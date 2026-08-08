# fuel_signal

Deploys [fuel-price-signal](https://github.com/edwinsteele/fuel-price-signal)
on `viking` (see [samba_timemachine](../samba_timemachine/README.md) for what
else lives on that box) as a dedicated `fuelsignal` system account, with:

- an hourly `fuelsignal-signal.timer` that fetches fresh FuelCheck prices
  and prints the buy/wait signal to the journal, and
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

## Updates are manual and batched, not continuous

The `ansible.builtin.git` task uses `update: false` - it only clones on
first run. Re-running this play (e.g. for an unrelated `home_assistant`
change) never pulls new commits. Updates go through `fuelsignal-deploy`
(templated to `/usr/local/bin/fuelsignal-deploy`), run by hand whenever you
choose:

```bash
ssh viking.grus.space sudo fuelsignal-deploy
```

which does `git pull --ff-only` + `uv sync` as the `fuelsignal` account,
then restarts `fuelsignal-workbench.service`. The signal-check timer
doesn't need restarting - it's a oneshot that picks up the new checkout and
venv on its next scheduled firing.

## Secrets: FUELAPI_API_KEY / FUELAPI_API_SECRET

Both systemd units load `/etc/fuelsignal/fuelsignal.env`
(`EnvironmentFile=`, mode `0640` root:`fuelsignal`), templated from
`fuel_signal_fuelapi_api_key`/`fuel_signal_fuelapi_api_secret` - blank by
default in `defaults/main.yml`. Real values go in the private
`local_setup-scripts` repo (not this one), same pattern as
`roles/firewall`'s `pppoe_password`:

```
/Users/esteele/Code/local_setup-scripts/ansible/roles/fuel_signal/vars/private_vars.yml
```

(scaffolded already, blank - fill in your NSW FuelCheck OAuth client
credentials before running this role for real) and wired into `site.yml`'s
`rocky_9` play via `vars_files:`, next to the equivalent `firewalls` play
wiring.

## One-time bootstrap: DB and trained models

`fuel_signal.db` (SQLite, WAL) and `data/models/*.joblib` are gitignored -
`git pull` never brings them along. Sync them from your Mac dev checkout
once, straight into the `fuelsignal`-owned checkout, using esteele's
existing passwordless sudo rather than granting `fuelsignal` its own
inbound SSH access. This role installs `rsync` on viking for exactly this
(Rocky 9 minimal doesn't ship it by default).

Model training happens on the Mac, not on viking, deliberately - a real
`uv run python -m fuel_signal.features` benchmark on viking's hardware (4
cores, 3.6GB RAM) against the full price history OOM-killed at ~3GB
resident plus a fully-drained 4GB swap file. The APU3 board just doesn't
have the memory for full-history feature engineering, so there's no
version of "train it on-host instead" that works without either a memory
optimization in the upstream repo or more RAM than this board has.

```bash
cd ~/Code/fuel-price-signal   # your dev checkout
rsync -avz --rsync-path="sudo -u fuelsignal rsync" \
  fuel_signal.db fuel_signal.db-wal fuel_signal.db-shm \
  data/models/ \
  viking.grus.space:/srv/fuelsignal/fuel-price-signal/data/models/ \
  2>&1  # adjust source paths/flags to taste; run db + data/models as separate rsyncs if you prefer

# data/tgp/ (AIP TGP downloader cache) if you're relying on it rather than
# letting it rebuild on first live.py run:
rsync -avz --rsync-path="sudo -u fuelsignal rsync" \
  data/tgp/ viking.grus.space:/srv/fuelsignal/fuel-price-signal/data/tgp/
```

Do this after the first `ansible-playbook` run (the checkout and
`fuelsignal` account need to exist first) and again whenever your dev
machine's DB/models get meaningfully ahead of what's on `viking`. This is a
manual step by design - not scheduled, not run by `fuelsignal-deploy`.

`data/snapshots/**/*.csv` is tracked in git, so that part arrives free with
every `git pull`/clone.

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

(by IP rather than `viking.grus.space`, same caveat as
`samba_timemachine`'s README, until the static-IP/DNS change lands).
