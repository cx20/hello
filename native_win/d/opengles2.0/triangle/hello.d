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
    alias GLubyte = ubyte;
    alias GLsizeiptr = ptrdiff_t;

    void glDrawArrays(GLenum mode, GLint first, GLsizei count);
    void glClear(GLbitfield mask);
    void glClearColor(GLfloat red, GLfloat green, GLfloat blue, GLfloat alpha);
    const(GLubyte)* glGetString(GLenum name);

    enum GL_VERTEX_SHADER = 0x8B31;
    enum GL_FRAGMENT_SHADER = 0x8B30;
    enum GL_FLOAT = 0x1406;
    enum GL_TRIANGLES = 0x0004;
    enum GL_ARRAY_BUFFER = 0x8892;
    enum GL_STATIC_DRAW = 0x88E4;
    enum GL_COLOR_BUFFER_BIT = 0x4000;
    enum GL_FALSE = 0;
    enum GL_SHADING_LANGUAGE_VERSION = 0x8B8C;

    enum WGL_CONTEXT_MAJOR_VERSION_ARB = 0x2091;
    enum WGL_CONTEXT_MINOR_VERSION_ARB = 0x2092;
    enum WGL_CONTEXT_FLAGS_ARB = 0x2094;
    enum WGL_CONTEXT_PROFILE_MASK_ARB = 0x9126;
    enum WGL_CONTEXT_ES2_PROFILE_BIT_EXT = 0x00000004;

    void* wglGetProcAddress(const GLchar* name);
}

extern(System) {
    alias glGenBuffersFunc = void function(GLsizei n, GLuint* buffers);
    alias glBindBufferFunc = void function(GLenum target, GLuint buffer);
    alias glBufferDataFunc = void function(GLenum target, GLsizeiptr size, const void* data, GLenum usage);
    alias glCreateShaderFunc = GLuint function(GLenum shaderType);
    alias glShaderSourceFunc = void function(GLuint shader, GLsizei count, const GLchar** string, const GLint* length);
    alias glCompileShaderFunc = void function(GLuint shader);
    alias glCreateProgramFunc = GLuint function();
    alias glAttachShaderFunc = void function(GLuint program, GLuint shader);
    alias glLinkProgramFunc = void function(GLuint program);
    alias glUseProgramFunc = void function(GLuint program);
    alias glGetAttribLocationFunc = GLint function(GLuint program, const GLchar* name);
    alias glEnableVertexAttribArrayFunc = void function(GLuint index);
    alias glVertexAttribPointerFunc = void function(GLuint index, GLint size, GLenum type, GLboolean normalized, GLsizei stride, const void* pointer);
    alias wglCreateContextAttribsARBFunc = HGLRC function(HDC hDC, HGLRC hShareContext, const int* attribList);
}

glGenBuffersFunc glGenBuffers;
glBindBufferFunc glBindBuffer;
glBufferDataFunc glBufferData;
glCreateShaderFunc glCreateShader;
glShaderSourceFunc glShaderSource;
glCompileShaderFunc glCompileShader;
glCreateProgramFunc glCreateProgram;
glAttachShaderFunc glAttachShader;
glLinkProgramFunc glLinkProgram;
glUseProgramFunc glUseProgram;
glGetAttribLocationFunc glGetAttribLocation;
glEnableVertexAttribArrayFunc glEnableVertexAttribArray;
glVertexAttribPointerFunc glVertexAttribPointer;
wglCreateContextAttribsARBFunc wglCreateContextAttribsARB;

// Shader sources for OpenGL ES 2.0.
immutable(GLchar)[] vertexSource =
    "attribute vec3 position;                     \n" ~
    "attribute vec3 color;                        \n" ~
    "varying   vec4 vColor;                       \n" ~
    "void main()                                  \n" ~
    "{                                            \n" ~
    "  vColor = vec4(color, 1.0);                 \n" ~
    "  gl_Position = vec4(position, 1.0);         \n" ~
    "}                                            \n";

immutable(GLchar)[] fragmentSource =
    "precision mediump float;                     \n" ~
    "varying   vec4 vColor;                       \n" ~
    "void main()                                  \n" ~
    "{                                            \n" ~
    "  gl_FragColor = vColor;                     \n" ~
    "}                                            \n";

static GLuint[2] gVbo;
static GLint gPosAttrib;
static GLint gColAttrib;
static HDC gHdc;
static HGLRC gHglrc;

auto toUTF16z(S)(S s) {
    return cast(const(wchar)*)s.ptr;
}

void initOpenGLFunc() {
    glGenBuffers = cast(glGenBuffersFunc) wglGetProcAddress("glGenBuffers");
    glBindBuffer = cast(glBindBufferFunc) wglGetProcAddress("glBindBuffer");
    glBufferData = cast(glBufferDataFunc) wglGetProcAddress("glBufferData");
    glCreateShader = cast(glCreateShaderFunc) wglGetProcAddress("glCreateShader");
    glShaderSource = cast(glShaderSourceFunc) wglGetProcAddress("glShaderSource");
    glCompileShader = cast(glCompileShaderFunc) wglGetProcAddress("glCompileShader");
    glCreateProgram = cast(glCreateProgramFunc) wglGetProcAddress("glCreateProgram");
    glAttachShader = cast(glAttachShaderFunc) wglGetProcAddress("glAttachShader");
    glLinkProgram = cast(glLinkProgramFunc) wglGetProcAddress("glLinkProgram");
    glUseProgram = cast(glUseProgramFunc) wglGetProcAddress("glUseProgram");
    glGetAttribLocation = cast(glGetAttribLocationFunc) wglGetProcAddress("glGetAttribLocation");
    glEnableVertexAttribArray = cast(glEnableVertexAttribArrayFunc) wglGetProcAddress("glEnableVertexAttribArray");
    glVertexAttribPointer = cast(glVertexAttribPointerFunc) wglGetProcAddress("glVertexAttribPointer");
}

HGLRC enableOpenGLES20(HDC hdc) {
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

    // Create a temporary context first to load wglCreateContextAttribsARB.
    HGLRC oldContext = wglCreateContext(hdc);
    wglMakeCurrent(hdc, oldContext);

    wglCreateContextAttribsARB = cast(wglCreateContextAttribsARBFunc) wglGetProcAddress("wglCreateContextAttribsARB");

    int[9] opengles20 = [
        WGL_CONTEXT_MAJOR_VERSION_ARB, 2,
        WGL_CONTEXT_MINOR_VERSION_ARB, 0,
        WGL_CONTEXT_FLAGS_ARB, 0,
        WGL_CONTEXT_PROFILE_MASK_ARB, WGL_CONTEXT_ES2_PROFILE_BIT_EXT,
        0
    ];

    HGLRC context = wglCreateContextAttribsARB(hdc, null, opengles20.ptr);
    wglMakeCurrent(hdc, context);
    wglDeleteContext(oldContext);

    return context;
}

void initShader() {
    glGenBuffers(2, gVbo.ptr);

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

    glBindBuffer(GL_ARRAY_BUFFER, gVbo[0]);
    glBufferData(GL_ARRAY_BUFFER, cast(GLsizeiptr)vertices.sizeof, vertices.ptr, GL_STATIC_DRAW);

    glBindBuffer(GL_ARRAY_BUFFER, gVbo[1]);
    glBufferData(GL_ARRAY_BUFFER, cast(GLsizeiptr)colors.sizeof, colors.ptr, GL_STATIC_DRAW);

    // Create and compile the vertex shader.
    GLuint vertexShader = glCreateShader(GL_VERTEX_SHADER);
    const GLchar* vs = cast(const GLchar*)vertexSource.ptr;
    glShaderSource(vertexShader, 1, &vs, null);
    glCompileShader(vertexShader);

    // Create and compile the fragment shader.
    GLuint fragmentShader = glCreateShader(GL_FRAGMENT_SHADER);
    const GLchar* fs = cast(const GLchar*)fragmentSource.ptr;
    glShaderSource(fragmentShader, 1, &fs, null);
    glCompileShader(fragmentShader);

    // Link shaders into one program and enable the attributes.
    GLuint shaderProgram = glCreateProgram();
    glAttachShader(shaderProgram, vertexShader);
    glAttachShader(shaderProgram, fragmentShader);
    glLinkProgram(shaderProgram);
    glUseProgram(shaderProgram);

    gPosAttrib = glGetAttribLocation(shaderProgram, "position");
    glEnableVertexAttribArray(cast(GLuint)gPosAttrib);

    gColAttrib = glGetAttribLocation(shaderProgram, "color");
    glEnableVertexAttribArray(cast(GLuint)gColAttrib);
}

void drawTriangle() {
    glBindBuffer(GL_ARRAY_BUFFER, gVbo[0]);
    glVertexAttribPointer(cast(GLuint)gPosAttrib, 3, GL_FLOAT, GL_FALSE, 0, null);

    glBindBuffer(GL_ARRAY_BUFFER, gVbo[1]);
    glVertexAttribPointer(cast(GLuint)gColAttrib, 3, GL_FLOAT, GL_FALSE, 0, null);

    glDrawArrays(GL_TRIANGLES, 0, 3);
}

void render() {
    glClearColor(0.0f, 0.0f, 0.0f, 0.0f);
    glClear(GL_COLOR_BUFFER_BIT);
    drawTriangle();
    SwapBuffers(gHdc);
}

extern (Windows)
LRESULT WndProc(HWND hwnd, UINT message, WPARAM wParam, LPARAM lParam) nothrow {
    try {
        switch (message) {
            case WM_CREATE:
                gHdc = GetDC(hwnd);
                gHglrc = enableOpenGLES20(gHdc);
                initOpenGLFunc();
                initShader();
                glGetString(GL_SHADING_LANGUAGE_VERSION);
                return 0;

            case WM_DESTROY:
                wglMakeCurrent(null, null);
                if (gHglrc !is null) {
                    wglDeleteContext(gHglrc);
                }
                if (gHdc !is null) {
                    ReleaseDC(hwnd, gHdc);
                }
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
    string appName = "OpenGLES20Triangle";
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
            Sleep(1);
        }
    }
    return cast(int)msg.wParam;
}
