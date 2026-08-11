# samba_timemachine

Owns the `TimeMachine` share on `viking`: mounts the `TimeMachine`-labelled
XFS partition (`sdb3`, see [samba_server](../samba_server/README.md#disk-layout)
for the full disk layout) at `/srv/timemachine`, sets its ownership and
SELinux `samba_share_t` context, and advertises it over Bonjour/mDNS
(`avahi-daemon` + `_adisk._tcp`, see `templates/adisk.service.j2`) so it
auto-discovers in System Settings > Time Machine.

It doesn't install Samba, own `smb.conf`, or manage the `smb`/`avahi-daemon`
services - that's [samba_server](../samba_server/README.md), which reads
this role's `samba_timemachine_*` defaults to render the `[TimeMachine]`
share stanza. See that role's README for installation, networking, running
the play, and the Samba password setup step.

Connect from a Mac via Finder (`Go > Connect to Server`,
`smb://viking.home.wordspeak.org/TimeMachine`) or System Settings > Time
Machine.
