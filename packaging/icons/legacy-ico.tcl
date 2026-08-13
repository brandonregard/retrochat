# Write a Windows 95-compatible ICO from raw RGBA images. Each icon uses an
# 8-bit 3-3-2 color bitmap plus the 1-bit AND mask required for transparency.
proc byte {value} {
    return [binary format c [expr {$value > 127 ? $value - 256 : $value}]]
}

proc le16 {value} {
    return "[byte [expr {$value & 255}]][byte [expr {($value >> 8) & 255}]]"
}

proc le32 {value} {
    return "[le16 [expr {$value & 65535}]][le16 [expr {($value >> 16) & 65535}]]"
}

proc makeImage {path size} {
    set channel [open $path rb]
    fconfigure $channel -translation binary
    set rgba [read $channel]
    close $channel
    if {[string length $rgba] != $size * $size * 4} {
        error "$path is not a $size x $size RGBA image"
    }

    set palette ""
    for {set index 0} {$index < 256} {incr index} {
        set red [expr {(($index >> 5) & 7) * 255 / 7}]
        set green [expr {(($index >> 2) & 7) * 255 / 7}]
        set blue [expr {($index & 3) * 255 / 3}]
        append palette [byte $blue] [byte $green] [byte $red] [byte 0]
    }

    set colors ""
    set mask ""
    for {set y [expr {$size - 1}]} {$y >= 0} {incr y -1} {
        set maskByte 0
        for {set x 0} {$x < $size} {incr x} {
            set offset [expr {(($y * $size) + $x) * 4}]
            binary scan [string range $rgba $offset [expr {$offset + 3}]] cu4 pixel
            foreach {red green blue alpha} $pixel break
            set colorIndex [expr {(($red * 7 / 255) << 5) |
                                  (($green * 7 / 255) << 2) |
                                  ($blue * 3 / 255)}]
            append colors [byte $colorIndex]
            if {$alpha < 128} {
                set maskByte [expr {$maskByte | (1 << (7 - ($x % 8)))}]
            }
            if {$x % 8 == 7} {
                append mask [byte $maskByte]
                set maskByte 0
            }
        }
        set maskRowBytes [expr {($size + 7) / 8}]
        while {$maskRowBytes % 4 != 0} {
            append mask [byte 0]
            incr maskRowBytes
        }
    }

    set bitmapSize [expr {[string length $colors] + [string length $mask]}]
    set header "[le32 40][le32 $size][le32 [expr {$size * 2}]]"
    append header [le16 1] [le16 8] [le32 0] [le32 $bitmapSize]
    append header [le32 0] [le32 0] [le32 256] [le32 0]
    return "$header$palette$colors$mask"
}

if {[llength $argv] != 7} {
    puts stderr "usage: tclsh legacy-ico.tcl 16.rgba 16 32.rgba 32 48.rgba 48 output.ico"
    exit 2
}

set images {}
foreach {path size} [lrange $argv 0 5] {
    lappend images [list $size [makeImage $path $size]]
}

set directory "[le16 0][le16 1][le16 [llength $images]]"
set offset [expr {6 + 16 * [llength $images]}]
set data ""
foreach image $images {
    foreach {size bytes} $image break
    append directory [byte $size] [byte $size] [byte 0] [byte 0]
    append directory [le16 1] [le16 8] [le32 [string length $bytes]] [le32 $offset]
    append data $bytes
    incr offset [string length $bytes]
}

set output [open [lindex $argv 6] wb]
fconfigure $output -translation binary
puts -nonewline $output "$directory$data"
close $output
