#include <windows.h>
#include <tchar.h>
#include <wrl.h>
#include <stdio.h>
#include <stdarg.h>

#include <d3d12.h>
#include <dxgi1_6.h>
#include <dxcapi.h>
#include "d3dx12.h"

#pragma comment(lib, "d3d12.lib")
#pragma comment(lib, "dxgi.lib")
#pragma comment(lib, "dxcompiler.lib")

#define WINDOW_WIDTH    640
#define WINDOW_HEIGHT   480

using Microsoft::WRL::ComPtr;

LRESULT CALLBACK WindowProc(HWND hWnd, UINT nMsg, WPARAM wParam, LPARAM lParam);
HRESULT OnInit(HWND hWnd);
HRESULT InitDevice(HWND hWnd);
HRESULT InitView();
HRESULT InitTraffic();
HRESULT InitShader();
HRESULT InitFence();
void OnRender();
void WaitForPreviousFrame();
void OnDestroy();

static const UINT g_frameCount = 2;

static bool   g_enableVerboseFrameLog = true;
static UINT64 g_frameNumber = 0;

ComPtr<ID3D12Device2>                 g_device;
ComPtr<IDXGISwapChain3>               g_swapChain;
ComPtr<ID3D12Resource>                g_renderTargets[g_frameCount];
ComPtr<ID3D12CommandAllocator>        g_commandAllocator;
ComPtr<ID3D12CommandQueue>            g_commandQueue;
ComPtr<ID3D12RootSignature>           g_rootSignature;
ComPtr<ID3D12DescriptorHeap>          g_rtvHeap;
ComPtr<ID3D12PipelineState>           g_pipelineState;
ComPtr<ID3D12GraphicsCommandList6>    g_commandList;
static UINT                           g_rtvDescriptorSize = 0;

static CD3DX12_VIEWPORT g_viewport(
    0.0f, 0.0f,
    static_cast<FLOAT>(WINDOW_WIDTH),
    static_cast<FLOAT>(WINDOW_HEIGHT));

static CD3DX12_RECT g_scissorRect(
    0, 0,
    static_cast<LONG>(WINDOW_WIDTH),
    static_cast<LONG>(WINDOW_HEIGHT));

static UINT         g_frameIndex = 0;
static HANDLE       g_fenceEvent = nullptr;
ComPtr<ID3D12Fence> g_fence;
static UINT64       g_fenceValue = 0;

struct PipelineStateStream
{
    CD3DX12_PIPELINE_STATE_STREAM_ROOT_SIGNATURE        RootSignature;
    CD3DX12_PIPELINE_STATE_STREAM_MS                    MS;
    CD3DX12_PIPELINE_STATE_STREAM_PS                    PS;
    CD3DX12_PIPELINE_STATE_STREAM_RASTERIZER            RasterizerState;
    CD3DX12_PIPELINE_STATE_STREAM_BLEND_DESC            BlendState;
    CD3DX12_PIPELINE_STATE_STREAM_DEPTH_STENCIL         DepthStencilState;
    CD3DX12_PIPELINE_STATE_STREAM_SAMPLE_MASK           SampleMask;
    CD3DX12_PIPELINE_STATE_STREAM_PRIMITIVE_TOPOLOGY    PrimitiveTopologyType;
    CD3DX12_PIPELINE_STATE_STREAM_RENDER_TARGET_FORMATS RTVFormats;
    CD3DX12_PIPELINE_STATE_STREAM_SAMPLE_DESC           SampleDesc;
};

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
    DebugPrintA("[DX12] %s hr=0x%08X\n", label, static_cast<unsigned int>(hr));
}

static const char* MeshShaderTierToString(D3D12_MESH_SHADER_TIER tier)
{
    switch (tier)
    {
    case D3D12_MESH_SHADER_TIER_NOT_SUPPORTED: return "NOT_SUPPORTED";
    case D3D12_MESH_SHADER_TIER_1:             return "TIER_1";
    default:                                   return "UNKNOWN";
    }
}

static void ShowErrorMessage(LPCWSTR text)
{
    MessageBoxW(nullptr, text, L"Error", MB_ICONERROR | MB_OK);
}

static HRESULT CompileShader(
    LPCWSTR filePath,
    LPCWSTR entryPoint,
    LPCWSTR targetProfile,
    ComPtr<IDxcBlob>& shaderBlob)
{
    DebugPrintW(L"[DX12] CompileShader begin file=%s entry=%s target=%s\n",
        filePath, entryPoint, targetProfile);

    ComPtr<IDxcUtils> utils;
    ComPtr<IDxcCompiler3> compiler;
    ComPtr<IDxcIncludeHandler> includeHandler;

    HRESULT hr = DxcCreateInstance(CLSID_DxcUtils, IID_PPV_ARGS(utils.GetAddressOf()));
    if (FAILED(hr))
    {
        DebugPrintHr("DxcCreateInstance(CLSID_DxcUtils) failed", hr);
        return E_FAIL;
    }

    hr = DxcCreateInstance(CLSID_DxcCompiler, IID_PPV_ARGS(compiler.GetAddressOf()));
    if (FAILED(hr))
    {
        DebugPrintHr("DxcCreateInstance(CLSID_DxcCompiler) failed", hr);
        return E_FAIL;
    }

    hr = utils->CreateDefaultIncludeHandler(includeHandler.GetAddressOf());
    if (FAILED(hr))
    {
        DebugPrintHr("CreateDefaultIncludeHandler failed", hr);
        return E_FAIL;
    }

    uint32_t codePage = DXC_CP_UTF8;
    ComPtr<IDxcBlobEncoding> sourceBlob;
    hr = utils->LoadFile(filePath, &codePage, sourceBlob.GetAddressOf());
    if (FAILED(hr))
    {
        DebugPrintHr("LoadFile failed", hr);
        return E_FAIL;
    }

    DxcBuffer sourceBuffer = {};
    sourceBuffer.Ptr      = sourceBlob->GetBufferPointer();
    sourceBuffer.Size     = sourceBlob->GetBufferSize();
    sourceBuffer.Encoding = DXC_CP_UTF8;

    LPCWSTR arguments[] =
    {
        filePath,
        L"-E", entryPoint,
        L"-T", targetProfile,
        L"-Zi",
        L"-Qembed_debug",
        L"-Od"
    };

    ComPtr<IDxcResult> results;
    hr = compiler->Compile(
        &sourceBuffer,
        arguments,
        _countof(arguments),
        includeHandler.Get(),
        IID_PPV_ARGS(results.GetAddressOf()));

    if (FAILED(hr))
    {
        DebugPrintHr("compiler->Compile failed", hr);
        return E_FAIL;
    }

    HRESULT compileStatus = S_OK;
    hr = results->GetStatus(&compileStatus);
    if (FAILED(hr))
    {
        DebugPrintHr("results->GetStatus failed", hr);
        return E_FAIL;
    }

    if (FAILED(compileStatus))
    {
        DebugPrintHr("shader compilation failed", compileStatus);

        ComPtr<IDxcBlobUtf8> errors;
        results->GetOutput(DXC_OUT_ERRORS, IID_PPV_ARGS(errors.GetAddressOf()), nullptr);

        if (errors && errors->GetStringLength() > 0)
        {
            OutputDebugStringA("[DX12] DXC errors:\n");
            OutputDebugStringA(errors->GetStringPointer());
            OutputDebugStringA("\n");
        }

        return E_FAIL;
    }

    hr = results->GetOutput(DXC_OUT_OBJECT, IID_PPV_ARGS(shaderBlob.GetAddressOf()), nullptr);
    if (FAILED(hr))
    {
        DebugPrintHr("GetOutput(DXC_OUT_OBJECT) failed", hr);
        return E_FAIL;
    }

    DebugPrintW(L"[DX12] CompileShader success entry=%s target=%s size=%zu bytes\n",
        entryPoint, targetProfile, shaderBlob->GetBufferSize());

    return S_OK;
}

int APIENTRY _tWinMain(HINSTANCE hInstance, HINSTANCE, LPTSTR, int)
{
    DebugPrintA("[DX12] Application start.\n");

    WNDCLASSEX windowClass = {};
    windowClass.cbSize        = sizeof(WNDCLASSEX);
    windowClass.style         = CS_HREDRAW | CS_VREDRAW;
    windowClass.lpfnWndProc   = WindowProc;
    windowClass.hInstance     = hInstance;
    windowClass.hCursor       = LoadCursor(nullptr, IDC_ARROW);
    windowClass.lpszClassName = _T("windowClass");
    RegisterClassEx(&windowClass);

    RECT windowRect = { 0, 0, WINDOW_WIDTH, WINDOW_HEIGHT };
    AdjustWindowRect(&windowRect, WS_OVERLAPPEDWINDOW, FALSE);

    HWND hWnd = CreateWindow(
        _T("windowClass"),
        _T("DirectX 12 Mesh Shader Triangle"),
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
    DebugPrintA("[DX12] OnInit begin.\n");

    if (FAILED(InitDevice(hWnd))) return E_FAIL;
    if (FAILED(InitView()))       return E_FAIL;
    if (FAILED(InitTraffic()))    return E_FAIL;
    if (FAILED(InitShader()))     return E_FAIL;
    if (FAILED(InitFence()))      return E_FAIL;

    DebugPrintA("[DX12] Vertex buffer path is not used.\n");
    DebugPrintA("[DX12] DrawInstanced is not used.\n");
    DebugPrintA("[DX12] Rendering path uses DispatchMesh only.\n");
    DebugPrintA("[DX12] OnInit completed successfully.\n");

    return S_OK;
}

HRESULT InitDevice(HWND hWnd)
{
    UINT dxgiFactoryFlags = 0;

    ComPtr<IDXGIFactory6> factory;
    if (FAILED(CreateDXGIFactory2(dxgiFactoryFlags, IID_PPV_ARGS(factory.GetAddressOf()))))
        return E_FAIL;

    ComPtr<IDXGIAdapter1> adapter;
    ComPtr<IDXGIAdapter1> hardwareAdapter;

    for (UINT adapterIndex = 0;
         factory->EnumAdapters1(adapterIndex, adapter.GetAddressOf()) != DXGI_ERROR_NOT_FOUND;
         ++adapterIndex)
    {
        DXGI_ADAPTER_DESC1 adapterDesc = {};
        adapter->GetDesc1(&adapterDesc);

        DebugPrintW(L"[DX12] Enumerated adapter: %s\n", adapterDesc.Description);
        DebugPrintA("[DX12] Adapter VendorId=0x%04X DeviceId=0x%04X Flags=0x%08X DedicatedVideoMemory=%llu MB\n",
            adapterDesc.VendorId,
            adapterDesc.DeviceId,
            adapterDesc.Flags,
            static_cast<unsigned long long>(adapterDesc.DedicatedVideoMemory / (1024ull * 1024ull)));

        if (adapterDesc.Flags & DXGI_ADAPTER_FLAG_SOFTWARE)
            continue;

        if (SUCCEEDED(D3D12CreateDevice(adapter.Get(), D3D_FEATURE_LEVEL_12_2, __uuidof(ID3D12Device), nullptr)))
        {
            hardwareAdapter = adapter;
            break;
        }
    }

    if (!hardwareAdapter)
    {
        ShowErrorMessage(L"No suitable hardware adapter for Mesh Shader was found.");
        return E_FAIL;
    }

    if (FAILED(D3D12CreateDevice(
        hardwareAdapter.Get(),
        D3D_FEATURE_LEVEL_12_2,
        IID_PPV_ARGS(g_device.GetAddressOf()))))
    {
        return E_FAIL;
    }

    DebugPrintW(L"[DX12] D3D12 device created successfully.\n");

    D3D12_FEATURE_DATA_D3D12_OPTIONS7 options7 = {};
    if (FAILED(g_device->CheckFeatureSupport(
        D3D12_FEATURE_D3D12_OPTIONS7,
        &options7,
        sizeof(options7))))
    {
        ShowErrorMessage(L"Failed to query D3D12 options.");
        return E_FAIL;
    }

    DebugPrintA("[DX12] MeshShaderTier = %s (%d)\n",
        MeshShaderTierToString(options7.MeshShaderTier),
        static_cast<int>(options7.MeshShaderTier));

    if (options7.MeshShaderTier == D3D12_MESH_SHADER_TIER_NOT_SUPPORTED)
    {
        ShowErrorMessage(L"This GPU or driver does not support Mesh Shader.");
        return E_FAIL;
    }

    D3D12_FEATURE_DATA_FEATURE_LEVELS featureLevels = {};
    D3D_FEATURE_LEVEL levels[] =
    {
        D3D_FEATURE_LEVEL_12_2,
        D3D_FEATURE_LEVEL_12_1,
        D3D_FEATURE_LEVEL_12_0
    };
    featureLevels.NumFeatureLevels = _countof(levels);
    featureLevels.pFeatureLevelsRequested = levels;

    if (SUCCEEDED(g_device->CheckFeatureSupport(
        D3D12_FEATURE_FEATURE_LEVELS,
        &featureLevels,
        sizeof(featureLevels))))
    {
        DebugPrintA("[DX12] MaxFeatureLevel = 0x%X\n",
            static_cast<unsigned int>(featureLevels.MaxSupportedFeatureLevel));
    }

    D3D12_COMMAND_QUEUE_DESC queueDesc = {};
    queueDesc.Type  = D3D12_COMMAND_LIST_TYPE_DIRECT;
    queueDesc.Flags = D3D12_COMMAND_QUEUE_FLAG_NONE;

    if (FAILED(g_device->CreateCommandQueue(&queueDesc, IID_PPV_ARGS(g_commandQueue.GetAddressOf()))))
        return E_FAIL;

    DXGI_SWAP_CHAIN_DESC1 swapChainDesc = {};
    swapChainDesc.BufferCount      = g_frameCount;
    swapChainDesc.Width            = WINDOW_WIDTH;
    swapChainDesc.Height           = WINDOW_HEIGHT;
    swapChainDesc.Format           = DXGI_FORMAT_R8G8B8A8_UNORM;
    swapChainDesc.BufferUsage      = DXGI_USAGE_RENDER_TARGET_OUTPUT;
    swapChainDesc.SwapEffect       = DXGI_SWAP_EFFECT_FLIP_DISCARD;
    swapChainDesc.SampleDesc.Count = 1;

    ComPtr<IDXGISwapChain1> swapChain;
    if (FAILED(factory->CreateSwapChainForHwnd(
        g_commandQueue.Get(),
        hWnd,
        &swapChainDesc,
        nullptr,
        nullptr,
        swapChain.GetAddressOf())))
    {
        return E_FAIL;
    }

    if (FAILED(factory->MakeWindowAssociation(hWnd, DXGI_MWA_NO_ALT_ENTER)))
        return E_FAIL;

    if (FAILED(swapChain.As(&g_swapChain)))
        return E_FAIL;

    g_frameIndex = g_swapChain->GetCurrentBackBufferIndex();
    DebugPrintA("[DX12] Initial back buffer index = %u\n", g_frameIndex);

    return S_OK;
}

HRESULT InitView()
{
    D3D12_DESCRIPTOR_HEAP_DESC rtvHeapDesc = {};
    rtvHeapDesc.NumDescriptors = g_frameCount;
    rtvHeapDesc.Type           = D3D12_DESCRIPTOR_HEAP_TYPE_RTV;
    rtvHeapDesc.Flags          = D3D12_DESCRIPTOR_HEAP_FLAG_NONE;

    if (FAILED(g_device->CreateDescriptorHeap(&rtvHeapDesc, IID_PPV_ARGS(g_rtvHeap.GetAddressOf()))))
        return E_FAIL;

    g_rtvDescriptorSize = g_device->GetDescriptorHandleIncrementSize(D3D12_DESCRIPTOR_HEAP_TYPE_RTV);
    DebugPrintA("[DX12] RTV descriptor size = %u\n", g_rtvDescriptorSize);

    CD3DX12_CPU_DESCRIPTOR_HANDLE rtvHandle(g_rtvHeap->GetCPUDescriptorHandleForHeapStart());

    for (UINT i = 0; i < g_frameCount; ++i)
    {
        if (FAILED(g_swapChain->GetBuffer(i, IID_PPV_ARGS(g_renderTargets[i].GetAddressOf()))))
            return E_FAIL;

        g_device->CreateRenderTargetView(g_renderTargets[i].Get(), nullptr, rtvHandle);
        DebugPrintA("[DX12] RTV created for back buffer %u\n", i);

        rtvHandle.Offset(1, g_rtvDescriptorSize);
    }

    return S_OK;
}

HRESULT InitTraffic()
{
    if (FAILED(g_device->CreateCommandAllocator(
        D3D12_COMMAND_LIST_TYPE_DIRECT,
        IID_PPV_ARGS(g_commandAllocator.GetAddressOf()))))
    {
        return E_FAIL;
    }

    CD3DX12_ROOT_SIGNATURE_DESC rsDesc;
    rsDesc.Init(0, nullptr, 0, nullptr, D3D12_ROOT_SIGNATURE_FLAG_NONE);

    ComPtr<ID3DBlob> signature;
    ComPtr<ID3DBlob> error;

    if (FAILED(D3D12SerializeRootSignature(
        &rsDesc,
        D3D_ROOT_SIGNATURE_VERSION_1,
        signature.GetAddressOf(),
        error.GetAddressOf())))
    {
        return E_FAIL;
    }

    if (FAILED(g_device->CreateRootSignature(
        0,
        signature->GetBufferPointer(),
        signature->GetBufferSize(),
        IID_PPV_ARGS(g_rootSignature.GetAddressOf()))))
    {
        return E_FAIL;
    }

    DebugPrintA("[DX12] Root signature created.\n");

    if (FAILED(g_device->CreateCommandList(
        0,
        D3D12_COMMAND_LIST_TYPE_DIRECT,
        g_commandAllocator.Get(),
        nullptr,
        IID_PPV_ARGS(g_commandList.GetAddressOf()))))
    {
        return E_FAIL;
    }

    if (FAILED(g_commandList->Close()))
        return E_FAIL;

    DebugPrintA("[DX12] Command list created and closed.\n");

    return S_OK;
}

HRESULT InitShader()
{
    ComPtr<IDxcBlob> meshShader;
    ComPtr<IDxcBlob> pixelShader;

    if (FAILED(CompileShader(L"hello.hlsl", L"MSMain", L"ms_6_5", meshShader)))
    {
        ShowErrorMessage(L"Failed to compile mesh shader.");
        return E_FAIL;
    }

    if (FAILED(CompileShader(L"hello.hlsl", L"PSMain", L"ps_6_0", pixelShader)))
    {
        ShowErrorMessage(L"Failed to compile pixel shader.");
        return E_FAIL;
    }

    D3D12_SHADER_BYTECODE msBytecode = {};
    msBytecode.pShaderBytecode = meshShader->GetBufferPointer();
    msBytecode.BytecodeLength  = meshShader->GetBufferSize();

    D3D12_SHADER_BYTECODE psBytecode = {};
    psBytecode.pShaderBytecode = pixelShader->GetBufferPointer();
    psBytecode.BytecodeLength  = pixelShader->GetBufferSize();

    D3D12_RT_FORMAT_ARRAY rtvFormats = {};
    rtvFormats.NumRenderTargets = 1;
    rtvFormats.RTFormats[0] = DXGI_FORMAT_R8G8B8A8_UNORM;

    PipelineStateStream psoStream = {};
    psoStream.RootSignature        = g_rootSignature.Get();
    psoStream.MS                   = msBytecode;
    psoStream.PS                   = psBytecode;
    psoStream.RasterizerState      = CD3DX12_RASTERIZER_DESC(D3D12_DEFAULT);
    psoStream.BlendState           = CD3DX12_BLEND_DESC(D3D12_DEFAULT);

    CD3DX12_DEPTH_STENCIL_DESC depthStencilDesc(D3D12_DEFAULT);
    depthStencilDesc.DepthEnable = FALSE;
    depthStencilDesc.StencilEnable = FALSE;
    psoStream.DepthStencilState = depthStencilDesc;

    psoStream.SampleMask            = UINT_MAX;
    psoStream.PrimitiveTopologyType = D3D12_PRIMITIVE_TOPOLOGY_TYPE_TRIANGLE;
    psoStream.RTVFormats            = rtvFormats;
    psoStream.SampleDesc            = DXGI_SAMPLE_DESC{ 1, 0 };

    D3D12_PIPELINE_STATE_STREAM_DESC streamDesc = {};
    streamDesc.pPipelineStateSubobjectStream = &psoStream;
    streamDesc.SizeInBytes = sizeof(psoStream);

    if (FAILED(g_device->CreatePipelineState(
        &streamDesc,
        IID_PPV_ARGS(g_pipelineState.GetAddressOf()))))
    {
        ShowErrorMessage(L"Failed to create mesh shader pipeline state.");
        return E_FAIL;
    }

    DebugPrintA("[DX12] Graphics PSO created successfully.\n");
    DebugPrintA("[DX12] PSO stages: MeshShader=enabled PixelShader=enabled\n");
    DebugPrintA("[DX12] Mesh shader bytecode size = %zu bytes\n", meshShader->GetBufferSize());
    DebugPrintA("[DX12] Pixel shader bytecode size = %zu bytes\n", pixelShader->GetBufferSize());

    return S_OK;
}

HRESULT InitFence()
{
    if (FAILED(g_device->CreateFence(0, D3D12_FENCE_FLAG_NONE, IID_PPV_ARGS(g_fence.GetAddressOf()))))
        return E_FAIL;

    g_fenceValue = 1;

    g_fenceEvent = CreateEvent(nullptr, FALSE, FALSE, nullptr);
    if (g_fenceEvent == nullptr)
        return E_FAIL;

    DebugPrintA("[DX12] Fence and event created.\n");

    WaitForPreviousFrame();
    return S_OK;
}

void OnRender()
{
    ++g_frameNumber;

    if (g_enableVerboseFrameLog)
    {
        DebugPrintA("\n[DX12] ===== Frame %llu begin =====\n",
            static_cast<unsigned long long>(g_frameNumber));
        DebugPrintA("[DX12] Current back buffer index = %u\n", g_frameIndex);
    }

    HRESULT hr = g_commandAllocator->Reset();
    if (FAILED(hr))
    {
        DebugPrintHr("CommandAllocator->Reset failed", hr);
        return;
    }
    if (g_enableVerboseFrameLog)
        DebugPrintA("[DX12] CommandAllocator reset.\n");

    hr = g_commandList->Reset(g_commandAllocator.Get(), g_pipelineState.Get());
    if (FAILED(hr))
    {
        DebugPrintHr("CommandList->Reset failed", hr);
        return;
    }
    if (g_enableVerboseFrameLog)
        DebugPrintA("[DX12] CommandList reset with mesh shader PSO.\n");

    g_commandList->SetGraphicsRootSignature(g_rootSignature.Get());
    if (g_enableVerboseFrameLog)
        DebugPrintA("[DX12] Root signature set.\n");

    g_commandList->RSSetViewports(1, &g_viewport);
    g_commandList->RSSetScissorRects(1, &g_scissorRect);
    if (g_enableVerboseFrameLog)
        DebugPrintA("[DX12] Viewport and scissor set.\n");

    if (g_enableVerboseFrameLog)
        DebugPrintA("[DX12] ResourceBarrier: PRESENT -> RENDER_TARGET\n");

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
        DebugPrintA("[DX12] Render target bound.\n");

    const FLOAT clearColor[] = { 1.0f, 1.0f, 1.0f, 1.0f };
    g_commandList->ClearRenderTargetView(rtvHandle, clearColor, 0, nullptr);
    if (g_enableVerboseFrameLog)
        DebugPrintA("[DX12] Render target cleared.\n");

    DebugPrintA("[DX12] DispatchMesh(1, 1, 1) called.\n");
    g_commandList->DispatchMesh(1, 1, 1);

    if (g_enableVerboseFrameLog)
        DebugPrintA("[DX12] ResourceBarrier: RENDER_TARGET -> PRESENT\n");

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
        DebugPrintA("[DX12] CommandList closed.\n");

    ID3D12CommandList* commandLists[] = { g_commandList.Get() };
    DebugPrintA("[DX12] ExecuteCommandLists called.\n");
    g_commandQueue->ExecuteCommandLists(_countof(commandLists), commandLists);

    hr = g_swapChain->Present(1, 0);
    if (FAILED(hr))
    {
        DebugPrintHr("SwapChain->Present failed", hr);
        return;
    }
    if (g_enableVerboseFrameLog)
        DebugPrintA("[DX12] Present succeeded.\n");

    WaitForPreviousFrame();

    if (g_enableVerboseFrameLog)
    {
        DebugPrintA("[DX12] ===== Frame %llu end =====\n",
            static_cast<unsigned long long>(g_frameNumber));
    }
}

void WaitForPreviousFrame()
{
    const UINT64 fence = g_fenceValue;

    DebugPrintA("[DX12] Signal fence value=%llu\n",
        static_cast<unsigned long long>(fence));

    g_commandQueue->Signal(g_fence.Get(), fence);
    g_fenceValue++;

    const UINT64 completedValue = g_fence->GetCompletedValue();
    DebugPrintA("[DX12] Fence completed value before wait=%llu\n",
        static_cast<unsigned long long>(completedValue));

    if (completedValue < fence)
    {
        DebugPrintA("[DX12] Waiting for fence completion...\n");
        g_fence->SetEventOnCompletion(fence, g_fenceEvent);
        WaitForSingleObject(g_fenceEvent, INFINITE);
        DebugPrintA("[DX12] Fence wait completed.\n");
    }

    g_frameIndex = g_swapChain->GetCurrentBackBufferIndex();
    DebugPrintA("[DX12] New back buffer index=%u\n", g_frameIndex);
}

void OnDestroy()
{
    DebugPrintA("[DX12] OnDestroy begin.\n");

    WaitForPreviousFrame();

    if (g_fenceEvent)
    {
        CloseHandle(g_fenceEvent);
        g_fenceEvent = nullptr;
    }

    DebugPrintA("[DX12] OnDestroy completed.\n");
}