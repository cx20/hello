#include <windows.h>
#include <tchar.h>
#include <wrl.h>
#include <stdio.h>
#include <stdarg.h>

#include <d3d12.h>
#include <dxgi1_6.h>
#include <d3dcompiler.h>
#include "d3dx12.h"

#pragma comment(lib, "d3d12.lib")
#pragma comment(lib, "dxgi.lib")
#pragma comment(lib, "d3dcompiler.lib")

#define WINDOW_WIDTH  640
#define WINDOW_HEIGHT 480

using Microsoft::WRL::ComPtr;

LRESULT CALLBACK WindowProc(HWND hWnd, UINT nMsg, WPARAM wParam, LPARAM lParam);

HRESULT OnInit(HWND hWnd);
HRESULT InitDevice(HWND hWnd);
HRESULT InitView();
HRESULT InitPipeline();
HRESULT InitShader();
HRESULT InitFence();
void OnRender();
void WaitForPreviousFrame();
void OnDestroy();

static const UINT g_frameCount = 2;

static bool   g_enableVerboseFrameLog = true;
static UINT64 g_frameNumber = 0;

ComPtr<ID3D12Device>               g_device;
ComPtr<IDXGISwapChain3>            g_swapChain;
ComPtr<ID3D12Resource>             g_renderTargets[g_frameCount];
ComPtr<ID3D12CommandAllocator>     g_commandAllocator;
ComPtr<ID3D12CommandQueue>         g_commandQueue;
ComPtr<ID3D12RootSignature>        g_rootSignature;
ComPtr<ID3D12DescriptorHeap>       g_rtvHeap;
ComPtr<ID3D12PipelineState>        g_pipelineState;
ComPtr<ID3D12GraphicsCommandList>  g_commandList;

UINT   g_rtvDescriptorSize = 0;
UINT   g_frameIndex = 0;
HANDLE g_fenceEvent = nullptr;
UINT64 g_fenceValue = 0;
ComPtr<ID3D12Fence> g_fence;

static CD3DX12_VIEWPORT g_viewport(
    0.0f, 0.0f,
    static_cast<FLOAT>(WINDOW_WIDTH),
    static_cast<FLOAT>(WINDOW_HEIGHT));

static CD3DX12_RECT g_scissorRect(
    0, 0,
    static_cast<LONG>(WINDOW_WIDTH),
    static_cast<LONG>(WINDOW_HEIGHT));

static void DebugPrintA(const char* format, ...)
{
    char buffer[2048] = {};

    va_list args;
    va_start(args, format);
    vsnprintf_s(buffer, _countof(buffer), _TRUNCATE, format, args);
    va_end(args);

    OutputDebugStringA(buffer);
}

static void DebugPrintW(const wchar_t* format, ...)
{
    wchar_t buffer[2048] = {};

    va_list args;
    va_start(args, format);
    _vsnwprintf_s(buffer, _countof(buffer), _TRUNCATE, format, args);
    va_end(args);

    OutputDebugStringW(buffer);
}

static void DebugPrintHr(const char* label, HRESULT hr)
{
    DebugPrintA("[DX12-GS] %s hr=0x%08X\n", label, static_cast<unsigned int>(hr));
}

static void ShowErrorMessage(LPCWSTR text)
{
    MessageBoxW(nullptr, text, L"Error", MB_ICONERROR | MB_OK);
}

static HRESULT CompileShaderFromFile(
    LPCWSTR filePath,
    LPCSTR entryPoint,
    LPCSTR targetProfile,
    ComPtr<ID3DBlob>& shaderBlob)
{
    DebugPrintA("[DX12-GS] CompileShader begin entry=%s target=%s\n", entryPoint, targetProfile);
    DebugPrintW(L"[DX12-GS] Shader file=%s\n", filePath);

    UINT compileFlags = 0;
#if defined(_DEBUG)
    compileFlags = D3DCOMPILE_DEBUG | D3DCOMPILE_SKIP_OPTIMIZATION;
#endif

    ComPtr<ID3DBlob> errorBlob;

    HRESULT hr = D3DCompileFromFile(
        filePath,
        nullptr,
        D3D_COMPILE_STANDARD_FILE_INCLUDE,
        entryPoint,
        targetProfile,
        compileFlags,
        0,
        shaderBlob.GetAddressOf(),
        errorBlob.GetAddressOf());

    if (FAILED(hr))
    {
        DebugPrintHr("D3DCompileFromFile failed", hr);
        if (errorBlob)
        {
            OutputDebugStringA("[DX12-GS] Compiler errors:\n");
            OutputDebugStringA(static_cast<const char*>(errorBlob->GetBufferPointer()));
            OutputDebugStringA("\n");
        }
        return hr;
    }

    DebugPrintA("[DX12-GS] CompileShader success entry=%s target=%s size=%zu bytes\n",
        entryPoint, targetProfile, shaderBlob->GetBufferSize());

    return S_OK;
}

int APIENTRY _tWinMain(HINSTANCE hInstance, HINSTANCE, LPTSTR, int)
{
    DebugPrintA("[DX12-GS] Application start.\n");

    WNDCLASSEX windowClass = {};
    windowClass.cbSize = sizeof(WNDCLASSEX);
    windowClass.style = CS_HREDRAW | CS_VREDRAW;
    windowClass.lpfnWndProc = WindowProc;
    windowClass.hInstance = hInstance;
    windowClass.hCursor = LoadCursor(nullptr, IDC_ARROW);
    windowClass.lpszClassName = _T("windowClass");
    RegisterClassEx(&windowClass);

    RECT windowRect = { 0, 0, WINDOW_WIDTH, WINDOW_HEIGHT };
    AdjustWindowRect(&windowRect, WS_OVERLAPPEDWINDOW, FALSE);

    HWND hWnd = CreateWindow(
        _T("windowClass"),
        _T("DirectX 12 Geometry Shader Triangle (DebugView)"),
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
    DebugPrintA("[DX12-GS] OnInit begin.\n");

    if (FAILED(InitDevice(hWnd)))   return E_FAIL;
    if (FAILED(InitView()))         return E_FAIL;
    if (FAILED(InitPipeline()))     return E_FAIL;
    if (FAILED(InitShader()))       return E_FAIL;
    if (FAILED(InitFence()))        return E_FAIL;

    DebugPrintA("[DX12-GS] Vertex buffer path is not used.\n");
    DebugPrintA("[DX12-GS] Geometry shader path is enabled.\n");
    DebugPrintA("[DX12-GS] Input primitive topology is POINTLIST.\n");
    DebugPrintA("[DX12-GS] DrawInstanced(1, 1, 0, 0) will feed one point into GS.\n");
    DebugPrintA("[DX12-GS] The geometry shader expands one point into one triangle.\n");
    DebugPrintA("[DX12-GS] OnInit completed successfully.\n");

    return S_OK;
}

HRESULT InitDevice(HWND hWnd)
{
    UINT dxgiFactoryFlags = 0;

    ComPtr<IDXGIFactory6> factory;
    HRESULT hr = CreateDXGIFactory2(dxgiFactoryFlags, IID_PPV_ARGS(factory.GetAddressOf()));
    if (FAILED(hr))
    {
        DebugPrintHr("CreateDXGIFactory2 failed", hr);
        return E_FAIL;
    }

    ComPtr<IDXGIAdapter1> adapter;
    ComPtr<IDXGIAdapter1> hardwareAdapter;

    for (UINT adapterIndex = 0;
         factory->EnumAdapters1(adapterIndex, adapter.GetAddressOf()) != DXGI_ERROR_NOT_FOUND;
         ++adapterIndex)
    {
        DXGI_ADAPTER_DESC1 adapterDesc = {};
        adapter->GetDesc1(&adapterDesc);

        DebugPrintW(L"[DX12-GS] Enumerated adapter: %s\n", adapterDesc.Description);
        DebugPrintA("[DX12-GS] Adapter VendorId=0x%04X DeviceId=0x%04X Flags=0x%08X DedicatedVideoMemory=%llu MB\n",
            adapterDesc.VendorId,
            adapterDesc.DeviceId,
            adapterDesc.Flags,
            static_cast<unsigned long long>(adapterDesc.DedicatedVideoMemory / (1024ull * 1024ull)));

        if (adapterDesc.Flags & DXGI_ADAPTER_FLAG_SOFTWARE)
            continue;

        if (SUCCEEDED(D3D12CreateDevice(adapter.Get(), D3D_FEATURE_LEVEL_11_0, __uuidof(ID3D12Device), nullptr)))
        {
            hardwareAdapter = adapter;
            break;
        }
    }

    if (!hardwareAdapter)
    {
        ShowErrorMessage(L"No suitable hardware adapter was found.");
        DebugPrintA("[DX12-GS] No suitable hardware adapter was found.\n");
        return E_FAIL;
    }

    hr = D3D12CreateDevice(
        hardwareAdapter.Get(),
        D3D_FEATURE_LEVEL_11_0,
        IID_PPV_ARGS(g_device.GetAddressOf()));

    if (FAILED(hr))
    {
        DebugPrintHr("D3D12CreateDevice failed", hr);
        return E_FAIL;
    }

    DebugPrintA("[DX12-GS] D3D12 device created successfully.\n");

    D3D12_FEATURE_DATA_FEATURE_LEVELS featureLevels = {};
    D3D_FEATURE_LEVEL levels[] =
    {
        D3D_FEATURE_LEVEL_12_2,
        D3D_FEATURE_LEVEL_12_1,
        D3D_FEATURE_LEVEL_12_0,
        D3D_FEATURE_LEVEL_11_1,
        D3D_FEATURE_LEVEL_11_0
    };
    featureLevels.NumFeatureLevels = _countof(levels);
    featureLevels.pFeatureLevelsRequested = levels;

    if (SUCCEEDED(g_device->CheckFeatureSupport(
        D3D12_FEATURE_FEATURE_LEVELS,
        &featureLevels,
        sizeof(featureLevels))))
    {
        DebugPrintA("[DX12-GS] MaxFeatureLevel = 0x%X\n",
            static_cast<unsigned int>(featureLevels.MaxSupportedFeatureLevel));
    }

    D3D12_COMMAND_QUEUE_DESC queueDesc = {};
    queueDesc.Type = D3D12_COMMAND_LIST_TYPE_DIRECT;
    queueDesc.Flags = D3D12_COMMAND_QUEUE_FLAG_NONE;

    hr = g_device->CreateCommandQueue(&queueDesc, IID_PPV_ARGS(g_commandQueue.GetAddressOf()));
    if (FAILED(hr))
    {
        DebugPrintHr("CreateCommandQueue failed", hr);
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

    ComPtr<IDXGISwapChain1> swapChain;
    hr = factory->CreateSwapChainForHwnd(
        g_commandQueue.Get(),
        hWnd,
        &swapChainDesc,
        nullptr,
        nullptr,
        swapChain.GetAddressOf());

    if (FAILED(hr))
    {
        DebugPrintHr("CreateSwapChainForHwnd failed", hr);
        return E_FAIL;
    }

    hr = factory->MakeWindowAssociation(hWnd, DXGI_MWA_NO_ALT_ENTER);
    if (FAILED(hr))
    {
        DebugPrintHr("MakeWindowAssociation failed", hr);
        return E_FAIL;
    }

    hr = swapChain.As(&g_swapChain);
    if (FAILED(hr))
    {
        DebugPrintHr("SwapChain.As failed", hr);
        return E_FAIL;
    }

    g_frameIndex = g_swapChain->GetCurrentBackBufferIndex();
    DebugPrintA("[DX12-GS] Initial back buffer index = %u\n", g_frameIndex);

    return S_OK;
}

HRESULT InitView()
{
    D3D12_DESCRIPTOR_HEAP_DESC rtvHeapDesc = {};
    rtvHeapDesc.NumDescriptors = g_frameCount;
    rtvHeapDesc.Type = D3D12_DESCRIPTOR_HEAP_TYPE_RTV;
    rtvHeapDesc.Flags = D3D12_DESCRIPTOR_HEAP_FLAG_NONE;

    HRESULT hr = g_device->CreateDescriptorHeap(&rtvHeapDesc, IID_PPV_ARGS(g_rtvHeap.GetAddressOf()));
    if (FAILED(hr))
    {
        DebugPrintHr("CreateDescriptorHeap failed", hr);
        return E_FAIL;
    }

    g_rtvDescriptorSize = g_device->GetDescriptorHandleIncrementSize(D3D12_DESCRIPTOR_HEAP_TYPE_RTV);
    DebugPrintA("[DX12-GS] RTV descriptor size = %u\n", g_rtvDescriptorSize);

    CD3DX12_CPU_DESCRIPTOR_HANDLE rtvHandle(g_rtvHeap->GetCPUDescriptorHandleForHeapStart());

    for (UINT i = 0; i < g_frameCount; ++i)
    {
        hr = g_swapChain->GetBuffer(i, IID_PPV_ARGS(g_renderTargets[i].GetAddressOf()));
        if (FAILED(hr))
        {
            DebugPrintHr("SwapChain->GetBuffer failed", hr);
            return E_FAIL;
        }

        g_device->CreateRenderTargetView(g_renderTargets[i].Get(), nullptr, rtvHandle);
        DebugPrintA("[DX12-GS] RTV created for back buffer %u\n", i);

        rtvHandle.Offset(1, g_rtvDescriptorSize);
    }

    return S_OK;
}

HRESULT InitPipeline()
{
    HRESULT hr = g_device->CreateCommandAllocator(
        D3D12_COMMAND_LIST_TYPE_DIRECT,
        IID_PPV_ARGS(g_commandAllocator.GetAddressOf()));

    if (FAILED(hr))
    {
        DebugPrintHr("CreateCommandAllocator failed", hr);
        return E_FAIL;
    }

    CD3DX12_ROOT_SIGNATURE_DESC rsDesc;
    rsDesc.Init(0, nullptr, 0, nullptr, D3D12_ROOT_SIGNATURE_FLAG_ALLOW_INPUT_ASSEMBLER_INPUT_LAYOUT);

    ComPtr<ID3DBlob> signature;
    ComPtr<ID3DBlob> error;

    hr = D3D12SerializeRootSignature(
        &rsDesc,
        D3D_ROOT_SIGNATURE_VERSION_1,
        signature.GetAddressOf(),
        error.GetAddressOf());

    if (FAILED(hr))
    {
        DebugPrintHr("D3D12SerializeRootSignature failed", hr);
        if (error)
        {
            OutputDebugStringA("[DX12-GS] Root signature errors:\n");
            OutputDebugStringA(static_cast<const char*>(error->GetBufferPointer()));
            OutputDebugStringA("\n");
        }
        return E_FAIL;
    }

    hr = g_device->CreateRootSignature(
        0,
        signature->GetBufferPointer(),
        signature->GetBufferSize(),
        IID_PPV_ARGS(g_rootSignature.GetAddressOf()));

    if (FAILED(hr))
    {
        DebugPrintHr("CreateRootSignature failed", hr);
        return E_FAIL;
    }

    DebugPrintA("[DX12-GS] Root signature created.\n");

    hr = g_device->CreateCommandList(
        0,
        D3D12_COMMAND_LIST_TYPE_DIRECT,
        g_commandAllocator.Get(),
        nullptr,
        IID_PPV_ARGS(g_commandList.GetAddressOf()));

    if (FAILED(hr))
    {
        DebugPrintHr("CreateCommandList failed", hr);
        return E_FAIL;
    }

    hr = g_commandList->Close();
    if (FAILED(hr))
    {
        DebugPrintHr("CommandList->Close failed", hr);
        return E_FAIL;
    }

    DebugPrintA("[DX12-GS] Command list created and closed.\n");

    return S_OK;
}

HRESULT InitShader()
{
    ComPtr<ID3DBlob> vertexShader;
    ComPtr<ID3DBlob> geometryShader;
    ComPtr<ID3DBlob> pixelShader;

    if (FAILED(CompileShaderFromFile(L"hello.hlsl", "VSMain", "vs_5_0", vertexShader)))
    {
        ShowErrorMessage(L"Failed to compile vertex shader.");
        return E_FAIL;
    }

    if (FAILED(CompileShaderFromFile(L"hello.hlsl", "GSMain", "gs_5_0", geometryShader)))
    {
        ShowErrorMessage(L"Failed to compile geometry shader.");
        return E_FAIL;
    }

    if (FAILED(CompileShaderFromFile(L"hello.hlsl", "PSMain", "ps_5_0", pixelShader)))
    {
        ShowErrorMessage(L"Failed to compile pixel shader.");
        return E_FAIL;
    }

    D3D12_GRAPHICS_PIPELINE_STATE_DESC psoDesc = {};
    psoDesc.InputLayout = { nullptr, 0 };
    psoDesc.pRootSignature = g_rootSignature.Get();
    psoDesc.VS = CD3DX12_SHADER_BYTECODE(vertexShader.Get());
    psoDesc.GS = CD3DX12_SHADER_BYTECODE(geometryShader.Get());
    psoDesc.PS = CD3DX12_SHADER_BYTECODE(pixelShader.Get());
    psoDesc.RasterizerState = CD3DX12_RASTERIZER_DESC(D3D12_DEFAULT);
    psoDesc.BlendState = CD3DX12_BLEND_DESC(D3D12_DEFAULT);
    psoDesc.DepthStencilState.DepthEnable = FALSE;
    psoDesc.DepthStencilState.StencilEnable = FALSE;
    psoDesc.SampleMask = UINT_MAX;

    // The input primitive is a point.
    // The geometry shader expands that point into a triangle.
    psoDesc.PrimitiveTopologyType = D3D12_PRIMITIVE_TOPOLOGY_TYPE_POINT;

    psoDesc.NumRenderTargets = 1;
    psoDesc.RTVFormats[0] = DXGI_FORMAT_R8G8B8A8_UNORM;
    psoDesc.SampleDesc.Count = 1;

    HRESULT hr = g_device->CreateGraphicsPipelineState(&psoDesc, IID_PPV_ARGS(g_pipelineState.GetAddressOf()));
    if (FAILED(hr))
    {
        DebugPrintHr("CreateGraphicsPipelineState failed", hr);
        return E_FAIL;
    }

    DebugPrintA("[DX12-GS] Graphics PSO created successfully.\n");
    DebugPrintA("[DX12-GS] PSO stages: VS=enabled GS=enabled PS=enabled\n");
    DebugPrintA("[DX12-GS] Vertex shader bytecode size   = %zu bytes\n", vertexShader->GetBufferSize());
    DebugPrintA("[DX12-GS] Geometry shader bytecode size = %zu bytes\n", geometryShader->GetBufferSize());
    DebugPrintA("[DX12-GS] Pixel shader bytecode size    = %zu bytes\n", pixelShader->GetBufferSize());

    return S_OK;
}

HRESULT InitFence()
{
    HRESULT hr = g_device->CreateFence(0, D3D12_FENCE_FLAG_NONE, IID_PPV_ARGS(g_fence.GetAddressOf()));
    if (FAILED(hr))
    {
        DebugPrintHr("CreateFence failed", hr);
        return E_FAIL;
    }

    g_fenceValue = 1;
    g_fenceEvent = CreateEvent(nullptr, FALSE, FALSE, nullptr);

    if (g_fenceEvent == nullptr)
    {
        DebugPrintA("[DX12-GS] CreateEvent failed.\n");
        return E_FAIL;
    }

    DebugPrintA("[DX12-GS] Fence and event created.\n");

    WaitForPreviousFrame();
    return S_OK;
}

void OnRender()
{
    ++g_frameNumber;

    if (g_enableVerboseFrameLog)
    {
        DebugPrintA("\n[DX12-GS] ===== Frame %llu begin =====\n",
            static_cast<unsigned long long>(g_frameNumber));
        DebugPrintA("[DX12-GS] Current back buffer index = %u\n", g_frameIndex);
    }

    HRESULT hr = g_commandAllocator->Reset();
    if (FAILED(hr))
    {
        DebugPrintHr("CommandAllocator->Reset failed", hr);
        return;
    }
    if (g_enableVerboseFrameLog)
        DebugPrintA("[DX12-GS] CommandAllocator reset.\n");

    hr = g_commandList->Reset(g_commandAllocator.Get(), g_pipelineState.Get());
    if (FAILED(hr))
    {
        DebugPrintHr("CommandList->Reset failed", hr);
        return;
    }
    if (g_enableVerboseFrameLog)
        DebugPrintA("[DX12-GS] CommandList reset with VS+GS+PS PSO.\n");

    g_commandList->SetGraphicsRootSignature(g_rootSignature.Get());
    if (g_enableVerboseFrameLog)
        DebugPrintA("[DX12-GS] Root signature set.\n");

    g_commandList->RSSetViewports(1, &g_viewport);
    g_commandList->RSSetScissorRects(1, &g_scissorRect);
    if (g_enableVerboseFrameLog)
        DebugPrintA("[DX12-GS] Viewport and scissor set.\n");

    if (g_enableVerboseFrameLog)
        DebugPrintA("[DX12-GS] ResourceBarrier: PRESENT -> RENDER_TARGET\n");

    g_commandList->ResourceBarrier(
        1,
        &CD3DX12_RESOURCE_BARRIER::Transition(
            g_renderTargets[g_frameIndex].Get(),
            D3D12_RESOURCE_STATE_PRESENT,
            D3D12_RESOURCE_STATE_RENDER_TARGET));

    CD3DX12_CPU_DESCRIPTOR_HANDLE rtvHandle(
        g_rtvHeap->GetCPUDescriptorHandleForHeapStart(),
        g_frameIndex,
        g_rtvDescriptorSize);

    g_commandList->OMSetRenderTargets(1, &rtvHandle, FALSE, nullptr);
    if (g_enableVerboseFrameLog)
        DebugPrintA("[DX12-GS] Render target bound.\n");

    const FLOAT clearColor[] = { 1.0f, 1.0f, 1.0f, 1.0f };
    g_commandList->ClearRenderTargetView(rtvHandle, clearColor, 0, nullptr);
    if (g_enableVerboseFrameLog)
        DebugPrintA("[DX12-GS] Render target cleared.\n");

    g_commandList->IASetPrimitiveTopology(D3D_PRIMITIVE_TOPOLOGY_POINTLIST);
    DebugPrintA("[DX12-GS] IA primitive topology = POINTLIST\n");

    // One point is submitted.
    // The geometry shader receives that point and emits one triangle.
    DebugPrintA("[DX12-GS] DrawInstanced(1, 1, 0, 0) called.\n");
    DebugPrintA("[DX12-GS] Expected GS behavior: point input -> triangle output.\n");
    g_commandList->DrawInstanced(1, 1, 0, 0);

    if (g_enableVerboseFrameLog)
        DebugPrintA("[DX12-GS] ResourceBarrier: RENDER_TARGET -> PRESENT\n");

    g_commandList->ResourceBarrier(
        1,
        &CD3DX12_RESOURCE_BARRIER::Transition(
            g_renderTargets[g_frameIndex].Get(),
            D3D12_RESOURCE_STATE_RENDER_TARGET,
            D3D12_RESOURCE_STATE_PRESENT));

    hr = g_commandList->Close();
    if (FAILED(hr))
    {
        DebugPrintHr("CommandList->Close failed", hr);
        return;
    }
    if (g_enableVerboseFrameLog)
        DebugPrintA("[DX12-GS] CommandList closed.\n");

    ID3D12CommandList* commandLists[] = { g_commandList.Get() };
    DebugPrintA("[DX12-GS] ExecuteCommandLists called.\n");
    g_commandQueue->ExecuteCommandLists(_countof(commandLists), commandLists);

    hr = g_swapChain->Present(1, 0);
    if (FAILED(hr))
    {
        DebugPrintHr("SwapChain->Present failed", hr);
        return;
    }
    if (g_enableVerboseFrameLog)
        DebugPrintA("[DX12-GS] Present succeeded.\n");

    WaitForPreviousFrame();

    if (g_enableVerboseFrameLog)
    {
        DebugPrintA("[DX12-GS] ===== Frame %llu end =====\n",
            static_cast<unsigned long long>(g_frameNumber));
    }
}

void WaitForPreviousFrame()
{
    const UINT64 fence = g_fenceValue;

    DebugPrintA("[DX12-GS] Signal fence value=%llu\n",
        static_cast<unsigned long long>(fence));

    g_commandQueue->Signal(g_fence.Get(), fence);
    g_fenceValue++;

    const UINT64 completedValue = g_fence->GetCompletedValue();
    DebugPrintA("[DX12-GS] Fence completed value before wait=%llu\n",
        static_cast<unsigned long long>(completedValue));

    if (completedValue < fence)
    {
        DebugPrintA("[DX12-GS] Waiting for fence completion...\n");
        g_fence->SetEventOnCompletion(fence, g_fenceEvent);
        WaitForSingleObject(g_fenceEvent, INFINITE);
        DebugPrintA("[DX12-GS] Fence wait completed.\n");
    }

    g_frameIndex = g_swapChain->GetCurrentBackBufferIndex();
    DebugPrintA("[DX12-GS] New back buffer index=%u\n", g_frameIndex);
}

void OnDestroy()
{
    DebugPrintA("[DX12-GS] OnDestroy begin.\n");

    WaitForPreviousFrame();

    if (g_fenceEvent)
    {
        CloseHandle(g_fenceEvent);
        g_fenceEvent = nullptr;
    }

    DebugPrintA("[DX12-GS] OnDestroy completed.\n");
}