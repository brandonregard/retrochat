#ifndef TCL_SCRIPT_PATH
#error TCL_SCRIPT_PATH must name the MacRoman Tcl startup script
#endif

read 'TEXT' (3114, "tclshrc", purgeable) TCL_SCRIPT_PATH;
