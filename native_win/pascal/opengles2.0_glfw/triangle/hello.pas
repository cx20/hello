program hello;

{$macro on}
{$define nl:=+ LineEnding +}

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

    GLHandle    = Integer;
    PGLchar     = PAnsiChar;
    PPGLchar    = ^PGLChar;

    TglClear                   = procedure(mask: GLbitfield); stdcall;
    TglClearColor              = procedure(red, green, blue, alpha: GLclampf); stdcall;
    TglDrawArrays              = procedure(mode: GLenum; first: GLint; count: GLsizei); stdcall;
    TglGenBuffers              = procedure(n: TGLsizei; buffers: PGLuint); stdcall;
    TglBindBuffer              = procedure(target: TGLenum; buffer: TGLuint); stdcall;
    TglBufferData              = procedure(target: TGLenum; size: TGLsizei; const data: PGLvoid; usage: TGLenum); stdcall;
    TglCreateShader            = function(shaderType: cardinal): integer; stdcall;
    TglShaderSource            = procedure(shaderObj: integer; count: integer; _string: PPAnsiChar; lengths: PInteger); stdcall;
    TglCompileShader           = procedure(shaderObj: integer); stdcall;
    TglCreateProgram           = function: integer; stdcall;
    TglAttachShader            = procedure(programObj, shaderObj: integer); stdcall;
    TglLinkProgram             = procedure(programObj: integer); stdcall;
    TglUseProgram              = procedure(programObj: integer); stdcall;
    TglGetAttribLocation       = function(programObj: GLhandle; char: PGLChar): GLint; stdcall;
    TglEnableVertexAttribArray = procedure(index: GLuint); stdcall;
    TglVertexAttribPointer     = procedure(index: GLuint; size: GLint; _type: GLenum; normalized: GLboolean; stride: GLsizei; const _pointer: PGLvoid); stdcall;

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
    glClear      : TglClear;
    glClearColor : TglClearColor;
    glDrawArrays : TglDrawArrays;

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

    vbo        : array[0..1] of GLuint;
    posAttrib  : GLint;
    colAttrib  : GLint;

    vertexSource: PChar =
'attribute vec3 position;                     'nl
'attribute vec3 color;                        'nl
'varying   vec4 vColor;                       'nl
'void main()                                  'nl
'{                                            'nl
'  vColor = vec4(color, 1.0);                 'nl
'  gl_Position = vec4(position, 1.0);         'nl
'}                                            ';

    fragmentSource: PChar =
'precision mediump float;                     'nl
'varying   vec4 vColor;                       'nl
'void main()                                  'nl
'{                                            'nl
'  gl_FragColor = vColor;                     'nl
'}                                            ';

const
    GL_TRUE              = 1;
    GL_FALSE             = 0;
    GL_FLOAT             = $1406;
    GL_COLOR_BUFFER_BIT  = $00004000;
    GL_TRIANGLES         = $0004;
    GL_ARRAY_BUFFER      = $8892;
    GL_STATIC_DRAW       = $88E4;
    GL_FRAGMENT_SHADER   = $8B30;
    GL_VERTEX_SHADER     = $8B31;

    GLFW_CLIENT_API            = $00022001;
    GLFW_OPENGL_ES_API         = $00030002;
    GLFW_CONTEXT_VERSION_MAJOR = $00022002;
    GLFW_CONTEXT_VERSION_MINOR = $00022003;

procedure InitOpenGLFunc();
begin
    glClear      := TglClear     (glfwGetProcAddress('glClear'));
    glClearColor := TglClearColor(glfwGetProcAddress('glClearColor'));
    glDrawArrays := TglDrawArrays(glfwGetProcAddress('glDrawArrays'));

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
end;

procedure InitShader();
var
    vertices:       array [0..8] of GLfloat;
    colors:         array [0..8] of GLfloat;
    vertexShader:   GLuint;
    fragmentShader: GLuint;
    shaderProgram:  GLuint;
begin
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

    shaderProgram := glCreateProgram();
    glAttachShader(shaderProgram, vertexShader);
    glAttachShader(shaderProgram, fragmentShader);
    glLinkProgram(shaderProgram);
    glUseProgram(shaderProgram);

    posAttrib := glGetAttribLocation(shaderProgram, 'position');
    glEnableVertexAttribArray(posAttrib);

    colAttrib := glGetAttribLocation(shaderProgram, 'color');
    glEnableVertexAttribArray(colAttrib);
end;

procedure DrawTriangle();
begin
    glBindBuffer(GL_ARRAY_BUFFER, vbo[0]);
    glVertexAttribPointer(posAttrib, 3, GL_FLOAT, GL_FALSE, 0, nil);

    glBindBuffer(GL_ARRAY_BUFFER, vbo[1]);
    glVertexAttribPointer(colAttrib, 3, GL_FLOAT, GL_FALSE, 0, nil);

    glDrawArrays(GL_TRIANGLES, 0, 3);
end;

function WinMain(hInstance, hPrevInstance: THandle; lpCmdLine: PAnsiChar; nCmdShow: Integer): Integer; stdcall;
var
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

    glfwInit();
    OutputDebugString('[hello] glfwInit done');
    glfwWindowHint(GLFW_CLIENT_API, GLFW_OPENGL_ES_API);
    glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 2);
    glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 0);
    glfwWindow := glfwCreateWindow(640, 480, WindowName, nil, nil);
    if glfwWindow = nil then
        OutputDebugString('[hello] glfwCreateWindow: FAILED')
    else
        OutputDebugString('[hello] glfwCreateWindow: OK');
    glfwMakeContextCurrent(glfwWindow);
    OutputDebugString('[hello] glfwMakeContextCurrent done');

    InitOpenGLFunc();
    OutputDebugString('[hello] InitOpenGLFunc done');
    InitShader();
    OutputDebugString('[hello] InitShader done');

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

    glClear                   := nil;
    glClearColor              := nil;
    glDrawArrays              := nil;
    glGenBuffers              := nil;
    glBindBuffer              := nil;
    glBufferData              := nil;
    glCreateShader            := nil;
    glShaderSource            := nil;
    glCompileShader           := nil;
    glCreateProgram           := nil;
    glAttachShader            := nil;
    glLinkProgram             := nil;
    glUseProgram              := nil;
    glGetAttribLocation       := nil;
    glEnableVertexAttribArray := nil;
    glVertexAttribPointer     := nil;

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

    FreeLibrary(glfwLib);

    WinMain := 0;
end;

begin
    WinMain(hInstance, 0, nil, cmdShow);
end.
