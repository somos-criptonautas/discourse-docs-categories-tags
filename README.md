# Wiki Tag List

Lists every topic carrying a given tag (default: `wiki`) on one specific
category page, sorted alphabetically. Topics already in that category are
excluded, so nothing appears twice.

Built for the case the Doc Categories plugin cannot cover: that plugin is
category-scoped, so it cannot list topics by tag across many categories.

## Install

Admin → Customize → Themes → Install → From a git repository, using this
repository's clone URL. Then add the component to the themes that should
show it.

## Settings

| Setting | Default | Notes |
| --- | --- | --- |
| `tag_name` | `wiki` | Tag whose topics are listed. Only the first tag is used. |
| `target_category` | — | The one category page that shows the list. Only the first category is used. **Required** — the list renders nowhere until it is set. |
| `section_heading` | `Wiki` | Heading rendered above the list. |
| `placement` | `above` | Above or below the category's native topic list. |

## Behavior

- Fetches `/tag/{tag}/l/latest.json` and follows `more_topics_url` until the
  list is exhausted, capped at 20 pages (~600 topics).
- Sorts by topic title with `localeCompare`, so accented characters sort in
  place rather than after Z.
- Renders a plain `<ul>` of linked titles plus a source category badge. It
  deliberately does not reuse core's topic-list components, which change
  between Discourse versions.
- Renders **only** on the target category. The
  `discovery-list-container-top` outlet fires on every discovery page, so
  the component checks the current category ID and also skips
  tag/category intersection pages such as `/tags/c/docs/other-tag`.
- While fetching, shows a fixed-height skeleton, because the outlet sits
  above the topic list and would otherwise shift it.
- On fetch failure, or when the tag matches nothing outside the target
  category, renders nothing at all. No error block.
- Results are cached in memory per tag for the session, so switching
  between the category's Latest and Top tabs does not refetch. A full page
  reload fetches again.

### Known limits

- `placement: below` renders under an infinitely scrolling topic list, so
  on a busy category few people will scroll far enough to see it.
- The list is not paginated or collapsed. At the top of the expected
  50–200 range it pushes the native topic list a long way down.
- Topic titles render as plain text, so `:emoji:` codes in a title are not
  converted to images.

## Development

```bash
pnpm install
pnpm lint
```

CI runs Discourse's shared theme workflow, which lints and runs the theme
tests. `spec/system/core_features_spec.rb` checks that core features still
work with the component installed;
`spec/system/wiki_tag_list_spec.rb` covers the guard, the sort order and
the exclusion of the target category's own topics.

System tests run against a real Discourse via the
[discourse_theme CLI](https://github.com/discourse/discourse_theme):

```bash
discourse_theme rspec .
```

Verified against Discourse `2026.7.2` (stable) and `2026.9.0-latest`.
