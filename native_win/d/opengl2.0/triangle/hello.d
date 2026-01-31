import core.runtime;
import core.sys.windows.windows;
import core.sys.windows.windef;
import core.sys.windows.winuser;
import core.sys.windows.wingdi;

extern(System) {
    alias GLenum = uint;
    alias GLuint = uint;
    alias GLint = int;
    alias GLsizei = int;
    alias GLbitfield = uint;
    alias GLfloat = float;
    alias GLchar = char;
    alias GLboolean = ubyte;

    void glDrawArrays(GLenum mode, GLint first, GLsizei count);
    void glClear(GLbitfield mask);
    void glClearColor(GLfloat red, GLfloat green, GLfloat blue, GLfloat alpha);
    void glViewport(GLint x, GLint y, GLsizei width, GLsizei height);

    enum GL_VERTEX_SHADER = 0x8B31;
    enum GL_FRAGMENT_SHADER = 0x8B30;
    enum GL_FLOAT = 0x1406;
    enum GL_TRIANGLES = 0x0004;
    enum GL_COMPILE_STATUS = 0x8B81;
    enum GL_LINK_STATUS = 0x8B82;
    enum GL_ARRAY_BUFFER = 0x8892;
    enum GL_STATIC_DRAW = 0x88E4;
    enum GL_COLOR_BUFFER_BIT = 0x4000;
    enum GL_FALSE = 0;

    void* wglGetProcAddress(const GLchar* name);
}

// Function pointers for OpenGL 2.0 extensions
extern(System) {
    alias glCreateShaderFunc = GLuint function(GLenum shaderType);
    alias glShaderSourceFunc = void function(GLuint shader, GLsizei count, const GLchar** string, const GLint* length);
    alias glCompileShaderFunc = void function(GLuint shader);
    alias glGetShaderivFunc = void function(GLuint shader, GLenum pname, GLint* params);
    alias glGetShaderInfoLogFunc = void function(GLuint shader, GLsizei bufSize, GLsizei* length, GLchar* infoLog);
    alias glDeleteShaderFunc = void function(GLuint shader);
    alias glCreateProgramFunc = GLuint function();
    alias glAttachShaderFunc = void function(GLuint program, GLuint shader);
    alias glLinkProgramFunc = void function(GLuint program);
    alias glGetProgramivFunc = void function(GLuint program, GLenum pname, GLint* params);
    alias glGetProgramInfoLogFunc = void function(GLuint program, GLsizei bufSize, GLsizei* length, GLchar* infoLog);
    alias glUseProgramFunc = void function(GLuint program);
    alias glDeleteProgramFunc = void function(GLuint program);
    alias glGetAttribLocationFunc = GLint function(GLuint program, const GLchar* name);
    alias glEnableVertexAttribArrayFunc = void function(GLuint index);
    alias glVertexAttribPointerFunc = void function(GLuint index, GLint size, GLenum type, GLboolean normalized, GLsizei stride, const void* pointer);
    alias glGenBuffersFunc = void function(GLsizei n, GLuint* buffers);
    alias glBindBufferFunc = void function(GLenum target, GLuint buffer);
    alias glBufferDataFunc = void function(GLenum target, size_t size, const void* data, GLenum usage);
    alias glDeleteBuffersFunc = void function(GLsizei n, const GLuint* buffers);
}

// Global function pointers
glCreateShaderFunc glCreateShader;
glShaderSourceFunc glShaderSource;
glCompileShaderFunc glCompileShader;
glGetShaderivFunc glGetShaderiv;
glGetShaderInfoLogFunc glGetShaderInfoLog;
glDeleteShaderFunc glDeleteShader;
glCreateProgramFunc glCreateProgram;
glAttachShaderFunc glAttachShader;
glLinkProgramFunc glLinkProgram;
glGetProgramivFunc glGetProgramiv;
glGetProgramInfoLogFunc glGetProgramInfoLog;
glUseProgramFunc glUseProgram;
glDeleteProgramFunc glDeleteProgram;
glGetAttribLocationFunc glGetAttribLocation;
glEnableVertexAttribArrayFunc glEnableVertexAttribArray;
glVertexAttribPointerFunc glVertexAttribPointer;
glGenBuffersFunc glGenBuffers;
glBindBufferFunc glBindBuffer;
glBufferDataFunc glBufferData;
glDeleteBuffersFunc glDeleteBuffers;

// Global variables for rendering
static GLuint gShaderProgram;
static GLint gPosAttrib;
static GLint gColAttrib;
static GLuint[2] gVBO;
static HDC gHDC;
static int gWindowWidth = 640;
static int gWindowHeight = 480;

auto toUTF16z(S)(S s) {
    return cast(const(wchar)*)s.ptr;
}

void initOpenGL20() {
    glCreateShader = cast(glCreateShaderFunc) wglGetProcAddress("glCreateShader");
    glShaderSource = cast(glShaderSourceFunc) wglGetProcAddress("glShaderSource");
    glCompileShader = cast(glCompileShaderFunc) wglGetProcAddress("glCompileShader");
    glGetShaderiv = cast(glGetShaderivFunc) wglGetProcAddress("glGetShaderiv");
    glGetShaderInfoLog = cast(glGetShaderInfoLogFunc) wglGetProcAddress("glGetShaderInfoLog");
    glDeleteShader = cast(glDeleteShaderFunc) wglGetProcAddress("glDeleteShader");
    glCreateProgram = cast(glCreateProgramFunc) wglGetProcAddress("glCreateProgram");
    glAttachShader = cast(glAttachShaderFunc) wglGetProcAddress("glAttachShader");
    glLinkProgram = cast(glLinkProgramFunc) wglGetProcAddress("glLinkProgram");
    glGetProgramiv = cast(glGetProgramivFunc) wglGetProcAddress("glGetProgramiv");
    glGetProgramInfoLog = cast(glGetProgramInfoLogFunc) wglGetProcAddress("glGetProgramInfoLog");
    glUseProgram = cast(glUseProgramFunc) wglGetProcAddress("glUseProgram");
    glDeleteProgram = cast(glDeleteProgramFunc) wglGetProcAddress("glDeleteProgram");
    glGetAttribLocation = cast(glGetAttribLocationFunc) wglGetProcAddress("glGetAttribLocation");
    glEnableVertexAttribArray = cast(glEnableVertexAttribArrayFunc) wglGetProcAddress("glEnableVertexAttribArray");
    glVertexAttribPointer = cast(glVertexAttribPointerFunc) wglGetProcAddress("glVertexAttribPointer");
    glGenBuffers = cast(glGenBuffersFunc) wglGetProcAddress("glGenBuffers");
    glBindBuffer = cast(glBindBufferFunc) wglGetProcAddress("glBindBuffer");
    glBufferData = cast(glBufferDataFunc) wglGetProcAddress("glBufferData");
    glDeleteBuffers = cast(glDeleteBuffersFunc) wglGetProcAddress("glDeleteBuffers");
}

GLuint createShader(GLenum shaderType, const char* source) {
    GLuint shader = glCreateShader(shaderType);
    const GLchar* source_c = cast(const GLchar*) source;
    glShaderSource(shader, 1, &source_c, null);
    glCompileShader(shader);

    GLint success;
    glGetShaderiv(shader, GL_COMPILE_STATUS, &success);
    // Shader compilation status checked but not logged
    return shader;
}

void initShader() {
    const char* vertexSource = 
        "attribute vec3 position;\n"~
        "attribute vec3 color;\n"~
        "varying   vec4 vColor;\n"~
        "void main()\n"~
        "{\n"~
        "  vColor = vec4(color, 1.0);\n"~
        "  gl_Position = vec4(position, 1.0);\n"~
        "}\n";

    const char* fragmentSource = 
        "varying vec4 vColor;\n"~
        "void main()\n"~
        "{\n"~
        "  gl_FragColor = vColor;\n"~
        "}\n";

    glGenBuffers(2, gVBO.ptr);

    GLfloat[9] vertices = [
          0.0f,  0.5f, 0.0f, 
          0.5f, -0.5f, 0.0f, 
         -0.5f, -0.5f, 0.0f
    ];

    GLfloat[9] colors = [
         1.0f,  0.0f,  0.0f,
         0.0f,  1.0f,  0.0f,
         0.0f,  0.0f,  1.0f
    ];

    glBindBuffer(GL_ARRAY_BUFFER, gVBO[0]);
    glBufferData(GL_ARRAY_BUFFER, vertices.sizeof, vertices.ptr, GL_STATIC_DRAW);

    glBindBuffer(GL_ARRAY_BUFFER, gVBO[1]);
    glBufferData(GL_ARRAY_BUFFER, colors.sizeof, colors.ptr, GL_STATIC_DRAW);

    // Create and compile the vertex shader
    GLuint vertexShader = createShader(GL_VERTEX_SHADER, vertexSource);
    GLuint fragmentShader = createShader(GL_FRAGMENT_SHADER, fragmentSource);

    gShaderProgram = glCreateProgram();
    glAttachShader(gShaderProgram, vertexShader);
    glAttachShader(gShaderProgram, fragmentShader);
    glLinkProgram(gShaderProgram);

    GLint success;
    glGetProgramiv(gShaderProgram, GL_LINK_STATUS, &success);
    // Program linking status checked but not logged
    
    glUseProgram(gShaderProgram);

    gPosAttrib = glGetAttribLocation(gShaderProgram, "position");
    glEnableVertexAttribArray(cast(GLuint)gPosAttrib);

    gColAttrib = glGetAttribLocation(gShaderProgram, "color");
    glEnableVertexAttribArray(cast(GLuint)gColAttrib);

    glViewport(0, 0, gWindowWidth, gWindowHeight);

    glDeleteShader(vertexShader);
    glDeleteShader(fragmentShader);
}

void render() {
    glBindBuffer(GL_ARRAY_BUFFER, gVBO[0]);
    glVertexAttribPointer(cast(GLuint)gPosAttrib, 3, GL_FLOAT, GL_FALSE, 0, null);
    
    glBindBuffer(GL_ARRAY_BUFFER, gVBO[1]);
    glVertexAttribPointer(cast(GLuint)gColAttrib, 3, GL_FLOAT, GL_FALSE, 0, null);
    
    glClearColor(0.0f, 0.0f, 0.0f, 0.0f);
    glClear(GL_COLOR_BUFFER_BIT);

    glDrawArrays(GL_TRIANGLES, 0, 3);
    
    SwapBuffers(gHDC);
}

extern (Windows)
LRESULT WndProc(HWND hwnd, UINT message, WPARAM wParam, LPARAM lParam) nothrow {
    static HGLRC hglrc;
    static HDC hdc;

    try {
        switch (message) {
            case WM_CREATE:
                hdc = GetDC(hwnd);
                gHDC = hdc;
                PIXELFORMATDESCRIPTOR pfd = PIXELFORMATDESCRIPTOR(
                    nSize: PIXELFORMATDESCRIPTOR.sizeof,
                    nVersion: 1,
                    dwFlags: PFD_DRAW_TO_WINDOW | PFD_SUPPORT_OPENGL | PFD_DOUBLEBUFFER,
                    iPixelType: PFD_TYPE_RGBA,
                    cColorBits: 24,
                    cDepthBits: 16,
                    iLayerType: PFD_MAIN_PLANE
                );
                int format = ChoosePixelFormat(hdc, &pfd);
                SetPixelFormat(hdc, format, &pfd);
                hglrc = wglCreateContext(hdc);
                wglMakeCurrent(hdc, hglrc);
                initOpenGL20();
                initShader();
                glClearColor(0.0f, 0.0f, 0.0f, 0.0f);
                return 0;

            case WM_DESTROY:
                wglMakeCurrent(null, null);
                wglDeleteContext(hglrc);
                ReleaseDC(hwnd, hdc);
                PostQuitMessage(0);
                return 0;

            case WM_CLOSE:
                PostQuitMessage(0);
                return 0;

            default:
                return DefWindowProc(hwnd, message, wParam, lParam);
        }
    } catch (Throwable) {
        return DefWindowProc(hwnd, message, wParam, lParam);
    }
}

extern (Windows)
int WinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, LPSTR lpCmdLine, int nCmdShow) {
    Runtime.initialize();
    int result = myWinMain(hInstance, hPrevInstance, lpCmdLine, nCmdShow);
    Runtime.terminate();
    return result;
}

int myWinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, LPSTR lpCmdLine, int nCmdShow) {
    string appName = "OpenGLTriangle";
    WNDCLASSEX wcex;
    wcex.cbSize = WNDCLASSEX.sizeof;
    wcex.style = CS_OWNDC;
    wcex.lpfnWndProc = &WndProc;
    wcex.cbClsExtra = 0;
    wcex.cbWndExtra = 0;
    wcex.hInstance = hInstance;
    wcex.hIcon = LoadIcon(null, IDI_APPLICATION);
    wcex.hCursor = LoadCursor(null, IDC_ARROW);
    wcex.hbrBackground = cast(HBRUSH) GetStockObject(BLACK_BRUSH);
    wcex.lpszMenuName = null;
    wcex.lpszClassName = appName.toUTF16z;
    wcex.hIconSm = LoadIcon(null, IDI_APPLICATION);

    RegisterClassEx(&wcex);

    HWND hwnd = CreateWindowEx(
        0,
        appName.toUTF16z,
        "Hello, World!",
        WS_OVERLAPPEDWINDOW,
        CW_USEDEFAULT,
        CW_USEDEFAULT,
        640,
        480,
        null,
        null,
        hInstance,
        null);

    ShowWindow(hwnd, nCmdShow);

    MSG msg;
    bool quit = false;
    while (!quit) {
        if (PeekMessage(&msg, null, 0, 0, PM_REMOVE)) {
            if (msg.message == WM_QUIT) {
                quit = true;
            } else {
                TranslateMessage(&msg);
                DispatchMessage(&msg);
            }
        } else {
            render();
        }
    }
    return cast(int)msg.wParam;
}
