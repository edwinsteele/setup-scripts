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
3. cd ~/Code/local/startssl; ./make_bundles.sh
4. test connectivity: `ansible -u root all -i vagrant/mercury-vm/ansible_hosts -m ping`. This will give a pong response. 
5. Initial system setup: `ansible-playbook -u root -i vagrant/mercury-vm/ansible_hosts ansible/wordspeak/initial.yml`
11. Setup python2.7: `ansible-playbook -u root -i vagrant/mercury-vm/ansible_hosts ansible/wordspeak/python27-setup.yml`
12. Setup my user account: `ansible-playbook -u root -i vagrant/mercury-vm/ansible_hosts ansible/wordspeak/esteele.yml`
13. Setup all the system modules required for wordspeak deployment: `ansible-playbook -u root -i vagrant/mercury-vm/ansible_hosts ansible/wordspeak/wordspeak-deploy.yml`
14. Setup the language_explorer site: `ansible-playbook -u root -i vagrant/mercury-vm/ansible_hosts ansible/wordspeak/language_explorer.yml`
15. Logon to the VM to perform the rest of the steps
16. Update /etc/hosts to have FQDN for host, not just machine name
17. Copy esteele ssh keys and ssh config
18. Test github with `ssh -T git@github.com`.
19. cd ~/Code && git clone git@github.com:edwinsteele/wordspeak.org.git (listed at the end of esteele.yml)
20. cd ~/Code && git clone git@github.com:edwinsteele/dotfiles.git
21. cd ~/Code/dotfiles && ./make.sh
22. source ~/.virtualenvs/wordspeak/bin/activate
23. pip install git+https://github.com/edwinsteele/nikola.git@ongoing_5.5_compat#egg=nikola_5.5_compat
24. pip install -r ~/Code/wordspeak.org/requirements.txt

# Provisioning a VM on a local machine with Vagrant/VirtualBox
Assumes virtualbox, vagrant 1.7

1. workon ansible (venv should already exist)
2. confirm that the IP address in setup-scripts/vagrant/mercury-vm/Vagrantfile is the same as setup-scripts/vagrant/mercury/vagrant-ansible_hosts
3. In directory setup-scripts/vagrant/mercury, run "vagrant up" to boot an existing VM, or "vagrant destroy" and "vagrant up" to reprovision.
4. Possibly do most of the post ansible steps above

For ad-hoc running of ansible playbooks, after the esteele account has been created, run e.g.: ansible-playbook -u esteele -i ../../vagrant/mercury-vm/vagrant-ansible_hosts ./language_explorer.yml
