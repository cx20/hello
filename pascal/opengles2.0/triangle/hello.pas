program hello;

{$macro on}
{$define nl:=+ LineEnding +}

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

    TglGenBuffers         = procedure(n: TGLsizei; buffers: PGLuint); stdcall;
    TglBindBuffer         = procedure(target: TGLenum; buffer: TGLuint); stdcall;
    TglBufferData         = procedure(target: TGLenum; size: TGLsizei; const data: PGLvoid; usage: TGLenum); stdcall;
    TglCreateShader       = function(shaderType: cardinal): integer; stdcall;
    TglShaderSource       = procedure(shaderObj: integer; count: integer; _string: PPAnsiChar; lengths: PInteger); stdcall;
    TglCompileShader      = procedure(shaderObj: integer); stdcall;
    TglCreateProgram      = function: integer; stdcall;
    TglAttachShader       = procedure(programObj, shaderObj: integer); stdcall;
    TglLinkProgram        = procedure(programObj: integer); stdcall;
    TglUseProgram         = procedure(programObj: integer); stdcall;
    TglGetAttribLocation  = function(programObj: GLhandle; char: PGLChar): glint; stdcall;
    TglEnableVertexAttribArray = procedure(index: GLuint); stdcall; 
    TglVertexAttribPointer = procedure(index: GLuint; size: GLint; _type: GLenum; normalized: GLboolean; stride: GLsizei; const _pointer: PGLvoid); stdcall;
    TwglCreateContextAttribsARB = function (DC: HDC; hShareContext:HGLRC; attribList:PInteger ):HGLRC;stdcall;

var
    glClear              : procedure(mask: GLbitfield); stdcall;
    glClearColor         : procedure(red, green, blue, alpha: GLclampf); stdcall;
    glDrawArrays         : procedure (mode: GLenum; first: GLint; count: GLsizei); stdcall;

    glGenBuffers              : TglGenBuffers              ;
    glBindBuffer              : TglBindBuffer              ;
    glBufferData              : TglBufferData              ;
    glCreateShader            : TglCreateShader            ;
    glShaderSource            : TglShaderSource            ;
    glCompileShader           : TglCompileShader           ;
    glCreateProgram           : TglCreateProgram           ;
    glAttachShader            : TglAttachShader            ;
    glLinkProgram             : TglLinkProgram             ;
    glUseProgram              : TglUseProgram              ;
    glGetAttribLocation       : TglGetAttribLocation       ;
    glEnableVertexAttribArray : TglEnableVertexAttribArray ;
    glVertexAttribPointer     : TglVertexAttribPointer     ;
    wglCreateContextAttribsARB: TwglCreateContextAttribsARB;
 
    vbo : array[0..1] of GLuint;
    posAttrib: GLint;
    colAttrib: GLint;

    vertexSource: PChar =
'attribute vec3 position;                     'nl
'attribute vec3 color;                        'nl
'varying   vec4 vColor;                       'nl
'void main()                                  'nl
'{                                            'nl
'  vColor = vec4(color, 1.0);                 'nl
'  gl_Position = vec4(position, 1.0);         'nl
'}                                            ';

    fragmentSource : PChar =
'precision mediump float;                     'nl
'varying vec4 vColor;                         'nl
'void main()                                  'nl
'{                                            'nl
'  gl_FragColor = vColor;                     'nl
'}                                            ';

 const
    PFD_TYPE_RGBA        = 0;
    PFD_MAIN_PLANE       = 0;
    
    PFD_DOUBLEBUFFER     = $00000001;
    PFD_DRAW_TO_WINDOW   = $00000004;
    PFD_SUPPORT_OPENGL   = $00000020;

    GL_TRUE              = 1;
    GL_FALSE             = 0;
  
    GL_FLOAT             = $1406;
    
    GL_COLOR_BUFFER_BIT  = $00004000;
    GL_TRIANGLES         = $0004;
    GL_TRIANGLE_STRIP    = $0005;

    GL_VERTEX_ARRAY      = $8074;
    GL_COLOR_ARRAY       = $8076;
    
    GL_ARRAY_BUFFER      = $8892;
    
    GL_STATIC_DRAW       = $88E4;
    
    GL_FRAGMENT_SHADER   = $8B30;
    GL_VERTEX_SHADER     = $8B31;

function WindowProc(hWindow:HWnd; message:Cardinal; wParam:Word; lParam:Longint):LongWord; stdcall;
begin
    case message of
        WM_CLOSE:
            PostQuitMessage(0);
    else
        WindowProc := DefWindowProc(hWindow, message, wParam, lParam);
        exit;
    end;
    WindowProc := 0;
end;

function EnableOpenGL(hDC: THandle): HGLRC;
var
    hRC:       HGLRC;
    hGLRC_old: HGLRC;
    pfd:       PIXELFORMATDESCRIPTOR;
    iFormat:   LongInt;
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

    hGLRC_old := wglCreateContext(hDC);
    wglMakeCurrent(hDC, hGLRC_old);
    
    wglCreateContextAttribsARB := TwglCreateContextAttribsARB(wglGetProcAddress('wglCreateContextAttribsARB'));

    hRC := wglCreateContextAttribsARB(hDC, 0, nil);

    wglMakeCurrent(hDC, hRC);
    wglDeleteContext(hGLRC_old);

    EnableOpenGL := hRC;
end;

procedure DisableOpenGL(hWindow: HWnd; hDC: THandle; hRC: HGLRC);
begin
    wglMakeCurrent(0, 0);
    wglDeleteContext(hRC);
    ReleaseDC(hWindow, hDC);
end;

procedure InitOpenGLFunc();
begin
    glGenBuffers              := TglGenBuffers             (wglGetProcAddress('glGenBuffers'));
    glBindBuffer              := TglBindBuffer             (wglGetProcAddress('glBindBuffer'));
    glBufferData              := TglBufferData             (wglGetProcAddress('glBufferData'));
    glCreateShader            := TglCreateShader           (wglGetProcAddress('glCreateShader'));
    glShaderSource            := TglShaderSource           (wglGetProcAddress('glShaderSource'));
    glCompileShader           := TglCompileShader          (wglGetProcAddress('glCompileShader'));
    glCreateProgram           := TglCreateProgram          (wglGetProcAddress('glCreateProgram'));
    glAttachShader            := TglAttachShader           (wglGetProcAddress('glAttachShader'));
    glLinkProgram             := TglLinkProgram            (wglGetProcAddress('glLinkProgram'));
    glUseProgram              := TglUseProgram             (wglGetProcAddress('glUseProgram'));
    glGetAttribLocation       := TglGetAttribLocation      (wglGetProcAddress('glGetAttribLocation'));
    glEnableVertexAttribArray := TglEnableVertexAttribArray(wglGetProcAddress('glEnableVertexAttribArray'));
    glVertexAttribPointer     := TglVertexAttribPointer    (wglGetProcAddress('glVertexAttribPointer'));
end;

procedure InitShader();
var
    vertices: array [0..8] of GLfloat;
    colors:   array [0..8] of GLfloat;
    vertexShader:   GLuint;
    fragmentShader: GLuint;
    shaderProgram:  GLuint;
begin
    glGenBuffers(2, @vbo);
    
    vertices[0] :=  0.0;
    vertices[1] :=  0.5;
    vertices[2] :=  0.0;
    vertices[3] :=  0.5;
    vertices[4] := -0.5;
    vertices[5] :=  0.0;
    vertices[6] := -0.5;
    vertices[7] := -0.5;
    vertices[8] :=  0.0;

    colors[0]   := 1.0;
    colors[1]   := 0.0;
    colors[2]   := 0.0;
    colors[3]   := 0.0;
    colors[4]   := 1.0;
    colors[5]   := 0.0;
    colors[6]   := 0.0;
    colors[7]   := 0.0;
    colors[8]   := 1.0;

    glBindBuffer(GL_ARRAY_BUFFER, vbo[0]);
    glBufferData(GL_ARRAY_BUFFER, SizeOf(vertices), @vertices, GL_STATIC_DRAW);

    glBindBuffer(GL_ARRAY_BUFFER, vbo[1]);
    glBufferData(GL_ARRAY_BUFFER, SizeOf(colors), @colors, GL_STATIC_DRAW);

    // Create and compile the vertex shader
    vertexShader := glCreateShader(GL_VERTEX_SHADER);
    glShaderSource(vertexShader, 1, @vertexSource, nil);
    glCompileShader(vertexShader);

    // Create and compile the fragment shader    
    fragmentShader := glCreateShader(GL_FRAGMENT_SHADER);
    glShaderSource(fragmentShader, 1, @fragmentSource, nil);
    glCompileShader(fragmentShader);
    
    // Link the vertex and fragment shader into a shader program
    shaderProgram := glCreateProgram();
    glAttachShader(shaderProgram, vertexShader);
    glAttachShader(shaderProgram, fragmentShader);
    glLinkProgram(shaderProgram);
    glUseProgram(shaderProgram);

    // Specify the layout of the vertex data
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
    
    glClear(GL_COLOR_BUFFER_BIT);

    // Draw a triangle from the 3 vertices
    glDrawArrays(GL_TRIANGLES, 0, 3);

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
    Pointer(glClear     ) := GetProcAddress(LibHandle, 'glClear');
    Pointer(glClearColor) := GetProcAddress(LibHandle, 'glClearColor');
    Pointer(glDrawArrays) := GetProcAddress(LibHandle, 'glDrawArrays');
    
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

    hDC := GetDC(hWindow);
    hRC := EnableOpenGL(hDC);

    UpdateWindow(hWindow);

    ShowWindow(hWindow, nCmdShow);

    InitOpenGLFunc();

    InitShader();

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

    FreeLibrary(LibHandle);

    WinMain := msg.wParam;
end;

begin
    WinMain( hInstance, 0, nil, cmdShow );
end.
