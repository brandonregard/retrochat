#!/bin/sh
set -eu

root=assets/icons
icon_work=$(mktemp -d /tmp/retrochat-icons.XXXXXX)
trap 'rm -rf "$icon_work"' EXIT HUP INT TERM

for kind in client server
do
    master="$root/source/$kind-master.png"
    sips -g hasAlpha "$master" | grep -q 'hasAlpha: yes' || {
        echo "$master must contain an alpha channel" >&2
        exit 1
    }

    for size in 16 24 32 48 64 128 256 512 1024
    do
        mkdir -p "$root/png/$kind"
        sips -z "$size" "$size" "$master" \
            --out "$root/png/$kind/${kind}-${size}.png" >/dev/null
        sips -g hasAlpha "$root/png/$kind/${kind}-${size}.png" |
            grep -q 'hasAlpha: yes' || {
                echo "generated $kind ${size}px icon lost transparency" >&2
                exit 1
            }
    done

    mkdir -p "$root/macos/$kind.iconset"
    cp "$root/png/$kind/${kind}-16.png" "$root/macos/$kind.iconset/icon_16x16.png"
    cp "$root/png/$kind/${kind}-32.png" "$root/macos/$kind.iconset/icon_16x16@2x.png"
    cp "$root/png/$kind/${kind}-32.png" "$root/macos/$kind.iconset/icon_32x32.png"
    cp "$root/png/$kind/${kind}-64.png" "$root/macos/$kind.iconset/icon_32x32@2x.png"
    cp "$root/png/$kind/${kind}-128.png" "$root/macos/$kind.iconset/icon_128x128.png"
    cp "$root/png/$kind/${kind}-256.png" "$root/macos/$kind.iconset/icon_128x128@2x.png"
    cp "$root/png/$kind/${kind}-256.png" "$root/macos/$kind.iconset/icon_256x256.png"
    cp "$root/png/$kind/${kind}-512.png" "$root/macos/$kind.iconset/icon_256x256@2x.png"
    cp "$root/png/$kind/${kind}-512.png" "$root/macos/$kind.iconset/icon_512x512.png"
    cp "$root/png/$kind/${kind}-1024.png" "$root/macos/$kind.iconset/icon_512x512@2x.png"

    mkdir -p "$root/macos/$kind.xcassets/AppIcon.appiconset"
    cp packaging/icons/AssetCatalog-Contents.json \
        "$root/macos/$kind.xcassets/Contents.json"
    cp packaging/icons/AppIcon-Contents.json \
        "$root/macos/$kind.xcassets/AppIcon.appiconset/Contents.json"
    cp "$root/macos/$kind.iconset/"*.png \
        "$root/macos/$kind.xcassets/AppIcon.appiconset/"
    png2icns "$root/macos/$kind.icns" \
        "$root/png/$kind/${kind}-16.png" \
        "$root/png/$kind/${kind}-32.png" \
        "$root/png/$kind/${kind}-48.png" \
        "$root/png/$kind/${kind}-128.png" \
        "$root/png/$kind/${kind}-256.png" \
        "$root/png/$kind/${kind}-512.png" \
        "$root/png/$kind/${kind}-1024.png"
    test -s "$root/macos/$kind.icns" || {
        echo "failed to create $kind macOS icon family" >&2
        exit 1
    }

    # Tk 8.0 uses the legacy Win32 icon API. Supply paletted 8-bit entries
    # with explicit 1-bit AND masks for transparent window/taskbar icons.
    mkdir -p "$icon_work/$kind"
    for size in 16 32 48
    do
        ffmpeg -v error -y -i "$root/png/$kind/${kind}-${size}.png" \
            -f rawvideo -pix_fmt rgba "$icon_work/$kind/${kind}-${size}.rgba"
    done
    tclsh packaging/icons/legacy-ico.tcl \
        "$icon_work/$kind/${kind}-16.rgba" 16 \
        "$icon_work/$kind/${kind}-32.rgba" 32 \
        "$icon_work/$kind/${kind}-48.rgba" 48 \
        "$root/windows/$kind.ico"
    test -s "$root/windows/$kind.ico" || {
        echo "failed to create $kind Windows icon family" >&2
        exit 1
    }
    sips -s format gif "$root/png/$kind/${kind}-24.png" \
        --out "$root/png/$kind/${kind}-tray.gif" >/dev/null

    cp "$root/png/$kind/${kind}-16.png" "$root/classic-mac/${kind}-16.png"
    cp "$root/png/$kind/${kind}-32.png" "$root/classic-mac/${kind}-32.png"
    cp "$root/png/$kind/${kind}-48.png" "$root/classic-mac/${kind}-48.png"
    cp "$root/png/$kind/${kind}-16.png" "$root/netbsd/${kind}-16.png"
    cp "$root/png/$kind/${kind}-32.png" "$root/netbsd/${kind}-32.png"
    cp "$root/png/$kind/${kind}-48.png" "$root/netbsd/${kind}-48.png"
    cp "$root/png/$kind/${kind}-256.png" "$root/netbsd/${kind}-256.png"
done
