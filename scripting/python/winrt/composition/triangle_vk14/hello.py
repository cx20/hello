# -*- coding: utf-8 -*-
"""Vulkan 1.4 Triangle (Windows, Python, no external Python packages)

- Win32 window via ctypes
- Vulkan via vulkan-1.dll (ctypes)
- Runtime GLSL->SPIR-V via shaderc_shared.dll (ctypes)
- Swapchain + renderpass + graphics pipeline
- Draw triangle via gl_VertexIndex (no vertex buffer)

Fixes:
- Fence byref issue: use 1-element VkFence array when calling vkWaitForFences/vkResetFences
- Black screen: disable culling (VK_CULL_MODE_NONE) so winding issues never hide the triangle
  (Alternatively set frontFace=COUNTER_CLOCKWISE and keep culling.)

Files in same folder:
- hello.vert
- hello.frag
"""

from __future__ import annotations

import os
import sys
import time
import ctypes
import importlib.util
from ctypes import wintypes
from pathlib import Path

# ============================================================
# Logging
# ============================================================
_T0 = time.perf_counter()

def log(msg: str) -> None:
    dt = time.perf_counter() - _T0
    print(f"[{dt:8.3f}] {msg}", flush=True)

def hx(h) -> str:
    if h is None:
        return "(null)"
    if isinstance(h, int):
        return f"0x{h:X}"
    if hasattr(h, "value"):
        v = h.value
        if v is None:
            return "(null)"
        if isinstance(v, int):
            return f"0x{v:X}"
        return str(v)
    try:
        return f"0x{int(h):X}"
    except Exception:
        return str(h)

# ============================================================
# DLL search path setup (Python 3.8+ safe)
# ============================================================
SCRIPT_DIR = Path(__file__).resolve().parent
try:
    os.add_dll_directory(str(SCRIPT_DIR))
    log(f"add_dll_directory: {SCRIPT_DIR}")
except Exception:
    pass

VKSDK = os.environ.get("VULKAN_SDK", "")
VKSDK_BIN = ""
if VKSDK:
    cand = Path(VKSDK) / "Bin"
    if cand.exists():
        VKSDK_BIN = str(cand)

if VKSDK_BIN:
    try:
        os.add_dll_directory(VKSDK_BIN)
        log(f"add_dll_directory: {VKSDK_BIN}")
    except Exception:
        pass

# ============================================================
# Win32 missing wintypes fallbacks
# ============================================================
for name in ("HICON", "HCURSOR", "HBRUSH", "LRESULT"):
    if not hasattr(wintypes, name):
        setattr(wintypes, name, wintypes.HANDLE)
LRESULT = getattr(wintypes, "LRESULT", wintypes.LPARAM)

# ============================================================
# Win32 API
# ============================================================
log("Loading user32/kernel32...")
user32 = ctypes.WinDLL("user32", use_last_error=True)
kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)

CS_OWNDC = 0x0020
WS_OVERLAPPEDWINDOW = 0x00CF0000
WS_EX_NOREDIRECTIONBITMAP = 0x00200000
CW_USEDEFAULT = 0x80000000
SW_SHOW = 5

WM_DESTROY = 0x0002
WM_CLOSE   = 0x0010
WM_QUIT    = 0x0012
WM_SIZE    = 0x0005
WM_PAINT   = 0x000F
PM_REMOVE  = 0x0001

IDI_APPLICATION = 32512
IDC_ARROW       = 32512

class POINT(ctypes.Structure):
    _fields_ = [("x", ctypes.c_long), ("y", ctypes.c_long)]

class MSG(ctypes.Structure):
    _fields_ = [
        ("hwnd", wintypes.HWND),
        ("message", wintypes.UINT),
        ("wParam", wintypes.WPARAM),
        ("lParam", wintypes.LPARAM),
        ("time", wintypes.DWORD),
        ("pt", POINT),
    ]

class RECT(ctypes.Structure):
    _fields_ = [("left", ctypes.c_long), ("top", ctypes.c_long),
                ("right", ctypes.c_long), ("bottom", ctypes.c_long)]

class PAINTSTRUCT(ctypes.Structure):
    _fields_ = [
        ("hdc", wintypes.HDC),
        ("fErase", wintypes.BOOL),
        ("rcPaint", RECT),
        ("fRestore", wintypes.BOOL),
        ("fIncUpdate", wintypes.BOOL),
        ("rgbReserved", ctypes.c_byte * 32),
    ]

WNDPROC = ctypes.WINFUNCTYPE(LRESULT, wintypes.HWND, wintypes.UINT, wintypes.WPARAM, wintypes.LPARAM)

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
    wintypes.HWND, wintypes.HMENU, wintypes.HINSTANCE, wintypes.LPVOID,
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

user32.LoadIconW.restype = wintypes.HICON
user32.LoadIconW.argtypes = (wintypes.HINSTANCE, wintypes.LPCWSTR)

user32.LoadCursorW.restype = wintypes.HCURSOR
user32.LoadCursorW.argtypes = (wintypes.HINSTANCE, wintypes.LPCWSTR)

user32.GetClientRect.restype = wintypes.BOOL
user32.GetClientRect.argtypes = (wintypes.HWND, ctypes.POINTER(RECT))

user32.BeginPaint.restype = wintypes.HDC
user32.BeginPaint.argtypes = (wintypes.HWND, ctypes.POINTER(PAINTSTRUCT))

user32.EndPaint.restype = wintypes.BOOL
user32.EndPaint.argtypes = (wintypes.HWND, ctypes.POINTER(PAINTSTRUCT))

_g_should_quit = False
_g_resized = False
_WNDPROC_REF = None
WIDTH = 640
HEIGHT = 480

def _get_client_size(hwnd) -> tuple[int, int]:
    rc = RECT()
    if not user32.GetClientRect(hwnd, ctypes.byref(rc)):
        raise ctypes.WinError(ctypes.get_last_error())
    w = max(1, int(rc.right - rc.left))
    h = max(1, int(rc.bottom - rc.top))
    return w, h

def create_window(title: str, width: int, height: int) -> tuple[wintypes.HWND, wintypes.HINSTANCE]:
    global _WNDPROC_REF, _g_should_quit, _g_resized

    hinst = kernel32.GetModuleHandleW(None)

    @WNDPROC
    def wndproc(hwnd, msg, wparam, lparam):
        global _g_should_quit, _g_resized
        if msg == WM_CLOSE:
            _g_should_quit = True
            user32.PostQuitMessage(0)
            return 0
        if msg == WM_DESTROY:
            _g_should_quit = True
            user32.PostQuitMessage(0)
            return 0
        if msg == WM_SIZE:
            w = int(lparam & 0xFFFF)
            h = int((lparam >> 16) & 0xFFFF)
            if w > 0 and h > 0:
                _g_resized = True
            return 0
        if msg == WM_PAINT:
            ps = PAINTSTRUCT()
            user32.BeginPaint(hwnd, ctypes.byref(ps))
            user32.EndPaint(hwnd, ctypes.byref(ps))
            return 0
        return user32.DefWindowProcW(hwnd, msg, wparam, lparam)

    _WNDPROC_REF = wndproc

    class_name = "VkTriangleWindow"
    wc = WNDCLASSEXW()
    wc.cbSize = ctypes.sizeof(WNDCLASSEXW)
    wc.style = CS_OWNDC
    wc.lpfnWndProc = wndproc
    wc.cbClsExtra = 0
    wc.cbWndExtra = 0
    wc.hInstance = hinst
    wc.hIcon = user32.LoadIconW(None, ctypes.c_wchar_p(IDI_APPLICATION))
    wc.hCursor = user32.LoadCursorW(None, ctypes.c_wchar_p(IDC_ARROW))
    wc.hbrBackground = 0
    wc.lpszMenuName = None
    wc.lpszClassName = class_name
    wc.hIconSm = wc.hIcon

    atom = user32.RegisterClassExW(ctypes.byref(wc))
    if not atom:
        raise ctypes.WinError(ctypes.get_last_error())

    hwnd = user32.CreateWindowExW(
        WS_EX_NOREDIRECTIONBITMAP, class_name, title, WS_OVERLAPPEDWINDOW,
        CW_USEDEFAULT, CW_USEDEFAULT, width, height,
        None, None, hinst, None,
    )
    if not hwnd:
        raise ctypes.WinError(ctypes.get_last_error())

    user32.ShowWindow(hwnd, SW_SHOW)
    user32.UpdateWindow(hwnd)
    return hwnd, hinst

def pump_messages() -> bool:
    msg = MSG()
    while user32.PeekMessageW(ctypes.byref(msg), None, 0, 0, PM_REMOVE):
        if msg.message == WM_QUIT:
            return False
        user32.TranslateMessage(ctypes.byref(msg))
        user32.DispatchMessageW(ctypes.byref(msg))
    return True

# ============================================================
# shaderc C API wrapper (GLSL -> SPIR-V)
# ============================================================
class Shaderc:
    # shaderc_shader_kind (C API)
    VERTEX = 0
    FRAGMENT = 1
    STATUS_SUCCESS = 0

    def __init__(self, dll_name: str = "shaderc_shared.dll"):
        self.dll_path = self._resolve_shaderc_path(dll_name)
        log(f"Loading shaderc: {self.dll_path}")
        self.lib = ctypes.CDLL(str(self.dll_path))

        self.lib.shaderc_compiler_initialize.restype = ctypes.c_void_p
        self.lib.shaderc_compiler_release.argtypes = [ctypes.c_void_p]

        self.lib.shaderc_compile_options_initialize.restype = ctypes.c_void_p
        self.lib.shaderc_compile_options_release.argtypes = [ctypes.c_void_p]
        self.lib.shaderc_compile_options_set_optimization_level.argtypes = [ctypes.c_void_p, ctypes.c_int]

        self.lib.shaderc_compile_into_spv.restype = ctypes.c_void_p
        self.lib.shaderc_compile_into_spv.argtypes = [
            ctypes.c_void_p, ctypes.c_char_p, ctypes.c_size_t, ctypes.c_int,
            ctypes.c_char_p, ctypes.c_char_p, ctypes.c_void_p,
        ]

        self.lib.shaderc_result_release.argtypes = [ctypes.c_void_p]
        self.lib.shaderc_result_get_length.restype = ctypes.c_size_t
        self.lib.shaderc_result_get_length.argtypes = [ctypes.c_void_p]
        self.lib.shaderc_result_get_bytes.restype = ctypes.c_void_p
        self.lib.shaderc_result_get_bytes.argtypes = [ctypes.c_void_p]
        self.lib.shaderc_result_get_compilation_status.restype = ctypes.c_int
        self.lib.shaderc_result_get_compilation_status.argtypes = [ctypes.c_void_p]
        self.lib.shaderc_result_get_error_message.restype = ctypes.c_char_p
        self.lib.shaderc_result_get_error_message.argtypes = [ctypes.c_void_p]

    def _resolve_shaderc_path(self, name: str) -> Path:
        p = Path(name)
        if p.is_file():
            return p.resolve()
        if VKSDK_BIN:
            cand = Path(VKSDK_BIN) / name
            if cand.is_file():
                return cand.resolve()
        cand = SCRIPT_DIR / name
        if cand.is_file():
            return cand.resolve()
        return Path(name)

    def compile(self, source_text: str, kind: int, filename: str, entry: str = "main") -> bytes:
        src = source_text.encode("utf-8")
        compiler = self.lib.shaderc_compiler_initialize()
        if not compiler:
            raise RuntimeError("shaderc_compiler_initialize failed")

        options = self.lib.shaderc_compile_options_initialize()
        if not options:
            self.lib.shaderc_compiler_release(compiler)
            raise RuntimeError("shaderc_compile_options_initialize failed")

        self.lib.shaderc_compile_options_set_optimization_level(options, 2)

        try:
            result = self.lib.shaderc_compile_into_spv(
                compiler,
                ctypes.c_char_p(src),
                len(src),
                kind,
                ctypes.c_char_p(filename.encode("utf-8")),
                ctypes.c_char_p(entry.encode("utf-8")),
                options,
            )
            if not result:
                raise RuntimeError("shaderc_compile_into_spv returned NULL")

            try:
                status = self.lib.shaderc_result_get_compilation_status(result)
                if status != self.STATUS_SUCCESS:
                    err = self.lib.shaderc_result_get_error_message(result)
                    msg = err.decode("utf-8", errors="replace") if err else "(no message)"
                    raise RuntimeError(f"Shader compilation failed ({status}): {msg}")

                length = self.lib.shaderc_result_get_length(result)
                ptr = self.lib.shaderc_result_get_bytes(result)
                if not ptr or length == 0:
                    raise RuntimeError("shaderc_result_get_bytes/length failed")

                return ctypes.string_at(ptr, length)
            finally:
                self.lib.shaderc_result_release(result)
        finally:
            self.lib.shaderc_compile_options_release(options)
            self.lib.shaderc_compiler_release(compiler)

# ============================================================
# Reuse D3D11 + Windows.UI.Composition helper from sibling sample
# ============================================================
_d3dcomp = None

def load_d3d11_composition_helper():
    global _d3dcomp
    if _d3dcomp is not None:
        return _d3dcomp

    helper_path = SCRIPT_DIR.parent / "triangle_d3d11" / "hello.py"
    spec = importlib.util.spec_from_file_location("py_d3d11_comp_helper", helper_path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Failed to load helper module: {helper_path}")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    _d3dcomp = mod
    return mod

# ============================================================
# Vulkan minimal definitions
# ============================================================
log("Loading vulkan-1.dll...")
vk_dll = ctypes.WinDLL("vulkan-1", use_last_error=True)

VkFlags      = ctypes.c_uint32
VkBool32     = ctypes.c_uint32
VkDeviceSize = ctypes.c_uint64
VkResult     = ctypes.c_int32

# Dispatchable handles
VkInstance       = ctypes.c_void_p
VkPhysicalDevice = ctypes.c_void_p
VkDevice         = ctypes.c_void_p
VkQueue          = ctypes.c_void_p
VkCommandPool    = ctypes.c_void_p
VkCommandBuffer  = ctypes.c_void_p

# Non-dispatchable handles (uint64)
VkSurfaceKHR     = ctypes.c_uint64
VkSwapchainKHR   = ctypes.c_uint64
VkImage          = ctypes.c_uint64
VkBuffer         = ctypes.c_uint64
VkDeviceMemory   = ctypes.c_uint64
VkImageView      = ctypes.c_uint64
VkShaderModule   = ctypes.c_uint64
VkRenderPass     = ctypes.c_uint64
VkPipelineLayout = ctypes.c_uint64
VkPipeline       = ctypes.c_uint64
VkFramebuffer    = ctypes.c_uint64
VkSemaphore      = ctypes.c_uint64
VkFence          = ctypes.c_uint64

VK_SUCCESS = 0
VK_ERROR_OUT_OF_DATE_KHR = -1000001004
VK_SUBOPTIMAL_KHR        = 1000001003

# VK_STRUCTURE_TYPE_*
VK_STRUCTURE_TYPE_APPLICATION_INFO                      = 0
VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO                  = 1
VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO              = 2
VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO                    = 3
VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO                  = 5
VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO                    = 12
VK_STRUCTURE_TYPE_IMAGE_CREATE_INFO                     = 14
VK_STRUCTURE_TYPE_WIN32_SURFACE_CREATE_INFO_KHR         = 1000009000
VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR             = 1000001000
VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO                = 15
VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO             = 16
VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO               = 38
VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO     = 18
VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO = 19
VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO = 20
VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO   = 22
VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO = 23
VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO = 24
VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO = 26
VK_STRUCTURE_TYPE_PIPELINE_DYNAMIC_STATE_CREATE_INFO    = 27
VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO           = 30
VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO         = 28
VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO               = 37
VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO              = 39
VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO          = 40
VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO             = 42
VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO                = 43
VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO                 = 9
VK_STRUCTURE_TYPE_FENCE_CREATE_INFO                     = 8
VK_STRUCTURE_TYPE_SUBMIT_INFO                           = 4
VK_STRUCTURE_TYPE_PRESENT_INFO_KHR                      = 1000001002

# Extensions
VK_KHR_SURFACE_EXTENSION_NAME       = b"VK_KHR_surface"
VK_KHR_WIN32_SURFACE_EXTENSION_NAME = b"VK_KHR_win32_surface"
VK_KHR_SWAPCHAIN_EXTENSION_NAME     = b"VK_KHR_swapchain"

# Queue flags
VK_QUEUE_GRAPHICS_BIT = 0x00000001

# Command pool flags
VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT = 0x00000002

# Pipeline
VK_PIPELINE_BIND_POINT_GRAPHICS = 0
VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST = 3

VK_POLYGON_MODE_FILL = 0
VK_CULL_MODE_NONE = 0  # <-- FIX: disable culling to avoid black screen from winding mismatch
VK_FRONT_FACE_COUNTER_CLOCKWISE = 1

VK_SAMPLE_COUNT_1_BIT = 1

VK_COLOR_COMPONENT_R_BIT = 0x1
VK_COLOR_COMPONENT_G_BIT = 0x2
VK_COLOR_COMPONENT_B_BIT = 0x4
VK_COLOR_COMPONENT_A_BIT = 0x8

VK_DYNAMIC_STATE_VIEWPORT = 0
VK_DYNAMIC_STATE_SCISSOR  = 1

# Image / layout
VK_IMAGE_ASPECT_COLOR_BIT = 0x1
VK_IMAGE_TYPE_2D = 1
VK_IMAGE_TILING_OPTIMAL = 0
VK_IMAGE_VIEW_TYPE_2D = 1

VK_IMAGE_LAYOUT_UNDEFINED = 0
VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL = 2
VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL = 6
VK_IMAGE_LAYOUT_PRESENT_SRC_KHR = 1000001002

# Attachment
VK_ATTACHMENT_LOAD_OP_CLEAR  = 1
VK_ATTACHMENT_STORE_OP_STORE = 0

# Sharing mode
VK_SHARING_MODE_EXCLUSIVE   = 0
VK_SHARING_MODE_CONCURRENT  = 1

# Image/buffer usage
VK_IMAGE_USAGE_TRANSFER_SRC_BIT = 0x00000001
VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT = 0x00000010
VK_BUFFER_USAGE_TRANSFER_DST_BIT = 0x00000002

# Memory properties
VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT   = 0x00000001
VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT   = 0x00000002
VK_MEMORY_PROPERTY_HOST_COHERENT_BIT  = 0x00000004

# Formats
VK_FORMAT_B8G8R8A8_UNORM = 44

# Present mode
VK_PRESENT_MODE_FIFO_KHR = 2

# Composite alpha / transform
VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR = 0x00000001
VK_SURFACE_TRANSFORM_IDENTITY_BIT_KHR = 0x00000001

# Pipeline stage
VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT = 0x00000400

# Fence
VK_FENCE_CREATE_SIGNALED_BIT = 0x00000001

# Command buffer
VK_COMMAND_BUFFER_LEVEL_PRIMARY = 0

# Shader stage
VK_SHADER_STAGE_VERTEX_BIT   = 0x00000001
VK_SHADER_STAGE_FRAGMENT_BIT = 0x00000010

# Image usage
VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT = 0x00000010

# ============================================================
# Vulkan structs
# ============================================================
class VkApplicationInfo(ctypes.Structure):
    _fields_ = [
        ("sType", ctypes.c_uint32),
        ("pNext", ctypes.c_void_p),
        ("pApplicationName", ctypes.c_char_p),
        ("applicationVersion", ctypes.c_uint32),
        ("pEngineName", ctypes.c_char_p),
        ("engineVersion", ctypes.c_uint32),
        ("apiVersion", ctypes.c_uint32),
    ]

class VkInstanceCreateInfo(ctypes.Structure):
    _fields_ = [
        ("sType", ctypes.c_uint32),
        ("pNext", ctypes.c_void_p),
        ("flags", ctypes.c_uint32),
        ("pApplicationInfo", ctypes.POINTER(VkApplicationInfo)),
        ("enabledLayerCount", ctypes.c_uint32),
        ("ppEnabledLayerNames", ctypes.POINTER(ctypes.c_char_p)),
        ("enabledExtensionCount", ctypes.c_uint32),
        ("ppEnabledExtensionNames", ctypes.POINTER(ctypes.c_char_p)),
    ]

class VkWin32SurfaceCreateInfoKHR(ctypes.Structure):
    _fields_ = [
        ("sType", ctypes.c_uint32),
        ("pNext", ctypes.c_void_p),
        ("flags", ctypes.c_uint32),
        ("hinstance", wintypes.HINSTANCE),
        ("hwnd", wintypes.HWND),
    ]

class VkExtent2D(ctypes.Structure):
    _fields_ = [("width", ctypes.c_uint32), ("height", ctypes.c_uint32)]

class VkExtent3D(ctypes.Structure):
    _fields_ = [("width", ctypes.c_uint32), ("height", ctypes.c_uint32), ("depth", ctypes.c_uint32)]

class VkOffset3D(ctypes.Structure):
    _fields_ = [("x", ctypes.c_int32), ("y", ctypes.c_int32), ("z", ctypes.c_int32)]

class VkImageCreateInfo(ctypes.Structure):
    _fields_ = [
        ("sType", ctypes.c_uint32),
        ("pNext", ctypes.c_void_p),
        ("flags", ctypes.c_uint32),
        ("imageType", ctypes.c_uint32),
        ("format", ctypes.c_uint32),
        ("extent", VkExtent3D),
        ("mipLevels", ctypes.c_uint32),
        ("arrayLayers", ctypes.c_uint32),
        ("samples", ctypes.c_uint32),
        ("tiling", ctypes.c_uint32),
        ("usage", ctypes.c_uint32),
        ("sharingMode", ctypes.c_uint32),
        ("queueFamilyIndexCount", ctypes.c_uint32),
        ("pQueueFamilyIndices", ctypes.POINTER(ctypes.c_uint32)),
        ("initialLayout", ctypes.c_uint32),
    ]

class VkMemoryRequirements(ctypes.Structure):
    _fields_ = [
        ("size", VkDeviceSize),
        ("alignment", VkDeviceSize),
        ("memoryTypeBits", ctypes.c_uint32),
    ]

class VkMemoryAllocateInfo(ctypes.Structure):
    _fields_ = [
        ("sType", ctypes.c_uint32),
        ("pNext", ctypes.c_void_p),
        ("allocationSize", VkDeviceSize),
        ("memoryTypeIndex", ctypes.c_uint32),
    ]

class VkBufferCreateInfo(ctypes.Structure):
    _fields_ = [
        ("sType", ctypes.c_uint32),
        ("pNext", ctypes.c_void_p),
        ("flags", ctypes.c_uint32),
        ("size", VkDeviceSize),
        ("usage", ctypes.c_uint32),
        ("sharingMode", ctypes.c_uint32),
        ("queueFamilyIndexCount", ctypes.c_uint32),
        ("pQueueFamilyIndices", ctypes.POINTER(ctypes.c_uint32)),
    ]

class VkMemoryType(ctypes.Structure):
    _fields_ = [("propertyFlags", ctypes.c_uint32), ("heapIndex", ctypes.c_uint32)]

class VkMemoryHeap(ctypes.Structure):
    _fields_ = [("size", VkDeviceSize), ("flags", ctypes.c_uint32)]

class VkPhysicalDeviceMemoryProperties(ctypes.Structure):
    _fields_ = [
        ("memoryTypeCount", ctypes.c_uint32),
        ("memoryTypes", VkMemoryType * 32),
        ("memoryHeapCount", ctypes.c_uint32),
        ("memoryHeaps", VkMemoryHeap * 16),
    ]

class VkImageSubresourceLayers(ctypes.Structure):
    _fields_ = [
        ("aspectMask", ctypes.c_uint32),
        ("mipLevel", ctypes.c_uint32),
        ("baseArrayLayer", ctypes.c_uint32),
        ("layerCount", ctypes.c_uint32),
    ]

class VkBufferImageCopy(ctypes.Structure):
    _fields_ = [
        ("bufferOffset", VkDeviceSize),
        ("bufferRowLength", ctypes.c_uint32),
        ("bufferImageHeight", ctypes.c_uint32),
        ("imageSubresource", VkImageSubresourceLayers),
        ("imageOffset", VkOffset3D),
        ("imageExtent", VkExtent3D),
    ]

class VkSurfaceCapabilitiesKHR(ctypes.Structure):
    _fields_ = [
        ("minImageCount", ctypes.c_uint32),
        ("maxImageCount", ctypes.c_uint32),
        ("currentExtent", VkExtent2D),
        ("minImageExtent", VkExtent2D),
        ("maxImageExtent", VkExtent2D),
        ("maxImageArrayLayers", ctypes.c_uint32),
        ("supportedTransforms", ctypes.c_uint32),
        ("currentTransform", ctypes.c_uint32),
        ("supportedCompositeAlpha", ctypes.c_uint32),
        ("supportedUsageFlags", ctypes.c_uint32),
    ]

class VkSurfaceFormatKHR(ctypes.Structure):
    _fields_ = [("format", ctypes.c_uint32), ("colorSpace", ctypes.c_uint32)]

class VkDeviceQueueCreateInfo(ctypes.Structure):
    _fields_ = [
        ("sType", ctypes.c_uint32),
        ("pNext", ctypes.c_void_p),
        ("flags", ctypes.c_uint32),
        ("queueFamilyIndex", ctypes.c_uint32),
        ("queueCount", ctypes.c_uint32),
        ("pQueuePriorities", ctypes.POINTER(ctypes.c_float)),
    ]

class VkDeviceCreateInfo(ctypes.Structure):
    _fields_ = [
        ("sType", ctypes.c_uint32),
        ("pNext", ctypes.c_void_p),
        ("flags", ctypes.c_uint32),
        ("queueCreateInfoCount", ctypes.c_uint32),
        ("pQueueCreateInfos", ctypes.POINTER(VkDeviceQueueCreateInfo)),
        ("enabledLayerCount", ctypes.c_uint32),
        ("ppEnabledLayerNames", ctypes.POINTER(ctypes.c_char_p)),
        ("enabledExtensionCount", ctypes.c_uint32),
        ("ppEnabledExtensionNames", ctypes.POINTER(ctypes.c_char_p)),
        ("pEnabledFeatures", ctypes.c_void_p),
    ]

class VkQueueFamilyProperties(ctypes.Structure):
    _fields_ = [
        ("queueFlags", ctypes.c_uint32),
        ("queueCount", ctypes.c_uint32),
        ("timestampValidBits", ctypes.c_uint32),
        ("minImageTransferGranularity", VkExtent3D),
    ]

class VkSwapchainCreateInfoKHR(ctypes.Structure):
    _fields_ = [
        ("sType", ctypes.c_uint32),
        ("pNext", ctypes.c_void_p),
        ("flags", ctypes.c_uint32),
        ("surface", VkSurfaceKHR),
        ("minImageCount", ctypes.c_uint32),
        ("imageFormat", ctypes.c_uint32),
        ("imageColorSpace", ctypes.c_uint32),
        ("imageExtent", VkExtent2D),
        ("imageArrayLayers", ctypes.c_uint32),
        ("imageUsage", ctypes.c_uint32),
        ("imageSharingMode", ctypes.c_uint32),
        ("queueFamilyIndexCount", ctypes.c_uint32),
        ("pQueueFamilyIndices", ctypes.POINTER(ctypes.c_uint32)),
        ("preTransform", ctypes.c_uint32),
        ("compositeAlpha", ctypes.c_uint32),
        ("presentMode", ctypes.c_uint32),
        ("clipped", VkBool32),
        ("oldSwapchain", VkSwapchainKHR),
    ]

class VkComponentMapping(ctypes.Structure):
    _fields_ = [("r", ctypes.c_uint32), ("g", ctypes.c_uint32), ("b", ctypes.c_uint32), ("a", ctypes.c_uint32)]

class VkImageSubresourceRange(ctypes.Structure):
    _fields_ = [
        ("aspectMask", ctypes.c_uint32),
        ("baseMipLevel", ctypes.c_uint32),
        ("levelCount", ctypes.c_uint32),
        ("baseArrayLayer", ctypes.c_uint32),
        ("layerCount", ctypes.c_uint32),
    ]

class VkImageViewCreateInfo(ctypes.Structure):
    _fields_ = [
        ("sType", ctypes.c_uint32),
        ("pNext", ctypes.c_void_p),
        ("flags", ctypes.c_uint32),
        ("image", VkImage),
        ("viewType", ctypes.c_uint32),
        ("format", ctypes.c_uint32),
        ("components", VkComponentMapping),
        ("subresourceRange", VkImageSubresourceRange),
    ]

class VkAttachmentDescription(ctypes.Structure):
    _fields_ = [
        ("flags", ctypes.c_uint32),
        ("format", ctypes.c_uint32),
        ("samples", ctypes.c_uint32),
        ("loadOp", ctypes.c_uint32),
        ("storeOp", ctypes.c_uint32),
        ("stencilLoadOp", ctypes.c_uint32),
        ("stencilStoreOp", ctypes.c_uint32),
        ("initialLayout", ctypes.c_uint32),
        ("finalLayout", ctypes.c_uint32),
    ]

class VkAttachmentReference(ctypes.Structure):
    _fields_ = [("attachment", ctypes.c_uint32), ("layout", ctypes.c_uint32)]

class VkSubpassDescription(ctypes.Structure):
    _fields_ = [
        ("flags", ctypes.c_uint32),
        ("pipelineBindPoint", ctypes.c_uint32),
        ("inputAttachmentCount", ctypes.c_uint32),
        ("pInputAttachments", ctypes.c_void_p),
        ("colorAttachmentCount", ctypes.c_uint32),
        ("pColorAttachments", ctypes.POINTER(VkAttachmentReference)),
        ("pResolveAttachments", ctypes.c_void_p),
        ("pDepthStencilAttachment", ctypes.c_void_p),
        ("preserveAttachmentCount", ctypes.c_uint32),
        ("pPreserveAttachments", ctypes.c_void_p),
    ]

class VkRenderPassCreateInfo(ctypes.Structure):
    _fields_ = [
        ("sType", ctypes.c_uint32),
        ("pNext", ctypes.c_void_p),
        ("flags", ctypes.c_uint32),
        ("attachmentCount", ctypes.c_uint32),
        ("pAttachments", ctypes.POINTER(VkAttachmentDescription)),
        ("subpassCount", ctypes.c_uint32),
        ("pSubpasses", ctypes.POINTER(VkSubpassDescription)),
        ("dependencyCount", ctypes.c_uint32),
        ("pDependencies", ctypes.c_void_p),
    ]

class VkShaderModuleCreateInfo(ctypes.Structure):
    _fields_ = [
        ("sType", ctypes.c_uint32),
        ("pNext", ctypes.c_void_p),
        ("flags", ctypes.c_uint32),
        ("codeSize", ctypes.c_size_t),
        ("pCode", ctypes.POINTER(ctypes.c_uint32)),
    ]

class VkPipelineShaderStageCreateInfo(ctypes.Structure):
    _fields_ = [
        ("sType", ctypes.c_uint32),
        ("pNext", ctypes.c_void_p),
        ("flags", ctypes.c_uint32),
        ("stage", ctypes.c_uint32),
        ("module", VkShaderModule),
        ("pName", ctypes.c_char_p),
        ("pSpecializationInfo", ctypes.c_void_p),
    ]

class VkPipelineVertexInputStateCreateInfo(ctypes.Structure):
    _fields_ = [
        ("sType", ctypes.c_uint32),
        ("pNext", ctypes.c_void_p),
        ("flags", ctypes.c_uint32),
        ("vertexBindingDescriptionCount", ctypes.c_uint32),
        ("pVertexBindingDescriptions", ctypes.c_void_p),
        ("vertexAttributeDescriptionCount", ctypes.c_uint32),
        ("pVertexAttributeDescriptions", ctypes.c_void_p),
    ]

class VkPipelineInputAssemblyStateCreateInfo(ctypes.Structure):
    _fields_ = [
        ("sType", ctypes.c_uint32),
        ("pNext", ctypes.c_void_p),
        ("flags", ctypes.c_uint32),
        ("topology", ctypes.c_uint32),
        ("primitiveRestartEnable", VkBool32),
    ]

class VkViewport(ctypes.Structure):
    _fields_ = [
        ("x", ctypes.c_float),
        ("y", ctypes.c_float),
        ("width", ctypes.c_float),
        ("height", ctypes.c_float),
        ("minDepth", ctypes.c_float),
        ("maxDepth", ctypes.c_float),
    ]

class VkOffset2D(ctypes.Structure):
    _fields_ = [("x", ctypes.c_int32), ("y", ctypes.c_int32)]

class VkRect2D(ctypes.Structure):
    _fields_ = [("offset", VkOffset2D), ("extent", VkExtent2D)]

class VkPipelineViewportStateCreateInfo(ctypes.Structure):
    _fields_ = [
        ("sType", ctypes.c_uint32),
        ("pNext", ctypes.c_void_p),
        ("flags", ctypes.c_uint32),
        ("viewportCount", ctypes.c_uint32),
        ("pViewports", ctypes.POINTER(VkViewport)),
        ("scissorCount", ctypes.c_uint32),
        ("pScissors", ctypes.POINTER(VkRect2D)),
    ]

class VkPipelineRasterizationStateCreateInfo(ctypes.Structure):
    _fields_ = [
        ("sType", ctypes.c_uint32),
        ("pNext", ctypes.c_void_p),
        ("flags", ctypes.c_uint32),
        ("depthClampEnable", VkBool32),
        ("rasterizerDiscardEnable", VkBool32),
        ("polygonMode", ctypes.c_uint32),
        ("cullMode", ctypes.c_uint32),
        ("frontFace", ctypes.c_uint32),
        ("depthBiasEnable", VkBool32),
        ("depthBiasConstantFactor", ctypes.c_float),
        ("depthBiasClamp", ctypes.c_float),
        ("depthBiasSlopeFactor", ctypes.c_float),
        ("lineWidth", ctypes.c_float),
    ]

class VkPipelineMultisampleStateCreateInfo(ctypes.Structure):
    _fields_ = [
        ("sType", ctypes.c_uint32),
        ("pNext", ctypes.c_void_p),
        ("flags", ctypes.c_uint32),
        ("rasterizationSamples", ctypes.c_uint32),
        ("sampleShadingEnable", VkBool32),
        ("minSampleShading", ctypes.c_float),
        ("pSampleMask", ctypes.c_void_p),
        ("alphaToCoverageEnable", VkBool32),
        ("alphaToOneEnable", VkBool32),
    ]

class VkPipelineColorBlendAttachmentState(ctypes.Structure):
    _fields_ = [
        ("blendEnable", VkBool32),
        ("srcColorBlendFactor", ctypes.c_uint32),
        ("dstColorBlendFactor", ctypes.c_uint32),
        ("colorBlendOp", ctypes.c_uint32),
        ("srcAlphaBlendFactor", ctypes.c_uint32),
        ("dstAlphaBlendFactor", ctypes.c_uint32),
        ("alphaBlendOp", ctypes.c_uint32),
        ("colorWriteMask", ctypes.c_uint32),
    ]

class VkPipelineColorBlendStateCreateInfo(ctypes.Structure):
    _fields_ = [
        ("sType", ctypes.c_uint32),
        ("pNext", ctypes.c_void_p),
        ("flags", ctypes.c_uint32),
        ("logicOpEnable", VkBool32),
        ("logicOp", ctypes.c_uint32),
        ("attachmentCount", ctypes.c_uint32),
        ("pAttachments", ctypes.POINTER(VkPipelineColorBlendAttachmentState)),
        ("blendConstants", ctypes.c_float * 4),
    ]

class VkDynamicStateCreateInfo(ctypes.Structure):
    _fields_ = [
        ("sType", ctypes.c_uint32),
        ("pNext", ctypes.c_void_p),
        ("flags", ctypes.c_uint32),
        ("dynamicStateCount", ctypes.c_uint32),
        ("pDynamicStates", ctypes.POINTER(ctypes.c_uint32)),
    ]

class VkPipelineLayoutCreateInfo(ctypes.Structure):
    _fields_ = [
        ("sType", ctypes.c_uint32),
        ("pNext", ctypes.c_void_p),
        ("flags", ctypes.c_uint32),
        ("setLayoutCount", ctypes.c_uint32),
        ("pSetLayouts", ctypes.c_void_p),
        ("pushConstantRangeCount", ctypes.c_uint32),
        ("pPushConstantRanges", ctypes.c_void_p),
    ]

class VkGraphicsPipelineCreateInfo(ctypes.Structure):
    _fields_ = [
        ("sType", ctypes.c_uint32),
        ("pNext", ctypes.c_void_p),
        ("flags", ctypes.c_uint32),
        ("stageCount", ctypes.c_uint32),
        ("pStages", ctypes.POINTER(VkPipelineShaderStageCreateInfo)),
        ("pVertexInputState", ctypes.POINTER(VkPipelineVertexInputStateCreateInfo)),
        ("pInputAssemblyState", ctypes.POINTER(VkPipelineInputAssemblyStateCreateInfo)),
        ("pTessellationState", ctypes.c_void_p),
        ("pViewportState", ctypes.POINTER(VkPipelineViewportStateCreateInfo)),
        ("pRasterizationState", ctypes.POINTER(VkPipelineRasterizationStateCreateInfo)),
        ("pMultisampleState", ctypes.POINTER(VkPipelineMultisampleStateCreateInfo)),
        ("pDepthStencilState", ctypes.c_void_p),
        ("pColorBlendState", ctypes.POINTER(VkPipelineColorBlendStateCreateInfo)),
        ("pDynamicState", ctypes.POINTER(VkDynamicStateCreateInfo)),
        ("layout", VkPipelineLayout),
        ("renderPass", VkRenderPass),
        ("subpass", ctypes.c_uint32),
        ("basePipelineHandle", VkPipeline),
        ("basePipelineIndex", ctypes.c_int32),
    ]

class VkFramebufferCreateInfo(ctypes.Structure):
    _fields_ = [
        ("sType", ctypes.c_uint32),
        ("pNext", ctypes.c_void_p),
        ("flags", ctypes.c_uint32),
        ("renderPass", VkRenderPass),
        ("attachmentCount", ctypes.c_uint32),
        ("pAttachments", ctypes.POINTER(VkImageView)),
        ("width", ctypes.c_uint32),
        ("height", ctypes.c_uint32),
        ("layers", ctypes.c_uint32),
    ]

class VkCommandPoolCreateInfo(ctypes.Structure):
    _fields_ = [("sType", ctypes.c_uint32), ("pNext", ctypes.c_void_p), ("flags", ctypes.c_uint32), ("queueFamilyIndex", ctypes.c_uint32)]

class VkCommandBufferAllocateInfo(ctypes.Structure):
    _fields_ = [("sType", ctypes.c_uint32), ("pNext", ctypes.c_void_p), ("commandPool", VkCommandPool), ("level", ctypes.c_uint32), ("commandBufferCount", ctypes.c_uint32)]

class VkCommandBufferBeginInfo(ctypes.Structure):
    _fields_ = [("sType", ctypes.c_uint32), ("pNext", ctypes.c_void_p), ("flags", ctypes.c_uint32), ("pInheritanceInfo", ctypes.c_void_p)]

class VkClearColorValue(ctypes.Structure):
    _fields_ = [("float32", ctypes.c_float * 4)]

class VkClearValue(ctypes.Union):
    _fields_ = [("color", VkClearColorValue)]

class VkRenderPassBeginInfo(ctypes.Structure):
    _fields_ = [
        ("sType", ctypes.c_uint32),
        ("pNext", ctypes.c_void_p),
        ("renderPass", VkRenderPass),
        ("framebuffer", VkFramebuffer),
        ("renderArea", VkRect2D),
        ("clearValueCount", ctypes.c_uint32),
        ("pClearValues", ctypes.POINTER(VkClearValue)),
    ]

class VkSemaphoreCreateInfo(ctypes.Structure):
    _fields_ = [("sType", ctypes.c_uint32), ("pNext", ctypes.c_void_p), ("flags", ctypes.c_uint32)]

class VkFenceCreateInfo(ctypes.Structure):
    _fields_ = [("sType", ctypes.c_uint32), ("pNext", ctypes.c_void_p), ("flags", ctypes.c_uint32)]

class VkSubmitInfo(ctypes.Structure):
    _fields_ = [
        ("sType", ctypes.c_uint32),
        ("pNext", ctypes.c_void_p),
        ("waitSemaphoreCount", ctypes.c_uint32),
        ("pWaitSemaphores", ctypes.POINTER(VkSemaphore)),
        ("pWaitDstStageMask", ctypes.POINTER(ctypes.c_uint32)),
        ("commandBufferCount", ctypes.c_uint32),
        ("pCommandBuffers", ctypes.POINTER(VkCommandBuffer)),
        ("signalSemaphoreCount", ctypes.c_uint32),
        ("pSignalSemaphores", ctypes.POINTER(VkSemaphore)),
    ]

class VkPresentInfoKHR(ctypes.Structure):
    _fields_ = [
        ("sType", ctypes.c_uint32),
        ("pNext", ctypes.c_void_p),
        ("waitSemaphoreCount", ctypes.c_uint32),
        ("pWaitSemaphores", ctypes.POINTER(VkSemaphore)),
        ("swapchainCount", ctypes.c_uint32),
        ("pSwapchains", ctypes.POINTER(VkSwapchainKHR)),
        ("pImageIndices", ctypes.POINTER(ctypes.c_uint32)),
        ("pResults", ctypes.c_void_p),
    ]

# ============================================================
# Vulkan function loading helpers
# ============================================================
PFN_vkVoidFunction = ctypes.c_void_p

vk_dll.vkGetInstanceProcAddr.restype = PFN_vkVoidFunction
vk_dll.vkGetInstanceProcAddr.argtypes = (VkInstance, ctypes.c_char_p)

vk_dll.vkGetDeviceProcAddr.restype = PFN_vkVoidFunction
vk_dll.vkGetDeviceProcAddr.argtypes = (VkDevice, ctypes.c_char_p)

def _get_global(name: bytes, restype, argtypes):
    fn = getattr(vk_dll, name.decode("ascii"))
    fn.restype = restype
    fn.argtypes = argtypes
    return fn

def _get_inst(instance: VkInstance, name: bytes, restype, argtypes):
    addr = vk_dll.vkGetInstanceProcAddr(instance, name)
    if not addr:
        raise RuntimeError(f"vkGetInstanceProcAddr failed for {name!r}")
    ftype = ctypes.WINFUNCTYPE(restype, *argtypes)
    return ftype(addr)

def _get_dev(device: VkDevice, name: bytes, restype, argtypes):
    addr = vk_dll.vkGetDeviceProcAddr(device, name)
    if not addr:
        raise RuntimeError(f"vkGetDeviceProcAddr failed for {name!r}")
    ftype = ctypes.WINFUNCTYPE(restype, *argtypes)
    return ftype(addr)

def vk_check(res: int, what: str) -> None:
    if res != VK_SUCCESS:
        raise RuntimeError(f"{what} failed: VkResult={res}")

# Global exported
vkCreateInstance = _get_global(b"vkCreateInstance", VkResult, (ctypes.POINTER(VkInstanceCreateInfo), ctypes.c_void_p, ctypes.POINTER(VkInstance)))
vkEnumeratePhysicalDevices = _get_global(b"vkEnumeratePhysicalDevices", VkResult, (VkInstance, ctypes.POINTER(ctypes.c_uint32), ctypes.POINTER(VkPhysicalDevice)))
vkGetPhysicalDeviceQueueFamilyProperties = _get_global(b"vkGetPhysicalDeviceQueueFamilyProperties", None, (VkPhysicalDevice, ctypes.POINTER(ctypes.c_uint32), ctypes.POINTER(VkQueueFamilyProperties)))
vkCreateDevice = _get_global(b"vkCreateDevice", VkResult, (VkPhysicalDevice, ctypes.POINTER(VkDeviceCreateInfo), ctypes.c_void_p, ctypes.POINTER(VkDevice)))
vkDestroyInstance = _get_global(b"vkDestroyInstance", None, (VkInstance, ctypes.c_void_p))

# ============================================================
# Vulkan helpers
# ============================================================
def create_instance() -> VkInstance:
    exts = (ctypes.c_char_p * 2)(VK_KHR_SURFACE_EXTENSION_NAME, VK_KHR_WIN32_SURFACE_EXTENSION_NAME)

    api_1_4 = (1 << 22) | (4 << 12) | 0

    app = VkApplicationInfo(
        sType=VK_STRUCTURE_TYPE_APPLICATION_INFO,
        pNext=None,
        pApplicationName=b"PyVulkanTriangle",
        applicationVersion=1,
        pEngineName=b"NoEngine",
        engineVersion=1,
        apiVersion=api_1_4,
    )

    ici = VkInstanceCreateInfo(
        sType=VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
        pNext=None,
        flags=0,
        pApplicationInfo=ctypes.pointer(app),
        enabledLayerCount=0,
        ppEnabledLayerNames=None,
        enabledExtensionCount=2,
        ppEnabledExtensionNames=ctypes.cast(exts, ctypes.POINTER(ctypes.c_char_p)),
    )

    inst = VkInstance()
    vk_check(vkCreateInstance(ctypes.byref(ici), None, ctypes.byref(inst)), "vkCreateInstance")
    return inst

def create_surface(instance: VkInstance, hwnd, hinst) -> VkSurfaceKHR:
    vkCreateWin32SurfaceKHR = _get_inst(
        instance,
        b"vkCreateWin32SurfaceKHR",
        VkResult,
        (VkInstance, ctypes.POINTER(VkWin32SurfaceCreateInfoKHR), ctypes.c_void_p, ctypes.POINTER(VkSurfaceKHR)),
    )

    sci = VkWin32SurfaceCreateInfoKHR(
        sType=VK_STRUCTURE_TYPE_WIN32_SURFACE_CREATE_INFO_KHR,
        pNext=None,
        flags=0,
        hinstance=hinst,
        hwnd=hwnd,
    )

    surface = VkSurfaceKHR(0)
    vk_check(vkCreateWin32SurfaceKHR(instance, ctypes.byref(sci), None, ctypes.byref(surface)), "vkCreateWin32SurfaceKHR")
    return surface

def pick_physical_device(instance: VkInstance, surface: VkSurfaceKHR) -> tuple[VkPhysicalDevice, int, int]:
    vkGetPhysicalDeviceSurfaceSupportKHR = _get_inst(
        instance,
        b"vkGetPhysicalDeviceSurfaceSupportKHR",
        VkResult,
        (VkPhysicalDevice, ctypes.c_uint32, VkSurfaceKHR, ctypes.POINTER(VkBool32)),
    )

    count = ctypes.c_uint32(0)
    vk_check(vkEnumeratePhysicalDevices(instance, ctypes.byref(count), None), "vkEnumeratePhysicalDevices(count)")
    if count.value == 0:
        raise RuntimeError("No Vulkan physical devices found")

    devs = (VkPhysicalDevice * count.value)()
    vk_check(vkEnumeratePhysicalDevices(instance, ctypes.byref(count), devs), "vkEnumeratePhysicalDevices(list)")

    for i in range(count.value):
        pd = devs[i]

        qcount = ctypes.c_uint32(0)
        vkGetPhysicalDeviceQueueFamilyProperties(pd, ctypes.byref(qcount), None)
        props = (VkQueueFamilyProperties * qcount.value)()
        vkGetPhysicalDeviceQueueFamilyProperties(pd, ctypes.byref(qcount), props)

        graphics_idx = -1
        present_idx = -1

        for qi in range(qcount.value):
            if (props[qi].queueFlags & VK_QUEUE_GRAPHICS_BIT) != 0:
                graphics_idx = qi

            supported = VkBool32(0)
            vk_check(vkGetPhysicalDeviceSurfaceSupportKHR(pd, qi, surface, ctypes.byref(supported)), "vkGetPhysicalDeviceSurfaceSupportKHR")
            if supported.value != 0:
                present_idx = qi

            if graphics_idx != -1 and present_idx != -1:
                return pd, graphics_idx, present_idx

    raise RuntimeError("No suitable physical device/queue family found")

def create_device(pd: VkPhysicalDevice, graphics_q: int, present_q: int) -> tuple[VkDevice, VkQueue, VkQueue]:
    unique_q = sorted(set([graphics_q, present_q]))
    priorities = (ctypes.c_float * 1)(1.0)
    qinfos = (VkDeviceQueueCreateInfo * len(unique_q))()
    for i, qfi in enumerate(unique_q):
        qinfos[i] = VkDeviceQueueCreateInfo(
            sType=VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
            pNext=None,
            flags=0,
            queueFamilyIndex=qfi,
            queueCount=1,
            pQueuePriorities=priorities,
        )

    dev_exts = (ctypes.c_char_p * 1)(VK_KHR_SWAPCHAIN_EXTENSION_NAME)

    dci = VkDeviceCreateInfo(
        sType=VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO,
        pNext=None,
        flags=0,
        queueCreateInfoCount=len(unique_q),
        pQueueCreateInfos=ctypes.cast(qinfos, ctypes.POINTER(VkDeviceQueueCreateInfo)),
        enabledLayerCount=0,
        ppEnabledLayerNames=None,
        enabledExtensionCount=1,
        ppEnabledExtensionNames=ctypes.cast(dev_exts, ctypes.POINTER(ctypes.c_char_p)),
        pEnabledFeatures=None,
    )

    device = VkDevice()
    vk_check(vkCreateDevice(pd, ctypes.byref(dci), None, ctypes.byref(device)), "vkCreateDevice")

    vkGetDeviceQueue = _get_dev(device, b"vkGetDeviceQueue", None, (VkDevice, ctypes.c_uint32, ctypes.c_uint32, ctypes.POINTER(VkQueue)))
    gq = VkQueue()
    pq = VkQueue()
    vkGetDeviceQueue(device, graphics_q, 0, ctypes.byref(gq))
    vkGetDeviceQueue(device, present_q, 0, ctypes.byref(pq))
    return device, gq, pq

# ============================================================
# Swapchain bundle
# ============================================================
class SwapchainBundle:
    def __init__(self):
        self.swapchain = VkSwapchainKHR(0)
        self.format = 0
        self.extent = VkExtent2D(0, 0)
        self.image_count = 0
        self.images = None      # (VkImage * N)
        self.views = None       # (VkImageView * N)
        self.render_pass = VkRenderPass(0)
        self.pipeline_layout = VkPipelineLayout(0)
        self.pipeline = VkPipeline(0)
        self.framebuffers = None  # (VkFramebuffer * N)
        self.command_pool = VkCommandPool()
        self.command_buffers = None  # (VkCommandBuffer * N)

def query_swapchain_support(instance: VkInstance, pd: VkPhysicalDevice, surface: VkSurfaceKHR):
    vkGetPhysicalDeviceSurfaceCapabilitiesKHR = _get_inst(instance, b"vkGetPhysicalDeviceSurfaceCapabilitiesKHR", VkResult, (VkPhysicalDevice, VkSurfaceKHR, ctypes.POINTER(VkSurfaceCapabilitiesKHR)))
    vkGetPhysicalDeviceSurfaceFormatsKHR      = _get_inst(instance, b"vkGetPhysicalDeviceSurfaceFormatsKHR", VkResult, (VkPhysicalDevice, VkSurfaceKHR, ctypes.POINTER(ctypes.c_uint32), ctypes.POINTER(VkSurfaceFormatKHR)))
    vkGetPhysicalDeviceSurfacePresentModesKHR = _get_inst(instance, b"vkGetPhysicalDeviceSurfacePresentModesKHR", VkResult, (VkPhysicalDevice, VkSurfaceKHR, ctypes.POINTER(ctypes.c_uint32), ctypes.POINTER(ctypes.c_uint32)))

    caps = VkSurfaceCapabilitiesKHR()
    vk_check(vkGetPhysicalDeviceSurfaceCapabilitiesKHR(pd, surface, ctypes.byref(caps)), "vkGetPhysicalDeviceSurfaceCapabilitiesKHR")

    fmt_count = ctypes.c_uint32(0)
    vk_check(vkGetPhysicalDeviceSurfaceFormatsKHR(pd, surface, ctypes.byref(fmt_count), None), "vkGetPhysicalDeviceSurfaceFormatsKHR(count)")
    fmts = (VkSurfaceFormatKHR * fmt_count.value)()
    vk_check(vkGetPhysicalDeviceSurfaceFormatsKHR(pd, surface, ctypes.byref(fmt_count), fmts), "vkGetPhysicalDeviceSurfaceFormatsKHR(list)")

    pm_count = ctypes.c_uint32(0)
    vk_check(vkGetPhysicalDeviceSurfacePresentModesKHR(pd, surface, ctypes.byref(pm_count), None), "vkGetPhysicalDeviceSurfacePresentModesKHR(count)")
    pms = (ctypes.c_uint32 * pm_count.value)()
    vk_check(vkGetPhysicalDeviceSurfacePresentModesKHR(pd, surface, ctypes.byref(pm_count), pms), "vkGetPhysicalDeviceSurfacePresentModesKHR(list)")
    return caps, fmts, pms

def choose_surface_format(fmts) -> VkSurfaceFormatKHR:
    # Prefer VK_FORMAT_B8G8R8A8_UNORM (44) if present
    for i in range(len(fmts)):
        if fmts[i].format == 44:
            return fmts[i]
    return fmts[0]

def choose_present_mode(_pms) -> int:
    return VK_PRESENT_MODE_FIFO_KHR

def choose_extent(hwnd, caps: VkSurfaceCapabilitiesKHR) -> VkExtent2D:
    if caps.currentExtent.width != 0xFFFFFFFF and caps.currentExtent.height != 0xFFFFFFFF:
        return caps.currentExtent
    w, h = _get_client_size(hwnd)
    w = max(int(caps.minImageExtent.width), min(w, int(caps.maxImageExtent.width)))
    h = max(int(caps.minImageExtent.height), min(h, int(caps.maxImageExtent.height)))
    return VkExtent2D(w, h)

def _make_shader_module(device: VkDevice, spv: bytes) -> VkShaderModule:
    if (len(spv) % 4) != 0:
        raise RuntimeError("SPIR-V size must be multiple of 4")
    u32_count = len(spv) // 4
    buf = (ctypes.c_uint32 * u32_count).from_buffer_copy(spv)
    smci = VkShaderModuleCreateInfo(
        sType=VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO,
        pNext=None,
        flags=0,
        codeSize=len(spv),
        pCode=ctypes.cast(buf, ctypes.POINTER(ctypes.c_uint32)),
    )
    vkCreateShaderModule = _get_dev(device, b"vkCreateShaderModule", VkResult, (VkDevice, ctypes.POINTER(VkShaderModuleCreateInfo), ctypes.c_void_p, ctypes.POINTER(VkShaderModule)))
    mod = VkShaderModule(0)
    vk_check(vkCreateShaderModule(device, ctypes.byref(smci), None, ctypes.byref(mod)), "vkCreateShaderModule")
    return mod

def record_all_command_buffers(device: VkDevice, bundle: SwapchainBundle) -> None:
    vkBeginCommandBuffer   = _get_dev(device, b"vkBeginCommandBuffer", VkResult, (VkCommandBuffer, ctypes.POINTER(VkCommandBufferBeginInfo)))
    vkEndCommandBuffer     = _get_dev(device, b"vkEndCommandBuffer", VkResult, (VkCommandBuffer,))
    vkCmdBeginRenderPass   = _get_dev(device, b"vkCmdBeginRenderPass", None, (VkCommandBuffer, ctypes.POINTER(VkRenderPassBeginInfo), ctypes.c_uint32))
    vkCmdEndRenderPass     = _get_dev(device, b"vkCmdEndRenderPass", None, (VkCommandBuffer,))
    vkCmdBindPipeline      = _get_dev(device, b"vkCmdBindPipeline", None, (VkCommandBuffer, ctypes.c_uint32, VkPipeline))
    vkCmdDraw              = _get_dev(device, b"vkCmdDraw", None, (VkCommandBuffer, ctypes.c_uint32, ctypes.c_uint32, ctypes.c_uint32, ctypes.c_uint32))
    vkCmdSetViewport       = _get_dev(device, b"vkCmdSetViewport", None, (VkCommandBuffer, ctypes.c_uint32, ctypes.c_uint32, ctypes.POINTER(VkViewport)))
    vkCmdSetScissor        = _get_dev(device, b"vkCmdSetScissor", None, (VkCommandBuffer, ctypes.c_uint32, ctypes.c_uint32, ctypes.POINTER(VkRect2D)))

    clear = VkClearValue()
    clear.color = VkClearColorValue((ctypes.c_float * 4)(0.05, 0.05, 0.10, 1.0))  # slightly bluish dark

    for i in range(bundle.image_count):
        cmd = bundle.command_buffers[i]

        bi = VkCommandBufferBeginInfo(
            sType=VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
            pNext=None,
            flags=0,
            pInheritanceInfo=None,
        )
        vk_check(vkBeginCommandBuffer(cmd, ctypes.byref(bi)), "vkBeginCommandBuffer")

        vp = VkViewport(0.0, 0.0, float(bundle.extent.width), float(bundle.extent.height), 0.0, 1.0)
        sc = VkRect2D(VkOffset2D(0, 0), bundle.extent)

        rpbi = VkRenderPassBeginInfo(
            sType=VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO,
            pNext=None,
            renderPass=bundle.render_pass,
            framebuffer=bundle.framebuffers[i],
            renderArea=VkRect2D(VkOffset2D(0, 0), bundle.extent),
            clearValueCount=1,
            pClearValues=ctypes.pointer(clear),
        )

        vkCmdBeginRenderPass(cmd, ctypes.byref(rpbi), 0)
        vkCmdBindPipeline(cmd, VK_PIPELINE_BIND_POINT_GRAPHICS, bundle.pipeline)
        vkCmdSetViewport(cmd, 0, 1, ctypes.byref(vp))
        vkCmdSetScissor(cmd, 0, 1, ctypes.byref(sc))
        vkCmdDraw(cmd, 3, 1, 0, 0)
        vkCmdEndRenderPass(cmd)

        vk_check(vkEndCommandBuffer(cmd), "vkEndCommandBuffer")

    log("Command buffers recorded")

def create_swapchain_bundle(instance: VkInstance, device: VkDevice, pd: VkPhysicalDevice, surface: VkSurfaceKHR,
                           hwnd, graphics_q: int, present_q: int, vert_spv: bytes, frag_spv: bytes) -> SwapchainBundle:
    bundle = SwapchainBundle()

    vkCreateSwapchainKHR    = _get_dev(device, b"vkCreateSwapchainKHR", VkResult, (VkDevice, ctypes.POINTER(VkSwapchainCreateInfoKHR), ctypes.c_void_p, ctypes.POINTER(VkSwapchainKHR)))
    vkGetSwapchainImagesKHR = _get_dev(device, b"vkGetSwapchainImagesKHR", VkResult, (VkDevice, VkSwapchainKHR, ctypes.POINTER(ctypes.c_uint32), ctypes.POINTER(VkImage)))
    vkCreateImageView       = _get_dev(device, b"vkCreateImageView", VkResult, (VkDevice, ctypes.POINTER(VkImageViewCreateInfo), ctypes.c_void_p, ctypes.POINTER(VkImageView)))
    vkCreateRenderPass      = _get_dev(device, b"vkCreateRenderPass", VkResult, (VkDevice, ctypes.POINTER(VkRenderPassCreateInfo), ctypes.c_void_p, ctypes.POINTER(VkRenderPass)))
    vkCreatePipelineLayout  = _get_dev(device, b"vkCreatePipelineLayout", VkResult, (VkDevice, ctypes.POINTER(VkPipelineLayoutCreateInfo), ctypes.c_void_p, ctypes.POINTER(VkPipelineLayout)))
    vkCreateGraphicsPipelines = _get_dev(device, b"vkCreateGraphicsPipelines", VkResult, (VkDevice, ctypes.c_uint64, ctypes.c_uint32, ctypes.POINTER(VkGraphicsPipelineCreateInfo), ctypes.c_void_p, ctypes.POINTER(VkPipeline)))
    vkCreateFramebuffer     = _get_dev(device, b"vkCreateFramebuffer", VkResult, (VkDevice, ctypes.POINTER(VkFramebufferCreateInfo), ctypes.c_void_p, ctypes.POINTER(VkFramebuffer)))
    vkCreateCommandPool     = _get_dev(device, b"vkCreateCommandPool", VkResult, (VkDevice, ctypes.POINTER(VkCommandPoolCreateInfo), ctypes.c_void_p, ctypes.POINTER(VkCommandPool)))
    vkAllocateCommandBuffers = _get_dev(device, b"vkAllocateCommandBuffers", VkResult, (VkDevice, ctypes.POINTER(VkCommandBufferAllocateInfo), ctypes.POINTER(VkCommandBuffer)))
    vkDestroyShaderModule   = _get_dev(device, b"vkDestroyShaderModule", None, (VkDevice, VkShaderModule, ctypes.c_void_p))

    caps, fmts, pms = query_swapchain_support(instance, pd, surface)
    sfmt = choose_surface_format(fmts)
    pmode = choose_present_mode(pms)
    extent = choose_extent(hwnd, caps)

    image_count = caps.minImageCount + 1
    if caps.maxImageCount != 0 and image_count > caps.maxImageCount:
        image_count = caps.maxImageCount

    q_indices = (ctypes.c_uint32 * 2)(graphics_q, present_q)
    if graphics_q != present_q:
        sharing_mode = VK_SHARING_MODE_CONCURRENT
        q_count = 2
        q_ptr = ctypes.cast(q_indices, ctypes.POINTER(ctypes.c_uint32))
    else:
        sharing_mode = VK_SHARING_MODE_EXCLUSIVE
        q_count = 0
        q_ptr = None

    sci = VkSwapchainCreateInfoKHR(
        sType=VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR,
        pNext=None,
        flags=0,
        surface=surface,
        minImageCount=image_count,
        imageFormat=sfmt.format,
        imageColorSpace=sfmt.colorSpace,
        imageExtent=extent,
        imageArrayLayers=1,
        imageUsage=VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT,
        imageSharingMode=sharing_mode,
        queueFamilyIndexCount=q_count,
        pQueueFamilyIndices=q_ptr,
        preTransform=caps.currentTransform if (caps.supportedTransforms & caps.currentTransform) else VK_SURFACE_TRANSFORM_IDENTITY_BIT_KHR,
        compositeAlpha=VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR,
        presentMode=pmode,
        clipped=1,
        oldSwapchain=VkSwapchainKHR(0),
    )

    sc = VkSwapchainKHR(0)
    vk_check(vkCreateSwapchainKHR(device, ctypes.byref(sci), None, ctypes.byref(sc)), "vkCreateSwapchainKHR")

    ic = ctypes.c_uint32(0)
    vk_check(vkGetSwapchainImagesKHR(device, sc, ctypes.byref(ic), None), "vkGetSwapchainImagesKHR(count)")
    images = (VkImage * ic.value)()
    vk_check(vkGetSwapchainImagesKHR(device, sc, ctypes.byref(ic), images), "vkGetSwapchainImagesKHR(list)")

    bundle.swapchain = sc
    bundle.format = sfmt.format
    bundle.extent = extent
    bundle.images = images
    bundle.image_count = ic.value

    log(f"Swapchain created: {hx(sc)} format={bundle.format} extent={extent.width}x{extent.height} images={bundle.image_count}")

    views = (VkImageView * bundle.image_count)()
    for i in range(bundle.image_count):
        ivci = VkImageViewCreateInfo(
            sType=VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO,
            pNext=None,
            flags=0,
            image=images[i],
            viewType=VK_IMAGE_VIEW_TYPE_2D,
            format=bundle.format,
            components=VkComponentMapping(0, 0, 0, 0),
            subresourceRange=VkImageSubresourceRange(VK_IMAGE_ASPECT_COLOR_BIT, 0, 1, 0, 1),
        )
        out = VkImageView(0)
        vk_check(vkCreateImageView(device, ctypes.byref(ivci), None, ctypes.byref(out)), "vkCreateImageView")
        views[i] = out
    bundle.views = views
    log(f"Created {bundle.image_count} swapchain image views")

    color_attachment = VkAttachmentDescription(
        flags=0,
        format=bundle.format,
        samples=VK_SAMPLE_COUNT_1_BIT,
        loadOp=VK_ATTACHMENT_LOAD_OP_CLEAR,
        storeOp=VK_ATTACHMENT_STORE_OP_STORE,
        stencilLoadOp=0,
        stencilStoreOp=0,
        initialLayout=VK_IMAGE_LAYOUT_UNDEFINED,
        finalLayout=VK_IMAGE_LAYOUT_PRESENT_SRC_KHR,
    )
    color_ref = VkAttachmentReference(attachment=0, layout=VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL)
    subpass = VkSubpassDescription(
        flags=0,
        pipelineBindPoint=VK_PIPELINE_BIND_POINT_GRAPHICS,
        inputAttachmentCount=0,
        pInputAttachments=None,
        colorAttachmentCount=1,
        pColorAttachments=ctypes.pointer(color_ref),
        pResolveAttachments=None,
        pDepthStencilAttachment=None,
        preserveAttachmentCount=0,
        pPreserveAttachments=None,
    )
    rpci = VkRenderPassCreateInfo(
        sType=VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO,
        pNext=None,
        flags=0,
        attachmentCount=1,
        pAttachments=ctypes.pointer(color_attachment),
        subpassCount=1,
        pSubpasses=ctypes.pointer(subpass),
        dependencyCount=0,
        pDependencies=None,
    )
    rp = VkRenderPass(0)
    vk_check(vkCreateRenderPass(device, ctypes.byref(rpci), None, ctypes.byref(rp)), "vkCreateRenderPass")
    bundle.render_pass = rp
    log(f"RenderPass created: {hx(rp)}")

    vert_mod = _make_shader_module(device, vert_spv)
    frag_mod = _make_shader_module(device, frag_spv)
    log(f"Shader modules: vert={hx(vert_mod)} frag={hx(frag_mod)}")

    plci = VkPipelineLayoutCreateInfo(
        sType=VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO,
        pNext=None,
        flags=0,
        setLayoutCount=0,
        pSetLayouts=None,
        pushConstantRangeCount=0,
        pPushConstantRanges=None,
    )
    pl = VkPipelineLayout(0)
    vk_check(vkCreatePipelineLayout(device, ctypes.byref(plci), None, ctypes.byref(pl)), "vkCreatePipelineLayout")
    bundle.pipeline_layout = pl

    stages = (VkPipelineShaderStageCreateInfo * 2)()
    stages[0] = VkPipelineShaderStageCreateInfo(
        sType=VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
        pNext=None,
        flags=0,
        stage=VK_SHADER_STAGE_VERTEX_BIT,
        module=vert_mod,
        pName=b"main",
        pSpecializationInfo=None,
    )
    stages[1] = VkPipelineShaderStageCreateInfo(
        sType=VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
        pNext=None,
        flags=0,
        stage=VK_SHADER_STAGE_FRAGMENT_BIT,
        module=frag_mod,
        pName=b"main",
        pSpecializationInfo=None,
    )

    vin = VkPipelineVertexInputStateCreateInfo(
        sType=VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO,
        pNext=None,
        flags=0,
        vertexBindingDescriptionCount=0,
        pVertexBindingDescriptions=None,
        vertexAttributeDescriptionCount=0,
        pVertexAttributeDescriptions=None,
    )
    ia = VkPipelineInputAssemblyStateCreateInfo(
        sType=VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO,
        pNext=None,
        flags=0,
        topology=VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST,
        primitiveRestartEnable=0,
    )

    dummy_vp = VkViewport(0.0, 0.0, float(extent.width), float(extent.height), 0.0, 1.0)
    dummy_sc = VkRect2D(VkOffset2D(0, 0), extent)
    vp_state = VkPipelineViewportStateCreateInfo(
        sType=VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO,
        pNext=None,
        flags=0,
        viewportCount=1,
        pViewports=ctypes.pointer(dummy_vp),
        scissorCount=1,
        pScissors=ctypes.pointer(dummy_sc),
    )

    rs = VkPipelineRasterizationStateCreateInfo(
        sType=VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO,
        pNext=None,
        flags=0,
        depthClampEnable=0,
        rasterizerDiscardEnable=0,
        polygonMode=VK_POLYGON_MODE_FILL,
        cullMode=VK_CULL_MODE_NONE,  # <-- FIX
        frontFace=VK_FRONT_FACE_COUNTER_CLOCKWISE,
        depthBiasEnable=0,
        depthBiasConstantFactor=0.0,
        depthBiasClamp=0.0,
        depthBiasSlopeFactor=0.0,
        lineWidth=1.0,
    )

    ms = VkPipelineMultisampleStateCreateInfo(
        sType=VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO,
        pNext=None,
        flags=0,
        rasterizationSamples=VK_SAMPLE_COUNT_1_BIT,
        sampleShadingEnable=0,
        minSampleShading=1.0,
        pSampleMask=None,
        alphaToCoverageEnable=0,
        alphaToOneEnable=0,
    )

    cb_attach = VkPipelineColorBlendAttachmentState(
        blendEnable=0,
        srcColorBlendFactor=0,
        dstColorBlendFactor=0,
        colorBlendOp=0,
        srcAlphaBlendFactor=0,
        dstAlphaBlendFactor=0,
        alphaBlendOp=0,
        colorWriteMask=(VK_COLOR_COMPONENT_R_BIT | VK_COLOR_COMPONENT_G_BIT | VK_COLOR_COMPONENT_B_BIT | VK_COLOR_COMPONENT_A_BIT),
    )

    cb = VkPipelineColorBlendStateCreateInfo(
        sType=VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO,
        pNext=None,
        flags=0,
        logicOpEnable=0,
        logicOp=0,
        attachmentCount=1,
        pAttachments=ctypes.pointer(cb_attach),
        blendConstants=(ctypes.c_float * 4)(0.0, 0.0, 0.0, 0.0),
    )

    dyn_states = (ctypes.c_uint32 * 2)(VK_DYNAMIC_STATE_VIEWPORT, VK_DYNAMIC_STATE_SCISSOR)
    dyn = VkDynamicStateCreateInfo(
        sType=VK_STRUCTURE_TYPE_PIPELINE_DYNAMIC_STATE_CREATE_INFO,
        pNext=None,
        flags=0,
        dynamicStateCount=2,
        pDynamicStates=ctypes.cast(dyn_states, ctypes.POINTER(ctypes.c_uint32)),
    )

    gpci = VkGraphicsPipelineCreateInfo(
        sType=VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO,
        pNext=None,
        flags=0,
        stageCount=2,
        pStages=ctypes.cast(stages, ctypes.POINTER(VkPipelineShaderStageCreateInfo)),
        pVertexInputState=ctypes.pointer(vin),
        pInputAssemblyState=ctypes.pointer(ia),
        pTessellationState=None,
        pViewportState=ctypes.pointer(vp_state),
        pRasterizationState=ctypes.pointer(rs),
        pMultisampleState=ctypes.pointer(ms),
        pDepthStencilState=None,
        pColorBlendState=ctypes.pointer(cb),
        pDynamicState=ctypes.pointer(dyn),
        layout=pl,
        renderPass=rp,
        subpass=0,
        basePipelineHandle=VkPipeline(0),
        basePipelineIndex=-1,
    )

    pipeline = VkPipeline(0)
    vk_check(vkCreateGraphicsPipelines(device, 0, 1, ctypes.byref(gpci), None, ctypes.byref(pipeline)), "vkCreateGraphicsPipelines")
    bundle.pipeline = pipeline
    log(f"Pipeline created: {hx(pipeline)}")

    vkDestroyShaderModule(device, vert_mod, None)
    vkDestroyShaderModule(device, frag_mod, None)

    fbs = (VkFramebuffer * bundle.image_count)()
    for i in range(bundle.image_count):
        attachments = (VkImageView * 1)(views[i])
        fbci = VkFramebufferCreateInfo(
            sType=VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO,
            pNext=None,
            flags=0,
            renderPass=rp,
            attachmentCount=1,
            pAttachments=ctypes.cast(attachments, ctypes.POINTER(VkImageView)),
            width=extent.width,
            height=extent.height,
            layers=1,
        )
        out = VkFramebuffer(0)
        vk_check(vkCreateFramebuffer(device, ctypes.byref(fbci), None, ctypes.byref(out)), "vkCreateFramebuffer")
        fbs[i] = out
    bundle.framebuffers = fbs
    log(f"Created {bundle.image_count} framebuffers")

    cpci = VkCommandPoolCreateInfo(
        sType=VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO,
        pNext=None,
        flags=VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT,
        queueFamilyIndex=graphics_q,
    )
    cp = VkCommandPool()
    vk_check(vkCreateCommandPool(device, ctypes.byref(cpci), None, ctypes.byref(cp)), "vkCreateCommandPool")
    bundle.command_pool = cp
    log(f"CommandPool: {hx(cp)}")

    cbi = VkCommandBufferAllocateInfo(
        sType=VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
        pNext=None,
        commandPool=cp,
        level=VK_COMMAND_BUFFER_LEVEL_PRIMARY,
        commandBufferCount=bundle.image_count,
    )
    cbs = (VkCommandBuffer * bundle.image_count)()
    vk_check(vkAllocateCommandBuffers(device, ctypes.byref(cbi), cbs), "vkAllocateCommandBuffers")
    bundle.command_buffers = cbs
    log(f"Allocated {bundle.image_count} command buffers")

    record_all_command_buffers(device, bundle)
    return bundle

def destroy_swapchain_bundle(device: VkDevice, bundle: SwapchainBundle) -> None:
    vkDestroyCommandPool   = _get_dev(device, b"vkDestroyCommandPool", None, (VkDevice, VkCommandPool, ctypes.c_void_p))
    vkDestroyFramebuffer   = _get_dev(device, b"vkDestroyFramebuffer", None, (VkDevice, VkFramebuffer, ctypes.c_void_p))
    vkDestroyPipeline      = _get_dev(device, b"vkDestroyPipeline", None, (VkDevice, VkPipeline, ctypes.c_void_p))
    vkDestroyPipelineLayout= _get_dev(device, b"vkDestroyPipelineLayout", None, (VkDevice, VkPipelineLayout, ctypes.c_void_p))
    vkDestroyRenderPass    = _get_dev(device, b"vkDestroyRenderPass", None, (VkDevice, VkRenderPass, ctypes.c_void_p))
    vkDestroyImageView     = _get_dev(device, b"vkDestroyImageView", None, (VkDevice, VkImageView, ctypes.c_void_p))
    vkDestroySwapchainKHR  = _get_dev(device, b"vkDestroySwapchainKHR", None, (VkDevice, VkSwapchainKHR, ctypes.c_void_p))

    if bundle.command_pool and bundle.command_pool.value:
        vkDestroyCommandPool(device, bundle.command_pool, None)
    if bundle.framebuffers is not None:
        for i in range(bundle.image_count):
            if bundle.framebuffers[i]:
                vkDestroyFramebuffer(device, bundle.framebuffers[i], None)
    if bundle.pipeline.value:
        vkDestroyPipeline(device, bundle.pipeline, None)
    if bundle.pipeline_layout.value:
        vkDestroyPipelineLayout(device, bundle.pipeline_layout, None)
    if bundle.render_pass.value:
        vkDestroyRenderPass(device, bundle.render_pass, None)
    if bundle.views is not None:
        for i in range(bundle.image_count):
            if bundle.views[i]:
                vkDestroyImageView(device, bundle.views[i], None)
    if bundle.swapchain.value:
        vkDestroySwapchainKHR(device, bundle.swapchain, None)

def destroy_device_and_instance(instance: VkInstance, device: VkDevice, surface: VkSurfaceKHR) -> None:
    vkDestroyDevice = _get_global(b"vkDestroyDevice", None, (VkDevice, ctypes.c_void_p))
    vkDestroySurfaceKHR = _get_inst(instance, b"vkDestroySurfaceKHR", None, (VkInstance, VkSurfaceKHR, ctypes.c_void_p))

    if device and device.value:
        vkDestroyDevice(device, None)
    if surface.value:
        vkDestroySurfaceKHR(instance, surface, None)
    if instance and instance.value:
        vkDestroyInstance(instance, None)

# ============================================================
# Sync objects
# ============================================================
class SyncObjects:
    def __init__(self, max_frames: int):
        self.max_frames = max_frames
        self.image_available = (VkSemaphore * max_frames)()
        self.render_finished = (VkSemaphore * max_frames)()
        self.in_flight       = (VkFence * max_frames)()

def create_sync_objects(device: VkDevice, max_frames: int) -> SyncObjects:
    vkCreateSemaphore = _get_dev(device, b"vkCreateSemaphore", VkResult, (VkDevice, ctypes.POINTER(VkSemaphoreCreateInfo), ctypes.c_void_p, ctypes.POINTER(VkSemaphore)))
    vkCreateFence     = _get_dev(device, b"vkCreateFence", VkResult, (VkDevice, ctypes.POINTER(VkFenceCreateInfo), ctypes.c_void_p, ctypes.POINTER(VkFence)))

    sync = SyncObjects(max_frames)
    sci = VkSemaphoreCreateInfo(sType=VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO, pNext=None, flags=0)
    fci = VkFenceCreateInfo(sType=VK_STRUCTURE_TYPE_FENCE_CREATE_INFO, pNext=None, flags=VK_FENCE_CREATE_SIGNALED_BIT)

    for i in range(max_frames):
        sem1 = VkSemaphore(0)
        vk_check(vkCreateSemaphore(device, ctypes.byref(sci), None, ctypes.byref(sem1)), "vkCreateSemaphore")
        sync.image_available[i] = sem1

        sem2 = VkSemaphore(0)
        vk_check(vkCreateSemaphore(device, ctypes.byref(sci), None, ctypes.byref(sem2)), "vkCreateSemaphore")
        sync.render_finished[i] = sem2

        fnc = VkFence(0)
        vk_check(vkCreateFence(device, ctypes.byref(fci), None, ctypes.byref(fnc)), "vkCreateFence")
        sync.in_flight[i] = fnc

    log("Sync objects created")
    return sync

def recreate_swapchain(instance: VkInstance, device: VkDevice, pd: VkPhysicalDevice, surface: VkSurfaceKHR,
                       hwnd, graphics_q: int, present_q: int, vert_spv: bytes, frag_spv: bytes, old: SwapchainBundle) -> SwapchainBundle:
    log("Recreating swapchain...")
    vkDeviceWaitIdle = _get_dev(device, b"vkDeviceWaitIdle", VkResult, (VkDevice,))
    vk_check(vkDeviceWaitIdle(device), "vkDeviceWaitIdle")
    destroy_swapchain_bundle(device, old)
    return create_swapchain_bundle(instance, device, pd, surface, hwnd, graphics_q, present_q, vert_spv, frag_spv)

# ============================================================
# Vulkan offscreen -> D3D11 -> Windows.UI.Composition bridge
# ============================================================
class DXGI_SAMPLE_DESC_LOCAL(ctypes.Structure):
    _fields_ = [("Count", ctypes.c_uint32), ("Quality", ctypes.c_uint32)]

class D3D11_TEXTURE2D_DESC(ctypes.Structure):
    _fields_ = [
        ("Width", ctypes.c_uint32),
        ("Height", ctypes.c_uint32),
        ("MipLevels", ctypes.c_uint32),
        ("ArraySize", ctypes.c_uint32),
        ("Format", ctypes.c_uint32),
        ("SampleDesc", DXGI_SAMPLE_DESC_LOCAL),
        ("Usage", ctypes.c_uint32),
        ("BindFlags", ctypes.c_uint32),
        ("CPUAccessFlags", ctypes.c_uint32),
        ("MiscFlags", ctypes.c_uint32),
    ]

class D3D11_MAPPED_SUBRESOURCE(ctypes.Structure):
    _fields_ = [("pData", ctypes.c_void_p), ("RowPitch", ctypes.c_uint32), ("DepthPitch", ctypes.c_uint32)]

D3D11_USAGE_STAGING = 3
D3D11_CPU_ACCESS_WRITE = 0x00010000
D3D11_MAP_WRITE = 2

g_bridge_helper = None
g_bridge_staging_tex = ctypes.c_void_p()

class VkOffscreenState:
    def __init__(self):
        self.instance = VkInstance()
        self.pd = VkPhysicalDevice()
        self.device = VkDevice()
        self.queue_family = 0
        self.queue = VkQueue()
        self.width = WIDTH
        self.height = HEIGHT
        self.off_image = VkImage(0)
        self.off_memory = VkDeviceMemory(0)
        self.off_view = VkImageView(0)
        self.readback_buf = VkBuffer(0)
        self.readback_mem = VkDeviceMemory(0)
        self.render_pass = VkRenderPass(0)
        self.framebuffer = VkFramebuffer(0)
        self.pipeline_layout = VkPipelineLayout(0)
        self.pipeline = VkPipeline(0)
        self.cmd_pool = VkCommandPool()
        self.cmd_buf = VkCommandBuffer()
        self.fence = VkFence(0)

def _require_hr(hr: int, what: str) -> None:
    if hr < 0:
        raise RuntimeError(f"{what} failed: 0x{hr & 0xFFFFFFFF:08X}")

def _find_memory_type(pd: VkPhysicalDevice, type_bits: int, required_flags: int) -> int:
    vkGetPhysicalDeviceMemoryProperties = _get_global(
        b"vkGetPhysicalDeviceMemoryProperties",
        None,
        (VkPhysicalDevice, ctypes.POINTER(VkPhysicalDeviceMemoryProperties)),
    )
    props = VkPhysicalDeviceMemoryProperties()
    vkGetPhysicalDeviceMemoryProperties(pd, ctypes.byref(props))
    for i in range(int(props.memoryTypeCount)):
        if (type_bits & (1 << i)) and ((props.memoryTypes[i].propertyFlags & required_flags) == required_flags):
            return i
    raise RuntimeError("No suitable Vulkan memory type")

def _pick_physical_device_offscreen(instance: VkInstance) -> tuple[VkPhysicalDevice, int]:
    count = ctypes.c_uint32(0)
    vk_check(vkEnumeratePhysicalDevices(instance, ctypes.byref(count), None), "vkEnumeratePhysicalDevices(count)")
    if count.value == 0:
        raise RuntimeError("No Vulkan physical devices found")
    devs = (VkPhysicalDevice * count.value)()
    vk_check(vkEnumeratePhysicalDevices(instance, ctypes.byref(count), devs), "vkEnumeratePhysicalDevices(list)")
    for i in range(count.value):
        pd = devs[i]
        qcount = ctypes.c_uint32(0)
        vkGetPhysicalDeviceQueueFamilyProperties(pd, ctypes.byref(qcount), None)
        props = (VkQueueFamilyProperties * qcount.value)()
        vkGetPhysicalDeviceQueueFamilyProperties(pd, ctypes.byref(qcount), props)
        for qi in range(qcount.value):
            if (props[qi].queueFlags & VK_QUEUE_GRAPHICS_BIT) != 0:
                return pd, qi
    raise RuntimeError("No Vulkan graphics queue family found")

def _create_device_offscreen(pd: VkPhysicalDevice, graphics_q: int) -> tuple[VkDevice, VkQueue]:
    priorities = (ctypes.c_float * 1)(1.0)
    qci = VkDeviceQueueCreateInfo(
        sType=VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
        pNext=None,
        flags=0,
        queueFamilyIndex=graphics_q,
        queueCount=1,
        pQueuePriorities=priorities,
    )
    dci = VkDeviceCreateInfo(
        sType=VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO,
        pNext=None,
        flags=0,
        queueCreateInfoCount=1,
        pQueueCreateInfos=ctypes.pointer(qci),
        enabledLayerCount=0,
        ppEnabledLayerNames=None,
        enabledExtensionCount=0,
        ppEnabledExtensionNames=None,
        pEnabledFeatures=None,
    )
    device = VkDevice()
    vk_check(vkCreateDevice(pd, ctypes.byref(dci), None, ctypes.byref(device)), "vkCreateDevice")
    vkGetDeviceQueue = _get_dev(device, b"vkGetDeviceQueue", None, (VkDevice, ctypes.c_uint32, ctypes.c_uint32, ctypes.POINTER(VkQueue)))
    queue = VkQueue()
    vkGetDeviceQueue(device, graphics_q, 0, ctypes.byref(queue))
    return device, queue

def _init_composition_bridge(hwnd, width: int, height: int) -> None:
    global g_bridge_helper, g_bridge_staging_tex
    helper = load_d3d11_composition_helper()
    g_bridge_helper = helper
    helper.WIDTH = width
    helper.HEIGHT = height
    helper.g_hwnd = hwnd
    helper.init_d3d()
    helper.init_composition()

    desc = D3D11_TEXTURE2D_DESC()
    desc.Width = width
    desc.Height = height
    desc.MipLevels = 1
    desc.ArraySize = 1
    desc.Format = helper.DXGI_FORMAT_B8G8R8A8_UNORM
    desc.SampleDesc = DXGI_SAMPLE_DESC_LOCAL(1, 0)
    desc.Usage = D3D11_USAGE_STAGING
    desc.BindFlags = 0
    desc.CPUAccessFlags = D3D11_CPU_ACCESS_WRITE
    desc.MiscFlags = 0

    fn = helper.com_method(helper.g_device, 5, wintypes.HRESULT,
                           (ctypes.c_void_p, ctypes.POINTER(D3D11_TEXTURE2D_DESC),
                            ctypes.c_void_p, ctypes.POINTER(ctypes.c_void_p)))
    hr = fn(helper.g_device.value, ctypes.byref(desc), None, ctypes.byref(g_bridge_staging_tex))
    _require_hr(hr, "ID3D11Device::CreateTexture2D(staging)")

def _copy_vulkan_pixels_to_composition(src_ptr: ctypes.c_void_p, width: int, height: int) -> None:
    helper = g_bridge_helper
    if helper is None:
        return

    backbuf = ctypes.c_void_p()
    fn = helper.com_method(helper.g_swap, 9, wintypes.HRESULT,
                           (ctypes.c_void_p, ctypes.c_uint, ctypes.POINTER(helper.GUID),
                            ctypes.POINTER(ctypes.c_void_p)))
    hr = fn(helper.g_swap.value, 0, ctypes.byref(helper.IID_ID3D11Texture2D), ctypes.byref(backbuf))
    _require_hr(hr, "IDXGISwapChain::GetBuffer")

    mapped = D3D11_MAPPED_SUBRESOURCE()
    map_fn = helper.com_method(helper.g_context, 14, wintypes.HRESULT,
                               (ctypes.c_void_p, ctypes.c_void_p, ctypes.c_uint, ctypes.c_uint, ctypes.c_uint,
                                ctypes.POINTER(D3D11_MAPPED_SUBRESOURCE)))
    hr = map_fn(helper.g_context.value, g_bridge_staging_tex.value, 0, D3D11_MAP_WRITE, 0, ctypes.byref(mapped))
    if hr >= 0:
        src_pitch = width * 4
        for y in range(height):
            ctypes.memmove(mapped.pData + y * mapped.RowPitch, src_ptr.value + y * src_pitch, src_pitch)
        unmap_fn = helper.com_method(helper.g_context, 15, None, (ctypes.c_void_p, ctypes.c_void_p, ctypes.c_uint))
        unmap_fn(helper.g_context.value, g_bridge_staging_tex.value, 0)
        copy_fn = helper.com_method(helper.g_context, 47, None, (ctypes.c_void_p, ctypes.c_void_p, ctypes.c_void_p))
        copy_fn(helper.g_context.value, backbuf.value, g_bridge_staging_tex.value)

    helper.com_release(backbuf)
    present_fn = helper.com_method(helper.g_swap, 8, wintypes.HRESULT, (ctypes.c_void_p, ctypes.c_uint, ctypes.c_uint))
    present_fn(helper.g_swap.value, 1, 0)

def _cleanup_composition_bridge() -> None:
    global g_bridge_staging_tex
    if g_bridge_helper is not None:
        if g_bridge_staging_tex and g_bridge_staging_tex.value:
            g_bridge_helper.com_release(g_bridge_staging_tex)
            g_bridge_staging_tex = ctypes.c_void_p()
        g_bridge_helper.cleanup()

def _create_instance_offscreen() -> VkInstance:
    api_1_4 = (1 << 22) | (4 << 12) | 0
    app = VkApplicationInfo(
        sType=VK_STRUCTURE_TYPE_APPLICATION_INFO,
        pNext=None,
        pApplicationName=b"PyVulkanCompTriangle",
        applicationVersion=1,
        pEngineName=b"NoEngine",
        engineVersion=1,
        apiVersion=api_1_4,
    )
    ici = VkInstanceCreateInfo(
        sType=VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
        pNext=None,
        flags=0,
        pApplicationInfo=ctypes.pointer(app),
        enabledLayerCount=0,
        ppEnabledLayerNames=None,
        enabledExtensionCount=0,
        ppEnabledExtensionNames=None,
    )
    inst = VkInstance()
    vk_check(vkCreateInstance(ctypes.byref(ici), None, ctypes.byref(inst)), "vkCreateInstance")
    return inst

def _init_vulkan_offscreen(vert_spv: bytes, frag_spv: bytes, width: int, height: int) -> VkOffscreenState:
    st = VkOffscreenState()
    st.width = width
    st.height = height
    st.instance = _create_instance_offscreen()
    st.pd, st.queue_family = _pick_physical_device_offscreen(st.instance)
    st.device, st.queue = _create_device_offscreen(st.pd, st.queue_family)

    vkCreateImage = _get_dev(st.device, b"vkCreateImage", VkResult, (VkDevice, ctypes.POINTER(VkImageCreateInfo), ctypes.c_void_p, ctypes.POINTER(VkImage)))
    vkGetImageMemoryRequirements = _get_dev(st.device, b"vkGetImageMemoryRequirements", None, (VkDevice, VkImage, ctypes.POINTER(VkMemoryRequirements)))
    vkAllocateMemory = _get_dev(st.device, b"vkAllocateMemory", VkResult, (VkDevice, ctypes.POINTER(VkMemoryAllocateInfo), ctypes.c_void_p, ctypes.POINTER(VkDeviceMemory)))
    vkBindImageMemory = _get_dev(st.device, b"vkBindImageMemory", VkResult, (VkDevice, VkImage, VkDeviceMemory, VkDeviceSize))
    vkCreateImageView = _get_dev(st.device, b"vkCreateImageView", VkResult, (VkDevice, ctypes.POINTER(VkImageViewCreateInfo), ctypes.c_void_p, ctypes.POINTER(VkImageView)))
    vkCreateBuffer = _get_dev(st.device, b"vkCreateBuffer", VkResult, (VkDevice, ctypes.POINTER(VkBufferCreateInfo), ctypes.c_void_p, ctypes.POINTER(VkBuffer)))
    vkGetBufferMemoryRequirements = _get_dev(st.device, b"vkGetBufferMemoryRequirements", None, (VkDevice, VkBuffer, ctypes.POINTER(VkMemoryRequirements)))
    vkBindBufferMemory = _get_dev(st.device, b"vkBindBufferMemory", VkResult, (VkDevice, VkBuffer, VkDeviceMemory, VkDeviceSize))
    vkCreateRenderPass = _get_dev(st.device, b"vkCreateRenderPass", VkResult, (VkDevice, ctypes.POINTER(VkRenderPassCreateInfo), ctypes.c_void_p, ctypes.POINTER(VkRenderPass)))
    vkCreateFramebuffer = _get_dev(st.device, b"vkCreateFramebuffer", VkResult, (VkDevice, ctypes.POINTER(VkFramebufferCreateInfo), ctypes.c_void_p, ctypes.POINTER(VkFramebuffer)))
    vkCreatePipelineLayout = _get_dev(st.device, b"vkCreatePipelineLayout", VkResult, (VkDevice, ctypes.POINTER(VkPipelineLayoutCreateInfo), ctypes.c_void_p, ctypes.POINTER(VkPipelineLayout)))
    vkCreateGraphicsPipelines = _get_dev(st.device, b"vkCreateGraphicsPipelines", VkResult, (VkDevice, ctypes.c_uint64, ctypes.c_uint32, ctypes.POINTER(VkGraphicsPipelineCreateInfo), ctypes.c_void_p, ctypes.POINTER(VkPipeline)))
    vkCreateCommandPool = _get_dev(st.device, b"vkCreateCommandPool", VkResult, (VkDevice, ctypes.POINTER(VkCommandPoolCreateInfo), ctypes.c_void_p, ctypes.POINTER(VkCommandPool)))
    vkAllocateCommandBuffers = _get_dev(st.device, b"vkAllocateCommandBuffers", VkResult, (VkDevice, ctypes.POINTER(VkCommandBufferAllocateInfo), ctypes.POINTER(VkCommandBuffer)))
    vkCreateFence = _get_dev(st.device, b"vkCreateFence", VkResult, (VkDevice, ctypes.POINTER(VkFenceCreateInfo), ctypes.c_void_p, ctypes.POINTER(VkFence)))
    vkDestroyShaderModule = _get_dev(st.device, b"vkDestroyShaderModule", None, (VkDevice, VkShaderModule, ctypes.c_void_p))

    imgci = VkImageCreateInfo(
        sType=VK_STRUCTURE_TYPE_IMAGE_CREATE_INFO, pNext=None, flags=0,
        imageType=VK_IMAGE_TYPE_2D, format=VK_FORMAT_B8G8R8A8_UNORM,
        extent=VkExtent3D(width, height, 1), mipLevels=1, arrayLayers=1,
        samples=VK_SAMPLE_COUNT_1_BIT, tiling=VK_IMAGE_TILING_OPTIMAL,
        usage=(VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT | VK_IMAGE_USAGE_TRANSFER_SRC_BIT),
        sharingMode=VK_SHARING_MODE_EXCLUSIVE, queueFamilyIndexCount=0,
        pQueueFamilyIndices=None, initialLayout=VK_IMAGE_LAYOUT_UNDEFINED)
    vk_check(vkCreateImage(st.device, ctypes.byref(imgci), None, ctypes.byref(st.off_image)), "vkCreateImage")

    mr = VkMemoryRequirements()
    vkGetImageMemoryRequirements(st.device, st.off_image, ctypes.byref(mr))
    mai = VkMemoryAllocateInfo(VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO, None, mr.size,
                               _find_memory_type(st.pd, mr.memoryTypeBits, VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT))
    vk_check(vkAllocateMemory(st.device, ctypes.byref(mai), None, ctypes.byref(st.off_memory)), "vkAllocateMemory(offscreen)")
    vk_check(vkBindImageMemory(st.device, st.off_image, st.off_memory, 0), "vkBindImageMemory")

    ivci = VkImageViewCreateInfo(
        sType=VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO, pNext=None, flags=0,
        image=st.off_image, viewType=VK_IMAGE_VIEW_TYPE_2D, format=VK_FORMAT_B8G8R8A8_UNORM,
        components=VkComponentMapping(0, 0, 0, 0),
        subresourceRange=VkImageSubresourceRange(VK_IMAGE_ASPECT_COLOR_BIT, 0, 1, 0, 1))
    vk_check(vkCreateImageView(st.device, ctypes.byref(ivci), None, ctypes.byref(st.off_view)), "vkCreateImageView")

    bci = VkBufferCreateInfo(
        sType=VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO, pNext=None, flags=0,
        size=width * height * 4, usage=VK_BUFFER_USAGE_TRANSFER_DST_BIT,
        sharingMode=VK_SHARING_MODE_EXCLUSIVE, queueFamilyIndexCount=0, pQueueFamilyIndices=None)
    vk_check(vkCreateBuffer(st.device, ctypes.byref(bci), None, ctypes.byref(st.readback_buf)), "vkCreateBuffer")
    vkGetBufferMemoryRequirements(st.device, st.readback_buf, ctypes.byref(mr))
    mai = VkMemoryAllocateInfo(
        VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO, None, mr.size,
        _find_memory_type(st.pd, mr.memoryTypeBits, VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | VK_MEMORY_PROPERTY_HOST_COHERENT_BIT))
    vk_check(vkAllocateMemory(st.device, ctypes.byref(mai), None, ctypes.byref(st.readback_mem)), "vkAllocateMemory(readback)")
    vk_check(vkBindBufferMemory(st.device, st.readback_buf, st.readback_mem, 0), "vkBindBufferMemory")

    att = VkAttachmentDescription(0, VK_FORMAT_B8G8R8A8_UNORM, VK_SAMPLE_COUNT_1_BIT,
                                  VK_ATTACHMENT_LOAD_OP_CLEAR, VK_ATTACHMENT_STORE_OP_STORE, 0, 0,
                                  VK_IMAGE_LAYOUT_UNDEFINED, VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL)
    aref = VkAttachmentReference(0, VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL)
    subpass = VkSubpassDescription(0, VK_PIPELINE_BIND_POINT_GRAPHICS, 0, None, 1,
                                   ctypes.pointer(aref), None, None, 0, None)
    rpci = VkRenderPassCreateInfo(VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO, None, 0, 1,
                                  ctypes.pointer(att), 1, ctypes.pointer(subpass), 0, None)
    vk_check(vkCreateRenderPass(st.device, ctypes.byref(rpci), None, ctypes.byref(st.render_pass)), "vkCreateRenderPass")

    atts = (VkImageView * 1)(st.off_view)
    fbci = VkFramebufferCreateInfo(VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO, None, 0, st.render_pass, 1,
                                   ctypes.cast(atts, ctypes.POINTER(VkImageView)), width, height, 1)
    vk_check(vkCreateFramebuffer(st.device, ctypes.byref(fbci), None, ctypes.byref(st.framebuffer)), "vkCreateFramebuffer")

    vert_mod = _make_shader_module(st.device, vert_spv)
    frag_mod = _make_shader_module(st.device, frag_spv)
    try:
        plci = VkPipelineLayoutCreateInfo(VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO, None, 0, 0, None, 0, None)
        vk_check(vkCreatePipelineLayout(st.device, ctypes.byref(plci), None, ctypes.byref(st.pipeline_layout)), "vkCreatePipelineLayout")

        stages = (VkPipelineShaderStageCreateInfo * 2)()
        stages[0] = VkPipelineShaderStageCreateInfo(VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO, None, 0, VK_SHADER_STAGE_VERTEX_BIT, vert_mod, b"main", None)
        stages[1] = VkPipelineShaderStageCreateInfo(VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO, None, 0, VK_SHADER_STAGE_FRAGMENT_BIT, frag_mod, b"main", None)
        vin = VkPipelineVertexInputStateCreateInfo(VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO, None, 0, 0, None, 0, None)
        ia = VkPipelineInputAssemblyStateCreateInfo(VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO, None, 0, VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST, 0)
        dummy_vp = VkViewport(0.0, 0.0, float(width), float(height), 0.0, 1.0)
        dummy_sc = VkRect2D(VkOffset2D(0, 0), VkExtent2D(width, height))
        vp_state = VkPipelineViewportStateCreateInfo(VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO, None, 0, 1, ctypes.pointer(dummy_vp), 1, ctypes.pointer(dummy_sc))
        rs = VkPipelineRasterizationStateCreateInfo(VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO, None, 0, 0, 0, VK_POLYGON_MODE_FILL, VK_CULL_MODE_NONE, VK_FRONT_FACE_COUNTER_CLOCKWISE, 0, 0.0, 0.0, 0.0, 1.0)
        ms = VkPipelineMultisampleStateCreateInfo(VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO, None, 0, VK_SAMPLE_COUNT_1_BIT, 0, 1.0, None, 0, 0)
        cba = VkPipelineColorBlendAttachmentState(0, 0, 0, 0, 0, 0, 0,
                                                  VK_COLOR_COMPONENT_R_BIT | VK_COLOR_COMPONENT_G_BIT | VK_COLOR_COMPONENT_B_BIT | VK_COLOR_COMPONENT_A_BIT)
        cbs = VkPipelineColorBlendStateCreateInfo(VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO, None, 0, 0, 0, 1, ctypes.pointer(cba), (ctypes.c_float * 4)(0, 0, 0, 0))
        dyn_states = (ctypes.c_uint32 * 2)(VK_DYNAMIC_STATE_VIEWPORT, VK_DYNAMIC_STATE_SCISSOR)
        dyn = VkDynamicStateCreateInfo(VK_STRUCTURE_TYPE_PIPELINE_DYNAMIC_STATE_CREATE_INFO, None, 0, 2, ctypes.cast(dyn_states, ctypes.POINTER(ctypes.c_uint32)))
        gpci = VkGraphicsPipelineCreateInfo(
            VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO, None, 0, 2,
            ctypes.cast(stages, ctypes.POINTER(VkPipelineShaderStageCreateInfo)),
            ctypes.pointer(vin), ctypes.pointer(ia), None, ctypes.pointer(vp_state),
            ctypes.pointer(rs), ctypes.pointer(ms), None, ctypes.pointer(cbs), ctypes.pointer(dyn),
            st.pipeline_layout, st.render_pass, 0, VkPipeline(0), -1)
        vk_check(vkCreateGraphicsPipelines(st.device, 0, 1, ctypes.byref(gpci), None, ctypes.byref(st.pipeline)), "vkCreateGraphicsPipelines")
    finally:
        vkDestroyShaderModule(st.device, vert_mod, None)
        vkDestroyShaderModule(st.device, frag_mod, None)

    cpci = VkCommandPoolCreateInfo(VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO, None, VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT, st.queue_family)
    vk_check(vkCreateCommandPool(st.device, ctypes.byref(cpci), None, ctypes.byref(st.cmd_pool)), "vkCreateCommandPool")
    cbai = VkCommandBufferAllocateInfo(VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO, None, st.cmd_pool, VK_COMMAND_BUFFER_LEVEL_PRIMARY, 1)
    vk_check(vkAllocateCommandBuffers(st.device, ctypes.byref(cbai), ctypes.byref(st.cmd_buf)), "vkAllocateCommandBuffers")
    fci = VkFenceCreateInfo(VK_STRUCTURE_TYPE_FENCE_CREATE_INFO, None, VK_FENCE_CREATE_SIGNALED_BIT)
    vk_check(vkCreateFence(st.device, ctypes.byref(fci), None, ctypes.byref(st.fence)), "vkCreateFence")
    return st

def _render_vulkan_offscreen_to_composition(st: VkOffscreenState) -> None:
    vkWaitForFences = _get_dev(st.device, b"vkWaitForFences", VkResult, (VkDevice, ctypes.c_uint32, ctypes.POINTER(VkFence), VkBool32, ctypes.c_uint64))
    vkResetFences = _get_dev(st.device, b"vkResetFences", VkResult, (VkDevice, ctypes.c_uint32, ctypes.POINTER(VkFence)))
    vkResetCommandBuffer = _get_dev(st.device, b"vkResetCommandBuffer", VkResult, (VkCommandBuffer, ctypes.c_uint32))
    vkBeginCommandBuffer = _get_dev(st.device, b"vkBeginCommandBuffer", VkResult, (VkCommandBuffer, ctypes.POINTER(VkCommandBufferBeginInfo)))
    vkEndCommandBuffer = _get_dev(st.device, b"vkEndCommandBuffer", VkResult, (VkCommandBuffer,))
    vkCmdBeginRenderPass = _get_dev(st.device, b"vkCmdBeginRenderPass", None, (VkCommandBuffer, ctypes.POINTER(VkRenderPassBeginInfo), ctypes.c_uint32))
    vkCmdEndRenderPass = _get_dev(st.device, b"vkCmdEndRenderPass", None, (VkCommandBuffer,))
    vkCmdBindPipeline = _get_dev(st.device, b"vkCmdBindPipeline", None, (VkCommandBuffer, ctypes.c_uint32, VkPipeline))
    vkCmdSetViewport = _get_dev(st.device, b"vkCmdSetViewport", None, (VkCommandBuffer, ctypes.c_uint32, ctypes.c_uint32, ctypes.POINTER(VkViewport)))
    vkCmdSetScissor = _get_dev(st.device, b"vkCmdSetScissor", None, (VkCommandBuffer, ctypes.c_uint32, ctypes.c_uint32, ctypes.POINTER(VkRect2D)))
    vkCmdDraw = _get_dev(st.device, b"vkCmdDraw", None, (VkCommandBuffer, ctypes.c_uint32, ctypes.c_uint32, ctypes.c_uint32, ctypes.c_uint32))
    vkCmdCopyImageToBuffer = _get_dev(st.device, b"vkCmdCopyImageToBuffer", None, (VkCommandBuffer, VkImage, ctypes.c_uint32, VkBuffer, ctypes.c_uint32, ctypes.POINTER(VkBufferImageCopy)))
    vkQueueSubmit = _get_dev(st.device, b"vkQueueSubmit", VkResult, (VkQueue, ctypes.c_uint32, ctypes.POINTER(VkSubmitInfo), VkFence))
    vkMapMemory = _get_dev(st.device, b"vkMapMemory", VkResult, (VkDevice, VkDeviceMemory, VkDeviceSize, VkDeviceSize, ctypes.c_uint32, ctypes.POINTER(ctypes.c_void_p)))
    vkUnmapMemory = _get_dev(st.device, b"vkUnmapMemory", None, (VkDevice, VkDeviceMemory))

    fences = (VkFence * 1)(st.fence)
    vk_check(vkWaitForFences(st.device, 1, fences, 1, 0xFFFFFFFFFFFFFFFF), "vkWaitForFences")
    vk_check(vkResetFences(st.device, 1, fences), "vkResetFences")
    vk_check(vkResetCommandBuffer(st.cmd_buf, 0), "vkResetCommandBuffer")

    bi = VkCommandBufferBeginInfo(VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO, None, 0, None)
    vk_check(vkBeginCommandBuffer(st.cmd_buf, ctypes.byref(bi)), "vkBeginCommandBuffer")

    clear = VkClearValue()
    clear.color.float32[0] = 1.0
    clear.color.float32[1] = 1.0
    clear.color.float32[2] = 1.0
    clear.color.float32[3] = 1.0
    rpbi = VkRenderPassBeginInfo(
        VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO, None, st.render_pass, st.framebuffer,
        VkRect2D(VkOffset2D(0, 0), VkExtent2D(st.width, st.height)),
        1, ctypes.pointer(clear))
    vkCmdBeginRenderPass(st.cmd_buf, ctypes.byref(rpbi), 0)
    vkCmdBindPipeline(st.cmd_buf, VK_PIPELINE_BIND_POINT_GRAPHICS, st.pipeline)
    vp = VkViewport(0.0, 0.0, float(st.width), float(st.height), 0.0, 1.0)
    sc = VkRect2D(VkOffset2D(0, 0), VkExtent2D(st.width, st.height))
    vkCmdSetViewport(st.cmd_buf, 0, 1, ctypes.byref(vp))
    vkCmdSetScissor(st.cmd_buf, 0, 1, ctypes.byref(sc))
    vkCmdDraw(st.cmd_buf, 3, 1, 0, 0)
    vkCmdEndRenderPass(st.cmd_buf)

    region = VkBufferImageCopy(
        0, st.width, st.height,
        VkImageSubresourceLayers(VK_IMAGE_ASPECT_COLOR_BIT, 0, 0, 1),
        VkOffset3D(0, 0, 0),
        VkExtent3D(st.width, st.height, 1))
    vkCmdCopyImageToBuffer(st.cmd_buf, st.off_image, VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL, st.readback_buf, 1, ctypes.byref(region))
    vk_check(vkEndCommandBuffer(st.cmd_buf), "vkEndCommandBuffer")

    cmds = (VkCommandBuffer * 1)(st.cmd_buf)
    submit = VkSubmitInfo(VK_STRUCTURE_TYPE_SUBMIT_INFO, None, 0, None, None, 1,
                          ctypes.cast(cmds, ctypes.POINTER(VkCommandBuffer)), 0, None)
    vk_check(vkQueueSubmit(st.queue, 1, ctypes.byref(submit), st.fence), "vkQueueSubmit")
    vk_check(vkWaitForFences(st.device, 1, fences, 1, 0xFFFFFFFFFFFFFFFF), "vkWaitForFences(post)")

    vk_data = ctypes.c_void_p()
    vk_check(vkMapMemory(st.device, st.readback_mem, 0, st.width * st.height * 4, 0, ctypes.byref(vk_data)), "vkMapMemory")
    try:
        _copy_vulkan_pixels_to_composition(vk_data, st.width, st.height)
    finally:
        vkUnmapMemory(st.device, st.readback_mem)

def _cleanup_vulkan_offscreen(st: VkOffscreenState | None) -> None:
    if st is None or not st.device:
        return
    try:
        _get_dev(st.device, b"vkDeviceWaitIdle", VkResult, (VkDevice,))(st.device)
    except Exception:
        pass
    try:
        if st.fence:
            _get_dev(st.device, b"vkDestroyFence", None, (VkDevice, VkFence, ctypes.c_void_p))(st.device, st.fence, None)
        if st.cmd_pool:
            _get_dev(st.device, b"vkDestroyCommandPool", None, (VkDevice, VkCommandPool, ctypes.c_void_p))(st.device, st.cmd_pool, None)
        if st.pipeline:
            _get_dev(st.device, b"vkDestroyPipeline", None, (VkDevice, VkPipeline, ctypes.c_void_p))(st.device, st.pipeline, None)
        if st.pipeline_layout:
            _get_dev(st.device, b"vkDestroyPipelineLayout", None, (VkDevice, VkPipelineLayout, ctypes.c_void_p))(st.device, st.pipeline_layout, None)
        if st.framebuffer:
            _get_dev(st.device, b"vkDestroyFramebuffer", None, (VkDevice, VkFramebuffer, ctypes.c_void_p))(st.device, st.framebuffer, None)
        if st.render_pass:
            _get_dev(st.device, b"vkDestroyRenderPass", None, (VkDevice, VkRenderPass, ctypes.c_void_p))(st.device, st.render_pass, None)
        if st.off_view:
            _get_dev(st.device, b"vkDestroyImageView", None, (VkDevice, VkImageView, ctypes.c_void_p))(st.device, st.off_view, None)
        if st.off_image:
            _get_dev(st.device, b"vkDestroyImage", None, (VkDevice, VkImage, ctypes.c_void_p))(st.device, st.off_image, None)
        if st.off_memory:
            _get_dev(st.device, b"vkFreeMemory", None, (VkDevice, VkDeviceMemory, ctypes.c_void_p))(st.device, st.off_memory, None)
        if st.readback_buf:
            _get_dev(st.device, b"vkDestroyBuffer", None, (VkDevice, VkBuffer, ctypes.c_void_p))(st.device, st.readback_buf, None)
        if st.readback_mem:
            _get_dev(st.device, b"vkFreeMemory", None, (VkDevice, VkDeviceMemory, ctypes.c_void_p))(st.device, st.readback_mem, None)
    finally:
        try:
            _get_global(b"vkDestroyDevice", None, (VkDevice, ctypes.c_void_p))(st.device, None)
        except Exception:
            pass
        try:
            vkDestroyInstance(st.instance, None)
        except Exception:
            pass

def main_composition() -> None:
    import faulthandler
    faulthandler.enable()
    log("=== START (Vulkan 1.4 + Windows.UI.Composition) ===")

    shaderc = Shaderc("shaderc_shared.dll")
    vert_path = SCRIPT_DIR / "hello.vert"
    frag_path = SCRIPT_DIR / "hello.frag"
    vert_spv = shaderc.compile(vert_path.read_text(encoding="utf-8"), Shaderc.VERTEX, filename=vert_path.name)
    frag_spv = shaderc.compile(frag_path.read_text(encoding="utf-8"), Shaderc.FRAGMENT, filename=frag_path.name)

    hwnd, _ = create_window("Vulkan 1.4 Triangle via Windows.UI.Composition (Python)", WIDTH, HEIGHT)
    vk_state = None
    try:
        _init_composition_bridge(hwnd, WIDTH, HEIGHT)
        vk_state = _init_vulkan_offscreen(vert_spv, frag_spv, WIDTH, HEIGHT)
        while True:
            if not pump_messages() or _g_should_quit:
                break
            _render_vulkan_offscreen_to_composition(vk_state)
            kernel32.Sleep(1)
    finally:
        _cleanup_vulkan_offscreen(vk_state)
        try:
            _cleanup_composition_bridge()
        except Exception:
            pass
        log("=== END ===")

# ============================================================
# main
# ============================================================
def main() -> None:
    import faulthandler
    faulthandler.enable()

    log("=== START ===")
    log("STEP: Shaderc init")
    shaderc = Shaderc("shaderc_shared.dll")

    vert_path = SCRIPT_DIR / "hello.vert"
    frag_path = SCRIPT_DIR / "hello.frag"
    if not vert_path.is_file() or not frag_path.is_file():
        raise FileNotFoundError("hello.vert / hello.frag must be in the same folder as this script")

    log(f"Reading shader: {vert_path}")
    log(f"Reading shader: {frag_path}")
    vert_src = vert_path.read_text(encoding="utf-8")
    frag_src = frag_path.read_text(encoding="utf-8")

    log("STEP: shaderc compile hello.vert")
    vert_spv = shaderc.compile(vert_src, Shaderc.VERTEX, filename=str(vert_path.name))
    log(f"shaderc OK: hello.vert -> {len(vert_spv)} bytes SPIR-V")

    log("STEP: shaderc compile hello.frag")
    frag_spv = shaderc.compile(frag_src, Shaderc.FRAGMENT, filename=str(frag_path.name))
    log(f"shaderc OK: hello.frag -> {len(frag_spv)} bytes SPIR-V")

    log("STEP: create_window")
    hwnd, hinst = create_window("Vulkan 1.4 Triangle (Python + shaderc)", 800, 600)
    log(f"Window created hwnd={hx(hwnd)} hinst={hx(hinst)}")

    log("STEP: vkCreateInstance")
    instance = create_instance()
    log(f"vkCreateInstance OK (instance_ptr={hx(instance)})")

    log("STEP: vkCreateWin32SurfaceKHR")
    surface = create_surface(instance, hwnd, hinst)
    log(f"vkCreateWin32SurfaceKHR OK (surface={hx(surface)})")

    log("STEP: pick_physical_device")
    pd, graphics_q, present_q = pick_physical_device(instance, surface)
    log(f"Selected physical device pd={hx(pd)} graphicsQ={graphics_q} presentQ={present_q}")

    log("STEP: vkCreateDevice")
    device, graphics_queue, present_queue = create_device(pd, graphics_q, present_q)
    log(f"vkCreateDevice OK (device_ptr={hx(device)})")
    log(f"Queues: graphics={hx(graphics_queue)} present={hx(present_queue)}")

    log("STEP: create_swapchain/pipeline")
    bundle = create_swapchain_bundle(instance, device, pd, surface, hwnd, graphics_q, present_q, vert_spv, frag_spv)

    log("STEP: create_sync_objects")
    sync = create_sync_objects(device, max_frames=2)

    # Device functions for draw loop
    vkAcquireNextImageKHR = _get_dev(device, b"vkAcquireNextImageKHR", VkResult, (VkDevice, VkSwapchainKHR, ctypes.c_uint64, VkSemaphore, VkFence, ctypes.POINTER(ctypes.c_uint32)))
    vkQueueSubmit         = _get_dev(device, b"vkQueueSubmit", VkResult, (VkQueue, ctypes.c_uint32, ctypes.POINTER(VkSubmitInfo), VkFence))
    vkQueuePresentKHR     = _get_dev(device, b"vkQueuePresentKHR", VkResult, (VkQueue, ctypes.POINTER(VkPresentInfoKHR)))
    vkWaitForFences       = _get_dev(device, b"vkWaitForFences", VkResult, (VkDevice, ctypes.c_uint32, ctypes.POINTER(VkFence), VkBool32, ctypes.c_uint64))
    vkResetFences         = _get_dev(device, b"vkResetFences", VkResult, (VkDevice, ctypes.c_uint32, ctypes.POINTER(VkFence)))
    vkDeviceWaitIdle      = _get_dev(device, b"vkDeviceWaitIdle", VkResult, (VkDevice,))

    frame = 0
    log("STEP: entering main loop (close the window to exit)")

    global _g_resized
    _g_resized = False  # avoid immediate recreation on the first WM_SIZE during creation

    while True:
        if not pump_messages():
            break
        if _g_should_quit:
            break

        if _g_resized:
            _g_resized = False
            bundle = recreate_swapchain(instance, device, pd, surface, hwnd, graphics_q, present_q, vert_spv, frag_spv, bundle)
            continue

        cur = frame % sync.max_frames

        # --- FIX: byref needs ctypes instances; array element access returns int.
        # Make a 1-element VkFence array for vkWaitForFences/vkResetFences.
        fences = (VkFence * 1)(sync.in_flight[cur])

        vk_check(vkWaitForFences(device, 1, fences, 1, 0xFFFFFFFFFFFFFFFF), "vkWaitForFences")
        vk_check(vkResetFences(device, 1, fences), "vkResetFences")

        image_index = ctypes.c_uint32(0)
        res = vkAcquireNextImageKHR(
            device,
            bundle.swapchain,
            0xFFFFFFFFFFFFFFFF,
            sync.image_available[cur],
            VkFence(0),
            ctypes.byref(image_index),
        )

        if res == VK_ERROR_OUT_OF_DATE_KHR:
            log("vkAcquireNextImageKHR: OUT_OF_DATE -> recreate")
            bundle = recreate_swapchain(instance, device, pd, surface, hwnd, graphics_q, present_q, vert_spv, frag_spv, bundle)
            continue
        elif res != VK_SUCCESS and res != VK_SUBOPTIMAL_KHR:
            raise RuntimeError(f"vkAcquireNextImageKHR failed: {res}")

        wait_sems   = (VkSemaphore * 1)(sync.image_available[cur])
        signal_sems = (VkSemaphore * 1)(sync.render_finished[cur])
        wait_stages = (ctypes.c_uint32 * 1)(VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT)

        cmd = bundle.command_buffers[image_index.value]
        cmd_ptr = (VkCommandBuffer * 1)(cmd)

        submit = VkSubmitInfo(
            sType=VK_STRUCTURE_TYPE_SUBMIT_INFO,
            pNext=None,
            waitSemaphoreCount=1,
            pWaitSemaphores=ctypes.cast(wait_sems, ctypes.POINTER(VkSemaphore)),
            pWaitDstStageMask=ctypes.cast(wait_stages, ctypes.POINTER(ctypes.c_uint32)),
            commandBufferCount=1,
            pCommandBuffers=ctypes.cast(cmd_ptr, ctypes.POINTER(VkCommandBuffer)),
            signalSemaphoreCount=1,
            pSignalSemaphores=ctypes.cast(signal_sems, ctypes.POINTER(VkSemaphore)),
        )

        # Submit fence: use same value as in fences[0]
        submit_fence = VkFence(sync.in_flight[cur])
        vk_check(vkQueueSubmit(graphics_queue, 1, ctypes.byref(submit), submit_fence), "vkQueueSubmit")

        swapchains = (VkSwapchainKHR * 1)(bundle.swapchain)
        indices    = (ctypes.c_uint32 * 1)(image_index.value)

        present = VkPresentInfoKHR(
            sType=VK_STRUCTURE_TYPE_PRESENT_INFO_KHR,
            pNext=None,
            waitSemaphoreCount=1,
            pWaitSemaphores=ctypes.cast(signal_sems, ctypes.POINTER(VkSemaphore)),
            swapchainCount=1,
            pSwapchains=ctypes.cast(swapchains, ctypes.POINTER(VkSwapchainKHR)),
            pImageIndices=ctypes.cast(indices, ctypes.POINTER(ctypes.c_uint32)),
            pResults=None,
        )

        pres_res = vkQueuePresentKHR(present_queue, ctypes.byref(present))
        if pres_res in (VK_ERROR_OUT_OF_DATE_KHR, VK_SUBOPTIMAL_KHR):
            log(f"vkQueuePresentKHR: {pres_res} -> recreate")
            bundle = recreate_swapchain(instance, device, pd, surface, hwnd, graphics_q, present_q, vert_spv, frag_spv, bundle)
        elif pres_res != VK_SUCCESS:
            raise RuntimeError(f"vkQueuePresentKHR failed: {pres_res}")

        frame += 1

    log("Main loop ended; waiting device idle...")
    vk_check(vkDeviceWaitIdle(device), "vkDeviceWaitIdle")

    destroy_swapchain_bundle(device, bundle)

    vkDestroySemaphore = _get_dev(device, b"vkDestroySemaphore", None, (VkDevice, VkSemaphore, ctypes.c_void_p))
    vkDestroyFence     = _get_dev(device, b"vkDestroyFence", None, (VkDevice, VkFence, ctypes.c_void_p))
    for i in range(sync.max_frames):
        if sync.image_available[i]:
            vkDestroySemaphore(device, sync.image_available[i], None)
        if sync.render_finished[i]:
            vkDestroySemaphore(device, sync.render_finished[i], None)
        if sync.in_flight[i]:
            vkDestroyFence(device, sync.in_flight[i], None)

    destroy_device_and_instance(instance, device, surface)
    log("=== END ===")

if __name__ == "__main__":
    try:
        main_composition()
    except Exception:
        log("EXCEPTION:")
        raise
