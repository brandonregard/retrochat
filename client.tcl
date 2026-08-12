#!/usr/bin/env wish

set here [file dirname [info script]]
source [file join $here lib protocol.tcl]

namespace eval app {
    variable sock ""
    variable connected 0
    variable nextTransfer 0
    variable incoming
    variable host localhost
    variable port 7777
    variable nickname Guest
    variable message ""
    variable status "Disconnected"
}

proc app::show {line {tag normal}} {
    .chat configure -state normal
    .chat insert end "$line\n" $tag
    .chat see end
    .chat configure -state disabled
}

proc app::sendRecord {command fields} {
    variable sock

    if {$sock == ""} {
        return 0
    }

    if {[catch {
        puts $sock [retrochat::makeRecord $command $fields]
        flush $sock
    } problem]} {
        disconnect
        show "Connection lost: $problem" error
        return 0
    }

    return 1
}

proc app::connect {} {
    variable host
    variable port
    variable nickname
    variable sock
    variable connected
    variable status

    if {$connected} {
        return
    }

    if {[catch {socket $host $port} channel]} {
        set status "Connection failed"
        show "Could not connect: $channel" error
        return
    }

    set sock $channel
    fconfigure $sock -blocking 0 -buffering line -translation lf
    fileevent $sock readable app::readable

    set connected 1
    set status "Connected to $host:$port"

    sendRecord HELLO [list $nickname 1]
    show "Connected." system

    .connect configure -state disabled
    .disconnect configure -state normal
    .compose.sendfile configure -state normal
}

proc app::disconnect {} {
    variable sock
    variable connected
    variable status

    if {$sock != ""} {
        catch {fileevent $sock readable {}}
        catch {close $sock}
    }

    set sock ""
    set connected 0
    set status "Disconnected"

    .connect configure -state normal
    .disconnect configure -state disabled
    .compose.sendfile configure -state disabled
}

proc app::readable {} {
    variable sock

    if {$sock == ""} {
        return
    }

    # A modal save dialog runs Tk's event loop. Disable this socket callback
    # while handling the current record so FILE_CHUNK records cannot be handled
    # before FILE_BEGIN has finished opening and registering the destination.
    fileevent $sock readable {}

    if {[eof $sock]} {
        disconnect
        show "Server closed the connection." error
        return
    }

    if {[catch {gets $sock line} count] || $count < 0} {
        if {$sock != ""} {
            fileevent $sock readable app::readable
        }
        return
    }

    if {[catch {retrochat::parseRecord $line} parsed]} {
        if {$sock != ""} {
            fileevent $sock readable app::readable
        }
        return
    }

    receive [lindex $parsed 0] [lindex $parsed 1]

    if {$sock != ""} {
        fileevent $sock readable app::readable
    }
}

proc app::receive {command fields} {
    variable incoming

    if {$command == "CHAT" && [llength $fields] == 2} {
        show "<[lindex $fields 0]> [lindex $fields 1]"
    } elseif {$command == "FILE_BEGIN" && [llength $fields] == 4} {
        set id [lindex $fields 0]
        set name [file tail [lindex $fields 1]]
        set size [lindex $fields 2]
        set sender [lindex $fields 3]

        set path [tk_getSaveFile \
            -initialfile $name \
            -title "File from $sender ($size bytes)"]

        if {$path == ""} {
            set incoming($id) ""
            show "Declined file $name from $sender." system
        } elseif {[catch {open $path w} channel]} {
            set incoming($id) ""
            show "Could not save $name: $channel" error
        } else {
            fconfigure $channel -translation binary
            set incoming($id) $channel
            show "Receiving $name from $sender..." system
        }
    } elseif {$command == "FILE_CHUNK" && [llength $fields] == 2} {
        set id [lindex $fields 0]

        if {[info exists incoming($id)] && $incoming($id) != ""} {
            puts -nonewline $incoming($id) [lindex $fields 1]
        }
    } elseif {$command == "FILE_END" && [llength $fields] == 1} {
        set id [lindex $fields 0]

        if {[info exists incoming($id)]} {
            if {$incoming($id) != ""} {
                close $incoming($id)
                show "File transfer complete." system
            }

            unset incoming($id)
        }
    }
}

proc app::sendChat {} {
    variable message
    variable nickname

    if {$message == ""} {
        return
    }

    if {[sendRecord CHAT [list $nickname $message]]} {
        set message ""
    }
}

proc app::sendFile {} {
    variable nextTransfer
    variable nickname

    set path [tk_getOpenFile -title "Send a file"]

    if {$path == ""} {
        return
    }

    if {[catch {open $path r} channel]} {
        show "Could not open file: $channel" error
        return
    }

    fconfigure $channel -translation binary

    incr nextTransfer
    set id "[clock seconds]-$nextTransfer"
    set size [file size $path]

    if {![sendRecord FILE_BEGIN \
        [list $id [file tail $path] $size $nickname]]} {
        close $channel
        return
    }

    while {![eof $channel]} {
        set chunk [read $channel 16384]

        if {$chunk != "" &&
            ![sendRecord FILE_CHUNK [list $id $chunk]]} {
            break
        }

        update idletasks
    }

    close $channel
    sendRecord FILE_END [list $id]
    show "Sent [file tail $path] ($size bytes)." system
}

# Consistent dark palette using classic Tk options for broad compatibility.
set uiBackground "#20242b"
set uiSurface "#292e37"
set uiField "#15191f"
set uiForeground "#e6edf3"
set uiMuted "#9da7b3"
set uiAccent "#58a6ff"
set uiSelection "#264f78"
set uiError "#ff7b72"

# macOS renders classic Tk buttons with light native surfaces, so buttons
# receive a separate dark-text palette.
set uiButtonBackground "#d7e3f0"
set uiButtonForeground "#17202a"
set uiButtonActive "#8fc7ff"
set uiButtonDisabled "#626b75"

option add *background $uiBackground
option add *foreground $uiForeground
option add *activeBackground $uiSurface
option add *activeForeground $uiForeground
option add *highlightBackground $uiBackground
option add *highlightColor $uiAccent
option add *selectBackground $uiSelection
option add *selectForeground $uiForeground
option add *insertBackground $uiForeground

option add *Entry.background $uiField
option add *Text.background $uiField
option add *Listbox.background $uiField

option add *Button.background $uiButtonBackground
option add *Button.foreground $uiButtonForeground
option add *Button.activeBackground $uiButtonActive
option add *Button.activeForeground $uiButtonForeground
option add *Button.disabledForeground $uiButtonDisabled

wm title . "RetroChat"
wm minsize . 640 420

frame .connection

label .connection.hostlabel \
    -text "Host:"

entry .connection.host \
    -textvariable app::host \
    -width 20

label .connection.portlabel \
    -text "Port:"

entry .connection.port \
    -textvariable app::port \
    -width 6

label .connection.nicklabel \
    -text "Name:"

entry .connection.nick \
    -textvariable app::nickname \
    -width 12

button .connect \
    -text "Connect" \
    -command app::connect

button .disconnect \
    -text "Disconnect" \
    -command app::disconnect \
    -state disabled

pack \
    .connection.hostlabel \
    .connection.host \
    .connection.portlabel \
    .connection.port \
    .connection.nicklabel \
    .connection.nick \
    -side left \
    -padx 4 \
    -pady 8

pack \
    .connect \
    .disconnect \
    -in .connection \
    -side left \
    -padx 4 \
    -pady 8

pack .connection \
    -side top \
    -fill x

frame .transcript

text .chat \
    -width 72 \
    -height 22 \
    -wrap word \
    -state disabled \
    -background $uiField \
    -foreground $uiForeground \
    -insertbackground $uiForeground \
    -selectbackground $uiSelection \
    -selectforeground $uiForeground \
    -borderwidth 0 \
    -padx 8 \
    -pady 8

.chat tag configure system \
    -foreground $uiAccent

.chat tag configure error \
    -foreground $uiError

scrollbar .scroll \
    -command ".chat yview"

.chat configure \
    -yscrollcommand ".scroll set"

pack .scroll \
    -in .transcript \
    -side right \
    -fill y

pack .chat \
    -in .transcript \
    -side left \
    -fill both \
    -expand 1

pack .transcript \
    -side top \
    -fill both \
    -expand 1

frame .compose

button .compose.sendfile \
    -text "Send File..." \
    -command app::sendFile \
    -state disabled

entry .compose.message \
    -textvariable app::message

button .compose.send \
    -text "Send" \
    -command app::sendChat

pack .compose.sendfile \
    -side left \
    -padx 4 \
    -pady 6

pack .compose.message \
    -side left \
    -fill x \
    -expand 1 \
    -padx 4 \
    -pady 6

pack .compose.send \
    -side left \
    -padx 4 \
    -pady 6

pack .compose \
    -side top \
    -fill x

label .status \
    -textvariable app::status \
    -anchor w \
    -relief flat \
    -background $uiSurface \
    -foreground $uiMuted \
    -padx 8 \
    -pady 4

pack .status \
    -side bottom \
    -fill x

bind .compose.message <Return> {
    app::sendChat
}

wm protocol . WM_DELETE_WINDOW {
    app::disconnect
    destroy .
}

focus .compose.message
