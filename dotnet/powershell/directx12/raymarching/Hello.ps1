$source = @"
using System;
using System.Runtime.InteropServices;
using System.Diagnostics;

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

    const uint WS_OVERLAPPEDWINDOW = 0x0CF0000;
    const uint WS_VISIBLE = 0x10000000;

    const uint WM_DESTROY = 0x0002;
    const uint WM_QUIT = 0x0012;
    const uint PM_REMOVE = 0x0001;

    const uint CS_OWNDC = 0x0020;
    const int IDC_ARROW = 32512;
    const uint INFINITE = 0xFFFFFFFF;

    const int WIDTH = 800;
    const int HEIGHT = 600;

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
    static extern bool TranslateMessage([In] ref MSG lpMsg);

    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    static extern IntPtr DispatchMessage([In] ref MSG lpMsg);

    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    static extern void PostQuitMessage(int nExitCode);

    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    static extern IntPtr DefWindowProc(IntPtr hWnd, uint uMsg, IntPtr wParam, IntPtr lParam);

    const uint D3D_FEATURE_LEVEL_11_0 = 0xb000;
    const uint D3D_ROOT_SIGNATURE_VERSION_1 = 0x1;
            
    // Vertex structure for fullscreen quad (position only)
    [StructLayout(LayoutKind.Sequential)]
    struct Vertex
    {
        public float X, Y;
    }

    // Constant buffer for shader parameters
    [StructLayout(LayoutKind.Sequential)]
    struct ConstantBufferData
    {
        public float iTime;
        public float iResolutionX;
        public float iResolutionY;
        public float padding;
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
        uint MinimumFeatureLevel,
        ref Guid riid,
        out IntPtr ppDevice);

    [DllImport("dxgi.dll")]
    private static extern int CreateDXGIFactory2(uint Flags, ref Guid riid, out IntPtr ppFactory);

    private static DXGI_SWAP_CHAIN_DESC1 swapChainDesc1;

    [DllImport("d3d12.dll")]
    public static extern int D3D12SerializeRootSignature(
        ref D3D12_ROOT_SIGNATURE_DESC pRootSignature,
        uint Version,
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
        D3D12_RESOURCE_STATE_RENDER_TARGET = 0x4,
        D3D12_RESOURCE_STATE_GENERIC_READ = 
            (D3D12_RESOURCE_STATE_VERTEX_AND_CONSTANT_BUFFER | 0x2 | 0x40 | 0x80 | 0x200 | 0x800),
        D3D12_RESOURCE_STATE_PRESENT = 0
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
        public uint Format;
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
        D3D12_RESOURCE_FLAG_ALLOW_RENDER_TARGET = 0x1
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
        D3D12_CPU_PAGE_PROPERTY_UNKNOWN = 0
    }

    public enum D3D12_MEMORY_POOL
    {
        D3D12_MEMORY_POOL_UNKNOWN = 0
    }

    [Flags]
    public enum D3D12_HEAP_FLAGS
    {
        D3D12_HEAP_FLAG_NONE = 0
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
        public uint Format;
        public uint InputSlot;
        public uint AlignedByteOffset;
        public D3D12_INPUT_CLASSIFICATION InputSlotClass;
        public uint InstanceDataStepRate;
    }

    enum D3D12_INPUT_CLASSIFICATION
    {
        D3D12_INPUT_CLASSIFICATION_PER_VERTEX_DATA = 0
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

    [StructLayout(LayoutKind.Sequential)]
    public struct D3D12_ROOT_PARAMETER
    {
        public D3D12_ROOT_PARAMETER_TYPE ParameterType;
        public D3D12_ROOT_DESCRIPTOR_TABLE DescriptorTable;
        public D3D12_SHADER_VISIBILITY ShaderVisibility;
    }

    public enum D3D12_ROOT_PARAMETER_TYPE
    {
        D3D12_ROOT_PARAMETER_TYPE_DESCRIPTOR_TABLE = 0,
        D3D12_ROOT_PARAMETER_TYPE_32BIT_CONSTANTS = 1,
        D3D12_ROOT_PARAMETER_TYPE_CBV = 2
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct D3D12_ROOT_DESCRIPTOR_TABLE
    {
        public uint NumDescriptorRanges;
        public IntPtr pDescriptorRanges;
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

    public enum D3D12_DESCRIPTOR_RANGE_TYPE
    {
        D3D12_DESCRIPTOR_RANGE_TYPE_SRV = 0,
        D3D12_DESCRIPTOR_RANGE_TYPE_UAV = 1,
        D3D12_DESCRIPTOR_RANGE_TYPE_CBV = 2,
        D3D12_DESCRIPTOR_RANGE_TYPE_SAMPLER = 3
    }

    public enum D3D12_SHADER_VISIBILITY
    {
        D3D12_SHADER_VISIBILITY_ALL = 0,
        D3D12_SHADER_VISIBILITY_PIXEL = 5
    }

    [Flags]
    public enum D3D12_ROOT_SIGNATURE_FLAGS
    {
        D3D12_ROOT_SIGNATURE_FLAG_NONE = 0,
        D3D12_ROOT_SIGNATURE_FLAG_ALLOW_INPUT_ASSEMBLER_INPUT_LAYOUT = 0x1
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct D3D12_VERTEX_BUFFER_VIEW
    {
        public ulong BufferLocation;
        public uint SizeInBytes;
        public uint StrideInBytes;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct D3D12_CONSTANT_BUFFER_VIEW_DESC
    {
        public ulong BufferLocation;
        public uint SizeInBytes;
    }

    [Flags]
    public enum D3D12_FENCE_FLAGS
    {
        D3D12_FENCE_FLAG_NONE = 0
    }

    [StructLayout(LayoutKind.Sequential)]
    struct D3D12_STREAM_OUTPUT_DESC
    {
        public IntPtr pSODeclaration;
        public uint NumEntries;
        public IntPtr pBufferStrides;
        public uint NumStrides;
        public uint RasterizedStream;
    }

    [StructLayout(LayoutKind.Sequential)]
    struct D3D12_BLEND_DESC
    {
        public int AlphaToCoverageEnable;
        public int IndependentBlendEnable;
        [MarshalAs(UnmanagedType.ByValArray, SizeConst = 8)]
        public D3D12_RENDER_TARGET_BLEND_DESC[] RenderTarget;
    }

    [StructLayout(LayoutKind.Sequential)]
    struct D3D12_RENDER_TARGET_BLEND_DESC
    {
        public int BlendEnable;
        public int LogicOpEnable;
        public D3D12_BLEND SrcBlend;
        public D3D12_BLEND DestBlend;
        public D3D12_BLEND_OP BlendOp;
        public D3D12_BLEND SrcBlendAlpha;
        public D3D12_BLEND DestBlendAlpha;
        public D3D12_BLEND_OP BlendOpAlpha;
        public D3D12_LOGIC_OP LogicOp;
        public byte RenderTargetWriteMask;
    }

    enum D3D12_BLEND
    {
        D3D12_BLEND_ZERO = 1,
        D3D12_BLEND_ONE = 2
    }

    enum D3D12_BLEND_OP
    {
        D3D12_BLEND_OP_ADD = 1
    }

    enum D3D12_LOGIC_OP
    {
        D3D12_LOGIC_OP_NOOP = 4
    }

    [StructLayout(LayoutKind.Sequential)]
    struct D3D12_RASTERIZER_DESC
    {
        public D3D12_FILL_MODE FillMode;
        public D3D12_CULL_MODE CullMode;
        public int FrontCounterClockwise;
        public int DepthBias;
        public float DepthBiasClamp;
        public float SlopeScaledDepthBias;
        public int DepthClipEnable;
        public int MultisampleEnable;
        public int AntialiasedLineEnable;
        public uint ForcedSampleCount;
        public D3D12_CONSERVATIVE_RASTERIZATION_MODE ConservativeRaster;
    }

    enum D3D12_FILL_MODE
    {
        D3D12_FILL_MODE_SOLID = 3
    }

    enum D3D12_CULL_MODE
    {
        D3D12_CULL_MODE_NONE = 1,
        D3D12_CULL_MODE_BACK = 3
    }

    enum D3D12_CONSERVATIVE_RASTERIZATION_MODE
    {
        D3D12_CONSERVATIVE_RASTERIZATION_MODE_OFF = 0
    }

    [StructLayout(LayoutKind.Sequential)]
    struct D3D12_DEPTH_STENCIL_DESC
    {
        public int DepthEnable;
        public D3D12_DEPTH_WRITE_MASK DepthWriteMask;
        public D3D12_COMPARISON_FUNC DepthFunc;
        public int StencilEnable;
        public byte StencilReadMask;
        public byte StencilWriteMask;
        public D3D12_DEPTH_STENCILOP_DESC FrontFace;
        public D3D12_DEPTH_STENCILOP_DESC BackFace;
    }

    enum D3D12_DEPTH_WRITE_MASK
    {
        D3D12_DEPTH_WRITE_MASK_ALL = 1
    }

    enum D3D12_COMPARISON_FUNC
    {
        D3D12_COMPARISON_FUNC_LESS = 2,
        D3D12_COMPARISON_FUNC_ALWAYS = 8
    }

    [StructLayout(LayoutKind.Sequential)]
    struct D3D12_DEPTH_STENCILOP_DESC
    {
        public D3D12_STENCIL_OP StencilFailOp;
        public D3D12_STENCIL_OP StencilDepthFailOp;
        public D3D12_STENCIL_OP StencilPassOp;
        public D3D12_COMPARISON_FUNC StencilFunc;
    }

    enum D3D12_STENCIL_OP
    {
        D3D12_STENCIL_OP_KEEP = 1
    }

    enum D3D12_INDEX_BUFFER_STRIP_CUT_VALUE
    {
        D3D12_INDEX_BUFFER_STRIP_CUT_VALUE_DISABLED = 0
    }

    enum D3D12_PRIMITIVE_TOPOLOGY_TYPE
    {
        D3D12_PRIMITIVE_TOPOLOGY_TYPE_TRIANGLE = 3
    }

    [StructLayout(LayoutKind.Sequential)]
    struct D3D12_CACHED_PIPELINE_STATE
    {
        public IntPtr pCachedBlob;
        public IntPtr CachedBlobSizeInBytes;
    }

    enum D3D12_PIPELINE_STATE_FLAGS
    {
        D3D12_PIPELINE_STATE_FLAG_NONE = 0
    }

    [StructLayout(LayoutKind.Sequential)]
    struct D3D12_VIEWPORT
    {
        public float TopLeftX;
        public float TopLeftY;
        public float Width;
        public float Height;
        public float MinDepth;
        public float MaxDepth;
    }

    [StructLayout(LayoutKind.Sequential)]
    struct D3D12_RECT
    {
        public int left;
        public int top;
        public int right;
        public int bottom;
    }

    enum D3D12_RESOURCE_BARRIER_TYPE
    {
        D3D12_RESOURCE_BARRIER_TYPE_TRANSITION = 0
    }

    enum D3D12_RESOURCE_BARRIER_FLAGS
    {
        D3D12_RESOURCE_BARRIER_FLAG_NONE = 0
    }

    [StructLayout(LayoutKind.Explicit)]
    struct D3D12_RESOURCE_BARRIER
    {
        [FieldOffset(0)]
        public D3D12_RESOURCE_BARRIER_TYPE Type;
        [FieldOffset(4)]
        public D3D12_RESOURCE_BARRIER_FLAGS Flags;
        [FieldOffset(8)]
        public D3D12_RESOURCE_TRANSITION_BARRIER Transition;
    }

    [StructLayout(LayoutKind.Sequential)]
    struct D3D12_RESOURCE_TRANSITION_BARRIER
    {
        public IntPtr pResource;
        public uint Subresource;
        public D3D12_RESOURCE_STATES StateBefore;
        public D3D12_RESOURCE_STATES StateAfter;
    }

    [StructLayout(LayoutKind.Sequential)]
    struct D3D12_RANGE
    {
        public IntPtr Begin;
        public IntPtr End;
    }

    enum D3D_PRIMITIVE_TOPOLOGY
    {
        D3D_PRIMITIVE_TOPOLOGY_TRIANGLELIST = 4
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct DXGI_SWAP_CHAIN_DESC1
    {
        public uint Width;
        public uint Height;
        public uint Format;
        public bool Stereo; 
        public DXGI_SAMPLE_DESC SampleDesc;
        public uint BufferUsage;
        public uint BufferCount;
        public DXGI_SCALING Scaling;
        public uint SwapEffect;
        public DXGI_ALPHA_MODE AlphaMode;
        public uint Flags;
    }

    public enum DXGI_SCALING
    {
        DXGI_SCALING_STRETCH = 0
    }

    public enum DXGI_ALPHA_MODE
    {
        DXGI_ALPHA_MODE_UNSPECIFIED = 0
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct D3D12_CPU_DESCRIPTOR_HANDLE_ARRAY
    {
        public IntPtr ptr;
    }

    // DXGI formats
    const uint DXGI_FORMAT_UNKNOWN = 0;
    const uint DXGI_FORMAT_R32G32_FLOAT = 16;
    const uint DXGI_FORMAT_R8G8B8A8_UNORM = 28;

    const uint DXGI_USAGE_RENDER_TARGET_OUTPUT = 0x00000020;
    const uint DXGI_SWAP_EFFECT_FLIP_DISCARD = 4;
    const uint DXGI_SWAP_CHAIN_FLAG_ALLOW_MODE_SWITCH = 2;
    const uint DXGI_SWAP_CHAIN_FLAG_FRAME_LATENCY_WAITABLE_OBJECT = 0x40;

    const uint D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES = 0xffffffff;
    const uint D3D12_DESCRIPTOR_RANGE_OFFSET_APPEND = 0xffffffff;

    // GUIDs
    static readonly Guid IID_IDXGIFactory4 = new Guid("1bc6ea02-ef36-464f-bf0c-21ca39e5168a");
    static readonly Guid IID_IDXGISwapChain3 = new Guid("94d99bdb-f1f8-4ab0-b236-7da0170edab1");
    static readonly Guid IID_ID3D12Device = new Guid("189819f1-1db6-4b57-be54-1821339b85f7");
    static readonly Guid IID_ID3D12CommandQueue = new Guid("0ec870a6-5d7e-4c22-8cfc-5baae07616ed");
    static readonly Guid IID_ID3D12CommandAllocator = new Guid("6102dee4-af59-4b09-b999-b44d73f09b24");
    static readonly Guid IID_ID3D12GraphicsCommandList = new Guid("5b160d0f-ac1b-4185-8ba8-b3ae42a5a455");
    static readonly Guid IID_ID3D12DescriptorHeap = new Guid("8efb471d-616c-4f49-90f7-127bb763fa51");
    static readonly Guid IID_ID3D12Resource = new Guid("696442be-a72e-4059-bc79-5b5c98040fad");
    static readonly Guid IID_ID3D12PipelineState = new Guid("765a30f3-f624-4c6f-a828-ace948622445");
    static readonly Guid IID_ID3D12RootSignature = new Guid("c54a6b66-72df-4ee8-8be5-a946a1429214");
    static readonly Guid IID_ID3D12Fence = new Guid("0a753dcf-c4d8-4b91-adf6-be5a60d95a76");
    static readonly Guid IID_ID3D12Debug = new Guid("344488b7-6846-474b-b989-f027448245e0");

    // Delegates
    delegate int CreateCommandQueueDelegate(IntPtr device, ref D3D12_COMMAND_QUEUE_DESC desc, ref Guid riid, out IntPtr commandQueue);
    delegate int CreateDescriptorHeapDelegate(IntPtr device, ref D3D12_DESCRIPTOR_HEAP_DESC desc, ref Guid riid, out IntPtr heap);
    delegate uint GetDescriptorHandleIncrementSizeDelegate(IntPtr device, D3D12_DESCRIPTOR_HEAP_TYPE type);
    delegate int GetBufferDelegate(IntPtr swapChain, uint buffer, ref Guid riid, out IntPtr surface);
    delegate void CreateRenderTargetViewDelegate(IntPtr device, IntPtr resource, IntPtr desc, D3D12_CPU_DESCRIPTOR_HANDLE handle);
    delegate void CreateConstantBufferViewDelegate(IntPtr device, ref D3D12_CONSTANT_BUFFER_VIEW_DESC desc, D3D12_CPU_DESCRIPTOR_HANDLE destDescriptor);
    delegate int CreateCommandAllocatorDelegate(IntPtr device, D3D12_COMMAND_LIST_TYPE type, ref Guid riid, out IntPtr allocator);
    delegate int CreateRootSignatureDelegate(IntPtr device, uint nodeMask, IntPtr blobWithRootSignature, IntPtr blobLengthInBytes, ref Guid riid, out IntPtr rootSignature);
    delegate int CreateGraphicsPipelineStateDelegate(IntPtr device, ref D3D12_GRAPHICS_PIPELINE_STATE_DESC desc, ref Guid riid, out IntPtr pipelineState);
    delegate int CreateCommandListDelegate(IntPtr device, uint nodeMask, D3D12_COMMAND_LIST_TYPE type, IntPtr allocator, IntPtr initialState, ref Guid riid, out IntPtr commandList);
    delegate int CloseDelegate(IntPtr commandList);
    delegate int CreateCommittedResourceDelegate(IntPtr device, ref D3D12_HEAP_PROPERTIES heapProperties, D3D12_HEAP_FLAGS heapFlags, ref D3D12_RESOURCE_DESC desc, D3D12_RESOURCE_STATES initialState, IntPtr optimizedClearValue, ref Guid riid, out IntPtr resource);
    delegate int MapDelegate(IntPtr resource, uint subresource, ref D3D12_RANGE readRange, out IntPtr data);
    delegate void UnmapDelegate(IntPtr resource, uint subresource, ref D3D12_RANGE writtenRange);
    delegate ulong GetGPUVirtualAddressDelegate(IntPtr resource);
    delegate int CreateFenceDelegate(IntPtr device, ulong initialValue, D3D12_FENCE_FLAGS flags, ref Guid riid, out IntPtr fence);
    delegate int ResetCommandAllocatorDelegate(IntPtr allocator);
    delegate int ResetCommandListDelegate(IntPtr commandList, IntPtr allocator, IntPtr initialState);
    delegate void SetGraphicsRootSignatureDelegate(IntPtr commandList, IntPtr rootSignature);
    delegate void SetDescriptorHeapsDelegate(IntPtr commandList, uint numDescriptorHeaps, IntPtr[] ppDescriptorHeaps);
    delegate void SetGraphicsRootDescriptorTableDelegate(IntPtr commandList, uint rootParameterIndex, D3D12_GPU_DESCRIPTOR_HANDLE baseDescriptor);
    delegate void RSSetViewportsDelegate(IntPtr commandList, uint numViewports, D3D12_VIEWPORT[] viewports);
    delegate void RSSetScissorRectsDelegate(IntPtr commandList, uint numRects, D3D12_RECT[] rects);
    delegate void ResourceBarrierDelegate(IntPtr commandList, uint numBarriers, D3D12_RESOURCE_BARRIER[] barriers);
    delegate void OMSetRenderTargetsDelegate(IntPtr commandList, uint numRenderTargetDescriptors, D3D12_CPU_DESCRIPTOR_HANDLE_ARRAY[] renderTargetDescriptors, bool RTsSingleHandleToDescriptorRange, IntPtr depthStencilDescriptor);
    delegate void ClearRenderTargetViewDelegate(IntPtr commandList, D3D12_CPU_DESCRIPTOR_HANDLE renderTargetView, float[] colorRGBA, uint numRects, IntPtr rects);
    delegate void IASetPrimitiveTopologyDelegate(IntPtr commandList, D3D_PRIMITIVE_TOPOLOGY topology);
    delegate void IASetVertexBuffersDelegate(IntPtr commandList, uint startSlot, uint numViews, D3D12_VERTEX_BUFFER_VIEW[] views);
    delegate void DrawInstancedDelegate(IntPtr commandList, uint vertexCountPerInstance, uint instanceCount, uint startVertexLocation, uint startInstanceLocation);
    delegate int ExecuteCommandListsDelegate(IntPtr commandQueue, uint numCommandLists, IntPtr[] commandLists);
    delegate int PresentDelegate(IntPtr swapChain, uint syncInterval, uint flags);
    delegate int SignalDelegate(IntPtr commandQueue, IntPtr fence, ulong value);
    delegate ulong GetCompletedValueDelegate(IntPtr fence);
    delegate int SetEventOnCompletionDelegate(IntPtr fence, ulong value, IntPtr hEvent);
    delegate int CreateSwapChainForHwndDelegate(IntPtr factory, IntPtr device, IntPtr hwnd, ref DXGI_SWAP_CHAIN_DESC1 desc, IntPtr fullscreenDesc, IntPtr restrictToOutput, out IntPtr swapChain);
    delegate uint GetCurrentBackBufferIndexDelegate(IntPtr swapChain);
    delegate void GetCPUDescriptorHandleForHeapStartThunk(IntPtr heap, out D3D12_CPU_DESCRIPTOR_HANDLE handle);
    delegate void GetGPUDescriptorHandleForHeapStartThunk(IntPtr heap, out D3D12_GPU_DESCRIPTOR_HANDLE handle);
    delegate IntPtr GetBufferPointerDelegate(IntPtr blob);
    delegate ulong GetBufferSizeDelegate(IntPtr blob);

    // Helpers
    static D3D12_BLEND_DESC GetDefaultBlendDesc()
    {
        var desc = new D3D12_BLEND_DESC
        {
            AlphaToCoverageEnable = 0,
            IndependentBlendEnable = 0,
            RenderTarget = new D3D12_RENDER_TARGET_BLEND_DESC[8]
        };
        for (int i = 0; i < 8; i++)
        {
            desc.RenderTarget[i] = new D3D12_RENDER_TARGET_BLEND_DESC
            {
                BlendEnable = 0,
                LogicOpEnable = 0,
                SrcBlend = D3D12_BLEND.D3D12_BLEND_ONE,
                DestBlend = D3D12_BLEND.D3D12_BLEND_ZERO,
                BlendOp = D3D12_BLEND_OP.D3D12_BLEND_OP_ADD,
                SrcBlendAlpha = D3D12_BLEND.D3D12_BLEND_ONE,
                DestBlendAlpha = D3D12_BLEND.D3D12_BLEND_ZERO,
                BlendOpAlpha = D3D12_BLEND_OP.D3D12_BLEND_OP_ADD,
                LogicOp = D3D12_LOGIC_OP.D3D12_LOGIC_OP_NOOP,
                RenderTargetWriteMask = 0x0F
            };
        }
        return desc;
    }

    static D3D12_RASTERIZER_DESC GetDefaultRasterizerDesc()
    {
        return new D3D12_RASTERIZER_DESC
        {
            FillMode = D3D12_FILL_MODE.D3D12_FILL_MODE_SOLID,
            CullMode = D3D12_CULL_MODE.D3D12_CULL_MODE_BACK,
            FrontCounterClockwise = 0,
            DepthBias = 0,
            DepthBiasClamp = 0.0f,
            SlopeScaledDepthBias = 0.0f,
            DepthClipEnable = 1,
            MultisampleEnable = 0,
            AntialiasedLineEnable = 0,
            ForcedSampleCount = 0,
            ConservativeRaster = D3D12_CONSERVATIVE_RASTERIZATION_MODE.D3D12_CONSERVATIVE_RASTERIZATION_MODE_OFF
        };
    }

    static D3D12_DEPTH_STENCIL_DESC GetDefaultDepthStencilDesc()
    {
        return new D3D12_DEPTH_STENCIL_DESC
        {
            DepthEnable = 1,
            DepthWriteMask = D3D12_DEPTH_WRITE_MASK.D3D12_DEPTH_WRITE_MASK_ALL,
            DepthFunc = D3D12_COMPARISON_FUNC.D3D12_COMPARISON_FUNC_LESS,
            StencilEnable = 0,
            StencilReadMask = 0xFF,
            StencilWriteMask = 0xFF,
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

    static D3D12_RESOURCE_BARRIER GetTransitionBarrier(IntPtr resource, D3D12_RESOURCE_STATES stateBefore, D3D12_RESOURCE_STATES stateAfter)
    {
        return new D3D12_RESOURCE_BARRIER
        {
            Type = D3D12_RESOURCE_BARRIER_TYPE.D3D12_RESOURCE_BARRIER_TYPE_TRANSITION,
            Flags = D3D12_RESOURCE_BARRIER_FLAGS.D3D12_RESOURCE_BARRIER_FLAG_NONE,
            Transition = new D3D12_RESOURCE_TRANSITION_BARRIER
            {
                pResource = resource,
                Subresource = D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES,
                StateBefore = stateBefore,
                StateAfter = stateAfter
            }
        };
    }

    // Members
    const int FrameCount = 2;
    IntPtr device;
    IntPtr commandQueue;
    IntPtr swapChain;
    IntPtr rtvHeap;
    IntPtr cbvHeap;
    IntPtr commandAllocator;
    IntPtr commandList;
    IntPtr rootSignature;
    IntPtr pipelineState;
    IntPtr vertexBuffer;
    IntPtr constantBuffer;
    IntPtr constantBufferDataBegin;
    IntPtr fence;
    IntPtr fenceEvent;
    ulong fenceValue;
    IntPtr[] renderTargets = new IntPtr[FrameCount];
    uint rtvDescriptorSize;
    uint cbvDescriptorSize;
    int frameIndex = 0;
    D3D12_VERTEX_BUFFER_VIEW vertexBufferView;
    Stopwatch stopwatch;

    Vertex[] quadVertices = new Vertex[]
    {
        new Vertex { X = -1.0f, Y = -1.0f },
        new Vertex { X =  1.0f, Y = -1.0f },
        new Vertex { X = -1.0f, Y =  1.0f },
        new Vertex { X = -1.0f, Y =  1.0f },
        new Vertex { X =  1.0f, Y = -1.0f },
        new Vertex { X =  1.0f, Y =  1.0f }
    };

    IntPtr GetCPUDescriptorHandleForHeapStart(IntPtr heap)
    {
        IntPtr vTable = Marshal.ReadIntPtr(heap);
        IntPtr getCpuHandlePtr = Marshal.ReadIntPtr(vTable, 9 * IntPtr.Size);
        var thunk = Marshal.GetDelegateForFunctionPointer<GetCPUDescriptorHandleForHeapStartThunk>(getCpuHandlePtr);
        D3D12_CPU_DESCRIPTOR_HANDLE handle = new D3D12_CPU_DESCRIPTOR_HANDLE();
        thunk(heap, out handle);
        return handle.ptr;
    }

    D3D12_GPU_DESCRIPTOR_HANDLE GetGPUDescriptorHandleForHeapStart(IntPtr heap)
    {
        IntPtr vTable = Marshal.ReadIntPtr(heap);
        IntPtr getGpuHandlePtr = Marshal.ReadIntPtr(vTable, 10 * IntPtr.Size);
        var thunk = Marshal.GetDelegateForFunctionPointer<GetGPUDescriptorHandleForHeapStartThunk>(getGpuHandlePtr);
        D3D12_GPU_DESCRIPTOR_HANDLE handle = new D3D12_GPU_DESCRIPTOR_HANDLE();
        thunk(heap, out handle);
        return handle;
    }

    uint GetCurrentBackBufferIndex(IntPtr swapChain)
    {
        IntPtr vTable = Marshal.ReadIntPtr(swapChain);
        IntPtr getCurrentIndexPtr = Marshal.ReadIntPtr(vTable, 36 * IntPtr.Size);
        var getCurrentBackBufferIndex = Marshal.GetDelegateForFunctionPointer<GetCurrentBackBufferIndexDelegate>(getCurrentIndexPtr);
        return getCurrentBackBufferIndex(swapChain);
    }

    IntPtr CompileShaderFromFile(string fileName, string entryPoint, string target)
    {
        IntPtr shaderBlob;
        IntPtr errorBlob;
        int result = D3DCompileFromFile(fileName, IntPtr.Zero, IntPtr.Zero, entryPoint, target, 0, 0, out shaderBlob, out errorBlob);
        if (result < 0)
        {
            if (errorBlob != IntPtr.Zero)
            {
                IntPtr errorPtr = GetBufferPointer(errorBlob);
                string error = Marshal.PtrToStringAnsi(errorPtr);
                Console.WriteLine("Shader compilation error: " + error);
                Marshal.Release(errorBlob);
            }
            throw new Exception("Failed to compile shader.");
        }
        return shaderBlob;
    }

    IntPtr GetBufferPointer(IntPtr blob)
    {
        IntPtr vTable = Marshal.ReadIntPtr(blob);
        IntPtr getBufferPointerPtr = Marshal.ReadIntPtr(vTable, 3 * IntPtr.Size);
        var getBufferPointer = Marshal.GetDelegateForFunctionPointer<GetBufferPointerDelegate>(getBufferPointerPtr);
        return getBufferPointer(blob);
    }

    ulong GetBlobSize(IntPtr blob)
    {
        IntPtr vTable = Marshal.ReadIntPtr(blob);
        IntPtr getBufferSizePtr = Marshal.ReadIntPtr(vTable, 4 * IntPtr.Size);
        var getBufferSize = Marshal.GetDelegateForFunctionPointer<GetBufferSizeDelegate>(getBufferSizePtr);
        return getBufferSize(blob);
    }

    static byte[] StructArrayToByteArray<T>(T[] array) where T : struct
    {
        int size = Marshal.SizeOf<T>() * array.Length;
        byte[] bytes = new byte[size];
        GCHandle handle = GCHandle.Alloc(array, GCHandleType.Pinned);
        try
        {
            Marshal.Copy(handle.AddrOfPinnedObject(), bytes, 0, size);
        }
        finally
        {
            handle.Free();
        }
        return bytes;
    }

    private void LoadAssets()
    {
        // Root Signature with 1 Descriptor Table (CBV)
        var cbvRange = new D3D12_DESCRIPTOR_RANGE
        {
            RangeType = D3D12_DESCRIPTOR_RANGE_TYPE.D3D12_DESCRIPTOR_RANGE_TYPE_CBV,
            NumDescriptors = 1,
            BaseShaderRegister = 0,
            RegisterSpace = 0,
            OffsetInDescriptorsFromTableStart = D3D12_DESCRIPTOR_RANGE_OFFSET_APPEND
        };

        GCHandle cbvRangeHandle = GCHandle.Alloc(new D3D12_DESCRIPTOR_RANGE[] { cbvRange }, GCHandleType.Pinned);
        var rootParameter = new D3D12_ROOT_PARAMETER
        {
            ParameterType = D3D12_ROOT_PARAMETER_TYPE.D3D12_ROOT_PARAMETER_TYPE_DESCRIPTOR_TABLE,
            DescriptorTable = new D3D12_ROOT_DESCRIPTOR_TABLE { NumDescriptorRanges = 1, pDescriptorRanges = cbvRangeHandle.AddrOfPinnedObject() },
            ShaderVisibility = D3D12_SHADER_VISIBILITY.D3D12_SHADER_VISIBILITY_PIXEL
        };
        GCHandle rootParamHandle = GCHandle.Alloc(new D3D12_ROOT_PARAMETER[] { rootParameter }, GCHandleType.Pinned);

        D3D12_ROOT_SIGNATURE_DESC rootSignatureDesc = new D3D12_ROOT_SIGNATURE_DESC
        {
            NumParameters = 1,
            pParameters = rootParamHandle.AddrOfPinnedObject(),
            NumStaticSamplers = 0,
            pStaticSamplers = IntPtr.Zero,
            Flags = D3D12_ROOT_SIGNATURE_FLAGS.D3D12_ROOT_SIGNATURE_FLAG_ALLOW_INPUT_ASSEMBLER_INPUT_LAYOUT
        };

        IntPtr signature = IntPtr.Zero;
        IntPtr error = IntPtr.Zero;
        D3D12SerializeRootSignature(ref rootSignatureDesc, D3D_ROOT_SIGNATURE_VERSION_1, out signature, out error);
        
        cbvRangeHandle.Free();
        rootParamHandle.Free();

        IntPtr vTable = Marshal.ReadIntPtr(device);
        IntPtr createRootSigPtr = Marshal.ReadIntPtr(vTable, 16 * IntPtr.Size);
        var createRootSignature = Marshal.GetDelegateForFunctionPointer<CreateRootSignatureDelegate>(createRootSigPtr);
        Guid rootSignatureGuid = IID_ID3D12RootSignature;
        createRootSignature(device, 0, GetBufferPointer(signature), (IntPtr)GetBlobSize(signature), ref rootSignatureGuid, out rootSignature);
        if(signature != IntPtr.Zero) Marshal.Release(signature);

        // Compile Shaders
        IntPtr vertexShader = CompileShaderFromFile("hello.hlsl", "VSMain", "vs_5_0");
        IntPtr pixelShader = CompileShaderFromFile("hello.hlsl", "PSMain", "ps_5_0");

        // Input Layout
        D3D12_INPUT_ELEMENT_DESC[] inputElementDescs = new[]
        {
            new D3D12_INPUT_ELEMENT_DESC
            {
                SemanticName = Marshal.StringToHGlobalAnsi("POSITION"),
                SemanticIndex = 0,
                Format = DXGI_FORMAT_R32G32_FLOAT,
                InputSlot = 0,
                AlignedByteOffset = 0,
                InputSlotClass = D3D12_INPUT_CLASSIFICATION.D3D12_INPUT_CLASSIFICATION_PER_VERTEX_DATA,
                InstanceDataStepRate = 0
            }
        };
        GCHandle inputElementsHandle = GCHandle.Alloc(inputElementDescs, GCHandleType.Pinned);

        D3D12_GRAPHICS_PIPELINE_STATE_DESC psoDesc = new D3D12_GRAPHICS_PIPELINE_STATE_DESC
        {
            pRootSignature = rootSignature,
            VS = new D3D12_SHADER_BYTECODE { pShaderBytecode = GetBufferPointer(vertexShader), BytecodeLength = (IntPtr)GetBlobSize(vertexShader) },
            PS = new D3D12_SHADER_BYTECODE { pShaderBytecode = GetBufferPointer(pixelShader), BytecodeLength = (IntPtr)GetBlobSize(pixelShader) },
            BlendState = GetDefaultBlendDesc(),
            SampleMask = uint.MaxValue,
            RasterizerState = GetDefaultRasterizerDesc(),
            DepthStencilState = GetDefaultDepthStencilDesc(),
            InputLayout = new D3D12_INPUT_LAYOUT_DESC { pInputElementDescs = inputElementsHandle.AddrOfPinnedObject(), NumElements = 1 },
            PrimitiveTopologyType = D3D12_PRIMITIVE_TOPOLOGY_TYPE.D3D12_PRIMITIVE_TOPOLOGY_TYPE_TRIANGLE,
            NumRenderTargets = 1,
            RTVFormats = new uint[8] { DXGI_FORMAT_R8G8B8A8_UNORM, 0, 0, 0, 0, 0, 0, 0 },
            DSVFormat = DXGI_FORMAT_UNKNOWN,
            SampleDesc = new DXGI_SAMPLE_DESC { Count = 1, Quality = 0 },
            NodeMask = 0
        };
        // Disable culling and depth for FS quad
        psoDesc.RasterizerState.CullMode = D3D12_CULL_MODE.D3D12_CULL_MODE_NONE;
        psoDesc.DepthStencilState.DepthEnable = 0;

        IntPtr createPipelineStatePtr = Marshal.ReadIntPtr(vTable, 10 * IntPtr.Size);
        var createPipelineState = Marshal.GetDelegateForFunctionPointer<CreateGraphicsPipelineStateDelegate>(createPipelineStatePtr);
        Guid pipelineStateGuid = IID_ID3D12PipelineState;
        createPipelineState(device, ref psoDesc, ref pipelineStateGuid, out pipelineState);
        inputElementsHandle.Free();

        // Create Command List
        IntPtr createCommandListPtr = Marshal.ReadIntPtr(vTable, 12 * IntPtr.Size);
        var createCommandList = Marshal.GetDelegateForFunctionPointer<CreateCommandListDelegate>(createCommandListPtr);
        Guid commandListGuid = IID_ID3D12GraphicsCommandList;
        createCommandList(device, 0, D3D12_COMMAND_LIST_TYPE.D3D12_COMMAND_LIST_TYPE_DIRECT, commandAllocator, pipelineState, ref commandListGuid, out commandList);

        IntPtr vTableCmdList = Marshal.ReadIntPtr(commandList);
        IntPtr closePtr = Marshal.ReadIntPtr(vTableCmdList, 9 * IntPtr.Size);
        var close = Marshal.GetDelegateForFunctionPointer<CloseDelegate>(closePtr);
        close(commandList);

        // Vertex Buffer
        uint vertexBufferSize = (uint)(Marshal.SizeOf<Vertex>() * quadVertices.Length);
        D3D12_HEAP_PROPERTIES heapProps = new D3D12_HEAP_PROPERTIES { Type = D3D12_HEAP_TYPE.D3D12_HEAP_TYPE_UPLOAD };
        D3D12_RESOURCE_DESC resDesc = new D3D12_RESOURCE_DESC
        {
            Dimension = D3D12_RESOURCE_DIMENSION.D3D12_RESOURCE_DIMENSION_BUFFER,
            Width = vertexBufferSize,
            Height = 1, DepthOrArraySize = 1, MipLevels = 1, SampleDesc = new DXGI_SAMPLE_DESC { Count = 1 },
            Layout = D3D12_TEXTURE_LAYOUT.D3D12_TEXTURE_LAYOUT_ROW_MAJOR
        };

        IntPtr createResourcePtr = Marshal.ReadIntPtr(vTable, 27 * IntPtr.Size);
        var createResource = Marshal.GetDelegateForFunctionPointer<CreateCommittedResourceDelegate>(createResourcePtr);
        Guid resourceGuid = IID_ID3D12Resource;
        createResource(device, ref heapProps, D3D12_HEAP_FLAGS.D3D12_HEAP_FLAG_NONE, ref resDesc, D3D12_RESOURCE_STATES.D3D12_RESOURCE_STATE_GENERIC_READ, IntPtr.Zero, ref resourceGuid, out vertexBuffer);

        // Map VB
        IntPtr vTableRes = Marshal.ReadIntPtr(vertexBuffer);
        IntPtr mapPtr = Marshal.ReadIntPtr(vTableRes, 8 * IntPtr.Size);
        var map = Marshal.GetDelegateForFunctionPointer<MapDelegate>(mapPtr);
        IntPtr pData;
        D3D12_RANGE readRange = new D3D12_RANGE();
        map(vertexBuffer, 0, ref readRange, out pData);
        byte[] vData = StructArrayToByteArray(quadVertices);
        Marshal.Copy(vData, 0, pData, vData.Length);
        
        IntPtr unmapPtr = Marshal.ReadIntPtr(vTableRes, 9 * IntPtr.Size);
        var unmap = Marshal.GetDelegateForFunctionPointer<UnmapDelegate>(unmapPtr);
        unmap(vertexBuffer, 0, ref readRange);

        // VB View
        IntPtr getGPUVirtualAddressPtr = Marshal.ReadIntPtr(vTableRes, 11 * IntPtr.Size);
        var getGPUVirtualAddress = Marshal.GetDelegateForFunctionPointer<GetGPUVirtualAddressDelegate>(getGPUVirtualAddressPtr);
        vertexBufferView = new D3D12_VERTEX_BUFFER_VIEW
        {
            BufferLocation = getGPUVirtualAddress(vertexBuffer),
            StrideInBytes = (uint)Marshal.SizeOf<Vertex>(),
            SizeInBytes = vertexBufferSize
        };

        // Constant Buffer
        uint constantBufferSize = 256;
        resDesc.Width = constantBufferSize;
        createResource(device, ref heapProps, D3D12_HEAP_FLAGS.D3D12_HEAP_FLAG_NONE, ref resDesc, D3D12_RESOURCE_STATES.D3D12_RESOURCE_STATE_GENERIC_READ, IntPtr.Zero, ref resourceGuid, out constantBuffer);

        // Map CB (keep mapped)
        vTableRes = Marshal.ReadIntPtr(constantBuffer);
        mapPtr = Marshal.ReadIntPtr(vTableRes, 8 * IntPtr.Size);
        map = Marshal.GetDelegateForFunctionPointer<MapDelegate>(mapPtr);
        map(constantBuffer, 0, ref readRange, out constantBufferDataBegin);

        // Create CBV
        getGPUVirtualAddressPtr = Marshal.ReadIntPtr(vTableRes, 11 * IntPtr.Size);
        getGPUVirtualAddress = Marshal.GetDelegateForFunctionPointer<GetGPUVirtualAddressDelegate>(getGPUVirtualAddressPtr);
        D3D12_CONSTANT_BUFFER_VIEW_DESC cbvDesc = new D3D12_CONSTANT_BUFFER_VIEW_DESC
        {
            BufferLocation = getGPUVirtualAddress(constantBuffer),
            SizeInBytes = constantBufferSize
        };
        D3D12_CPU_DESCRIPTOR_HANDLE cbvHandle = new D3D12_CPU_DESCRIPTOR_HANDLE { ptr = GetCPUDescriptorHandleForHeapStart(cbvHeap) };
        IntPtr createCBVPtr = Marshal.ReadIntPtr(vTable, 17 * IntPtr.Size);
        var createCBV = Marshal.GetDelegateForFunctionPointer<CreateConstantBufferViewDelegate>(createCBVPtr);
        createCBV(device, ref cbvDesc, cbvHandle);

        // Fence
        IntPtr createFencePtr = Marshal.ReadIntPtr(vTable, 36 * IntPtr.Size);
        var createFence = Marshal.GetDelegateForFunctionPointer<CreateFenceDelegate>(createFencePtr);
        Guid fenceGuid = IID_ID3D12Fence;
        createFence(device, 0, D3D12_FENCE_FLAGS.D3D12_FENCE_FLAG_NONE, ref fenceGuid, out fence);
        fenceValue = 1;
        fenceEvent = CreateEvent(IntPtr.Zero, false, false, null);
        stopwatch = new Stopwatch();
        stopwatch.Start();
    }

    private void PopulateCommandList()
    {
        IntPtr vTableAlloc = Marshal.ReadIntPtr(commandAllocator);
        IntPtr resetAllocPtr = Marshal.ReadIntPtr(vTableAlloc, 8 * IntPtr.Size);
        var resetAlloc = Marshal.GetDelegateForFunctionPointer<ResetCommandAllocatorDelegate>(resetAllocPtr);
        resetAlloc(commandAllocator);

        IntPtr vTableList = Marshal.ReadIntPtr(commandList);
        IntPtr resetListPtr = Marshal.ReadIntPtr(vTableList, 10 * IntPtr.Size);
        var resetList = Marshal.GetDelegateForFunctionPointer<ResetCommandListDelegate>(resetListPtr);
        resetList(commandList, commandAllocator, pipelineState);

        IntPtr setRootSigPtr = Marshal.ReadIntPtr(vTableList, 30 * IntPtr.Size);
        var setRootSig = Marshal.GetDelegateForFunctionPointer<SetGraphicsRootSignatureDelegate>(setRootSigPtr);
        setRootSig(commandList, rootSignature);

        IntPtr setDescHeapsPtr = Marshal.ReadIntPtr(vTableList, 28 * IntPtr.Size);
        var setDescHeaps = Marshal.GetDelegateForFunctionPointer<SetDescriptorHeapsDelegate>(setDescHeapsPtr);
        setDescHeaps(commandList, 1, new IntPtr[] { cbvHeap });

        IntPtr setRootTablePtr = Marshal.ReadIntPtr(vTableList, 32 * IntPtr.Size);
        var setRootTable = Marshal.GetDelegateForFunctionPointer<SetGraphicsRootDescriptorTableDelegate>(setRootTablePtr);
        setRootTable(commandList, 0, GetGPUDescriptorHandleForHeapStart(cbvHeap));

        var viewports = new D3D12_VIEWPORT[] { new D3D12_VIEWPORT { Width = WIDTH, Height = HEIGHT, MaxDepth = 1.0f } };
        IntPtr setVPPtr = Marshal.ReadIntPtr(vTableList, 21 * IntPtr.Size);
        var setVP = Marshal.GetDelegateForFunctionPointer<RSSetViewportsDelegate>(setVPPtr);
        setVP(commandList, 1, viewports);

        var scissors = new D3D12_RECT[] { new D3D12_RECT { right = WIDTH, bottom = HEIGHT } };
        IntPtr setScissorPtr = Marshal.ReadIntPtr(vTableList, 22 * IntPtr.Size);
        var setScissor = Marshal.GetDelegateForFunctionPointer<RSSetScissorRectsDelegate>(setScissorPtr);
        setScissor(commandList, 1, scissors);

        var barrier = GetTransitionBarrier(renderTargets[frameIndex], D3D12_RESOURCE_STATES.D3D12_RESOURCE_STATE_PRESENT, D3D12_RESOURCE_STATES.D3D12_RESOURCE_STATE_RENDER_TARGET);
        IntPtr barrierPtr = Marshal.ReadIntPtr(vTableList, 26 * IntPtr.Size);
        var resBarrier = Marshal.GetDelegateForFunctionPointer<ResourceBarrierDelegate>(barrierPtr);
        resBarrier(commandList, 1, new D3D12_RESOURCE_BARRIER[] { barrier });

        D3D12_CPU_DESCRIPTOR_HANDLE rtvHandle = new D3D12_CPU_DESCRIPTOR_HANDLE { ptr = GetCPUDescriptorHandleForHeapStart(rtvHeap) + frameIndex * (int)rtvDescriptorSize };
        var rtvHandles = new[] { new D3D12_CPU_DESCRIPTOR_HANDLE_ARRAY { ptr = rtvHandle.ptr } };
        IntPtr setRTVPtr = Marshal.ReadIntPtr(vTableList, 46 * IntPtr.Size);
        var setRTV = Marshal.GetDelegateForFunctionPointer<OMSetRenderTargetsDelegate>(setRTVPtr);
        setRTV(commandList, 1, rtvHandles, false, IntPtr.Zero);

        IntPtr clearRTVPtr = Marshal.ReadIntPtr(vTableList, 48 * IntPtr.Size);
        var clearRTV = Marshal.GetDelegateForFunctionPointer<ClearRenderTargetViewDelegate>(clearRTVPtr);
        clearRTV(commandList, rtvHandle, new float[] { 0, 0, 0, 1 }, 0, IntPtr.Zero);

        IntPtr setTopoPtr = Marshal.ReadIntPtr(vTableList, 20 * IntPtr.Size);
        var setTopo = Marshal.GetDelegateForFunctionPointer<IASetPrimitiveTopologyDelegate>(setTopoPtr);
        setTopo(commandList, D3D_PRIMITIVE_TOPOLOGY.D3D_PRIMITIVE_TOPOLOGY_TRIANGLELIST);

        IntPtr setVBPtr = Marshal.ReadIntPtr(vTableList, 44 * IntPtr.Size);
        var setVB = Marshal.GetDelegateForFunctionPointer<IASetVertexBuffersDelegate>(setVBPtr);
        setVB(commandList, 0, 1, new[] { vertexBufferView });

        IntPtr drawPtr = Marshal.ReadIntPtr(vTableList, 12 * IntPtr.Size);
        var draw = Marshal.GetDelegateForFunctionPointer<DrawInstancedDelegate>(drawPtr);
        draw(commandList, 6, 1, 0, 0);

        barrier = GetTransitionBarrier(renderTargets[frameIndex], D3D12_RESOURCE_STATES.D3D12_RESOURCE_STATE_RENDER_TARGET, D3D12_RESOURCE_STATES.D3D12_RESOURCE_STATE_PRESENT);
        resBarrier(commandList, 1, new D3D12_RESOURCE_BARRIER[] { barrier });

        IntPtr closePtr = Marshal.ReadIntPtr(vTableList, 9 * IntPtr.Size);
        var close = Marshal.GetDelegateForFunctionPointer<CloseDelegate>(closePtr);
        close(commandList);
    }

    private void WaitForPreviousFrame()
    {
        IntPtr vTableQ = Marshal.ReadIntPtr(commandQueue);
        IntPtr signalPtr = Marshal.ReadIntPtr(vTableQ, 14 * IntPtr.Size);
        var signal = Marshal.GetDelegateForFunctionPointer<SignalDelegate>(signalPtr);
        signal(commandQueue, fence, fenceValue);

        IntPtr vTableFence = Marshal.ReadIntPtr(fence);
        IntPtr getCompletedPtr = Marshal.ReadIntPtr(vTableFence, 8 * IntPtr.Size);
        var getCompleted = Marshal.GetDelegateForFunctionPointer<GetCompletedValueDelegate>(getCompletedPtr);
        
        if (getCompleted(fence) < fenceValue)
        {
            IntPtr setEventPtr = Marshal.ReadIntPtr(vTableFence, 9 * IntPtr.Size);
            var setEvent = Marshal.GetDelegateForFunctionPointer<SetEventOnCompletionDelegate>(setEventPtr);
            setEvent(fence, fenceValue, fenceEvent);
            WaitForSingleObject(fenceEvent, INFINITE);
        }
        fenceValue++;
        frameIndex = (int)GetCurrentBackBufferIndex(swapChain);
    }

    public void Render()
    {
        ConstantBufferData cbData = new ConstantBufferData
        {
            iTime = (float)stopwatch.Elapsed.TotalSeconds,
            iResolutionX = WIDTH,
            iResolutionY = HEIGHT,
            padding = 0
        };
        Marshal.StructureToPtr(cbData, constantBufferDataBegin, false);

        PopulateCommandList();
        
        IntPtr[] lists = { commandList };
        IntPtr vTableQ = Marshal.ReadIntPtr(commandQueue);
        IntPtr execPtr = Marshal.ReadIntPtr(vTableQ, 10 * IntPtr.Size);
        var exec = Marshal.GetDelegateForFunctionPointer<ExecuteCommandListsDelegate>(execPtr);
        exec(commandQueue, 1, lists);

        IntPtr vTableSwap = Marshal.ReadIntPtr(swapChain);
        IntPtr presentPtr = Marshal.ReadIntPtr(vTableSwap, 8 * IntPtr.Size);
        var present = Marshal.GetDelegateForFunctionPointer<PresentDelegate>(presentPtr);
        present(swapChain, 1, 0);

        WaitForPreviousFrame();
    }

    public void Cleanup()
    {
        WaitForPreviousFrame();
        CloseHandle(fenceEvent);
        if(fence != IntPtr.Zero) Marshal.Release(fence);
        if(constantBuffer != IntPtr.Zero) Marshal.Release(constantBuffer);
        if(vertexBuffer != IntPtr.Zero) Marshal.Release(vertexBuffer);
        if(pipelineState != IntPtr.Zero) Marshal.Release(pipelineState);
        if(rootSignature != IntPtr.Zero) Marshal.Release(rootSignature);
        if(commandList != IntPtr.Zero) Marshal.Release(commandList);
        if(commandAllocator != IntPtr.Zero) Marshal.Release(commandAllocator);
        if(cbvHeap != IntPtr.Zero) Marshal.Release(cbvHeap);
        if(rtvHeap != IntPtr.Zero) Marshal.Release(rtvHeap);
        foreach(var rt in renderTargets) { if(rt != IntPtr.Zero) Marshal.Release(rt); }
        if(swapChain != IntPtr.Zero) Marshal.Release(swapChain);
        if(commandQueue != IntPtr.Zero) Marshal.Release(commandQueue);
        if(device != IntPtr.Zero) Marshal.Release(device);
    }

    public void Initialize(IntPtr hwnd)
    {
        // Debug Layer
        IntPtr debugInterface;
        Guid debugGuid = IID_ID3D12Debug;
        if (D3D12GetDebugInterface(ref debugGuid, out debugInterface) >= 0)
        {
             ID3D12Debug debug = Marshal.GetObjectForIUnknown(debugInterface) as ID3D12Debug;
             debug.EnableDebugLayer();
             Marshal.ReleaseComObject(debug);
        }

        IntPtr factory;
        Guid factoryGuid = IID_IDXGIFactory4;
        CreateDXGIFactory2(0, ref factoryGuid, out factory);

        Guid deviceGuid = IID_ID3D12Device;
        D3D12CreateDevice(IntPtr.Zero, D3D_FEATURE_LEVEL_11_0, ref deviceGuid, out device);

        D3D12_COMMAND_QUEUE_DESC queueDesc = new D3D12_COMMAND_QUEUE_DESC { Type = D3D12_COMMAND_LIST_TYPE.D3D12_COMMAND_LIST_TYPE_DIRECT };
        IntPtr vTable = Marshal.ReadIntPtr(device);
        IntPtr createQPtr = Marshal.ReadIntPtr(vTable, 8 * IntPtr.Size);
        var createQ = Marshal.GetDelegateForFunctionPointer<CreateCommandQueueDelegate>(createQPtr);
        Guid qGuid = IID_ID3D12CommandQueue;
        createQ(device, ref queueDesc, ref qGuid, out commandQueue);

        swapChainDesc1 = new DXGI_SWAP_CHAIN_DESC1
        {
            Width = WIDTH, Height = HEIGHT, Format = DXGI_FORMAT_R8G8B8A8_UNORM,
            SampleDesc = new DXGI_SAMPLE_DESC { Count = 1 },
            BufferUsage = DXGI_USAGE_RENDER_TARGET_OUTPUT, BufferCount = FrameCount,
            SwapEffect = DXGI_SWAP_EFFECT_FLIP_DISCARD,
            Flags = DXGI_SWAP_CHAIN_FLAG_ALLOW_MODE_SWITCH | DXGI_SWAP_CHAIN_FLAG_FRAME_LATENCY_WAITABLE_OBJECT
        };

        IntPtr vTableFactory = Marshal.ReadIntPtr(factory);
        IntPtr createSwapPtr = Marshal.ReadIntPtr(vTableFactory, 15 * IntPtr.Size);
        var createSwap = Marshal.GetDelegateForFunctionPointer<CreateSwapChainForHwndDelegate>(createSwapPtr);
        createSwap(factory, commandQueue, hwnd, ref swapChainDesc1, IntPtr.Zero, IntPtr.Zero, out swapChain);
        
        // Upgrade to SwapChain3
        IntPtr swapChain1 = swapChain;
        Guid swapChain3Guid = IID_IDXGISwapChain3;
        Marshal.QueryInterface(swapChain1, ref swapChain3Guid, out swapChain);
        Marshal.Release(swapChain1);
        frameIndex = (int)GetCurrentBackBufferIndex(swapChain);

        // Heaps
        D3D12_DESCRIPTOR_HEAP_DESC rtvDesc = new D3D12_DESCRIPTOR_HEAP_DESC { Type = D3D12_DESCRIPTOR_HEAP_TYPE.D3D12_DESCRIPTOR_HEAP_TYPE_RTV, NumDescriptors = FrameCount };
        Guid heapGuid = IID_ID3D12DescriptorHeap;
        IntPtr createHeapPtr = Marshal.ReadIntPtr(vTable, 14 * IntPtr.Size);
        var createHeap = Marshal.GetDelegateForFunctionPointer<CreateDescriptorHeapDelegate>(createHeapPtr);
        createHeap(device, ref rtvDesc, ref heapGuid, out rtvHeap);

        IntPtr getIncPtr = Marshal.ReadIntPtr(vTable, 15 * IntPtr.Size);
        var getInc = Marshal.GetDelegateForFunctionPointer<GetDescriptorHandleIncrementSizeDelegate>(getIncPtr);
        rtvDescriptorSize = getInc(device, D3D12_DESCRIPTOR_HEAP_TYPE.D3D12_DESCRIPTOR_HEAP_TYPE_RTV);

        D3D12_DESCRIPTOR_HEAP_DESC cbvDesc = new D3D12_DESCRIPTOR_HEAP_DESC 
        { 
            Type = D3D12_DESCRIPTOR_HEAP_TYPE.D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV, 
            NumDescriptors = 1, 
            Flags = D3D12_DESCRIPTOR_HEAP_FLAGS.D3D12_DESCRIPTOR_HEAP_FLAG_SHADER_VISIBLE 
        };
        createHeap(device, ref cbvDesc, ref heapGuid, out cbvHeap);
        cbvDescriptorSize = getInc(device, D3D12_DESCRIPTOR_HEAP_TYPE.D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV);

        // RTVs
        D3D12_CPU_DESCRIPTOR_HANDLE rtvHandle = new D3D12_CPU_DESCRIPTOR_HANDLE { ptr = GetCPUDescriptorHandleForHeapStart(rtvHeap) };
        IntPtr vTableSwap = Marshal.ReadIntPtr(swapChain);
        IntPtr getBufPtr = Marshal.ReadIntPtr(vTableSwap, 9 * IntPtr.Size);
        var getBuf = Marshal.GetDelegateForFunctionPointer<GetBufferDelegate>(getBufPtr);
        IntPtr createRTVPtr = Marshal.ReadIntPtr(vTable, 20 * IntPtr.Size);
        var createRTV = Marshal.GetDelegateForFunctionPointer<CreateRenderTargetViewDelegate>(createRTVPtr);
        Guid resGuid = IID_ID3D12Resource;

        for (int i = 0; i < FrameCount; i++)
        {
            getBuf(swapChain, (uint)i, ref resGuid, out renderTargets[i]);
            createRTV(device, renderTargets[i], IntPtr.Zero, rtvHandle);
            rtvHandle.ptr += (int)rtvDescriptorSize;
        }

        IntPtr createAllocPtr = Marshal.ReadIntPtr(vTable, 9 * IntPtr.Size);
        var createAlloc = Marshal.GetDelegateForFunctionPointer<CreateCommandAllocatorDelegate>(createAllocPtr);
        Guid allocGuid = IID_ID3D12CommandAllocator;
        createAlloc(device, D3D12_COMMAND_LIST_TYPE.D3D12_COMMAND_LIST_TYPE_DIRECT, ref allocGuid, out commandAllocator);

        Marshal.Release(factory);
    }

    static WndProcDelegate wndProcDelegate;

    public static void Main()
    {
        Console.WriteLine("DX12 Raymarching (PowerShell)");
        var app = new Hello();
        string CLASS_NAME = "PS_DX12_Raymarching";
        IntPtr hInstance = Marshal.GetHINSTANCE(typeof(Hello).Module);
        wndProcDelegate = new WndProcDelegate(WndProc);

        WNDCLASSEX wc = new WNDCLASSEX
        {
            cbSize = (uint)Marshal.SizeOf(typeof(WNDCLASSEX)),
            style = CS_OWNDC,
            lpfnWndProc = wndProcDelegate,
            hInstance = hInstance,
            hCursor = LoadCursor(IntPtr.Zero, IDC_ARROW),
            lpszClassName = CLASS_NAME
        };
        RegisterClassEx(ref wc);

        IntPtr hwnd = CreateWindowEx(0, CLASS_NAME, "Raymarching DirectX12", WS_OVERLAPPEDWINDOW | WS_VISIBLE, 100, 100, WIDTH, HEIGHT, IntPtr.Zero, IntPtr.Zero, hInstance, IntPtr.Zero);

        try
        {
            app.Initialize(hwnd);
            app.LoadAssets();
            ShowWindow(hwnd, 1);

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
        }
        finally
        {
            app.Cleanup();
        }
    }

    static IntPtr WndProc(IntPtr hWnd, uint uMsg, IntPtr wParam, IntPtr lParam)
    {
        if (uMsg == WM_DESTROY) PostQuitMessage(0);
        return DefWindowProc(hWnd, uMsg, wParam, lParam);
    }
}
"@

Add-Type -Language CSharp -TypeDefinition $source -ReferencedAssemblies ("System.Drawing", "System.Windows.Forms")
[Hello]::Main()
