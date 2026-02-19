// hello_dcomp_gl.cpp - OpenGL 4.6 Triangle via DirectComposition
//
// Build (Visual Studio Developer Command Prompt):
//   cl /EHsc hello_dcomp_gl.cpp /link d3d11.lib dxgi.lib dcomp.lib opengl32.lib user32.lib gdi32.lib
//
// Architecture:
//   [GL DrawArrays] -> [GL Renderbuffer (shared)] -> [D3D11 BackBuffer]
//       -> [SwapChain Present] -> [DComp Visual] -> [DWM] -> [Display]
//
// The key technology is WGL_NV_DX_interop2, which allows OpenGL and D3D11
// to share the same GPU texture with zero-copy. GL renders into a
// renderbuffer that IS the D3D11 swap chain back buffer.
//
// Requirements:
//   - Windows 8 or later (for DirectComposition)
//   - GPU driver supporting WGL_NV_DX_interop / WGL_NV_DX_interop2
//     (available on NVIDIA, AMD, and Intel drivers)
//
// Debug output: OutputDebugString - monitor with DebugView (SysInternals)

#include <windows.h>
#include <tchar.h>
#include <d3d11.h>
#include <dxgi1_2.h>
#include <dcomp.h>
#include <gl/gl.h>
#include <cstdio>
#include <cstdarg>

#pragma comment(lib, "d3d11.lib")
#pragma comment(lib, "dxgi.lib")
#pragma comment(lib, "dcomp.lib")
#pragma comment(lib, "opengl32.lib")
#pragma comment(lib, "user32.lib")
#pragma comment(lib, "gdi32.lib")

// ============================================================
// Debug output helper - sends formatted text to DebugView
// ============================================================
static void dbg(const char* fmt, ...) {
    char buf[1024];
    va_list args;
    va_start(args, fmt);
    vsnprintf(buf, sizeof(buf), fmt, args);
    va_end(args);
    OutputDebugStringA(buf);
}

// ============================================================
// OpenGL type definitions and constants (same as hello.cpp)
// ============================================================
#ifndef APIENTRY
#define APIENTRY
#endif
#ifndef APIENTRYP
#define APIENTRYP APIENTRY *
#endif

typedef ptrdiff_t GLsizeiptr;
typedef char      GLchar;

#define GL_ARRAY_BUFFER                   0x8892
#define GL_STATIC_DRAW                    0x88E4
#define GL_FRAGMENT_SHADER                0x8B30
#define GL_VERTEX_SHADER                  0x8B31
#define GL_FRAMEBUFFER                    0x8D40
#define GL_RENDERBUFFER                   0x8D41
#define GL_COLOR_ATTACHMENT0              0x8CE0
#define GL_FRAMEBUFFER_COMPLETE           0x8CD5
#define GL_COMPILE_STATUS                 0x8B81
#define GL_LINK_STATUS                    0x8B82

// WGL_ARB_create_context
#define WGL_CONTEXT_MAJOR_VERSION_ARB     0x2091
#define WGL_CONTEXT_MINOR_VERSION_ARB     0x2092
#define WGL_CONTEXT_FLAGS_ARB             0x2094
#define WGL_CONTEXT_PROFILE_MASK_ARB      0x9126
#define WGL_CONTEXT_CORE_PROFILE_BIT_ARB  0x00000001

// WGL_NV_DX_interop
#define WGL_ACCESS_READ_WRITE_NV          0x0001

// ============================================================
// GL function pointer types (same as hello.cpp + FBO/RBO additions)
// ============================================================
typedef void   (APIENTRYP PFNGLGENBUFFERSPROC)(GLsizei, GLuint*);
typedef void   (APIENTRYP PFNGLBINDBUFFERPROC)(GLenum, GLuint);
typedef void   (APIENTRYP PFNGLBUFFERDATAPROC)(GLenum, GLsizeiptr, const void*, GLenum);
typedef GLuint (APIENTRYP PFNGLCREATESHADERPROC)(GLenum);
typedef void   (APIENTRYP PFNGLSHADERSOURCEPROC)(GLuint, GLsizei, const GLchar* const*, const GLint*);
typedef void   (APIENTRYP PFNGLCOMPILESHADERPROC)(GLuint);
typedef GLuint (APIENTRYP PFNGLCREATEPROGRAMPROC)(void);
typedef void   (APIENTRYP PFNGLATTACHSHADERPROC)(GLuint, GLuint);
typedef void   (APIENTRYP PFNGLLINKPROGRAMPROC)(GLuint);
typedef void   (APIENTRYP PFNGLUSEPROGRAMPROC)(GLuint);
typedef GLint  (APIENTRYP PFNGLGETATTRIBLOCATIONPROC)(GLuint, const GLchar*);
typedef void   (APIENTRYP PFNGLENABLEVERTEXATTRIBARRAYPROC)(GLuint);
typedef void   (APIENTRYP PFNGLVERTEXATTRIBPOINTERPROC)(GLuint, GLint, GLenum, GLboolean, GLsizei, const void*);
typedef void   (APIENTRYP PFNGLGETSHADERIVPROC)(GLuint, GLenum, GLint*);
typedef void   (APIENTRYP PFNGLGETSHADERINFOLOGPROC)(GLuint, GLsizei, GLsizei*, GLchar*);
typedef void   (APIENTRYP PFNGLGETPROGRAMIVPROC)(GLuint, GLenum, GLint*);
typedef void   (APIENTRYP PFNGLGETPROGRAMINFOLOGPROC)(GLuint, GLsizei, GLsizei*, GLchar*);
typedef void   (APIENTRYP PFNGLGENFRAMEBUFFERSPROC)(GLsizei, GLuint*);
typedef void   (APIENTRYP PFNGLBINDFRAMEBUFFERPROC)(GLenum, GLuint);
typedef void   (APIENTRYP PFNGLFRAMEBUFFERRENDERBUFFERPROC)(GLenum, GLenum, GLenum, GLuint);
typedef GLenum (APIENTRYP PFNGLCHECKFRAMEBUFFERSTATUSPROC)(GLenum);
typedef void   (APIENTRYP PFNGLGENRENDERBUFFERSPROC)(GLsizei, GLuint*);
typedef void   (APIENTRYP PFNGLBINDRENDERBUFFERPROC)(GLenum, GLuint);
typedef void   (APIENTRYP PFNGLDELETEFRAMEBUFFERSPROC)(GLsizei, const GLuint*);
typedef void   (APIENTRYP PFNGLDELETERENDERBUFFERSPROC)(GLsizei, const GLuint*);
typedef void   (APIENTRYP PFNGLDELETEBUFFERSPROC)(GLsizei, const GLuint*);
typedef void   (APIENTRYP PFNGLGENVERTEXARRAYSPROC)(GLsizei, GLuint*);
typedef void   (APIENTRYP PFNGLBINDVERTEXARRAYPROC)(GLuint);

// WGL function pointer types
typedef HGLRC  (WINAPI * PFNWGLCREATECONTEXTATTRIBSARBPROC)(HDC, HGLRC, const int*);
typedef HANDLE (WINAPI * PFNWGLDXOPENDEVICENVPROC)(void*);
typedef BOOL   (WINAPI * PFNWGLDXCLOSEDEVICENVPROC)(HANDLE);
typedef HANDLE (WINAPI * PFNWGLDXREGISTEROBJECTNVPROC)(HANDLE, void*, GLuint, GLenum, GLenum);
typedef BOOL   (WINAPI * PFNWGLDXUNREGISTEROBJECTNVPROC)(HANDLE, HANDLE);
typedef BOOL   (WINAPI * PFNWGLDXLOCKOBJECTSNVPROC)(HANDLE, GLint, HANDLE*);
typedef BOOL   (WINAPI * PFNWGLDXUNLOCKOBJECTSNVPROC)(HANDLE, GLint, HANDLE*);

// ============================================================
// GL function pointers (same as hello.cpp + FBO/RBO/DX-interop additions)
// ============================================================
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
PFNGLENABLEVERTEXATTRIBARRAYPROC  glEnableVertexAttribArray;
PFNGLVERTEXATTRIBPOINTERPROC     glVertexAttribPointer;
PFNGLGETSHADERIVPROC              glGetShaderiv;
PFNGLGETSHADERINFOLOGPROC         glGetShaderInfoLog;
PFNGLGETPROGRAMIVPROC             glGetProgramiv;
PFNGLGETPROGRAMINFOLOGPROC        glGetProgramInfoLog;
PFNGLGENFRAMEBUFFERSPROC          glGenFramebuffers;
PFNGLBINDFRAMEBUFFERPROC          glBindFramebuffer;
PFNGLFRAMEBUFFERRENDERBUFFERPROC  glFramebufferRenderbuffer;
PFNGLCHECKFRAMEBUFFERSTATUSPROC   glCheckFramebufferStatus;
PFNGLGENRENDERBUFFERSPROC         glGenRenderbuffers;
PFNGLBINDRENDERBUFFERPROC         glBindRenderbuffer;
PFNGLDELETEFRAMEBUFFERSPROC       glDeleteFramebuffers;
PFNGLDELETERENDERBUFFERSPROC      glDeleteRenderbuffers;
PFNGLDELETEBUFFERSPROC            glDeleteBuffers;
PFNGLGENVERTEXARRAYSPROC          glGenVertexArrays;
PFNGLBINDVERTEXARRAYPROC          glBindVertexArray;

PFNWGLCREATECONTEXTATTRIBSARBPROC wglCreateContextAttribsARB;
PFNWGLDXOPENDEVICENVPROC          wglDXOpenDeviceNV;
PFNWGLDXCLOSEDEVICENVPROC         wglDXCloseDeviceNV;
PFNWGLDXREGISTEROBJECTNVPROC      wglDXRegisterObjectNV;
PFNWGLDXUNREGISTEROBJECTNVPROC    wglDXUnregisterObjectNV;
PFNWGLDXLOCKOBJECTSNVPROC         wglDXLockObjectsNV;
PFNWGLDXUNLOCKOBJECTSNVPROC       wglDXUnlockObjectsNV;

// ============================================================
// Constants
// ============================================================
static const int WIDTH  = 640;
static const int HEIGHT = 480;

// ============================================================
// Shader sources (same as hello.cpp)
// ============================================================
const GLchar* vertexSource =
    "#version 460 core                            \n"
    "layout(location = 0) in  vec3 position;      \n"
    "layout(location = 1) in  vec3 color;         \n"
    "out vec4 vColor;                             \n"
    "void main()                                  \n"
    "{                                            \n"
    "  vColor = vec4(color, 1.0);                 \n"
    "  gl_Position = vec4(position.x, -position.y, position.z, 1.0); \n"
    "}                                            \n";

const GLchar* fragmentSource =
    "#version 460 core                            \n"
    "precision mediump float;                     \n"
    "in  vec4 vColor;                             \n"
    "out vec4 outColor;                           \n"
    "void main()                                  \n"
    "{                                            \n"
    "  outColor = vColor;                         \n"
    "}                                            \n";

// ============================================================
// Global state
// ============================================================

// GL vertex data (same as hello.cpp)
GLuint vbo[2];
GLint  posAttrib;
GLint  colAttrib;
GLuint shaderProgram;
GLuint vao;

// D3D11
ID3D11Device*           g_d3dDevice   = nullptr;
ID3D11DeviceContext*    g_d3dContext  = nullptr;
IDXGISwapChain1*        g_swapChain   = nullptr;
ID3D11Texture2D*        g_backBuffer  = nullptr;

// DirectComposition
IDCompositionDevice*    g_dcompDevice = nullptr;
IDCompositionTarget*    g_dcompTarget = nullptr;
IDCompositionVisual*    g_dcompVisual = nullptr;

// WGL_NV_DX_interop state
HANDLE g_hInteropDevice = nullptr;
HANDLE g_hInteropObject = nullptr;
GLuint g_glRenderbuffer = 0;
GLuint g_glFramebuffer  = 0;

// ============================================================
// Forward declarations
// ============================================================
LRESULT CALLBACK WindowProc(HWND hWnd, UINT uMsg, WPARAM wParam, LPARAM lParam);
HGLRC   EnableOpenGL(HDC hDC);
void    DisableOpenGL(HWND hWnd, HDC hDC, HGLRC hRC);
void    InitOpenGLFunc();
void    InitShader();
void    DrawTriangle();

template <typename T>
void SafeRelease(T** pp) { if (*pp) { (*pp)->Release(); *pp = nullptr; } }

// ============================================================
// Initialize D3D11 - Device + SwapChain (ForComposition)
// ============================================================
bool InitD3D11()
{
    HRESULT hr;
    dbg("[InitD3D11] begin\n");

    // Step 1: Create D3D11 device
    D3D_FEATURE_LEVEL featureLevel;
    D3D_FEATURE_LEVEL levels[] = { D3D_FEATURE_LEVEL_11_0 };
    UINT flags = D3D11_CREATE_DEVICE_BGRA_SUPPORT;

    hr = D3D11CreateDevice(
        nullptr, D3D_DRIVER_TYPE_HARDWARE, nullptr,
        flags, levels, 1, D3D11_SDK_VERSION,
        &g_d3dDevice, &featureLevel, &g_d3dContext);
    if (FAILED(hr)) {
        dbg("[InitD3D11] D3D11CreateDevice failed: hr=0x%08X\n", hr);
        return false;
    }
    dbg("[InitD3D11] Device=%p Context=%p\n", g_d3dDevice, g_d3dContext);

    // Step 2: Get DXGI Device -> Adapter -> Factory2
    IDXGIDevice* dxgiDevice = nullptr;
    g_d3dDevice->QueryInterface(__uuidof(IDXGIDevice), (void**)&dxgiDevice);

    IDXGIAdapter* adapter = nullptr;
    dxgiDevice->GetAdapter(&adapter);

    IDXGIFactory2* factory = nullptr;
    adapter->GetParent(__uuidof(IDXGIFactory2), (void**)&factory);
    adapter->Release();

    // Step 3: Create SwapChain FOR COMPOSITION (not bound to any HWND)
    // Unlike CreateSwapChainForHwnd, this swap chain has no window -
    // DirectComposition will composite it onto the window later.
    DXGI_SWAP_CHAIN_DESC1 scd = {};
    scd.Width       = WIDTH;
    scd.Height      = HEIGHT;
    scd.Format      = DXGI_FORMAT_B8G8R8A8_UNORM;
    scd.SampleDesc  = { 1, 0 };
    scd.BufferUsage = DXGI_USAGE_RENDER_TARGET_OUTPUT;
    scd.BufferCount = 2;
    scd.SwapEffect  = DXGI_SWAP_EFFECT_FLIP_SEQUENTIAL;
    scd.AlphaMode   = DXGI_ALPHA_MODE_PREMULTIPLIED;

    hr = factory->CreateSwapChainForComposition(g_d3dDevice, &scd, nullptr, &g_swapChain);
    factory->Release();
    dxgiDevice->Release();
    if (FAILED(hr)) {
        dbg("[InitD3D11] CreateSwapChainForComposition failed: hr=0x%08X\n", hr);
        return false;
    }
    dbg("[InitD3D11] SwapChain=%p\n", g_swapChain);

    // Step 4: Get the back buffer texture
    hr = g_swapChain->GetBuffer(0, __uuidof(ID3D11Texture2D), (void**)&g_backBuffer);
    if (FAILED(hr)) {
        dbg("[InitD3D11] GetBuffer failed: hr=0x%08X\n", hr);
        return false;
    }
    dbg("[InitD3D11] BackBuffer=%p\n", g_backBuffer);

    dbg("[InitD3D11] ok\n");
    return true;
}

// ============================================================
// Initialize WGL_NV_DX_interop - share D3D11 back buffer with GL
// ============================================================
bool InitDXInterop()
{
    dbg("[InitDXInterop] begin\n");

    // Step 1: Open the D3D11 device for GL interop
    g_hInteropDevice = wglDXOpenDeviceNV(g_d3dDevice);
    if (!g_hInteropDevice) {
        dbg("[InitDXInterop] wglDXOpenDeviceNV failed: %lu\n", GetLastError());
        return false;
    }
    dbg("[InitDXInterop] InteropDevice=%p\n", g_hInteropDevice);

    // Step 2: Create a GL renderbuffer that will mirror the D3D11 texture
    glGenRenderbuffers(1, &g_glRenderbuffer);
    dbg("[InitDXInterop] GL renderbuffer=%u\n", g_glRenderbuffer);

    // Step 3: Register the D3D11 back buffer as a GL renderbuffer
    // After this call, the GL renderbuffer and D3D11 texture share
    // the same GPU memory - zero-copy.
    g_hInteropObject = wglDXRegisterObjectNV(
        g_hInteropDevice,           // interop device handle
        g_backBuffer,               // D3D11 texture (back buffer)
        g_glRenderbuffer,           // GL renderbuffer name
        GL_RENDERBUFFER,            // GL object type
        WGL_ACCESS_READ_WRITE_NV    // access mode
    );
    if (!g_hInteropObject) {
        dbg("[InitDXInterop] wglDXRegisterObjectNV failed: %lu\n", GetLastError());
        return false;
    }
    dbg("[InitDXInterop] InteropObject=%p\n", g_hInteropObject);

    // Step 4: Create GL framebuffer and attach the shared renderbuffer
    glGenFramebuffers(1, &g_glFramebuffer);
    glBindFramebuffer(GL_FRAMEBUFFER, g_glFramebuffer);
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0,
                              GL_RENDERBUFFER, g_glRenderbuffer);

    GLenum status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
    if (status != GL_FRAMEBUFFER_COMPLETE) {
        dbg("[InitDXInterop] Framebuffer not complete: 0x%04X\n", status);
        return false;
    }
    glBindFramebuffer(GL_FRAMEBUFFER, 0);

    dbg("[InitDXInterop] FBO=%u status=COMPLETE\n", g_glFramebuffer);
    dbg("[InitDXInterop] ok\n");
    return true;
}

// ============================================================
// Initialize DirectComposition - pure COM, no WinRT
// ============================================================
bool InitDirectComposition(HWND hwnd)
{
    HRESULT hr;
    dbg("[InitDComp] begin\n");

    // Step 1: Create DComp device from the D3D11 DXGI device
    IDXGIDevice* dxgiDevice = nullptr;
    g_d3dDevice->QueryInterface(__uuidof(IDXGIDevice), (void**)&dxgiDevice);

    hr = DCompositionCreateDevice(dxgiDevice, __uuidof(IDCompositionDevice), (void**)&g_dcompDevice);
    dxgiDevice->Release();
    if (FAILED(hr)) {
        dbg("[InitDComp] DCompositionCreateDevice failed: hr=0x%08X\n", hr);
        return false;
    }
    dbg("[InitDComp] DCompDevice=%p\n", g_dcompDevice);

    // Step 2: Create target bound to the HWND
    hr = g_dcompDevice->CreateTargetForHwnd(hwnd, TRUE, &g_dcompTarget);
    if (FAILED(hr)) {
        dbg("[InitDComp] CreateTargetForHwnd failed: hr=0x%08X\n", hr);
        return false;
    }
    dbg("[InitDComp] DCompTarget=%p\n", g_dcompTarget);

    // Step 3: Create visual + set swap chain as content
    hr = g_dcompDevice->CreateVisual(&g_dcompVisual);
    if (FAILED(hr)) {
        dbg("[InitDComp] CreateVisual failed: hr=0x%08X\n", hr);
        return false;
    }

    hr = g_dcompVisual->SetContent(g_swapChain);
    if (FAILED(hr)) {
        dbg("[InitDComp] SetContent failed: hr=0x%08X\n", hr);
        return false;
    }
    dbg("[InitDComp] SetContent(SwapChain) ok\n");

    // Step 4: Build tree and commit to DWM
    g_dcompTarget->SetRoot(g_dcompVisual);
    hr = g_dcompDevice->Commit();
    if (FAILED(hr)) {
        dbg("[InitDComp] Commit failed: hr=0x%08X\n", hr);
        return false;
    }
    dbg("[InitDComp] Commit ok - composition tree active\n");

    return true;
}

// ============================================================
// Window procedure (same as hello.cpp)
// ============================================================
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
            return 0;

        default:
            return DefWindowProc(hWnd, uMsg, wParam, lParam);
    }

    return 0;
}

// ============================================================
// Initialize GL extension functions
// ============================================================
void InitOpenGLFunc()
{
    dbg("[InitOpenGLFunc] begin\n");

    // Same functions as hello.cpp
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
    glEnableVertexAttribArray = (PFNGLENABLEVERTEXATTRIBARRAYPROC) wglGetProcAddress("glEnableVertexAttribArray");
    glVertexAttribPointer     = (PFNGLVERTEXATTRIBPOINTERPROC)     wglGetProcAddress("glVertexAttribPointer");
    wglCreateContextAttribsARB= (PFNWGLCREATECONTEXTATTRIBSARBPROC)wglGetProcAddress("wglCreateContextAttribsARB");

    // Additional functions for FBO/RBO
    glGetShaderiv             = (PFNGLGETSHADERIVPROC)             wglGetProcAddress("glGetShaderiv");
    glGetShaderInfoLog        = (PFNGLGETSHADERINFOLOGPROC)        wglGetProcAddress("glGetShaderInfoLog");
    glGetProgramiv            = (PFNGLGETPROGRAMIVPROC)            wglGetProcAddress("glGetProgramiv");
    glGetProgramInfoLog       = (PFNGLGETPROGRAMINFOLOGPROC)       wglGetProcAddress("glGetProgramInfoLog");
    glGenFramebuffers         = (PFNGLGENFRAMEBUFFERSPROC)         wglGetProcAddress("glGenFramebuffers");
    glBindFramebuffer         = (PFNGLBINDFRAMEBUFFERPROC)         wglGetProcAddress("glBindFramebuffer");
    glFramebufferRenderbuffer = (PFNGLFRAMEBUFFERRENDERBUFFERPROC) wglGetProcAddress("glFramebufferRenderbuffer");
    glCheckFramebufferStatus  = (PFNGLCHECKFRAMEBUFFERSTATUSPROC)  wglGetProcAddress("glCheckFramebufferStatus");
    glGenRenderbuffers        = (PFNGLGENRENDERBUFFERSPROC)        wglGetProcAddress("glGenRenderbuffers");
    glBindRenderbuffer        = (PFNGLBINDRENDERBUFFERPROC)        wglGetProcAddress("glBindRenderbuffer");
    glDeleteFramebuffers      = (PFNGLDELETEFRAMEBUFFERSPROC)      wglGetProcAddress("glDeleteFramebuffers");
    glDeleteRenderbuffers     = (PFNGLDELETERENDERBUFFERSPROC)     wglGetProcAddress("glDeleteRenderbuffers");
    glDeleteBuffers           = (PFNGLDELETEBUFFERSPROC)           wglGetProcAddress("glDeleteBuffers");
    glGenVertexArrays         = (PFNGLGENVERTEXARRAYSPROC)         wglGetProcAddress("glGenVertexArrays");
    glBindVertexArray         = (PFNGLBINDVERTEXARRAYPROC)         wglGetProcAddress("glBindVertexArray");

    // WGL_NV_DX_interop functions
    wglDXOpenDeviceNV         = (PFNWGLDXOPENDEVICENVPROC)         wglGetProcAddress("wglDXOpenDeviceNV");
    wglDXCloseDeviceNV        = (PFNWGLDXCLOSEDEVICENVPROC)        wglGetProcAddress("wglDXCloseDeviceNV");
    wglDXRegisterObjectNV     = (PFNWGLDXREGISTEROBJECTNVPROC)     wglGetProcAddress("wglDXRegisterObjectNV");
    wglDXUnregisterObjectNV   = (PFNWGLDXUNREGISTEROBJECTNVPROC)   wglGetProcAddress("wglDXUnregisterObjectNV");
    wglDXLockObjectsNV        = (PFNWGLDXLOCKOBJECTSNVPROC)        wglGetProcAddress("wglDXLockObjectsNV");
    wglDXUnlockObjectsNV      = (PFNWGLDXUNLOCKOBJECTSNVPROC)      wglGetProcAddress("wglDXUnlockObjectsNV");

    if (!wglDXOpenDeviceNV) {
        dbg("[InitOpenGLFunc] WARNING: WGL_NV_DX_interop2 not available!\n");
    } else {
        dbg("[InitOpenGLFunc] WGL_NV_DX_interop2 functions loaded\n");
    }

    dbg("[InitOpenGLFunc] ok\n");
}

// ============================================================
// Enable OpenGL (same pattern as hello.cpp)
// ============================================================
HGLRC EnableOpenGL(HDC hDC)
{
    dbg("[EnableOpenGL] begin\n");

    HGLRC hRC = NULL;

    PIXELFORMATDESCRIPTOR pfd;
    int iFormat;

    ZeroMemory(&pfd, sizeof(pfd));
    pfd.nSize      = sizeof(pfd);
    pfd.nVersion   = 1;
    pfd.dwFlags    = PFD_DRAW_TO_WINDOW | PFD_SUPPORT_OPENGL | PFD_DOUBLEBUFFER;
    pfd.iPixelType = PFD_TYPE_RGBA;
    pfd.cColorBits = 24;
    pfd.cDepthBits = 16;
    pfd.iLayerType = PFD_MAIN_PLANE;

    iFormat = ChoosePixelFormat(hDC, &pfd);
    SetPixelFormat(hDC, iFormat, &pfd);

    // Create temporary legacy context to bootstrap
    HGLRC hGLRC_old = wglCreateContext(hDC);
    wglMakeCurrent(hDC, hGLRC_old);

    wglCreateContextAttribsARB = (PFNWGLCREATECONTEXTATTRIBSARBPROC)
        wglGetProcAddress("wglCreateContextAttribsARB");

    // Create context (same approach as hello.cpp)
    hRC = wglCreateContextAttribsARB(hDC, 0, NULL);

    wglMakeCurrent(hDC, hRC);
    wglDeleteContext(hGLRC_old);

    const char* version  = (const char*)glGetString(GL_VERSION);
    const char* renderer = (const char*)glGetString(GL_RENDERER);
    dbg("[EnableOpenGL] GL_VERSION  = %s\n", version ? version : "(null)");
    dbg("[EnableOpenGL] GL_RENDERER = %s\n", renderer ? renderer : "(null)");

    return hRC;
}

// ============================================================
// Disable OpenGL (same as hello.cpp)
// ============================================================
void DisableOpenGL(HWND hWnd, HDC hDC, HGLRC hRC)
{
    wglMakeCurrent(NULL, NULL);
    wglDeleteContext(hRC);
    ReleaseDC(hWnd, hDC);
}

// ============================================================
// Initialize shader and vertex buffers (based on hello.cpp)
// ============================================================
void InitShader()
{
    dbg("[InitShader] begin\n");

    // Need a VAO for core profile contexts
    glGenVertexArrays(1, &vao);
    glBindVertexArray(vao);

    glGenBuffers(2, vbo);

    GLfloat vertices[] = {
         0.0f,  0.5f, 0.0f,
         0.5f, -0.5f, 0.0f,
        -0.5f, -0.5f, 0.0f
    };

    GLfloat colors[] = {
         1.0f,  0.0f,  0.0f,
         0.0f,  1.0f,  0.0f,
         0.0f,  0.0f,  1.0f
    };

    glBindBuffer(GL_ARRAY_BUFFER, vbo[0]);
    glBufferData(GL_ARRAY_BUFFER, sizeof(vertices), vertices, GL_STATIC_DRAW);

    glBindBuffer(GL_ARRAY_BUFFER, vbo[1]);
    glBufferData(GL_ARRAY_BUFFER, sizeof(colors), colors, GL_STATIC_DRAW);

    // Create and compile the vertex shader
    GLuint vertexShader = glCreateShader(GL_VERTEX_SHADER);
    glShaderSource(vertexShader, 1, &vertexSource, nullptr);
    glCompileShader(vertexShader);
    {
        GLint ok = 0;
        glGetShaderiv(vertexShader, GL_COMPILE_STATUS, &ok);
        if (!ok) {
            char log[512];
            glGetShaderInfoLog(vertexShader, sizeof(log), nullptr, log);
            dbg("[InitShader] VS compile error: %s\n", log);
        } else {
            dbg("[InitShader] VS compiled ok\n");
        }
    }

    // Create and compile the fragment shader
    GLuint fragmentShader = glCreateShader(GL_FRAGMENT_SHADER);
    glShaderSource(fragmentShader, 1, &fragmentSource, nullptr);
    glCompileShader(fragmentShader);
    {
        GLint ok = 0;
        glGetShaderiv(fragmentShader, GL_COMPILE_STATUS, &ok);
        if (!ok) {
            char log[512];
            glGetShaderInfoLog(fragmentShader, sizeof(log), nullptr, log);
            dbg("[InitShader] FS compile error: %s\n", log);
        } else {
            dbg("[InitShader] FS compiled ok\n");
        }
    }

    // Link the vertex and fragment shader into a shader program
    shaderProgram = glCreateProgram();
    glAttachShader(shaderProgram, vertexShader);
    glAttachShader(shaderProgram, fragmentShader);
    glLinkProgram(shaderProgram);
    {
        GLint ok = 0;
        glGetProgramiv(shaderProgram, GL_LINK_STATUS, &ok);
        if (!ok) {
            char log[512];
            glGetProgramInfoLog(shaderProgram, sizeof(log), nullptr, log);
            dbg("[InitShader] Link error: %s\n", log);
        } else {
            dbg("[InitShader] Program linked ok\n");
        }
    }
    glUseProgram(shaderProgram);

    // Specify the layout of the vertex data
    posAttrib = glGetAttribLocation(shaderProgram, "position");
    glEnableVertexAttribArray(posAttrib);

    colAttrib = glGetAttribLocation(shaderProgram, "color");
    glEnableVertexAttribArray(colAttrib);

    dbg("[InitShader] posAttrib=%d colAttrib=%d\n", posAttrib, colAttrib);
    dbg("[InitShader] ok\n");
}

// ============================================================
// Draw triangle (based on hello.cpp DrawTriangle)
// Renders into the shared FBO instead of the default framebuffer.
// ============================================================
void DrawTriangle()
{
    // Bind FBO that targets the shared renderbuffer (= D3D11 back buffer)
    glBindFramebuffer(GL_FRAMEBUFFER, g_glFramebuffer);
    glViewport(0, 0, WIDTH, HEIGHT);

    glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT);

    glUseProgram(shaderProgram);
    glBindVertexArray(vao);

    glBindBuffer(GL_ARRAY_BUFFER, vbo[0]);
    glVertexAttribPointer(posAttrib, 3, GL_FLOAT, GL_FALSE, 0, 0);

    glBindBuffer(GL_ARRAY_BUFFER, vbo[1]);
    glVertexAttribPointer(colAttrib, 3, GL_FLOAT, GL_FALSE, 0, 0);

    // Draw a triangle from the 3 vertices
    glDrawArrays(GL_TRIANGLES, 0, 3);

    // Unbind FBO
    glBindFramebuffer(GL_FRAMEBUFFER, 0);
}

// ============================================================
// Cleanup D3D11 / DComp / Interop resources
// ============================================================
void CleanupAll()
{
    dbg("[Cleanup] begin\n");

    // WGL_NV_DX_interop
    if (g_hInteropObject && wglDXUnregisterObjectNV) {
        wglDXUnregisterObjectNV(g_hInteropDevice, g_hInteropObject);
        g_hInteropObject = nullptr;
    }
    if (g_hInteropDevice && wglDXCloseDeviceNV) {
        wglDXCloseDeviceNV(g_hInteropDevice);
        g_hInteropDevice = nullptr;
    }

    // GL resources
    if (g_glFramebuffer)  { glDeleteFramebuffers(1, &g_glFramebuffer);  g_glFramebuffer = 0; }
    if (g_glRenderbuffer) { glDeleteRenderbuffers(1, &g_glRenderbuffer); g_glRenderbuffer = 0; }
    if (vbo[0])           { glDeleteBuffers(2, vbo); vbo[0] = vbo[1] = 0; }

    // DirectComposition
    SafeRelease(&g_dcompVisual);
    SafeRelease(&g_dcompTarget);
    SafeRelease(&g_dcompDevice);

    // D3D11
    SafeRelease(&g_backBuffer);
    SafeRelease(&g_swapChain);
    SafeRelease(&g_d3dContext);
    SafeRelease(&g_d3dDevice);

    dbg("[Cleanup] all resources released\n");
}

// ============================================================
// Entry point
// ============================================================
int APIENTRY _tWinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, LPTSTR lpCmdLine, int nCmdShow)
{
    dbg("========================================\n");
    dbg("OpenGL 4.6 Triangle via DirectComposition\n");
    dbg("WGL_NV_DX_interop2 + dcomp.dll\n");
    dbg("========================================\n");

    WNDCLASSEX wcex;
    HWND hWnd;
    HDC hDC;
    HGLRC hRC;
    MSG msg;
    BOOL bQuit = FALSE;

    // Register window class (same as hello.cpp)
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
    wcex.lpszClassName  = _T("DCompGLWindowClass");
    wcex.hIconSm        = LoadIcon(NULL, IDI_APPLICATION);

    if (!RegisterClassEx(&wcex))
        return 0;

    hWnd = CreateWindowEx(0,
                          _T("DCompGLWindowClass"),
                          _T("OpenGL 4.6 Triangle (DirectComposition)"),
                          WS_OVERLAPPEDWINDOW,
                          CW_USEDEFAULT, CW_USEDEFAULT,
                          WIDTH, HEIGHT,
                          NULL, NULL, hInstance, NULL);

    ShowWindow(hWnd, nCmdShow);
    dbg("[Main] HWND=%p\n", hWnd);

    // Step 1: Enable OpenGL (same as hello.cpp)
    hDC = GetDC(hWnd);
    hRC = EnableOpenGL(hDC);
    InitOpenGLFunc();

    // Step 2: Initialize D3D11 (SwapChainForComposition)
    if (!InitD3D11()) {
        dbg("[Main] InitD3D11 failed\n");
        DisableOpenGL(hWnd, hDC, hRC);
        return 1;
    }

    // Step 3: Set up WGL_NV_DX_interop
    //   GL renderbuffer <-> D3D11 back buffer (zero-copy GPU sharing)
    if (!InitDXInterop()) {
        dbg("[Main] InitDXInterop failed\n");
        CleanupAll();
        DisableOpenGL(hWnd, hDC, hRC);
        return 1;
    }

    // Step 4: Initialize DirectComposition
    //   SwapChain -> DComp Visual -> DWM -> Display
    if (!InitDirectComposition(hWnd)) {
        dbg("[Main] InitDirectComposition failed\n");
        CleanupAll();
        DisableOpenGL(hWnd, hDC, hRC);
        return 1;
    }

    // Step 5: Initialize shaders and vertex buffers (same as hello.cpp)
    InitShader();

    dbg("[Main] entering message loop\n");

    // Message loop (same structure as hello.cpp)
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
            // Lock the D3D11 back buffer for GL access
            wglDXLockObjectsNV(g_hInteropDevice, 1, &g_hInteropObject);

            // Draw triangle into FBO (= shared D3D11 back buffer)
            DrawTriangle();
            glFlush();

            // Unlock - D3D11 can now access the texture
            wglDXUnlockObjectsNV(g_hInteropDevice, 1, &g_hInteropObject);

            // Present via swap chain - DComp composites onto window
            g_swapChain->Present(1, 0);

            Sleep(1);
        }
    }

    // Cleanup
    CleanupAll();
    DisableOpenGL(hWnd, hDC, hRC);
    DestroyWindow(hWnd);

    dbg("[Main] exit\n");

    return msg.wParam;
}
