# Building RetroChat distributions

This document describes how to reproduce every RetroChat installer from a
normal terminal. Codex, ChatGPT, and other AI tools are not required.

## Build host

The complete release pipeline currently runs on macOS. It uses Apple tools for
DMG creation, icon processing, application asset catalogs, and Classic Mac
resource forks. A Linux or Windows host can run and test the Tcl source, but it
cannot run the complete `make installers` target without replacing those
macOS-specific parts of the packaging pipeline.

The commands below have been exercised on Apple silicon. They also build the
x86_64 macOS, Windows, Linux, NetBSD/mac68k, and Classic Mac artifacts; the
target architecture does not have to match the build host architecture.

## 1. Check out the complete source tree

Clone the repository and enter it:

```sh
git clone https://github.com/brandonregard/retrochat.git
cd retrochat
```

Do not omit the files under the platform `runtime` directories. The installers
are self-contained because these inputs supply the Tcl/Tk runtimes needed by
the destination systems:

```text
packaging/classic-mac/runtime/
packaging/linux-amd64/runtime/
packaging/macos/runtime/
packaging/netbsd/runtime/
packaging/windows-amd64/runtime/
packaging/windows98/runtime/
```

## 2. Install host build tools

Install full Xcode and accept its license. The command-line tools alone may not
include `actool`, which is required for modern macOS application icons.

```sh
xcode-select -p
xcrun --find actool
xcrun --find clang
```

Install the open-source packaging tools with Homebrew:

```sh
brew install \
  cdrtools \
  ffmpeg \
  hfsutils \
  libicns \
  libtommath \
  mingw-w64 \
  msitools \
  tcl-tk \
  unar
```

Make Homebrew Tcl/Tk available to `make`:

```sh
export PATH="$(brew --prefix tcl-tk)/bin:$PATH"
```

The Classic Mac builder also requires the Apple tools `Rez`, `DeRez`,
`SetFile`, `GetFileInfo`, and `macbinary`. Verify the complete tool set before
building:

```sh
for command in \
  codesign DeRez ffmpeg GetFileInfo hcopy hformat hls hmount humount \
  iconv install_name_tool macbinary mkisofs png2icns Rez SetFile sips tclsh \
  unar wixl xcrun x86_64-w64-mingw32-gcc i686-w64-mingw32-gcc
do
  command -v "$command" >/dev/null || echo "Missing: $command"
done
```

No output from that loop means the tools were found.

## 3. Verify source and runtime inputs

Run the source tests first:

```sh
make test
```

Confirm that all required prebuilt runtimes are present:

```sh
test -f packaging/windows98/runtime/tcl805.exe
test -f packaging/windows-amd64/runtime/tcltk86-win10-amd64.tgz
test -f packaging/linux-amd64/runtime/tcltk86-bookworm-amd64.deb
test -f packaging/macos/runtime/tcltk9-macos-universal.tgz
test -f packaging/classic-mac/runtime/mactk8.0.3.sea.hqx
test -f packaging/classic-mac/runtime/CFM-68K-Runtime-Enabler.bin
test -f packaging/classic-mac/runtime/SimpleTkPPC.bin
test -f packaging/netbsd/runtime/tcl-8.6.16nb2.tgz
test -f packaging/netbsd/runtime/tk-8.6.16.tgz
```

The x86_64 macOS runtime is the only input with a supported source bootstrap.
If its archive is missing, this command downloads the pinned Tcl/Tk sources,
checks their SHA-256 hashes, and builds it:

```sh
make macos-amd64-runtime
```

The other historical or cross-platform runtime files must already be present.
Do not replace them with a runtime for a different CPU or operating-system
generation.

## 4. Build one target

Each target below can be built independently.

| Distribution | Command | Primary output |
| --- | --- | --- |
| macOS arm64 | `make macos-installer` | `dist/retrochat-0.0.3-macos-arm64.dmg` |
| macOS x86_64/amd64 | `make macos-amd64-installer` | `dist/retrochat-0.0.3-macos-amd64.dmg` |
| Windows 95/98 i386 | `make windows95-installer` | `dist/retrochat-0.0.3-windows-i386-setup.exe` and `.msi` |
| Windows 10+ amd64 | `make windows-amd64-installer` | `dist/retrochat-0.0.3-windows-amd64.msi` |
| Debian-compatible Linux amd64 | `make linux-amd64-installer-iso` | `dist/retrochat-0.0.3-linux-amd64.iso` |
| NetBSD 10.1/mac68k | `make netbsd-mac68k-installer` | `dist/retrochat-0.0.3-netbsd-mac68k.iso` |
| Classic Mac OS 68K | `make classic-mac-68k-installer` | `dist/retrochat-0.0.3-macos-68k.iso` |
| Classic Mac OS PowerPC | `make classic-mac-ppc-installer` | `dist/retrochat-0.0.3-macos-ppc.iso` |
| Both Classic Mac architectures | `make classic-mac-installers` | both Classic Mac hybrid CDs |

The version in filenames comes from `VERSION` at the top of the Makefile. To
build another version without editing the file, pass it on the command line:

```sh
make VERSION=0.0.3 macos-installer
```

To place results somewhere other than `dist`, set `DIST_DIR`:

```sh
make VERSION=0.0.3 DIST_DIR=release-build windows-amd64-installer
```

## 5. Build the complete release set

Remove prior output, run the tests, and build every supported installer:

```sh
make clean
make test
make installers
```

For version 0.0.3, a successful complete build produces:

```text
dist/retrochat-0.0.3-linux-amd64.iso
dist/retrochat-0.0.3-macos-68k.iso
dist/retrochat-0.0.3-macos-amd64.dmg
dist/retrochat-0.0.3-macos-arm64.dmg
dist/retrochat-0.0.3-macos-ppc.iso
dist/retrochat-0.0.3-netbsd-mac68k.iso
dist/retrochat-0.0.3-windows-amd64.msi
dist/retrochat-0.0.3-windows-i386-setup.exe
dist/retrochat-0.0.3-windows-i386.msi
```

The Classic Mac `.iso` files are ISO 9660/HFS Standard hybrid CDs intended for
both physical machines and Basilisk II or SheepShaver. The builder uses a
temporary HFS image to validate each CD, but does not publish `.hfv` files.

## 6. Runtime-path overrides

The Makefile accepts alternate runtime locations when reproducing a build from
an archival mirror or another workstation:

```sh
make windows95-installer \
  TCL805_INSTALLER=/absolute/path/to/tcl805.exe

make windows-amd64-installer \
  WINDOWS_AMD64_RUNTIME=/absolute/path/to/tcltk86-win10-amd64.tgz

make linux-amd64-installer-iso \
  LINUX_AMD64_RUNTIME=/absolute/path/to/tcltk86-bookworm-amd64.deb

make macos-amd64-installer \
  MACOS_AMD64_RUNTIME=/absolute/path/to/tcltk9-macos-universal.tgz
```

The modern arm64 macOS build defaults to Homebrew's Apple-silicon prefixes. If
Homebrew is installed elsewhere, call the build script with explicit paths:

```sh
VERSION=0.0.3 \
TCL_PREFIX="$(brew --prefix tcl-tk)" \
TOMMATH_PREFIX="$(brew --prefix libtommath)" \
sh packaging/macos/build.sh
```

Classic Mac runtime inputs can likewise be overridden with
`CLASSIC_MAC_PPC_STUB`, `CLASSIC_MAC_CFM_68K`, and
`CLASSIC_MAC_68K_RUNTIME` when invoking the relevant script.

## 7. Basic artifact verification

Check image types and hashes after a build:

```sh
file dist/*
shasum -a 256 dist/*
```

Verify the two modern macOS disk images:

```sh
hdiutil verify dist/retrochat-0.0.3-macos-arm64.dmg
hdiutil verify dist/retrochat-0.0.3-macos-amd64.dmg
```

List the Macintosh view of a Classic Mac hybrid CD:

```sh
hmount dist/retrochat-0.0.3-macos-68k.iso
hls -la
humount
```

The Classic Mac build itself fails if the application resources, Finder type,
color icons, transparency masks, About-dialog icon layers, or bundled 68K
runtime files are missing. The icon build likewise fails if the master PNGs or
generated PNGs lack alpha channels.

For installation and emulator acceptance testing, continue with
[EMULATOR_TESTING.md](EMULATOR_TESTING.md).

## Common failures

`xcrun: error: unable to find utility "actool"` means full Xcode is missing or
the active developer directory is wrong. Select Xcode with:

```sh
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
```

`Missing ... runtime` means the checkout does not contain a required bundled
runtime or an override points to the wrong file. Restore the named file; do not
substitute a runtime from another architecture.

Classic Mac failures mentioning `Rez`, `SetFile`, `hformat`, or `mkisofs` mean
the Xcode or Homebrew prerequisites in section 2 are incomplete.

Windows launcher failures mentioning `windres` or a MinGW compiler require the
Homebrew `mingw-w64` package. MSI failures mentioning `wixl` or `msiinfo`
require `msitools`.
