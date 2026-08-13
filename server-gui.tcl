#!/usr/bin/env wish

set here [file dirname [info script]]
source [file join $here server.tcl]

namespace eval serverui {
    variable tray 0
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

proc serverui::start {} {
    variable tray

    set port 7777
    if {[llength $::argv] > 0} {
        set port [lindex $::argv 0]
    }

    server::start $port

    if {[string compare $::tcl_platform(platform) "windows"] == 0} {
        set windowsIconPath [file join $::here assets icons windows server.ico]
        if {[file exists $windowsIconPath]} {
            catch {wm iconbitmap . $windowsIconPath}
        }
    }

    menu .serverMenu -tearoff 0
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
        button .quit -text "Quit" -command serverui::quit -width 12
        pack .status .quit -padx 8 -pady 5
        wm protocol . WM_DELETE_WINDOW serverui::quit
    }
}

serverui::start
