#include <windows.h>
#ifndef SCRIPT_NAME
#error SCRIPT_NAME must name the Tcl script
#endif
#ifndef SCRIPT_ARGS
#define SCRIPT_ARGS ""
#endif

static DWORD targetProcess;
static HICON largeIcon;
static HICON smallIcon;
static int windowsUpdated;

static BOOL CALLBACK updateWindow(HWND window, LPARAM parameter) {
    DWORD process;
    (void) parameter;
    GetWindowThreadProcessId(window, &process);
    if (process == targetProcess) {
        if (largeIcon != NULL)
            SendMessage(window, WM_SETICON, ICON_BIG, (LPARAM) largeIcon);
        if (smallIcon != NULL)
            SendMessage(window, WM_SETICON, ICON_SMALL, (LPARAM) smallIcon);
        ++windowsUpdated;
    }
    return TRUE;
}

void WINAPI WinMainCRTStartup(void) {
    char directory[MAX_PATH];
    char wish[MAX_PATH];
    char script[MAX_PATH];
    char command[MAX_PATH * 3];
    STARTUPINFO startup;
    PROCESS_INFORMATION process;
    DWORD waitResult;
    int attempts;
    char *cursor;
    char *slash;

    if (!GetModuleFileName(NULL, directory, sizeof(directory))) ExitProcess(1);
    slash = NULL;
    for (cursor = directory; *cursor; ++cursor)
        if (*cursor == '\\') slash = cursor;
    if (!slash) ExitProcess(1);
    *slash = '\0';

    wsprintf(wish, "%s\\..\\Tcl\\bin\\wish80.exe", directory);
    wsprintf(script, "%s\\%s", directory, SCRIPT_NAME);
    if (SCRIPT_ARGS[0])
        wsprintf(command, "\"%s\" \"%s\" %s", wish, script, SCRIPT_ARGS);
    else
        wsprintf(command, "\"%s\" \"%s\"", wish, script);

    ZeroMemory(&startup, sizeof(startup));
    startup.cb = sizeof(startup);
    ZeroMemory(&process, sizeof(process));
    if (!CreateProcess(wish, command, NULL, NULL, FALSE, 0, NULL, directory,
                       &startup, &process)) {
        MessageBox(NULL, "Tcl/Tk 8.0.5 was not found. Reinstall RetroChat.",
                   "RetroChat", MB_OK | MB_ICONERROR);
        ExitProcess(1);
    }
    CloseHandle(process.hThread);

    targetProcess = process.dwProcessId;
    largeIcon = (HICON) LoadImage(GetModuleHandle(NULL), MAKEINTRESOURCE(1),
        IMAGE_ICON, GetSystemMetrics(SM_CXICON), GetSystemMetrics(SM_CYICON), 0);
    smallIcon = (HICON) LoadImage(GetModuleHandle(NULL), MAKEINTRESOURCE(1),
        IMAGE_ICON, GetSystemMetrics(SM_CXSMICON), GetSystemMetrics(SM_CYSMICON), 0);

    /* Tk 8 creates hidden helper windows before mapping the real root window.
       Update every Wish-owned window repeatedly through the startup interval. */
    for (attempts = 0; attempts < 100; ++attempts) {
        windowsUpdated = 0;
        EnumWindows(updateWindow, 0);
        waitResult = WaitForSingleObject(process.hProcess, 100);
        if (waitResult != WAIT_TIMEOUT) break;
    }
    WaitForSingleObject(process.hProcess, INFINITE);
    CloseHandle(process.hProcess);
    ExitProcess(0);
}
