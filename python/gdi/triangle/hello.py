import ctypes
from ctypes import wintypes

user32   = ctypes.WinDLL("user32", use_last_error=True)
gdi32    = ctypes.WinDLL("gdi32",  use_last_error=True)
msimg32  = ctypes.WinDLL("msimg32", use_last_error=True)

if not hasattr(wintypes, "HCURSOR"):
    wintypes.HCURSOR = wintypes.HANDLE
if not hasattr(wintypes, "HICON"):
    wintypes.HICON = wintypes.HANDLE
if not hasattr(wintypes, "HBRUSH"):
    wintypes.HBRUSH = wintypes.HANDLE

user32.LoadIconW.restype = wintypes.HICON
user32.LoadIconW.argtypes = (wintypes.HINSTANCE, wintypes.LPCWSTR)

user32.LoadCursorW.restype = wintypes.HCURSOR
user32.LoadCursorW.argtypes = (wintypes.HINSTANCE, wintypes.LPCWSTR)

# ----------------------------
# Win32 constants
# ----------------------------
CS_HREDRAW = 0x0002
CS_VREDRAW = 0x0001

WS_OVERLAPPEDWINDOW = 0x00CF0000
CW_USEDEFAULT = 0x80000000
SW_SHOW = 5

WM_DESTROY = 0x0002
WM_PAINT   = 0x000F

GRADIENT_FILL_TRIANGLE = 0x00000002

# ----------------------------
# Win32 structs
# ----------------------------
LRESULT = wintypes.LPARAM

WNDPROC = ctypes.WINFUNCTYPE(LRESULT, wintypes.HWND, wintypes.UINT, wintypes.WPARAM, wintypes.LPARAM)

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

class PAINTSTRUCT(ctypes.Structure):
    _fields_ = [
        ("hdc",         wintypes.HDC),
        ("fErase",      wintypes.BOOL),
        ("rcPaint",     wintypes.RECT),
        ("fRestore",    wintypes.BOOL),
        ("fIncUpdate",  wintypes.BOOL),
        ("rgbReserved", ctypes.c_byte * 32),
    ]

# GradientFill related
COLOR16 = ctypes.c_ushort

class TRIVERTEX(ctypes.Structure):
    _fields_ = [
        ("x",     ctypes.c_long),
        ("y",     ctypes.c_long),
        ("Red",   COLOR16),
        ("Green", COLOR16),
        ("Blue",  COLOR16),
        ("Alpha", COLOR16),
    ]

class GRADIENT_TRIANGLE(ctypes.Structure):
    _fields_ = [
        ("Vertex1", ctypes.c_ulong),
        ("Vertex2", ctypes.c_ulong),
        ("Vertex3", ctypes.c_ulong),
    ]

# ----------------------------
# Win32 function prototypes
# ----------------------------
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

user32.GetMessageW.restype = ctypes.c_int
user32.GetMessageW.argtypes = (ctypes.POINTER(MSG), wintypes.HWND, wintypes.UINT, wintypes.UINT)

user32.TranslateMessage.restype = wintypes.BOOL
user32.TranslateMessage.argtypes = (ctypes.POINTER(MSG),)

user32.DispatchMessageW.restype = LRESULT
user32.DispatchMessageW.argtypes = (ctypes.POINTER(MSG),)

user32.PostQuitMessage.restype = None
user32.PostQuitMessage.argtypes = (ctypes.c_int,)

user32.BeginPaint.restype = wintypes.HDC
user32.BeginPaint.argtypes = (wintypes.HWND, ctypes.POINTER(PAINTSTRUCT))

user32.EndPaint.restype = wintypes.BOOL
user32.EndPaint.argtypes = (wintypes.HWND, ctypes.POINTER(PAINTSTRUCT))

user32.GetClientRect.restype = wintypes.BOOL
user32.GetClientRect.argtypes = (wintypes.HWND, ctypes.POINTER(wintypes.RECT))

# msimg32 GradientFill
msimg32.GradientFill.restype = wintypes.BOOL
msimg32.GradientFill.argtypes = (
    wintypes.HDC,
    ctypes.POINTER(TRIVERTEX),
    ctypes.c_ulong,
    ctypes.c_void_p,
    ctypes.c_ulong,
    ctypes.c_ulong
)

# ----------------------------
# Drawing
# ----------------------------
def draw_triangle_gradient(hdc: wintypes.HDC, width: int, height: int) -> None:
    v = (TRIVERTEX * 3)()

    v[0].x = width  * 1 // 2
    v[0].y = height * 1 // 4
    v[0].Red   = 0xFFFF
    v[0].Green = 0x0000
    v[0].Blue  = 0x0000
    v[0].Alpha = 0x0000

    v[1].x = width  * 3 // 4
    v[1].y = height * 3 // 4
    v[1].Red   = 0x0000
    v[1].Green = 0xFFFF
    v[1].Blue  = 0x0000
    v[1].Alpha = 0x0000

    v[2].x = width  * 1 // 4
    v[2].y = height * 3 // 4
    v[2].Red   = 0x0000
    v[2].Green = 0x0000
    v[2].Blue  = 0xFFFF
    v[2].Alpha = 0x0000

    tri = GRADIENT_TRIANGLE()
    tri.Vertex1 = 0
    tri.Vertex2 = 1
    tri.Vertex3 = 2

    ok = msimg32.GradientFill(
        hdc,
        v, 3,
        ctypes.byref(tri),
        1,
        GRADIENT_FILL_TRIANGLE
    )
    if not ok:
        raise ctypes.WinError(ctypes.get_last_error())

# ----------------------------
# Window procedure
# ----------------------------
@WNDPROC
def wndproc(hwnd, msg, wparam, lparam):
    if msg == WM_PAINT:
        ps = PAINTSTRUCT()
        hdc = user32.BeginPaint(hwnd, ctypes.byref(ps))

        rc = wintypes.RECT()
        user32.GetClientRect(hwnd, ctypes.byref(rc))
        width  = rc.right - rc.left
        height = rc.bottom - rc.top

        draw_triangle_gradient(hdc, width, height)

        user32.EndPaint(hwnd, ctypes.byref(ps))
        return 0

    if msg == WM_DESTROY:
        user32.PostQuitMessage(0)
        return 0

    return user32.DefWindowProcW(hwnd, msg, wparam, lparam)

# ----------------------------
# Main
# ----------------------------
def main():
    hInstance = ctypes.WinDLL("kernel32").GetModuleHandleW(None)

    className = "PyWin32NoLibWindow"
    wc = WNDCLASSEXW()
    wc.cbSize = ctypes.sizeof(WNDCLASSEXW)
    wc.style  = CS_HREDRAW | CS_VREDRAW
    wc.lpfnWndProc = wndproc
    wc.cbClsExtra = 0
    wc.cbWndExtra = 0
    wc.hInstance = hInstance
    wc.hIcon = user32.LoadIconW(None, wintypes.LPCWSTR(32512))   # IDI_APPLICATION
    wc.hCursor = user32.LoadCursorW(None, wintypes.LPCWSTR(32512)) # IDC_ARROW
    wc.hbrBackground = ctypes.c_void_p(0)
    wc.lpszMenuName = None
    wc.lpszClassName = className
    wc.hIconSm = wc.hIcon

    if not user32.RegisterClassExW(ctypes.byref(wc)):
        raise ctypes.WinError(ctypes.get_last_error())

    hwnd = user32.CreateWindowExW(
        0,
        className,
        "GDI Gradient Triangle (ctypes only)",
        WS_OVERLAPPEDWINDOW,
        CW_USEDEFAULT, CW_USEDEFAULT,
        640, 480,
        None, None,
        hInstance,
        None
    )
    if not hwnd:
        raise ctypes.WinError(ctypes.get_last_error())

    user32.ShowWindow(hwnd, SW_SHOW)
    user32.UpdateWindow(hwnd)

    msg = MSG()
    while user32.GetMessageW(ctypes.byref(msg), None, 0, 0) > 0:
        user32.TranslateMessage(ctypes.byref(msg))
        user32.DispatchMessageW(ctypes.byref(msg))

if __name__ == "__main__":
    main()

