# samba_timemachine

Provisions `viking` - the reimaged old-firewall APU3 hardware (see
[pxe_install](../pxe_install/README.md)) - as a Samba/Time Machine target.
It's Rocky Linux 9, not OpenBSD, so it lives in its own
`rocky_9`/`timemachine_servers` inventory groups and gets its own plays in
`site.yml` - the pre-existing `hosts: all` plays exclude `rocky_9`
explicitly (`hosts: 'all:!rocky_9'`) because roles like `network`, `pf`,
`mail_sender`, and `bootstrap` are OpenBSD-only (`pfctl`, `doas`,
`openbsd_pkg`). `common`, `esteele_acct`, `git`, and `esteele_contents` are
shared roles - each dispatches to an OS-specific task file (or an inline
`when:`) based on `ansible_facts['os_family']`, so the same role provisions
both OpenBSD and Rocky hosts.

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
ansible-playbook -u root -i inventory.yml site.yml --limit viking.grus.space
```

(or `--limit 192.168.20.200` until the DHCP/unbound change above has been
applied to the gateway and `viking.grus.space` resolves).

## Manual post-step: Samba password

Samba keeps its own password database (`tdbsam`), separate from the Linux
account password (which `esteele_acct`'s Rocky branch locks entirely). This
repo doesn't set it, the same way it doesn't commit root password
hashes/SSH keys - run this once, interactively, after the first apply:

```bash
ssh viking.grus.space sudo smbpasswd -a esteele
```

Then connect from a Mac via Finder (`Go > Connect to Server`,
`smb://viking.grus.space/TimeMachine`) or System Settings > Time Machine,
where it should also auto-discover via Bonjour/mDNS (`avahi-daemon` +
`_adisk._tcp`, see `templates/adisk.service.j2`).
