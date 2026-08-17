#!/bin/sh
set -eu

version=${VERSION:-0.0.1}
dist_dir=${DIST_DIR:-dist}
tcl_prefix=${TCL_PREFIX:-/opt/homebrew/opt/tcl-tk}
tommath_prefix=${TOMMATH_PREFIX:-/opt/homebrew/opt/libtommath}
tcl_real_prefix=$(cd "$tcl_prefix" && pwd -P)
tommath_real_prefix=$(cd "$tommath_prefix" && pwd -P)
stage="$dist_dir/macos-stage"
client_app="$stage/RetroChat.app"
server_app="$stage/RetroChat Server.app"

if [ ! -x "$tcl_prefix/bin/wish" ] || [ ! -x "$tcl_prefix/bin/tclsh" ]; then
    echo "Tcl/Tk was not found at $tcl_prefix" >&2
    exit 1
fi

rm -rf "$stage"
mkdir -p "$stage"

make_app() {
    app=$1
    executable=$2
    script=$3
    bundle_id=$4
    display_name=$5
    if [ "$script" = "server-gui.tcl" ]; then
        icon_name=server
    else
        icon_name=client
    fi

    mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources/app/lib"
    mkdir -p "$app/Contents/Resources/runtime/bin"
    mkdir -p "$app/Contents/Resources/runtime/lib"

    if [ "$executable" = "wish" ]; then
        clang -Os -I"$tcl_prefix/include/tcl-tk" packaging/macos/launcher.c \
            -L"$tcl_prefix/lib" -ltcl9tk9.0 -ltcl9.0 \
            -o "$app/Contents/Resources/runtime/bin/RetroChat"
        runtime_executable=RetroChat
    else
        cp "$tcl_prefix/bin/$executable" "$app/Contents/Resources/runtime/bin/"
        runtime_executable=$executable
    fi
    cp "$tcl_prefix/lib/libtcl9.0.dylib" "$app/Contents/Resources/runtime/lib/"
    cp "$tcl_prefix/lib/libtcl9tk9.0.dylib" "$app/Contents/Resources/runtime/lib/"
    cp "$tommath_prefix/lib/libtommath.1.dylib" "$app/Contents/Resources/runtime/lib/"
    cp -R "$tcl_prefix/lib/tcl9.0" "$app/Contents/Resources/runtime/lib/"
    cp -R "$tcl_prefix/lib/tk9.0" "$app/Contents/Resources/runtime/lib/"
    cp -R "$tcl_prefix/lib/tcl9" "$app/Contents/Resources/runtime/lib/"
    cp "$script" "$app/Contents/Resources/app/"
    cp lib/protocol.tcl "$app/Contents/Resources/app/lib/"
    mkdir -p "$app/Contents/Resources/app/assets/icons/png/$icon_name"
    cp "assets/icons/png/$icon_name/${icon_name}-tray.gif" \
        "$app/Contents/Resources/app/assets/icons/png/$icon_name/"
    cp "assets/icons/png/$icon_name/${icon_name}-128.png" \
        "$app/Contents/Resources/app/assets/icons/png/$icon_name/"
    cp "assets/icons/macos/$icon_name.icns" \
        "$app/Contents/Resources/RetroChat.icns"
    xcrun actool "assets/icons/macos/$icon_name.xcassets" \
        --compile "$app/Contents/Resources" \
        --platform macosx \
        --minimum-deployment-target 26.0 \
        --app-icon AppIcon \
        --output-partial-info-plist "$app/Contents/Resources/asset-info.plist"
    if [ "$script" = "server-gui.tcl" ]; then
        cp server.tcl "$app/Contents/Resources/app/"
    fi

    cat > "$app/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key><string>en</string>
  <key>CFBundleDisplayName</key><string>$display_name</string>
  <key>CFBundleExecutable</key><string>launcher</string>
  <key>CFBundleIdentifier</key><string>$bundle_id</string>
  <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
  <key>CFBundleIconFile</key><string>RetroChat.icns</string>
  <key>CFBundleIconName</key><string>AppIcon</string>
  <key>CFBundleName</key><string>$display_name</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$version</string>
  <key>CFBundleVersion</key><string>$version</string>
  <key>NSHumanReadableCopyright</key><string>Copyright 2026 Brandon Regard</string>
  <key>LSMinimumSystemVersion</key><string>26.0</string>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
EOF

    cat > "$app/Contents/MacOS/launcher" <<EOF
#!/bin/sh
resources="\$(cd "\$(dirname "\$0")/../Resources" && pwd)"
export TCL_LIBRARY="\$resources/runtime/lib/tcl9.0"
export TK_LIBRARY="\$resources/runtime/lib/tk9.0"
export TCLLIBPATH="\$resources/runtime/lib"
exec "\$resources/runtime/bin/$runtime_executable" "\$resources/app/$script" "\$@"
EOF
    chmod 755 "$app/Contents/MacOS/launcher"

    for old_tcl_prefix in "$tcl_prefix" "$tcl_real_prefix"
    do
        install_name_tool -change "$old_tcl_prefix/lib/libtcl9.0.dylib" \
            @executable_path/../lib/libtcl9.0.dylib \
            "$app/Contents/Resources/runtime/bin/$runtime_executable"
        install_name_tool -change "$old_tcl_prefix/lib/libtcl9tk9.0.dylib" \
            @executable_path/../lib/libtcl9tk9.0.dylib \
            "$app/Contents/Resources/runtime/bin/$runtime_executable"
    done
    for old_tommath in \
        "$tommath_prefix/lib/libtommath.1.dylib" \
        "$tommath_real_prefix/lib/libtommath.1.dylib"
    do
        install_name_tool -change "$old_tommath" \
            @executable_path/../lib/libtommath.1.dylib \
            "$app/Contents/Resources/runtime/bin/$runtime_executable"
        install_name_tool -change "$old_tommath" \
            @loader_path/libtommath.1.dylib \
            "$app/Contents/Resources/runtime/lib/libtcl9.0.dylib"
        install_name_tool -change "$old_tommath" \
            @loader_path/libtommath.1.dylib \
            "$app/Contents/Resources/runtime/lib/libtcl9tk9.0.dylib"
    done
    install_name_tool -id @loader_path/libtcl9.0.dylib \
        "$app/Contents/Resources/runtime/lib/libtcl9.0.dylib"
    install_name_tool -id @loader_path/libtcl9tk9.0.dylib \
        "$app/Contents/Resources/runtime/lib/libtcl9tk9.0.dylib"
    install_name_tool -id @loader_path/libtommath.1.dylib \
        "$app/Contents/Resources/runtime/lib/libtommath.1.dylib"

    codesign --force --sign - "$app/Contents/Resources/runtime/lib/libtommath.1.dylib"
    codesign --force --sign - "$app/Contents/Resources/runtime/lib/libtcl9.0.dylib"
    codesign --force --sign - "$app/Contents/Resources/runtime/lib/libtcl9tk9.0.dylib"
    codesign --force --sign - "$app/Contents/Resources/runtime/bin/$runtime_executable"
    codesign --force --sign - "$app"
}

make_app "$client_app" wish client.tcl com.retrochat.client RetroChat
make_app "$server_app" wish server-gui.tcl com.retrochat.server "RetroChat Server"

ln -s /Applications "$stage/Applications"
rm -f "$dist_dir/retrochat-$version-macos-arm64.iso"
hdiutil makehybrid -hfs -iso -joliet \
    -default-volume-name "RetroChat $version" \
    -o "$dist_dir/retrochat-$version-macos-arm64.iso" "$stage"

echo "$dist_dir/retrochat-$version-macos-arm64.iso"
