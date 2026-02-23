/* hello.c
 * Win32 window + OpenGL 4.6 render triangle into a D3D11 DXGI swapchain created by
 * CreateSwapChainForComposition, then show it via Windows.UI.Composition
 * Desktop interop (DesktopWindowTarget) on classic desktop apps.
 *
 * Pure C implementation using raw COM vtable calls for WinRT interfaces.
 *
 * Logging: DebugView only (OutputDebugStringW). No console, no MessageBox.
 *
 * Build example (MSVC, adjust Windows Kits path if needed):
 *   cl hello.c ^
 *     /link user32.lib gdi32.lib opengl32.lib d3d11.lib dxguid.lib d3dcompiler.lib ^
 *     /SUBSYSTEM:WINDOWS
 */

#define COBJMACROS
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <unknwn.h>
#include <objbase.h>
#include <stdint.h>
#include <stddef.h>
#include <stdarg.h>

#include <gl/gl.h>
#include <d3d11.h>
#include <dxgi1_2.h>
#include <d3dcompiler.h>
#include <roapi.h>

#ifndef WS_EX_NOREDIRECTIONBITMAP
#define WS_EX_NOREDIRECTIONBITMAP 0x00200000L
#endif

#ifndef APIENTRY
#define APIENTRY
#endif
#ifndef APIENTRYP
#define APIENTRYP APIENTRY *
#endif

/* OpenGL/WGL constants not present in old gl.h */
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
#define WGL_CONTEXT_FLAGS_ARB             0x2094
#define WGL_CONTEXT_PROFILE_MASK_ARB      0x9126
#define WGL_CONTEXT_CORE_PROFILE_BIT_ARB  0x00000001
#define WGL_ACCESS_READ_WRITE_NV          0x0001

typedef ptrdiff_t GLsizeiptr;
typedef char GLchar;

typedef void   (APIENTRYP PFNGLGENBUFFERSPROC)(GLsizei, GLuint*);
typedef void   (APIENTRYP PFNGLBINDBUFFERPROC)(GLenum, GLuint);
typedef void   (APIENTRYP PFNGLBUFFERDATAPROC)(GLenum, GLsizeiptr, const void*, GLenum);
typedef GLuint (APIENTRYP PFNGLCREATESHADERPROC)(GLenum);
typedef void   (APIENTRYP PFNGLSHADERSOURCEPROC)(GLuint, GLsizei, const GLchar* const*, const GLint*);
typedef void   (APIENTRYP PFNGLCOMPILESHADERPROC)(GLuint);
typedef void   (APIENTRYP PFNGLGETSHADERIVPROC)(GLuint, GLenum, GLint*);
typedef void   (APIENTRYP PFNGLGETSHADERINFOLOGPROC)(GLuint, GLsizei, GLsizei*, GLchar*);
typedef GLuint (APIENTRYP PFNGLCREATEPROGRAMPROC)(void);
typedef void   (APIENTRYP PFNGLATTACHSHADERPROC)(GLuint, GLuint);
typedef void   (APIENTRYP PFNGLLINKPROGRAMPROC)(GLuint);
typedef void   (APIENTRYP PFNGLGETPROGRAMIVPROC)(GLuint, GLenum, GLint*);
typedef void   (APIENTRYP PFNGLGETPROGRAMINFOLOGPROC)(GLuint, GLsizei, GLsizei*, GLchar*);
typedef void   (APIENTRYP PFNGLUSEPROGRAMPROC)(GLuint);
typedef GLint  (APIENTRYP PFNGLGETATTRIBLOCATIONPROC)(GLuint, const GLchar*);
typedef void   (APIENTRYP PFNGLENABLEVERTEXATTRIBARRAYPROC)(GLuint);
typedef void   (APIENTRYP PFNGLVERTEXATTRIBPOINTERPROC)(GLuint, GLint, GLenum, GLboolean, GLsizei, const void*);
typedef void   (APIENTRYP PFNGLGENVERTEXARRAYSPROC)(GLsizei, GLuint*);
typedef void   (APIENTRYP PFNGLBINDVERTEXARRAYPROC)(GLuint);
typedef void   (APIENTRYP PFNGLGENFRAMEBUFFERSPROC)(GLsizei, GLuint*);
typedef void   (APIENTRYP PFNGLBINDFRAMEBUFFERPROC)(GLenum, GLuint);
typedef void   (APIENTRYP PFNGLFRAMEBUFFERRENDERBUFFERPROC)(GLenum, GLenum, GLenum, GLuint);
typedef GLenum (APIENTRYP PFNGLCHECKFRAMEBUFFERSTATUSPROC)(GLenum);
typedef void   (APIENTRYP PFNGLGENRENDERBUFFERSPROC)(GLsizei, GLuint*);
typedef void   (APIENTRYP PFNGLBINDRENDERBUFFERPROC)(GLenum, GLuint);
typedef void   (APIENTRYP PFNGLDELETEBUFFERSPROC)(GLsizei, const GLuint*);
typedef void   (APIENTRYP PFNGLDELETEVERTEXARRAYSPROC)(GLsizei, const GLuint*);
typedef void   (APIENTRYP PFNGLDELETEFRAMEBUFFERSPROC)(GLsizei, const GLuint*);
typedef void   (APIENTRYP PFNGLDELETERENDERBUFFERSPROC)(GLsizei, const GLuint*);
typedef void   (APIENTRYP PFNGLDELETEPROGRAMPROC)(GLuint);

typedef HGLRC  (WINAPI *PFNWGLCREATECONTEXTATTRIBSARBPROC)(HDC, HGLRC, const int*);
typedef HANDLE (WINAPI *PFNWGLDXOPENDEVICENVPROC)(void*);
typedef BOOL   (WINAPI *PFNWGLDXCLOSEDEVICENVPROC)(HANDLE);
typedef HANDLE (WINAPI *PFNWGLDXREGISTEROBJECTNVPROC)(HANDLE, void*, GLuint, GLenum, GLenum);
typedef BOOL   (WINAPI *PFNWGLDXUNREGISTEROBJECTNVPROC)(HANDLE, HANDLE);
typedef BOOL   (WINAPI *PFNWGLDXLOCKOBJECTSNVPROC)(HANDLE, GLint, HANDLE*);
typedef BOOL   (WINAPI *PFNWGLDXUNLOCKOBJECTSNVPROC)(HANDLE, GLint, HANDLE*);

/* DispatcherQueue.h uses C++ enum class, so we define the types manually for C */
typedef enum DISPATCHERQUEUE_THREAD_TYPE {
    DQTYPE_THREAD_DEDICATED = 1,
    DQTYPE_THREAD_CURRENT   = 2
} DISPATCHERQUEUE_THREAD_TYPE;

typedef enum DISPATCHERQUEUE_THREAD_APARTMENTTYPE {
    DQTAT_COM_NONE = 0,
    DQTAT_COM_ASTA = 1,
    DQTAT_COM_STA  = 2
} DISPATCHERQUEUE_THREAD_APARTMENTTYPE;

typedef struct DispatcherQueueOptions {
    DWORD dwSize;
    DISPATCHERQUEUE_THREAD_TYPE threadType;
    DISPATCHERQUEUE_THREAD_APARTMENTTYPE apartmentType;
} DispatcherQueueOptions;

STDAPI CreateDispatcherQueueController(
    DispatcherQueueOptions options,
    IUnknown** dispatcherQueueController
);

#pragma comment(lib, "CoreMessaging.lib")

#pragma comment(lib, "user32.lib")
#pragma comment(lib, "gdi32.lib")
#pragma comment(lib, "ole32.lib")
#pragma comment(lib, "windowsapp.lib")
#pragma comment(lib, "d3d11.lib")
#pragma comment(lib, "dxgi.lib")
#pragma comment(lib, "d3dcompiler.lib")
#pragma comment(lib, "runtimeobject.lib")

/* ============================================================
 * Vertex definition
 * ============================================================ */
typedef struct _VERTEX
{
    FLOAT x, y, z;
    FLOAT r, g, b, a;
} VERTEX;

/* ============================================================
 * Numerics types used by Composition API
 * ============================================================ */
typedef struct _Vector2
{
    float X;
    float Y;
} Vector2;

/* ============================================================
 * WinRT interface GUIDs
 *
 * We define the minimal set of interfaces needed to:
 *   1. Activate a Compositor
 *   2. Create a DesktopWindowTarget for our HWND
 *   3. Wrap a DXGI swapchain as a composition surface
 *   4. Display it via SpriteVisual -> SurfaceBrush
 * ============================================================ */

/* ICompositor {B403CA50-7F8C-4E83-985F-A414D26F1DAD} */
static const IID IID_ICompositor =
    { 0xB403CA50, 0x7F8C, 0x4E83, { 0x98, 0x5F, 0xA4, 0x14, 0xD2, 0x6F, 0x1D, 0xAD } };

/* ICompositorDesktopInterop {29E691FA-4567-4DCA-B319-D0F207EB6807} */
static const IID IID_ICompositorDesktopInterop =
    { 0x29E691FA, 0x4567, 0x4DCA, { 0xB3, 0x19, 0xD0, 0xF2, 0x07, 0xEB, 0x68, 0x07 } };

/* ICompositorInterop {25297D5C-3AD4-4C9C-B5CF-E36A38512330} */
static const IID IID_ICompositorInterop =
    { 0x25297D5C, 0x3AD4, 0x4C9C, { 0xB5, 0xCF, 0xE3, 0x6A, 0x38, 0x51, 0x23, 0x30 } };

/* ICompositionTarget {A1BEA8BA-D726-4663-8129-6B5E7927FFA6} */
static const IID IID_ICompositionTarget =
    { 0xA1BEA8BA, 0xD726, 0x4663, { 0x81, 0x29, 0x6B, 0x5E, 0x79, 0x27, 0xFF, 0xA6 } };

/* IContainerVisual {02F6BC74-ED20-4773-AFE6-D49B4A93DB32} */
static const IID IID_IContainerVisual =
    { 0x02F6BC74, 0xED20, 0x4773, { 0xAF, 0xE6, 0xD4, 0x9B, 0x4A, 0x93, 0xDB, 0x32 } };

/* IVisual {117E202D-A859-4C89-873B-C2AA566788E3} */
static const IID IID_IVisual =
    { 0x117E202D, 0xA859, 0x4C89, { 0x87, 0x3B, 0xC2, 0xAA, 0x56, 0x67, 0x88, 0xE3 } };

/* ISpriteVisual {08E05581-1AD1-4F97-9757-402D76E4233B} */
static const IID IID_ISpriteVisual =
    { 0x08E05581, 0x1AD1, 0x4F97, { 0x97, 0x57, 0x40, 0x2D, 0x76, 0xE4, 0x23, 0x3B } };

/* ICompositionBrush {AB0D7608-30C0-40E9-B568-B60A6BD1FB46} */
static const IID IID_ICompositionBrush =
    { 0xAB0D7608, 0x30C0, 0x40E9, { 0xB5, 0x68, 0xB6, 0x0A, 0x6B, 0xD1, 0xFB, 0x46 } };

/* ICompositionSurface {1527540D-42C7-47A6-A408-668F79A90DFB} */
static const IID IID_ICompositionSurface =
    { 0x1527540D, 0x42C7, 0x47A6, { 0xA4, 0x08, 0x66, 0x8F, 0x79, 0xA9, 0x0D, 0xFB } };

/* ============================================================
 * WinRT vtable slot helpers
 *
 * WinRT interfaces inherit from IInspectable (6 vtable slots):
 *   0: QueryInterface  1: AddRef  2: Release
 *   3: GetIids  4: GetRuntimeClassName  5: GetTrustLevel
 * Interface-specific methods start at slot 6.
 *
 * COM interop interfaces inherit from IUnknown (3 vtable slots):
 *   0: QueryInterface  1: AddRef  2: Release
 * Interface-specific methods start at slot 3.
 * ============================================================ */

/* Helper: get the raw vtable pointer array from a COM object */
#define VTBL(obj)     ((void***)(obj))[0]

/* Helper: access a vtable slot */
#define SLOT(obj, i)  (VTBL(obj)[(i)])

/* ============================================================
 * Typed wrappers for WinRT vtable calls
 *
 * These use function pointer casts at the correct vtable slot
 * index. The slot numbers come from the WinRT IDL method
 * ordering for each interface.
 * ============================================================ */

/* --- ICompositor (WinRT, slot 6+) ---
 * Method ordering from Windows.UI.Composition.idl:
 *   slot  6: CreateColorKeyFrameAnimation
 *   slot  7: CreateColorBrush()
 *   slot  8: CreateColorBrushWithColor(Color)
 *   slot  9: CreateContainerVisual
 *   slot 10: CreateCubicBezierEasingFunction
 *   slot 11: CreateEffectFactory(IGraphicsEffect)
 *   slot 12: CreateEffectFactory(IGraphicsEffect, IIterable<String>)
 *   slot 13: CreateExpressionAnimation()
 *   slot 14: CreateExpressionAnimation(String)
 *   slot 15: CreateInsetClip()
 *   slot 16: CreateInsetClip(4 floats)
 *   slot 17: CreateLinearEasingFunction
 *   slot 18: CreatePropertySet
 *   slot 19: CreateQuaternionKeyFrameAnimation
 *   slot 20: CreateScalarKeyFrameAnimation
 *   slot 21: CreateScopedBatch
 *   slot 22: CreateSpriteVisual
 *   slot 23: CreateSurfaceBrush()
 *   slot 24: CreateSurfaceBrush(ICompositionSurface)
 *   slot 25: CreateTargetForCurrentView
 *   slot 26: CreateVector2KeyFrameAnimation
 *   slot 27: CreateVector3KeyFrameAnimation
 *   slot 28: CreateVector4KeyFrameAnimation
 *   slot 29: GetCommitBatch
 */
typedef HRESULT (STDMETHODCALLTYPE *PFN_CreateContainerVisual)(void* pThis, void** ppResult);
typedef HRESULT (STDMETHODCALLTYPE *PFN_CreateSpriteVisual)(void* pThis, void** ppResult);
typedef HRESULT (STDMETHODCALLTYPE *PFN_CreateSurfaceBrushWithSurface)(void* pThis, void* pSurface, void** ppResult);

static HRESULT Compositor_CreateContainerVisual(void* compositor, void** ppResult)
{
    return ((PFN_CreateContainerVisual)SLOT(compositor, 9))(compositor, ppResult);
}
static HRESULT Compositor_CreateSpriteVisual(void* compositor, void** ppResult)
{
    return ((PFN_CreateSpriteVisual)SLOT(compositor, 22))(compositor, ppResult);
}
static HRESULT Compositor_CreateSurfaceBrush(void* compositor, void* surface, void** ppResult)
{
    return ((PFN_CreateSurfaceBrushWithSurface)SLOT(compositor, 24))(compositor, surface, ppResult);
}

/* --- ICompositorDesktopInterop (COM, slot 3+) ---
 *   slot 3: CreateDesktopWindowTarget(HWND, BOOL isTopmost, IDesktopWindowTarget**)
 */
typedef HRESULT (STDMETHODCALLTYPE *PFN_CreateDesktopWindowTarget)(
    void* pThis, HWND hwnd, BOOL isTopmost, void** ppResult);

static HRESULT CompositorDesktopInterop_CreateDesktopWindowTarget(
    void* interop, HWND hwnd, BOOL isTopmost, void** ppResult)
{
    return ((PFN_CreateDesktopWindowTarget)SLOT(interop, 3))(interop, hwnd, isTopmost, ppResult);
}

/* --- ICompositorInterop (COM, slot 3+) ---
 *   slot 3: CreateCompositionSurfaceForHandle
 *   slot 4: CreateCompositionSurfaceForSwapChain(IUnknown*, ICompositionSurface**)
 *   slot 5: CreateGraphicsDevice
 */
typedef HRESULT (STDMETHODCALLTYPE *PFN_CreateCompositionSurfaceForSwapChain)(
    void* pThis, IUnknown* pSwapChain, void** ppResult);

static HRESULT CompositorInterop_CreateCompositionSurfaceForSwapChain(
    void* interop, IUnknown* pSwapChain, void** ppResult)
{
    return ((PFN_CreateCompositionSurfaceForSwapChain)SLOT(interop, 4))(interop, pSwapChain, ppResult);
}

/* --- ICompositionTarget (WinRT, slot 6+) ---
 *   slot 6: get_Root
 *   slot 7: put_Root(IVisual*)
 */
typedef HRESULT (STDMETHODCALLTYPE *PFN_put_Root)(void* pThis, void* pVisual);

static HRESULT CompositionTarget_put_Root(void* target, void* visual)
{
    return ((PFN_put_Root)SLOT(target, 7))(target, visual);
}

/* --- IContainerVisual (WinRT, slot 6+) ---
 *   slot 6: get_Children(IVisualCollection**)
 */
typedef HRESULT (STDMETHODCALLTYPE *PFN_get_Children)(void* pThis, void** ppResult);

static HRESULT ContainerVisual_get_Children(void* container, void** ppResult)
{
    return ((PFN_get_Children)SLOT(container, 6))(container, ppResult);
}

/* --- IVisualCollection (WinRT, slot 6+) ---
 *   slot 6: get_Count
 *   slot 7: InsertAbove
 *   slot 8: InsertAtBottom
 *   slot 9: InsertAtTop(IVisual*)
 */
typedef HRESULT (STDMETHODCALLTYPE *PFN_InsertAtTop)(void* pThis, void* pVisual);

static HRESULT VisualCollection_InsertAtTop(void* collection, void* visual)
{
    return ((PFN_InsertAtTop)SLOT(collection, 9))(collection, visual);
}

/* --- IVisual (WinRT, slot 6+) ---
 * Properly define the vtable in C to avoid ABI issues with struct-by-value.
 * We only need put_Size (slot 36), but define all slots for correctness.
 * Methods we don't call are typed as generic void* stubs.
 */
typedef struct IVisualC_Vtbl
{
    /* IUnknown (slots 0-2) */
    HRESULT (STDMETHODCALLTYPE *QueryInterface)(void* pThis, REFIID riid, void** ppOut);
    ULONG   (STDMETHODCALLTYPE *AddRef)(void* pThis);
    ULONG   (STDMETHODCALLTYPE *Release)(void* pThis);
    /* IInspectable (slots 3-5) */
    HRESULT (STDMETHODCALLTYPE *GetIids)(void* pThis, ULONG* count, IID** iids);
    HRESULT (STDMETHODCALLTYPE *GetRuntimeClassName)(void* pThis, HSTRING* name);
    HRESULT (STDMETHODCALLTYPE *GetTrustLevel)(void* pThis, INT32* level);
    /* IVisual methods (slots 6-39) */
    void* get_AnchorPoint;              /* 6 */
    void* put_AnchorPoint;              /* 7 */
    void* get_BackfaceVisibility;       /* 8 */
    void* put_BackfaceVisibility;       /* 9 */
    void* get_BorderMode;               /* 10 */
    void* put_BorderMode;               /* 11 */
    void* get_CenterPoint;              /* 12 */
    void* put_CenterPoint;              /* 13 */
    void* get_Clip;                     /* 14 */
    void* put_Clip;                     /* 15 */
    void* get_CompositeMode;            /* 16 */
    void* put_CompositeMode;            /* 17 */
    void* get_IsVisible;                /* 18 */
    void* put_IsVisible;                /* 19 */
    void* get_Offset;                   /* 20 */
    void* put_Offset;                   /* 21 */
    void* get_Opacity;                  /* 22 */
    void* put_Opacity;                  /* 23 */
    void* get_Orientation;              /* 24 */
    void* put_Orientation;              /* 25 */
    void* get_Parent;                   /* 26 */
    void* get_Properties;               /* 27 */
    void* get_RotationAngle;            /* 28 */
    void* put_RotationAngle;            /* 29 */
    void* get_RotationAngleInDegrees;   /* 30 */
    void* put_RotationAngleInDegrees;   /* 31 */
    void* get_RotationAxis;             /* 32 */
    void* put_RotationAxis;             /* 33 */
    void* get_Scale;                    /* 34 */
    void* put_Scale;                    /* 35 */
    void* get_Size;                     /* 35 */
    HRESULT (STDMETHODCALLTYPE *put_Size)(void* pThis, Vector2 value); /* 36 */
    void* get_TransformMatrix;          /* 37 */
    void* put_TransformMatrix;          /* 38 */
} IVisualC_Vtbl;

/* WinRT IVisual::put_Size expects Vector2 by value */
typedef HRESULT (STDMETHODCALLTYPE *PFN_put_Size)(void* pThis, Vector2 value);

static HRESULT Visual_put_Size(void* visual, float width, float height)
{
    Vector2 v;
    v.X = width;
    v.Y = height;
    return ((PFN_put_Size)SLOT(visual, 36))(visual, v);
}

/* --- ISpriteVisual (WinRT, slot 6+) ---
 *   slot 6: get_Brush
 *   slot 7: put_Brush(ICompositionBrush*)
 */
typedef HRESULT (STDMETHODCALLTYPE *PFN_put_Brush)(void* pThis, void* pBrush);

static HRESULT SpriteVisual_put_Brush(void* sprite, void* brush)
{
    return ((PFN_put_Brush)SLOT(sprite, 7))(sprite, brush);
}

/* ============================================================
 * Generic COM helpers for C
 * ============================================================ */
static HRESULT QI(void* pObj, const IID* riid, void** ppOut)
{
    return ((IUnknown*)pObj)->lpVtbl->QueryInterface((IUnknown*)pObj, riid, ppOut);
}
static ULONG Rel(void* pObj)
{
    if (pObj) return ((IUnknown*)pObj)->lpVtbl->Release((IUnknown*)pObj);
    return 0;
}

/* ============================================================
 * Debug logging: DebugView only
 * ============================================================ */
static void dbgprintf(const wchar_t* fmt, ...)
{
    wchar_t buf[2048];
    va_list ap;
    va_start(ap, fmt);
    wvsprintfW(buf, fmt, ap);
    va_end(ap);
    OutputDebugStringW(buf);
}

static void dbg_step(const wchar_t* fn, const wchar_t* msg)
{
    dbgprintf(L"[STEP] %s : %s\n", fn, msg);
}

static void dbg_hr(const wchar_t* fn, const wchar_t* api, HRESULT hr)
{
    dbgprintf(L"[ERR ] %s : %s failed hr=0x%08X\n", fn, api, (uint32_t)hr);
}

/* ============================================================
 * OpenGL shader sources (for WGL_NV_DX_interop render path)
 * ============================================================ */
static const GLchar* kVS_GLSL =
    "#version 460 core\n"
    "layout(location=0) in vec3 position;\n"
    "layout(location=1) in vec3 color;\n"
    "out vec4 vColor;\n"
    "void main(){ vColor=vec4(color,1.0); gl_Position=vec4(position.x,-position.y,position.z,1.0); }\n";

static const GLchar* kPS_GLSL =
    "#version 460 core\n"
    "in vec4 vColor;\n"
    "out vec4 outColor;\n"
    "void main(){ outColor=vColor; }\n";

/* ============================================================
 * Globals
 * ============================================================ */
static HWND g_hwnd = NULL;
static UINT g_width = 640;
static UINT g_height = 480;

/* COM init flag */
static BOOL g_comInitialized = FALSE;

/* DispatcherQueue controller (keep alive) */
static IUnknown* g_dqController = NULL;

/* D3D11 objects */
static ID3D11Device*            g_d3dDevice = NULL;
static ID3D11DeviceContext*     g_d3dCtx = NULL;
static IDXGISwapChain1*         g_swapChain = NULL;
static ID3D11Texture2D*         g_backBuffer = NULL; /* shared with GL via NV interop */
static ID3D11RenderTargetView*  g_rtv = NULL;
static ID3D11VertexShader*      g_vs = NULL;
static ID3D11PixelShader*       g_ps = NULL;
static ID3D11InputLayout*       g_inputLayout = NULL;
static ID3D11Buffer*            g_vb = NULL;

/* WGL/OpenGL objects */
static HDC   g_hdc = NULL;
static HGLRC g_hglrc = NULL;
static PFNGLGENBUFFERSPROC              p_glGenBuffers = NULL;
static PFNGLBINDBUFFERPROC              p_glBindBuffer = NULL;
static PFNGLBUFFERDATAPROC              p_glBufferData = NULL;
static PFNGLCREATESHADERPROC            p_glCreateShader = NULL;
static PFNGLSHADERSOURCEPROC            p_glShaderSource = NULL;
static PFNGLCOMPILESHADERPROC           p_glCompileShader = NULL;
static PFNGLGETSHADERIVPROC             p_glGetShaderiv = NULL;
static PFNGLGETSHADERINFOLOGPROC        p_glGetShaderInfoLog = NULL;
static PFNGLCREATEPROGRAMPROC           p_glCreateProgram = NULL;
static PFNGLATTACHSHADERPROC            p_glAttachShader = NULL;
static PFNGLLINKPROGRAMPROC             p_glLinkProgram = NULL;
static PFNGLGETPROGRAMIVPROC            p_glGetProgramiv = NULL;
static PFNGLGETPROGRAMINFOLOGPROC       p_glGetProgramInfoLog = NULL;
static PFNGLUSEPROGRAMPROC              p_glUseProgram = NULL;
static PFNGLGETATTRIBLOCATIONPROC       p_glGetAttribLocation = NULL;
static PFNGLENABLEVERTEXATTRIBARRAYPROC p_glEnableVertexAttribArray = NULL;
static PFNGLVERTEXATTRIBPOINTERPROC     p_glVertexAttribPointer = NULL;
static PFNGLGENVERTEXARRAYSPROC         p_glGenVertexArrays = NULL;
static PFNGLBINDVERTEXARRAYPROC         p_glBindVertexArray = NULL;
static PFNGLGENFRAMEBUFFERSPROC         p_glGenFramebuffers = NULL;
static PFNGLBINDFRAMEBUFFERPROC         p_glBindFramebuffer = NULL;
static PFNGLFRAMEBUFFERRENDERBUFFERPROC p_glFramebufferRenderbuffer = NULL;
static PFNGLCHECKFRAMEBUFFERSTATUSPROC  p_glCheckFramebufferStatus = NULL;
static PFNGLGENRENDERBUFFERSPROC        p_glGenRenderbuffers = NULL;
static PFNGLBINDRENDERBUFFERPROC        p_glBindRenderbuffer = NULL;
static PFNGLDELETEBUFFERSPROC           p_glDeleteBuffers = NULL;
static PFNGLDELETEVERTEXARRAYSPROC      p_glDeleteVertexArrays = NULL;
static PFNGLDELETEFRAMEBUFFERSPROC      p_glDeleteFramebuffers = NULL;
static PFNGLDELETERENDERBUFFERSPROC     p_glDeleteRenderbuffers = NULL;
static PFNGLDELETEPROGRAMPROC           p_glDeleteProgram = NULL;

static PFNWGLCREATECONTEXTATTRIBSARBPROC p_wglCreateContextAttribsARB = NULL;
static PFNWGLDXOPENDEVICENVPROC          p_wglDXOpenDeviceNV = NULL;
static PFNWGLDXCLOSEDEVICENVPROC         p_wglDXCloseDeviceNV = NULL;
static PFNWGLDXREGISTEROBJECTNVPROC      p_wglDXRegisterObjectNV = NULL;
static PFNWGLDXUNREGISTEROBJECTNVPROC    p_wglDXUnregisterObjectNV = NULL;
static PFNWGLDXLOCKOBJECTSNVPROC         p_wglDXLockObjectsNV = NULL;
static PFNWGLDXUNLOCKOBJECTSNVPROC       p_wglDXUnlockObjectsNV = NULL;

static HANDLE g_glInteropDevice = NULL;
static HANDLE g_glInteropObject = NULL;
static GLuint g_glVbo[2] = { 0, 0 };
static GLuint g_glVao = 0;
static GLuint g_glProgram = 0;
static GLuint g_glRbo = 0;
static GLuint g_glFbo = 0;
static GLint  g_glPosAttrib = -1;
static GLint  g_glColAttrib = -1;

/* Composition objects (stored as opaque pointers) */
static void* g_compositor = NULL;           /* ICompositor */
static void* g_desktopTarget = NULL;        /* IDesktopWindowTarget */
static void* g_rootVisual = NULL;           /* IContainerVisual */
static void* g_spriteVisual = NULL;         /* ISpriteVisual */
static void* g_compositionSurface = NULL;   /* ICompositionSurface */
static void* g_surfaceBrush = NULL;         /* ICompositionSurfaceBrush */
static void* g_visualCollection = NULL;     /* IVisualCollection */
static void* g_compositionTarget = NULL;    /* ICompositionTarget (QI from target) */
static void* g_visual = NULL;               /* IVisual (QI from sprite) */
static void* g_compositionBrush = NULL;     /* ICompositionBrush (QI from brush) */

/* Interop interfaces (QI from compositor) */
static void* g_desktopInterop = NULL;       /* ICompositorDesktopInterop */
static void* g_compInterop = NULL;          /* ICompositorInterop */

/* ============================================================
 * Win32 window proc
 * ============================================================ */
static LRESULT CALLBACK WndProc(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam)
{
    switch (msg)
    {
    case WM_DESTROY:
        PostQuitMessage(0);
        return 0;

    case WM_PAINT:
    {
        PAINTSTRUCT ps;
        BeginPaint(hWnd, &ps);
        EndPaint(hWnd, &ps);
        return 0;
    }

    default:
        return DefWindowProcW(hWnd, msg, wParam, lParam);
    }
}

/* ============================================================
 * Create window
 * ============================================================ */
static HRESULT CreateAppWindow(HINSTANCE hInst)
{
    const wchar_t* FN = L"CreateAppWindow";
    const wchar_t* kClassName = L"Win32CompTriangleC";
    WNDCLASSEXW wc;
    DWORD style;
    RECT rc;

    dbg_step(FN, L"begin");

    ZeroMemory(&wc, sizeof(wc));
    wc.cbSize        = sizeof(wc);
    wc.hInstance     = hInst;
    wc.lpszClassName = kClassName;
    wc.lpfnWndProc   = WndProc;
    wc.hCursor       = LoadCursorW(NULL, MAKEINTRESOURCEW(32512)); /* IDC_ARROW */
    wc.hbrBackground = NULL; /* No GDI background - composition handles rendering */

    if (!RegisterClassExW(&wc))
    {
        DWORD gle = GetLastError();
        if (gle != ERROR_CLASS_ALREADY_EXISTS)
        {
            dbgprintf(L"[WIN ] %s : RegisterClassExW failed GLE=%lu\n", FN, gle);
            return HRESULT_FROM_WIN32(gle);
        }
    }

    style = WS_OVERLAPPEDWINDOW;
    rc.left = 0; rc.top = 0; rc.right = (LONG)g_width; rc.bottom = (LONG)g_height;
    AdjustWindowRect(&rc, style, FALSE);

    g_hwnd = CreateWindowExW(
        WS_EX_NOREDIRECTIONBITMAP, kClassName,
        L"OpenGL 4.6 Triangle via Windows.UI.Composition (C)",
        style,
        CW_USEDEFAULT, CW_USEDEFAULT,
        rc.right - rc.left, rc.bottom - rc.top,
        NULL, NULL, hInst, NULL
    );

    if (!g_hwnd)
    {
        DWORD gle = GetLastError();
        dbgprintf(L"[WIN ] %s : CreateWindowExW failed GLE=%lu\n", FN, gle);
        return HRESULT_FROM_WIN32(gle);
    }

    ShowWindow(g_hwnd, SW_SHOW);
    UpdateWindow(g_hwnd);

    dbg_step(FN, L"ok");
    return S_OK;
}

/* ============================================================
 * DispatcherQueue (required for some Composition operations)
 * ============================================================ */
static HRESULT InitDispatcherQueue(void)
{
    const wchar_t* FN = L"InitDispatcherQueue";
    DispatcherQueueOptions opt;
    HRESULT hr;

    dbg_step(FN, L"begin");

    if (g_dqController)
    {
        dbg_step(FN, L"already initialized");
        return S_OK;
    }

    ZeroMemory(&opt, sizeof(opt));
    opt.dwSize        = sizeof(opt);
    opt.threadType    = DQTYPE_THREAD_CURRENT;
    opt.apartmentType = DQTAT_COM_STA;

    hr = CreateDispatcherQueueController(
        opt,
        &g_dqController
    );
    if (FAILED(hr))
    {
        dbg_hr(FN, L"CreateDispatcherQueueController", hr);
        return hr;
    }

    dbg_step(FN, L"ok");
    return S_OK;
}

/* ============================================================
 * OpenGL / WGL interop helpers
 * ============================================================ */
static void* GetGLProc(const char* name)
{
    void* p = (void*)wglGetProcAddress(name);
    if (!p || p == (void*)0x1 || p == (void*)0x2 || p == (void*)0x3 || p == (void*)-1)
    {
        HMODULE h = GetModuleHandleA("opengl32.dll");
        if (h) p = (void*)GetProcAddress(h, name);
    }
    return p;
}

#define LOAD_GL_PROC(dst, type, name) \
    do { dst = (type)GetGLProc(name); if (!(dst)) { dbgprintf(L"[ERR ] InitOpenGL : missing %S\n", name); return E_FAIL; } } while (0)

static HGLRC EnableOpenGL(HDC hdc)
{
    PIXELFORMATDESCRIPTOR pfd;
    int pf;
    HGLRC oldRc;
    HGLRC rc;
    int attrs[] = {
        WGL_CONTEXT_MAJOR_VERSION_ARB, 4,
        WGL_CONTEXT_MINOR_VERSION_ARB, 6,
        WGL_CONTEXT_FLAGS_ARB, 0,
        WGL_CONTEXT_PROFILE_MASK_ARB, WGL_CONTEXT_CORE_PROFILE_BIT_ARB,
        0
    };

    ZeroMemory(&pfd, sizeof(pfd));
    pfd.nSize = sizeof(pfd);
    pfd.nVersion = 1;
    pfd.dwFlags = PFD_DRAW_TO_WINDOW | PFD_SUPPORT_OPENGL | PFD_DOUBLEBUFFER;
    pfd.iPixelType = PFD_TYPE_RGBA;
    pfd.cColorBits = 32;
    pfd.cDepthBits = 24;
    pfd.iLayerType = PFD_MAIN_PLANE;

    pf = ChoosePixelFormat(hdc, &pfd);
    if (pf == 0) return NULL;
    if (!SetPixelFormat(hdc, pf, &pfd))
    {
        DWORD gle = GetLastError();
        if (gle != ERROR_INVALID_PIXEL_FORMAT) return NULL;
    }

    oldRc = wglCreateContext(hdc);
    if (!oldRc) return NULL;
    if (!wglMakeCurrent(hdc, oldRc))
    {
        wglDeleteContext(oldRc);
        return NULL;
    }

    p_wglCreateContextAttribsARB = (PFNWGLCREATECONTEXTATTRIBSARBPROC)GetGLProc("wglCreateContextAttribsARB");
    if (!p_wglCreateContextAttribsARB)
    {
        return oldRc; /* fallback legacy context if extension missing */
    }

    rc = p_wglCreateContextAttribsARB(hdc, 0, attrs);
    if (!rc)
    {
        /* fallback - extension present but 4.6 create failed */
        return oldRc;
    }

    wglMakeCurrent(hdc, rc);
    wglDeleteContext(oldRc);
    return rc;
}

static void DisableOpenGL(void)
{
    if (g_hglrc)
    {
        wglMakeCurrent(NULL, NULL);
        wglDeleteContext(g_hglrc);
        g_hglrc = NULL;
    }
    if (g_hdc && g_hwnd)
    {
        ReleaseDC(g_hwnd, g_hdc);
        g_hdc = NULL;
    }
}

static HRESULT CheckGLShader(GLuint shader, const wchar_t* label)
{
    GLint ok = 0;
    GLchar logbuf[1024];
    GLsizei loglen = 0;
    p_glGetShaderiv(shader, GL_COMPILE_STATUS, &ok);
    if (ok) return S_OK;
    if (p_glGetShaderInfoLog)
    {
        p_glGetShaderInfoLog(shader, (GLsizei)(sizeof(logbuf) - 1), &loglen, logbuf);
        if (loglen > 0)
        {
            logbuf[loglen < (GLsizei)(sizeof(logbuf) - 1) ? loglen : (GLsizei)(sizeof(logbuf) - 1)] = '\0';
            OutputDebugStringA((const char*)logbuf);
            OutputDebugStringA("\n");
        }
    }
    dbgprintf(L"[ERR ] InitOpenGL : shader compile failed (%s)\n", label);
    return E_FAIL;
}

static HRESULT CheckGLProgram(GLuint program)
{
    GLint ok = 0;
    GLchar logbuf[1024];
    GLsizei loglen = 0;
    p_glGetProgramiv(program, GL_LINK_STATUS, &ok);
    if (ok) return S_OK;
    if (p_glGetProgramInfoLog)
    {
        p_glGetProgramInfoLog(program, (GLsizei)(sizeof(logbuf) - 1), &loglen, logbuf);
        if (loglen > 0)
        {
            logbuf[loglen < (GLsizei)(sizeof(logbuf) - 1) ? loglen : (GLsizei)(sizeof(logbuf) - 1)] = '\0';
            OutputDebugStringA((const char*)logbuf);
            OutputDebugStringA("\n");
        }
    }
    dbg_step(L"InitOpenGL", L"program link failed");
    return E_FAIL;
}

static HRESULT InitOpenGLForComposition(void)
{
    const wchar_t* FN = L"InitOpenGL";
    HRESULT hr = S_OK;
    GLuint vs = 0, ps = 0;
    GLenum fboStatus;
    GLfloat verts[] = {
        -0.5f, -0.5f, 0.0f,
         0.5f, -0.5f, 0.0f,
         0.0f,  0.5f, 0.0f
    };
    GLfloat cols[] = {
        0.0f, 0.0f, 1.0f,
        0.0f, 1.0f, 0.0f,
        1.0f, 0.0f, 0.0f
    };

    dbg_step(FN, L"begin");

    if (!g_hwnd || !g_d3dDevice || !g_swapChain || !g_backBuffer)
    {
        dbg_step(FN, L"missing HWND/D3D state/backbuffer");
        return E_FAIL;
    }

    g_hdc = GetDC(g_hwnd);
    if (!g_hdc)
    {
        dbg_step(FN, L"GetDC failed");
        return HRESULT_FROM_WIN32(GetLastError());
    }

    g_hglrc = EnableOpenGL(g_hdc);
    if (!g_hglrc)
    {
        dbg_step(FN, L"EnableOpenGL failed");
        return E_FAIL;
    }
    if (!wglMakeCurrent(g_hdc, g_hglrc))
    {
        dbg_step(FN, L"wglMakeCurrent failed");
        return E_FAIL;
    }

    LOAD_GL_PROC(p_glGenBuffers, PFNGLGENBUFFERSPROC, "glGenBuffers");
    LOAD_GL_PROC(p_glBindBuffer, PFNGLBINDBUFFERPROC, "glBindBuffer");
    LOAD_GL_PROC(p_glBufferData, PFNGLBUFFERDATAPROC, "glBufferData");
    LOAD_GL_PROC(p_glCreateShader, PFNGLCREATESHADERPROC, "glCreateShader");
    LOAD_GL_PROC(p_glShaderSource, PFNGLSHADERSOURCEPROC, "glShaderSource");
    LOAD_GL_PROC(p_glCompileShader, PFNGLCOMPILESHADERPROC, "glCompileShader");
    LOAD_GL_PROC(p_glGetShaderiv, PFNGLGETSHADERIVPROC, "glGetShaderiv");
    LOAD_GL_PROC(p_glGetShaderInfoLog, PFNGLGETSHADERINFOLOGPROC, "glGetShaderInfoLog");
    LOAD_GL_PROC(p_glCreateProgram, PFNGLCREATEPROGRAMPROC, "glCreateProgram");
    LOAD_GL_PROC(p_glAttachShader, PFNGLATTACHSHADERPROC, "glAttachShader");
    LOAD_GL_PROC(p_glLinkProgram, PFNGLLINKPROGRAMPROC, "glLinkProgram");
    LOAD_GL_PROC(p_glGetProgramiv, PFNGLGETPROGRAMIVPROC, "glGetProgramiv");
    LOAD_GL_PROC(p_glGetProgramInfoLog, PFNGLGETPROGRAMINFOLOGPROC, "glGetProgramInfoLog");
    LOAD_GL_PROC(p_glUseProgram, PFNGLUSEPROGRAMPROC, "glUseProgram");
    LOAD_GL_PROC(p_glGetAttribLocation, PFNGLGETATTRIBLOCATIONPROC, "glGetAttribLocation");
    LOAD_GL_PROC(p_glEnableVertexAttribArray, PFNGLENABLEVERTEXATTRIBARRAYPROC, "glEnableVertexAttribArray");
    LOAD_GL_PROC(p_glVertexAttribPointer, PFNGLVERTEXATTRIBPOINTERPROC, "glVertexAttribPointer");
    LOAD_GL_PROC(p_glGenVertexArrays, PFNGLGENVERTEXARRAYSPROC, "glGenVertexArrays");
    LOAD_GL_PROC(p_glBindVertexArray, PFNGLBINDVERTEXARRAYPROC, "glBindVertexArray");
    LOAD_GL_PROC(p_glGenFramebuffers, PFNGLGENFRAMEBUFFERSPROC, "glGenFramebuffers");
    LOAD_GL_PROC(p_glBindFramebuffer, PFNGLBINDFRAMEBUFFERPROC, "glBindFramebuffer");
    LOAD_GL_PROC(p_glFramebufferRenderbuffer, PFNGLFRAMEBUFFERRENDERBUFFERPROC, "glFramebufferRenderbuffer");
    LOAD_GL_PROC(p_glCheckFramebufferStatus, PFNGLCHECKFRAMEBUFFERSTATUSPROC, "glCheckFramebufferStatus");
    LOAD_GL_PROC(p_glGenRenderbuffers, PFNGLGENRENDERBUFFERSPROC, "glGenRenderbuffers");
    LOAD_GL_PROC(p_glBindRenderbuffer, PFNGLBINDRENDERBUFFERPROC, "glBindRenderbuffer");

    p_glDeleteBuffers = (PFNGLDELETEBUFFERSPROC)GetGLProc("glDeleteBuffers");
    p_glDeleteVertexArrays = (PFNGLDELETEVERTEXARRAYSPROC)GetGLProc("glDeleteVertexArrays");
    p_glDeleteFramebuffers = (PFNGLDELETEFRAMEBUFFERSPROC)GetGLProc("glDeleteFramebuffers");
    p_glDeleteRenderbuffers = (PFNGLDELETERENDERBUFFERSPROC)GetGLProc("glDeleteRenderbuffers");
    p_glDeleteProgram = (PFNGLDELETEPROGRAMPROC)GetGLProc("glDeleteProgram");

    LOAD_GL_PROC(p_wglDXOpenDeviceNV, PFNWGLDXOPENDEVICENVPROC, "wglDXOpenDeviceNV");
    LOAD_GL_PROC(p_wglDXCloseDeviceNV, PFNWGLDXCLOSEDEVICENVPROC, "wglDXCloseDeviceNV");
    LOAD_GL_PROC(p_wglDXRegisterObjectNV, PFNWGLDXREGISTEROBJECTNVPROC, "wglDXRegisterObjectNV");
    LOAD_GL_PROC(p_wglDXUnregisterObjectNV, PFNWGLDXUNREGISTEROBJECTNVPROC, "wglDXUnregisterObjectNV");
    LOAD_GL_PROC(p_wglDXLockObjectsNV, PFNWGLDXLOCKOBJECTSNVPROC, "wglDXLockObjectsNV");
    LOAD_GL_PROC(p_wglDXUnlockObjectsNV, PFNWGLDXUNLOCKOBJECTSNVPROC, "wglDXUnlockObjectsNV");

    g_glInteropDevice = p_wglDXOpenDeviceNV(g_d3dDevice);
    if (!g_glInteropDevice)
    {
        dbg_step(FN, L"wglDXOpenDeviceNV failed");
        return E_FAIL;
    }

    p_glGenRenderbuffers(1, &g_glRbo);
    p_glBindRenderbuffer(GL_RENDERBUFFER, g_glRbo);

    g_glInteropObject = p_wglDXRegisterObjectNV(
        g_glInteropDevice,
        g_backBuffer,
        g_glRbo,
        GL_RENDERBUFFER,
        WGL_ACCESS_READ_WRITE_NV);
    if (!g_glInteropObject)
    {
        dbg_step(FN, L"wglDXRegisterObjectNV failed");
        return E_FAIL;
    }

    p_glGenFramebuffers(1, &g_glFbo);
    p_glBindFramebuffer(GL_FRAMEBUFFER, g_glFbo);
    p_glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, g_glRbo);
    fboStatus = p_glCheckFramebufferStatus(GL_FRAMEBUFFER);
    p_glBindFramebuffer(GL_FRAMEBUFFER, 0);
    if (fboStatus != GL_FRAMEBUFFER_COMPLETE)
    {
        dbgprintf(L"[ERR ] %s : FBO incomplete status=0x%04X\n", FN, (unsigned int)fboStatus);
        return E_FAIL;
    }

    p_glGenVertexArrays(1, &g_glVao);
    p_glBindVertexArray(g_glVao);

    p_glGenBuffers(2, g_glVbo);
    p_glBindBuffer(GL_ARRAY_BUFFER, g_glVbo[0]);
    p_glBufferData(GL_ARRAY_BUFFER, sizeof(verts), verts, GL_STATIC_DRAW);
    p_glBindBuffer(GL_ARRAY_BUFFER, g_glVbo[1]);
    p_glBufferData(GL_ARRAY_BUFFER, sizeof(cols), cols, GL_STATIC_DRAW);

    vs = p_glCreateShader(GL_VERTEX_SHADER);
    p_glShaderSource(vs, 1, &kVS_GLSL, NULL);
    p_glCompileShader(vs);
    hr = CheckGLShader(vs, L"VS");
    if (FAILED(hr)) return hr;

    ps = p_glCreateShader(GL_FRAGMENT_SHADER);
    p_glShaderSource(ps, 1, &kPS_GLSL, NULL);
    p_glCompileShader(ps);
    hr = CheckGLShader(ps, L"PS");
    if (FAILED(hr)) return hr;

    g_glProgram = p_glCreateProgram();
    p_glAttachShader(g_glProgram, vs);
    p_glAttachShader(g_glProgram, ps);
    p_glLinkProgram(g_glProgram);
    hr = CheckGLProgram(g_glProgram);
    if (FAILED(hr)) return hr;

    p_glUseProgram(g_glProgram);
    g_glPosAttrib = p_glGetAttribLocation(g_glProgram, "position");
    g_glColAttrib = p_glGetAttribLocation(g_glProgram, "color");
    if (g_glPosAttrib < 0 || g_glColAttrib < 0)
    {
        dbg_step(FN, L"attrib lookup failed");
        return E_FAIL;
    }
    p_glEnableVertexAttribArray((GLuint)g_glPosAttrib);
    p_glEnableVertexAttribArray((GLuint)g_glColAttrib);

    dbg_step(FN, L"ok");
    return S_OK;
}

/* ============================================================
 * D3D11 HLSL shader sources (embedded)
 * ============================================================ */
static const char* kVS_HLSL =
    "struct VSInput { float3 pos:POSITION; float4 col:COLOR; };\n"
    "struct VSOutput{ float4 pos:SV_POSITION; float4 col:COLOR; };\n"
    "VSOutput main(VSInput i){ VSOutput o; o.pos=float4(i.pos,1); o.col=i.col; return o; }\n";

static const char* kPS_HLSL =
    "struct PSInput { float4 pos:SV_POSITION; float4 col:COLOR; };\n"
    "float4 main(PSInput i):SV_TARGET{ return i.col; }\n";

/* ============================================================
 * Compile HLSL from memory
 * ============================================================ */
static HRESULT CompileShader(const char* src, const char* entry, const char* target, ID3DBlob** ppBlob)
{
    const wchar_t* FN = L"CompileShader";
    UINT flags = D3DCOMPILE_ENABLE_STRICTNESS;
    ID3DBlob* pErr = NULL;
    HRESULT hr;

    hr = D3DCompile(src, strlen(src), NULL, NULL, NULL, entry, target, flags, 0, ppBlob, &pErr);
    if (FAILED(hr))
    {
        if (pErr)
        {
            OutputDebugStringA((const char*)pErr->lpVtbl->GetBufferPointer(pErr));
            pErr->lpVtbl->Release(pErr);
        }
        dbg_hr(FN, L"D3DCompile", hr);
        return hr;
    }
    if (pErr) pErr->lpVtbl->Release(pErr);

    return S_OK;
}

/* ============================================================
 * Create render target view from swapchain
 * ============================================================ */
static HRESULT CreateRenderTarget(void)
{
    const wchar_t* FN = L"CreateRenderTarget";
    ID3D11Texture2D* pBackBuffer = NULL;
    HRESULT hr;

    dbg_step(FN, L"begin");

    if (g_rtv)
    {
        g_rtv->lpVtbl->Release(g_rtv);
        g_rtv = NULL;
    }
    if (g_backBuffer)
    {
        g_backBuffer->lpVtbl->Release(g_backBuffer);
        g_backBuffer = NULL;
    }

    hr = g_swapChain->lpVtbl->GetBuffer(g_swapChain, 0,
        &IID_ID3D11Texture2D, (void**)&pBackBuffer);
    if (FAILED(hr))
    {
        dbg_hr(FN, L"SwapChain::GetBuffer", hr);
        return hr;
    }

    hr = g_d3dDevice->lpVtbl->CreateRenderTargetView(
        g_d3dDevice, (ID3D11Resource*)(IUnknown*)pBackBuffer, NULL, &g_rtv);
    if (FAILED(hr))
    {
        pBackBuffer->lpVtbl->Release(pBackBuffer);
        dbg_hr(FN, L"CreateRenderTargetView", hr);
        return hr;
    }

    /* Keep the back buffer texture alive for WGL_NV_DX_interop registration */
    g_backBuffer = pBackBuffer;

    dbg_step(FN, L"ok");
    return S_OK;
}

/* ============================================================
 * Initialize D3D11 + SwapChain for Composition
 * ============================================================ */
static HRESULT InitD3D11AndSwapChainForComposition(void)
{
    const wchar_t* FN = L"InitD3D11AndSwapChainForComposition";
    HRESULT hr;
    UINT deviceFlags = D3D11_CREATE_DEVICE_BGRA_SUPPORT;  /* IMPORTANT for composition */
    D3D_FEATURE_LEVEL fls[] = { D3D_FEATURE_LEVEL_11_0 };
    D3D_FEATURE_LEVEL flOut = D3D_FEATURE_LEVEL_11_0;
    IDXGIDevice* dxgiDevice = NULL;
    IDXGIAdapter* adapter = NULL;
    IDXGIFactory2* factory = NULL;
    DXGI_SWAP_CHAIN_DESC1 desc;
    ID3DBlob* vsBlob = NULL;
    ID3DBlob* psBlob = NULL;
    D3D11_INPUT_ELEMENT_DESC layout[2];
    D3D11_BUFFER_DESC bd;
    D3D11_SUBRESOURCE_DATA initData;

    VERTEX verts[3] = {
        {  0.0f,  0.5f, 0.5f,  1.0f, 0.0f, 0.0f, 1.0f },
        {  0.5f, -0.5f, 0.5f,  0.0f, 1.0f, 0.0f, 1.0f },
        { -0.5f, -0.5f, 0.5f,  0.0f, 0.0f, 1.0f, 1.0f },
    };

    dbg_step(FN, L"begin");

    /* Create D3D11 device (no swapchain yet) */
    hr = D3D11CreateDevice(
        NULL, D3D_DRIVER_TYPE_HARDWARE, NULL,
        deviceFlags,
        fls, 1,
        D3D11_SDK_VERSION,
        &g_d3dDevice, &flOut, &g_d3dCtx
    );
    if (FAILED(hr))
    {
        dbg_hr(FN, L"D3D11CreateDevice", hr);
        return hr;
    }
    dbg_step(FN, L"D3D11 device created");

    /* Get DXGI factory via device -> adapter -> factory */
    hr = g_d3dDevice->lpVtbl->QueryInterface(g_d3dDevice, &IID_IDXGIDevice, (void**)&dxgiDevice);
    if (FAILED(hr)) { dbg_hr(FN, L"QI(IDXGIDevice)", hr); return hr; }

    hr = dxgiDevice->lpVtbl->GetAdapter(dxgiDevice, &adapter);
    dxgiDevice->lpVtbl->Release(dxgiDevice);
    if (FAILED(hr)) { dbg_hr(FN, L"GetAdapter", hr); return hr; }

    hr = adapter->lpVtbl->GetParent(adapter, &IID_IDXGIFactory2, (void**)&factory);
    adapter->lpVtbl->Release(adapter);
    if (FAILED(hr)) { dbg_hr(FN, L"GetParent(IDXGIFactory2)", hr); return hr; }

    /* Create swapchain for composition (not for HWND) */
    ZeroMemory(&desc, sizeof(desc));
    desc.Width              = g_width;
    desc.Height             = g_height;
    desc.Format             = DXGI_FORMAT_B8G8R8A8_UNORM;
    desc.SampleDesc.Count   = 1;
    desc.BufferUsage        = DXGI_USAGE_RENDER_TARGET_OUTPUT;
    desc.BufferCount        = 2;
    desc.Scaling            = DXGI_SCALING_STRETCH;
    desc.SwapEffect         = DXGI_SWAP_EFFECT_FLIP_SEQUENTIAL;
    desc.AlphaMode          = DXGI_ALPHA_MODE_PREMULTIPLIED;

    hr = factory->lpVtbl->CreateSwapChainForComposition(
        factory, (IUnknown*)g_d3dDevice, &desc, NULL, &g_swapChain);
    factory->lpVtbl->Release(factory);
    if (FAILED(hr))
    {
        dbg_hr(FN, L"CreateSwapChainForComposition", hr);
        return hr;
    }
    dbg_step(FN, L"SwapChain for Composition created");

    /* Render target */
    hr = CreateRenderTarget();
    if (FAILED(hr)) return hr;

    /* Compile vertex shader */
    hr = CompileShader(kVS_HLSL, "main", "vs_4_0", &vsBlob);
    if (FAILED(hr)) return hr;

    hr = g_d3dDevice->lpVtbl->CreateVertexShader(g_d3dDevice,
        vsBlob->lpVtbl->GetBufferPointer(vsBlob),
        vsBlob->lpVtbl->GetBufferSize(vsBlob),
        NULL, &g_vs);
    if (FAILED(hr))
    {
        dbg_hr(FN, L"CreateVertexShader", hr);
        vsBlob->lpVtbl->Release(vsBlob);
        return hr;
    }

    /* Compile pixel shader */
    hr = CompileShader(kPS_HLSL, "main", "ps_4_0", &psBlob);
    if (FAILED(hr))
    {
        vsBlob->lpVtbl->Release(vsBlob);
        return hr;
    }

    hr = g_d3dDevice->lpVtbl->CreatePixelShader(g_d3dDevice,
        psBlob->lpVtbl->GetBufferPointer(psBlob),
        psBlob->lpVtbl->GetBufferSize(psBlob),
        NULL, &g_ps);
    psBlob->lpVtbl->Release(psBlob);
    if (FAILED(hr))
    {
        dbg_hr(FN, L"CreatePixelShader", hr);
        vsBlob->lpVtbl->Release(vsBlob);
        return hr;
    }

    /* Input layout */
    layout[0].SemanticName         = "POSITION";
    layout[0].SemanticIndex        = 0;
    layout[0].Format               = DXGI_FORMAT_R32G32B32_FLOAT;
    layout[0].InputSlot            = 0;
    layout[0].AlignedByteOffset    = 0;
    layout[0].InputSlotClass       = D3D11_INPUT_PER_VERTEX_DATA;
    layout[0].InstanceDataStepRate = 0;

    layout[1].SemanticName         = "COLOR";
    layout[1].SemanticIndex        = 0;
    layout[1].Format               = DXGI_FORMAT_R32G32B32A32_FLOAT;
    layout[1].InputSlot            = 0;
    layout[1].AlignedByteOffset    = 12;
    layout[1].InputSlotClass       = D3D11_INPUT_PER_VERTEX_DATA;
    layout[1].InstanceDataStepRate = 0;

    hr = g_d3dDevice->lpVtbl->CreateInputLayout(g_d3dDevice,
        layout, 2,
        vsBlob->lpVtbl->GetBufferPointer(vsBlob),
        vsBlob->lpVtbl->GetBufferSize(vsBlob),
        &g_inputLayout);
    vsBlob->lpVtbl->Release(vsBlob);
    if (FAILED(hr))
    {
        dbg_hr(FN, L"CreateInputLayout", hr);
        return hr;
    }

    /* Vertex buffer */
    ZeroMemory(&bd, sizeof(bd));
    bd.Usage          = D3D11_USAGE_DEFAULT;
    bd.ByteWidth      = sizeof(verts);
    bd.BindFlags      = D3D11_BIND_VERTEX_BUFFER;
    bd.CPUAccessFlags = 0;

    ZeroMemory(&initData, sizeof(initData));
    initData.pSysMem = verts;

    hr = g_d3dDevice->lpVtbl->CreateBuffer(g_d3dDevice, &bd, &initData, &g_vb);
    if (FAILED(hr))
    {
        dbg_hr(FN, L"CreateBuffer(VB)", hr);
        return hr;
    }

    dbg_step(FN, L"ok");
    return S_OK;
}

/* ============================================================
 * Initialize Composition for HWND
 *
 * This creates the WinRT Compositor, DesktopWindowTarget,
 * and wires the DXGI swapchain as a composition surface.
 * ============================================================ */
static HRESULT InitCompositionForHwnd(void)
{
    const wchar_t* FN = L"InitCompositionForHwnd";
    HRESULT hr;
    HSTRING hClassName = NULL;
    HSTRING_HEADER hdr;
    IInspectable* inspectable = NULL;
    void* sprite_asVisual = NULL;

    dbg_step(FN, L"begin");

    if (!g_hwnd || !IsWindow(g_hwnd))
    {
        dbg_step(FN, L"HWND invalid");
        return E_INVALIDARG;
    }

    /* COM STA */
    hr = CoInitializeEx(NULL, COINIT_APARTMENTTHREADED);
    if (SUCCEEDED(hr))
    {
        g_comInitialized = TRUE;
        dbg_step(FN, L"CoInitializeEx(STA) ok");
    }
    else if (hr == RPC_E_CHANGED_MODE)
    {
        dbg_step(FN, L"CoInitializeEx returned RPC_E_CHANGED_MODE (continuing)");
    }
    else
    {
        dbg_hr(FN, L"CoInitializeEx", hr);
        return hr;
    }

    /* DispatcherQueue must exist before certain Composition calls */
    hr = InitDispatcherQueue();
    if (FAILED(hr)) return hr;

    /* Initialize WinRT */
    hr = RoInitialize(RO_INIT_SINGLETHREADED);
    if (FAILED(hr) && hr != S_FALSE && hr != RPC_E_CHANGED_MODE)
    {
        dbg_hr(FN, L"RoInitialize", hr);
        return hr;
    }
    dbg_step(FN, L"RoInitialize ok");

    /* Activate Compositor via WinRT activation */
    {
        const wchar_t* className = L"Windows.UI.Composition.Compositor";
        hr = WindowsCreateStringReference(
            className, (UINT32)wcslen(className), &hdr, &hClassName);
    }
    if (FAILED(hr))
    {
        dbg_hr(FN, L"WindowsCreateStringReference", hr);
        return hr;
    }

    hr = RoActivateInstance(hClassName, &inspectable);
    if (FAILED(hr))
    {
        dbg_hr(FN, L"RoActivateInstance(Compositor)", hr);
        return hr;
    }
    /* RoActivateInstance returns the default interface (ICompositor) directly */
    g_compositor = (void*)inspectable;
    dbg_step(FN, L"Compositor created");

    /* QI for ICompositorDesktopInterop (to create DesktopWindowTarget) */
    hr = QI(g_compositor, &IID_ICompositorDesktopInterop, &g_desktopInterop);
    if (FAILED(hr))
    {
        dbg_hr(FN, L"QI(ICompositorDesktopInterop)", hr);
        return hr;
    }
    dbg_step(FN, L"ICompositorDesktopInterop obtained");

    /* Create DesktopWindowTarget for our HWND */
    hr = CompositorDesktopInterop_CreateDesktopWindowTarget(
        g_desktopInterop, g_hwnd, FALSE, &g_desktopTarget);
    if (FAILED(hr))
    {
        dbg_hr(FN, L"CreateDesktopWindowTarget", hr);
        return hr;
    }
    dbg_step(FN, L"DesktopWindowTarget created");

    /* QI DesktopWindowTarget for ICompositionTarget to set Root */
    hr = QI(g_desktopTarget, &IID_ICompositionTarget, &g_compositionTarget);
    if (FAILED(hr))
    {
        dbg_hr(FN, L"QI(ICompositionTarget)", hr);
        return hr;
    }

    /* Create root ContainerVisual */
    hr = Compositor_CreateContainerVisual(g_compositor, &g_rootVisual);
    if (FAILED(hr))
    {
        dbg_hr(FN, L"CreateContainerVisual", hr);
        return hr;
    }
    dbg_step(FN, L"ContainerVisual created");

    /* Set root visual on the composition target
     * put_Root expects an IVisual*, so QI the ContainerVisual */
    {
        void* rootAsVisual = NULL;
        hr = QI(g_rootVisual, &IID_IVisual, &rootAsVisual);
        if (FAILED(hr))
        {
            dbg_hr(FN, L"QI(rootVisual->IVisual)", hr);
            return hr;
        }
        hr = CompositionTarget_put_Root(g_compositionTarget, rootAsVisual);
        Rel(rootAsVisual);
        if (FAILED(hr))
        {
            dbg_hr(FN, L"put_Root", hr);
            return hr;
        }
    }
    dbg_step(FN, L"Root visual set");

    /* QI for ICompositorInterop to wrap swapchain as composition surface */
    hr = QI(g_compositor, &IID_ICompositorInterop, &g_compInterop);
    if (FAILED(hr))
    {
        dbg_hr(FN, L"QI(ICompositorInterop)", hr);
        return hr;
    }

    hr = CompositorInterop_CreateCompositionSurfaceForSwapChain(
        g_compInterop, (IUnknown*)g_swapChain, &g_compositionSurface);
    if (FAILED(hr))
    {
        dbg_hr(FN, L"CreateCompositionSurfaceForSwapChain", hr);
        return hr;
    }
    dbg_step(FN, L"CompositionSurface created for swapchain");

    /* Create SurfaceBrush from the composition surface */
    hr = Compositor_CreateSurfaceBrush(g_compositor, g_compositionSurface, &g_surfaceBrush);
    if (FAILED(hr))
    {
        dbg_hr(FN, L"CreateSurfaceBrush", hr);
        return hr;
    }
    dbg_step(FN, L"SurfaceBrush created");

    /* Create SpriteVisual to display the brush */
    hr = Compositor_CreateSpriteVisual(g_compositor, &g_spriteVisual);
    if (FAILED(hr))
    {
        dbg_hr(FN, L"CreateSpriteVisual", hr);
        return hr;
    }
    dbg_step(FN, L"SpriteVisual created");

    /* Set brush on sprite visual (QI surface brush for ICompositionBrush) */
    hr = QI(g_surfaceBrush, &IID_ICompositionBrush, &g_compositionBrush);
    if (FAILED(hr))
    {
        dbg_hr(FN, L"QI(ICompositionBrush)", hr);
        return hr;
    }
    hr = SpriteVisual_put_Brush(g_spriteVisual, g_compositionBrush);
    if (FAILED(hr))
    {
        dbg_hr(FN, L"SpriteVisual::put_Brush", hr);
        return hr;
    }
    dbg_step(FN, L"Brush set on SpriteVisual");

    /* Set size on sprite visual (QI for IVisual to access put_Size) */
    dbg_step(FN, L"about to QI sprite->IVisual");
    hr = QI(g_spriteVisual, &IID_IVisual, &g_visual);
    if (FAILED(hr))
    {
        dbg_hr(FN, L"QI(ISpriteVisual->IVisual)", hr);
        return hr;
    }
    dbg_step(FN, L"QI sprite->IVisual ok");

    /* Set size - inline the exact code that worked in the probe */
    dbg_step(FN, L"calling put_Size inline (slot36, by value)...");
    {
        typedef HRESULT (STDMETHODCALLTYPE *PFN_put_Size_val)(void*, Vector2);
        Vector2 sizeVal;
        sizeVal.X = (float)g_width;
        sizeVal.Y = (float)g_height;
        __try
        {
            hr = ((PFN_put_Size_val)SLOT(g_visual, 36))(g_visual, sizeVal);
        }
        __except(EXCEPTION_EXECUTE_HANDLER)
        {
            dbg_step(FN, L"put_Size CRASHED!");
            hr = E_FAIL;
        }
    }
    if (FAILED(hr))
    {
        dbg_hr(FN, L"put_Size", hr);
        /* Also try setting size on root container visual instead */
        dbg_step(FN, L"trying put_Size on rootVisual...");
        {
            void* rootAsVisual = NULL;
            hr = QI(g_rootVisual, &IID_IVisual, &rootAsVisual);
            if (SUCCEEDED(hr))
            {
                typedef HRESULT (STDMETHODCALLTYPE *PFN_put_Size_val)(void*, Vector2);
                Vector2 sv2;
                sv2.X = (float)g_width;
                sv2.Y = (float)g_height;
                __try
                {
                    hr = ((PFN_put_Size_val)SLOT(rootAsVisual, 36))(rootAsVisual, sv2);
                }
                __except(EXCEPTION_EXECUTE_HANDLER)
                {
                    hr = E_FAIL;
                }
                dbgprintf(L"[DBG ] put_Size on root: hr=0x%08X\n", (unsigned int)hr);
                Rel(rootAsVisual);
            }
        }
    }
    else
    {
        dbgprintf(L"[STEP] %s : Size set to %dx%d\n", FN, g_width, g_height);
    }

    /* Insert sprite into root's visual children collection */
    dbg_step(FN, L"about to get_Children");
    hr = ContainerVisual_get_Children(g_rootVisual, &g_visualCollection);
    if (FAILED(hr))
    {
        dbg_hr(FN, L"ContainerVisual::get_Children", hr);
        return hr;
    }
    dbg_step(FN, L"get_Children ok");

    sprite_asVisual = NULL;
    hr = QI(g_spriteVisual, &IID_IVisual, &sprite_asVisual);
    if (FAILED(hr))
    {
        dbg_hr(FN, L"QI(sprite->IVisual for InsertAtTop)", hr);
        return hr;
    }
    dbg_step(FN, L"about to InsertAtTop");
    hr = VisualCollection_InsertAtTop(g_visualCollection, sprite_asVisual);
    Rel(sprite_asVisual);
    if (FAILED(hr))
    {
        dbg_hr(FN, L"InsertAtTop", hr);
        return hr;
    }

    dbg_step(FN, L"SpriteVisual inserted - Composition init complete");
    return S_OK;
}

/* ============================================================
 * Render
 * ============================================================ */
static void Render(void)
{
    static BOOL firstCall = TRUE;
    HANDLE objs[1];

    if (firstCall)
    {
        dbg_step(L"Render", L"=== FIRST RENDER CALL ===");
        firstCall = FALSE;
    }

    if (!g_hdc || !g_hglrc || !g_glInteropDevice || !g_glInteropObject || !g_glFbo)
        return;

    if (!wglMakeCurrent(g_hdc, g_hglrc))
        return;

    objs[0] = g_glInteropObject;
    if (!p_wglDXLockObjectsNV(g_glInteropDevice, 1, objs))
        return;

    p_glBindFramebuffer(GL_FRAMEBUFFER, g_glFbo);
    glViewport(0, 0, (GLsizei)g_width, (GLsizei)g_height);
    glClearColor(1.0f, 1.0f, 1.0f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT);

    p_glUseProgram(g_glProgram);
    p_glBindBuffer(GL_ARRAY_BUFFER, g_glVbo[0]);
    p_glVertexAttribPointer((GLuint)g_glPosAttrib, 3, GL_FLOAT, GL_FALSE, 0, 0);
    p_glBindBuffer(GL_ARRAY_BUFFER, g_glVbo[1]);
    p_glVertexAttribPointer((GLuint)g_glColAttrib, 3, GL_FLOAT, GL_FALSE, 0, 0);
    glDrawArrays(GL_TRIANGLES, 0, 3);
    glFlush();
    p_glBindFramebuffer(GL_FRAMEBUFFER, 0);

    p_wglDXUnlockObjectsNV(g_glInteropDevice, 1, objs);

    /* Present swapchain (composition will pick it up) */
    {
        static BOOL firstPresent = TRUE;
        HRESULT hrP = g_swapChain->lpVtbl->Present(g_swapChain, 1, 0);
        if (firstPresent)
        {
            dbgprintf(L"[STEP] Render : first Present hr=0x%08X\n", (unsigned int)hrP);
            firstPresent = FALSE;
        }
    }
}

/* ============================================================
 * Cleanup
 * ============================================================ */
static void Cleanup(void)
{
    dbg_step(L"Cleanup", L"begin");

    /* Release Composition objects (reverse order of creation) */
    Rel(g_visualCollection);     g_visualCollection = NULL;
    Rel(g_visual);               g_visual = NULL;
    Rel(g_compositionBrush);     g_compositionBrush = NULL;
    Rel(g_spriteVisual);         g_spriteVisual = NULL;
    Rel(g_surfaceBrush);         g_surfaceBrush = NULL;
    Rel(g_compositionSurface);   g_compositionSurface = NULL;
    Rel(g_rootVisual);           g_rootVisual = NULL;
    Rel(g_compositionTarget);    g_compositionTarget = NULL;
    Rel(g_desktopTarget);        g_desktopTarget = NULL;
    Rel(g_compInterop);          g_compInterop = NULL;
    Rel(g_desktopInterop);       g_desktopInterop = NULL;
    Rel(g_compositor);           g_compositor = NULL;

    /* OpenGL / WGL / NV interop cleanup (before D3D device release) */
    if (g_glInteropObject && g_glInteropDevice && p_wglDXUnregisterObjectNV)
    {
        p_wglDXUnregisterObjectNV(g_glInteropDevice, g_glInteropObject);
        g_glInteropObject = NULL;
    }
    if (g_glInteropDevice && p_wglDXCloseDeviceNV)
    {
        p_wglDXCloseDeviceNV(g_glInteropDevice);
        g_glInteropDevice = NULL;
    }

    if (g_hdc && g_hglrc) wglMakeCurrent(g_hdc, g_hglrc);
    if (g_glProgram && p_glDeleteProgram) { p_glDeleteProgram(g_glProgram); g_glProgram = 0; }
    if (g_glVbo[0] && p_glDeleteBuffers) { p_glDeleteBuffers(2, g_glVbo); g_glVbo[0] = g_glVbo[1] = 0; }
    if (g_glVao && p_glDeleteVertexArrays) { p_glDeleteVertexArrays(1, &g_glVao); g_glVao = 0; }
    if (g_glFbo && p_glDeleteFramebuffers) { p_glDeleteFramebuffers(1, &g_glFbo); g_glFbo = 0; }
    if (g_glRbo && p_glDeleteRenderbuffers) { p_glDeleteRenderbuffers(1, &g_glRbo); g_glRbo = 0; }
    DisableOpenGL();

    /* Release D3D11 objects */
    if (g_vb)          { g_vb->lpVtbl->Release(g_vb);                   g_vb = NULL; }
    if (g_inputLayout) { g_inputLayout->lpVtbl->Release(g_inputLayout); g_inputLayout = NULL; }
    if (g_ps)          { g_ps->lpVtbl->Release(g_ps);                   g_ps = NULL; }
    if (g_vs)          { g_vs->lpVtbl->Release(g_vs);                   g_vs = NULL; }
    if (g_rtv)         { g_rtv->lpVtbl->Release(g_rtv);                 g_rtv = NULL; }
    if (g_backBuffer)  { g_backBuffer->lpVtbl->Release(g_backBuffer);   g_backBuffer = NULL; }
    if (g_swapChain)   { g_swapChain->lpVtbl->Release(g_swapChain);     g_swapChain = NULL; }
    if (g_d3dCtx)      { g_d3dCtx->lpVtbl->Release(g_d3dCtx);          g_d3dCtx = NULL; }
    if (g_d3dDevice)   { g_d3dDevice->lpVtbl->Release(g_d3dDevice);     g_d3dDevice = NULL; }

    /* DispatcherQueue controller */
    if (g_dqController)
    {
        g_dqController->lpVtbl->Release(g_dqController);
        g_dqController = NULL;
    }

    /* Uninitialize WinRT */
    RoUninitialize();

    /* COM uninit */
    if (g_comInitialized)
    {
        CoUninitialize();
        g_comInitialized = FALSE;
    }

    dbg_step(L"Cleanup", L"ok");
}

/* ============================================================
 * Entry point
 * ============================================================ */
int WINAPI wWinMain(HINSTANCE hInst, HINSTANCE hPrev, PWSTR pCmdLine, int nCmdShow)
{
    MSG msg;
    HRESULT hr;

    UNREFERENCED_PARAMETER(hPrev);
    UNREFERENCED_PARAMETER(pCmdLine);
    UNREFERENCED_PARAMETER(nCmdShow);

    dbg_step(L"wWinMain", L"start");

    hr = CreateAppWindow(hInst);
    if (FAILED(hr))
    {
        dbgprintf(L"[FATAL] CreateAppWindow failed hr=0x%08X\n", (uint32_t)hr);
        Cleanup();
        return (int)hr;
    }

    dbg_step(L"wWinMain", L"InitD3D11...");
    hr = InitD3D11AndSwapChainForComposition();
    if (FAILED(hr))
    {
        dbgprintf(L"[FATAL] InitD3D11 failed hr=0x%08X\n", (uint32_t)hr);
        Cleanup();
        return (int)hr;
    }

    dbg_step(L"wWinMain", L"InitComposition...");
    hr = InitCompositionForHwnd();
    if (FAILED(hr))
    {
        dbgprintf(L"[FATAL] InitComposition failed hr=0x%08X\n", (uint32_t)hr);
        Cleanup();
        return (int)hr;
    }

    dbg_step(L"wWinMain", L"InitOpenGL...");
    hr = InitOpenGLForComposition();
    if (FAILED(hr))
    {
        dbgprintf(L"[FATAL] InitOpenGL failed hr=0x%08X\n", (uint32_t)hr);
        Cleanup();
        return (int)hr;
    }

    dbg_step(L"wWinMain", L"=== ENTERING MESSAGE LOOP ===");
    ZeroMemory(&msg, sizeof(msg));
    while (msg.message != WM_QUIT)
    {
        if (PeekMessageW(&msg, NULL, 0, 0, PM_REMOVE))
        {
            TranslateMessage(&msg);
            DispatchMessageW(&msg);
        }
        else
        {
            Render();
        }
    }

    dbg_step(L"wWinMain", L"loop end");
    Cleanup();
    return 0;
}
