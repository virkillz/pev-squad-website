# AGENTS.md

This file provides guidance to coding agents working with code in this repository.

## What this is

PEV Squad (https://pev-squad.org) is the site for an Indonesian community of personal electric vehicle riders (EUC, performance scooters, esk8). It's an Elixir/Phoenix 1.8 + LiveView app with PostgreSQL. The app lives in `backend/`.

An earlier static HTML prototype used to sit at the repo root. It has been removed; it is still in git history if you need it.

## Repo layout

- `backend/`: the Phoenix app (contexts in `lib/pev_squad/`, LiveViews in `lib/pev_squad_web/live/`, assets in `assets/`). Phoenix/Elixir coding rules are in `backend/AGENTS.md`.
- `docs/DESIGN.md`: platform design doc (data model, roadmap). `docs/DEPLOYMENT.md`: production runbook. `docs/events.md`: the community's real event history, the source for the event seeds.
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
