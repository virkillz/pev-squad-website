# PEV Squad Platform — Design Document

**Status:** Draft v0.1 · **Date:** 2026-11-04 · **Owner:** arifcamp

This doc covers turning the static PEV Squad prototype into a real platform: a backend in Elixir/Phoenix, a website built with Phoenix LiveView, and mobile apps in React Native.

---

## 1. Summary

| Decision | Choice |
|---|---|
| Backend | Elixir + Phoenix 1.8, PostgreSQL, Oban for background jobs |
| Web frontend | Phoenix LiveView, porting the prototype's "Kinetic" design system (`css/kinetic.css`) |
| Mobile | React Native via Expo (iOS + Android), talking to a versioned JSON API |
| Auth | Email + password, email magic link, Google and Apple sign-in |
| Content model | Members create content, moderators approve it |
| Language | English only (strings still go through Gettext so we can add Indonesian later) |
| Hosting | A single VPS in Singapore or Jakarta, Docker + Kamal, Caddy for TLS |
| Team / timeline | 1–2 developers, about 12 weeks to the MVP |

**MVP scope:** accounts and rider profiles, events with RSVP, reviews, and the gallery.
**Phase 2:** marketplace (buyers contact the seller over WhatsApp, no payments in the app), Indonesian translation, in-app chat if people ask for it.

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
                ┌──────────────────────────── VPS (SG/JKT) ────────────────────────────┐
 Browser ──────▶│ Caddy (TLS) ──▶ Phoenix app (mix release, Docker)                    │
                │                  ├─ LiveView web  (/)                                │
 RN app  ──────▶│                  ├─ JSON API      (/api/v1)                          │
 (Expo)         │                  ├─ Admin LiveView (/admin)                          │
                │                  └─ Oban workers  (push, email, image variants)      │
                │                        │                                             │
                │                   PostgreSQL 17  (app data + Oban queue)             │
                └────────────────────────┼──────────────────────────────────────────── ┘
                                         │
              Object storage (Cloudflare R2 / DO Spaces) ◀── direct uploads via presigned URLs
              Email (Postmark / Resend / SES)   Expo Push Service → APNs / FCM
              Error tracking (Sentry or AppSignal)  ·  Off-site DB backups → object storage
```

### Why a single Phoenix monolith
- One deployable, one database, one repo. That's right for a team of 1–2.
- The web pages (LiveView) and the mobile API (JSON controllers) both call the **same context modules** (`Accounts`, `Events`, `Reviews`, `Gallery`, `Moderation`). Business rules live in one place.
- Oban runs jobs on the Postgres we already have, so there's no Redis or extra queue to run.

### Repository layout (monorepo)

```
pev_squad/
├── prototype/          # current static HTML/CSS/JS, kept as the visual reference until the LiveView pages match it
├── backend/            # Phoenix app (mix phx.new pev_squad --database postgres)
│   ├── lib/pev_squad/        # contexts: accounts, profiles, events, reviews, gallery, moderation, media
│   ├── lib/pev_squad_web/    # LiveViews, components, API controllers, router
│   └── assets/css/           # kinetic.css (from the prototype) + forms.css (app-only UI)
├── mobile/             # Expo app (expo-router, TypeScript)
├── docs/               # this doc, ADRs, API notes
└── .github/workflows/  # CI for backend + mobile
```

Moving the current site into `prototype/` is a one-time step. Until the LiveView pages are live, the static site can stay deployed as it is.

---

## 4. Domain model

### 4.1 Entities

```
users ─1:1─ rider_profiles ─1:N─ garage_vehicles ─N:1─ pev_models
  │                                                       │
  ├─1:N─ user_identities (google, apple)                  ├─1:N─ reviews ─1:N─ review_scores
  ├─1:N─ user_tokens (session, magic link, api)           │
  ├─1:N─ push_devices                                     │
  ├─1:N─ event_rsvps ─N:1─ events ─N:M─ partners          │
  ├─1:N─ photos ─N:1─ albums ─(optional) N:1─ events      │
  └─1:N─ reports (polymorphic target)                     │
```

### 4.2 Tables (main fields)

**users** — `email` (citext, unique), `hashed_password` (nullable), `confirmed_at`, `role` (`member | moderator | admin`), `status` (`active | suspended | deleted`), `inserted_at`

**user_identities** — `user_id`, `provider` (`google | apple`), `provider_uid`, `email`. Unique on `(provider, provider_uid)`.

**rider_profiles** — `user_id`, `alias` (unique, shown publicly), `slug`, `full_name` (private), `city`, `bio`, `avatar_photo_id`, `primary_pev_type` (`euc | escooter | esk8 | other`), `total_km` (self-reported), `riding_since` (date), `instagram_handle`, `whatsapp_number` (private, only shown when the member opts in), `is_public` (maps to the CSV column *"Bersedia dicantumkan di website?"*), `featured_rider_since` (nullable)

**pev_models** (catalog) — `type`, `brand`, `model`, `slug`, specs as JSONB (`battery_wh`, `top_speed_kmh`, `weight_kg`, `motor_w`, `suspension`), `hero_photo_id`. Moderators curate it; members can suggest new models.

**garage_vehicles** — `rider_profile_id`, `pev_model_id`, `nickname`, `km`, `acquired_on`, `is_current`. This is what "PEV Utama / Model PEV yang dipakai" from the form turns into.

**events** — `title`, `slug`, `kind` (`ride | tour | meetup | clinic | collab`), `role` (`organizer | collaborator`, from `events.md`), `starts_at`, `ends_at`, `timezone` (default `Asia/Jakarta`), `location_name`, `lat`/`lng` (optional), `meeting_point`, `route_url`, `description`, `cover_photo_id`, `capacity` (nullable), `rsvp_deadline`, `allowed_pev_types` (array), `status` (`draft | published | cancelled | completed`), `created_by_id`

**event_partners** — `event_id`, `partner_id`, `relation` (`co_organizer | sponsor | supporter`). **partners** — `name`, `logo_photo_id`, `url`, `instagram`. These records also back the Sponsors page.

**event_rsvps** — `event_id`, `user_id`, `status` (`going | maybe | not_going | waitlist`), `vehicle_id` (optional: "what are you riding"), `checked_in_at`. Unique on `(event_id, user_id)`.

**reviews** — `pev_model_id`, `author_id`, `title`, `body` (Markdown), `km_on_unit`, `ownership_months`, `overall_score` (stored, computed from the scores), `is_featured_review` (true when the author was a Featured Rider at publish time), `moderation_status`, `published_at`. Unique on `(pev_model_id, author_id)`: one review per model per author, which they can edit.

**review_scores** — `review_id`, `criterion` (`power | range | comfort | build | value | portability`), `score` (0.0–10.0, one decimal, matches the prototype's `9.4`).

**albums** — `title`, `slug`, `event_id` (optional), `cover_photo_id`, `created_by_id`. These are the gallery sections (*Bromo 2026*, *Morning Ride*, …).

**photos** — `uploader_id`, `album_id` (nullable), `storage_key`, `width`, `height`, `blurhash`, `caption`, `variants` (JSONB: `thumb`, `medium`, `large` keys), `moderation_status`.

**reports** — `reporter_id`, `target_type`, `target_id`, `reason`, `notes`, `status`, `resolved_by_id`.

**push_devices** — `user_id`, `expo_push_token`, `platform`, `last_seen_at`.

Phase 2 adds **listings** (`seller_id`, `pev_model_id`, `condition` `brand_new | second_hand`, `price_idr` as an integer, `km`, `city`, `photos`, `status` `active | sold | expired`, `contact_whatsapp`). The web page keeps the `#brand-new` and `#second-hand` sections from the prototype.

### 4.3 Featured Riders

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
- Moderators get an Oban notification (email or push) when the queue has items older than 24 hours.

---

## 6. Authentication

Built on `mix phx.gen.auth` (Phoenix 1.8 includes **magic link + optional password** and sudo mode out of the box).

| Method | Web | Mobile |
|---|---|---|
| Email + password | phx.gen.auth | `POST /api/v1/auth/password` |
| Magic link | phx.gen.auth | Email link opens the app through a universal link / app link (`https://pev-squad.org/auth/magic/:token`); the app exchanges the token for API tokens |
| Google | OAuth redirect via `assent` | Native sign-in with `@react-native-google-signin`; the app sends the **ID token** to `POST /api/v1/auth/google`; the backend checks it against Google's JWKS (`joken`/`jose`) |
| Apple | OAuth redirect via `assent` | `expo-apple-authentication`; the app sends the ID token to `POST /api/v1/auth/apple`; the backend checks it against Apple's JWKS |

**Linking accounts:** if a social login comes back with an email that's verified and matches an existing user, attach a `user_identity` to that user instead of creating a second account. Apple's "Hide My Email" relay addresses are treated as different emails, so those users can link accounts by hand in Settings.

**Mobile tokens:** a short-lived access token (15 minutes, signed with `Phoenix.Token`) plus a long-lived refresh token (60 days, rotated on every use, stored hashed in `user_tokens`). Tokens live in `expo-secure-store`. Logging out deletes the refresh token on the server.

**Account deletion:** in-app and on the web (an Apple requirement). Deleting anonymises the profile and removes photos after a 30-day grace period. Reviews stay up as "Deleted rider" unless the member asks for them to be removed too.

---

## 7. API (for mobile)

- REST + JSON under `/api/v1`, with `Authorization: Bearer <access>`.
- **OpenAPI spec via `open_api_spex`**. We generate a typed TypeScript client for the app from it (`openapi-typescript` + `openapi-fetch`), so the API contract can't quietly drift between backend and app.
- Cursor pagination (`?after=<cursor>&limit=20`) on every list.
- Errors use one shape: `{ "error": { "code": "validation_failed", "fields": {...} } }`.

| Area | Endpoints |
|---|---|
| Auth | `POST auth/password`, `auth/magic_link`, `auth/magic_link/exchange`, `auth/google`, `auth/apple`, `auth/refresh`, `DELETE auth/session` |
| Me | `GET/PATCH me`, `GET/POST/PATCH/DELETE me/garage`, `POST me/push_devices`, `DELETE me` |
| Riders | `GET riders`, `GET riders/:slug`, `GET riders/featured` |
| Models | `GET pev_models`, `GET pev_models/:slug` (with average scores) |
| Reviews | `GET reviews`, `GET reviews/:id`, `POST reviews`, `PATCH reviews/:id` |
| Events | `GET events?when=upcoming|past`, `GET events/:slug`, `PUT events/:slug/rsvp`, `DELETE events/:slug/rsvp`, `GET events/:slug/attendees` |
| Gallery | `GET albums`, `GET albums/:slug`, `POST uploads/presign`, `POST photos` |
| Safety | `POST reports`, `POST blocks` |

Real-time updates (RSVP counts changing live) use Phoenix Channels later, and only if people actually want them. The MVP app refetches on screen focus and on pull-to-refresh (TanStack Query).

---

## 8. Media pipeline

1. The client asks `POST /uploads/presign` for a presigned PUT URL to `uploads/tmp/<uuid>`.
2. The client uploads the file straight to R2 or Spaces. The image never passes through the VPS, which keeps bandwidth and memory low.
3. The client calls `POST /photos` with the key. The backend creates the photo row and queues an `ImageVariantsWorker` (Oban) job.
4. The worker uses the `image` library (libvips) to strip EXIF/GPS data, generate `thumb` (400px), `medium` (1200px) and `large` (2048px) WebP versions plus a blurhash, and write them to `photos/<id>/…`.
5. Images are served from the object storage's public CDN domain (e.g. `img.pev-squad.org`).

Limits: 15 MB per upload, JPEG/PNG/HEIC/WebP only, and a per-user daily upload cap to stop abuse.

---

## 9. Web (Phoenix LiveView)

- Each prototype page becomes a LiveView or controller page: `/`, `/community`, `/riders/:slug`, `/featured-riders`, `/reviews`, `/reviews/:id`, `/models/:slug`, `/events`, `/events/:slug`, `/gallery`, `/gallery/:slug`, `/sponsors`, and later `/for-sale`.
- The nav and footer that are copy-pasted across every prototype page become **layout components** (`<.site_header>`, `<.site_footer>`), which ends the "update all seven files" rule.
- `css/kinetic.css` is ported unchanged into `assets/css/` and imported into Tailwind's `components` layer, so Tailwind spacing utilities still work alongside it. `forms.css` adds Kinetic-style inputs, flashes, tables and panels for screens the prototype didn't have. daisyUI has been removed because its `.btn`, `.card`, `.hero` and `.badge` clashed with Kinetic. The heroicons plugin's `hero-*` classes are reserved, which is why the prototype's `.hero-tag` became `.hero-scribble`.
- The Kinetic design has no light/dark toggle, so there's no theme script.
- Public pages render on the server and can be cached. Each has `<meta>`/OpenGraph tags (event pages share well on WhatsApp). Pages are reachable without logging in; RSVP, posting and profile editing need a login.
- **Admin** at `/admin`: moderation queue, events CRUD, partners, PEV model catalog, Featured Rider grants, user management. Hand-written LiveViews, or **Backpex** to save time.

---

## 10. Mobile (React Native / Expo)

- **Expo SDK (latest stable) + expo-router + TypeScript**, built and released with **EAS Build / EAS Submit**. **EAS Update** pushes JS-only fixes over the air.
- Libraries: TanStack Query (server state), the generated OpenAPI client, `expo-secure-store`, `expo-image` (with blurhash placeholders), `expo-image-picker`, `expo-notifications`, `expo-calendar` ("add ride to calendar"), `react-native-reanimated`.
- **Design tokens** taken from `kinetic.css` `:root` into `mobile/src/theme/tokens.ts` (`orange #FF4800`, black, white, `bw: 2`). Fonts Big Shoulders Stencil Display, Inter, JetBrains Mono and Permanent Marker load via `expo-font`.

**Tabs:** Home (next ride, latest reviews) · Events · Reviews · Gallery · Profile

**Key flows**
1. Onboarding: sign in, then set alias, city, primary PEV and garage, then "show me on the website?" (consent)
2. Event detail: RSVP (pick the vehicle you're bringing), add to calendar, open the meeting point in Maps, share link
3. Write a review: pick a model from the catalog, enter scores per criterion and the text, then show "pending approval"
4. Upload photos to an album
5. Push notifications: event reminder (24h and 2h before), RSVP waitlist promotion, review approved or rejected, new event published

Push goes through the **Expo Push API**, sent from an Oban `PushWorker`. Tokens that get `DeviceNotRegistered` receipts are deleted.

---

## 11. Infrastructure and operations (VPS)

- **Server:** 1 VPS with 2 vCPU and 4 GB RAM, e.g. Hetzner (closest is Singapore), DigitalOcean SGP1, or IDCloudHost (Jakarta, lowest latency for Indonesian users). About $15–25/month.
- **Deploy:** **Kamal** (Docker image built in GitHub Actions, zero-downtime deploys with kamal-proxy) or a plain `mix release` + systemd + Caddy. Kamal is the recommendation: rollbacks are easy, and moving to a new server is one config change.
- **Postgres** on the same server at first (Docker volume). **Backups:** nightly `pg_dump` to object storage, kept 30 days, plus WAL archiving with `wal-g` if we want point-in-time recovery. **Practice a restore once before launch.**
- **TLS/DNS:** Cloudflare DNS, with Caddy or kamal-proxy handling Let's Encrypt.
- **Observability:** Sentry (backend + RN), Phoenix LiveDashboard behind admin auth, Oban Web (free tier) or Oban metrics in LiveDashboard, an external uptime check (UptimeRobot / Better Stack).
- **Email:** Postmark or Resend for magic links and notifications, with SPF/DKIM/DMARC set up on the domain.
- **Environments:** `dev` (local, Postgres in Docker) · `staging` (a small second VPS or the same box on a different port and database) · `prod`.
- **CI:** backend runs `mix format --check-formatted`, `credo`, `mix test`, and builds the image; mobile runs `tsc`, `eslint`, and `jest` on PRs, and EAS builds on tags.

**Estimated monthly cost at launch:** VPS ~$20 + storage/CDN ~$0–5 (R2 has no egress fees) + email ~$0–15 + Apple Developer $99/yr + Google Play $25 one-time.

---

## 12. Privacy and compliance

- **Indonesia PDP Law (UU 27/2022):** say clearly why we collect each piece of data, get explicit consent before showing a profile publicly, let members export and delete their data, and keep a privacy policy page.
- Full name, email and WhatsApp number are private by default. Public profiles show alias, city, PEVs, bio and photo.
- Location is stored at city level only for members. Event locations are public.
- EXIF/GPS data is stripped from every uploaded photo.
- App store checklist: Sign in with Apple (required because we offer Google sign-in), in-app account deletion, UGC report/block, privacy nutrition labels / Play Data Safety form.

---

## 13. Migrating existing data

A one-off `mix pev_squad.import` task:
1. **Members** from `member pev squad.csv`: create a `rider_profile` with alias, city, PEV type/model and bio. **Only rows where *"Bersedia dicantumkan di website?"* = yes** get `is_public = true`. Photos are copied from `images/community/`. Profiles start **unclaimed**, with no login attached.
2. **Claiming a profile:** a member signs up with the email from the form and gets offered "Is this you?" for the matching profile. A moderator can also link profiles by hand.
3. **Events** from `events.md` (role, partners, sponsors, location, notes) → `events` + `partners` + `event_partners`.
4. **Reviews, featured riders, gallery albums:** the prototype content is placeholder data (per `SUMMARY.md`), so import only the real items. The PEV model catalog gets seeded by hand.

The CSV has personal data in it and should not be committed to git. Add it to `.gitignore` and keep it outside the repo.

---

## 14. Delivery plan (12 weeks, 1–2 devs)

| Weeks | Backend / Web | Mobile |
|---|---|---|
| 1–2 | Phoenix project, CI, Kamal deploy to staging, phx.gen.auth, port CSS + layout components, schema migrations | Expo project, theme tokens and fonts, navigation shell |
| 3–4 | Profiles, garage, PEV catalog, Google/Apple OAuth, API auth tokens, OpenAPI spec | Auth flows (email, magic link, Google, Apple), onboarding, profile screens |
| 5–6 | Events + RSVP + partners, admin events CRUD, CSV/events import | Events list and detail, RSVP, calendar, push registration |
| 7–8 | Reviews + scores + averages, media pipeline, gallery | Reviews list, detail and compose, photo upload, gallery |
| 9–10 | Moderation queue, reports/blocks, trusted-member logic, Featured Rider admin, push/email workers | Report/block UI, notifications, account deletion, polish |
| 11 | Hardening: backups and restore drill, Sentry, rate limiting (`hammer`), SEO/OG tags, privacy policy | TestFlight + Play internal testing with ~10 squad members |
| 12 | Production launch of the web | Store submission (allow 1–2 weeks for review) |

With two developers, one owns backend + web and the other owns mobile from week 3. Both work against the OpenAPI spec. With one developer, ship the web first (weeks 1–10) and release the app after it (~weeks 10–16).

---

## 15. Risks

| Risk | Mitigation |
|---|---|
| A single VPS is a single point of failure | Tested backups, a Kamal config that redeploys to a fresh server in under an hour, uptime alerts. Fine for a community app. |
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
| 7 | Featured weighting (default) | Featured reviews count **×2** in a model's overall score. The Sheet also shows the Featured and Community averages **separately**, like the prototype. "Featured" is fixed when a review is published, based on the author's badge at that moment. |
| 8 | Review moderation | Reviews from new members wait for a moderator. **Staff and members with 2 or more published reviews publish straight away**, unless the model is new, in which case the moderator approves both together. Rejections require a reason, which is emailed to the author. Editing a rejected review sends it back to the queue. |

## 17. Open questions

1. **Review criteria:** confirm the defaults in decision 6 and the ×2 weighting in decision 7.
2. **Featured Rider gate:** keep it as a manual admin grant, or let members apply through a form in the app?
3. **Should the static prototype stay live** at `pev-squad.org` until the LiveView pages are ready, or move to `demo.pev-squad.org`?
4. **Marketplace phase 2:** are dealers / sponsors allowed to post brand-new listings, and do they need a separate "shop" account type?
