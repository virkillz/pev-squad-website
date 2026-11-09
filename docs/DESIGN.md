# PEV Squad Platform — Design Document

**Status:** v0.2 · **Updated:** 2026-11-09 (first draft 2026-11-04) · **Owner:** arifcamp

This doc covers the PEV Squad platform: a backend in Elixir/Phoenix, a website built with Phoenix LiveView (live at https://pev-squad.org), and mobile apps in React Native (next phase).

v0.2 brings the doc in line with what was actually built: Indonesian + English, For Sale listings, news and articles, local-disk uploads, a plain release on a DigitalOcean droplet, and no Oban yet. It also adds the API plan for the mobile app and for admin tools (§7).

---

## 1. Summary

| Decision | Choice |
|---|---|
| Backend | Elixir + Phoenix 1.8, PostgreSQL 16. Background work runs in small supervised GenServers for now (e.g. `Listings.Reminder`); Oban comes in when push notifications need a real queue |
| Web frontend | Phoenix LiveView, using the "Kinetic" design system from the prototype (`backend/assets/css/kinetic.css`) |
| Mobile | React Native via Expo (iOS + Android), talking to a versioned JSON API at `/api/v1` (§7, §10) |
| Auth | Email magic link + optional password (phx.gen.auth). Google and Apple sign-in are planned for the app |
| Content model | Members create content, moderators approve it |
| Language | **Indonesian (default) and English**, via Gettext. Posts store text per language (decision 15) |
| Hosting | One DigitalOcean droplet (Singapore), `mix release` built on the server + systemd + Caddy. See `docs/DEPLOYMENT.md` |
| Email | Brevo (`Swoosh.Adapters.Brevo`), sent from `noreply@pev-squad.org` |

**Shipped on the web:** accounts and rider profiles, events with RSVP and member group rides, reviews and the model catalog, the gallery, partners, news and articles, For Sale listings, reports and blocks, the admin area.
**Next:** the JSON API, then the mobile app (§7, §10, §14).
**Later:** Creators (decision 13, designed but not built), in-app chat if people ask for it.

---

## 2. Goals and non-goals

### Goals
- Replace the Google Form plus CSV workflow (`member pev squad.csv`) with real member accounts that members edit themselves.
- Let members RSVP to rides and events and get push reminders on their phones.
- Let members post reviews and gallery photos, with moderators approving them.
- Keep the current "Kinetic" look (street-brutalist black/white/orange bands, stencil headlines) on web and mobile.
- Keep running costs and maintenance low enough for 1–2 people.

### Non-goals (MVP)
- Payments, escrow or any handling of money.
- Live ride tracking or GPS group rides.
- In-app messaging. The community stays on WhatsApp and Instagram.
- Multi-region or high-availability infrastructure.
- Replacing the WhatsApp group as the main place where people talk.

---

## 3. Architecture

```
                ┌──────────────── DigitalOcean droplet (SGP1) ─────────────────────────┐
 Browser ──────▶│ Caddy (TLS) ──▶ Phoenix app (mix release, systemd)                   │
                │                  ├─ LiveView web   (/)                               │
 RN app  ──────▶│                  ├─ JSON API       (/api/v1)          ◀── planned    │
 (Expo)         │                  ├─ Admin LiveView (/admin)                          │
 CLI / AI ─────▶│                  │   (CLI uses /api/v1/admin)                        │
                │                  └─ GenServers     (listing reminders; Oban later)   │
                │                        │                                             │
                │                   PostgreSQL 16  ·  uploads on local disk            │
                └──────────────────────────────────────────────────────────────────────┘
              Email: Brevo  ·  Push (planned): Expo Push Service → APNs / FCM
              Nightly pg_dump + uploads backups (7 days), pulled off-site with scripts/pull-backups.sh
```

### Why a single Phoenix monolith
- One deployable, one database, one repo. That's right for a team of 1–2.
- The web pages (LiveView), the mobile API and the admin API all call the **same context modules** (`Accounts`, `Events`, `Posts`, `Listings`, `Reviews`, `Gallery`, `Safety`…). Business rules live in one place, and API controllers stay thin.

### Repository layout (monorepo)

```
pev_squad/
├── backend/            # Phoenix app
│   ├── lib/pev_squad/        # contexts: accounts, riders, events, reviews, gallery, partners, posts, listings, safety, uploads
│   ├── lib/pev_squad_web/    # LiveViews, components, controllers (incl. api/), router
│   └── assets/css/           # kinetic.css (from the prototype) + forms.css (app-only UI)
├── mobile/             # Expo app (expo-router, TypeScript), planned
├── scripts/            # pull-backups.sh, and the `pev` API CLI (planned)
└── docs/               # this doc, DEPLOYMENT.md, events.md
```

The static prototype has been removed; it's in git history.

---

## 4. Domain model

### 4.1 Entities

The diagram is the target model. **Not built yet:** `user_identities`, `garage_vehicles` (profiles have a single `primary_pev_type` + `main_ride` for now), `push_devices`, and `users.status`. **Built but not in the diagram:** `blocks`, `rider_affiliations` (rider ↔ partner community), `posts` + `post_translations`, `listings`.

```
users ─1:1─ rider_profiles ─1:N─ garage_vehicles ─N:1─ pev_models
  │                                                       │
  ├─1:N─ user_identities (google, apple)                  ├─1:N─ reviews ─1:N─ review_scores
  ├─1:N─ users_tokens (session, login, change:, api, …)   │
  ├─1:N─ push_devices                                     │
  ├─1:N─ event_rsvps ─N:1─ events ─N:M─ partners          │
  ├─1:N─ photos ─N:1─ albums ─(optional) N:1─ events      │
  └─1:N─ reports (polymorphic target)                     │
```

### 4.2 Tables (main fields)

**users** — `email` (citext, unique), `hashed_password` (nullable), `confirmed_at`, `role` (`member | moderator | admin`), `status` (`active | suspended | deleted`), `inserted_at`

**users_tokens** (phx.gen.auth's table) — `token` (raw for sessions, SHA-256 hash for everything sent outside the server), `context`, `sent_to`, `authenticated_at`. Context `api` rows are personal API tokens and also use `name`, `last_used_at` and `expires_at` (§7.2). Mobile refresh tokens will be context `refresh`.

**user_identities** (planned) — `user_id`, `provider` (`google | apple`), `provider_uid`, `email`. Unique on `(provider, provider_uid)`.

**rider_profiles** — `user_id`, `alias` (unique, shown publicly), `slug`, `full_name` (private), `city`, `bio`, `avatar_photo_id`, `primary_pev_type` (`euc | escooter | esk8 | other`), `total_km` (self-reported), `riding_since` (date), `instagram_handle`, `whatsapp_number` (private, only shown when the member opts in), `is_public` (maps to the CSV column *"Bersedia dicantumkan di website?"*), `featured_rider_since` (nullable)

**pev_models** (catalog) — `type`, `brand`, `model`, `slug`, specs as JSONB (`battery_wh`, `top_speed_kmh`, `weight_kg`, `motor_w`, `suspension`), `hero_photo_id`. Moderators curate it; members can suggest new models.

**garage_vehicles** — `rider_profile_id`, `pev_model_id`, `nickname`, `km`, `acquired_on`, `is_current`. This is what "PEV Utama / Model PEV yang dipakai" from the form turns into.

**events** — `title`, `slug`, `kind` (`ride | tour | meetup | clinic | collab`), `role` (`organizer | collaborator`, from `docs/events.md`), `starts_at`, `ends_at`, `timezone` (default `Asia/Jakarta`), `location_name`, `lat`/`lng` (optional), `meeting_point`, `route_url`, `description`, `cover_photo_id`, `capacity` (nullable), `rsvp_deadline`, `allowed_pev_types` (array), `status` (`draft | published | cancelled | completed`), `created_by_id`

**event_partners** — `event_id`, `partner_id`, `relation` (`co_organizer | sponsor | supporter`). **partners** — `name`, `logo_photo_id`, `url`, `instagram`. These records also back the Sponsors page.

**event_rsvps** — `event_id`, `user_id`, `status` (`going | maybe | not_going | waitlist`), `vehicle_id` (optional: "what are you riding"), `checked_in_at`. Unique on `(event_id, user_id)`.

**reviews** — `pev_model_id`, `author_id`, `title`, `body` (Markdown), `km_on_unit`, `ownership_months`, `overall_score` (stored, computed from the scores), `is_featured_review` (true when the author was a Featured Rider at publish time), `moderation_status`, `published_at`. Unique on `(pev_model_id, author_id)`: one review per model per author, which they can edit.

**review_scores** — `review_id`, `criterion` (`power | range | comfort | build | value | portability`), `score` (0.0–10.0, one decimal, matches the prototype's `9.4`).

**albums** — `title`, `slug`, `event_id` (optional), `cover_photo_id`, `created_by_id`. These are the gallery sections (*Bromo 2026*, *Morning Ride*, …).

**photos** — `uploader_id`, `album_id` (nullable), `storage_key`, `width`, `height`, `blurhash`, `caption`, `variants` (JSONB: `thumb`, `medium`, `large` keys), `moderation_status`.

**posts** — `kind` (`news | article`), `slug` (generated once from the first title, Indonesian first; `-2`, `-3`… when taken), `status` (`draft | published`), `published_at` (a future date schedules it), `topic` (optional: `community | industry | regulation | safety | maintenance | guide | gear | story`), `cover_path`, `source_name` / `source_url` (outside news), `event_id` (a recap), `author_id`.

**post_translations** — `post_id`, `locale` (`id | en`), `title`, `excerpt`, `body` (Markdown), `machine_translated`. Unique on `(post_id, locale)`. See decision 15.

**reports** — `reporter_id`, `target_type`, `target_id`, `reason`, `notes`, `status`, `resolved_by_id`.

**push_devices** — `user_id`, `expo_push_token`, `platform`, `last_seen_at`.

**listings** — `kind` (`member | official`; only member listings exist so far), `seller_id`, `title`, `category` (`euc | escooter | esk8 | ebike | parts | gear | other`), `condition` (`new | like_new | used | for_parts`), `price_idr` (integer), `negotiable`, `quantity` (default 1), `city`, `km` (optional), `description`, `whatsapp` / `instagram` (at least one), `photos` (JSONB, 1–5 processed images), `status` (`pending | approved | rejected`), `rejection_reason`, `moderated_by_id`, and the timestamps that decide visibility: `approved_at`, `last_checked_at`, `reminded_at`, `sold_at`, `hidden_at`, `deleted_at`. See decision 16.

### 4.3 Featured Riders (switched off — see decision 14)

The prototype's rule is **at least 5,000 km, at least 1 year active, and more than one unit owned**. The system works out who is eligible from the profile and garage data and lists them for admins. **An admin grants the badge by hand**, because the numbers are self-reported. Reviews posted while the author holds the badge get `is_featured_review = true` and count more in model averages. MVP weighting: Featured reviews ×2, community reviews ×1. Both web and app show the averages split into "Featured" and "Community" columns, the same way the prototype shows them.

---

## 5. Members create, moderators approve

| Content | New member (default) | Trusted member* | Moderator/Admin |
|---|---|---|---|
| Profile and garage | Live right away; can be reported | Live | Can edit or hide |
| Reviews | `pending` until a moderator approves | Live right away | Approve or reject |
| Gallery photos | `pending` | Live right away | Approve or reject |
| Events | Can propose (`draft`); only moderators publish | Same | Create and publish |
| RSVP | Allowed | Allowed | Can manage attendees |

\* "Trusted" = at least 2 approved posts and no upheld reports, or a manual flag. This keeps the moderation queue small.

- **Moderation queue** in `/admin/moderation`, LiveView with live updates over PubSub so two moderators don't review the same item.
- **Report and block** on every piece of user content and every profile. **The app stores require this for apps with user-generated content** (Apple App Review Guideline 1.2, Google Play's UGC policy).
- Planned: moderators get a notification (email or push) when the queue has items older than 24 hours.

---

## 6. Authentication

Built on `mix phx.gen.auth` (Phoenix 1.8 includes **magic link + optional password** and sudo mode out of the box). The web has email magic link + password today. Everything in the Mobile column, and Google/Apple on the web, is planned.

| Method | Web | Mobile |
|---|---|---|
| Email + password | phx.gen.auth ✓ | `POST /api/v1/auth/password` |
| Magic link | phx.gen.auth ✓ (`/users/log-in/:token`) | Email link opens the app through a universal link / app link (`https://pev-squad.org/users/log-in/:token`); the app exchanges the token for API tokens |
| Google | OAuth redirect via `assent` | Native sign-in with `@react-native-google-signin`; the app sends the **ID token** to `POST /api/v1/auth/google`; the backend checks it against Google's JWKS (`joken`/`jose`) |
| Apple | OAuth redirect via `assent` | `expo-apple-authentication`; the app sends the ID token to `POST /api/v1/auth/apple`; the backend checks it against Apple's JWKS. **Required by Apple once Google sign-in is offered** |

**Linking accounts:** if a social login comes back with an email that's verified and matches an existing user, attach a `user_identity` to that user instead of creating a second account. Apple's "Hide My Email" relay addresses are treated as different emails, so those users can link accounts by hand in Settings.

**API tokens:** see §7.2. There are personal API tokens for staff tools (built) and access + refresh tokens for the app (planned).

**Account deletion:** in-app (an Apple requirement; `DELETE /api/v1/me`, needs a login in the last 20 minutes) and by staff in `/admin/members`. It is immediate and uses the same steps as the admin delete: upcoming RSVPs are cancelled, hosted group rides removed (riders emailed), and photos, listings, reviews, profile, tokens and blocks deleted. A member deleting themselves also removes an imported profile they claimed. Admins can't delete their own account. Not built yet: the web settings button, and the earlier idea of a 30-day grace period with reviews kept as "Deleted rider".

---

## 7. API (mobile app and admin tools)

One JSON API serves two clients: the **mobile app**, and **staff tools** (the `pev` CLI, which an AI assistant such as Claude Code can drive to draft events, news and articles from a laptop). The two share one foundation: auth, errors, locale and the OpenAPI spec. Controllers live in `PevSquadWeb.API.*` and only call context functions.

### 7.1 Conventions

- REST + JSON under `/api/v1`, with `Authorization: Bearer <token>`. Breaking changes go to `/api/v2`; older app builds stay in the stores for months.
- **OpenAPI spec via `open_api_spex`**, served at `GET /api/v1/openapi` (Swagger UI at `/dev/swaggerui` in development). The app generates a typed TypeScript client from it (`openapi-typescript` + `openapi-fetch`), so the contract can't quietly drift between backend and app.
- **Errors** always look like `{"error": {"code": "validation_failed", "message": "…", "fields": {"title": ["can't be blank"]}}}`. Codes: `unauthorized` 401, `forbidden` 403, `not_found` 404, `validation_failed` 422, later `rate_limited` 429. `fields` only appears on 422.
- **Language:** `?locale=id|en`, else `Accept-Language`, else Indonesian. It applies to translated text (post translations, labels) and error messages. The response sets `Content-Language`. The app sends the device or in-app language choice. There's no session on the API, so the web's session-based locale doesn't apply.
- **Times** are ISO 8601 in UTC. Events also return their `timezone` (`Asia/Jakarta`…) so the app shows local time.
- **Images** are absolute URLs (`https://pev-squad.org/uploads/…`).
- Public lists use **cursor pagination** (`?after=<cursor>&limit=20`, response `{"data": [...], "next": "<cursor>|null"}`), added with the first list endpoint.
- Real-time updates (live RSVP counts) can come later over Phoenix Channels, if people want them. The app refetches on screen focus and pull-to-refresh (TanStack Query).

### 7.2 Tokens

| Kind | Who | Format and lifetime | Storage |
|---|---|---|---|
| **Personal API token** (built) | Staff only (moderator/admin) | `pevsq_` + 43 random URL-safe chars, shown **once**. Expires after 1 year, revocable at any time | SHA-256 hash in `users_tokens`, context `api`, with `name` (e.g. "MacBook CLI"), `last_used_at`, `expires_at` |
| **Access token** (planned, app) | Any member | `Phoenix.Token`-signed, 15 minutes | Not stored |
| **Refresh token** (planned, app) | Any member | Random, 60 days, rotated on every use | Hashed in `users_tokens`, context `refresh`. Logging out deletes it |

- Staff create and revoke personal tokens at `/admin/api-tokens`. Creating one requires a recent login (sudo mode), and staff only see and revoke their own tokens.
- Both kinds produce a normal `%Scope{}`, so authorization is the same as on the web: staff-only endpoints check `Scope.staff?/1`, whatever the token type.
- Changing a user's role takes effect on the next request, because the scope is loaded from the database every time.
- App tokens live in `expo-secure-store`. The CLI reads `PEV_API_TOKEN` from the environment and never writes it to a file in the repo.

### 7.3 Endpoints

| Area | Endpoints | Status |
|---|---|---|
| Spec | `GET openapi` | Built (step 1) |
| Me | `GET me` | Built (step 1) |
| Admin content | `GET/POST admin/posts`, `GET/PATCH admin/posts/:id` (id or slug), `POST admin/posts/:id/cover`, `GET/POST admin/events`, `GET/PATCH admin/events/:id`, `GET admin/partners`, `POST admin/uploads` (multipart image) | Built (step 2) |
| Public read | `GET events?when=upcoming\|past&category=`, `GET events/:slug`, `GET posts?kind=news\|article`, `GET posts/:slug`, `GET listings`, `GET listings/:id`, `GET partners`, `GET partners/:slug`, `GET pev_models`, `GET pev_models/:slug`, `GET reviews`, `GET reviews/:id`, `GET albums`, `GET albums/:slug` | Step 3 |
| Auth | `POST auth/password`, `auth/magic_link`, `auth/magic_link/exchange`, `auth/google`, `auth/apple`, `auth/refresh`, `DELETE auth/session` | Step 4 |
| Me (more) | `PATCH me` (incl. `locale`), `GET/PATCH me/profile`, `POST me/push_devices`, `DELETE me` | Step 4 |
| Member actions | `PUT/DELETE events/:slug/rsvp`, `GET events/:slug/attendees`, `POST/PATCH reviews`, `POST albums/:slug/photos`, `POST/PATCH listings`, `POST listings/:id/still_available`, … | Step 5 |
| Safety | `GET reports/reasons`, `POST reports` (with optional `block`), `GET blocks`, `POST blocks`, `DELETE blocks/:user_id`. Targets are `{target_type, target_id}`; the server finds the owner | Built |

**Admin content rules (step 2):** the API **creates and edits drafts only**. Publishing (and scheduling with a future `published_at`) stays a click in `/admin`, so nothing written by a script or an AI goes live without a person reading it.

- Sending `status` or `published_at` is a 422. Changing a published post or event, or any group ride, is a 409 `conflict`.
- Post translations are an object keyed by language. A PATCH only touches the languages it sends, and `null` deletes one. Translations written through the API default to `machine_translated: true`.
- Event times may carry an offset or be local to the event's `timezone`. Responses give UTC plus a `local` block.
- Admin lists aren't paginated (staff lists are small).

**The `pev` CLI** (`scripts/pev`, Python 3 standard library only) wraps these endpoints for people and AI assistants. Posts round-trip as Markdown files with front matter and `=== id ===` / `=== en ===` sections; local images in the body and the `cover:` are uploaded automatically. See `scripts/pev --help` and the CLAUDE.md section on drafting content.

---

## 8. Media pipeline

**Today:** uploads arrive through LiveView, are processed straight away with the `image` library (libvips: autorotate, resize, WebP, metadata including GPS stripped), and are written to local disk at `UPLOADS_DIR` (`/var/lib/pev_squad/uploads` in prod, backed up nightly) and served at `/uploads`. The sizes per feature are in decisions 5, 9, 12, 15 and 16. The API will accept multipart uploads into the same processing modules (`Gallery.Processing`, `Listings.Processing`, `Posts.Images`…), so phones and the web produce identical files.

**Later, if disk or bandwidth on the droplet becomes a problem:** move to object storage with direct uploads:

1. The client asks `POST /uploads/presign` for a presigned PUT URL to `uploads/tmp/<uuid>`.
2. The client uploads the file straight to R2 or Spaces. The image never passes through the VPS, which keeps bandwidth and memory low.
3. The client calls `POST /photos` with the key. The backend creates the photo row and queues an `ImageVariantsWorker` (Oban) job.
4. The worker uses the `image` library (libvips) to strip EXIF/GPS data, generate `thumb` (400px), `medium` (1200px) and `large` (2048px) WebP versions plus a blurhash, and write them to `photos/<id>/…`.
5. Images are served from the object storage's public CDN domain (e.g. `img.pev-squad.org`).

Limits: 15 MB per upload, JPEG/PNG/HEIC/WebP only, and a per-user daily upload cap to stop abuse.

---

## 9. Web (Phoenix LiveView)

- Pages: `/`, `/about`, `/community` (+ `/community/:slug`), `/partners/:slug`, `/events` (+ `/events/:slug`, `/group-rides/new`), `/reviews` (+ `/reviews/:id`, `/reviews/new`), `/models/:slug`, `/gallery` (+ `/gallery/:slug`), `/news`, `/articles` (+ `/:slug`), `/for-sale` (+ `/for-sale/:id`, `/mine`, `/new`), `/feed.xml`. `/riders` redirects to `/community` (decision 14). The router is the source of truth.
- The nav and footer that are copy-pasted across every prototype page become **layout components** (`<.site_header>`, `<.site_footer>`), which ends the "update all seven files" rule.
- The prototype's `kinetic.css` was ported unchanged into `assets/css/` and imported into Tailwind's `components` layer, so Tailwind spacing utilities still work alongside it. `forms.css` adds Kinetic-style inputs, flashes, tables and panels for screens the prototype didn't have. daisyUI has been removed because its `.btn`, `.card`, `.hero` and `.badge` clashed with Kinetic. The heroicons plugin's `hero-*` classes are reserved, which is why the prototype's `.hero-tag` became `.hero-scribble`.
- The Kinetic design has no light/dark toggle, so there's no theme script.
- Public pages render on the server and can be cached. Each has `<meta>`/OpenGraph tags (event pages share well on WhatsApp). Pages are reachable without logging in; RSVP, posting and profile editing need a login.
- **Admin** at `/admin` (English only, hand-written LiveViews): events, members and roles, rider profiles, review / photo / listing queues, reports, model catalog, albums, partners, news & articles, API tokens.

---

## 10. Mobile (React Native / Expo)

- **Expo SDK (latest stable) + expo-router + TypeScript**, built and released with **EAS Build / EAS Submit**. **EAS Update** pushes JS-only fixes over the air.
- Libraries: TanStack Query (server state), the generated OpenAPI client, `expo-secure-store`, `expo-image` (with blurhash placeholders), `expo-image-picker`, `expo-notifications`, `expo-calendar` ("add ride to calendar"), `react-native-reanimated`.
- **Design tokens** taken from `kinetic.css` `:root` into `mobile/src/theme/tokens.ts` (`orange #FF4800`, black, white, `bw: 2`). Fonts Big Shoulders Stencil Display, Inter, JetBrains Mono and Permanent Marker load via `expo-font`.

- **Languages:** Indonesian and English, using the same rule as the web (device language, can be changed in-app, saved to `users.locale` once logged in). App strings use `i18next` / `expo-localization`; content comes from the API already translated (§7.1).
- **Deep links:** universal links (iOS) and app links (Android) on `pev-squad.org` for `/events/:slug`, `/news/:slug`, `/articles/:slug`, `/for-sale/:id` and `/users/log-in/:token`. This needs `apple-app-site-association` and `assetlinks.json` served from the backend. Links shared in WhatsApp open in the app when it's installed, otherwise on the website.

**Tabs:** Home (next ride, latest news) · Events · News · For Sale · Profile. Reviews and the gallery are reached from Home and Profile, and can become tabs later if people use them.

**Key flows**
1. Onboarding: sign in, then set alias, city and main PEV, then "show me on the website?" (consent)
2. Event detail: RSVP, add to calendar, open the meeting point in Maps, share link
3. News and articles: read in the chosen language, with the "machine translated" note the web shows
4. For Sale: browse, contact the seller (WhatsApp / Instagram, logged-in only), post a listing with photos, tap "Still available"
5. Write a review: pick a model from the catalog, enter scores per criterion and the text, then show "pending approval"
6. Upload photos to an open album
7. Push notifications: event reminder (24h and 2h before), RSVP waitlist promotion, review / listing approved or rejected, listing about to lapse, new event published

Push goes through the **Expo Push API**, sent from a background job (Oban comes in here). Tokens that get `DeviceNotRegistered` receipts are deleted.

**Store requirements, built in from the start:** report and block on all member content (reviews, photos, listings, group rides, profiles), in-app account deletion, Sign in with Apple if Google sign-in ships, privacy policy URL, Apple privacy labels / Play Data Safety form.

**Releases:** EAS Build profiles `development`, `preview` (internal testers via TestFlight and Play internal testing) and `production`. EAS Update for JS-only fixes, on a channel per app version, so a fix never reaches a build whose native code doesn't match.

---

## 11. Infrastructure and operations (VPS)

What runs today is in `docs/DEPLOYMENT.md`, which is the runbook. In short:

- **Server:** one DigitalOcean droplet in Singapore (1 vCPU / 1 GB + 2 GB swap), Ubuntu 24.04.
- **Deploy:** push to `main`, then `ssh deploy@… ./deploy.sh`. It builds the release on the server, migrates, restarts the systemd service and health-checks.
- **Postgres 16** on the same box. **Backups:** nightly `pg_dump` + uploads at 03:00 WIB, kept 7 days, pulled off-site with `scripts/pull-backups.sh`.
- **TLS:** Caddy with Let's Encrypt.
- **Email:** Brevo, with DKIM on the domain.

**Still to do before the app launches:** error tracking (Sentry for backend + RN), an external uptime check, rate limiting on `/api/v1/auth/*` and uploads, and probably a droplet with 2 GB RAM once the API and push jobs add load. CI (`mix precommit` on PRs; `tsc`/`eslint`/`jest` for mobile) and a staging environment are nice-to-haves for a team of one.

**Running costs:** droplet ~$6–12/month + Brevo free tier + Apple Developer $99/year + Google Play $25 one-time.

---

## 12. Privacy and compliance

- **Indonesia PDP Law (UU 27/2022):** say clearly why we collect each piece of data, get explicit consent before showing a profile publicly, let members export and delete their data, and keep a privacy policy page.
- Full name, email and WhatsApp number are private by default. Public profiles show alias, city, PEVs, bio and photo.
- Location is stored at city level only for members. Event locations are public.
- EXIF/GPS data is stripped from every uploaded photo.
- App store checklist: Sign in with Apple (required if we offer Google sign-in), in-app account deletion, UGC report/block, privacy nutrition labels / Play Data Safety form.

---

## 13. Migrating existing data

A one-off `mix pev_squad.import` task:
1. **Members** from `member pev squad.csv`: create a `rider_profile` with alias, city, PEV type/model and bio. **Only rows where *"Bersedia dicantumkan di website?"* = yes** get `is_public = true`. Photos were copied from the prototype's `images/community/` (since removed from the repo). Profiles start **unclaimed**, with no login attached.
2. **Claiming a profile:** a member signs up with the email from the form and gets offered "Is this you?" for the matching profile. A moderator can also link profiles by hand.
3. **Events** from `docs/events.md` (role, partners, sponsors, location, notes) → `events` + `partners` + `event_partners`.
4. **Reviews, featured riders, gallery albums:** the prototype content is placeholder data (per the prototype's `SUMMARY.md`, now removed), so import only the real items. The PEV model catalog gets seeded by hand.

The CSV has personal data in it and should not be committed to git. Add it to `.gitignore` and keep it outside the repo.

---

## 14. Delivery plan

The web launched first, as planned for a single developer. The API and the app come next, in this order:

| Step | Backend | Mobile |
|---|---|---|
| 1 | **API foundation:** `/api/v1` pipeline, bearer-token auth, error format, API locale, OpenAPI spec, personal API tokens + `/admin/api-tokens`, `GET me` | |
| 2 | **Admin content API** (posts, events, uploads; drafts only) + the `pev` CLI in `scripts/`, documented in CLAUDE.md | |
| 3 | Public read endpoints (events, posts, listings, partners, models, reviews, albums) with pagination | Expo project in `mobile/`, Kinetic theme tokens and fonts, navigation shell, generated API client, read-only screens |
| 4 | App auth (magic link exchange, password, refresh tokens; Google/Apple if chosen), `me` / profile endpoints, deep-link files | Login, onboarding, profile, language switch |
| 5 | RSVP, reviews, photo and listing uploads, reports and blocks, account deletion; Oban + push | The matching screens, push registration, notifications |
| 6 | Sentry, rate limiting, uptime check | TestFlight + Play internal testing with ~10 squad members, then store submission (allow 1–2 weeks for review) |

---

## 15. Risks

| Risk | Mitigation |
|---|---|
| A single VPS is a single point of failure | Nightly backups pulled off-site, a scripted deploy (`deploy.sh`) that can rebuild on a fresh droplet, uptime alerts (to add). Fine for a community app. |
| App store rejection (UGC, account deletion, Apple sign-in) | Build those in from the start (§12). Submit for review early in week 11. |
| Moderation burden on volunteers | Trusted-member auto-approval, 24h queue alert, more than one moderator. |
| Low adoption because the community lives on WhatsApp | Make sharing to WhatsApp easy (OG previews, `wa.me` share buttons). RSVP links get posted in the WA group. |
| Scope creep (marketplace, chat, ride tracking) | Explicit Phase 2 list. Ship the MVP first. |

---

## 16. Decisions log

| # | Question | Decision (2026-11-04) |
|---|---|---|
| 1 | Domain | **`https://pev-squad.org`**. Images at `img.pev-squad.org`, email sent from `@pev-squad.org`, universal/app links on the apex domain. |
| 2 | Moderators | **arifcamp (admin) plus selected members** as moderators. Admins promote members to the moderator role in `/admin`. |
| 3 | Limited-slot RSVP | **First come, first served.** When `capacity` is set, a `going` RSVP is accepted while seats remain; after that it becomes `waitlist`. When someone cancels, the earliest waitlisted RSVP gets promoted automatically and notified. The seat check runs inside a DB transaction with a row lock on the event, so two people can't take the last seat. |

| 4 | Claiming imported profiles | The sign-up form had no email column, so imported profiles start **unclaimed**. Once a rider registers, staff link the profile to their account at `/admin/riders`. A self-service "this is me" request can come later. |
| 5 | Avatar storage (interim) | Until the R2 media pipeline exists, avatars are processed with libvips (4:5 crop, WebP, metadata including GPS stripped) and stored on local disk (`UPLOADS_DIR`, a persistent volume on the VPS), served at `/uploads`. HEIC isn't accepted, so iPhones convert photos to JPEG on upload. |

| 6 | Review criteria (default, change if needed) | **Power, Range, Comfort, Build, Value** (required) plus **App/FW** (optional), each 0–10 with one decimal. A review's overall score is the average of the criteria it scored. Taken from the prototype, with Comfort added. |
| 7 | ~~Featured weighting~~ (superseded by 14) | Featured reviews count **×2** in a model's overall score. The Sheet also shows the Featured and Community averages **separately**, like the prototype. "Featured" is fixed when a review is published, based on the author's badge at that moment. |
| 8 | Review moderation | Reviews from new members wait for a moderator. **Staff and members with 2 or more published reviews publish straight away**, unless the model is new, in which case the moderator approves both together. Rejections require a reason, which is emailed to the author. Editing a rejected review sends it back to the queue. |
| 9 | Gallery moderation | Staff create albums and choose which are open for member uploads. Members' photos wait for a moderator until they have **3 approved photos**, then go live straight away. **A rejected photo is deleted** (row and files) rather than kept. Uploads are processed into a 2048px large and an 800px thumb, both WebP with metadata stripped. Tiles can be normal, big (2×2) or wide (2×1), as in the prototype. |
| 10 | Reporting and blocking | Members can report reviews, photos and profiles, with a reason and an optional note, at most one open report per item. **3 different reporters automatically hide a review or photo** until staff dismiss the reports (which restores it) or remove it. Profiles are flagged only. Blocking hides the blocked member's profile, reviews and photos from the blocker. Model scores on the Sheet still include them. |
| 11 | Group rides (2026-11-05) | Member-hosted rides live in the **same `events` table**, with a `category` column: `official` (PEV Squad organizes or collaborates; `role` still applies) or `group_ride` (hosted by the member in `created_by`). Group rides reuse RSVP, capacity, waitlist and time zones. Any member with a rider profile can host. They **go live immediately**, with reports as the safety net (3 reporters hide one, as for reviews and photos). Limits: kinds ride / night ride / trail ride / meetup only, capacity required (max 30), at most 3 upcoming per host. The host edits, cancels (RSVPs are emailed) and sees the rider list; staff can do the same. Pages label them "Group ride · hosted by @alias" with a note that PEV Squad doesn't organize them. `/events` shows both with an All / Official / Group rides filter. |
| 12 | The Network (2026-11-05) | The community page gains three parts: **Partner Communities** (REJS, Eastlectric, Jogwheel, SNOI, Eboard Indonesia…), **Brand Partners** and **Creators**. "Affiliate" is avoided because in Indonesia it reads as commission selling. Communities and brands share a `partners` table (`kind`, logo, description, region, vehicle focus, links, partner since, collaboration type and note), managed by staff. Events link to partners through an `event_partners` table, so partner pages list their collaboration history ("4 events together"). The free-text `events.partners` stays for names without a partner page (shown after the logo chips). Pages: community page sections, `/partners/:slug`, and `/admin/partners` with logo upload (fitted inside 600×600, WebP, transparency kept). |
| 13 | Creators (2026-11-05) | A creator is a **media identity, not a person**: "arifvirkill" and "Voltasi" are two creators. Tables: `creators` (name, slug, kind `personal`/`media`, avatar, bio, niche), `creator_channels` (one-to-many: platform, handle, url, followers, `checked_on`) and `creator_members` (many-to-many with users, role `owner`/`host`). So one member can run several creators, a media creator can have several members, and a creator with no linked member is a non-member listed by staff, who can link a member later (the same claim flow as imported profiles). Members add their own creators; staff approve before they're listed. Follower counts are self-reported, shown with their "as of" date, and summed as "combined followers" on the Creators header. |
| 14 | Featured Riders switched off (2026-11-05) | The Featured Rider badge, the `/riders` page (now redirects to `/community`), the home page spotlight and the badges are removed; Creators (decision 13) cover showcasing members instead. **Every review counts equally**: the Sheet and model pages show one average, with no Featured/Community split, and the "Featured Rider Only" filter is gone. The `rider_profiles.featured_since` and `reviews.featured` columns are kept, unused, so the badge can come back without a migration. |
| 15 | News & articles (2026-11-09) | One `posts` table with `kind` **news** (dated: recaps, announcements, outside news with a source) or **article** (evergreen: guides, safety, maintenance, rider stories), at `/news` and `/articles`. Staff write them; member submissions can come later through the review-style moderation flow. **Text is stored per language** in `post_translations`, so a post can have Indonesian, English or both (English is expected to come from AI translation, flagged `machine_translated` and labelled on the page until a person checks it). Readers get their language, else Indonesian, else whatever exists, with a note saying so; lists never hide a post for a missing language. Both languages share one URL; `?locale=` switches and `hreflang` alternates are emitted when both exist. Bodies are Markdown rendered with MDEx (raw HTML dropped, output sanitized). Images are 1600px WebP with metadata stripped, in `uploads/posts`. A recap links to its event and shows on the event page. The home page "Latest" block shows the two newest posts. RSS at `/feed.xml`. |
| 16 | For Sale, member listings (2026-11-09) | Only members with an **active** rider profile (and staff) can sell. **Every listing waits for a moderator** at `/admin/listings`; rejections need a reason, emailed to the seller. On an approved listing, price, quantity, city and contact can change freely; changing title, category, condition, description or photos sends it back to the queue. **Decay**: a listing stays on the board for **7 days after the seller last tapped "Still available"** (the clock starts at approval); one reminder email goes out 2 days before it lapses (hourly `Listings.Reminder` worker). An expired listing comes back with one tap, unless it has been off for over 30 days, which sends it back to review. **Sold** listings stay on the board, marked sold, for 7 days. Sellers can hide/unhide and delete (soft delete, kept for disputes). Visibility is computed from timestamps, so nothing has to flip statuses on a timer. Buyers contact the seller over **WhatsApp or Instagram DM**, shown only to logged-in members; no payments in the app. No per-member listing limit. Photos: 1600px + 800px WebP, metadata (GPS) stripped, in `uploads/listings`. Listings from banned or inactive sellers and from blocked members are left out. PEV Squad's own "official" listings come later (`kind` column is ready). |
| 17 | One API for the app and admin tools (2026-11-09) | The mobile app and staff tooling share **one `/api/v1`** (§7) rather than a separate admin API. Staff tooling means the `pev` CLI, which an AI assistant like Claude Code drives through the shell; that was preferred over an MCP server, which can be added later on top of the same endpoints if we want to post from the Claude desktop or web app. Staff authenticate with **personal API tokens** (hashed in `users_tokens`, context `api`, 1-year expiry, created at `/admin/api-tokens` after re-authenticating). The admin content API writes **drafts only**; publishing stays manual in `/admin`. Running code in prod over `bin/pev_squad rpc` is kept for emergencies, not routine content. |


## 17. Open questions

1. **Review criteria:** confirm the defaults in decision 6.
2. **Marketplace phase 2:** are dealers / sponsors allowed to post brand-new listings, and do they need a separate "shop" account type?
3. **App v1 scope:** read-only first (events, news, For Sale), with login and RSVP in an update, or login + RSVP from the first release?
4. **App sign-in methods:** magic link + password only at first, or Google and Apple as well? (Apple sign-in becomes required as soon as Google is offered.)
5. **Store accounts:** personal or organization developer accounts? An organization account (listing under the "PEV Squad" name) needs a D-U-N-S number, which can take weeks.
