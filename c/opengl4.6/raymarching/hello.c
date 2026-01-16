#include <windows.h>
#include <tchar.h>
#include <gl/gl.h>

#ifndef APIENTRY
#define APIENTRY
#endif

#ifndef APIENTRYP
#define APIENTRYP APIENTRY *
#endif

#define GL_ARRAY_BUFFER                   0x8892
#define GL_STATIC_DRAW                    0x88E4
#define GL_FRAGMENT_SHADER                0x8B30
#define GL_VERTEX_SHADER                  0x8B31
#define WGL_CONTEXT_MAJOR_VERSION_ARB     0x2091
#define WGL_CONTEXT_MINOR_VERSION_ARB     0x2092
#define WGL_CONTEXT_FLAGS_ARB             0x2094
#define WGL_CONTEXT_PROFILE_MASK_ARB      0x9126
#define WGL_CONTEXT_CORE_PROFILE_BIT_ARB  0x00000001

typedef ptrdiff_t GLsizeiptr;
typedef char GLchar;

typedef void (APIENTRYP PFNGLGENBUFFERSPROC) (GLsizei n, GLuint *buffers);
typedef void (APIENTRYP PFNGLBINDBUFFERPROC) (GLenum target, GLuint buffer);
typedef void (APIENTRYP PFNGLBUFFERDATAPROC) (GLenum target, GLsizeiptr size, const void *data, GLenum usage);
typedef GLuint (APIENTRYP PFNGLCREATESHADERPROC) (GLenum type);
typedef void (APIENTRYP PFNGLSHADERSOURCEPROC) (GLuint shader, GLsizei count, const GLchar* const* string, const GLint* length);
typedef void (APIENTRYP PFNGLCOMPILESHADERPROC) (GLuint shader);
typedef GLuint (APIENTRYP PFNGLCREATEPROGRAMPROC) (void);
typedef void (APIENTRYP PFNGLATTACHSHADERPROC) (GLuint program, GLuint shader);
typedef void (APIENTRYP PFNGLLINKPROGRAMPROC) (GLuint program);
typedef void (APIENTRYP PFNGLUSEPROGRAMPROC) (GLuint program);
typedef GLint (APIENTRYP PFNGLGETATTRIBLOCATIONPROC) (GLuint program, const GLchar *name);
typedef GLint (APIENTRYP PFNGLGETUNIFORMLOCATIONPROC) (GLuint program, const GLchar *name);
typedef void (APIENTRYP PFNGLENABLEVERTEXATTRIBARRAYPROC) (GLuint index);
typedef void (APIENTRYP PFNGLVERTEXATTRIBPOINTERPROC) (GLuint index, GLint size, GLenum type, GLboolean normalized, GLsizei stride, const void *pointer);
typedef void (APIENTRYP PFNGLUNIFORM1FPROC) (GLint location, GLfloat v0);
typedef void (APIENTRYP PFNGLUNIFORM2FPROC) (GLint location, GLfloat v0, GLfloat v1);

typedef HGLRC (WINAPI * PFNWGLCREATECONTEXTATTRIBSARBPROC) (HDC hDC, HGLRC hShareContext, const int *attribList);

PFNGLGENBUFFERSPROC               glGenBuffers;
PFNGLBINDBUFFERPROC               glBindBuffer;
PFNGLBUFFERDATAPROC               glBufferData;
PFNGLCREATESHADERPROC             glCreateShader;
PFNGLSHADERSOURCEPROC             glShaderSource;
PFNGLCOMPILESHADERPROC            glCompileShader;
PFNGLCREATEPROGRAMPROC            glCreateProgram;
PFNGLATTACHSHADERPROC             glAttachShader;
PFNGLLINKPROGRAMPROC              glLinkProgram;
PFNGLUSEPROGRAMPROC               glUseProgram;
PFNGLGETATTRIBLOCATIONPROC        glGetAttribLocation;
PFNGLGETUNIFORMLOCATIONPROC       glGetUniformLocation;
PFNGLENABLEVERTEXATTRIBARRAYPROC  glEnableVertexAttribArray;
PFNGLVERTEXATTRIBPOINTERPROC      glVertexAttribPointer;
PFNGLUNIFORM1FPROC                glUniform1f;
PFNGLUNIFORM2FPROC                glUniform2f;

PFNWGLCREATECONTEXTATTRIBSARBPROC wglCreateContextAttribsARB;


LRESULT CALLBACK WindowProc(HWND hWnd, UINT uMsg, WPARAM wParam, LPARAM lParam);
HGLRC EnableOpenGL(HDC hDC);
void DisableOpenGL(HWND hWnd, HDC hDC, HGLRC hRC);
void InitOpenGLFunc();
void InitShader();
void Render(HWND hWnd);

// Shader sources
const GLchar* vertexSource =
    "#version 460 core                            \n"
    "layout(location = 0) in vec2 position;       \n"
    "out vec2 fragCoord;                          \n"
    "void main()                                  \n"
    "{                                            \n"
    "  fragCoord = position * 0.5 + 0.5;          \n"
    "  gl_Position = vec4(position, 0.0, 1.0);    \n"
    "}                                            \n";

const GLchar* fragmentSource =
    "#version 460 core                                                                              \n"
    "precision highp float;                                                                         \n"
    "                                                                                               \n"
    "in vec2 fragCoord;                                                                             \n"
    "out vec4 outColor;                                                                             \n"
    "                                                                                               \n"
    "uniform float iTime;                                                                           \n"
    "uniform vec2 iResolution;                                                                      \n"
    "                                                                                               \n"
    "const int MAX_STEPS = 100;                                                                     \n"
    "const float MAX_DIST = 100.0;                                                                  \n"
    "const float SURF_DIST = 0.001;                                                                 \n"
    "                                                                                               \n"
    "// Signed Distance Functions                                                                   \n"
    "float sdSphere(vec3 p, float r) {                                                              \n"
    "    return length(p) - r;                                                                      \n"
    "}                                                                                              \n"
    "                                                                                               \n"
    "float sdBox(vec3 p, vec3 b) {                                                                  \n"
    "    vec3 q = abs(p) - b;                                                                       \n"
    "    return length(max(q, 0.0)) + min(max(q.x, max(q.y, q.z)), 0.0);                            \n"
    "}                                                                                              \n"
    "                                                                                               \n"
    "float sdTorus(vec3 p, vec2 t) {                                                                \n"
    "    vec2 q = vec2(length(p.xz) - t.x, p.y);                                                    \n"
    "    return length(q) - t.y;                                                                    \n"
    "}                                                                                              \n"
    "                                                                                               \n"
    "// Smooth minimum for blending shapes                                                          \n"
    "float smin(float a, float b, float k) {                                                        \n"
    "    float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);                                        \n"
    "    return mix(b, a, h) - k * h * (1.0 - h);                                                   \n"
    "}                                                                                              \n"
    "                                                                                               \n"
    "// Scene distance function                                                                     \n"
    "float GetDist(vec3 p) {                                                                        \n"
    "    // Animated sphere                                                                         \n"
    "    float sphere = sdSphere(p - vec3(sin(iTime) * 1.5, 0.5 + sin(iTime * 2.0) * 0.3, 0.0), 0.5);\n"
    "                                                                                               \n"
    "    // Rotating torus                                                                          \n"
    "    float angle = iTime * 0.5;                                                                 \n"
    "    vec3 torusPos = p - vec3(0.0, 0.5, 0.0);                                                   \n"
    "    torusPos.xz = mat2(cos(angle), -sin(angle), sin(angle), cos(angle)) * torusPos.xz;         \n"
    "    torusPos.xy = mat2(cos(angle * 0.7), -sin(angle * 0.7), sin(angle * 0.7), cos(angle * 0.7)) * torusPos.xy;\n"
    "    float torus = sdTorus(torusPos, vec2(0.8, 0.2));                                           \n"
    "                                                                                               \n"
    "    // Ground plane                                                                            \n"
    "    float plane = p.y + 0.5;                                                                   \n"
    "                                                                                               \n"
    "    // Combine with smooth blending                                                            \n"
    "    float d = smin(sphere, torus, 0.3);                                                        \n"
    "    d = min(d, plane);                                                                         \n"
    "                                                                                               \n"
    "    return d;                                                                                  \n"
    "}                                                                                              \n"
    "                                                                                               \n"
    "// Calculate normal using gradient                                                             \n"
    "vec3 GetNormal(vec3 p) {                                                                       \n"
    "    float d = GetDist(p);                                                                      \n"
    "    vec2 e = vec2(0.001, 0.0);                                                                 \n"
    "    vec3 n = d - vec3(                                                                         \n"
    "        GetDist(p - e.xyy),                                                                    \n"
    "        GetDist(p - e.yxy),                                                                    \n"
    "        GetDist(p - e.yyx)                                                                     \n"
    "    );                                                                                         \n"
    "    return normalize(n);                                                                       \n"
    "}                                                                                              \n"
    "                                                                                               \n"
    "// Raymarching                                                                                 \n"
    "float RayMarch(vec3 ro, vec3 rd) {                                                             \n"
    "    float dO = 0.0;                                                                            \n"
    "    for(int i = 0; i < MAX_STEPS; i++) {                                                       \n"
    "        vec3 p = ro + rd * dO;                                                                 \n"
    "        float dS = GetDist(p);                                                                 \n"
    "        dO += dS;                                                                              \n"
    "        if(dO > MAX_DIST || dS < SURF_DIST) break;                                             \n"
    "    }                                                                                          \n"
    "    return dO;                                                                                 \n"
    "}                                                                                              \n"
    "                                                                                               \n"
    "// Soft shadows                                                                                \n"
    "float GetShadow(vec3 ro, vec3 rd, float mint, float maxt, float k) {                           \n"
    "    float res = 1.0;                                                                           \n"
    "    float t = mint;                                                                            \n"
    "    for(int i = 0; i < 64 && t < maxt; i++) {                                                  \n"
    "        float h = GetDist(ro + rd * t);                                                        \n"
    "        if(h < 0.001)                                                                          \n"
    "            return 0.0;                                                                        \n"
    "        res = min(res, k * h / t);                                                             \n"
    "        t += h;                                                                                \n"
    "    }                                                                                          \n"
    "    return res;                                                                                \n"
    "}                                                                                              \n"
    "                                                                                               \n"
    "// Ambient occlusion                                                                           \n"
    "float GetAO(vec3 p, vec3 n) {                                                                  \n"
    "    float occ = 0.0;                                                                           \n"
    "    float sca = 1.0;                                                                           \n"
    "    for(int i = 0; i < 5; i++) {                                                               \n"
    "        float h = 0.01 + 0.12 * float(i) / 4.0;                                                \n"
    "        float d = GetDist(p + h * n);                                                          \n"
    "        occ += (h - d) * sca;                                                                  \n"
    "        sca *= 0.95;                                                                           \n"
    "    }                                                                                          \n"
    "    return clamp(1.0 - 3.0 * occ, 0.0, 1.0);                                                   \n"
    "}                                                                                              \n"
    "                                                                                               \n"
    "void main()                                                                                    \n"
    "{                                                                                              \n"
    "    vec2 uv = fragCoord - 0.5;                                                                 \n"
    "    uv.x *= iResolution.x / iResolution.y;                                                     \n"
    "                                                                                               \n"
    "    // Camera setup                                                                            \n"
    "    vec3 ro = vec3(0.0, 1.5, -4.0);                                                            \n"
    "    vec3 rd = normalize(vec3(uv.x, uv.y, 1.0));                                                \n"
    "                                                                                               \n"
    "    // Light position                                                                          \n"
    "    vec3 lightPos = vec3(3.0, 5.0, -2.0);                                                      \n"
    "                                                                                               \n"
    "    // Raymarching                                                                             \n"
    "    float d = RayMarch(ro, rd);                                                                \n"
    "                                                                                               \n"
    "    vec3 col = vec3(0.0);                                                                      \n"
    "                                                                                               \n"
    "    if(d < MAX_DIST) {                                                                         \n"
    "        vec3 p = ro + rd * d;                                                                  \n"
    "        vec3 n = GetNormal(p);                                                                 \n"
    "        vec3 l = normalize(lightPos - p);                                                      \n"
    "        vec3 v = normalize(ro - p);                                                            \n"
    "        vec3 r = reflect(-l, n);                                                               \n"
    "                                                                                               \n"
    "        // Material color based on position                                                    \n"
    "        vec3 matCol = vec3(0.4, 0.6, 0.9);                                                     \n"
    "        if(p.y < -0.49) {                                                                      \n"
    "            // Checkerboard floor                                                              \n"
    "            float checker = mod(floor(p.x) + floor(p.z), 2.0);                                 \n"
    "            matCol = mix(vec3(0.2), vec3(0.8), checker);                                       \n"
    "        }                                                                                      \n"
    "                                                                                               \n"
    "        // Lighting                                                                            \n"
    "        float diff = max(dot(n, l), 0.0);                                                      \n"
    "        float spec = pow(max(dot(r, v), 0.0), 32.0);                                           \n"
    "        float ao = GetAO(p, n);                                                                \n"
    "        float shadow = GetShadow(p + n * 0.01, l, 0.01, length(lightPos - p), 16.0);           \n"
    "                                                                                               \n"
    "        // Ambient                                                                             \n"
    "        vec3 ambient = vec3(0.1, 0.12, 0.15);                                                  \n"
    "                                                                                               \n"
    "        col = matCol * (ambient * ao + diff * shadow) + vec3(1.0) * spec * shadow * 0.5;       \n"
    "                                                                                               \n"
    "        // Fog                                                                                 \n"
    "        col = mix(col, vec3(0.05, 0.05, 0.1), 1.0 - exp(-0.02 * d * d));                       \n"
    "    } else {                                                                                   \n"
    "        // Background gradient                                                                 \n"
    "        col = mix(vec3(0.1, 0.1, 0.15), vec3(0.02, 0.02, 0.05), fragCoord.y);                  \n"
    "    }                                                                                          \n"
    "                                                                                               \n"
    "    // Gamma correction                                                                        \n"
    "    col = pow(col, vec3(0.4545));                                                              \n"
    "                                                                                               \n"
    "    outColor = vec4(col, 1.0);                                                                 \n"
    "}                                                                                              \n";

GLuint vbo;
GLint posAttrib;
GLint timeLocation;
GLint resolutionLocation;
LARGE_INTEGER startTime;
LARGE_INTEGER frequency;

int APIENTRY _tWinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, LPTSTR lpCmdLine, int nCmdShow)
{
    WNDCLASSEX wcex;
    HWND hWnd;
    HDC hDC;
    HGLRC hRC;
    MSG msg;
    BOOL bQuit = FALSE;

    QueryPerformanceFrequency(&frequency);
    QueryPerformanceCounter(&startTime);

    wcex.cbSize         = sizeof(WNDCLASSEX);
    wcex.style          = CS_OWNDC;
    wcex.lpfnWndProc    = WindowProc;
    wcex.cbClsExtra     = 0;
    wcex.cbWndExtra     = 0;
    wcex.hInstance      = hInstance;
    wcex.hIcon          = LoadIcon(NULL, IDI_APPLICATION);
    wcex.hCursor        = LoadCursor(NULL, IDC_ARROW);
    wcex.hbrBackground  = (HBRUSH)GetStockObject(BLACK_BRUSH);
    wcex.lpszMenuName   = NULL;
    wcex.lpszClassName  = _T("WindowClass");
    wcex.hIconSm        = LoadIcon(NULL, IDI_APPLICATION);

    if (!RegisterClassEx(&wcex))
        return 0;

    hWnd = CreateWindowEx(0,
                          _T("WindowClass"),
                          _T("Raymarching - OpenGL 4.6 / C"),
                          WS_OVERLAPPEDWINDOW,
                          CW_USEDEFAULT,
                          CW_USEDEFAULT,
                          800,
                          600,
                          NULL,
                          NULL,
                          hInstance,
                          NULL);

    ShowWindow(hWnd, nCmdShow);

    hDC = GetDC(hWnd);
    hRC = EnableOpenGL(hDC);
    
    InitOpenGLFunc();
    
    InitShader();

    while (!bQuit)
    {
        if (PeekMessage(&msg, NULL, 0, 0, PM_REMOVE))
        {
            if (msg.message == WM_QUIT)
            {
                bQuit = TRUE;
            }
            else
            {
                TranslateMessage(&msg);
                DispatchMessage(&msg);
            }
        }
        else
        {
            Render(hWnd);

            SwapBuffers(hDC);

            Sleep(1);
        }
    }

    DisableOpenGL(hWnd, hDC, hRC);
    DestroyWindow(hWnd);

    return msg.wParam;
}

LRESULT CALLBACK WindowProc(HWND hWnd, UINT uMsg, WPARAM wParam, LPARAM lParam)
{
    switch (uMsg)
    {
        case WM_CLOSE:
            PostQuitMessage(0);
        break;

        case WM_DESTROY:
            return 0;

        default:
            return DefWindowProc(hWnd, uMsg, wParam, lParam);
    }

    return 0;
}


void InitOpenGLFunc()
{
    glGenBuffers              = (PFNGLGENBUFFERSPROC)              wglGetProcAddress("glGenBuffers");
    glBindBuffer              = (PFNGLBINDBUFFERPROC)              wglGetProcAddress("glBindBuffer");
    glBufferData              = (PFNGLBUFFERDATAPROC)              wglGetProcAddress("glBufferData");
    glCreateShader            = (PFNGLCREATESHADERPROC)            wglGetProcAddress("glCreateShader");
    glShaderSource            = (PFNGLSHADERSOURCEPROC)            wglGetProcAddress("glShaderSource");
    glCompileShader           = (PFNGLCOMPILESHADERPROC)           wglGetProcAddress("glCompileShader");
    glCreateProgram           = (PFNGLCREATEPROGRAMPROC)           wglGetProcAddress("glCreateProgram");
    glAttachShader            = (PFNGLATTACHSHADERPROC)            wglGetProcAddress("glAttachShader");
    glLinkProgram             = (PFNGLLINKPROGRAMPROC)             wglGetProcAddress("glLinkProgram");
    glUseProgram              = (PFNGLUSEPROGRAMPROC)              wglGetProcAddress("glUseProgram");
    glGetAttribLocation       = (PFNGLGETATTRIBLOCATIONPROC)       wglGetProcAddress("glGetAttribLocation");
    glGetUniformLocation      = (PFNGLGETUNIFORMLOCATIONPROC)      wglGetProcAddress("glGetUniformLocation");
    glEnableVertexAttribArray = (PFNGLENABLEVERTEXATTRIBARRAYPROC) wglGetProcAddress("glEnableVertexAttribArray");
    glVertexAttribPointer     = (PFNGLVERTEXATTRIBPOINTERPROC)     wglGetProcAddress("glVertexAttribPointer");
    glUniform1f               = (PFNGLUNIFORM1FPROC)               wglGetProcAddress("glUniform1f");
    glUniform2f               = (PFNGLUNIFORM2FPROC)               wglGetProcAddress("glUniform2f");

    wglCreateContextAttribsARB= (PFNWGLCREATECONTEXTATTRIBSARBPROC)wglGetProcAddress("wglCreateContextAttribsARB");
}

HGLRC EnableOpenGL(HDC hDC)
{
    HGLRC hRC = NULL;
    
    PIXELFORMATDESCRIPTOR pfd;

    int iFormat;

    ZeroMemory(&pfd, sizeof(pfd));

    pfd.nSize = sizeof(pfd);
    pfd.nVersion = 1;
    pfd.dwFlags = PFD_DRAW_TO_WINDOW | PFD_SUPPORT_OPENGL | PFD_DOUBLEBUFFER;
    pfd.iPixelType = PFD_TYPE_RGBA;
    pfd.cColorBits = 24;
    pfd.cDepthBits = 16;
    pfd.iLayerType = PFD_MAIN_PLANE;

    iFormat = ChoosePixelFormat(hDC, &pfd);

    SetPixelFormat(hDC, iFormat, &pfd);

    HGLRC hGLRC_old = wglCreateContext(hDC);
    wglMakeCurrent(hDC, hGLRC_old);

    wglCreateContextAttribsARB = (PFNWGLCREATECONTEXTATTRIBSARBPROC)wglGetProcAddress("wglCreateContextAttribsARB");

    hRC = wglCreateContextAttribsARB(hDC, 0, NULL);

    wglMakeCurrent(hDC, hRC);
    wglDeleteContext(hGLRC_old);

    return hRC;
}

void DisableOpenGL(HWND hWnd, HDC hDC, HGLRC hRC)
{
    wglMakeCurrent(NULL, NULL);
    wglDeleteContext(hRC);
    ReleaseDC(hWnd, hDC);
}

void InitShader()
{
    glGenBuffers(1, &vbo);

    // Fullscreen quad (two triangles)
    GLfloat vertices[] = {
        -1.0f, -1.0f,
         1.0f, -1.0f,
        -1.0f,  1.0f,
        -1.0f,  1.0f,
         1.0f, -1.0f,
         1.0f,  1.0f
    };

    glBindBuffer(GL_ARRAY_BUFFER, vbo);
    glBufferData(GL_ARRAY_BUFFER, sizeof(vertices), vertices, GL_STATIC_DRAW);

    // Create and compile the vertex shader
    GLuint vertexShader = glCreateShader(GL_VERTEX_SHADER);
    glShaderSource(vertexShader, 1, &vertexSource, NULL);
    glCompileShader(vertexShader);

    // Create and compile the fragment shader
    GLuint fragmentShader = glCreateShader(GL_FRAGMENT_SHADER);
    glShaderSource(fragmentShader, 1, &fragmentSource, NULL);
    glCompileShader(fragmentShader);

    // Link the vertex and fragment shader into a shader program
    GLuint shaderProgram = glCreateProgram();
    glAttachShader(shaderProgram, vertexShader);
    glAttachShader(shaderProgram, fragmentShader);
    glLinkProgram(shaderProgram);
    glUseProgram(shaderProgram);

    // Specify the layout of the vertex data
    posAttrib = glGetAttribLocation(shaderProgram, "position");
    glEnableVertexAttribArray(posAttrib);

    // Get uniform locations
    timeLocation = glGetUniformLocation(shaderProgram, "iTime");
    resolutionLocation = glGetUniformLocation(shaderProgram, "iResolution");
}

void Render(HWND hWnd)
{
    RECT rect;
    GetClientRect(hWnd, &rect);
    float width = (float)(rect.right - rect.left);
    float height = (float)(rect.bottom - rect.top);

    LARGE_INTEGER currentTime;
    QueryPerformanceCounter(&currentTime);
    float time = (float)(currentTime.QuadPart - startTime.QuadPart) / (float)frequency.QuadPart;

    glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT);

    // Set uniforms
    glUniform1f(timeLocation, time);
    glUniform2f(resolutionLocation, width, height);

    glBindBuffer(GL_ARRAY_BUFFER, vbo);
    glVertexAttribPointer(posAttrib, 2, GL_FLOAT, GL_FALSE, 0, 0);

    // Draw fullscreen quad (6 vertices for 2 triangles)
    glDrawArrays(GL_TRIANGLES, 0, 6);
}
