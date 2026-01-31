# -*- coding: utf-8 -*-
"""Vulkan 1.4 Raymarching (Windows, Python, no external Python packages)

Based on the provided hello.py and Hello.cs.
"""

from __future__ import annotations

import os
import sys
import time
import struct  # data packing for PushConstants
import ctypes
from ctypes import wintypes
from pathlib import Path

# ============================================================
# Logging
# ============================================================
_T0 = time.perf_counter()

def log(msg: str) -> None:
    dt = time.perf_counter() - _T0
    print(f"[{dt:8.3f}] {msg}", flush=True)

# ============================================================
# DLL search path setup
# ============================================================
SCRIPT_DIR = Path(__file__).resolve().parent
try:
    os.add_dll_directory(str(SCRIPT_DIR))
except Exception:
    pass

VKSDK = os.environ.get("VULKAN_SDK", "")
VKSDK_BIN = str(Path(VKSDK) / "Bin") if VKSDK and (Path(VKSDK) / "Bin").exists() else ""
if VKSDK_BIN:
    try:
        os.add_dll_directory(VKSDK_BIN)
    except Exception:
        pass

# ============================================================
# Win32 API
# ============================================================
user32 = ctypes.WinDLL("user32", use_last_error=True)
kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)

# Win32 Constants
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

# Win32 Types
for name in ("HICON", "HCURSOR", "HBRUSH", "LRESULT"):
    if not hasattr(wintypes, name): setattr(wintypes, name, wintypes.HANDLE)
LRESULT = getattr(wintypes, "LRESULT", wintypes.LPARAM)

class POINT(ctypes.Structure): _fields_ = [("x", ctypes.c_long), ("y", ctypes.c_long)]
class MSG(ctypes.Structure):
    _fields_ = [("hwnd", wintypes.HWND), ("message", wintypes.UINT),
                ("wParam", wintypes.WPARAM), ("lParam", wintypes.LPARAM),
                ("time", wintypes.DWORD), ("pt", POINT)]
class RECT(ctypes.Structure):
    _fields_ = [("left", ctypes.c_long), ("top", ctypes.c_long),
                ("right", ctypes.c_long), ("bottom", ctypes.c_long)]

WNDPROC = ctypes.WINFUNCTYPE(LRESULT, wintypes.HWND, wintypes.UINT, wintypes.WPARAM, wintypes.LPARAM)

class WNDCLASSEXW(ctypes.Structure):
    _fields_ = [("cbSize", wintypes.UINT), ("style", wintypes.UINT), ("lpfnWndProc", WNDPROC),
                ("cbClsExtra", ctypes.c_int), ("cbWndExtra", ctypes.c_int),
                ("hInstance", wintypes.HINSTANCE), ("hIcon", wintypes.HICON),
                ("hCursor", wintypes.HCURSOR), ("hbrBackground", wintypes.HBRUSH),
                ("lpszMenuName", wintypes.LPCWSTR), ("lpszClassName", wintypes.LPCWSTR),
                ("hIconSm", wintypes.HICON)]

# Win32 Functions
kernel32.GetModuleHandleW.restype, kernel32.GetModuleHandleW.argtypes = wintypes.HMODULE, (wintypes.LPCWSTR,)
user32.DefWindowProcW.restype, user32.DefWindowProcW.argtypes = LRESULT, (wintypes.HWND, wintypes.UINT, wintypes.WPARAM, wintypes.LPARAM)
user32.RegisterClassExW.restype, user32.RegisterClassExW.argtypes = wintypes.ATOM, (ctypes.POINTER(WNDCLASSEXW),)
user32.CreateWindowExW.restype, user32.CreateWindowExW.argtypes = wintypes.HWND, (wintypes.DWORD, wintypes.LPCWSTR, wintypes.LPCWSTR, wintypes.DWORD, ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_int, wintypes.HWND, wintypes.HMENU, wintypes.HINSTANCE, wintypes.LPVOID)
user32.ShowWindow.restype, user32.ShowWindow.argtypes = wintypes.BOOL, (wintypes.HWND, ctypes.c_int)
user32.UpdateWindow.restype, user32.UpdateWindow.argtypes = wintypes.BOOL, (wintypes.HWND,)
user32.PeekMessageW.restype, user32.PeekMessageW.argtypes = wintypes.BOOL, (ctypes.POINTER(MSG), wintypes.HWND, wintypes.UINT, wintypes.UINT, wintypes.UINT)
user32.TranslateMessage.restype, user32.TranslateMessage.argtypes = wintypes.BOOL, (ctypes.POINTER(MSG),)
user32.DispatchMessageW.restype, user32.DispatchMessageW.argtypes = LRESULT, (ctypes.POINTER(MSG),)
user32.PostQuitMessage.restype, user32.PostQuitMessage.argtypes = None, (ctypes.c_int,)
user32.LoadIconW.restype, user32.LoadIconW.argtypes = wintypes.HICON, (wintypes.HINSTANCE, wintypes.LPCWSTR)
user32.LoadCursorW.restype, user32.LoadCursorW.argtypes = wintypes.HCURSOR, (wintypes.HINSTANCE, wintypes.LPCWSTR)
user32.GetClientRect.restype, user32.GetClientRect.argtypes = wintypes.BOOL, (wintypes.HWND, ctypes.POINTER(RECT))

_g_should_quit = False
_g_resized = False
_WNDPROC_REF = None

def _get_client_size(hwnd) -> tuple[int, int]:
    rc = RECT()
    user32.GetClientRect(hwnd, ctypes.byref(rc))
    return max(1, rc.right - rc.left), max(1, rc.bottom - rc.top)

def create_window(title: str, width: int, height: int) -> tuple[wintypes.HWND, wintypes.HINSTANCE]:
    global _WNDPROC_REF, _g_should_quit, _g_resized
    hinst = kernel32.GetModuleHandleW(None)
    
    @WNDPROC
    def wndproc(hwnd, msg, wparam, lparam):
        global _g_should_quit, _g_resized
        if msg in (WM_CLOSE, WM_DESTROY):
            _g_should_quit = True
            user32.PostQuitMessage(0)
            return 0
        if msg == WM_SIZE:
            if (lparam & 0xFFFF) > 0 and ((lparam >> 16) & 0xFFFF) > 0:
                _g_resized = True
            return 0
        return user32.DefWindowProcW(hwnd, msg, wparam, lparam)
    
    _WNDPROC_REF = wndproc
    wc = WNDCLASSEXW()
    wc.cbSize, wc.style, wc.lpfnWndProc = ctypes.sizeof(WNDCLASSEXW), CS_OWNDC, wndproc
    wc.hInstance = hinst
    wc.hIcon = user32.LoadIconW(None, ctypes.c_wchar_p(IDI_APPLICATION))
    wc.hCursor = user32.LoadCursorW(None, ctypes.c_wchar_p(IDC_ARROW))
    wc.lpszClassName = "VkRaymarchingWindow"
    if not user32.RegisterClassExW(ctypes.byref(wc)): raise ctypes.WinError()
    
    hwnd = user32.CreateWindowExW(0, wc.lpszClassName, title, WS_OVERLAPPEDWINDOW,
                                  CW_USEDEFAULT, CW_USEDEFAULT, width, height, None, None, hinst, None)
    if not hwnd: raise ctypes.WinError()
    user32.ShowWindow(hwnd, SW_SHOW)
    user32.UpdateWindow(hwnd)
    return hwnd, hinst

def pump_messages() -> bool:
    msg = MSG()
    while user32.PeekMessageW(ctypes.byref(msg), None, 0, 0, PM_REMOVE):
        if msg.message == WM_QUIT: return False
        user32.TranslateMessage(ctypes.byref(msg))
        user32.DispatchMessageW(ctypes.byref(msg))
    return True

# ============================================================
# Shaderc
# ============================================================
class Shaderc:
    VERTEX, FRAGMENT, STATUS_SUCCESS = 0, 1, 0
    def __init__(self, dll_name="shaderc_shared.dll"):
        p = Path(dll_name).resolve() if Path(dll_name).exists() else (Path(VKSDK_BIN)/dll_name if VKSDK_BIN else SCRIPT_DIR/dll_name)
        self.lib = ctypes.CDLL(str(p))
        self.lib.shaderc_compiler_initialize.restype = ctypes.c_void_p
        self.lib.shaderc_compiler_release.argtypes = [ctypes.c_void_p]
        self.lib.shaderc_compile_options_initialize.restype = ctypes.c_void_p
        self.lib.shaderc_compile_options_release.argtypes = [ctypes.c_void_p]
        self.lib.shaderc_compile_options_set_optimization_level.argtypes = [ctypes.c_void_p, ctypes.c_int]
        self.lib.shaderc_compile_into_spv.restype, self.lib.shaderc_compile_into_spv.argtypes = ctypes.c_void_p, [ctypes.c_void_p, ctypes.c_char_p, ctypes.c_size_t, ctypes.c_int, ctypes.c_char_p, ctypes.c_char_p, ctypes.c_void_p]
        self.lib.shaderc_result_release.argtypes = [ctypes.c_void_p]
        
        self.lib.shaderc_result_get_length.restype = ctypes.c_size_t
        self.lib.shaderc_result_get_length.argtypes = [ctypes.c_void_p]
        
        self.lib.shaderc_result_get_bytes.restype = ctypes.c_void_p
        self.lib.shaderc_result_get_bytes.argtypes = [ctypes.c_void_p]
        
        self.lib.shaderc_result_get_compilation_status.restype = ctypes.c_int
        self.lib.shaderc_result_get_compilation_status.argtypes = [ctypes.c_void_p]
        
        self.lib.shaderc_result_get_error_message.restype = ctypes.c_char_p
        self.lib.shaderc_result_get_error_message.argtypes = [ctypes.c_void_p]

    def compile(self, source: str, kind: int, filename: str) -> bytes:
        c = self.lib.shaderc_compiler_initialize()
        o = self.lib.shaderc_compile_options_initialize()
        self.lib.shaderc_compile_options_set_optimization_level(o, 2)
        try:
            src_b = source.encode("utf-8")
            res = self.lib.shaderc_compile_into_spv(c, src_b, len(src_b), kind, filename.encode("utf-8"), b"main", o)
            if not res: raise RuntimeError("shaderc failed")
            try:
                if self.lib.shaderc_result_get_compilation_status(res) != self.STATUS_SUCCESS:
                    raise RuntimeError(f"Shader error: {self.lib.shaderc_result_get_error_message(res).decode()}")
                return ctypes.string_at(self.lib.shaderc_result_get_bytes(res), self.lib.shaderc_result_get_length(res))
            finally:
                self.lib.shaderc_result_release(res)
        finally:
            self.lib.shaderc_compile_options_release(o)
            self.lib.shaderc_compiler_release(c)

# ============================================================
# Vulkan Definitions
# ============================================================
vk_dll = ctypes.WinDLL("vulkan-1", use_last_error=True)
VkFlags = VkBool32 = ctypes.c_uint32
VkDeviceSize = ctypes.c_uint64
VkResult = ctypes.c_int32
VkInstance = VkPhysicalDevice = VkDevice = VkQueue = VkCommandPool = VkCommandBuffer = ctypes.c_void_p
VkSurfaceKHR = VkSwapchainKHR = VkImage = VkImageView = VkShaderModule = VkRenderPass = VkPipelineLayout = VkPipeline = VkFramebuffer = VkSemaphore = VkFence = ctypes.c_uint64

VK_SUCCESS = 0
VK_ERROR_OUT_OF_DATE_KHR = -1000001004
VK_SUBOPTIMAL_KHR = 1000001003

# Structs
class VkApplicationInfo(ctypes.Structure): _fields_ = [("sType", ctypes.c_uint32), ("pNext", ctypes.c_void_p), ("pApplicationName", ctypes.c_char_p), ("applicationVersion", ctypes.c_uint32), ("pEngineName", ctypes.c_char_p), ("engineVersion", ctypes.c_uint32), ("apiVersion", ctypes.c_uint32)]
class VkInstanceCreateInfo(ctypes.Structure): _fields_ = [("sType", ctypes.c_uint32), ("pNext", ctypes.c_void_p), ("flags", ctypes.c_uint32), ("pApplicationInfo", ctypes.POINTER(VkApplicationInfo)), ("enabledLayerCount", ctypes.c_uint32), ("ppEnabledLayerNames", ctypes.POINTER(ctypes.c_char_p)), ("enabledExtensionCount", ctypes.c_uint32), ("ppEnabledExtensionNames", ctypes.POINTER(ctypes.c_char_p))]
class VkWin32SurfaceCreateInfoKHR(ctypes.Structure): _fields_ = [("sType", ctypes.c_uint32), ("pNext", ctypes.c_void_p), ("flags", ctypes.c_uint32), ("hinstance", wintypes.HINSTANCE), ("hwnd", wintypes.HWND)]
class VkExtent2D(ctypes.Structure): _fields_ = [("width", ctypes.c_uint32), ("height", ctypes.c_uint32)]
class VkExtent3D(ctypes.Structure): _fields_ = [("width", ctypes.c_uint32), ("height", ctypes.c_uint32), ("depth", ctypes.c_uint32)]
class VkSurfaceCapabilitiesKHR(ctypes.Structure): _fields_ = [("minImageCount", ctypes.c_uint32), ("maxImageCount", ctypes.c_uint32), ("currentExtent", VkExtent2D), ("minImageExtent", VkExtent2D), ("maxImageExtent", VkExtent2D), ("maxImageArrayLayers", ctypes.c_uint32), ("supportedTransforms", ctypes.c_uint32), ("currentTransform", ctypes.c_uint32), ("supportedCompositeAlpha", ctypes.c_uint32), ("supportedUsageFlags", ctypes.c_uint32)]
class VkSurfaceFormatKHR(ctypes.Structure): _fields_ = [("format", ctypes.c_uint32), ("colorSpace", ctypes.c_uint32)]
class VkDeviceQueueCreateInfo(ctypes.Structure): _fields_ = [("sType", ctypes.c_uint32), ("pNext", ctypes.c_void_p), ("flags", ctypes.c_uint32), ("queueFamilyIndex", ctypes.c_uint32), ("queueCount", ctypes.c_uint32), ("pQueuePriorities", ctypes.POINTER(ctypes.c_float))]
class VkDeviceCreateInfo(ctypes.Structure): _fields_ = [("sType", ctypes.c_uint32), ("pNext", ctypes.c_void_p), ("flags", ctypes.c_uint32), ("queueCreateInfoCount", ctypes.c_uint32), ("pQueueCreateInfos", ctypes.POINTER(VkDeviceQueueCreateInfo)), ("enabledLayerCount", ctypes.c_uint32), ("ppEnabledLayerNames", ctypes.POINTER(ctypes.c_char_p)), ("enabledExtensionCount", ctypes.c_uint32), ("ppEnabledExtensionNames", ctypes.POINTER(ctypes.c_char_p)), ("pEnabledFeatures", ctypes.c_void_p)]
class VkQueueFamilyProperties(ctypes.Structure): _fields_ = [("queueFlags", ctypes.c_uint32), ("queueCount", ctypes.c_uint32), ("timestampValidBits", ctypes.c_uint32), ("minImageTransferGranularity", VkExtent3D)]
class VkSwapchainCreateInfoKHR(ctypes.Structure): _fields_ = [("sType", ctypes.c_uint32), ("pNext", ctypes.c_void_p), ("flags", ctypes.c_uint32), ("surface", VkSurfaceKHR), ("minImageCount", ctypes.c_uint32), ("imageFormat", ctypes.c_uint32), ("imageColorSpace", ctypes.c_uint32), ("imageExtent", VkExtent2D), ("imageArrayLayers", ctypes.c_uint32), ("imageUsage", ctypes.c_uint32), ("imageSharingMode", ctypes.c_uint32), ("queueFamilyIndexCount", ctypes.c_uint32), ("pQueueFamilyIndices", ctypes.POINTER(ctypes.c_uint32)), ("preTransform", ctypes.c_uint32), ("compositeAlpha", ctypes.c_uint32), ("presentMode", ctypes.c_uint32), ("clipped", VkBool32), ("oldSwapchain", VkSwapchainKHR)]
class VkComponentMapping(ctypes.Structure): _fields_ = [("r", ctypes.c_uint32), ("g", ctypes.c_uint32), ("b", ctypes.c_uint32), ("a", ctypes.c_uint32)]
class VkImageSubresourceRange(ctypes.Structure): _fields_ = [("aspectMask", ctypes.c_uint32), ("baseMipLevel", ctypes.c_uint32), ("levelCount", ctypes.c_uint32), ("baseArrayLayer", ctypes.c_uint32), ("layerCount", ctypes.c_uint32)]
class VkImageViewCreateInfo(ctypes.Structure): _fields_ = [("sType", ctypes.c_uint32), ("pNext", ctypes.c_void_p), ("flags", ctypes.c_uint32), ("image", VkImage), ("viewType", ctypes.c_uint32), ("format", ctypes.c_uint32), ("components", VkComponentMapping), ("subresourceRange", VkImageSubresourceRange)]
class VkAttachmentDescription(ctypes.Structure): _fields_ = [("flags", ctypes.c_uint32), ("format", ctypes.c_uint32), ("samples", ctypes.c_uint32), ("loadOp", ctypes.c_uint32), ("storeOp", ctypes.c_uint32), ("stencilLoadOp", ctypes.c_uint32), ("stencilStoreOp", ctypes.c_uint32), ("initialLayout", ctypes.c_uint32), ("finalLayout", ctypes.c_uint32)]
class VkAttachmentReference(ctypes.Structure): _fields_ = [("attachment", ctypes.c_uint32), ("layout", ctypes.c_uint32)]
class VkSubpassDescription(ctypes.Structure): _fields_ = [("flags", ctypes.c_uint32), ("pipelineBindPoint", ctypes.c_uint32), ("inputAttachmentCount", ctypes.c_uint32), ("pInputAttachments", ctypes.c_void_p), ("colorAttachmentCount", ctypes.c_uint32), ("pColorAttachments", ctypes.POINTER(VkAttachmentReference)), ("pResolveAttachments", ctypes.c_void_p), ("pDepthStencilAttachment", ctypes.c_void_p), ("preserveAttachmentCount", ctypes.c_uint32), ("pPreserveAttachments", ctypes.c_void_p)]
class VkRenderPassCreateInfo(ctypes.Structure): _fields_ = [("sType", ctypes.c_uint32), ("pNext", ctypes.c_void_p), ("flags", ctypes.c_uint32), ("attachmentCount", ctypes.c_uint32), ("pAttachments", ctypes.POINTER(VkAttachmentDescription)), ("subpassCount", ctypes.c_uint32), ("pSubpasses", ctypes.POINTER(VkSubpassDescription)), ("dependencyCount", ctypes.c_uint32), ("pDependencies", ctypes.c_void_p)]
class VkShaderModuleCreateInfo(ctypes.Structure): _fields_ = [("sType", ctypes.c_uint32), ("pNext", ctypes.c_void_p), ("flags", ctypes.c_uint32), ("codeSize", ctypes.c_size_t), ("pCode", ctypes.POINTER(ctypes.c_uint32))]
class VkPipelineShaderStageCreateInfo(ctypes.Structure): _fields_ = [("sType", ctypes.c_uint32), ("pNext", ctypes.c_void_p), ("flags", ctypes.c_uint32), ("stage", ctypes.c_uint32), ("module", VkShaderModule), ("pName", ctypes.c_char_p), ("pSpecializationInfo", ctypes.c_void_p)]
class VkPipelineVertexInputStateCreateInfo(ctypes.Structure): _fields_ = [("sType", ctypes.c_uint32), ("pNext", ctypes.c_void_p), ("flags", ctypes.c_uint32), ("vertexBindingDescriptionCount", ctypes.c_uint32), ("pVertexBindingDescriptions", ctypes.c_void_p), ("vertexAttributeDescriptionCount", ctypes.c_uint32), ("pVertexAttributeDescriptions", ctypes.c_void_p)]
class VkPipelineInputAssemblyStateCreateInfo(ctypes.Structure): _fields_ = [("sType", ctypes.c_uint32), ("pNext", ctypes.c_void_p), ("flags", ctypes.c_uint32), ("topology", ctypes.c_uint32), ("primitiveRestartEnable", VkBool32)]
class VkViewport(ctypes.Structure): _fields_ = [("x", ctypes.c_float), ("y", ctypes.c_float), ("width", ctypes.c_float), ("height", ctypes.c_float), ("minDepth", ctypes.c_float), ("maxDepth", ctypes.c_float)]
class VkOffset2D(ctypes.Structure): _fields_ = [("x", ctypes.c_int32), ("y", ctypes.c_int32)]
class VkRect2D(ctypes.Structure): _fields_ = [("offset", VkOffset2D), ("extent", VkExtent2D)]
class VkPipelineViewportStateCreateInfo(ctypes.Structure): _fields_ = [("sType", ctypes.c_uint32), ("pNext", ctypes.c_void_p), ("flags", ctypes.c_uint32), ("viewportCount", ctypes.c_uint32), ("pViewports", ctypes.POINTER(VkViewport)), ("scissorCount", ctypes.c_uint32), ("pScissors", ctypes.POINTER(VkRect2D))]
class VkPipelineRasterizationStateCreateInfo(ctypes.Structure): _fields_ = [("sType", ctypes.c_uint32), ("pNext", ctypes.c_void_p), ("flags", ctypes.c_uint32), ("depthClampEnable", VkBool32), ("rasterizerDiscardEnable", VkBool32), ("polygonMode", ctypes.c_uint32), ("cullMode", ctypes.c_uint32), ("frontFace", ctypes.c_uint32), ("depthBiasEnable", VkBool32), ("depthBiasConstantFactor", ctypes.c_float), ("depthBiasClamp", ctypes.c_float), ("depthBiasSlopeFactor", ctypes.c_float), ("lineWidth", ctypes.c_float)]
class VkPipelineMultisampleStateCreateInfo(ctypes.Structure): _fields_ = [("sType", ctypes.c_uint32), ("pNext", ctypes.c_void_p), ("flags", ctypes.c_uint32), ("rasterizationSamples", ctypes.c_uint32), ("sampleShadingEnable", VkBool32), ("minSampleShading", ctypes.c_float), ("pSampleMask", ctypes.c_void_p), ("alphaToCoverageEnable", VkBool32), ("alphaToOneEnable", VkBool32)]
class VkPipelineColorBlendAttachmentState(ctypes.Structure): _fields_ = [("blendEnable", VkBool32), ("srcColorBlendFactor", ctypes.c_uint32), ("dstColorBlendFactor", ctypes.c_uint32), ("colorBlendOp", ctypes.c_uint32), ("srcAlphaBlendFactor", ctypes.c_uint32), ("dstAlphaBlendFactor", ctypes.c_uint32), ("alphaBlendOp", ctypes.c_uint32), ("colorWriteMask", ctypes.c_uint32)]
class VkPipelineColorBlendStateCreateInfo(ctypes.Structure): _fields_ = [("sType", ctypes.c_uint32), ("pNext", ctypes.c_void_p), ("flags", ctypes.c_uint32), ("logicOpEnable", VkBool32), ("logicOp", ctypes.c_uint32), ("attachmentCount", ctypes.c_uint32), ("pAttachments", ctypes.POINTER(VkPipelineColorBlendAttachmentState)), ("blendConstants", ctypes.c_float * 4)]
class VkDynamicStateCreateInfo(ctypes.Structure): _fields_ = [("sType", ctypes.c_uint32), ("pNext", ctypes.c_void_p), ("flags", ctypes.c_uint32), ("dynamicStateCount", ctypes.c_uint32), ("pDynamicStates", ctypes.POINTER(ctypes.c_uint32))]
class VkPushConstantRange(ctypes.Structure): _fields_ = [("stageFlags", ctypes.c_uint32), ("offset", ctypes.c_uint32), ("size", ctypes.c_uint32)]
class VkPipelineLayoutCreateInfo(ctypes.Structure): _fields_ = [("sType", ctypes.c_uint32), ("pNext", ctypes.c_void_p), ("flags", ctypes.c_uint32), ("setLayoutCount", ctypes.c_uint32), ("pSetLayouts", ctypes.c_void_p), ("pushConstantRangeCount", ctypes.c_uint32), ("pPushConstantRanges", ctypes.POINTER(VkPushConstantRange))]
class VkGraphicsPipelineCreateInfo(ctypes.Structure): _fields_ = [("sType", ctypes.c_uint32), ("pNext", ctypes.c_void_p), ("flags", ctypes.c_uint32), ("stageCount", ctypes.c_uint32), ("pStages", ctypes.POINTER(VkPipelineShaderStageCreateInfo)), ("pVertexInputState", ctypes.POINTER(VkPipelineVertexInputStateCreateInfo)), ("pInputAssemblyState", ctypes.POINTER(VkPipelineInputAssemblyStateCreateInfo)), ("pTessellationState", ctypes.c_void_p), ("pViewportState", ctypes.POINTER(VkPipelineViewportStateCreateInfo)), ("pRasterizationState", ctypes.POINTER(VkPipelineRasterizationStateCreateInfo)), ("pMultisampleState", ctypes.POINTER(VkPipelineMultisampleStateCreateInfo)), ("pDepthStencilState", ctypes.c_void_p), ("pColorBlendState", ctypes.POINTER(VkPipelineColorBlendStateCreateInfo)), ("pDynamicState", ctypes.POINTER(VkDynamicStateCreateInfo)), ("layout", VkPipelineLayout), ("renderPass", VkRenderPass), ("subpass", ctypes.c_uint32), ("basePipelineHandle", VkPipeline), ("basePipelineIndex", ctypes.c_int32)]
class VkFramebufferCreateInfo(ctypes.Structure): _fields_ = [("sType", ctypes.c_uint32), ("pNext", ctypes.c_void_p), ("flags", ctypes.c_uint32), ("renderPass", VkRenderPass), ("attachmentCount", ctypes.c_uint32), ("pAttachments", ctypes.POINTER(VkImageView)), ("width", ctypes.c_uint32), ("height", ctypes.c_uint32), ("layers", ctypes.c_uint32)]
class VkCommandPoolCreateInfo(ctypes.Structure): _fields_ = [("sType", ctypes.c_uint32), ("pNext", ctypes.c_void_p), ("flags", ctypes.c_uint32), ("queueFamilyIndex", ctypes.c_uint32)]
class VkCommandBufferAllocateInfo(ctypes.Structure): _fields_ = [("sType", ctypes.c_uint32), ("pNext", ctypes.c_void_p), ("commandPool", VkCommandPool), ("level", ctypes.c_uint32), ("commandBufferCount", ctypes.c_uint32)]
class VkCommandBufferBeginInfo(ctypes.Structure): _fields_ = [("sType", ctypes.c_uint32), ("pNext", ctypes.c_void_p), ("flags", ctypes.c_uint32), ("pInheritanceInfo", ctypes.c_void_p)]
class VkClearColorValue(ctypes.Structure): _fields_ = [("float32", ctypes.c_float * 4)]
class VkClearValue(ctypes.Union): _fields_ = [("color", VkClearColorValue)]
class VkRenderPassBeginInfo(ctypes.Structure): _fields_ = [("sType", ctypes.c_uint32), ("pNext", ctypes.c_void_p), ("renderPass", VkRenderPass), ("framebuffer", VkFramebuffer), ("renderArea", VkRect2D), ("clearValueCount", ctypes.c_uint32), ("pClearValues", ctypes.POINTER(VkClearValue))]
class VkSemaphoreCreateInfo(ctypes.Structure): _fields_ = [("sType", ctypes.c_uint32), ("pNext", ctypes.c_void_p), ("flags", ctypes.c_uint32)]
class VkFenceCreateInfo(ctypes.Structure): _fields_ = [("sType", ctypes.c_uint32), ("pNext", ctypes.c_void_p), ("flags", ctypes.c_uint32)]
class VkSubmitInfo(ctypes.Structure): _fields_ = [("sType", ctypes.c_uint32), ("pNext", ctypes.c_void_p), ("waitSemaphoreCount", ctypes.c_uint32), ("pWaitSemaphores", ctypes.POINTER(VkSemaphore)), ("pWaitDstStageMask", ctypes.POINTER(ctypes.c_uint32)), ("commandBufferCount", ctypes.c_uint32), ("pCommandBuffers", ctypes.POINTER(VkCommandBuffer)), ("signalSemaphoreCount", ctypes.c_uint32), ("pSignalSemaphores", ctypes.POINTER(VkSemaphore))]
class VkPresentInfoKHR(ctypes.Structure): _fields_ = [("sType", ctypes.c_uint32), ("pNext", ctypes.c_void_p), ("waitSemaphoreCount", ctypes.c_uint32), ("pWaitSemaphores", ctypes.POINTER(VkSemaphore)), ("swapchainCount", ctypes.c_uint32), ("pSwapchains", ctypes.POINTER(VkSwapchainKHR)), ("pImageIndices", ctypes.POINTER(ctypes.c_uint32)), ("pResults", ctypes.c_void_p)]

# Flags & Enums
# Structure Types
VK_STRUCTURE_TYPE_APPLICATION_INFO = 0
VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO = 1
VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO = 2
VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO = 3
VK_STRUCTURE_TYPE_SUBMIT_INFO = 4
VK_STRUCTURE_TYPE_FENCE_CREATE_INFO = 8
VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO = 9
VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO = 15
VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO = 16
VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO = 18
VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO = 19
VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO = 20
VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO = 22
VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO = 23
VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO = 24
VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO = 26
VK_STRUCTURE_TYPE_PIPELINE_DYNAMIC_STATE_CREATE_INFO = 27
VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO = 28
VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO = 30
VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO = 37
VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO = 38
VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO = 39
VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO = 40
VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO = 42
VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO = 43
VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR = 1000001000
VK_STRUCTURE_TYPE_PRESENT_INFO_KHR = 1000001002
VK_STRUCTURE_TYPE_WIN32_SURFACE_CREATE_INFO_KHR = 1000009000

# Constants
VK_QUEUE_GRAPHICS_BIT = 1
VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT = 2
VK_PIPELINE_BIND_POINT_GRAPHICS = 0
VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST = 3
VK_POLYGON_MODE_FILL = 0
VK_CULL_MODE_NONE = 0
VK_FRONT_FACE_COUNTER_CLOCKWISE = 1
VK_SAMPLE_COUNT_1_BIT = 1
VK_COLOR_COMPONENT_R_BIT = 1; VK_COLOR_COMPONENT_G_BIT = 2; VK_COLOR_COMPONENT_B_BIT = 4; VK_COLOR_COMPONENT_A_BIT = 8
VK_DYNAMIC_STATE_VIEWPORT = 0; VK_DYNAMIC_STATE_SCISSOR = 1
VK_IMAGE_ASPECT_COLOR_BIT = 1
VK_IMAGE_VIEW_TYPE_2D = 1
VK_IMAGE_LAYOUT_UNDEFINED = 0; VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL = 2; VK_IMAGE_LAYOUT_PRESENT_SRC_KHR = 1000001002
VK_ATTACHMENT_LOAD_OP_CLEAR = 1; VK_ATTACHMENT_STORE_OP_STORE = 0
VK_SHARING_MODE_EXCLUSIVE = 0; VK_SHARING_MODE_CONCURRENT = 1
VK_PRESENT_MODE_FIFO_KHR = 2
VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR = 1
VK_SURFACE_TRANSFORM_IDENTITY_BIT_KHR = 1
VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT = 0x00000400
VK_FENCE_CREATE_SIGNALED_BIT = 1
VK_COMMAND_BUFFER_LEVEL_PRIMARY = 0
VK_SHADER_STAGE_VERTEX_BIT = 1; VK_SHADER_STAGE_FRAGMENT_BIT = 16
VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT = 16

# Vulkan Functions
def _func(name, restype, argtypes):
    fn = getattr(vk_dll, name)
    fn.restype, fn.argtypes = restype, argtypes
    return fn

vkGetInstanceProcAddr = _func("vkGetInstanceProcAddr", ctypes.c_void_p, (VkInstance, ctypes.c_char_p))
vkGetDeviceProcAddr = _func("vkGetDeviceProcAddr", ctypes.c_void_p, (VkDevice, ctypes.c_char_p))
vkCreateInstance = _func("vkCreateInstance", VkResult, (ctypes.POINTER(VkInstanceCreateInfo), ctypes.c_void_p, ctypes.POINTER(VkInstance)))
vkEnumeratePhysicalDevices = _func("vkEnumeratePhysicalDevices", VkResult, (VkInstance, ctypes.POINTER(ctypes.c_uint32), ctypes.POINTER(VkPhysicalDevice)))
vkGetPhysicalDeviceQueueFamilyProperties = _func("vkGetPhysicalDeviceQueueFamilyProperties", None, (VkPhysicalDevice, ctypes.POINTER(ctypes.c_uint32), ctypes.POINTER(VkQueueFamilyProperties)))
vkCreateDevice = _func("vkCreateDevice", VkResult, (VkPhysicalDevice, ctypes.POINTER(VkDeviceCreateInfo), ctypes.c_void_p, ctypes.POINTER(VkDevice)))
vkDestroyInstance = _func("vkDestroyInstance", None, (VkInstance, ctypes.c_void_p))
vkDestroyDevice = _func("vkDestroyDevice", None, (VkDevice, ctypes.c_void_p))

def check(res, msg):
    if res != VK_SUCCESS: raise RuntimeError(f"{msg}: {res}")

def get_inst_proc(inst, name, restype, argtypes):
    addr = vkGetInstanceProcAddr(inst, name)
    return ctypes.WINFUNCTYPE(restype, *argtypes)(addr)

def get_dev_proc(dev, name, restype, argtypes):
    addr = vkGetDeviceProcAddr(dev, name)
    return ctypes.WINFUNCTYPE(restype, *argtypes)(addr)

# ============================================================
# Helpers
# ============================================================
class SwapchainBundle:
    def __init__(self):
        self.swapchain = VkSwapchainKHR(0)
        self.format = 0
        self.extent = VkExtent2D(0, 0)
        self.image_count = 0
        self.images, self.views, self.framebuffers, self.command_buffers = None, None, None, None
        self.render_pass = VkRenderPass(0)
        self.pipeline_layout = VkPipelineLayout(0)
        self.pipeline = VkPipeline(0)
        self.command_pool = VkCommandPool()

def create_instance() -> VkInstance:
    exts = (ctypes.c_char_p * 2)(b"VK_KHR_surface", b"VK_KHR_win32_surface")
    app = VkApplicationInfo(VK_STRUCTURE_TYPE_APPLICATION_INFO, None, b"PyRaymarch", 1, b"NoEngine", 1, (1<<22)|(4<<12))
    ici = VkInstanceCreateInfo(VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO, None, 0, ctypes.pointer(app), 0, None, 2, ctypes.cast(exts, ctypes.POINTER(ctypes.c_char_p)))
    inst = VkInstance()
    check(vkCreateInstance(ctypes.byref(ici), None, ctypes.byref(inst)), "vkCreateInstance")
    return inst

def create_device(inst, hwnd):
    # Surface
    vkCreateWin32SurfaceKHR = get_inst_proc(inst, b"vkCreateWin32SurfaceKHR", VkResult, (VkInstance, ctypes.POINTER(VkWin32SurfaceCreateInfoKHR), ctypes.c_void_p, ctypes.POINTER(VkSurfaceKHR)))
    sci = VkWin32SurfaceCreateInfoKHR(VK_STRUCTURE_TYPE_WIN32_SURFACE_CREATE_INFO_KHR, None, 0, kernel32.GetModuleHandleW(None), hwnd)
    surf = VkSurfaceKHR(0)
    check(vkCreateWin32SurfaceKHR(inst, ctypes.byref(sci), None, ctypes.byref(surf)), "vkCreateWin32SurfaceKHR")
    
    # PhysDevice
    count = ctypes.c_uint32(0)
    vkEnumeratePhysicalDevices(inst, ctypes.byref(count), None)
    devs = (VkPhysicalDevice * count.value)()
    vkEnumeratePhysicalDevices(inst, ctypes.byref(count), devs)
    
    vkGetPhysicalDeviceSurfaceSupportKHR = get_inst_proc(inst, b"vkGetPhysicalDeviceSurfaceSupportKHR", VkResult, (VkPhysicalDevice, ctypes.c_uint32, VkSurfaceKHR, ctypes.POINTER(VkBool32)))
    
    pd, gq, pq = None, -1, -1
    for d in devs:
        qcount = ctypes.c_uint32(0)
        vkGetPhysicalDeviceQueueFamilyProperties(d, ctypes.byref(qcount), None)
        props = (VkQueueFamilyProperties * qcount.value)()
        vkGetPhysicalDeviceQueueFamilyProperties(d, ctypes.byref(qcount), props)
        for i, p in enumerate(props):
            if p.queueFlags & VK_QUEUE_GRAPHICS_BIT: gq = i
            sup = VkBool32(0)
            vkGetPhysicalDeviceSurfaceSupportKHR(d, i, surf, ctypes.byref(sup))
            if sup: pq = i
            if gq != -1 and pq != -1: pd = d; break
        if pd: break
    
    # Device
    qs = list({gq, pq})
    qcis = (VkDeviceQueueCreateInfo * len(qs))()
    prio = ctypes.c_float(1.0)
    for i, q in enumerate(qs):
        qcis[i] = VkDeviceQueueCreateInfo(VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO, None, 0, q, 1, ctypes.pointer(prio))
    dexts = (ctypes.c_char_p * 1)(b"VK_KHR_swapchain")
    dci = VkDeviceCreateInfo(VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO, None, 0, len(qs), ctypes.cast(qcis, ctypes.POINTER(VkDeviceQueueCreateInfo)), 0, None, 1, ctypes.cast(dexts, ctypes.POINTER(ctypes.c_char_p)), None)
    dev = VkDevice()
    check(vkCreateDevice(pd, ctypes.byref(dci), None, ctypes.byref(dev)), "vkCreateDevice")
    
    vkGetDeviceQueue = get_dev_proc(dev, b"vkGetDeviceQueue", None, (VkDevice, ctypes.c_uint32, ctypes.c_uint32, ctypes.POINTER(VkQueue)))
    qg, qp = VkQueue(), VkQueue()
    vkGetDeviceQueue(dev, gq, 0, ctypes.byref(qg))
    vkGetDeviceQueue(dev, pq, 0, ctypes.byref(qp))
    
    # Return both handles and indices, explicitly named
    return dev, pd, surf, qg, qp, gq, pq

def create_pipeline(inst, dev, pd, surf, hwnd, gq, pq, vs_spv, fs_spv):
    b = SwapchainBundle()
    
    # Procs
    vkCreateSwapchainKHR = get_dev_proc(dev, b"vkCreateSwapchainKHR", VkResult, (VkDevice, ctypes.POINTER(VkSwapchainCreateInfoKHR), ctypes.c_void_p, ctypes.POINTER(VkSwapchainKHR)))
    vkGetSwapchainImagesKHR = get_dev_proc(dev, b"vkGetSwapchainImagesKHR", VkResult, (VkDevice, VkSwapchainKHR, ctypes.POINTER(ctypes.c_uint32), ctypes.POINTER(VkImage)))
    vkCreateImageView = get_dev_proc(dev, b"vkCreateImageView", VkResult, (VkDevice, ctypes.POINTER(VkImageViewCreateInfo), ctypes.c_void_p, ctypes.POINTER(VkImageView)))
    vkCreateRenderPass = get_dev_proc(dev, b"vkCreateRenderPass", VkResult, (VkDevice, ctypes.POINTER(VkRenderPassCreateInfo), ctypes.c_void_p, ctypes.POINTER(VkRenderPass)))
    vkCreatePipelineLayout = get_dev_proc(dev, b"vkCreatePipelineLayout", VkResult, (VkDevice, ctypes.POINTER(VkPipelineLayoutCreateInfo), ctypes.c_void_p, ctypes.POINTER(VkPipelineLayout)))
    vkCreateGraphicsPipelines = get_dev_proc(dev, b"vkCreateGraphicsPipelines", VkResult, (VkDevice, ctypes.c_uint64, ctypes.c_uint32, ctypes.POINTER(VkGraphicsPipelineCreateInfo), ctypes.c_void_p, ctypes.POINTER(VkPipeline)))
    vkCreateFramebuffer = get_dev_proc(dev, b"vkCreateFramebuffer", VkResult, (VkDevice, ctypes.POINTER(VkFramebufferCreateInfo), ctypes.c_void_p, ctypes.POINTER(VkFramebuffer)))
    vkCreateCommandPool = get_dev_proc(dev, b"vkCreateCommandPool", VkResult, (VkDevice, ctypes.POINTER(VkCommandPoolCreateInfo), ctypes.c_void_p, ctypes.POINTER(VkCommandPool)))
    vkAllocateCommandBuffers = get_dev_proc(dev, b"vkAllocateCommandBuffers", VkResult, (VkDevice, ctypes.POINTER(VkCommandBufferAllocateInfo), ctypes.POINTER(VkCommandBuffer)))
    vkCreateShaderModule = get_dev_proc(dev, b"vkCreateShaderModule", VkResult, (VkDevice, ctypes.POINTER(VkShaderModuleCreateInfo), ctypes.c_void_p, ctypes.POINTER(VkShaderModule)))
    vkDestroyShaderModule = get_dev_proc(dev, b"vkDestroyShaderModule", None, (VkDevice, VkShaderModule, ctypes.c_void_p))
    
    # Swapchain Support
    caps = VkSurfaceCapabilitiesKHR()
    get_inst_proc(inst, b"vkGetPhysicalDeviceSurfaceCapabilitiesKHR", VkResult, (VkPhysicalDevice, VkSurfaceKHR, ctypes.POINTER(VkSurfaceCapabilitiesKHR)))(pd, surf, ctypes.byref(caps))
    
    fmt_count = ctypes.c_uint32(0)
    get_inst_proc(inst, b"vkGetPhysicalDeviceSurfaceFormatsKHR", VkResult, (VkPhysicalDevice, VkSurfaceKHR, ctypes.POINTER(ctypes.c_uint32), ctypes.POINTER(VkSurfaceFormatKHR)))(pd, surf, ctypes.byref(fmt_count), None)
    fmts = (VkSurfaceFormatKHR * fmt_count.value)()
    get_inst_proc(inst, b"vkGetPhysicalDeviceSurfaceFormatsKHR", VkResult, (VkPhysicalDevice, VkSurfaceKHR, ctypes.POINTER(ctypes.c_uint32), ctypes.POINTER(VkSurfaceFormatKHR)))(pd, surf, ctypes.byref(fmt_count), fmts)
    
    sfmt = fmts[0]
    for f in fmts:
        if f.format == 44: sfmt = f; break # VK_FORMAT_B8G8R8A8_UNORM
    
    w, h = _get_client_size(hwnd)
    ext = VkExtent2D(w, h)
    if caps.currentExtent.width != 0xFFFFFFFF: ext = caps.currentExtent
    
    ic = caps.minImageCount + 1
    if caps.maxImageCount > 0: ic = min(ic, caps.maxImageCount)
    
    qidx = (ctypes.c_uint32 * 2)(gq, pq)
    scci = VkSwapchainCreateInfoKHR(VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR, None, 0, surf, ic, sfmt.format, sfmt.colorSpace, ext, 1, VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT, VK_SHARING_MODE_CONCURRENT if gq!=pq else VK_SHARING_MODE_EXCLUSIVE, 2 if gq!=pq else 0, ctypes.cast(qidx, ctypes.POINTER(ctypes.c_uint32)) if gq!=pq else None, caps.currentTransform, VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR, VK_PRESENT_MODE_FIFO_KHR, 1, 0)
    check(vkCreateSwapchainKHR(dev, ctypes.byref(scci), None, ctypes.byref(b.swapchain)), "vkCreateSwapchainKHR")
    
    b.format, b.extent = sfmt.format, ext
    ic_val = ctypes.c_uint32(0)
    vkGetSwapchainImagesKHR(dev, b.swapchain, ctypes.byref(ic_val), None)
    b.images = (VkImage * ic_val.value)()
    vkGetSwapchainImagesKHR(dev, b.swapchain, ctypes.byref(ic_val), b.images)
    b.image_count = ic_val.value
    
    # Views
    b.views = (VkImageView * b.image_count)()
    for i in range(b.image_count):
        ivci = VkImageViewCreateInfo(VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO, None, 0, b.images[i], VK_IMAGE_VIEW_TYPE_2D, b.format, VkComponentMapping(0,0,0,0), VkImageSubresourceRange(VK_IMAGE_ASPECT_COLOR_BIT, 0, 1, 0, 1))
        # Use temp variable for byref
        view_handle = VkImageView(0)
        check(vkCreateImageView(dev, ctypes.byref(ivci), None, ctypes.byref(view_handle)), "vkCreateImageView")
        b.views[i] = view_handle.value
        
    # RenderPass
    att = VkAttachmentDescription(0, b.format, VK_SAMPLE_COUNT_1_BIT, VK_ATTACHMENT_LOAD_OP_CLEAR, VK_ATTACHMENT_STORE_OP_STORE, 0, 0, VK_IMAGE_LAYOUT_UNDEFINED, VK_IMAGE_LAYOUT_PRESENT_SRC_KHR)
    ref = VkAttachmentReference(0, VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL)
    sub = VkSubpassDescription(0, VK_PIPELINE_BIND_POINT_GRAPHICS, 0, None, 1, ctypes.pointer(ref), None, None, 0, None)
    rpci = VkRenderPassCreateInfo(VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO, None, 0, 1, ctypes.pointer(att), 1, ctypes.pointer(sub), 0, None)
    check(vkCreateRenderPass(dev, ctypes.byref(rpci), None, ctypes.byref(b.render_pass)), "vkCreateRenderPass")
    
    # Shaders
    def create_mod(spv):
        pcode = ctypes.cast((ctypes.c_uint32 * (len(spv)//4)).from_buffer_copy(spv), ctypes.POINTER(ctypes.c_uint32))
        info = VkShaderModuleCreateInfo(VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO, None, 0, len(spv), pcode)
        mod = VkShaderModule(0)
        check(vkCreateShaderModule(dev, ctypes.byref(info), None, ctypes.byref(mod)), "vkCreateShaderModule")
        return mod
    
    vmod = create_mod(vs_spv)
    fmod = create_mod(fs_spv)
    
    # Pipeline Layout with Push Constants
    # Layout: offset=0, size=16 (float time, float padding, vec2 res)
    pc_range = VkPushConstantRange(VK_SHADER_STAGE_FRAGMENT_BIT, 0, 16)
    plci = VkPipelineLayoutCreateInfo(VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO, None, 0, 0, None, 1, ctypes.pointer(pc_range))
    check(vkCreatePipelineLayout(dev, ctypes.byref(plci), None, ctypes.byref(b.pipeline_layout)), "vkCreatePipelineLayout")
    
    # Pipeline
    stages = (VkPipelineShaderStageCreateInfo * 2)(
        VkPipelineShaderStageCreateInfo(VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO, None, 0, VK_SHADER_STAGE_VERTEX_BIT, vmod, b"main", None),
        VkPipelineShaderStageCreateInfo(VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO, None, 0, VK_SHADER_STAGE_FRAGMENT_BIT, fmod, b"main", None)
    )
    vis = VkPipelineVertexInputStateCreateInfo(VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO, None, 0, 0, None, 0, None)
    ias = VkPipelineInputAssemblyStateCreateInfo(VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO, None, 0, VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST, 0)
    vp = VkViewport(0, 0, float(b.extent.width), float(b.extent.height), 0, 1)
    sc = VkRect2D(VkOffset2D(0, 0), b.extent)
    vps = VkPipelineViewportStateCreateInfo(VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO, None, 0, 1, ctypes.pointer(vp), 1, ctypes.pointer(sc))
    # Disable cull mode to ensure triangle is visible regardless of winding
    rs = VkPipelineRasterizationStateCreateInfo(VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO, None, 0, 0, 0, VK_POLYGON_MODE_FILL, VK_CULL_MODE_NONE, VK_FRONT_FACE_COUNTER_CLOCKWISE, 0, 0, 0, 0, 1)
    ms = VkPipelineMultisampleStateCreateInfo(VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO, None, 0, VK_SAMPLE_COUNT_1_BIT, 0, 0, None, 0, 0)
    cba = VkPipelineColorBlendAttachmentState(0, 0, 0, 0, 0, 0, 0, 0xF)
    cbs = VkPipelineColorBlendStateCreateInfo(VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO, None, 0, 0, 0, 1, ctypes.pointer(cba), (ctypes.c_float*4)(0,0,0,0))
    dyns = (ctypes.c_uint32 * 2)(VK_DYNAMIC_STATE_VIEWPORT, VK_DYNAMIC_STATE_SCISSOR)
    ds = VkDynamicStateCreateInfo(VK_STRUCTURE_TYPE_PIPELINE_DYNAMIC_STATE_CREATE_INFO, None, 0, 2, ctypes.cast(dyns, ctypes.POINTER(ctypes.c_uint32)))
    
    gpci = VkGraphicsPipelineCreateInfo(VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO, None, 0, 2, ctypes.cast(stages, ctypes.POINTER(VkPipelineShaderStageCreateInfo)), ctypes.pointer(vis), ctypes.pointer(ias), None, ctypes.pointer(vps), ctypes.pointer(rs), ctypes.pointer(ms), None, ctypes.pointer(cbs), ctypes.pointer(ds), b.pipeline_layout, b.render_pass, 0, 0, -1)
    check(vkCreateGraphicsPipelines(dev, 0, 1, ctypes.byref(gpci), None, ctypes.byref(b.pipeline)), "vkCreateGraphicsPipelines")
    
    vkDestroyShaderModule(dev, vmod, None)
    vkDestroyShaderModule(dev, fmod, None)
    
    # Framebuffers
    b.framebuffers = (VkFramebuffer * b.image_count)()
    for i in range(b.image_count):
        atts = (VkImageView * 1)(b.views[i])
        fbci = VkFramebufferCreateInfo(VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO, None, 0, b.render_pass, 1, ctypes.cast(atts, ctypes.POINTER(VkImageView)), b.extent.width, b.extent.height, 1)
        # Use temp variable for byref
        fb_handle = VkFramebuffer(0)
        check(vkCreateFramebuffer(dev, ctypes.byref(fbci), None, ctypes.byref(fb_handle)), "vkCreateFramebuffer")
        b.framebuffers[i] = fb_handle.value
        
    # Command Pool & Buffers
    cpci = VkCommandPoolCreateInfo(VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO, None, VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT, gq)
    check(vkCreateCommandPool(dev, ctypes.byref(cpci), None, ctypes.byref(b.command_pool)), "vkCreateCommandPool")
    
    cbai = VkCommandBufferAllocateInfo(VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO, None, b.command_pool, VK_COMMAND_BUFFER_LEVEL_PRIMARY, b.image_count)
    b.command_buffers = (VkCommandBuffer * b.image_count)()
    check(vkAllocateCommandBuffers(dev, ctypes.byref(cbai), b.command_buffers), "vkAllocateCommandBuffers")
    
    return b

def cleanup_bundle(dev, b):
    vkDestroySwapchainKHR = get_dev_proc(dev, b"vkDestroySwapchainKHR", None, (VkDevice, VkSwapchainKHR, ctypes.c_void_p))
    vkDestroyImageView = get_dev_proc(dev, b"vkDestroyImageView", None, (VkDevice, VkImageView, ctypes.c_void_p))
    vkDestroyRenderPass = get_dev_proc(dev, b"vkDestroyRenderPass", None, (VkDevice, VkRenderPass, ctypes.c_void_p))
    vkDestroyPipelineLayout = get_dev_proc(dev, b"vkDestroyPipelineLayout", None, (VkDevice, VkPipelineLayout, ctypes.c_void_p))
    vkDestroyPipeline = get_dev_proc(dev, b"vkDestroyPipeline", None, (VkDevice, VkPipeline, ctypes.c_void_p))
    vkDestroyFramebuffer = get_dev_proc(dev, b"vkDestroyFramebuffer", None, (VkDevice, VkFramebuffer, ctypes.c_void_p))
    vkDestroyCommandPool = get_dev_proc(dev, b"vkDestroyCommandPool", None, (VkDevice, VkCommandPool, ctypes.c_void_p))
    
    if b.command_pool: vkDestroyCommandPool(dev, b.command_pool, None)
    if b.framebuffers:
        for f in b.framebuffers: vkDestroyFramebuffer(dev, f, None)
    vkDestroyPipeline(dev, b.pipeline, None)
    vkDestroyPipelineLayout(dev, b.pipeline_layout, None)
    vkDestroyRenderPass(dev, b.render_pass, None)
    if b.views:
        for v in b.views: vkDestroyImageView(dev, v, None)
    vkDestroySwapchainKHR(dev, b.swapchain, None)

# ============================================================
# Main
# ============================================================
def main():
    log("Init Window")
    hwnd, hinst = create_window("Vulkan Raymarching (Python)", 800, 600)
    
    log("Init Vulkan")
    inst = create_instance()
    # Explicitly unpack variables to avoid confusion between handle and index
    dev, pd, surf, graphics_queue, present_queue, g_q_idx, p_q_idx = create_device(inst, hwnd)
    
    log("Compile Shaders")
    shaderc = Shaderc()
    
    # Read shader files
    vert_path = SCRIPT_DIR / "hello.vert"
    frag_path = SCRIPT_DIR / "hello.frag"
    
    if not vert_path.exists() or not frag_path.exists():
        log("ERROR: hello.vert or hello.frag not found in script directory.")
        return

    vs_spv = shaderc.compile(vert_path.read_text(encoding="utf-8"), Shaderc.VERTEX, "hello.vert")
    fs_spv = shaderc.compile(frag_path.read_text(encoding="utf-8"), Shaderc.FRAGMENT, "hello.frag")
    log(f"Shaders compiled: VS={len(vs_spv)}B FS={len(fs_spv)}B")
    
    log("Create Pipeline")
    bundle = create_pipeline(inst, dev, pd, surf, hwnd, g_q_idx, p_q_idx, vs_spv, fs_spv)
    
    # Sync objects
    vkCreateSemaphore = get_dev_proc(dev, b"vkCreateSemaphore", VkResult, (VkDevice, ctypes.POINTER(VkSemaphoreCreateInfo), ctypes.c_void_p, ctypes.POINTER(VkSemaphore)))
    vkCreateFence = get_dev_proc(dev, b"vkCreateFence", VkResult, (VkDevice, ctypes.POINTER(VkFenceCreateInfo), ctypes.c_void_p, ctypes.POINTER(VkFence)))
    
    MAX_FRAMES = 2
    sem_img = (VkSemaphore * MAX_FRAMES)()
    sem_rnd = (VkSemaphore * MAX_FRAMES)()
    fences = (VkFence * MAX_FRAMES)()
    
    sci = VkSemaphoreCreateInfo(VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO, None, 0)
    fci = VkFenceCreateInfo(VK_STRUCTURE_TYPE_FENCE_CREATE_INFO, None, VK_FENCE_CREATE_SIGNALED_BIT)
    for i in range(MAX_FRAMES):
        # Use temp vars for Sync Object creation
        s1 = VkSemaphore(0)
        vkCreateSemaphore(dev, ctypes.byref(sci), None, ctypes.byref(s1))
        sem_img[i] = s1.value
        
        s2 = VkSemaphore(0)
        vkCreateSemaphore(dev, ctypes.byref(sci), None, ctypes.byref(s2))
        sem_rnd[i] = s2.value
        
        f = VkFence(0)
        vkCreateFence(dev, ctypes.byref(fci), None, ctypes.byref(f))
        fences[i] = f.value

    # Loop Procs
    vkAcquireNextImageKHR = get_dev_proc(dev, b"vkAcquireNextImageKHR", VkResult, (VkDevice, VkSwapchainKHR, ctypes.c_uint64, VkSemaphore, VkFence, ctypes.POINTER(ctypes.c_uint32)))
    vkWaitForFences = get_dev_proc(dev, b"vkWaitForFences", VkResult, (VkDevice, ctypes.c_uint32, ctypes.POINTER(VkFence), VkBool32, ctypes.c_uint64))
    vkResetFences = get_dev_proc(dev, b"vkResetFences", VkResult, (VkDevice, ctypes.c_uint32, ctypes.POINTER(VkFence)))
    vkQueueSubmit = get_dev_proc(dev, b"vkQueueSubmit", VkResult, (VkQueue, ctypes.c_uint32, ctypes.POINTER(VkSubmitInfo), VkFence))
    vkQueuePresentKHR = get_dev_proc(dev, b"vkQueuePresentKHR", VkResult, (VkQueue, ctypes.POINTER(VkPresentInfoKHR)))
    vkDeviceWaitIdle = get_dev_proc(dev, b"vkDeviceWaitIdle", VkResult, (VkDevice,))
    
    # Command Recording Procs
    vkBeginCommandBuffer = get_dev_proc(dev, b"vkBeginCommandBuffer", VkResult, (VkCommandBuffer, ctypes.POINTER(VkCommandBufferBeginInfo)))
    vkEndCommandBuffer = get_dev_proc(dev, b"vkEndCommandBuffer", VkResult, (VkCommandBuffer,))
    vkCmdBeginRenderPass = get_dev_proc(dev, b"vkCmdBeginRenderPass", None, (VkCommandBuffer, ctypes.POINTER(VkRenderPassBeginInfo), ctypes.c_uint32))
    vkCmdEndRenderPass = get_dev_proc(dev, b"vkCmdEndRenderPass", None, (VkCommandBuffer,))
    vkCmdBindPipeline = get_dev_proc(dev, b"vkCmdBindPipeline", None, (VkCommandBuffer, ctypes.c_uint32, VkPipeline))
    vkCmdDraw = get_dev_proc(dev, b"vkCmdDraw", None, (VkCommandBuffer, ctypes.c_uint32, ctypes.c_uint32, ctypes.c_uint32, ctypes.c_uint32))
    vkCmdSetViewport = get_dev_proc(dev, b"vkCmdSetViewport", None, (VkCommandBuffer, ctypes.c_uint32, ctypes.c_uint32, ctypes.POINTER(VkViewport)))
    vkCmdSetScissor = get_dev_proc(dev, b"vkCmdSetScissor", None, (VkCommandBuffer, ctypes.c_uint32, ctypes.c_uint32, ctypes.POINTER(VkRect2D)))
    vkCmdPushConstants = get_dev_proc(dev, b"vkCmdPushConstants", None, (VkCommandBuffer, VkPipelineLayout, ctypes.c_uint32, ctypes.c_uint32, ctypes.c_uint32, ctypes.c_void_p))
    vkResetCommandBuffer = get_dev_proc(dev, b"vkResetCommandBuffer", VkResult, (VkCommandBuffer, ctypes.c_uint32))

    log("Loop Start")
    frame = 0
    start_time = time.perf_counter()
    
    global _g_resized
    _g_resized = False

    try:
        while pump_messages():
            if _g_should_quit: break
            
            if _g_resized:
                _g_resized = False
                vkDeviceWaitIdle(dev)
                cleanup_bundle(dev, bundle)
                bundle = create_pipeline(inst, dev, pd, surf, hwnd, g_q_idx, p_q_idx, vs_spv, fs_spv)
                continue

            fi = frame % MAX_FRAMES
            fence_ptr = (VkFence*1)(fences[fi])
            
            vkWaitForFences(dev, 1, fence_ptr, 1, 0xFFFFFFFFFFFFFFFF)
            
            img_idx = ctypes.c_uint32(0)
            res = vkAcquireNextImageKHR(dev, bundle.swapchain, 0xFFFFFFFFFFFFFFFF, sem_img[fi], 0, ctypes.byref(img_idx))
            
            if res == VK_ERROR_OUT_OF_DATE_KHR:
                _g_resized = True
                continue
            elif res != VK_SUCCESS and res != VK_SUBOPTIMAL_KHR:
                raise RuntimeError("Acquire failed")
            
            vkResetFences(dev, 1, fence_ptr)
            
            # Record Command Buffer for this frame
            cmd = bundle.command_buffers[img_idx.value]
            vkResetCommandBuffer(cmd, 0)
            
            bi = VkCommandBufferBeginInfo(VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO, None, 0, None)
            vkBeginCommandBuffer(cmd, ctypes.byref(bi))
            
            clr = VkClearValue(VkClearColorValue((ctypes.c_float*4)(0,0,0,1)))
            rpbi = VkRenderPassBeginInfo(VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO, None, bundle.render_pass, bundle.framebuffers[img_idx.value], VkRect2D(VkOffset2D(0,0), bundle.extent), 1, ctypes.pointer(clr))
            
            vkCmdBeginRenderPass(cmd, ctypes.byref(rpbi), 0)
            vkCmdBindPipeline(cmd, VK_PIPELINE_BIND_POINT_GRAPHICS, bundle.pipeline)
            
            vp = VkViewport(0, 0, float(bundle.extent.width), float(bundle.extent.height), 0, 1)
            sc = VkRect2D(VkOffset2D(0, 0), bundle.extent)
            vkCmdSetViewport(cmd, 0, 1, ctypes.byref(vp))
            vkCmdSetScissor(cmd, 0, 1, ctypes.byref(sc))
            
            # Push Constants: Time, Padding, ResX, ResY
            cur_time = time.perf_counter() - start_time
            pc_data = struct.pack('<ffff', cur_time, 0.0, float(bundle.extent.width), float(bundle.extent.height))
            # Create a buffer for the data to ensure it's passed as a void pointer
            pc_buf = (ctypes.c_char * len(pc_data)).from_buffer_copy(pc_data)
            vkCmdPushConstants(cmd, bundle.pipeline_layout, VK_SHADER_STAGE_FRAGMENT_BIT, 0, 16, ctypes.byref(pc_buf))
            
            vkCmdDraw(cmd, 3, 1, 0, 0)
            vkCmdEndRenderPass(cmd)
            vkEndCommandBuffer(cmd)
            
            # Submit
            # Construct arrays for submission
            wait_sems = (VkSemaphore * 1)(sem_img[fi])
            sig_sems = (VkSemaphore * 1)(sem_rnd[fi])
            cmd_bufs = (VkCommandBuffer * 1)(cmd)
            wait_stages = (ctypes.c_uint32 * 1)(VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT)
            
            si = VkSubmitInfo(VK_STRUCTURE_TYPE_SUBMIT_INFO, None, 1, 
                              ctypes.cast(wait_sems, ctypes.POINTER(VkSemaphore)), 
                              ctypes.cast(wait_stages, ctypes.POINTER(ctypes.c_uint32)), 
                              1, 
                              ctypes.cast(cmd_bufs, ctypes.POINTER(VkCommandBuffer)), 
                              1, 
                              ctypes.cast(sig_sems, ctypes.POINTER(VkSemaphore)))
            
            # Use graphics_queue handle (not index)
            vkQueueSubmit(graphics_queue, 1, ctypes.byref(si), fences[fi])
            
            # Present
            swaps = (VkSwapchainKHR*1)(bundle.swapchain)
            idxs = (ctypes.c_uint32*1)(img_idx.value)
            
            pi = VkPresentInfoKHR(VK_STRUCTURE_TYPE_PRESENT_INFO_KHR, None, 1, 
                                  ctypes.cast(sig_sems, ctypes.POINTER(VkSemaphore)), 
                                  1, 
                                  ctypes.cast(swaps, ctypes.POINTER(VkSwapchainKHR)), 
                                  ctypes.cast(idxs, ctypes.POINTER(ctypes.c_uint32)), None)
            
            # Use present_queue handle
            pres = vkQueuePresentKHR(present_queue, ctypes.byref(pi))
            
            if pres == VK_ERROR_OUT_OF_DATE_KHR or pres == VK_SUBOPTIMAL_KHR:
                _g_resized = True
            
            frame += 1

    except KeyboardInterrupt:
        pass
    finally:
        vkDeviceWaitIdle(dev)
        cleanup_bundle(dev, bundle)
        vkDestroySemaphore = get_dev_proc(dev, b"vkDestroySemaphore", None, (VkDevice, VkSemaphore, ctypes.c_void_p))
        vkDestroyFence = get_dev_proc(dev, b"vkDestroyFence", None, (VkDevice, VkFence, ctypes.c_void_p))
        for i in range(MAX_FRAMES):
            vkDestroySemaphore(dev, sem_img[i], None)
            vkDestroySemaphore(dev, sem_rnd[i], None)
            vkDestroyFence(dev, fences[i], None)
        
        get_inst_proc(inst, b"vkDestroySurfaceKHR", None, (VkInstance, VkSurfaceKHR, ctypes.c_void_p))(inst, surf, None)
        vkDestroyDevice(dev, None)
        vkDestroyInstance(inst, None)
        log("Done")

if __name__ == "__main__":
    main()
