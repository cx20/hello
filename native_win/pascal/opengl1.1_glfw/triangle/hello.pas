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
    glClear             : procedure(mask: GLbitfield); stdcall;
    glClearColor        : procedure(red, green, blue, alpha: GLclampf); stdcall;
    glVertexPointer     : procedure(size: GLint; atype: GLenum; stride: GLsizei; data: pointer); stdcall;
    glColorPointer      : procedure(size: GLint; atype: GLenum; stride: GLsizei; data: pointer); stdcall;
    glDrawArrays        : procedure(mode: GLenum; first: GLint; count: GLsizei); stdcall;
    glEnableClientState : procedure(aarray: GLenum); stdcall;

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
    GL_COLOR_BUFFER_BIT  = $00004000;
    GL_TRIANGLE_STRIP    = $0005;
    GL_FLOAT             = $1406;
    GL_VERTEX_ARRAY      = $8074;
    GL_COLOR_ARRAY       = $8076;

procedure DrawTriangle();
var
    colors:   array [0..8] of GLfloat;
    vertices: array [0..5] of GLfloat;
begin
    glEnableClientState(GL_COLOR_ARRAY);
    glEnableClientState(GL_VERTEX_ARRAY);

    colors[0] := 1.0;   colors[1] := 0.0;   colors[2] := 0.0;
    colors[3] := 0.0;   colors[4] := 1.0;   colors[5] := 0.0;
    colors[6] := 0.0;   colors[7] := 0.0;   colors[8] := 1.0;

    vertices[0] :=  0.0;   vertices[1] :=  0.5;
    vertices[2] :=  0.5;   vertices[3] := -0.5;
    vertices[4] := -0.5;   vertices[5] := -0.5;

    glColorPointer(3,  GL_FLOAT, 0, @colors);
    glVertexPointer(2, GL_FLOAT, 0, @vertices);

    glDrawArrays(GL_TRIANGLE_STRIP, 0, 3);
end;

function WinMain(hInstance, hPrevInstance: THandle; lpCmdLine: PAnsiChar; nCmdShow: Integer): Integer; stdcall;
var
    glLib:      THandle;
    glfwLib:    THandle;
    glfwWindow: Pointer;
const
    WindowName = 'Hello, World!';

begin
    glfwLib := LoadLibrary(PChar('glfw3.dll'));
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
    Pointer(glClear            ) := GetProcAddress(glLib, 'glClear');
    Pointer(glClearColor       ) := GetProcAddress(glLib, 'glClearColor');
    Pointer(glVertexPointer    ) := GetProcAddress(glLib, 'glVertexPointer');
    Pointer(glColorPointer     ) := GetProcAddress(glLib, 'glColorPointer');
    Pointer(glDrawArrays       ) := GetProcAddress(glLib, 'glDrawArrays');
    Pointer(glEnableClientState) := GetProcAddress(glLib, 'glEnableClientState');

    glfwInit();
    glfwWindow := glfwCreateWindow(640, 480, WindowName, nil, nil);
    glfwMakeContextCurrent(glfwWindow);

    while glfwWindowShouldClose(glfwWindow) = 0 do begin
        glClearColor(0.0, 0.0, 0.0, 0.0);
        glClear(GL_COLOR_BUFFER_BIT);
        DrawTriangle();
        glfwSwapBuffers(glfwWindow);
        glfwPollEvents();
    end;

    glfwDestroyWindow(glfwWindow);
    glfwTerminate();

    glClear             := nil;
    glClearColor        := nil;
    glVertexPointer     := nil;
    glColorPointer      := nil;
    glDrawArrays        := nil;
    glEnableClientState := nil;

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
