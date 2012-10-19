yum install ssh-client wget

curl https://raw.github.com/bngsudheer/bangadmin/master/linux/centos/6/x86_64/build-python-27.sh > /tmp/build-python-27.sh
sh /tmp/build-python-27.sh

# Python altinstall stuff taken from https://github.com/bngsudheer/bangadmin/blob/master/linux/centos/6/x86_64/build-python-27.sh

# Base packages
yum groupinstall "development tools" -y
yum install readline-devel openssl-devel gmp-devel ncurses-devel gdbm-devel zlib-devel expat-devel libGL-devel tk tix gcc-c++ libX11-devel glibc-devel bzip2 tar tcl-devel tk-devel pkgconfig tix-devel bzip2-devel sqlite-devel autoconf db4-devel libffi-devel valgrind-devel -y

mkdir tmp
# Build 2.7.2
cd tmp
wget http://python.org/ftp/python/2.7.2/Python-2.7.2.tar.bz2
tar xfj Python-2.7.2.tgz
cd Python-2.7.2
./configure --prefix=/opt/python2.7 --enable-shared
make
make altinstall
echo "/opt/python2.7/lib" >> /etc/ld.so.conf.d/opt-python2.7.conf

# Build 3.3.0
cd tmp
wget http://www.python.org/ftp/python/3.3.0/Python-3.3.0.tar.bz2
tar xfj Python-3.3.0.tar.bz2
cd Python-3.3.0
./configure --prefix=/opt/python3.3 --enabled-shared
make
make altinstall
echo "/opt/python3.3/lib" >> /etc/ld.so.conf.d/opt-python3.3.conf


ldconfig
cd ..
cd ..
rm -rf tmp

# End python build


# maybe? or do we not want to depend on system installed py?
#yum install python-devel
