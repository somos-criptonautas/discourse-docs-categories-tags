import { apiInitializer } from "discourse/lib/api";

// Doc index links carry only `text` and `href` (no topic id), so membership
// is resolved by parsing the topic id out of each href.
const TOPIC_HREF = /^(?:https?:\/\/[^/]+)?\/t\/(?:[^/]+\/)?(\d+)/;

function topicIdFromHref(href) {
  const match = href?.match(TOPIC_HREF);

  return match ? Number(match[1]) : null;
}

function indexLinksTopic(category, topicId) {
  const structure = category?.doc_category_index;

  if (!Array.isArray(structure) || !topicId) {
    return false;
  }

  return structure.some((section) =>
    (section?.links ?? []).some(
      (link) => topicIdFromHref(link?.href) === topicId
    )
  );
}

// Mirrors the plugin's own walk: a subcategory inherits its parent's index.
function hasDocIndex(category) {
  let current = category;

  while (current) {
    if (current.doc_category_index) {
      return true;
    }
    current = current.parentCategory;
  }

  return false;
}

function currentTopic(router, container) {
  const name = router.currentRouteName;

  if (name !== "topic" && !name?.startsWith("topic.")) {
    return null;
  }

  const route = router.currentRoute;
  const attributes = route?.attributes ?? route?.parent?.attributes;

  return attributes?.id
    ? attributes
    : (container.lookup("controller:topic")?.model ?? null);
}

// Walks up to the prototype that actually defines the accessor.
function inheritedDescriptor(object, name) {
  let current = Object.getPrototypeOf(object);

  while (current) {
    const descriptor = Object.getOwnPropertyDescriptor(current, name);

    if (descriptor) {
      return descriptor;
    }

    current = Object.getPrototypeOf(current);
  }
}

export default apiInitializer((api) => {
  // Doc Categories decides its sidebar from the category a topic lives in, so
  // a topic listed in an Index Topic but filed elsewhere gets none. Membership
  // follows the index instead: whichever category's index links to this topic
  // drives the sidebar. Topics in a doc category are left untouched.
  //
  // This patches the service instance rather than the class: the plugin looks
  // the service up in the first line of its own initializer, so by the time
  // theme code runs it sits in the container cache, and api.modifyClass
  // refuses to touch anything already initialized ("Attempted to modify ...
  // but it was already initialized earlier in the boot process").
  let sidebar;

  try {
    sidebar = api.container.lookup("service:doc-category-sidebar");
  } catch {
    return; // plugin not installed
  }

  if (!sidebar) {
    return; // plugin not installed
  }

  const original = inheritedDescriptor(sidebar, "activeCategory")?.get;

  if (!original) {
    // The plugin is installed but no longer looks the way this patch expects.
    // Say so: the previous version of this failed silently for days.
    // eslint-disable-next-line no-console
    console.warn(
      "discourse-docs-categories-tags: doc-category-sidebar has no " +
        "activeCategory getter, so topics listed in an index but filed " +
        "elsewhere will not get the docs sidebar."
    );
    return;
  }

  const site = api.container.lookup("service:site");

  Object.defineProperty(sidebar, "activeCategory", {
    configurable: true,
    get() {
      const fromRoute = original.call(this);

      if (hasDocIndex(fromRoute)) {
        return fromRoute;
      }

      const topic = currentTopic(this.router, api.container);

      if (!topic) {
        return fromRoute;
      }

      return (
        site.categories?.find((category) =>
          indexLinksTopic(category, topic.id)
        ) ?? fromRoute
      );
    },
  });

  // The service already judged the current route during boot, before this
  // getter existed, so ask it to look again for a full page load on a topic.
  sidebar.currentRouteChanged({ isAborted: false });
});
