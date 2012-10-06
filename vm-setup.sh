yum install ssh-client wget

curl https://raw.github.com/bngsudheer/bangadmin/master/linux/centos/6/x86_64/build-python-27.sh > /tmp/build-python-27.sh
sh /tmp/build-python-27.sh
echo << EOF >> /etc/profile.d/python2.7.sh
test -d ~/.local || mkdir ~/.local/lib/python2.7/site-packages;
export PATH=~/.local/bin:/opt/python2.7/bin:\$PATH
alias python=python2.7
EOF
