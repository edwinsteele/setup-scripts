# setup-scripts

Ansible provisioning for the wordspeak webserver and home firewall/gateway.

* `ansible/` - playbooks and roles
* `autoinstall/` - OpenBSD autoinstall confs for bootstrapping new Vultr hosts

## New Vultr host (OpenBSD)

OpenBSD needs hand-installation on Vultr even though pre-built images exist,
because their partitioning scheme only has a single partition.

1. Boot from an ISO with the installation packages (e.g. `install70.iso`).
2. Auto-install using an autoinstall conf. noVNC (used by Vultr) has a paste
   option in the client's pop-out, so you can paste the URL instead of
   typing it: `https://raw.githubusercontent.com/edwinsteele/setup-scripts/master/autoinstall/gemini-install.conf`
3. Detach the ISO (triggers a reboot on Vultr; manual reboot may be needed).

## Provisioning with Ansible

Requires your ssh public key installed on the server under the account
you're provisioning as (root), or pass a different key with
`--private-key=PRIVATE_KEY_FILE`.

```bash
brew install ansible
cd ansible
ansible-galaxy collection install -r requirements.yml
```

Add the new host's IP to `inventory.yml`, under the group matching the type
of install, then run:

```bash
ansible-playbook -u root -i inventory.yml site.yml --limit <limit-criteria>
```

`<limit-criteria>` can be an IP (`192.168.56.101`), a group (`webservers`),
or a combination (`webservers:&192.168.56.101`).

> OpenBSD hosts don't have a python interpreter until the `common` play
> installs one, so ansible connectivity can't be tested before that runs.

## After provisioning

See [docs/webserver-post-provision.md](docs/webserver-post-provision.md)
for the manual steps that bring a freshly provisioned webserver into
service (cert sync, site content, DNS cutover).

## One-off PXE reimage

See [ansible/roles/pxe_install/README.md](ansible/roles/pxe_install/README.md)
for reimaging a piece of hardware (e.g. old firewall) via netboot.

## viking: Samba Time Machine server

See [ansible/roles/samba_timemachine/README.md](ansible/roles/samba_timemachine/README.md)
for the reimaged APU3 hardware, now a Rocky Linux Time Machine target.

## viking: Home Assistant

See [ansible/roles/home_assistant/README.md](ansible/roles/home_assistant/README.md)
for Home Assistant Container, running alongside Samba on the same box.
