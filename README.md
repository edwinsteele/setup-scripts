# Files in this area

* ansible: Provisioning of wordspeak webserver and home firewall
* vagrant: provisioning of gemini-type VM using vagrant. Only setup
  locally as I didn't want to spend time learning EC2 provisioning
  inside vagrant. Eventually switched to using ansible directly,
  rather than through vagrant

# Provisioning a VM on an existing Install

This is the case where a base OS install already exists, either because
a cloud provider image has been used, or a virtualbox OS install has
already been setup

Assumes that your default ssh public key is installed on the server under
the account that you'll be using for provisioning (root)

## General pre-work
1. `workon ansible`  (the virtualenv should already exist from previous work)
2. `cd ~/Code/setup-scripts/ansible`
2. Replace the host in `hosts` with the IP address of the newly provisioned
   host, placing it in the group section that corresponds to the `--limit`
   argument used in the `ansible-playbook` commands for the appropriate type of VM install
3. `cd ~/Code/local/startssl; ./make_bundles.sh` (if deploying a webserver)

## Setup OpenBSD

OpenBSD requires hand-installation on cloud providers, and vagrant images
so we install ourselves.

* do install from CD,
* setup all network interfaces
* do not setup a user
* start ssh and allow root login with 'prohibit-password'
* selecting correct timezone
* default disk layout
* all packages (for simplicity)
* reboot
* add root `.ssh/authorized_keys` via console
  * `.ssh` directory is 600
  * `authorized_keys` is 600


## Provisioning a local VM

Note that it's not possible to test ansible connectivity on OpenBSD hosts
until they have a python interpreter, which is the first step in the common
playbook.

The default architecture is `openbsd-amd64` and if the installation machine is
another architecture, create a file under `host_vars` with a PKG_PATH
definition with the appropriate architecture specified e.g.
`PKG_PATH: 'http://mirror.internode.on.net/pub/OpenBSD/5.8/packages/powerpc/'`

In the `ansible` directory at the same level as this `README.md` file run:

`ansible-playbook -u root -i hosts --limit <limit-criteria> site.yml`

Where the limit criteria is something like:

* 192.168.56.101  (an IP address)
* webservers (a single group name)
* 'webservers:&192.168.56.101' (the union of a group and an IP address)

## Provisioning common steps

15. Logon to the VM to perform the rest of the steps
16. Update `/etc/hosts` to have FQDN for host, and short and FQDN for any sites that the machine will serve
20. `cd ~/Code && git clone git@github.com:edwinsteele/dotfiles.git`
21. `cd ~/Code/dotfiles && ./make.sh`
25. `cd ~/Code/wordspeak.org && /home/esteele/.virtualenvs/wordspeak_n7/bin/fab build staging_sync`

# Provisioning a VM on a local machine with Vagrant/VirtualBox

**Broken - only for linux**

Assumes virtualbox, vagrant 1.7

1. `workon ansible` (venv should already exist)
2. confirm that the IP address in setup-scripts/vagrant/mercury-vm/Vagrantfile is the same as setup-scripts/vagrant/mercury-vm/vagrant-ansible_hosts
3. In directory setup-scripts/vagrant/mercury-vm, run "vagrant up" to boot an existing VM, or "vagrant destroy" and "vagrant up" to reprovision.
4. Possibly do most of the post ansible steps above

For ad-hoc running of ansible playbooks, after the esteele account has been created, run e.g.: `ansible-playbook -u esteele -i ../../vagrant/mercury-vm/vagrant-ansible_hosts ./language_explorer.yml` (and change the user line to esteele instead of root in the playbook). 
TODO - see if we can remove the user line entirely and specify all the time on commandline

# VirtualBox assumptions

* Assumes that the VM can talk to the VirtualBox Host, and to the outside world. This can be done by configuring the VM with two network adapters, one as NAT and the other as host-only (which requires creation of a host-only network on the host)
* Shared clipboard is enabled (bidirectional)
