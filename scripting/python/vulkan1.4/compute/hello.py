# -*- coding: utf-8 -*-
"""Vulkan 1.4 Compute Harmonograph (Windows, Python, no external Python packages)

- Win32 window via ctypes
- Vulkan via vulkan-1.dll (ctypes)
- Runtime GLSL->SPIR-V via shaderc_shared.dll (ctypes)
- Compute shader calculates harmonograph points
- Graphics pipeline renders points as LINE_STRIP
"""

from __future__ import annotations

import os
import sys
import time
import ctypes
import math
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
CW_USEDEFAULT = 0x80000000
SW_SHOW = 5

WM_DESTROY = 0x0002
WM_CLOSE   = 0x0010
WM_QUIT    = 0x0012
WM_SIZE    = 0x0005
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

_g_should_quit = False
_g_resized = False
_WNDPROC_REF = None

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
        return user32.DefWindowProcW(hwnd, msg, wparam, lparam)

    _WNDPROC_REF = wndproc

    class_name = "VkHarmonographWindow"
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
        0, class_name, title, WS_OVERLAPPEDWINDOW,
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
    VERTEX   = 0
    FRAGMENT = 1
    COMPUTE  = 2
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
VkSurfaceKHR        = ctypes.c_uint64
VkSwapchainKHR      = ctypes.c_uint64
VkImage             = ctypes.c_uint64
VkImageView         = ctypes.c_uint64
VkShaderModule      = ctypes.c_uint64
VkRenderPass        = ctypes.c_uint64
VkPipelineLayout    = ctypes.c_uint64
VkPipeline          = ctypes.c_uint64
VkFramebuffer       = ctypes.c_uint64
VkSemaphore         = ctypes.c_uint64
VkFence             = ctypes.c_uint64
VkBuffer            = ctypes.c_uint64
VkDeviceMemory      = ctypes.c_uint64
VkDescriptorSetLayout = ctypes.c_uint64
VkDescriptorPool    = ctypes.c_uint64
VkDescriptorSet     = ctypes.c_uint64

VK_SUCCESS = 0
VK_ERROR_OUT_OF_DATE_KHR = -1000001004
VK_SUBOPTIMAL_KHR        = 1000001003

# VK_STRUCTURE_TYPE_*
VK_STRUCTURE_TYPE_APPLICATION_INFO                      = 0
VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO                  = 1
VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO              = 2
VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO                    = 3
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
VK_STRUCTURE_TYPE_COMPUTE_PIPELINE_CREATE_INFO          = 29
VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO               = 37
VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO              = 39
VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO          = 40
VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO             = 42
VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO                = 43
VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO                 = 9
VK_STRUCTURE_TYPE_FENCE_CREATE_INFO                     = 8
VK_STRUCTURE_TYPE_SUBMIT_INFO                           = 4
VK_STRUCTURE_TYPE_PRESENT_INFO_KHR                      = 1000001002
VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO                    = 12
VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO                  = 5
VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO     = 32
VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO           = 33
VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO          = 34
VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET                  = 35
VK_STRUCTURE_TYPE_BUFFER_MEMORY_BARRIER                 = 44

# Extensions
VK_KHR_SURFACE_EXTENSION_NAME       = b"VK_KHR_surface"
VK_KHR_WIN32_SURFACE_EXTENSION_NAME = b"VK_KHR_win32_surface"
VK_KHR_SWAPCHAIN_EXTENSION_NAME     = b"VK_KHR_swapchain"

# Queue flags
VK_QUEUE_GRAPHICS_BIT = 0x00000001
VK_QUEUE_COMPUTE_BIT  = 0x00000002

# Command pool flags
VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT = 0x00000002

# Pipeline
VK_PIPELINE_BIND_POINT_GRAPHICS = 0
VK_PIPELINE_BIND_POINT_COMPUTE  = 1
VK_PRIMITIVE_TOPOLOGY_POINT_LIST = 0
VK_PRIMITIVE_TOPOLOGY_LINE_LIST = 1
VK_PRIMITIVE_TOPOLOGY_LINE_STRIP = 2
VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST = 3

VK_POLYGON_MODE_FILL = 0
VK_CULL_MODE_NONE = 0
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
VK_IMAGE_VIEW_TYPE_2D = 1

VK_IMAGE_LAYOUT_UNDEFINED = 0
VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL = 2
VK_IMAGE_LAYOUT_PRESENT_SRC_KHR = 1000001002

# Attachment
VK_ATTACHMENT_LOAD_OP_CLEAR  = 1
VK_ATTACHMENT_STORE_OP_STORE = 0

# Sharing mode
VK_SHARING_MODE_EXCLUSIVE   = 0
VK_SHARING_MODE_CONCURRENT  = 1

# Present mode
VK_PRESENT_MODE_FIFO_KHR = 2

# Composite alpha / transform
VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR = 0x00000001
VK_SURFACE_TRANSFORM_IDENTITY_BIT_KHR = 0x00000001

# Pipeline stage
VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT = 0x00000400
VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT          = 0x00000800
VK_PIPELINE_STAGE_VERTEX_SHADER_BIT           = 0x00000008

# Fence
VK_FENCE_CREATE_SIGNALED_BIT = 0x00000001

# Command buffer
VK_COMMAND_BUFFER_LEVEL_PRIMARY = 0

# Shader stage
VK_SHADER_STAGE_VERTEX_BIT   = 0x00000001
VK_SHADER_STAGE_FRAGMENT_BIT = 0x00000010
VK_SHADER_STAGE_COMPUTE_BIT  = 0x00000020

# Image usage
VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT = 0x00000010

# Buffer usage
VK_BUFFER_USAGE_UNIFORM_BUFFER_BIT = 0x00000010
VK_BUFFER_USAGE_STORAGE_BUFFER_BIT = 0x00000020

# Memory property
VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT     = 0x00000001
VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT     = 0x00000002
VK_MEMORY_PROPERTY_HOST_COHERENT_BIT    = 0x00000004

# Descriptor type
VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER = 6
VK_DESCRIPTOR_TYPE_STORAGE_BUFFER = 7

# Access flags
VK_ACCESS_SHADER_WRITE_BIT = 0x00000040
VK_ACCESS_SHADER_READ_BIT  = 0x00000020

VK_QUEUE_FAMILY_IGNORED = 0xFFFFFFFF

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
        ("pSetLayouts", ctypes.POINTER(VkDescriptorSetLayout)),
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

class VkComputePipelineCreateInfo(ctypes.Structure):
    _fields_ = [
        ("sType", ctypes.c_uint32),
        ("pNext", ctypes.c_void_p),
        ("flags", ctypes.c_uint32),
        ("stage", VkPipelineShaderStageCreateInfo),
        ("layout", VkPipelineLayout),
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

class VkBufferCreateInfo(ctypes.Structure):
    _fields_ = [
        ("sType", ctypes.c_uint32),
        ("pNext", ctypes.c_void_p),
        ("flags", ctypes.c_uint32),
        ("size", VkDeviceSize),
        ("usage", ctypes.c_uint32),
        ("sharingMode", ctypes.c_uint32),
        ("queueFamilyIndexCount", ctypes.c_uint32),
        ("pQueueFamilyIndices", ctypes.c_void_p),
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

class VkPhysicalDeviceMemoryProperties(ctypes.Structure):
    class VkMemoryType(ctypes.Structure):
        _fields_ = [("propertyFlags", ctypes.c_uint32), ("heapIndex", ctypes.c_uint32)]
    class VkMemoryHeap(ctypes.Structure):
        _fields_ = [("size", VkDeviceSize), ("flags", ctypes.c_uint32)]
    _fields_ = [
        ("memoryTypeCount", ctypes.c_uint32),
        ("memoryTypes", VkMemoryType * 32),
        ("memoryHeapCount", ctypes.c_uint32),
        ("memoryHeaps", VkMemoryHeap * 16),
    ]

class VkDescriptorSetLayoutBinding(ctypes.Structure):
    _fields_ = [
        ("binding", ctypes.c_uint32),
        ("descriptorType", ctypes.c_uint32),
        ("descriptorCount", ctypes.c_uint32),
        ("stageFlags", ctypes.c_uint32),
        ("pImmutableSamplers", ctypes.c_void_p),
    ]

class VkDescriptorSetLayoutCreateInfo(ctypes.Structure):
    _fields_ = [
        ("sType", ctypes.c_uint32),
        ("pNext", ctypes.c_void_p),
        ("flags", ctypes.c_uint32),
        ("bindingCount", ctypes.c_uint32),
        ("pBindings", ctypes.POINTER(VkDescriptorSetLayoutBinding)),
    ]

class VkDescriptorPoolSize(ctypes.Structure):
    _fields_ = [("type", ctypes.c_uint32), ("descriptorCount", ctypes.c_uint32)]

class VkDescriptorPoolCreateInfo(ctypes.Structure):
    _fields_ = [
        ("sType", ctypes.c_uint32),
        ("pNext", ctypes.c_void_p),
        ("flags", ctypes.c_uint32),
        ("maxSets", ctypes.c_uint32),
        ("poolSizeCount", ctypes.c_uint32),
        ("pPoolSizes", ctypes.POINTER(VkDescriptorPoolSize)),
    ]

class VkDescriptorSetAllocateInfo(ctypes.Structure):
    _fields_ = [
        ("sType", ctypes.c_uint32),
        ("pNext", ctypes.c_void_p),
        ("descriptorPool", VkDescriptorPool),
        ("descriptorSetCount", ctypes.c_uint32),
        ("pSetLayouts", ctypes.POINTER(VkDescriptorSetLayout)),
    ]

class VkDescriptorBufferInfo(ctypes.Structure):
    _fields_ = [
        ("buffer", VkBuffer),
        ("offset", VkDeviceSize),
        ("range", VkDeviceSize),
    ]

class VkWriteDescriptorSet(ctypes.Structure):
    _fields_ = [
        ("sType", ctypes.c_uint32),
        ("pNext", ctypes.c_void_p),
        ("dstSet", VkDescriptorSet),
        ("dstBinding", ctypes.c_uint32),
        ("dstArrayElement", ctypes.c_uint32),
        ("descriptorCount", ctypes.c_uint32),
        ("descriptorType", ctypes.c_uint32),
        ("pImageInfo", ctypes.c_void_p),
        ("pBufferInfo", ctypes.POINTER(VkDescriptorBufferInfo)),
        ("pTexelBufferView", ctypes.c_void_p),
    ]

class VkBufferMemoryBarrier(ctypes.Structure):
    _fields_ = [
        ("sType", ctypes.c_uint32),
        ("pNext", ctypes.c_void_p),
        ("srcAccessMask", ctypes.c_uint32),
        ("dstAccessMask", ctypes.c_uint32),
        ("srcQueueFamilyIndex", ctypes.c_uint32),
        ("dstQueueFamilyIndex", ctypes.c_uint32),
        ("buffer", VkBuffer),
        ("offset", VkDeviceSize),
        ("size", VkDeviceSize),
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
vkGetPhysicalDeviceMemoryProperties = _get_global(b"vkGetPhysicalDeviceMemoryProperties", None, (VkPhysicalDevice, ctypes.POINTER(VkPhysicalDeviceMemoryProperties)))

# ============================================================
# Vulkan helpers
# ============================================================
def create_instance() -> VkInstance:
    exts = (ctypes.c_char_p * 2)(VK_KHR_SURFACE_EXTENSION_NAME, VK_KHR_WIN32_SURFACE_EXTENSION_NAME)

    api_1_4 = (1 << 22) | (4 << 12) | 0

    app = VkApplicationInfo(
        sType=VK_STRUCTURE_TYPE_APPLICATION_INFO,
        pNext=None,
        pApplicationName=b"PyVulkanHarmonograph",
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

def pick_physical_device(instance: VkInstance, surface: VkSurfaceKHR) -> tuple[VkPhysicalDevice, int]:
    """Returns physical device and queue family index that supports graphics+compute+present."""
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

        for qi in range(qcount.value):
            graphics_ok = (props[qi].queueFlags & VK_QUEUE_GRAPHICS_BIT) != 0
            compute_ok = (props[qi].queueFlags & VK_QUEUE_COMPUTE_BIT) != 0

            supported = VkBool32(0)
            vk_check(vkGetPhysicalDeviceSurfaceSupportKHR(pd, qi, surface, ctypes.byref(supported)), "vkGetPhysicalDeviceSurfaceSupportKHR")
            present_ok = supported.value != 0

            if graphics_ok and compute_ok and present_ok:
                return pd, qi

    raise RuntimeError("No suitable physical device/queue family found (need graphics+compute+present)")

def create_device(pd: VkPhysicalDevice, queue_family: int) -> tuple[VkDevice, VkQueue]:
    priorities = (ctypes.c_float * 1)(1.0)
    qinfo = VkDeviceQueueCreateInfo(
        sType=VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
        pNext=None,
        flags=0,
        queueFamilyIndex=queue_family,
        queueCount=1,
        pQueuePriorities=priorities,
    )

    dev_exts = (ctypes.c_char_p * 1)(VK_KHR_SWAPCHAIN_EXTENSION_NAME)

    dci = VkDeviceCreateInfo(
        sType=VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO,
        pNext=None,
        flags=0,
        queueCreateInfoCount=1,
        pQueueCreateInfos=ctypes.pointer(qinfo),
        enabledLayerCount=0,
        ppEnabledLayerNames=None,
        enabledExtensionCount=1,
        ppEnabledExtensionNames=ctypes.cast(dev_exts, ctypes.POINTER(ctypes.c_char_p)),
        pEnabledFeatures=None,
    )

    device = VkDevice()
    vk_check(vkCreateDevice(pd, ctypes.byref(dci), None, ctypes.byref(device)), "vkCreateDevice")

    vkGetDeviceQueue = _get_dev(device, b"vkGetDeviceQueue", None, (VkDevice, ctypes.c_uint32, ctypes.c_uint32, ctypes.POINTER(VkQueue)))
    queue = VkQueue()
    vkGetDeviceQueue(device, queue_family, 0, ctypes.byref(queue))
    return device, queue

# ============================================================
# Memory helpers
# ============================================================
def find_memory_type(pd: VkPhysicalDevice, type_bits: int, props: int) -> int:
    mem_props = VkPhysicalDeviceMemoryProperties()
    vkGetPhysicalDeviceMemoryProperties(pd, ctypes.byref(mem_props))
    for i in range(mem_props.memoryTypeCount):
        if (type_bits & (1 << i)) and ((mem_props.memoryTypes[i].propertyFlags & props) == props):
            return i
    raise RuntimeError("No suitable memory type found")

# ============================================================
# Bundle for all resources
# ============================================================
class HarmonographBundle:
    def __init__(self):
        # Swapchain
        self.swapchain = VkSwapchainKHR(0)
        self.format = 0
        self.extent = VkExtent2D(0, 0)
        self.image_count = 0
        self.images = None
        self.views = None
        self.render_pass = VkRenderPass(0)
        self.framebuffers = None
        self.command_pool = VkCommandPool()
        self.command_buffers = None

        # Pipelines
        self.compute_pipeline_layout = VkPipelineLayout(0)
        self.compute_pipeline = VkPipeline(0)
        self.graphics_pipeline_layout = VkPipelineLayout(0)
        self.graphics_pipeline = VkPipeline(0)

        # Buffers
        self.pos_buffer = VkBuffer(0)
        self.pos_memory = VkDeviceMemory(0)
        self.col_buffer = VkBuffer(0)
        self.col_memory = VkDeviceMemory(0)
        self.ubo_buffer = VkBuffer(0)
        self.ubo_memory = VkDeviceMemory(0)

        # Descriptors
        self.descriptor_set_layout = VkDescriptorSetLayout(0)
        self.descriptor_pool = VkDescriptorPool(0)
        self.descriptor_set = VkDescriptorSet(0)

# ============================================================
# Harmonograph parameters UBO (std140 layout)
# ============================================================
VERTEX_COUNT = 500000

class ParamsUBO(ctypes.Structure):
    _fields_ = [
        ("max_num", ctypes.c_uint32),
        ("dt", ctypes.c_float),
        ("scale", ctypes.c_float),
        ("pad0", ctypes.c_float),
        ("A1", ctypes.c_float), ("f1", ctypes.c_float), ("p1", ctypes.c_float), ("d1", ctypes.c_float),
        ("A2", ctypes.c_float), ("f2", ctypes.c_float), ("p2", ctypes.c_float), ("d2", ctypes.c_float),
        ("A3", ctypes.c_float), ("f3", ctypes.c_float), ("p3", ctypes.c_float), ("d3", ctypes.c_float),
        ("A4", ctypes.c_float), ("f4", ctypes.c_float), ("p4", ctypes.c_float), ("d4", ctypes.c_float),
    ]

# ============================================================
# Shader sources
# ============================================================
COMP_SHADER_SRC = """#version 450
layout(local_size_x = 256, local_size_y = 1, local_size_z = 1) in;

layout(std430, binding = 0) buffer Positions { vec4 pos[]; };
layout(std430, binding = 1) buffer Colors    { vec4 col[]; };

layout(std140, binding = 2) uniform Params
{
    uint  max_num;
    float dt;
    float scale;
    float pad0;

    float A1; float f1; float p1; float d1;
    float A2; float f2; float p2; float d2;
    float A3; float f3; float p3; float d3;
    float A4; float f4; float p4; float d4;
} u;

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
    if (idx >= u.max_num) return;

    float t  = float(idx) * u.dt;
    float PI = 3.141592653589793;

    float x = u.A1 * sin(u.f1 * t + PI * u.p1) * exp(-u.d1 * t) +
              u.A2 * sin(u.f2 * t + PI * u.p2) * exp(-u.d2 * t);

    float y = u.A3 * sin(u.f3 * t + PI * u.p3) * exp(-u.d3 * t) +
              u.A4 * sin(u.f4 * t + PI * u.p4) * exp(-u.d4 * t);

    vec2 p = vec2(x, y) * u.scale;
    pos[idx] = vec4(p.x, p.y, 0.0, 1.0);

    float hue = mod((t / 20.0) * 360.0, 360.0);
    vec3 rgb  = hsv2rgb(hue, 1.0, 1.0);
    col[idx]  = vec4(rgb, 1.0);
}
"""

VERT_SHADER_SRC = """#version 450
layout(std430, binding = 0) buffer Positions { vec4 pos[]; };
layout(std430, binding = 1) buffer Colors    { vec4 col[]; };

layout(location = 0) out vec4 vColor;

void main()
{
    uint idx = uint(gl_VertexIndex);
    gl_Position = pos[idx];
    vColor = col[idx];
}
"""

FRAG_SHADER_SRC = """#version 450
layout(location = 0) in  vec4 vColor;
layout(location = 0) out vec4 outColor;

void main()
{
    outColor = vColor;
}
"""

# ============================================================
# Create/destroy bundle
# ============================================================
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
    for i in range(len(fmts)):
        if fmts[i].format == 44:  # VK_FORMAT_B8G8R8A8_UNORM
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

def create_bundle(instance: VkInstance, device: VkDevice, pd: VkPhysicalDevice, surface: VkSurfaceKHR,
                  hwnd, queue_family: int, comp_spv: bytes, vert_spv: bytes, frag_spv: bytes) -> HarmonographBundle:
    bundle = HarmonographBundle()

    # Get device functions
    vkCreateSwapchainKHR = _get_dev(device, b"vkCreateSwapchainKHR", VkResult, (VkDevice, ctypes.POINTER(VkSwapchainCreateInfoKHR), ctypes.c_void_p, ctypes.POINTER(VkSwapchainKHR)))
    vkGetSwapchainImagesKHR = _get_dev(device, b"vkGetSwapchainImagesKHR", VkResult, (VkDevice, VkSwapchainKHR, ctypes.POINTER(ctypes.c_uint32), ctypes.POINTER(VkImage)))
    vkCreateImageView = _get_dev(device, b"vkCreateImageView", VkResult, (VkDevice, ctypes.POINTER(VkImageViewCreateInfo), ctypes.c_void_p, ctypes.POINTER(VkImageView)))
    vkCreateRenderPass = _get_dev(device, b"vkCreateRenderPass", VkResult, (VkDevice, ctypes.POINTER(VkRenderPassCreateInfo), ctypes.c_void_p, ctypes.POINTER(VkRenderPass)))
    vkCreateFramebuffer = _get_dev(device, b"vkCreateFramebuffer", VkResult, (VkDevice, ctypes.POINTER(VkFramebufferCreateInfo), ctypes.c_void_p, ctypes.POINTER(VkFramebuffer)))
    vkCreateCommandPool = _get_dev(device, b"vkCreateCommandPool", VkResult, (VkDevice, ctypes.POINTER(VkCommandPoolCreateInfo), ctypes.c_void_p, ctypes.POINTER(VkCommandPool)))
    vkAllocateCommandBuffers = _get_dev(device, b"vkAllocateCommandBuffers", VkResult, (VkDevice, ctypes.POINTER(VkCommandBufferAllocateInfo), ctypes.POINTER(VkCommandBuffer)))
    vkCreatePipelineLayout = _get_dev(device, b"vkCreatePipelineLayout", VkResult, (VkDevice, ctypes.POINTER(VkPipelineLayoutCreateInfo), ctypes.c_void_p, ctypes.POINTER(VkPipelineLayout)))
    vkCreateGraphicsPipelines = _get_dev(device, b"vkCreateGraphicsPipelines", VkResult, (VkDevice, ctypes.c_uint64, ctypes.c_uint32, ctypes.POINTER(VkGraphicsPipelineCreateInfo), ctypes.c_void_p, ctypes.POINTER(VkPipeline)))
    vkCreateComputePipelines = _get_dev(device, b"vkCreateComputePipelines", VkResult, (VkDevice, ctypes.c_uint64, ctypes.c_uint32, ctypes.POINTER(VkComputePipelineCreateInfo), ctypes.c_void_p, ctypes.POINTER(VkPipeline)))
    vkDestroyShaderModule = _get_dev(device, b"vkDestroyShaderModule", None, (VkDevice, VkShaderModule, ctypes.c_void_p))
    vkCreateBuffer = _get_dev(device, b"vkCreateBuffer", VkResult, (VkDevice, ctypes.POINTER(VkBufferCreateInfo), ctypes.c_void_p, ctypes.POINTER(VkBuffer)))
    vkGetBufferMemoryRequirements = _get_dev(device, b"vkGetBufferMemoryRequirements", None, (VkDevice, VkBuffer, ctypes.POINTER(VkMemoryRequirements)))
    vkAllocateMemory = _get_dev(device, b"vkAllocateMemory", VkResult, (VkDevice, ctypes.POINTER(VkMemoryAllocateInfo), ctypes.c_void_p, ctypes.POINTER(VkDeviceMemory)))
    vkBindBufferMemory = _get_dev(device, b"vkBindBufferMemory", VkResult, (VkDevice, VkBuffer, VkDeviceMemory, VkDeviceSize))
    vkCreateDescriptorSetLayout = _get_dev(device, b"vkCreateDescriptorSetLayout", VkResult, (VkDevice, ctypes.POINTER(VkDescriptorSetLayoutCreateInfo), ctypes.c_void_p, ctypes.POINTER(VkDescriptorSetLayout)))
    vkCreateDescriptorPool = _get_dev(device, b"vkCreateDescriptorPool", VkResult, (VkDevice, ctypes.POINTER(VkDescriptorPoolCreateInfo), ctypes.c_void_p, ctypes.POINTER(VkDescriptorPool)))
    vkAllocateDescriptorSets = _get_dev(device, b"vkAllocateDescriptorSets", VkResult, (VkDevice, ctypes.POINTER(VkDescriptorSetAllocateInfo), ctypes.POINTER(VkDescriptorSet)))
    vkUpdateDescriptorSets = _get_dev(device, b"vkUpdateDescriptorSets", None, (VkDevice, ctypes.c_uint32, ctypes.POINTER(VkWriteDescriptorSet), ctypes.c_uint32, ctypes.c_void_p))

    # Query swapchain
    caps, fmts, pms = query_swapchain_support(instance, pd, surface)
    sfmt = choose_surface_format(fmts)
    pmode = choose_present_mode(pms)
    extent = choose_extent(hwnd, caps)

    image_count = caps.minImageCount + 1
    if caps.maxImageCount != 0 and image_count > caps.maxImageCount:
        image_count = caps.maxImageCount

    # Create swapchain
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
        imageSharingMode=VK_SHARING_MODE_EXCLUSIVE,
        queueFamilyIndexCount=0,
        pQueueFamilyIndices=None,
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

    # Image views
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

    # Render pass
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

    # Framebuffers
    framebuffers = (VkFramebuffer * bundle.image_count)()
    for i in range(bundle.image_count):
        atts = (VkImageView * 1)(views[i])
        fbci = VkFramebufferCreateInfo(
            sType=VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO,
            pNext=None,
            flags=0,
            renderPass=rp,
            attachmentCount=1,
            pAttachments=atts,
            width=extent.width,
            height=extent.height,
            layers=1,
        )
        fb = VkFramebuffer(0)
        vk_check(vkCreateFramebuffer(device, ctypes.byref(fbci), None, ctypes.byref(fb)), "vkCreateFramebuffer")
        framebuffers[i] = fb
    bundle.framebuffers = framebuffers
    log(f"Framebuffers created")

    # Command pool
    cpci = VkCommandPoolCreateInfo(
        sType=VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO,
        pNext=None,
        flags=VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT,
        queueFamilyIndex=queue_family,
    )
    cp = VkCommandPool()
    vk_check(vkCreateCommandPool(device, ctypes.byref(cpci), None, ctypes.byref(cp)), "vkCreateCommandPool")
    bundle.command_pool = cp

    # Command buffers
    cbai = VkCommandBufferAllocateInfo(
        sType=VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
        pNext=None,
        commandPool=cp,
        level=VK_COMMAND_BUFFER_LEVEL_PRIMARY,
        commandBufferCount=bundle.image_count,
    )
    command_buffers = (VkCommandBuffer * bundle.image_count)()
    vk_check(vkAllocateCommandBuffers(device, ctypes.byref(cbai), command_buffers), "vkAllocateCommandBuffers")
    bundle.command_buffers = command_buffers
    log(f"Command pool and buffers created")

    # ---- Buffers ----
    def create_buffer(size, usage, mem_props):
        bci = VkBufferCreateInfo(
            sType=VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO,
            pNext=None,
            flags=0,
            size=size,
            usage=usage,
            sharingMode=VK_SHARING_MODE_EXCLUSIVE,
            queueFamilyIndexCount=0,
            pQueueFamilyIndices=None,
        )
        buf = VkBuffer(0)
        vk_check(vkCreateBuffer(device, ctypes.byref(bci), None, ctypes.byref(buf)), "vkCreateBuffer")

        req = VkMemoryRequirements()
        vkGetBufferMemoryRequirements(device, buf, ctypes.byref(req))

        mai = VkMemoryAllocateInfo(
            sType=VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
            pNext=None,
            allocationSize=req.size,
            memoryTypeIndex=find_memory_type(pd, req.memoryTypeBits, mem_props),
        )
        mem = VkDeviceMemory(0)
        vk_check(vkAllocateMemory(device, ctypes.byref(mai), None, ctypes.byref(mem)), "vkAllocateMemory")
        vk_check(vkBindBufferMemory(device, buf, mem, 0), "vkBindBufferMemory")
        return buf, mem

    pos_size = VERTEX_COUNT * 16  # vec4 = 16 bytes
    col_size = VERTEX_COUNT * 16
    ubo_size = ctypes.sizeof(ParamsUBO)

    bundle.pos_buffer, bundle.pos_memory = create_buffer(pos_size, VK_BUFFER_USAGE_STORAGE_BUFFER_BIT, VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT)
    bundle.col_buffer, bundle.col_memory = create_buffer(col_size, VK_BUFFER_USAGE_STORAGE_BUFFER_BIT, VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT)
    bundle.ubo_buffer, bundle.ubo_memory = create_buffer(ubo_size, VK_BUFFER_USAGE_UNIFORM_BUFFER_BIT, VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | VK_MEMORY_PROPERTY_HOST_COHERENT_BIT)
    log(f"Buffers created: pos={hx(bundle.pos_buffer)} col={hx(bundle.col_buffer)} ubo={hx(bundle.ubo_buffer)}")

    # ---- Descriptor set layout ----
    bindings = (VkDescriptorSetLayoutBinding * 3)()
    # binding 0: positions SSBO
    bindings[0] = VkDescriptorSetLayoutBinding(
        binding=0,
        descriptorType=VK_DESCRIPTOR_TYPE_STORAGE_BUFFER,
        descriptorCount=1,
        stageFlags=VK_SHADER_STAGE_COMPUTE_BIT | VK_SHADER_STAGE_VERTEX_BIT,
        pImmutableSamplers=None,
    )
    # binding 1: colors SSBO
    bindings[1] = VkDescriptorSetLayoutBinding(
        binding=1,
        descriptorType=VK_DESCRIPTOR_TYPE_STORAGE_BUFFER,
        descriptorCount=1,
        stageFlags=VK_SHADER_STAGE_COMPUTE_BIT | VK_SHADER_STAGE_VERTEX_BIT,
        pImmutableSamplers=None,
    )
    # binding 2: UBO
    bindings[2] = VkDescriptorSetLayoutBinding(
        binding=2,
        descriptorType=VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER,
        descriptorCount=1,
        stageFlags=VK_SHADER_STAGE_COMPUTE_BIT,
        pImmutableSamplers=None,
    )

    dslci = VkDescriptorSetLayoutCreateInfo(
        sType=VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
        pNext=None,
        flags=0,
        bindingCount=3,
        pBindings=bindings,
    )
    dsl = VkDescriptorSetLayout(0)
    vk_check(vkCreateDescriptorSetLayout(device, ctypes.byref(dslci), None, ctypes.byref(dsl)), "vkCreateDescriptorSetLayout")
    bundle.descriptor_set_layout = dsl
    log(f"DescriptorSetLayout created: {hx(dsl)}")

    # ---- Descriptor pool ----
    pool_sizes = (VkDescriptorPoolSize * 2)()
    pool_sizes[0] = VkDescriptorPoolSize(type=VK_DESCRIPTOR_TYPE_STORAGE_BUFFER, descriptorCount=2)
    pool_sizes[1] = VkDescriptorPoolSize(type=VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER, descriptorCount=1)

    dpci = VkDescriptorPoolCreateInfo(
        sType=VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO,
        pNext=None,
        flags=0,
        maxSets=1,
        poolSizeCount=2,
        pPoolSizes=pool_sizes,
    )
    dpool = VkDescriptorPool(0)
    vk_check(vkCreateDescriptorPool(device, ctypes.byref(dpci), None, ctypes.byref(dpool)), "vkCreateDescriptorPool")
    bundle.descriptor_pool = dpool

    # ---- Allocate descriptor set ----
    layouts = (VkDescriptorSetLayout * 1)(dsl)
    dsai = VkDescriptorSetAllocateInfo(
        sType=VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO,
        pNext=None,
        descriptorPool=dpool,
        descriptorSetCount=1,
        pSetLayouts=layouts,
    )
    dset = VkDescriptorSet(0)
    vk_check(vkAllocateDescriptorSets(device, ctypes.byref(dsai), ctypes.byref(dset)), "vkAllocateDescriptorSets")
    bundle.descriptor_set = dset

    # ---- Update descriptor set ----
    pos_info = VkDescriptorBufferInfo(buffer=bundle.pos_buffer, offset=0, range=pos_size)
    col_info = VkDescriptorBufferInfo(buffer=bundle.col_buffer, offset=0, range=col_size)
    ubo_info = VkDescriptorBufferInfo(buffer=bundle.ubo_buffer, offset=0, range=ubo_size)

    writes = (VkWriteDescriptorSet * 3)()
    writes[0] = VkWriteDescriptorSet(
        sType=VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET,
        pNext=None,
        dstSet=dset,
        dstBinding=0,
        dstArrayElement=0,
        descriptorCount=1,
        descriptorType=VK_DESCRIPTOR_TYPE_STORAGE_BUFFER,
        pImageInfo=None,
        pBufferInfo=ctypes.pointer(pos_info),
        pTexelBufferView=None,
    )
    writes[1] = VkWriteDescriptorSet(
        sType=VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET,
        pNext=None,
        dstSet=dset,
        dstBinding=1,
        dstArrayElement=0,
        descriptorCount=1,
        descriptorType=VK_DESCRIPTOR_TYPE_STORAGE_BUFFER,
        pImageInfo=None,
        pBufferInfo=ctypes.pointer(col_info),
        pTexelBufferView=None,
    )
    writes[2] = VkWriteDescriptorSet(
        sType=VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET,
        pNext=None,
        dstSet=dset,
        dstBinding=2,
        dstArrayElement=0,
        descriptorCount=1,
        descriptorType=VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER,
        pImageInfo=None,
        pBufferInfo=ctypes.pointer(ubo_info),
        pTexelBufferView=None,
    )
    vkUpdateDescriptorSets(device, 3, writes, 0, None)
    log(f"DescriptorSet updated")

    # ---- Shader modules ----
    comp_mod = _make_shader_module(device, comp_spv)
    vert_mod = _make_shader_module(device, vert_spv)
    frag_mod = _make_shader_module(device, frag_spv)
    log(f"Shader modules: comp={hx(comp_mod)} vert={hx(vert_mod)} frag={hx(frag_mod)}")

    # ---- Compute pipeline ----
    dsl_arr = (VkDescriptorSetLayout * 1)(dsl)
    comp_plci = VkPipelineLayoutCreateInfo(
        sType=VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO,
        pNext=None,
        flags=0,
        setLayoutCount=1,
        pSetLayouts=dsl_arr,
        pushConstantRangeCount=0,
        pPushConstantRanges=None,
    )
    comp_pl = VkPipelineLayout(0)
    vk_check(vkCreatePipelineLayout(device, ctypes.byref(comp_plci), None, ctypes.byref(comp_pl)), "vkCreatePipelineLayout(compute)")
    bundle.compute_pipeline_layout = comp_pl

    comp_stage = VkPipelineShaderStageCreateInfo(
        sType=VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
        pNext=None,
        flags=0,
        stage=VK_SHADER_STAGE_COMPUTE_BIT,
        module=comp_mod,
        pName=b"main",
        pSpecializationInfo=None,
    )
    cpci = VkComputePipelineCreateInfo(
        sType=VK_STRUCTURE_TYPE_COMPUTE_PIPELINE_CREATE_INFO,
        pNext=None,
        flags=0,
        stage=comp_stage,
        layout=comp_pl,
        basePipelineHandle=VkPipeline(0),
        basePipelineIndex=-1,
    )
    comp_pipe = VkPipeline(0)
    vk_check(vkCreateComputePipelines(device, 0, 1, ctypes.byref(cpci), None, ctypes.byref(comp_pipe)), "vkCreateComputePipelines")
    bundle.compute_pipeline = comp_pipe
    log(f"Compute pipeline created: {hx(comp_pipe)}")

    # ---- Graphics pipeline ----
    gfx_plci = VkPipelineLayoutCreateInfo(
        sType=VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO,
        pNext=None,
        flags=0,
        setLayoutCount=1,
        pSetLayouts=dsl_arr,
        pushConstantRangeCount=0,
        pPushConstantRanges=None,
    )
    gfx_pl = VkPipelineLayout(0)
    vk_check(vkCreatePipelineLayout(device, ctypes.byref(gfx_plci), None, ctypes.byref(gfx_pl)), "vkCreatePipelineLayout(graphics)")
    bundle.graphics_pipeline_layout = gfx_pl

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
        topology=VK_PRIMITIVE_TOPOLOGY_LINE_STRIP,
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
        cullMode=VK_CULL_MODE_NONE,
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

    cba = VkPipelineColorBlendAttachmentState(
        blendEnable=0,
        srcColorBlendFactor=0,
        dstColorBlendFactor=0,
        colorBlendOp=0,
        srcAlphaBlendFactor=0,
        dstAlphaBlendFactor=0,
        alphaBlendOp=0,
        colorWriteMask=VK_COLOR_COMPONENT_R_BIT | VK_COLOR_COMPONENT_G_BIT | VK_COLOR_COMPONENT_B_BIT | VK_COLOR_COMPONENT_A_BIT,
    )
    cb = VkPipelineColorBlendStateCreateInfo(
        sType=VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO,
        pNext=None,
        flags=0,
        logicOpEnable=0,
        logicOp=0,
        attachmentCount=1,
        pAttachments=ctypes.pointer(cba),
        blendConstants=(ctypes.c_float * 4)(0.0, 0.0, 0.0, 0.0),
    )

    gpci = VkGraphicsPipelineCreateInfo(
        sType=VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO,
        pNext=None,
        flags=0,
        stageCount=2,
        pStages=stages,
        pVertexInputState=ctypes.pointer(vin),
        pInputAssemblyState=ctypes.pointer(ia),
        pTessellationState=None,
        pViewportState=ctypes.pointer(vp_state),
        pRasterizationState=ctypes.pointer(rs),
        pMultisampleState=ctypes.pointer(ms),
        pDepthStencilState=None,
        pColorBlendState=ctypes.pointer(cb),
        pDynamicState=None,
        layout=gfx_pl,
        renderPass=rp,
        subpass=0,
        basePipelineHandle=VkPipeline(0),
        basePipelineIndex=-1,
    )
    gfx_pipe = VkPipeline(0)
    vk_check(vkCreateGraphicsPipelines(device, 0, 1, ctypes.byref(gpci), None, ctypes.byref(gfx_pipe)), "vkCreateGraphicsPipelines")
    bundle.graphics_pipeline = gfx_pipe
    log(f"Graphics pipeline created: {hx(gfx_pipe)}")

    # Cleanup shader modules
    vkDestroyShaderModule(device, comp_mod, None)
    vkDestroyShaderModule(device, vert_mod, None)
    vkDestroyShaderModule(device, frag_mod, None)

    return bundle

def destroy_bundle(device: VkDevice, bundle: HarmonographBundle) -> None:
    vkDestroyPipeline = _get_dev(device, b"vkDestroyPipeline", None, (VkDevice, VkPipeline, ctypes.c_void_p))
    vkDestroyPipelineLayout = _get_dev(device, b"vkDestroyPipelineLayout", None, (VkDevice, VkPipelineLayout, ctypes.c_void_p))
    vkDestroyFramebuffer = _get_dev(device, b"vkDestroyFramebuffer", None, (VkDevice, VkFramebuffer, ctypes.c_void_p))
    vkDestroyRenderPass = _get_dev(device, b"vkDestroyRenderPass", None, (VkDevice, VkRenderPass, ctypes.c_void_p))
    vkDestroyImageView = _get_dev(device, b"vkDestroyImageView", None, (VkDevice, VkImageView, ctypes.c_void_p))
    vkDestroySwapchainKHR = _get_dev(device, b"vkDestroySwapchainKHR", None, (VkDevice, VkSwapchainKHR, ctypes.c_void_p))
    vkDestroyCommandPool = _get_dev(device, b"vkDestroyCommandPool", None, (VkDevice, VkCommandPool, ctypes.c_void_p))
    vkDestroyBuffer = _get_dev(device, b"vkDestroyBuffer", None, (VkDevice, VkBuffer, ctypes.c_void_p))
    vkFreeMemory = _get_dev(device, b"vkFreeMemory", None, (VkDevice, VkDeviceMemory, ctypes.c_void_p))
    vkDestroyDescriptorPool = _get_dev(device, b"vkDestroyDescriptorPool", None, (VkDevice, VkDescriptorPool, ctypes.c_void_p))
    vkDestroyDescriptorSetLayout = _get_dev(device, b"vkDestroyDescriptorSetLayout", None, (VkDevice, VkDescriptorSetLayout, ctypes.c_void_p))

    if bundle.compute_pipeline:
        vkDestroyPipeline(device, bundle.compute_pipeline, None)
    if bundle.compute_pipeline_layout:
        vkDestroyPipelineLayout(device, bundle.compute_pipeline_layout, None)
    if bundle.graphics_pipeline:
        vkDestroyPipeline(device, bundle.graphics_pipeline, None)
    if bundle.graphics_pipeline_layout:
        vkDestroyPipelineLayout(device, bundle.graphics_pipeline_layout, None)

    if bundle.pos_buffer:
        vkDestroyBuffer(device, bundle.pos_buffer, None)
    if bundle.pos_memory:
        vkFreeMemory(device, bundle.pos_memory, None)
    if bundle.col_buffer:
        vkDestroyBuffer(device, bundle.col_buffer, None)
    if bundle.col_memory:
        vkFreeMemory(device, bundle.col_memory, None)
    if bundle.ubo_buffer:
        vkDestroyBuffer(device, bundle.ubo_buffer, None)
    if bundle.ubo_memory:
        vkFreeMemory(device, bundle.ubo_memory, None)

    if bundle.descriptor_pool:
        vkDestroyDescriptorPool(device, bundle.descriptor_pool, None)
    if bundle.descriptor_set_layout:
        vkDestroyDescriptorSetLayout(device, bundle.descriptor_set_layout, None)

    if bundle.command_pool:
        vkDestroyCommandPool(device, bundle.command_pool, None)

    if bundle.framebuffers:
        for i in range(bundle.image_count):
            if bundle.framebuffers[i]:
                vkDestroyFramebuffer(device, bundle.framebuffers[i], None)

    if bundle.render_pass:
        vkDestroyRenderPass(device, bundle.render_pass, None)

    if bundle.views:
        for i in range(bundle.image_count):
            if bundle.views[i]:
                vkDestroyImageView(device, bundle.views[i], None)

    if bundle.swapchain:
        vkDestroySwapchainKHR(device, bundle.swapchain, None)

# ============================================================
# Sync objects
# ============================================================
class SyncObjects:
    def __init__(self, max_frames: int):
        self.max_frames = max_frames
        self.image_available = [VkSemaphore(0)] * max_frames
        self.render_finished = [VkSemaphore(0)] * max_frames
        self.in_flight = [VkFence(0)] * max_frames

def create_sync_objects(device: VkDevice, max_frames: int) -> SyncObjects:
    vkCreateSemaphore = _get_dev(device, b"vkCreateSemaphore", VkResult, (VkDevice, ctypes.POINTER(VkSemaphoreCreateInfo), ctypes.c_void_p, ctypes.POINTER(VkSemaphore)))
    vkCreateFence = _get_dev(device, b"vkCreateFence", VkResult, (VkDevice, ctypes.POINTER(VkFenceCreateInfo), ctypes.c_void_p, ctypes.POINTER(VkFence)))

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

def recreate_bundle(instance: VkInstance, device: VkDevice, pd: VkPhysicalDevice, surface: VkSurfaceKHR,
                    hwnd, queue_family: int, comp_spv: bytes, vert_spv: bytes, frag_spv: bytes,
                    old: HarmonographBundle) -> HarmonographBundle:
    log("Recreating swapchain...")
    vkDeviceWaitIdle = _get_dev(device, b"vkDeviceWaitIdle", VkResult, (VkDevice,))
    vk_check(vkDeviceWaitIdle(device), "vkDeviceWaitIdle")
    destroy_bundle(device, old)
    return create_bundle(instance, device, pd, surface, hwnd, queue_family, comp_spv, vert_spv, frag_spv)

def destroy_device_and_instance(instance: VkInstance, device: VkDevice, surface: VkSurfaceKHR) -> None:
    vkDestroyDevice = _get_dev(device, b"vkDestroyDevice", None, (VkDevice, ctypes.c_void_p))
    vkDestroySurfaceKHR = _get_inst(instance, b"vkDestroySurfaceKHR", None, (VkInstance, VkSurfaceKHR, ctypes.c_void_p))

    vkDestroyDevice(device, None)
    log("Device destroyed")

    vkDestroySurfaceKHR(instance, surface, None)
    log("Surface destroyed")

    vkDestroyInstance(instance, None)
    log("Instance destroyed")

# ============================================================
# main
# ============================================================
def main() -> None:
    import faulthandler
    faulthandler.enable()

    log("=== START ===")
    log("STEP: Shaderc init")
    shaderc = Shaderc("shaderc_shared.dll")

    log("STEP: Compile shaders")
    comp_spv = shaderc.compile(COMP_SHADER_SRC, Shaderc.COMPUTE, filename="harmonograph.comp")
    log(f"shaderc OK: comp -> {len(comp_spv)} bytes SPIR-V")

    vert_spv = shaderc.compile(VERT_SHADER_SRC, Shaderc.VERTEX, filename="harmonograph.vert")
    log(f"shaderc OK: vert -> {len(vert_spv)} bytes SPIR-V")

    frag_spv = shaderc.compile(FRAG_SHADER_SRC, Shaderc.FRAGMENT, filename="harmonograph.frag")
    log(f"shaderc OK: frag -> {len(frag_spv)} bytes SPIR-V")

    log("STEP: create_window")
    hwnd, hinst = create_window("Vulkan 1.4 Compute Harmonograph (Python + shaderc)", 960, 720)
    log(f"Window created hwnd={hx(hwnd)} hinst={hx(hinst)}")

    log("STEP: vkCreateInstance")
    instance = create_instance()
    log(f"vkCreateInstance OK (instance_ptr={hx(instance)})")

    log("STEP: vkCreateWin32SurfaceKHR")
    surface = create_surface(instance, hwnd, hinst)
    log(f"vkCreateWin32SurfaceKHR OK (surface={hx(surface)})")

    log("STEP: pick_physical_device")
    pd, queue_family = pick_physical_device(instance, surface)
    log(f"Selected physical device pd={hx(pd)} queueFamily={queue_family}")

    log("STEP: vkCreateDevice")
    device, queue = create_device(pd, queue_family)
    log(f"vkCreateDevice OK (device_ptr={hx(device)})")
    log(f"Queue: {hx(queue)}")

    log("STEP: create_bundle")
    bundle = create_bundle(instance, device, pd, surface, hwnd, queue_family, comp_spv, vert_spv, frag_spv)

    log("STEP: create_sync_objects")
    sync = create_sync_objects(device, max_frames=2)

    # Device functions for draw loop
    vkAcquireNextImageKHR = _get_dev(device, b"vkAcquireNextImageKHR", VkResult, (VkDevice, VkSwapchainKHR, ctypes.c_uint64, VkSemaphore, VkFence, ctypes.POINTER(ctypes.c_uint32)))
    vkQueueSubmit         = _get_dev(device, b"vkQueueSubmit", VkResult, (VkQueue, ctypes.c_uint32, ctypes.POINTER(VkSubmitInfo), VkFence))
    vkQueuePresentKHR     = _get_dev(device, b"vkQueuePresentKHR", VkResult, (VkQueue, ctypes.POINTER(VkPresentInfoKHR)))
    vkWaitForFences       = _get_dev(device, b"vkWaitForFences", VkResult, (VkDevice, ctypes.c_uint32, ctypes.POINTER(VkFence), VkBool32, ctypes.c_uint64))
    vkResetFences         = _get_dev(device, b"vkResetFences", VkResult, (VkDevice, ctypes.c_uint32, ctypes.POINTER(VkFence)))
    vkDeviceWaitIdle      = _get_dev(device, b"vkDeviceWaitIdle", VkResult, (VkDevice,))
    vkMapMemory           = _get_dev(device, b"vkMapMemory", VkResult, (VkDevice, VkDeviceMemory, VkDeviceSize, VkDeviceSize, ctypes.c_uint32, ctypes.POINTER(ctypes.c_void_p)))
    vkUnmapMemory         = _get_dev(device, b"vkUnmapMemory", None, (VkDevice, VkDeviceMemory))
    vkResetCommandBuffer  = _get_dev(device, b"vkResetCommandBuffer", VkResult, (VkCommandBuffer, ctypes.c_uint32))
    vkBeginCommandBuffer  = _get_dev(device, b"vkBeginCommandBuffer", VkResult, (VkCommandBuffer, ctypes.POINTER(VkCommandBufferBeginInfo)))
    vkEndCommandBuffer    = _get_dev(device, b"vkEndCommandBuffer", VkResult, (VkCommandBuffer,))
    vkCmdBindPipeline     = _get_dev(device, b"vkCmdBindPipeline", None, (VkCommandBuffer, ctypes.c_uint32, VkPipeline))
    vkCmdBindDescriptorSets = _get_dev(device, b"vkCmdBindDescriptorSets", None, (VkCommandBuffer, ctypes.c_uint32, VkPipelineLayout, ctypes.c_uint32, ctypes.c_uint32, ctypes.POINTER(VkDescriptorSet), ctypes.c_uint32, ctypes.c_void_p))
    vkCmdDispatch         = _get_dev(device, b"vkCmdDispatch", None, (VkCommandBuffer, ctypes.c_uint32, ctypes.c_uint32, ctypes.c_uint32))
    vkCmdPipelineBarrier  = _get_dev(device, b"vkCmdPipelineBarrier", None, (VkCommandBuffer, ctypes.c_uint32, ctypes.c_uint32, ctypes.c_uint32, ctypes.c_uint32, ctypes.c_void_p, ctypes.c_uint32, ctypes.POINTER(VkBufferMemoryBarrier), ctypes.c_uint32, ctypes.c_void_p))
    vkCmdBeginRenderPass  = _get_dev(device, b"vkCmdBeginRenderPass", None, (VkCommandBuffer, ctypes.POINTER(VkRenderPassBeginInfo), ctypes.c_uint32))
    vkCmdEndRenderPass    = _get_dev(device, b"vkCmdEndRenderPass", None, (VkCommandBuffer,))
    vkCmdDraw             = _get_dev(device, b"vkCmdDraw", None, (VkCommandBuffer, ctypes.c_uint32, ctypes.c_uint32, ctypes.c_uint32, ctypes.c_uint32))

    # Params
    params = ParamsUBO()
    params.max_num = VERTEX_COUNT
    params.dt = 0.001
    params.scale = 0.02
    params.pad0 = 0.0
    params.A1 = 50.0; params.f1 = 2.0; params.p1 = 1.0/16.0; params.d1 = 0.02
    params.A2 = 50.0; params.f2 = 2.0; params.p2 = 3.0/2.0;  params.d2 = 0.0315
    params.A3 = 50.0; params.f3 = 2.0; params.p3 = 13.0/15.0; params.d3 = 0.02
    params.A4 = 50.0; params.f4 = 2.0; params.p4 = 1.0;       params.d4 = 0.02

    frame = 0
    anim_time = 0.0
    log("STEP: entering main loop (close the window to exit)")

    global _g_resized
    _g_resized = False

    while True:
        if not pump_messages():
            break
        if _g_should_quit:
            break

        if _g_resized:
            _g_resized = False
            bundle = recreate_bundle(instance, device, pd, surface, hwnd, queue_family, comp_spv, vert_spv, frag_spv, bundle)
            continue

        cur = frame % sync.max_frames

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
            bundle = recreate_bundle(instance, device, pd, surface, hwnd, queue_family, comp_spv, vert_spv, frag_spv, bundle)
            continue
        elif res != VK_SUCCESS and res != VK_SUBOPTIMAL_KHR:
            raise RuntimeError(f"vkAcquireNextImageKHR failed: {res}")

        # Animate params
        anim_time += 0.016
        params.f1 = 2.0 + 0.5 * math.sin(anim_time * 0.7)
        params.f2 = 2.0 + 0.5 * math.sin(anim_time * 0.9)
        params.f3 = 2.0 + 0.5 * math.sin(anim_time * 1.1)
        params.f4 = 2.0 + 0.5 * math.sin(anim_time * 1.3)
        params.p1 += 0.002

        # Update UBO
        ptr = ctypes.c_void_p()
        vk_check(vkMapMemory(device, bundle.ubo_memory, 0, ctypes.sizeof(ParamsUBO), 0, ctypes.byref(ptr)), "vkMapMemory")
        ctypes.memmove(ptr, ctypes.addressof(params), ctypes.sizeof(ParamsUBO))
        vkUnmapMemory(device, bundle.ubo_memory)

        # Record command buffer
        cmd = bundle.command_buffers[image_index.value]
        vk_check(vkResetCommandBuffer(cmd, 0), "vkResetCommandBuffer")

        bi = VkCommandBufferBeginInfo(
            sType=VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
            pNext=None,
            flags=0,
            pInheritanceInfo=None,
        )
        vk_check(vkBeginCommandBuffer(cmd, ctypes.byref(bi)), "vkBeginCommandBuffer")

        # Compute
        vkCmdBindPipeline(cmd, VK_PIPELINE_BIND_POINT_COMPUTE, bundle.compute_pipeline)
        dsets = (VkDescriptorSet * 1)(bundle.descriptor_set)
        vkCmdBindDescriptorSets(cmd, VK_PIPELINE_BIND_POINT_COMPUTE, bundle.compute_pipeline_layout, 0, 1, dsets, 0, None)
        groups_x = (VERTEX_COUNT + 255) // 256
        vkCmdDispatch(cmd, groups_x, 1, 1)

        # Barrier: compute -> vertex
        barriers = (VkBufferMemoryBarrier * 2)()
        barriers[0] = VkBufferMemoryBarrier(
            sType=VK_STRUCTURE_TYPE_BUFFER_MEMORY_BARRIER,
            pNext=None,
            srcAccessMask=VK_ACCESS_SHADER_WRITE_BIT,
            dstAccessMask=VK_ACCESS_SHADER_READ_BIT,
            srcQueueFamilyIndex=VK_QUEUE_FAMILY_IGNORED,
            dstQueueFamilyIndex=VK_QUEUE_FAMILY_IGNORED,
            buffer=bundle.pos_buffer,
            offset=0,
            size=VERTEX_COUNT * 16,
        )
        barriers[1] = VkBufferMemoryBarrier(
            sType=VK_STRUCTURE_TYPE_BUFFER_MEMORY_BARRIER,
            pNext=None,
            srcAccessMask=VK_ACCESS_SHADER_WRITE_BIT,
            dstAccessMask=VK_ACCESS_SHADER_READ_BIT,
            srcQueueFamilyIndex=VK_QUEUE_FAMILY_IGNORED,
            dstQueueFamilyIndex=VK_QUEUE_FAMILY_IGNORED,
            buffer=bundle.col_buffer,
            offset=0,
            size=VERTEX_COUNT * 16,
        )
        vkCmdPipelineBarrier(
            cmd,
            VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT,
            VK_PIPELINE_STAGE_VERTEX_SHADER_BIT,
            0,
            0, None,
            2, barriers,
            0, None,
        )

        # Render pass
        clear = VkClearValue()
        clear.color = VkClearColorValue((ctypes.c_float * 4)(0.0, 0.0, 0.0, 1.0))

        rpbi = VkRenderPassBeginInfo(
            sType=VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO,
            pNext=None,
            renderPass=bundle.render_pass,
            framebuffer=bundle.framebuffers[image_index.value],
            renderArea=VkRect2D(VkOffset2D(0, 0), bundle.extent),
            clearValueCount=1,
            pClearValues=ctypes.pointer(clear),
        )
        vkCmdBeginRenderPass(cmd, ctypes.byref(rpbi), 0)  # VK_SUBPASS_CONTENTS_INLINE = 0

        vkCmdBindPipeline(cmd, VK_PIPELINE_BIND_POINT_GRAPHICS, bundle.graphics_pipeline)
        vkCmdBindDescriptorSets(cmd, VK_PIPELINE_BIND_POINT_GRAPHICS, bundle.graphics_pipeline_layout, 0, 1, dsets, 0, None)
        vkCmdDraw(cmd, VERTEX_COUNT, 1, 0, 0)

        vkCmdEndRenderPass(cmd)

        vk_check(vkEndCommandBuffer(cmd), "vkEndCommandBuffer")

        # Submit
        wait_sems   = (VkSemaphore * 1)(sync.image_available[cur])
        signal_sems = (VkSemaphore * 1)(sync.render_finished[cur])
        wait_stages = (ctypes.c_uint32 * 1)(VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT)
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

        submit_fence = VkFence(sync.in_flight[cur].value)
        vk_check(vkQueueSubmit(queue, 1, ctypes.byref(submit), submit_fence), "vkQueueSubmit")

        # Present
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

        pres_res = vkQueuePresentKHR(queue, ctypes.byref(present))
        if pres_res in (VK_ERROR_OUT_OF_DATE_KHR, VK_SUBOPTIMAL_KHR):
            log(f"vkQueuePresentKHR: {pres_res} -> recreate")
            bundle = recreate_bundle(instance, device, pd, surface, hwnd, queue_family, comp_spv, vert_spv, frag_spv, bundle)
        elif pres_res != VK_SUCCESS:
            raise RuntimeError(f"vkQueuePresentKHR failed: {pres_res}")

        frame += 1

    log("Main loop ended; waiting device idle...")
    vk_check(vkDeviceWaitIdle(device), "vkDeviceWaitIdle")

    destroy_bundle(device, bundle)

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
        main()
    except Exception:
        log("EXCEPTION:")
        raise
