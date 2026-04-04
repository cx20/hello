program hello;

uses Math;

const
    libGL   = 'libGL.so.1';
    libGLFW = 'libglfw.so.3';

    GL_COLOR_BUFFER_BIT  = $00004000;
    GL_TRIANGLE_STRIP    = $0005;
    GL_FLOAT             = $1406;
    GL_VERTEX_ARRAY      = $8074;
    GL_COLOR_ARRAY       = $8076;

type
    GLenum     = Cardinal;      PGLenum     = ^GLenum;
    GLboolean  = Byte;          PGLboolean  = ^GLboolean;
    GLbitfield = Cardinal;      PGLbitfield = ^GLbitfield;
    GLbyte     = ShortInt;      PGLbyte     = ^GLbyte;
    GLshort    = SmallInt;      PGLshort    = ^GLshort;
    GLint      = LongInt;       PGLint      = ^GLint;
    GLsizei    = LongInt;       PGLsizei    = ^GLsizei;
    GLubyte    = Byte;          PGLubyte    = ^GLubyte;
    GLushort   = Word;          PGLushort   = ^GLushort;
    GLuint     = Cardinal;      PGLuint     = ^GLuint;
    GLfloat    = Single;        PGLfloat    = ^GLfloat;
    GLclampf   = Single;        PGLclampf   = ^GLclampf;
    GLdouble   = Double;        PGLdouble   = ^GLdouble;
    GLclampd   = Double;        PGLclampd   = ^GLclampd;
  { GLvoid     = void; }        PGLvoid     = Pointer;
                                PPGLvoid    = ^PGLvoid;

{ GLFW }
function  glfwInit: LongInt; cdecl; external libGLFW;
procedure glfwTerminate; cdecl; external libGLFW;
function  glfwCreateWindow(width, height: LongInt; title: PAnsiChar; monitor, share: Pointer): Pointer; cdecl; external libGLFW;
procedure glfwDestroyWindow(window: Pointer); cdecl; external libGLFW;
procedure glfwMakeContextCurrent(window: Pointer); cdecl; external libGLFW;
function  glfwWindowShouldClose(window: Pointer): LongInt; cdecl; external libGLFW;
procedure glfwSwapBuffers(window: Pointer); cdecl; external libGLFW;
procedure glfwPollEvents; cdecl; external libGLFW;

{ OpenGL }
procedure glClear(mask: GLbitfield); cdecl; external libGL;
procedure glClearColor(red, green, blue, alpha: GLclampf); cdecl; external libGL;
procedure glViewport(x, y: GLint; width, height: GLsizei); cdecl; external libGL;
procedure glEnableClientState(arr: GLenum); cdecl; external libGL;
procedure glColorPointer(size: GLint; type_: GLenum; stride: GLsizei; pointer: Pointer); cdecl; external libGL;
procedure glVertexPointer(size: GLint; type_: GLenum; stride: GLsizei; pointer: Pointer); cdecl; external libGL;
procedure glDrawArrays(mode: GLenum; first: GLint; count: GLsizei); cdecl; external libGL;

var
    glfwWindow: Pointer;
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
    glfwInit;
    glfwWindow := glfwCreateWindow(640, 480, 'Hello, Pascal World!', nil, nil);
    glfwMakeContextCurrent(glfwWindow);
    glViewport(0, 0, 640, 480);

    while glfwWindowShouldClose(glfwWindow) = 0 do begin
        glClearColor(0.0, 0.0, 0.0, 0.0);
        glClear(GL_COLOR_BUFFER_BIT);
        DrawTriangle;
        glfwSwapBuffers(glfwWindow);
        glfwPollEvents;
    end;

    glfwDestroyWindow(glfwWindow);
    glfwTerminate;
end.
