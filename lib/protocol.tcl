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

