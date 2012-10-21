#!/bin/bash

# Setup virtual environments completely under a user's home directory with no deps
#  on system packages (besides python itself). Leads taken from:
# https://ncoghlan_devs-python-notes.readthedocs.org/en/latest/venv_bootstrap.html

if [ $(whoami) == "root" ];
then
  echo "Don't run this as root";
  exit 1;
fi

if [ $# -ne 1 ];
then
  echo "Usage: $0 [python version]"
  echo "e.g. $0 2.7"
  exit 2;
fi

# This script will fail if it is being run in a virtual env, or when a
#  virtual env setup script (like the profile script towards the bottom
#  of this script) has been sourced. The error that would appear when
#  pip install is run is:
#  Could not find an activated virtualenv (required)
#
# To avoid this, we check for one of the variables that we set during our
#  profile script, and fail if it is set.
if [ "$PIP_REQUIRE_VIRTUALENV"  == "true" ];
then
  echo "It looks like this script is being run with virtualenv variables are set"
  echo "e.g. PIP_REQUIRE_VIRTUALENV. This prevents the setup from running properly"
  echo "Please start a new shell and make sure these variables aren't set (they may"
  echo "be sourced from the bash_profile automatically, so you may need to make"
  echo "alterations in your profile to achieve this goal)."
  echo "Exiting"
  exit 3;
fi

#PYTHON_VERSION="2.7"
PYTHON_VERSION=$1
VENV_BASE=~/.virtualenvs	# this is the default anyway...

pushd $(pwd)

which python$PYTHON_VERSION > /dev/null
if [ $? -ne 0 ];
then
  echo "python interpreter (version $PYTHON_VERSION) not in path. exiting";
  exit 1;
fi


if [ $(uname) == "Darwin" ];
then
	# This structure only holds true for 2.7 and up. 2.6 uses .local
	LOCAL_SITE_BIN=~/Library/Python/$PYTHON_VERSION/bin
	LOCAL_SITE_LIB=~/Library/Python/$PYTHON_VERSION/lib/python/site-packages
elif [ $(uname) == "Linux" ];
then
	LOCAL_SITE_BIN=~/.local/bin
	LOCAL_SITE_LIB=~/.local/lib/python$PYTHON_VERSION/site-packages

else
	echo "Don't know how to run on this platform: $(uname)";
	exit 1;
fi

# TODO - Can probably just make this a temporary directory... shouldn't need to rerun
#  the setup, and we download it in this script each time anyway...
BOOTSTRAP_DIR=$LOCAL_SITE_BIN/../bootstrap

# TODO - Check if we need to create the lib and bin directories... perhaps they
#  will be automatically created
mkdir -p $LOCAL_SITE_BIN
mkdir -p $LOCAL_SITE_LIB
mkdir -p $BOOTSTRAP_DIR

cd $BOOTSTRAP_DIR
curl -O http://python-distribute.org/distribute_setup.py
curl -O http://pypi.python.org/packages/source/p/pip/pip-1.2.1.tar.gz
tar -zxf $BOOTSTRAP_DIR/pip-1.2.1.tar.gz

cd $BOOTSTRAP_DIR
python$PYTHON_VERSION distribute_setup.py --user
cd $BOOTSTRAP_DIR/pip-1.2.1
python$PYTHON_VERSION setup.py install --user

$LOCAL_SITE_BIN/pip-$PYTHON_VERSION install --user virtualenv
$LOCAL_SITE_BIN/pip-$PYTHON_VERSION install --user virtualenvwrapper

mkdir -p $VENV_BASE
VENV_PROFILE_SCRIPT=$VENV_BASE/venv_profile_additions_$PYTHON_VERSION.sh
cat > $VENV_PROFILE_SCRIPT << EOF
VENV_DIR=$VENV_BASE

export VIRTUALENVWRAPPER_PYTHON=$(which python$PYTHON_VERSION)
export VIRTUALENVWRAPPER_VIRTUALENV=$LOCAL_SITE_BIN/virtualenv-$PYTHON_VERSION
export VIRTUALENVWRAPPER_VIRTUALENV_ARGS='--no-site-packages --distribute'
export WORKON_HOME=\$VENV_DIR

# Locate virtualenvwrapper binary
if [ -f $LOCAL_SITE_BIN/virtualenvwrapper.sh ]; then
    export VENVWRAP=$LOCAL_SITE_BIN/virtualenvwrapper.sh
fi

if [ ! -z \$VENVWRAP ]; then
    [ -d \$VENV_DIR ] || mkdir -p \$VENV_DIR
    export WORKON_HOME=$VENV_DIR
    source \$VENVWRAP
    export VIRTUALENV_USE_DISTRIBUTE=true
    # pip ---------------------------------------------------------
    export PIP_VIRTUALENV_BASE=\$WORKON_HOME
    export PIP_REQUIRE_VIRTUALENV=true
    export PIP_RESPECT_VIRTUALENV=true
    export PIP_DOWNLOAD_CACHE=$HOME/.pip/cache
fi
EOF

echo "##############################"
echo "Add the following lines to ~/.bash_profile:"
echo "source $VENV_PROFILE_SCRIPT"

# Finish where we started
popd
