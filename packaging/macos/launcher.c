#include <tcl.h>
#include <tk.h>

static int
RetroChatAppInit(Tcl_Interp *interp)
{
    if (Tcl_Init(interp) == TCL_ERROR) {
        return TCL_ERROR;
    }
    if (Tk_Init(interp) == TCL_ERROR) {
        return TCL_ERROR;
    }
    Tcl_StaticPackage(interp, "Tk", Tk_Init, Tk_SafeInit);
    return TCL_OK;
}

int
main(int argc, char **argv)
{
    Tk_Main(argc, argv, RetroChatAppInit);
    return 0;
}
