# Testing every target from an Apple-silicon Mac

This guide assumes macOS 26 on an M2 MacBook Air and a checkout at
`/Users/brandon/retrochat`. Commands beginning with `host$` run in macOS;
commands beginning with `guest$` run inside the emulated system.

## What is being tested

| Target | Method on this host | Level |
| --- | --- | --- |
| macOS 26, arm64 | Native Homebrew Tcl/Tk | Full client and server |
| Ubuntu 24.04, x86-64 | QEMU/UTM emulation or GitHub Actions | Full client and server |
| NetBSD 10.1, amd64 | QEMU/UTM emulation | Full client and server |
| NetBSD 10.1, i386 | QEMU/UTM emulation | Full client and server |
| NetBSD 10.1, mac68k | QEMU Quadra 800 | Full server; client when X/Tk works |
| Windows Server 2025, x86-64 | QEMU/UTM emulation or GitHub Actions | Full client and server |
| Windows 2000, i386 | QEMU/UTM emulation | Compatibility test |
| Windows 98, i386 | QEMU/UTM emulation | Compatibility test |
| Windows 95, i386 | QEMU/UTM emulation | Compatibility test |
| Classic Mac OS 7/8, 68k | Basilisk II | Compatibility test |

Apple silicon can virtualize arm64 guests, but every x86 and m68k target in
this table must be CPU-emulated. Expect installation and booting to be much
slower than an arm64 VM. Use one reusable disk image per target and take a
snapshot after installing the runtime.

Do not commit proprietary Windows media, Windows product keys, classic Mac OS
media, Macintosh ROM images, or prepared guest disks to this repository.

## 1. Prepare the host

Install the native tools. QEMU's official download page lists Homebrew as the
macOS installation method: [Download QEMU](https://www.qemu.org/download/).

```sh
host$ brew install tcl-tk qemu
host$ export PATH="/opt/homebrew/opt/tcl-tk/bin:$PATH"
host$ rehash
host$ cd /Users/brandon/retrochat
host$ command -v qemu-img
host$ qemu-img --version
host$ qemu-system-m68k -machine help | grep q800
host$ qemu-system-x86_64 --version
host$ tclsh tests/protocol.test
```

`command -v qemu-img` must print `/opt/homebrew/bin/qemu-img`. This Mac also has
an old QEMU 2.12 utility bundled with Android SDK at
`~/Library/Android/sdk/emulator/qemu-img`. If `qemu-img --version` still reports
2.12 after installing QEMU with Homebrew, refresh zsh's command cache and check
all candidates:

```sh
host$ rehash
host$ type -a qemu-img
host$ /opt/homebrew/bin/qemu-img --version
```

Use `/opt/homebrew/bin/qemu-img` explicitly if the current shell continues to
select Android's copy. Opening a new Terminal window also clears the cached
command lookup. Do not delete the Android SDK copy because Android Emulator may
need it.

UTM is optional. It provides a friendlier UI around QEMU and is convenient for
interactive OS installation. In UTM, always select **Emulate**, not Virtualize,
for x86 and m68k guests on this M2 host. The command-line tests below do not
depend on UTM.

Create a host directory for legal installation media and mutable VM disks:

```sh
host$ mkdir -p "$HOME/Virtual Machines/RetroChat"
```

Keep that directory outside the repository.

### Installation media and QEMU references

Use these links instead of searching for unofficial repacks:

- [QEMU system-emulation manual](https://www.qemu.org/docs/master/system/)
- [QEMU command-line options](https://www.qemu.org/docs/master/system/qemu-manpage.html)
- [QEMU disk-image and snapshot guide](https://www.qemu.org/docs/master/system/images.html)
- [QEMU networking guide](https://www.qemu.org/docs/master/system/devices/net.html)
- [UTM download](https://getutm.app/) and [UTM documentation](https://docs.getutm.app/)
- [UTM emulated architecture and machine settings](https://docs.getutm.app/settings-qemu/system/)
- [Ubuntu Server 24.04 amd64 download](https://ubuntu.com/download/server?architecture=amd64&lts=true&version=24.04.3)
- [NetBSD 10.1 installation images](https://cdn.netbsd.org/pub/NetBSD/images/10.1/)
- [NetBSD/amd64 installation guide](https://cdn.netbsd.org/pub/NetBSD/NetBSD-10.1/amd64/INSTALL.html)
- [NetBSD/i386 installation guide](https://cdn.netbsd.org/pub/NetBSD/NetBSD-10.1/i386/INSTALL.html)
- [NetBSD/mac68k installation guide](https://cdn.netbsd.org/pub/NetBSD/NetBSD-10.1/mac68k/INSTALL.html)
- [NetBSD pkgsrc package guide](https://www.netbsd.org/docs/pkgsrc/using.html)
- [Windows Server 2025 evaluation ISO](https://www.microsoft.com/en-us/evalcenter/download-windows-server-2025)
- [Magicsplat Tcl/Tk for supported Windows releases](https://www.magicsplat.com/tcl-installer/index.html)

Microsoft does not provide public downloads of Windows 95, 98, or 2000 as
current evaluation products. Use original licensed media and keys. Likewise,
obtain classic Mac OS media and Macintosh ROMs from hardware or media you own;
this guide intentionally provides no unofficial ROM or abandonware links.

Useful QEMU host checks are:

```sh
host$ qemu-system-x86_64 -machine help
host$ qemu-system-i386 -machine help
host$ qemu-system-m68k -machine help
host$ qemu-img --help
```

## 2. Use one acceptance test on every platform

For each target, record the OS version, CPU architecture, and Tcl patch level by
running this command from the RetroChat directory:

```sh
guest$ tclsh tests/platform.test
```

On the macOS host, use `host$ tclsh tests/platform.test`. On Windows, run
`tclsh tests\platform.test` in Command Prompt or PowerShell. The script prints
the same information on old Tcl versions and reports an unknown machine rather
than failing if that runtime does not provide `tcl_platform(machine)`.

Then perform this checklist:

1. Run `tests/protocol.test`; expect `protocol tests passed`.
2. Start `server.tcl` on port 17777.
3. Run `tests/relay.test 17777`; expect `relay test passed`.
4. Start two GUI clients and connect both to `localhost:17777`.
5. Send chat in both directions, including spaces and non-ASCII text.
6. Transfer an empty file, a small text file, and a binary file containing zero
   bytes. Confirm byte-for-byte equality at the destination.
7. Decline one incoming file and confirm both clients remain usable.
8. Disconnect and reconnect each client.
9. Stop the server during a connection and confirm the clients report the loss.

On Unix guests, steps 1 through 3 are:

```sh
guest$ cd retrochat
guest$ tclsh tests/platform.test
guest$ tclsh tests/protocol.test
guest$ tclsh server.tcl 17777 >server.log 2>&1 &
guest$ server_pid=$!
guest$ tclsh tests/relay.test 17777
guest$ kill "$server_pid"
guest$ wish client.tcl
```

For old systems lacking SSH or Git, create the appropriate archive on the host,
attach it as read-only CD media, and copy it to the guest disk:

```sh
host$ make netbsd-mac68k
```

## 3. Native macOS 26/arm64

Run the automated checks:

```sh
host$ cd /Users/brandon/retrochat
host$ /opt/homebrew/opt/tcl-tk/bin/tclsh tests/platform.test
host$ /opt/homebrew/opt/tcl-tk/bin/tclsh tests/protocol.test
host$ /opt/homebrew/opt/tcl-tk/bin/tclsh server.tcl 17777 > /tmp/retrochat-server.log 2>&1 &
host$ retrochat_server_pid=$!
host$ /opt/homebrew/opt/tcl-tk/bin/tclsh tests/relay.test 17777
host$ kill "$retrochat_server_pid"
```

For the GUI test, open three terminals. Run the server in the first and one
client in each of the other two:

```sh
host$ /opt/homebrew/opt/tcl-tk/bin/tclsh server.tcl 7777
host$ /opt/homebrew/opt/tcl-tk/bin/wish client.tcl
host$ /opt/homebrew/opt/tcl-tk/bin/wish client.tcl
```

Complete the acceptance checklist and save the Tcl/Tk versions in the test log.

## 4. Modern x86 guests: Ubuntu, NetBSD, and Windows Server

Use UTM for the simplest interactive installation:

1. Create a new VM and choose **Emulate**.
2. Select `x86_64` for Ubuntu 24.04, NetBSD/amd64, or Windows Server 2025.
3. Give the guest 2 CPU cores. Use 4 GB RAM for Ubuntu/Windows and 1 GB for
   NetBSD. Keep macOS responsive by not allocating all host memory.
4. Create a 20 GB disk for Ubuntu/NetBSD or a 64 GB disk for Windows Server.
5. Attach the official installation ISO and enable shared networking.
6. Install the OS, enable SSH where supported, shut down, and clone or snapshot
   the clean disk.

### Ubuntu 24.04/x86-64

Download the official
[Ubuntu Server 24.04 amd64 ISO](https://ubuntu.com/download/server?architecture=amd64&lts=true&version=24.04.3),
attach it to the emulated CD drive, and install Ubuntu. Inside the guest:

```sh
guest$ sudo apt update
guest$ sudo apt install -y git tcl tk xvfb
guest$ git clone YOUR_REPOSITORY_URL retrochat
guest$ cd retrochat
guest$ uname -m
guest$ tclsh tests/platform.test
guest$ tclsh tests/protocol.test
guest$ tclsh server.tcl 17777 >server.log 2>&1 &
guest$ server_pid=$!
guest$ tclsh tests/relay.test 17777
guest$ kill "$server_pid"
guest$ wish client.tcl
```

`uname -m` must report `x86_64`; otherwise this is not the requested target.

### NetBSD 10.1/amd64

Download the official
[`NetBSD-10.1-amd64.iso`](https://cdn.netbsd.org/pub/NetBSD/images/10.1/NetBSD-10.1-amd64.iso).
During installation enable DHCP, SSH, and binary packages. After reboot:

```sh
guest$ uname -a
guest$ uname -m
guest$ su -
guest# pkgin update
guest# pkgin install tcl tk git
guest# exit
guest$ git clone YOUR_REPOSITORY_URL retrochat
guest$ cd retrochat
guest$ tclsh tests/platform.test
```

`uname -m` must report `amd64`. Run the Unix acceptance commands from section 2.
For GUI testing, install/configure X11 during installation and run `wish` from an
X terminal. A successful command-line relay test alone does not validate Tk.

### Windows Server 2025/x86-64

Download Microsoft's official
[Windows Server 2025 evaluation ISO](https://www.microsoft.com/en-us/evalcenter/download-windows-server-2025).
The existing GitHub Actions workflow is the preferred repeatable test. Trigger
the `Verify` workflow and require the `Protocol — windows-2025` matrix entry to
pass. For a local VM:

1. Install Windows Server from licensed Microsoft media.
2. Install the x64
   [Magicsplat Tcl/Tk distribution](https://www.magicsplat.com/tcl-installer/index.html).
3. Copy or clone RetroChat into `C:\retrochat`.
4. Open PowerShell and locate the interpreter:

```powershell
Get-Command tclsh*.exe
Get-Command wish*.exe
cd C:\retrochat
tclsh tests\platform.test
tclsh tests\protocol.test
Start-Process tclsh -ArgumentList "server.tcl", "17777"
tclsh tests\relay.test 17777
wish client.tcl
```

Start a second `wish client.tcl`, complete the acceptance checklist, then stop
the server in Task Manager or with `Stop-Process`.

## 5. NetBSD 10.1/i386

Create another UTM **Emulate** VM with architecture `i386`, 512 MB RAM, an 8 GB
IDE disk, an IDE CD-ROM, and shared networking. Attach the official
[`NetBSD-10.1-i386.iso`](https://cdn.netbsd.org/pub/NetBSD/images/10.1/NetBSD-10.1-i386.iso)
and install with DHCP, SSH, X11, and binary packages.

After reboot:

```sh
guest$ uname -m
guest$ su -
guest# pkgin update
guest# pkgin install tcl tk git
guest# exit
guest$ git clone YOUR_REPOSITORY_URL retrochat
guest$ cd retrochat
guest$ tclsh tests/platform.test
```

`uname -m` must report `i386`. Run the Unix acceptance commands from section 2.
If no suitable binary Tcl/Tk package exists, install pkgsrc and build `lang/tcl`
and `x11/tk`; record the pkgsrc branch and build result.

## 6. NetBSD 10.1/mac68k in QEMU

This is the exact 68k NetBSD target. The Homebrew QEMU installed on this host
supplies the `q800` machine. The official NetBSD process boots through classic
Mac OS, so you must provide a legally obtained Quadra-compatible ROM and
bootable classic Mac OS disk. The repository cannot supply either.

Prepare working copies, preserving originals:

```sh
host$ cd "$HOME/Virtual Machines/RetroChat"
host$ cp /path/to/your/Quadra800.rom ./Quadra800.rom
host$ cp /path/to/your/classic-mac-system.qcow2 ./netbsd-mac68k.qcow2
host$ curl -O https://cdn.netbsd.org/pub/NetBSD/images/10.1/NetBSD-10.1-mac68k.iso
```

The image comes from the official
[NetBSD 10.1 image directory](https://cdn.netbsd.org/pub/NetBSD/images/10.1/),
and installation details are in the official
[NetBSD/mac68k INSTALL guide](https://cdn.netbsd.org/pub/NetBSD/NetBSD-10.1/mac68k/INSTALL.html).

Boot the Quadra with conservative settings:

```sh
host$ qemu-system-m68k \
  -M q800 \
  -m 128 \
  -bios Quadra800.rom \
  -drive file=netbsd-mac68k.qcow2,format=qcow2 \
  -cdrom NetBSD-10.1-mac68k.iso \
  -nic user,model=dp83932 \
  -audio driver=none
```

If this QEMU build rejects the explicit NIC model, omit `-nic` and inspect the
default q800 devices with `qemu-system-m68k -M q800 -device help`. Do not assume
networking works until NetBSD shows an interface and DHCP succeeds.

In classic Mac OS, install the NetBSD/mac68k Booter from the official 10.1
`mac68k/installation/misc` directory. Follow the official mac68k INSTALL guide:

1. Select the installation kernel in Booter.
2. Use black-and-white video if color booting fails.
3. Boot sysinst and install NetBSD onto a dedicated NetBSD partition/disk.
4. Enable networking, SSH, X11, and binary packages where available.
5. Reboot through Booter using the installed kernel.

In NetBSD, verify the exact platform:

```sh
guest$ uname -a
guest$ uname -m
guest$ sysctl hw.model
guest$ cd retrochat
guest$ tclsh tests/platform.test
```

Build the packages on the host and transfer them by SSH, an ISO, or an HFS disk:

```sh
host$ cd /Users/brandon/retrochat
host$ make netbsd-mac68k
```

Install Tcl/Tk using pkgin when packages exist. Otherwise use pkgsrc
`lang/tcl` and `x11/tk`. Extract each archive and run `./retrochat-server 17777`
or `./retrochat-client`. Run `tests/protocol.test` and `tests/relay.test` from a
full source copy as well. The GUI requires a functioning NetBSD X server.

Take two results separately: **mac68k server/protocol passed** and **mac68k Tk
client passed**. Do not mark the second passed based only on command-line tests.

## 7. Windows 2000, 98, and 95/i386

Create three independent UTM **Emulate** VMs using `i386`. Use licensed media
and valid keys. A practical conservative configuration is one emulated Pentium
CPU, 128 MB RAM for Windows 2000, 64 MB for Windows 98, and 32 MB for Windows 95.
Use IDE disks and an emulated RTL8139 or NE2000-compatible network adapter for
which the guest has a driver. Save a clean snapshot before installing Tcl/Tk.

For each VM:

1. Install the OS and its available service packs/updates from trusted offline
   media. Do not expose these unsupported systems directly to the Internet.
2. Configure QEMU user-mode/NAT networking or an isolated host-only network.
3. Install a Tcl/Tk 8.4-era i386 runtime. If testing the minimum promise, also
   test Tcl/Tk 8.0 where obtainable.
4. Copy RetroChat through a read-only ISO or emulator shared disk. Avoid Git and
   modern TLS downloads inside the guest.
5. Open the Tcl shell, `cd` to the copied source, and run:

```tcl
source tests/platform.test
source tests/protocol.test
```

6. Start the server with `tclsh server.tcl 17777`, open a second command window,
   and run `tclsh tests/relay.test 17777`.
7. Start two clients with `wish client.tcl` and complete the acceptance list.

Windows 95/98/2000 do not have a native amd64 userland. Record these results as
`i386`, even though the physical Mac host is arm64.

### Immediate Windows 98 SE test

For an already-installed Windows 98 SE guest, build a single transfer ZIP:

```sh
host$ cd /Users/brandon/retrochat
host$ make windows98-test-kit
```

Transfer `dist/retrochat-0.0.3-windows98-test-kit.zip` through a read-only UTM
shared directory or CD image, extract it to `C:\RETROCHAT`, and follow its
`README.txt`. Begin with the official
[Tcl/Tk 8.0.5 Windows installer](https://www.tcl-lang.org/software/tcltk/8.0.html),
which explicitly targets Windows 95/NT and bundles Tcl and Tk. Treat Windows 98
SE support as unverified until all tests pass in the guest.

For the most reliable offline transfer, download `tcl805.exe` from that official
page and build a ready-to-attach ISO containing the installer and unpacked test
kit:

```sh
host$ make windows98-test-iso TCL805_INSTALLER="$HOME/Downloads/tcl805.exe"
```

Attach `dist/retrochat-0.0.3-windows98-test.iso` to the Windows 98 VM's CD/DVD
drive. This avoids depending on Windows 98 ZIP support or Internet access.

## 8. Classic Mac OS 7/8, 68k

Use Basilisk II with a legally obtained Macintosh ROM and licensed System 7.x
or Mac OS 8.0/8.1 media. Basilisk II emulates a 68040 Macintosh; it does not run
Mac OS 8.5 or later because those releases require PowerPC.

1. Create a writable HFS disk in Basilisk II and install System 7.5.5 or Mac OS
   8.1.
2. Configure Basilisk II networking, or use its host-directory sharing for file
   transfer.
3. Install a classic 68k Tcl/Tk 8.0 distribution.
4. Copy `client.tcl`, `server.tcl`, `lib/protocol.tcl`, and the tests while
   preserving their directory layout.
5. Run `source tests:platform.test`, then `source tests:protocol.test`, from Tcl.
   Classic Mac path separators may be displayed as colons even though the
   scripts use portable `file join` calls.
6. Start the relay in a Tcl shell and two client instances in Wish.
7. Complete the acceptance list, especially binary transfer and save dialogs.
8. Record whether resource forks survive. RetroChat promises only data-fork
   transfer, so loss of resource-fork metadata is an expected limitation.

If the classic Tcl/Tk runtime cannot provide sockets or Tk reliably, record the
exact runtime build and failure. That is a compatibility finding, not a reason
to substitute a modern PowerPC or macOS runtime.

## 9. Record results

Create one row per tested runtime:

| Date | OS | Guest CPU | Emulator/version | Tcl/Tk | Protocol | Relay | GUI/chat | Files | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| YYYY-MM-DD | NetBSD 10.1/mac68k | m68k | QEMU q800 | 8.x | PASS/FAIL | PASS/FAIL | PASS/FAIL | PASS/FAIL | issue link |

A platform is fully passed only when the architecture is verified, protocol and
relay tests pass, two clients exchange chat, and binary file comparison passes.
Keep emulator screenshots and logs as CI artifacts or issue attachments, not in
the source tree unless they are intentionally curated documentation.

## 10. Recommended execution order

1. Native macOS 26/arm64.
2. Existing GitHub Actions: Ubuntu, macOS, Windows Server, NetBSD/amd64.
3. NetBSD 10.1/amd64 locally.
4. NetBSD 10.1/i386 locally.
5. Ubuntu 24.04/x86-64 locally only if CI is insufficient.
6. Windows Server 2025 locally only if GUI validation is required.
7. Windows 2000, then Windows 98, then Windows 95.
8. Classic Mac OS 8.1/68k.
9. NetBSD 10.1/mac68k server, then its X11/Tk client.

This order finds application defects quickly before spending time debugging
installation media, ROM compatibility, old drivers, and emulated networking.

## 11. Windows 98 installer and macOS-hosted server

Build the complete ANSI MSI installer:

```sh
host$ cd /Users/brandon/retrochat
host$ make windows95-installer \
  TCL805_INSTALLER="$HOME/Downloads/tcl805.exe"
```

Transfer `dist/retrochat-0.0.3-windows-i386-setup.exe` to the VM using a shared
folder or removable image. In Windows 98, double-click the Setup EXE and accept
RetroChat's default directory. Do not use the amd64 MSI on Windows 98. The i386
MSI is an alternative only when Windows Installer is already installed.
When the embedded Tcl/Tk installer opens, accept its default
`C:\Program Files\Tcl` directory; the shortcuts depend on that location. Setup
creates **RetroChat Client** on the desktop and client/server shortcuts under
Start > Programs > RetroChat. The uninstaller removes RetroChat and offers to
remove the shared Tcl/Tk runtime separately.

To test a Windows client against the macOS server:

1. In UTM, ensure the VM network mode is **Emulated VLAN** or **Shared Network**,
   not disconnected or host-isolated.
2. In Windows 98, choose Start > Run, enter `winipcfg`, select the installed
   Ethernet adapter, and record its IP address and Default Gateway.
3. With QEMU user networking, the guest is normally `10.0.2.15` and the macOS
   host is reachable as `10.0.2.2`. Confirm with `ping 10.0.2.2` in an MS-DOS
   Prompt. If UTM shows a different Default Gateway, use that gateway address.
4. On macOS, start the server and leave the Terminal window open:

   ```sh
   host$ cd /Users/brandon/retrochat
   host$ /opt/homebrew/opt/tcl-tk/bin/tclsh server.tcl 7777
   ```

5. If macOS asks whether `tclsh` may accept incoming connections, click Allow.
6. In Windows 98, open RetroChat Client. Set Host to `10.0.2.2` (or the Default
   Gateway recorded above), Port to `7777`, choose a nickname, and click Connect.
7. On macOS, start the native client:

   ```sh
   host$ cd /Users/brandon/retrochat
   host$ /opt/homebrew/opt/tcl-tk/bin/wish client.tcl
   ```

8. Connect the macOS client to `localhost`, port `7777`.
9. Exchange chat both ways, then send a GIF from macOS to Windows and back.
   Compare file sizes on both systems and open both received files.

If Windows cannot connect, first verify that the macOS server printed
`RetroChat server listening on port 7777`. Then test the gateway with `ping`,
check the macOS firewall prompt/settings, and confirm UTM did not switch the VM
to an isolated network. QEMU documents `10.0.2.2` as the host/router address for
its default [user-mode network](https://www.qemu.org/docs/master/system/devices/net.html#using-the-user-mode-network-stack).
