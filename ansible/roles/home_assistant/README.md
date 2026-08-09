# home_assistant

Runs [Home Assistant Container](https://www.home-assistant.io/installation/linux#install-home-assistant-container)
on `viking` (see [samba_timemachine](../samba_timemachine/README.md) for
what else lives on that box) via a rootful Podman
[Quadlet](https://docs.podman.io/en/latest/markdown/podman-systemd.unit.5.html)
unit, with the config directory itself managed as a git repo.

## Why Container, not Home Assistant OS / Supervised

The previous install (Raspberry Pi, HAOS/Supervised) had exactly one
add-on in use (File Editor - a convenience UI for editing files that
Container doesn't need, since the config directory is just a normal path
on disk you can edit directly). Everything else - Enphase, HomeKit
Bridge, Apple TV, TP-Link, etc. - is a Home Assistant *integration*, not
an add-on, and integrations work identically under Container. Container
also fits this repo's pattern much better than HAOS/Supervised would: a
plain Docker/Podman image and a bind-mounted config directory, rather
than a dedicated appliance OS image.

## Why git-track the config directory instead of relying only on Backup

Home Assistant's `automations.yaml`, `scripts.yaml`, `scenes.yaml`, and
`configuration.yaml` are genuinely plain YAML that the UI keeps in sync -
they diff well and are the main payoff of "version controlled config".
Everything else (integrations/config entries, the device & entity
registry, dashboards unless built in YAML mode) lives in `.storage/*.json`
- not hand-editable, not meaningfully diffable, and in places holds
plaintext integration credentials (e.g. the Enphase Envoy and TP-Link/Tapo
passwords). This role deliberately excludes `.storage/` from git (see
`files/gitignore`) rather than tracking it encrypted - recovering that
layer is what Home Assistant's own **Backup** feature (Settings > System
> Backups, works fine under Container, not just Supervisor) is for.

A nightly `home-assistant-git-snapshot.timer` runs `git add -A && git
commit` in the config directory, so changes made through the UI (a new
automation, a renamed device) still land in git history even though
nobody typed `git commit` by hand.

## Off-host backup of the git layer

The nightly `home-assistant-git-snapshot.timer` also pushes to
[`ha-config-backup`](https://github.com/edwinsteele/ha-config-backup), a
dedicated private GitHub repo, after each commit - the on-host git history
alone doesn't protect against viking's own disk dying, since that's the
only copy. Generating and registering the deploy key is a manual one-time
step (deliberately not automated - key material shouldn't be generated or
handled by a script/agent):

```bash
sudo ssh-keygen -t ed25519 -f /root/.ssh/ha-config-backup_ed25519 -N "" -C "viking ha-config-backup deploy key"
sudo cat /root/.ssh/ha-config-backup_ed25519.pub
```

Add the printed public key at
`https://github.com/edwinsteele/ha-config-backup/settings/keys` with
**Allow write access** checked. Until this is done, the nightly push step
fails (visible as a failed `home-assistant-git-snapshot.service` run) -
that's intentional, not a bug to silence, so an incomplete setup doesn't go
unnoticed.

A dedicated key (not root's general SSH identity) is scoped to just this
repo via `core.sshCommand` in the config directory's local git config, so a
compromised or rotated key here can't reach anything else.

## Editing HA config directly (diffs first, then apply)

Automations/scripts/scenes/`configuration.yaml` are edited live over SSH,
not templated by ansible - the UI writes to these files too, so a second
copy managed by this role would just drift. The workflow:

1. **Commit before editing** (`git add -A && git commit`), even if the
   nightly timer hasn't run yet - pins an exact rollback point immediately
   before the change rather than relying on up-to-a-day-old history.
2. **Propose the edit as a diff first** and wait for approval before
   writing it - never apply directly.
3. Once approved, write the change and **validate config** (Developer
   Tools > YAML > Check Configuration, or the equivalent API) before
   reloading anything.
4. **Reload, don't restart** where possible - automations/scripts/scenes
   support a targeted reload; a full restart is only needed for
   `configuration.yaml` changes that require it, and is riskier (a broken
   config can prevent the container starting at all).
5. **If it breaks**, `git checkout <commit> -- <file>` back to the
   checkpoint from step 1 and reload again - a git revert, not a restore
   from Backup, since `.storage/` (credentials, entity registry) is never
   touched by this workflow.

## Manual one-time steps not covered by this role

- **Automatic backup schedule** (Settings > System > Backups) is a
  UI-managed setting stored in `.storage/`, not something `configuration.yaml`
  or ansible can set - enable it by hand after onboarding.
- **Off-site destination for the `.storage` layer** (credentials, entity
  registry - the actual disaster-recovery unit, separate from the git
  layer above): plan is to point it at the external disk being added to
  viking for Time Machine + the movie library (see viking's backlog notes),
  once that disk physically exists and is mounted. Not yet actionable.

## Root ownership

The container runs as root (the image's default) via a rootful Quadlet
unit - not rootless/user-scoped - to avoid the added complexity of
`systemctl --user` plus `loginctl enable-linger` for no real benefit on a
single-purpose home box. That means every file Home Assistant writes is
root-owned on the host, so hand-editing config over SSH needs `sudo`
(already frictionless: `esteele` has passwordless wheel sudo from
`roles/common`'s RedHat branch). The git-snapshot timer and the git init
task run as root for the same reason - no ownership mismatch to reconcile.

## Networking

The container uses `Network=host` (see the Quadlet unit), not a published
port - mDNS/discovery-based integrations (HomeKit Bridge, Apple TV, Google
Cast) need to see the real LAN, which a bridged Podman network namespace
wouldn't give them. Bluetooth/BLE integrations (Xiaomi BLE, iBeacon
Tracker) were intentionally left out of scope here - `viking`'s APU3 board
has no Bluetooth radio, and there's no USB BT passthrough in this role.

## Restoring a backup from a previous install

Home Assistant's onboarding wizard offers an "Upload backup" step, but its
upload endpoint caps the request body well below the size of a real
backup (hit a hard "16777216 bytes exceeded" error restoring a 36MB
backup here) - and it's upload-only, it doesn't detect files already
present locally. The reliable path: click through onboarding *without*
restoring (a throwaway first-run user is fine, you're about to overwrite
it), then use the authenticated `Settings > System > Backups` page
instead, which manages the `backups/` directory directly. You can drop
the backup file straight into `{{ home_assistant_config_path }}/backups/`
over SSH first (`scp` + `sudo mv`) so it's already there when you get to
that page.

## Updating Home Assistant

`home_assistant_image` defaults to the `:stable` tag for a friendly first
apply. Once running, pin it to a specific version
(e.g. `docker.io/homeassistant/home-assistant:2025.12.0`) in
`host_vars`/`group_vars` - an upgrade then becomes a deliberate git commit
to this repo (bump the tag, re-run the play) rather than something that
happens silently. There's no `AutoUpdate=` label on the Quadlet unit for
the same reason.

## Running the play

```bash
cd ansible
ansible-playbook -i inventory.yml site.yml --limit viking.home.wordspeak.org
```

Home Assistant's onboarding wizard (create the first user, set
location/units) runs once at `http://viking.home.wordspeak.org:8123/` after the
first apply - that's an interactive step this role doesn't automate.
