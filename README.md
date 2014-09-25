# Files in this area

* python-setup.sh: setup python venvs from scratch
* vm-setup.sh: build and install python 2.7 or 3.3 from scratch
* ansible
 * wordspeak
  * yaml files for setup of a CentOS6 VM for my hosting (doesn't include provisioning)
* gemini: not sure... possibly initial config files from original gemini install?
* vagrant: provisioning of gemini-type VM using vagrant. Only setup locally as I didn't want to spend time learning EC2 provisioning inside vagrant. Eventually switched to using ansible directly, rather than through vagrant

# Provisioning a VM on Rackspace or EC2 (or elsewhere?)
Assumes that your default ssh public key is installed on the server under the account that you'll be using for provisioning (root)

1. workon ansible  (venv should already exist)
2. replace the host in vagrant/mercury-vm/ansible_hosts with the newly provisioned host
3. test connectivity: `ansible -u root all -i vagrant/mercury-vm/ansible_hosts -m ping`. This will give a pong response. 
4. Initial system setup: `ansible-playbook -u root -i vagrant/mercury-vm/ansible_hosts ansible/wordspeak/initial.yml`
5. Setup python2.7 and all the system modules required for wordspeak deployment: `ansible-playbook -u root -i vagrant/mercury-vm/ansible_hosts ansible/wordspeak/wordspeak-deploy.yml`
6. Setup the wordspeak site, with Nikola for building: `ansible-playbook -u root -i vagrant/mercury-vm/ansible_hosts ansible/wordspeak/esteele.yml`
6. Setup the language_explorer site: `ansible-playbook -u root -i vagrant/mercury-vm/ansible_hosts ansible/wordspeak/language_explorer.yml`
7. Logon to the VM to perform the rest of the steps
7. Update /etc/hosts to have FQDN for host, not just machine name
7. Copy ssh keys and ssh config
8. Copy wordspeak.org-certchain.crt to /etc/ssl/certs/wordspeak.org-certchain.ssl.crt  (root 644)
9. Copy my-private-decrypted.key to /etc/ssl/certs/wordspeak.org.ssl.key (root 400)
8. Test github with `ssh -T git@github.com`.
9. cd ~/Code && git clone git@github.com:edwinsteele/wordspeak.org.git (listed at the end of esteele.yml)
11. cd ~/Code && git clone git@github.com:edwinsteele/dotfiles.git
12. cd ~/Code/dotfiles && ./make.sh
13. source ~/.virtualenvs/wordspeak/bin/activate
14. pip install git+https://github.com/edwinsteele/nikola.git@ongoing_5.5_compat#egg=nikola_5.5_compat
15. pip install -r ~/Code/wordspeak.org/requirements.txt

# Provisioning a VM on a local machine with Vagrant/VirtualBox
Assumes virtualbox, vagrant 1.7

1. workon ansible (venv should already exist)
2. confirm that the IP address in setup-scripts/vagrant/mercury-vm/Vagrantfile is the same as setup-scripts/vagrant/mercury/vagrant-ansible_hosts
3. In directory setup-scripts/vagrant/mercury, run "vagrant up" to boot an existing VM, or "vagrant destroy" and "vagrant up" to reprovision.
4. Possibly do most of the post ansible steps above

For ad-hoc running of ansible playbooks, after the esteele account has been created, run e.g.: ansible-playbook -u esteele -i ../../vagrant/mercury-vm/vagrant-ansible_hosts ./language_explorer.yml
