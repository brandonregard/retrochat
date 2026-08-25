#!/bin/sh
set -eu

output=${1:-dist/classic-mac-wrapper-inputs}
version=${VERSION:-0.0.3}
client_source=${CLIENT_SOURCE:-client.tcl}
rm -rf "$output"
mkdir -p "$output/Icons"
work_client="$output/client.unix"
work_server="$output/server.unix"

{
    echo 'catch {console hide}'
    echo 'if {[catch {'
    echo "set ::retrochatVersion \"$version\""
    echo 'set ::retrochatClassicMac 1'
    echo 'set ::retrochatAboutIconResource RcCg'
    sed '/^#!/d' lib/protocol.tcl
    sed '/^#!/d; /^set here /d; /^source \[file join \$here lib protocol\.tcl\]$/d' "$client_source"
    sed '/^#/d' packaging/classic-mac/about.tcl
    echo '} ::retrochat_startup_error]} {'
    echo '    tk_messageBox -icon error -title "RetroChat Startup Error" -message $::retrochat_startup_error'
    echo '}'
} > "$work_client"

{
    echo 'catch {console hide}'
    echo 'set ::retrochat_embedded_server 1'
    echo "set ::retrochatVersion \"$version\""
    echo 'set ::retrochatAboutIconResource RcSg'
    sed '/^#!/d' lib/protocol.tcl
    sed '/^#!/d; /^set here /d; /^source \[file join \$here lib protocol\.tcl\]$/d' server.tcl
    echo 'unset ::retrochat_embedded_server'
    sed '/^#!/d; /^set here /d; /^source \[file join \$here server\.tcl\]$/d' server-gui.tcl
    sed '/^#/d' packaging/classic-mac/about.tcl
} > "$work_server"

iconv -f UTF-8 -t MACINTOSH "$work_client" | LC_ALL=C tr '\n' '\r' \
    > "$output/RetroChat Client.tcl"
iconv -f UTF-8 -t MACINTOSH "$work_server" | LC_ALL=C tr '\n' '\r' \
    > "$output/RetroChat Server.tcl"
rm -f "$work_client" "$work_server"

cp assets/icons/classic-mac/*.png "$output/Icons/"
cp packaging/classic-mac/WRAP-IN-EMULATOR.txt "$output/"

echo "$output"
