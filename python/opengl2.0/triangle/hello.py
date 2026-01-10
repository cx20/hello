import ctypes
from ctypes import wintypes

# ----------------------------
# DLLs
# ----------------------------
user32   = ctypes.WinDLL("user32", use_last_error=True)
gdi32    = ctypes.WinDLL("gdi32",  use_last_error=True)
opengl32 = ctypes.WinDLL("opengl32", use_last_error=True)
kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)

for name in ("HICON", "HCURSOR", "HBRUSH", "HGLRC"):
    if not hasattr(wintypes, name):
        setattr(wintypes, name, wintypes.HANDLE)

LRESULT = wintypes.LPARAM
WNDPROC = ctypes.WINFUNCTYPE(LRESULT, wintypes.HWND, wintypes.UINT, wintypes.WPARAM, wintypes.LPARAM)

# ----------------------------
# Win32 constants
# ----------------------------
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

# ----------------------------
# OpenGL constants (minimum)
# ----------------------------
GL_COLOR_BUFFER_BIT            = 0x00004000
GL_TRIANGLES                   = 0x0004

GL_FALSE                       = 0
GL_TRUE                        = 1

GL_FLOAT                       = 0x1406
GL_ARRAY_BUFFER                = 0x8892
GL_STATIC_DRAW                 = 0x88E4

GL_FRAGMENT_SHADER             = 0x8B30
GL_VERTEX_SHADER               = 0x8B31

GL_COMPILE_STATUS              = 0x8B81
GL_LINK_STATUS                 = 0x8B82
GL_INFO_LOG_LENGTH             = 0x8B84

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
# Win32 prototypes
# ----------------------------
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

# WGL
opengl32.wglCreateContext.restype = wintypes.HGLRC
opengl32.wglCreateContext.argtypes = (wintypes.HDC,)

opengl32.wglMakeCurrent.restype = wintypes.BOOL
opengl32.wglMakeCurrent.argtypes = (wintypes.HDC, wintypes.HGLRC)

opengl32.wglDeleteContext.restype = wintypes.BOOL
opengl32.wglDeleteContext.argtypes = (wintypes.HGLRC,)

opengl32.wglGetProcAddress.restype = ctypes.c_void_p
opengl32.wglGetProcAddress.argtypes = (ctypes.c_char_p,)

# OpenGL 1.1 (dllにあるので直呼びOK)
opengl32.glClearColor.restype = None
opengl32.glClearColor.argtypes = (ctypes.c_float, ctypes.c_float, ctypes.c_float, ctypes.c_float)

opengl32.glClear.restype = None
opengl32.glClear.argtypes = (wintypes.DWORD,)

# ----------------------------
# Helpers: load GL function pointers
# ----------------------------
def get_gl_func(name: str, restype, argtypes):
    addr = opengl32.wglGetProcAddress(name.encode("ascii"))
    if not addr:
        raise RuntimeError(f"wglGetProcAddress failed: {name}")
    fn = ctypes.CFUNCTYPE(restype, *argtypes)(addr)
    fn.__name__ = name
    return fn

# ----------------------------
# GL 2.0 function pointers (minimum)
# ----------------------------
glGenBuffers              = None
glBindBuffer              = None
glBufferData              = None

glCreateShader            = None
glShaderSource            = None
glCompileShader           = None
glGetShaderiv             = None
glGetShaderInfoLog        = None

glCreateProgram           = None
glAttachShader            = None
glLinkProgram             = None
glUseProgram              = None
glGetProgramiv            = None
glGetProgramInfoLog       = None

glGetAttribLocation       = None
glEnableVertexAttribArray = None
glVertexAttribPointer     = None

glDrawArrays              = None

def init_gl2_funcs():
    global glGenBuffers, glBindBuffer, glBufferData
    global glCreateShader, glShaderSource, glCompileShader, glGetShaderiv, glGetShaderInfoLog
    global glCreateProgram, glAttachShader, glLinkProgram, glUseProgram, glGetProgramiv, glGetProgramInfoLog
    global glGetAttribLocation, glEnableVertexAttribArray, glVertexAttribPointer
    global glDrawArrays

    # VBO
    glGenBuffers  = get_gl_func("glGenBuffers",  None, (ctypes.c_int, ctypes.POINTER(ctypes.c_uint)))
    glBindBuffer  = get_gl_func("glBindBuffer",  None, (ctypes.c_uint, ctypes.c_uint))
    glBufferData  = get_gl_func("glBufferData",  None, (ctypes.c_uint, ctypes.c_size_t, ctypes.c_void_p, ctypes.c_uint))

    # Shader
    glCreateShader     = get_gl_func("glCreateShader", ctypes.c_uint, (ctypes.c_uint,))
    glShaderSource     = get_gl_func("glShaderSource", None, (ctypes.c_uint, ctypes.c_int,
                                                             ctypes.POINTER(ctypes.c_char_p),
                                                             ctypes.POINTER(ctypes.c_int)))
    glCompileShader    = get_gl_func("glCompileShader", None, (ctypes.c_uint,))
    glGetShaderiv      = get_gl_func("glGetShaderiv", None, (ctypes.c_uint, ctypes.c_uint, ctypes.POINTER(ctypes.c_int)))
    glGetShaderInfoLog = get_gl_func("glGetShaderInfoLog", None, (ctypes.c_uint, ctypes.c_int,
                                                                  ctypes.POINTER(ctypes.c_int),
                                                                  ctypes.c_char_p))

    # Program
    glCreateProgram      = get_gl_func("glCreateProgram", ctypes.c_uint, ())
    glAttachShader       = get_gl_func("glAttachShader", None, (ctypes.c_uint, ctypes.c_uint))
    glLinkProgram        = get_gl_func("glLinkProgram", None, (ctypes.c_uint,))
    glUseProgram         = get_gl_func("glUseProgram", None, (ctypes.c_uint,))
    glGetProgramiv       = get_gl_func("glGetProgramiv", None, (ctypes.c_uint, ctypes.c_uint, ctypes.POINTER(ctypes.c_int)))
    glGetProgramInfoLog  = get_gl_func("glGetProgramInfoLog", None, (ctypes.c_uint, ctypes.c_int,
                                                                     ctypes.POINTER(ctypes.c_int),
                                                                     ctypes.c_char_p))

    # Attributes
    glGetAttribLocation       = get_gl_func("glGetAttribLocation", ctypes.c_int, (ctypes.c_uint, ctypes.c_char_p))
    glEnableVertexAttribArray = get_gl_func("glEnableVertexAttribArray", None, (ctypes.c_uint,))
    glVertexAttribPointer     = get_gl_func("glVertexAttribPointer", None, (ctypes.c_uint, ctypes.c_int, ctypes.c_uint,
                                                                            ctypes.c_ubyte, ctypes.c_int, ctypes.c_void_p))

    # Draw
    glDrawArrays = get_gl_func("glDrawArrays", None, (ctypes.c_uint, ctypes.c_int, ctypes.c_int))

# ----------------------------
# Shader utilities
# ----------------------------
def compile_shader(shader_type: int, source: str) -> int:
    shader = glCreateShader(shader_type)
    src_bytes = source.encode("utf-8")
    src_ptr = ctypes.c_char_p(src_bytes)
    length = ctypes.c_int(len(src_bytes))
    glShaderSource(shader, 1, ctypes.byref(src_ptr), ctypes.byref(length))
    glCompileShader(shader)

    status = ctypes.c_int(0)
    glGetShaderiv(shader, GL_COMPILE_STATUS, ctypes.byref(status))
    if status.value != GL_TRUE:
        log_len = ctypes.c_int(0)
        glGetShaderiv(shader, GL_INFO_LOG_LENGTH, ctypes.byref(log_len))
        if log_len.value > 1:
            buf = ctypes.create_string_buffer(log_len.value)
            out_len = ctypes.c_int(0)
            glGetShaderInfoLog(shader, log_len.value, ctypes.byref(out_len), buf)
            raise RuntimeError(f"Shader compile failed:\n{buf.value.decode('utf-8', 'replace')}")
        raise RuntimeError("Shader compile failed (no log).")
    return shader

def link_program(vs: int, fs: int) -> int:
    prog = glCreateProgram()
    glAttachShader(prog, vs)
    glAttachShader(prog, fs)
    glLinkProgram(prog)

    status = ctypes.c_int(0)
    glGetProgramiv(prog, GL_LINK_STATUS, ctypes.byref(status))
    if status.value != GL_TRUE:
        log_len = ctypes.c_int(0)
        glGetProgramiv(prog, GL_INFO_LOG_LENGTH, ctypes.byref(log_len))
        if log_len.value > 1:
            buf = ctypes.create_string_buffer(log_len.value)
            out_len = ctypes.c_int(0)
            glGetProgramInfoLog(prog, log_len.value, ctypes.byref(out_len), buf)
            raise RuntimeError(f"Program link failed:\n{buf.value.decode('utf-8', 'replace')}")
        raise RuntimeError("Program link failed (no log).")
    return prog

# ----------------------------
# Globals for GL objects
# ----------------------------
g_hdc = None
g_hrc = None

vbo = (ctypes.c_uint * 2)()
posAttrib = ctypes.c_int(-1)
colAttrib = ctypes.c_int(-1)
shaderProgram = ctypes.c_uint(0)

# Shader sources
vertexSource = """
attribute vec3 position;
attribute vec3 color;
varying   vec4 vColor;
void main()
{
  vColor = vec4(color, 1.0);
  gl_Position = vec4(position, 1.0);
}
"""

fragmentSource = """
precision mediump float;
varying   vec4 vColor;
void main()
{
  gl_FragColor = vColor;
}
"""

def init_shader_and_buffers():
    global shaderProgram, posAttrib, colAttrib

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

    glBindBuffer(GL_ARRAY_BUFFER, vbo[0])
    glBufferData(GL_ARRAY_BUFFER, ctypes.sizeof(vertices), ctypes.cast(vertices, ctypes.c_void_p), GL_STATIC_DRAW)

    glBindBuffer(GL_ARRAY_BUFFER, vbo[1])
    glBufferData(GL_ARRAY_BUFFER, ctypes.sizeof(colors), ctypes.cast(colors, ctypes.c_void_p), GL_STATIC_DRAW)

    vs = compile_shader(GL_VERTEX_SHADER, vertexSource)
    fs = compile_shader(GL_FRAGMENT_SHADER, fragmentSource)
    shaderProgram = link_program(vs, fs)
    glUseProgram(shaderProgram)

    pos = glGetAttribLocation(shaderProgram, b"position")
    col = glGetAttribLocation(shaderProgram, b"color")
    if pos < 0 or col < 0:
        raise RuntimeError(f"glGetAttribLocation failed: position={pos}, color={col}")

    posAttrib = ctypes.c_int(pos)
    colAttrib = ctypes.c_int(col)

    glEnableVertexAttribArray(posAttrib.value)
    glEnableVertexAttribArray(colAttrib.value)

def draw_triangle_gl20():
    # position
    glBindBuffer(GL_ARRAY_BUFFER, vbo[0])
    glVertexAttribPointer(posAttrib.value, 3, GL_FLOAT, GL_FALSE, 0, ctypes.c_void_p(0))

    # color
    glBindBuffer(GL_ARRAY_BUFFER, vbo[1])
    glVertexAttribPointer(colAttrib.value, 3, GL_FLOAT, GL_FALSE, 0, ctypes.c_void_p(0))

    glDrawArrays(GL_TRIANGLES, 0, 3)

# ----------------------------
# WGL context setup
# ----------------------------
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

# ----------------------------
# Window procedure
# ----------------------------
@WNDPROC
def wndproc(hwnd, msg, wparam, lparam):
    if msg == WM_CLOSE:
        user32.PostQuitMessage(0)
        return 0
    if msg == WM_DESTROY:
        return 0
    return user32.DefWindowProcW(hwnd, msg, wparam, lparam)

# ----------------------------
# Main
# ----------------------------
def main():
    global g_hdc, g_hrc

    hInstance = kernel32.GetModuleHandleW(None)
    className = "PyOpenGL20NoLib"

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
        0, className, "OpenGL 2.0 Triangle (ctypes only)",
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

    init_gl2_funcs()

    init_shader_and_buffers()

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

            draw_triangle_gl20()

            gdi32.SwapBuffers(g_hdc)
            kernel32.Sleep(1)

    disable_opengl(hwnd, g_hdc, g_hrc)

if __name__ == "__main__":
    main()
