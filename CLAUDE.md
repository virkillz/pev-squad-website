# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A static, hand-edited prototype website for "PEV Squad" — a community of personal electric vehicle riders (EUC, performance scooters, esk8). Purpose is to demo the concept to the team; there is no build step, no framework, no package.json, and no test suite. All content is edited directly in the HTML files.

## Running locally

There's no dev server or build tooling. To preview:

```bash
python3 -m http.server 8934
```

Then open `http://localhost:8934/index.html`. Opening the HTML files directly via `file://` also works for basic viewing, but a local server is more reliable if verifying via browser automation.

## Architecture

- **Multi-page static site, no templating.** Each top-level page (`index.html`, `community.html`, `featured-riders.html`, `reviews.html`, `for-sale.html`, `events.html`, `sponsors.html`) is a fully self-contained HTML file. The `<header>` nav block and `<footer>` block are duplicated verbatim across every page — there is no include/partial mechanism. When editing nav links, the footer, or the theme-init script, **update all seven files identically**.
- **`css/style.css`** is the single shared stylesheet (one file, no preprocessor). It's organized as a design system: CSS custom properties in `:root` define the dark theme (default), with a `:root[data-theme="light"]` block overriding a subset of tokens for light mode. Section comments divide the file (nav, buttons, hero, cards, stars/ratings, statbar, collab strip, filters, listings, events, footer, page-header).
- **`js/main.js`** is vanilla JS, no dependencies: wires up the mobile nav hamburger toggle and the light/dark theme switch button (persists choice to `localStorage` under key `pev-theme`).
- **Theme switching mechanics**: each page has an inline `<script>` in `<head>` (before the stylesheet) that reads `localStorage.pev-theme` (falling back to `prefers-color-scheme`) and sets `data-theme` on `<html>` synchronously, to avoid a flash of the wrong theme. This inline script is duplicated per-page like the nav/footer — keep it in sync if changed.
- **Design tokens worth knowing**: `--black`/`--white`/`--card`/`--grey`/`--line` etc. are theme-flippable surface/text tokens (swapped by the light-mode override). `--ink` is a fixed near-black constant used specifically for text sitting on solid-orange fills (buttons, solid badges, active filter tags) — it must NOT flip with theme, since orange backgrounds need dark text in both modes. `--orange`/`--orange-2`/`--orange-dim` are brand accent colors; `--orange-2` is overridden slightly darker in light mode for text contrast.
- **Images**: `images/logo.jpg` is the brand mark (also used as favicon and in the footer). A copy of the original upload lives at the repo root (`pev_squad_logo.jpg`) — treat `images/logo.jpg` as the canonical asset referenced by the pages.
- **Fonts**: Google Fonts loaded via `@import` in `style.css` — Anton (display headlines), Barlow / Barlow Condensed (body/labels), JetBrains Mono (stats, prices, ratings).

## Conventions when editing

- Since there's no component system, adding a new page means copying an existing page's `<head>`/nav/footer boilerplate and updating the active nav link (`class="active"`) and page-specific content.
- Card-based content (reviews, listings, riders, events) follows a consistent `.card` / `.card-body` / `.card-foot` markup pattern in `style.css` — reuse these classes rather than inventing new ones for similar content blocks.
- The "For Sale" page splits listings into two sections (`#brand-new`, `#second-hand`) rather than a single New/Used filter — keep new content in the correct section rather than reintroducing a combined filter.
