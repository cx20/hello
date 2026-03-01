# =============================================================================
# DirectX Raytracing (DXR) - Triangle Sample (Python / ctypes)
# =============================================================================
# Minimal DXR sample in pure Python (ctypes only, no external libraries):
# renders a single triangle using raytracing.
#
# Requirements:
#   - Windows 10 Version 1809+
#   - Python 3.8+
#   - Windows SDK (for d3d12.dll, dxgi.dll)
#   - DXR-capable GPU (NVIDIA RTX / AMD RDNA2+) or WARP (software fallback)
#   - dxcompiler.dll and dxil.dll in PATH or script directory
#   - hello.hlsl in the script directory
#
# Run:
#   python hello.py
#
# =============================================================================

import ctypes
import ctypes.wintypes as wintypes
import struct
import sys
import os

# ============================================================
# DLLs
# ============================================================
user32   = ctypes.WinDLL("user32",   use_last_error=True)
kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
ole32    = ctypes.WinDLL("ole32",    use_last_error=True)
d3d12    = ctypes.WinDLL("d3d12",    use_last_error=True)
dxgi     = ctypes.WinDLL("dxgi",     use_last_error=True)

# DXC compiler - required for DXR shader compilation (lib_6_3)
# Python 3.8+ no longer searches PATH by default for DLLs.
# We manually search PATH to find the full path and use os.add_dll_directory.
def _find_dll_on_path(dll_name):
    """Search PATH environment variable for a DLL file."""
    # Check script directory first
    script_dir = os.path.dirname(os.path.abspath(__file__))
    candidate = os.path.join(script_dir, dll_name)
    if os.path.isfile(candidate):
        return candidate
    # Search PATH
    for d in os.environ.get("PATH", "").split(os.pathsep):
        candidate = os.path.join(d, dll_name)
        if os.path.isfile(candidate):
            return candidate
    return None

def _load_dxc():
    """Load dxcompiler.dll with PATH search and dependent DLL support."""
    # Try direct load first (works if DLL is in system dir or script dir)
    try:
        return ctypes.WinDLL("dxcompiler", use_last_error=True)
    except OSError:
        pass
    # Find on PATH manually
    found = _find_dll_on_path("dxcompiler.dll")
    if not found:
        return None
    # Add directory so dependent DLLs (dxil.dll) can also be found
    dll_dir = os.path.dirname(os.path.abspath(found))
    if hasattr(os, "add_dll_directory"):
        os.add_dll_directory(dll_dir)
    return ctypes.WinDLL(found, use_last_error=True)

try:
    dxcompiler = _load_dxc()
    if dxcompiler is None:
        raise OSError()
except OSError as e:
    found = _find_dll_on_path("dxcompiler.dll")
    print("ERROR: Failed to load dxcompiler.dll.")
    if found:
        print(f"  Found at: {found}")
        print(f"  Load error: {e}")
        print("  This may be a 32-bit/64-bit mismatch between Python and the DLL.")
        print(f"  Python is {'64' if sys.maxsize > 2**32 else '32'}-bit")
    else:
        print("  DLL not found on PATH or in script directory.")
    print("Ensure dxcompiler.dll and dxil.dll are in PATH or script directory.")
    sys.exit(1)

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
WNDPROC = ctypes.WINFUNCTYPE(LRESULT, wintypes.HWND, wintypes.UINT,
                              wintypes.WPARAM, wintypes.LPARAM)

def winerr():
    return ctypes.WinError(ctypes.get_last_error())

# ============================================================
# Win32 constants
# ============================================================
CS_HREDRAW  = 0x0002
CS_VREDRAW  = 0x0001
WS_OVERLAPPEDWINDOW = 0x00CF0000
CW_USEDEFAULT = 0x80000000
SW_SHOW     = 5
WM_DESTROY  = 0x0002
WM_KEYDOWN  = 0x0100
WM_QUIT     = 0x0012
PM_REMOVE   = 0x0001
INFINITE    = 0xFFFFFFFF
IDC_ARROW   = 32512
VK_ESCAPE   = 0x1B

# ============================================================
# D3D12 / DXGI constants
# ============================================================
WIDTH       = 800
HEIGHT      = 600
FRAME_COUNT = 2

# DXGI_FORMAT
DXGI_FORMAT_UNKNOWN            = 0
DXGI_FORMAT_R32G32B32A32_FLOAT = 2
DXGI_FORMAT_R32G32B32_FLOAT    = 6
DXGI_FORMAT_R8G8B8A8_UNORM     = 28

# DXGI misc
DXGI_SWAP_EFFECT_FLIP_DISCARD  = 4
DXGI_USAGE_RENDER_TARGET_OUTPUT = 0x00000020
DXGI_ADAPTER_FLAG_SOFTWARE     = 2

# D3D12 command / heap / fence
D3D12_COMMAND_LIST_TYPE_DIRECT  = 0
D3D12_COMMAND_QUEUE_FLAG_NONE   = 0
D3D12_FENCE_FLAG_NONE           = 0
D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV = 0
D3D12_DESCRIPTOR_HEAP_TYPE_RTV  = 2
D3D12_DESCRIPTOR_HEAP_FLAG_NONE = 0
D3D12_DESCRIPTOR_HEAP_FLAG_SHADER_VISIBLE = 0x1

# D3D12 resource states
D3D12_RESOURCE_STATE_COMMON     = 0
D3D12_RESOURCE_STATE_PRESENT    = 0
D3D12_RESOURCE_STATE_GENERIC_READ = 0x0AC3
D3D12_RESOURCE_STATE_UNORDERED_ACCESS = 0x8
D3D12_RESOURCE_STATE_COPY_DEST  = 0x400
D3D12_RESOURCE_STATE_COPY_SOURCE = 0x800
D3D12_RESOURCE_STATE_RAYTRACING_ACCELERATION_STRUCTURE = 0x400000

# D3D12 heap / resource
D3D12_HEAP_TYPE_DEFAULT  = 1
D3D12_HEAP_TYPE_UPLOAD   = 2
D3D12_HEAP_FLAG_NONE     = 0
D3D12_RESOURCE_DIMENSION_BUFFER    = 1
D3D12_RESOURCE_DIMENSION_TEXTURE2D = 3
D3D12_TEXTURE_LAYOUT_ROW_MAJOR    = 1
D3D12_RESOURCE_FLAG_NONE = 0
D3D12_RESOURCE_FLAG_ALLOW_UNORDERED_ACCESS = 0x4

# D3D12 resource barrier
D3D12_RESOURCE_BARRIER_TYPE_TRANSITION = 0
D3D12_RESOURCE_BARRIER_TYPE_UAV        = 2
D3D12_RESOURCE_BARRIER_FLAG_NONE       = 0
D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES = 0xFFFFFFFF

# D3D12 UAV
D3D12_UAV_DIMENSION_TEXTURE2D = 3

# D3D12 feature levels
D3D_FEATURE_LEVEL_12_1 = 0xC100
D3D12_FEATURE_D3D12_OPTIONS5 = 27
D3D12_RAYTRACING_TIER_NOT_SUPPORTED = 0
D3D12_RAYTRACING_TIER_1_0 = 10

# D3D12 root signature
D3D_ROOT_SIGNATURE_VERSION_1 = 1
D3D12_ROOT_PARAMETER_TYPE_DESCRIPTOR_TABLE = 0
D3D12_ROOT_PARAMETER_TYPE_SRV = 3
D3D12_DESCRIPTOR_RANGE_TYPE_UAV = 1

# D3D12 raytracing
D3D12_RAYTRACING_GEOMETRY_TYPE_TRIANGLES = 0
D3D12_RAYTRACING_GEOMETRY_FLAG_OPAQUE    = 0x1
# D3D12_RAYTRACING_ACCELERATION_STRUCTURE_TYPE
D3D12_RAYTRACING_ACCELERATION_STRUCTURE_TYPE_TOP_LEVEL    = 0
D3D12_RAYTRACING_ACCELERATION_STRUCTURE_TYPE_BOTTOM_LEVEL = 1
D3D12_ELEMENTS_LAYOUT_ARRAY = 0
D3D12_RAYTRACING_ACCELERATION_STRUCTURE_BUILD_FLAG_PREFER_FAST_TRACE = 0x2

# D3D12 state object
D3D12_STATE_SUBOBJECT_TYPE_DXIL_LIBRARY               = 5
D3D12_STATE_SUBOBJECT_TYPE_HIT_GROUP                  = 11
D3D12_STATE_SUBOBJECT_TYPE_RAYTRACING_SHADER_CONFIG   = 9
D3D12_STATE_SUBOBJECT_TYPE_GLOBAL_ROOT_SIGNATURE      = 1
D3D12_STATE_SUBOBJECT_TYPE_RAYTRACING_PIPELINE_CONFIG = 10
D3D12_HIT_GROUP_TYPE_TRIANGLES      = 0
D3D12_STATE_OBJECT_TYPE_RAYTRACING_PIPELINE = 3

D3D12_SHADER_IDENTIFIER_SIZE_IN_BYTES        = 32
D3D12_RAYTRACING_SHADER_TABLE_BYTE_ALIGNMENT = 64

# DXC constants
DXC_OUT_OBJECT = 1
DXC_OUT_ERRORS = 2

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

# D3D12 / DXGI GUIDs
IID_IDXGIFactory4          = guid_from_str("{1bc6ea02-ef36-464f-bf0c-21ca39e5168a}")
IID_IDXGISwapChain3        = guid_from_str("{94d99bdb-f1f8-4ab0-b236-7da0170edab1}")
IID_IDXGIAdapter           = guid_from_str("{2411e7e1-12ac-4ccf-bd14-9798e8534dc0}")
IID_ID3D12Device           = guid_from_str("{189819f1-1db6-4b57-be54-1821339b85f7}")
IID_ID3D12Device5          = guid_from_str("{8b4f173b-2fea-4b80-8f58-4307191ab95d}")
IID_ID3D12CommandQueue      = guid_from_str("{0ec870a6-5d7e-4c22-8cfc-5baae07616ed}")
IID_ID3D12CommandAllocator  = guid_from_str("{6102dee4-af59-4b09-b999-b44d73f09b24}")
IID_ID3D12GraphicsCommandList  = guid_from_str("{5b160d0f-ac1b-4185-8ba8-b3ae42a5a455}")
IID_ID3D12GraphicsCommandList4 = guid_from_str("{8754318e-d3a9-4541-98cf-645b50dc4874}")
IID_ID3D12Resource          = guid_from_str("{696442be-a72e-4059-bc79-5b5c98040fad}")
IID_ID3D12DescriptorHeap    = guid_from_str("{8efb471d-616c-4f49-90f7-127bb763fa51}")
IID_ID3D12RootSignature     = guid_from_str("{c54a6b66-72df-4ee8-8be5-a946a1429214}")
IID_ID3D12Fence             = guid_from_str("{0a753dcf-c4d8-4b91-adf6-be5a60d95a76}")
IID_ID3D12Debug             = guid_from_str("{344488b7-6846-474b-b989-f027448245e0}")
IID_ID3D12StateObject       = guid_from_str("{47016943-fca8-4594-93ea-af258b55346d}")
IID_ID3D12StateObjectProperties = guid_from_str("{de5fa827-9bf9-4f26-89ff-d7f56fde3860}")

# DXC GUIDs
CLSID_DxcUtils     = guid_from_str("{6245D6AF-66E0-48FD-80B4-4D271796748C}")
CLSID_DxcCompiler  = guid_from_str("{73e22d93-e6ce-47f3-b5bf-f0664f39c1b0}")
IID_IDxcUtils      = guid_from_str("{4605C4CB-2019-492A-ADA4-65F20BB7D67F}")
IID_IDxcCompiler3  = guid_from_str("{228B4687-5A6A-4730-900C-9702B2203F54}")
IID_IDxcResult     = guid_from_str("{58346CDA-DDE7-4497-9461-6F87AF5E0659}")
IID_IDxcBlob       = guid_from_str("{8BA5FB08-5195-40e2-AC58-0D989C3A0102}")
IID_IDxcBlobUtf8   = guid_from_str("{3DA636C9-BA71-4024-A301-30CBF125305B}")

# ============================================================
# Win32 structures
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
# DXGI structures
# ============================================================
class DXGI_SAMPLE_DESC(ctypes.Structure):
    _fields_ = [("Count", wintypes.UINT), ("Quality", wintypes.UINT)]

class DXGI_SWAP_CHAIN_DESC1(ctypes.Structure):
    _fields_ = [
        ("Width",       wintypes.UINT),
        ("Height",      wintypes.UINT),
        ("Format",      wintypes.UINT),
        ("Stereo",      wintypes.BOOL),
        ("SampleDesc",  DXGI_SAMPLE_DESC),
        ("BufferUsage", wintypes.UINT),
        ("BufferCount", wintypes.UINT),
        ("Scaling",     wintypes.UINT),
        ("SwapEffect",  wintypes.UINT),
        ("AlphaMode",   wintypes.UINT),
        ("Flags",       wintypes.UINT),
    ]

class LUID(ctypes.Structure):
    _fields_ = [("LowPart", wintypes.DWORD), ("HighPart", ctypes.c_long)]

class DXGI_ADAPTER_DESC1(ctypes.Structure):
    _fields_ = [
        ("Description",           wintypes.WCHAR * 128),
        ("VendorId",              wintypes.UINT),
        ("DeviceId",              wintypes.UINT),
        ("SubSysId",              wintypes.UINT),
        ("Revision",              wintypes.UINT),
        ("DedicatedVideoMemory",  ctypes.c_size_t),
        ("DedicatedSystemMemory", ctypes.c_size_t),
        ("SharedSystemMemory",    ctypes.c_size_t),
        ("AdapterLuid",           LUID),
        ("Flags",                 wintypes.UINT),
    ]

# ============================================================
# D3D12 structures
# ============================================================
class D3D12_COMMAND_QUEUE_DESC(ctypes.Structure):
    _fields_ = [
        ("Type",     wintypes.UINT),
        ("Priority", ctypes.c_int),
        ("Flags",    wintypes.UINT),
        ("NodeMask", wintypes.UINT),
    ]

class D3D12_DESCRIPTOR_HEAP_DESC(ctypes.Structure):
    _fields_ = [
        ("Type",           wintypes.UINT),
        ("NumDescriptors", wintypes.UINT),
        ("Flags",          wintypes.UINT),
        ("NodeMask",       wintypes.UINT),
    ]

class D3D12_CPU_DESCRIPTOR_HANDLE(ctypes.Structure):
    _fields_ = [("ptr", ctypes.c_size_t)]

class D3D12_GPU_DESCRIPTOR_HANDLE(ctypes.Structure):
    _fields_ = [("ptr", ctypes.c_uint64)]

class D3D12_HEAP_PROPERTIES(ctypes.Structure):
    _fields_ = [
        ("Type",                 wintypes.UINT),
        ("CPUPageProperty",      wintypes.UINT),
        ("MemoryPoolPreference", wintypes.UINT),
        ("CreationNodeMask",     wintypes.UINT),
        ("VisibleNodeMask",      wintypes.UINT),
    ]

class D3D12_RESOURCE_DESC(ctypes.Structure):
    _fields_ = [
        ("Dimension",        wintypes.UINT),
        ("Alignment",        ctypes.c_uint64),
        ("Width",            ctypes.c_uint64),
        ("Height",           wintypes.UINT),
        ("DepthOrArraySize", wintypes.WORD),
        ("MipLevels",        wintypes.WORD),
        ("Format",           wintypes.UINT),
        ("SampleDesc",       DXGI_SAMPLE_DESC),
        ("Layout",           wintypes.UINT),
        ("Flags",            wintypes.UINT),
    ]

class D3D12_RANGE(ctypes.Structure):
    _fields_ = [("Begin", ctypes.c_size_t), ("End", ctypes.c_size_t)]

# Resource barrier structures
class D3D12_RESOURCE_TRANSITION_BARRIER(ctypes.Structure):
    _fields_ = [
        ("pResource",   ctypes.c_void_p),
        ("Subresource", wintypes.UINT),
        ("StateBefore", wintypes.UINT),
        ("StateAfter",  wintypes.UINT),
    ]

class D3D12_RESOURCE_UAV_BARRIER(ctypes.Structure):
    _fields_ = [("pResource", ctypes.c_void_p)]

class D3D12_RESOURCE_BARRIER_UNION(ctypes.Union):
    _fields_ = [
        ("Transition", D3D12_RESOURCE_TRANSITION_BARRIER),
        ("UAV",        D3D12_RESOURCE_UAV_BARRIER),
        ("_padding",   ctypes.c_ubyte * 24),
    ]

class D3D12_RESOURCE_BARRIER(ctypes.Structure):
    _fields_ = [
        ("Type",  wintypes.UINT),
        ("Flags", wintypes.UINT),
        ("u",     D3D12_RESOURCE_BARRIER_UNION),
    ]

# Root signature structures
class D3D12_DESCRIPTOR_RANGE(ctypes.Structure):
    _fields_ = [
        ("RangeType",                         ctypes.c_uint32),
        ("NumDescriptors",                    ctypes.c_uint32),
        ("BaseShaderRegister",                ctypes.c_uint32),
        ("RegisterSpace",                     ctypes.c_uint32),
        ("OffsetInDescriptorsFromTableStart", ctypes.c_uint32),
    ]

class _ROOT_PARAM_DESCRIPTOR_TABLE(ctypes.Structure):
    _fields_ = [
        ("NumDescriptorRanges", ctypes.c_uint32),
        ("_pad",                ctypes.c_uint32),
        ("pDescriptorRanges",   ctypes.c_void_p),
    ]

class _ROOT_PARAM_DESCRIPTOR(ctypes.Structure):
    _fields_ = [
        ("ShaderRegister", ctypes.c_uint32),
        ("RegisterSpace",  ctypes.c_uint32),
    ]

class _ROOT_PARAM_UNION(ctypes.Union):
    _fields_ = [
        ("DescriptorTable", _ROOT_PARAM_DESCRIPTOR_TABLE),
        ("Descriptor",      _ROOT_PARAM_DESCRIPTOR),
        ("_raw",            ctypes.c_ubyte * 16),
    ]

class D3D12_ROOT_PARAMETER(ctypes.Structure):
    _fields_ = [
        ("ParameterType",    ctypes.c_uint32),
        ("_pad0",            ctypes.c_uint32),
        ("u",                _ROOT_PARAM_UNION),
        ("ShaderVisibility", ctypes.c_uint32),
        ("_pad1",            ctypes.c_uint32),
    ]

class D3D12_ROOT_SIGNATURE_DESC(ctypes.Structure):
    _fields_ = [
        ("NumParameters",     wintypes.UINT),
        ("pParameters",       ctypes.c_void_p),
        ("NumStaticSamplers", wintypes.UINT),
        ("pStaticSamplers",   ctypes.c_void_p),
        ("Flags",             wintypes.UINT),
    ]

# Shader bytecode
class D3D12_SHADER_BYTECODE(ctypes.Structure):
    _fields_ = [
        ("pShaderBytecode", ctypes.c_void_p),
        ("BytecodeLength",  ctypes.c_size_t),
    ]

# UAV desc
class D3D12_TEX2D_UAV(ctypes.Structure):
    _fields_ = [("MipSlice", ctypes.c_uint32), ("PlaneSlice", ctypes.c_uint32)]

class D3D12_BUFFER_UAV(ctypes.Structure):
    _fields_ = [
        ("FirstElement", ctypes.c_uint64),
        ("NumElements", ctypes.c_uint32),
        ("StructureByteStride", ctypes.c_uint32),
        ("CounterOffsetInBytes", ctypes.c_uint64),
        ("Flags", ctypes.c_uint32),
        ("_pad", ctypes.c_uint32),
    ]

class D3D12_UAV_DESC_UNION(ctypes.Union):
    _fields_ = [
        ("Texture2D", D3D12_TEX2D_UAV),
        # Keep native size/alignment via real largest member.
        ("Buffer", D3D12_BUFFER_UAV),
    ]

class D3D12_UNORDERED_ACCESS_VIEW_DESC(ctypes.Structure):
    _fields_ = [
        ("Format",        ctypes.c_uint32),
        ("ViewDimension", ctypes.c_uint32),
        ("u",             D3D12_UAV_DESC_UNION),
    ]

# Feature support
class D3D12_FEATURE_DATA_D3D12_OPTIONS5(ctypes.Structure):
    _fields_ = [
        ("SRVOnlyTiledResourceTier3", wintypes.BOOL),
        ("RenderPassesTier",          ctypes.c_uint32),
        ("RaytracingTier",            ctypes.c_uint32),
    ]

# ============================================================
# DXR-specific structures
# ============================================================
class D3D12_GPU_VIRTUAL_ADDRESS_AND_STRIDE(ctypes.Structure):
    _fields_ = [
        ("StartAddress",  ctypes.c_uint64),
        ("StrideInBytes", ctypes.c_uint64),
    ]

class D3D12_RAYTRACING_GEOMETRY_TRIANGLES_DESC(ctypes.Structure):
    _fields_ = [
        ("Transform3x4",  ctypes.c_uint64),
        ("IndexFormat",    ctypes.c_uint32),
        ("VertexFormat",   ctypes.c_uint32),
        ("IndexCount",     ctypes.c_uint32),
        ("VertexCount",    ctypes.c_uint32),
        ("IndexBuffer",    ctypes.c_uint64),
        ("VertexBuffer",   D3D12_GPU_VIRTUAL_ADDRESS_AND_STRIDE),
    ]

class D3D12_RAYTRACING_GEOMETRY_AABBS_DESC(ctypes.Structure):
    _fields_ = [
        ("AABBCount", ctypes.c_uint64),
        ("AABBs",     D3D12_GPU_VIRTUAL_ADDRESS_AND_STRIDE),
    ]

class _GEOMETRY_UNION(ctypes.Union):
    _fields_ = [
        ("Triangles", D3D12_RAYTRACING_GEOMETRY_TRIANGLES_DESC),
        ("AABBs",     D3D12_RAYTRACING_GEOMETRY_AABBS_DESC),
    ]

class D3D12_RAYTRACING_GEOMETRY_DESC(ctypes.Structure):
    _fields_ = [
        ("Type",  ctypes.c_uint32),
        ("Flags", ctypes.c_uint32),
        ("u",     _GEOMETRY_UNION),
    ]

class _AS_INPUTS_UNION(ctypes.Union):
    _fields_ = [
        ("InstanceDescs",   ctypes.c_uint64),
        ("pGeometryDescs",  ctypes.c_void_p),
    ]

class D3D12_BUILD_RAYTRACING_ACCELERATION_STRUCTURE_INPUTS(ctypes.Structure):
    _fields_ = [
        ("Type",       ctypes.c_uint32),
        ("Flags",      ctypes.c_uint32),
        ("NumDescs",   ctypes.c_uint32),
        ("DescsLayout", ctypes.c_uint32),
        ("u",          _AS_INPUTS_UNION),
    ]

class D3D12_RAYTRACING_ACCELERATION_STRUCTURE_PREBUILD_INFO(ctypes.Structure):
    _fields_ = [
        ("ResultDataMaxSizeInBytes",  ctypes.c_uint64),
        ("ScratchDataSizeInBytes",    ctypes.c_uint64),
        ("UpdateScratchDataSizeInBytes", ctypes.c_uint64),
    ]

class D3D12_BUILD_RAYTRACING_ACCELERATION_STRUCTURE_DESC(ctypes.Structure):
    _fields_ = [
        ("DestAccelerationStructureData",    ctypes.c_uint64),
        ("Inputs", D3D12_BUILD_RAYTRACING_ACCELERATION_STRUCTURE_INPUTS),
        ("SourceAccelerationStructureData",  ctypes.c_uint64),
        ("ScratchAccelerationStructureData", ctypes.c_uint64),
    ]

class D3D12_RAYTRACING_INSTANCE_DESC(ctypes.Structure):
    """64-byte instance descriptor for TLAS."""
    _fields_ = [
        ("Transform",              (ctypes.c_float * 4) * 3),
        ("InstanceID_and_Mask",    ctypes.c_uint32),
        ("HitGroupIndex_and_Flags", ctypes.c_uint32),
        ("AccelerationStructure",  ctypes.c_uint64),
    ]

# State object subobject structures
class D3D12_DXIL_LIBRARY_DESC(ctypes.Structure):
    _fields_ = [
        ("DXILLibrary", D3D12_SHADER_BYTECODE),
        ("NumExports",  ctypes.c_uint32),
        ("_pad",        ctypes.c_uint32),
        ("pExports",    ctypes.c_void_p),
    ]

class D3D12_HIT_GROUP_DESC(ctypes.Structure):
    _fields_ = [
        ("HitGroupExport",           ctypes.c_wchar_p),
        ("Type",                     ctypes.c_uint32),
        ("_pad",                     ctypes.c_uint32),
        ("AnyHitShaderImport",       ctypes.c_wchar_p),
        ("ClosestHitShaderImport",   ctypes.c_wchar_p),
        ("IntersectionShaderImport", ctypes.c_wchar_p),
    ]

class D3D12_RAYTRACING_SHADER_CONFIG(ctypes.Structure):
    _fields_ = [
        ("MaxPayloadSizeInBytes",   ctypes.c_uint32),
        ("MaxAttributeSizeInBytes", ctypes.c_uint32),
    ]

class D3D12_GLOBAL_ROOT_SIGNATURE(ctypes.Structure):
    _fields_ = [("pGlobalRootSignature", ctypes.c_void_p)]

class D3D12_RAYTRACING_PIPELINE_CONFIG(ctypes.Structure):
    _fields_ = [("MaxTraceRecursionDepth", ctypes.c_uint32)]

class D3D12_STATE_SUBOBJECT(ctypes.Structure):
    _fields_ = [
        ("Type",  ctypes.c_uint32),
        ("_pad",  ctypes.c_uint32),
        ("pDesc", ctypes.c_void_p),
    ]

class D3D12_STATE_OBJECT_DESC(ctypes.Structure):
    _fields_ = [
        ("Type",          ctypes.c_uint32),
        ("NumSubobjects", ctypes.c_uint32),
        ("pSubobjects",   ctypes.c_void_p),
    ]

# DispatchRays structures
class D3D12_GPU_VIRTUAL_ADDRESS_RANGE(ctypes.Structure):
    _fields_ = [
        ("StartAddress", ctypes.c_uint64),
        ("SizeInBytes",  ctypes.c_uint64),
    ]

class D3D12_GPU_VIRTUAL_ADDRESS_RANGE_AND_STRIDE(ctypes.Structure):
    _fields_ = [
        ("StartAddress",  ctypes.c_uint64),
        ("SizeInBytes",   ctypes.c_uint64),
        ("StrideInBytes", ctypes.c_uint64),
    ]

class D3D12_DISPATCH_RAYS_DESC(ctypes.Structure):
    _fields_ = [
        ("RayGenerationShaderRecord", D3D12_GPU_VIRTUAL_ADDRESS_RANGE),
        ("MissShaderTable",           D3D12_GPU_VIRTUAL_ADDRESS_RANGE_AND_STRIDE),
        ("HitGroupTable",             D3D12_GPU_VIRTUAL_ADDRESS_RANGE_AND_STRIDE),
        ("CallableShaderTable",       D3D12_GPU_VIRTUAL_ADDRESS_RANGE_AND_STRIDE),
        ("Width",  ctypes.c_uint32),
        ("Height", ctypes.c_uint32),
        ("Depth",  ctypes.c_uint32),
    ]

# ============================================================
# Win32 prototypes
# ============================================================
kernel32.GetModuleHandleW.restype  = wintypes.HMODULE
kernel32.GetModuleHandleW.argtypes = (wintypes.LPCWSTR,)
kernel32.Sleep.restype  = None
kernel32.Sleep.argtypes = (wintypes.DWORD,)
kernel32.CreateEventW.restype  = wintypes.HANDLE
kernel32.CreateEventW.argtypes = (ctypes.c_void_p, wintypes.BOOL, wintypes.BOOL, wintypes.LPCWSTR)
kernel32.WaitForSingleObject.restype  = wintypes.DWORD
kernel32.WaitForSingleObject.argtypes = (wintypes.HANDLE, wintypes.DWORD)
kernel32.CloseHandle.restype  = wintypes.BOOL
kernel32.CloseHandle.argtypes = (wintypes.HANDLE,)
kernel32.OutputDebugStringW.restype  = None
kernel32.OutputDebugStringW.argtypes = (wintypes.LPCWSTR,)

user32.DefWindowProcW.restype  = LRESULT
user32.DefWindowProcW.argtypes = (wintypes.HWND, wintypes.UINT, wintypes.WPARAM, wintypes.LPARAM)
user32.RegisterClassExW.restype  = wintypes.ATOM
user32.RegisterClassExW.argtypes = (ctypes.POINTER(WNDCLASSEXW),)
user32.CreateWindowExW.restype  = wintypes.HWND
user32.CreateWindowExW.argtypes = (
    wintypes.DWORD, wintypes.LPCWSTR, wintypes.LPCWSTR, wintypes.DWORD,
    ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_int,
    wintypes.HWND, wintypes.HMENU, wintypes.HINSTANCE, wintypes.LPVOID)
user32.ShowWindow.restype  = wintypes.BOOL
user32.ShowWindow.argtypes = (wintypes.HWND, ctypes.c_int)
user32.PeekMessageW.restype  = wintypes.BOOL
user32.PeekMessageW.argtypes = (ctypes.POINTER(MSG), wintypes.HWND, wintypes.UINT, wintypes.UINT, wintypes.UINT)
user32.TranslateMessage.restype  = wintypes.BOOL
user32.TranslateMessage.argtypes = (ctypes.POINTER(MSG),)
user32.DispatchMessageW.restype  = LRESULT
user32.DispatchMessageW.argtypes = (ctypes.POINTER(MSG),)
user32.PostQuitMessage.restype  = None
user32.PostQuitMessage.argtypes = (ctypes.c_int,)
user32.LoadCursorW.restype  = wintypes.HCURSOR
user32.LoadCursorW.argtypes = (wintypes.HINSTANCE, wintypes.LPCWSTR)
user32.AdjustWindowRect.restype  = wintypes.BOOL
user32.AdjustWindowRect.argtypes = (ctypes.POINTER(RECT), wintypes.DWORD, wintypes.BOOL)

# ============================================================
# D3D12 / DXGI function prototypes
# ============================================================
CreateDXGIFactory2 = dxgi.CreateDXGIFactory2
CreateDXGIFactory2.restype  = wintypes.HRESULT
CreateDXGIFactory2.argtypes = (wintypes.UINT, ctypes.POINTER(GUID), ctypes.POINTER(ctypes.c_void_p))

D3D12CreateDevice = d3d12.D3D12CreateDevice
D3D12CreateDevice.restype  = wintypes.HRESULT
D3D12CreateDevice.argtypes = (ctypes.c_void_p, wintypes.UINT, ctypes.POINTER(GUID), ctypes.POINTER(ctypes.c_void_p))

D3D12GetDebugInterface = d3d12.D3D12GetDebugInterface
D3D12GetDebugInterface.restype  = wintypes.HRESULT
D3D12GetDebugInterface.argtypes = (ctypes.POINTER(GUID), ctypes.POINTER(ctypes.c_void_p))

D3D12SerializeRootSignature = d3d12.D3D12SerializeRootSignature
D3D12SerializeRootSignature.restype  = wintypes.HRESULT
D3D12SerializeRootSignature.argtypes = (
    ctypes.POINTER(D3D12_ROOT_SIGNATURE_DESC), wintypes.UINT,
    ctypes.POINTER(ctypes.c_void_p), ctypes.POINTER(ctypes.c_void_p))

DxcCreateInstance = dxcompiler.DxcCreateInstance
DxcCreateInstance.restype  = wintypes.HRESULT
DxcCreateInstance.argtypes = (ctypes.POINTER(GUID), ctypes.POINTER(GUID), ctypes.POINTER(ctypes.c_void_p))

# ============================================================
# COM vtable caller
# ============================================================
def com_method(obj, index: int, restype, argtypes):
    """Call a COM method by vtable index."""
    if isinstance(obj, ctypes.c_void_p):
        ptr_value = obj.value
    elif isinstance(obj, int):
        ptr_value = obj
    else:
        ptr_value = obj
    if ptr_value is None or ptr_value == 0:
        raise RuntimeError(f"com_method: NULL pointer at vtable index {index}")
    vtbl = ctypes.cast(ptr_value, ctypes.POINTER(ctypes.POINTER(ctypes.c_void_p))).contents
    fn_addr = vtbl[index]
    if not fn_addr:
        raise RuntimeError(f"com_method: NULL function pointer at vtable index {index}")
    fn_addr = fn_addr.value if isinstance(fn_addr, ctypes.c_void_p) else int(fn_addr)
    # On x64 Windows, COM methods use the unified x64 calling convention.
    # CFUNCTYPE avoids Python 3.13 WINFUNCTYPE quirks around void methods.
    if ctypes.sizeof(ctypes.c_void_p) == 8:
        FN = ctypes.CFUNCTYPE(restype, *argtypes)
    else:
        # x86 fallback
        if restype is None:
            restype = ctypes.c_int
        FN = ctypes.WINFUNCTYPE(restype, *argtypes)
    return FN(fn_addr)

def com_method_addr(obj, index: int) -> int:
    """Get raw function pointer address from COM vtable."""
    if isinstance(obj, ctypes.c_void_p):
        ptr_value = obj.value
    elif isinstance(obj, int):
        ptr_value = obj
    else:
        ptr_value = obj
    if not ptr_value:
        return 0
    vtbl = ctypes.cast(ptr_value, ctypes.POINTER(ctypes.POINTER(ctypes.c_void_p))).contents
    fn_addr = vtbl[index]
    return fn_addr.value if isinstance(fn_addr, ctypes.c_void_p) else int(fn_addr)

def com_release(obj_ref):
    """Call IUnknown::Release (index 2)."""
    if obj_ref:
        val = obj_ref.value if isinstance(obj_ref, ctypes.c_void_p) else obj_ref
        if val:
            try:
                com_method(val, 2, wintypes.ULONG, (ctypes.c_void_p,))(val)
            except Exception:
                pass

def com_qi(obj, iid_new):
    """Call IUnknown::QueryInterface (index 0)."""
    val = obj.value if isinstance(obj, ctypes.c_void_p) else obj
    result = ctypes.c_void_p()
    qi = com_method(val, 0, wintypes.HRESULT, (ctypes.c_void_p, ctypes.POINTER(GUID), ctypes.POINTER(ctypes.c_void_p)))
    hr = qi(val, ctypes.byref(iid_new), ctypes.byref(result))
    check_hr(hr, "QueryInterface")
    return result

def blob_ptr(blob):
    """IDxcBlob/ID3DBlob::GetBufferPointer (index 3)."""
    v = blob.value if isinstance(blob, ctypes.c_void_p) else blob
    return com_method(v, 3, ctypes.c_void_p, (ctypes.c_void_p,))(v)

def blob_size(blob):
    """IDxcBlob/ID3DBlob::GetBufferSize (index 4)."""
    v = blob.value if isinstance(blob, ctypes.c_void_p) else blob
    return com_method(v, 4, ctypes.c_size_t, (ctypes.c_void_p,))(v)

# ============================================================
# Debug / error helpers
# ============================================================
def debug_print(msg: str):
    kernel32.OutputDebugStringW(f"[DXR-Py] {msg}\n")
    print(f"[DXR-Py] {msg}")

def check_hr(hr, msg):
    if hr != 0 and hr < 0:
        if (hr & 0xFFFFFFFF) == 0x887A0005 and g_device:
            try:
                get_reason = com_method(g_device, 37, wintypes.HRESULT, (ctypes.c_void_p,))
                reason = get_reason(g_device)
                debug_print(f"DeviceRemovedReason: 0x{reason & 0xFFFFFFFF:08X}")
            except Exception:
                pass
        err_msg = f"{msg} failed: 0x{hr & 0xFFFFFFFF:08X}"
        debug_print(err_msg)
        raise RuntimeError(err_msg)

def align_up(size, alignment):
    return (size + alignment - 1) & ~(alignment - 1)

# ============================================================
# Global D3D12 objects
# ============================================================
g_hwnd = None

g_factory         = ctypes.c_void_p()
g_device          = ctypes.c_void_p()  # ID3D12Device5
g_command_queue   = ctypes.c_void_p()
g_command_alloc   = ctypes.c_void_p()
g_command_list    = ctypes.c_void_p()  # ID3D12GraphicsCommandList4
g_swap_chain      = ctypes.c_void_p()  # IDXGISwapChain3
g_rtv_heap        = ctypes.c_void_p()
g_render_targets  = [ctypes.c_void_p() for _ in range(FRAME_COUNT)]
g_rtv_desc_size   = 0
g_frame_index     = 0

# Synchronization
g_fence       = ctypes.c_void_p()
g_fence_value = 0
g_fence_event = None

# DXR-specific objects
g_vertex_buffer   = ctypes.c_void_p()
g_bottom_level_as = ctypes.c_void_p()
g_top_level_as    = ctypes.c_void_p()
g_instance_buffer = ctypes.c_void_p()
g_state_object    = ctypes.c_void_p()
g_output_resource = ctypes.c_void_p()
g_srv_uav_heap    = ctypes.c_void_p()
g_global_root_sig = ctypes.c_void_p()
g_shader_table    = ctypes.c_void_p()
g_scratch_blas    = ctypes.c_void_p()
g_scratch_tlas    = ctypes.c_void_p()

# ============================================================
# Helper: Get GPU virtual address of a resource
# ============================================================
# ID3D12Resource vtable:
#   IUnknown(0-2) + ID3D12Object(3-6) + ID3D12DeviceChild(7) +
#   ID3D12Pageable(none) + Map(8), Unmap(9), GetDesc(10), GetGPUVirtualAddress(11)
def get_gpu_va(resource):
    fn = com_method(resource, 11, ctypes.c_uint64, (ctypes.c_void_p,))
    return fn(resource.value if isinstance(resource, ctypes.c_void_p) else resource)

# ============================================================
# Helper: Create an upload heap buffer
# ============================================================
def create_upload_buffer(size):
    hp = D3D12_HEAP_PROPERTIES()
    hp.Type = D3D12_HEAP_TYPE_UPLOAD

    rd = D3D12_RESOURCE_DESC()
    rd.Dimension        = D3D12_RESOURCE_DIMENSION_BUFFER
    rd.Width            = size
    rd.Height           = 1
    rd.DepthOrArraySize = 1
    rd.MipLevels        = 1
    rd.SampleDesc.Count = 1
    rd.Layout           = D3D12_TEXTURE_LAYOUT_ROW_MAJOR
    rd.Flags            = D3D12_RESOURCE_FLAG_NONE

    buf = ctypes.c_void_p()
    # ID3D12Device::CreateCommittedResource (index 27)
    create_res = com_method(g_device, 27, wintypes.HRESULT,
        (ctypes.c_void_p, ctypes.POINTER(D3D12_HEAP_PROPERTIES), wintypes.UINT,
         ctypes.POINTER(D3D12_RESOURCE_DESC), wintypes.UINT, ctypes.c_void_p,
         ctypes.POINTER(GUID), ctypes.POINTER(ctypes.c_void_p)))
    hr = create_res(g_device, ctypes.byref(hp), D3D12_HEAP_FLAG_NONE, ctypes.byref(rd),
                    D3D12_RESOURCE_STATE_GENERIC_READ, None,
                    ctypes.byref(IID_ID3D12Resource), ctypes.byref(buf))
    check_hr(hr, "CreateUploadBuffer")
    return buf

# ============================================================
# Helper: Create a default heap buffer
# ============================================================
def create_default_buffer(size, flags, initial_state):
    hp = D3D12_HEAP_PROPERTIES()
    hp.Type = D3D12_HEAP_TYPE_DEFAULT

    rd = D3D12_RESOURCE_DESC()
    rd.Dimension        = D3D12_RESOURCE_DIMENSION_BUFFER
    rd.Width            = size
    rd.Height           = 1
    rd.DepthOrArraySize = 1
    rd.MipLevels        = 1
    rd.SampleDesc.Count = 1
    rd.Layout           = D3D12_TEXTURE_LAYOUT_ROW_MAJOR
    rd.Flags            = flags

    buf = ctypes.c_void_p()
    create_res = com_method(g_device, 27, wintypes.HRESULT,
        (ctypes.c_void_p, ctypes.POINTER(D3D12_HEAP_PROPERTIES), wintypes.UINT,
         ctypes.POINTER(D3D12_RESOURCE_DESC), wintypes.UINT, ctypes.c_void_p,
         ctypes.POINTER(GUID), ctypes.POINTER(ctypes.c_void_p)))
    hr = create_res(g_device, ctypes.byref(hp), D3D12_HEAP_FLAG_NONE, ctypes.byref(rd),
                    initial_state, None,
                    ctypes.byref(IID_ID3D12Resource), ctypes.byref(buf))
    check_hr(hr, "CreateDefaultBuffer")
    return buf

# ============================================================
# Helper: Map, copy data, unmap
# ============================================================
def upload_to_buffer(resource, data, data_size):
    """Map a resource, copy data, unmap."""
    # ID3D12Resource::Map (index 8)
    map_fn = com_method(resource, 8, wintypes.HRESULT,
        (ctypes.c_void_p, wintypes.UINT, ctypes.c_void_p, ctypes.POINTER(ctypes.c_void_p)))
    ptr = ctypes.c_void_p()
    hr = map_fn(resource, 0, None, ctypes.byref(ptr))
    check_hr(hr, "Map")
    ctypes.memmove(ptr.value, data, data_size)
    # ID3D12Resource::Unmap (index 9)
    unmap_fn = com_method(resource, 9, None, (ctypes.c_void_p, wintypes.UINT, ctypes.c_void_p))
    unmap_fn(resource, 0, None)

# ============================================================
# Helper: Wait for GPU
# ============================================================
def wait_for_gpu():
    global g_fence_value
    g_fence_value += 1
    # ID3D12CommandQueue::Signal (index 14)
    signal_fn = com_method(g_command_queue, 14, wintypes.HRESULT,
        (ctypes.c_void_p, ctypes.c_void_p, ctypes.c_uint64))
    hr = signal_fn(g_command_queue, g_fence, g_fence_value)
    check_hr(hr, "Signal")
    # ID3D12Fence::GetCompletedValue (index 8)
    get_val = com_method(g_fence, 8, ctypes.c_uint64, (ctypes.c_void_p,))
    if get_val(g_fence) < g_fence_value:
        # ID3D12Fence::SetEventOnCompletion (index 9)
        set_evt = com_method(g_fence, 9, wintypes.HRESULT,
            (ctypes.c_void_p, ctypes.c_uint64, wintypes.HANDLE))
        hr = set_evt(g_fence, g_fence_value, g_fence_event)
        check_hr(hr, "SetEventOnCompletion")
        kernel32.WaitForSingleObject(g_fence_event, INFINITE)

# ============================================================
# Helper: Execute command list and wait
# ============================================================
def execute_and_wait():
    # Execute
    cmd_lists = (ctypes.c_void_p * 1)(g_command_list.value)
    exec_fn = com_method(g_command_queue, 10, None,
        (ctypes.c_void_p, wintypes.UINT, ctypes.POINTER(ctypes.c_void_p)))
    exec_fn(g_command_queue, 1, cmd_lists)
    wait_for_gpu()

# ============================================================
# Helper: Get CPU/GPU descriptor handle for heap start
# ============================================================
def get_cpu_handle(heap):
    """ID3D12DescriptorHeap::GetCPUDescriptorHandleForHeapStart (index 9)."""
    h = heap.value if isinstance(heap, ctypes.c_void_p) else heap
    # Use out-parameter ABI (works reliably with Python/ctypes across environments).
    fn = com_method(h, 9, None,
        (ctypes.c_void_p, ctypes.POINTER(D3D12_CPU_DESCRIPTOR_HANDLE)))
    handle = D3D12_CPU_DESCRIPTOR_HANDLE()
    fn(h, ctypes.byref(handle))
    return handle

def get_gpu_handle(heap):
    """ID3D12DescriptorHeap::GetGPUDescriptorHandleForHeapStart (index 10)."""
    h = heap.value if isinstance(heap, ctypes.c_void_p) else heap
    # Use out-parameter ABI (works reliably with Python/ctypes across environments).
    fn = com_method(h, 10, None,
        (ctypes.c_void_p, ctypes.POINTER(D3D12_GPU_DESCRIPTOR_HANDLE)))
    handle = D3D12_GPU_DESCRIPTOR_HANDLE()
    fn(h, ctypes.byref(handle))
    return handle

# ============================================================
# InitD3D12
# ============================================================
def init_d3d12():
    global g_factory, g_device, g_command_queue, g_command_alloc, g_command_list
    global g_swap_chain, g_rtv_heap, g_render_targets, g_rtv_desc_size, g_frame_index
    global g_fence, g_fence_value, g_fence_event, g_srv_uav_heap

    debug_print("InitD3D12: BEGIN")

    # Enable debug layer
    debug_if = ctypes.c_void_p()
    hr = D3D12GetDebugInterface(ctypes.byref(IID_ID3D12Debug), ctypes.byref(debug_if))
    if hr == 0 and debug_if:
        enable = com_method(debug_if, 3, None, (ctypes.c_void_p,))
        enable(debug_if)
        com_release(debug_if)
        debug_print("InitD3D12: Debug layer enabled")

    # Create DXGI factory
    hr = CreateDXGIFactory2(0, ctypes.byref(IID_IDXGIFactory4), ctypes.byref(g_factory))
    check_hr(hr, "CreateDXGIFactory2")

    # Enumerate adapters to find DXR-capable device
    found = False
    i = 0
    while True:
        adapter = ctypes.c_void_p()
        # IDXGIFactory1::EnumAdapters1 (index 12)
        enum_fn = com_method(g_factory, 12, wintypes.HRESULT,
            (ctypes.c_void_p, wintypes.UINT, ctypes.POINTER(ctypes.c_void_p)))
        hr = enum_fn(g_factory, i, ctypes.byref(adapter))
        if hr != 0:
            break
        i += 1

        # IDXGIAdapter1::GetDesc1 (index 10)
        desc = DXGI_ADAPTER_DESC1()
        get_desc = com_method(adapter, 10, wintypes.HRESULT,
            (ctypes.c_void_p, ctypes.POINTER(DXGI_ADAPTER_DESC1)))
        get_desc(adapter, ctypes.byref(desc))
        adapter_name = desc.Description

        if desc.Flags & DXGI_ADAPTER_FLAG_SOFTWARE:
            debug_print(f"InitD3D12: Adapter[{i-1}] '{adapter_name}' -> SKIP (software)")
            com_release(adapter)
            continue

        # Try creating D3D12 device
        temp_device = ctypes.c_void_p()
        hr = D3D12CreateDevice(adapter, D3D_FEATURE_LEVEL_12_1,
                               ctypes.byref(IID_ID3D12Device5), ctypes.byref(temp_device))
        com_release(adapter)

        if hr != 0:
            debug_print(f"InitD3D12: Adapter[{i-1}] '{adapter_name}' -> "
                        f"D3D12CreateDevice(FL12.1/Device5) failed: 0x{hr & 0xFFFFFFFF:08X}")
            continue

        # Check DXR support
        opts5 = D3D12_FEATURE_DATA_D3D12_OPTIONS5()
        # ID3D12Device::CheckFeatureSupport (index 13)
        check_feat = com_method(temp_device, 13, wintypes.HRESULT,
            (ctypes.c_void_p, wintypes.UINT, ctypes.c_void_p, wintypes.UINT))
        hr = check_feat(temp_device, D3D12_FEATURE_D3D12_OPTIONS5,
                        ctypes.byref(opts5), ctypes.sizeof(opts5))
        if hr == 0 and opts5.RaytracingTier >= D3D12_RAYTRACING_TIER_1_0:
            g_device = temp_device
            debug_print(f"InitD3D12: Adapter[{i-1}] '{adapter_name}' -> "
                        f"DXR OK (tier={opts5.RaytracingTier})")
            found = True
            break
        debug_print(f"InitD3D12: Adapter[{i-1}] '{adapter_name}' -> "
                    f"NO DXR (hr=0x{hr & 0xFFFFFFFF:08X}, tier={opts5.RaytracingTier})")
        com_release(temp_device)

    if not found:
        # Fallback to WARP
        debug_print("InitD3D12: No DXR GPU found, falling back to WARP")
        warp_adapter = ctypes.c_void_p()
        # IDXGIFactory4::EnumWarpAdapter (index 27)
        enum_warp = com_method(g_factory, 27, wintypes.HRESULT,
            (ctypes.c_void_p, ctypes.POINTER(GUID), ctypes.POINTER(ctypes.c_void_p)))
        hr = enum_warp(g_factory, ctypes.byref(IID_IDXGIAdapter), ctypes.byref(warp_adapter))
        check_hr(hr, "EnumWarpAdapter")
        hr = D3D12CreateDevice(warp_adapter, D3D_FEATURE_LEVEL_12_1,
                               ctypes.byref(IID_ID3D12Device5), ctypes.byref(g_device))
        com_release(warp_adapter)
        check_hr(hr, "D3D12CreateDevice (WARP)")

        opts5 = D3D12_FEATURE_DATA_D3D12_OPTIONS5()
        check_feat = com_method(g_device, 13, wintypes.HRESULT,
            (ctypes.c_void_p, wintypes.UINT, ctypes.c_void_p, wintypes.UINT))
        check_feat(g_device, D3D12_FEATURE_D3D12_OPTIONS5,
                   ctypes.byref(opts5), ctypes.sizeof(opts5))
        debug_print(f"InitD3D12: WARP RaytracingTier={opts5.RaytracingTier}")
        if opts5.RaytracingTier < D3D12_RAYTRACING_TIER_1_0:
            raise RuntimeError("WARP does not support DXR on this system.")

    debug_print("InitD3D12: D3D12 device created")

    # Create command queue
    queue_desc = D3D12_COMMAND_QUEUE_DESC()
    queue_desc.Type = D3D12_COMMAND_LIST_TYPE_DIRECT
    # ID3D12Device::CreateCommandQueue (index 8)
    create_cq = com_method(g_device, 8, wintypes.HRESULT,
        (ctypes.c_void_p, ctypes.POINTER(D3D12_COMMAND_QUEUE_DESC),
         ctypes.POINTER(GUID), ctypes.POINTER(ctypes.c_void_p)))
    hr = create_cq(g_device, ctypes.byref(queue_desc),
                   ctypes.byref(IID_ID3D12CommandQueue), ctypes.byref(g_command_queue))
    check_hr(hr, "CreateCommandQueue")

    # Create command allocator
    # ID3D12Device::CreateCommandAllocator (index 9)
    create_ca = com_method(g_device, 9, wintypes.HRESULT,
        (ctypes.c_void_p, wintypes.UINT, ctypes.POINTER(GUID), ctypes.POINTER(ctypes.c_void_p)))
    hr = create_ca(g_device, D3D12_COMMAND_LIST_TYPE_DIRECT,
                   ctypes.byref(IID_ID3D12CommandAllocator), ctypes.byref(g_command_alloc))
    check_hr(hr, "CreateCommandAllocator")

    # Create command list (base type), then QI to CommandList4 for DXR
    base_cmd_list = ctypes.c_void_p()
    # ID3D12Device::CreateCommandList (index 12)
    create_cl = com_method(g_device, 12, wintypes.HRESULT,
        (ctypes.c_void_p, wintypes.UINT, wintypes.UINT, ctypes.c_void_p, ctypes.c_void_p,
         ctypes.POINTER(GUID), ctypes.POINTER(ctypes.c_void_p)))
    hr = create_cl(g_device, 0, D3D12_COMMAND_LIST_TYPE_DIRECT, g_command_alloc, None,
                   ctypes.byref(IID_ID3D12GraphicsCommandList), ctypes.byref(base_cmd_list))
    check_hr(hr, "CreateCommandList")
    g_command_list = com_qi(base_cmd_list, IID_ID3D12GraphicsCommandList4)
    com_release(base_cmd_list)
    # Match C#/C flow: close the initially-open command list once.
    close_fn = com_method(g_command_list, 9, wintypes.HRESULT, (ctypes.c_void_p,))
    hr = close_fn(g_command_list)
    check_hr(hr, "Initial CommandList Close")
    debug_print("InitD3D12: Command allocator & list created (CommandList4)")

    # Create swap chain
    sc_desc = DXGI_SWAP_CHAIN_DESC1()
    sc_desc.Width       = WIDTH
    sc_desc.Height      = HEIGHT
    sc_desc.Format      = DXGI_FORMAT_R8G8B8A8_UNORM
    sc_desc.SampleDesc.Count = 1
    sc_desc.BufferUsage = DXGI_USAGE_RENDER_TARGET_OUTPUT
    sc_desc.BufferCount = FRAME_COUNT
    sc_desc.SwapEffect  = DXGI_SWAP_EFFECT_FLIP_DISCARD

    swap_temp = ctypes.c_void_p()
    # IDXGIFactory2::CreateSwapChainForHwnd (index 15)
    create_sc = com_method(g_factory, 15, wintypes.HRESULT,
        (ctypes.c_void_p, ctypes.c_void_p, wintypes.HWND,
         ctypes.POINTER(DXGI_SWAP_CHAIN_DESC1), ctypes.c_void_p, ctypes.c_void_p,
         ctypes.POINTER(ctypes.c_void_p)))
    hr = create_sc(g_factory, g_command_queue, g_hwnd,
                   ctypes.byref(sc_desc), None, None, ctypes.byref(swap_temp))
    check_hr(hr, "CreateSwapChainForHwnd")
    g_swap_chain = com_qi(swap_temp, IID_IDXGISwapChain3)
    com_release(swap_temp)

    # IDXGISwapChain3::GetCurrentBackBufferIndex (index 36)
    get_idx = com_method(g_swap_chain, 36, wintypes.UINT, (ctypes.c_void_p,))
    g_frame_index = get_idx(g_swap_chain)
    debug_print("InitD3D12: Swap chain created")

    # Create RTV descriptor heap
    rtv_heap_desc = D3D12_DESCRIPTOR_HEAP_DESC()
    rtv_heap_desc.NumDescriptors = FRAME_COUNT
    rtv_heap_desc.Type  = D3D12_DESCRIPTOR_HEAP_TYPE_RTV
    rtv_heap_desc.Flags = D3D12_DESCRIPTOR_HEAP_FLAG_NONE
    # ID3D12Device::CreateDescriptorHeap (index 14)
    create_dh = com_method(g_device, 14, wintypes.HRESULT,
        (ctypes.c_void_p, ctypes.POINTER(D3D12_DESCRIPTOR_HEAP_DESC),
         ctypes.POINTER(GUID), ctypes.POINTER(ctypes.c_void_p)))
    hr = create_dh(g_device, ctypes.byref(rtv_heap_desc),
                   ctypes.byref(IID_ID3D12DescriptorHeap), ctypes.byref(g_rtv_heap))
    check_hr(hr, "CreateDescriptorHeap (RTV)")

    # ID3D12Device::GetDescriptorHandleIncrementSize (index 15)
    get_inc = com_method(g_device, 15, wintypes.UINT, (ctypes.c_void_p, wintypes.UINT))
    g_rtv_desc_size = get_inc(g_device, D3D12_DESCRIPTOR_HEAP_TYPE_RTV)

    # Create render target views
    rtv_handle = get_cpu_handle(g_rtv_heap)
    debug_print(f"InitD3D12: RTV heap CPU handle=0x{rtv_handle.ptr:X}")
    for i in range(FRAME_COUNT):
        # IDXGISwapChain::GetBuffer (index 9)
        get_buf = com_method(g_swap_chain, 9, wintypes.HRESULT,
            (ctypes.c_void_p, wintypes.UINT, ctypes.POINTER(GUID), ctypes.POINTER(ctypes.c_void_p)))
        hr = get_buf(g_swap_chain, i, ctypes.byref(IID_ID3D12Resource), ctypes.byref(g_render_targets[i]))
        check_hr(hr, f"GetBuffer({i})")
        # ID3D12Device::CreateRenderTargetView (index 20)
        create_rtv = com_method(g_device, 20, None,
            (ctypes.c_void_p, ctypes.c_void_p, ctypes.c_void_p, D3D12_CPU_DESCRIPTOR_HANDLE))
        h = D3D12_CPU_DESCRIPTOR_HANDLE(rtv_handle.ptr + i * g_rtv_desc_size)
        create_rtv(g_device, g_render_targets[i], None, h)
    debug_print("InitD3D12: RTVs created")

    # Create fence
    # ID3D12Device::CreateFence (index 36)
    create_fence = com_method(g_device, 36, wintypes.HRESULT,
        (ctypes.c_void_p, ctypes.c_uint64, wintypes.UINT,
         ctypes.POINTER(GUID), ctypes.POINTER(ctypes.c_void_p)))
    hr = create_fence(g_device, 0, D3D12_FENCE_FLAG_NONE,
                      ctypes.byref(IID_ID3D12Fence), ctypes.byref(g_fence))
    check_hr(hr, "CreateFence")
    g_fence_event = kernel32.CreateEventW(None, False, False, None)

    # Create SRV/UAV descriptor heap (shader visible)
    srv_heap_desc = D3D12_DESCRIPTOR_HEAP_DESC()
    srv_heap_desc.NumDescriptors = 1
    srv_heap_desc.Type  = D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV
    srv_heap_desc.Flags = D3D12_DESCRIPTOR_HEAP_FLAG_SHADER_VISIBLE
    hr = create_dh(g_device, ctypes.byref(srv_heap_desc),
                   ctypes.byref(IID_ID3D12DescriptorHeap), ctypes.byref(g_srv_uav_heap))
    check_hr(hr, "CreateDescriptorHeap (SRV/UAV)")

    debug_print("InitD3D12: DONE")

# ============================================================
# CreateVertexBuffer
# ============================================================
def create_vertex_buffer():
    global g_vertex_buffer
    debug_print("CreateVertexBuffer: BEGIN")

    # Triangle vertices (position only: float3 x 3)
    vertices = (ctypes.c_float * 9)(
         0.0,  0.7, 0.0,  # top
        -0.7, -0.7, 0.0,  # bottom-left
         0.7, -0.7, 0.0,  # bottom-right
    )
    buf_size = ctypes.sizeof(vertices)
    g_vertex_buffer = create_upload_buffer(buf_size)
    upload_to_buffer(g_vertex_buffer, ctypes.addressof(vertices), buf_size)

    debug_print(f"CreateVertexBuffer: DONE ({buf_size} bytes)")

# ============================================================
# BuildAccelerationStructures
# ============================================================
def build_acceleration_structures():
    global g_bottom_level_as, g_top_level_as, g_instance_buffer
    global g_scratch_blas, g_scratch_tlas
    debug_print("BuildAccelerationStructures: BEGIN")

    # --- BLAS (Bottom-Level Acceleration Structure) ---
    geom_desc = D3D12_RAYTRACING_GEOMETRY_DESC()
    geom_desc.Type  = D3D12_RAYTRACING_GEOMETRY_TYPE_TRIANGLES
    geom_desc.Flags = D3D12_RAYTRACING_GEOMETRY_FLAG_OPAQUE
    geom_desc.u.Triangles.VertexBuffer.StartAddress  = get_gpu_va(g_vertex_buffer)
    geom_desc.u.Triangles.VertexBuffer.StrideInBytes  = ctypes.sizeof(ctypes.c_float) * 3
    geom_desc.u.Triangles.VertexFormat = DXGI_FORMAT_R32G32B32_FLOAT
    geom_desc.u.Triangles.VertexCount  = 3

    blas_inputs = D3D12_BUILD_RAYTRACING_ACCELERATION_STRUCTURE_INPUTS()
    blas_inputs.Type       = D3D12_RAYTRACING_ACCELERATION_STRUCTURE_TYPE_BOTTOM_LEVEL
    blas_inputs.DescsLayout = D3D12_ELEMENTS_LAYOUT_ARRAY
    blas_inputs.NumDescs   = 1
    blas_inputs.u.pGeometryDescs = ctypes.addressof(geom_desc)
    blas_inputs.Flags      = D3D12_RAYTRACING_ACCELERATION_STRUCTURE_BUILD_FLAG_PREFER_FAST_TRACE

    blas_prebuild = D3D12_RAYTRACING_ACCELERATION_STRUCTURE_PREBUILD_INFO()
    # ID3D12Device5::GetRaytracingAccelerationStructurePrebuildInfo (index 63)
    get_prebuild = com_method(g_device, 63, None,
        (ctypes.c_void_p,
         ctypes.POINTER(D3D12_BUILD_RAYTRACING_ACCELERATION_STRUCTURE_INPUTS),
         ctypes.POINTER(D3D12_RAYTRACING_ACCELERATION_STRUCTURE_PREBUILD_INFO)))
    get_prebuild(g_device, ctypes.byref(blas_inputs), ctypes.byref(blas_prebuild))
    debug_print(f"BLAS result={blas_prebuild.ResultDataMaxSizeInBytes} bytes, "
                f"scratch={blas_prebuild.ScratchDataSizeInBytes} bytes")

    g_bottom_level_as = create_default_buffer(
        blas_prebuild.ResultDataMaxSizeInBytes,
        D3D12_RESOURCE_FLAG_ALLOW_UNORDERED_ACCESS,
        D3D12_RESOURCE_STATE_RAYTRACING_ACCELERATION_STRUCTURE)
    g_scratch_blas = create_default_buffer(
        blas_prebuild.ScratchDataSizeInBytes,
        D3D12_RESOURCE_FLAG_ALLOW_UNORDERED_ACCESS,
        D3D12_RESOURCE_STATE_COMMON)

    blas_build_desc = D3D12_BUILD_RAYTRACING_ACCELERATION_STRUCTURE_DESC()
    blas_build_desc.Inputs = blas_inputs
    blas_build_desc.DestAccelerationStructureData    = get_gpu_va(g_bottom_level_as)
    blas_build_desc.ScratchAccelerationStructureData  = get_gpu_va(g_scratch_blas)

    debug_print(f"CommandList4 vtbl addr[72]=0x{com_method_addr(g_command_list, 72):X}, "
                f"[75]=0x{com_method_addr(g_command_list, 75):X}, "
                f"[76]=0x{com_method_addr(g_command_list, 76):X}")
    # ID3D12GraphicsCommandList4::BuildRaytracingAccelerationStructure (index 72)
    build_as = com_method(g_command_list, 72, None,
        (ctypes.c_void_p,
         ctypes.POINTER(D3D12_BUILD_RAYTRACING_ACCELERATION_STRUCTURE_DESC),
         wintypes.UINT, ctypes.c_void_p))
    reset_ca = com_method(g_command_alloc, 8, wintypes.HRESULT, (ctypes.c_void_p,))
    reset_cl = com_method(g_command_list, 10, wintypes.HRESULT,
        (ctypes.c_void_p, ctypes.c_void_p, ctypes.c_void_p))
    close_fn = com_method(g_command_list, 9, wintypes.HRESULT, (ctypes.c_void_p,))

    hr = reset_ca(g_command_alloc)
    check_hr(hr, "Allocator Reset (BLAS)")
    hr = reset_cl(g_command_list, g_command_alloc, None)
    check_hr(hr, "CommandList Reset (BLAS)")

    build_as(g_command_list, ctypes.byref(blas_build_desc), 0, None)

    # UAV barrier between BLAS and TLAS builds
    uav_barrier = D3D12_RESOURCE_BARRIER()
    uav_barrier.Type = D3D12_RESOURCE_BARRIER_TYPE_UAV
    uav_barrier.u.UAV.pResource = g_bottom_level_as.value
    # ID3D12GraphicsCommandList::ResourceBarrier (index 26)
    res_barrier = com_method(g_command_list, 26, None,
        (ctypes.c_void_p, wintypes.UINT, ctypes.POINTER(D3D12_RESOURCE_BARRIER)))
    res_barrier(g_command_list, 1, ctypes.byref(uav_barrier))
    hr = close_fn(g_command_list)
    check_hr(hr, "Close (BLAS)")
    execute_and_wait()

    # --- TLAS (Top-Level Acceleration Structure) ---
    inst_desc = D3D12_RAYTRACING_INSTANCE_DESC()
    ctypes.memset(ctypes.byref(inst_desc), 0, ctypes.sizeof(inst_desc))
    # Identity transform
    inst_desc.Transform[0][0] = 1.0
    inst_desc.Transform[1][1] = 1.0
    inst_desc.Transform[2][2] = 1.0
    # InstanceID=0 (bits 0-23), InstanceMask=0xFF (bits 24-31)
    inst_desc.InstanceID_and_Mask = 0xFF000000
    inst_desc.AccelerationStructure = get_gpu_va(g_bottom_level_as)

    g_instance_buffer = create_upload_buffer(ctypes.sizeof(inst_desc))
    upload_to_buffer(g_instance_buffer, ctypes.addressof(inst_desc), ctypes.sizeof(inst_desc))

    tlas_inputs = D3D12_BUILD_RAYTRACING_ACCELERATION_STRUCTURE_INPUTS()
    tlas_inputs.Type        = D3D12_RAYTRACING_ACCELERATION_STRUCTURE_TYPE_TOP_LEVEL
    tlas_inputs.DescsLayout  = D3D12_ELEMENTS_LAYOUT_ARRAY
    tlas_inputs.NumDescs    = 1
    tlas_inputs.u.InstanceDescs = get_gpu_va(g_instance_buffer)
    tlas_inputs.Flags       = D3D12_RAYTRACING_ACCELERATION_STRUCTURE_BUILD_FLAG_PREFER_FAST_TRACE

    tlas_prebuild = D3D12_RAYTRACING_ACCELERATION_STRUCTURE_PREBUILD_INFO()
    get_prebuild(g_device, ctypes.byref(tlas_inputs), ctypes.byref(tlas_prebuild))
    debug_print(f"TLAS result={tlas_prebuild.ResultDataMaxSizeInBytes} bytes, "
                f"scratch={tlas_prebuild.ScratchDataSizeInBytes} bytes")

    g_top_level_as = create_default_buffer(
        tlas_prebuild.ResultDataMaxSizeInBytes,
        D3D12_RESOURCE_FLAG_ALLOW_UNORDERED_ACCESS,
        D3D12_RESOURCE_STATE_RAYTRACING_ACCELERATION_STRUCTURE)
    g_scratch_tlas = create_default_buffer(
        tlas_prebuild.ScratchDataSizeInBytes,
        D3D12_RESOURCE_FLAG_ALLOW_UNORDERED_ACCESS,
        D3D12_RESOURCE_STATE_COMMON)

    tlas_build_desc = D3D12_BUILD_RAYTRACING_ACCELERATION_STRUCTURE_DESC()
    tlas_build_desc.Inputs = tlas_inputs
    tlas_build_desc.DestAccelerationStructureData    = get_gpu_va(g_top_level_as)
    tlas_build_desc.ScratchAccelerationStructureData  = get_gpu_va(g_scratch_tlas)

    hr = reset_ca(g_command_alloc)
    check_hr(hr, "Allocator Reset (TLAS)")
    hr = reset_cl(g_command_list, g_command_alloc, None)
    check_hr(hr, "CommandList Reset (TLAS)")
    build_as(g_command_list, ctypes.byref(tlas_build_desc), 0, None)
    uav_barrier.u.UAV.pResource = g_top_level_as.value
    res_barrier(g_command_list, 1, ctypes.byref(uav_barrier))
    hr = close_fn(g_command_list)
    check_hr(hr, "Close (TLAS)")
    execute_and_wait()
    debug_print("BuildAccelerationStructures: DONE")

# ============================================================
# CreateRootSignature
# ============================================================
def create_root_signature():
    global g_global_root_sig
    debug_print("CreateRootSignature: BEGIN")

    # Layout:
    #   [0] UAV  - output texture (u0) via descriptor table
    #   [1] SRV  - acceleration structure (t0) via root SRV

    ranges = (D3D12_DESCRIPTOR_RANGE * 1)()
    ranges[0].RangeType          = D3D12_DESCRIPTOR_RANGE_TYPE_UAV
    ranges[0].NumDescriptors     = 1
    ranges[0].BaseShaderRegister = 0

    params = (D3D12_ROOT_PARAMETER * 2)()

    # [0] UAV (descriptor table)
    params[0].ParameterType = D3D12_ROOT_PARAMETER_TYPE_DESCRIPTOR_TABLE
    params[0].u.DescriptorTable.NumDescriptorRanges = 1
    params[0].u.DescriptorTable.pDescriptorRanges   = ctypes.addressof(ranges)

    # [1] SRV (root SRV for acceleration structure)
    params[1].ParameterType = D3D12_ROOT_PARAMETER_TYPE_SRV
    params[1].u.Descriptor.ShaderRegister = 0

    rs_desc = D3D12_ROOT_SIGNATURE_DESC()
    rs_desc.NumParameters = 2
    rs_desc.pParameters   = ctypes.addressof(params)

    rs_blob  = ctypes.c_void_p()
    err_blob = ctypes.c_void_p()
    hr = D3D12SerializeRootSignature(ctypes.byref(rs_desc), D3D_ROOT_SIGNATURE_VERSION_1,
                                     ctypes.byref(rs_blob), ctypes.byref(err_blob))
    if hr != 0:
        msg = "D3D12SerializeRootSignature failed"
        if err_blob:
            p = blob_ptr(err_blob)
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
    hr = create_rs(g_device, 0, blob_ptr(rs_blob), blob_size(rs_blob),
                   ctypes.byref(IID_ID3D12RootSignature), ctypes.byref(g_global_root_sig))
    com_release(rs_blob)
    check_hr(hr, "CreateRootSignature")

    debug_print("CreateRootSignature: DONE")

# ============================================================
# CreateRaytracingPipeline - Compile shader with DXC, create state object
# ============================================================
def create_raytracing_pipeline():
    global g_state_object
    debug_print("CreateRaytracingPipeline: BEGIN")

    # Create DXC instances
    dxc_utils = ctypes.c_void_p()
    dxc_compiler = ctypes.c_void_p()
    hr = DxcCreateInstance(ctypes.byref(CLSID_DxcUtils), ctypes.byref(IID_IDxcUtils),
                           ctypes.byref(dxc_utils))
    check_hr(hr, "DxcCreateInstance(Utils)")
    hr = DxcCreateInstance(ctypes.byref(CLSID_DxcCompiler), ctypes.byref(IID_IDxcCompiler3),
                           ctypes.byref(dxc_compiler))
    check_hr(hr, "DxcCreateInstance(Compiler)")

    # Load HLSL from file
    # IDxcUtils::LoadFile (index 7)
    source_blob = ctypes.c_void_p()
    load_file = com_method(dxc_utils, 7, wintypes.HRESULT,
        (ctypes.c_void_p, ctypes.c_wchar_p, ctypes.c_void_p, ctypes.POINTER(ctypes.c_void_p)))
    hr = load_file(dxc_utils, "hello.hlsl", None, ctypes.byref(source_blob))
    check_hr(hr, "LoadFile(hello.hlsl)")
    debug_print("CreateRaytracingPipeline: HLSL loaded from hello.hlsl")

    # Compile with DXC (lib_6_3 for raytracing library)
    # Build DxcBuffer on the stack (Ptr, Size, Encoding = 3 fields)
    src_ptr  = blob_ptr(source_blob)
    src_size = blob_size(source_blob)

    # DxcBuffer as raw bytes: void* Ptr (8), SIZE_T Size (8), UINT Encoding (4+pad)
    dxc_buffer = (ctypes.c_ubyte * 24)()
    struct.pack_into('<Q', dxc_buffer, 0,  src_ptr)
    struct.pack_into('<Q', dxc_buffer, 8,  src_size)
    struct.pack_into('<I', dxc_buffer, 16, 0)  # Let DXC detect encoding

    args = (ctypes.c_wchar_p * 2)(
        "-T", "lib_6_3",
    )

    result = ctypes.c_void_p()
    # IDxcCompiler3::Compile (index 3)
    compile_fn = com_method(dxc_compiler, 3, wintypes.HRESULT,
        (ctypes.c_void_p,       # this
         ctypes.c_void_p,       # pSource (DxcBuffer*)
         ctypes.POINTER(ctypes.c_wchar_p),  # pArguments
         ctypes.c_uint32,       # argCount
         ctypes.c_void_p,       # pIncludeHandler
         ctypes.POINTER(GUID),  # riid
         ctypes.POINTER(ctypes.c_void_p)))  # ppResult
    debug_print("CreateRaytracingPipeline: Compiling HLSL with DXC (lib_6_3)...")
    hr = compile_fn(dxc_compiler, ctypes.addressof(dxc_buffer), args, 2,
                    None, ctypes.byref(IID_IDxcResult), ctypes.byref(result))
    check_hr(hr, "Compile")

    # Check for errors
    # IDxcResult::GetOutput (index 7)
    get_output = com_method(result, 7, wintypes.HRESULT,
        (ctypes.c_void_p, ctypes.c_uint32, ctypes.POINTER(GUID),
         ctypes.POINTER(ctypes.c_void_p), ctypes.POINTER(ctypes.c_void_p)))

    errors = ctypes.c_void_p()
    get_output(result, DXC_OUT_ERRORS, ctypes.byref(IID_IDxcBlobUtf8),
               ctypes.byref(errors), None)
    if errors and errors.value:
        # IDxcBlobUtf8::GetStringLength (index 7)
        get_str_len = com_method(errors, 7, ctypes.c_size_t, (ctypes.c_void_p,))
        str_len = get_str_len(errors)
        if str_len > 0:
            # IDxcBlobUtf8::GetStringPointer (index 6)
            get_str_ptr = com_method(errors, 6, ctypes.c_char_p, (ctypes.c_void_p,))
            err_str = get_str_ptr(errors)
            debug_print(f"Shader compile output: {err_str.decode('utf-8', 'replace')}")

    # Check compile status
    # IDxcResult::GetStatus (index 3)
    get_status = com_method(result, 3, wintypes.HRESULT,
        (ctypes.c_void_p, ctypes.POINTER(wintypes.HRESULT)))
    compile_status = wintypes.HRESULT()
    get_status(result, ctypes.byref(compile_status))
    if compile_status.value != 0 and compile_status.value < 0:
        raise RuntimeError(f"Shader compilation FAILED: 0x{compile_status.value & 0xFFFFFFFF:08X}")

    # Get compiled shader blob
    shader_blob = ctypes.c_void_p()
    get_output(result, DXC_OUT_OBJECT, ctypes.byref(IID_IDxcBlob),
               ctypes.byref(shader_blob), None)
    debug_print(f"Shader compiled OK ({blob_size(shader_blob)} bytes)")

    # --- Build State Object (raytracing pipeline) ---
    # Keep all desc structures alive until CreateStateObject returns

    # Subobject 0: DXIL Library
    lib_desc = D3D12_DXIL_LIBRARY_DESC()
    lib_desc.DXILLibrary.pShaderBytecode = blob_ptr(shader_blob)
    lib_desc.DXILLibrary.BytecodeLength  = blob_size(shader_blob)
    lib_desc.NumExports = 0  # export all

    # Subobject 1: Hit Group
    hit_group_desc = D3D12_HIT_GROUP_DESC()
    hit_group_desc.HitGroupExport         = "HitGroup"
    hit_group_desc.ClosestHitShaderImport = "ClosestHit"
    hit_group_desc.Type                   = D3D12_HIT_GROUP_TYPE_TRIANGLES

    # Subobject 2: Shader Config
    shader_config = D3D12_RAYTRACING_SHADER_CONFIG()
    shader_config.MaxPayloadSizeInBytes   = ctypes.sizeof(ctypes.c_float) * 4  # float4
    shader_config.MaxAttributeSizeInBytes = ctypes.sizeof(ctypes.c_float) * 2  # float2

    # Subobject 3: Global Root Signature
    global_rs_desc = D3D12_GLOBAL_ROOT_SIGNATURE()
    global_rs_desc.pGlobalRootSignature = g_global_root_sig.value

    # Subobject 4: Pipeline Config
    pipeline_config = D3D12_RAYTRACING_PIPELINE_CONFIG()
    pipeline_config.MaxTraceRecursionDepth = 1

    subobjects = (D3D12_STATE_SUBOBJECT * 5)()

    subobjects[0].Type  = D3D12_STATE_SUBOBJECT_TYPE_DXIL_LIBRARY
    subobjects[0].pDesc = ctypes.addressof(lib_desc)

    subobjects[1].Type  = D3D12_STATE_SUBOBJECT_TYPE_HIT_GROUP
    subobjects[1].pDesc = ctypes.addressof(hit_group_desc)

    subobjects[2].Type  = D3D12_STATE_SUBOBJECT_TYPE_RAYTRACING_SHADER_CONFIG
    subobjects[2].pDesc = ctypes.addressof(shader_config)

    subobjects[3].Type  = D3D12_STATE_SUBOBJECT_TYPE_GLOBAL_ROOT_SIGNATURE
    subobjects[3].pDesc = ctypes.addressof(global_rs_desc)

    subobjects[4].Type  = D3D12_STATE_SUBOBJECT_TYPE_RAYTRACING_PIPELINE_CONFIG
    subobjects[4].pDesc = ctypes.addressof(pipeline_config)
    debug_print(f"CreateRaytracingPipeline: StateSubobjectTypes="
                f"[{subobjects[0].Type},{subobjects[1].Type},{subobjects[2].Type},{subobjects[3].Type},{subobjects[4].Type}]")

    state_obj_desc = D3D12_STATE_OBJECT_DESC()
    state_obj_desc.Type          = D3D12_STATE_OBJECT_TYPE_RAYTRACING_PIPELINE
    state_obj_desc.NumSubobjects = 5
    state_obj_desc.pSubobjects   = ctypes.addressof(subobjects)
    debug_print(f"CreateRaytracingPipeline: sizeof(STATE_OBJECT_DESC)={ctypes.sizeof(D3D12_STATE_OBJECT_DESC)}, "
                f"sizeof(STATE_SUBOBJECT)={ctypes.sizeof(D3D12_STATE_SUBOBJECT)}")

    # ID3D12Device5::CreateStateObject (index 62)
    create_so = com_method(g_device, 62, wintypes.HRESULT,
        (ctypes.c_void_p, ctypes.POINTER(D3D12_STATE_OBJECT_DESC),
         ctypes.POINTER(GUID), ctypes.POINTER(ctypes.c_void_p)))
    debug_print(f"Creating state object (5 subobjects)...")
    hr = create_so(g_device, ctypes.byref(state_obj_desc),
                   ctypes.byref(IID_ID3D12StateObject), ctypes.byref(g_state_object))
    check_hr(hr, "CreateStateObject")

    debug_print("CreateRaytracingPipeline: DONE")

    # Cleanup DXC objects
    com_release(shader_blob)
    com_release(errors)
    com_release(result)
    com_release(source_blob)
    com_release(dxc_compiler)
    com_release(dxc_utils)

# ============================================================
# CreateOutputResource - UAV texture for raytracing output
# ============================================================
def create_output_resource():
    global g_output_resource
    debug_print("CreateOutputResource: BEGIN")

    tex_desc = D3D12_RESOURCE_DESC()
    tex_desc.Dimension        = D3D12_RESOURCE_DIMENSION_TEXTURE2D
    tex_desc.Width            = WIDTH
    tex_desc.Height           = HEIGHT
    tex_desc.DepthOrArraySize = 1
    tex_desc.MipLevels        = 1
    tex_desc.Format           = DXGI_FORMAT_R8G8B8A8_UNORM
    tex_desc.SampleDesc.Count = 1
    tex_desc.Flags            = D3D12_RESOURCE_FLAG_ALLOW_UNORDERED_ACCESS

    hp = D3D12_HEAP_PROPERTIES()
    hp.Type = D3D12_HEAP_TYPE_DEFAULT

    create_res = com_method(g_device, 27, wintypes.HRESULT,
        (ctypes.c_void_p, ctypes.POINTER(D3D12_HEAP_PROPERTIES), wintypes.UINT,
         ctypes.POINTER(D3D12_RESOURCE_DESC), wintypes.UINT, ctypes.c_void_p,
         ctypes.POINTER(GUID), ctypes.POINTER(ctypes.c_void_p)))
    hr = create_res(g_device, ctypes.byref(hp), D3D12_HEAP_FLAG_NONE, ctypes.byref(tex_desc),
                    D3D12_RESOURCE_STATE_UNORDERED_ACCESS, None,
                    ctypes.byref(IID_ID3D12Resource), ctypes.byref(g_output_resource))
    check_hr(hr, "CreateOutputResource")

    # Create UAV descriptor
    cpu_handle = get_cpu_handle(g_srv_uav_heap)
    debug_print(f"CreateOutputResource: SRV/UAV heap CPU handle=0x{cpu_handle.ptr:X}")
    debug_print(
        f"CreateOutputResource: sizeof(BUFFER_UAV)={ctypes.sizeof(D3D12_BUFFER_UAV)}, "
        f"sizeof(UAV_DESC)={ctypes.sizeof(D3D12_UNORDERED_ACCESS_VIEW_DESC)}")
    # ID3D12Device::CreateUnorderedAccessView (index 19)
    create_uav = com_method(g_device, 19, None,
        (ctypes.c_void_p, ctypes.c_void_p, ctypes.c_void_p,
         ctypes.POINTER(D3D12_UNORDERED_ACCESS_VIEW_DESC), D3D12_CPU_DESCRIPTOR_HANDLE))
    # Use default UAV desc for the resource to avoid struct ABI mismatch issues.
    create_uav(g_device, g_output_resource, None, None, cpu_handle)

    debug_print("CreateOutputResource: DONE")

# ============================================================
# CreateShaderTable
# ============================================================
def create_shader_table():
    global g_shader_table
    debug_print("CreateShaderTable: BEGIN")

    # Get shader identifiers from state object properties
    state_props = com_qi(g_state_object, IID_ID3D12StateObjectProperties)

    # ID3D12StateObjectProperties::GetShaderIdentifier (index 3)
    get_id = com_method(state_props, 3, ctypes.c_void_p, (ctypes.c_void_p, ctypes.c_wchar_p))
    ray_gen_id = get_id(state_props, "RayGen")
    miss_id    = get_id(state_props, "Miss")
    hit_id     = get_id(state_props, "HitGroup")

    if not ray_gen_id or not miss_id or not hit_id:
        raise RuntimeError("Failed to get shader identifiers")

    shader_id_size = D3D12_SHADER_IDENTIFIER_SIZE_IN_BYTES  # 32
    record_size    = align_up(shader_id_size, D3D12_RAYTRACING_SHADER_TABLE_BYTE_ALIGNMENT)  # 64
    table_size     = record_size * 3

    g_shader_table = create_upload_buffer(table_size)

    # Map and fill
    map_fn = com_method(g_shader_table, 8, wintypes.HRESULT,
        (ctypes.c_void_p, wintypes.UINT, ctypes.c_void_p, ctypes.POINTER(ctypes.c_void_p)))
    ptr = ctypes.c_void_p()
    hr = map_fn(g_shader_table, 0, None, ctypes.byref(ptr))
    check_hr(hr, "Map shader table")

    # Clear table to zero
    ctypes.memset(ptr.value, 0, table_size)

    # Copy shader identifiers
    ctypes.memmove(ptr.value + record_size * 0, ray_gen_id, shader_id_size)
    ctypes.memmove(ptr.value + record_size * 1, miss_id,    shader_id_size)
    ctypes.memmove(ptr.value + record_size * 2, hit_id,     shader_id_size)

    unmap_fn = com_method(g_shader_table, 9, None, (ctypes.c_void_p, wintypes.UINT, ctypes.c_void_p))
    unmap_fn(g_shader_table, 0, None)

    com_release(state_props)

    debug_print(f"CreateShaderTable: DONE (recordSize={record_size}, tableSize={table_size})")

# ============================================================
# Render
# ============================================================
def render():
    global g_frame_index

    # Reset command allocator and command list
    reset_ca = com_method(g_command_alloc, 8, wintypes.HRESULT, (ctypes.c_void_p,))
    hr = reset_ca(g_command_alloc)
    check_hr(hr, "Allocator Reset")

    reset_cl = com_method(g_command_list, 10, wintypes.HRESULT,
        (ctypes.c_void_p, ctypes.c_void_p, ctypes.c_void_p))
    hr = reset_cl(g_command_list, g_command_alloc, None)
    check_hr(hr, "CommandList Reset")

    # Set descriptor heap
    heaps = (ctypes.c_void_p * 1)(g_srv_uav_heap.value)
    # ID3D12GraphicsCommandList::SetDescriptorHeaps (index 28)
    set_heaps = com_method(g_command_list, 28, None,
        (ctypes.c_void_p, wintypes.UINT, ctypes.POINTER(ctypes.c_void_p)))
    set_heaps(g_command_list, 1, heaps)

    # Set global root signature and parameters
    # ID3D12GraphicsCommandList::SetComputeRootSignature (index 29)
    set_rs = com_method(g_command_list, 29, None, (ctypes.c_void_p, ctypes.c_void_p))
    set_rs(g_command_list, g_global_root_sig)

    gpu_handle = get_gpu_handle(g_srv_uav_heap)
    debug_print(f"Render: SRV/UAV heap GPU handle=0x{gpu_handle.ptr:X}")
    # ID3D12GraphicsCommandList::SetComputeRootDescriptorTable (index 31)
    set_table = com_method(g_command_list, 31, None,
        (ctypes.c_void_p, wintypes.UINT, D3D12_GPU_DESCRIPTOR_HANDLE))
    set_table(g_command_list, 0, gpu_handle)  # UAV

    # ID3D12GraphicsCommandList::SetComputeRootShaderResourceView (index 39)
    set_srv = com_method(g_command_list, 39, None,
        (ctypes.c_void_p, wintypes.UINT, ctypes.c_uint64))
    set_srv(g_command_list, 1, get_gpu_va(g_top_level_as))  # TLAS

    # Set pipeline state object
    # ID3D12GraphicsCommandList4::SetPipelineState1 (index 75)
    set_pso = com_method(g_command_list, 75, None, (ctypes.c_void_p, ctypes.c_void_p))
    set_pso(g_command_list, g_state_object)

    # DispatchRays
    record_size = align_up(D3D12_SHADER_IDENTIFIER_SIZE_IN_BYTES,
                           D3D12_RAYTRACING_SHADER_TABLE_BYTE_ALIGNMENT)
    table_gpu = get_gpu_va(g_shader_table)

    dispatch_desc = D3D12_DISPATCH_RAYS_DESC()
    ctypes.memset(ctypes.byref(dispatch_desc), 0, ctypes.sizeof(dispatch_desc))

    dispatch_desc.RayGenerationShaderRecord.StartAddress = table_gpu + record_size * 0
    dispatch_desc.RayGenerationShaderRecord.SizeInBytes  = record_size

    dispatch_desc.MissShaderTable.StartAddress  = table_gpu + record_size * 1
    dispatch_desc.MissShaderTable.SizeInBytes   = record_size
    dispatch_desc.MissShaderTable.StrideInBytes  = record_size

    dispatch_desc.HitGroupTable.StartAddress  = table_gpu + record_size * 2
    dispatch_desc.HitGroupTable.SizeInBytes   = record_size
    dispatch_desc.HitGroupTable.StrideInBytes  = record_size

    dispatch_desc.Width  = WIDTH
    dispatch_desc.Height = HEIGHT
    dispatch_desc.Depth  = 1

    # ID3D12GraphicsCommandList4::DispatchRays (index 76)
    dispatch_rays = com_method(g_command_list, 76, None,
        (ctypes.c_void_p, ctypes.POINTER(D3D12_DISPATCH_RAYS_DESC)))
    dispatch_rays(g_command_list, ctypes.byref(dispatch_desc))

    # Copy output texture to back buffer
    barriers = (D3D12_RESOURCE_BARRIER * 2)()

    # Output texture: UAV -> COPY_SOURCE
    barriers[0].Type  = D3D12_RESOURCE_BARRIER_TYPE_TRANSITION
    barriers[0].Flags = D3D12_RESOURCE_BARRIER_FLAG_NONE
    barriers[0].u.Transition.pResource   = g_output_resource.value
    barriers[0].u.Transition.StateBefore = D3D12_RESOURCE_STATE_UNORDERED_ACCESS
    barriers[0].u.Transition.StateAfter  = D3D12_RESOURCE_STATE_COPY_SOURCE
    barriers[0].u.Transition.Subresource = D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES

    # Back buffer: PRESENT -> COPY_DEST
    barriers[1].Type  = D3D12_RESOURCE_BARRIER_TYPE_TRANSITION
    barriers[1].Flags = D3D12_RESOURCE_BARRIER_FLAG_NONE
    barriers[1].u.Transition.pResource   = g_render_targets[g_frame_index].value
    barriers[1].u.Transition.StateBefore = D3D12_RESOURCE_STATE_PRESENT
    barriers[1].u.Transition.StateAfter  = D3D12_RESOURCE_STATE_COPY_DEST
    barriers[1].u.Transition.Subresource = D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES

    res_barrier = com_method(g_command_list, 26, None,
        (ctypes.c_void_p, wintypes.UINT, ctypes.POINTER(D3D12_RESOURCE_BARRIER)))
    res_barrier(g_command_list, 2, barriers)

    # ID3D12GraphicsCommandList::CopyResource (index 17)
    copy_res = com_method(g_command_list, 17, None,
        (ctypes.c_void_p, ctypes.c_void_p, ctypes.c_void_p))
    copy_res(g_command_list, g_render_targets[g_frame_index], g_output_resource)

    # Restore states
    barriers[0].u.Transition.StateBefore = D3D12_RESOURCE_STATE_COPY_SOURCE
    barriers[0].u.Transition.StateAfter  = D3D12_RESOURCE_STATE_UNORDERED_ACCESS
    barriers[1].u.Transition.StateBefore = D3D12_RESOURCE_STATE_COPY_DEST
    barriers[1].u.Transition.StateAfter  = D3D12_RESOURCE_STATE_PRESENT
    res_barrier(g_command_list, 2, barriers)

    # Close
    close_fn = com_method(g_command_list, 9, wintypes.HRESULT, (ctypes.c_void_p,))
    hr = close_fn(g_command_list)
    check_hr(hr, "Close")

    # Execute
    cmd_lists = (ctypes.c_void_p * 1)(g_command_list.value)
    exec_fn = com_method(g_command_queue, 10, None,
        (ctypes.c_void_p, wintypes.UINT, ctypes.POINTER(ctypes.c_void_p)))
    exec_fn(g_command_queue, 1, cmd_lists)

    # Present
    # IDXGISwapChain::Present (index 8)
    present = com_method(g_swap_chain, 8, wintypes.HRESULT,
        (ctypes.c_void_p, wintypes.UINT, wintypes.UINT))
    hr = present(g_swap_chain, 1, 0)
    check_hr(hr, "Present")

    wait_for_gpu()

    # IDXGISwapChain3::GetCurrentBackBufferIndex (index 36)
    get_idx = com_method(g_swap_chain, 36, wintypes.UINT, (ctypes.c_void_p,))
    g_frame_index = get_idx(g_swap_chain)

# ============================================================
# Cleanup
# ============================================================
def cleanup():
    for obj in [g_shader_table, g_output_resource, g_srv_uav_heap, g_global_root_sig,
                g_state_object, g_instance_buffer, g_top_level_as, g_bottom_level_as,
                g_scratch_blas, g_scratch_tlas, g_vertex_buffer, g_fence,
                g_command_list, g_command_alloc]:
        com_release(obj)
    for rt in g_render_targets:
        com_release(rt)
    for obj in [g_rtv_heap, g_swap_chain, g_command_queue, g_device, g_factory]:
        com_release(obj)

# ============================================================
# Window procedure
# ============================================================
@WNDPROC
def wndproc(hwnd, msg, wparam, lparam):
    if msg == WM_KEYDOWN:
        if wparam == VK_ESCAPE:
            user32.PostQuitMessage(0)
        return 0
    if msg == WM_DESTROY:
        user32.PostQuitMessage(0)
        return 0
    return user32.DefWindowProcW(hwnd, msg, wparam, lparam)

# ============================================================
# Main
# ============================================================
def main():
    global g_hwnd

    debug_print("====== DXR Triangle Sample (Python) START ======")
    debug_print(f"Python {sys.version}, {'64' if sys.maxsize > 2**32 else '32'}-bit")

    ole32.CoInitialize(None)

    hInstance = kernel32.GetModuleHandleW(None)

    wc = WNDCLASSEXW()
    wc.cbSize       = ctypes.sizeof(WNDCLASSEXW)
    wc.style        = CS_HREDRAW | CS_VREDRAW
    wc.lpfnWndProc  = wndproc
    wc.hInstance     = hInstance
    wc.hCursor       = user32.LoadCursorW(None, wintypes.LPCWSTR(IDC_ARROW))
    wc.lpszClassName = "DXRTrianglePy"

    if not user32.RegisterClassExW(ctypes.byref(wc)):
        raise winerr()

    rc = RECT(0, 0, WIDTH, HEIGHT)
    user32.AdjustWindowRect(ctypes.byref(rc), WS_OVERLAPPEDWINDOW, False)

    g_hwnd = user32.CreateWindowExW(
        0, "DXRTrianglePy", "DXR Triangle Sample (Python)",
        WS_OVERLAPPEDWINDOW,
        CW_USEDEFAULT, CW_USEDEFAULT,
        rc.right - rc.left, rc.bottom - rc.top,
        None, None, hInstance, None)
    if not g_hwnd:
        raise winerr()

    user32.ShowWindow(g_hwnd, SW_SHOW)

    # Initialize
    init_d3d12()
    create_vertex_buffer()
    build_acceleration_structures()
    create_root_signature()
    create_raytracing_pipeline()
    create_output_resource()
    create_shader_table()

    # Close the command list before entering the render loop
    close_fn = com_method(g_command_list, 9, wintypes.HRESULT, (ctypes.c_void_p,))
    close_fn(g_command_list)

    debug_print("====== Initialization COMPLETE - entering render loop ======")

    # Message loop
    msg = MSG()
    while True:
        if user32.PeekMessageW(ctypes.byref(msg), None, 0, 0, PM_REMOVE):
            if msg.message == WM_QUIT:
                break
            user32.TranslateMessage(ctypes.byref(msg))
            user32.DispatchMessageW(ctypes.byref(msg))
        else:
            render()

    wait_for_gpu()
    if g_fence_event:
        kernel32.CloseHandle(g_fence_event)
    cleanup()

    ole32.CoUninitialize()
    debug_print("====== DXR Triangle Sample (Python) END ======")

if __name__ == "__main__":
    main()
