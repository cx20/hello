import ctypes
from ctypes import wintypes

# ============================================================
# DLLs
# ============================================================
user32   = ctypes.WinDLL("user32", use_last_error=True)
kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
d3d9     = ctypes.WinDLL("d3d9", use_last_error=True)

if not hasattr(wintypes, "HRESULT"):
    wintypes.HRESULT = ctypes.c_long

for name in ("HICON", "HCURSOR", "HBRUSH"):
    if not hasattr(wintypes, name):
        setattr(wintypes, name, wintypes.HANDLE)

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
WM_QUIT    = 0x0012

PM_REMOVE  = 0x0001

IDC_ARROW = 32512

# ============================================================
# DirectX 9 constants
# ============================================================
D3D_SDK_VERSION = 32

D3DADAPTER_DEFAULT = 0
D3DDEVTYPE_HAL = 1
D3DCREATE_SOFTWARE_VERTEXPROCESSING = 0x00000020

D3DFMT_UNKNOWN = 0
D3DSWAPEFFECT_DISCARD = 1
D3DMULTISAMPLE_NONE = 0
D3DPOOL_DEFAULT = 0

D3DCLEAR_TARGET = 0x00000001
D3DPT_TRIANGLELIST = 4

# FVF flags
D3DFVF_XYZRHW  = 0x004
D3DFVF_DIFFUSE = 0x040
D3DFVF_VERTEX  = D3DFVF_XYZRHW | D3DFVF_DIFFUSE

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

class D3DPRESENT_PARAMETERS(ctypes.Structure):
    _fields_ = [
        ("BackBufferWidth",            wintypes.UINT),
        ("BackBufferHeight",           wintypes.UINT),
        ("BackBufferFormat",           wintypes.UINT),
        ("BackBufferCount",            wintypes.UINT),
        ("MultiSampleType",            wintypes.UINT),
        ("MultiSampleQuality",         wintypes.DWORD),
        ("SwapEffect",                 wintypes.UINT),
        ("hDeviceWindow",              wintypes.HWND),
        ("Windowed",                   wintypes.BOOL),
        ("EnableAutoDepthStencil",     wintypes.BOOL),
        ("AutoDepthStencilFormat",     wintypes.UINT),
        ("Flags",                      wintypes.DWORD),
        ("FullScreen_RefreshRateInHz", wintypes.UINT),
        ("PresentationInterval",       wintypes.UINT),
    ]

# Vertex structure (transformed with diffuse color)
class VERTEX(ctypes.Structure):
    _fields_ = [
        ("x",     ctypes.c_float),
        ("y",     ctypes.c_float),
        ("z",     ctypes.c_float),
        ("rhw",   ctypes.c_float),
        ("color", wintypes.DWORD),
    ]

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

user32.UpdateWindow.restype = wintypes.BOOL
user32.UpdateWindow.argtypes = (wintypes.HWND,)

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

# ============================================================
# D3D9 prototypes
# ============================================================
Direct3DCreate9 = d3d9.Direct3DCreate9
Direct3DCreate9.restype = ctypes.c_void_p
Direct3DCreate9.argtypes = (wintypes.UINT,)

# ============================================================
# D3DCOLOR_XRGB macro replacement
# ============================================================
def D3DCOLOR_XRGB(r, g, b):
    return 0xFF000000 | (r << 16) | (g << 8) | b

# ============================================================
# COM vtable caller
# ============================================================
def com_method(obj, index, restype, argtypes):
    """
    obj: COM interface pointer (void*)
    index: vtable index
    """
    vtbl = ctypes.cast(obj, ctypes.POINTER(ctypes.POINTER(ctypes.c_void_p))).contents
    fn_addr = vtbl[index]
    FN = ctypes.WINFUNCTYPE(restype, *argtypes)
    return FN(fn_addr)

def com_release(obj_ref):
    if obj_ref:
        try:
            com_method(obj_ref, 2, wintypes.ULONG, (ctypes.c_void_p,))(obj_ref)
        except Exception:
            pass

# ============================================================
# Global D3D objects (void* pointers)
# ============================================================
g_hwnd = None
g_pD3D = ctypes.c_void_p()
g_pd3dDevice = ctypes.c_void_p()
g_pVB = ctypes.c_void_p()

# ============================================================
# D3D9 COM vtable indices
# ============================================================
# IDirect3D9
IDirect3D9_CreateDevice = 16

# IDirect3DDevice9
IDirect3DDevice9_Present = 17
IDirect3DDevice9_CreateVertexBuffer = 26
IDirect3DDevice9_BeginScene = 41
IDirect3DDevice9_EndScene = 42
IDirect3DDevice9_Clear = 43
IDirect3DDevice9_DrawPrimitive = 81
IDirect3DDevice9_SetFVF = 89
IDirect3DDevice9_SetStreamSource = 100

# IDirect3DVertexBuffer9
IDirect3DVertexBuffer9_Lock = 11
IDirect3DVertexBuffer9_Unlock = 12

# ============================================================
# D3D init
# ============================================================
def init_d3d():
    global g_pD3D, g_pd3dDevice

    # Create Direct3D9 object
    g_pD3D.value = Direct3DCreate9(D3D_SDK_VERSION)
    if not g_pD3D.value:
        raise RuntimeError("Direct3DCreate9 failed")

    # Set up present parameters
    d3dpp = D3DPRESENT_PARAMETERS()
    ctypes.memset(ctypes.byref(d3dpp), 0, ctypes.sizeof(d3dpp))
    d3dpp.Windowed = True
    d3dpp.SwapEffect = D3DSWAPEFFECT_DISCARD
    d3dpp.BackBufferFormat = D3DFMT_UNKNOWN
    d3dpp.hDeviceWindow = g_hwnd

    # IDirect3D9::CreateDevice
    create_device = com_method(g_pD3D, IDirect3D9_CreateDevice, wintypes.HRESULT,
        (ctypes.c_void_p, wintypes.UINT, wintypes.UINT, wintypes.HWND, wintypes.DWORD,
         ctypes.POINTER(D3DPRESENT_PARAMETERS), ctypes.POINTER(ctypes.c_void_p)))

    hr = create_device(g_pD3D, D3DADAPTER_DEFAULT, D3DDEVTYPE_HAL, g_hwnd,
                       D3DCREATE_SOFTWARE_VERTEXPROCESSING,
                       ctypes.byref(d3dpp), ctypes.byref(g_pd3dDevice))
    if hr != 0:
        raise RuntimeError(f"IDirect3D9::CreateDevice failed: HRESULT=0x{hr & 0xFFFFFFFF:08X}")

def init_vb():
    global g_pVB

    # Define triangle vertices
    vertices = (VERTEX * 3)(
        VERTEX(320.0, 100.0, 0.0, 1.0, D3DCOLOR_XRGB(255, 0, 0)),   # Red
        VERTEX(520.0, 380.0, 0.0, 1.0, D3DCOLOR_XRGB(0, 255, 0)),   # Green
        VERTEX(120.0, 380.0, 0.0, 1.0, D3DCOLOR_XRGB(0, 0, 255)),   # Blue
    )

    # IDirect3DDevice9::CreateVertexBuffer
    create_vb = com_method(g_pd3dDevice, IDirect3DDevice9_CreateVertexBuffer, wintypes.HRESULT,
        (ctypes.c_void_p, wintypes.UINT, wintypes.DWORD, wintypes.DWORD, wintypes.UINT,
         ctypes.POINTER(ctypes.c_void_p), ctypes.c_void_p))

    hr = create_vb(g_pd3dDevice, 3 * ctypes.sizeof(VERTEX), 0, D3DFVF_VERTEX,
                   D3DPOOL_DEFAULT, ctypes.byref(g_pVB), None)
    if hr != 0:
        raise RuntimeError(f"CreateVertexBuffer failed: HRESULT=0x{hr & 0xFFFFFFFF:08X}")

    # IDirect3DVertexBuffer9::Lock
    lock = com_method(g_pVB, IDirect3DVertexBuffer9_Lock, wintypes.HRESULT,
        (ctypes.c_void_p, wintypes.UINT, wintypes.UINT, ctypes.POINTER(ctypes.c_void_p), wintypes.DWORD))

    p_vertices = ctypes.c_void_p()
    hr = lock(g_pVB, 0, ctypes.sizeof(vertices), ctypes.byref(p_vertices), 0)
    if hr != 0:
        raise RuntimeError(f"Lock failed: HRESULT=0x{hr & 0xFFFFFFFF:08X}")

    # Copy vertex data
    ctypes.memmove(p_vertices, ctypes.byref(vertices), ctypes.sizeof(vertices))

    # IDirect3DVertexBuffer9::Unlock
    unlock = com_method(g_pVB, IDirect3DVertexBuffer9_Unlock, wintypes.HRESULT,
        (ctypes.c_void_p,))
    unlock(g_pVB)

def cleanup():
    global g_pVB, g_pd3dDevice, g_pD3D

    if g_pVB.value:
        com_release(g_pVB)
        g_pVB = ctypes.c_void_p()

    if g_pd3dDevice.value:
        com_release(g_pd3dDevice)
        g_pd3dDevice = ctypes.c_void_p()

    if g_pD3D.value:
        com_release(g_pD3D)
        g_pD3D = ctypes.c_void_p()

def render():
    if not g_pd3dDevice.value:
        return

    # IDirect3DDevice9::Clear
    clear = com_method(g_pd3dDevice, IDirect3DDevice9_Clear, wintypes.HRESULT,
        (ctypes.c_void_p, wintypes.DWORD, ctypes.c_void_p, wintypes.DWORD,
         wintypes.DWORD, ctypes.c_float, wintypes.DWORD))
    clear(g_pd3dDevice, 0, None, D3DCLEAR_TARGET, D3DCOLOR_XRGB(255, 255, 255), 1.0, 0)

    # IDirect3DDevice9::BeginScene
    begin_scene = com_method(g_pd3dDevice, IDirect3DDevice9_BeginScene, wintypes.HRESULT,
        (ctypes.c_void_p,))
    hr = begin_scene(g_pd3dDevice)

    if hr == 0:  # SUCCEEDED
        # IDirect3DDevice9::SetStreamSource
        set_stream = com_method(g_pd3dDevice, IDirect3DDevice9_SetStreamSource, wintypes.HRESULT,
            (ctypes.c_void_p, wintypes.UINT, ctypes.c_void_p, wintypes.UINT, wintypes.UINT))
        set_stream(g_pd3dDevice, 0, g_pVB, 0, ctypes.sizeof(VERTEX))

        # IDirect3DDevice9::SetFVF
        set_fvf = com_method(g_pd3dDevice, IDirect3DDevice9_SetFVF, wintypes.HRESULT,
            (ctypes.c_void_p, wintypes.DWORD))
        set_fvf(g_pd3dDevice, D3DFVF_VERTEX)

        # IDirect3DDevice9::DrawPrimitive
        draw_prim = com_method(g_pd3dDevice, IDirect3DDevice9_DrawPrimitive, wintypes.HRESULT,
            (ctypes.c_void_p, wintypes.UINT, wintypes.UINT, wintypes.UINT))
        draw_prim(g_pd3dDevice, D3DPT_TRIANGLELIST, 0, 1)

        # IDirect3DDevice9::EndScene
        end_scene = com_method(g_pd3dDevice, IDirect3DDevice9_EndScene, wintypes.HRESULT,
            (ctypes.c_void_p,))
        end_scene(g_pd3dDevice)

    # IDirect3DDevice9::Present
    present = com_method(g_pd3dDevice, IDirect3DDevice9_Present, wintypes.HRESULT,
        (ctypes.c_void_p, ctypes.c_void_p, ctypes.c_void_p, wintypes.HWND, ctypes.c_void_p))
    present(g_pd3dDevice, None, None, None, None)

# ============================================================
# Window procedure
# ============================================================
@WNDPROC
def wndproc(hwnd, msg, wparam, lparam):
    if msg == WM_DESTROY:
        user32.PostQuitMessage(0)
        return 0
    return user32.DefWindowProcW(hwnd, msg, wparam, lparam)

# ============================================================
# Main
# ============================================================
def main():
    global g_hwnd

    hInstance = kernel32.GetModuleHandleW(None)
    class_name = "PyD3D9Window"

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
        "Hello, World!",
        WS_OVERLAPPEDWINDOW,
        CW_USEDEFAULT, CW_USEDEFAULT,
        640, 480,
        None, None, hInstance, None
    )
    if not g_hwnd:
        raise winerr()

    user32.ShowWindow(g_hwnd, SW_SHOW)
    user32.UpdateWindow(g_hwnd)

    init_d3d()
    init_vb()

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

    cleanup()

if __name__ == "__main__":
    main()
