import ctypes
from ctypes import wintypes

# ---------------------------------------
# DLLs
# ---------------------------------------
user32   = ctypes.WinDLL("user32", use_last_error=True)
gdi32    = ctypes.WinDLL("gdi32",  use_last_error=True)
opengl32 = ctypes.WinDLL("opengl32", use_last_error=True)
kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)

for name in ("HICON", "HCURSOR", "HBRUSH", "HGLRC"):
    if not hasattr(wintypes, name):
        setattr(wintypes, name, wintypes.HANDLE)

LRESULT = wintypes.LPARAM
WNDPROC = ctypes.WINFUNCTYPE(LRESULT, wintypes.HWND, wintypes.UINT, wintypes.WPARAM, wintypes.LPARAM)

# ---------------------------------------
# Win32 constants
# ---------------------------------------
CS_OWNDC  = 0x0020
WS_OVERLAPPEDWINDOW = 0x00CF0000
CW_USEDEFAULT = 0x80000000
SW_SHOW = 5

WM_CLOSE   = 0x0010
WM_DESTROY = 0x0002
WM_QUIT    = 0x0012

PM_REMOVE  = 0x0001

# PixelFormat / PFD
PFD_TYPE_RGBA       = 0
PFD_MAIN_PLANE      = 0
PFD_DRAW_TO_WINDOW  = 0x00000004
PFD_SUPPORT_OPENGL  = 0x00000020
PFD_DOUBLEBUFFER    = 0x00000001

# IDC/IDI
IDI_APPLICATION = 32512
IDC_ARROW       = 32512

# ---------------------------------------
# WGL constants
# ---------------------------------------
WGL_CONTEXT_MAJOR_VERSION_ARB    = 0x2091
WGL_CONTEXT_MINOR_VERSION_ARB    = 0x2092
WGL_CONTEXT_FLAGS_ARB            = 0x2094
WGL_CONTEXT_PROFILE_MASK_ARB     = 0x9126
WGL_CONTEXT_CORE_PROFILE_BIT_ARB = 0x00000001

WGL_CONTEXT_DEBUG_BIT_ARB        = 0x0001

# ---------------------------------------
# OpenGL constants (minimum)
# ---------------------------------------
GL_COLOR_BUFFER_BIT = 0x00004000
GL_TRIANGLES        = 0x0004

GL_FLOAT            = 0x1406
GL_FALSE            = 0

GL_ARRAY_BUFFER     = 0x8892
GL_STATIC_DRAW      = 0x88E4

GL_VERTEX_SHADER    = 0x8B31
GL_FRAGMENT_SHADER  = 0x8B30

GL_COMPILE_STATUS   = 0x8B81
GL_LINK_STATUS      = 0x8B82
GL_INFO_LOG_LENGTH  = 0x8B84

GL_VERSION          = 0x1F02
GL_SHADING_LANGUAGE_VERSION = 0x8B8C

# ---------------------------------------
# Structs
# ---------------------------------------
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

# ---------------------------------------
# Prototypes (Win32/WGL basics)
# ---------------------------------------
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

# WGL (legacy + proc loader)
opengl32.wglCreateContext.restype = wintypes.HGLRC
opengl32.wglCreateContext.argtypes = (wintypes.HDC,)

opengl32.wglMakeCurrent.restype = wintypes.BOOL
opengl32.wglMakeCurrent.argtypes = (wintypes.HDC, wintypes.HGLRC)

opengl32.wglDeleteContext.restype = wintypes.BOOL
opengl32.wglDeleteContext.argtypes = (wintypes.HGLRC,)

opengl32.wglGetProcAddress.restype = ctypes.c_void_p
opengl32.wglGetProcAddress.argtypes = (ctypes.c_char_p,)

# OpenGL 1.1 exported funcs
opengl32.glClearColor.restype = None
opengl32.glClearColor.argtypes = (ctypes.c_float, ctypes.c_float, ctypes.c_float, ctypes.c_float)

opengl32.glClear.restype = None
opengl32.glClear.argtypes = (wintypes.DWORD,)

opengl32.glViewport.restype = None
opengl32.glViewport.argtypes = (ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_int)

opengl32.glGetString.restype = ctypes.c_char_p
opengl32.glGetString.argtypes = (wintypes.DWORD,)

# ---------------------------------------
# Helpers: load function pointers
# ---------------------------------------
def _valid_wgl_addr(addr: int) -> bool:
    return addr not in (0, 1, 2, 3, 0xFFFFFFFF)

def get_gl_func(name: str, restype, argtypes, is_stdcall=False):
    addr = opengl32.wglGetProcAddress(name.encode("ascii"))
    if not addr or not _valid_wgl_addr(int(addr)):
        raise RuntimeError(f"wglGetProcAddress failed: {name}")

    factory = ctypes.WINFUNCTYPE if is_stdcall else ctypes.CFUNCTYPE
    fn = factory(restype, *argtypes)(addr)
    fn.__name__ = name
    return fn

# ---------------------------------------
# Function pointers we need (same as GL3.3)
# ---------------------------------------
wglCreateContextAttribsARB = None

glGenVertexArrays = None
glBindVertexArray = None

glGenBuffers      = None
glBindBuffer      = None
glBufferData      = None

glCreateShader     = None
glShaderSource     = None
glCompileShader    = None
glGetShaderiv      = None
glGetShaderInfoLog = None

glCreateProgram      = None
glAttachShader       = None
glLinkProgram        = None
glUseProgram         = None
glGetProgramiv       = None
glGetProgramInfoLog  = None

glVertexAttribPointer     = None
glEnableVertexAttribArray = None

glDrawArrays = None

def init_wgl_and_gl_funcs():
    global wglCreateContextAttribsARB
    global glGenVertexArrays, glBindVertexArray
    global glGenBuffers, glBindBuffer, glBufferData
    global glCreateShader, glShaderSource, glCompileShader, glGetShaderiv, glGetShaderInfoLog
    global glCreateProgram, glAttachShader, glLinkProgram, glUseProgram, glGetProgramiv, glGetProgramInfoLog
    global glVertexAttribPointer, glEnableVertexAttribArray
    global glDrawArrays

    wglCreateContextAttribsARB = get_gl_func(
        "wglCreateContextAttribsARB",
        wintypes.HGLRC,
        (wintypes.HDC, wintypes.HGLRC, ctypes.POINTER(ctypes.c_int)),
        is_stdcall=True
    )

    glGenVertexArrays = get_gl_func("glGenVertexArrays", None, (ctypes.c_int, ctypes.POINTER(ctypes.c_uint)))
    glBindVertexArray = get_gl_func("glBindVertexArray", None, (ctypes.c_uint,))

    glGenBuffers = get_gl_func("glGenBuffers", None, (ctypes.c_int, ctypes.POINTER(ctypes.c_uint)))
    glBindBuffer = get_gl_func("glBindBuffer", None, (ctypes.c_uint, ctypes.c_uint))
    glBufferData = get_gl_func("glBufferData", None, (ctypes.c_uint, ctypes.c_size_t, ctypes.c_void_p, ctypes.c_uint))

    glCreateShader     = get_gl_func("glCreateShader", ctypes.c_uint, (ctypes.c_uint,))
    glShaderSource     = get_gl_func("glShaderSource", None, (ctypes.c_uint, ctypes.c_int,
                                                             ctypes.POINTER(ctypes.c_char_p),
                                                             ctypes.POINTER(ctypes.c_int)))
    glCompileShader    = get_gl_func("glCompileShader", None, (ctypes.c_uint,))
    glGetShaderiv      = get_gl_func("glGetShaderiv", None, (ctypes.c_uint, ctypes.c_uint, ctypes.POINTER(ctypes.c_int)))
    glGetShaderInfoLog = get_gl_func("glGetShaderInfoLog", None, (ctypes.c_uint, ctypes.c_int,
                                                                  ctypes.POINTER(ctypes.c_int),
                                                                  ctypes.c_char_p))

    glCreateProgram     = get_gl_func("glCreateProgram", ctypes.c_uint, ())
    glAttachShader      = get_gl_func("glAttachShader", None, (ctypes.c_uint, ctypes.c_uint))
    glLinkProgram       = get_gl_func("glLinkProgram", None, (ctypes.c_uint,))
    glUseProgram        = get_gl_func("glUseProgram", None, (ctypes.c_uint,))
    glGetProgramiv      = get_gl_func("glGetProgramiv", None, (ctypes.c_uint, ctypes.c_uint, ctypes.POINTER(ctypes.c_int)))
    glGetProgramInfoLog = get_gl_func("glGetProgramInfoLog", None, (ctypes.c_uint, ctypes.c_int,
                                                                    ctypes.POINTER(ctypes.c_int),
                                                                    ctypes.c_char_p))

    glVertexAttribPointer     = get_gl_func("glVertexAttribPointer", None, (ctypes.c_uint, ctypes.c_int, ctypes.c_uint,
                                                                            ctypes.c_ubyte, ctypes.c_int, ctypes.c_void_p))
    glEnableVertexAttribArray = get_gl_func("glEnableVertexAttribArray", None, (ctypes.c_uint,))

    glDrawArrays = get_gl_func("glDrawArrays", None, (ctypes.c_uint, ctypes.c_int, ctypes.c_int))

# ---------------------------------------
# Shader utilities
# ---------------------------------------
def compile_shader(shader_type: int, source: str) -> int:
    shader = glCreateShader(shader_type)
    src_bytes = source.encode("utf-8")
    src_ptr = ctypes.c_char_p(src_bytes)
    length = ctypes.c_int(len(src_bytes))
    glShaderSource(shader, 1, ctypes.byref(src_ptr), ctypes.byref(length))
    glCompileShader(shader)

    status = ctypes.c_int(0)
    glGetShaderiv(shader, GL_COMPILE_STATUS, ctypes.byref(status))
    if status.value != 1:
        log_len = ctypes.c_int(0)
        glGetShaderiv(shader, GL_INFO_LOG_LENGTH, ctypes.byref(log_len))
        if log_len.value > 1:
            buf = ctypes.create_string_buffer(log_len.value)
            out_len = ctypes.c_int(0)
            glGetShaderInfoLog(shader, log_len.value, ctypes.byref(out_len), buf)
            raise RuntimeError("Shader compile failed:\n" + buf.value.decode("utf-8", "replace"))
        raise RuntimeError("Shader compile failed (no log).")
    return shader

def link_program(vs: int, fs: int) -> int:
    prog = glCreateProgram()
    glAttachShader(prog, vs)
    glAttachShader(prog, fs)
    glLinkProgram(prog)

    status = ctypes.c_int(0)
    glGetProgramiv(prog, GL_LINK_STATUS, ctypes.byref(status))
    if status.value != 1:
        log_len = ctypes.c_int(0)
        glGetProgramiv(prog, GL_INFO_LOG_LENGTH, ctypes.byref(log_len))
        if log_len.value > 1:
            buf = ctypes.create_string_buffer(log_len.value)
            out_len = ctypes.c_int(0)
            glGetProgramInfoLog(prog, log_len.value, ctypes.byref(out_len), buf)
            raise RuntimeError("Program link failed:\n" + buf.value.decode("utf-8", "replace"))
        raise RuntimeError("Program link failed (no log).")
    return prog

# ---------------------------------------
# GL objects
# ---------------------------------------
g_hdc = None
g_hrc = None

vao = ctypes.c_uint(0)
vbo = (ctypes.c_uint * 2)()
program = ctypes.c_uint(0)

# GLSL 460 core
VERT_SRC = r"""
#version 460 core
layout(location = 0) in vec3 position;
layout(location = 1) in vec3 color;
out vec3 vColor;
void main()
{
    vColor = color;
    gl_Position = vec4(position, 1.0);
}
"""

FRAG_SRC = r"""
#version 460 core
in vec3 vColor;
layout(location = 0) out vec4 outColor;
void main()
{
    outColor = vec4(vColor, 1.0);
}
"""

def init_triangle_resources():
    global program

    glGenVertexArrays(1, ctypes.byref(vao))
    glBindVertexArray(vao.value)

    glGenBuffers(2, vbo)

    vertices = (ctypes.c_float * 9)(
         0.0,  0.5, 0.0,
         0.5, -0.5, 0.0,
        -0.5, -0.5, 0.0
    )
    colors = (ctypes.c_float * 9)(
        1.0, 0.0, 0.0,
        0.0, 1.0, 0.0,
        0.0, 0.0, 1.0
    )

    # position -> location 0
    glBindBuffer(GL_ARRAY_BUFFER, vbo[0])
    glBufferData(GL_ARRAY_BUFFER, ctypes.sizeof(vertices), ctypes.cast(vertices, ctypes.c_void_p), GL_STATIC_DRAW)
    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 0, ctypes.c_void_p(0))
    glEnableVertexAttribArray(0)

    # color -> location 1
    glBindBuffer(GL_ARRAY_BUFFER, vbo[1])
    glBufferData(GL_ARRAY_BUFFER, ctypes.sizeof(colors), ctypes.cast(colors, ctypes.c_void_p), GL_STATIC_DRAW)
    glVertexAttribPointer(1, 3, GL_FLOAT, GL_FALSE, 0, ctypes.c_void_p(0))
    glEnableVertexAttribArray(1)

    vs = compile_shader(GL_VERTEX_SHADER, VERT_SRC)
    fs = compile_shader(GL_FRAGMENT_SHADER, FRAG_SRC)
    program = ctypes.c_uint(link_program(vs, fs))
    glUseProgram(program.value)

def draw():
    glUseProgram(program.value)
    glBindVertexArray(vao.value)
    glDrawArrays(GL_TRIANGLES, 0, 3)

# ---------------------------------------
# Context creation
# ---------------------------------------
def set_pixel_format(hdc: wintypes.HDC) -> None:
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

def create_gl46_context(hdc: wintypes.HDC) -> wintypes.HGLRC:
    # old context
    hrc_old = opengl32.wglCreateContext(hdc)
    if not hrc_old:
        raise ctypes.WinError(ctypes.get_last_error())
    if not opengl32.wglMakeCurrent(hdc, hrc_old):
        raise ctypes.WinError(ctypes.get_last_error())

    # load pointers
    init_wgl_and_gl_funcs()

    attribs = (ctypes.c_int * 9)(
        WGL_CONTEXT_MAJOR_VERSION_ARB, 4,
        WGL_CONTEXT_MINOR_VERSION_ARB, 6,
        WGL_CONTEXT_FLAGS_ARB, 0,
        WGL_CONTEXT_PROFILE_MASK_ARB, WGL_CONTEXT_CORE_PROFILE_BIT_ARB,
        0
    )

    hrc = wglCreateContextAttribsARB(hdc, None, attribs)
    if not hrc:
        raise ctypes.WinError(ctypes.get_last_error())

    if not opengl32.wglMakeCurrent(hdc, hrc):
        raise ctypes.WinError(ctypes.get_last_error())

    opengl32.wglDeleteContext(hrc_old)
    return hrc

def destroy_context(hwnd: wintypes.HWND, hdc: wintypes.HDC, hrc: wintypes.HGLRC):
    if hrc:
        opengl32.wglMakeCurrent(None, None)
        opengl32.wglDeleteContext(hrc)
    if hwnd and hdc:
        user32.ReleaseDC(hwnd, hdc)

# ---------------------------------------
# Window procedure
# ---------------------------------------
@WNDPROC
def wndproc(hwnd, msg, wparam, lparam):
    if msg == WM_CLOSE:
        user32.PostQuitMessage(0)
        return 0
    if msg == WM_DESTROY:
        return 0
    return user32.DefWindowProcW(hwnd, msg, wparam, lparam)

# ---------------------------------------
# Main
# ---------------------------------------
def main():
    global g_hdc, g_hrc

    hInstance = kernel32.GetModuleHandleW(None)
    className = "PyOpenGL46NoLib"

    wc = WNDCLASSEXW()
    wc.cbSize = ctypes.sizeof(WNDCLASSEXW)
    wc.style = CS_OWNDC
    wc.lpfnWndProc = wndproc
    wc.hInstance = hInstance
    wc.hIcon = user32.LoadIconW(None, wintypes.LPCWSTR(IDI_APPLICATION))
    wc.hCursor = user32.LoadCursorW(None, wintypes.LPCWSTR(IDC_ARROW))
    wc.hbrBackground = 0
    wc.lpszClassName = className
    wc.hIconSm = wc.hIcon

    if not user32.RegisterClassExW(ctypes.byref(wc)):
        raise ctypes.WinError(ctypes.get_last_error())

    hwnd = user32.CreateWindowExW(
        0, className, "OpenGL 4.6 Triangle (ctypes only)",
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

    set_pixel_format(g_hdc)
    g_hrc = create_gl46_context(g_hdc)

    ver = opengl32.glGetString(GL_VERSION)
    sl  = opengl32.glGetString(GL_SHADING_LANGUAGE_VERSION)
    print("[GL] Version:", (ver.decode("ascii", "replace") if ver else "(null)"))
    print("[GL] GLSL   :", (sl.decode("ascii", "replace") if sl else "(null)"))

    opengl32.glViewport(0, 0, 640, 480)

    init_triangle_resources()

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

            draw()

            gdi32.SwapBuffers(g_hdc)
            kernel32.Sleep(1)

    destroy_context(hwnd, g_hdc, g_hrc)

if __name__ == "__main__":
    main()
