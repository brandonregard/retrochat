#!/bin/sh
set -eu

arch=${1:?usage: build-fat.sh 68k|ppc}
case "$arch" in
    68k|ppc) ;;
    *) echo "architecture must be 68k or ppc" >&2; exit 2 ;;
esac

version=${VERSION:-0.0.2}
dist_dir=${DIST_DIR:-dist}
stub_68k=${CLASSIC_MAC_68K_STUB:-packaging/classic-mac/runtime/SimpleTk68K.bin}
stub_ppc=${CLASSIC_MAC_PPC_STUB:-packaging/classic-mac/runtime/SimpleTkPPC.bin}
cfm_68k=${CLASSIC_MAC_CFM_68K:-packaging/classic-mac/runtime/CFM-68K-Runtime-Enabler.bin}
runtime_68k=${CLASSIC_MAC_68K_RUNTIME:-packaging/classic-mac/runtime/mactk8.0.3.sea.hqx}

for tool in DeRez Rez SetFile GetFileInfo macbinary hformat hmount humount hcopy hls iconv ffmpeg tclsh
do
    command -v "$tool" >/dev/null 2>&1 || {
        echo "classic Mac installer requires $tool" >&2
        exit 1
    }
done

case "$arch" in
    68k)
        command -v unar >/dev/null 2>&1 || {
            echo "classic Mac 68K installer requires unar" >&2
            exit 1
        }
        test -f "$runtime_68k" || { echo "missing 68K Tcl/Tk runtime: $runtime_68k" >&2; exit 1; }
        test -f "$cfm_68k" || { echo "missing CFM-68K Runtime Enabler: $cfm_68k" >&2; exit 1; }
        macbinary probe "$cfm_68k" >/dev/null 2>&1 || {
            echo "CFM-68K Runtime Enabler is not valid MacBinary" >&2
            exit 1
        }
        ;;
    ppc) stub=$stub_ppc ;;
esac
if [ "$arch" = ppc ]; then
    test -f "$stub" || { echo "missing $arch Tk stub: $stub" >&2; exit 1; }
fi

mkdir -p "$dist_dir"
work=$(mktemp -d "$dist_dir/.classic-$arch.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM

if [ "$arch" = 68k ]; then
    mkdir -p "$work/runtime-extract"
    unar -quiet -output-directory "$work/runtime-extract" "$runtime_68k"
    runtime_root="$work/runtime-extract/mactk8.0.3.sea"
    test -f "$runtime_root/Wish 8.0.3" || {
        echo "68K runtime archive is missing Wish 8.0.3" >&2
        exit 1
    }
    cp -p "$runtime_root/Wish 8.0.3" "$work/SimpleTk"
else
    macbinary decode -n -o "$work/SimpleTk" "$stub"
fi

VERSION="$version" sh packaging/classic-mac/prepare-wrappers.sh "$work/scripts" >/dev/null
grep -q 'set ::retrochatClassicMac 1' "$work/scripts/RetroChat Client.tcl" || {
    echo "Classic client is missing its required filename compatibility flag" >&2
    exit 1
}
cp "$work/scripts/RetroChat Client.tcl" "$work/client.tcl"
cp "$work/scripts/RetroChat Server.tcl" "$work/server.tcl"
sed -e "s/@VERSION@/$version/g" -e "s/@ARCH@/$arch/g" packaging/classic-mac/installer.tcl |
    iconv -f UTF-8 -t MACINTOSH | LC_ALL=C tr '\n' '\r' \
    > "$work/installer.tcl"
sed "s/@VERSION@/$version/g" packaging/classic-mac/INSTALLER-README.txt |
    iconv -f UTF-8 -t MACINTOSH | LC_ALL=C tr '\n' '\r' \
    > "$work/readme.txt"

installer="$work/RetroChat $version Installer $arch"
cp -p "$work/SimpleTk" "$installer"
Rez -a -ov \
    -d "TCL_SCRIPT_PATH=\"$work/installer.tcl\"" \
    -o "$installer" packaging/classic-mac/tclet-script.r
ffmpeg -v error -i assets/icons/classic-mac/client-32.png \
    -f rawvideo -pix_fmt rgba "$work/client-32.rgba"
ffmpeg -v error -i assets/icons/classic-mac/client-16.png \
    -f rawvideo -pix_fmt rgba "$work/client-16.rgba"
ffmpeg -v error -i assets/icons/classic-mac/server-32.png \
    -f rawvideo -pix_fmt rgba "$work/server-32.rgba"
ffmpeg -v error -i assets/icons/classic-mac/server-16.png \
    -f rawvideo -pix_fmt rgba "$work/server-16.rgba"
ffmpeg -v error -y -i assets/icons/classic-mac/client-48.png \
    -filter_complex \
    '[0:v]split[icon][palette_source];[palette_source]palettegen=reserve_transparent=1:transparency_color=ffffff[palette];[icon][palette]paletteuse=alpha_threshold=128' \
    -frames:v 1 "$work/client-about.gif"
ffmpeg -v error -y -i assets/icons/classic-mac/server-48.png \
    -filter_complex \
    '[0:v]split[icon][palette_source];[palette_source]palettegen=reserve_transparent=1:transparency_color=ffffff[palette];[icon][palette]paletteuse=alpha_threshold=128' \
    -frames:v 1 "$work/server-about.gif"
tclsh packaging/icons/classic-icon-rez.tcl \
    "$work/client-32.rgba" "$work/client-16.rgba" \
    "$work/server-32.rgba" "$work/server-16.rgba" "$work/installer-icon.r" \
    "$work/client-icon.xbm" "$work/client-mask.xbm"
Rez -a -ov \
    -d "CLIENT_SCRIPT_PATH=\"$work/client.tcl\"" \
    -d "SERVER_SCRIPT_PATH=\"$work/server.tcl\"" \
    -d "README_PATH=\"$work/readme.txt\"" \
    -d "ICON_BITMAP_PATH=\"$work/client-icon.xbm\"" \
    -d "ICON_MASK_PATH=\"$work/client-mask.xbm\"" \
    -d "CLIENT_COLOR_ICON_PATH=\"$work/client-about.gif\"" \
    -d "SERVER_COLOR_ICON_PATH=\"$work/server-about.gif\"" \
    -o "$installer" packaging/classic-mac/fat-installer-resources.r
Rez -a -ov -o "$installer" "$work/installer-icon.r"
SetFile -t APPL -c RtIn -a BC "$installer"

DeRez "$installer" > "$work/installer-resources.r"
required_executable_resources="data 'SIZE' (-1"
if [ "$arch" = 68k ]; then
    required_executable_resources="data 'CODE' (0|data 'CODE' (6|data 'cfrg' (0|$required_executable_resources"
else
    required_executable_resources="data 'cfrg' (0|$required_executable_resources"
fi
printf '%s\n' "$required_executable_resources" | tr '|' '\n' | while IFS= read -r required
do
    grep -Fq "$required" "$work/installer-resources.r" || {
        echo "Classic $arch installer is missing required resource: $required" >&2
        exit 1
    }
done
for required in \
    "data 'ICN#' (128" "data 'ICN#' (129" "data 'ICN#' (130" \
    "data 'ICN#' (-16455" "data 'icl4' (-16455" \
    "data 'ics#' (-16455" "data 'ics4' (-16455"
do
    grep -Fq "$required" "$work/installer-resources.r" || {
        echo "Classic installer is missing required resource: $required" >&2
        exit 1
    }
done
case $(GetFileInfo -a "$installer") in
    *B*C*) ;;
    *) echo "Classic installer is missing bundle/custom-icon Finder flags" >&2; exit 1 ;;
esac

macbinary_output="$dist_dir/retrochat-$version-macos-$arch.bin"
image_output="$dist_dir/retrochat-$version-macos-$arch.hfv"
# Keep the distributed filename within the 31-character limit used by
# System 7 and put the HFS Standard volume itself on the CD image.  Apple's
# makehybrid creates HFS+, which System 7.5.3 cannot mount; it consequently
# falls back to ISO 9660, uppercases the names, and loses resource forks.
iso_output="$dist_dir/retrochat-$version-macos-$arch.iso"
macbinary encode -n -t 2 -o "$macbinary_output" "$installer"

if [ "$arch" = 68k ]; then
    for runtime_file in Tcl8.0CFM68K.shlb Tk8.0CFM68K.shlb; do
        macbinary encode -n -t 2 -o "$work/$runtime_file.bin" \
            "$runtime_root/$runtime_file"
    done
fi

image_megabytes=8
if [ "$arch" = 68k ]; then image_megabytes=16; fi
dd if=/dev/zero of="$image_output" bs=1m count="$image_megabytes" 2>/dev/null
hformat -l "RetroChat $arch" "$image_output" >/dev/null
hmount "$image_output" >/dev/null
hcopy -m "$macbinary_output" ":RetroChat $version Installer $arch"
if [ "$arch" = 68k ]; then
    hcopy -m "$cfm_68k" ":CFM-68K Runtime Enabler"
    hcopy -m "$work/Tcl8.0CFM68K.shlb.bin" ":Tcl8.0CFM68K.shlb"
    hcopy -m "$work/Tk8.0CFM68K.shlb.bin" ":Tk8.0CFM68K.shlb"
    hmkdir :tcl8.0 :tk8.0
    for runtime_file in "$runtime_root"/tcl8.0/*; do
        test -f "$runtime_file" && hcopy -t "$runtime_file" \
            ":tcl8.0:$(basename "$runtime_file")"
    done
    for runtime_file in "$runtime_root"/tk8.0/*.tcl "$runtime_root"/tk8.0/tclIndex; do
        test -f "$runtime_file" && hcopy -t "$runtime_file" \
            ":tk8.0:$(basename "$runtime_file")"
    done
fi
hcopy -t packaging/classic-mac/INSTALLER-README.txt ":Read Me"
hfs_listing=$(hls -la)
printf '%s\n' "$hfs_listing" | grep -q "APPL/RtIn.*RetroChat $version Installer $arch" || {
    echo "HFS image is missing the executable installer or its Finder metadata" >&2
    exit 1
}
if [ "$arch" = 68k ]; then
    printf '%s\n' "$hfs_listing" | grep -q "INIT/cfm8.*CFM-68K Runtime Enabler" || {
        echo "HFS image is missing the 68K System 7 CFM runtime extension" >&2
        exit 1
    }
    printf '%s\n' "$hfs_listing" | grep -q "shlb/TclL.*Tcl8.0CFM68K.shlb" || {
        echo "HFS image is missing the Tcl 8.0.3 68K shared library" >&2
        exit 1
    }
    printf '%s\n' "$hfs_listing" | grep -q "shlb/TclL.*Tk8.0CFM68K.shlb" || {
        echo "HFS image is missing the Tk 8.0.3 68K shared library" >&2
        exit 1
    }
fi
printf '%s\n' "$hfs_listing" | grep -q "Read Me" || {
    echo "HFS image is missing the mixed-case read-me name" >&2
    exit 1
}
humount

rm -f "$iso_output"
rm -f "$dist_dir/retrochat-$version-macos-fat.iso"
rm -f "$dist_dir/retrochat-$version-macos-classic-fat.bin"
rm -f "$dist_dir/retrochat-$version-macos-classic-fat.hfv"
# A classic Macintosh CD may contain a plain HFS Standard filesystem.  The
# .iso suffix is retained for emulator/CD-ROM attachment, while the bytes are
# copied from the already validated HFS image so Finder metadata, icons, and
# architecture-specific executable and resource forks survive unchanged.
cp "$image_output" "$iso_output"
iso_name=$(basename "$iso_output")
test "$(printf '%s' "$iso_name" | wc -c | tr -d ' ')" -le 31 || {
    echo "Classic Mac image filename exceeds 31 characters: $iso_name" >&2
    exit 1
}

echo "$image_output"
echo "$macbinary_output"
echo "$iso_output"
