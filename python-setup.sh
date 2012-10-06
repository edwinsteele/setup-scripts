if [ $(whoami) == "root" ];
then
  echo "Don't run this as root";
  exit 1;
fi

PYTHON_VERSION="2.7"

which python$PYTHON_VERSION
if [ $? -ne 0 ];
then
  echo "python interpreter (version $PYTHON_VERSION) not in path. exiting";
  exit 1;
fi

echo "Make sure ~/.local/bin is at the front of your PATH"
echo "Make sure ~/.local is on PYTHONPATH"

mkdir -p ~/.local/lib/python$PYTHON_VERSION/site-packages
cat > ~/.pydistutils.cfg << EOF
[install]
prefix=~/.local
EOF

# Pinched from http://stackoverflow.com/questions/4324558/whats-the-proper-way-to-install-pip-virtualenv-and-distribute-for-python
curl --output ~/distribute_setup.py http://python-distribute.org/distribute_setup.py
python$PYTHON_VERSION /tmp/distribute_setup.py
rm ~/distribute_setup.py
# use easy install because we don't have pip yet, then revert to pip
easy_install pip
pip install virtualenv
pip install virtualenvwrapper
mkdir ~/.virtualenvs

cat > ~/.virtualenvs/venv_profile_additions.sh << EOF
VENV_DIR=$HOME/.virtualEnvs

# Locate virtualenvwrapper binary
if [ -f ~/.local/bin/virtualenvwrapper.sh ]; then
    export VENVWRAP=~/.local/bin/virtualenvwrapper.sh
fi

if [ ! -z $VENVWRAP ]; then
    # virtualenvwrapper -------------------------------------------
    # make sure env directory exists; else create it
    [ -d $VENV_DIR ] || mkdir -p $VENV_DIR
    export WORKON_HOME=$VENV_DIR
    source $VENVWRAP

    # virtualenv --------------------------------------------------
    export VIRTUALENV_USE_DISTRIBUTE=true

    # pip ---------------------------------------------------------
    export PIP_VIRTUALENV_BASE=$WORKON_HOME
    export PIP_REQUIRE_VIRTUALENV=true
    export PIP_RESPECT_VIRTUALENV=true
    export PIP_DOWNLOAD_CACHE=$HOME/.pip/cache
fi
EOF

echo "Make the following changes to ~/.bash_profile"
echo "Add ~/.local/bin to the start of PATH and export it (it needs to come before /opt/python2.7/bin)"
echo "Add: source ~/.virtualEnvs/venv_profile_additions.sh"
#test -d ~/.local || mkdir ~/.local/lib/python2.7/site-packages;
#export PATH=~/.local/bin:/opt/python2.7/bin:/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin:/root/bin
#alias python=python2.7
