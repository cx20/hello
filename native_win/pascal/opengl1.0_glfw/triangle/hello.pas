program hello;

uses
    Windows;

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

    TglfwInit               = function: Integer; cdecl;
    TglfwTerminate          = procedure; cdecl;
    TglfwWindowHint         = procedure(hint, value: Integer); cdecl;
    TglfwCreateWindow       = function(width, height: Integer; title: PAnsiChar; monitor, share: Pointer): Pointer; cdecl;
    TglfwDestroyWindow      = procedure(window: Pointer); cdecl;
    TglfwMakeContextCurrent = procedure(window: Pointer); cdecl;
    TglfwWindowShouldClose  = function(window: Pointer): Integer; cdecl;
    TglfwSwapBuffers        = procedure(window: Pointer); cdecl;
    TglfwPollEvents         = procedure; cdecl;
    TglfwGetProcAddress     = function(procname: PAnsiChar): Pointer; cdecl;

var
    glClear      : procedure(mask: GLbitfield); stdcall;
    glClearColor : procedure(red, green, blue, alpha: GLclampf); stdcall;
    glBegin      : procedure(mode: GLenum); stdcall;
    glEnd        : procedure; stdcall;
    glColor3f    : procedure(red, green, blue: GLfloat); stdcall;
    glVertex2f   : procedure(x, y: GLfloat); stdcall;

    glfwInit               : TglfwInit;
    glfwTerminate          : TglfwTerminate;
    glfwWindowHint         : TglfwWindowHint;
    glfwCreateWindow       : TglfwCreateWindow;
    glfwDestroyWindow      : TglfwDestroyWindow;
    glfwMakeContextCurrent : TglfwMakeContextCurrent;
    glfwWindowShouldClose  : TglfwWindowShouldClose;
    glfwSwapBuffers        : TglfwSwapBuffers;
    glfwPollEvents         : TglfwPollEvents;
    glfwGetProcAddress     : TglfwGetProcAddress;

const
    GL_COLOR_BUFFER_BIT = $00004000;
    GL_TRIANGLES        = $0004;

procedure DrawTriangle();
begin
    glBegin(GL_TRIANGLES);

        glColor3f(1.0, 0.0, 0.0);   glVertex2f( 0.0,  0.50);
        glColor3f(0.0, 1.0, 0.0);   glVertex2f( 0.5, -0.50);
        glColor3f(0.0, 0.0, 1.0);   glVertex2f(-0.5, -0.50);

    glEnd();
end;

function WinMain(hInstance, hPrevInstance: THandle; lpCmdLine: PAnsiChar; nCmdShow: Integer): Integer; stdcall;
var
    glLib:      THandle;
    glfwLib:    THandle;
    glfwWindow: Pointer;
    frameCount: Integer;
const
    WindowName = 'Hello, World!';

begin
    glfwLib := LoadLibrary(PChar('glfw3.dll'));
    if glfwLib = 0 then begin
        OutputDebugString('[hello] LoadLibrary(glfw3.dll): FAILED');
        WinMain := 1;
        Exit;
    end;
    OutputDebugString('[hello] LoadLibrary(glfw3.dll): OK');
    Pointer(glfwInit              ) := GetProcAddress(glfwLib, 'glfwInit');
    Pointer(glfwTerminate         ) := GetProcAddress(glfwLib, 'glfwTerminate');
    Pointer(glfwWindowHint        ) := GetProcAddress(glfwLib, 'glfwWindowHint');
    Pointer(glfwCreateWindow      ) := GetProcAddress(glfwLib, 'glfwCreateWindow');
    Pointer(glfwDestroyWindow     ) := GetProcAddress(glfwLib, 'glfwDestroyWindow');
    Pointer(glfwMakeContextCurrent) := GetProcAddress(glfwLib, 'glfwMakeContextCurrent');
    Pointer(glfwWindowShouldClose ) := GetProcAddress(glfwLib, 'glfwWindowShouldClose');
    Pointer(glfwSwapBuffers       ) := GetProcAddress(glfwLib, 'glfwSwapBuffers');
    Pointer(glfwPollEvents        ) := GetProcAddress(glfwLib, 'glfwPollEvents');
    Pointer(glfwGetProcAddress    ) := GetProcAddress(glfwLib, 'glfwGetProcAddress');

    glLib := LoadLibrary(PChar('opengl32.dll'));
    if glLib = 0 then
        OutputDebugString('[hello] LoadLibrary(opengl32.dll): FAILED')
    else
        OutputDebugString('[hello] LoadLibrary(opengl32.dll): OK');
    Pointer(glClear     ) := GetProcAddress(glLib, 'glClear');
    Pointer(glClearColor) := GetProcAddress(glLib, 'glClearColor');
    Pointer(glBegin     ) := GetProcAddress(glLib, 'glBegin');
    Pointer(glEnd       ) := GetProcAddress(glLib, 'glEnd');
    Pointer(glColor3f   ) := GetProcAddress(glLib, 'glColor3f');
    Pointer(glVertex2f  ) := GetProcAddress(glLib, 'glVertex2f');

    glfwInit();
    OutputDebugString('[hello] glfwInit done');
    glfwWindow := glfwCreateWindow(640, 480, WindowName, nil, nil);
    if glfwWindow = nil then
        OutputDebugString('[hello] glfwCreateWindow: FAILED')
    else
        OutputDebugString('[hello] glfwCreateWindow: OK');
    glfwMakeContextCurrent(glfwWindow);
    OutputDebugString('[hello] glfwMakeContextCurrent done');

    frameCount := 0;
    OutputDebugString('[hello] Enter render loop');
    while glfwWindowShouldClose(glfwWindow) = 0 do begin
        glClearColor(0.0, 0.0, 0.0, 0.0);
        glClear(GL_COLOR_BUFFER_BIT);
        DrawTriangle();
        glfwSwapBuffers(glfwWindow);
        glfwPollEvents();
        if frameCount = 0 then
            OutputDebugString('[hello] First frame rendered');
        Inc(frameCount);
    end;
    OutputDebugString('[hello] Exit render loop');

    glfwDestroyWindow(glfwWindow);
    glfwTerminate();

    glClear      := nil;
    glClearColor := nil;
    glBegin      := nil;
    glEnd        := nil;
    glColor3f    := nil;
    glVertex2f   := nil;

    glfwInit               := nil;
    glfwTerminate          := nil;
    glfwWindowHint         := nil;
    glfwCreateWindow       := nil;
    glfwDestroyWindow      := nil;
    glfwMakeContextCurrent := nil;
    glfwWindowShouldClose  := nil;
    glfwSwapBuffers        := nil;
    glfwPollEvents         := nil;
    glfwGetProcAddress     := nil;

    FreeLibrary(glLib);
    FreeLibrary(glfwLib);

    WinMain := 0;
end;

begin
    WinMain(hInstance, 0, nil, cmdShow);
end.
