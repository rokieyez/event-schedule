# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repository is

A **redirect-only stub**, not an application. It exists solely to keep the retired
domain `event.suayona.com` alive so that already-shared links keep working, forwarding
everything to `https://www.suayona.com/event/...`.

The real event app used to live here and was moved under the main domain (commit
`a684e13`) so the two sites share a login session. Nothing here should grow back into
an app — if a task calls for changing event-site behavior, it almost certainly belongs
in `rokieyez/suayona-site`, not here.

## Commands

There are none. No package manager, build step, test suite, linter, or dependencies —
the repo is four static HTML files plus `CNAME`.

- **Deploy:** push to `main`. GitHub Pages serves the repo root as-is.
- **Preview:** open a file directly, or `python3 -m http.server` from the repo root.
  Note the redirect fires on load, so a local preview navigates away immediately;
  comment out the `location.replace` line to inspect the page itself.

## Structure and the one rule that matters

`index.html`, `404.html`, `e/index.html`, and `e/admin.html` are **byte-identical**.
Any edit must be applied to all four, or the redirect behaves inconsistently depending
on which URL a visitor hits. Verify with `diff` after editing.

The redirect logic in each file is:

```js
var target = 'https://www.suayona.com/event' + location.pathname + location.search + location.hash;
```

Consequences worth knowing before touching it:

- The `/event` prefix is prepended to the **original path**, so `/e/?slug=x` lands on
  `/event/e/?slug=x`. The destination site mirrors this repo's path layout — changing
  the prefix or dropping `location.search` breaks every shared `?slug=` link.
- `404.html` is what catches unknown paths on GitHub Pages, which is why it carries
  the same redirect rather than an error message. It is served with a 404 status;
  the JS redirect is what actually rescues the visitor.
- `<meta name="robots" content="noindex">` and the `<link rel="canonical">` to the new
  location are deliberate — they steer search engines to the live site. Keep both.
- `CNAME` (`event.suayona.com`) must stay at the repo root; deleting it drops the
  custom domain and the redirect never runs.

## Recovering the old app

The full pre-redirect event site is in git history: a Supabase-backed single-page app
(`e/index.html` viewer, `e/admin.html` editor) driven by `?slug=` against tables
`event_meta`, `events`, `gallery_media`, and `custom_tabs`, with `supabase-setup.sql`
and `compress.js` alongside.

```sh
git show a684e13^:e/index.html         # any file as it was before the redirect
git ls-tree -r --name-only a684e13^    # everything that existed then
```

Read these for reference only. Restoring them here would resurrect a second copy of a
site that now lives elsewhere.
