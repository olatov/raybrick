unit GameUtils;

{$mode ObjFPC}{$H+}

interface

uses
  RayLib;

procedure ApplyFullscreen(AFullscreen: Boolean);
function LoadTextureFromResource(
  const AResourceName: String; const AFileType: String): TTexture;
function LoadImageFromResource(const AResourceName: String;
  const AFileType: String): TImage;
function LoadMusicStreamFromResource(
  const AResourceName: String; const AFileType: String): TMusic;
function LoadSoundFromResource(
  const AResourceName: String; const AFileType: String): TSound;
function LoadFontFromResource(
  const AResourceName: String; const AFileType: String): TFont;

implementation

uses
  {$ifdef MSWINDOWS}
    Windows,
  {$endif}
  Classes, SysUtils;

procedure ApplyFullscreen(AFullscreen: Boolean);
begin
  if AFullscreen then
  begin
    RayLib.HideCursor;
    ClearWindowState(FLAG_WINDOW_RESIZABLE);
  end else
  begin
    RayLib.ShowCursor;
    SetWindowState(FLAG_WINDOW_RESIZABLE);
  end;
  ToggleBorderlessWindowed;
end;

function LoadTextureFromResource(
  const AResourceName: String; const AFileType: String): TTexture;
var
  Image: TImage;
begin
  Image := LoadImageFromResource(AResourceName, AFileType);
  try
    Result := LoadTextureFromImage(Image);
  finally
    UnloadImage(Image);
  end;
end;

function LoadImageFromResource(const AResourceName: String;
  const AFileType: String): TImage;
var
  Stream: TResourceStream;
begin
  Stream := TResourceStream.Create(HINSTANCE, AResourceName, RT_RCDATA);
  try
    Result := LoadImageFromMemory(PChar(AFileType), Stream.Memory, Stream.Size);
  finally
    FreeAndNil(Stream);
  end;
end;

function LoadMusicStreamFromResource(
  const AResourceName: String; const AFileType: String): TMusic;
var
  Stream: TResourceStream;
begin
  Stream := TResourceStream.Create(HINSTANCE, AResourceName, RT_RCDATA);
  try
    Result := LoadMusicStreamFromMemory(
      PChar(AFileType), Stream.Memory, Stream.Size);
  finally
    FreeAndNil(Stream);
  end;
end;

function LoadSoundFromResource(
  const AResourceName: String; const AFileType: String): TSound;
var
  Stream: TResourceStream;
  Wave: TWave;
begin
  Stream := TResourceStream.Create(HINSTANCE, AResourceName, RT_RCDATA);
  try
    Wave := LoadWaveFromMemory(PChar(AFileType), Stream.Memory, Stream.Size);
    try
      Result := LoadSoundFromWave(Wave);
    finally
      UnloadWave(Wave);
    end;
  finally
    FreeAndNil(Stream);
  end;
end;

function LoadFontFromResource(const AResourceName: String;
  const AFileType: String): TFont;
var
  Stream: TResourceStream;
begin
  Stream := TResourceStream.Create(HINSTANCE, AResourceName, RT_RCDATA);
  try
    Result := LoadFontFromMemory(
      PChar(AFileType), Stream.Memory, Stream.Size, 72, Nil, 0);
  finally
    FreeAndNil(Stream);
  end;
end;


end.

