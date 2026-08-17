#!/usr/bin/env tclsh

set here [file dirname [info script]]
source [file join $here lib protocol.tcl]

namespace eval server {
    variable clients
    variable clientRooms
    variable clientNames
    variable clientIds
    variable nextClientId 0
    variable rooms
    variable history
    variable historyFile ""
    variable transferSender
    variable transferRecipients
    variable transferReady
    variable transferAccepted
    variable transferAck
    variable transferLastAck
    variable transferWriter
    variable transferPath
    variable transferAvailable
    variable transferBytes
    variable transferEnd
    variable transferNext
    variable transferWaiting
    variable transferStarted
    variable transferChunkSize
    variable transferWindow
    variable transferReader
    variable transferBegin
    variable transferSerial 0
    variable recipientActive
    variable recipientQueue
    variable batchTarget
    # A 65536-byte file chunk becomes about 131100 hexadecimal characters.
    variable maxLine 140000
    variable listener ""
}

proc server::sendRecordTo {channel command fields} {
    if {[catch {puts $channel [retrochat::makeRecord $command $fields]} problem]} {
        drop $channel
        return 0
    }
    if {[catch {flush $channel} problem]} {
        # A nonblocking socket may temporarily refuse a flush when its peer is
        # busy (especially Classic Open Transport). Keep the queued Tcl channel
        # data and resume when the socket is writable instead of disconnecting.
        if {[info exists ::errorCode] &&
            ([lsearch -exact $::errorCode EWOULDBLOCK] >= 0 ||
             [lsearch -exact $::errorCode EAGAIN] >= 0)} {
            fileevent $channel writable [list server::writable $channel]
            return 1
        }
        drop $channel
        return 0
    }
    return 1
}

proc server::writable {channel} {
    variable clients
    if {![info exists clients($channel)]} {return}
    if {![catch {flush $channel}]} {
        fileevent $channel writable {}
        return
    }
    if {![info exists ::errorCode] ||
        ([lsearch -exact $::errorCode EWOULDBLOCK] < 0 &&
         [lsearch -exact $::errorCode EAGAIN] < 0)} {
        fileevent $channel writable {}
        drop $channel
    }
}

proc server::finishTransferReadiness {id} {
    variable transferSender
    variable transferRecipients
    variable transferReady
    variable transferAccepted
    variable transferAck
    variable transferLastAck
    variable transferNext
    variable transferWaiting
    variable transferStarted
    variable transferChunkSize
    variable transferWindow
    if {![info exists transferSender($id)]} {return}
    foreach recipient $transferRecipients($id) {
        if {[info exists transferReady($id,$recipient)] &&
            $transferReady($id,$recipient) &&
            [lsearch -exact $transferAccepted($id) $recipient] < 0} {
            lappend transferAccepted($id) $recipient
            set transferAck($id,$recipient) 0
            set transferNext($id,$recipient) 0
            set transferWaiting($id,$recipient) 0
        }
    }
    if {!$transferStarted($id) && [llength $transferAccepted($id)] > 0} {
        set transferStarted($id) 1
        sendRecordTo $transferSender($id) FILE_READY \
            [list $id 1 $transferChunkSize($id) $transferWindow($id)]
    }
    foreach recipient $transferRecipients($id) {
        if {![info exists transferReady($id,$recipient)]} {return}
    }
    if {!$transferStarted($id)} {
        sendRecordTo $transferSender($id) FILE_READY [list $id 0]
        forgetTransfer $id
    }
}

proc server::queueRecipientTransfer {recipient id} {
    variable recipientActive
    variable recipientQueue
    variable transferBegin
    if {![info exists recipientActive($recipient)] ||
        $recipientActive($recipient) == ""} {
        set recipientActive($recipient) $id
        if {[info exists transferBegin($id)]} {
            sendRecordTo $recipient FILE_BEGIN $transferBegin($id)
        }
    } elseif {$recipientActive($recipient) != $id &&
        (![info exists recipientQueue($recipient)] ||
         [lsearch -exact $recipientQueue($recipient) $id] < 0)} {
        lappend recipientQueue($recipient) $id
    }
}

proc server::releaseRecipientTransfer {recipient id} {
    variable recipientActive
    variable recipientQueue
    variable transferReader
    variable transferBegin
    if {[info exists transferReader($id,$recipient)]} {
        catch {close $transferReader($id,$recipient)}
        unset transferReader($id,$recipient)
    }
    if {[info exists recipientQueue($recipient)]} {
        set index [lsearch -exact $recipientQueue($recipient) $id]
        if {$index >= 0} {
            set recipientQueue($recipient) [lreplace \
                $recipientQueue($recipient) $index $index]
        }
    }
    if {![info exists recipientActive($recipient)] ||
        $recipientActive($recipient) != $id} {return}
    set recipientActive($recipient) ""
    while {[info exists recipientQueue($recipient)] &&
        [llength $recipientQueue($recipient)] > 0} {
        set next [lindex $recipientQueue($recipient) 0]
        set recipientQueue($recipient) [lrange $recipientQueue($recipient) 1 end]
        if {[info exists ::server::transferRecipients($next)] &&
            [lsearch -exact $::server::transferRecipients($next) $recipient] >= 0} {
            set recipientActive($recipient) $next
            if {[info exists transferBegin($next)]} {
                sendRecordTo $recipient FILE_BEGIN $transferBegin($next)
            }
            break
        }
    }
}

proc server::pumpRecipient {id recipient} {
    variable transferAccepted
    variable transferAck
    variable transferPath
    variable transferAvailable
    variable transferEnd
    variable transferNext
    variable transferWaiting
    variable recipientActive
    variable transferChunkSize
    variable transferWindow
    variable transferReader
    variable transferBegin
    if {![info exists transferAccepted($id)] ||
        [lsearch -exact $transferAccepted($id) $recipient] < 0 ||
        ![info exists transferNext($id,$recipient)] ||
        ![info exists recipientActive($recipient)] ||
        $recipientActive($recipient) != $id} {return}
    while {$transferNext($id,$recipient) < $transferAvailable($id) &&
        $transferNext($id,$recipient) - $transferAck($id,$recipient) <
            $transferWindow($id)} {
        set sequence $transferNext($id,$recipient)
        if {[catch {
            if {![info exists transferReader($id,$recipient)]} {
                set transferReader($id,$recipient) [open $transferPath($id) r]
                fconfigure $transferReader($id,$recipient) -translation binary
            }
            seek $transferReader($id,$recipient) \
                [expr {$sequence * $transferChunkSize($id)}]
            set chunk [read $transferReader($id,$recipient) \
                $transferChunkSize($id)]
        } problem]} {
            if {[info exists transferReader($id,$recipient)]} {
                catch {close $transferReader($id,$recipient)}
                unset transferReader($id,$recipient)
            }
            log "could not read transfer spool: $problem"
            return
        }
        if {[sendRecordTo $recipient FILE_CHUNK [list $id $sequence $chunk]]} {
            incr transferNext($id,$recipient)
        } else {
            return
        }
    }
    if {[info exists transferEnd($id)] &&
        $transferNext($id,$recipient) >= $transferAvailable($id) &&
        $transferAck($id,$recipient) >= $transferAvailable($id) &&
        (!$transferWaiting($id,$recipient))} {
        # Keep the recipient lane occupied until it confirms that FILE_END was
        # validated and the completed file was installed at its destination.
        set transferWaiting($id,$recipient) 1
        sendRecordTo $recipient FILE_END $transferEnd($id)
    }
}

proc server::maybeFinishTransfer {id} {
    variable transferAccepted
    variable transferEnd
    if {[info exists transferEnd($id)] &&
        (![info exists transferAccepted($id)] ||
         [llength $transferAccepted($id)] == 0)} {
        forgetTransfer $id
    }
}

proc server::forgetTransfer {id} {
    variable transferSender
    variable transferRecipients
    variable transferReady
    variable transferAccepted
    variable transferAck
    variable transferLastAck
    variable transferWriter
    variable transferPath
    variable transferAvailable
    variable transferBytes
    variable transferEnd
    variable transferNext
    variable transferWaiting
    variable transferStarted
    variable transferChunkSize
    variable transferWindow
    variable transferReader
    # A transfer may be queued before its recipient has accepted it, so remove
    # it from the recipient lane using the intended-recipient list rather than
    # only the accepted list.
    if {[info exists transferRecipients($id)]} {
        foreach recipient $transferRecipients($id) {
            releaseRecipientTransfer $recipient $id
        }
    }
    if {[info exists transferWriter($id)]} {
        catch {close $transferWriter($id)}
    }
    if {[info exists transferPath($id)]} {
        catch {file delete -force $transferPath($id)}
    }
    catch {unset transferSender($id)}
    catch {unset transferRecipients($id)}
    catch {unset transferAccepted($id)}
    catch {unset transferLastAck($id)}
    catch {unset transferWriter($id)}
    catch {unset transferPath($id)}
    catch {unset transferAvailable($id)}
    catch {unset transferBytes($id)}
    catch {unset transferEnd($id)}
    catch {unset transferStarted($id)}
    catch {unset transferChunkSize($id)}
    catch {unset transferWindow($id)}
    catch {unset transferBegin($id)}
    foreach key [array names transferReady "$id,*"] {unset transferReady($key)}
    foreach key [array names transferAck "$id,*"] {unset transferAck($key)}
    foreach key [array names transferNext "$id,*"] {unset transferNext($key)}
    foreach key [array names transferWaiting "$id,*"] {unset transferWaiting($key)}
    foreach key [array names transferReader "$id,*"] {
        catch {close $transferReader($key)}
        unset transferReader($key)
    }
}

proc server::saveHistory {} {
    variable rooms
    variable history
    variable historyFile
    if {[catch {
        set temporary "$historyFile.tmp"
        set file [open $temporary w]
        foreach room [lsort [array names rooms]] {
            if {$room == "RelayTestRoom"} {continue}
            puts $file [retrochat::makeRecord CHANNEL [list $room]]
            if {[info exists history($room)]} {
                foreach message $history($room) {
                    puts $file [retrochat::makeRecord MESSAGE \
                        [list $room [lindex $message 0] [lindex $message 1]]]
                }
            }
        }
        close $file
        file rename -force $temporary $historyFile
    } problem]} {
        catch {close $file}
        log "could not save channel history: $problem"
        return 0
    }
    return 1
}

proc server::loadHistory {} {
    variable rooms
    variable history
    variable historyFile
    catch {array unset rooms}
    catch {array unset history}
    set rooms(Lobby) 1
    set historyChanged 0
    if {![file exists $historyFile]} {return}
    set file [open $historyFile r]
    while {[gets $file line] >= 0} {
        if {[catch {retrochat::parseRecord $line} parsed]} {continue}
        set command [lindex $parsed 0]
        set fields [lindex $parsed 1]
        if {$command == "CHANNEL" && [llength $fields] == 1} {
            set room [lindex $fields 0]
            if {[string tolower $room] != "other" &&
                [string tolower $room] != "sideroom" &&
                $room != "RelayTestRoom"} {
                set rooms($room) 1
            } else {
                set historyChanged 1
            }
        } elseif {$command == "MESSAGE" && [llength $fields] == 3} {
            set room [lindex $fields 0]
            if {[string tolower $room] == "other" ||
                [string tolower $room] == "sideroom" ||
                $room == "RelayTestRoom"} {
                set historyChanged 1
                continue
            }
            if {$room == "Lobby" && [lindex $fields 1] == "Tester"} {
                set historyChanged 1
                continue
            }
            set rooms($room) 1
            lappend history($room) [list [lindex $fields 1] [lindex $fields 2]]
        }
    }
    close $file
    if {$historyChanged} {saveHistory}
}

proc server::sendChannels {channel} {
    variable rooms
    sendRecordTo $channel CHANNELS [lsort [array names rooms]]
}

proc server::sendUsers {room} {
    variable clients
    variable clientRooms
    variable clientNames
    variable clientIds
    set fields ""
    foreach channel [array names clients] {
        if {[info exists clientRooms($channel)] &&
            $clientRooms($channel) == $room &&
            [info exists clientIds($channel)] &&
            [info exists clientNames($channel)]} {
            lappend fields $clientIds($channel) $clientNames($channel)
        }
    }
    foreach channel [array names clients] {
        if {[info exists clientRooms($channel)] &&
            $clientRooms($channel) == $room} {
            sendRecordTo $channel USERS $fields
        }
    }
}

proc server::channelForUser {id room excludedChannel} {
    variable clients
    variable clientRooms
    variable clientIds
    foreach channel [array names clients] {
        if {$channel != $excludedChannel &&
            [info exists clientIds($channel)] &&
            $clientIds($channel) == $id &&
            [info exists clientRooms($channel)] &&
            $clientRooms($channel) == $room} {
            return $channel
        }
    }
    return ""
}

proc server::sendHistory {channel room} {
    variable history
    if {![sendRecordTo $channel HISTORY_BEGIN [list $room]]} {return}
    if {[info exists history($room)]} {
        foreach message $history($room) {
            if {![sendRecordTo $channel HISTORY_CHAT $message]} {return}
        }
    }
    sendRecordTo $channel HISTORY_END [list $room]
}

proc server::clearAllData {} {
    variable clients
    variable clientRooms
    variable rooms
    variable history
    variable historyFile
    variable transferSender
    variable transferRecipients
    variable recipientActive
    variable recipientQueue
    variable batchTarget

    # Notify both ends before discarding every active or queued transfer.
    foreach id [array names transferSender] {
        catch {sendRecordTo $transferSender($id) FILE_CANCEL [list $id]}
        if {[info exists transferRecipients($id)]} {
            foreach recipient $transferRecipients($id) {
                catch {sendRecordTo $recipient FILE_CANCEL [list $id]}
            }
        }
    }
    # Prevent forgetTransfer from advancing queued work while the cache is
    # being emptied.
    catch {array unset recipientActive}
    catch {array unset recipientQueue}
    foreach id [array names transferSender] {forgetTransfer $id}
    catch {array unset batchTarget}

    # Remove any orphaned spool left by an interrupted earlier server run.
    set dataDirectory [file dirname $historyFile]
    foreach path [glob -nocomplain \
        [file join $dataDirectory .retrochat-transfer-*.tmp]] {
        catch {file delete -force $path}
    }

    catch {array unset rooms}
    catch {array unset history}
    set rooms(Lobby) 1
    if {![saveHistory]} {return 0}

    # Put every connected client in the one empty default channel and refresh
    # all channel and membership state immediately.
    foreach channel [array names clients] {
        set clientRooms($channel) Lobby
        sendRecordTo $channel JOINED [list Lobby]
        sendHistory $channel Lobby
        sendChannels $channel
    }
    sendUsers Lobby
    log "cleared transfer cache, channel history, and non-default channels"
    return 1
}

proc server::stop {} {
    variable clients
    variable listener

    foreach channel [array names clients] {
        catch {fileevent $channel readable {}}
        catch {close $channel}
    }
    catch {array unset clients}
    catch {array unset clientRooms}
    catch {array unset clientNames}
    catch {array unset clientIds}
    if {$listener != ""} {
        catch {close $listener}
        set listener ""
    }
}

proc server::log {message} {
    puts "[clock format [clock seconds]] $message"
}

proc server::drop {channel} {
    variable clients
    variable clientRooms
    variable transferSender
    variable transferAccepted
    variable recipientActive
    variable recipientQueue
    variable clientNames
    variable clientIds
    set oldRoom ""
    if {[info exists clientRooms($channel)]} {set oldRoom $clientRooms($channel)}
    catch {fileevent $channel readable {}}
    catch {close $channel}
    catch {unset clients($channel)}
    catch {unset clientRooms($channel)}
    catch {unset clientNames($channel)}
    catch {unset clientIds($channel)}
    foreach id [array names transferSender] {
        if {$transferSender($id) == $channel} {
            forgetTransfer $id
        } elseif {[info exists transferAccepted($id)]} {
            set index [lsearch -exact $transferAccepted($id) $channel]
            if {$index >= 0} {
                if {[info exists transferSender($id)]} {
                    sendRecordTo $transferSender($id) FILE_DELIVERED \
                        [list $id 0]
                }
                set transferAccepted($id) [lreplace \
                    $transferAccepted($id) $index $index]
                releaseRecipientTransfer $channel $id
                maybeFinishTransfer $id
            }
        }
    }
    catch {unset recipientActive($channel)}
    catch {unset recipientQueue($channel)}
    if {$oldRoom != ""} {sendUsers $oldRoom}
    log "client disconnected"
}

proc server::broadcast {line room {excludedChannel ""}} {
    variable clients
    variable clientRooms
    foreach channel [array names clients] {
        if {$channel == $excludedChannel} {
            continue
        }
        if {![info exists clientRooms($channel)] ||
            $clientRooms($channel) != $room} {
            continue
        }
        if {[catch {puts $channel $line}]} {drop $channel; continue}
        if {[catch {flush $channel}] &&
            [info exists ::errorCode] &&
            ([lsearch -exact $::errorCode EWOULDBLOCK] >= 0 ||
             [lsearch -exact $::errorCode EAGAIN] >= 0)} {
            fileevent $channel writable [list server::writable $channel]
        }
    }
}

proc server::broadcastFile {line {excludedChannel ""}} {
    variable clients
    foreach channel [array names clients] {
        if {$channel == $excludedChannel} {continue}
        if {[catch {puts $channel $line}]} {drop $channel; continue}
        if {[catch {flush $channel}] &&
            [info exists ::errorCode] &&
            ([lsearch -exact $::errorCode EWOULDBLOCK] >= 0 ||
             [lsearch -exact $::errorCode EAGAIN] >= 0)} {
            fileevent $channel writable [list server::writable $channel]
        }
    }
}

proc server::readable {channel} {
    variable maxLine
    variable clientRooms
    variable rooms
    variable history
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
    set fields [lindex $parsed 1]
    if {$command == "HELLO" && [llength $fields] >= 1} {
        variable clientNames
        variable clientIds
        set name [string trim [lindex $fields 0]]
        if {$name == ""} {set name Guest}
        set clientNames($channel) [string range $name 0 31]
        sendRecordTo $channel SELF \
            [list $clientIds($channel) $clientNames($channel)]
        sendUsers $clientRooms($channel)
        return
    }
    if {$command == "LIST_CHANNELS"} {
        sendChannels $channel
        return
    }
    if {$command == "DELETE_CHANNEL" && [llength $fields] == 1} {
        set room [lindex $fields 0]
        if {$room == "Lobby"} {
            puts $channel [retrochat::makeRecord ERROR [list "Lobby cannot be deleted"]]
            flush $channel
            return
        }
        catch {unset rooms($room)}
        catch {unset history($room)}
        foreach client [array names clientRooms] {
            if {$clientRooms($client) == $room} {
                set clientRooms($client) Lobby
                puts $client [retrochat::makeRecord JOINED [list Lobby]]
                sendHistory $client Lobby
            }
        }
        saveHistory
        foreach client [array names clientRooms] {sendChannels $client}
        sendUsers Lobby
        return
    }
    if {$command == "JOIN" && [llength $fields] == 1} {
        set oldRoom $clientRooms($channel)
        set room [string trim [lindex $fields 0]]
        if {[string tolower $room] == "other"} {
            puts $channel [retrochat::makeRecord ERROR \
                [list {"Other" is not a channel. Choose another name.}]]
            flush $channel
            return
        }
        if {$room == "" || [string length $room] > 32 ||
            ![regexp {^[A-Za-z0-9 _.-]+$} $room]} {
            puts $channel [retrochat::makeRecord ERROR \
                [list "Channel names use letters, numbers, spaces, _, . or -"]]
            flush $channel
            return
        }
        set clientRooms($channel) $room
        set rooms($room) 1
        saveHistory
        puts $channel [retrochat::makeRecord JOINED [list $room]]
        sendHistory $channel $room
        foreach client [array names clientRooms] {sendChannels $client}
        if {$oldRoom != $room} {sendUsers $oldRoom}
        sendUsers $room
        log "client joined channel $room"
        return
    }
    if {[lsearch -exact {CHAT FILE_BATCH_BEGIN FILE_BEGIN FILE_CHUNK FILE_READY FILE_ACK FILE_RECEIVED FILE_CANCEL FILE_END FILE_BATCH_END} $command] < 0} {
        return
    }
    set room $clientRooms($channel)
    if {$command == "CHAT" && [llength $fields] == 2} {
        # Tester is reserved for the relay integration test. Its smoke-test
        # traffic must never become part of a user's Lobby history.
        if {$room != "Lobby" || [lindex $fields 0] != "Tester"} {
            lappend history($room) [list [lindex $fields 0] [lindex $fields 1]]
            saveHistory
        }
    }
    if {$command == "FILE_BATCH_BEGIN" && [llength $fields] == 4} {
        variable batchTarget
        set batch [lindex $fields 0]
        set target [channelForUser [lindex $fields 3] $room $channel]
        if {$target == ""} {
            sendRecordTo $channel ERROR [list "Selected user is no longer in this channel"]
            return
        }
        set batchTarget($channel,$batch) $target
        sendRecordTo $target FILE_BATCH_BEGIN [lrange $fields 0 2]
        return
    }
    if {$command == "FILE_BEGIN" && [llength $fields] == 6} {
        variable clients
        variable transferSender
        variable transferRecipients
        variable transferWriter
        variable transferPath
        variable transferAvailable
        variable transferBytes
        variable transferSerial
        variable transferAccepted
        variable transferStarted
        variable transferLastAck
        variable transferChunkSize
        variable transferWindow
        variable transferBegin
        variable historyFile
        set id [lindex $fields 0]
        forgetTransfer $id
        set transferSender($id) $channel
        incr transferSerial
        set transferPath($id) [file join [file dirname $historyFile] \
            ".retrochat-transfer-[pid]-$transferSerial.tmp"]
        if {[catch {open $transferPath($id) w} transferWriter($id)]} {
            log "could not create transfer spool: $transferWriter($id)"
            catch {unset transferWriter($id)}
            sendRecordTo $channel FILE_READY [list $id 0]
            forgetTransfer $id
            return
        }
        fconfigure $transferWriter($id) -translation binary
        set transferAvailable($id) 0
        set transferBytes($id) 0
        set transferAccepted($id) ""
        set transferStarted($id) 0
        set transferLastAck($id) 0
        set transferChunkSize($id) 16384
        set transferWindow($id) 8
        variable batchTarget
        set batch [lindex $fields 4]
        set recipient [channelForUser [lindex $fields 5] $room $channel]
        if {![info exists batchTarget($channel,$batch)] ||
            $batchTarget($channel,$batch) != $recipient} {
            set recipient ""
        }
        set recipients ""
        if {$recipient != ""} {lappend recipients $recipient}
        set transferRecipients($id) $recipients
        if {$recipient != ""} {
            set transferBegin($id) [lrange $fields 0 4]
            queueRecipientTransfer $recipient $id
        }
        if {[llength $recipients] == 0} {
            sendRecordTo $channel FILE_READY [list $id 0]
            forgetTransfer $id
        }
        return
    }
    if {$command == "FILE_BATCH_END" && [llength $fields] == 1} {
        variable batchTarget
        set batch [lindex $fields 0]
        if {[info exists batchTarget($channel,$batch)]} {
            sendRecordTo $batchTarget($channel,$batch) FILE_BATCH_END $fields
            unset batchTarget($channel,$batch)
        }
        return
    }
    if {$command == "FILE_READY" && [llength $fields] >= 2} {
        variable transferRecipients
        variable transferReady
        variable transferChunkSize
        variable transferWindow
        set id [lindex $fields 0]
        if {[info exists transferRecipients($id)] &&
            [lsearch -exact $transferRecipients($id) $channel] >= 0} {
            set transferReady($id,$channel) [expr {[lindex $fields 1] != 0}]
            if {$transferReady($id,$channel) && [llength $fields] >= 4} {
                set chunkSize [lindex $fields 2]
                set window [lindex $fields 3]
                if {[regexp {^[0-9]+$} $chunkSize] &&
                    $chunkSize >= 4096 && $chunkSize <= 65536} {
                    set transferChunkSize($id) $chunkSize
                }
                if {[regexp {^[0-9]+$} $window] &&
                    $window >= 1 && $window <= 64} {
                    set transferWindow($id) $window
                }
            }
            finishTransferReadiness $id
        }
        return
    }
    if {$command == "FILE_ACK" && [llength $fields] == 2} {
        variable transferAccepted
        variable transferAck
        variable transferWaiting
        variable transferSender
        variable transferBytes
        variable transferChunkSize
        set id [lindex $fields 0]
        if {[info exists transferAccepted($id)] &&
            [lsearch -exact $transferAccepted($id) $channel] >= 0} {
            set transferAck($id,$channel) [lindex $fields 1]
            set transferWaiting($id,$channel) 0
            set delivered [expr {$transferAck($id,$channel) *
                $transferChunkSize($id)}]
            if {$delivered > $transferBytes($id)} {
                set delivered $transferBytes($id)
            }
            sendRecordTo $transferSender($id) FILE_PROGRESS \
                [list $id $delivered]
            pumpRecipient $id $channel
        }
        return
    }
    if {$command == "FILE_RECEIVED" && [llength $fields] == 2} {
        variable transferSender
        variable transferAccepted
        variable transferAck
        variable transferNext
        variable transferWaiting
        variable transferBytes
        set id [lindex $fields 0]
        if {[info exists transferAccepted($id)] &&
            [lsearch -exact $transferAccepted($id) $channel] >= 0} {
            set succeeded [expr {[lindex $fields 1] != 0}]
            if {$succeeded} {
                sendRecordTo $transferSender($id) FILE_PROGRESS \
                    [list $id $transferBytes($id)]
            }
            sendRecordTo $transferSender($id) FILE_DELIVERED \
                [list $id $succeeded]
            set index [lsearch -exact $transferAccepted($id) $channel]
            set transferAccepted($id) [lreplace \
                $transferAccepted($id) $index $index]
            catch {unset transferAck($id,$channel)}
            catch {unset transferNext($id,$channel)}
            catch {unset transferWaiting($id,$channel)}
            releaseRecipientTransfer $channel $id
            maybeFinishTransfer $id
        }
        return
    }
    if {$command == "FILE_CANCEL" && [llength $fields] == 1} {
        variable transferSender
        variable transferAccepted
        variable transferAck
        variable transferNext
        variable transferWaiting
        set id [lindex $fields 0]
            if {[info exists transferSender($id)] &&
            $transferSender($id) != $channel} {
            if {[info exists transferAccepted($id)]} {
                set index [lsearch -exact $transferAccepted($id) $channel]
                if {$index >= 0} {
                    sendRecordTo $transferSender($id) FILE_DELIVERED \
                        [list $id 0]
                    set transferAccepted($id) [lreplace \
                        $transferAccepted($id) $index $index]
                }
            }
            catch {unset transferAck($id,$channel)}
            catch {unset transferNext($id,$channel)}
            catch {unset transferWaiting($id,$channel)}
            releaseRecipientTransfer $channel $id
            maybeFinishTransfer $id
            return
        }
        if {[info exists transferSender($id)] &&
            $transferSender($id) == $channel} {
            variable transferRecipients
            if {[info exists transferRecipients($id)]} {
                foreach recipient $transferRecipients($id) {
                    sendRecordTo $recipient FILE_CANCEL $fields
                }
            }
            forgetTransfer $id
            return
        }
        return
    }
    if {$command == "FILE_CHUNK" && [llength $fields] == 3} {
        variable transferSender
        variable transferWriter
        variable transferAvailable
        variable transferBytes
        variable transferAccepted
        set id [lindex $fields 0]
        set sequence [lindex $fields 1]
        if {[info exists transferSender($id)] &&
            $transferSender($id) == $channel &&
            [info exists transferWriter($id)] &&
            $sequence == $transferAvailable($id)} {
            if {[catch {
                puts -nonewline $transferWriter($id) [lindex $fields 2]
                flush $transferWriter($id)
            } problem]} {
                log "could not write transfer spool: $problem"
                sendRecordTo $channel FILE_CANCEL [list $id]
                forgetTransfer $id
                return
            }
            incr transferAvailable($id)
            incr transferBytes($id) [string length [lindex $fields 2]]
            sendRecordTo $channel FILE_ACK [list $id $transferAvailable($id)]
            if {[info exists transferAccepted($id)]} {
                foreach recipient $transferAccepted($id) {
                    pumpRecipient $id $recipient
                }
            }
        }
        return
    }
    if {$command == "FILE_END" && [llength $fields] == 3} {
        variable transferSender
        variable transferWriter
        variable transferAccepted
        variable transferEnd
        variable transferBytes
        set id [lindex $fields 0]
        if {[info exists transferSender($id)] &&
            $transferSender($id) == $channel} {
            if {[info exists transferWriter($id)]} {
                catch {close $transferWriter($id)}
                unset transferWriter($id)
            }
            if {![info exists transferBytes($id)] ||
                ![regexp {^[0-9]+$} [lindex $fields 1]] ||
                $transferBytes($id) != [lindex $fields 1]} {
                sendRecordTo $channel FILE_CANCEL [list $id]
                if {[info exists transferAccepted($id)]} {
                    foreach recipient $transferAccepted($id) {
                        sendRecordTo $recipient FILE_CANCEL [list $id]
                    }
                }
                forgetTransfer $id
                return
            }
            set transferEnd($id) $fields
            if {[info exists transferAccepted($id)]} {
                foreach recipient $transferAccepted($id) {
                    pumpRecipient $id $recipient
                }
            }
            maybeFinishTransfer $id
        }
        return
    }
    if {[lsearch -exact {FILE_BATCH_BEGIN FILE_BEGIN FILE_CHUNK FILE_READY FILE_ACK FILE_CANCEL FILE_END FILE_BATCH_END} $command] >= 0} {
        broadcastFile $line $channel
        if {$command == "FILE_END" || $command == "FILE_CANCEL"} {
            forgetTransfer [lindex $fields 0]
        }
    } else {
        broadcast $line $room
    }
}

proc server::accept {channel address port} {
    variable clients
    variable clientRooms
    variable clientNames
    variable clientIds
    variable nextClientId
    fconfigure $channel -blocking 0 -buffering full -buffersize 1048576 \
        -translation lf
    set clients($channel) [list $address $port]
    set clientRooms($channel) Lobby
    set clientNames($channel) Guest
    incr nextClientId
    set clientIds($channel) "user-$nextClientId"
    fileevent $channel readable [list server::readable $channel]
    log "client connected from $address:$port"
}

proc server::start {{port 7777}} {
    variable listener
    variable historyFile
    if {![regexp {^[0-9]+$} $port] || $port < 1 || $port > 65535} {
        error "port must be an integer from 1 through 65535"
    }
    if {[info exists ::env(RETROCHAT_HISTORY_FILE)]} {
        set historyFile $::env(RETROCHAT_HISTORY_FILE)
    } else {
        if {[info exists ::env(APPDATA)]} {
            set dataDirectory [file join $::env(APPDATA) RetroChat]
        } elseif {[info exists ::env(HOME)]} {
            set dataDirectory [file join $::env(HOME) .retrochat]
        } else {
            set dataDirectory [pwd]
        }
        if {[catch {file mkdir $dataDirectory}]} {
            set dataDirectory [pwd]
        }
        set historyFile [file join $dataDirectory channels.dat]
    }
    loadHistory
    set listener [socket -server server::accept $port]
    log "RetroChat server listening on port $port"
}

if {![info exists ::retrochat_embedded_server] &&
    [file tail [info script]] == [file tail $argv0]} {
    set port 7777
    if {[llength $argv] > 0} {
        set port [lindex $argv 0]
    }
    if {[catch {server::start $port} problem]} {
        puts stderr "usage: tclsh server.tcl ?port?"
        puts stderr $problem
        exit 2
    }
    vwait forever
}
