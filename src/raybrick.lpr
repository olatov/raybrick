{
  Copyright 2025 Nimbus

  Permission is hereby granted, free of charge, to any person obtaining a copy
  of this software and associated documentation files (the "Software"),
  to deal in the Software without restriction, including without limitation
  the rights to use, copy, modify, merge, publish, distribute, sublicense,
  and/or sell copies of the Software, and to permit persons to whom
  the Software is furnished to do so, subject to the following conditions:

  The above copyright notice and this permission notice shall be included
  in all copies or substantial portions of the Software.

  THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS
  OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
  THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
  IN THE SOFTWARE.
}

program Raybrick;

{$mode objfpc}{$H+}

{$ifdef DARWIN}
  {$linkframework Cocoa}
  {$linkframework IOKit}
{$endif}

uses
  Classes, SysUtils, CustApp, System.Diagnostics,
  RayLib, RayMath,
  GameModels, GameSettings, GameScenes, GameUtils, GameRenderer;

type
  { TRayApplication }

  TRayApplication = class(TCustomApplication)
  protected
    Target: TRenderTexture2D;
    procedure DoRun; override;
    generic procedure RunScene<T: TGameScene>;
  public
    constructor Create(TheOwner: TComponent); override;
    destructor Destroy; override;
  end;

const
  AppTitle = 'raybrick';

{ TRayApplication }

constructor TRayApplication.Create(TheOwner: TComponent);
  function MeasureFPS(ADuration: Integer = 1000): Integer;
  var
    Rectangle: TRectangle;
    FullWidth: Single;
    SW: TStopwatch;
  begin
    FullWidth := View.width * 0.5;
    Rectangle.width := FullWidth;
    Rectangle.height := View.height * 1/32;
    Rectangle.x := (View.width - Rectangle.width) / 2;
    Rectangle.y := (View.height - Rectangle.height) / 2;

    SW := TStopwatch.StartNew;
    repeat
      BeginTextureMode(Target);
        ClearBackground(ColorCreate(0, 0, 32, 255));
        Rectangle.width := FullWidth;
        DrawRectangleLinesEx(Rectangle, 1, GRAY);
        Rectangle.width := SW.ElapsedMilliseconds / ADuration * FullWidth;
        DrawRectangleRec(Rectangle, VIOLET);
        Result := GetFPS;
      EndTextureMode;
      TRenderer.RenderTarget(Target);
    until SW.ElapsedMilliseconds > ADuration;
  end;

  procedure ConfigureFPS;
  var
    FPS: Integer;
  begin
    if Settings.TargetFPS > 0 then
      SetTargetFPS(Settings.TargetFPS)
    else if Settings.TargetFPS = 0 then
    begin
      FPS := MeasureFPS;
      if FPS > 144 then
        { Hard limit when VSync didn't work }
        SetTargetFPS(60);
    end;
  end;

begin
  inherited Create(TheOwner);

  Randomize;

  SetConfigFlags(FLAG_WINDOW_RESIZABLE);
  if Settings.VSync then SetConfigFlags(FLAG_VSYNC_HINT);
  if Settings.HiDPI then SetConfigFlags(FLAG_WINDOW_HIGHDPI);

  InitWindow(Settings.WindowWidth, Settings.WindowHeight, 'raybrick');

  Target := LoadRenderTexture(Round(View.Width), Round(View.Height));
  SetTextureFilter(Target.texture, TEXTURE_FILTER_BILINEAR);

  ConfigureFPS;
  LockMouse;

  if Settings.Fullscreen then ApplyFullscreen(Settings.Fullscreen);

  InitAudioDevice;
end;

procedure TRayApplication.DoRun;
begin
  repeat
    specialize RunScene<TTitleScene>;
    specialize RunScene<TGamePlayScene>;
  until WindowShouldClose;

  Terminate;
end;

generic procedure TRayApplication.RunScene<T>;
var
  Scene: T;
begin
  Scene := T.Create(Target);
  try
    Scene.Run;
  finally
    FreeAndNil(Scene);
  end;
end;

destructor TRayApplication.Destroy;
begin
  ReleaseMouse;
  UnloadRenderTexture(Target);

  Settings.WindowWidth := GetScreenWidth;
  Settings.WindowHeight := GetScreenHeight;

  ClearWindowState(FLAG_WINDOW_MAXIMIZED);
  SetWindowSize(320, 200);

  CloseAudioDevice;
  CloseWindow;

  inherited Destroy;
end;

var
  Application: TRayApplication;

{$R *.res}

begin
  Application := TRayApplication.Create(Nil);
  try
    Application.Title := AppTitle;
    Application.Run;
  finally
    FreeAndNil(Application);
  end;
end.

