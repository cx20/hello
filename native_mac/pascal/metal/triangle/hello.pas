program hello;

{$mode delphi}

uses
  SysUtils;

type
  MetalContext = Pointer;

function metal_create(): MetalContext; cdecl; external;
procedure metal_render(ctx: MetalContext); cdecl; external;
function metal_is_running(ctx: MetalContext): Boolean; cdecl; external;
procedure metal_destroy(ctx: MetalContext); cdecl; external;

procedure libc_usleep(usec: LongWord); cdecl; external 'c' name 'usleep';

var
  ctx: MetalContext;
begin
  ctx := metal_create();
  if ctx = nil then begin
    WriteLn(ErrOutput, 'Failed to create Metal context');
    Halt(1);
  end;
  WriteLn('Metal triangle created. Close window to exit.');
  while metal_is_running(ctx) do begin
    metal_render(ctx);
    libc_usleep(16667);
  end;
  metal_destroy(ctx);
end.
