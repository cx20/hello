<?php
declare(strict_types=1);

echo "[PHPD3D12] Compute Harmonograph start\n";

// Window styles
const WS_OVERLAPPED       = 0x00000000;
const WS_CAPTION          = 0x00C00000;
const WS_SYSMENU          = 0x00080000;
const WS_THICKFRAME       = 0x00040000;
const WS_MINIMIZEBOX      = 0x00020000;
const WS_MAXIMIZEBOX      = 0x00010000;
const WS_OVERLAPPEDWINDOW = WS_OVERLAPPED | WS_CAPTION | WS_SYSMENU | WS_THICKFRAME | WS_MINIMIZEBOX | WS_MAXIMIZEBOX;

const CS_HREDRAW          = 0x0002;
const CS_VREDRAW          = 0x0001;
const CW_USEDEFAULT       = 0x80000000;
const SW_SHOWDEFAULT      = 10;

const WM_QUIT             = 0x0012;
const PM_REMOVE           = 0x0001;

const IDI_APPLICATION     = 32512;
const IDC_ARROW           = 32512;

// DXGI / D3D12 constants
const DXGI_FORMAT_UNKNOWN            = 0;
const DXGI_FORMAT_R8G8B8A8_UNORM     = 28;

const DXGI_USAGE_RENDER_TARGET_OUTPUT = 0x00000020;
const DXGI_SWAP_EFFECT_FLIP_DISCARD = 4;
const DXGI_SCALING_STRETCH = 1;

const D3D_FEATURE_LEVEL_12_0 = 0xC000;

const D3D12_COMMAND_LIST_TYPE_DIRECT = 0;
const D3D12_COMMAND_QUEUE_FLAG_NONE  = 0;
const D3D12_FENCE_FLAG_NONE          = 0;

const D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV = 0;
const D3D12_DESCRIPTOR_HEAP_TYPE_RTV = 2;
const D3D12_DESCRIPTOR_HEAP_FLAG_NONE = 0;
const D3D12_DESCRIPTOR_HEAP_FLAG_SHADER_VISIBLE = 1;

const D3D12_RESOURCE_STATE_COMMON              = 0;
const D3D12_RESOURCE_STATE_PRESENT             = 0;
const D3D12_RESOURCE_STATE_RENDER_TARGET       = 4;
const D3D12_RESOURCE_STATE_UNORDERED_ACCESS    = 0x8;
const D3D12_RESOURCE_STATE_NON_PIXEL_SHADER_RESOURCE = 0x40;
const D3D12_RESOURCE_STATE_GENERIC_READ        = 0x1;

const D3D12_HEAP_TYPE_DEFAULT = 1;
const D3D12_HEAP_TYPE_UPLOAD  = 2;

const D3D12_RESOURCE_DIMENSION_BUFFER = 1;
const D3D12_TEXTURE_LAYOUT_ROW_MAJOR  = 1;
const D3D12_RESOURCE_FLAG_NONE = 0;
const D3D12_RESOURCE_FLAG_ALLOW_UNORDERED_ACCESS = 0x4;

const D3D12_ROOT_SIGNATURE_FLAG_NONE = 0;
const D3D12_ROOT_SIGNATURE_VERSION_1 = 1;

const D3D12_ROOT_PARAMETER_TYPE_DESCRIPTOR_TABLE = 0;

const D3D12_DESCRIPTOR_RANGE_TYPE_SRV = 0;
const D3D12_DESCRIPTOR_RANGE_TYPE_UAV = 1;
const D3D12_DESCRIPTOR_RANGE_TYPE_CBV = 2;

const D3D12_SHADER_VISIBILITY_ALL    = 0;
const D3D12_SHADER_VISIBILITY_VERTEX = 1;

const D3D12_PRIMITIVE_TOPOLOGY_TYPE_LINE = 2;
const D3D_PRIMITIVE_TOPOLOGY_LINESTRIP   = 3;

const D3D12_FILL_MODE_SOLID = 3;
const D3D12_CULL_MODE_NONE  = 1;

const D3D12_BLEND_ONE  = 2;
const D3D12_BLEND_ZERO = 1;
const D3D12_BLEND_OP_ADD = 1;
const D3D12_LOGIC_OP_NOOP = 5;
const D3D12_COLOR_WRITE_ENABLE_ALL = 15;

const D3D12_DEPTH_WRITE_MASK_ALL = 1;
const D3D12_COMPARISON_FUNC_LESS = 2;

const D3D12_RESOURCE_BARRIER_TYPE_TRANSITION  = 0;
const D3D12_RESOURCE_BARRIER_FLAG_NONE        = 0;
const D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES = 0xFFFFFFFF;

const D3DCOMPILE_ENABLE_STRICTNESS = 0x00000800;

const D3D12_SRV_DIMENSION_BUFFER = 1;
const D3D12_UAV_DIMENSION_BUFFER = 1;
const D3D12_DEFAULT_SHADER_4_COMPONENT_MAPPING = 5768;

const FRAME_COUNT   = 2;
const VERTEX_COUNT  = 100000;
const WIN_WIDTH     = 800;
const WIN_HEIGHT    = 600;

// COM vtable indices
const VTBL_RELEASE = 2;

// IDXGIFactory2
const VTBL_FACTORY_CREATE_SWAPCHAIN_FOR_HWND = 15;

// IDXGISwapChain / IDXGISwapChain3
const VTBL_SWAP_PRESENT = 8;
const VTBL_SWAP_GETBUFFER = 9;
const VTBL_SWAP_GET_CURRENT_BACKBUFFER_INDEX = 36;

// IUnknown
const VTBL_QUERY_INTERFACE = 0;

// ID3D12Device
const VTBL_DEVICE_CREATE_COMMAND_QUEUE = 8;
const VTBL_DEVICE_CREATE_COMMAND_ALLOCATOR = 9;
const VTBL_DEVICE_CREATE_GRAPHICS_PSO = 10;
const VTBL_DEVICE_CREATE_COMPUTE_PSO = 11;
const VTBL_DEVICE_CREATE_COMMAND_LIST = 12;
const VTBL_DEVICE_CREATE_DESCRIPTOR_HEAP = 14;
const VTBL_DEVICE_GET_DESCRIPTOR_HANDLE_INC_SIZE = 15;
const VTBL_DEVICE_CREATE_ROOT_SIGNATURE = 16;
const VTBL_DEVICE_CREATE_CBV = 17;
const VTBL_DEVICE_CREATE_SRV = 18;
const VTBL_DEVICE_CREATE_UAV = 19;
const VTBL_DEVICE_CREATE_RTV = 20;
const VTBL_DEVICE_CREATE_COMMITTED_RESOURCE = 27;
const VTBL_DEVICE_CREATE_FENCE = 36;

// ID3D12DescriptorHeap
const VTBL_DESCRIPTOR_HEAP_GET_CPU_HANDLE = 9;
const VTBL_DESCRIPTOR_HEAP_GET_GPU_HANDLE = 10;

// ID3D12CommandAllocator
const VTBL_COMMAND_ALLOCATOR_RESET = 8;

// ID3D12GraphicsCommandList
const VTBL_COMMAND_LIST_CLOSE = 9;
const VTBL_COMMAND_LIST_RESET = 10;
const VTBL_COMMAND_LIST_DRAW_INSTANCED = 12;
const VTBL_COMMAND_LIST_DISPATCH = 14;
const VTBL_COMMAND_LIST_IA_SET_PRIMITIVE_TOPOLOGY = 20;
const VTBL_COMMAND_LIST_RS_SET_VIEWPORTS = 21;
const VTBL_COMMAND_LIST_RS_SET_SCISSOR_RECTS = 22;
const VTBL_COMMAND_LIST_RESOURCE_BARRIER = 26;
const VTBL_COMMAND_LIST_SET_DESCRIPTOR_HEAPS = 28;
const VTBL_COMMAND_LIST_SET_COMPUTE_ROOT_SIGNATURE = 29;
const VTBL_COMMAND_LIST_SET_ROOT_SIGNATURE = 30;
const VTBL_COMMAND_LIST_SET_COMPUTE_ROOT_DESCRIPTOR_TABLE = 31;
const VTBL_COMMAND_LIST_SET_GRAPHICS_ROOT_DESCRIPTOR_TABLE = 32;
const VTBL_COMMAND_LIST_OM_SET_RENDER_TARGETS = 46;
const VTBL_COMMAND_LIST_CLEAR_RTV = 48;

// ID3D12CommandQueue
const VTBL_COMMAND_QUEUE_EXECUTE_LISTS = 10;
const VTBL_COMMAND_QUEUE_SIGNAL = 14;

// ID3D12Fence
const VTBL_FENCE_GET_COMPLETED = 8;
const VTBL_FENCE_SET_EVENT = 9;

// ID3D12Resource
const VTBL_RESOURCE_MAP = 8;
const VTBL_RESOURCE_GET_GPU_VA = 11;

// ID3DBlob
const VTBL_BLOB_GET_PTR = 3;
const VTBL_BLOB_GET_SIZE = 4;

function wstr(string $s): FFI\CData
{
    $bytes = iconv('UTF-8', 'UTF-16LE', $s) . "\x00\x00";
    $len16 = intdiv(strlen($bytes), 2);
    $buf = FFI::new("uint16_t[$len16]", false);
    FFI::memcpy($buf, $bytes, strlen($bytes));
    return $buf;
}

function astr(string $s): FFI\CData
{
    $len = strlen($s) + 1;
    $buf = FFI::new("char[$len]", false);
    for ($i = 0; $i < strlen($s); $i++) {
        $buf[$i] = $s[$i];
    }
    $buf[strlen($s)] = "\0";
    return $buf;
}

// kernel32.dll
$kernel32 = FFI::cdef('
    typedef void* HANDLE;
    typedef HANDLE HINSTANCE;
    typedef HANDLE HMODULE;
    typedef const uint16_t* LPCWSTR;
    typedef const char* LPCSTR;
    typedef void* FARPROC;

    HINSTANCE GetModuleHandleW(LPCWSTR lpModuleName);
    HMODULE LoadLibraryW(LPCWSTR lpLibFileName);
    FARPROC GetProcAddress(HMODULE hModule, LPCSTR lpProcName);
    unsigned long GetLastError(void);
    void Sleep(unsigned long dwMilliseconds);
    int FreeLibrary(HMODULE hLibModule);

    HANDLE CreateEventW(void* lpEventAttributes, int bManualReset, int bInitialState, LPCWSTR lpName);
    unsigned long WaitForSingleObject(HANDLE hHandle, unsigned long dwMilliseconds);
    int CloseHandle(HANDLE hObject);
', 'kernel32.dll');

// user32.dll
$user32 = FFI::cdef('
    typedef void* HANDLE;
    typedef HANDLE HWND;
    typedef HANDLE HDC;
    typedef HANDLE HINSTANCE;
    typedef HANDLE HICON;
    typedef HANDLE HCURSOR;
    typedef HANDLE HBRUSH;
    typedef HANDLE HMENU;
    typedef void*  WNDPROC;

    typedef const uint16_t* LPCWSTR;

    typedef unsigned int   UINT;
    typedef unsigned long  DWORD;
    typedef long           LONG;
    typedef unsigned long long WPARAM;
    typedef long long      LPARAM;
    typedef long long      LRESULT;
    typedef int            BOOL;
    typedef uint16_t       ATOM;

    typedef struct tagPOINT { LONG x; LONG y; } POINT;

    typedef struct tagRECT {
        LONG left;
        LONG top;
        LONG right;
        LONG bottom;
    } RECT;

    typedef struct tagMSG {
        HWND   hwnd;
        UINT   message;
        WPARAM wParam;
        LPARAM lParam;
        DWORD  time;
        POINT  pt;
        DWORD  lPrivate;
    } MSG;

    typedef struct tagWNDCLASSEXW {
        UINT      cbSize;
        UINT      style;
        WNDPROC   lpfnWndProc;
        int       cbClsExtra;
        int       cbWndExtra;
        HINSTANCE hInstance;
        HICON     hIcon;
        HCURSOR   hCursor;
        HBRUSH    hbrBackground;
        LPCWSTR   lpszMenuName;
        LPCWSTR   lpszClassName;
        HICON     hIconSm;
    } WNDCLASSEXW;

    ATOM RegisterClassExW(const WNDCLASSEXW *lpwcx);

    HWND CreateWindowExW(
        DWORD     dwExStyle,
        LPCWSTR   lpClassName,
        LPCWSTR   lpWindowName,
        DWORD     dwStyle,
        int       X,
        int       Y,
        int       nWidth,
        int       nHeight,
        HWND      hWndParent,
        HMENU     hMenu,
        HINSTANCE hInstance,
        void*     lpParam
    );

    BOOL ShowWindow(HWND hWnd, int nCmdShow);
    BOOL UpdateWindow(HWND hWnd);
    BOOL IsWindow(HWND hWnd);

    BOOL PeekMessageW(MSG *lpMsg, HWND hWnd, UINT wMsgFilterMin, UINT wMsgFilterMax, UINT wRemoveMsg);
    BOOL TranslateMessage(const MSG *lpMsg);
    LRESULT DispatchMessageW(const MSG *lpMsg);

    HICON LoadIconW(HINSTANCE hInstance, LPCWSTR lpIconName);
    HCURSOR LoadCursorW(HINSTANCE hInstance, LPCWSTR lpCursorName);

    BOOL GetClientRect(HWND hWnd, RECT* lpRect);
', 'user32.dll');

// D3D12 types
$sizeType = PHP_INT_SIZE === 8 ? 'unsigned long long' : 'unsigned long';
$d3d12Cdef = <<<CDEF
    typedef long HRESULT;
    typedef {$sizeType} SIZE_T;
    typedef {$sizeType} UINTPTR;
    typedef unsigned char BYTE;
    typedef unsigned short WORD;
    typedef unsigned int UINT;
    typedef unsigned long DWORD;
    typedef unsigned long long UINT64;
    typedef int BOOL;
    typedef void* HWND;

    typedef struct _GUID {
        uint32_t Data1;
        uint16_t Data2;
        uint16_t Data3;
        uint8_t  Data4[8];
    } GUID;

    typedef struct DXGI_SAMPLE_DESC {
        UINT Count;
        UINT Quality;
    } DXGI_SAMPLE_DESC;

    typedef struct DXGI_SWAP_CHAIN_DESC1 {
        UINT Width;
        UINT Height;
        UINT Format;
        BOOL Stereo;
        DXGI_SAMPLE_DESC SampleDesc;
        UINT BufferUsage;
        UINT BufferCount;
        UINT Scaling;
        UINT SwapEffect;
        UINT AlphaMode;
        UINT Flags;
    } DXGI_SWAP_CHAIN_DESC1;

    typedef struct D3D12_COMMAND_QUEUE_DESC {
        UINT Type;
        int Priority;
        UINT Flags;
        UINT NodeMask;
    } D3D12_COMMAND_QUEUE_DESC;

    typedef struct D3D12_DESCRIPTOR_HEAP_DESC {
        UINT Type;
        UINT NumDescriptors;
        UINT Flags;
        UINT NodeMask;
    } D3D12_DESCRIPTOR_HEAP_DESC;

    typedef struct D3D12_CPU_DESCRIPTOR_HANDLE {
        UINTPTR ptr;
    } D3D12_CPU_DESCRIPTOR_HANDLE;

    typedef struct D3D12_GPU_DESCRIPTOR_HANDLE {
        UINT64 ptr;
    } D3D12_GPU_DESCRIPTOR_HANDLE;

    typedef struct D3D12_HEAP_PROPERTIES {
        UINT Type;
        UINT CPUPageProperty;
        UINT MemoryPoolPreference;
        UINT CreationNodeMask;
        UINT VisibleNodeMask;
    } D3D12_HEAP_PROPERTIES;

    typedef struct D3D12_RESOURCE_DESC {
        UINT Dimension;
        UINT64 Alignment;
        UINT64 Width;
        UINT Height;
        WORD DepthOrArraySize;
        WORD MipLevels;
        UINT Format;
        DXGI_SAMPLE_DESC SampleDesc;
        UINT Layout;
        UINT Flags;
    } D3D12_RESOURCE_DESC;

    typedef struct D3D12_RANGE {
        SIZE_T Begin;
        SIZE_T End;
    } D3D12_RANGE;

    typedef struct D3D12_VIEWPORT {
        float TopLeftX;
        float TopLeftY;
        float Width;
        float Height;
        float MinDepth;
        float MaxDepth;
    } D3D12_VIEWPORT;

    typedef struct D3D12_RECT {
        long left;
        long top;
        long right;
        long bottom;
    } D3D12_RECT;

    typedef struct D3D12_RESOURCE_TRANSITION_BARRIER {
        void* pResource;
        UINT Subresource;
        UINT StateBefore;
        UINT StateAfter;
    } D3D12_RESOURCE_TRANSITION_BARRIER;

    typedef union D3D12_RESOURCE_BARRIER_UNION {
        D3D12_RESOURCE_TRANSITION_BARRIER Transition;
        BYTE _padding[24];
    } D3D12_RESOURCE_BARRIER_UNION;

    typedef struct D3D12_RESOURCE_BARRIER {
        UINT Type;
        UINT Flags;
        D3D12_RESOURCE_BARRIER_UNION u;
    } D3D12_RESOURCE_BARRIER;

    /* Root Signature structures */
    typedef struct D3D12_DESCRIPTOR_RANGE {
        UINT RangeType;
        UINT NumDescriptors;
        UINT BaseShaderRegister;
        UINT RegisterSpace;
        UINT OffsetInDescriptorsFromTableStart;
    } D3D12_DESCRIPTOR_RANGE;

    typedef struct D3D12_ROOT_DESCRIPTOR_TABLE {
        UINT NumDescriptorRanges;
        void* pDescriptorRanges;
    } D3D12_ROOT_DESCRIPTOR_TABLE;

    typedef union D3D12_ROOT_PARAMETER_UNION {
        D3D12_ROOT_DESCRIPTOR_TABLE DescriptorTable;
        BYTE _pad[16];
    } D3D12_ROOT_PARAMETER_UNION;

    typedef struct D3D12_ROOT_PARAMETER {
        UINT ParameterType;
        D3D12_ROOT_PARAMETER_UNION u;
        UINT ShaderVisibility;
    } D3D12_ROOT_PARAMETER;

    typedef struct D3D12_ROOT_SIGNATURE_DESC {
        UINT NumParameters;
        void* pParameters;
        UINT NumStaticSamplers;
        void* pStaticSamplers;
        UINT Flags;
    } D3D12_ROOT_SIGNATURE_DESC;

    typedef struct D3D12_SHADER_BYTECODE {
        void* pShaderBytecode;
        SIZE_T BytecodeLength;
    } D3D12_SHADER_BYTECODE;

    typedef struct D3D12_RASTERIZER_DESC {
        UINT FillMode;
        UINT CullMode;
        BOOL FrontCounterClockwise;
        int DepthBias;
        float DepthBiasClamp;
        float SlopeScaledDepthBias;
        BOOL DepthClipEnable;
        BOOL MultisampleEnable;
        BOOL AntialiasedLineEnable;
        UINT ForcedSampleCount;
        UINT ConservativeRaster;
    } D3D12_RASTERIZER_DESC;

    typedef struct D3D12_RENDER_TARGET_BLEND_DESC {
        BOOL BlendEnable;
        BOOL LogicOpEnable;
        UINT SrcBlend;
        UINT DestBlend;
        UINT BlendOp;
        UINT SrcBlendAlpha;
        UINT DestBlendAlpha;
        UINT BlendOpAlpha;
        UINT LogicOp;
        BYTE RenderTargetWriteMask;
    } D3D12_RENDER_TARGET_BLEND_DESC;

    typedef struct D3D12_BLEND_DESC {
        BOOL AlphaToCoverageEnable;
        BOOL IndependentBlendEnable;
        D3D12_RENDER_TARGET_BLEND_DESC RenderTarget[8];
    } D3D12_BLEND_DESC;

    typedef struct D3D12_DEPTH_STENCILOP_DESC {
        UINT StencilFailOp;
        UINT StencilDepthFailOp;
        UINT StencilPassOp;
        UINT StencilFunc;
    } D3D12_DEPTH_STENCILOP_DESC;

    typedef struct D3D12_DEPTH_STENCIL_DESC {
        BOOL DepthEnable;
        UINT DepthWriteMask;
        UINT DepthFunc;
        BOOL StencilEnable;
        BYTE StencilReadMask;
        BYTE StencilWriteMask;
        D3D12_DEPTH_STENCILOP_DESC FrontFace;
        D3D12_DEPTH_STENCILOP_DESC BackFace;
    } D3D12_DEPTH_STENCIL_DESC;

    typedef struct D3D12_CACHED_PIPELINE_STATE {
        void* pCachedBlob;
        SIZE_T CachedBlobSizeInBytes;
    } D3D12_CACHED_PIPELINE_STATE;

    typedef struct D3D12_STREAM_OUTPUT_DESC {
        void* pSODeclaration;
        UINT NumEntries;
        void* pBufferStrides;
        UINT NumStrides;
        UINT RasterizedStream;
    } D3D12_STREAM_OUTPUT_DESC;

    typedef struct D3D12_INPUT_LAYOUT_DESC {
        void* pInputElementDescs;
        UINT NumElements;
    } D3D12_INPUT_LAYOUT_DESC;

    typedef struct D3D12_GRAPHICS_PIPELINE_STATE_DESC {
        void* pRootSignature;
        D3D12_SHADER_BYTECODE VS;
        D3D12_SHADER_BYTECODE PS;
        D3D12_SHADER_BYTECODE DS;
        D3D12_SHADER_BYTECODE HS;
        D3D12_SHADER_BYTECODE GS;
        D3D12_STREAM_OUTPUT_DESC StreamOutput;
        D3D12_BLEND_DESC BlendState;
        UINT SampleMask;
        D3D12_RASTERIZER_DESC RasterizerState;
        D3D12_DEPTH_STENCIL_DESC DepthStencilState;
        D3D12_INPUT_LAYOUT_DESC InputLayout;
        UINT IBStripCutValue;
        UINT PrimitiveTopologyType;
        UINT NumRenderTargets;
        UINT RTVFormats[8];
        UINT DSVFormat;
        DXGI_SAMPLE_DESC SampleDesc;
        UINT NodeMask;
        D3D12_CACHED_PIPELINE_STATE CachedPSO;
        UINT Flags;
    } D3D12_GRAPHICS_PIPELINE_STATE_DESC;

    typedef struct D3D12_COMPUTE_PIPELINE_STATE_DESC {
        void* pRootSignature;
        D3D12_SHADER_BYTECODE CS;
        UINT NodeMask;
        D3D12_CACHED_PIPELINE_STATE CachedPSO;
        UINT Flags;
    } D3D12_COMPUTE_PIPELINE_STATE_DESC;

    /* UAV / SRV / CBV descriptor structures */
    typedef struct D3D12_BUFFER_UAV {
        UINT64 FirstElement;
        UINT NumElements;
        UINT StructureByteStride;
        UINT64 CounterOffsetInBytes;
        UINT Flags;
    } D3D12_BUFFER_UAV;

    typedef struct D3D12_UNORDERED_ACCESS_VIEW_DESC {
        UINT Format;
        UINT ViewDimension;
        D3D12_BUFFER_UAV Buffer;
    } D3D12_UNORDERED_ACCESS_VIEW_DESC;

    typedef struct D3D12_BUFFER_SRV {
        UINT64 FirstElement;
        UINT NumElements;
        UINT StructureByteStride;
        UINT Flags;
    } D3D12_BUFFER_SRV;

    typedef struct D3D12_SHADER_RESOURCE_VIEW_DESC {
        UINT Format;
        UINT ViewDimension;
        UINT Shader4ComponentMapping;
        D3D12_BUFFER_SRV Buffer;
    } D3D12_SHADER_RESOURCE_VIEW_DESC;

    typedef struct D3D12_CONSTANT_BUFFER_VIEW_DESC {
        UINT64 BufferLocation;
        UINT SizeInBytes;
    } D3D12_CONSTANT_BUFFER_VIEW_DESC;

    /* Harmonograph params - matches HLSL cbuffer layout */
    typedef struct HarmonographParams {
        float A1, f1, p1, d1;
        float A2, f2, p2, d2;
        float A3, f3, p3, d3;
        float A4, f4, p4, d4;
        UINT  max_num;
        float pad1, pad2, pad3;
        float resX, resY;
        float pad4, pad5;
    } HarmonographParams;

    typedef struct IUnknown {
        void** lpVtbl;
    } IUnknown;

    typedef struct ID3DBlob {
        void** lpVtbl;
    } ID3DBlob;

    /* Function typedefs */
    typedef HRESULT (__stdcall *ReleaseFunc)(void* pThis);
    typedef HRESULT (__stdcall *QueryInterfaceFunc)(void* pThis, const GUID* riid, void** ppvObject);

    typedef HRESULT (__stdcall *CreateDXGIFactory1Func)(const GUID* riid, void** ppFactory);
    typedef HRESULT (__stdcall *D3D12CreateDeviceFunc)(void* pAdapter, UINT MinimumFeatureLevel, const GUID* riid, void** ppDevice);
    typedef HRESULT (__stdcall *D3DCompileFunc)(
        const void* pSrcData, SIZE_T SrcDataSize, const char* pSourceName,
        const void* pDefines, const void* pInclude,
        const char* pEntrypoint, const char* pTarget,
        UINT Flags1, UINT Flags2, void** ppCode, void** ppErrorMsgs
    );

    typedef HRESULT (__stdcall *CreateSwapChainForHwndFunc)(
        void* pThis, void* pDevice, HWND hWnd,
        DXGI_SWAP_CHAIN_DESC1* pDesc, void* pFullscreenDesc, void* pRestrictToOutput, void** ppSwapChain
    );

    typedef HRESULT (__stdcall *GetBufferFunc)(void* pThis, UINT Buffer, const GUID* riid, void** ppSurface);
    typedef HRESULT (__stdcall *PresentFunc)(void* pThis, UINT SyncInterval, UINT Flags);
    typedef UINT (__stdcall *GetCurrentBackBufferIndexFunc)(void* pThis);

    typedef HRESULT (__stdcall *CreateCommandQueueFunc)(void* pThis, const D3D12_COMMAND_QUEUE_DESC* pDesc, const GUID* riid, void** ppCommandQueue);
    typedef HRESULT (__stdcall *CreateCommandAllocatorFunc)(void* pThis, UINT type, const GUID* riid, void** ppCommandAllocator);
    typedef HRESULT (__stdcall *CreateGraphicsPipelineStateFunc)(void* pThis, const D3D12_GRAPHICS_PIPELINE_STATE_DESC* pDesc, const GUID* riid, void** ppPipelineState);
    typedef HRESULT (__stdcall *CreateComputePipelineStateFunc)(void* pThis, const D3D12_COMPUTE_PIPELINE_STATE_DESC* pDesc, const GUID* riid, void** ppPipelineState);
    typedef HRESULT (__stdcall *CreateCommandListFunc)(void* pThis, UINT nodeMask, UINT type, void* pAllocator, void* pInitialState, const GUID* riid, void** ppCommandList);
    typedef HRESULT (__stdcall *CreateDescriptorHeapFunc)(void* pThis, const D3D12_DESCRIPTOR_HEAP_DESC* pDesc, const GUID* riid, void** ppHeap);
    typedef UINT (__stdcall *GetDescriptorHandleIncrementSizeFunc)(void* pThis, UINT type);
    typedef HRESULT (__stdcall *CreateRootSignatureFunc)(void* pThis, UINT nodeMask, const void* pBlobWithRootSignature, SIZE_T blobLengthInBytes, const GUID* riid, void** ppRootSignature);
    typedef void (__stdcall *CreateRenderTargetViewFunc)(void* pThis, void* pResource, const void* pDesc, D3D12_CPU_DESCRIPTOR_HANDLE DestDescriptor);
    typedef HRESULT (__stdcall *CreateCommittedResourceFunc)(
        void* pThis, const D3D12_HEAP_PROPERTIES* pHeapProperties, UINT HeapFlags,
        const D3D12_RESOURCE_DESC* pDesc, UINT InitialResourceState,
        const void* pOptimizedClearValue, const GUID* riidResource, void** ppvResource
    );
    typedef HRESULT (__stdcall *CreateFenceFunc)(void* pThis, UINT64 InitialValue, UINT Flags, const GUID* riid, void** ppFence);

    typedef void (__stdcall *CreateUnorderedAccessViewFunc)(void* pThis, void* pResource, void* pCounterResource, const D3D12_UNORDERED_ACCESS_VIEW_DESC* pDesc, D3D12_CPU_DESCRIPTOR_HANDLE DestDescriptor);
    typedef void (__stdcall *CreateShaderResourceViewFunc)(void* pThis, void* pResource, const D3D12_SHADER_RESOURCE_VIEW_DESC* pDesc, D3D12_CPU_DESCRIPTOR_HANDLE DestDescriptor);
    typedef void (__stdcall *CreateConstantBufferViewFunc)(void* pThis, const D3D12_CONSTANT_BUFFER_VIEW_DESC* pDesc, D3D12_CPU_DESCRIPTOR_HANDLE DestDescriptor);

    typedef void (__stdcall *GetCPUDescriptorHandleForHeapStartFunc)(void* pThis, D3D12_CPU_DESCRIPTOR_HANDLE* pRetVal);
    typedef void (__stdcall *GetGPUDescriptorHandleForHeapStartFunc)(void* pThis, D3D12_GPU_DESCRIPTOR_HANDLE* pRetVal);

    typedef HRESULT (__stdcall *ResetCommandAllocatorFunc)(void* pThis);

    typedef HRESULT (__stdcall *CommandListCloseFunc)(void* pThis);
    typedef HRESULT (__stdcall *CommandListResetFunc)(void* pThis, void* pAllocator, void* pInitialState);
    typedef void (__stdcall *SetGraphicsRootSignatureFunc)(void* pThis, void* pRootSignature);
    typedef void (__stdcall *SetComputeRootSignatureFunc)(void* pThis, void* pRootSignature);
    typedef void (__stdcall *SetDescriptorHeapsFunc)(void* pThis, UINT NumDescriptorHeaps, void** ppDescriptorHeaps);
    typedef void (__stdcall *SetComputeRootDescriptorTableFunc)(void* pThis, UINT RootParameterIndex, D3D12_GPU_DESCRIPTOR_HANDLE BaseDescriptor);
    typedef void (__stdcall *SetGraphicsRootDescriptorTableFunc)(void* pThis, UINT RootParameterIndex, D3D12_GPU_DESCRIPTOR_HANDLE BaseDescriptor);
    typedef void (__stdcall *DispatchFunc)(void* pThis, UINT ThreadGroupCountX, UINT ThreadGroupCountY, UINT ThreadGroupCountZ);
    typedef void (__stdcall *RSSetViewportsFunc)(void* pThis, UINT NumViewports, const D3D12_VIEWPORT* pViewports);
    typedef void (__stdcall *RSSetScissorRectsFunc)(void* pThis, UINT NumRects, const D3D12_RECT* pRects);
    typedef void (__stdcall *ResourceBarrierFunc)(void* pThis, UINT NumBarriers, const D3D12_RESOURCE_BARRIER* pBarriers);
    typedef void (__stdcall *OMSetRenderTargetsFunc)(void* pThis, UINT NumRenderTargetDescriptors, const D3D12_CPU_DESCRIPTOR_HANDLE* pRenderTargetDescriptors, BOOL RTsSingleHandleToDescriptorRange, const void* pDepthStencilDescriptor);
    typedef void (__stdcall *ClearRenderTargetViewFunc)(void* pThis, D3D12_CPU_DESCRIPTOR_HANDLE RenderTargetView, const float* ColorRGBA, UINT NumRects, const void* pRects);
    typedef void (__stdcall *IASetPrimitiveTopologyFunc)(void* pThis, UINT Topology);
    typedef void (__stdcall *DrawInstancedFunc)(void* pThis, UINT VertexCountPerInstance, UINT InstanceCount, UINT StartVertexLocation, UINT StartInstanceLocation);

    typedef void (__stdcall *ExecuteCommandListsFunc)(void* pThis, UINT NumCommandLists, void** ppCommandLists);
    typedef HRESULT (__stdcall *SignalFunc)(void* pThis, void* pFence, UINT64 Value);

    typedef UINT64 (__stdcall *GetCompletedValueFunc)(void* pThis);
    typedef HRESULT (__stdcall *SetEventOnCompletionFunc)(void* pThis, UINT64 Value, void* hEvent);

    typedef HRESULT (__stdcall *MapResourceFunc)(void* pThis, UINT Subresource, const D3D12_RANGE* pReadRange, void** ppData);
    typedef UINT64 (__stdcall *GetGPUVirtualAddressFunc)(void* pThis);

    typedef void* (__stdcall *GetBufferPointerFunc)(void* pThis);
    typedef SIZE_T (__stdcall *GetBufferSizeFunc)(void* pThis);

    typedef void (__stdcall *EnableDebugLayerFunc)(void* pThis);
    typedef HRESULT (__stdcall *D3D12GetDebugInterfaceFunc)(const GUID* riid, void** ppvDebug);
    typedef HRESULT (__stdcall *D3D12SerializeRootSignatureFunc)(const D3D12_ROOT_SIGNATURE_DESC* pRootSignature, UINT Version, void** ppBlob, void** ppErrorBlob);
CDEF;

$d3d12Types = FFI::cdef($d3d12Cdef);

// ============================================================
// Helper functions
// ============================================================
function guid_from_string(string $s, FFI $ffi): FFI\CData
{
    $s = trim($s, "{} ");
    $parts = explode('-', $s);
    $g = $ffi->new('GUID');
    $g->Data1 = hexdec($parts[0]);
    $g->Data2 = hexdec($parts[1]);
    $g->Data3 = hexdec($parts[2]);
    $d4 = hex2bin($parts[3] . $parts[4]);
    for ($i = 0; $i < 8; $i++) {
        $g->Data4[$i] = ord($d4[$i]);
    }
    return $g;
}

function com_release(FFI $ffi, FFI\CData $obj): void
{
    if ($obj === null || (int)FFI::cast($ffi->type('UINTPTR'), $obj)->cdata === 0) return;
    $fn = FFI::cast($ffi->type('ReleaseFunc'), $obj->lpVtbl[VTBL_RELEASE]);
    $fn($obj);
}

function blob_ptr(FFI $ffi, FFI\CData $blob): FFI\CData
{
    $fn = FFI::cast($ffi->type('GetBufferPointerFunc'), $blob->lpVtbl[VTBL_BLOB_GET_PTR]);
    return $fn($blob);
}

function blob_size(FFI $ffi, FFI\CData $blob): int
{
    $fn = FFI::cast($ffi->type('GetBufferSizeFunc'), $blob->lpVtbl[VTBL_BLOB_GET_SIZE]);
    return (int)$fn($blob);
}

function ptr_value(FFI $ffi, $ptr): int
{
    return (int)FFI::cast($ffi->type('UINTPTR'), $ptr)->cdata;
}

function out_ptr(FFI $ffi, FFI\CData $pp): ?FFI\CData
{
    $ppv = FFI::cast('void**', FFI::addr($pp));
    return $ppv[0];
}

function compile_hlsl(FFI $ffi, FFI\CData $d3dCompile, string $source, string $entry, string $target): FFI\CData
{
    $srcLen = strlen($source);
    $srcBuf = FFI::new("char[" . ($srcLen + 1) . "]", false);
    FFI::memcpy($srcBuf, $source, $srcLen);
    $srcBuf[$srcLen] = "\0";

    $code = FFI::new('void*');
    $err  = FFI::new('void*');

    $hr = $d3dCompile(
        FFI::addr($srcBuf[0]), $srcLen, 'hello.hlsl', null, null,
        $entry, $target, D3DCOMPILE_ENABLE_STRICTNESS, 0,
        FFI::addr($code), FFI::addr($err)
    );

    $ppCode = FFI::cast('void**', FFI::addr($code));
    $codeVal = $ppCode[0];

    if ($hr < 0) {
        $msg = "D3DCompile($entry) failed";
        $ppErr = FFI::cast('void**', FFI::addr($err));
        $errVal = $ppErr[0];
        if ($errVal !== null) {
            $blob = FFI::cast($ffi->type('ID3DBlob*'), $errVal);
            $ptr = blob_ptr($ffi, $blob);
            $size = blob_size($ffi, $blob);
            if ($ptr && $size > 0) {
                $msg = FFI::string($ptr, $size);
            }
            com_release($ffi, $blob);
        }
        throw new RuntimeException($msg);
    }

    if ($codeVal === null) {
        throw new RuntimeException("D3DCompile($entry) returned null code blob");
    }

    return FFI::cast($ffi->type('ID3DBlob*'), $codeVal);
}

function serialize_and_create_root_signature(
    FFI $ffi, FFI\CData $device, FFI\CData $serializeRootSig, FFI\CData $rsDesc, string $label
): FFI\CData {
    $rsBlob  = FFI::new('void*');
    $errBlob = FFI::new('void*');
    $hr = $serializeRootSig(FFI::addr($rsDesc), D3D12_ROOT_SIGNATURE_VERSION_1, FFI::addr($rsBlob), FFI::addr($errBlob));
    if ($hr < 0) {
        $msg = "D3D12SerializeRootSignature($label) failed";
        $errVal = out_ptr($ffi, $errBlob);
        if ($errVal !== null) {
            $blob = FFI::cast($ffi->type('ID3DBlob*'), $errVal);
            $ptr = blob_ptr($ffi, $blob);
            $size = blob_size($ffi, $blob);
            if ($ptr && $size > 0) $msg = FFI::string($ptr, $size);
            com_release($ffi, $blob);
        }
        throw new RuntimeException($msg);
    }
    $errVal = out_ptr($ffi, $errBlob);
    if ($errVal !== null) {
        com_release($ffi, FFI::cast($ffi->type('ID3DBlob*'), $errVal));
    }

    $rsBlobVal = out_ptr($ffi, $rsBlob);
    $rsBlobObj = FFI::cast($ffi->type('ID3DBlob*'), $rsBlobVal);
    $rsPtr  = blob_ptr($ffi, $rsBlobObj);
    $rsSize = blob_size($ffi, $rsBlobObj);

    $iidRootSig = guid_from_string('{c54a6b66-72df-4ee8-8be5-a946a1429214}', $ffi);
    $ppRootSig = FFI::new('void*');
    $createRootSig = FFI::cast($ffi->type('CreateRootSignatureFunc'), $device->lpVtbl[VTBL_DEVICE_CREATE_ROOT_SIGNATURE]);
    $hr = $createRootSig($device, 0, $rsPtr, $rsSize, FFI::addr($iidRootSig), FFI::addr($ppRootSig));
    com_release($ffi, $rsBlobObj);
    if ($hr < 0) {
        throw new RuntimeException("CreateRootSignature($label) failed (hr=0x" . dechex($hr & 0xffffffff) . ")");
    }
    echo "[PHPD3D12] $label root signature created\n";
    return FFI::cast($ffi->type('IUnknown*'), out_ptr($ffi, $ppRootSig));
}

// ============================================================
// Window setup
// ============================================================
$hInstance = $kernel32->GetModuleHandleW(null);

$user32DllName = wstr("user32.dll");
$hUser32 = $kernel32->LoadLibraryW(FFI::cast('uint16_t*', FFI::addr($user32DllName[0])));
$procName = astr("DefWindowProcW");
$defWndProcAddr = $kernel32->GetProcAddress($hUser32, FFI::cast('char*', FFI::addr($procName[0])));

$className  = wstr("PHPD3D12HarmoWindow");
$windowName = wstr("Harmonograph (PHP DirectX12 Compute)");

$hIcon   = $user32->LoadIconW(null, FFI::cast('uint16_t*', IDI_APPLICATION));
$hCursor = $user32->LoadCursorW(null, FFI::cast('uint16_t*', IDC_ARROW));

$wcex = $user32->new('WNDCLASSEXW');
$wcex->cbSize        = FFI::sizeof($wcex);
$wcex->style         = CS_HREDRAW | CS_VREDRAW;
$wcex->lpfnWndProc   = $defWndProcAddr;
$wcex->cbClsExtra    = 0;
$wcex->cbWndExtra    = 0;
$wcex->hInstance     = $hInstance;
$wcex->hIcon         = $hIcon;
$wcex->hCursor       = $hCursor;
$wcex->hbrBackground = null;
$wcex->lpszMenuName  = null;
$wcex->lpszClassName = FFI::cast('uint16_t*', FFI::addr($className[0]));
$wcex->hIconSm       = $hIcon;

$atom = $user32->RegisterClassExW(FFI::addr($wcex));
if ($atom === 0) { echo "RegisterClassExW failed\n"; exit(1); }

$hwnd = $user32->CreateWindowExW(
    0,
    FFI::cast('uint16_t*', FFI::addr($className[0])),
    FFI::cast('uint16_t*', FFI::addr($windowName[0])),
    WS_OVERLAPPEDWINDOW,
    CW_USEDEFAULT, CW_USEDEFAULT,
    WIN_WIDTH, WIN_HEIGHT,
    null, null, $hInstance, null
);
if ($hwnd === null) { echo "CreateWindowExW failed\n"; exit(1); }

echo "[PHPD3D12] window created\n";

// ============================================================
// Load DLLs
// ============================================================
$d3d12DllName = wstr('d3d12.dll');
$hD3D12 = $kernel32->LoadLibraryW(FFI::cast('uint16_t*', FFI::addr($d3d12DllName[0])));
if ($hD3D12 === null) { echo "Failed to load d3d12.dll\n"; exit(1); }

$dxgiDllName = wstr('dxgi.dll');
$hDxgi = $kernel32->LoadLibraryW(FFI::cast('uint16_t*', FFI::addr($dxgiDllName[0])));
if ($hDxgi === null) { echo "Failed to load dxgi.dll\n"; exit(1); }

$d3dcompilerName = wstr('d3dcompiler_47.dll');
$hCompiler = $kernel32->LoadLibraryW(FFI::cast('uint16_t*', FFI::addr($d3dcompilerName[0])));
if ($hCompiler === null) {
    $d3dcompilerName = wstr('d3dcompiler_43.dll');
    $hCompiler = $kernel32->LoadLibraryW(FFI::cast('uint16_t*', FFI::addr($d3dcompilerName[0])));
}
if ($hCompiler === null) { echo "Failed to load d3dcompiler\n"; exit(1); }

echo "[PHPD3D12] libraries loaded\n";

// Get function pointers
$procName = astr('CreateDXGIFactory1');
$pfnCreateFactory = $kernel32->GetProcAddress($hDxgi, FFI::cast('char*', FFI::addr($procName[0])));
$createFactory = FFI::cast($d3d12Types->type('CreateDXGIFactory1Func'), $pfnCreateFactory);

$procName = astr('D3D12CreateDevice');
$pfnCreateDevice = $kernel32->GetProcAddress($hD3D12, FFI::cast('char*', FFI::addr($procName[0])));
$createDevice = FFI::cast($d3d12Types->type('D3D12CreateDeviceFunc'), $pfnCreateDevice);

$procName = astr('D3D12SerializeRootSignature');
$pfnSerializeRS = $kernel32->GetProcAddress($hD3D12, FFI::cast('char*', FFI::addr($procName[0])));
$serializeRootSig = FFI::cast($d3d12Types->type('D3D12SerializeRootSignatureFunc'), $pfnSerializeRS);

$procName = astr('D3DCompile');
$pfnD3DCompile = $kernel32->GetProcAddress($hCompiler, FFI::cast('char*', FFI::addr($procName[0])));
$d3dCompile = FFI::cast($d3d12Types->type('D3DCompileFunc'), $pfnD3DCompile);

// ============================================================
// Create DXGI Factory & D3D12 Device
// ============================================================
$iidFactory = guid_from_string('{1bc6ea02-ef36-464f-bf0c-21ca39e5168a}', $d3d12Types);
$ppFactory = FFI::new('void*');
$hr = $createFactory(FFI::addr($iidFactory), FFI::addr($ppFactory));
if ($hr < 0) { echo "CreateDXGIFactory1 failed\n"; exit(1); }
$gFactory = FFI::cast($d3d12Types->type('IUnknown*'), out_ptr($d3d12Types, $ppFactory));
echo "[PHPD3D12] factory created\n";

$iidDevice = guid_from_string('{189819f1-1db6-4b57-be54-1821339b85f7}', $d3d12Types);
$ppDevice = FFI::new('void*');
$hr = $createDevice(null, D3D_FEATURE_LEVEL_12_0, FFI::addr($iidDevice), FFI::addr($ppDevice));
if ($hr < 0) { echo "D3D12CreateDevice failed\n"; exit(1); }
$gDevice = FFI::cast($d3d12Types->type('IUnknown*'), out_ptr($d3d12Types, $ppDevice));
echo "[PHPD3D12] device created\n";

// ============================================================
// Command Queue
// ============================================================
$cqDesc = $d3d12Types->new('D3D12_COMMAND_QUEUE_DESC');
$cqDesc->Type = D3D12_COMMAND_LIST_TYPE_DIRECT;
$cqDesc->Priority = 0;
$cqDesc->Flags = D3D12_COMMAND_QUEUE_FLAG_NONE;
$cqDesc->NodeMask = 0;

$iidQueue = guid_from_string('{0ec870a6-5d7e-4c22-8cfc-5baae07616ed}', $d3d12Types);
$ppQueue = FFI::new('void*');
$createQueue = FFI::cast($d3d12Types->type('CreateCommandQueueFunc'), $gDevice->lpVtbl[VTBL_DEVICE_CREATE_COMMAND_QUEUE]);
$hr = $createQueue($gDevice, FFI::addr($cqDesc), FFI::addr($iidQueue), FFI::addr($ppQueue));
if ($hr < 0) { echo "CreateCommandQueue failed\n"; exit(1); }
$gCommandQueue = FFI::cast($d3d12Types->type('IUnknown*'), out_ptr($d3d12Types, $ppQueue));
echo "[PHPD3D12] command queue created\n";

// ============================================================
// Swap Chain
// ============================================================
$rect = $user32->new('RECT');
$user32->GetClientRect($hwnd, FFI::addr($rect));
$width  = max(1, $rect->right - $rect->left);
$height = max(1, $rect->bottom - $rect->top);

$scDesc = $d3d12Types->new('DXGI_SWAP_CHAIN_DESC1');
$scDesc->Width = $width;
$scDesc->Height = $height;
$scDesc->Format = DXGI_FORMAT_R8G8B8A8_UNORM;
$scDesc->Stereo = 0;
$scDesc->SampleDesc->Count = 1;
$scDesc->SampleDesc->Quality = 0;
$scDesc->BufferUsage = DXGI_USAGE_RENDER_TARGET_OUTPUT;
$scDesc->BufferCount = FRAME_COUNT;
$scDesc->Scaling = DXGI_SCALING_STRETCH;
$scDesc->SwapEffect = DXGI_SWAP_EFFECT_FLIP_DISCARD;
$scDesc->AlphaMode = 0;
$scDesc->Flags = 0;

$ppSwapTemp = FFI::new('void*');
$createSwapChain = FFI::cast($d3d12Types->type('CreateSwapChainForHwndFunc'), $gFactory->lpVtbl[VTBL_FACTORY_CREATE_SWAPCHAIN_FOR_HWND]);
$hr = $createSwapChain($gFactory, $gCommandQueue, $hwnd, FFI::addr($scDesc), null, null, FFI::addr($ppSwapTemp));
if ($hr < 0) { echo "CreateSwapChainForHwnd failed\n"; exit(1); }

$swapTemp = FFI::cast($d3d12Types->type('IUnknown*'), out_ptr($d3d12Types, $ppSwapTemp));
$iidSwap3 = guid_from_string('{94d99bdb-f1f8-4ab0-b236-7da0170edab1}', $d3d12Types);
$ppSwap3 = FFI::new('void*');
$qi = FFI::cast($d3d12Types->type('QueryInterfaceFunc'), $swapTemp->lpVtbl[VTBL_QUERY_INTERFACE]);
$hr = $qi($swapTemp, FFI::addr($iidSwap3), FFI::addr($ppSwap3));
com_release($d3d12Types, $swapTemp);
if ($hr < 0) { echo "QueryInterface IDXGISwapChain3 failed\n"; exit(1); }
$gSwapChain = FFI::cast($d3d12Types->type('IUnknown*'), out_ptr($d3d12Types, $ppSwap3));

$getFrameIndex = FFI::cast($d3d12Types->type('GetCurrentBackBufferIndexFunc'), $gSwapChain->lpVtbl[VTBL_SWAP_GET_CURRENT_BACKBUFFER_INDEX]);
$gFrameIndex = $getFrameIndex($gSwapChain);
echo "[PHPD3D12] swap chain created\n";

// ============================================================
// RTV Heap
// ============================================================
$rtvHeapDesc = $d3d12Types->new('D3D12_DESCRIPTOR_HEAP_DESC');
$rtvHeapDesc->Type = D3D12_DESCRIPTOR_HEAP_TYPE_RTV;
$rtvHeapDesc->NumDescriptors = FRAME_COUNT;
$rtvHeapDesc->Flags = D3D12_DESCRIPTOR_HEAP_FLAG_NONE;
$rtvHeapDesc->NodeMask = 0;

$iidHeap = guid_from_string('{8efb471d-616c-4f49-90f7-127bb763fa51}', $d3d12Types);
$ppHeap = FFI::new('void*');
$createHeap = FFI::cast($d3d12Types->type('CreateDescriptorHeapFunc'), $gDevice->lpVtbl[VTBL_DEVICE_CREATE_DESCRIPTOR_HEAP]);
$hr = $createHeap($gDevice, FFI::addr($rtvHeapDesc), FFI::addr($iidHeap), FFI::addr($ppHeap));
if ($hr < 0) { echo "CreateDescriptorHeap(RTV) failed\n"; exit(1); }
$gRtvHeap = FFI::cast($d3d12Types->type('IUnknown*'), out_ptr($d3d12Types, $ppHeap));

$getInc = FFI::cast($d3d12Types->type('GetDescriptorHandleIncrementSizeFunc'), $gDevice->lpVtbl[VTBL_DEVICE_GET_DESCRIPTOR_HANDLE_INC_SIZE]);
$rtvDescriptorSize = $getInc($gDevice, D3D12_DESCRIPTOR_HEAP_TYPE_RTV);

$getCpuHandle = FFI::cast($d3d12Types->type('GetCPUDescriptorHandleForHeapStartFunc'), $gRtvHeap->lpVtbl[VTBL_DESCRIPTOR_HEAP_GET_CPU_HANDLE]);
$rtvHandle = $d3d12Types->new('D3D12_CPU_DESCRIPTOR_HANDLE');
$getCpuHandle($gRtvHeap, FFI::addr($rtvHandle));

// Create RTVs
$iidResource = guid_from_string('{696442be-a72e-4059-bc79-5b5c98040fad}', $d3d12Types);
$gRenderTargets = [];
for ($i = 0; $i < FRAME_COUNT; $i++) {
    $ppBuffer = FFI::new('void*');
    $getBuffer = FFI::cast($d3d12Types->type('GetBufferFunc'), $gSwapChain->lpVtbl[VTBL_SWAP_GETBUFFER]);
    $hr = $getBuffer($gSwapChain, $i, FFI::addr($iidResource), FFI::addr($ppBuffer));
    if ($hr < 0) { echo "GetBuffer($i) failed\n"; exit(1); }
    $gRenderTargets[$i] = FFI::cast($d3d12Types->type('IUnknown*'), out_ptr($d3d12Types, $ppBuffer));
    $createRtv = FFI::cast($d3d12Types->type('CreateRenderTargetViewFunc'), $gDevice->lpVtbl[VTBL_DEVICE_CREATE_RTV]);
    $handle = $d3d12Types->new('D3D12_CPU_DESCRIPTOR_HANDLE');
    $handle->ptr = $rtvHandle->ptr + $i * $rtvDescriptorSize;
    $createRtv($gDevice, $gRenderTargets[$i], null, $handle);
}
echo "[PHPD3D12] RTVs created\n";

// ============================================================
// SRV/UAV/CBV Heap (shader-visible)
// ============================================================
$srvUavHeapDesc = $d3d12Types->new('D3D12_DESCRIPTOR_HEAP_DESC');
$srvUavHeapDesc->Type = D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV;
$srvUavHeapDesc->NumDescriptors = 5;  // 2 UAVs + 2 SRVs + 1 CBV
$srvUavHeapDesc->Flags = D3D12_DESCRIPTOR_HEAP_FLAG_SHADER_VISIBLE;
$srvUavHeapDesc->NodeMask = 0;

$ppSrvUavHeap = FFI::new('void*');
$hr = $createHeap($gDevice, FFI::addr($srvUavHeapDesc), FFI::addr($iidHeap), FFI::addr($ppSrvUavHeap));
if ($hr < 0) { echo "CreateDescriptorHeap(SRV_UAV_CBV) failed\n"; exit(1); }
$gSrvUavHeap = FFI::cast($d3d12Types->type('IUnknown*'), out_ptr($d3d12Types, $ppSrvUavHeap));

$srvUavDescriptorSize = $getInc($gDevice, D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV);
echo "[PHPD3D12] SRV/UAV/CBV heap created (descriptor size=$srvUavDescriptorSize)\n";

// ============================================================
// Command Allocators (1 graphics + 1 compute)
// ============================================================
$iidAllocator = guid_from_string('{6102dee4-af59-4b09-b999-b44d73f09b24}', $d3d12Types);
$createAllocator = FFI::cast($d3d12Types->type('CreateCommandAllocatorFunc'), $gDevice->lpVtbl[VTBL_DEVICE_CREATE_COMMAND_ALLOCATOR]);

$ppGraphicsAllocator = FFI::new('void*');
$hr = $createAllocator($gDevice, D3D12_COMMAND_LIST_TYPE_DIRECT, FFI::addr($iidAllocator), FFI::addr($ppGraphicsAllocator));
if ($hr < 0) { echo "CreateCommandAllocator(Graphics) failed\n"; exit(1); }
$gGraphicsAllocator = FFI::cast($d3d12Types->type('IUnknown*'), out_ptr($d3d12Types, $ppGraphicsAllocator));

$ppComputeAllocator = FFI::new('void*');
$hr = $createAllocator($gDevice, D3D12_COMMAND_LIST_TYPE_DIRECT, FFI::addr($iidAllocator), FFI::addr($ppComputeAllocator));
if ($hr < 0) { echo "CreateCommandAllocator(Compute) failed\n"; exit(1); }
$gComputeAllocator = FFI::cast($d3d12Types->type('IUnknown*'), out_ptr($d3d12Types, $ppComputeAllocator));
echo "[PHPD3D12] command allocators created\n";

// ============================================================
// Create Buffers (Position, Color, Constant)
// ============================================================
$bufferSize = VERTEX_COUNT * 16;  // float4 = 16 bytes

$defaultHeap = $d3d12Types->new('D3D12_HEAP_PROPERTIES');
$defaultHeap->Type = D3D12_HEAP_TYPE_DEFAULT;
$defaultHeap->CPUPageProperty = 0;
$defaultHeap->MemoryPoolPreference = 0;
$defaultHeap->CreationNodeMask = 1;
$defaultHeap->VisibleNodeMask = 1;

$uploadHeap = $d3d12Types->new('D3D12_HEAP_PROPERTIES');
$uploadHeap->Type = D3D12_HEAP_TYPE_UPLOAD;
$uploadHeap->CPUPageProperty = 0;
$uploadHeap->MemoryPoolPreference = 0;
$uploadHeap->CreationNodeMask = 1;
$uploadHeap->VisibleNodeMask = 1;

$bufDesc = $d3d12Types->new('D3D12_RESOURCE_DESC');
$bufDesc->Dimension = D3D12_RESOURCE_DIMENSION_BUFFER;
$bufDesc->Alignment = 0;
$bufDesc->Width = $bufferSize;
$bufDesc->Height = 1;
$bufDesc->DepthOrArraySize = 1;
$bufDesc->MipLevels = 1;
$bufDesc->Format = DXGI_FORMAT_UNKNOWN;
$bufDesc->SampleDesc->Count = 1;
$bufDesc->SampleDesc->Quality = 0;
$bufDesc->Layout = D3D12_TEXTURE_LAYOUT_ROW_MAJOR;
$bufDesc->Flags = D3D12_RESOURCE_FLAG_ALLOW_UNORDERED_ACCESS;

$createResource = FFI::cast($d3d12Types->type('CreateCommittedResourceFunc'), $gDevice->lpVtbl[VTBL_DEVICE_CREATE_COMMITTED_RESOURCE]);

// Position buffer
$ppPositionBuf = FFI::new('void*');
$hr = $createResource($gDevice, FFI::addr($defaultHeap), 0, FFI::addr($bufDesc),
    D3D12_RESOURCE_STATE_COMMON, null, FFI::addr($iidResource), FFI::addr($ppPositionBuf));
if ($hr < 0) { echo "CreateCommittedResource(positionBuffer) failed\n"; exit(1); }
$gPositionBuffer = FFI::cast($d3d12Types->type('IUnknown*'), out_ptr($d3d12Types, $ppPositionBuf));

// Color buffer
$ppColorBuf = FFI::new('void*');
$hr = $createResource($gDevice, FFI::addr($defaultHeap), 0, FFI::addr($bufDesc),
    D3D12_RESOURCE_STATE_COMMON, null, FFI::addr($iidResource), FFI::addr($ppColorBuf));
if ($hr < 0) { echo "CreateCommittedResource(colorBuffer) failed\n"; exit(1); }
$gColorBuffer = FFI::cast($d3d12Types->type('IUnknown*'), out_ptr($d3d12Types, $ppColorBuf));

// Constant buffer (256-byte aligned)
$cbDesc = $d3d12Types->new('D3D12_RESOURCE_DESC');
$cbDesc->Dimension = D3D12_RESOURCE_DIMENSION_BUFFER;
$cbDesc->Alignment = 0;
$cbDesc->Width = 256;
$cbDesc->Height = 1;
$cbDesc->DepthOrArraySize = 1;
$cbDesc->MipLevels = 1;
$cbDesc->Format = DXGI_FORMAT_UNKNOWN;
$cbDesc->SampleDesc->Count = 1;
$cbDesc->SampleDesc->Quality = 0;
$cbDesc->Layout = D3D12_TEXTURE_LAYOUT_ROW_MAJOR;
$cbDesc->Flags = D3D12_RESOURCE_FLAG_NONE;

$ppConstBuf = FFI::new('void*');
$hr = $createResource($gDevice, FFI::addr($uploadHeap), 0, FFI::addr($cbDesc),
    D3D12_RESOURCE_STATE_GENERIC_READ, null, FFI::addr($iidResource), FFI::addr($ppConstBuf));
if ($hr < 0) { echo "CreateCommittedResource(constantBuffer) failed\n"; exit(1); }
$gConstantBuffer = FFI::cast($d3d12Types->type('IUnknown*'), out_ptr($d3d12Types, $ppConstBuf));

// Map constant buffer
$mapFn = FFI::cast($d3d12Types->type('MapResourceFunc'), $gConstantBuffer->lpVtbl[VTBL_RESOURCE_MAP]);
$mapped = FFI::new('void*');
$readRange = $d3d12Types->new('D3D12_RANGE');
$readRange->Begin = 0;
$readRange->End = 0;
$hr = $mapFn($gConstantBuffer, 0, FFI::addr($readRange), FFI::addr($mapped));
if ($hr < 0) { echo "Map(constantBuffer) failed\n"; exit(1); }
$gConstantBufferPtr = $mapped;

echo "[PHPD3D12] buffers created and constant buffer mapped\n";

// ============================================================
// Create UAVs, SRVs, CBV
// ============================================================
$srvUavCpuHandle = $d3d12Types->new('D3D12_CPU_DESCRIPTOR_HANDLE');
$getCpuHandleSrvUav = FFI::cast($d3d12Types->type('GetCPUDescriptorHandleForHeapStartFunc'), $gSrvUavHeap->lpVtbl[VTBL_DESCRIPTOR_HEAP_GET_CPU_HANDLE]);
$getCpuHandleSrvUav($gSrvUavHeap, FFI::addr($srvUavCpuHandle));

// UAV desc
$uavDesc = $d3d12Types->new('D3D12_UNORDERED_ACCESS_VIEW_DESC');
$uavDesc->Format = DXGI_FORMAT_UNKNOWN;
$uavDesc->ViewDimension = D3D12_UAV_DIMENSION_BUFFER;
$uavDesc->Buffer->FirstElement = 0;
$uavDesc->Buffer->NumElements = VERTEX_COUNT;
$uavDesc->Buffer->StructureByteStride = 16;
$uavDesc->Buffer->CounterOffsetInBytes = 0;
$uavDesc->Buffer->Flags = 0;

$createUav = FFI::cast($d3d12Types->type('CreateUnorderedAccessViewFunc'), $gDevice->lpVtbl[VTBL_DEVICE_CREATE_UAV]);

// Slot 0: Position UAV
$h0 = $d3d12Types->new('D3D12_CPU_DESCRIPTOR_HANDLE');
$h0->ptr = $srvUavCpuHandle->ptr;
$createUav($gDevice, $gPositionBuffer, null, FFI::addr($uavDesc), $h0);

// Slot 1: Color UAV
$h1 = $d3d12Types->new('D3D12_CPU_DESCRIPTOR_HANDLE');
$h1->ptr = $srvUavCpuHandle->ptr + $srvUavDescriptorSize;
$createUav($gDevice, $gColorBuffer, null, FFI::addr($uavDesc), $h1);

// SRV desc
$srvDesc = $d3d12Types->new('D3D12_SHADER_RESOURCE_VIEW_DESC');
$srvDesc->Format = DXGI_FORMAT_UNKNOWN;
$srvDesc->ViewDimension = D3D12_SRV_DIMENSION_BUFFER;
$srvDesc->Shader4ComponentMapping = D3D12_DEFAULT_SHADER_4_COMPONENT_MAPPING;
$srvDesc->Buffer->FirstElement = 0;
$srvDesc->Buffer->NumElements = VERTEX_COUNT;
$srvDesc->Buffer->StructureByteStride = 16;
$srvDesc->Buffer->Flags = 0;

$createSrv = FFI::cast($d3d12Types->type('CreateShaderResourceViewFunc'), $gDevice->lpVtbl[VTBL_DEVICE_CREATE_SRV]);

// Slot 2: Position SRV
$h2 = $d3d12Types->new('D3D12_CPU_DESCRIPTOR_HANDLE');
$h2->ptr = $srvUavCpuHandle->ptr + $srvUavDescriptorSize * 2;
$createSrv($gDevice, $gPositionBuffer, FFI::addr($srvDesc), $h2);

// Slot 3: Color SRV
$h3 = $d3d12Types->new('D3D12_CPU_DESCRIPTOR_HANDLE');
$h3->ptr = $srvUavCpuHandle->ptr + $srvUavDescriptorSize * 3;
$createSrv($gDevice, $gColorBuffer, FFI::addr($srvDesc), $h3);

// CBV desc
$getGpuVA = FFI::cast($d3d12Types->type('GetGPUVirtualAddressFunc'), $gConstantBuffer->lpVtbl[VTBL_RESOURCE_GET_GPU_VA]);
$cbGpuVA = $getGpuVA($gConstantBuffer);

$cbvDesc = $d3d12Types->new('D3D12_CONSTANT_BUFFER_VIEW_DESC');
$cbvDesc->BufferLocation = $cbGpuVA;
$cbvDesc->SizeInBytes = 256;

$createCbv = FFI::cast($d3d12Types->type('CreateConstantBufferViewFunc'), $gDevice->lpVtbl[VTBL_DEVICE_CREATE_CBV]);

// Slot 4: CBV
$h4 = $d3d12Types->new('D3D12_CPU_DESCRIPTOR_HANDLE');
$h4->ptr = $srvUavCpuHandle->ptr + $srvUavDescriptorSize * 4;
$createCbv($gDevice, FFI::addr($cbvDesc), $h4);

echo "[PHPD3D12] UAVs, SRVs, CBV created\n";

// ============================================================
// Root Signatures
// ============================================================

// --- Compute Root Signature ---
// Param 0: UAV table (u0, u1)
// Param 1: CBV table (b0)
$uavRange = $d3d12Types->new('D3D12_DESCRIPTOR_RANGE');
$uavRange->RangeType = D3D12_DESCRIPTOR_RANGE_TYPE_UAV;
$uavRange->NumDescriptors = 2;
$uavRange->BaseShaderRegister = 0;
$uavRange->RegisterSpace = 0;
$uavRange->OffsetInDescriptorsFromTableStart = 0xFFFFFFFF;

$cbvRange = $d3d12Types->new('D3D12_DESCRIPTOR_RANGE');
$cbvRange->RangeType = D3D12_DESCRIPTOR_RANGE_TYPE_CBV;
$cbvRange->NumDescriptors = 1;
$cbvRange->BaseShaderRegister = 0;
$cbvRange->RegisterSpace = 0;
$cbvRange->OffsetInDescriptorsFromTableStart = 0xFFFFFFFF;

$computeParams = $d3d12Types->new('D3D12_ROOT_PARAMETER[2]');
$computeParams[0]->ParameterType = D3D12_ROOT_PARAMETER_TYPE_DESCRIPTOR_TABLE;
$computeParams[0]->u->DescriptorTable->NumDescriptorRanges = 1;
$computeParams[0]->u->DescriptorTable->pDescriptorRanges = FFI::addr($uavRange);
$computeParams[0]->ShaderVisibility = D3D12_SHADER_VISIBILITY_ALL;

$computeParams[1]->ParameterType = D3D12_ROOT_PARAMETER_TYPE_DESCRIPTOR_TABLE;
$computeParams[1]->u->DescriptorTable->NumDescriptorRanges = 1;
$computeParams[1]->u->DescriptorTable->pDescriptorRanges = FFI::addr($cbvRange);
$computeParams[1]->ShaderVisibility = D3D12_SHADER_VISIBILITY_ALL;

$computeRsDesc = $d3d12Types->new('D3D12_ROOT_SIGNATURE_DESC');
FFI::memset(FFI::addr($computeRsDesc), 0, FFI::sizeof($computeRsDesc));
$computeRsDesc->NumParameters = 2;
$computeRsDesc->pParameters = FFI::addr($computeParams[0]);
$computeRsDesc->NumStaticSamplers = 0;
$computeRsDesc->pStaticSamplers = null;
$computeRsDesc->Flags = D3D12_ROOT_SIGNATURE_FLAG_NONE;

$gComputeRootSig = serialize_and_create_root_signature($d3d12Types, $gDevice, $serializeRootSig, $computeRsDesc, 'Compute');

// --- Graphics Root Signature ---
// Param 0: SRV table (t0, t1)
// Param 1: CBV table (b0)
$srvRange = $d3d12Types->new('D3D12_DESCRIPTOR_RANGE');
$srvRange->RangeType = D3D12_DESCRIPTOR_RANGE_TYPE_SRV;
$srvRange->NumDescriptors = 2;
$srvRange->BaseShaderRegister = 0;
$srvRange->RegisterSpace = 0;
$srvRange->OffsetInDescriptorsFromTableStart = 0xFFFFFFFF;

$graphicsParams = $d3d12Types->new('D3D12_ROOT_PARAMETER[2]');
$graphicsParams[0]->ParameterType = D3D12_ROOT_PARAMETER_TYPE_DESCRIPTOR_TABLE;
$graphicsParams[0]->u->DescriptorTable->NumDescriptorRanges = 1;
$graphicsParams[0]->u->DescriptorTable->pDescriptorRanges = FFI::addr($srvRange);
$graphicsParams[0]->ShaderVisibility = D3D12_SHADER_VISIBILITY_VERTEX;

$graphicsParams[1]->ParameterType = D3D12_ROOT_PARAMETER_TYPE_DESCRIPTOR_TABLE;
$graphicsParams[1]->u->DescriptorTable->NumDescriptorRanges = 1;
$graphicsParams[1]->u->DescriptorTable->pDescriptorRanges = FFI::addr($cbvRange);
$graphicsParams[1]->ShaderVisibility = D3D12_SHADER_VISIBILITY_VERTEX;

$graphicsRsDesc = $d3d12Types->new('D3D12_ROOT_SIGNATURE_DESC');
FFI::memset(FFI::addr($graphicsRsDesc), 0, FFI::sizeof($graphicsRsDesc));
$graphicsRsDesc->NumParameters = 2;
$graphicsRsDesc->pParameters = FFI::addr($graphicsParams[0]);
$graphicsRsDesc->NumStaticSamplers = 0;
$graphicsRsDesc->pStaticSamplers = null;
$graphicsRsDesc->Flags = D3D12_ROOT_SIGNATURE_FLAG_NONE;

$gGraphicsRootSig = serialize_and_create_root_signature($d3d12Types, $gDevice, $serializeRootSig, $graphicsRsDesc, 'Graphics');

// ============================================================
// Compile Shaders
// ============================================================
$hlslPath = __DIR__ . DIRECTORY_SEPARATOR . 'hello.hlsl';
$hlslSource = file_get_contents($hlslPath);
if ($hlslSource === false) { echo "Failed to read hello.hlsl\n"; exit(1); }

$csBlob = compile_hlsl($d3d12Types, $d3dCompile, $hlslSource, 'CSMain', 'cs_5_0');
$vsBlob = compile_hlsl($d3d12Types, $d3dCompile, $hlslSource, 'VSMain', 'vs_5_0');
$psBlob = compile_hlsl($d3d12Types, $d3dCompile, $hlslSource, 'PSMain', 'ps_5_0');
echo "[PHPD3D12] shaders compiled\n";

// ============================================================
// Create Pipeline States
// ============================================================

// Compute PSO
$computePsoDesc = $d3d12Types->new('D3D12_COMPUTE_PIPELINE_STATE_DESC');
FFI::memset(FFI::addr($computePsoDesc), 0, FFI::sizeof($computePsoDesc));
$computePsoDesc->pRootSignature = FFI::cast('void*', $gComputeRootSig);
$computePsoDesc->CS->pShaderBytecode = blob_ptr($d3d12Types, $csBlob);
$computePsoDesc->CS->BytecodeLength  = blob_size($d3d12Types, $csBlob);

$iidPso = guid_from_string('{765a30f3-f624-4c6f-a828-ace948622445}', $d3d12Types);
$ppComputePso = FFI::new('void*');
$createComputePso = FFI::cast($d3d12Types->type('CreateComputePipelineStateFunc'), $gDevice->lpVtbl[VTBL_DEVICE_CREATE_COMPUTE_PSO]);
$hr = $createComputePso($gDevice, FFI::addr($computePsoDesc), FFI::addr($iidPso), FFI::addr($ppComputePso));
if ($hr < 0) { echo "CreateComputePipelineState failed (hr=0x" . dechex($hr & 0xffffffff) . ")\n"; exit(1); }
$gComputePso = FFI::cast($d3d12Types->type('IUnknown*'), out_ptr($d3d12Types, $ppComputePso));
echo "[PHPD3D12] compute PSO created\n";

// Graphics PSO (line topology, no input layout - uses SV_VertexID)
$psoDesc = $d3d12Types->new('D3D12_GRAPHICS_PIPELINE_STATE_DESC');
FFI::memset(FFI::addr($psoDesc), 0, FFI::sizeof($psoDesc));

$psoDesc->pRootSignature = FFI::cast('void*', $gGraphicsRootSig);
$psoDesc->VS->pShaderBytecode = blob_ptr($d3d12Types, $vsBlob);
$psoDesc->VS->BytecodeLength  = blob_size($d3d12Types, $vsBlob);
$psoDesc->PS->pShaderBytecode = blob_ptr($d3d12Types, $psBlob);
$psoDesc->PS->BytecodeLength  = blob_size($d3d12Types, $psBlob);

$psoDesc->BlendState->AlphaToCoverageEnable = 0;
$psoDesc->BlendState->IndependentBlendEnable = 0;
$psoDesc->BlendState->RenderTarget[0]->BlendEnable = 0;
$psoDesc->BlendState->RenderTarget[0]->LogicOpEnable = 0;
$psoDesc->BlendState->RenderTarget[0]->SrcBlend = D3D12_BLEND_ONE;
$psoDesc->BlendState->RenderTarget[0]->DestBlend = D3D12_BLEND_ZERO;
$psoDesc->BlendState->RenderTarget[0]->BlendOp = D3D12_BLEND_OP_ADD;
$psoDesc->BlendState->RenderTarget[0]->SrcBlendAlpha = D3D12_BLEND_ONE;
$psoDesc->BlendState->RenderTarget[0]->DestBlendAlpha = D3D12_BLEND_ZERO;
$psoDesc->BlendState->RenderTarget[0]->BlendOpAlpha = D3D12_BLEND_OP_ADD;
$psoDesc->BlendState->RenderTarget[0]->LogicOp = D3D12_LOGIC_OP_NOOP;
$psoDesc->BlendState->RenderTarget[0]->RenderTargetWriteMask = D3D12_COLOR_WRITE_ENABLE_ALL;

$psoDesc->SampleMask = 0xFFFFFFFF;

$psoDesc->RasterizerState->FillMode = D3D12_FILL_MODE_SOLID;
$psoDesc->RasterizerState->CullMode = D3D12_CULL_MODE_NONE;
$psoDesc->RasterizerState->FrontCounterClockwise = 0;
$psoDesc->RasterizerState->DepthBias = 0;
$psoDesc->RasterizerState->DepthBiasClamp = 0.0;
$psoDesc->RasterizerState->SlopeScaledDepthBias = 0.0;
$psoDesc->RasterizerState->DepthClipEnable = 1;
$psoDesc->RasterizerState->MultisampleEnable = 0;
$psoDesc->RasterizerState->AntialiasedLineEnable = 0;
$psoDesc->RasterizerState->ForcedSampleCount = 0;
$psoDesc->RasterizerState->ConservativeRaster = 0;

$psoDesc->DepthStencilState->DepthEnable = 0;
$psoDesc->DepthStencilState->StencilEnable = 0;

// No input layout (using SV_VertexID)
$psoDesc->InputLayout->pInputElementDescs = null;
$psoDesc->InputLayout->NumElements = 0;

$psoDesc->PrimitiveTopologyType = D3D12_PRIMITIVE_TOPOLOGY_TYPE_LINE;
$psoDesc->NumRenderTargets = 1;
$psoDesc->RTVFormats[0] = DXGI_FORMAT_R8G8B8A8_UNORM;
$psoDesc->SampleDesc->Count = 1;
$psoDesc->SampleDesc->Quality = 0;

$ppGraphicsPso = FFI::new('void*');
$createGraphicsPso = FFI::cast($d3d12Types->type('CreateGraphicsPipelineStateFunc'), $gDevice->lpVtbl[VTBL_DEVICE_CREATE_GRAPHICS_PSO]);
$hr = $createGraphicsPso($gDevice, FFI::addr($psoDesc), FFI::addr($iidPso), FFI::addr($ppGraphicsPso));
if ($hr < 0) { echo "CreateGraphicsPipelineState failed (hr=0x" . dechex($hr & 0xffffffff) . ")\n"; exit(1); }
$gGraphicsPso = FFI::cast($d3d12Types->type('IUnknown*'), out_ptr($d3d12Types, $ppGraphicsPso));
echo "[PHPD3D12] graphics PSO created\n";

// Free shader blobs
com_release($d3d12Types, $csBlob);
com_release($d3d12Types, $vsBlob);
com_release($d3d12Types, $psBlob);

// ============================================================
// Create Command Lists
// ============================================================
$iidCmdList = guid_from_string('{5b160d0f-ac1b-4185-8ba8-b3ae42a5a455}', $d3d12Types);
$createCmdList = FFI::cast($d3d12Types->type('CreateCommandListFunc'), $gDevice->lpVtbl[VTBL_DEVICE_CREATE_COMMAND_LIST]);

// Graphics command list
$ppGfxCmdList = FFI::new('void*');
$hr = $createCmdList($gDevice, 0, D3D12_COMMAND_LIST_TYPE_DIRECT, $gGraphicsAllocator, $gGraphicsPso, FFI::addr($iidCmdList), FFI::addr($ppGfxCmdList));
if ($hr < 0) { echo "CreateCommandList(Graphics) failed\n"; exit(1); }
$gGraphicsCmdList = FFI::cast($d3d12Types->type('IUnknown*'), out_ptr($d3d12Types, $ppGfxCmdList));

$closeCmdListFn = FFI::cast($d3d12Types->type('CommandListCloseFunc'), $gGraphicsCmdList->lpVtbl[VTBL_COMMAND_LIST_CLOSE]);
$closeCmdListFn($gGraphicsCmdList);

// Compute command list
$ppCompCmdList = FFI::new('void*');
$hr = $createCmdList($gDevice, 0, D3D12_COMMAND_LIST_TYPE_DIRECT, $gComputeAllocator, $gComputePso, FFI::addr($iidCmdList), FFI::addr($ppCompCmdList));
if ($hr < 0) { echo "CreateCommandList(Compute) failed\n"; exit(1); }
$gComputeCmdList = FFI::cast($d3d12Types->type('IUnknown*'), out_ptr($d3d12Types, $ppCompCmdList));

$closeCompCmdListFn = FFI::cast($d3d12Types->type('CommandListCloseFunc'), $gComputeCmdList->lpVtbl[VTBL_COMMAND_LIST_CLOSE]);
$closeCompCmdListFn($gComputeCmdList);

echo "[PHPD3D12] command lists created\n";

// ============================================================
// Fence
// ============================================================
$iidFence = guid_from_string('{0a753dcf-c4d8-4b91-adf6-be5a60d95a76}', $d3d12Types);
$ppFence = FFI::new('void*');
$createFence = FFI::cast($d3d12Types->type('CreateFenceFunc'), $gDevice->lpVtbl[VTBL_DEVICE_CREATE_FENCE]);
$hr = $createFence($gDevice, 0, D3D12_FENCE_FLAG_NONE, FFI::addr($iidFence), FFI::addr($ppFence));
if ($hr < 0) { echo "CreateFence failed\n"; exit(1); }
$gFence = FFI::cast($d3d12Types->type('IUnknown*'), out_ptr($d3d12Types, $ppFence));
$gFenceValue = 1;

$fenceEvent = $kernel32->CreateEventW(null, 0, 0, null);
if ($fenceEvent === null) { echo "CreateEventW failed\n"; exit(1); }

echo "[PHPD3D12] fence created\n";

// ============================================================
// Harmonograph Parameters
// ============================================================
$gParams = $d3d12Types->new('HarmonographParams');
$gParams->A1 = 50.0; $gParams->f1 = 2.0;  $gParams->p1 = 1.0/16.0;   $gParams->d1 = 0.02;
$gParams->A2 = 50.0; $gParams->f2 = 2.0;  $gParams->p2 = 3.0/2.0;    $gParams->d2 = 0.0315;
$gParams->A3 = 50.0; $gParams->f3 = 2.0;  $gParams->p3 = 13.0/15.0;  $gParams->d3 = 0.02;
$gParams->A4 = 50.0; $gParams->f4 = 2.0;  $gParams->p4 = 1.0;        $gParams->d4 = 0.02;
$gParams->max_num = VERTEX_COUNT;
$gParams->pad1 = 0.0; $gParams->pad2 = 0.0; $gParams->pad3 = 0.0;
$gParams->resX = (float)$width;
$gParams->resY = (float)$height;
$gParams->pad4 = 0.0; $gParams->pad5 = 0.0;

$PI2 = M_PI * 2.0;

// ============================================================
// Wait helper
// ============================================================
function wait_for_gpu(
    FFI $ffi, FFI\CData $commandQueue, FFI\CData $fence, int &$fenceValue,
    FFI\CData $fenceEvent, $kernel32, FFI\CData $swapChain, int &$frameIndex
): void {
    $currentVal = $fenceValue;

    $signal = FFI::cast($ffi->type('SignalFunc'), $commandQueue->lpVtbl[VTBL_COMMAND_QUEUE_SIGNAL]);
    $signal($commandQueue, $fence, $currentVal);
    $fenceValue++;

    $getCompleted = FFI::cast($ffi->type('GetCompletedValueFunc'), $fence->lpVtbl[VTBL_FENCE_GET_COMPLETED]);
    if ($getCompleted($fence) < $currentVal) {
        $setEvent = FFI::cast($ffi->type('SetEventOnCompletionFunc'), $fence->lpVtbl[VTBL_FENCE_SET_EVENT]);
        $setEvent($fence, $currentVal, $fenceEvent);
        $kernel32->WaitForSingleObject($fenceEvent, 0xFFFFFFFF);
    }

    $getIdx = FFI::cast($ffi->type('GetCurrentBackBufferIndexFunc'), $swapChain->lpVtbl[VTBL_SWAP_GET_CURRENT_BACKBUFFER_INDEX]);
    $frameIndex = $getIdx($swapChain);
}

// ============================================================
// Render loop
// ============================================================
echo "[PHPD3D12] entering render loop\n";

$user32->ShowWindow($hwnd, SW_SHOWDEFAULT);
$user32->UpdateWindow($hwnd);

$msg = $user32->new('MSG');

while ($user32->IsWindow($hwnd)) {
    while ($user32->PeekMessageW(FFI::addr($msg), null, 0, 0, PM_REMOVE)) {
        if ($msg->message === WM_QUIT) {
            break 2;
        }
        $user32->TranslateMessage(FFI::addr($msg));
        $user32->DispatchMessageW(FFI::addr($msg));
    }

    // --- Animate parameters ---
    $gParams->f1 = fmod($gParams->f1 + mt_rand() / mt_getrandmax() / 200.0, 10.0);
    $gParams->f2 = fmod($gParams->f2 + mt_rand() / mt_getrandmax() / 200.0, 10.0);
    $gParams->p1 += $PI2 * 0.5 / 360.0;

    // Copy params to constant buffer
    FFI::memcpy($gConstantBufferPtr, FFI::addr($gParams), FFI::sizeof($gParams));

    // ============ COMPUTE PASS ============
    $resetCA = FFI::cast($d3d12Types->type('ResetCommandAllocatorFunc'), $gComputeAllocator->lpVtbl[VTBL_COMMAND_ALLOCATOR_RESET]);
    $resetCA($gComputeAllocator);

    $resetCL = FFI::cast($d3d12Types->type('CommandListResetFunc'), $gComputeCmdList->lpVtbl[VTBL_COMMAND_LIST_RESET]);
    $resetCL($gComputeCmdList, $gComputeAllocator, $gComputePso);

    // Set descriptor heaps
    $heaps = $d3d12Types->new('void*[1]');
    $heaps[0] = FFI::cast('void*', $gSrvUavHeap);
    $setHeaps = FFI::cast($d3d12Types->type('SetDescriptorHeapsFunc'), $gComputeCmdList->lpVtbl[VTBL_COMMAND_LIST_SET_DESCRIPTOR_HEAPS]);
    $setHeaps($gComputeCmdList, 1, FFI::addr($heaps[0]));

    // Set compute root signature
    $setComputeRS = FFI::cast($d3d12Types->type('SetComputeRootSignatureFunc'), $gComputeCmdList->lpVtbl[VTBL_COMMAND_LIST_SET_COMPUTE_ROOT_SIGNATURE]);
    $setComputeRS($gComputeCmdList, $gComputeRootSig);

    // Get GPU descriptor handle
    $gpuHandle = $d3d12Types->new('D3D12_GPU_DESCRIPTOR_HANDLE');
    $getGpuHandle = FFI::cast($d3d12Types->type('GetGPUDescriptorHandleForHeapStartFunc'), $gSrvUavHeap->lpVtbl[VTBL_DESCRIPTOR_HEAP_GET_GPU_HANDLE]);
    $getGpuHandle($gSrvUavHeap, FFI::addr($gpuHandle));

    // Set compute root descriptor tables
    $setComputeTable = FFI::cast($d3d12Types->type('SetComputeRootDescriptorTableFunc'), $gComputeCmdList->lpVtbl[VTBL_COMMAND_LIST_SET_COMPUTE_ROOT_DESCRIPTOR_TABLE]);

    // Table 0: UAVs (slots 0-1)
    $setComputeTable($gComputeCmdList, 0, $gpuHandle);

    // Table 1: CBV (slot 4)
    $cbvGpuHandle = $d3d12Types->new('D3D12_GPU_DESCRIPTOR_HANDLE');
    $cbvGpuHandle->ptr = $gpuHandle->ptr + $srvUavDescriptorSize * 4;
    $setComputeTable($gComputeCmdList, 1, $cbvGpuHandle);

    // Dispatch compute shader
    $dispatch = FFI::cast($d3d12Types->type('DispatchFunc'), $gComputeCmdList->lpVtbl[VTBL_COMMAND_LIST_DISPATCH]);
    $dispatch($gComputeCmdList, intdiv(VERTEX_COUNT + 63, 64), 1, 1);

    // Resource barriers: UAV -> SRV
    $barriers = $d3d12Types->new('D3D12_RESOURCE_BARRIER[2]');
    $barriers[0]->Type = D3D12_RESOURCE_BARRIER_TYPE_TRANSITION;
    $barriers[0]->Flags = D3D12_RESOURCE_BARRIER_FLAG_NONE;
    $barriers[0]->u->Transition->pResource = FFI::cast('void*', $gPositionBuffer);
    $barriers[0]->u->Transition->Subresource = D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES;
    $barriers[0]->u->Transition->StateBefore = D3D12_RESOURCE_STATE_UNORDERED_ACCESS;
    $barriers[0]->u->Transition->StateAfter = D3D12_RESOURCE_STATE_NON_PIXEL_SHADER_RESOURCE;

    $barriers[1]->Type = D3D12_RESOURCE_BARRIER_TYPE_TRANSITION;
    $barriers[1]->Flags = D3D12_RESOURCE_BARRIER_FLAG_NONE;
    $barriers[1]->u->Transition->pResource = FFI::cast('void*', $gColorBuffer);
    $barriers[1]->u->Transition->Subresource = D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES;
    $barriers[1]->u->Transition->StateBefore = D3D12_RESOURCE_STATE_UNORDERED_ACCESS;
    $barriers[1]->u->Transition->StateAfter = D3D12_RESOURCE_STATE_NON_PIXEL_SHADER_RESOURCE;

    $resourceBarrier = FFI::cast($d3d12Types->type('ResourceBarrierFunc'), $gComputeCmdList->lpVtbl[VTBL_COMMAND_LIST_RESOURCE_BARRIER]);
    $resourceBarrier($gComputeCmdList, 2, FFI::addr($barriers[0]));

    // Close & execute compute command list
    $closeComp = FFI::cast($d3d12Types->type('CommandListCloseFunc'), $gComputeCmdList->lpVtbl[VTBL_COMMAND_LIST_CLOSE]);
    $closeComp($gComputeCmdList);

    $cmdLists = $d3d12Types->new('void*[1]');
    $cmdLists[0] = FFI::cast('void*', $gComputeCmdList);
    $executeLists = FFI::cast($d3d12Types->type('ExecuteCommandListsFunc'), $gCommandQueue->lpVtbl[VTBL_COMMAND_QUEUE_EXECUTE_LISTS]);
    $executeLists($gCommandQueue, 1, FFI::addr($cmdLists[0]));

    // ============ GRAPHICS PASS ============
    $resetGfxCA = FFI::cast($d3d12Types->type('ResetCommandAllocatorFunc'), $gGraphicsAllocator->lpVtbl[VTBL_COMMAND_ALLOCATOR_RESET]);
    $resetGfxCA($gGraphicsAllocator);

    $resetGfxCL = FFI::cast($d3d12Types->type('CommandListResetFunc'), $gGraphicsCmdList->lpVtbl[VTBL_COMMAND_LIST_RESET]);
    $resetGfxCL($gGraphicsCmdList, $gGraphicsAllocator, $gGraphicsPso);

    // Set descriptor heaps
    $setHeapsGfx = FFI::cast($d3d12Types->type('SetDescriptorHeapsFunc'), $gGraphicsCmdList->lpVtbl[VTBL_COMMAND_LIST_SET_DESCRIPTOR_HEAPS]);
    $setHeapsGfx($gGraphicsCmdList, 1, FFI::addr($heaps[0]));

    // Set graphics root signature
    $setGfxRS = FFI::cast($d3d12Types->type('SetGraphicsRootSignatureFunc'), $gGraphicsCmdList->lpVtbl[VTBL_COMMAND_LIST_SET_ROOT_SIGNATURE]);
    $setGfxRS($gGraphicsCmdList, $gGraphicsRootSig);

    // Set graphics root descriptor tables
    $setGfxTable = FFI::cast($d3d12Types->type('SetGraphicsRootDescriptorTableFunc'), $gGraphicsCmdList->lpVtbl[VTBL_COMMAND_LIST_SET_GRAPHICS_ROOT_DESCRIPTOR_TABLE]);

    // Table 0: SRVs (slots 2-3)
    $srvGpuHandle = $d3d12Types->new('D3D12_GPU_DESCRIPTOR_HANDLE');
    $srvGpuHandle->ptr = $gpuHandle->ptr + $srvUavDescriptorSize * 2;
    $setGfxTable($gGraphicsCmdList, 0, $srvGpuHandle);

    // Table 1: CBV (slot 4)
    $setGfxTable($gGraphicsCmdList, 1, $cbvGpuHandle);

    // Set viewport
    $viewport = $d3d12Types->new('D3D12_VIEWPORT');
    $viewport->TopLeftX = 0.0;
    $viewport->TopLeftY = 0.0;
    $viewport->Width = (float)$width;
    $viewport->Height = (float)$height;
    $viewport->MinDepth = 0.0;
    $viewport->MaxDepth = 1.0;
    $rsSetViewports = FFI::cast($d3d12Types->type('RSSetViewportsFunc'), $gGraphicsCmdList->lpVtbl[VTBL_COMMAND_LIST_RS_SET_VIEWPORTS]);
    $rsSetViewports($gGraphicsCmdList, 1, FFI::addr($viewport));

    // Set scissor rect
    $scissor = $d3d12Types->new('D3D12_RECT');
    $scissor->left = 0;
    $scissor->top = 0;
    $scissor->right = $width;
    $scissor->bottom = $height;
    $rsSetScissor = FFI::cast($d3d12Types->type('RSSetScissorRectsFunc'), $gGraphicsCmdList->lpVtbl[VTBL_COMMAND_LIST_RS_SET_SCISSOR_RECTS]);
    $rsSetScissor($gGraphicsCmdList, 1, FFI::addr($scissor));

    // Barrier: PRESENT -> RENDER_TARGET
    $rtBarrier = $d3d12Types->new('D3D12_RESOURCE_BARRIER');
    $rtBarrier->Type = D3D12_RESOURCE_BARRIER_TYPE_TRANSITION;
    $rtBarrier->Flags = D3D12_RESOURCE_BARRIER_FLAG_NONE;
    $rtBarrier->u->Transition->pResource = FFI::cast('void*', $gRenderTargets[$gFrameIndex]);
    $rtBarrier->u->Transition->Subresource = D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES;
    $rtBarrier->u->Transition->StateBefore = D3D12_RESOURCE_STATE_PRESENT;
    $rtBarrier->u->Transition->StateAfter = D3D12_RESOURCE_STATE_RENDER_TARGET;

    $gfxBarrier = FFI::cast($d3d12Types->type('ResourceBarrierFunc'), $gGraphicsCmdList->lpVtbl[VTBL_COMMAND_LIST_RESOURCE_BARRIER]);
    $gfxBarrier($gGraphicsCmdList, 1, FFI::addr($rtBarrier));

    // Set render target
    $rtv = $d3d12Types->new('D3D12_CPU_DESCRIPTOR_HANDLE');
    $getCpuHandle($gRtvHeap, FFI::addr($rtv));
    $rtv->ptr += $gFrameIndex * $rtvDescriptorSize;

    $omSet = FFI::cast($d3d12Types->type('OMSetRenderTargetsFunc'), $gGraphicsCmdList->lpVtbl[VTBL_COMMAND_LIST_OM_SET_RENDER_TARGETS]);
    $omSet($gGraphicsCmdList, 1, FFI::addr($rtv), 0, null);

    // Clear render target (dark blue background)
    $clearColor = $d3d12Types->new('float[4]');
    $clearColor[0] = 0.05;
    $clearColor[1] = 0.05;
    $clearColor[2] = 0.1;
    $clearColor[3] = 1.0;

    $clearRtv = FFI::cast($d3d12Types->type('ClearRenderTargetViewFunc'), $gGraphicsCmdList->lpVtbl[VTBL_COMMAND_LIST_CLEAR_RTV]);
    $clearRtv($gGraphicsCmdList, $rtv, FFI::addr($clearColor[0]), 0, null);

    // Set primitive topology
    $setTopo = FFI::cast($d3d12Types->type('IASetPrimitiveTopologyFunc'), $gGraphicsCmdList->lpVtbl[VTBL_COMMAND_LIST_IA_SET_PRIMITIVE_TOPOLOGY]);
    $setTopo($gGraphicsCmdList, D3D_PRIMITIVE_TOPOLOGY_LINESTRIP);

    // Draw
    $draw = FFI::cast($d3d12Types->type('DrawInstancedFunc'), $gGraphicsCmdList->lpVtbl[VTBL_COMMAND_LIST_DRAW_INSTANCED]);
    $draw($gGraphicsCmdList, VERTEX_COUNT, 1, 0, 0);

    // Barrier: RENDER_TARGET -> PRESENT
    $rtBarrier->u->Transition->StateBefore = D3D12_RESOURCE_STATE_RENDER_TARGET;
    $rtBarrier->u->Transition->StateAfter = D3D12_RESOURCE_STATE_PRESENT;
    $gfxBarrier($gGraphicsCmdList, 1, FFI::addr($rtBarrier));

    // Resource barriers: SRV -> UAV (for next frame)
    $barriers[0]->u->Transition->StateBefore = D3D12_RESOURCE_STATE_NON_PIXEL_SHADER_RESOURCE;
    $barriers[0]->u->Transition->StateAfter = D3D12_RESOURCE_STATE_UNORDERED_ACCESS;
    $barriers[1]->u->Transition->StateBefore = D3D12_RESOURCE_STATE_NON_PIXEL_SHADER_RESOURCE;
    $barriers[1]->u->Transition->StateAfter = D3D12_RESOURCE_STATE_UNORDERED_ACCESS;
    $gfxBarrier($gGraphicsCmdList, 2, FFI::addr($barriers[0]));

    // Close & execute graphics command list
    $closeGfx = FFI::cast($d3d12Types->type('CommandListCloseFunc'), $gGraphicsCmdList->lpVtbl[VTBL_COMMAND_LIST_CLOSE]);
    $closeGfx($gGraphicsCmdList);

    $cmdLists[0] = FFI::cast('void*', $gGraphicsCmdList);
    $executeLists($gCommandQueue, 1, FFI::addr($cmdLists[0]));

    // Present
    $present = FFI::cast($d3d12Types->type('PresentFunc'), $gSwapChain->lpVtbl[VTBL_SWAP_PRESENT]);
    $present($gSwapChain, 1, 0);

    // Wait for GPU
    wait_for_gpu($d3d12Types, $gCommandQueue, $gFence, $gFenceValue, $fenceEvent, $kernel32, $gSwapChain, $gFrameIndex);
}

// ============================================================
// Cleanup
// ============================================================
echo "[PHPD3D12] cleaning up\n";

// Final GPU wait
wait_for_gpu($d3d12Types, $gCommandQueue, $gFence, $gFenceValue, $fenceEvent, $kernel32, $gSwapChain, $gFrameIndex);

$kernel32->CloseHandle($fenceEvent);

com_release($d3d12Types, $gFence);
com_release($d3d12Types, $gConstantBuffer);
com_release($d3d12Types, $gColorBuffer);
com_release($d3d12Types, $gPositionBuffer);
com_release($d3d12Types, $gComputePso);
com_release($d3d12Types, $gGraphicsPso);
com_release($d3d12Types, $gComputeRootSig);
com_release($d3d12Types, $gGraphicsRootSig);
com_release($d3d12Types, $gComputeCmdList);
com_release($d3d12Types, $gGraphicsCmdList);
com_release($d3d12Types, $gComputeAllocator);
com_release($d3d12Types, $gGraphicsAllocator);
com_release($d3d12Types, $gSrvUavHeap);
com_release($d3d12Types, $gRtvHeap);
foreach ($gRenderTargets as $rt) {
    com_release($d3d12Types, $rt);
}
com_release($d3d12Types, $gSwapChain);
com_release($d3d12Types, $gCommandQueue);
com_release($d3d12Types, $gDevice);
com_release($d3d12Types, $gFactory);

$kernel32->FreeLibrary($hD3D12);
$kernel32->FreeLibrary($hDxgi);
$kernel32->FreeLibrary($hCompiler);

echo "[PHPD3D12] done\n";
