RetroChat for Classic Mac OS 7/8/9
==================================

The primary release is the hybrid HFS/ISO installer disc:

  retrochat-0.0.2-macos-68k.iso
  retrochat-0.0.2-macos-ppc.iso

The Classic Mac release is intentionally architecture-specific. The 68K image
uses the Tcl/Tk 8.0.3 CFM-68K application and matching shared libraries proven
on System 7.5.3. The PPC image uses the standalone Tcl/Tk 8.3.4 PPC runtime
proven on Mac OS 9. Do not combine the applications or runtime files.

Mount or burn the image, then
double-click RetroChat 0.0.2 Installer. The installer asks for a destination
and creates a RetroChat folder containing the client, server, and Read Me.

Each image includes only the runtime library set required by its target. A
clean 68K System 7.5.3 installation must first drag the included "CFM-68K
Runtime Enabler" onto its System Folder and restart. The 68K installer copies
its private Tcl/Tk libraries into the RetroChat folder; no system-wide Tcl/Tk
installation is required.

The matching .hfv is an HFS Standard disk image for emulators. The .bin file
is the same Installer application in MacBinary II form for transfer through
filesystems that do not preserve resource forks.

Developers can run:

  make classic-mac-installers

The older architecture-specific development-kit targets remain available for
toolchain and emulator work; they are not end-user installers.
