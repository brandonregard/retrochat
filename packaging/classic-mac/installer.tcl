catch {console hide}
set retrochatVersion "@VERSION@"
set retrochatArchitecture "@ARCH@"
set installerDestination ""

proc refreshFolderBrowser {} {
    .folders.list delete 0 end
    if {$::folderBrowserPath == ""} {
        foreach volume [file volumes] {
            .folders.list insert end $volume
        }
        .folders.path configure -text "Disks"
        .folders.up configure -state disabled
        return
    }

    .folders.path configure -text $::folderBrowserPath
    .folders.up configure -state normal
    set folders {}
    catch {
        foreach item [glob -nocomplain [file join $::folderBrowserPath *]] {
            if {[file isdirectory $item]} {
                lappend folders $item
            }
        }
    }
    foreach folder [lsort -dictionary $folders] {
        .folders.list insert end [file tail $folder]
    }
}

proc openSelectedFolder {} {
    set selected [.folders.list curselection]
    if {$selected == ""} {
        return
    }
    set name [.folders.list get [lindex $selected 0]]
    if {$::folderBrowserPath == ""} {
        set ::folderBrowserPath $name
    } else {
        set ::folderBrowserPath [file join $::folderBrowserPath $name]
    }
    refreshFolderBrowser
}

proc folderBrowserUp {} {
    if {$::folderBrowserPath == ""} {
        return
    }
    set parent [file dirname $::folderBrowserPath]
    if {$parent == $::folderBrowserPath} {
        set ::folderBrowserPath ""
    } else {
        set ::folderBrowserPath $parent
    }
    refreshFolderBrowser
}

proc chooseInstallFolder {} {
    set ::folderBrowserPath ""
    set ::folderBrowserDone 0
    toplevel .folders
    wm title .folders "Choose Installation Folder"
    wm resizable .folders 1 1
    label .folders.path -text "Disks" -anchor w
    listbox .folders.list -width 42 -height 12 -exportselection 0
    scrollbar .folders.scroll -command {.folders.list yview}
    .folders.list configure -yscrollcommand {.folders.scroll set}
    button .folders.up -text "Up" -command folderBrowserUp
    button .folders.open -text "Open" -command openSelectedFolder
    button .folders.choose -text "Choose" -command {set ::folderBrowserDone 1}
    button .folders.cancel -text "Cancel" -command {set ::folderBrowserDone -1}
    grid .folders.path -columnspan 3 -sticky ew -padx 8 -pady 6
    grid .folders.list .folders.scroll - -sticky nsew -padx 8
    grid .folders.up .folders.open .folders.choose .folders.cancel -padx 5 -pady 8
    grid columnconfigure .folders 0 -weight 1
    grid rowconfigure .folders 1 -weight 1
    bind .folders.list <Double-Button-1> openSelectedFolder
    wm protocol .folders WM_DELETE_WINDOW {set ::folderBrowserDone -1}
    refreshFolderBrowser
    grab .folders
    tkwait variable ::folderBrowserDone
    grab release .folders
    if {$::folderBrowserDone == 1 && $::folderBrowserPath != ""} {
        set ::installerDestination $::folderBrowserPath
    }
    destroy .folders
}

proc showInstalledDialog {installDir} {
    set dialog .installed
    toplevel $dialog
    wm title $dialog "RetroChat Installer"
    wm resizable $dialog 0 0
    wm protocol $dialog WM_DELETE_WINDOW [list set ::installedDialogDone 1]

    if {[catch {
        retrochatInstallerColorIcon $dialog.icon RcLy
    }]} {
        catch {destroy $dialog.icon}
        catch {image delete retrochatDialogIcon}
        image create bitmap retrochatDialogIcon \
            -data [resource read RcIb 128] \
            -maskdata [resource read RcIm 128] \
            -foreground black -background white
        label $dialog.icon -image retrochatDialogIcon
    }
    label $dialog.message -justify left -anchor w \
        -text "RetroChat was installed in:\n$installDir"
    button $dialog.ok -text OK -width 8 -default active \
        -command [list set ::installedDialogDone 1]

    grid $dialog.icon $dialog.message -padx 12 -pady 12
    grid $dialog.ok -columnspan 2 -pady 10 -padx 12
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
    catch {image delete retrochatDialogIcon}
}

proc retrochatInstallerColorIcon {widget resourceType} {
    canvas $widget -width 32 -height 32 -highlightthickness 0 -borderwidth 0
    set number 0
    foreach layer [resource read $resourceType 128] {
        foreach {color bitmap} $layer break
        set imageName "retrochatInstallerLayer$widget$number"
        image create bitmap $imageName -data $bitmap -foreground $color
        $widget create image 16 16 -image $imageName
        lappend ::retrochatInstallerColorImages($widget) $imageName
        incr number
    }
    bind $widget <Destroy> [list retrochatDeleteInstallerColorIcon $widget]
}

proc retrochatDeleteInstallerColorIcon {widget} {
    if {[info exists ::retrochatInstallerColorImages($widget)]} {
        foreach imageName $::retrochatInstallerColorImages($widget) {
            catch {image delete $imageName}
        }
        unset ::retrochatInstallerColorImages($widget)
    }
}

proc retrochatInstallerAbout {} {
    if {[winfo exists .installerAbout]} {
        raise .installerAbout
        return
    }
    set dialog .installerAbout
    toplevel $dialog
    wm title $dialog "About RetroChat Installer"
    wm resizable $dialog 0 0
    if {[catch {retrochatInstallerColorIcon $dialog.icon RcLy}]} {
        catch {destroy $dialog.icon}
        image create bitmap retrochatInstallerAboutIcon \
            -data [resource read RcIb 128] \
            -maskdata [resource read RcIm 128] \
            -foreground black -background white
        label $dialog.icon -image retrochatInstallerAboutIcon
    }
    label $dialog.name -text "RetroChat Installer" -font {Geneva 18 bold}
    label $dialog.version -text "Version $::retrochatVersion ($::retrochatArchitecture)"
    label $dialog.author -text "Brandon Regard"
    label $dialog.license -text "MIT License"
    label $dialog.date -text "August 17, 2026"
    label $dialog.detail -justify center \
        -text "Alpha Codex Release\nCodename: Save Ferris\n\nClassic Mac OS 7, 8, and 9"
    button $dialog.ok -text OK -width 8 -default active \
        -command [list destroy $dialog]
    pack $dialog.icon -pady 12
    pack $dialog.name -padx 24
    pack $dialog.version -pady 2
    pack $dialog.author
    pack $dialog.license
    pack $dialog.date
    pack $dialog.detail -padx 24 -pady 8
    pack $dialog.ok -pady 10
    bind $dialog <Return> [list $dialog.ok invoke]
    bind $dialog <Destroy> {catch {image delete retrochatInstallerAboutIcon}}
    update idletasks
    set x [expr {([winfo screenwidth $dialog] - [winfo reqwidth $dialog]) / 2}]
    set y [expr {([winfo screenheight $dialog] - [winfo reqheight $dialog]) / 3}]
    wm geometry $dialog +$x+$y
    grab $dialog
    focus $dialog.ok
}

proc tkAboutDialog {} {
    retrochatInstallerAbout
}

proc showCfm68KWarning {} {
    if {$::retrochatArchitecture != "68k"} {return}
    tk_messageBox -icon warning -title "CFM-68K Required" \
        -message "RetroChat requires the CFM-68K Runtime Enabler.\n\nIf it is not already installed, quit this installer, drag CFM-68K Runtime Enabler onto the closed System Folder, and restart the Macintosh before installing RetroChat."
}

proc installRetroChat {} {
    set destination $::installerDestination
    if {$destination == ""} {
        tk_messageBox -icon info -title "RetroChat Installer" \
            -message "Choose an installation folder first."
        return
    }

    set installDir [file join $destination "RetroChat $::retrochatVersion"]
    if {[catch {
        file mkdir $installDir

        set installer [info nameofexecutable]
        if {$::retrochatArchitecture == "68k"} {
            set runtimeDir [file dirname $installer]
            foreach runtimeFile {
                Tcl8.0CFM68K.shlb Tk8.0CFM68K.shlb tcl8.0 tk8.0
            } {
                set runtimeSource [file join $runtimeDir $runtimeFile]
                set runtimeTarget [file join $installDir $runtimeFile]
                if {[file exists $runtimeTarget]} {
                    file delete -force $runtimeTarget
                }
                file copy -force $runtimeSource $runtimeTarget
            }
        }
        foreach {name creator scriptType iconId} {
            "RetroChat Client" RtCl RcCl 129
            "RetroChat Server" RtSv RcSv 130
        } {
            set target [file join $installDir $name]
            file copy -force $installer $target

            set resources [resource open $target r+]
            resource write -force -file $resources -id 3114 \
                -name tclshrc TEXT [resource read $scriptType 128]
            foreach payloadType {RcCl RcSv RcLi} {
                catch {resource delete -file $resources -id 128 $payloadType}
            }
            foreach iconType {ICN# icl4 ics# ics4} {
                resource write -force -file $resources -id -16455 \
                    -name "RetroChat Custom Icon" $iconType \
                    [resource read $iconType $iconId]
            }
            resource close $resources

            file attributes $target -type APPL -creator $creator
        }

        set license [open [file join $installDir "License"] w]
        fconfigure $license -translation binary
        puts -nonewline $license [resource read RcLi 128]
        close $license
        file attributes [file join $installDir "License"] \
            -type TEXT -creator ttxt
    } problem]} {
        tk_messageBox -icon error -title "RetroChat Installer" \
            -message "RetroChat could not be installed:\n$problem"
        exit 1
    }

    showInstalledDialog $installDir
    exit
}

proc startRetroChatInstaller {} {
    wm title . "RetroChat Installer"
    wm resizable . 0 0
    if {![winfo exists .menubar]} {
        menu .menubar
        . configure -menu .menubar
    }
    if {![winfo exists .menubar.apple]} {
        menu .menubar.apple -tearoff 0
        .menubar add cascade -label "\024" -menu .menubar.apple
    }
    .menubar.apple delete 0 end
    .menubar.apple add command -label "About RetroChat Installer..." \
        -command retrochatInstallerAbout
    label .title -text "Install RetroChat $::retrochatVersion" -anchor w
    label .prompt -text "Destination folder:" -anchor w
    entry .destination -textvariable ::installerDestination -width 38
    button .browse -text "Choose..." -command chooseInstallFolder
    button .install -text "Install" -command installRetroChat
    button .cancel -text "Cancel" -command exit
    grid .title -columnspan 3 -sticky w -padx 12 -pady 10
    grid .prompt -columnspan 3 -sticky w -padx 12
    grid .destination .browse - -sticky ew -padx 12 -pady 6
    grid .install .cancel - -padx 12 -pady 10
    focus .browse
    after 100 showCfm68KWarning
}

after idle startRetroChatInstaller
