$source = @"
using System;
using System.Numerics;
using System.Runtime.InteropServices;
using System.Collections.Generic;
using System.Text;

public class Hello
{
    [StructLayout(LayoutKind.Sequential)]
    public struct POINT
    {
        public int X;
        public int Y;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct MSG
    {
        public IntPtr hwnd;
        public uint message;
        public IntPtr wParam;
        public IntPtr lParam;
        public uint time;
        public POINT pt;
    }

    delegate IntPtr WndProcDelegate(IntPtr hWnd, uint uMsg, IntPtr wParam, IntPtr lParam);
    
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Auto)]
    struct WNDCLASSEX
    {
        public uint cbSize;
        public uint style;
        public WndProcDelegate lpfnWndProc;
        public Int32 cbClsExtra;
        public Int32 cbWndExtra;
        public IntPtr hInstance;
        public IntPtr hIcon;
        public IntPtr hCursor;
        public IntPtr hbrBackground;
        public string lpszMenuName;
        public string lpszClassName;
        public IntPtr hIconSm;
    }

    [StructLayout(LayoutKind.Sequential)]
    struct RECT
    {
        public int Left;
        public int Top;
        public int Right;
        public int Bottom;
    }
 
    [StructLayout(LayoutKind.Sequential)]
    struct PAINTSTRUCT
    {
        public IntPtr hdc;
        public int fErase;
        public RECT rcPaint;
        public int fRestore;
        public int fIncUpdate;
        [MarshalAs(UnmanagedType.ByValArray, SizeConst = 32)]
        public byte[] rgbReserved;
    }
 
    const uint WS_OVERLAPPEDWINDOW = 0x0CF0000;
    const uint WS_VISIBLE = 0x10000000;

    const uint WM_CREATE = 0x0001;
    const uint WM_DESTROY = 0x0002;
    const uint WM_PAINT = 0x000F;
    const uint WM_CLOSE = 0x0010;
    const uint WM_COMMAND = 0x0111;

    const uint WM_QUIT = 0x0012;
    const uint PM_REMOVE = 0x0001;

    const uint CS_OWNDC = 0x0020;

    const int IDC_ARROW = 32512;

    const uint INFINITE = 0xFFFFFFFF;

    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    private static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);

    [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
    static extern IntPtr LoadCursor(IntPtr hInstance, int lpCursorName);

    [DllImport("user32.dll", EntryPoint = "RegisterClassEx", CharSet = CharSet.Auto, SetLastError = true)]
    static extern ushort RegisterClassEx([In] ref WNDCLASSEX lpwcx);

    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    static extern IntPtr CreateWindowEx(
        uint dwExStyle,
        string lpClassName,
        string lpWindowName,
        uint dwStyle,
        int x,
        int y,
        int nWidth,
        int nHeight,
        IntPtr hWndParent,
        IntPtr hMenu,
        IntPtr hInstance,
        IntPtr lpParam
    );

    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    static extern bool PeekMessage(out MSG lpMsg, IntPtr hWnd, uint wMsgFilterMin, uint wMsgFilterMax, uint wRemoveMsg);

    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    static extern bool GetMessage(out MSG lpMsg, IntPtr hWnd, uint wMsgFilterMin, uint wMsgFilterMax);

    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    static extern bool TranslateMessage([In] ref MSG lpMsg);

    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    static extern IntPtr DispatchMessage([In] ref MSG lpMsg);

    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    static extern void PostQuitMessage(int nExitCode);
 
    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    static extern IntPtr DefWindowProc(IntPtr hWnd, uint uMsg, IntPtr wParam, IntPtr lParam);
 
    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    static extern IntPtr BeginPaint(IntPtr hWnd, out PAINTSTRUCT lpPaint);
 
    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    static extern IntPtr EndPaint(IntPtr hWnd, ref PAINTSTRUCT lpPaint);
 
    [DllImport("gdi32.dll", CharSet = CharSet.Auto)]
    static extern IntPtr TextOut( IntPtr hdc, int x, int y, string lpString, int nCount );

    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    static extern int GetWindowText(IntPtr hWnd, StringBuilder lpString, int nMaxCount);

    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    static extern int GetClassName(IntPtr hWnd, StringBuilder lpClassName, int nMaxCount);

    const uint D3D_FEATURE_LEVEL_11_0 = 0xb000;
    const uint D3D_FEATURE_LEVEL_10_1 = 0xa100;
    const uint D3D_FEATURE_LEVEL_10_0 = 0xa000;
    const uint D3D_FEATURE_LEVEL_9_3  = 0x9300;
    const uint D3D_FEATURE_LEVEL_9_2  = 0x9200;
    const uint D3D_FEATURE_LEVEL_9_1  = 0x9100;

    const uint D3D_ROOT_SIGNATURE_VERSION_1 = 0x1;
    const uint D3D_ROOT_SIGNATURE_VERSION_1_0 = 0x1;
    const uint D3D_ROOT_SIGNATURE_VERSION_1_1 = 0x2;
    const uint D3D_ROOT_SIGNATURE_VERSION_1_2 = 0x3;
            
    [StructLayout(LayoutKind.Sequential)]
    struct Vertex
    {
        public float X, Y, Z;    // position
        public float R, G, B, A; // color
    }

    [DllImport("d3d12.dll")]
    private static extern int D3D12GetDebugInterface([In] ref Guid riid, [Out] out IntPtr ppvDebug);

    [ComImport]
    [Guid("344488b7-6846-474b-b989-f027448245e0")]
    [InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    private interface ID3D12Debug
    {
        void EnableDebugLayer();
    }

    [DllImport("d3d12.dll")]
    public static extern int D3D12CreateDevice(
        IntPtr pAdapter,
        uint MinimumFeatureLevel,  // D3D_FEATURE_LEVEL
        ref Guid riid,
        out IntPtr ppDevice);

    [DllImport("dxgidebug.dll")]
    private static extern int DXGIGetDebugInterface(ref Guid riid, out IntPtr ppDebug);

    [DllImport("dxgi.dll")]
    private static extern int CreateDXGIFactory1(ref Guid riid, out IntPtr ppFactory);

    [DllImport("dxgi.dll")]
    private static extern int CreateDXGIFactory2(uint Flags, ref Guid riid, out IntPtr ppFactory);

    private static DXGI_SWAP_CHAIN_DESC1 swapChainDesc1;

    [DllImport("d3d12.dll")]
    public static extern int D3D12SerializeRootSignature(
        ref D3D12_ROOT_SIGNATURE_DESC pRootSignature,
        uint Version, // D3D_ROOT_SIGNATURE_VERSION
        out IntPtr ppBlob,
        out IntPtr ppErrorBlob);

    [DllImport("kernel32.dll")]
    public static extern IntPtr CreateEvent(
        IntPtr lpEventAttributes,
        bool bManualReset,
        bool bInitialState,
        string lpName);

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern UInt32 WaitForSingleObject(IntPtr hHandle, UInt32 dwMilliseconds);

    [DllImport("kernel32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool CloseHandle(IntPtr hObject);

    [DllImport("d3dcompiler_47.dll", CallingConvention = CallingConvention.Winapi)]
    private static extern int D3DCompileFromFile(
        [MarshalAs(UnmanagedType.LPWStr)] string pFileName,
        IntPtr pDefines,
        IntPtr pInclude,
        [MarshalAs(UnmanagedType.LPStr)] string pEntrypoint,
        [MarshalAs(UnmanagedType.LPStr)] string pTarget,
        uint Flags1,
        uint Flags2,
        out IntPtr ppCode,
        out IntPtr ppErrorMsgs
    );


    [StructLayout(LayoutKind.Sequential)]
    struct D3D12_COMMAND_QUEUE_DESC
    {
        public D3D12_COMMAND_LIST_TYPE Type;
        public int Priority;
        public D3D12_COMMAND_QUEUE_FLAGS Flags;
        public uint NodeMask;
    }

    enum D3D12_COMMAND_LIST_TYPE
    {
        D3D12_COMMAND_LIST_TYPE_DIRECT = 0,
        D3D12_COMMAND_LIST_TYPE_BUNDLE = 1,
        D3D12_COMMAND_LIST_TYPE_COMPUTE = 2,
        D3D12_COMMAND_LIST_TYPE_COPY = 3
    }

    [Flags]
    enum D3D12_COMMAND_QUEUE_FLAGS
    {
        D3D12_COMMAND_QUEUE_FLAG_NONE = 0,
        D3D12_COMMAND_QUEUE_FLAG_DISABLE_GPU_TIMEOUT = 0x1
    }

    [StructLayout(LayoutKind.Sequential)]
    struct D3D12_DESCRIPTOR_HEAP_DESC
    {
        public D3D12_DESCRIPTOR_HEAP_TYPE Type;
        public uint NumDescriptors;
        public D3D12_DESCRIPTOR_HEAP_FLAGS Flags;
        public uint NodeMask;
    }

    enum D3D12_DESCRIPTOR_HEAP_TYPE
    {
        D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV = 0,
        D3D12_DESCRIPTOR_HEAP_TYPE_SAMPLER = 1,
        D3D12_DESCRIPTOR_HEAP_TYPE_RTV = 2,
        D3D12_DESCRIPTOR_HEAP_TYPE_DSV = 3
    }

    [Flags]
    enum D3D12_DESCRIPTOR_HEAP_FLAGS
    {
        D3D12_DESCRIPTOR_HEAP_FLAG_NONE = 0,
        D3D12_DESCRIPTOR_HEAP_FLAG_SHADER_VISIBLE = 0x1
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct D3D12_CPU_DESCRIPTOR_HANDLE
    {
        public IntPtr ptr;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct D3D12_GPU_DESCRIPTOR_HANDLE
    {
        public ulong ptr;
    }

    public enum D3D12_RESOURCE_STATES
    {
        D3D12_RESOURCE_STATE_COMMON = 0,
        D3D12_RESOURCE_STATE_VERTEX_AND_CONSTANT_BUFFER = 0x1,
        D3D12_RESOURCE_STATE_INDEX_BUFFER = 0x2,
        D3D12_RESOURCE_STATE_RENDER_TARGET = 0x4,
        D3D12_RESOURCE_STATE_UNORDERED_ACCESS = 0x8,
        D3D12_RESOURCE_STATE_DEPTH_WRITE = 0x10,
        D3D12_RESOURCE_STATE_DEPTH_READ = 0x20,
        D3D12_RESOURCE_STATE_NON_PIXEL_SHADER_RESOURCE = 0x40,
        D3D12_RESOURCE_STATE_PIXEL_SHADER_RESOURCE = 0x80,
        D3D12_RESOURCE_STATE_STREAM_OUT = 0x100,
        D3D12_RESOURCE_STATE_INDIRECT_ARGUMENT = 0x200,
        D3D12_RESOURCE_STATE_COPY_DEST = 0x400,
        D3D12_RESOURCE_STATE_COPY_SOURCE = 0x800,
        D3D12_RESOURCE_STATE_RESOLVE_DEST = 0x1000,
        D3D12_RESOURCE_STATE_RESOLVE_SOURCE = 0x2000,
        D3D12_RESOURCE_STATE_GENERIC_READ = 
            (D3D12_RESOURCE_STATE_VERTEX_AND_CONSTANT_BUFFER | 
             D3D12_RESOURCE_STATE_INDEX_BUFFER |
             D3D12_RESOURCE_STATE_NON_PIXEL_SHADER_RESOURCE |
             D3D12_RESOURCE_STATE_PIXEL_SHADER_RESOURCE |
             D3D12_RESOURCE_STATE_INDIRECT_ARGUMENT |
             D3D12_RESOURCE_STATE_COPY_SOURCE),
        D3D12_RESOURCE_STATE_PRESENT = 0,
        D3D12_RESOURCE_STATE_PREDICATION = 0x200
    }

    [StructLayout(LayoutKind.Sequential)]
    struct D3D12_RESOURCE_DESC
    {
        public D3D12_RESOURCE_DIMENSION Dimension;
        public ulong Alignment;
        public ulong Width;
        public uint Height;
        public ushort DepthOrArraySize;
        public ushort MipLevels;
        public uint Format; // DXGI_FORMAT
        public DXGI_SAMPLE_DESC SampleDesc;
        public D3D12_TEXTURE_LAYOUT Layout;
        public D3D12_RESOURCE_FLAGS Flags;
    }

    enum D3D12_RESOURCE_DIMENSION
    {
        D3D12_RESOURCE_DIMENSION_UNKNOWN = 0,
        D3D12_RESOURCE_DIMENSION_BUFFER = 1,
        D3D12_RESOURCE_DIMENSION_TEXTURE1D = 2,
        D3D12_RESOURCE_DIMENSION_TEXTURE2D = 3,
        D3D12_RESOURCE_DIMENSION_TEXTURE3D = 4
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct DXGI_SAMPLE_DESC
    {
        public uint Count;
        public uint Quality;
    }

    enum D3D12_TEXTURE_LAYOUT
    {
        D3D12_TEXTURE_LAYOUT_UNKNOWN = 0,
        D3D12_TEXTURE_LAYOUT_ROW_MAJOR = 1,
        D3D12_TEXTURE_LAYOUT_64KB_UNDEFINED_SWIZZLE = 2,
        D3D12_TEXTURE_LAYOUT_64KB_STANDARD_SWIZZLE = 3
    }

    [Flags]
    enum D3D12_RESOURCE_FLAGS
    {
        D3D12_RESOURCE_FLAG_NONE = 0,
        D3D12_RESOURCE_FLAG_ALLOW_RENDER_TARGET = 0x1,
        D3D12_RESOURCE_FLAG_ALLOW_DEPTH_STENCIL = 0x2,
        D3D12_RESOURCE_FLAG_ALLOW_UNORDERED_ACCESS = 0x4,
        D3D12_RESOURCE_FLAG_DENY_SHADER_RESOURCE = 0x8,
        D3D12_RESOURCE_FLAG_ALLOW_CROSS_ADAPTER = 0x10,
        D3D12_RESOURCE_FLAG_ALLOW_SIMULTANEOUS_ACCESS = 0x20
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct D3D12_HEAP_PROPERTIES
    {
        public D3D12_HEAP_TYPE Type;
        public D3D12_CPU_PAGE_PROPERTY CPUPageProperty;
        public D3D12_MEMORY_POOL MemoryPoolPreference;
        public uint CreationNodeMask;
        public uint VisibleNodeMask;
    }

    public enum D3D12_HEAP_TYPE
    {
        D3D12_HEAP_TYPE_DEFAULT = 1,
        D3D12_HEAP_TYPE_UPLOAD = 2,
        D3D12_HEAP_TYPE_READBACK = 3,
        D3D12_HEAP_TYPE_CUSTOM = 4
    }

    public enum D3D12_CPU_PAGE_PROPERTY
    {
        D3D12_CPU_PAGE_PROPERTY_UNKNOWN = 0,
        D3D12_CPU_PAGE_PROPERTY_NOT_AVAILABLE = 1,
        D3D12_CPU_PAGE_PROPERTY_WRITE_COMBINE = 2,
        D3D12_CPU_PAGE_PROPERTY_WRITE_BACK = 3
    }

    public enum D3D12_MEMORY_POOL
    {
        D3D12_MEMORY_POOL_UNKNOWN = 0,
        D3D12_MEMORY_POOL_L0 = 1,
        D3D12_MEMORY_POOL_L1 = 2
    }

    [Flags]
    public enum D3D12_HEAP_FLAGS
    {
        D3D12_HEAP_FLAG_NONE = 0,
        D3D12_HEAP_FLAG_SHARED = 0x1,
        D3D12_HEAP_FLAG_DENY_BUFFERS = 0x4,
        D3D12_HEAP_FLAG_ALLOW_DISPLAY = 0x8,
        D3D12_HEAP_FLAG_SHARED_CROSS_ADAPTER = 0x20,
        D3D12_HEAP_FLAG_DENY_RT_DS_TEXTURES = 0x40,
        D3D12_HEAP_FLAG_DENY_NON_RT_DS_TEXTURES = 0x80,
        D3D12_HEAP_FLAG_ALLOW_ALL_BUFFERS_AND_TEXTURES = 0,
        D3D12_HEAP_FLAG_ALLOW_ONLY_BUFFERS = D3D12_HEAP_FLAG_DENY_RT_DS_TEXTURES | D3D12_HEAP_FLAG_DENY_NON_RT_DS_TEXTURES,
        D3D12_HEAP_FLAG_ALLOW_ONLY_NON_RT_DS_TEXTURES = D3D12_HEAP_FLAG_DENY_BUFFERS | D3D12_HEAP_FLAG_DENY_RT_DS_TEXTURES,
    }
    
    [StructLayout(LayoutKind.Sequential)]
    struct D3D12_GRAPHICS_PIPELINE_STATE_DESC
    {
        public IntPtr pRootSignature;
        public D3D12_SHADER_BYTECODE VS;
        public D3D12_SHADER_BYTECODE PS;
        public D3D12_SHADER_BYTECODE DS;
        public D3D12_SHADER_BYTECODE HS;
        public D3D12_SHADER_BYTECODE GS;
        public D3D12_STREAM_OUTPUT_DESC StreamOutput;
        public D3D12_BLEND_DESC BlendState;
        public uint SampleMask;
        public D3D12_RASTERIZER_DESC RasterizerState;
        public D3D12_DEPTH_STENCIL_DESC DepthStencilState;
        public D3D12_INPUT_LAYOUT_DESC InputLayout;
        public D3D12_INDEX_BUFFER_STRIP_CUT_VALUE IBStripCutValue;
        public D3D12_PRIMITIVE_TOPOLOGY_TYPE PrimitiveTopologyType;
        public uint NumRenderTargets;
        [MarshalAs(UnmanagedType.ByValArray, SizeConst = 8)]
        public uint[] RTVFormats;
        public uint DSVFormat;
        public DXGI_SAMPLE_DESC SampleDesc;
        public uint NodeMask;
        public D3D12_CACHED_PIPELINE_STATE CachedPSO;
        public D3D12_PIPELINE_STATE_FLAGS Flags;
    }

    [StructLayout(LayoutKind.Sequential)]
    struct D3D12_SHADER_BYTECODE
    {
        public IntPtr pShaderBytecode;
        public IntPtr BytecodeLength;
    }

    [StructLayout(LayoutKind.Sequential)]
    struct D3D12_INPUT_LAYOUT_DESC
    {
        public IntPtr pInputElementDescs;
        public uint NumElements;
    }

        [StructLayout(LayoutKind.Sequential)]
    struct D3D12_INPUT_ELEMENT_DESC
    {
        public IntPtr SemanticName;
        public uint SemanticIndex;
        public uint Format;            // DXGI_FORMAT
        public uint InputSlot;
        public uint AlignedByteOffset;
        public D3D12_INPUT_CLASSIFICATION InputSlotClass;
        public uint InstanceDataStepRate;
    }

    enum D3D12_INPUT_CLASSIFICATION
    {
        D3D12_INPUT_CLASSIFICATION_PER_VERTEX_DATA = 0,
        D3D12_INPUT_CLASSIFICATION_PER_INSTANCE_DATA = 1
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct D3D12_ROOT_SIGNATURE_DESC
    {
        public uint NumParameters;
        public IntPtr pParameters;
        public uint NumStaticSamplers;
        public IntPtr pStaticSamplers;
        public D3D12_ROOT_SIGNATURE_FLAGS Flags;
    }

    [Flags]
    public enum D3D12_ROOT_SIGNATURE_FLAGS
    {
        D3D12_ROOT_SIGNATURE_FLAG_NONE = 0,
        D3D12_ROOT_SIGNATURE_FLAG_ALLOW_INPUT_ASSEMBLER_INPUT_LAYOUT = 0x1,
        D3D12_ROOT_SIGNATURE_FLAG_DENY_VERTEX_SHADER_ROOT_ACCESS = 0x2,
        D3D12_ROOT_SIGNATURE_FLAG_DENY_HULL_SHADER_ROOT_ACCESS = 0x4,
        D3D12_ROOT_SIGNATURE_FLAG_DENY_DOMAIN_SHADER_ROOT_ACCESS = 0x8,
        D3D12_ROOT_SIGNATURE_FLAG_DENY_GEOMETRY_SHADER_ROOT_ACCESS = 0x10,
        D3D12_ROOT_SIGNATURE_FLAG_DENY_PIXEL_SHADER_ROOT_ACCESS = 0x20,
        D3D12_ROOT_SIGNATURE_FLAG_ALLOW_STREAM_OUTPUT = 0x40
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct D3D12_VERTEX_BUFFER_VIEW
    {
        public ulong BufferLocation;    // D3D12_GPU_VIRTUAL_ADDRESS
        public uint SizeInBytes;
        public uint StrideInBytes;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct D3D12_CONSTANT_BUFFER_VIEW_DESC
    {
        public ulong BufferLocation;    // D3D12_GPU_VIRTUAL_ADDRESS
        public uint SizeInBytes;
        public uint SizeInBytesDividedBy256; // constant buffers must be 256-byte aligned
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct D3D12_SAMPLER_DESC
    {
        public D3D12_FILTER Filter;
        public D3D12_TEXTURE_ADDRESS_MODE AddressU;
        public D3D12_TEXTURE_ADDRESS_MODE AddressV;
        public D3D12_TEXTURE_ADDRESS_MODE AddressW;
        public float MipLODBias;
        public uint MaxAnisotropy;
        public D3D12_COMPARISON_FUNC ComparisonFunc;
        [MarshalAs(UnmanagedType.ByValArray, SizeConst = 4)]
        public float[] BorderColor;
        public float MinLOD;
        public float MaxLOD;
    }

    public enum D3D12_FILTER
    {
        D3D12_FILTER_MIN_MAG_MIP_POINT = 0,
        D3D12_FILTER_MIN_MAG_POINT_MIP_LINEAR = 0x1,
        D3D12_FILTER_MIN_POINT_MAG_LINEAR_MIP_POINT = 0x4,
        D3D12_FILTER_MIN_POINT_MAG_MIP_LINEAR = 0x5,
        D3D12_FILTER_MIN_LINEAR_MAG_MIP_POINT = 0x10,
        D3D12_FILTER_MIN_LINEAR_MAG_POINT_MIP_LINEAR = 0x11,
        D3D12_FILTER_MIN_MAG_LINEAR_MIP_POINT = 0x14,
        D3D12_FILTER_MIN_MAG_MIP_LINEAR = 0x15,
        D3D12_FILTER_ANISOTROPIC = 0x55,
    }

    public enum D3D12_TEXTURE_ADDRESS_MODE
    {
        D3D12_TEXTURE_ADDRESS_MODE_WRAP = 1,
        D3D12_TEXTURE_ADDRESS_MODE_MIRROR = 2,
        D3D12_TEXTURE_ADDRESS_MODE_CLAMP = 3,
        D3D12_TEXTURE_ADDRESS_MODE_BORDER = 4,
        D3D12_TEXTURE_ADDRESS_MODE_MIRROR_ONCE = 5
    }

    public enum D3D12_COMPARISON_FUNC
    {
        D3D12_COMPARISON_FUNC_NEVER = 1,
        D3D12_COMPARISON_FUNC_LESS = 2,
        D3D12_COMPARISON_FUNC_EQUAL = 3,
        D3D12_COMPARISON_FUNC_LESS_EQUAL = 4,
        D3D12_COMPARISON_FUNC_GREATER = 5,
        D3D12_COMPARISON_FUNC_NOT_EQUAL = 6,
        D3D12_COMPARISON_FUNC_GREATER_EQUAL = 7,
        D3D12_COMPARISON_FUNC_ALWAYS = 8
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct D3D12_RESOURCE_ALLOCATION_INFO
    {
        public ulong SizeInBytes;
        public ulong Alignment;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct D3D12_HEAP_DESC
    {
        public ulong SizeInBytes;
        public D3D12_HEAP_PROPERTIES Properties;
        public ulong Alignment;
        public D3D12_HEAP_FLAGS Flags;
    }

    [Flags]
    public enum D3D12_FENCE_FLAGS
    {
        D3D12_FENCE_FLAG_NONE = 0,
        D3D12_FENCE_FLAG_SHARED = 0x1,
        D3D12_FENCE_FLAG_SHARED_CROSS_ADAPTER = 0x2
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct D3D12_PLACED_SUBRESOURCE_FOOTPRINT
    {
        public ulong Offset;
        public D3D12_SUBRESOURCE_FOOTPRINT Footprint;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct D3D12_SUBRESOURCE_FOOTPRINT
    {
        public uint Format; // DXGI_FORMAT
        public uint Width;
        public uint Height;
        public uint Depth;
        public uint RowPitch;
    }

    const uint DXGI_FORMAT_UNKNOWN = 0;
    const uint DXGI_FORMAT_R32G32B32A32_TYPELESS = 1;
    const uint DXGI_FORMAT_R32G32B32A32_FLOAT = 2;
    const uint DXGI_FORMAT_R32G32B32A32_UINT = 3;
    const uint DXGI_FORMAT_R32G32B32A32_SINT = 4;
    const uint DXGI_FORMAT_R32G32B32_TYPELESS = 5;
    const uint DXGI_FORMAT_R32G32B32_FLOAT = 6;
    const uint DXGI_FORMAT_R32G32B32_UINT = 7;
    const uint DXGI_FORMAT_R32G32B32_SINT = 8;
    const uint DXGI_FORMAT_R16G16B16A16_TYPELESS = 9;
    const uint DXGI_FORMAT_R16G16B16A16_FLOAT = 10;
    const uint DXGI_FORMAT_R32G32_FLOAT = 16;
    const uint DXGI_FORMAT_R8G8B8A8_UNORM = 28;
    const uint DXGI_FORMAT_R8G8B8A8_UINT = 30;
    const uint DXGI_FORMAT_R8G8B8A8_SNORM = 29;
    const uint DXGI_FORMAT_R8G8B8A8_SINT = 31;
    const uint DXGI_FORMAT_R32_FLOAT = 41;

    const uint DXGI_USAGE_RENDER_TARGET_OUTPUT = 0x20;
    const uint DXGI_SCALING_STRETCH = 0;

    const int  DXGI_MODE_SCANLINE_ORDER_UNSPECIFIED = 0;
    const uint DXGI_MODE_SCALING_UNSPECIFIED = 0;
    const uint DXGI_MODE_SCALING_CENTERED = 1;
    const uint DXGI_MODE_SCALING_STRETCH = 2;
    const uint DXGI_SCANLINE_ORDERING_UNSPECIFIED = 0;
    
    const uint DXGI_SWAP_EFFECT_DISCARD = 0;
    const uint DXGI_SWAP_EFFECT_SEQUENTIAL = 1;
    const uint DXGI_SWAP_EFFECT_FLIP_SEQUENTIAL = 3;
    const uint DXGI_SWAP_EFFECT_FLIP_DISCARD = 4;

    const uint DXGI_SWAP_CHAIN_FLAG_NONPREROTATED = 1;
    const uint DXGI_SWAP_CHAIN_FLAG_ALLOW_MODE_SWITCH = 2;
    const uint DXGI_SWAP_CHAIN_FLAG_GDI_COMPATIBLE = 4;
    const uint DXGI_SWAP_CHAIN_FLAG_RESTRICTED_CONTENT = 8;
    const uint DXGI_SWAP_CHAIN_FLAG_RESTRICT_SHARED_RESOURCE_DRIVER = 16;
    const uint DXGI_SWAP_CHAIN_FLAG_DISPLAY_ONLY = 32;
    const uint DXGI_SWAP_CHAIN_FLAG_FRAME_LATENCY_WAITABLE_OBJECT = 64;
    const uint DXGI_SWAP_CHAIN_FLAG_ALLOW_TEARING = 512;  // 0x200

    const uint DXGI_PRESENT_NONE                  = 0x00000000;
    const uint DXGI_PRESENT_TEST                  = 0x00000001;
    const uint DXGI_PRESENT_DO_NOT_SEQUENCE       = 0x00000002;
    const uint DXGI_PRESENT_RESTART               = 0x00000004;
    const uint DXGI_PRESENT_DO_NOT_WAIT           = 0x00000008;
    const uint DXGI_PRESENT_STEREO_PREFER_RIGHT   = 0x00000010;
    const uint DXGI_PRESENT_STEREO_TEMPORARY_MONO = 0x00000020;
    const uint DXGI_PRESENT_RESTRICT_TO_OUTPUT    = 0x00000040;
    const uint DXGI_PRESENT_USE_DURATION          = 0x00000100;

    [StructLayout(LayoutKind.Sequential)]
    public struct D3D12_STREAM_OUTPUT_DESC
    {
        public IntPtr pSODeclaration;
        public uint NumEntries;
        public IntPtr pBufferStrides;
        public uint NumStrides;
        public uint RasterizedStream;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct D3D12_BLEND_DESC
    {
        public bool AlphaToCoverageEnable;
        public bool IndependentBlendEnable;
        [MarshalAs(UnmanagedType.ByValArray, SizeConst = 8)]
        public D3D12_RENDER_TARGET_BLEND_DESC[] RenderTarget;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct D3D12_RENDER_TARGET_BLEND_DESC
    {
        public bool BlendEnable;
        public bool LogicOpEnable;
        public D3D12_BLEND SrcBlend;
        public D3D12_BLEND DestBlend;
        public D3D12_BLEND_OP BlendOp;
        public D3D12_BLEND SrcBlendAlpha;
        public D3D12_BLEND DestBlendAlpha;
        public D3D12_BLEND_OP BlendOpAlpha;
        public D3D12_LOGIC_OP LogicOp;
        public byte RenderTargetWriteMask;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct D3D12_RASTERIZER_DESC
    {
        public D3D12_FILL_MODE FillMode;
        public D3D12_CULL_MODE CullMode;
        public bool FrontCounterClockwise;
        public int DepthBias;
        public float DepthBiasClamp;
        public float SlopeScaledDepthBias;
        public bool DepthClipEnable;
        public bool MultisampleEnable;
        public bool AntialiasedLineEnable;
        public uint ForcedSampleCount;
        public D3D12_CONSERVATIVE_RASTERIZATION_MODE ConservativeRaster;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct D3D12_DEPTH_STENCIL_DESC
    {
        public bool DepthEnable;
        public D3D12_DEPTH_WRITE_MASK DepthWriteMask;
        public D3D12_COMPARISON_FUNC DepthFunc;
        public bool StencilEnable;
        public byte StencilReadMask;
        public byte StencilWriteMask;
        public D3D12_DEPTH_STENCILOP_DESC FrontFace;
        public D3D12_DEPTH_STENCILOP_DESC BackFace;
    }

    public enum D3D12_INDEX_BUFFER_STRIP_CUT_VALUE
    {
        D3D12_INDEX_BUFFER_STRIP_CUT_VALUE_DISABLED = 0,
        D3D12_INDEX_BUFFER_STRIP_CUT_VALUE_0xFFFF = 1,
        D3D12_INDEX_BUFFER_STRIP_CUT_VALUE_0xFFFFFFFF = 2
    }

    public enum D3D12_PRIMITIVE_TOPOLOGY_TYPE
    {
        D3D12_PRIMITIVE_TOPOLOGY_TYPE_UNDEFINED = 0,
        D3D12_PRIMITIVE_TOPOLOGY_TYPE_POINT = 1,
        D3D12_PRIMITIVE_TOPOLOGY_TYPE_LINE = 2,
        D3D12_PRIMITIVE_TOPOLOGY_TYPE_TRIANGLE = 3,
        D3D12_PRIMITIVE_TOPOLOGY_TYPE_PATCH = 4
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct D3D12_CACHED_PIPELINE_STATE
    {
        public IntPtr pCachedBlob;
        public IntPtr CachedBlobSizeInBytes;
    }

    [Flags]
    public enum D3D12_PIPELINE_STATE_FLAGS
    {
        D3D12_PIPELINE_STATE_FLAG_NONE = 0,
        D3D12_PIPELINE_STATE_FLAG_TOOL_DEBUG = 0x1
    }

    public enum D3D12_BLEND
    {
        D3D12_BLEND_ZERO = 1,
        D3D12_BLEND_ONE = 2,
        D3D12_BLEND_SRC_COLOR = 3,
        D3D12_BLEND_INV_SRC_COLOR = 4,
        D3D12_BLEND_SRC_ALPHA = 5,
        D3D12_BLEND_INV_SRC_ALPHA = 6,
        D3D12_BLEND_DEST_ALPHA = 7,
        D3D12_BLEND_INV_DEST_ALPHA = 8,
        D3D12_BLEND_DEST_COLOR = 9,
        D3D12_BLEND_INV_DEST_COLOR = 10,
        D3D12_BLEND_SRC_ALPHA_SAT = 11,
        D3D12_BLEND_BLEND_FACTOR = 14,
        D3D12_BLEND_INV_BLEND_FACTOR = 15,
        D3D12_BLEND_SRC1_COLOR = 16,
        D3D12_BLEND_INV_SRC1_COLOR = 17,
        D3D12_BLEND_SRC1_ALPHA = 18,
        D3D12_BLEND_INV_SRC1_ALPHA = 19
    }

    public enum D3D12_BLEND_OP
    {
        D3D12_BLEND_OP_ADD = 1,
        D3D12_BLEND_OP_SUBTRACT = 2,
        D3D12_BLEND_OP_REV_SUBTRACT = 3,
        D3D12_BLEND_OP_MIN = 4,
        D3D12_BLEND_OP_MAX = 5
    }

    public enum D3D12_LOGIC_OP
    {
        D3D12_LOGIC_OP_CLEAR = 0,
        D3D12_LOGIC_OP_SET = 1,
        D3D12_LOGIC_OP_COPY = 2,
        D3D12_LOGIC_OP_COPY_INVERTED = 3,
        D3D12_LOGIC_OP_NOOP = 4,
        D3D12_LOGIC_OP_INVERT = 5,
        D3D12_LOGIC_OP_AND = 6,
        D3D12_LOGIC_OP_NAND = 7,
        D3D12_LOGIC_OP_OR = 8,
        D3D12_LOGIC_OP_NOR = 9,
        D3D12_LOGIC_OP_XOR = 10,
        D3D12_LOGIC_OP_EQUIV = 11,
        D3D12_LOGIC_OP_AND_REVERSE = 12,
        D3D12_LOGIC_OP_AND_INVERTED = 13,
        D3D12_LOGIC_OP_OR_REVERSE = 14,
        D3D12_LOGIC_OP_OR_INVERTED = 15
    }

    public enum D3D12_FILL_MODE
    {
        D3D12_FILL_MODE_WIREFRAME = 2,
        D3D12_FILL_MODE_SOLID = 3
    }

    public enum D3D12_CULL_MODE
    {
        D3D12_CULL_MODE_NONE = 1,
        D3D12_CULL_MODE_FRONT = 2,
        D3D12_CULL_MODE_BACK = 3
    }

    public enum D3D12_CONSERVATIVE_RASTERIZATION_MODE
    {
        D3D12_CONSERVATIVE_RASTERIZATION_MODE_OFF = 0,
        D3D12_CONSERVATIVE_RASTERIZATION_MODE_ON = 1
    }

    public enum D3D12_DEPTH_WRITE_MASK
    {
        D3D12_DEPTH_WRITE_MASK_ZERO = 0,
        D3D12_DEPTH_WRITE_MASK_ALL = 1
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct D3D12_DEPTH_STENCILOP_DESC
    {
        public D3D12_STENCIL_OP StencilFailOp;
        public D3D12_STENCIL_OP StencilDepthFailOp;
        public D3D12_STENCIL_OP StencilPassOp;
        public D3D12_COMPARISON_FUNC StencilFunc;
    }

    public enum D3D12_STENCIL_OP
    {
        D3D12_STENCIL_OP_KEEP = 1,
        D3D12_STENCIL_OP_ZERO = 2,
        D3D12_STENCIL_OP_REPLACE = 3,
        D3D12_STENCIL_OP_INCR_SAT = 4,
        D3D12_STENCIL_OP_DECR_SAT = 5,
        D3D12_STENCIL_OP_INVERT = 6,
        D3D12_STENCIL_OP_INCR = 7,
        D3D12_STENCIL_OP_DECR = 8
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct DXGI_RATIONAL
    {
        public uint Numerator;
        public uint Denominator;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct DXGI_MODE_DESC
    {
        public uint Width;
        public uint Height;
        public DXGI_RATIONAL RefreshRate;
        public uint Format;
        public uint ScanlineOrdering;
        public uint Scaling;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct DXGI_SWAP_CHAIN_DESC
    {
        public DXGI_MODE_DESC BufferDesc;
        public DXGI_SAMPLE_DESC SampleDesc;
        public uint BufferUsage;
        public uint BufferCount;
        public IntPtr OutputWindow;
        public bool Windowed;
        public uint SwapEffect;
        public uint Flags;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct DXGI_SWAP_CHAIN_DESC1
    {
        public uint Width;
        public uint Height;
        public uint Format; // DXGI_FORMAT
        public bool Stereo;
        public DXGI_SAMPLE_DESC SampleDesc;
        public uint BufferUsage;
        public uint BufferCount;
        public DXGI_SCALING Scaling;
        public uint SwapEffect;  // DXGI_SWAP_EFFECT
        public DXGI_ALPHA_MODE AlphaMode;
        public uint Flags;
    }

    public enum DXGI_SCALING
    {
        DXGI_SCALING_STRETCH = 0,
        DXGI_SCALING_NONE = 1,
        DXGI_SCALING_ASPECT_RATIO_STRETCH = 2
    }

    public enum DXGI_ALPHA_MODE
    {
        DXGI_ALPHA_MODE_UNSPECIFIED = 0,
        DXGI_ALPHA_MODE_PREMULTIPLIED = 1,
        DXGI_ALPHA_MODE_STRAIGHT = 2,
        DXGI_ALPHA_MODE_IGNORE = 3
    }


    [StructLayout(LayoutKind.Sequential)]
    public struct D3D12_TEXTURE_COPY_LOCATION
    {
        public IntPtr pResource;
        public D3D12_TEXTURE_COPY_TYPE Type;
        public D3D12_PLACED_SUBRESOURCE_FOOTPRINT PlacedFootprint;
    }

    public enum D3D12_TEXTURE_COPY_TYPE
    {
        D3D12_TEXTURE_COPY_TYPE_SUBRESOURCE_INDEX = 0,
        D3D12_TEXTURE_COPY_TYPE_PLACED_FOOTPRINT = 1
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct D3D12_INDEX_BUFFER_VIEW
    {
        public ulong BufferLocation; // D3D12_GPU_VIRTUAL_ADDRESS
        public uint SizeInBytes; 
        public uint Format;  // DXGI_FORMAT
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct D3D12_STREAM_OUTPUT_BUFFER_VIEW
    {
        public ulong BufferLocation;
        public ulong SizeInBytes;
        public ulong BufferFilledSizeLocation;
    }
    
    public enum D3D12_CLEAR_FLAGS
    {
        // Intentionally no flag for NONE
        D3D12_CLEAR_FLAG_DEPTH   = 0x01,
        D3D12_CLEAR_FLAG_STENCIL = 0x02
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct D3D12_DISCARD_REGION
    {
        public uint NumRects;
        public IntPtr pRects;
        public uint FirstSubresource;
        public uint NumSubresources;
    }

    public enum D3D12_QUERY_TYPE
    {
        D3D12_QUERY_TYPE_OCCLUSION                      = 0,
        D3D12_QUERY_TYPE_BINARY_OCCLUSION               = 1,
        D3D12_QUERY_TYPE_TIMESTAMP                      = 2,
        D3D12_QUERY_TYPE_PIPELINE_STATISTICS            = 3,
        D3D12_QUERY_TYPE_SO_STATISTICS_STREAM0          = 4,
        D3D12_QUERY_TYPE_SO_STATISTICS_STREAM1          = 5,
        D3D12_QUERY_TYPE_SO_STATISTICS_STREAM2          = 6,
        D3D12_QUERY_TYPE_SO_STATISTICS_STREAM3          = 7,
        D3D12_QUERY_TYPE_VIDEO_DECODE_STATISTICS        = 8,
        D3D12_QUERY_TYPE_PIPELINE_STATISTICS1           = 10,
    }

    public enum D3D12_PREDICATION_OP
    {
        D3D12_PREDICATION_OP_EQUAL_ZERO     = 0,
        D3D12_PREDICATION_OP_NOT_EQUAL_ZERO = 1,
    }
    
    [StructLayout(LayoutKind.Sequential)]
    public struct D3D12_TILED_RESOURCE_COORDINATE
    {
        public uint X;
        public uint Y;
        public uint Z;
        public uint Subresource;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct D3D12_TILE_REGION_SIZE
    {
        public uint NumTiles;
        public bool UseBox;
        public uint Width;
        public ushort Height;
        public ushort Depth;
    }

    [Flags]
    public enum D3D12_TILE_COPY_FLAGS
    {
        D3D12_TILE_COPY_FLAG_NONE = 0,
        D3D12_TILE_COPY_FLAG_NO_HAZARD = 0x1,
        D3D12_TILE_COPY_FLAG_LINEAR_BUFFER_TO_SWIZZLED_TILED_RESOURCE = 0x2,
        D3D12_TILE_COPY_FLAG_SWIZZLED_TILED_RESOURCE_TO_LINEAR_BUFFER = 0x4
    }

    public enum D3D_PRIMITIVE_TOPOLOGY
    {
        D3D_PRIMITIVE_TOPOLOGY_UNDEFINED = 0,
        D3D_PRIMITIVE_TOPOLOGY_POINTLIST = 1,
        D3D_PRIMITIVE_TOPOLOGY_LINELIST = 2,
        D3D_PRIMITIVE_TOPOLOGY_LINESTRIP = 3,
        D3D_PRIMITIVE_TOPOLOGY_TRIANGLELIST = 4,
        D3D_PRIMITIVE_TOPOLOGY_TRIANGLESTRIP = 5
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct D3D12_VIEWPORT
    {
        public float TopLeftX;
        public float TopLeftY;
        public float Width;
        public float Height;
        public float MinDepth;
        public float MaxDepth;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct D3D12_RECT
    {
        public int left;
        public int top;
        public int right;
        public int bottom;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct D3D12_RESOURCE_BARRIER
    {
        public D3D12_RESOURCE_BARRIER_TYPE Type;
        public D3D12_RESOURCE_BARRIER_FLAGS Flags;
        public D3D12_RESOURCE_TRANSITION_BARRIER Transition;
    }

    public enum D3D12_RESOURCE_BARRIER_TYPE
    {
        D3D12_RESOURCE_BARRIER_TYPE_TRANSITION = 0,
        D3D12_RESOURCE_BARRIER_TYPE_ALIASING = 1,
        D3D12_RESOURCE_BARRIER_TYPE_UAV = 2
    }

    [Flags]
    public enum D3D12_RESOURCE_BARRIER_FLAGS
    {
        D3D12_RESOURCE_BARRIER_FLAG_NONE = 0,
        D3D12_RESOURCE_BARRIER_FLAG_BEGIN_ONLY = 0x1,
        D3D12_RESOURCE_BARRIER_FLAG_END_ONLY = 0x2
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct D3D12_RESOURCE_TRANSITION_BARRIER
    {
        public IntPtr pResource;
        public uint Subresource;
        public D3D12_RESOURCE_STATES StateBefore;
        public D3D12_RESOURCE_STATES StateAfter;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct D3D12_RANGE
    {
        public ulong Begin;
        public ulong End;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct D3D12_CPU_DESCRIPTOR_HANDLE_ARRAY
    {
        public IntPtr ptr;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct DXGI_PRESENT_PARAMETERS
    {
        public uint DirtyRectsCount;
        public IntPtr pDirtyRects;
        public IntPtr pScrollRect;
        public IntPtr pScrollOffset;
    }

    [StructLayout(LayoutKind.Sequential)]
    struct PSInput
    {
        [MarshalAs(UnmanagedType.Struct)]
        public float4 position;
        [MarshalAs(UnmanagedType.Struct)]
        public float4 color;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct float4
    {
        public float x, y, z, w;
    }

    public static class CD3DX12_BLEND_DESC
    {
        public static D3D12_BLEND_DESC Default()
        {
            var defaultRenderTarget = new D3D12_RENDER_TARGET_BLEND_DESC
            {
                BlendEnable = false,
                LogicOpEnable = false,
                SrcBlend = D3D12_BLEND.D3D12_BLEND_ONE,
                DestBlend = D3D12_BLEND.D3D12_BLEND_ZERO,
                BlendOp = D3D12_BLEND_OP.D3D12_BLEND_OP_ADD,
                SrcBlendAlpha = D3D12_BLEND.D3D12_BLEND_ONE,
                DestBlendAlpha = D3D12_BLEND.D3D12_BLEND_ZERO,
                BlendOpAlpha = D3D12_BLEND_OP.D3D12_BLEND_OP_ADD,
                LogicOp = D3D12_LOGIC_OP.D3D12_LOGIC_OP_NOOP,
                RenderTargetWriteMask = 0xf
            };

            return new D3D12_BLEND_DESC
            {
                AlphaToCoverageEnable = false,
                IndependentBlendEnable = false,
                RenderTarget = new D3D12_RENDER_TARGET_BLEND_DESC[8]
                {
                    defaultRenderTarget,  // RenderTarget[0]
                    defaultRenderTarget,  // RenderTarget[1]
                    defaultRenderTarget,  // RenderTarget[2]
                    defaultRenderTarget,  // RenderTarget[3]
                    defaultRenderTarget,  // RenderTarget[4]
                    defaultRenderTarget,  // RenderTarget[5]
                    defaultRenderTarget,  // RenderTarget[6]
                    defaultRenderTarget   // RenderTarget[7]
                }
            };
        }
    }

    public static class CD3DX12_RASTERIZER_DESC
    {
        public static D3D12_RASTERIZER_DESC Default()
        {
            return new D3D12_RASTERIZER_DESC
            {
                FillMode = D3D12_FILL_MODE.D3D12_FILL_MODE_SOLID,
                CullMode = D3D12_CULL_MODE.D3D12_CULL_MODE_BACK,
                FrontCounterClockwise = false,
                DepthBias = 0,
                DepthBiasClamp = 0.0f,
                SlopeScaledDepthBias = 0.0f,
                DepthClipEnable = true,
                MultisampleEnable = false,
                AntialiasedLineEnable = false,
                ForcedSampleCount = 0,
                ConservativeRaster = D3D12_CONSERVATIVE_RASTERIZATION_MODE.D3D12_CONSERVATIVE_RASTERIZATION_MODE_OFF
            };
        }
    }

    public static class CD3DX12_DEPTH_STENCIL_DESC
    {
        public static D3D12_DEPTH_STENCIL_DESC Default()
        {
            return new D3D12_DEPTH_STENCIL_DESC
            {
                DepthEnable = false,
                DepthWriteMask = D3D12_DEPTH_WRITE_MASK.D3D12_DEPTH_WRITE_MASK_ALL,
                DepthFunc = D3D12_COMPARISON_FUNC.D3D12_COMPARISON_FUNC_LESS,
                StencilEnable = false,
                StencilReadMask = 0xff,
                StencilWriteMask = 0xff,
                FrontFace = new D3D12_DEPTH_STENCILOP_DESC
                {
                    StencilFailOp = D3D12_STENCIL_OP.D3D12_STENCIL_OP_KEEP,
                    StencilDepthFailOp = D3D12_STENCIL_OP.D3D12_STENCIL_OP_KEEP,
                    StencilPassOp = D3D12_STENCIL_OP.D3D12_STENCIL_OP_KEEP,
                    StencilFunc = D3D12_COMPARISON_FUNC.D3D12_COMPARISON_FUNC_ALWAYS
                },
                BackFace = new D3D12_DEPTH_STENCILOP_DESC
                {
                    StencilFailOp = D3D12_STENCIL_OP.D3D12_STENCIL_OP_KEEP,
                    StencilDepthFailOp = D3D12_STENCIL_OP.D3D12_STENCIL_OP_KEEP,
                    StencilPassOp = D3D12_STENCIL_OP.D3D12_STENCIL_OP_KEEP,
                    StencilFunc = D3D12_COMPARISON_FUNC.D3D12_COMPARISON_FUNC_ALWAYS
                }
            };
        }
    }

    static readonly Guid IID_ID3D12Debug    = new Guid("344488b7-6846-474b-b989-f027448245e0");
    static readonly Guid IID_ID3D12Device   = new Guid("189819f1-1db6-4b57-be54-1821339b85f7");
    static readonly Guid IID_ID3D12Resource = new Guid("696442be-a72e-4059-bc79-5b5c98040fad");

    static readonly Guid IID_ID3D12PipelineState       = new Guid("765a30f3-f624-4c6f-a828-ace948622445");
    static readonly Guid IID_ID3D12GraphicsCommandList = new Guid("5b160d0f-ac1b-4185-8ba8-b3ae42a5a455");
    static readonly Guid IID_ID3D12Fence               = new Guid("0a753dcf-c4d8-4b91-adf6-be5a60d95a76");
    static readonly Guid IID_ID3D12CommandQueue        = new Guid("0ec870a6-5d7e-4c22-8cfc-5baae07616ed");
    static readonly Guid IID_ID3D12DescriptorHeap      = new Guid("8efb471d-616c-4f49-90f7-127bb763fa51");
    static readonly Guid IID_ID3D12CommandAllocator    = new Guid("6102dee4-af59-4b09-b999-b44d73f09b24");
    static readonly Guid IID_ID3D12RootSignature       = new Guid("c54a6b66-72df-4ee8-8be5-a946a1429214");
    static readonly Guid IID_ID3DBlob                  = new Guid("8ba5fb08-5195-40e2-ac58-0d989c3a0102");

    static readonly Guid IID_IDXGIFactory    = new Guid("7b7166ec-21c7-44ae-b21a-c9ae321ae369");
    static readonly Guid IID_IDXGIFactory1   = new Guid("770aae78-f26f-4dba-a829-253c83d1b387");
    static readonly Guid IID_IDXGIFactory2   = new Guid("50c83a1c-e072-4c48-87b0-3630fa36a6d0");
    static readonly Guid IID_IDXGIFactory3   = new Guid("25483823-cd46-4c7d-86ca-47aa95b837bd");
    static readonly Guid IID_IDXGIFactory4   = new Guid("1bc6ea02-ef36-464f-bf0c-21ca39e5168a");

    static readonly Guid IID_IDXGISwapChain1 = new Guid("790a45f7-0d42-4876-983a-0a55cfe6f4aa");
    static readonly Guid IID_IDXGISwapChain2 = new Guid("a8be2ac4-199f-4946-b331-79599fb98de7");
    static readonly Guid IID_IDXGISwapChain3 = new Guid("94d99bdb-f1f8-4ab0-b236-7da0170edab1");

    // #10 IDXGIFactory::CreateSwapChain
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    private delegate int CreateSwapChainDelegate(IntPtr factory, IntPtr pDevice, [In] ref DXGI_SWAP_CHAIN_DESC pDesc, out IntPtr ppSwapChain);

    // #15 IDXGIFactory2::CreateSwapChainForHwnd
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    private delegate int CreateSwapChainForHwndDelegate(IntPtr factory, IntPtr pDevice, IntPtr hWnd, [In] ref DXGI_SWAP_CHAIN_DESC1 pDesc, IntPtr pFullscreenDesc, IntPtr pRestrictToOutput, out IntPtr ppSwapChain);

    // #8 IDXGISwapChain::Present
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    private delegate int PresentDelegate(IntPtr swapChain, uint SyncInterval, uint Flags);

    // #9 IDXGISwapChain::GetBuffer
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    private delegate int GetBufferDelegate([In] IntPtr swapChain, [In] uint Buffer, [In] ref Guid riid, [Out] out IntPtr ppSurface);

    // #36 IDXGISwapChain3::GetCurrentBackBufferIndex
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    private delegate uint GetCurrentBackBufferIndexDelegate(IntPtr swapChain);

    // #8 ID3D12Device::CreateCommandQueue
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    private delegate int CreateCommandQueueDelegate(IntPtr device, [In] ref D3D12_COMMAND_QUEUE_DESC pDesc, ref Guid riid, out IntPtr ppCommandQueue);

    // #9 ID3D12Device::CreateCommandAllocator
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    private delegate int CreateCommandAllocatorDelegate(IntPtr device, D3D12_COMMAND_LIST_TYPE type, ref Guid riid, out IntPtr ppCommandAllocator);

    // #10 ID3D12Device::CreateGraphicsPipelineState
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    private delegate int CreateGraphicsPipelineStateDelegate(IntPtr device, [In] ref D3D12_GRAPHICS_PIPELINE_STATE_DESC pDesc, ref Guid riid, out IntPtr ppPipelineState);

    // #12 ID3D12Device::CreateCommandList
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    private delegate int CreateCommandListDelegate(IntPtr device, uint nodeMask, D3D12_COMMAND_LIST_TYPE type, IntPtr pCommandAllocator, IntPtr pInitialState, ref Guid riid, out IntPtr ppCommandList);

    // #14 ID3D12Device::CreateDescriptorHeap
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    private delegate int CreateDescriptorHeapDelegate(IntPtr device, [In] ref D3D12_DESCRIPTOR_HEAP_DESC pDesc, ref Guid riid, out IntPtr ppHeap);

    // #15 ID3D12Device::GetDescriptorHandleIncrementSize
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    private delegate uint GetDescriptorHandleIncrementSizeDelegate(IntPtr device, D3D12_DESCRIPTOR_HEAP_TYPE descriptorHeapType);

    // #16 ID3D12Device::CreateRootSignature
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    private delegate int CreateRootSignatureDelegate(IntPtr device, uint nodeMask, IntPtr pBlobWithRootSignature, IntPtr blobLengthInBytes, ref Guid riid, out IntPtr ppvRootSignature);

    // #20 ID3D12Device::CreateRenderTargetView
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    private delegate void CreateRenderTargetViewDelegate(IntPtr device, IntPtr pResource, IntPtr pDesc, D3D12_CPU_DESCRIPTOR_HANDLE DestDescriptor);

    // #37 ID3D12Device::GetDeviceRemovedReason
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    private delegate int GetDeviceRemovedReasonDelegate(IntPtr device);

    // #27 ID3D12Device::CreateCommittedResource
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    private delegate int CreateCommittedResourceDelegate(IntPtr device, [In] ref D3D12_HEAP_PROPERTIES pHeapProperties, D3D12_HEAP_FLAGS HeapFlags, [In] ref D3D12_RESOURCE_DESC pDesc, D3D12_RESOURCE_STATES InitialResourceState, IntPtr pOptimizedClearValue, ref Guid riid, out IntPtr ppvResource);

    // #36 ID3D12Device::CreateFence
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    private delegate int CreateFenceDelegate(IntPtr device, ulong InitialValue, D3D12_FENCE_FLAGS Flags, ref Guid riid, out IntPtr ppFence);

    // #9 ID3D12GraphicsCommandList::Close
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    private delegate int CloseDelegate(IntPtr commandList);

    // #10 ID3D12GraphicsCommandList::Reset
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    private delegate int ResetCommandListDelegate(IntPtr commandList, IntPtr pAllocator, IntPtr pInitialState);
    
    // #20 ID3D12GraphicsCommandList::IASetPrimitiveTopology
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    private delegate void IASetPrimitiveTopologyDelegate(IntPtr commandList, D3D_PRIMITIVE_TOPOLOGY PrimitiveTopology);

    // #21 ID3D12GraphicsCommandList::RSSetViewports
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    private delegate void RSSetViewportsDelegate(IntPtr commandList, uint NumViewports, [In, MarshalAs(UnmanagedType.LPArray)] D3D12_VIEWPORT[] pViewports);

    // #22 ID3D12GraphicsCommandList::RSSetScissorRects
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    private delegate void RSSetScissorRectsDelegate(IntPtr commandList, uint NumRects, [In, MarshalAs(UnmanagedType.LPArray)] D3D12_RECT[] pRects);
    
    // #26 ID3D12GraphicsCommandList::ResourceBarrier
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    private delegate void ResourceBarrierDelegate(IntPtr commandList, uint NumBarriers, [In] D3D12_RESOURCE_BARRIER[] pBarriers);

    // #30 ID3D12GraphicsCommandList::SetGraphicsRootSignature
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    private delegate void SetGraphicsRootSignatureDelegate(IntPtr commandList, IntPtr pRootSignature);

    // #46 ID3D12GraphicsCommandList::OMSetRenderTargets
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    private delegate void OMSetRenderTargetsDelegate(IntPtr commandList, uint NumRenderTargetDescriptors, [In] D3D12_CPU_DESCRIPTOR_HANDLE_ARRAY[] pRenderTargetDescriptors, bool RTsSingleHandleToDescriptorRange, IntPtr pDepthStencilDescriptor);

    // #48 ID3D12GraphicsCommandList::ClearRenderTargetView
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    private delegate void ClearRenderTargetViewDelegate(IntPtr commandList, D3D12_CPU_DESCRIPTOR_HANDLE RenderTargetView, [In] float[] ColorRGBA, uint NumRects, IntPtr pRects);

    // #44 ID3D12GraphicsCommandList::IASetVertexBuffers
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    private delegate void IASetVertexBuffersDelegate(IntPtr commandList, uint StartSlot, uint NumViews, [In] D3D12_VERTEX_BUFFER_VIEW[] pViews);

    // #12 ID3D12GraphicsCommandList::DrawInstanced
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    private delegate void DrawInstancedDelegate(IntPtr commandList, uint VertexCountPerInstance, uint InstanceCount, uint StartVertexLocation, uint StartInstanceLocation);

    // #10 ID3D12CommandQueue::ExecuteCommandLists
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    private delegate void ExecuteCommandListsDelegate(IntPtr commandQueue, uint NumCommandLists, [In] IntPtr[] ppCommandLists);

    // #14 ID3D12CommandQueue::Signal
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    private delegate int SignalDelegate(IntPtr commandQueue, IntPtr fence, ulong Value);

    // #8 ID3D12CommandAllocator::Reset
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    private delegate int ResetCommandAllocatorDelegate(IntPtr commandAllocator);

    // #8 ID3D12Fence::GetCompletedValue
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    private delegate ulong GetCompletedValueDelegate(IntPtr fence);

    // #9 ID3D12Fence::SetEventOnCompletion
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    private delegate int SetEventOnCompletionDelegate(IntPtr fence, ulong Value, IntPtr hEvent);

    // #3 ID3DBlob::GetBufferPointer
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    private delegate IntPtr GetBufferPointerDelegate(IntPtr blob);

    // #4 ID3DBlob::GetBufferSize
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    private delegate int GetBufferSizeDelegate(IntPtr blob);

    // #8 ID3D12Resource::Map
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    private delegate int MapDelegate(IntPtr resource, uint Subresource, ref D3D12_RANGE pReadRange, out IntPtr ppData);

    // #9 ID3D12Resource::Unmap
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    private delegate int UnmapDelegate(IntPtr resource, uint Subresource, ref D3D12_RANGE pWrittenRange);
    
    // #11 ID3D12Resource::GetGPUVirtualAddress
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    private delegate ulong GetGPUVirtualAddressDelegate(IntPtr resource);  // this pointer

    // #9 ID3D12DescriptorHeap::GetCPUDescriptorHandleForHeapStart
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    private delegate void GetCPUDescriptorHandleForHeapStartDelegate(IntPtr descriptorHeap, out D3D12_CPU_DESCRIPTOR_HANDLE handle);

    private const int FrameCount = 2;

    private IntPtr device;
    private IntPtr commandQueue;
    private IntPtr swapChain;
    private IntPtr[] renderTargets = new IntPtr[FrameCount];
    private IntPtr commandAllocator;
    private IntPtr commandList;
    private IntPtr pipelineState;
    private IntPtr rootSignature;
    private IntPtr rtvHeap;
    private uint rtvDescriptorSize;
    private IntPtr vertexBuffer;
    private D3D12_VERTEX_BUFFER_VIEW vertexBufferView;
    private IntPtr fence;
    private IntPtr fenceEvent;
    private ulong fenceValue;
    private int frameIndex = 0;

    private byte[] StructArrayToByteArray<T>(T[] structures) where T : struct
    {
        int size = Marshal.SizeOf<T>();
        byte[] arr = new byte[size * structures.Length];
        GCHandle handle = GCHandle.Alloc(structures, GCHandleType.Pinned);
        try
        {
            IntPtr ptr = handle.AddrOfPinnedObject();
            Marshal.Copy(ptr, arr, 0, arr.Length);
        }
        finally
        {
            handle.Free();
        }
        return arr;
    }


    public static class CD3DX12_RESOURCE_BARRIER
    {
        public static D3D12_RESOURCE_BARRIER Transition(
            IntPtr pResource,
            D3D12_RESOURCE_STATES stateBefore,
            D3D12_RESOURCE_STATES stateAfter,
            uint subresource = D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES)
        {
            return new D3D12_RESOURCE_BARRIER
            {
                Type = D3D12_RESOURCE_BARRIER_TYPE.D3D12_RESOURCE_BARRIER_TYPE_TRANSITION,
                Flags = D3D12_RESOURCE_BARRIER_FLAGS.D3D12_RESOURCE_BARRIER_FLAG_NONE,
                Transition = new D3D12_RESOURCE_TRANSITION_BARRIER
                {
                    pResource = pResource,
                    Subresource = subresource,
                    StateBefore = stateBefore,
                    StateAfter = stateAfter
                }
            };
        }
    }

    public const uint D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES = 0xffffffff;

    private static int CreateSwapChain(IntPtr factory, IntPtr pDevice, ref DXGI_SWAP_CHAIN_DESC pDesc, out IntPtr ppSwapChain)
    {
        try
        {
            Console.WriteLine("----------------------------------------");
            Console.WriteLine("[CreateSwapChain] - Start");

            IntPtr vTable = Marshal.ReadIntPtr(factory);
            IntPtr createSwapChainPtr = Marshal.ReadIntPtr(vTable, 10 * IntPtr.Size);  // vTable #10 IDXGIFactory::CreateSwapChain
            Console.WriteLine("CreateSwapChain method address: " + createSwapChainPtr);

            var createSwapChain = Marshal.GetDelegateForFunctionPointer<CreateSwapChainDelegate>(createSwapChainPtr);
            int result = createSwapChain(factory, pDevice, ref pDesc, out ppSwapChain);
            
            Console.WriteLine("CreateSwapChain result: " + result);
            Console.WriteLine("Created SwapChain pointer: " + ppSwapChain);
            
            return result;
        }
        catch (Exception ex)
        {
            Console.WriteLine("Error in CreateSwapChain: " + ex.Message);
            Console.WriteLine("Stack trace: " + ex.StackTrace);
            ppSwapChain = IntPtr.Zero;
            return -1;
        }
    }

    private static int CreateSwapChainForHwnd(IntPtr factory, IntPtr pDevice, IntPtr hWnd, ref DXGI_SWAP_CHAIN_DESC1 pDesc, IntPtr pFullscreenDesc, IntPtr pRestrictToOutput, out IntPtr ppSwapChain)
    {
        Console.WriteLine("----------------------------------------");
        Console.WriteLine("[CreateSwapChainForHwnd] - Start");

        try
        {
            IntPtr vTable = Marshal.ReadIntPtr(factory);
            IntPtr methodPtr = Marshal.ReadIntPtr(vTable, 15 * IntPtr.Size); // vTable #15 IDXGIFactory2::CreateSwapChainForHwnd

            var createSwapChain = Marshal.GetDelegateForFunctionPointer<CreateSwapChainForHwndDelegate>(methodPtr);
            int result = createSwapChain(factory, pDevice, hWnd, ref pDesc, pFullscreenDesc, pRestrictToOutput, out ppSwapChain);
            
            if (result < 0)
            {
                Console.WriteLine("Failed with HRESULT: " + result);
            }
            else
            {
                Console.WriteLine("Created swap chain: " + ppSwapChain);
            }
            
            return result;
        }
        catch (Exception ex)
        {
            Console.WriteLine("Error creating swap chain: " + ex.Message);
            Console.WriteLine("Stack trace: " + ex.StackTrace);
            ppSwapChain = IntPtr.Zero;
            return -1;
        }
    }

    private static int GetBuffer(IntPtr swapChain, uint buffer, ref Guid riid, out IntPtr ppSurface)
    {
        try
        {
            Console.WriteLine("----------------------------------------");
            Console.WriteLine("[GetBuffer] - Start");

            IntPtr vTable = Marshal.ReadIntPtr(swapChain);
            IntPtr methodPtr = Marshal.ReadIntPtr(vTable, 9 * IntPtr.Size);  // vTable #9 IDXGISwapChain::GetBuffer

            if (methodPtr == IntPtr.Zero)
            {
                Console.WriteLine("GetBuffer method pointer is null!");
                ppSurface = IntPtr.Zero;
                return -1;
            }

            var getBuffer = Marshal.GetDelegateForFunctionPointer<GetBufferDelegate>(methodPtr);
            
            int result = getBuffer(swapChain, buffer, ref riid, out ppSurface);
            
            if (result >= 0)
            {
                Console.WriteLine("Buffer obtained: " + ppSurface);
            }
            else
            {
                Console.WriteLine("GetBuffer failed with HRESULT: " + result);
            }
            
            return result;
        }
        catch (Exception ex)
        {
            Console.WriteLine("Error in GetBuffer: " + ex.Message);
            Console.WriteLine("Stack trace: " + ex.StackTrace);
            ppSurface = IntPtr.Zero;
            return -1;
        }
    }

    private static IntPtr CompileShaderFromFile(string fileName, string entryPoint, string profile)
    {
        Console.WriteLine("----------------------------------------");
        Console.WriteLine("[CompileShaderFromFile] - Start");
    
        IntPtr shaderBlob = IntPtr.Zero;
        IntPtr errorBlob = IntPtr.Zero;

        try
        {
            //const uint D3DCOMPILE_DEBUG = 1;
            //const uint D3DCOMPILE_SKIP_OPTIMIZATION = (1 << 2);
            const uint D3DCOMPILE_ENABLE_STRICTNESS = (1 << 11);

            uint compileFlags = D3DCOMPILE_ENABLE_STRICTNESS;
    //#if DEBUG
    //        compileFlags |= D3DCOMPILE_DEBUG | D3DCOMPILE_SKIP_OPTIMIZATION;
    //#endif
    
            int result = D3DCompileFromFile(
                fileName,
                IntPtr.Zero,      // defines
                IntPtr.Zero,      // include interface
                entryPoint,       // entry point
                profile,          // shader profile
                compileFlags,     // flags1
                0,                // flags2
                out shaderBlob,
                out errorBlob
            );

            if (result < 0)
            {
                if (errorBlob != IntPtr.Zero)
                {
                    string errorMessage = Marshal.PtrToStringAnsi(GetBufferPointer(errorBlob));
                    Console.WriteLine("Shader compilation error: " + errorMessage);
                }
                else
                {
                    Console.WriteLine("Shader compilation failed with HRESULT: " + result);
                }
                return IntPtr.Zero;
            }

            if (shaderBlob != IntPtr.Zero)
            {
                IntPtr shaderCode = GetBufferPointer(shaderBlob);
                int shaderSize = GetBlobSize(shaderBlob);
            }
            
            return shaderBlob;
        }
        catch (Exception ex)
        {
            Console.WriteLine("Exception in CompileShaderFromFile: " + ex.Message);
            Console.WriteLine("Stack trace: " + ex.StackTrace);
            return IntPtr.Zero;
        }
        finally
        {
            if (errorBlob != IntPtr.Zero)
            {
                Marshal.Release(errorBlob);
            }
        }
    }

    private static int GetBlobSize(IntPtr blob)
    {
        if (blob == IntPtr.Zero)
        {
            Console.WriteLine("Error: Blob pointer is null");
            return 0;
        }

        try
        {
            IntPtr vTable = Marshal.ReadIntPtr(blob);
            IntPtr getBufferSizePtr = Marshal.ReadIntPtr(vTable, 4 * IntPtr.Size);  // vTable #4 ID3DBlob::GetBufferSize
            var getBufferSize = Marshal.GetDelegateForFunctionPointer<GetBufferSizeDelegate>(getBufferSizePtr);
            return getBufferSize(blob);
        }
        catch (Exception ex)
        {
            Console.WriteLine("Error in GetBlobSize: " + ex.Message);
            return 0;
        }
    }


    private static IntPtr GetBufferPointer(IntPtr blob)
    {
        if (blob == IntPtr.Zero)
        {
            Console.WriteLine("Error: Blob pointer is null");
            return IntPtr.Zero;
        }

        try
        {
            IntPtr vTable = Marshal.ReadIntPtr(blob);
            IntPtr getBufferPointerPtr = Marshal.ReadIntPtr(vTable, 3 * IntPtr.Size);  // vTable #3 ID3DBlob::GetBufferPointer
            
            var getBufferPointer = Marshal.GetDelegateForFunctionPointer<GetBufferPointerDelegate>(getBufferPointerPtr);
            return getBufferPointer(blob);
        }
        catch (Exception ex)
        {
            Console.WriteLine("Error in GetBufferPointer: " + ex.Message);
            return IntPtr.Zero;
        }
    }

    private static IntPtr GetCPUDescriptorHandleForHeapStart(IntPtr descriptorHeap)
    {
        IntPtr heapVTable = Marshal.ReadIntPtr(descriptorHeap);
        IntPtr getHandlePtr = Marshal.ReadIntPtr(heapVTable, 9 * IntPtr.Size);  // #9 ID3D12DescriptorHeap::GetCPUDescriptorHandleForHeapStart
        var getHandle = Marshal.GetDelegateForFunctionPointer<GetCPUDescriptorHandleForHeapStartDelegate>(getHandlePtr);

        D3D12_CPU_DESCRIPTOR_HANDLE handle;
        getHandle(descriptorHeap, out handle);
        return handle.ptr;
    }

    private static int GetBufferSize(IntPtr blob)
    {
        if (blob == IntPtr.Zero)
        {
            Console.WriteLine("Error: Blob pointer is null.");
            return 0;
        }

        try
        {
            IntPtr vTable = Marshal.ReadIntPtr(blob);
            IntPtr getBufferSizePtr = Marshal.ReadIntPtr(vTable, 4 * IntPtr.Size); // vTable #4 ID3DBlob::GetBufferSize
            var getBufferSize = Marshal.GetDelegateForFunctionPointer<GetBufferSizeDelegate>(getBufferSizePtr);

            return (int)getBufferSize(blob);
        }
        catch (Exception ex)
        {
            Console.WriteLine("Error in GetBufferSize: " + ex.Message);
            return 0;
        }
    }

    private int GetDeviceRemovedReason(IntPtr device)
    {
        IntPtr vTable = Marshal.ReadIntPtr(device);
        IntPtr getDeviceRemovedReasonPtr = Marshal.ReadIntPtr(vTable, 37 * IntPtr.Size); // vTable #37 ID3D12Device::GetDeviceRemovedReason
        var getDeviceRemovedReason = Marshal.GetDelegateForFunctionPointer<GetDeviceRemovedReasonDelegate>(getDeviceRemovedReasonPtr);
        return getDeviceRemovedReason(device);
    }

    private void LoadAssets()
    {
        Console.WriteLine("----------------------------------------");
        Console.WriteLine("[LoadAssets] - Start");

        D3D12_ROOT_SIGNATURE_DESC rootSignatureDesc = new D3D12_ROOT_SIGNATURE_DESC
        {
            NumParameters = 0,
            pParameters = IntPtr.Zero,
            NumStaticSamplers = 0,
            pStaticSamplers = IntPtr.Zero,
            Flags = D3D12_ROOT_SIGNATURE_FLAGS.D3D12_ROOT_SIGNATURE_FLAG_ALLOW_INPUT_ASSEMBLER_INPUT_LAYOUT
        };

        IntPtr signature = IntPtr.Zero;
        IntPtr error = IntPtr.Zero;

        int serializeResult = D3D12SerializeRootSignature(
            ref rootSignatureDesc,
            D3D_ROOT_SIGNATURE_VERSION_1,
            out signature,
            out error
        );

        if (serializeResult < 0)
        {
            if (error != IntPtr.Zero)
            {
                string errorMessage = Marshal.PtrToStringAnsi(GetBufferPointer(error));
                Console.WriteLine("Root signature serialization error: " + errorMessage);
                Marshal.Release(error);
            }
            return;
        }

        if (signature == IntPtr.Zero)
        {
            Console.WriteLine("Error: Signature blob is null");
            return;
        }

        IntPtr blobData = GetBufferPointer(signature);
        int blobSize = GetBlobSize(signature);

        if (blobData == IntPtr.Zero || blobSize == 0)
        {
            Console.WriteLine("Error: Invalid serialized root signature data");
            if (signature != IntPtr.Zero) Marshal.Release(signature);
            return;
        }

        try
        {
            IntPtr vTable = Marshal.ReadIntPtr(device);
            IntPtr createRootSignaturePtr = Marshal.ReadIntPtr(vTable, 16 * IntPtr.Size);  // vTable #16 ID3D12Device::CreateRootSignature
            var createRootSignature = Marshal.GetDelegateForFunctionPointer<CreateRootSignatureDelegate>(createRootSignaturePtr);

            Guid rootSignatureGuid = IID_ID3D12RootSignature;
            int result = createRootSignature(
                device,
                0,  // nodeMask
                GetBufferPointer(signature),
                (IntPtr)GetBlobSize(signature),
                ref rootSignatureGuid,
                out rootSignature
            );

            if (result < 0)
            {
                Console.WriteLine("Failed to create root signature. HRESULT: " + result);
            }
            else
            {
                Console.WriteLine("Successfully created root signature: " + rootSignature);
            }
        }
        finally
        {
            if (signature != IntPtr.Zero)
            {
                Marshal.Release(signature);
            }
        }

        IntPtr vertexShader, pixelShader;
        vertexShader = CompileShaderFromFile("hello.hlsl", "VSMain", "vs_5_0");
        pixelShader = CompileShaderFromFile("hello.hlsl", "PSMain", "ps_5_0");

        GCHandle inputElementsHandle = default(GCHandle);

        List<GCHandle> semanticNameHandles = new List<GCHandle>();

        D3D12_INPUT_ELEMENT_DESC[] inputElementDescs = new[]
        {
            new D3D12_INPUT_ELEMENT_DESC
            {
                SemanticName = Marshal.StringToHGlobalAnsi("POSITION"),
                SemanticIndex = 0,
                Format = DXGI_FORMAT_R32G32B32_FLOAT,
                InputSlot = 0,
                AlignedByteOffset = 0,
                InputSlotClass = D3D12_INPUT_CLASSIFICATION.D3D12_INPUT_CLASSIFICATION_PER_VERTEX_DATA,
                InstanceDataStepRate = 0
            },
            new D3D12_INPUT_ELEMENT_DESC
            {
                SemanticName = Marshal.StringToHGlobalAnsi("COLOR"),
                SemanticIndex = 0,
                Format = DXGI_FORMAT_R32G32B32A32_FLOAT,
                InputSlot = 0,
                AlignedByteOffset = 12,
                InputSlotClass = D3D12_INPUT_CLASSIFICATION.D3D12_INPUT_CLASSIFICATION_PER_VERTEX_DATA,
                InstanceDataStepRate = 0
            }
        };
        
        inputElementsHandle = GCHandle.Alloc(inputElementDescs, GCHandleType.Pinned);
        IntPtr pInputElementDescs = inputElementsHandle.AddrOfPinnedObject();

        Console.WriteLine("Pinned input layout pointer: " + pInputElementDescs);

        D3D12_GRAPHICS_PIPELINE_STATE_DESC psoDesc = new D3D12_GRAPHICS_PIPELINE_STATE_DESC
        {
            pRootSignature = rootSignature,
            VS = new D3D12_SHADER_BYTECODE { pShaderBytecode = GetBufferPointer(vertexShader), BytecodeLength = (IntPtr)GetBlobSize(vertexShader) },
            PS = new D3D12_SHADER_BYTECODE { pShaderBytecode = GetBufferPointer(pixelShader), BytecodeLength = (IntPtr)GetBlobSize(pixelShader) },
            BlendState = CD3DX12_BLEND_DESC.Default(),
            SampleMask = uint.MaxValue,
            RasterizerState = CD3DX12_RASTERIZER_DESC.Default(),
            DepthStencilState = CD3DX12_DEPTH_STENCIL_DESC.Default(),
            InputLayout = new D3D12_INPUT_LAYOUT_DESC 
            { 
                pInputElementDescs = pInputElementDescs,
                NumElements = (uint)inputElementDescs.Length 
            },
            PrimitiveTopologyType = D3D12_PRIMITIVE_TOPOLOGY_TYPE.D3D12_PRIMITIVE_TOPOLOGY_TYPE_TRIANGLE,
            NumRenderTargets = 1,
            RTVFormats = new uint[8] { DXGI_FORMAT_R8G8B8A8_UNORM, 0, 0, 0, 0, 0, 0, 0 },
            DSVFormat = DXGI_FORMAT_UNKNOWN,
            SampleDesc = new DXGI_SAMPLE_DESC { Count = 1, Quality = 0 },
            NodeMask = 0
        };

        Console.WriteLine("----------------------------------------");
        Console.WriteLine("[CreateGraphicsPipelineState] - Start");

        if (psoDesc.RTVFormats != null)
        {
            for (int i = 0; i < Math.Min(8, psoDesc.RTVFormats.Length); i++)
            {
                Console.WriteLine("  RTVFormat[" + i + "]: " + psoDesc.RTVFormats[i]);
            }
        }
        else
        {
            Console.WriteLine("  RTVFormats array is null");
        }

        try
        {
            IntPtr vTable = Marshal.ReadIntPtr(device);
            IntPtr createPipelineStatePtr = Marshal.ReadIntPtr(vTable, 10 * IntPtr.Size); // vTable #10 ID3D12Device::CreateGraphicsPipelineState
            var createPipelineState = Marshal.GetDelegateForFunctionPointer<CreateGraphicsPipelineStateDelegate>(createPipelineStatePtr);

            Guid pipelineStateGuid = IID_ID3D12PipelineState;
            int result = createPipelineState(
                device,
                ref psoDesc,
                ref pipelineStateGuid,
                out pipelineState
            );

            if (result < 0)
            {
                Console.WriteLine("Failed to create graphics pipeline state. HRESULT: " + result);
            }
            else
            {
                Console.WriteLine("Successfully created pipeline state: " + pipelineState);
            }
        }
        catch (Exception ex)
        {
            Console.WriteLine("Error creating pipeline state: " + ex.Message);
            Console.WriteLine("Stack trace: " + ex.StackTrace);
            pipelineState = IntPtr.Zero;
        }

        Console.WriteLine("[CreateCommandList using vtable] - Start");

        try
        {
            IntPtr vTable = Marshal.ReadIntPtr(device);
            IntPtr createCommandListPtr = Marshal.ReadIntPtr(vTable, 12 * IntPtr.Size); // vTable #12 ID3D12Device::CreateCommandList
            var createCommandList = Marshal.GetDelegateForFunctionPointer<CreateCommandListDelegate>(createCommandListPtr);

            Guid commandListGuid = IID_ID3D12GraphicsCommandList;

            int result = createCommandList(
                device,
                0,  // nodeMask
                D3D12_COMMAND_LIST_TYPE.D3D12_COMMAND_LIST_TYPE_DIRECT,
                commandAllocator,
                pipelineState,
                ref commandListGuid,
                out commandList
            );

            if (result < 0)
            {
                Console.WriteLine("Failed to create command list. HRESULT: " + result);
            }
            else
            {
                Console.WriteLine("Successfully created command list: " + commandList);
                
                try
                {
                    vTable = Marshal.ReadIntPtr(commandList);
                    IntPtr closePtr = Marshal.ReadIntPtr(vTable, 9 * IntPtr.Size);  // vTable #9 ID3D12GraphicsCommandList::Close
                    var close = Marshal.GetDelegateForFunctionPointer<CloseDelegate>(closePtr);
                    int closeResult = close(commandList);

                    Console.WriteLine("Close result: " + closeResult);
                }
                catch (Exception ex)
                {
                    Console.WriteLine("Error in Close: " + ex.Message);
                    Console.WriteLine("Stack trace: " + ex.StackTrace);
                }
            }
        }
        catch (Exception ex)
        {
            Console.WriteLine("Error creating command list: " + ex.Message);
            Console.WriteLine("Stack trace: " + ex.StackTrace);
            commandList = IntPtr.Zero;
        }

        float aspectRatio = 800.0f / 600.0f;
        Vertex[] triangleVertices = new[]
        {
            new Vertex { X =  0.0f, Y =  0.5f * aspectRatio, Z = 0.0f, R = 1.0f, G = 0.0f, B = 0.0f, A = 1.0f },
            new Vertex { X =  0.5f, Y = -0.5f * aspectRatio, Z = 0.0f, R = 0.0f, G = 1.0f, B = 0.0f, A = 1.0f },
            new Vertex { X = -0.5f, Y = -0.5f * aspectRatio, Z = 0.0f, R = 0.0f, G = 0.0f, B = 1.0f, A = 1.0f }
        };

        uint vertexBufferSize = (uint)(Marshal.SizeOf<Vertex>() * triangleVertices.Length);

        D3D12_HEAP_PROPERTIES heapProps = new D3D12_HEAP_PROPERTIES {
            Type = D3D12_HEAP_TYPE.D3D12_HEAP_TYPE_UPLOAD,
            CPUPageProperty = D3D12_CPU_PAGE_PROPERTY.D3D12_CPU_PAGE_PROPERTY_UNKNOWN,
            MemoryPoolPreference = D3D12_MEMORY_POOL.D3D12_MEMORY_POOL_UNKNOWN
        };

        D3D12_RESOURCE_DESC resourceDesc = new D3D12_RESOURCE_DESC
        {
            Dimension = D3D12_RESOURCE_DIMENSION.D3D12_RESOURCE_DIMENSION_BUFFER,
            Width = vertexBufferSize,
            Height = 1,
            DepthOrArraySize = 1,
            MipLevels = 1,
            Format = DXGI_FORMAT_UNKNOWN,
            SampleDesc = new DXGI_SAMPLE_DESC { Count = 1, Quality = 0 },
            Layout = D3D12_TEXTURE_LAYOUT.D3D12_TEXTURE_LAYOUT_ROW_MAJOR,
            Flags = D3D12_RESOURCE_FLAGS.D3D12_RESOURCE_FLAG_NONE
        };

        Console.WriteLine("[CreateCommittedResource using vtable] - Start");
        Guid resourceGuid = IID_ID3D12Resource;
        
        try
        {
            IntPtr vTable = Marshal.ReadIntPtr(device);
            IntPtr createResourcePtr = Marshal.ReadIntPtr(vTable, 27 * IntPtr.Size); // vTable #27 ID3D12Device::CreateCommittedResource
            var createResource = Marshal.GetDelegateForFunctionPointer<CreateCommittedResourceDelegate>(createResourcePtr);

            int result = createResource(
                device,
                ref heapProps,
                D3D12_HEAP_FLAGS.D3D12_HEAP_FLAG_NONE,
                ref resourceDesc,
                D3D12_RESOURCE_STATES.D3D12_RESOURCE_STATE_GENERIC_READ,
                IntPtr.Zero,
                ref resourceGuid,
                out vertexBuffer
            );

            if (result < 0)
            {
                Console.WriteLine("Failed to create committed resource. HRESULT: " + result);
            }
            else
            {
                Console.WriteLine("Successfully created vertex buffer: " + vertexBuffer);
            }
        }
        catch (Exception ex)
        {
            Console.WriteLine("Error creating committed resource: " + ex.Message);
            Console.WriteLine("Stack trace: " + ex.StackTrace);
            vertexBuffer = IntPtr.Zero;
        }

        try
        {
            IntPtr pData;
            D3D12_RANGE readRange = new D3D12_RANGE { Begin = 0, End = 0 };

            IntPtr vTable = Marshal.ReadIntPtr(vertexBuffer);
            IntPtr mapPtr = Marshal.ReadIntPtr(vTable, 8 * IntPtr.Size);  // vTable #8 ID3D12Resource::Map
            var map = Marshal.GetDelegateForFunctionPointer<MapDelegate>(mapPtr);
            int result = map(vertexBuffer, 0, ref readRange, out pData);

            byte[] vertexData = StructArrayToByteArray(triangleVertices);
            Marshal.Copy(vertexData, 0, pData, (int)vertexBufferSize);

            D3D12_RANGE emptyRange = new D3D12_RANGE { Begin = 0, End = 0 };
            IntPtr unmapPtr = Marshal.ReadIntPtr(vTable, 9 * IntPtr.Size); // vTable #9 ID3D12Resource::Unmap
            var unmap = Marshal.GetDelegateForFunctionPointer<UnmapDelegate>(unmapPtr);
            unmap(vertexBuffer, 0, ref emptyRange);
        }
        catch (Exception ex)
        {
            Console.WriteLine("Error Map/Unmap: " + ex.Message);
            Console.WriteLine("Stack trace: " + ex.StackTrace);
        }


        try
        {
            IntPtr vTable = Marshal.ReadIntPtr(vertexBuffer);
            IntPtr getGPUVirtualAddressPtr = Marshal.ReadIntPtr(vTable, 11 * IntPtr.Size);  // vTable #11 ID3D12Resource::GetGPUVirtualAddress
            var getGPUVirtualAddress = Marshal.GetDelegateForFunctionPointer<GetGPUVirtualAddressDelegate>(getGPUVirtualAddressPtr);

            vertexBufferView = new D3D12_VERTEX_BUFFER_VIEW
            {
                BufferLocation = getGPUVirtualAddress(vertexBuffer),
                StrideInBytes = (uint)Marshal.SizeOf<Vertex>(),
                SizeInBytes = vertexBufferSize
            };
        }
        catch (Exception ex)
        {
            Console.WriteLine("Error GetGPUVirtualAddress: " + ex.Message);
            Console.WriteLine("Stack trace: " + ex.StackTrace);
            fence = IntPtr.Zero;
        }

        Console.WriteLine("[CreateFence using vtable] - Start");

        try
        {
            IntPtr vTable = Marshal.ReadIntPtr(device);
            IntPtr createFencePtr = Marshal.ReadIntPtr(vTable, 36 * IntPtr.Size); // vTable #36 ID3D12Device::CreateFence
            var createFence = Marshal.GetDelegateForFunctionPointer<CreateFenceDelegate>(createFencePtr);

            Guid fenceGuid = IID_ID3D12Fence;
            int result = createFence(
                device,
                0,  // InitialValue
                D3D12_FENCE_FLAGS.D3D12_FENCE_FLAG_NONE,
                ref fenceGuid,
                out fence
            );

            if (result < 0)
            {
                Console.WriteLine("Failed to create fence. HRESULT: " + result);
            }
            else
            {
                Console.WriteLine("Successfully created fence: " + fence);
                
                fenceValue = 1;
                fenceEvent = CreateEvent(IntPtr.Zero, false, false, null);
                
                if (fenceEvent == IntPtr.Zero)
                {
                    Console.WriteLine("Failed to create fence event. Last error: " + Marshal.GetLastWin32Error());
                }
            }
        }
        catch (Exception ex)
        {
            Console.WriteLine("Error creating fence: " + ex.Message);
            Console.WriteLine("Stack trace: " + ex.StackTrace);
            fence = IntPtr.Zero;
        }

    }

    private void PopulateCommandList()
    {
        //Console.WriteLine("----------------------------------------");
        //Console.WriteLine("[WaitForPreviousFrame] - Start");

        try
        {
           IntPtr allocatorVTable = Marshal.ReadIntPtr(commandAllocator);
           IntPtr resetAllocatorPtr = Marshal.ReadIntPtr(allocatorVTable, 8 * IntPtr.Size);  // vTable ID3D12CommandAllocator::Reset
           var resetAllocator = Marshal.GetDelegateForFunctionPointer<ResetCommandAllocatorDelegate>(resetAllocatorPtr);
           int resetResult = resetAllocator(commandAllocator);
           
           if (resetResult < 0)
           {
               Console.WriteLine("Failed to reset command allocator. HRESULT: " + resetResult);
               return;
           }

           IntPtr vTable = Marshal.ReadIntPtr(commandList);
           IntPtr resetPtr = Marshal.ReadIntPtr(vTable, 10 * IntPtr.Size);  // vTable #10 ID3D12GraphicsCommandList::Reset
           var reset = Marshal.GetDelegateForFunctionPointer<ResetCommandListDelegate>(resetPtr);
           int result = reset(commandList, commandAllocator, pipelineState);

           if (result < 0)
           {
               Console.WriteLine("Failed to reset command list. HRESULT: " + result);
               return;
           }

           IntPtr setRootSigPtr = Marshal.ReadIntPtr(vTable, 30 * IntPtr.Size);  // vTable #30 ID3D12GraphicsCommandList::SetGraphicsRootSignature
           var setRootSig = Marshal.GetDelegateForFunctionPointer<SetGraphicsRootSignatureDelegate>(setRootSigPtr);
           setRootSig(commandList, rootSignature);

           var viewports = new D3D12_VIEWPORT[]
           {
               new D3D12_VIEWPORT
               {
                   TopLeftX = 0,
                   TopLeftY = 0,
                   Width = 800,
                   Height = 600,
                   MinDepth = 0.0f,
                   MaxDepth = 1.0f
               }
           };

           IntPtr setViewportsPtr = Marshal.ReadIntPtr(vTable, 21 * IntPtr.Size);  // vTable #21 ID3D12GraphicsCommandList::RSSetViewports
           var rsSetViewports = Marshal.GetDelegateForFunctionPointer<RSSetViewportsDelegate>(setViewportsPtr);
           rsSetViewports(commandList, 1, viewports);

           var scissorRects = new D3D12_RECT[]
           {
               new D3D12_RECT
               {
                   left = 0,
                   top = 0,
                   right = 800,
                   bottom = 600
               }
           };

           IntPtr setScissorRectsPtr = Marshal.ReadIntPtr(vTable, 22 * IntPtr.Size);  // vTable #22 ID3D12GraphicsCommandList::RSSetScissorRects
           var setScissorRects = Marshal.GetDelegateForFunctionPointer<RSSetScissorRectsDelegate>(setScissorRectsPtr);
           setScissorRects(commandList, 1, scissorRects);

           // PRESENT -> RENDER_TARGET
           var barrierDesc = CD3DX12_RESOURCE_BARRIER.Transition(
               renderTargets[frameIndex],
               D3D12_RESOURCE_STATES.D3D12_RESOURCE_STATE_PRESENT,
               D3D12_RESOURCE_STATES.D3D12_RESOURCE_STATE_RENDER_TARGET);

           IntPtr resourceBarrierPtr = Marshal.ReadIntPtr(vTable, 26 * IntPtr.Size);  // vTable #26 ID3D12GraphicsCommandList::ResourceBarrier
           var resourceBarrier = Marshal.GetDelegateForFunctionPointer<ResourceBarrierDelegate>(resourceBarrierPtr);
           resourceBarrier(commandList, 1, new D3D12_RESOURCE_BARRIER[] { barrierDesc });

           D3D12_CPU_DESCRIPTOR_HANDLE rtvHandle = new D3D12_CPU_DESCRIPTOR_HANDLE
           {
               ptr = GetCPUDescriptorHandleForHeapStart(rtvHeap) + frameIndex * (int)rtvDescriptorSize
           };

           var rtvHandleArray = new[] { new D3D12_CPU_DESCRIPTOR_HANDLE_ARRAY { ptr = rtvHandle.ptr } };
           GCHandle handleArray = GCHandle.Alloc(rtvHandleArray, GCHandleType.Pinned);
           try
           {
               IntPtr setRenderTargetsPtr = Marshal.ReadIntPtr(vTable, 46 * IntPtr.Size);  // vTable #46 ID3D12GraphicsCommandList::OMSetRenderTargets
               var omSetRenderTargets = Marshal.GetDelegateForFunctionPointer<OMSetRenderTargetsDelegate>(setRenderTargetsPtr);
               omSetRenderTargets(commandList, 1, rtvHandleArray, false, IntPtr.Zero);
           }
           finally
           {
               if (handleArray.IsAllocated)
                   handleArray.Free();
           }

           float[] clearColor = new float[] { 0.0f, 0.2f, 0.4f, 1.0f };
           IntPtr clearRtvPtr = Marshal.ReadIntPtr(vTable, 48 * IntPtr.Size);  // vTable #48 ID3D12GraphicsCommandList::ClearRenderTargetView
           var clearRtv = Marshal.GetDelegateForFunctionPointer<ClearRenderTargetViewDelegate>(clearRtvPtr);
           clearRtv(commandList, rtvHandle, clearColor, 0, IntPtr.Zero);

           IntPtr setPrimTopoPtr = Marshal.ReadIntPtr(vTable, 20 * IntPtr.Size); // vTable #20 ID3D12GraphicsCommandList::IASetPrimitiveTopology
           var setPrimTopo = Marshal.GetDelegateForFunctionPointer<IASetPrimitiveTopologyDelegate>(setPrimTopoPtr);
           setPrimTopo(commandList, D3D_PRIMITIVE_TOPOLOGY.D3D_PRIMITIVE_TOPOLOGY_TRIANGLELIST);

           IntPtr setVBPtr = Marshal.ReadIntPtr(vTable, 44 * IntPtr.Size);  // vTable #44 ID3D12GraphicsCommandList::IASetVertexBuffers
           var setVB = Marshal.GetDelegateForFunctionPointer<IASetVertexBuffersDelegate>(setVBPtr);
           setVB(commandList, 0, 1, new[] { vertexBufferView });

           IntPtr drawPtr = Marshal.ReadIntPtr(vTable, 12 * IntPtr.Size);  // vTable #12 ID3D12GraphicsCommandList::DrawInstanced
           var draw = Marshal.GetDelegateForFunctionPointer<DrawInstancedDelegate>(drawPtr);
           draw(commandList, 3, 1, 0, 0);

           // RENDER_TARGET -> PRESENT
           barrierDesc = CD3DX12_RESOURCE_BARRIER.Transition(
               renderTargets[frameIndex],
               D3D12_RESOURCE_STATES.D3D12_RESOURCE_STATE_RENDER_TARGET,
               D3D12_RESOURCE_STATES.D3D12_RESOURCE_STATE_PRESENT);
           
           resourceBarrier(commandList, 1, new D3D12_RESOURCE_BARRIER[] { barrierDesc });

           IntPtr closePtr = Marshal.ReadIntPtr(vTable, 9 * IntPtr.Size);  // vTable #9 ID3D12GraphicsCommandList::Close
           var close = Marshal.GetDelegateForFunctionPointer<CloseDelegate>(closePtr);
           result = close(commandList);
       }
       catch (Exception ex)
       {
           Console.WriteLine("Error in PopulateCommandList: " + ex.Message);
           Console.WriteLine("Stack trace: " + ex.StackTrace);
       }
    }

    private void WaitForPreviousFrame()
    {
        //Console.WriteLine("----------------------------------------");
        //Console.WriteLine("[WaitForPreviousFrame] - Start");

        try
        {
            IntPtr vTable = Marshal.ReadIntPtr(commandQueue);
            IntPtr signalPtr = Marshal.ReadIntPtr(vTable, 14 * IntPtr.Size);  // vTable #14 ID3D12CommandQueue::Signal
            var signal = Marshal.GetDelegateForFunctionPointer<SignalDelegate>(signalPtr);
            int result = signal(commandQueue, fence, fenceValue);

            if (result < 0)
            {
                Console.WriteLine("Signal failed with HRESULT: " + result);
                return;
            }

            IntPtr fenceVTable = Marshal.ReadIntPtr(fence);
            IntPtr getCompletedValuePtr = Marshal.ReadIntPtr(fenceVTable, 8 * IntPtr.Size);  // vTable #8 ID3D12Fence::GetCompletedValue
            var getCompletedValue = Marshal.GetDelegateForFunctionPointer<GetCompletedValueDelegate>(getCompletedValuePtr);

            if (getCompletedValue(fence) < fenceValue)
            {
                IntPtr setEventPtr = Marshal.ReadIntPtr(fenceVTable, 9 * IntPtr.Size);  // vTable #9 ID3D12Fence::SetEventOnCompletion
                var setEvent = Marshal.GetDelegateForFunctionPointer<SetEventOnCompletionDelegate>(setEventPtr);
                result = setEvent(fence, fenceValue, fenceEvent);
                
                if (result < 0)
                {
                    Console.WriteLine("SetEventOnCompletion failed with HRESULT: " + result);
                    return;
                }

                WaitForSingleObject(fenceEvent, INFINITE);
            }

            fenceValue++;
        }
        catch (Exception ex)
        {
            Console.WriteLine("Error in WaitForPreviousFrame: " + ex.Message);
            Console.WriteLine("Stack trace: " + ex.StackTrace);
        }
    }

    public void Render()
    {
       //Console.WriteLine("----------------------------------------");
       //Console.WriteLine("[Render] - Start");

       try
       {
           PopulateCommandList();

           IntPtr[] commandLists = { commandList };
           IntPtr vTable = Marshal.ReadIntPtr(commandQueue);
           IntPtr executePtr = Marshal.ReadIntPtr(vTable, 10 * IntPtr.Size);  // vTable #10 ID3D12CommandQueue::ExecuteCommandLists
           var executeCommandLists = Marshal.GetDelegateForFunctionPointer<ExecuteCommandListsDelegate>(executePtr);
           executeCommandLists(commandQueue, 1, commandLists);

           vTable = Marshal.ReadIntPtr(swapChain);
           IntPtr presentPtr = Marshal.ReadIntPtr(vTable, 8 * IntPtr.Size);  // vTable #8 IDXGISwapChain::Present
           var present = Marshal.GetDelegateForFunctionPointer<PresentDelegate>(presentPtr);
           int result = present(swapChain, 0, 0);

           if (result < 0)
           {
               //Console.WriteLine("Present failed with HRESULT: " + result);
               return;
           }

           WaitForPreviousFrame();
       }
       catch (Exception ex)
       {
           Console.WriteLine("Error in Render: " + ex.Message);
           Console.WriteLine("Stack trace: " + ex.StackTrace);
       }
    }

    private void CleanupDevice()
    {
        Console.WriteLine("----------------------------------------");
        Console.WriteLine("[CleanupDevice] - Start");

        CloseHandle(fenceEvent);

        if (fence != IntPtr.Zero) Marshal.Release(fence);
        if (vertexBuffer != IntPtr.Zero) Marshal.Release(vertexBuffer);
        if (pipelineState != IntPtr.Zero) Marshal.Release(pipelineState);
        if (rootSignature != IntPtr.Zero) Marshal.Release(rootSignature);
        if (commandList != IntPtr.Zero) Marshal.Release(commandList);
        if (commandAllocator != IntPtr.Zero) Marshal.Release(commandAllocator);
        if (rtvHeap != IntPtr.Zero) Marshal.Release(rtvHeap);
        
        foreach (var rt in renderTargets)
        {
            if (rt != IntPtr.Zero) Marshal.Release(rt);
        }
        
        if (swapChain != IntPtr.Zero) Marshal.Release(swapChain);
        if (commandQueue != IntPtr.Zero) Marshal.Release(commandQueue);
        if (device != IntPtr.Zero) Marshal.Release(device);
    }

    private void LoadPipeline(IntPtr hwnd)
    {
       Console.WriteLine("----------------------------------------");
       Console.WriteLine("[LoadPipeline] - Start");

       try
       {
            IntPtr debugInterface;
            Guid debugGuid = IID_ID3D12Debug;
            int debugResult = D3D12GetDebugInterface(ref debugGuid, out debugInterface);
            if (debugResult >= 0 && debugInterface != IntPtr.Zero)
            {
                Console.WriteLine("Enabling debug layer...");
                ID3D12Debug debug = Marshal.GetObjectForIUnknown(debugInterface) as ID3D12Debug;
                debug.EnableDebugLayer();
                Marshal.ReleaseComObject(debug);
            }
            else
            {
                Console.WriteLine("Failed to get debug interface: " + debugResult);
            }

           IntPtr factory = IntPtr.Zero;
           Guid factoryIID = IID_IDXGIFactory4;
           int result = CreateDXGIFactory2(0, ref factoryIID, out factory);
           if (result < 0)
           {
               throw new Exception("Failed to create DXGI Factory2: " + result);
           }

           Guid deviceGuid = IID_ID3D12Device;
           result = D3D12CreateDevice(IntPtr.Zero, D3D_FEATURE_LEVEL_11_0, ref deviceGuid, out device);
           if (result < 0)
           {
               throw new Exception("Failed to create D3D12 Device: " + result);
           }

           D3D12_COMMAND_QUEUE_DESC queueDesc = new D3D12_COMMAND_QUEUE_DESC
           {
               Type = D3D12_COMMAND_LIST_TYPE.D3D12_COMMAND_LIST_TYPE_DIRECT,
               Priority = 0,
               Flags = D3D12_COMMAND_QUEUE_FLAGS.D3D12_COMMAND_QUEUE_FLAG_NONE,
               NodeMask = 0
           };

           IntPtr vTable = Marshal.ReadIntPtr(device);
           IntPtr createCommandQueuePtr = Marshal.ReadIntPtr(vTable, 8 * IntPtr.Size);  // vTable #8 ID3D12Device::CreateCommandQueue
           var createCommandQueue = Marshal.GetDelegateForFunctionPointer<CreateCommandQueueDelegate>(createCommandQueuePtr);
           Guid queueGuid = IID_ID3D12CommandQueue;
           result = createCommandQueue(device, ref queueDesc, ref queueGuid, out commandQueue);
           if (result < 0)
           {
               throw new Exception("Failed to create Command Queue: " + result);
           }

            swapChainDesc1 = new DXGI_SWAP_CHAIN_DESC1
            {
                Width = 800,
                Height = 600,
                Format = DXGI_FORMAT_R8G8B8A8_UNORM,
                Stereo = false,
                SampleDesc = new DXGI_SAMPLE_DESC { Count = 1, Quality = 0 },
                BufferUsage = DXGI_USAGE_RENDER_TARGET_OUTPUT,
                BufferCount = FrameCount,
                Scaling = DXGI_SCALING.DXGI_SCALING_STRETCH,
                SwapEffect = DXGI_SWAP_EFFECT_FLIP_DISCARD,
                AlphaMode = DXGI_ALPHA_MODE.DXGI_ALPHA_MODE_UNSPECIFIED,
                Flags = DXGI_SWAP_CHAIN_FLAG_ALLOW_MODE_SWITCH | DXGI_SWAP_CHAIN_FLAG_FRAME_LATENCY_WAITABLE_OBJECT
            };

           result = CreateSwapChainForHwnd(factory, commandQueue, hwnd, ref swapChainDesc1, IntPtr.Zero, IntPtr.Zero, out swapChain);
           if (result < 0)
           {
               throw new Exception("Failed to create Swap Chain: " + result);
           }

           D3D12_DESCRIPTOR_HEAP_DESC rtvHeapDesc = new D3D12_DESCRIPTOR_HEAP_DESC
           {
               Type = D3D12_DESCRIPTOR_HEAP_TYPE.D3D12_DESCRIPTOR_HEAP_TYPE_RTV,
               NumDescriptors = FrameCount,
               Flags = D3D12_DESCRIPTOR_HEAP_FLAGS.D3D12_DESCRIPTOR_HEAP_FLAG_NONE,
               NodeMask = 0
           };

           Guid heapGuid = IID_ID3D12DescriptorHeap;
           vTable = Marshal.ReadIntPtr(device);
           IntPtr createHeapPtr = Marshal.ReadIntPtr(vTable, 14 * IntPtr.Size);  // vTable #14 ID3D12Device::CreateDescriptorHeap
           var createHeap = Marshal.GetDelegateForFunctionPointer<CreateDescriptorHeapDelegate>(createHeapPtr);
           result = createHeap(device, ref rtvHeapDesc, ref heapGuid, out rtvHeap);
           if (result < 0)
           {
               throw new Exception("Failed to create Descriptor Heap: " + result);
           }

           IntPtr getIncrementPtr = Marshal.ReadIntPtr(vTable, 15 * IntPtr.Size);  // vTable #15 ID3D12Device::GetDescriptorHandleIncrementSize
           var getIncrement = Marshal.GetDelegateForFunctionPointer<GetDescriptorHandleIncrementSizeDelegate>(getIncrementPtr);
           rtvDescriptorSize = getIncrement(device, D3D12_DESCRIPTOR_HEAP_TYPE.D3D12_DESCRIPTOR_HEAP_TYPE_RTV);

           D3D12_CPU_DESCRIPTOR_HANDLE rtvHandle = new D3D12_CPU_DESCRIPTOR_HANDLE
           {
               ptr = GetCPUDescriptorHandleForHeapStart(rtvHeap)
           };

           for (int i = 0; i < FrameCount; i++)
           {
               IntPtr swapChainVTable = Marshal.ReadIntPtr(swapChain);
               IntPtr getBufferPtr = Marshal.ReadIntPtr(swapChainVTable, 9 * IntPtr.Size);  // vTable #9 IDXGISwapChain::GetBuffer
               var getBuffer = Marshal.GetDelegateForFunctionPointer<GetBufferDelegate>(getBufferPtr);

               Guid resourceGuid = IID_ID3D12Resource;
               IntPtr resourcePtr;
               result = getBuffer(swapChain, (uint)i, ref resourceGuid, out resourcePtr);
               if (result < 0)
               {
                   throw new Exception("Failed to get Buffer: " + result);
               }
               renderTargets[i] = resourcePtr;

               vTable = Marshal.ReadIntPtr(device);
               IntPtr createRTVPtr = Marshal.ReadIntPtr(vTable, 20 * IntPtr.Size);  // vTable #20 ID3D12Device::CreateRenderTargetView
               var createRTV = Marshal.GetDelegateForFunctionPointer<CreateRenderTargetViewDelegate>(createRTVPtr);
               createRTV(device, resourcePtr, IntPtr.Zero, rtvHandle);

               var barrierDesc = CD3DX12_RESOURCE_BARRIER.Transition(
                   renderTargets[i],
                   D3D12_RESOURCE_STATES.D3D12_RESOURCE_STATE_PRESENT,
                   D3D12_RESOURCE_STATES.D3D12_RESOURCE_STATE_COMMON);

               rtvHandle.ptr += (int)rtvDescriptorSize;
           }

           vTable = Marshal.ReadIntPtr(device);
           IntPtr createCommandAllocatorPtr = Marshal.ReadIntPtr(vTable, 9 * IntPtr.Size);  // vTable #9 ID3D12Device::CreateCommandAllocator
           var createCommandAllocator = Marshal.GetDelegateForFunctionPointer<CreateCommandAllocatorDelegate>(createCommandAllocatorPtr);
           Guid allocatorGuid = IID_ID3D12CommandAllocator;
           result = createCommandAllocator(device, D3D12_COMMAND_LIST_TYPE.D3D12_COMMAND_LIST_TYPE_DIRECT, ref allocatorGuid, out commandAllocator);
           if (result < 0)
           {
               throw new Exception("Failed to create Command Allocator: " + result);
           }

           Marshal.Release(factory);
       }
       catch (Exception ex)
       {
           Console.WriteLine("Error in LoadPipeline: " + ex.Message);
           Console.WriteLine("Stack trace: " + ex.StackTrace);
           throw;
       }
    }

    static IntPtr WndProc(IntPtr hWnd, uint uMsg, IntPtr wParam, IntPtr lParam)
    {
        PAINTSTRUCT ps = new PAINTSTRUCT();
        IntPtr hdc;
        string strMessage = "Hello, DirectX11(C#) World!";
 
        switch (uMsg)
        {
            case WM_PAINT:
                hdc = BeginPaint( hWnd, out ps );
                TextOut( hdc, 0, 0, strMessage, strMessage.Length );
                EndPaint( hWnd, ref ps );
                break;
            case WM_DESTROY:
                PostQuitMessage(0);
                break;
            default:
                return DefWindowProc(hWnd, uMsg, wParam, lParam);
        }
 
        return IntPtr.Zero;
    }

    [STAThread]
    public static int Main()
    {
        Console.WriteLine("----------------------------------------");
        Console.WriteLine("[Main] - Start");

        var app = new Hello();
        

        const string CLASS_NAME = "MyDXWindowClass";
        const string WINDOW_NAME = "Helo, World!";

        IntPtr hInstance = Marshal.GetHINSTANCE(typeof(Hello).Module);
        
        var wndClassEx = new WNDCLASSEX
        {
            cbSize = (uint)Marshal.SizeOf(typeof(WNDCLASSEX)),
            style = CS_OWNDC,
            lpfnWndProc = new WndProcDelegate(WndProc),
            cbClsExtra = 0,
            cbWndExtra = 0,
            hInstance = hInstance,
            hIcon = IntPtr.Zero,
            hCursor = LoadCursor(IntPtr.Zero, (int)IDC_ARROW),
            hbrBackground = IntPtr.Zero,
            lpszMenuName = null,
            lpszClassName = CLASS_NAME,
            hIconSm = IntPtr.Zero
        };

        ushort atom = RegisterClassEx(ref wndClassEx);
        int error = Marshal.GetLastWin32Error();
        
        if (atom == 0)
        {
            Console.WriteLine("Failed to register window class. Error: " + error);
            return 0;
        }

        IntPtr hwnd = CreateWindowEx(
            0,
            CLASS_NAME,
            WINDOW_NAME,
            WS_OVERLAPPEDWINDOW | WS_VISIBLE,
            100, 100,
            800, 600,
            IntPtr.Zero,
            IntPtr.Zero,
            hInstance,
            IntPtr.Zero
        );

        try
        {
            app.LoadPipeline(hwnd);
            app.LoadAssets();

            ShowWindow(hwnd, 1); // SW_SHOW

            MSG msg = new MSG();
            while (msg.message != WM_QUIT)
            {
                if (PeekMessage(out msg, IntPtr.Zero, 0, 0, PM_REMOVE))
                {
                    TranslateMessage(ref msg);
                    DispatchMessage(ref msg);
                }
                else
                {
                    app.Render();
                }
            }

            return (int)msg.wParam;
        }
        finally
        {
            app.CleanupDevice();
        }
    }
}
"@
Add-Type -Language CSharp -TypeDefinition $source -ReferencedAssemblies ("System.Drawing", "System.Windows.Forms" )
[void][Hello]::Main()
