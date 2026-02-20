// hello_wuc_multi.cpp - OpenGL + D3D11 + Vulkan Triangles via Windows.UI.Composition
//
// [C++/CLI Build Compatible Version]
//
// Summary of changes from the original:
//   - The entire file is wrapped with #pragma managed(push, off) / #pragma managed(pop)
//     so that all code in this file is compiled as native (unmanaged) code.
//   - /EHa is used instead of /EHsc because /clr changes the exception model
//     and requires SEH-compatible exception handling.
//   - #pragma comment(linker, "/ENTRY:wWinMainCRTStartup") is added because
//     wWinMain may not be recognized as the entry point automatically under /clr.
//   - Standard exceptions such as std::runtime_error are usable inside #pragma managed(off).
//   - No other logic has been changed from the original code.
//
// Build (Visual Studio Developer Command Prompt):
//   build_clr.bat
//
// Architecture:
//   Uses Windows.UI.Composition (WinRT) instead of DirectComposition.
//   Each panel has its own SwapChainForComposition, wrapped as:
//     SwapChain -> ICompositionSurface -> ICompositionSurfaceBrush -> ISpriteVisual
//   All three SpriteVisuals are children of one ContainerVisual.
//
//   ------------------------ One HWND ---------------------
//   | SpriteVisual 0   | SpriteVisual 1  | SpriteVisual 2 |
//   | OpenGL 4.6       | D3D11           | Vulkan         |
//   | Offset(0,0,0)    | Offset(320,0,0) | Offset(640,0,0)|
//   -------------------------------------------------------

// ============================================================
// [C++/CLI] Treat everything below as native (unmanaged) code
// ============================================================
#pragma managed(push, off)

#define WIN32_LEAN_AND_MEAN
#define NOMINMAX
#include <windows.h>
#include <d3d11.h>
#include <dxgi1_2.h>
#include <d3dcompiler.h>
#include <gl/gl.h>

#define VK_USE_PLATFORM_WIN32_KHR
#include <vulkan/vulkan.h>

// WinRT / Composition headers
#include <roapi.h>
#include <winstring.h>
#include <windows.ui.composition.h>
#include <windows.ui.composition.desktop.h>
#include <windows.ui.composition.interop.h>

#include <vector>
#include <fstream>
#include <string>
#include <cstdio>
#include <cstdarg>
#include <cstring>
#include <stdexcept>

#pragma comment(lib, "d3d11.lib")
#pragma comment(lib, "dxgi.lib")
#pragma comment(lib, "d3dcompiler.lib")
#pragma comment(lib, "opengl32.lib")
#pragma comment(lib, "user32.lib")
#pragma comment(lib, "gdi32.lib")
#pragma comment(lib, "RuntimeObject.lib")

// [C++/CLI] Explicitly specify the entry point because /clr may not
// automatically recognize wWinMain as the executable entry point.
#pragma comment(linker, "/ENTRY:wWinMainCRTStartup")

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

// ============================================================
// COM Interop interfaces - manual definition required.
// SDK 10.0.26100.0's windows.ui.composition.interop.h only
// contains WinRT ABI type declarations, NOT these COM interfaces.
// ============================================================

// ICompositorInterop {25297D5C-3AD4-4C9C-B5CF-E36A38512330}
MIDL_INTERFACE("25297D5C-3AD4-4C9C-B5CF-E36A38512330")
ICompositorInterop : public IUnknown {
public:
    virtual HRESULT STDMETHODCALLTYPE CreateCompositionSurfaceForHandle(
        HANDLE swapChain,
        ABI::Windows::UI::Composition::ICompositionSurface** result) = 0;
    virtual HRESULT STDMETHODCALLTYPE CreateCompositionSurfaceForSwapChain(
        IUnknown* swapChain,
        ABI::Windows::UI::Composition::ICompositionSurface** result) = 0;
    virtual HRESULT STDMETHODCALLTYPE CreateGraphicsDevice(
        IUnknown* renderingDevice,
        ABI::Windows::UI::Composition::ICompositionGraphicsDevice** result) = 0;
};

// ICompositorDesktopInterop {29E691FA-4567-4DCA-B319-D0F207EB6807}
MIDL_INTERFACE("29E691FA-4567-4DCA-B319-D0F207EB6807")
ICompositorDesktopInterop : public IUnknown {
public:
    virtual HRESULT STDMETHODCALLTYPE CreateDesktopWindowTarget(
        HWND hwndTarget,
        BOOL isTopmost,
        ABI::Windows::UI::Composition::Desktop::IDesktopWindowTarget** result) = 0;
    virtual HRESULT STDMETHODCALLTYPE EnsureOnThread(DWORD threadId) = 0;
};

// ============================================================
// DispatcherQueueController - dynamically loaded from CoreMessaging.dll
// ============================================================
typedef HRESULT(WINAPI* PFN_CreateDispatcherQueueController)(
    struct DispatcherQueueOptions, ABI::Windows::System::IDispatcherQueueController**);

struct DispatcherQueueOptions {
    DWORD dwSize;
    DWORD threadType;    // DQTYPE_THREAD_DEDICATED=1, DQTYPE_THREAD_CURRENT=2
    DWORD apartmentType; // DQTAT_COM_NONE=0, DQTAT_COM_ASTA=1, DQTAT_COM_STA=2
};

// ============================================================
// Constants
// ============================================================
static const uint32_t PANEL_W = 320;
static const uint32_t PANEL_H = 480;
static const uint32_t WINDOW_W = PANEL_W * 3;
static const uint32_t WINDOW_H = PANEL_H;

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
    if (!file.is_open()) throw std::runtime_error("failed to open file: " + filename);
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

// GL function pointers
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
// Namespace aliases for ABI types
// ============================================================
namespace WUC  = ABI::Windows::UI::Composition;
namespace WUCD = ABI::Windows::UI::Composition::Desktop;
namespace WFN  = ABI::Windows::Foundation::Numerics;

// ============================================================
// Global state
// ============================================================

// Win32
static HWND g_hwnd = nullptr;

// Tracks whether RoInitialize actually initialized WinRT on this thread.
// Under /clr the CLR pre-initializes COM as MTA, so RoInitialize returns
// RPC_E_CHANGED_MODE (non-fatal). We must only call RoUninitialize when
// we ourselves successfully called RoInitialize.
static bool g_roInitialized = false;

// Shared D3D11 device
static ID3D11Device*        g_d3dDevice  = nullptr;
static ID3D11DeviceContext*  g_d3dContext = nullptr;

// Windows.UI.Composition
static WUC::ICompositor*                      g_compositor     = nullptr;
static ICompositorInterop*                     g_compInterop    = nullptr;
static ICompositorDesktopInterop*              g_compDesktopInt = nullptr;
static WUCD::IDesktopWindowTarget*             g_windowTarget   = nullptr;
static WUC::ICompositionTarget*               g_compTarget     = nullptr;
static WUC::IContainerVisual*                  g_rootContainer  = nullptr;
static WUC::IVisual*                           g_rootVisual     = nullptr;
static WUC::IVisualCollection*                 g_children       = nullptr;
static ABI::Windows::System::IDispatcherQueueController* g_dqController = nullptr;

// --- Panel 0: OpenGL ---
static IDXGISwapChain1*             g_glSwapChain    = nullptr;
static ID3D11Texture2D*             g_glBackBuffer   = nullptr;
static WUC::ICompositionSurface*    g_glSurface      = nullptr;
static WUC::ISpriteVisual*          g_glSprite       = nullptr;
static HDC                          g_glHDC          = nullptr;
static HGLRC                        g_glHRC          = nullptr;
static HANDLE                       g_glInteropDev   = nullptr;
static HANDLE                       g_glInteropObj   = nullptr;
static GLuint                       g_glRBO = 0, g_glFBO = 0;
static GLuint                       g_glProgram = 0, g_glVAO = 0, g_glVBO[2] = {};
static GLint                        g_glPosAttr = -1, g_glColAttr = -1;

// --- Panel 1: D3D11 ---
static IDXGISwapChain1*             g_dxSwapChain    = nullptr;
static ID3D11RenderTargetView*      g_dxRTV          = nullptr;
static WUC::ICompositionSurface*    g_dxSurface      = nullptr;
static WUC::ISpriteVisual*          g_dxSprite       = nullptr;
static ID3D11VertexShader*          g_dxVS           = nullptr;
static ID3D11PixelShader*           g_dxPS           = nullptr;
static ID3D11InputLayout*           g_dxInputLayout  = nullptr;
static ID3D11Buffer*                g_dxVertexBuffer = nullptr;

// --- Panel 2: Vulkan ---
static IDXGISwapChain1*             g_vkSwapChain    = nullptr;
static ID3D11Texture2D*             g_vkBackBuffer   = nullptr;
static ID3D11Texture2D*             g_vkStagingTex   = nullptr;
static WUC::ICompositionSurface*    g_vkSurface      = nullptr;
static WUC::ISpriteVisual*          g_vkSprite       = nullptr;
static VkInstance       g_vkInst        = VK_NULL_HANDLE;
static VkPhysicalDevice g_vkPhysDev     = VK_NULL_HANDLE;
static VkDevice         g_vkDev         = VK_NULL_HANDLE;
static VkQueue          g_vkQueue       = VK_NULL_HANDLE;
static uint32_t         g_vkQueueFamily = 0;
static VkImage          g_vkOffImage    = VK_NULL_HANDLE;
static VkDeviceMemory   g_vkOffMemory   = VK_NULL_HANDLE;
static VkImageView      g_vkOffView     = VK_NULL_HANDLE;
static VkRenderPass     g_vkRenderPass  = VK_NULL_HANDLE;
static VkFramebuffer    g_vkFramebuffer = VK_NULL_HANDLE;
static VkPipelineLayout g_vkPipeLayout  = VK_NULL_HANDLE;
static VkPipeline       g_vkPipeline    = VK_NULL_HANDLE;
static VkCommandPool    g_vkCmdPool     = VK_NULL_HANDLE;
static VkCommandBuffer  g_vkCmdBuf      = VK_NULL_HANDLE;
static VkFence          g_vkFence       = VK_NULL_HANDLE;
static VkBuffer         g_vkStagBuf     = VK_NULL_HANDLE;
static VkDeviceMemory   g_vkStagMem     = VK_NULL_HANDLE;

// ============================================================
// Window procedure
// ============================================================
static LRESULT CALLBACK WndProc(HWND h, UINT m, WPARAM w, LPARAM l) {
    if (m == WM_DESTROY || (m == WM_KEYDOWN && w == VK_ESCAPE)) {
        PostQuitMessage(0); return 0;
    }
    return DefWindowProcW(h, m, w, l);
}

// ============================================================
// Create Win32 window
// ============================================================
static void CreateAppWindow() {
    dbg("[Window] begin\n");
    WNDCLASSEXW wc = {};
    wc.cbSize = sizeof(wc); wc.style = CS_OWNDC;
    wc.lpfnWndProc = WndProc; wc.hInstance = GetModuleHandle(nullptr);
    wc.hCursor = LoadCursor(nullptr, IDC_ARROW);
    wc.hbrBackground = (HBRUSH)GetStockObject(BLACK_BRUSH);
    wc.lpszClassName = L"WUCMultiClass";
    RegisterClassExW(&wc);

    RECT rc = { 0, 0, (LONG)WINDOW_W, (LONG)WINDOW_H };
    AdjustWindowRect(&rc, WS_OVERLAPPEDWINDOW, FALSE);
    g_hwnd = CreateWindowExW(0, wc.lpszClassName,
        L"OpenGL + D3D11 + Vulkan (Windows.UI.Composition)",
        WS_OVERLAPPEDWINDOW, CW_USEDEFAULT, CW_USEDEFAULT,
        rc.right - rc.left, rc.bottom - rc.top,
        nullptr, nullptr, wc.hInstance, nullptr);
    ShowWindow(g_hwnd, SW_SHOW);
    dbg("[Window] HWND=%p\n", g_hwnd);
}

// ============================================================
// Create shared D3D11 device
// ============================================================
static void CreateD3D11Device() {
    dbg("[D3D11] creating shared device\n");
    D3D_FEATURE_LEVEL level = D3D_FEATURE_LEVEL_11_0;
    HRESULT hr = D3D11CreateDevice(nullptr, D3D_DRIVER_TYPE_HARDWARE, nullptr,
        D3D11_CREATE_DEVICE_BGRA_SUPPORT, &level, 1, D3D11_SDK_VERSION,
        &g_d3dDevice, nullptr, &g_d3dContext);
    if (FAILED(hr)) throw std::runtime_error("D3D11CreateDevice failed");
    dbg("[D3D11] Device=%p\n", g_d3dDevice);
}

// ============================================================
// Helper: create a SwapChainForComposition
// ============================================================
static IDXGISwapChain1* CreateCompSwapChain(uint32_t w, uint32_t h) {
    IDXGIDevice* dxgiDev = nullptr;
    g_d3dDevice->QueryInterface(__uuidof(IDXGIDevice), (void**)&dxgiDev);
    IDXGIAdapter* adapter = nullptr;
    dxgiDev->GetAdapter(&adapter);
    IDXGIFactory2* factory = nullptr;
    adapter->GetParent(__uuidof(IDXGIFactory2), (void**)&factory);
    adapter->Release();

    DXGI_SWAP_CHAIN_DESC1 scd = {};
    scd.Width = w; scd.Height = h;
    scd.Format = DXGI_FORMAT_B8G8R8A8_UNORM;
    scd.SampleDesc = { 1, 0 };
    scd.BufferUsage = DXGI_USAGE_RENDER_TARGET_OUTPUT;
    scd.BufferCount = 2;
    scd.SwapEffect = DXGI_SWAP_EFFECT_FLIP_SEQUENTIAL;
    scd.AlphaMode = DXGI_ALPHA_MODE_PREMULTIPLIED;

    IDXGISwapChain1* sc = nullptr;
    factory->CreateSwapChainForComposition(g_d3dDevice, &scd, nullptr, &sc);
    factory->Release(); dxgiDev->Release();
    return sc;
}

// ============================================================
// Initialize Windows.UI.Composition
// ============================================================
static void InitComposition() {
    dbg("[WUC] begin\n");
    HRESULT hr;

    // Initialize WinRT.
    // Under /clr the CLR pre-initializes COM as MTA before wWinMain runs,
    // so RoInitialize(STA) returns RPC_E_CHANGED_MODE (0x80010106).
    // That is not a true failure: WinRT is still usable because the
    // DispatcherQueue created below provides the required STA context.
    hr = RoInitialize(RO_INIT_SINGLETHREADED);
    if (SUCCEEDED(hr)) {
        g_roInitialized = true;
        dbg("[WUC] RoInitialize ok (STA)\n");
    } else if (hr == RPC_E_CHANGED_MODE) {
        dbg("[WUC] RoInitialize: RPC_E_CHANGED_MODE (CLR pre-initialized COM as MTA) - continuing\n");
    } else {
        throw std::runtime_error("RoInitialize failed");
    }

    HMODULE hCoreMsgDll = LoadLibraryW(L"CoreMessaging.dll");
    if (!hCoreMsgDll) throw std::runtime_error("LoadLibrary CoreMessaging.dll failed");

    auto pfnCreateDQC = (PFN_CreateDispatcherQueueController)
        GetProcAddress(hCoreMsgDll, "CreateDispatcherQueueController");
    if (!pfnCreateDQC) throw std::runtime_error("CreateDispatcherQueueController not found");

    DispatcherQueueOptions dqOpts = {};
    dqOpts.dwSize = sizeof(dqOpts);
    dqOpts.threadType = 2;
    dqOpts.apartmentType = 2;

    hr = pfnCreateDQC(dqOpts, &g_dqController);
    if (FAILED(hr)) throw std::runtime_error("CreateDispatcherQueueController failed");
    dbg("[WUC] DispatcherQueue created\n");

    HSTRING hsCompositor = nullptr;
    HSTRING_HEADER hsHeader;
    const wchar_t className[] = L"Windows.UI.Composition.Compositor";
    hr = WindowsCreateStringReference(className, (UINT32)wcslen(className), &hsHeader, &hsCompositor);
    if (FAILED(hr)) throw std::runtime_error("WindowsCreateStringReference failed");

    IInspectable* inspectable = nullptr;
    hr = RoActivateInstance(hsCompositor, &inspectable);
    if (FAILED(hr)) throw std::runtime_error("RoActivateInstance Compositor failed");

    hr = inspectable->QueryInterface(__uuidof(WUC::ICompositor), (void**)&g_compositor);
    inspectable->Release();
    if (FAILED(hr)) throw std::runtime_error("QI ICompositor failed");
    dbg("[WUC] Compositor=%p\n", g_compositor);

    hr = g_compositor->QueryInterface(__uuidof(ICompositorInterop), (void**)&g_compInterop);
    if (FAILED(hr)) throw std::runtime_error("QI ICompositorInterop failed");

    hr = g_compositor->QueryInterface(__uuidof(ICompositorDesktopInterop), (void**)&g_compDesktopInt);
    if (FAILED(hr)) throw std::runtime_error("QI ICompositorDesktopInterop failed");

    hr = g_compDesktopInt->CreateDesktopWindowTarget(g_hwnd, TRUE, &g_windowTarget);
    if (FAILED(hr)) throw std::runtime_error("CreateDesktopWindowTarget failed");

    hr = g_windowTarget->QueryInterface(__uuidof(WUC::ICompositionTarget), (void**)&g_compTarget);
    if (FAILED(hr)) throw std::runtime_error("QI ICompositionTarget failed");

    hr = g_compositor->CreateContainerVisual(&g_rootContainer);
    if (FAILED(hr)) throw std::runtime_error("CreateContainerVisual failed");

    hr = g_rootContainer->QueryInterface(__uuidof(WUC::IVisual), (void**)&g_rootVisual);
    if (FAILED(hr)) throw std::runtime_error("QI IVisual on root failed");

    WFN::Vector2 rootSize = { (float)WINDOW_W, (float)WINDOW_H };
    g_rootVisual->put_Size(rootSize);

    hr = g_compTarget->put_Root(g_rootVisual);
    if (FAILED(hr)) throw std::runtime_error("put_Root failed");

    hr = g_rootContainer->get_Children(&g_children);
    if (FAILED(hr)) throw std::runtime_error("get_Children failed");

    dbg("[WUC] root container set\n");
}

// ============================================================
// Helper: create a SpriteVisual from a SwapChain
// ============================================================
static WUC::ISpriteVisual* CreateSpriteFromSwapChain(
    IDXGISwapChain1* swapChain, float offsetX,
    WUC::ICompositionSurface** outSurface)
{
    HRESULT hr;

    WUC::ICompositionSurface* surface = nullptr;
    hr = g_compInterop->CreateCompositionSurfaceForSwapChain(
        (IUnknown*)swapChain, &surface);
    if (FAILED(hr)) throw std::runtime_error("CreateCompositionSurfaceForSwapChain failed");
    if (outSurface) *outSurface = surface;

    WUC::ICompositionSurfaceBrush* surfBrush = nullptr;
    hr = g_compositor->CreateSurfaceBrush(&surfBrush);
    if (FAILED(hr)) throw std::runtime_error("CreateSurfaceBrush failed");

    hr = surfBrush->put_Surface(surface);
    if (FAILED(hr)) throw std::runtime_error("put_Surface failed");

    WUC::ICompositionBrush* brush = nullptr;
    hr = surfBrush->QueryInterface(__uuidof(WUC::ICompositionBrush), (void**)&brush);
    surfBrush->Release();
    if (FAILED(hr)) throw std::runtime_error("QI ICompositionBrush failed");

    WUC::ISpriteVisual* sprite = nullptr;
    hr = g_compositor->CreateSpriteVisual(&sprite);
    if (FAILED(hr)) throw std::runtime_error("CreateSpriteVisual failed");

    hr = sprite->put_Brush(brush);
    brush->Release();
    if (FAILED(hr)) throw std::runtime_error("put_Brush failed");

    WUC::IVisual* visual = nullptr;
    sprite->QueryInterface(__uuidof(WUC::IVisual), (void**)&visual);

    WFN::Vector2 size = { (float)PANEL_W, (float)PANEL_H };
    visual->put_Size(size);

    WFN::Vector3 offset = { offsetX, 0.0f, 0.0f };
    visual->put_Offset(offset);

    g_children->InsertAtTop(visual);
    visual->Release();

    return sprite;
}

// ************************************************************
//  PANEL 0: OpenGL 4.6 via WGL_NV_DX_interop2
// ************************************************************
static void LoadGLFunctions() {
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
}

static void InitOpenGL() {
    dbg("[GL] begin\n");

    g_glHDC = GetDC(g_hwnd);
    PIXELFORMATDESCRIPTOR pfd = {};
    pfd.nSize = sizeof(pfd); pfd.nVersion = 1;
    pfd.dwFlags = PFD_DRAW_TO_WINDOW | PFD_SUPPORT_OPENGL | PFD_DOUBLEBUFFER;
    pfd.iPixelType = PFD_TYPE_RGBA; pfd.cColorBits = 32; pfd.cDepthBits = 24;
    SetPixelFormat(g_glHDC, ChoosePixelFormat(g_glHDC, &pfd), &pfd);

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

    g_glSwapChain = CreateCompSwapChain(PANEL_W, PANEL_H);
    g_glSwapChain->GetBuffer(0, __uuidof(ID3D11Texture2D), (void**)&g_glBackBuffer);

    g_glInteropDev = p_wglDXOpenDeviceNV(g_d3dDevice);
    p_glGenRenderbuffers(1, &g_glRBO);
    g_glInteropObj = p_wglDXRegisterObjectNV(
        g_glInteropDev, g_glBackBuffer, g_glRBO,
        GL_RENDERBUFFER, WGL_ACCESS_READ_WRITE_NV);
    if (!g_glInteropObj) throw std::runtime_error("wglDXRegisterObjectNV failed");

    p_glGenFramebuffers(1, &g_glFBO);
    p_glBindFramebuffer(GL_FRAMEBUFFER, g_glFBO);
    p_glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0,
                                GL_RENDERBUFFER, g_glRBO);
    p_glBindFramebuffer(GL_FRAMEBUFFER, 0);

    g_glSprite = CreateSpriteFromSwapChain(g_glSwapChain, 0.0f, &g_glSurface);

    p_glGenVertexArrays(1, &g_glVAO); p_glBindVertexArray(g_glVAO);
    p_glGenBuffers(2, g_glVBO);

    GLfloat verts[] = { 0,0.5f,0, 0.5f,-0.5f,0, -0.5f,-0.5f,0 };
    GLfloat cols[]  = { 1,0,0,  0,1,0,  0,0,1 };
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
    GLuint fs = p_glCreateShader(GL_FRAGMENT_SHADER);
    p_glShaderSource(fs, 1, &fsSrc, nullptr); p_glCompileShader(fs);
    g_glProgram = p_glCreateProgram();
    p_glAttachShader(g_glProgram, vs); p_glAttachShader(g_glProgram, fs);
    p_glLinkProgram(g_glProgram); p_glUseProgram(g_glProgram);

    g_glPosAttr = p_glGetAttribLocation(g_glProgram, "pos");
    g_glColAttr = p_glGetAttribLocation(g_glProgram, "col");
    p_glEnableVertexAttribArray(g_glPosAttr);
    p_glEnableVertexAttribArray(g_glColAttr);

    dbg("[GL] ok\n");
}

static void RenderGL() {
    wglMakeCurrent(g_glHDC, g_glHRC);
    p_wglDXLockObjectsNV(g_glInteropDev, 1, &g_glInteropObj);

    p_glBindFramebuffer(GL_FRAMEBUFFER, g_glFBO);
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

    p_glBindFramebuffer(GL_FRAMEBUFFER, 0);
    glFlush();
    p_wglDXUnlockObjectsNV(g_glInteropDev, 1, &g_glInteropObj);
    g_glSwapChain->Present(1, 0);
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
    dbg("[D3D11] init panel\n");

    g_dxSwapChain = CreateCompSwapChain(PANEL_W, PANEL_H);

    ID3D11Texture2D* bb = nullptr;
    g_dxSwapChain->GetBuffer(0, __uuidof(ID3D11Texture2D), (void**)&bb);
    g_d3dDevice->CreateRenderTargetView(bb, nullptr, &g_dxRTV);
    bb->Release();

    ID3DBlob* vsBlob = nullptr; ID3DBlob* psBlob = nullptr; ID3DBlob* err = nullptr;
    D3DCompile(g_dxHLSL, strlen(g_dxHLSL), "dx", nullptr, nullptr, "VS", "vs_4_0", 0, 0, &vsBlob, &err);
    if (err) { err->Release(); err = nullptr; }
    D3DCompile(g_dxHLSL, strlen(g_dxHLSL), "dx", nullptr, nullptr, "PS", "ps_4_0", 0, 0, &psBlob, &err);
    if (err) { err->Release(); err = nullptr; }

    g_d3dDevice->CreateVertexShader(vsBlob->GetBufferPointer(), vsBlob->GetBufferSize(), nullptr, &g_dxVS);
    g_d3dDevice->CreatePixelShader(psBlob->GetBufferPointer(), psBlob->GetBufferSize(), nullptr, &g_dxPS);

    D3D11_INPUT_ELEMENT_DESC layout[] = {
        { "POSITION", 0, DXGI_FORMAT_R32G32B32_FLOAT,   0,  0, D3D11_INPUT_PER_VERTEX_DATA, 0 },
        { "COLOR",    0, DXGI_FORMAT_R32G32B32A32_FLOAT, 0, 12, D3D11_INPUT_PER_VERTEX_DATA, 0 },
    };
    g_d3dDevice->CreateInputLayout(layout, 2, vsBlob->GetBufferPointer(), vsBlob->GetBufferSize(), &g_dxInputLayout);
    vsBlob->Release(); psBlob->Release();

    DxVertex verts[] = {
        {  0.0f,  0.5f, 0.0f,  1,0,0,1 },
        {  0.5f, -0.5f, 0.0f,  0,1,0,1 },
        { -0.5f, -0.5f, 0.0f,  0,0,1,1 },
    };
    D3D11_BUFFER_DESC bd = {}; bd.ByteWidth = sizeof(verts);
    bd.Usage = D3D11_USAGE_DEFAULT; bd.BindFlags = D3D11_BIND_VERTEX_BUFFER;
    D3D11_SUBRESOURCE_DATA sd = {}; sd.pSysMem = verts;
    g_d3dDevice->CreateBuffer(&bd, &sd, &g_dxVertexBuffer);

    g_dxSprite = CreateSpriteFromSwapChain(g_dxSwapChain, (float)PANEL_W, &g_dxSurface);

    dbg("[D3D11] panel ok\n");
}

static void RenderD3D11() {
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
//  PANEL 2: Vulkan (offscreen -> staging -> D3D11 copy)
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
    dbg("[VK] begin\n");

    VkApplicationInfo ai = {}; ai.sType = VK_STRUCTURE_TYPE_APPLICATION_INFO;
    ai.apiVersion = VK_API_VERSION_1_0;
    VkInstanceCreateInfo ici = {}; ici.sType = VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO;
    ici.pApplicationInfo = &ai;
    vkCreateInstance(&ici, nullptr, &g_vkInst);

    uint32_t cnt = 0;
    vkEnumeratePhysicalDevices(g_vkInst, &cnt, nullptr);
    std::vector<VkPhysicalDevice> devs(cnt);
    vkEnumeratePhysicalDevices(g_vkInst, &cnt, devs.data());
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

    float prio = 1.0f;
    VkDeviceQueueCreateInfo qci = {}; qci.sType = VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO;
    qci.queueFamilyIndex = g_vkQueueFamily; qci.queueCount = 1; qci.pQueuePriorities = &prio;
    VkDeviceCreateInfo dci = {}; dci.sType = VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO;
    dci.queueCreateInfoCount = 1; dci.pQueueCreateInfos = &qci;
    vkCreateDevice(g_vkPhysDev, &dci, nullptr, &g_vkDev);
    vkGetDeviceQueue(g_vkDev, g_vkQueueFamily, 0, &g_vkQueue);

    VkImageCreateInfo imgci = {}; imgci.sType = VK_STRUCTURE_TYPE_IMAGE_CREATE_INFO;
    imgci.imageType = VK_IMAGE_TYPE_2D; imgci.format = VK_FORMAT_B8G8R8A8_UNORM;
    imgci.extent = { PANEL_W, PANEL_H, 1 }; imgci.mipLevels = 1; imgci.arrayLayers = 1;
    imgci.samples = VK_SAMPLE_COUNT_1_BIT; imgci.tiling = VK_IMAGE_TILING_OPTIMAL;
    imgci.usage = VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT | VK_IMAGE_USAGE_TRANSFER_SRC_BIT;
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

    VkFramebufferCreateInfo fci = {}; fci.sType = VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO;
    fci.renderPass = g_vkRenderPass; fci.attachmentCount = 1; fci.pAttachments = &g_vkOffView;
    fci.width = PANEL_W; fci.height = PANEL_H; fci.layers = 1;
    vkCreateFramebuffer(g_vkDev, &fci, nullptr, &g_vkFramebuffer);

    auto vertCode = readFile("hello_vert.spv");
    auto fragCode = readFile("hello_frag.spv");
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

    VkPipelineColorBlendAttachmentState cbAtt = {}; cbAtt.colorWriteMask = 0xF;
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
    vkCreateGraphicsPipelines(g_vkDev, VK_NULL_HANDLE, 1, &pci, nullptr, &g_vkPipeline);
    vkDestroyShaderModule(g_vkDev, vertMod, nullptr);
    vkDestroyShaderModule(g_vkDev, fragMod, nullptr);

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

    g_vkSwapChain = CreateCompSwapChain(PANEL_W, PANEL_H);
    g_vkSwapChain->GetBuffer(0, __uuidof(ID3D11Texture2D), (void**)&g_vkBackBuffer);

    D3D11_TEXTURE2D_DESC td = {}; td.Width = PANEL_W; td.Height = PANEL_H;
    td.MipLevels = 1; td.ArraySize = 1; td.Format = DXGI_FORMAT_B8G8R8A8_UNORM;
    td.SampleDesc = { 1, 0 }; td.Usage = D3D11_USAGE_STAGING;
    td.CPUAccessFlags = D3D11_CPU_ACCESS_WRITE;
    g_d3dDevice->CreateTexture2D(&td, nullptr, &g_vkStagingTex);

    g_vkSprite = CreateSpriteFromSwapChain(g_vkSwapChain, (float)(PANEL_W * 2), &g_vkSurface);

    dbg("[VK] ok\n");
}

static void RenderVulkan() {
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
//  Main loop
// ************************************************************
static void MainLoop() {
    dbg("[Main] entering message loop\n");
    MSG msg = {};
    bool first = true;
    while (msg.message != WM_QUIT) {
        if (PeekMessageW(&msg, nullptr, 0, 0, PM_REMOVE)) {
            TranslateMessage(&msg);
            DispatchMessageW(&msg);
        } else {
            RenderGL();
            RenderD3D11();
            RenderVulkan();

            if (first) {
                dbg("[Main] first frame rendered (all 3 panels)\n");
                first = false;
            }
            Sleep(1);
        }
    }
}

// ************************************************************
//  Cleanup
// ************************************************************
static void CleanupAll() {
    dbg("[Cleanup] begin\n");

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
    SafeRelease(&g_vkSurface);
    SafeRelease(&g_vkSprite);

    if (g_glInteropObj) p_wglDXUnregisterObjectNV(g_glInteropDev, g_glInteropObj);
    if (g_glInteropDev) p_wglDXCloseDeviceNV(g_glInteropDev);
    if (g_glHRC) { wglMakeCurrent(nullptr, nullptr); wglDeleteContext(g_glHRC); }
    if (g_glHDC) ReleaseDC(g_hwnd, g_glHDC);
    SafeRelease(&g_glBackBuffer);
    SafeRelease(&g_glSwapChain);
    SafeRelease(&g_glSurface);
    SafeRelease(&g_glSprite);

    SafeRelease(&g_dxVertexBuffer);
    SafeRelease(&g_dxInputLayout);
    SafeRelease(&g_dxPS);
    SafeRelease(&g_dxVS);
    SafeRelease(&g_dxRTV);
    SafeRelease(&g_dxSwapChain);
    SafeRelease(&g_dxSurface);
    SafeRelease(&g_dxSprite);

    SafeRelease(&g_children);
    SafeRelease(&g_rootVisual);
    SafeRelease(&g_rootContainer);
    SafeRelease(&g_compTarget);
    SafeRelease(&g_windowTarget);
    SafeRelease(&g_compDesktopInt);
    SafeRelease(&g_compInterop);
    SafeRelease(&g_compositor);
    SafeRelease(&g_dqController);

    SafeRelease(&g_d3dContext);
    SafeRelease(&g_d3dDevice);

    // Only uninitialize WinRT if we successfully initialized it.
    // Under /clr, RoInitialize may have returned RPC_E_CHANGED_MODE,
    // meaning we did not actually initialize it - do not call uninit.
    if (g_roInitialized) {
        RoUninitialize();
        g_roInitialized = false;
    }

    if (g_hwnd) DestroyWindow(g_hwnd);
    dbg("[Cleanup] done\n");
}

// ============================================================
// Entry point
// ============================================================
int WINAPI wWinMain(HINSTANCE, HINSTANCE, LPWSTR, int) {
    dbg("======================================================\n");
    dbg("OpenGL + D3D11 + Vulkan via Windows.UI.Composition\n");
    dbg("3 panels in 1 window, WinRT Compositor + SpriteVisual\n");
    dbg("======================================================\n");

    try {
        CreateAppWindow();
        CreateD3D11Device();
        InitComposition();

        InitOpenGL();
        InitD3D11Panel();
        InitVulkan();

        MainLoop();
    } catch (const std::exception& e) {
        dbg("[FATAL] %s\n", e.what());
        MessageBoxA(nullptr, e.what(), "Error", MB_OK | MB_ICONERROR);
    }

    CleanupAll();
    dbg("[Main] exit\n");
    return 0;
}

// ============================================================
// [C++/CLI] End of native (unmanaged) code block
// ============================================================
#pragma managed(pop)
