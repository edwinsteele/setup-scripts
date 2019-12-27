# Files in this area

* ansible: Provisioning of wordspeak webserver and home firewall
* packer: Creation of OpenBSD virtualbox images
* vagrant: Vagrantfiles for each type of machine

# OS Setup a VM from scratch (VirtualBox, with packer and vagrant)

Creation of virtualbox images is done via packer.

This setup relies on packer being able to accept incoming connections, so review firewall on the host if it's not working. It also requires the `variables["mirror"]` setting in the packer json file correspond to the HTTP server in the `http/install.conf`.

As this setup uses OpenBSD autoinstall, it's necessary to set DHCP variables:

```
option tftp-server-name "openbsd-mirror.soyuz.local:8080";
option bootfile-name "auto_install";
```

(the type-server-name corresponds, again, to the `variables["mirror"]` setting in the packer json file. The dhcp options (for VMWare Fusion) are set in `/Library/Preferences/VMware Fusion/vmnet8/dhcpd.conf` (then restart the process to apply changes. Probably `/Applications/VMware Fusion.app/Contents/Library/vmnet-dhcpd -s 6 -cf /Library/Preferences/VMware Fusion/vmnet8/dhcpd.conf -lf /var/db/vmware/vmnet-dhcpd-vmnet8.leases -pf /var/run/vmnet-dhcpd-vmnet8.pid vmnet8`)

1. Setup or review the file *(the varfile)* containing the private packer variables (`ssh_private_key_file`, `ssh_public_key_str`, `root_bcrypt_hash`)
2. cd ~/Code/setup-scripts/packer
3. `packer build -var-file=<path-to-varfile> openbsd.json`
4. The ovf and vmdk files will be found in the `output_directory` specified in the openbsd.json file. Take note of the path to the ovf file that's been created, as it is necessary below.
5. `vagrant box add --name openbsd64 build/openbsd64-amd64-vmware.box`
5. `cd` into a directory under vagrant, that defines the type of machine that you want, and look at the `config.vm.box`. Vagrant won't pull in the machine that you've just built if it's already been important. If `vagrant box list` shows a box with the same name as the `config.box.vm` directive in the `Vagrantfile` then run `vagrant box delete <name-of-box>`
6. run `vagrant up`
7. If you haven't done a DHCP mapping, find the new IP address on the DHCP server (look for recent *DHCPACK* log line in `/var/log/daemon` if it's OpenBSD)
13. Login as root, using the private key associated with the `ssh_private_key_file` that was used in the packer setup phase

# OS Setup a cloud host from scratch

OpenBSD requires hand-installation on cloud providers

* boot from ISO
* do an auto-install, using an auto-install conf hosted in this repo i.e. use https://raw.githubusercontent.com/edwinsteele/setup-scripts/master/autoinstall/gemini-install.conf
* detach the ISO (which triggers a reboot on Vultr - manual reboot may be necessary)

# Provisioning using ansible once the OS setup is complete

Once the base OS has been setup, we do further setup using ansible.
Assumes that your default ssh public key is installed on the server under
the account that you'll be using for provisioning (root), or that you provide
a different key to ansible with `--private-key=PRIVATE_KEY_FILE`

## General pre-work
1. `workon ansible`  (the virtualenv should already exist from previous work)
1. `cd ~/Code/setup-scripts/ansible`
1. Replace the host in `hosts` with the IP address of the newly provisioned
   host, placing it in the group section that corresponds to the `--limit`
   argument used in the `ansible-playbook` commands for the appropriate type of VM install

## Performing non-OS setup

Note that it's not possible to test ansible connectivity on OpenBSD hosts until they
have a python interpreter, which is the first step in the common playbook.

In the `ansible` directory at the same level as this `README.md` file run:

`ansible-playbook -u root -i hosts --limit <limit-criteria> site.yml`

Where the limit criteria is something like:

* 192.168.56.101  (an IP address)
* webservers (a single group name)
* 'webservers:&192.168.56.101' (the union of a group and an IP address)

## Additional steps

1. On the newly provisioned VM:
  1. Update `/etc/hosts` to have FQDN for host, and short and FQDN for any sites that the machine will serve
  1. `cd ~/Code/dotfiles && ./make.sh`
  1. ``doas acme-client -v wordspeak.org``
1. (for a webserver) From the old webserver:
  1. `for d in images.wordspeak.org language-explorer.wordspeak.org staging.wordspeak.org www.wordspeak.org; do rsync --rsync-path=/usr/bin/openrsync -av /home/esteele/Sites/$d/ 139.180.174.179:/home/esteele/Sites/$d/; done`
1. (on desktop, not the VM) `cd ~/Code/wordspeak.org && /home/esteele/.virtualenvs/wordspeak_n7/bin/fab build staging_sync` (for webserver)
