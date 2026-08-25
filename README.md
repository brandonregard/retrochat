# RetroChat

RetroChat is a small chat and file-transfer system written in Tcl/Tk. Its first
milestone is deliberately simple: one relay server, many desktop clients, chat
messages, and user-approved file saves.

**Alpha Codex Release. Codename: Save Ferris**

![Ferris Bueller saying "Never had one lesson."](assets/0.0.1-save_ferris.gif)

## Run it

Requires Tcl/Tk 8.0 or newer.

```sh
tclsh server.tcl 7777
wish client.tcl
```

Enter the server address, port, and a nickname, then connect. Run another client
to chat or transfer a file. The server listens on all interfaces; allow TCP port
7777 through the host firewall when using separate machines.

Run the protocol tests with:

```sh
tclsh tests/platform.test
tclsh tests/protocol.test
```

See [docs/PLATFORMS.md](docs/PLATFORMS.md) for tested operating systems,
runtime requirements, and platform-specific notes. For a complete host-specific
procedure, see [docs/EMULATOR_TESTING.md](docs/EMULATOR_TESTING.md).

## Portability strategy

The source uses Tcl 8.0-era constructs and standard Tk widgets. All protocol
fields, including file chunks, are hexadecimal, so the relay remains safe across
different newline conventions, byte orders, and character systems. Files are
saved only after the receiving user chooses a destination.

Target tiers:

| Target | Intended runtime | Status |
| --- | --- | --- |
| macOS 26, arm64 | Bundled Tcl/Tk 9.0 | Native DMG |
| macOS 10.13+, amd64 | Bundled Tcl/Tk 9.0 | Native DMG |
| Windows 10+, amd64 | Bundled Tcl/Tk 8.6 | Native MSI |
| Debian 12-compatible Linux, amd64 | Bundled Tcl/Tk 8.6 | Native installer ISO |
| NetBSD-current, amd64/i386 | pkgsrc Tcl/Tk 8.6+ | Source MVP |
| NetBSD 10.1, mac68k | pkgsrc Tcl/Tk 8.0+ | Packaged source build |
| Windows 2000, amd64/i386 family | Tcl/Tk 8.4-era build | Compatibility target |
| Windows 95/98, i386 | Bundled Tcl/Tk 8.0.5 installer | Native ANSI Setup EXE; MSI also included |
| Classic Mac OS 7/8, 68k | classic Tcl/Tk 8.0 port | Compatibility target |

“amd64 Windows 95/98/2000” means the software may run on an amd64 machine only
through an i386 OS/runtime or virtual machine: those Windows releases do not
provide a native amd64 userland. Classic Mac builds likewise require a historical
68k Tcl/Tk toolchain; current Tcl/Tk releases do not produce classic Mac binaries.

Use the Windows i386 `setup.exe` on Windows 95/98. It does not require Windows
Installer and starts the bundled Tcl/Tk 8.0.5 runtime installer during setup.
The i386 MSI contains the same payload for later 32-bit Windows systems that
already provide Microsoft Windows Installer (`msiexec`). The amd64 MSI is only
for 64-bit Windows 10 or later and cannot run on Windows 95/98.

Build all official installers, including the distinct Windows i386 and Windows
AMD64 MSI packages, with:

```sh
make installers
```

For complete reproducible instructions—including host prerequisites, bundled
runtime inputs, individual platform targets, version/path overrides, expected
outputs, verification commands, and common failures—see
[docs/BUILDING.md](docs/BUILDING.md). The guide uses only normal shell and
`make` commands; Codex or another AI tool is not required.

Modern macOS is distributed as a `.dmg`. Classic Mac OS 68K and PPC installers
are distributed as ISO 9660/HFS Standard hybrid CDs. The HFS side preserves
the executable resource forks, Finder metadata, mixed-case names, and color
icons required by physical System 7/8/9 Macs. The same images can be attached
as CD-ROMs in Basilisk II and SheepShaver. Temporary `.hfv` images used while
mastering and validating the hybrid CDs are not distribution artifacts.

## NetBSD 10.1/mac68k packages

Build separate client and server archives with:

```sh
make netbsd-mac68k
```

The archives are written to `dist/`. The installer ISO includes an `INSTALL.SH`
script that installs both applications, checks for Tcl/Tk, bootstraps `pkgin`
with NetBSD's `pkg_add` when necessary, and creates `retrochat-client` and
`retrochat-server` commands.
Run the graphical applications from an xterm under X11. The stock monochrome
NetBSD 10.1/mac68k X server is supported; RetroChat uses an explicit
black-text-on-white palette when the X display is one bit deep.

## Current limitations

- No encryption, authentication, rooms, history, resume, or integrity hashes.
- Anyone who can reach the server can connect and relay data.
- File sending is synchronous, so the sender UI pauses during a large transfer.
- File metadata/resource forks are not preserved on classic Mac OS.
- The server has basic line-size validation but is not yet Internet-hardened.

The next engineering milestone should add a transfer state machine, cancellation,
SHA-256 where available, server limits, and TLS through an optional package while
retaining this protocol as the legacy compatibility mode.

## License

RetroChat is copyright (c) 2026 Brandon Regard and released under the
[MIT License](LICENSE).
