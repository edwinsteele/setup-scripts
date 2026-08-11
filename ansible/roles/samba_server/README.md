# samba_server

Provisions `viking` - the reimaged old-firewall APU3 hardware (see
[pxe_install](../pxe_install/README.md)) - as a Samba server. This role
owns the generic plumbing only: packages (`samba`, `avahi`), the `[global]`
section of `smb.conf`, firewalld rules, and the `smb`/`avahi-daemon`
service lifecycle. It's Rocky Linux 9, not OpenBSD, so it lives in its own
`rocky_9`/`timemachine_servers` inventory groups and gets its own plays in
`site.yml` - the pre-existing `hosts: all` plays exclude `rocky_9`
explicitly (`hosts: 'all:!rocky_9'`) because roles like `network`, `pf`,
`mail_sender`, and `bootstrap` are OpenBSD-only (`pfctl`, `doas`,
`openbsd_pkg`). `common`, `esteele_acct`, `git`, and `esteele_contents` are
shared roles - each dispatches to an OS-specific task file (or an inline
`when:`) based on `ansible_facts['os_family']`, so the same role provisions
both OpenBSD and Rocky hosts.

The actual shares are owned by separate roles, one per share:
[samba_timemachine](../samba_timemachine/README.md) and
[samba_media](../samba_media/README.md). This role's `smb.conf.j2` template
references their `samba_timemachine_*`/`samba_media_*` variables directly -
that works regardless of role execution order because Ansible merges every
role's `defaults/main.yml` into the play's variables at parse time, not at
task-execution time. Keeping this split (rather than one role that did
everything) means the role name matches what it does - a role that just
happened to also run the Time Machine share isn't a good home for an
unrelated media share.

## Disk layout

Both shares live on a single 4T Seagate disk attached to `viking`
(`/dev/sdb`), GPT-partitioned, no LVM:

- `sdb1` - 200M EFI leftover from the disk's previous life as an
  APFS-formatted Mac drive (macOS creates this alongside every APFS
  container). Unused, left in place - not worth reclaiming for 200M.
- `sdb2` - XFS, label `Data`, mounted at `/srv/media` by
  [samba_media](../samba_media/README.md).
- `sdb3` - XFS, label `TimeMachine`, mounted at `/srv/timemachine` by
  [samba_timemachine](../samba_timemachine/README.md).

Both share roles mount their partition by filesystem label
(`/dev/disk/by-label/Data`, `/dev/disk/by-label/TimeMachine`) via
`ansible.posix.mount`, so nothing host-specific is needed in `host_vars`.
Formatting the partitions and copying data onto them is a manual, one-time
step, not something any role does - a first apply expects the labels above
to already exist:

```bash
sudo mkfs.xfs -f -L Data /dev/sdb2
sudo mkfs.xfs -f -L TimeMachine /dev/sdb3
```

(run once, after copying any data that needs to survive the reformat off
to other storage first)

### USB-SATA bridge quirk

This role also disables the Linux `uas` driver for this specific disk's
USB bridge (`samba_server_seagate_usb_id`, `0bc2:331a`) via a `grubby`
kernel boot arg. Hit for real on 2026-08-11: sustained write load (the
initial rsync of the media library) made the bridge drop commands, which
cascaded into dozens of SCSI resets and eventually an XFS log shutdown on
`sdb2` - the drive itself briefly disappeared from the USB bus and needed
a physical power-cycle to come back. Forcing the older `usb-storage` (BOT)
driver avoids it.

`grubby` only edits the bootloader entry - it doesn't take effect until
the next reboot, and this role doesn't reboot the host automatically (it's
in active use for Samba/HA/other services). After a first apply that
changes this arg, reboot manually when convenient:

```bash
ssh viking.home.wordspeak.org sudo reboot
```

## Networking

Unlike the OpenBSD hosts, `viking` has no ansible-managed network role - it
just gets a static IP via a DHCP reservation on the gateway (like
`mariner-wifi`/`office-ethernet`), configured in the private
`local_setup-scripts` repo's `generate_local_address_files.py` and applied
the same way as any other DHCP/unbound change:

```bash
cd ~/Code/local_setup-scripts/ansible && python3 generate_local_address_files.py
cd ~/Documents/Code/setup-scripts/ansible
ansible-playbook -i inventory.yml site.yml --tags firewall --limit 192.168.20.254
```

## Running the play

```bash
cd ansible
ansible-playbook -u root -i inventory.yml site.yml --limit viking.home.wordspeak.org
```

(or `--limit 192.168.20.200` until the DHCP/unbound change above has been
applied to the gateway and `viking.home.wordspeak.org` resolves).

This also applies `samba_timemachine` and `samba_media`, since `site.yml`
lists all three roles together for `rocky_9`.

## Manual post-step: Samba password

Samba keeps its own password database (`tdbsam`), separate from the Linux
account password (which `esteele_acct`'s Rocky branch locks entirely). This
repo doesn't set it, the same way it doesn't commit root password
hashes/SSH keys - run this once, interactively, after the first apply. It
covers both shares, since they share the same `esteele` login:

```bash
ssh viking.home.wordspeak.org sudo smbpasswd -a esteele
```
