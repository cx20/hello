using System;
using System.IO;
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
    const uint D3D_FEATURE_LEVEL_12_1 = 0xc100;
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

    [DllImport("kernel32.dll", CharSet = CharSet.Unicode)]
    static extern void OutputDebugString(string lpOutputString);

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

    private static void Dbg(string func, string state)
    {
        OutputDebugString($"[DXR-CS][{func}] {state}\n");
    }

    private static void DbgHr(string func, string api, int hr)
    {
        OutputDebugString($"[DXR-CS][{func}] {api} hr=0x{hr:X8}\n");
    }


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
        D3D12_RESOURCE_STATE_PREDICATION = 0x200,
        D3D12_RESOURCE_STATE_RAYTRACING_ACCELERATION_STRUCTURE = 0x400000
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

    public enum D3D12_ROOT_PARAMETER_TYPE
    {
        D3D12_ROOT_PARAMETER_TYPE_DESCRIPTOR_TABLE = 0,
        D3D12_ROOT_PARAMETER_TYPE_32BIT_CONSTANTS = 1,
        D3D12_ROOT_PARAMETER_TYPE_CBV = 2,
        D3D12_ROOT_PARAMETER_TYPE_SRV = 3,
        D3D12_ROOT_PARAMETER_TYPE_UAV = 4
    }

    public enum D3D12_SHADER_VISIBILITY
    {
        D3D12_SHADER_VISIBILITY_ALL = 0,
        D3D12_SHADER_VISIBILITY_VERTEX = 1,
        D3D12_SHADER_VISIBILITY_HULL = 2,
        D3D12_SHADER_VISIBILITY_DOMAIN = 3,
        D3D12_SHADER_VISIBILITY_GEOMETRY = 4,
        D3D12_SHADER_VISIBILITY_PIXEL = 5
    }

    public enum D3D12_DESCRIPTOR_RANGE_TYPE
    {
        D3D12_DESCRIPTOR_RANGE_TYPE_SRV = 0,
        D3D12_DESCRIPTOR_RANGE_TYPE_UAV = 1,
        D3D12_DESCRIPTOR_RANGE_TYPE_CBV = 2,
        D3D12_DESCRIPTOR_RANGE_TYPE_SAMPLER = 3
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct D3D12_DESCRIPTOR_RANGE
    {
        public D3D12_DESCRIPTOR_RANGE_TYPE RangeType;
        public uint NumDescriptors;
        public uint BaseShaderRegister;
        public uint RegisterSpace;
        public uint OffsetInDescriptorsFromTableStart;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct D3D12_ROOT_DESCRIPTOR_TABLE
    {
        public uint NumDescriptorRanges;
        public IntPtr pDescriptorRanges;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct D3D12_ROOT_DESCRIPTOR
    {
        public uint ShaderRegister;
        public uint RegisterSpace;
    }

    [StructLayout(LayoutKind.Explicit)]
    public struct D3D12_ROOT_PARAMETER_UNION
    {
        [FieldOffset(0)] public D3D12_ROOT_DESCRIPTOR_TABLE DescriptorTable;
        [FieldOffset(0)] public D3D12_ROOT_DESCRIPTOR Descriptor;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct D3D12_ROOT_PARAMETER
    {
        public D3D12_ROOT_PARAMETER_TYPE ParameterType;
        public D3D12_ROOT_PARAMETER_UNION Union;
        public D3D12_SHADER_VISIBILITY ShaderVisibility;

        public D3D12_ROOT_DESCRIPTOR_TABLE DescriptorTable
        {
            get => Union.DescriptorTable;
            set => Union.DescriptorTable = value;
        }

        public D3D12_ROOT_DESCRIPTOR Descriptor
        {
            get => Union.Descriptor;
            set => Union.Descriptor = value;
        }
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
    struct D3D12_FEATURE_DATA_D3D12_OPTIONS5
    {
        [MarshalAs(UnmanagedType.Bool)] public bool SRVOnlyTiledResourceTier3;
        public uint RenderPassesTier;
        public uint RaytracingTier;
    }

    [StructLayout(LayoutKind.Sequential)]
    struct D3D12_RAYTRACING_GEOMETRY_TRIANGLES_DESC
    {
        public ulong Transform3x4;
        public uint IndexFormat;
        public uint VertexFormat;
        public uint IndexCount;
        public uint VertexCount;
        public ulong IndexBuffer;
        public ulong VertexBuffer_StartAddress;
        public ulong VertexBuffer_StrideInBytes;
    }

    [StructLayout(LayoutKind.Explicit)]
    struct D3D12_RAYTRACING_GEOMETRY_DESC_UNION
    {
        [FieldOffset(0)] public D3D12_RAYTRACING_GEOMETRY_TRIANGLES_DESC Triangles;
    }

    [StructLayout(LayoutKind.Sequential)]
    struct D3D12_RAYTRACING_GEOMETRY_DESC
    {
        public uint Type;
        public uint Flags;
        public D3D12_RAYTRACING_GEOMETRY_DESC_UNION Desc;
    }

    [StructLayout(LayoutKind.Explicit)]
    struct D3D12_BUILD_RAYTRACING_ACCELERATION_STRUCTURE_INPUTS
    {
        [FieldOffset(0)]
        public uint Type;
        [FieldOffset(4)]
        public uint Flags;
        [FieldOffset(8)]
        public uint NumDescs;
        [FieldOffset(12)]
        public uint DescsLayout;
        [FieldOffset(16)]
        public ulong pGeometryDescs;
        [FieldOffset(16)]
        public ulong InstanceDescs;
    }

    [StructLayout(LayoutKind.Sequential)]
    struct D3D12_RAYTRACING_ACCELERATION_STRUCTURE_PREBUILD_INFO
    {
        public ulong ResultDataMaxSizeInBytes;
        public ulong ScratchDataSizeInBytes;
        public ulong UpdateScratchDataSizeInBytes;
    }

    [StructLayout(LayoutKind.Sequential)]
    struct D3D12_BUILD_RAYTRACING_ACCELERATION_STRUCTURE_DESC
    {
        public ulong DestAccelerationStructureData;
        public D3D12_BUILD_RAYTRACING_ACCELERATION_STRUCTURE_INPUTS Inputs;
        public ulong SourceAccelerationStructureData;
        public ulong ScratchAccelerationStructureData;
    }

    [StructLayout(LayoutKind.Sequential)]
    struct D3D12_RAYTRACING_INSTANCE_DESC
    {
        [MarshalAs(UnmanagedType.ByValArray, SizeConst = 12)]
        public float[] Transform;
        public uint InstanceIDMask;
        public uint InstanceContributionAndFlags;
        public ulong AccelerationStructure;
    }

    [StructLayout(LayoutKind.Sequential)]
    struct D3D12_GPU_VIRTUAL_ADDRESS_RANGE
    {
        public ulong StartAddress;
        public ulong SizeInBytes;
    }

    [StructLayout(LayoutKind.Sequential)]
    struct D3D12_GPU_VIRTUAL_ADDRESS_RANGE_AND_STRIDE
    {
        public ulong StartAddress;
        public ulong SizeInBytes;
        public ulong StrideInBytes;
    }

    [StructLayout(LayoutKind.Sequential)]
    struct D3D12_DISPATCH_RAYS_DESC
    {
        public D3D12_GPU_VIRTUAL_ADDRESS_RANGE RayGenerationShaderRecord;
        public D3D12_GPU_VIRTUAL_ADDRESS_RANGE_AND_STRIDE MissShaderTable;
        public D3D12_GPU_VIRTUAL_ADDRESS_RANGE_AND_STRIDE HitGroupTable;
        public D3D12_GPU_VIRTUAL_ADDRESS_RANGE_AND_STRIDE CallableShaderTable;
        public uint Width;
        public uint Height;
        public uint Depth;
    }

    [StructLayout(LayoutKind.Sequential)]
    struct D3D12_STATE_SUBOBJECT
    {
        public uint Type;
        public IntPtr pDesc;
    }

    [StructLayout(LayoutKind.Sequential)]
    struct D3D12_STATE_OBJECT_DESC
    {
        public uint Type;
        public uint NumSubobjects;
        public IntPtr pSubobjects;
    }

    [StructLayout(LayoutKind.Sequential)]
    struct D3D12_DXIL_LIBRARY_DESC
    {
        public D3D12_SHADER_BYTECODE DXILLibrary;
        public uint NumExports;
        public IntPtr pExports;
    }

    [StructLayout(LayoutKind.Sequential)]
    struct D3D12_HIT_GROUP_DESC
    {
        public IntPtr HitGroupExport;
        public uint Type;
        public IntPtr AnyHitShaderImport;
        public IntPtr ClosestHitShaderImport;
        public IntPtr IntersectionShaderImport;
    }

    [StructLayout(LayoutKind.Sequential)]
    struct D3D12_RAYTRACING_SHADER_CONFIG
    {
        public uint MaxPayloadSizeInBytes;
        public uint MaxAttributeSizeInBytes;
    }

    [StructLayout(LayoutKind.Sequential)]
    struct D3D12_GLOBAL_ROOT_SIGNATURE
    {
        public IntPtr pGlobalRootSignature;
    }

    [StructLayout(LayoutKind.Sequential)]
    struct D3D12_RAYTRACING_PIPELINE_CONFIG
    {
        public uint MaxTraceRecursionDepth;
    }

    [StructLayout(LayoutKind.Sequential)]
    struct D3D12_UNORDERED_ACCESS_VIEW_DESC
    {
        public uint Format;
        public uint ViewDimension;
        public uint Texture2D_MipSlice;
        public uint Texture2D_PlaneSlice;
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
    static readonly Guid IID_ID3D12Device5  = new Guid("8b4f173b-2fea-4b80-8f58-4307191ab95d");
    static readonly Guid IID_ID3D12Resource = new Guid("696442be-a72e-4059-bc79-5b5c98040fad");

    static readonly Guid IID_ID3D12PipelineState       = new Guid("765a30f3-f624-4c6f-a828-ace948622445");
    static readonly Guid IID_ID3D12GraphicsCommandList = new Guid("5b160d0f-ac1b-4185-8ba8-b3ae42a5a455");
    static readonly Guid IID_ID3D12GraphicsCommandList4 = new Guid("8754318e-d3a9-4541-98cf-645b50dc4874");
    static readonly Guid IID_ID3D12Fence               = new Guid("0a753dcf-c4d8-4b91-adf6-be5a60d95a76");
    static readonly Guid IID_ID3D12CommandQueue        = new Guid("0ec870a6-5d7e-4c22-8cfc-5baae07616ed");
    static readonly Guid IID_ID3D12DescriptorHeap      = new Guid("8efb471d-616c-4f49-90f7-127bb763fa51");
    static readonly Guid IID_ID3D12CommandAllocator    = new Guid("6102dee4-af59-4b09-b999-b44d73f09b24");
    static readonly Guid IID_ID3D12RootSignature       = new Guid("c54a6b66-72df-4ee8-8be5-a946a1429214");
    static readonly Guid IID_ID3D12StateObject         = new Guid("47016943-fca8-4594-93ea-af258b55346d");
    static readonly Guid IID_ID3D12StateObjectProperties = new Guid("de5fa827-9bf9-4f26-89ff-d7f56fde3860");
    static readonly Guid IID_ID3DBlob                  = new Guid("8ba5fb08-5195-40e2-ac58-0d989c3a0102");

    static readonly Guid IID_IDXGIFactory    = new Guid("7b7166ec-21c7-44ae-b21a-c9ae321ae369");
    static readonly Guid IID_IDXGIFactory1   = new Guid("770aae78-f26f-4dba-a829-253c83d1b387");
    static readonly Guid IID_IDXGIFactory2   = new Guid("50c83a1c-e072-4c48-87b0-3630fa36a6d0");
    static readonly Guid IID_IDXGIFactory3   = new Guid("25483823-cd46-4c7d-86ca-47aa95b837bd");
    static readonly Guid IID_IDXGIFactory4   = new Guid("1bc6ea02-ef36-464f-bf0c-21ca39e5168a");
    static readonly Guid IID_IDXGIAdapter1   = new Guid("29038f61-3839-4626-91fd-086879011a05");

    static readonly Guid IID_IDXGISwapChain1 = new Guid("790a45f7-0d42-4876-983a-0a55cfe6f4aa");
    static readonly Guid IID_IDXGISwapChain2 = new Guid("a8be2ac4-199f-4946-b331-79599fb98de7");
    static readonly Guid IID_IDXGISwapChain3 = new Guid("94d99bdb-f1f8-4ab0-b236-7da0170edab1");

    // #10 IDXGIFactory::CreateSwapChain
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    private delegate int CreateSwapChainDelegate(IntPtr factory, IntPtr pDevice, [In] ref DXGI_SWAP_CHAIN_DESC pDesc, out IntPtr ppSwapChain);

    // #15 IDXGIFactory2::CreateSwapChainForHwnd
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    private delegate int CreateSwapChainForHwndDelegate(IntPtr factory, IntPtr pDevice, IntPtr hWnd, [In] ref DXGI_SWAP_CHAIN_DESC1 pDesc, IntPtr pFullscreenDesc, IntPtr pRestrictToOutput, out IntPtr ppSwapChain);

    // #12 IDXGIFactory1::EnumAdapters1
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    private delegate int EnumAdapters1Delegate(IntPtr factory, uint adapterIndex, out IntPtr ppAdapter);

    // #27 IDXGIFactory4::EnumWarpAdapter
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    private delegate int EnumWarpAdapterDelegate(IntPtr factory, ref Guid riid, out IntPtr ppvAdapter);

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

    // #17 ID3D12GraphicsCommandList::CopyResource
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    private delegate void CopyResourceDelegate(IntPtr commandList, IntPtr dstResource, IntPtr srcResource);

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

    // #10 ID3D12DescriptorHeap::GetGPUDescriptorHandleForHeapStart
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    private delegate void GetGPUDescriptorHandleForHeapStartDelegate(IntPtr descriptorHeap, out D3D12_GPU_DESCRIPTOR_HANDLE handle);

    // #13 ID3D12Device::CheckFeatureSupport
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    private delegate int CheckFeatureSupportDelegate(IntPtr device, uint feature, ref D3D12_FEATURE_DATA_D3D12_OPTIONS5 data, uint size);

    // #19 ID3D12Device::CreateUnorderedAccessView
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    private delegate void CreateUnorderedAccessViewDelegate(IntPtr device, IntPtr resource, IntPtr counterResource, ref D3D12_UNORDERED_ACCESS_VIEW_DESC desc, D3D12_CPU_DESCRIPTOR_HANDLE handle);

    // #62 ID3D12Device5::CreateStateObject
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    private delegate int CreateStateObjectDelegate(IntPtr device, ref D3D12_STATE_OBJECT_DESC desc, ref Guid riid, out IntPtr stateObject);

    // #63 ID3D12Device5::GetRaytracingAccelerationStructurePrebuildInfo
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    private delegate void GetRaytracingAccelerationStructurePrebuildInfoDelegate(IntPtr device, ref D3D12_BUILD_RAYTRACING_ACCELERATION_STRUCTURE_INPUTS desc, out D3D12_RAYTRACING_ACCELERATION_STRUCTURE_PREBUILD_INFO info);

    // #72 ID3D12GraphicsCommandList4::BuildRaytracingAccelerationStructure
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    private delegate void BuildRaytracingAccelerationStructureDelegate(IntPtr commandList, ref D3D12_BUILD_RAYTRACING_ACCELERATION_STRUCTURE_DESC desc, uint numPostBuildInfoDescs, IntPtr postBuildInfoDescs);

    // #28 ID3D12GraphicsCommandList::SetDescriptorHeaps
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    private delegate void SetDescriptorHeapsDelegate(IntPtr commandList, uint numHeaps, [In] IntPtr[] heaps);

    // #29 ID3D12GraphicsCommandList::SetComputeRootSignature
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    private delegate void SetComputeRootSignatureDelegate(IntPtr commandList, IntPtr rootSig);

    // #31 ID3D12GraphicsCommandList::SetComputeRootDescriptorTable
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    private delegate void SetComputeRootDescriptorTableDelegate(IntPtr commandList, uint rootParameterIndex, D3D12_GPU_DESCRIPTOR_HANDLE baseDescriptor);

    // #39 ID3D12GraphicsCommandList::SetComputeRootShaderResourceView
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    private delegate void SetComputeRootShaderResourceViewDelegate(IntPtr commandList, uint rootParameterIndex, ulong address);

    // #75 ID3D12GraphicsCommandList4::SetPipelineState1
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    private delegate void SetPipelineState1Delegate(IntPtr commandList, IntPtr stateObject);

    // #76 ID3D12GraphicsCommandList4::DispatchRays
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    private delegate void DispatchRaysDelegate(IntPtr commandList, ref D3D12_DISPATCH_RAYS_DESC desc);

    // #0 IUnknown::QueryInterface
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    private delegate int QueryInterfaceDelegate(IntPtr self, ref Guid riid, out IntPtr ppv);

    // #3 ID3D12StateObjectProperties::GetShaderIdentifier
    [UnmanagedFunctionPointer(CallingConvention.StdCall, CharSet = CharSet.Unicode)]
    private delegate IntPtr GetShaderIdentifierDelegate(IntPtr props, string exportName);

    private const int FrameCount = 2;

    private IntPtr device;
    private IntPtr device5;
    private IntPtr commandQueue;
    private IntPtr swapChain;
    private IntPtr[] renderTargets = new IntPtr[FrameCount];
    private IntPtr commandAllocator;
    private IntPtr commandList;
    private IntPtr commandList4;
    private IntPtr pipelineState;
    private IntPtr rootSignature;
    private IntPtr stateObject;
    private IntPtr stateObjectProperties;
    private IntPtr rtvHeap;
    private IntPtr srvUavHeap;
    private uint rtvDescriptorSize;
    private IntPtr vertexBuffer;
    private D3D12_VERTEX_BUFFER_VIEW vertexBufferView;
    private IntPtr outputResource;
    private IntPtr shaderTable;
    private IntPtr blas;
    private IntPtr tlas;
    private IntPtr scratchBlas;
    private IntPtr scratchTlas;
    private IntPtr instanceBuffer;
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
            Console.WriteLine($"CreateSwapChain method address: {createSwapChainPtr:X}");

            var createSwapChain = Marshal.GetDelegateForFunctionPointer<CreateSwapChainDelegate>(createSwapChainPtr);
            int result = createSwapChain(factory, pDevice, ref pDesc, out ppSwapChain);
            
            Console.WriteLine($"CreateSwapChain result: {result:X}");
            Console.WriteLine($"Created SwapChain pointer: {ppSwapChain:X}");
            
            return result;
        }
        catch (Exception ex)
        {
            Console.WriteLine($"Error in CreateSwapChain: {ex.Message}");
            Console.WriteLine($"Stack trace: {ex.StackTrace}");
            ppSwapChain = IntPtr.Zero;
            return -1;
        }
    }

    private static int CreateSwapChainForHwnd(IntPtr factory, IntPtr pDevice, IntPtr hWnd, ref DXGI_SWAP_CHAIN_DESC1 pDesc, IntPtr pFullscreenDesc, IntPtr pRestrictToOutput, out IntPtr ppSwapChain)
    {
        Console.WriteLine("----------------------------------------");
        Console.WriteLine("[CreateSwapChainForHwnd] - Start");

        Console.WriteLine($"Creating swap chain...");
        Console.WriteLine($"Factory: {factory:X}");
        Console.WriteLine($"Device: {pDevice:X}");
        Console.WriteLine($"HWND: {hWnd:X}");
        
        try
        {
            IntPtr vTable = Marshal.ReadIntPtr(factory);
            IntPtr methodPtr = Marshal.ReadIntPtr(vTable, 15 * IntPtr.Size); // vTable #15 IDXGIFactory2::CreateSwapChainForHwnd
            Console.WriteLine($"CreateSwapChainForHwnd method address: {methodPtr:X}");

            var createSwapChain = Marshal.GetDelegateForFunctionPointer<CreateSwapChainForHwndDelegate>(methodPtr);
            int result = createSwapChain(factory, pDevice, hWnd, ref pDesc, pFullscreenDesc, pRestrictToOutput, out ppSwapChain);
            
            Console.WriteLine($"CreateSwapChainForHwnd result: {result:X}");
            if (result < 0)
            {
                Console.WriteLine($"Failed with HRESULT: {result:X}");
            }
            else
            {
                Console.WriteLine($"Created swap chain: {ppSwapChain:X}");
            }
            
            return result;
        }
        catch (Exception ex)
        {
            Console.WriteLine($"Error creating swap chain: {ex.Message}");
            Console.WriteLine($"Stack trace: {ex.StackTrace}");
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

            Console.WriteLine($"Getting buffer from swap chain: {swapChain:X}");
            
            IntPtr vTable = Marshal.ReadIntPtr(swapChain);
            IntPtr methodPtr = Marshal.ReadIntPtr(vTable, 9 * IntPtr.Size);  // vTable #9 IDXGISwapChain::GetBuffer
            Console.WriteLine($"GetBuffer method address: {methodPtr:X}");

            if (methodPtr == IntPtr.Zero)
            {
                Console.WriteLine("GetBuffer method pointer is null!");
                ppSurface = IntPtr.Zero;
                return -1;
            }

            var getBuffer = Marshal.GetDelegateForFunctionPointer<GetBufferDelegate>(methodPtr);
            
            Console.WriteLine($"Calling GetBuffer with parameters:");
            Console.WriteLine($"  swapChain: {swapChain:X}");
            Console.WriteLine($"  buffer: {buffer}");
            Console.WriteLine($"  riid: {riid}");
            
            Console.WriteLine($"SwapChain creation parameters:");
            Console.WriteLine($"  BufferCount: {swapChainDesc1.BufferCount}");
            Console.WriteLine($"  Format: {swapChainDesc1.Format:X}");
            Console.WriteLine($"  BufferUsage: {swapChainDesc1.BufferUsage:X}");
            Console.WriteLine($"  SwapEffect: {swapChainDesc1.SwapEffect:X}");
            
            int result = getBuffer(swapChain, buffer, ref riid, out ppSurface);
            
            Console.WriteLine($"GetBuffer result: {result:X}");
            if (result >= 0)
            {
                Console.WriteLine($"Buffer obtained: {ppSurface:X}");
            }
            else
            {
                Console.WriteLine($"GetBuffer failed with HRESULT: {result:X}");
            }
            
            return result;
        }
        catch (Exception ex)
        {
            Console.WriteLine($"Error in GetBuffer: {ex.Message}");
            Console.WriteLine($"Stack trace: {ex.StackTrace}");
            ppSurface = IntPtr.Zero;
            return -1;
        }
    }

    private static IntPtr CompileShaderFromFile(string fileName, string entryPoint, string profile)
    {
        Console.WriteLine("----------------------------------------");
        Console.WriteLine("[CompileShaderFromFile] - Start");
        Console.WriteLine($"File: {fileName}");
        Console.WriteLine($"Entry Point: {entryPoint}");
        Console.WriteLine($"Profile: {profile}");
    
        IntPtr shaderBlob = IntPtr.Zero;
        IntPtr errorBlob = IntPtr.Zero;

        try
        {
            const uint D3DCOMPILE_DEBUG = 1;
            const uint D3DCOMPILE_SKIP_OPTIMIZATION = (1 << 2);
            const uint D3DCOMPILE_ENABLE_STRICTNESS = (1 << 11);

            uint compileFlags = D3DCOMPILE_ENABLE_STRICTNESS;
    #if DEBUG
            compileFlags |= D3DCOMPILE_DEBUG | D3DCOMPILE_SKIP_OPTIMIZATION;
    #endif
    
            Console.WriteLine($"Compile Flags: {compileFlags:X}");

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

            Console.WriteLine($"D3DCompileFromFile result: {result:X}");
            Console.WriteLine($"Shader Blob: {shaderBlob:X}");
            Console.WriteLine($"Error Blob: {errorBlob:X}");
            
            if (result < 0)
            {
                if (errorBlob != IntPtr.Zero)
                {
                    string errorMessage = Marshal.PtrToStringAnsi(GetBufferPointer(errorBlob));
                    Console.WriteLine($"Shader compilation error: {errorMessage}");
                }
                else
                {
                    Console.WriteLine($"Shader compilation failed with HRESULT: {result:X}");
                }
                return IntPtr.Zero;
            }

            if (shaderBlob != IntPtr.Zero)
            {
                IntPtr shaderCode = GetBufferPointer(shaderBlob);
                int shaderSize = GetBlobSize(shaderBlob);
                Console.WriteLine($"Compiled shader details:");
                Console.WriteLine($"  Code pointer: {shaderCode:X}");
                Console.WriteLine($"  Size: {shaderSize} bytes");

                if (shaderCode != IntPtr.Zero && shaderSize > 0)
                {
                    Console.WriteLine("  First 16 bytes of shader code:");
                    byte[] firstBytes = new byte[Math.Min(16, shaderSize)];
                    Marshal.Copy(shaderCode, firstBytes, 0, firstBytes.Length);
                    Console.Write("  ");
                    foreach (byte b in firstBytes)
                    {
                        Console.Write($"{b:X2} ");
                    }
                    Console.WriteLine();
                }
            }
            
            return shaderBlob;
        }
        catch (Exception ex)
        {
            Console.WriteLine($"Exception in CompileShaderFromFile: {ex.Message}");
            Console.WriteLine($"Stack trace: {ex.StackTrace}");
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
            Console.WriteLine($"Error in GetBlobSize: {ex.Message}");
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
            Console.WriteLine($"Error in GetBufferPointer: {ex.Message}");
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
            Console.WriteLine($"Error in GetBufferSize: {ex.Message}");
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
        Dbg(nameof(LoadAssets), "begin");
        CreateRootSignatureForRaytracing();
        Dbg(nameof(LoadAssets), "CreateRootSignatureForRaytracing done");
        CreateFenceForRender();
        Dbg(nameof(LoadAssets), "CreateFenceForRender done");
        CreateAccelerationStructures();
        Dbg(nameof(LoadAssets), "CreateAccelerationStructures done");
        CreateRaytracingPipeline();
        Dbg(nameof(LoadAssets), "CreateRaytracingPipeline done");
        CreateOutputAndShaderTable();
        Dbg(nameof(LoadAssets), "CreateOutputAndShaderTable done");
        Dbg(nameof(LoadAssets), "end");
    }

    private void CreateFenceForRender()
    {
        Dbg(nameof(CreateFenceForRender), "begin");
        IntPtr vTable = Marshal.ReadIntPtr(device);
        IntPtr createFencePtr = Marshal.ReadIntPtr(vTable, 36 * IntPtr.Size);
        var createFence = Marshal.GetDelegateForFunctionPointer<CreateFenceDelegate>(createFencePtr);
        Guid fenceGuid = IID_ID3D12Fence;
        int result = createFence(device, 0, D3D12_FENCE_FLAGS.D3D12_FENCE_FLAG_NONE, ref fenceGuid, out fence);
        DbgHr(nameof(CreateFenceForRender), "CreateFence", result);
        if (result < 0) throw new Exception($"CreateFence failed: {result:X}");
        fenceValue = 1;
        fenceEvent = CreateEvent(IntPtr.Zero, false, false, null);
        Dbg(nameof(CreateFenceForRender), $"fence=0x{fence.ToInt64():X}, event=0x{fenceEvent.ToInt64():X}");
        Dbg(nameof(CreateFenceForRender), "end");
    }

    private void CreateRootSignatureForRaytracing()
    {
        Dbg(nameof(CreateRootSignatureForRaytracing), "begin");
        // UAV table(u0) + SRV(t0 as TLAS)
        D3D12_DESCRIPTOR_RANGE range = new D3D12_DESCRIPTOR_RANGE
        {
            RangeType = D3D12_DESCRIPTOR_RANGE_TYPE.D3D12_DESCRIPTOR_RANGE_TYPE_UAV,
            NumDescriptors = 1,
            BaseShaderRegister = 0,
            RegisterSpace = 0,
            OffsetInDescriptorsFromTableStart = uint.MaxValue
        };

        IntPtr rangePtr = Marshal.AllocHGlobal(Marshal.SizeOf<D3D12_DESCRIPTOR_RANGE>());
        Marshal.StructureToPtr(range, rangePtr, false);

        D3D12_ROOT_PARAMETER[] rootParams = new D3D12_ROOT_PARAMETER[2];
        rootParams[0] = new D3D12_ROOT_PARAMETER
        {
            ParameterType = D3D12_ROOT_PARAMETER_TYPE.D3D12_ROOT_PARAMETER_TYPE_DESCRIPTOR_TABLE,
            ShaderVisibility = D3D12_SHADER_VISIBILITY.D3D12_SHADER_VISIBILITY_ALL,
            DescriptorTable = new D3D12_ROOT_DESCRIPTOR_TABLE
            {
                NumDescriptorRanges = 1,
                pDescriptorRanges = rangePtr
            }
        };
        rootParams[1] = new D3D12_ROOT_PARAMETER
        {
            ParameterType = D3D12_ROOT_PARAMETER_TYPE.D3D12_ROOT_PARAMETER_TYPE_SRV,
            ShaderVisibility = D3D12_SHADER_VISIBILITY.D3D12_SHADER_VISIBILITY_ALL,
            Descriptor = new D3D12_ROOT_DESCRIPTOR { ShaderRegister = 0, RegisterSpace = 0 }
        };

        IntPtr paramsPtr = Marshal.AllocHGlobal(Marshal.SizeOf<D3D12_ROOT_PARAMETER>() * rootParams.Length);
        for (int i = 0; i < rootParams.Length; i++)
            Marshal.StructureToPtr(rootParams[i], IntPtr.Add(paramsPtr, i * Marshal.SizeOf<D3D12_ROOT_PARAMETER>()), false);

        D3D12_ROOT_SIGNATURE_DESC rsDesc = new D3D12_ROOT_SIGNATURE_DESC
        {
            NumParameters = (uint)rootParams.Length,
            pParameters = paramsPtr,
            NumStaticSamplers = 0,
            pStaticSamplers = IntPtr.Zero,
            Flags = D3D12_ROOT_SIGNATURE_FLAGS.D3D12_ROOT_SIGNATURE_FLAG_NONE
        };

        IntPtr blob, error;
        int hr = D3D12SerializeRootSignature(ref rsDesc, D3D_ROOT_SIGNATURE_VERSION_1, out blob, out error);
        DbgHr(nameof(CreateRootSignatureForRaytracing), "D3D12SerializeRootSignature", hr);
        if (hr < 0) throw new Exception($"D3D12SerializeRootSignature failed: {hr:X}");

        IntPtr vTable = Marshal.ReadIntPtr(device);
        IntPtr createRootSignaturePtr = Marshal.ReadIntPtr(vTable, 16 * IntPtr.Size);
        var createRootSignature = Marshal.GetDelegateForFunctionPointer<CreateRootSignatureDelegate>(createRootSignaturePtr);

        Guid rootSignatureGuid = IID_ID3D12RootSignature;
        hr = createRootSignature(device, 0, GetBufferPointer(blob), (IntPtr)GetBlobSize(blob), ref rootSignatureGuid, out rootSignature);
        DbgHr(nameof(CreateRootSignatureForRaytracing), "CreateRootSignature", hr);
        if (hr < 0) throw new Exception($"CreateRootSignature failed: {hr:X}");

        Marshal.FreeHGlobal(rangePtr);
        Marshal.FreeHGlobal(paramsPtr);
        Marshal.Release(blob);
        if (error != IntPtr.Zero) Marshal.Release(error);
        Dbg(nameof(CreateRootSignatureForRaytracing), $"rootSignature=0x{rootSignature.ToInt64():X}");
        Dbg(nameof(CreateRootSignatureForRaytracing), "end");
    }

    private IntPtr CreateBufferResource(ulong size, D3D12_HEAP_TYPE heapType, D3D12_RESOURCE_FLAGS flags, D3D12_RESOURCE_STATES initialState)
    {
        Dbg(nameof(CreateBufferResource), $"begin size={size} heap={heapType} state={initialState} flags={flags}");
        D3D12_HEAP_PROPERTIES heap = new D3D12_HEAP_PROPERTIES
        {
            Type = heapType,
            CPUPageProperty = D3D12_CPU_PAGE_PROPERTY.D3D12_CPU_PAGE_PROPERTY_UNKNOWN,
            MemoryPoolPreference = D3D12_MEMORY_POOL.D3D12_MEMORY_POOL_UNKNOWN,
            CreationNodeMask = 1,
            VisibleNodeMask = 1
        };

        D3D12_RESOURCE_DESC desc = new D3D12_RESOURCE_DESC
        {
            Dimension = D3D12_RESOURCE_DIMENSION.D3D12_RESOURCE_DIMENSION_BUFFER,
            Width = size,
            Height = 1,
            DepthOrArraySize = 1,
            MipLevels = 1,
            Format = DXGI_FORMAT_UNKNOWN,
            SampleDesc = new DXGI_SAMPLE_DESC { Count = 1, Quality = 0 },
            Layout = D3D12_TEXTURE_LAYOUT.D3D12_TEXTURE_LAYOUT_ROW_MAJOR,
            Flags = flags
        };

        IntPtr vTable = Marshal.ReadIntPtr(device);
        IntPtr createResourcePtr = Marshal.ReadIntPtr(vTable, 27 * IntPtr.Size);
        var createResource = Marshal.GetDelegateForFunctionPointer<CreateCommittedResourceDelegate>(createResourcePtr);

        Guid resourceGuid = IID_ID3D12Resource;
        IntPtr resource;
        int hr = createResource(device, ref heap, D3D12_HEAP_FLAGS.D3D12_HEAP_FLAG_NONE, ref desc, initialState, IntPtr.Zero, ref resourceGuid, out resource);
        DbgHr(nameof(CreateBufferResource), "CreateCommittedResource(Buffer)", hr);
        if (hr < 0) throw new Exception($"CreateCommittedResource failed: {hr:X}");

        Dbg(nameof(CreateBufferResource), $"end resource=0x{resource.ToInt64():X}");
        return resource;
    }

    private void CreateAccelerationStructures()
    {
        Dbg(nameof(CreateAccelerationStructures), "begin");
        float[] v = new float[] { 0.0f, 0.5f, 0.0f, 0.5f, -0.5f, 0.0f, -0.5f, -0.5f, 0.0f };
        ulong vbSize = (ulong)(v.Length * sizeof(float));
        vertexBuffer = CreateBufferResource(vbSize, D3D12_HEAP_TYPE.D3D12_HEAP_TYPE_UPLOAD, D3D12_RESOURCE_FLAGS.D3D12_RESOURCE_FLAG_NONE, D3D12_RESOURCE_STATES.D3D12_RESOURCE_STATE_GENERIC_READ);

        D3D12_RANGE rr = new D3D12_RANGE { Begin = 0, End = 0 };
        IntPtr vbVtbl = Marshal.ReadIntPtr(vertexBuffer);
        var map = Marshal.GetDelegateForFunctionPointer<MapDelegate>(Marshal.ReadIntPtr(vbVtbl, 8 * IntPtr.Size));
        var unmap = Marshal.GetDelegateForFunctionPointer<UnmapDelegate>(Marshal.ReadIntPtr(vbVtbl, 9 * IntPtr.Size));
        IntPtr p;
        map(vertexBuffer, 0, ref rr, out p);
        Marshal.Copy(v, 0, p, v.Length);
        unmap(vertexBuffer, 0, ref rr);

        var getVa = Marshal.GetDelegateForFunctionPointer<GetGPUVirtualAddressDelegate>(Marshal.ReadIntPtr(vbVtbl, 11 * IntPtr.Size));
        ulong vbAddress = getVa(vertexBuffer);

        D3D12_RAYTRACING_GEOMETRY_DESC geom = new D3D12_RAYTRACING_GEOMETRY_DESC
        {
            Type = 0,
            Flags = 1,
            Desc = new D3D12_RAYTRACING_GEOMETRY_DESC_UNION
            {
                Triangles = new D3D12_RAYTRACING_GEOMETRY_TRIANGLES_DESC
                {
                    Transform3x4 = 0,
                    IndexFormat = DXGI_FORMAT_UNKNOWN,
                    VertexFormat = DXGI_FORMAT_R32G32B32_FLOAT,
                    IndexCount = 0,
                    VertexCount = 3,
                    IndexBuffer = 0,
                    VertexBuffer_StartAddress = vbAddress,
                    VertexBuffer_StrideInBytes = 12
                }
            }
        };

        IntPtr geomPtr = Marshal.AllocHGlobal(Marshal.SizeOf<D3D12_RAYTRACING_GEOMETRY_DESC>());
        Marshal.StructureToPtr(geom, geomPtr, false);

        D3D12_BUILD_RAYTRACING_ACCELERATION_STRUCTURE_INPUTS blasInputs = new D3D12_BUILD_RAYTRACING_ACCELERATION_STRUCTURE_INPUTS
        {
            Type = 1,
            Flags = 0x4,
            NumDescs = 1,
            DescsLayout = 0,
            pGeometryDescs = (ulong)geomPtr.ToInt64()
        };
        Dbg(nameof(CreateAccelerationStructures), $"BLAS inputs: type={blasInputs.Type} num={blasInputs.NumDescs} layout={blasInputs.DescsLayout} pGeom=0x{blasInputs.pGeometryDescs:X}");

        const ulong BLAS_SCRATCH_SIZE = 4UL * 1024 * 1024;
        const ulong BLAS_RESULT_SIZE = 4UL * 1024 * 1024;
        scratchBlas = CreateBufferResource(BLAS_SCRATCH_SIZE, D3D12_HEAP_TYPE.D3D12_HEAP_TYPE_DEFAULT, D3D12_RESOURCE_FLAGS.D3D12_RESOURCE_FLAG_ALLOW_UNORDERED_ACCESS, D3D12_RESOURCE_STATES.D3D12_RESOURCE_STATE_UNORDERED_ACCESS);
        blas = CreateBufferResource(BLAS_RESULT_SIZE, D3D12_HEAP_TYPE.D3D12_HEAP_TYPE_DEFAULT, D3D12_RESOURCE_FLAGS.D3D12_RESOURCE_FLAG_ALLOW_UNORDERED_ACCESS, D3D12_RESOURCE_STATES.D3D12_RESOURCE_STATE_RAYTRACING_ACCELERATION_STRUCTURE);
        Dbg(nameof(CreateAccelerationStructures), $"BLAS fixed sizes: result={BLAS_RESULT_SIZE}, scratch={BLAS_SCRATCH_SIZE}");

        IntPtr sbVtbl = Marshal.ReadIntPtr(scratchBlas);
        IntPtr bVtbl = Marshal.ReadIntPtr(blas);
        ulong scratchAddr = Marshal.GetDelegateForFunctionPointer<GetGPUVirtualAddressDelegate>(Marshal.ReadIntPtr(sbVtbl, 11 * IntPtr.Size))(scratchBlas);
        ulong blasAddr = Marshal.GetDelegateForFunctionPointer<GetGPUVirtualAddressDelegate>(Marshal.ReadIntPtr(bVtbl, 11 * IntPtr.Size))(blas);

        D3D12_BUILD_RAYTRACING_ACCELERATION_STRUCTURE_DESC buildBlas = new D3D12_BUILD_RAYTRACING_ACCELERATION_STRUCTURE_DESC
        {
            DestAccelerationStructureData = blasAddr,
            Inputs = blasInputs,
            SourceAccelerationStructureData = 0,
            ScratchAccelerationStructureData = scratchAddr
        };

        IntPtr clVtbl = Marshal.ReadIntPtr(commandList4);
        var reset = Marshal.GetDelegateForFunctionPointer<ResetCommandListDelegate>(Marshal.ReadIntPtr(clVtbl, 10 * IntPtr.Size));
        var close = Marshal.GetDelegateForFunctionPointer<CloseDelegate>(Marshal.ReadIntPtr(clVtbl, 9 * IntPtr.Size));
        var barrier = Marshal.GetDelegateForFunctionPointer<ResourceBarrierDelegate>(Marshal.ReadIntPtr(clVtbl, 26 * IntPtr.Size));
        var buildAs = Marshal.GetDelegateForFunctionPointer<BuildRaytracingAccelerationStructureDelegate>(Marshal.ReadIntPtr(clVtbl, 72 * IntPtr.Size));

        IntPtr allocVtbl = Marshal.ReadIntPtr(commandAllocator);
        var resetAlloc = Marshal.GetDelegateForFunctionPointer<ResetCommandAllocatorDelegate>(Marshal.ReadIntPtr(allocVtbl, 8 * IntPtr.Size));
        resetAlloc(commandAllocator);
        reset(commandList4, commandAllocator, IntPtr.Zero);

        buildAs(commandList4, ref buildBlas, 0, IntPtr.Zero);
        Dbg(nameof(CreateAccelerationStructures), "BLAS build dispatched");
        D3D12_RESOURCE_BARRIER uavBarrier = new D3D12_RESOURCE_BARRIER
        {
            Type = D3D12_RESOURCE_BARRIER_TYPE.D3D12_RESOURCE_BARRIER_TYPE_UAV,
            Flags = D3D12_RESOURCE_BARRIER_FLAGS.D3D12_RESOURCE_BARRIER_FLAG_NONE,
            Transition = new D3D12_RESOURCE_TRANSITION_BARRIER { pResource = blas }
        };
        barrier(commandList4, 1, new[] { uavBarrier });
        close(commandList4);
        ExecuteAndWait();
        Dbg(nameof(CreateAccelerationStructures), "BLAS build completed");

        // TLAS
        D3D12_RAYTRACING_INSTANCE_DESC instanceDesc = new D3D12_RAYTRACING_INSTANCE_DESC
        {
            Transform = new float[] { 1,0,0,0, 0,1,0,0, 0,0,1,0 },
            InstanceIDMask = (1u << 24),
            InstanceContributionAndFlags = 0,
            AccelerationStructure = blasAddr
        };

        instanceBuffer = CreateBufferResource((ulong)Marshal.SizeOf<D3D12_RAYTRACING_INSTANCE_DESC>(), D3D12_HEAP_TYPE.D3D12_HEAP_TYPE_UPLOAD, D3D12_RESOURCE_FLAGS.D3D12_RESOURCE_FLAG_NONE, D3D12_RESOURCE_STATES.D3D12_RESOURCE_STATE_GENERIC_READ);
        IntPtr ibVtbl = Marshal.ReadIntPtr(instanceBuffer);
        map = Marshal.GetDelegateForFunctionPointer<MapDelegate>(Marshal.ReadIntPtr(ibVtbl, 8 * IntPtr.Size));
        unmap = Marshal.GetDelegateForFunctionPointer<UnmapDelegate>(Marshal.ReadIntPtr(ibVtbl, 9 * IntPtr.Size));
        IntPtr ip;
        map(instanceBuffer, 0, ref rr, out ip);
        Marshal.StructureToPtr(instanceDesc, ip, false);
        unmap(instanceBuffer, 0, ref rr);
        ulong instanceAddr = Marshal.GetDelegateForFunctionPointer<GetGPUVirtualAddressDelegate>(Marshal.ReadIntPtr(ibVtbl, 11 * IntPtr.Size))(instanceBuffer);

        D3D12_BUILD_RAYTRACING_ACCELERATION_STRUCTURE_INPUTS tlasInputs = new D3D12_BUILD_RAYTRACING_ACCELERATION_STRUCTURE_INPUTS
        {
            Type = 0,
            Flags = 0x4,
            NumDescs = 1,
            DescsLayout = 0,
            InstanceDescs = instanceAddr
        };
        Dbg(nameof(CreateAccelerationStructures), $"TLAS inputs: type={tlasInputs.Type} num={tlasInputs.NumDescs} layout={tlasInputs.DescsLayout} instance=0x{tlasInputs.InstanceDescs:X}");

        const ulong TLAS_SCRATCH_SIZE = 4UL * 1024 * 1024;
        const ulong TLAS_RESULT_SIZE = 4UL * 1024 * 1024;
        scratchTlas = CreateBufferResource(TLAS_SCRATCH_SIZE, D3D12_HEAP_TYPE.D3D12_HEAP_TYPE_DEFAULT, D3D12_RESOURCE_FLAGS.D3D12_RESOURCE_FLAG_ALLOW_UNORDERED_ACCESS, D3D12_RESOURCE_STATES.D3D12_RESOURCE_STATE_UNORDERED_ACCESS);
        tlas = CreateBufferResource(TLAS_RESULT_SIZE, D3D12_HEAP_TYPE.D3D12_HEAP_TYPE_DEFAULT, D3D12_RESOURCE_FLAGS.D3D12_RESOURCE_FLAG_ALLOW_UNORDERED_ACCESS, D3D12_RESOURCE_STATES.D3D12_RESOURCE_STATE_RAYTRACING_ACCELERATION_STRUCTURE);
        Dbg(nameof(CreateAccelerationStructures), $"TLAS fixed sizes: result={TLAS_RESULT_SIZE}, scratch={TLAS_SCRATCH_SIZE}");

        ulong scratchTlasAddr = Marshal.GetDelegateForFunctionPointer<GetGPUVirtualAddressDelegate>(Marshal.ReadIntPtr(Marshal.ReadIntPtr(scratchTlas), 11 * IntPtr.Size))(scratchTlas);
        ulong tlasAddr = Marshal.GetDelegateForFunctionPointer<GetGPUVirtualAddressDelegate>(Marshal.ReadIntPtr(Marshal.ReadIntPtr(tlas), 11 * IntPtr.Size))(tlas);

        D3D12_BUILD_RAYTRACING_ACCELERATION_STRUCTURE_DESC buildTlas = new D3D12_BUILD_RAYTRACING_ACCELERATION_STRUCTURE_DESC
        {
            DestAccelerationStructureData = tlasAddr,
            Inputs = tlasInputs,
            SourceAccelerationStructureData = 0,
            ScratchAccelerationStructureData = scratchTlasAddr
        };

        resetAlloc(commandAllocator);
        reset(commandList4, commandAllocator, IntPtr.Zero);
        buildAs(commandList4, ref buildTlas, 0, IntPtr.Zero);
        Dbg(nameof(CreateAccelerationStructures), "TLAS build dispatched");
        uavBarrier.Transition = new D3D12_RESOURCE_TRANSITION_BARRIER { pResource = tlas };
        barrier(commandList4, 1, new[] { uavBarrier });
        close(commandList4);
        ExecuteAndWait();
        Dbg(nameof(CreateAccelerationStructures), "TLAS build completed");

        Marshal.FreeHGlobal(geomPtr);
        Dbg(nameof(CreateAccelerationStructures), $"vertex=0x{vertexBuffer.ToInt64():X}, blas=0x{blas.ToInt64():X}, tlas=0x{tlas.ToInt64():X}");
        Dbg(nameof(CreateAccelerationStructures), "end");
    }

    private void CreateRaytracingPipeline()
    {
        Dbg(nameof(CreateRaytracingPipeline), "begin");
        string dxilPath = Path.Combine(AppContext.BaseDirectory, "raytracing.dxil");
        if (!File.Exists(dxilPath)) dxilPath = "raytracing.dxil";
        if (!File.Exists(dxilPath)) throw new Exception("raytracing.dxil not found. Run build.bat.");
        Dbg(nameof(CreateRaytracingPipeline), $"dxil={dxilPath}");
        byte[] dxil = File.ReadAllBytes(dxilPath);
        IntPtr dxilPtr = Marshal.AllocHGlobal(dxil.Length);
        Marshal.Copy(dxil, 0, dxilPtr, dxil.Length);

        D3D12_DXIL_LIBRARY_DESC lib = new D3D12_DXIL_LIBRARY_DESC
        {
            DXILLibrary = new D3D12_SHADER_BYTECODE { pShaderBytecode = dxilPtr, BytecodeLength = (IntPtr)dxil.Length },
            NumExports = 0,
            pExports = IntPtr.Zero
        };

        IntPtr hitName = Marshal.StringToHGlobalUni("HitGroup");
        IntPtr chName = Marshal.StringToHGlobalUni("ClosestHit");
        D3D12_HIT_GROUP_DESC hit = new D3D12_HIT_GROUP_DESC
        {
            HitGroupExport = hitName,
            ClosestHitShaderImport = chName,
            Type = 0
        };

        D3D12_RAYTRACING_SHADER_CONFIG shaderCfg = new D3D12_RAYTRACING_SHADER_CONFIG { MaxPayloadSizeInBytes = 16, MaxAttributeSizeInBytes = 8 };
        D3D12_GLOBAL_ROOT_SIGNATURE globalRs = new D3D12_GLOBAL_ROOT_SIGNATURE { pGlobalRootSignature = rootSignature };
        D3D12_RAYTRACING_PIPELINE_CONFIG pipelineCfg = new D3D12_RAYTRACING_PIPELINE_CONFIG { MaxTraceRecursionDepth = 1 };

        IntPtr pLib = Marshal.AllocHGlobal(Marshal.SizeOf<D3D12_DXIL_LIBRARY_DESC>()); Marshal.StructureToPtr(lib, pLib, false);
        IntPtr pHit = Marshal.AllocHGlobal(Marshal.SizeOf<D3D12_HIT_GROUP_DESC>()); Marshal.StructureToPtr(hit, pHit, false);
        IntPtr pShc = Marshal.AllocHGlobal(Marshal.SizeOf<D3D12_RAYTRACING_SHADER_CONFIG>()); Marshal.StructureToPtr(shaderCfg, pShc, false);
        IntPtr pGrs = Marshal.AllocHGlobal(Marshal.SizeOf<D3D12_GLOBAL_ROOT_SIGNATURE>()); Marshal.StructureToPtr(globalRs, pGrs, false);
        IntPtr pPcf = Marshal.AllocHGlobal(Marshal.SizeOf<D3D12_RAYTRACING_PIPELINE_CONFIG>()); Marshal.StructureToPtr(pipelineCfg, pPcf, false);

        D3D12_STATE_SUBOBJECT[] so = new D3D12_STATE_SUBOBJECT[]
        {
            new D3D12_STATE_SUBOBJECT { Type = 5, pDesc = pLib },   // DXIL_LIBRARY
            new D3D12_STATE_SUBOBJECT { Type = 11, pDesc = pHit },  // HIT_GROUP
            new D3D12_STATE_SUBOBJECT { Type = 9, pDesc = pShc },   // RAYTRACING_SHADER_CONFIG
            new D3D12_STATE_SUBOBJECT { Type = 1, pDesc = pGrs },   // GLOBAL_ROOT_SIGNATURE
            new D3D12_STATE_SUBOBJECT { Type = 10, pDesc = pPcf }   // RAYTRACING_PIPELINE_CONFIG
        };

        IntPtr pSubs = Marshal.AllocHGlobal(Marshal.SizeOf<D3D12_STATE_SUBOBJECT>() * so.Length);
        for (int i = 0; i < so.Length; i++) Marshal.StructureToPtr(so[i], IntPtr.Add(pSubs, i * Marshal.SizeOf<D3D12_STATE_SUBOBJECT>()), false);

        D3D12_STATE_OBJECT_DESC desc = new D3D12_STATE_OBJECT_DESC { Type = 3, NumSubobjects = (uint)so.Length, pSubobjects = pSubs };

        IntPtr devVtbl = Marshal.ReadIntPtr(device5);
        var createStateObject = Marshal.GetDelegateForFunctionPointer<CreateStateObjectDelegate>(Marshal.ReadIntPtr(devVtbl, 62 * IntPtr.Size));
        Guid soGuid = IID_ID3D12StateObject;
        Dbg(nameof(CreateRaytracingPipeline), $"StateSubobjectTypes=[{so[0].Type},{so[1].Type},{so[2].Type},{so[3].Type},{so[4].Type}]");
        Dbg(nameof(CreateRaytracingPipeline), $"sizeof(STATE_OBJECT_DESC)={Marshal.SizeOf<D3D12_STATE_OBJECT_DESC>()}, sizeof(STATE_SUBOBJECT)={Marshal.SizeOf<D3D12_STATE_SUBOBJECT>()}, pSubobjects=0x{pSubs.ToInt64():X}");
        int hr = createStateObject(device5, ref desc, ref soGuid, out stateObject);
        DbgHr(nameof(CreateRaytracingPipeline), "CreateStateObject", hr);
        if (hr < 0) throw new Exception($"CreateStateObject failed: {hr:X}");

        var qi = Marshal.GetDelegateForFunctionPointer<QueryInterfaceDelegate>(Marshal.ReadIntPtr(Marshal.ReadIntPtr(stateObject), 0));
        Guid propsGuid = IID_ID3D12StateObjectProperties;
        hr = qi(stateObject, ref propsGuid, out stateObjectProperties);
        DbgHr(nameof(CreateRaytracingPipeline), "QueryInterface(ID3D12StateObjectProperties)", hr);
        if (hr < 0) throw new Exception($"QI ID3D12StateObjectProperties failed: {hr:X}");

        Marshal.FreeHGlobal(dxilPtr);
        Marshal.FreeHGlobal(hitName);
        Marshal.FreeHGlobal(chName);
        Marshal.FreeHGlobal(pLib);
        Marshal.FreeHGlobal(pHit);
        Marshal.FreeHGlobal(pShc);
        Marshal.FreeHGlobal(pGrs);
        Marshal.FreeHGlobal(pPcf);
        Marshal.FreeHGlobal(pSubs);
        Dbg(nameof(CreateRaytracingPipeline), $"stateObject=0x{stateObject.ToInt64():X}, props=0x{stateObjectProperties.ToInt64():X}");
        Dbg(nameof(CreateRaytracingPipeline), "end");
    }

    private void CreateOutputAndShaderTable()
    {
        Dbg(nameof(CreateOutputAndShaderTable), "begin");
        D3D12_DESCRIPTOR_HEAP_DESC srvHeapDesc = new D3D12_DESCRIPTOR_HEAP_DESC
        {
            Type = D3D12_DESCRIPTOR_HEAP_TYPE.D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV,
            NumDescriptors = 1,
            Flags = D3D12_DESCRIPTOR_HEAP_FLAGS.D3D12_DESCRIPTOR_HEAP_FLAG_SHADER_VISIBLE,
            NodeMask = 0
        };

        IntPtr vTable = Marshal.ReadIntPtr(device);
        IntPtr createHeapPtr = Marshal.ReadIntPtr(vTable, 14 * IntPtr.Size);
        var createHeap = Marshal.GetDelegateForFunctionPointer<CreateDescriptorHeapDelegate>(createHeapPtr);
        Guid heapGuid = IID_ID3D12DescriptorHeap;
        int hr = createHeap(device, ref srvHeapDesc, ref heapGuid, out srvUavHeap);
        DbgHr(nameof(CreateOutputAndShaderTable), "CreateDescriptorHeap(CBV_SRV_UAV)", hr);
        if (hr < 0) throw new Exception($"CreateDescriptorHeap(SRV/UAV) failed: {hr:X}");

        D3D12_HEAP_PROPERTIES hp = new D3D12_HEAP_PROPERTIES
        {
            Type = D3D12_HEAP_TYPE.D3D12_HEAP_TYPE_DEFAULT,
            CPUPageProperty = D3D12_CPU_PAGE_PROPERTY.D3D12_CPU_PAGE_PROPERTY_UNKNOWN,
            MemoryPoolPreference = D3D12_MEMORY_POOL.D3D12_MEMORY_POOL_UNKNOWN,
            CreationNodeMask = 1,
            VisibleNodeMask = 1
        };
        D3D12_RESOURCE_DESC tex = new D3D12_RESOURCE_DESC
        {
            Dimension = D3D12_RESOURCE_DIMENSION.D3D12_RESOURCE_DIMENSION_TEXTURE2D,
            Width = 800,
            Height = 600,
            DepthOrArraySize = 1,
            MipLevels = 1,
            Format = DXGI_FORMAT_R8G8B8A8_UNORM,
            SampleDesc = new DXGI_SAMPLE_DESC { Count = 1, Quality = 0 },
            Layout = D3D12_TEXTURE_LAYOUT.D3D12_TEXTURE_LAYOUT_UNKNOWN,
            Flags = D3D12_RESOURCE_FLAGS.D3D12_RESOURCE_FLAG_ALLOW_UNORDERED_ACCESS
        };

        IntPtr createResPtr = Marshal.ReadIntPtr(vTable, 27 * IntPtr.Size);
        var createRes = Marshal.GetDelegateForFunctionPointer<CreateCommittedResourceDelegate>(createResPtr);
        Guid resGuid = IID_ID3D12Resource;
        hr = createRes(device, ref hp, D3D12_HEAP_FLAGS.D3D12_HEAP_FLAG_NONE, ref tex, D3D12_RESOURCE_STATES.D3D12_RESOURCE_STATE_UNORDERED_ACCESS, IntPtr.Zero, ref resGuid, out outputResource);
        DbgHr(nameof(CreateOutputAndShaderTable), "CreateCommittedResource(UAVTexture)", hr);
        if (hr < 0) throw new Exception($"Create output UAV texture failed: {hr:X}");

        D3D12_CPU_DESCRIPTOR_HANDLE cpu;
        var getCpu = Marshal.GetDelegateForFunctionPointer<GetCPUDescriptorHandleForHeapStartDelegate>(Marshal.ReadIntPtr(Marshal.ReadIntPtr(srvUavHeap), 9 * IntPtr.Size));
        getCpu(srvUavHeap, out cpu);

        D3D12_UNORDERED_ACCESS_VIEW_DESC uav = new D3D12_UNORDERED_ACCESS_VIEW_DESC
        {
            Format = DXGI_FORMAT_R8G8B8A8_UNORM,
            ViewDimension = 4,
            Texture2D_MipSlice = 0,
            Texture2D_PlaneSlice = 0
        };
        var createUav = Marshal.GetDelegateForFunctionPointer<CreateUnorderedAccessViewDelegate>(Marshal.ReadIntPtr(vTable, 19 * IntPtr.Size));
        createUav(device, outputResource, IntPtr.Zero, ref uav, cpu);

        var getShaderId = Marshal.GetDelegateForFunctionPointer<GetShaderIdentifierDelegate>(Marshal.ReadIntPtr(Marshal.ReadIntPtr(stateObjectProperties), 3 * IntPtr.Size));
        IntPtr rayGen = getShaderId(stateObjectProperties, "RayGen");
        IntPtr miss = getShaderId(stateObjectProperties, "Miss");
        IntPtr hit = getShaderId(stateObjectProperties, "HitGroup");

        ulong recSize = 64;
        shaderTable = CreateBufferResource(recSize * 3, D3D12_HEAP_TYPE.D3D12_HEAP_TYPE_UPLOAD, D3D12_RESOURCE_FLAGS.D3D12_RESOURCE_FLAG_NONE, D3D12_RESOURCE_STATES.D3D12_RESOURCE_STATE_GENERIC_READ);
        IntPtr stVtbl = Marshal.ReadIntPtr(shaderTable);
        var map = Marshal.GetDelegateForFunctionPointer<MapDelegate>(Marshal.ReadIntPtr(stVtbl, 8 * IntPtr.Size));
        var unmap = Marshal.GetDelegateForFunctionPointer<UnmapDelegate>(Marshal.ReadIntPtr(stVtbl, 9 * IntPtr.Size));
        D3D12_RANGE rr = new D3D12_RANGE { Begin = 0, End = 0 };
        IntPtr sp;
        map(shaderTable, 0, ref rr, out sp);
        byte[] id = new byte[32];
        Marshal.Copy(rayGen, id, 0, id.Length); Marshal.Copy(id, 0, sp, id.Length);
        Marshal.Copy(miss, id, 0, id.Length); Marshal.Copy(id, 0, IntPtr.Add(sp, 64), id.Length);
        Marshal.Copy(hit, id, 0, id.Length); Marshal.Copy(id, 0, IntPtr.Add(sp, 128), id.Length);
        unmap(shaderTable, 0, ref rr);
        Dbg(nameof(CreateOutputAndShaderTable), $"srvUavHeap=0x{srvUavHeap.ToInt64():X}, output=0x{outputResource.ToInt64():X}, shaderTable=0x{shaderTable.ToInt64():X}");
        Dbg(nameof(CreateOutputAndShaderTable), "end");
    }

    private void ExecuteAndWait()
    {
        Dbg(nameof(ExecuteAndWait), "begin");
        IntPtr qv = Marshal.ReadIntPtr(commandQueue);
        var execute = Marshal.GetDelegateForFunctionPointer<ExecuteCommandListsDelegate>(Marshal.ReadIntPtr(qv, 10 * IntPtr.Size));
        execute(commandQueue, 1, new[] { commandList4 });
        WaitForPreviousFrame();
        Dbg(nameof(ExecuteAndWait), "end");
    }

    private void PopulateCommandList()
    {
        Dbg(nameof(PopulateCommandList), $"begin frameIndex={frameIndex}");
        IntPtr allocV = Marshal.ReadIntPtr(commandAllocator);
        var resetAlloc = Marshal.GetDelegateForFunctionPointer<ResetCommandAllocatorDelegate>(Marshal.ReadIntPtr(allocV, 8 * IntPtr.Size));
        int hr = resetAlloc(commandAllocator);
        if (hr < 0) throw new Exception($"CommandAllocator.Reset failed: {hr:X}");

        IntPtr clV = Marshal.ReadIntPtr(commandList4);
        var reset = Marshal.GetDelegateForFunctionPointer<ResetCommandListDelegate>(Marshal.ReadIntPtr(clV, 10 * IntPtr.Size));
        hr = reset(commandList4, commandAllocator, IntPtr.Zero);
        if (hr < 0) throw new Exception($"CommandList.Reset failed: {hr:X}");

        var setHeaps = Marshal.GetDelegateForFunctionPointer<SetDescriptorHeapsDelegate>(Marshal.ReadIntPtr(clV, 28 * IntPtr.Size));
        setHeaps(commandList4, 1, new[] { srvUavHeap });

        var setComputeRootSig = Marshal.GetDelegateForFunctionPointer<SetComputeRootSignatureDelegate>(Marshal.ReadIntPtr(clV, 29 * IntPtr.Size));
        setComputeRootSig(commandList4, rootSignature);

        D3D12_GPU_DESCRIPTOR_HANDLE gpuHandle;
        var getGpu = Marshal.GetDelegateForFunctionPointer<GetGPUDescriptorHandleForHeapStartDelegate>(Marshal.ReadIntPtr(Marshal.ReadIntPtr(srvUavHeap), 10 * IntPtr.Size));
        getGpu(srvUavHeap, out gpuHandle);

        var setRootTable = Marshal.GetDelegateForFunctionPointer<SetComputeRootDescriptorTableDelegate>(Marshal.ReadIntPtr(clV, 31 * IntPtr.Size));
        setRootTable(commandList4, 0, gpuHandle);

        ulong tlasAddress = Marshal.GetDelegateForFunctionPointer<GetGPUVirtualAddressDelegate>(Marshal.ReadIntPtr(Marshal.ReadIntPtr(tlas), 11 * IntPtr.Size))(tlas);
        var setRootSrv = Marshal.GetDelegateForFunctionPointer<SetComputeRootShaderResourceViewDelegate>(Marshal.ReadIntPtr(clV, 39 * IntPtr.Size));
        setRootSrv(commandList4, 1, tlasAddress);

        var setPipelineState1 = Marshal.GetDelegateForFunctionPointer<SetPipelineState1Delegate>(Marshal.ReadIntPtr(clV, 75 * IntPtr.Size));
        setPipelineState1(commandList4, stateObject);

        ulong shaderTableAddress = Marshal.GetDelegateForFunctionPointer<GetGPUVirtualAddressDelegate>(Marshal.ReadIntPtr(Marshal.ReadIntPtr(shaderTable), 11 * IntPtr.Size))(shaderTable);
        D3D12_DISPATCH_RAYS_DESC dispatch = new D3D12_DISPATCH_RAYS_DESC
        {
            RayGenerationShaderRecord = new D3D12_GPU_VIRTUAL_ADDRESS_RANGE { StartAddress = shaderTableAddress, SizeInBytes = 64 },
            MissShaderTable = new D3D12_GPU_VIRTUAL_ADDRESS_RANGE_AND_STRIDE { StartAddress = shaderTableAddress + 64, SizeInBytes = 64, StrideInBytes = 64 },
            HitGroupTable = new D3D12_GPU_VIRTUAL_ADDRESS_RANGE_AND_STRIDE { StartAddress = shaderTableAddress + 128, SizeInBytes = 64, StrideInBytes = 64 },
            CallableShaderTable = new D3D12_GPU_VIRTUAL_ADDRESS_RANGE_AND_STRIDE { StartAddress = 0, SizeInBytes = 0, StrideInBytes = 0 },
            Width = 800,
            Height = 600,
            Depth = 1
        };

        var dispatchRays = Marshal.GetDelegateForFunctionPointer<DispatchRaysDelegate>(Marshal.ReadIntPtr(clV, 76 * IntPtr.Size));
        dispatchRays(commandList4, ref dispatch);
        Dbg(nameof(PopulateCommandList), "DispatchRays recorded");

        var resourceBarrier = Marshal.GetDelegateForFunctionPointer<ResourceBarrierDelegate>(Marshal.ReadIntPtr(clV, 26 * IntPtr.Size));
        var copyResource = Marshal.GetDelegateForFunctionPointer<CopyResourceDelegate>(Marshal.ReadIntPtr(clV, 17 * IntPtr.Size));

        D3D12_RESOURCE_BARRIER[] barriers = new D3D12_RESOURCE_BARRIER[]
        {
            new D3D12_RESOURCE_BARRIER
            {
                Type = D3D12_RESOURCE_BARRIER_TYPE.D3D12_RESOURCE_BARRIER_TYPE_TRANSITION,
                Flags = D3D12_RESOURCE_BARRIER_FLAGS.D3D12_RESOURCE_BARRIER_FLAG_NONE,
                Transition = new D3D12_RESOURCE_TRANSITION_BARRIER
                {
                    pResource = outputResource,
                    Subresource = D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES,
                    StateBefore = D3D12_RESOURCE_STATES.D3D12_RESOURCE_STATE_UNORDERED_ACCESS,
                    StateAfter = D3D12_RESOURCE_STATES.D3D12_RESOURCE_STATE_COPY_SOURCE
                }
            },
            new D3D12_RESOURCE_BARRIER
            {
                Type = D3D12_RESOURCE_BARRIER_TYPE.D3D12_RESOURCE_BARRIER_TYPE_TRANSITION,
                Flags = D3D12_RESOURCE_BARRIER_FLAGS.D3D12_RESOURCE_BARRIER_FLAG_NONE,
                Transition = new D3D12_RESOURCE_TRANSITION_BARRIER
                {
                    pResource = renderTargets[frameIndex],
                    Subresource = D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES,
                    StateBefore = D3D12_RESOURCE_STATES.D3D12_RESOURCE_STATE_PRESENT,
                    StateAfter = D3D12_RESOURCE_STATES.D3D12_RESOURCE_STATE_COPY_DEST
                }
            }
        };

        resourceBarrier(commandList4, 2, barriers);
        copyResource(commandList4, renderTargets[frameIndex], outputResource);
        Dbg(nameof(PopulateCommandList), "CopyResource output->backbuffer recorded");

        barriers[0].Transition.StateBefore = D3D12_RESOURCE_STATES.D3D12_RESOURCE_STATE_COPY_SOURCE;
        barriers[0].Transition.StateAfter = D3D12_RESOURCE_STATES.D3D12_RESOURCE_STATE_UNORDERED_ACCESS;
        barriers[1].Transition.StateBefore = D3D12_RESOURCE_STATES.D3D12_RESOURCE_STATE_COPY_DEST;
        barriers[1].Transition.StateAfter = D3D12_RESOURCE_STATES.D3D12_RESOURCE_STATE_PRESENT;
        resourceBarrier(commandList4, 2, barriers);

        var close = Marshal.GetDelegateForFunctionPointer<CloseDelegate>(Marshal.ReadIntPtr(clV, 9 * IntPtr.Size));
        hr = close(commandList4);
        if (hr < 0) throw new Exception($"CommandList.Close failed: {hr:X}");
        Dbg(nameof(PopulateCommandList), "end");
    }
    private void WaitForPreviousFrame()
    {
        Dbg(nameof(WaitForPreviousFrame), $"begin fenceValue={fenceValue}");
        if (fence == IntPtr.Zero)
        {
            Dbg(nameof(WaitForPreviousFrame), "fence is null");
            throw new Exception("Fence is null.");
        }
        Console.WriteLine("----------------------------------------");
        Console.WriteLine("[WaitForPreviousFrame] - Start");

        try
        {
            IntPtr vTable = Marshal.ReadIntPtr(commandQueue);
            IntPtr signalPtr = Marshal.ReadIntPtr(vTable, 14 * IntPtr.Size);  // vTable #14 ID3D12CommandQueue::Signal
            var signal = Marshal.GetDelegateForFunctionPointer<SignalDelegate>(signalPtr);
            int result = signal(commandQueue, fence, fenceValue);
            DbgHr(nameof(WaitForPreviousFrame), "Signal", result);

            if (result < 0)
            {
                Console.WriteLine($"Signal failed with HRESULT: {result:X}");
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
                DbgHr(nameof(WaitForPreviousFrame), "SetEventOnCompletion", result);
                
                if (result < 0)
                {
                    Console.WriteLine($"SetEventOnCompletion failed with HRESULT: {result:X}");
                    return;
                }

                WaitForSingleObject(fenceEvent, INFINITE);
                Dbg(nameof(WaitForPreviousFrame), "wait completed");
            }

            fenceValue++;
            Dbg(nameof(WaitForPreviousFrame), $"end nextFenceValue={fenceValue}");
        }
        catch (Exception ex)
        {
            Console.WriteLine($"Error in WaitForPreviousFrame: {ex.Message}");
            Console.WriteLine($"Stack trace: {ex.StackTrace}");
            Dbg(nameof(WaitForPreviousFrame), $"exception: {ex.Message}");
        }
    }

    public void Render()
    {
       Dbg(nameof(Render), "begin");
       Console.WriteLine("----------------------------------------");
       Console.WriteLine("[Render] - Start");

       try
       {
           PopulateCommandList();

           IntPtr[] commandLists = { commandList4 };
           IntPtr vTable = Marshal.ReadIntPtr(commandQueue);
           IntPtr executePtr = Marshal.ReadIntPtr(vTable, 10 * IntPtr.Size);  // vTable #10 ID3D12CommandQueue::ExecuteCommandLists
           var executeCommandLists = Marshal.GetDelegateForFunctionPointer<ExecuteCommandListsDelegate>(executePtr);
           executeCommandLists(commandQueue, 1, commandLists);

           vTable = Marshal.ReadIntPtr(swapChain);
           IntPtr presentPtr = Marshal.ReadIntPtr(vTable, 8 * IntPtr.Size);  // vTable #8 IDXGISwapChain::Present
           var present = Marshal.GetDelegateForFunctionPointer<PresentDelegate>(presentPtr);
           int result = present(swapChain, 0, 0);
           DbgHr(nameof(Render), "Present", result);

           if (result < 0)
           {
               Console.WriteLine($"Present failed with HRESULT: {result:X}");
               return;
           }

           WaitForPreviousFrame();
           Dbg(nameof(Render), "end");
       }
       catch (Exception ex)
       {
           Console.WriteLine($"Error in Render: {ex.Message}");
           Console.WriteLine($"Stack trace: {ex.StackTrace}");
           Dbg(nameof(Render), $"exception: {ex.Message}");
       }
    }

    private void CleanupDevice()
    {
        Dbg(nameof(CleanupDevice), "begin");
        Console.WriteLine("----------------------------------------");
        Console.WriteLine("[CleanupDevice] - Start");

        CloseHandle(fenceEvent);

        if (fence != IntPtr.Zero) Marshal.Release(fence);
        if (stateObjectProperties != IntPtr.Zero) Marshal.Release(stateObjectProperties);
        if (stateObject != IntPtr.Zero) Marshal.Release(stateObject);
        if (shaderTable != IntPtr.Zero) Marshal.Release(shaderTable);
        if (outputResource != IntPtr.Zero) Marshal.Release(outputResource);
        if (tlas != IntPtr.Zero) Marshal.Release(tlas);
        if (blas != IntPtr.Zero) Marshal.Release(blas);
        if (instanceBuffer != IntPtr.Zero) Marshal.Release(instanceBuffer);
        if (scratchTlas != IntPtr.Zero) Marshal.Release(scratchTlas);
        if (scratchBlas != IntPtr.Zero) Marshal.Release(scratchBlas);
        if (vertexBuffer != IntPtr.Zero) Marshal.Release(vertexBuffer);
        if (pipelineState != IntPtr.Zero) Marshal.Release(pipelineState);
        if (rootSignature != IntPtr.Zero) Marshal.Release(rootSignature);
        if (commandList4 != IntPtr.Zero) Marshal.Release(commandList4);
        if (commandList != IntPtr.Zero) Marshal.Release(commandList);
        if (commandAllocator != IntPtr.Zero) Marshal.Release(commandAllocator);
        if (srvUavHeap != IntPtr.Zero) Marshal.Release(srvUavHeap);
        if (rtvHeap != IntPtr.Zero) Marshal.Release(rtvHeap);
        
        foreach (var rt in renderTargets)
        {
            if (rt != IntPtr.Zero) Marshal.Release(rt);
        }
        
        if (swapChain != IntPtr.Zero) Marshal.Release(swapChain);
        if (commandQueue != IntPtr.Zero) Marshal.Release(commandQueue);
        if (device5 != IntPtr.Zero) Marshal.Release(device5);
        if (device != IntPtr.Zero) Marshal.Release(device);
        Dbg(nameof(CleanupDevice), "end");
    }

    private void LoadPipeline(IntPtr hwnd)
    {
       Dbg(nameof(LoadPipeline), "begin");
       Console.WriteLine("----------------------------------------");
       Console.WriteLine("[LoadPipeline] - Start");

       try
       {
            IntPtr debugInterface;
            Guid debugGuid = IID_ID3D12Debug;
            int debugResult = D3D12GetDebugInterface(ref debugGuid, out debugInterface);
            DbgHr(nameof(LoadPipeline), "D3D12GetDebugInterface", debugResult);
            if (debugResult >= 0 && debugInterface != IntPtr.Zero)
            {
                Console.WriteLine("Enabling debug layer...");
                ID3D12Debug debug = Marshal.GetObjectForIUnknown(debugInterface) as ID3D12Debug;
                debug.EnableDebugLayer();
                Marshal.ReleaseComObject(debug);
            }
            else
            {
                Console.WriteLine($"Failed to get debug interface: {debugResult:X}");
            }

           IntPtr factory = IntPtr.Zero;
           Guid factoryIID = IID_IDXGIFactory4;
           int result = CreateDXGIFactory2(0, ref factoryIID, out factory);
           DbgHr(nameof(LoadPipeline), "CreateDXGIFactory2", result);
           if (result < 0)
           {
               throw new Exception($"Failed to create DXGI Factory2: {result:X}");
           }

           // Prefer hardware DXR adapter, fallback to WARP DXR.
           Guid deviceGuid = IID_ID3D12Device5;
           IntPtr factoryVTable = Marshal.ReadIntPtr(factory);
           var enumAdapters1 = Marshal.GetDelegateForFunctionPointer<EnumAdapters1Delegate>(Marshal.ReadIntPtr(factoryVTable, 12 * IntPtr.Size));
           var enumWarpAdapter = Marshal.GetDelegateForFunctionPointer<EnumWarpAdapterDelegate>(Marshal.ReadIntPtr(factoryVTable, 27 * IntPtr.Size));

           bool foundDxr = false;
           for (uint i = 0; ; i++)
           {
               IntPtr adapter;
               int enumHr = enumAdapters1(factory, i, out adapter);
               if ((uint)enumHr == 0x887A0002) // DXGI_ERROR_NOT_FOUND
               {
                   break;
               }
               DbgHr(nameof(LoadPipeline), $"EnumAdapters1({i})", enumHr);
               if (enumHr < 0) break;

               IntPtr candidateDevice;
               int createHr = D3D12CreateDevice(adapter, D3D_FEATURE_LEVEL_12_1, ref deviceGuid, out candidateDevice);
               DbgHr(nameof(LoadPipeline), $"D3D12CreateDevice(adapter:{i})", createHr);
               if (createHr >= 0)
               {
                   D3D12_FEATURE_DATA_D3D12_OPTIONS5 options5 = new D3D12_FEATURE_DATA_D3D12_OPTIONS5();
                   IntPtr dv = Marshal.ReadIntPtr(candidateDevice);
                   var checkFeature = Marshal.GetDelegateForFunctionPointer<CheckFeatureSupportDelegate>(Marshal.ReadIntPtr(dv, 13 * IntPtr.Size));
                   int featureHr = checkFeature(candidateDevice, 27, ref options5, (uint)Marshal.SizeOf<D3D12_FEATURE_DATA_D3D12_OPTIONS5>());
                   DbgHr(nameof(LoadPipeline), $"CheckFeatureSupport(adapter:{i})", featureHr);
                   Dbg(nameof(LoadPipeline), $"adapter:{i} RaytracingTier={options5.RaytracingTier}");

                   if (featureHr >= 0 && options5.RaytracingTier >= 10)
                   {
                       device = candidateDevice;
                       foundDxr = true;
                       Marshal.Release(adapter);
                       break;
                   }
                   Marshal.Release(candidateDevice);
               }
               Marshal.Release(adapter);
           }

           if (!foundDxr)
           {
               Dbg(nameof(LoadPipeline), "No DXR hardware adapter found. Trying WARP.");
               IntPtr warpAdapter;
               Guid adapterGuid = IID_IDXGIAdapter1;
               int warpHr = enumWarpAdapter(factory, ref adapterGuid, out warpAdapter);
               DbgHr(nameof(LoadPipeline), "EnumWarpAdapter", warpHr);
               if (warpHr < 0) throw new Exception("EnumWarpAdapter failed.");

               result = D3D12CreateDevice(warpAdapter, D3D_FEATURE_LEVEL_12_1, ref deviceGuid, out device);
               DbgHr(nameof(LoadPipeline), "D3D12CreateDevice(WARP)", result);
               Marshal.Release(warpAdapter);
               if (result < 0) throw new Exception("Failed to create WARP D3D12 device.");

               D3D12_FEATURE_DATA_D3D12_OPTIONS5 options5 = new D3D12_FEATURE_DATA_D3D12_OPTIONS5();
               IntPtr deviceVTable = Marshal.ReadIntPtr(device);
               var checkFeature = Marshal.GetDelegateForFunctionPointer<CheckFeatureSupportDelegate>(Marshal.ReadIntPtr(deviceVTable, 13 * IntPtr.Size));
               result = checkFeature(device, 27, ref options5, (uint)Marshal.SizeOf<D3D12_FEATURE_DATA_D3D12_OPTIONS5>());
               DbgHr(nameof(LoadPipeline), "CheckFeatureSupport(WARP)", result);
               Dbg(nameof(LoadPipeline), $"WARP RaytracingTier={options5.RaytracingTier}");
               if (result < 0 || options5.RaytracingTier < 10)
               {
                   throw new Exception("DXR Tier 1.0 is not supported on this system (hardware/WARP).");
               }
           }

           // Ensure DXR-capable interface pointers are explicitly acquired.
           IntPtr deviceBaseVt = Marshal.ReadIntPtr(device);
           var qiDev = Marshal.GetDelegateForFunctionPointer<QueryInterfaceDelegate>(Marshal.ReadIntPtr(deviceBaseVt, 0));
           Guid iidDev5 = IID_ID3D12Device5;
           result = qiDev(device, ref iidDev5, out device5);
           DbgHr(nameof(LoadPipeline), "QueryInterface(ID3D12Device5)", result);
           if (result < 0 || device5 == IntPtr.Zero)
           {
               throw new Exception("Failed to query ID3D12Device5.");
           }
           Dbg(nameof(LoadPipeline), $"device=0x{device.ToInt64():X}, device5=0x{device5.ToInt64():X}");

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
           DbgHr(nameof(LoadPipeline), "CreateCommandQueue", result);
           if (result < 0)
           {
               throw new Exception($"Failed to create Command Queue: {result:X}");
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
           DbgHr(nameof(LoadPipeline), "CreateSwapChainForHwnd", result);
           if (result < 0)
           {
               throw new Exception($"Failed to create Swap Chain: {result:X}");
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
           DbgHr(nameof(LoadPipeline), "CreateDescriptorHeap(RTV)", result);
           if (result < 0)
           {
               throw new Exception($"Failed to create Descriptor Heap: {result:X}");
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
               result = getBuffer(swapChain, (uint)i, ref resourceGuid, out IntPtr resourcePtr);
               if (result < 0)
               {
                   throw new Exception($"Failed to get Buffer: {result:X}");
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
            DbgHr(nameof(LoadPipeline), "CreateCommandAllocator", result);
            if (result < 0)
            {
                throw new Exception($"Failed to create Command Allocator: {result:X}");
            }

            IntPtr createCommandListPtr = Marshal.ReadIntPtr(vTable, 12 * IntPtr.Size);  // vTable #12 ID3D12Device::CreateCommandList
            var createCommandList = Marshal.GetDelegateForFunctionPointer<CreateCommandListDelegate>(createCommandListPtr);
            Guid commandListGuid = IID_ID3D12GraphicsCommandList4;
            result = createCommandList(
                device,
                0,
                D3D12_COMMAND_LIST_TYPE.D3D12_COMMAND_LIST_TYPE_DIRECT,
                commandAllocator,
                IntPtr.Zero,
                ref commandListGuid,
                out commandList
            );
            DbgHr(nameof(LoadPipeline), "CreateCommandList4", result);
            if (result < 0)
            {
                throw new Exception($"Failed to create Command List4: {result:X}");
            }

            IntPtr clVTable = Marshal.ReadIntPtr(commandList);
            var qiCl = Marshal.GetDelegateForFunctionPointer<QueryInterfaceDelegate>(Marshal.ReadIntPtr(clVTable, 0));
            Guid iidCl4 = IID_ID3D12GraphicsCommandList4;
            result = qiCl(commandList, ref iidCl4, out commandList4);
            DbgHr(nameof(LoadPipeline), "QueryInterface(ID3D12GraphicsCommandList4)", result);
            if (result < 0 || commandList4 == IntPtr.Zero)
            {
                throw new Exception("Failed to query ID3D12GraphicsCommandList4.");
            }
            Dbg(nameof(LoadPipeline), $"commandList=0x{commandList.ToInt64():X}, commandList4=0x{commandList4.ToInt64():X}");

            IntPtr closePtr = Marshal.ReadIntPtr(clVTable, 9 * IntPtr.Size);
            var close = Marshal.GetDelegateForFunctionPointer<CloseDelegate>(closePtr);
            close(commandList);
            Dbg(nameof(LoadPipeline), "commandList initial close done");

            Marshal.Release(factory);
            Dbg(nameof(LoadPipeline), "end");
        }
        catch (Exception ex)
        {
            Console.WriteLine($"Error in LoadPipeline: {ex.Message}");
            Console.WriteLine($"Stack trace: {ex.StackTrace}");
            Dbg(nameof(LoadPipeline), $"exception: {ex.Message}");
            throw;
        }
    }

    static IntPtr WndProc(IntPtr hWnd, uint uMsg, IntPtr wParam, IntPtr lParam)
    {
        PAINTSTRUCT ps = new PAINTSTRUCT();
        IntPtr hdc;
        string strMessage = "Hello, DirectX Raytracing(C#) World!";
 
        switch (uMsg)
        {
            case WM_PAINT:
                hdc = BeginPaint( hWnd, out ps );
                TextOut( hdc, 0, 0, strMessage, strMessage.Length );
                EndPaint( hWnd, ref ps );
                break;
            case WM_DESTROY:
                Dbg(nameof(WndProc), "WM_DESTROY");
                PostQuitMessage(0);
                break;
            default:
                return DefWindowProc(hWnd, uMsg, wParam, lParam);
        }
 
        return IntPtr.Zero;
    }

    [STAThread]
    static int Main(string[] args)
    {
        Dbg(nameof(Main), "begin");
        Dbg(nameof(Main), $"Is64BitProcess={Environment.Is64BitProcess}");
        Console.WriteLine("----------------------------------------");
        Console.WriteLine("[Main] - Start");

        var app = new Hello();
        

        const string CLASS_NAME = "MyDXWindowClass";
        const string WINDOW_NAME = "DirectX Raytracing Triangle (C#)";

        IntPtr hInstance = Marshal.GetHINSTANCE(typeof(Hello).Module);
        
        Console.WriteLine($"hInstance: {hInstance}");

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

        Console.WriteLine($"WNDCLASSEX Size: {wndClassEx.cbSize}");
        Console.WriteLine($"WndProc Pointer: {wndClassEx.lpfnWndProc}");

        ushort atom = RegisterClassEx(ref wndClassEx);
        int error = Marshal.GetLastWin32Error();
        
        Console.WriteLine($"RegisterClassEx result: {atom}");
        Console.WriteLine($"Last error: {error}");

        if (atom == 0)
        {
            Console.WriteLine($"Failed to register window class. Error: {error}");
            Dbg(nameof(Main), $"RegisterClassEx failed err={error}");
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
            Dbg(nameof(Main), "initializing pipeline");
            app.LoadPipeline(hwnd);
            Dbg(nameof(Main), "loading assets");
            app.LoadAssets();

            ShowWindow(hwnd, 1); // SW_SHOW
            Dbg(nameof(Main), "entering message loop");

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
        catch (Exception ex)
        {
            Dbg(nameof(Main), $"exception: {ex.Message}");
            throw;
        }
        finally
        {
            Dbg(nameof(Main), "cleanup");
            app.CleanupDevice();
            Dbg(nameof(Main), "end");
        }
    }
}


