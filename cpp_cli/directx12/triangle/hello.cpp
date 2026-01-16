#include <windows.h>
#include <tchar.h>
#include <d3d12.h>
#include <dxgi1_4.h>
#include <d3dcompiler.h>
#include <directxmath.h>

#pragma comment(lib, "d3d12.lib")
#pragma comment(lib, "dxgi.lib")
#pragma comment(lib, "d3dcompiler.lib")

#define WINDOW_WIDTH    640
#define WINDOW_HEIGHT   480

using namespace DirectX;

struct VERTEX
{
    XMFLOAT3 position;
    XMFLOAT4 color;
};

inline D3D12_HEAP_PROPERTIES CreateHeapProperties(D3D12_HEAP_TYPE type)
{
    D3D12_HEAP_PROPERTIES props = {};
    props.Type = type;
    props.CPUPageProperty = D3D12_CPU_PAGE_PROPERTY_UNKNOWN;
    props.MemoryPoolPreference = D3D12_MEMORY_POOL_UNKNOWN;
    props.CreationNodeMask = 1;
    props.VisibleNodeMask = 1;
    return props;
}

inline D3D12_RESOURCE_DESC CreateBufferDesc(UINT64 width)
{
    D3D12_RESOURCE_DESC desc = {};
    desc.Dimension = D3D12_RESOURCE_DIMENSION_BUFFER;
    desc.Alignment = 0;
    desc.Width = width;
    desc.Height = 1;
    desc.DepthOrArraySize = 1;
    desc.MipLevels = 1;
    desc.Format = DXGI_FORMAT_UNKNOWN;
    desc.SampleDesc.Count = 1;
    desc.SampleDesc.Quality = 0;
    desc.Layout = D3D12_TEXTURE_LAYOUT_ROW_MAJOR;
    desc.Flags = D3D12_RESOURCE_FLAG_NONE;
    return desc;
}

inline D3D12_RESOURCE_BARRIER CreateTransitionBarrier(
    ID3D12Resource* pResource,
    D3D12_RESOURCE_STATES stateBefore,
    D3D12_RESOURCE_STATES stateAfter)
{
    D3D12_RESOURCE_BARRIER barrier = {};
    barrier.Type = D3D12_RESOURCE_BARRIER_TYPE_TRANSITION;
    barrier.Flags = D3D12_RESOURCE_BARRIER_FLAG_NONE;
    barrier.Transition.pResource = pResource;
    barrier.Transition.StateBefore = stateBefore;
    barrier.Transition.StateAfter = stateAfter;
    barrier.Transition.Subresource = D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES;
    return barrier;
}

static const UINT g_frameCount = 2;

ID3D12Device*               g_device = nullptr;
IDXGISwapChain3*            g_swapChain = nullptr;
ID3D12Resource*             g_renderTargets[g_frameCount] = {};
ID3D12CommandAllocator*     g_commandAllocator = nullptr;
ID3D12CommandQueue*         g_commandQueue = nullptr;
ID3D12RootSignature*        g_rootSignature = nullptr;
ID3D12DescriptorHeap*       g_rtvHeap = nullptr;
ID3D12PipelineState*        g_pipelineState = nullptr;
ID3D12GraphicsCommandList*  g_commandList = nullptr;
static UINT                 g_rtvDescriptorSize = 0;

static D3D12_VIEWPORT       g_viewport = { 0.0f, 0.0f, (FLOAT)WINDOW_WIDTH, (FLOAT)WINDOW_HEIGHT, 0.0f, 1.0f };
static D3D12_RECT           g_scissorRect = { 0, 0, WINDOW_WIDTH, WINDOW_HEIGHT };

static UINT                 g_frameIndex = 0;
static HANDLE               g_fenceEvent = nullptr;
ID3D12Fence*                g_fence = nullptr;
static UINT64               g_fenceValue = 0;

ID3D12Resource*             g_vertexBuffer = nullptr;
static D3D12_VERTEX_BUFFER_VIEW g_vertexBufferView = {};

LRESULT CALLBACK WindowProc(HWND hWnd, UINT nMsg, WPARAM wParam, LPARAM lParam);
HRESULT OnInit(HWND hWnd);
HRESULT InitDevice(HWND hWnd);
HRESULT InitView();
HRESULT InitTraffic();
HRESULT InitShader();
HRESULT InitBuffer();
HRESULT InitFence();
void OnRender();
void WaitForPreviousFrame();
void OnDestroy();

#define SAFE_RELEASE(p) { if(p) { (p)->Release(); (p) = nullptr; } }

int APIENTRY _tWinMain(HINSTANCE hInstance, HINSTANCE, LPTSTR, int nCmdShow)
{
    WNDCLASSEX windowClass = {};
    windowClass.cbSize = sizeof(WNDCLASSEX);
    windowClass.style = CS_HREDRAW | CS_VREDRAW;
    windowClass.lpfnWndProc = WindowProc;
    windowClass.hInstance = hInstance;
    windowClass.hCursor = LoadCursor(NULL, IDC_ARROW);
    windowClass.lpszClassName = _T("DX12CLRWindowClass");
    RegisterClassEx(&windowClass);

    RECT windowRect = { 0, 0, WINDOW_WIDTH, WINDOW_HEIGHT };
    AdjustWindowRect(&windowRect, WS_OVERLAPPEDWINDOW, FALSE);

    HWND hWnd = CreateWindow(
        _T("DX12CLRWindowClass"),
        _T("Hello, DirectX 12 (C++/CLI)!"),
        WS_OVERLAPPEDWINDOW,
        CW_USEDEFAULT,
        CW_USEDEFAULT,
        windowRect.right - windowRect.left,
        windowRect.bottom - windowRect.top,
        nullptr,
        nullptr,
        hInstance,
        nullptr);

    MSG msg = {};
    if (SUCCEEDED(OnInit(hWnd)))
    {
        ShowWindow(hWnd, SW_SHOW);

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

LRESULT CALLBACK WindowProc(HWND hWnd, UINT nMsg, WPARAM wParam, LPARAM lParam)
{
    switch (nMsg)
    {
    case WM_DESTROY:
        OnDestroy();
        PostQuitMessage(0);
        return 0;
    }
    return DefWindowProc(hWnd, nMsg, wParam, lParam);
}

HRESULT OnInit(HWND hWnd)
{
    if (FAILED(InitDevice(hWnd))) return E_FAIL;
    if (FAILED(InitView())) return E_FAIL;
    if (FAILED(InitTraffic())) return E_FAIL;
    if (FAILED(InitShader())) return E_FAIL;
    if (FAILED(InitBuffer())) return E_FAIL;
    if (FAILED(InitFence())) return E_FAIL;
    return S_OK;
}

HRESULT InitDevice(HWND hWnd)
{
    UINT dxgiFactoryFlags = 0;

    IDXGIFactory4* factory = nullptr;
    if (FAILED(CreateDXGIFactory2(dxgiFactoryFlags, IID_PPV_ARGS(&factory))))
    {
        return E_FAIL;
    }

    HRESULT hr = E_FAIL;
    IDXGIAdapter1* adapter = nullptr;
    for (UINT adapterIndex = 0; factory->EnumAdapters1(adapterIndex, &adapter) != DXGI_ERROR_NOT_FOUND; ++adapterIndex)
    {
        DXGI_ADAPTER_DESC1 adapterDesc;
        adapter->GetDesc1(&adapterDesc);

        if (adapterDesc.Flags & DXGI_ADAPTER_FLAG_SOFTWARE)
        {
            SAFE_RELEASE(adapter);
            continue;
        }

        hr = D3D12CreateDevice(adapter, D3D_FEATURE_LEVEL_11_0, IID_PPV_ARGS(&g_device));
        if (SUCCEEDED(hr))
        {
            SAFE_RELEASE(adapter);
            break;
        }
        SAFE_RELEASE(adapter);
    }

    if (FAILED(hr))
    {
        IDXGIAdapter* warpAdapter = nullptr;
        factory->EnumWarpAdapter(IID_PPV_ARGS(&warpAdapter));
        hr = D3D12CreateDevice(warpAdapter, D3D_FEATURE_LEVEL_11_0, IID_PPV_ARGS(&g_device));
        SAFE_RELEASE(warpAdapter);
        if (FAILED(hr))
        {
            SAFE_RELEASE(factory);
            return E_FAIL;
        }
    }

    D3D12_COMMAND_QUEUE_DESC queueDesc = {};
    queueDesc.Flags = D3D12_COMMAND_QUEUE_FLAG_NONE;
    queueDesc.Type = D3D12_COMMAND_LIST_TYPE_DIRECT;

    if (FAILED(g_device->CreateCommandQueue(&queueDesc, IID_PPV_ARGS(&g_commandQueue))))
    {
        SAFE_RELEASE(factory);
        return E_FAIL;
    }

    DXGI_SWAP_CHAIN_DESC1 swapChainDesc = {};
    swapChainDesc.BufferCount = g_frameCount;
    swapChainDesc.Width = WINDOW_WIDTH;
    swapChainDesc.Height = WINDOW_HEIGHT;
    swapChainDesc.Format = DXGI_FORMAT_R8G8B8A8_UNORM;
    swapChainDesc.BufferUsage = DXGI_USAGE_RENDER_TARGET_OUTPUT;
    swapChainDesc.SwapEffect = DXGI_SWAP_EFFECT_FLIP_DISCARD;
    swapChainDesc.SampleDesc.Count = 1;

    IDXGISwapChain1* swapChain1 = nullptr;
    if (FAILED(factory->CreateSwapChainForHwnd(g_commandQueue, hWnd, &swapChainDesc, nullptr, nullptr, &swapChain1)))
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

HRESULT InitView()
{
    D3D12_DESCRIPTOR_HEAP_DESC rtvHeapDesc = {};
    rtvHeapDesc.NumDescriptors = g_frameCount;
    rtvHeapDesc.Type = D3D12_DESCRIPTOR_HEAP_TYPE_RTV;
    rtvHeapDesc.Flags = D3D12_DESCRIPTOR_HEAP_FLAG_NONE;

    if (FAILED(g_device->CreateDescriptorHeap(&rtvHeapDesc, IID_PPV_ARGS(&g_rtvHeap))))
    {
        return E_FAIL;
    }

    g_rtvDescriptorSize = g_device->GetDescriptorHandleIncrementSize(D3D12_DESCRIPTOR_HEAP_TYPE_RTV);

    D3D12_CPU_DESCRIPTOR_HANDLE rtvHandle = g_rtvHeap->GetCPUDescriptorHandleForHeapStart();

    for (UINT i = 0; i < g_frameCount; i++)
    {
        if (FAILED(g_swapChain->GetBuffer(i, IID_PPV_ARGS(&g_renderTargets[i]))))
        {
            return E_FAIL;
        }
        g_device->CreateRenderTargetView(g_renderTargets[i], nullptr, rtvHandle);
        rtvHandle.ptr += g_rtvDescriptorSize;
    }

    return S_OK;
}

HRESULT InitTraffic()
{
    if (FAILED(g_device->CreateCommandAllocator(D3D12_COMMAND_LIST_TYPE_DIRECT, IID_PPV_ARGS(&g_commandAllocator))))
    {
        return E_FAIL;
    }

    D3D12_ROOT_SIGNATURE_DESC rsDesc = {};
    rsDesc.NumParameters = 0;
    rsDesc.pParameters = nullptr;
    rsDesc.NumStaticSamplers = 0;
    rsDesc.pStaticSamplers = nullptr;
    rsDesc.Flags = D3D12_ROOT_SIGNATURE_FLAG_ALLOW_INPUT_ASSEMBLER_INPUT_LAYOUT;

    ID3DBlob* signature = nullptr;
    ID3DBlob* error = nullptr;
    D3D12SerializeRootSignature(&rsDesc, D3D_ROOT_SIGNATURE_VERSION_1, &signature, &error);
    
    HRESULT hr = g_device->CreateRootSignature(0, signature->GetBufferPointer(), signature->GetBufferSize(), IID_PPV_ARGS(&g_rootSignature));
    
    SAFE_RELEASE(signature);
    SAFE_RELEASE(error);

    if (FAILED(hr))
    {
        return E_FAIL;
    }

    return S_OK;
}

HRESULT InitShader()
{
    ID3DBlob* vertexShader = nullptr;
    ID3DBlob* pixelShader = nullptr;
    ID3DBlob* errorBlob = nullptr;

    UINT compileFlags = 0;

    HRESULT hr = D3DCompileFromFile(L"hello.hlsl", nullptr, nullptr, "VSMain", "vs_5_0", compileFlags, 0, &vertexShader, &errorBlob);
    if (FAILED(hr))
    {
        if (errorBlob)
        {
            OutputDebugStringA((char*)errorBlob->GetBufferPointer());
            SAFE_RELEASE(errorBlob);
        }
        return E_FAIL;
    }

    hr = D3DCompileFromFile(L"hello.hlsl", nullptr, nullptr, "PSMain", "ps_5_0", compileFlags, 0, &pixelShader, &errorBlob);
    if (FAILED(hr))
    {
        SAFE_RELEASE(vertexShader);
        if (errorBlob)
        {
            OutputDebugStringA((char*)errorBlob->GetBufferPointer());
            SAFE_RELEASE(errorBlob);
        }
        return E_FAIL;
    }

    D3D12_INPUT_ELEMENT_DESC inputElementDescs[] =
    {
        { "POSITION", 0, DXGI_FORMAT_R32G32B32_FLOAT,    0,  0, D3D12_INPUT_CLASSIFICATION_PER_VERTEX_DATA, 0 },
        { "COLOR",    0, DXGI_FORMAT_R32G32B32A32_FLOAT, 0, 12, D3D12_INPUT_CLASSIFICATION_PER_VERTEX_DATA, 0 },
    };

    D3D12_RASTERIZER_DESC rasterizerDesc = {};
    rasterizerDesc.FillMode = D3D12_FILL_MODE_SOLID;
    rasterizerDesc.CullMode = D3D12_CULL_MODE_BACK;
    rasterizerDesc.FrontCounterClockwise = FALSE;
    rasterizerDesc.DepthBias = D3D12_DEFAULT_DEPTH_BIAS;
    rasterizerDesc.DepthBiasClamp = D3D12_DEFAULT_DEPTH_BIAS_CLAMP;
    rasterizerDesc.SlopeScaledDepthBias = D3D12_DEFAULT_SLOPE_SCALED_DEPTH_BIAS;
    rasterizerDesc.DepthClipEnable = TRUE;
    rasterizerDesc.MultisampleEnable = FALSE;
    rasterizerDesc.AntialiasedLineEnable = FALSE;
    rasterizerDesc.ForcedSampleCount = 0;
    rasterizerDesc.ConservativeRaster = D3D12_CONSERVATIVE_RASTERIZATION_MODE_OFF;

    D3D12_BLEND_DESC blendDesc = {};
    blendDesc.AlphaToCoverageEnable = FALSE;
    blendDesc.IndependentBlendEnable = FALSE;
    blendDesc.RenderTarget[0].BlendEnable = FALSE;
    blendDesc.RenderTarget[0].LogicOpEnable = FALSE;
    blendDesc.RenderTarget[0].SrcBlend = D3D12_BLEND_ONE;
    blendDesc.RenderTarget[0].DestBlend = D3D12_BLEND_ZERO;
    blendDesc.RenderTarget[0].BlendOp = D3D12_BLEND_OP_ADD;
    blendDesc.RenderTarget[0].SrcBlendAlpha = D3D12_BLEND_ONE;
    blendDesc.RenderTarget[0].DestBlendAlpha = D3D12_BLEND_ZERO;
    blendDesc.RenderTarget[0].BlendOpAlpha = D3D12_BLEND_OP_ADD;
    blendDesc.RenderTarget[0].LogicOp = D3D12_LOGIC_OP_NOOP;
    blendDesc.RenderTarget[0].RenderTargetWriteMask = D3D12_COLOR_WRITE_ENABLE_ALL;

    D3D12_GRAPHICS_PIPELINE_STATE_DESC gpsDesc = {};
    gpsDesc.InputLayout = { inputElementDescs, _countof(inputElementDescs) };
    gpsDesc.pRootSignature = g_rootSignature;
    gpsDesc.VS = { vertexShader->GetBufferPointer(), vertexShader->GetBufferSize() };
    gpsDesc.PS = { pixelShader->GetBufferPointer(), pixelShader->GetBufferSize() };
    gpsDesc.RasterizerState = rasterizerDesc;
    gpsDesc.BlendState = blendDesc;
    gpsDesc.DepthStencilState.DepthEnable = FALSE;
    gpsDesc.DepthStencilState.StencilEnable = FALSE;
    gpsDesc.SampleMask = UINT_MAX;
    gpsDesc.PrimitiveTopologyType = D3D12_PRIMITIVE_TOPOLOGY_TYPE_TRIANGLE;
    gpsDesc.NumRenderTargets = 1;
    gpsDesc.RTVFormats[0] = DXGI_FORMAT_R8G8B8A8_UNORM;
    gpsDesc.SampleDesc.Count = 1;

    hr = g_device->CreateGraphicsPipelineState(&gpsDesc, IID_PPV_ARGS(&g_pipelineState));

    SAFE_RELEASE(vertexShader);
    SAFE_RELEASE(pixelShader);

    if (FAILED(hr))
    {
        return E_FAIL;
    }

    return S_OK;
}

HRESULT InitBuffer()
{
    if (FAILED(g_device->CreateCommandList(0, D3D12_COMMAND_LIST_TYPE_DIRECT, g_commandAllocator, nullptr, IID_PPV_ARGS(&g_commandList))))
    {
        return E_FAIL;
    }
    g_commandList->Close();

    VERTEX vertices[] =
    {
        { XMFLOAT3(  0.0f,  0.5f, 0.0f), XMFLOAT4(1.0f, 0.0f, 0.0f, 1.0f) },
        { XMFLOAT3(  0.5f, -0.5f, 0.0f), XMFLOAT4(0.0f, 1.0f, 0.0f, 1.0f) },
        { XMFLOAT3( -0.5f, -0.5f, 0.0f), XMFLOAT4(0.0f, 0.0f, 1.0f, 1.0f) },
    };

    const UINT vertexBufferSize = sizeof(vertices);

    D3D12_HEAP_PROPERTIES heapProps = CreateHeapProperties(D3D12_HEAP_TYPE_UPLOAD);
    D3D12_RESOURCE_DESC bufferDesc = CreateBufferDesc(vertexBufferSize);

    if (FAILED(g_device->CreateCommittedResource(
        &heapProps,
        D3D12_HEAP_FLAG_NONE,
        &bufferDesc,
        D3D12_RESOURCE_STATE_GENERIC_READ,
        nullptr,
        IID_PPV_ARGS(&g_vertexBuffer))))
    {
        return E_FAIL;
    }

    UINT8* pVertexDataBegin = nullptr;
    D3D12_RANGE readRange = { 0, 0 };
    g_vertexBuffer->Map(0, &readRange, reinterpret_cast<void**>(&pVertexDataBegin));
    memcpy(pVertexDataBegin, vertices, sizeof(vertices));
    g_vertexBuffer->Unmap(0, nullptr);

    g_vertexBufferView.BufferLocation = g_vertexBuffer->GetGPUVirtualAddress();
    g_vertexBufferView.StrideInBytes = sizeof(VERTEX);
    g_vertexBufferView.SizeInBytes = vertexBufferSize;

    return S_OK;
}

HRESULT InitFence()
{
    if (FAILED(g_device->CreateFence(0, D3D12_FENCE_FLAG_NONE, IID_PPV_ARGS(&g_fence))))
    {
        return E_FAIL;
    }

    g_fenceValue = 1;
    g_fenceEvent = CreateEvent(nullptr, FALSE, FALSE, nullptr);

    if (g_fenceEvent == nullptr)
    {
        return E_FAIL;
    }

    WaitForPreviousFrame();

    return S_OK;
}

void OnRender()
{
    g_commandAllocator->Reset();
    g_commandList->Reset(g_commandAllocator, g_pipelineState);

    g_commandList->SetGraphicsRootSignature(g_rootSignature);
    g_commandList->RSSetViewports(1, &g_viewport);
    g_commandList->RSSetScissorRects(1, &g_scissorRect);

    D3D12_RESOURCE_BARRIER barrierToRT = CreateTransitionBarrier(
        g_renderTargets[g_frameIndex],
        D3D12_RESOURCE_STATE_PRESENT,
        D3D12_RESOURCE_STATE_RENDER_TARGET);
    g_commandList->ResourceBarrier(1, &barrierToRT);

    D3D12_CPU_DESCRIPTOR_HANDLE rtvHandle = g_rtvHeap->GetCPUDescriptorHandleForHeapStart();
    rtvHandle.ptr += g_frameIndex * g_rtvDescriptorSize;

    g_commandList->OMSetRenderTargets(1, &rtvHandle, FALSE, nullptr);

    const FLOAT clearColor[] = { 1.0f, 1.0f, 1.0f, 1.0f };
    g_commandList->ClearRenderTargetView(rtvHandle, clearColor, 0, nullptr);

    g_commandList->IASetPrimitiveTopology(D3D_PRIMITIVE_TOPOLOGY_TRIANGLELIST);
    g_commandList->IASetVertexBuffers(0, 1, &g_vertexBufferView);
    g_commandList->DrawInstanced(3, 1, 0, 0);

    D3D12_RESOURCE_BARRIER barrierToPresent = CreateTransitionBarrier(
        g_renderTargets[g_frameIndex],
        D3D12_RESOURCE_STATE_RENDER_TARGET,
        D3D12_RESOURCE_STATE_PRESENT);
    g_commandList->ResourceBarrier(1, &barrierToPresent);

    g_commandList->Close();

    ID3D12CommandList* ppCommandLists[] = { g_commandList };
    g_commandQueue->ExecuteCommandLists(_countof(ppCommandLists), ppCommandLists);

    g_swapChain->Present(1, 0);

    WaitForPreviousFrame();
}

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

void OnDestroy()
{
    WaitForPreviousFrame();

    if (g_fenceEvent)
    {
        CloseHandle(g_fenceEvent);
        g_fenceEvent = nullptr;
    }

    SAFE_RELEASE(g_fence);
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
