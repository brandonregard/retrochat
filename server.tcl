#!/usr/bin/env tclsh

set here [file dirname [info script]]
source [file join $here lib protocol.tcl]

namespace eval server {
    variable clients
    variable maxLine 70000
}

proc server::log {message} {
    puts "[clock format [clock seconds]] $message"
}

proc server::drop {channel} {
    variable clients
    catch {fileevent $channel readable {}}
    catch {close $channel}
    catch {unset clients($channel)}
    log "client disconnected"
}

proc server::broadcast {line {excludedChannel ""}} {
    variable clients
    foreach channel [array names clients] {
        if {$channel == $excludedChannel} {
            continue
        }
        if {[catch {puts $channel $line; flush $channel}]} {
            drop $channel
        }
    }
}

proc server::readable {channel} {
    variable maxLine
    if {[eof $channel]} {
        drop $channel
        return
    }
    if {[catch {gets $channel line} count] || $count < 0} {
        return
    }
    if {[string length $line] > $maxLine} {
        drop $channel
        return
    }
    if {[catch {retrochat::parseRecord $line} parsed]} {
        log "ignored malformed record"
        return
    }
    set command [lindex $parsed 0]
    if {[lsearch -exact {HELLO CHAT FILE_BEGIN FILE_CHUNK FILE_END} $command] < 0} {
        return
    }
    if {[lsearch -exact {FILE_BEGIN FILE_CHUNK FILE_END} $command] >= 0} {
        broadcast $line $channel
    } else {
        broadcast $line
    }
}

proc server::accept {channel address port} {
    variable clients
    fconfigure $channel -blocking 0 -buffering line -translation lf
    set clients($channel) [list $address $port]
    fileevent $channel readable [list server::readable $channel]
    log "client connected from $address:$port"
}

set port 7777
if {[llength $argv] > 0} {
    set port [lindex $argv 0]
}
if {![regexp {^[0-9]+$} $port] || $port < 1 || $port > 65535} {
    puts stderr "usage: tclsh server.tcl ?port?"
    exit 2
}

socket -server server::accept $port
server::log "RetroChat server listening on port $port"
vwait forever
