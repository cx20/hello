# -*- coding: utf-8 -*-
"""OpenGL + D3D11 + Vulkan Triangles via DirectComposition (Python, ctypes only)

Three panels in one window, each rendered by a different graphics API:
  Panel 0 (left):   OpenGL 4.6 via WGL_NV_DX_interop2
  Panel 1 (center): D3D11 (native)
  Panel 2 (right):  Vulkan (offscreen -> staging -> D3D11 copy)

All COM interfaces (D3D11, DXGI, DirectComposition) are called via raw
vtable indexing through ctypes — no comtypes or external packages.

Requirements:
  - Windows 8+ (DirectComposition)
  - NVIDIA/AMD/Intel GPU supporting WGL_NV_DX_interop2
  - Vulkan SDK (for vulkan-1.dll + shaderc_shared.dll)
  - hello.vert / hello.frag in same folder (for Vulkan SPIR-V compilation)

Build: Just run with Python 3.10+
  python hello_dcomp_multi.py
"""

from __future__ import annotations
import os, sys, time, ctypes, struct
from ctypes import wintypes
from pathlib import Path

# ============================================================
# Logging
# ============================================================
_T0 = time.perf_counter()
def log(msg: str) -> None:
    print(f"[{time.perf_counter()-_T0:8.3f}] {msg}", flush=True)

def hx(h) -> str:
    v = getattr(h, "value", h)
    if v is None: return "(null)"
    try: return f"0x{int(v):X}"
    except: return str(v)

# ============================================================
# DLL search paths
# ============================================================
SCRIPT_DIR = Path(__file__).resolve().parent
try: os.add_dll_directory(str(SCRIPT_DIR))
except: pass
VKSDK = os.environ.get("VULKAN_SDK", "")
if VKSDK:
    b = Path(VKSDK) / "Bin"
    if b.exists():
        try: os.add_dll_directory(str(b))
        except: pass

# ============================================================
# Win32 basics
# ============================================================
for n in ("HICON","HCURSOR","HBRUSH","LRESULT"):
    if not hasattr(wintypes, n): setattr(wintypes, n, wintypes.HANDLE)
LRESULT = getattr(wintypes, "LRESULT", wintypes.LPARAM)

user32   = ctypes.WinDLL("user32", use_last_error=True)
kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
gdi32    = ctypes.WinDLL("gdi32", use_last_error=True)

CS_OWNDC = 0x20; WS_OVERLAPPEDWINDOW = 0xCF0000; CW_USEDEFAULT = 0x80000000
SW_SHOW = 5; WM_DESTROY = 2; WM_CLOSE = 0x10; WM_QUIT = 0x12
WM_KEYDOWN = 0x100; VK_ESCAPE = 0x1B; PM_REMOVE = 1

class POINT(ctypes.Structure): _fields_ = [("x",ctypes.c_long),("y",ctypes.c_long)]
class MSG(ctypes.Structure):
    _fields_ = [("hwnd",wintypes.HWND),("message",wintypes.UINT),("wParam",wintypes.WPARAM),
                ("lParam",wintypes.LPARAM),("time",wintypes.DWORD),("pt",POINT)]
class RECT(ctypes.Structure):
    _fields_ = [("left",ctypes.c_long),("top",ctypes.c_long),("right",ctypes.c_long),("bottom",ctypes.c_long)]

WNDPROC = ctypes.WINFUNCTYPE(LRESULT, wintypes.HWND, wintypes.UINT, wintypes.WPARAM, wintypes.LPARAM)

class WNDCLASSEXW(ctypes.Structure):
    _fields_ = [("cbSize",wintypes.UINT),("style",wintypes.UINT),("lpfnWndProc",WNDPROC),
                ("cbClsExtra",ctypes.c_int),("cbWndExtra",ctypes.c_int),("hInstance",wintypes.HINSTANCE),
                ("hIcon",wintypes.HICON),("hCursor",wintypes.HCURSOR),("hbrBackground",wintypes.HBRUSH),
                ("lpszMenuName",wintypes.LPCWSTR),("lpszClassName",wintypes.LPCWSTR),("hIconSm",wintypes.HICON)]

kernel32.GetModuleHandleW.restype = wintypes.HMODULE; kernel32.GetModuleHandleW.argtypes = (wintypes.LPCWSTR,)
user32.DefWindowProcW.restype = LRESULT; user32.DefWindowProcW.argtypes = (wintypes.HWND,wintypes.UINT,wintypes.WPARAM,wintypes.LPARAM)
user32.RegisterClassExW.restype = wintypes.ATOM; user32.RegisterClassExW.argtypes = (ctypes.POINTER(WNDCLASSEXW),)
user32.CreateWindowExW.restype = wintypes.HWND
user32.CreateWindowExW.argtypes = (wintypes.DWORD,wintypes.LPCWSTR,wintypes.LPCWSTR,wintypes.DWORD,ctypes.c_int,ctypes.c_int,ctypes.c_int,ctypes.c_int,wintypes.HWND,wintypes.HMENU,wintypes.HINSTANCE,wintypes.LPVOID)
user32.ShowWindow.argtypes = (wintypes.HWND,ctypes.c_int)
user32.PeekMessageW.restype = wintypes.BOOL; user32.PeekMessageW.argtypes = (ctypes.POINTER(MSG),wintypes.HWND,wintypes.UINT,wintypes.UINT,wintypes.UINT)
user32.TranslateMessage.argtypes = (ctypes.POINTER(MSG),)
user32.DispatchMessageW.argtypes = (ctypes.POINTER(MSG),)
user32.PostQuitMessage.argtypes = (ctypes.c_int,)
user32.LoadCursorW.restype = wintypes.HCURSOR; user32.LoadCursorW.argtypes = (wintypes.HINSTANCE,wintypes.LPCWSTR)
user32.AdjustWindowRect.restype = wintypes.BOOL; user32.AdjustWindowRect.argtypes = (ctypes.POINTER(RECT),wintypes.DWORD,wintypes.BOOL)
user32.DestroyWindow.argtypes = (wintypes.HWND,)

# ============================================================
# COM vtable helper
# ============================================================
def com_call(obj, vtbl_idx, restype, *args):
    """Call a COM method by vtable index. obj is a ctypes c_void_p (COM pointer)."""
    vtbl_pp = ctypes.cast(obj, ctypes.POINTER(ctypes.POINTER(ctypes.c_void_p)))
    fn_ptr = vtbl_pp[0][vtbl_idx]
    def _safe_argtype(a):
        t = type(a)
        # ctypes.byref(...) returns a CArgObject whose type is not valid in argtypes.
        # Fall back to void* for such adapter objects.
        return t if hasattr(t, "from_param") else ctypes.c_void_p
    arg_types = [ctypes.c_void_p] + [_safe_argtype(a) for a in args]  # this + args
    ftype = ctypes.WINFUNCTYPE(restype, *arg_types)
    return ftype(fn_ptr)(obj, *args)

def com_release(obj):
    """IUnknown::Release (vtbl index 2)"""
    if obj:
        com_call(obj, 2, ctypes.c_ulong)

def com_qi(obj, iid_bytes):
    """IUnknown::QueryInterface (vtbl index 0)"""
    out = ctypes.c_void_p(0)
    iid = (ctypes.c_byte * 16)(*iid_bytes)
    hr = com_call(obj, 0, ctypes.c_long, ctypes.cast(iid, ctypes.c_void_p), ctypes.byref(out))
    if hr < 0:
        raise RuntimeError(f"QueryInterface failed: 0x{hr & 0xFFFFFFFF:08X}")
    return out

def iid_bytes(s: str) -> bytes:
    """Convert GUID string 'XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX' to 16 bytes (LE)."""
    import uuid
    return uuid.UUID(s).bytes_le

# GUIDs
IID_IDXGIDevice   = iid_bytes("54ec77fa-1377-44e6-8c32-88fd5f44c84c")
IID_IDXGIAdapter  = iid_bytes("2411e7e1-12ac-4ccf-bd14-9798e8534dc0")
IID_IDXGIFactory2 = iid_bytes("50c83a1c-e072-4c48-87b0-3630fa36a6d0")
IID_ID3D11Texture2D = iid_bytes("6f15aaf2-d208-4e89-9ab4-489535d34f9c")

# ============================================================
# Constants
# ============================================================
PANEL_W, PANEL_H = 320, 480
WINDOW_W, WINDOW_H = PANEL_W * 3, PANEL_H

# ============================================================
# D3D11 / DXGI DLL imports
# ============================================================
d3d11_dll = ctypes.WinDLL("d3d11")
dxgi_dll  = ctypes.WinDLL("dxgi")
dcomp_dll = ctypes.WinDLL("dcomp")
d3dc_dll  = ctypes.WinDLL("d3dcompiler_47")
gl_dll    = ctypes.WinDLL("opengl32")

# D3D11CreateDevice
d3d11_dll.D3D11CreateDevice.restype = ctypes.c_long
d3d11_dll.D3D11CreateDevice.argtypes = (
    ctypes.c_void_p, ctypes.c_uint, ctypes.c_void_p, ctypes.c_uint,
    ctypes.POINTER(ctypes.c_uint), ctypes.c_uint, ctypes.c_uint,
    ctypes.POINTER(ctypes.c_void_p), ctypes.POINTER(ctypes.c_uint), ctypes.POINTER(ctypes.c_void_p))

# DCompositionCreateDevice
dcomp_dll.DCompositionCreateDevice.restype = ctypes.c_long
dcomp_dll.DCompositionCreateDevice.argtypes = (ctypes.c_void_p, ctypes.c_void_p, ctypes.POINTER(ctypes.c_void_p))

# D3DCompile
d3dc_dll.D3DCompile.restype = ctypes.c_long
d3dc_dll.D3DCompile.argtypes = (ctypes.c_void_p,ctypes.c_size_t,ctypes.c_char_p,ctypes.c_void_p,ctypes.c_void_p,ctypes.c_char_p,ctypes.c_char_p,ctypes.c_uint,ctypes.c_uint,ctypes.POINTER(ctypes.c_void_p),ctypes.POINTER(ctypes.c_void_p))

# ============================================================
# DXGI structs
# ============================================================
class DXGI_SAMPLE_DESC(ctypes.Structure): _fields_ = [("Count",ctypes.c_uint),("Quality",ctypes.c_uint)]
class DXGI_SWAP_CHAIN_DESC1(ctypes.Structure):
    _fields_ = [("Width",ctypes.c_uint),("Height",ctypes.c_uint),("Format",ctypes.c_uint),
                ("Stereo",wintypes.BOOL),("SampleDesc",DXGI_SAMPLE_DESC),("BufferUsage",ctypes.c_uint),
                ("BufferCount",ctypes.c_uint),("Scaling",ctypes.c_uint),("SwapEffect",ctypes.c_uint),
                ("AlphaMode",ctypes.c_uint),("Flags",ctypes.c_uint)]
class D3D11_TEXTURE2D_DESC(ctypes.Structure):
    _fields_ = [("Width",ctypes.c_uint),("Height",ctypes.c_uint),("MipLevels",ctypes.c_uint),
                ("ArraySize",ctypes.c_uint),("Format",ctypes.c_uint),("SampleDesc",DXGI_SAMPLE_DESC),
                ("Usage",ctypes.c_uint),("BindFlags",ctypes.c_uint),("CPUAccessFlags",ctypes.c_uint),
                ("MiscFlags",ctypes.c_uint)]
class D3D11_MAPPED_SUBRESOURCE(ctypes.Structure):
    _fields_ = [("pData",ctypes.c_void_p),("RowPitch",ctypes.c_uint),("DepthPitch",ctypes.c_uint)]

# DXGI formats / constants
DXGI_FORMAT_B8G8R8A8_UNORM = 87
DXGI_USAGE_RENDER_TARGET_OUTPUT = 0x20
DXGI_SWAP_EFFECT_FLIP_SEQUENTIAL = 3
DXGI_ALPHA_MODE_PREMULTIPLIED = 1
D3D11_SDK_VERSION = 7
D3D_FEATURE_LEVEL_11_0 = 0xb000
D3D11_CREATE_DEVICE_BGRA_SUPPORT = 0x20
D3D11_USAGE_STAGING = 3
D3D11_CPU_ACCESS_WRITE = 0x10000
D3D11_MAP_WRITE = 2

# COM vtable indices (counted from header definitions)
# IDXGIObject: 0=QI 1=AddRef 2=Release 3=SetPrivateData 4=SetPDInterface 5=GetPrivateData 6=GetParent
# IDXGIDevice(extends IDXGIObject): 7=GetAdapter
# IDXGIFactory2(extends IDXGIFactory1→Factory→Object): 24=CreateSwapChainForComposition
# IDXGISwapChain(extends IDXGIDeviceSubObject→Object): 8=Present 9=GetBuffer
# ID3D11Device: 5=CreateTexture2D 9=CreateRTV 11=CreateInputLayout 12=CreateVS 15=CreatePS
# ID3D11DeviceContext: 9=PSSetShader 11=VSSetShader 13=Draw 14=Map 15=Unmap
#   17=IASetInputLayout 18=IASetVertexBuffers 24=IASetPrimitiveTopology
#   33=OMSetRenderTargets 44=RSSetViewports 47=CopyResource 50=ClearRTV
# IDCompositionDevice: 3=Commit 6=CreateTargetForHwnd 7=CreateVisual
# IDCompositionTarget: 3=SetRoot
# IDCompositionVisual: 4=SetOffsetX(float) 6=SetOffsetY(float) 15=SetContent 16=AddVisual

# ============================================================
# Global state
# ============================================================
g_hwnd = None
g_d3d_device = ctypes.c_void_p(0)
g_d3d_ctx    = ctypes.c_void_p(0)
g_dcomp_dev  = ctypes.c_void_p(0)
g_dcomp_tgt  = ctypes.c_void_p(0)
g_root_vis   = ctypes.c_void_p(0)

_WNDPROC_REF = None
_g_quit = False

# ============================================================
# Create window
# ============================================================
def create_window():
    global _WNDPROC_REF, _g_quit, g_hwnd
    hinst = kernel32.GetModuleHandleW(None)
    @WNDPROC
    def wndproc(hw, msg, wp, lp):
        global _g_quit
        if msg == WM_DESTROY or msg == WM_CLOSE:
            _g_quit = True; user32.PostQuitMessage(0); return 0
        if msg == WM_KEYDOWN and wp == VK_ESCAPE:
            _g_quit = True; user32.PostQuitMessage(0); return 0
        return user32.DefWindowProcW(hw, msg, wp, lp)
    _WNDPROC_REF = wndproc
    wc = WNDCLASSEXW(); wc.cbSize = ctypes.sizeof(WNDCLASSEXW)
    wc.style = CS_OWNDC; wc.lpfnWndProc = wndproc; wc.hInstance = hinst
    wc.hCursor = user32.LoadCursorW(None, ctypes.c_wchar_p(32512))
    wc.hbrBackground = gdi32.GetStockObject(4)  # BLACK_BRUSH
    wc.lpszClassName = "DCompMultiPy"
    user32.RegisterClassExW(ctypes.byref(wc))
    rc = RECT(0, 0, WINDOW_W, WINDOW_H)
    user32.AdjustWindowRect(ctypes.byref(rc), WS_OVERLAPPEDWINDOW, 0)
    g_hwnd = user32.CreateWindowExW(0, "DCompMultiPy",
        "OpenGL + D3D11 + Vulkan (DirectComposition / Python)",
        WS_OVERLAPPEDWINDOW, CW_USEDEFAULT, CW_USEDEFAULT,
        rc.right - rc.left, rc.bottom - rc.top, None, None, hinst, None)
    user32.ShowWindow(g_hwnd, SW_SHOW)
    log(f"Window created: {hx(g_hwnd)}")
    return hinst

# ============================================================
# Create shared D3D11 device
# ============================================================
def create_d3d11_device():
    global g_d3d_device, g_d3d_ctx
    level = (ctypes.c_uint * 1)(D3D_FEATURE_LEVEL_11_0)
    hr = d3d11_dll.D3D11CreateDevice(
        None, 1, None, D3D11_CREATE_DEVICE_BGRA_SUPPORT,
        level, 1, D3D11_SDK_VERSION,
        ctypes.byref(g_d3d_device), None, ctypes.byref(g_d3d_ctx))
    if hr < 0: raise RuntimeError(f"D3D11CreateDevice failed: 0x{hr & 0xFFFFFFFF:08X}")
    log(f"D3D11 Device={hx(g_d3d_device)}")

# ============================================================
# Helper: create SwapChainForComposition
# ============================================================
def create_comp_swapchain(w, h):
    dxgi_dev = com_qi(g_d3d_device, IID_IDXGIDevice)
    adapter = ctypes.c_void_p(0)
    hr = com_call(dxgi_dev, 7, ctypes.c_long, ctypes.byref(adapter))  # IDXGIDevice::GetAdapter
    if hr < 0 or not adapter:
        com_release(dxgi_dev)
        raise RuntimeError(f"IDXGIDevice::GetAdapter failed: 0x{hr & 0xFFFFFFFF:08X}")

    factory = ctypes.c_void_p(0)
    iid_factory2 = (ctypes.c_byte * 16)(*IID_IDXGIFactory2)
    hr = com_call(adapter, 6, ctypes.c_long,  # IDXGIObject::GetParent
                  ctypes.byref(iid_factory2), ctypes.byref(factory))
    com_release(adapter)
    if hr < 0 or not factory:
        com_release(dxgi_dev)
        raise RuntimeError(f"IDXGIAdapter::GetParent(IDXGIFactory2) failed: 0x{hr & 0xFFFFFFFF:08X}")

    scd = DXGI_SWAP_CHAIN_DESC1()
    scd.Width = w; scd.Height = h; scd.Format = DXGI_FORMAT_B8G8R8A8_UNORM
    scd.SampleDesc = DXGI_SAMPLE_DESC(1, 0)
    scd.BufferUsage = DXGI_USAGE_RENDER_TARGET_OUTPUT; scd.BufferCount = 2
    scd.SwapEffect = DXGI_SWAP_EFFECT_FLIP_SEQUENTIAL
    scd.AlphaMode = DXGI_ALPHA_MODE_PREMULTIPLIED

    sc = ctypes.c_void_p(0)
    hr = com_call(factory, 24, ctypes.c_long,  # CreateSwapChainForComposition
                  g_d3d_device, ctypes.byref(scd), ctypes.c_void_p(0), ctypes.byref(sc))
    com_release(factory); com_release(dxgi_dev)
    if hr < 0: raise RuntimeError(f"CreateSwapChainForComposition failed: 0x{hr & 0xFFFFFFFF:08X}")
    return sc

def swapchain_get_buffer(sc):
    """IDXGISwapChain::GetBuffer(0, IID_ID3D11Texture2D, &tex)"""
    tex = ctypes.c_void_p(0)
    iid = (ctypes.c_byte * 16)(*IID_ID3D11Texture2D)
    hr = com_call(sc, 9, ctypes.c_long, ctypes.c_uint(0),
                  ctypes.c_void_p(ctypes.addressof(iid)), ctypes.byref(tex))
    if hr < 0: raise RuntimeError(f"GetBuffer failed: 0x{hr & 0xFFFFFFFF:08X}")
    return tex

def swapchain_present(sc):
    com_call(sc, 8, ctypes.c_long, ctypes.c_uint(1), ctypes.c_uint(0))

# ============================================================
# DirectComposition setup
# ============================================================
def init_dcomp():
    global g_dcomp_dev, g_dcomp_tgt, g_root_vis
    dxgi_dev = com_qi(g_d3d_device, IID_IDXGIDevice)

    IID_IDCompositionDevice = iid_bytes("C37EA93A-E7AA-450D-B16F-9746CB0407F3")
    iid = (ctypes.c_byte * 16)(*IID_IDCompositionDevice)
    hr = dcomp_dll.DCompositionCreateDevice(dxgi_dev, ctypes.cast(iid, ctypes.c_void_p), ctypes.byref(g_dcomp_dev))
    com_release(dxgi_dev)
    if hr < 0: raise RuntimeError(f"DCompositionCreateDevice failed: 0x{hr & 0xFFFFFFFF:08X}")
    log(f"DComp Device={hx(g_dcomp_dev)}")

    # CreateTargetForHwnd (vtbl 6)
    hr = com_call(g_dcomp_dev, 6, ctypes.c_long,
                  ctypes.c_void_p(g_hwnd), wintypes.BOOL(True), ctypes.byref(g_dcomp_tgt))
    if hr < 0: raise RuntimeError("CreateTargetForHwnd failed")

    # CreateVisual -> root (vtbl 7)
    hr = com_call(g_dcomp_dev, 7, ctypes.c_long, ctypes.byref(g_root_vis))
    if hr < 0: raise RuntimeError("CreateVisual (root) failed")

    # SetRoot (IDCompositionTarget vtbl 3)
    com_call(g_dcomp_tgt, 3, ctypes.c_long, g_root_vis)
    log("DComp target + root visual created")

def create_dcomp_visual(sc, offset_x):
    """Create a child visual, SetContent(sc), SetOffsetX, add to root."""
    vis = ctypes.c_void_p(0)
    com_call(g_dcomp_dev, 7, ctypes.c_long, ctypes.byref(vis))  # CreateVisual
    com_call(vis, 15, ctypes.c_long, sc)  # SetContent(IUnknown*)
    com_call(vis, 4, ctypes.c_long, ctypes.c_float(offset_x))   # SetOffsetX(float)
    com_call(vis, 6, ctypes.c_long, ctypes.c_float(0.0))        # SetOffsetY(float)
    # AddVisual(vis, TRUE, NULL)  (vtbl 16 on root)
    com_call(g_root_vis, 16, ctypes.c_long, vis, wintypes.BOOL(True), ctypes.c_void_p(0))
    return vis

def dcomp_commit():
    com_call(g_dcomp_dev, 3, ctypes.c_long)

# ============================================================
# D3D11 device helper methods
# ============================================================
def d3d_create_rtv(tex):
    rtv = ctypes.c_void_p(0)
    hr = com_call(g_d3d_device, 9, ctypes.c_long, tex, ctypes.c_void_p(0), ctypes.byref(rtv))
    if hr < 0: raise RuntimeError(f"CreateRenderTargetView failed: 0x{hr & 0xFFFFFFFF:08X}")
    return rtv

def d3d_create_staging_tex(w, h):
    desc = D3D11_TEXTURE2D_DESC()
    desc.Width = w; desc.Height = h; desc.MipLevels = 1; desc.ArraySize = 1
    desc.Format = DXGI_FORMAT_B8G8R8A8_UNORM; desc.SampleDesc = DXGI_SAMPLE_DESC(1,0)
    desc.Usage = D3D11_USAGE_STAGING; desc.CPUAccessFlags = D3D11_CPU_ACCESS_WRITE
    tex = ctypes.c_void_p(0)
    hr = com_call(g_d3d_device, 5, ctypes.c_long, ctypes.byref(desc), ctypes.c_void_p(0), ctypes.byref(tex))
    if hr < 0: raise RuntimeError(f"CreateTexture2D staging failed: 0x{hr & 0xFFFFFFFF:08X}")
    return tex

def d3d_create_buffer(data_bytes, bind_flags):
    """Create a D3D11 buffer (vertex buffer)."""
    class D3D11_BUFFER_DESC(ctypes.Structure):
        _fields_ = [("ByteWidth",ctypes.c_uint),("Usage",ctypes.c_uint),("BindFlags",ctypes.c_uint),
                     ("CPUAccessFlags",ctypes.c_uint),("MiscFlags",ctypes.c_uint),("StructureByteStride",ctypes.c_uint)]
    class D3D11_SUBRESOURCE_DATA(ctypes.Structure):
        _fields_ = [("pSysMem",ctypes.c_void_p),("SysMemPitch",ctypes.c_uint),("SysMemSlicePitch",ctypes.c_uint)]
    bd = D3D11_BUFFER_DESC(); bd.ByteWidth = len(data_bytes); bd.BindFlags = bind_flags
    arr = (ctypes.c_byte * len(data_bytes))(*data_bytes)
    sd = D3D11_SUBRESOURCE_DATA(); sd.pSysMem = ctypes.cast(arr, ctypes.c_void_p)
    buf = ctypes.c_void_p(0)
    hr = com_call(g_d3d_device, 3, ctypes.c_long, ctypes.byref(bd), ctypes.byref(sd), ctypes.byref(buf))
    if hr < 0: raise RuntimeError(f"CreateBuffer failed: 0x{hr & 0xFFFFFFFF:08X}")
    return buf

def ctx_clear_rtv(rtv, r, g, b, a):
    color = (ctypes.c_float * 4)(r, g, b, a)
    com_call(g_d3d_ctx, 50, None, rtv, ctypes.cast(color, ctypes.c_void_p))

def ctx_copy_resource(dst, src):
    com_call(g_d3d_ctx, 47, None, dst, src)

def ctx_map(res, map_type=D3D11_MAP_WRITE):
    mapped = D3D11_MAPPED_SUBRESOURCE()
    hr = com_call(g_d3d_ctx, 14, ctypes.c_long, res, ctypes.c_uint(0),
                  ctypes.c_uint(map_type), ctypes.c_uint(0), ctypes.byref(mapped))
    if hr < 0: raise RuntimeError(f"Map failed: 0x{hr & 0xFFFFFFFF:08X}")
    return mapped

def ctx_unmap(res):
    com_call(g_d3d_ctx, 15, None, res, ctypes.c_uint(0))

# ============================================================
# PANEL 1: D3D11 (native triangle)
# ============================================================
DX_HLSL = b"""
struct VSI { float3 p:POSITION; float4 c:COLOR; };
struct PSI { float4 p:SV_POSITION; float4 c:COLOR; };
PSI VS(VSI i){ PSI o; o.p=float4(i.p,1); o.c=i.c; return o; }
float4 PS(PSI i):SV_Target{ return i.c; }
"""

class D3D11Panel:
    def __init__(self):
        self.sc = self.bb = self.rtv = None
        self.vs = self.ps = self.il = self.vb = None
        self.vis = None

def init_d3d11_panel():
    p = D3D11Panel()
    p.sc = create_comp_swapchain(PANEL_W, PANEL_H)
    p.bb = swapchain_get_buffer(p.sc)
    p.rtv = d3d_create_rtv(p.bb)

    # Compile shaders
    vs_blob = ctypes.c_void_p(0); ps_blob = ctypes.c_void_p(0); err_blob = ctypes.c_void_p(0)
    hr = d3dc_dll.D3DCompile(DX_HLSL, len(DX_HLSL), b"dx", None, None, b"VS", b"vs_4_0", 0, 0, ctypes.byref(vs_blob), ctypes.byref(err_blob))
    if hr < 0 or not vs_blob:
        raise RuntimeError(f"D3DCompile(VS) failed: 0x{hr & 0xFFFFFFFF:08X}")
    hr = d3dc_dll.D3DCompile(DX_HLSL, len(DX_HLSL), b"dx", None, None, b"PS", b"ps_4_0", 0, 0, ctypes.byref(ps_blob), ctypes.byref(err_blob))
    if hr < 0 or not ps_blob:
        com_release(vs_blob)
        raise RuntimeError(f"D3DCompile(PS) failed: 0x{hr & 0xFFFFFFFF:08X}")

    vs_ptr = com_call(vs_blob, 3, ctypes.c_void_p)   # ID3D10Blob::GetBufferPointer
    vs_sz  = com_call(vs_blob, 4, ctypes.c_size_t)    # ID3D10Blob::GetBufferSize
    ps_ptr = com_call(ps_blob, 3, ctypes.c_void_p)
    ps_sz  = com_call(ps_blob, 4, ctypes.c_size_t)

    # CreateVertexShader (vtbl 12)
    p.vs = ctypes.c_void_p(0)
    hr = com_call(g_d3d_device, 12, ctypes.c_long, ctypes.c_void_p(vs_ptr), ctypes.c_size_t(vs_sz), ctypes.c_void_p(0), ctypes.byref(p.vs))
    if hr < 0 or not p.vs:
        com_release(vs_blob); com_release(ps_blob)
        raise RuntimeError(f"CreateVertexShader failed: 0x{hr & 0xFFFFFFFF:08X}")
    # CreatePixelShader (vtbl 15)
    p.ps = ctypes.c_void_p(0)
    hr = com_call(g_d3d_device, 15, ctypes.c_long, ctypes.c_void_p(ps_ptr), ctypes.c_size_t(ps_sz), ctypes.c_void_p(0), ctypes.byref(p.ps))
    if hr < 0 or not p.ps:
        com_release(vs_blob); com_release(ps_blob)
        raise RuntimeError(f"CreatePixelShader failed: 0x{hr & 0xFFFFFFFF:08X}")

    # Input layout
    class D3D11_INPUT_ELEMENT_DESC(ctypes.Structure):
        _fields_ = [("SemanticName",ctypes.c_char_p),("SemanticIndex",ctypes.c_uint),("Format",ctypes.c_uint),
                     ("InputSlot",ctypes.c_uint),("AlignedByteOffset",ctypes.c_uint),
                     ("InputSlotClass",ctypes.c_uint),("InstanceDataStepRate",ctypes.c_uint)]
    elems = (D3D11_INPUT_ELEMENT_DESC * 2)(
        D3D11_INPUT_ELEMENT_DESC(b"POSITION",0,6,0,0,0,0),   # DXGI_FORMAT_R32G32B32_FLOAT=6
        D3D11_INPUT_ELEMENT_DESC(b"COLOR",0,2,0,12,0,0),     # DXGI_FORMAT_R32G32B32A32_FLOAT=2
    )
    p.il = ctypes.c_void_p(0)
    hr = com_call(g_d3d_device, 11, ctypes.c_long, ctypes.cast(elems, ctypes.c_void_p), ctypes.c_uint(2),
                  ctypes.c_void_p(vs_ptr), ctypes.c_size_t(vs_sz), ctypes.byref(p.il))
    if hr < 0 or not p.il:
        com_release(vs_blob); com_release(ps_blob)
        raise RuntimeError(f"CreateInputLayout failed: 0x{hr & 0xFFFFFFFF:08X}")

    com_release(vs_blob); com_release(ps_blob)

    # Vertex buffer: 3 vertices x (float3 pos + float4 color) = 7 floats x 4 bytes = 28 bytes/vert
    verts = struct.pack("<" + "fffffff" * 3,
        0.0,  0.5, 0.0,  1,0,0,1,
        0.5, -0.5, 0.0,  0,1,0,1,
       -0.5, -0.5, 0.0,  0,0,1,1)
    p.vb = d3d_create_buffer(verts, 1)  # D3D11_BIND_VERTEX_BUFFER = 1

    p.vis = create_dcomp_visual(p.sc, float(PANEL_W))
    log("D3D11 panel init ok")
    return p

def render_d3d11(p: D3D11Panel):
    ctx = g_d3d_ctx
    ctx_clear_rtv(p.rtv, 0.05, 0.15, 0.05, 1.0)

    # OMSetRenderTargets(1, &rtv, NULL) - vtbl 33
    rtvs = (ctypes.c_void_p * 1)(p.rtv)
    com_call(ctx, 33, None, ctypes.c_uint(1), ctypes.cast(rtvs, ctypes.c_void_p), ctypes.c_void_p(0))

    # RSSetViewports - vtbl 44
    class D3D11_VIEWPORT(ctypes.Structure):
        _fields_ = [("TopLeftX", ctypes.c_float), ("TopLeftY", ctypes.c_float),
                    ("Width", ctypes.c_float), ("Height", ctypes.c_float),
                    ("MinDepth", ctypes.c_float), ("MaxDepth", ctypes.c_float)]
    vp = D3D11_VIEWPORT(0.0, 0.0, float(PANEL_W), float(PANEL_H), 0.0, 1.0)
    com_call(ctx, 44, None, ctypes.c_uint(1), ctypes.byref(vp))

    # IASetInputLayout - vtbl 17
    com_call(ctx, 17, None, p.il)

    # IASetVertexBuffers(0, 1, &vb, &stride, &offset) - vtbl 18
    vbs = (ctypes.c_void_p * 1)(p.vb)
    strides = (ctypes.c_uint * 1)(28)
    offsets = (ctypes.c_uint * 1)(0)
    com_call(ctx, 18, None, ctypes.c_uint(0), ctypes.c_uint(1),
             vbs, strides, offsets)

    # IASetPrimitiveTopology(TRIANGLELIST=4) - vtbl 24
    com_call(ctx, 24, None, ctypes.c_uint(4))

    # VSSetShader - vtbl 11
    com_call(ctx, 11, None, p.vs, ctypes.c_void_p(0), ctypes.c_uint(0))
    # PSSetShader - vtbl 9
    com_call(ctx, 9, None, p.ps, ctypes.c_void_p(0), ctypes.c_uint(0))

    # Draw(3, 0) - vtbl 13
    com_call(ctx, 13, None, ctypes.c_uint(3), ctypes.c_uint(0))

    swapchain_present(p.sc)

# ============================================================
# PANEL 0: OpenGL via WGL_NV_DX_interop2
# ============================================================
# OpenGL constants
GL_TRIANGLES = 0x0004; GL_FLOAT = 0x1406; GL_FALSE = 0; GL_COLOR_BUFFER_BIT = 0x4000
GL_ARRAY_BUFFER = 0x8892; GL_STATIC_DRAW = 0x88E4
GL_VERTEX_SHADER = 0x8B31; GL_FRAGMENT_SHADER = 0x8B30
GL_FRAMEBUFFER = 0x8D40; GL_RENDERBUFFER = 0x8D41; GL_COLOR_ATTACHMENT0 = 0x8CE0
WGL_ACCESS_READ_WRITE_NV = 1

class PFD(ctypes.Structure):
    _fields_ = [("nSize",ctypes.c_ushort),("nVersion",ctypes.c_ushort),("dwFlags",wintypes.DWORD),
                ("iPixelType",ctypes.c_ubyte),("cColorBits",ctypes.c_ubyte)] + \
               [(f"_pad{i}",ctypes.c_ubyte) for i in range(35)]

class GLPanel:
    def __init__(self):
        self.sc = self.bb = self.vis = None
        self.hdc = self.hrc = None
        self.interop_dev = self.interop_obj = None
        self.fbo = self.rbo = 0
        self.prog = 0

# wglGetProcAddress
gl_dll.wglGetProcAddress.restype = ctypes.c_void_p
gl_dll.wglGetProcAddress.argtypes = (ctypes.c_char_p,)
gl_dll.wglCreateContext.restype = ctypes.c_void_p
gl_dll.wglCreateContext.argtypes = (ctypes.c_void_p,)
gl_dll.wglMakeCurrent.restype = ctypes.c_int
gl_dll.wglMakeCurrent.argtypes = (ctypes.c_void_p, ctypes.c_void_p)
gl_dll.wglDeleteContext.argtypes = (ctypes.c_void_p,)
gl_dll.glGetString.restype = ctypes.c_void_p
gl_dll.glGetString.argtypes = (ctypes.c_uint,)

def _wgl(name, restype, argtypes):
    addr = gl_dll.wglGetProcAddress(name)
    if not addr: raise RuntimeError(f"wglGetProcAddress({name}) failed")
    return ctypes.WINFUNCTYPE(restype, *argtypes)(addr)

def _gl(name, restype, argtypes):
    return _wgl(name, restype, argtypes)

def init_gl_panel():
    p = GLPanel()

    # Create GL context using window DC
    p.hdc = user32.GetDC(g_hwnd)
    pfd = PFD(); pfd.nSize = ctypes.sizeof(PFD); pfd.nVersion = 1
    pfd.dwFlags = 0x25; pfd.iPixelType = 0; pfd.cColorBits = 32
    pf = gdi32.ChoosePixelFormat(p.hdc, ctypes.byref(pfd))
    gdi32.SetPixelFormat(p.hdc, pf, ctypes.byref(pfd))
    tmp_rc = gl_dll.wglCreateContext(p.hdc)
    gl_dll.wglMakeCurrent(p.hdc, tmp_rc)

    # Upgrade to 4.6 core via wglCreateContextAttribsARB
    try:
        wglCreateCtxAttribs = _wgl(b"wglCreateContextAttribsARB", ctypes.c_void_p,
                                   (ctypes.c_void_p, ctypes.c_void_p, ctypes.POINTER(ctypes.c_int)))
        p.hrc = wglCreateCtxAttribs(p.hdc, None, None)
        gl_dll.wglMakeCurrent(p.hdc, p.hrc)
        gl_dll.wglDeleteContext(tmp_rc)
        log("wglCreateContextAttribsARB available")
    except RuntimeError:
        # Fallback for environments without WGL_ARB_create_context (e.g. RDP/basic driver).
        p.hrc = tmp_rc
        log("wglCreateContextAttribsARB unavailable; using legacy WGL context")

    ven = ctypes.cast(gl_dll.glGetString(0x1F00), ctypes.c_char_p)
    ren = ctypes.cast(gl_dll.glGetString(0x1F01), ctypes.c_char_p)
    ver = ctypes.cast(gl_dll.glGetString(0x1F02), ctypes.c_char_p)
    log(f"GL_VENDOR   = {ven.value.decode() if ven else '?'}")
    log(f"GL_RENDERER = {ren.value.decode() if ren else '?'}")
    log(f"GL_VERSION  = {ver.value.decode() if ver else '?'}")

    # Load GL + WGL functions
    glGenBuffers = _gl(b"glGenBuffers", None, (ctypes.c_int, ctypes.POINTER(ctypes.c_uint)))
    glBindBuffer = _gl(b"glBindBuffer", None, (ctypes.c_uint, ctypes.c_uint))
    glBufferData = _gl(b"glBufferData", None, (ctypes.c_uint, ctypes.c_ssize_t, ctypes.c_void_p, ctypes.c_uint))
    glCreateShader = _gl(b"glCreateShader", ctypes.c_uint, (ctypes.c_uint,))
    glShaderSource = _gl(b"glShaderSource", None, (ctypes.c_uint, ctypes.c_int, ctypes.POINTER(ctypes.c_char_p), ctypes.c_void_p))
    glCompileShader = _gl(b"glCompileShader", None, (ctypes.c_uint,))
    glCreateProgram = _gl(b"glCreateProgram", ctypes.c_uint, ())
    glAttachShader = _gl(b"glAttachShader", None, (ctypes.c_uint, ctypes.c_uint))
    glLinkProgram = _gl(b"glLinkProgram", None, (ctypes.c_uint,))
    glUseProgram = _gl(b"glUseProgram", None, (ctypes.c_uint,))
    glGetAttribLocation = _gl(b"glGetAttribLocation", ctypes.c_int, (ctypes.c_uint, ctypes.c_char_p))
    glEnableVertexAttribArray = _gl(b"glEnableVertexAttribArray", None, (ctypes.c_uint,))
    glVertexAttribPointer = _gl(b"glVertexAttribPointer", None, (ctypes.c_uint, ctypes.c_int, ctypes.c_uint, ctypes.c_ubyte, ctypes.c_int, ctypes.c_void_p))
    glGenFramebuffers = _gl(b"glGenFramebuffers", None, (ctypes.c_int, ctypes.POINTER(ctypes.c_uint)))
    glBindFramebuffer = _gl(b"glBindFramebuffer", None, (ctypes.c_uint, ctypes.c_uint))
    glFramebufferRenderbuffer = _gl(b"glFramebufferRenderbuffer", None, (ctypes.c_uint, ctypes.c_uint, ctypes.c_uint, ctypes.c_uint))
    glGenRenderbuffers = _gl(b"glGenRenderbuffers", None, (ctypes.c_int, ctypes.POINTER(ctypes.c_uint)))
    glGenVertexArrays = _gl(b"glGenVertexArrays", None, (ctypes.c_int, ctypes.POINTER(ctypes.c_uint)))
    glBindVertexArray = _gl(b"glBindVertexArray", None, (ctypes.c_uint,))

    wglDXOpenDeviceNV = _wgl(b"wglDXOpenDeviceNV", ctypes.c_void_p, (ctypes.c_void_p,))
    wglDXRegisterObjectNV = _wgl(b"wglDXRegisterObjectNV", ctypes.c_void_p,
        (ctypes.c_void_p, ctypes.c_void_p, ctypes.c_uint, ctypes.c_uint, ctypes.c_uint))
    p._wglDXLock   = _wgl(b"wglDXLockObjectsNV", ctypes.c_int, (ctypes.c_void_p, ctypes.c_int, ctypes.POINTER(ctypes.c_void_p)))
    p._wglDXUnlock = _wgl(b"wglDXUnlockObjectsNV", ctypes.c_int, (ctypes.c_void_p, ctypes.c_int, ctypes.POINTER(ctypes.c_void_p)))

    # SwapChain + DX interop
    p.sc = create_comp_swapchain(PANEL_W, PANEL_H)
    p.bb = swapchain_get_buffer(p.sc)

    p.interop_dev = wglDXOpenDeviceNV(g_d3d_device)
    if not p.interop_dev: raise RuntimeError("wglDXOpenDeviceNV failed")

    rbo = ctypes.c_uint(0); glGenRenderbuffers(1, ctypes.byref(rbo)); p.rbo = rbo.value
    p.interop_obj = wglDXRegisterObjectNV(p.interop_dev, p.bb, p.rbo, GL_RENDERBUFFER, WGL_ACCESS_READ_WRITE_NV)
    if not p.interop_obj: raise RuntimeError("wglDXRegisterObjectNV failed")

    fbo = ctypes.c_uint(0); glGenFramebuffers(1, ctypes.byref(fbo)); p.fbo = fbo.value
    glBindFramebuffer(GL_FRAMEBUFFER, p.fbo)
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, p.rbo)
    glBindFramebuffer(GL_FRAMEBUFFER, 0)

    # DComp visual
    p.vis = create_dcomp_visual(p.sc, 0.0)

    # VAO + VBO
    vao = ctypes.c_uint(0); glGenVertexArrays(1, ctypes.byref(vao)); glBindVertexArray(vao.value)
    vbo = (ctypes.c_uint * 2)(); glGenBuffers(2, vbo)

    verts = (ctypes.c_float * 9)(0,0.5,0, 0.5,-0.5,0, -0.5,-0.5,0)
    cols  = (ctypes.c_float * 9)(1,0,0, 0,1,0, 0,0,1)
    glBindBuffer(GL_ARRAY_BUFFER, vbo[0])
    glBufferData(GL_ARRAY_BUFFER, ctypes.sizeof(verts), ctypes.cast(verts, ctypes.c_void_p), GL_STATIC_DRAW)
    glBindBuffer(GL_ARRAY_BUFFER, vbo[1])
    glBufferData(GL_ARRAY_BUFFER, ctypes.sizeof(cols), ctypes.cast(cols, ctypes.c_void_p), GL_STATIC_DRAW)

    # Shaders
    vs_src = b"#version 460 core\nlayout(location=0) in vec3 pos; layout(location=1) in vec3 col;\nout vec4 vCol;\nvoid main(){ vCol=vec4(col,1); gl_Position=vec4(pos.x,-pos.y,pos.z,1); }\n"
    fs_src = b"#version 460 core\nin vec4 vCol; out vec4 outCol;\nvoid main(){ outCol=vCol; }\n"

    vs = glCreateShader(GL_VERTEX_SHADER)
    src_p = (ctypes.c_char_p * 1)(vs_src)
    glShaderSource(vs, 1, src_p, None); glCompileShader(vs)
    fs = glCreateShader(GL_FRAGMENT_SHADER)
    src_p = (ctypes.c_char_p * 1)(fs_src)
    glShaderSource(fs, 1, src_p, None); glCompileShader(fs)
    p.prog = glCreateProgram()
    glAttachShader(p.prog, vs); glAttachShader(p.prog, fs)
    glLinkProgram(p.prog); glUseProgram(p.prog)

    p._posAttr = glGetAttribLocation(p.prog, b"pos")
    p._colAttr = glGetAttribLocation(p.prog, b"col")
    glEnableVertexAttribArray(p._posAttr)
    glEnableVertexAttribArray(p._colAttr)

    # Store function refs for render loop
    p._vbo = vbo
    p._glBindFramebuffer = glBindFramebuffer
    p._glBindBuffer = glBindBuffer
    p._glVertexAttribPointer = glVertexAttribPointer
    p._glUseProgram = glUseProgram
    p._glBindVertexArray = glBindVertexArray
    p._vao = vao.value

    log("GL panel init ok")
    return p

def render_gl(p: GLPanel):
    gl_dll.wglMakeCurrent(p.hdc, p.hrc)
    objs = (ctypes.c_void_p * 1)(p.interop_obj)
    p._wglDXLock(p.interop_dev, 1, objs)

    p._glBindFramebuffer(GL_FRAMEBUFFER, p.fbo)
    gl_dll.glViewport(0, 0, PANEL_W, PANEL_H)
    gl_dll.glClearColor(ctypes.c_float(0.05), ctypes.c_float(0.05), ctypes.c_float(0.15), ctypes.c_float(1.0))
    gl_dll.glClear(GL_COLOR_BUFFER_BIT)

    p._glUseProgram(p.prog)
    p._glBindVertexArray(p._vao)
    p._glBindBuffer(GL_ARRAY_BUFFER, p._vbo[0])
    p._glVertexAttribPointer(p._posAttr, 3, GL_FLOAT, GL_FALSE, 0, None)
    p._glBindBuffer(GL_ARRAY_BUFFER, p._vbo[1])
    p._glVertexAttribPointer(p._colAttr, 3, GL_FLOAT, GL_FALSE, 0, None)
    gl_dll.glDrawArrays(GL_TRIANGLES, 0, 3)

    p._glBindFramebuffer(GL_FRAMEBUFFER, 0)
    gl_dll.glFlush()
    p._wglDXUnlock(p.interop_dev, 1, objs)
    swapchain_present(p.sc)

# ============================================================
# PANEL 2: Vulkan (offscreen -> staging -> D3D11 copy)
# ============================================================
# Vulkan types
VkResult = ctypes.c_int32
VkInstance = ctypes.c_void_p; VkPhysicalDevice = ctypes.c_void_p; VkDevice = ctypes.c_void_p
VkQueue = ctypes.c_void_p; VkCommandPool = ctypes.c_void_p; VkCommandBuffer = ctypes.c_void_p
VkImage = ctypes.c_uint64; VkImageView = ctypes.c_uint64; VkRenderPass = ctypes.c_uint64
VkFramebuffer_ = ctypes.c_uint64; VkPipelineLayout = ctypes.c_uint64; VkPipeline_ = ctypes.c_uint64
VkShaderModule = ctypes.c_uint64; VkFence = ctypes.c_uint64; VkDeviceMemory = ctypes.c_uint64
VkBuffer_ = ctypes.c_uint64

vk_dll = ctypes.WinDLL("vulkan-1", use_last_error=True)
vk_dll.vkGetInstanceProcAddr.restype = ctypes.c_void_p
vk_dll.vkGetInstanceProcAddr.argtypes = (VkInstance, ctypes.c_char_p)
vk_dll.vkGetDeviceProcAddr.restype = ctypes.c_void_p
vk_dll.vkGetDeviceProcAddr.argtypes = (VkDevice, ctypes.c_char_p)

def _vk_g(name, res, args):
    fn = getattr(vk_dll, name.decode()); fn.restype = res; fn.argtypes = args; return fn
def _vk_d(dev, name, res, args):
    addr = vk_dll.vkGetDeviceProcAddr(dev, name)
    if not addr: raise RuntimeError(f"vkGetDeviceProcAddr({name}) failed")
    return ctypes.WINFUNCTYPE(res, *args)(addr)
def vk_check(r, w):
    if r != 0: raise RuntimeError(f"{w} failed: {r}")

# Vulkan structs (minimal for offscreen)
class VkExtent2D(ctypes.Structure): _fields_ = [("width",ctypes.c_uint32),("height",ctypes.c_uint32)]
class VkExtent3D(ctypes.Structure): _fields_ = [("width",ctypes.c_uint32),("height",ctypes.c_uint32),("depth",ctypes.c_uint32)]
class VkQueueFamilyProperties(ctypes.Structure):
    _fields_ = [("queueFlags",ctypes.c_uint32),("queueCount",ctypes.c_uint32),("timestampValidBits",ctypes.c_uint32),("minImageTransferGranularity",VkExtent3D)]
class VkApplicationInfo(ctypes.Structure):
    _fields_ = [("sType",ctypes.c_uint32),("pNext",ctypes.c_void_p),("pApplicationName",ctypes.c_char_p),("applicationVersion",ctypes.c_uint32),("pEngineName",ctypes.c_char_p),("engineVersion",ctypes.c_uint32),("apiVersion",ctypes.c_uint32)]
class VkInstanceCreateInfo(ctypes.Structure):
    _fields_ = [("sType",ctypes.c_uint32),("pNext",ctypes.c_void_p),("flags",ctypes.c_uint32),("pApplicationInfo",ctypes.POINTER(VkApplicationInfo)),("enabledLayerCount",ctypes.c_uint32),("ppEnabledLayerNames",ctypes.c_void_p),("enabledExtensionCount",ctypes.c_uint32),("ppEnabledExtensionNames",ctypes.c_void_p)]
class VkDeviceQueueCreateInfo(ctypes.Structure):
    _fields_ = [("sType",ctypes.c_uint32),("pNext",ctypes.c_void_p),("flags",ctypes.c_uint32),("queueFamilyIndex",ctypes.c_uint32),("queueCount",ctypes.c_uint32),("pQueuePriorities",ctypes.POINTER(ctypes.c_float))]
class VkDeviceCreateInfo(ctypes.Structure):
    _fields_ = [("sType",ctypes.c_uint32),("pNext",ctypes.c_void_p),("flags",ctypes.c_uint32),("queueCreateInfoCount",ctypes.c_uint32),("pQueueCreateInfos",ctypes.POINTER(VkDeviceQueueCreateInfo)),("enabledLayerCount",ctypes.c_uint32),("ppEnabledLayerNames",ctypes.c_void_p),("enabledExtensionCount",ctypes.c_uint32),("ppEnabledExtensionNames",ctypes.c_void_p),("pEnabledFeatures",ctypes.c_void_p)]
class VkImageCreateInfo(ctypes.Structure):
    _fields_ = [("sType",ctypes.c_uint32),("pNext",ctypes.c_void_p),("flags",ctypes.c_uint32),("imageType",ctypes.c_uint32),("format",ctypes.c_uint32),("extent",VkExtent3D),("mipLevels",ctypes.c_uint32),("arrayLayers",ctypes.c_uint32),("samples",ctypes.c_uint32),("tiling",ctypes.c_uint32),("usage",ctypes.c_uint32),("sharingMode",ctypes.c_uint32),("queueFamilyIndexCount",ctypes.c_uint32),("pQueueFamilyIndices",ctypes.c_void_p),("initialLayout",ctypes.c_uint32)]
class VkMemoryRequirements(ctypes.Structure):
    _fields_ = [("size",ctypes.c_uint64),("alignment",ctypes.c_uint64),("memoryTypeBits",ctypes.c_uint32)]
class VkMemoryAllocateInfo(ctypes.Structure):
    _fields_ = [("sType",ctypes.c_uint32),("pNext",ctypes.c_void_p),("allocationSize",ctypes.c_uint64),("memoryTypeIndex",ctypes.c_uint32)]
class VkPhysicalDeviceMemoryProperties(ctypes.Structure):
    class VkMemoryType(ctypes.Structure): _fields_ = [("propertyFlags",ctypes.c_uint32),("heapIndex",ctypes.c_uint32)]
    class VkMemoryHeap(ctypes.Structure): _fields_ = [("size",ctypes.c_uint64),("flags",ctypes.c_uint32)]
    _fields_ = [("memoryTypeCount",ctypes.c_uint32),("memoryTypes",VkMemoryType*32),("memoryHeapCount",ctypes.c_uint32),("memoryHeaps",VkMemoryHeap*16)]
class VkImageSubresourceRange(ctypes.Structure):
    _fields_ = [("aspectMask",ctypes.c_uint32),("baseMipLevel",ctypes.c_uint32),("levelCount",ctypes.c_uint32),("baseArrayLayer",ctypes.c_uint32),("layerCount",ctypes.c_uint32)]
class VkImageViewCreateInfo(ctypes.Structure):
    _fields_ = [("sType",ctypes.c_uint32),("pNext",ctypes.c_void_p),("flags",ctypes.c_uint32),("image",VkImage),("viewType",ctypes.c_uint32),("format",ctypes.c_uint32),("r",ctypes.c_uint32),("g",ctypes.c_uint32),("b",ctypes.c_uint32),("a",ctypes.c_uint32),("subresourceRange",VkImageSubresourceRange)]
class VkAttachmentDescription(ctypes.Structure):
    _fields_ = [("flags",ctypes.c_uint32),("format",ctypes.c_uint32),("samples",ctypes.c_uint32),("loadOp",ctypes.c_uint32),("storeOp",ctypes.c_uint32),("stencilLoadOp",ctypes.c_uint32),("stencilStoreOp",ctypes.c_uint32),("initialLayout",ctypes.c_uint32),("finalLayout",ctypes.c_uint32)]
class VkAttachmentReference(ctypes.Structure): _fields_ = [("attachment",ctypes.c_uint32),("layout",ctypes.c_uint32)]
class VkSubpassDescription(ctypes.Structure):
    _fields_ = [("flags",ctypes.c_uint32),("pipelineBindPoint",ctypes.c_uint32),("inputAttachmentCount",ctypes.c_uint32),("pInputAttachments",ctypes.c_void_p),("colorAttachmentCount",ctypes.c_uint32),("pColorAttachments",ctypes.POINTER(VkAttachmentReference)),("pResolveAttachments",ctypes.c_void_p),("pDepthStencilAttachment",ctypes.c_void_p),("preserveAttachmentCount",ctypes.c_uint32),("pPreserveAttachments",ctypes.c_void_p)]
class VkRenderPassCreateInfo(ctypes.Structure):
    _fields_ = [("sType",ctypes.c_uint32),("pNext",ctypes.c_void_p),("flags",ctypes.c_uint32),("attachmentCount",ctypes.c_uint32),("pAttachments",ctypes.POINTER(VkAttachmentDescription)),("subpassCount",ctypes.c_uint32),("pSubpasses",ctypes.POINTER(VkSubpassDescription)),("dependencyCount",ctypes.c_uint32),("pDependencies",ctypes.c_void_p)]
class VkShaderModuleCreateInfo(ctypes.Structure):
    _fields_ = [("sType",ctypes.c_uint32),("pNext",ctypes.c_void_p),("flags",ctypes.c_uint32),("codeSize",ctypes.c_size_t),("pCode",ctypes.POINTER(ctypes.c_uint32))]
class VkPipelineShaderStageCreateInfo(ctypes.Structure):
    _fields_ = [("sType",ctypes.c_uint32),("pNext",ctypes.c_void_p),("flags",ctypes.c_uint32),("stage",ctypes.c_uint32),("module",VkShaderModule),("pName",ctypes.c_char_p),("pSpecializationInfo",ctypes.c_void_p)]
class VkPipelineVertexInputStateCreateInfo(ctypes.Structure):
    _fields_ = [("sType",ctypes.c_uint32),("pNext",ctypes.c_void_p),("flags",ctypes.c_uint32),("vbdc",ctypes.c_uint32),("pVBD",ctypes.c_void_p),("vadc",ctypes.c_uint32),("pVAD",ctypes.c_void_p)]
class VkPipelineInputAssemblyStateCreateInfo(ctypes.Structure):
    _fields_ = [("sType",ctypes.c_uint32),("pNext",ctypes.c_void_p),("flags",ctypes.c_uint32),("topology",ctypes.c_uint32),("primitiveRestartEnable",ctypes.c_uint32)]
class VkViewport(ctypes.Structure):
    _fields_ = [("x",ctypes.c_float),("y",ctypes.c_float),("width",ctypes.c_float),("height",ctypes.c_float),("minDepth",ctypes.c_float),("maxDepth",ctypes.c_float)]
class VkOffset2D(ctypes.Structure): _fields_ = [("x",ctypes.c_int32),("y",ctypes.c_int32)]
class VkRect2D(ctypes.Structure): _fields_ = [("offset",VkOffset2D),("extent",VkExtent2D)]
class VkPipelineViewportStateCreateInfo(ctypes.Structure):
    _fields_ = [("sType",ctypes.c_uint32),("pNext",ctypes.c_void_p),("flags",ctypes.c_uint32),("viewportCount",ctypes.c_uint32),("pViewports",ctypes.POINTER(VkViewport)),("scissorCount",ctypes.c_uint32),("pScissors",ctypes.POINTER(VkRect2D))]
class VkPipelineRasterizationStateCreateInfo(ctypes.Structure):
    _fields_ = [("sType",ctypes.c_uint32),("pNext",ctypes.c_void_p),("flags",ctypes.c_uint32),("depthClampEnable",ctypes.c_uint32),("rasterizerDiscardEnable",ctypes.c_uint32),("polygonMode",ctypes.c_uint32),("cullMode",ctypes.c_uint32),("frontFace",ctypes.c_uint32),("depthBiasEnable",ctypes.c_uint32),("depthBiasConstantFactor",ctypes.c_float),("depthBiasClamp",ctypes.c_float),("depthBiasSlopeFactor",ctypes.c_float),("lineWidth",ctypes.c_float)]
class VkPipelineMultisampleStateCreateInfo(ctypes.Structure):
    _fields_ = [("sType",ctypes.c_uint32),("pNext",ctypes.c_void_p),("flags",ctypes.c_uint32),("rasterizationSamples",ctypes.c_uint32),("sampleShadingEnable",ctypes.c_uint32),("minSampleShading",ctypes.c_float),("pSampleMask",ctypes.c_void_p),("alphaToCoverageEnable",ctypes.c_uint32),("alphaToOneEnable",ctypes.c_uint32)]
class VkPipelineColorBlendAttachmentState(ctypes.Structure):
    _fields_ = [("blendEnable",ctypes.c_uint32),("srcColorBlendFactor",ctypes.c_uint32),("dstColorBlendFactor",ctypes.c_uint32),("colorBlendOp",ctypes.c_uint32),("srcAlphaBlendFactor",ctypes.c_uint32),("dstAlphaBlendFactor",ctypes.c_uint32),("alphaBlendOp",ctypes.c_uint32),("colorWriteMask",ctypes.c_uint32)]
class VkPipelineColorBlendStateCreateInfo(ctypes.Structure):
    _fields_ = [("sType",ctypes.c_uint32),("pNext",ctypes.c_void_p),("flags",ctypes.c_uint32),("logicOpEnable",ctypes.c_uint32),("logicOp",ctypes.c_uint32),("attachmentCount",ctypes.c_uint32),("pAttachments",ctypes.POINTER(VkPipelineColorBlendAttachmentState)),("blendConstants",ctypes.c_float*4)]
class VkPipelineLayoutCreateInfo(ctypes.Structure):
    _fields_ = [("sType",ctypes.c_uint32),("pNext",ctypes.c_void_p),("flags",ctypes.c_uint32),("setLayoutCount",ctypes.c_uint32),("pSetLayouts",ctypes.c_void_p),("pushConstantRangeCount",ctypes.c_uint32),("pPushConstantRanges",ctypes.c_void_p)]
class VkGraphicsPipelineCreateInfo(ctypes.Structure):
    _fields_ = [("sType",ctypes.c_uint32),("pNext",ctypes.c_void_p),("flags",ctypes.c_uint32),("stageCount",ctypes.c_uint32),("pStages",ctypes.POINTER(VkPipelineShaderStageCreateInfo)),("pVertexInputState",ctypes.POINTER(VkPipelineVertexInputStateCreateInfo)),("pInputAssemblyState",ctypes.POINTER(VkPipelineInputAssemblyStateCreateInfo)),("pTessellationState",ctypes.c_void_p),("pViewportState",ctypes.POINTER(VkPipelineViewportStateCreateInfo)),("pRasterizationState",ctypes.POINTER(VkPipelineRasterizationStateCreateInfo)),("pMultisampleState",ctypes.POINTER(VkPipelineMultisampleStateCreateInfo)),("pDepthStencilState",ctypes.c_void_p),("pColorBlendState",ctypes.POINTER(VkPipelineColorBlendStateCreateInfo)),("pDynamicState",ctypes.c_void_p),("layout",VkPipelineLayout),("renderPass",VkRenderPass),("subpass",ctypes.c_uint32),("basePipelineHandle",VkPipeline_),("basePipelineIndex",ctypes.c_int32)]
class VkFramebufferCreateInfo(ctypes.Structure):
    _fields_ = [("sType",ctypes.c_uint32),("pNext",ctypes.c_void_p),("flags",ctypes.c_uint32),("renderPass",VkRenderPass),("attachmentCount",ctypes.c_uint32),("pAttachments",ctypes.POINTER(VkImageView)),("width",ctypes.c_uint32),("height",ctypes.c_uint32),("layers",ctypes.c_uint32)]
class VkCommandPoolCreateInfo(ctypes.Structure):
    _fields_ = [("sType",ctypes.c_uint32),("pNext",ctypes.c_void_p),("flags",ctypes.c_uint32),("queueFamilyIndex",ctypes.c_uint32)]
class VkCommandBufferAllocateInfo(ctypes.Structure):
    _fields_ = [("sType",ctypes.c_uint32),("pNext",ctypes.c_void_p),("commandPool",VkCommandPool),("level",ctypes.c_uint32),("commandBufferCount",ctypes.c_uint32)]
class VkCommandBufferBeginInfo(ctypes.Structure):
    _fields_ = [("sType",ctypes.c_uint32),("pNext",ctypes.c_void_p),("flags",ctypes.c_uint32),("pInheritanceInfo",ctypes.c_void_p)]
class VkClearColorValue(ctypes.Structure): _fields_ = [("float32",ctypes.c_float*4)]
class VkClearValue(ctypes.Union): _fields_ = [("color",VkClearColorValue)]
class VkRenderPassBeginInfo(ctypes.Structure):
    _fields_ = [("sType",ctypes.c_uint32),("pNext",ctypes.c_void_p),("renderPass",VkRenderPass),("framebuffer",VkFramebuffer_),("renderArea",VkRect2D),("clearValueCount",ctypes.c_uint32),("pClearValues",ctypes.POINTER(VkClearValue))]
class VkFenceCreateInfo(ctypes.Structure):
    _fields_ = [("sType",ctypes.c_uint32),("pNext",ctypes.c_void_p),("flags",ctypes.c_uint32)]
class VkSubmitInfo(ctypes.Structure):
    _fields_ = [("sType",ctypes.c_uint32),("pNext",ctypes.c_void_p),("waitSemaphoreCount",ctypes.c_uint32),("pWaitSemaphores",ctypes.c_void_p),("pWaitDstStageMask",ctypes.c_void_p),("commandBufferCount",ctypes.c_uint32),("pCommandBuffers",ctypes.POINTER(VkCommandBuffer)),("signalSemaphoreCount",ctypes.c_uint32),("pSignalSemaphores",ctypes.c_void_p)]
class VkBufferCreateInfo(ctypes.Structure):
    _fields_ = [("sType",ctypes.c_uint32),("pNext",ctypes.c_void_p),("flags",ctypes.c_uint32),("size",ctypes.c_uint64),("usage",ctypes.c_uint32),("sharingMode",ctypes.c_uint32),("queueFamilyIndexCount",ctypes.c_uint32),("pQueueFamilyIndices",ctypes.c_void_p)]
class VkImageSubresourceLayers(ctypes.Structure):
    _fields_ = [("aspectMask",ctypes.c_uint32),("mipLevel",ctypes.c_uint32),("baseArrayLayer",ctypes.c_uint32),("layerCount",ctypes.c_uint32)]
class VkBufferImageCopy(ctypes.Structure):
    _fields_ = [("bufferOffset",ctypes.c_uint64),("bufferRowLength",ctypes.c_uint32),("bufferImageHeight",ctypes.c_uint32),("imageSubresource",VkImageSubresourceLayers),("imageOffset_x",ctypes.c_int32),("imageOffset_y",ctypes.c_int32),("imageOffset_z",ctypes.c_int32),("imageExtent",VkExtent3D)]

class VKPanel:
    pass

# Shaderc for GLSL->SPIR-V
class Shaderc:
    VERTEX=0; FRAGMENT=1; STATUS_SUCCESS=0
    def __init__(self):
        dll_path = "shaderc_shared.dll"
        vksdk_bin = Path(os.environ.get("VULKAN_SDK","")) / "Bin"
        if (vksdk_bin / dll_path).exists(): dll_path = str(vksdk_bin / dll_path)
        elif (SCRIPT_DIR / dll_path).exists(): dll_path = str(SCRIPT_DIR / dll_path)
        self.lib = ctypes.CDLL(dll_path)
        self.lib.shaderc_compiler_initialize.restype = ctypes.c_void_p
        self.lib.shaderc_compile_into_spv.restype = ctypes.c_void_p
        self.lib.shaderc_compile_into_spv.argtypes = [ctypes.c_void_p,ctypes.c_char_p,ctypes.c_size_t,ctypes.c_int,ctypes.c_char_p,ctypes.c_char_p,ctypes.c_void_p]
        self.lib.shaderc_result_get_compilation_status.restype = ctypes.c_int; self.lib.shaderc_result_get_compilation_status.argtypes = [ctypes.c_void_p]
        self.lib.shaderc_result_get_length.restype = ctypes.c_size_t; self.lib.shaderc_result_get_length.argtypes = [ctypes.c_void_p]
        self.lib.shaderc_result_get_bytes.restype = ctypes.c_void_p; self.lib.shaderc_result_get_bytes.argtypes = [ctypes.c_void_p]
        self.lib.shaderc_result_release.argtypes = [ctypes.c_void_p]
        self.lib.shaderc_compiler_release.argtypes = [ctypes.c_void_p]
        self.lib.shaderc_result_get_error_message.restype = ctypes.c_char_p; self.lib.shaderc_result_get_error_message.argtypes = [ctypes.c_void_p]
    def compile(self, src, kind, fname="shader"):
        s = src.encode() if isinstance(src,str) else src
        c = self.lib.shaderc_compiler_initialize()
        r = self.lib.shaderc_compile_into_spv(c, s, len(s), kind, fname.encode(), b"main", None)
        if self.lib.shaderc_result_get_compilation_status(r) != 0:
            err = self.lib.shaderc_result_get_error_message(r)
            raise RuntimeError(f"Shader compile error: {err}")
        n = self.lib.shaderc_result_get_length(r)
        p = self.lib.shaderc_result_get_bytes(r)
        data = ctypes.string_at(p, n)
        self.lib.shaderc_result_release(r); self.lib.shaderc_compiler_release(c)
        return data

def init_vulkan_panel():
    p = VKPanel()
    sc = Shaderc()
    vert_src = (SCRIPT_DIR / "hello.vert").read_text()
    frag_src = (SCRIPT_DIR / "hello.frag").read_text()
    vert_spv = sc.compile(vert_src, Shaderc.VERTEX, "hello.vert")
    frag_spv = sc.compile(frag_src, Shaderc.FRAGMENT, "hello.frag")
    log(f"Vulkan SPIR-V: vert={len(vert_spv)}B frag={len(frag_spv)}B")

    # Instance (no surface extensions)
    vkCreateInstance = _vk_g(b"vkCreateInstance", VkResult, (ctypes.c_void_p, ctypes.c_void_p, ctypes.POINTER(VkInstance)))
    vkEnumPD = _vk_g(b"vkEnumeratePhysicalDevices", VkResult, (VkInstance, ctypes.POINTER(ctypes.c_uint32), ctypes.c_void_p))
    vkGetQFP = _vk_g(b"vkGetPhysicalDeviceQueueFamilyProperties", None, (VkPhysicalDevice, ctypes.POINTER(ctypes.c_uint32), ctypes.POINTER(VkQueueFamilyProperties)))
    vkGetMemProps = _vk_g(b"vkGetPhysicalDeviceMemoryProperties", None, (VkPhysicalDevice, ctypes.POINTER(VkPhysicalDeviceMemoryProperties)))
    vkCreateDevice_ = _vk_g(b"vkCreateDevice", VkResult, (VkPhysicalDevice, ctypes.c_void_p, ctypes.c_void_p, ctypes.POINTER(VkDevice)))

    app = VkApplicationInfo(sType=0, pNext=None, pApplicationName=b"vk", applicationVersion=1, pEngineName=b"", engineVersion=1, apiVersion=(1<<22))
    ici = VkInstanceCreateInfo(sType=1, pNext=None, flags=0, pApplicationInfo=ctypes.pointer(app))
    p.inst = VkInstance()
    vk_check(vkCreateInstance(ctypes.byref(ici), None, ctypes.byref(p.inst)), "vkCreateInstance")

    cnt = ctypes.c_uint32(0); vkEnumPD(p.inst, ctypes.byref(cnt), None)
    devs = (VkPhysicalDevice * cnt.value)(); vkEnumPD(p.inst, ctypes.byref(cnt), devs)
    p.pd = None; p.qf = 0
    for d in devs:
        qc = ctypes.c_uint32(0); vkGetQFP(d, ctypes.byref(qc), None)
        qps = (VkQueueFamilyProperties * qc.value)(); vkGetQFP(d, ctypes.byref(qc), qps)
        for i in range(qc.value):
            if qps[i].queueFlags & 1:
                p.pd = d; p.qf = i; break
        if p.pd: break
    if not p.pd: raise RuntimeError("No Vulkan GPU")

    prio = (ctypes.c_float * 1)(1.0)
    qci = VkDeviceQueueCreateInfo(sType=2, pNext=None, flags=0, queueFamilyIndex=p.qf, queueCount=1, pQueuePriorities=prio)
    dci = VkDeviceCreateInfo(sType=3, pNext=None, flags=0, queueCreateInfoCount=1, pQueueCreateInfos=ctypes.pointer(qci))
    p.dev = VkDevice()
    vk_check(vkCreateDevice_(p.pd, ctypes.byref(dci), None, ctypes.byref(p.dev)), "vkCreateDevice")

    vkGetQueue = _vk_d(p.dev, b"vkGetDeviceQueue", None, (VkDevice, ctypes.c_uint32, ctypes.c_uint32, ctypes.POINTER(VkQueue)))
    p.queue = VkQueue()
    vkGetQueue(p.dev, p.qf, 0, ctypes.byref(p.queue))

    memProps = VkPhysicalDeviceMemoryProperties(); vkGetMemProps(p.pd, ctypes.byref(memProps))
    def find_mem(bits, flags):
        for i in range(memProps.memoryTypeCount):
            if (bits & (1<<i)) and (memProps.memoryTypes[i].propertyFlags & flags) == flags: return i
        raise RuntimeError("No memory type")

    # Image (offscreen, BGRA)
    vkCreateImage = _vk_d(p.dev, b"vkCreateImage", VkResult, (VkDevice, ctypes.POINTER(VkImageCreateInfo), ctypes.c_void_p, ctypes.POINTER(VkImage)))
    vkGetImageMemReq = _vk_d(p.dev, b"vkGetImageMemoryRequirements", None, (VkDevice, VkImage, ctypes.POINTER(VkMemoryRequirements)))
    vkAllocMem = _vk_d(p.dev, b"vkAllocateMemory", VkResult, (VkDevice, ctypes.POINTER(VkMemoryAllocateInfo), ctypes.c_void_p, ctypes.POINTER(VkDeviceMemory)))
    vkBindImgMem = _vk_d(p.dev, b"vkBindImageMemory", VkResult, (VkDevice, VkImage, VkDeviceMemory, ctypes.c_uint64))
    vkCreateImageView_ = _vk_d(p.dev, b"vkCreateImageView", VkResult, (VkDevice, ctypes.POINTER(VkImageViewCreateInfo), ctypes.c_void_p, ctypes.POINTER(VkImageView)))

    imgci = VkImageCreateInfo(sType=14, pNext=None, flags=0, imageType=1, format=44,
        extent=VkExtent3D(PANEL_W,PANEL_H,1), mipLevels=1, arrayLayers=1, samples=1, tiling=0,
        usage=0x10|0x1, initialLayout=0)  # COLOR_ATTACHMENT|TRANSFER_SRC, TILING_OPTIMAL
    p.offImg = VkImage(0)
    vk_check(vkCreateImage(p.dev, ctypes.byref(imgci), None, ctypes.byref(p.offImg)), "vkCreateImage")
    mr = VkMemoryRequirements(); vkGetImageMemReq(p.dev, p.offImg, ctypes.byref(mr))
    mai = VkMemoryAllocateInfo(sType=5, pNext=None, allocationSize=mr.size, memoryTypeIndex=find_mem(mr.memoryTypeBits, 1))  # DEVICE_LOCAL
    p.offMem = VkDeviceMemory(0); vk_check(vkAllocMem(p.dev, ctypes.byref(mai), None, ctypes.byref(p.offMem)), "vkAllocMem")
    vk_check(vkBindImgMem(p.dev, p.offImg, p.offMem, 0), "vkBindImageMemory")

    ivci = VkImageViewCreateInfo(sType=15, pNext=None, flags=0, image=p.offImg, viewType=1, format=44,
        subresourceRange=VkImageSubresourceRange(1,0,1,0,1))
    p.offView = VkImageView(0)
    vk_check(vkCreateImageView_(p.dev, ctypes.byref(ivci), None, ctypes.byref(p.offView)), "vkCreateImageView")

    # Staging buffer
    vkCreateBuffer_ = _vk_d(p.dev, b"vkCreateBuffer", VkResult, (VkDevice, ctypes.POINTER(VkBufferCreateInfo), ctypes.c_void_p, ctypes.POINTER(VkBuffer_)))
    vkGetBufMemReq = _vk_d(p.dev, b"vkGetBufferMemoryRequirements", None, (VkDevice, VkBuffer_, ctypes.POINTER(VkMemoryRequirements)))
    vkBindBufMem = _vk_d(p.dev, b"vkBindBufferMemory", VkResult, (VkDevice, VkBuffer_, VkDeviceMemory, ctypes.c_uint64))

    bufSz = PANEL_W * PANEL_H * 4
    bci = VkBufferCreateInfo(sType=12, pNext=None, flags=0, size=bufSz, usage=2)  # TRANSFER_DST
    p.stagBuf = VkBuffer_(0); vk_check(vkCreateBuffer_(p.dev, ctypes.byref(bci), None, ctypes.byref(p.stagBuf)), "vkCreateBuffer")
    mr2 = VkMemoryRequirements(); vkGetBufMemReq(p.dev, p.stagBuf, ctypes.byref(mr2))
    mai2 = VkMemoryAllocateInfo(sType=5, pNext=None, allocationSize=mr2.size, memoryTypeIndex=find_mem(mr2.memoryTypeBits, 2|4))  # HOST_VISIBLE|COHERENT
    p.stagMem = VkDeviceMemory(0); vk_check(vkAllocMem(p.dev, ctypes.byref(mai2), None, ctypes.byref(p.stagMem)), "vkAllocMem stag")
    vk_check(vkBindBufMem(p.dev, p.stagBuf, p.stagMem, 0), "vkBindBufferMemory")

    # Render pass (finalLayout = TRANSFER_SRC_OPTIMAL = 6)
    vkCreateRenderPass_ = _vk_d(p.dev, b"vkCreateRenderPass", VkResult, (VkDevice, ctypes.POINTER(VkRenderPassCreateInfo), ctypes.c_void_p, ctypes.POINTER(VkRenderPass)))
    att = VkAttachmentDescription(flags=0, format=44, samples=1, loadOp=1, storeOp=0, stencilLoadOp=2, stencilStoreOp=1, initialLayout=0, finalLayout=6)
    ref = VkAttachmentReference(0, 2)  # COLOR_ATTACHMENT_OPTIMAL
    sub = VkSubpassDescription(flags=0, pipelineBindPoint=0, colorAttachmentCount=1, pColorAttachments=ctypes.pointer(ref))
    rpci = VkRenderPassCreateInfo(sType=38, pNext=None, flags=0, attachmentCount=1, pAttachments=ctypes.pointer(att), subpassCount=1, pSubpasses=ctypes.pointer(sub))
    p.renderPass = VkRenderPass(0); vk_check(vkCreateRenderPass_(p.dev, ctypes.byref(rpci), None, ctypes.byref(p.renderPass)), "vkCreateRenderPass")

    # Framebuffer
    vkCreateFramebuffer_ = _vk_d(p.dev, b"vkCreateFramebuffer", VkResult, (VkDevice, ctypes.POINTER(VkFramebufferCreateInfo), ctypes.c_void_p, ctypes.POINTER(VkFramebuffer_)))
    atts = (VkImageView * 1)(p.offView)
    fbci = VkFramebufferCreateInfo(sType=37, pNext=None, flags=0, renderPass=p.renderPass, attachmentCount=1, pAttachments=atts, width=PANEL_W, height=PANEL_H, layers=1)
    p.fb = VkFramebuffer_(0); vk_check(vkCreateFramebuffer_(p.dev, ctypes.byref(fbci), None, ctypes.byref(p.fb)), "vkCreateFramebuffer")

    # Pipeline
    vkCreateShaderModule_ = _vk_d(p.dev, b"vkCreateShaderModule", VkResult, (VkDevice, ctypes.POINTER(VkShaderModuleCreateInfo), ctypes.c_void_p, ctypes.POINTER(VkShaderModule)))
    vkCreatePipelineLayout_ = _vk_d(p.dev, b"vkCreatePipelineLayout", VkResult, (VkDevice, ctypes.POINTER(VkPipelineLayoutCreateInfo), ctypes.c_void_p, ctypes.POINTER(VkPipelineLayout)))
    vkCreateGraphicsPipelines_ = _vk_d(p.dev, b"vkCreateGraphicsPipelines", VkResult, (VkDevice, ctypes.c_uint64, ctypes.c_uint32, ctypes.POINTER(VkGraphicsPipelineCreateInfo), ctypes.c_void_p, ctypes.POINTER(VkPipeline_)))
    vkDestroyShaderModule_ = _vk_d(p.dev, b"vkDestroyShaderModule", None, (VkDevice, VkShaderModule, ctypes.c_void_p))

    def mk_sm(spv):
        u32 = (ctypes.c_uint32 * (len(spv)//4)).from_buffer_copy(spv)
        smci = VkShaderModuleCreateInfo(sType=16, pNext=None, flags=0, codeSize=len(spv), pCode=u32)
        m = VkShaderModule(0); vk_check(vkCreateShaderModule_(p.dev, ctypes.byref(smci), None, ctypes.byref(m)), "vkCreateShaderModule"); return m

    vm = mk_sm(vert_spv); fm = mk_sm(frag_spv)
    stages = (VkPipelineShaderStageCreateInfo * 2)(
        VkPipelineShaderStageCreateInfo(sType=18, stage=1, module=vm, pName=b"main"),
        VkPipelineShaderStageCreateInfo(sType=18, stage=0x10, module=fm, pName=b"main"))

    viState = VkPipelineVertexInputStateCreateInfo(sType=19)
    iaState = VkPipelineInputAssemblyStateCreateInfo(sType=20, topology=3)
    vp = VkViewport(0,0,float(PANEL_W),float(PANEL_H),0,1)
    scRect = VkRect2D(VkOffset2D(0,0), VkExtent2D(PANEL_W,PANEL_H))
    vpState = VkPipelineViewportStateCreateInfo(sType=22, viewportCount=1, pViewports=ctypes.pointer(vp), scissorCount=1, pScissors=ctypes.pointer(scRect))
    rsState = VkPipelineRasterizationStateCreateInfo(sType=23, polygonMode=0, cullMode=0, frontFace=1, lineWidth=1.0)
    msState = VkPipelineMultisampleStateCreateInfo(sType=24, rasterizationSamples=1)
    cbAtt = VkPipelineColorBlendAttachmentState(colorWriteMask=0xF)
    cbState = VkPipelineColorBlendStateCreateInfo(sType=26, attachmentCount=1, pAttachments=ctypes.pointer(cbAtt))

    plci = VkPipelineLayoutCreateInfo(sType=30)
    p.pipeLayout = VkPipelineLayout(0); vk_check(vkCreatePipelineLayout_(p.dev, ctypes.byref(plci), None, ctypes.byref(p.pipeLayout)), "vkCreatePipelineLayout")

    gpci = VkGraphicsPipelineCreateInfo(sType=28, stageCount=2, pStages=stages,
        pVertexInputState=ctypes.pointer(viState), pInputAssemblyState=ctypes.pointer(iaState),
        pViewportState=ctypes.pointer(vpState), pRasterizationState=ctypes.pointer(rsState),
        pMultisampleState=ctypes.pointer(msState), pColorBlendState=ctypes.pointer(cbState),
        layout=p.pipeLayout, renderPass=p.renderPass)
    p.pipeline = VkPipeline_(0); vk_check(vkCreateGraphicsPipelines_(p.dev, 0, 1, ctypes.byref(gpci), None, ctypes.byref(p.pipeline)), "vkCreateGraphicsPipelines")
    vkDestroyShaderModule_(p.dev, vm, None); vkDestroyShaderModule_(p.dev, fm, None)

    # Command pool / buffer / fence
    vkCreateCommandPool_ = _vk_d(p.dev, b"vkCreateCommandPool", VkResult, (VkDevice, ctypes.POINTER(VkCommandPoolCreateInfo), ctypes.c_void_p, ctypes.POINTER(VkCommandPool)))
    vkAllocateCommandBuffers_ = _vk_d(p.dev, b"vkAllocateCommandBuffers", VkResult, (VkDevice, ctypes.POINTER(VkCommandBufferAllocateInfo), ctypes.POINTER(VkCommandBuffer)))
    vkCreateFence_ = _vk_d(p.dev, b"vkCreateFence", VkResult, (VkDevice, ctypes.POINTER(VkFenceCreateInfo), ctypes.c_void_p, ctypes.POINTER(VkFence)))

    cpci = VkCommandPoolCreateInfo(sType=39, flags=2, queueFamilyIndex=p.qf)  # RESET_COMMAND_BUFFER
    p.cmdPool = VkCommandPool(); vk_check(vkCreateCommandPool_(p.dev, ctypes.byref(cpci), None, ctypes.byref(p.cmdPool)), "vkCreateCommandPool")
    cbai = VkCommandBufferAllocateInfo(sType=40, commandPool=p.cmdPool, level=0, commandBufferCount=1)
    p.cmdBuf = VkCommandBuffer(); vk_check(vkAllocateCommandBuffers_(p.dev, ctypes.byref(cbai), ctypes.byref(p.cmdBuf)), "vkAllocateCommandBuffers")
    fci = VkFenceCreateInfo(sType=8, flags=1)
    p.fence = VkFence(0); vk_check(vkCreateFence_(p.dev, ctypes.byref(fci), None, ctypes.byref(p.fence)), "vkCreateFence")

    # Store device functions for render loop
    p.vkWaitForFences = _vk_d(p.dev, b"vkWaitForFences", VkResult, (VkDevice, ctypes.c_uint32, ctypes.POINTER(VkFence), ctypes.c_uint32, ctypes.c_uint64))
    p.vkResetFences = _vk_d(p.dev, b"vkResetFences", VkResult, (VkDevice, ctypes.c_uint32, ctypes.POINTER(VkFence)))
    p.vkResetCommandBuffer = _vk_d(p.dev, b"vkResetCommandBuffer", VkResult, (VkCommandBuffer, ctypes.c_uint32))
    p.vkBeginCommandBuffer = _vk_d(p.dev, b"vkBeginCommandBuffer", VkResult, (VkCommandBuffer, ctypes.POINTER(VkCommandBufferBeginInfo)))
    p.vkEndCommandBuffer = _vk_d(p.dev, b"vkEndCommandBuffer", VkResult, (VkCommandBuffer,))
    p.vkCmdBeginRenderPass = _vk_d(p.dev, b"vkCmdBeginRenderPass", None, (VkCommandBuffer, ctypes.POINTER(VkRenderPassBeginInfo), ctypes.c_uint32))
    p.vkCmdEndRenderPass = _vk_d(p.dev, b"vkCmdEndRenderPass", None, (VkCommandBuffer,))
    p.vkCmdBindPipeline = _vk_d(p.dev, b"vkCmdBindPipeline", None, (VkCommandBuffer, ctypes.c_uint32, VkPipeline_))
    p.vkCmdDraw = _vk_d(p.dev, b"vkCmdDraw", None, (VkCommandBuffer, ctypes.c_uint32, ctypes.c_uint32, ctypes.c_uint32, ctypes.c_uint32))
    p.vkCmdCopyImageToBuffer = _vk_d(p.dev, b"vkCmdCopyImageToBuffer", None, (VkCommandBuffer, VkImage, ctypes.c_uint32, VkBuffer_, ctypes.c_uint32, ctypes.POINTER(VkBufferImageCopy)))
    p.vkQueueSubmit = _vk_d(p.dev, b"vkQueueSubmit", VkResult, (VkQueue, ctypes.c_uint32, ctypes.POINTER(VkSubmitInfo), VkFence))
    p.vkMapMemory = _vk_d(p.dev, b"vkMapMemory", VkResult, (VkDevice, VkDeviceMemory, ctypes.c_uint64, ctypes.c_uint64, ctypes.c_uint32, ctypes.POINTER(ctypes.c_void_p)))
    p.vkUnmapMemory = _vk_d(p.dev, b"vkUnmapMemory", None, (VkDevice, VkDeviceMemory))

    # D3D11 SwapChain + staging for VK panel
    p.sc = create_comp_swapchain(PANEL_W, PANEL_H)
    p.bb = swapchain_get_buffer(p.sc)
    p.stgTex = d3d_create_staging_tex(PANEL_W, PANEL_H)
    p.vis = create_dcomp_visual(p.sc, float(PANEL_W * 2))
    p.bufSz = bufSz

    log("Vulkan panel init ok")
    return p

def render_vulkan(p: VKPanel):
    fences = (VkFence * 1)(p.fence)
    p.vkWaitForFences(p.dev, 1, fences, 1, 0xFFFFFFFFFFFFFFFF)
    p.vkResetFences(p.dev, 1, fences)
    p.vkResetCommandBuffer(p.cmdBuf, 0)

    bi = VkCommandBufferBeginInfo(sType=42)
    p.vkBeginCommandBuffer(p.cmdBuf, ctypes.byref(bi))

    cv = VkClearValue(); cv.color = VkClearColorValue((ctypes.c_float*4)(0.15, 0.05, 0.05, 1.0))
    rpbi = VkRenderPassBeginInfo(sType=43, renderPass=p.renderPass, framebuffer=p.fb,
        renderArea=VkRect2D(VkOffset2D(0,0), VkExtent2D(PANEL_W,PANEL_H)),
        clearValueCount=1, pClearValues=ctypes.pointer(cv))
    p.vkCmdBeginRenderPass(p.cmdBuf, ctypes.byref(rpbi), 0)
    p.vkCmdBindPipeline(p.cmdBuf, 0, p.pipeline)
    p.vkCmdDraw(p.cmdBuf, 3, 1, 0, 0)
    p.vkCmdEndRenderPass(p.cmdBuf)

    region = VkBufferImageCopy(bufferRowLength=PANEL_W, bufferImageHeight=PANEL_H,
        imageSubresource=VkImageSubresourceLayers(1,0,0,1), imageExtent=VkExtent3D(PANEL_W,PANEL_H,1))
    p.vkCmdCopyImageToBuffer(p.cmdBuf, p.offImg, 6, p.stagBuf, 1, ctypes.byref(region))  # TRANSFER_SRC_OPTIMAL=6
    p.vkEndCommandBuffer(p.cmdBuf)

    cmds = (VkCommandBuffer * 1)(p.cmdBuf)
    si = VkSubmitInfo(sType=4, commandBufferCount=1, pCommandBuffers=cmds)
    p.vkQueueSubmit(p.queue, 1, ctypes.byref(si), p.fence)
    fences2 = (VkFence * 1)(p.fence)
    p.vkWaitForFences(p.dev, 1, fences2, 1, 0xFFFFFFFFFFFFFFFF)

    # Map VK staging -> D3D11 staging -> copy to back buffer
    vkData = ctypes.c_void_p(0)
    p.vkMapMemory(p.dev, p.stagMem, 0, p.bufSz, 0, ctypes.byref(vkData))
    mapped = ctx_map(p.stgTex)
    pitch = PANEL_W * 4
    for y in range(PANEL_H):
        ctypes.memmove(mapped.pData + y * mapped.RowPitch, vkData.value + y * pitch, pitch)
    ctx_unmap(p.stgTex)
    p.vkUnmapMemory(p.dev, p.stagMem)

    ctx_copy_resource(p.bb, p.stgTex)
    swapchain_present(p.sc)

# ============================================================
# Main
# ============================================================
def main():
    import faulthandler; faulthandler.enable()
    log("=== OpenGL + D3D11 + Vulkan via DirectComposition (Python) ===")

    hinst = create_window()
    create_d3d11_device()
    init_dcomp()

    gl_panel = None
    log("--- Init GL panel ---")
    try:
        gl_panel = init_gl_panel()
    except Exception as e:
        log(f"GL panel disabled: {e}")
        log("Hint: install vendor GPU driver / avoid RDP / ensure OpenGL extensions are available")
    log("--- Init D3D11 panel ---")
    dx_panel = init_d3d11_panel()
    log("--- Init Vulkan panel ---")
    vk_panel = init_vulkan_panel()

    dcomp_commit()
    log("DComp Commit - entering main loop")

    msg = MSG()
    first = True
    while not _g_quit:
        while user32.PeekMessageW(ctypes.byref(msg), None, 0, 0, PM_REMOVE):
            if msg.message == WM_QUIT: break
            user32.TranslateMessage(ctypes.byref(msg)); user32.DispatchMessageW(ctypes.byref(msg))
        if _g_quit or msg.message == WM_QUIT: break

        if gl_panel is not None:
            render_gl(gl_panel)
        render_d3d11(dx_panel)
        render_vulkan(vk_panel)

        if first:
            panel_count = 2 + (1 if gl_panel is not None else 0)
            log(f"First frame rendered ({panel_count} panels)")
            first = False
        time.sleep(0.001)

    log("=== END ===")

if __name__ == "__main__":
    try: main()
    except Exception:
        log("EXCEPTION:"); import traceback; traceback.print_exc()
