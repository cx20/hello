program hello;

uses ctypes, Math;

const
    libX11  = 'libX11.so.6';
    libGL   = 'libGL.so.1';

    { X11 }
    None_            = 0;
    InputOutput      = 1;
    AllocNone        = 0;
    ExposureMask     = 1 shl 15;
    Expose           = 12;
    ClientMessage    = 33;
    DestroyNotify    = 17;
    CWBackPixel      = 1 shl 1;
    CWBorderPixel    = 1 shl 3;
    CWOverrideRedirect = 1 shl 9;
    CWEventMask      = 1 shl 11;
    CWColormap       = 1 shl 13;
    True_            = 1;

    { GLX }
    GLX_RGBA_BIT         = 1;
    GLX_WINDOW_BIT       = 1;
    GLX_DOUBLEBUFFER     = 5;
    GLX_RED_SIZE         = 8;
    GLX_GREEN_SIZE       = 9;
    GLX_BLUE_SIZE        = 10;
    GLX_ALPHA_SIZE       = 11;
    GLX_DEPTH_SIZE       = 12;
    GLX_STENCIL_SIZE     = 13;
    GLX_X_VISUAL_TYPE    = $22;
    GLX_TRUE_COLOR       = $8002;
    GLX_X_RENDERABLE     = $8010;
    GLX_DRAWABLE_TYPE    = $8011;
    GLX_RENDER_TYPE      = $8012;
    GLX_RGBA_TYPE        = $8014;
    GLX_SAMPLE_BUFFERS   = $186AA;
    GLX_SAMPLES          = $186AB;

    { OpenGL }
    GL_COLOR_BUFFER_BIT  = $00004000;
    GL_TRIANGLES         = $0004;
    GL_TRIANGLE_STRIP    = $0005;
    GL_FLOAT             = $1406;
    GL_VERTEX_ARRAY      = $8074;
    GL_COLOR_ARRAY       = $8076;

type
    GLenum     = Cardinal;      PGLenum     = ^GLenum;
    GLboolean  = Byte;          PGLboolean  = ^GLboolean;
    GLbitfield = Cardinal;      PGLbitfield = ^GLbitfield;
    GLint      = LongInt;       PGLint      = ^GLint;
    GLsizei    = LongInt;       PGLsizei    = ^GLsizei;
    GLuint     = Cardinal;      PGLuint     = ^GLuint;
    GLfloat    = Single;        PGLfloat    = ^GLfloat;
    GLclampf   = Single;        PGLclampf   = ^GLclampf;

    TDisplay    = Pointer;
    TWindow     = culong;
    TAtom       = culong;
    TColormap   = culong;
    TGLXContext  = Pointer;
    TGLXFBConfig = Pointer;
    PGLXFBConfig = ^TGLXFBConfig;

    {$PACKRECORDS C}
    TXVisualInfo = record
        visual        : Pointer;
        visualid      : culong;
        screen        : cint;
        depth         : cint;
        class_        : cint;
        red_mask      : culong;
        green_mask    : culong;
        blue_mask     : culong;
        colormap_size : cint;
        bits_per_rgb  : cint;
    end;
    PXVisualInfo = ^TXVisualInfo;

    TXSetWindowAttributes = record
        background_pixmap     : culong;
        background_pixel      : culong;
        border_pixmap         : culong;
        border_pixel          : culong;
        bit_gravity           : cint;
        win_gravity           : cint;
        backing_store         : cint;
        backing_planes        : culong;
        backing_pixel         : culong;
        save_under            : cint;
        event_mask            : clong;
        do_not_propagate_mask : clong;
        override_redirect     : cint;
        colormap              : TColormap;
        cursor                : culong;
    end;
    {$PACKRECORDS DEFAULT}

    TXClientMessageData = record
        case Integer of
            0: (b: array[0..19] of AnsiChar);
            1: (s: array[0.. 9] of cshort);
            2: (l: array[0.. 4] of clong);
    end;

    TXEvent = record
        _type : cint;
        pad   : array[0..191] of Byte;
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

{ X11 }
function  XOpenDisplay(display_name: PAnsiChar): TDisplay; cdecl; external libX11;
procedure XCloseDisplay(display: TDisplay); cdecl; external libX11;
function  XDefaultScreen(display: TDisplay): cint; cdecl; external libX11;
function  XDefaultRootWindow(display: TDisplay): TWindow; cdecl; external libX11;
function  XBlackPixel(display: TDisplay; screen: cint): culong; cdecl; external libX11;
function  XWhitePixel(display: TDisplay; screen: cint): culong; cdecl; external libX11;
function  XCreateColormap(display: TDisplay; w: TWindow; visual: Pointer; alloc: cint): TColormap; cdecl; external libX11;
function  XCreateWindow(display: TDisplay; parent: TWindow; x, y: cint; width, height, border_width: cuint; depth: cint; class_: cuint; visual: Pointer; valuemask: culong; attributes: Pointer): TWindow; cdecl; external libX11;
procedure XSetStandardProperties(display: TDisplay; w: TWindow; window_name, icon_name: PAnsiChar; icon_pixmap: culong; argv: PPAnsiChar; argc: cint; hints: Pointer); cdecl; external libX11;
function  XInternAtom(display: TDisplay; atom_name: PAnsiChar; only_if_exists: cint): TAtom; cdecl; external libX11;
function  XSetWMProtocols(display: TDisplay; w: TWindow; protocols: Pointer; count: cint): cint; cdecl; external libX11;
procedure XClearWindow(display: TDisplay; w: TWindow); cdecl; external libX11;
procedure XMapRaised(display: TDisplay; w: TWindow); cdecl; external libX11;
function  XPending(display: TDisplay): cint; cdecl; external libX11;
procedure XNextEvent(display: TDisplay; event_return: Pointer); cdecl; external libX11;
procedure XFree(data: Pointer); cdecl; external libX11;
procedure XFreeColormap(display: TDisplay; colormap: TColormap); cdecl; external libX11;
procedure XDestroyWindow(display: TDisplay; w: TWindow); cdecl; external libX11;

{ GLX }
function  glXQueryVersion(display: TDisplay; major, minor: PGLint): cint; cdecl; external libGL;
function  glXChooseFBConfig(display: TDisplay; screen: cint; attrib_list: PGLint; nelements: PGLint): PGLXFBConfig; cdecl; external libGL;
function  glXGetFBConfigAttrib(display: TDisplay; config: TGLXFBConfig; attribute: cint; value: PGLint): cint; cdecl; external libGL;
function  glXGetVisualFromFBConfig(display: TDisplay; config: TGLXFBConfig): PXVisualInfo; cdecl; external libGL;
function  glXCreateNewContext(display: TDisplay; config: TGLXFBConfig; render_type: cint; share_list: TGLXContext; direct: cint): TGLXContext; cdecl; external libGL;
function  glXMakeCurrent(display: TDisplay; draw: TWindow; ctx: TGLXContext): cint; cdecl; external libGL;
procedure glXSwapBuffers(display: TDisplay; draw: TWindow); cdecl; external libGL;
procedure glXDestroyContext(display: TDisplay; ctx: TGLXContext); cdecl; external libGL;

{ OpenGL }
procedure glClearColor(red, green, blue, alpha: GLclampf); cdecl; external libGL;
procedure glClear(mask: GLbitfield); cdecl; external libGL;
procedure glViewport(x, y: GLint; width, height: GLsizei); cdecl; external libGL;
procedure glEnableClientState(arr: GLenum); cdecl; external libGL;
procedure glColorPointer(size: GLint; type_: GLenum; stride: GLsizei; pointer: Pointer); cdecl; external libGL;
procedure glVertexPointer(size: GLint; type_: GLenum; stride: GLsizei; pointer: Pointer); cdecl; external libGL;
procedure glDrawArrays(mode: GLenum; first: GLint; count: GLsizei); cdecl; external libGL;

var
    display           : TDisplay;
    window            : TWindow;
    screenId          : cint;
    ev                : TXEvent;
    windowAttribs     : TXSetWindowAttributes;
    visual            : PXVisualInfo;
    context           : TGLXContext;
    atomWmDeleteWindow: TAtom;
    fbc               : PGLXFBConfig;
    fbcount           : GLint;
    bestFbc           : TGLXFBConfig;
    best_fbc          : cint;
    best_num_samp     : cint;
    worst_fbc         : cint;
    worst_num_samp    : cint;
    samp_buf, samples : GLint;
    i                 : cint;
    vi                : PXVisualInfo;
    done              : Boolean;
    clientEv          : TXClientMessageEvent absolute ev;

    glxAttribs: array[0..23] of GLint;

    colors: array[0..8] of GLfloat = (
         1.0,  0.0,  0.0,
         0.0,  1.0,  0.0,
         0.0,  0.0,  1.0
    );
    vertices: array[0..5] of GLfloat = (
         0.0,  0.5,
         0.5, -0.5,
        -0.5, -0.5
    );

procedure DrawTriangle;
begin
    glEnableClientState(GL_COLOR_ARRAY);
    glEnableClientState(GL_VERTEX_ARRAY);
    glColorPointer(3, GL_FLOAT, 0, @colors[0]);
    glVertexPointer(2, GL_FLOAT, 0, @vertices[0]);
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 3);
end;

begin
    SetExceptionMask(GetExceptionMask + [exInvalidOp, exZeroDivide, exOverflow, exUnderflow, exPrecision]);
    display  := XOpenDisplay('');
    screenId := XDefaultScreen(display);

    glxAttribs[ 0] := GLX_X_RENDERABLE;    glxAttribs[ 1] := True_;
    glxAttribs[ 2] := GLX_DRAWABLE_TYPE;   glxAttribs[ 3] := GLX_WINDOW_BIT;
    glxAttribs[ 4] := GLX_RENDER_TYPE;     glxAttribs[ 5] := GLX_RGBA_BIT;
    glxAttribs[ 6] := GLX_X_VISUAL_TYPE;   glxAttribs[ 7] := GLX_TRUE_COLOR;
    glxAttribs[ 8] := GLX_RED_SIZE;        glxAttribs[ 9] := 8;
    glxAttribs[10] := GLX_GREEN_SIZE;      glxAttribs[11] := 8;
    glxAttribs[12] := GLX_BLUE_SIZE;       glxAttribs[13] := 8;
    glxAttribs[14] := GLX_ALPHA_SIZE;      glxAttribs[15] := 8;
    glxAttribs[16] := GLX_DEPTH_SIZE;      glxAttribs[17] := 24;
    glxAttribs[18] := GLX_STENCIL_SIZE;    glxAttribs[19] := 8;
    glxAttribs[20] := GLX_DOUBLEBUFFER;    glxAttribs[21] := True_;
    glxAttribs[22] := None_;               glxAttribs[23] := None_;

    fbc      := glXChooseFBConfig(display, screenId, @glxAttribs[0], @fbcount);
    best_fbc := -1;  best_num_samp := -1;
    worst_fbc := -1; worst_num_samp := 999;
    for i := 0 to fbcount - 1 do begin
        vi := glXGetVisualFromFBConfig(display, fbc[i]);
        if vi <> nil then begin
            glXGetFBConfigAttrib(display, fbc[i], GLX_SAMPLE_BUFFERS, @samp_buf);
            glXGetFBConfigAttrib(display, fbc[i], GLX_SAMPLES,        @samples);
            if (best_fbc < 0) or ((samp_buf <> 0) and (samples > best_num_samp)) then begin
                best_fbc      := i;
                best_num_samp := samples;
            end;
            if (worst_fbc < 0) or (samp_buf = 0) or (samples < worst_num_samp) then begin
                worst_fbc      := i;
                worst_num_samp := samples;
            end;
        end;
        XFree(vi);
    end;
    bestFbc := fbc[best_fbc];
    XFree(fbc);

    visual := glXGetVisualFromFBConfig(display, bestFbc);

    windowAttribs.border_pixel      := XBlackPixel(display, screenId);
    windowAttribs.background_pixel  := XWhitePixel(display, screenId);
    windowAttribs.override_redirect := True_;
    windowAttribs.colormap := XCreateColormap(display, XDefaultRootWindow(display), visual^.visual, AllocNone);
    windowAttribs.event_mask := ExposureMask;

    window := XCreateWindow(
        display, XDefaultRootWindow(display),
        0, 0, 640, 480, 0,
        visual^.depth, InputOutput, visual^.visual,
        CWBackPixel or CWColormap or CWBorderPixel or CWEventMask,
        @windowAttribs);

    XSetStandardProperties(display, window, 'Hello, Pascal World!', nil, None_, nil, 0, nil);

    atomWmDeleteWindow := XInternAtom(display, 'WM_DELETE_WINDOW', 0);
    XSetWMProtocols(display, window, @atomWmDeleteWindow, 1);

    context := glXCreateNewContext(display, bestFbc, GLX_RGBA_TYPE, nil, True_);
    glXMakeCurrent(display, window, context);

    glViewport(0, 0, 640, 480);

    XClearWindow(display, window);
    XMapRaised(display, window);

    done := False;
    while not done do begin
        while XPending(display) > 0 do begin
            XNextEvent(display, @ev);
            if ev._type = ClientMessage then begin
                if clientEv.data.l[0] = clong(atomWmDeleteWindow) then
                    done := True;
            end else if ev._type = DestroyNotify then
                done := True;
        end;

        glClearColor(0.0, 0.0, 0.0, 1.0);
        glClear(GL_COLOR_BUFFER_BIT);
        DrawTriangle;
        glXSwapBuffers(display, window);
    end;

    glXDestroyContext(display, context);
    XFree(visual);
    XFreeColormap(display, windowAttribs.colormap);
    XDestroyWindow(display, window);
    XCloseDisplay(display);
end.
