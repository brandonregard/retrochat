#!/bin/sh
set -eu

version=${VERSION:-0.0.3}
dist_dir=${DIST_DIR:-dist}
runtime_archive=${WINDOWS_AMD64_RUNTIME:-packaging/windows-amd64/runtime/tcltk86-win10-amd64.tgz}
cc=${MINGW_AMD64_CC:-x86_64-w64-mingw32-gcc}
windres=${MINGW_AMD64_WINDRES:-x86_64-w64-mingw32-windres}
work=$(mktemp -d "$dist_dir/.windows-amd64.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM

mkdir -p "$dist_dir"
tar -xzf "$runtime_archive" -C "$work"
runtime_root=$(find "$work" -mindepth 1 -maxdepth 1 -type d | head -n 1)
test -x "$runtime_root/bin/wish86.exe"
rm -rf "$dist_dir/windows-amd64-runtime"
mv "$runtime_root" "$dist_dir/windows-amd64-runtime"

for kind in client server
do
    "$windres" "packaging/windows-amd64/$kind.rc" -O coff -o "$work/$kind-icon.o"
    script=$kind.tcl
    args=
    if test "$kind" = server; then
        script=server-gui.tcl
        args=7777
    fi
    "$cc" -Os -s -mwindows -nostdlib -D_WIN32_WINNT=0x0601 \
        -DSCRIPT_NAME="\"$script\"" packaging/windows-amd64/launcher.c \
        -DSCRIPT_ARGS="\"$args\"" "$work/$kind-icon.o" \
        -Wl,-e,WinMainCRTStartup -lkernel32 -luser32 \
        -o "$dist_dir/RetroChat-amd64-$kind.exe"
done

VERSION="$version" DIST_DIR="$dist_dir" sh packaging/windows/build-msi.sh amd64
file "$dist_dir/RetroChat-amd64-client.exe" "$dist_dir/RetroChat-amd64-server.exe"
