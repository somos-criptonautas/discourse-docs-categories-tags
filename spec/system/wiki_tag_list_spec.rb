# frozen_string_literal: true

RSpec.describe "Wiki tag list" do
  let!(:component) { upload_theme_or_component }

  fab!(:wiki_tag) { Fabricate(:tag, name: "wiki") }
  fab!(:target_category) { Fabricate(:category, name: "Docs") }
  fab!(:other_category) { Fabricate(:category, name: "Guides") }

  # Titles are chosen so that alphabetical order differs from the bumped_at
  # order the endpoint returns, and so that a plain sort would put the
  # accented title after Z instead of between A and Z. They also have to
  # clear Discourse's 15 character minimum title length.
  fab!(:zebra) do
    Fabricate(:topic, title: "Zebra care essentials", category: other_category, tags: [wiki_tag])
  end

  fab!(:elan) do
    Fabricate(
      :topic,
      title: "Élan basics for beginners",
      category: other_category,
      tags: [wiki_tag],
    )
  end

  fab!(:apple) do
    Fabricate(
      :topic,
      title: "Apple basics for gardeners",
      category: other_category,
      tags: [wiki_tag],
    )
  end

  fab!(:already_in_target) do
    Fabricate(
      :topic,
      title: "Already inside the Docs category",
      category: target_category,
      tags: [wiki_tag],
    )
  end

  fab!(:untagged) do
    Fabricate(:topic, title: "Not tagged at all anywhere", category: other_category)
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
    page.all(".wiki-tag-list__title").map(&:text)
  end

  it "lists the tagged topics alphabetically, accents included" do
    visit target_category_path

    expect(page).to have_css(".wiki-tag-list")
    expect(listed_titles).to eq(
      ["Apple basics for gardeners", "Élan basics for beginners", "Zebra care essentials"],
    )
  end

  it "excludes topics that are already in the target category" do
    visit target_category_path

    expect(page).to have_css(".wiki-tag-list")
    expect(listed_titles).not_to include("Already inside the Docs category")
  end

  it "excludes topics without the tag" do
    visit target_category_path

    expect(page).to have_css(".wiki-tag-list")
    expect(listed_titles).not_to include("Not tagged at all anywhere")
  end

  it "renders one heading and a single list" do
    visit target_category_path

    expect(page).to have_css(".wiki-tag-list__heading", count: 1)
    expect(page).to have_css(".wiki-tag-list__items", count: 1)
  end

  it "does not render on other discovery pages" do
    visit "/latest"
    expect(page).to have_css(".topic-list")
    expect(page).to have_no_css(".wiki-tag-list")

    visit "/categories"
    expect(page).to have_css(".category-list, .categories-list")
    expect(page).to have_no_css(".wiki-tag-list")

    visit "/c/#{other_category.slug}/#{other_category.id}"
    expect(page).to have_css(".topic-list")
    expect(page).to have_no_css(".wiki-tag-list")
  end

  it "does not render when no target category is set" do
    component.update_setting(:target_category, "")
    component.save!

    visit target_category_path

    expect(page).to have_css(".topic-list")
    expect(page).to have_no_css(".wiki-tag-list")
  end
end
