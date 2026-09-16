# Wiki Tag List

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
  a single category. Injected rows also get a `wiki-tag-topic` class for
  styling.
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

### Known limits

- The **Top** tab is approximate. The tag list is fetched with the `top`
  filter, but the merged order is by view count, which is not the same
  ranking the server uses, and the period (`top/weekly` and so on) is not
  passed through.
- The merged topics appear a moment after the native list, once the fetch
  finishes, which visibly reflows the list on a slow connection.
- Everything carrying the tag is fetched up front, up to 20 pages, while the
  category's own topics keep paginating on scroll.

## Development

```bash
pnpm install
pnpm lint
```

CI runs Discourse's shared theme workflow, which lints and runs the theme
tests. `spec/system/core_features_spec.rb` checks that core features still
work with the component installed; `spec/system/wiki_tag_list_spec.rb`
covers the merge, the ordering, the category guard and the de-duplication.

System tests run against a real Discourse via the
[discourse_theme CLI](https://github.com/discourse/discourse_theme):

```bash
discourse_theme rspec .
```

Verified against Discourse `2026.7.2` (stable) and `2026.9.0-latest`.
