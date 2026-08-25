#!/usr/bin/env wish

set here [file dirname [info script]]
source [file join $here lib protocol.tcl]

namespace eval app {
    variable sock ""
    variable connected 0
    variable nextTransfer 0
    variable incoming
    variable incomingBatch
    variable incomingBatchCount
    variable incomingBatchSender
    variable incomingOffer ""
    variable incomingOfferTimer ""
    variable incomingName
    variable incomingSize
    variable incomingReceived
    variable incomingSequence
    variable incomingAckInterval
    variable incomingPath
    variable incomingTemporary
    variable outgoingChannel ""
    variable outgoingPaths ""
    variable outgoingBatch ""
    variable outgoingTarget ""
    variable outgoingId ""
    variable outgoingWaiting 0
    variable outgoingAckGeneration 0
    variable outgoingAcknowledged 0
    variable outgoingChunkSize 16384
    variable outgoingWindow 8
    variable outgoingCurrentPath ""
    variable outgoingRetryCount 0
    variable host localhost
    variable port 7777
    variable nickname Guest
    variable channel Lobby
    variable channelNames ""
    variable userIds ""
    variable userNames ""
    variable selfUserId ""
    variable selectedUserId ""
    variable selectedRoom ""
    variable lastChannelClickRoom ""
    variable lastChannelClickTime 0
    variable message ""
    variable status "Disconnected"
    variable transferText ""
}

proc app::updateSendProgress {name sent total} {
    variable transferText

    if {$total > 0} {
        set percent [expr {int((double($sent) * 100.0) / double($total))}]
    } else {
        set percent 100
    }
    if {$percent > 100} {
        set percent 100
    }
    set transferText "Sending [shortFileName $name]: $percent%"
    if {![winfo ismapped .transfer]} {
        pack .transfer -side bottom -fill x -padx 4 -pady 2 \
            -before .transcript
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

proc app::formatByteCount {bytes} {
    if {$bytes < 1024} {return "$bytes bytes"}
    if {$bytes < 1048576} {
        return "[format %.1f [expr {double($bytes) / 1024.0}]] KB"
    }
    if {$bytes < 1073741824} {
        return "[format %.1f [expr {double($bytes) / 1048576.0}]] MB"
    }
    return "[format %.2f [expr {double($bytes) / 1073741824.0}]] GB"
}

proc app::showSendWaiting {name} {
    variable transferText
    set transferText "Waiting for recipient: [shortFileName $name]"
    if {![winfo ismapped .transfer]} {
        pack .transfer -side bottom -fill x -padx 4 -pady 2 \
            -before .transcript
    }
    .transfer.bar coords progress 1 1 1 9
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

proc app::isClassicMac {} {
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
    # Some standalone Classic Tcl/Tk shells report a nonstandard platform
    # value, but still expose native colon-separated Macintosh paths.
    return [expr {[string first {:} [file join RetroChat Probe]] >= 0}]
}

proc app::transferProfile {} {
    # A moderate 256 KiB payload window keeps 10BASE-T busy without the old
    # 512 KiB burst. The relay now handles nonblocking backpressure correctly.
    if {[isClassicMac]} {return [list 32768 8]}
    if {[info exists ::tcl_platform(platform)] &&
        [string compare $::tcl_platform(platform) "windows"] == 0} {
        return [list 32768 16]
    }
    return [list 65536 32]
}

proc app::eventDelay {} {
    if {[isClassicMac]} {return 1}
    if {[info exists ::tcl_platform(platform)] &&
        [string compare $::tcl_platform(platform) "windows"] == 0} {return 1}
    return 0
}

proc app::fitReceiveFileName {name {suffix ""}} {
    set limit 255
    if {[isClassicMac]} {
        set limit 31
        regsub -all {:} $name {-} name
    }
    set extension [file extension $name]
    set stem [file rootname $name]
    if {$stem == ""} {set stem file}
    set suffixLength [string length $suffix]
    set extensionLength [string length $extension]
    set available [expr {$limit - $extensionLength - $suffixLength}]
    if {$available < 1} {
        # A pathological extension can itself exceed the HFS filename limit.
        # Preserve its dot and final characters while guaranteeing room for
        # one stem character and any collision suffix.
        set extensionBudget [expr {$limit - $suffixLength - 1}]
        if {$extensionBudget < 2} {
            set suffix ""
            set suffixLength 0
            set extensionBudget [expr {$limit - 1}]
        }
        if {$extensionLength > $extensionBudget} {
            set extension ".[string range $extension \
                [expr {$extensionLength - $extensionBudget + 1}] end]"
        }
        set available 1
    }
    if {[string length $stem] > $available} {
        set stem [string range $stem 0 [expr {$available - 1}]]
    }
    return "$stem$suffix$extension"
}

proc app::receiveFilePath {directory name} {
    set suffix ""
    set number 1
    while {1} {
        set candidate [file join $directory [fitReceiveFileName $name $suffix]]
        if {![file exists $candidate]} {return $candidate}
        incr number
        set suffix " $number"
    }
}

proc app::receiveTemporaryPath {path id} {
    # Keep partial names below the Classic Mac OS 31-character limit on every
    # platform. This is harmless elsewhere and avoids relying on inconsistent
    # tcl_platform values in standalone Classic Tcl/Tk shells.
    set token $id
    regsub -all {[^A-Za-z0-9_-]} $token {_} token
    if {$token == ""} {set token transfer}
    if {[string length $token] > 20} {
        set token [string range $token end-19 end]
    }
    return [file join [file dirname $path] "RC-$token.part"]
}

proc app::classicMetadataForExtension {extension} {
    # Classic Mac OS associates documents through four-character HFS type and
    # creator codes. Keep this table independent of the installed applications:
    # setting metadata must never be required for a successful transfer.
    switch -- [string tolower $extension] {
        ".jpg" -
        ".jpeg" {return [list JPEG ogle]}
        ".gif"  {return [list GIFf ogle]}
        ".png"  {return [list PNGf ogle]}
        ".tif" -
        ".tiff" {return [list TIFF ogle]}
        ".pct" -
        ".pict" {return [list PICT ogle]}
        ".mov" -
        ".qt" -
        ".mp4" -
        ".m4v"  {return [list MooV TVOD]}
        ".mpg" -
        ".mpeg" {return [list MPEG TVOD]}
        ".mp3"  {return [list {MP3 } TVOD]}
        ".wav"  {return [list WAVE TVOD]}
        ".aif" -
        ".aiff" -
        ".aifc" {return [list AIFF TVOD]}
        default {return {}}
    }
}

proc app::applyClassicFileMetadata {path} {
    if {![isClassicMac]} {return}
    set metadata [classicMetadataForExtension [file extension $path]]
    if {[llength $metadata] == 2} {
        catch {file attributes $path -type [lindex $metadata 0] \
            -creator [lindex $metadata 1]}
    }
}

proc app::makeClassicJpegCompatible {path} {
    if {![isClassicMac]} {return 0}
    set extension [string tolower [file extension $path]]
    if {$extension != ".jpg" && $extension != ".jpeg"} {return 0}

    # QuickTime's Classic JPEG importer can reject otherwise valid modern
    # JPEGs containing ICC_PROFILE APP2 segments. Copy the JPEG structure
    # without those metadata segments. Image data is never decompressed or
    # recompressed, and the original is retained if parsing is unsuccessful.
    set temporary [file join [file dirname $path] "RC-ICC-[pid].tmp"]
    catch {file delete $temporary}
    if {[catch {
        set input [open $path r]
        set output [open $temporary w]
        fconfigure $input -translation binary -eofchar {}
        fconfigure $output -translation binary -eofchar {}

        set signature [read $input 2]
        binary scan $signature H4 signatureHex
        if {$signatureHex != "ffd8"} {error "not a JPEG file"}
        puts -nonewline $output $signature
        set removed 0

        while {1} {
            set marker [read $input 2]
            if {[string length $marker] != 2} {error "truncated JPEG marker"}
            binary scan $marker H4 markerHex
            if {[string range $markerHex 0 1] != "ff"} {
                error "invalid JPEG marker"
            }
            if {$markerHex == "ffd9"} {
                puts -nonewline $output $marker
                break
            }

            set lengthBytes [read $input 2]
            if {[string length $lengthBytes] != 2} {
                error "truncated JPEG segment length"
            }
            binary scan $lengthBytes H4 lengthHex
            scan $lengthHex %x segmentLength
            if {$segmentLength < 2} {error "invalid JPEG segment length"}
            set payload [read $input [expr {$segmentLength - 2}]]
            if {[string length $payload] != $segmentLength - 2} {
                error "truncated JPEG segment"
            }

            set isIcc [expr {$markerHex == "ffe2" &&
                [string range $payload 0 11] == "ICC_PROFILE\x00"}]
            if {$isIcc} {
                set removed 1
            } else {
                puts -nonewline $output $marker$lengthBytes$payload
            }

            if {$markerHex == "ffda"} {
                while {![eof $input]} {
                    set data [read $input 32768]
                    if {$data != ""} {puts -nonewline $output $data}
                }
                break
            }
        }
        close $input
        close $output
    } problem]} {
        catch {close $input}
        catch {close $output}
        catch {file delete $temporary}
        return 0
    }

    if {$removed} {
        if {[catch {file rename -force $temporary $path}]} {
            catch {file delete $temporary}
            return 0
        }
        return 1
    }
    catch {file delete $temporary}
    return 0
}

proc app::showAbout {} {
    set dialog .retrochatAbout
    if {[winfo exists $dialog]} {
        raise $dialog
        return
    }
    toplevel $dialog
    wm title $dialog "About RetroChat Client"
    wm resizable $dialog 0 0
    if {[winfo ismapped .]} {wm transient $dialog .}

    set iconPath [file join $::here assets icons png client client-128.png]
    if {[file exists $iconPath] &&
        ![catch {image create photo retrochatClientAboutIcon -file $iconPath}]} {
        label $dialog.icon -image retrochatClientAboutIcon
        pack $dialog.icon -side left -padx 20 -pady 20
    }
    frame $dialog.details
    label $dialog.details.name -text "RetroChat Client" -font TkHeadingFont
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
        if {[winfo exists .retrochatAbout] == 0} {
            catch {image delete retrochatClientAboutIcon}
        }
    }
}

proc app::updateReceiveProgress {name received total} {
    variable transferText
    if {$total > 0} {
        set percent [expr {int((double($received) * 100.0) / double($total))}]
    } else {
        set percent 100
    }
    if {$percent > 100} {set percent 100}
    set transferText "Receiving [shortFileName $name]: $percent%"
    if {![winfo ismapped .transfer]} {
        pack .transfer -side bottom -fill x -padx 4 -pady 2 \
            -before .transcript
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

proc app::hideReceiveProgressIfIdle {} {
    variable incoming
    if {[llength [array names incoming]] == 0} {hideSendProgress}
}

proc app::showTransferCanceled {} {
    variable transferText
    set transferText "Transfer canceled"
    .transfer.bar coords progress 1 1 1 9
    .transfer.cancel configure -state disabled
    update idletasks
    after 1200 app::hideSendProgress
}

proc app::closeFileOffer {} {
    variable incomingOffer
    variable incomingOfferTimer
    if {$incomingOfferTimer != ""} {
        catch {after cancel $incomingOfferTimer}
        set incomingOfferTimer ""
    }
    if {[winfo exists .fileOffer]} {destroy .fileOffer}
    set incomingOffer ""
}

proc app::beginIncomingFile {fields} {
    variable incoming
    variable incomingBatch
    variable incomingName
    variable incomingSize
    variable incomingReceived
    variable incomingSequence
    variable incomingAckInterval
    variable incomingPath
    variable incomingTemporary

    set id [lindex $fields 0]
    set name [file tail [lindex $fields 1]]
    set size [lindex $fields 2]
    set batch [lindex $fields 4]
    set path ""

    if {[info exists incomingBatch($batch)] &&
        $incomingBatch($batch) != "" &&
        $incomingBatch($batch) != "offered"} {
        set path [receiveFilePath $incomingBatch($batch) $name]
    }
    if {$path == ""} {
        if {[info exists incomingBatch($batch)] && $incomingBatch($batch) == ""} {
            sendRecord FILE_READY [list $id 0 declined]
        } else {
            sendRecord FILE_READY [list $id 0]
        }
        return
    }

    set temporary [receiveTemporaryPath $path $id]
    if {[catch {open $temporary w} channel]} {
        show "Could not save $name: $channel" error
        sendRecord FILE_READY [list $id 0]
        return
    }

    fconfigure $channel -translation binary -eofchar {}
    set savedName [file tail $path]
    set incoming($id) $channel
    set incomingName($id) $savedName
    set incomingSize($id) $size
    set incomingReceived($id) 0
    set incomingSequence($id) 0
    set incomingPath($id) $path
    set incomingTemporary($id) $temporary
    updateReceiveProgress $savedName 0 $size
    set profile [transferProfile]
    set incomingAckInterval($id) [lindex $profile 1]
    sendRecord FILE_READY [list $id 1 [lindex $profile 0] [lindex $profile 1]]
}

proc app::acceptFileOffer {} {
    variable incomingOffer
    variable incomingBatch

    if {$incomingOffer == ""} {return}
    set fields $incomingOffer
    set name [file tail [lindex $fields 1]]
    set sender [lindex $fields 3]
    set batch [lindex $fields 4]
    closeFileOffer

    set directory ""
    if {[llength [info commands tk_chooseDirectory]]} {
        set directory [tk_chooseDirectory -title "Save files from $sender"]
    } else {
        set chosen [tk_getSaveFile -initialfile [fitReceiveFileName $name] \
            -title "Save files from $sender"]
        if {$chosen != ""} {set directory [file dirname $chosen]}
    }

    if {$directory == ""} {
        set incomingBatch($batch) ""
        sendRecord FILE_READY [list [lindex $fields 0] 0 declined]
        show "Declined files from $sender." system
        return
    }
    set incomingBatch($batch) $directory
    beginIncomingFile $fields
}

proc app::declineFileOffer {} {
    variable incomingOffer
    variable incomingBatch

    if {$incomingOffer == ""} {return}
    set fields $incomingOffer
    set id [lindex $fields 0]
    set sender [lindex $fields 3]
    set batch [lindex $fields 4]
    set incomingBatch($batch) ""
    closeFileOffer
    sendRecord FILE_READY [list $id 0 declined]
    show "Declined files from $sender." system
}

proc app::showFileOffer {fields} {
    variable incomingOffer
    variable incomingOfferTimer
    variable incomingBatchCount

    set incomingOffer $fields
    set name [file tail [lindex $fields 1]]
    set size [lindex $fields 2]
    set sender [lindex $fields 3]
    set batch [lindex $fields 4]
    set count 1
    if {[info exists incomingBatchCount($batch)]} {
        set count $incomingBatchCount($batch)
    }

    if {[winfo exists .fileOffer]} {destroy .fileOffer}
    toplevel .fileOffer
    wm title .fileOffer "Incoming File"
    wm resizable .fileOffer 0 0
    if {[winfo ismapped .]} {wm transient .fileOffer .}
    wm protocol .fileOffer WM_DELETE_WINDOW app::declineFileOffer

    label .fileOffer.heading -text "Incoming file transfer"
    label .fileOffer.sender -text "From: $sender" -anchor w
    label .fileOffer.name -text "File: $name" -anchor w -wraplength 420 \
        -justify left
    label .fileOffer.size -text "Size: [formatByteCount $size] ($size bytes)" \
        -anchor w
    if {$count > 1} {
        label .fileOffer.batch -text "This is the first of $count files." \
            -anchor w
    } else {
        label .fileOffer.batch -text "One file will be received." -anchor w
    }
    label .fileOffer.question -text "Do you want to proceed?" -anchor w
    frame .fileOffer.buttons
    button .fileOffer.buttons.decline -text "Decline" \
        -command app::declineFileOffer
    button .fileOffer.buttons.receive -text "Receive..." -default active \
        -command app::acceptFileOffer
    pack .fileOffer.heading -side top -anchor w -padx 16 -pady 12
    pack .fileOffer.sender .fileOffer.name .fileOffer.size \
        .fileOffer.batch .fileOffer.question -side top -anchor w \
        -fill x -padx 16 -pady 2
    pack .fileOffer.buttons.receive .fileOffer.buttons.decline \
        -side right -padx 4
    pack .fileOffer.buttons -side bottom -fill x -padx 12 -pady 14
    bind .fileOffer <Return> {app::acceptFileOffer}
    bind .fileOffer <Escape> {app::declineFileOffer}
    focus .fileOffer.buttons.receive

    # No grab or tkwait: chat remains usable on both peers while this offer is
    # pending. Expire abandoned offers so the relay lane cannot wait forever.
    set incomingOfferTimer [after 120000 app::declineFileOffer]
}

proc app::cancelTransfer {} {
    variable outgoingChannel
    variable outgoingPaths
    variable outgoingBatch
    variable outgoingTarget
    variable outgoingId
    variable outgoingWaiting
    variable outgoingAckGeneration
    variable outgoingCurrentPath
    variable outgoingRetryCount

    if {$outgoingBatch == ""} {return}
    incr outgoingAckGeneration
    if {$outgoingId != ""} {sendRecord FILE_CANCEL [list $outgoingId]}
    if {$outgoingChannel != ""} {catch {close $outgoingChannel}}
    set outgoingChannel ""
    set outgoingPaths ""
    set outgoingWaiting 0
    sendRecord FILE_BATCH_END [list $outgoingBatch]
    set outgoingBatch ""
    set outgoingTarget ""
    set outgoingCurrentPath ""
    set outgoingRetryCount 0
    updateSendFileState
    show "File transfer canceled." system
    showTransferCanceled
}

proc app::outgoingOfferDeclined {} {
    variable outgoingChannel
    variable outgoingPaths
    variable outgoingBatch
    variable outgoingTarget
    variable outgoingId
    variable outgoingWaiting
    variable outgoingAckGeneration
    variable outgoingCurrentPath
    variable outgoingRetryCount

    incr outgoingAckGeneration
    if {$outgoingChannel != ""} {catch {close $outgoingChannel}}
    set outgoingChannel ""
    set outgoingPaths ""
    set outgoingWaiting 0
    if {$outgoingBatch != ""} {
        catch {sendRecord FILE_BATCH_END [list $outgoingBatch]}
    }
    set outgoingBatch ""
    set outgoingTarget ""
    set outgoingId ""
    set outgoingCurrentPath ""
    set outgoingRetryCount 0
    updateSendFileState
    show "The recipient declined the file transfer." system
    showTransferCanceled
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
    .chat insert end "$line\n" $tag
    .chat see end
}

proc app::transferFailed {problem} {
    variable outgoingChannel
    variable outgoingPaths
    variable outgoingBatch
    variable outgoingTarget
    variable outgoingId
    variable outgoingWaiting
    variable outgoingCurrentPath
    variable outgoingRetryCount

    if {$outgoingId != ""} {
        catch {sendRecord FILE_CANCEL [list $outgoingId]}
    }
    if {$outgoingBatch != ""} {
        catch {sendRecord FILE_BATCH_END [list $outgoingBatch]}
    }
    if {$outgoingChannel != ""} {catch {close $outgoingChannel}}
    set outgoingChannel ""
    set outgoingPaths ""
    set outgoingBatch ""
    set outgoingTarget ""
    set outgoingId ""
    set outgoingWaiting 0
    set outgoingCurrentPath ""
    set outgoingRetryCount 0
    updateSendFileState
    show "File transfer failed: $problem" error
    set ::app::transferText "Transfer failed"
    .transfer.cancel configure -state disabled
    after 1200 app::hideSendProgress
}

proc app::runTransferStep {command} {
    if {[catch {uplevel #0 $command} problem]} {
        transferFailed $problem
    }
}

proc app::scheduleTransferStep {delay command} {
    after $delay [list app::runTransferStep $command]
}

proc app::receiveTransferFailed {command fields problem} {
    variable incoming
    set id ""
    if {[llength $fields] > 0} {set id [lindex $fields 0]}
    if {$id != "" && [info exists incoming($id)]} {
        failIncomingFile $id "$problem; retry requested."
    } else {
        # FILE_BEGIN may fail before its destination channel is registered.
        # Reject only this file and retain incomingBatch so a fresh FILE_BEGIN
        # can reuse the already selected destination without user interaction.
        if {$id != ""} {catch {sendRecord FILE_READY [list $id 0]}}
        show "File transfer failed: $problem" error
        set ::app::transferText "Transfer failed"
        .transfer.cancel configure -state disabled
        after 1200 app::hideSendProgress
    }
}

proc app::failIncomingFile {id message} {
    variable incoming
    variable incomingName
    variable incomingSize
    variable incomingReceived
    variable incomingSequence
    variable incomingAckInterval
    variable incomingPath
    variable incomingTemporary

    set name "file"
    if {[info exists incomingName($id)]} {set name $incomingName($id)}
    if {[info exists incoming($id)] && $incoming($id) != ""} {
        catch {close $incoming($id)}
    }
    if {[info exists incomingTemporary($id)]} {
        catch {file delete $incomingTemporary($id)}
    }
    catch {sendRecord FILE_CANCEL [list $id]}
    catch {unset incoming($id)}
    catch {unset incomingName($id)}
    catch {unset incomingSize($id)}
    catch {unset incomingReceived($id)}
    catch {unset incomingSequence($id)}
    catch {unset incomingAckInterval($id)}
    catch {unset incomingPath($id)}
    catch {unset incomingTemporary($id)}
    show "Transfer failed for $name: $message" error
    showTransferCanceled
}

proc app::sendRecord {command fields} {
    variable sock

    if {$sock == ""} {
        return 0
    }

    if {[catch {
        puts $sock [retrochat::makeRecord $command $fields]
    } problem]} {
        # A transfer-control write can fail while a legacy peer or relay is
        # unwinding that transfer. Do not tear down an otherwise usable chat
        # connection; the readable callback will disconnect only on real EOF.
        if {[string match "FILE_*" $command]} {
            show "File transfer signaling failed: $problem" error
            return 0
        }
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
    variable channel

    if {$connected} {
        return
    }

    if {[catch {socket $host $port} sockChannel]} {
        set status "Connection failed"
        show "Could not connect: $sockChannel" error
        return
    }

    set sock $sockChannel
    fconfigure $sock -blocking 0 -buffering line -translation lf
    fileevent $sock readable app::readable

    set connected 1
    set status "Connected to $host:$port"

    if {![sendRecord HELLO [list $nickname 1]]} {return}
    if {![sendRecord LIST_CHANNELS [list]]} {return}
    if {![sendRecord JOIN [list $channel]]} {return}
    show "Connected." system

    .connect configure -text "Disconnect" -state normal
    updateSendFileState
    .channels.new configure -state normal
    .channels.delete configure -state normal
}

proc app::toggleConnection {} {
    variable connected
    if {$connected} {
        disconnect
    } else {
        connect
    }
}

proc app::selectedChannel {} {
    variable selectedRoom
    return $selectedRoom
}

proc app::showChannels {} {
    variable channel
    variable channelNames
    variable selectedRoom
    .channels.list delete 1.0 end
    set line 1
    foreach room $channelNames {
        .channels.list insert end "$room\n"
        if {$room == $channel} {
            .channels.list tag add currentChannel "$line.0" "$line.end"
        }
        if {$room == $selectedRoom} {
            .channels.list tag add selectedChannel "$line.0" "$line.end"
        }
        incr line
    }
}

proc app::updateSendFileState {} {
    variable connected
    variable selectedUserId
    variable selfUserId
    if {$connected && $selectedUserId != "" &&
        $selectedUserId != $selfUserId} {
        .users.sendfile configure -state normal
    } else {
        .users.sendfile configure -state disabled
    }
}

proc app::showUsers {} {
    variable userIds
    variable userNames
    variable selfUserId
    variable selectedUserId
    .users.list delete 0 end
    set index 0
    foreach id $userIds name $userNames {
        if {$id == $selfUserId} {
            .users.list insert end "$name (you)"
        } else {
            .users.list insert end $name
        }
        if {$id == $selectedUserId} {.users.list selection set $index}
        incr index
    }
    if {[lsearch -exact $userIds $selectedUserId] < 0 ||
        $selectedUserId == $selfUserId} {
        set selectedUserId ""
        .users.list selection clear 0 end
    }
    updateSendFileState
}

proc app::outgoingTargetAvailable {} {
    variable outgoingTarget
    variable userIds
    return [expr {$outgoingTarget != "" &&
        [lsearch -exact $userIds $outgoingTarget] >= 0}]
}

proc app::selectUser {} {
    variable userIds
    variable selectedUserId
    set selection [.users.list curselection]
    if {[llength $selection] == 0} {
        set selectedUserId ""
    } else {
        set selectedUserId [lindex $userIds [lindex $selection 0]]
    }
    updateSendFileState
}

proc app::channelAt {y} {
    variable channelNames
    set line [lindex [split [.channels.list index "@0,$y"] .] 0]
    if {$line < 1 || $line > [llength $channelNames]} {return ""}
    return [lindex $channelNames [expr {$line - 1}]]
}

proc app::channelClick {y eventTime} {
    variable selectedRoom
    variable lastChannelClickRoom
    variable lastChannelClickTime

    set room [channelAt $y]
    set isDouble [expr {$room != "" && $room == $lastChannelClickRoom &&
        $eventTime >= $lastChannelClickTime &&
        $eventTime - $lastChannelClickTime <= 800}]
    set selectedRoom $room
    .channels.list tag remove selectedChannel 1.0 end
    if {$selectedRoom != ""} {
        set line [expr {[lsearch -exact $::app::channelNames $selectedRoom] + 1}]
        .channels.list tag add selectedChannel "$line.0" "$line.end"
    }
    set lastChannelClickRoom $room
    set lastChannelClickTime $eventTime
    if {$isDouble} {
        set lastChannelClickRoom ""
        set lastChannelClickTime 0
        joinChannel $room
    }
}

proc app::newChannel {} {
    variable newChannelName
    variable newChannelDone

    set newChannelName ""
    set newChannelDone 0
    catch {destroy .newChannel}
    toplevel .newChannel
    wm title .newChannel "New Channel"
    wm transient .newChannel .
    wm protocol .newChannel WM_DELETE_WINDOW {set ::app::newChannelDone 1}
    label .newChannel.label -text "Channel name:" -anchor w
    entry .newChannel.name -textvariable app::newChannelName -width 28
    frame .newChannel.buttons
    button .newChannel.buttons.create -text "Create" -command {
        set ::app::newChannelName [string trim $::app::newChannelName]
        if {[string tolower $::app::newChannelName] == "other"} {
            tk_messageBox -icon error -title "New Channel" \
                -message {"Other" is not a channel. Choose another name.}
        } elseif {$::app::newChannelName != ""} {
            set ::app::newChannelDone 2
        }
    }
    button .newChannel.buttons.cancel -text "Cancel" \
        -command {set ::app::newChannelDone 1}
    pack .newChannel.label -side top -fill x -padx 8 -pady 4
    pack .newChannel.name -side top -fill x -padx 8 -pady 4
    pack .newChannel.buttons.cancel .newChannel.buttons.create \
        -side right -padx 4
    pack .newChannel.buttons -side bottom -fill x -padx 4 -pady 8
    bind .newChannel.name <Return> {
        set ::app::newChannelName [string trim $::app::newChannelName]
        if {[string tolower $::app::newChannelName] == "other"} {
            tk_messageBox -icon error -title "New Channel" \
                -message {"Other" is not a channel. Choose another name.}
        } elseif {$::app::newChannelName != ""} {
            set ::app::newChannelDone 2
        }
    }
    grab .newChannel
    focus .newChannel.name
    tkwait variable ::app::newChannelDone
    grab release .newChannel
    destroy .newChannel
    if {$newChannelDone == 2} {joinChannel $newChannelName}
}

proc app::deleteSelectedChannel {} {
    set room [selectedChannel]
    if {$room == ""} {return}
    if {$room == "Lobby"} {
        tk_messageBox -icon error -title "Delete Channel" \
            -message "Lobby cannot be deleted."
        return
    }
    set answer [tk_messageBox -icon question -type yesno \
        -title "Delete Channel" \
        -message "Are you sure?\n\nDelete $room and all of its history?"]
    if {$answer == "yes"} {
        sendRecord DELETE_CHANNEL [list $room]
    }
}

proc app::joinChannel {{room ""}} {
    variable channel
    variable connected
    set room [string trim $room]
    if {$connected} {
        sendRecord JOIN [list $room]
    }
}

proc app::disconnect {} {
    variable sock
    variable connected
    variable status
    variable outgoingChannel
    variable outgoingPaths
    variable outgoingBatch
    variable outgoingTarget
    variable outgoingCurrentPath
    variable outgoingRetryCount

    closeFileOffer

    if {$sock != ""} {
        catch {fileevent $sock readable {}}
        catch {close $sock}
    }

    set sock ""
    if {$outgoingChannel != ""} {catch {close $outgoingChannel}}
    set outgoingChannel ""
    set outgoingPaths ""
    set outgoingBatch ""
    set outgoingTarget ""
    set outgoingCurrentPath ""
    set outgoingRetryCount 0
    set connected 0
    set status "Disconnected"

    .connect configure -text "Connect" -state normal
    .users.sendfile configure -state disabled
    set ::app::userIds ""
    set ::app::userNames ""
    set ::app::selectedUserId ""
    set ::app::selfUserId ""
    catch {.users.list delete 0 end}
    .channels.new configure -state disabled
    .channels.delete configure -state disabled
}

proc app::quit {} {
    disconnect
    destroy .
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
            after 5 app::resumeReadable
        }
        return
    }

    if {[catch {retrochat::parseRecord $line} parsed]} {
        if {$sock != ""} {
            after 5 app::resumeReadable
        }
        return
    }

    set command [lindex $parsed 0]
    set recordFields [lindex $parsed 1]
    if {[catch {receive $command $recordFields} problem]} {
        if {[string match "FILE_*" $command]} {
            receiveTransferFailed $command $recordFields $problem
        } else {
            show "Could not process server message: $problem" error
        }
    }

    if {$sock != ""} {
        # A backed-up socket can otherwise invoke readable continuously and
        # starve the Windows 95/98 paint and input message queue.
        if {$command == "FILE_CHUNK"} {
            after [eventDelay] app::resumeReadable
        } else {
            after [eventDelay] app::resumeReadable
        }
    }
}

proc app::resumeReadable {} {
    variable sock
    if {$sock != ""} {fileevent $sock readable app::readable}
}

proc app::receive {command fields} {
    variable incoming
    variable incomingBatch
    variable incomingName
    variable incomingSize
    variable incomingReceived
    variable incomingSequence
    variable incomingAckInterval
    variable incomingPath
    variable incomingTemporary
    variable outgoingWaiting
    variable outgoingId
    variable outgoingSequence

    if {$command == "CHAT" && [llength $fields] == 2} {
        show "<[lindex $fields 0]> [lindex $fields 1]"
    } elseif {$command == "SELF" && [llength $fields] == 2} {
        set ::app::selfUserId [lindex $fields 0]
        app::showUsers
    } elseif {$command == "USERS"} {
        set ::app::userIds ""
        set ::app::userNames ""
        set index 0
        while {$index + 1 < [llength $fields]} {
            lappend ::app::userIds [lindex $fields $index]
            lappend ::app::userNames [lindex $fields [expr {$index + 1}]]
            incr index 2
        }
        app::showUsers
    } elseif {$command == "CHANNELS"} {
        set ::app::channelNames ""
        foreach room $fields {
            if {[string tolower $room] != "other" &&
                [string tolower $room] != "sideroom"} {
                lappend ::app::channelNames $room
            }
        }
        if {[lsearch -exact $fields $::app::selectedRoom] < 0} {
            set ::app::selectedRoom $::app::channel
        }
        app::showChannels
    } elseif {$command == "JOINED" && [llength $fields] == 1} {
        set ::app::channel [lindex $fields 0]
        set ::app::selectedRoom $::app::channel
        app::showChannels
        set ::app::status "Connected to $::app::host:$::app::port - $::app::channel"
        show "Joined channel $::app::channel." system
    } elseif {$command == "HISTORY_BEGIN" && [llength $fields] == 1} {
        .chat delete 1.0 end
    } elseif {$command == "HISTORY_CHAT" && [llength $fields] == 2} {
        show "<[lindex $fields 0]> [lindex $fields 1]"
    } elseif {$command == "HISTORY_END" && [llength $fields] == 1} {
        show "History loaded for [lindex $fields 0]." system
    } elseif {$command == "ERROR" && [llength $fields] == 1} {
        set message [lindex $fields 0]
        # A batch can be rejected before its first FILE_BEGIN when the chosen
        # peer left or reconnected while the native file picker was open.
        # Stop the queued send callback as well as reporting the rejection;
        # otherwise it retries a target the server has already rejected and
        # can later display a contradictory "Sent" result.
        if {$message == "Selected user is no longer in this channel" &&
            $::app::outgoingBatch != ""} {
            transferFailed $message
        } else {
            show $message error
        }
    } elseif {$command == "FILE_BATCH_BEGIN" && [llength $fields] == 3} {
        set batch [lindex $fields 0]
        set count [lindex $fields 1]
        set sender [lindex $fields 2]
        set incomingBatch($batch) offered
        set ::app::incomingBatchCount($batch) $count
        set ::app::incomingBatchSender($batch) $sender
    } elseif {$command == "FILE_BEGIN" && [llength $fields] == 5} {
        set id [lindex $fields 0]
        set batch [lindex $fields 4]
        if {[info exists incomingBatch($batch)] &&
            $incomingBatch($batch) == "offered"} {
            showFileOffer $fields
        } else {
            beginIncomingFile $fields
        }
    } elseif {$command == "FILE_CHUNK" && [llength $fields] == 3} {
        set id [lindex $fields 0]

        if {[info exists incoming($id)] && $incoming($id) != ""} {
            set sequence [lindex $fields 1]
            set chunk [lindex $fields 2]
            if {$sequence != $incomingSequence($id)} {
                failIncomingFile $id "missing or out-of-order data; retry requested."
            } elseif {[catch {puts -nonewline $incoming($id) $chunk} problem]} {
                failIncomingFile $id "$problem; retry requested."
            } else {
                incr incomingSequence($id)
                incr incomingReceived($id) [string length $chunk]
                if {$incomingReceived($id) > $incomingSize($id)} {
                    failIncomingFile $id "received too much data; retry requested."
                    return
                }
                if {$incomingSequence($id) % $incomingAckInterval($id) == 0 ||
                    $incomingReceived($id) == $incomingSize($id)} {
                    sendRecord FILE_ACK [list $id $incomingSequence($id)]
                }
                if {$incomingReceived($id) == $incomingSize($id) ||
                    $incomingReceived($id) % 65536 < [string length $chunk]} {
                    updateReceiveProgress $incomingName($id) \
                        $incomingReceived($id) $incomingSize($id)
                }
            }
        }
    } elseif {$command == "FILE_READY" && [llength $fields] >= 2} {
        if {[lindex $fields 0] == $outgoingId && $outgoingWaiting} {
            if {[lindex $fields 1]} {
                if {[llength $fields] >= 3} {
                    set proposed [lindex $fields 2]
                    if {$proposed >= 4096 && $proposed <= 65536} {
                        set ::app::outgoingChunkSize $proposed
                    }
                }
                if {[llength $fields] >= 4} {
                    set proposed [lindex $fields 3]
                    if {$proposed >= 1 && $proposed <= 64} {
                        set ::app::outgoingWindow $proposed
                    }
                }
                set outgoingWaiting 0
                scheduleTransferStep [eventDelay] app::sendFileChunk
            } elseif {[llength $fields] >= 3 &&
                [lindex $fields 2] == "declined"} {
                outgoingOfferDeclined
            } else {
                catch {close $::app::outgoingChannel}
                set ::app::outgoingChannel ""
                set outgoingWaiting 0
                if {[outgoingTargetAvailable] &&
                    $::app::outgoingRetryCount < 1 &&
                    $::app::outgoingCurrentPath != ""} {
                    incr ::app::outgoingRetryCount
                    set ::app::outgoingPaths [linsert \
                        $::app::outgoingPaths 0 $::app::outgoingCurrentPath]
                    show "Retrying $::app::outgoingName once." system
                } else {
                    show "No client accepted $::app::outgoingName after retry." error
                    set ::app::outgoingCurrentPath ""
                    set ::app::outgoingRetryCount 0
                }
                scheduleTransferStep 1 app::sendNextFile
            }
        }
    } elseif {$command == "FILE_ACK" && [llength $fields] == 2} {
        if {[lindex $fields 0] == $outgoingId &&
            [lindex $fields 1] <= $outgoingSequence} {
            set acknowledged [lindex $fields 1]
            if {$acknowledged > $::app::outgoingAcknowledged} {
                set ::app::outgoingAcknowledged $acknowledged
            }
            # The normal send loop is already scheduled. Only restart it when
            # flow control actually paused at the negotiated window; otherwise
            # every ACK creates another competing send callback.
            if {$outgoingWaiting} {
                set outgoingWaiting 0
                scheduleTransferStep [eventDelay] app::sendFileChunk
            }
        }
    } elseif {$command == "FILE_PROGRESS" && [llength $fields] == 2} {
        if {[lindex $fields 0] == $outgoingId &&
            [info exists ::app::outgoingSize] &&
            [info exists ::app::outgoingName]} {
            set delivered [lindex $fields 1]
            if {$delivered < 0} {set delivered 0}
            if {$delivered > $::app::outgoingSize} {
                set delivered $::app::outgoingSize
            }
            updateSendProgress $::app::outgoingName $delivered \
                $::app::outgoingSize
        }
    } elseif {$command == "FILE_DELIVERED" && [llength $fields] == 2} {
        if {[lindex $fields 0] == $outgoingId} {
            set succeeded [expr {[lindex $fields 1] != 0}]
            set outgoingWaiting 0
            if {$succeeded} {
                updateSendProgress $::app::outgoingName \
                    $::app::outgoingSize $::app::outgoingSize
                show "Sent $::app::outgoingName ($::app::outgoingSize bytes)." system
                set ::app::outgoingCurrentPath ""
                set ::app::outgoingRetryCount 0
            } else {
                if {[outgoingTargetAvailable] &&
                    $::app::outgoingRetryCount < 1 &&
                    $::app::outgoingCurrentPath != ""} {
                    incr ::app::outgoingRetryCount
                    set ::app::outgoingPaths [linsert \
                        $::app::outgoingPaths 0 $::app::outgoingCurrentPath]
                    show "Retrying $::app::outgoingName once." system
                } else {
                    show "The recipient could not receive $::app::outgoingName after retry." error
                    set ::app::outgoingCurrentPath ""
                    set ::app::outgoingRetryCount 0
                }
            }
            set ::app::outgoingId ""
            scheduleTransferStep 1 app::sendNextFile
        }
    } elseif {$command == "FILE_CANCEL" && [llength $fields] == 1} {
        set id [lindex $fields 0]
        if {$::app::incomingOffer != "" &&
            [lindex $::app::incomingOffer 0] == $id} {
            closeFileOffer
        }
        if {[info exists incoming($id)]} {
            if {$incoming($id) != ""} {
                catch {close $incoming($id)}
                catch {file delete $incomingTemporary($id)}
                show "Transfer canceled: $incomingName($id)." system
            }
            unset incoming($id)
            catch {unset incomingName($id)}
            catch {unset incomingSize($id)}
            catch {unset incomingReceived($id)}
            catch {unset incomingSequence($id)}
            catch {unset incomingAckInterval($id)}
            catch {unset incomingPath($id)}
            catch {unset incomingTemporary($id)}
        }
        showTransferCanceled
    } elseif {$command == "FILE_END" && [llength $fields] == 3} {
        set id [lindex $fields 0]
        set sentSize [lindex $fields 1]
        set succeeded 0
        if {[info exists incoming($id)]} {
            if {$incoming($id) != ""} {
                set valid [expr {$sentSize == $incomingSize($id) &&
                    $incomingReceived($id) == $incomingSize($id)}]
                if {[catch {close $incoming($id)} problem]} {set valid 0}
                set temporary $incomingTemporary($id)
                if {$valid && ![catch {file rename -force $temporary \
                    $incomingPath($id)} problem]} {
                    makeClassicJpegCompatible $incomingPath($id)
                    applyClassicFileMetadata $incomingPath($id)
                    show "Received $incomingName($id)." system
                    set succeeded 1
                } else {
                    catch {file delete $temporary}
                    show "Transfer failed size or sequence check for $incomingName($id); no incomplete file was saved." error
                }
            }

            unset incoming($id)
            catch {unset incomingName($id)}
            catch {unset incomingSize($id)}
            catch {unset incomingReceived($id)}
            catch {unset incomingSequence($id)}
            catch {unset incomingAckInterval($id)}
            catch {unset incomingPath($id)}
            catch {unset incomingTemporary($id)}
            after 400 app::hideReceiveProgressIfIdle
        }
        sendRecord FILE_RECEIVED [list $id $succeeded]
    } elseif {$command == "FILE_BATCH_END" && [llength $fields] == 1} {
        set batch [lindex $fields 0]
        catch {unset incomingBatch($batch)}
        catch {unset ::app::incomingBatchCount($batch)}
        catch {unset ::app::incomingBatchSender($batch)}
    }
}

proc app::sendChat {} {
    variable nickname

    set message [.compose.message get 1.0 end-1c]
    if {$message == ""} {
        return
    }

    if {[sendRecord CHAT [list $nickname $message]]} {
        .compose.message delete 1.0 end
    }
}

proc app::sendFile {} {
    variable nextTransfer
    variable nickname
    variable outgoingPaths
    variable outgoingBatch
    variable selectedUserId
    variable outgoingTarget
    variable userIds
    variable userNames

    if {$selectedUserId == "" || $selectedUserId == $::app::selfUserId} {
        tk_messageBox -icon info -title "Send Files" \
            -message "Select another user in this channel first."
        return
    }

    # Remember both identity and display name before entering the native file
    # dialog. Its nested event loop can process a USERS update if the selected
    # peer reconnects while the dialog is open.
    set chosenTarget $selectedUserId
    set chosenIndex [lsearch -exact $userIds $chosenTarget]
    if {$chosenIndex < 0} {
        set selectedUserId ""
        showUsers
        show "Selected user is no longer in this channel." error
        return
    }
    set chosenName [lindex $userNames $chosenIndex]

    set paths ""
    if {[catch {tk_getOpenFile -title "Send files" -multiple 1} selected]} {
        set paths [chooseMultipleFiles]
    } else {
        set paths $selected
    }
    if {[llength $paths] == 0} {
        return
    }

    # Prefer the same connection. If it reconnected, follow the same unique
    # nickname to its fresh server-issued id. Never send a known-stale id.
    if {[lsearch -exact $userIds $chosenTarget] < 0} {
        set matches ""
        set index 0
        foreach name $userNames {
            if {$name == $chosenName} {lappend matches $index}
            incr index
        }
        if {[llength $matches] == 1} {
            set chosenTarget [lindex $userIds [lindex $matches 0]]
            set selectedUserId $chosenTarget
            showUsers
        } else {
            show "Selected user is no longer in this channel." error
            updateSendFileState
            return
        }
    }

    incr nextTransfer
    set outgoingBatch "[clock seconds]-$nextTransfer"
    set outgoingTarget $chosenTarget
    set ::app::outgoingId ""
    if {![sendRecord FILE_BATCH_BEGIN \
        [list $outgoingBatch [llength $paths] $nickname \
            $chosenTarget]]} {return}
    set outgoingPaths $paths
    .users.sendfile configure -state disabled
    .transfer.cancel configure -state normal
    scheduleTransferStep 1 app::sendNextFile
}

proc app::sendNextFile {} {
    variable outgoingPaths
    variable outgoingBatch
    variable outgoingChannel
    variable outgoingId
    variable outgoingName
    variable outgoingSize
    variable outgoingSent
    variable outgoingSequence
    variable outgoingWaiting
    variable outgoingAckGeneration
    variable outgoingAcknowledged
    variable outgoingChunkSize
    variable outgoingWindow
    variable nextTransfer
    variable nickname
    variable outgoingTarget
    variable outgoingCurrentPath
    variable outgoingRetryCount

    # A server rejection may cancel the batch while this callback is already
    # queued by the Tk event loop.
    if {$outgoingBatch == ""} {
        updateSendFileState
        return
    }

    if {[llength $outgoingPaths] == 0} {
        sendRecord FILE_BATCH_END [list $outgoingBatch]
        set outgoingBatch ""
        set outgoingTarget ""
        set outgoingId ""
        set outgoingCurrentPath ""
        set outgoingRetryCount 0
        updateSendFileState
        after 400 app::hideSendProgress
        return
    }
    set path [lindex $outgoingPaths 0]
    set outgoingPaths [lrange $outgoingPaths 1 end]
    if {$path != $outgoingCurrentPath} {
        set outgoingCurrentPath $path
        set outgoingRetryCount 0
    }

    if {[catch {open $path r} outgoingChannel]} {
        show "Could not open file: $outgoingChannel" error
        set outgoingChannel ""
        set outgoingCurrentPath ""
        set outgoingRetryCount 0
        scheduleTransferStep 1 app::sendNextFile
        return
    }
    fconfigure $outgoingChannel -translation binary -eofchar {}

    incr nextTransfer
    set outgoingId "[clock seconds]-$nextTransfer"
    set outgoingSize [file size $path]
    set outgoingName [file tail $path]
    set outgoingSent 0
    set outgoingSequence 0
    set outgoingAcknowledged 0
    set outgoingChunkSize 16384
    set outgoingWindow 8
    set outgoingWaiting 1
    incr outgoingAckGeneration

    if {![sendRecord FILE_BEGIN \
        [list $outgoingId $outgoingName $outgoingSize $nickname \
            $outgoingBatch $outgoingTarget]]} {
        catch {close $outgoingChannel}
        set outgoingChannel ""
        return
    }
    showSendWaiting $outgoingName
}

proc app::releaseSendWait {generation} {
    variable outgoingAckGeneration
    variable outgoingWaiting
    variable outgoingChannel
    variable outgoingSequence
    variable outgoingAcknowledged
    if {$generation == $outgoingAckGeneration && $outgoingWaiting &&
        $outgoingChannel != ""} {
        set outgoingWaiting 0
        set outgoingAcknowledged $outgoingSequence
        scheduleTransferStep [eventDelay] app::sendFileChunk
    }
}

proc app::sendFileChunk {} {
    variable outgoingChannel
    variable outgoingId
    variable outgoingName
    variable outgoingSize
    variable outgoingSent
    variable outgoingSequence
    variable outgoingWaiting
    variable outgoingAckGeneration
    variable outgoingAcknowledged
    variable outgoingChunkSize
    variable outgoingWindow

    if {$outgoingChannel == "" || $outgoingWaiting} {return}
    # Hex encoding doubles each record. 16 KiB keeps parsing responsive on
    # Classic Mac Tcl while an eight-chunk window still fills 10BASE-T well.
    set chunk [read $outgoingChannel $outgoingChunkSize]
    if {$chunk != ""} {
        if {![sendRecord FILE_CHUNK \
            [list $outgoingId $outgoingSequence $chunk]]} {
            catch {close $outgoingChannel}
            set outgoingChannel ""
            return
        }
        incr outgoingSequence
        incr outgoingSent [string length $chunk]
        if {$outgoingSequence - $outgoingAcknowledged >= $outgoingWindow} {
            set outgoingWaiting 1
            incr outgoingAckGeneration
        }
        if {!$outgoingWaiting} {
            scheduleTransferStep [eventDelay] app::sendFileChunk
        }
        return
    }

    if {![eof $outgoingChannel]} {
        scheduleTransferStep 5 app::sendFileChunk
        return
    }
    close $outgoingChannel
    set outgoingChannel ""
    # Retain the third field for compatibility with installed peers. Ordered
    # sequences, exact byte counts, and TCP provide transfer integrity without
    # an interpreted checksum on a 1990s processor.
    if {[sendRecord FILE_END [list $outgoingId $outgoingSent none]]} {
        # The server now reports recipient-side progress. Do not advance the
        # batch until the destination confirms that it accepted the file.
        set outgoingWaiting 1
    }
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
set uiSelectionForeground "#ffffff"
set uiError "#cc0000"

set uiButtonBackground "#d8d8d8"
set uiButtonForeground "#101010"
set uiButtonActive "#b0b0b0"
set uiButtonDisabled "#787878"

# Identify NetBSD/mac68k only for compact sizing. Its one-bit X color mapping
# is controlled by the X server; RetroChat does not attempt to invert it.
set uiNetBSDMac68k 0
if {[info exists ::tcl_platform(os)] &&
    [string compare $::tcl_platform(os) "NetBSD"] == 0 &&
    [info exists ::tcl_platform(machine)] &&
    ([string match "m68k*" $::tcl_platform(machine)] ||
     [string match "mac68k*" $::tcl_platform(machine)] ||
     [string match "m680*" $::tcl_platform(machine)])} {
    set uiNetBSDMac68k 1
}

option add *background $uiBackground
option add *foreground $uiForeground
option add *activeBackground $uiSurface
option add *activeForeground $uiForeground
option add *highlightBackground $uiBackground
option add *highlightColor $uiAccent
option add *selectBackground $uiSelection
option add *selectForeground $uiSelectionForeground
option add *insertBackground $uiForeground

option add *Entry.background $uiField
option add *Text.background $uiField
option add *Listbox.background $uiField

option add *Button.background $uiButtonBackground
option add *Button.foreground $uiButtonForeground
option add *Button.activeBackground $uiButtonActive
option add *Button.activeForeground $uiButtonForeground
option add *Button.disabledForeground $uiButtonDisabled

# The mac68k X framebuffer is normally 640x480 to 1152x870. Its default X
# resources can select an unusually large font, which makes character-sized
# Tk widgets grow beyond the screen. Keep this target compact without changing
# the appearance on any other platform.
if {$uiNetBSDMac68k} {
    foreach uiFont {TkDefaultFont TkTextFont TkFixedFont TkMenuFont
                    TkHeadingFont TkCaptionFont TkSmallCaptionFont
                    TkIconFont TkTooltipFont} {
        catch {font configure $uiFont -size 10}
    }
}

proc app::fitWindowToScreen {window marginX marginY} {
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

wm title . "RetroChat"
if {$uiNetBSDMac68k} {
    wm minsize . 520 340
} else {
    wm minsize . 640 420
}

if {[info exists tcl_platform(os)] &&
    [string compare $tcl_platform(os) "Darwin"] == 0 &&
    ![app::isClassicMac]} {
    # Tk 9 invokes this documented global hook from the application menu.
    proc tkAboutDialog {} {app::showAbout}
}

if {[app::isClassicMac]} {
    menu .menubar -tearoff 0
    menu .menubar.file -tearoff 0
    .menubar add cascade -label "File" -menu .menubar.file
    .menubar.file add command -label "Quit" -accelerator "Command-Q" \
        -command app::quit
    . configure -menu .menubar
    catch {bind all <Command-q> app::quit}
}

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
    -width 10 \
    -command app::toggleConnection

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
    -in .connection \
    -side left \
    -padx 4 \
    -pady 8

pack .connection \
    -side top \
    -fill x

frame .transcript

frame .sidebar
frame .channels
label .channels.title -text "Channels" -anchor w
text .channels.list -height 5 -width 18 -wrap none \
    -cursor arrow -takefocus 1
font create channelCurrentFont \
    -family [font actual [.channels.list cget -font] -family] \
    -size [font actual [.channels.list cget -font] -size] \
    -slant [font actual [.channels.list cget -font] -slant] \
    -underline [font actual [.channels.list cget -font] -underline] \
    -overstrike [font actual [.channels.list cget -font] -overstrike] \
    -weight bold
scrollbar .channels.scroll -command {.channels.list yview}
.channels.list configure -yscrollcommand {.channels.scroll set}
.channels.list tag configure currentChannel -font channelCurrentFont
.channels.list tag configure selectedChannel -background $uiSelection \
    -foreground $uiSelectionForeground
button .channels.new -text "New..." -command app::newChannel \
    -state disabled
button .channels.delete -text "Delete..." -command app::deleteSelectedChannel \
    -state disabled
pack .channels.title -side top -fill x -padx 4 -pady 2
pack .channels.scroll -side right -fill y
pack .channels.list -side top -fill both -expand 1 -padx 4
pack .channels.new .channels.delete -side left -padx 3 -pady 4
bind .channels.list <ButtonRelease-1> {app::channelClick %y %t; break}
bind .channels.list <Key> {break}
bind .channels.list <<Paste>> {break}
bind .channels.list <<Cut>> {break}
pack .channels -in .sidebar -side top -fill both -expand 1

frame .users
label .users.title -text "Users in Channel" -anchor w
listbox .users.list -height 5 -width 18 -exportselection 0 \
    -background $uiField -foreground $uiForeground \
    -selectbackground $uiSelection -selectforeground $uiSelectionForeground
scrollbar .users.scroll -command {.users.list yview}
.users.list configure -yscrollcommand {.users.scroll set}
button .users.sendfile \
    -text "Send Files..." \
    -command {app::runTransferStep app::sendFile} \
    -state disabled
pack .users.title -side top -fill x -padx 4 -pady 2
pack .users.scroll -side right -fill y
pack .users.list -side top -fill both -expand 1 -padx 4 -pady 2
pack .users.sendfile -side bottom -fill x -padx 4 -pady 4
bind .users.list <ButtonRelease-1> {after 1 app::selectUser}
bind .users.list <KeyRelease> {after 1 app::selectUser}
pack .users -in .sidebar -side top -fill both -expand 1
pack .sidebar -side left -fill y

text .chat \
    -width 72 \
    -height 22 \
    -wrap word \
    -state normal \
    -background $uiField \
    -foreground $uiForeground \
    -insertbackground $uiForeground \
    -selectbackground $uiSelection \
    -selectforeground $uiSelectionForeground \
    -borderwidth 0 \
    -padx 8 \
    -pady 8

font create systemMessageFont \
    -family [font actual [.chat cget -font] -family] \
    -size [font actual [.chat cget -font] -size] \
    -weight [font actual [.chat cget -font] -weight] \
    -slant italic

.chat tag configure system \
    -foreground $uiMuted \
    -font systemMessageFont

.chat tag configure error \
    -foreground $uiError

scrollbar .scroll \
    -command ".chat yview"

.chat configure \
    -yscrollcommand ".scroll set"

# Keep the transcript read-only while retaining ordinary mouse selection and
# platform copy shortcuts (Command-C, Control-C, and the Edit menu).
bind .chat <Key> {break}
bind .chat <<Paste>> {break}
bind .chat <<Cut>> {break}
bind .chat <Control-Key-c> {tk_textCopy %W; break}
catch {bind .chat <Command-Key-c> {tk_textCopy %W; break}}

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
button .transfer.cancel -text "Cancel" -command app::cancelTransfer
pack .transfer.cancel -side right -padx 4
pack .transfer.bar -side right -fill x -expand 1 -padx 4

frame .compose

text .compose.message \
    -height 3 \
    -width 40 \
    -wrap word \
    -font [.connection.host cget -font] \
    -background $uiField \
    -foreground $uiForeground \
    -insertbackground $uiForeground \
    -selectbackground $uiSelection \
    -selectforeground $uiSelectionForeground

button .compose.send \
    -text "Send" \
    -command app::sendChat

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
    -side bottom \
    -fill x \
    -before .transcript

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
    -fill x \
    -before .compose

bind .compose.message <Control-Return> {
    app::sendChat
    break
}

wm protocol . WM_DELETE_WINDOW app::quit

if {$uiNetBSDMac68k} {
    after idle {app::fitWindowToScreen . 12 36}
}

focus .compose.message
