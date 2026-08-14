unit GameUtils;

{$mode ObjFPC}{$H+}

interface

uses
  RayLib;

procedure ApplyFullscreen(AFullscreen: Boolean);
procedure LockMouse;
procedure ReleaseMouse;

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
  Classes, SysUtils, Types, StrUtils,
  FPImage, FPReadJPEG, FPWriteBMP,
  GameSettings;

procedure ApplyFullscreen(AFullscreen: Boolean);
begin
  if AFullscreen then
    ClearWindowState(FLAG_WINDOW_RESIZABLE)
  else
    SetWindowState(FLAG_WINDOW_RESIZABLE);
  ToggleBorderlessWindowed;
end;

procedure LockMouse;
begin
  Settings.MouseLocked := True;
  RayLib.HideCursor;
end;

procedure ReleaseMouse;
begin
  {$ifndef Darwin}
    if Settings.Fullscreen then Exit;
  {$endif}

  Settings.MouseLocked := False;
  RayLib.ShowCursor;
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
  Stream: specialize TScoped<TResourceStream>;
  MemoryImage: specialize TScoped<TFPMemoryImage>;
  ReaderJPEG: specialize TScoped<TFPReaderJPEG>;
  WriterBMP: specialize TScoped<TFPWriterBMP>;
  Buffer: specialize TScoped<TMemoryStream>;
begin
  Stream := TResourceStream.Create(HINSTANCE, AResourceName, RT_RCDATA);

  Result := LoadImageFromMemory(
    PChar(AFileType), Stream.Get.Memory, Stream.Get.Size);

  if not (IsImageValid(Result)) and MatchText(AFileType, ['.jpg', '.jpeg']) then
  begin
    {
      JPEG decoder isn't included in standard builds of recent raylib.
      Decode with FPImage and hand the result back to raylib as BMP.
    }

    MemoryImage := TFPMemoryImage.Create(0, 0);
    ReaderJPEG := TFPReaderJPEG.Create;
    WriterBMP := TFPWriterBMP.Create;

    Buffer := TMemoryStream.Create;
    Stream.Get.Position := 0;
    MemoryImage.Get.LoadFromStream(Stream.Get, ReaderJPEG.Get);
    MemoryImage.Get.SaveToStream(Buffer.Get, WriterBMP.Get);
    Result := LoadImageFromMemory('.bmp', Buffer.Get.Memory, Buffer.Get.Size);
  end;
end;

function LoadMusicStreamFromResource(
  const AResourceName: String; const AFileType: String): TMusic;
var
  Stream: specialize TScoped<TResourceStream>;
begin
  Stream := TResourceStream.Create(HINSTANCE, AResourceName, RT_RCDATA);
  Result := LoadMusicStreamFromMemory(
    PChar(AFileType), Stream.Get.Memory, Stream.Get.Size);
end;

function LoadSoundFromResource(
  const AResourceName: String; const AFileType: String): TSound;
var
  Stream: specialize TScoped<TResourceStream>;
  Wave: TWave;
begin
  Stream := TResourceStream.Create(HINSTANCE, AResourceName, RT_RCDATA);
  Wave := LoadWaveFromMemory(
    PChar(AFileType), Stream.Get.Memory, Stream.Get.Size);
  try
    Result := LoadSoundFromWave(Wave);
  finally
    UnloadWave(Wave);
  end;
end;

function LoadFontFromResource(const AResourceName: String;
  const AFileType: String): TFont;
const
  DefaultSize = 72;
var
  Stream: specialize TScoped<TResourceStream>;
begin
  Stream := TResourceStream.Create(HINSTANCE, AResourceName, RT_RCDATA);
  Result := LoadFontFromMemory(
    PChar(AFileType), Stream.Get.Memory, Stream.Get.Size, DefaultSize, Nil, 0);
end;

end.

