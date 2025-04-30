unit GameMath;

{$mode ObjFPC}

interface

uses
  RayLib;

operator + (const AFirst, ASecond: TVector2): TVector2; overload; inline;
operator - (const AFirst, ASecond: TVector2): TVector2; overload; inline;
operator * (const AFirst, ASecond: TVector2): TVector2; overload; inline;
operator / (const AFirst, ASecond: TVector2): TVector2; overload; inline;

{ Temporary declaration because of mistake in RayMath unit }
function Vector2ClampValue(v: TVector2; min, max: Single): TVector2; cdecl; external name 'Vector2ClampValue';

implementation

uses
  RayMath;

operator + (const AFirst, ASecond: TVector2): TVector2;
begin
  Result := Vector2Add(AFirst, ASecond);
end;

operator - (const AFirst, ASecond: TVector2): TVector2;
begin
  Result := Vector2Subtract(AFirst, ASecond);
end;

operator * (const AFirst, ASecond: TVector2): TVector2;
begin
  Result := Vector2Multiply(AFirst, ASecond);
end;

operator / (const AFirst, ASecond: TVector2): TVector2;
begin
  Result := Vector2Divide(AFirst, ASecond);
end;

end.

