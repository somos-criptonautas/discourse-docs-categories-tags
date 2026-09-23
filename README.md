# discourse-docs-categories-tags

Mixes every topic carrying a given tag (default: `wiki`) into the topic list
of one specific category, so they appear as ordinary rows alongside the
topics that natively belong to that category.

Built for the case the Doc Categories plugin cannot cover: that plugin is
category-scoped, so it cannot pull in topics by tag from other categories.

## Install

Admin → Customize → Themes → Install → From a git repository, using this
repository's clone URL. Then add the component to the themes that should
use it.

## Settings

| Setting | Default | Notes |
| --- | --- | --- |
| `tag_name` | `wiki` | Tag whose topics get mixed in. Only the first tag is used. |
| `target_category` | — | The one category whose list gains those topics. Only the first category is used. **Required** — nothing happens until it is set. |

## Behavior

- On the target category only, fetches the tag's topic list for the current
  tab and merges those topics into the category's own list. Rows render
  through core's topic list, so they carry the usual avatars, reply counts,
  activity and badges.
- Merged topics follow the tab's own sort rather than a separate order, so
  Latest stays ordered by activity.
- Topics already in the target category are skipped, so nothing appears
  twice, and the category's pinned topics stay pinned to the top.
- Source category badges are turned back on, since the list no longer holds
  a single category. Injected rows also get a `docs-categories-tags-topic`
  class for styling.
- The tag pill is hidden on that category's list, where it only repeats what
  the page already is. It stays visible on topic pages and every other
  listing, and other tags on those topics are untouched.
- The tag's own page (`/tag/<tag>`) redirects to the category, since the
  category now holds everything carrying the tag. Only that tag's listing
  routes redirect: tag editing and `/tags/c/...` intersections are left
  alone.
- A `#<tag>` written into a post body renders nothing, so the tag is applied
  through the tag selector rather than by hashtag. Other hashtags are
  untouched, and the word stays in the raw markdown.
- Disabled rows are hidden in the composer's tag search. When a category
  restricts which tags it allows, core lists the tags it does not allow as
  disabled rows explaining why; this hides that explanation. Unlike
  everything else here, that rule is site-wide, not scoped to the target
  category.
- Runs **only** on the target category. The outlet fires on every discovery
  page, so the component checks the current category ID and also skips
  tag/category intersection pages such as `/tags/c/docs/other-tag`.
- Results are cached in memory per tag and tab for the session, so switching
  tabs or navigating away and back does not refetch. A full page reload
  fetches again.
- On fetch failure the native list is left exactly as it was. No error is
  shown.

### How it hooks in

Topics are merged through the `discovery-above` plugin outlet, which
receives the route's model. That avoids overriding the fifteen-odd category
route classes (`category`, `categoryNone`, `latestCategory`, `topCategory`
and friends), at the cost of mutating the topic list the outlet hands over.

### The tag redirect

The redirect is client side, in the component. Discourse's own Permalinks
cannot do this: they are a catch-all route registered last, so they only fire
for URLs that match nothing else, and `/tag/<tag>` matches the real tag route
first.

That means in-app tag clicks never render the tag page, but a direct or
external hit loads it briefly before bouncing, and crawlers do not follow it.
For a real 301, redirect at the reverse proxy **and exclude the JSON**, which
this component fetches for its own data:

```nginx
location = /tag/wiki { return 301 /c/docs/4; }
location ~ ^/tag/wiki/l/[a-z]+$ { return 301 /c/docs/4; }
# /tag/wiki/l/latest.json must NOT be redirected.
```

### Doc Categories sidebar for topics listed elsewhere

Doc Categories decides its sidebar from the category a topic lives in
(`doc-category-sidebar.js`, `activeCategory`), so a topic that a Docs Index
Topic links to but which is filed in another category gets no sidebar, even
though it is part of the docs. This component overrides that one getter so
membership follows the index: whichever category's index links to the topic
drives the sidebar. Topics in a doc category are untouched.

This is tag-independent on purpose - it keys on the index, not on
`tag_name` - so it also covers doc topics that have nothing to do with the
merge above.

The patch is applied to the service **instance**, not through
`api.modifyClass`. Doc Categories looks that service up on the first line of
its own initializer, so by the time theme code runs it is already in the
container cache, and `modifyClass` refuses to touch anything initialized
earlier in boot - it logs "Attempted to modify ... but it was already
initialized earlier in the boot process" and silently does nothing.

Two caveats:

- It shadows a getter on a third-party plugin's service, which is private
  API. If Doc Categories renames it, the sidebar silently goes back to its
  default; nothing else breaks. When the plugin is not installed, the lookup
  finds nothing and the component stays inert.
- Prev/next navigation is a separate matter and lives in
  `discourse-course-progress`, which resolves membership the same way. The
  href-parsing helper is therefore duplicated in both repositories; it is
  unit-tested there.

### What this deliberately does not do

Two neighbouring problems are better solved in Discourse itself than here:

- **Tags that should be invisible outside a bot's use** (auto-applied
  glossary terms, say). Put them in a tag group whose only permission entry
  is that bot's group. `DiscourseTagging.hidden_tags` then hides them
  server-side from everyone except that group and admins, in lists, topics,
  search and autocomplete. No stylesheet can match that.
- **Tags a category does not allow being offered at all.** The rule above
  only hides core's explanation. What is offered is decided server-side.

### Known limits

- The **Top** tab is approximate. The tag list is fetched with the `top`
  filter, but the merged order is by view count, which is not the same
  ranking the server uses, and the period (`top/weekly` and so on) is not
  passed through.
- The merged topics appear a moment after the native list, once the fetch
  finishes, which visibly reflows the list on a slow connection.
- Everything carrying the tag is fetched up front, up to 20 pages, while the
  category's own topics keep paginating on scroll.
- The docs sidebar override is not covered by a test: the theme CI runs core
  only, so the Doc Categories plugin is not installed and the modification
  never applies there. The existing suite only proves it does not break boot.
- The hidden disabled rows in the tag chooser are not covered by a test:
  exercising them needs a category with restricted tag groups driven through
  the composer. The hashtag rule is tested.

## Development

```bash
pnpm install
pnpm lint
```

CI runs Discourse's shared theme workflow, which lints and runs the theme
tests. `spec/system/core_features_spec.rb` checks that core features still
work with the component installed; `spec/system/docs_categories_tags_spec.rb`
covers the merge, the ordering, the category guard and the de-duplication.

System tests run against a real Discourse via the
[discourse_theme CLI](https://github.com/discourse/discourse_theme):

```bash
discourse_theme rspec .
```

Verified against Discourse `2026.7.2` (stable) and `2026.9.0-latest`.
