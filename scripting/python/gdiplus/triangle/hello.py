import ctypes
from ctypes import wintypes

# Some Python builds don't define these handle typedefs in ctypes.wintypes
if not hasattr(wintypes, "HCURSOR"):
    wintypes.HCURSOR = wintypes.HANDLE
if not hasattr(wintypes, "HICON"):
    wintypes.HICON = wintypes.HANDLE
if not hasattr(wintypes, "HBRUSH"):
    wintypes.HBRUSH = wintypes.HANDLE
if not hasattr(wintypes, "HGDIOBJ"):
    wintypes.HGDIOBJ = wintypes.HANDLE

# ----------------------------
# DLLs
# ----------------------------
user32   = ctypes.WinDLL("user32",   use_last_error=True)
gdi32    = ctypes.WinDLL("gdi32",    use_last_error=True)
kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
gdiplus  = ctypes.WinDLL("gdiplus",  use_last_error=True)

# ----------------------------
# Helpers / types
# ----------------------------
# ULONG_PTR (pointer-sized unsigned integer)
if hasattr(wintypes, "ULONG_PTR"):
    ULONG_PTR = wintypes.ULONG_PTR
else:
    ULONG_PTR = ctypes.c_size_t

GpStatus = ctypes.c_int
GpGraphics = ctypes.c_void_p
GpPath = ctypes.c_void_p
GpBrush = ctypes.c_void_p  # PathGradient is also a Brush in the API surface

def gp_check(status: int, name: str):
    # GDI+ status: 0 == Ok. (This is not GetLastError-based.)
    if status != 0:
        raise RuntimeError(f"{name} failed: status={status}")

# ----------------------------
# GDI+ structs
# ----------------------------
class GdiplusStartupInput(ctypes.Structure):
    _fields_ = [
        ("GdiplusVersion", wintypes.UINT),
        ("DebugEventCallback", ctypes.c_void_p),
        ("SuppressBackgroundThread", wintypes.BOOL),
        ("SuppressExternalCodecs", wintypes.BOOL),
    ]

class GpPoint(ctypes.Structure):
    _fields_ = [("x", ctypes.c_int), ("y", ctypes.c_int)]

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

IDI_APPLICATION = 32512
IDC_ARROW       = 32512
WHITE_BRUSH     = 0

# GDI+ FillMode (GdipCreatePath)
FillModeAlternate = 0

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

# ----------------------------
# Win32 prototypes
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

user32.LoadIconW.restype = wintypes.HICON
user32.LoadIconW.argtypes = (wintypes.HINSTANCE, wintypes.LPCWSTR)

user32.LoadCursorW.restype = wintypes.HCURSOR
user32.LoadCursorW.argtypes = (wintypes.HINSTANCE, wintypes.LPCWSTR)

gdi32.GetStockObject.restype = wintypes.HGDIOBJ
gdi32.GetStockObject.argtypes = (ctypes.c_int,)

# ----------------------------
# GDI+ prototypes (stdcall)
# ----------------------------
gdiplus.GdiplusStartup.restype = GpStatus
gdiplus.GdiplusStartup.argtypes = (ctypes.POINTER(ULONG_PTR), ctypes.POINTER(GdiplusStartupInput), ctypes.c_void_p)

gdiplus.GdiplusShutdown.restype = None
gdiplus.GdiplusShutdown.argtypes = (ULONG_PTR,)

gdiplus.GdipCreateFromHDC.restype = GpStatus
gdiplus.GdipCreateFromHDC.argtypes = (wintypes.HDC, ctypes.POINTER(GpGraphics))

gdiplus.GdipDeleteGraphics.restype = GpStatus
gdiplus.GdipDeleteGraphics.argtypes = (GpGraphics,)

gdiplus.GdipCreatePath.restype = GpStatus
gdiplus.GdipCreatePath.argtypes = (ctypes.c_int, ctypes.POINTER(GpPath))

gdiplus.GdipDeletePath.restype = GpStatus
gdiplus.GdipDeletePath.argtypes = (GpPath,)

gdiplus.GdipAddPathLine2I.restype = GpStatus
gdiplus.GdipAddPathLine2I.argtypes = (GpPath, ctypes.POINTER(GpPoint), ctypes.c_int)

gdiplus.GdipClosePathFigure.restype = GpStatus
gdiplus.GdipClosePathFigure.argtypes = (GpPath,)

gdiplus.GdipCreatePathGradientFromPath.restype = GpStatus
gdiplus.GdipCreatePathGradientFromPath.argtypes = (GpPath, ctypes.POINTER(GpBrush))

gdiplus.GdipSetPathGradientCenterColor.restype = GpStatus
gdiplus.GdipSetPathGradientCenterColor.argtypes = (GpBrush, wintypes.DWORD)  # ARGB

gdiplus.GdipSetPathGradientSurroundColorsWithCount.restype = GpStatus
gdiplus.GdipSetPathGradientSurroundColorsWithCount.argtypes = (
    GpBrush,
    ctypes.POINTER(wintypes.DWORD),   # ARGB array
    ctypes.POINTER(ctypes.c_int)      # in/out count
)

gdiplus.GdipFillPath.restype = GpStatus
gdiplus.GdipFillPath.argtypes = (GpGraphics, GpBrush, GpPath)

gdiplus.GdipDeleteBrush.restype = GpStatus
gdiplus.GdipDeleteBrush.argtypes = (GpBrush,)

# ----------------------------
# Drawing (GDI+ PathGradient triangle)
# ----------------------------
def draw_triangle_gdiplus(hdc: wintypes.HDC, width: int, height: int) -> None:
    graphics = GpGraphics()
    path = GpPath()
    brush = GpBrush()

    status = gdiplus.GdipCreateFromHDC(hdc, ctypes.byref(graphics))
    gp_check(status, "GdipCreateFromHDC")

    try:
        status = gdiplus.GdipCreatePath(FillModeAlternate, ctypes.byref(path))
        gp_check(status, "GdipCreatePath")

        try:
            pts = (GpPoint * 3)()
            pts[0].x = width  * 1 // 2
            pts[0].y = height * 1 // 4
            pts[1].x = width  * 3 // 4
            pts[1].y = height * 3 // 4
            pts[2].x = width  * 1 // 4
            pts[2].y = height * 3 // 4

            status = gdiplus.GdipAddPathLine2I(path, pts, 3)
            gp_check(status, "GdipAddPathLine2I")

            status = gdiplus.GdipClosePathFigure(path)
            gp_check(status, "GdipClosePathFigure")

            status = gdiplus.GdipCreatePathGradientFromPath(path, ctypes.byref(brush))
            gp_check(status, "GdipCreatePathGradientFromPath")

            try:
                # Center color (ARGB)
                status = gdiplus.GdipSetPathGradientCenterColor(brush, 0xFF555555)
                gp_check(status, "GdipSetPathGradientCenterColor")

                # Surround colors (ARGB)
                colors = (wintypes.DWORD * 3)(0xFFFF0000, 0xFF00FF00, 0xFF0000FF)  # red, green, blue
                count = ctypes.c_int(3)
                status = gdiplus.GdipSetPathGradientSurroundColorsWithCount(brush, colors, ctypes.byref(count))
                gp_check(status, "GdipSetPathGradientSurroundColorsWithCount")

                status = gdiplus.GdipFillPath(graphics, brush, path)
                gp_check(status, "GdipFillPath")

            finally:
                if brush:
                    gdiplus.GdipDeleteBrush(brush)

        finally:
            if path:
                gdiplus.GdipDeletePath(path)

    finally:
        if graphics:
            gdiplus.GdipDeleteGraphics(graphics)

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
        w = rc.right - rc.left
        h = rc.bottom - rc.top

        draw_triangle_gdiplus(hdc, w, h)

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
    # GDI+ init
    token = ULONG_PTR(0)
    si = GdiplusStartupInput()
    si.GdiplusVersion = 1
    si.DebugEventCallback = None
    si.SuppressBackgroundThread = False
    si.SuppressExternalCodecs = False

    status = gdiplus.GdiplusStartup(ctypes.byref(token), ctypes.byref(si), None)
    gp_check(status, "GdiplusStartup")

    try:
        hInstance = kernel32.GetModuleHandleW(None)

        className = "PyGDIPlusWindow"
        wc = WNDCLASSEXW()
        wc.cbSize = ctypes.sizeof(WNDCLASSEXW)
        wc.style  = CS_HREDRAW | CS_VREDRAW
        wc.lpfnWndProc = wndproc
        wc.cbClsExtra = 0
        wc.cbWndExtra = 0
        wc.hInstance = hInstance
        wc.hIcon = user32.LoadIconW(None, wintypes.LPCWSTR(IDI_APPLICATION))
        wc.hCursor = user32.LoadCursorW(None, wintypes.LPCWSTR(IDC_ARROW))
        wc.hbrBackground = ctypes.cast(gdi32.GetStockObject(WHITE_BRUSH), wintypes.HBRUSH)
        wc.lpszMenuName = None
        wc.lpszClassName = className
        wc.hIconSm = wc.hIcon

        if not user32.RegisterClassExW(ctypes.byref(wc)):
            raise ctypes.WinError(ctypes.get_last_error())

        hwnd = user32.CreateWindowExW(
            0,
            className,
            "GDI+ Triangle (ctypes only)",
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

    finally:
        gdiplus.GdiplusShutdown(token)

if __name__ == "__main__":
    main()
