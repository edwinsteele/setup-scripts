if [ $(whoami) == "root" ];
then
  echo "Don't run this as root";
  exit 1;
fi

PYTHON_VERSION="2.7"

STARTING_DIR=$(pwd)

if [ $(uname) == "Darwin" ];
then
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

BOOTSTRAP_DIR=$LOCAL_SITE_BIN/../bootstrap

which python$PYTHON_VERSION > /dev/null
if [ $? -ne 0 ];
then
  echo "python interpreter (version $PYTHON_VERSION) not in path. exiting";
  exit 1;
fi

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

PYTHON_PROFILE_SCRIPT=~/.python_profile_additions_$PYTHON_VERSION.sh

cat > $PYTHON_PROFILE_SCRIPT << EOF
export PATH=$LOCAL_SITE_BIN:\$PATH
alias pip$PYTHON_VERSION="$LOCAL_SITE_BIN/pip-$PYTHON_VERSION"
alias install$PYTHON_VERSION="pip$PYTHON_VERSION install --user"

EOF

VENV_PROFILE_SCRIPT=~/.virtualenvs/venv_profile_additions_$PYTHON_VERSION.sh
cat > $VENV_PROFILE_SCRIPT << EOF
VENV_DIR=$HOME/.virtualenvs

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
#echo "Add $LOCAL_SITE_BIN to the start of PATH and export it (it needs to come before /opt/python2.7/bin)"
echo "source $PYTHON_PROFILE_SCRIPT"
echo "source $VENV_PROFILE_SCRIPT"

# Finish where we started
cd $STARTING_DIR
