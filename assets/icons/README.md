# RetroChat icons

The client uses a blue chat bubble. The server uses the same visual family
with a server cabinet behind the bubble.

- `source/` contains the full-resolution generated PNG masters.
- `macos/` contains application `.icns` files and their iconsets.
- `windows/` contains Windows 95-compatible 32-pixel `.ico` files.
- `classic-mac/` contains 16, 32, and 48-pixel source artwork for classic Mac
  OS icon resources.
- `netbsd/` contains common desktop icon sizes.
- `png/` contains portable sizes and 24-pixel GIFs readable by Tcl/Tk 8.0.

Run `make icons` on macOS to rebuild derived assets. This requires `sips`,
`png2icns` (Homebrew's `libicns` package), and `icotool` (Homebrew's
`icoutils` package). `icotool` writes the legacy transparency masks required
by Windows 95/98 in addition to the 32-bit alpha channel.

Classic Mac OS 7 stores Finder icons in resource forks rather than ordinary
image files. Import the supplied 16/32/48 artwork into the application's
`ICN#`/`icl4`/`icl8` and small-icon resources when constructing a native
classic Mac application bundle.
