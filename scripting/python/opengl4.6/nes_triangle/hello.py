import ctypes
import os
import sys
import time
from ctypes import wintypes


user32 = ctypes.WinDLL("user32", use_last_error=True)
gdi32 = ctypes.WinDLL("gdi32", use_last_error=True)
opengl32 = ctypes.WinDLL("opengl32", use_last_error=True)
kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)

for name in ("HICON", "HCURSOR", "HBRUSH", "HGLRC"):
    if not hasattr(wintypes, name):
        setattr(wintypes, name, wintypes.HANDLE)

LRESULT = wintypes.LPARAM
WNDPROC = ctypes.WINFUNCTYPE(
    LRESULT, wintypes.HWND, wintypes.UINT, wintypes.WPARAM, wintypes.LPARAM
)

CS_OWNDC = 0x0020
WS_OVERLAPPEDWINDOW = 0x00CF0000
WS_THICKFRAME = 0x00040000
WS_MAXIMIZEBOX = 0x00010000
CW_USEDEFAULT = 0x80000000
SW_SHOW = 5

WM_DESTROY = 0x0002
WM_CLOSE = 0x0010
WM_QUIT = 0x0012
WM_KEYDOWN = 0x0100
WM_SIZE = 0x0005
PM_REMOVE = 0x0001
SIZE_MINIMIZED = 1

VK_ESCAPE = 0x1B
VK_RETURN = 0x0D
VK_RSHIFT = 0xA1
VK_UP = 0x26
VK_DOWN = 0x28
VK_LEFT = 0x25
VK_RIGHT = 0x27

PFD_TYPE_RGBA = 0
PFD_MAIN_PLANE = 0
PFD_DRAW_TO_WINDOW = 0x00000004
PFD_SUPPORT_OPENGL = 0x00000020
PFD_DOUBLEBUFFER = 0x00000001

IDI_APPLICATION = 32512
IDC_ARROW = 32512

WGL_CONTEXT_MAJOR_VERSION_ARB = 0x2091
WGL_CONTEXT_MINOR_VERSION_ARB = 0x2092
WGL_CONTEXT_FLAGS_ARB = 0x2094
WGL_CONTEXT_PROFILE_MASK_ARB = 0x9126
WGL_CONTEXT_CORE_PROFILE_BIT_ARB = 0x00000001

GL_COLOR_BUFFER_BIT = 0x00004000
GL_TRIANGLE_STRIP = 0x0005
GL_FLOAT = 0x1406
GL_FALSE = 0
GL_TRUE = 1
GL_ARRAY_BUFFER = 0x8892
GL_STATIC_DRAW = 0x88E4
GL_VERTEX_SHADER = 0x8B31
GL_FRAGMENT_SHADER = 0x8B30
GL_COMPILE_STATUS = 0x8B81
GL_LINK_STATUS = 0x8B82
GL_INFO_LOG_LENGTH = 0x8B84
GL_VERSION = 0x1F02
GL_SHADING_LANGUAGE_VERSION = 0x8B8C
GL_TEXTURE0 = 0x84C0
GL_TEXTURE_2D = 0x0DE1
GL_TEXTURE_MIN_FILTER = 0x2801
GL_TEXTURE_MAG_FILTER = 0x2800
GL_TEXTURE_WRAP_S = 0x2802
GL_TEXTURE_WRAP_T = 0x2803
GL_TEXTURE_BASE_LEVEL = 0x813C
GL_TEXTURE_MAX_LEVEL = 0x813D
GL_CLAMP_TO_EDGE = 0x812F
GL_NEAREST = 0x2600
GL_BGRA = 0x80E1
GL_RGBA8 = 0x8058
GL_UNSIGNED_BYTE = 0x1401

NES_WIDTH = 256
NES_HEIGHT = 240
SCREEN_SCALE = 2
WINDOW_WIDTH = NES_WIDTH * SCREEN_SCALE
WINDOW_HEIGHT = NES_HEIGHT * SCREEN_SCALE
FRAMEBUFFER_SIZE = NES_WIDTH * NES_HEIGHT
FRAME_US = 1_000_000.0 / 60.0988

FLAG_C = 0x01
FLAG_Z = 0x02
FLAG_I = 0x04
FLAG_D = 0x08
FLAG_B = 0x10
FLAG_U = 0x20
FLAG_V = 0x40
FLAG_N = 0x80

PPUCTRL_VRAM_INC = 0x04
PPUCTRL_SPR_ADDR = 0x08
PPUCTRL_BG_ADDR = 0x10
PPUCTRL_SPR_SIZE = 0x20
PPUCTRL_NMI_ENABLE = 0x80

PPUMASK_BG_LEFT = 0x02
PPUMASK_SPR_LEFT = 0x04
PPUMASK_BG_ENABLE = 0x08
PPUMASK_SPR_ENABLE = 0x10

PPUSTAT_OVERFLOW = 0x20
PPUSTAT_SPR0_HIT = 0x40
PPUSTAT_VBLANK = 0x80

MIRROR_HORIZONTAL = 0
MIRROR_VERTICAL = 1
MIRROR_SINGLE_LO = 2
MIRROR_SINGLE_HI = 3
MIRROR_FOUR_SCREEN = 4

MAPPER_NROM = 0
MAPPER_GXROM = 66

BTN_A = 0x80
BTN_B = 0x40
BTN_SELECT = 0x20
BTN_START = 0x10
BTN_UP = 0x08
BTN_DOWN = 0x04
BTN_LEFT = 0x02
BTN_RIGHT = 0x01

(AM_IMP, AM_ACC, AM_IMM, AM_ZPG, AM_ZPX, AM_ZPY, AM_REL, AM_ABS, AM_ABX, AM_ABY, AM_IND, AM_IZX, AM_IZY) = range(13)
(INS_ADC, INS_AND, INS_ASL, INS_BCC, INS_BCS, INS_BEQ, INS_BIT, INS_BMI,
 INS_BNE, INS_BPL, INS_BRK, INS_BVC, INS_BVS, INS_CLC, INS_CLD, INS_CLI,
 INS_CLV, INS_CMP, INS_CPX, INS_CPY, INS_DEC, INS_DEX, INS_DEY, INS_EOR,
 INS_INC, INS_INX, INS_INY, INS_JMP, INS_JSR, INS_LDA, INS_LDX, INS_LDY,
 INS_LSR, INS_NOP, INS_ORA, INS_PHA, INS_PHP, INS_PLA, INS_PLP, INS_ROL,
 INS_ROR, INS_RTI, INS_RTS, INS_SBC, INS_SEC, INS_SED, INS_SEI, INS_STA,
 INS_STX, INS_STY, INS_TAX, INS_TAY, INS_TSX, INS_TXA, INS_TXS, INS_TYA,
 INS_XXX) = range(57)


class WNDCLASSEXW(ctypes.Structure):
    _fields_ = [
        ("cbSize", wintypes.UINT),
        ("style", wintypes.UINT),
        ("lpfnWndProc", WNDPROC),
        ("cbClsExtra", ctypes.c_int),
        ("cbWndExtra", ctypes.c_int),
        ("hInstance", wintypes.HINSTANCE),
        ("hIcon", wintypes.HICON),
        ("hCursor", wintypes.HCURSOR),
        ("hbrBackground", wintypes.HBRUSH),
        ("lpszMenuName", wintypes.LPCWSTR),
        ("lpszClassName", wintypes.LPCWSTR),
        ("hIconSm", wintypes.HICON),
    ]


class MSG(ctypes.Structure):
    _fields_ = [
        ("hwnd", wintypes.HWND),
        ("message", wintypes.UINT),
        ("wParam", wintypes.WPARAM),
        ("lParam", wintypes.LPARAM),
        ("time", wintypes.DWORD),
        ("pt", wintypes.POINT),
    ]


class RECT(ctypes.Structure):
    _fields_ = [
        ("left", ctypes.c_long),
        ("top", ctypes.c_long),
        ("right", ctypes.c_long),
        ("bottom", ctypes.c_long),
    ]


class PIXELFORMATDESCRIPTOR(ctypes.Structure):
    _fields_ = [
        ("nSize", wintypes.WORD),
        ("nVersion", wintypes.WORD),
        ("dwFlags", wintypes.DWORD),
        ("iPixelType", ctypes.c_ubyte),
        ("cColorBits", ctypes.c_ubyte),
        ("cRedBits", ctypes.c_ubyte),
        ("cRedShift", ctypes.c_ubyte),
        ("cGreenBits", ctypes.c_ubyte),
        ("cGreenShift", ctypes.c_ubyte),
        ("cBlueBits", ctypes.c_ubyte),
        ("cBlueShift", ctypes.c_ubyte),
        ("cAlphaBits", ctypes.c_ubyte),
        ("cAlphaShift", ctypes.c_ubyte),
        ("cAccumBits", ctypes.c_ubyte),
        ("cAccumRedBits", ctypes.c_ubyte),
        ("cAccumGreenBits", ctypes.c_ubyte),
        ("cAccumBlueBits", ctypes.c_ubyte),
        ("cAccumAlphaBits", ctypes.c_ubyte),
        ("cDepthBits", ctypes.c_ubyte),
        ("cStencilBits", ctypes.c_ubyte),
        ("cAuxBuffers", ctypes.c_ubyte),
        ("iLayerType", ctypes.c_ubyte),
        ("bReserved", ctypes.c_ubyte),
        ("dwLayerMask", wintypes.DWORD),
        ("dwVisibleMask", wintypes.DWORD),
        ("dwDamageMask", wintypes.DWORD),
    ]


kernel32.GetModuleHandleW.restype = wintypes.HMODULE
kernel32.GetModuleHandleW.argtypes = (wintypes.LPCWSTR,)
kernel32.Sleep.restype = None
kernel32.Sleep.argtypes = (wintypes.DWORD,)

user32.DefWindowProcW.restype = LRESULT
user32.DefWindowProcW.argtypes = (
    wintypes.HWND,
    wintypes.UINT,
    wintypes.WPARAM,
    wintypes.LPARAM,
)
user32.RegisterClassExW.restype = wintypes.ATOM
user32.RegisterClassExW.argtypes = (ctypes.POINTER(WNDCLASSEXW),)
user32.CreateWindowExW.restype = wintypes.HWND
user32.CreateWindowExW.argtypes = (
    wintypes.DWORD,
    wintypes.LPCWSTR,
    wintypes.LPCWSTR,
    wintypes.DWORD,
    ctypes.c_int,
    ctypes.c_int,
    ctypes.c_int,
    ctypes.c_int,
    wintypes.HWND,
    wintypes.HMENU,
    wintypes.HINSTANCE,
    wintypes.LPVOID,
)
user32.ShowWindow.restype = wintypes.BOOL
user32.ShowWindow.argtypes = (wintypes.HWND, ctypes.c_int)
user32.PeekMessageW.restype = wintypes.BOOL
user32.PeekMessageW.argtypes = (
    ctypes.POINTER(MSG),
    wintypes.HWND,
    wintypes.UINT,
    wintypes.UINT,
    wintypes.UINT,
)
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
user32.AdjustWindowRect.restype = wintypes.BOOL
user32.AdjustWindowRect.argtypes = (ctypes.POINTER(RECT), wintypes.DWORD, wintypes.BOOL)
user32.GetClientRect.restype = wintypes.BOOL
user32.GetClientRect.argtypes = (wintypes.HWND, ctypes.POINTER(RECT))
user32.GetAsyncKeyState.restype = ctypes.c_short
user32.GetAsyncKeyState.argtypes = (ctypes.c_int,)

gdi32.ChoosePixelFormat.restype = ctypes.c_int
gdi32.ChoosePixelFormat.argtypes = (wintypes.HDC, ctypes.POINTER(PIXELFORMATDESCRIPTOR))
gdi32.SetPixelFormat.restype = wintypes.BOOL
gdi32.SetPixelFormat.argtypes = (
    wintypes.HDC,
    ctypes.c_int,
    ctypes.POINTER(PIXELFORMATDESCRIPTOR),
)
gdi32.SwapBuffers.restype = wintypes.BOOL
gdi32.SwapBuffers.argtypes = (wintypes.HDC,)

opengl32.wglCreateContext.restype = wintypes.HGLRC
opengl32.wglCreateContext.argtypes = (wintypes.HDC,)
opengl32.wglMakeCurrent.restype = wintypes.BOOL
opengl32.wglMakeCurrent.argtypes = (wintypes.HDC, wintypes.HGLRC)
opengl32.wglDeleteContext.restype = wintypes.BOOL
opengl32.wglDeleteContext.argtypes = (wintypes.HGLRC,)
opengl32.wglGetProcAddress.restype = ctypes.c_void_p
opengl32.wglGetProcAddress.argtypes = (ctypes.c_char_p,)

opengl32.glClearColor.restype = None
opengl32.glClearColor.argtypes = (ctypes.c_float, ctypes.c_float, ctypes.c_float, ctypes.c_float)
opengl32.glClear.restype = None
opengl32.glClear.argtypes = (wintypes.DWORD,)
opengl32.glViewport.restype = None
opengl32.glViewport.argtypes = (ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_int)
opengl32.glGetString.restype = ctypes.c_char_p
opengl32.glGetString.argtypes = (wintypes.DWORD,)
opengl32.glGenTextures.restype = None
opengl32.glGenTextures.argtypes = (ctypes.c_int, ctypes.POINTER(ctypes.c_uint))
opengl32.glBindTexture.restype = None
opengl32.glBindTexture.argtypes = (ctypes.c_uint, ctypes.c_uint)
opengl32.glTexParameteri.restype = None
opengl32.glTexParameteri.argtypes = (ctypes.c_uint, ctypes.c_uint, ctypes.c_int)
opengl32.glTexImage2D.restype = None
opengl32.glTexImage2D.argtypes = (
    ctypes.c_uint, ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_int,
    ctypes.c_int, ctypes.c_uint, ctypes.c_uint, ctypes.c_void_p,
)
opengl32.glTexSubImage2D.restype = None
opengl32.glTexSubImage2D.argtypes = (
    ctypes.c_uint, ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_int,
    ctypes.c_int, ctypes.c_uint, ctypes.c_uint, ctypes.c_void_p,
)
opengl32.glDeleteTextures.restype = None
opengl32.glDeleteTextures.argtypes = (ctypes.c_int, ctypes.POINTER(ctypes.c_uint))


def _valid_wgl_addr(addr):
    return addr not in (0, 1, 2, 3, 0xFFFFFFFF)


def get_gl_func(name, restype, argtypes, is_stdcall=False):
    addr = opengl32.wglGetProcAddress(name.encode("ascii"))
    if not addr or not _valid_wgl_addr(int(addr)):
        raise RuntimeError(f"wglGetProcAddress failed: {name}")
    factory = ctypes.WINFUNCTYPE if is_stdcall else ctypes.CFUNCTYPE
    fn = factory(restype, *argtypes)(addr)
    fn.__name__ = name
    return fn


wglCreateContextAttribsARB = None
glGenVertexArrays = None
glBindVertexArray = None
glGenBuffers = None
glBindBuffer = None
glBufferData = None
glCreateShader = None
glShaderSource = None
glCompileShader = None
glGetShaderiv = None
glGetShaderInfoLog = None
glCreateProgram = None
glAttachShader = None
glLinkProgram = None
glUseProgram = None
glGetProgramiv = None
glGetProgramInfoLog = None
glGetUniformLocation = None
glUniform1i = None
glVertexAttribPointer = None
glEnableVertexAttribArray = None
glDrawArrays = None
glActiveTexture = None
glDeleteBuffers = None
glDeleteVertexArrays = None
glDeleteShader = None
glDeleteProgram = None


def init_wgl_and_gl_funcs():
    global wglCreateContextAttribsARB
    global glGenVertexArrays, glBindVertexArray
    global glGenBuffers, glBindBuffer, glBufferData
    global glCreateShader, glShaderSource, glCompileShader, glGetShaderiv, glGetShaderInfoLog
    global glCreateProgram, glAttachShader, glLinkProgram, glUseProgram
    global glGetProgramiv, glGetProgramInfoLog, glGetUniformLocation, glUniform1i
    global glVertexAttribPointer, glEnableVertexAttribArray, glDrawArrays
    global glActiveTexture, glDeleteBuffers, glDeleteVertexArrays, glDeleteShader, glDeleteProgram

    wglCreateContextAttribsARB = get_gl_func(
        "wglCreateContextAttribsARB",
        wintypes.HGLRC,
        (wintypes.HDC, wintypes.HGLRC, ctypes.POINTER(ctypes.c_int)),
        is_stdcall=True,
    )
    glGenVertexArrays = get_gl_func("glGenVertexArrays", None, (ctypes.c_int, ctypes.POINTER(ctypes.c_uint)))
    glBindVertexArray = get_gl_func("glBindVertexArray", None, (ctypes.c_uint,))
    glGenBuffers = get_gl_func("glGenBuffers", None, (ctypes.c_int, ctypes.POINTER(ctypes.c_uint)))
    glBindBuffer = get_gl_func("glBindBuffer", None, (ctypes.c_uint, ctypes.c_uint))
    glBufferData = get_gl_func("glBufferData", None, (ctypes.c_uint, ctypes.c_size_t, ctypes.c_void_p, ctypes.c_uint))
    glCreateShader = get_gl_func("glCreateShader", ctypes.c_uint, (ctypes.c_uint,))
    glShaderSource = get_gl_func(
        "glShaderSource",
        None,
        (ctypes.c_uint, ctypes.c_int, ctypes.POINTER(ctypes.c_char_p), ctypes.POINTER(ctypes.c_int)),
    )
    glCompileShader = get_gl_func("glCompileShader", None, (ctypes.c_uint,))
    glGetShaderiv = get_gl_func("glGetShaderiv", None, (ctypes.c_uint, ctypes.c_uint, ctypes.POINTER(ctypes.c_int)))
    glGetShaderInfoLog = get_gl_func(
        "glGetShaderInfoLog",
        None,
        (ctypes.c_uint, ctypes.c_int, ctypes.POINTER(ctypes.c_int), ctypes.c_char_p),
    )
    glCreateProgram = get_gl_func("glCreateProgram", ctypes.c_uint, ())
    glAttachShader = get_gl_func("glAttachShader", None, (ctypes.c_uint, ctypes.c_uint))
    glLinkProgram = get_gl_func("glLinkProgram", None, (ctypes.c_uint,))
    glUseProgram = get_gl_func("glUseProgram", None, (ctypes.c_uint,))
    glGetProgramiv = get_gl_func("glGetProgramiv", None, (ctypes.c_uint, ctypes.c_uint, ctypes.POINTER(ctypes.c_int)))
    glGetProgramInfoLog = get_gl_func(
        "glGetProgramInfoLog",
        None,
        (ctypes.c_uint, ctypes.c_int, ctypes.POINTER(ctypes.c_int), ctypes.c_char_p),
    )
    glGetUniformLocation = get_gl_func("glGetUniformLocation", ctypes.c_int, (ctypes.c_uint, ctypes.c_char_p))
    glUniform1i = get_gl_func("glUniform1i", None, (ctypes.c_int, ctypes.c_int))
    glVertexAttribPointer = get_gl_func(
        "glVertexAttribPointer",
        None,
        (ctypes.c_uint, ctypes.c_int, ctypes.c_uint, ctypes.c_ubyte, ctypes.c_int, ctypes.c_void_p),
    )
    glEnableVertexAttribArray = get_gl_func("glEnableVertexAttribArray", None, (ctypes.c_uint,))
    glDrawArrays = get_gl_func("glDrawArrays", None, (ctypes.c_uint, ctypes.c_int, ctypes.c_int))
    glActiveTexture = get_gl_func("glActiveTexture", None, (ctypes.c_uint,))
    glDeleteBuffers = get_gl_func("glDeleteBuffers", None, (ctypes.c_int, ctypes.POINTER(ctypes.c_uint)))
    glDeleteVertexArrays = get_gl_func("glDeleteVertexArrays", None, (ctypes.c_int, ctypes.POINTER(ctypes.c_uint)))
    glDeleteShader = get_gl_func("glDeleteShader", None, (ctypes.c_uint,))
    glDeleteProgram = get_gl_func("glDeleteProgram", None, (ctypes.c_uint,))


VERT_SRC = r"""
#version 460 core
layout(location = 0) in vec3 position;
layout(location = 1) in vec2 texcoord;
out vec2 v_texcoord;
void main()
{
    v_texcoord = texcoord;
    gl_Position = vec4(position, 1.0);
}
"""

FRAG_SRC = r"""
#version 460 core
in vec2 v_texcoord;
uniform sampler2D u_texture;
layout(location = 0) out vec4 out_color;
void main()
{
    out_color = texture(u_texture, v_texcoord);
}
"""


def compile_shader(shader_type, source):
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
        buf = ctypes.create_string_buffer(max(log_len.value, 1))
        out_len = ctypes.c_int(0)
        glGetShaderInfoLog(shader, len(buf), ctypes.byref(out_len), buf)
        raise RuntimeError("Shader compile failed:\n" + buf.value.decode("utf-8", "replace"))
    return shader


def link_program(vs, fs):
    program = glCreateProgram()
    glAttachShader(program, vs)
    glAttachShader(program, fs)
    glLinkProgram(program)
    status = ctypes.c_int(0)
    glGetProgramiv(program, GL_LINK_STATUS, ctypes.byref(status))
    if status.value != GL_TRUE:
        log_len = ctypes.c_int(0)
        glGetProgramiv(program, GL_INFO_LOG_LENGTH, ctypes.byref(log_len))
        buf = ctypes.create_string_buffer(max(log_len.value, 1))
        out_len = ctypes.c_int(0)
        glGetProgramInfoLog(program, len(buf), ctypes.byref(out_len), buf)
        raise RuntimeError("Program link failed:\n" + buf.value.decode("utf-8", "replace"))
    return program


OPCODE_TABLE = (
    (INS_BRK, AM_IMP, 7, 0), (INS_ORA, AM_IZX, 6, 0), (INS_XXX, AM_IMP, 2, 0), (INS_XXX, AM_IMP, 2, 0),
    (INS_XXX, AM_IMP, 2, 0), (INS_ORA, AM_ZPG, 3, 0), (INS_ASL, AM_ZPG, 5, 0), (INS_XXX, AM_IMP, 2, 0),
    (INS_PHP, AM_IMP, 3, 0), (INS_ORA, AM_IMM, 2, 0), (INS_ASL, AM_ACC, 2, 0), (INS_XXX, AM_IMP, 2, 0),
    (INS_XXX, AM_IMP, 2, 0), (INS_ORA, AM_ABS, 4, 0), (INS_ASL, AM_ABS, 6, 0), (INS_XXX, AM_IMP, 2, 0),
    (INS_BPL, AM_REL, 2, 0), (INS_ORA, AM_IZY, 5, 1), (INS_XXX, AM_IMP, 2, 0), (INS_XXX, AM_IMP, 2, 0),
    (INS_XXX, AM_IMP, 2, 0), (INS_ORA, AM_ZPX, 4, 0), (INS_ASL, AM_ZPX, 6, 0), (INS_XXX, AM_IMP, 2, 0),
    (INS_CLC, AM_IMP, 2, 0), (INS_ORA, AM_ABY, 4, 1), (INS_XXX, AM_IMP, 2, 0), (INS_XXX, AM_IMP, 2, 0),
    (INS_XXX, AM_IMP, 2, 0), (INS_ORA, AM_ABX, 4, 1), (INS_ASL, AM_ABX, 7, 0), (INS_XXX, AM_IMP, 2, 0),
    (INS_JSR, AM_ABS, 6, 0), (INS_AND, AM_IZX, 6, 0), (INS_XXX, AM_IMP, 2, 0), (INS_XXX, AM_IMP, 2, 0),
    (INS_BIT, AM_ZPG, 3, 0), (INS_AND, AM_ZPG, 3, 0), (INS_ROL, AM_ZPG, 5, 0), (INS_XXX, AM_IMP, 2, 0),
    (INS_PLP, AM_IMP, 4, 0), (INS_AND, AM_IMM, 2, 0), (INS_ROL, AM_ACC, 2, 0), (INS_XXX, AM_IMP, 2, 0),
    (INS_BIT, AM_ABS, 4, 0), (INS_AND, AM_ABS, 4, 0), (INS_ROL, AM_ABS, 6, 0), (INS_XXX, AM_IMP, 2, 0),
    (INS_BMI, AM_REL, 2, 0), (INS_AND, AM_IZY, 5, 1), (INS_XXX, AM_IMP, 2, 0), (INS_XXX, AM_IMP, 2, 0),
    (INS_XXX, AM_IMP, 2, 0), (INS_AND, AM_ZPX, 4, 0), (INS_ROL, AM_ZPX, 6, 0), (INS_XXX, AM_IMP, 2, 0),
    (INS_SEC, AM_IMP, 2, 0), (INS_AND, AM_ABY, 4, 1), (INS_XXX, AM_IMP, 2, 0), (INS_XXX, AM_IMP, 2, 0),
    (INS_XXX, AM_IMP, 2, 0), (INS_AND, AM_ABX, 4, 1), (INS_ROL, AM_ABX, 7, 0), (INS_XXX, AM_IMP, 2, 0),
    (INS_RTI, AM_IMP, 6, 0), (INS_EOR, AM_IZX, 6, 0), (INS_XXX, AM_IMP, 2, 0), (INS_XXX, AM_IMP, 2, 0),
    (INS_XXX, AM_IMP, 2, 0), (INS_EOR, AM_ZPG, 3, 0), (INS_LSR, AM_ZPG, 5, 0), (INS_XXX, AM_IMP, 2, 0),
    (INS_PHA, AM_IMP, 3, 0), (INS_EOR, AM_IMM, 2, 0), (INS_LSR, AM_ACC, 2, 0), (INS_XXX, AM_IMP, 2, 0),
    (INS_JMP, AM_ABS, 3, 0), (INS_EOR, AM_ABS, 4, 0), (INS_LSR, AM_ABS, 6, 0), (INS_XXX, AM_IMP, 2, 0),
    (INS_BVC, AM_REL, 2, 0), (INS_EOR, AM_IZY, 5, 1), (INS_XXX, AM_IMP, 2, 0), (INS_XXX, AM_IMP, 2, 0),
    (INS_XXX, AM_IMP, 2, 0), (INS_EOR, AM_ZPX, 4, 0), (INS_LSR, AM_ZPX, 6, 0), (INS_XXX, AM_IMP, 2, 0),
    (INS_CLI, AM_IMP, 2, 0), (INS_EOR, AM_ABY, 4, 1), (INS_XXX, AM_IMP, 2, 0), (INS_XXX, AM_IMP, 2, 0),
    (INS_XXX, AM_IMP, 2, 0), (INS_EOR, AM_ABX, 4, 1), (INS_LSR, AM_ABX, 7, 0), (INS_XXX, AM_IMP, 2, 0),
    (INS_RTS, AM_IMP, 6, 0), (INS_ADC, AM_IZX, 6, 0), (INS_XXX, AM_IMP, 2, 0), (INS_XXX, AM_IMP, 2, 0),
    (INS_XXX, AM_IMP, 2, 0), (INS_ADC, AM_ZPG, 3, 0), (INS_ROR, AM_ZPG, 5, 0), (INS_XXX, AM_IMP, 2, 0),
    (INS_PLA, AM_IMP, 4, 0), (INS_ADC, AM_IMM, 2, 0), (INS_ROR, AM_ACC, 2, 0), (INS_XXX, AM_IMP, 2, 0),
    (INS_JMP, AM_IND, 5, 0), (INS_ADC, AM_ABS, 4, 0), (INS_ROR, AM_ABS, 6, 0), (INS_XXX, AM_IMP, 2, 0),
    (INS_BVS, AM_REL, 2, 0), (INS_ADC, AM_IZY, 5, 1), (INS_XXX, AM_IMP, 2, 0), (INS_XXX, AM_IMP, 2, 0),
    (INS_XXX, AM_IMP, 2, 0), (INS_ADC, AM_ZPX, 4, 0), (INS_ROR, AM_ZPX, 6, 0), (INS_XXX, AM_IMP, 2, 0),
    (INS_SEI, AM_IMP, 2, 0), (INS_ADC, AM_ABY, 4, 1), (INS_XXX, AM_IMP, 2, 0), (INS_XXX, AM_IMP, 2, 0),
    (INS_XXX, AM_IMP, 2, 0), (INS_ADC, AM_ABX, 4, 1), (INS_ROR, AM_ABX, 7, 0), (INS_XXX, AM_IMP, 2, 0),
    (INS_XXX, AM_IMP, 2, 0), (INS_STA, AM_IZX, 6, 0), (INS_XXX, AM_IMP, 2, 0), (INS_XXX, AM_IMP, 2, 0),
    (INS_STY, AM_ZPG, 3, 0), (INS_STA, AM_ZPG, 3, 0), (INS_STX, AM_ZPG, 3, 0), (INS_XXX, AM_IMP, 2, 0),
    (INS_DEY, AM_IMP, 2, 0), (INS_XXX, AM_IMP, 2, 0), (INS_TXA, AM_IMP, 2, 0), (INS_XXX, AM_IMP, 2, 0),
    (INS_STY, AM_ABS, 4, 0), (INS_STA, AM_ABS, 4, 0), (INS_STX, AM_ABS, 4, 0), (INS_XXX, AM_IMP, 2, 0),
    (INS_BCC, AM_REL, 2, 0), (INS_STA, AM_IZY, 6, 0), (INS_XXX, AM_IMP, 2, 0), (INS_XXX, AM_IMP, 2, 0),
    (INS_STY, AM_ZPX, 4, 0), (INS_STA, AM_ZPX, 4, 0), (INS_STX, AM_ZPY, 4, 0), (INS_XXX, AM_IMP, 2, 0),
    (INS_TYA, AM_IMP, 2, 0), (INS_STA, AM_ABY, 5, 0), (INS_TXS, AM_IMP, 2, 0), (INS_XXX, AM_IMP, 2, 0),
    (INS_XXX, AM_IMP, 2, 0), (INS_STA, AM_ABX, 5, 0), (INS_XXX, AM_IMP, 2, 0), (INS_XXX, AM_IMP, 2, 0),
    (INS_LDY, AM_IMM, 2, 0), (INS_LDA, AM_IZX, 6, 0), (INS_LDX, AM_IMM, 2, 0), (INS_XXX, AM_IMP, 2, 0),
    (INS_LDY, AM_ZPG, 3, 0), (INS_LDA, AM_ZPG, 3, 0), (INS_LDX, AM_ZPG, 3, 0), (INS_XXX, AM_IMP, 2, 0),
    (INS_TAY, AM_IMP, 2, 0), (INS_LDA, AM_IMM, 2, 0), (INS_TAX, AM_IMP, 2, 0), (INS_XXX, AM_IMP, 2, 0),
    (INS_LDY, AM_ABS, 4, 0), (INS_LDA, AM_ABS, 4, 0), (INS_LDX, AM_ABS, 4, 0), (INS_XXX, AM_IMP, 2, 0),
    (INS_BCS, AM_REL, 2, 0), (INS_LDA, AM_IZY, 5, 1), (INS_XXX, AM_IMP, 2, 0), (INS_XXX, AM_IMP, 2, 0),
    (INS_LDY, AM_ZPX, 4, 0), (INS_LDA, AM_ZPX, 4, 0), (INS_LDX, AM_ZPY, 4, 0), (INS_XXX, AM_IMP, 2, 0),
    (INS_CLV, AM_IMP, 2, 0), (INS_LDA, AM_ABY, 4, 1), (INS_TSX, AM_IMP, 2, 0), (INS_XXX, AM_IMP, 2, 0),
    (INS_LDY, AM_ABX, 4, 1), (INS_LDA, AM_ABX, 4, 1), (INS_LDX, AM_ABY, 4, 1), (INS_XXX, AM_IMP, 2, 0),
    (INS_CPY, AM_IMM, 2, 0), (INS_CMP, AM_IZX, 6, 0), (INS_XXX, AM_IMP, 2, 0), (INS_XXX, AM_IMP, 2, 0),
    (INS_CPY, AM_ZPG, 3, 0), (INS_CMP, AM_ZPG, 3, 0), (INS_DEC, AM_ZPG, 5, 0), (INS_XXX, AM_IMP, 2, 0),
    (INS_INY, AM_IMP, 2, 0), (INS_CMP, AM_IMM, 2, 0), (INS_DEX, AM_IMP, 2, 0), (INS_XXX, AM_IMP, 2, 0),
    (INS_CPY, AM_ABS, 4, 0), (INS_CMP, AM_ABS, 4, 0), (INS_DEC, AM_ABS, 6, 0), (INS_XXX, AM_IMP, 2, 0),
    (INS_BNE, AM_REL, 2, 0), (INS_CMP, AM_IZY, 5, 1), (INS_XXX, AM_IMP, 2, 0), (INS_XXX, AM_IMP, 2, 0),
    (INS_XXX, AM_IMP, 2, 0), (INS_CMP, AM_ZPX, 4, 0), (INS_DEC, AM_ZPX, 6, 0), (INS_XXX, AM_IMP, 2, 0),
    (INS_CLD, AM_IMP, 2, 0), (INS_CMP, AM_ABY, 4, 1), (INS_XXX, AM_IMP, 2, 0), (INS_XXX, AM_IMP, 2, 0),
    (INS_XXX, AM_IMP, 2, 0), (INS_CMP, AM_ABX, 4, 1), (INS_DEC, AM_ABX, 7, 0), (INS_XXX, AM_IMP, 2, 0),
    (INS_CPX, AM_IMM, 2, 0), (INS_SBC, AM_IZX, 6, 0), (INS_XXX, AM_IMP, 2, 0), (INS_XXX, AM_IMP, 2, 0),
    (INS_CPX, AM_ZPG, 3, 0), (INS_SBC, AM_ZPG, 3, 0), (INS_INC, AM_ZPG, 5, 0), (INS_XXX, AM_IMP, 2, 0),
    (INS_INX, AM_IMP, 2, 0), (INS_SBC, AM_IMM, 2, 0), (INS_NOP, AM_IMP, 2, 0), (INS_XXX, AM_IMP, 2, 0),
    (INS_CPX, AM_ABS, 4, 0), (INS_SBC, AM_ABS, 4, 0), (INS_INC, AM_ABS, 6, 0), (INS_XXX, AM_IMP, 2, 0),
    (INS_BEQ, AM_REL, 2, 0), (INS_SBC, AM_IZY, 5, 1), (INS_XXX, AM_IMP, 2, 0), (INS_XXX, AM_IMP, 2, 0),
    (INS_XXX, AM_IMP, 2, 0), (INS_SBC, AM_ZPX, 4, 0), (INS_INC, AM_ZPX, 6, 0), (INS_XXX, AM_IMP, 2, 0),
    (INS_SED, AM_IMP, 2, 0), (INS_SBC, AM_ABY, 4, 1), (INS_XXX, AM_IMP, 2, 0), (INS_XXX, AM_IMP, 2, 0),
    (INS_XXX, AM_IMP, 2, 0), (INS_SBC, AM_ABX, 4, 1), (INS_INC, AM_ABX, 7, 0), (INS_XXX, AM_IMP, 2, 0),
)

NES_PALETTE = (
    0xFF666666, 0xFF002A88, 0xFF1412A7, 0xFF3B00A4, 0xFF5C007E, 0xFF6E0040, 0xFF6C0600, 0xFF561D00,
    0xFF333500, 0xFF0B4800, 0xFF005200, 0xFF004F08, 0xFF00404D, 0xFF000000, 0xFF000000, 0xFF000000,
    0xFFADADAD, 0xFF155FD9, 0xFF4240FF, 0xFF7527FE, 0xFFA01ACC, 0xFFB71E7B, 0xFFB53120, 0xFF994E00,
    0xFF6B6D00, 0xFF388700, 0xFF0C9300, 0xFF008F32, 0xFF007C8D, 0xFF000000, 0xFF000000, 0xFF000000,
    0xFFFFFEFF, 0xFF64B0FF, 0xFF9290FF, 0xFFC676FF, 0xFFF36AFF, 0xFFFE6ECC, 0xFFFE8170, 0xFFEA9E22,
    0xFFBCBE00, 0xFF88D800, 0xFF5CE430, 0xFF45E082, 0xFF48CDDE, 0xFF4F4F4F, 0xFF000000, 0xFF000000,
    0xFFFFFEFF, 0xFFC0DFFF, 0xFFD3D2FF, 0xFFE8C8FF, 0xFFFBC2FF, 0xFFFEC4EA, 0xFFFECCC5, 0xFFF7D8A5,
    0xFFE4E594, 0xFFCFEF96, 0xFFBDF4AB, 0xFFB3F3CC, 0xFFB5EBF2, 0xFFB8B8B8, 0xFF000000, 0xFF000000,
)


class CPU:
    __slots__ = ("a", "x", "y", "sp", "pc", "p", "cycles", "stall", "nmi_pending", "irq_pending")

    def __init__(self):
        self.a = 0
        self.x = 0
        self.y = 0
        self.sp = 0
        self.pc = 0
        self.p = 0
        self.cycles = 0
        self.stall = 0
        self.nmi_pending = 0
        self.irq_pending = 0


class PPU:
    __slots__ = (
        "ctrl", "mask", "status", "oam_addr", "v", "t", "fine_x", "w", "data_buf",
        "oam", "vram", "palette", "scanline", "cycle", "frame_count", "frame_ready",
        "nmi_occurred", "nmi_output", "framebuffer"
    )

    def __init__(self):
        self.ctrl = 0
        self.mask = 0
        self.status = 0
        self.oam_addr = 0
        self.v = 0
        self.t = 0
        self.fine_x = 0
        self.w = 0
        self.data_buf = 0
        self.oam = bytearray(256)
        self.vram = bytearray(0x800)
        self.palette = bytearray(32)
        self.scanline = -1
        self.cycle = 0
        self.frame_count = 0
        self.frame_ready = 0
        self.nmi_occurred = 0
        self.nmi_output = 0
        self.framebuffer = (ctypes.c_uint32 * FRAMEBUFFER_SIZE)()


class Cartridge:
    __slots__ = (
        "prg_rom", "chr_rom", "prg_size", "chr_size", "prg_banks", "chr_banks",
        "mapper", "mirror", "prg_bank_select", "chr_bank_select", "chr_ram", "has_chr_ram"
    )

    def __init__(self):
        self.prg_rom = b""
        self.chr_rom = b""
        self.prg_size = 0
        self.chr_size = 0
        self.prg_banks = 0
        self.chr_banks = 0
        self.mapper = 0
        self.mirror = 0
        self.prg_bank_select = 0
        self.chr_bank_select = 0
        self.chr_ram = bytearray(0x2000)
        self.has_chr_ram = False


class Bus:
    __slots__ = (
        "cpu", "ppu", "cart", "ram", "controller", "controller_latch", "controller_strobe",
        "dma_page", "dma_addr", "dma_data", "dma_transfer", "dma_dummy", "system_cycles"
    )

    def __init__(self):
        self.cpu = CPU()
        self.ppu = PPU()
        self.cart = None
        self.ram = bytearray(0x800)
        self.controller = bytearray(2)
        self.controller_latch = bytearray(2)
        self.controller_strobe = 0
        self.dma_page = 0
        self.dma_addr = 0
        self.dma_data = 0
        self.dma_transfer = 0
        self.dma_dummy = 0
        self.system_cycles = 0


class Renderer:
    __slots__ = ("hwnd", "hdc", "hrc", "program", "vao", "vbo", "texture", "texture_uniform")

    def __init__(self):
        self.hwnd = None
        self.hdc = None
        self.hrc = None
        self.program = ctypes.c_uint(0)
        self.vao = ctypes.c_uint(0)
        self.vbo = ctypes.c_uint(0)
        self.texture = ctypes.c_uint(0)
        self.texture_uniform = -1


def u8(value):
    return value & 0xFF


def u16(value):
    return value & 0xFFFF


def mirror_nametable(cart, addr):
    addr = (addr - 0x2000) & 0x0FFF
    if cart.mirror == MIRROR_HORIZONTAL:
        return (addr & 0x3FF) if addr < 0x800 else (0x400 + (addr & 0x3FF))
    if cart.mirror == MIRROR_VERTICAL:
        return addr & 0x7FF
    if cart.mirror == MIRROR_SINGLE_LO:
        return addr & 0x3FF
    if cart.mirror == MIRROR_SINGLE_HI:
        return 0x400 + (addr & 0x3FF)
    return addr & 0x7FF


def cartridge_prg_addr(cart, addr):
    if cart.mapper == MAPPER_GXROM:
        bank_count = cart.prg_size // 0x8000
        bank = (cart.prg_bank_select % bank_count) if bank_count else 0
        return bank * 0x8000 + (addr - 0x8000)
    mapped = addr - 0x8000
    if cart.prg_banks == 1:
        mapped &= 0x3FFF
    return mapped


def cartridge_chr_addr(cart, addr):
    if cart.mapper == MAPPER_GXROM:
        bank_count = cart.chr_size // 0x2000
        bank = (cart.chr_bank_select % bank_count) if bank_count else 0
        return bank * 0x2000 + addr
    return addr


def cartridge_load(cart, filename):
    with open(filename, "rb") as fp:
        data = fp.read()
    if len(data) < 16 or data[:4] != b"NES\x1A":
        raise RuntimeError("Invalid iNES file")

    prg_count = data[4]
    chr_count = data[5]
    flags6 = data[6]
    flags7 = data[7]

    cart.mapper = (flags7 & 0xF0) | (flags6 >> 4)
    if cart.mapper not in (MAPPER_NROM, MAPPER_GXROM):
        raise RuntimeError(f"Only Mapper 0 and 66 supported (got {cart.mapper})")

    if flags6 & 0x08:
        cart.mirror = MIRROR_FOUR_SCREEN
    elif flags6 & 0x01:
        cart.mirror = MIRROR_VERTICAL
    else:
        cart.mirror = MIRROR_HORIZONTAL

    offset = 16 + (512 if (flags6 & 0x04) else 0)
    cart.prg_banks = prg_count
    cart.prg_size = prg_count * 16384
    cart.prg_rom = data[offset:offset + cart.prg_size]
    if len(cart.prg_rom) != cart.prg_size:
        raise RuntimeError("Failed to read PRG ROM")
    offset += cart.prg_size

    cart.chr_banks = chr_count
    if chr_count:
        cart.chr_size = chr_count * 8192
        cart.chr_rom = data[offset:offset + cart.chr_size]
        if len(cart.chr_rom) != cart.chr_size:
            raise RuntimeError("Failed to read CHR ROM")
        cart.has_chr_ram = False
    else:
        cart.chr_size = 0x2000
        cart.chr_rom = cart.chr_ram
        cart.has_chr_ram = True

    print(
        f"ROM: PRG={cart.prg_size // 1024}KB CHR={cart.chr_size // 1024}KB "
        f"Mapper={cart.mapper} Mirror={cart.mirror}"
    )


def cartridge_cpu_read(cart, addr):
    if addr >= 0x8000:
        return cart.prg_rom[cartridge_prg_addr(cart, addr)]
    return 0


def cartridge_cpu_write(cart, addr, value):
    if cart.mapper == MAPPER_GXROM and addr >= 0x8000:
        latch = value & cartridge_cpu_read(cart, addr)
        cart.chr_bank_select = latch & 0x03
        cart.prg_bank_select = (latch >> 4) & 0x03


def cartridge_ppu_read(cart, addr):
    if addr >= 0x2000:
        return 0
    if cart.has_chr_ram:
        return cart.chr_ram[cartridge_chr_addr(cart, addr)]
    return cart.chr_rom[cartridge_chr_addr(cart, addr)]


def cartridge_ppu_write(cart, addr, value):
    if addr < 0x2000 and cart.has_chr_ram:
        cart.chr_ram[cartridge_chr_addr(cart, addr)] = value


def ppu_read(ppu, cart, addr):
    addr &= 0x3FFF
    if addr < 0x2000:
        return cartridge_ppu_read(cart, addr)
    if addr < 0x3F00:
        return ppu.vram[mirror_nametable(cart, addr)]
    palette_addr = addr & 0x1F
    if palette_addr >= 16 and (palette_addr & 3) == 0:
        palette_addr -= 16
    return ppu.palette[palette_addr]


def ppu_write(ppu, cart, addr, value):
    addr &= 0x3FFF
    if addr < 0x2000:
        cartridge_ppu_write(cart, addr, value)
        return
    if addr < 0x3F00:
        ppu.vram[mirror_nametable(cart, addr)] = value
        return
    palette_addr = addr & 0x1F
    if palette_addr >= 16 and (palette_addr & 3) == 0:
        palette_addr -= 16
    ppu.palette[palette_addr] = value


def ppu_reg_read(ppu, cart, reg):
    reg &= 7
    if reg == 2:
        result = (ppu.status & 0xE0) | (ppu.data_buf & 0x1F)
        ppu.status &= ~PPUSTAT_VBLANK
        ppu.nmi_occurred = 0
        ppu.w = 0
        return result
    if reg == 4:
        return ppu.oam[ppu.oam_addr]
    if reg == 7:
        result = ppu.data_buf
        ppu.data_buf = ppu_read(ppu, cart, ppu.v)
        if (ppu.v & 0x3FFF) >= 0x3F00:
            result = ppu.data_buf
            ppu.data_buf = ppu_read(ppu, cart, ppu.v - 0x1000)
        ppu.v = u16(ppu.v + (32 if (ppu.ctrl & PPUCTRL_VRAM_INC) else 1))
        return result
    return 0


def ppu_reg_write(ppu, cart, reg, value):
    reg &= 7
    if reg == 0:
        ppu.ctrl = value
        ppu.nmi_output = 1 if (value & PPUCTRL_NMI_ENABLE) else 0
        ppu.t = (ppu.t & 0xF3FF) | ((value & 0x03) << 10)
    elif reg == 1:
        ppu.mask = value
    elif reg == 3:
        ppu.oam_addr = value
    elif reg == 4:
        ppu.oam[ppu.oam_addr] = value
        ppu.oam_addr = u8(ppu.oam_addr + 1)
    elif reg == 5:
        if ppu.w == 0:
            ppu.t = (ppu.t & 0xFFE0) | (value >> 3)
            ppu.fine_x = value & 0x07
            ppu.w = 1
        else:
            ppu.t = (ppu.t & 0x8C1F) | ((value & 0x07) << 12) | ((value >> 3) << 5)
            ppu.w = 0
    elif reg == 6:
        if ppu.w == 0:
            ppu.t = (ppu.t & 0x00FF) | ((value & 0x3F) << 8)
            ppu.w = 1
        else:
            ppu.t = (ppu.t & 0xFF00) | value
            ppu.v = ppu.t
            ppu.w = 0
    elif reg == 7:
        ppu_write(ppu, cart, ppu.v, value)
        ppu.v = u16(ppu.v + (32 if (ppu.ctrl & PPUCTRL_VRAM_INC) else 1))


def rendering_enabled(ppu):
    return (ppu.mask & (PPUMASK_BG_ENABLE | PPUMASK_SPR_ENABLE)) != 0


def increment_x(ppu):
    if (ppu.v & 0x001F) == 31:
        ppu.v &= ~0x001F
        ppu.v ^= 0x0400
    else:
        ppu.v = u16(ppu.v + 1)


def increment_y(ppu):
    if (ppu.v & 0x7000) != 0x7000:
        ppu.v = u16(ppu.v + 0x1000)
        return
    ppu.v &= ~0x7000
    coarse_y = (ppu.v & 0x03E0) >> 5
    if coarse_y == 29:
        coarse_y = 0
        ppu.v ^= 0x0800
    elif coarse_y == 31:
        coarse_y = 0
    else:
        coarse_y += 1
    ppu.v = (ppu.v & ~0x03E0) | (coarse_y << 5)


def copy_horizontal(ppu):
    ppu.v = (ppu.v & ~0x041F) | (ppu.t & 0x041F)


def copy_vertical(ppu):
    ppu.v = (ppu.v & ~0x7BE0) | (ppu.t & 0x7BE0)


def render_bg_scanline(ppu, cart, bg_px, bg_pal):
    v = ppu.v
    fine_x = ppu.fine_x
    show_bg = 1 if (ppu.mask & PPUMASK_BG_ENABLE) else 0
    show_left = 1 if (ppu.mask & PPUMASK_BG_LEFT) else 0
    for x in range(256):
        pixel = 0
        palette = 0
        if show_bg and (x >= 8 or show_left):
            nt = 0x2000 | (v & 0x0FFF)
            tile = ppu_read(ppu, cart, nt)
            at = 0x23C0 | (v & 0x0C00) | ((v >> 4) & 0x38) | ((v >> 2) & 0x07)
            attr = ppu_read(ppu, cart, at)
            palette = (attr >> (((v >> 4) & 4) | (v & 2))) & 3
            pattern_base = 0x1000 if (ppu.ctrl & PPUCTRL_BG_ADDR) else 0
            pattern_addr = pattern_base + tile * 16 + ((v >> 12) & 7)
            lo = ppu_read(ppu, cart, pattern_addr)
            hi = ppu_read(ppu, cart, pattern_addr + 8)
            bit = 7 - fine_x
            pixel = ((lo >> bit) & 1) | (((hi >> bit) & 1) << 1)
        bg_px[x] = pixel
        bg_pal[x] = palette
        if fine_x == 7:
            fine_x = 0
            increment_x(ppu)
            v = ppu.v
        else:
            fine_x += 1


def render_sprites(ppu, cart, scanline, bg_px, bg_pal, framebuffer, line_offset):
    show_spr = 1 if (ppu.mask & PPUMASK_SPR_ENABLE) else 0
    show_left = 1 if (ppu.mask & PPUMASK_SPR_LEFT) else 0
    spr_h = 16 if (ppu.ctrl & PPUCTRL_SPR_SIZE) else 8
    count = 0
    sp_px = bytearray(256)
    sp_pal = bytearray(256)
    sp_pri = bytearray(256)
    sp_z = bytearray(256)

    if show_spr:
        for i in range(63, -1, -1):
            y = ppu.oam[i * 4 + 0] + 1
            tile = ppu.oam[i * 4 + 1]
            attr = ppu.oam[i * 4 + 2]
            sx = ppu.oam[i * 4 + 3]
            row = scanline - y
            if row < 0 or row >= spr_h:
                continue
            count += 1

            flip_v = 1 if (attr & 0x80) else 0
            flip_h = 1 if (attr & 0x40) else 0
            pal = (attr & 0x03) + 4
            pri = 1 if (attr & 0x20) else 0

            if spr_h == 8:
                sprite_row = 7 - row if flip_v else row
                pattern_addr = (0x1000 if (ppu.ctrl & PPUCTRL_SPR_ADDR) else 0) + tile * 16 + sprite_row
            else:
                base = 0x1000 if (tile & 1) else 0
                tile_index = tile & 0xFE
                sprite_row = 15 - row if flip_v else row
                if sprite_row >= 8:
                    tile_index += 1
                    sprite_row -= 8
                pattern_addr = base + tile_index * 16 + sprite_row

            lo = ppu_read(ppu, cart, pattern_addr)
            hi = ppu_read(ppu, cart, pattern_addr + 8)
            for px in range(8):
                dx = sx + px
                if dx >= 256 or (dx < 8 and not show_left):
                    continue
                bit = px if flip_h else (7 - px)
                pixel = ((lo >> bit) & 1) | (((hi >> bit) & 1) << 1)
                if pixel == 0:
                    continue
                sp_px[dx] = pixel
                sp_pal[dx] = pal
                sp_pri[dx] = pri
                if i == 0:
                    sp_z[dx] = 1

    if count > 8:
        ppu.status |= PPUSTAT_OVERFLOW

    show_bg = 1 if (ppu.mask & PPUMASK_BG_ENABLE) else 0
    for x in range(256):
        bp = bg_px[x]
        sp = sp_px[x]
        if sp_z[x] and bp and sp and show_spr and show_bg:
            if x >= 8 or ((ppu.mask & PPUMASK_BG_LEFT) and (ppu.mask & PPUMASK_SPR_LEFT)):
                ppu.status |= PPUSTAT_SPR0_HIT
        if not bp and not sp:
            color_index = ppu_read(ppu, cart, 0x3F00)
        elif not bp and sp:
            color_index = ppu_read(ppu, cart, 0x3F00 + sp_pal[x] * 4 + sp)
        elif bp and not sp:
            color_index = ppu_read(ppu, cart, 0x3F00 + bg_pal[x] * 4 + bp)
        elif sp_pri[x] == 0:
            color_index = ppu_read(ppu, cart, 0x3F00 + sp_pal[x] * 4 + sp)
        else:
            color_index = ppu_read(ppu, cart, 0x3F00 + bg_pal[x] * 4 + bp)
        framebuffer[line_offset + x] = NES_PALETTE[color_index & 0x3F]


def ppu_step(ppu, bus):
    cart = bus.cart
    is_pre = ppu.scanline == -1
    is_visible = 0 <= ppu.scanline < 240
    ren = rendering_enabled(ppu)

    if is_visible and ppu.cycle == 256:
        line_offset = ppu.scanline * 256
        if ren:
            bg_px = bytearray(256)
            bg_pal = bytearray(256)
            copy_horizontal(ppu)
            render_bg_scanline(ppu, cart, bg_px, bg_pal)
            render_sprites(ppu, cart, ppu.scanline, bg_px, bg_pal, ppu.framebuffer, line_offset)
            increment_y(ppu)
        else:
            bg = ppu.palette[0] & 0x3F
            color = NES_PALETTE[bg]
            for x in range(256):
                ppu.framebuffer[line_offset + x] = color

    if is_pre:
        if ppu.cycle == 1:
            ppu.status &= ~(PPUSTAT_VBLANK | PPUSTAT_SPR0_HIT | PPUSTAT_OVERFLOW)
            ppu.nmi_occurred = 0
        if ren and 280 <= ppu.cycle <= 304:
            copy_vertical(ppu)

    if ppu.scanline == 241 and ppu.cycle == 1:
        ppu.status |= PPUSTAT_VBLANK
        ppu.nmi_occurred = 1
        if ppu.nmi_output:
            bus.cpu.nmi_pending = 1
        ppu.frame_ready = 1

    ppu.cycle += 1
    if ppu.cycle > 340:
        ppu.cycle = 0
        ppu.scanline += 1
        if ppu.scanline > 260:
            ppu.scanline = -1
            ppu.frame_count += 1


def set_flag(cpu, flag, value):
    if value:
        cpu.p |= flag
    else:
        cpu.p &= ~flag


def update_nz(cpu, value):
    set_flag(cpu, FLAG_Z, (value & 0xFF) == 0)
    set_flag(cpu, FLAG_N, value & 0x80)


def bus_cpu_read(bus, addr):
    addr &= 0xFFFF
    if addr < 0x2000:
        return bus.ram[addr & 0x07FF]
    if addr < 0x4000:
        return ppu_reg_read(bus.ppu, bus.cart, addr)
    if addr == 0x4016:
        data = 1 if (bus.controller_latch[0] & 0x80) else 0
        bus.controller_latch[0] = u8(bus.controller_latch[0] << 1)
        return data | 0x40
    if addr == 0x4017:
        data = 1 if (bus.controller_latch[1] & 0x80) else 0
        bus.controller_latch[1] = u8(bus.controller_latch[1] << 1)
        return data | 0x40
    if addr < 0x4020:
        return 0
    return cartridge_cpu_read(bus.cart, addr)


def bus_cpu_write(bus, addr, value):
    addr &= 0xFFFF
    value &= 0xFF
    if addr < 0x2000:
        bus.ram[addr & 0x07FF] = value
        return
    if addr < 0x4000:
        ppu_reg_write(bus.ppu, bus.cart, addr, value)
        return
    if addr == 0x4014:
        bus.dma_page = value
        bus.dma_addr = 0
        bus.dma_transfer = 1
        bus.dma_dummy = 1
        return
    if addr == 0x4016:
        bus.controller_strobe = value & 1
        if bus.controller_strobe:
            bus.controller_latch[0] = bus.controller[0]
            bus.controller_latch[1] = bus.controller[1]
        return
    if addr < 0x4020:
        return
    cartridge_cpu_write(bus.cart, addr, value)


def push8(cpu, bus, value):
    bus_cpu_write(bus, 0x0100 + cpu.sp, value)
    cpu.sp = u8(cpu.sp - 1)


def push16(cpu, bus, value):
    push8(cpu, bus, value >> 8)
    push8(cpu, bus, value & 0xFF)


def pull8(cpu, bus):
    cpu.sp = u8(cpu.sp + 1)
    return bus_cpu_read(bus, 0x0100 + cpu.sp)


def pull16(cpu, bus):
    lo = pull8(cpu, bus)
    hi = pull8(cpu, bus)
    return (hi << 8) | lo


def pages_differ(a, b):
    return (a & 0xFF00) != (b & 0xFF00)


def resolve_addr(cpu, bus, mode):
    page_cross = 0
    addr = 0
    if mode in (AM_IMP, AM_ACC):
        return addr, page_cross
    if mode == AM_IMM:
        addr = cpu.pc
        cpu.pc = u16(cpu.pc + 1)
    elif mode == AM_ZPG:
        addr = bus_cpu_read(bus, cpu.pc)
        cpu.pc = u16(cpu.pc + 1)
    elif mode == AM_ZPX:
        addr = u8(bus_cpu_read(bus, cpu.pc) + cpu.x)
        cpu.pc = u16(cpu.pc + 1)
    elif mode == AM_ZPY:
        addr = u8(bus_cpu_read(bus, cpu.pc) + cpu.y)
        cpu.pc = u16(cpu.pc + 1)
    elif mode == AM_REL:
        addr = cpu.pc
        cpu.pc = u16(cpu.pc + 1)
    elif mode == AM_ABS:
        lo = bus_cpu_read(bus, cpu.pc)
        hi = bus_cpu_read(bus, cpu.pc + 1)
        cpu.pc = u16(cpu.pc + 2)
        addr = (hi << 8) | lo
    elif mode == AM_ABX:
        lo = bus_cpu_read(bus, cpu.pc)
        hi = bus_cpu_read(bus, cpu.pc + 1)
        base = (hi << 8) | lo
        cpu.pc = u16(cpu.pc + 2)
        addr = u16(base + cpu.x)
        page_cross = 1 if pages_differ(addr, base) else 0
    elif mode == AM_ABY:
        lo = bus_cpu_read(bus, cpu.pc)
        hi = bus_cpu_read(bus, cpu.pc + 1)
        base = (hi << 8) | lo
        cpu.pc = u16(cpu.pc + 2)
        addr = u16(base + cpu.y)
        page_cross = 1 if pages_differ(addr, base) else 0
    elif mode == AM_IND:
        lo = bus_cpu_read(bus, cpu.pc)
        hi = bus_cpu_read(bus, cpu.pc + 1)
        cpu.pc = u16(cpu.pc + 2)
        pointer = (hi << 8) | lo
        pointer_hi = (pointer & 0xFF00) if lo == 0xFF else (pointer + 1)
        addr = bus_cpu_read(bus, pointer) | (bus_cpu_read(bus, pointer_hi) << 8)
    elif mode == AM_IZX:
        base = bus_cpu_read(bus, cpu.pc)
        cpu.pc = u16(cpu.pc + 1)
        z = u8(base + cpu.x)
        lo = bus_cpu_read(bus, z)
        hi = bus_cpu_read(bus, u8(z + 1))
        addr = (hi << 8) | lo
    elif mode == AM_IZY:
        z = bus_cpu_read(bus, cpu.pc)
        cpu.pc = u16(cpu.pc + 1)
        lo = bus_cpu_read(bus, z)
        hi = bus_cpu_read(bus, u8(z + 1))
        base = (hi << 8) | lo
        addr = u16(base + cpu.y)
        page_cross = 1 if pages_differ(addr, base) else 0
    return addr, page_cross


def do_branch(cpu, bus, addr, cond):
    if not cond:
        return 0
    offset = bus_cpu_read(bus, addr)
    if offset & 0x80:
        offset -= 0x100
    new_pc = u16(cpu.pc + offset)
    extra = 1 + (1 if pages_differ(cpu.pc, new_pc) else 0)
    cpu.pc = new_pc
    return extra


def cpu_nmi(cpu, bus):
    push16(cpu, bus, cpu.pc)
    push8(cpu, bus, (cpu.p | FLAG_U) & ~FLAG_B)
    cpu.p |= FLAG_I
    cpu.pc = bus_cpu_read(bus, 0xFFFA) | (bus_cpu_read(bus, 0xFFFB) << 8)
    cpu.cycles += 7


def cpu_irq(cpu, bus):
    if cpu.p & FLAG_I:
        return
    push16(cpu, bus, cpu.pc)
    push8(cpu, bus, (cpu.p | FLAG_U) & ~FLAG_B)
    cpu.p |= FLAG_I
    cpu.pc = bus_cpu_read(bus, 0xFFFE) | (bus_cpu_read(bus, 0xFFFF) << 8)
    cpu.cycles += 7


def cpu_reset(cpu, bus):
    cpu.pc = bus_cpu_read(bus, 0xFFFC) | (bus_cpu_read(bus, 0xFFFD) << 8)
    cpu.sp = 0xFD
    cpu.p = FLAG_U | FLAG_I
    cpu.a = 0
    cpu.x = 0
    cpu.y = 0
    cpu.cycles = 0
    cpu.stall = 0
    cpu.nmi_pending = 0
    cpu.irq_pending = 0


def cpu_step(cpu, bus):
    if cpu.stall > 0:
        cpu.stall -= 1
        return 1
    if cpu.nmi_pending:
        cpu_nmi(cpu, bus)
        cpu.nmi_pending = 0
        return 7
    if cpu.irq_pending and not (cpu.p & FLAG_I):
        cpu_irq(cpu, bus)
        cpu.irq_pending = 0
        return 7

    opcode = bus_cpu_read(bus, cpu.pc)
    cpu.pc = u16(cpu.pc + 1)
    ins, mode, base_cycles, page_penalty = OPCODE_TABLE[opcode]
    addr, page_cross = resolve_addr(cpu, bus, mode)
    cycles = base_cycles + (1 if page_cross and page_penalty else 0)
    extra = 0

    if ins == INS_ADC:
        value = bus_cpu_read(bus, addr)
        total = cpu.a + value + (1 if (cpu.p & FLAG_C) else 0)
        set_flag(cpu, FLAG_C, total > 0xFF)
        set_flag(cpu, FLAG_V, (~(cpu.a ^ value) & (cpu.a ^ total) & 0x80) != 0)
        cpu.a = u8(total)
        update_nz(cpu, cpu.a)
    elif ins == INS_SBC:
        value = bus_cpu_read(bus, addr)
        total = cpu.a - value - (0 if (cpu.p & FLAG_C) else 1)
        set_flag(cpu, FLAG_C, total >= 0)
        set_flag(cpu, FLAG_V, ((cpu.a ^ value) & (cpu.a ^ total) & 0x80) != 0)
        cpu.a = u8(total)
        update_nz(cpu, cpu.a)
    elif ins == INS_AND:
        cpu.a = u8(cpu.a & bus_cpu_read(bus, addr))
        update_nz(cpu, cpu.a)
    elif ins == INS_ORA:
        cpu.a = u8(cpu.a | bus_cpu_read(bus, addr))
        update_nz(cpu, cpu.a)
    elif ins == INS_EOR:
        cpu.a = u8(cpu.a ^ bus_cpu_read(bus, addr))
        update_nz(cpu, cpu.a)
    elif ins == INS_ASL:
        if mode == AM_ACC:
            set_flag(cpu, FLAG_C, cpu.a & 0x80)
            cpu.a = u8(cpu.a << 1)
            update_nz(cpu, cpu.a)
        else:
            value = bus_cpu_read(bus, addr)
            set_flag(cpu, FLAG_C, value & 0x80)
            value = u8(value << 1)
            bus_cpu_write(bus, addr, value)
            update_nz(cpu, value)
    elif ins == INS_LSR:
        if mode == AM_ACC:
            set_flag(cpu, FLAG_C, cpu.a & 1)
            cpu.a = u8(cpu.a >> 1)
            update_nz(cpu, cpu.a)
        else:
            value = bus_cpu_read(bus, addr)
            set_flag(cpu, FLAG_C, value & 1)
            value = u8(value >> 1)
            bus_cpu_write(bus, addr, value)
            update_nz(cpu, value)
    elif ins == INS_ROL:
        carry = 1 if (cpu.p & FLAG_C) else 0
        if mode == AM_ACC:
            set_flag(cpu, FLAG_C, cpu.a & 0x80)
            cpu.a = u8((cpu.a << 1) | carry)
            update_nz(cpu, cpu.a)
        else:
            value = bus_cpu_read(bus, addr)
            set_flag(cpu, FLAG_C, value & 0x80)
            value = u8((value << 1) | carry)
            bus_cpu_write(bus, addr, value)
            update_nz(cpu, value)
    elif ins == INS_ROR:
        carry = 0x80 if (cpu.p & FLAG_C) else 0
        if mode == AM_ACC:
            set_flag(cpu, FLAG_C, cpu.a & 1)
            cpu.a = u8((cpu.a >> 1) | carry)
            update_nz(cpu, cpu.a)
        else:
            value = bus_cpu_read(bus, addr)
            set_flag(cpu, FLAG_C, value & 1)
            value = u8((value >> 1) | carry)
            bus_cpu_write(bus, addr, value)
            update_nz(cpu, value)
    elif ins == INS_CMP:
        value = bus_cpu_read(bus, addr)
        set_flag(cpu, FLAG_C, cpu.a >= value)
        update_nz(cpu, u8(cpu.a - value))
    elif ins == INS_CPX:
        value = bus_cpu_read(bus, addr)
        set_flag(cpu, FLAG_C, cpu.x >= value)
        update_nz(cpu, u8(cpu.x - value))
    elif ins == INS_CPY:
        value = bus_cpu_read(bus, addr)
        set_flag(cpu, FLAG_C, cpu.y >= value)
        update_nz(cpu, u8(cpu.y - value))
    elif ins == INS_INC:
        value = u8(bus_cpu_read(bus, addr) + 1)
        bus_cpu_write(bus, addr, value)
        update_nz(cpu, value)
    elif ins == INS_DEC:
        value = u8(bus_cpu_read(bus, addr) - 1)
        bus_cpu_write(bus, addr, value)
        update_nz(cpu, value)
    elif ins == INS_INX:
        cpu.x = u8(cpu.x + 1)
        update_nz(cpu, cpu.x)
    elif ins == INS_INY:
        cpu.y = u8(cpu.y + 1)
        update_nz(cpu, cpu.y)
    elif ins == INS_DEX:
        cpu.x = u8(cpu.x - 1)
        update_nz(cpu, cpu.x)
    elif ins == INS_DEY:
        cpu.y = u8(cpu.y - 1)
        update_nz(cpu, cpu.y)
    elif ins == INS_LDA:
        cpu.a = bus_cpu_read(bus, addr)
        update_nz(cpu, cpu.a)
    elif ins == INS_LDX:
        cpu.x = bus_cpu_read(bus, addr)
        update_nz(cpu, cpu.x)
    elif ins == INS_LDY:
        cpu.y = bus_cpu_read(bus, addr)
        update_nz(cpu, cpu.y)
    elif ins == INS_STA:
        bus_cpu_write(bus, addr, cpu.a)
    elif ins == INS_STX:
        bus_cpu_write(bus, addr, cpu.x)
    elif ins == INS_STY:
        bus_cpu_write(bus, addr, cpu.y)
    elif ins == INS_TAX:
        cpu.x = cpu.a
        update_nz(cpu, cpu.x)
    elif ins == INS_TAY:
        cpu.y = cpu.a
        update_nz(cpu, cpu.y)
    elif ins == INS_TXA:
        cpu.a = cpu.x
        update_nz(cpu, cpu.a)
    elif ins == INS_TYA:
        cpu.a = cpu.y
        update_nz(cpu, cpu.a)
    elif ins == INS_TSX:
        cpu.x = cpu.sp
        update_nz(cpu, cpu.x)
    elif ins == INS_TXS:
        cpu.sp = cpu.x
    elif ins == INS_PHA:
        push8(cpu, bus, cpu.a)
    elif ins == INS_PHP:
        push8(cpu, bus, cpu.p | FLAG_B | FLAG_U)
    elif ins == INS_PLA:
        cpu.a = pull8(cpu, bus)
        update_nz(cpu, cpu.a)
    elif ins == INS_PLP:
        cpu.p = (pull8(cpu, bus) & ~FLAG_B) | FLAG_U
    elif ins == INS_BCC:
        extra = do_branch(cpu, bus, addr, not (cpu.p & FLAG_C))
    elif ins == INS_BCS:
        extra = do_branch(cpu, bus, addr, cpu.p & FLAG_C)
    elif ins == INS_BEQ:
        extra = do_branch(cpu, bus, addr, cpu.p & FLAG_Z)
    elif ins == INS_BNE:
        extra = do_branch(cpu, bus, addr, not (cpu.p & FLAG_Z))
    elif ins == INS_BMI:
        extra = do_branch(cpu, bus, addr, cpu.p & FLAG_N)
    elif ins == INS_BPL:
        extra = do_branch(cpu, bus, addr, not (cpu.p & FLAG_N))
    elif ins == INS_BVS:
        extra = do_branch(cpu, bus, addr, cpu.p & FLAG_V)
    elif ins == INS_BVC:
        extra = do_branch(cpu, bus, addr, not (cpu.p & FLAG_V))
    elif ins == INS_JMP:
        cpu.pc = addr
    elif ins == INS_JSR:
        push16(cpu, bus, u16(cpu.pc - 1))
        cpu.pc = addr
    elif ins == INS_RTS:
        cpu.pc = u16(pull16(cpu, bus) + 1)
    elif ins == INS_RTI:
        cpu.p = (pull8(cpu, bus) & ~FLAG_B) | FLAG_U
        cpu.pc = pull16(cpu, bus)
    elif ins == INS_CLC:
        cpu.p &= ~FLAG_C
    elif ins == INS_SEC:
        cpu.p |= FLAG_C
    elif ins == INS_CLD:
        cpu.p &= ~FLAG_D
    elif ins == INS_SED:
        cpu.p |= FLAG_D
    elif ins == INS_CLI:
        cpu.p &= ~FLAG_I
    elif ins == INS_SEI:
        cpu.p |= FLAG_I
    elif ins == INS_CLV:
        cpu.p &= ~FLAG_V
    elif ins == INS_BIT:
        value = bus_cpu_read(bus, addr)
        set_flag(cpu, FLAG_Z, (cpu.a & value) == 0)
        set_flag(cpu, FLAG_V, value & 0x40)
        set_flag(cpu, FLAG_N, value & 0x80)
    elif ins == INS_BRK:
        cpu.pc = u16(cpu.pc + 1)
        push16(cpu, bus, cpu.pc)
        push8(cpu, bus, cpu.p | FLAG_B | FLAG_U)
        cpu.p |= FLAG_I
        cpu.pc = bus_cpu_read(bus, 0xFFFE) | (bus_cpu_read(bus, 0xFFFF) << 8)

    cycles += extra
    cpu.cycles += cycles
    return cycles


def bus_run_frame(bus):
    bus.ppu.frame_ready = 0
    while not bus.ppu.frame_ready:
        if bus.dma_transfer:
            if bus.dma_dummy:
                if bus.system_cycles & 1:
                    bus.dma_dummy = 0
            else:
                if (bus.system_cycles & 1) == 0:
                    bus.dma_data = bus_cpu_read(bus, (bus.dma_page << 8) | bus.dma_addr)
                else:
                    bus.ppu.oam[bus.ppu.oam_addr] = bus.dma_data
                    bus.ppu.oam_addr = u8(bus.ppu.oam_addr + 1)
                    bus.dma_addr = u8(bus.dma_addr + 1)
                    if bus.dma_addr == 0:
                        bus.dma_transfer = 0
            ppu_step(bus.ppu, bus)
            ppu_step(bus.ppu, bus)
            ppu_step(bus.ppu, bus)
            bus.system_cycles += 1
            continue

        cycles = cpu_step(bus.cpu, bus)
        for _ in range(cycles):
            ppu_step(bus.ppu, bus)
            ppu_step(bus.ppu, bus)
            ppu_step(bus.ppu, bus)
            bus.system_cycles += 1


def set_pixel_format(hdc):
    pfd = PIXELFORMATDESCRIPTOR()
    ctypes.memset(ctypes.byref(pfd), 0, ctypes.sizeof(pfd))
    pfd.nSize = ctypes.sizeof(PIXELFORMATDESCRIPTOR)
    pfd.nVersion = 1
    pfd.dwFlags = PFD_DRAW_TO_WINDOW | PFD_SUPPORT_OPENGL | PFD_DOUBLEBUFFER
    pfd.iPixelType = PFD_TYPE_RGBA
    pfd.cColorBits = 32
    pfd.cDepthBits = 24
    pfd.iLayerType = PFD_MAIN_PLANE
    fmt = gdi32.ChoosePixelFormat(hdc, ctypes.byref(pfd))
    if fmt == 0:
        raise ctypes.WinError(ctypes.get_last_error())
    if not gdi32.SetPixelFormat(hdc, fmt, ctypes.byref(pfd)):
        raise ctypes.WinError(ctypes.get_last_error())


def create_gl46_context(hdc):
    old_rc = opengl32.wglCreateContext(hdc)
    if not old_rc:
        raise ctypes.WinError(ctypes.get_last_error())
    if not opengl32.wglMakeCurrent(hdc, old_rc):
        raise ctypes.WinError(ctypes.get_last_error())
    init_wgl_and_gl_funcs()
    attribs = (ctypes.c_int * 9)(
        WGL_CONTEXT_MAJOR_VERSION_ARB, 4,
        WGL_CONTEXT_MINOR_VERSION_ARB, 6,
        WGL_CONTEXT_FLAGS_ARB, 0,
        WGL_CONTEXT_PROFILE_MASK_ARB, WGL_CONTEXT_CORE_PROFILE_BIT_ARB,
        0,
    )
    hrc = wglCreateContextAttribsARB(hdc, None, attribs)
    if not hrc:
        hrc = opengl32.wglCreateContext(hdc)
    if not hrc:
        raise ctypes.WinError(ctypes.get_last_error())
    if not opengl32.wglMakeCurrent(hdc, hrc):
        raise ctypes.WinError(ctypes.get_last_error())
    opengl32.wglDeleteContext(old_rc)
    return hrc


def get_client_size(hwnd):
    rect = RECT()
    user32.GetClientRect(hwnd, ctypes.byref(rect))
    return rect.right - rect.left, rect.bottom - rect.top


def render_init(renderer, hwnd):
    vertices = (ctypes.c_float * 20)(
        -1.0, 1.0, 0.0, 0.0, 0.0,
         1.0, 1.0, 0.0, 1.0, 0.0,
        -1.0, -1.0, 0.0, 0.0, 1.0,
         1.0, -1.0, 0.0, 1.0, 1.0,
    )

    renderer.hwnd = hwnd
    renderer.hdc = user32.GetDC(hwnd)
    if not renderer.hdc:
        raise ctypes.WinError(ctypes.get_last_error())
    set_pixel_format(renderer.hdc)
    renderer.hrc = create_gl46_context(renderer.hdc)

    vs = compile_shader(GL_VERTEX_SHADER, VERT_SRC)
    fs = compile_shader(GL_FRAGMENT_SHADER, FRAG_SRC)
    renderer.program = ctypes.c_uint(link_program(vs, fs))
    glDeleteShader(vs)
    glDeleteShader(fs)

    glGenVertexArrays(1, ctypes.byref(renderer.vao))
    glBindVertexArray(renderer.vao.value)
    glGenBuffers(1, ctypes.byref(renderer.vbo))
    glBindBuffer(GL_ARRAY_BUFFER, renderer.vbo.value)
    glBufferData(GL_ARRAY_BUFFER, ctypes.sizeof(vertices), ctypes.cast(vertices, ctypes.c_void_p), GL_STATIC_DRAW)
    glEnableVertexAttribArray(0)
    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 5 * ctypes.sizeof(ctypes.c_float), ctypes.c_void_p(0))
    glEnableVertexAttribArray(1)
    glVertexAttribPointer(
        1, 2, GL_FLOAT, GL_FALSE, 5 * ctypes.sizeof(ctypes.c_float), ctypes.c_void_p(3 * ctypes.sizeof(ctypes.c_float))
    )

    opengl32.glGenTextures(1, ctypes.byref(renderer.texture))
    opengl32.glBindTexture(GL_TEXTURE_2D, renderer.texture.value)
    opengl32.glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST)
    opengl32.glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST)
    opengl32.glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE)
    opengl32.glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE)
    opengl32.glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_BASE_LEVEL, 0)
    opengl32.glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAX_LEVEL, 0)
    opengl32.glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, NES_WIDTH, NES_HEIGHT, 0, GL_BGRA, GL_UNSIGNED_BYTE, None)

    glUseProgram(renderer.program.value)
    renderer.texture_uniform = glGetUniformLocation(renderer.program.value, b"u_texture")
    glUniform1i(renderer.texture_uniform, 0)

    width, height = get_client_size(hwnd)
    opengl32.glViewport(0, 0, width, height)


def render_resize(hwnd):
    width, height = get_client_size(hwnd)
    opengl32.glViewport(0, 0, width, height)


def render_frame(renderer, framebuffer):
    opengl32.glClearColor(0.0, 0.0, 0.0, 1.0)
    opengl32.glClear(GL_COLOR_BUFFER_BIT)
    glUseProgram(renderer.program.value)
    glActiveTexture(GL_TEXTURE0)
    opengl32.glBindTexture(GL_TEXTURE_2D, renderer.texture.value)
    opengl32.glTexSubImage2D(
        GL_TEXTURE_2D, 0, 0, 0, NES_WIDTH, NES_HEIGHT, GL_BGRA, GL_UNSIGNED_BYTE, ctypes.cast(framebuffer, ctypes.c_void_p)
    )
    glBindVertexArray(renderer.vao.value)
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4)
    gdi32.SwapBuffers(renderer.hdc)


def render_destroy(renderer):
    if renderer.texture.value:
        opengl32.glDeleteTextures(1, ctypes.byref(renderer.texture))
        renderer.texture = ctypes.c_uint(0)
    if renderer.vbo.value and glDeleteBuffers:
        glDeleteBuffers(1, ctypes.byref(renderer.vbo))
        renderer.vbo = ctypes.c_uint(0)
    if renderer.vao.value and glDeleteVertexArrays:
        glDeleteVertexArrays(1, ctypes.byref(renderer.vao))
        renderer.vao = ctypes.c_uint(0)
    if renderer.program.value and glDeleteProgram:
        glDeleteProgram(renderer.program.value)
        renderer.program = ctypes.c_uint(0)
    if renderer.hrc:
        opengl32.wglMakeCurrent(None, None)
        opengl32.wglDeleteContext(renderer.hrc)
        renderer.hrc = None
    if renderer.hwnd and renderer.hdc:
        user32.ReleaseDC(renderer.hwnd, renderer.hdc)
        renderer.hdc = None


g_running = True
g_renderer = Renderer()


def update_input(bus):
    state = 0
    if user32.GetAsyncKeyState(ord("Z")) & 0x8000:
        state |= BTN_A
    if user32.GetAsyncKeyState(ord("X")) & 0x8000:
        state |= BTN_B
    if user32.GetAsyncKeyState(VK_RSHIFT) & 0x8000:
        state |= BTN_SELECT
    if user32.GetAsyncKeyState(VK_RETURN) & 0x8000:
        state |= BTN_START
    if user32.GetAsyncKeyState(VK_UP) & 0x8000:
        state |= BTN_UP
    if user32.GetAsyncKeyState(VK_DOWN) & 0x8000:
        state |= BTN_DOWN
    if user32.GetAsyncKeyState(VK_LEFT) & 0x8000:
        state |= BTN_LEFT
    if user32.GetAsyncKeyState(VK_RIGHT) & 0x8000:
        state |= BTN_RIGHT
    bus.controller[0] = state


@WNDPROC
def wndproc(hwnd, msg, wparam, lparam):
    global g_running
    if msg == WM_CLOSE:
        g_running = False
        user32.PostQuitMessage(0)
        return 0
    if msg == WM_DESTROY:
        g_running = False
        user32.PostQuitMessage(0)
        return 0
    if msg == WM_KEYDOWN and wparam == VK_ESCAPE:
        g_running = False
        user32.PostQuitMessage(0)
        return 0
    if msg == WM_SIZE and g_renderer.hrc and wparam != SIZE_MINIMIZED:
        render_resize(hwnd)
        return 0
    return user32.DefWindowProcW(hwnd, msg, wparam, lparam)


def resolve_rom_path(argv):
    if len(argv) >= 2 and os.path.isfile(argv[1]):
        return os.path.abspath(argv[1])

    here = os.path.dirname(os.path.abspath(__file__))
    local_rom = os.path.join(here, "triangle.nes")
    if os.path.isfile(local_rom):
        return local_rom

    repo_rom = os.path.abspath(
        os.path.join(here, "triangle.nes")
    )
    if os.path.isfile(repo_rom):
        return repo_rom

    raise FileNotFoundError("ROM file not found. Pass a .nes file path as the first argument.")


def create_window():
    hinstance = kernel32.GetModuleHandleW(None)
    class_name = "PyNESOpenGL46"
    wc = WNDCLASSEXW()
    wc.cbSize = ctypes.sizeof(WNDCLASSEXW)
    wc.style = CS_OWNDC
    wc.lpfnWndProc = wndproc
    wc.hInstance = hinstance
    wc.hIcon = user32.LoadIconW(None, wintypes.LPCWSTR(IDI_APPLICATION))
    wc.hCursor = user32.LoadCursorW(None, wintypes.LPCWSTR(IDC_ARROW))
    wc.hbrBackground = 0
    wc.lpszClassName = class_name
    wc.hIconSm = wc.hIcon
    if not user32.RegisterClassExW(ctypes.byref(wc)):
        err = ctypes.get_last_error()
        if err != 1410:
            raise ctypes.WinError(err)

    rect = RECT(0, 0, WINDOW_WIDTH, WINDOW_HEIGHT)
    style = WS_OVERLAPPEDWINDOW & ~(WS_THICKFRAME | WS_MAXIMIZEBOX)
    user32.AdjustWindowRect(ctypes.byref(rect), style, False)
    hwnd = user32.CreateWindowExW(
        0,
        class_name,
        "NES Emulator (Python + OpenGL 4.6)",
        style,
        CW_USEDEFAULT,
        CW_USEDEFAULT,
        rect.right - rect.left,
        rect.bottom - rect.top,
        None,
        None,
        hinstance,
        None,
    )
    if not hwnd:
        raise ctypes.WinError(ctypes.get_last_error())
    return hwnd


def main():
    global g_running
    bus = Bus()
    cart = Cartridge()
    renderer = g_renderer

    rom_path = resolve_rom_path(sys.argv)
    cartridge_load(cart, rom_path)
    bus.cart = cart
    cpu_reset(bus.cpu, bus)

    hwnd = create_window()
    user32.ShowWindow(hwnd, SW_SHOW)
    render_init(renderer, hwnd)

    ver = opengl32.glGetString(GL_VERSION)
    sl = opengl32.glGetString(GL_SHADING_LANGUAGE_VERSION)
    print("[GL] Version:", ver.decode("ascii", "replace") if ver else "(null)")
    print("[GL] GLSL   :", sl.decode("ascii", "replace") if sl else "(null)")
    print("[ROM] Path  :", rom_path)

    msg = MSG()
    last = time.perf_counter()
    accum_us = 0.0

    try:
        while g_running:
            while user32.PeekMessageW(ctypes.byref(msg), None, 0, 0, PM_REMOVE):
                if msg.message == WM_QUIT:
                    g_running = False
                    break
                user32.TranslateMessage(ctypes.byref(msg))
                user32.DispatchMessageW(ctypes.byref(msg))
            if not g_running:
                break

            now = time.perf_counter()
            accum_us += (now - last) * 1_000_000.0
            last = now
            if accum_us >= FRAME_US:
                if accum_us > FRAME_US * 3:
                    accum_us = FRAME_US
                accum_us -= FRAME_US
                update_input(bus)
                bus_run_frame(bus)
                render_frame(renderer, bus.ppu.framebuffer)
            else:
                kernel32.Sleep(1)
    finally:
        render_destroy(renderer)


if __name__ == "__main__":
    main()
