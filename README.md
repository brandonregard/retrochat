# RetroChat

RetroChat is a small chat and file-transfer system written in Tcl/Tk. Its first
milestone is deliberately simple: one relay server, many desktop clients, chat
messages, and user-approved file saves.

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
tclsh tests/protocol.test
```

## Portability strategy

The source uses Tcl 8.0-era constructs and standard Tk widgets. All protocol
fields, including file chunks, are hexadecimal, so the relay remains safe across
different newline conventions, byte orders, and character systems. Files are
saved only after the receiving user chooses a destination.

Target tiers:

| Target | Intended runtime | Status |
| --- | --- | --- |
| macOS 26, arm64 | Tcl/Tk 8.6+ | Source MVP |
| NetBSD-current, amd64/i386 | pkgsrc Tcl/Tk 8.6+ | Source MVP |
| Windows 2000, amd64/i386 family | Tcl/Tk 8.4-era build | Compatibility target |
| Windows 95/98, i386 | Tcl/Tk 8.0/8.4-era build | Compatibility target |
| Classic Mac OS 7/8, 68k | classic Tcl/Tk 8.0 port | Compatibility target |

“amd64 Windows 95/98/2000” means the software may run on an amd64 machine only
through an i386 OS/runtime or virtual machine: those Windows releases do not
provide a native amd64 userland. Classic Mac builds likewise require a historical
68k Tcl/Tk toolchain; current Tcl/Tk releases do not produce classic Mac binaries.

## Current limitations

- No encryption, authentication, rooms, history, resume, or integrity hashes.
- Anyone who can reach the server can connect and relay data.
- File sending is synchronous, so the sender UI pauses during a large transfer.
- File metadata/resource forks are not preserved on classic Mac OS.
- The server has basic line-size validation but is not yet Internet-hardened.

The next engineering milestone should add a transfer state machine, cancellation,
SHA-256 where available, server limits, and TLS through an optional package while
retaining this protocol as the legacy compatibility mode.

