# -*- coding: utf-8 -*-
"""
Python (ctypes only) + DirectX 12
Pixel Shader Raymarching sample (IA input POSITION version)

Shader: hello.hlsl
  VSMain(float2 position : POSITION)
  PSMain(PSInput input)

ConstantBuffer b0:
  float iTime;
  float2 iResolution;
  float padding;
"""

import os
import time
import ctypes
from ctypes import wintypes

# ============================================================
# DLLs
# ============================================================
user32   = ctypes.WinDLL("user32",   use_last_error=True)
kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
ole32    = ctypes.WinDLL("ole32",    use_last_error=True)
dxgi     = ctypes.WinDLL("dxgi",     use_last_error=True)
d3d12    = ctypes.WinDLL("d3d12",    use_last_error=True)
try:
    d3dcompiler = ctypes.WinDLL("d3dcompiler_47", use_last_error=True)
except OSError:
    d3dcompiler = ctypes.WinDLL("d3dcompiler_43", use_last_error=True)

# ctypes.wintypes lacks some aliases depending on Python build
if not hasattr(wintypes, "HRESULT"):
    wintypes.HRESULT = ctypes.c_long
if not hasattr(wintypes, "SIZE_T"):
    wintypes.SIZE_T = ctypes.c_size_t
for _n in ("HICON", "HCURSOR", "HBRUSH"):
    if not hasattr(wintypes, _n):
        setattr(wintypes, _n, wintypes.HANDLE)

def debug(msg: str):
    print(f"[DEBUG] {msg}")

def winerr():
    return ctypes.WinError(ctypes.get_last_error())

def align_up(v: int, a: int) -> int:
    return (v + (a - 1)) & ~(a - 1)

# ============================================================
# Win32 constants / types
# ============================================================
LRESULT = wintypes.LPARAM
WNDPROC = ctypes.WINFUNCTYPE(LRESULT, wintypes.HWND, wintypes.UINT, wintypes.WPARAM, wintypes.LPARAM)

CS_HREDRAW = 0x0002
CS_VREDRAW = 0x0001

WS_OVERLAPPEDWINDOW = 0x00CF0000
CW_USEDEFAULT = 0x80000000
SW_SHOW = 5

WM_DESTROY = 0x0002
WM_PAINT   = 0x000F
WM_QUIT    = 0x0012
PM_REMOVE  = 0x0001

IDC_ARROW = 32512
INFINITE  = 0xFFFFFFFF

# ============================================================
# D3D12 / DXGI constants
# ============================================================
FRAME_COUNT = 2

DXGI_FORMAT_R8G8B8A8_UNORM = 28
DXGI_FORMAT_R32G32_FLOAT   = 16

DXGI_SWAP_EFFECT_FLIP_DISCARD = 4
DXGI_USAGE_RENDER_TARGET_OUTPUT = 0x20

D3D_FEATURE_LEVEL_12_0 = 0xC000

D3D12_COMMAND_LIST_TYPE_DIRECT = 0
D3D12_COMMAND_QUEUE_FLAG_NONE  = 0
D3D12_FENCE_FLAG_NONE          = 0

D3D12_DESCRIPTOR_HEAP_TYPE_RTV = 2
D3D12_DESCRIPTOR_HEAP_FLAG_NONE = 0

D3D12_RESOURCE_STATE_PRESENT       = 0
D3D12_RESOURCE_STATE_RENDER_TARGET = 4
D3D12_RESOURCE_STATE_GENERIC_READ  = 0x1

D3D12_HEAP_TYPE_UPLOAD  = 2
D3D12_RESOURCE_DIMENSION_BUFFER = 1
D3D12_TEXTURE_LAYOUT_ROW_MAJOR  = 1
D3D12_RESOURCE_FLAG_NONE        = 0
D3D12_HEAP_FLAG_NONE            = 0

D3D12_PRIMITIVE_TOPOLOGY_TYPE_TRIANGLE = 3
D3D_PRIMITIVE_TOPOLOGY_TRIANGLELIST    = 4

D3D12_FILL_MODE_SOLID = 3
D3D12_CULL_MODE_NONE  = 1

D3D12_BLEND_ONE  = 2
D3D12_BLEND_ZERO = 1
D3D12_BLEND_OP_ADD = 1
D3D12_LOGIC_OP_NOOP = 5
D3D12_COLOR_WRITE_ENABLE_ALL = 15

D3D12_RESOURCE_BARRIER_TYPE_TRANSITION  = 0
D3D12_RESOURCE_BARRIER_FLAG_NONE        = 0
D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES = 0xFFFFFFFF

# Root signature
D3D12_ROOT_SIGNATURE_FLAG_NONE = 0
D3D12_ROOT_SIGNATURE_FLAG_ALLOW_INPUT_ASSEMBLER_INPUT_LAYOUT = 0x1
D3D12_ROOT_PARAMETER_TYPE_CBV = 2
D3D12_SHADER_VISIBILITY_PIXEL = 5
D3D_ROOT_SIGNATURE_VERSION_1 = 1

# Input layout
D3D12_INPUT_CLASSIFICATION_PER_VERTEX_DATA = 0

# Shader compile flags
D3DCOMPILE_ENABLE_STRICTNESS = 0x00000002
D3DCOMPILE_DEBUG = 0x00000001
D3DCOMPILE_SKIP_OPTIMIZATION = 0x00000004

# ============================================================
# GUID helper
# ============================================================
class GUID(ctypes.Structure):
    _fields_ = [
        ("Data1", wintypes.DWORD),
        ("Data2", wintypes.WORD),
        ("Data3", wintypes.WORD),
        ("Data4", ctypes.c_ubyte * 8),
    ]

def guid_from_str(s: str) -> GUID:
    import uuid
    u = uuid.UUID(s)
    b = u.bytes_le
    g = GUID()
    ctypes.memmove(ctypes.byref(g), b, ctypes.sizeof(g))
    return g

IID_IDXGIFactory4   = guid_from_str("{1bc6ea02-ef36-464f-bf0c-21ca39e5168a}")
IID_IDXGISwapChain3 = guid_from_str("{94d99bdb-f1f8-4ab0-b236-7da0170edab1}")
IID_ID3D12Device    = guid_from_str("{189819f1-1db6-4b57-be54-1821339b85f7}")
IID_ID3D12Resource  = guid_from_str("{696442be-a72e-4059-bc79-5b5c98040fad}")
IID_ID3D12RootSignature = guid_from_str("{c54a6b66-72df-4ee8-8be5-a946a1429214}")
IID_ID3D12Debug     = guid_from_str("{344488b7-6846-474b-b989-f027448245e0}")
IID_ID3D12CommandQueue = guid_from_str("{0ec870a6-5d7e-4c22-8cfc-5baae07616ed}")
IID_ID3D12CommandAllocator = guid_from_str("{6102dee4-af59-4b09-b999-b44d73f09b24}")
IID_ID3D12GraphicsCommandList = guid_from_str("{5b160d0f-ac1b-4185-8ba8-b3ae42a5a455}")
IID_ID3D12DescriptorHeap = guid_from_str("{8efb471d-616c-4f49-90f7-127bb763fa51}")
IID_ID3D12PipelineState = guid_from_str("{765a30f3-f624-4c6f-a828-ace948622445}")
IID_ID3D12Fence = guid_from_str("{0a753dcf-c4d8-4b91-adf6-be5a60d95a76}")

# ============================================================
# Win32 structs
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

class RECT(ctypes.Structure):
    _fields_ = [("left", ctypes.c_long), ("top", ctypes.c_long),
                ("right", ctypes.c_long), ("bottom", ctypes.c_long)]

# ============================================================
# DXGI / D3D12 structs
# ============================================================
class DXGI_SAMPLE_DESC(ctypes.Structure):
    _fields_ = [("Count", wintypes.UINT), ("Quality", wintypes.UINT)]

class DXGI_SWAP_CHAIN_DESC1(ctypes.Structure):
    _fields_ = [
        ("Width", wintypes.UINT),
        ("Height", wintypes.UINT),
        ("Format", wintypes.UINT),
        ("Stereo", wintypes.BOOL),
        ("SampleDesc", DXGI_SAMPLE_DESC),
        ("BufferUsage", wintypes.UINT),
        ("BufferCount", wintypes.UINT),
        ("Scaling", wintypes.UINT),
        ("SwapEffect", wintypes.UINT),
        ("AlphaMode", wintypes.UINT),
        ("Flags", wintypes.UINT),
    ]

class D3D12_COMMAND_QUEUE_DESC(ctypes.Structure):
    _fields_ = [
        ("Type", wintypes.UINT),
        ("Priority", ctypes.c_int),
        ("Flags", wintypes.UINT),
        ("NodeMask", wintypes.UINT),
    ]

class D3D12_DESCRIPTOR_HEAP_DESC(ctypes.Structure):
    _fields_ = [
        ("Type", wintypes.UINT),
        ("NumDescriptors", wintypes.UINT),
        ("Flags", wintypes.UINT),
        ("NodeMask", wintypes.UINT),
    ]

class D3D12_CPU_DESCRIPTOR_HANDLE(ctypes.Structure):
    _fields_ = [("ptr", ctypes.c_size_t)]

class D3D12_HEAP_PROPERTIES(ctypes.Structure):
    _fields_ = [
        ("Type", wintypes.UINT),
        ("CPUPageProperty", wintypes.UINT),
        ("MemoryPoolPreference", wintypes.UINT),
        ("CreationNodeMask", wintypes.UINT),
        ("VisibleNodeMask", wintypes.UINT),
    ]

class D3D12_RESOURCE_DESC(ctypes.Structure):
    _fields_ = [
        ("Dimension", wintypes.UINT),
        ("Alignment", ctypes.c_uint64),
        ("Width", ctypes.c_uint64),
        ("Height", wintypes.UINT),
        ("DepthOrArraySize", wintypes.WORD),
        ("MipLevels", wintypes.WORD),
        ("Format", wintypes.UINT),
        ("SampleDesc", DXGI_SAMPLE_DESC),
        ("Layout", wintypes.UINT),
        ("Flags", wintypes.UINT),
    ]

class D3D12_RANGE(ctypes.Structure):
    _fields_ = [("Begin", ctypes.c_size_t), ("End", ctypes.c_size_t)]

class D3D12_VIEWPORT(ctypes.Structure):
    _fields_ = [
        ("TopLeftX", ctypes.c_float),
        ("TopLeftY", ctypes.c_float),
        ("Width", ctypes.c_float),
        ("Height", ctypes.c_float),
        ("MinDepth", ctypes.c_float),
        ("MaxDepth", ctypes.c_float),
    ]

class D3D12_RECT(ctypes.Structure):
    _fields_ = [("left", ctypes.c_long), ("top", ctypes.c_long),
                ("right", ctypes.c_long), ("bottom", ctypes.c_long)]

class D3D12_RESOURCE_TRANSITION_BARRIER(ctypes.Structure):
    _fields_ = [
        ("pResource", ctypes.c_void_p),
        ("Subresource", wintypes.UINT),
        ("StateBefore", wintypes.UINT),
        ("StateAfter", wintypes.UINT),
    ]

class D3D12_RESOURCE_BARRIER_UNION(ctypes.Union):
    _fields_ = [
        ("Transition", D3D12_RESOURCE_TRANSITION_BARRIER),
        ("_padding", ctypes.c_ubyte * 24),
    ]

class D3D12_RESOURCE_BARRIER(ctypes.Structure):
    _fields_ = [
        ("Type", wintypes.UINT),
        ("Flags", wintypes.UINT),
        ("u", D3D12_RESOURCE_BARRIER_UNION),
    ]

# ---- Root signature ----
class D3D12_ROOT_DESCRIPTOR(ctypes.Structure):
    _fields_ = [("ShaderRegister", wintypes.UINT), ("RegisterSpace", wintypes.UINT)]

class D3D12_ROOT_PARAMETER_UNION(ctypes.Union):
    _fields_ = [
        ("Descriptor", D3D12_ROOT_DESCRIPTOR),
        ("_bytes", ctypes.c_ubyte * 16),
    ]

class D3D12_ROOT_PARAMETER(ctypes.Structure):
    _fields_ = [
        ("ParameterType", wintypes.UINT),
        ("_pad0", wintypes.UINT),
        ("u", D3D12_ROOT_PARAMETER_UNION),
        ("ShaderVisibility", wintypes.UINT),
        ("_pad1", wintypes.UINT),
    ]

class D3D12_ROOT_SIGNATURE_DESC(ctypes.Structure):
    _fields_ = [
        ("NumParameters", wintypes.UINT),
        ("pParameters", ctypes.c_void_p),
        ("NumStaticSamplers", wintypes.UINT),
        ("pStaticSamplers", ctypes.c_void_p),
        ("Flags", wintypes.UINT),
    ]

# ---- Input layout / VB view ----
class D3D12_INPUT_ELEMENT_DESC(ctypes.Structure):
    _fields_ = [
        ("SemanticName", ctypes.c_char_p),
        ("SemanticIndex", wintypes.UINT),
        ("Format", wintypes.UINT),
        ("InputSlot", wintypes.UINT),
        ("AlignedByteOffset", wintypes.UINT),
        ("InputSlotClass", wintypes.UINT),
        ("InstanceDataStepRate", wintypes.UINT),
    ]

class D3D12_VERTEX_BUFFER_VIEW(ctypes.Structure):
    _fields_ = [
        ("BufferLocation", ctypes.c_uint64),
        ("SizeInBytes", wintypes.UINT),
        ("StrideInBytes", wintypes.UINT),
    ]

# ---- PSO structs ----
class D3D12_INPUT_LAYOUT_DESC(ctypes.Structure):
    _fields_ = [("pInputElementDescs", ctypes.c_void_p), ("NumElements", wintypes.UINT)]

class D3D12_SHADER_BYTECODE(ctypes.Structure):
    _fields_ = [("pShaderBytecode", ctypes.c_void_p), ("BytecodeLength", ctypes.c_size_t)]

class D3D12_RASTERIZER_DESC(ctypes.Structure):
    _fields_ = [
        ("FillMode", wintypes.UINT),
        ("CullMode", wintypes.UINT),
        ("FrontCounterClockwise", wintypes.BOOL),
        ("DepthBias", ctypes.c_int),
        ("DepthBiasClamp", ctypes.c_float),
        ("SlopeScaledDepthBias", ctypes.c_float),
        ("DepthClipEnable", wintypes.BOOL),
        ("MultisampleEnable", wintypes.BOOL),
        ("AntialiasedLineEnable", wintypes.BOOL),
        ("ForcedSampleCount", wintypes.UINT),
        ("ConservativeRaster", wintypes.UINT),
    ]

class D3D12_RENDER_TARGET_BLEND_DESC(ctypes.Structure):
    _fields_ = [
        ("BlendEnable", wintypes.BOOL),
        ("LogicOpEnable", wintypes.BOOL),
        ("SrcBlend", wintypes.UINT),
        ("DestBlend", wintypes.UINT),
        ("BlendOp", wintypes.UINT),
        ("SrcBlendAlpha", wintypes.UINT),
        ("DestBlendAlpha", wintypes.UINT),
        ("BlendOpAlpha", wintypes.UINT),
        ("LogicOp", wintypes.UINT),
        ("RenderTargetWriteMask", ctypes.c_ubyte),
    ]

class D3D12_BLEND_DESC(ctypes.Structure):
    _fields_ = [
        ("AlphaToCoverageEnable", wintypes.BOOL),
        ("IndependentBlendEnable", wintypes.BOOL),
        ("RenderTarget", D3D12_RENDER_TARGET_BLEND_DESC * 8),
    ]

class D3D12_DEPTH_STENCILOP_DESC(ctypes.Structure):
    _fields_ = [
        ("StencilFailOp", wintypes.UINT),
        ("StencilDepthFailOp", wintypes.UINT),
        ("StencilPassOp", wintypes.UINT),
        ("StencilFunc", wintypes.UINT),
    ]

class D3D12_DEPTH_STENCIL_DESC(ctypes.Structure):
    _fields_ = [
        ("DepthEnable", wintypes.BOOL),
        ("DepthWriteMask", wintypes.UINT),
        ("DepthFunc", wintypes.UINT),
        ("StencilEnable", wintypes.BOOL),
        ("StencilReadMask", ctypes.c_ubyte),
        ("StencilWriteMask", ctypes.c_ubyte),
        ("FrontFace", D3D12_DEPTH_STENCILOP_DESC),
        ("BackFace", D3D12_DEPTH_STENCILOP_DESC),
    ]

class D3D12_CACHED_PIPELINE_STATE(ctypes.Structure):
    _fields_ = [("pCachedBlob", ctypes.c_void_p), ("CachedBlobSizeInBytes", ctypes.c_size_t)]

class D3D12_STREAM_OUTPUT_DESC(ctypes.Structure):
    _fields_ = [
        ("pSODeclaration", ctypes.c_void_p),
        ("NumEntries", wintypes.UINT),
        ("pBufferStrides", ctypes.c_void_p),
        ("NumStrides", wintypes.UINT),
        ("RasterizedStream", wintypes.UINT),
    ]

class D3D12_GRAPHICS_PIPELINE_STATE_DESC(ctypes.Structure):
    _fields_ = [
        ("pRootSignature", ctypes.c_void_p),
        ("VS", D3D12_SHADER_BYTECODE),
        ("PS", D3D12_SHADER_BYTECODE),
        ("DS", D3D12_SHADER_BYTECODE),
        ("HS", D3D12_SHADER_BYTECODE),
        ("GS", D3D12_SHADER_BYTECODE),
        ("StreamOutput", D3D12_STREAM_OUTPUT_DESC),
        ("BlendState", D3D12_BLEND_DESC),
        ("SampleMask", wintypes.UINT),
        ("RasterizerState", D3D12_RASTERIZER_DESC),
        ("DepthStencilState", D3D12_DEPTH_STENCIL_DESC),
        ("InputLayout", D3D12_INPUT_LAYOUT_DESC),
        ("IBStripCutValue", wintypes.UINT),
        ("PrimitiveTopologyType", wintypes.UINT),
        ("NumRenderTargets", wintypes.UINT),
        ("RTVFormats", wintypes.UINT * 8),
        ("DSVFormat", wintypes.UINT),
        ("SampleDesc", DXGI_SAMPLE_DESC),
        ("NodeMask", wintypes.UINT),
        ("CachedPSO", D3D12_CACHED_PIPELINE_STATE),
        ("Flags", wintypes.UINT),
    ]

# ============================================================
# Constant buffer struct (MUST match your HLSL layout)
#   float iTime;
#   float2 iResolution;
#   float padding;
# ============================================================
class CBParams(ctypes.Structure):
    _fields_ = [
        ("iTime",        ctypes.c_float),
        ("iResolutionX", ctypes.c_float),
        ("iResolutionY", ctypes.c_float),
        ("_pad",         ctypes.c_float),
    ]

# ============================================================
# Win32 prototypes
# ============================================================
kernel32.GetModuleHandleW.restype = wintypes.HMODULE
kernel32.GetModuleHandleW.argtypes = (wintypes.LPCWSTR,)

kernel32.CreateEventW.restype = wintypes.HANDLE
kernel32.CreateEventW.argtypes = (ctypes.c_void_p, wintypes.BOOL, wintypes.BOOL, wintypes.LPCWSTR)

kernel32.WaitForSingleObject.restype = wintypes.DWORD
kernel32.WaitForSingleObject.argtypes = (wintypes.HANDLE, wintypes.DWORD)

kernel32.CloseHandle.restype = wintypes.BOOL
kernel32.CloseHandle.argtypes = (wintypes.HANDLE,)

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

user32.LoadCursorW.restype = wintypes.HCURSOR
user32.LoadCursorW.argtypes = (wintypes.HINSTANCE, wintypes.LPCWSTR)

user32.GetClientRect.restype = wintypes.BOOL
user32.GetClientRect.argtypes = (wintypes.HWND, ctypes.POINTER(RECT))

# ============================================================
# D3D12 / DXGI / D3DCompiler prototypes
# ============================================================
CreateDXGIFactory1 = dxgi.CreateDXGIFactory1
CreateDXGIFactory1.restype = wintypes.HRESULT
CreateDXGIFactory1.argtypes = (ctypes.POINTER(GUID), ctypes.POINTER(ctypes.c_void_p))

D3D12CreateDevice = d3d12.D3D12CreateDevice
D3D12CreateDevice.restype = wintypes.HRESULT
D3D12CreateDevice.argtypes = (ctypes.c_void_p, wintypes.UINT, ctypes.POINTER(GUID), ctypes.POINTER(ctypes.c_void_p))

D3D12GetDebugInterface = d3d12.D3D12GetDebugInterface
D3D12GetDebugInterface.restype = wintypes.HRESULT
D3D12GetDebugInterface.argtypes = (ctypes.POINTER(GUID), ctypes.POINTER(ctypes.c_void_p))

D3D12SerializeRootSignature = d3d12.D3D12SerializeRootSignature
D3D12SerializeRootSignature.restype = wintypes.HRESULT
D3D12SerializeRootSignature.argtypes = (
    ctypes.POINTER(D3D12_ROOT_SIGNATURE_DESC),
    wintypes.UINT,
    ctypes.POINTER(ctypes.c_void_p),
    ctypes.POINTER(ctypes.c_void_p),
)

D3DCompileFromFile = d3dcompiler.D3DCompileFromFile
D3DCompileFromFile.restype = wintypes.HRESULT
D3DCompileFromFile.argtypes = (
    wintypes.LPCWSTR,
    ctypes.c_void_p,
    ctypes.c_void_p,
    ctypes.c_char_p,
    ctypes.c_char_p,
    wintypes.UINT,
    wintypes.UINT,
    ctypes.POINTER(ctypes.c_void_p),
    ctypes.POINTER(ctypes.c_void_p),
)

# ============================================================
# COM vtbl helpers (indices are from vtable.txt)
# ============================================================
def com_method(obj_ptr, index: int, restype, argtypes):
    if not obj_ptr:
        raise RuntimeError("com_method: null this")
    this = obj_ptr if isinstance(obj_ptr, ctypes.c_void_p) else ctypes.c_void_p(int(obj_ptr))
    vtbl = ctypes.cast(this, ctypes.POINTER(ctypes.POINTER(ctypes.c_void_p)))[0]
    fn = ctypes.cast(vtbl[index], ctypes.c_void_p).value
    proto = ctypes.WINFUNCTYPE(restype, *argtypes)
    return proto(fn)

def com_release(obj_ptr):
    if not obj_ptr:
        return
    rel = com_method(obj_ptr, 2, wintypes.ULONG, (ctypes.c_void_p,))
    rel(obj_ptr if isinstance(obj_ptr, ctypes.c_void_p) else ctypes.c_void_p(int(obj_ptr)))

def blob_ptr(blob) -> ctypes.c_void_p:
    # ID3DBlob::GetBufferPointer index 3
    return com_method(blob, 3, ctypes.c_void_p, (ctypes.c_void_p,))(
        blob if isinstance(blob, ctypes.c_void_p) else ctypes.c_void_p(int(blob))
    )

def blob_size(blob) -> int:
    # ID3DBlob::GetBufferSize index 4
    return int(com_method(blob, 4, ctypes.c_size_t, (ctypes.c_void_p,))(
        blob if isinstance(blob, ctypes.c_void_p) else ctypes.c_void_p(int(blob))
    ))

# ============================================================
# Globals
# ============================================================
g_hwnd = None
g_width = 640
g_height = 480

g_factory = ctypes.c_void_p()
g_device = ctypes.c_void_p()
g_command_queue = ctypes.c_void_p()
g_swap_chain = ctypes.c_void_p()

g_rtv_heap = ctypes.c_void_p()
g_rtv_descriptor_size = 0

# store addresses (int) in c_void_p arrays
g_render_targets = (ctypes.c_void_p * FRAME_COUNT)()
g_command_allocators = (ctypes.c_void_p * FRAME_COUNT)()

g_command_list = ctypes.c_void_p()
g_root_signature = ctypes.c_void_p()
g_pipeline_state = ctypes.c_void_p()

g_fence = ctypes.c_void_p()
g_fence_event = None
g_fence_values = [1, 1]
g_frame_index = 0

# constant buffer
g_cb_resource = ctypes.c_void_p()
g_cb_mapped_ptr = ctypes.c_void_p()
g_cb_gpu_va = 0
g_start_time = 0.0
g_root_params = None

# vertex buffer (POSITION float2 x 3)
g_vb_resource = ctypes.c_void_p()
g_vb_mapped_ptr = ctypes.c_void_p()
g_vb_view = D3D12_VERTEX_BUFFER_VIEW()

# input layout keep-alives
g_sem_position = None
g_input_elems = None

# ============================================================
# Debug layer
# ============================================================
def enable_debug_layer():
    dbg = ctypes.c_void_p()
    hr = D3D12GetDebugInterface(ctypes.byref(IID_ID3D12Debug), ctypes.byref(dbg))
    if hr == 0 and dbg:
        # ID3D12Debug::EnableDebugLayer index 3
        enable = com_method(dbg, 3, None, (ctypes.c_void_p,))
        enable(dbg)
        com_release(dbg)
        debug("D3D12 Debug Layer ENABLED")
    else:
        debug("D3D12 Debug Layer NOT available")

# ============================================================
# Shader compile
# ============================================================
def compile_hlsl_from_file(path: str, entry: str, target: str) -> ctypes.c_void_p:
    if not os.path.isfile(path):
        raise FileNotFoundError(path)

    code = ctypes.c_void_p()
    err  = ctypes.c_void_p()
    flags1 = D3DCOMPILE_ENABLE_STRICTNESS | D3DCOMPILE_DEBUG | D3DCOMPILE_SKIP_OPTIMIZATION

    hr = D3DCompileFromFile(
        path,
        None,
        None,
        entry.encode("ascii"),
        target.encode("ascii"),
        flags1,
        0,
        ctypes.byref(code),
        ctypes.byref(err),
    )
    if hr != 0:
        msg = f"D3DCompileFromFile failed: {os.path.basename(path)} {entry} {target}"
        if err:
            p = blob_ptr(err)
            n = blob_size(err)
            if p and n:
                msg = ctypes.string_at(p, n).decode("utf-8", "replace")
            com_release(err)
        raise RuntimeError(msg)
    if err:
        com_release(err)
    return code

# ============================================================
# D3D12 init
# ============================================================
def init_d3d12():
    global g_width, g_height
    global g_factory, g_device, g_command_queue, g_swap_chain
    global g_rtv_heap, g_rtv_descriptor_size, g_frame_index
    global g_root_signature, g_pipeline_state, g_command_list
    global g_fence, g_fence_event, g_start_time
    global g_cb_resource, g_cb_mapped_ptr, g_cb_gpu_va
    global g_root_params
    global g_vb_resource, g_vb_mapped_ptr, g_vb_view
    global g_sem_position, g_input_elems

    debug("=== Initializing D3D12 ===")
    enable_debug_layer()

    # client size
    rc = RECT()
    if not user32.GetClientRect(g_hwnd, ctypes.byref(rc)):
        raise winerr()
    g_width  = max(1, rc.right - rc.left)
    g_height = max(1, rc.bottom - rc.top)

    # factory
    hr = CreateDXGIFactory1(ctypes.byref(IID_IDXGIFactory4), ctypes.byref(g_factory))
    if hr != 0:
        raise RuntimeError(f"CreateDXGIFactory1 failed: 0x{hr & 0xFFFFFFFF:08X}")

    # device
    hr = D3D12CreateDevice(None, D3D_FEATURE_LEVEL_12_0, ctypes.byref(IID_ID3D12Device), ctypes.byref(g_device))
    if hr != 0:
        raise RuntimeError(f"D3D12CreateDevice failed: 0x{hr & 0xFFFFFFFF:08X}")

    # CreateCommandQueue index 8
    queue_desc = D3D12_COMMAND_QUEUE_DESC()
    queue_desc.Type = D3D12_COMMAND_LIST_TYPE_DIRECT
    queue_desc.Priority = 0
    queue_desc.Flags = D3D12_COMMAND_QUEUE_FLAG_NONE
    queue_desc.NodeMask = 0

    create_queue = com_method(
        g_device, 8, wintypes.HRESULT,
        (ctypes.c_void_p, ctypes.POINTER(D3D12_COMMAND_QUEUE_DESC), ctypes.POINTER(GUID), ctypes.POINTER(ctypes.c_void_p))
    )
    hr = create_queue(g_device, ctypes.byref(queue_desc), ctypes.byref(IID_ID3D12CommandQueue), ctypes.byref(g_command_queue))
    if hr != 0:
        raise RuntimeError(f"CreateCommandQueue failed: 0x{hr & 0xFFFFFFFF:08X}")

    # CreateSwapChainForHwnd index 15 (IDXGIFactory)
    swap_desc = DXGI_SWAP_CHAIN_DESC1()
    swap_desc.Width = g_width
    swap_desc.Height = g_height
    swap_desc.Format = DXGI_FORMAT_R8G8B8A8_UNORM
    swap_desc.Stereo = False
    swap_desc.SampleDesc.Count = 1
    swap_desc.SampleDesc.Quality = 0
    swap_desc.BufferUsage = DXGI_USAGE_RENDER_TARGET_OUTPUT
    swap_desc.BufferCount = FRAME_COUNT
    swap_desc.Scaling = 0
    swap_desc.SwapEffect = DXGI_SWAP_EFFECT_FLIP_DISCARD
    swap_desc.AlphaMode = 0
    swap_desc.Flags = 0

    create_sc = com_method(
        g_factory, 15, wintypes.HRESULT,
        (ctypes.c_void_p, ctypes.c_void_p, wintypes.HWND,
         ctypes.POINTER(DXGI_SWAP_CHAIN_DESC1), ctypes.c_void_p, ctypes.c_void_p,
         ctypes.POINTER(ctypes.c_void_p))
    )
    temp_sc = ctypes.c_void_p()
    hr = create_sc(g_factory, g_command_queue, g_hwnd, ctypes.byref(swap_desc), None, None, ctypes.byref(temp_sc))
    if hr != 0:
        raise RuntimeError(f"CreateSwapChainForHwnd failed: 0x{hr & 0xFFFFFFFF:08X}")

    # QueryInterface IDXGISwapChain3
    qi = com_method(temp_sc, 0, wintypes.HRESULT, (ctypes.c_void_p, ctypes.POINTER(GUID), ctypes.POINTER(ctypes.c_void_p)))
    hr = qi(temp_sc, ctypes.byref(IID_IDXGISwapChain3), ctypes.byref(g_swap_chain))
    com_release(temp_sc)
    if hr != 0:
        raise RuntimeError(f"QueryInterface IDXGISwapChain3 failed: 0x{hr & 0xFFFFFFFF:08X}")

    # GetCurrentBackBufferIndex index 36
    get_idx = com_method(g_swap_chain, 36, wintypes.UINT, (ctypes.c_void_p,))
    g_frame_index = int(get_idx(g_swap_chain))

    # RTV heap CreateDescriptorHeap index 14
    rtv_heap_desc = D3D12_DESCRIPTOR_HEAP_DESC()
    rtv_heap_desc.Type = D3D12_DESCRIPTOR_HEAP_TYPE_RTV
    rtv_heap_desc.NumDescriptors = FRAME_COUNT
    rtv_heap_desc.Flags = D3D12_DESCRIPTOR_HEAP_FLAG_NONE
    rtv_heap_desc.NodeMask = 0

    create_heap = com_method(
        g_device, 14, wintypes.HRESULT,
        (ctypes.c_void_p, ctypes.POINTER(D3D12_DESCRIPTOR_HEAP_DESC), ctypes.POINTER(GUID), ctypes.POINTER(ctypes.c_void_p))
    )
    hr = create_heap(g_device, ctypes.byref(rtv_heap_desc), ctypes.byref(IID_ID3D12DescriptorHeap), ctypes.byref(g_rtv_heap))
    if hr != 0:
        raise RuntimeError(f"CreateDescriptorHeap(RTV) failed: 0x{hr & 0xFFFFFFFF:08X}")

    # GetDescriptorHandleIncrementSize index 15
    get_inc = com_method(g_device, 15, wintypes.UINT, (ctypes.c_void_p, wintypes.UINT))
    g_rtv_descriptor_size = int(get_inc(g_device, D3D12_DESCRIPTOR_HEAP_TYPE_RTV))

    # GetCPUDescriptorHandleForHeapStart index 9
    get_cpu_handle = com_method(g_rtv_heap, 9, None, (ctypes.c_void_p, ctypes.POINTER(D3D12_CPU_DESCRIPTOR_HANDLE)))
    rtv_start = D3D12_CPU_DESCRIPTOR_HANDLE()
    get_cpu_handle(g_rtv_heap, ctypes.byref(rtv_start))

    # GetBuffer index 9
    get_buffer = com_method(
        g_swap_chain, 9, wintypes.HRESULT,
        (ctypes.c_void_p, wintypes.UINT, ctypes.POINTER(GUID), ctypes.POINTER(ctypes.c_void_p))
    )
    # CreateRenderTargetView index 20
    create_rtv = com_method(
        g_device, 20, None,
        (ctypes.c_void_p, ctypes.c_void_p, ctypes.c_void_p, D3D12_CPU_DESCRIPTOR_HANDLE)
    )

    for i in range(FRAME_COUNT):
        rt = ctypes.c_void_p()
        hr = get_buffer(g_swap_chain, i, ctypes.byref(IID_ID3D12Resource), ctypes.byref(rt))
        if hr != 0:
            raise RuntimeError(f"GetBuffer({i}) failed: 0x{hr & 0xFFFFFFFF:08X}")

        g_render_targets[i] = rt.value
        handle = D3D12_CPU_DESCRIPTOR_HANDLE(rtv_start.ptr + i * g_rtv_descriptor_size)
        create_rtv(g_device, ctypes.c_void_p(int(g_render_targets[i])), None, handle)

    # CreateCommandAllocator index 9
    create_ca = com_method(
        g_device, 9, wintypes.HRESULT,
        (ctypes.c_void_p, wintypes.UINT, ctypes.POINTER(GUID), ctypes.POINTER(ctypes.c_void_p))
    )
    for i in range(FRAME_COUNT):
        ca = ctypes.c_void_p()
        hr = create_ca(g_device, D3D12_COMMAND_LIST_TYPE_DIRECT, ctypes.byref(IID_ID3D12CommandAllocator), ctypes.byref(ca))
        if hr != 0:
            raise RuntimeError(f"CreateCommandAllocator({i}) failed: 0x{hr & 0xFFFFFFFF:08X}")
        g_command_allocators[i] = ca.value

    # RootSignature: one CBV(b0) visible to Pixel
    if ctypes.sizeof(D3D12_ROOT_PARAMETER) != 32:
        raise RuntimeError(f"Bad D3D12_ROOT_PARAMETER size: {ctypes.sizeof(D3D12_ROOT_PARAMETER)} (expected 32)")

    root_param = D3D12_ROOT_PARAMETER()
    root_param.ParameterType = D3D12_ROOT_PARAMETER_TYPE_CBV
    root_param._pad0 = 0
    root_param.u.Descriptor = D3D12_ROOT_DESCRIPTOR(0, 0)  # b0
    root_param.ShaderVisibility = D3D12_SHADER_VISIBILITY_PIXEL
    root_param._pad1 = 0

    g_root_params = (D3D12_ROOT_PARAMETER * 1)(root_param)

    rs_desc = D3D12_ROOT_SIGNATURE_DESC()
    rs_desc.NumParameters = 1
    rs_desc.pParameters = ctypes.cast(g_root_params, ctypes.c_void_p)
    rs_desc.NumStaticSamplers = 0
    rs_desc.pStaticSamplers = None
    rs_desc.Flags = D3D12_ROOT_SIGNATURE_FLAG_ALLOW_INPUT_ASSEMBLER_INPUT_LAYOUT

    rs_blob = ctypes.c_void_p()
    err_blob = ctypes.c_void_p()
    hr = D3D12SerializeRootSignature(ctypes.byref(rs_desc), D3D_ROOT_SIGNATURE_VERSION_1, ctypes.byref(rs_blob), ctypes.byref(err_blob))
    if hr != 0:
        msg = "D3D12SerializeRootSignature failed"
        if err_blob:
            msg = ctypes.string_at(blob_ptr(err_blob), blob_size(err_blob)).decode("utf-8", "replace")
            com_release(err_blob)
        raise RuntimeError(msg)
    if err_blob:
        com_release(err_blob)

    # CreateRootSignature index 16
    create_rs = com_method(
        g_device, 16, wintypes.HRESULT,
        (ctypes.c_void_p, wintypes.UINT, ctypes.c_void_p, ctypes.c_size_t, ctypes.POINTER(GUID), ctypes.POINTER(ctypes.c_void_p))
    )
    hr = create_rs(g_device, 0, blob_ptr(rs_blob), blob_size(rs_blob), ctypes.byref(IID_ID3D12RootSignature), ctypes.byref(g_root_signature))
    com_release(rs_blob)
    if hr != 0:
        raise RuntimeError(f"CreateRootSignature failed: 0x{hr & 0xFFFFFFFF:08X}")

    # Compile shaders from external hello.hlsl
    hlsl_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "hello.hlsl")
    vs_blob = compile_hlsl_from_file(hlsl_path, "VSMain", "vs_5_0")
    ps_blob = compile_hlsl_from_file(hlsl_path, "PSMain", "ps_5_0")

    # ----------------------------
    # InputLayout for VSMain(float2 position : POSITION)
    # ----------------------------
    g_sem_position = ctypes.create_string_buffer(b"POSITION")
    elem = D3D12_INPUT_ELEMENT_DESC()
    elem.SemanticName = ctypes.cast(g_sem_position, ctypes.c_char_p)
    elem.SemanticIndex = 0
    elem.Format = DXGI_FORMAT_R32G32_FLOAT
    elem.InputSlot = 0
    elem.AlignedByteOffset = 0
    elem.InputSlotClass = D3D12_INPUT_CLASSIFICATION_PER_VERTEX_DATA
    elem.InstanceDataStepRate = 0
    g_input_elems = (D3D12_INPUT_ELEMENT_DESC * 1)(elem)

    # PSO CreateGraphicsPipelineState index 10
    pso_desc = D3D12_GRAPHICS_PIPELINE_STATE_DESC()
    ctypes.memset(ctypes.byref(pso_desc), 0, ctypes.sizeof(pso_desc))

    pso_desc.pRootSignature = g_root_signature.value
    pso_desc.VS.pShaderBytecode = blob_ptr(vs_blob)
    pso_desc.VS.BytecodeLength  = blob_size(vs_blob)
    pso_desc.PS.pShaderBytecode = blob_ptr(ps_blob)
    pso_desc.PS.BytecodeLength  = blob_size(ps_blob)

    # Blend (no blend)
    pso_desc.BlendState.AlphaToCoverageEnable = False
    pso_desc.BlendState.IndependentBlendEnable = False
    rt0 = pso_desc.BlendState.RenderTarget[0]
    rt0.BlendEnable = False
    rt0.LogicOpEnable = False
    rt0.SrcBlend = D3D12_BLEND_ONE
    rt0.DestBlend = D3D12_BLEND_ZERO
    rt0.BlendOp = D3D12_BLEND_OP_ADD
    rt0.SrcBlendAlpha = D3D12_BLEND_ONE
    rt0.DestBlendAlpha = D3D12_BLEND_ZERO
    rt0.BlendOpAlpha = D3D12_BLEND_OP_ADD
    rt0.LogicOp = D3D12_LOGIC_OP_NOOP
    rt0.RenderTargetWriteMask = D3D12_COLOR_WRITE_ENABLE_ALL

    pso_desc.SampleMask = 0xFFFFFFFF

    # Rasterizer
    pso_desc.RasterizerState.FillMode = D3D12_FILL_MODE_SOLID
    pso_desc.RasterizerState.CullMode = D3D12_CULL_MODE_NONE
    pso_desc.RasterizerState.FrontCounterClockwise = False
    pso_desc.RasterizerState.DepthClipEnable = True

    # Depth/stencil off
    pso_desc.DepthStencilState.DepthEnable = False
    pso_desc.DepthStencilState.StencilEnable = False

    # Input layout (IMPORTANT)
    pso_desc.InputLayout.pInputElementDescs = ctypes.cast(g_input_elems, ctypes.c_void_p)
    pso_desc.InputLayout.NumElements = 1

    pso_desc.PrimitiveTopologyType = D3D12_PRIMITIVE_TOPOLOGY_TYPE_TRIANGLE
    pso_desc.NumRenderTargets = 1
    pso_desc.RTVFormats[0] = DXGI_FORMAT_R8G8B8A8_UNORM
    pso_desc.SampleDesc.Count = 1
    pso_desc.SampleDesc.Quality = 0

    create_pso = com_method(
        g_device, 10, wintypes.HRESULT,
        (ctypes.c_void_p, ctypes.POINTER(D3D12_GRAPHICS_PIPELINE_STATE_DESC), ctypes.POINTER(GUID), ctypes.POINTER(ctypes.c_void_p))
    )
    hr = create_pso(g_device, ctypes.byref(pso_desc), ctypes.byref(IID_ID3D12PipelineState), ctypes.byref(g_pipeline_state))
    com_release(vs_blob)
    com_release(ps_blob)
    if hr != 0:
        raise RuntimeError(f"CreateGraphicsPipelineState failed: 0x{hr & 0xFFFFFFFF:08X}")

    # Command list CreateCommandList index 12 (nodeMask, type, allocator, initialState, iid, out)
    create_cl = com_method(
        g_device, 12, wintypes.HRESULT,
        (ctypes.c_void_p, wintypes.UINT, wintypes.UINT, ctypes.c_void_p, ctypes.c_void_p, ctypes.POINTER(GUID), ctypes.POINTER(ctypes.c_void_p))
    )
    hr = create_cl(
        g_device,
        0,
        D3D12_COMMAND_LIST_TYPE_DIRECT,
        ctypes.c_void_p(int(g_command_allocators[g_frame_index])),
        g_pipeline_state,
        ctypes.byref(IID_ID3D12GraphicsCommandList),
        ctypes.byref(g_command_list),
    )
    if hr != 0:
        raise RuntimeError(f"CreateCommandList failed: 0x{hr & 0xFFFFFFFF:08X}")

    # Close once index 9
    close = com_method(g_command_list, 9, wintypes.HRESULT, (ctypes.c_void_p,))
    close(g_command_list)

    # Fence CreateFence index 36
    create_fence = com_method(
        g_device, 36, wintypes.HRESULT,
        (ctypes.c_void_p, ctypes.c_uint64, wintypes.UINT, ctypes.POINTER(GUID), ctypes.POINTER(ctypes.c_void_p))
    )
    hr = create_fence(g_device, 0, D3D12_FENCE_FLAG_NONE, ctypes.byref(IID_ID3D12Fence), ctypes.byref(g_fence))
    if hr != 0:
        raise RuntimeError(f"CreateFence failed: 0x{hr & 0xFFFFFFFF:08X}")

    g_fence_event = kernel32.CreateEventW(None, False, False, None)
    if not g_fence_event:
        raise winerr()

    # CreateCommittedResource index 27 (Constant Buffer)
    cb_size = align_up(ctypes.sizeof(CBParams), 256)

    heap_props = D3D12_HEAP_PROPERTIES()
    heap_props.Type = D3D12_HEAP_TYPE_UPLOAD
    heap_props.CPUPageProperty = 0
    heap_props.MemoryPoolPreference = 0
    heap_props.CreationNodeMask = 1
    heap_props.VisibleNodeMask = 1

    res_desc = D3D12_RESOURCE_DESC()
    res_desc.Dimension = D3D12_RESOURCE_DIMENSION_BUFFER
    res_desc.Alignment = 0
    res_desc.Width = cb_size
    res_desc.Height = 1
    res_desc.DepthOrArraySize = 1
    res_desc.MipLevels = 1
    res_desc.Format = 0
    res_desc.SampleDesc.Count = 1
    res_desc.SampleDesc.Quality = 0
    res_desc.Layout = D3D12_TEXTURE_LAYOUT_ROW_MAJOR
    res_desc.Flags = D3D12_RESOURCE_FLAG_NONE

    create_res = com_method(
        g_device, 27, wintypes.HRESULT,
        (ctypes.c_void_p, ctypes.POINTER(D3D12_HEAP_PROPERTIES), wintypes.UINT,
         ctypes.POINTER(D3D12_RESOURCE_DESC), wintypes.UINT,
         ctypes.c_void_p, ctypes.POINTER(GUID), ctypes.POINTER(ctypes.c_void_p))
    )
    hr = create_res(
        g_device,
        ctypes.byref(heap_props),
        D3D12_HEAP_FLAG_NONE,
        ctypes.byref(res_desc),
        D3D12_RESOURCE_STATE_GENERIC_READ,
        None,
        ctypes.byref(IID_ID3D12Resource),
        ctypes.byref(g_cb_resource),
    )
    if hr != 0:
        raise RuntimeError(f"CreateCommittedResource(CB) failed: 0x{hr & 0xFFFFFFFF:08X}")

    # Map index 8
    map_fn = com_method(
        g_cb_resource, 8, wintypes.HRESULT,
        (ctypes.c_void_p, wintypes.UINT, ctypes.POINTER(D3D12_RANGE), ctypes.POINTER(ctypes.c_void_p))
    )
    read_range = D3D12_RANGE(0, 0)
    mapped = ctypes.c_void_p()
    hr = map_fn(g_cb_resource, 0, ctypes.byref(read_range), ctypes.byref(mapped))
    if hr != 0:
        raise RuntimeError(f"CB Map failed: 0x{hr & 0xFFFFFFFF:08X}")
    g_cb_mapped_ptr = mapped

    # GetGPUVirtualAddress index 11
    get_va = com_method(g_cb_resource, 11, ctypes.c_uint64, (ctypes.c_void_p,))
    g_cb_gpu_va = int(get_va(g_cb_resource))

    # ----------------------------
    # Vertex buffer (3 vertices, float2 POSITION)
    # ----------------------------
    vb_bytes = 3 * 2 * 4  # 3 * float2
    vb_desc = D3D12_RESOURCE_DESC()
    vb_desc.Dimension = D3D12_RESOURCE_DIMENSION_BUFFER
    vb_desc.Alignment = 0
    vb_desc.Width = vb_bytes
    vb_desc.Height = 1
    vb_desc.DepthOrArraySize = 1
    vb_desc.MipLevels = 1
    vb_desc.Format = 0
    vb_desc.SampleDesc.Count = 1
    vb_desc.SampleDesc.Quality = 0
    vb_desc.Layout = D3D12_TEXTURE_LAYOUT_ROW_MAJOR
    vb_desc.Flags = D3D12_RESOURCE_FLAG_NONE

    hr = create_res(
        g_device,
        ctypes.byref(heap_props),
        D3D12_HEAP_FLAG_NONE,
        ctypes.byref(vb_desc),
        D3D12_RESOURCE_STATE_GENERIC_READ,
        None,
        ctypes.byref(IID_ID3D12Resource),
        ctypes.byref(g_vb_resource),
    )
    if hr != 0:
        raise RuntimeError(f"CreateCommittedResource(VB) failed: 0x{hr & 0xFFFFFFFF:08X}")

    map_vb = com_method(
        g_vb_resource, 8, wintypes.HRESULT,
        (ctypes.c_void_p, wintypes.UINT, ctypes.POINTER(D3D12_RANGE), ctypes.POINTER(ctypes.c_void_p))
    )
    vb_mapped = ctypes.c_void_p()
    hr = map_vb(g_vb_resource, 0, ctypes.byref(read_range), ctypes.byref(vb_mapped))
    if hr != 0:
        raise RuntimeError(f"VB Map failed: 0x{hr & 0xFFFFFFFF:08X}")
    g_vb_mapped_ptr = vb_mapped

    # Fullscreen triangle in clip-space (matches your VS: float4(position,0,1))
    # (-1,-1), (-1, 3), ( 3,-1)
    verts = (ctypes.c_float * 6)(
        -1.0, -1.0,
        -1.0,  3.0,
         3.0, -1.0,
    )
    ctypes.memmove(g_vb_mapped_ptr, verts, vb_bytes)

    get_vb_va = com_method(g_vb_resource, 11, ctypes.c_uint64, (ctypes.c_void_p,))
    vb_gpu_va = int(get_vb_va(g_vb_resource))

    g_vb_view.BufferLocation = ctypes.c_uint64(vb_gpu_va)
    g_vb_view.SizeInBytes = vb_bytes
    g_vb_view.StrideInBytes = 8  # float2

    g_start_time = time.perf_counter()
    debug("=== D3D12 Initialization Complete ===")

def update_constant_buffer():
    t = float(time.perf_counter() - g_start_time)
    cb = CBParams(t, float(g_width), float(g_height), 0.0)
    ctypes.memmove(g_cb_mapped_ptr, ctypes.byref(cb), ctypes.sizeof(CBParams))

def wait_for_previous_frame():
    global g_frame_index, g_fence_values

    current_value = g_fence_values[g_frame_index]

    # Signal index 14
    signal = com_method(g_command_queue, 14, wintypes.HRESULT, (ctypes.c_void_p, ctypes.c_void_p, ctypes.c_uint64))
    hr = signal(g_command_queue, g_fence, current_value)
    if hr != 0:
        raise RuntimeError(f"Signal failed: 0x{hr & 0xFFFFFFFF:08X}")

    # next frame index
    get_idx = com_method(g_swap_chain, 36, wintypes.UINT, (ctypes.c_void_p,))
    g_frame_index = int(get_idx(g_swap_chain))

    # GetCompletedValue index 8
    get_completed = com_method(g_fence, 8, ctypes.c_uint64, (ctypes.c_void_p,))
    if int(get_completed(g_fence)) < g_fence_values[g_frame_index]:
        # SetEventOnCompletion index 9
        set_event = com_method(g_fence, 9, wintypes.HRESULT, (ctypes.c_void_p, ctypes.c_uint64, wintypes.HANDLE))
        hr = set_event(g_fence, g_fence_values[g_frame_index], g_fence_event)
        if hr != 0:
            raise RuntimeError(f"SetEventOnCompletion failed: 0x{hr & 0xFFFFFFFF:08X}")
        kernel32.WaitForSingleObject(g_fence_event, INFINITE)

    g_fence_values[g_frame_index] = current_value + 1

def render():
    update_constant_buffer()

    alloc = ctypes.c_void_p(int(g_command_allocators[g_frame_index]))

    # CommandAllocator::Reset index 8
    reset_ca = com_method(alloc, 8, wintypes.HRESULT, (ctypes.c_void_p,))
    hr = reset_ca(alloc)
    if hr != 0:
        raise RuntimeError(f"CommandAllocator::Reset failed: 0x{hr & 0xFFFFFFFF:08X}")

    # CommandList::Reset index 10
    reset_cl = com_method(g_command_list, 10, wintypes.HRESULT, (ctypes.c_void_p, ctypes.c_void_p, ctypes.c_void_p))
    hr = reset_cl(g_command_list, alloc, g_pipeline_state)
    if hr != 0:
        raise RuntimeError(f"CommandList::Reset failed: 0x{hr & 0xFFFFFFFF:08X}")

    # SetGraphicsRootSignature index 30
    set_rs = com_method(g_command_list, 30, None, (ctypes.c_void_p, ctypes.c_void_p))
    set_rs(g_command_list, g_root_signature)

    # SetGraphicsRootConstantBufferView index 38
    set_cbv = com_method(g_command_list, 38, None, (ctypes.c_void_p, wintypes.UINT, ctypes.c_uint64))
    set_cbv(g_command_list, 0, ctypes.c_uint64(g_cb_gpu_va))

    # RSSetViewports index 21
    vp = D3D12_VIEWPORT(0.0, 0.0, float(g_width), float(g_height), 0.0, 1.0)
    rs_viewports = com_method(g_command_list, 21, None, (ctypes.c_void_p, wintypes.UINT, ctypes.POINTER(D3D12_VIEWPORT)))
    rs_viewports(g_command_list, 1, ctypes.byref(vp))

    # RSSetScissorRects index 22
    sc = D3D12_RECT(0, 0, g_width, g_height)
    rs_scissors = com_method(g_command_list, 22, None, (ctypes.c_void_p, wintypes.UINT, ctypes.POINTER(D3D12_RECT)))
    rs_scissors(g_command_list, 1, ctypes.byref(sc))

    # IASetVertexBuffers index 44  (IMPORTANT)
    ia_set_vb = com_method(
        g_command_list, 44, None,
        (ctypes.c_void_p, wintypes.UINT, wintypes.UINT, ctypes.POINTER(D3D12_VERTEX_BUFFER_VIEW))
    )
    ia_set_vb(g_command_list, 0, 1, ctypes.byref(g_vb_view))

    # IASetPrimitiveTopology index 20
    ia_topo = com_method(g_command_list, 20, None, (ctypes.c_void_p, wintypes.UINT))
    ia_topo(g_command_list, D3D_PRIMITIVE_TOPOLOGY_TRIANGLELIST)

    # ResourceBarrier index 26
    resource_barrier = com_method(g_command_list, 26, None, (ctypes.c_void_p, wintypes.UINT, ctypes.POINTER(D3D12_RESOURCE_BARRIER)))

    barrier = D3D12_RESOURCE_BARRIER()
    barrier.Type = D3D12_RESOURCE_BARRIER_TYPE_TRANSITION
    barrier.Flags = D3D12_RESOURCE_BARRIER_FLAG_NONE
    barrier.u.Transition.pResource = ctypes.c_void_p(int(g_render_targets[g_frame_index]))
    barrier.u.Transition.Subresource = D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES
    barrier.u.Transition.StateBefore = D3D12_RESOURCE_STATE_PRESENT
    barrier.u.Transition.StateAfter  = D3D12_RESOURCE_STATE_RENDER_TARGET
    resource_barrier(g_command_list, 1, ctypes.byref(barrier))

    # RTV handle for current frame
    get_cpu_handle = com_method(g_rtv_heap, 9, None, (ctypes.c_void_p, ctypes.POINTER(D3D12_CPU_DESCRIPTOR_HANDLE)))
    rtv_start = D3D12_CPU_DESCRIPTOR_HANDLE()
    get_cpu_handle(g_rtv_heap, ctypes.byref(rtv_start))
    rtv = D3D12_CPU_DESCRIPTOR_HANDLE(rtv_start.ptr + g_frame_index * g_rtv_descriptor_size)

    # OMSetRenderTargets index 46
    om_set = com_method(
        g_command_list, 46, None,
        (ctypes.c_void_p, wintypes.UINT, ctypes.POINTER(D3D12_CPU_DESCRIPTOR_HANDLE), wintypes.BOOL, ctypes.c_void_p)
    )
    om_set(g_command_list, 1, ctypes.byref(rtv), False, None)

    # ClearRenderTargetView index 48
    clear = com_method(
        g_command_list, 48, None,
        (ctypes.c_void_p, D3D12_CPU_DESCRIPTOR_HANDLE, ctypes.POINTER(ctypes.c_float), wintypes.UINT, ctypes.c_void_p)
    )
    clear_color = (ctypes.c_float * 4)(0.0, 0.0, 0.0, 1.0)
    clear(g_command_list, rtv, clear_color, 0, None)

    # DrawInstanced index 12
    draw = com_method(g_command_list, 12, None, (ctypes.c_void_p, wintypes.UINT, wintypes.UINT, wintypes.UINT, wintypes.UINT))
    draw(g_command_list, 3, 1, 0, 0)

    # Barrier back: RT -> Present
    barrier.u.Transition.StateBefore = D3D12_RESOURCE_STATE_RENDER_TARGET
    barrier.u.Transition.StateAfter  = D3D12_RESOURCE_STATE_PRESENT
    resource_barrier(g_command_list, 1, ctypes.byref(barrier))

    # Close index 9
    close = com_method(g_command_list, 9, wintypes.HRESULT, (ctypes.c_void_p,))
    hr = close(g_command_list)
    if hr != 0:
        raise RuntimeError(f"CommandList::Close failed: 0x{hr & 0xFFFFFFFF:08X}")

    # ExecuteCommandLists index 10
    cmd_lists = (ctypes.c_void_p * 1)(g_command_list.value)
    execute = com_method(g_command_queue, 10, None, (ctypes.c_void_p, wintypes.UINT, ctypes.POINTER(ctypes.c_void_p)))
    execute(g_command_queue, 1, cmd_lists)

    # Present index 8
    present = com_method(g_swap_chain, 8, wintypes.HRESULT, (ctypes.c_void_p, wintypes.UINT, wintypes.UINT))
    hr = present(g_swap_chain, 1, 0)
    if hr != 0:
        raise RuntimeError(f"Present failed: 0x{hr & 0xFFFFFFFF:08X}")

    wait_for_previous_frame()

def cleanup():
    try:
        wait_for_previous_frame()
    except:
        pass

    # Unmap CB/VB
    if g_cb_resource:
        unmap = com_method(g_cb_resource, 9, None, (ctypes.c_void_p, wintypes.UINT, ctypes.POINTER(D3D12_RANGE)))
        unmap(g_cb_resource, 0, None)
    if g_vb_resource:
        unmap = com_method(g_vb_resource, 9, None, (ctypes.c_void_p, wintypes.UINT, ctypes.POINTER(D3D12_RANGE)))
        unmap(g_vb_resource, 0, None)

    if g_fence_event:
        kernel32.CloseHandle(g_fence_event)

    # Release COM
    com_release(g_vb_resource)
    com_release(g_cb_resource)
    com_release(g_pipeline_state)
    com_release(g_root_signature)
    com_release(g_command_list)
    for i in range(FRAME_COUNT):
        com_release(ctypes.c_void_p(int(g_command_allocators[i])))
        com_release(ctypes.c_void_p(int(g_render_targets[i])))
    com_release(g_rtv_heap)
    com_release(g_fence)
    com_release(g_swap_chain)
    com_release(g_command_queue)
    com_release(g_device)
    com_release(g_factory)

# ============================================================
# Window proc
# ============================================================
@WNDPROC
def wndproc(hwnd, msg, wparam, lparam):
    if msg == WM_PAINT:
        return user32.DefWindowProcW(hwnd, msg, wparam, lparam)
    if msg == WM_DESTROY:
        user32.PostQuitMessage(0)
        return 0
    return user32.DefWindowProcW(hwnd, msg, wparam, lparam)

# ============================================================
# Main
# ============================================================
def main():
    global g_hwnd

    ole32.CoInitialize(None)

    hInstance = kernel32.GetModuleHandleW(None)
    class_name = "PyDX12RaymarchIA"

    wc = WNDCLASSEXW()
    wc.cbSize = ctypes.sizeof(WNDCLASSEXW)
    wc.style = CS_HREDRAW | CS_VREDRAW
    wc.lpfnWndProc = wndproc
    wc.hInstance = hInstance
    wc.hCursor = user32.LoadCursorW(None, wintypes.LPCWSTR(IDC_ARROW))
    wc.hbrBackground = 0
    wc.lpszClassName = class_name

    if not user32.RegisterClassExW(ctypes.byref(wc)):
        raise winerr()

    g_hwnd = user32.CreateWindowExW(
        0,
        class_name,
        "DirectX12 Raymarching (ctypes only / IA POSITION)",
        WS_OVERLAPPEDWINDOW,
        CW_USEDEFAULT, CW_USEDEFAULT,
        960, 540,
        None, None, hInstance, None
    )
    if not g_hwnd:
        raise winerr()

    user32.ShowWindow(g_hwnd, SW_SHOW)

    init_d3d12()

    msg = MSG()
    while True:
        while user32.PeekMessageW(ctypes.byref(msg), None, 0, 0, PM_REMOVE):
            if msg.message == WM_QUIT:
                cleanup()
                return
            user32.TranslateMessage(ctypes.byref(msg))
            user32.DispatchMessageW(ctypes.byref(msg))
        render()

if __name__ == "__main__":
    main()
