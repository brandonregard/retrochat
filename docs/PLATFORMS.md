# Supported platforms

RetroChat is written for Tcl/Tk 8.0 and newer. The relay server needs Tcl; the
desktop client needs both Tcl and Tk. The wire protocol uses line-oriented ASCII
records with hexadecimal fields so it does not depend on native newline, byte
order, or character encoding conventions.

## Support tiers

| Platform | Runtime | Verification | Support tier |
| --- | --- | --- | --- |
| NetBSD 10.1, x86-64 | Base-system or pkgsrc Tcl/Tk 8.6+ | Protocol and relay tests in GitHub Actions | CI-tested |
| NetBSD 10.1, mac68k | pkgsrc Tcl/Tk 8.0+ | Client/server archives built in GitHub Actions | Build-tested |
| Ubuntu 24.04, x86-64 | Distribution Tcl/Tk 8.6+ | Lint, protocol, and relay tests in GitHub Actions | CI-tested |
| macOS 15, arm64 | Homebrew Tcl/Tk 8.6+ | Protocol and relay tests in GitHub Actions | CI-tested |
| Windows Server 2025, x86-64 | Magicsplat Tcl/Tk | Protocol and relay tests in GitHub Actions | CI-tested |
| Windows 95/98/2000, i386 | Tcl/Tk 8.0 or 8.4-era build | Not automated | Compatibility target |
| Classic Mac OS 7/8, 68k | Classic Tcl/Tk 8.0 port | Not automated | Compatibility target |

The CI-tested tier means the command-line protocol library and a two-client
relay exchange run on every change. It does not currently include automated Tk
GUI testing. Compatibility targets guide source and protocol decisions but need
testing on appropriate historical hardware, emulators, or virtual machines.

## NetBSD

Install Tcl and Tk from pkgsrc if they are not already available:

```sh
pkgin install tcl tk
```

Start the relay and client with:

```sh
tclsh server.tcl 7777
wish client.tcl
```

The GitHub Actions job boots a NetBSD 10.1 x86-64 virtual machine, installs Tcl
when necessary, and runs both test suites inside the guest. A local NetBSD test
can be run with:

```sh
tclsh tests/protocol.test
tclsh server.tcl 17777 >server.log 2>&1 &
server_pid=$!
tclsh tests/relay.test 17777
kill "$server_pid"
```

For mac68k, `make netbsd-mac68k` creates separate client and server archives in
`dist/`. The payload is architecture-independent Tcl source with small NetBSD
shell launchers. The client needs Tk and an X11 display; the server needs Tcl.
CI verifies the package contents but does not claim native mac68k execution
testing. Where binary Tcl/Tk packages are unavailable, build `lang/tcl` and
`x11/tk` from pkgsrc.

## Other Unix-like systems

RetroChat has no compiled components. On systems with Tcl/Tk 8.0 or newer,
install the platform's Tcl and Tk packages and use the same launch commands.
Only the operating systems listed as CI-tested above are continuously verified.

## Historical systems

Windows 95, Windows 98, and Windows 2000 require an i386 Tcl/Tk runtime even
when the host processor is amd64; those operating systems do not have a native
amd64 userland. Classic Mac OS requires a historical 68k Tcl/Tk toolchain.
Modern releases of Tcl/Tk do not build native applications for those targets.

RetroChat deliberately avoids newer Tcl language features and nonstandard
widgets to preserve these targets. File metadata and resource forks are not
preserved on Classic Mac OS, and TLS or integrity checks added in the future
must remain optional for legacy runtimes.
