// =============================================================================
// DirectX Raytracing (DXR) - Triangle Sample (C)
// =============================================================================
// Minimal DXR sample in pure C: renders a single triangle using raytracing.
//
// Requirements:
//   - Windows 10 Version 1809+
//   - Visual Studio 2019/2022 (Developer Command Prompt)
//   - Windows SDK 10.0.20348.0+
//   - DXR-capable GPU (NVIDIA RTX / AMD RDNA2+) or WARP (software fallback)
//   - dxcompiler.dll and dxil.dll in PATH or exe directory
//   - hello.hlsl in the exe directory
//
// Build (Developer Command Prompt for VS 2022):
//   cl /TC hello.c /link d3d12.lib dxgi.lib dxguid.lib user32.lib ole32.lib /SUBSYSTEM:WINDOWS
//
// =============================================================================

#define COBJMACROS
#define WIN32_LEAN_AND_MEAN
#define NOMINMAX
#define UNICODE
#define _UNICODE
#include <windows.h>
#include <d3d12.h>
#include <d3d12sdklayers.h>
#include <dxgi1_6.h>
#include <math.h>
#include <string.h>
#include <stdio.h>

// =============================================================================
// Constants
// =============================================================================
#define WIDTH       800
#define HEIGHT      600
#define FRAME_COUNT 2
#define PI          3.14159265358979323846f

// =============================================================================
// GUIDs
// =============================================================================
// D3D12/DXGI GUIDs: declared in d3d12.h/dxgi1_6.h as EXTERN_C, defined in dxguid.lib.
// We only manually define GUIDs that are NOT in the standard headers (DXC).

// DXC GUIDs (not in Windows SDK headers)
static const GUID CLSID_DxcUtils_     = {0x6245D6AF,0x66E0,0x48FD,{0x80,0xB4,0x4D,0x27,0x17,0x96,0x74,0x8C}};
static const GUID CLSID_DxcCompiler_  = {0x73e22d93,0xe6ce,0x47f3,{0xb5,0xbf,0xf0,0x66,0x4f,0x39,0xc1,0xb0}};
static const GUID IID_IDxcUtils_      = {0x4605C4CB,0x2019,0x492A,{0xAD,0xA4,0x65,0xF2,0x0B,0xB7,0xD6,0x7F}};
static const GUID IID_IDxcCompiler3_  = {0x228B4687,0x5A6A,0x4730,{0x90,0x0C,0x97,0x02,0xB2,0x20,0x3F,0x54}};
static const GUID IID_IDxcResult_     = {0x58346CDA,0xDDE7,0x4497,{0x94,0x61,0x6F,0x87,0xAF,0x5E,0x06,0x59}};
static const GUID IID_IDxcBlob_       = {0x8BA5FB08,0x5195,0x40e2,{0xAC,0x58,0x0D,0x98,0x9C,0x3A,0x01,0x02}};
static const GUID IID_IDxcBlobUtf8_   = {0x3DA636C9,0xBA71,0x4024,{0xA3,0x01,0x30,0xCB,0xF1,0x25,0x30,0x5B}};

// =============================================================================
// DXC Interface Definitions (minimal C-compatible vtable stubs)
// =============================================================================

// IDxcBlob (inherits IUnknown)
typedef struct IDxcBlobVtbl {
    // IUnknown
    HRESULT (STDMETHODCALLTYPE *QueryInterface)(void* This, REFIID riid, void** ppvObject);
    ULONG   (STDMETHODCALLTYPE *AddRef)(void* This);
    ULONG   (STDMETHODCALLTYPE *Release)(void* This);
    // IDxcBlob
    LPVOID  (STDMETHODCALLTYPE *GetBufferPointer)(void* This);
    SIZE_T  (STDMETHODCALLTYPE *GetBufferSize)(void* This);
} IDxcBlobVtbl;

typedef struct IDxcBlob {
    IDxcBlobVtbl* lpVtbl;
} IDxcBlob;

// IDxcBlobEncoding (inherits IDxcBlob)
typedef struct IDxcBlobEncodingVtbl {
    // IUnknown
    HRESULT (STDMETHODCALLTYPE *QueryInterface)(void* This, REFIID riid, void** ppvObject);
    ULONG   (STDMETHODCALLTYPE *AddRef)(void* This);
    ULONG   (STDMETHODCALLTYPE *Release)(void* This);
    // IDxcBlob
    LPVOID  (STDMETHODCALLTYPE *GetBufferPointer)(void* This);
    SIZE_T  (STDMETHODCALLTYPE *GetBufferSize)(void* This);
    // IDxcBlobEncoding
    HRESULT (STDMETHODCALLTYPE *GetEncoding)(void* This, BOOL* pKnown, UINT32* pCodePage);
} IDxcBlobEncodingVtbl;

typedef struct IDxcBlobEncoding {
    IDxcBlobEncodingVtbl* lpVtbl;
} IDxcBlobEncoding;

// IDxcBlobUtf8 (inherits IDxcBlobEncoding)
typedef struct IDxcBlobUtf8Vtbl {
    // IUnknown
    HRESULT     (STDMETHODCALLTYPE *QueryInterface)(void* This, REFIID riid, void** ppvObject);
    ULONG       (STDMETHODCALLTYPE *AddRef)(void* This);
    ULONG       (STDMETHODCALLTYPE *Release)(void* This);
    // IDxcBlob
    LPVOID      (STDMETHODCALLTYPE *GetBufferPointer)(void* This);
    SIZE_T      (STDMETHODCALLTYPE *GetBufferSize)(void* This);
    // IDxcBlobEncoding
    HRESULT     (STDMETHODCALLTYPE *GetEncoding)(void* This, BOOL* pKnown, UINT32* pCodePage);
    // IDxcBlobUtf8
    LPCSTR      (STDMETHODCALLTYPE *GetStringPointer)(void* This);
    SIZE_T      (STDMETHODCALLTYPE *GetStringLength)(void* This);
} IDxcBlobUtf8Vtbl;

typedef struct IDxcBlobUtf8 {
    IDxcBlobUtf8Vtbl* lpVtbl;
} IDxcBlobUtf8;

// DxcBuffer structure
typedef struct DxcBuffer {
    LPCVOID Ptr;
    SIZE_T  Size;
    UINT    Encoding;
} DxcBuffer;

#define DXC_CP_UTF8  65001
#define DXC_CP_UTF16 1200

// DXC output kinds
#define DXC_OUT_OBJECT 1
#define DXC_OUT_ERRORS 2

// IDxcResult (inherits IUnknown + IDxcOperationResult)
typedef struct IDxcResultVtbl {
    // IUnknown
    HRESULT (STDMETHODCALLTYPE *QueryInterface)(void* This, REFIID riid, void** ppvObject);
    ULONG   (STDMETHODCALLTYPE *AddRef)(void* This);
    ULONG   (STDMETHODCALLTYPE *Release)(void* This);
    // IDxcOperationResult
    HRESULT (STDMETHODCALLTYPE *GetStatus)(void* This, HRESULT* pStatus);
    HRESULT (STDMETHODCALLTYPE *GetResult)(void* This, IDxcBlob** ppResult);
    HRESULT (STDMETHODCALLTYPE *GetErrorBuffer)(void* This, IDxcBlobEncoding** ppErrors);
    // IDxcResult
    BOOL    (STDMETHODCALLTYPE *HasOutput)(void* This, UINT32 dxcOutKind);
    HRESULT (STDMETHODCALLTYPE *GetOutput)(void* This, UINT32 dxcOutKind, REFIID iid, void** ppvObject, IDxcBlobUtf8** ppOutputName);
} IDxcResultVtbl;

typedef struct IDxcResult {
    IDxcResultVtbl* lpVtbl;
} IDxcResult;

// IDxcCompiler3 (inherits IUnknown)
typedef struct IDxcCompiler3Vtbl {
    // IUnknown
    HRESULT (STDMETHODCALLTYPE *QueryInterface)(void* This, REFIID riid, void** ppvObject);
    ULONG   (STDMETHODCALLTYPE *AddRef)(void* This);
    ULONG   (STDMETHODCALLTYPE *Release)(void* This);
    // IDxcCompiler3
    HRESULT (STDMETHODCALLTYPE *Compile)(
        void* This,
        const DxcBuffer* pSource,
        LPCWSTR* pArguments,
        UINT32 argCount,
        void* pIncludeHandler,  // IDxcIncludeHandler*
        REFIID riid,
        LPVOID* ppResult
    );
} IDxcCompiler3Vtbl;

typedef struct IDxcCompiler3 {
    IDxcCompiler3Vtbl* lpVtbl;
} IDxcCompiler3;

// IDxcUtils (inherits IUnknown) - only the methods we need
typedef struct IDxcUtilsVtbl {
    // IUnknown
    HRESULT (STDMETHODCALLTYPE *QueryInterface)(void* This, REFIID riid, void** ppvObject);
    ULONG   (STDMETHODCALLTYPE *AddRef)(void* This);
    ULONG   (STDMETHODCALLTYPE *Release)(void* This);
    // IDxcUtils
    HRESULT (STDMETHODCALLTYPE *CreateBlobFromBlob)(void* This, IDxcBlob* pBlob, UINT32 offset, UINT32 length, IDxcBlob** ppResult);
    HRESULT (STDMETHODCALLTYPE *CreateBlobFromPinned)(void* This, LPCVOID pData, UINT32 size, UINT32 codePage, IDxcBlobEncoding** pBlobEncoding);
    HRESULT (STDMETHODCALLTYPE *MoveToBlob)(void* This, LPCVOID pData, void* pIMalloc, UINT32 size, UINT32 codePage, IDxcBlobEncoding** pBlobEncoding);
    HRESULT (STDMETHODCALLTYPE *CreateBlob)(void* This, LPCVOID pData, UINT32 size, UINT32 codePage, IDxcBlobEncoding** pBlobEncoding);
    HRESULT (STDMETHODCALLTYPE *LoadFile)(void* This, LPCWSTR pFileName, UINT32* pCodePage, IDxcBlobEncoding** pBlobEncoding);
    // ... more methods follow but we don't need them
} IDxcUtilsVtbl;

typedef struct IDxcUtils {
    IDxcUtilsVtbl* lpVtbl;
} IDxcUtils;

typedef HRESULT (WINAPI *DxcCreateInstanceProc)(REFCLSID rclsid, REFIID riid, LPVOID* ppv);

// =============================================================================
// Global Variables
// =============================================================================
static HWND g_hwnd = NULL;

// D3D12 core objects
static IDXGIFactory4*              g_factory     = NULL;
static ID3D12Device5*              g_device      = NULL;
static ID3D12CommandQueue*         g_commandQueue = NULL;
static ID3D12CommandAllocator*     g_commandAllocator = NULL;
static ID3D12GraphicsCommandList4* g_commandList = NULL;
static IDXGISwapChain3*            g_swapChain   = NULL;
static ID3D12DescriptorHeap*       g_rtvHeap     = NULL;
static ID3D12Resource*             g_renderTargets[FRAME_COUNT] = {NULL, NULL};
static UINT                        g_rtvDescriptorSize = 0;
static UINT                        g_frameIndex = 0;

// Synchronization
static ID3D12Fence* g_fence      = NULL;
static UINT64       g_fenceValue = 0;
static HANDLE       g_fenceEvent = NULL;

// DXR-specific objects
static ID3D12Resource*       g_vertexBuffer   = NULL;
static ID3D12Resource*       g_bottomLevelAS  = NULL;   // BLAS
static ID3D12Resource*       g_topLevelAS     = NULL;   // TLAS
static ID3D12Resource*       g_instanceBuffer = NULL;
static ID3D12StateObject*    g_stateObject    = NULL;
static ID3D12Resource*       g_outputResource = NULL;   // UAV output texture
static ID3D12DescriptorHeap* g_srvUavHeap     = NULL;
static ID3D12RootSignature*  g_globalRootSig  = NULL;
static ID3D12Resource*       g_shaderTable    = NULL;

// Scratch buffers for BLAS/TLAS build
static ID3D12Resource* g_scratchBLAS = NULL;
static ID3D12Resource* g_scratchTLAS = NULL;

// =============================================================================
// Debug output helper
// =============================================================================
static void DebugLog(const char* fmt, ...)
{
    char buf[1024];
    va_list args;
    va_start(args, fmt);
    vsnprintf(buf, sizeof(buf), fmt, args);
    va_end(args);
    OutputDebugStringA(buf);
}

// =============================================================================
// Error check macro
// =============================================================================
#define CHECK_HR(hr, msg)                                                     \
    do {                                                                      \
        HRESULT _hr = (hr);                                                   \
        if (FAILED(_hr)) {                                                    \
            char _buf[512];                                                   \
            sprintf(_buf, "[DXR] %s failed: 0x%08X at %s:%d\n",              \
                    (msg), (unsigned)_hr, __FILE__, __LINE__);                \
            OutputDebugStringA(_buf);                                         \
            MessageBoxA(NULL, _buf, "Error", MB_OK | MB_ICONERROR);          \
            ExitProcess(1);                                                   \
        }                                                                     \
    } while (0)

// =============================================================================
// Alignment helper
// =============================================================================
static UINT64 AlignUp(UINT64 size, UINT64 alignment)
{
    return (size + alignment - 1) & ~(alignment - 1);
}

// =============================================================================
// Helper: Create an upload heap buffer
// =============================================================================
static ID3D12Resource* CreateUploadBuffer(UINT64 size)
{
    ID3D12Resource* buffer = NULL;
    D3D12_HEAP_PROPERTIES hp;
    D3D12_RESOURCE_DESC rd;

    ZeroMemory(&hp, sizeof(hp));
    hp.Type = D3D12_HEAP_TYPE_UPLOAD;

    ZeroMemory(&rd, sizeof(rd));
    rd.Dimension          = D3D12_RESOURCE_DIMENSION_BUFFER;
    rd.Width              = size;
    rd.Height             = 1;
    rd.DepthOrArraySize   = 1;
    rd.MipLevels          = 1;
    rd.SampleDesc.Count   = 1;
    rd.Layout             = D3D12_TEXTURE_LAYOUT_ROW_MAJOR;
    rd.Flags              = D3D12_RESOURCE_FLAG_NONE;

    CHECK_HR(
        g_device->lpVtbl->CreateCommittedResource(
            (ID3D12Device*)g_device,
            &hp, D3D12_HEAP_FLAG_NONE, &rd,
            D3D12_RESOURCE_STATE_GENERIC_READ, NULL,
            &IID_ID3D12Resource, (void**)&buffer),
        "CreateUploadBuffer");
    return buffer;
}

// =============================================================================
// Helper: Create a default heap buffer
// =============================================================================
static ID3D12Resource* CreateDefaultBuffer(UINT64 size, D3D12_RESOURCE_FLAGS flags, D3D12_RESOURCE_STATES initialState)
{
    ID3D12Resource* buffer = NULL;
    D3D12_HEAP_PROPERTIES hp;
    D3D12_RESOURCE_DESC rd;

    ZeroMemory(&hp, sizeof(hp));
    hp.Type = D3D12_HEAP_TYPE_DEFAULT;

    ZeroMemory(&rd, sizeof(rd));
    rd.Dimension          = D3D12_RESOURCE_DIMENSION_BUFFER;
    rd.Width              = size;
    rd.Height             = 1;
    rd.DepthOrArraySize   = 1;
    rd.MipLevels          = 1;
    rd.SampleDesc.Count   = 1;
    rd.Layout             = D3D12_TEXTURE_LAYOUT_ROW_MAJOR;
    rd.Flags              = flags;

    CHECK_HR(
        g_device->lpVtbl->CreateCommittedResource(
            (ID3D12Device*)g_device,
            &hp, D3D12_HEAP_FLAG_NONE, &rd,
            initialState, NULL,
            &IID_ID3D12Resource, (void**)&buffer),
        "CreateDefaultBuffer");
    return buffer;
}

// =============================================================================
// Helper: Wait for GPU to complete all pending work
// =============================================================================
static void WaitForGPU(void)
{
    g_fenceValue++;
    CHECK_HR(
        g_commandQueue->lpVtbl->Signal(g_commandQueue, g_fence, g_fenceValue),
        "Signal");
    if (g_fence->lpVtbl->GetCompletedValue(g_fence) < g_fenceValue)
    {
        CHECK_HR(
            g_fence->lpVtbl->SetEventOnCompletion(g_fence, g_fenceValue, g_fenceEvent),
            "SetEventOnCompletion");
        WaitForSingleObject(g_fenceEvent, INFINITE);
    }
}

// =============================================================================
// Helper: Execute command list and wait for completion
// =============================================================================
static void ExecuteAndWait(void)
{
    ID3D12CommandList* lists[1];
    CHECK_HR(
        g_commandList->lpVtbl->Close((ID3D12GraphicsCommandList*)g_commandList),
        "Close");
    lists[0] = (ID3D12CommandList*)g_commandList;
    g_commandQueue->lpVtbl->ExecuteCommandLists(g_commandQueue, 1, lists);
    WaitForGPU();
    CHECK_HR(
        g_commandAllocator->lpVtbl->Reset(g_commandAllocator),
        "Allocator Reset");
    CHECK_HR(
        g_commandList->lpVtbl->Reset(
            (ID3D12GraphicsCommandList*)g_commandList,
            g_commandAllocator, NULL),
        "CommandList Reset");
}

// =============================================================================
// Helper: Get CPU descriptor handle for heap start
// (The C calling convention for this varies by architecture;
//  on x64 the struct is returned via hidden pointer parameter)
// =============================================================================
static D3D12_CPU_DESCRIPTOR_HANDLE GetCPUDescriptorHandleForHeapStart(ID3D12DescriptorHeap* heap)
{
    D3D12_CPU_DESCRIPTOR_HANDLE handle;
    // Use the C-style call with explicit struct return
    ((void (STDMETHODCALLTYPE*)(ID3D12DescriptorHeap*, D3D12_CPU_DESCRIPTOR_HANDLE*))
        heap->lpVtbl->GetCPUDescriptorHandleForHeapStart)(heap, &handle);
    return handle;
}

static D3D12_GPU_DESCRIPTOR_HANDLE GetGPUDescriptorHandleForHeapStart(ID3D12DescriptorHeap* heap)
{
    D3D12_GPU_DESCRIPTOR_HANDLE handle;
    ((void (STDMETHODCALLTYPE*)(ID3D12DescriptorHeap*, D3D12_GPU_DESCRIPTOR_HANDLE*))
        heap->lpVtbl->GetGPUDescriptorHandleForHeapStart)(heap, &handle);
    return handle;
}

// =============================================================================
// InitD3D12 - Create device, command queue, swap chain, descriptor heaps
// =============================================================================
static void InitD3D12(void)
{
    HRESULT hr;
    DebugLog("[DXR] InitD3D12: BEGIN\n");

    // Enable debug layer
    {
        ID3D12Debug* debug = NULL;
        if (SUCCEEDED(D3D12GetDebugInterface(&IID_ID3D12Debug, (void**)&debug)))
        {
            debug->lpVtbl->EnableDebugLayer(debug);
            debug->lpVtbl->Release(debug);
            DebugLog("[DXR] InitD3D12: Debug layer enabled\n");
        }
    }

    // Create DXGI factory
    CHECK_HR(
        CreateDXGIFactory2(0, &IID_IDXGIFactory4, (void**)&g_factory),
        "CreateDXGIFactory2");

    // Enumerate adapters and find a DXR-capable device
    {
        IDXGIAdapter1* adapter = NULL;
        UINT i;
        BOOL found = FALSE;
        for (i = 0; g_factory->lpVtbl->EnumAdapters1((IDXGIFactory1*)g_factory, i, &adapter) != DXGI_ERROR_NOT_FOUND; i++)
        {
            DXGI_ADAPTER_DESC1 desc;
            adapter->lpVtbl->GetDesc1(adapter, &desc);
            if (desc.Flags & DXGI_ADAPTER_FLAG_SOFTWARE)
            {
                adapter->lpVtbl->Release(adapter);
                adapter = NULL;
                continue;
            }

            // Try creating a D3D12 device
            hr = D3D12CreateDevice((IUnknown*)adapter, D3D_FEATURE_LEVEL_12_1,
                                   &IID_ID3D12Device5, (void**)&g_device);
            if (SUCCEEDED(hr))
            {
                // Check DXR support
                D3D12_FEATURE_DATA_D3D12_OPTIONS5 opts5;
                ZeroMemory(&opts5, sizeof(opts5));
                hr = g_device->lpVtbl->CheckFeatureSupport(
                    (ID3D12Device*)g_device,
                    D3D12_FEATURE_D3D12_OPTIONS5, &opts5, sizeof(opts5));
                if (SUCCEEDED(hr) && opts5.RaytracingTier >= D3D12_RAYTRACING_TIER_1_0)
                {
                    DebugLog("[DXR] InitD3D12: Found DXR-capable adapter: %ls\n", desc.Description);
                    adapter->lpVtbl->Release(adapter);
                    found = TRUE;
                    break;
                }
                g_device->lpVtbl->Release((ID3D12Device*)g_device);
                g_device = NULL;
            }
            adapter->lpVtbl->Release(adapter);
            adapter = NULL;
        }

        if (!found)
        {
            // Fallback to WARP
            IDXGIAdapter* warpAdapter = NULL;
            D3D12_FEATURE_DATA_D3D12_OPTIONS5 warpOpts5;
            DebugLog("[DXR] InitD3D12: No DXR GPU found, falling back to WARP\n");
            CHECK_HR(
                g_factory->lpVtbl->EnumWarpAdapter(g_factory, &IID_IDXGIAdapter, (void**)&warpAdapter),
                "EnumWarpAdapter");
            CHECK_HR(
                D3D12CreateDevice((IUnknown*)warpAdapter, D3D_FEATURE_LEVEL_12_1,
                                  &IID_ID3D12Device5, (void**)&g_device),
                "D3D12CreateDevice (WARP)");
            warpAdapter->lpVtbl->Release(warpAdapter);

            ZeroMemory(&warpOpts5, sizeof(warpOpts5));
            g_device->lpVtbl->CheckFeatureSupport(
                (ID3D12Device*)g_device,
                D3D12_FEATURE_D3D12_OPTIONS5, &warpOpts5, sizeof(warpOpts5));
            if (warpOpts5.RaytracingTier < D3D12_RAYTRACING_TIER_1_0)
            {
                MessageBoxA(NULL, "WARP does not support DXR on this system.", "Error", MB_OK | MB_ICONERROR);
                ExitProcess(1);
            }
        }
    }
    DebugLog("[DXR] InitD3D12: D3D12 device created\n");

    // Create command queue
    {
        D3D12_COMMAND_QUEUE_DESC queueDesc;
        ZeroMemory(&queueDesc, sizeof(queueDesc));
        queueDesc.Type = D3D12_COMMAND_LIST_TYPE_DIRECT;
        CHECK_HR(
            g_device->lpVtbl->CreateCommandQueue(
                (ID3D12Device*)g_device, &queueDesc,
                &IID_ID3D12CommandQueue, (void**)&g_commandQueue),
            "CreateCommandQueue");
    }

    // Create command allocator
    CHECK_HR(
        g_device->lpVtbl->CreateCommandAllocator(
            (ID3D12Device*)g_device,
            D3D12_COMMAND_LIST_TYPE_DIRECT,
            &IID_ID3D12CommandAllocator, (void**)&g_commandAllocator),
        "CreateCommandAllocator");

    // Create command list as base type, then QI to CommandList4 for DXR
    {
        ID3D12GraphicsCommandList* baseCmdList = NULL;
        CHECK_HR(
            g_device->lpVtbl->CreateCommandList(
                (ID3D12Device*)g_device,
                0, D3D12_COMMAND_LIST_TYPE_DIRECT,
                g_commandAllocator, NULL,
                &IID_ID3D12GraphicsCommandList, (void**)&baseCmdList),
            "CreateCommandList");
        CHECK_HR(
            baseCmdList->lpVtbl->QueryInterface(
                baseCmdList,
                &IID_ID3D12GraphicsCommandList4, (void**)&g_commandList),
            "QueryInterface(CommandList4)");
        baseCmdList->lpVtbl->Release(baseCmdList);
    }
    DebugLog("[DXR] InitD3D12: Command allocator & list created\n");

    // Create swap chain
    {
        DXGI_SWAP_CHAIN_DESC1 scDesc;
        IDXGISwapChain1* swapChain1 = NULL;
        ZeroMemory(&scDesc, sizeof(scDesc));
        scDesc.Width       = WIDTH;
        scDesc.Height      = HEIGHT;
        scDesc.Format      = DXGI_FORMAT_R8G8B8A8_UNORM;
        scDesc.BufferUsage = DXGI_USAGE_RENDER_TARGET_OUTPUT;
        scDesc.BufferCount = FRAME_COUNT;
        scDesc.SwapEffect  = DXGI_SWAP_EFFECT_FLIP_DISCARD;
        scDesc.SampleDesc.Count = 1;

        CHECK_HR(
            g_factory->lpVtbl->CreateSwapChainForHwnd(
                (IDXGIFactory2*)g_factory,
                (IUnknown*)g_commandQueue, g_hwnd,
                &scDesc, NULL, NULL, &swapChain1),
            "CreateSwapChainForHwnd");
        CHECK_HR(
            swapChain1->lpVtbl->QueryInterface(swapChain1, &IID_IDXGISwapChain3, (void**)&g_swapChain),
            "QueryInterface SwapChain3");
        swapChain1->lpVtbl->Release(swapChain1);
        g_frameIndex = g_swapChain->lpVtbl->GetCurrentBackBufferIndex(g_swapChain);
    }
    DebugLog("[DXR] InitD3D12: Swap chain created\n");

    // Create RTV descriptor heap
    {
        D3D12_DESCRIPTOR_HEAP_DESC rtvHeapDesc;
        ZeroMemory(&rtvHeapDesc, sizeof(rtvHeapDesc));
        rtvHeapDesc.NumDescriptors = FRAME_COUNT;
        rtvHeapDesc.Type  = D3D12_DESCRIPTOR_HEAP_TYPE_RTV;
        rtvHeapDesc.Flags = D3D12_DESCRIPTOR_HEAP_FLAG_NONE;
        CHECK_HR(
            g_device->lpVtbl->CreateDescriptorHeap(
                (ID3D12Device*)g_device, &rtvHeapDesc,
                &IID_ID3D12DescriptorHeap, (void**)&g_rtvHeap),
            "CreateDescriptorHeap (RTV)");
        g_rtvDescriptorSize = g_device->lpVtbl->GetDescriptorHandleIncrementSize(
            (ID3D12Device*)g_device, D3D12_DESCRIPTOR_HEAP_TYPE_RTV);
    }

    // Create render target views
    {
        D3D12_CPU_DESCRIPTOR_HANDLE rtvHandle = GetCPUDescriptorHandleForHeapStart(g_rtvHeap);
        UINT i;
        for (i = 0; i < FRAME_COUNT; i++)
        {
            CHECK_HR(
                g_swapChain->lpVtbl->GetBuffer(
                    (IDXGISwapChain*)g_swapChain, i,
                    &IID_ID3D12Resource, (void**)&g_renderTargets[i]),
                "GetBuffer");
            g_device->lpVtbl->CreateRenderTargetView(
                (ID3D12Device*)g_device, g_renderTargets[i], NULL, rtvHandle);
            rtvHandle.ptr += g_rtvDescriptorSize;
        }
    }
    DebugLog("[DXR] InitD3D12: RTVs created\n");

    // Create fence
    CHECK_HR(
        g_device->lpVtbl->CreateFence(
            (ID3D12Device*)g_device,
            0, D3D12_FENCE_FLAG_NONE,
            &IID_ID3D12Fence, (void**)&g_fence),
        "CreateFence");
    g_fenceEvent = CreateEvent(NULL, FALSE, FALSE, NULL);

    // Create SRV/UAV descriptor heap (shader visible)
    {
        D3D12_DESCRIPTOR_HEAP_DESC srvHeapDesc;
        ZeroMemory(&srvHeapDesc, sizeof(srvHeapDesc));
        srvHeapDesc.NumDescriptors = 1; // UAV (output)
        srvHeapDesc.Type  = D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV;
        srvHeapDesc.Flags = D3D12_DESCRIPTOR_HEAP_FLAG_SHADER_VISIBLE;
        CHECK_HR(
            g_device->lpVtbl->CreateDescriptorHeap(
                (ID3D12Device*)g_device, &srvHeapDesc,
                &IID_ID3D12DescriptorHeap, (void**)&g_srvUavHeap),
            "CreateDescriptorHeap (SRV/UAV)");
    }

    DebugLog("[DXR] InitD3D12: DONE\n");
}

// =============================================================================
// CreateVertexBuffer - Define the triangle's 3 vertices
// =============================================================================
static void CreateVertexBuffer(void)
{
    float vertices[] = {
         0.0f,  0.7f, 0.0f,   // top
        -0.7f, -0.7f, 0.0f,   // bottom-left
         0.7f, -0.7f, 0.0f,   // bottom-right
    };
    UINT bufferSize = sizeof(vertices);
    void* mapped = NULL;

    DebugLog("[DXR] CreateVertexBuffer: BEGIN\n");

    g_vertexBuffer = CreateUploadBuffer(bufferSize);
    CHECK_HR(
        g_vertexBuffer->lpVtbl->Map(g_vertexBuffer, 0, NULL, &mapped),
        "Map vertex buffer");
    memcpy(mapped, vertices, bufferSize);
    g_vertexBuffer->lpVtbl->Unmap(g_vertexBuffer, 0, NULL);

    DebugLog("[DXR] CreateVertexBuffer: DONE (%u bytes)\n", bufferSize);
}

// =============================================================================
// BuildAccelerationStructures - Build BLAS and TLAS
// =============================================================================
static void BuildAccelerationStructures(void)
{
    DebugLog("[DXR] BuildAccelerationStructures: BEGIN\n");

    // === Bottom-Level Acceleration Structure (BLAS) ===
    {
        D3D12_RAYTRACING_GEOMETRY_DESC geomDesc;
        D3D12_BUILD_RAYTRACING_ACCELERATION_STRUCTURE_INPUTS blasInputs;
        D3D12_RAYTRACING_ACCELERATION_STRUCTURE_PREBUILD_INFO blasPrebuild;
        D3D12_BUILD_RAYTRACING_ACCELERATION_STRUCTURE_DESC blasBuildDesc;
        D3D12_RESOURCE_BARRIER uavBarrier;

        ZeroMemory(&geomDesc, sizeof(geomDesc));
        geomDesc.Type  = D3D12_RAYTRACING_GEOMETRY_TYPE_TRIANGLES;
        geomDesc.Flags = D3D12_RAYTRACING_GEOMETRY_FLAG_OPAQUE;
        geomDesc.Triangles.VertexBuffer.StartAddress  = g_vertexBuffer->lpVtbl->GetGPUVirtualAddress(g_vertexBuffer);
        geomDesc.Triangles.VertexBuffer.StrideInBytes  = sizeof(float) * 3;
        geomDesc.Triangles.VertexFormat = DXGI_FORMAT_R32G32B32_FLOAT;
        geomDesc.Triangles.VertexCount  = 3;

        ZeroMemory(&blasInputs, sizeof(blasInputs));
        blasInputs.Type           = D3D12_RAYTRACING_ACCELERATION_STRUCTURE_TYPE_BOTTOM_LEVEL;
        blasInputs.DescsLayout    = D3D12_ELEMENTS_LAYOUT_ARRAY;
        blasInputs.NumDescs       = 1;
        blasInputs.pGeometryDescs = &geomDesc;
        blasInputs.Flags          = D3D12_RAYTRACING_ACCELERATION_STRUCTURE_BUILD_FLAG_PREFER_FAST_TRACE;

        ZeroMemory(&blasPrebuild, sizeof(blasPrebuild));
        g_device->lpVtbl->GetRaytracingAccelerationStructurePrebuildInfo(
            g_device, &blasInputs, &blasPrebuild);
        DebugLog("[DXR] BLAS result=%llu bytes, scratch=%llu bytes\n",
                 blasPrebuild.ResultDataMaxSizeInBytes, blasPrebuild.ScratchDataSizeInBytes);

        g_bottomLevelAS = CreateDefaultBuffer(
            blasPrebuild.ResultDataMaxSizeInBytes,
            D3D12_RESOURCE_FLAG_ALLOW_UNORDERED_ACCESS,
            D3D12_RESOURCE_STATE_RAYTRACING_ACCELERATION_STRUCTURE);
        g_scratchBLAS = CreateDefaultBuffer(
            blasPrebuild.ScratchDataSizeInBytes,
            D3D12_RESOURCE_FLAG_ALLOW_UNORDERED_ACCESS,
            D3D12_RESOURCE_STATE_COMMON);

        ZeroMemory(&blasBuildDesc, sizeof(blasBuildDesc));
        blasBuildDesc.Inputs                           = blasInputs;
        blasBuildDesc.DestAccelerationStructureData     = g_bottomLevelAS->lpVtbl->GetGPUVirtualAddress(g_bottomLevelAS);
        blasBuildDesc.ScratchAccelerationStructureData  = g_scratchBLAS->lpVtbl->GetGPUVirtualAddress(g_scratchBLAS);

        g_commandList->lpVtbl->BuildRaytracingAccelerationStructure(
            g_commandList, &blasBuildDesc, 0, NULL);

        // UAV barrier between BLAS and TLAS builds
        ZeroMemory(&uavBarrier, sizeof(uavBarrier));
        uavBarrier.Type          = D3D12_RESOURCE_BARRIER_TYPE_UAV;
        uavBarrier.UAV.pResource = g_bottomLevelAS;
        g_commandList->lpVtbl->ResourceBarrier(
            (ID3D12GraphicsCommandList*)g_commandList, 1, &uavBarrier);
    }

    // === Top-Level Acceleration Structure (TLAS) ===
    {
        D3D12_RAYTRACING_INSTANCE_DESC instanceDesc;
        void* mapped = NULL;
        D3D12_BUILD_RAYTRACING_ACCELERATION_STRUCTURE_INPUTS tlasInputs;
        D3D12_RAYTRACING_ACCELERATION_STRUCTURE_PREBUILD_INFO tlasPrebuild;
        D3D12_BUILD_RAYTRACING_ACCELERATION_STRUCTURE_DESC tlasBuildDesc;

        ZeroMemory(&instanceDesc, sizeof(instanceDesc));
        instanceDesc.Transform[0][0] = 1.0f;
        instanceDesc.Transform[1][1] = 1.0f;
        instanceDesc.Transform[2][2] = 1.0f;
        instanceDesc.InstanceMask = 0xFF;
        instanceDesc.AccelerationStructure = g_bottomLevelAS->lpVtbl->GetGPUVirtualAddress(g_bottomLevelAS);

        g_instanceBuffer = CreateUploadBuffer(sizeof(instanceDesc));
        CHECK_HR(
            g_instanceBuffer->lpVtbl->Map(g_instanceBuffer, 0, NULL, &mapped),
            "Map instance buffer");
        memcpy(mapped, &instanceDesc, sizeof(instanceDesc));
        g_instanceBuffer->lpVtbl->Unmap(g_instanceBuffer, 0, NULL);

        ZeroMemory(&tlasInputs, sizeof(tlasInputs));
        tlasInputs.Type          = D3D12_RAYTRACING_ACCELERATION_STRUCTURE_TYPE_TOP_LEVEL;
        tlasInputs.DescsLayout   = D3D12_ELEMENTS_LAYOUT_ARRAY;
        tlasInputs.NumDescs      = 1;
        tlasInputs.InstanceDescs = g_instanceBuffer->lpVtbl->GetGPUVirtualAddress(g_instanceBuffer);
        tlasInputs.Flags         = D3D12_RAYTRACING_ACCELERATION_STRUCTURE_BUILD_FLAG_PREFER_FAST_TRACE;

        ZeroMemory(&tlasPrebuild, sizeof(tlasPrebuild));
        g_device->lpVtbl->GetRaytracingAccelerationStructurePrebuildInfo(
            g_device, &tlasInputs, &tlasPrebuild);
        DebugLog("[DXR] TLAS result=%llu bytes, scratch=%llu bytes\n",
                 tlasPrebuild.ResultDataMaxSizeInBytes, tlasPrebuild.ScratchDataSizeInBytes);

        g_topLevelAS = CreateDefaultBuffer(
            tlasPrebuild.ResultDataMaxSizeInBytes,
            D3D12_RESOURCE_FLAG_ALLOW_UNORDERED_ACCESS,
            D3D12_RESOURCE_STATE_RAYTRACING_ACCELERATION_STRUCTURE);
        g_scratchTLAS = CreateDefaultBuffer(
            tlasPrebuild.ScratchDataSizeInBytes,
            D3D12_RESOURCE_FLAG_ALLOW_UNORDERED_ACCESS,
            D3D12_RESOURCE_STATE_COMMON);

        ZeroMemory(&tlasBuildDesc, sizeof(tlasBuildDesc));
        tlasBuildDesc.Inputs                           = tlasInputs;
        tlasBuildDesc.DestAccelerationStructureData     = g_topLevelAS->lpVtbl->GetGPUVirtualAddress(g_topLevelAS);
        tlasBuildDesc.ScratchAccelerationStructureData  = g_scratchTLAS->lpVtbl->GetGPUVirtualAddress(g_scratchTLAS);

        g_commandList->lpVtbl->BuildRaytracingAccelerationStructure(
            g_commandList, &tlasBuildDesc, 0, NULL);
    }

    // Execute and wait for GPU
    ExecuteAndWait();
    DebugLog("[DXR] BuildAccelerationStructures: DONE\n");
}

// =============================================================================
// CreateRootSignature - Global root signature for DXR pipeline
// =============================================================================
static void CreateRootSignature(void)
{
    // Layout:
    //   [0] UAV  - output texture (u0) via descriptor table
    //   [1] SRV  - acceleration structure (t0) via root SRV

    D3D12_DESCRIPTOR_RANGE ranges[1];
    D3D12_ROOT_PARAMETER params[2];
    D3D12_ROOT_SIGNATURE_DESC rootSigDesc;
    ID3DBlob* blob  = NULL;
    ID3DBlob* error = NULL;

    DebugLog("[DXR] CreateRootSignature: BEGIN\n");

    ZeroMemory(ranges, sizeof(ranges));
    ranges[0].RangeType          = D3D12_DESCRIPTOR_RANGE_TYPE_UAV;
    ranges[0].NumDescriptors     = 1;
    ranges[0].BaseShaderRegister = 0;

    ZeroMemory(params, sizeof(params));

    // [0] UAV (descriptor table)
    params[0].ParameterType    = D3D12_ROOT_PARAMETER_TYPE_DESCRIPTOR_TABLE;
    params[0].DescriptorTable.NumDescriptorRanges = 1;
    params[0].DescriptorTable.pDescriptorRanges   = ranges;

    // [1] SRV (root SRV for acceleration structure)
    params[1].ParameterType             = D3D12_ROOT_PARAMETER_TYPE_SRV;
    params[1].Descriptor.ShaderRegister = 0;

    ZeroMemory(&rootSigDesc, sizeof(rootSigDesc));
    rootSigDesc.NumParameters = 2;
    rootSigDesc.pParameters   = params;

    CHECK_HR(
        D3D12SerializeRootSignature(&rootSigDesc, D3D_ROOT_SIGNATURE_VERSION_1, &blob, &error),
        "D3D12SerializeRootSignature");
    CHECK_HR(
        g_device->lpVtbl->CreateRootSignature(
            (ID3D12Device*)g_device,
            0, blob->lpVtbl->GetBufferPointer(blob), blob->lpVtbl->GetBufferSize(blob),
            &IID_ID3D12RootSignature, (void**)&g_globalRootSig),
        "CreateRootSignature");

    blob->lpVtbl->Release(blob);
    if (error) error->lpVtbl->Release(error);

    DebugLog("[DXR] CreateRootSignature: DONE\n");
}

// =============================================================================
// CreateRaytracingPipeline - Compile shader with DXC and create state object
// =============================================================================
static void CreateRaytracingPipeline(void)
{
    HMODULE dxcModule = NULL;
    DxcCreateInstanceProc pDxcCreateInstance = NULL;
    IDxcUtils*      dxcUtils    = NULL;
    IDxcCompiler3*  dxcCompiler = NULL;
    IDxcBlobEncoding* sourceBlob = NULL;
    IDxcResult*     result       = NULL;
    IDxcBlobUtf8*   errors       = NULL;
    IDxcBlob*       shaderBlob   = NULL;
    HRESULT compileStatus;

    // State object subobject data (must remain alive until CreateStateObject)
    D3D12_DXIL_LIBRARY_DESC libDesc;
    D3D12_HIT_GROUP_DESC hitGroupDesc;
    D3D12_RAYTRACING_SHADER_CONFIG shaderConfig;
    D3D12_GLOBAL_ROOT_SIGNATURE globalRootSigDesc;
    D3D12_RAYTRACING_PIPELINE_CONFIG pipelineConfig;
    D3D12_STATE_SUBOBJECT subobjects[5];
    D3D12_STATE_OBJECT_DESC stateObjectDesc;

    DebugLog("[DXR] CreateRaytracingPipeline: BEGIN\n");

    // --- Load DXC ---
    dxcModule = LoadLibraryW(L"dxcompiler.dll");
    if (!dxcModule)
    {
        MessageBoxA(NULL, "Failed to load dxcompiler.dll.\n"
            "Ensure dxcompiler.dll and dxil.dll are in PATH or exe directory.",
            "Error", MB_OK | MB_ICONERROR);
        ExitProcess(1);
    }
    pDxcCreateInstance = (DxcCreateInstanceProc)GetProcAddress(dxcModule, "DxcCreateInstance");
    if (!pDxcCreateInstance)
    {
        FreeLibrary(dxcModule);
        MessageBoxA(NULL, "Failed to find DxcCreateInstance.", "Error", MB_OK | MB_ICONERROR);
        ExitProcess(1);
    }

    CHECK_HR(pDxcCreateInstance(&CLSID_DxcUtils_,    &IID_IDxcUtils_,     (void**)&dxcUtils),    "DxcCreateInstance(Utils)");
    CHECK_HR(pDxcCreateInstance(&CLSID_DxcCompiler_, &IID_IDxcCompiler3_, (void**)&dxcCompiler), "DxcCreateInstance(Compiler)");

    // --- Load HLSL from file ---
    CHECK_HR(
        dxcUtils->lpVtbl->LoadFile(dxcUtils, L"hello.hlsl", NULL, &sourceBlob),
        "LoadFile(hello.hlsl)");
    DebugLog("[DXR] CreateRaytracingPipeline: HLSL loaded from hello.hlsl\n");

    // --- Compile ---
    {
        LPCWSTR args[] = {
            L"-T", L"lib_6_3",     // target: raytracing library
        };
        DxcBuffer sourceBuffer;
        sourceBuffer.Ptr      = sourceBlob->lpVtbl->GetBufferPointer(sourceBlob);
        sourceBuffer.Size     = sourceBlob->lpVtbl->GetBufferSize(sourceBlob);
        sourceBuffer.Encoding = 0; // Let DXC detect encoding

        DebugLog("[DXR] CreateRaytracingPipeline: Compiling HLSL with DXC (lib_6_3)...\n");
        CHECK_HR(
            dxcCompiler->lpVtbl->Compile(
                dxcCompiler,
                &sourceBuffer,
                args, _countof(args),
                NULL,  // no include handler
                &IID_IDxcResult_,
                (void**)&result),
            "Compile");
    }

    // Check for compilation errors
    result->lpVtbl->GetOutput(result, DXC_OUT_ERRORS, &IID_IDxcBlobUtf8_, (void**)&errors, NULL);
    if (errors && errors->lpVtbl->GetStringLength(errors) > 0)
    {
        DebugLog("[DXR] Shader compile output:\n%s\n", errors->lpVtbl->GetStringPointer(errors));
    }

    result->lpVtbl->GetStatus(result, &compileStatus);
    if (FAILED(compileStatus))
    {
        DebugLog("[DXR] Shader compilation FAILED (0x%08X)\n", (unsigned)compileStatus);
        if (errors && errors->lpVtbl->GetStringLength(errors) > 0)
            MessageBoxA(NULL, errors->lpVtbl->GetStringPointer(errors), "Shader Compile Error", MB_OK | MB_ICONERROR);
        ExitProcess(1);
    }

    result->lpVtbl->GetOutput(result, DXC_OUT_OBJECT, &IID_IDxcBlob_, (void**)&shaderBlob, NULL);
    DebugLog("[DXR] Shader compiled OK (%zu bytes)\n", shaderBlob->lpVtbl->GetBufferSize(shaderBlob));

    // --- Build State Object (raytracing pipeline) ---
    // Subobject 0: DXIL Library
    ZeroMemory(&libDesc, sizeof(libDesc));
    libDesc.DXILLibrary.pShaderBytecode = shaderBlob->lpVtbl->GetBufferPointer(shaderBlob);
    libDesc.DXILLibrary.BytecodeLength  = shaderBlob->lpVtbl->GetBufferSize(shaderBlob);
    libDesc.NumExports = 0; // export all shaders

    ZeroMemory(&subobjects[0], sizeof(subobjects[0]));
    subobjects[0].Type  = D3D12_STATE_SUBOBJECT_TYPE_DXIL_LIBRARY;
    subobjects[0].pDesc = &libDesc;

    // Subobject 1: Hit Group
    ZeroMemory(&hitGroupDesc, sizeof(hitGroupDesc));
    hitGroupDesc.HitGroupExport         = L"HitGroup";
    hitGroupDesc.ClosestHitShaderImport = L"ClosestHit";
    hitGroupDesc.Type                   = D3D12_HIT_GROUP_TYPE_TRIANGLES;

    ZeroMemory(&subobjects[1], sizeof(subobjects[1]));
    subobjects[1].Type  = D3D12_STATE_SUBOBJECT_TYPE_HIT_GROUP;
    subobjects[1].pDesc = &hitGroupDesc;

    // Subobject 2: Shader Config
    ZeroMemory(&shaderConfig, sizeof(shaderConfig));
    shaderConfig.MaxPayloadSizeInBytes   = sizeof(float) * 4; // RayPayload: float4
    shaderConfig.MaxAttributeSizeInBytes = sizeof(float) * 2; // TriAttributes: float2

    ZeroMemory(&subobjects[2], sizeof(subobjects[2]));
    subobjects[2].Type  = D3D12_STATE_SUBOBJECT_TYPE_RAYTRACING_SHADER_CONFIG;
    subobjects[2].pDesc = &shaderConfig;

    // Subobject 3: Global Root Signature
    ZeroMemory(&globalRootSigDesc, sizeof(globalRootSigDesc));
    globalRootSigDesc.pGlobalRootSignature = g_globalRootSig;

    ZeroMemory(&subobjects[3], sizeof(subobjects[3]));
    subobjects[3].Type  = D3D12_STATE_SUBOBJECT_TYPE_GLOBAL_ROOT_SIGNATURE;
    subobjects[3].pDesc = &globalRootSigDesc;

    // Subobject 4: Pipeline Config
    ZeroMemory(&pipelineConfig, sizeof(pipelineConfig));
    pipelineConfig.MaxTraceRecursionDepth = 1;

    ZeroMemory(&subobjects[4], sizeof(subobjects[4]));
    subobjects[4].Type  = D3D12_STATE_SUBOBJECT_TYPE_RAYTRACING_PIPELINE_CONFIG;
    subobjects[4].pDesc = &pipelineConfig;

    // Create State Object
    ZeroMemory(&stateObjectDesc, sizeof(stateObjectDesc));
    stateObjectDesc.Type          = D3D12_STATE_OBJECT_TYPE_RAYTRACING_PIPELINE;
    stateObjectDesc.NumSubobjects = _countof(subobjects);
    stateObjectDesc.pSubobjects   = subobjects;

    DebugLog("[DXR] Creating state object (%u subobjects)...\n", _countof(subobjects));
    CHECK_HR(
        g_device->lpVtbl->CreateStateObject(
            g_device, &stateObjectDesc,
            &IID_ID3D12StateObject, (void**)&g_stateObject),
        "CreateStateObject");

    DebugLog("[DXR] CreateRaytracingPipeline: DONE\n");

    // Cleanup DXC objects
    if (shaderBlob)  shaderBlob->lpVtbl->Release(shaderBlob);
    if (errors)      errors->lpVtbl->Release(errors);
    if (result)      result->lpVtbl->Release(result);
    if (sourceBlob)  sourceBlob->lpVtbl->Release(sourceBlob);
    if (dxcCompiler) dxcCompiler->lpVtbl->Release(dxcCompiler);
    if (dxcUtils)    dxcUtils->lpVtbl->Release(dxcUtils);
    // Note: don't FreeLibrary(dxcModule) - state object may reference it
}

// =============================================================================
// CreateOutputResource - UAV texture for raytracing output
// =============================================================================
static void CreateOutputResource(void)
{
    D3D12_RESOURCE_DESC texDesc;
    D3D12_HEAP_PROPERTIES hp;
    D3D12_CPU_DESCRIPTOR_HANDLE cpuHandle;
    D3D12_UNORDERED_ACCESS_VIEW_DESC uavDesc;

    DebugLog("[DXR] CreateOutputResource: BEGIN\n");

    ZeroMemory(&texDesc, sizeof(texDesc));
    texDesc.Dimension        = D3D12_RESOURCE_DIMENSION_TEXTURE2D;
    texDesc.Width            = WIDTH;
    texDesc.Height           = HEIGHT;
    texDesc.DepthOrArraySize = 1;
    texDesc.MipLevels        = 1;
    texDesc.Format           = DXGI_FORMAT_R8G8B8A8_UNORM;
    texDesc.SampleDesc.Count = 1;
    texDesc.Flags            = D3D12_RESOURCE_FLAG_ALLOW_UNORDERED_ACCESS;

    ZeroMemory(&hp, sizeof(hp));
    hp.Type = D3D12_HEAP_TYPE_DEFAULT;

    CHECK_HR(
        g_device->lpVtbl->CreateCommittedResource(
            (ID3D12Device*)g_device,
            &hp, D3D12_HEAP_FLAG_NONE, &texDesc,
            D3D12_RESOURCE_STATE_UNORDERED_ACCESS, NULL,
            &IID_ID3D12Resource, (void**)&g_outputResource),
        "CreateOutputResource");

    // Create UAV descriptor
    cpuHandle = GetCPUDescriptorHandleForHeapStart(g_srvUavHeap);
    ZeroMemory(&uavDesc, sizeof(uavDesc));
    uavDesc.ViewDimension = D3D12_UAV_DIMENSION_TEXTURE2D;
    g_device->lpVtbl->CreateUnorderedAccessView(
        (ID3D12Device*)g_device, g_outputResource, NULL, &uavDesc, cpuHandle);

    DebugLog("[DXR] CreateOutputResource: DONE\n");
}

// =============================================================================
// CreateShaderTable - Build shader record table for DispatchRays
// =============================================================================
static void CreateShaderTable(void)
{
    ID3D12StateObjectProperties* stateProps = NULL;
    void* rayGenId;
    void* missId;
    void* hitId;
    UINT shaderIdSize;
    UINT recordSize;
    UINT tableSize;
    UINT8* mapped = NULL;

    DebugLog("[DXR] CreateShaderTable: BEGIN\n");

    CHECK_HR(
        g_stateObject->lpVtbl->QueryInterface(
            (IUnknown*)g_stateObject,
            &IID_ID3D12StateObjectProperties, (void**)&stateProps),
        "QueryInterface(StateObjectProperties)");

    rayGenId = stateProps->lpVtbl->GetShaderIdentifier(stateProps, L"RayGen");
    missId   = stateProps->lpVtbl->GetShaderIdentifier(stateProps, L"Miss");
    hitId    = stateProps->lpVtbl->GetShaderIdentifier(stateProps, L"HitGroup");

    if (!rayGenId || !missId || !hitId)
    {
        MessageBoxA(NULL, "Failed to get shader identifiers", "Error", MB_OK | MB_ICONERROR);
        ExitProcess(1);
    }

    shaderIdSize = D3D12_SHADER_IDENTIFIER_SIZE_IN_BYTES; // 32 bytes
    recordSize   = (UINT)AlignUp(shaderIdSize, D3D12_RAYTRACING_SHADER_TABLE_BYTE_ALIGNMENT); // 64 bytes
    tableSize    = recordSize * 3;

    g_shaderTable = CreateUploadBuffer(tableSize);

    CHECK_HR(
        g_shaderTable->lpVtbl->Map(g_shaderTable, 0, NULL, (void**)&mapped),
        "Map shader table");
    memcpy(mapped + recordSize * 0, rayGenId, shaderIdSize);
    memcpy(mapped + recordSize * 1, missId,   shaderIdSize);
    memcpy(mapped + recordSize * 2, hitId,    shaderIdSize);
    g_shaderTable->lpVtbl->Unmap(g_shaderTable, 0, NULL);

    stateProps->lpVtbl->Release((IUnknown*)stateProps);

    DebugLog("[DXR] CreateShaderTable: DONE (recordSize=%u, tableSize=%u)\n", recordSize, tableSize);
}

// =============================================================================
// Render - Dispatch rays and copy result to back buffer
// =============================================================================
static void Render(void)
{
    UINT recordSize;
    D3D12_DISPATCH_RAYS_DESC dispatchDesc;
    D3D12_RESOURCE_BARRIER barriers[2];
    ID3D12CommandList* lists[1];
    ID3D12DescriptorHeap* heaps[1];
    D3D12_GPU_DESCRIPTOR_HANDLE gpuHandle;

    CHECK_HR(g_commandAllocator->lpVtbl->Reset(g_commandAllocator), "Allocator Reset");
    CHECK_HR(
        g_commandList->lpVtbl->Reset(
            (ID3D12GraphicsCommandList*)g_commandList,
            g_commandAllocator, NULL),
        "CommandList Reset");

    // Set descriptor heap
    heaps[0] = g_srvUavHeap;
    g_commandList->lpVtbl->SetDescriptorHeaps(
        (ID3D12GraphicsCommandList*)g_commandList, 1, heaps);

    // Set global root signature and parameters
    g_commandList->lpVtbl->SetComputeRootSignature(
        (ID3D12GraphicsCommandList*)g_commandList, g_globalRootSig);

    gpuHandle = GetGPUDescriptorHandleForHeapStart(g_srvUavHeap);
    g_commandList->lpVtbl->SetComputeRootDescriptorTable(
        (ID3D12GraphicsCommandList*)g_commandList, 0, gpuHandle);  // UAV
    g_commandList->lpVtbl->SetComputeRootShaderResourceView(
        (ID3D12GraphicsCommandList*)g_commandList, 1,
        g_topLevelAS->lpVtbl->GetGPUVirtualAddress(g_topLevelAS));  // TLAS

    // Set pipeline state object
    g_commandList->lpVtbl->SetPipelineState1(g_commandList, g_stateObject);

    // DispatchRays
    recordSize = (UINT)AlignUp(
        D3D12_SHADER_IDENTIFIER_SIZE_IN_BYTES,
        D3D12_RAYTRACING_SHADER_TABLE_BYTE_ALIGNMENT);

    ZeroMemory(&dispatchDesc, sizeof(dispatchDesc));

    dispatchDesc.RayGenerationShaderRecord.StartAddress =
        g_shaderTable->lpVtbl->GetGPUVirtualAddress(g_shaderTable) + recordSize * 0;
    dispatchDesc.RayGenerationShaderRecord.SizeInBytes = recordSize;

    dispatchDesc.MissShaderTable.StartAddress =
        g_shaderTable->lpVtbl->GetGPUVirtualAddress(g_shaderTable) + recordSize * 1;
    dispatchDesc.MissShaderTable.SizeInBytes  = recordSize;
    dispatchDesc.MissShaderTable.StrideInBytes = recordSize;

    dispatchDesc.HitGroupTable.StartAddress =
        g_shaderTable->lpVtbl->GetGPUVirtualAddress(g_shaderTable) + recordSize * 2;
    dispatchDesc.HitGroupTable.SizeInBytes  = recordSize;
    dispatchDesc.HitGroupTable.StrideInBytes = recordSize;

    dispatchDesc.Width  = WIDTH;
    dispatchDesc.Height = HEIGHT;
    dispatchDesc.Depth  = 1;

    g_commandList->lpVtbl->DispatchRays(g_commandList, &dispatchDesc);

    // Copy output texture to back buffer
    ZeroMemory(barriers, sizeof(barriers));

    // Output texture: UAV -> COPY_SOURCE
    barriers[0].Type                   = D3D12_RESOURCE_BARRIER_TYPE_TRANSITION;
    barriers[0].Transition.pResource   = g_outputResource;
    barriers[0].Transition.StateBefore = D3D12_RESOURCE_STATE_UNORDERED_ACCESS;
    barriers[0].Transition.StateAfter  = D3D12_RESOURCE_STATE_COPY_SOURCE;
    barriers[0].Transition.Subresource = D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES;

    // Back buffer: PRESENT -> COPY_DEST
    barriers[1].Type                   = D3D12_RESOURCE_BARRIER_TYPE_TRANSITION;
    barriers[1].Transition.pResource   = g_renderTargets[g_frameIndex];
    barriers[1].Transition.StateBefore = D3D12_RESOURCE_STATE_PRESENT;
    barriers[1].Transition.StateAfter  = D3D12_RESOURCE_STATE_COPY_DEST;
    barriers[1].Transition.Subresource = D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES;

    g_commandList->lpVtbl->ResourceBarrier(
        (ID3D12GraphicsCommandList*)g_commandList, 2, barriers);
    g_commandList->lpVtbl->CopyResource(
        (ID3D12GraphicsCommandList*)g_commandList,
        g_renderTargets[g_frameIndex], g_outputResource);

    // Restore states
    barriers[0].Transition.StateBefore = D3D12_RESOURCE_STATE_COPY_SOURCE;
    barriers[0].Transition.StateAfter  = D3D12_RESOURCE_STATE_UNORDERED_ACCESS;
    barriers[1].Transition.StateBefore = D3D12_RESOURCE_STATE_COPY_DEST;
    barriers[1].Transition.StateAfter  = D3D12_RESOURCE_STATE_PRESENT;
    g_commandList->lpVtbl->ResourceBarrier(
        (ID3D12GraphicsCommandList*)g_commandList, 2, barriers);

    CHECK_HR(
        g_commandList->lpVtbl->Close((ID3D12GraphicsCommandList*)g_commandList),
        "Close");
    lists[0] = (ID3D12CommandList*)g_commandList;
    g_commandQueue->lpVtbl->ExecuteCommandLists(g_commandQueue, 1, lists);

    CHECK_HR(
        g_swapChain->lpVtbl->Present((IDXGISwapChain*)g_swapChain, 1, 0),
        "Present");
    WaitForGPU();
    g_frameIndex = g_swapChain->lpVtbl->GetCurrentBackBufferIndex(g_swapChain);
}

// =============================================================================
// Cleanup
// =============================================================================
static void Cleanup(void)
{
#define SAFE_RELEASE(p) do { if (p) { ((IUnknown*)(p))->lpVtbl->Release((IUnknown*)(p)); (p) = NULL; } } while(0)
    UINT i;
    SAFE_RELEASE(g_shaderTable);
    SAFE_RELEASE(g_outputResource);
    SAFE_RELEASE(g_srvUavHeap);
    SAFE_RELEASE(g_globalRootSig);
    SAFE_RELEASE(g_stateObject);
    SAFE_RELEASE(g_instanceBuffer);
    SAFE_RELEASE(g_topLevelAS);
    SAFE_RELEASE(g_bottomLevelAS);
    SAFE_RELEASE(g_scratchBLAS);
    SAFE_RELEASE(g_scratchTLAS);
    SAFE_RELEASE(g_vertexBuffer);
    SAFE_RELEASE(g_fence);
    SAFE_RELEASE(g_commandList);
    SAFE_RELEASE(g_commandAllocator);
    for (i = 0; i < FRAME_COUNT; i++)
        SAFE_RELEASE(g_renderTargets[i]);
    SAFE_RELEASE(g_rtvHeap);
    SAFE_RELEASE(g_swapChain);
    SAFE_RELEASE(g_commandQueue);
    SAFE_RELEASE(g_device);
    SAFE_RELEASE(g_factory);
#undef SAFE_RELEASE
}

// =============================================================================
// Window Procedure
// =============================================================================
static LRESULT CALLBACK WndProc(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam)
{
    switch (msg)
    {
    case WM_KEYDOWN:
        if (wParam == VK_ESCAPE) PostQuitMessage(0);
        return 0;
    case WM_DESTROY:
        PostQuitMessage(0);
        return 0;
    }
    return DefWindowProc(hwnd, msg, wParam, lParam);
}

// =============================================================================
// Entry Point
// =============================================================================
int WINAPI WinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, LPSTR lpCmdLine, int nCmdShow)
{
    MSG msg;
    WNDCLASSEXW wc;
    RECT rc;

    (void)hPrevInstance;
    (void)lpCmdLine;

    DebugLog("[DXR] ====== DXR Triangle Sample (C) START ======\n");

    // Register window class
    ZeroMemory(&wc, sizeof(wc));
    wc.cbSize        = sizeof(WNDCLASSEXW);
    wc.style         = CS_HREDRAW | CS_VREDRAW;
    wc.lpfnWndProc   = WndProc;
    wc.hInstance      = hInstance;
    wc.hCursor        = LoadCursor(NULL, IDC_ARROW);
    wc.lpszClassName  = L"DXRTriangleC";
    RegisterClassExW(&wc);

    // Create window
    rc.left   = 0;
    rc.top    = 0;
    rc.right  = WIDTH;
    rc.bottom = HEIGHT;
    AdjustWindowRect(&rc, WS_OVERLAPPEDWINDOW, FALSE);
    g_hwnd = CreateWindowExW(0, L"DXRTriangleC", L"DXR Triangle Sample (C)",
        WS_OVERLAPPEDWINDOW, CW_USEDEFAULT, CW_USEDEFAULT,
        rc.right - rc.left, rc.bottom - rc.top,
        NULL, NULL, hInstance, NULL);
    ShowWindow(g_hwnd, nCmdShow);

    // Initialize
    InitD3D12();
    CreateVertexBuffer();
    BuildAccelerationStructures();
    CreateRootSignature();
    CreateRaytracingPipeline();
    CreateOutputResource();
    CreateShaderTable();

    // Close the command list before entering the render loop
    g_commandList->lpVtbl->Close((ID3D12GraphicsCommandList*)g_commandList);

    DebugLog("[DXR] ====== Initialization COMPLETE - entering render loop ======\n");

    // Message loop
    ZeroMemory(&msg, sizeof(msg));
    while (msg.message != WM_QUIT)
    {
        if (PeekMessage(&msg, NULL, 0, 0, PM_REMOVE))
        {
            TranslateMessage(&msg);
            DispatchMessage(&msg);
        }
        else
        {
            Render();
        }
    }

    WaitForGPU();
    CloseHandle(g_fenceEvent);
    Cleanup();

    DebugLog("[DXR] ====== DXR Triangle Sample (C) END ======\n");
    return 0;
}
