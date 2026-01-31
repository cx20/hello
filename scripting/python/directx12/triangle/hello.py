"""
DirectX12 Triangle (ctypes only, no external libraries)
Python で外部ライブラリを使わずに DirectX12 で三角形を描画するサンプル
"""
import ctypes
from ctypes import wintypes

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
DXGI_FORMAT_R8G8B8A8_UNORM     = 28
DXGI_FORMAT_R32G32B32_FLOAT    = 6
DXGI_FORMAT_R32G32B32A32_FLOAT = 2
DXGI_FORMAT_D32_FLOAT          = 40

# DXGI_SWAP_EFFECT
DXGI_SWAP_EFFECT_FLIP_DISCARD = 4

# D3D12 constants
D3D12_COMMAND_LIST_TYPE_DIRECT = 0
D3D12_COMMAND_QUEUE_FLAG_NONE  = 0
D3D12_FENCE_FLAG_NONE          = 0

# D3D12_DESCRIPTOR_HEAP_TYPE
D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV = 0
D3D12_DESCRIPTOR_HEAP_TYPE_SAMPLER     = 1
D3D12_DESCRIPTOR_HEAP_TYPE_RTV         = 2  # Was incorrectly 0!
D3D12_DESCRIPTOR_HEAP_TYPE_DSV         = 3
D3D12_DESCRIPTOR_HEAP_FLAG_NONE = 0

D3D12_RESOURCE_STATE_PRESENT        = 0
D3D12_RESOURCE_STATE_RENDER_TARGET  = 4

D3D12_HEAP_TYPE_UPLOAD  = 2
D3D12_HEAP_TYPE_DEFAULT = 1

D3D12_RESOURCE_DIMENSION_BUFFER = 1

D3D12_TEXTURE_LAYOUT_ROW_MAJOR = 1

D3D12_RESOURCE_FLAG_NONE = 0

D3D12_ROOT_SIGNATURE_FLAG_ALLOW_INPUT_ASSEMBLER_INPUT_LAYOUT = 0x1

D3D12_PRIMITIVE_TOPOLOGY_TYPE_TRIANGLE = 3
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

FRAME_COUNT = 2

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
IID_IDXGIInfoQueue       = guid_from_str("{D67441C7-672A-476f-9E82-CD55B44949CE}")

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

class DXGI_MODE_DESC(ctypes.Structure):
    _fields_ = [
        ("Width", wintypes.UINT),
        ("Height", wintypes.UINT),
        ("RefreshRate", DXGI_RATIONAL),
        ("Format", wintypes.UINT),
        ("ScanlineOrdering", wintypes.UINT),
        ("Scaling", wintypes.UINT),
    ]

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

class D3D12_VERTEX_BUFFER_VIEW(ctypes.Structure):
    _fields_ = [
        ("BufferLocation", ctypes.c_uint64),
        ("SizeInBytes", wintypes.UINT),
        ("StrideInBytes", wintypes.UINT),
    ]

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

# Root signature (serialized)
class D3D12_ROOT_SIGNATURE_DESC(ctypes.Structure):
    _fields_ = [
        ("NumParameters", wintypes.UINT),
        ("pParameters", ctypes.c_void_p),
        ("NumStaticSamplers", wintypes.UINT),
        ("pStaticSamplers", ctypes.c_void_p),
        ("Flags", wintypes.UINT),
    ]

# Input element
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

class D3D12_SHADER_BYTECODE(ctypes.Structure):
    _fields_ = [
        ("pShaderBytecode", ctypes.c_void_p),
        ("BytecodeLength", ctypes.c_size_t),
    ]

class DXGI_SAMPLE_DESC(ctypes.Structure):
    _fields_ = [("Count", wintypes.UINT), ("Quality", wintypes.UINT)]

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
    ctypes.c_void_p,       # pAdapter
    wintypes.UINT,         # MinimumFeatureLevel
    ctypes.POINTER(GUID),  # riid
    ctypes.POINTER(ctypes.c_void_p),  # ppDevice
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
    # Get the actual pointer value
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
    """Output debug message to DebugView"""
    kernel32.OutputDebugStringW(f"[PyDX12] {msg}\n")

def enable_debug_layer():
    """Enable D3D12 debug layer - must be called before device creation"""
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
g_render_targets = [ctypes.c_void_p() for _ in range(FRAME_COUNT)]
g_command_allocators = [ctypes.c_void_p() for _ in range(FRAME_COUNT)]
g_command_list   = ctypes.c_void_p()
g_root_signature = ctypes.c_void_p()
g_pipeline_state = ctypes.c_void_p()
g_vertex_buffer  = ctypes.c_void_p()
g_fence          = ctypes.c_void_p()
g_fence_event    = None
g_fence_values   = [0] * FRAME_COUNT
g_frame_index    = 0
g_rtv_descriptor_size = 0
g_vertex_buffer_view = D3D12_VERTEX_BUFFER_VIEW()

g_width  = 640
g_height = 480

# ============================================================
# HLSL source (SM 5.0 for D3D12)
# ============================================================
HLSL_SRC = r"""
struct VS_OUTPUT
{
    float4 position : SV_POSITION;
    float4 color : COLOR0;
};

VS_OUTPUT VS(float4 position : POSITION, float4 color : COLOR)
{
    VS_OUTPUT output = (VS_OUTPUT)0;
    output.position = position;
    output.color = color;
    return output;
}

float4 PS(VS_OUTPUT input) : SV_Target
{
    return input.color;
}
"""

def compile_hlsl(entry: str, target: str) -> ctypes.c_void_p:
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
    global g_rtv_heap, g_render_targets, g_command_allocators, g_command_list
    global g_root_signature, g_pipeline_state, g_vertex_buffer
    global g_fence, g_fence_event, g_fence_values, g_frame_index
    global g_rtv_descriptor_size, g_vertex_buffer_view
    global g_width, g_height

    debug_print("=== Initializing D3D12 ===")

    # Enable debug layer BEFORE creating device
    enable_debug_layer()

    rc = RECT()
    if not user32.GetClientRect(g_hwnd, ctypes.byref(rc)):
        raise winerr()
    g_width  = rc.right - rc.left
    g_height = rc.bottom - rc.top

    # --- Create DXGI Factory ---
    hr = CreateDXGIFactory1(ctypes.byref(IID_IDXGIFactory4), ctypes.byref(g_factory))
    if hr != 0:
        raise RuntimeError(f"CreateDXGIFactory1 failed: 0x{hr & 0xFFFFFFFF:08X}")
    debug_print(f"DXGI Factory created: 0x{g_factory.value:016X}")

    # --- Create Device ---
    hr = D3D12CreateDevice(None, D3D_FEATURE_LEVEL_12_0, ctypes.byref(IID_ID3D12Device), ctypes.byref(g_device))
    if hr != 0:
        raise RuntimeError(f"D3D12CreateDevice failed: 0x{hr & 0xFFFFFFFF:08X}")
    debug_print(f"D3D12 Device created: 0x{g_device.value:016X}")

    # --- Create Command Queue ---
    # ID3D12Device::CreateCommandQueue (index 8)
    queue_desc = D3D12_COMMAND_QUEUE_DESC()
    queue_desc.Type = D3D12_COMMAND_LIST_TYPE_DIRECT
    queue_desc.Flags = D3D12_COMMAND_QUEUE_FLAG_NONE

    create_cq = com_method(g_device, 8, wintypes.HRESULT,
                           (ctypes.c_void_p, ctypes.POINTER(D3D12_COMMAND_QUEUE_DESC),
                            ctypes.POINTER(GUID), ctypes.POINTER(ctypes.c_void_p)))
    hr = create_cq(g_device, ctypes.byref(queue_desc), ctypes.byref(IID_ID3D12CommandQueue), ctypes.byref(g_command_queue))
    if hr != 0:
        raise RuntimeError(f"CreateCommandQueue failed: 0x{hr & 0xFFFFFFFF:08X}")
    debug_print(f"Command Queue created: 0x{g_command_queue.value:016X}")

    # --- Create Swap Chain ---
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

    # IDXGIFactory2::CreateSwapChainForHwnd (index 15)
    create_sc = com_method(g_factory, 15, wintypes.HRESULT,
                           (ctypes.c_void_p, ctypes.c_void_p, wintypes.HWND,
                            ctypes.POINTER(DXGI_SWAP_CHAIN_DESC1), ctypes.c_void_p, ctypes.c_void_p,
                            ctypes.POINTER(ctypes.c_void_p)))
    swap_temp = ctypes.c_void_p()
    debug_print(f"Creating swap chain for HWND: 0x{g_hwnd:08X}, Size: {g_width}x{g_height}")
    hr = create_sc(g_factory, g_command_queue, g_hwnd, ctypes.byref(sc_desc), None, None, ctypes.byref(swap_temp))
    if hr != 0:
        raise RuntimeError(f"CreateSwapChainForHwnd failed: 0x{hr & 0xFFFFFFFF:08X}")
    debug_print(f"Swap chain (temp) created: 0x{swap_temp.value:016X}")

    # Query IDXGISwapChain3
    qi = com_method(swap_temp, 0, wintypes.HRESULT, (ctypes.c_void_p, ctypes.POINTER(GUID), ctypes.POINTER(ctypes.c_void_p)))
    hr = qi(swap_temp, ctypes.byref(IID_IDXGISwapChain3), ctypes.byref(g_swap_chain))
    com_release(swap_temp)
    if hr != 0:
        raise RuntimeError(f"QueryInterface IDXGISwapChain3 failed: 0x{hr & 0xFFFFFFFF:08X}")
    debug_print(f"IDXGISwapChain3 obtained: 0x{g_swap_chain.value:016X}")

    # Get current back buffer index
    # IDXGISwapChain3::GetCurrentBackBufferIndex (index 36)
    # VTable: IUnknown(0-2) + IDXGIObject(3-6) + IDXGIDeviceSubObject(7) + 
    #         IDXGISwapChain(8-17) + IDXGISwapChain1(18-28) + IDXGISwapChain2(29-35) + IDXGISwapChain3(36+)
    get_idx = com_method(g_swap_chain, 36, wintypes.UINT, (ctypes.c_void_p,))
    g_frame_index = get_idx(g_swap_chain)
    debug_print(f"Initial frame index: {g_frame_index}")

    # --- Create RTV Descriptor Heap ---
    rtv_heap_desc = D3D12_DESCRIPTOR_HEAP_DESC()
    rtv_heap_desc.Type = D3D12_DESCRIPTOR_HEAP_TYPE_RTV
    rtv_heap_desc.NumDescriptors = FRAME_COUNT
    rtv_heap_desc.Flags = D3D12_DESCRIPTOR_HEAP_FLAG_NONE
    rtv_heap_desc.NodeMask = 0

    # ID3D12Device::CreateDescriptorHeap (index 14)
    create_heap = com_method(g_device, 14, wintypes.HRESULT,
                             (ctypes.c_void_p, ctypes.POINTER(D3D12_DESCRIPTOR_HEAP_DESC),
                              ctypes.POINTER(GUID), ctypes.POINTER(ctypes.c_void_p)))
    IID_ID3D12DescriptorHeap = guid_from_str("{8efb471d-616c-4f49-90f7-127bb763fa51}")
    hr = create_heap(g_device, ctypes.byref(rtv_heap_desc), ctypes.byref(IID_ID3D12DescriptorHeap), ctypes.byref(g_rtv_heap))
    if hr != 0:
        raise RuntimeError(f"CreateDescriptorHeap failed: 0x{hr & 0xFFFFFFFF:08X}")
    debug_print(f"RTV Descriptor Heap created: 0x{g_rtv_heap.value:016X}")

    # ID3D12Device::GetDescriptorHandleIncrementSize (index 15)
    get_inc_size = com_method(g_device, 15, wintypes.UINT, (ctypes.c_void_p, wintypes.UINT))
    g_rtv_descriptor_size = get_inc_size(g_device, D3D12_DESCRIPTOR_HEAP_TYPE_RTV)
    debug_print(f"RTV descriptor size: {g_rtv_descriptor_size}")

    # ID3D12DescriptorHeap::GetCPUDescriptorHandleForHeapStart (index 9)
    # On Windows, this method takes an output parameter: (this, D3D12_CPU_DESCRIPTOR_HANDLE* RetVal)
    # Returns the same pointer for chaining
    debug_print(f"Calling GetCPUDescriptorHandleForHeapStart on heap: 0x{g_rtv_heap.value:016X}")
    heap_ptr = ctypes.c_void_p(g_rtv_heap.value)  # Explicit c_void_p wrapper
    get_cpu_handle = com_method(heap_ptr, 9, ctypes.c_void_p,
                               (ctypes.c_void_p, ctypes.POINTER(D3D12_CPU_DESCRIPTOR_HANDLE)))
    rtv_handle = D3D12_CPU_DESCRIPTOR_HANDLE()
    get_cpu_handle(heap_ptr, ctypes.byref(rtv_handle))
    debug_print(f"RTV heap CPU handle: 0x{rtv_handle.ptr:016X}")

    # Create RTVs for each frame
    for i in range(FRAME_COUNT):
        # IDXGISwapChain::GetBuffer (index 9)
        get_buffer = com_method(g_swap_chain, 9, wintypes.HRESULT,
                               (ctypes.c_void_p, wintypes.UINT, ctypes.POINTER(GUID), ctypes.POINTER(ctypes.c_void_p)))
        hr = get_buffer(g_swap_chain, i, ctypes.byref(IID_ID3D12Resource), ctypes.byref(g_render_targets[i]))
        if hr != 0:
            raise RuntimeError(f"GetBuffer({i}) failed: 0x{hr & 0xFFFFFFFF:08X}")

        # ID3D12Device::CreateRenderTargetView (index 20)
        create_rtv = com_method(g_device, 20, None,
                               (ctypes.c_void_p, ctypes.c_void_p, ctypes.c_void_p, D3D12_CPU_DESCRIPTOR_HANDLE))
        handle_copy = D3D12_CPU_DESCRIPTOR_HANDLE(rtv_handle.ptr + i * g_rtv_descriptor_size)
        create_rtv(g_device, g_render_targets[i], None, handle_copy)

    # --- Create Command Allocators ---
    IID_ID3D12CommandAllocator = guid_from_str("{6102dee4-af59-4b09-b999-b44d73f09b24}")
    for i in range(FRAME_COUNT):
        # ID3D12Device::CreateCommandAllocator (index 9)
        create_ca = com_method(g_device, 9, wintypes.HRESULT,
                              (ctypes.c_void_p, wintypes.UINT, ctypes.POINTER(GUID), ctypes.POINTER(ctypes.c_void_p)))
        hr = create_ca(g_device, D3D12_COMMAND_LIST_TYPE_DIRECT, ctypes.byref(IID_ID3D12CommandAllocator), ctypes.byref(g_command_allocators[i]))
        if hr != 0:
            raise RuntimeError(f"CreateCommandAllocator({i}) failed: 0x{hr & 0xFFFFFFFF:08X}")

    # --- Create Root Signature ---
    rs_desc = D3D12_ROOT_SIGNATURE_DESC()
    rs_desc.NumParameters = 0
    rs_desc.pParameters = None
    rs_desc.NumStaticSamplers = 0
    rs_desc.pStaticSamplers = None
    rs_desc.Flags = D3D12_ROOT_SIGNATURE_FLAG_ALLOW_INPUT_ASSEMBLER_INPUT_LAYOUT

    rs_blob = ctypes.c_void_p()
    err_blob = ctypes.c_void_p()
    hr = D3D12SerializeRootSignature(ctypes.byref(rs_desc), D3D_ROOT_SIGNATURE_VERSION_1, ctypes.byref(rs_blob), ctypes.byref(err_blob))
    if hr != 0:
        msg = "D3D12SerializeRootSignature failed"
        if err_blob:
            get_ptr = com_method(err_blob, 3, ctypes.c_void_p, (ctypes.c_void_p,))
            p = get_ptr(err_blob)
            if p:
                msg = ctypes.string_at(p).decode("utf-8", "replace")
            com_release(err_blob)
        raise RuntimeError(msg)
    if err_blob:
        com_release(err_blob)

    # ID3D12Device::CreateRootSignature (index 16)
    create_rs = com_method(g_device, 16, wintypes.HRESULT,
                          (ctypes.c_void_p, wintypes.UINT, ctypes.c_void_p, ctypes.c_size_t,
                           ctypes.POINTER(GUID), ctypes.POINTER(ctypes.c_void_p)))
    debug_print(f"Root signature blob size: {blob_size(rs_blob)}")
    hr = create_rs(g_device, 0, blob_ptr(rs_blob), blob_size(rs_blob), ctypes.byref(IID_ID3D12RootSignature), ctypes.byref(g_root_signature))
    com_release(rs_blob)
    if hr != 0:
        raise RuntimeError(f"CreateRootSignature failed: 0x{hr & 0xFFFFFFFF:08X}")

    # --- Compile Shaders ---
    vs_blob = compile_hlsl("VS", "vs_5_0")
    ps_blob = compile_hlsl("PS", "ps_5_0")

    # --- Create Pipeline State Object ---
    POSITION = b"POSITION"
    COLOR = b"COLOR"
    input_layout = (D3D12_INPUT_ELEMENT_DESC * 2)(
        D3D12_INPUT_ELEMENT_DESC(POSITION, 0, DXGI_FORMAT_R32G32B32_FLOAT, 0, 0, D3D12_INPUT_CLASSIFICATION_PER_VERTEX_DATA, 0),
        D3D12_INPUT_ELEMENT_DESC(COLOR, 0, DXGI_FORMAT_R32G32B32A32_FLOAT, 0, 12, D3D12_INPUT_CLASSIFICATION_PER_VERTEX_DATA, 0),
    )

    pso_desc = D3D12_GRAPHICS_PIPELINE_STATE_DESC()
    ctypes.memset(ctypes.byref(pso_desc), 0, ctypes.sizeof(pso_desc))

    pso_desc.pRootSignature = g_root_signature.value
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

    # Depth stencil
    pso_desc.DepthStencilState.DepthEnable = False
    pso_desc.DepthStencilState.StencilEnable = False

    # Input layout
    pso_desc.InputLayout.pInputElementDescs = input_layout
    pso_desc.InputLayout.NumElements = 2

    pso_desc.PrimitiveTopologyType = D3D12_PRIMITIVE_TOPOLOGY_TYPE_TRIANGLE
    pso_desc.NumRenderTargets = 1
    pso_desc.RTVFormats[0] = DXGI_FORMAT_R8G8B8A8_UNORM
    pso_desc.SampleDesc.Count = 1
    pso_desc.SampleDesc.Quality = 0

    # ID3D12Device::CreateGraphicsPipelineState (index 10)
    IID_ID3D12PipelineState = guid_from_str("{765a30f3-f624-4c6f-a828-ace948622445}")
    create_pso = com_method(g_device, 10, wintypes.HRESULT,
                           (ctypes.c_void_p, ctypes.POINTER(D3D12_GRAPHICS_PIPELINE_STATE_DESC),
                            ctypes.POINTER(GUID), ctypes.POINTER(ctypes.c_void_p)))
    hr = create_pso(g_device, ctypes.byref(pso_desc), ctypes.byref(IID_ID3D12PipelineState), ctypes.byref(g_pipeline_state))
    if hr != 0:
        raise RuntimeError(f"CreateGraphicsPipelineState failed: 0x{hr & 0xFFFFFFFF:08X}")

    com_release(vs_blob)
    com_release(ps_blob)

    # --- Create Command List ---
    IID_ID3D12GraphicsCommandList = guid_from_str("{5b160d0f-ac1b-4185-8ba8-b3ae42a5a455}")
    # ID3D12Device::CreateCommandList (index 12)
    create_cl = com_method(g_device, 12, wintypes.HRESULT,
                          (ctypes.c_void_p, wintypes.UINT, wintypes.UINT, ctypes.c_void_p, ctypes.c_void_p,
                           ctypes.POINTER(GUID), ctypes.POINTER(ctypes.c_void_p)))
    hr = create_cl(g_device, 0, D3D12_COMMAND_LIST_TYPE_DIRECT, g_command_allocators[g_frame_index], g_pipeline_state,
                   ctypes.byref(IID_ID3D12GraphicsCommandList), ctypes.byref(g_command_list))
    if hr != 0:
        raise RuntimeError(f"CreateCommandList failed: 0x{hr & 0xFFFFFFFF:08X}")

    # Close command list (will reset later)
    # ID3D12GraphicsCommandList::Close (index 9)
    close_cl = com_method(g_command_list, 9, wintypes.HRESULT, (ctypes.c_void_p,))
    close_cl(g_command_list)

    # --- Create Vertex Buffer ---
    class VERTEX(ctypes.Structure):
        _fields_ = [("x", ctypes.c_float), ("y", ctypes.c_float), ("z", ctypes.c_float),
                    ("r", ctypes.c_float), ("g", ctypes.c_float), ("b", ctypes.c_float), ("a", ctypes.c_float)]

    verts = (VERTEX * 3)(
        VERTEX( 0.0,  0.5, 0.5, 1.0, 0.0, 0.0, 1.0),  # Red top
        VERTEX( 0.5, -0.5, 0.5, 0.0, 1.0, 0.0, 1.0),  # Green right
        VERTEX(-0.5, -0.5, 0.5, 0.0, 0.0, 1.0, 1.0),  # Blue left
    )
    vertex_buffer_size = ctypes.sizeof(VERTEX) * 3

    # Create upload heap buffer
    heap_props = D3D12_HEAP_PROPERTIES()
    heap_props.Type = D3D12_HEAP_TYPE_UPLOAD
    heap_props.CPUPageProperty = 0
    heap_props.MemoryPoolPreference = 0
    heap_props.CreationNodeMask = 1
    heap_props.VisibleNodeMask = 1

    res_desc = D3D12_RESOURCE_DESC()
    res_desc.Dimension = D3D12_RESOURCE_DIMENSION_BUFFER
    res_desc.Alignment = 0
    res_desc.Width = vertex_buffer_size
    res_desc.Height = 1
    res_desc.DepthOrArraySize = 1
    res_desc.MipLevels = 1
    res_desc.Format = 0  # DXGI_FORMAT_UNKNOWN
    res_desc.SampleDesc.Count = 1
    res_desc.SampleDesc.Quality = 0
    res_desc.Layout = D3D12_TEXTURE_LAYOUT_ROW_MAJOR
    res_desc.Flags = D3D12_RESOURCE_FLAG_NONE

    # ID3D12Device::CreateCommittedResource (index 27)
    create_res = com_method(g_device, 27, wintypes.HRESULT,
                           (ctypes.c_void_p, ctypes.POINTER(D3D12_HEAP_PROPERTIES), wintypes.UINT,
                            ctypes.POINTER(D3D12_RESOURCE_DESC), wintypes.UINT, ctypes.c_void_p,
                            ctypes.POINTER(GUID), ctypes.POINTER(ctypes.c_void_p)))
    hr = create_res(g_device, ctypes.byref(heap_props), 0, ctypes.byref(res_desc),
                    0,  # D3D12_RESOURCE_STATE_GENERIC_READ = 0x1 | 0x2 | ... But for upload buffer, use state 0
                    None, ctypes.byref(IID_ID3D12Resource), ctypes.byref(g_vertex_buffer))
    if hr != 0:
        raise RuntimeError(f"CreateCommittedResource (VB) failed: 0x{hr & 0xFFFFFFFF:08X}")

    # Map and copy vertex data
    # ID3D12Resource::Map (index 8)
    map_res = com_method(g_vertex_buffer, 8, wintypes.HRESULT,
                        (ctypes.c_void_p, wintypes.UINT, ctypes.POINTER(D3D12_RANGE), ctypes.POINTER(ctypes.c_void_p)))
    data_ptr = ctypes.c_void_p()
    read_range = D3D12_RANGE(0, 0)
    hr = map_res(g_vertex_buffer, 0, ctypes.byref(read_range), ctypes.byref(data_ptr))
    if hr != 0:
        raise RuntimeError(f"Map (VB) failed: 0x{hr & 0xFFFFFFFF:08X}")

    ctypes.memmove(data_ptr.value, ctypes.addressof(verts), vertex_buffer_size)

    # ID3D12Resource::Unmap (index 9)
    unmap_res = com_method(g_vertex_buffer, 9, None, (ctypes.c_void_p, wintypes.UINT, ctypes.POINTER(D3D12_RANGE)))
    unmap_res(g_vertex_buffer, 0, None)

    # ID3D12Resource::GetGPUVirtualAddress (index 11)
    get_gpu_addr = com_method(g_vertex_buffer, 11, ctypes.c_uint64, (ctypes.c_void_p,))
    gpu_addr = get_gpu_addr(g_vertex_buffer)
    debug_print(f"Vertex buffer GPU address: 0x{gpu_addr:016X}")

    g_vertex_buffer_view.BufferLocation = gpu_addr
    g_vertex_buffer_view.SizeInBytes = vertex_buffer_size
    g_vertex_buffer_view.StrideInBytes = ctypes.sizeof(VERTEX)

    # --- Create Fence ---
    IID_ID3D12Fence = guid_from_str("{0a753dcf-c4d8-4b91-adf6-be5a60d95a76}")
    # ID3D12Device::CreateFence (index 36)
    # VTable: IUnknown(0-2) + ID3D12Object(3-6) + ID3D12Device methods
    # 7:GetNodeCount, 8:CreateCommandQueue, ..., 27:CreateCommittedResource,
    # 28:CreateHeap, 29:CreatePlacedResource, 30:CreateReservedResource,
    # 31:CreateSharedHandle, 32:OpenSharedHandle, 33:OpenSharedHandleByName,
    # 34:MakeResident, 35:Evict, 36:CreateFence
    create_fence = com_method(g_device, 36, wintypes.HRESULT,
                             (ctypes.c_void_p, ctypes.c_uint64, wintypes.UINT,
                              ctypes.POINTER(GUID), ctypes.POINTER(ctypes.c_void_p)))
    hr = create_fence(g_device, 0, D3D12_FENCE_FLAG_NONE, ctypes.byref(IID_ID3D12Fence), ctypes.byref(g_fence))
    if hr != 0:
        raise RuntimeError(f"CreateFence failed: 0x{hr & 0xFFFFFFFF:08X}")

    g_fence_values[g_frame_index] = 1

    g_fence_event = kernel32.CreateEventW(None, False, False, None)
    if not g_fence_event:
        raise winerr()

    debug_print("=== D3D12 Initialization Complete ===")

def wait_for_previous_frame():
    global g_frame_index, g_fence_values

    current_fence_value = g_fence_values[g_frame_index]

    # ID3D12CommandQueue::Signal (index 14)
    # VTable: IUnknown(0-2) + ID3D12Object(3-6) + ID3D12DeviceChild(7) + ID3D12Pageable(none) +
    #         ID3D12CommandQueue: 8=UpdateTileMappings, 9=CopyTileMappings, 10=ExecuteCommandLists,
    #         11=SetMarker, 12=BeginEvent, 13=EndEvent, 14=Signal
    signal = com_method(g_command_queue, 14, wintypes.HRESULT, (ctypes.c_void_p, ctypes.c_void_p, ctypes.c_uint64))
    hr = signal(g_command_queue, g_fence, current_fence_value)
    if hr != 0:
        raise RuntimeError(f"Signal failed: 0x{hr & 0xFFFFFFFF:08X}")

    # IDXGISwapChain3::GetCurrentBackBufferIndex (index 36)
    get_idx = com_method(g_swap_chain, 36, wintypes.UINT, (ctypes.c_void_p,))
    g_frame_index = get_idx(g_swap_chain)

    # ID3D12Fence::GetCompletedValue (index 8)
    get_completed = com_method(g_fence, 8, ctypes.c_uint64, (ctypes.c_void_p,))
    if get_completed(g_fence) < g_fence_values[g_frame_index]:
        # ID3D12Fence::SetEventOnCompletion (index 9)
        set_event = com_method(g_fence, 9, wintypes.HRESULT, (ctypes.c_void_p, ctypes.c_uint64, wintypes.HANDLE))
        hr = set_event(g_fence, g_fence_values[g_frame_index], g_fence_event)
        if hr != 0:
            raise RuntimeError(f"SetEventOnCompletion failed: 0x{hr & 0xFFFFFFFF:08X}")
        kernel32.WaitForSingleObject(g_fence_event, INFINITE)

    g_fence_values[g_frame_index] = current_fence_value + 1

def render():
    global g_frame_index
    
    # Reset command allocator
    # ID3D12CommandAllocator::Reset (index 8)
    # VTable: IUnknown(0-2) + ID3D12Object(3-6) + ID3D12DeviceChild(7) + ID3D12Pageable(none) + Reset(8)
    reset_ca = com_method(g_command_allocators[g_frame_index], 8, wintypes.HRESULT, (ctypes.c_void_p,))
    hr = reset_ca(g_command_allocators[g_frame_index])
    if hr != 0:
        debug_print(f"CommandAllocator::Reset failed: 0x{hr & 0xFFFFFFFF:08X}")
        raise RuntimeError(f"CommandAllocator::Reset failed: 0x{hr & 0xFFFFFFFF:08X}")

    # Reset command list
    # ID3D12GraphicsCommandList::Reset (index 10)
    # VTable: IUnknown(0-2) + ID3D12Object(3-6) + ID3D12DeviceChild(7) + ID3D12CommandList(8) + 
    #         Close(9), Reset(10), ...
    reset_cl = com_method(g_command_list, 10, wintypes.HRESULT, (ctypes.c_void_p, ctypes.c_void_p, ctypes.c_void_p))
    hr = reset_cl(g_command_list, g_command_allocators[g_frame_index], g_pipeline_state)
    if hr != 0:
        raise RuntimeError(f"CommandList::Reset failed: 0x{hr & 0xFFFFFFFF:08X}")

    # Set root signature
    # ID3D12GraphicsCommandList::SetGraphicsRootSignature (index 30)
    set_rs = com_method(g_command_list, 30, None, (ctypes.c_void_p, ctypes.c_void_p))
    set_rs(g_command_list, g_root_signature)

    # Set viewport
    viewport = D3D12_VIEWPORT(0.0, 0.0, float(g_width), float(g_height), 0.0, 1.0)
    # ID3D12GraphicsCommandList::RSSetViewports (index 21)
    set_vp = com_method(g_command_list, 21, None, (ctypes.c_void_p, wintypes.UINT, ctypes.POINTER(D3D12_VIEWPORT)))
    set_vp(g_command_list, 1, ctypes.byref(viewport))

    # Set scissor rect
    scissor = D3D12_RECT(0, 0, g_width, g_height)
    # ID3D12GraphicsCommandList::RSSetScissorRects (index 22)
    set_sr = com_method(g_command_list, 22, None, (ctypes.c_void_p, wintypes.UINT, ctypes.POINTER(D3D12_RECT)))
    set_sr(g_command_list, 1, ctypes.byref(scissor))

    # Transition render target to RENDER_TARGET state
    barrier = D3D12_RESOURCE_BARRIER()
    barrier.Type = D3D12_RESOURCE_BARRIER_TYPE_TRANSITION
    barrier.Flags = D3D12_RESOURCE_BARRIER_FLAG_NONE
    barrier.u.Transition.pResource = g_render_targets[g_frame_index].value
    barrier.u.Transition.Subresource = D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES
    barrier.u.Transition.StateBefore = D3D12_RESOURCE_STATE_PRESENT
    barrier.u.Transition.StateAfter = D3D12_RESOURCE_STATE_RENDER_TARGET

    # ID3D12GraphicsCommandList::ResourceBarrier (index 26)
    res_barrier = com_method(g_command_list, 26, None, (ctypes.c_void_p, wintypes.UINT, ctypes.POINTER(D3D12_RESOURCE_BARRIER)))
    res_barrier(g_command_list, 1, ctypes.byref(barrier))

    # Get RTV handle
    # On Windows, this method takes an output parameter: (this, D3D12_CPU_DESCRIPTOR_HANDLE* RetVal)
    heap_ptr = ctypes.c_void_p(g_rtv_heap.value)
    get_cpu_handle = com_method(heap_ptr, 9, ctypes.c_void_p,
                               (ctypes.c_void_p, ctypes.POINTER(D3D12_CPU_DESCRIPTOR_HANDLE)))
    rtv_handle = D3D12_CPU_DESCRIPTOR_HANDLE()
    get_cpu_handle(heap_ptr, ctypes.byref(rtv_handle))
    rtv_handle.ptr += g_frame_index * g_rtv_descriptor_size

    # Set render target
    # ID3D12GraphicsCommandList::OMSetRenderTargets (index 46)
    set_rt = com_method(g_command_list, 46, None,
                       (ctypes.c_void_p, wintypes.UINT, ctypes.POINTER(D3D12_CPU_DESCRIPTOR_HANDLE),
                        wintypes.BOOL, ctypes.c_void_p))
    set_rt(g_command_list, 1, ctypes.byref(rtv_handle), False, None)

    # Clear render target (white background)
    clear_color = (ctypes.c_float * 4)(1.0, 1.0, 1.0, 1.0)
    # ID3D12GraphicsCommandList::ClearRenderTargetView (index 48)
    clear_rtv = com_method(g_command_list, 48, None,
                          (ctypes.c_void_p, D3D12_CPU_DESCRIPTOR_HANDLE, ctypes.POINTER(ctypes.c_float), wintypes.UINT, ctypes.c_void_p))
    clear_rtv(g_command_list, rtv_handle, clear_color, 0, None)

    # Set primitive topology
    # ID3D12GraphicsCommandList::IASetPrimitiveTopology (index 20)
    set_topo = com_method(g_command_list, 20, None, (ctypes.c_void_p, wintypes.UINT))
    set_topo(g_command_list, D3D_PRIMITIVE_TOPOLOGY_TRIANGLELIST)

    # Set vertex buffer
    # ID3D12GraphicsCommandList::IASetVertexBuffers (index 44)
    set_vb = com_method(g_command_list, 44, None,
                       (ctypes.c_void_p, wintypes.UINT, wintypes.UINT, ctypes.POINTER(D3D12_VERTEX_BUFFER_VIEW)))
    set_vb(g_command_list, 0, 1, ctypes.byref(g_vertex_buffer_view))

    # Draw triangle
    # ID3D12GraphicsCommandList::DrawInstanced (index 12)
    draw = com_method(g_command_list, 12, None, (ctypes.c_void_p, wintypes.UINT, wintypes.UINT, wintypes.UINT, wintypes.UINT))
    draw(g_command_list, 3, 1, 0, 0)

    # Transition render target back to PRESENT state
    barrier.u.Transition.StateBefore = D3D12_RESOURCE_STATE_RENDER_TARGET
    barrier.u.Transition.StateAfter = D3D12_RESOURCE_STATE_PRESENT
    res_barrier(g_command_list, 1, ctypes.byref(barrier))

    # Close command list
    # ID3D12GraphicsCommandList::Close (index 9)
    close_cl = com_method(g_command_list, 9, wintypes.HRESULT, (ctypes.c_void_p,))
    hr = close_cl(g_command_list)
    if hr != 0:
        raise RuntimeError(f"CommandList::Close failed: 0x{hr & 0xFFFFFFFF:08X}")

    # Execute command list
    cmd_lists = (ctypes.c_void_p * 1)(g_command_list.value)
    # ID3D12CommandQueue::ExecuteCommandLists (index 10)
    exec_cl = com_method(g_command_queue, 10, None, (ctypes.c_void_p, wintypes.UINT, ctypes.POINTER(ctypes.c_void_p)))
    exec_cl(g_command_queue, 1, cmd_lists)

    # Present
    # IDXGISwapChain::Present (index 8)
    present = com_method(g_swap_chain, 8, wintypes.HRESULT, (ctypes.c_void_p, wintypes.UINT, wintypes.UINT))
    hr = present(g_swap_chain, 1, 0)
    if hr != 0:
        raise RuntimeError(f"Present failed: 0x{hr & 0xFFFFFFFF:08X}")

    wait_for_previous_frame()

def cleanup_d3d():
    # Wait for GPU to finish
    try:
        wait_for_previous_frame()
    except:
        pass

    if g_fence_event:
        kernel32.CloseHandle(g_fence_event)

    com_release(g_fence)
    com_release(g_vertex_buffer)
    com_release(g_pipeline_state)
    com_release(g_root_signature)
    com_release(g_command_list)
    for ca in g_command_allocators:
        com_release(ca)
    com_release(g_rtv_heap)
    for rt in g_render_targets:
        com_release(rt)
    com_release(g_swap_chain)
    com_release(g_command_queue)
    com_release(g_device)
    com_release(g_factory)

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

    ole32.CoInitialize(None)

    hInstance = kernel32.GetModuleHandleW(None)
    class_name = "PyDx12Raw"

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
        "DirectX12 Triangle (ctypes only)",
        WS_OVERLAPPEDWINDOW,
        CW_USEDEFAULT, CW_USEDEFAULT,
        640, 480,
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

if __name__ == "__main__":
    main()
