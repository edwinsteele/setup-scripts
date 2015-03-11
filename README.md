# Files in this area

* python-setup.sh: setup python venvs from scratch
* vm-setup.sh: build and install python 2.7 or 3.3 from scratch
* ansible
 * wordspeak
  * yaml files for setup of a CentOS6 or OpenBSD 5.6 VM for my hosting
* gemini: not sure... possibly initial config files from original gemini install?
* vagrant: provisioning of gemini-type VM using vagrant. Only setup locally as I didn't want to spend time learning EC2 provisioning inside vagrant. Eventually switched to using ansible directly, rather than through vagrant

# Provisioning a VM on an existing Install

This is the case where a base OS install already exists, either because a cloud provider image has been used, or a virtualbox OS install has already been setup
Assumes that your default ssh public key is installed on the server under the account that you'll be using for provisioning (root)

## Common preceeding steps
1. `workon ansible`  (the virtualenv should already exist from previous work)
2. `cd ~/Code/setup-scripts/ansible`
2. Replace the host in `hosts` with the IP address of the newly provisioned host, placing it in the group section that corresponds to the `--limit` argument used in the `ansible-playbook` commands for the appropriate type of VM install
3. cd ~/Code/local/startssl; ./make_bundles.sh


## Provisioning a Linux VM

4. test ansible connectivity: `ansible -u root -i hosts local-linux -m ping`. This will give a pong response. 
5. `ansible-playbook -u root -i hosts --limit local-linux ansible/wordspeak/initial.yml`
5. `ansible-playbook -u root -i hosts --limit local-linux ansible/wordspeak/base_nginx.yml`
11. `ansible-playbook -u root -i hosts --limit local-linux ansible/wordspeak/python27-setup.yml`
12. `ansible-playbook -u root -i hosts --limit local-linux ansible/wordspeak/esteele.yml`
13. `ansible-playbook -u root -i hosts --limit local-linux ansible/wordspeak/wordspeak-deploy.yml`
14. `ansible-playbook -u root -i vagrant/mercury-vm/ansible_hosts ansible/wordspeak/language_explorer.yml`


# Provisioning an OpenBSD VM

## OpenBSD-specific preceeding steps
* do install from CD,
* selecting correct timezone
* setup root .ssh/authorized_keys

## Provisioning a local VM

Note that it's not possible to test ansible connectivity on OpenBSD hosts until they have a python interpreter, which is first setup in the bootstrap.yml playbook below

Replace `local-openbsd-amd64` with `local-openbsd-macppc` if this is an openbsd macppc machine

* `ansible-playbook -u root -i hosts --limit local-openbsd-amd64 openbsd/bootstrap.yml`
* `ansible-playbook -u root -i hosts --limit local-openbsd-amd64 wordspeak/initial.yml`
* `ansible-playbook -u root -i hosts --limit local-openbsd-amd64 wordspeak/base_nginx.yml`
* `ansible-playbook -u root -i hosts --limit local-openbsd-amd64 wordspeak/python27-setup.yml`
* `ansible-playbook -u root -i hosts --limit local-openbsd-amd64 wordspeak/esteele.yml`
* `ansible-playbook -u root -i hosts --limit local-openbsd-amd64 wordspeak/wordspeak-deploy.yml`


## Todo
* start script for nginx

## Provisioning common steps

15. Logon to the VM to perform the rest of the steps
16. Update `/etc/hosts` to have FQDN for host, not just machine name
18. Test github with `ssh -T git@github.com`.
19. `cd ~/Code && git clone git@github.com:edwinsteele/wordspeak.org.git` (listed at the end of esteele.yml)
19. `cd ~/Code/wordspeak.org && git submodule update --init`  (listed at the end of esteele.yml)
20. `cd ~/Code && git clone git@github.com:edwinsteele/dotfiles.git`
21. `cd ~/Code/dotfiles && ./make.sh`
23. `. ~/.virtualenvs/wordspeak_n7/bin/activate`
24. `pip install -r ~/Code/wordspeak.org/requirements.txt`

# Provisioning a Linux VM on a local machine with Vagrant/VirtualBox
Assumes virtualbox, vagrant 1.7

1. `workon ansible` (venv should already exist)
2. confirm that the IP address in setup-scripts/vagrant/mercury-vm/Vagrantfile is the same as setup-scripts/vagrant/mercury-vm/vagrant-ansible_hosts
3. In directory setup-scripts/vagrant/mercury-vm, run "vagrant up" to boot an existing VM, or "vagrant destroy" and "vagrant up" to reprovision.
4. Possibly do most of the post ansible steps above

For ad-hoc running of ansible playbooks, after the esteele account has been created, run e.g.: `ansible-playbook -u esteele -i ../../vagrant/mercury-vm/vagrant-ansible_hosts ./language_explorer.yml` (and change the user line to esteele instead of root in the playbook). 
TODO - see if we can remove the user line entirely and specify all the time on commandline

# Extra notes
ansible -i hosts local-linux -m setup to get variables

