import Component from "@glimmer/component";
import { service } from "@ember/service";
import { apiInitializer } from "discourse/lib/api";

// Runaway guard. 20 pages x 30 topics is far more than the expected volume.
const MAX_PAGES = 20;

// Cached per tag and filter, so switching between the category's tabs and
// navigating away and back does not refetch during the session.
const cache = new Map();

// Ids of the topics this component pulled in, used to mark their rows.
const injectedIds = new Set();

const firstValue = (value) => (value || "").split("|").find(Boolean);

async function fetchTagged(store, tag, filter) {
  // Same filter string core's tag route uses, so this goes through the
  // normal topic-list adapter and yields real Topic records.
  const list = await store.findFiltered("topicList", {
    filter: `tag/${tag}/l/${filter}`,
  });

  for (let page = 0; page < MAX_PAGES && list.canLoadMore; page++) {
    await list.loadMore();
  }

  return [...list.topics];
}

function loadTagged(store, tag, filter) {
  const key = `${tag}|${filter}`;

  if (!cache.has(key)) {
    const promise = fetchTagged(store, tag, filter).catch((error) => {
      cache.delete(key); // let the next visit retry
      throw error;
    });
    cache.set(key, promise);
  }

  return cache.get(key);
}

// Pinned topics belonging to the category keep their place at the top. An
// injected topic pinned in its own category is not pinned to this one.
const pinRank = (topic) => (topic.pinned && !injectedIds.has(topic.id) ? 0 : 1);

function sortKey(topic, filter) {
  if (filter === "top") {
    return topic.views ?? 0;
  }
  return Date.parse(topic.bumped_at ?? topic.created_at) || 0;
}

function sortTopics(topics, filter) {
  return [...topics].sort(
    (a, b) => pinRank(a) - pinRank(b) || sortKey(b, filter) - sortKey(a, filter)
  );
}

// Renders nothing. It exists to reach the topic list through the outlet's
// model, which is a public API, rather than overriding the category routes.
class DocsCategoriesTagsInjector extends Component {
  @service store;

  constructor() {
    super(...arguments);
    this.injectTopics();
  }

  async injectTopics() {
    const list = this.args.model?.list;

    // A list is reused when returning to a cached page; only merge once.
    if (!list || list.docsCategoriesTagsMerged) {
      return;
    }
    list.docsCategoriesTagsMerged = true;

    const filter = this.args.model.filterType || "latest";

    let tagged;
    try {
      tagged = await loadTagged(this.store, this.args.tag, filter);
    } catch {
      return; // leave the native list exactly as it was
    }

    const present = new Set(list.topics.map((topic) => topic.id));
    const extra = tagged.filter(
      (topic) =>
        topic.category_id !== this.args.categoryId && !present.has(topic.id)
    );

    if (extra.length === 0) {
      return;
    }

    extra.forEach((topic) => injectedIds.add(topic.id));

    // Core hides the category badge when every topic shares the category,
    // which is no longer true once topics from elsewhere are mixed in.
    list.set("hideCategory", false);
    list.topics = sortTopics([...list.topics, ...extra], filter);

    // Infinite scroll appends the next page of the category's own topics to
    // the end, so the merged order has to be restored after each page.
    const loadMore = list.loadMore.bind(list);
    list.loadMore = async (...args) => {
      const result = await loadMore(...args);
      list.topics = sortTopics(list.topics, filter);
      return result;
    };
  }

  <template></template>
}

export default apiInitializer((api) => {
  const tag = firstValue(settings.tag_name);
  const categoryId = parseInt(firstValue(settings.target_category), 10);

  if (!tag || !categoryId) {
    return;
  }

  // The outlet fires on every discovery page, so merge only on the target
  // category. Tag/category intersection pages are left alone.
  const isTarget = (outletArgs) =>
    !outletArgs.tag && outletArgs.category?.id === categoryId;

  api.renderInOutlet(
    "discovery-above",
    <template>
      {{#if (isTarget @outletArgs)}}
        <DocsCategoriesTagsInjector
          @model={{@outletArgs.model}}
          @tag={{tag}}
          @categoryId={{categoryId}}
        />
      {{/if}}
    </template>
  );

  api.registerValueTransformer(
    "topic-list-item-class",
    ({ value, context }) => {
      if (
        context.category?.id === categoryId &&
        injectedIds.has(context.topic.id)
      ) {
        value.push("docs-categories-tags-topic");
      }
      return value;
    }
  );
});
