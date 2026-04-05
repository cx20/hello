program hello;

uses Math;

{$L hello_cocoa.o}

procedure createCocoaWindow; cdecl; external;

begin
    SetExceptionMask([exInvalidOp, exDenormalized, exZeroDivide, exOverflow, exUnderflow, exPrecision]);
    createCocoaWindow();
end.
