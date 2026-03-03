// hello.cpp - OpenGL + D3D11 + Vulkan Triangles via Windows.UI.Composition (MFC)
//
// Build (Visual Studio Developer Command Prompt, Windows 10 SDK 10.0.17763+):
//   cl /EHsc /std:c++20 hello.cpp ^
//      /link vulkan-1.lib ^
//      d3d11.lib dxgi.lib d3dcompiler.lib opengl32.lib ^
//      user32.lib gdi32.lib shell32.lib RuntimeObject.lib ^
//      /SUBSYSTEM:WINDOWS
//
// Shaders (Vulkan only - D3D11 and OpenGL use embedded shaders):
//   %VULKAN_SDK%\Bin\glslangValidator -V hello.vert -o hello_vert.spv
//   %VULKAN_SDK%\Bin\glslangValidator -V hello.frag -o hello_frag.spv
//
// Architecture:
//   Uses Windows.UI.Composition (WinRT) instead of DirectComposition.
//   Each panel has its own SwapChainForComposition, wrapped as:
//     SwapChain -> ICompositionSurface -> ICompositionSurfaceBrush -> ISpriteVisual
//   All three SpriteVisuals are children of one ContainerVisual.
//
//   ---------------------- One CFrameWnd --------------------
//   | SpriteVisual 0   | SpriteVisual 1  | SpriteVisual 2   |
//   | OpenGL 4.6       | D3D11           | Vulkan            |
//   | Offset(0,0,0)    | Offset(320,0,0) | Offset(640,0,0)  |
//   ---------------------------------------------------------
//
// Differences from DirectComposition (dcomp.dll) version:
//   dcomp:  IDCompositionVisual::SetContent(swapChain)  <- direct
//   WinRT:  CreateCompositionSurfaceForSwapChain(swapChain)
//           -> CreateSurfaceBrush() -> put_Surface()
//           -> CreateSpriteVisual() -> put_Brush()        <- 3-step chain

#include <afxwin.h>
#include <tchar.h>

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
#include <cstring>

#pragma comment(lib, "d3d11.lib")
#pragma comment(lib, "dxgi.lib")
#pragma comment(lib, "d3dcompiler.lib")
#pragma comment(lib, "opengl32.lib")
#pragma comment(lib, "RuntimeObject.lib")

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
    DWORD threadType;     // DQTYPE_THREAD_DEDICATED=1, DQTYPE_THREAD_CURRENT=2
    DWORD apartmentType;  // DQTAT_COM_NONE=0, DQTAT_COM_ASTA=1, DQTAT_COM_STA=2
};

// ============================================================
// Constants
// ============================================================
static const uint32_t PANEL_W  = 320;
static const uint32_t PANEL_H  = 480;
static const uint32_t WINDOW_W = PANEL_W * 3; // 960
static const uint32_t WINDOW_H = PANEL_H;     // 480

// ============================================================
// Helper: safe COM release
// ============================================================
template <typename T>
void SafeRelease(T** pp) { if (*pp) { (*pp)->Release(); *pp = nullptr; } }

// ============================================================
// Read SPIR-V file using CFile (for Vulkan)
// ============================================================
static std::vector<char> ReadSpvFile(LPCTSTR filename) {
    CFile file;
    CFileException ex;
    if (!file.Open(filename, CFile::modeRead | CFile::typeBinary, &ex)) {
        CString msg;
        msg.Format(_T("Failed to open SPIR-V file: %s"), filename);
        AfxMessageBox(msg, MB_OK | MB_ICONERROR);
        return std::vector<char>();
    }
    ULONGLONG sz = file.GetLength();
    std::vector<char> buf((size_t)sz);
    file.Read(buf.data(), (UINT)sz);
    file.Close();
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

// ============================================================
// D3D11 vertex struct and embedded HLSL shader
// ============================================================
struct DxVertex { float x, y, z, r, g, b, a; };

static const char* g_dxHLSL = R"(
struct VSI { float3 p:POSITION; float4 c:COLOR; };
struct PSI { float4 p:SV_POSITION; float4 c:COLOR; };
PSI VS(VSI i){ PSI o; o.p=float4(i.p,1); o.c=i.c; return o; }
float4 PS(PSI i):SV_Target{ return i.c; }
)";

// ============================================================
// Namespace aliases for ABI types
// ============================================================
namespace WUC  = ABI::Windows::UI::Composition;
namespace WUCD = ABI::Windows::UI::Composition::Desktop;
namespace WFN  = ABI::Windows::Foundation::Numerics;

// ============================================================
// CMainFrame - MFC main frame window with Windows.UI.Composition
// ============================================================
class CMainFrame : public CFrameWnd
{
public:
    CMainFrame();
    ~CMainFrame();
    BOOL PreCreateWindow(CREATESTRUCT& cs);

protected:
    afx_msg int  OnCreate(LPCREATESTRUCT lpCreateStruct);
    afx_msg void OnDestroy();
    afx_msg void OnPaint();
    afx_msg BOOL OnEraseBkgnd(CDC* pDC);
    afx_msg void OnTimer(UINT_PTR nIDEvent);
    DECLARE_MESSAGE_MAP()

private:
    // --- Initialization ---
    BOOL CreateD3D11Device();
    IDXGISwapChain1* CreateCompSwapChain(uint32_t w, uint32_t h);
    BOOL InitComposition();
    WUC::ISpriteVisual* CreateSpriteFromSwapChain(
        IDXGISwapChain1* pSwapChain, float offsetX,
        WUC::ICompositionSurface** ppOutSurface);
    BOOL InitOpenGL();
    BOOL InitD3D11Panel();
    BOOL InitVulkan();

    // --- Rendering ---
    void RenderGL();
    void RenderD3D11();
    void RenderVulkan();
    void RenderAll();

    // --- Cleanup ---
    void CleanupAll();

    // --- Helpers ---
    void LoadGLFunctions();
    uint32_t VkFindMemType(uint32_t filter, VkMemoryPropertyFlags props);

    // --- Shared D3D11 device ---
    ID3D11Device*         m_pd3dDevice;
    ID3D11DeviceContext*  m_pd3dContext;

    // --- Windows.UI.Composition ---
    WUC::ICompositor*                                        m_pCompositor;
    ICompositorInterop*                                      m_pCompInterop;
    ICompositorDesktopInterop*                                m_pCompDesktopInt;
    WUCD::IDesktopWindowTarget*                              m_pWindowTarget;
    WUC::ICompositionTarget*                                 m_pCompTarget;
    WUC::IContainerVisual*                                   m_pRootContainer;
    WUC::IVisual*                                            m_pRootVisual;
    WUC::IVisualCollection*                                  m_pChildren;
    ABI::Windows::System::IDispatcherQueueController*        m_pDQController;

    // --- Panel 0: OpenGL ---
    IDXGISwapChain1*            m_pGLSwapChain;
    ID3D11Texture2D*            m_pGLBackBuffer;
    WUC::ICompositionSurface*   m_pGLSurface;
    WUC::ISpriteVisual*         m_pGLSprite;
    CClientDC*                  m_pGLDC;
    HGLRC                       m_hGLRC;
    HANDLE                      m_hGLInteropDev;
    HANDLE                      m_hGLInteropObj;
    GLuint                      m_nGLRBO, m_nGLFBO;
    GLuint                      m_nGLProgram, m_nGLVAO, m_nGLVBO[2];
    GLint                       m_nGLPosAttr, m_nGLColAttr;

    // GL function pointers
    PFN_glGenBuffers              m_pfnGenBuffers;
    PFN_glBindBuffer              m_pfnBindBuffer;
    PFN_glBufferData              m_pfnBufferData;
    PFN_glCreateShader            m_pfnCreateShader;
    PFN_glShaderSource            m_pfnShaderSource;
    PFN_glCompileShader           m_pfnCompileShader;
    PFN_glCreateProgram           m_pfnCreateProgram;
    PFN_glAttachShader            m_pfnAttachShader;
    PFN_glLinkProgram             m_pfnLinkProgram;
    PFN_glUseProgram              m_pfnUseProgram;
    PFN_glGetAttribLocation       m_pfnGetAttribLocation;
    PFN_glEnableVertexAttribArray m_pfnEnableVertexAttribArray;
    PFN_glVertexAttribPointer     m_pfnVertexAttribPointer;
    PFN_glGetShaderiv             m_pfnGetShaderiv;
    PFN_glGetShaderInfoLog        m_pfnGetShaderInfoLog;
    PFN_glGetProgramiv            m_pfnGetProgramiv;
    PFN_glGetProgramInfoLog       m_pfnGetProgramInfoLog;
    PFN_glGenFramebuffers         m_pfnGenFramebuffers;
    PFN_glBindFramebuffer         m_pfnBindFramebuffer;
    PFN_glFramebufferRenderbuffer m_pfnFramebufferRenderbuffer;
    PFN_glCheckFramebufferStatus  m_pfnCheckFramebufferStatus;
    PFN_glGenRenderbuffers        m_pfnGenRenderbuffers;
    PFN_glBindRenderbuffer        m_pfnBindRenderbuffer;
    PFN_glGenVertexArrays         m_pfnGenVertexArrays;
    PFN_glBindVertexArray         m_pfnBindVertexArray;

    PFN_wglCreateContextAttribsARB m_pfnCreateContextAttribsARB;
    PFN_wglDXOpenDeviceNV          m_pfnDXOpenDeviceNV;
    PFN_wglDXCloseDeviceNV         m_pfnDXCloseDeviceNV;
    PFN_wglDXRegisterObjectNV      m_pfnDXRegisterObjectNV;
    PFN_wglDXUnregisterObjectNV    m_pfnDXUnregisterObjectNV;
    PFN_wglDXLockObjectsNV         m_pfnDXLockObjectsNV;
    PFN_wglDXUnlockObjectsNV       m_pfnDXUnlockObjectsNV;

    // --- Panel 1: D3D11 ---
    IDXGISwapChain1*            m_pDXSwapChain;
    ID3D11RenderTargetView*     m_pDXRTV;
    WUC::ICompositionSurface*   m_pDXSurface;
    WUC::ISpriteVisual*         m_pDXSprite;
    ID3D11VertexShader*         m_pDXVS;
    ID3D11PixelShader*          m_pDXPS;
    ID3D11InputLayout*          m_pDXInputLayout;
    ID3D11Buffer*               m_pDXVertexBuffer;

    // --- Panel 2: Vulkan ---
    IDXGISwapChain1*            m_pVKSwapChain;
    ID3D11Texture2D*            m_pVKBackBuffer;
    ID3D11Texture2D*            m_pVKStagingTex;
    WUC::ICompositionSurface*   m_pVKSurface;
    WUC::ISpriteVisual*         m_pVKSprite;
    VkInstance       m_vkInst;
    VkPhysicalDevice m_vkPhysDev;
    VkDevice         m_vkDev;
    VkQueue          m_vkQueue;
    uint32_t         m_nVKQueueFamily;
    VkImage          m_vkOffImage;
    VkDeviceMemory   m_vkOffMemory;
    VkImageView      m_vkOffView;
    VkRenderPass     m_vkRenderPass;
    VkFramebuffer    m_vkFramebuffer;
    VkPipelineLayout m_vkPipeLayout;
    VkPipeline       m_vkPipeline;
    VkCommandPool    m_vkCmdPool;
    VkCommandBuffer  m_vkCmdBuf;
    VkFence          m_vkFence;
    VkBuffer         m_vkStagBuf;
    VkDeviceMemory   m_vkStagMem;

    static const UINT_PTR RENDER_TIMER_ID = 1;
};

// ============================================================
// MFC Application class
// ============================================================
class CHelloApp : public CWinApp
{
public:
    BOOL InitInstance();
    int  ExitInstance();
};

BOOL CHelloApp::InitInstance()
{
    CWinApp::InitInstance();

    // Initialize WinRT (required before Compositor creation)
    HRESULT hr = RoInitialize(RO_INIT_SINGLETHREADED);
    if (FAILED(hr)) {
        AfxMessageBox(_T("RoInitialize failed"), MB_OK | MB_ICONERROR);
        return FALSE;
    }
    TRACE(_T("[App] RoInitialize ok\n"));

    m_pMainWnd = new CMainFrame;
    m_pMainWnd->ShowWindow(m_nCmdShow);
    m_pMainWnd->UpdateWindow();
    return TRUE;
}

int CHelloApp::ExitInstance()
{
    RoUninitialize();
    TRACE(_T("[App] RoUninitialize\n"));
    return CWinApp::ExitInstance();
}

CHelloApp theApp;

// ============================================================
// Message map
// ============================================================
BEGIN_MESSAGE_MAP(CMainFrame, CFrameWnd)
    ON_WM_CREATE()
    ON_WM_DESTROY()
    ON_WM_PAINT()
    ON_WM_ERASEBKGND()
    ON_WM_TIMER()
END_MESSAGE_MAP()

// ============================================================
// Constructor / Destructor
// ============================================================
CMainFrame::CMainFrame()
    : m_pd3dDevice(NULL), m_pd3dContext(NULL)
    // Windows.UI.Composition
    , m_pCompositor(NULL), m_pCompInterop(NULL), m_pCompDesktopInt(NULL)
    , m_pWindowTarget(NULL), m_pCompTarget(NULL)
    , m_pRootContainer(NULL), m_pRootVisual(NULL), m_pChildren(NULL)
    , m_pDQController(NULL)
    // OpenGL
    , m_pGLSwapChain(NULL), m_pGLBackBuffer(NULL)
    , m_pGLSurface(NULL), m_pGLSprite(NULL)
    , m_pGLDC(NULL), m_hGLRC(NULL)
    , m_hGLInteropDev(NULL), m_hGLInteropObj(NULL)
    , m_nGLRBO(0), m_nGLFBO(0), m_nGLProgram(0), m_nGLVAO(0)
    , m_nGLPosAttr(-1), m_nGLColAttr(-1)
    // GL function pointers
    , m_pfnGenBuffers(NULL), m_pfnBindBuffer(NULL), m_pfnBufferData(NULL)
    , m_pfnCreateShader(NULL), m_pfnShaderSource(NULL), m_pfnCompileShader(NULL)
    , m_pfnCreateProgram(NULL), m_pfnAttachShader(NULL), m_pfnLinkProgram(NULL)
    , m_pfnUseProgram(NULL), m_pfnGetAttribLocation(NULL)
    , m_pfnEnableVertexAttribArray(NULL), m_pfnVertexAttribPointer(NULL)
    , m_pfnGetShaderiv(NULL), m_pfnGetShaderInfoLog(NULL)
    , m_pfnGetProgramiv(NULL), m_pfnGetProgramInfoLog(NULL)
    , m_pfnGenFramebuffers(NULL), m_pfnBindFramebuffer(NULL)
    , m_pfnFramebufferRenderbuffer(NULL), m_pfnCheckFramebufferStatus(NULL)
    , m_pfnGenRenderbuffers(NULL), m_pfnBindRenderbuffer(NULL)
    , m_pfnGenVertexArrays(NULL), m_pfnBindVertexArray(NULL)
    , m_pfnCreateContextAttribsARB(NULL)
    , m_pfnDXOpenDeviceNV(NULL), m_pfnDXCloseDeviceNV(NULL)
    , m_pfnDXRegisterObjectNV(NULL), m_pfnDXUnregisterObjectNV(NULL)
    , m_pfnDXLockObjectsNV(NULL), m_pfnDXUnlockObjectsNV(NULL)
    // D3D11
    , m_pDXSwapChain(NULL), m_pDXRTV(NULL)
    , m_pDXSurface(NULL), m_pDXSprite(NULL)
    , m_pDXVS(NULL), m_pDXPS(NULL), m_pDXInputLayout(NULL), m_pDXVertexBuffer(NULL)
    // Vulkan
    , m_pVKSwapChain(NULL), m_pVKBackBuffer(NULL), m_pVKStagingTex(NULL)
    , m_pVKSurface(NULL), m_pVKSprite(NULL)
    , m_vkInst(VK_NULL_HANDLE), m_vkPhysDev(VK_NULL_HANDLE)
    , m_vkDev(VK_NULL_HANDLE), m_vkQueue(VK_NULL_HANDLE), m_nVKQueueFamily(0)
    , m_vkOffImage(VK_NULL_HANDLE), m_vkOffMemory(VK_NULL_HANDLE)
    , m_vkOffView(VK_NULL_HANDLE), m_vkRenderPass(VK_NULL_HANDLE)
    , m_vkFramebuffer(VK_NULL_HANDLE), m_vkPipeLayout(VK_NULL_HANDLE)
    , m_vkPipeline(VK_NULL_HANDLE), m_vkCmdPool(VK_NULL_HANDLE)
    , m_vkCmdBuf(VK_NULL_HANDLE), m_vkFence(VK_NULL_HANDLE)
    , m_vkStagBuf(VK_NULL_HANDLE), m_vkStagMem(VK_NULL_HANDLE)
{
    m_nGLVBO[0] = 0;
    m_nGLVBO[1] = 0;
    Create(NULL, _T("OpenGL + D3D11 + Vulkan (Windows.UI.Composition / MFC)"));
}

CMainFrame::~CMainFrame()
{
}

BOOL CMainFrame::PreCreateWindow(CREATESTRUCT& cs)
{
    CFrameWnd::PreCreateWindow(cs);
    cs.cx = WINDOW_W;
    cs.cy = WINDOW_H;
    return TRUE;
}

// ============================================================
// OnCreate - Initialize all rendering subsystems
// ============================================================
int CMainFrame::OnCreate(LPCREATESTRUCT lpCreateStruct)
{
    if (CFrameWnd::OnCreate(lpCreateStruct) == -1)
        return -1;

    TRACE(_T("======================================================\n"));
    TRACE(_T("OpenGL + D3D11 + Vulkan via Windows.UI.Composition (MFC)\n"));
    TRACE(_T("3 panels in 1 window, WinRT Compositor + SpriteVisual\n"));
    TRACE(_T("======================================================\n"));

    if (!CreateD3D11Device())     return -1;
    if (!InitComposition())       return -1;  // WinRT Compositor + DesktopWindowTarget
    if (!InitOpenGL())            return -1;  // Panel 0 (left)   - GL via WGL_NV_DX_interop2
    if (!InitD3D11Panel())        return -1;  // Panel 1 (center) - D3D11 native
    if (!InitVulkan())            return -1;  // Panel 2 (right)  - VK via staging buffer

    // Start a timer for continuous rendering (~60fps)
    SetTimer(RENDER_TIMER_ID, 16, NULL);

    return 0;
}

void CMainFrame::OnDestroy()
{
    KillTimer(RENDER_TIMER_ID);
    CleanupAll();
    CFrameWnd::OnDestroy();
}

void CMainFrame::OnPaint()
{
    CPaintDC dc(this);
    RenderAll();
}

BOOL CMainFrame::OnEraseBkgnd(CDC* pDC)
{
    return TRUE; // WUC handles compositing
}

void CMainFrame::OnTimer(UINT_PTR nIDEvent)
{
    if (nIDEvent == RENDER_TIMER_ID) {
        RenderAll();
    }
    CFrameWnd::OnTimer(nIDEvent);
}

void CMainFrame::RenderAll()
{
    RenderGL();
    RenderD3D11();
    RenderVulkan();
}

// ============================================================
// Create shared D3D11 device
// ============================================================
BOOL CMainFrame::CreateD3D11Device()
{
    TRACE(_T("[D3D11] creating shared device\n"));
    D3D_FEATURE_LEVEL level = D3D_FEATURE_LEVEL_11_0;
    HRESULT hr = D3D11CreateDevice(nullptr, D3D_DRIVER_TYPE_HARDWARE, nullptr,
        D3D11_CREATE_DEVICE_BGRA_SUPPORT, &level, 1, D3D11_SDK_VERSION,
        &m_pd3dDevice, nullptr, &m_pd3dContext);
    if (FAILED(hr)) {
        AfxMessageBox(_T("D3D11CreateDevice failed"), MB_OK | MB_ICONERROR);
        return FALSE;
    }
    TRACE(_T("[D3D11] Device=%p\n"), m_pd3dDevice);
    return TRUE;
}

// ============================================================
// Helper: create a SwapChainForComposition
// ============================================================
IDXGISwapChain1* CMainFrame::CreateCompSwapChain(uint32_t w, uint32_t h)
{
    IDXGIDevice* pDXGIDev = nullptr;
    m_pd3dDevice->QueryInterface(__uuidof(IDXGIDevice), (void**)&pDXGIDev);
    IDXGIAdapter* pAdapter = nullptr;
    pDXGIDev->GetAdapter(&pAdapter);
    IDXGIFactory2* pFactory = nullptr;
    pAdapter->GetParent(__uuidof(IDXGIFactory2), (void**)&pFactory);
    pAdapter->Release();

    DXGI_SWAP_CHAIN_DESC1 scd = {};
    scd.Width       = w;
    scd.Height      = h;
    scd.Format      = DXGI_FORMAT_B8G8R8A8_UNORM;
    scd.SampleDesc  = { 1, 0 };
    scd.BufferUsage = DXGI_USAGE_RENDER_TARGET_OUTPUT;
    scd.BufferCount = 2;
    scd.SwapEffect  = DXGI_SWAP_EFFECT_FLIP_SEQUENTIAL;
    scd.AlphaMode   = DXGI_ALPHA_MODE_PREMULTIPLIED;

    IDXGISwapChain1* pSC = nullptr;
    HRESULT hr = pFactory->CreateSwapChainForComposition(m_pd3dDevice, &scd, nullptr, &pSC);
    pFactory->Release();
    pDXGIDev->Release();
    if (FAILED(hr)) {
        AfxMessageBox(_T("CreateSwapChainForComposition failed"), MB_OK | MB_ICONERROR);
        return nullptr;
    }
    return pSC;
}

// ============================================================
// Initialize Windows.UI.Composition
// ============================================================
BOOL CMainFrame::InitComposition()
{
    TRACE(_T("[WUC] begin\n"));
    HRESULT hr;

    // Step 1: Create DispatcherQueueController (required for Compositor)
    HMODULE hCoreMsgDll = LoadLibrary(_T("CoreMessaging.dll"));
    if (!hCoreMsgDll) {
        AfxMessageBox(_T("LoadLibrary CoreMessaging.dll failed"), MB_OK | MB_ICONERROR);
        return FALSE;
    }

    auto pfnCreateDQC = (PFN_CreateDispatcherQueueController)
        GetProcAddress(hCoreMsgDll, "CreateDispatcherQueueController");
    if (!pfnCreateDQC) {
        AfxMessageBox(_T("CreateDispatcherQueueController not found"), MB_OK | MB_ICONERROR);
        return FALSE;
    }

    DispatcherQueueOptions dqOpts = {};
    dqOpts.dwSize = sizeof(dqOpts);
    dqOpts.threadType = 2;    // DQTYPE_THREAD_CURRENT
    dqOpts.apartmentType = 2; // DQTAT_COM_STA

    hr = pfnCreateDQC(dqOpts, &m_pDQController);
    if (FAILED(hr)) {
        AfxMessageBox(_T("CreateDispatcherQueueController failed"), MB_OK | MB_ICONERROR);
        return FALSE;
    }
    TRACE(_T("[WUC] DispatcherQueue created\n"));

    // Step 2: Activate Compositor
    HSTRING hsCompositor = nullptr;
    HSTRING_HEADER hsHeader;
    const wchar_t className[] = L"Windows.UI.Composition.Compositor";
    hr = WindowsCreateStringReference(className, (UINT32)wcslen(className), &hsHeader, &hsCompositor);
    if (FAILED(hr)) {
        AfxMessageBox(_T("WindowsCreateStringReference failed"), MB_OK | MB_ICONERROR);
        return FALSE;
    }

    IInspectable* pInspectable = nullptr;
    hr = RoActivateInstance(hsCompositor, &pInspectable);
    if (FAILED(hr)) {
        AfxMessageBox(_T("RoActivateInstance Compositor failed"), MB_OK | MB_ICONERROR);
        return FALSE;
    }

    hr = pInspectable->QueryInterface(__uuidof(WUC::ICompositor), (void**)&m_pCompositor);
    pInspectable->Release();
    if (FAILED(hr)) {
        AfxMessageBox(_T("QI ICompositor failed"), MB_OK | MB_ICONERROR);
        return FALSE;
    }
    TRACE(_T("[WUC] Compositor=%p\n"), m_pCompositor);

    // Step 3: Get interop interfaces
    hr = m_pCompositor->QueryInterface(__uuidof(ICompositorInterop), (void**)&m_pCompInterop);
    if (FAILED(hr)) {
        AfxMessageBox(_T("QI ICompositorInterop failed"), MB_OK | MB_ICONERROR);
        return FALSE;
    }

    hr = m_pCompositor->QueryInterface(__uuidof(ICompositorDesktopInterop), (void**)&m_pCompDesktopInt);
    if (FAILED(hr)) {
        AfxMessageBox(_T("QI ICompositorDesktopInterop failed"), MB_OK | MB_ICONERROR);
        return FALSE;
    }

    // Step 4: Create DesktopWindowTarget (bind Compositor to MFC HWND)
    hr = m_pCompDesktopInt->CreateDesktopWindowTarget(m_hWnd, TRUE, &m_pWindowTarget);
    if (FAILED(hr)) {
        AfxMessageBox(_T("CreateDesktopWindowTarget failed"), MB_OK | MB_ICONERROR);
        return FALSE;
    }
    TRACE(_T("[WUC] DesktopWindowTarget=%p\n"), m_pWindowTarget);

    // Step 5: Get ICompositionTarget from DesktopWindowTarget
    hr = m_pWindowTarget->QueryInterface(__uuidof(WUC::ICompositionTarget), (void**)&m_pCompTarget);
    if (FAILED(hr)) {
        AfxMessageBox(_T("QI ICompositionTarget failed"), MB_OK | MB_ICONERROR);
        return FALSE;
    }

    // Step 6: Create root ContainerVisual
    hr = m_pCompositor->CreateContainerVisual(&m_pRootContainer);
    if (FAILED(hr)) {
        AfxMessageBox(_T("CreateContainerVisual failed"), MB_OK | MB_ICONERROR);
        return FALSE;
    }

    hr = m_pRootContainer->QueryInterface(__uuidof(WUC::IVisual), (void**)&m_pRootVisual);
    if (FAILED(hr)) {
        AfxMessageBox(_T("QI IVisual on root failed"), MB_OK | MB_ICONERROR);
        return FALSE;
    }

    // Set root size
    WFN::Vector2 rootSize = { (float)WINDOW_W, (float)WINDOW_H };
    m_pRootVisual->put_Size(rootSize);

    // Set as composition target root
    hr = m_pCompTarget->put_Root(m_pRootVisual);
    if (FAILED(hr)) {
        AfxMessageBox(_T("put_Root failed"), MB_OK | MB_ICONERROR);
        return FALSE;
    }

    // Get children collection for adding panels
    hr = m_pRootContainer->get_Children(&m_pChildren);
    if (FAILED(hr)) {
        AfxMessageBox(_T("get_Children failed"), MB_OK | MB_ICONERROR);
        return FALSE;
    }

    TRACE(_T("[WUC] root container set, ready for panels\n"));
    return TRUE;
}

// ============================================================
// Helper: create a SpriteVisual from a SwapChain
//   SwapChain -> ICompositionSurface -> ICompositionSurfaceBrush -> ISpriteVisual
// ============================================================
WUC::ISpriteVisual* CMainFrame::CreateSpriteFromSwapChain(
    IDXGISwapChain1* pSwapChain, float offsetX,
    WUC::ICompositionSurface** ppOutSurface)
{
    HRESULT hr;

    // Step 1: CreateCompositionSurfaceForSwapChain
    WUC::ICompositionSurface* pSurface = nullptr;
    hr = m_pCompInterop->CreateCompositionSurfaceForSwapChain(
        (IUnknown*)pSwapChain, &pSurface);
    if (FAILED(hr)) {
        AfxMessageBox(_T("CreateCompositionSurfaceForSwapChain failed"), MB_OK | MB_ICONERROR);
        return nullptr;
    }
    if (ppOutSurface) *ppOutSurface = pSurface;

    // Step 2: CreateSurfaceBrush
    WUC::ICompositionSurfaceBrush* pSurfBrush = nullptr;
    hr = m_pCompositor->CreateSurfaceBrush(&pSurfBrush);
    if (FAILED(hr)) {
        AfxMessageBox(_T("CreateSurfaceBrush failed"), MB_OK | MB_ICONERROR);
        return nullptr;
    }

    // Step 3: Set surface on brush
    hr = pSurfBrush->put_Surface(pSurface);
    if (FAILED(hr)) {
        AfxMessageBox(_T("put_Surface failed"), MB_OK | MB_ICONERROR);
        pSurfBrush->Release();
        return nullptr;
    }

    // Step 4: Get ICompositionBrush from SurfaceBrush
    WUC::ICompositionBrush* pBrush = nullptr;
    hr = pSurfBrush->QueryInterface(__uuidof(WUC::ICompositionBrush), (void**)&pBrush);
    pSurfBrush->Release();
    if (FAILED(hr)) {
        AfxMessageBox(_T("QI ICompositionBrush failed"), MB_OK | MB_ICONERROR);
        return nullptr;
    }

    // Step 5: CreateSpriteVisual
    WUC::ISpriteVisual* pSprite = nullptr;
    hr = m_pCompositor->CreateSpriteVisual(&pSprite);
    if (FAILED(hr)) {
        AfxMessageBox(_T("CreateSpriteVisual failed"), MB_OK | MB_ICONERROR);
        pBrush->Release();
        return nullptr;
    }

    // Step 6: Set brush on sprite
    hr = pSprite->put_Brush(pBrush);
    pBrush->Release();
    if (FAILED(hr)) {
        AfxMessageBox(_T("put_Brush failed"), MB_OK | MB_ICONERROR);
        pSprite->Release();
        return nullptr;
    }

    // Step 7: Set size and offset via IVisual
    WUC::IVisual* pVisual = nullptr;
    pSprite->QueryInterface(__uuidof(WUC::IVisual), (void**)&pVisual);

    WFN::Vector2 size = { (float)PANEL_W, (float)PANEL_H };
    pVisual->put_Size(size);

    WFN::Vector3 offset = { offsetX, 0.0f, 0.0f };
    pVisual->put_Offset(offset);

    // Step 8: Add to container
    m_pChildren->InsertAtTop(pVisual);
    pVisual->Release();

    return pSprite;
}

// ************************************************************
//  PANEL 0: OpenGL 4.6 via WGL_NV_DX_interop2
// ************************************************************
void CMainFrame::LoadGLFunctions()
{
    m_pfnGenBuffers              = (PFN_glGenBuffers)              wglGetProcAddress("glGenBuffers");
    m_pfnBindBuffer              = (PFN_glBindBuffer)              wglGetProcAddress("glBindBuffer");
    m_pfnBufferData              = (PFN_glBufferData)              wglGetProcAddress("glBufferData");
    m_pfnCreateShader            = (PFN_glCreateShader)            wglGetProcAddress("glCreateShader");
    m_pfnShaderSource            = (PFN_glShaderSource)            wglGetProcAddress("glShaderSource");
    m_pfnCompileShader           = (PFN_glCompileShader)           wglGetProcAddress("glCompileShader");
    m_pfnCreateProgram           = (PFN_glCreateProgram)           wglGetProcAddress("glCreateProgram");
    m_pfnAttachShader            = (PFN_glAttachShader)            wglGetProcAddress("glAttachShader");
    m_pfnLinkProgram             = (PFN_glLinkProgram)             wglGetProcAddress("glLinkProgram");
    m_pfnUseProgram              = (PFN_glUseProgram)              wglGetProcAddress("glUseProgram");
    m_pfnGetAttribLocation       = (PFN_glGetAttribLocation)       wglGetProcAddress("glGetAttribLocation");
    m_pfnEnableVertexAttribArray = (PFN_glEnableVertexAttribArray) wglGetProcAddress("glEnableVertexAttribArray");
    m_pfnVertexAttribPointer     = (PFN_glVertexAttribPointer)     wglGetProcAddress("glVertexAttribPointer");
    m_pfnGetShaderiv             = (PFN_glGetShaderiv)             wglGetProcAddress("glGetShaderiv");
    m_pfnGetShaderInfoLog        = (PFN_glGetShaderInfoLog)        wglGetProcAddress("glGetShaderInfoLog");
    m_pfnGetProgramiv            = (PFN_glGetProgramiv)            wglGetProcAddress("glGetProgramiv");
    m_pfnGetProgramInfoLog       = (PFN_glGetProgramInfoLog)       wglGetProcAddress("glGetProgramInfoLog");
    m_pfnGenFramebuffers         = (PFN_glGenFramebuffers)         wglGetProcAddress("glGenFramebuffers");
    m_pfnBindFramebuffer         = (PFN_glBindFramebuffer)         wglGetProcAddress("glBindFramebuffer");
    m_pfnFramebufferRenderbuffer = (PFN_glFramebufferRenderbuffer) wglGetProcAddress("glFramebufferRenderbuffer");
    m_pfnCheckFramebufferStatus  = (PFN_glCheckFramebufferStatus)  wglGetProcAddress("glCheckFramebufferStatus");
    m_pfnGenRenderbuffers        = (PFN_glGenRenderbuffers)        wglGetProcAddress("glGenRenderbuffers");
    m_pfnBindRenderbuffer        = (PFN_glBindRenderbuffer)        wglGetProcAddress("glBindRenderbuffer");
    m_pfnGenVertexArrays         = (PFN_glGenVertexArrays)         wglGetProcAddress("glGenVertexArrays");
    m_pfnBindVertexArray         = (PFN_glBindVertexArray)         wglGetProcAddress("glBindVertexArray");

    m_pfnCreateContextAttribsARB = (PFN_wglCreateContextAttribsARB)wglGetProcAddress("wglCreateContextAttribsARB");
    m_pfnDXOpenDeviceNV          = (PFN_wglDXOpenDeviceNV)         wglGetProcAddress("wglDXOpenDeviceNV");
    m_pfnDXCloseDeviceNV         = (PFN_wglDXCloseDeviceNV)        wglGetProcAddress("wglDXCloseDeviceNV");
    m_pfnDXRegisterObjectNV      = (PFN_wglDXRegisterObjectNV)     wglGetProcAddress("wglDXRegisterObjectNV");
    m_pfnDXUnregisterObjectNV    = (PFN_wglDXUnregisterObjectNV)   wglGetProcAddress("wglDXUnregisterObjectNV");
    m_pfnDXLockObjectsNV         = (PFN_wglDXLockObjectsNV)        wglGetProcAddress("wglDXLockObjectsNV");
    m_pfnDXUnlockObjectsNV       = (PFN_wglDXUnlockObjectsNV)      wglGetProcAddress("wglDXUnlockObjectsNV");
}

BOOL CMainFrame::InitOpenGL()
{
    TRACE(_T("[GL] begin\n"));

    // Create persistent MFC device context for OpenGL
    m_pGLDC = new CClientDC(this);
    HDC hDC = m_pGLDC->GetSafeHdc();

    PIXELFORMATDESCRIPTOR pfd = {};
    pfd.nSize = sizeof(pfd); pfd.nVersion = 1;
    pfd.dwFlags = PFD_DRAW_TO_WINDOW | PFD_SUPPORT_OPENGL | PFD_DOUBLEBUFFER;
    pfd.iPixelType = PFD_TYPE_RGBA; pfd.cColorBits = 32; pfd.cDepthBits = 24;
    SetPixelFormat(hDC, ChoosePixelFormat(hDC, &pfd), &pfd);

    HGLRC hTmpRC = wglCreateContext(hDC);
    wglMakeCurrent(hDC, hTmpRC);
    m_pfnCreateContextAttribsARB = (PFN_wglCreateContextAttribsARB)
        wglGetProcAddress("wglCreateContextAttribsARB");
    m_hGLRC = m_pfnCreateContextAttribsARB(hDC, 0, NULL);
    wglMakeCurrent(hDC, m_hGLRC);
    wglDeleteContext(hTmpRC);

    TRACE(_T("[GL] GL_VERSION = %hs\n"), (const char*)glGetString(GL_VERSION));
    LoadGLFunctions();

    if (!m_pfnDXOpenDeviceNV) {
        AfxMessageBox(_T("WGL_NV_DX_interop2 not available"), MB_OK | MB_ICONERROR);
        return FALSE;
    }

    // Create SwapChain, set up DX interop, create FBO
    m_pGLSwapChain = CreateCompSwapChain(PANEL_W, PANEL_H);
    if (!m_pGLSwapChain) return FALSE;
    m_pGLSwapChain->GetBuffer(0, __uuidof(ID3D11Texture2D), (void**)&m_pGLBackBuffer);

    m_hGLInteropDev = m_pfnDXOpenDeviceNV(m_pd3dDevice);
    m_pfnGenRenderbuffers(1, &m_nGLRBO);
    m_hGLInteropObj = m_pfnDXRegisterObjectNV(
        m_hGLInteropDev, m_pGLBackBuffer, m_nGLRBO,
        GL_RENDERBUFFER, WGL_ACCESS_READ_WRITE_NV);
    if (!m_hGLInteropObj) {
        AfxMessageBox(_T("wglDXRegisterObjectNV failed"), MB_OK | MB_ICONERROR);
        return FALSE;
    }

    m_pfnGenFramebuffers(1, &m_nGLFBO);
    m_pfnBindFramebuffer(GL_FRAMEBUFFER, m_nGLFBO);
    m_pfnFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0,
                                  GL_RENDERBUFFER, m_nGLRBO);
    if (m_pfnCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE) {
        AfxMessageBox(_T("GL FBO not complete"), MB_OK | MB_ICONERROR);
        return FALSE;
    }
    m_pfnBindFramebuffer(GL_FRAMEBUFFER, 0);

    // Create SpriteVisual for GL panel (WinRT Composition)
    m_pGLSprite = CreateSpriteFromSwapChain(m_pGLSwapChain, 0.0f, &m_pGLSurface);
    if (!m_pGLSprite) return FALSE;

    // Shaders and geometry
    m_pfnGenVertexArrays(1, &m_nGLVAO); m_pfnBindVertexArray(m_nGLVAO);
    m_pfnGenBuffers(2, m_nGLVBO);

    GLfloat verts[] = { 0.0f, 0.5f, 0.0f,  0.5f,-0.5f, 0.0f, -0.5f,-0.5f, 0.0f };
    GLfloat cols[]  = { 1.0f, 0.0f, 0.0f,  0.0f, 1.0f, 0.0f,  0.0f, 0.0f, 1.0f };
    m_pfnBindBuffer(GL_ARRAY_BUFFER, m_nGLVBO[0]);
    m_pfnBufferData(GL_ARRAY_BUFFER, sizeof(verts), verts, GL_STATIC_DRAW);
    m_pfnBindBuffer(GL_ARRAY_BUFFER, m_nGLVBO[1]);
    m_pfnBufferData(GL_ARRAY_BUFFER, sizeof(cols), cols, GL_STATIC_DRAW);

    // Embedded GL shaders (Y-flip to match D3D11/Vulkan orientation)
    const GLchar* vsSrc =
        "#version 460 core\n"
        "layout(location=0) in vec3 pos; layout(location=1) in vec3 col;\n"
        "out vec4 vCol;\n"
        "void main(){ vCol=vec4(col,1); gl_Position=vec4(pos.x,-pos.y,pos.z,1); }\n";
    const GLchar* fsSrc =
        "#version 460 core\n"
        "in vec4 vCol; out vec4 outCol;\n"
        "void main(){ outCol=vCol; }\n";

    GLuint vs = m_pfnCreateShader(GL_VERTEX_SHADER);
    m_pfnShaderSource(vs, 1, &vsSrc, nullptr); m_pfnCompileShader(vs);
    GLuint fs = m_pfnCreateShader(GL_FRAGMENT_SHADER);
    m_pfnShaderSource(fs, 1, &fsSrc, nullptr); m_pfnCompileShader(fs);
    m_nGLProgram = m_pfnCreateProgram();
    m_pfnAttachShader(m_nGLProgram, vs); m_pfnAttachShader(m_nGLProgram, fs);
    m_pfnLinkProgram(m_nGLProgram); m_pfnUseProgram(m_nGLProgram);

    m_nGLPosAttr = m_pfnGetAttribLocation(m_nGLProgram, "pos");
    m_nGLColAttr = m_pfnGetAttribLocation(m_nGLProgram, "col");
    m_pfnEnableVertexAttribArray(m_nGLPosAttr);
    m_pfnEnableVertexAttribArray(m_nGLColAttr);

    TRACE(_T("[GL] ok\n"));
    return TRUE;
}

void CMainFrame::RenderGL()
{
    if (!m_hGLRC) return;

    HDC hDC = m_pGLDC->GetSafeHdc();
    wglMakeCurrent(hDC, m_hGLRC);
    m_pfnDXLockObjectsNV(m_hGLInteropDev, 1, &m_hGLInteropObj);

    m_pfnBindFramebuffer(GL_FRAMEBUFFER, m_nGLFBO);
    glViewport(0, 0, PANEL_W, PANEL_H);
    glClearColor(0.05f, 0.05f, 0.15f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT);

    m_pfnUseProgram(m_nGLProgram);
    m_pfnBindVertexArray(m_nGLVAO);
    m_pfnBindBuffer(GL_ARRAY_BUFFER, m_nGLVBO[0]);
    m_pfnVertexAttribPointer(m_nGLPosAttr, 3, GL_FLOAT, GL_FALSE, 0, 0);
    m_pfnBindBuffer(GL_ARRAY_BUFFER, m_nGLVBO[1]);
    m_pfnVertexAttribPointer(m_nGLColAttr, 3, GL_FLOAT, GL_FALSE, 0, 0);
    glDrawArrays(GL_TRIANGLES, 0, 3);

    m_pfnBindFramebuffer(GL_FRAMEBUFFER, 0);
    glFlush();
    m_pfnDXUnlockObjectsNV(m_hGLInteropDev, 1, &m_hGLInteropObj);
    m_pGLSwapChain->Present(1, 0);
}

// ************************************************************
//  PANEL 1: D3D11 (native)
// ************************************************************
BOOL CMainFrame::InitD3D11Panel()
{
    TRACE(_T("[D3D11] init panel\n"));

    m_pDXSwapChain = CreateCompSwapChain(PANEL_W, PANEL_H);
    if (!m_pDXSwapChain) return FALSE;

    ID3D11Texture2D* pBB = nullptr;
    m_pDXSwapChain->GetBuffer(0, __uuidof(ID3D11Texture2D), (void**)&pBB);
    m_pd3dDevice->CreateRenderTargetView(pBB, nullptr, &m_pDXRTV);
    pBB->Release();

    ID3DBlob* pVSBlob = nullptr; ID3DBlob* pPSBlob = nullptr; ID3DBlob* pErr = nullptr;
    D3DCompile(g_dxHLSL, strlen(g_dxHLSL), "dx", nullptr, nullptr, "VS", "vs_4_0", 0, 0, &pVSBlob, &pErr);
    if (pErr) { TRACE(_T("[D3D11] VS err: %hs\n"), (char*)pErr->GetBufferPointer()); pErr->Release(); }
    D3DCompile(g_dxHLSL, strlen(g_dxHLSL), "dx", nullptr, nullptr, "PS", "ps_4_0", 0, 0, &pPSBlob, &pErr);
    if (pErr) { TRACE(_T("[D3D11] PS err: %hs\n"), (char*)pErr->GetBufferPointer()); pErr->Release(); }

    m_pd3dDevice->CreateVertexShader(pVSBlob->GetBufferPointer(), pVSBlob->GetBufferSize(), nullptr, &m_pDXVS);
    m_pd3dDevice->CreatePixelShader(pPSBlob->GetBufferPointer(), pPSBlob->GetBufferSize(), nullptr, &m_pDXPS);

    D3D11_INPUT_ELEMENT_DESC layout[] = {
        { "POSITION", 0, DXGI_FORMAT_R32G32B32_FLOAT,   0,  0, D3D11_INPUT_PER_VERTEX_DATA, 0 },
        { "COLOR",    0, DXGI_FORMAT_R32G32B32A32_FLOAT, 0, 12, D3D11_INPUT_PER_VERTEX_DATA, 0 },
    };
    m_pd3dDevice->CreateInputLayout(layout, 2, pVSBlob->GetBufferPointer(), pVSBlob->GetBufferSize(), &m_pDXInputLayout);
    pVSBlob->Release(); pPSBlob->Release();

    DxVertex verts[] = {
        {  0.0f,  0.5f, 0.0f,  1,0,0,1 },
        {  0.5f, -0.5f, 0.0f,  0,1,0,1 },
        { -0.5f, -0.5f, 0.0f,  0,0,1,1 },
    };
    D3D11_BUFFER_DESC bd = {}; bd.ByteWidth = sizeof(verts);
    bd.Usage = D3D11_USAGE_DEFAULT; bd.BindFlags = D3D11_BIND_VERTEX_BUFFER;
    D3D11_SUBRESOURCE_DATA sd = {}; sd.pSysMem = verts;
    m_pd3dDevice->CreateBuffer(&bd, &sd, &m_pDXVertexBuffer);

    // Create SpriteVisual for D3D11 panel (WinRT Composition)
    m_pDXSprite = CreateSpriteFromSwapChain(m_pDXSwapChain, (float)PANEL_W, &m_pDXSurface);
    if (!m_pDXSprite) return FALSE;

    TRACE(_T("[D3D11] panel ok\n"));
    return TRUE;
}

void CMainFrame::RenderD3D11()
{
    if (!m_pDXRTV) return;

    float clear[4] = { 0.05f, 0.15f, 0.05f, 1.0f };
    m_pd3dContext->ClearRenderTargetView(m_pDXRTV, clear);
    m_pd3dContext->OMSetRenderTargets(1, &m_pDXRTV, nullptr);

    D3D11_VIEWPORT vp = { 0, 0, (float)PANEL_W, (float)PANEL_H, 0, 1 };
    m_pd3dContext->RSSetViewports(1, &vp);
    m_pd3dContext->IASetInputLayout(m_pDXInputLayout);
    UINT stride = sizeof(DxVertex), offset = 0;
    m_pd3dContext->IASetVertexBuffers(0, 1, &m_pDXVertexBuffer, &stride, &offset);
    m_pd3dContext->IASetPrimitiveTopology(D3D11_PRIMITIVE_TOPOLOGY_TRIANGLELIST);
    m_pd3dContext->VSSetShader(m_pDXVS, nullptr, 0);
    m_pd3dContext->PSSetShader(m_pDXPS, nullptr, 0);
    m_pd3dContext->Draw(3, 0);

    m_pDXSwapChain->Present(1, 0);
}

// ************************************************************
//  PANEL 2: Vulkan (offscreen -> staging -> D3D11 copy)
// ************************************************************
uint32_t CMainFrame::VkFindMemType(uint32_t filter, VkMemoryPropertyFlags props)
{
    VkPhysicalDeviceMemoryProperties mp;
    vkGetPhysicalDeviceMemoryProperties(m_vkPhysDev, &mp);
    for (uint32_t i = 0; i < mp.memoryTypeCount; i++)
        if ((filter & (1 << i)) && (mp.memoryTypes[i].propertyFlags & props) == props)
            return i;
    AfxMessageBox(_T("VkFindMemType: suitable memory type not found"), MB_OK | MB_ICONERROR);
    return 0;
}

BOOL CMainFrame::InitVulkan()
{
    TRACE(_T("[VK] begin\n"));

    VkApplicationInfo ai = {}; ai.sType = VK_STRUCTURE_TYPE_APPLICATION_INFO;
    ai.apiVersion = VK_API_VERSION_1_0;
    VkInstanceCreateInfo ici = {}; ici.sType = VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO;
    ici.pApplicationInfo = &ai;
    if (vkCreateInstance(&ici, nullptr, &m_vkInst) != VK_SUCCESS) {
        AfxMessageBox(_T("vkCreateInstance failed"), MB_OK | MB_ICONERROR);
        return FALSE;
    }

    uint32_t cnt = 0;
    vkEnumeratePhysicalDevices(m_vkInst, &cnt, nullptr);
    std::vector<VkPhysicalDevice> devs(cnt);
    vkEnumeratePhysicalDevices(m_vkInst, &cnt, devs.data());
    for (auto& d : devs) {
        uint32_t qc = 0;
        vkGetPhysicalDeviceQueueFamilyProperties(d, &qc, nullptr);
        std::vector<VkQueueFamilyProperties> qp(qc);
        vkGetPhysicalDeviceQueueFamilyProperties(d, &qc, qp.data());
        for (uint32_t i = 0; i < qc; i++) {
            if (qp[i].queueFlags & VK_QUEUE_GRAPHICS_BIT) {
                m_vkPhysDev = d; m_nVKQueueFamily = i; break;
            }
        }
        if (m_vkPhysDev) break;
    }

    float prio = 1.0f;
    VkDeviceQueueCreateInfo qci = {}; qci.sType = VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO;
    qci.queueFamilyIndex = m_nVKQueueFamily; qci.queueCount = 1; qci.pQueuePriorities = &prio;
    VkDeviceCreateInfo dci = {}; dci.sType = VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO;
    dci.queueCreateInfoCount = 1; dci.pQueueCreateInfos = &qci;
    if (vkCreateDevice(m_vkPhysDev, &dci, nullptr, &m_vkDev) != VK_SUCCESS) {
        AfxMessageBox(_T("vkCreateDevice failed"), MB_OK | MB_ICONERROR);
        return FALSE;
    }
    vkGetDeviceQueue(m_vkDev, m_nVKQueueFamily, 0, &m_vkQueue);

    // Offscreen image (BGRA to match D3D11)
    VkImageCreateInfo imgci = {}; imgci.sType = VK_STRUCTURE_TYPE_IMAGE_CREATE_INFO;
    imgci.imageType = VK_IMAGE_TYPE_2D; imgci.format = VK_FORMAT_B8G8R8A8_UNORM;
    imgci.extent = { PANEL_W, PANEL_H, 1 }; imgci.mipLevels = 1; imgci.arrayLayers = 1;
    imgci.samples = VK_SAMPLE_COUNT_1_BIT; imgci.tiling = VK_IMAGE_TILING_OPTIMAL;
    imgci.usage = VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT | VK_IMAGE_USAGE_TRANSFER_SRC_BIT;
    vkCreateImage(m_vkDev, &imgci, nullptr, &m_vkOffImage);

    VkMemoryRequirements mr; vkGetImageMemoryRequirements(m_vkDev, m_vkOffImage, &mr);
    VkMemoryAllocateInfo mai = {}; mai.sType = VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO;
    mai.allocationSize = mr.size;
    mai.memoryTypeIndex = VkFindMemType(mr.memoryTypeBits, VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT);
    vkAllocateMemory(m_vkDev, &mai, nullptr, &m_vkOffMemory);
    vkBindImageMemory(m_vkDev, m_vkOffImage, m_vkOffMemory, 0);

    VkImageViewCreateInfo ivci = {}; ivci.sType = VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO;
    ivci.image = m_vkOffImage; ivci.viewType = VK_IMAGE_VIEW_TYPE_2D;
    ivci.format = VK_FORMAT_B8G8R8A8_UNORM;
    ivci.subresourceRange = { VK_IMAGE_ASPECT_COLOR_BIT, 0, 1, 0, 1 };
    vkCreateImageView(m_vkDev, &ivci, nullptr, &m_vkOffView);

    VkDeviceSize bufSz = PANEL_W * PANEL_H * 4;
    VkBufferCreateInfo bci = {}; bci.sType = VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO;
    bci.size = bufSz; bci.usage = VK_BUFFER_USAGE_TRANSFER_DST_BIT;
    vkCreateBuffer(m_vkDev, &bci, nullptr, &m_vkStagBuf);
    vkGetBufferMemoryRequirements(m_vkDev, m_vkStagBuf, &mr);
    mai.allocationSize = mr.size;
    mai.memoryTypeIndex = VkFindMemType(mr.memoryTypeBits,
        VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | VK_MEMORY_PROPERTY_HOST_COHERENT_BIT);
    vkAllocateMemory(m_vkDev, &mai, nullptr, &m_vkStagMem);
    vkBindBufferMemory(m_vkDev, m_vkStagBuf, m_vkStagMem, 0);

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
    vkCreateRenderPass(m_vkDev, &rpci, nullptr, &m_vkRenderPass);

    VkFramebufferCreateInfo fci = {}; fci.sType = VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO;
    fci.renderPass = m_vkRenderPass; fci.attachmentCount = 1; fci.pAttachments = &m_vkOffView;
    fci.width = PANEL_W; fci.height = PANEL_H; fci.layers = 1;
    vkCreateFramebuffer(m_vkDev, &fci, nullptr, &m_vkFramebuffer);

    // Pipeline - load SPIR-V shaders
    auto vertCode = ReadSpvFile(_T("hello_vert.spv"));
    auto fragCode = ReadSpvFile(_T("hello_frag.spv"));
    if (vertCode.empty() || fragCode.empty()) return FALSE;

    VkShaderModuleCreateInfo smci = {}; smci.sType = VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO;
    smci.codeSize = vertCode.size(); smci.pCode = (const uint32_t*)vertCode.data();
    VkShaderModule vertMod; vkCreateShaderModule(m_vkDev, &smci, nullptr, &vertMod);
    smci.codeSize = fragCode.size(); smci.pCode = (const uint32_t*)fragCode.data();
    VkShaderModule fragMod; vkCreateShaderModule(m_vkDev, &smci, nullptr, &fragMod);

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

    VkViewport vkVp = { 0, 0, (float)PANEL_W, (float)PANEL_H, 0, 1 };
    VkRect2D sc = { {0,0}, {PANEL_W, PANEL_H} };
    VkPipelineViewportStateCreateInfo vpState = {};
    vpState.sType = VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO;
    vpState.viewportCount = 1; vpState.pViewports = &vkVp;
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
    vkCreatePipelineLayout(m_vkDev, &plci, nullptr, &m_vkPipeLayout);

    VkGraphicsPipelineCreateInfo pci = {}; pci.sType = VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO;
    pci.stageCount = 2; pci.pStages = stages;
    pci.pVertexInputState = &viState; pci.pInputAssemblyState = &iaState;
    pci.pViewportState = &vpState; pci.pRasterizationState = &rsState;
    pci.pMultisampleState = &msState; pci.pColorBlendState = &cbState;
    pci.layout = m_vkPipeLayout; pci.renderPass = m_vkRenderPass;
    vkCreateGraphicsPipelines(m_vkDev, VK_NULL_HANDLE, 1, &pci, nullptr, &m_vkPipeline);
    vkDestroyShaderModule(m_vkDev, vertMod, nullptr);
    vkDestroyShaderModule(m_vkDev, fragMod, nullptr);

    // Command pool / buffer / fence
    VkCommandPoolCreateInfo cpci = {}; cpci.sType = VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO;
    cpci.flags = VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT;
    cpci.queueFamilyIndex = m_nVKQueueFamily;
    vkCreateCommandPool(m_vkDev, &cpci, nullptr, &m_vkCmdPool);

    VkCommandBufferAllocateInfo cbai = {}; cbai.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO;
    cbai.commandPool = m_vkCmdPool; cbai.level = VK_COMMAND_BUFFER_LEVEL_PRIMARY;
    cbai.commandBufferCount = 1;
    vkAllocateCommandBuffers(m_vkDev, &cbai, &m_vkCmdBuf);

    VkFenceCreateInfo fnci = {}; fnci.sType = VK_STRUCTURE_TYPE_FENCE_CREATE_INFO;
    fnci.flags = VK_FENCE_CREATE_SIGNALED_BIT;
    vkCreateFence(m_vkDev, &fnci, nullptr, &m_vkFence);

    // D3D11 swap chain + staging
    m_pVKSwapChain = CreateCompSwapChain(PANEL_W, PANEL_H);
    if (!m_pVKSwapChain) return FALSE;
    m_pVKSwapChain->GetBuffer(0, __uuidof(ID3D11Texture2D), (void**)&m_pVKBackBuffer);

    D3D11_TEXTURE2D_DESC td = {}; td.Width = PANEL_W; td.Height = PANEL_H;
    td.MipLevels = 1; td.ArraySize = 1; td.Format = DXGI_FORMAT_B8G8R8A8_UNORM;
    td.SampleDesc = { 1, 0 }; td.Usage = D3D11_USAGE_STAGING;
    td.CPUAccessFlags = D3D11_CPU_ACCESS_WRITE;
    m_pd3dDevice->CreateTexture2D(&td, nullptr, &m_pVKStagingTex);

    // Create SpriteVisual for VK panel (WinRT Composition)
    m_pVKSprite = CreateSpriteFromSwapChain(m_pVKSwapChain, (float)(PANEL_W * 2), &m_pVKSurface);
    if (!m_pVKSprite) return FALSE;

    TRACE(_T("[VK] ok\n"));
    return TRUE;
}

void CMainFrame::RenderVulkan()
{
    if (!m_vkDev) return;

    vkWaitForFences(m_vkDev, 1, &m_vkFence, VK_TRUE, UINT64_MAX);
    vkResetFences(m_vkDev, 1, &m_vkFence);
    vkResetCommandBuffer(m_vkCmdBuf, 0);

    VkCommandBufferBeginInfo bi = {}; bi.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO;
    vkBeginCommandBuffer(m_vkCmdBuf, &bi);

    VkRenderPassBeginInfo rpbi = {}; rpbi.sType = VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO;
    rpbi.renderPass = m_vkRenderPass; rpbi.framebuffer = m_vkFramebuffer;
    rpbi.renderArea.extent = { PANEL_W, PANEL_H };
    VkClearValue cv = {}; cv.color = { { 0.15f, 0.05f, 0.05f, 1.0f } };
    rpbi.clearValueCount = 1; rpbi.pClearValues = &cv;

    vkCmdBeginRenderPass(m_vkCmdBuf, &rpbi, VK_SUBPASS_CONTENTS_INLINE);
    vkCmdBindPipeline(m_vkCmdBuf, VK_PIPELINE_BIND_POINT_GRAPHICS, m_vkPipeline);
    vkCmdDraw(m_vkCmdBuf, 3, 1, 0, 0);
    vkCmdEndRenderPass(m_vkCmdBuf);

    VkBufferImageCopy region = {}; region.bufferRowLength = PANEL_W;
    region.bufferImageHeight = PANEL_H;
    region.imageSubresource = { VK_IMAGE_ASPECT_COLOR_BIT, 0, 0, 1 };
    region.imageExtent = { PANEL_W, PANEL_H, 1 };
    vkCmdCopyImageToBuffer(m_vkCmdBuf, m_vkOffImage,
        VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL, m_vkStagBuf, 1, &region);
    vkEndCommandBuffer(m_vkCmdBuf);

    VkSubmitInfo si = {}; si.sType = VK_STRUCTURE_TYPE_SUBMIT_INFO;
    si.commandBufferCount = 1; si.pCommandBuffers = &m_vkCmdBuf;
    vkQueueSubmit(m_vkQueue, 1, &si, m_vkFence);
    vkWaitForFences(m_vkDev, 1, &m_vkFence, VK_TRUE, UINT64_MAX);

    void* pVKData = nullptr;
    vkMapMemory(m_vkDev, m_vkStagMem, 0, PANEL_W * PANEL_H * 4, 0, &pVKData);
    D3D11_MAPPED_SUBRESOURCE mapped = {};
    if (SUCCEEDED(m_pd3dContext->Map(m_pVKStagingTex, 0, D3D11_MAP_WRITE, 0, &mapped))) {
        const uint8_t* pSrc = (const uint8_t*)pVKData;
        uint8_t* pDst = (uint8_t*)mapped.pData;
        uint32_t pitch = PANEL_W * 4;
        for (uint32_t y = 0; y < PANEL_H; y++)
            memcpy(pDst + y * mapped.RowPitch, pSrc + y * pitch, pitch);
        m_pd3dContext->Unmap(m_pVKStagingTex, 0);
    }
    vkUnmapMemory(m_vkDev, m_vkStagMem);

    m_pd3dContext->CopyResource(m_pVKBackBuffer, m_pVKStagingTex);
    m_pVKSwapChain->Present(1, 0);
}

// ************************************************************
//  Cleanup
// ************************************************************
void CMainFrame::CleanupAll()
{
    TRACE(_T("[Cleanup] begin\n"));

    // Vulkan
    if (m_vkDev) {
        vkDeviceWaitIdle(m_vkDev);
        vkDestroyFence(m_vkDev, m_vkFence, nullptr);
        vkDestroyCommandPool(m_vkDev, m_vkCmdPool, nullptr);
        vkDestroyPipeline(m_vkDev, m_vkPipeline, nullptr);
        vkDestroyPipelineLayout(m_vkDev, m_vkPipeLayout, nullptr);
        vkDestroyFramebuffer(m_vkDev, m_vkFramebuffer, nullptr);
        vkDestroyRenderPass(m_vkDev, m_vkRenderPass, nullptr);
        vkDestroyImageView(m_vkDev, m_vkOffView, nullptr);
        vkDestroyImage(m_vkDev, m_vkOffImage, nullptr);
        vkFreeMemory(m_vkDev, m_vkOffMemory, nullptr);
        vkDestroyBuffer(m_vkDev, m_vkStagBuf, nullptr);
        vkFreeMemory(m_vkDev, m_vkStagMem, nullptr);
        vkDestroyDevice(m_vkDev, nullptr);
    }
    if (m_vkInst) vkDestroyInstance(m_vkInst, nullptr);
    SafeRelease(&m_pVKStagingTex);
    SafeRelease(&m_pVKBackBuffer);
    SafeRelease(&m_pVKSwapChain);
    SafeRelease(&m_pVKSurface);
    SafeRelease(&m_pVKSprite);

    // OpenGL
    if (m_hGLInteropObj) m_pfnDXUnregisterObjectNV(m_hGLInteropDev, m_hGLInteropObj);
    if (m_hGLInteropDev) m_pfnDXCloseDeviceNV(m_hGLInteropDev);
    if (m_hGLRC) { wglMakeCurrent(nullptr, nullptr); wglDeleteContext(m_hGLRC); }
    if (m_pGLDC) { delete m_pGLDC; m_pGLDC = NULL; }
    SafeRelease(&m_pGLBackBuffer);
    SafeRelease(&m_pGLSwapChain);
    SafeRelease(&m_pGLSurface);
    SafeRelease(&m_pGLSprite);

    // D3D11 panel
    SafeRelease(&m_pDXVertexBuffer);
    SafeRelease(&m_pDXInputLayout);
    SafeRelease(&m_pDXPS);
    SafeRelease(&m_pDXVS);
    SafeRelease(&m_pDXRTV);
    SafeRelease(&m_pDXSwapChain);
    SafeRelease(&m_pDXSurface);
    SafeRelease(&m_pDXSprite);

    // Windows.UI.Composition
    SafeRelease(&m_pChildren);
    SafeRelease(&m_pRootVisual);
    SafeRelease(&m_pRootContainer);
    SafeRelease(&m_pCompTarget);
    SafeRelease(&m_pWindowTarget);
    SafeRelease(&m_pCompDesktopInt);
    SafeRelease(&m_pCompInterop);
    SafeRelease(&m_pCompositor);
    SafeRelease(&m_pDQController);

    // Shared D3D11
    SafeRelease(&m_pd3dContext);
    SafeRelease(&m_pd3dDevice);

    TRACE(_T("[Cleanup] done\n"));
}