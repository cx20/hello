program hello;

const
    libGL   = 'libGL.so.1';
    libGLFW = 'libglfw.so.3';

    GL_COLOR_BUFFER_BIT = $00004000;
    GL_TRIANGLES        = $0004;

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
procedure glBegin(mode: GLenum); cdecl; external libGL;
procedure glEnd; cdecl; external libGL;
procedure glColor3f(red, green, blue: GLfloat); cdecl; external libGL;
procedure glVertex2f(x, y: GLfloat); cdecl; external libGL;

var
    glfwWindow: Pointer;

procedure DrawTriangle;
begin
    glBegin(GL_TRIANGLES);

        glColor3f(1.0, 0.0, 0.0);   glVertex2f( 0.0,  0.50);
        glColor3f(0.0, 1.0, 0.0);   glVertex2f( 0.5, -0.50);
        glColor3f(0.0, 0.0, 1.0);   glVertex2f(-0.5, -0.50);

    glEnd;
end;

begin
    glfwInit;
    glfwWindow := glfwCreateWindow(640, 480, 'Hello, Pascal World!', nil, nil);
    glfwMakeContextCurrent(glfwWindow);

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
