#define MyAppName "EMAP - Extracción de Aportaciones (PDF)"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "EMAP - Entidad Municipal de Aseo Potosí"
#define MyAppExeName "emap.exe"
; Ruta a la carpeta Release, inyectada desde el workflow por la variable EMAP_RELEASE.
#ifndef EMAPRelease
  #define EMAPRelease GetEnv("EMAP_RELEASE")
#endif

[Setup]
AppId={{B8C4E2A0-5B31-4A77-9C0E-2F6A1D5C3B9E}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\EMAP Aportaciones
DefaultGroupName=EMAP Aportaciones
UninstallDisplayIcon={app}\{#MyAppExeName}
OutputDir=Output
OutputBaseFilename=EMAP_Certificados_Setup
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesInstallIn64BitMode=x64compatible
ArchitecturesAllowed=x64compatible

[Languages]
Name: "spanish"; MessagesFile: "compiler:Languages\Spanish.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "{#EMAPRelease}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\Desinstalar {#MyAppName}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent
