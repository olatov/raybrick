unit GameSettings;

{$mode ObjFPC}{$H+}

interface

type

  { TSettings }

  TSettings = class
    Fullscreen: Boolean;
    WindowWidth: Integer;
    WindowHeight: Integer;
    HiDPI: Boolean;
    TargetFPS: Integer;
    VSync: Boolean;
    ShowFPS: Boolean;
    Muted: Boolean;
    MouseSensitivity: Single;
    MouseLocked: Boolean;
    Filename: String;
    constructor Create;
    constructor Create(const AFileName: String);
    procedure LoadFromFile(const AFilename: String);
    procedure SaveToFile(const AFilename: String);
    procedure Load;
    procedure Save;
  end;

  var
    Settings: TSettings;

implementation

uses
  SysUtils, IniFiles,
  RayLib,
  GameModels;

{ TSettings }

constructor TSettings.Create;
begin
  Create(GetAppConfigFile(False));
end;

constructor TSettings.Create(const AFileName: String);
begin
  Filename := AFilename;
  MouseLocked := True;
end;

procedure TSettings.LoadFromFile(const AFilename: String);
var
  SettingsFile: TIniFile;
begin
  SettingsFile := TIniFile.Create(AFilename);
  try
    Fullscreen := SettingsFile.ReadBool('window', 'fullscreen', False);
    WindowWidth := SettingsFile.ReadInteger(
      'window', 'width', Round(View.Width));
    WindowHeight := SettingsFile.ReadInteger(
      'window', 'height', Round(View.Height));
    HiDPI := SettingsFile.ReadBool('window', 'hi_dpi', False);
    TargetFPS := SettingsFile.ReadInteger('window', 'target_fps', 0);
    VSync := SettingsFile.ReadBool('window', 'vsync', True);
    ShowFPS := SettingsFile.ReadBool('window', 'show_fps', False);
    Muted := SettingsFile.ReadBool('audio', 'muted', False);
    MouseSensitivity := SettingsFile.ReadFloat(
      'control', 'mouse_sensitivity', 12);
  finally
    FreeAndNil(SettingsFile);
  end;
end;

procedure TSettings.SaveToFile(const AFilename: String);
var
  SettingsFile: TIniFile;
begin
  SettingsFile := TIniFile.Create(AFilename);
  try
    SettingsFile.WriteBool('window', 'fullscreen', Fullscreen);
    if not Fullscreen then
    begin
      SettingsFile.WriteInteger('window', 'width', WindowWidth);
      SettingsFile.WriteInteger('window', 'height', WindowHeight);
    end;
    SettingsFile.WriteBool('window', 'hi_dpi', HiDPI);
    SettingsFile.WriteInteger('window', 'target_fps', TargetFPS);
    SettingsFile.WriteBool('window', 'vsync', VSync);
    SettingsFile.WriteBool('window', 'show_fps', ShowFPS);
    SettingsFile.WriteBool('audio', 'muted', Muted);
    SettingsFile.WriteFloat('control', 'mouse_sensitivity', MouseSensitivity);
  finally
    FreeAndNil(SettingsFile);
  end;
end;

procedure TSettings.Load;
begin
  LoadFromFile(Filename);
end;

procedure TSettings.Save;
begin
  SaveToFile(Filename);
end;

initialization
  Settings := TSettings.Create;
  try
    Settings.Load;
  except
    on E: Exception do
      begin
        TraceLog(
          LOG_ERROR,
          PChar(Format('Error loading settings: %s', [E.Message])));
        { Some defaults as fallback }
        Settings.WindowWidth := 1280;
        Settings.WindowHeight := 720;
        Settings.Fullscreen := False;
        Settings.VSync := True;
        Settings.Muted := False;
      end;
  end;

finalization
  try
    Settings.Save;
  finally
    FreeAndNil(Settings);
  end;

end.

