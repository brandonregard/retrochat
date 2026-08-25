#!/bin/sh
set -eu

version=${TCLTK_VERSION:-9.0.4}
output=${1:-packaging/macos/runtime/tcltk9-macos-universal.tgz}
root=$(cd "$(dirname "$0")/../.." && pwd)
case "$output" in /*) ;; *) output="$root/$output" ;; esac
work=$(mktemp -d "${TMPDIR:-/tmp}/retrochat-tcltk.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
tcl_url="https://downloads.sourceforge.net/project/tcl/Tcl/$version/tcl$version-src.tar.gz"
tk_url="https://downloads.sourceforge.net/project/tcl/Tcl/$version/tk$version-src.tar.gz"
curl -L --fail --retry 3 -o "$work/tcl.tgz" "$tcl_url"
curl -L --fail --retry 3 -o "$work/tk.tgz" "$tk_url"
echo "d0aed49230bc02a65c1e0229e65f34590a4b037ec40d546f32573b467f7551ea  $work/tcl.tgz" | shasum -a 256 -c -
echo "d7a146d2917eb8b5cc95276dbf0e3d03c7464d2b19c1675357857c989301dbb4  $work/tk.tgz" | shasum -a 256 -c -
tar -xzf "$work/tcl.tgz" -C "$work"
tar -xzf "$work/tk.tgz" -C "$work"
prefix="$work/runtime"
flags="-arch x86_64 -mmacosx-version-min=10.13"
(cd "$work/tcl$version/unix" && CFLAGS="$flags" LDFLAGS="$flags" ./configure --prefix="$prefix" --enable-64bit && make -j"$(sysctl -n hw.ncpu)" && make install)
(cd "$work/tk$version/unix" && CFLAGS="$flags" LDFLAGS="$flags" ./configure --prefix="$prefix" --with-tcl="$prefix/lib" --enable-64bit --enable-aqua=yes && make -j"$(sysctl -n hw.ncpu)" && make install)
file "$prefix/bin/wish9.0" "$prefix/lib/libtcl9.0.dylib" "$prefix/lib/libtcl9tk9.0.dylib"
if [ -d "$prefix/share/tcl9.0" ] && [ ! -d "$prefix/lib/tcl9.0" ]; then
    cp -R "$prefix/share/tcl9.0" "$prefix/lib/tcl9.0"
fi
mkdir -p "$(dirname "$output")"
COPYFILE_DISABLE=1 tar --no-xattrs -C "$prefix" -czf "$output" bin include lib
echo "$output"
