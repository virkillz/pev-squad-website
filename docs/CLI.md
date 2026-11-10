# The `pev` CLI

`scripts/pev` drafts events, news and articles on pev-squad.org from your computer, by hand or through an AI assistant like Claude Code. It talks to the admin API (`/api/v1/admin`, see `DESIGN.md` §7).

**Everything it writes is a draft.** Nothing goes live until someone opens it in `/admin` and publishes it. The API refuses to publish and refuses to edit anything that's already published.

It's a single Python 3 script with no dependencies (macOS ships Python 3). Output is JSON on stdout. Errors are JSON on stderr, with exit code 1.

---

## Setup (once per computer)

1. **Create a token.** Go to https://pev-squad.org/admin/api-tokens (staff only). Creating one asks you to log in again if your login is older than about 20 minutes. Give it a name like "MacBook CLI" and copy the token (`pevsq_…`). It's shown only once.
2. **Put it in your shell profile** (`~/.zshrc`):
   ```bash
   export PEV_API_TOKEN=pevsq_...
   ```
   Keep it out of git and out of files in the repo. A token acts as you.
3. **Open a new terminal**, or restart Claude Code from a new terminal tab, so the variable is picked up.
4. **Check it works:**
   ```bash
   scripts/pev whoami
   ```

Optional variables:

| Variable | Default | Use |
|---|---|---|
| `PEV_API_URL` | `https://pev-squad.org` | `http://localhost:4000` to try things against the dev server |
| `PEV_LOCALE` | server default (Indonesian) | `en` for English error messages |

Tokens expire after a year. They stop working if you change your password or stop being a moderator or admin. If a laptop is lost, revoke its token at `/admin/api-tokens`.

---

## Commands

```
pev whoami                                  who the token belongs to
pev partners                                partner ids, for an event's partner_ids
pev albums                                  gallery album ids, for album_id / album_ids
pev upload IMAGE                            upload an image for a post body
pev spec                                    the OpenAPI document

pev posts list [--kind news|article] [--status draft|published]
pev posts get ID_OR_SLUG                    full post as JSON
pev posts pull ID_OR_SLUG [-o FILE]         save as an editable .md file
pev posts create FILE                       FILE is .md or .json
pev posts update ID_OR_SLUG FILE            only what's in FILE changes
pev posts cover ID_OR_SLUG IMAGE            set the cover image

pev events list [--status S] [--category official|group_ride] [--upcoming]
pev events get ID_OR_SLUG
pev events create FILE                      .md or .json
pev events update ID_OR_SLUG FILE
pev events cover ID_OR_SLUG IMAGE           set the event image
```

Every response for a post or event includes `admin_url` (where you review and publish it) and `url` (the public page, which shows 404 until it's published).

---

## Writing a post

A post file has front matter, then one section per language:

```markdown
---
kind: news                 # news | article
topic: community           # optional: community industry regulation safety maintenance guide gear story
event_id: 12               # optional: makes it a recap of that event (pev events list)
album_id: 4                # optional: photo album shown with the post (pev albums)
source_name: Kompas        # optional: outside news
source_url: https://...
cover: ./cover.jpg         # optional: uploaded after saving
---
=== id ===
title: Recap Night Ride Sudirman
excerpt: Optional one-liner for cards and previews.
machine_translated: false

The body is in **Markdown**. Local images are uploaded automatically and the
link is rewritten:

![Group photo](./group.jpg)
=== en ===
title: Night Ride Sudirman Recap

English body. machine_translated defaults to true here.
```

Rules:
- **Indonesian first.** It's the site's default language, and the slug (URL) is generated from the Indonesian title. It doesn't change when you edit the title later.
- Each language section has `key: value` header lines, then a blank line, then the body. `title` and the body are required.
- **`machine_translated`** shows a "machine translated" note on the page. It defaults to `true` for text sent through the CLI. Set it to `false` for text a person wrote or checked.
- Quote titles that contain `:` or `#`, e.g. `title: "Tips: Ban Tubeless"`.
- Images: JPEG, PNG or WebP, up to 15 MB. They're stored as 1600px WebP with location data (GPS/EXIF) removed.
- **`album_id`** shows a photo album card with the post. A recap (`event_id`) without one shows its event's newest album. Only published albums with photos appear. `album_id: null` removes it.
- Leave out a language section to leave that language as it is. An **empty** section (`=== en ===` with nothing under it) deletes that language.

Create it:

```bash
scripts/pev posts create recap.md
```

### Editing a draft

```bash
scripts/pev posts pull recap-night-ride-sudirman -o recap.md   # download
# edit recap.md
scripts/pev posts update recap-night-ride-sudirman recap.md    # upload
```

`pull` writes the same format, with `id` and `slug` in the front matter and the current status as a comment. Only drafts can be updated. To fix a published post, edit it in `/admin`.

---

## Writing an event

An event file has front matter with the fields, and the text after it is the description (Markdown):

```markdown
---
title: Night Ride Sudirman
kind: night_ride           # ride night_ride trail_ride tour getaway expedition race meetup clinic collab collab_ride brand_invite brand_activation media exhibition marshal
role: organizer            # organizer | collaborator
starts_at: 2026-12-05T20:00
ends_at: 2026-12-05T23:00
timezone: Asia/Jakarta     # Asia/Jakarta (WIB) | Asia/Makassar (WITA) | Asia/Jayapura (WIT)
location_name: FX Sudirman
meeting_point: Lobby parkir motor
capacity: 40               # leave out for unlimited
rsvp_deadline: 2026-12-05T18:00
partner_ids: [3, 7]        # from `pev partners`; replaces the linked partners
partners: Komunitas X      # free text for names without a partner page
album_ids: [4]             # from `pev albums`; replaces the linked photo albums
cover: ./poster.jpg        # optional: the event image, uploaded after saving
---
Kumpul jam **19.30**, briefing 19.45.
```

```bash
scripts/pev events create night-ride.md
scripts/pev events update night-ride-sudirman-2026 night-ride.md
```

- **Times** without an offset are local to `timezone`, so `20:00` with `Asia/Jakarta` means 20:00 WIB. You can also give an exact time with an offset (`2026-12-05T20:00:00+07:00`).
- Responses show `starts_at` in UTC, plus a `local` block in the event's zone. Check `local.starts_at` to confirm.
- **Image and album**: `cover:` uploads one image (a poster or photo; JPEG, PNG or WebP up to 15 MB) shown at the top of the event page. `album_ids` links gallery albums; an album belongs to one event, so linking it here moves it from any other event. Only published albums with photos appear on the page.
- The CLI only creates **official** events. Member group rides can't be edited through it.

---

## JSON instead of Markdown

Any `create`/`update` also accepts a `.json` file with the API's own shape. For posts:

```json
{
  "kind": "article",
  "translations": {
    "id": {"title": "...", "body": "...", "machine_translated": false},
    "en": {"title": "...", "body": "..."}
  }
}
```

In an update, `"en": null` deletes the English text. The full schema is in `pev spec`, and in Swagger UI at `http://localhost:4000/dev/swaggerui` when the dev server is running.

---

## Using it with Claude Code

CLAUDE.md tells Claude Code to use this CLI for site content, so you can ask in plain language:

> Draft a news recap of last Saturday's night ride. Photos are in ~/Desktop/nightride. Indonesian first, then English.

> Make a draft event for the Bromo trip on 14 Feb 2027, 04:00 WIB, meeting at Rest Area KM 57, capacity 25, with Jogwheel as partner.

Claude writes the file, runs `pev`, and gives you the `admin_url`. Review it there and publish.

---

## Errors

Errors look like this (in Indonesian unless `PEV_LOCALE=en`):

```json
{"error": {"code": "validation_failed", "message": "Some fields need fixing.", "fields": {"title": ["can't be blank"]}}}
```

| Code | Meaning | What to do |
|---|---|---|
| `no_token` | `PEV_API_TOKEN` isn't set in this shell | Export it and open a new terminal (restart Claude Code if it's running) |
| `unauthorized` | Token wrong, expired, revoked, or you're not staff anymore | Create a new token at `/admin/api-tokens` |
| `validation_failed` | A field is invalid; `fields` says which | Fix the file and run again. `status` / `published_at` are always refused: publish in `/admin` |
| `conflict` | The post/event is already published, or it's a group ride | Edit it in `/admin` |
| `not_found` | No post/event with that id or slug | `pev posts list` / `pev events list` |
| `unreachable` | Can't reach `PEV_API_URL` | Check the URL, your connection, or whether the dev server is running |
| `bad_file` | The `.md` file couldn't be parsed | The message points to the problem line |

---

## Where things live

- CLI: `scripts/pev`
- API controllers: `backend/lib/pev_squad_web/controllers/api/admin/`. Request parsing is in `backend/lib/pev_squad_web/api/admin_params.ex`.
- Token logic: `PevSquad.Accounts` (`create_api_token/2`, `get_user_by_api_token/1`). The admin page is `/admin/api-tokens`.
- Design and rules: `docs/DESIGN.md` §7 and decision 17
