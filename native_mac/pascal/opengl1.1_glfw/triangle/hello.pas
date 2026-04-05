program hello;

uses Math;

{$L hello_glfw.o}

procedure runSample; cdecl; external;

begin
    SetExceptionMask([exInvalidOp, exDenormalized, exZeroDivide, exOverflow, exUnderflow, exPrecision]);
    runSample();
end.
