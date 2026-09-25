#define MyAppName "EMAP - Extracción de Aportaciones (PDF)"
#define MyAppVersion "1.0.1"
#define MyAppPublisher "Aldo Ortiz UPDS"
#define MyAppExeName "emap.exe"
; Ruta a la carpeta Release, inyectada desde el workflow por la variable EMAP_RELEASE.
#ifndef EMAPRelease
  #define EMAPRelease GetEnv("EMAP_RELEASE")
#endif
; Rutas absolutas inyectadas desde el workflow mediante EMAP_ICON y EMAP_OUTPUT.
; ISCC no resuelve de forma fiable las rutas relativas (ni la base del script ni el CWD),
; por eso el workflow pasa rutas absolutas. Compilando en local hay que exportarlas:
;   $env:EMAP_ICON = (Resolve-Path .\assets\logos\app_icon.ico).Path
;   $env:EMAP_OUTPUT = (Join-Path (Get-Location) 'installer\Output')
#ifndef EMAPIcon
  #define EMAPIcon GetEnv("EMAP_ICON")
#endif
#ifndef EMAPOutput
  #define EMAPOutput GetEnv("EMAP_OUTPUT")
#endif

[Setup]
AppId={{B8C4E2A0-5B31-4A77-9C0E-2F6A1D5C3B9E}
AppName={#MyAppName}
SetupIconFile={#EMAPIcon}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL=https://github.com/OrtizAldoB/emap-certificados
VersionInfoVersion={#MyAppVersion}
VersionInfoCompany={#MyAppPublisher}
VersionInfoDescription={#MyAppName}
VersionInfoProductName={#MyAppName}
VersionInfoProductVersion={#MyAppVersion}
VersionInfoCopyright=Copyright (C) 2026 {#MyAppPublisher}
DefaultDirName={autopf}\EMAP Aportaciones
DefaultGroupName=EMAP Aportaciones
UninstallDisplayIcon={app}\{#MyAppExeName}
OutputDir={#EMAPOutput}
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
