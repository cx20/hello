"""
OpenGL 4.6 + DirectX11 + Vulkan 1.4 Triangles via Windows.UI.Composition
(ctypes only, no external Python packages)

This sample demonstrates how to render and composite three triangles
(OpenGL 4.6, DirectX11, Vulkan 1.4) through Windows.UI.Composition on a
classic desktop window, using only Python's ctypes without external packages.

Architecture:
  1. Create a Win32 window with WS_EX_NOREDIRECTIONBITMAP
  2. Create a D3D11 device and DXGI swap chain for Composition
  3. Initialize WinRT Compositor and DesktopWindowTarget
  4. Wrap the swap chain as a CompositionSurface -> SurfaceBrush -> SpriteVisual
  5. Render OpenGL 4.6 into the left panel via WGL_NV_DX_interop
  6. Render DirectX11 triangle into the middle panel
  7. Render Vulkan 1.4 offscreen and copy into the right panel
  8. Present via the swap chain; Composition displays the composited result

Requirements:
  - Windows 10 1803+ (for DesktopWindowTarget)
  - NVIDIA GPU with WGL_NV_DX_interop2 support (or compatible AMD/Intel driver)
  - Python 3.8+ (64-bit recommended)
"""

import ctypes
import ctypes.wintypes as wintypes
import struct
import sys
import importlib.util
from pathlib import Path

# ============================================================
# DLLs
# ============================================================
kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
user32   = ctypes.WinDLL("user32",   use_last_error=True)
gdi32    = ctypes.WinDLL("gdi32",    use_last_error=True)
ole32    = ctypes.WinDLL("ole32",    use_last_error=True)
combase  = ctypes.WinDLL("combase",  use_last_error=True)

opengl32 = ctypes.WinDLL("opengl32", use_last_error=True)
d3d11    = ctypes.WinDLL("d3d11",    use_last_error=True)
dxgi_dll = ctypes.WinDLL("dxgi",     use_last_error=True)

try:
    d3dcompiler = ctypes.WinDLL("d3dcompiler_47", use_last_error=True)
except OSError:
    d3dcompiler = ctypes.WinDLL("d3dcompiler_43", use_last_error=True)

try:
    core_messaging = ctypes.WinDLL("CoreMessaging", use_last_error=True)
except OSError:
    core_messaging = None

# Add HRESULT type if not defined
if not hasattr(wintypes, "HRESULT"):
    wintypes.HRESULT = ctypes.c_long

# ============================================================
# Debug output
# ============================================================
kernel32.OutputDebugStringW.restype  = None
kernel32.OutputDebugStringW.argtypes = (wintypes.LPCWSTR,)

def debug_print(msg: str):
    """Output debug message to DebugView and console"""
    kernel32.OutputDebugStringW(f"[PyGL] {msg}\n")
    print(f"[PyGL] {msg}")

def check_hr(hr, api_name: str):
    """Check HRESULT and raise on failure"""
    if hr < 0:
        raise RuntimeError(f"{api_name} failed: 0x{hr & 0xFFFFFFFF:08X}")

# ============================================================
# Constants
# ============================================================
S_OK    = 0
S_FALSE = 1
E_FAIL  = 0x80004005
RPC_E_CHANGED_MODE = 0x80010106

# COM initialization
COINIT_APARTMENTTHREADED = 0x2
RO_INIT_SINGLETHREADED  = 0

# Window styles
WS_OVERLAPPEDWINDOW     = 0x00CF0000
WS_EX_NOREDIRECTIONBITMAP = 0x00200000
WS_VISIBLE              = 0x10000000
CW_USEDEFAULT           = 0x80000000

# Window messages
WM_DESTROY = 0x0002
WM_PAINT   = 0x000F
WM_QUIT    = 0x0012

# Peek message
PM_REMOVE = 0x0001

# Cursor
IDC_ARROW = 32512

# D3D11 constants
D3D_DRIVER_TYPE_HARDWARE       = 1
D3D11_SDK_VERSION              = 7
D3D11_CREATE_DEVICE_BGRA_SUPPORT = 0x20
D3D_FEATURE_LEVEL_11_0         = 0xB000
D3D11_BIND_VERTEX_BUFFER       = 0x1
D3D11_USAGE_DEFAULT            = 0
D3D11_BIND_RENDER_TARGET       = 0x20
D3D11_USAGE_STAGING            = 3
D3D11_CPU_ACCESS_WRITE         = 0x00010000
D3D11_MAP_WRITE                = 2
D3D11_INPUT_PER_VERTEX_DATA    = 0
D3D11_PRIMITIVE_TOPOLOGY_TRIANGLELIST = 4

# DXGI constants
DXGI_FORMAT_B8G8R8A8_UNORM     = 87
DXGI_FORMAT_R32G32B32_FLOAT    = 6
DXGI_FORMAT_R32G32B32A32_FLOAT = 2
DXGI_USAGE_RENDER_TARGET_OUTPUT = 0x00000020
DXGI_SWAP_EFFECT_FLIP_SEQUENTIAL = 3
DXGI_SCALING_STRETCH           = 0
DXGI_ALPHA_MODE_PREMULTIPLIED  = 1

# D3DCompile flags
D3DCOMPILE_ENABLE_STRICTNESS = 0x00000800

# OpenGL constants
GL_FLOAT             = 0x1406
GL_FALSE             = 0
GL_TRUE              = 1
GL_TRIANGLES         = 0x0004
GL_COLOR_BUFFER_BIT  = 0x00004000
GL_ARRAY_BUFFER      = 0x8892
GL_STATIC_DRAW       = 0x88E4
GL_FRAGMENT_SHADER   = 0x8B30
GL_VERTEX_SHADER     = 0x8B31
GL_FRAMEBUFFER       = 0x8D40
GL_RENDERBUFFER      = 0x8D41
GL_COLOR_ATTACHMENT0 = 0x8CE0
GL_FRAMEBUFFER_COMPLETE = 0x8CD5
GL_COMPILE_STATUS    = 0x8B81
GL_LINK_STATUS       = 0x8B82
GL_SCISSOR_TEST      = 0x0C11

# WGL constants
WGL_CONTEXT_MAJOR_VERSION_ARB    = 0x2091
WGL_CONTEXT_MINOR_VERSION_ARB    = 0x2092
WGL_CONTEXT_FLAGS_ARB            = 0x2094
WGL_CONTEXT_PROFILE_MASK_ARB     = 0x9126
WGL_CONTEXT_CORE_PROFILE_BIT_ARB = 0x00000001
WGL_ACCESS_READ_WRITE_NV         = 0x0001

# PFD flags
PFD_DRAW_TO_WINDOW = 0x00000004
PFD_SUPPORT_OPENGL = 0x00000020
PFD_DOUBLEBUFFER   = 0x00000001
PFD_TYPE_RGBA      = 0
PFD_MAIN_PLANE     = 0

# DispatcherQueue thread types
DQTYPE_THREAD_CURRENT = 2
DQTAT_COM_STA         = 2

# Window dimensions
WIDTH  = 960
HEIGHT = 480

# ============================================================
# GUID structure
# ============================================================
class GUID(ctypes.Structure):
    _fields_ = [
        ("Data1", wintypes.DWORD),
        ("Data2", wintypes.WORD),
        ("Data3", wintypes.WORD),
        ("Data4", ctypes.c_ubyte * 8),
    ]

def make_guid(d1, d2, d3, *d4) -> GUID:
    """Create GUID from components"""
    g = GUID()
    g.Data1 = d1
    g.Data2 = d2
    g.Data3 = d3
    for i, b in enumerate(d4):
        g.Data4[i] = b
    return g

# ============================================================
# Interface GUIDs
# ============================================================
# D3D11/DXGI GUIDs
IID_IDXGIDevice   = make_guid(0x54ec77fa, 0x1377, 0x44e6, 0x8c, 0x32, 0x88, 0xfd, 0x5f, 0x44, 0xc8, 0x4c)
IID_IDXGIAdapter  = make_guid(0x2411e7e1, 0x12ac, 0x4ccf, 0xbd, 0x14, 0x97, 0x98, 0xe8, 0x53, 0x4d, 0xc0)
IID_IDXGIFactory2 = make_guid(0x50c83a1c, 0xe072, 0x4c48, 0x87, 0xb0, 0x36, 0x30, 0xfa, 0x36, 0xa6, 0xd0)
IID_ID3D11Texture2D = make_guid(0x6f15aaf2, 0xd208, 0x4e89, 0x9a, 0xb4, 0x48, 0x95, 0x35, 0xd3, 0x4f, 0x9c)

# WinRT Composition GUIDs
IID_ICompositor = make_guid(
    0xB403CA50, 0x7F8C, 0x4E83, 0x98, 0x5F, 0xA4, 0x14, 0xD2, 0x6F, 0x1D, 0xAD)
IID_ICompositorDesktopInterop = make_guid(
    0x29E691FA, 0x4567, 0x4DCA, 0xB3, 0x19, 0xD0, 0xF2, 0x07, 0xEB, 0x68, 0x07)
IID_ICompositorInterop = make_guid(
    0x25297D5C, 0x3AD4, 0x4C9C, 0xB5, 0xCF, 0xE3, 0x6A, 0x38, 0x51, 0x23, 0x30)
IID_ICompositionTarget = make_guid(
    0xA1BEA8BA, 0xD726, 0x4663, 0x81, 0x29, 0x6B, 0x5E, 0x79, 0x27, 0xFF, 0xA6)
IID_IContainerVisual = make_guid(
    0x02F6BC74, 0xED20, 0x4773, 0xAF, 0xE6, 0xD4, 0x9B, 0x4A, 0x93, 0xDB, 0x32)
IID_IVisual = make_guid(
    0x117E202D, 0xA859, 0x4C89, 0x87, 0x3B, 0xC2, 0xAA, 0x56, 0x67, 0x88, 0xE3)
IID_ISpriteVisual = make_guid(
    0x08E05581, 0x1AD1, 0x4F97, 0x97, 0x57, 0x40, 0x2D, 0x76, 0xE4, 0x23, 0x3B)
IID_ICompositionBrush = make_guid(
    0xAB0D7608, 0x30C0, 0x40E9, 0xB5, 0x68, 0xB6, 0x0A, 0x6B, 0xD1, 0xFB, 0x46)
IID_ICompositionSurface = make_guid(
    0x1527540D, 0x42C7, 0x47A6, 0xA4, 0x08, 0x66, 0x8F, 0x79, 0xA9, 0x0D, 0xFB)

# ============================================================
# HSTRING types (for WinRT string interop)
# ============================================================
HSTRING = ctypes.c_void_p

class HSTRING_HEADER(ctypes.Structure):
    _fields_ = [("Reserved", ctypes.c_void_p * 5)]

# ============================================================
# Structures
# ============================================================
class PIXELFORMATDESCRIPTOR(ctypes.Structure):
    _fields_ = [
        ("nSize",           wintypes.WORD),
        ("nVersion",        wintypes.WORD),
        ("dwFlags",         wintypes.DWORD),
        ("iPixelType",      ctypes.c_ubyte),
        ("cColorBits",      ctypes.c_ubyte),
        ("cRedBits",        ctypes.c_ubyte),
        ("cRedShift",       ctypes.c_ubyte),
        ("cGreenBits",      ctypes.c_ubyte),
        ("cGreenShift",     ctypes.c_ubyte),
        ("cBlueBits",       ctypes.c_ubyte),
        ("cBlueShift",      ctypes.c_ubyte),
        ("cAlphaBits",      ctypes.c_ubyte),
        ("cAlphaShift",     ctypes.c_ubyte),
        ("cAccumBits",      ctypes.c_ubyte),
        ("cAccumRedBits",   ctypes.c_ubyte),
        ("cAccumGreenBits", ctypes.c_ubyte),
        ("cAccumBlueBits",  ctypes.c_ubyte),
        ("cAccumAlphaBits", ctypes.c_ubyte),
        ("cDepthBits",      ctypes.c_ubyte),
        ("cStencilBits",    ctypes.c_ubyte),
        ("cAuxBuffers",     ctypes.c_ubyte),
        ("iLayerType",      ctypes.c_ubyte),
        ("bReserved",       ctypes.c_ubyte),
        ("dwLayerMask",     wintypes.DWORD),
        ("dwVisibleMask",   wintypes.DWORD),
        ("dwDamageMask",    wintypes.DWORD),
    ]

class WNDCLASSEXW(ctypes.Structure):
    _fields_ = [
        ("cbSize",        wintypes.UINT),
        ("style",         wintypes.UINT),
        ("lpfnWndProc",   ctypes.c_void_p),
        ("cbClsExtra",    ctypes.c_int),
        ("cbWndExtra",    ctypes.c_int),
        ("hInstance",     wintypes.HINSTANCE),
        ("hIcon",         wintypes.HICON),
        ("hCursor",       wintypes.HANDLE),
        ("hbrBackground", wintypes.HANDLE),
        ("lpszMenuName",  wintypes.LPCWSTR),
        ("lpszClassName", wintypes.LPCWSTR),
        ("hIconSm",       wintypes.HICON),
    ]

class DXGI_SAMPLE_DESC(ctypes.Structure):
    _fields_ = [
        ("Count",   wintypes.UINT),
        ("Quality", wintypes.UINT),
    ]

class DXGI_SWAP_CHAIN_DESC1(ctypes.Structure):
    _fields_ = [
        ("Width",       wintypes.UINT),
        ("Height",      wintypes.UINT),
        ("Format",      wintypes.UINT),
        ("Stereo",      wintypes.BOOL),
        ("SampleDesc",  DXGI_SAMPLE_DESC),
        ("BufferUsage", wintypes.UINT),
        ("BufferCount", wintypes.UINT),
        ("Scaling",     wintypes.UINT),
        ("SwapEffect",  wintypes.UINT),
        ("AlphaMode",   wintypes.UINT),
        ("Flags",       wintypes.UINT),
    ]

class D3D11_BUFFER_DESC(ctypes.Structure):
    _fields_ = [
        ("ByteWidth",      wintypes.UINT),
        ("Usage",           wintypes.UINT),
        ("BindFlags",       wintypes.UINT),
        ("CPUAccessFlags",  wintypes.UINT),
        ("MiscFlags",       wintypes.UINT),
        ("StructureByteStride", wintypes.UINT),
    ]

class D3D11_SUBRESOURCE_DATA(ctypes.Structure):
    _fields_ = [
        ("pSysMem",          ctypes.c_void_p),
        ("SysMemPitch",      wintypes.UINT),
        ("SysMemSlicePitch", wintypes.UINT),
    ]

class D3D11_VIEWPORT(ctypes.Structure):
    _fields_ = [
        ("TopLeftX", ctypes.c_float),
        ("TopLeftY", ctypes.c_float),
        ("Width", ctypes.c_float),
        ("Height", ctypes.c_float),
        ("MinDepth", ctypes.c_float),
        ("MaxDepth", ctypes.c_float),
    ]

class D3D11_INPUT_ELEMENT_DESC(ctypes.Structure):
    _fields_ = [
        ("SemanticName", ctypes.c_char_p),
        ("SemanticIndex", wintypes.UINT),
        ("Format", wintypes.UINT),
        ("InputSlot", wintypes.UINT),
        ("AlignedByteOffset", wintypes.UINT),
        ("InputSlotClass", wintypes.UINT),
        ("InstanceDataStepRate", wintypes.UINT),
    ]

class D3D11_TEXTURE2D_DESC(ctypes.Structure):
    _fields_ = [
        ("Width", wintypes.UINT),
        ("Height", wintypes.UINT),
        ("MipLevels", wintypes.UINT),
        ("ArraySize", wintypes.UINT),
        ("Format", wintypes.UINT),
        ("SampleDesc", DXGI_SAMPLE_DESC),
        ("Usage", wintypes.UINT),
        ("BindFlags", wintypes.UINT),
        ("CPUAccessFlags", wintypes.UINT),
        ("MiscFlags", wintypes.UINT),
    ]

class D3D11_MAPPED_SUBRESOURCE(ctypes.Structure):
    _fields_ = [
        ("pData", ctypes.c_void_p),
        ("RowPitch", wintypes.UINT),
        ("DepthPitch", wintypes.UINT),
    ]

class D3D11_BOX(ctypes.Structure):
    _fields_ = [
        ("left", wintypes.UINT),
        ("top", wintypes.UINT),
        ("front", wintypes.UINT),
        ("right", wintypes.UINT),
        ("bottom", wintypes.UINT),
        ("back", wintypes.UINT),
    ]

class DispatcherQueueOptions(ctypes.Structure):
    _fields_ = [
        ("dwSize",        wintypes.DWORD),
        ("threadType",    ctypes.c_int),
        ("apartmentType", ctypes.c_int),
    ]

class PAINTSTRUCT(ctypes.Structure):
    _fields_ = [
        ("hdc",         wintypes.HDC),
        ("fErase",      wintypes.BOOL),
        ("rcPaint",     wintypes.RECT),
        ("fRestore",    wintypes.BOOL),
        ("fIncUpdate",  wintypes.BOOL),
        ("rgbReserved", ctypes.c_ubyte * 32),
    ]

# ============================================================
# COM VTable helper (same pattern as hello.py toast sample)
# ============================================================
def vtbl_slot(obj_ptr, index):
    """Read a vtable slot address from a COM object pointer"""
    if isinstance(obj_ptr, ctypes.c_void_p):
        ptr = obj_ptr.value
    else:
        ptr = obj_ptr
    if not ptr:
        raise RuntimeError(f"vtbl_slot: NULL pointer at index {index}")
    # Dereference: obj -> vtable -> slot[index]
    vtbl = ctypes.cast(ptr, ctypes.POINTER(ctypes.POINTER(ctypes.c_void_p))).contents
    return vtbl[index]

def com_call(obj_ptr, index, restype, argtypes):
    """
    Create a callable for a COM method by vtable index.
    The first argument (pThis) must be passed by the caller.
    """
    addr = vtbl_slot(obj_ptr, index)
    FN = ctypes.WINFUNCTYPE(restype, *argtypes)
    return FN(addr)

def com_release(obj_ptr):
    """Call IUnknown::Release (slot 2)"""
    if obj_ptr:
        ptr = obj_ptr.value if isinstance(obj_ptr, ctypes.c_void_p) else obj_ptr
        if ptr:
            try:
                com_call(ptr, 2, wintypes.ULONG, (ctypes.c_void_p,))(ptr)
            except Exception:
                pass

def com_qi(obj_ptr, iid):
    """Call IUnknown::QueryInterface (slot 0), return new interface pointer"""
    ptr = obj_ptr.value if isinstance(obj_ptr, ctypes.c_void_p) else obj_ptr
    result = ctypes.c_void_p()
    fn = com_call(ptr, 0, wintypes.HRESULT,
                  (ctypes.c_void_p, ctypes.POINTER(GUID), ctypes.POINTER(ctypes.c_void_p)))
    hr = fn(ptr, ctypes.byref(iid), ctypes.byref(result))
    check_hr(hr, "QueryInterface")
    return result

# ============================================================
# WinRT API function prototypes
# ============================================================
RoInitialize = combase.RoInitialize
RoInitialize.restype  = wintypes.HRESULT
RoInitialize.argtypes = (wintypes.UINT,)

RoUninitialize = combase.RoUninitialize
RoUninitialize.restype  = None
RoUninitialize.argtypes = ()

RoActivateInstance = combase.RoActivateInstance
RoActivateInstance.restype  = wintypes.HRESULT
RoActivateInstance.argtypes = (HSTRING, ctypes.POINTER(ctypes.c_void_p))

WindowsCreateStringReference = combase.WindowsCreateStringReference
WindowsCreateStringReference.restype  = wintypes.HRESULT
WindowsCreateStringReference.argtypes = (
    wintypes.LPCWSTR, wintypes.UINT,
    ctypes.POINTER(HSTRING_HEADER), ctypes.POINTER(HSTRING),
)

# ============================================================
# Win32 API function prototypes
# ============================================================
WNDPROC = ctypes.WINFUNCTYPE(ctypes.c_long, wintypes.HWND, wintypes.UINT,
                              wintypes.WPARAM, wintypes.LPARAM)

user32.RegisterClassExW.restype  = wintypes.ATOM
user32.RegisterClassExW.argtypes = (ctypes.POINTER(WNDCLASSEXW),)

user32.CreateWindowExW.restype  = wintypes.HWND
user32.CreateWindowExW.argtypes = (
    wintypes.DWORD, wintypes.LPCWSTR, wintypes.LPCWSTR, wintypes.DWORD,
    ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_int,
    wintypes.HWND, wintypes.HMENU, wintypes.HINSTANCE, wintypes.LPVOID,
)

user32.ShowWindow.restype  = wintypes.BOOL
user32.ShowWindow.argtypes = (wintypes.HWND, ctypes.c_int)

user32.UpdateWindow.restype  = wintypes.BOOL
user32.UpdateWindow.argtypes = (wintypes.HWND,)

user32.DefWindowProcW.restype  = ctypes.c_long
user32.DefWindowProcW.argtypes = (wintypes.HWND, wintypes.UINT, wintypes.WPARAM, wintypes.LPARAM)

user32.PostQuitMessage.restype  = None
user32.PostQuitMessage.argtypes = (ctypes.c_int,)

user32.PeekMessageW.restype  = wintypes.BOOL
user32.PeekMessageW.argtypes = (
    ctypes.POINTER(wintypes.MSG), wintypes.HWND,
    wintypes.UINT, wintypes.UINT, wintypes.UINT,
)

user32.TranslateMessage.restype  = wintypes.BOOL
user32.TranslateMessage.argtypes = (ctypes.POINTER(wintypes.MSG),)

user32.DispatchMessageW.restype  = ctypes.c_long
user32.DispatchMessageW.argtypes = (ctypes.POINTER(wintypes.MSG),)

user32.LoadCursorW.restype  = wintypes.HANDLE
user32.LoadCursorW.argtypes = (wintypes.HINSTANCE, wintypes.LPCWSTR)

user32.AdjustWindowRect.restype  = wintypes.BOOL
user32.AdjustWindowRect.argtypes = (ctypes.POINTER(wintypes.RECT), wintypes.DWORD, wintypes.BOOL)

user32.BeginPaint.restype  = wintypes.HDC
user32.BeginPaint.argtypes = (wintypes.HWND, ctypes.POINTER(PAINTSTRUCT))

user32.EndPaint.restype  = wintypes.BOOL
user32.EndPaint.argtypes = (wintypes.HWND, ctypes.POINTER(PAINTSTRUCT))



kernel32.GetModuleHandleW.restype  = wintypes.HMODULE
kernel32.GetModuleHandleW.argtypes = (wintypes.LPCWSTR,)

user32.GetDC.restype  = wintypes.HDC
user32.GetDC.argtypes = (wintypes.HWND,)

user32.ReleaseDC.restype  = ctypes.c_int
user32.ReleaseDC.argtypes = (wintypes.HWND, wintypes.HDC)

gdi32.ChoosePixelFormat.restype  = ctypes.c_int
gdi32.ChoosePixelFormat.argtypes = (wintypes.HDC, ctypes.POINTER(PIXELFORMATDESCRIPTOR))

gdi32.SetPixelFormat.restype  = wintypes.BOOL
gdi32.SetPixelFormat.argtypes = (wintypes.HDC, ctypes.c_int, ctypes.POINTER(PIXELFORMATDESCRIPTOR))

# ============================================================
# OpenGL / WGL function prototypes
# ============================================================
opengl32.wglCreateContext.restype  = wintypes.HANDLE
opengl32.wglCreateContext.argtypes = (wintypes.HDC,)

opengl32.wglMakeCurrent.restype  = wintypes.BOOL
opengl32.wglMakeCurrent.argtypes = (wintypes.HDC, wintypes.HANDLE)

opengl32.wglDeleteContext.restype  = wintypes.BOOL
opengl32.wglDeleteContext.argtypes = (wintypes.HANDLE,)

opengl32.wglGetProcAddress.restype  = ctypes.c_void_p
opengl32.wglGetProcAddress.argtypes = (ctypes.c_char_p,)

opengl32.glViewport.restype  = None
opengl32.glViewport.argtypes = (ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_int)
opengl32.glEnable.restype    = None
opengl32.glEnable.argtypes   = (ctypes.c_uint,)
opengl32.glDisable.restype   = None
opengl32.glDisable.argtypes  = (ctypes.c_uint,)
opengl32.glScissor.restype   = None
opengl32.glScissor.argtypes  = (ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_int)

opengl32.glClearColor.restype  = None
opengl32.glClearColor.argtypes = (ctypes.c_float, ctypes.c_float, ctypes.c_float, ctypes.c_float)

opengl32.glClear.restype  = None
opengl32.glClear.argtypes = (ctypes.c_uint,)

opengl32.glDrawArrays.restype  = None
opengl32.glDrawArrays.argtypes = (ctypes.c_uint, ctypes.c_int, ctypes.c_int)

opengl32.glFlush.restype  = None
opengl32.glFlush.argtypes = ()

opengl32.glGetString.restype  = ctypes.c_char_p
opengl32.glGetString.argtypes = (ctypes.c_uint,)

# ============================================================
# GL extension function type signatures
# ============================================================
GLuint    = ctypes.c_uint
GLint     = ctypes.c_int
GLsizei   = ctypes.c_int
GLenum    = ctypes.c_uint
GLboolean = ctypes.c_ubyte
GLchar    = ctypes.c_char
GLsizeiptr = ctypes.c_ssize_t

def get_gl_proc(name: str):
    """Load an OpenGL extension function by name"""
    addr = opengl32.wglGetProcAddress(name.encode())
    if not addr or addr in (0, 1, 2, 3, -1, 0xFFFFFFFF, 0xFFFFFFFFFFFFFFFF):
        # Try from opengl32.dll directly
        try:
            return getattr(opengl32, name)
        except AttributeError:
            return None
    return addr

def load_gl_func(name: str, restype, argtypes):
    """Load and wrap an OpenGL extension function"""
    addr = get_gl_proc(name)
    if not addr:
        raise RuntimeError(f"Missing GL function: {name}")
    if isinstance(addr, int):
        FN = ctypes.CFUNCTYPE(restype, *argtypes)
        return FN(addr)
    return addr  # Already a ctypes function

# ============================================================
# OpenGL shader sources (GLSL 4.60)
# ============================================================
VERTEX_SHADER_SRC = b"""#version 460 core
layout(location=0) in vec3 position;
layout(location=1) in vec3 color;
out vec4 vColor;
void main(){
    vColor = vec4(color, 1.0);
    gl_Position = vec4(position.x, -position.y, position.z, 1.0);
}
"""

FRAGMENT_SHADER_SRC = b"""#version 460 core
in vec4 vColor;
out vec4 outColor;
void main(){
    outColor = vColor;
}
"""

# D3D11 shader source for the middle panel
D3D11_HLSL_SRC = r"""
struct VS_OUTPUT
{
    float4 position : SV_POSITION;
    float4 color : COLOR0;
};

VS_OUTPUT VS(float4 position : POSITION, float4 color : COLOR)
{
    VS_OUTPUT o = (VS_OUTPUT)0;
    o.position = position;
    o.color = color;
    return o;
}

float4 PS(VS_OUTPUT input) : SV_Target
{
    return input.color;
}
"""

def _load_module_from_path(name: str, path: Path):
    spec = importlib.util.spec_from_file_location(name, path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Failed to load module: {path}")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod

def _compile_hlsl_blob(entry: str, target: str) -> ctypes.c_void_p:
    d3dcompiler.D3DCompile.restype = wintypes.HRESULT
    d3dcompiler.D3DCompile.argtypes = (
        ctypes.c_void_p, ctypes.c_size_t, ctypes.c_char_p,
        ctypes.c_void_p, ctypes.c_void_p,
        ctypes.c_char_p, ctypes.c_char_p,
        wintypes.UINT, wintypes.UINT,
        ctypes.POINTER(ctypes.c_void_p), ctypes.POINTER(ctypes.c_void_p),
    )
    src = D3D11_HLSL_SRC.encode("utf-8")
    code = ctypes.c_void_p()
    err = ctypes.c_void_p()
    hr = d3dcompiler.D3DCompile(
        ctypes.c_char_p(src), len(src), b"embedded.hlsl",
        None, None, entry.encode("ascii"), target.encode("ascii"),
        D3DCOMPILE_ENABLE_STRICTNESS, 0, ctypes.byref(code), ctypes.byref(err))
    if hr < 0:
        msg = f"D3DCompile({entry}) failed"
        if err:
            try:
                p = com_call(err, 3, ctypes.c_void_p, (ctypes.c_void_p,))(err)
                n = com_call(err, 4, ctypes.c_size_t, (ctypes.c_void_p,))(err)
                if p and n:
                    msg = ctypes.string_at(p, n).decode("utf-8", "replace")
            except Exception:
                pass
            com_release(err)
        raise RuntimeError(msg)
    if err:
        com_release(err)
    return code

def _blob_ptr(blob):
    return com_call(blob, 3, ctypes.c_void_p, (ctypes.c_void_p,))(blob)

def _blob_size(blob):
    return com_call(blob, 4, ctypes.c_size_t, (ctypes.c_void_p,))(blob)

# ============================================================
# Global state
# ============================================================
g_hwnd = None
g_hdc  = None
g_hglrc = None
g_com_initialized = False
g_dq_controller = ctypes.c_void_p()

# D3D11 / DXGI objects
g_d3d_device   = ctypes.c_void_p()
g_d3d_ctx      = ctypes.c_void_p()
g_swap_chain   = ctypes.c_void_p()
g_back_buffer  = ctypes.c_void_p()
g_rtv          = ctypes.c_void_p()
g_d3d_vs       = ctypes.c_void_p()
g_d3d_ps       = ctypes.c_void_p()
g_d3d_layout   = ctypes.c_void_p()
g_d3d_vb       = ctypes.c_void_p()
g_vk_stage_tex = ctypes.c_void_p()
g_vk_helper    = None
g_vk_state     = None

# OpenGL objects
g_gl_vao     = GLuint(0)
g_gl_vbo     = (GLuint * 2)(0, 0)
g_gl_program = GLuint(0)
g_gl_rbo     = GLuint(0)
g_gl_fbo     = GLuint(0)
g_gl_pos_attrib = GLint(-1)
g_gl_col_attrib = GLint(-1)

# WGL_NV_DX_interop handles
g_gl_interop_device = ctypes.c_void_p()
g_gl_interop_object = ctypes.c_void_p()

# Composition objects (opaque pointers)
g_compositor          = ctypes.c_void_p()
g_desktop_interop     = ctypes.c_void_p()
g_comp_interop        = ctypes.c_void_p()
g_desktop_target      = ctypes.c_void_p()
g_composition_target  = ctypes.c_void_p()
g_root_visual         = ctypes.c_void_p()
g_sprite_visual       = ctypes.c_void_p()
g_composition_surface = ctypes.c_void_p()
g_surface_brush       = ctypes.c_void_p()
g_composition_brush   = ctypes.c_void_p()
g_visual              = ctypes.c_void_p()
g_visual_collection   = ctypes.c_void_p()

# GL extension function pointers (populated after context creation)
gl = {}  # dict of loaded GL functions

# WGL NV interop function pointers
wgl = {}  # dict of loaded WGL functions

# Keep references alive for HSTRING buffers
_hstring_refs = []

# ============================================================
# WinRT HSTRING helper
# ============================================================
def create_hstring(s: str):
    """Create an HSTRING reference from a Python string.
    Returns (buffer, header, hstring). All must stay alive."""
    buf = ctypes.create_unicode_buffer(s)
    hdr = HSTRING_HEADER()
    hs  = HSTRING()
    hr  = WindowsCreateStringReference(buf, len(s), ctypes.byref(hdr), ctypes.byref(hs))
    check_hr(hr, "WindowsCreateStringReference")
    _hstring_refs.append((buf, hdr))  # prevent GC
    return hs

# ============================================================
# Window procedure
# ============================================================
@WNDPROC
def wnd_proc(hwnd, msg, w_param, l_param):
    if msg == WM_DESTROY:
        user32.PostQuitMessage(0)
        return 0
    elif msg == WM_PAINT:
        ps = PAINTSTRUCT()
        user32.BeginPaint(hwnd, ctypes.byref(ps))
        user32.EndPaint(hwnd, ctypes.byref(ps))
        return 0
    return user32.DefWindowProcW(hwnd, msg, w_param, l_param)

# ============================================================
# Step 1: Create Win32 window with WS_EX_NOREDIRECTIONBITMAP
# ============================================================
def create_window():
    global g_hwnd
    debug_print("CreateWindow: begin")

    hInst = kernel32.GetModuleHandleW(None)
    class_name = "PyCompTriangleGL"

    wc = WNDCLASSEXW()
    ctypes.memset(ctypes.byref(wc), 0, ctypes.sizeof(wc))
    wc.cbSize        = ctypes.sizeof(WNDCLASSEXW)
    wc.hInstance     = hInst
    wc.lpszClassName = class_name
    wc.lpfnWndProc   = ctypes.cast(wnd_proc, ctypes.c_void_p)
    wc.hCursor       = user32.LoadCursorW(None, ctypes.cast(IDC_ARROW, wintypes.LPCWSTR))
    wc.hbrBackground = None  # No GDI background - composition handles rendering

    atom = user32.RegisterClassExW(ctypes.byref(wc))
    # Ignore ERROR_CLASS_ALREADY_EXISTS

    # Adjust window rect for the desired client area
    style = WS_OVERLAPPEDWINDOW
    rc = wintypes.RECT(0, 0, WIDTH, HEIGHT)
    user32.AdjustWindowRect(ctypes.byref(rc), style, False)

    g_hwnd = user32.CreateWindowExW(
        WS_EX_NOREDIRECTIONBITMAP,
        class_name,
        "OpenGL 4.6 + D3D11 + Vulkan 1.4 via Windows.UI.Composition (Python)",
        style,
        CW_USEDEFAULT, CW_USEDEFAULT,
        rc.right - rc.left, rc.bottom - rc.top,
        None, None, hInst, None,
    )
    if not g_hwnd:
        raise RuntimeError(f"CreateWindowExW failed: GLE={ctypes.get_last_error()}")

    user32.ShowWindow(g_hwnd, 1)  # SW_SHOWNORMAL
    user32.UpdateWindow(g_hwnd)
    debug_print("CreateWindow: ok")

# ============================================================
# Step 2: Create D3D11 device + DXGI swap chain for Composition
# ============================================================
def init_d3d11():
    global g_d3d_device, g_d3d_ctx, g_swap_chain, g_back_buffer, g_rtv
    debug_print("InitD3D11: begin")

    # D3D11CreateDevice
    feature_levels = (ctypes.c_uint * 1)(D3D_FEATURE_LEVEL_11_0)
    fl_out = ctypes.c_uint(0)

    d3d11.D3D11CreateDevice.restype  = wintypes.HRESULT
    d3d11.D3D11CreateDevice.argtypes = (
        ctypes.c_void_p, ctypes.c_uint, ctypes.c_void_p, ctypes.c_uint,
        ctypes.POINTER(ctypes.c_uint), ctypes.c_uint, ctypes.c_uint,
        ctypes.POINTER(ctypes.c_void_p), ctypes.POINTER(ctypes.c_uint),
        ctypes.POINTER(ctypes.c_void_p),
    )

    hr = d3d11.D3D11CreateDevice(
        None, D3D_DRIVER_TYPE_HARDWARE, None,
        D3D11_CREATE_DEVICE_BGRA_SUPPORT,
        feature_levels, 1, D3D11_SDK_VERSION,
        ctypes.byref(g_d3d_device), ctypes.byref(fl_out), ctypes.byref(g_d3d_ctx),
    )
    check_hr(hr, "D3D11CreateDevice")
    debug_print(f"InitD3D11: device created (FL=0x{fl_out.value:X})")

    # Get DXGI factory: device -> IDXGIDevice -> adapter -> IDXGIFactory2
    dxgi_device = com_qi(g_d3d_device, IID_IDXGIDevice)

    # IDXGIDevice::GetAdapter (slot 7 = IUnknown(3) + GetAdapter(7-3=4th method... 
    # actually IDXGIObject has GetPrivateData(3), SetPrivateData(4), SetPrivateDataInterface(5), GetParent(6)
    # IDXGIDevice inherits IDXGIObject -> IUnknown
    # IUnknown: QI(0), AddRef(1), Release(2)
    # IDXGIObject: SetPrivateData(3), SetPrivateDataInterface(4), GetPrivateData(5), GetParent(6)
    # IDXGIDevice: GetAdapter(7), CreateSurface(8), ...
    adapter = ctypes.c_void_p()
    fn = com_call(dxgi_device.value, 7, wintypes.HRESULT,
                  (ctypes.c_void_p, ctypes.POINTER(ctypes.c_void_p)))
    hr = fn(dxgi_device.value, ctypes.byref(adapter))
    check_hr(hr, "IDXGIDevice::GetAdapter")
    com_release(dxgi_device)

    # IDXGIObject::GetParent (slot 6)
    factory = ctypes.c_void_p()
    fn = com_call(adapter.value, 6, wintypes.HRESULT,
                  (ctypes.c_void_p, ctypes.POINTER(GUID), ctypes.POINTER(ctypes.c_void_p)))
    hr = fn(adapter.value, ctypes.byref(IID_IDXGIFactory2), ctypes.byref(factory))
    check_hr(hr, "IDXGIAdapter::GetParent(IDXGIFactory2)")
    com_release(adapter)

    # Create swap chain for composition
    desc = DXGI_SWAP_CHAIN_DESC1()
    ctypes.memset(ctypes.byref(desc), 0, ctypes.sizeof(desc))
    desc.Width      = WIDTH
    desc.Height     = HEIGHT
    desc.Format     = DXGI_FORMAT_B8G8R8A8_UNORM
    desc.SampleDesc.Count = 1
    desc.BufferUsage = DXGI_USAGE_RENDER_TARGET_OUTPUT
    desc.BufferCount = 2
    desc.Scaling    = DXGI_SCALING_STRETCH
    desc.SwapEffect = DXGI_SWAP_EFFECT_FLIP_SEQUENTIAL
    desc.AlphaMode  = DXGI_ALPHA_MODE_PREMULTIPLIED

    # IDXGIFactory2::CreateSwapChainForComposition
    # IDXGIFactory2 inherits IDXGIFactory1 -> IDXGIFactory -> IDXGIObject -> IUnknown
    # IUnknown: 0-2
    # IDXGIObject: 3-6 (SetPrivateData, SetPrivateDataInterface, GetPrivateData, GetParent)
    # IDXGIFactory: 7-11 (EnumAdapters, MakeWindowAssociation, GetWindowAssociation,
    #                      CreateSwapChain, CreateSoftwareAdapter)
    # IDXGIFactory1: 12-13 (EnumAdapters1, IsCurrent)
    # IDXGIFactory2: 14-22 (IsWindowedStereoEnabled, CreateSwapChainForHwnd,
    #                        CreateSwapChainForCoreWindow, GetSharedResourceAdapterLuid,
    #                        RegisterStereoStatusWindow, RegisterStereoStatusEvent,
    #                        UnregisterStereoStatus, RegisterOcclusionStatusWindow,
    #                        RegisterOcclusionStatusEvent)
    # Wait - let me recount for IDXGIFactory2:
    # slot 14: IsWindowedStereoEnabled
    # slot 15: CreateSwapChainForHwnd
    # slot 16: CreateSwapChainForCoreWindow
    # slot 17: GetSharedResourceAdapterLuid
    # slot 18: RegisterStereoStatusWindow
    # slot 19: RegisterStereoStatusEvent
    # slot 20: UnregisterStereoStatus
    # slot 21: RegisterOcclusionStatusWindow
    # slot 22: RegisterOcclusionStatusEvent
    # slot 23: UnregisterOcclusionStatus
    # slot 24: CreateSwapChainForComposition
    fn = com_call(factory.value, 24, wintypes.HRESULT,
                  (ctypes.c_void_p, ctypes.c_void_p, ctypes.POINTER(DXGI_SWAP_CHAIN_DESC1),
                   ctypes.c_void_p, ctypes.POINTER(ctypes.c_void_p)))
    hr = fn(factory.value, g_d3d_device.value, ctypes.byref(desc), None, ctypes.byref(g_swap_chain))
    check_hr(hr, "CreateSwapChainForComposition")
    com_release(factory)
    debug_print("InitD3D11: SwapChain for Composition created")

    # Get back buffer (IDXGISwapChain::GetBuffer, slot 9)
    # IDXGISwapChain inherits IDXGIDeviceSubObject -> IDXGIObject -> IUnknown
    # IUnknown: 0-2
    # IDXGIObject: 3-6
    # IDXGIDeviceSubObject: 7 (GetDevice)
    # IDXGISwapChain: 8 (Present), 9 (GetBuffer), ...
    fn = com_call(g_swap_chain.value, 9, wintypes.HRESULT,
                  (ctypes.c_void_p, ctypes.c_uint, ctypes.POINTER(GUID),
                   ctypes.POINTER(ctypes.c_void_p)))
    hr = fn(g_swap_chain.value, 0, ctypes.byref(IID_ID3D11Texture2D), ctypes.byref(g_back_buffer))
    check_hr(hr, "IDXGISwapChain::GetBuffer")

    # Create render target view
    # ID3D11Device::CreateRenderTargetView - slot 9
    # ID3D11Device inherits IUnknown (0-2)
    # slot 3: CreateBuffer
    # slot 4: CreateTexture1D
    # slot 5: CreateTexture2D
    # slot 6: CreateTexture3D
    # slot 7: CreateShaderResourceView
    # slot 8: CreateUnorderedAccessView
    # slot 9: CreateRenderTargetView
    fn = com_call(g_d3d_device.value, 9, wintypes.HRESULT,
                  (ctypes.c_void_p, ctypes.c_void_p, ctypes.c_void_p,
                   ctypes.POINTER(ctypes.c_void_p)))
    hr = fn(g_d3d_device.value, g_back_buffer.value, None, ctypes.byref(g_rtv))
    check_hr(hr, "CreateRenderTargetView")

    debug_print("InitD3D11: ok")

def init_d3d11_triangle_panel():
    global g_d3d_vs, g_d3d_ps, g_d3d_layout, g_d3d_vb
    debug_print("InitD3D11TrianglePanel: begin")

    vs_blob = _compile_hlsl_blob("VS", "vs_4_0")
    ps_blob = _compile_hlsl_blob("PS", "ps_4_0")

    fn = com_call(g_d3d_device.value, 12, wintypes.HRESULT,
                  (ctypes.c_void_p, ctypes.c_void_p, ctypes.c_size_t, ctypes.c_void_p, ctypes.POINTER(ctypes.c_void_p)))
    hr = fn(g_d3d_device.value, _blob_ptr(vs_blob), _blob_size(vs_blob), None, ctypes.byref(g_d3d_vs))
    check_hr(hr, "CreateVertexShader")

    fn = com_call(g_d3d_device.value, 15, wintypes.HRESULT,
                  (ctypes.c_void_p, ctypes.c_void_p, ctypes.c_size_t, ctypes.c_void_p, ctypes.POINTER(ctypes.c_void_p)))
    hr = fn(g_d3d_device.value, _blob_ptr(ps_blob), _blob_size(ps_blob), None, ctypes.byref(g_d3d_ps))
    check_hr(hr, "CreatePixelShader")

    layout = (D3D11_INPUT_ELEMENT_DESC * 2)(
        D3D11_INPUT_ELEMENT_DESC(b"POSITION", 0, DXGI_FORMAT_R32G32B32_FLOAT, 0, 0, D3D11_INPUT_PER_VERTEX_DATA, 0),
        D3D11_INPUT_ELEMENT_DESC(b"COLOR",    0, DXGI_FORMAT_R32G32B32A32_FLOAT, 0, 12, D3D11_INPUT_PER_VERTEX_DATA, 0),
    )
    fn = com_call(g_d3d_device.value, 11, wintypes.HRESULT,
                  (ctypes.c_void_p, ctypes.POINTER(D3D11_INPUT_ELEMENT_DESC), wintypes.UINT,
                   ctypes.c_void_p, ctypes.c_size_t, ctypes.POINTER(ctypes.c_void_p)))
    hr = fn(g_d3d_device.value, layout, 2, _blob_ptr(vs_blob), _blob_size(vs_blob), ctypes.byref(g_d3d_layout))
    com_release(vs_blob)
    com_release(ps_blob)
    check_hr(hr, "CreateInputLayout")

    class VERTEX(ctypes.Structure):
        _fields_ = [("x", ctypes.c_float), ("y", ctypes.c_float), ("z", ctypes.c_float),
                    ("r", ctypes.c_float), ("g", ctypes.c_float), ("b", ctypes.c_float), ("a", ctypes.c_float)]
    verts = (VERTEX * 3)(
        VERTEX(0.0, 0.5, 0.5, 1.0, 0.0, 0.0, 1.0),
        VERTEX(0.5,-0.5, 0.5, 0.0, 1.0, 0.0, 1.0),
        VERTEX(-0.5,-0.5,0.5, 0.0, 0.0, 1.0, 1.0),
    )
    bd = D3D11_BUFFER_DESC()
    bd.ByteWidth = ctypes.sizeof(verts)
    bd.Usage = D3D11_USAGE_DEFAULT
    bd.BindFlags = D3D11_BIND_VERTEX_BUFFER
    sd = D3D11_SUBRESOURCE_DATA()
    sd.pSysMem = ctypes.cast(verts, ctypes.c_void_p)
    fn = com_call(g_d3d_device.value, 3, wintypes.HRESULT,
                  (ctypes.c_void_p, ctypes.POINTER(D3D11_BUFFER_DESC), ctypes.POINTER(D3D11_SUBRESOURCE_DATA),
                   ctypes.POINTER(ctypes.c_void_p)))
    hr = fn(g_d3d_device.value, ctypes.byref(bd), ctypes.byref(sd), ctypes.byref(g_d3d_vb))
    check_hr(hr, "CreateBuffer(VB)")
    debug_print("InitD3D11TrianglePanel: ok")

def init_vulkan_panel():
    global g_vk_helper, g_vk_state, g_vk_stage_tex
    debug_print("InitVulkanPanel: begin")

    vk_path = Path(__file__).resolve().parent.parent / "triangle_vk14" / "hello.py"
    g_vk_helper = _load_module_from_path("py_wuc_vk14_helper_multi", vk_path)

    # Compile SPIR-V using the helper's shaderc wrapper and shader files.
    shaderc = g_vk_helper.Shaderc("shaderc_shared.dll")
    vk_dir = vk_path.parent
    vert_src = (vk_dir / "hello.vert").read_text(encoding="utf-8")
    frag_src = (vk_dir / "hello.frag").read_text(encoding="utf-8")
    vert_spv = shaderc.compile(vert_src, g_vk_helper.Shaderc.VERTEX, filename="hello.vert")
    frag_spv = shaderc.compile(frag_src, g_vk_helper.Shaderc.FRAGMENT, filename="hello.frag")

    panel_w = WIDTH - (WIDTH // 3) * 2
    panel_h = HEIGHT
    g_vk_state = g_vk_helper._init_vulkan_offscreen(vert_spv, frag_spv, panel_w, panel_h)
    # Match the C multi sample's Vulkan panel clear color (dark red).
    g_vk_helper.g_offscreen_clear_color = (0.15, 0.05, 0.05, 1.0)

    # Create a CPU-writable staging texture for the Vulkan panel copy.
    desc = D3D11_TEXTURE2D_DESC()
    desc.Width = panel_w
    desc.Height = panel_h
    desc.MipLevels = 1
    desc.ArraySize = 1
    desc.Format = DXGI_FORMAT_B8G8R8A8_UNORM
    desc.SampleDesc = DXGI_SAMPLE_DESC(1, 0)
    desc.Usage = D3D11_USAGE_STAGING
    desc.BindFlags = 0
    desc.CPUAccessFlags = D3D11_CPU_ACCESS_WRITE
    desc.MiscFlags = 0
    fn = com_call(g_d3d_device.value, 5, wintypes.HRESULT,
                  (ctypes.c_void_p, ctypes.POINTER(D3D11_TEXTURE2D_DESC), ctypes.c_void_p, ctypes.POINTER(ctypes.c_void_p)))
    hr = fn(g_d3d_device.value, ctypes.byref(desc), None, ctypes.byref(g_vk_stage_tex))
    check_hr(hr, "CreateTexture2D(Vulkan staging)")

    # Replace the helper copy callback so it writes into the right panel of this sample's back buffer.
    def _copy_into_right_panel(src_ptr, width, height):
        mapped = D3D11_MAPPED_SUBRESOURCE()
        map_fn = com_call(g_d3d_ctx.value, 14, wintypes.HRESULT,
                          (ctypes.c_void_p, ctypes.c_void_p, wintypes.UINT, wintypes.UINT, wintypes.UINT,
                           ctypes.POINTER(D3D11_MAPPED_SUBRESOURCE)))
        hr2 = map_fn(g_d3d_ctx.value, g_vk_stage_tex.value, 0, D3D11_MAP_WRITE, 0, ctypes.byref(mapped))
        if hr2 < 0:
            return
        src_pitch = width * 4
        for y in range(height):
            ctypes.memmove(mapped.pData + y * mapped.RowPitch, src_ptr.value + y * src_pitch, src_pitch)
        com_call(g_d3d_ctx.value, 15, None, (ctypes.c_void_p, ctypes.c_void_p, wintypes.UINT))(g_d3d_ctx.value, g_vk_stage_tex.value, 0)
        box = D3D11_BOX(0, 0, 0, width, height, 1)
        dst_x = (WIDTH // 3) * 2
        # ID3D11DeviceContext::CopySubresourceRegion is slot 46.
        com_call(g_d3d_ctx.value, 46, None,
                 (ctypes.c_void_p, ctypes.c_void_p, wintypes.UINT, wintypes.UINT, wintypes.UINT, wintypes.UINT,
                  ctypes.c_void_p, wintypes.UINT, ctypes.POINTER(D3D11_BOX)))(
            g_d3d_ctx.value, g_back_buffer.value, 0, dst_x, 0, 0, g_vk_stage_tex.value, 0, ctypes.byref(box))

    g_vk_helper._copy_vulkan_pixels_to_composition = _copy_into_right_panel
    debug_print("InitVulkanPanel: ok")

# ============================================================
# Step 3: Initialize DispatcherQueue + WinRT Compositor
# ============================================================
def init_dispatcher_queue():
    global g_dq_controller
    debug_print("InitDispatcherQueue: begin")

    if core_messaging is None:
        debug_print("InitDispatcherQueue: CoreMessaging.dll not found, skipping")
        return

    core_messaging.CreateDispatcherQueueController.restype  = wintypes.HRESULT
    core_messaging.CreateDispatcherQueueController.argtypes = (
        DispatcherQueueOptions, ctypes.POINTER(ctypes.c_void_p),
    )

    opt = DispatcherQueueOptions()
    opt.dwSize        = ctypes.sizeof(DispatcherQueueOptions)
    opt.threadType    = DQTYPE_THREAD_CURRENT
    opt.apartmentType = DQTAT_COM_STA

    hr = core_messaging.CreateDispatcherQueueController(opt, ctypes.byref(g_dq_controller))
    check_hr(hr, "CreateDispatcherQueueController")
    debug_print("InitDispatcherQueue: ok")

def init_composition():
    global g_compositor, g_desktop_interop, g_comp_interop
    global g_desktop_target, g_composition_target, g_root_visual
    global g_sprite_visual, g_composition_surface, g_surface_brush
    global g_composition_brush, g_visual, g_visual_collection
    global g_com_initialized

    debug_print("InitComposition: begin")

    # COM STA initialization
    ole32.CoInitializeEx.restype  = wintypes.HRESULT
    ole32.CoInitializeEx.argtypes = (ctypes.c_void_p, wintypes.DWORD)
    ole32.CoUninitialize.restype  = None
    ole32.CoUninitialize.argtypes = ()
    hr = ole32.CoInitializeEx(None, COINIT_APARTMENTTHREADED)
    if hr >= 0:
        g_com_initialized = True
        debug_print("InitComposition: CoInitializeEx(STA) ok")
    elif (hr & 0xFFFFFFFF) == RPC_E_CHANGED_MODE:
        debug_print("InitComposition: CoInitializeEx returned RPC_E_CHANGED_MODE (continuing)")
    else:
        check_hr(hr, "CoInitializeEx")

    # DispatcherQueue (required before some Composition calls)
    init_dispatcher_queue()

    # Initialize WinRT
    hr = RoInitialize(RO_INIT_SINGLETHREADED)
    if hr < 0 and hr != S_FALSE and (hr & 0xFFFFFFFF) != RPC_E_CHANGED_MODE:
        check_hr(hr, "RoInitialize")
    debug_print("InitComposition: RoInitialize ok")

    # Activate Compositor
    hs_class = create_hstring("Windows.UI.Composition.Compositor")
    inspectable = ctypes.c_void_p()
    hr = RoActivateInstance(hs_class, ctypes.byref(inspectable))
    check_hr(hr, "RoActivateInstance(Compositor)")
    g_compositor = inspectable
    debug_print("InitComposition: Compositor created")

    # QI for ICompositorDesktopInterop (COM, not WinRT)
    g_desktop_interop = com_qi(g_compositor, IID_ICompositorDesktopInterop)
    debug_print("InitComposition: ICompositorDesktopInterop obtained")

    # CreateDesktopWindowTarget (slot 3 of ICompositorDesktopInterop)
    g_desktop_target = ctypes.c_void_p()
    fn = com_call(g_desktop_interop.value, 3, wintypes.HRESULT,
                  (ctypes.c_void_p, wintypes.HWND, wintypes.BOOL,
                   ctypes.POINTER(ctypes.c_void_p)))
    hr = fn(g_desktop_interop.value, g_hwnd, False, ctypes.byref(g_desktop_target))
    check_hr(hr, "CreateDesktopWindowTarget")
    debug_print("InitComposition: DesktopWindowTarget created")

    # QI DesktopWindowTarget -> ICompositionTarget
    g_composition_target = com_qi(g_desktop_target, IID_ICompositionTarget)

    # Create root ContainerVisual (ICompositor slot 9)
    g_root_visual = ctypes.c_void_p()
    fn = com_call(g_compositor.value, 9, wintypes.HRESULT,
                  (ctypes.c_void_p, ctypes.POINTER(ctypes.c_void_p)))
    hr = fn(g_compositor.value, ctypes.byref(g_root_visual))
    check_hr(hr, "CreateContainerVisual")
    debug_print("InitComposition: ContainerVisual created")

    # Set root visual on the composition target
    # ICompositionTarget::put_Root (slot 7)
    root_as_visual = com_qi(g_root_visual, IID_IVisual)
    fn = com_call(g_composition_target.value, 7, wintypes.HRESULT,
                  (ctypes.c_void_p, ctypes.c_void_p))
    hr = fn(g_composition_target.value, root_as_visual.value)
    check_hr(hr, "CompositionTarget::put_Root")
    com_release(root_as_visual)
    debug_print("InitComposition: Root visual set")

    # QI Compositor -> ICompositorInterop (COM interop)
    g_comp_interop = com_qi(g_compositor, IID_ICompositorInterop)

    # CreateCompositionSurfaceForSwapChain (slot 4 of ICompositorInterop)
    g_composition_surface = ctypes.c_void_p()
    fn = com_call(g_comp_interop.value, 4, wintypes.HRESULT,
                  (ctypes.c_void_p, ctypes.c_void_p, ctypes.POINTER(ctypes.c_void_p)))
    hr = fn(g_comp_interop.value, g_swap_chain.value, ctypes.byref(g_composition_surface))
    check_hr(hr, "CreateCompositionSurfaceForSwapChain")
    debug_print("InitComposition: CompositionSurface created")

    # Create SurfaceBrush (ICompositor slot 24: CreateSurfaceBrush(ICompositionSurface))
    g_surface_brush = ctypes.c_void_p()
    fn = com_call(g_compositor.value, 24, wintypes.HRESULT,
                  (ctypes.c_void_p, ctypes.c_void_p, ctypes.POINTER(ctypes.c_void_p)))
    hr = fn(g_compositor.value, g_composition_surface.value, ctypes.byref(g_surface_brush))
    check_hr(hr, "CreateSurfaceBrush")
    debug_print("InitComposition: SurfaceBrush created")

    # Create SpriteVisual (ICompositor slot 22)
    g_sprite_visual = ctypes.c_void_p()
    fn = com_call(g_compositor.value, 22, wintypes.HRESULT,
                  (ctypes.c_void_p, ctypes.POINTER(ctypes.c_void_p)))
    hr = fn(g_compositor.value, ctypes.byref(g_sprite_visual))
    check_hr(hr, "CreateSpriteVisual")
    debug_print("InitComposition: SpriteVisual created")

    # Set brush on SpriteVisual
    # ISpriteVisual::put_Brush (slot 7), needs ICompositionBrush
    g_composition_brush = com_qi(g_surface_brush, IID_ICompositionBrush)
    fn = com_call(g_sprite_visual.value, 7, wintypes.HRESULT,
                  (ctypes.c_void_p, ctypes.c_void_p))
    hr = fn(g_sprite_visual.value, g_composition_brush.value)
    check_hr(hr, "SpriteVisual::put_Brush")
    debug_print("InitComposition: Brush set on SpriteVisual")

    # Set size on SpriteVisual via IVisual::put_Size (slot 36)
    # put_Size expects Vector2 by value (two floats packed contiguously)
    g_visual = com_qi(g_sprite_visual, IID_IVisual)

    # Vector2 is passed by value as two floats (8 bytes total)
    # On x64 Windows ABI, a struct <= 8 bytes is passed in a register as a single 64-bit value
    size_x = ctypes.c_float(float(WIDTH))
    size_y = ctypes.c_float(float(HEIGHT))
    # Pack two floats into one c_uint64 for by-value struct passing
    packed = struct.pack('ff', float(WIDTH), float(HEIGHT))
    vec2_as_u64 = struct.unpack('Q', packed)[0]

    fn = com_call(g_visual.value, 36, wintypes.HRESULT,
                  (ctypes.c_void_p, ctypes.c_uint64))
    hr = fn(g_visual.value, vec2_as_u64)
    if hr < 0:
        debug_print(f"InitComposition: put_Size failed 0x{hr & 0xFFFFFFFF:08X} (non-fatal)")
    else:
        debug_print(f"InitComposition: Size set to {WIDTH}x{HEIGHT}")

    # Get children collection from root visual
    # IContainerVisual::get_Children (slot 6)
    g_visual_collection = ctypes.c_void_p()
    fn = com_call(g_root_visual.value, 6, wintypes.HRESULT,
                  (ctypes.c_void_p, ctypes.POINTER(ctypes.c_void_p)))
    hr = fn(g_root_visual.value, ctypes.byref(g_visual_collection))
    check_hr(hr, "ContainerVisual::get_Children")

    # Insert sprite into visual tree
    # IVisualCollection::InsertAtTop (slot 9)
    sprite_as_visual = com_qi(g_sprite_visual, IID_IVisual)
    fn = com_call(g_visual_collection.value, 9, wintypes.HRESULT,
                  (ctypes.c_void_p, ctypes.c_void_p))
    hr = fn(g_visual_collection.value, sprite_as_visual.value)
    check_hr(hr, "VisualCollection::InsertAtTop")
    com_release(sprite_as_visual)

    debug_print("InitComposition: SpriteVisual inserted - Composition init complete")

# ============================================================
# Step 4: Initialize OpenGL 4.6 via WGL_NV_DX_interop
# ============================================================
def init_opengl():
    global g_hdc, g_hglrc, gl, wgl
    global g_gl_vao, g_gl_vbo, g_gl_program, g_gl_rbo, g_gl_fbo
    global g_gl_pos_attrib, g_gl_col_attrib
    global g_gl_interop_device, g_gl_interop_object

    debug_print("InitOpenGL: begin")

    # Get DC from the window
    g_hdc = user32.GetDC(g_hwnd)
    if not g_hdc:
        raise RuntimeError("GetDC failed")

    # Set pixel format
    pfd = PIXELFORMATDESCRIPTOR()
    ctypes.memset(ctypes.byref(pfd), 0, ctypes.sizeof(pfd))
    pfd.nSize      = ctypes.sizeof(PIXELFORMATDESCRIPTOR)
    pfd.nVersion   = 1
    pfd.dwFlags    = PFD_DRAW_TO_WINDOW | PFD_SUPPORT_OPENGL | PFD_DOUBLEBUFFER
    pfd.iPixelType = PFD_TYPE_RGBA
    pfd.cColorBits = 32
    pfd.cDepthBits = 24
    pfd.iLayerType = PFD_MAIN_PLANE

    pf = gdi32.ChoosePixelFormat(g_hdc, ctypes.byref(pfd))
    if pf == 0:
        raise RuntimeError("ChoosePixelFormat failed")
    gdi32.SetPixelFormat(g_hdc, pf, ctypes.byref(pfd))

    # Create legacy OpenGL context first
    old_rc = opengl32.wglCreateContext(g_hdc)
    if not old_rc:
        raise RuntimeError("wglCreateContext failed")
    if not opengl32.wglMakeCurrent(g_hdc, old_rc):
        raise RuntimeError("wglMakeCurrent failed (legacy)")

    # Try to create OpenGL 4.6 core profile context
    wglCreateContextAttribsARB_addr = opengl32.wglGetProcAddress(b"wglCreateContextAttribsARB")
    if wglCreateContextAttribsARB_addr:
        PFNWGLCCA = ctypes.WINFUNCTYPE(
            wintypes.HANDLE, wintypes.HDC, wintypes.HANDLE, ctypes.POINTER(ctypes.c_int))
        wglCreateContextAttribsARB = PFNWGLCCA(wglCreateContextAttribsARB_addr)

        attrs = (ctypes.c_int * 9)(
            WGL_CONTEXT_MAJOR_VERSION_ARB, 4,
            WGL_CONTEXT_MINOR_VERSION_ARB, 6,
            WGL_CONTEXT_FLAGS_ARB, 0,
            WGL_CONTEXT_PROFILE_MASK_ARB, WGL_CONTEXT_CORE_PROFILE_BIT_ARB,
            0,
        )
        new_rc = wglCreateContextAttribsARB(g_hdc, None, attrs)
        if new_rc:
            opengl32.wglMakeCurrent(g_hdc, new_rc)
            opengl32.wglDeleteContext(old_rc)
            g_hglrc = new_rc
            debug_print("InitOpenGL: OpenGL 4.6 core context created")
        else:
            g_hglrc = old_rc
            debug_print("InitOpenGL: 4.6 create failed, using legacy context")
    else:
        g_hglrc = old_rc
        debug_print("InitOpenGL: wglCreateContextAttribsARB not available, using legacy context")

    opengl32.wglMakeCurrent(g_hdc, g_hglrc)

    # Print GL version for diagnostics
    GL_VERSION = 0x1F02
    ver = opengl32.glGetString(GL_VERSION)
    if ver:
        debug_print(f"InitOpenGL: GL_VERSION = {ver.decode('utf-8', errors='replace')}")

    # Load required GL extension functions
    def load_gl(name, restype, argtypes):
        fn = load_gl_func(name, restype, argtypes)
        gl[name] = fn
        return fn

    load_gl("glGenBuffers",              None, (GLsizei, ctypes.POINTER(GLuint)))
    load_gl("glBindBuffer",              None, (GLenum, GLuint))
    load_gl("glBufferData",              None, (GLenum, GLsizeiptr, ctypes.c_void_p, GLenum))
    load_gl("glCreateShader",            GLuint, (GLenum,))
    load_gl("glShaderSource",            None, (GLuint, GLsizei, ctypes.POINTER(ctypes.c_char_p), ctypes.POINTER(GLint)))
    load_gl("glCompileShader",           None, (GLuint,))
    load_gl("glGetShaderiv",             None, (GLuint, GLenum, ctypes.POINTER(GLint)))
    load_gl("glGetShaderInfoLog",        None, (GLuint, GLsizei, ctypes.POINTER(GLsizei), ctypes.c_char_p))
    load_gl("glCreateProgram",           GLuint, ())
    load_gl("glAttachShader",            None, (GLuint, GLuint))
    load_gl("glLinkProgram",             None, (GLuint,))
    load_gl("glGetProgramiv",            None, (GLuint, GLenum, ctypes.POINTER(GLint)))
    load_gl("glGetProgramInfoLog",       None, (GLuint, GLsizei, ctypes.POINTER(GLsizei), ctypes.c_char_p))
    load_gl("glUseProgram",              None, (GLuint,))
    load_gl("glGetAttribLocation",       GLint, (GLuint, ctypes.c_char_p))
    load_gl("glEnableVertexAttribArray", None, (GLuint,))
    load_gl("glVertexAttribPointer",     None, (GLuint, GLint, GLenum, GLboolean, GLsizei, ctypes.c_void_p))
    load_gl("glGenVertexArrays",         None, (GLsizei, ctypes.POINTER(GLuint)))
    load_gl("glBindVertexArray",         None, (GLuint,))
    load_gl("glGenFramebuffers",         None, (GLsizei, ctypes.POINTER(GLuint)))
    load_gl("glBindFramebuffer",         None, (GLenum, GLuint))
    load_gl("glFramebufferRenderbuffer", None, (GLenum, GLenum, GLenum, GLuint))
    load_gl("glCheckFramebufferStatus",  GLenum, (GLenum,))
    load_gl("glGenRenderbuffers",        None, (GLsizei, ctypes.POINTER(GLuint)))
    load_gl("glBindRenderbuffer",        None, (GLenum, GLuint))
    load_gl("glDeleteBuffers",           None, (GLsizei, ctypes.POINTER(GLuint)))
    load_gl("glDeleteVertexArrays",      None, (GLsizei, ctypes.POINTER(GLuint)))
    load_gl("glDeleteFramebuffers",      None, (GLsizei, ctypes.POINTER(GLuint)))
    load_gl("glDeleteRenderbuffers",     None, (GLsizei, ctypes.POINTER(GLuint)))
    load_gl("glDeleteProgram",           None, (GLuint,))

    # Load WGL_NV_DX_interop functions
    def load_wgl(name, restype, argtypes):
        addr = opengl32.wglGetProcAddress(name.encode())
        if not addr:
            raise RuntimeError(f"Missing WGL function: {name}")
        FN = ctypes.WINFUNCTYPE(restype, *argtypes)
        fn = FN(addr)
        wgl[name] = fn
        return fn

    load_wgl("wglDXOpenDeviceNV",       ctypes.c_void_p, (ctypes.c_void_p,))
    load_wgl("wglDXCloseDeviceNV",      wintypes.BOOL, (ctypes.c_void_p,))
    load_wgl("wglDXRegisterObjectNV",   ctypes.c_void_p,
             (ctypes.c_void_p, ctypes.c_void_p, GLuint, GLenum, GLenum))
    load_wgl("wglDXUnregisterObjectNV", wintypes.BOOL, (ctypes.c_void_p, ctypes.c_void_p))
    load_wgl("wglDXLockObjectsNV",      wintypes.BOOL,
             (ctypes.c_void_p, GLint, ctypes.POINTER(ctypes.c_void_p)))
    load_wgl("wglDXUnlockObjectsNV",    wintypes.BOOL,
             (ctypes.c_void_p, GLint, ctypes.POINTER(ctypes.c_void_p)))

    debug_print("InitOpenGL: WGL_NV_DX_interop functions loaded")

    # Open D3D11 device for NV interop
    g_gl_interop_device = wgl["wglDXOpenDeviceNV"](g_d3d_device.value)
    if not g_gl_interop_device:
        raise RuntimeError("wglDXOpenDeviceNV failed")
    debug_print("InitOpenGL: wglDXOpenDeviceNV ok")

    # Create renderbuffer and register with NV interop (share D3D11 back buffer)
    gl["glGenRenderbuffers"](1, ctypes.byref(g_gl_rbo))
    gl["glBindRenderbuffer"](GL_RENDERBUFFER, g_gl_rbo)

    g_gl_interop_object = wgl["wglDXRegisterObjectNV"](
        g_gl_interop_device, g_back_buffer.value,
        g_gl_rbo, GL_RENDERBUFFER, WGL_ACCESS_READ_WRITE_NV)
    if not g_gl_interop_object:
        raise RuntimeError("wglDXRegisterObjectNV failed")
    debug_print("InitOpenGL: D3D11 back buffer registered with GL interop")

    # Create FBO and attach the shared renderbuffer
    gl["glGenFramebuffers"](1, ctypes.byref(g_gl_fbo))
    gl["glBindFramebuffer"](GL_FRAMEBUFFER, g_gl_fbo)
    gl["glFramebufferRenderbuffer"](GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0,
                                    GL_RENDERBUFFER, g_gl_rbo)
    fbo_status = gl["glCheckFramebufferStatus"](GL_FRAMEBUFFER)
    gl["glBindFramebuffer"](GL_FRAMEBUFFER, GLuint(0))
    if fbo_status != GL_FRAMEBUFFER_COMPLETE:
        raise RuntimeError(f"FBO incomplete: status=0x{fbo_status:04X}")
    debug_print("InitOpenGL: FBO complete")

    # Create VAO
    gl["glGenVertexArrays"](1, ctypes.byref(g_gl_vao))
    gl["glBindVertexArray"](g_gl_vao)

    # Create VBOs for position and color
    # Triangle vertices (matching the C version)
    verts = (ctypes.c_float * 9)(
        -0.5, -0.5, 0.0,
         0.5, -0.5, 0.0,
         0.0,  0.5, 0.0,
    )
    cols = (ctypes.c_float * 9)(
        0.0, 0.0, 1.0,   # Blue
        0.0, 1.0, 0.0,   # Green
        1.0, 0.0, 0.0,   # Red
    )

    gl["glGenBuffers"](2, g_gl_vbo)

    gl["glBindBuffer"](GL_ARRAY_BUFFER, g_gl_vbo[0])
    gl["glBufferData"](GL_ARRAY_BUFFER, ctypes.sizeof(verts), ctypes.cast(verts, ctypes.c_void_p), GL_STATIC_DRAW)

    gl["glBindBuffer"](GL_ARRAY_BUFFER, g_gl_vbo[1])
    gl["glBufferData"](GL_ARRAY_BUFFER, ctypes.sizeof(cols), ctypes.cast(cols, ctypes.c_void_p), GL_STATIC_DRAW)

    # Compile shaders
    def compile_shader(src_bytes, shader_type, label):
        shader = gl["glCreateShader"](shader_type)
        src_p = ctypes.c_char_p(src_bytes)
        length = GLint(len(src_bytes))
        gl["glShaderSource"](shader, 1, ctypes.byref(src_p), ctypes.byref(length))
        gl["glCompileShader"](shader)

        status = GLint(0)
        gl["glGetShaderiv"](shader, GL_COMPILE_STATUS, ctypes.byref(status))
        if status.value == 0:
            log_buf = ctypes.create_string_buffer(1024)
            log_len = GLsizei(0)
            gl["glGetShaderInfoLog"](shader, 1024, ctypes.byref(log_len), log_buf)
            raise RuntimeError(f"Shader compile failed ({label}): {log_buf.value.decode()}")
        return shader

    vs = compile_shader(VERTEX_SHADER_SRC, GL_VERTEX_SHADER, "vertex")
    fs = compile_shader(FRAGMENT_SHADER_SRC, GL_FRAGMENT_SHADER, "fragment")
    debug_print("InitOpenGL: Shaders compiled")

    # Link program
    g_gl_program = gl["glCreateProgram"]()
    gl["glAttachShader"](g_gl_program, vs)
    gl["glAttachShader"](g_gl_program, fs)
    gl["glLinkProgram"](g_gl_program)

    status = GLint(0)
    gl["glGetProgramiv"](g_gl_program, GL_LINK_STATUS, ctypes.byref(status))
    if status.value == 0:
        log_buf = ctypes.create_string_buffer(1024)
        log_len = GLsizei(0)
        gl["glGetProgramInfoLog"](g_gl_program, 1024, ctypes.byref(log_len), log_buf)
        raise RuntimeError(f"Program link failed: {log_buf.value.decode()}")
    debug_print("InitOpenGL: Program linked")

    # Setup vertex attributes
    gl["glUseProgram"](g_gl_program)
    g_gl_pos_attrib = gl["glGetAttribLocation"](g_gl_program, b"position")
    g_gl_col_attrib = gl["glGetAttribLocation"](g_gl_program, b"color")
    if g_gl_pos_attrib < 0 or g_gl_col_attrib < 0:
        raise RuntimeError(f"Attribute lookup failed: pos={g_gl_pos_attrib}, col={g_gl_col_attrib}")

    gl["glEnableVertexAttribArray"](GLuint(g_gl_pos_attrib))
    gl["glEnableVertexAttribArray"](GLuint(g_gl_col_attrib))

    debug_print("InitOpenGL: ok")

def clear_backbuffer_white():
    color = (ctypes.c_float * 4)(1.0, 1.0, 1.0, 1.0)
    fn = com_call(g_d3d_ctx.value, 50, None, (ctypes.c_void_p, ctypes.c_void_p, ctypes.POINTER(ctypes.c_float)))
    fn(g_d3d_ctx.value, g_rtv.value, color)

def render_gl_panel():
    if not g_hdc or not g_hglrc or not g_gl_interop_device or not g_gl_interop_object or not g_gl_fbo.value:
        return
    if not opengl32.wglMakeCurrent(g_hdc, g_hglrc):
        return
    objs = (ctypes.c_void_p * 1)(g_gl_interop_object)
    if not wgl["wglDXLockObjectsNV"](g_gl_interop_device, 1, objs):
        return
    try:
        panel_w = WIDTH // 3
        gl["glBindFramebuffer"](GL_FRAMEBUFFER, g_gl_fbo)
        opengl32.glViewport(0, 0, panel_w, HEIGHT)
        opengl32.glEnable(GL_SCISSOR_TEST)
        opengl32.glScissor(0, 0, panel_w, HEIGHT)
        # Match the C multi sample's OpenGL panel clear color (dark blue).
        opengl32.glClearColor(0.05, 0.05, 0.15, 1.0)
        opengl32.glClear(GL_COLOR_BUFFER_BIT)
        opengl32.glDisable(GL_SCISSOR_TEST)
        gl["glUseProgram"](g_gl_program)
        gl["glBindBuffer"](GL_ARRAY_BUFFER, g_gl_vbo[0])
        gl["glVertexAttribPointer"](GLuint(g_gl_pos_attrib), 3, GL_FLOAT, GL_FALSE, 0, None)
        gl["glBindBuffer"](GL_ARRAY_BUFFER, g_gl_vbo[1])
        gl["glVertexAttribPointer"](GLuint(g_gl_col_attrib), 3, GL_FLOAT, GL_FALSE, 0, None)
        opengl32.glDrawArrays(GL_TRIANGLES, 0, 3)
        opengl32.glFlush()
        gl["glBindFramebuffer"](GL_FRAMEBUFFER, GLuint(0))
    finally:
        wgl["wglDXUnlockObjectsNV"](g_gl_interop_device, 1, objs)

def render_d3d11_panel():
    if not (g_d3d_vs.value and g_d3d_ps.value and g_d3d_layout.value and g_d3d_vb.value):
        return
    # Bind RTV in case flip-model present unbound it in previous frame.
    rtv_arr = (ctypes.c_void_p * 1)(g_rtv.value)
    com_call(g_d3d_ctx.value, 33, None, (ctypes.c_void_p, wintypes.UINT, ctypes.POINTER(ctypes.c_void_p), ctypes.c_void_p))(
        g_d3d_ctx.value, 1, rtv_arr, None)
    clear = (ctypes.c_float * 4)(0.05, 0.15, 0.05, 1.0)  # dark green (C sample)
    com_call(g_d3d_ctx.value, 50, None, (ctypes.c_void_p, ctypes.c_void_p, ctypes.POINTER(ctypes.c_float)))(
        g_d3d_ctx.value, g_rtv.value, clear)
    vp = D3D11_VIEWPORT(float(WIDTH // 3), 0.0, float(WIDTH // 3), float(HEIGHT), 0.0, 1.0)
    com_call(g_d3d_ctx.value, 44, None, (ctypes.c_void_p, wintypes.UINT, ctypes.POINTER(D3D11_VIEWPORT)))(
        g_d3d_ctx.value, 1, ctypes.byref(vp))
    com_call(g_d3d_ctx.value, 17, None, (ctypes.c_void_p, ctypes.c_void_p))(g_d3d_ctx.value, g_d3d_layout.value)
    stride = wintypes.UINT(ctypes.sizeof(ctypes.c_float) * 7)
    offset = wintypes.UINT(0)
    vb_arr = (ctypes.c_void_p * 1)(g_d3d_vb.value)
    com_call(g_d3d_ctx.value, 18, None,
             (ctypes.c_void_p, wintypes.UINT, wintypes.UINT, ctypes.POINTER(ctypes.c_void_p),
              ctypes.POINTER(wintypes.UINT), ctypes.POINTER(wintypes.UINT)))(
        g_d3d_ctx.value, 0, 1, vb_arr, ctypes.byref(stride), ctypes.byref(offset))
    com_call(g_d3d_ctx.value, 24, None, (ctypes.c_void_p, wintypes.UINT))(g_d3d_ctx.value, D3D11_PRIMITIVE_TOPOLOGY_TRIANGLELIST)
    com_call(g_d3d_ctx.value, 11, None, (ctypes.c_void_p, ctypes.c_void_p, ctypes.c_void_p, wintypes.UINT))(g_d3d_ctx.value, g_d3d_vs.value, None, 0)
    com_call(g_d3d_ctx.value, 9, None, (ctypes.c_void_p, ctypes.c_void_p, ctypes.c_void_p, wintypes.UINT))(g_d3d_ctx.value, g_d3d_ps.value, None, 0)
    com_call(g_d3d_ctx.value, 13, None, (ctypes.c_void_p, wintypes.UINT, wintypes.UINT))(g_d3d_ctx.value, 3, 0)

def render_vulkan_panel():
    if g_vk_helper is not None and g_vk_state is not None:
        g_vk_helper._render_vulkan_offscreen_to_composition(g_vk_state)

def present_swap_chain():
    fn = com_call(g_swap_chain.value, 8, wintypes.HRESULT, (ctypes.c_void_p, ctypes.c_uint, ctypes.c_uint))
    fn(g_swap_chain.value, 1, 0)

# ============================================================
# Render: composite OpenGL / D3D11 / Vulkan onto one composition swap chain
# ============================================================
def render():
    if not g_swap_chain.value:
        return
    render_d3d11_panel()
    render_vulkan_panel()
    render_gl_panel()
    present_swap_chain()

# ============================================================
# Cleanup
# ============================================================
def cleanup():
    debug_print("Cleanup: begin")

    # Release Composition objects
    for obj in [g_visual_collection, g_visual, g_composition_brush,
                g_sprite_visual, g_surface_brush, g_composition_surface,
                g_root_visual, g_composition_target, g_desktop_target,
                g_comp_interop, g_desktop_interop, g_compositor]:
        com_release(obj)

    # OpenGL / NV interop cleanup
    if g_gl_interop_object and g_gl_interop_device:
        try:
            wgl["wglDXUnregisterObjectNV"](g_gl_interop_device, g_gl_interop_object)
        except Exception:
            pass
    if g_gl_interop_device:
        try:
            wgl["wglDXCloseDeviceNV"](g_gl_interop_device)
        except Exception:
            pass

    # Delete GL objects
    if g_hdc and g_hglrc:
        opengl32.wglMakeCurrent(g_hdc, g_hglrc)
    try:
        if g_gl_program and "glDeleteProgram" in gl:
            gl["glDeleteProgram"](g_gl_program)
        if g_gl_vbo[0] and "glDeleteBuffers" in gl:
            gl["glDeleteBuffers"](2, g_gl_vbo)
        if g_gl_vao.value and "glDeleteVertexArrays" in gl:
            gl["glDeleteVertexArrays"](1, ctypes.byref(g_gl_vao))
        if g_gl_fbo.value and "glDeleteFramebuffers" in gl:
            gl["glDeleteFramebuffers"](1, ctypes.byref(g_gl_fbo))
        if g_gl_rbo.value and "glDeleteRenderbuffers" in gl:
            gl["glDeleteRenderbuffers"](1, ctypes.byref(g_gl_rbo))
    except Exception:
        pass

    # Destroy WGL context
    if g_hglrc:
        opengl32.wglMakeCurrent(None, None)
        opengl32.wglDeleteContext(g_hglrc)
    if g_hdc and g_hwnd:
        user32.ReleaseDC(g_hwnd, g_hdc)

    # Vulkan helper / offscreen resources
    if g_vk_helper is not None and g_vk_state is not None:
        try:
            g_vk_helper._cleanup_vulkan_offscreen(g_vk_state)
        except Exception:
            pass

    # Release D3D11 objects
    for obj in [g_vk_stage_tex, g_d3d_vb, g_d3d_layout, g_d3d_ps, g_d3d_vs,
                g_rtv, g_back_buffer, g_swap_chain, g_d3d_ctx, g_d3d_device]:
        com_release(obj)

    # Release DispatcherQueue controller
    com_release(g_dq_controller)

    # Uninitialize WinRT and COM
    try:
        RoUninitialize()
    except Exception:
        pass
    if g_com_initialized:
        try:
            ole32.CoUninitialize()
        except Exception:
            pass

    debug_print("Cleanup: ok")

# ============================================================
# Main entry point
# ============================================================
def main():
    debug_print("=== OpenGL 4.6 + DirectX11 + Vulkan 1.4 via Windows.UI.Composition (Python) ===")
    debug_print(f"Python: {sys.version}")

    try:
        # Step 1: Create window
        create_window()

        # Step 2: Create D3D11 + DXGI swap chain for Composition
        init_d3d11()

        # Step 3: Initialize D3D11 triangle resources (middle panel)
        init_d3d11_triangle_panel()

        # Step 4: Initialize Composition (WinRT)
        init_composition()

        # Step 5: Initialize OpenGL 4.6 with NV_DX_interop (left panel)
        init_opengl()

        # Step 6: Initialize Vulkan 1.4 offscreen helper (right panel)
        init_vulkan_panel()

        # Message loop
        debug_print("=== ENTERING MESSAGE LOOP ===")
        msg = wintypes.MSG()
        while True:
            if user32.PeekMessageW(ctypes.byref(msg), None, 0, 0, PM_REMOVE):
                if msg.message == WM_QUIT:
                    break
                user32.TranslateMessage(ctypes.byref(msg))
                user32.DispatchMessageW(ctypes.byref(msg))
            else:
                render()

        debug_print("=== MESSAGE LOOP END ===")

    except Exception as e:
        debug_print(f"FATAL: {e}")
        import traceback
        traceback.print_exc()
    finally:
        cleanup()

if __name__ == "__main__":
    main()
