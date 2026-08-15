# nut_ups

Runs [Network UPS Tools](https://networkupstools.org/) (`usbhid-ups` +
`upsd` + `upsmon`) on `viking` in standalone mode, talking to a CyberPower
BR700ELCD over USB. Gives Home Assistant battery charge/load/runtime and
line-status data, and triggers a clean shutdown of viking itself if the
UPS reports low battery during an outage.

## Off by default - fix the hub first

`nut_ups_enabled` defaults to `false`, so applying `site.yml` currently
no-ops this role entirely. **Don't flip it on yet.**

The UPS is plugged into an unpowered VIA VL812 USB hub, shared with the
EyeTV Diversity DVB tuner (`roles/dvb_tuner`) - `lsusb -t` shows both under
`Bus 003 Device 002`. With no dedicated power feeding the hub, its
downstream ports run off whatever the host's USB2 port budget leaves over,
and `journalctl -k` on 2026-08-15 showed the UPS's USB link cleanly
disconnecting and re-enumerating every ~7-11 seconds (no xHCI transfer
errors logged - consistent with port-level power starvation, not a bad
cable or a protocol fault). Running `usbhid-ups` against a link that flaps
that often is worse than not monitoring at all, since the one moment this
needs to actually work is mid-outage.

Fix: power the hub properly (its power-input port is rated 5V/2.1A per its
own label - any real USB charger/wall brick meeting that, including a
USB-C one, is fine; just don't power it from a computer's USB port, which
can drop power on sleep). Once it's powered, confirm the flapping has
stopped:

```bash
ssh viking.home.wordspeak.org "sudo journalctl -k --since '5 min ago' | grep -i 'usb disconnect\|0764:0501'"
```

No more `USB disconnect` lines for the UPS -> safe to enable this role.

## Prerequisites (outside this repo)

`nut_ups_monuser_password` must be set via the private `local_setup-scripts`
overlay (`ansible/roles/firewall/vars/private_vars.yml`, the same file
`pxe_install_root_password_hash` lives in - see `roles/pxe_install`'s
README for how that file gets wired into `site.yml`). It's stored and
transmitted **in cleartext** by NUT's own protocol (`upsd` needs the
plaintext to authenticate `upsmon` and Home Assistant), not hashed - treat
it as a LAN-only credential and don't reuse a password from anywhere else
for it.

## Enabling

ansible-core 2.19+ requires JSON-typed `-e` values for booleans:

```bash
cd ansible
ansible-playbook -i inventory.yml site.yml --tags nut_ups \
  -e '{"nut_ups_enabled": true}' --limit viking.home.wordspeak.org
```

Verify with `upsc cyberpower` on viking - it should print battery charge,
load, runtime and status fields.

## Home Assistant integration - one-time manual step

Same category as Tvheadend's channel scan (`roles/tvheadend`'s README) and
the reverse proxy's HA trust step (`roles/reverse_proxy`'s README): HA's
NUT support is a config-flow integration set up through the UI, not
YAML, so this role can't wire it up non-interactively.

In Home Assistant: **Settings > Devices & Services > Add Integration >
NUT**, host `127.0.0.1`, port `3493` (`nut_ups_listen_port`), username
`nut_ups_monuser` (default `upsmon`), password `nut_ups_monuser_password`.
This exposes battery charge, load, runtime, and status sensors that can
drive dashboards/automations (e.g. notify on `ONBATT`).

## Why a single shared upsd user

`upsd.users` defines one account (`nut_ups_monuser`) with the `upsmon
primary` role, used both by the local `upsmon` (which needs primary rights
to trigger `SHUTDOWNCMD`) and by Home Assistant's polling. HA only ever
reads status with it, but there's no separate read-only role worth the
extra account for a single-host, single-UPS setup - if that ever changes,
add a second `[ha]` stanza in `templates/upsd.users.j2` with a plain
(non-`primary`) role instead of reusing this one.

## USB device identification

`ups.conf` pins `vendorid = 0764` / `productid = 0501` rather than leaving
`usbhid-ups` to auto-match, and `templates/70-nut-cyberpower.rules.j2`
grants the `nut` group access to that exact USB ID explicitly rather than
relying on it being covered by the `nut` package's own bundled udev rules.
(Config lives in `/etc/ups/`, not the `/etc/nut/` Debian/Ubuntu use - this
role's own name is just the Ansible role's, unrelated to the path RHEL's
`nut` package actually installs into.)
Both are belt-and-braces, not strictly required - there's only one USB HID
power device on this host - but cheap insurance against ambiguity if
another USB HID device is ever added.

Note `lsusb` reports this device as "CP1500 AVR UPS", not "BR700ELCD" -
CyberPower's AVR-series UPSes share a single USB product ID across models,
so that's expected, not a misidentification.
