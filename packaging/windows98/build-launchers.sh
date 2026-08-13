#!/bin/sh
set -eu

dist_dir=${DIST_DIR:-dist}
cc=${MINGW_CC:-i686-w64-mingw32-gcc}
windres=${MINGW_WINDRES:-i686-w64-mingw32-windres}
mkdir -p "$dist_dir"
work=$(mktemp -d "$dist_dir/.windows-launchers.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM

for kind in client server
do
    "$windres" packaging/windows98/$kind.rc -O coff -o "$work/$kind-icon.o"
    script=$kind.tcl
    args=
    if test "$kind" = server; then
        script=server-gui.tcl
        args=7777
    fi
    "$cc" -Os -s -mwindows -nostdlib -D_WIN32_WINNT=0x0400 \
        -DSCRIPT_NAME="\"$script\"" packaging/windows98/launcher.c \
        -DSCRIPT_ARGS="\"$args\"" "$work/$kind-icon.o" \
        -Wl,-e,_WinMainCRTStartup -lkernel32 -luser32 \
        -o "$dist_dir/RetroChat-$kind.exe"
done
