#!/usr/bin/env wish

set here [file dirname [info script]]
source [file join $here server.tcl]

namespace eval serverui {
    variable tray 0
    variable connectedUserIds ""
    variable usersRefreshAfter ""
}

proc serverui::isClassicMac {} {
    if {[info exists ::retrochatClassicMac] && $::retrochatClassicMac} {
        return 1
    }
    if {[info exists ::tcl_platform(platform)] &&
        [string compare $::tcl_platform(platform) "macintosh"] == 0} {
        return 1
    }
    if {[info exists ::tcl_platform(os)] &&
        [string match "MacOS*" $::tcl_platform(os)]} {
        return 1
    }
    return 0
}

# Match the client and the native gray interfaces of Mac OS 9/Windows 95.
set serverUiBackground "#c8c8c8"
set serverUiForeground "#101010"
set serverUiActive "#b0b0b0"
set serverUiHighlight "#383838"
set serverUiButton "#d8d8d8"
set serverUiDisabled "#787878"

# Identify NetBSD/mac68k only for compact sizing. Its one-bit X color mapping
# is controlled by the X server; RetroChat does not attempt to invert it.
set serverUiNetBSDMac68k 0
if {[info exists ::tcl_platform(os)] &&
    [string compare $::tcl_platform(os) "NetBSD"] == 0 &&
    [info exists ::tcl_platform(machine)] &&
    ([string match "m68k*" $::tcl_platform(machine)] ||
     [string match "mac68k*" $::tcl_platform(machine)] ||
     [string match "m680*" $::tcl_platform(machine)])} {
    set serverUiNetBSDMac68k 1
}

option add *background $serverUiBackground
option add *foreground $serverUiForeground
option add *activeBackground $serverUiActive
option add *activeForeground $serverUiForeground
option add *highlightBackground $serverUiBackground
option add *highlightColor $serverUiHighlight
option add *Button.background $serverUiButton
option add *Button.foreground $serverUiForeground
option add *Button.activeBackground $serverUiActive
option add *Button.activeForeground $serverUiForeground
option add *Button.disabledForeground $serverUiDisabled
option add *Entry.background $serverUiBackground
option add *Text.background $serverUiBackground
option add *Listbox.background $serverUiBackground
option add *selectBackground $serverUiHighlight
option add *selectForeground "#ffffff"
option add *insertBackground $serverUiForeground

if {$serverUiNetBSDMac68k} {
    foreach serverFont {TkDefaultFont TkTextFont TkFixedFont TkMenuFont
                        TkHeadingFont TkCaptionFont TkSmallCaptionFont
                        TkIconFont TkTooltipFont} {
        catch {font configure $serverFont -size 10}
    }
}

proc serverui::fitWindowToScreen {window marginX marginY} {
    if {![winfo exists $window]} {return}
    if {[catch {update idletasks}]} {return}
    if {[catch {
        set width [winfo reqwidth $window]
        set height [winfo reqheight $window]
        set maximumWidth [expr {[winfo screenwidth $window] - $marginX}]
        set maximumHeight [expr {[winfo screenheight $window] - $marginY}]
    }]} {return}
    if {$width > $maximumWidth} {set width $maximumWidth}
    if {$height > $maximumHeight} {set height $maximumHeight}
    if {$width < 1 || $height < 1} {return}
    catch {wm maxsize $window $maximumWidth $maximumHeight}
    catch {wm geometry $window [format "%dx%d+0+0" $width $height]}
}

proc serverui::quit {} {
    catch {tk systray destroy}
    server::stop
    exit
}

proc serverui::showMenu {} {
    tk_popup .serverMenu [winfo pointerx .] [winfo pointery .]
}

proc serverui::formatDuration {seconds} {
    if {$seconds < 0} {set seconds 0}
    set days [expr {$seconds / 86400}]
    set hours [expr {($seconds % 86400) / 3600}]
    set minutes [expr {($seconds % 3600) / 60}]
    set secs [expr {$seconds % 60}]
    if {$days > 0} {return [format "%dd %02d:%02d:%02d" $days $hours $minutes $secs]}
    return [format "%02d:%02d:%02d" $hours $minutes $secs]
}

proc serverui::updateDisconnectButton {} {
    if {![winfo exists .connectedUsers.table.list]} {return}
    if {[llength [.connectedUsers.table.list curselection]] > 0} {
        .connectedUsers.buttons.disconnect configure -state normal
    } else {
        .connectedUsers.buttons.disconnect configure -state disabled
    }
}

proc serverui::refreshConnectedUsers {} {
    variable connectedUserIds
    variable usersRefreshAfter
    if {![winfo exists .connectedUsers]} {return}

    set selectedId ""
    set selection [.connectedUsers.table.list curselection]
    if {[llength $selection] > 0} {
        set index [lindex $selection 0]
        if {$index < [llength $connectedUserIds]} {
            set selectedId [lindex $connectedUserIds $index]
        }
    }

    .connectedUsers.table.list delete 0 end
    set connectedUserIds ""
    set now [clock seconds]
    set rowIndex 0
    foreach row [server::connectedUsers] {
        set id [lindex $row 0]
        set name [lindex $row 1]
        set address [lindex $row 2]
        set port [lindex $row 3]
        set room [lindex $row 4]
        set since [lindex $row 5]
        if {$since > 0} {
            set connected [clock format $since -format "%Y-%m-%d %H:%M:%S"]
            set duration [formatDuration [expr {$now - $since}]]
        } else {
            set connected "Unknown"
            set duration "Unknown"
        }
        .connectedUsers.table.list insert end [format "%-18.18s %-22.22s %-6.6s %-16.16s %-19.19s %s" \
            $name $address $port $room $connected $duration]
        lappend connectedUserIds $id
        if {$id == $selectedId} {
            .connectedUsers.table.list selection set $rowIndex
            .connectedUsers.table.list see $rowIndex
        }
        incr rowIndex
    }
    if {[llength $connectedUserIds] == 0} {
        .connectedUsers.empty configure -text "No users are connected."
    } else {
        .connectedUsers.empty configure -text ""
    }
    updateDisconnectButton
    catch {after cancel $usersRefreshAfter}
    set usersRefreshAfter [after 1000 serverui::refreshConnectedUsers]
}

proc serverui::closeConnectedUsers {} {
    variable usersRefreshAfter
    if {$usersRefreshAfter != ""} {catch {after cancel $usersRefreshAfter}}
    set usersRefreshAfter ""
    catch {destroy .connectedUsers}
}

proc serverui::disconnectSelectedUser {} {
    variable connectedUserIds
    set selection [.connectedUsers.table.list curselection]
    if {[llength $selection] == 0} {return}
    set index [lindex $selection 0]
    if {$index >= [llength $connectedUserIds]} {return}
    set id [lindex $connectedUserIds $index]
    set display "the selected user"
    foreach candidate [server::connectedUsers] {
        if {[lindex $candidate 0] == $id} {
            set display "[lindex $candidate 1] ([lindex $candidate 2])"
            break
        }
    }
    set answer [tk_messageBox -icon warning -type yesno \
        -title "Disconnect User" \
        -message "Are you sure?\n\nDisconnect $display from RetroChat?"]
    if {$answer != "yes"} {return}
    server::disconnectUser $id
    refreshConnectedUsers
}

proc serverui::showConnectedUsers {} {
    if {[winfo exists .connectedUsers]} {
        raise .connectedUsers
        refreshConnectedUsers
        return
    }
    toplevel .connectedUsers
    wm title .connectedUsers "Connected Users"
    if {$::serverUiNetBSDMac68k} {
        wm minsize .connectedUsers 540 240
    } else {
        wm minsize .connectedUsers 760 280
    }
    wm protocol .connectedUsers WM_DELETE_WINDOW serverui::closeConnectedUsers

    label .connectedUsers.title -text "Connected Users" -font TkHeadingFont -anchor w
    frame .connectedUsers.table
    label .connectedUsers.table.header \
        -text [format "%-18s %-22s %-6s %-16s %-19s %s" \
            "Name" "IP Address" "Port" "Channel" "Connected" "Duration"] \
        -anchor w -font TkFixedFont
    listbox .connectedUsers.table.list -height 12 -width 100 \
        -font TkFixedFont -exportselection 0 \
        -yscrollcommand {.connectedUsers.table.scroll set}
    scrollbar .connectedUsers.table.scroll -orient vertical \
        -command {.connectedUsers.table.list yview}
    label .connectedUsers.empty -text "" -anchor w
    frame .connectedUsers.buttons
    button .connectedUsers.buttons.disconnect -text "Disconnect User..." \
        -state disabled -command serverui::disconnectSelectedUser
    button .connectedUsers.buttons.refresh -text "Refresh" \
        -command serverui::refreshConnectedUsers
    button .connectedUsers.buttons.close -text "Close" \
        -command serverui::closeConnectedUsers

    pack .connectedUsers.title -side top -fill x -padx 12 -pady 10
    pack .connectedUsers.table.header -side top -fill x
    pack .connectedUsers.table.scroll -side right -fill y
    pack .connectedUsers.table.list -side left -fill both -expand 1
    pack .connectedUsers.table -side top -fill both -expand 1 -padx 12
    pack .connectedUsers.empty -side top -fill x -padx 12 -pady 3
    pack .connectedUsers.buttons.disconnect .connectedUsers.buttons.refresh \
        .connectedUsers.buttons.close -side left -padx 5 -pady 8
    pack .connectedUsers.buttons -side bottom
    bind .connectedUsers.table.list <ButtonRelease-1> serverui::updateDisconnectButton
    bind .connectedUsers.table.list <KeyRelease> serverui::updateDisconnectButton
    bind .connectedUsers <Escape> serverui::closeConnectedUsers
    refreshConnectedUsers
    if {$::serverUiNetBSDMac68k} {
        after idle {serverui::fitWindowToScreen .connectedUsers 12 36}
    }
}

proc serverui::showAbout {} {
    set dialog .retrochatServerAbout
    if {[winfo exists $dialog]} {
        raise $dialog
        return
    }
    toplevel $dialog
    wm title $dialog "About RetroChat Server"
    wm resizable $dialog 0 0
    # The main server window may be withdrawn while its status item is active.
    # In that case, making About transient to it would also hide the dialog.
    if {[winfo ismapped .]} {wm transient $dialog .}

    set iconPath [file join $::here assets icons png server server-128.png]
    if {[file exists $iconPath] &&
        ![catch {image create photo retrochatServerAboutIcon -file $iconPath}]} {
        label $dialog.icon -image retrochatServerAboutIcon
        pack $dialog.icon -side left -padx 20 -pady 20
    }
    frame $dialog.details
    label $dialog.details.name -text "RetroChat Server" -font TkHeadingFont
    label $dialog.details.version -text "Version 0.0.4"
    label $dialog.details.author -text "Brandon Regard"
    label $dialog.details.license -text "MIT License"
    label $dialog.details.date -text "August 17, 2026"
    button $dialog.details.ok -text "OK" -width 8 -default active \
        -command [list destroy $dialog]
    pack $dialog.details.name $dialog.details.version \
        $dialog.details.author $dialog.details.license \
        $dialog.details.date -anchor center -pady 2
    pack $dialog.details.ok -pady 12
    pack $dialog.details -side left -padx 20 -pady 18
    bind $dialog <Return> [list destroy $dialog]
    bind $dialog <Escape> [list destroy $dialog]
    bind $dialog <Destroy> {
        if {[winfo exists .retrochatServerAbout] == 0} {
            catch {image delete retrochatServerAboutIcon}
        }
    }
}

proc serverui::installApplicationMenu {} {
    set aqua [expr {[info exists ::tcl_platform(os)] &&
        [string compare $::tcl_platform(os) "Darwin"] == 0}]

    # These hooks and the special .apple menu must exist before the menubar is
    # attached. Otherwise Aqua inserts Wish's hidden default application menu,
    # and its Tcl/Tk items cannot be replaced afterward.
    if {$aqua} {
        proc ::tkAboutDialog {} {serverui::showAbout}
        proc ::tk::mac::Quit {} {serverui::quit}
    }

    catch {destroy .menubar}
    menu .menubar -tearoff 0
    if {$aqua} {
        menu .menubar.apple -tearoff 0
        .menubar add cascade -label "RetroChat Server" -menu .menubar.apple
        .menubar.apple add command -label "About RetroChat Server" \
            -command serverui::showAbout
    } elseif {[isClassicMac]} {
        menu .menubar.apple -tearoff 0
        .menubar add cascade -label "\024" -menu .menubar.apple
        .menubar.apple add command -label "About RetroChat..." \
            -command retrochatAbout
    }
    menu .menubar.file -tearoff 0
    .menubar add cascade -label "File" -menu .menubar.file
    .menubar.file add command -label "Connected Users..." \
        -command serverui::showConnectedUsers
    .menubar.file add separator
    .menubar.file add command -label "Clear All History..." \
        -command serverui::clearAllData
    if {[isClassicMac]} {
        .menubar.file add separator
        .menubar.file add command -label "Quit RetroChat Server" \
            -command serverui::quit
    }
    . configure -menu .menubar
}

proc serverui::clearAllData {} {
    set answer [tk_messageBox -icon warning -type yesno \
        -title "Clear All History" \
        -message "Are you sure?\n\nThis will cancel file transfers, erase all channel history, delete every channel except Lobby, and move all connected clients to an empty Lobby."]
    if {$answer != "yes"} {return}
    if {[server::clearAllData]} {
        tk_messageBox -icon info -type ok -title "History Cleared" \
            -message "All cached transfers, channel history, and non-default channels were cleared."
    } else {
        tk_messageBox -icon error -type ok -title "Could Not Clear Data" \
            -message "The server could not save the empty Lobby history. Check the server log."
    }
}

proc serverui::start {} {
    variable tray

    set port 7777
    if {[llength $::argv] > 0} {
        set port [lindex $::argv 0]
    }

    server::start $port
    installApplicationMenu

    if {[string compare $::tcl_platform(platform) "windows"] == 0} {
        set windowsIconPath [file join $::here assets icons windows server.ico]
        if {[file exists $windowsIconPath]} {
            if {[catch {wm iconbitmap . -default $windowsIconPath}]} {
                catch {wm iconbitmap . $windowsIconPath}
            }
        }
    }

    menu .serverMenu -tearoff 0
    .serverMenu add command -label "Connected Users..." \
        -command serverui::showConnectedUsers
    .serverMenu add command -label "Clear All History..." \
        -command serverui::clearAllData
    .serverMenu add separator
    .serverMenu add command -label "Quit RetroChat Server" \
        -command serverui::quit

    set iconPath [file join $::here assets icons png server server-tray.gif]
    if {[file exists $iconPath]} {
        image create photo serverTrayIcon -file $iconPath
    }

    if {[llength [info commands tk]] &&
        ![catch {tk systray create -image serverTrayIcon \
            -text "RetroChat Server — port $port" \
            -button1 serverui::showMenu \
            -button3 serverui::showMenu}]} {
        set tray 1
        wm withdraw .
    } else {
        wm title . "RetroChat Server"
        wm resizable . 0 0
        label .status -text "Listening on port $port" -padx 18 -pady 10
        button .users -text "Connected Users..." \
            -command serverui::showConnectedUsers -width 16
        button .clear -text "Clear All History..." \
            -command serverui::clearAllData -width 16
        button .quit -text "Quit" -command serverui::quit -width 12
        pack .status .users .clear .quit -padx 8 -pady 5
        wm protocol . WM_DELETE_WINDOW serverui::quit
        if {$::serverUiNetBSDMac68k} {
            after idle {serverui::fitWindowToScreen . 12 36}
        }
    }
}

serverui::start
