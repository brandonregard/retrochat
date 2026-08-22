# Classic Mac OS application About box. The installer retains the color icon
# resources in each installed application, so this does not depend on external
# image files. RcIb/RcIm remain as a fallback for unusually old Tk builds.
option add *Entry.font {Geneva 9}

proc retrochatClassicColorIcon {widget resourceType} {
    canvas $widget -width 32 -height 32 -highlightthickness 0 -borderwidth 0
    set number 0
    foreach layer [resource read $resourceType 128] {
        foreach {color bitmap} $layer break
        set imageName "retrochatColorLayer$widget$number"
        image create bitmap $imageName -data $bitmap -foreground $color
        $widget create image 16 16 -image $imageName
        lappend ::retrochatColorImages($widget) $imageName
        incr number
    }
    bind $widget <Destroy> [list retrochatDeleteColorIcon $widget]
}

proc retrochatDeleteColorIcon {widget} {
    if {[info exists ::retrochatColorImages($widget)]} {
        foreach imageName $::retrochatColorImages($widget) {
            catch {image delete $imageName}
        }
        unset ::retrochatColorImages($widget)
    }
}

proc retrochatAbout {} {
    if {[winfo exists .retrochatAbout]} {
        raise .retrochatAbout
        return
    }

    set dialog .retrochatAbout
    toplevel $dialog
    wm title $dialog "About RetroChat"
    wm resizable $dialog 0 0

    set iconType RcLy
    if {[info exists ::retrochatAboutIconResource]} {
        if {$::retrochatAboutIconResource == "RcSg"} {
            set iconType RsLy
        }
    }
    if {[catch {
        retrochatClassicColorIcon $dialog.icon $iconType
    }]} {
        catch {destroy $dialog.icon}
        image create bitmap retrochatAboutIcon \
            -data [resource read RcIb 128] \
            -maskdata [resource read RcIm 128] \
            -foreground black -background white
        label $dialog.icon -image retrochatAboutIcon
    }
    label $dialog.name -text "RetroChat" -font {Geneva 18 bold}
    label $dialog.version -text "Version $::retrochatVersion"
    label $dialog.detail -justify center \
        -text "Created by Brandon Regard\n\nClassic Internet chat for Mac OS 7, 8, and 9\n68K and PowerPC"
    button $dialog.ok -text OK -width 8 -default active \
        -command [list destroy $dialog]

    pack $dialog.icon -pady 12
    pack $dialog.name -padx 24
    pack $dialog.version -pady 2
    pack $dialog.detail -padx 24 -pady 8
    pack $dialog.ok -pady 10
    bind $dialog <Return> [list $dialog.ok invoke]
    bind $dialog <Destroy> {catch {image delete retrochatAboutIcon}}
    update idletasks
    set x [expr {([winfo screenwidth $dialog] - [winfo reqwidth $dialog]) / 2}]
    set y [expr {([winfo screenheight $dialog] - [winfo reqheight $dialog]) / 3}]
    wm geometry $dialog +$x+$y
    grab $dialog
    focus $dialog.ok
}

# Classic Mac Tk calls this command from its standard Apple-menu About item.
proc tkAboutDialog {} {
    retrochatAbout
}

# Some older Tk builds require the application to supply the Apple menu.
if {![winfo exists .menubar]} {
    menu .menubar
    . configure -menu .menubar
}
if {![winfo exists .menubar.apple]} {
    menu .menubar.apple -tearoff 0
    .menubar add cascade -label "\024" -menu .menubar.apple
    .menubar.apple add command -label "About RetroChat..." \
        -command retrochatAbout
}
