#!/bin/sh
set -eu

version=${VERSION:-0.0.4}
dist_dir=${DIST_DIR:-dist}
macos_arch=${MACOS_ARCH:-arm64}
output_arch=${MACOS_OUTPUT_ARCH:-$macos_arch}
deployment_target=${MACOS_DEPLOYMENT_TARGET:-26.0}
runtime_archive=${MACOS_RUNTIME_ARCHIVE:-}
tcl_prefix=${TCL_PREFIX:-/opt/homebrew/opt/tcl-tk}
tommath_prefix=${TOMMATH_PREFIX:-/opt/homebrew/opt/libtommath}
if [ -n "$runtime_archive" ]; then
    runtime_work=$(mktemp -d "${TMPDIR:-/tmp}/retrochat-macos-runtime.XXXXXX")
    trap 'rm -rf "$runtime_work"' EXIT HUP INT TERM
    tar -xzf "$runtime_archive" -C "$runtime_work"
    tcl_prefix=$runtime_work
    tommath_prefix=$runtime_work
fi
tcl_real_prefix=$(cd "$tcl_prefix" && pwd -P)
tcl_include="$tcl_prefix/include/tcl-tk"
[ -f "$tcl_include/tcl.h" ] || tcl_include="$tcl_prefix/include"
tommath_real_prefix=
if [ -f "$tommath_prefix/lib/libtommath.1.dylib" ]; then tommath_real_prefix=$(cd "$tommath_prefix" && pwd -P); fi
stage="$dist_dir/macos-$output_arch-stage"
client_app="$stage/RetroChat.app"
server_app="$stage/RetroChat Server.app"

wish_path="$tcl_prefix/bin/wish"
tclsh_path="$tcl_prefix/bin/tclsh"
[ -x "$wish_path" ] || wish_path="$tcl_prefix/bin/wish9.0"
[ -x "$tclsh_path" ] || tclsh_path="$tcl_prefix/bin/tclsh9.0"
if [ ! -x "$wish_path" ] || [ ! -x "$tclsh_path" ]; then
    echo "Tcl/Tk was not found at $tcl_prefix" >&2
    exit 1
fi
if ! file "$wish_path" | grep -q "$macos_arch"; then
    echo "Tcl/Tk at $tcl_prefix does not contain the requested $macos_arch architecture" >&2
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
        clang -arch "$macos_arch" -mmacosx-version-min="$deployment_target" -Os -I"$tcl_include" packaging/macos/launcher.c \
            -L"$tcl_prefix/lib" -ltcl9tk9.0 -ltcl9.0 \
            -o "$app/Contents/Resources/runtime/bin/RetroChat"
        runtime_executable=RetroChat
    else
        cp "$tcl_prefix/bin/$executable" "$app/Contents/Resources/runtime/bin/"
        runtime_executable=$executable
    fi
    if file "$tcl_prefix/lib/libtcl9.0.dylib" | grep -q 'universal binary'; then
        lipo "$tcl_prefix/lib/libtcl9.0.dylib" -thin "$macos_arch" -output "$app/Contents/Resources/runtime/lib/libtcl9.0.dylib"
        lipo "$tcl_prefix/lib/libtcl9tk9.0.dylib" -thin "$macos_arch" -output "$app/Contents/Resources/runtime/lib/libtcl9tk9.0.dylib"
    else
        cp "$tcl_prefix/lib/libtcl9.0.dylib" "$app/Contents/Resources/runtime/lib/"
        cp "$tcl_prefix/lib/libtcl9tk9.0.dylib" "$app/Contents/Resources/runtime/lib/"
    fi
    if [ -f "$tommath_prefix/lib/libtommath.1.dylib" ]; then cp "$tommath_prefix/lib/libtommath.1.dylib" "$app/Contents/Resources/runtime/lib/"; fi
    if [ -d "$tcl_prefix/lib/tcl9.0" ]; then
        cp -R "$tcl_prefix/lib/tcl9.0" "$app/Contents/Resources/runtime/lib/"
    else
        cp -R "$tcl_prefix/share/tcl9.0" "$app/Contents/Resources/runtime/lib/"
    fi
    cp -R "$tcl_prefix/lib/tk9.0" "$app/Contents/Resources/runtime/lib/"
    cp -R "$tcl_prefix/lib/tcl9" "$app/Contents/Resources/runtime/lib/"
    cp "$script" "$app/Contents/Resources/app/"
    cp LICENSE "$app/Contents/Resources/LICENSE.txt"
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
        --minimum-deployment-target "$deployment_target" \
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
  <key>LSMinimumSystemVersion</key><string>$deployment_target</string>
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

    # Source-built runtimes retain the temporary prefix used when they were
    # compiled. Discover the recorded paths from each Mach-O rather than
    # assuming they match the directory from which the archive was extracted.
    runtime_binary="$app/Contents/Resources/runtime/bin/$runtime_executable"
    otool -L "$runtime_binary" | awk 'NR > 1 {print $1}' | while IFS= read -r dependency
    do
        case "$dependency" in
            */libtcl9.0.dylib)
                install_name_tool -change "$dependency" @executable_path/../lib/libtcl9.0.dylib "$runtime_binary"
                ;;
            */libtcl9tk9.0.dylib)
                install_name_tool -change "$dependency" @executable_path/../lib/libtcl9tk9.0.dylib "$runtime_binary"
                ;;
        esac
    done
    tk_library="$app/Contents/Resources/runtime/lib/libtcl9tk9.0.dylib"
    otool -L "$tk_library" | awk 'NR > 1 {print $1}' | while IFS= read -r dependency
    do
        case "$dependency" in
            */libtcl9.0.dylib)
                install_name_tool -change "$dependency" @loader_path/libtcl9.0.dylib "$tk_library"
                ;;
        esac
    done
    if [ -f "$app/Contents/Resources/runtime/lib/libtommath.1.dylib" ]; then
      for old_tommath in "$tommath_prefix/lib/libtommath.1.dylib" "$tommath_real_prefix/lib/libtommath.1.dylib"; do
        [ -n "$old_tommath" ] || continue
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
      install_name_tool -id @loader_path/libtommath.1.dylib "$app/Contents/Resources/runtime/lib/libtommath.1.dylib"
      codesign --force --sign - "$app/Contents/Resources/runtime/lib/libtommath.1.dylib"
    fi
    install_name_tool -id @loader_path/libtcl9.0.dylib \
        "$app/Contents/Resources/runtime/lib/libtcl9.0.dylib"
    install_name_tool -id @loader_path/libtcl9tk9.0.dylib \
        "$app/Contents/Resources/runtime/lib/libtcl9tk9.0.dylib"
    codesign --force --sign - "$app/Contents/Resources/runtime/lib/libtcl9.0.dylib"
    codesign --force --sign - "$app/Contents/Resources/runtime/lib/libtcl9tk9.0.dylib"
    codesign --force --sign - "$app/Contents/Resources/runtime/bin/$runtime_executable"
    codesign --force --sign - "$app"
}

make_app "$client_app" wish client.tcl com.retrochat.client RetroChat
make_app "$server_app" wish server-gui.tcl com.retrochat.server "RetroChat Server"

ln -s /Applications "$stage/Applications"
cp LICENSE "$stage/LICENSE.txt"
output="$dist_dir/retrochat-$version-macos-$output_arch.dmg"
rm -f "$output"
hdiutil create -fs HFS+ -format UDZO \
    -volname "RetroChat $version" \
    -srcfolder "$stage" "$output"
rm -rf "$stage"

echo "$output"
