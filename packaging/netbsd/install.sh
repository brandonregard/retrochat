#!/bin/sh

# RetroChat installer for NetBSD 10.1/mac68k.
# Run this script as root from the mounted installer CD.

set -eu

version="@VERSION@"
media_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
install_root=${RETROCHAT_PREFIX:-/usr/local/lib/retrochat}
bin_root=${RETROCHAT_BIN:-/usr/local/bin}

if [ "$(id -u)" -ne 0 ]; then
    echo "Run this installer as root: sh $0" >&2
    exit 1
fi

find_runtime() {
    program=$1
    for candidate in "$program" "${program}8.6" "${program}8.5" \
        "/usr/pkg/bin/$program" "/usr/pkg/bin/${program}8.6" "/usr/pkg/bin/${program}8.5"
    do
        if command -v "$candidate" >/dev/null 2>&1; then
            command -v "$candidate"
            return 0
        fi
        if [ -x "$candidate" ]; then
            echo "$candidate"
            return 0
        fi
    done
    return 1
}

if ! find_runtime tclsh >/dev/null 2>&1 || ! find_runtime wish >/dev/null 2>&1; then
    if ! command -v pkg_add >/dev/null 2>&1; then
        echo "NetBSD's pkg_add command is unavailable." >&2
        exit 1
    fi

    runtime_archive="$media_dir/RUNTIME.TGZ"
    if [ ! -f "$runtime_archive" ]; then
        echo "The bundled Tcl/Tk runtime is missing from the installer media." >&2
        exit 1
    fi

    package_dir="${TMPDIR:-/tmp}/retrochat-runtime.$$"
    rm -rf "$package_dir"
    mkdir -p "$package_dir"
    trap 'rm -rf "$package_dir"' 0 1 2 15
    tar --no-xattrs -xzf "$runtime_archive" -C "$package_dir"

    PKG_PATH="$package_dir"
    export PKG_PATH
    echo "Installing the bundled Tcl/Tk runtime..."
    pkg_add "$package_dir/tk-8.6.16.tgz"
    rm -rf "$package_dir"
    trap - 0 1 2 15
fi

tclsh_path=$(find_runtime tclsh) || exit 1
wish_path=$(find_runtime wish) || exit 1

client_archive="$media_dir/CLIENT.TGZ"
server_archive="$media_dir/SERVER.TGZ"
if [ ! -f "$client_archive" ] || [ ! -f "$server_archive" ]; then
    echo "The RetroChat archives are missing from the installer media." >&2
    exit 1
fi

echo "Installing RetroChat $version in $install_root..."
mkdir -p "$install_root" "$bin_root"
rm -rf "$install_root/client" "$install_root/server"
mkdir -p "$install_root/client" "$install_root/server"
tar --no-xattrs -xzf "$client_archive" -C "$install_root/client" --strip-components 1
tar --no-xattrs -xzf "$server_archive" -C "$install_root/server" --strip-components 1

sed "s|@INSTALL_ROOT@|$install_root|g; s|@WISH@|$wish_path|g" \
    "$media_dir/CLIENT.IN" > "$bin_root/retrochat-client"
sed "s|@INSTALL_ROOT@|$install_root|g; s|@WISH@|$wish_path|g; s|@TCLSH@|$tclsh_path|g" \
    "$media_dir/SERVER.IN" > "$bin_root/retrochat-server"
chmod 755 "$bin_root/retrochat-client" "$bin_root/retrochat-server"

echo
echo "RetroChat $version is installed."
echo "  Client: retrochat-client"
echo "  Server: retrochat-server 7777"
echo
if [ -z "${DISPLAY:-}" ]; then
    echo "Start X11 before running retrochat-client."
else
    echo "X11 display is $DISPLAY. You can run retrochat-client now."
fi
