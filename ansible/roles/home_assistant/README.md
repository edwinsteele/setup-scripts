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

**If you do copy/move a file into the config directory from outside the
container**, and Home Assistant/the Backups page doesn't seem to see it:
check `ls -Z` on it vs. its siblings. A same-filesystem `mv` preserves the
*source's* SELinux label (e.g. `user_tmp_t` from wherever it was `scp`'d
to) rather than adopting the destination directory's - it won't match the
private `container_file_t:s0:cXXX,cYYY` category Podman's `:Z` flag
assigned this container, and the container will silently fail to see the
file (a denial, not a missing-file error, but it looks identical from
Home Assistant's side). `sudo systemctl restart home-assistant` fixes it
- Podman re-walks and relabels the whole bind-mounted tree on every
start - or `sudo restorecon -Rv <path>` / `sudo chcon -t container_file_t
<path>` for a targeted fix without restarting.

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
ansible-playbook -i inventory.yml site.yml --limit viking.grus.space
```

Home Assistant's onboarding wizard (create the first user, set
location/units) runs once at `http://viking.grus.space:8123/` after the
first apply - that's an interactive step this role doesn't automate.
