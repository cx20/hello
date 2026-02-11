// Raymarching - DirectX 12 / C++
// forked from https://www.shadertoy.com/view/wtB3RG

#include <windows.h>
#include <tchar.h>
#include <wrl.h>

#include <d3d12.h>
#include <dxgi1_4.h>
#include <d3dcompiler.h>
#include <directxmath.h>
#include "d3dx12.h"

#include <cstdio>

#pragma comment(lib, "d3d12.lib")
#pragma comment(lib, "dxgi.lib")
#pragma comment(lib, "d3dcompiler.lib")

#define WINDOW_WIDTH  800
#define WINDOW_HEIGHT 600

using Microsoft::WRL::ComPtr;

/* Vertex structure for fullscreen quad (position only) */
struct Vertex
{
    float position[2];
};

/* Constant buffer (must match HLSL cbuffer layout) */
struct ConstantBuffer
{
    float iTime;
    float iResolutionX;
    float iResolutionY;
    float padding;
};

/* Forward declarations */
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

/* Constants */
static const UINT g_frameCount = 2;

/* Device & swap chain */
ComPtr<ID3D12Device>              g_device;
ComPtr<IDXGISwapChain3>           g_swapChain;
ComPtr<ID3D12Resource>            g_renderTargets[g_frameCount];
ComPtr<ID3D12CommandQueue>        g_commandQueue;

/* Descriptor heaps */
ComPtr<ID3D12DescriptorHeap>      g_rtvHeap;
ComPtr<ID3D12DescriptorHeap>      g_cbvHeap;
static UINT                       g_rtvDescriptorSize = 0;

/* Pipeline */
ComPtr<ID3D12RootSignature>       g_rootSignature;
ComPtr<ID3D12PipelineState>       g_pipelineState;

/* Command infrastructure */
ComPtr<ID3D12CommandAllocator>    g_commandAllocator;
ComPtr<ID3D12GraphicsCommandList> g_commandList;

/* Buffers */
ComPtr<ID3D12Resource>            g_vertexBuffer;
ComPtr<ID3D12Resource>            g_constantBuffer;
static D3D12_VERTEX_BUFFER_VIEW   g_vertexBufferView;
static UINT8*                     g_constantBufferDataBegin = nullptr;

/* Sync */
static UINT                       g_frameIndex = 0;
static HANDLE                     g_fenceEvent = nullptr;
ComPtr<ID3D12Fence>               g_fence;
static UINT64                     g_fenceValue = 0;

/* Viewport & scissor */
static CD3DX12_VIEWPORT g_viewport(0.0f, 0.0f,
    static_cast<FLOAT>(WINDOW_WIDTH), static_cast<FLOAT>(WINDOW_HEIGHT));
static CD3DX12_RECT g_scissorRect(0, 0,
    static_cast<LONG>(WINDOW_WIDTH), static_cast<LONG>(WINDOW_HEIGHT));

/* Timer */
static LARGE_INTEGER g_startTime;
static LARGE_INTEGER g_frequency;

/* ================================================================ */

int APIENTRY _tWinMain(HINSTANCE hInstance, HINSTANCE, LPTSTR, int nCmdShow)
{
    WNDCLASSEX windowClass = {};
    windowClass.cbSize        = sizeof(WNDCLASSEX);
    windowClass.style         = CS_HREDRAW | CS_VREDRAW;
    windowClass.lpfnWndProc   = WindowProc;
    windowClass.hInstance     = hInstance;
    windowClass.hCursor       = LoadCursor(NULL, IDC_ARROW);
    windowClass.lpszClassName = _T("DX12Raymarching");
    RegisterClassEx(&windowClass);

    RECT windowRect = { 0, 0, WINDOW_WIDTH, WINDOW_HEIGHT };
    AdjustWindowRect(&windowRect, WS_OVERLAPPEDWINDOW, FALSE);

    HWND hWnd = CreateWindow(
        windowClass.lpszClassName,
        _T("Raymarching - DirectX 12 / C++"),
        WS_OVERLAPPEDWINDOW,
        CW_USEDEFAULT, CW_USEDEFAULT,
        windowRect.right - windowRect.left,
        windowRect.bottom - windowRect.top,
        nullptr, nullptr, hInstance, nullptr);

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
    QueryPerformanceFrequency(&g_frequency);
    QueryPerformanceCounter(&g_startTime);

    if (FAILED(InitDevice(hWnd))) return E_FAIL;
    if (FAILED(InitView()))       return E_FAIL;
    if (FAILED(InitTraffic()))    return E_FAIL;
    if (FAILED(InitShader()))     return E_FAIL;
    if (FAILED(InitBuffer()))     return E_FAIL;
    if (FAILED(InitFence()))      return E_FAIL;
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
        ComPtr<IDXGIAdapter> warpAdapter;
        factory->EnumWarpAdapter(IID_PPV_ARGS(&warpAdapter));
        if (FAILED(D3D12CreateDevice(warpAdapter.Get(), D3D_FEATURE_LEVEL_12_0,
                                     IID_PPV_ARGS(&g_device))))
            return E_FAIL;
    }

    /* Command queue */
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
 * Descriptor heaps + render target views
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

    /* CBV heap (shader-visible, 1 descriptor for constant buffer) */
    {
        D3D12_DESCRIPTOR_HEAP_DESC desc = {};
        desc.NumDescriptors = 1;
        desc.Type           = D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV;
        desc.Flags          = D3D12_DESCRIPTOR_HEAP_FLAG_SHADER_VISIBLE;
        if (FAILED(g_device->CreateDescriptorHeap(&desc, IID_PPV_ARGS(&g_cbvHeap))))
            return E_FAIL;
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
 * Command allocator + root signature
 * ================================================================ */
HRESULT InitTraffic()
{
    if (FAILED(g_device->CreateCommandAllocator(
            D3D12_COMMAND_LIST_TYPE_DIRECT, IID_PPV_ARGS(&g_commandAllocator))))
        return E_FAIL;

    /* Root signature: 1 descriptor table with CBV (b0) */
    {
        CD3DX12_DESCRIPTOR_RANGE1 range;
        range.Init(D3D12_DESCRIPTOR_RANGE_TYPE_CBV, 1, 0);

        CD3DX12_ROOT_PARAMETER1 rootParam;
        rootParam.InitAsDescriptorTable(1, &range, D3D12_SHADER_VISIBILITY_ALL);

        CD3DX12_VERSIONED_ROOT_SIGNATURE_DESC rsDesc;
        rsDesc.Init_1_1(1, &rootParam, 0, nullptr,
                        D3D12_ROOT_SIGNATURE_FLAG_ALLOW_INPUT_ASSEMBLER_INPUT_LAYOUT);

        ComPtr<ID3DBlob> signature, error;
        if (FAILED(D3DX12SerializeVersionedRootSignature(
                &rsDesc, D3D_ROOT_SIGNATURE_VERSION_1_1, &signature, &error)))
        {
            /* Fall back to 1.0 */
            CD3DX12_DESCRIPTOR_RANGE range0;
            range0.Init(D3D12_DESCRIPTOR_RANGE_TYPE_CBV, 1, 0);

            CD3DX12_ROOT_PARAMETER rootParam0;
            rootParam0.InitAsDescriptorTable(1, &range0, D3D12_SHADER_VISIBILITY_ALL);

            CD3DX12_ROOT_SIGNATURE_DESC rsDesc0;
            rsDesc0.Init(1, &rootParam0, 0, nullptr,
                         D3D12_ROOT_SIGNATURE_FLAG_ALLOW_INPUT_ASSEMBLER_INPUT_LAYOUT);

            if (FAILED(D3D12SerializeRootSignature(
                    &rsDesc0, D3D_ROOT_SIGNATURE_VERSION_1, &signature, &error)))
                return E_FAIL;
        }

        if (FAILED(g_device->CreateRootSignature(0,
                signature->GetBufferPointer(), signature->GetBufferSize(),
                IID_PPV_ARGS(&g_rootSignature))))
            return E_FAIL;
    }

    return S_OK;
}

/* ================================================================
 * Shader compilation + PSO
 * ================================================================ */
HRESULT InitShader()
{
    ComPtr<ID3DBlob> vertexShader, pixelShader, error;
    UINT compileFlags = 0;

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

    /* Input layout: float2 POSITION */
    D3D12_INPUT_ELEMENT_DESC inputLayout[] =
    {
        { "POSITION", 0, DXGI_FORMAT_R32G32_FLOAT, 0, 0,
          D3D12_INPUT_CLASSIFICATION_PER_VERTEX_DATA, 0 },
    };

    /* Graphics PSO */
    D3D12_GRAPHICS_PIPELINE_STATE_DESC psoDesc = {};
    psoDesc.InputLayout         = { inputLayout, _countof(inputLayout) };
    psoDesc.pRootSignature      = g_rootSignature.Get();
    psoDesc.VS                  = CD3DX12_SHADER_BYTECODE(vertexShader.Get());
    psoDesc.PS                  = CD3DX12_SHADER_BYTECODE(pixelShader.Get());
    psoDesc.RasterizerState     = CD3DX12_RASTERIZER_DESC(D3D12_DEFAULT);
    psoDesc.RasterizerState.CullMode = D3D12_CULL_MODE_NONE;
    psoDesc.BlendState          = CD3DX12_BLEND_DESC(D3D12_DEFAULT);
    psoDesc.DepthStencilState.DepthEnable   = FALSE;
    psoDesc.DepthStencilState.StencilEnable = FALSE;
    psoDesc.SampleMask            = UINT_MAX;
    psoDesc.PrimitiveTopologyType = D3D12_PRIMITIVE_TOPOLOGY_TYPE_TRIANGLE;
    psoDesc.NumRenderTargets      = 1;
    psoDesc.RTVFormats[0]         = DXGI_FORMAT_R8G8B8A8_UNORM;
    psoDesc.SampleDesc.Count      = 1;

    if (FAILED(g_device->CreateGraphicsPipelineState(&psoDesc, IID_PPV_ARGS(&g_pipelineState))))
        return E_FAIL;

    return S_OK;
}

/* ================================================================
 * Vertex buffer + constant buffer
 * ================================================================ */
HRESULT InitBuffer()
{
    if (FAILED(g_device->CreateCommandList(0, D3D12_COMMAND_LIST_TYPE_DIRECT,
            g_commandAllocator.Get(), nullptr, IID_PPV_ARGS(&g_commandList))))
        return E_FAIL;
    g_commandList->Close();

    /* Fullscreen quad (2 triangles, 6 vertices) */
    Vertex vertices[] =
    {
        { {-1.0f,  1.0f} },   // Top-left
        { { 1.0f,  1.0f} },   // Top-right
        { {-1.0f, -1.0f} },   // Bottom-left
        { { 1.0f,  1.0f} },   // Top-right
        { { 1.0f, -1.0f} },   // Bottom-right
        { {-1.0f, -1.0f} },   // Bottom-left
    };
    const UINT vertexBufferSize = sizeof(vertices);

    /* Vertex buffer (UPLOAD heap) */
    if (FAILED(g_device->CreateCommittedResource(
            &CD3DX12_HEAP_PROPERTIES(D3D12_HEAP_TYPE_UPLOAD),
            D3D12_HEAP_FLAG_NONE,
            &CD3DX12_RESOURCE_DESC::Buffer(vertexBufferSize),
            D3D12_RESOURCE_STATE_GENERIC_READ, nullptr,
            IID_PPV_ARGS(&g_vertexBuffer))))
        return E_FAIL;

    {
        UINT8* pData;
        CD3DX12_RANGE readRange(0, 0);
        g_vertexBuffer->Map(0, &readRange, reinterpret_cast<void**>(&pData));
        memcpy(pData, vertices, vertexBufferSize);
        g_vertexBuffer->Unmap(0, nullptr);
    }

    g_vertexBufferView.BufferLocation = g_vertexBuffer->GetGPUVirtualAddress();
    g_vertexBufferView.SizeInBytes    = vertexBufferSize;
    g_vertexBufferView.StrideInBytes  = sizeof(Vertex);

    /* Constant buffer (UPLOAD heap, 256-byte aligned, persistently mapped) */
    if (FAILED(g_device->CreateCommittedResource(
            &CD3DX12_HEAP_PROPERTIES(D3D12_HEAP_TYPE_UPLOAD),
            D3D12_HEAP_FLAG_NONE,
            &CD3DX12_RESOURCE_DESC::Buffer(256),
            D3D12_RESOURCE_STATE_GENERIC_READ, nullptr,
            IID_PPV_ARGS(&g_constantBuffer))))
        return E_FAIL;

    g_constantBuffer->Map(0, nullptr,
        reinterpret_cast<void**>(&g_constantBufferDataBegin));

    /* Create CBV */
    {
        D3D12_CONSTANT_BUFFER_VIEW_DESC cbvDesc = {};
        cbvDesc.BufferLocation = g_constantBuffer->GetGPUVirtualAddress();
        cbvDesc.SizeInBytes    = 256;
        g_device->CreateConstantBufferView(&cbvDesc,
            g_cbvHeap->GetCPUDescriptorHandleForHeapStart());
    }

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
    /* Update constant buffer with elapsed time */
    LARGE_INTEGER currentTime;
    QueryPerformanceCounter(&currentTime);
    float time = static_cast<float>(currentTime.QuadPart - g_startTime.QuadPart)
               / static_cast<float>(g_frequency.QuadPart);

    ConstantBuffer cbData = {};
    cbData.iTime        = time;
    cbData.iResolutionX = static_cast<float>(WINDOW_WIDTH);
    cbData.iResolutionY = static_cast<float>(WINDOW_HEIGHT);
    memcpy(g_constantBufferDataBegin, &cbData, sizeof(cbData));

    /* Reset */
    g_commandAllocator->Reset();
    g_commandList->Reset(g_commandAllocator.Get(), g_pipelineState.Get());

    /* Root signature & descriptor heaps */
    g_commandList->SetGraphicsRootSignature(g_rootSignature.Get());

    ID3D12DescriptorHeap* heaps[] = { g_cbvHeap.Get() };
    g_commandList->SetDescriptorHeaps(_countof(heaps), heaps);
    g_commandList->SetGraphicsRootDescriptorTable(0,
        g_cbvHeap->GetGPUDescriptorHandleForHeapStart());

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

    /* Draw fullscreen quad */
    g_commandList->IASetPrimitiveTopology(D3D_PRIMITIVE_TOPOLOGY_TRIANGLELIST);
    g_commandList->IASetVertexBuffers(0, 1, &g_vertexBufferView);
    g_commandList->DrawInstanced(6, 1, 0, 0);

    /* Barrier: RENDER_TARGET -> PRESENT */
    g_commandList->ResourceBarrier(1,
        &CD3DX12_RESOURCE_BARRIER::Transition(
            g_renderTargets[g_frameIndex].Get(),
            D3D12_RESOURCE_STATE_RENDER_TARGET,
            D3D12_RESOURCE_STATE_PRESENT));

    g_commandList->Close();

    /* Execute */
    ID3D12CommandList* ppCommandLists[] = { g_commandList.Get() };
    g_commandQueue->ExecuteCommandLists(_countof(ppCommandLists), ppCommandLists);

    /* Present */
    g_swapChain->Present(1, 0);
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
