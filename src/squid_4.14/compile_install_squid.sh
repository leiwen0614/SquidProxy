# Tested on Azure Ubuntu 20.04 VM only
# The key to get Squid transparent proxy working option is enable-linux-netfilter and enable-http-violations options at compile time

# set squid version
SQUID_VER="4.14"
SQUID_PKG="${SQUID_VER}-8"

# some packages are in universe, so enable it
add-apt-repository universe

# Stage 0
REPO_ROOT=$(cd `dirname $0` && pwd)
SOURCE_LIST=$REPO_ROOT/sources.list
SSL_SITES=$REPO_ROOT/ssl_sites.txt
SQUID_DIR=$REPO_ROOT/squid
SQUID_SRC=$SQUID_DIR/squid-$SQUID_VER


echo "SOURCE_LIST=$SOURCE_LIST"
echo "SSL_SITES=$SSL_SITES"
echo "SQUID_DIR=$SQUID_DIR"
echo "SQUID_SRC=$SQUID_SRC"

echo "Creating '$SQUID_DIR'..."
mkdir "$SQUID_DIR"


# Stage 1
# Get the squid dependency packages and build tools

echo "-----------------------------------------------------"
echo "Displaying Contents of sources.list Before update"
echo "-----------------------------------------------------"
cat /etc/apt/sources.list


echo "-----------------------------------------------------"
echo "Updating sources.list with checked in version"
echo "-----------------------------------------------------"
mv /etc/apt/sources.list /etc/apt/sources.list.bak.$BUILD_BUILDID
cp $SOURCE_LIST /etc/apt/sources.list

echo "-----------------------------------------------------"
echo "Displaying Contents of sources.list after update"
echo "-----------------------------------------------------"
cat /etc/apt/sources.list

# install build tools
apt-get -y install devscripts build-essential fakeroot debhelper dh-autoreconf dh-apparmor cdbs || { echo "Failed to install build tools" && exit 1; }

# install additional header packages for squid 4
apt-get -y install \
    libcppunit-dev \
    libsasl2-dev \
    libxml2-dev \
    libkrb5-dev \
    libdb-dev \
    libnetfilter-conntrack-dev \
    libexpat1-dev \
    libcap2-dev \
    libldap2-dev \
    libpam0g-dev \
    libgnutls28-dev \
    libssl-dev \
    libdbi-perl \
    libecap3 \
    libecap3-dev \
    libsystemd-dev || { echo "Failed to install additional header packages" && exit 1; }



apt-get update -y || { echo "Failed to update" && exit 1; }
apt-get install -y openssl build-essential libssl-dev || { echo "Failed to install packages" && exit 1; }
apt-get -y build-dep squid || { echo "Failed to install Squid build dependencies" && exit 1; }

# Stage 2
# Get the squid source code
wget http://www.squid-cache.org/Versions/v4/squid-4.14.tar.gz || { echo "Failed to download Squid source" && exit 1; }
tar zxvf squid-4.14.tar.gz || { echo "Failed to unpack Squid source" && exit 1; }


ls -a

# Stage 3
# Build Squid
# TODO fix this hardcoded value
pushd "squid-4.14"
./configure  \
             --prefix=/usr\
             --includedir=${prefix}/include\
             --mandir=${prefix}/share/man\
             --infodir=${prefix}/share/info\
             --sysconfdir=/etc\
             --localstatedir=/var\
             --libexecdir=${prefix}/lib/squid\
             --srcdir=.\
             --without-libcap\
             --sysconfdir=/etc/squid\
             --mandir=/usr/share/man\
             --enable-inline\
             --with-openssl\
             --enable-ssl-crtd\
             --with-default-user=proxy\
             --with-swapdir=/var/spool/squid\
             --with-logdir=/var/log/squid\
             --with-pidfile=/var/run/squid.pid\
             --disable-arch-native\
             --enable-linux-netfilter\
             --enable-http-violations || { echo "Failed to configure from auto-apt" && exit 1; }

make

# Stage 3
make install

# Stage 4
# Configure ssl folder
/usr/lib/squid/security_file_certgen -c -s /var/spool/squid/ssl_db -M 4MB

# Stage 5
# Configure write permission for default user 'proxy' in logging folder
chown -R proxy:proxy /var/log/squid/ || { echo "Failed to change permissions" && exit 1; }

# Stage 6
# Congiure ssl_sites, this config is kind of a dummy config, but it is must, since in squid.conf, ssl_bump peek step2 is a must and it replies some ssl sites.
cp $SSL_SITES /etc/squid/ssl_sites

# Stage 6
echo "Run squid to test compilation"
squid
sleep 1
squid -v
echo -e "\n"

echo "Last call"
popd
exit 0
