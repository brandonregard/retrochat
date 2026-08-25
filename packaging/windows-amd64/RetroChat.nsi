Unicode true

!include "MUI2.nsh"

!ifndef VERSION
!define VERSION "0.0.4"
!endif

Name "RetroChat ${VERSION} AMD64"
OutFile "..\..\dist\retrochat-${VERSION}-windows-amd64-setup.exe"
InstallDir "$LOCALAPPDATA\Programs\RetroChat"
InstallDirRegKey HKCU "Software\RetroChat" "InstallDir"
RequestExecutionLevel user
SetCompressor /SOLID lzma
ShowInstDetails show
ShowUninstDetails show

!define MUI_ABORTWARNING
!define MUI_ICON "..\..\assets\icons\windows\client.ico"
!define MUI_UNICON "..\..\assets\icons\windows\client.ico"

!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_LICENSE "..\..\LICENSE"
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
  File "/oname=LICENSE.txt" "..\..\LICENSE"
  File "/oname=RetroChat-client.exe" "..\..\dist\RetroChat-amd64-client.exe"
  File "/oname=RetroChat-server.exe" "..\..\dist\RetroChat-amd64-server.exe"

  SetOutPath "$INSTDIR\lib"
  File "..\..\lib\protocol.tcl"
  SetOutPath "$INSTDIR\assets\icons\png\client"
  File "..\..\assets\icons\png\client\client-tray.gif"
  File "..\..\assets\icons\png\client\client-128.png"
  SetOutPath "$INSTDIR\assets\icons\png\server"
  File "..\..\assets\icons\png\server\server-tray.gif"
  File "..\..\assets\icons\png\server\server-128.png"
  SetOutPath "$INSTDIR\assets\icons\windows"
  File "..\..\assets\icons\windows\client.ico"
  File "..\..\assets\icons\windows\server.ico"
  SetOutPath "$INSTDIR\runtime"
  File /r "..\..\dist\windows-amd64-runtime\*"

  WriteRegStr HKCU "Software\RetroChat" "InstallDir" "$INSTDIR"
  WriteUninstaller "$INSTDIR\Uninstall.exe"
  CreateDirectory "$SMPROGRAMS\RetroChat"
  CreateShortCut "$SMPROGRAMS\RetroChat\RetroChat Client.lnk" "$INSTDIR\RetroChat-client.exe"
  CreateShortCut "$SMPROGRAMS\RetroChat\RetroChat Server.lnk" "$INSTDIR\RetroChat-server.exe"
  CreateShortCut "$SMPROGRAMS\RetroChat\Uninstall RetroChat.lnk" "$INSTDIR\Uninstall.exe"
  CreateShortCut "$DESKTOP\RetroChat Client.lnk" "$INSTDIR\RetroChat-client.exe"
SectionEnd

Section "Uninstall"
  Delete "$DESKTOP\RetroChat Client.lnk"
  RMDir /r "$SMPROGRAMS\RetroChat"
  RMDir /r "$INSTDIR"
  DeleteRegKey HKCU "Software\RetroChat"
SectionEnd
