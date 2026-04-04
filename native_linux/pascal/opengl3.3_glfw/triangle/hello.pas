program hello;

{$macro on}
{$define nl:=+ LineEnding +}

const
    libGL   = 'libGL.so.1';
    libGLFW = 'libglfw.so.3';

    GL_TRUE                    = 1;
    GL_FALSE                   = 0;
    GL_FLOAT                   = $1406;
    GL_COLOR_BUFFER_BIT        = $00004000;
    GL_TRIANGLES               = $0004;
    GL_ARRAY_BUFFER            = $8892;
    GL_STATIC_DRAW             = $88E4;
    GL_FRAGMENT_SHADER         = $8B30;
    GL_VERTEX_SHADER           = $8B31;

    GLFW_CONTEXT_VERSION_MAJOR : LongInt = $00022002;
    GLFW_CONTEXT_VERSION_MINOR : LongInt = $00022003;
    GLFW_OPENGL_FORWARD_COMPAT : LongInt = $00022006;
    GLFW_OPENGL_PROFILE        : LongInt = $00022008;
    GLFW_OPENGL_CORE_PROFILE   : LongInt = $00032001;
    GLFW_TRUE                  = 1;

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

    TGLenum     = GLenum;
    TGLboolean  = GLboolean;
    TGLbitfield = GLbitfield;
    TGLbyte     = GLbyte;
    TGLshort    = GLshort;
    TGLint      = GLint;
    TGLsizei    = GLsizei;
    TGLubyte    = GLubyte;
    TGLushort   = GLushort;
    TGLuint     = GLuint;
    TGLfloat    = GLfloat;
    TGLclampf   = GLclampf;
    TGLdouble   = GLdouble;
    TGLclampd   = GLclampd;

    GLHandle    = LongInt;
    PGLchar     = PAnsiChar;
    PPGLchar    = ^PGLChar;
    PLongInt    = ^LongInt;

    TglGenBuffers              = procedure(n: TGLsizei; buffers: PGLuint); cdecl;
    TglBindBuffer              = procedure(target: TGLenum; buffer: TGLuint); cdecl;
    TglBufferData              = procedure(target: TGLenum; size: TGLsizei; const data: PGLvoid; usage: TGLenum); cdecl;
    TglCreateShader            = function(shaderType: cardinal): LongInt; cdecl;
    TglShaderSource            = procedure(shaderObj: LongInt; count: LongInt; _string: PPAnsiChar; lengths: PLongInt); cdecl;
    TglCompileShader           = procedure(shaderObj: LongInt); cdecl;
    TglCreateProgram           = function: LongInt; cdecl;
    TglAttachShader            = procedure(programObj, shaderObj: LongInt); cdecl;
    TglLinkProgram             = procedure(programObj: LongInt); cdecl;
    TglUseProgram              = procedure(programObj: LongInt); cdecl;
    TglGetAttribLocation       = function(programObj: GLhandle; char: PGLChar): GLint; cdecl;
    TglEnableVertexAttribArray = procedure(index: GLuint); cdecl;
    TglVertexAttribPointer     = procedure(index: GLuint; size: GLint; _type: GLenum; normalized: GLboolean; stride: GLsizei; const _pointer: PGLvoid); cdecl;
    TglGenVertexArrays         = procedure(n: GLsizei; arrays: PGLuint); cdecl;
    TglBindVertexArray         = procedure(array_: GLuint); cdecl;

{ GLFW }
function  glfwInit: LongInt; cdecl; external libGLFW;
procedure glfwTerminate; cdecl; external libGLFW;
procedure glfwWindowHint(hint, value: LongInt); cdecl; external libGLFW;
function  glfwCreateWindow(width, height: LongInt; title: PAnsiChar; monitor, share: Pointer): Pointer; cdecl; external libGLFW;
procedure glfwDestroyWindow(window: Pointer); cdecl; external libGLFW;
procedure glfwMakeContextCurrent(window: Pointer); cdecl; external libGLFW;
function  glfwWindowShouldClose(window: Pointer): LongInt; cdecl; external libGLFW;
procedure glfwSwapBuffers(window: Pointer); cdecl; external libGLFW;
procedure glfwPollEvents; cdecl; external libGLFW;
function  glfwGetProcAddress(procname: PAnsiChar): Pointer; cdecl; external libGLFW;

{ OpenGL }
procedure glClear(mask: GLbitfield); cdecl; external libGL;
procedure glClearColor(red, green, blue, alpha: GLclampf); cdecl; external libGL;
procedure glDrawArrays(mode: GLenum; first: GLint; count: GLsizei); cdecl; external libGL;

var
    glfwWindow: Pointer;
    vao        : GLuint;
    vbo        : array[0..1] of GLuint;
    posAttrib  : GLint;
    colAttrib  : GLint;

    glGenBuffers              : TglGenBuffers;
    glBindBuffer              : TglBindBuffer;
    glBufferData              : TglBufferData;
    glCreateShader            : TglCreateShader;
    glShaderSource            : TglShaderSource;
    glCompileShader           : TglCompileShader;
    glCreateProgram           : TglCreateProgram;
    glAttachShader            : TglAttachShader;
    glLinkProgram             : TglLinkProgram;
    glUseProgram              : TglUseProgram;
    glGetAttribLocation       : TglGetAttribLocation;
    glEnableVertexAttribArray : TglEnableVertexAttribArray;
    glVertexAttribPointer     : TglVertexAttribPointer;
    glGenVertexArrays         : TglGenVertexArrays;
    glBindVertexArray         : TglBindVertexArray;

    vertexSource: PChar =
'#version 330 core                            'nl
'layout(location = 0) in vec3 position;       'nl
'layout(location = 1) in vec3 color;          'nl
'out vec4 vColor;                             'nl
'void main()                                  'nl
'{                                            'nl
'  vColor = vec4(color, 1.0);                 'nl
'  gl_Position = vec4(position, 1.0);         'nl
'}                                            ';

    fragmentSource: PChar =
'#version 330 core                            'nl
'in  vec4 vColor;                             'nl
'out vec4 outColor;                           'nl
'void main()                                  'nl
'{                                            'nl
'  outColor = vColor;                         'nl
'}                                            ';

procedure InitOpenGLFunc;
begin
    glGenBuffers              := TglGenBuffers             (glfwGetProcAddress('glGenBuffers'));
    glBindBuffer              := TglBindBuffer             (glfwGetProcAddress('glBindBuffer'));
    glBufferData              := TglBufferData             (glfwGetProcAddress('glBufferData'));
    glCreateShader            := TglCreateShader           (glfwGetProcAddress('glCreateShader'));
    glShaderSource            := TglShaderSource           (glfwGetProcAddress('glShaderSource'));
    glCompileShader           := TglCompileShader          (glfwGetProcAddress('glCompileShader'));
    glCreateProgram           := TglCreateProgram          (glfwGetProcAddress('glCreateProgram'));
    glAttachShader            := TglAttachShader           (glfwGetProcAddress('glAttachShader'));
    glLinkProgram             := TglLinkProgram            (glfwGetProcAddress('glLinkProgram'));
    glUseProgram              := TglUseProgram             (glfwGetProcAddress('glUseProgram'));
    glGetAttribLocation       := TglGetAttribLocation      (glfwGetProcAddress('glGetAttribLocation'));
    glEnableVertexAttribArray := TglEnableVertexAttribArray(glfwGetProcAddress('glEnableVertexAttribArray'));
    glVertexAttribPointer     := TglVertexAttribPointer    (glfwGetProcAddress('glVertexAttribPointer'));
    glGenVertexArrays         := TglGenVertexArrays        (glfwGetProcAddress('glGenVertexArrays'));
    glBindVertexArray         := TglBindVertexArray        (glfwGetProcAddress('glBindVertexArray'));
end;

procedure InitShader;
var
    vertices:       array [0..8] of GLfloat;
    colors:         array [0..8] of GLfloat;
    vertexShader:   GLuint;
    fragmentShader: GLuint;
    shaderProgram:  GLuint;
begin
    glGenVertexArrays(1, @vao);
    glBindVertexArray(vao);

    glGenBuffers(2, @vbo);

    vertices[0] :=  0.0;   vertices[1] :=  0.5;   vertices[2] :=  0.0;
    vertices[3] :=  0.5;   vertices[4] := -0.5;   vertices[5] :=  0.0;
    vertices[6] := -0.5;   vertices[7] := -0.5;   vertices[8] :=  0.0;

    colors[0] := 1.0;   colors[1] := 0.0;   colors[2] := 0.0;
    colors[3] := 0.0;   colors[4] := 1.0;   colors[5] := 0.0;
    colors[6] := 0.0;   colors[7] := 0.0;   colors[8] := 1.0;

    glBindBuffer(GL_ARRAY_BUFFER, vbo[0]);
    glBufferData(GL_ARRAY_BUFFER, SizeOf(vertices), @vertices, GL_STATIC_DRAW);

    glBindBuffer(GL_ARRAY_BUFFER, vbo[1]);
    glBufferData(GL_ARRAY_BUFFER, SizeOf(colors), @colors, GL_STATIC_DRAW);

    vertexShader := glCreateShader(GL_VERTEX_SHADER);
    glShaderSource(vertexShader, 1, @vertexSource, nil);
    glCompileShader(vertexShader);

    fragmentShader := glCreateShader(GL_FRAGMENT_SHADER);
    glShaderSource(fragmentShader, 1, @fragmentSource, nil);
    glCompileShader(fragmentShader);

    shaderProgram := glCreateProgram;
    glAttachShader(shaderProgram, vertexShader);
    glAttachShader(shaderProgram, fragmentShader);
    glLinkProgram(shaderProgram);
    glUseProgram(shaderProgram);

    posAttrib := glGetAttribLocation(shaderProgram, 'position');
    glBindBuffer(GL_ARRAY_BUFFER, vbo[0]);
    glEnableVertexAttribArray(posAttrib);
    glVertexAttribPointer(posAttrib, 3, GL_FLOAT, GL_FALSE, 0, nil);

    colAttrib := glGetAttribLocation(shaderProgram, 'color');
    glBindBuffer(GL_ARRAY_BUFFER, vbo[1]);
    glEnableVertexAttribArray(colAttrib);
    glVertexAttribPointer(colAttrib, 3, GL_FLOAT, GL_FALSE, 0, nil);
end;

procedure DrawTriangle;
begin
    glBindVertexArray(vao);
    glDrawArrays(GL_TRIANGLES, 0, 3);
end;

begin
    glfwInit;
    glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 3);
    glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 3);
    glfwWindowHint(GLFW_OPENGL_FORWARD_COMPAT, GLFW_TRUE);
    glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);
    glfwWindow := glfwCreateWindow(640, 480, 'Hello, Pascal World!', nil, nil);
    glfwMakeContextCurrent(glfwWindow);

    InitOpenGLFunc;
    InitShader;

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
