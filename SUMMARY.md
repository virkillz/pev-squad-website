# PEV Squad — Content Summary

Handover doc for new sessions. Covers *what the site says and how it looks*.
For build/architecture rules (no build step, duplicated nav/footer, theme-init script), see [CLAUDE.md](CLAUDE.md).

---

## Background

**PEV Squad** is an Indonesian community of personal electric vehicle riders — performance EUCs first, performance e-scooters second, the occasional electric skateboard. The site is a **static hand-edited prototype** built to demo the concept to the team. All content is fictional placeholder data (names, mileage, prices, dates), not real records.

- **Tagline / motto:** "We Take It Personal."
- **Positioning line:** "Indonesia's Most Active EUC Community"
- **Three pillars:** Ride Fast · Ride Far · Ride Often
- **Tone:** hobbyists, not a business. Day jobs, no media kit — the stated bar for collaboration is *"will it be fun?"*
- **Community lives on WhatsApp/Instagram**, not email — CTAs point at chat, not forms.
- **Footer scope line:** `EUC / ESCOOTER / ESK8 — INDONESIA`, © 2026.

Two recurring concepts drive the content model:

| Concept | Meaning |
|---|---|
| **Featured Rider** | Seasoned member vetted to give star ratings. Gate: 5,000 km minimum · 1 year active · multiple units owned. Marked with an orange `★ Featured Rider` badge. |
| **Community member** | Everyone else. Grey `Member` / `Community Review` badge. Reviews carry less weight. |

---

## Style guide & concept

Aesthetic: **industrial / moto-poster** — condensed uppercase display type, near-black surfaces, single hot-orange accent, hard 2px corners, hazard-stripe motif.

**Colors** (`css/style.css` `:root`, dark is default; `:root[data-theme="light"]` overrides a subset)

- Brand accent: `--orange #ff5a1f`, `--orange-2 #ff7a3d` (darkened to `#d8480f` in light mode for contrast), `--orange-dim`, `--yellow #ffb703`
- Theme-flippable surfaces/text: `--black`, `--black-soft`, `--card`, `--card-2`, `--white`, `--grey`, `--grey-dim`, `--line`, `--line-strong`, `--header-bg`
- `--ink #0a0a0b` is a **fixed** near-black for text on solid-orange fills — it must never flip with theme
- `--radius: 2px` (near-square everywhere), `--stripe` = 45° orange/ink hazard stripe used in the bar under the header

**Typography**

- `Anton` — all h1/h2/h3, uppercase display
- `Barlow Condensed` — `.eyebrow` labels: uppercase, `0.22em` tracking, orange, prefixed by a 22px orange dash
- `Barlow` — body copy and any headline that should read as sentence-case (applied inline)
- `JetBrains Mono` — stats, prices, rating numbers

**Recurring components** (reuse these; don't invent new ones)

`.wrap` container · `.eyebrow` + `.section-head` (label → h2 → blurb, optional right-aligned button) · `.btn-solid` / `.btn-outline` · `.card` › `.avatar` (2–4 letter monogram on a dark tinted background) › `.card-body` (`.badge`, h3, `.card-meta`, `.desc`) › `.card-foot` (two-column meta) · `.grid.grid-3` · `.tiles` (numbered `01–04` landing tiles) · `.statbar` · `.filters` / `.filter-tag` · `.stars` + `.rating-row`/`.rating-bar` · `.price-tag` · `.event-card` (+ `.past`) · `.collab-card` / `.collab-chip` · `.section-alt` for alternating band backgrounds.

**Copy conventions:** eyebrow labels are short lowercase-idea phrases in caps ("Ridden, not sponsored", "Rider to rider", "Already said yes"). Headlines are punchy and declarative. Body copy is first-person plural and self-deprecating. Prices are Indonesian format (`Rp 22.000.000`), distances in km.

---

## Content

Seven pages, all in the top-level nav in this order.

### `index.html` — Home
Hero ("We Take It / **Personal.**") with *Join the Squad* + *Collaborate With Us* CTAs → three pillars (Speed / Distance / Frequency) → four numbered tiles linking to Community, Reviews, For Sale, Events → **`#collaborate`** section ("If It's Fun, We're In.") with three offers: invite us to your event, use us for content, ask us to help run it → current-collaborator chips → three-rider Featured Rider spotlight.

### `community.html`
Stat bar: **184 active members · 9 cities · 62,000+ km logged · 37 meetups**. Six rider cards (3 Featured, 3 Member) with city, current wheel, join year, lifetime km. Closes with a "Where We Actually Talk" WhatsApp CTA.

### `featured-riders.html`
Explains the three qualification criteria, then a six-person panel with review counts and star averages: Rangga Wibisono (Jakarta, 12 reviews), Dinda Anjani (Bandung, 8), Teuku Maulana (Surabaya, 10), Ayu Kirana (Jakarta, 6), Wahyu Pradana (Semarang, 19, longest-tenured), Sinta Puspita (Bandung, 5, app/firmware focus).

### `reviews.html`
Filter chips (All / EUC / Scooter / Esk8 / Featured Rider Only — **decorative, not wired up**). Six review cards, each with star rating, three labelled score bars (Power/Range/Build/Value/App-FW) and a "Verified owner · N km on unit" footer. Units covered: Kingsong S22 Pro, Dualtron Thunder 3, Inmotion V13, custom Trampa deck build, Begode Master Pro, Kaabo Wolf Warrior 11.

### `for-sale.html`
Split into **`#brand-new`** (3 listings: Dualtron Mini Special+, helmet + wrist guards, Veteran Sherman-S) and **`#second-hand`** (4 listings: Kingsong S20, Trampa + VESC build, Begode Master Pro, Kaabo Wolf Warrior 11). Each card carries condition notes, a `Rp` price tag, and seller + city + posted-age. Deals are arranged rider-to-rider; there is no checkout. Keep new content in the correct section — do **not** reintroduce a combined New/Used filter.

### `events.html`
**Upcoming:** Sudirman-Thamrin night ride (2 Aug 2026), Volt Rides Demo & Try-Out (16 Aug 2026), Bandung Chapter Gathering (6 Sep 2026).
**Past** (`.event-card.past`): Ancol Sunrise Ride (21 Jun 2026), Battery Safety & Maintenance Clinic (10 May 2026), 3rd Anniversary Ride (14 Mar 2026, 60+ riders). Implies the squad started ~March 2023.

### `sponsors.html`
**Current collaborators** (the five also chipped on the homepage): Volt Rides (retailer), Kinetic Gear Co. (safety gear), Nanjing Wheels ID (brand/review units), Asphalt Supply (parts), Torque Protective (apparel).
**Past collaborators** as a plain name list: Jakarta E-Mobility Expo, RideSafe Indonesia, ChargeUp Stations, Sunrise Skate Co., Bengkel Roda Listrik, Loop Battery Co.

### Cross-page consistency to preserve
The same cast recurs across Community → Featured Riders → Reviews → For Sale (e.g. Rangga rides a Kingsong and sells the S20; Dinda ran the battery clinic and reviews the Dualtron; Teuku builds the Trampa esk8 he later lists). **When editing one page, check whether the same person, unit, or partner appears elsewhere** and keep the details aligned.

### `alternatives/`
`alternatives/kinetic.html` + its own `css/kinetic.css` and `js/kinetic.js` — an unrelated **alternative design direction** ("KINETIC // DIGITAL STRUCTURES", a fictional Berlin studio page: Inter + JetBrains Mono, split-panel brutalist grid, `#FF4800`). It is **self-contained and shares no tokens with the main site**, and is not linked from any page. Don't pull it into PEV Squad edits unless asked.
