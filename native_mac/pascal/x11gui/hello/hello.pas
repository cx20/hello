program hello;

uses ctypes;

const
    libX11 = 'X11';  // XQuartz: /opt/X11/lib/libX11.dylib

    None_     = 0;
    PPosition = $0004;
    PSize     = $0008;
    ButtonPressMask = 1 shl 2;
    KeyPressMask    = 1 shl 0;
    ExposureMask    = 1 shl 15;
    Expose          = 12;
    ClientMessage   = 33;
    DestroyNotify   = 17;

type
    TDisplay    = Pointer;
    TWindow     = culong;
    TGC         = Pointer;
    TAtom       = culong;
    TVisual     = Pointer;
    TColormap   = culong;

    TXSizeHints = record
        flags  : clong;
        x, y   : cint;
        width  : cint;
        height : cint;
        min_width, min_height   : cint;
        max_width, max_height   : cint;
        width_inc, height_inc   : cint;
        min_aspect_x, min_aspect_y : cint;
        max_aspect_x, max_aspect_y : cint;
        base_width, base_height : cint;
        win_gravity             : cint;
    end;

    TXClientMessageData = record
        case Integer of
            0: (b: array[0..19] of AnsiChar);
            1: (s: array[0.. 9] of cshort);
            2: (l: array[0.. 4] of clong);
    end;

    TXEvent = record
        _type   : cint;
        pad     : array[0..191] of Byte;
    end;

    TXClientMessageEvent = record
        _type        : cint;
        serial       : culong;
        send_event   : cint;
        display      : TDisplay;
        window       : TWindow;
        message_type : TAtom;
        format       : cint;
        data         : TXClientMessageData;
    end;

function XOpenDisplay(display_name: PAnsiChar): TDisplay; cdecl; external libX11;
function XDefaultScreen(display: TDisplay): cint; cdecl; external libX11;
function XBlackPixel(display: TDisplay; screen_number: cint): culong; cdecl; external libX11;
function XWhitePixel(display: TDisplay; screen_number: cint): culong; cdecl; external libX11;
function XDefaultRootWindow(display: TDisplay): TWindow; cdecl; external libX11;
function XCreateSimpleWindow(display: TDisplay; parent: TWindow; x, y: cint; width, height, border_width: cuint; border, background: culong): TWindow; cdecl; external libX11;
procedure XSetStandardProperties(display: TDisplay; w: TWindow; window_name, icon_name: PAnsiChar; icon_pixmap: culong; argv: PPAnsiChar; argc: cint; hints: Pointer); cdecl; external libX11;
function XInternAtom(display: TDisplay; atom_name: PAnsiChar; only_if_exists: cint): TAtom; cdecl; external libX11;
function XSetWMProtocols(display: TDisplay; w: TWindow; protocols: Pointer; count: cint): cint; cdecl; external libX11;
function XCreateGC(display: TDisplay; d: TWindow; valuemask: culong; values: Pointer): TGC; cdecl; external libX11;
procedure XSetBackground(display: TDisplay; gc: TGC; background: culong); cdecl; external libX11;
procedure XSetForeground(display: TDisplay; gc: TGC; foreground: culong); cdecl; external libX11;
procedure XSelectInput(display: TDisplay; w: TWindow; event_mask: clong); cdecl; external libX11;
procedure XMapRaised(display: TDisplay; w: TWindow); cdecl; external libX11;
procedure XNextEvent(display: TDisplay; event_return: Pointer); cdecl; external libX11;
procedure XDrawImageString(display: TDisplay; d: TWindow; gc: TGC; x, y: cint; string_: PAnsiChar; length: cint); cdecl; external libX11;
procedure XFreeGC(display: TDisplay; gc: TGC); cdecl; external libX11;
procedure XDestroyWindow(display: TDisplay; w: TWindow); cdecl; external libX11;
procedure XCloseDisplay(display: TDisplay); cdecl; external libX11;

var
    display    : TDisplay;
    window     : TWindow;
    gc         : TGC;
    ev         : TXEvent;
    hint       : TXSizeHints;
    screen     : cint;
    foreground : culong;
    background : culong;
    done       : Boolean;
    atomWmDeleteWindow : TAtom;
    helloTitle   : PAnsiChar;
    helloMessage : PAnsiChar;
    clientEv   : TXClientMessageEvent absolute ev;

begin
    helloTitle   := 'Hello, World!';
    helloMessage := 'Hello, X11 GUI(Pascal) World!';

    display := XOpenDisplay('');
    if display = nil then begin
        WriteLn(StdErr, 'Failed to open X display. Start XQuartz and set DISPLAY.');
        Halt(1);
    end;
    screen  := XDefaultScreen(display);

    foreground := XBlackPixel(display, screen);
    background := XWhitePixel(display, screen);

    hint.flags  := PPosition or PSize;
    hint.x      := 0;
    hint.y      := 0;
    hint.width  := 640;
    hint.height := 480;

    window := XCreateSimpleWindow(
        display,
        XDefaultRootWindow(display),
        hint.x, hint.y,
        hint.width, hint.height,
        5,
        foreground,
        background);

    XSetStandardProperties(display, window, helloTitle, helloTitle, None_, nil, 0, @hint);

    atomWmDeleteWindow := XInternAtom(display, 'WM_DELETE_WINDOW', 0);
    XSetWMProtocols(display, window, @atomWmDeleteWindow, 1);

    gc := XCreateGC(display, window, 0, nil);
    XSetBackground(display, gc, background);
    XSetForeground(display, gc, foreground);

    XSelectInput(display, window, ButtonPressMask or KeyPressMask or ExposureMask);
    XMapRaised(display, window);

    done := False;
    while not done do begin
        XNextEvent(display, @ev);
        if ev._type = Expose then
            XDrawImageString(display, window, gc, 5, 20, helloMessage, Length(helloMessage));
        if ev._type = ClientMessage then begin
            if clientEv.data.l[0] = clong(atomWmDeleteWindow) then
                done := True;
        end else if ev._type = DestroyNotify then
            done := True;
    end;

    XFreeGC(display, gc);
    XDestroyWindow(display, window);
    XCloseDisplay(display);
end.
