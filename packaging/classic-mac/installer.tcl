wm withdraw .
catch {console hide}
set retrochatVersion "@VERSION@"

proc showInstalledDialog {installDir} {
    set dialog .installed
    toplevel $dialog
    wm title $dialog "RetroChat Installer"
    wm resizable $dialog 0 0
    wm protocol $dialog WM_DELETE_WINDOW [list set ::installedDialogDone 1]

    if {[catch {
        image create photo retrochatDialogIcon \
            -data [resource read RcCg 128] -format gif
    }]} {
        catch {image delete retrochatDialogIcon}
        image create bitmap retrochatDialogIcon \
            -data [resource read RcIb 128] \
            -maskdata [resource read RcIm 128] \
            -foreground black -background white
    }
    label $dialog.icon -image retrochatDialogIcon
    label $dialog.message -justify left -anchor w \
        -text "RetroChat was installed in:\n$installDir"
    button $dialog.ok -text OK -width 8 -default active \
        -command [list set ::installedDialogDone 1]

    grid $dialog.icon $dialog.message -padx 12 -pady 12
    grid $dialog.ok -columnspan 2 -pady 0 -padx 12
    bind $dialog <Return> [list $dialog.ok invoke]
    update idletasks
    set x [expr {([winfo screenwidth $dialog] - [winfo reqwidth $dialog]) / 2}]
    set y [expr {([winfo screenheight $dialog] - [winfo reqheight $dialog]) / 3}]
    wm geometry $dialog +$x+$y
    set ::installedDialogDone 0
    grab $dialog
    focus $dialog.ok
    tkwait variable ::installedDialogDone
    grab release $dialog
    destroy $dialog
    image delete retrochatDialogIcon
}

proc installRetroChat {} {
    set destination [tk_chooseDirectory -title "Install RetroChat"]
    if {$destination == ""} {
        exit
    }

    set installDir [file join $destination "RetroChat $::retrochatVersion"]
    if {[catch {
        file mkdir $installDir

        set installer [info nameofexecutable]
        foreach {name creator scriptType} {
            "RetroChat Client" RtCl RcCl
            "RetroChat Server" RtSv RcSv
        } {
            set target [file join $installDir $name]
            file copy -force -- $installer $target

            set resources [resource open $target r+]
            resource write -force -file $resources -id 3114 \
                -name tclshrc TEXT [resource read $scriptType 128]
            foreach payloadType {RcCl RcSv RcRd} {
                catch {resource delete -file $resources -id 128 $payloadType}
            }
            resource close $resources

            file attributes $target -type APPL -creator $creator
        }

        set readme [open [file join $installDir "Read Me"] w]
        fconfigure $readme -translation binary
        puts -nonewline $readme [resource read RcRd 128]
        close $readme
        file attributes [file join $installDir "Read Me"] \
            -type TEXT -creator ttxt
    } problem]} {
        tk_messageBox -icon error -title "RetroChat Installer" \
            -message "RetroChat could not be installed:\n$problem"
        exit 1
    }

    showInstalledDialog $installDir
    exit
}

after idle installRetroChat
