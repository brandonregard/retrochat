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

static BOOL CALLBACK updateWindow(HWND window, LPARAM parameter) {
    DWORD process;
    (void) parameter;
    GetWindowThreadProcessId(window, &process);
    if (process == targetProcess) {
        if (largeIcon != NULL)
            SendMessage(window, WM_SETICON, ICON_BIG, (LPARAM) largeIcon);
        if (smallIcon != NULL)
            SendMessage(window, WM_SETICON, ICON_SMALL, (LPARAM) smallIcon);
    }
    return TRUE;
}

void WINAPI WinMainCRTStartup(void) {
    WCHAR directory[MAX_PATH];
    WCHAR wish[MAX_PATH];
    WCHAR script[MAX_PATH];
    WCHAR command[MAX_PATH * 3];
    STARTUPINFOW startup;
    PROCESS_INFORMATION process;
    DWORD waitResult;
    WCHAR *cursor;
    WCHAR *slash;

    if (!GetModuleFileNameW(NULL, directory, MAX_PATH)) ExitProcess(1);
    slash = NULL;
    for (cursor = directory; *cursor; ++cursor)
        if (*cursor == L'\\') slash = cursor;
    if (!slash) ExitProcess(1);
    *slash = L'\0';

    wsprintfW(wish, L"%s\\runtime\\bin\\wish86.exe", directory);
    wsprintfW(script, L"%s\\%S", directory, SCRIPT_NAME);
    if (SCRIPT_ARGS[0])
        wsprintfW(command, L"\"%s\" \"%s\" %S", wish, script, SCRIPT_ARGS);
    else
        wsprintfW(command, L"\"%s\" \"%s\"", wish, script);

    ZeroMemory(&startup, sizeof(startup));
    startup.cb = sizeof(startup);
    ZeroMemory(&process, sizeof(process));
    if (!CreateProcessW(wish, command, NULL, NULL, FALSE, 0, NULL, directory,
                        &startup, &process)) {
        MessageBoxW(NULL, L"The bundled AMD64 Tcl/Tk runtime was not found. Reinstall RetroChat.",
                    L"RetroChat", MB_OK | MB_ICONERROR);
        ExitProcess(1);
    }
    CloseHandle(process.hThread);

    targetProcess = process.dwProcessId;
    largeIcon = (HICON) LoadImageW(GetModuleHandleW(NULL), MAKEINTRESOURCEW(1),
        IMAGE_ICON, GetSystemMetrics(SM_CXICON), GetSystemMetrics(SM_CYICON), 0);
    smallIcon = (HICON) LoadImageW(GetModuleHandleW(NULL), MAKEINTRESOURCEW(1),
        IMAGE_ICON, GetSystemMetrics(SM_CXSMICON), GetSystemMetrics(SM_CYSMICON), 0);

    for (;;) {
        EnumWindows(updateWindow, 0);
        waitResult = WaitForSingleObject(process.hProcess, 250);
        if (waitResult != WAIT_TIMEOUT) break;
    }
    CloseHandle(process.hProcess);
    ExitProcess(0);
}
