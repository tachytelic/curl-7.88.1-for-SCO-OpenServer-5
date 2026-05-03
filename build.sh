#!/bin/sh
# Build curl 7.88.1 natively on SCO OpenServer 5.0.7 with TLS support.
#
# Run this script ON the SCO machine, in a writable directory.
#
# Required:
#   GCC 3.4 or later (the SCO native 2.95.3 is C89-only and won't build
#       curl 7.88 — full C99 support is needed). Set CC and put it on
#       PATH before running this script, or override via the GCC env var.
#   /usr/gnu/bin/{gmake,gtar}, /bin/{sed,gunzip}
#   wget or curl, OR drop curl-7.88.1.tar.gz next to this script
#   Static OpenSSL 1.0.2 at /usr/local/lib/{libssl,libcrypto}.a with
#       headers at /usr/local/include/openssl/. SCO's stock OpenSSL
#       0.9.7 is too old for modern TLS. Build OpenSSL 1.0.2 first
#       (./Configure no-shared no-asm sco5-gcc; make; make install).
#
# Output: ./curl_install/ (about 450 KB stripped)

set -e

SCRIPT_DIR=`cd \`dirname "$0"\` && pwd`
VERSION=7.88.1
TARBALL=curl-${VERSION}.tar.gz
SRCDIR=curl-${VERSION}

if [ -n "$GCC" ]; then
    CC="$GCC"
fi
CC="${CC:-gcc}"
export CC

PATH=/usr/gnu/bin:/usr/ccs/bin:/usr/bin:/bin
export PATH

gcc_ver=`$CC -dumpversion 2>/dev/null`
case "$gcc_ver" in
    2.*)
        echo "ERROR: $CC is GCC $gcc_ver — too old (C89 only)." >&2
        echo "       curl 7.88 needs GCC 3.4+ for full C99 support." >&2
        exit 1 ;;
esac
echo "Using $CC (GCC $gcc_ver)"

if [ ! -f "$TARBALL" ]; then
    echo "Fetching $TARBALL..."
    if which wget >/dev/null 2>&1; then
        wget --no-check-certificate "https://curl.se/download/${TARBALL}"
    elif which curl >/dev/null 2>&1; then
        curl -kLO "https://curl.se/download/${TARBALL}"
    else
        echo "ERROR: no wget or curl. Drop $TARBALL next to this script." >&2
        exit 1
    fi
fi

if [ ! -d "$SRCDIR" ]; then
    echo "Unpacking $TARBALL..."
    gtar xzf "$TARBALL"
fi

cd "$SRCDIR"

echo "Configuring..."
# Notes on the flags:
#   --with-n64-deprecated — SCO has 32-bit off_t; curl 7.88 supports 32-bit
#                           curl_off_t with this opt-in (removed in 8.x).
#   --with-ca-bundle=...  — bake in default location for cacert.pem so users
#                           don't have to pass --cacert on every invocation.
#   --disable-threaded-resolver — SCO has no working pthreads. Synchronous
#                                  resolver (gethostbyname) works fine.
#   --without-* deps      — SCO doesn't have nghttp2/libssh/libpsl/libidn2/
#                            brotli/zstd/librtmp/zlib. Each is optional.
#   --disable-ipv6        — SCO is IPv4-only.
CFLAGS="-O2 -std=gnu99" \
CPPFLAGS="-I/usr/local/include" \
LDFLAGS="-L/usr/local/lib" \
./configure --prefix="$SCRIPT_DIR/curl_install" \
  --with-openssl=/usr/local --with-n64-deprecated \
  --with-ca-bundle=/usr/local/etc/ssl/cert.pem \
  --without-nghttp2 --without-libssh --without-libssh2 \
  --without-libpsl --without-libidn2 \
  --without-brotli --without-zstd --without-librtmp --without-libgsasl \
  --disable-ldap --disable-ldaps --disable-mqtt --disable-rtsp \
  --disable-dict --disable-telnet --disable-tftp \
  --disable-pop3 --disable-imap --disable-smb --disable-smtp --disable-gopher \
  --disable-ipv6 --without-zlib --disable-threaded-resolver

echo "Compiling..."
gmake

echo "Installing to $SCRIPT_DIR/curl_install/..."
gmake -s install

echo "Stripping..."
strip "$SCRIPT_DIR/curl_install/bin/curl" 2>/dev/null || true

ls -l "$SCRIPT_DIR/curl_install/bin/curl"
echo
echo "Built: $SCRIPT_DIR/curl_install/"
echo
echo "Don't forget to install the CA bundle:"
echo "  mkdir -p /usr/local/etc/ssl"
echo "  cp $SCRIPT_DIR/extras/cacert.pem /usr/local/etc/ssl/cert.pem"
echo
echo "Test:  $SCRIPT_DIR/curl_install/bin/curl -sI https://www.google.com/"
