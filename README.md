# Files in this area

* ansible: Provisioning of wordspeak webserver and home firewall
* vagrant: Vagrantfiles for each type of machine

# OS Setup a Vultr cloud host from scratch

OpenBSD requires hand-installation on Vultr, even though they offer pre-build
images because their partitioning scheme only has a single partition.

* boot from ISO that has installation packages e.g. `install70.iso`
* do an auto-install, using an auto-install conf. Note that noVNC (used by
  Vultr) has a paste option in the client's pop-out, so you don't need to
  type in the autoinstall URL - ` https://raw.githubusercontent.com/edwinsteele/setup-scripts/master/autoinstall/gemini-install.conf`
* detach the ISO (which triggers a reboot on Vultr - manual reboot may be necessary)

# Provisioning using ansible once the OS setup is complete

Once the base OS has been setup, we do further setup using ansible.
Assumes that your default ssh public key is installed on the server under
the account that you'll be using for provisioning (root), or that you provide
a different key to ansible with `--private-key=PRIVATE_KEY_FILE`

## General pre-work
1. `brew install ansible` (if not already installed)
1. `cd ~/Code/setup-scripts/ansible`
1. Replace the host in `hosts` with the IP address of the newly provisioned
   host, placing it in the group section that corresponds to the `--limit`
   argument used in the `ansible-playbook` commands for the appropriate type of VM install
   e.g. `ansible-playbook -u root -i inventory site.yml --limit=192.168.20.254`

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

1. On the newly provisioned VM as root (in an ssh session with agent forwarding enabled):
  1. `openrsync -av www.wordspeak.org:/etc/ssl/wordspeak.org/ /etc/ssl/wordspeak.org/`
  1. `openrsync -av www.wordspeak.org:/etc/ssl/private/wordspeak.org/ /etc/ssl/private/wordspeak.org/`
  1. `rcctl restart nginx`
1. On the newly provisioned VM as esteele (in an ssh session with agent forwarding enabled):
  1. `for d in images.wordspeak.org language-explorer.wordspeak.org staging.wordspeak.org www.wordspeak.org; do openrsync -av www.wordspeak.org:/home/esteele/Sites/$d/ /home/esteele/Sites/$d/; done`
  1. `cd ~/Code/dotfiles && ./make.sh`
`flip the DNS to point to the new host`
  1. ``doas acme-client -v wordspeak.org && rcctl restart nginx``

### For Webserver

1. Update DNS record for staging.wordspeak.org (to simplify final setup, knowing that nobody is looking at staging)
1. `rsync -av --rsync-path=/usr/bin/openrsync /usr/local/var/www/lex-mirror/ staging.wordspeak.org:/var/www/htdocs/language-explorer.wordspeak.org/`
1. in images.wordspeak.org checkout, run `./images_tool.py sync`
1. RUn github actions
