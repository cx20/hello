"""
DirectX 11 Triangle via Windows.UI.Composition (ctypes only, no external libraries)

This sample demonstrates how to render a D3D11 triangle through
Windows.UI.Composition on a classic desktop window.

Architecture:
  1. Create a Win32 window with WS_EX_NOREDIRECTIONBITMAP
  2. Create a D3D11 device (separate from swap chain)
  3. Create a DXGI swap chain for Composition (CreateSwapChainForComposition)
  4. Initialize WinRT Compositor and DesktopWindowTarget
  5. Wrap the swap chain as CompositionSurface -> SurfaceBrush -> SpriteVisual
  6. Render D3D11 triangle, present via swap chain; Composition displays it

Requirements:
  - Windows 10 1803+ (for DesktopWindowTarget)
  - Python 3.8+ (64-bit recommended)
"""

import ctypes
import struct
from ctypes import wintypes

# ============================================================
# DLLs
# ============================================================
user32   = ctypes.WinDLL("user32",   use_last_error=True)
gdi32    = ctypes.WinDLL("gdi32",    use_last_error=True)
kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
ole32    = ctypes.WinDLL("ole32",    use_last_error=True)
combase  = ctypes.WinDLL("combase",  use_last_error=True)
d3d11    = ctypes.WinDLL("d3d11",    use_last_error=True)

try:
    d3dcompiler = ctypes.WinDLL("d3dcompiler_47", use_last_error=True)
except OSError:
    d3dcompiler = ctypes.WinDLL("d3dcompiler_43", use_last_error=True)

try:
    core_messaging = ctypes.WinDLL("CoreMessaging", use_last_error=True)
except OSError:
    core_messaging = None

if not hasattr(wintypes, "HRESULT"):
    wintypes.HRESULT = ctypes.c_long
if not hasattr(wintypes, "SIZE_T"):
    wintypes.SIZE_T = ctypes.c_size_t

for name in ("HICON", "HCURSOR", "HBRUSH"):
    if not hasattr(wintypes, name):
        setattr(wintypes, name, wintypes.HANDLE)

# ============================================================
# Basic Win32 types / helpers
# ============================================================
LRESULT = wintypes.LPARAM
WNDPROC = ctypes.WINFUNCTYPE(LRESULT, wintypes.HWND, wintypes.UINT,
                              wintypes.WPARAM, wintypes.LPARAM)

def winerr():
    return ctypes.WinError(ctypes.get_last_error())

def debug_print(msg: str):
    """Output debug message to DebugView and console"""
    kernel32.OutputDebugStringW(f"[PyD3D] {msg}\n")
    print(f"[PyD3D] {msg}")

# ============================================================
# Win32 constants
# ============================================================
CS_HREDRAW = 0x0002
CS_VREDRAW = 0x0001
WS_OVERLAPPEDWINDOW = 0x00CF0000
WS_EX_NOREDIRECTIONBITMAP = 0x00200000
CW_USEDEFAULT = 0x80000000
SW_SHOW = 5

WM_DESTROY = 0x0002
WM_PAINT   = 0x000F
WM_QUIT    = 0x0012
PM_REMOVE  = 0x0001
IDC_ARROW  = 32512

# COM
COINIT_APARTMENTTHREADED = 0x2
RPC_E_CHANGED_MODE       = 0x80010106
RO_INIT_SINGLETHREADED  = 0
S_OK    = 0
S_FALSE = 1

# ============================================================
# D3D11 / DXGI constants
# ============================================================
D3D11_SDK_VERSION = 7

D3D_DRIVER_TYPE_HARDWARE  = 1
D3D_DRIVER_TYPE_WARP      = 5
D3D_DRIVER_TYPE_REFERENCE = 2

D3D_FEATURE_LEVEL_11_0 = 0xB000

# IMPORTANT: Use B8G8R8A8 for Composition compatibility
DXGI_FORMAT_B8G8R8A8_UNORM     = 87
DXGI_FORMAT_R32G32B32_FLOAT    = 6
DXGI_FORMAT_R32G32B32A32_FLOAT = 2

DXGI_USAGE_RENDER_TARGET_OUTPUT = 0x00000020
DXGI_SWAP_EFFECT_FLIP_SEQUENTIAL = 3
DXGI_SCALING_STRETCH            = 0
DXGI_ALPHA_MODE_PREMULTIPLIED   = 1

# D3D11 create device flags
D3D11_CREATE_DEVICE_BGRA_SUPPORT = 0x20

D3D11_USAGE_DEFAULT       = 0
D3D11_BIND_VERTEX_BUFFER  = 0x00000001
D3D11_INPUT_PER_VERTEX_DATA = 0

D3D11_PRIMITIVE_TOPOLOGY_TRIANGLELIST = 4

# Shader compile flags
D3DCOMPILE_ENABLE_STRICTNESS = 0x00000002

# DispatcherQueue
DQTYPE_THREAD_CURRENT = 2
DQTAT_COM_STA         = 2

# Window dimensions
WIDTH  = 640
HEIGHT = 480

# ============================================================
# Structs
# ============================================================
class WNDCLASSEXW(ctypes.Structure):
    _fields_ = [
        ("cbSize",        wintypes.UINT),
        ("style",         wintypes.UINT),
        ("lpfnWndProc",   WNDPROC),
        ("cbClsExtra",    ctypes.c_int),
        ("cbWndExtra",    ctypes.c_int),
        ("hInstance",     wintypes.HINSTANCE),
        ("hIcon",         wintypes.HICON),
        ("hCursor",       wintypes.HCURSOR),
        ("hbrBackground", wintypes.HBRUSH),
        ("lpszMenuName",  wintypes.LPCWSTR),
        ("lpszClassName", wintypes.LPCWSTR),
        ("hIconSm",       wintypes.HICON),
    ]

class MSG(ctypes.Structure):
    _fields_ = [
        ("hwnd",    wintypes.HWND),
        ("message", wintypes.UINT),
        ("wParam",  wintypes.WPARAM),
        ("lParam",  wintypes.LPARAM),
        ("time",    wintypes.DWORD),
        ("pt",      wintypes.POINT),
    ]

class RECT(ctypes.Structure):
    _fields_ = [("left", ctypes.c_long), ("top", ctypes.c_long),
                ("right", ctypes.c_long), ("bottom", ctypes.c_long)]

class DXGI_SAMPLE_DESC(ctypes.Structure):
    _fields_ = [("Count", wintypes.UINT), ("Quality", wintypes.UINT)]

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

class D3D11_VIEWPORT(ctypes.Structure):
    _fields_ = [
        ("TopLeftX", ctypes.c_float),
        ("TopLeftY", ctypes.c_float),
        ("Width",    ctypes.c_float),
        ("Height",   ctypes.c_float),
        ("MinDepth", ctypes.c_float),
        ("MaxDepth", ctypes.c_float),
    ]

class D3D11_BUFFER_DESC(ctypes.Structure):
    _fields_ = [
        ("ByteWidth",           wintypes.UINT),
        ("Usage",               wintypes.UINT),
        ("BindFlags",           wintypes.UINT),
        ("CPUAccessFlags",      wintypes.UINT),
        ("MiscFlags",           wintypes.UINT),
        ("StructureByteStride", wintypes.UINT),
    ]

class D3D11_SUBRESOURCE_DATA(ctypes.Structure):
    _fields_ = [
        ("pSysMem",          ctypes.c_void_p),
        ("SysMemPitch",      wintypes.UINT),
        ("SysMemSlicePitch", wintypes.UINT),
    ]

class D3D11_INPUT_ELEMENT_DESC(ctypes.Structure):
    _fields_ = [
        ("SemanticName",         ctypes.c_char_p),
        ("SemanticIndex",        wintypes.UINT),
        ("Format",               wintypes.UINT),
        ("InputSlot",            wintypes.UINT),
        ("AlignedByteOffset",    wintypes.UINT),
        ("InputSlotClass",       wintypes.UINT),
        ("InstanceDataStepRate", wintypes.UINT),
    ]

class DispatcherQueueOptions(ctypes.Structure):
    _fields_ = [
        ("dwSize",        wintypes.DWORD),
        ("threadType",    ctypes.c_int),
        ("apartmentType", ctypes.c_int),
    ]

class GUID(ctypes.Structure):
    _fields_ = [
        ("Data1", wintypes.DWORD),
        ("Data2", wintypes.WORD),
        ("Data3", wintypes.WORD),
        ("Data4", ctypes.c_ubyte * 8),
    ]

def guid_from_str(s: str) -> GUID:
    """Create GUID from string like '{xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx}'"""
    import uuid
    u = uuid.UUID(s)
    b = u.bytes_le
    g = GUID()
    ctypes.memmove(ctypes.byref(g), b, ctypes.sizeof(g))
    return g

# ============================================================
# GUIDs
# ============================================================
# D3D11 / DXGI
IID_ID3D11Texture2D = guid_from_str("{6f15aaf2-d208-4e89-9ab4-489535d34f9c}")
IID_IDXGIDevice     = guid_from_str("{54ec77fa-1377-44e6-8c32-88fd5f44c84c}")
IID_IDXGIFactory2   = guid_from_str("{50c83a1c-e072-4c48-87b0-3630fa36a6d0}")

# WinRT Composition interfaces
IID_ICompositorDesktopInterop = guid_from_str("{29E691FA-4567-4DCA-B319-D0F207EB6807}")
IID_ICompositorInterop        = guid_from_str("{25297D5C-3AD4-4C9C-B5CF-E36A38512330}")
IID_ICompositionTarget        = guid_from_str("{A1BEA8BA-D726-4663-8129-6B5E7927FFA6}")
IID_IVisual                   = guid_from_str("{117E202D-A859-4C89-873B-C2AA566788E3}")
IID_ICompositionBrush         = guid_from_str("{AB0D7608-30C0-40E9-B568-B60A6BD1FB46}")

# ============================================================
# HSTRING types (for WinRT activation)
# ============================================================
HSTRING = ctypes.c_void_p

class HSTRING_HEADER(ctypes.Structure):
    _fields_ = [("Reserved", ctypes.c_void_p * 5)]

# ============================================================
# Win32 prototypes
# ============================================================
kernel32.GetModuleHandleW.restype  = wintypes.HMODULE
kernel32.GetModuleHandleW.argtypes = (wintypes.LPCWSTR,)

kernel32.Sleep.restype  = None
kernel32.Sleep.argtypes = (wintypes.DWORD,)

kernel32.OutputDebugStringW.restype  = None
kernel32.OutputDebugStringW.argtypes = (wintypes.LPCWSTR,)

user32.DefWindowProcW.restype  = LRESULT
user32.DefWindowProcW.argtypes = (wintypes.HWND, wintypes.UINT, wintypes.WPARAM, wintypes.LPARAM)

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

user32.AdjustWindowRect.restype  = wintypes.BOOL
user32.AdjustWindowRect.argtypes = (ctypes.POINTER(RECT), wintypes.DWORD, wintypes.BOOL)

user32.PeekMessageW.restype  = wintypes.BOOL
user32.PeekMessageW.argtypes = (ctypes.POINTER(MSG), wintypes.HWND,
                                 wintypes.UINT, wintypes.UINT, wintypes.UINT)

user32.TranslateMessage.restype  = wintypes.BOOL
user32.TranslateMessage.argtypes = (ctypes.POINTER(MSG),)

user32.DispatchMessageW.restype  = LRESULT
user32.DispatchMessageW.argtypes = (ctypes.POINTER(MSG),)

user32.PostQuitMessage.restype  = None
user32.PostQuitMessage.argtypes = (ctypes.c_int,)

user32.LoadCursorW.restype  = wintypes.HCURSOR
user32.LoadCursorW.argtypes = (wintypes.HINSTANCE, wintypes.LPCWSTR)

# COM / WinRT prototypes
ole32.CoInitializeEx.restype  = wintypes.HRESULT
ole32.CoInitializeEx.argtypes = (ctypes.c_void_p, wintypes.DWORD)
ole32.CoUninitialize.restype  = None
ole32.CoUninitialize.argtypes = ()

combase.RoInitialize.restype  = wintypes.HRESULT
combase.RoInitialize.argtypes = (wintypes.UINT,)
combase.RoUninitialize.restype  = None
combase.RoUninitialize.argtypes = ()

combase.RoActivateInstance.restype  = wintypes.HRESULT
combase.RoActivateInstance.argtypes = (HSTRING, ctypes.POINTER(ctypes.c_void_p))

combase.WindowsCreateStringReference.restype  = wintypes.HRESULT
combase.WindowsCreateStringReference.argtypes = (
    wintypes.LPCWSTR, wintypes.UINT,
    ctypes.POINTER(HSTRING_HEADER), ctypes.POINTER(HSTRING),
)

# D3D11 device creation (separate from swap chain)
d3d11.D3D11CreateDevice.restype  = wintypes.HRESULT
d3d11.D3D11CreateDevice.argtypes = (
    ctypes.c_void_p, wintypes.UINT, ctypes.c_void_p, wintypes.UINT,
    ctypes.POINTER(wintypes.UINT), wintypes.UINT, wintypes.UINT,
    ctypes.POINTER(ctypes.c_void_p), ctypes.POINTER(wintypes.UINT),
    ctypes.POINTER(ctypes.c_void_p),
)

# D3DCompile
D3DCompile = d3dcompiler.D3DCompile
D3DCompile.restype  = wintypes.HRESULT
D3DCompile.argtypes = (
    ctypes.c_void_p, wintypes.SIZE_T, ctypes.c_char_p,
    ctypes.c_void_p, ctypes.c_void_p,
    ctypes.c_char_p, ctypes.c_char_p,
    wintypes.UINT, wintypes.UINT,
    ctypes.POINTER(ctypes.c_void_p), ctypes.POINTER(ctypes.c_void_p),
)

# ============================================================
# COM vtable caller
# ============================================================
def com_method(obj, index: int, restype, argtypes):
    """Call a COM method by vtable index. obj can be c_void_p or int."""
    ptr = obj.value if isinstance(obj, ctypes.c_void_p) else obj
    vtbl = ctypes.cast(ptr, ctypes.POINTER(ctypes.POINTER(ctypes.c_void_p))).contents
    FN = ctypes.WINFUNCTYPE(restype, *argtypes)
    return FN(vtbl[index])

def com_release(obj):
    """IUnknown::Release (slot 2)"""
    if obj:
        ptr = obj.value if isinstance(obj, ctypes.c_void_p) else obj
        if ptr:
            try:
                com_method(ptr, 2, wintypes.ULONG, (ctypes.c_void_p,))(ptr)
            except Exception:
                pass

def com_qi(obj, iid: GUID):
    """IUnknown::QueryInterface (slot 0)"""
    ptr = obj.value if isinstance(obj, ctypes.c_void_p) else obj
    result = ctypes.c_void_p()
    fn = com_method(ptr, 0, wintypes.HRESULT,
                    (ctypes.c_void_p, ctypes.POINTER(GUID), ctypes.POINTER(ctypes.c_void_p)))
    hr = fn(ptr, ctypes.byref(iid), ctypes.byref(result))
    if hr != 0:
        raise RuntimeError(f"QueryInterface failed: 0x{hr & 0xFFFFFFFF:08X}")
    return result

# ============================================================
# HSTRING helper
# ============================================================
_hstring_refs = []  # prevent GC of HSTRING buffers

def create_hstring(s: str) -> HSTRING:
    """Create an HSTRING reference. Buffers are kept alive globally."""
    buf = ctypes.create_unicode_buffer(s)
    hdr = HSTRING_HEADER()
    hs  = HSTRING()
    hr = combase.WindowsCreateStringReference(buf, len(s), ctypes.byref(hdr), ctypes.byref(hs))
    if hr != 0:
        raise RuntimeError(f"WindowsCreateStringReference failed: 0x{hr & 0xFFFFFFFF:08X}")
    _hstring_refs.append((buf, hdr))
    return hs

# ============================================================
# Global objects
# ============================================================
g_hwnd = None

# D3D11 objects
g_device  = ctypes.c_void_p()
g_context = ctypes.c_void_p()
g_swap    = ctypes.c_void_p()   # IDXGISwapChain1 (for Composition)
g_rtv     = ctypes.c_void_p()
g_vs      = ctypes.c_void_p()
g_ps      = ctypes.c_void_p()
g_layout  = ctypes.c_void_p()
g_vb      = ctypes.c_void_p()

# Composition objects
g_dq_controller       = ctypes.c_void_p()
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

g_com_initialized = False

# ============================================================
# HLSL source (same as the original D3D11 sample)
# ============================================================
HLSL_SRC = r"""
struct VS_OUTPUT
{
    float4 position : SV_POSITION;
    float4 color : COLOR0;
};

VS_OUTPUT VS(float4 position : POSITION, float4 color : COLOR)
{
    VS_OUTPUT output = (VS_OUTPUT)0;
    output.position = position;
    output.color = color;
    return output;
}

float4 PS(VS_OUTPUT input) : SV_Target
{
    return input.color;
}
"""

def compile_hlsl(entry: str, target: str) -> ctypes.c_void_p:
    src = HLSL_SRC.encode("utf-8")
    code = ctypes.c_void_p()
    err  = ctypes.c_void_p()
    hr = D3DCompile(
        ctypes.c_char_p(src), len(src), b"embedded.hlsl",
        None, None,
        entry.encode("ascii"), target.encode("ascii"),
        D3DCOMPILE_ENABLE_STRICTNESS, 0,
        ctypes.byref(code), ctypes.byref(err),
    )
    if hr != 0:
        msg = "D3DCompile failed."
        if err:
            p = com_method(err, 3, ctypes.c_void_p, (ctypes.c_void_p,))(err)
            n = com_method(err, 4, ctypes.c_size_t, (ctypes.c_void_p,))(err)
            if p and n:
                msg = ctypes.string_at(p, n).decode("utf-8", "replace")
            com_release(err)
        raise RuntimeError(msg)
    if err:
        com_release(err)
    return code

def blob_ptr(blob) -> ctypes.c_void_p:
    return com_method(blob, 3, ctypes.c_void_p, (ctypes.c_void_p,))(blob)

def blob_size(blob) -> int:
    return com_method(blob, 4, ctypes.c_size_t, (ctypes.c_void_p,))(blob)

# ============================================================
# Step 1: Create D3D11 device + DXGI swap chain for Composition
#
# Unlike the original sample which uses D3D11CreateDeviceAndSwapChain
# with an HWND-bound swap chain, here we:
#   - Create the D3D11 device separately with BGRA support flag
#   - Obtain IDXGIFactory2 via device -> IDXGIDevice -> adapter -> parent
#   - Call CreateSwapChainForComposition (no HWND association)
# ============================================================
def init_d3d():
    global g_device, g_context, g_swap, g_rtv, g_vs, g_ps, g_layout, g_vb
    debug_print("InitD3D: begin")

    # Create D3D11 device (without swap chain)
    feature_levels = (wintypes.UINT * 1)(D3D_FEATURE_LEVEL_11_0)
    created_level = wintypes.UINT(0)

    driver_types = (D3D_DRIVER_TYPE_HARDWARE, D3D_DRIVER_TYPE_WARP, D3D_DRIVER_TYPE_REFERENCE)
    hr = 0
    for dt in driver_types:
        hr = d3d11.D3D11CreateDevice(
            None, dt, None,
            D3D11_CREATE_DEVICE_BGRA_SUPPORT,  # Required for Composition
            feature_levels, 1, D3D11_SDK_VERSION,
            ctypes.byref(g_device), ctypes.byref(created_level), ctypes.byref(g_context),
        )
        if hr == 0:
            debug_print(f"InitD3D: device created (driver_type={dt})")
            break
    if hr != 0:
        raise RuntimeError(f"D3D11CreateDevice failed: 0x{hr & 0xFFFFFFFF:08X}")

    # Obtain IDXGIFactory2 via: device -> IDXGIDevice -> adapter -> factory
    # IDXGIDevice::GetAdapter (slot 7)
    # IDXGIObject::GetParent  (slot 6)
    dxgi_device = com_qi(g_device, IID_IDXGIDevice)

    adapter = ctypes.c_void_p()
    fn = com_method(dxgi_device, 7, wintypes.HRESULT,
                    (ctypes.c_void_p, ctypes.POINTER(ctypes.c_void_p)))
    hr = fn(dxgi_device.value, ctypes.byref(adapter))
    com_release(dxgi_device)
    if hr != 0:
        raise RuntimeError(f"IDXGIDevice::GetAdapter failed: 0x{hr & 0xFFFFFFFF:08X}")

    factory = ctypes.c_void_p()
    fn = com_method(adapter, 6, wintypes.HRESULT,
                    (ctypes.c_void_p, ctypes.POINTER(GUID), ctypes.POINTER(ctypes.c_void_p)))
    hr = fn(adapter.value, ctypes.byref(IID_IDXGIFactory2), ctypes.byref(factory))
    com_release(adapter)
    if hr != 0:
        raise RuntimeError(f"IDXGIAdapter::GetParent failed: 0x{hr & 0xFFFFFFFF:08X}")

    # Create swap chain for Composition (not bound to HWND)
    desc = DXGI_SWAP_CHAIN_DESC1()
    ctypes.memset(ctypes.byref(desc), 0, ctypes.sizeof(desc))
    desc.Width      = WIDTH
    desc.Height     = HEIGHT
    desc.Format     = DXGI_FORMAT_B8G8R8A8_UNORM  # Required for Composition
    desc.SampleDesc.Count = 1
    desc.BufferUsage = DXGI_USAGE_RENDER_TARGET_OUTPUT
    desc.BufferCount = 2
    desc.Scaling    = DXGI_SCALING_STRETCH
    desc.SwapEffect = DXGI_SWAP_EFFECT_FLIP_SEQUENTIAL
    desc.AlphaMode  = DXGI_ALPHA_MODE_PREMULTIPLIED

    # IDXGIFactory2::CreateSwapChainForComposition (slot 24)
    fn = com_method(factory, 24, wintypes.HRESULT,
                    (ctypes.c_void_p, ctypes.c_void_p,
                     ctypes.POINTER(DXGI_SWAP_CHAIN_DESC1),
                     ctypes.c_void_p, ctypes.POINTER(ctypes.c_void_p)))
    hr = fn(factory.value, g_device.value, ctypes.byref(desc),
            None, ctypes.byref(g_swap))
    com_release(factory)
    if hr != 0:
        raise RuntimeError(f"CreateSwapChainForComposition failed: 0x{hr & 0xFFFFFFFF:08X}")
    debug_print("InitD3D: SwapChain for Composition created")

    # Get back buffer -> create RTV
    backbuf = ctypes.c_void_p()
    # IDXGISwapChain::GetBuffer (slot 9)
    fn = com_method(g_swap, 9, wintypes.HRESULT,
                    (ctypes.c_void_p, wintypes.UINT, ctypes.POINTER(GUID),
                     ctypes.POINTER(ctypes.c_void_p)))
    hr = fn(g_swap.value, 0, ctypes.byref(IID_ID3D11Texture2D), ctypes.byref(backbuf))
    if hr != 0:
        raise RuntimeError(f"SwapChain::GetBuffer failed: 0x{hr & 0xFFFFFFFF:08X}")

    # ID3D11Device::CreateRenderTargetView (slot 9)
    fn = com_method(g_device, 9, wintypes.HRESULT,
                    (ctypes.c_void_p, ctypes.c_void_p, ctypes.c_void_p,
                     ctypes.POINTER(ctypes.c_void_p)))
    hr = fn(g_device.value, backbuf.value, None, ctypes.byref(g_rtv))
    com_release(backbuf)
    if hr != 0:
        raise RuntimeError(f"CreateRenderTargetView failed: 0x{hr & 0xFFFFFFFF:08X}")

    # OMSetRenderTargets (context slot 33)
    fn = com_method(g_context, 33, None,
                    (ctypes.c_void_p, wintypes.UINT,
                     ctypes.POINTER(ctypes.c_void_p), ctypes.c_void_p))
    rtv_arr = (ctypes.c_void_p * 1)(g_rtv.value)
    fn(g_context.value, 1, rtv_arr, None)

    # RSSetViewports (context slot 44)
    vp = D3D11_VIEWPORT(0.0, 0.0, float(WIDTH), float(HEIGHT), 0.0, 1.0)
    fn = com_method(g_context, 44, None,
                    (ctypes.c_void_p, wintypes.UINT, ctypes.POINTER(D3D11_VIEWPORT)))
    fn(g_context.value, 1, ctypes.byref(vp))

    # --- Compile shaders ---
    vs_blob = compile_hlsl("VS", "vs_4_0")
    ps_blob = compile_hlsl("PS", "ps_4_0")

    # ID3D11Device::CreateVertexShader (slot 12)
    fn = com_method(g_device, 12, wintypes.HRESULT,
                    (ctypes.c_void_p, ctypes.c_void_p, ctypes.c_size_t,
                     ctypes.c_void_p, ctypes.POINTER(ctypes.c_void_p)))
    hr = fn(g_device.value, blob_ptr(vs_blob), blob_size(vs_blob),
            None, ctypes.byref(g_vs))
    if hr != 0:
        raise RuntimeError(f"CreateVertexShader failed: 0x{hr & 0xFFFFFFFF:08X}")

    # Input layout: POSITION (float3 offset 0), COLOR (float4 offset 12)
    layout = (D3D11_INPUT_ELEMENT_DESC * 2)(
        D3D11_INPUT_ELEMENT_DESC(b"POSITION", 0, DXGI_FORMAT_R32G32B32_FLOAT,
                                  0, 0, D3D11_INPUT_PER_VERTEX_DATA, 0),
        D3D11_INPUT_ELEMENT_DESC(b"COLOR",    0, DXGI_FORMAT_R32G32B32A32_FLOAT,
                                  0, 12, D3D11_INPUT_PER_VERTEX_DATA, 0),
    )

    # ID3D11Device::CreateInputLayout (slot 11)
    fn = com_method(g_device, 11, wintypes.HRESULT,
                    (ctypes.c_void_p, ctypes.POINTER(D3D11_INPUT_ELEMENT_DESC),
                     wintypes.UINT, ctypes.c_void_p, ctypes.c_size_t,
                     ctypes.POINTER(ctypes.c_void_p)))
    hr = fn(g_device.value, layout, 2, blob_ptr(vs_blob), blob_size(vs_blob),
            ctypes.byref(g_layout))
    if hr != 0:
        raise RuntimeError(f"CreateInputLayout failed: 0x{hr & 0xFFFFFFFF:08X}")

    # IASetInputLayout (context slot 17)
    fn = com_method(g_context, 17, None, (ctypes.c_void_p, ctypes.c_void_p))
    fn(g_context.value, g_layout.value)

    # ID3D11Device::CreatePixelShader (slot 15)
    fn = com_method(g_device, 15, wintypes.HRESULT,
                    (ctypes.c_void_p, ctypes.c_void_p, ctypes.c_size_t,
                     ctypes.c_void_p, ctypes.POINTER(ctypes.c_void_p)))
    hr = fn(g_device.value, blob_ptr(ps_blob), blob_size(ps_blob),
            None, ctypes.byref(g_ps))
    if hr != 0:
        raise RuntimeError(f"CreatePixelShader failed: 0x{hr & 0xFFFFFFFF:08X}")

    com_release(vs_blob)
    com_release(ps_blob)

    # --- Vertex buffer ---
    class VERTEX(ctypes.Structure):
        _fields_ = [("x", ctypes.c_float), ("y", ctypes.c_float), ("z", ctypes.c_float),
                     ("r", ctypes.c_float), ("g", ctypes.c_float), ("b", ctypes.c_float),
                     ("a", ctypes.c_float)]

    verts = (VERTEX * 3)(
        VERTEX( 0.0,  0.5, 0.5,  1.0, 0.0, 0.0, 1.0),  # Red   (top)
        VERTEX( 0.5, -0.5, 0.5,  0.0, 1.0, 0.0, 1.0),  # Green (right)
        VERTEX(-0.5, -0.5, 0.5,  0.0, 0.0, 1.0, 1.0),  # Blue  (left)
    )

    bd = D3D11_BUFFER_DESC()
    bd.ByteWidth = ctypes.sizeof(VERTEX) * 3
    bd.Usage     = D3D11_USAGE_DEFAULT
    bd.BindFlags = D3D11_BIND_VERTEX_BUFFER

    init_data = D3D11_SUBRESOURCE_DATA()
    init_data.pSysMem = ctypes.cast(verts, ctypes.c_void_p)

    # ID3D11Device::CreateBuffer (slot 3)
    fn = com_method(g_device, 3, wintypes.HRESULT,
                    (ctypes.c_void_p, ctypes.POINTER(D3D11_BUFFER_DESC),
                     ctypes.POINTER(D3D11_SUBRESOURCE_DATA),
                     ctypes.POINTER(ctypes.c_void_p)))
    hr = fn(g_device.value, ctypes.byref(bd), ctypes.byref(init_data), ctypes.byref(g_vb))
    if hr != 0:
        raise RuntimeError(f"CreateBuffer failed: 0x{hr & 0xFFFFFFFF:08X}")

    # IASetVertexBuffers (context slot 18)
    stride = wintypes.UINT(ctypes.sizeof(VERTEX))
    offset = wintypes.UINT(0)
    vb_arr = (ctypes.c_void_p * 1)(g_vb.value)
    fn = com_method(g_context, 18, None,
                    (ctypes.c_void_p, wintypes.UINT, wintypes.UINT,
                     ctypes.POINTER(ctypes.c_void_p),
                     ctypes.POINTER(wintypes.UINT), ctypes.POINTER(wintypes.UINT)))
    fn(g_context.value, 0, 1, vb_arr, ctypes.byref(stride), ctypes.byref(offset))

    # IASetPrimitiveTopology (context slot 24)
    fn = com_method(g_context, 24, None, (ctypes.c_void_p, wintypes.UINT))
    fn(g_context.value, D3D11_PRIMITIVE_TOPOLOGY_TRIANGLELIST)

    debug_print("InitD3D: ok")

# ============================================================
# Step 2: Initialize DispatcherQueue + Compositor + visual tree
#
# WinRT vtable layout:
#   IUnknown:     0=QI, 1=AddRef, 2=Release
#   IInspectable: 3=GetIids, 4=GetRuntimeClassName, 5=GetTrustLevel
#   Methods:      6+
#
# COM interop interfaces (non-WinRT) inherit from IUnknown only:
#   Methods start at slot 3.
# ============================================================
def init_composition():
    global g_com_initialized, g_dq_controller
    global g_compositor, g_desktop_interop, g_comp_interop
    global g_desktop_target, g_composition_target, g_root_visual
    global g_sprite_visual, g_composition_surface, g_surface_brush
    global g_composition_brush, g_visual, g_visual_collection

    debug_print("InitComposition: begin")

    # COM STA
    hr = ole32.CoInitializeEx(None, COINIT_APARTMENTTHREADED)
    if hr >= 0:
        g_com_initialized = True
    elif (hr & 0xFFFFFFFF) != RPC_E_CHANGED_MODE:
        raise RuntimeError(f"CoInitializeEx failed: 0x{hr & 0xFFFFFFFF:08X}")

    # DispatcherQueue (required for Composition)
    if core_messaging:
        core_messaging.CreateDispatcherQueueController.restype  = wintypes.HRESULT
        core_messaging.CreateDispatcherQueueController.argtypes = (
            DispatcherQueueOptions, ctypes.POINTER(ctypes.c_void_p))
        opt = DispatcherQueueOptions()
        opt.dwSize        = ctypes.sizeof(DispatcherQueueOptions)
        opt.threadType    = DQTYPE_THREAD_CURRENT
        opt.apartmentType = DQTAT_COM_STA
        hr = core_messaging.CreateDispatcherQueueController(
            opt, ctypes.byref(g_dq_controller))
        if hr != 0:
            raise RuntimeError(f"CreateDispatcherQueueController failed: 0x{hr & 0xFFFFFFFF:08X}")
        debug_print("InitComposition: DispatcherQueue ok")

    # Initialize WinRT
    hr = combase.RoInitialize(RO_INIT_SINGLETHREADED)
    if hr < 0 and hr != S_FALSE and (hr & 0xFFFFFFFF) != RPC_E_CHANGED_MODE:
        raise RuntimeError(f"RoInitialize failed: 0x{hr & 0xFFFFFFFF:08X}")

    # Activate Compositor
    hs = create_hstring("Windows.UI.Composition.Compositor")
    inspectable = ctypes.c_void_p()
    hr = combase.RoActivateInstance(hs, ctypes.byref(inspectable))
    if hr != 0:
        raise RuntimeError(f"RoActivateInstance(Compositor) failed: 0x{hr & 0xFFFFFFFF:08X}")
    g_compositor = inspectable
    debug_print("InitComposition: Compositor created")

    # QI -> ICompositorDesktopInterop (COM interop, slots start at 3)
    g_desktop_interop = com_qi(g_compositor, IID_ICompositorDesktopInterop)

    # CreateDesktopWindowTarget(HWND, isTopmost, ppResult) -> slot 3
    g_desktop_target = ctypes.c_void_p()
    fn = com_method(g_desktop_interop, 3, wintypes.HRESULT,
                    (ctypes.c_void_p, wintypes.HWND, wintypes.BOOL,
                     ctypes.POINTER(ctypes.c_void_p)))
    hr = fn(g_desktop_interop.value, g_hwnd, False, ctypes.byref(g_desktop_target))
    if hr != 0:
        raise RuntimeError(f"CreateDesktopWindowTarget failed: 0x{hr & 0xFFFFFFFF:08X}")
    debug_print("InitComposition: DesktopWindowTarget created")

    # QI -> ICompositionTarget, then put_Root
    g_composition_target = com_qi(g_desktop_target, IID_ICompositionTarget)

    # ICompositor::CreateContainerVisual (slot 9)
    g_root_visual = ctypes.c_void_p()
    fn = com_method(g_compositor, 9, wintypes.HRESULT,
                    (ctypes.c_void_p, ctypes.POINTER(ctypes.c_void_p)))
    hr = fn(g_compositor.value, ctypes.byref(g_root_visual))
    if hr != 0:
        raise RuntimeError(f"CreateContainerVisual failed: 0x{hr & 0xFFFFFFFF:08X}")

    # ICompositionTarget::put_Root (slot 7) - expects IVisual*
    root_as_visual = com_qi(g_root_visual, IID_IVisual)
    fn = com_method(g_composition_target, 7, wintypes.HRESULT,
                    (ctypes.c_void_p, ctypes.c_void_p))
    hr = fn(g_composition_target.value, root_as_visual.value)
    com_release(root_as_visual)
    if hr != 0:
        raise RuntimeError(f"put_Root failed: 0x{hr & 0xFFFFFFFF:08X}")
    debug_print("InitComposition: root visual set")

    # QI -> ICompositorInterop (COM interop)
    g_comp_interop = com_qi(g_compositor, IID_ICompositorInterop)

    # CreateCompositionSurfaceForSwapChain(IUnknown*, ppSurface) -> slot 4
    g_composition_surface = ctypes.c_void_p()
    fn = com_method(g_comp_interop, 4, wintypes.HRESULT,
                    (ctypes.c_void_p, ctypes.c_void_p, ctypes.POINTER(ctypes.c_void_p)))
    hr = fn(g_comp_interop.value, g_swap.value, ctypes.byref(g_composition_surface))
    if hr != 0:
        raise RuntimeError(f"CreateCompositionSurfaceForSwapChain failed: 0x{hr & 0xFFFFFFFF:08X}")
    debug_print("InitComposition: CompositionSurface created")

    # ICompositor::CreateSurfaceBrush(surface) -> slot 24
    g_surface_brush = ctypes.c_void_p()
    fn = com_method(g_compositor, 24, wintypes.HRESULT,
                    (ctypes.c_void_p, ctypes.c_void_p, ctypes.POINTER(ctypes.c_void_p)))
    hr = fn(g_compositor.value, g_composition_surface.value, ctypes.byref(g_surface_brush))
    if hr != 0:
        raise RuntimeError(f"CreateSurfaceBrush failed: 0x{hr & 0xFFFFFFFF:08X}")

    # ICompositor::CreateSpriteVisual -> slot 22
    g_sprite_visual = ctypes.c_void_p()
    fn = com_method(g_compositor, 22, wintypes.HRESULT,
                    (ctypes.c_void_p, ctypes.POINTER(ctypes.c_void_p)))
    hr = fn(g_compositor.value, ctypes.byref(g_sprite_visual))
    if hr != 0:
        raise RuntimeError(f"CreateSpriteVisual failed: 0x{hr & 0xFFFFFFFF:08X}")

    # ISpriteVisual::put_Brush (slot 7) - needs ICompositionBrush
    g_composition_brush = com_qi(g_surface_brush, IID_ICompositionBrush)
    fn = com_method(g_sprite_visual, 7, wintypes.HRESULT,
                    (ctypes.c_void_p, ctypes.c_void_p))
    hr = fn(g_sprite_visual.value, g_composition_brush.value)
    if hr != 0:
        raise RuntimeError(f"put_Brush failed: 0x{hr & 0xFFFFFFFF:08X}")
    debug_print("InitComposition: brush set on sprite")

    # IVisual::put_Size (slot 36) - Vector2 by value
    # On x64, Vector2 (8 bytes) is passed in a single register as uint64
    g_visual = com_qi(g_sprite_visual, IID_IVisual)
    packed = struct.pack('ff', float(WIDTH), float(HEIGHT))
    vec2_u64 = struct.unpack('Q', packed)[0]
    fn = com_method(g_visual, 36, wintypes.HRESULT,
                    (ctypes.c_void_p, ctypes.c_uint64))
    hr = fn(g_visual.value, vec2_u64)
    if hr < 0:
        debug_print(f"InitComposition: put_Size hr=0x{hr & 0xFFFFFFFF:08X} (non-fatal)")
    else:
        debug_print(f"InitComposition: size set to {WIDTH}x{HEIGHT}")

    # IContainerVisual::get_Children (slot 6)
    g_visual_collection = ctypes.c_void_p()
    fn = com_method(g_root_visual, 6, wintypes.HRESULT,
                    (ctypes.c_void_p, ctypes.POINTER(ctypes.c_void_p)))
    hr = fn(g_root_visual.value, ctypes.byref(g_visual_collection))
    if hr != 0:
        raise RuntimeError(f"get_Children failed: 0x{hr & 0xFFFFFFFF:08X}")

    # IVisualCollection::InsertAtTop (slot 9)
    sprite_as_visual = com_qi(g_sprite_visual, IID_IVisual)
    fn = com_method(g_visual_collection, 9, wintypes.HRESULT,
                    (ctypes.c_void_p, ctypes.c_void_p))
    hr = fn(g_visual_collection.value, sprite_as_visual.value)
    com_release(sprite_as_visual)
    if hr != 0:
        raise RuntimeError(f"InsertAtTop failed: 0x{hr & 0xFFFFFFFF:08X}")

    debug_print("InitComposition: visual tree complete")

# ============================================================
# Back buffer / RTV binding for flip-model swap chain
# ============================================================
def bind_current_backbuffer():
    global g_rtv

    # With flip-model swap chains, the current back buffer changes after Present.
    # Recreate an RTV for the current buffer and bind it every frame.
    if g_rtv and g_rtv.value:
        com_release(g_rtv)
        g_rtv = ctypes.c_void_p()

    # IDXGISwapChain::GetBuffer (slot 9) for the current back buffer
    backbuf = ctypes.c_void_p()
    fn = com_method(g_swap, 9, wintypes.HRESULT,
                    (ctypes.c_void_p, wintypes.UINT, ctypes.POINTER(GUID),
                     ctypes.POINTER(ctypes.c_void_p)))
    hr = fn(g_swap.value, 0, ctypes.byref(IID_ID3D11Texture2D), ctypes.byref(backbuf))
    if hr != 0:
        raise RuntimeError(f"SwapChain::GetBuffer failed: 0x{hr & 0xFFFFFFFF:08X}")

    # ID3D11Device::CreateRenderTargetView (slot 9)
    fn = com_method(g_device, 9, wintypes.HRESULT,
                    (ctypes.c_void_p, ctypes.c_void_p, ctypes.c_void_p,
                     ctypes.POINTER(ctypes.c_void_p)))
    hr = fn(g_device.value, backbuf.value, None, ctypes.byref(g_rtv))
    com_release(backbuf)
    if hr != 0:
        raise RuntimeError(f"CreateRenderTargetView failed: 0x{hr & 0xFFFFFFFF:08X}")

    # Present unbinds render targets on flip-model swap chains, so bind every frame.
    fn = com_method(g_context, 33, None,
                    (ctypes.c_void_p, wintypes.UINT,
                     ctypes.POINTER(ctypes.c_void_p), ctypes.c_void_p))
    rtv_arr = (ctypes.c_void_p * 1)(g_rtv.value)
    fn(g_context.value, 1, rtv_arr, None)

# ============================================================
# Render
# ============================================================
def render():
    ctx = g_context.value
    if not ctx:
        return

    bind_current_backbuffer()

    # ClearRenderTargetView (context slot 50)
    color = (ctypes.c_float * 4)(1.0, 1.0, 1.0, 1.0)  # White
    fn = com_method(ctx, 50, None,
                    (ctypes.c_void_p, ctypes.c_void_p, ctypes.POINTER(ctypes.c_float)))
    fn(ctx, g_rtv.value, color)

    # VSSetShader (context slot 11)
    fn = com_method(ctx, 11, None,
                    (ctypes.c_void_p, ctypes.c_void_p, ctypes.c_void_p, wintypes.UINT))
    fn(ctx, g_vs.value, None, 0)

    # PSSetShader (context slot 9)
    fn = com_method(ctx, 9, None,
                    (ctypes.c_void_p, ctypes.c_void_p, ctypes.c_void_p, wintypes.UINT))
    fn(ctx, g_ps.value, None, 0)

    # Draw (context slot 13)
    fn = com_method(ctx, 13, None,
                    (ctypes.c_void_p, wintypes.UINT, wintypes.UINT))
    fn(ctx, 3, 0)

    # Present via swap chain (slot 8) - Composition picks this up
    fn = com_method(g_swap, 8, wintypes.HRESULT,
                    (ctypes.c_void_p, wintypes.UINT, wintypes.UINT))
    fn(g_swap.value, 1, 0)

# ============================================================
# Cleanup
# ============================================================
def cleanup():
    debug_print("Cleanup: begin")

    # Release Composition objects (reverse order)
    for obj in [g_visual_collection, g_visual, g_composition_brush,
                g_sprite_visual, g_surface_brush, g_composition_surface,
                g_root_visual, g_composition_target, g_desktop_target,
                g_comp_interop, g_desktop_interop, g_compositor,
                g_dq_controller]:
        com_release(obj)

    # Release D3D11 objects (reverse order)
    for obj in [g_vb, g_layout, g_vs, g_ps, g_rtv, g_swap, g_context, g_device]:
        com_release(obj)

    # Uninitialize WinRT / COM
    try:
        combase.RoUninitialize()
    except Exception:
        pass
    if g_com_initialized:
        try:
            ole32.CoUninitialize()
        except Exception:
            pass

    debug_print("Cleanup: ok")

# ============================================================
# Window procedure
# ============================================================
@WNDPROC
def wndproc(hwnd, msg, wparam, lparam):
    if msg == WM_DESTROY:
        user32.PostQuitMessage(0)
        return 0
    if msg == WM_PAINT:
        return user32.DefWindowProcW(hwnd, msg, wparam, lparam)
    return user32.DefWindowProcW(hwnd, msg, wparam, lparam)

# ============================================================
# Main
# ============================================================
def main():
    global g_hwnd

    debug_print("=== D3D11 Triangle via Windows.UI.Composition (Python) ===")

    hInstance = kernel32.GetModuleHandleW(None)
    class_name = "PyD3D11CompTriangle"

    wc = WNDCLASSEXW()
    wc.cbSize        = ctypes.sizeof(WNDCLASSEXW)
    wc.style         = CS_HREDRAW | CS_VREDRAW
    wc.lpfnWndProc   = wndproc
    wc.hInstance      = hInstance
    wc.hCursor        = user32.LoadCursorW(None, wintypes.LPCWSTR(IDC_ARROW))
    wc.hbrBackground  = 0   # No GDI background - Composition handles rendering
    wc.lpszClassName  = class_name

    if not user32.RegisterClassExW(ctypes.byref(wc)):
        raise winerr()

    # Adjust window rect for desired client area
    style = WS_OVERLAPPEDWINDOW
    rc = RECT(0, 0, WIDTH, HEIGHT)
    user32.AdjustWindowRect(ctypes.byref(rc), style, False)

    # WS_EX_NOREDIRECTIONBITMAP: no GDI surface, Composition provides visuals
    g_hwnd = user32.CreateWindowExW(
        WS_EX_NOREDIRECTIONBITMAP,
        class_name,
        "DirectX 11 Triangle via Windows.UI.Composition (Python)",
        style,
        CW_USEDEFAULT, CW_USEDEFAULT,
        rc.right - rc.left, rc.bottom - rc.top,
        None, None, hInstance, None,
    )
    if not g_hwnd:
        raise winerr()

    user32.ShowWindow(g_hwnd, SW_SHOW)

    try:
        init_d3d()
        init_composition()

        debug_print("=== ENTERING MESSAGE LOOP ===")
        msg = MSG()
        running = True
        while running:
            if user32.PeekMessageW(ctypes.byref(msg), None, 0, 0, PM_REMOVE):
                if msg.message == WM_QUIT:
                    running = False
                else:
                    user32.TranslateMessage(ctypes.byref(msg))
                    user32.DispatchMessageW(ctypes.byref(msg))
            else:
                render()
                kernel32.Sleep(1)

    except Exception as e:
        debug_print(f"FATAL: {e}")
        import traceback
        traceback.print_exc()
    finally:
        cleanup()

if __name__ == "__main__":
    main()
