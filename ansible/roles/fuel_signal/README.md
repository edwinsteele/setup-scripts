# fuel_signal

Deploys [fuel-price-signal](https://github.com/edwinsteele/fuel-price-signal)
on `viking` (see [samba_timemachine](../samba_timemachine/README.md) for what
else lives on that box) as a dedicated `fuelsignal` system account, with:

- a daily `fuelsignal-daily-update.timer` that pulls, syncs, loads today's
  already-committed snapshot CSV, then refreshes the derived tables the
  workbench reads (`daily_prices`, `station_class`/`classification_summary`,
  `lga_leadership`), and
- an always-on `fuelsignal-workbench.service` running the Flask analysis
  workbench, bound to `viking`'s LAN address (never `0.0.0.0`).

Deployment model is git checkout + `uv`, not packaging: `fuel-price-signal`
installs itself as an editable package into its own `.venv`
(`[tool.uv] package = true`), so there's nothing to build or publish.

## Why a dedicated `fuelsignal` account, not `esteele`

Keeps the checkout, venv, DB, and model files owned by an unprivileged
account scoped to this one thing, separate from `esteele`'s own login - the
same reasoning `samba_timemachine` and `home_assistant` don't run as
`esteele` either. `shell: /sbin/nologin` - nobody logs in as `fuelsignal`
directly; `esteele`'s existing passwordless wheel sudo (`roles/common`'s
RedHat branch) is how you reach it (`sudo -u fuelsignal ...`,
`sudo fuelsignal-deploy`).

## No deploy key needed

`fuel-price-signal` is a public repo (confirmed: anonymous `git clone` over
HTTPS works), so the `fuelsignal` account just clones over plain HTTPS -
`fuel_signal_repo_url` defaults to the `https://` remote, not `git@`. No key
material to generate, store, or register anywhere. If the repo ever goes
private, this role would need a deploy key added back (generated on-box,
never handled by ansible directly, with the public half surfaced for you to
register manually - same spirit as `samba_timemachine`'s `smbpasswd` step).

## Python 3.14

`fuel-price-signal` requires Python ≥3.14. Rocky 9's AppStream repo ships a
versioned `python3.14` package alongside the `python3.9` the OS itself
depends on - this role installs it via `dnf` rather than letting `uv`
download its own standalone build, so the interpreter stays patched through
the box's normal `dnf update` cadence like everything else on it.
`UV_PYTHON_PREFERENCE=only-system` (set on both systemd units, the initial
`uv sync` bootstrap task, and `fuelsignal-deploy`) makes this a hard
requirement rather than a preference - `uv` errors out instead of silently
falling back to a downloaded interpreter if the dnf package is ever missing.

## Why `uv run --with waitress` instead of Flask's dev server

`fuel_signal.inspect`'s Flask app isn't a module-level object a WSGI server
could import directly - `main()` (the click command) builds it from live
DB/model state and finishes with `app.run(host, port, debug)`. Rather than
patching that into the upstream repo, `templates/waitress_wrapper.py.j2`
(deployed to `{{ fuel_signal_base_dir }}/waitress_wrapper.py`, *beside* the
checkout so `git pull` never touches it) monkeypatches `Flask.run` to hand
off to `waitress.serve()` before importing and calling `main()` - click's
own `--host`/`--port`/`--no-browser` parsing is untouched.
`uv run --with waitress` layers the `waitress` package in for just that
invocation without adding it to `fuel-price-signal`'s own
`pyproject.toml`/`uv.lock`. `--debug` is never passed, so Flask's debug
mode stays off regardless.

## Checkout updates: the ansible role never pulls, but the daily-update timer does

The `ansible.builtin.git` task uses `update: false` - it only clones on
first run. Re-running this play (e.g. for an unrelated `home_assistant`
change) never pulls new commits - that's the invariant `fuelsignal-deploy`
documents ("this repo's ansible role never runs `git pull` itself").

That invariant is about the *ansible role*, though, not about all automation
on the box. `fuelsignal-daily-update.sh` (see below) is a deliberate
exception: it does its own `git pull --ff-only` on every daily firing, so
the checkout stays bleeding-edge - and, since `fuelsignal-workbench.service`
is a long-running Flask process that doesn't reload code from disk on its
own, the script also restarts it every run so newly-pulled *code* actually
goes live daily rather than sitting unused until someone runs
`fuelsignal-deploy` by hand. After restarting, it polls `/healthz` (cheap,
no DB work) every 5s for up to `fuel_signal_workbench_warmup_ready_timeout_seconds`
(default 120s) until the process is accepting connections at all, then
curls each of `fuel_signal_workbench_warmup_paths` (`/`, `/lead-lag`,
`/classification-health`, `/features` by default) once each, so the first
real visitor of the day isn't the one paying for cold-start latency.

Each warm-up GET gets a generous, single-shot timeout
(`fuel_signal_workbench_warmup_timeout_seconds`, default 240s) and no
`curl --retry` - confirmed on viking that the first hit to a data-heavy
page right after a full `daily_prices` rebuild can legitimately take
minutes (cold disk cache on this box's constrained hardware), and Flask
keeps running the view function to completion server-side even after a
client gives up. Retrying on top of that just launches another concurrent
copy of the same expensive query rather than helping - which is exactly
what made warming `/` fail outright the first time this was wired up with
`--retry`.

`fuelsignal-daily-update.service` therefore runs as root, not
`{{ fuel_signal_user }}` - restarting a systemd unit needs that - and drops
to `{{ fuel_signal_user }}` itself (via `runuser`, same pattern as
`fuelsignal-deploy.sh`) for the actual `git pull`/`uv sync`/DB steps.

For an on-demand restart in between daily runs (e.g. right after pushing a
fix upstream, without waiting for the timer), `fuelsignal-deploy` (templated
to `/usr/local/bin/fuelsignal-deploy`) is still there to run by hand:

```bash
ssh viking.home.wordspeak.org sudo fuelsignal-deploy
```

It does `git pull --ff-only` + `uv sync` as the `fuelsignal` account
(usually a no-op by the time you run it, since the timer already pulled),
then restarts `fuelsignal-workbench.service` - but unlike the daily timer,
it doesn't warm the workbench back up afterward.

## Daily update: `git pull`, not a live FuelCheck API call

`fuelsignal-daily-update.sh` (formerly `fuelsignal-signal-check.sh` - and
its service/timer were `fuelsignal-signal.*` - renamed because "signal
check" undersold what it does) used to run `fuel_signal.live` (hitting the
FuelCheck API directly, which needed OAuth credentials). It doesn't anymore:
`fuel-price-signal` already runs its own `daily-snapshot.yml` GitHub Action
that fetches the same data and commits it to `data/snapshots/**/*.csv`
(tracked in git), so calling the live API a second time from viking was
redundant.

`fuelsignal-daily-update.sh.j2` now does `git pull --ff-only` + `uv sync` to
bring in whatever landed upstream (today's snapshot commit, and any code/
dependency changes riding along with it), then mirrors upstream's own
`daily-db-update.yml` GitHub Actions workflow (see that project's README,
"CI: DB and model pipeline"): `fuel_signal.db` (loads the new snapshot file
via its `loaded_files`-table tracking), `fuel_signal.fill` (rebuilds
`daily_prices`), `fuel_signal.classify --snapshot-date <today>`, and
`fuel_signal.lga_leadership --snapshot-date <today>` - both scoped to a
single date (their default when `--start-date` isn't given), not the
`--start-date`-driven backfill mode used for a from-scratch rebuild.

### Waiting for the snapshot

GitHub starts upstream's scheduled `daily-snapshot.yml` (cron
`0 10 * * *`) anywhere from minutes to many hours late. Commits have landed
as late as 17:50 UTC, and GitHub sometimes skips a scheduled run entirely,
so no fixed timer time is reliably "after the snapshot". Instead, after the
first `git pull` the script checks for today's file,
`data/snapshots/YYYY/MM/YYYY-MM-DD.csv`. The date is UTC, because the
Action names the file from its runner's UTC date. If the file isn't there,
the script re-runs `git pull --ff-only` every
`fuel_signal_daily_update_snapshot_poll_interval_seconds` (default 600s)
until it appears or `fuel_signal_daily_update_snapshot_wait_timeout_seconds`
(default 21600s, so 2am to about 8am Sydney) runs out. A failed pull inside
the loop is treated as "not yet" and retried. The first pull, before the
loop, still aborts the run if it fails.

On timeout the script logs a warning-priority journal line ("Snapshot for
<date> never arrived after <N>s, continuing with existing data") and runs
the rest of the pipeline anyway. Code changes, the workbench restart and
the signal cache still happen, and `/api/v1/recommendation`'s `freshness`
block reports the staleness to clients. `fuel_signal_daily_update_oncalendar`
(02:00 Australia/Sydney) is therefore a start time, not a safety margin.
The service sets no `TimeoutStartSec=`, since `Type=oneshot` has no start
timeout by default (systemd.service(5)).

A missed snapshot leaves viking one day behind, and it doesn't add up over
consecutive misses. `fuel_signal.db` loads every snapshot file it hasn't
loaded yet, so a late file gets picked up the next night. In
`/api/v1/recommendation`'s `freshness` block, `days_stale: 2` with
`expected_lag_days: 1` means exactly one snapshot was missed. An Action run
that starts after UTC midnight names its file for the next UTC day, so that
night's wait always times out and the data catches up a night later. To see
how a night went:

```bash
ssh viking.home.wordspeak.org journalctl -u fuelsignal-daily-update.service --since today
```

`fill` alone isn't sufficient for the always-on workbench: `/classification-health`
reads `station_class`/`classification_summary` and `/lead-lag` reads
`lga_leadership`, neither of which `fill` touches. `--snapshot-date` is
computed explicitly as `date -u +%Y-%m-%d` in the script rather than left
to `classify`/`lga_leadership`'s own `date.today()` default - that default
reads the *host's local date*, and viking's isn't UTC (confirmed in a real
run: `fill`/`signal` logged `2026-08-10` from their local-date default
while the snapshot that had just landed, and `git pull`/`fuel_signal.db`,
were dated `2026-08-09` UTC) - same "don't trust viking's configured system
timezone" reasoning behind `fuel_signal_daily_update_oncalendar` naming an
explicit zone (`Australia/Sydney`, resolved from systemd's own tzdata)
rather than reading `/etc/localtime`.

After `classify`/`lga_leadership`, the script also runs
`fuel_signal.generate_signal_cache` (no-arg - it defaults to the latest
date in `daily_prices`, which the steps above just brought current), which
precomputes and stores the payload behind the workbench's `/api/v1/stations`
and `/api/v1/recommendation` endpoints. Without this step those endpoints
return `HTTP 503` (missing cache) indefinitely, no matter how current the
rest of the DB is - `fill`/`classify`/`lga_leadership` don't touch the
table it writes. Like `classify`/`lga_leadership`, a failure here aborts
the script (`set -e`) before the `fuelsignal-workbench.service` restart
below, so the workbench never restarts into a stale or missing signal
cache.

No `fuel_signal.signal` call - the buy/wait CLI verdict isn't consumed by
anything on viking (nothing forwards it anywhere, the workbench doesn't
need it), so it's dropped rather than run for no reason. Run it by hand
whenever you're curious: `sudo -u fuelsignal env UV_PYTHON_PREFERENCE=only-system
/usr/local/bin/uv run python -m fuel_signal.signal` from
`{{ fuel_signal_repo_dir }}`.

(The old `fuelsignal-signal.*` unit files and script were retired on
viking via a transitional cleanup in `tasks/main.yml`, removed again once
confirmed applied - see git history if this ever needs redoing for another
host.)

**Runtime**: `fuel_signal.fill` is not incremental - it fully rebuilds
`daily_prices` from every station's entire price history on every run
(confirmed on viking: ~6 minutes of a ~7-minute total run, rebuilding 747
stations / 2.3M rows from one new snapshot file). `classify`/`lga_leadership`
are cheap by contrast (single-date, bounded window). This will keep
growing slowly as history lengthens - not a problem today for a
once-daily oneshot unit, but worth watching.

This also means the role no longer needs any FuelCheck credentials at all -
no `/etc/fuelsignal/fuelsignal.env`, no `EnvironmentFile=` on either systemd
unit, no private-vars wiring in `site.yml`. The private `local_setup-scripts`
repo's `roles/fuel_signal/vars/private_vars.yml` (which held those
credentials) has been removed there too - it was never committed, just an
untracked file on disk.

`fuel_signal.db` (SQLite, WAL) is gitignored - `git pull` never brings it
along, but nothing on viking needs a pre-built copy: the checkout builds
its own from scratch (`history` → `db` → `fill` → `classify` →
`lga_leadership`, run once by hand as `fuelsignal` after the first
`ansible-playbook` run). `data/snapshots/**/*.csv` is tracked in git, so
that part arrives free with every `git pull`/clone.

## Trained models: pulled from a GitHub Release, not synced from the Mac

`data/models/*.joblib` is gitignored too, and like the DB it's built
elsewhere and pulled in rather than shipped in the checkout -
`fuel-price-signal`'s `build-model.yml` GitHub Actions workflow trains the
model and publishes `lgbm.joblib` +
`lgbm_calibrated.joblib` as assets on a GitHub Release tagged
`model-latest`, re-uploaded with `--clobber` on every run (so the tag
always points at the current model - no versioned tags to track). This is
deliberately a public Release rather than an Actions artifact: viking is an
external, unattended box, not a GitHub Actions runner, so it needs a plain
HTTPS download with no stored credential - only Releases give you that;
artifacts and the Actions cache both require an authenticated API call.

Model training happens in CI, not on viking, for the same memory reason it
never happened on the Mac's behalf locally either - a real
`uv run python -m fuel_signal.features` benchmark on viking's hardware (4
cores, 3.6GB RAM) against the full price history OOM-killed at ~3GB
resident plus a fully-drained 4GB swap file. The APU3 board just doesn't
have the memory for full-history feature engineering.

Pull the latest model files with (templated to
`/usr/local/bin/fuelsignal-model-update`):

```bash
ssh viking.home.wordspeak.org sudo fuelsignal-model-update
```

which downloads both assets as the `fuelsignal` account into
`data/models/` and restarts `fuelsignal-workbench.service`. Run by hand
whenever you choose - not scheduled, not run by `fuelsignal-deploy`.

## Networking

`fuel_signal_workbench_host` defaults to `127.0.0.1` (fail-safe: a host
that forgets to override this just isn't reachable over LAN, rather than
accidentally exposed) and is overridden for `viking` in
`host_vars/192.168.20.200.yml`. A hard `assert` in `tasks/main.yml` refuses
to template a `0.0.0.0` bind. Firewalld is opened for
`fuel_signal_workbench_port` (default `5000/tcp`) on this box only -
there's no reverse proxy or auth in front of the workbench, so keep it
LAN-only.

## Running the play

```bash
cd ansible
ansible-playbook -u root -i inventory.yml site.yml --limit 192.168.20.200
```

(by IP rather than `viking.home.wordspeak.org`, same caveat as
`samba_timemachine`'s README, until the static-IP/DNS change lands).
