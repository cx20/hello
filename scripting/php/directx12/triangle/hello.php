<?php
declare(strict_types=1);

echo "[PHPD3D12] start\n";

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
const DXGI_FORMAT_R8G8B8A8_UNORM     = 28;
const DXGI_FORMAT_R32G32B32_FLOAT    = 6;
const DXGI_FORMAT_R32G32B32A32_FLOAT = 2;

const DXGI_USAGE_RENDER_TARGET_OUTPUT = 0x00000020;
const DXGI_SWAP_EFFECT_FLIP_DISCARD = 4;
const DXGI_SCALING_STRETCH = 1;

const D3D_FEATURE_LEVEL_12_0 = 0xC000;

const D3D12_COMMAND_LIST_TYPE_DIRECT = 0;
const D3D12_COMMAND_QUEUE_FLAG_NONE  = 0;
const D3D12_FENCE_FLAG_NONE          = 0;

const D3D12_DESCRIPTOR_HEAP_TYPE_RTV = 2;
const D3D12_DESCRIPTOR_HEAP_FLAG_NONE = 0;

const D3D12_RESOURCE_STATE_PRESENT       = 0;
const D3D12_RESOURCE_STATE_RENDER_TARGET = 4;

const D3D12_HEAP_TYPE_UPLOAD = 2;

const D3D12_RESOURCE_DIMENSION_BUFFER = 1;
const D3D12_TEXTURE_LAYOUT_ROW_MAJOR  = 1;
const D3D12_RESOURCE_FLAG_NONE = 0;

const D3D12_ROOT_SIGNATURE_FLAG_ALLOW_INPUT_ASSEMBLER_INPUT_LAYOUT = 0x1;
const D3D12_ROOT_SIGNATURE_VERSION_1 = 1;

const D3D12_PRIMITIVE_TOPOLOGY_TYPE_TRIANGLE = 3;
const D3D_PRIMITIVE_TOPOLOGY_TRIANGLELIST = 4;

const D3D12_INPUT_CLASSIFICATION_PER_VERTEX_DATA = 0;

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

const FRAME_COUNT = 2;

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
const VTBL_DEVICE_CREATE_COMMAND_LIST = 12;
const VTBL_DEVICE_CREATE_DESCRIPTOR_HEAP = 14;
const VTBL_DEVICE_GET_DESCRIPTOR_HANDLE_INC_SIZE = 15;
const VTBL_DEVICE_CREATE_ROOT_SIGNATURE = 16;
const VTBL_DEVICE_CREATE_RTV = 20;
const VTBL_DEVICE_CREATE_COMMITTED_RESOURCE = 27;
const VTBL_DEVICE_CREATE_FENCE = 36;

// ID3D12DescriptorHeap
const VTBL_DESCRIPTOR_HEAP_GET_CPU_HANDLE = 9;

// ID3D12CommandAllocator
const VTBL_COMMAND_ALLOCATOR_RESET = 8;

// ID3D12GraphicsCommandList
const VTBL_COMMAND_LIST_CLOSE = 9;
const VTBL_COMMAND_LIST_RESET = 10;
const VTBL_COMMAND_LIST_DRAW_INSTANCED = 12;
const VTBL_COMMAND_LIST_IA_SET_PRIMITIVE_TOPOLOGY = 20;
const VTBL_COMMAND_LIST_RS_SET_VIEWPORTS = 21;
const VTBL_COMMAND_LIST_RS_SET_SCISSOR_RECTS = 22;
const VTBL_COMMAND_LIST_RESOURCE_BARRIER = 26;
const VTBL_COMMAND_LIST_SET_ROOT_SIGNATURE = 30;
const VTBL_COMMAND_LIST_IA_SET_VERTEX_BUFFERS = 44;
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
const VTBL_RESOURCE_UNMAP = 9;
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

    typedef struct D3D12_VERTEX_BUFFER_VIEW {
        UINT64 BufferLocation;
        UINT SizeInBytes;
        UINT StrideInBytes;
    } D3D12_VERTEX_BUFFER_VIEW;

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

    typedef struct D3D12_ROOT_SIGNATURE_DESC {
        UINT NumParameters;
        void* pParameters;
        UINT NumStaticSamplers;
        void* pStaticSamplers;
        UINT Flags;
    } D3D12_ROOT_SIGNATURE_DESC;

    typedef struct D3D12_INPUT_ELEMENT_DESC {
        const char* SemanticName;
        UINT SemanticIndex;
        UINT Format;
        UINT InputSlot;
        UINT AlignedByteOffset;
        UINT InputSlotClass;
        UINT InstanceDataStepRate;
    } D3D12_INPUT_ELEMENT_DESC;

    typedef struct D3D12_INPUT_LAYOUT_DESC {
        D3D12_INPUT_ELEMENT_DESC* pInputElementDescs;
        UINT NumElements;
    } D3D12_INPUT_LAYOUT_DESC;

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

    typedef struct IUnknown {
        void** lpVtbl;
    } IUnknown;

    typedef struct ID3DBlob {
        void** lpVtbl;
    } ID3DBlob;

    typedef struct VERTEX {
        float x;
        float y;
        float z;
        float r;
        float g;
        float b;
        float a;
    } VERTEX;

    typedef HRESULT (__stdcall *ReleaseFunc)(void* pThis);
    typedef HRESULT (__stdcall *QueryInterfaceFunc)(void* pThis, const GUID* riid, void** ppvObject);

    typedef HRESULT (__stdcall *CreateDXGIFactory1Func)(const GUID* riid, void** ppFactory);
    typedef HRESULT (__stdcall *D3D12CreateDeviceFunc)(void* pAdapter, UINT MinimumFeatureLevel, const GUID* riid, void** ppDevice);
    typedef HRESULT (__stdcall *D3DCompileFunc)(
        const void* pSrcData,
        SIZE_T SrcDataSize,
        const char* pSourceName,
        const void* pDefines,
        const void* pInclude,
        const char* pEntrypoint,
        const char* pTarget,
        UINT Flags1,
        UINT Flags2,
        void** ppCode,
        void** ppErrorMsgs
    );

    typedef HRESULT (__stdcall *CreateSwapChainForHwndFunc)(
        void* pThis,
        void* pDevice,
        HWND hWnd,
        DXGI_SWAP_CHAIN_DESC1* pDesc,
        void* pFullscreenDesc,
        void* pRestrictToOutput,
        void** ppSwapChain
    );

    typedef HRESULT (__stdcall *GetBufferFunc)(void* pThis, UINT Buffer, const GUID* riid, void** ppSurface);
    typedef HRESULT (__stdcall *PresentFunc)(void* pThis, UINT SyncInterval, UINT Flags);
    typedef UINT (__stdcall *GetCurrentBackBufferIndexFunc)(void* pThis);

    typedef HRESULT (__stdcall *CreateCommandQueueFunc)(void* pThis, const D3D12_COMMAND_QUEUE_DESC* pDesc, const GUID* riid, void** ppCommandQueue);
    typedef HRESULT (__stdcall *CreateCommandAllocatorFunc)(void* pThis, UINT type, const GUID* riid, void** ppCommandAllocator);
    typedef HRESULT (__stdcall *CreateGraphicsPipelineStateFunc)(void* pThis, const D3D12_GRAPHICS_PIPELINE_STATE_DESC* pDesc, const GUID* riid, void** ppPipelineState);
    typedef HRESULT (__stdcall *CreateCommandListFunc)(void* pThis, UINT nodeMask, UINT type, void* pAllocator, void* pInitialState, const GUID* riid, void** ppCommandList);
    typedef HRESULT (__stdcall *CreateDescriptorHeapFunc)(void* pThis, const D3D12_DESCRIPTOR_HEAP_DESC* pDesc, const GUID* riid, void** ppHeap);
    typedef UINT (__stdcall *GetDescriptorHandleIncrementSizeFunc)(void* pThis, UINT type);
    typedef HRESULT (__stdcall *CreateRootSignatureFunc)(void* pThis, UINT nodeMask, const void* pBlobWithRootSignature, SIZE_T blobLengthInBytes, const GUID* riid, void** ppRootSignature);
    typedef void (__stdcall *CreateRenderTargetViewFunc)(void* pThis, void* pResource, const void* pDesc, D3D12_CPU_DESCRIPTOR_HANDLE DestDescriptor);
    typedef HRESULT (__stdcall *CreateCommittedResourceFunc)(
        void* pThis,
        const D3D12_HEAP_PROPERTIES* pHeapProperties,
        UINT HeapFlags,
        const D3D12_RESOURCE_DESC* pDesc,
        UINT InitialResourceState,
        const void* pOptimizedClearValue,
        const GUID* riidResource,
        void** ppvResource
    );
    typedef HRESULT (__stdcall *CreateFenceFunc)(void* pThis, UINT64 InitialValue, UINT Flags, const GUID* riid, void** ppFence);

    typedef void (__stdcall *GetCPUDescriptorHandleForHeapStartFunc)(void* pThis, D3D12_CPU_DESCRIPTOR_HANDLE* pRetVal);

    typedef HRESULT (__stdcall *ResetCommandAllocatorFunc)(void* pThis);

    typedef HRESULT (__stdcall *CommandListCloseFunc)(void* pThis);
    typedef HRESULT (__stdcall *CommandListResetFunc)(void* pThis, void* pAllocator, void* pInitialState);
    typedef void (__stdcall *SetGraphicsRootSignatureFunc)(void* pThis, void* pRootSignature);
    typedef void (__stdcall *RSSetViewportsFunc)(void* pThis, UINT NumViewports, const D3D12_VIEWPORT* pViewports);
    typedef void (__stdcall *RSSetScissorRectsFunc)(void* pThis, UINT NumRects, const D3D12_RECT* pRects);
    typedef void (__stdcall *ResourceBarrierFunc)(void* pThis, UINT NumBarriers, const D3D12_RESOURCE_BARRIER* pBarriers);
    typedef void (__stdcall *OMSetRenderTargetsFunc)(void* pThis, UINT NumRenderTargetDescriptors, const D3D12_CPU_DESCRIPTOR_HANDLE* pRenderTargetDescriptors, BOOL RTsSingleHandleToDescriptorRange, const void* pDepthStencilDescriptor);
    typedef void (__stdcall *ClearRenderTargetViewFunc)(void* pThis, D3D12_CPU_DESCRIPTOR_HANDLE RenderTargetView, const float* ColorRGBA, UINT NumRects, const void* pRects);
    typedef void (__stdcall *IASetPrimitiveTopologyFunc)(void* pThis, UINT Topology);
    typedef void (__stdcall *IASetVertexBuffersFunc)(void* pThis, UINT StartSlot, UINT NumViews, const D3D12_VERTEX_BUFFER_VIEW* pViews);
    typedef void (__stdcall *DrawInstancedFunc)(void* pThis, UINT VertexCountPerInstance, UINT InstanceCount, UINT StartVertexLocation, UINT StartInstanceLocation);

    typedef void (__stdcall *ExecuteCommandListsFunc)(void* pThis, UINT NumCommandLists, void** ppCommandLists);
    typedef HRESULT (__stdcall *SignalFunc)(void* pThis, void* pFence, UINT64 Value);

    typedef UINT64 (__stdcall *GetCompletedValueFunc)(void* pThis);
    typedef HRESULT (__stdcall *SetEventOnCompletionFunc)(void* pThis, UINT64 Value, void* hEvent);

    typedef HRESULT (__stdcall *MapResourceFunc)(void* pThis, UINT Subresource, const D3D12_RANGE* pReadRange, void** ppData);
    typedef void (__stdcall *UnmapResourceFunc)(void* pThis, UINT Subresource, const D3D12_RANGE* pWrittenRange);
    typedef UINT64 (__stdcall *GetGPUVirtualAddressFunc)(void* pThis);

    typedef void* (__stdcall *GetBufferPointerFunc)(void* pThis);
    typedef SIZE_T (__stdcall *GetBufferSizeFunc)(void* pThis);

    typedef void (__stdcall *EnableDebugLayerFunc)(void* pThis);

    typedef HRESULT (__stdcall *D3D12GetDebugInterfaceFunc)(const GUID* riid, void** ppvDebug);
    typedef HRESULT (__stdcall *D3D12SerializeRootSignatureFunc)(const D3D12_ROOT_SIGNATURE_DESC* pRootSignature, UINT Version, void** ppBlob, void** ppErrorBlob);
CDEF;

$d3d12Types = FFI::cdef($d3d12Cdef);

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
    if ($obj === null || (int)FFI::cast($ffi->type('UINTPTR'), $obj)->cdata === 0) {
        return;
    }
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
    $err = FFI::new('void*');

    $hr = $d3dCompile(
        FFI::addr($srcBuf[0]),
        $srcLen,
        'hello.hlsl',
        null,
        null,
        $entry,
        $target,
        D3DCOMPILE_ENABLE_STRICTNESS,
        0,
        FFI::addr($code),
        FFI::addr($err)
    );

    $ppCode = FFI::cast('void**', FFI::addr($code));
    $codeVal = $ppCode[0];

    if ($hr < 0) {
        $msg = 'D3DCompile failed';
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
        throw new RuntimeException('D3DCompile returned null code blob');
    }

    return FFI::cast($ffi->type('ID3DBlob*'), $codeVal);
}

// Window setup
$hInstance = $kernel32->GetModuleHandleW(null);

$user32DllName = wstr("user32.dll");
$hUser32 = $kernel32->LoadLibraryW(FFI::cast('uint16_t*', FFI::addr($user32DllName[0])));
$procName = astr("DefWindowProcW");
$defWndProcAddr = $kernel32->GetProcAddress($hUser32, FFI::cast('char*', FFI::addr($procName[0])));

$className  = wstr("PHPD3D12Window");
$windowName = wstr("Hello, World! (PHP DirectX12)");

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
if ($atom === 0) {
    $err = $kernel32->GetLastError();
    echo "RegisterClassExW failed (error: $err)\n";
    exit(1);
}

$hwnd = $user32->CreateWindowExW(
    0,
    FFI::cast('uint16_t*', FFI::addr($className[0])),
    FFI::cast('uint16_t*', FFI::addr($windowName[0])),
    WS_OVERLAPPEDWINDOW,
    CW_USEDEFAULT,
    CW_USEDEFAULT,
    640,
    480,
    null,
    null,
    $hInstance,
    null
);

if ($hwnd === null) {
    $err = $kernel32->GetLastError();
    echo "CreateWindowExW failed (error: $err)\n";
    exit(1);
}

$user32->ShowWindow($hwnd, SW_SHOWDEFAULT);
$user32->UpdateWindow($hwnd);

echo "[PHPD3D12] window created and shown\n";

// Load d3d12, dxgi, and d3dcompiler
$d3d12DllName = wstr('d3d12.dll');
$hD3D12 = $kernel32->LoadLibraryW(FFI::cast('uint16_t*', FFI::addr($d3d12DllName[0])));
if ($hD3D12 === null) {
    echo "Failed to load d3d12.dll\n";
    exit(1);
}

$dxgiDllName = wstr('dxgi.dll');
$hDxgi = $kernel32->LoadLibraryW(FFI::cast('uint16_t*', FFI::addr($dxgiDllName[0])));
if ($hDxgi === null) {
    echo "Failed to load dxgi.dll\n";
    exit(1);
}

$d3dcompilerName = wstr('d3dcompiler_47.dll');
$hCompiler = $kernel32->LoadLibraryW(FFI::cast('uint16_t*', FFI::addr($d3dcompilerName[0])));
if ($hCompiler === null) {
    $d3dcompilerName = wstr('d3dcompiler_43.dll');
    $hCompiler = $kernel32->LoadLibraryW(FFI::cast('uint16_t*', FFI::addr($d3dcompilerName[0])));
}
if ($hCompiler === null) {
    echo "Failed to load d3dcompiler\n";
    exit(1);
}

echo "[PHPD3D12] libraries loaded\n";

// Enable D3D12 debug layer (if available)
$procName = astr('D3D12GetDebugInterface');
$pfnGetDebug = $kernel32->GetProcAddress($hD3D12, FFI::cast('char*', FFI::addr($procName[0])));
$ppDebug = FFI::new('void*');
$hr = -1;
if ($pfnGetDebug !== null) {
    $getDebug = FFI::cast($d3d12Types->type('D3D12GetDebugInterfaceFunc'), $pfnGetDebug);
    $iidDebug = guid_from_string('{344488b7-6846-474b-b989-f027448245e0}', $d3d12Types);
    $hr = $getDebug(FFI::addr($iidDebug), FFI::addr($ppDebug));
}
if ($hr >= 0) {
    $debugPtr = out_ptr($d3d12Types, $ppDebug);
    if ($debugPtr !== null) {
        $debug = FFI::cast($d3d12Types->type('IUnknown*'), $debugPtr);
        $enableDebug = FFI::cast($d3d12Types->type('EnableDebugLayerFunc'), $debug->lpVtbl[3]);
        $enableDebug($debug);
        com_release($d3d12Types, $debug);
        echo "[PHPD3D12] debug layer enabled\n";
    } else {
        echo "[PHPD3D12] debug layer not available (null ptr)\n";
    }
} else {
    echo "[PHPD3D12] debug layer not available (hr=0x" . dechex($hr & 0xffffffff) . ")\n";
}

$procName = astr('CreateDXGIFactory1');
$pfnCreateFactory = $kernel32->GetProcAddress($hDxgi, FFI::cast('char*', FFI::addr($procName[0])));
if ($pfnCreateFactory === null) {
    echo "GetProcAddress for CreateDXGIFactory1 failed\n";
    exit(1);
}
$createFactory = FFI::cast($d3d12Types->type('CreateDXGIFactory1Func'), $pfnCreateFactory);

$procName = astr('D3D12CreateDevice');
$pfnCreateDevice = $kernel32->GetProcAddress($hD3D12, FFI::cast('char*', FFI::addr($procName[0])));
if ($pfnCreateDevice === null) {
    echo "GetProcAddress for D3D12CreateDevice failed\n";
    exit(1);
}
$createDevice = FFI::cast($d3d12Types->type('D3D12CreateDeviceFunc'), $pfnCreateDevice);

$procName = astr('D3D12SerializeRootSignature');
$pfnSerializeRS = $kernel32->GetProcAddress($hD3D12, FFI::cast('char*', FFI::addr($procName[0])));
if ($pfnSerializeRS === null) {
    echo "GetProcAddress for D3D12SerializeRootSignature failed\n";
    exit(1);
}
$serializeRootSig = FFI::cast($d3d12Types->type('D3D12SerializeRootSignatureFunc'), $pfnSerializeRS);

$procName = astr('D3DCompile');
$pfnD3DCompile = $kernel32->GetProcAddress($hCompiler, FFI::cast('char*', FFI::addr($procName[0])));
if ($pfnD3DCompile === null) {
    echo "GetProcAddress for D3DCompile failed\n";
    exit(1);
}
$d3dCompile = FFI::cast($d3d12Types->type('D3DCompileFunc'), $pfnD3DCompile);

    // Create DXGI factory
    $iidFactory = guid_from_string('{1bc6ea02-ef36-464f-bf0c-21ca39e5168a}', $d3d12Types);
    $ppFactory = FFI::new('void*');
    $hr = $createFactory(FFI::addr($iidFactory), FFI::addr($ppFactory));
    if ($hr < 0) {
        echo "CreateDXGIFactory1 failed (hr=0x" . dechex($hr & 0xffffffff) . ")\n";
        exit(1);
    }
    $gFactory = FFI::cast($d3d12Types->type('IUnknown*'), out_ptr($d3d12Types, $ppFactory));

    echo "[PHPD3D12] factory created\n";

    // Create D3D12 device
    $iidDevice = guid_from_string('{189819f1-1db6-4b57-be54-1821339b85f7}', $d3d12Types);
    $ppDevice = FFI::new('void*');
    $hr = $createDevice(null, D3D_FEATURE_LEVEL_12_0, FFI::addr($iidDevice), FFI::addr($ppDevice));
    if ($hr < 0) {
        echo "D3D12CreateDevice failed (hr=0x" . dechex($hr & 0xffffffff) . ")\n";
        exit(1);
    }
    $gDevice = FFI::cast($d3d12Types->type('IUnknown*'), out_ptr($d3d12Types, $ppDevice));

    echo "[PHPD3D12] device created\n";

    // Create command queue
    $cqDesc = $d3d12Types->new('D3D12_COMMAND_QUEUE_DESC');
    $cqDesc->Type = D3D12_COMMAND_LIST_TYPE_DIRECT;
    $cqDesc->Priority = 0;
    $cqDesc->Flags = D3D12_COMMAND_QUEUE_FLAG_NONE;
    $cqDesc->NodeMask = 0;

    $iidQueue = guid_from_string('{0ec870a6-5d7e-4c22-8cfc-5baae07616ed}', $d3d12Types);
    $ppQueue = FFI::new('void*');
    $createQueue = FFI::cast($d3d12Types->type('CreateCommandQueueFunc'), $gDevice->lpVtbl[VTBL_DEVICE_CREATE_COMMAND_QUEUE]);
    $hr = $createQueue($gDevice, FFI::addr($cqDesc), FFI::addr($iidQueue), FFI::addr($ppQueue));
    if ($hr < 0) {
        echo "CreateCommandQueue failed (hr=0x" . dechex($hr & 0xffffffff) . ")\n";
        exit(1);
    }
    $gCommandQueue = FFI::cast($d3d12Types->type('IUnknown*'), out_ptr($d3d12Types, $ppQueue));

    echo "[PHPD3D12] command queue created\n";

    // Swap chain
    $rect = $user32->new('RECT');
    $user32->GetClientRect($hwnd, FFI::addr($rect));
    $width = max(1, $rect->right - $rect->left);
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
    if ($hr < 0) {
        echo "CreateSwapChainForHwnd failed (hr=0x" . dechex($hr & 0xffffffff) . ")\n";
        exit(1);
    }

    echo "[PHPD3D12] swap chain created\n";

    $swapTemp = FFI::cast($d3d12Types->type('IUnknown*'), out_ptr($d3d12Types, $ppSwapTemp));
    $iidSwap3 = guid_from_string('{94d99bdb-f1f8-4ab0-b236-7da0170edab1}', $d3d12Types);
    $ppSwap3 = FFI::new('void*');
    $qi = FFI::cast($d3d12Types->type('QueryInterfaceFunc'), $swapTemp->lpVtbl[VTBL_QUERY_INTERFACE]);
    $hr = $qi($swapTemp, FFI::addr($iidSwap3), FFI::addr($ppSwap3));
    com_release($d3d12Types, $swapTemp);
    if ($hr < 0) {
        echo "QueryInterface IDXGISwapChain3 failed (hr=0x" . dechex($hr & 0xffffffff) . ")\n";
        exit(1);
    }
    $gSwapChain = FFI::cast($d3d12Types->type('IUnknown*'), out_ptr($d3d12Types, $ppSwap3));

    $getFrameIndex = FFI::cast($d3d12Types->type('GetCurrentBackBufferIndexFunc'), $gSwapChain->lpVtbl[VTBL_SWAP_GET_CURRENT_BACKBUFFER_INDEX]);
    $gFrameIndex = $getFrameIndex($gSwapChain);

    echo "[PHPD3D12] swap chain queried\n";

    // Create RTV heap
    $rtvHeapDesc = $d3d12Types->new('D3D12_DESCRIPTOR_HEAP_DESC');
    $rtvHeapDesc->Type = D3D12_DESCRIPTOR_HEAP_TYPE_RTV;
    $rtvHeapDesc->NumDescriptors = FRAME_COUNT;
    $rtvHeapDesc->Flags = D3D12_DESCRIPTOR_HEAP_FLAG_NONE;
    $rtvHeapDesc->NodeMask = 0;

    $iidHeap = guid_from_string('{8efb471d-616c-4f49-90f7-127bb763fa51}', $d3d12Types);
    $ppHeap = FFI::new('void*');
    $createHeap = FFI::cast($d3d12Types->type('CreateDescriptorHeapFunc'), $gDevice->lpVtbl[VTBL_DEVICE_CREATE_DESCRIPTOR_HEAP]);
    $hr = $createHeap($gDevice, FFI::addr($rtvHeapDesc), FFI::addr($iidHeap), FFI::addr($ppHeap));
    if ($hr < 0) {
        echo "CreateDescriptorHeap failed (hr=0x" . dechex($hr & 0xffffffff) . ")\n";
        exit(1);
    }
    $gRtvHeap = FFI::cast($d3d12Types->type('IUnknown*'), out_ptr($d3d12Types, $ppHeap));

    echo "[PHPD3D12] RTV heap created\n";

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
        if ($hr < 0) {
            echo "GetBuffer($i) failed (hr=0x" . dechex($hr & 0xffffffff) . ")\n";
            exit(1);
        }

        $gRenderTargets[$i] = FFI::cast($d3d12Types->type('IUnknown*'), out_ptr($d3d12Types, $ppBuffer));
        $createRtv = FFI::cast($d3d12Types->type('CreateRenderTargetViewFunc'), $gDevice->lpVtbl[VTBL_DEVICE_CREATE_RTV]);
        $handle = $d3d12Types->new('D3D12_CPU_DESCRIPTOR_HANDLE');
        $handle->ptr = $rtvHandle->ptr + $i * $rtvDescriptorSize;
        $createRtv($gDevice, $gRenderTargets[$i], null, $handle);
    }

    echo "[PHPD3D12] RTVs created\n";

    // Create command allocators
    $iidAllocator = guid_from_string('{6102dee4-af59-4b09-b999-b44d73f09b24}', $d3d12Types);
    $gCommandAllocators = [];
    $createAllocator = FFI::cast($d3d12Types->type('CreateCommandAllocatorFunc'), $gDevice->lpVtbl[VTBL_DEVICE_CREATE_COMMAND_ALLOCATOR]);
    for ($i = 0; $i < FRAME_COUNT; $i++) {
        $ppAllocator = FFI::new('void*');
        $hr = $createAllocator($gDevice, D3D12_COMMAND_LIST_TYPE_DIRECT, FFI::addr($iidAllocator), FFI::addr($ppAllocator));
        if ($hr < 0) {
            echo "CreateCommandAllocator failed (hr=0x" . dechex($hr & 0xffffffff) . ")\n";
            exit(1);
        }
        $gCommandAllocators[$i] = FFI::cast($d3d12Types->type('IUnknown*'), out_ptr($d3d12Types, $ppAllocator));
    }

    echo "[PHPD3D12] command allocators created\n";

    // Root signature
    $rsDesc = $d3d12Types->new('D3D12_ROOT_SIGNATURE_DESC');
    FFI::memset(FFI::addr($rsDesc), 0, FFI::sizeof($rsDesc));
    $rsDesc->NumParameters = 0;
    $rsDesc->pParameters = null;
    $rsDesc->NumStaticSamplers = 0;
    $rsDesc->pStaticSamplers = null;
    $rsDesc->Flags = D3D12_ROOT_SIGNATURE_FLAG_ALLOW_INPUT_ASSEMBLER_INPUT_LAYOUT;

    echo "[PHPD3D12] serialize root signature\n";

    $rsBlob = FFI::new('void*');
    $errBlob = FFI::new('void*');
    $hr = $serializeRootSig(FFI::addr($rsDesc), D3D12_ROOT_SIGNATURE_VERSION_1, FFI::addr($rsBlob), FFI::addr($errBlob));
    echo "[PHPD3D12] serialize root signature hr=0x" . dechex($hr & 0xffffffff) . "\n";
    echo "[PHPD3D12] serialize root signature post\n";
    if ($hr < 0) {
        $msg = 'D3D12SerializeRootSignature failed';
        $ppErr = FFI::cast('void**', FFI::addr($errBlob));
        $errVal = $ppErr[0];
        if ($errVal !== null) {
            $blob = FFI::cast($d3d12Types->type('ID3DBlob*'), $errVal);
            $ptr = blob_ptr($d3d12Types, $blob);
            $size = blob_size($d3d12Types, $blob);
            if ($ptr && $size > 0) {
                $msg = FFI::string($ptr, $size);
            }
            com_release($d3d12Types, $blob);
        }
        throw new RuntimeException($msg);
    }
    $ppErr = FFI::cast('void**', FFI::addr($errBlob));
    $errVal = out_ptr($d3d12Types, $errBlob);
    if ($errVal !== null) {
        $blob = FFI::cast($d3d12Types->type('ID3DBlob*'), $errVal);
        com_release($d3d12Types, $blob);
    }

    $iidRootSig = guid_from_string('{c54a6b66-72df-4ee8-8be5-a946a1429214}', $d3d12Types);
    $ppRootSig = FFI::new('void*');
    $createRootSig = FFI::cast($d3d12Types->type('CreateRootSignatureFunc'), $gDevice->lpVtbl[VTBL_DEVICE_CREATE_ROOT_SIGNATURE]);
    echo "[PHPD3D12] create root signature\n";
    $ppRsBlob = FFI::cast('void**', FFI::addr($rsBlob));
    $rsBlobVal = out_ptr($d3d12Types, $rsBlob);
    if ($rsBlobVal === null) {
        echo "[PHPD3D12] rsBlob is null\n";
        exit(1);
    }
    $rsBlobObj = FFI::cast($d3d12Types->type('ID3DBlob*'), $rsBlobVal);
    $rsPtr = blob_ptr($d3d12Types, $rsBlobObj);
    $rsSize = blob_size($d3d12Types, $rsBlobObj);
    echo "[PHPD3D12] root sig blob size=" . $rsSize . "\n";
    $hr = $createRootSig(
        $gDevice,
        0,
        $rsPtr,
        $rsSize,
        FFI::addr($iidRootSig),
        FFI::addr($ppRootSig)
    );
    echo "[PHPD3D12] create root signature hr=0x" . dechex($hr & 0xffffffff) . "\n";
    com_release($d3d12Types, $rsBlobObj);
    if ($hr < 0) {
        echo "CreateRootSignature failed (hr=0x" . dechex($hr & 0xffffffff) . ")\n";
        exit(1);
    }
    $gRootSignature = FFI::cast($d3d12Types->type('IUnknown*'), out_ptr($d3d12Types, $ppRootSig));
    $gRootSignature = FFI::cast($d3d12Types->type('IUnknown*'), out_ptr($d3d12Types, $ppRootSig));

    echo "[PHPD3D12] root signature created\n";

    // Compile shaders
    $hlslPath = __DIR__ . DIRECTORY_SEPARATOR . 'hello.hlsl';
    $hlslSource = file_get_contents($hlslPath);
    if ($hlslSource === false) {
        echo "Failed to read hello.hlsl\n";
        exit(1);
    }

    $vsBlob = compile_hlsl($d3d12Types, $d3dCompile, $hlslSource, 'VSMain', 'vs_5_0');
    $psBlob = compile_hlsl($d3d12Types, $d3dCompile, $hlslSource, 'PSMain', 'ps_5_0');

    echo "[PHPD3D12] shaders compiled\n";

    // Create PSO
    $psoDesc = $d3d12Types->new('D3D12_GRAPHICS_PIPELINE_STATE_DESC');
    FFI::memset(FFI::addr($psoDesc), 0, FFI::sizeof($psoDesc));

    $psoDesc->pRootSignature = FFI::cast('void*', $gRootSignature);
    $psoDesc->VS->pShaderBytecode = blob_ptr($d3d12Types, $vsBlob);
    $psoDesc->VS->BytecodeLength = blob_size($d3d12Types, $vsBlob);
    $psoDesc->PS->pShaderBytecode = blob_ptr($d3d12Types, $psBlob);
    $psoDesc->PS->BytecodeLength = blob_size($d3d12Types, $psBlob);

    echo "[PHPD3D12] setup PSO states\n";

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
    $psoDesc->DepthStencilState->DepthWriteMask = D3D12_DEPTH_WRITE_MASK_ALL;
    $psoDesc->DepthStencilState->DepthFunc = D3D12_COMPARISON_FUNC_LESS;

    $position = astr('POSITION');
    $color = astr('COLOR');
    $inputLayout = $d3d12Types->new('D3D12_INPUT_ELEMENT_DESC[2]');
    $inputLayout[0]->SemanticName = FFI::cast('char*', FFI::addr($position[0]));
    $inputLayout[0]->SemanticIndex = 0;
    $inputLayout[0]->Format = DXGI_FORMAT_R32G32B32_FLOAT;
    $inputLayout[0]->InputSlot = 0;
    $inputLayout[0]->AlignedByteOffset = 0;
    $inputLayout[0]->InputSlotClass = D3D12_INPUT_CLASSIFICATION_PER_VERTEX_DATA;
    $inputLayout[0]->InstanceDataStepRate = 0;

    $inputLayout[1]->SemanticName = FFI::cast('char*', FFI::addr($color[0]));
    $inputLayout[1]->SemanticIndex = 0;
    $inputLayout[1]->Format = DXGI_FORMAT_R32G32B32A32_FLOAT;
    $inputLayout[1]->InputSlot = 0;
    $inputLayout[1]->AlignedByteOffset = 12;
    $inputLayout[1]->InputSlotClass = D3D12_INPUT_CLASSIFICATION_PER_VERTEX_DATA;
    $inputLayout[1]->InstanceDataStepRate = 0;

    $psoDesc->InputLayout->pInputElementDescs = FFI::addr($inputLayout[0]);
    $psoDesc->InputLayout->NumElements = 2;
    $psoDesc->PrimitiveTopologyType = D3D12_PRIMITIVE_TOPOLOGY_TYPE_TRIANGLE;
    $psoDesc->NumRenderTargets = 1;
    $psoDesc->RTVFormats[0] = DXGI_FORMAT_R8G8B8A8_UNORM;
    $psoDesc->SampleDesc->Count = 1;
    $psoDesc->SampleDesc->Quality = 0;

    echo "[PHPD3D12] setup PSO input layout\n";

    echo "[PHPD3D12] prepare PSO create\n";
    $iidPso = guid_from_string('{765a30f3-f624-4c6f-a828-ace948622445}', $d3d12Types);
    $ppPso = FFI::new('void*');
    $createPso = FFI::cast($d3d12Types->type('CreateGraphicsPipelineStateFunc'), $gDevice->lpVtbl[VTBL_DEVICE_CREATE_GRAPHICS_PSO]);
    echo "[PHPD3D12] create PSO\n";
    $hr = $createPso($gDevice, FFI::addr($psoDesc), FFI::addr($iidPso), FFI::addr($ppPso));
    echo "[PHPD3D12] create PSO hr=0x" . dechex($hr & 0xffffffff) . "\n";
    if ($hr < 0) {
        echo "CreateGraphicsPipelineState failed (hr=0x" . dechex($hr & 0xffffffff) . ")\n";
        exit(1);
    }
    $gPipelineState = FFI::cast($d3d12Types->type('IUnknown*'), out_ptr($d3d12Types, $ppPso));

    com_release($d3d12Types, $vsBlob);
    com_release($d3d12Types, $psBlob);

    echo "[PHPD3D12] PSO created\n";

    // Create command list
    $iidCmdList = guid_from_string('{5b160d0f-ac1b-4185-8ba8-b3ae42a5a455}', $d3d12Types);
    $ppCmdList = FFI::new('void*');
    $createCmdList = FFI::cast($d3d12Types->type('CreateCommandListFunc'), $gDevice->lpVtbl[VTBL_DEVICE_CREATE_COMMAND_LIST]);
    echo "[PHPD3D12] create command list (frameIndex=$gFrameIndex)\n";
    $hr = $createCmdList($gDevice, 0, D3D12_COMMAND_LIST_TYPE_DIRECT, $gCommandAllocators[$gFrameIndex], $gPipelineState, FFI::addr($iidCmdList), FFI::addr($ppCmdList));
    echo "[PHPD3D12] create command list hr=0x" . dechex($hr & 0xffffffff) . "\n";
    if ($hr < 0) {
        echo "CreateCommandList failed (hr=0x" . dechex($hr & 0xffffffff) . ")\n";
        exit(1);
    }
    $gCommandList = FFI::cast($d3d12Types->type('IUnknown*'), out_ptr($d3d12Types, $ppCmdList));

    $closeCmdList = FFI::cast($d3d12Types->type('CommandListCloseFunc'), $gCommandList->lpVtbl[VTBL_COMMAND_LIST_CLOSE]);
    $closeCmdList($gCommandList);

    echo "[PHPD3D12] command list created\n";

    // Vertex buffer
    $verts = $d3d12Types->new('VERTEX[3]');
    $verts[0]->x = 0.0;  $verts[0]->y = 0.5;  $verts[0]->z = 0.5;  $verts[0]->r = 1.0; $verts[0]->g = 0.0; $verts[0]->b = 0.0; $verts[0]->a = 1.0;
    $verts[1]->x = 0.5;  $verts[1]->y = -0.5; $verts[1]->z = 0.5;  $verts[1]->r = 0.0; $verts[1]->g = 1.0; $verts[1]->b = 0.0; $verts[1]->a = 1.0;
    $verts[2]->x = -0.5; $verts[2]->y = -0.5; $verts[2]->z = 0.5;  $verts[2]->r = 0.0; $verts[2]->g = 0.0; $verts[2]->b = 1.0; $verts[2]->a = 1.0;

    $vertexBufferSize = FFI::sizeof($verts);

    $heapProps = $d3d12Types->new('D3D12_HEAP_PROPERTIES');
    $heapProps->Type = D3D12_HEAP_TYPE_UPLOAD;
    $heapProps->CPUPageProperty = 0;
    $heapProps->MemoryPoolPreference = 0;
    $heapProps->CreationNodeMask = 1;
    $heapProps->VisibleNodeMask = 1;

    $resDesc = $d3d12Types->new('D3D12_RESOURCE_DESC');
    $resDesc->Dimension = D3D12_RESOURCE_DIMENSION_BUFFER;
    $resDesc->Alignment = 0;
    $resDesc->Width = $vertexBufferSize;
    $resDesc->Height = 1;
    $resDesc->DepthOrArraySize = 1;
    $resDesc->MipLevels = 1;
    $resDesc->Format = 0;
    $resDesc->SampleDesc->Count = 1;
    $resDesc->SampleDesc->Quality = 0;
    $resDesc->Layout = D3D12_TEXTURE_LAYOUT_ROW_MAJOR;
    $resDesc->Flags = D3D12_RESOURCE_FLAG_NONE;

    $ppVertexBuffer = FFI::new('void*');
    $createResource = FFI::cast($d3d12Types->type('CreateCommittedResourceFunc'), $gDevice->lpVtbl[VTBL_DEVICE_CREATE_COMMITTED_RESOURCE]);
    $hr = $createResource(
        $gDevice,
        FFI::addr($heapProps),
        0,
        FFI::addr($resDesc),
        0,
        null,
        FFI::addr($iidResource),
        FFI::addr($ppVertexBuffer)
    );
    if ($hr < 0) {
        echo "CreateCommittedResource failed (hr=0x" . dechex($hr & 0xffffffff) . ")\n";
        exit(1);
    }
    $gVertexBuffer = FFI::cast($d3d12Types->type('IUnknown*'), out_ptr($d3d12Types, $ppVertexBuffer));

    $map = FFI::cast($d3d12Types->type('MapResourceFunc'), $gVertexBuffer->lpVtbl[VTBL_RESOURCE_MAP]);
    $mapped = FFI::new('void*');
    $readRange = $d3d12Types->new('D3D12_RANGE');
    $readRange->Begin = 0;
    $readRange->End = 0;
    $hr = $map($gVertexBuffer, 0, FFI::addr($readRange), FFI::addr($mapped));
    if ($hr < 0) {
        echo "Map failed (hr=0x" . dechex($hr & 0xffffffff) . ")\n";
        exit(1);
    }

    FFI::memcpy($mapped, FFI::addr($verts[0]), $vertexBufferSize);

    $unmap = FFI::cast($d3d12Types->type('UnmapResourceFunc'), $gVertexBuffer->lpVtbl[VTBL_RESOURCE_UNMAP]);
    $unmap($gVertexBuffer, 0, null);

    $getGpuVA = FFI::cast($d3d12Types->type('GetGPUVirtualAddressFunc'), $gVertexBuffer->lpVtbl[VTBL_RESOURCE_GET_GPU_VA]);
    $gpuVA = $getGpuVA($gVertexBuffer);

    $gVertexBufferView = $d3d12Types->new('D3D12_VERTEX_BUFFER_VIEW');
    $gVertexBufferView->BufferLocation = $gpuVA;
    $gVertexBufferView->SizeInBytes = $vertexBufferSize;
    $gVertexBufferView->StrideInBytes = FFI::sizeof($verts[0]);

    echo "[PHPD3D12] vertex buffer created\n";

    // Fence
    $iidFence = guid_from_string('{0a753dcf-c4d8-4b91-adf6-be5a60d95a76}', $d3d12Types);
    $ppFence = FFI::new('void*');
    $createFence = FFI::cast($d3d12Types->type('CreateFenceFunc'), $gDevice->lpVtbl[VTBL_DEVICE_CREATE_FENCE]);
    $hr = $createFence($gDevice, 0, D3D12_FENCE_FLAG_NONE, FFI::addr($iidFence), FFI::addr($ppFence));
    if ($hr < 0) {
        echo "CreateFence failed (hr=0x" . dechex($hr & 0xffffffff) . ")\n";
        exit(1);
    }
    $gFence = FFI::cast($d3d12Types->type('IUnknown*'), out_ptr($d3d12Types, $ppFence));
    $gFenceValues = [1, 1];

    echo "[PHPD3D12] fence created\n";

    $fenceEvent = $kernel32->CreateEventW(null, 0, 0, null);
    if ($fenceEvent === null) {
        echo "CreateEventW failed\n";
        exit(1);
    }

    echo "[PHPD3D12] entering render loop\n";

    function wait_for_previous_frame(FFI $ffi, FFI\CData $gSwapChain, int &$frameIndex): void
    {
        // Simply get the current frame index
        $getFrameIndex = FFI::cast($ffi->type('GetCurrentBackBufferIndexFunc'), $gSwapChain->lpVtbl[VTBL_SWAP_GET_CURRENT_BACKBUFFER_INDEX]);
        $frameIndex = $getFrameIndex($gSwapChain);
    }

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

        // Get current frame index
        wait_for_previous_frame($d3d12Types, $gSwapChain, $gFrameIndex);

        $resetAllocator = FFI::cast($d3d12Types->type('ResetCommandAllocatorFunc'), $gCommandAllocators[$gFrameIndex]->lpVtbl[VTBL_COMMAND_ALLOCATOR_RESET]);
        $resetAllocator($gCommandAllocators[$gFrameIndex]);

        $resetCmdList = FFI::cast($d3d12Types->type('CommandListResetFunc'), $gCommandList->lpVtbl[VTBL_COMMAND_LIST_RESET]);
        $resetCmdList($gCommandList, $gCommandAllocators[$gFrameIndex], $gPipelineState);

        $setRootSig = FFI::cast($d3d12Types->type('SetGraphicsRootSignatureFunc'), $gCommandList->lpVtbl[VTBL_COMMAND_LIST_SET_ROOT_SIGNATURE]);
        $setRootSig($gCommandList, $gRootSignature);

        $viewport = $d3d12Types->new('D3D12_VIEWPORT');
        $viewport->TopLeftX = 0.0;
        $viewport->TopLeftY = 0.0;
        $viewport->Width = (float)$width;
        $viewport->Height = (float)$height;
        $viewport->MinDepth = 0.0;
        $viewport->MaxDepth = 1.0;

        $rsSetViewports = FFI::cast($d3d12Types->type('RSSetViewportsFunc'), $gCommandList->lpVtbl[VTBL_COMMAND_LIST_RS_SET_VIEWPORTS]);
        $rsSetViewports($gCommandList, 1, FFI::addr($viewport));

        $scissor = $d3d12Types->new('D3D12_RECT');
        $scissor->left = 0;
        $scissor->top = 0;
        $scissor->right = $width;
        $scissor->bottom = $height;

        $rsSetScissor = FFI::cast($d3d12Types->type('RSSetScissorRectsFunc'), $gCommandList->lpVtbl[VTBL_COMMAND_LIST_RS_SET_SCISSOR_RECTS]);
        $rsSetScissor($gCommandList, 1, FFI::addr($scissor));

        $barrier = $d3d12Types->new('D3D12_RESOURCE_BARRIER');
        $barrier->Type = D3D12_RESOURCE_BARRIER_TYPE_TRANSITION;
        $barrier->Flags = D3D12_RESOURCE_BARRIER_FLAG_NONE;
        $barrier->u->Transition->pResource = FFI::cast('void*', $gRenderTargets[$gFrameIndex]);
        $barrier->u->Transition->Subresource = D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES;
        $barrier->u->Transition->StateBefore = D3D12_RESOURCE_STATE_PRESENT;
        $barrier->u->Transition->StateAfter = D3D12_RESOURCE_STATE_RENDER_TARGET;

        $resourceBarrier = FFI::cast($d3d12Types->type('ResourceBarrierFunc'), $gCommandList->lpVtbl[VTBL_COMMAND_LIST_RESOURCE_BARRIER]);
        $resourceBarrier($gCommandList, 1, FFI::addr($barrier));

        $rtv = $d3d12Types->new('D3D12_CPU_DESCRIPTOR_HANDLE');
        $getCpuHandle($gRtvHeap, FFI::addr($rtv));
        $rtv->ptr += $gFrameIndex * $rtvDescriptorSize;

        $omSet = FFI::cast($d3d12Types->type('OMSetRenderTargetsFunc'), $gCommandList->lpVtbl[VTBL_COMMAND_LIST_OM_SET_RENDER_TARGETS]);
        $omSet($gCommandList, 1, FFI::addr($rtv), 0, null);

        $clearColor = $d3d12Types->new('float[4]');
        $clearColor[0] = 1.0;
        $clearColor[1] = 1.0;
        $clearColor[2] = 1.0;
        $clearColor[3] = 1.0;

        $clearRtv = FFI::cast($d3d12Types->type('ClearRenderTargetViewFunc'), $gCommandList->lpVtbl[VTBL_COMMAND_LIST_CLEAR_RTV]);
        $clearRtv($gCommandList, $rtv, FFI::addr($clearColor[0]), 0, null);

        $setTopo = FFI::cast($d3d12Types->type('IASetPrimitiveTopologyFunc'), $gCommandList->lpVtbl[VTBL_COMMAND_LIST_IA_SET_PRIMITIVE_TOPOLOGY]);
        $setTopo($gCommandList, D3D_PRIMITIVE_TOPOLOGY_TRIANGLELIST);

        $setVB = FFI::cast($d3d12Types->type('IASetVertexBuffersFunc'), $gCommandList->lpVtbl[VTBL_COMMAND_LIST_IA_SET_VERTEX_BUFFERS]);
        $setVB($gCommandList, 0, 1, FFI::addr($gVertexBufferView));

        $draw = FFI::cast($d3d12Types->type('DrawInstancedFunc'), $gCommandList->lpVtbl[VTBL_COMMAND_LIST_DRAW_INSTANCED]);
        $draw($gCommandList, 3, 1, 0, 0);

        $barrier->u->Transition->StateBefore = D3D12_RESOURCE_STATE_RENDER_TARGET;
        $barrier->u->Transition->StateAfter = D3D12_RESOURCE_STATE_PRESENT;
        $resourceBarrier($gCommandList, 1, FFI::addr($barrier));

        $closeCmdList = FFI::cast($d3d12Types->type('CommandListCloseFunc'), $gCommandList->lpVtbl[VTBL_COMMAND_LIST_CLOSE]);
        $closeCmdList($gCommandList);

        $cmdLists = $d3d12Types->new('void*[1]');
        $cmdLists[0] = FFI::cast('void*', $gCommandList);
        $executeLists = FFI::cast($d3d12Types->type('ExecuteCommandListsFunc'), $gCommandQueue->lpVtbl[VTBL_COMMAND_QUEUE_EXECUTE_LISTS]);
        $executeLists($gCommandQueue, 1, FFI::addr($cmdLists[0]));

        // Signal fence for this frame (after execute, before present)
        $signal = FFI::cast($d3d12Types->type('SignalFunc'), $gCommandQueue->lpVtbl[VTBL_COMMAND_QUEUE_SIGNAL]);
        $signal($gCommandQueue, $gFence, $gFenceValues[$gFrameIndex]);
        $gFenceValues[$gFrameIndex]++;

        $present = FFI::cast($d3d12Types->type('PresentFunc'), $gSwapChain->lpVtbl[VTBL_SWAP_PRESENT]);
        $present($gSwapChain, 1, 0);

        $kernel32->Sleep(1);
    }

    try {
        wait_for_previous_frame($d3d12Types, $gSwapChain, $gFrameIndex);
    } catch (Throwable $e) {
    }

    $kernel32->CloseHandle($fenceEvent);

    com_release($d3d12Types, $gFence);
    com_release($d3d12Types, $gVertexBuffer);
    com_release($d3d12Types, $gPipelineState);
    com_release($d3d12Types, $gRootSignature);
    com_release($d3d12Types, $gCommandList);
    foreach ($gCommandAllocators as $allocator) {
        com_release($d3d12Types, $allocator);
    }
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
