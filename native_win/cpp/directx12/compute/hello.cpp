/*
 * DirectX 12 Compute Shader Harmonograph (C++ / Win32 / ComPtr + d3dx12.h)
 *
 * Build: cl hello.cpp /EHsc /link d3d12.lib dxgi.lib d3dcompiler.lib user32.lib
 */
#include <windows.h>
#include <tchar.h>
#include <wrl.h>

#include <d3d12.h>
#include <dxgi1_4.h>
#include <d3dcompiler.h>
#include <directxmath.h>
#include "d3dx12.h"

#include <cmath>
#include <cstdlib>
#include <ctime>
#include <cstdio>

#define WINDOW_WIDTH    640
#define WINDOW_HEIGHT   480
#define VERTEX_COUNT    500000
#define PI2             6.283185307179586f

using namespace DirectX;
using Microsoft::WRL::ComPtr;

/* Constant buffer for harmonograph parameters (must match HLSL cbuffer) */
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

/* Forward declarations */
LRESULT CALLBACK WindowProc(HWND hWnd, UINT nMsg, WPARAM wParam, LPARAM lParam);
HRESULT OnInit(HWND hWnd);
HRESULT InitDevice(HWND hWnd);
HRESULT InitView();
HRESULT InitBuffers();
HRESULT InitRootSignatures();
HRESULT InitShaders();
HRESULT InitCommandLists();
HRESULT InitFence();
void OnRender();
void WaitForPreviousFrame();
void OnDestroy();

/* Constants */
static const UINT g_frameCount = 2;

/* Device & swap chain */
ComPtr<ID3D12Device>              g_device;
ComPtr<IDXGISwapChain3>           g_swapChain;
ComPtr<ID3D12Resource>            g_renderTargets[g_frameCount];
ComPtr<ID3D12CommandQueue>        g_commandQueue;

/* Descriptor heaps */
ComPtr<ID3D12DescriptorHeap>      g_rtvHeap;
ComPtr<ID3D12DescriptorHeap>      g_srvUavHeap;
static UINT                       g_rtvDescriptorSize = 0;
static UINT                       g_srvUavDescriptorSize = 0;

/* Pipeline */
ComPtr<ID3D12RootSignature>       g_computeRootSignature;
ComPtr<ID3D12RootSignature>       g_graphicsRootSignature;
ComPtr<ID3D12PipelineState>       g_computePso;
ComPtr<ID3D12PipelineState>       g_graphicsPso;

/* Command infrastructure */
ComPtr<ID3D12CommandAllocator>    g_graphicsAllocator;
ComPtr<ID3D12CommandAllocator>    g_computeAllocator;
ComPtr<ID3D12GraphicsCommandList> g_commandList;
ComPtr<ID3D12GraphicsCommandList> g_computeCommandList;

/* Buffers */
ComPtr<ID3D12Resource>            g_positionBuffer;
ComPtr<ID3D12Resource>            g_colorBuffer;
ComPtr<ID3D12Resource>            g_constantBuffer;
HarmonographParams*               g_constantBufferData = nullptr;

/* Sync */
static UINT                       g_frameIndex = 0;
static HANDLE                     g_fenceEvent;
ComPtr<ID3D12Fence>               g_fence;
static UINT64                     g_fenceValue;

/* Viewport & scissor */
static CD3DX12_VIEWPORT g_viewport(0.0f, 0.0f,
    static_cast<FLOAT>(WINDOW_WIDTH), static_cast<FLOAT>(WINDOW_HEIGHT));
static CD3DX12_RECT g_scissorRect(0, 0,
    static_cast<LONG>(WINDOW_WIDTH), static_cast<LONG>(WINDOW_HEIGHT));

/* Harmonograph animation parameters */
float g_A1 = 50.0f, g_f1 = 2.0f, g_p1 = 1.0f / 16.0f, g_d1 = 0.02f;
float g_A2 = 50.0f, g_f2 = 2.0f, g_p2 = 3.0f / 2.0f,  g_d2 = 0.0315f;
float g_A3 = 50.0f, g_f3 = 2.0f, g_p3 = 13.0f / 15.0f, g_d3 = 0.02f;
float g_A4 = 50.0f, g_f4 = 2.0f, g_p4 = 1.0f,          g_d4 = 0.02f;

static float randf() { return static_cast<float>(rand()) / static_cast<float>(RAND_MAX); }

/* ================================================================ */

int APIENTRY _tWinMain(HINSTANCE hInstance, HINSTANCE, LPTSTR, int nCmdShow)
{
    srand(static_cast<unsigned int>(time(nullptr)));

    WNDCLASSEX windowClass = {};
    windowClass.cbSize        = sizeof(WNDCLASSEX);
    windowClass.style         = CS_HREDRAW | CS_VREDRAW;
    windowClass.lpfnWndProc   = WindowProc;
    windowClass.hInstance     = hInstance;
    windowClass.hCursor       = LoadCursor(NULL, IDC_ARROW);
    windowClass.lpszClassName = _T("DX12Harmonograph");
    RegisterClassEx(&windowClass);

    RECT windowRect = { 0, 0, WINDOW_WIDTH, WINDOW_HEIGHT };
    AdjustWindowRect(&windowRect, WS_OVERLAPPEDWINDOW, FALSE);

    HWND hWnd = CreateWindow(
        windowClass.lpszClassName,
        _T("DirectX 12 Compute Harmonograph (C++)"),
        WS_OVERLAPPEDWINDOW,
        CW_USEDEFAULT, CW_USEDEFAULT,
        windowRect.right - windowRect.left,
        windowRect.bottom - windowRect.top,
        nullptr, nullptr, hInstance, nullptr);

    MSG msg = {};
    if (SUCCEEDED(OnInit(hWnd)))
    {
        ShowWindow(hWnd, SW_SHOW);

        DWORD startTime   = GetTickCount();
        DWORD lastFpsTime = startTime;
        int   frameCount  = 0;

        while (msg.message != WM_QUIT)
        {
            if (PeekMessage(&msg, NULL, 0, 0, PM_REMOVE))
            {
                TranslateMessage(&msg);
                DispatchMessage(&msg);
            }
            else
            {
                DWORD currentTime = GetTickCount();
                if (currentTime - startTime > 60000) break;

                OnRender();

                frameCount++;
                if (currentTime - lastFpsTime >= 1000)
                {
                    float fps = static_cast<float>(frameCount) * 1000.0f
                              / static_cast<float>(currentTime - lastFpsTime);
                    frameCount  = 0;
                    lastFpsTime = currentTime;

                    char title[256];
                    sprintf(title, "DirectX 12 Compute Harmonograph (C++) - FPS: %.1f", fps);
                    SetWindowTextA(hWnd, title);
                }

                Sleep(1);
            }
        }
    }

    return static_cast<int>(msg.wParam);
}

LRESULT CALLBACK WindowProc(HWND hWnd, UINT nMsg, WPARAM wParam, LPARAM lParam)
{
    switch (nMsg)
    {
    case WM_KEYUP:
        if (wParam == VK_ESCAPE) { OnDestroy(); PostQuitMessage(0); return 0; }
        break;
    case WM_DESTROY:
        OnDestroy();
        PostQuitMessage(0);
        return 0;
    }
    return DefWindowProc(hWnd, nMsg, wParam, lParam);
}

HRESULT OnInit(HWND hWnd)
{
    if (FAILED(InitDevice(hWnd)))       return E_FAIL;
    if (FAILED(InitView()))             return E_FAIL;
    if (FAILED(InitBuffers()))          return E_FAIL;
    if (FAILED(InitRootSignatures()))   return E_FAIL;
    if (FAILED(InitShaders()))          return E_FAIL;
    if (FAILED(InitCommandLists()))     return E_FAIL;
    if (FAILED(InitFence()))            return E_FAIL;
    return S_OK;
}

/* ================================================================
 * Device, command queue, swap chain
 * ================================================================ */
HRESULT InitDevice(HWND hWnd)
{
    UINT dxgiFactoryFlags = 0;

    ComPtr<IDXGIFactory4> factory;
    if (FAILED(CreateDXGIFactory2(dxgiFactoryFlags, IID_PPV_ARGS(&factory))))
        return E_FAIL;

    /* Find hardware adapter */
    ComPtr<IDXGIAdapter1> hardwareAdapter;
    {
        ComPtr<IDXGIAdapter1> adapter;
        for (UINT i = 0; factory->EnumAdapters1(i, &adapter) != DXGI_ERROR_NOT_FOUND; ++i)
        {
            DXGI_ADAPTER_DESC1 desc;
            adapter->GetDesc1(&desc);
            if (desc.Flags & DXGI_ADAPTER_FLAG_SOFTWARE) continue;
            if (SUCCEEDED(D3D12CreateDevice(adapter.Get(), D3D_FEATURE_LEVEL_12_0,
                                            _uuidof(ID3D12Device), nullptr)))
            {
                hardwareAdapter = adapter;
                break;
            }
        }
    }

    if (FAILED(D3D12CreateDevice(hardwareAdapter.Get(), D3D_FEATURE_LEVEL_12_0,
                                 IID_PPV_ARGS(&g_device))))
    {
        /* Fall back to WARP */
        ComPtr<IDXGIAdapter> warpAdapter;
        factory->EnumWarpAdapter(IID_PPV_ARGS(&warpAdapter));
        if (FAILED(D3D12CreateDevice(warpAdapter.Get(), D3D_FEATURE_LEVEL_12_0,
                                     IID_PPV_ARGS(&g_device))))
            return E_FAIL;
    }

    /* Command queue (DIRECT - used for both compute and graphics) */
    D3D12_COMMAND_QUEUE_DESC queueDesc = {};
    queueDesc.Type = D3D12_COMMAND_LIST_TYPE_DIRECT;
    if (FAILED(g_device->CreateCommandQueue(&queueDesc, IID_PPV_ARGS(&g_commandQueue))))
        return E_FAIL;

    /* Swap chain */
    DXGI_SWAP_CHAIN_DESC1 scDesc = {};
    scDesc.BufferCount      = g_frameCount;
    scDesc.Width            = WINDOW_WIDTH;
    scDesc.Height           = WINDOW_HEIGHT;
    scDesc.Format           = DXGI_FORMAT_R8G8B8A8_UNORM;
    scDesc.BufferUsage      = DXGI_USAGE_RENDER_TARGET_OUTPUT;
    scDesc.SwapEffect       = DXGI_SWAP_EFFECT_FLIP_DISCARD;
    scDesc.SampleDesc.Count = 1;

    ComPtr<IDXGISwapChain1> swapChain1;
    if (FAILED(factory->CreateSwapChainForHwnd(
            g_commandQueue.Get(), hWnd, &scDesc, nullptr, nullptr, &swapChain1)))
        return E_FAIL;

    factory->MakeWindowAssociation(hWnd, DXGI_MWA_NO_ALT_ENTER);
    swapChain1.As(&g_swapChain);
    g_frameIndex = g_swapChain->GetCurrentBackBufferIndex();

    return S_OK;
}

/* ================================================================
 * RTV heap + SRV/UAV/CBV heap + render target views
 * ================================================================ */
HRESULT InitView()
{
    /* RTV heap */
    {
        D3D12_DESCRIPTOR_HEAP_DESC desc = {};
        desc.NumDescriptors = g_frameCount;
        desc.Type           = D3D12_DESCRIPTOR_HEAP_TYPE_RTV;
        if (FAILED(g_device->CreateDescriptorHeap(&desc, IID_PPV_ARGS(&g_rtvHeap))))
            return E_FAIL;
        g_rtvDescriptorSize = g_device->GetDescriptorHandleIncrementSize(
            D3D12_DESCRIPTOR_HEAP_TYPE_RTV);
    }

    /* SRV/UAV/CBV heap (shader-visible): slot 0,1 = UAV; slot 2 = CBV */
    {
        D3D12_DESCRIPTOR_HEAP_DESC desc = {};
        desc.NumDescriptors = 3;
        desc.Type           = D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV;
        desc.Flags          = D3D12_DESCRIPTOR_HEAP_FLAG_SHADER_VISIBLE;
        if (FAILED(g_device->CreateDescriptorHeap(&desc, IID_PPV_ARGS(&g_srvUavHeap))))
            return E_FAIL;
        g_srvUavDescriptorSize = g_device->GetDescriptorHandleIncrementSize(
            D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV);
    }

    /* Create RTVs */
    {
        CD3DX12_CPU_DESCRIPTOR_HANDLE rtvHandle(g_rtvHeap->GetCPUDescriptorHandleForHeapStart());
        for (UINT i = 0; i < g_frameCount; ++i)
        {
            if (FAILED(g_swapChain->GetBuffer(i, IID_PPV_ARGS(&g_renderTargets[i]))))
                return E_FAIL;
            g_device->CreateRenderTargetView(g_renderTargets[i].Get(), nullptr, rtvHandle);
            rtvHandle.Offset(1, g_rtvDescriptorSize);
        }
    }

    return S_OK;
}

/* ================================================================
 * Position / Color (UAV) + Constant buffer
 * ================================================================ */
HRESULT InitBuffers()
{
    const UINT bufferSize = VERTEX_COUNT * 16;  /* float4 = 16 bytes per vertex */

    /* Position buffer (DEFAULT heap, UAV) */
    if (FAILED(g_device->CreateCommittedResource(
            &CD3DX12_HEAP_PROPERTIES(D3D12_HEAP_TYPE_DEFAULT),
            D3D12_HEAP_FLAG_NONE,
            &CD3DX12_RESOURCE_DESC::Buffer(bufferSize,
                D3D12_RESOURCE_FLAG_ALLOW_UNORDERED_ACCESS),
            D3D12_RESOURCE_STATE_UNORDERED_ACCESS, nullptr,
            IID_PPV_ARGS(&g_positionBuffer))))
        return E_FAIL;

    /* Color buffer (DEFAULT heap, UAV) */
    if (FAILED(g_device->CreateCommittedResource(
            &CD3DX12_HEAP_PROPERTIES(D3D12_HEAP_TYPE_DEFAULT),
            D3D12_HEAP_FLAG_NONE,
            &CD3DX12_RESOURCE_DESC::Buffer(bufferSize,
                D3D12_RESOURCE_FLAG_ALLOW_UNORDERED_ACCESS),
            D3D12_RESOURCE_STATE_UNORDERED_ACCESS, nullptr,
            IID_PPV_ARGS(&g_colorBuffer))))
        return E_FAIL;

    /* Constant buffer (UPLOAD heap, persistently mapped) */
    if (FAILED(g_device->CreateCommittedResource(
            &CD3DX12_HEAP_PROPERTIES(D3D12_HEAP_TYPE_UPLOAD),
            D3D12_HEAP_FLAG_NONE,
            &CD3DX12_RESOURCE_DESC::Buffer(256),
            D3D12_RESOURCE_STATE_GENERIC_READ, nullptr,
            IID_PPV_ARGS(&g_constantBuffer))))
        return E_FAIL;

    g_constantBuffer->Map(0, nullptr,
        reinterpret_cast<void**>(&g_constantBufferData));

    /* Create UAVs (slot 0 = position, slot 1 = color) */
    {
        CD3DX12_CPU_DESCRIPTOR_HANDLE handle(
            g_srvUavHeap->GetCPUDescriptorHandleForHeapStart());

        D3D12_UNORDERED_ACCESS_VIEW_DESC uavDesc = {};
        uavDesc.Format                      = DXGI_FORMAT_UNKNOWN;
        uavDesc.ViewDimension               = D3D12_UAV_DIMENSION_BUFFER;
        uavDesc.Buffer.NumElements          = VERTEX_COUNT;
        uavDesc.Buffer.StructureByteStride  = 16;

        g_device->CreateUnorderedAccessView(
            g_positionBuffer.Get(), nullptr, &uavDesc, handle);
        handle.Offset(1, g_srvUavDescriptorSize);

        g_device->CreateUnorderedAccessView(
            g_colorBuffer.Get(), nullptr, &uavDesc, handle);
        handle.Offset(1, g_srvUavDescriptorSize);

        /* CBV (slot 2) */
        D3D12_CONSTANT_BUFFER_VIEW_DESC cbvDesc = {};
        cbvDesc.BufferLocation = g_constantBuffer->GetGPUVirtualAddress();
        cbvDesc.SizeInBytes    = 256;
        g_device->CreateConstantBufferView(&cbvDesc, handle);
    }

    return S_OK;
}

/* ================================================================
 * Root signatures (compute + graphics)
 * ================================================================ */
HRESULT InitRootSignatures()
{
    ComPtr<ID3DBlob> signature, error;

    /* Compute: param0 = UAV table (u0, u1), param1 = CBV table (b0) */
    {
        CD3DX12_DESCRIPTOR_RANGE1 ranges[2];
        ranges[0].Init(D3D12_DESCRIPTOR_RANGE_TYPE_UAV, 2, 0);
        ranges[1].Init(D3D12_DESCRIPTOR_RANGE_TYPE_CBV, 1, 0);

        CD3DX12_ROOT_PARAMETER1 rootParams[2];
        rootParams[0].InitAsDescriptorTable(1, &ranges[0], D3D12_SHADER_VISIBILITY_ALL);
        rootParams[1].InitAsDescriptorTable(1, &ranges[1], D3D12_SHADER_VISIBILITY_ALL);

        CD3DX12_VERSIONED_ROOT_SIGNATURE_DESC rsDesc;
        rsDesc.Init_1_1(_countof(rootParams), rootParams, 0, nullptr,
                        D3D12_ROOT_SIGNATURE_FLAG_NONE);

        if (FAILED(D3DX12SerializeVersionedRootSignature(
                &rsDesc, D3D_ROOT_SIGNATURE_VERSION_1_1, &signature, &error)))
        {
            /* Fall back to version 1.0 */
            CD3DX12_DESCRIPTOR_RANGE ranges0[2];
            ranges0[0].Init(D3D12_DESCRIPTOR_RANGE_TYPE_UAV, 2, 0);
            ranges0[1].Init(D3D12_DESCRIPTOR_RANGE_TYPE_CBV, 1, 0);

            CD3DX12_ROOT_PARAMETER rootParams0[2];
            rootParams0[0].InitAsDescriptorTable(1, &ranges0[0], D3D12_SHADER_VISIBILITY_ALL);
            rootParams0[1].InitAsDescriptorTable(1, &ranges0[1], D3D12_SHADER_VISIBILITY_ALL);

            CD3DX12_ROOT_SIGNATURE_DESC rsDesc0;
            rsDesc0.Init(_countof(rootParams0), rootParams0, 0, nullptr,
                         D3D12_ROOT_SIGNATURE_FLAG_NONE);

            if (FAILED(D3D12SerializeRootSignature(
                    &rsDesc0, D3D_ROOT_SIGNATURE_VERSION_1, &signature, &error)))
                return E_FAIL;
        }

        if (FAILED(g_device->CreateRootSignature(0,
                signature->GetBufferPointer(), signature->GetBufferSize(),
                IID_PPV_ARGS(&g_computeRootSignature))))
            return E_FAIL;
    }

    /* Graphics: param0 = SRV table (t0, t1), param1 = CBV table (b0) */
    {
        signature.Reset();
        error.Reset();

        CD3DX12_DESCRIPTOR_RANGE1 ranges[2];
        ranges[0].Init(D3D12_DESCRIPTOR_RANGE_TYPE_SRV, 2, 0);
        ranges[1].Init(D3D12_DESCRIPTOR_RANGE_TYPE_CBV, 1, 0);

        CD3DX12_ROOT_PARAMETER1 rootParams[2];
        rootParams[0].InitAsDescriptorTable(1, &ranges[0], D3D12_SHADER_VISIBILITY_VERTEX);
        rootParams[1].InitAsDescriptorTable(1, &ranges[1], D3D12_SHADER_VISIBILITY_VERTEX);

        CD3DX12_VERSIONED_ROOT_SIGNATURE_DESC rsDesc;
        rsDesc.Init_1_1(_countof(rootParams), rootParams, 0, nullptr,
                        D3D12_ROOT_SIGNATURE_FLAG_NONE);

        if (FAILED(D3DX12SerializeVersionedRootSignature(
                &rsDesc, D3D_ROOT_SIGNATURE_VERSION_1_1, &signature, &error)))
        {
            CD3DX12_DESCRIPTOR_RANGE ranges0[2];
            ranges0[0].Init(D3D12_DESCRIPTOR_RANGE_TYPE_SRV, 2, 0);
            ranges0[1].Init(D3D12_DESCRIPTOR_RANGE_TYPE_CBV, 1, 0);

            CD3DX12_ROOT_PARAMETER rootParams0[2];
            rootParams0[0].InitAsDescriptorTable(1, &ranges0[0], D3D12_SHADER_VISIBILITY_VERTEX);
            rootParams0[1].InitAsDescriptorTable(1, &ranges0[1], D3D12_SHADER_VISIBILITY_VERTEX);

            CD3DX12_ROOT_SIGNATURE_DESC rsDesc0;
            rsDesc0.Init(_countof(rootParams0), rootParams0, 0, nullptr,
                         D3D12_ROOT_SIGNATURE_FLAG_NONE);

            if (FAILED(D3D12SerializeRootSignature(
                    &rsDesc0, D3D_ROOT_SIGNATURE_VERSION_1, &signature, &error)))
                return E_FAIL;
        }

        if (FAILED(g_device->CreateRootSignature(0,
                signature->GetBufferPointer(), signature->GetBufferSize(),
                IID_PPV_ARGS(&g_graphicsRootSignature))))
            return E_FAIL;
    }

    return S_OK;
}

/* ================================================================
 * Shader compilation + PSO creation
 * ================================================================ */
HRESULT InitShaders()
{
    ComPtr<ID3DBlob> computeShader, vertexShader, pixelShader, error;
    UINT compileFlags = 0;

    if (FAILED(D3DCompileFromFile(L"hello.hlsl", nullptr, nullptr,
            "CSMain", "cs_5_0", compileFlags, 0, &computeShader, &error)))
    {
        if (error) OutputDebugStringA(static_cast<char*>(error->GetBufferPointer()));
        return E_FAIL;
    }
    if (FAILED(D3DCompileFromFile(L"hello.hlsl", nullptr, nullptr,
            "VSMain", "vs_5_0", compileFlags, 0, &vertexShader, &error)))
    {
        if (error) OutputDebugStringA(static_cast<char*>(error->GetBufferPointer()));
        return E_FAIL;
    }
    if (FAILED(D3DCompileFromFile(L"hello.hlsl", nullptr, nullptr,
            "PSMain", "ps_5_0", compileFlags, 0, &pixelShader, &error)))
    {
        if (error) OutputDebugStringA(static_cast<char*>(error->GetBufferPointer()));
        return E_FAIL;
    }

    /* Compute PSO */
    {
        D3D12_COMPUTE_PIPELINE_STATE_DESC desc = {};
        desc.pRootSignature = g_computeRootSignature.Get();
        desc.CS = CD3DX12_SHADER_BYTECODE(computeShader.Get());
        if (FAILED(g_device->CreateComputePipelineState(&desc, IID_PPV_ARGS(&g_computePso))))
            return E_FAIL;
    }

    /* Graphics PSO (LINE topology, no input layout - uses SV_VertexID) */
    {
        D3D12_GRAPHICS_PIPELINE_STATE_DESC desc = {};
        desc.pRootSignature     = g_graphicsRootSignature.Get();
        desc.VS                 = CD3DX12_SHADER_BYTECODE(vertexShader.Get());
        desc.PS                 = CD3DX12_SHADER_BYTECODE(pixelShader.Get());
        desc.RasterizerState    = CD3DX12_RASTERIZER_DESC(D3D12_DEFAULT);
        desc.RasterizerState.CullMode = D3D12_CULL_MODE_NONE;
        desc.BlendState         = CD3DX12_BLEND_DESC(D3D12_DEFAULT);
        desc.DepthStencilState.DepthEnable   = FALSE;
        desc.DepthStencilState.StencilEnable = FALSE;
        desc.SampleMask              = UINT_MAX;
        desc.PrimitiveTopologyType   = D3D12_PRIMITIVE_TOPOLOGY_TYPE_LINE;
        desc.NumRenderTargets        = 1;
        desc.RTVFormats[0]           = DXGI_FORMAT_R8G8B8A8_UNORM;
        desc.SampleDesc.Count        = 1;

        if (FAILED(g_device->CreateGraphicsPipelineState(&desc, IID_PPV_ARGS(&g_graphicsPso))))
            return E_FAIL;
    }

    return S_OK;
}

/* ================================================================
 * Command allocators & command lists
 * ================================================================ */
HRESULT InitCommandLists()
{
    if (FAILED(g_device->CreateCommandAllocator(
            D3D12_COMMAND_LIST_TYPE_DIRECT, IID_PPV_ARGS(&g_graphicsAllocator))))
        return E_FAIL;

    if (FAILED(g_device->CreateCommandAllocator(
            D3D12_COMMAND_LIST_TYPE_DIRECT, IID_PPV_ARGS(&g_computeAllocator))))
        return E_FAIL;

    if (FAILED(g_device->CreateCommandList(0, D3D12_COMMAND_LIST_TYPE_DIRECT,
            g_graphicsAllocator.Get(), g_graphicsPso.Get(),
            IID_PPV_ARGS(&g_commandList))))
        return E_FAIL;
    g_commandList->Close();

    if (FAILED(g_device->CreateCommandList(0, D3D12_COMMAND_LIST_TYPE_DIRECT,
            g_computeAllocator.Get(), g_computePso.Get(),
            IID_PPV_ARGS(&g_computeCommandList))))
        return E_FAIL;
    g_computeCommandList->Close();

    return S_OK;
}

/* ================================================================
 * Fence
 * ================================================================ */
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

/* ================================================================
 * Render
 * ================================================================ */
void OnRender()
{
    /* Animate parameters */
    g_f1 = fmodf(g_f1 + randf() / 40.0f, 10.0f);
    g_f2 = fmodf(g_f2 + randf() / 40.0f, 10.0f);
    g_f3 = fmodf(g_f3 + randf() / 40.0f, 10.0f);
    g_f4 = fmodf(g_f4 + randf() / 40.0f, 10.0f);
    g_p1 += PI2 * 0.5f / 360.0f;

    /* Update constant buffer */
    g_constantBufferData->A1 = g_A1; g_constantBufferData->f1 = g_f1;
    g_constantBufferData->p1 = g_p1; g_constantBufferData->d1 = g_d1;
    g_constantBufferData->A2 = g_A2; g_constantBufferData->f2 = g_f2;
    g_constantBufferData->p2 = g_p2; g_constantBufferData->d2 = g_d2;
    g_constantBufferData->A3 = g_A3; g_constantBufferData->f3 = g_f3;
    g_constantBufferData->p3 = g_p3; g_constantBufferData->d3 = g_d3;
    g_constantBufferData->A4 = g_A4; g_constantBufferData->f4 = g_f4;
    g_constantBufferData->p4 = g_p4; g_constantBufferData->d4 = g_d4;
    g_constantBufferData->max_num       = VERTEX_COUNT;
    g_constantBufferData->resolution[0] = static_cast<float>(WINDOW_WIDTH);
    g_constantBufferData->resolution[1] = static_cast<float>(WINDOW_HEIGHT);

    /* ==================== Compute Pass ==================== */
    g_computeAllocator->Reset();
    g_computeCommandList->Reset(g_computeAllocator.Get(), g_computePso.Get());

    ID3D12DescriptorHeap* heaps[] = { g_srvUavHeap.Get() };
    g_computeCommandList->SetDescriptorHeaps(_countof(heaps), heaps);
    g_computeCommandList->SetComputeRootSignature(g_computeRootSignature.Get());

    CD3DX12_GPU_DESCRIPTOR_HANDLE gpuHandle(
        g_srvUavHeap->GetGPUDescriptorHandleForHeapStart());

    /* Root param 0: UAV table (slot 0, 1) */
    g_computeCommandList->SetComputeRootDescriptorTable(0, gpuHandle);
    /* Root param 1: CBV table (slot 2) */
    gpuHandle.Offset(2, g_srvUavDescriptorSize);
    g_computeCommandList->SetComputeRootDescriptorTable(1, gpuHandle);

    g_computeCommandList->Dispatch((VERTEX_COUNT + 63) / 64, 1, 1);

    /* UAV barrier (ensure compute writes complete) */
    {
        D3D12_RESOURCE_BARRIER uavBarrier = {};
        uavBarrier.Type = D3D12_RESOURCE_BARRIER_TYPE_UAV;
        uavBarrier.UAV.pResource = g_positionBuffer.Get();
        g_computeCommandList->ResourceBarrier(1, &uavBarrier);
        uavBarrier.UAV.pResource = g_colorBuffer.Get();
        g_computeCommandList->ResourceBarrier(1, &uavBarrier);
    }

    g_computeCommandList->Close();

    ID3D12CommandList* computeLists[] = {
        static_cast<ID3D12CommandList*>(g_computeCommandList.Get()) };
    g_commandQueue->ExecuteCommandLists(_countof(computeLists), computeLists);
    WaitForPreviousFrame();

    /* ==================== Graphics Pass ==================== */
    g_graphicsAllocator->Reset();
    g_commandList->Reset(g_graphicsAllocator.Get(), g_graphicsPso.Get());

    g_commandList->SetDescriptorHeaps(_countof(heaps), heaps);
    g_commandList->SetGraphicsRootSignature(g_graphicsRootSignature.Get());

    gpuHandle = CD3DX12_GPU_DESCRIPTOR_HANDLE(
        g_srvUavHeap->GetGPUDescriptorHandleForHeapStart());
    /* Root param 0: same UAV table (used as SRV via StructuredBuffer in VS) */
    g_commandList->SetGraphicsRootDescriptorTable(0, gpuHandle);
    gpuHandle.Offset(2, g_srvUavDescriptorSize);
    g_commandList->SetGraphicsRootDescriptorTable(1, gpuHandle);

    g_commandList->RSSetViewports(1, &g_viewport);
    g_commandList->RSSetScissorRects(1, &g_scissorRect);

    /* Barrier: PRESENT -> RENDER_TARGET */
    g_commandList->ResourceBarrier(1,
        &CD3DX12_RESOURCE_BARRIER::Transition(
            g_renderTargets[g_frameIndex].Get(),
            D3D12_RESOURCE_STATE_PRESENT,
            D3D12_RESOURCE_STATE_RENDER_TARGET));

    CD3DX12_CPU_DESCRIPTOR_HANDLE rtvHandle(
        g_rtvHeap->GetCPUDescriptorHandleForHeapStart(),
        g_frameIndex, g_rtvDescriptorSize);

    const FLOAT clearColor[] = { 0.0f, 0.0f, 0.0f, 1.0f };
    g_commandList->ClearRenderTargetView(rtvHandle, clearColor, 0, nullptr);
    g_commandList->OMSetRenderTargets(1, &rtvHandle, FALSE, nullptr);

    g_commandList->IASetPrimitiveTopology(D3D_PRIMITIVE_TOPOLOGY_LINESTRIP);
    g_commandList->DrawInstanced(VERTEX_COUNT, 1, 0, 0);

    /* Barrier: RENDER_TARGET -> PRESENT */
    g_commandList->ResourceBarrier(1,
        &CD3DX12_RESOURCE_BARRIER::Transition(
            g_renderTargets[g_frameIndex].Get(),
            D3D12_RESOURCE_STATE_RENDER_TARGET,
            D3D12_RESOURCE_STATE_PRESENT));

    g_commandList->Close();

    ID3D12CommandList* graphicsLists[] = {
        static_cast<ID3D12CommandList*>(g_commandList.Get()) };
    g_commandQueue->ExecuteCommandLists(_countof(graphicsLists), graphicsLists);

    g_swapChain->Present(0, 0);
    WaitForPreviousFrame();
}

void WaitForPreviousFrame()
{
    const UINT64 fence = g_fenceValue;
    g_commandQueue->Signal(g_fence.Get(), fence);
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

    if (g_constantBuffer)
        g_constantBuffer->Unmap(0, nullptr);

    if (g_fenceEvent)
        CloseHandle(g_fenceEvent);
}
