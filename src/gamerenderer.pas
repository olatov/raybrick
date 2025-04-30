unit GameRenderer;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, Math,
  RayLib, RayMath,
  GameState, GameModels;

type

  { TTextureAtlas }

  TTextureAtlas = class
    Texture: TTexture2D;
    BallRectangle: TRectangle;
    BrickRectangle: TRectangle;
    PaddleRectangle: TRectangle;
    destructor Destroy; override;
  end;

  { TRenderer }

  TRenderer = class abstract
  private
    procedure RenderBackground;
  public
    View: TRectangle;
    BackgroundTexture: TTexture2D;
    BackgroundTint: TColor;
    DefaultFont: TFont;
    constructor Create; virtual; overload;
    constructor Create(const AView: TRectangle); virtual; overload;
    procedure RenderTextCentered(AFont: TFont; const AText: String;
      FontSize: Integer; Color: TColor; Spacing: Single = 1);
    procedure Render; virtual; abstract;
    class procedure RenderTarget(const ATarget: TRenderTexture2D);
  end;

  { TTitleRenderer }

  TTitleRenderer = class(TRenderer)
  public
    FontInterlaced: TFont;
    FontRounded: TFont;
    ControlsTitle: String;
    ControlsTitleColor: TColor;
    ControlsLines: TStringArray;
    ControlsLinesColor: TColor;
    ControlsBoxColor: TColor;
    StartTextColor: TColor;
    StartText: String;
    constructor Create(const AView: TRectangle); override;
    procedure Render; override;
  end;

  { TGameRenderer }

  TGameRenderer = class(TRenderer)
  private
    FTextureAtlas: TTextureAtlas;
    procedure RenderTexture(
      const ASrcRectangle, ADestRectangle: TRectangle; ATint: TColor);
    procedure RenderBall(const ABall: TBall);
    procedure RenderBrick(const ABrick: TBrick);
    procedure RenderPaddle(const APaddle: TPaddle);
    procedure RenderBonus(const ABonus: TBonus);
    procedure RenderBullet(const ABullet: TBullet);
    procedure RenderWall(const AWall: TWall);
    procedure RenderGameObject(const AObject: TGameObject);
    procedure SetTextureAtlas(AValue: TTextureAtlas);
  public
    FontInterlaced: TFont;
    FontRounded: TFont;
    property TextureAtlas: TTextureAtlas read FTextureAtlas
      write SetTextureAtlas;
    procedure Render(const AState: TGameState); reintroduce;
  end;

implementation

{ TTextureAtlas }

destructor TTextureAtlas.Destroy;
begin
  inherited Destroy;
  UnloadTexture(Texture);
end;

{ TRenderer }

constructor TRenderer.Create(const AView: TRectangle);
begin
  View := AView;
  DefaultFont := GetFontDefault;
end;

procedure TRenderer.RenderBackground;
begin
  if not IsTextureValid(BackgroundTexture) then Exit;
  DrawTexture(BackgroundTexture, 0, 0, BackgroundTint);
end;

constructor TRenderer.Create;
begin
  Create(GameModels.View);
end;

procedure TRenderer.RenderTextCentered(
  AFont: TFont; const AText: String; FontSize: Integer; Color: TColor;
  Spacing: Single = 1);
var
  Chars: PChar;
  TextDimensions: TVector2;
begin
  Chars := PChar(AText);
  TextDimensions := MeasureTextEx(AFont, Chars, FontSize, Spacing);
  DrawTextEx(
    AFont, Chars,
    Vector2Create(
      (View.Width - TextDimensions.x) / 2,
      (View.Height - TextDimensions.y) / 2),
    FontSize, Spacing, Color);
end;

class procedure TRenderer.RenderTarget(const ATarget: TRenderTexture2D);
var
  DestRectangle: TRectangle;
const
  Aspect = 16 / 9;
begin
  if (GetScreenWidth / GetScreenHeight) <= (16 / 9) then
  begin
    DestRectangle.width := GetScreenWidth;
    DestRectangle.height := DestRectangle.width / Aspect;
    DestRectangle.x := 0;
    DestRectangle.y := (GetScreenHeight - DestRectangle.height) / 2
  end else
  begin
    DestRectangle.height := GetScreenHeight;
    DestRectangle.width := DestRectangle.height * Aspect;
    DestRectangle.x := (GetScreenWidth - DestRectangle.width) / 2;
    DestRectangle.y := 0;
  end;

  BeginDrawing;
    ClearBackground(BLACK);
    DrawTexturePro(
      ATarget.texture,
      RectangleCreate(
        0, 0,
        ATarget.texture.width, -ATarget.texture.height),
      DestRectangle,
      Vector2Zero,
      0,
      WHITE);
  EndDrawing;
end;


{ TTitleRenderer }

constructor TTitleRenderer.Create(const AView: TRectangle);
begin
  inherited Create(AView);
end;

procedure TTitleRenderer.Render;
var
  I: Integer;
  Rectangle: TRectangle;
  TextDimensions: TVector2;
  Chars: PChar;
begin
  RenderBackground;

  Rectangle := RectangleCreate(48, 48, 1116, 268);
  DrawRectangleRec(Rectangle, ControlsBoxColor);
  DrawRectangleLinesEx(Rectangle, 1, GRAY);

  if not ControlsTitle.IsEmpty then
    DrawTextEx(
      FontRounded, PChar(ControlsTitle),
      Vector2Create(88, 73), 24, 2, ControlsTitleColor);

  for I := 0 to High(ControlsLines) do
    DrawTextEx(
      FontRounded, PChar(ControlsLines[I]),
      Vector2Create(88, 123 + (20 * I)), 18, 2, ControlsLinesColor);

  if not StartText.IsEmpty then
  begin
    Chars := PChar(StartText);
    TextDimensions := MeasureTextEx(FontInterlaced, Chars, 36, 1);
    DrawTextEx(
      FontInterlaced, Chars,
      Vector2Create(
        (View.width - TextDimensions.x) / 2,
        (View.Height * 2/3) - (TextDimensions.y) / 2),
      36, 1, StartTextColor);
  end;
end;

{ TGameRenderer }

procedure TGameRenderer.RenderTexture(
  const ASrcRectangle, ADestRectangle: TRectangle;
  ATint: TColor);
begin
  DrawTexturePro(
    FTextureAtlas.Texture, ASrcRectangle, ADestRectangle,
    Vector2Zero, 0, ATint);
end;

procedure TGameRenderer.RenderBall(const ABall: TBall);
begin
  RenderTexture(FTextureAtlas.BallRectangle, ABall.Rectangle, ABall.Color);
end;

procedure TGameRenderer.RenderBrick(const ABrick: TBrick);
begin
  RenderTexture(FTextureAtlas.BrickRectangle, ABrick.Rectangle, ABrick.Color);
end;

procedure TGameRenderer.RenderPaddle(const APaddle: TPaddle);
var
  Rectangle: TRectangle;
  CatchObj: TCatch;
begin
  Rectangle := APaddle.Rectangle;

  CatchObj := APaddle.specialize FindPowerUp<TCatch>;
  if Assigned(CatchObj) then
    RenderTexture(
      FTextureAtlas.PaddleRectangle,
      RectangleCreate(
        Rectangle.x, Rectangle.y - 6, Rectangle.width, Rectangle.height),
      ColorAlpha(YELLOW, 0.8 * Min(5, CatchObj.LifetimeTimer) / 5));

  if Assigned(APaddle.Gun) then
  begin
    RenderTexture(
      FTextureAtlas.BallRectangle,
      RectangleCreate(Rectangle.x + 6, Rectangle.y - 8, 18, 18),
      RAYWHITE);

    RenderTexture(
      FTextureAtlas.BallRectangle,
      RectangleCreate(
        Rectangle.x + Rectangle.width - 24, Rectangle.y - 8, 18, 18),
      RAYWHITE);
  end;

  RenderTexture(FTextureAtlas.PaddleRectangle, Rectangle, APaddle.Color);
end;

procedure TGameRenderer.RenderBonus(const ABonus: TBonus);
var
  Text: String;
  TextDimensions: TVector2;
  FontSize: Integer = 12;
begin
  RenderTexture(FTextureAtlas.BrickRectangle, ABonus.Rectangle, ABonus.Color);

  case ABonus.BonusType of
    Score25: Text := '25';
    Score50: Text := '50';
    Score100: Text := '100';
    LongPaddle: Text := 'Long';
    SlowBall: Text := 'Slow';
    Gun: Text := 'Gun';
    ExtraBalls: Text := '3X';
    BigBall: Text := 'Big';
    QuickPaddle: Text := 'Quick';
    OneUp: Text := '1UP';
    Catch: Text := 'Catch';
    BottomWall: Text := 'Wall';
  end;

  if Length(Text) > 4 then Dec(FontSize, 2);

  TextDimensions := MeasureTextEx(FontRounded, PChar(Text), FontSize, 1);
  DrawTextEx(
    FontRounded,
    PChar(Text),
    Vector2Create(
      ABonus.Rectangle.x + (ABonus.Rectangle.width - TextDimensions.x) / 2,
      ABonus.Rectangle.y + (ABonus.Rectangle.height - TextDimensions.y) / 2),
    FontSize, 1, LIGHTGRAY);
end;

procedure TGameRenderer.RenderBullet(const ABullet: TBullet);
begin
  RenderTexture(FTextureAtlas.BallRectangle, ABullet.Rectangle, ABullet.Color);
end;

procedure TGameRenderer.RenderWall(const AWall: TWall);
var
  Alpha: Double = 1;
begin
  if not AWall.Visible then Exit;

  if not AWall.Permanent and (AWall.LifetimeTimer < 2) then
    Alpha := AWall.LifetimeTimer / 2;

  RenderTexture(FTextureAtlas.BrickRectangle, AWall.Rectangle,
    ColorAlpha(Yellow, Alpha));
end;

procedure TGameRenderer.RenderGameObject(const AObject: TGameObject);
begin
  DrawRectangleRec(AObject.Rectangle, AObject.Color);
end;

procedure TGameRenderer.SetTextureAtlas(AValue: TTextureAtlas);
begin
  FTextureAtlas := AValue;
  GenTextureMipmaps(@FTextureAtlas.Texture);
  SetTextureFilter(FTextureAtlas.Texture, TEXTURE_FILTER_TRILINEAR);
end;

procedure TGameRenderer.Render(const AState: TGameState);
  procedure DrawObjects;
  var
    Obj: TGameObject;
  begin
    for Obj in AState.Objects do
    begin
      if not Obj.Exists then Continue;

      if Obj is TBall then RenderBall(Obj as TBall)
      else if Obj is TBrick then RenderBrick(Obj as TBrick)
      else if Obj is TPaddle then RenderPaddle(Obj as TPaddle)
      else if Obj is TBonus then RenderBonus(Obj as TBonus)
      else if Obj is TBullet then RenderBullet(Obj as TBullet)
      else if Obj is TWall then RenderWall(Obj as TWall)
      else
        RenderGameObject(Obj);
    end;
  end;

  procedure DrawScore;
  var
    Chars: PChar;
    TextDimensions: TVector2;
    Rectangle: TRectangle;
  const
    FontSize = 36;
  begin
    Chars := PChar(
      Format(
        Format('%%.%du', [Max(8, Trunc(Log10(AState.Score)))]),
        [AState.Score]));
    TextDimensions := MeasureTextEx(FontInterlaced, Chars, FontSize, 1);

    Rectangle.width := TextDimensions.x * 1.05;
    Rectangle.height := TextDimensions.y * 1.1 - 2;
    Rectangle.x := 2;
    Rectangle.y := 2;

    DrawRectangleRounded(Rectangle, 0.3, 5,ColorAlpha(MAGENTA, 0.2));
    DrawTextEx(
      FontInterlaced, Chars,
      Vector2Create(
        TextDimensions.x * 0.025 + 2, (TextDimensions.y * 0.05) + 1),
        FontSize, 1, ColorBrightness(ORANGE, -0.1));
  end;

  procedure DrawLevel;
  var
    Chars: PChar;
    TextDimensions: TVector2;
    Rectangle: TRectangle;
  const
    FontSize = 36;
  begin
    Chars := PChar(Format('Level %d', [AState.Level]));
    TextDimensions := MeasureTextEx(FontInterlaced, Chars, FontSize, 1);

    Rectangle.width := TextDimensions.x * 1.1;
    Rectangle.height := TextDimensions.y * 1.05 - 2;
    Rectangle.x := View.width - Rectangle.width - 1;
    Rectangle.y := 2;

    DrawRectangleRounded(Rectangle, 0.3, 5,ColorAlpha(MAGENTA, 0.2));
    DrawTextEx(
      FontInterlaced, Chars,
      Vector2Create(
        View.Width - (TextDimensions.x * 1.05), (TextDimensions.y * 0.05) + 1),
      FontSize, 1, ColorBrightness(ORANGE, -0.1));
  end;

  procedure DrawSpareBalls;
  const
    Radius = 16;
    Interval = 36;
  var
    I: Integer;
  begin
    for I := 1 to Min(AState.SpareBallCount, 18) do
      RenderTexture(
        FTextureAtlas.BallRectangle,
        RectangleCreate(
          340 + (Interval * (I - 1)),
          (12 + Radius) / 2,
          Radius, Radius),
        ColorAlpha(WHITE, 0.9));
  end;

begin
  RenderBackground;

  DrawObjects;
  DrawLevel;
  DrawScore;
  DrawSpareBalls;

  if AState.Paused then RenderTextCentered(FontInterlaced, 'Paused', 36, RED);
  if AState.GameOver then RenderTextCentered(
    FontInterlaced, 'Game over', 72, RED);
end;

end.

