program hello;

uses
    Windows, Messages;

type
    GLenum     = Cardinal;      PGLenum     = ^GLenum;
    GLboolean  = Byte;          PGLboolean  = ^GLboolean;
    GLbitfield = Cardinal;      PGLbitfield = ^GLbitfield;
    GLbyte     = ShortInt;      PGLbyte     = ^GLbyte;
    GLshort    = SmallInt;      PGLshort    = ^GLshort;
    GLint      = Integer;       PGLint      = ^GLint;
    GLsizei    = Integer;       PGLsizei    = ^GLsizei;
    GLubyte    = Byte;          PGLubyte    = ^GLubyte;
    GLushort   = Word;          PGLushort   = ^GLushort;
    GLuint     = Cardinal;      PGLuint     = ^GLuint;
    GLfloat    = Single;        PGLfloat    = ^GLfloat;
    GLclampf   = Single;        PGLclampf   = ^GLclampf;
    GLdouble   = Double;        PGLdouble   = ^GLdouble;
    GLclampd   = Double;        PGLclampd   = ^GLclampd;
  { GLvoid     = void; }        PGLvoid     = Pointer;
                                PPGLvoid    = ^PGLvoid;

    TglClear              = procedure(mask: GLbitfield); stdcall;
    TglClearColor         = procedure(red, green, blue, alpha: GLclampf); stdcall;
    TglBegin              = procedure(mode: GLenum); stdcall;
    TglEnd                = procedure; stdcall;
    TglColor3f            = procedure(red, green, blue: GLfloat); stdcall;
    TglVertex2f           = procedure(x, y: GLfloat); stdcall;

    TglVertexPointer      = procedure  (size: GLint; atype: GLenum; stride: GLsizei; data: pointer); stdcall;
    TglColorPointer       = procedure (size: GLint; atype: GLenum; stride: GLsizei; data: pointer); stdcall;
    TglDrawArrays         = procedure (mode: GLenum; first: GLint; count: GLsizei); stdcall;
    TglEnableClientState  = procedure (aarray: GLenum); stdcall;
    TglDisableClientState = procedure (aarray: GLenum); stdcall;

var
    glClear              : TglClear;
    glClearColor         : TglClearColor;
    glBegin              : TglBegin;
    glEnd                : TglEnd;
    glColor3f            : TglColor3f;
    glVertex2f           : TglVertex2f;

    glVertexPointer      : TglVertexPointer;
    glColorPointer       : TglColorPointer;
    glDrawArrays         : TglDrawArrays;
    glEnableClientState  : TglEnableClientState;
    glDisableClientState : TglDisableClientState;

const
    PFD_TYPE_RGBA        = 0;
    PFD_MAIN_PLANE       = 0;
    
    PFD_DOUBLEBUFFER     = $00000001;
    PFD_DRAW_TO_WINDOW   = $00000004;
    PFD_SUPPORT_OPENGL   = $00000020;

    GL_COLOR_BUFFER_BIT  = $00004000;
    GL_TRIANGLES         = $0004;
    GL_TRIANGLE_STRIP    = $0005;

    GL_VERTEX_ARRAY      = $8074;
    GL_COLOR_ARRAY       = $8076;
    
    GL_FLOAT             = $1406;

function WindowProc(hWindow:HWnd; message:Cardinal; wParam:Word; lParam:Longint):LongWord; stdcall;
begin
    case message of
        WM_DESTROY:
            PostQuitMessage(0);
    else
        WindowProc := DefWindowProc(hWindow, message, wParam, lParam);
        exit;
    end;
    WindowProc := 0;
end;


function EnableOpenGL(hDC: THandle): HGLRC;
var
    hRC:     HGLRC;
    pfd:     PIXELFORMATDESCRIPTOR;
    iFormat: LongInt;
begin
    hRC := 0;
    ZeroMemory(@pfd, SizeOf(pfd));

    pfd.nSize      := SizeOf(pfd);
    pfd.nVersion   := 1;
    pfd.dwFlags    := PFD_DRAW_TO_WINDOW or PFD_SUPPORT_OPENGL or PFD_DOUBLEBUFFER;
    pfd.iPixelType := PFD_TYPE_RGBA;
    pfd.cColorBits := 24;
    pfd.cDepthBits := 16;
    pfd.iLayerType := PFD_MAIN_PLANE;

    iFormat := ChoosePixelFormat(hDC, @pfd);
    
    SetPixelFormat(hDC, iFormat, @pfd);

    hRC := wglCreateContext(hDC);
    wglMakeCurrent(hDC, hRC);

    EnableOpenGL := hRC;
end;

procedure DisableOpenGL(hWindow: HWnd; hDC: THandle; hRC: HGLRC);
begin
    wglMakeCurrent(0, 0);
    wglDeleteContext(hRC);
    ReleaseDC(hWindow, hDC);
end;

procedure DrawTriangle();
var
    colors:   array [0..8] of GLfloat;
    vertices: array [0..5] of GLfloat;
begin
    glEnableClientState(GL_COLOR_ARRAY);
    glEnableClientState(GL_VERTEX_ARRAY);

    colors[0] := 1.0;
    colors[1] := 0.0;
    colors[2] := 0.0;
    colors[3] := 0.0;
    colors[4] := 1.0;
    colors[5] := 0.0;
    colors[6] := 0.0;
    colors[7] := 0.0;
    colors[8] := 1.0;
    
    vertices[0] :=  0.0;
    vertices[1] :=  0.5;
    vertices[2] :=  0.5;
    vertices[3] := -0.5;
    vertices[4] := -0.5;
    vertices[5] := -0.5;
    
    glColorPointer(3,  GL_FLOAT, 0, @colors);
    glVertexPointer(2, GL_FLOAT, 0, @vertices);

    glDrawArrays(GL_TRIANGLE_STRIP, 0, 3);
end;

function WinMain(hInstance, hPrevInstance:THandle; lpCmdLine:PAnsiChar; nCmdShow:Integer):Integer; stdcall;
var
    wcex:       TWndClassEx;
    hWindow:    HWnd;
    msg:        TMsg;
    hDC:        THandle;
    hRC:        HGLRC;
    LibHandle:  THandle;
    bQuit:      boolean;
const
    ClassName = 'helloWindow';
    WindowName = 'Hello, World!';

begin
    LibHandle := LoadLibrary(PChar('opengl32.dll'));
    Pointer(glClear)              := GetProcAddress(LibHandle, 'glClear');
    Pointer(glClearColor)         := GetProcAddress(LibHandle, 'glClearColor');
    Pointer(glBegin)              := GetProcAddress(LibHandle, 'glBegin');
    Pointer(glEnd)                := GetProcAddress(LibHandle, 'glEnd');
    Pointer(glColor3f)            := GetProcAddress(LibHandle, 'glColor3f');
    Pointer(glVertex2f)           := GetProcAddress(LibHandle, 'glVertex2f');

    Pointer(glVertexPointer)      := GetProcAddress(LibHandle, 'glVertexPointer');
    Pointer(glColorPointer)       := GetProcAddress(LibHandle, 'glColorPointer');
    Pointer(glDrawArrays)         := GetProcAddress(LibHandle, 'glDrawArrays');
    Pointer(glEnableClientState)  := GetProcAddress(LibHandle, 'glEnableClientState');
    Pointer(glDisableClientState) := GetProcAddress(LibHandle, 'glDisableClientState');
    
    wcex.cbSize         := SizeOf(TWndclassEx);
    wcex.style          := CS_HREDRAW or CS_VREDRAW;
    wcex.lpfnWndProc    := WndProc(@WindowProc);
    wcex.cbClsExtra     := 0;
    wcex.cbWndExtra     := 0;
    wcex.hInstance      := hInstance;
    wcex.hIcon          := LoadIcon(0, IDI_APPLICATION);
    wcex.hCursor        := LoadCursor(0, IDC_ARROW);
    wcex.hbrBackground  := COLOR_WINDOW +1;
    wcex.lpszMenuName   := nil;
    wcex.lpszClassName  := ClassName;

    RegisterClassEx(wcex);
    hWindow := CreateWindowEX(
        0,
        ClassName,
        WindowName,
        WS_OVERLAPPEDWINDOW,
        CW_USEDEFAULT, CW_USEDEFAULT, 640, 480,
        0, 0, hInstance, nil
    );

    ShowWindow(hWindow, nCmdShow);

    hDC := GetDC(hWindow);
    hRC := EnableOpenGL(hDC);

    UpdateWindow(hWindow);

    bQuit := false;

    while not bQuit do begin
        if PeekMessage(msg, 0, 0, 0, PM_REMOVE) then
        begin
            if msg.message = WM_QUIT then
            begin
                bQuit := true;
            end
            else
            begin
                TranslateMessage(@msg);
                DispatchMessage(@msg);
            end
        end
        else
        begin
            glClearColor(0.0, 0.0, 0.0, 0.0);
            glClear(GL_COLOR_BUFFER_BIT);

            DrawTriangle();

            SwapBuffers(hDC);
        end
    end;
    
    DisableOpenGL(hWindow, hDC, hRC);
    DestroyWindow(hWindow);

    glClear              := nil;
    glClearColor         := nil;
    glBegin              := nil;
    glEnd                := nil;
    glColor3f            := nil;
    glVertex2f           := nil;

    glVertexPointer      := nil;
    glColorPointer       := nil;
    glDrawArrays         := nil;
    glEnableClientState  := nil;
    glDisableClientState := nil;

    FreeLibrary(LibHandle);

    WinMain := msg.wParam;
end;

begin
    WinMain( hInstance, 0, nil, cmdShow );
end.
