catch {console hide}
wm title . "RetroChat 68K Bootstrap Test"
wm resizable . 0 0
label .message -text "Tcl/Tk 68K bootstrap succeeded."
button .quit -text "Quit" -command exit
pack .message -padx 24 -pady 18
pack .quit -padx 12 -pady 12
