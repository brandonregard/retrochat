proc bitmapHex {path size maskOnly} {
    set channel [open $path rb]
    set pixels [read $channel]
    close $channel

    set result ""
    for {set y 0} {$y < $size} {incr y} {
        for {set x 0} {$x < $size} {incr x 8} {
            set byte 0
            for {set bit 0} {$bit < 8} {incr bit} {
                set offset [expr {(($y * $size) + $x + $bit) * 4}]
                binary scan [string range $pixels $offset [expr {$offset + 3}]] \
                    cu4 rgba
                foreach {red green blue alpha} $rgba break
                set opaque [expr {$alpha >= 128}]
                set dark [expr {(($red + $green + $blue) / 3) < 210}]
                if {$opaque && ($maskOnly || $dark)} {
                    set byte [expr {$byte | (1 << (7 - $bit))}]
                }
            }
            append result [format %02X $byte]
        }
    }
    return $result
}

proc color4Hex {path size} {
    # The fixed 16-color palette used by classic Mac OS icon resources.
    set palette {
        {255 255 255} {255 255 0} {255 102 0} {221 0 0}
        {255 0 255} {128 0 128} {0 0 221} {0 255 255}
        {0 170 0} {0 85 0} {153 102 51} {204 153 102}
        {204 204 204} {136 136 136} {68 68 68} {0 0 0}
    }
    set channel [open $path rb]
    set pixels [read $channel]
    close $channel

    set result ""
    for {set y 0} {$y < $size} {incr y} {
        for {set x 0} {$x < $size} {incr x 2} {
            set byte 0
            for {set half 0} {$half < 2} {incr half} {
                set offset [expr {(($y * $size) + $x + $half) * 4}]
                binary scan [string range $pixels $offset [expr {$offset + 3}]] \
                    cu4 rgba
                foreach {red green blue alpha} $rgba break
                set best 0
                set bestDistance 0x7fffffff
                if {$alpha >= 128} {
                    for {set index 0} {$index < 16} {incr index} {
                        foreach {pr pg pb} [lindex $palette $index] break
                        set distance [expr {($red-$pr)**2 + ($green-$pg)**2 + ($blue-$pb)**2}]
                        if {$distance < $bestDistance} {
                            set best $index
                            set bestDistance $distance
                        }
                    }
                }
                set byte [expr {$byte | ($best << (4 * (1 - $half)))}]
            }
            append result [format %02X $byte]
        }
    }
    return $result
}

proc colorLayerData {path size} {
    set palette {
        {255 255 255} {255 255 0} {255 102 0} {221 0 0}
        {255 0 255} {128 0 128} {0 0 221} {0 255 255}
        {0 170 0} {0 85 0} {153 102 51} {204 153 102}
        {204 204 204} {136 136 136} {68 68 68} {0 0 0}
    }
    set channel [open $path rb]
    set pixels [read $channel]
    close $channel
    set layers {}
    for {set wanted 0} {$wanted < 16} {incr wanted} {
        set values {}
        set used 0
        for {set y 0} {$y < $size} {incr y} {
            for {set x 0} {$x < $size} {incr x 8} {
                set byte 0
                for {set bit 0} {$bit < 8} {incr bit} {
                    set pixel [expr {$x + $bit}]
                    if {$pixel >= $size} {continue}
                    set offset [expr {(($y * $size) + $pixel) * 4}]
                    binary scan [string range $pixels $offset [expr {$offset + 3}]] cu4 rgba
                    foreach {red green blue alpha} $rgba break
                    if {$alpha < 128} {continue}
                    set best 0
                    set bestDistance 0x7fffffff
                    for {set index 0} {$index < 16} {incr index} {
                        foreach {pr pg pb} [lindex $palette $index] break
                        set distance [expr {($red-$pr)**2 + ($green-$pg)**2 + ($blue-$pb)**2}]
                        if {$distance < $bestDistance} {
                            set best $index
                            set bestDistance $distance
                        }
                    }
                    if {$best == $wanted} {
                        set byte [expr {$byte | (1 << $bit)}]
                        set used 1
                    }
                }
                lappend values [format 0x%02X $byte]
            }
        }
        if {$used} {
            foreach {red green blue} [lindex $palette $wanted] break
            set color [format "#%02x%02x%02x" $red $green $blue]
            set bitmap "#define layer_width $size\n#define layer_height $size\nstatic unsigned char layer_bits\[\] = {\n [join $values {, }]};"
            lappend layers [list $color $bitmap]
        }
    }
    return $layers
}

proc writeResource {channel type id name bytes} {
    puts $channel "data '$type' ($id, \"$name\", purgeable) {"
    for {set offset 0} {$offset < [string length $bytes]} {incr offset 64} {
        puts $channel "    \$\"[string range $bytes $offset [expr {$offset + 63}]]\""
    }
    puts $channel "};"
}

proc writeXbm {path rgbaPath size maskOnly} {
    set input [open $rgbaPath rb]
    set pixels [read $input]
    close $input
    set output [open $path w]
    puts $output "#define retrochat_width $size"
    puts $output "#define retrochat_height $size"
    puts $output "static unsigned char retrochat_bits\[\] = {"
    set values {}
    for {set y 0} {$y < $size} {incr y} {
        for {set x 0} {$x < $size} {incr x 8} {
            set byte 0
            for {set bit 0} {$bit < 8} {incr bit} {
                set offset [expr {(($y * $size) + $x + $bit) * 4}]
                binary scan [string range $pixels $offset [expr {$offset + 3}]] cu4 rgba
                foreach {red green blue alpha} $rgba break
                set opaque [expr {$alpha >= 128}]
                set dark [expr {(($red + $green + $blue) / 3) < 210}]
                if {$opaque && ($maskOnly || $dark)} {
                    set byte [expr {$byte | (1 << $bit)}]
                }
            }
            lappend values [format 0x%02X $byte]
        }
    }
    puts $output " [join $values {, }]};"
    close $output
}

if {[llength $argv] != 7} {
    puts stderr "usage: tclsh classic-icon-rez.tcl client-32.rgba client-16.rgba server-32.rgba server-16.rgba output.r bitmap.xbm mask.xbm"
    exit 2
}

set icon32 [bitmapHex [lindex $argv 0] 32 0]
set mask32 [bitmapHex [lindex $argv 0] 32 1]
set icon16 [bitmapHex [lindex $argv 1] 16 0]
set mask16 [bitmapHex [lindex $argv 1] 16 1]
set color32 [color4Hex [lindex $argv 0] 32]
set color16 [color4Hex [lindex $argv 1] 16]
set serverIcon32 [bitmapHex [lindex $argv 2] 32 0]
set serverMask32 [bitmapHex [lindex $argv 2] 32 1]
set serverIcon16 [bitmapHex [lindex $argv 3] 16 0]
set serverMask16 [bitmapHex [lindex $argv 3] 16 1]
set serverColor32 [color4Hex [lindex $argv 2] 32]
set serverColor16 [color4Hex [lindex $argv 3] 16]
set clientLayers [colorLayerData [lindex $argv 0] 32]
set serverLayers [colorLayerData [lindex $argv 2] 32]

# Classic color icons use the second half of ICN#/ics# as a 1-bit
# transparency mask. Reject an empty or fully opaque mask: either mistake can
# produce a black rectangle around the artwork in Finder.
foreach {label mask} [list \
        client-32 $mask32 client-16 $mask16 \
        server-32 $serverMask32 server-16 $serverMask16] {
    if {[regexp {^0+$} $mask] || [regexp {^F+$} $mask]} {
        error "$label icon does not contain a usable transparency mask"
    }
}

set output [open [lindex $argv 4] w]
puts $output {data 'BNDL' (128, "RetroChat Installer bundle", purgeable) {
    $"5274496E 0000 0001"
    $"49434E23 0000 0000 0080"
    $"46524546 0000 0000 0080"
};

data 'FREF' (128, "RetroChat Installer", purgeable) {
    $"4150504C 0000 00"
};

data 'BNDL' (129, "RetroChat Client bundle", purgeable) {
    $"5274436C 0000 0001"
    $"49434E23 0000 0000 0081"
    $"46524546 0000 0000 0081"
};

data 'FREF' (129, "RetroChat Client", purgeable) {
    $"4150504C 0000 00"
};

data 'BNDL' (130, "RetroChat Server bundle", purgeable) {
    $"52745376 0000 0001"
    $"49434E23 0000 0000 0082"
    $"46524546 0000 0000 0082"
};

data 'FREF' (130, "RetroChat Server", purgeable) {
    $"4150504C 0000 00"
};}
writeResource $output ICN# 128 "RetroChat Installer" "$icon32$mask32"
writeResource $output icl4 128 "RetroChat Installer" $color32
writeResource $output ics# 128 "RetroChat Installer" "$icon16$mask16"
writeResource $output ics4 128 "RetroChat Installer" $color16
writeResource $output ICN# 129 "RetroChat Client" "$icon32$mask32"
writeResource $output icl4 129 "RetroChat Client" $color32
writeResource $output ics# 129 "RetroChat Client" "$icon16$mask16"
writeResource $output ics4 129 "RetroChat Client" $color16
writeResource $output ICN# 130 "RetroChat Server" "$serverIcon32$serverMask32"
writeResource $output icl4 130 "RetroChat Server" $serverColor32
writeResource $output ics# 130 "RetroChat Server" "$serverIcon16$serverMask16"
writeResource $output ics4 130 "RetroChat Server" $serverColor16
binary scan $clientLayers H* clientLayerHex
binary scan $serverLayers H* serverLayerHex
writeResource $output RcLy 128 "RetroChat Client Color Layers" $clientLayerHex
writeResource $output RsLy 128 "RetroChat Server Color Layers" $serverLayerHex
# A per-file custom icon works without waiting for the Desktop Database to
# register the BNDL on read-only installation media.
writeResource $output ICN# -16455 "RetroChat Custom Icon" "$icon32$mask32"
writeResource $output icl4 -16455 "RetroChat Custom Icon" $color32
writeResource $output ics# -16455 "RetroChat Custom Icon" "$icon16$mask16"
writeResource $output ics4 -16455 "RetroChat Custom Icon" $color16
close $output
writeXbm [lindex $argv 5] [lindex $argv 0] 32 0
writeXbm [lindex $argv 6] [lindex $argv 0] 32 1
