#!/bin/bash

set -e

# names of latest versions of each package
export HAPROXY_VERSION=1.6.6
export VERSION_PCRE=pcre-8.39
export VERSION_LIBRESSL=libressl-2.3.6
export VERSION_HAPROXY=haproxy-$HAPROXY_VERSION

# URLs to the source directories
export SOURCE_LIBRESSL=http://ftp.openbsd.org/pub/OpenBSD/LibreSSL/
export SOURCE_PCRE=ftp://ftp.csx.cam.ac.uk/pub/software/programming/pcre/
export SOURCE_HAPROXY=http://www.haproxy.org/download


# clean out any files from previous runs of this script
rm -rf build
mkdir build

# proc for building faster
NB_PROC=$(grep -c ^processor /proc/cpuinfo)

# ensure that we have the required software
#sudo apt-get -y install curl wget build-essential libgd-dev libgeoip-dev checkinstall git

# grab the source files
echo "Download sources"
wget -P ./build "${SOURCE_HAPROXY}/$(echo $HAPROXY_VERSION | cut -d. -f1-2)/src/$VERSION_HAPROXY.tar.gz"
wget -P ./build "${SOURCE_PCRE}${VERSION_PCRE}.tar.gz"
wget -P ./build "${SOURCE_LIBRESSL}${VERSION_LIBRESSL}.tar.gz"

# expand the source files
echo "Extract Packages"
cd build || exit 1

tar xfz "${VERSION_HAPROXY}.tar.gz"
tar xfz "${VERSION_LIBRESSL}.tar.gz"
tar xfz "${VERSION_PCRE}.tar.gz"
cd ../ || exit 1

export BPATH="${PWD}/build"
export STATICLIBSSL="${BPATH}/${VERSION_LIBRESSL}"

# build static LibreSSL
echo "Configure & Build LibreSSL"
cd "${STATICLIBSSL}" || exit 1
./configure --prefix="${STATICLIBSSL}/_openssl/" --enable-shared=no && make install-strip -j "${NB_PROC}"

# build pcre
export STATICLIPCRE="${BPATH}/${VERSION_PCRE}"
cd "${STATICLIPCRE}" || exit 1
./configure --prefix="${STATICLIPCRE}/_pcre" --enable-shared=no --enable-utf8 --enable-jit
make -j "${NB_PROC}"
make install


echo "Build HAProxy"
cd "${BPATH}/${VERSION_HAPROXY}" || exit 1

make \
-j "${NB_PROC}" \
TARGET=linux2628 \
USE_STATIC_PCRE=1 \
USE_PCRE_JIT=1 \
PCRE_LIB="${STATICLIPCRE}/_pcre/lib" \
PCRE_INC="${STATICLIPCRE}/_pcre/include" \
USE_OPENSSL=1 \
SSL_INC="${STATICLIBSSL}/_openssl/include" \
SSL_LIB="${STATICLIBSSL}/_openssl/lib" \
USE_ZLIB=1 \
DEFINE="-fstack-protector --param=ssp-buffer-size=4 -Wformat -Werror=format-security -D_FORTIFY_SOURCE=2"


echo "All done."
echo "become root and type: "
echo "  cp build/haproxy-${HAPROXY_VERSION}/haproxy /usr/local/sbin"
echo "  cp build/haproxy-${HAPROXY_VERSION}/haproxy-systemd-wrapper /usr/local/sbin"
