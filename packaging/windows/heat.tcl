#!/usr/bin/env tclsh

if {$argc != 3} {
    puts stderr "usage: heat.tcl payload-directory output.wxs i386|amd64"
    exit 2
}
lassign $argv root output arch
set root [file normalize $root]
set counter 0
set componentIds {}

proc xml {value} {
    return [string map {& &amp; < &lt; > &gt; \" &quot;} $value]
}

proc emitDirectory {channel path relative} {
    global counter componentIds arch
    foreach entry [lsort -dictionary [glob -nocomplain -directory $path *]] {
        set name [file tail $entry]
        set childRelative [expr {$relative eq "" ? $name : "$relative/$name"}]
        if {[file isdirectory $entry]} {
            incr counter
            set directoryId "RCDir$counter"
            puts $channel "      <Directory Id=\"$directoryId\" Name=\"[xml $name]\">"
            emitDirectory $channel $entry $childRelative
            puts $channel "      </Directory>"
        } else {
            incr counter
            set componentId "RCComponent$counter"
            set fileId [expr {[string equal -nocase $name "tcl805.exe"] ? "Tcl805InstallerFile" : "RCFile$counter"}]
            lappend componentIds $componentId
            set win64 [expr {$arch eq "amd64" ? " Win64=\"yes\"" : ""}]
            puts $channel "      <Component Id=\"$componentId\" Guid=\"*\"$win64>"
            puts $channel "        <File Id=\"$fileId\" KeyPath=\"yes\" Source=\"\$(var.PayloadDir)/[xml $childRelative]\" />"
            puts $channel "      </Component>"
        }
    }
}

set channel [open $output w]
puts $channel {<?xml version="1.0" encoding="utf-8"?>}
puts $channel {<Wix xmlns="http://schemas.microsoft.com/wix/2006/wi">}
puts $channel {  <Fragment>}
puts $channel {    <DirectoryRef Id="INSTALLDIR">}
emitDirectory $channel $root ""
puts $channel {    </DirectoryRef>}
puts $channel {  </Fragment>}
puts $channel {  <Fragment>}
puts $channel {    <ComponentGroup Id="Payload">}
foreach componentId $componentIds {
    puts $channel "      <ComponentRef Id=\"$componentId\" />"
}
puts $channel {    </ComponentGroup>}
puts $channel {  </Fragment>}
puts $channel {</Wix>}
close $channel
