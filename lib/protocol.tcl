# RetroChat wire-format helpers. Kept compatible with Tcl 8.0.

namespace eval retrochat {
    variable protocolVersion 1
}

proc retrochat::hexEncode {value} {
    binary scan $value H* encoded
    return $encoded
}

proc retrochat::hexDecode {value} {
    if {[string length $value] % 2 != 0 ||
        ![regexp {^[0-9a-fA-F]*$} $value]} {
        error "invalid hexadecimal field"
    }
    return [binary format H* $value]
}

# Lightweight incremental transfer fingerprint. TCP already protects every
# byte in transit; this additionally catches application-level truncation or
# chunk mixups without scanning every byte in interpreted Tcl on a 1990s CPU.
proc retrochat::checksumStart {} {
    return [list 1 0]
}

proc retrochat::checksumUpdate {state data} {
    set a [lindex $state 0]
    set b [lindex $state 1]
    set length [string length $data]
    set samples [list]
    if {$length > 0} {
        foreach index [list 0 [expr {$length / 4}] [expr {$length / 2}] \
            [expr {($length * 3) / 4}] [expr {$length - 1}]] {
            binary scan [string index $data $index] c byte
            lappend samples $byte
        }
    }
    lappend samples [expr {$length & 255}] [expr {($length / 256) & 255}]
    foreach byte $samples {
        set a [expr {($a + ($byte & 255)) % 65521}]
        set b [expr {($b + $a) % 65521}]
    }
    return [list $a $b]
}

proc retrochat::checksumFinish {state} {
    return [format %08x [expr {[lindex $state 1] * 65536 + [lindex $state 0]}]]
}

proc retrochat::makeRecord {command fields} {
    set record $command
    foreach field $fields {
        append record " " [hexEncode $field]
    }
    return $record
}

proc retrochat::parseRecord {line} {
    set words [split $line " "]
    set command [lindex $words 0]
    if {![regexp {^[A-Z_]+$} $command]} {
        error "invalid command"
    }
    set fields [list]
    set index 1
    while {$index < [llength $words]} {
        lappend fields [hexDecode [lindex $words $index]]
        incr index
    }
    return [list $command $fields]
}
