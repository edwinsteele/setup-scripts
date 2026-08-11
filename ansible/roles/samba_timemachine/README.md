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

## Multiple users

`samba_timemachine_valid_users` is a list, not a single account - two
Macs can back up to the same share under separate logins (Time Machine
identifies each backup by the Mac's own name/UUID within its
`.sparsebundle`, not by which SMB login was used, so sharing the share
this way is fine). `esteele`'s Unix account comes from `esteele_acct`
(every host); anyone else in `samba_timemachine_valid_users` needs an
entry in `samba_timemachine_extra_accounts` too, which this role
provisions as a Samba-only Unix account (no shell, no home directory,
locked Linux password, added to the `esteele` group for share write
access). Currently: `esteele` and `cheriesteele`.

Each user's *Samba* password is separate from (and, since Linux passwords
are locked, unrelated to) their Unix account, and is a manual post-step
the same way `esteele`'s is - see the Samba password section in
[samba_server](../samba_server/README.md):

```bash
ssh viking.home.wordspeak.org sudo smbpasswd -a cheriesteele
```

Connect from a Mac via Finder (`Go > Connect to Server`,
`smb://viking.home.wordspeak.org/TimeMachine`) or System Settings > Time
Machine.
