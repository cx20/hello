import ctypes
from ctypes import wintypes

# ============================================================
# DLLs
# ============================================================
user32   = ctypes.WinDLL("user32", use_last_error=True)
gdi32    = ctypes.WinDLL("gdi32",  use_last_error=True)
kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
ole32    = ctypes.WinDLL("ole32", use_last_error=True)

try:
    d3dcompiler = ctypes.WinDLL("d3dcompiler_47", use_last_error=True)
except OSError:
    d3dcompiler = ctypes.WinDLL("d3dcompiler_43", use_last_error=True)

if not hasattr(wintypes, "HRESULT"):
    wintypes.HRESULT = ctypes.c_long
if not hasattr(wintypes, "SIZE_T"):
    wintypes.SIZE_T = ctypes.c_size_t

for name in ("HICON", "HCURSOR", "HBRUSH"):
    if not hasattr(wintypes, name):
        setattr(wintypes, name, wintypes.HANDLE)

d3d10 = ctypes.WinDLL("d3d10", use_last_error=True)

# ============================================================
# Basic Win32 types / helpers
# ============================================================
LRESULT = wintypes.LPARAM
WNDPROC = ctypes.WINFUNCTYPE(LRESULT, wintypes.HWND, wintypes.UINT, wintypes.WPARAM, wintypes.LPARAM)

def winerr():
    return ctypes.WinError(ctypes.get_last_error())

# ============================================================
# Win32 constants
# ============================================================
CS_HREDRAW = 0x0002
CS_VREDRAW = 0x0001
WS_OVERLAPPEDWINDOW = 0x00CF0000
CW_USEDEFAULT = 0x80000000
SW_SHOW = 5

WM_DESTROY = 0x0002
WM_PAINT   = 0x000F
WM_QUIT    = 0x0012

PM_REMOVE  = 0x0001

IDC_ARROW = 32512

# ============================================================
# D3D11 / DXGI constants (minimum)
# ============================================================
D3D11_SDK_VERSION = 7

# D3D_DRIVER_TYPE
D3D_DRIVER_TYPE_HARDWARE  = 1
D3D_DRIVER_TYPE_REFERENCE = 2
D3D_DRIVER_TYPE_WARP      = 5

# D3D_FEATURE_LEVEL
D3D_FEATURE_LEVEL_11_0 = 0xB000

# DXGI_FORMAT
DXGI_FORMAT_R8G8B8A8_UNORM     = 28
DXGI_FORMAT_R32G32B32_FLOAT    = 6
DXGI_FORMAT_R32G32B32A32_FLOAT = 2

DXGI_USAGE_RENDER_TARGET_OUTPUT = 0x00000020

# D3D10
D3D10_SDK_VERSION = 29
D3D10_USAGE_DEFAULT       = 0
D3D10_BIND_VERTEX_BUFFER  = 0x00000001
D3D10_INPUT_PER_VERTEX_DATA = 0

D3D10_PRIMITIVE_TOPOLOGY_TRIANGLELIST = 4

# Shader compile flags
D3DCOMPILE_ENABLE_STRICTNESS = 0x00000002

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

class DXGI_RATIONAL(ctypes.Structure):
    _fields_ = [("Numerator", wintypes.UINT), ("Denominator", wintypes.UINT)]

class DXGI_MODE_DESC(ctypes.Structure):
    _fields_ = [
        ("Width", wintypes.UINT),
        ("Height", wintypes.UINT),
        ("RefreshRate", DXGI_RATIONAL),
        ("Format", wintypes.UINT),
        ("ScanlineOrdering", wintypes.UINT),
        ("Scaling", wintypes.UINT),
    ]

class DXGI_SAMPLE_DESC(ctypes.Structure):
    _fields_ = [("Count", wintypes.UINT), ("Quality", wintypes.UINT)]

class DXGI_SWAP_CHAIN_DESC(ctypes.Structure):
    _fields_ = [
        ("BufferDesc", DXGI_MODE_DESC),
        ("SampleDesc", DXGI_SAMPLE_DESC),
        ("BufferUsage", wintypes.UINT),
        ("BufferCount", wintypes.UINT),
        ("OutputWindow", wintypes.HWND),
        ("Windowed", wintypes.BOOL),
        ("SwapEffect", wintypes.UINT),
        ("Flags", wintypes.UINT),
    ]

class D3D10_VIEWPORT(ctypes.Structure):
    _fields_ = [
        ("TopLeftX", ctypes.c_int),
        ("TopLeftY", ctypes.c_int),
        ("Width",    wintypes.UINT),
        ("Height",   wintypes.UINT),
        ("MinDepth", ctypes.c_float),
        ("MaxDepth", ctypes.c_float),
    ]

class D3D10_BUFFER_DESC(ctypes.Structure):
    _fields_ = [
        ("ByteWidth", wintypes.UINT),
        ("Usage", wintypes.UINT),
        ("BindFlags", wintypes.UINT),
        ("CPUAccessFlags", wintypes.UINT),
        ("MiscFlags", wintypes.UINT),
    ]

class D3D10_SUBRESOURCE_DATA(ctypes.Structure):
    _fields_ = [
        ("pSysMem", ctypes.c_void_p),
        ("SysMemPitch", wintypes.UINT),
        ("SysMemSlicePitch", wintypes.UINT),
    ]

class D3D10_INPUT_ELEMENT_DESC(ctypes.Structure):
    _fields_ = [
        ("SemanticName", ctypes.c_char_p),
        ("SemanticIndex", wintypes.UINT),
        ("Format", wintypes.UINT),
        ("InputSlot", wintypes.UINT),
        ("AlignedByteOffset", wintypes.UINT),
        ("InputSlotClass", wintypes.UINT),
        ("InstanceDataStepRate", wintypes.UINT),
    ]

class GUID(ctypes.Structure):
    _fields_ = [
        ("Data1", wintypes.DWORD),
        ("Data2", wintypes.WORD),
        ("Data3", wintypes.WORD),
        ("Data4", ctypes.c_ubyte * 8),
    ]

def guid_from_str(s: str) -> GUID:
    # "{xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx}"
    import uuid
    u = uuid.UUID(s)
    b = u.bytes_le
    g = GUID()
    ctypes.memmove(ctypes.byref(g), b, ctypes.sizeof(g))
    return g

# IID_ID3D10Texture2D
IID_ID3D10Texture2D = guid_from_str("{9B7E4C04-342C-4106-A19F-4F2704F689F0}")

# ============================================================
# Win32 prototypes
# ============================================================
kernel32.GetModuleHandleW.restype = wintypes.HMODULE
kernel32.GetModuleHandleW.argtypes = (wintypes.LPCWSTR,)

kernel32.Sleep.restype = None
kernel32.Sleep.argtypes = (wintypes.DWORD,)

user32.DefWindowProcW.restype = LRESULT
user32.DefWindowProcW.argtypes = (wintypes.HWND, wintypes.UINT, wintypes.WPARAM, wintypes.LPARAM)

user32.RegisterClassExW.restype = wintypes.ATOM
user32.RegisterClassExW.argtypes = (ctypes.POINTER(WNDCLASSEXW),)

user32.CreateWindowExW.restype = wintypes.HWND
user32.CreateWindowExW.argtypes = (
    wintypes.DWORD, wintypes.LPCWSTR, wintypes.LPCWSTR, wintypes.DWORD,
    ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_int,
    wintypes.HWND, wintypes.HMENU, wintypes.HINSTANCE, wintypes.LPVOID
)

user32.ShowWindow.restype = wintypes.BOOL
user32.ShowWindow.argtypes = (wintypes.HWND, ctypes.c_int)

user32.PeekMessageW.restype = wintypes.BOOL
user32.PeekMessageW.argtypes = (ctypes.POINTER(MSG), wintypes.HWND, wintypes.UINT, wintypes.UINT, wintypes.UINT)

user32.TranslateMessage.restype = wintypes.BOOL
user32.TranslateMessage.argtypes = (ctypes.POINTER(MSG),)

user32.DispatchMessageW.restype = LRESULT
user32.DispatchMessageW.argtypes = (ctypes.POINTER(MSG),)

user32.PostQuitMessage.restype = None
user32.PostQuitMessage.argtypes = (ctypes.c_int,)

user32.LoadCursorW.restype = wintypes.HCURSOR
user32.LoadCursorW.argtypes = (wintypes.HINSTANCE, wintypes.LPCWSTR)

user32.GetClientRect.restype = wintypes.BOOL
user32.GetClientRect.argtypes = (wintypes.HWND, ctypes.POINTER(RECT))

user32.GetDC.restype = wintypes.HDC
user32.GetDC.argtypes = (wintypes.HWND,)

# ============================================================
# D3D / Compiler prototypes
# ============================================================
# HRESULT D3D10CreateDeviceAndSwapChain(...)
D3D10CreateDeviceAndSwapChain = d3d10.D3D10CreateDeviceAndSwapChain
D3D10CreateDeviceAndSwapChain.restype = wintypes.HRESULT
D3D10CreateDeviceAndSwapChain.argtypes = (
    ctypes.c_void_p,         # IDXGIAdapter* (NULL)
    wintypes.UINT,           # D3D_DRIVER_TYPE
    wintypes.HMODULE,        # Software
    wintypes.UINT,           # Flags
    wintypes.UINT,           # SDKVersion
    ctypes.POINTER(DXGI_SWAP_CHAIN_DESC),  # SwapChainDesc
    ctypes.POINTER(ctypes.c_void_p), # IDXGISwapChain**
    ctypes.POINTER(ctypes.c_void_p), # ID3D10Device**
)

# ============================================================
# D3D / Compiler prototypes
# ============================================================
# HRESULT D3D10CreateDeviceAndSwapChain(...)
D3D10CreateDeviceAndSwapChain = d3d10.D3D10CreateDeviceAndSwapChain
D3D10CreateDeviceAndSwapChain.restype = wintypes.HRESULT
D3D10CreateDeviceAndSwapChain.argtypes = (
    ctypes.c_void_p,         # IDXGIAdapter* (NULL)
    wintypes.UINT,           # D3D_DRIVER_TYPE
    wintypes.HMODULE,        # Software
    wintypes.UINT,           # Flags
    wintypes.UINT,           # SDKVersion
    ctypes.POINTER(DXGI_SWAP_CHAIN_DESC),  # SwapChainDesc
    ctypes.POINTER(ctypes.c_void_p), # IDXGISwapChain**
    ctypes.POINTER(ctypes.c_void_p), # ID3D10Device**
)

# HRESULT D3DCompile(...)
D3DCompile = d3dcompiler.D3DCompile
D3DCompile.restype = wintypes.HRESULT
D3DCompile.argtypes = (
    ctypes.c_void_p, wintypes.SIZE_T, ctypes.c_char_p,  # src, size, sourceName
    ctypes.c_void_p, ctypes.c_void_p,                   # defines, include
    ctypes.c_char_p, ctypes.c_char_p,                   # entry, target
    wintypes.UINT, wintypes.UINT,                       # flags1, flags2
    ctypes.POINTER(ctypes.c_void_p), ctypes.POINTER(ctypes.c_void_p)  # code blob, error blob
)

# ============================================================
# COM vtable caller (no comtypes)
# ============================================================
def com_method(obj: ctypes.c_void_p, index: int, restype, argtypes):
    """
    obj: COM interface pointer (void*)
    index: vtable index
    """
    vtbl = ctypes.cast(obj, ctypes.POINTER(ctypes.POINTER(ctypes.c_void_p))).contents
    fn_addr = vtbl[index]
    FN = ctypes.WINFUNCTYPE(restype, *argtypes)
    return FN(fn_addr)

def com_release(obj_ref: ctypes.c_void_p):
    if obj_ref:
        try:
            com_method(obj_ref, 2, wintypes.ULONG, (ctypes.c_void_p,))(obj_ref)
        except Exception:
            pass

# ============================================================
# Global D3D objects (void* pointers)
# ============================================================
g_hwnd = None
g_hdc  = None

g_device   = ctypes.c_void_p()
g_swap     = ctypes.c_void_p()
g_rtv      = ctypes.c_void_p()
g_vs       = ctypes.c_void_p()
g_ps       = ctypes.c_void_p()
g_layout   = ctypes.c_void_p()
g_vb       = ctypes.c_void_p()

# ============================================================
# HLSL source
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
        ctypes.c_char_p(src),
        len(src),
        b"embedded.hlsl",
        None,
        None,
        entry.encode("ascii"),
        target.encode("ascii"),
        D3DCOMPILE_ENABLE_STRICTNESS,
        0,
        ctypes.byref(code),
        ctypes.byref(err),
    )
    if hr != 0:  # FAILED
        msg = "D3DCompile failed."
        if err:
            # ID3DBlob: GetBufferPointer (#3), GetBufferSize (#4), Release (#2)
            get_ptr = com_method(err, 3, ctypes.c_void_p, (ctypes.c_void_p,))
            get_sz  = com_method(err, 4, ctypes.c_size_t, (ctypes.c_void_p,))
            p = get_ptr(err)
            n = get_sz(err)
            if p and n:
                msg = ctypes.string_at(p, n).decode("utf-8", "replace")
            com_release(err)
        raise RuntimeError(msg)
    if err:
        com_release(err)
    return code

def blob_ptr(blob: ctypes.c_void_p) -> ctypes.c_void_p:
    return com_method(blob, 3, ctypes.c_void_p, (ctypes.c_void_p,))(blob)

def blob_size(blob: ctypes.c_void_p) -> int:
    return com_method(blob, 4, ctypes.c_size_t, (ctypes.c_void_p,))(blob)

# ============================================================
# D3D init
# ============================================================
def init_d3d():
    global g_device, g_swap, g_rtv, g_vs, g_ps, g_layout, g_vb

    rc = RECT()
    if not user32.GetClientRect(g_hwnd, ctypes.byref(rc)):
        raise winerr()
    width  = rc.right - rc.left
    height = rc.bottom - rc.top

    sd = DXGI_SWAP_CHAIN_DESC()
    sd.BufferCount = 1
    sd.BufferDesc.Width  = width
    sd.BufferDesc.Height = height
    sd.BufferDesc.RefreshRate.Numerator   = 60
    sd.BufferDesc.RefreshRate.Denominator = 1
    sd.BufferDesc.Format = DXGI_FORMAT_R8G8B8A8_UNORM
    sd.BufferUsage = DXGI_USAGE_RENDER_TARGET_OUTPUT
    sd.OutputWindow = g_hwnd
    sd.SampleDesc.Count = 1
    sd.SampleDesc.Quality = 0
    sd.Windowed = True
    sd.SwapEffect = 0
    sd.Flags = 0

    driver_types = (D3D_DRIVER_TYPE_HARDWARE, D3D_DRIVER_TYPE_WARP, D3D_DRIVER_TYPE_REFERENCE)
    hr = wintypes.HRESULT(0)

    for dt in driver_types:
        hr = D3D10CreateDeviceAndSwapChain(
            None,
            dt,
            None,
            0,
            D3D10_SDK_VERSION,
            ctypes.byref(sd),
            ctypes.byref(g_swap),
            ctypes.byref(g_device),
        )
        if hr == 0:
            break
    if hr != 0:
        raise RuntimeError(f"D3D10CreateDeviceAndSwapChain failed: HRESULT=0x{hr & 0xFFFFFFFF:08X}")

    # back buffer -> RTV
    backbuf = ctypes.c_void_p()

    # IDXGISwapChain::GetBuffer index = 9
    get_buffer = com_method(g_swap, 9, wintypes.HRESULT, (ctypes.c_void_p, wintypes.UINT, ctypes.POINTER(GUID), ctypes.POINTER(ctypes.c_void_p)))
    hr = get_buffer(g_swap, 0, ctypes.byref(IID_ID3D10Texture2D), ctypes.byref(backbuf))
    if hr != 0:
        raise RuntimeError(f"SwapChain.GetBuffer failed: HRESULT=0x{hr & 0xFFFFFFFF:08X}")

    # ID3D10Device::CreateRenderTargetView index = 76
    create_rtv = com_method(g_device, 76, wintypes.HRESULT, (ctypes.c_void_p, ctypes.c_void_p, ctypes.c_void_p, ctypes.POINTER(ctypes.c_void_p)))
    hr = create_rtv(g_device, backbuf, None, ctypes.byref(g_rtv))
    com_release(backbuf)
    if hr != 0:
        raise RuntimeError(f"Device.CreateRenderTargetView failed: HRESULT=0x{hr & 0xFFFFFFFF:08X}")

    # OMSetRenderTargets (device index 24)
    om_set = com_method(g_device, 24, None, (ctypes.c_void_p, wintypes.UINT, ctypes.POINTER(ctypes.c_void_p), ctypes.c_void_p))
    rtv_arr = (ctypes.c_void_p * 1)(g_rtv.value)
    om_set(g_device, 1, rtv_arr, None)

    # RSSetViewports (device index 30)
    rs_vp = com_method(g_device, 30, None, (ctypes.c_void_p, wintypes.UINT, ctypes.POINTER(D3D10_VIEWPORT)))
    vp = D3D10_VIEWPORT(0, 0, width, height, 0.0, 1.0)
    rs_vp(g_device, 1, ctypes.byref(vp))

    # --- Shaders ---
    vs_blob = compile_hlsl("VS", "vs_4_0")
    ps_blob = compile_hlsl("PS", "ps_4_0")

    # ID3D10Device::CreateVertexShader index = 79
    create_vs = com_method(g_device, 79, wintypes.HRESULT, (ctypes.c_void_p, ctypes.c_void_p, ctypes.c_size_t, ctypes.POINTER(ctypes.c_void_p)))
    hr = create_vs(g_device, blob_ptr(vs_blob), blob_size(vs_blob), ctypes.byref(g_vs))
    if hr != 0:
        raise RuntimeError(f"Device.CreateVertexShader failed: HRESULT=0x{hr & 0xFFFFFFFF:08X}")

    # input layout
    # POSITION: float3 offset 0, COLOR: float4 offset 12
    POSITION = b"POSITION"
    COLOR    = b"COLOR"
    layout = (D3D10_INPUT_ELEMENT_DESC * 2)(
        D3D10_INPUT_ELEMENT_DESC(POSITION, 0, DXGI_FORMAT_R32G32B32_FLOAT,    0,  0, D3D10_INPUT_PER_VERTEX_DATA, 0),
        D3D10_INPUT_ELEMENT_DESC(COLOR,    0, DXGI_FORMAT_R32G32B32A32_FLOAT, 0, 12, D3D10_INPUT_PER_VERTEX_DATA, 0),
    )

    # ID3D10Device::CreateInputLayout index = 78
    create_il = com_method(g_device, 78, wintypes.HRESULT, (ctypes.c_void_p,
                                                           ctypes.POINTER(D3D10_INPUT_ELEMENT_DESC), wintypes.UINT,
                                                           ctypes.c_void_p, ctypes.c_size_t,
                                                           ctypes.POINTER(ctypes.c_void_p)))
    hr = create_il(g_device, layout, 2, blob_ptr(vs_blob), blob_size(vs_blob), ctypes.byref(g_layout))
    if hr != 0:
        raise RuntimeError(f"Device.CreateInputLayout failed: HRESULT=0x{hr & 0xFFFFFFFF:08X}")

    # IASetInputLayout (device index 11)
    ia_layout = com_method(g_device, 11, None, (ctypes.c_void_p, ctypes.c_void_p))
    ia_layout(g_device, g_layout)

    # pixel shader
    # ID3D10Device::CreatePixelShader index = 82
    create_ps = com_method(g_device, 82, wintypes.HRESULT, (ctypes.c_void_p, ctypes.c_void_p, ctypes.c_size_t, ctypes.POINTER(ctypes.c_void_p)))
    hr = create_ps(g_device, blob_ptr(ps_blob), blob_size(ps_blob), ctypes.byref(g_ps))
    if hr != 0:
        raise RuntimeError(f"Device.CreatePixelShader failed: HRESULT=0x{hr & 0xFFFFFFFF:08X}")

    # blobs release
    com_release(vs_blob)
    com_release(ps_blob)

    # --- Vertex buffer ---
    class VERTEX(ctypes.Structure):
        _fields_ = [("x", ctypes.c_float), ("y", ctypes.c_float), ("z", ctypes.c_float),
                    ("r", ctypes.c_float), ("g", ctypes.c_float), ("b", ctypes.c_float), ("a", ctypes.c_float)]

    verts = (VERTEX * 3)(
        VERTEX( 0.0,  0.5, 0.5, 1.0, 0.0, 0.0, 1.0),
        VERTEX( 0.5, -0.5, 0.5, 0.0, 1.0, 0.0, 1.0),
        VERTEX(-0.5, -0.5, 0.5, 0.0, 0.0, 1.0, 1.0),
    )

    bd = D3D10_BUFFER_DESC()
    bd.Usage = D3D10_USAGE_DEFAULT
    bd.ByteWidth = ctypes.sizeof(VERTEX) * 3
    bd.BindFlags = D3D10_BIND_VERTEX_BUFFER
    bd.CPUAccessFlags = 0
    bd.MiscFlags = 0

    init_data = D3D10_SUBRESOURCE_DATA()
    init_data.pSysMem = ctypes.cast(verts, ctypes.c_void_p)
    init_data.SysMemPitch = 0
    init_data.SysMemSlicePitch = 0

    # ID3D10Device::CreateBuffer index = 71
    create_buf = com_method(g_device, 71, wintypes.HRESULT, (ctypes.c_void_p, ctypes.POINTER(D3D10_BUFFER_DESC),
                                                           ctypes.POINTER(D3D10_SUBRESOURCE_DATA),
                                                           ctypes.POINTER(ctypes.c_void_p)))
    hr = create_buf(g_device, ctypes.byref(bd), ctypes.byref(init_data), ctypes.byref(g_vb))
    if hr != 0:
        raise RuntimeError(f"Device.CreateBuffer failed: HRESULT=0x{hr & 0xFFFFFFFF:08X}")

    # IASetVertexBuffers (device index 12)
    ia_vb = com_method(g_device, 12, None, (ctypes.c_void_p, wintypes.UINT, wintypes.UINT,
                                            ctypes.POINTER(ctypes.c_void_p),
                                            ctypes.POINTER(wintypes.UINT),
                                            ctypes.POINTER(wintypes.UINT)))
    stride = wintypes.UINT(ctypes.sizeof(VERTEX))
    offset = wintypes.UINT(0)
    vb_arr = (ctypes.c_void_p * 1)(g_vb.value)
    ia_vb(g_device, 0, 1, vb_arr, ctypes.byref(stride), ctypes.byref(offset))

    # IASetPrimitiveTopology (device index 18)
    ia_topo = com_method(g_device, 18, None, (ctypes.c_void_p, wintypes.UINT))
    ia_topo(g_device, D3D10_PRIMITIVE_TOPOLOGY_TRIANGLELIST)

def cleanup_d3d():
    # 生成順と逆に Release（ClearState は vtable が長いので省略）
    global g_vb, g_layout, g_vs, g_ps, g_rtv, g_swap, g_device
    com_release(g_vb);     g_vb     = ctypes.c_void_p()
    com_release(g_layout); g_layout = ctypes.c_void_p()
    com_release(g_vs);     g_vs     = ctypes.c_void_p()
    com_release(g_ps);     g_ps     = ctypes.c_void_p()
    com_release(g_rtv);    g_rtv    = ctypes.c_void_p()
    com_release(g_swap);   g_swap   = ctypes.c_void_p()
    com_release(g_device); g_device = ctypes.c_void_p()

def render():
    # ClearRenderTargetView (device index 35)
    clear_rtv = com_method(g_device, 35, None, (ctypes.c_void_p, ctypes.c_void_p, ctypes.POINTER(ctypes.c_float)))
    color = (ctypes.c_float * 4)(1.0, 1.0, 1.0, 1.0)
    clear_rtv(g_device, g_rtv, color)

    # VSSetShader (device index 7), PSSetShader (device index 5)
    vs_set = com_method(g_device, 7, None, (ctypes.c_void_p, ctypes.c_void_p))
    ps_set = com_method(g_device, 5,  None, (ctypes.c_void_p, ctypes.c_void_p))
    vs_set(g_device, g_vs)
    ps_set(g_device, g_ps)

    # Draw (device index 9)
    draw = com_method(g_device, 9, None, (ctypes.c_void_p, wintypes.UINT, wintypes.UINT))
    draw(g_device, 3, 0)

    # Present (swapchain index 8)
    present = com_method(g_swap, 8, wintypes.HRESULT, (ctypes.c_void_p, wintypes.UINT, wintypes.UINT))
    present(g_swap, 0, 0)

# ============================================================
# Window procedure
# ============================================================
@WNDPROC
def wndproc(hwnd, msg, wparam, lparam):
    if msg == WM_PAINT:
        return user32.DefWindowProcW(hwnd, msg, wparam, lparam)
    if msg == WM_DESTROY:
        user32.PostQuitMessage(0)
        return 0
    return user32.DefWindowProcW(hwnd, msg, wparam, lparam)

# ============================================================
# Main
# ============================================================
def main():
    global g_hwnd, g_hdc

    ole32.CoInitialize(None)

    hInstance = kernel32.GetModuleHandleW(None)
    class_name = "PyDx10Raw"

    wc = WNDCLASSEXW()
    wc.cbSize = ctypes.sizeof(WNDCLASSEXW)
    wc.style = CS_HREDRAW | CS_VREDRAW
    wc.lpfnWndProc = wndproc
    wc.hInstance = hInstance
    wc.hCursor = user32.LoadCursorW(None, wintypes.LPCWSTR(IDC_ARROW))
    wc.hbrBackground = 0
    wc.lpszClassName = class_name

    if not user32.RegisterClassExW(ctypes.byref(wc)):
        raise winerr()

    g_hwnd = user32.CreateWindowExW(
        0,
        class_name,
        "DirectX10 Triangle (ctypes only)",
        WS_OVERLAPPEDWINDOW,
        CW_USEDEFAULT, CW_USEDEFAULT,
        640, 480,
        None, None, hInstance, None
    )
    if not g_hwnd:
        raise winerr()

    user32.ShowWindow(g_hwnd, SW_SHOW)

    g_hdc = user32.GetDC(g_hwnd)
    if not g_hdc:
        raise winerr()

    init_d3d()

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

    cleanup_d3d()
    if g_hdc and g_hwnd:
        user32.ReleaseDC(g_hwnd, g_hdc)

    ole32.CoUninitialize()

if __name__ == "__main__":
    main()
