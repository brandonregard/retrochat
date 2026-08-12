#!/bin/sh
set -eu

version=${VERSION:-0.1.0}
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
    agent_key=""

    if [ "$executable" = "tclsh" ]; then
        agent_key="  <key>LSUIElement</key><true/>"
    fi

    mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources/app/lib"
    mkdir -p "$app/Contents/Resources/runtime/bin"
    mkdir -p "$app/Contents/Resources/runtime/lib"

    cp "$tcl_prefix/bin/$executable" "$app/Contents/Resources/runtime/bin/"
    cp "$tcl_prefix/lib/libtcl9.0.dylib" "$app/Contents/Resources/runtime/lib/"
    cp "$tcl_prefix/lib/libtcl9tk9.0.dylib" "$app/Contents/Resources/runtime/lib/"
    cp "$tommath_prefix/lib/libtommath.1.dylib" "$app/Contents/Resources/runtime/lib/"
    cp -R "$tcl_prefix/lib/tcl9.0" "$app/Contents/Resources/runtime/lib/"
    cp -R "$tcl_prefix/lib/tk9.0" "$app/Contents/Resources/runtime/lib/"
    cp -R "$tcl_prefix/lib/tcl9" "$app/Contents/Resources/runtime/lib/"
    cp "$script" "$app/Contents/Resources/app/"
    cp lib/protocol.tcl "$app/Contents/Resources/app/lib/"

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
  <key>CFBundleName</key><string>$display_name</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$version</string>
  <key>CFBundleVersion</key><string>$version</string>
  <key>LSMinimumSystemVersion</key><string>26.0</string>
${agent_key}
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
EOF

    if [ "$executable" = "tclsh" ]; then
        cat > "$app/Contents/MacOS/launcher" <<EOF
#!/bin/sh
resources="\$(cd "\$(dirname "\$0")/../Resources" && pwd)"
export TCL_LIBRARY="\$resources/runtime/lib/tcl9.0"
export TK_LIBRARY="\$resources/runtime/lib/tk9.0"
export TCLLIBPATH="\$resources/runtime/lib"
log_dir="\$HOME/Library/Logs"
log_file="\$log_dir/RetroChat Server.log"
mkdir -p "\$log_dir"
"\$resources/runtime/bin/tclsh" "\$resources/app/$script" "\$@" >>"\$log_file" 2>&1 &
server_pid=\$!
/usr/bin/osascript -e 'display notification "Listening on port 7777" with title "RetroChat Server"' >/dev/null 2>&1 || true
wait "\$server_pid"
EOF
    else
        cat > "$app/Contents/MacOS/launcher" <<EOF
#!/bin/sh
resources="\$(cd "\$(dirname "\$0")/../Resources" && pwd)"
export TCL_LIBRARY="\$resources/runtime/lib/tcl9.0"
export TK_LIBRARY="\$resources/runtime/lib/tk9.0"
export TCLLIBPATH="\$resources/runtime/lib"
exec "\$resources/runtime/bin/$executable" "\$resources/app/$script" "\$@"
EOF
    fi
    chmod 755 "$app/Contents/MacOS/launcher"

    install_name_tool -change "$tcl_real_prefix/lib/libtcl9.0.dylib" \
        @executable_path/../lib/libtcl9.0.dylib \
        "$app/Contents/Resources/runtime/bin/$executable"
    install_name_tool -change "$tcl_real_prefix/lib/libtcl9tk9.0.dylib" \
        @executable_path/../lib/libtcl9tk9.0.dylib \
        "$app/Contents/Resources/runtime/bin/$executable"
    for old_tommath in \
        "$tommath_prefix/lib/libtommath.1.dylib" \
        "$tommath_real_prefix/lib/libtommath.1.dylib"
    do
        install_name_tool -change "$old_tommath" \
            @executable_path/../lib/libtommath.1.dylib \
            "$app/Contents/Resources/runtime/bin/$executable"
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
    codesign --force --sign - "$app/Contents/Resources/runtime/bin/$executable"
    codesign --force --sign - "$app"
}

make_app "$client_app" wish client.tcl com.retrochat.client RetroChat
make_app "$server_app" tclsh server.tcl com.retrochat.server "RetroChat Server"

ln -s /Applications "$stage/Applications"
rm -f "$dist_dir/RetroChat-$version-macOS26-arm64.dmg"
hdiutil create -volname "RetroChat $version" -srcfolder "$stage" \
    -ov -format UDZO "$dist_dir/RetroChat-$version-macOS26-arm64.dmg"

echo "$dist_dir/RetroChat-$version-macOS26-arm64.dmg"
