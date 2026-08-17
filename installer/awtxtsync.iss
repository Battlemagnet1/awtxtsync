; AWtxtSync Windows 安装包脚本 (Inno Setup 6)
; 用法：先 flutter build windows --release，再用 ISCC.exe 编译本脚本

#define MyAppName "AWtxtSync"
#define MyAppVersion "1.0.1"
#define MyAppExeName "awtxtsync.exe"

[Setup]
AppId={{7B9D2C4E-5A6F-4B3C-9E1D-AWtxtSync0001}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher=AWtxtSync
AppPublisherURL=https://github.com/Battlemagnet1/awtxtsync
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
OutputDir=..\build\installer
OutputBaseFilename=AWtxtSync-Setup-{#MyAppVersion}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=lowest

[Languages]
Name: "chinesesimplified"; MessagesFile: "compiler:Default.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "创建桌面快捷方式"; GroupDescription: "附加任务:"; Flags: unchecked

[Files]
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "立即运行 {#MyAppName}"; Flags: nowait postinstall skipifsilent
