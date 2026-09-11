import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { ajax } from "discourse/lib/ajax";
import { apiInitializer } from "discourse/lib/api";
import getURL from "discourse/lib/get-url";
import Category from "discourse/models/category";
import dCategoryBadge from "discourse/ui-kit/helpers/d-category-badge";
import I18n from "discourse-i18n";

// Runaway guard: 20 pages x 30 topics covers far more than the expected 200.
const MAX_PAGES = 20;

// Per-tag promise, kept for the session so Latest/Top tab switches reuse it.
const cache = new Map();

const firstValue = (value) => (value || "").split("|").find(Boolean);

// Same .json postfixing core does in models/topic-list.js loadMore.
function jsonUrl(moreTopicsUrl) {
  const [path, query] = moreTopicsUrl.split("?");
  const url = path.endsWith(".json") ? path : `${path}.json`;
  return query ? `${url}?${query}` : url;
}

async function fetchTagged(tag) {
  const topics = new Map(); // keyed by id: latest order can shift between pages
  let url = `/tag/${encodeURIComponent(tag)}/l/latest.json`;

  for (let page = 0; url && page < MAX_PAGES; page++) {
    const { topic_list } = await ajax(url);
    topic_list.topics.forEach((topic) => topics.set(topic.id, topic));
    url = topic_list.more_topics_url && jsonUrl(topic_list.more_topics_url);
  }

  return [...topics.values()];
}

function loadTagged(tag) {
  if (!cache.has(tag)) {
    const promise = fetchTagged(tag).catch((error) => {
      cache.delete(tag); // let the next visit retry
      throw error;
    });
    cache.set(tag, promise);
  }
  return cache.get(tag);
}

// An empty array after filtering renders nothing, same as a failure.
const isLoading = (topics) => topics === null;

class WikiTagList extends Component {
  @tracked topics = null; // null while loading
  @tracked failed = false;

  constructor() {
    super(...arguments);

    const locale = I18n.currentBcp47Locale;

    loadTagged(this.args.tag)
      .then((topics) => {
        this.topics = topics
          .filter((topic) => topic.category_id !== this.args.categoryId)
          .sort((a, b) =>
            a.title.localeCompare(b.title, locale, { sensitivity: "base" })
          )
          .map((topic) => ({
            id: topic.id,
            title: topic.title,
            url: getURL(`/t/${topic.slug}/${topic.id}`),
            category: Category.findById(topic.category_id),
          }));
      })
      .catch(() => (this.failed = true));
  }

  <template>
    {{#unless this.failed}}
      {{#if this.topics}}
        <section class="wiki-tag-list" aria-labelledby="wiki-tag-list-heading">
          <h2 id="wiki-tag-list-heading" class="wiki-tag-list__heading">
            {{@heading}}
          </h2>
          <ul class="wiki-tag-list__items">
            {{#each this.topics key="id" as |topic|}}
              <li class="wiki-tag-list__item">
                <a class="wiki-tag-list__title" href={{topic.url}}>
                  {{topic.title}}
                </a>
                {{#if topic.category}}
                  {{dCategoryBadge topic.category}}
                {{/if}}
              </li>
            {{/each}}
          </ul>
        </section>
      {{else if (isLoading this.topics)}}
        <div class="wiki-tag-list__skeleton" aria-hidden="true"></div>
      {{/if}}
    {{/unless}}
  </template>
}

export default apiInitializer((api) => {
  const tag = firstValue(settings.tag_name);
  const categoryId = parseInt(firstValue(settings.target_category), 10);

  if (!tag || !categoryId) {
    return;
  }

  // The outlet fires on every discovery page (/latest, /categories, every
  // category, tag+category intersections), so render only on the target
  // category itself. Reactive: navigating away tears the list down.
  const isTarget = (outletArgs) =>
    !outletArgs.tag && outletArgs.category?.id === categoryId;

  const Connector = <template>
    {{#if (isTarget @outletArgs)}}
      <WikiTagList
        @tag={{tag}}
        @categoryId={{categoryId}}
        @heading={{settings.section_heading}}
      />
    {{/if}}
  </template>;

  if (settings.placement === "below") {
    api.renderAfterWrapperOutlet("discovery-list-area", Connector);
  } else {
    api.renderInOutlet("discovery-list-container-top", Connector);
  }
});
