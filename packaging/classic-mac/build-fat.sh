#!/bin/sh
set -eu

version=${VERSION:-0.1.0}
dist_dir=${DIST_DIR:-dist}
stub_68k=${CLASSIC_MAC_68K_STUB:-packaging/classic-mac/runtime/SimpleTk68K.bin}
stub_ppc=${CLASSIC_MAC_PPC_STUB:-packaging/classic-mac/runtime/SimpleTkPPC.bin}

for tool in DeRez Rez SetFile macbinary hformat hmount humount hcopy iconv ditto hdiutil ffmpeg tclsh
do
    command -v "$tool" >/dev/null 2>&1 || {
        echo "classic fat installer requires $tool" >&2
        exit 1
    }
done

test -f "$stub_68k" || { echo "missing 68K Tk stub: $stub_68k" >&2; exit 1; }
test -f "$stub_ppc" || { echo "missing PPC Tk stub: $stub_ppc" >&2; exit 1; }

mkdir -p "$dist_dir"
work=$(mktemp -d "$dist_dir/.classic-fat.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM

macbinary decode -n -o "$work/SimpleTk68K" "$stub_68k"
macbinary decode -n -o "$work/SimpleTkPPC" "$stub_ppc"
DeRez -only CODE "$work/SimpleTk68K" > "$work/code68k.r"

sh packaging/classic-mac/prepare-wrappers.sh "$work/scripts" >/dev/null
cp "$work/scripts/RetroChat Client.tcl" "$work/client.tcl"
cp "$work/scripts/RetroChat Server.tcl" "$work/server.tcl"
sed "s/@VERSION@/$version/g" packaging/classic-mac/installer.tcl |
    iconv -f UTF-8 -t MACINTOSH | LC_ALL=C tr '\n' '\r' \
    > "$work/installer.tcl"
sed "s/@VERSION@/$version/g" packaging/classic-mac/INSTALLER-README.txt |
    iconv -f UTF-8 -t MACINTOSH | LC_ALL=C tr '\n' '\r' \
    > "$work/readme.txt"

installer="$work/RetroChat $version Installer"
cp -p "$work/SimpleTkPPC" "$installer"
Rez -a -ov -o "$installer" "$work/code68k.r"
Rez -a -ov \
    -d "TCL_SCRIPT_PATH=\"$work/installer.tcl\"" \
    -o "$installer" packaging/classic-mac/tclet-script.r
ffmpeg -v error -i assets/icons/classic-mac/client-32.png \
    -f rawvideo -pix_fmt rgba "$work/client-32.rgba"
ffmpeg -v error -i assets/icons/classic-mac/client-16.png \
    -f rawvideo -pix_fmt rgba "$work/client-16.rgba"
tclsh packaging/icons/classic-icon-rez.tcl \
    "$work/client-32.rgba" "$work/client-16.rgba" "$work/installer-icon.r" \
    "$work/client-icon.xbm" "$work/client-mask.xbm"
Rez -a -ov \
    -d "CLIENT_SCRIPT_PATH=\"$work/client.tcl\"" \
    -d "SERVER_SCRIPT_PATH=\"$work/server.tcl\"" \
    -d "README_PATH=\"$work/readme.txt\"" \
    -d "ICON_BITMAP_PATH=\"$work/client-icon.xbm\"" \
    -d "ICON_MASK_PATH=\"$work/client-mask.xbm\"" \
    -o "$installer" packaging/classic-mac/fat-installer-resources.r
Rez -a -ov -o "$installer" "$work/installer-icon.r"
SetFile -t APPL -c RtIn -a B "$installer"

macbinary_output="$dist_dir/RetroChat-$version-Classic-MacOS-7-9-Fat-Installer.bin"
image_output="$dist_dir/RetroChat-$version-Classic-MacOS-7-9-Fat-Installer.hfv"
iso_output="$dist_dir/RetroChat-$version-Classic-MacOS-7-9-Fat-Installer.iso"
macbinary encode -n -t 2 -o "$macbinary_output" "$installer"

dd if=/dev/zero of="$image_output" bs=1m count=8 2>/dev/null
hformat -l "RetroChat $version" "$image_output" >/dev/null
hmount "$image_output" >/dev/null
hcopy -m "$macbinary_output" ":RetroChat $version Installer"
hcopy -t packaging/classic-mac/INSTALLER-README.txt ":Read Me"
humount

iso_stage="$work/iso-stage"
mkdir -p "$iso_stage"
ditto "$installer" "$iso_stage/RetroChat $version Installer"
cp packaging/classic-mac/INSTALLER-README.txt "$iso_stage/Read Me"
SetFile -t TEXT -c ttxt "$iso_stage/Read Me"
rm -f "$iso_output"
hdiutil makehybrid -hfs -iso -joliet -keep-mac-specific \
    -hfs-volume-name "RetroChat $version" \
    -iso-volume-name "RETROCHAT" \
    -joliet-volume-name "RetroChat $version" \
    -o "$iso_output" "$iso_stage"

echo "$image_output"
echo "$macbinary_output"
echo "$iso_output"
