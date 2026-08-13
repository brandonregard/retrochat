RetroChat Windows 98 SE test kit
================================

This is a compatibility test kit, not an installer. Preserve the directory
layout when extracting it to C:\RETROCHAT.

Recommended first runtime
-------------------------

Install the official Tcl/Tk 8.0.5 Windows self-extracting distribution linked
from https://www.tcl-lang.org/software/tcltk/8.0.html. It supports Windows 95
and Windows NT and includes tclsh, wish, Tcl, and Tk. Windows 98 SE testing is
required before RetroChat can claim a working installer.

Automated checks
----------------

Open an MS-DOS Prompt, change to the extracted directory, and locate Tcl:

  C:
  CD \RETROCHAT
  PATH
  DIR "C:\Program Files\Tcl\bin\tclsh80.exe"

If that file is absent, use Start > Find > Files or Folders to locate
TCLSH80.EXE and WISH80.EXE, then invoke them by full path. For example, replace
C:\Program Files\Tcl below with the actual installation directory:

  "C:\Program Files\Tcl\bin\tclsh80.exe" tests\platform.test
  "C:\Program Files\Tcl\bin\tclsh80.exe" tests\protocol.test

Expected results include a Tcl version/platform line followed by:

  protocol tests passed

Relay test
----------

Open the first MS-DOS Prompt:

  C:
  CD \RETROCHAT
  "C:\Program Files\Tcl\bin\tclsh80.exe" server.tcl 17777

Leave it running. Open a second MS-DOS Prompt:

  C:
  CD \RETROCHAT
  "C:\Program Files\Tcl\bin\tclsh80.exe" tests\relay.test 17777

Expected result:

  relay test passed

GUI test
--------

To use the quit-only server controller, launch:

  "C:\Program Files\Tcl\bin\wish80.exe" server-gui.tcl 17777

Tk 8.0 on Windows 95/98 does not provide the newer native system-tray API, so
the controller is a small window with a Quit button. Then launch two copies of:

  "C:\Program Files\Tcl\bin\wish80.exe" client.tcl

Connect both to localhost port 17777. Test chat in both directions; transfer an
empty file, a text file, and a binary file; decline one transfer; disconnect
and reconnect; then stop the server and confirm both clients report the loss.

Record failures exactly, including the Tcl version from platform.test and any
Windows dialog text. Do not connect Windows 98 directly to the public Internet.
