/*
 * OpenGL 4.6 Compute Shader Harmonograph (C / Win32 / No external libs)
 *
 * - Creates a Win32 window
 * - Creates an OpenGL 4.6 core profile context via WGL_ARB_create_context
 * - Uses a compute shader to fill SSBOs (positions + colors)
 * - Uses a vertex/fragment shader to render GL_LINE_STRIP from SSBO data
 */

#include <windows.h>
#include <tchar.h>
#include <gl/gl.h>
#include <stdio.h>
#include <stdlib.h>
#include <math.h>

#ifndef APIENTRY
#define APIENTRY
#endif

#ifndef APIENTRYP
#define APIENTRYP APIENTRY *
#endif

/* OpenGL constants */
#define GL_ARRAY_BUFFER                   0x8892
#define GL_SHADER_STORAGE_BUFFER          0x90D2
#define GL_STATIC_DRAW                    0x88E4
#define GL_DYNAMIC_DRAW                   0x88E8
#define GL_FRAGMENT_SHADER                0x8B30
#define GL_VERTEX_SHADER                  0x8B31
#define GL_COMPUTE_SHADER                 0x91B9
#define GL_COMPILE_STATUS                 0x8B81
#define GL_LINK_STATUS                    0x8B82
#define GL_INFO_LOG_LENGTH                0x8B84
#define GL_SHADER_STORAGE_BARRIER_BIT     0x00002000
#define GL_LINE_STRIP                     0x0003
#define GL_TRUE                           1
#define GL_FALSE                          0

/* WGL constants */
#define WGL_CONTEXT_MAJOR_VERSION_ARB     0x2091
#define WGL_CONTEXT_MINOR_VERSION_ARB     0x2092
#define WGL_CONTEXT_FLAGS_ARB             0x2094
#define WGL_CONTEXT_PROFILE_MASK_ARB      0x9126
#define WGL_CONTEXT_CORE_PROFILE_BIT_ARB  0x00000001

typedef ptrdiff_t GLsizeiptr;
typedef char GLchar;
typedef unsigned int GLbitfield;

/* OpenGL function pointer typedefs */
typedef void (APIENTRYP PFNGLGENBUFFERSPROC) (GLsizei n, GLuint *buffers);
typedef void (APIENTRYP PFNGLBINDBUFFERPROC) (GLenum target, GLuint buffer);
typedef void (APIENTRYP PFNGLBUFFERDATAPROC) (GLenum target, GLsizeiptr size, const void *data, GLenum usage);
typedef void (APIENTRYP PFNGLBINDBUFFERBASEPROC) (GLenum target, GLuint index, GLuint buffer);
typedef GLuint (APIENTRYP PFNGLCREATESHADERPROC) (GLenum type);
typedef void (APIENTRYP PFNGLSHADERSOURCEPROC) (GLuint shader, GLsizei count, const GLchar* const* string, const GLint* length);
typedef void (APIENTRYP PFNGLCOMPILESHADERPROC) (GLuint shader);
typedef void (APIENTRYP PFNGLGETSHADERIVPROC) (GLuint shader, GLenum pname, GLint *params);
typedef void (APIENTRYP PFNGLGETSHADERINFOLOGPROC) (GLuint shader, GLsizei bufSize, GLsizei *length, GLchar *infoLog);
typedef void (APIENTRYP PFNGLDELETESHADERPROC) (GLuint shader);
typedef GLuint (APIENTRYP PFNGLCREATEPROGRAMPROC) (void);
typedef void (APIENTRYP PFNGLATTACHSHADERPROC) (GLuint program, GLuint shader);
typedef void (APIENTRYP PFNGLLINKPROGRAMPROC) (GLuint program);
typedef void (APIENTRYP PFNGLUSEPROGRAMPROC) (GLuint program);
typedef void (APIENTRYP PFNGLGETPROGRAMIVPROC) (GLuint program, GLenum pname, GLint *params);
typedef void (APIENTRYP PFNGLGETPROGRAMINFOLOGPROC) (GLuint program, GLsizei bufSize, GLsizei *length, GLchar *infoLog);
typedef GLint (APIENTRYP PFNGLGETUNIFORMLOCATIONPROC) (GLuint program, const GLchar *name);
typedef void (APIENTRYP PFNGLUNIFORM1FPROC) (GLint location, GLfloat v0);
typedef void (APIENTRYP PFNGLUNIFORM2FPROC) (GLint location, GLfloat v0, GLfloat v1);
typedef void (APIENTRYP PFNGLUNIFORM1UIPROC) (GLint location, GLuint v0);
typedef void (APIENTRYP PFNGLGENVERTEXARRAYSPROC) (GLsizei n, GLuint *arrays);
typedef void (APIENTRYP PFNGLBINDVERTEXARRAYPROC) (GLuint array);
typedef void (APIENTRYP PFNGLDISPATCHCOMPUTEPROC) (GLuint num_groups_x, GLuint num_groups_y, GLuint num_groups_z);
typedef void (APIENTRYP PFNGLMEMORYBARRIERPROC) (GLbitfield barriers);
typedef void (APIENTRYP PFNGLDRAWARRAYSPROC) (GLenum mode, GLint first, GLsizei count);

typedef HGLRC (WINAPI * PFNWGLCREATECONTEXTATTRIBSARBPROC) (HDC hDC, HGLRC hShareContext, const int *attribList);

/* Function pointers */
PFNGLGENBUFFERSPROC              glGenBuffers;
PFNGLBINDBUFFERPROC              glBindBuffer;
PFNGLBUFFERDATAPROC              glBufferData;
PFNGLBINDBUFFERBASEPROC          glBindBufferBase;
PFNGLCREATESHADERPROC            glCreateShader;
PFNGLSHADERSOURCEPROC            glShaderSource;
PFNGLCOMPILESHADERPROC           glCompileShader;
PFNGLGETSHADERIVPROC             glGetShaderiv;
PFNGLGETSHADERINFOLOGPROC        glGetShaderInfoLog;
PFNGLDELETESHADERPROC            glDeleteShader;
PFNGLCREATEPROGRAMPROC           glCreateProgram;
PFNGLATTACHSHADERPROC            glAttachShader;
PFNGLLINKPROGRAMPROC             glLinkProgram;
PFNGLUSEPROGRAMPROC              glUseProgram;
PFNGLGETPROGRAMIVPROC            glGetProgramiv;
PFNGLGETPROGRAMINFOLOGPROC       glGetProgramInfoLog;
PFNGLGETUNIFORMLOCATIONPROC      glGetUniformLocation;
PFNGLUNIFORM1FPROC               glUniform1f;
PFNGLUNIFORM2FPROC               glUniform2f;
PFNGLUNIFORM1UIPROC              glUniform1ui;
PFNGLGENVERTEXARRAYSPROC         glGenVertexArrays;
PFNGLBINDVERTEXARRAYPROC         glBindVertexArray;
PFNGLDISPATCHCOMPUTEPROC         glDispatchCompute;
PFNGLMEMORYBARRIERPROC           glMemoryBarrier;
PFNGLDRAWARRAYSPROC              glDrawArraysExt;

PFNWGLCREATECONTEXTATTRIBSARBPROC wglCreateContextAttribsARB;

/* Shader sources */
const GLchar* vertexSource =
    "#version 460 core\n"
    "\n"
    "layout(std430, binding=7) buffer Positions {\n"
    "    vec4 pos[];\n"
    "};\n"
    "\n"
    "layout(std430, binding=8) buffer Colors {\n"
    "    vec4 col[];\n"
    "};\n"
    "\n"
    "uniform vec2 resolution;\n"
    "out vec4 vColor;\n"
    "\n"
    "mat4 perspective(float fov, float aspect, float near, float far)\n"
    "{\n"
    "    float v = 1.0 / tan(radians(fov/2.0));\n"
    "    float u = v / aspect;\n"
    "    float w = near - far;\n"
    "    return mat4(\n"
    "        u, 0, 0, 0,\n"
    "        0, v, 0, 0,\n"
    "        0, 0, (near+far)/w, -1,\n"
    "        0, 0, (near*far*2.0)/w, 0\n"
    "    );\n"
    "}\n"
    "\n"
    "mat4 lookAt(vec3 eye, vec3 center, vec3 up)\n"
    "{\n"
    "    vec3 w = normalize(eye - center);\n"
    "    vec3 u = normalize(cross(up, w));\n"
    "    vec3 v = cross(w, u);\n"
    "    return mat4(\n"
    "        u.x, v.x, w.x, 0,\n"
    "        u.y, v.y, w.y, 0,\n"
    "        u.z, v.z, w.z, 0,\n"
    "        -dot(u, eye), -dot(v, eye), -dot(w, eye), 1\n"
    "    );\n"
    "}\n"
    "\n"
    "void main(void)\n"
    "{\n"
    "    vec4 p = pos[gl_VertexID];\n"
    "\n"
    "    mat4 pMat = perspective(45.0, resolution.x / resolution.y, 0.1, 200.0);\n"
    "    vec3 camera = vec3(0, 5, 10);\n"
    "    vec3 center = vec3(0, 0, 0);\n"
    "    mat4 vMat = lookAt(camera, center, vec3(0,1,0));\n"
    "\n"
    "    gl_Position = pMat * vMat * p;\n"
    "    vColor = col[gl_VertexID];\n"
    "}\n";

const GLchar* fragmentSource =
    "#version 460 core\n"
    "in vec4 vColor;\n"
    "layout(location = 0) out vec4 outColor;\n"
    "void main()\n"
    "{\n"
    "    outColor = vColor;\n"
    "}\n";

const GLchar* computeSource =
    "#version 460 core\n"
    "\n"
    "layout(local_size_x = 64, local_size_y = 1, local_size_z = 1) in;\n"
    "\n"
    "layout(std430, binding=7) buffer Positions {\n"
    "    vec4 pos[];\n"
    "};\n"
    "\n"
    "layout(std430, binding=8) buffer Colors {\n"
    "    vec4 col[];\n"
    "};\n"
    "\n"
    "uniform uint max_num;\n"
    "\n"
    "uniform float A1; uniform float f1; uniform float p1; uniform float d1;\n"
    "uniform float A2; uniform float f2; uniform float p2; uniform float d2;\n"
    "uniform float A3; uniform float f3; uniform float p3; uniform float d3;\n"
    "uniform float A4; uniform float f4; uniform float p4; uniform float d4;\n"
    "\n"
    "vec3 hsv2rgb(float h, float s, float v)\n"
    "{\n"
    "    float c = v * s;\n"
    "    float hp = h / 60.0;\n"
    "    float x = c * (1.0 - abs(mod(hp, 2.0) - 1.0));\n"
    "    vec3 rgb;\n"
    "\n"
    "    if      (hp < 1.0) rgb = vec3(c, x, 0.0);\n"
    "    else if (hp < 2.0) rgb = vec3(x, c, 0.0);\n"
    "    else if (hp < 3.0) rgb = vec3(0.0, c, x);\n"
    "    else if (hp < 4.0) rgb = vec3(0.0, x, c);\n"
    "    else if (hp < 5.0) rgb = vec3(x, 0.0, c);\n"
    "    else               rgb = vec3(c, 0.0, x);\n"
    "\n"
    "    float m = v - c;\n"
    "    return rgb + vec3(m);\n"
    "}\n"
    "\n"
    "void main()\n"
    "{\n"
    "    uint idx = gl_GlobalInvocationID.x;\n"
    "    if (idx >= max_num) return;\n"
    "\n"
    "    float t = float(idx) * 0.001;\n"
    "    float PI = 3.14159265;\n"
    "\n"
    "    float x = A1 * sin(f1 * t + PI * p1) * exp(-d1 * t) +\n"
    "              A2 * sin(f2 * t + PI * p2) * exp(-d2 * t);\n"
    "\n"
    "    float y = A3 * sin(f3 * t + PI * p3) * exp(-d3 * t) +\n"
    "              A4 * sin(f4 * t + PI * p4) * exp(-d4 * t);\n"
    "\n"
    "    float z = A1 * cos(f1 * t + PI * p1) * exp(-d1 * t) +\n"
    "              A2 * cos(f2 * t + PI * p2) * exp(-d2 * t);\n"
    "\n"
    "    pos[idx] = vec4(x, y, z, 1.0);\n"
    "\n"
    "    float hue = mod((t / 20.0) * 360.0, 360.0);\n"
    "    vec3 rgb = hsv2rgb(hue, 1.0, 1.0);\n"
    "    col[idx] = vec4(rgb, 1.0);\n"
    "}\n";

/* Global variables */
#define WIDTH 640
#define HEIGHT 480
#define VERTEX_COUNT 500000

GLuint vao;
GLuint ssboPos, ssboCol;
GLuint drawProgram, computeProgram;

/* Harmonograph parameters */
float A1 = 50.0f, f1 = 2.0f, p1 = 1.0f/16.0f, d1 = 0.02f;
float A2 = 50.0f, f2 = 2.0f, p2 = 3.0f/2.0f,  d2 = 0.0315f;
float A3 = 50.0f, f3 = 2.0f, p3 = 13.0f/15.0f, d3 = 0.02f;
float A4 = 50.0f, f4 = 2.0f, p4 = 1.0f,       d4 = 0.02f;

/* Function declarations */
LRESULT CALLBACK WindowProc(HWND hWnd, UINT uMsg, WPARAM wParam, LPARAM lParam);
HGLRC EnableOpenGL(HDC hDC);
void DisableOpenGL(HWND hWnd, HDC hDC, HGLRC hRC);
void InitOpenGLFunc();
void InitResources();
GLuint CompileShader(GLenum type, const GLchar* source);
GLuint LinkProgram(GLuint* shaders, int count);
void SetUniformF(GLuint prog, const char* name, float v);
void SetUniformU(GLuint prog, const char* name, GLuint v);
void RunCompute();
void Draw();

/* Random number between 0 and 1 */
float randf() {
    return (float)rand() / (float)RAND_MAX;
}

int APIENTRY _tWinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, LPTSTR lpCmdLine, int nCmdShow)
{
    WNDCLASSEX wcex;
    HWND hWnd;
    HDC hDC;
    HGLRC hRC;
    MSG msg;
    BOOL bQuit = FALSE;
    const float PI2 = 6.283185307179586f;
    DWORD startTime, currentTime;
    int frameCount = 0;
    float fps = 0.0f;
    DWORD lastFpsTime;
    char titleBuffer[256];

    srand((unsigned int)GetTickCount());

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
    wcex.lpszClassName  = _T("HarmonographClass");
    wcex.hIconSm        = LoadIcon(NULL, IDI_APPLICATION);

    if (!RegisterClassEx(&wcex))
        return 0;

    hWnd = CreateWindowEx(0,
                          _T("HarmonographClass"),
                          _T("OpenGL 4.6 Compute Harmonograph"),
                          WS_OVERLAPPEDWINDOW,
                          CW_USEDEFAULT,
                          CW_USEDEFAULT,
                          WIDTH,
                          HEIGHT,
                          NULL,
                          NULL,
                          hInstance,
                          NULL);

    ShowWindow(hWnd, nCmdShow);

    hDC = GetDC(hWnd);
    hRC = EnableOpenGL(hDC);
    
    InitOpenGLFunc();
    InitResources();

    startTime = GetTickCount();
    lastFpsTime = startTime;

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
            currentTime = GetTickCount();
            
            /* Exit after 60 seconds */
            if (currentTime - startTime > 60000)
            {
                bQuit = TRUE;
                continue;
            }

            /* Animate parameters */
            f1 = fmodf(f1 + randf() / 40.0f, 10.0f);
            f2 = fmodf(f2 + randf() / 40.0f, 10.0f);
            f3 = fmodf(f3 + randf() / 40.0f, 10.0f);
            f4 = fmodf(f4 + randf() / 40.0f, 10.0f);
            p1 += (PI2 * 0.5f / 360.0f);

            /* Run compute shader */
            RunCompute();

            /* Clear and draw */
            glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
            glClear(GL_COLOR_BUFFER_BIT);
            Draw();

            SwapBuffers(hDC);

            /* FPS calculation */
            frameCount++;
            if (currentTime - lastFpsTime >= 1000)
            {
                fps = (float)frameCount * 1000.0f / (float)(currentTime - lastFpsTime);
                frameCount = 0;
                lastFpsTime = currentTime;
                sprintf(titleBuffer, "OpenGL 4.6 Compute Harmonograph - FPS: %.1f", fps);
                SetWindowTextA(hWnd, titleBuffer);
            }

            Sleep(1);
        }
    }

    DisableOpenGL(hWnd, hDC, hRC);
    DestroyWindow(hWnd);

    return (int)msg.wParam;
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

        case WM_KEYDOWN:
            if (wParam == VK_ESCAPE)
                PostQuitMessage(0);
            break;

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
    glBindBufferBase          = (PFNGLBINDBUFFERBASEPROC)          wglGetProcAddress("glBindBufferBase");
    glCreateShader            = (PFNGLCREATESHADERPROC)            wglGetProcAddress("glCreateShader");
    glShaderSource            = (PFNGLSHADERSOURCEPROC)            wglGetProcAddress("glShaderSource");
    glCompileShader           = (PFNGLCOMPILESHADERPROC)           wglGetProcAddress("glCompileShader");
    glGetShaderiv             = (PFNGLGETSHADERIVPROC)             wglGetProcAddress("glGetShaderiv");
    glGetShaderInfoLog        = (PFNGLGETSHADERINFOLOGPROC)        wglGetProcAddress("glGetShaderInfoLog");
    glDeleteShader            = (PFNGLDELETESHADERPROC)            wglGetProcAddress("glDeleteShader");
    glCreateProgram           = (PFNGLCREATEPROGRAMPROC)           wglGetProcAddress("glCreateProgram");
    glAttachShader            = (PFNGLATTACHSHADERPROC)            wglGetProcAddress("glAttachShader");
    glLinkProgram             = (PFNGLLINKPROGRAMPROC)             wglGetProcAddress("glLinkProgram");
    glUseProgram              = (PFNGLUSEPROGRAMPROC)              wglGetProcAddress("glUseProgram");
    glGetProgramiv            = (PFNGLGETPROGRAMIVPROC)            wglGetProcAddress("glGetProgramiv");
    glGetProgramInfoLog       = (PFNGLGETPROGRAMINFOLOGPROC)       wglGetProcAddress("glGetProgramInfoLog");
    glGetUniformLocation      = (PFNGLGETUNIFORMLOCATIONPROC)      wglGetProcAddress("glGetUniformLocation");
    glUniform1f               = (PFNGLUNIFORM1FPROC)               wglGetProcAddress("glUniform1f");
    glUniform2f               = (PFNGLUNIFORM2FPROC)               wglGetProcAddress("glUniform2f");
    glUniform1ui              = (PFNGLUNIFORM1UIPROC)              wglGetProcAddress("glUniform1ui");
    glGenVertexArrays         = (PFNGLGENVERTEXARRAYSPROC)         wglGetProcAddress("glGenVertexArrays");
    glBindVertexArray         = (PFNGLBINDVERTEXARRAYPROC)         wglGetProcAddress("glBindVertexArray");
    glDispatchCompute         = (PFNGLDISPATCHCOMPUTEPROC)         wglGetProcAddress("glDispatchCompute");
    glMemoryBarrier           = (PFNGLMEMORYBARRIERPROC)           wglGetProcAddress("glMemoryBarrier");
    glDrawArraysExt           = (PFNGLDRAWARRAYSPROC)              wglGetProcAddress("glDrawArrays");

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
    pfd.cDepthBits = 24;
    pfd.iLayerType = PFD_MAIN_PLANE;

    iFormat = ChoosePixelFormat(hDC, &pfd);
    SetPixelFormat(hDC, iFormat, &pfd);

    /* Create legacy context first */
    HGLRC hGLRC_old = wglCreateContext(hDC);
    wglMakeCurrent(hDC, hGLRC_old);

    /* Load wglCreateContextAttribsARB */
    wglCreateContextAttribsARB = (PFNWGLCREATECONTEXTATTRIBSARBPROC)wglGetProcAddress("wglCreateContextAttribsARB");

    /* Create OpenGL 4.6 core profile context */
    static const int attribs[] = {
        WGL_CONTEXT_MAJOR_VERSION_ARB, 4,
        WGL_CONTEXT_MINOR_VERSION_ARB, 6,
        WGL_CONTEXT_FLAGS_ARB, 0,
        WGL_CONTEXT_PROFILE_MASK_ARB, WGL_CONTEXT_CORE_PROFILE_BIT_ARB,
        0
    };

    hRC = wglCreateContextAttribsARB(hDC, 0, attribs);
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

GLuint CompileShader(GLenum type, const GLchar* source)
{
    GLuint shader = glCreateShader(type);
    GLint status;
    
    glShaderSource(shader, 1, &source, NULL);
    glCompileShader(shader);
    
    glGetShaderiv(shader, GL_COMPILE_STATUS, &status);
    if (status != GL_TRUE)
    {
        GLint logLen;
        glGetShaderiv(shader, GL_INFO_LOG_LENGTH, &logLen);
        if (logLen > 1)
        {
            char* log = (char*)malloc(logLen);
            glGetShaderInfoLog(shader, logLen, NULL, log);
            MessageBoxA(NULL, log, "Shader Compile Error", MB_OK | MB_ICONERROR);
            free(log);
        }
        return 0;
    }
    
    return shader;
}

GLuint LinkProgram(GLuint* shaders, int count)
{
    GLuint program = glCreateProgram();
    GLint status;
    int i;
    
    for (i = 0; i < count; i++)
    {
        glAttachShader(program, shaders[i]);
    }
    
    glLinkProgram(program);
    
    glGetProgramiv(program, GL_LINK_STATUS, &status);
    if (status != GL_TRUE)
    {
        GLint logLen;
        glGetProgramiv(program, GL_INFO_LOG_LENGTH, &logLen);
        if (logLen > 1)
        {
            char* log = (char*)malloc(logLen);
            glGetProgramInfoLog(program, logLen, NULL, log);
            MessageBoxA(NULL, log, "Program Link Error", MB_OK | MB_ICONERROR);
            free(log);
        }
        return 0;
    }
    
    /* Delete shaders after linking */
    for (i = 0; i < count; i++)
    {
        glDeleteShader(shaders[i]);
    }
    
    return program;
}

void InitResources()
{
    GLuint shaders[2];
    GLint loc;
    
    /* Create VAO (required for core profile) */
    glGenVertexArrays(1, &vao);
    glBindVertexArray(vao);
    
    /* Create SSBO for positions: vec4 * VERTEX_COUNT (16 bytes each) */
    glGenBuffers(1, &ssboPos);
    glBindBuffer(GL_SHADER_STORAGE_BUFFER, ssboPos);
    glBufferData(GL_SHADER_STORAGE_BUFFER, 16 * VERTEX_COUNT, NULL, GL_DYNAMIC_DRAW);
    glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 7, ssboPos);
    
    /* Create SSBO for colors: vec4 * VERTEX_COUNT (16 bytes each) */
    glGenBuffers(1, &ssboCol);
    glBindBuffer(GL_SHADER_STORAGE_BUFFER, ssboCol);
    glBufferData(GL_SHADER_STORAGE_BUFFER, 16 * VERTEX_COUNT, NULL, GL_DYNAMIC_DRAW);
    glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 8, ssboCol);
    
    /* Build draw program (VS + FS) */
    shaders[0] = CompileShader(GL_VERTEX_SHADER, vertexSource);
    shaders[1] = CompileShader(GL_FRAGMENT_SHADER, fragmentSource);
    drawProgram = LinkProgram(shaders, 2);
    
    /* Set resolution uniform */
    glUseProgram(drawProgram);
    loc = glGetUniformLocation(drawProgram, "resolution");
    if (loc >= 0)
    {
        glUniform2f(loc, (float)WIDTH, (float)HEIGHT);
    }
    
    /* Build compute program (CS) */
    shaders[0] = CompileShader(GL_COMPUTE_SHADER, computeSource);
    computeProgram = LinkProgram(shaders, 1);
}

void SetUniformF(GLuint prog, const char* name, float v)
{
    GLint loc = glGetUniformLocation(prog, name);
    if (loc >= 0)
    {
        glUniform1f(loc, v);
    }
}

void SetUniformU(GLuint prog, const char* name, GLuint v)
{
    GLint loc = glGetUniformLocation(prog, name);
    if (loc >= 0)
    {
        glUniform1ui(loc, v);
    }
}

void RunCompute()
{
    GLuint groupsX = (VERTEX_COUNT + 63) / 64;
    
    glUseProgram(computeProgram);
    
    SetUniformU(computeProgram, "max_num", VERTEX_COUNT);
    
    SetUniformF(computeProgram, "A1", A1);
    SetUniformF(computeProgram, "f1", f1);
    SetUniformF(computeProgram, "p1", p1);
    SetUniformF(computeProgram, "d1", d1);
    
    SetUniformF(computeProgram, "A2", A2);
    SetUniformF(computeProgram, "f2", f2);
    SetUniformF(computeProgram, "p2", p2);
    SetUniformF(computeProgram, "d2", d2);
    
    SetUniformF(computeProgram, "A3", A3);
    SetUniformF(computeProgram, "f3", f3);
    SetUniformF(computeProgram, "p3", p3);
    SetUniformF(computeProgram, "d3", d3);
    
    SetUniformF(computeProgram, "A4", A4);
    SetUniformF(computeProgram, "f4", f4);
    SetUniformF(computeProgram, "p4", p4);
    SetUniformF(computeProgram, "d4", d4);
    
    glDispatchCompute(groupsX, 1, 1);
    glMemoryBarrier(GL_SHADER_STORAGE_BARRIER_BIT);
}

void Draw()
{
    glUseProgram(drawProgram);
    glBindVertexArray(vao);
    glDrawArrays(GL_LINE_STRIP, 0, VERTEX_COUNT);
}
