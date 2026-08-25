#!/bin/sh
set -eu

version=${VERSION:-0.0.4}
dist_dir=${DIST_DIR:-dist}
runtime_deb=${LINUX_AMD64_RUNTIME:-packaging/linux-amd64/runtime/tcltk86-bookworm-amd64.deb}
deb_ar=${DEB_AR:-x86_64-w64-mingw32-ar}
work=$(mktemp -d "$dist_dir/.linux-amd64.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
package_root="$work/package"
iso_root="$dist_dir/retrochat-linux-amd64-cd"

mkdir -p "$package_root/DEBIAN" "$package_root/opt/retrochat/lib"
mkdir -p "$package_root/opt/retrochat/assets/icons/png/client"
mkdir -p "$package_root/opt/retrochat/assets/icons/png/server"
mkdir -p "$package_root/usr/bin" "$package_root/usr/share/applications"
mkdir -p "$package_root/usr/share/icons/hicolor/256x256/apps"
mkdir -p "$package_root/usr/share/doc/retrochat"

cp client.tcl server.tcl server-gui.tcl "$package_root/opt/retrochat/"
cp lib/protocol.tcl "$package_root/opt/retrochat/lib/"
sh packaging/normalize-text.sh lf LICENSE "$package_root/opt/retrochat/LICENSE"
sh packaging/normalize-text.sh lf LICENSE "$package_root/usr/share/doc/retrochat/copyright"
cp assets/icons/png/client/client-tray.gif "$package_root/opt/retrochat/assets/icons/png/client/"
cp assets/icons/png/client/client-128.png "$package_root/opt/retrochat/assets/icons/png/client/"
cp assets/icons/png/server/server-tray.gif "$package_root/opt/retrochat/assets/icons/png/server/"
cp assets/icons/png/server/server-128.png "$package_root/opt/retrochat/assets/icons/png/server/"
cp assets/icons/png/client/client-256.png "$package_root/usr/share/icons/hicolor/256x256/apps/retrochat.png"
cp assets/icons/png/server/server-256.png "$package_root/usr/share/icons/hicolor/256x256/apps/retrochat-server.png"

sed "s/@VERSION@/$version/g" packaging/linux-amd64/control.in > "$package_root/DEBIAN/control"
cp packaging/linux-amd64/retrochat packaging/linux-amd64/retrochat-server "$package_root/usr/bin/"
cp packaging/linux-amd64/retrochat.desktop packaging/linux-amd64/retrochat-server.desktop "$package_root/usr/share/applications/"
chmod 755 "$package_root/usr/bin/retrochat" "$package_root/usr/bin/retrochat-server"

mkdir -p "$work/deb"
printf '2.0\n' > "$work/deb/debian-binary"
tar -C "$package_root/DEBIAN" -czf "$work/deb/control.tar.gz" .
rm -rf "$package_root/DEBIAN"
tar -C "$package_root" -czf "$work/deb/data.tar.gz" .
(cd "$work/deb" && "$deb_ar" rc "retrochat-${version}-linux-amd64.deb" debian-binary control.tar.gz data.tar.gz)
mv "$work/deb/retrochat-${version}-linux-amd64.deb" "$dist_dir/"

rm -rf "$iso_root"
mkdir -p "$iso_root"
cp "$runtime_deb" "$iso_root/tcltk86-amd64.deb"
cp "$dist_dir/retrochat-${version}-linux-amd64.deb" "$iso_root/"
cp packaging/linux-amd64/install.sh "$iso_root/INSTALL.SH"
sh packaging/normalize-text.sh lf packaging/linux-amd64/README.txt "$iso_root/README.TXT"
sh packaging/normalize-text.sh lf LICENSE "$iso_root/LICENSE.TXT"
chmod 755 "$iso_root/INSTALL.SH"
rm -f "$dist_dir/retrochat-${version}-linux-amd64.iso"
hdiutil makehybrid -iso -joliet -o "$dist_dir/retrochat-${version}-linux-amd64.iso" "$iso_root"
rm -rf "$iso_root"
rm -f "$dist_dir/retrochat-${version}-linux-amd64.deb"
