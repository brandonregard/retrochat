RetroChat for Classic Mac OS 7/8/9
==================================

The primary release is the hybrid HFS/ISO installer disc:

  retrochat-0.0.1-macos-classic-fat.iso

Mount or burn the image, then
double-click RetroChat 0.0.1 Installer. The installer asks for a destination
and creates a RetroChat folder containing the client, server, and Read Me.

The Installer, client, and server are fat applications. Each contains both
68K CODE resources and a PowerPC PEF executable. No separate Tcl/Tk install
is required.

The matching .hfv is an HFS Standard disk image for emulators. The .bin file
is the same Installer application in MacBinary II form for transfer through
filesystems that do not preserve resource forks.

Developers can run:

  make classic-mac-fat-installer

The older architecture-specific development-kit targets remain available for
toolchain and emulator work; they are not end-user installers.
