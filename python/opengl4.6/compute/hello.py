import ctypes
from ctypes import wintypes
import time
import random
import sys

# ============================================================
# DLLs
# ============================================================
user32   = ctypes.WinDLL("user32", use_last_error=True)
gdi32    = ctypes.WinDLL("gdi32",  use_last_error=True)
opengl32 = ctypes.WinDLL("opengl32", use_last_error=True)
kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)

# Some handle typedefs might be missing in ctypes.wintypes
for name in ("HICON", "HCURSOR", "HBRUSH", "HGLRC"):
    if not hasattr(wintypes, name):
        setattr(wintypes, name, wintypes.HANDLE)

LRESULT = wintypes.LPARAM
WNDPROC = ctypes.WINFUNCTYPE(LRESULT, wintypes.HWND, wintypes.UINT, wintypes.WPARAM, wintypes.LPARAM)

# ============================================================
# Win32 constants
# ============================================================
CS_OWNDC  = 0x0020
WS_OVERLAPPEDWINDOW = 0x00CF0000
CW_USEDEFAULT = 0x80000000
SW_SHOW = 5

WM_CLOSE   = 0x0010
WM_DESTROY = 0x0002
WM_QUIT    = 0x0012
PM_REMOVE  = 0x0001

IDI_APPLICATION = 32512
IDC_ARROW       = 32512
VK_ESCAPE       = 0x1B

# PixelFormat / PFD
PFD_TYPE_RGBA       = 0
PFD_MAIN_PLANE      = 0
PFD_DRAW_TO_WINDOW  = 0x00000004
PFD_SUPPORT_OPENGL  = 0x00000020
PFD_DOUBLEBUFFER    = 0x00000001

# ============================================================
# WGL constants (for OpenGL 4.6 core context)
# ============================================================
WGL_CONTEXT_MAJOR_VERSION_ARB    = 0x2091
WGL_CONTEXT_MINOR_VERSION_ARB    = 0x2092
WGL_CONTEXT_FLAGS_ARB            = 0x2094
WGL_CONTEXT_PROFILE_MASK_ARB     = 0x9126
WGL_CONTEXT_CORE_PROFILE_BIT_ARB = 0x00000001

# ============================================================
# OpenGL constants (minimum)
# ============================================================
GL_COLOR_BUFFER_BIT = 0x00004000
GL_DEPTH_BUFFER_BIT = 0x00000100
GL_POINTS           = 0x0000

GL_FALSE            = 0
GL_TRUE             = 1

GL_FLOAT            = 0x1406
GL_ARRAY_BUFFER     = 0x8892

GL_STATIC_DRAW      = 0x88E4
GL_DYNAMIC_DRAW     = 0x88E8

GL_VERTEX_SHADER    = 0x8B31
GL_FRAGMENT_SHADER  = 0x8B30
GL_COMPUTE_SHADER   = 0x91B9

GL_COMPILE_STATUS   = 0x8B81
GL_LINK_STATUS      = 0x8B82
GL_INFO_LOG_LENGTH  = 0x8B84

GL_VERSION          = 0x1F02
GL_SHADING_LANGUAGE_VERSION = 0x8B8C

GL_SHADER_STORAGE_BUFFER = 0x90D2
GL_SHADER_STORAGE_BARRIER_BIT = 0x2000

GL_DEPTH_TEST       = 0x0B71
GL_PROGRAM_POINT_SIZE = 0x8642

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

user32.GetDC.restype = wintypes.HDC
user32.GetDC.argtypes = (wintypes.HWND,)

user32.ReleaseDC.restype = ctypes.c_int
user32.ReleaseDC.argtypes = (wintypes.HWND, wintypes.HDC)

user32.LoadIconW.restype = wintypes.HICON
user32.LoadIconW.argtypes = (wintypes.HINSTANCE, wintypes.LPCWSTR)

user32.LoadCursorW.restype = wintypes.HCURSOR
user32.LoadCursorW.argtypes = (wintypes.HINSTANCE, wintypes.LPCWSTR)

user32.GetAsyncKeyState.restype = wintypes.SHORT
user32.GetAsyncKeyState.argtypes = (wintypes.INT,)

gdi32.ChoosePixelFormat.restype = ctypes.c_int
gdi32.ChoosePixelFormat.argtypes = (wintypes.HDC, ctypes.POINTER(PIXELFORMATDESCRIPTOR))

gdi32.SetPixelFormat.restype = wintypes.BOOL
gdi32.SetPixelFormat.argtypes = (wintypes.HDC, ctypes.c_int, ctypes.POINTER(PIXELFORMATDESCRIPTOR))

gdi32.SwapBuffers.restype = wintypes.BOOL
gdi32.SwapBuffers.argtypes = (wintypes.HDC,)

# ============================================================
# WGL (legacy + proc loader)
# ============================================================
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

opengl32.glEnable.restype = None
opengl32.glEnable.argtypes = (wintypes.DWORD,)

opengl32.glPointSize.restype = None
opengl32.glPointSize.argtypes = (ctypes.c_float,)

# ============================================================
# Helpers: load function pointers
# ============================================================
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

# ============================================================
# GL/WGL function pointers we need
# ============================================================
wglCreateContextAttribsARB = None

glGenVertexArrays = None
glBindVertexArray = None

glGenBuffers      = None
glBindBuffer      = None
glBufferData      = None
glBindBufferBase  = None

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
glDeleteShader       = None

glGetUniformLocation = None
glUniform1f          = None
glUniform2f          = None
glUniform1ui         = None

glDispatchCompute = None
glMemoryBarrier   = None

glDrawArrays = None

def init_wgl_and_gl_funcs():
    global wglCreateContextAttribsARB
    global glGenVertexArrays, glBindVertexArray
    global glGenBuffers, glBindBuffer, glBufferData, glBindBufferBase
    global glCreateShader, glShaderSource, glCompileShader, glGetShaderiv, glGetShaderInfoLog
    global glCreateProgram, glAttachShader, glLinkProgram, glUseProgram, glGetProgramiv, glGetProgramInfoLog, glDeleteShader
    global glGetUniformLocation, glUniform1f, glUniform2f, glUniform1ui
    global glDispatchCompute, glMemoryBarrier
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
    glBindBufferBase = get_gl_func("glBindBufferBase", None, (ctypes.c_uint, ctypes.c_uint, ctypes.c_uint))

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
    glDeleteShader      = get_gl_func("glDeleteShader", None, (ctypes.c_uint,))

    glGetUniformLocation = get_gl_func("glGetUniformLocation", ctypes.c_int, (ctypes.c_uint, ctypes.c_char_p))
    glUniform1f          = get_gl_func("glUniform1f", None, (ctypes.c_int, ctypes.c_float))
    glUniform2f          = get_gl_func("glUniform2f", None, (ctypes.c_int, ctypes.c_float, ctypes.c_float))
    glUniform1ui         = get_gl_func("glUniform1ui", None, (ctypes.c_int, ctypes.c_uint))

    glDispatchCompute = get_gl_func("glDispatchCompute", None, (ctypes.c_uint, ctypes.c_uint, ctypes.c_uint))
    glMemoryBarrier   = get_gl_func("glMemoryBarrier", None, (ctypes.c_uint,))

    glDrawArrays = get_gl_func("glDrawArrays", None, (ctypes.c_uint, ctypes.c_int, ctypes.c_int))

# ============================================================
# Shader utilities
# ============================================================
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
            raise RuntimeError("Shader compile failed:\n" + buf.value.decode("utf-8", "replace"))
        raise RuntimeError("Shader compile failed (no log).")
    return shader

def link_program(shaders) -> int:
    prog = glCreateProgram()
    for sh in shaders:
        glAttachShader(prog, sh)
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
            raise RuntimeError("Program link failed:\n" + buf.value.decode("utf-8", "replace"))
        raise RuntimeError("Program link failed (no log).")

    for sh in shaders:
        glDeleteShader(sh)

    return prog

# ============================================================
# GLSL sources (SSBO + Compute)
# ============================================================
VERT_SRC = r"""
#version 460 core

layout(std430, binding=7) buffer Particles {
    vec4 pos[];
};

uniform vec2 resolution;
out vec4 vColor;

mat4 perspective(float fov, float aspect, float near, float far)
{
    float v = 1.0 / tan(radians(fov/2.0));
    float u = v / aspect;
    float w = near - far;
    return mat4(
        u, 0, 0, 0,
        0, v, 0, 0,
        0, 0, (near+far)/w, -1,
        0, 0, (near*far*2.0)/w, 0
    );
}

mat4 lookAt(vec3 eye, vec3 center, vec3 up)
{
    vec3 w = normalize(eye - center);
    vec3 u = normalize(cross(up, w));
    vec3 v = cross(w, u);
    return mat4(
        u.x, v.x, w.x, 0,
        u.y, v.y, w.y, 0,
        u.z, v.z, w.z, 0,
        -dot(u, eye), -dot(v, eye), -dot(w, eye), 1
    );
}

void main(void)
{
    vec4 p = pos[gl_VertexID];

    mat4 pMat = perspective(45.0, resolution.x / resolution.y, 0.1, 200.0);
    vec3 camera = vec3(0, 5, 10);
    vec3 center = vec3(0, 0, 0);
    mat4 vMat = lookAt(camera, center, vec3(0,1,0));

    gl_Position = pMat * vMat * p;

    vColor = vec4(
        gl_Position.x * 0.08 + 0.5,
        gl_Position.y * 0.08 + 0.5,
        gl_Position.z * 0.08 + 0.5,
        1.0
    );
}
"""

FRAG_SRC = r"""
#version 460 core
in vec4 vColor;
layout(location = 0) out vec4 outColor;
void main()
{
    outColor = vColor;
}
"""

COMP_SRC = r"""
#version 460 core

layout(std430, binding=7) buffer Particles {
    vec4 pos[];
};

uniform float time;
uniform uint  max_num;

uniform float f1;
uniform float f2;
uniform float f3;
uniform float f4;

layout(local_size_x = 128, local_size_y = 1, local_size_z = 1) in;

#define PI 3.14159265359
#define PI2 (PI * 2.0)

vec2 rotate2(in vec2 p, in float t)
{
    float c = cos(-t);
    float s = sin(-t);
    return p * c + vec2(p.y, -p.x) * s;
}

float hash(float n)
{
    return fract(sin(n) * 753.5453123);
}

float A1 = 0.2, p1 = 1.0/16.0,  d1 = 0.02;
float A2 = 0.2, p2 = 3.0/2.0,   d2 = 0.0315;
float A3 = 0.2, p3 = 13.0/15.0, d3 = 0.02;
float A4 = 0.2, p4 = 1.0,       d4 = 0.02;

void main()
{
    uint id = gl_GlobalInvocationID.x;
    if (id >= max_num) return;

    float theta = hash(float(id) * 0.3123887) * PI2 + time;

    p1 = theta;

    float t = theta;

    float x = A1 * sin(f1 * t + PI * p1) * exp(-d1 * t)
            + A2 * sin(f2 * t + PI * p2) * exp(-d2 * t);

    float y = A3 * sin(f3 * t + PI * p3) * exp(-d3 * t)
            + A4 * sin(f4 * t + PI * p4) * exp(-d4 * t);

    float z = A1 * cos(f1 * t + PI * p1) * exp(-d1 * t)
            + A2 * cos(f2 * t + PI * p2) * exp(-d2 * t);

    vec4 p = vec4(x, y, z, 1.0);

    p.xz = rotate2(p.xz, hash(float(id) * 0.5123) * PI2);

    p.xyz *= 5.0;

    pos[id] = p;
}
"""

# ============================================================
# GL objects
# ============================================================
g_hdc = None
g_hrc = None

vao = ctypes.c_uint(0)
ssbo = ctypes.c_uint(0)

draw_program = ctypes.c_uint(0)
compute_program = ctypes.c_uint(0)

# ============================================================
# Context creation
# ============================================================
def set_pixel_format(hdc: wintypes.HDC) -> None:
    pfd = PIXELFORMATDESCRIPTOR()
    ctypes.memset(ctypes.byref(pfd), 0, ctypes.sizeof(pfd))

    pfd.nSize = ctypes.sizeof(PIXELFORMATDESCRIPTOR)
    pfd.nVersion = 1
    pfd.dwFlags = PFD_DRAW_TO_WINDOW | PFD_SUPPORT_OPENGL | PFD_DOUBLEBUFFER
    pfd.iPixelType = PFD_TYPE_RGBA
    pfd.cColorBits = 24
    pfd.cDepthBits = 24
    pfd.iLayerType = PFD_MAIN_PLANE

    fmt = gdi32.ChoosePixelFormat(hdc, ctypes.byref(pfd))
    if fmt == 0:
        raise ctypes.WinError(ctypes.get_last_error())
    if not gdi32.SetPixelFormat(hdc, fmt, ctypes.byref(pfd)):
        raise ctypes.WinError(ctypes.get_last_error())

def create_gl46_context(hdc: wintypes.HDC) -> wintypes.HGLRC:
    hrc_old = opengl32.wglCreateContext(hdc)
    if not hrc_old:
        raise ctypes.WinError(ctypes.get_last_error())
    if not opengl32.wglMakeCurrent(hdc, hrc_old):
        raise ctypes.WinError(ctypes.get_last_error())

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

# ============================================================
# Window procedure
# ============================================================
@WNDPROC
def wndproc(hwnd, msg, wparam, lparam):
    if msg == WM_CLOSE:
        user32.PostQuitMessage(0)
        return 0
    if msg == WM_DESTROY:
        return 0
    return user32.DefWindowProcW(hwnd, msg, wparam, lparam)

# ============================================================
# Init GL resources (SSBO + programs)
# ============================================================
def init_resources(width: int, height: int, max_num: int):
    global draw_program, compute_program, vao, ssbo

    # VAO
    glGenVertexArrays(1, ctypes.byref(vao))
    glBindVertexArray(vao.value)

    # SSBO（vec4 * max_num）
    glGenBuffers(1, ctypes.byref(ssbo))
    glBindBuffer(GL_SHADER_STORAGE_BUFFER, ssbo.value)
    glBufferData(GL_SHADER_STORAGE_BUFFER, 16 * max_num, None, GL_DYNAMIC_DRAW)
    glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 7, ssbo.value)

    # draw program
    vs = compile_shader(GL_VERTEX_SHADER, VERT_SRC)
    fs = compile_shader(GL_FRAGMENT_SHADER, FRAG_SRC)
    draw_program = ctypes.c_uint(link_program([vs, fs]))

    # compute program
    cs = compile_shader(GL_COMPUTE_SHADER, COMP_SRC)
    compute_program = ctypes.c_uint(link_program([cs]))

    # uniforms
    glUseProgram(draw_program.value)
    loc_res = glGetUniformLocation(draw_program.value, b"resolution")
    if loc_res >= 0:
        glUniform2f(loc_res, float(width), float(height))

    glUseProgram(compute_program.value)
    loc_max = glGetUniformLocation(compute_program.value, b"max_num")
    if loc_max >= 0:
        glUniform1ui(loc_max, max_num)

    opengl32.glEnable(GL_DEPTH_TEST)
    opengl32.glEnable(GL_PROGRAM_POINT_SIZE)
    opengl32.glPointSize(2.0)

# ============================================================
# Main loop
# ============================================================
def main():
    global g_hdc, g_hrc

    WIDTH  = 640
    HEIGHT = 480
    max_num = 10000
    duration_sec = 60.0

    hInstance = kernel32.GetModuleHandleW(None)
    className = "PyGL46ComputeNoLib"

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
        0, className, "OpenGL 4.6 Compute Shader (ctypes only)",
        WS_OVERLAPPEDWINDOW,
        CW_USEDEFAULT, CW_USEDEFAULT,
        WIDTH, HEIGHT,
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

    opengl32.glViewport(0, 0, WIDTH, HEIGHT)
    init_resources(WIDTH, HEIGHT, max_num)

    f1 = 2.0
    f2 = 2.0
    f3 = 2.0
    f4 = 2.0

    msg = MSG()
    start = time.perf_counter()
    last_fps_t = start
    frames = 0
    fps = 0

    loc_time = glGetUniformLocation(compute_program.value, b"time")
    loc_f1 = glGetUniformLocation(compute_program.value, b"f1")
    loc_f2 = glGetUniformLocation(compute_program.value, b"f2")
    loc_f3 = glGetUniformLocation(compute_program.value, b"f3")
    loc_f4 = glGetUniformLocation(compute_program.value, b"f4")

    running = True
    while running:
        # message pump
        if user32.PeekMessageW(ctypes.byref(msg), None, 0, 0, PM_REMOVE):
            if msg.message == WM_QUIT:
                running = False
            else:
                user32.TranslateMessage(ctypes.byref(msg))
                user32.DispatchMessageW(ctypes.byref(msg))
            continue

        if user32.GetAsyncKeyState(VK_ESCAPE) & 0x8000:
            running = False
            continue

        now = time.perf_counter()
        t = float(now - start)

        f1 = (f1 + random.random() / 100.0) % 10.0
        f2 = (f2 + random.random() / 100.0) % 10.0
        f3 = (f3 + random.random() / 100.0) % 10.0
        f4 = (f4 + random.random() / 100.0) % 10.0

        # --- Compute: SSBO update ---
        glUseProgram(compute_program.value)
        if loc_time >= 0: glUniform1f(loc_time, t)
        if loc_f1 >= 0: glUniform1f(loc_f1, f1)
        if loc_f2 >= 0: glUniform1f(loc_f2, f2)
        if loc_f3 >= 0: glUniform1f(loc_f3, f3)
        if loc_f4 >= 0: glUniform1f(loc_f4, f4)

        groups_x = (max_num + 127) // 128
        glDispatchCompute(groups_x, 1, 1)

        glMemoryBarrier(GL_SHADER_STORAGE_BARRIER_BIT)

        # --- Draw ---
        opengl32.glClearColor(0.0, 0.0, 0.0, 1.0)
        opengl32.glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT)

        glUseProgram(draw_program.value)
        glBindVertexArray(vao.value)
        glDrawArrays(GL_POINTS, 0, max_num)

        gdi32.SwapBuffers(g_hdc)

        frames += 1
        if now - last_fps_t >= 1.0:
            fps = frames
            frames = 0
            last_fps_t = now
            sys.stdout.write(f"\rFPS: {fps}  time: {t:.2f}  max_num: {max_num}    ")
            sys.stdout.flush()

        if t >= duration_sec:
            running = False

        kernel32.Sleep(1)

    print("\n[Exit]")
    destroy_context(hwnd, g_hdc, g_hrc)

if __name__ == "__main__":
    main()

