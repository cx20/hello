import ctypes
from ctypes import wintypes
import time
import random
import sys

# ============================================================
# OpenGL 4.6 Compute Shader Harmonograph (ctypes only, no libs)
# - Creates a Win32 window
# - Creates an OpenGL 4.6 core profile context via WGL_ARB_create_context
# - Uses a compute shader to fill SSBOs (positions + colors)
# - Uses a vertex/fragment shader to render GL_LINE_STRIP from SSBO data
#
# Notes:
# - This is designed to match the behavior of the WGSL snippet you posted:
#     t = idx * 0.01
#     harmonograph equations with exp(-d*t)
#     hue = (t/20*360) % 360, HSV->RGB
# - For visual stability with exp(-d*t), a moderate VERTEX_COUNT (e.g. 20000) is recommended.
# ============================================================

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

GL_LINE_STRIP       = 0x0003

GL_FALSE            = 0
GL_TRUE             = 1

GL_VERTEX_SHADER    = 0x8B31
GL_FRAGMENT_SHADER  = 0x8B30
GL_COMPUTE_SHADER   = 0x91B9

GL_COMPILE_STATUS   = 0x8B81
GL_LINK_STATUS      = 0x8B82
GL_INFO_LOG_LENGTH  = 0x8B84

GL_VERSION          = 0x1F02
GL_SHADING_LANGUAGE_VERSION = 0x8B8C

GL_SHADER_STORAGE_BUFFER = 0x90D2
GL_DYNAMIC_DRAW          = 0x88E8
GL_SHADER_STORAGE_BARRIER_BIT = 0x2000

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

# ============================================================
# Helpers: load function pointers via wglGetProcAddress
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

glGenBuffers     = None
glBindBuffer     = None
glBufferData     = None
glBindBufferBase = None

glCreateShader     = None
glShaderSource     = None
glCompileShader    = None
glGetShaderiv      = None
glGetShaderInfoLog = None
glDeleteShader     = None

glCreateProgram      = None
glAttachShader       = None
glLinkProgram        = None
glUseProgram         = None
glGetProgramiv       = None
glGetProgramInfoLog  = None

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
    global glCreateShader, glShaderSource, glCompileShader, glGetShaderiv, glGetShaderInfoLog, glDeleteShader
    global glCreateProgram, glAttachShader, glLinkProgram, glUseProgram, glGetProgramiv, glGetProgramInfoLog
    global glGetUniformLocation, glUniform1f, glUniform2f, glUniform1ui
    global glDispatchCompute, glMemoryBarrier
    global glDrawArrays

    # WGL extension for core context creation
    wglCreateContextAttribsARB = get_gl_func(
        "wglCreateContextAttribsARB",
        wintypes.HGLRC,
        (wintypes.HDC, wintypes.HGLRC, ctypes.POINTER(ctypes.c_int)),
        is_stdcall=True
    )

    # VAO
    glGenVertexArrays = get_gl_func("glGenVertexArrays", None, (ctypes.c_int, ctypes.POINTER(ctypes.c_uint)))
    glBindVertexArray = get_gl_func("glBindVertexArray", None, (ctypes.c_uint,))

    # Buffers + SSBO binding
    glGenBuffers     = get_gl_func("glGenBuffers", None, (ctypes.c_int, ctypes.POINTER(ctypes.c_uint)))
    glBindBuffer     = get_gl_func("glBindBuffer", None, (ctypes.c_uint, ctypes.c_uint))
    glBufferData     = get_gl_func("glBufferData", None, (ctypes.c_uint, ctypes.c_size_t, ctypes.c_void_p, ctypes.c_uint))
    glBindBufferBase = get_gl_func("glBindBufferBase", None, (ctypes.c_uint, ctypes.c_uint, ctypes.c_uint))

    # Shader compile/link
    glCreateShader     = get_gl_func("glCreateShader", ctypes.c_uint, (ctypes.c_uint,))
    glShaderSource     = get_gl_func(
        "glShaderSource",
        None,
        (ctypes.c_uint, ctypes.c_int, ctypes.POINTER(ctypes.c_char_p), ctypes.POINTER(ctypes.c_int))
    )
    glCompileShader    = get_gl_func("glCompileShader", None, (ctypes.c_uint,))
    glGetShaderiv      = get_gl_func("glGetShaderiv", None, (ctypes.c_uint, ctypes.c_uint, ctypes.POINTER(ctypes.c_int)))
    glGetShaderInfoLog = get_gl_func(
        "glGetShaderInfoLog",
        None,
        (ctypes.c_uint, ctypes.c_int, ctypes.POINTER(ctypes.c_int), ctypes.c_char_p)
    )
    glDeleteShader     = get_gl_func("glDeleteShader", None, (ctypes.c_uint,))

    glCreateProgram     = get_gl_func("glCreateProgram", ctypes.c_uint, ())
    glAttachShader      = get_gl_func("glAttachShader", None, (ctypes.c_uint, ctypes.c_uint))
    glLinkProgram       = get_gl_func("glLinkProgram", None, (ctypes.c_uint,))
    glUseProgram        = get_gl_func("glUseProgram", None, (ctypes.c_uint,))
    glGetProgramiv      = get_gl_func("glGetProgramiv", None, (ctypes.c_uint, ctypes.c_uint, ctypes.POINTER(ctypes.c_int)))
    glGetProgramInfoLog = get_gl_func(
        "glGetProgramInfoLog",
        None,
        (ctypes.c_uint, ctypes.c_int, ctypes.POINTER(ctypes.c_int), ctypes.c_char_p)
    )

    # Uniforms
    glGetUniformLocation = get_gl_func("glGetUniformLocation", ctypes.c_int, (ctypes.c_uint, ctypes.c_char_p))
    glUniform1f          = get_gl_func("glUniform1f", None, (ctypes.c_int, ctypes.c_float))
    glUniform2f          = get_gl_func("glUniform2f", None, (ctypes.c_int, ctypes.c_float, ctypes.c_float))
    glUniform1ui         = get_gl_func("glUniform1ui", None, (ctypes.c_int, ctypes.c_uint))

    # Compute + sync
    glDispatchCompute = get_gl_func("glDispatchCompute", None, (ctypes.c_uint, ctypes.c_uint, ctypes.c_uint))
    glMemoryBarrier   = get_gl_func("glMemoryBarrier", None, (ctypes.c_uint,))

    # Draw
    glDrawArrays = get_gl_func("glDrawArrays", None, (ctypes.c_uint, ctypes.c_int, ctypes.c_int))

# ============================================================
# Shader utilities
# ============================================================
def compile_shader(shader_type: int, source: str) -> int:
    shader = glCreateShader(shader_type)

    src_bytes = source.encode("utf-8")
    src_ptr   = ctypes.c_char_p(src_bytes)
    length    = ctypes.c_int(len(src_bytes))

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

    # We can delete shader objects after linking
    for sh in shaders:
        glDeleteShader(sh)

    return prog

# ============================================================
# GLSL sources
# - Positions SSBO: binding=7, vec4 pos[]
# - Colors SSBO:    binding=8, vec4 col[]
# - Compute fills both buffers, matching your WGSL logic
# ============================================================

VERT_SRC = r"""
#version 460 core

layout(std430, binding=7) buffer Positions {
    vec4 pos[];
};

layout(std430, binding=8) buffer Colors {
    vec4 col[];
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

    // Simple camera (same as earlier samples)
    mat4 pMat = perspective(45.0, resolution.x / resolution.y, 0.1, 200.0);
    vec3 camera = vec3(0, 5, 10);
    vec3 center = vec3(0, 0, 0);
    mat4 vMat = lookAt(camera, center, vec3(0,1,0));

    gl_Position = pMat * vMat * p;

    // Read per-vertex color from SSBO (matching WGSL behavior)
    vColor = col[gl_VertexID];
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

layout(local_size_x = 64, local_size_y = 1, local_size_z = 1) in;

layout(std430, binding=7) buffer Positions {
    vec4 pos[];
};

layout(std430, binding=8) buffer Colors {
    vec4 col[];
};

uniform uint max_num;

// Harmonograph parameters (mirrors your WGSL structure)
uniform float A1; uniform float f1; uniform float p1; uniform float d1;
uniform float A2; uniform float f2; uniform float p2; uniform float d2;
uniform float A3; uniform float f3; uniform float p3; uniform float d3;
uniform float A4; uniform float f4; uniform float p4; uniform float d4;

// HSV to RGB conversion (h in degrees 0..360)
vec3 hsv2rgb(float h, float s, float v)
{
    float c = v * s;
    float hp = h / 60.0;
    float x = c * (1.0 - abs(mod(hp, 2.0) - 1.0));
    vec3 rgb;

    if      (hp < 1.0) rgb = vec3(c, x, 0.0);
    else if (hp < 2.0) rgb = vec3(x, c, 0.0);
    else if (hp < 3.0) rgb = vec3(0.0, c, x);
    else if (hp < 4.0) rgb = vec3(0.0, x, c);
    else if (hp < 5.0) rgb = vec3(x, 0.0, c);
    else               rgb = vec3(c, 0.0, x);

    float m = v - c;
    return rgb + vec3(m);
}

void main()
{
    uint idx = gl_GlobalInvocationID.x;
    if (idx >= max_num) return;

    // Match your WGSL: t depends only on idx
    float t = float(idx) * 0.001;
    float PI = 3.14159265;

    // Harmonograph equations (same structure as WGSL)
    float x = A1 * sin(f1 * t + PI * p1) * exp(-d1 * t) +
              A2 * sin(f2 * t + PI * p2) * exp(-d2 * t);

    float y = A3 * sin(f3 * t + PI * p3) * exp(-d3 * t) +
              A4 * sin(f4 * t + PI * p4) * exp(-d4 * t);

    float z = A1 * cos(f1 * t + PI * p1) * exp(-d1 * t) +
              A2 * cos(f2 * t + PI * p2) * exp(-d2 * t);

    pos[idx] = vec4(x, y, z, 1.0);

    // Color: hue from t, just like WGSL
    float hue = mod((t / 20.0) * 360.0, 360.0);
    vec3 rgb = hsv2rgb(hue, 1.0, 1.0);
    col[idx] = vec4(rgb, 1.0);
}
"""

# ============================================================
# Global GL objects
# ============================================================
g_hdc = None
g_hrc = None

vao = ctypes.c_uint(0)
ssbo_pos = ctypes.c_uint(0)
ssbo_col = ctypes.c_uint(0)

draw_program = ctypes.c_uint(0)
compute_program = ctypes.c_uint(0)

# ============================================================
# Context creation helpers
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
    # Create a legacy context first so we can load wglCreateContextAttribsARB
    hrc_old = opengl32.wglCreateContext(hdc)
    if not hrc_old:
        raise ctypes.WinError(ctypes.get_last_error())
    if not opengl32.wglMakeCurrent(hdc, hrc_old):
        raise ctypes.WinError(ctypes.get_last_error())

    # Load required WGL/GL entry points
    init_wgl_and_gl_funcs()

    # Create a 4.6 core profile context
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
# Init GL resources: VAO, SSBOs, programs
# ============================================================
def init_resources(width: int, height: int, max_num: int):
    global draw_program, compute_program, vao, ssbo_pos, ssbo_col

    # In core profile, a VAO must be bound even if you don't use vertex attributes
    glGenVertexArrays(1, ctypes.byref(vao))
    glBindVertexArray(vao.value)

    # Create SSBO for positions: vec4 * max_num (16 bytes each)
    glGenBuffers(1, ctypes.byref(ssbo_pos))
    glBindBuffer(GL_SHADER_STORAGE_BUFFER, ssbo_pos.value)
    glBufferData(GL_SHADER_STORAGE_BUFFER, 16 * max_num, None, GL_DYNAMIC_DRAW)
    glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 7, ssbo_pos.value)

    # Create SSBO for colors: vec4 * max_num (16 bytes each)
    glGenBuffers(1, ctypes.byref(ssbo_col))
    glBindBuffer(GL_SHADER_STORAGE_BUFFER, ssbo_col.value)
    glBufferData(GL_SHADER_STORAGE_BUFFER, 16 * max_num, None, GL_DYNAMIC_DRAW)
    glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 8, ssbo_col.value)

    # Build draw program (VS+FS)
    vs = compile_shader(GL_VERTEX_SHADER, VERT_SRC)
    fs = compile_shader(GL_FRAGMENT_SHADER, FRAG_SRC)
    draw_program = ctypes.c_uint(link_program([vs, fs]))

    # Build compute program (CS)
    cs = compile_shader(GL_COMPUTE_SHADER, COMP_SRC)
    compute_program = ctypes.c_uint(link_program([cs]))

    # Set resolution uniform once
    glUseProgram(draw_program.value)
    loc_res = glGetUniformLocation(draw_program.value, b"resolution")
    if loc_res >= 0:
        glUniform2f(loc_res, float(width), float(height))

# ============================================================
# Helper: set uniforms on the compute program
# ============================================================
def set_uniform_f(prog: int, name: bytes, v: float):
    loc = glGetUniformLocation(prog, name)
    if loc >= 0:
        glUniform1f(loc, ctypes.c_float(v))

def set_uniform_u(prog: int, name: bytes, v: int):
    loc = glGetUniformLocation(prog, name)
    if loc >= 0:
        glUniform1ui(loc, ctypes.c_uint(v))

# ============================================================
# Main
# ============================================================
def main():
    global g_hdc, g_hrc

    WIDTH  = 640
    HEIGHT = 480

    # Recommended: keep this moderate so exp(-d*t) doesn't collapse too much.
    # If you really want 1,000,000, consider reducing the "0.01" scale in COMP_SRC.
    VERTEX_COUNT = 500000

    duration_sec = 60.0

    # WGSL-like parameter defaults (same as your snippet)
    A1, f1, p1, d1 = 50.0, 2.0, 1.0/16.0, 0.02
    A2, f2, p2, d2 = 50.0, 2.0, 3.0/2.0, 0.0315
    A3, f3, p3, d3 = 50.0, 2.0, 13.0/15.0, 0.02
    A4, f4, p4, d4 = 50.0, 2.0, 1.0, 0.02

    # Animation deltas matching your JS
    PI2 = 6.283185307179586

    # ------------------------------------------------------------
    # Create a window
    # ------------------------------------------------------------
    hInstance = kernel32.GetModuleHandleW(None)
    className = "PyGL46ComputeHarmonograph"

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
        0, className, "OpenGL 4.6 Compute Harmonograph (ctypes only)",
        WS_OVERLAPPEDWINDOW,
        CW_USEDEFAULT, CW_USEDEFAULT,
        WIDTH, HEIGHT,
        None, None, hInstance, None
    )
    if not hwnd:
        raise ctypes.WinError(ctypes.get_last_error())

    user32.ShowWindow(hwnd, SW_SHOW)

    # ------------------------------------------------------------
    # Create OpenGL context
    # ------------------------------------------------------------
    g_hdc = user32.GetDC(hwnd)
    if not g_hdc:
        raise ctypes.WinError(ctypes.get_last_error())

    set_pixel_format(g_hdc)
    g_hrc = create_gl46_context(g_hdc)

    ver = opengl32.glGetString(GL_VERSION)
    sl  = opengl32.glGetString(GL_SHADING_LANGUAGE_VERSION)
    print("[GL] Version:", (ver.decode("ascii", "replace") if ver else "(null)"))
    print("[GL] GLSL   :", (sl.decode("ascii", "replace") if sl else "(null)"))
    print("[Info] VERTEX_COUNT:", VERTEX_COUNT)

    opengl32.glViewport(0, 0, WIDTH, HEIGHT)

    init_resources(WIDTH, HEIGHT, VERTEX_COUNT)

    # ------------------------------------------------------------
    # Initial compute dispatch (optional but useful)
    # ------------------------------------------------------------
    glUseProgram(compute_program.value)
    set_uniform_u(compute_program.value, b"max_num", VERTEX_COUNT)

    # Set initial harmonograph uniforms
    set_uniform_f(compute_program.value, b"A1", A1); set_uniform_f(compute_program.value, b"f1", f1); set_uniform_f(compute_program.value, b"p1", p1); set_uniform_f(compute_program.value, b"d1", d1)
    set_uniform_f(compute_program.value, b"A2", A2); set_uniform_f(compute_program.value, b"f2", f2); set_uniform_f(compute_program.value, b"p2", p2); set_uniform_f(compute_program.value, b"d2", d2)
    set_uniform_f(compute_program.value, b"A3", A3); set_uniform_f(compute_program.value, b"f3", f3); set_uniform_f(compute_program.value, b"p3", p3); set_uniform_f(compute_program.value, b"d3", d3)
    set_uniform_f(compute_program.value, b"A4", A4); set_uniform_f(compute_program.value, b"f4", f4); set_uniform_f(compute_program.value, b"p4", p4); set_uniform_f(compute_program.value, b"d4", d4)

    groups_x = (VERTEX_COUNT + 63) // 64
    glDispatchCompute(groups_x, 1, 1)
    glMemoryBarrier(GL_SHADER_STORAGE_BARRIER_BIT)

    # ------------------------------------------------------------
    # Main loop
    # ------------------------------------------------------------
    msg = MSG()
    start = time.perf_counter()
    last_fps_t = start
    frames = 0
    fps = 0

    running = True
    while running:
        # Process messages
        if user32.PeekMessageW(ctypes.byref(msg), None, 0, 0, PM_REMOVE):
            if msg.message == WM_QUIT:
                running = False
            else:
                user32.TranslateMessage(ctypes.byref(msg))
                user32.DispatchMessageW(ctypes.byref(msg))
            continue

        # ESC to exit
        if user32.GetAsyncKeyState(VK_ESCAPE) & 0x8000:
            running = False
            continue

        now = time.perf_counter()
        elapsed = now - start
        if elapsed >= duration_sec:
            running = False

        # --------------------------------------------------------
        # Animate parameters (matching your JS behavior)
        # - f1..f4 random drift: +rand/40, mod 10
        # - p1 increments by 2π * 0.5 / 360
        # --------------------------------------------------------
        f1 = (f1 + random.random() / 40.0) % 10.0
        f2 = (f2 + random.random() / 40.0) % 10.0
        f3 = (f3 + random.random() / 40.0) % 10.0
        f4 = (f4 + random.random() / 40.0) % 10.0
        p1 += (PI2 * 0.5 / 360.0)

        # --------------------------------------------------------
        # Compute pass
        # --------------------------------------------------------
        glUseProgram(compute_program.value)
        set_uniform_u(compute_program.value, b"max_num", VERTEX_COUNT)

        set_uniform_f(compute_program.value, b"A1", A1); set_uniform_f(compute_program.value, b"f1", f1); set_uniform_f(compute_program.value, b"p1", p1); set_uniform_f(compute_program.value, b"d1", d1)
        set_uniform_f(compute_program.value, b"A2", A2); set_uniform_f(compute_program.value, b"f2", f2); set_uniform_f(compute_program.value, b"p2", p2); set_uniform_f(compute_program.value, b"d2", d2)
        set_uniform_f(compute_program.value, b"A3", A3); set_uniform_f(compute_program.value, b"f3", f3); set_uniform_f(compute_program.value, b"p3", p3); set_uniform_f(compute_program.value, b"d3", d3)
        set_uniform_f(compute_program.value, b"A4", A4); set_uniform_f(compute_program.value, b"f4", f4); set_uniform_f(compute_program.value, b"p4", p4); set_uniform_f(compute_program.value, b"d4", d4)

        glDispatchCompute(groups_x, 1, 1)

        # Make SSBO writes visible to the draw stage
        glMemoryBarrier(GL_SHADER_STORAGE_BARRIER_BIT)

        # --------------------------------------------------------
        # Draw pass (line strip)
        # --------------------------------------------------------
        opengl32.glClearColor(0.0, 0.0, 0.0, 1.0)
        opengl32.glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT)

        glUseProgram(draw_program.value)
        glBindVertexArray(vao.value)
        glDrawArrays(GL_LINE_STRIP, 0, VERTEX_COUNT)

        gdi32.SwapBuffers(g_hdc)

        # FPS output
        frames += 1
        if now - last_fps_t >= 1.0:
            fps = frames
            frames = 0
            last_fps_t = now
            sys.stdout.write(f"\rFPS: {fps}   elapsed: {elapsed:5.1f}s   f1..f4=({f1:4.2f},{f2:4.2f},{f3:4.2f},{f4:4.2f})   ")
            sys.stdout.flush()

        kernel32.Sleep(1)

    print("\n[Exit]")

    destroy_context(hwnd, g_hdc, g_hrc)

if __name__ == "__main__":
    main()
