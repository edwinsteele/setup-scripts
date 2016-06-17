#!/bin/sh

# Corresponds to the ssh_private_key_file directive in the packer template
ROOT_PUBLIC_KEY="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDZOQQUwe79XugZrvnJNIgEglmzVa0h+/TgEaI534WA83j0Q56HcE97Ma47EZ3tZMJYDr5w81iXFga5P0ciED8ieaBEaMKES028rT10uLuZkoLx+jOTgOdHfuEzudcTrM4XTF+7oJJg/Y4mA6ltajgutoMKHDc4LHb8iafIVgnxZlaZTMQa/pJ3olVA/r6eK/EsGiqxRPjWGulG9pfr/0oxWZiwaf1IwW9HmtqHAzC8nyulBhvzF+iRrhBvuOkpinLS51QaUPddRC1msiP9TVDM66wbQL4Iz8tYx8mopDHCR7a3JqlsfK4KqM3nvxL+11j087nGHVwmFRhZ7Zun7LfV esteele@mercury.local"
mkdir /root/.ssh
chmod 700 /root/.ssh
echo $ROOT_PUBLIC_KEY > /root/.ssh/authorized_keys
chmod 600 /root/.ssh/authorized_keys
