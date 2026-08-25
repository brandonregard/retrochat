RetroChat for Classic Mac OS 7/8/9
==================================

The primary releases are self-contained HFS Standard disk images:

  retrochat-0.0.4-macos-68k.img
  retrochat-0.0.4-macos-ppc.img

The Classic Mac release is intentionally architecture-specific. The 68K image
uses the Tcl/Tk 8.0.3 CFM-68K application and matching shared libraries proven
on System 7.5.3. The PPC image uses the standalone Tcl/Tk 8.3.4 PPC runtime
proven on Mac OS 9. Do not combine the applications or runtime files.

On a physical Macintosh, write or copy the matching .img to media supported by
the machine and mount it. In Basilisk II or SheepShaver, attach the matching
.img as a disk. Then double-click RetroChat 0.0.4 Installer. The installer asks
for a destination and creates a RetroChat folder containing the client, server,
and MIT License.

Each image includes only the runtime library set required by its target. A
clean 68K System 7.5.3 installation must first drag the included "CFM-68K
Runtime Enabler" onto its System Folder and restart. The 68K installer copies
its private Tcl/Tk libraries into the RetroChat folder; no system-wide Tcl/Tk
installation is required.

The HFS Standard image preserves every application resource fork and keeps the
68K Tcl/Tk shared libraries beside the installer, where the Code Fragment Manager
can load them before the installer starts. A single MacBinary application is
not a complete 68K installer and is therefore not published as a .sea.bin.

Developers can run:

  make classic-mac-installers

The older architecture-specific development-kit targets remain available for
toolchain and emulator work; they are not end-user installers.
