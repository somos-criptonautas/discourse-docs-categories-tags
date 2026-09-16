# frozen_string_literal: true

RSpec.describe "discourse-docs-categories-tags" do
  let!(:component) { upload_theme_or_component }

  fab!(:wiki_tag) { Fabricate(:tag, name: "wiki") }
  fab!(:target_category) { Fabricate(:category, name: "Docs") }
  fab!(:other_category) { Fabricate(:category, name: "Guides") }

  # bumped_at is set explicitly so the expected merged order is unambiguous:
  # the tagged topics from Guides have to land between the Docs topics.
  # Titles have to clear Discourse's 15 character minimum.
  fab!(:docs_recent) do
    Fabricate(
      :topic,
      title: "Docs topic bumped most recently",
      category: target_category,
      bumped_at: 1.hour.ago,
    )
  end

  fab!(:wiki_middle) do
    Fabricate(
      :topic,
      title: "Wiki topic bumped in the middle",
      category: other_category,
      tags: [wiki_tag],
      bumped_at: 1.day.ago,
    )
  end

  fab!(:docs_older) do
    Fabricate(
      :topic,
      title: "Docs topic bumped a while back",
      category: target_category,
      bumped_at: 2.days.ago,
    )
  end

  fab!(:wiki_oldest) do
    Fabricate(
      :topic,
      title: "Wiki topic bumped longest ago",
      category: other_category,
      tags: [wiki_tag],
      bumped_at: 3.days.ago,
    )
  end

  fab!(:wiki_already_in_target) do
    Fabricate(
      :topic,
      title: "Wiki topic already inside Docs",
      category: target_category,
      tags: [wiki_tag],
      bumped_at: 4.days.ago,
    )
  end

  fab!(:untagged_elsewhere) do
    Fabricate(
      :topic,
      title: "Untagged topic somewhere else",
      category: other_category,
      bumped_at: 5.minutes.ago,
    )
  end

  before do
    SiteSetting.tagging_enabled = true
    component.update_setting(:tag_name, "wiki")
    component.update_setting(:target_category, target_category.id.to_s)
    component.save!
  end

  def target_category_path
    "/c/#{target_category.slug}/#{target_category.id}"
  end

  def listed_titles
    page.all(".topic-list-body .topic-list-item .raw-topic-link").map(&:text)
  end

  it "mixes the tagged topics into the category's own topic list" do
    visit target_category_path

    expect(page).to have_css(".topic-list-item.docs-categories-tags-topic", count: 2)
    expect(listed_titles).to eq(
      [
        "Docs topic bumped most recently",
        "Wiki topic bumped in the middle",
        "Docs topic bumped a while back",
        "Wiki topic bumped longest ago",
        "Wiki topic already inside Docs",
      ],
    )
  end

  it "shows the source category on the topics it pulled in" do
    visit target_category_path

    expect(page).to have_css(
      ".topic-list-item.docs-categories-tags-topic .badge-category",
      text: "Guides",
    )
  end

  it "does not duplicate a tagged topic that already lives in the category" do
    visit target_category_path

    expect(page).to have_css(".topic-list-item")
    expect(listed_titles.count("Wiki topic already inside Docs")).to eq(1)
  end

  it "leaves untagged topics from other categories out" do
    visit target_category_path

    expect(page).to have_css(".topic-list-item.docs-categories-tags-topic")
    expect(listed_titles).not_to include("Untagged topic somewhere else")
  end

  it "does not touch other discovery pages" do
    visit "/c/#{other_category.slug}/#{other_category.id}"
    expect(page).to have_css(".topic-list-item")
    expect(page).to have_no_css(".topic-list-item.docs-categories-tags-topic")
    expect(listed_titles).not_to include("Docs topic bumped most recently")

    visit "/latest"
    expect(page).to have_css(".topic-list-item")
    expect(page).to have_no_css(".topic-list-item.docs-categories-tags-topic")
  end

  it "does nothing when no target category is set" do
    component.update_setting(:target_category, "")
    component.save!

    visit target_category_path

    expect(page).to have_css(".topic-list-item")
    expect(page).to have_no_css(".topic-list-item.docs-categories-tags-topic")
    expect(listed_titles).not_to include("Wiki topic bumped in the middle")
  end

  it "hides the tag pill on that list only" do
    visit target_category_path
    expect(page).to have_css(".topic-list-item.docs-categories-tags-topic")
    expect(page).to have_no_css(".topic-list .discourse-tag[data-tag-name='wiki']")

    # Still meaningful everywhere else.
    visit "/c/#{other_category.slug}/#{other_category.id}"
    expect(page).to have_css(".discourse-tag[data-tag-name='wiki']")
  end

  it "redirects the tag's own page to the category" do
    visit "/tag/wiki"

    expect(page).to have_current_path(target_category_path, ignore_query: true)
    expect(page).to have_css(".topic-list-item.docs-categories-tags-topic")
  end

  it "leaves other tags alone" do
    Fabricate(:tag, name: "handbook")

    visit "/tag/handbook"

    # Discourse canonicalises this to /tag/handbook/<id> on its own; what
    # matters is that it stays on the tag page.
    expect(page).to have_current_path(%r{/tag/handbook}, ignore_query: true)
  end
end
