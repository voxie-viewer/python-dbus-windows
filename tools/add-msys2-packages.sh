#!/bin/sh

set -e

# List based on msys2-x86_64-20161025.exe, unused stuff removed
# Star indicates arch-any packages
# Replace m4-1.4.17-4 by m4-1.4.17-1 because sources for m4-1.4.17-4 are missing on the server
PKGS="
bash-4.3.046-1
bzip2-1.0.6-2
coreutils-8.25-1
file-5.28-2
filesystem-2016.07-2
gawk-4.1.4-1
gcc-libs-5.3.0-3
gmp-6.1.0-2
grep-2.26-1
gzip-1.8-1
heimdal-libs-1.5.3-9
icu-56.1-1
inetutils-1.9.2-1
libarchive-3.2.1-1
libbz2-1.0.6-2
libcrypt-1.3-1
libcurl-7.50.3-1
libdb-5.3.28-2
libedit-3.1-20150325
libexpat-2.2.0-1
libffi-3.2.1-1
libgettextpo-0.19.7-3
libiconv-1.14-2
libidn-1.33-1
libintl-0.19.7-3
liblzma-5.2.2-1
liblzo2-2.09-1
libnettle-3.3-1
libopenssl-1.0.2.j-1
libp11-kit-0.23.2-1
libpcre-8.38-1
libpcre16-8.38-1
libpcre32-8.38-1
libpcrecpp-8.38-1
libpcreposix-8.38-1
libreadline-6.3.008-7
libsqlite-3.10.0.0-1
libssh2-1.7.0-1
libutil-linux-2.26.2-1
libxml2-2.9.2-2
lndir-1.0.3-1
m4-1.4.17-1
mpfr-3.1.4-1
msys2-launcher-git-0.3.32.56c2ba7-2
msys2-runtime-2.6.0-1
ncurses-6.0.20161001-1
pcre-8.38-1
sed-4.2.2-2
time-1.7-1
ttyrec-1.0.8-1
tzcode-2015.e-1
util-linux-2.26.2-1
which-2.21-2
xz-5.2.2-1
zlib-1.2.8-3

tar-1.29-1
zip-3.0-1
p7zip-9.38.1-1

make-4.2.1-1
cmake-3.6.2-1
pkg-config-0.29.1-1

*mingw-w64-x86_64-binutils-2.27-2
*mingw-w64-x86_64-gcc-6.2.0-2
*mingw-w64-x86_64-headers-git-5.0.0.4747.0f8f626-1
*mingw-w64-x86_64-crt-git-5.0.0.4745.d2384c2-1
*mingw-w64-x86_64-windows-default-manifest-6.4-2
*mingw-w64-x86_64-libwinpthread-git-5.0.0.4741.2c8939a-1
*mingw-w64-x86_64-gcc-libs-6.2.0-2
*mingw-w64-x86_64-winpthreads-git-5.0.0.4741.2c8939a-1
*mingw-w64-x86_64-libiconv-1.14-5
*mingw-w64-x86_64-zlib-1.2.8-10
*mingw-w64-x86_64-isl-0.17.1-1
*mingw-w64-x86_64-libiconv-1.14-5
*mingw-w64-x86_64-mpc-1.0.3-2
*mingw-w64-x86_64-gmp-6.1.1-1
*mingw-w64-x86_64-gcc-libgfortran-6.2.0-2
*mingw-w64-x86_64-bzip2-1.0.6-5
*mingw-w64-x86_64-mpfr-3.1.4.p3-4

*mingw-w64-x86_64-expat-2.2.0-1

*mingw-w64-x86_64-python3-3.5.3-2
"

POS="${0%/*}"; test "$POS" = "$0" && POS=.
POS="$(readlink -f -- "$POS")"

cd "$POS/../files"

LIST=""

alldeps=""
allpkgs="  "

for PKG in $PKGS; do
    echo $PKG
    ARCH=x86_64
    if [ "$PKG" != "${PKG#\*}" ]; then
        PKG="${PKG#\*}"
        ARCH=any
    fi
    FN="msys2/$PKG-$ARCH.pkg.tar.xz"
    LIST="$LIST$PKG-$ARCH
"
    URLBASE="https://sourceforge.net/projects/msys2/files/REPOS/MSYS2"
    if [ "$PKG" != "${PKG#mingw-w64-x86_64}" ]; then
        URLBASE="https://sourceforge.net/projects/msys2/files/REPOS/MINGW"
    fi
    URL="$URLBASE/x86_64/$PKG-$ARCH.pkg.tar.xz"
    if [ ! -f "$FN.url" -o ! -f "$FN.sha512sum" ]; then
        echo "$URL" > "$FN.url.new"
        rm -f -- "$FN.new"
        echo "Downloading $URL"
        curl --fail --progress-bar --location -o "$FN.new" "$URL"
        mv "$FN.new" "$FN"
        sha512sum "$FN" > "$FN.sha512sum.new"
        mv "$FN.url.new" "$FN.url"
        mv "$FN.sha512sum.new" "$FN.sha512sum"
    fi
    rm -rf tmp
    mkdir tmp
    tar x -C tmp -f "$FN" .PKGINFO
    pkgname="$(grep '^pkgname = ' tmp/.PKGINFO | sed 's/.* = //')"
    pkgbase="$(grep '^pkgbase = ' tmp/.PKGINFO | sed 's/.* = //')"
    pkgver="$(grep '^pkgver = ' tmp/.PKGINFO | sed 's/.* = //')"
    deps="$(grep '^depend = ' tmp/.PKGINFO | sed 's/.* = //')"
    provides="$(grep '^provides = ' tmp/.PKGINFO | sed 's/.* = //')"
    if [ "$pkgbase" = "" ]; then
        pkgbase="$pkgname"
    fi
    if [ "$pkgbase" = "" ]; then
        echo "pkgbase = '' and pkgname = '' for '$PKG'"
        false
    fi
    if [ "$pkgver" = "" ]; then
        echo "pkgver = '' for '$PKG'"
        false
    fi
    allpkgs="$allpkgs $pkgname "
    for prov in $provides; do
        allpkgs="$allpkgs $prov "
    done
    alldeps="$alldeps $deps"
    SPKG="$pkgbase-$pkgver"
    rm -rf tmp
    SRC_FN="msys2/$SPKG.src.tar.gz"
    SRC_URL="$URLBASE/Sources/$SPKG.src.tar.gz"
    if [ ! -f "$SRC_FN.url" -o ! -f "$SRC_FN.sha512sum" ]; then
        echo "$SRC_URL" > "$SRC_FN.url.new"
        rm -f -- "$SRC_FN.new"
        echo "Downloading $SRC_URL"
        curl --fail --progress-bar --location -o "$SRC_FN.new" "$SRC_URL"
        mv "$SRC_FN.new" "$SRC_FN"
        sha512sum "$SRC_FN" > "$SRC_FN.sha512sum.new"
        mv "$SRC_FN.url.new" "$SRC_FN.url"
        mv "$SRC_FN.sha512sum.new" "$SRC_FN.sha512sum"
    fi
done

# for dep in $alldeps; do
#     #echo $dep
#     dep2="$dep"
#     dep2="${dep2%>=*}"
#     dep2="${dep2%<=*}"
#     dep2="${dep2%=*}"
#     if [ "$allpkgs" = "${allpkgs% $dep2 *}" ]; then
#         echo $dep
#     fi
# done

echo -n "$LIST" | LC_COLLATE=C sort > ../tools/msys2-pkglist.txt
