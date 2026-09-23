# frozen_string_literal: true

# Covers the one thing that broke silently in production: the docs sidebar on
# a topic that a Doc Categories index links to but that lives in another
# category. It needs the plugin, which CI installs through the
# `tests.requiredPlugins` entry in about.json.
RSpec.describe "Docs sidebar for topics listed elsewhere" do
  before { skip("discourse-doc-categories is not installed") unless defined?(DocCategories) }

  let!(:component) { upload_theme_or_component }

  fab!(:docs_category, :category_with_definition)
  fab!(:other_category, :category_with_definition)

  # Lives outside the docs category, and the docs index links to it.
  fab!(:listed_topic) do
    Fabricate(:topic_with_op, title: "Wiki topic listed in the index", category: other_category)
  end

  fab!(:unlisted_topic) do
    Fabricate(:topic_with_op, title: "Topic that no index mentions", category: other_category)
  end

  fab!(:index_topic) { Fabricate(:topic_with_op, category: docs_category) }

  before do
    # Core's set_navigation_menu helper is not loaded for theme specs.
    SiteSetting.navigation_menu = "sidebar"
    SiteSetting.doc_categories_enabled = true

    index = DocCategories::Index.create!(category: docs_category, index_topic: index_topic)
    section = index.sidebar_sections.create!(title: "Guides", position: 0)
    section.sidebar_links.create!(
      title: listed_topic.title,
      href: "/t/#{listed_topic.slug}/#{listed_topic.id}",
      topic: listed_topic,
      position: 0,
    )

    Site.clear_cache
  end

  # Raw selectors rather than core's page objects, for the same reason.
  def docs_link_selector
    ".sidebar-section-link[href='/t/#{listed_topic.slug}/#{listed_topic.id}']"
  end

  it "shows the docs sidebar on a topic the index links to" do
    visit listed_topic.relative_url

    expect(page).to have_css(docs_link_selector)
    expect(page).to have_no_css(".sidebar-section[data-section-name='categories']")
  end

  it "leaves topics that no index lists alone" do
    visit unlisted_topic.relative_url

    expect(page).to have_css(".sidebar-section[data-section-name='categories']")
    expect(page).to have_no_css(docs_link_selector)
  end
end
