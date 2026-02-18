/*
 * Harmonograph Visualizer - DirectX 12 with Compute Shader (C++/CLI)
 *
 * Uses a compute shader (CSMain) to calculate 500,000 harmonograph vertices
 * in parallel, then renders them as a line strip with a 3D camera using
 * vertex (VSMain) and pixel (PSMain) shaders from hello.hlsl.
 *
 * Build: cl /clr harmonograph.cpp /link d3d12.lib dxgi.lib d3dcompiler.lib
 */

#include <windows.h>
#include <tchar.h>
#include <d3d12.h>
#include <dxgi1_4.h>
#include <d3dcompiler.h>
#include <directxmath.h>
#include <cmath>

#pragma comment(lib, "d3d12.lib")
#pragma comment(lib, "dxgi.lib")
#pragma comment(lib, "d3dcompiler.lib")

#define WINDOW_WIDTH    800
#define WINDOW_HEIGHT   600
#define VERTEX_COUNT    100000
#define FRAME_COUNT     2

using namespace DirectX;

/* -------------------------------------------------------------------------
 * Constant buffer layout - must match cbuffer HarmonographParams in HLSL
 * ------------------------------------------------------------------------- */
struct HarmonographParams
{
    float A1, f1, p1, d1;
    float A2, f2, p2, d2;
    float A3, f3, p3, d3;
    float A4, f4, p4, d4;
    UINT  max_num;
    float padding[3];
    float resolution[2];
    float padding2[2];
};

/* -------------------------------------------------------------------------
 * Helper: create common heap properties
 * ------------------------------------------------------------------------- */
inline D3D12_HEAP_PROPERTIES HeapProps(D3D12_HEAP_TYPE type)
{
    D3D12_HEAP_PROPERTIES p = {};
    p.Type                 = type;
    p.CPUPageProperty      = D3D12_CPU_PAGE_PROPERTY_UNKNOWN;
    p.MemoryPoolPreference = D3D12_MEMORY_POOL_UNKNOWN;
    p.CreationNodeMask     = 1;
    p.VisibleNodeMask      = 1;
    return p;
}

/* -------------------------------------------------------------------------
 * Helper: create a buffer resource descriptor
 * ------------------------------------------------------------------------- */
inline D3D12_RESOURCE_DESC BufferDesc(UINT64 width, D3D12_RESOURCE_FLAGS flags = D3D12_RESOURCE_FLAG_NONE)
{
    D3D12_RESOURCE_DESC d = {};
    d.Dimension          = D3D12_RESOURCE_DIMENSION_BUFFER;
    d.Width              = width;
    d.Height             = 1;
    d.DepthOrArraySize   = 1;
    d.MipLevels          = 1;
    d.Format             = DXGI_FORMAT_UNKNOWN;
    d.SampleDesc.Count   = 1;
    d.Layout             = D3D12_TEXTURE_LAYOUT_ROW_MAJOR;
    d.Flags              = flags;
    return d;
}

/* -------------------------------------------------------------------------
 * Helper: create a resource transition barrier
 * ------------------------------------------------------------------------- */
inline D3D12_RESOURCE_BARRIER TransitionBarrier(
    ID3D12Resource*       res,
    D3D12_RESOURCE_STATES before,
    D3D12_RESOURCE_STATES after)
{
    D3D12_RESOURCE_BARRIER b = {};
    b.Type                   = D3D12_RESOURCE_BARRIER_TYPE_TRANSITION;
    b.Transition.pResource   = res;
    b.Transition.StateBefore = before;
    b.Transition.StateAfter  = after;
    b.Transition.Subresource = D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES;
    return b;
}

#define SAFE_RELEASE(p) { if(p) { (p)->Release(); (p) = nullptr; } }

/* -------------------------------------------------------------------------
 * Globals - Device & swap chain
 * ------------------------------------------------------------------------- */
static ID3D12Device*              g_device            = nullptr;
static IDXGISwapChain3*           g_swapChain         = nullptr;
static ID3D12CommandQueue*        g_commandQueue      = nullptr;
static ID3D12CommandAllocator*    g_commandAllocator  = nullptr;
static ID3D12GraphicsCommandList* g_commandList       = nullptr;

/* Render targets */
static ID3D12Resource*            g_renderTargets[FRAME_COUNT] = {};
static ID3D12DescriptorHeap*      g_rtvHeap           = nullptr;
static UINT                       g_rtvDescSize       = 0;
static UINT                       g_frameIndex        = 0;

/* Fence for CPU/GPU synchronization */
static ID3D12Fence*               g_fence             = nullptr;
static HANDLE                     g_fenceEvent        = nullptr;
static UINT64                     g_fenceValue        = 0;

/* Viewport / scissor */
static D3D12_VIEWPORT g_viewport    = { 0,0,(FLOAT)WINDOW_WIDTH,(FLOAT)WINDOW_HEIGHT,0,1 };
static D3D12_RECT     g_scissorRect = { 0,0,WINDOW_WIDTH,WINDOW_HEIGHT };

/* -------------------------------------------------------------------------
 * Globals - Compute pipeline
 * (root signature, PSO, constant buffer)
 * ------------------------------------------------------------------------- */
static ID3D12RootSignature*       g_computeRS         = nullptr;
static ID3D12PipelineState*       g_computePSO        = nullptr;

/* -------------------------------------------------------------------------
 * Globals - Graphics pipeline
 * (root signature, PSO)
 * ------------------------------------------------------------------------- */
static ID3D12RootSignature*       g_graphicsRS        = nullptr;
static ID3D12PipelineState*       g_graphicsPSO       = nullptr;

/* -------------------------------------------------------------------------
 * Globals - Shared resources
 * Descriptor heap layout (CBV_SRV_UAV):
 *   [0] CBV  b0 - constant buffer (shared by compute & graphics)
 *   [1] UAV  u0 - positionBuffer  (compute writes)
 *   [2] UAV  u1 - colorBuffer     (compute writes)
 *   [3] SRV  t0 - positionSRV     (vertex shader reads)
 *   [4] SRV  t1 - colorSRV        (vertex shader reads)
 * ------------------------------------------------------------------------- */
static ID3D12DescriptorHeap*      g_cbvSrvUavHeap     = nullptr;
static UINT                       g_cbvSrvUavDescSize = 0;

static ID3D12Resource*            g_positionBuffer    = nullptr; /* UAV/SRV */
static ID3D12Resource*            g_colorBuffer       = nullptr; /* UAV/SRV */
static ID3D12Resource*            g_constantBuffer    = nullptr; /* CBV      */
static HarmonographParams*        g_cbMapped          = nullptr; /* persistent map */

/* -------------------------------------------------------------------------
 * Animation state - matches C# version initial values and per-frame update
 *   f1, f2 slowly drift each frame (random walk, same scale as C# rand/200)
 *   p1 rotates each frame by PI2 * 0.5 / 360
 * ------------------------------------------------------------------------- */
static float g_A1 = 50.0f, g_f1 = 2.0f,          g_p1 = 1.0f / 16.0f,  g_d1 = 0.0200f;
static float g_A2 = 50.0f, g_f2 = 2.0f,          g_p2 = 3.0f / 2.0f,   g_d2 = 0.0315f;
static float g_A3 = 50.0f, g_f3 = 2.0f,          g_p3 = 13.0f / 15.0f, g_d3 = 0.0200f;
static float g_A4 = 50.0f, g_f4 = 2.0f,          g_p4 = 1.0f,          g_d4 = 0.0200f;

static const float PI2 = 6.283185307179586f;

/* Simple LCG for deterministic random walk, scale = rand()/200 matching C# */
static UINT g_randState = 12345;
static float NextRand()
{
    g_randState = g_randState * 1664525u + 1013904223u;
    return (float)(g_randState >> 8) / (float)(1 << 24) / 200.0f;
}

/* -------------------------------------------------------------------------
 * Forward declarations
 * ------------------------------------------------------------------------- */
LRESULT CALLBACK WindowProc(HWND, UINT, WPARAM, LPARAM);
HRESULT OnInit(HWND);
HRESULT InitDevice(HWND);
HRESULT InitView();
HRESULT InitDescriptorHeap();
HRESULT InitRootSignatures();
HRESULT InitPipelines();
HRESULT InitResources();
HRESULT InitFence();
void    UpdateConstantBuffer();
void    OnRender();
void    WaitForPreviousFrame();
void    OnDestroy();

/* =========================================================================
 * WinMain
 * ========================================================================= */
int APIENTRY _tWinMain(HINSTANCE hInstance, HINSTANCE, LPTSTR, int nCmdShow)
{
    WNDCLASSEX wc = {};
    wc.cbSize        = sizeof(WNDCLASSEX);
    wc.style         = CS_HREDRAW | CS_VREDRAW;
    wc.lpfnWndProc   = WindowProc;
    wc.hInstance     = hInstance;
    wc.hCursor       = LoadCursor(nullptr, IDC_ARROW);
    wc.lpszClassName = _T("HarmonographDX12");
    RegisterClassEx(&wc);

    RECT r = { 0, 0, WINDOW_WIDTH, WINDOW_HEIGHT };
    AdjustWindowRect(&r, WS_OVERLAPPEDWINDOW, FALSE);

    HWND hWnd = CreateWindow(
        _T("HarmonographDX12"),
        _T("Harmonograph - DirectX 12 Compute Shader (C++/CLI)"),
        WS_OVERLAPPEDWINDOW,
        CW_USEDEFAULT, CW_USEDEFAULT,
        r.right - r.left, r.bottom - r.top,
        nullptr, nullptr, hInstance, nullptr);

    MSG msg = {};
    if (SUCCEEDED(OnInit(hWnd)))
    {
        ShowWindow(hWnd, nCmdShow);

        while (msg.message != WM_QUIT)
        {
            if (PeekMessage(&msg, nullptr, 0, 0, PM_REMOVE))
            {
                TranslateMessage(&msg);
                DispatchMessage(&msg);
            }
            else
            {
                OnRender();
            }
        }
    }

    return static_cast<int>(msg.wParam);
}

LRESULT CALLBACK WindowProc(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam)
{
    switch (msg)
    {
    case WM_KEYDOWN:
        if (wParam == VK_ESCAPE) PostQuitMessage(0);
        break;
    case WM_DESTROY:
        OnDestroy();
        PostQuitMessage(0);
        return 0;
    }
    return DefWindowProc(hWnd, msg, wParam, lParam);
}

/* =========================================================================
 * OnInit - call all initialization steps in order
 * ========================================================================= */
HRESULT OnInit(HWND hWnd)
{
    if (FAILED(InitDevice(hWnd)))       return E_FAIL;
    if (FAILED(InitView()))             return E_FAIL;
    if (FAILED(InitDescriptorHeap()))   return E_FAIL;
    if (FAILED(InitRootSignatures()))   return E_FAIL;
    if (FAILED(InitPipelines()))        return E_FAIL;
    if (FAILED(InitResources()))        return E_FAIL;
    if (FAILED(InitFence()))            return E_FAIL;
    return S_OK;
}

/* =========================================================================
 * InitDevice - create D3D12 device, command queue, and swap chain
 * ========================================================================= */
HRESULT InitDevice(HWND hWnd)
{
    IDXGIFactory4* factory = nullptr;
    if (FAILED(CreateDXGIFactory2(0, IID_PPV_ARGS(&factory))))
        return E_FAIL;

    /* Try hardware adapters first */
    HRESULT hr = E_FAIL;
    IDXGIAdapter1* adapter = nullptr;
    for (UINT i = 0; factory->EnumAdapters1(i, &adapter) != DXGI_ERROR_NOT_FOUND; ++i)
    {
        DXGI_ADAPTER_DESC1 desc;
        adapter->GetDesc1(&desc);
        if (desc.Flags & DXGI_ADAPTER_FLAG_SOFTWARE) { SAFE_RELEASE(adapter); continue; }

        hr = D3D12CreateDevice(adapter, D3D_FEATURE_LEVEL_11_0, IID_PPV_ARGS(&g_device));
        SAFE_RELEASE(adapter);
        if (SUCCEEDED(hr)) break;
    }

    /* Fall back to WARP software renderer */
    if (FAILED(hr))
    {
        IDXGIAdapter* warp = nullptr;
        factory->EnumWarpAdapter(IID_PPV_ARGS(&warp));
        hr = D3D12CreateDevice(warp, D3D_FEATURE_LEVEL_11_0, IID_PPV_ARGS(&g_device));
        SAFE_RELEASE(warp);
        if (FAILED(hr)) { SAFE_RELEASE(factory); return E_FAIL; }
    }

    /* Direct command queue */
    D3D12_COMMAND_QUEUE_DESC qd = {};
    qd.Type  = D3D12_COMMAND_LIST_TYPE_DIRECT;
    qd.Flags = D3D12_COMMAND_QUEUE_FLAG_NONE;
    if (FAILED(g_device->CreateCommandQueue(&qd, IID_PPV_ARGS(&g_commandQueue))))
    { SAFE_RELEASE(factory); return E_FAIL; }

    /* Swap chain */
    DXGI_SWAP_CHAIN_DESC1 scd = {};
    scd.BufferCount = FRAME_COUNT;
    scd.Width       = WINDOW_WIDTH;
    scd.Height      = WINDOW_HEIGHT;
    scd.Format      = DXGI_FORMAT_R8G8B8A8_UNORM;
    scd.BufferUsage = DXGI_USAGE_RENDER_TARGET_OUTPUT;
    scd.SwapEffect  = DXGI_SWAP_EFFECT_FLIP_DISCARD;
    scd.SampleDesc.Count = 1;

    IDXGISwapChain1* sc1 = nullptr;
    if (FAILED(factory->CreateSwapChainForHwnd(g_commandQueue, hWnd, &scd, nullptr, nullptr, &sc1)))
    { SAFE_RELEASE(factory); return E_FAIL; }

    factory->MakeWindowAssociation(hWnd, DXGI_MWA_NO_ALT_ENTER);
    sc1->QueryInterface(IID_PPV_ARGS(&g_swapChain));
    SAFE_RELEASE(sc1);
    SAFE_RELEASE(factory);

    g_frameIndex = g_swapChain->GetCurrentBackBufferIndex();

    /* Command allocator */
    if (FAILED(g_device->CreateCommandAllocator(D3D12_COMMAND_LIST_TYPE_DIRECT,
        IID_PPV_ARGS(&g_commandAllocator))))
        return E_FAIL;

    return S_OK;
}

/* =========================================================================
 * InitView - create RTV descriptor heap and render target views
 * ========================================================================= */
HRESULT InitView()
{
    D3D12_DESCRIPTOR_HEAP_DESC hd = {};
    hd.NumDescriptors = FRAME_COUNT;
    hd.Type           = D3D12_DESCRIPTOR_HEAP_TYPE_RTV;
    hd.Flags          = D3D12_DESCRIPTOR_HEAP_FLAG_NONE;
    if (FAILED(g_device->CreateDescriptorHeap(&hd, IID_PPV_ARGS(&g_rtvHeap))))
        return E_FAIL;

    g_rtvDescSize = g_device->GetDescriptorHandleIncrementSize(D3D12_DESCRIPTOR_HEAP_TYPE_RTV);

    D3D12_CPU_DESCRIPTOR_HANDLE rtvH = g_rtvHeap->GetCPUDescriptorHandleForHeapStart();
    for (UINT i = 0; i < FRAME_COUNT; i++)
    {
        if (FAILED(g_swapChain->GetBuffer(i, IID_PPV_ARGS(&g_renderTargets[i]))))
            return E_FAIL;
        g_device->CreateRenderTargetView(g_renderTargets[i], nullptr, rtvH);
        rtvH.ptr += g_rtvDescSize;
    }
    return S_OK;
}

/* =========================================================================
 * InitDescriptorHeap - create CBV/SRV/UAV heap (5 descriptors)
 *   [0] CBV b0, [1] UAV u0, [2] UAV u1, [3] SRV t0, [4] SRV t1
 * ========================================================================= */
HRESULT InitDescriptorHeap()
{
    D3D12_DESCRIPTOR_HEAP_DESC hd = {};
    hd.NumDescriptors = 5;  /* CBV + 2 UAV + 2 SRV */
    hd.Type           = D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV;
    hd.Flags          = D3D12_DESCRIPTOR_HEAP_FLAG_SHADER_VISIBLE;
    if (FAILED(g_device->CreateDescriptorHeap(&hd, IID_PPV_ARGS(&g_cbvSrvUavHeap))))
        return E_FAIL;

    g_cbvSrvUavDescSize = g_device->GetDescriptorHandleIncrementSize(
        D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV);

    return S_OK;
}

/* =========================================================================
 * InitRootSignatures
 *
 * Compute root signature:
 *   param 0: CBV  (b0) - harmonograph parameters
 *   param 1: Descriptor table: UAV u0, UAV u1
 *
 * Graphics root signature:
 *   param 0: CBV  (b0) - harmonograph parameters (resolution)
 *   param 1: Descriptor table: SRV t0, SRV t1
 * ========================================================================= */
HRESULT InitRootSignatures()
{
    HRESULT hr;

    /* ---- Compute root signature ---- */
    {
        D3D12_DESCRIPTOR_RANGE uavRange = {};
        uavRange.RangeType          = D3D12_DESCRIPTOR_RANGE_TYPE_UAV;
        uavRange.NumDescriptors     = 2;    /* u0, u1 */
        uavRange.BaseShaderRegister = 0;
        uavRange.RegisterSpace      = 0;
        uavRange.OffsetInDescriptorsFromTableStart = D3D12_DESCRIPTOR_RANGE_OFFSET_APPEND;

        D3D12_ROOT_PARAMETER params[2] = {};

        /* param 0: root CBV b0 */
        params[0].ParameterType    = D3D12_ROOT_PARAMETER_TYPE_CBV;
        params[0].Descriptor.ShaderRegister = 0;
        params[0].Descriptor.RegisterSpace  = 0;
        params[0].ShaderVisibility = D3D12_SHADER_VISIBILITY_ALL;

        /* param 1: descriptor table for UAVs */
        params[1].ParameterType                       = D3D12_ROOT_PARAMETER_TYPE_DESCRIPTOR_TABLE;
        params[1].DescriptorTable.NumDescriptorRanges = 1;
        params[1].DescriptorTable.pDescriptorRanges   = &uavRange;
        params[1].ShaderVisibility = D3D12_SHADER_VISIBILITY_ALL;

        D3D12_ROOT_SIGNATURE_DESC rsd = {};
        rsd.NumParameters = 2;
        rsd.pParameters   = params;
        rsd.Flags         = D3D12_ROOT_SIGNATURE_FLAG_NONE;

        ID3DBlob* sig = nullptr;
        ID3DBlob* err = nullptr;
        hr = D3D12SerializeRootSignature(&rsd, D3D_ROOT_SIGNATURE_VERSION_1, &sig, &err);
        if (FAILED(hr)) { if (err) { OutputDebugStringA((char*)err->GetBufferPointer()); SAFE_RELEASE(err); } return E_FAIL; }

        hr = g_device->CreateRootSignature(0, sig->GetBufferPointer(), sig->GetBufferSize(),
            IID_PPV_ARGS(&g_computeRS));
        SAFE_RELEASE(sig);
        if (FAILED(hr)) return E_FAIL;
    }

    /* ---- Graphics root signature ---- */
    {
        D3D12_DESCRIPTOR_RANGE srvRange = {};
        srvRange.RangeType          = D3D12_DESCRIPTOR_RANGE_TYPE_SRV;
        srvRange.NumDescriptors     = 2;    /* t0, t1 */
        srvRange.BaseShaderRegister = 0;
        srvRange.RegisterSpace      = 0;
        srvRange.OffsetInDescriptorsFromTableStart = D3D12_DESCRIPTOR_RANGE_OFFSET_APPEND;

        D3D12_ROOT_PARAMETER params[2] = {};

        /* param 0: root CBV b0 */
        params[0].ParameterType    = D3D12_ROOT_PARAMETER_TYPE_CBV;
        params[0].Descriptor.ShaderRegister = 0;
        params[0].Descriptor.RegisterSpace  = 0;
        params[0].ShaderVisibility = D3D12_SHADER_VISIBILITY_ALL;

        /* param 1: descriptor table for SRVs */
        params[1].ParameterType                       = D3D12_ROOT_PARAMETER_TYPE_DESCRIPTOR_TABLE;
        params[1].DescriptorTable.NumDescriptorRanges = 1;
        params[1].DescriptorTable.pDescriptorRanges   = &srvRange;
        params[1].ShaderVisibility = D3D12_SHADER_VISIBILITY_ALL;

        D3D12_ROOT_SIGNATURE_DESC rsd = {};
        rsd.NumParameters = 2;
        rsd.pParameters   = params;
        /* Allow vertex shader to read from SRV without input layout */
        rsd.Flags = D3D12_ROOT_SIGNATURE_FLAG_NONE;

        ID3DBlob* sig = nullptr;
        ID3DBlob* err = nullptr;
        hr = D3D12SerializeRootSignature(&rsd, D3D_ROOT_SIGNATURE_VERSION_1, &sig, &err);
        if (FAILED(hr)) { if (err) { OutputDebugStringA((char*)err->GetBufferPointer()); SAFE_RELEASE(err); } return E_FAIL; }

        hr = g_device->CreateRootSignature(0, sig->GetBufferPointer(), sig->GetBufferSize(),
            IID_PPV_ARGS(&g_graphicsRS));
        SAFE_RELEASE(sig);
        if (FAILED(hr)) return E_FAIL;
    }

    return S_OK;
}

/* =========================================================================
 * InitPipelines - compile hello.hlsl and create compute + graphics PSOs
 * ========================================================================= */
HRESULT InitPipelines()
{
    HRESULT hr;
    UINT compileFlags = 0;

    /* Compile compute shader (CSMain) */
    ID3DBlob* csBlob  = nullptr;
    ID3DBlob* errBlob = nullptr;
    hr = D3DCompileFromFile(L"hello.hlsl", nullptr, nullptr,
        "CSMain", "cs_5_0", compileFlags, 0, &csBlob, &errBlob);
    if (FAILED(hr))
    {
        if (errBlob) { OutputDebugStringA((char*)errBlob->GetBufferPointer()); SAFE_RELEASE(errBlob); }
        return E_FAIL;
    }
    SAFE_RELEASE(errBlob);

    /* Compute PSO */
    D3D12_COMPUTE_PIPELINE_STATE_DESC cpsd = {};
    cpsd.pRootSignature = g_computeRS;
    cpsd.CS             = { csBlob->GetBufferPointer(), csBlob->GetBufferSize() };
    hr = g_device->CreateComputePipelineState(&cpsd, IID_PPV_ARGS(&g_computePSO));
    SAFE_RELEASE(csBlob);
    if (FAILED(hr)) return E_FAIL;

    /* Compile vertex shader (VSMain) */
    ID3DBlob* vsBlob = nullptr;
    hr = D3DCompileFromFile(L"hello.hlsl", nullptr, nullptr,
        "VSMain", "vs_5_0", compileFlags, 0, &vsBlob, &errBlob);
    if (FAILED(hr))
    {
        if (errBlob) { OutputDebugStringA((char*)errBlob->GetBufferPointer()); SAFE_RELEASE(errBlob); }
        return E_FAIL;
    }
    SAFE_RELEASE(errBlob);

    /* Compile pixel shader (PSMain) */
    ID3DBlob* psBlob = nullptr;
    hr = D3DCompileFromFile(L"hello.hlsl", nullptr, nullptr,
        "PSMain", "ps_5_0", compileFlags, 0, &psBlob, &errBlob);
    if (FAILED(hr))
    {
        SAFE_RELEASE(vsBlob);
        if (errBlob) { OutputDebugStringA((char*)errBlob->GetBufferPointer()); SAFE_RELEASE(errBlob); }
        return E_FAIL;
    }
    SAFE_RELEASE(errBlob);

    /* Rasterizer state - standard solid/back-cull */
    D3D12_RASTERIZER_DESC rast = {};
    rast.FillMode = D3D12_FILL_MODE_SOLID;
    rast.CullMode = D3D12_CULL_MODE_NONE;   /* both sides visible for line strip */
    rast.DepthClipEnable = TRUE;

    /* Blend state - alpha blend for nice line rendering */
    D3D12_BLEND_DESC blend = {};
    blend.RenderTarget[0].BlendEnable           = TRUE;
    blend.RenderTarget[0].SrcBlend              = D3D12_BLEND_SRC_ALPHA;
    blend.RenderTarget[0].DestBlend             = D3D12_BLEND_INV_SRC_ALPHA;
    blend.RenderTarget[0].BlendOp               = D3D12_BLEND_OP_ADD;
    blend.RenderTarget[0].SrcBlendAlpha         = D3D12_BLEND_ONE;
    blend.RenderTarget[0].DestBlendAlpha        = D3D12_BLEND_ZERO;
    blend.RenderTarget[0].BlendOpAlpha          = D3D12_BLEND_OP_ADD;
    blend.RenderTarget[0].RenderTargetWriteMask = D3D12_COLOR_WRITE_ENABLE_ALL;

    /* Graphics PSO - no input layout; vertex positions come from SRV */
    D3D12_GRAPHICS_PIPELINE_STATE_DESC gpsd = {};
    gpsd.pRootSignature        = g_graphicsRS;
    gpsd.VS                    = { vsBlob->GetBufferPointer(), vsBlob->GetBufferSize() };
    gpsd.PS                    = { psBlob->GetBufferPointer(), psBlob->GetBufferSize() };
    gpsd.RasterizerState       = rast;
    gpsd.BlendState            = blend;
    gpsd.DepthStencilState.DepthEnable   = FALSE;
    gpsd.DepthStencilState.StencilEnable = FALSE;
    gpsd.SampleMask            = UINT_MAX;
    gpsd.PrimitiveTopologyType = D3D12_PRIMITIVE_TOPOLOGY_TYPE_LINE;
    gpsd.NumRenderTargets      = 1;
    gpsd.RTVFormats[0]         = DXGI_FORMAT_R8G8B8A8_UNORM;
    gpsd.SampleDesc.Count      = 1;
    /* No InputLayout - vertex shader uses SV_VertexID to index into SRV */

    hr = g_device->CreateGraphicsPipelineState(&gpsd, IID_PPV_ARGS(&g_graphicsPSO));
    SAFE_RELEASE(vsBlob);
    SAFE_RELEASE(psBlob);
    if (FAILED(hr)) return E_FAIL;

    return S_OK;
}

/* =========================================================================
 * InitResources - create constant buffer, position/color UAV buffers,
 *                 and fill the CBV/UAV/SRV descriptor heap
 * ========================================================================= */
HRESULT InitResources()
{
    HRESULT hr;
    const UINT64 vertexBufSize = (UINT64)VERTEX_COUNT * sizeof(XMFLOAT4);

    /* ---- Constant buffer (upload heap, persistently mapped) ---- */
    {
        /* Align to 256 bytes as required by DirectX 12 */
        UINT64 cbSize = (sizeof(HarmonographParams) + 255) & ~255ull;
        auto hp = HeapProps(D3D12_HEAP_TYPE_UPLOAD);
        auto bd = BufferDesc(cbSize);

        hr = g_device->CreateCommittedResource(&hp, D3D12_HEAP_FLAG_NONE, &bd,
            D3D12_RESOURCE_STATE_GENERIC_READ, nullptr,
            IID_PPV_ARGS(&g_constantBuffer));
        if (FAILED(hr)) return E_FAIL;

        /* Map persistently; safe because it is on an upload heap */
        D3D12_RANGE readRange = { 0, 0 };
        hr = g_constantBuffer->Map(0, &readRange,
            reinterpret_cast<void**>(&g_cbMapped));
        if (FAILED(hr)) return E_FAIL;

        /* Write initial constant buffer content */
        UpdateConstantBuffer();
    }

    /* ---- Position buffer (DEFAULT heap, UAV + SRV) ---- */
    {
        auto hp = HeapProps(D3D12_HEAP_TYPE_DEFAULT);
        auto bd = BufferDesc(vertexBufSize, D3D12_RESOURCE_FLAG_ALLOW_UNORDERED_ACCESS);

        hr = g_device->CreateCommittedResource(&hp, D3D12_HEAP_FLAG_NONE, &bd,
            D3D12_RESOURCE_STATE_UNORDERED_ACCESS, nullptr,
            IID_PPV_ARGS(&g_positionBuffer));
        if (FAILED(hr)) return E_FAIL;
    }

    /* ---- Color buffer (DEFAULT heap, UAV + SRV) ---- */
    {
        auto hp = HeapProps(D3D12_HEAP_TYPE_DEFAULT);
        auto bd = BufferDesc(vertexBufSize, D3D12_RESOURCE_FLAG_ALLOW_UNORDERED_ACCESS);

        hr = g_device->CreateCommittedResource(&hp, D3D12_HEAP_FLAG_NONE, &bd,
            D3D12_RESOURCE_STATE_UNORDERED_ACCESS, nullptr,
            IID_PPV_ARGS(&g_colorBuffer));
        if (FAILED(hr)) return E_FAIL;
    }

    /* ---- Populate descriptor heap ---- */
    D3D12_CPU_DESCRIPTOR_HANDLE handle = g_cbvSrvUavHeap->GetCPUDescriptorHandleForHeapStart();

    /* [0] CBV b0 - constant buffer */
    {
        D3D12_CONSTANT_BUFFER_VIEW_DESC cbd = {};
        cbd.BufferLocation = g_constantBuffer->GetGPUVirtualAddress();
        cbd.SizeInBytes    = (UINT)((sizeof(HarmonographParams) + 255) & ~255u);
        g_device->CreateConstantBufferView(&cbd, handle);
        handle.ptr += g_cbvSrvUavDescSize;
    }

    /* [1] UAV u0 - positionBuffer */
    {
        D3D12_UNORDERED_ACCESS_VIEW_DESC uavd = {};
        uavd.ViewDimension              = D3D12_UAV_DIMENSION_BUFFER;
        uavd.Buffer.NumElements         = VERTEX_COUNT;
        uavd.Buffer.StructureByteStride = sizeof(XMFLOAT4);
        uavd.Buffer.Flags               = D3D12_BUFFER_UAV_FLAG_NONE;
        g_device->CreateUnorderedAccessView(g_positionBuffer, nullptr, &uavd, handle);
        handle.ptr += g_cbvSrvUavDescSize;
    }

    /* [2] UAV u1 - colorBuffer */
    {
        D3D12_UNORDERED_ACCESS_VIEW_DESC uavd = {};
        uavd.ViewDimension              = D3D12_UAV_DIMENSION_BUFFER;
        uavd.Buffer.NumElements         = VERTEX_COUNT;
        uavd.Buffer.StructureByteStride = sizeof(XMFLOAT4);
        uavd.Buffer.Flags               = D3D12_BUFFER_UAV_FLAG_NONE;
        g_device->CreateUnorderedAccessView(g_colorBuffer, nullptr, &uavd, handle);
        handle.ptr += g_cbvSrvUavDescSize;
    }

    /* [3] SRV t0 - positionSRV */
    {
        D3D12_SHADER_RESOURCE_VIEW_DESC srvd = {};
        srvd.ViewDimension              = D3D12_SRV_DIMENSION_BUFFER;
        srvd.Shader4ComponentMapping    = D3D12_DEFAULT_SHADER_4_COMPONENT_MAPPING;
        srvd.Buffer.NumElements         = VERTEX_COUNT;
        srvd.Buffer.StructureByteStride = sizeof(XMFLOAT4);
        srvd.Buffer.Flags               = D3D12_BUFFER_SRV_FLAG_NONE;
        g_device->CreateShaderResourceView(g_positionBuffer, &srvd, handle);
        handle.ptr += g_cbvSrvUavDescSize;
    }

    /* [4] SRV t1 - colorSRV */
    {
        D3D12_SHADER_RESOURCE_VIEW_DESC srvd = {};
        srvd.ViewDimension              = D3D12_SRV_DIMENSION_BUFFER;
        srvd.Shader4ComponentMapping    = D3D12_DEFAULT_SHADER_4_COMPONENT_MAPPING;
        srvd.Buffer.NumElements         = VERTEX_COUNT;
        srvd.Buffer.StructureByteStride = sizeof(XMFLOAT4);
        srvd.Buffer.Flags               = D3D12_BUFFER_SRV_FLAG_NONE;
        g_device->CreateShaderResourceView(g_colorBuffer, &srvd, handle);
        handle.ptr += g_cbvSrvUavDescSize;
    }

    /* ---- Create command list (starts closed) ---- */
    hr = g_device->CreateCommandList(0, D3D12_COMMAND_LIST_TYPE_DIRECT,
        g_commandAllocator, nullptr, IID_PPV_ARGS(&g_commandList));
    if (FAILED(hr)) return E_FAIL;
    g_commandList->Close();

    return S_OK;
}

/* =========================================================================
 * InitFence
 * ========================================================================= */
HRESULT InitFence()
{
    if (FAILED(g_device->CreateFence(0, D3D12_FENCE_FLAG_NONE, IID_PPV_ARGS(&g_fence))))
        return E_FAIL;

    g_fenceValue = 1;
    g_fenceEvent = CreateEvent(nullptr, FALSE, FALSE, nullptr);
    if (!g_fenceEvent) return E_FAIL;

    WaitForPreviousFrame();
    return S_OK;
}

/* =========================================================================
 * UpdateConstantBuffer - replicate C# Render() animation exactly:
 *   f1 = (f1 + rand()/200) % 10
 *   f2 = (f2 + rand()/200) % 10
 *   p1 += PI2 * 0.5 / 360
 * ========================================================================= */
void UpdateConstantBuffer()
{
    /* Advance animation - same logic as C# Render() */
    g_f1 = fmodf(g_f1 + NextRand(), 10.0f);
    g_f2 = fmodf(g_f2 + NextRand(), 10.0f);
    g_p1 += PI2 * 0.5f / 360.0f;

    HarmonographParams p = {};
    p.A1 = g_A1; p.f1 = g_f1; p.p1 = g_p1; p.d1 = g_d1;
    p.A2 = g_A2; p.f2 = g_f2; p.p2 = g_p2; p.d2 = g_d2;
    p.A3 = g_A3; p.f3 = g_f3; p.p3 = g_p3; p.d3 = g_d3;
    p.A4 = g_A4; p.f4 = g_f4; p.p4 = g_p4; p.d4 = g_d4;
    p.max_num       = VERTEX_COUNT;
    p.resolution[0] = (float)WINDOW_WIDTH;
    p.resolution[1] = (float)WINDOW_HEIGHT;

    memcpy(g_cbMapped, &p, sizeof(p));
}

/* =========================================================================
 * OnRender - one frame:
 *   1. Update constant buffer (animation)
 *   2. Dispatch compute shader  -> writes positionBuffer / colorBuffer as UAV
 *   3. Resource barrier UAV -> SRV
 *   4. Graphics pass: draw VERTEX_COUNT vertices as line strip
 *   5. Resource barrier SRV -> UAV  (ready for next compute pass)
 *   6. Present
 * ========================================================================= */
void OnRender()
{
    /* Advance animation time and update constant buffer */
    UpdateConstantBuffer();

    /* Descriptor heap GPU base handles */
    D3D12_GPU_DESCRIPTOR_HANDLE gpuBase =
        g_cbvSrvUavHeap->GetGPUDescriptorHandleForHeapStart();

    /* GPU handles for each descriptor slot */
    D3D12_GPU_DESCRIPTOR_HANDLE hCBV = gpuBase;
    hCBV.ptr += 0 * g_cbvSrvUavDescSize;

    D3D12_GPU_DESCRIPTOR_HANDLE hUAV = gpuBase;
    hUAV.ptr += 1 * g_cbvSrvUavDescSize;  /* UAV table starts at slot 1 */

    D3D12_GPU_DESCRIPTOR_HANDLE hSRV = gpuBase;
    hSRV.ptr += 3 * g_cbvSrvUavDescSize;  /* SRV table starts at slot 3 */

    /* Reset command allocator and list */
    g_commandAllocator->Reset();
    g_commandList->Reset(g_commandAllocator, nullptr);

    /* Set shared descriptor heap */
    ID3D12DescriptorHeap* heaps[] = { g_cbvSrvUavHeap };
    g_commandList->SetDescriptorHeaps(1, heaps);

    /* ----------------------------------------------------------------
     * Compute pass: calculate harmonograph vertices
     * ---------------------------------------------------------------- */
    g_commandList->SetComputeRootSignature(g_computeRS);
    g_commandList->SetPipelineState(g_computePSO);

    /* param 0: CBV (constant buffer GPU address) */
    g_commandList->SetComputeRootConstantBufferView(0,
        g_constantBuffer->GetGPUVirtualAddress());

    /* param 1: descriptor table starting at UAV u0 */
    g_commandList->SetComputeRootDescriptorTable(1, hUAV);

    /* Dispatch: numthreads(64,1,1) so ceil(VERTEX_COUNT / 64) groups */
    UINT groups = (VERTEX_COUNT + 63) / 64;
    g_commandList->Dispatch(groups, 1, 1);

    /* ----------------------------------------------------------------
     * Barrier: UAV -> NON_PIXEL_SHADER_RESOURCE for vertex shader reads
     * ---------------------------------------------------------------- */
    D3D12_RESOURCE_BARRIER toSRV[2] = {
        TransitionBarrier(g_positionBuffer,
            D3D12_RESOURCE_STATE_UNORDERED_ACCESS,
            D3D12_RESOURCE_STATE_NON_PIXEL_SHADER_RESOURCE),
        TransitionBarrier(g_colorBuffer,
            D3D12_RESOURCE_STATE_UNORDERED_ACCESS,
            D3D12_RESOURCE_STATE_NON_PIXEL_SHADER_RESOURCE)
    };
    g_commandList->ResourceBarrier(2, toSRV);

    /* ----------------------------------------------------------------
     * Render pass: draw harmonograph line strip
     * ---------------------------------------------------------------- */
    g_commandList->SetGraphicsRootSignature(g_graphicsRS);
    g_commandList->SetPipelineState(g_graphicsPSO);

    /* param 0: CBV */
    g_commandList->SetGraphicsRootConstantBufferView(0,
        g_constantBuffer->GetGPUVirtualAddress());

    /* param 1: descriptor table starting at SRV t0 */
    g_commandList->SetGraphicsRootDescriptorTable(1, hSRV);

    g_commandList->RSSetViewports(1, &g_viewport);
    g_commandList->RSSetScissorRects(1, &g_scissorRect);

    /* Transition render target: PRESENT -> RENDER_TARGET */
    D3D12_RESOURCE_BARRIER toRT = TransitionBarrier(
        g_renderTargets[g_frameIndex],
        D3D12_RESOURCE_STATE_PRESENT,
        D3D12_RESOURCE_STATE_RENDER_TARGET);
    g_commandList->ResourceBarrier(1, &toRT);

    D3D12_CPU_DESCRIPTOR_HANDLE rtvH = g_rtvHeap->GetCPUDescriptorHandleForHeapStart();
    rtvH.ptr += g_frameIndex * g_rtvDescSize;

    g_commandList->OMSetRenderTargets(1, &rtvH, FALSE, nullptr);

    /* Clear to dark background */
    const FLOAT clearColor[] = { 0.05f, 0.05f, 0.08f, 1.0f };
    g_commandList->ClearRenderTargetView(rtvH, clearColor, 0, nullptr);

    /* Draw all vertices as a line strip (no index buffer needed) */
    g_commandList->IASetPrimitiveTopology(D3D_PRIMITIVE_TOPOLOGY_LINESTRIP);
    g_commandList->DrawInstanced(VERTEX_COUNT, 1, 0, 0);

    /* ----------------------------------------------------------------
     * Barriers back: render target -> PRESENT,
     *                SRV buffers  -> UAV (ready for next frame's compute)
     * ---------------------------------------------------------------- */
    D3D12_RESOURCE_BARRIER toPresent = TransitionBarrier(
        g_renderTargets[g_frameIndex],
        D3D12_RESOURCE_STATE_RENDER_TARGET,
        D3D12_RESOURCE_STATE_PRESENT);
    g_commandList->ResourceBarrier(1, &toPresent);

    D3D12_RESOURCE_BARRIER toUAV[2] = {
        TransitionBarrier(g_positionBuffer,
            D3D12_RESOURCE_STATE_NON_PIXEL_SHADER_RESOURCE,
            D3D12_RESOURCE_STATE_UNORDERED_ACCESS),
        TransitionBarrier(g_colorBuffer,
            D3D12_RESOURCE_STATE_NON_PIXEL_SHADER_RESOURCE,
            D3D12_RESOURCE_STATE_UNORDERED_ACCESS)
    };
    g_commandList->ResourceBarrier(2, toUAV);

    g_commandList->Close();

    /* Submit command list */
    ID3D12CommandList* lists[] = { g_commandList };
    g_commandQueue->ExecuteCommandLists(1, lists);

    g_swapChain->Present(1, 0);

    WaitForPreviousFrame();
}

/* =========================================================================
 * WaitForPreviousFrame - signal fence and stall CPU until GPU is done
 * ========================================================================= */
void WaitForPreviousFrame()
{
    const UINT64 fence = g_fenceValue;
    g_commandQueue->Signal(g_fence, fence);
    g_fenceValue++;

    if (g_fence->GetCompletedValue() < fence)
    {
        g_fence->SetEventOnCompletion(fence, g_fenceEvent);
        WaitForSingleObject(g_fenceEvent, INFINITE);
    }

    g_frameIndex = g_swapChain->GetCurrentBackBufferIndex();
}

/* =========================================================================
 * OnDestroy - wait for GPU idle, then release all resources
 * ========================================================================= */
void OnDestroy()
{
    WaitForPreviousFrame();

    if (g_fenceEvent) { CloseHandle(g_fenceEvent); g_fenceEvent = nullptr; }

    SAFE_RELEASE(g_fence);
    SAFE_RELEASE(g_commandList);
    SAFE_RELEASE(g_computePSO);
    SAFE_RELEASE(g_graphicsPSO);
    SAFE_RELEASE(g_computeRS);
    SAFE_RELEASE(g_graphicsRS);

    if (g_constantBuffer && g_cbMapped) { g_constantBuffer->Unmap(0, nullptr); g_cbMapped = nullptr; }
    SAFE_RELEASE(g_constantBuffer);
    SAFE_RELEASE(g_positionBuffer);
    SAFE_RELEASE(g_colorBuffer);
    SAFE_RELEASE(g_cbvSrvUavHeap);
    SAFE_RELEASE(g_commandAllocator);

    for (UINT i = 0; i < FRAME_COUNT; i++) SAFE_RELEASE(g_renderTargets[i]);
    SAFE_RELEASE(g_rtvHeap);
    SAFE_RELEASE(g_swapChain);
    SAFE_RELEASE(g_commandQueue);
    SAFE_RELEASE(g_device);
}
