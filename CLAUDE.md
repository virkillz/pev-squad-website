# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

PEV Squad (https://pev-squad.org) is the site for an Indonesian community of personal electric vehicle riders (EUC, performance scooters, esk8). It's an Elixir/Phoenix 1.8 + LiveView app with PostgreSQL. The app lives in `backend/`.

An earlier static HTML prototype used to sit at the repo root. It has been removed; it is still in git history if you need it.

## Repo layout

- `backend/`: the Phoenix app (contexts in `lib/pev_squad/`, LiveViews in `lib/pev_squad_web/live/`, assets in `assets/`). Phoenix/Elixir coding rules are in `backend/AGENTS.md`.
- `docs/DESIGN.md`: platform design doc (data model, roadmap). `docs/DEPLOYMENT.md`: production runbook. `docs/CLI.md`: the `pev` content CLI. `docs/events.md`: the community's real event history, the source for the event seeds.
- `scripts/pull-backups.sh`: downloads the nightly production backups.
- `member pev squad.csv`: member sign-up export with personal data. It's gitignored; never commit it.

## Running locally

```bash
cd backend
mix setup        # deps, DB, assets, dev seeds
mix phx.server   # http://localhost:4000
mix test
mix precommit    # run before finishing a change
```

## Styling

The "Kinetic" design system from the prototype lives in `backend/assets/css/kinetic.css`, imported into Tailwind's `components` layer. App-only UI (forms, flashes, tables, panels) is in `forms.css`. daisyUI is removed because its class names clash with Kinetic, and `hero-*` is reserved for heroicons. See `docs/DESIGN.md` for details.

## Languages (Indonesian / English)

The public site and member pages are translated with Gettext; the admin area is English only. Indonesian is the default.

- `PevSquadWeb.Locale` picks the language (`?locale=`, session, `Accept-Language`, default) and is both a plug and an `on_mount` hook. The ID/EN switch goes through `/locale/:locale`. Members' choice is saved in `users.locale` and used for their emails (`PevSquad.Mailer.in_locale/2`).
- Wrap new UI text in `gettext("...")` (use `%{name}` placeholders, never string interpolation). Labels in core modules use `gettext_noop` and are translated by their label functions. Custom changeset messages use `dgettext_noop("errors", ...)`.
- Dates: `PevSquadWeb.Locale.strftime/2`, not `Calendar.strftime/2`, for anything riders see.
- After changing text: `mix gettext.extract --merge`, then fill the empty `msgstr ""` entries in `priv/gettext/id/LC_MESSAGES/*.po`. Clear any `#, fuzzy` guesses gettext adds; they're usually wrong.
- Tests run with English as the default (`config/test.exs`); Indonesian is covered in `test/pev_squad_web/locale_test.exs`.

## JSON API

`/api/v1` serves the planned mobile app and staff tools (design: `docs/DESIGN.md` §7, roadmap §14).

- Pipeline `:api` in the router: session-less locale (`PevSquadWeb.Locale, session: false`), then `fetch_api_scope` (`PevSquadWeb.API.Auth`) reads the bearer token. Protected routes add `require_api_user` or `require_api_staff`.
- Controllers: `use PevSquadWeb, :api_controller`, in `lib/pev_squad_web/controllers/api/`. Return `{:error, changeset | :not_found | :forbidden}` and the fallback controller renders the shared error shape (`PevSquadWeb.API.Errors`). Declare an `operation` for each action; schemas are in `lib/pev_squad_web/api/schemas/`.
- The spec is served at `/api/v1/openapi`, with Swagger UI at `/dev/swaggerui` in development.
- Tokens: personal API tokens (`pevsq_…`) for staff only, created at `/admin/api-tokens`, stored hashed in `users_tokens` (context `api`).
- Admin endpoints (`/api/v1/admin/…`, `require_api_staff`) only create and edit **drafts**. They refuse `status` / `published_at` with a 422, and editing published items or group rides returns a 409. Body parsing is in `PevSquadWeb.API.AdminParams`.

## Drafting events, news and articles (`scripts/pev`)

When the user asks you to write or edit an event, a news item or an article on the site, use the `pev` CLI. Don't use the admin UI, `bin/pev_squad rpc`, or the database.

- It needs `PEV_API_TOKEN` (the user creates it at `/admin/api-tokens`; never print it or write it to a file in the repo). `PEV_API_URL` defaults to production; use `http://localhost:4000` to try things locally. `PEV_LOCALE=en` gives English error messages.
- Full guide: `docs/CLI.md`. `scripts/pev --help` has the commands and the `.md` file format. Typical loop:
  1. Write a draft `.md` in the scratchpad: front matter, then `=== id ===` and `=== en ===` sections.
  2. `pev posts create FILE`. Local `![](./img.jpg)` images and `cover:` are uploaded for you.
  3. To edit: `pev posts pull SLUG -o FILE`, change the file, then `pev posts update SLUG FILE`.
- Events: `pev events create FILE`, with times local to `timezone` (e.g. `starts_at: 2026-12-05T20:00`). Run `pev partners` to find `partner_ids`, and `pev events list` to find an `event_id` for a recap post.
- Images and albums: an event takes one image (`cover: ./poster.jpg`, or `pev events cover`), and posts take `cover:` too. Run `pev albums` to find ids for an event's `album_ids` or a post's `album_id`. A recap post shows its event's album without `album_id`.
- Write Indonesian first, since it's the default language. Set `machine_translated: false` on text the user wrote or checked. Anything you translated keeps the default `true`.
- Everything lands as a draft. Give the user the `admin_url` from the response so they can review and publish it. You can't publish.

## Production server

Full runbook: `docs/DEPLOYMENT.md`. Key facts for connecting and operating:

- **Site**: https://pev-squad.org (`www` redirects). DigitalOcean droplet `159.223.73.156`, Ubuntu 24.04, 1 vCPU / 1 GB + 2 GB swap.
- **SSH**: key-only, no passwords. `ssh deploy@159.223.73.156` for app work, `ssh root@159.223.73.156` for system admin. Always pass `-o BatchMode=yes`. The user's key `~/.ssh/id_ed25519` has a passphrase. If SSH says `Permission denied (publickey)`, the key probably isn't loaded in the agent: ask the user to run `ssh-add --apple-use-keychain ~/.ssh/id_ed25519` in a **normal terminal tab**. You can't enter the passphrase yourself.
- **Deploy**: changes go to `origin/main` first (the server only builds `main`), then run `ssh deploy@159.223.73.156 ./deploy.sh`. It pulls, builds the release on the server, migrates, restarts, and health-checks.
- **Layout**: code `/home/deploy/app`, release `backend/_build/prod/rel/pev_squad`, secrets `/home/deploy/pev_squad.env` (not in git; never print its values), uploads `/var/lib/pev_squad/uploads`, Postgres 16 db `pev_squad_prod` on the same box.
- **Services**: systemd `pev_squad` (Bandit on `localhost:4000`), Caddy reverse proxy with auto HTTPS (`/etc/caddy/Caddyfile`), `pev-backup.timer` (nightly 03:00 WIB, 7-day retention, in `/var/backups/pev_squad`).
- **Toolchain**: Erlang/OTP 27 in `/opt/erlang`, Elixir 1.19 in `/opt/elixir` (prebuilt Hex builds). Root also has an unused mise Elixir that sets `MIX_HOME=/root/...`: run mix as deploy via `ssh deploy@` or `su - deploy` (with the dash), never `su deploy`.
- **Running code in prod**: `bin/pev_squad rpc "..."` evaluates in the live node. `bin/pev_squad eval` with `PHX_SERVER` unset is for one-offs. Source `~/pev_squad.env` before `mix` tasks under `MIX_ENV=prod`.
- **Email**: Brevo through `Swoosh.Adapters.Brevo` when `BREVO_API_KEY` is set (otherwise emails are only logged). The sender is `noreply@pev-squad.org`. The domain is authenticated with DKIM.
- **Data rules**: production is the source of truth now. Don't overwrite it from the local dev DB. **Never run `priv/repo/seeds.exs` in prod**: it creates demo accounts whose password is published in the repo. The admin account is `virkill@gmail.com`.
- **Backups locally**: `scripts/pull-backups.sh` downloads them to `~/Backups/pev_squad`. Use Homebrew `postgresql@17` tools to read the dumps. `@14` can't read Postgres 16 dumps.
