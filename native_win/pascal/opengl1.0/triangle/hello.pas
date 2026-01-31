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

var
    glClear      : procedure(mask: GLbitfield); stdcall;
    glClearColor : procedure(red, green, blue, alpha: GLclampf); stdcall;
    glBegin      : procedure(mode: GLenum); stdcall;
    glEnd        : procedure; stdcall;
    glColor3f    : procedure(red, green, blue: GLfloat); stdcall;
    glVertex2f   : procedure(x, y: GLfloat); stdcall;

const
    PFD_TYPE_RGBA           = 0;
    PFD_MAIN_PLANE          = 0;
    
    PFD_DOUBLEBUFFER        = $00000001;
    PFD_DRAW_TO_WINDOW      = $00000004;
    PFD_SUPPORT_OPENGL      = $00000020;

    GL_COLOR_BUFFER_BIT     = $00004000;
    GL_TRIANGLES            = $0004;

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
begin
    glBegin(GL_TRIANGLES);

        glColor3f(1.0, 0.0, 0.0);   glVertex2f( 0.0,  0.50);
        glColor3f(0.0, 1.0, 0.0);   glVertex2f( 0.5, -0.50);
        glColor3f(0.0, 0.0, 1.0);   glVertex2f(-0.5, -0.50);

    glEnd();
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
    Pointer(glClear)      := GetProcAddress(LibHandle, 'glClear');
    Pointer(glClearColor) := GetProcAddress(LibHandle, 'glClearColor');
    Pointer(glBegin)      := GetProcAddress(LibHandle, 'glBegin');
    Pointer(glEnd)        := GetProcAddress(LibHandle, 'glEnd');
    Pointer(glColor3f)    := GetProcAddress(LibHandle, 'glColor3f');
    Pointer(glVertex2f)   := GetProcAddress(LibHandle, 'glVertex2f');
    
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

    glClear      := nil;
    glClearColor := nil;
    glBegin      := nil;
    glEnd        := nil;
    glColor3f    := nil;
    glVertex2f   := nil;

    FreeLibrary(LibHandle);

    WinMain := msg.wParam;
end;

begin
    WinMain( hInstance, 0, nil, cmdShow );
end.
