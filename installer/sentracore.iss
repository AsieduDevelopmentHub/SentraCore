[Setup]
AppName=SentraCore
AppVersion=0.0.1
AppPublisher=SentraCore Development Team
DefaultDirName={autopf}\SentraCore
DefaultGroupName=SentraCore
OutputDir=..\dist
OutputBaseFilename=SentraCore_Setup_v0.0.1
Compression=lzma
SolidCompression=yes
; Use the same brandmark icon as the dashboard
SetupIconFile=..\dashboard\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\sentracore_dashboard.exe

[Files]
; The Python Engine (Headless executable)
Source: "..\dist\SentraCoreEngine.exe"; DestDir: "{app}"; Flags: ignoreversion

; Shared config (must exist before engine or dashboard runs — same folder as both .exe files)
Source: "..\dashboard\assets\engine-config.json"; DestDir: "{app}"; Flags: ignoreversion

; The Flutter Dashboard and all its dependencies
Source: "..\dashboard\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
; Start Menu Shortcut for the Dashboard
Name: "{group}\SentraCore Dashboard"; Filename: "{app}\sentracore_dashboard.exe"
; Desktop Shortcut for the Dashboard
Name: "{autodesktop}\SentraCore Dashboard"; Filename: "{app}\sentracore_dashboard.exe"; Tasks: desktopicon
; Uninstaller Shortcut
Name: "{group}\Uninstall SentraCore"; Filename: "{uninstallexe}"

[Tasks]
Name: "desktopicon"; Description: "Create a &desktop shortcut"; GroupDescription: "Additional icons:"

[Registry]
; Policy A: engine runs only when the dashboard is opened.
; Ensure upgrades remove any legacy auto-start entry from older installers.
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; ValueType: string; ValueName: "SentraCoreEngine"; Flags: deletevalue uninsdeletevalue

[Run]
; Optionally launch the dashboard
Filename: "{app}\sentracore_dashboard.exe"; Description: "Launch SentraCore Dashboard"; Flags: nowait postinstall

[UninstallRun]
; Attempt to gracefully kill the engine process during uninstallation
Filename: "{cmd}"; Parameters: "/c taskkill /f /im SentraCoreEngine.exe"; Flags: runhidden waituntilterminated
