import ctypes
from ctypes import wintypes

user32   = ctypes.WinDLL("user32", use_last_error=True)
gdi32    = ctypes.WinDLL("gdi32",  use_last_error=True)
opengl32 = ctypes.WinDLL("opengl32", use_last_error=True)

for name in ("HICON", "HCURSOR", "HBRUSH", "HGLRC"):
    if not hasattr(wintypes, name):
        setattr(wintypes, name, wintypes.HANDLE)

LRESULT = wintypes.LPARAM
WNDPROC = ctypes.WINFUNCTYPE(LRESULT, wintypes.HWND, wintypes.UINT, wintypes.WPARAM, wintypes.LPARAM)

# ----------------------------
# Constants
# ----------------------------
CS_OWNDC  = 0x0020
WS_OVERLAPPEDWINDOW = 0x00CF0000
CW_USEDEFAULT = 0x80000000
SW_SHOW = 5

WM_DESTROY = 0x0002
WM_CLOSE   = 0x0010
WM_QUIT    = 0x0012

PM_REMOVE  = 0x0001

# PixelFormat / PFD
PFD_TYPE_RGBA       = 0
PFD_MAIN_PLANE      = 0
PFD_DRAW_TO_WINDOW  = 0x00000004
PFD_SUPPORT_OPENGL  = 0x00000020
PFD_DOUBLEBUFFER    = 0x00000001

# OpenGL 1.0
GL_COLOR_BUFFER_BIT = 0x00004000
GL_TRIANGLES        = 0x0004

# IDC/IDI
IDI_APPLICATION = 32512
IDC_ARROW       = 32512

# ----------------------------
# Structs
# ----------------------------
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

# ----------------------------
# Win32 prototypes (minimum)
# ----------------------------
kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
kernel32.GetModuleHandleW.restype = wintypes.HMODULE
kernel32.GetModuleHandleW.argtypes = (wintypes.LPCWSTR,)

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

user32.GetDC.restype = wintypes.HDC
user32.GetDC.argtypes = (wintypes.HWND,)

user32.ReleaseDC.restype = ctypes.c_int
user32.ReleaseDC.argtypes = (wintypes.HWND, wintypes.HDC)

user32.LoadIconW.restype = wintypes.HICON
user32.LoadIconW.argtypes = (wintypes.HINSTANCE, wintypes.LPCWSTR)

user32.LoadCursorW.restype = wintypes.HCURSOR
user32.LoadCursorW.argtypes = (wintypes.HINSTANCE, wintypes.LPCWSTR)

gdi32.ChoosePixelFormat.restype = ctypes.c_int
gdi32.ChoosePixelFormat.argtypes = (wintypes.HDC, ctypes.POINTER(PIXELFORMATDESCRIPTOR))

gdi32.SetPixelFormat.restype = wintypes.BOOL
gdi32.SetPixelFormat.argtypes = (wintypes.HDC, ctypes.c_int, ctypes.POINTER(PIXELFORMATDESCRIPTOR))

gdi32.SwapBuffers.restype = wintypes.BOOL
gdi32.SwapBuffers.argtypes = (wintypes.HDC,)

kernel32.Sleep.restype = None
kernel32.Sleep.argtypes = (wintypes.DWORD,)

# WGL
opengl32.wglCreateContext.restype = wintypes.HGLRC
opengl32.wglCreateContext.argtypes = (wintypes.HDC,)

opengl32.wglMakeCurrent.restype = wintypes.BOOL
opengl32.wglMakeCurrent.argtypes = (wintypes.HDC, wintypes.HGLRC)

opengl32.wglDeleteContext.restype = wintypes.BOOL
opengl32.wglDeleteContext.argtypes = (wintypes.HGLRC,)

# OpenGL 1.0 (fixed pipeline)
opengl32.glClearColor.restype = None
opengl32.glClearColor.argtypes = (ctypes.c_float, ctypes.c_float, ctypes.c_float, ctypes.c_float)

opengl32.glClear.restype = None
opengl32.glClear.argtypes = (wintypes.DWORD,)

opengl32.glBegin.restype = None
opengl32.glBegin.argtypes = (wintypes.DWORD,)

opengl32.glEnd.restype = None
opengl32.glEnd.argtypes = ()

opengl32.glColor3f.restype = None
opengl32.glColor3f.argtypes = (ctypes.c_float, ctypes.c_float, ctypes.c_float)

opengl32.glVertex2f.restype = None
opengl32.glVertex2f.argtypes = (ctypes.c_float, ctypes.c_float)

# ----------------------------
# Globals
# ----------------------------
g_hdc = None
g_hrc = None

def enable_opengl(hdc: wintypes.HDC) -> wintypes.HGLRC:
    pfd = PIXELFORMATDESCRIPTOR()
    ctypes.memset(ctypes.byref(pfd), 0, ctypes.sizeof(pfd))

    pfd.nSize = ctypes.sizeof(PIXELFORMATDESCRIPTOR)
    pfd.nVersion = 1
    pfd.dwFlags = PFD_DRAW_TO_WINDOW | PFD_SUPPORT_OPENGL | PFD_DOUBLEBUFFER
    pfd.iPixelType = PFD_TYPE_RGBA
    pfd.cColorBits = 24
    pfd.cDepthBits = 16
    pfd.iLayerType = PFD_MAIN_PLANE

    fmt = gdi32.ChoosePixelFormat(hdc, ctypes.byref(pfd))
    if fmt == 0:
        raise ctypes.WinError(ctypes.get_last_error())

    if not gdi32.SetPixelFormat(hdc, fmt, ctypes.byref(pfd)):
        raise ctypes.WinError(ctypes.get_last_error())

    hrc = opengl32.wglCreateContext(hdc)
    if not hrc:
        raise ctypes.WinError(ctypes.get_last_error())

    if not opengl32.wglMakeCurrent(hdc, hrc):
        raise ctypes.WinError(ctypes.get_last_error())

    return hrc

def disable_opengl(hwnd: wintypes.HWND, hdc: wintypes.HDC, hrc: wintypes.HGLRC) -> None:
    if hrc:
        opengl32.wglMakeCurrent(None, None)
        opengl32.wglDeleteContext(hrc)
    if hwnd and hdc:
        user32.ReleaseDC(hwnd, hdc)

def draw_triangle():
    opengl32.glBegin(GL_TRIANGLES)
    opengl32.glColor3f(1.0, 0.0, 0.0); opengl32.glVertex2f( 0.0,  0.50)
    opengl32.glColor3f(0.0, 1.0, 0.0); opengl32.glVertex2f( 0.5, -0.50)
    opengl32.glColor3f(0.0, 0.0, 1.0); opengl32.glVertex2f(-0.5, -0.50)
    opengl32.glEnd()

@WNDPROC
def wndproc(hwnd, msg, wparam, lparam):
    global g_hdc, g_hrc

    if msg == WM_CLOSE:
        user32.PostQuitMessage(0)
        return 0

    if msg == WM_DESTROY:
        return 0

    return user32.DefWindowProcW(hwnd, msg, wparam, lparam)

def main():
    global g_hdc, g_hrc

    hInstance = kernel32.GetModuleHandleW(None)
    className = "PyOpenGL10NoLib"

    wc = WNDCLASSEXW()
    wc.cbSize = ctypes.sizeof(WNDCLASSEXW)
    wc.style = CS_OWNDC
    wc.lpfnWndProc = wndproc
    wc.cbClsExtra = 0
    wc.cbWndExtra = 0
    wc.hInstance = hInstance
    wc.hIcon = user32.LoadIconW(None, wintypes.LPCWSTR(IDI_APPLICATION))
    wc.hCursor = user32.LoadCursorW(None, wintypes.LPCWSTR(IDC_ARROW))
    wc.hbrBackground = 0
    wc.lpszMenuName = None
    wc.lpszClassName = className
    wc.hIconSm = wc.hIcon

    if not user32.RegisterClassExW(ctypes.byref(wc)):
        raise ctypes.WinError(ctypes.get_last_error())

    hwnd = user32.CreateWindowExW(
        0, className, "OpenGL 1.0 Triangle (ctypes only)",
        WS_OVERLAPPEDWINDOW,
        CW_USEDEFAULT, CW_USEDEFAULT,
        640, 480,
        None, None, hInstance, None
    )
    if not hwnd:
        raise ctypes.WinError(ctypes.get_last_error())

    user32.ShowWindow(hwnd, SW_SHOW)

    g_hdc = user32.GetDC(hwnd)
    if not g_hdc:
        raise ctypes.WinError(ctypes.get_last_error())

    g_hrc = enable_opengl(g_hdc)

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
            opengl32.glClearColor(0.0, 0.0, 0.0, 0.0)
            opengl32.glClear(GL_COLOR_BUFFER_BIT)

            draw_triangle()

            gdi32.SwapBuffers(g_hdc)
            kernel32.Sleep(1)

    disable_opengl(hwnd, g_hdc, g_hrc)

if __name__ == "__main__":
    main()
