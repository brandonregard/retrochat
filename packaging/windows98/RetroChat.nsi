Unicode false

!include "MUI2.nsh"

!ifndef VERSION
!define VERSION "0.1.0"
!endif

!ifndef TCL805_INSTALLER
!error "Define TCL805_INSTALLER as the path to tcl805.exe"
!endif

Name "RetroChat ${VERSION}"
OutFile "..\..\dist\RetroChat-${VERSION}-Windows95-Plus-Setup.exe"
InstallDir "$PROGRAMFILES\RetroChat"
InstallDirRegKey HKCU "Software\RetroChat" "InstallDir"
RequestExecutionLevel user
SetCompressor /SOLID lzma
ShowInstDetails show
ShowUninstDetails show

!define MUI_ABORTWARNING
!define MUI_ICON "..\..\assets\icons\windows\client.ico"
!define MUI_UNICON "..\..\assets\icons\windows\client.ico"
!define MUI_FINISHPAGE_NOAUTOCLOSE

!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH

!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES

!insertmacro MUI_LANGUAGE "English"

Section "RetroChat" SEC_RETROCHAT
  SetOutPath "$INSTDIR"
  File "..\..\client.tcl"
  File "..\..\server.tcl"
  File "..\..\server-gui.tcl"
  File "README.txt"
  File "..\..\dist\RetroChat-client.exe"
  File "..\..\dist\RetroChat-server.exe"

  SetOutPath "$INSTDIR\lib"
  File "..\..\lib\protocol.tcl"

  SetOutPath "$INSTDIR\tests"
  File "..\..\tests\platform.test"
  File "..\..\tests\protocol.test"
  File "..\..\tests\relay.test"

  SetOutPath "$INSTDIR\assets\icons\png\client"
  File "..\..\assets\icons\png\client\client-tray.gif"
  SetOutPath "$INSTDIR\assets\icons\png\server"
  File "..\..\assets\icons\png\server\server-tray.gif"
  SetOutPath "$INSTDIR\assets\icons\windows"
  File "..\..\assets\icons\windows\client.ico"
  File "..\..\assets\icons\windows\server.ico"

  WriteRegStr HKCU "Software\RetroChat" "InstallDir" "$INSTDIR"
  WriteUninstaller "$INSTDIR\Uninstall.exe"

  SetOutPath "$TEMP"
  File "/oname=tcl805.exe" "${TCL805_INSTALLER}"
  MessageBox MB_OK "RetroChat uses Tcl/Tk 8.0.5. Its installer will open next. Accept its default C:\Program Files\Tcl directory so the RetroChat shortcuts work."
  ExecWait '"$TEMP\tcl805.exe"' $0
  Delete "$TEMP\tcl805.exe"

  IfFileExists "$PROGRAMFILES\Tcl\bin\wish80.exe" runtime_found
  MessageBox MB_ICONSTOP|MB_OK "Tcl/Tk was not found at $PROGRAMFILES\Tcl\bin. RetroChat was copied, but shortcuts were not created. Re-run Setup and accept Tcl/Tk's default directory."
  Goto done

runtime_found:
  CreateDirectory "$SMPROGRAMS\RetroChat"
  CreateShortCut "$SMPROGRAMS\RetroChat\RetroChat Client.lnk" "$INSTDIR\RetroChat-client.exe"
  CreateShortCut "$SMPROGRAMS\RetroChat\RetroChat Server.lnk" "$INSTDIR\RetroChat-server.exe"
  CreateShortCut "$SMPROGRAMS\RetroChat\Uninstall RetroChat.lnk" "$INSTDIR\Uninstall.exe"
  CreateShortCut "$DESKTOP\RetroChat Client.lnk" "$INSTDIR\RetroChat-client.exe"

done:
SectionEnd

Section "Uninstall"
  Delete "$DESKTOP\RetroChat Client.lnk"
  RMDir /r "$SMPROGRAMS\RetroChat"
  RMDir /r "$INSTDIR"
  DeleteRegKey HKCU "Software\RetroChat"

  MessageBox MB_YESNO "Remove Tcl/Tk 8.0.5 too? Keep it if another Tcl application uses it." IDNO keep_tcl
  IfFileExists "$PROGRAMFILES\Tcl\unins000.exe" 0 keep_tcl
  ExecWait '"$PROGRAMFILES\Tcl\unins000.exe"'
keep_tcl:
SectionEnd
