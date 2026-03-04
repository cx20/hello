// hello_dcomp_multi.cpp - OpenGL + D3D11 + Vulkan Triangles in One Window
//
// Build (Visual Studio Developer Command Prompt):
//   cl /EHsc /std:c++17 /I%VULKAN_SDK%\Include hello_dcomp_multi.cpp ^
//      /link /LIBPATH:%VULKAN_SDK%\Lib vulkan-1.lib ^
//      d3d11.lib dxgi.lib d3dcompiler.lib dcomp.lib opengl32.lib user32.lib gdi32.lib
//
// Shaders (Vulkan only - D3D11 and OpenGL use embedded shaders):
//   %VULKAN_SDK%\Bin\glslangValidator -V hello.vert -o hello_vert.spv
//   %VULKAN_SDK%\Bin\glslangValidator -V hello.frag -o hello_frag.spv
//
// Architecture:
//   Three separate SwapChainForComposition, each displayed as a
//   DirectComposition Visual positioned side-by-side in one window.
//
//   ------------------------ One HWND ---------------------
//   |  Visual 0 (GL)  |  Visual 1 (D3D)  | Visual 2 (VK)  |
//   |  OffsetX = 0    |  OffsetX = 320   | OffsetX = 640  |
//   -------------------------------------------------------
//
//   OpenGL:  WGL_NV_DX_interop2 -> shared D3D11 SwapChain
//   D3D11:   native rendering to SwapChain
//   Vulkan:  offscreen render -> staging buffer -> D3D11 SwapChain
//
// Debug output: OutputDebugString - monitor with DebugView (SysInternals)

#define WIN32_LEAN_AND_MEAN
#define NOMINMAX
#include <atlbase.h>
#include <atlapp.h>
#include <atlcrack.h>
#include <atlwin.h>
#include <tchar.h>
#include <windows.h>
#include <d3d11.h>
#include <dxgi1_2.h>
#include <dxgi1_4.h>
#include <d3dcompiler.h>
#include <dcomp.h>
#include <gl/gl.h>

#define VK_USE_PLATFORM_WIN32_KHR
#include <vulkan/vulkan.h>

#include <vector>
#include <fstream>
#include <string>
#include <cstdio>
#include <cstdarg>
#include <cstring>
#include <stdexcept>

CAppModule _Module;

#pragma comment(lib, "d3d11.lib")
#pragma comment(lib, "dxgi.lib")
#pragma comment(lib, "d3dcompiler.lib")
#pragma comment(lib, "dcomp.lib")
#pragma comment(lib, "opengl32.lib")
#pragma comment(lib, "user32.lib")
#pragma comment(lib, "gdi32.lib")

// ============================================================
// Debug output helper
// ============================================================
static void dbg(const char* fmt, ...) {
    char buf[1024];
    va_list args;
    va_start(args, fmt);
    vsnprintf(buf, sizeof(buf), fmt, args);
    va_end(args);
    OutputDebugStringA(buf);
}

static void TraceEnter(const char* fn) {
    dbg("[TRACE] %s: enter\n", fn);
}

static void TraceState(const char* fn, const char* state) {
    dbg("[TRACE] %s: %s\n", fn, state);
}

static void TraceHr(const char* fn, const char* api, HRESULT hr) {
    dbg("[TRACE] %s: %s hr=0x%08lX (%s)\n",
        fn, api, (unsigned long)hr, SUCCEEDED(hr) ? "OK" : "FAILED");
}

static void TraceVk(const char* fn, const char* api, VkResult vr) {
    dbg("[TRACE] %s: %s vr=%d (%s)\n",
        fn, api, (int)vr, (vr == VK_SUCCESS) ? "OK" : "FAILED");
}

#define TRACE_ENTER() TraceEnter(__FUNCTION__)
#define TRACE_STATE(msg) TraceState(__FUNCTION__, msg)

// ============================================================
// Constants
// ============================================================
static const uint32_t PANEL_W = 320;
static const uint32_t PANEL_H = 480;
static const uint32_t WINDOW_W = PANEL_W * 3; // 960
static const uint32_t WINDOW_H = PANEL_H;     // 480

// ============================================================
// Helper: safe COM release
// ============================================================
template <typename T>
void SafeRelease(T** pp) { if (*pp) { (*pp)->Release(); *pp = nullptr; } }

// ============================================================
// Read SPIR-V file (for Vulkan)
// ============================================================
static std::vector<char> readFile(const std::string& filename) {
    std::ifstream file(filename, std::ios::ate | std::ios::binary);
    if (!file.is_open())
        throw std::runtime_error("failed to open file: " + filename);
    size_t sz = (size_t)file.tellg();
    std::vector<char> buf(sz);
    file.seekg(0);
    file.read(buf.data(), sz);
    return buf;
}

// ============================================================
// OpenGL type definitions and constants
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
#define WGL_CONTEXT_MAJOR_VERSION_ARB     0x2091
#define WGL_CONTEXT_MINOR_VERSION_ARB     0x2092
#define WGL_CONTEXT_PROFILE_MASK_ARB      0x9126
#define WGL_CONTEXT_CORE_PROFILE_BIT_ARB  0x00000001
#define WGL_ACCESS_READ_WRITE_NV          0x0001
#define WGL_ACCESS_WRITE_DISCARD_NV       0x0002

// GL function pointer types
typedef void   (APIENTRYP PFN_glGenBuffers)(GLsizei, GLuint*);
typedef void   (APIENTRYP PFN_glBindBuffer)(GLenum, GLuint);
typedef void   (APIENTRYP PFN_glBufferData)(GLenum, GLsizeiptr, const void*, GLenum);
typedef GLuint (APIENTRYP PFN_glCreateShader)(GLenum);
typedef void   (APIENTRYP PFN_glShaderSource)(GLuint, GLsizei, const GLchar* const*, const GLint*);
typedef void   (APIENTRYP PFN_glCompileShader)(GLuint);
typedef GLuint (APIENTRYP PFN_glCreateProgram)(void);
typedef void   (APIENTRYP PFN_glAttachShader)(GLuint, GLuint);
typedef void   (APIENTRYP PFN_glLinkProgram)(GLuint);
typedef void   (APIENTRYP PFN_glUseProgram)(GLuint);
typedef GLint  (APIENTRYP PFN_glGetAttribLocation)(GLuint, const GLchar*);
typedef void   (APIENTRYP PFN_glEnableVertexAttribArray)(GLuint);
typedef void   (APIENTRYP PFN_glVertexAttribPointer)(GLuint, GLint, GLenum, GLboolean, GLsizei, const void*);
typedef void   (APIENTRYP PFN_glGetShaderiv)(GLuint, GLenum, GLint*);
typedef void   (APIENTRYP PFN_glGetShaderInfoLog)(GLuint, GLsizei, GLsizei*, GLchar*);
typedef void   (APIENTRYP PFN_glGetProgramiv)(GLuint, GLenum, GLint*);
typedef void   (APIENTRYP PFN_glGetProgramInfoLog)(GLuint, GLsizei, GLsizei*, GLchar*);
typedef void   (APIENTRYP PFN_glGenFramebuffers)(GLsizei, GLuint*);
typedef void   (APIENTRYP PFN_glBindFramebuffer)(GLenum, GLuint);
typedef void   (APIENTRYP PFN_glFramebufferRenderbuffer)(GLenum, GLenum, GLenum, GLuint);
typedef GLenum (APIENTRYP PFN_glCheckFramebufferStatus)(GLenum);
typedef void   (APIENTRYP PFN_glGenRenderbuffers)(GLsizei, GLuint*);
typedef void   (APIENTRYP PFN_glBindRenderbuffer)(GLenum, GLuint);
typedef void   (APIENTRYP PFN_glGenVertexArrays)(GLsizei, GLuint*);
typedef void   (APIENTRYP PFN_glBindVertexArray)(GLuint);

// WGL function pointer types
typedef HGLRC  (WINAPI * PFN_wglCreateContextAttribsARB)(HDC, HGLRC, const int*);
typedef HANDLE (WINAPI * PFN_wglDXOpenDeviceNV)(void*);
typedef BOOL   (WINAPI * PFN_wglDXCloseDeviceNV)(HANDLE);
typedef HANDLE (WINAPI * PFN_wglDXRegisterObjectNV)(HANDLE, void*, GLuint, GLenum, GLenum);
typedef BOOL   (WINAPI * PFN_wglDXUnregisterObjectNV)(HANDLE, HANDLE);
typedef BOOL   (WINAPI * PFN_wglDXLockObjectsNV)(HANDLE, GLint, HANDLE*);
typedef BOOL   (WINAPI * PFN_wglDXUnlockObjectsNV)(HANDLE, GLint, HANDLE*);

// GL function pointers (loaded at runtime)
static PFN_glGenBuffers              p_glGenBuffers;
static PFN_glBindBuffer              p_glBindBuffer;
static PFN_glBufferData              p_glBufferData;
static PFN_glCreateShader            p_glCreateShader;
static PFN_glShaderSource            p_glShaderSource;
static PFN_glCompileShader           p_glCompileShader;
static PFN_glCreateProgram           p_glCreateProgram;
static PFN_glAttachShader            p_glAttachShader;
static PFN_glLinkProgram             p_glLinkProgram;
static PFN_glUseProgram              p_glUseProgram;
static PFN_glGetAttribLocation       p_glGetAttribLocation;
static PFN_glEnableVertexAttribArray p_glEnableVertexAttribArray;
static PFN_glVertexAttribPointer     p_glVertexAttribPointer;
static PFN_glGetShaderiv             p_glGetShaderiv;
static PFN_glGetShaderInfoLog        p_glGetShaderInfoLog;
static PFN_glGetProgramiv            p_glGetProgramiv;
static PFN_glGetProgramInfoLog       p_glGetProgramInfoLog;
static PFN_glGenFramebuffers         p_glGenFramebuffers;
static PFN_glBindFramebuffer         p_glBindFramebuffer;
static PFN_glFramebufferRenderbuffer p_glFramebufferRenderbuffer;
static PFN_glCheckFramebufferStatus  p_glCheckFramebufferStatus;
static PFN_glGenRenderbuffers        p_glGenRenderbuffers;
static PFN_glBindRenderbuffer        p_glBindRenderbuffer;
static PFN_glGenVertexArrays         p_glGenVertexArrays;
static PFN_glBindVertexArray         p_glBindVertexArray;

static PFN_wglCreateContextAttribsARB p_wglCreateContextAttribsARB;
static PFN_wglDXOpenDeviceNV          p_wglDXOpenDeviceNV;
static PFN_wglDXCloseDeviceNV         p_wglDXCloseDeviceNV;
static PFN_wglDXRegisterObjectNV      p_wglDXRegisterObjectNV;
static PFN_wglDXUnregisterObjectNV    p_wglDXUnregisterObjectNV;
static PFN_wglDXLockObjectsNV         p_wglDXLockObjectsNV;
static PFN_wglDXUnlockObjectsNV       p_wglDXUnlockObjectsNV;

// ============================================================
// Global state
// ============================================================

// Win32
static HWND g_hwnd = nullptr;

// Shared D3D11 device (used by all three renderers)
static ID3D11Device*        g_d3dDevice  = nullptr;
static ID3D11DeviceContext*  g_d3dContext = nullptr;

// DirectComposition
static IDCompositionDevice* g_dcompDevice = nullptr;
static IDCompositionTarget* g_dcompTarget = nullptr;
static IDCompositionVisual* g_rootVisual  = nullptr;

// --- Panel 0: OpenGL ---
static IDXGISwapChain1*     g_glSwapChain    = nullptr;
static ID3D11Texture2D*     g_glBackBuffer[2] = { nullptr, nullptr };
static IDXGISwapChain3*     g_glSwapChain3   = nullptr;
static IDCompositionVisual* g_glVisual       = nullptr;
static HDC                  g_glHDC          = nullptr;
static HGLRC                g_glHRC          = nullptr;
static HANDLE               g_glInteropDev   = nullptr;
static HANDLE               g_glInteropObj[2] = { nullptr, nullptr };
static GLuint               g_glRBO[2]       = { 0, 0 };
static GLuint               g_glFBO[2]       = { 0, 0 };
static GLuint               g_glProgram      = 0;
static GLuint               g_glVAO          = 0;
static GLuint               g_glVBO[2]       = {};
static GLint                g_glPosAttr      = -1;
static GLint                g_glColAttr      = -1;

// --- Panel 1: D3D11 ---
static IDXGISwapChain1*        g_dxSwapChain    = nullptr;
static ID3D11RenderTargetView* g_dxRTV          = nullptr;
static IDCompositionVisual*    g_dxVisual       = nullptr;
static ID3D11VertexShader*     g_dxVS           = nullptr;
static ID3D11PixelShader*      g_dxPS           = nullptr;
static ID3D11InputLayout*      g_dxInputLayout  = nullptr;
static ID3D11Buffer*           g_dxVertexBuffer = nullptr;

// --- Panel 2: Vulkan ---
static IDXGISwapChain1*     g_vkSwapChain    = nullptr;
static ID3D11Texture2D*     g_vkBackBuffer   = nullptr;
static ID3D11Texture2D*     g_vkStagingTex   = nullptr;
static IDCompositionVisual* g_vkVisual       = nullptr;
static VkInstance           g_vkInst         = VK_NULL_HANDLE;
static VkPhysicalDevice     g_vkPhysDev      = VK_NULL_HANDLE;
static VkDevice             g_vkDev          = VK_NULL_HANDLE;
static VkQueue              g_vkQueue        = VK_NULL_HANDLE;
static uint32_t             g_vkQueueFamily  = 0;
static VkImage              g_vkOffImage     = VK_NULL_HANDLE;
static VkDeviceMemory       g_vkOffMemory    = VK_NULL_HANDLE;
static VkImageView          g_vkOffView      = VK_NULL_HANDLE;
static VkRenderPass         g_vkRenderPass   = VK_NULL_HANDLE;
static VkFramebuffer        g_vkFramebuffer  = VK_NULL_HANDLE;
static VkPipelineLayout     g_vkPipeLayout   = VK_NULL_HANDLE;
static VkPipeline           g_vkPipeline     = VK_NULL_HANDLE;
static VkCommandPool        g_vkCmdPool      = VK_NULL_HANDLE;
static VkCommandBuffer      g_vkCmdBuf       = VK_NULL_HANDLE;
static VkFence              g_vkFence        = VK_NULL_HANDLE;
static VkBuffer             g_vkStagBuf      = VK_NULL_HANDLE;
static VkDeviceMemory       g_vkStagMem      = VK_NULL_HANDLE;
static bool                 g_isReadyForRender = false;
static bool                 g_firstFrameLogged = false;
static bool                 g_vkEnabled = false;

// ============================================================
// Forward declarations used by the WTL window
// ============================================================
static void RenderGL();
static void RenderD3D11();
static void RenderVulkan();

// ============================================================
// WTL window
// ============================================================
class CHelloWindow : public CWindowImpl<CHelloWindow> {
public:
    DECLARE_WND_CLASS_EX(_T("DCompMultiWtlClass"), CS_HREDRAW | CS_VREDRAW | CS_OWNDC, COLOR_WINDOW)

    BEGIN_MSG_MAP(CHelloWindow)
        MSG_WM_CREATE(OnCreate)
        MSG_WM_TIMER(OnTimer)
        MSG_WM_KEYDOWN(OnKeyDown)
        MSG_WM_DESTROY(OnDestroy)
    END_MSG_MAP()

    int OnCreate(LPCREATESTRUCT) {
        SetTimer(1, 16, nullptr);
        return 0;
    }

    void OnTimer(UINT_PTR) {
        if (!g_isReadyForRender) return;
        RenderGL();
        RenderD3D11();
        if (g_vkEnabled) {
            RenderVulkan();
        }
        if (!g_firstFrameLogged) {
            dbg("[Main] first frame rendered\n");
            g_firstFrameLogged = true;
        }
    }

    void OnKeyDown(TCHAR ch, UINT, UINT) {
        if (ch == VK_ESCAPE) {
            DestroyWindow();
        }
    }

    void OnDestroy() {
        KillTimer(1);
        PostQuitMessage(0);
    }
};

// ============================================================
// Create shared D3D11 device
// ============================================================
static void CreateD3D11Device() {
    TRACE_ENTER();
    dbg("[D3D11] creating shared device\n");
    D3D_FEATURE_LEVEL level = D3D_FEATURE_LEVEL_11_0;
    HRESULT hr = D3D11CreateDevice(nullptr, D3D_DRIVER_TYPE_HARDWARE, nullptr,
        D3D11_CREATE_DEVICE_BGRA_SUPPORT, &level, 1, D3D11_SDK_VERSION,
        &g_d3dDevice, nullptr, &g_d3dContext);
    TraceHr(__FUNCTION__, "D3D11CreateDevice", hr);
    if (FAILED(hr)) throw std::runtime_error("D3D11CreateDevice failed");
    dbg("[D3D11] Device=%p\n", g_d3dDevice);
}

// ============================================================
// Helper: create a SwapChainForComposition
// ============================================================
static IDXGISwapChain1* CreateCompSwapChainWithAlpha(uint32_t w, uint32_t h, DXGI_ALPHA_MODE alphaMode) {
    TRACE_ENTER();
    IDXGIDevice* dxgiDev = nullptr;
    g_d3dDevice->QueryInterface(__uuidof(IDXGIDevice), (void**)&dxgiDev);
    IDXGIAdapter* adapter = nullptr;
    dxgiDev->GetAdapter(&adapter);
    IDXGIFactory2* factory = nullptr;
    adapter->GetParent(__uuidof(IDXGIFactory2), (void**)&factory);
    adapter->Release();

    DXGI_SWAP_CHAIN_DESC1 scd = {};
    scd.Width       = w;
    scd.Height      = h;
    scd.Format      = DXGI_FORMAT_B8G8R8A8_UNORM;
    scd.SampleDesc  = { 1, 0 };
    scd.BufferUsage = DXGI_USAGE_RENDER_TARGET_OUTPUT;
    scd.BufferCount = 2;
    scd.SwapEffect  = DXGI_SWAP_EFFECT_FLIP_SEQUENTIAL;
    scd.AlphaMode   = alphaMode;

    IDXGISwapChain1* sc = nullptr;
    HRESULT hr = factory->CreateSwapChainForComposition(g_d3dDevice, &scd, nullptr, &sc);
    TraceHr(__FUNCTION__, "CreateSwapChainForComposition", hr);
    factory->Release();
    dxgiDev->Release();
    if (FAILED(hr)) throw std::runtime_error("CreateSwapChainForComposition failed");
    return sc;
}

static IDXGISwapChain1* CreateCompSwapChain(uint32_t w, uint32_t h) {
    return CreateCompSwapChainWithAlpha(w, h, DXGI_ALPHA_MODE_PREMULTIPLIED);
}

// ============================================================
// Initialize DirectComposition - 3 visuals side by side
// ============================================================
static void InitDirectComposition() {
    TRACE_ENTER();
    dbg("[DComp] begin\n");
    IDXGIDevice* dxgiDev = nullptr;
    g_d3dDevice->QueryInterface(__uuidof(IDXGIDevice), (void**)&dxgiDev);
    HRESULT hr = DCompositionCreateDevice(dxgiDev, __uuidof(IDCompositionDevice), (void**)&g_dcompDevice);
    TraceHr(__FUNCTION__, "DCompositionCreateDevice", hr);
    dxgiDev->Release();

    hr = g_dcompDevice->CreateTargetForHwnd(g_hwnd, TRUE, &g_dcompTarget);
    TraceHr(__FUNCTION__, "CreateTargetForHwnd", hr);

    // Root visual (container)
    g_dcompDevice->CreateVisual(&g_rootVisual);
    g_dcompTarget->SetRoot(g_rootVisual);

    // Panel 0: OpenGL (left)
    g_dcompDevice->CreateVisual(&g_glVisual);
    g_glVisual->SetOffsetX(0.0f);
    g_glVisual->SetOffsetY(0.0f);

    // Panel 1: D3D11 (center)
    g_dcompDevice->CreateVisual(&g_dxVisual);
    g_dxVisual->SetOffsetX((float)PANEL_W);
    g_dxVisual->SetOffsetY(0.0f);

    // Panel 2: Vulkan (right)
    g_dcompDevice->CreateVisual(&g_vkVisual);
    g_vkVisual->SetOffsetX((float)(PANEL_W * 2));
    g_vkVisual->SetOffsetY(0.0f);

    // Build visual tree: root -> gl -> dx -> vk (sibling chain)
    g_rootVisual->AddVisual(g_glVisual, TRUE, nullptr);
    g_rootVisual->AddVisual(g_dxVisual, TRUE, g_glVisual);
    g_rootVisual->AddVisual(g_vkVisual, TRUE, g_dxVisual);

    dbg("[DComp] 3 visuals created\n");
}

// ************************************************************
//  PANEL 0: OpenGL 4.6 via WGL_NV_DX_interop2
// ************************************************************
static void LoadGLFunctions() {
    TRACE_ENTER();
    p_glGenBuffers              = (PFN_glGenBuffers)              wglGetProcAddress("glGenBuffers");
    p_glBindBuffer              = (PFN_glBindBuffer)              wglGetProcAddress("glBindBuffer");
    p_glBufferData              = (PFN_glBufferData)              wglGetProcAddress("glBufferData");
    p_glCreateShader            = (PFN_glCreateShader)            wglGetProcAddress("glCreateShader");
    p_glShaderSource            = (PFN_glShaderSource)            wglGetProcAddress("glShaderSource");
    p_glCompileShader           = (PFN_glCompileShader)           wglGetProcAddress("glCompileShader");
    p_glCreateProgram           = (PFN_glCreateProgram)           wglGetProcAddress("glCreateProgram");
    p_glAttachShader            = (PFN_glAttachShader)            wglGetProcAddress("glAttachShader");
    p_glLinkProgram             = (PFN_glLinkProgram)             wglGetProcAddress("glLinkProgram");
    p_glUseProgram              = (PFN_glUseProgram)              wglGetProcAddress("glUseProgram");
    p_glGetAttribLocation       = (PFN_glGetAttribLocation)       wglGetProcAddress("glGetAttribLocation");
    p_glEnableVertexAttribArray = (PFN_glEnableVertexAttribArray) wglGetProcAddress("glEnableVertexAttribArray");
    p_glVertexAttribPointer     = (PFN_glVertexAttribPointer)     wglGetProcAddress("glVertexAttribPointer");
    p_glGetShaderiv             = (PFN_glGetShaderiv)             wglGetProcAddress("glGetShaderiv");
    p_glGetShaderInfoLog        = (PFN_glGetShaderInfoLog)        wglGetProcAddress("glGetShaderInfoLog");
    p_glGetProgramiv            = (PFN_glGetProgramiv)            wglGetProcAddress("glGetProgramiv");
    p_glGetProgramInfoLog       = (PFN_glGetProgramInfoLog)       wglGetProcAddress("glGetProgramInfoLog");
    p_glGenFramebuffers         = (PFN_glGenFramebuffers)         wglGetProcAddress("glGenFramebuffers");
    p_glBindFramebuffer         = (PFN_glBindFramebuffer)         wglGetProcAddress("glBindFramebuffer");
    p_glFramebufferRenderbuffer = (PFN_glFramebufferRenderbuffer) wglGetProcAddress("glFramebufferRenderbuffer");
    p_glCheckFramebufferStatus  = (PFN_glCheckFramebufferStatus)  wglGetProcAddress("glCheckFramebufferStatus");
    p_glGenRenderbuffers        = (PFN_glGenRenderbuffers)        wglGetProcAddress("glGenRenderbuffers");
    p_glBindRenderbuffer        = (PFN_glBindRenderbuffer)        wglGetProcAddress("glBindRenderbuffer");
    p_glGenVertexArrays         = (PFN_glGenVertexArrays)         wglGetProcAddress("glGenVertexArrays");
    p_glBindVertexArray         = (PFN_glBindVertexArray)         wglGetProcAddress("glBindVertexArray");

    p_wglCreateContextAttribsARB = (PFN_wglCreateContextAttribsARB)wglGetProcAddress("wglCreateContextAttribsARB");
    p_wglDXOpenDeviceNV          = (PFN_wglDXOpenDeviceNV)         wglGetProcAddress("wglDXOpenDeviceNV");
    p_wglDXCloseDeviceNV         = (PFN_wglDXCloseDeviceNV)        wglGetProcAddress("wglDXCloseDeviceNV");
    p_wglDXRegisterObjectNV      = (PFN_wglDXRegisterObjectNV)     wglGetProcAddress("wglDXRegisterObjectNV");
    p_wglDXUnregisterObjectNV    = (PFN_wglDXUnregisterObjectNV)   wglGetProcAddress("wglDXUnregisterObjectNV");
    p_wglDXLockObjectsNV         = (PFN_wglDXLockObjectsNV)        wglGetProcAddress("wglDXLockObjectsNV");
    p_wglDXUnlockObjectsNV       = (PFN_wglDXUnlockObjectsNV)      wglGetProcAddress("wglDXUnlockObjectsNV");
    TRACE_STATE("OpenGL/WGL function pointers loaded");
}

static void CheckGLShader(GLuint shader, const char* label) {
    GLint ok = 0;
    p_glGetShaderiv(shader, GL_COMPILE_STATUS, &ok);
    if (ok == 0) {
        char log[1024] = {};
        GLsizei len = 0;
        p_glGetShaderInfoLog(shader, sizeof(log), &len, log);
        char msg[1200] = {};
        snprintf(msg, sizeof(msg), "%s compile failed: %s", label, log);
        throw std::runtime_error(msg);
    }
}

static void CheckGLProgram(GLuint prog) {
    GLint ok = 0;
    p_glGetProgramiv(prog, GL_LINK_STATUS, &ok);
    if (ok == 0) {
        char log[1024] = {};
        GLsizei len = 0;
        p_glGetProgramInfoLog(prog, sizeof(log), &len, log);
        char msg[1200] = {};
        snprintf(msg, sizeof(msg), "GL program link failed: %s", log);
        throw std::runtime_error(msg);
    }
}

static UINT GetGLBackBufferIndex() {
    if (!g_glSwapChain3) return 0;
    return g_glSwapChain3->GetCurrentBackBufferIndex() & 1u;
}

static void InitOpenGL() {
    TRACE_ENTER();
    dbg("[GL] begin\n");

    // Create GL context
    g_glHDC = GetDC(g_hwnd);
    PIXELFORMATDESCRIPTOR pfd = {};
    pfd.nSize = sizeof(pfd); pfd.nVersion = 1;
    pfd.dwFlags = PFD_DRAW_TO_WINDOW | PFD_SUPPORT_OPENGL | PFD_DOUBLEBUFFER;
    pfd.iPixelType = PFD_TYPE_RGBA; pfd.cColorBits = 32; pfd.cDepthBits = 24;
    int pf = ChoosePixelFormat(g_glHDC, &pfd);
    if (pf == 0 || !SetPixelFormat(g_glHDC, pf, &pfd))
        throw std::runtime_error("SetPixelFormat failed");

    HGLRC tmpRC = wglCreateContext(g_glHDC);
    wglMakeCurrent(g_glHDC, tmpRC);
    p_wglCreateContextAttribsARB = (PFN_wglCreateContextAttribsARB)
        wglGetProcAddress("wglCreateContextAttribsARB");
    g_glHRC = p_wglCreateContextAttribsARB(g_glHDC, 0, NULL);
    wglMakeCurrent(g_glHDC, g_glHRC);
    wglDeleteContext(tmpRC);

    dbg("[GL] GL_VERSION = %s\n", (const char*)glGetString(GL_VERSION));
    LoadGLFunctions();

    if (!p_wglDXOpenDeviceNV)
        throw std::runtime_error("WGL_NV_DX_interop2 not available");

    // Create SwapChain for GL panel
    g_glSwapChain = CreateCompSwapChainWithAlpha(PANEL_W, PANEL_H, DXGI_ALPHA_MODE_IGNORE);
    TRACE_STATE("GL swap chain uses DXGI_ALPHA_MODE_IGNORE");
    HRESULT hr = g_glSwapChain->QueryInterface(__uuidof(IDXGISwapChain3), (void**)&g_glSwapChain3);
    TraceHr(__FUNCTION__, "IDXGISwapChain1::QueryInterface(IDXGISwapChain3)", hr);
    if (FAILED(hr)) {
        g_glSwapChain3 = nullptr;
        dbg("[GL] warning: IDXGISwapChain3 not available, fallback index=0\n");
    }

    // Set up DX interop
    g_glInteropDev = p_wglDXOpenDeviceNV(g_d3dDevice);
    if (!g_glInteropDev)
        throw std::runtime_error("wglDXOpenDeviceNV failed");
    p_glGenRenderbuffers(2, g_glRBO);
    p_glGenFramebuffers(2, g_glFBO);

    for (UINT i = 0; i < 2; ++i) {
        hr = g_glSwapChain->GetBuffer(i, __uuidof(ID3D11Texture2D), (void**)&g_glBackBuffer[i]);
        TraceHr(__FUNCTION__, (i == 0) ? "IDXGISwapChain1::GetBuffer(GL0)" : "IDXGISwapChain1::GetBuffer(GL1)", hr);
        if (FAILED(hr) || !g_glBackBuffer[i]) throw std::runtime_error("GL swap chain GetBuffer failed");

        g_glInteropObj[i] = p_wglDXRegisterObjectNV(
            g_glInteropDev, g_glBackBuffer[i], g_glRBO[i],
            GL_RENDERBUFFER, WGL_ACCESS_WRITE_DISCARD_NV);
        if (!g_glInteropObj[i]) throw std::runtime_error("wglDXRegisterObjectNV failed");

        if (!p_wglDXLockObjectsNV(g_glInteropDev, 1, &g_glInteropObj[i]))
            throw std::runtime_error("wglDXLockObjectsNV failed during GL init");

        p_glBindRenderbuffer(GL_RENDERBUFFER, g_glRBO[i]);
        p_glBindFramebuffer(GL_FRAMEBUFFER, g_glFBO[i]);
        p_glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, g_glRBO[i]);
        GLenum fboStatus = p_glCheckFramebufferStatus(GL_FRAMEBUFFER);
        if (fboStatus != GL_FRAMEBUFFER_COMPLETE) {
            char msg[128];
            snprintf(msg, sizeof(msg), "GL FBO[%u] not complete (status=0x%04X)", (unsigned)i, (unsigned)fboStatus);
            p_wglDXUnlockObjectsNV(g_glInteropDev, 1, &g_glInteropObj[i]);
            throw std::runtime_error(msg);
        }
        p_glBindFramebuffer(GL_FRAMEBUFFER, 0);
        p_wglDXUnlockObjectsNV(g_glInteropDev, 1, &g_glInteropObj[i]);
    }
    TRACE_STATE("GL interop objects registered for both back buffers");

    // Bind SwapChain to DComp visual
    hr = g_glVisual->SetContent(g_glSwapChain);
    TraceHr(__FUNCTION__, "IDCompositionVisual::SetContent(GL)", hr);
    if (FAILED(hr)) throw std::runtime_error("SetContent(GL) failed");

    // Create GL shaders and geometry
    p_glGenVertexArrays(1, &g_glVAO);
    p_glBindVertexArray(g_glVAO);
    p_glGenBuffers(2, g_glVBO);

    GLfloat verts[] = { 0.0f, 0.5f, 0.0f,  0.5f,-0.5f, 0.0f, -0.5f,-0.5f, 0.0f };
    GLfloat cols[]  = { 1.0f, 0.0f, 0.0f,  0.0f, 1.0f, 0.0f,  0.0f, 0.0f, 1.0f };
    p_glBindBuffer(GL_ARRAY_BUFFER, g_glVBO[0]);
    p_glBufferData(GL_ARRAY_BUFFER, sizeof(verts), verts, GL_STATIC_DRAW);
    p_glBindBuffer(GL_ARRAY_BUFFER, g_glVBO[1]);
    p_glBufferData(GL_ARRAY_BUFFER, sizeof(cols), cols, GL_STATIC_DRAW);

    const GLchar* vsSrc =
        "#version 460 core\n"
        "layout(location=0) in vec3 pos; layout(location=1) in vec3 col;\n"
        "out vec4 vCol;\n"
        "void main(){ vCol=vec4(col,1); gl_Position=vec4(pos.x,-pos.y,pos.z,1); }\n";
    const GLchar* fsSrc =
        "#version 460 core\n"
        "in vec4 vCol; out vec4 outCol;\n"
        "void main(){ outCol=vCol; }\n";

    GLuint vs = p_glCreateShader(GL_VERTEX_SHADER);
    p_glShaderSource(vs, 1, &vsSrc, nullptr); p_glCompileShader(vs);
    CheckGLShader(vs, "vertex shader");
    GLuint fs = p_glCreateShader(GL_FRAGMENT_SHADER);
    p_glShaderSource(fs, 1, &fsSrc, nullptr); p_glCompileShader(fs);
    CheckGLShader(fs, "fragment shader");
    g_glProgram = p_glCreateProgram();
    p_glAttachShader(g_glProgram, vs); p_glAttachShader(g_glProgram, fs);
    p_glLinkProgram(g_glProgram); p_glUseProgram(g_glProgram);
    CheckGLProgram(g_glProgram);

    g_glPosAttr = p_glGetAttribLocation(g_glProgram, "pos");
    g_glColAttr = p_glGetAttribLocation(g_glProgram, "col");
    dbg("[GL] attrib locations: pos=%d col=%d\n", (int)g_glPosAttr, (int)g_glColAttr);
    if (g_glPosAttr < 0 || g_glColAttr < 0) {
        throw std::runtime_error("GL attribute location lookup failed");
    }
    p_glEnableVertexAttribArray(g_glPosAttr);
    p_glEnableVertexAttribArray(g_glColAttr);

    dbg("[GL] ok\n");
}

static void RenderGL() {
    static bool loggedFirst = false;
    static uint64_t frameCount = 0;
    if (!loggedFirst) { TRACE_ENTER(); loggedFirst = true; }
    frameCount++;

    wglMakeCurrent(g_glHDC, g_glHRC);
    UINT idx = GetGLBackBufferIndex();
    if (frameCount == 1 || (frameCount % 300) == 0) {
        dbg("[GL] rendering with back buffer index=%u\n", idx);
    }
    if (!p_wglDXLockObjectsNV(g_glInteropDev, 1, &g_glInteropObj[idx])) {
        dbg("[GL] wglDXLockObjectsNV failed\n");
        return;
    }

    p_glBindFramebuffer(GL_FRAMEBUFFER, g_glFBO[idx]);
    glDrawBuffer(GL_COLOR_ATTACHMENT0);
    GLenum fboStatus = p_glCheckFramebufferStatus(GL_FRAMEBUFFER);
    if (fboStatus != GL_FRAMEBUFFER_COMPLETE) {
        dbg("[GL] runtime FBO not complete: 0x%04X\n", (unsigned)fboStatus);
    }
    glViewport(0, 0, PANEL_W, PANEL_H);
    glClearColor(0.05f, 0.05f, 0.15f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT);

    p_glUseProgram(g_glProgram);
    p_glBindVertexArray(g_glVAO);
    p_glBindBuffer(GL_ARRAY_BUFFER, g_glVBO[0]);
    p_glVertexAttribPointer(g_glPosAttr, 3, GL_FLOAT, GL_FALSE, 0, 0);
    p_glBindBuffer(GL_ARRAY_BUFFER, g_glVBO[1]);
    p_glVertexAttribPointer(g_glColAttr, 3, GL_FLOAT, GL_FALSE, 0, 0);
    glDrawArrays(GL_TRIANGLES, 0, 3);
    GLenum glerr = glGetError();
    if (glerr != GL_NO_ERROR) {
        dbg("[GL] glDrawArrays error=0x%04X\n", (unsigned)glerr);
    }

    if (frameCount == 1) {
        GLubyte px[4] = {};
        glReadPixels(PANEL_W / 2, PANEL_H / 2, 1, 1, GL_RGBA, GL_UNSIGNED_BYTE, px);
        dbg("[GL] sample pixel rgba=(%u,%u,%u,%u)\n",
            (unsigned)px[0], (unsigned)px[1], (unsigned)px[2], (unsigned)px[3]);
    }

    p_glBindFramebuffer(GL_FRAMEBUFFER, 0);
    glFlush();
    glFinish();
    if (!p_wglDXUnlockObjectsNV(g_glInteropDev, 1, &g_glInteropObj[idx])) {
        dbg("[GL] wglDXUnlockObjectsNV failed\n");
    }
    HRESULT hr = g_glSwapChain->Present(1, 0);
    if (FAILED(hr) || frameCount == 1 || (frameCount % 300) == 0) {
        TraceHr(__FUNCTION__, "IDXGISwapChain1::Present(GL)", hr);
    }
}

// ************************************************************
//  PANEL 1: D3D11 (native)
// ************************************************************
static const char* g_dxHLSL = R"(
struct VSI { float3 p:POSITION; float4 c:COLOR; };
struct PSI { float4 p:SV_POSITION; float4 c:COLOR; };
PSI VS(VSI i){ PSI o; o.p=float4(i.p,1); o.c=i.c; return o; }
float4 PS(PSI i):SV_Target{ return i.c; }
)";

struct DxVertex { float x,y,z, r,g,b,a; };

static void InitD3D11Panel() {
    TRACE_ENTER();
    dbg("[D3D11] init panel\n");

    g_dxSwapChain = CreateCompSwapChain(PANEL_W, PANEL_H);

    // RTV
    ID3D11Texture2D* bb = nullptr;
    g_dxSwapChain->GetBuffer(0, __uuidof(ID3D11Texture2D), (void**)&bb);
    g_d3dDevice->CreateRenderTargetView(bb, nullptr, &g_dxRTV);
    bb->Release();

    // Shaders
    ID3DBlob* vsBlob = nullptr; ID3DBlob* psBlob = nullptr; ID3DBlob* err = nullptr;
    D3DCompile(g_dxHLSL, strlen(g_dxHLSL), "dx", nullptr, nullptr, "VS", "vs_4_0", 0, 0, &vsBlob, &err);
    if (err) { dbg("[D3D11] VS err: %s\n", (char*)err->GetBufferPointer()); err->Release(); }
    D3DCompile(g_dxHLSL, strlen(g_dxHLSL), "dx", nullptr, nullptr, "PS", "ps_4_0", 0, 0, &psBlob, &err);
    if (err) { dbg("[D3D11] PS err: %s\n", (char*)err->GetBufferPointer()); err->Release(); }

    g_d3dDevice->CreateVertexShader(vsBlob->GetBufferPointer(), vsBlob->GetBufferSize(), nullptr, &g_dxVS);
    g_d3dDevice->CreatePixelShader(psBlob->GetBufferPointer(), psBlob->GetBufferSize(), nullptr, &g_dxPS);

    D3D11_INPUT_ELEMENT_DESC layout[] = {
        { "POSITION", 0, DXGI_FORMAT_R32G32B32_FLOAT,   0,  0, D3D11_INPUT_PER_VERTEX_DATA, 0 },
        { "COLOR",    0, DXGI_FORMAT_R32G32B32A32_FLOAT, 0, 12, D3D11_INPUT_PER_VERTEX_DATA, 0 },
    };
    g_d3dDevice->CreateInputLayout(layout, 2, vsBlob->GetBufferPointer(), vsBlob->GetBufferSize(), &g_dxInputLayout);
    vsBlob->Release(); psBlob->Release();

    // Vertex buffer
    DxVertex verts[] = {
        {  0.0f,  0.5f, 0.0f,  1,0,0,1 },
        {  0.5f, -0.5f, 0.0f,  0,1,0,1 },
        { -0.5f, -0.5f, 0.0f,  0,0,1,1 },
    };
    D3D11_BUFFER_DESC bd = {}; bd.ByteWidth = sizeof(verts);
    bd.Usage = D3D11_USAGE_DEFAULT; bd.BindFlags = D3D11_BIND_VERTEX_BUFFER;
    D3D11_SUBRESOURCE_DATA sd = {}; sd.pSysMem = verts;
    g_d3dDevice->CreateBuffer(&bd, &sd, &g_dxVertexBuffer);

    // Bind to DComp visual
    g_dxVisual->SetContent(g_dxSwapChain);
    dbg("[D3D11] panel ok\n");
}

static void RenderD3D11() {
    static bool loggedFirst = false;
    if (!loggedFirst) { TRACE_ENTER(); loggedFirst = true; }
    float clear[4] = { 0.05f, 0.15f, 0.05f, 1.0f };
    g_d3dContext->ClearRenderTargetView(g_dxRTV, clear);
    g_d3dContext->OMSetRenderTargets(1, &g_dxRTV, nullptr);

    D3D11_VIEWPORT vp = { 0, 0, (float)PANEL_W, (float)PANEL_H, 0, 1 };
    g_d3dContext->RSSetViewports(1, &vp);
    g_d3dContext->IASetInputLayout(g_dxInputLayout);
    UINT stride = sizeof(DxVertex), offset = 0;
    g_d3dContext->IASetVertexBuffers(0, 1, &g_dxVertexBuffer, &stride, &offset);
    g_d3dContext->IASetPrimitiveTopology(D3D11_PRIMITIVE_TOPOLOGY_TRIANGLELIST);
    g_d3dContext->VSSetShader(g_dxVS, nullptr, 0);
    g_d3dContext->PSSetShader(g_dxPS, nullptr, 0);
    g_d3dContext->Draw(3, 0);

    g_dxSwapChain->Present(1, 0);
}

// ************************************************************
//  PANEL 2: Vulkan (offscreen ?? staging ?? D3D11 copy)
// ************************************************************
static uint32_t VkFindMemType(uint32_t filter, VkMemoryPropertyFlags props) {
    VkPhysicalDeviceMemoryProperties mp;
    vkGetPhysicalDeviceMemoryProperties(g_vkPhysDev, &mp);
    for (uint32_t i = 0; i < mp.memoryTypeCount; i++)
        if ((filter & (1 << i)) && (mp.memoryTypes[i].propertyFlags & props) == props)
            return i;
    throw std::runtime_error("VkFindMemType failed");
}

static void InitVulkan() {
    TRACE_ENTER();
    dbg("[VK] begin\n");
    dbg("[VK] step1: create instance\n");

    // Instance (no surface extensions needed)
    VkApplicationInfo ai = {}; ai.sType = VK_STRUCTURE_TYPE_APPLICATION_INFO;
    ai.apiVersion = VK_API_VERSION_1_0;

    VkInstanceCreateInfo ici = {}; ici.sType = VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO;
    ici.pApplicationInfo = &ai;
    VkResult vr = vkCreateInstance(&ici, nullptr, &g_vkInst);
    TraceVk(__FUNCTION__, "vkCreateInstance", vr);
    if (vr != VK_SUCCESS) throw std::runtime_error("vkCreateInstance failed");
    dbg("[VK] step1 done: instance=%p\n", g_vkInst);

    // Physical device
    dbg("[VK] step2: enumerate physical devices\n");
    uint32_t cnt = 0;
    vr = vkEnumeratePhysicalDevices(g_vkInst, &cnt, nullptr);
    TraceVk(__FUNCTION__, "vkEnumeratePhysicalDevices(count)", vr);
    if (vr != VK_SUCCESS || cnt == 0) throw std::runtime_error("No Vulkan physical device");
    std::vector<VkPhysicalDevice> devs(cnt);
    vr = vkEnumeratePhysicalDevices(g_vkInst, &cnt, devs.data());
    TraceVk(__FUNCTION__, "vkEnumeratePhysicalDevices(list)", vr);
    if (vr != VK_SUCCESS) throw std::runtime_error("vkEnumeratePhysicalDevices list failed");
    for (auto& d : devs) {
        uint32_t qc = 0;
        vkGetPhysicalDeviceQueueFamilyProperties(d, &qc, nullptr);
        std::vector<VkQueueFamilyProperties> qp(qc);
        vkGetPhysicalDeviceQueueFamilyProperties(d, &qc, qp.data());
        for (uint32_t i = 0; i < qc; i++) {
            if (qp[i].queueFlags & VK_QUEUE_GRAPHICS_BIT) {
                g_vkPhysDev = d; g_vkQueueFamily = i; break;
            }
        }
        if (g_vkPhysDev) break;
    }
    if (!g_vkPhysDev) throw std::runtime_error("No graphics queue family found");
    dbg("[VK] step2 done: phys=%p queueFamily=%u\n", g_vkPhysDev, g_vkQueueFamily);

    // Logical device
    dbg("[VK] step3: create logical device\n");
    float prio = 1.0f;
    VkDeviceQueueCreateInfo qci = {}; qci.sType = VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO;
    qci.queueFamilyIndex = g_vkQueueFamily; qci.queueCount = 1; qci.pQueuePriorities = &prio;
    VkDeviceCreateInfo dci = {}; dci.sType = VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO;
    dci.queueCreateInfoCount = 1; dci.pQueueCreateInfos = &qci;
    vr = vkCreateDevice(g_vkPhysDev, &dci, nullptr, &g_vkDev);
    TraceVk(__FUNCTION__, "vkCreateDevice", vr);
    if (vr != VK_SUCCESS) throw std::runtime_error("vkCreateDevice failed");
    vkGetDeviceQueue(g_vkDev, g_vkQueueFamily, 0, &g_vkQueue);
    dbg("[VK] step3 done: device=%p queue=%p\n", g_vkDev, g_vkQueue);

    // Offscreen image (BGRA to match D3D11)
    VkImageCreateInfo imgci = {}; imgci.sType = VK_STRUCTURE_TYPE_IMAGE_CREATE_INFO;
    imgci.imageType = VK_IMAGE_TYPE_2D; imgci.format = VK_FORMAT_B8G8R8A8_UNORM;
    imgci.extent = { PANEL_W, PANEL_H, 1 }; imgci.mipLevels = 1; imgci.arrayLayers = 1;
    imgci.samples = VK_SAMPLE_COUNT_1_BIT; imgci.tiling = VK_IMAGE_TILING_OPTIMAL;
    imgci.usage = VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT | VK_IMAGE_USAGE_TRANSFER_SRC_BIT;
    dbg("[VK] step4: create offscreen resources\n");
    vkCreateImage(g_vkDev, &imgci, nullptr, &g_vkOffImage);

    VkMemoryRequirements mr; vkGetImageMemoryRequirements(g_vkDev, g_vkOffImage, &mr);
    VkMemoryAllocateInfo mai = {}; mai.sType = VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO;
    mai.allocationSize = mr.size;
    mai.memoryTypeIndex = VkFindMemType(mr.memoryTypeBits, VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT);
    vkAllocateMemory(g_vkDev, &mai, nullptr, &g_vkOffMemory);
    vkBindImageMemory(g_vkDev, g_vkOffImage, g_vkOffMemory, 0);

    VkImageViewCreateInfo ivci = {}; ivci.sType = VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO;
    ivci.image = g_vkOffImage; ivci.viewType = VK_IMAGE_VIEW_TYPE_2D;
    ivci.format = VK_FORMAT_B8G8R8A8_UNORM;
    ivci.subresourceRange = { VK_IMAGE_ASPECT_COLOR_BIT, 0, 1, 0, 1 };
    vkCreateImageView(g_vkDev, &ivci, nullptr, &g_vkOffView);
    dbg("[VK] step4 done\n");

    // Staging buffer
    dbg("[VK] step5: create staging buffer\n");
    VkDeviceSize bufSz = PANEL_W * PANEL_H * 4;
    VkBufferCreateInfo bci = {}; bci.sType = VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO;
    bci.size = bufSz; bci.usage = VK_BUFFER_USAGE_TRANSFER_DST_BIT;
    vkCreateBuffer(g_vkDev, &bci, nullptr, &g_vkStagBuf);
    vkGetBufferMemoryRequirements(g_vkDev, g_vkStagBuf, &mr);
    mai.allocationSize = mr.size;
    mai.memoryTypeIndex = VkFindMemType(mr.memoryTypeBits,
        VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | VK_MEMORY_PROPERTY_HOST_COHERENT_BIT);
    vkAllocateMemory(g_vkDev, &mai, nullptr, &g_vkStagMem);
    vkBindBufferMemory(g_vkDev, g_vkStagBuf, g_vkStagMem, 0);
    dbg("[VK] step5 done\n");

    // Render pass
    VkAttachmentDescription att = {}; att.format = VK_FORMAT_B8G8R8A8_UNORM;
    att.samples = VK_SAMPLE_COUNT_1_BIT; att.loadOp = VK_ATTACHMENT_LOAD_OP_CLEAR;
    att.storeOp = VK_ATTACHMENT_STORE_OP_STORE;
    att.stencilLoadOp = VK_ATTACHMENT_LOAD_OP_DONT_CARE;
    att.stencilStoreOp = VK_ATTACHMENT_STORE_OP_DONT_CARE;
    att.initialLayout = VK_IMAGE_LAYOUT_UNDEFINED;
    att.finalLayout = VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL;

    VkAttachmentReference ref = { 0, VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL };
    VkSubpassDescription sub = {}; sub.pipelineBindPoint = VK_PIPELINE_BIND_POINT_GRAPHICS;
    sub.colorAttachmentCount = 1; sub.pColorAttachments = &ref;

    VkRenderPassCreateInfo rpci = {}; rpci.sType = VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO;
    rpci.attachmentCount = 1; rpci.pAttachments = &att;
    rpci.subpassCount = 1; rpci.pSubpasses = &sub;
    vkCreateRenderPass(g_vkDev, &rpci, nullptr, &g_vkRenderPass);

    // Framebuffer
    VkFramebufferCreateInfo fci = {}; fci.sType = VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO;
    fci.renderPass = g_vkRenderPass; fci.attachmentCount = 1; fci.pAttachments = &g_vkOffView;
    fci.width = PANEL_W; fci.height = PANEL_H; fci.layers = 1;
    vkCreateFramebuffer(g_vkDev, &fci, nullptr, &g_vkFramebuffer);

    // Pipeline
    dbg("[VK] step6: load shaders\n");
    auto vertCode = readFile("hello_vert.spv");
    auto fragCode = readFile("hello_frag.spv");
    dbg("[VK] shader sizes: vert=%zu frag=%zu\n", vertCode.size(), fragCode.size());
    VkShaderModuleCreateInfo smci = {}; smci.sType = VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO;
    smci.codeSize = vertCode.size(); smci.pCode = (const uint32_t*)vertCode.data();
    VkShaderModule vertMod; vkCreateShaderModule(g_vkDev, &smci, nullptr, &vertMod);
    smci.codeSize = fragCode.size(); smci.pCode = (const uint32_t*)fragCode.data();
    VkShaderModule fragMod; vkCreateShaderModule(g_vkDev, &smci, nullptr, &fragMod);

    VkPipelineShaderStageCreateInfo stages[2] = {};
    stages[0].sType = VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO;
    stages[0].stage = VK_SHADER_STAGE_VERTEX_BIT; stages[0].module = vertMod; stages[0].pName = "main";
    stages[1].sType = VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO;
    stages[1].stage = VK_SHADER_STAGE_FRAGMENT_BIT; stages[1].module = fragMod; stages[1].pName = "main";

    VkPipelineVertexInputStateCreateInfo viState = {};
    viState.sType = VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO;
    VkPipelineInputAssemblyStateCreateInfo iaState = {};
    iaState.sType = VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO;
    iaState.topology = VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST;

    VkViewport vp = { 0, 0, (float)PANEL_W, (float)PANEL_H, 0, 1 };
    VkRect2D sc = { {0,0}, {PANEL_W, PANEL_H} };
    VkPipelineViewportStateCreateInfo vpState = {};
    vpState.sType = VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO;
    vpState.viewportCount = 1; vpState.pViewports = &vp;
    vpState.scissorCount = 1; vpState.pScissors = &sc;

    VkPipelineRasterizationStateCreateInfo rsState = {};
    rsState.sType = VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO;
    rsState.polygonMode = VK_POLYGON_MODE_FILL; rsState.lineWidth = 1.0f;
    rsState.cullMode = VK_CULL_MODE_BACK_BIT; rsState.frontFace = VK_FRONT_FACE_CLOCKWISE;

    VkPipelineMultisampleStateCreateInfo msState = {};
    msState.sType = VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO;
    msState.rasterizationSamples = VK_SAMPLE_COUNT_1_BIT;

    VkPipelineColorBlendAttachmentState cbAtt = {};
    cbAtt.colorWriteMask = 0xF;
    VkPipelineColorBlendStateCreateInfo cbState = {};
    cbState.sType = VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO;
    cbState.attachmentCount = 1; cbState.pAttachments = &cbAtt;

    VkPipelineLayoutCreateInfo plci = {}; plci.sType = VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO;
    vkCreatePipelineLayout(g_vkDev, &plci, nullptr, &g_vkPipeLayout);

    VkGraphicsPipelineCreateInfo pci = {}; pci.sType = VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO;
    pci.stageCount = 2; pci.pStages = stages;
    pci.pVertexInputState = &viState; pci.pInputAssemblyState = &iaState;
    pci.pViewportState = &vpState; pci.pRasterizationState = &rsState;
    pci.pMultisampleState = &msState; pci.pColorBlendState = &cbState;
    pci.layout = g_vkPipeLayout; pci.renderPass = g_vkRenderPass;
    vr = vkCreateGraphicsPipelines(g_vkDev, VK_NULL_HANDLE, 1, &pci, nullptr, &g_vkPipeline);
    TraceVk(__FUNCTION__, "vkCreateGraphicsPipelines", vr);
    if (vr != VK_SUCCESS) throw std::runtime_error("vkCreateGraphicsPipelines failed");
    vkDestroyShaderModule(g_vkDev, vertMod, nullptr);
    vkDestroyShaderModule(g_vkDev, fragMod, nullptr);
    dbg("[VK] step6 done: graphics pipeline created\n");

    // Command pool / buffer / fence
    dbg("[VK] step7: create command objects\n");
    VkCommandPoolCreateInfo cpci = {}; cpci.sType = VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO;
    cpci.flags = VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT;
    cpci.queueFamilyIndex = g_vkQueueFamily;
    vkCreateCommandPool(g_vkDev, &cpci, nullptr, &g_vkCmdPool);

    VkCommandBufferAllocateInfo cbai = {}; cbai.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO;
    cbai.commandPool = g_vkCmdPool; cbai.level = VK_COMMAND_BUFFER_LEVEL_PRIMARY;
    cbai.commandBufferCount = 1;
    vkAllocateCommandBuffers(g_vkDev, &cbai, &g_vkCmdBuf);

    VkFenceCreateInfo fnci = {}; fnci.sType = VK_STRUCTURE_TYPE_FENCE_CREATE_INFO;
    fnci.flags = VK_FENCE_CREATE_SIGNALED_BIT;
    vkCreateFence(g_vkDev, &fnci, nullptr, &g_vkFence);
    dbg("[VK] step7 done\n");

    // D3D11 swap chain + staging for Vulkan panel
    dbg("[VK] step8: create D3D interop swap chain\n");
    g_vkSwapChain = CreateCompSwapChain(PANEL_W, PANEL_H);
    HRESULT hr = g_vkSwapChain->GetBuffer(0, __uuidof(ID3D11Texture2D), (void**)&g_vkBackBuffer);
    TraceHr(__FUNCTION__, "IDXGISwapChain1::GetBuffer(VK)", hr);
    if (FAILED(hr)) throw std::runtime_error("VK swap chain GetBuffer failed");

    D3D11_TEXTURE2D_DESC td = {}; td.Width = PANEL_W; td.Height = PANEL_H;
    td.MipLevels = 1; td.ArraySize = 1; td.Format = DXGI_FORMAT_B8G8R8A8_UNORM;
    td.SampleDesc = { 1, 0 }; td.Usage = D3D11_USAGE_STAGING;
    td.CPUAccessFlags = D3D11_CPU_ACCESS_WRITE;
    hr = g_d3dDevice->CreateTexture2D(&td, nullptr, &g_vkStagingTex);
    TraceHr(__FUNCTION__, "ID3D11Device::CreateTexture2D(VK staging)", hr);
    if (FAILED(hr)) throw std::runtime_error("CreateTexture2D(VK staging) failed");

    hr = g_vkVisual->SetContent(g_vkSwapChain);
    TraceHr(__FUNCTION__, "IDCompositionVisual::SetContent(VK)", hr);
    if (FAILED(hr)) throw std::runtime_error("SetContent(VK) failed");
    dbg("[VK] step8 done\n");
    dbg("[VK] ok\n");
    TRACE_STATE("Vulkan panel initialized");
}

static void RenderVulkan() {
    static bool loggedFirst = false;
    if (!loggedFirst) { TRACE_ENTER(); loggedFirst = true; }
    vkWaitForFences(g_vkDev, 1, &g_vkFence, VK_TRUE, UINT64_MAX);
    vkResetFences(g_vkDev, 1, &g_vkFence);
    vkResetCommandBuffer(g_vkCmdBuf, 0);

    VkCommandBufferBeginInfo bi = {}; bi.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO;
    vkBeginCommandBuffer(g_vkCmdBuf, &bi);

    VkRenderPassBeginInfo rpbi = {}; rpbi.sType = VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO;
    rpbi.renderPass = g_vkRenderPass; rpbi.framebuffer = g_vkFramebuffer;
    rpbi.renderArea.extent = { PANEL_W, PANEL_H };
    VkClearValue cv = {}; cv.color = { { 0.15f, 0.05f, 0.05f, 1.0f } };
    rpbi.clearValueCount = 1; rpbi.pClearValues = &cv;

    vkCmdBeginRenderPass(g_vkCmdBuf, &rpbi, VK_SUBPASS_CONTENTS_INLINE);
    vkCmdBindPipeline(g_vkCmdBuf, VK_PIPELINE_BIND_POINT_GRAPHICS, g_vkPipeline);
    vkCmdDraw(g_vkCmdBuf, 3, 1, 0, 0);
    vkCmdEndRenderPass(g_vkCmdBuf);

    VkBufferImageCopy region = {}; region.bufferRowLength = PANEL_W;
    region.bufferImageHeight = PANEL_H;
    region.imageSubresource = { VK_IMAGE_ASPECT_COLOR_BIT, 0, 0, 1 };
    region.imageExtent = { PANEL_W, PANEL_H, 1 };
    vkCmdCopyImageToBuffer(g_vkCmdBuf, g_vkOffImage,
        VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL, g_vkStagBuf, 1, &region);
    vkEndCommandBuffer(g_vkCmdBuf);

    VkSubmitInfo si = {}; si.sType = VK_STRUCTURE_TYPE_SUBMIT_INFO;
    si.commandBufferCount = 1; si.pCommandBuffers = &g_vkCmdBuf;
    vkQueueSubmit(g_vkQueue, 1, &si, g_vkFence);
    vkWaitForFences(g_vkDev, 1, &g_vkFence, VK_TRUE, UINT64_MAX);

    // Copy Vulkan staging ?? D3D11 staging ?? back buffer
    void* vkData = nullptr;
    vkMapMemory(g_vkDev, g_vkStagMem, 0, PANEL_W * PANEL_H * 4, 0, &vkData);
    D3D11_MAPPED_SUBRESOURCE mapped = {};
    if (SUCCEEDED(g_d3dContext->Map(g_vkStagingTex, 0, D3D11_MAP_WRITE, 0, &mapped))) {
        const uint8_t* src = (const uint8_t*)vkData;
        uint8_t* dst = (uint8_t*)mapped.pData;
        uint32_t pitch = PANEL_W * 4;
        for (uint32_t y = 0; y < PANEL_H; y++)
            memcpy(dst + y * mapped.RowPitch, src + y * pitch, pitch);
        g_d3dContext->Unmap(g_vkStagingTex, 0);
    }
    vkUnmapMemory(g_vkDev, g_vkStagMem);

    g_d3dContext->CopyResource(g_vkBackBuffer, g_vkStagingTex);
    g_vkSwapChain->Present(1, 0);
}

// ************************************************************
//  Commit composition tree
// ************************************************************
static void CommitComposition() {
    TRACE_ENTER();
    HRESULT hr = g_dcompDevice->Commit();
    TraceHr(__FUNCTION__, "IDCompositionDevice::Commit", hr);
    dbg("[Main] DComp Commit ok - entering WTL message loop\n");
}

// ************************************************************
//  Cleanup
// ************************************************************
static void CleanupAll() {
    TRACE_ENTER();
    dbg("[Cleanup] begin\n");

    // Vulkan
    if (g_vkDev) {
        vkDeviceWaitIdle(g_vkDev);
        vkDestroyFence(g_vkDev, g_vkFence, nullptr);
        vkDestroyCommandPool(g_vkDev, g_vkCmdPool, nullptr);
        vkDestroyPipeline(g_vkDev, g_vkPipeline, nullptr);
        vkDestroyPipelineLayout(g_vkDev, g_vkPipeLayout, nullptr);
        vkDestroyFramebuffer(g_vkDev, g_vkFramebuffer, nullptr);
        vkDestroyRenderPass(g_vkDev, g_vkRenderPass, nullptr);
        vkDestroyImageView(g_vkDev, g_vkOffView, nullptr);
        vkDestroyImage(g_vkDev, g_vkOffImage, nullptr);
        vkFreeMemory(g_vkDev, g_vkOffMemory, nullptr);
        vkDestroyBuffer(g_vkDev, g_vkStagBuf, nullptr);
        vkFreeMemory(g_vkDev, g_vkStagMem, nullptr);
        vkDestroyDevice(g_vkDev, nullptr);
    }
    if (g_vkInst) vkDestroyInstance(g_vkInst, nullptr);
    SafeRelease(&g_vkStagingTex);
    SafeRelease(&g_vkBackBuffer);
    SafeRelease(&g_vkSwapChain);

    // OpenGL
    if (g_glInteropObj[0]) p_wglDXUnregisterObjectNV(g_glInteropDev, g_glInteropObj[0]);
    if (g_glInteropObj[1]) p_wglDXUnregisterObjectNV(g_glInteropDev, g_glInteropObj[1]);
    if (g_glInteropDev) p_wglDXCloseDeviceNV(g_glInteropDev);
    if (g_glHRC) { wglMakeCurrent(nullptr, nullptr); wglDeleteContext(g_glHRC); }
    if (g_glHDC) ReleaseDC(g_hwnd, g_glHDC);
    SafeRelease(&g_glBackBuffer[0]);
    SafeRelease(&g_glBackBuffer[1]);
    SafeRelease(&g_glSwapChain3);
    SafeRelease(&g_glSwapChain);

    // D3D11 panel
    SafeRelease(&g_dxVertexBuffer);
    SafeRelease(&g_dxInputLayout);
    SafeRelease(&g_dxPS);
    SafeRelease(&g_dxVS);
    SafeRelease(&g_dxRTV);
    SafeRelease(&g_dxSwapChain);

    // DComp
    SafeRelease(&g_vkVisual);
    SafeRelease(&g_dxVisual);
    SafeRelease(&g_glVisual);
    SafeRelease(&g_rootVisual);
    SafeRelease(&g_dcompTarget);
    SafeRelease(&g_dcompDevice);

    // Shared D3D11
    SafeRelease(&g_d3dContext);
    SafeRelease(&g_d3dDevice);

    g_isReadyForRender = false;
    g_firstFrameLogged = false;
    dbg("[Cleanup] done\n");
}

// ============================================================
// Entry point
// ============================================================
int APIENTRY _tWinMain(HINSTANCE hInstance, HINSTANCE, LPTSTR, int nCmdShow) {
    TRACE_ENTER();
    char exePath[MAX_PATH] = {};
    char cwd[MAX_PATH] = {};
    GetModuleFileNameA(nullptr, exePath, MAX_PATH);
    GetCurrentDirectoryA(MAX_PATH, cwd);
    dbg("================================================\n");
    dbg("OpenGL + D3D11 + Vulkan via DirectComposition\n");
    dbg("3 panels in 1 window, each a separate SwapChain\n");
    dbg("================================================\n");
    dbg("[Main] exe=%s\n", exePath);
    dbg("[Main] cwd=%s\n", cwd);

    _Module.Init(nullptr, hInstance);
    CMessageLoop theLoop;
    _Module.AddMessageLoop(&theLoop);

    int nRet = 0;
    try {
        CHelloWindow wnd;
        RECT rc = { 0, 0, (LONG)WINDOW_W, (LONG)WINDOW_H };
        if (!wnd.Create(nullptr, rc, _T("OpenGL + D3D11 + Vulkan (DirectComposition)"), WS_OVERLAPPEDWINDOW | WS_VISIBLE)) {
            throw std::runtime_error("CHelloWindow::Create failed");
        }
        wnd.ResizeClient(WINDOW_W, WINDOW_H);
        wnd.ShowWindow(nCmdShow);
        g_hwnd = wnd.m_hWnd;
        dbg("[Window] HWND=%p\n", g_hwnd);

        CreateD3D11Device();
        InitDirectComposition();

        InitOpenGL();           // Panel 0 (left)   - GL via WGL_NV_DX_interop2
        InitD3D11Panel();       // Panel 1 (center) - D3D11 native
        try {
            InitVulkan();       // Panel 2 (right)  - VK via staging buffer
            g_vkEnabled = true;
        } catch (const std::exception& e) {
            g_vkEnabled = false;
            dbg("[WARN] Vulkan disabled: %s\n", e.what());
        }

        CommitComposition();
        g_isReadyForRender = true;
        nRet = theLoop.Run();
    } catch (const std::exception& e) {
        dbg("[FATAL] %s\n", e.what());
        MessageBoxA(nullptr, e.what(), "Error", MB_OK | MB_ICONERROR);
        nRet = -1;
    }

    CleanupAll();
    _Module.RemoveMessageLoop();
    _Module.Term();
    dbg("[Main] exit\n");
    return nRet;
}
