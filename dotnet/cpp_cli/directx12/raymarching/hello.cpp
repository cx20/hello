// raymarching.cpp
// DirectX 12 Raymarching Demo (C++/CLI style, native C++)
//
// Renders a full-screen quad and performs raymarching entirely in the pixel shader.
// The shader (hello.hlsl) evaluates signed distance functions (sphere, torus, plane)
// with soft shadows, ambient occlusion, and animated motion.
//
// Differences from the triangle sample (hello.cpp):
//   - Vertex struct holds only float2 position (no color); matches VSMain in hello.hlsl
//   - A constant buffer supplies iTime and iResolution to the shader each frame
//   - Root signature exposes one inline CBV (register b0)
//   - A full-screen quad (two triangles, six vertices) is drawn instead of one triangle

#include <windows.h>
#include <tchar.h>
#include <d3d12.h>
#include <dxgi1_4.h>
#include <d3dcompiler.h>
#include <directxmath.h>
#include <chrono>

#pragma comment(lib, "d3d12.lib")
#pragma comment(lib, "dxgi.lib")
#pragma comment(lib, "d3dcompiler.lib")

#define WINDOW_WIDTH    800
#define WINDOW_HEIGHT   600

using namespace DirectX;

// ---------------------------------------------------------------------------
// Helper macros
// ---------------------------------------------------------------------------
#define SAFE_RELEASE(p) { if (p) { (p)->Release(); (p) = nullptr; } }

// Align a value up to the nearest multiple of 'align' (must be power of two)
#define ALIGN_UP(value, align) (((value) + ((align) - 1)) & ~((align) - 1))

// ---------------------------------------------------------------------------
// Vertex layout for the full-screen quad.
// The HLSL VSMain expects: float2 position : POSITION
// ---------------------------------------------------------------------------
struct VERTEX
{
    XMFLOAT2 position;
};

// ---------------------------------------------------------------------------
// Constant buffer data that matches the HLSL cbuffer layout:
//   cbuffer ConstantBuffer : register(b0)
//   {
//       float  iTime;        // elapsed time in seconds
//       float2 iResolution;  // render target size (width, height)
//       float  padding;      // required to reach 16-byte alignment
//   };
// D3D12 requires each constant buffer to be a multiple of 256 bytes.
// ---------------------------------------------------------------------------
struct ConstantBufferData
{
    float  iTime;
    float  iResolutionX;
    float  iResolutionY;
    float  padding;
};

// ---------------------------------------------------------------------------
// Global state
// ---------------------------------------------------------------------------
static const UINT g_frameCount = 2;    // Double buffering

ID3D12Device*               g_device            = nullptr;
IDXGISwapChain3*            g_swapChain         = nullptr;
ID3D12Resource*             g_renderTargets[g_frameCount] = {};
ID3D12CommandAllocator*     g_commandAllocator  = nullptr;
ID3D12CommandQueue*         g_commandQueue      = nullptr;
ID3D12RootSignature*        g_rootSignature     = nullptr;
ID3D12DescriptorHeap*       g_rtvHeap           = nullptr;
ID3D12PipelineState*        g_pipelineState     = nullptr;
ID3D12GraphicsCommandList*  g_commandList       = nullptr;
static UINT                 g_rtvDescriptorSize = 0;

static D3D12_VIEWPORT g_viewport    = { 0.0f, 0.0f, (FLOAT)WINDOW_WIDTH, (FLOAT)WINDOW_HEIGHT, 0.0f, 1.0f };
static D3D12_RECT     g_scissorRect = { 0, 0, WINDOW_WIDTH, WINDOW_HEIGHT };

static UINT   g_frameIndex  = 0;
static HANDLE g_fenceEvent  = nullptr;
ID3D12Fence*  g_fence       = nullptr;
static UINT64 g_fenceValue  = 0;

// Full-screen quad vertex buffer
ID3D12Resource*             g_vertexBuffer      = nullptr;
static D3D12_VERTEX_BUFFER_VIEW g_vertexBufferView = {};

// Constant buffer (upload heap, persistently mapped)
ID3D12Resource*             g_constantBuffer    = nullptr;
static ConstantBufferData*  g_cbMappedData      = nullptr;   // CPU-side mapped pointer

// Animation timer
static std::chrono::steady_clock::time_point g_startTime;

// ---------------------------------------------------------------------------
// Forward declarations
// ---------------------------------------------------------------------------
LRESULT CALLBACK WindowProc(HWND hWnd, UINT nMsg, WPARAM wParam, LPARAM lParam);
HRESULT OnInit(HWND hWnd);
HRESULT InitDevice(HWND hWnd);
HRESULT InitView();
HRESULT InitTraffic();
HRESULT InitShader();
HRESULT InitBuffers();
HRESULT InitFence();
void    OnRender();
void    UpdateConstantBuffer();
void    WaitForPreviousFrame();
void    OnDestroy();

// ---------------------------------------------------------------------------
// Helper: fill D3D12_HEAP_PROPERTIES
// ---------------------------------------------------------------------------
inline D3D12_HEAP_PROPERTIES CreateHeapProperties(D3D12_HEAP_TYPE type)
{
    D3D12_HEAP_PROPERTIES props = {};
    props.Type                 = type;
    props.CPUPageProperty      = D3D12_CPU_PAGE_PROPERTY_UNKNOWN;
    props.MemoryPoolPreference = D3D12_MEMORY_POOL_UNKNOWN;
    props.CreationNodeMask     = 1;
    props.VisibleNodeMask      = 1;
    return props;
}

// ---------------------------------------------------------------------------
// Helper: fill D3D12_RESOURCE_DESC for a generic buffer
// ---------------------------------------------------------------------------
inline D3D12_RESOURCE_DESC CreateBufferDesc(UINT64 width)
{
    D3D12_RESOURCE_DESC desc = {};
    desc.Dimension          = D3D12_RESOURCE_DIMENSION_BUFFER;
    desc.Alignment          = 0;
    desc.Width              = width;
    desc.Height             = 1;
    desc.DepthOrArraySize   = 1;
    desc.MipLevels          = 1;
    desc.Format             = DXGI_FORMAT_UNKNOWN;
    desc.SampleDesc.Count   = 1;
    desc.SampleDesc.Quality = 0;
    desc.Layout             = D3D12_TEXTURE_LAYOUT_ROW_MAJOR;
    desc.Flags              = D3D12_RESOURCE_FLAG_NONE;
    return desc;
}

// ---------------------------------------------------------------------------
// Helper: fill D3D12_RESOURCE_BARRIER for a state transition
// ---------------------------------------------------------------------------
inline D3D12_RESOURCE_BARRIER CreateTransitionBarrier(
    ID3D12Resource*       pResource,
    D3D12_RESOURCE_STATES stateBefore,
    D3D12_RESOURCE_STATES stateAfter)
{
    D3D12_RESOURCE_BARRIER barrier = {};
    barrier.Type                   = D3D12_RESOURCE_BARRIER_TYPE_TRANSITION;
    barrier.Flags                  = D3D12_RESOURCE_BARRIER_FLAG_NONE;
    barrier.Transition.pResource   = pResource;
    barrier.Transition.StateBefore = stateBefore;
    barrier.Transition.StateAfter  = stateAfter;
    barrier.Transition.Subresource = D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES;
    return barrier;
}

// ===========================================================================
// Entry point
// ===========================================================================
int APIENTRY _tWinMain(HINSTANCE hInstance, HINSTANCE, LPTSTR, int nCmdShow)
{
    // Register window class
    WNDCLASSEX windowClass = {};
    windowClass.cbSize        = sizeof(WNDCLASSEX);
    windowClass.style         = CS_HREDRAW | CS_VREDRAW;
    windowClass.lpfnWndProc   = WindowProc;
    windowClass.hInstance     = hInstance;
    windowClass.hCursor       = LoadCursor(NULL, IDC_ARROW);
    windowClass.lpszClassName = _T("DX12RaymarchingClass");
    RegisterClassEx(&windowClass);

    // Compute window size that gives the desired client area
    RECT windowRect = { 0, 0, WINDOW_WIDTH, WINDOW_HEIGHT };
    AdjustWindowRect(&windowRect, WS_OVERLAPPEDWINDOW, FALSE);

    HWND hWnd = CreateWindow(
        _T("DX12RaymarchingClass"),
        _T("DirectX 12 Raymarching (C++/CLI)"),
        WS_OVERLAPPEDWINDOW,
        CW_USEDEFAULT, CW_USEDEFAULT,
        windowRect.right  - windowRect.left,
        windowRect.bottom - windowRect.top,
        nullptr, nullptr, hInstance, nullptr);

    MSG msg = {};
    if (SUCCEEDED(OnInit(hWnd)))
    {
        ShowWindow(hWnd, nCmdShow);

        // Main message loop
        while (msg.message != WM_QUIT)
        {
            if (PeekMessage(&msg, NULL, 0, 0, PM_REMOVE))
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

// ---------------------------------------------------------------------------
// Window procedure
// ---------------------------------------------------------------------------
LRESULT CALLBACK WindowProc(HWND hWnd, UINT nMsg, WPARAM wParam, LPARAM lParam)
{
    switch (nMsg)
    {
    case WM_DESTROY:
        OnDestroy();
        PostQuitMessage(0);
        return 0;
    case WM_KEYDOWN:
        if (wParam == VK_ESCAPE)
        {
            // Allow exiting with ESC key
            DestroyWindow(hWnd);
        }
        return 0;
    }
    return DefWindowProc(hWnd, nMsg, wParam, lParam);
}

// ===========================================================================
// Initialization
// ===========================================================================

HRESULT OnInit(HWND hWnd)
{
    g_startTime = std::chrono::steady_clock::now();   // Record start time for animation

    if (FAILED(InitDevice(hWnd))) return E_FAIL;
    if (FAILED(InitView()))       return E_FAIL;
    if (FAILED(InitTraffic()))    return E_FAIL;
    if (FAILED(InitShader()))     return E_FAIL;
    if (FAILED(InitBuffers()))    return E_FAIL;
    if (FAILED(InitFence()))      return E_FAIL;
    return S_OK;
}

// ---------------------------------------------------------------------------
// InitDevice: create DXGI factory, choose adapter, create device,
//             command queue, and swap chain
// ---------------------------------------------------------------------------
HRESULT InitDevice(HWND hWnd)
{
    UINT dxgiFactoryFlags = 0;

    IDXGIFactory4* factory = nullptr;
    if (FAILED(CreateDXGIFactory2(dxgiFactoryFlags, IID_PPV_ARGS(&factory))))
        return E_FAIL;

    // Try to find a hardware adapter
    HRESULT hr = E_FAIL;
    IDXGIAdapter1* adapter = nullptr;
    for (UINT i = 0; factory->EnumAdapters1(i, &adapter) != DXGI_ERROR_NOT_FOUND; ++i)
    {
        DXGI_ADAPTER_DESC1 desc;
        adapter->GetDesc1(&desc);

        if (desc.Flags & DXGI_ADAPTER_FLAG_SOFTWARE)
        {
            SAFE_RELEASE(adapter);
            continue;
        }

        hr = D3D12CreateDevice(adapter, D3D_FEATURE_LEVEL_11_0, IID_PPV_ARGS(&g_device));
        SAFE_RELEASE(adapter);
        if (SUCCEEDED(hr)) break;
    }

    // Fall back to WARP software adapter if no hardware device was found
    if (FAILED(hr))
    {
        IDXGIAdapter* warpAdapter = nullptr;
        factory->EnumWarpAdapter(IID_PPV_ARGS(&warpAdapter));
        hr = D3D12CreateDevice(warpAdapter, D3D_FEATURE_LEVEL_11_0, IID_PPV_ARGS(&g_device));
        SAFE_RELEASE(warpAdapter);
        if (FAILED(hr)) { SAFE_RELEASE(factory); return E_FAIL; }
    }

    // Create the direct command queue
    D3D12_COMMAND_QUEUE_DESC queueDesc = {};
    queueDesc.Type  = D3D12_COMMAND_LIST_TYPE_DIRECT;
    queueDesc.Flags = D3D12_COMMAND_QUEUE_FLAG_NONE;
    if (FAILED(g_device->CreateCommandQueue(&queueDesc, IID_PPV_ARGS(&g_commandQueue))))
    {
        SAFE_RELEASE(factory);
        return E_FAIL;
    }

    // Create the double-buffered swap chain
    DXGI_SWAP_CHAIN_DESC1 swapChainDesc = {};
    swapChainDesc.BufferCount  = g_frameCount;
    swapChainDesc.Width        = WINDOW_WIDTH;
    swapChainDesc.Height       = WINDOW_HEIGHT;
    swapChainDesc.Format       = DXGI_FORMAT_R8G8B8A8_UNORM;
    swapChainDesc.BufferUsage  = DXGI_USAGE_RENDER_TARGET_OUTPUT;
    swapChainDesc.SwapEffect   = DXGI_SWAP_EFFECT_FLIP_DISCARD;
    swapChainDesc.SampleDesc.Count = 1;

    IDXGISwapChain1* swapChain1 = nullptr;
    if (FAILED(factory->CreateSwapChainForHwnd(
            g_commandQueue, hWnd, &swapChainDesc, nullptr, nullptr, &swapChain1)))
    {
        SAFE_RELEASE(factory);
        return E_FAIL;
    }

    factory->MakeWindowAssociation(hWnd, DXGI_MWA_NO_ALT_ENTER);
    swapChain1->QueryInterface(IID_PPV_ARGS(&g_swapChain));
    SAFE_RELEASE(swapChain1);
    SAFE_RELEASE(factory);

    g_frameIndex = g_swapChain->GetCurrentBackBufferIndex();
    return S_OK;
}

// ---------------------------------------------------------------------------
// InitView: create the RTV descriptor heap and one RTV per back buffer
// ---------------------------------------------------------------------------
HRESULT InitView()
{
    D3D12_DESCRIPTOR_HEAP_DESC rtvHeapDesc = {};
    rtvHeapDesc.NumDescriptors = g_frameCount;
    rtvHeapDesc.Type           = D3D12_DESCRIPTOR_HEAP_TYPE_RTV;
    rtvHeapDesc.Flags          = D3D12_DESCRIPTOR_HEAP_FLAG_NONE;

    if (FAILED(g_device->CreateDescriptorHeap(&rtvHeapDesc, IID_PPV_ARGS(&g_rtvHeap))))
        return E_FAIL;

    g_rtvDescriptorSize = g_device->GetDescriptorHandleIncrementSize(D3D12_DESCRIPTOR_HEAP_TYPE_RTV);

    D3D12_CPU_DESCRIPTOR_HANDLE rtvHandle = g_rtvHeap->GetCPUDescriptorHandleForHeapStart();
    for (UINT i = 0; i < g_frameCount; i++)
    {
        if (FAILED(g_swapChain->GetBuffer(i, IID_PPV_ARGS(&g_renderTargets[i]))))
            return E_FAIL;
        g_device->CreateRenderTargetView(g_renderTargets[i], nullptr, rtvHandle);
        rtvHandle.ptr += g_rtvDescriptorSize;
    }

    return S_OK;
}

// ---------------------------------------------------------------------------
// InitTraffic: create command allocator and root signature.
//
// The root signature contains one inline root CBV descriptor (b0).
// This binds ConstantBufferData to the pixel shader without requiring
// a separate CBV/SRV/UAV descriptor heap.
// ---------------------------------------------------------------------------
HRESULT InitTraffic()
{
    // Command allocator for recording draw commands
    if (FAILED(g_device->CreateCommandAllocator(
            D3D12_COMMAND_LIST_TYPE_DIRECT, IID_PPV_ARGS(&g_commandAllocator))))
        return E_FAIL;

    // Root parameter: an inline root CBV at shader register b0, visible to all shaders
    D3D12_ROOT_PARAMETER rootParam = {};
    rootParam.ParameterType             = D3D12_ROOT_PARAMETER_TYPE_CBV;
    rootParam.Descriptor.ShaderRegister = 0;   // b0
    rootParam.Descriptor.RegisterSpace  = 0;
    rootParam.ShaderVisibility          = D3D12_SHADER_VISIBILITY_ALL;

    D3D12_ROOT_SIGNATURE_DESC rsDesc = {};
    rsDesc.NumParameters     = 1;
    rsDesc.pParameters       = &rootParam;
    rsDesc.NumStaticSamplers = 0;
    rsDesc.pStaticSamplers   = nullptr;
    rsDesc.Flags             = D3D12_ROOT_SIGNATURE_FLAG_ALLOW_INPUT_ASSEMBLER_INPUT_LAYOUT;

    ID3DBlob* signature = nullptr;
    ID3DBlob* error     = nullptr;
    D3D12SerializeRootSignature(&rsDesc, D3D_ROOT_SIGNATURE_VERSION_1, &signature, &error);
    SAFE_RELEASE(error);

    HRESULT hr = g_device->CreateRootSignature(
        0, signature->GetBufferPointer(), signature->GetBufferSize(), IID_PPV_ARGS(&g_rootSignature));
    SAFE_RELEASE(signature);

    return SUCCEEDED(hr) ? S_OK : E_FAIL;
}

// ---------------------------------------------------------------------------
// InitShader: compile hello.hlsl and create the graphics pipeline state.
//
// The input layout uses a single float2 POSITION attribute to match VSMain.
// ---------------------------------------------------------------------------
HRESULT InitShader()
{
    ID3DBlob* vertexShader = nullptr;
    ID3DBlob* pixelShader  = nullptr;
    ID3DBlob* errorBlob    = nullptr;
    UINT compileFlags      = 0;

    // Compile the vertex shader entry point
    HRESULT hr = D3DCompileFromFile(
        L"hello.hlsl", nullptr, nullptr, "VSMain", "vs_5_0",
        compileFlags, 0, &vertexShader, &errorBlob);
    if (FAILED(hr))
    {
        if (errorBlob) { OutputDebugStringA((char*)errorBlob->GetBufferPointer()); SAFE_RELEASE(errorBlob); }
        return E_FAIL;
    }

    // Compile the pixel shader entry point (contains the raymarching logic)
    hr = D3DCompileFromFile(
        L"hello.hlsl", nullptr, nullptr, "PSMain", "ps_5_0",
        compileFlags, 0, &pixelShader, &errorBlob);
    if (FAILED(hr))
    {
        SAFE_RELEASE(vertexShader);
        if (errorBlob) { OutputDebugStringA((char*)errorBlob->GetBufferPointer()); SAFE_RELEASE(errorBlob); }
        return E_FAIL;
    }

    // Input layout: only position (float2), matching "float2 position : POSITION" in VSMain
    D3D12_INPUT_ELEMENT_DESC inputElementDescs[] =
    {
        { "POSITION", 0, DXGI_FORMAT_R32G32_FLOAT, 0, 0, D3D12_INPUT_CLASSIFICATION_PER_VERTEX_DATA, 0 },
    };

    // Standard rasterizer settings (back-face culling off; the quad is always front-facing)
    D3D12_RASTERIZER_DESC rasterizerDesc = {};
    rasterizerDesc.FillMode              = D3D12_FILL_MODE_SOLID;
    rasterizerDesc.CullMode              = D3D12_CULL_MODE_NONE;   // No culling for full-screen quad
    rasterizerDesc.FrontCounterClockwise = FALSE;
    rasterizerDesc.DepthBias             = D3D12_DEFAULT_DEPTH_BIAS;
    rasterizerDesc.DepthBiasClamp        = D3D12_DEFAULT_DEPTH_BIAS_CLAMP;
    rasterizerDesc.SlopeScaledDepthBias  = D3D12_DEFAULT_SLOPE_SCALED_DEPTH_BIAS;
    rasterizerDesc.DepthClipEnable       = TRUE;

    // Blending disabled; raymarching outputs fully opaque pixels
    D3D12_BLEND_DESC blendDesc = {};
    blendDesc.RenderTarget[0].BlendEnable           = FALSE;
    blendDesc.RenderTarget[0].LogicOpEnable         = FALSE;
    blendDesc.RenderTarget[0].SrcBlend              = D3D12_BLEND_ONE;
    blendDesc.RenderTarget[0].DestBlend             = D3D12_BLEND_ZERO;
    blendDesc.RenderTarget[0].BlendOp               = D3D12_BLEND_OP_ADD;
    blendDesc.RenderTarget[0].SrcBlendAlpha         = D3D12_BLEND_ONE;
    blendDesc.RenderTarget[0].DestBlendAlpha        = D3D12_BLEND_ZERO;
    blendDesc.RenderTarget[0].BlendOpAlpha          = D3D12_BLEND_OP_ADD;
    blendDesc.RenderTarget[0].LogicOp               = D3D12_LOGIC_OP_NOOP;
    blendDesc.RenderTarget[0].RenderTargetWriteMask = D3D12_COLOR_WRITE_ENABLE_ALL;

    D3D12_GRAPHICS_PIPELINE_STATE_DESC gpsDesc = {};
    gpsDesc.InputLayout     = { inputElementDescs, _countof(inputElementDescs) };
    gpsDesc.pRootSignature  = g_rootSignature;
    gpsDesc.VS              = { vertexShader->GetBufferPointer(), vertexShader->GetBufferSize() };
    gpsDesc.PS              = { pixelShader->GetBufferPointer(),  pixelShader->GetBufferSize() };
    gpsDesc.RasterizerState = rasterizerDesc;
    gpsDesc.BlendState      = blendDesc;
    gpsDesc.DepthStencilState.DepthEnable   = FALSE;
    gpsDesc.DepthStencilState.StencilEnable = FALSE;
    gpsDesc.SampleMask              = UINT_MAX;
    gpsDesc.PrimitiveTopologyType   = D3D12_PRIMITIVE_TOPOLOGY_TYPE_TRIANGLE;
    gpsDesc.NumRenderTargets        = 1;
    gpsDesc.RTVFormats[0]           = DXGI_FORMAT_R8G8B8A8_UNORM;
    gpsDesc.SampleDesc.Count        = 1;

    hr = g_device->CreateGraphicsPipelineState(&gpsDesc, IID_PPV_ARGS(&g_pipelineState));

    SAFE_RELEASE(vertexShader);
    SAFE_RELEASE(pixelShader);

    return SUCCEEDED(hr) ? S_OK : E_FAIL;
}

// ---------------------------------------------------------------------------
// InitBuffers: create the command list, vertex buffer for the full-screen quad,
//              and the constant buffer used to pass iTime / iResolution to HLSL.
// ---------------------------------------------------------------------------
HRESULT InitBuffers()
{
    // Create the command list in the closed state (will be Reset in OnRender)
    if (FAILED(g_device->CreateCommandList(
            0, D3D12_COMMAND_LIST_TYPE_DIRECT, g_commandAllocator,
            nullptr, IID_PPV_ARGS(&g_commandList))))
        return E_FAIL;
    g_commandList->Close();

    // ------------------------------------------------------------------
    // Full-screen quad: two triangles that cover NDC [-1, 1] x [-1, 1].
    //   Triangle 0: top-left, bottom-left, top-right
    //   Triangle 1: bottom-left, bottom-right, top-right
    // ------------------------------------------------------------------
    VERTEX vertices[] =
    {
        { XMFLOAT2(-1.0f,  1.0f) },   // top-left
        { XMFLOAT2(-1.0f, -1.0f) },   // bottom-left
        { XMFLOAT2( 1.0f,  1.0f) },   // top-right
        { XMFLOAT2(-1.0f, -1.0f) },   // bottom-left
        { XMFLOAT2( 1.0f, -1.0f) },   // bottom-right
        { XMFLOAT2( 1.0f,  1.0f) },   // top-right
    };

    const UINT vertexBufferSize = sizeof(vertices);

    // Vertex buffer on upload heap (small, static data; no need for a default heap here)
    D3D12_HEAP_PROPERTIES heapProps = CreateHeapProperties(D3D12_HEAP_TYPE_UPLOAD);
    D3D12_RESOURCE_DESC   bufDesc   = CreateBufferDesc(vertexBufferSize);

    if (FAILED(g_device->CreateCommittedResource(
            &heapProps, D3D12_HEAP_FLAG_NONE, &bufDesc,
            D3D12_RESOURCE_STATE_GENERIC_READ, nullptr,
            IID_PPV_ARGS(&g_vertexBuffer))))
        return E_FAIL;

    // Copy vertex data via a persistent CPU map
    UINT8* pMapped = nullptr;
    D3D12_RANGE readRange = { 0, 0 };
    g_vertexBuffer->Map(0, &readRange, reinterpret_cast<void**>(&pMapped));
    memcpy(pMapped, vertices, vertexBufferSize);
    g_vertexBuffer->Unmap(0, nullptr);

    g_vertexBufferView.BufferLocation = g_vertexBuffer->GetGPUVirtualAddress();
    g_vertexBufferView.StrideInBytes  = sizeof(VERTEX);
    g_vertexBufferView.SizeInBytes    = vertexBufferSize;

    // ------------------------------------------------------------------
    // Constant buffer: must be 256-byte aligned per D3D12 specification.
    // We keep it persistently mapped for fast per-frame CPU writes.
    // ------------------------------------------------------------------
    const UINT cbSize = ALIGN_UP(sizeof(ConstantBufferData), 256);

    D3D12_HEAP_PROPERTIES cbHeapProps = CreateHeapProperties(D3D12_HEAP_TYPE_UPLOAD);
    D3D12_RESOURCE_DESC   cbDesc      = CreateBufferDesc(cbSize);

    if (FAILED(g_device->CreateCommittedResource(
            &cbHeapProps, D3D12_HEAP_FLAG_NONE, &cbDesc,
            D3D12_RESOURCE_STATE_GENERIC_READ, nullptr,
            IID_PPV_ARGS(&g_constantBuffer))))
        return E_FAIL;

    // Map and keep the pointer open for the lifetime of the application
    D3D12_RANGE cbReadRange = { 0, 0 };
    g_constantBuffer->Map(0, &cbReadRange, reinterpret_cast<void**>(&g_cbMappedData));

    // Initialize with sane defaults
    g_cbMappedData->iTime        = 0.0f;
    g_cbMappedData->iResolutionX = static_cast<float>(WINDOW_WIDTH);
    g_cbMappedData->iResolutionY = static_cast<float>(WINDOW_HEIGHT);
    g_cbMappedData->padding      = 0.0f;

    return S_OK;
}

// ---------------------------------------------------------------------------
// InitFence: create the GPU fence and perform the initial synchronization
// ---------------------------------------------------------------------------
HRESULT InitFence()
{
    if (FAILED(g_device->CreateFence(0, D3D12_FENCE_FLAG_NONE, IID_PPV_ARGS(&g_fence))))
        return E_FAIL;

    g_fenceValue = 1;
    g_fenceEvent = CreateEvent(nullptr, FALSE, FALSE, nullptr);
    if (g_fenceEvent == nullptr)
        return E_FAIL;

    WaitForPreviousFrame();
    return S_OK;
}

// ===========================================================================
// Per-frame logic
// ===========================================================================

// ---------------------------------------------------------------------------
// UpdateConstantBuffer: write current elapsed time and resolution to the
//                        persistently mapped constant buffer.
// ---------------------------------------------------------------------------
void UpdateConstantBuffer()
{
    auto now     = std::chrono::steady_clock::now();
    auto elapsed = std::chrono::duration<float>(now - g_startTime).count();

    g_cbMappedData->iTime        = elapsed;
    g_cbMappedData->iResolutionX = static_cast<float>(WINDOW_WIDTH);
    g_cbMappedData->iResolutionY = static_cast<float>(WINDOW_HEIGHT);
    g_cbMappedData->padding      = 0.0f;
}

// ---------------------------------------------------------------------------
// OnRender: record and submit one frame of commands
// ---------------------------------------------------------------------------
void OnRender()
{
    // Update the constant buffer before recording commands
    UpdateConstantBuffer();

    // Reset the command allocator and command list for this frame
    g_commandAllocator->Reset();
    g_commandList->Reset(g_commandAllocator, g_pipelineState);

    // Bind the root signature and set the inline CBV (root parameter 0 = b0)
    g_commandList->SetGraphicsRootSignature(g_rootSignature);
    g_commandList->SetGraphicsRootConstantBufferView(
        0,                                              // root parameter index
        g_constantBuffer->GetGPUVirtualAddress());      // GPU address of the constant buffer

    // Set viewport and scissor rectangle
    g_commandList->RSSetViewports(1, &g_viewport);
    g_commandList->RSSetScissorRects(1, &g_scissorRect);

    // Transition the current back buffer from Present to Render Target
    D3D12_RESOURCE_BARRIER barrierToRT = CreateTransitionBarrier(
        g_renderTargets[g_frameIndex],
        D3D12_RESOURCE_STATE_PRESENT,
        D3D12_RESOURCE_STATE_RENDER_TARGET);
    g_commandList->ResourceBarrier(1, &barrierToRT);

    // Get the RTV handle for the current back buffer
    D3D12_CPU_DESCRIPTOR_HANDLE rtvHandle = g_rtvHeap->GetCPUDescriptorHandleForHeapStart();
    rtvHandle.ptr += g_frameIndex * g_rtvDescriptorSize;

    g_commandList->OMSetRenderTargets(1, &rtvHandle, FALSE, nullptr);

    // Clear to black (the pixel shader overwrites everything anyway)
    const FLOAT clearColor[] = { 0.0f, 0.0f, 0.0f, 1.0f };
    g_commandList->ClearRenderTargetView(rtvHandle, clearColor, 0, nullptr);

    // Draw the full-screen quad (6 vertices = 2 triangles)
    g_commandList->IASetPrimitiveTopology(D3D_PRIMITIVE_TOPOLOGY_TRIANGLELIST);
    g_commandList->IASetVertexBuffers(0, 1, &g_vertexBufferView);
    g_commandList->DrawInstanced(6, 1, 0, 0);

    // Transition the back buffer from Render Target back to Present
    D3D12_RESOURCE_BARRIER barrierToPresent = CreateTransitionBarrier(
        g_renderTargets[g_frameIndex],
        D3D12_RESOURCE_STATE_RENDER_TARGET,
        D3D12_RESOURCE_STATE_PRESENT);
    g_commandList->ResourceBarrier(1, &barrierToPresent);

    g_commandList->Close();

    // Submit the command list to the GPU
    ID3D12CommandList* ppCommandLists[] = { g_commandList };
    g_commandQueue->ExecuteCommandLists(_countof(ppCommandLists), ppCommandLists);

    // Present the frame (vsync enabled: interval = 1)
    g_swapChain->Present(1, 0);

    // Wait for the GPU to finish before reusing resources
    WaitForPreviousFrame();
}

// ---------------------------------------------------------------------------
// WaitForPreviousFrame: signal the fence and stall the CPU until the GPU
//                       has processed all commands up to this frame.
// ---------------------------------------------------------------------------
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

// ---------------------------------------------------------------------------
// OnDestroy: unmap and release all DirectX 12 resources
// ---------------------------------------------------------------------------
void OnDestroy()
{
    WaitForPreviousFrame();

    if (g_fenceEvent)
    {
        CloseHandle(g_fenceEvent);
        g_fenceEvent = nullptr;
    }

    // Unmap the constant buffer before releasing it
    if (g_constantBuffer && g_cbMappedData)
    {
        g_constantBuffer->Unmap(0, nullptr);
        g_cbMappedData = nullptr;
    }

    SAFE_RELEASE(g_fence);
    SAFE_RELEASE(g_constantBuffer);
    SAFE_RELEASE(g_vertexBuffer);
    SAFE_RELEASE(g_commandList);
    SAFE_RELEASE(g_pipelineState);
    SAFE_RELEASE(g_rootSignature);
    SAFE_RELEASE(g_commandAllocator);

    for (UINT i = 0; i < g_frameCount; i++)
    {
        SAFE_RELEASE(g_renderTargets[i]);
    }

    SAFE_RELEASE(g_rtvHeap);
    SAFE_RELEASE(g_swapChain);
    SAFE_RELEASE(g_commandQueue);
    SAFE_RELEASE(g_device);
}
