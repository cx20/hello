import ctypes
from ctypes import wintypes
import random
import math

# ============================================================
# DLLs
# ============================================================
user32   = ctypes.WinDLL("user32", use_last_error=True)
kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
ole32    = ctypes.WinDLL("ole32", use_last_error=True)

try:
    d3dcompiler = ctypes.WinDLL("d3dcompiler_47", use_last_error=True)
except OSError:
    d3dcompiler = ctypes.WinDLL("d3dcompiler_43", use_last_error=True)

d3d12 = ctypes.WinDLL("d3d12", use_last_error=True)
dxgi  = ctypes.WinDLL("dxgi", use_last_error=True)

# Enable debug layer - load dxgidebug.dll if available
try:
    dxgidebug = ctypes.WinDLL("dxgidebug", use_last_error=True)
except OSError:
    dxgidebug = None

if not hasattr(wintypes, "HRESULT"):
    wintypes.HRESULT = ctypes.c_long
if not hasattr(wintypes, "SIZE_T"):
    wintypes.SIZE_T = ctypes.c_size_t

for name in ("HICON", "HCURSOR", "HBRUSH"):
    if not hasattr(wintypes, name):
        setattr(wintypes, name, wintypes.HANDLE)

# ============================================================
# Basic Win32 types / helpers
# ============================================================
LRESULT = wintypes.LPARAM
WNDPROC = ctypes.WINFUNCTYPE(LRESULT, wintypes.HWND, wintypes.UINT, wintypes.WPARAM, wintypes.LPARAM)

def winerr():
    return ctypes.WinError(ctypes.get_last_error())

# ============================================================
# Win32 constants
# ============================================================
CS_HREDRAW = 0x0002
CS_VREDRAW = 0x0001
WS_OVERLAPPEDWINDOW = 0x00CF0000
CW_USEDEFAULT = 0x80000000
SW_SHOW = 5

WM_DESTROY = 0x0002
WM_PAINT   = 0x000F
WM_QUIT    = 0x0012

PM_REMOVE  = 0x0001
INFINITE   = 0xFFFFFFFF

IDC_ARROW = 32512

# ============================================================
# D3D12 / DXGI constants
# ============================================================
# DXGI_FORMAT
DXGI_FORMAT_UNKNOWN            = 0
DXGI_FORMAT_R8G8B8A8_UNORM     = 28
DXGI_FORMAT_R32G32B32_FLOAT    = 6
DXGI_FORMAT_R32G32B32A32_FLOAT = 2
DXGI_FORMAT_D32_FLOAT          = 40

# DXGI_SWAP_EFFECT
DXGI_SWAP_EFFECT_FLIP_DISCARD = 4

# D3D12 constants
D3D12_COMMAND_LIST_TYPE_DIRECT  = 0
D3D12_COMMAND_LIST_TYPE_COMPUTE = 2
D3D12_COMMAND_QUEUE_FLAG_NONE   = 0
D3D12_FENCE_FLAG_NONE           = 0

# D3D12_DESCRIPTOR_HEAP_TYPE
D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV = 0
D3D12_DESCRIPTOR_HEAP_TYPE_SAMPLER     = 1
D3D12_DESCRIPTOR_HEAP_TYPE_RTV         = 2
D3D12_DESCRIPTOR_HEAP_TYPE_DSV         = 3

D3D12_DESCRIPTOR_HEAP_FLAG_NONE            = 0
D3D12_DESCRIPTOR_HEAP_FLAG_SHADER_VISIBLE  = 1

D3D12_RESOURCE_STATE_COMMON           = 0
D3D12_RESOURCE_STATE_PRESENT          = 0
D3D12_RESOURCE_STATE_RENDER_TARGET    = 4
D3D12_RESOURCE_STATE_UNORDERED_ACCESS = 0x8
D3D12_RESOURCE_STATE_NON_PIXEL_SHADER_RESOURCE = 0x40
D3D12_RESOURCE_STATE_GENERIC_READ     = 0x1

D3D12_HEAP_TYPE_DEFAULT = 1
D3D12_HEAP_TYPE_UPLOAD  = 2

D3D12_RESOURCE_DIMENSION_BUFFER  = 1
D3D12_RESOURCE_DIMENSION_TEXTURE2D = 3

D3D12_TEXTURE_LAYOUT_ROW_MAJOR = 1

D3D12_RESOURCE_FLAG_NONE               = 0
D3D12_RESOURCE_FLAG_ALLOW_UNORDERED_ACCESS = 0x4

D3D12_ROOT_SIGNATURE_FLAG_NONE = 0
D3D12_ROOT_SIGNATURE_FLAG_ALLOW_INPUT_ASSEMBLER_INPUT_LAYOUT = 0x1

D3D12_ROOT_PARAMETER_TYPE_DESCRIPTOR_TABLE = 0

D3D12_DESCRIPTOR_RANGE_TYPE_SRV = 0
D3D12_DESCRIPTOR_RANGE_TYPE_UAV = 1
D3D12_DESCRIPTOR_RANGE_TYPE_CBV = 2

D3D12_SHADER_VISIBILITY_ALL    = 0
D3D12_SHADER_VISIBILITY_VERTEX = 1

D3D12_PRIMITIVE_TOPOLOGY_TYPE_POINT    = 1
D3D12_PRIMITIVE_TOPOLOGY_TYPE_LINE     = 2
D3D12_PRIMITIVE_TOPOLOGY_TYPE_TRIANGLE = 3
D3D_PRIMITIVE_TOPOLOGY_POINTLIST       = 1
D3D_PRIMITIVE_TOPOLOGY_LINESTRIP       = 3
D3D_PRIMITIVE_TOPOLOGY_TRIANGLELIST    = 4

D3D12_INPUT_CLASSIFICATION_PER_VERTEX_DATA = 0

D3D12_FILL_MODE_SOLID = 3
D3D12_CULL_MODE_NONE  = 1

D3D12_BLEND_ONE  = 2
D3D12_BLEND_ZERO = 1
D3D12_BLEND_OP_ADD = 1
D3D12_LOGIC_OP_NOOP = 5
D3D12_COLOR_WRITE_ENABLE_ALL = 15

D3D12_COMPARISON_FUNC_LESS = 2
D3D12_DEPTH_WRITE_MASK_ALL = 1

D3D12_RESOURCE_BARRIER_TYPE_TRANSITION   = 0
D3D12_RESOURCE_BARRIER_FLAG_NONE         = 0
D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES  = 0xFFFFFFFF

D3D_FEATURE_LEVEL_12_0 = 0xC000

D3DCOMPILE_ENABLE_STRICTNESS = 0x00000002

D3D_ROOT_SIGNATURE_VERSION_1 = 1

D3D12_SRV_DIMENSION_BUFFER = 1
D3D12_UAV_DIMENSION_BUFFER = 1

D3D12_DEFAULT_SHADER_4_COMPONENT_MAPPING = 5768

FRAME_COUNT = 2
VERTEX_COUNT = 100000
WIDTH = 800
HEIGHT = 600

# ============================================================
# GUIDs
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

# GUIDs
IID_IDXGIFactory4        = guid_from_str("{1bc6ea02-ef36-464f-bf0c-21ca39e5168a}")
IID_IDXGISwapChain3      = guid_from_str("{94d99bdb-f1f8-4ab0-b236-7da0170edab1}")
IID_ID3D12Device         = guid_from_str("{189819f1-1db6-4b57-be54-1821339b85f7}")
IID_ID3D12CommandQueue   = guid_from_str("{0ec870a6-5d7e-4c22-8cfc-5baae07616ed}")
IID_ID3D12Resource       = guid_from_str("{696442be-a72e-4059-bc79-5b5c98040fad}")
IID_ID3D12RootSignature  = guid_from_str("{c54a6b66-72df-4ee8-8be5-a946a1429214}")
IID_ID3D12Debug          = guid_from_str("{344488b7-6846-474b-b989-f027448245e0}")
IID_ID3D12DescriptorHeap = guid_from_str("{8efb471d-616c-4f49-90f7-127bb763fa51}")
IID_ID3D12CommandAllocator = guid_from_str("{6102dee4-af59-4b09-b999-b44d73f09b24}")
IID_ID3D12PipelineState  = guid_from_str("{765a30f3-f624-4c6f-a828-ace948622445}")
IID_ID3D12GraphicsCommandList = guid_from_str("{5b160d0f-ac1b-4185-8ba8-b3ae42a5a455}")
IID_ID3D12Fence          = guid_from_str("{0a753dcf-c4d8-4b91-adf6-be5a60d95a76}")

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

class RECT(ctypes.Structure):
    _fields_ = [("left", ctypes.c_long), ("top", ctypes.c_long),
                ("right", ctypes.c_long), ("bottom", ctypes.c_long)]

class DXGI_RATIONAL(ctypes.Structure):
    _fields_ = [("Numerator", wintypes.UINT), ("Denominator", wintypes.UINT)]

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

class D3D12_GPU_DESCRIPTOR_HANDLE(ctypes.Structure):
    _fields_ = [("ptr", ctypes.c_uint64)]

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

# Resource barrier union
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

# Root signature structures
class D3D12_DESCRIPTOR_RANGE(ctypes.Structure):
    _fields_ = [
        ("RangeType", wintypes.UINT),
        ("NumDescriptors", wintypes.UINT),
        ("BaseShaderRegister", wintypes.UINT),
        ("RegisterSpace", wintypes.UINT),
        ("OffsetInDescriptorsFromTableStart", wintypes.UINT),
    ]

class D3D12_ROOT_DESCRIPTOR_TABLE(ctypes.Structure):
    _fields_ = [
        ("NumDescriptorRanges", wintypes.UINT),
        ("pDescriptorRanges", ctypes.c_void_p),
    ]

class D3D12_ROOT_CONSTANTS(ctypes.Structure):
    _fields_ = [
        ("ShaderRegister", wintypes.UINT),
        ("RegisterSpace", wintypes.UINT),
        ("Num32BitValues", wintypes.UINT),
    ]

class D3D12_ROOT_DESCRIPTOR(ctypes.Structure):
    _fields_ = [
        ("ShaderRegister", wintypes.UINT),
        ("RegisterSpace", wintypes.UINT),
    ]

class D3D12_ROOT_PARAMETER_UNION(ctypes.Union):
    _fields_ = [
        ("DescriptorTable", D3D12_ROOT_DESCRIPTOR_TABLE),
        ("Constants", D3D12_ROOT_CONSTANTS),
        ("Descriptor", D3D12_ROOT_DESCRIPTOR),
    ]

class D3D12_ROOT_PARAMETER(ctypes.Structure):
    _fields_ = [
        ("ParameterType", wintypes.UINT),
        ("u", D3D12_ROOT_PARAMETER_UNION),
        ("ShaderVisibility", wintypes.UINT),
    ]

class D3D12_ROOT_SIGNATURE_DESC(ctypes.Structure):
    _fields_ = [
        ("NumParameters", wintypes.UINT),
        ("pParameters", ctypes.c_void_p),
        ("NumStaticSamplers", wintypes.UINT),
        ("pStaticSamplers", ctypes.c_void_p),
        ("Flags", wintypes.UINT),
    ]

class D3D12_SHADER_BYTECODE(ctypes.Structure):
    _fields_ = [
        ("pShaderBytecode", ctypes.c_void_p),
        ("BytecodeLength", ctypes.c_size_t),
    ]

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
    _fields_ = [
        ("pCachedBlob", ctypes.c_void_p),
        ("CachedBlobSizeInBytes", ctypes.c_size_t),
    ]

class D3D12_STREAM_OUTPUT_DESC(ctypes.Structure):
    _fields_ = [
        ("pSODeclaration", ctypes.c_void_p),
        ("NumEntries", wintypes.UINT),
        ("pBufferStrides", ctypes.c_void_p),
        ("NumStrides", wintypes.UINT),
        ("RasterizedStream", wintypes.UINT),
    ]

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

class D3D12_INPUT_LAYOUT_DESC(ctypes.Structure):
    _fields_ = [
        ("pInputElementDescs", ctypes.POINTER(D3D12_INPUT_ELEMENT_DESC)),
        ("NumElements", wintypes.UINT),
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

class D3D12_COMPUTE_PIPELINE_STATE_DESC(ctypes.Structure):
    _fields_ = [
        ("pRootSignature", ctypes.c_void_p),
        ("CS", D3D12_SHADER_BYTECODE),
        ("NodeMask", wintypes.UINT),
        ("CachedPSO", D3D12_CACHED_PIPELINE_STATE),
        ("Flags", wintypes.UINT),
    ]

# SRV/UAV/CBV descriptor structures
class D3D12_BUFFER_SRV(ctypes.Structure):
    _fields_ = [
        ("FirstElement", ctypes.c_uint64),
        ("NumElements", wintypes.UINT),
        ("StructureByteStride", wintypes.UINT),
        ("Flags", wintypes.UINT),
    ]

class D3D12_SHADER_RESOURCE_VIEW_DESC(ctypes.Structure):
    _fields_ = [
        ("Format", wintypes.UINT),
        ("ViewDimension", wintypes.UINT),
        ("Shader4ComponentMapping", wintypes.UINT),
        ("Buffer", D3D12_BUFFER_SRV),
    ]

class D3D12_BUFFER_UAV(ctypes.Structure):
    _fields_ = [
        ("FirstElement", ctypes.c_uint64),
        ("NumElements", wintypes.UINT),
        ("StructureByteStride", wintypes.UINT),
        ("CounterOffsetInBytes", ctypes.c_uint64),
        ("Flags", wintypes.UINT),
    ]

class D3D12_UNORDERED_ACCESS_VIEW_DESC(ctypes.Structure):
    _fields_ = [
        ("Format", wintypes.UINT),
        ("ViewDimension", wintypes.UINT),
        ("Buffer", D3D12_BUFFER_UAV),
    ]

class D3D12_CONSTANT_BUFFER_VIEW_DESC(ctypes.Structure):
    _fields_ = [
        ("BufferLocation", ctypes.c_uint64),
        ("SizeInBytes", wintypes.UINT),
    ]

# Harmonograph parameters (must match HLSL)
class HarmonographParams(ctypes.Structure):
    _fields_ = [
        ("A1", ctypes.c_float), ("f1", ctypes.c_float), ("p1", ctypes.c_float), ("d1", ctypes.c_float),
        ("A2", ctypes.c_float), ("f2", ctypes.c_float), ("p2", ctypes.c_float), ("d2", ctypes.c_float),
        ("A3", ctypes.c_float), ("f3", ctypes.c_float), ("p3", ctypes.c_float), ("d3", ctypes.c_float),
        ("A4", ctypes.c_float), ("f4", ctypes.c_float), ("p4", ctypes.c_float), ("d4", ctypes.c_float),
        ("max_num", wintypes.UINT),
        ("padding1", ctypes.c_float), ("padding2", ctypes.c_float), ("padding3", ctypes.c_float),
        ("resolutionX", ctypes.c_float), ("resolutionY", ctypes.c_float),
        ("padding4", ctypes.c_float), ("padding5", ctypes.c_float),
    ]

# ============================================================
# Win32 prototypes
# ============================================================
kernel32.GetModuleHandleW.restype = wintypes.HMODULE
kernel32.GetModuleHandleW.argtypes = (wintypes.LPCWSTR,)

kernel32.Sleep.restype = None
kernel32.Sleep.argtypes = (wintypes.DWORD,)

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
# D3D12 / DXGI / Compiler prototypes
# ============================================================
CreateDXGIFactory1 = dxgi.CreateDXGIFactory1
CreateDXGIFactory1.restype = wintypes.HRESULT
CreateDXGIFactory1.argtypes = (ctypes.POINTER(GUID), ctypes.POINTER(ctypes.c_void_p))

D3D12CreateDevice = d3d12.D3D12CreateDevice
D3D12CreateDevice.restype = wintypes.HRESULT
D3D12CreateDevice.argtypes = (
    ctypes.c_void_p,
    wintypes.UINT,
    ctypes.POINTER(GUID),
    ctypes.POINTER(ctypes.c_void_p),
)

D3D12GetDebugInterface = d3d12.D3D12GetDebugInterface
D3D12GetDebugInterface.restype = wintypes.HRESULT
D3D12GetDebugInterface.argtypes = (
    ctypes.POINTER(GUID),
    ctypes.POINTER(ctypes.c_void_p),
)

D3D12SerializeRootSignature = d3d12.D3D12SerializeRootSignature
D3D12SerializeRootSignature.restype = wintypes.HRESULT
D3D12SerializeRootSignature.argtypes = (
    ctypes.POINTER(D3D12_ROOT_SIGNATURE_DESC),
    wintypes.UINT,
    ctypes.POINTER(ctypes.c_void_p),
    ctypes.POINTER(ctypes.c_void_p),
)

D3DCompile = d3dcompiler.D3DCompile
D3DCompile.restype = wintypes.HRESULT
D3DCompile.argtypes = (
    ctypes.c_void_p, wintypes.SIZE_T, ctypes.c_char_p,
    ctypes.c_void_p, ctypes.c_void_p,
    ctypes.c_char_p, ctypes.c_char_p,
    wintypes.UINT, wintypes.UINT,
    ctypes.POINTER(ctypes.c_void_p), ctypes.POINTER(ctypes.c_void_p)
)

# ============================================================
# COM vtable caller (no comtypes)
# ============================================================
def com_method(obj, index: int, restype, argtypes):
    if isinstance(obj, ctypes.c_void_p):
        ptr_value = obj.value
    elif isinstance(obj, int):
        ptr_value = obj
    else:
        ptr_value = obj
    
    if ptr_value is None or ptr_value == 0:
        raise RuntimeError(f"com_method: NULL pointer passed for vtable lookup at index {index}")
    
    vtbl = ctypes.cast(ptr_value, ctypes.POINTER(ctypes.POINTER(ctypes.c_void_p))).contents
    fn_addr = vtbl[index]
    FN = ctypes.WINFUNCTYPE(restype, *argtypes)
    return FN(fn_addr)

def com_release(obj_ref: ctypes.c_void_p):
    if obj_ref:
        try:
            com_method(obj_ref, 2, wintypes.ULONG, (ctypes.c_void_p,))(obj_ref)
        except Exception:
            pass

# Debug output helper
kernel32.OutputDebugStringW.restype = None
kernel32.OutputDebugStringW.argtypes = (wintypes.LPCWSTR,)

def debug_print(msg: str):
    """Output debug message to DebugView and console"""
    kernel32.OutputDebugStringW(f"[PyDX12] {msg}\n")
    print(f"[PyDX12] {msg}")

def enable_debug_layer():
    """Enable D3D12 debug layer - must be called before device creation"""
    debug_print("enable_debug_layer()")
    debug_interface = ctypes.c_void_p()
    hr = D3D12GetDebugInterface(ctypes.byref(IID_ID3D12Debug), ctypes.byref(debug_interface))
    if hr == 0 and debug_interface:
        # ID3D12Debug::EnableDebugLayer (index 3)
        enable = com_method(debug_interface, 3, None, (ctypes.c_void_p,))
        enable(debug_interface)
        debug_print("D3D12 Debug Layer ENABLED")
        com_release(debug_interface)
        return True
    else:
        debug_print(f"Failed to get debug interface: 0x{hr & 0xFFFFFFFF:08X}")
        return False

# ============================================================
# Global D3D12 objects
# ============================================================
g_hwnd = None

g_factory        = ctypes.c_void_p()
g_device         = ctypes.c_void_p()
g_command_queue  = ctypes.c_void_p()
g_swap_chain     = ctypes.c_void_p()
g_rtv_heap       = ctypes.c_void_p()
g_srv_uav_heap   = ctypes.c_void_p()
g_render_targets = [ctypes.c_void_p() for _ in range(FRAME_COUNT)]

# Graphics command allocator and list
g_command_allocator = ctypes.c_void_p()
g_command_list      = ctypes.c_void_p()

# Compute command allocator and list
g_compute_command_allocator = ctypes.c_void_p()
g_compute_command_list      = ctypes.c_void_p()

# Root signatures
g_graphics_root_signature = ctypes.c_void_p()
g_compute_root_signature  = ctypes.c_void_p()

# Pipeline states
g_graphics_pipeline_state = ctypes.c_void_p()
g_compute_pipeline_state  = ctypes.c_void_p()

# Buffers
g_position_buffer  = ctypes.c_void_p()
g_color_buffer     = ctypes.c_void_p()
g_constant_buffer  = ctypes.c_void_p()
g_constant_buffer_ptr = None

g_fence          = ctypes.c_void_p()
g_fence_event    = None
g_fence_value    = 1
g_frame_index    = 0
g_rtv_descriptor_size = 0
g_srv_uav_descriptor_size = 0

g_width  = WIDTH
g_height = HEIGHT

# Harmonograph parameters
g_params = HarmonographParams()
g_params.A1 = 50.0; g_params.f1 = 2.0; g_params.p1 = 1.0/16.0; g_params.d1 = 0.02
g_params.A2 = 50.0; g_params.f2 = 2.0; g_params.p2 = 3.0/2.0;  g_params.d2 = 0.0315
g_params.A3 = 50.0; g_params.f3 = 2.0; g_params.p3 = 13.0/15.0; g_params.d3 = 0.02
g_params.A4 = 50.0; g_params.f4 = 2.0; g_params.p4 = 1.0;       g_params.d4 = 0.02
g_params.max_num = VERTEX_COUNT
g_params.resolutionX = float(WIDTH)
g_params.resolutionY = float(HEIGHT)

PI2 = math.pi * 2

# ============================================================
# HLSL source
# ============================================================
HLSL_SRC = r"""
// Constant Buffer: Must match Python struct layout
cbuffer HarmonographParams : register(b0)
{
    float A1, f1, p1, d1;
    float A2, f2, p2, d2;
    float A3, f3, p3, d3;
    float A4, f4, p4, d4;
    uint max_num;
    float3 padding;
    float2 resolution;
    float2 padding2;
};

// UAVs
RWStructuredBuffer<float4> positionBuffer : register(u0);
RWStructuredBuffer<float4> colorBuffer : register(u1);

// SRVs
StructuredBuffer<float4> positionSRV : register(t0);
StructuredBuffer<float4> colorSRV : register(t1);

float3 hsv2rgb(float h, float s, float v)
{
    float c = v * s;
    float hp = h / 60.0;
    float x = c * (1.0 - abs(fmod(hp, 2.0) - 1.0));
    float3 rgb;

    if (hp < 1.0) rgb = float3(c, x, 0.0);
    else if (hp < 2.0) rgb = float3(x, c, 0.0);
    else if (hp < 3.0) rgb = float3(0.0, c, x);
    else if (hp < 4.0) rgb = float3(0.0, x, c);
    else if (hp < 5.0) rgb = float3(x, 0.0, c);
    else rgb = float3(c, 0.0, x);

    float m = v - c;
    return rgb + float3(m, m, m);
}

[numthreads(64, 1, 1)]
void CSMain(uint3 dispatchThreadID : SV_DispatchThreadID)
{
    uint idx = dispatchThreadID.x;
    if (idx >= max_num) return;

    float t = (float)idx * 0.01;
    float PI = 3.14159265;

    // Harmonograph Equations
    float x = A1 * sin(f1 * t + PI * p1) * exp(-d1 * t) +
              A2 * sin(f2 * t + PI * p2) * exp(-d2 * t);

    float y = A3 * sin(f3 * t + PI * p3) * exp(-d3 * t) +
              A4 * sin(f4 * t + PI * p4) * exp(-d4 * t);

    // Z axis
    float z = A1 * cos(f1 * t + PI * p1) * exp(-d1 * t);

    positionBuffer[idx] = float4(x, y, z, 1.0);

    float hue = fmod((t / 20.0) * 360.0, 360.0);
    float3 rgb = hsv2rgb(hue, 1.0, 1.0);
    colorBuffer[idx] = float4(rgb, 1.0);
}

// --------------------------------------------------------
// Graphics Pipeline
// --------------------------------------------------------

float4x4 perspective(float fov, float aspect, float nearZ, float farZ)
{
    float rad = radians(fov / 2.0);
    float yScale = 1.0 / tan(rad);
    float xScale = yScale / aspect;

    return float4x4(
        xScale, 0, 0, 0,
        0, yScale, 0, 0,
        0, 0, farZ / (farZ - nearZ), 1,
        0, 0, -nearZ * farZ / (farZ - nearZ), 0
    );
}

float4x4 lookAt(float3 eye, float3 target, float3 up)
{
    float3 zaxis = normalize(target - eye);
    float3 xaxis = normalize(cross(up, zaxis));
    float3 yaxis = cross(zaxis, xaxis);

    return float4x4(
        xaxis.x, yaxis.x, zaxis.x, 0,
        xaxis.y, yaxis.y, zaxis.y, 0,
        xaxis.z, yaxis.z, zaxis.z, 0,
        -dot(xaxis, eye), -dot(yaxis, eye), -dot(zaxis, eye), 1
    );
}

struct VSOutput
{
    float4 position : SV_POSITION;
    float4 color : COLOR;
};

VSOutput VSMain(uint vertexID : SV_VertexID)
{
    VSOutput output;

    float4 pos = positionSRV[vertexID];
    float4 col = colorSRV[vertexID];

    float4x4 proj = perspective(45.0, resolution.x / resolution.y, 1.0, 500.0);
    
    float3 cameraPos = float3(0, 0, -150); 
    float3 cameraTarget = float3(0, 0, 0);
    float3 cameraUp = float3(0, 1, 0);
    float4x4 view = lookAt(cameraPos, cameraTarget, cameraUp);

    output.position = mul(mul(pos, view), proj);
    output.color = col;

    return output;
}

float4 PSMain(VSOutput input) : SV_TARGET
{
    return input.color;
}
"""

def compile_hlsl(entry: str, target: str) -> ctypes.c_void_p:
    debug_print(f"compile_hlsl({entry}, {target})")
    src = HLSL_SRC.encode("utf-8")
    code = ctypes.c_void_p()
    err  = ctypes.c_void_p()
    hr = D3DCompile(
        ctypes.c_char_p(src),
        len(src),
        b"embedded.hlsl",
        None,
        None,
        entry.encode("ascii"),
        target.encode("ascii"),
        D3DCOMPILE_ENABLE_STRICTNESS,
        0,
        ctypes.byref(code),
        ctypes.byref(err),
    )
    if hr != 0:
        msg = "D3DCompile failed."
        if err:
            get_ptr = com_method(err, 3, ctypes.c_void_p, (ctypes.c_void_p,))
            get_sz  = com_method(err, 4, ctypes.c_size_t, (ctypes.c_void_p,))
            p = get_ptr(err)
            n = get_sz(err)
            if p and n:
                msg = ctypes.string_at(p, n).decode("utf-8", "replace")
            com_release(err)
        raise RuntimeError(msg)
    if err:
        com_release(err)
    debug_print(f"compile_hlsl({entry}, {target}) - SUCCESS")
    return code

def blob_ptr(blob: ctypes.c_void_p) -> ctypes.c_void_p:
    return com_method(blob, 3, ctypes.c_void_p, (ctypes.c_void_p,))(blob)

def blob_size(blob: ctypes.c_void_p) -> int:
    return com_method(blob, 4, ctypes.c_size_t, (ctypes.c_void_p,))(blob)

# ============================================================
# D3D12 init
# ============================================================
def init_d3d():
    global g_factory, g_device, g_command_queue, g_swap_chain
    global g_rtv_heap, g_srv_uav_heap, g_render_targets
    global g_command_allocator, g_command_list
    global g_compute_command_allocator, g_compute_command_list
    global g_graphics_root_signature, g_compute_root_signature
    global g_graphics_pipeline_state, g_compute_pipeline_state
    global g_position_buffer, g_color_buffer, g_constant_buffer, g_constant_buffer_ptr
    global g_fence, g_fence_event, g_fence_value, g_frame_index
    global g_rtv_descriptor_size, g_srv_uav_descriptor_size
    global g_width, g_height

    debug_print("=== init_d3d() ===")

    # Enable debug layer BEFORE creating device
    enable_debug_layer()

    rc = RECT()
    if not user32.GetClientRect(g_hwnd, ctypes.byref(rc)):
        raise winerr()
    g_width  = rc.right - rc.left
    g_height = rc.bottom - rc.top
    g_params.resolutionX = float(g_width)
    g_params.resolutionY = float(g_height)

    # --- Create DXGI Factory ---
    debug_print("CreateDXGIFactory1()")
    hr = CreateDXGIFactory1(ctypes.byref(IID_IDXGIFactory4), ctypes.byref(g_factory))
    if hr != 0:
        raise RuntimeError(f"CreateDXGIFactory1 failed: 0x{hr & 0xFFFFFFFF:08X}")
    debug_print(f"CreateDXGIFactory1() - SUCCESS: 0x{g_factory.value:016X}")

    # --- Create Device ---
    debug_print("D3D12CreateDevice()")
    hr = D3D12CreateDevice(None, D3D_FEATURE_LEVEL_12_0, ctypes.byref(IID_ID3D12Device), ctypes.byref(g_device))
    if hr != 0:
        raise RuntimeError(f"D3D12CreateDevice failed: 0x{hr & 0xFFFFFFFF:08X}")
    debug_print(f"D3D12CreateDevice() - SUCCESS: 0x{g_device.value:016X}")

    # --- Create Command Queue ---
    debug_print("ID3D12Device::CreateCommandQueue()")
    queue_desc = D3D12_COMMAND_QUEUE_DESC()
    queue_desc.Type = D3D12_COMMAND_LIST_TYPE_DIRECT
    queue_desc.Flags = D3D12_COMMAND_QUEUE_FLAG_NONE

    # VTable index 8
    create_cq = com_method(g_device, 8, wintypes.HRESULT,
                           (ctypes.c_void_p, ctypes.POINTER(D3D12_COMMAND_QUEUE_DESC),
                            ctypes.POINTER(GUID), ctypes.POINTER(ctypes.c_void_p)))
    hr = create_cq(g_device, ctypes.byref(queue_desc), ctypes.byref(IID_ID3D12CommandQueue), ctypes.byref(g_command_queue))
    if hr != 0:
        raise RuntimeError(f"CreateCommandQueue failed: 0x{hr & 0xFFFFFFFF:08X}")
    debug_print(f"ID3D12Device::CreateCommandQueue() - SUCCESS: 0x{g_command_queue.value:016X}")

    # --- Create Swap Chain ---
    debug_print("IDXGIFactory2::CreateSwapChainForHwnd()")
    sc_desc = DXGI_SWAP_CHAIN_DESC1()
    sc_desc.Width = g_width
    sc_desc.Height = g_height
    sc_desc.Format = DXGI_FORMAT_R8G8B8A8_UNORM
    sc_desc.Stereo = False
    sc_desc.SampleDesc.Count = 1
    sc_desc.SampleDesc.Quality = 0
    sc_desc.BufferUsage = 0x00000020  # DXGI_USAGE_RENDER_TARGET_OUTPUT
    sc_desc.BufferCount = FRAME_COUNT
    sc_desc.Scaling = 1  # DXGI_SCALING_STRETCH
    sc_desc.SwapEffect = DXGI_SWAP_EFFECT_FLIP_DISCARD
    sc_desc.AlphaMode = 0
    sc_desc.Flags = 0

    # VTable index 15
    create_sc = com_method(g_factory, 15, wintypes.HRESULT,
                           (ctypes.c_void_p, ctypes.c_void_p, wintypes.HWND,
                            ctypes.POINTER(DXGI_SWAP_CHAIN_DESC1), ctypes.c_void_p, ctypes.c_void_p,
                            ctypes.POINTER(ctypes.c_void_p)))
    swap_temp = ctypes.c_void_p()
    hr = create_sc(g_factory, g_command_queue, g_hwnd, ctypes.byref(sc_desc), None, None, ctypes.byref(swap_temp))
    if hr != 0:
        raise RuntimeError(f"CreateSwapChainForHwnd failed: 0x{hr & 0xFFFFFFFF:08X}")
    debug_print(f"IDXGIFactory2::CreateSwapChainForHwnd() - SUCCESS: 0x{swap_temp.value:016X}")

    # Query IDXGISwapChain3
    debug_print("IUnknown::QueryInterface(IDXGISwapChain3)")
    qi = com_method(swap_temp, 0, wintypes.HRESULT, (ctypes.c_void_p, ctypes.POINTER(GUID), ctypes.POINTER(ctypes.c_void_p)))
    hr = qi(swap_temp, ctypes.byref(IID_IDXGISwapChain3), ctypes.byref(g_swap_chain))
    com_release(swap_temp)
    if hr != 0:
        raise RuntimeError(f"QueryInterface IDXGISwapChain3 failed: 0x{hr & 0xFFFFFFFF:08X}")
    debug_print(f"IUnknown::QueryInterface(IDXGISwapChain3) - SUCCESS: 0x{g_swap_chain.value:016X}")

    # Get current back buffer index
    debug_print("IDXGISwapChain3::GetCurrentBackBufferIndex()")
    # VTable index 36
    get_idx = com_method(g_swap_chain, 36, wintypes.UINT, (ctypes.c_void_p,))
    g_frame_index = get_idx(g_swap_chain)
    debug_print(f"IDXGISwapChain3::GetCurrentBackBufferIndex() - SUCCESS: {g_frame_index}")

    # --- Create RTV Descriptor Heap ---
    debug_print("ID3D12Device::CreateDescriptorHeap(RTV)")
    rtv_heap_desc = D3D12_DESCRIPTOR_HEAP_DESC()
    rtv_heap_desc.Type = D3D12_DESCRIPTOR_HEAP_TYPE_RTV
    rtv_heap_desc.NumDescriptors = FRAME_COUNT
    rtv_heap_desc.Flags = D3D12_DESCRIPTOR_HEAP_FLAG_NONE
    rtv_heap_desc.NodeMask = 0

    # VTable index 14
    create_heap = com_method(g_device, 14, wintypes.HRESULT,
                             (ctypes.c_void_p, ctypes.POINTER(D3D12_DESCRIPTOR_HEAP_DESC),
                              ctypes.POINTER(GUID), ctypes.POINTER(ctypes.c_void_p)))
    hr = create_heap(g_device, ctypes.byref(rtv_heap_desc), ctypes.byref(IID_ID3D12DescriptorHeap), ctypes.byref(g_rtv_heap))
    if hr != 0:
        raise RuntimeError(f"CreateDescriptorHeap(RTV) failed: 0x{hr & 0xFFFFFFFF:08X}")
    debug_print(f"ID3D12Device::CreateDescriptorHeap(RTV) - SUCCESS: 0x{g_rtv_heap.value:016X}")

    # VTable index 15
    debug_print("ID3D12Device::GetDescriptorHandleIncrementSize(RTV)")
    get_inc_size = com_method(g_device, 15, wintypes.UINT, (ctypes.c_void_p, wintypes.UINT))
    g_rtv_descriptor_size = get_inc_size(g_device, D3D12_DESCRIPTOR_HEAP_TYPE_RTV)
    debug_print(f"ID3D12Device::GetDescriptorHandleIncrementSize(RTV) - SUCCESS: {g_rtv_descriptor_size}")

    # --- Create SRV/UAV/CBV Descriptor Heap ---
    debug_print("ID3D12Device::CreateDescriptorHeap(SRV_UAV_CBV)")
    srv_uav_heap_desc = D3D12_DESCRIPTOR_HEAP_DESC()
    srv_uav_heap_desc.Type = D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV
    srv_uav_heap_desc.NumDescriptors = 5  # 2 UAVs + 2 SRVs + 1 CBV
    srv_uav_heap_desc.Flags = D3D12_DESCRIPTOR_HEAP_FLAG_SHADER_VISIBLE
    srv_uav_heap_desc.NodeMask = 0

    hr = create_heap(g_device, ctypes.byref(srv_uav_heap_desc), ctypes.byref(IID_ID3D12DescriptorHeap), ctypes.byref(g_srv_uav_heap))
    if hr != 0:
        raise RuntimeError(f"CreateDescriptorHeap(SRV_UAV_CBV) failed: 0x{hr & 0xFFFFFFFF:08X}")
    debug_print(f"ID3D12Device::CreateDescriptorHeap(SRV_UAV_CBV) - SUCCESS: 0x{g_srv_uav_heap.value:016X}")

    debug_print("ID3D12Device::GetDescriptorHandleIncrementSize(CBV_SRV_UAV)")
    g_srv_uav_descriptor_size = get_inc_size(g_device, D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV)
    debug_print(f"ID3D12Device::GetDescriptorHandleIncrementSize(CBV_SRV_UAV) - SUCCESS: {g_srv_uav_descriptor_size}")

    # --- Get RTV heap CPU handle ---
    debug_print("ID3D12DescriptorHeap::GetCPUDescriptorHandleForHeapStart(RTV)")
    # VTable index 9
    heap_ptr = ctypes.c_void_p(g_rtv_heap.value)
    get_cpu_handle = com_method(heap_ptr, 9, ctypes.c_void_p,
                               (ctypes.c_void_p, ctypes.POINTER(D3D12_CPU_DESCRIPTOR_HANDLE)))
    rtv_handle = D3D12_CPU_DESCRIPTOR_HANDLE()
    get_cpu_handle(heap_ptr, ctypes.byref(rtv_handle))
    debug_print(f"ID3D12DescriptorHeap::GetCPUDescriptorHandleForHeapStart(RTV) - SUCCESS: 0x{rtv_handle.ptr:016X}")

    # --- Create RTVs for each frame ---
    for i in range(FRAME_COUNT):
        debug_print(f"IDXGISwapChain::GetBuffer({i})")
        # VTable index 9
        get_buffer = com_method(g_swap_chain, 9, wintypes.HRESULT,
                               (ctypes.c_void_p, wintypes.UINT, ctypes.POINTER(GUID), ctypes.POINTER(ctypes.c_void_p)))
        hr = get_buffer(g_swap_chain, i, ctypes.byref(IID_ID3D12Resource), ctypes.byref(g_render_targets[i]))
        if hr != 0:
            raise RuntimeError(f"GetBuffer({i}) failed: 0x{hr & 0xFFFFFFFF:08X}")
        debug_print(f"IDXGISwapChain::GetBuffer({i}) - SUCCESS: 0x{g_render_targets[i].value:016X}")

        # VTable index 20
        debug_print(f"ID3D12Device::CreateRenderTargetView({i})")
        create_rtv = com_method(g_device, 20, None,
                               (ctypes.c_void_p, ctypes.c_void_p, ctypes.c_void_p, D3D12_CPU_DESCRIPTOR_HANDLE))
        handle_copy = D3D12_CPU_DESCRIPTOR_HANDLE(rtv_handle.ptr + i * g_rtv_descriptor_size)
        create_rtv(g_device, g_render_targets[i], None, handle_copy)
        debug_print(f"ID3D12Device::CreateRenderTargetView({i}) - SUCCESS")

    # --- Create Command Allocators ---
    debug_print("ID3D12Device::CreateCommandAllocator(DIRECT)")
    # VTable index 9
    create_ca = com_method(g_device, 9, wintypes.HRESULT,
                          (ctypes.c_void_p, wintypes.UINT, ctypes.POINTER(GUID), ctypes.POINTER(ctypes.c_void_p)))
    hr = create_ca(g_device, D3D12_COMMAND_LIST_TYPE_DIRECT, ctypes.byref(IID_ID3D12CommandAllocator), ctypes.byref(g_command_allocator))
    if hr != 0:
        raise RuntimeError(f"CreateCommandAllocator(DIRECT) failed: 0x{hr & 0xFFFFFFFF:08X}")
    debug_print(f"ID3D12Device::CreateCommandAllocator(DIRECT) - SUCCESS: 0x{g_command_allocator.value:016X}")

    debug_print("ID3D12Device::CreateCommandAllocator(DIRECT for compute)")
    hr = create_ca(g_device, D3D12_COMMAND_LIST_TYPE_DIRECT, ctypes.byref(IID_ID3D12CommandAllocator), ctypes.byref(g_compute_command_allocator))
    if hr != 0:
        raise RuntimeError(f"CreateCommandAllocator(DIRECT for compute) failed: 0x{hr & 0xFFFFFFFF:08X}")
    debug_print(f"ID3D12Device::CreateCommandAllocator(DIRECT for compute) - SUCCESS: 0x{g_compute_command_allocator.value:016X}")

    # --- Create Buffers ---
    debug_print("Creating Buffers...")
    buffer_size = VERTEX_COUNT * 16  # float4 = 16 bytes

    default_heap = D3D12_HEAP_PROPERTIES()
    default_heap.Type = D3D12_HEAP_TYPE_DEFAULT
    default_heap.CPUPageProperty = 0
    default_heap.MemoryPoolPreference = 0
    default_heap.CreationNodeMask = 1
    default_heap.VisibleNodeMask = 1

    upload_heap = D3D12_HEAP_PROPERTIES()
    upload_heap.Type = D3D12_HEAP_TYPE_UPLOAD
    upload_heap.CPUPageProperty = 0
    upload_heap.MemoryPoolPreference = 0
    upload_heap.CreationNodeMask = 1
    upload_heap.VisibleNodeMask = 1

    buffer_desc = D3D12_RESOURCE_DESC()
    buffer_desc.Dimension = D3D12_RESOURCE_DIMENSION_BUFFER
    buffer_desc.Alignment = 0
    buffer_desc.Width = buffer_size
    buffer_desc.Height = 1
    buffer_desc.DepthOrArraySize = 1
    buffer_desc.MipLevels = 1
    buffer_desc.Format = DXGI_FORMAT_UNKNOWN
    buffer_desc.SampleDesc.Count = 1
    buffer_desc.SampleDesc.Quality = 0
    buffer_desc.Layout = D3D12_TEXTURE_LAYOUT_ROW_MAJOR
    buffer_desc.Flags = D3D12_RESOURCE_FLAG_ALLOW_UNORDERED_ACCESS

    # VTable index 27
    debug_print("ID3D12Device::CreateCommittedResource(positionBuffer)")
    create_resource = com_method(g_device, 27, wintypes.HRESULT,
                                (ctypes.c_void_p, ctypes.POINTER(D3D12_HEAP_PROPERTIES), wintypes.UINT,
                                 ctypes.POINTER(D3D12_RESOURCE_DESC), wintypes.UINT, ctypes.c_void_p,
                                 ctypes.POINTER(GUID), ctypes.POINTER(ctypes.c_void_p)))
    hr = create_resource(g_device, ctypes.byref(default_heap), 0, ctypes.byref(buffer_desc),
                        D3D12_RESOURCE_STATE_COMMON, None, ctypes.byref(IID_ID3D12Resource), ctypes.byref(g_position_buffer))
    if hr != 0:
        raise RuntimeError(f"CreateCommittedResource(positionBuffer) failed: 0x{hr & 0xFFFFFFFF:08X}")
    debug_print(f"ID3D12Device::CreateCommittedResource(positionBuffer) - SUCCESS: 0x{g_position_buffer.value:016X}")

    debug_print("ID3D12Device::CreateCommittedResource(colorBuffer)")
    hr = create_resource(g_device, ctypes.byref(default_heap), 0, ctypes.byref(buffer_desc),
                        D3D12_RESOURCE_STATE_COMMON, None, ctypes.byref(IID_ID3D12Resource), ctypes.byref(g_color_buffer))
    if hr != 0:
        raise RuntimeError(f"CreateCommittedResource(colorBuffer) failed: 0x{hr & 0xFFFFFFFF:08X}")
    debug_print(f"ID3D12Device::CreateCommittedResource(colorBuffer) - SUCCESS: 0x{g_color_buffer.value:016X}")

    # Constant buffer (256 bytes aligned)
    cb_desc = D3D12_RESOURCE_DESC()
    cb_desc.Dimension = D3D12_RESOURCE_DIMENSION_BUFFER
    cb_desc.Alignment = 0
    cb_desc.Width = 256
    cb_desc.Height = 1
    cb_desc.DepthOrArraySize = 1
    cb_desc.MipLevels = 1
    cb_desc.Format = DXGI_FORMAT_UNKNOWN
    cb_desc.SampleDesc.Count = 1
    cb_desc.SampleDesc.Quality = 0
    cb_desc.Layout = D3D12_TEXTURE_LAYOUT_ROW_MAJOR
    cb_desc.Flags = D3D12_RESOURCE_FLAG_NONE

    debug_print("ID3D12Device::CreateCommittedResource(constantBuffer)")
    hr = create_resource(g_device, ctypes.byref(upload_heap), 0, ctypes.byref(cb_desc),
                        D3D12_RESOURCE_STATE_GENERIC_READ, None, ctypes.byref(IID_ID3D12Resource), ctypes.byref(g_constant_buffer))
    if hr != 0:
        raise RuntimeError(f"CreateCommittedResource(constantBuffer) failed: 0x{hr & 0xFFFFFFFF:08X}")
    debug_print(f"ID3D12Device::CreateCommittedResource(constantBuffer) - SUCCESS: 0x{g_constant_buffer.value:016X}")

    # Map constant buffer
    debug_print("ID3D12Resource::Map(constantBuffer)")
    # VTable index 8
    map_fn = com_method(g_constant_buffer, 8, wintypes.HRESULT,
                       (ctypes.c_void_p, wintypes.UINT, ctypes.POINTER(D3D12_RANGE), ctypes.POINTER(ctypes.c_void_p)))
    read_range = D3D12_RANGE(0, 0)
    cb_ptr = ctypes.c_void_p()
    hr = map_fn(g_constant_buffer, 0, ctypes.byref(read_range), ctypes.byref(cb_ptr))
    if hr != 0:
        raise RuntimeError(f"Map(constantBuffer) failed: 0x{hr & 0xFFFFFFFF:08X}")
    g_constant_buffer_ptr = cb_ptr.value
    debug_print(f"ID3D12Resource::Map(constantBuffer) - SUCCESS: 0x{g_constant_buffer_ptr:016X}")

    # --- Create UAVs and SRVs ---
    debug_print("Creating UAVs and SRVs...")
    
    # Get SRV/UAV heap CPU handle
    debug_print("ID3D12DescriptorHeap::GetCPUDescriptorHandleForHeapStart(SRV_UAV)")
    srv_uav_heap_ptr = ctypes.c_void_p(g_srv_uav_heap.value)
    srv_uav_cpu_handle = D3D12_CPU_DESCRIPTOR_HANDLE()
    get_cpu_handle_srv = com_method(srv_uav_heap_ptr, 9, ctypes.c_void_p,
                                   (ctypes.c_void_p, ctypes.POINTER(D3D12_CPU_DESCRIPTOR_HANDLE)))
    get_cpu_handle_srv(srv_uav_heap_ptr, ctypes.byref(srv_uav_cpu_handle))
    debug_print(f"ID3D12DescriptorHeap::GetCPUDescriptorHandleForHeapStart(SRV_UAV) - SUCCESS: 0x{srv_uav_cpu_handle.ptr:016X}")

    # VTable index 19 - CreateUnorderedAccessView
    debug_print("ID3D12Device::CreateUnorderedAccessView(positionBuffer)")
    create_uav = com_method(g_device, 19, None,
                           (ctypes.c_void_p, ctypes.c_void_p, ctypes.c_void_p,
                            ctypes.POINTER(D3D12_UNORDERED_ACCESS_VIEW_DESC), D3D12_CPU_DESCRIPTOR_HANDLE))
    
    uav_desc = D3D12_UNORDERED_ACCESS_VIEW_DESC()
    uav_desc.Format = DXGI_FORMAT_UNKNOWN
    uav_desc.ViewDimension = D3D12_UAV_DIMENSION_BUFFER
    uav_desc.Buffer.FirstElement = 0
    uav_desc.Buffer.NumElements = VERTEX_COUNT
    uav_desc.Buffer.StructureByteStride = 16
    uav_desc.Buffer.CounterOffsetInBytes = 0
    uav_desc.Buffer.Flags = 0

    # Slot 0: Position UAV
    handle0 = D3D12_CPU_DESCRIPTOR_HANDLE(srv_uav_cpu_handle.ptr)
    create_uav(g_device, g_position_buffer, None, ctypes.byref(uav_desc), handle0)
    debug_print("ID3D12Device::CreateUnorderedAccessView(positionBuffer) - SUCCESS")

    # Slot 1: Color UAV
    debug_print("ID3D12Device::CreateUnorderedAccessView(colorBuffer)")
    handle1 = D3D12_CPU_DESCRIPTOR_HANDLE(srv_uav_cpu_handle.ptr + g_srv_uav_descriptor_size)
    create_uav(g_device, g_color_buffer, None, ctypes.byref(uav_desc), handle1)
    debug_print("ID3D12Device::CreateUnorderedAccessView(colorBuffer) - SUCCESS")

    # VTable index 18 - CreateShaderResourceView
    debug_print("ID3D12Device::CreateShaderResourceView(positionBuffer)")
    create_srv = com_method(g_device, 18, None,
                           (ctypes.c_void_p, ctypes.c_void_p, ctypes.POINTER(D3D12_SHADER_RESOURCE_VIEW_DESC),
                            D3D12_CPU_DESCRIPTOR_HANDLE))
    
    srv_desc = D3D12_SHADER_RESOURCE_VIEW_DESC()
    srv_desc.Format = DXGI_FORMAT_UNKNOWN
    srv_desc.ViewDimension = D3D12_SRV_DIMENSION_BUFFER
    srv_desc.Shader4ComponentMapping = D3D12_DEFAULT_SHADER_4_COMPONENT_MAPPING
    srv_desc.Buffer.FirstElement = 0
    srv_desc.Buffer.NumElements = VERTEX_COUNT
    srv_desc.Buffer.StructureByteStride = 16
    srv_desc.Buffer.Flags = 0

    # Slot 2: Position SRV
    handle2 = D3D12_CPU_DESCRIPTOR_HANDLE(srv_uav_cpu_handle.ptr + g_srv_uav_descriptor_size * 2)
    create_srv(g_device, g_position_buffer, ctypes.byref(srv_desc), handle2)
    debug_print("ID3D12Device::CreateShaderResourceView(positionBuffer) - SUCCESS")

    # Slot 3: Color SRV
    debug_print("ID3D12Device::CreateShaderResourceView(colorBuffer)")
    handle3 = D3D12_CPU_DESCRIPTOR_HANDLE(srv_uav_cpu_handle.ptr + g_srv_uav_descriptor_size * 3)
    create_srv(g_device, g_color_buffer, ctypes.byref(srv_desc), handle3)
    debug_print("ID3D12Device::CreateShaderResourceView(colorBuffer) - SUCCESS")

    # VTable index 17 - CreateConstantBufferView
    debug_print("ID3D12Device::CreateConstantBufferView()")
    create_cbv = com_method(g_device, 17, None,
                           (ctypes.c_void_p, ctypes.POINTER(D3D12_CONSTANT_BUFFER_VIEW_DESC),
                            D3D12_CPU_DESCRIPTOR_HANDLE))
    
    # Get GPU virtual address of constant buffer
    # VTable index 11
    get_gpu_va = com_method(g_constant_buffer, 11, ctypes.c_uint64, (ctypes.c_void_p,))
    cb_gpu_va = get_gpu_va(g_constant_buffer)
    
    cbv_desc = D3D12_CONSTANT_BUFFER_VIEW_DESC()
    cbv_desc.BufferLocation = cb_gpu_va
    cbv_desc.SizeInBytes = 256

    # Slot 4: CBV
    handle4 = D3D12_CPU_DESCRIPTOR_HANDLE(srv_uav_cpu_handle.ptr + g_srv_uav_descriptor_size * 4)
    create_cbv(g_device, ctypes.byref(cbv_desc), handle4)
    debug_print("ID3D12Device::CreateConstantBufferView() - SUCCESS")

    # --- Create Compute Root Signature ---
    debug_print("Creating Compute Root Signature...")
    
    # UAV range for compute (u0, u1)
    uav_range = D3D12_DESCRIPTOR_RANGE()
    uav_range.RangeType = D3D12_DESCRIPTOR_RANGE_TYPE_UAV
    uav_range.NumDescriptors = 2
    uav_range.BaseShaderRegister = 0
    uav_range.RegisterSpace = 0
    uav_range.OffsetInDescriptorsFromTableStart = 0xFFFFFFFF  # D3D12_DESCRIPTOR_RANGE_OFFSET_APPEND

    # CBV range (b0)
    cbv_range = D3D12_DESCRIPTOR_RANGE()
    cbv_range.RangeType = D3D12_DESCRIPTOR_RANGE_TYPE_CBV
    cbv_range.NumDescriptors = 1
    cbv_range.BaseShaderRegister = 0
    cbv_range.RegisterSpace = 0
    cbv_range.OffsetInDescriptorsFromTableStart = 0xFFFFFFFF

    uav_range_array = (D3D12_DESCRIPTOR_RANGE * 1)(uav_range)
    cbv_range_array = (D3D12_DESCRIPTOR_RANGE * 1)(cbv_range)

    compute_params = (D3D12_ROOT_PARAMETER * 2)()
    
    # Parameter 0: UAV table
    compute_params[0].ParameterType = D3D12_ROOT_PARAMETER_TYPE_DESCRIPTOR_TABLE
    compute_params[0].u.DescriptorTable.NumDescriptorRanges = 1
    compute_params[0].u.DescriptorTable.pDescriptorRanges = ctypes.cast(uav_range_array, ctypes.c_void_p).value
    compute_params[0].ShaderVisibility = D3D12_SHADER_VISIBILITY_ALL

    # Parameter 1: CBV table
    compute_params[1].ParameterType = D3D12_ROOT_PARAMETER_TYPE_DESCRIPTOR_TABLE
    compute_params[1].u.DescriptorTable.NumDescriptorRanges = 1
    compute_params[1].u.DescriptorTable.pDescriptorRanges = ctypes.cast(cbv_range_array, ctypes.c_void_p).value
    compute_params[1].ShaderVisibility = D3D12_SHADER_VISIBILITY_ALL

    compute_rs_desc = D3D12_ROOT_SIGNATURE_DESC()
    compute_rs_desc.NumParameters = 2
    compute_rs_desc.pParameters = ctypes.cast(compute_params, ctypes.c_void_p).value
    compute_rs_desc.NumStaticSamplers = 0
    compute_rs_desc.pStaticSamplers = None
    compute_rs_desc.Flags = D3D12_ROOT_SIGNATURE_FLAG_NONE

    debug_print("D3D12SerializeRootSignature(Compute)")
    compute_rs_blob = ctypes.c_void_p()
    err_blob = ctypes.c_void_p()
    hr = D3D12SerializeRootSignature(ctypes.byref(compute_rs_desc), D3D_ROOT_SIGNATURE_VERSION_1,
                                     ctypes.byref(compute_rs_blob), ctypes.byref(err_blob))
    if hr != 0:
        msg = "D3D12SerializeRootSignature(Compute) failed"
        if err_blob:
            get_ptr = com_method(err_blob, 3, ctypes.c_void_p, (ctypes.c_void_p,))
            p = get_ptr(err_blob)
            if p:
                msg = ctypes.string_at(p).decode("utf-8", "replace")
            com_release(err_blob)
        raise RuntimeError(msg)
    if err_blob:
        com_release(err_blob)
    debug_print("D3D12SerializeRootSignature(Compute) - SUCCESS")

    # VTable index 16
    debug_print("ID3D12Device::CreateRootSignature(Compute)")
    create_rs = com_method(g_device, 16, wintypes.HRESULT,
                          (ctypes.c_void_p, wintypes.UINT, ctypes.c_void_p, ctypes.c_size_t,
                           ctypes.POINTER(GUID), ctypes.POINTER(ctypes.c_void_p)))
    hr = create_rs(g_device, 0, blob_ptr(compute_rs_blob), blob_size(compute_rs_blob),
                  ctypes.byref(IID_ID3D12RootSignature), ctypes.byref(g_compute_root_signature))
    com_release(compute_rs_blob)
    if hr != 0:
        raise RuntimeError(f"CreateRootSignature(Compute) failed: 0x{hr & 0xFFFFFFFF:08X}")
    debug_print(f"ID3D12Device::CreateRootSignature(Compute) - SUCCESS: 0x{g_compute_root_signature.value:016X}")

    # --- Create Graphics Root Signature ---
    debug_print("Creating Graphics Root Signature...")
    
    # SRV range (t0, t1)
    srv_range = D3D12_DESCRIPTOR_RANGE()
    srv_range.RangeType = D3D12_DESCRIPTOR_RANGE_TYPE_SRV
    srv_range.NumDescriptors = 2
    srv_range.BaseShaderRegister = 0
    srv_range.RegisterSpace = 0
    srv_range.OffsetInDescriptorsFromTableStart = 0xFFFFFFFF

    srv_range_array = (D3D12_DESCRIPTOR_RANGE * 1)(srv_range)

    graphics_params = (D3D12_ROOT_PARAMETER * 2)()
    
    # Parameter 0: SRV table
    graphics_params[0].ParameterType = D3D12_ROOT_PARAMETER_TYPE_DESCRIPTOR_TABLE
    graphics_params[0].u.DescriptorTable.NumDescriptorRanges = 1
    graphics_params[0].u.DescriptorTable.pDescriptorRanges = ctypes.cast(srv_range_array, ctypes.c_void_p).value
    graphics_params[0].ShaderVisibility = D3D12_SHADER_VISIBILITY_VERTEX

    # Parameter 1: CBV table
    graphics_params[1].ParameterType = D3D12_ROOT_PARAMETER_TYPE_DESCRIPTOR_TABLE
    graphics_params[1].u.DescriptorTable.NumDescriptorRanges = 1
    graphics_params[1].u.DescriptorTable.pDescriptorRanges = ctypes.cast(cbv_range_array, ctypes.c_void_p).value
    graphics_params[1].ShaderVisibility = D3D12_SHADER_VISIBILITY_VERTEX

    graphics_rs_desc = D3D12_ROOT_SIGNATURE_DESC()
    graphics_rs_desc.NumParameters = 2
    graphics_rs_desc.pParameters = ctypes.cast(graphics_params, ctypes.c_void_p).value
    graphics_rs_desc.NumStaticSamplers = 0
    graphics_rs_desc.pStaticSamplers = None
    graphics_rs_desc.Flags = D3D12_ROOT_SIGNATURE_FLAG_NONE

    debug_print("D3D12SerializeRootSignature(Graphics)")
    graphics_rs_blob = ctypes.c_void_p()
    err_blob = ctypes.c_void_p()
    hr = D3D12SerializeRootSignature(ctypes.byref(graphics_rs_desc), D3D_ROOT_SIGNATURE_VERSION_1,
                                     ctypes.byref(graphics_rs_blob), ctypes.byref(err_blob))
    if hr != 0:
        msg = "D3D12SerializeRootSignature(Graphics) failed"
        if err_blob:
            get_ptr = com_method(err_blob, 3, ctypes.c_void_p, (ctypes.c_void_p,))
            p = get_ptr(err_blob)
            if p:
                msg = ctypes.string_at(p).decode("utf-8", "replace")
            com_release(err_blob)
        raise RuntimeError(msg)
    if err_blob:
        com_release(err_blob)
    debug_print("D3D12SerializeRootSignature(Graphics) - SUCCESS")

    debug_print("ID3D12Device::CreateRootSignature(Graphics)")
    hr = create_rs(g_device, 0, blob_ptr(graphics_rs_blob), blob_size(graphics_rs_blob),
                  ctypes.byref(IID_ID3D12RootSignature), ctypes.byref(g_graphics_root_signature))
    com_release(graphics_rs_blob)
    if hr != 0:
        raise RuntimeError(f"CreateRootSignature(Graphics) failed: 0x{hr & 0xFFFFFFFF:08X}")
    debug_print(f"ID3D12Device::CreateRootSignature(Graphics) - SUCCESS: 0x{g_graphics_root_signature.value:016X}")

    # --- Compile Shaders ---
    cs_blob = compile_hlsl("CSMain", "cs_5_0")
    vs_blob = compile_hlsl("VSMain", "vs_5_0")
    ps_blob = compile_hlsl("PSMain", "ps_5_0")

    # --- Create Compute Pipeline State ---
    debug_print("ID3D12Device::CreateComputePipelineState()")
    compute_pso_desc = D3D12_COMPUTE_PIPELINE_STATE_DESC()
    ctypes.memset(ctypes.byref(compute_pso_desc), 0, ctypes.sizeof(compute_pso_desc))
    compute_pso_desc.pRootSignature = g_compute_root_signature.value
    compute_pso_desc.CS.pShaderBytecode = blob_ptr(cs_blob)
    compute_pso_desc.CS.BytecodeLength = blob_size(cs_blob)

    # VTable index 11
    create_compute_pso = com_method(g_device, 11, wintypes.HRESULT,
                                   (ctypes.c_void_p, ctypes.POINTER(D3D12_COMPUTE_PIPELINE_STATE_DESC),
                                    ctypes.POINTER(GUID), ctypes.POINTER(ctypes.c_void_p)))
    hr = create_compute_pso(g_device, ctypes.byref(compute_pso_desc), ctypes.byref(IID_ID3D12PipelineState), ctypes.byref(g_compute_pipeline_state))
    if hr != 0:
        raise RuntimeError(f"CreateComputePipelineState failed: 0x{hr & 0xFFFFFFFF:08X}")
    debug_print(f"ID3D12Device::CreateComputePipelineState() - SUCCESS: 0x{g_compute_pipeline_state.value:016X}")

    # --- Create Graphics Pipeline State ---
    debug_print("ID3D12Device::CreateGraphicsPipelineState()")
    pso_desc = D3D12_GRAPHICS_PIPELINE_STATE_DESC()
    ctypes.memset(ctypes.byref(pso_desc), 0, ctypes.sizeof(pso_desc))

    pso_desc.pRootSignature = g_graphics_root_signature.value
    pso_desc.VS.pShaderBytecode = blob_ptr(vs_blob)
    pso_desc.VS.BytecodeLength = blob_size(vs_blob)
    pso_desc.PS.pShaderBytecode = blob_ptr(ps_blob)
    pso_desc.PS.BytecodeLength = blob_size(ps_blob)

    # Blend state
    pso_desc.BlendState.AlphaToCoverageEnable = False
    pso_desc.BlendState.IndependentBlendEnable = False
    pso_desc.BlendState.RenderTarget[0].BlendEnable = False
    pso_desc.BlendState.RenderTarget[0].LogicOpEnable = False
    pso_desc.BlendState.RenderTarget[0].SrcBlend = D3D12_BLEND_ONE
    pso_desc.BlendState.RenderTarget[0].DestBlend = D3D12_BLEND_ZERO
    pso_desc.BlendState.RenderTarget[0].BlendOp = D3D12_BLEND_OP_ADD
    pso_desc.BlendState.RenderTarget[0].SrcBlendAlpha = D3D12_BLEND_ONE
    pso_desc.BlendState.RenderTarget[0].DestBlendAlpha = D3D12_BLEND_ZERO
    pso_desc.BlendState.RenderTarget[0].BlendOpAlpha = D3D12_BLEND_OP_ADD
    pso_desc.BlendState.RenderTarget[0].LogicOp = D3D12_LOGIC_OP_NOOP
    pso_desc.BlendState.RenderTarget[0].RenderTargetWriteMask = D3D12_COLOR_WRITE_ENABLE_ALL

    pso_desc.SampleMask = 0xFFFFFFFF

    # Rasterizer state
    pso_desc.RasterizerState.FillMode = D3D12_FILL_MODE_SOLID
    pso_desc.RasterizerState.CullMode = D3D12_CULL_MODE_NONE
    pso_desc.RasterizerState.FrontCounterClockwise = False
    pso_desc.RasterizerState.DepthBias = 0
    pso_desc.RasterizerState.DepthBiasClamp = 0.0
    pso_desc.RasterizerState.SlopeScaledDepthBias = 0.0
    pso_desc.RasterizerState.DepthClipEnable = True
    pso_desc.RasterizerState.MultisampleEnable = False
    pso_desc.RasterizerState.AntialiasedLineEnable = False
    pso_desc.RasterizerState.ForcedSampleCount = 0
    pso_desc.RasterizerState.ConservativeRaster = 0

    # Depth stencil (disabled)
    pso_desc.DepthStencilState.DepthEnable = False
    pso_desc.DepthStencilState.StencilEnable = False

    # No input layout (using SV_VertexID)
    pso_desc.InputLayout.pInputElementDescs = None
    pso_desc.InputLayout.NumElements = 0

    pso_desc.PrimitiveTopologyType = D3D12_PRIMITIVE_TOPOLOGY_TYPE_LINE
    pso_desc.NumRenderTargets = 1
    pso_desc.RTVFormats[0] = DXGI_FORMAT_R8G8B8A8_UNORM
    pso_desc.SampleDesc.Count = 1
    pso_desc.SampleDesc.Quality = 0

    # VTable index 10
    create_graphics_pso = com_method(g_device, 10, wintypes.HRESULT,
                                    (ctypes.c_void_p, ctypes.POINTER(D3D12_GRAPHICS_PIPELINE_STATE_DESC),
                                     ctypes.POINTER(GUID), ctypes.POINTER(ctypes.c_void_p)))
    hr = create_graphics_pso(g_device, ctypes.byref(pso_desc), ctypes.byref(IID_ID3D12PipelineState), ctypes.byref(g_graphics_pipeline_state))
    if hr != 0:
        raise RuntimeError(f"CreateGraphicsPipelineState failed: 0x{hr & 0xFFFFFFFF:08X}")
    debug_print(f"ID3D12Device::CreateGraphicsPipelineState() - SUCCESS: 0x{g_graphics_pipeline_state.value:016X}")

    # Free shader blobs
    com_release(cs_blob)
    com_release(vs_blob)
    com_release(ps_blob)

    # --- Create Command Lists ---
    debug_print("ID3D12Device::CreateCommandList(Graphics)")
    # VTable index 12
    create_cl = com_method(g_device, 12, wintypes.HRESULT,
                          (ctypes.c_void_p, wintypes.UINT, wintypes.UINT, ctypes.c_void_p, ctypes.c_void_p,
                           ctypes.POINTER(GUID), ctypes.POINTER(ctypes.c_void_p)))
    hr = create_cl(g_device, 0, D3D12_COMMAND_LIST_TYPE_DIRECT, g_command_allocator,
                  g_graphics_pipeline_state, ctypes.byref(IID_ID3D12GraphicsCommandList), ctypes.byref(g_command_list))
    if hr != 0:
        raise RuntimeError(f"CreateCommandList(Graphics) failed: 0x{hr & 0xFFFFFFFF:08X}")
    debug_print(f"ID3D12Device::CreateCommandList(Graphics) - SUCCESS: 0x{g_command_list.value:016X}")

    debug_print("ID3D12Device::CreateCommandList(Compute)")
    hr = create_cl(g_device, 0, D3D12_COMMAND_LIST_TYPE_DIRECT, g_compute_command_allocator,
                  g_compute_pipeline_state, ctypes.byref(IID_ID3D12GraphicsCommandList), ctypes.byref(g_compute_command_list))
    if hr != 0:
        raise RuntimeError(f"CreateCommandList(Compute) failed: 0x{hr & 0xFFFFFFFF:08X}")
    debug_print(f"ID3D12Device::CreateCommandList(Compute) - SUCCESS: 0x{g_compute_command_list.value:016X}")

    # Close command lists
    debug_print("ID3D12GraphicsCommandList::Close(Graphics)")
    # VTable index 9
    close_cl = com_method(g_command_list, 9, wintypes.HRESULT, (ctypes.c_void_p,))
    hr = close_cl(g_command_list)
    if hr != 0:
        raise RuntimeError(f"Close(Graphics) failed: 0x{hr & 0xFFFFFFFF:08X}")
    debug_print("ID3D12GraphicsCommandList::Close(Graphics) - SUCCESS")

    debug_print("ID3D12GraphicsCommandList::Close(Compute)")
    close_compute_cl = com_method(g_compute_command_list, 9, wintypes.HRESULT, (ctypes.c_void_p,))
    hr = close_compute_cl(g_compute_command_list)
    if hr != 0:
        raise RuntimeError(f"Close(Compute) failed: 0x{hr & 0xFFFFFFFF:08X}")
    debug_print("ID3D12GraphicsCommandList::Close(Compute) - SUCCESS")

    # --- Create Fence ---
    debug_print("ID3D12Device::CreateFence()")
    # VTable index 36
    create_fence = com_method(g_device, 36, wintypes.HRESULT,
                             (ctypes.c_void_p, ctypes.c_uint64, wintypes.UINT,
                              ctypes.POINTER(GUID), ctypes.POINTER(ctypes.c_void_p)))
    hr = create_fence(g_device, 0, D3D12_FENCE_FLAG_NONE, ctypes.byref(IID_ID3D12Fence), ctypes.byref(g_fence))
    if hr != 0:
        raise RuntimeError(f"CreateFence failed: 0x{hr & 0xFFFFFFFF:08X}")
    debug_print(f"ID3D12Device::CreateFence() - SUCCESS: 0x{g_fence.value:016X}")

    g_fence_value = 1
    g_fence_event = kernel32.CreateEventW(None, False, False, None)
    if not g_fence_event:
        raise RuntimeError("CreateEvent failed")
    debug_print(f"CreateEvent() - SUCCESS: 0x{g_fence_event:016X}")

    debug_print("=== init_d3d() COMPLETE ===")

def wait_for_previous_frame():
    global g_fence_value, g_frame_index
    
    current_fence_value = g_fence_value

    # Signal
    # VTable index 14
    signal = com_method(g_command_queue, 14, wintypes.HRESULT, (ctypes.c_void_p, ctypes.c_void_p, ctypes.c_uint64))
    hr = signal(g_command_queue, g_fence, current_fence_value)
    if hr != 0:
        raise RuntimeError(f"Signal failed: 0x{hr & 0xFFFFFFFF:08X}")

    g_fence_value += 1

    # VTable index 8
    get_completed = com_method(g_fence, 8, ctypes.c_uint64, (ctypes.c_void_p,))
    if get_completed(g_fence) < current_fence_value:
        # VTable index 9
        set_event = com_method(g_fence, 9, wintypes.HRESULT, (ctypes.c_void_p, ctypes.c_uint64, wintypes.HANDLE))
        hr = set_event(g_fence, current_fence_value, g_fence_event)
        if hr != 0:
            raise RuntimeError(f"SetEventOnCompletion failed: 0x{hr & 0xFFFFFFFF:08X}")
        kernel32.WaitForSingleObject(g_fence_event, INFINITE)

    # VTable index 36
    get_idx = com_method(g_swap_chain, 36, wintypes.UINT, (ctypes.c_void_p,))
    g_frame_index = get_idx(g_swap_chain)

def render():
    global g_frame_index, g_params

    # Update harmonograph parameters
    g_params.f1 = (g_params.f1 + random.random() / 200.0) % 10.0
    g_params.f2 = (g_params.f2 + random.random() / 200.0) % 10.0
    g_params.p1 += PI2 * 0.5 / 360.0

    # Copy params to constant buffer
    ctypes.memmove(g_constant_buffer_ptr, ctypes.byref(g_params), ctypes.sizeof(g_params))

    # ===== Compute Pass =====
    
    # Reset compute command allocator
    # VTable index 8
    reset_ca = com_method(g_compute_command_allocator, 8, wintypes.HRESULT, (ctypes.c_void_p,))
    hr = reset_ca(g_compute_command_allocator)
    if hr != 0:
        raise RuntimeError(f"ComputeCommandAllocator::Reset failed: 0x{hr & 0xFFFFFFFF:08X}")

    # Reset compute command list
    # VTable index 10
    reset_cl = com_method(g_compute_command_list, 10, wintypes.HRESULT, (ctypes.c_void_p, ctypes.c_void_p, ctypes.c_void_p))
    hr = reset_cl(g_compute_command_list, g_compute_command_allocator, g_compute_pipeline_state)
    if hr != 0:
        raise RuntimeError(f"ComputeCommandList::Reset failed: 0x{hr & 0xFFFFFFFF:08X}")

    # Set descriptor heaps
    # VTable index 28
    heaps = (ctypes.c_void_p * 1)(g_srv_uav_heap.value)
    set_heaps = com_method(g_compute_command_list, 28, None,
                          (ctypes.c_void_p, wintypes.UINT, ctypes.POINTER(ctypes.c_void_p)))
    set_heaps(g_compute_command_list, 1, heaps)

    # Set compute root signature
    # VTable index 29
    set_compute_rs = com_method(g_compute_command_list, 29, None, (ctypes.c_void_p, ctypes.c_void_p))
    set_compute_rs(g_compute_command_list, g_compute_root_signature)

    # Get GPU descriptor handle
    # VTable index 10
    srv_uav_heap_ptr = ctypes.c_void_p(g_srv_uav_heap.value)
    get_gpu_handle = com_method(srv_uav_heap_ptr, 10, ctypes.c_void_p,
                               (ctypes.c_void_p, ctypes.POINTER(D3D12_GPU_DESCRIPTOR_HANDLE)))
    gpu_handle = D3D12_GPU_DESCRIPTOR_HANDLE()
    get_gpu_handle(srv_uav_heap_ptr, ctypes.byref(gpu_handle))

    # Set compute root descriptor tables
    # VTable index 31
    set_compute_table = com_method(g_compute_command_list, 31, None,
                                  (ctypes.c_void_p, wintypes.UINT, D3D12_GPU_DESCRIPTOR_HANDLE))
    
    # Table 0: UAVs (slots 0-1)
    set_compute_table(g_compute_command_list, 0, gpu_handle)
    
    # Table 1: CBV (slot 4)
    cbv_handle = D3D12_GPU_DESCRIPTOR_HANDLE()
    cbv_handle.ptr = gpu_handle.ptr + g_srv_uav_descriptor_size * 4
    set_compute_table(g_compute_command_list, 1, cbv_handle)

    # Dispatch compute shader
    # VTable index 14
    dispatch = com_method(g_compute_command_list, 14, None,
                         (ctypes.c_void_p, wintypes.UINT, wintypes.UINT, wintypes.UINT))
    dispatch(g_compute_command_list, (VERTEX_COUNT + 63) // 64, 1, 1)

    # Resource barriers: UAV -> SRV
    barriers = (D3D12_RESOURCE_BARRIER * 2)()
    
    barriers[0].Type = D3D12_RESOURCE_BARRIER_TYPE_TRANSITION
    barriers[0].Flags = D3D12_RESOURCE_BARRIER_FLAG_NONE
    barriers[0].u.Transition.pResource = g_position_buffer.value
    barriers[0].u.Transition.Subresource = D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES
    barriers[0].u.Transition.StateBefore = D3D12_RESOURCE_STATE_UNORDERED_ACCESS
    barriers[0].u.Transition.StateAfter = D3D12_RESOURCE_STATE_NON_PIXEL_SHADER_RESOURCE

    barriers[1].Type = D3D12_RESOURCE_BARRIER_TYPE_TRANSITION
    barriers[1].Flags = D3D12_RESOURCE_BARRIER_FLAG_NONE
    barriers[1].u.Transition.pResource = g_color_buffer.value
    barriers[1].u.Transition.Subresource = D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES
    barriers[1].u.Transition.StateBefore = D3D12_RESOURCE_STATE_UNORDERED_ACCESS
    barriers[1].u.Transition.StateAfter = D3D12_RESOURCE_STATE_NON_PIXEL_SHADER_RESOURCE

    # VTable index 26
    res_barrier = com_method(g_compute_command_list, 26, None,
                            (ctypes.c_void_p, wintypes.UINT, ctypes.POINTER(D3D12_RESOURCE_BARRIER)))
    res_barrier(g_compute_command_list, 2, barriers)

    # Close compute command list
    # VTable index 9
    close_cl = com_method(g_compute_command_list, 9, wintypes.HRESULT, (ctypes.c_void_p,))
    hr = close_cl(g_compute_command_list)
    if hr != 0:
        raise RuntimeError(f"ComputeCommandList::Close failed: 0x{hr & 0xFFFFFFFF:08X}")

    # Execute compute command list
    # VTable index 10
    cmd_lists = (ctypes.c_void_p * 1)(g_compute_command_list.value)
    exec_cl = com_method(g_command_queue, 10, None, (ctypes.c_void_p, wintypes.UINT, ctypes.POINTER(ctypes.c_void_p)))
    exec_cl(g_command_queue, 1, cmd_lists)

    # ===== Graphics Pass =====
    
    # Reset graphics command allocator
    # VTable index 8
    reset_graphics_ca = com_method(g_command_allocator, 8, wintypes.HRESULT, (ctypes.c_void_p,))
    hr = reset_graphics_ca(g_command_allocator)
    if hr != 0:
        raise RuntimeError(f"GraphicsCommandAllocator::Reset failed: 0x{hr & 0xFFFFFFFF:08X}")

    # Reset graphics command list
    # VTable index 10
    reset_graphics_cl = com_method(g_command_list, 10, wintypes.HRESULT, (ctypes.c_void_p, ctypes.c_void_p, ctypes.c_void_p))
    hr = reset_graphics_cl(g_command_list, g_command_allocator, g_graphics_pipeline_state)
    if hr != 0:
        raise RuntimeError(f"GraphicsCommandList::Reset failed: 0x{hr & 0xFFFFFFFF:08X}")

    # Set descriptor heaps
    set_heaps_graphics = com_method(g_command_list, 28, None,
                                   (ctypes.c_void_p, wintypes.UINT, ctypes.POINTER(ctypes.c_void_p)))
    set_heaps_graphics(g_command_list, 1, heaps)

    # Set graphics root signature
    # VTable index 30
    set_graphics_rs = com_method(g_command_list, 30, None, (ctypes.c_void_p, ctypes.c_void_p))
    set_graphics_rs(g_command_list, g_graphics_root_signature)

    # Set graphics root descriptor tables
    # VTable index 32
    set_graphics_table = com_method(g_command_list, 32, None,
                                   (ctypes.c_void_p, wintypes.UINT, D3D12_GPU_DESCRIPTOR_HANDLE))
    
    # Table 0: SRVs (slots 2-3)
    srv_handle = D3D12_GPU_DESCRIPTOR_HANDLE()
    srv_handle.ptr = gpu_handle.ptr + g_srv_uav_descriptor_size * 2
    set_graphics_table(g_command_list, 0, srv_handle)
    
    # Table 1: CBV (slot 4)
    set_graphics_table(g_command_list, 1, cbv_handle)

    # Set viewport
    viewport = D3D12_VIEWPORT(0.0, 0.0, float(g_width), float(g_height), 0.0, 1.0)
    # VTable index 21
    set_vp = com_method(g_command_list, 21, None, (ctypes.c_void_p, wintypes.UINT, ctypes.POINTER(D3D12_VIEWPORT)))
    set_vp(g_command_list, 1, ctypes.byref(viewport))

    # Set scissor rect
    scissor = D3D12_RECT(0, 0, g_width, g_height)
    # VTable index 22
    set_sr = com_method(g_command_list, 22, None, (ctypes.c_void_p, wintypes.UINT, ctypes.POINTER(D3D12_RECT)))
    set_sr(g_command_list, 1, ctypes.byref(scissor))

    # Transition render target to RENDER_TARGET state
    rt_barrier = D3D12_RESOURCE_BARRIER()
    rt_barrier.Type = D3D12_RESOURCE_BARRIER_TYPE_TRANSITION
    rt_barrier.Flags = D3D12_RESOURCE_BARRIER_FLAG_NONE
    rt_barrier.u.Transition.pResource = g_render_targets[g_frame_index].value
    rt_barrier.u.Transition.Subresource = D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES
    rt_barrier.u.Transition.StateBefore = D3D12_RESOURCE_STATE_PRESENT
    rt_barrier.u.Transition.StateAfter = D3D12_RESOURCE_STATE_RENDER_TARGET

    res_barrier_graphics = com_method(g_command_list, 26, None,
                                     (ctypes.c_void_p, wintypes.UINT, ctypes.POINTER(D3D12_RESOURCE_BARRIER)))
    res_barrier_graphics(g_command_list, 1, ctypes.byref(rt_barrier))

    # Get RTV handle
    heap_ptr = ctypes.c_void_p(g_rtv_heap.value)
    get_cpu_handle = com_method(heap_ptr, 9, ctypes.c_void_p,
                               (ctypes.c_void_p, ctypes.POINTER(D3D12_CPU_DESCRIPTOR_HANDLE)))
    rtv_handle = D3D12_CPU_DESCRIPTOR_HANDLE()
    get_cpu_handle(heap_ptr, ctypes.byref(rtv_handle))
    rtv_handle.ptr += g_frame_index * g_rtv_descriptor_size

    # Set render target
    # VTable index 46
    set_rt = com_method(g_command_list, 46, None,
                       (ctypes.c_void_p, wintypes.UINT, ctypes.POINTER(D3D12_CPU_DESCRIPTOR_HANDLE),
                        wintypes.BOOL, ctypes.c_void_p))
    set_rt(g_command_list, 1, ctypes.byref(rtv_handle), False, None)

    # Clear render target (dark blue background)
    clear_color = (ctypes.c_float * 4)(0.05, 0.05, 0.1, 1.0)
    # VTable index 48
    clear_rtv = com_method(g_command_list, 48, None,
                          (ctypes.c_void_p, D3D12_CPU_DESCRIPTOR_HANDLE, ctypes.POINTER(ctypes.c_float), wintypes.UINT, ctypes.c_void_p))
    clear_rtv(g_command_list, rtv_handle, clear_color, 0, None)

    # Set primitive topology
    # VTable index 20
    set_topo = com_method(g_command_list, 20, None, (ctypes.c_void_p, wintypes.UINT))
    set_topo(g_command_list, D3D_PRIMITIVE_TOPOLOGY_LINESTRIP)

    # Draw
    # VTable index 12
    draw = com_method(g_command_list, 12, None, (ctypes.c_void_p, wintypes.UINT, wintypes.UINT, wintypes.UINT, wintypes.UINT))
    draw(g_command_list, VERTEX_COUNT, 1, 0, 0)

    # Transition render target back to PRESENT state
    rt_barrier.u.Transition.StateBefore = D3D12_RESOURCE_STATE_RENDER_TARGET
    rt_barrier.u.Transition.StateAfter = D3D12_RESOURCE_STATE_PRESENT
    res_barrier_graphics(g_command_list, 1, ctypes.byref(rt_barrier))

    # Resource barriers: SRV -> UAV (for next frame)
    barriers[0].u.Transition.StateBefore = D3D12_RESOURCE_STATE_NON_PIXEL_SHADER_RESOURCE
    barriers[0].u.Transition.StateAfter = D3D12_RESOURCE_STATE_UNORDERED_ACCESS
    barriers[1].u.Transition.StateBefore = D3D12_RESOURCE_STATE_NON_PIXEL_SHADER_RESOURCE
    barriers[1].u.Transition.StateAfter = D3D12_RESOURCE_STATE_UNORDERED_ACCESS
    res_barrier_graphics(g_command_list, 2, barriers)

    # Close graphics command list
    close_graphics_cl = com_method(g_command_list, 9, wintypes.HRESULT, (ctypes.c_void_p,))
    hr = close_graphics_cl(g_command_list)
    if hr != 0:
        raise RuntimeError(f"GraphicsCommandList::Close failed: 0x{hr & 0xFFFFFFFF:08X}")

    # Execute graphics command list
    graphics_cmd_lists = (ctypes.c_void_p * 1)(g_command_list.value)
    exec_cl(g_command_queue, 1, graphics_cmd_lists)

    # Present
    # VTable index 8
    present = com_method(g_swap_chain, 8, wintypes.HRESULT, (ctypes.c_void_p, wintypes.UINT, wintypes.UINT))
    hr = present(g_swap_chain, 1, 0)
    if hr != 0:
        raise RuntimeError(f"Present failed: 0x{hr & 0xFFFFFFFF:08X}")

    wait_for_previous_frame()

def cleanup_d3d():
    debug_print("=== cleanup_d3d() ===")
    
    # Wait for GPU to finish
    try:
        wait_for_previous_frame()
    except:
        pass

    if g_fence_event:
        kernel32.CloseHandle(g_fence_event)

    com_release(g_fence)
    com_release(g_constant_buffer)
    com_release(g_color_buffer)
    com_release(g_position_buffer)
    com_release(g_compute_pipeline_state)
    com_release(g_graphics_pipeline_state)
    com_release(g_compute_root_signature)
    com_release(g_graphics_root_signature)
    com_release(g_compute_command_list)
    com_release(g_command_list)
    com_release(g_compute_command_allocator)
    com_release(g_command_allocator)
    com_release(g_srv_uav_heap)
    com_release(g_rtv_heap)
    for rt in g_render_targets:
        com_release(rt)
    com_release(g_swap_chain)
    com_release(g_command_queue)
    com_release(g_device)
    com_release(g_factory)

    debug_print("=== cleanup_d3d() COMPLETE ===")

# ============================================================
# Window procedure
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

    debug_print("=== main() ===")

    ole32.CoInitialize(None)

    hInstance = kernel32.GetModuleHandleW(None)
    class_name = "PyDx12Harmonograph"

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
        "DirectX12 Compute Shader Harmonograph (ctypes only)",
        WS_OVERLAPPEDWINDOW,
        CW_USEDEFAULT, CW_USEDEFAULT,
        WIDTH, HEIGHT,
        None, None, hInstance, None
    )
    if not g_hwnd:
        raise winerr()

    user32.ShowWindow(g_hwnd, SW_SHOW)

    init_d3d()

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
            render()
            kernel32.Sleep(1)

    cleanup_d3d()
    ole32.CoUninitialize()

    debug_print("=== main() COMPLETE ===")

if __name__ == "__main__":
    main()
