#!/usr/bin/env wish

set here [file dirname [info script]]
source [file join $here server.tcl]

namespace eval serverui {
    variable tray 0
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
option add *background "#c8c8c8"
option add *foreground "#101010"
option add *activeBackground "#b0b0b0"
option add *activeForeground "#101010"
option add *highlightBackground "#c8c8c8"
option add *highlightColor "#383838"
option add *Button.background "#d8d8d8"
option add *Button.foreground "#101010"
option add *Button.activeBackground "#b0b0b0"
option add *Button.activeForeground "#101010"
option add *Button.disabledForeground "#787878"

proc serverui::quit {} {
    catch {tk systray destroy}
    server::stop
    exit
}

proc serverui::showMenu {} {
    tk_popup .serverMenu [winfo pointerx .] [winfo pointery .]
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
    label $dialog.details.version -text "Version 0.0.1"
    label $dialog.details.author -text "Brandon Regard"
    label $dialog.details.date -text "August 17, 2026"
    button $dialog.details.ok -text "OK" -width 8 -default active \
        -command [list destroy $dialog]
    pack $dialog.details.name $dialog.details.version \
        $dialog.details.author $dialog.details.date -anchor center -pady 2
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
        button .clear -text "Clear All History..." \
            -command serverui::clearAllData -width 16
        button .quit -text "Quit" -command serverui::quit -width 12
        pack .status .clear .quit -padx 8 -pady 5
        wm protocol . WM_DELETE_WINDOW serverui::quit
    }
}

serverui::start
