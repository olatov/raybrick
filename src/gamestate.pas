unit GameState;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, Generics.Collections,
  RayLib,
  GameModels;

type
  { TGameState }

  TGameState = class
  const
    BonusChances = 0.1;
    ScoreForExtraBall = 2000;
  private
    FPaused: Boolean;
    function GetGameOver: Boolean;
    procedure SetPaused(AValue: Boolean);
  public
    Level: LongWord;
    SpareBallCount: Integer;
    Score: UInt64;
    Objects: TGameObjectList;
    OnPaddleBounce: TNotifyEvent;
    OnBrickBounce: TNotifyEvent;
    OnBrickShot: TNotifyEvent;
    OnBallShot: TNotifyEvent;
    OnWallBounce: TNotifyEvent;
    OnBonusCollect: TNotifyEvent;
    OnBallDestroy: TNotifyEvent;
    OnGunShoot: TNotifyEvent;
    OnBonusShot: TNotifyEvent;
    OnGameOver: TNotifyEvent;
    OnLevelUp: TNotifyEvent;
    OnGainExtraBall: TNotifyEvent;
    function FindBall: TBall;
    function FindPaddle: TPaddle;
    property Paused: Boolean read FPaused write SetPaused;
    property GameOver: Boolean read GetGameOver;
    constructor Create;
    destructor Destroy; override;
    generic function FindObject<T: TGameObject>: T;
    generic function FindObjects<T: TGameObject>: specialize TArray<T>;
    function SpawnBall(APaddle: TPaddle): TBall;
    function SpawnPaddle: TPaddle;
    procedure SpawnBricks;
    procedure Update(const ADT: Single);
    procedure TogglePause;
    procedure CollectBonus(ABonus: TBonus);
    procedure Shoot;
    procedure LaunchBalls;
    procedure GainScore(AScore: LongWord);
    procedure LevelUp;
  end;

implementation

uses
  SysUtils, Math,
  RayMath,
  GameMath;

{ TGameState }

function TGameState.GetGameOver: Boolean;
begin
  Result := (SpareBallCount < 0);
end;

function TGameState.FindBall: TBall;
begin
  Result := specialize FindObject<TBall>;
end;

function TGameState.FindPaddle: TPaddle;
begin
  Result := specialize FindObject<TPaddle>;
end;

procedure TGameState.SetPaused(AValue: Boolean);
begin
  if GameOver then Exit;
  FPaused := AValue;
end;

procedure TGameState.Update(const ADT: Single);
var
  Ball: TBall;
  Paddle: TPaddle;
  Bonus: TBonus;
  Brick: TBrick;
  Bullet: TBullet;
  Wall: TWall;
  Current, Other: TGameObject;
  Destroyer: TBallDestroyer;
begin
  if Paused or GameOver then Exit;

  Paddle := FindPaddle;
  if not Assigned(Paddle) then Paddle := SpawnPaddle;

  Ball := FindBall;
  if not Assigned(FindBall) then Ball := SpawnBall(Paddle);

  if not Assigned(specialize FindObject<TBrick>)
      and (Ball.Position.y > (View.Height * 2/3)) then
    LevelUp;

  for Current in Objects do
  begin
    if not Current.Exists then Continue;

    Current.Update(ADT);

    if not (
        (Current is TPaddle)
        or (Current is TBall)
        or (Current is TBullet)) then
      Continue;

    for Other in Objects do
    begin
      if (Current = Other) or not Other.Exists then Continue;

      if Current is TBall then
      begin
        Ball := (Current as TBall);
        Assert(Ball.Position.y < (View.height * 2));

        { Ball / Paddle collision }
        if Other is TPaddle then
        begin
          Paddle := (Other as TPaddle);

          if (Ball.Velocity.y > 0) and Ball.CollidesWith(Paddle) then
          begin
            Ball.BounceOff(Paddle);
            Ball.Velocity := Ball.Velocity
              + Vector2Scale(
                  Vector2Normalize(Ball.Velocity),
                  Ball.BaseSpeed * 0.005);

            if Paddle.HasCatch then
            begin
              Ball.JoinWith(Paddle);
              Ball.Velocity := Vector2Scale(
                Vector2Normalize(Ball.Velocity),
                Ball.DefaultSpeed);
              Continue;
            end;

            if Assigned(OnPaddleBounce) then OnPaddleBounce(Paddle);
          end;
          Continue;
        end;

        { Ball / Brick collision }
        if Other is TBrick then
        begin
          Brick := (Other as TBrick);
          if Ball.CollidesWith(Brick) then
          begin
            Dec(Brick.Hits);
            if Assigned(OnBrickBounce) then OnBrickBounce(Brick);

            Ball.BounceOff(Brick);
            Break;
          end;
          Continue;
        end;

        { Ball / Wall collision }
        if Other is TWall then
        begin
          Wall := (Other as TWall);
          if Ball.CollidesWith(Wall) then
          begin
            if Assigned(OnWallBounce) then OnWallBounce(Wall);
            Ball.BounceOff(Wall);
          end;
          Continue;
        end;

        { Ball / Destroyer collision }
        if Other is TBallDestroyer then
        begin
          Destroyer := (Other as TBallDestroyer);
          if Ball.CollidesWith(Destroyer) and Assigned(OnBallDestroy) then
          begin
            OnBallDestroy(Ball);
            if GameOver then
            begin
              if Assigned(OnGameOver) then OnGameOver(Nil);
              Exit;
            end;
          end;
        end;
        Continue;
      end;

      if Current is TPaddle then
      begin
        Paddle := Current as TPaddle;

        { Paddle / Bonus collision }
        if Other is TBonus then
        begin
          Bonus := (Other as TBonus);
          if Paddle.CollidesWith(Bonus) then
          begin
            if Assigned(OnBonusCollect) then OnBonusCollect(Bonus);
            CollectBonus(Bonus);
          end;
        end;
        Continue;
      end;

      if Current is TBullet then
      begin
        Bullet := (Current as TBullet);

        { Bullet / Brick collision }
        if Other is TBrick then
        begin
          Brick := (Other as TBrick);
          if Bullet.CollidesWith(Brick) then
          begin
            if Assigned(OnBrickShot) then OnBrickShot(Brick);
            Bullet.Remove;
            Break;
          end;
          Continue;
        end;

        { Bullet / Bonus collision }
        if Other is TBonus then
        begin
          Bonus := (Other as TBonus);
          if Bullet.CollidesWith(Bonus) then
          begin
            if Assigned(OnBonusShot) then OnBonusShot(Bonus);
            Bullet.Remove;
            Break;
          end;
          Continue;
        end;

        { Bullet / Ball collision }
        if Other is TBall then
        begin
          Ball := (Other as TBall);
          if Bullet.CollidesWith(Ball) then
          begin
            if Assigned(OnBallShot) then OnBallShot(Ball);
            Bullet.Remove;
            Break;
          end;
        end;
      end;
    end;
  end;

  for Current in Objects do
    if not Current.Exists then
      Objects.Remove(Current);
end;

procedure TGameState.TogglePause;
begin
  Paused := not Paused;
end;

procedure TGameState.CollectBonus(ABonus: TBonus);
var
  Paddle: TPaddle;
  Ball, NewBall: TBall;
  Wall: TWall;
  ExistingCatch: TCatch;
  I: Integer;
begin
  if not ABonus.Exists then Exit;

  case ABonus.BonusType of
    Score25: GainScore(25);
    Score50: GainScore(50);
    Score100: GainScore(100);

    LongPaddle:
      begin
        Paddle := FindPaddle;
        Assert(Assigned(Paddle));
        Paddle.PowerUps.Add(TLargePaddle.Create(30));
      end;

    SlowBall:
      begin
        for Ball in specialize FindObjects<TBall> do
        begin
          Ball.ResetSpeed;
          Ball.PowerUps.Add(TSlowBall.Create(20));
        end;
      end;

    ExtraBalls:
      begin
        for Ball in specialize FindObjects<TBall> do
          for I := 1 to 2 do
          begin
            NewBall := Ball.Clone;
            NewBall.Velocity := Vector2Rotate(
              Ball.Velocity,
              30 * IntPower(-1, I) * DEG2RAD);
            Objects.Add(NewBall);
          end;
        end;

    BigBall:
      for Ball in specialize FindObjects<TBall> do
        Ball.PowerUps.Add(TBigBall.Create(20));

    Gun:
      begin
        Paddle := FindPaddle;
        Assert(Assigned(Paddle));
        Paddle.PowerUps.Add(TGun.Create(10, 1/3));
      end;

    QuickPaddle:
      begin
        Paddle := FindPaddle;
        Assert(Assigned(Paddle));
        Paddle.PowerUps.Add(TQuickPaddle.Create(30));
      end;

    Catch:
      begin
        Paddle := FindPaddle;
        Assert(Assigned(Paddle));
        ExistingCatch := Paddle.specialize FindPowerUp<TCatch>;
        if Assigned(ExistingCatch) then
          ExistingCatch.LifetimeTimer := Max(ExistingCatch.LifetimeTimer, 25)
        else
          Paddle.PowerUps.Add(TCatch.Create(25));
      end;

    BottomWall:
      begin
        for Wall in specialize FindObjects<TWall> do
          if not Wall.Permanent then
            Wall.Remove;

        Wall := TWall.Create;
        Wall.Dimensions := Vector2Create(0, 16);
        Wall.BaseWidth := View.Width;
        Wall.Position := Vector2Create(View.Width / 2, View.Height - 18);
        Wall.Color := ORANGE;
        Wall.LifetimeTimer := 30;
        Wall.Visible := True;
        Wall.Permanent := False;

        for Ball in specialize FindObjects<TBall> do
          while Ball.CollidesWith(Wall) do
            Ball.Position.y := Ball.Position.y - Ball.EffectiveRadius;

        Objects.Add(Wall);
      end;

    OneUp:
      Inc(SpareBallCount);
  end;

  ABonus.Remove;
end;

procedure TGameState.Shoot;
var
  NewBullets: TGunGulp;
  Rectangle: TRectangle;
  Paddle: TPaddle;
begin
  Paddle := FindPaddle;
  if not (Assigned(Paddle) and Assigned(Paddle.Gun) and Paddle.Gun.Ready) then
    Exit;

  NewBullets := Paddle.Gun.Shoot;
  Rectangle := Paddle.Rectangle;

  Vector2Set(
    @NewBullets[1].Position,
    Rectangle.x + 15,
    Rectangle.y);

  Vector2Set(
    @NewBullets[2].Position,
    Rectangle.x + Rectangle.width - 15,
    Rectangle.y - 6);

  Objects.Add(NewBullets[1]);
  Objects.Add(NewBullets[2]);

  if Assigned(OnGunShoot) then OnGunShoot(Paddle.Gun);
end;

procedure TGameState.LaunchBalls;
var
  Ball: TBall;
begin
  for Ball in specialize FindObjects<TBall> do
    if Ball.Caught then
      Ball.Launch;
end;

procedure TGameState.GainScore(AScore: LongWord);
var
  NewScore: LongWord;
begin
  NewScore := Score + AScore;
  if (NewScore div ScoreForExtraBall) > (Score div ScoreForExtraBall) then
  begin
    Inc(SpareBallCount);
    if Assigned(OnGainExtraBall) then OnGainExtraBall(Nil);
  end;

  Score := NewScore;
end;

procedure TGameState.LevelUp;
begin
  Inc(Level);
  SpawnBricks;

  if Assigned(OnLevelUp) then OnLevelUp(Nil);
end;

constructor TGameState.Create;
  procedure Init;
  var
    Wall: TWall;
    BallDestroyer: TBallDestroyer;
  begin
    Objects.Clear;

    SpareBallCount := 2;
    Score := 0;

    SpawnPaddle;

    { Left }
    Wall := TWall.Create;
    Wall.Dimensions := Vector2Create(100, View.Height * 2);
    Wall.Position := Vector2Create(
       -Wall.Dimensions.x / 2,
      View.Height / 2);
    Wall.Permanent := True;
    Wall.Visible := False;
    Objects.Add(Wall);

    { Right }
    Wall := TWall.Create;
    Wall.Dimensions := Vector2Create(100, View.Height * 2);
    Wall.Position := Vector2Create(
      View.Width + (Wall.Dimensions.x / 2),
      View.Height / 2);
    Wall.Permanent := True;
    Wall.Visible := False;
    Objects.Add(Wall);

    { Top }
    Wall := TWall.Create;
    Wall.Dimensions := Vector2Create(View.Width * 2, 100);
    Wall.Position := Vector2Create(
      View.Width / 2,
      -Wall.Dimensions.y / 2);
    Wall.Permanent := True;
    Wall.Visible := False;
    Objects.Add(Wall);

    BallDestroyer := TBallDestroyer.Create;
    BallDestroyer.Exists := True;
    BallDestroyer.Dimensions := Vector2Create(10000, 10000);
    BallDestroyer.Position := Vector2Create(
      View.Width / 2,
      (View.Height * 1.1) + (BallDestroyer.Dimensions.y / 2));
    Objects.Add(BallDestroyer);
  end;
begin
  Objects := TGameObjectList.Create(True);
  Init;
end;

destructor TGameState.Destroy;
begin
  inherited Destroy;
  FreeAndNil(Objects);
end;

generic function TGameState.FindObject<T>: T;
var
  Obj: TGameObject;
begin
  Result := Nil;
  for Obj in Objects do
    if (Obj is T) and Obj.Exists then
    begin
      Result := (Obj as T);
      Break;
    end;
end;

generic function TGameState.FindObjects<T>: specialize TArray<T>;
var
  Obj: TGameObject;
begin
  Result := [];
  for Obj in Objects do
    if (Obj is T) and Obj.Exists then
      Insert(Obj as T, Result, 1000);
end;

function TGameState.SpawnBall(APaddle: TPaddle): TBall;
begin
  Assert(Assigned(APaddle));
  Result := TBall.Create;
  Result.Color := ColorAlpha(WHITE, 0.9);
  Result.Radius := 12;

  Result.Position := APaddle.Position
    + Vector2Create(APaddle.Dimensions.x * ((Random * 0.32) - 0.16), 0);

  Result.DefaultSpeed := Result.BaseSpeed
    + (Level - 1) * Result.PerLevelSpeedIncrement;

  Result.Velocity := Vector2Create(0, -1);
  Result.BounceOff(APaddle);
  Result.ResetSpeed;
  Result.JoinWith(APaddle);

  Objects.Add(Result);
end;

function TGameState.SpawnPaddle: TPaddle;
begin
  Result := TPaddle.Create(144, 28);
  Result.MaxSpeed := 1080;
  Result.Color := MAROON;
  Result.Position := Vector2Create(
    View.Width / 2,
    View.Height - Result.Dimensions.y - 32);
  Objects.Add(Result);
end;

procedure TGameState.SpawnBricks;
const
  BrickWidth = 64;
  BrickHeight = 32;

  function GetBrickColor(const AX, AY, ALevel: Integer): TColor;
  var
    Colors: array of TColor;
  begin
    Colors := [MAROON, ColorBrightness(GREEN, -0.1), BLUE, ORANGE];
    case ALevel mod 3 of
      1: Result := Colors[AY mod Length(Colors)];
      2: Result := Colors[AX mod Length(Colors)];
      else
        Result := Colors[(AX + AY) mod Length(Colors)];
    end;
  end;

  function GetBrickPosition(const AX, AY, ALevel: Integer): TVector2;
  begin
    Result.x := (AX + 0.5) * BrickWidth;
    case ALevel mod 4 of
      1: Result.y := (AY + 1) * BrickHeight;
      2: Result.y := (Cos(AX) * 2/3 + 1 + AY) * BrickHeight;
      3: Result.y := (Cos(AX/3) * 2 + 2 + AY) * BrickHeight;
      else
        Result.y := (Sin(AX/3) * 3 + 2 + AY) * BrickHeight;
    end;
  end;

var
  X, Y: Integer;
  Brick: TBrick;
  Color: TColor;
  OneUpAllowed: Boolean = True;
begin
  for Y := 2 to 9 do
    for X := 1 to (Trunc(View.Width) div BrickWidth) - 2 do
    begin
      Color := GetBrickColor(X, Y, Level);
      if Color.a = 0 then Continue;

      Brick := TBrick.Create;
      Brick.Color := Color;
      Brick.Score := ((9 - Y) div 2) + 1;
      Brick.Position := GetBrickPosition(X, Y, Level);
      Brick.Dimensions := Vector2Create(BrickWidth, BrickHeight);
      Brick.Velocity := Vector2Zero;

      if Random <= BonusChances then
      begin
        Brick.Bonus := TBonus.Create;
        repeat
          Brick.Bonus.Randomize;
        until (Brick.Bonus.BonusType <> OneUp) or OneUpAllowed;
        OneUpAllowed := OneUpAllowed and (Brick.Bonus.BonusType <> OneUp);
        Brick.Bonus.Dimensions := Brick.Dimensions;
      end;

      Objects.Add(Brick);
    end;
end;

end.

