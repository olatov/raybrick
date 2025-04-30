unit GameScenes;

{$mode ObjFPC}{$H+}

interface

uses
  Generics.Collections,
  RayLib,
  GameState, GameRenderer;

type
  { TGameScene }

  TGameScene = class abstract
  protected
    procedure ToggleFullscreen;
    procedure ToggleMuted;
  public
    Target: TRenderTexture2D;
    constructor Create(ATarget: TRenderTexture2D); virtual;
    procedure Run; virtual;
  end;

  { TTitleScene }

  TTitleScene = class(TGameScene)
    Renderer: TTitleRenderer;
    constructor Create(ATarget: TRenderTexture2D); override;
    destructor Destroy; override;
    procedure Run; override;
  end;

  { TGamePlayScene }

  TGamePlayScene = class(TGameScene)
  private
    const
      BackgroundCount = 5;
    type
      TSoundEffect = (
        PaddleBounce, PaddleLose, BrickBounce, WallBounce, BonusCollect,
        BallExtra, GunShoot, BrickShot, BonusShot, LevelUp, GameOver);
      TSoundEffectRegistry = specialize TDictionary<TSoundEffect, TSound>;
    function BuildTextureAtlas: TTextureAtlas;
    procedure OnBonusShot(Sender: TObject);
    procedure OnBrickShot(Sender: TObject);
    procedure OnGainExtraBall(Sender: TObject);
  private
    State: TGameState;
    SoundEffects: TSoundEffectRegistry;
    Music: TMusic;
    Renderer: TGameRenderer;
  public
    constructor Create(ATarget: TRenderTexture2D); override;
    destructor Destroy; override;
    procedure OnPaddleBounce(Sender: TObject);
    procedure OnBallDestroy(Sender: TObject);
    procedure OnBrickBounce(Sender: TObject);
    procedure OnWallBounce(Sender: TObject);
    procedure OnBonusCollect(Sender: TObject);
    procedure OnGunShoot(Sender: TObject);
    procedure OnLevelUp(Sender: TObject);
    procedure OnGameOver(Sender: TObject);
    procedure Run; override;
    procedure BindEvents(AState: TGameState);
    procedure PlaySoundEffect(const AEffect: TSoundEffect);
  end;

implementation

uses
  Classes, SysUtils, Math,
  GameModels, GameSettings, GameUtils;

{ TGameScene }

constructor TGameScene.Create(ATarget: TRenderTexture2D);
begin
  Target := ATarget;
end;

procedure TGameScene.Run;
begin

end;

procedure TGameScene.ToggleFullscreen;
begin
  Settings.Fullscreen := not Settings.Fullscreen;
  ApplyFullscreen(Settings.Fullscreen);
end;

procedure TGameScene.ToggleMuted;
begin
  Settings.Muted := not Settings.Muted;
end;

{ TTitleScene }

constructor TTitleScene.Create(ATarget: TRenderTexture2D);
begin
  inherited Create(ATarget);

  Renderer := TTitleRenderer.Create;
  Renderer.BackgroundTexture := LoadTextureFromResource(
    'IMAGE-BACKGROUND-TITLE', '.jpg');;
  Renderer.BackgroundTint := GRAY;
  Renderer.FontRounded := LoadFontFromResource('FONT-ARCADE-R', '.ttf');
  Renderer.FontInterlaced := LoadFontFromResource('FONT-ARCADE-I', '.ttf');;
end;

destructor TTitleScene.Destroy;
begin
  if IsTextureValid(Renderer.BackgroundTexture) then
    UnloadTexture(Renderer.BackgroundTexture);

  UnloadFont(Renderer.FontRounded);
  UnloadFont(Renderer.FontInterlaced);
  FreeAndNil(Renderer);
end;

procedure TTitleScene.Run;
begin
  Renderer.ControlsBoxColor := ColorAlpha(DARKPURPLE, 0.7);

  Renderer.ControlsTitle := 'Controls';
  Renderer.ControlsTitleColor := ORANGE;

  Renderer.ControlsLines := [
    '[A] or [Left] or [Move mouse left]: Move paddle left',
    '[D] or [Right] or [Move mouse right]: Move paddle right',
    '[LCtrl] or [Space] or [Mouse left button]: Launch ball / Shoot',
    '[F] or [F11]: Toggle fullscreen',
    '[F12]: Release mouse',
    '[M]: Mute sound',
    '[P] or [Enter] or [Mouse right button]: Pause / resume',
    '[Esc]: Exit game'
  ];
  Renderer.ControlsLinesColor := YELLOW;

  Renderer.StartText := 'Press any key to start';

  while not WindowShouldClose do
  begin
    if (GetKeyPressed <> 0)
        or IsMouseButtonPressed(MOUSE_BUTTON_LEFT) then
      Break;

    Renderer.StartTextColor := specialize IfThen<TColor>(
      Sin(GetTime * 2) >= -0.9, ORANGE, BLANK);

    BeginTextureMode(Target);
      Renderer.Render;
    EndTextureMode;

    Renderer.RenderTarget(Target);
  end;
end;

{ TGamePlayScene }

function TGamePlayScene.BuildTextureAtlas: TTextureAtlas;
var
  Buffer: TImage;
  Image: TImage;
  Y: Integer = 0;
  MaxWidth: Integer = 0;
begin
  Result := TTextureAtlas.Create;
  Buffer := GenImageColor(512, 512, BLANK);

  Image := LoadImageFromResource('IMAGE-PADDLE', '.png');
  Result.PaddleRectangle := RectangleCreate(0, Y, Image.width, Image.height);
  ImageDraw(
    @Buffer, Image,
    RectangleCreate(0, 0, Image.width, Image.height),
    Result.PaddleRectangle,
    WHITE);
  Inc(Y, Image.height);
  MaxWidth := Max(MaxWidth, Image.width);
  UnloadImage(Image);

  Image := LoadImageFromResource('IMAGE-BRICK', '.png');
  Result.BrickRectangle := RectangleCreate(0, Y, Image.width, Image.height);
  ImageDraw(
    @Buffer, Image,
    RectangleCreate(0, 0, Image.width, Image.height),
    RectangleCreate(0, Y, Image.width, Image.height),
    WHITE);
  Inc(Y, Image.height);
  MaxWidth := Max(MaxWidth, Image.width);
  UnloadImage(Image);

  Image := LoadImageFromResource('IMAGE-BALL', '.png');
  Result.BallRectangle := RectangleCreate(0, Y, Image.width, Image.height);
  ImageDraw(
    @Buffer, Image,
    RectangleCreate(0, 0, Image.width, Image.height),
    RectangleCreate(0, Y, Image.width, Image.height),
    WHITE);
  Inc(Y, Image.height);
  MaxWidth := Max(MaxWidth, Image.width);
  UnloadImage(Image);

  ImageCrop(@Buffer, RectangleCreate(0, 0, MaxWidth, Y));
  Result.Texture := LoadTextureFromImage(Buffer);
  UnloadImage(Buffer);
end;

constructor TGamePlayScene.Create(ATarget: TRenderTexture2D);
  procedure LoadSoundEffects;
  begin
    SoundEffects.Add(PaddleBounce,
      LoadSoundFromResource('SOUND-PADDLE-BOUNCE', '.ogg'));

    SoundEffects.Add(PaddleLose,
      LoadSoundFromResource('SOUND-PADDLE-LOSE', '.ogg'));

    SoundEffects.Add(BrickBounce,
      LoadSoundFromResource('SOUND-BRICK-BOUNCE', '.ogg'));

    SoundEffects.Add(WallBounce,
      LoadSoundFromResource('SOUND-WALL-BOUNCE', '.ogg'));

    SoundEffects.Add(BonusCollect,
      LoadSoundFromResource('SOUND-BONUS-COLLECT', '.ogg'));

    SoundEffects.Add(GunShoot,
      LoadSoundFromResource('SOUND-GUN-SHOOT', '.ogg'));

    SoundEffects.Add(BrickShot,
      LoadSoundFromResource('SOUND-BRICK-SHOT', '.ogg'));

    SoundEffects.Add(BonusShot,
      LoadSoundFromResource('SOUND-BONUS-SHOT', '.ogg'));

    SoundEffects.Add(BallExtra,
      LoadSoundFromResource('SOUND-BALL-EXTRA', '.ogg'));

    SoundEffects.Add(LevelUp,
      LoadSoundFromResource('SOUND-LEVEL-UP', '.ogg'));

    SoundEffects.Add(GameOver,
      LoadSoundFromResource('SOUND-GAME-OVER', '.ogg'));
  end;

begin
  inherited Create(ATarget);

  State := TGameState.Create;
  BindEvents(State);

  Renderer := TGameRenderer.Create;
  Renderer.BackgroundTexture :=
    LoadTextureFromResource('IMAGE-BACKGROUND-1', '.jpg');
  Renderer.BackgroundTint := ColorCreate($60, $70, $80, $ff);
  Renderer.TextureAtlas := BuildTextureAtlas;
  Renderer.FontInterlaced := LoadFontFromResource('FONT-ARCADE-I', '.ttf');
  Renderer.FontRounded := LoadFontFromResource('FONT-ARCADE-R', '.ttf');

  SoundEffects := TSoundEffectRegistry.Create;
  LoadSoundEffects;
  Music := LoadMusicStreamFromResource('MUSIC', '.ogg');
end;

destructor TGamePlayScene.Destroy;
var
  Sound: TSound;
begin
  inherited Destroy;

  if IsTextureValid(Renderer.BackgroundTexture) then
    UnloadTexture(Renderer.BackgroundTexture);

  if Assigned(Renderer.TextureAtlas) then
  begin
    if IsTextureValid(Renderer.TextureAtlas.Texture) then
      UnloadTexture(Renderer.TextureAtlas.Texture);

    Renderer.TextureAtlas.Free;
  end;

  UnloadFont(Renderer.FontInterlaced);
  UnloadFont(Renderer.FontRounded);

  FreeAndNil(Renderer);
  FreeAndNil(State);

  UnloadMusicStream(Music);

  for Sound in SoundEffects.Values do
    UnloadSound(Sound);

  FreeAndNil(SoundEffects);
end;

procedure TGamePlayScene.OnPaddleBounce(Sender: TObject);
begin
  PlaySoundEffect(PaddleBounce);
end;

procedure TGamePlayScene.OnBallDestroy(Sender: TObject);
var
  Ball: TBall absolute Sender;
  Paddle: TPaddle;
  Obj: TGameObject;
begin
  Ball.Remove;

  { See if any other ball remain in the game }
  if Assigned(State.specialize FindObject<TBall>) then Exit;

  State.FindPaddle.Remove;
  Dec(State.SpareBallCount);

  PlaySoundEffect(PaddleLose);
  WaitTime(1.5);

  if State.GameOver then
  begin
    WaitTime(1);
    Exit;
  end;

  for Obj in State.Objects do
    if (Obj is TBonus) or ((Obj is TWall) and not (Obj as TWall).Permanent) then
      Obj.Remove;

  Paddle := State.SpawnPaddle;
  State.SpawnBall(Paddle);
end;

procedure TGamePlayScene.OnBrickBounce(Sender: TObject);
var
  Brick: TBrick absolute Sender;
begin
  PlaySoundEffect(BrickBounce);

  Dec(Brick.Hits);
  if Brick.Hits > 0 then Exit;

  State.GainScore(Brick.Score);

  if Assigned(Brick.Bonus) then
  begin
    Brick.Bonus.Position := Brick.Position;
    State.Objects.Add(Brick.Bonus);
  end;

  Brick.Bonus := Nil;
  Brick.Exists := False;
end;

procedure TGamePlayScene.OnBrickShot(Sender: TObject);
var
  Brick: TBrick absolute Sender;
begin
  PlaySoundEffect(BrickShot);

  Dec(Brick.Hits);
  if Brick.Hits > 0 then Exit;

  State.GainScore(Brick.Score);

  if Assigned(Brick.Bonus) then
  begin
    Brick.Bonus.Position := Brick.Position;
    State.Objects.Add(Brick.Bonus);
  end;

  Brick.Bonus := Nil;
  Brick.Exists := False;
end;

procedure TGamePlayScene.OnWallBounce(Sender: TObject);
begin
  PlaySoundEffect(WallBounce);
end;

procedure TGamePlayScene.OnBonusCollect(Sender: TObject);
begin
  PlaySoundEffect(
    specialize IfThen<TSoundEffect>(
      (Sender as TBonus).BonusType = OneUp, BallExtra, BonusCollect));
end;

procedure TGamePlayScene.OnGunShoot(Sender: TObject);
begin
  PlaySoundEffect(GunShoot);
end;

procedure TGamePlayScene.OnLevelUp(Sender: TObject);
var
  Ball: TBall;
begin
  PlaySoundEffect(LevelUp);

  if State.Level > 1 then State.GainScore(200);

  Ball := State.FindBall;
  Assert(Assigned(Ball));

  Ball.DefaultSpeed := Ball.DefaultSpeed + Ball.PerLevelSpeedIncrement;
  Ball.ResetSpeed;

  if IsTextureValid(Renderer.BackgroundTexture) then
    UnloadTexture(Renderer.BackgroundTexture);

  Renderer.BackgroundTexture := LoadTextureFromResource(
    Format(
      'IMAGE-BACKGROUND-%d',
      [((State.Level - 1) mod BackgroundCount) + 1]),
    '.jpg');
end;

procedure TGamePlayScene.OnGameOver(Sender: TObject);
begin
  PlaySoundEffect(GameOver);
end;

procedure TGamePlayScene.OnBonusShot(Sender: TObject);
var
  Bonus: TBonus absolute Sender;
begin
  PlaySoundEffect(BonusShot);
  Bonus.Exists := False;
end;

procedure TGamePlayScene.OnGainExtraBall(Sender: TObject);
begin
  PlaySoundEffect(BallExtra);
end;

procedure TGamePlayScene.Run;
  procedure HandleInput;
  var
    Obj: TGameObject;
    Wall: TWall;
    Paddle: TPaddle;
    MouseDelta: TVector2;
  begin
    if IsKeyPressed(KEY_F) or IsKeyPressed(KEY_F11) then ToggleFullscreen;
    if IsKeyPressed(KEY_M) then Settings.Muted := not Settings.Muted;

    if not State.GameOver then
    begin
      if IsKeyPressed(KEY_P) or IsKeyPressed(KEY_ENTER)
          or IsMouseButtonPressed(MOUSE_RIGHT_BUTTON)
        then State.TogglePause;

      Paddle := State.FindPaddle;
      Assert(Assigned(Paddle));
      Paddle.Stop;

      if IsKeyDown(KEY_LEFT) or IsKeyDown(KEY_A) then
        Paddle.Move(Vector2Create(-1, 0));

      if IsKeyDown(KEY_RIGHT) or IsKeyDown(KEY_D) then
        Paddle.Move(Vector2Create(1, 0));

      MouseDelta := GetMouseDelta;
      if not IsZero(MouseDelta.x) then
        Paddle.Move(Vector2Create(
          MouseDelta.x * Settings.MouseSensitivity * 0.01, 0));

      if IsKeyDown(KEY_SPACE) or IsKeyDown(KEY_LEFT_CONTROL)
          or IsMouseButtonDown(MOUSE_BUTTON_LEFT) then
      begin
        State.LaunchBalls;
        State.Shoot;

        if IsMouseButtonDown(MOUSE_BUTTON_LEFT)
            and not Settings.MouseLocked then
          LockMouse;
      end;

      if IsKeyPressed(KEY_F12) then ReleaseMouse;

      if Settings.MouseLocked then
        SetMousePosition(Trunc(View.width / 2), Trunc(View.height / 2));
    end;
  end;

begin
  PlayMusicStream(Music);
  Music.Looping := True;
  SetMusicVolume(Music, 0.5);

  { Prevent going on pause immediately if Enter was pressed to start the game }
  while IsKeyDown(KEY_ENTER) do
  begin
    WaitTime(0.05);
    PollInputEvents;
  end;

  while not WindowShouldClose do
  begin
    HandleInput;
    if not State.GameOver then
    begin
      if not (Settings.Muted or State.Paused) then UpdateMusicStream(Music);
      State.Update(EnsureRange(GetFrameTime, 0.0001, 0.1));
    end
    else if GetKeyPressed <> 0 then Break;

    BeginTextureMode(Target);
      Renderer.Render(State);
      if Settings.ShowFPS then DrawFPS(600, 5);
    EndTextureMode;

    Renderer.RenderTarget(Target);
  end;

  StopMusicStream(Music);
end;

procedure TGamePlayScene.BindEvents(AState: TGameState);
begin
  AState.OnBallDestroy := @OnBallDestroy;
  AState.OnBonusCollect := @OnBonusCollect;
  AState.OnBonusShot := @OnBonusShot;
  AState.OnBrickBounce := @OnBrickBounce;
  AState.OnBrickShot := @OnBrickShot;
  AState.OnBonusShot := @OnBonusShot;
  AState.OnGainExtraBall := @OnGainExtraBall;
  AState.OnGameOver := @OnGameOver;
  AState.OnBallDestroy := @OnBallDestroy;
  AState.OnGunShoot := @OnGunShoot;
  AState.OnLevelUp := @OnLevelUp;
  AState.OnPaddleBounce := @OnPaddleBounce;
  AState.OnWallBounce := @OnWallBounce;
end;

procedure TGamePlayScene.PlaySoundEffect(const AEffect: TSoundEffect);
begin
  if Settings.Muted then Exit;
  PlaySound(SoundEffects[AEffect]);
end;

end.

