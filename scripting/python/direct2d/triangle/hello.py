import ctypes
from ctypes import wintypes

# ============================================================
# DLLs
# ============================================================
user32   = ctypes.WinDLL("user32", use_last_error=True)
kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)

# ============================================================
# Basic Win32 types / helpers
# ============================================================
LRESULT = wintypes.LPARAM
WNDPROC = ctypes.WINFUNCTYPE(LRESULT, wintypes.HWND, wintypes.UINT, wintypes.WPARAM, wintypes.LPARAM)

if not hasattr(wintypes, "HRESULT"):
    wintypes.HRESULT = ctypes.c_long

for name in ("HICON", "HCURSOR", "HBRUSH"):
    if not hasattr(wintypes, name):
        setattr(wintypes, name, wintypes.HANDLE)

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
COLOR_WINDOW = 5

WM_DESTROY = 0x0002
WM_PAINT   = 0x000F
WM_SIZE    = 0x0005
WM_QUIT    = 0x0012

PM_REMOVE  = 0x0001

IDC_ARROW = 32512

# ============================================================
# Direct2D constants
# ============================================================
D2D1_FACTORY_TYPE_SINGLE_THREADED = 0

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
    _fields_ = [
        ("left",   ctypes.c_long),
        ("top",    ctypes.c_long),
        ("right",  ctypes.c_long),
        ("bottom", ctypes.c_long),
    ]

class GUID(ctypes.Structure):
    _fields_ = [
        ("Data1", wintypes.DWORD),
        ("Data2", wintypes.WORD),
        ("Data3", wintypes.WORD),
        ("Data4", ctypes.c_ubyte * 8),
    ]

def guid_from_str(s: str) -> GUID:
    import uuid
    u = uuid.UUID(s)
    b = u.bytes_le
    g = GUID()
    ctypes.memmove(ctypes.byref(g), b, ctypes.sizeof(g))
    return g

# Direct2D structures
class D2D1_COLOR_F(ctypes.Structure):
    _fields_ = [
        ("r", ctypes.c_float),
        ("g", ctypes.c_float),
        ("b", ctypes.c_float),
        ("a", ctypes.c_float),
    ]

class D2D1_POINT_2F(ctypes.Structure):
    _fields_ = [
        ("x", ctypes.c_float),
        ("y", ctypes.c_float),
    ]

class D2D1_SIZE_U(ctypes.Structure):
    _fields_ = [
        ("width",  wintypes.UINT),
        ("height", wintypes.UINT),
    ]

class D2D1_PIXEL_FORMAT(ctypes.Structure):
    _fields_ = [
        ("format",    wintypes.UINT),
        ("alphaMode", wintypes.UINT),
    ]

class D2D1_RENDER_TARGET_PROPERTIES(ctypes.Structure):
    _fields_ = [
        ("type",        wintypes.UINT),
        ("pixelFormat", D2D1_PIXEL_FORMAT),
        ("dpiX",        ctypes.c_float),
        ("dpiY",        ctypes.c_float),
        ("usage",       wintypes.UINT),
        ("minLevel",    wintypes.UINT),
    ]

class D2D1_HWND_RENDER_TARGET_PROPERTIES(ctypes.Structure):
    _fields_ = [
        ("hwnd",           wintypes.HWND),
        ("pixelSize",      D2D1_SIZE_U),
        ("presentOptions", wintypes.UINT),
    ]

# IID_ID2D1Factory
IID_ID2D1Factory = guid_from_str("{06152247-6f50-465a-9245-118bfd3b6007}")

# ============================================================
# Win32 prototypes
# ============================================================
kernel32.GetModuleHandleW.restype = wintypes.HMODULE
kernel32.GetModuleHandleW.argtypes = (wintypes.LPCWSTR,)

kernel32.LoadLibraryW.restype = wintypes.HMODULE
kernel32.LoadLibraryW.argtypes = (wintypes.LPCWSTR,)

kernel32.GetProcAddress.restype = ctypes.c_void_p
kernel32.GetProcAddress.argtypes = (wintypes.HMODULE, wintypes.LPCSTR)

kernel32.FreeLibrary.restype = wintypes.BOOL
kernel32.FreeLibrary.argtypes = (wintypes.HMODULE,)

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

user32.GetMessageW.restype = wintypes.BOOL
user32.GetMessageW.argtypes = (ctypes.POINTER(MSG), wintypes.HWND, wintypes.UINT, wintypes.UINT)

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

user32.ValidateRect.restype = wintypes.BOOL
user32.ValidateRect.argtypes = (wintypes.HWND, ctypes.c_void_p)

# ============================================================
# COM vtable caller
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
# Global D2D objects
# ============================================================
g_hwnd = None
g_hD2D1 = None

g_factory      = ctypes.c_void_p()
g_renderTarget = ctypes.c_void_p()
g_brush        = ctypes.c_void_p()

# ============================================================
# D2D1CreateFactory function pointer
# ============================================================
# typedef HRESULT (WINAPI *PFN_D2D1CreateFactory)(D2D1_FACTORY_TYPE, REFIID, const D2D1_FACTORY_OPTIONS*, void**)
D2D1CreateFactoryProto = ctypes.WINFUNCTYPE(
    wintypes.HRESULT,
    wintypes.UINT,
    ctypes.POINTER(GUID),
    ctypes.c_void_p,
    ctypes.POINTER(ctypes.c_void_p)
)

# ============================================================
# D2D init
# ============================================================
def init_d2d():
    global g_hD2D1, g_factory, g_renderTarget, g_brush

    # Load d2d1.dll
    g_hD2D1 = kernel32.LoadLibraryW("d2d1.dll")
    if not g_hD2D1:
        raise winerr()

    # Get D2D1CreateFactory
    proc_addr = kernel32.GetProcAddress(g_hD2D1, b"D2D1CreateFactory")
    if not proc_addr:
        raise RuntimeError("Failed to get D2D1CreateFactory")

    D2D1CreateFactory = D2D1CreateFactoryProto(proc_addr)

    # Create factory
    iid = IID_ID2D1Factory
    hr = D2D1CreateFactory(
        D2D1_FACTORY_TYPE_SINGLE_THREADED,
        ctypes.byref(iid),
        None,
        ctypes.byref(g_factory)
    )
    if hr != 0:
        raise RuntimeError(f"D2D1CreateFactory failed: HRESULT=0x{hr & 0xFFFFFFFF:08X}")

    # Get client rect
    rc = RECT()
    user32.GetClientRect(g_hwnd, ctypes.byref(rc))
    width  = rc.right - rc.left
    height = rc.bottom - rc.top

    # Create render target properties
    rtProps = D2D1_RENDER_TARGET_PROPERTIES()
    hwndProps = D2D1_HWND_RENDER_TARGET_PROPERTIES()
    hwndProps.hwnd = g_hwnd
    hwndProps.pixelSize.width = width
    hwndProps.pixelSize.height = height
    hwndProps.presentOptions = 0

    # ID2D1Factory::CreateHwndRenderTarget (vtable #14)
    create_hwnd_rt = com_method(
        g_factory, 14, wintypes.HRESULT,
        (ctypes.c_void_p, ctypes.POINTER(D2D1_RENDER_TARGET_PROPERTIES),
         ctypes.POINTER(D2D1_HWND_RENDER_TARGET_PROPERTIES), ctypes.POINTER(ctypes.c_void_p))
    )
    hr = create_hwnd_rt(g_factory, ctypes.byref(rtProps), ctypes.byref(hwndProps), ctypes.byref(g_renderTarget))
    if hr != 0:
        raise RuntimeError(f"CreateHwndRenderTarget failed: HRESULT=0x{hr & 0xFFFFFFFF:08X}")

    # ID2D1RenderTarget::CreateSolidColorBrush (vtable #8)
    blue = D2D1_COLOR_F(0.0, 0.0, 1.0, 1.0)
    create_brush = com_method(
        g_renderTarget, 8, wintypes.HRESULT,
        (ctypes.c_void_p, ctypes.POINTER(D2D1_COLOR_F), ctypes.c_void_p, ctypes.POINTER(ctypes.c_void_p))
    )
    hr = create_brush(g_renderTarget, ctypes.byref(blue), None, ctypes.byref(g_brush))
    if hr != 0:
        raise RuntimeError(f"CreateSolidColorBrush failed: HRESULT=0x{hr & 0xFFFFFFFF:08X}")

def cleanup_d2d():
    global g_brush, g_renderTarget, g_factory, g_hD2D1
    com_release(g_brush);        g_brush        = ctypes.c_void_p()
    com_release(g_renderTarget); g_renderTarget = ctypes.c_void_p()
    com_release(g_factory);      g_factory      = ctypes.c_void_p()
    if g_hD2D1:
        kernel32.FreeLibrary(g_hD2D1)
        g_hD2D1 = None

def resize_render_target(width, height):
    if not g_renderTarget:
        return
    # ID2D1HwndRenderTarget::Resize (vtable #58)
    size = D2D1_SIZE_U(width, height)
    resize = com_method(
        g_renderTarget, 58, wintypes.HRESULT,
        (ctypes.c_void_p, ctypes.POINTER(D2D1_SIZE_U))
    )
    resize(g_renderTarget, ctypes.byref(size))

def draw():
    if not g_renderTarget:
        return

    # BeginDraw (vtable #48)
    begin_draw = com_method(g_renderTarget, 48, None, (ctypes.c_void_p,))
    begin_draw(g_renderTarget)

    # Clear (vtable #47)
    white = D2D1_COLOR_F(1.0, 1.0, 1.0, 1.0)
    clear = com_method(
        g_renderTarget, 47, None,
        (ctypes.c_void_p, ctypes.POINTER(D2D1_COLOR_F))
    )
    clear(g_renderTarget, ctypes.byref(white))

    # DrawLine (vtable #15)
    # void DrawLine(D2D1_POINT_2F p0, D2D1_POINT_2F p1, ID2D1Brush* brush, float strokeWidth, ID2D1StrokeStyle* strokeStyle)
    draw_line = com_method(
        g_renderTarget, 15, None,
        (ctypes.c_void_p, D2D1_POINT_2F, D2D1_POINT_2F, ctypes.c_void_p, ctypes.c_float, ctypes.c_void_p)
    )

    p1 = D2D1_POINT_2F(320.0, 120.0)
    p2 = D2D1_POINT_2F(480.0, 360.0)
    p3 = D2D1_POINT_2F(160.0, 360.0)

    draw_line(g_renderTarget, p1, p2, g_brush, 2.0, None)
    draw_line(g_renderTarget, p2, p3, g_brush, 2.0, None)
    draw_line(g_renderTarget, p3, p1, g_brush, 2.0, None)

    # EndDraw (vtable #49)
    end_draw = com_method(
        g_renderTarget, 49, wintypes.HRESULT,
        (ctypes.c_void_p, ctypes.POINTER(ctypes.c_uint64), ctypes.POINTER(ctypes.c_uint64))
    )
    end_draw(g_renderTarget, None, None)

# ============================================================
# Window procedure
# ============================================================
@WNDPROC
def wndproc(hwnd, msg, wparam, lparam):
    if msg == WM_PAINT:
        draw()
        user32.ValidateRect(hwnd, None)
        return 0
    if msg == WM_SIZE:
        width  = lparam & 0xFFFF
        height = (lparam >> 16) & 0xFFFF
        resize_render_target(width, height)
        return 0
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
    class_name = "PyD2DRaw"

    wc = WNDCLASSEXW()
    wc.cbSize = ctypes.sizeof(WNDCLASSEXW)
    wc.style = CS_HREDRAW | CS_VREDRAW
    wc.lpfnWndProc = wndproc
    wc.hInstance = hInstance
    wc.hCursor = user32.LoadCursorW(None, wintypes.LPCWSTR(IDC_ARROW))
    wc.hbrBackground = COLOR_WINDOW + 1
    wc.lpszClassName = class_name

    if not user32.RegisterClassExW(ctypes.byref(wc)):
        raise winerr()

    g_hwnd = user32.CreateWindowExW(
        0,
        class_name,
        "Hello, Direct2D(Python) World!",
        WS_OVERLAPPEDWINDOW,
        CW_USEDEFAULT, CW_USEDEFAULT,
        640, 480,
        None, None, hInstance, None
    )
    if not g_hwnd:
        raise winerr()

    init_d2d()

    user32.ShowWindow(g_hwnd, SW_SHOW)
    user32.UpdateWindow(g_hwnd)

    msg = MSG()
    while user32.GetMessageW(ctypes.byref(msg), None, 0, 0) != 0:
        user32.TranslateMessage(ctypes.byref(msg))
        user32.DispatchMessageW(ctypes.byref(msg))

    cleanup_d2d()

if __name__ == "__main__":
    main()
