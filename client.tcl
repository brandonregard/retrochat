#!/usr/bin/env wish

set here [file dirname [info script]]
source [file join $here lib protocol.tcl]

namespace eval app {
    variable sock ""
    variable connected 0
    variable nextTransfer 0
    variable incoming
    variable incomingBatch
    variable incomingName
    variable incomingSize
    variable incomingReceived
    variable host localhost
    variable port 7777
    variable nickname Guest
    variable message ""
    variable status "Disconnected"
    variable transferText ""
}

proc app::updateSendProgress {name sent total} {
    variable transferText

    if {$total > 0} {
        set percent [expr {($sent * 100) / $total}]
    } else {
        set percent 100
    }
    if {$percent > 100} {
        set percent 100
    }
    set transferText "Sending [shortFileName $name]: $percent%"
    if {![winfo ismapped .transfer]} {
        pack .transfer -side top -fill x -padx 4 -pady 2 -before .compose
    }
    update idletasks
    set width [winfo width .transfer.bar]
    if {$width < 2} {
        set width 2
    }
    .transfer.bar coords progress 1 1 \
        [expr {1 + (($width - 2) * $percent / 100)}] 9
    update idletasks
}

proc app::shortFileName {name} {
    set limit 30
    if {[string length $name] <= $limit} {
        return $name
    }
    set extension [file extension $name]
    set stem [file rootname $name]
    set available [expr {$limit - [string length $extension] - 3}]
    if {$available < 4} {
        set available 4
    }
    return "[string range $stem 0 [expr {$available - 1}]]...$extension"
}

proc app::updateReceiveProgress {name received total} {
    variable transferText
    if {$total > 0} {
        set percent [expr {($received * 100) / $total}]
    } else {
        set percent 100
    }
    if {$percent > 100} {set percent 100}
    set transferText "Receiving [shortFileName $name]: $percent%"
    if {![winfo ismapped .transfer]} {
        pack .transfer -side top -fill x -padx 4 -pady 2 -before .compose
    }
    update idletasks
    set width [winfo width .transfer.bar]
    if {$width < 2} {set width 2}
    .transfer.bar coords progress 1 1 \
        [expr {1 + (($width - 2) * $percent / 100)}] 9
    update idletasks
}

proc app::hideSendProgress {} {
    pack forget .transfer
    .transfer.bar coords progress 1 1 1 9
}

proc app::fillFilePicker {} {
    variable pickerDir
    variable pickerPaths
    variable pickerKinds

    .filePicker.files delete 0 end
    set pickerPaths ""
    set pickerKinds ""
    if {[catch {glob -nocomplain [file join $pickerDir *]} entries]} {
        set entries ""
    }
    foreach path [lsort $entries] {
        if {[file isdirectory $path]} {
            .filePicker.files insert end "< [file tail $path] >"
            lappend pickerKinds directory
        } else {
            .filePicker.files insert end [file tail $path]
            lappend pickerKinds file
        }
        lappend pickerPaths $path
    }
}

proc app::filePickerGo {} {
    variable pickerDir
    if {[file isdirectory $pickerDir]} {
        fillFilePicker
    }
}

proc app::filePickerUp {} {
    variable pickerDir
    set parent [file dirname $pickerDir]
    if {$parent != $pickerDir} {
        set pickerDir $parent
        fillFilePicker
    }
}

proc app::filePickerOpen {} {
    variable pickerDir
    variable pickerPaths
    variable pickerKinds
    set selected [.filePicker.files curselection]
    if {[llength $selected] != 1} {return}
    set index [lindex $selected 0]
    if {[lindex $pickerKinds $index] == "directory"} {
        set pickerDir [lindex $pickerPaths $index]
        fillFilePicker
    }
}

proc app::filePickerAccept {} {
    variable pickerPaths
    variable pickerKinds
    variable pickerResult
    set pickerResult ""
    foreach index [.filePicker.files curselection] {
        if {[lindex $pickerKinds $index] == "file"} {
            lappend pickerResult [lindex $pickerPaths $index]
        }
    }
    if {[llength $pickerResult] > 0} {set ::app::pickerDone 1}
}

proc app::chooseMultipleFiles {} {
    variable pickerDir
    variable pickerResult
    variable pickerDone

    set pickerDir [pwd]
    set pickerResult ""
    set pickerDone 0
    toplevel .filePicker
    wm title .filePicker "Send Files"
    wm protocol .filePicker WM_DELETE_WINDOW {set ::app::pickerDone 1}
    frame .filePicker.location
    entry .filePicker.location.path -textvariable app::pickerDir
    button .filePicker.location.up -text "Up" -command app::filePickerUp
    button .filePicker.location.go -text "Go" -command app::filePickerGo
    pack .filePicker.location.up .filePicker.location.go -side right -padx 2
    pack .filePicker.location.path -side left -fill x -expand 1
    scrollbar .filePicker.scroll -command {.filePicker.files yview}
    listbox .filePicker.files -selectmode extended -width 55 -height 18 \
        -yscrollcommand {.filePicker.scroll set}
    frame .filePicker.buttons
    button .filePicker.buttons.send -text "Send Selected" \
        -command app::filePickerAccept
    button .filePicker.buttons.cancel -text "Cancel" \
        -command {set ::app::pickerDone 1}
    pack .filePicker.buttons.cancel .filePicker.buttons.send -side right -padx 4
    pack .filePicker.location -side top -fill x -padx 6 -pady 6
    pack .filePicker.scroll -side right -fill y
    pack .filePicker.files -side top -fill both -expand 1 -padx 6
    pack .filePicker.buttons -side bottom -fill x -padx 6 -pady 6
    bind .filePicker.files <Double-Button-1> {app::filePickerOpen}
    bind .filePicker <Return> {app::filePickerAccept}
    fillFilePicker
    grab .filePicker
    focus .filePicker.files
    tkwait variable ::app::pickerDone
    grab release .filePicker
    destroy .filePicker
    return $pickerResult
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
    variable incomingBatch
    variable incomingName
    variable incomingSize
    variable incomingReceived

    if {$command == "CHAT" && [llength $fields] == 2} {
        show "<[lindex $fields 0]> [lindex $fields 1]"
    } elseif {$command == "FILE_BATCH_BEGIN" && [llength $fields] == 3} {
        set batch [lindex $fields 0]
        set count [lindex $fields 1]
        set sender [lindex $fields 2]
        if {[llength [info commands tk_chooseDirectory]]} {
            set incomingBatch($batch) [tk_chooseDirectory \
                -title "Save $count files from $sender"]
            if {$incomingBatch($batch) == ""} {
                show "Declined $count files from $sender." system
            }
        } else {
            # Tcl/Tk 8.0 has no directory chooser. Defer to the first file's
            # Save dialog, then use that selected folder for the whole batch.
            set incomingBatch($batch) pending
        }
    } elseif {$command == "FILE_BEGIN" && [llength $fields] == 5} {
        set id [lindex $fields 0]
        set name [file tail [lindex $fields 1]]
        set size [lindex $fields 2]
        set sender [lindex $fields 3]
        set batch [lindex $fields 4]

        set path ""
        if {[info exists incomingBatch($batch)] &&
            $incomingBatch($batch) == "pending"} {
            set chosen [tk_getSaveFile -initialfile $name \
                -title "Choose folder for files from $sender"]
            if {$chosen == ""} {
                set incomingBatch($batch) ""
                show "Declined files from $sender." system
            } else {
                set incomingBatch($batch) [file dirname $chosen]
            }
        }
        if {[info exists incomingBatch($batch)] && $incomingBatch($batch) != ""} {
            set path [file join $incomingBatch($batch) $name]
        }

        if {$path == ""} {
            set incoming($id) ""
        } elseif {[catch {open $path w} channel]} {
            set incoming($id) ""
            show "Could not save $name: $channel" error
        } else {
            fconfigure $channel -translation binary
            set incoming($id) $channel
            set incomingName($id) $name
            set incomingSize($id) $size
            set incomingReceived($id) 0
            show "Receiving $name from $sender..." system
            updateReceiveProgress $name 0 $size
        }
    } elseif {$command == "FILE_CHUNK" && [llength $fields] == 2} {
        set id [lindex $fields 0]

        if {[info exists incoming($id)] && $incoming($id) != ""} {
            set chunk [lindex $fields 1]
            puts -nonewline $incoming($id) $chunk
            incr incomingReceived($id) [string length $chunk]
            updateReceiveProgress $incomingName($id) \
                $incomingReceived($id) $incomingSize($id)
        }
    } elseif {$command == "FILE_END" && [llength $fields] == 1} {
        set id [lindex $fields 0]

        if {[info exists incoming($id)]} {
            if {$incoming($id) != ""} {
                close $incoming($id)
                updateReceiveProgress $incomingName($id) \
                    $incomingSize($id) $incomingSize($id)
                show "Received $incomingName($id)." system
            }

            unset incoming($id)
            catch {unset incomingName($id)}
            catch {unset incomingSize($id)}
            catch {unset incomingReceived($id)}
        }
    } elseif {$command == "FILE_BATCH_END" && [llength $fields] == 1} {
        set batch [lindex $fields 0]
        catch {unset incomingBatch($batch)}
        after 400 app::hideSendProgress
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

    set paths ""
    if {[catch {tk_getOpenFile -title "Send files" -multiple 1} selected]} {
        set paths [chooseMultipleFiles]
    } else {
        set paths $selected
    }
    if {[llength $paths] == 0} {
        return
    }

    incr nextTransfer
    set batch "[clock seconds]-$nextTransfer"
    if {![sendRecord FILE_BATCH_BEGIN \
        [list $batch [llength $paths] $nickname]]} {return}
    foreach path $paths {
        if {![sendOneFile $path $batch]} {break}
    }
    sendRecord FILE_BATCH_END [list $batch]
    after 400 app::hideSendProgress
}

proc app::sendOneFile {path batch} {
    variable nextTransfer
    variable nickname

    if {[catch {open $path r} channel]} {
        show "Could not open file: $channel" error
        return 0
    }

    fconfigure $channel -translation binary

    incr nextTransfer
    set id "[clock seconds]-$nextTransfer"
    set size [file size $path]
    set name [file tail $path]
    set sent 0
    set completed 1

    if {![sendRecord FILE_BEGIN \
        [list $id $name $size $nickname $batch]]} {
        close $channel
        return 0
    }

    updateSendProgress $name 0 $size

    while {![eof $channel]} {
        set chunk [read $channel 16384]

        if {$chunk != "" &&
            ![sendRecord FILE_CHUNK [list $id $chunk]]} {
            set completed 0
            break
        }

        incr sent [string length $chunk]
        updateSendProgress $name $sent $size

        update idletasks
    }

    close $channel
    if {$completed && [sendRecord FILE_END [list $id]]} {
        updateSendProgress $name $size $size
        show "Sent $name ($size bytes)." system
    } else {
        set completed 0
    }
    return $completed
}

# Neutral gray palette modeled on the Mac OS 9 Platinum and Windows 95
# system interfaces. These explicit colors keep the UI consistent across
# classic Tk ports without requiring platform themes.
set uiBackground "#c8c8c8"
set uiSurface "#b8b8b8"
set uiField "#f4f4f4"
set uiForeground "#101010"
set uiMuted "#505050"
set uiAccent "#383838"
set uiSelection "#707070"
set uiError "#202020"

set uiButtonBackground "#d8d8d8"
set uiButtonForeground "#101010"
set uiButtonActive "#b0b0b0"
set uiButtonDisabled "#787878"

option add *background $uiBackground
option add *foreground $uiForeground
option add *activeBackground $uiSurface
option add *activeForeground $uiForeground
option add *highlightBackground $uiBackground
option add *highlightColor $uiAccent
option add *selectBackground $uiSelection
option add *selectForeground "#ffffff"
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

if {[info exists here]} {
    if {[string compare $tcl_platform(platform) "windows"] == 0} {
        set windowsIconPath [file join $here assets icons windows client.ico]
        if {[file exists $windowsIconPath]} {
            # On Windows, -default updates both the class icon used by the
            # taskbar and the small icon drawn in the title bar.
            if {[catch {wm iconbitmap . -default $windowsIconPath}]} {
                catch {wm iconbitmap . $windowsIconPath}
            }
        }
    } else {
        set appIconPath [file join $here assets icons png client client-tray.gif]
        if {[file exists $appIconPath] &&
            ![catch {image create photo appIcon -file $appIconPath}]} {
            catch {wm iconphoto . appIcon}
        }
    }
}

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
    -selectforeground "#ffffff" \
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

frame .transfer
label .transfer.label \
    -textvariable app::transferText \
    -anchor w
canvas .transfer.bar \
    -height 10 \
    -width 160 \
    -borderwidth 1 \
    -relief sunken \
    -background $uiField \
    -highlightthickness 0
.transfer.bar create rectangle 1 1 1 9 \
    -fill $uiSelection \
    -outline $uiSelection \
    -tags progress
pack .transfer.label -side left -padx 4
pack .transfer.bar -side right -fill x -expand 1 -padx 4

frame .compose

button .compose.sendfile \
    -text "Send Files..." \
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
