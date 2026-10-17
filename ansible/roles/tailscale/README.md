# tailscale

Installs Tailscale on `viking` from Tailscale's own dnf repo and runs
`tailscaled`. The role doesn't join the tailnet. That's a one-time manual
step, because it signs in to the Tailscale account (see below).

## Applying

```bash
cd ansible
ansible-playbook -i inventory.yml site.yml --tags tailscale \
  --limit viking.home.wordspeak.org
```

## Joining the tailnet - one-time manual step

On viking:

```bash
sudo tailscale up --accept-dns=false
```

It prints a login URL. Open it, sign in to the Tailscale account (GitHub
SSO) and approve the machine. Then, in the admin console's Machines page,
use **Disable key expiry** on viking. Otherwise it drops off the tailnet
when its node key expires (180 days by default) until someone signs in
again.

`--accept-dns=false` keeps viking resolving through the gateway's unbound,
as it does now, instead of handing `/etc/resolv.conf` to MagicDNS. Other
tailnet devices can still reach viking by its MagicDNS name.

`tailscale up` settings persist in tailscaled's state
(`/var/lib/tailscale/`), so this survives reboots and re-runs of the role.

## Firewall

firewalld needs no changes. `tailscale0` isn't assigned to a zone, so it
falls into the default zone and tailnet devices can reach the same
services as the LAN does (Samba, Home Assistant, Tvheadend, the reverse
proxy, SSH). Tailscale's own access controls in the admin console limit it
further if needed.

## Verifying

```bash
ssh viking.home.wordspeak.org "tailscale status; sudo firewall-cmd --get-zone-of-interface=tailscale0"
```

viking should be listed with a `100.x.y.z` address, and the zone check
should print `no zone` (so the default zone applies) or the default
zone's name. From the Mac, `tailscale ping viking` should get a reply.
