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
7. Copy ssh keys and ssh config
8. Test github with `ssh -T git@github.com`.
9. cd ~/Code && git clone https://github.com/edwinsteele/wordspeak.org.git  (listed at the end of esteele.yml)
10. cd ~/Code/wordspeak && git submodule update --init   (listed at the end of esteele.yml)


