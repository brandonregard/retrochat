#!/bin/sh
set -eu

arch=${1:?usage: build.sh 68k|ppc}
case "$arch" in
    68k|ppc) ;;
    *) echo "architecture must be 68k or ppc" >&2; exit 2 ;;
esac

version=${VERSION:-0.1.0}
dist_dir=${DIST_DIR:-dist}
toolchain=${CLASSIC_MAC_TOOLCHAIN:-}

if [ -z "$toolchain" ] || [ ! -f "$toolchain" ]; then
    echo "Set CLASSIC_MAC_TOOLCHAIN to TclTk_8.3.4_FullInstall.bin." >&2
    exit 1
fi

stage="$dist_dir/classic-mac-$arch-stage"
app="$stage/RetroChat"
image="$dist_dir/RetroChat-$version-Classic-MacOS-7-9-$arch-Development-Kit.iso"

rm -rf "$stage"
mkdir -p "$app/lib" "$app/Icons"
cp client.tcl "$app/RetroChat Client"
cp server.tcl server-gui.tcl "$app/"
cp server-gui.tcl "$app/RetroChat Server"
cp lib/protocol.tcl "$app/lib/"
cp assets/icons/classic-mac/client-16.png "$app/Icons/Client 16.png"
cp assets/icons/classic-mac/client-32.png "$app/Icons/Client 32.png"
cp assets/icons/classic-mac/client-48.png "$app/Icons/Client 48.png"
cp assets/icons/classic-mac/server-16.png "$app/Icons/Server 16.png"
cp assets/icons/classic-mac/server-32.png "$app/Icons/Server 32.png"
cp assets/icons/classic-mac/server-48.png "$app/Icons/Server 48.png"
cp packaging/classic-mac/README.txt "$stage/Read Me"
cp packaging/classic-mac/BUILDING.txt "$stage/Building RetroChat"
cp packaging/classic-mac/MAKE-INSTALLER.txt "$stage/Make Installer"
cp "$toolchain" "$stage/TclTk 8.3.4 Full Installer.bin"

SetFile -t TEXT -c WIsH "$app/RetroChat Client" "$app/RetroChat Server"

rm -f "$image"
hdiutil makehybrid -hfs -iso -joliet -keep-mac-specific \
    -hfs-volume-name "RetroChat $arch" \
    -iso-volume-name "RETROCHAT_$arch" \
    -joliet-volume-name "RetroChat $arch" \
    -o "$image" "$stage"

echo "$image"
