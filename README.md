# Files in this area

* ansible: Provisioning of wordspeak webserver and home firewall
* packer: Creation of OpenBSD virtualbox images

# OS Setup a VM from scratch (VirtualBox)

Creation of virtualbox images is done via packer.

1. Setup or review the file *(the varfile)* containing the private packer variables (`ssh_private_key_file`, `ssh_public_key_str`, `root_bcrypt_hash`)
2. cd ~/Code/setup-scripts/packer
3. `packer build -var-file=<path-to-varfile> openbsd.json`
4. The ovf and vmdk files will be found in the `output_directory` specified in the openbsd.json file. Take note of the path to the ovf file that's been created, as it is necessary below.
5. Check the available VMs in VirtualBox with `VBoxManage list vms` to see whether there's an old version of this VM that should be deleted or migrated
6. Do a dry run of the import to confirm that it will be done correctly: `VBoxManage import <path-to-ovf-file> --dry-run`
7. Do the import for real (as above, without `--dry-run`)
8. Confirm the new vm is visible with `VBoxManage list vms` and make note of the VM name or the UUID for a subsequent step.
9. After import, it's necessary to specify which interface is being bridged into the VM. To find out which interfaces are available use: `VBoxManage list bridgedifs`. Make note of the Name field - you will need the whole field (it will generally be something like *en0: Wi-Fi (AirPort)*)
10. Specify which interface is being bridged: `VBoxManage modifyvm <vmname-or-uuid> --bridgeadapter1 <interfacename>` noting that you may need to single-quote the interface name if it has special characters or spaces.
11. Start the VM: `VBoxManage startvm <vmname-or-uuid>` (use `--type headless`) if you want to avoid a GUI on the host.
12. If you haven't done a DHCP mapping, find the new IP address on the DHCP server (look for recent *DHCPACK* log line in `/var/log/daemon` if it's OpenBSD)
13. Login using the private key associated with the `ssh_private_key_file` that was used in the packer setup phase

# OS Setup a cloud host from scratch

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

# Provisioning using ansible on a base OS install

Once the base operating system has been setup, we do further setup using ansible.
Assumes that your default ssh public key is installed on the server under
the account that you'll be using for provisioning (root), or that you provide
a different key to ansible with `--private-key=PRIVATE_KEY_FILE`

## General pre-work
1. `workon ansible`  (the virtualenv should already exist from previous work)
2. `cd ~/Code/setup-scripts/ansible`
2. Replace the host in `hosts` with the IP address of the newly provisioned
   host, placing it in the group section that corresponds to the `--limit`
   argument used in the `ansible-playbook` commands for the appropriate type of VM install
3. `cd ~/Code/local/startssl; ./make_bundles.sh` (if deploying a webserver)

## Performing non-OS setup

Note that it's not possible to test ansible connectivity on OpenBSD hosts
until they have a python interpreter, which is the first step in the common
playbook.

The default architecture is `openbsd-amd64` and if the installation machine is
another architecture, create a file under `host_vars` with a PKG_PATH
definition with the appropriate architecture specified e.g.
`PKG_PATH: 'http://mirror.internode.on.net/pub/OpenBSD/5.9/packages/powerpc/'`

In the `ansible` directory at the same level as this `README.md` file run:

`ansible-playbook -u root -i hosts --limit <limit-criteria> site.yml`

Where the limit criteria is something like:

* 192.168.56.101  (an IP address)
* webservers (a single group name)
* 'webservers:&192.168.56.101' (the union of a group and an IP address)

## Additional steps

15. Logon to the VM to perform the rest of the steps
16. Update `/etc/hosts` to have FQDN for host, and short and FQDN for any sites that the machine will serve
20. `cd ~/Code && git clone git@github.com:edwinsteele/dotfiles.git`
21. `cd ~/Code/dotfiles && ./make.sh`
25. `cd ~/Code/wordspeak.org && /home/esteele/.virtualenvs/wordspeak_n7/bin/fab build staging_sync` (for webserver)
