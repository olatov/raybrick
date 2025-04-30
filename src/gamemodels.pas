unit GameModels;

{$mode ObjFPC}{$H+}

interface

uses
  Generics.Collections,
  RayLib;

type
  TGameObject = class;
  TPaddle = class;
  TBall = class;
  TBrick = class;
  TBonus = class;
  TBullet = class;
  TWall = class;
  TBallJoint = class;

  TPowerUp = class;
  TGun = class;
  TCatch = class;

  TGameObjectList = specialize TObjectList<TGameObject>;
  TPowerUpList = specialize TObjectList<TPowerUp>;
  TGunGulp = array[1..2] of TBullet;

  { TGameObject }

  TGameObject = class
  private
    function GetColor: TColor; virtual;
    procedure SetColor(AValue: TColor);
  protected
    FDimensions: TVector2;
    FVelocity: TVector2;
    FColor: TColor;
    function GetDimensions: TVector2; virtual;
    procedure SetDimensions(AValue: TVector2); virtual;
    procedure SetVelocity(AValue: TVector2); virtual;
    function GetRectangle: TRectangle; virtual;
  public
    Exists: Boolean;
    Position: TVector2;
    property Color: TColor read GetColor write SetColor;
    property Dimensions: TVector2 read GetDimensions write SetDimensions;
    property Velocity: TVector2 read FVelocity write SetVelocity;
    constructor Create; virtual;
    procedure Update(const ADT: Single); virtual;
    procedure Remove;
    property Rectangle: TRectangle read GetRectangle;
    function CollidesWith(const AOther: TGameObject): Boolean; virtual;
  end;

  { TActiveGameObject }

  TActiveGameObject = class(TGameObject)
  public
    PowerUps: TPowerUpList;
    constructor Create; override;
    destructor Destroy; override;
    generic function FindPowerUp<T: TPowerUp>: T;
    procedure Update(const ADT: Single); override;
  end;

  { TBall }

  TBall = class(TActiveGameObject)
  private
    FPowerUps: TPowerUpList;
    function GetEffectiveRadius: Single;
    function GetCaught: Boolean;
    function GetSlow: Boolean;
  protected
    procedure SetVelocity(AValue: TVector2); override;
    function GetRectangle: TRectangle; override;
  public
  const
    BaseSpeed = 320;
    PerLevelSpeedIncrement = 40;
  var
    Radius: Single;
    Joint: TBallJoint;
    DefaultSpeed: Single;
    property EffectiveRadius: Single read GetEffectiveRadius;
    property Slow: Boolean read GetSlow;
    property Caught: Boolean read GetCaught;
    destructor Destroy; override;
    procedure JoinWith(APaddle: TPaddle);
    procedure Launch;
    procedure Update(const ADT: Single); override;
    function Clone: TBall;
    function CollidesWith(const AOther: TGameObject): Boolean; override;
    procedure BounceOff(const AOther: TGameObject);
    procedure SetSpeed(const ASpeed: Single);
    procedure ResetSpeed;
  end;

  { TBonus }

  TBonus = class(TGameObject)
  private
    type
      TBounusType = (
        Score25, Score50, Score100, SlowBall, BigBall, BottomWall,
        LongPaddle, QuickPaddle, Gun, ExtraBalls, Catch, OneUp);
  private
    function GetColor: TColor; override;
  public
    BonusType: TBounusType;
    procedure Randomize;
    procedure Update(const ADT: Single); override;
  end;

  { TBrick }

  TBrick = class(TGameObject)
    Score: Integer;
    Hits: Integer;
    Bonus: TBonus;
    Texture: TTexture2D;
    constructor Create; override;
    destructor Destroy; override;
  end;

  { TWall }

  TWall = class(TGameObject)
    Permanent: Boolean;
    Visible: Boolean;
    LifetimeTimer: Single;
    BaseWidth: Single;
    procedure Update(const ADT: Single); override;
  end;

  TBallDestroyer = class(TGameObject);

  { TPaddle }

  TPaddle = class(TActiveGameObject)
  private
    function GetGun: TGun;
    function GetHasCatch: Boolean;
  protected
    function GetDimensions: TVector2; override;
  public
    MaxSpeed: Single;
    property HasCatch: Boolean read GetHasCatch;
    property Gun: TGun read GetGun;
    constructor Create(AWidth, AHeight: Single); reintroduce;
    procedure Stop;
    procedure Move(const ADirection: TVector2);
    procedure Update(const ADT: Single); override;
  end;

  { TBullet }

  TBullet = class(TGameObject)
    const DefaultSpeed = 640;
    procedure Update(const ADT: Single); override;
  end;

  { TPowerUp }

  TPowerUp = class abstract
  protected
    function GetExists: Boolean;
  public
    LifetimeTimer: Single;
    property Exists: Boolean read GetExists;
    constructor Create(const ALifetime: Single); virtual;
    procedure Update(const ADT: Single); virtual;
  end;

  { TGun }

  TGun = class(TPowerUp)
  private
    function GetReady: Boolean;
  public
    ReloadTimer: Single;
    ReloadInterval: Single;
    property Ready: Boolean read GetReady;
    constructor Create(
      const ALifetime: Single; const AReloadInterval: Single); reintroduce;
    procedure Update(const ADT: Single); override;
    function Shoot: TGunGulp;
  end;

  TCatch = class(TPowerUp);
  TBigBall = class(TPowerUp);
  TSlowBall = class(TPowerUp);
  TLargePaddle = class(TPowerUp);
  TQuickPaddle = class(TPowerUp);
  TBottomWall = class(TPowerUp);

  TBallJoint = class
    Paddle: TPaddle;
    Offset: TVector2;
  end;

var
  View: TRectangle = (X: 0; Y: 0; Width: 1280; Height: 720);

implementation

uses
  SysUtils, Math,
  RayMath,
  GameMath;

{ TBonus }

function TBonus.GetColor: TColor;
begin
  case BonusType of
    Score25: Result := ColorBrightness(RED, +0.2);
    Score50: Result := ColorBrightness(GREEN, +0.2);
    Score100: Result := ColorBrightness(BLUE, +0.2);
    OneUp: Result := RED;
    else
      Result := VIOLET;
  end;

  Result := ColorAlpha(Result, 0.85);
end;

procedure TBonus.Randomize;
begin
  case GetRandomValue(1, 67) of
    1..21: BonusType := Score25;
    22..35: BonusType := Score50;
    36..45: BonusType := Score100;
    46..48: BonusType := SlowBall;
    49..52: BonusType := LongPaddle;
    53..56: BonusType := Catch;
    57..58: BonusType := Gun;
    59..60: BonusType := BigBall;
    61..62: BonusType := ExtraBalls;
    63..64: BonusType := QuickPaddle;
    65..66: BonusType := BottomWall;
    67: BonusType := OneUp;
  end;

  Velocity := Vector2Create(0, GetRandomValue(120, 320));
end;

procedure TBonus.Update(const ADT: Single);
begin
  inherited Update(ADT);
  if Position.y > View.Height then
    Remove;
end;

{ TBrick }

constructor TBrick.Create;
begin
  inherited Create;
  Hits := 1;
end;

destructor TBrick.Destroy;
begin
  inherited Destroy;
  FreeAndNil(Bonus);
end;

{ TWall }

procedure TWall.Update(const ADT: Single);
begin
  inherited Update(ADT);
  if Permanent then Exit;

  LifetimeTimer := Max(LifetimeTimer - ADT, 0);

  if (BaseWidth > 0) and (Dimensions.x < BaseWidth) then
    Dimensions := Dimensions + Vector2Create(BaseWidth * ADT * 1.5, 0);

  if (LifetimeTimer < 10) and (BaseWidth > 0) then
    Dimensions := Vector2Create(BaseWidth * (LifetimeTimer / 10), Dimensions.y);

  if IsZero(LifetimeTimer) then Remove;
end;

{ TPaddle }

function TPaddle.GetGun: TGun;
begin
  Result := specialize FindPowerUp<TGun>;
end;

function TPaddle.GetHasCatch: Boolean;
begin
  Result := Assigned(specialize FindPowerUp<TCatch>);
end;

function TPaddle.GetDimensions: TVector2;
begin
  Result := inherited GetDimensions;
  if Assigned(specialize FindPowerUp<TLargePaddle>) then
    Result *= Vector2Create(1.5, 1);
end;

constructor TPaddle.Create(AWidth, AHeight: Single);
begin
  inherited Create;
  Dimensions := Vector2Create(AWidth, AHeight);
end;

procedure TPaddle.Stop;
begin
  Velocity := Vector2Zero;
end;

procedure TPaddle.Move(const ADirection: TVector2);
begin
  Velocity := Vector2Scale(ADirection, MaxSpeed);
  if Assigned(specialize FindPowerUp<TQuickPaddle>) then
    Velocity := Vector2Scale(Velocity, 1.7);
end;

procedure TPaddle.Update(const ADT: Single);
begin
  inherited Update(ADT);

  Position.x := EnsureRange(
    Position.x,
      Dimensions.x / 2,
      View.Width - (Dimensions.x / 2));
end;

{ TBullet }

procedure TBullet.Update(const ADT: Single);
begin
  inherited Update(ADT);

  if (Position.y + Dimensions.y) <= 0 then
    Exists := False;
end;

{ TPowerUp }

function TPowerUp.GetExists: Boolean;
begin
  Result := (LifetimeTimer > 0);
end;

constructor TPowerUp.Create(const ALifetime: Single);
begin
  LifetimeTimer := ALifetime;
end;

procedure TPowerUp.Update(const ADT: Single);
begin
  LifetimeTimer := Max(0, LifetimeTimer - ADT);
end;

{ TGun }

function TGun.GetReady: Boolean;
begin
  Result := Exists and IsZero(ReloadTimer);
end;

constructor TGun.Create(const ALifetime: Single; const AReloadInterval: Single);
begin
  inherited Create(ALifetime);
  ReloadInterval := AReloadInterval;
end;

procedure TGun.Update(const ADT: Single);
begin
  inherited Update(ADT);
  ReloadTimer := Max(0, ReloadTimer - ADT);
end;

function TGun.Shoot: TGunGulp;
var
  Bullet: TBullet;
  I: Integer;
begin
  if not Ready then Exit;

  for I := 1 to 2 do
  begin
    Bullet := TBullet.Create;
    Bullet.Velocity := Vector2Create(0, -Bullet.DefaultSpeed);
    Bullet.Dimensions := Vector2Create(8, 12);
    Bullet.Color := ColorAlpha(MAGENTA, 0.7);
    Result[I] := Bullet;
  end;

  ReloadTimer := ReloadInterval;
end;

{ TGameObject }

function TGameObject.GetColor: TColor;
begin
  Result := FColor;
end;

procedure TGameObject.SetColor(AValue: TColor);
begin
  FColor := AValue;
end;

function TGameObject.GetDimensions: TVector2;
begin
  Result := FDimensions;
end;

procedure TGameObject.SetDimensions(AValue: TVector2);
begin
  FDimensions := AValue;
end;

procedure TGameObject.SetVelocity(AValue: TVector2);
begin
  FVelocity := AValue;
end;

function TGameObject.GetRectangle: TRectangle;
begin
  Result := RectangleCreate(
    Position.x - (Dimensions.x / 2),
    Position.y - (Dimensions.y / 2),
    Dimensions.x,
    Dimensions.y);
end;

constructor TGameObject.Create;
begin
  Exists := True;
end;

procedure TGameObject.Update(const ADT: Single);
begin
  Position += Vector2Scale(Velocity, ADT);
end;

procedure TGameObject.Remove;
begin
  Exists := False;
end;

function TGameObject.CollidesWith(const AOther: TGameObject): Boolean;
var
  Ball: TBall;
begin
  if not AOther.Exists then Exit(False);

  if AOther is TBall then
  begin
    Ball := (AOther as TBall);
    Result := CheckCollisionCircleRec(
      Ball.Position, Ball.EffectiveRadius, Rectangle);
    Exit;
  end;

  Result := CheckCollisionRecs(AOther.Rectangle, Rectangle);
end;

{ TActiveGameObject }

constructor TActiveGameObject.Create;
begin
  inherited Create;
  PowerUps := TPowerUpList.Create(True);
end;

destructor TActiveGameObject.Destroy;
begin
  inherited Destroy;
  FreeAndNil(PowerUps);
end;

generic function TActiveGameObject.FindPowerUp<T>: T;
var
  Item: TPowerUp;
begin
  Result := Nil;
  for Item in PowerUps do
    if (Item is T) and Item.Exists then
    begin
      Result := (Item as T);
      Break;
    end;
end;

procedure TActiveGameObject.Update(const ADT: Single);
var
  PowerUp: TPowerUp;
begin
  inherited Update(ADT);

  for PowerUp in PowerUps do
  begin
    PowerUp.Update(ADT);
    if not PowerUp.Exists then PowerUps.Remove(PowerUp);
  end;
end;

{ TBall }

function TBall.GetEffectiveRadius: Single;
begin
  Result := Radius;
  if Assigned(specialize FindPowerUp<TBigBall>) then
    Result *= 2;
end;

function TBall.GetCaught: Boolean;
begin
  Result := Assigned(Joint);
end;

function TBall.GetSlow: Boolean;
var
  PowerUp: TPowerUp;
begin
  Result := Assigned(specialize FindPowerUp<TSlowBall>);
end;

procedure TBall.SetVelocity(AValue: TVector2);
  function GetAngle: Single;
  begin
    Result := Abs(FMod(Vector2Angle(FVelocity, Vector2Create(1, 0)), Pi));
  end;

var
  I: Integer = 0;
  Angle: Single;
  Rotation: Single;

begin
  inherited SetVelocity(AValue);

  { Prevent the ball from going horizontally and vertically }
  Rotation := IfThen(FVelocity.X > 0, -1, 1) * DEG2RAD;
  while not (InRange(GetAngle, 20 * DEG2RAD, 80 * DEG2RAD)
    or InRange(GetAngle, 100 * DEG2RAD, 160 * DEG2RAD)) do
  begin
    Assert(I < 360);
    FVelocity := Vector2Rotate(FVelocity, Rotation);
  end;
end;

function TBall.GetRectangle: TRectangle;
begin
  Result := RectangleCreate(
    Position.x - EffectiveRadius, Position.y - EffectiveRadius,
    EffectiveRadius * 2, EffectiveRadius * 2);
end;

destructor TBall.Destroy;
begin
  inherited Destroy;
  FreeAndNil(Joint);
end;

procedure TBall.JoinWith(APaddle: TPaddle);
begin
  FreeAndNil(Joint);

  Position.Y := APaddle.Position.Y
    - (APaddle.Dimensions.Y / 2)
    - EffectiveRadius;
  Joint := TBallJoint.Create;
  Joint.Paddle := APaddle;
  Joint.Offset := Position - APaddle.Position;
end;

procedure TBall.Launch;
begin
  if not Caught then Exit;
  Velocity := Velocity + Vector2Scale(Joint.Paddle.Velocity, 0.4);
  FreeAndNil(Joint);
end;

procedure TBall.Update(const ADT: Single);
begin
  inherited Update(ADT);

  if Caught then
  begin
    Position := Joint.Paddle.Position + Joint.Offset;
    Exit;
  end;

  if Slow then
    Position -= Vector2Scale(Velocity, 1/3 * ADT);
end;

function TBall.Clone: TBall;
begin
  Result := TBall.Create;
  Result.Exists := Exists;
  Result.Color := Color;
  Result.Radius := Radius;
  Result.Position := Position;
  Result.Velocity := Velocity;
  Result.DefaultSpeed := DefaultSpeed;
end;

function TBall.CollidesWith(const AOther: TGameObject): Boolean;
var
  Ball: TBall;
begin
  if not AOther.Exists then Exit(False);

  if AOther is TBall then
  begin
    Ball := (AOther as TBall);
    Result := CheckCollisionCircles(
      Ball.Position, Ball.EffectiveRadius, Position, EffectiveRadius);
    Exit;
  end;

  Result := CheckCollisionCircleRec(
    Position, EffectiveRadius, AOther.Rectangle);
end;

procedure TBall.BounceOff(const AOther: TGameObject);
var
  Paddle: TPaddle;
  Normal: TVector2;
  Offset: TVector2;
  CollisionRect: TRectangle;
  R1, R2: TRectangle;
begin
  if AOther is TPaddle then
  begin
    Paddle := AOther as TPaddle;
    Normal := Vector2Create(0, -1);
    Velocity := Vector2Rotate(
      Vector2Scale(Normal, Vector2Length(Velocity)),
      ((Position.x - Paddle.Position.x) / Paddle.Dimensions.x * 120) * DEG2RAD);
    Velocity := Velocity + Vector2Scale(Paddle.Velocity, 0.05);
    Exit;
  end;

  R1 := Rectangle;
  R2 := AOther.Rectangle;
  CollisionRect := GetCollisionRec(Rectangle, AOther.Rectangle);

  Normal := Vector2Zero;
  if CollisionRect.width > CollisionRect.height then
    Normal += Vector2Create(0, 1)
  else
    Normal += Vector2Create(1, 0);

  Offset := Vector2Scale(
    Vector2Normalize(Velocity),
    Min(CollisionRect.width, CollisionRect.height));
  Position -= Offset;

  Velocity := Vector2Reflect(Velocity, Normal);
end;

procedure TBall.SetSpeed(const ASpeed: Single);
begin
  Velocity := Vector2Scale(Vector2Normalize(Velocity), ASpeed);
end;

procedure TBall.ResetSpeed;
begin
  SetSpeed(DefaultSpeed);
end;

end.

