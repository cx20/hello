program hello;

uses Math;

{$L hello_opengl.o}

procedure runOpenGLSample; cdecl; external;

begin
    SetExceptionMask([exInvalidOp, exDenormalized, exZeroDivide, exOverflow, exUnderflow, exPrecision]);
    runOpenGLSample();
end.
