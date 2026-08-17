wm withdraw .
catch {console hide}

proc restoreComponent {source target backupDirectory} {
    set backup [file join $backupDirectory [file tail $target]]
    set staged "$target RetroChat Restore"

    catch {file delete -force -- $staged}
    file copy -- $source $staged
    catch {file attributes $staged -readonly 0}

    if {[file exists $target]} {
        catch {file attributes $target -readonly 0}
        file copy -force -- $target $backup
        catch {file attributes $backup -readonly 0}
        file delete -force -- $target
    }
    file rename -force -- $staged $target
    catch {file attributes $target -readonly 0}
}

proc recoverNetwork {} {
    set destination [tk_chooseDirectory -title "Select the Mac OS 9 startup disk"]
    if {$destination == ""} {exit}

    set volume [lindex [file split $destination] 0]
    set systemFolder [file join $volume "System Folder"]
    set extensions [file join $systemFolder "Extensions"]
    if {![file isdirectory $systemFolder] || ![file isdirectory $extensions]} {
        tk_messageBox -icon error -title "RetroChat Network Recovery" \
            -message "The selected disk does not contain a Mac OS 9 System Folder."
        exit 1
    }

    set media [file dirname [info nameofexecutable]]
    set support [file join $media "Mac OS 9.0.4 Network Files"]
    set backup [file join $volume "RetroChat Network Backup"]
    if {[file exists $backup]} {
        append backup " " [clock seconds]
    }

    if {[catch {
        file mkdir $backup
        restoreComponent [file join $support "MacTCP DNR"] \
            [file join $systemFolder "MacTCP DNR"] $backup
        restoreComponent [file join $support "Open Transport"] \
            [file join $extensions "Open Transport"] $backup
        restoreComponent [file join $support "Open Transport ASLM Modules"] \
            [file join $extensions "Open Transport ASLM Modules"] $backup
    } problem]} {
        tk_messageBox -icon error -title "RetroChat Network Recovery" \
            -message "Network recovery failed:\n$problem\n\nExisting files were backed up in:\n$backup"
        exit 1
    }

    tk_messageBox -icon info -title "RetroChat Network Recovery" \
        -message "The original Mac OS 9.0.4 networking files were restored.\n\nPrevious files were saved in:\n$backup\n\nRestart the Macintosh now."
    exit
}

after idle recoverNetwork
