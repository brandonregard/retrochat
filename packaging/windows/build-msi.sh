#!/bin/sh
set -eu

for tool in tclsh wixl msiinfo; do
    command -v "$tool" >/dev/null 2>&1 || {
        echo "Windows MSI build requires $tool." >&2
        exit 1
    }
done

arch=${1:?usage: build-msi.sh i386|amd64}
case "$arch" in
    i386) wix_arch=x86; upgrade_code=8B042ED6-8304-4A45-967B-68BE2D2F3861 ;;
    amd64) wix_arch=x64; upgrade_code=4E0534B8-0D15-4DDD-8182-B1BFD1A68164 ;;
    *) echo "unsupported Windows MSI architecture: $arch" >&2; exit 2 ;;
esac

version=${VERSION:-0.0.4}
dist_dir=${DIST_DIR:-dist}
work=$(mktemp -d "$dist_dir/.windows-$arch-msi.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
stage="$work/payload"
mkdir -p "$stage/lib" "$stage/assets/icons/png/client" \
    "$stage/assets/icons/png/server" "$stage/assets/icons/windows"

cp client.tcl server.tcl server-gui.tcl "$stage/"
cp lib/protocol.tcl "$stage/lib/"
sh packaging/normalize-text.sh crlf LICENSE "$stage/LICENSE.txt"
cp assets/icons/png/client/client-tray.gif assets/icons/png/client/client-128.png "$stage/assets/icons/png/client/"
cp assets/icons/png/server/server-tray.gif assets/icons/png/server/server-128.png "$stage/assets/icons/png/server/"
cp assets/icons/windows/client.ico assets/icons/windows/server.ico "$stage/assets/icons/windows/"

if [ "$arch" = i386 ]; then
    cp "$dist_dir/RetroChat-client.exe" "$stage/"
    cp "$dist_dir/RetroChat-server.exe" "$stage/"
    cp "${TCL805_INSTALLER:?TCL805_INSTALLER is required}" "$stage/tcl805.exe"
else
    cp "$dist_dir/RetroChat-amd64-client.exe" "$stage/RetroChat-client.exe"
    cp "$dist_dir/RetroChat-amd64-server.exe" "$stage/RetroChat-server.exe"
    cp -R "$dist_dir/windows-amd64-runtime" "$stage/runtime"
fi

runtime_actions=
runtime_sequence=
if [ "$arch" = i386 ]; then
    runtime_actions="<CustomAction Id=\"InstallTcl805\" FileKey=\"Tcl805InstallerFile\" ExeCommand=\"\" Execute=\"deferred\" Return=\"check\" Impersonate=\"yes\" />"
    runtime_sequence="<InstallExecuteSequence>
      <Custom Action=\"InstallTcl805\" After=\"InstallFiles\">NOT Installed</Custom>
    </InstallExecuteSequence>"
fi

tclsh packaging/windows/heat.tcl "$stage" "$work/payload.wxs" "$arch"

cat > "$work/retrochat.wxs" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<Wix xmlns="http://schemas.microsoft.com/wix/2006/wi">
  <Product Id="*" Name="RetroChat" Language="1033" Version="$version"
           Manufacturer="Brandon Regard" UpgradeCode="{$upgrade_code}">
    <Package InstallerVersion="200" Compressed="yes" InstallScope="perMachine"
             Description="RetroChat client and server" />
    <MediaTemplate EmbedCab="yes" />
    <MajorUpgrade DowngradeErrorMessage="A newer RetroChat version is already installed." />
    <Icon Id="RetroChatClientIcon" SourceFile="assets/icons/windows/client.ico" />
    <Property Id="ARPPRODUCTICON" Value="RetroChatClientIcon" />
    $runtime_actions
    <Directory Id="TARGETDIR" Name="SourceDir">
      <Directory Id="ProgramFilesFolder"><Directory Id="INSTALLDIR" Name="RetroChat" /></Directory>
      <Directory Id="ProgramMenuFolder"><Directory Id="ProgramMenuDir" Name="RetroChat" /></Directory>
      <Directory Id="DesktopFolder" />
    </Directory>
    <DirectoryRef Id="ProgramMenuDir">
      <Component Id="MenuShortcuts" Guid="*">
        <Shortcut Id="ClientMenuShortcut" Name="RetroChat Client" Target="[INSTALLDIR]RetroChat-client.exe" WorkingDirectory="INSTALLDIR" />
        <Shortcut Id="ServerMenuShortcut" Name="RetroChat Server" Target="[INSTALLDIR]RetroChat-server.exe" WorkingDirectory="INSTALLDIR" />
        <RemoveFolder Id="RemoveProgramMenuDir" On="uninstall" />
        <RegistryValue Root="HKLM" Key="Software\RetroChat" Name="MenuShortcuts" Type="integer" Value="1" KeyPath="yes" />
      </Component>
    </DirectoryRef>
    <DirectoryRef Id="DesktopFolder">
      <Component Id="DesktopShortcut" Guid="*">
        <Shortcut Id="ClientDesktopShortcut" Name="RetroChat Client" Target="[INSTALLDIR]RetroChat-client.exe" WorkingDirectory="INSTALLDIR" />
        <RegistryValue Root="HKLM" Key="Software\RetroChat" Name="DesktopShortcut" Type="integer" Value="1" KeyPath="yes" />
      </Component>
    </DirectoryRef>
    <Feature Id="Complete" Title="RetroChat" Level="1">
      <ComponentGroupRef Id="Payload" /><ComponentRef Id="MenuShortcuts" /><ComponentRef Id="DesktopShortcut" />
    </Feature>
    $runtime_sequence
  </Product>
</Wix>
EOF

output="$dist_dir/retrochat-$version-windows-$arch.msi"
rm -f "$output"
wixl -a "$wix_arch" -D PayloadDir="$stage" -o "$output" "$work/retrochat.wxs" "$work/payload.wxs"
test -s "$output"
msiinfo export "$output" Property | grep -q "ProductName.*RetroChat"
msiinfo export "$output" File | grep -qi "RetroChat-client.exe"
msiinfo export "$output" File | grep -qi "RetroChat-server.exe"
msiinfo export "$output" Shortcut | grep -q "RetroChat Client"
echo "$output"
