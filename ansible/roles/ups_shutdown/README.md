# ups_shutdown

Powers the firewall off cleanly when its UPS (a CyberPower BR700ELCD, same
model as viking's - see `roles/nut_ups`) is on battery and charge drops
below `ups_shutdown_min_charge` (default 10%). Losing mains on its own does
nothing beyond a log line - the firewall keeps running on battery until
the charge gets that low. Uses only OpenBSD base:
the kernel's `upd(4)` driver exposes the UPS as `hw.sensors.upd0.*`, and
`sensorsd(8)` runs `/etc/sensorsd/ups_low_battery` when those sensors
change.

## Why not NUT, like viking

NUT's `usbhid-ups` can't open the UPS while `upd(4)` holds it, and the only
ways round that are disabling `uhidev`/`upd` in the kernel (which also
takes out USB keyboards) or a custom kernel quirk. Not worth it on the
gateway. It also keeps the firewall free of another listening service -
the trade-off is that its UPS isn't visible in Home Assistant.

## Known limitation: it stays off

`upd(4)` can't tell the UPS to cut and restore its output the way NUT's
killpower does. If mains returns after the firewall has powered off but
before the UPS battery runs flat, the UPS never drops its outlets, the
BIOS's power-on-after-AC-loss never fires, and the firewall stays off
until someone presses its power button. Accepted deliberately: at this
load it takes a long outage to get here.

## How the trigger works

`sensorsd` runs the script whenever a watched sensor crosses its limit in
either direction, and also once at startup (about a minute after start -
it waits for three consistent readings). So the script never acts on the
trigger alone: it re-reads `sysctl hw.sensors.upd0` and only runs
`shutdown -p now` if ACPresent is Off **and** RemainingCapacity is below
the threshold. Two sensors are watched so both orders are caught: charge
falling through the threshold during a long outage, and power failing
again while charge is still low from a previous one.

`upd(4)` always reports indicator status as `OK`, so ACPresent needs an
explicit `low=1` in `sensorsd.conf` - a plain status watch never fires on
it.

`sensorsd.conf` can only address sensors by index (`indicator2`,
`percent0`). The play reads `sysctl hw.sensors.upd0` first and fails if
those indices don't carry ACPresent / RemainingCapacity, which also
catches the UPS being unplugged. The script itself matches by description.

## Applying

```bash
cd ansible
ansible-playbook -i inventory.yml site.yml --tags ups_shutdown \
  --limit 192.168.20.254
```

## Checking it

Every trigger logs to `/var/log/daemon` under `ups_shutdown`, including
the startup one, so straight after applying:

```bash
ssh 192.168.20.254 "grep ups_shutdown /var/log/daemon | tail"
```

should show `AC On, charge 100%; no action` lines. Pulling the UPS's mains
plug for a minute or two should log `AC Off ... no action` and then
`AC On` again on restore, without shutting down.
