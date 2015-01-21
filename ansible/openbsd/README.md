# Manual preceeding steps
* do install from CD,
* selecting correct timezone
* setup root .ssh/authorized_keys

# Provisioning a local VM

* workon ansible
* cd ~/Code/setup-scripts/ansible
* ansible-playbook -u root -i hosts --limit local-openbsd openbsd/bootstrap.yml
* ansible-playbook -u root -i hosts --limit local-openbsd openbsd/initial.yml
* ansible-playbook -u root -i hosts --limit local-openbsd openbsd/base_nginx.yml
* ansible-playbook -u root -i hosts --limit local-openbsd wordspeak/python27-setup.yml
