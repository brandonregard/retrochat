RetroChat @VERSION@ for Classic Mac OS
==================================

This release is architecture-specific. Use the 68K image on 68K Macintosh
computers and the PPC image on PowerPC Macintosh computers running Mac OS 7,
Mac OS 8, or Mac OS 9.

RetroChat Client connects to a RetroChat server. RetroChat Server listens on
TCP port 7777 by default and provides a small controller window with a Quit
button.

PowerPC Macs need no separate Tcl/Tk installation. The 68K and PPC releases
are different applications; use only the image matching the processor.

IMPORTANT FOR 68K SYSTEM 7 MACS
-------------------------------
The 68K Tcl/Tk 8.0.3 runtime requires Apple's CFM-68K Runtime Enabler, which is
not included with a clean System 7.5.3 installation.

1. Drag "CFM-68K Runtime Enabler" from this disc onto the closed System
   Folder icon on your startup disk.
2. Accept the Finder's request to place it in the Extensions folder.
3. Restart the Macintosh.
4. Run "RetroChat @VERSION@ Installer 68k". It uses the Tcl/Tk 8.0.3 68K
   runtime and private libraries included on this disc.

The required extension and application-local Tcl/Tk libraries are included;
no separate Tcl/Tk installation or download is required. PowerPC users run
"RetroChat @VERSION@ Installer ppc" directly.
