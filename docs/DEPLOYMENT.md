# Deploying PEV Squad (backend)

Production runs on a single DigitalOcean droplet. The release is **built on the
server itself** from `main` — you never copy build output from your Mac (a macOS
build won't run on Linux).

| | |
|---|---|
| Site | https://pev-squad.org (`www` redirects to it) |
| Server | `159.223.73.156` — Ubuntu 24.04, 1 vCPU / 1 GB + 2 GB swap |
| SSH | `ssh deploy@159.223.73.156` (key only; root also works for admin tasks) |
| Code | `/home/deploy/app` (git clone of this repo, tracks `main`) |
| Release | `/home/deploy/app/backend/_build/prod/rel/pev_squad` |
| Secrets | `/home/deploy/pev_squad.env` (mode 600, **not in git**) |
| Uploads | `/var/lib/pev_squad/uploads` (avatars, gallery — **not in git**, outside the release) |
| Database | PostgreSQL 16 on the same box, db `pev_squad_prod` |
| App service | systemd `pev_squad` (Bandit on `localhost:4000`) |
| Web server | Caddy (`/etc/caddy/Caddyfile`) — HTTPS via Let's Encrypt, auto-renews |
| Toolchain | Erlang/OTP 27 in `/opt/erlang`, Elixir 1.19 in `/opt/elixir` |

---

## Deploying an update

### 1. Get your change onto `main`

The server only deploys what is on `origin/main`.

```bash
# from your feature branch, once it works locally
git checkout main
git merge <your-branch>        # or merge a PR on GitHub
git push origin main
```

Before pushing, it's worth running the checks locally:

```bash
cd backend && mix precommit    # compile with warnings-as-errors, format, tests
```

### 2. Run the deploy script

```bash
ssh deploy@159.223.73.156 ./deploy.sh
```

That's it. `~/deploy.sh` does, in order:

1. `git pull --ff-only` on `main`
2. `mix deps.get --only prod` and `mix compile` (with `MIX_ENV=prod`)
3. `mix assets.setup` + `mix assets.deploy` (tailwind, esbuild, digest)
4. `mix release --overwrite`
5. `mix ecto.migrate` — runs any new migrations
6. `sudo systemctl restart pev_squad`
7. A health check against `localhost:4000` — exits non-zero if it isn't `200`

Expect ~2–5 minutes (longer if dependencies changed — 1 vCPU). The site is
down only for the few seconds of the restart.

### 3. Check it

- Open https://pev-squad.org and click through what you changed.
- If something looks wrong, read the logs (below).

---

## Day-to-day commands

Run these on the server (`ssh deploy@159.223.73.156`).

```bash
# Logs (follow live / last 200 lines)
journalctl -u pev_squad -f
journalctl -u pev_squad -n 200 --no-pager

# Service status / restart
systemctl status pev_squad
sudo systemctl restart pev_squad

# Remote IEx shell into the running app (Ctrl+C twice to leave — does NOT stop the app)
~/app/backend/_build/prod/rel/pev_squad/bin/pev_squad remote

# Postgres shell
sudo -u postgres psql pev_squad_prod     # needs root; or connect as pev_squad via DATABASE_URL

# Caddy (HTTPS / proxy) logs
sudo journalctl -u caddy -n 100 --no-pager
```

> `deploy` can only `sudo systemctl restart pev_squad` without a password.
> For other sudo commands, SSH in as `root`.

---

## Rolling back

`mix release --overwrite` replaces the previous build, so rolling back means
building an older commit:

```bash
ssh deploy@159.223.73.156
cd ~/app
git log --oneline -10                  # find the last good commit
git checkout <good-sha>
# re-run the build steps from deploy.sh, skipping `git pull`:
. /etc/profile.d/beam.sh && cd backend && export MIX_ENV=prod
set -a; . ~/pev_squad.env; set +a
mix deps.get --only prod && mix compile && mix assets.deploy && mix release --overwrite
sudo systemctl restart pev_squad
```

Then fix forward on your Mac, push to `main`, and put the server back on it:

```bash
cd ~/app && git checkout main && ~/deploy.sh
```

**Migrations are not rolled back automatically.** If the bad deploy included a
migration that the old code can't work with, roll it back *before* checking
out the old commit:

```bash
cd ~/app/backend && MIX_ENV=prod mix ecto.rollback   # with the env file sourced, as above
```

---

## Changing configuration / secrets

Runtime config comes from `/home/deploy/pev_squad.env` (read by systemd and by
`deploy.sh`). Variables expected by `config/runtime.exs`:

| Variable | Purpose |
|---|---|
| `DATABASE_URL` | `ecto://pev_squad:<password>@localhost/pev_squad_prod` |
| `SECRET_KEY_BASE` | cookie/session signing — changing it logs everyone out |
| `PHX_HOST` | `pev-squad.org` |
| `PHX_SERVER` | `true` — makes the release start the web server |
| `PORT` | `4000` (Caddy proxies to it) |
| `UPLOADS_DIR` | `/var/lib/pev_squad/uploads` |

After editing the file: `sudo systemctl restart pev_squad`.

Compile-time config (`config/prod.exs`, e.g. `force_ssl`) needs a full
`./deploy.sh` rather than just a restart.

---

## Things that are *not* deployed by git

- **Uploads** live only in `/var/lib/pev_squad/uploads`. A deploy never touches
  them, but they are also not backed up anywhere yet.
- **Database content** lives only in `pev_squad_prod`. Production is now the
  source of truth — don't overwrite it from a local dev database.
- **`priv/repo/seeds.exs` must not be run in production.** It creates demo
  accounts with a password that is published in this repo (the script raises
  under `MIX_ENV=prod` for that reason).

---

## Known gaps

- **No backups yet** — set up a nightly `pg_dump` + copy of the uploads dir.
- **No mailer configured** — `Swoosh` has no prod adapter, so sign-up
  confirmation and password-reset emails are not sent.
