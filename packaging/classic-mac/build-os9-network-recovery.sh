#!/bin/sh
set -eu

component_dir=${OS9_NETWORK_COMPONENT_DIR:?set OS9_NETWORK_COMPONENT_DIR to MacBinary components}
dist_dir=${DIST_DIR:-dist}
stub_68k=${CLASSIC_MAC_68K_STUB:-packaging/classic-mac/runtime/SimpleTk68K.bin}
stub_ppc=${CLASSIC_MAC_PPC_STUB:-packaging/classic-mac/runtime/SimpleTkPPC.bin}
work=$(mktemp -d "$dist_dir/.os9-network-recovery.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM

mkdir -p "$dist_dir" "$work/support" "$work/iso-stage"
macbinary decode -n -o "$work/SimpleTk68K" "$stub_68k"
macbinary decode -n -o "$work/SimpleTkPPC" "$stub_ppc"
DeRez -only CODE "$work/SimpleTk68K" > "$work/code68k.r"
iconv -f UTF-8 -t MACINTOSH packaging/classic-mac/os9-network-recovery.tcl |
    LC_ALL=C tr '\n' '\r' > "$work/recovery.tcl"

recovery="$work/Restore Mac OS 9 Networking"
cp -p "$work/SimpleTkPPC" "$recovery"
Rez -a -ov -o "$recovery" "$work/code68k.r"
Rez -a -ov -d "TCL_SCRIPT_PATH=\"$work/recovery.tcl\"" \
    -o "$recovery" packaging/classic-mac/tclet-script.r
SetFile -t APPL -c RtIn -a B "$recovery"

macbinary decode -n -C "$work/support" "$component_dir/MacTCP_DNR.bin"
macbinary decode -n -C "$work/support" "$component_dir/Open_Transport.bin"
macbinary decode -n -C "$work/support" "$component_dir/Open_Transport_ASLM_Modules.bin"

ditto "$recovery" "$work/iso-stage/Restore Mac OS 9 Networking"
ditto "$work/support" "$work/iso-stage/Mac OS 9.0.4 Network Files"
cp packaging/classic-mac/OS9-NETWORK-RECOVERY-README.txt \
    "$work/iso-stage/Read Me"
SetFile -t TEXT -c ttxt "$work/iso-stage/Read Me"

output="$dist_dir/RetroChat-MacOS-9.0.4-Network-Recovery.iso"
rm -f "$output"
hdiutil makehybrid -hfs -iso -joliet -keep-mac-specific \
    -hfs-volume-name "OS 9 Network Recovery" \
    -iso-volume-name "OS9_NET_REPAIR" \
    -joliet-volume-name "OS 9 Network Recovery" \
    -o "$output" "$work/iso-stage"
echo "$output"
