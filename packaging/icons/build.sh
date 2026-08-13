#!/bin/sh
set -eu

root=assets/icons

for kind in client server
do
    master="$root/source/$kind-master.png"

    for size in 16 24 32 48 64 128 256 512 1024
    do
        mkdir -p "$root/png/$kind"
        sips -z "$size" "$size" "$master" \
            --out "$root/png/$kind/${kind}-${size}.png" >/dev/null
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

    icotool -c -o "$root/windows/$kind.ico" \
        "$root/png/$kind/${kind}-16.png" \
        "$root/png/$kind/${kind}-32.png" \
        "$root/png/$kind/${kind}-48.png" \
        "$root/png/$kind/${kind}-256.png"
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
