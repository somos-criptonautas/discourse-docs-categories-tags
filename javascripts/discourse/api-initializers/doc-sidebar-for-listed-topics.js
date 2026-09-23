import { apiInitializer } from "discourse/lib/api";
import Category from "discourse/models/category";

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

// On topic routes the route's model is the topic itself; the post stream is
// what distinguishes it from a discovery model that also has an id.
function currentTopic(router) {
  const route = router.currentRoute;
  const attributes = route?.attributes ?? route?.parent?.attributes;

  return attributes?.postStream ? attributes : null;
}

export default apiInitializer((api) => {
  // Doc Categories decides the sidebar from the category the topic lives in,
  // so a topic listed in an Index Topic but filed elsewhere gets no sidebar.
  // Membership follows the index instead: whichever category's index links to
  // this topic drives it. Topics in a doc category are left untouched.
  //
  // When the plugin is absent this modification is simply deferred forever,
  // so the component stays inert rather than erroring.
  api.modifyClass(
    "service:doc-category-sidebar",
    (Superclass) =>
      class extends Superclass {
        get activeCategory() {
          const fromRoute = super.activeCategory;

          if (hasDocIndex(fromRoute)) {
            return fromRoute;
          }

          const topic = currentTopic(this.router);

          if (!topic) {
            return fromRoute;
          }

          // Category.list() holds what the site has loaded; with lazily
          // loaded categories a miss just leaves the plugin's own answer.
          return (
            Category.list()?.find((category) =>
              indexLinksTopic(category, topic.id)
            ) ?? fromRoute
          );
        }
      }
  );
});
