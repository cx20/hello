#include <windows.h>
#include <wrl.h>

#include <d3d12.h>
#include <dxgi1_4.h>
#include <d3dcompiler.h>
#include <directxmath.h>
#include "d3dx12.h"

#pragma comment(lib, "d3d12.lib")
#pragma comment(lib, "dxgi.lib")
#pragma comment(lib, "d3dcompiler.lib")

#define WINDOW_WIDTH    640
#define WINDOW_HEIGHT   480

using namespace DirectX;
using Microsoft::WRL::ComPtr;

struct VERTEX
{
    XMFLOAT3 position;
    XMFLOAT4 color;
};

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
LRESULT CALLBACK WindowProc(HWND hWnd, UINT nMsg, WPARAM wParam, LPARAM lParam);

static const UINT   g_frameCount = 2;

ComPtr<ID3D12Device>                g_device;
ComPtr<IDXGISwapChain3>             g_swapChain;
ComPtr<ID3D12Resource>              g_renderTargets[g_frameCount];
ComPtr<ID3D12CommandAllocator>      g_commandAllocator;
ComPtr<ID3D12CommandQueue>          g_commandQueue;
ComPtr<ID3D12RootSignature>         g_rootSignature;
ComPtr<ID3D12DescriptorHeap>        g_rtvHeap;
ComPtr<ID3D12PipelineState>         g_pipelineState;
ComPtr<ID3D12GraphicsCommandList>   g_commandList;
static UINT                         g_rtvDescriptorSize = 0;

static CD3DX12_VIEWPORT g_viewport(0.0f, 0.0f, static_cast<FLOAT>(WINDOW_WIDTH), static_cast<FLOAT>(WINDOW_HEIGHT));
static CD3DX12_RECT     g_scissorRect(0, 0, static_cast<LONG>(WINDOW_WIDTH), static_cast<LONG>(WINDOW_HEIGHT));

static UINT         g_frameIndex = 0;
static HANDLE       g_fenceEvent;
ComPtr<ID3D12Fence> g_fence;
static UINT64       g_fenceValue;

ComPtr<ID3D12Resource>              g_vertexBuffer;
static D3D12_VERTEX_BUFFER_VIEW     g_vertexBufferView;

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

    ComPtr<IDXGIFactory4> factory;
    if (FAILED(CreateDXGIFactory2(dxgiFactoryFlags, IID_PPV_ARGS(factory.GetAddressOf()))))
    {
        return E_FAIL;
    }

    HRESULT hr;
    ComPtr<IDXGIAdapter1> hardwareAdapter = nullptr;
    ComPtr<IDXGIAdapter1> adapter;
    for (UINT adapterIndex = 0; DXGI_ERROR_NOT_FOUND != factory->EnumAdapters1(adapterIndex, adapter.GetAddressOf()); ++adapterIndex)
    {
        DXGI_ADAPTER_DESC1 adapterDesc;
        adapter->GetDesc1(&adapterDesc);

        if (adapterDesc.Flags & DXGI_ADAPTER_FLAG_SOFTWARE) continue;

        hr = D3D12CreateDevice(adapter.Get(), D3D_FEATURE_LEVEL_11_0, _uuidof(ID3D12Device), nullptr);
        if (SUCCEEDED(hr))
        {
            if (FAILED(D3D12CreateDevice(hardwareAdapter.Get(), D3D_FEATURE_LEVEL_11_0, IID_PPV_ARGS(g_device.GetAddressOf()))))
            {
                return E_FAIL;
            }
            break;
        }
    }

    hardwareAdapter = adapter.Detach();

    if (FAILED(hr))
    {
        ComPtr<IDXGIAdapter> warpAdapter;
        factory->EnumWarpAdapter(IID_PPV_ARGS(warpAdapter.GetAddressOf()));
        if (FAILED(D3D12CreateDevice(warpAdapter.Get(), D3D_FEATURE_LEVEL_11_0, IID_PPV_ARGS(g_device.GetAddressOf()))))
        {
            return E_FAIL;
        }
    }

    D3D12_COMMAND_QUEUE_DESC queueDesc = {};
    queueDesc.Flags = D3D12_COMMAND_QUEUE_FLAG_NONE;
    queueDesc.Type = D3D12_COMMAND_LIST_TYPE_DIRECT;

    if (FAILED(g_device->CreateCommandQueue(&queueDesc, IID_PPV_ARGS(g_commandQueue.GetAddressOf()))))
    {
        return E_FAIL;
    }

    DXGI_SWAP_CHAIN_DESC1 swapChainDesc = {};
    swapChainDesc.BufferCount      = g_frameCount;
    swapChainDesc.Width            = WINDOW_WIDTH;
    swapChainDesc.Height           = WINDOW_HEIGHT;
    swapChainDesc.Format           = DXGI_FORMAT_R8G8B8A8_UNORM;
    swapChainDesc.BufferUsage      = DXGI_USAGE_RENDER_TARGET_OUTPUT;
    swapChainDesc.SwapEffect       = DXGI_SWAP_EFFECT_FLIP_DISCARD;
    swapChainDesc.SampleDesc.Count = 1;

    ComPtr<IDXGISwapChain1> swapChain;
    if (FAILED(factory->CreateSwapChainForHwnd(g_commandQueue.Get(), hWnd, &swapChainDesc, nullptr, nullptr, swapChain.GetAddressOf())))
    {
        return E_FAIL;
    }

    if (FAILED(factory->MakeWindowAssociation(hWnd, DXGI_MWA_NO_ALT_ENTER)))
    {
        return E_FAIL;
    }

    swapChain.As(&g_swapChain);

    g_frameIndex = g_swapChain->GetCurrentBackBufferIndex();

    return S_OK;
}

HRESULT InitView()
{
    {
        D3D12_DESCRIPTOR_HEAP_DESC rtvHeapDesc = {};
        rtvHeapDesc.NumDescriptors = g_frameCount;
        rtvHeapDesc.Type = D3D12_DESCRIPTOR_HEAP_TYPE_RTV;
        rtvHeapDesc.Flags = D3D12_DESCRIPTOR_HEAP_FLAG_NONE;

        if (FAILED(g_device->CreateDescriptorHeap(&rtvHeapDesc, IID_PPV_ARGS(g_rtvHeap.GetAddressOf()))))
        {
            return E_FAIL;
        }

        g_rtvDescriptorSize = g_device->GetDescriptorHandleIncrementSize(D3D12_DESCRIPTOR_HEAP_TYPE_RTV);
    }

    {
        CD3DX12_CPU_DESCRIPTOR_HANDLE rtvHandle(g_rtvHeap->GetCPUDescriptorHandleForHeapStart());

        for (UINT i = 0; i < g_frameCount; i++)
        {
            if (FAILED(g_swapChain->GetBuffer(i, IID_PPV_ARGS(g_renderTargets[i].GetAddressOf()))))
            {
                return E_FAIL;
            }

            g_device->CreateRenderTargetView(g_renderTargets[i].Get(), nullptr, rtvHandle);

            rtvHandle.Offset(1, g_rtvDescriptorSize);
        }
    }

    return S_OK;
}

HRESULT InitTraffic()
{
    if (FAILED(g_device->CreateCommandAllocator(D3D12_COMMAND_LIST_TYPE_DIRECT, IID_PPV_ARGS(g_commandAllocator.GetAddressOf()))))
    {
        return E_FAIL;
    }

    {
        CD3DX12_ROOT_SIGNATURE_DESC rsDesc;
        rsDesc.Init(0, nullptr, 0, nullptr, D3D12_ROOT_SIGNATURE_FLAG_ALLOW_INPUT_ASSEMBLER_INPUT_LAYOUT);

        ComPtr<ID3DBlob> signature;
        ComPtr<ID3DBlob> error;
        D3D12SerializeRootSignature(&rsDesc, D3D_ROOT_SIGNATURE_VERSION_1, signature.GetAddressOf(), error.GetAddressOf());
        if (FAILED(g_device->CreateRootSignature(0, signature->GetBufferPointer(), signature->GetBufferSize(), IID_PPV_ARGS(&g_rootSignature))))
        {
            return E_FAIL;
        }
    }

    return S_OK;
}

HRESULT InitShader()
{
    {
        ComPtr<ID3DBlob> vertexShader, pixelShader;

        UINT compileFlags = 0;

        if (FAILED(D3DCompileFromFile(L"hello.hlsl", nullptr, nullptr, "VSMain", "vs_5_0", compileFlags, 0, vertexShader.GetAddressOf(), nullptr)))
        {
            return E_FAIL;
        }
        
        if (FAILED(D3DCompileFromFile(L"hello.hlsl", nullptr, nullptr, "PSMain", "ps_5_0", compileFlags, 0, pixelShader.GetAddressOf(), nullptr)))
        {
            return E_FAIL;
        }

        D3D12_INPUT_ELEMENT_DESC inputElementDescs[] =
        {
            {"POSITION", 0, DXGI_FORMAT_R32G32B32_FLOAT,    0,  0, D3D12_INPUT_CLASSIFICATION_PER_VERTEX_DATA, 0},
            {"COLOR",    0, DXGI_FORMAT_R32G32B32A32_FLOAT, 0, 12, D3D12_INPUT_CLASSIFICATION_PER_VERTEX_DATA, 0},
        };

        D3D12_GRAPHICS_PIPELINE_STATE_DESC gpsDesc = {};
        gpsDesc.InputLayout = { inputElementDescs, _countof(inputElementDescs) };
        gpsDesc.pRootSignature = g_rootSignature.Get();
        gpsDesc.VS = CD3DX12_SHADER_BYTECODE(vertexShader.Get());
        gpsDesc.PS = CD3DX12_SHADER_BYTECODE(pixelShader.Get());
        gpsDesc.RasterizerState = CD3DX12_RASTERIZER_DESC(D3D12_DEFAULT);
        gpsDesc.BlendState = CD3DX12_BLEND_DESC(D3D12_DEFAULT);
        gpsDesc.DepthStencilState.DepthEnable = FALSE;
        gpsDesc.DepthStencilState.StencilEnable = FALSE;
        gpsDesc.SampleMask = UINT_MAX;
        gpsDesc.PrimitiveTopologyType = D3D12_PRIMITIVE_TOPOLOGY_TYPE_TRIANGLE;
        gpsDesc.NumRenderTargets = 1;
        gpsDesc.RTVFormats[0] = DXGI_FORMAT_R8G8B8A8_UNORM;
        gpsDesc.SampleDesc.Count = 1;

        if (FAILED(g_device->CreateGraphicsPipelineState(&gpsDesc, IID_PPV_ARGS(g_pipelineState.GetAddressOf()))))
        {
            return E_FAIL;
        }
    }

    return S_OK;
}

HRESULT InitBuffer()
{
    if (FAILED(g_device->CreateCommandList(0, D3D12_COMMAND_LIST_TYPE_DIRECT, g_commandAllocator.Get(), nullptr, IID_PPV_ARGS(g_commandList.GetAddressOf()))))
    {
        return E_FAIL;
    }

    g_commandList->Close();

    {
        VERTEX vertices[] =
        {
            { XMFLOAT3(  0.0f,  0.5f, 0.0f), XMFLOAT4(1.0f, 0.0f, 0.0f, 1.0f) },
            { XMFLOAT3(  0.5f, -0.5f, 0.0f), XMFLOAT4(0.0f, 1.0f, 0.0f, 1.0f) },
            { XMFLOAT3( -0.5f, -0.5f, 0.0f), XMFLOAT4(0.0f, 0.0f, 1.0f, 1.0f) },
        };

        const UINT vertexBufferSize = sizeof(vertices);

        if (FAILED(g_device->CreateCommittedResource(&CD3DX12_HEAP_PROPERTIES(D3D12_HEAP_TYPE_UPLOAD), D3D12_HEAP_FLAG_NONE, &CD3DX12_RESOURCE_DESC::Buffer(vertexBufferSize), D3D12_RESOURCE_STATE_GENERIC_READ, nullptr, IID_PPV_ARGS(g_vertexBuffer.GetAddressOf()))))
        {
            return E_FAIL;
        }

        UINT8* pVertexDataBegin;
        CD3DX12_RANGE readRange(0, 0);
        g_vertexBuffer->Map(0, &readRange, reinterpret_cast<void**>(&pVertexDataBegin));
        memcpy(pVertexDataBegin, vertices, sizeof(vertices));
        g_vertexBuffer->Unmap(0, nullptr);

        g_vertexBufferView.BufferLocation = g_vertexBuffer->GetGPUVirtualAddress();
        g_vertexBufferView.StrideInBytes  = sizeof(VERTEX);
        g_vertexBufferView.SizeInBytes    = vertexBufferSize;
    }

    return S_OK;
}

HRESULT InitFence()
{
    {
        if (FAILED(g_device->CreateFence(0, D3D12_FENCE_FLAG_NONE, IID_PPV_ARGS(g_fence.GetAddressOf()))))
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
    }

    return S_OK;
}

void OnRender()
{
    g_commandAllocator->Reset();

    g_commandList->Reset(g_commandAllocator.Get(), g_pipelineState.Get());

    g_commandList->SetGraphicsRootSignature(g_rootSignature.Get());
    g_commandList->RSSetViewports(1, &g_viewport);
    g_commandList->RSSetScissorRects(1, &g_scissorRect);

    g_commandList->ResourceBarrier(1, &CD3DX12_RESOURCE_BARRIER::Transition(g_renderTargets[g_frameIndex].Get(), D3D12_RESOURCE_STATE_PRESENT, D3D12_RESOURCE_STATE_RENDER_TARGET));

    CD3DX12_CPU_DESCRIPTOR_HANDLE rtvHandle(g_rtvHeap->GetCPUDescriptorHandleForHeapStart(), g_frameIndex, g_rtvDescriptorSize);

    g_commandList->OMSetRenderTargets(1, &rtvHandle, FALSE, nullptr);

    const FLOAT clearColor[] = { 1.0f, 1.0f, 1.0f, 1.0f };
    g_commandList->ClearRenderTargetView(rtvHandle, clearColor, 0, nullptr);
    g_commandList->IASetPrimitiveTopology(D3D_PRIMITIVE_TOPOLOGY_TRIANGLELIST);
    g_commandList->IASetVertexBuffers(0, 1, &g_vertexBufferView);
    g_commandList->DrawInstanced(3, 1, 0, 0);

    g_commandList->ResourceBarrier(1, &CD3DX12_RESOURCE_BARRIER::Transition(g_renderTargets[g_frameIndex].Get(), D3D12_RESOURCE_STATE_RENDER_TARGET, D3D12_RESOURCE_STATE_PRESENT));

    g_commandList->Close();

    ID3D12CommandList* ppCommandLists[] = { g_commandList.Get() };
    g_commandQueue->ExecuteCommandLists(_countof(ppCommandLists), ppCommandLists);

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
    CloseHandle(g_fenceEvent);
}

LRESULT CALLBACK WindowProc(HWND hWnd, UINT nMsg, WPARAM wParam, LPARAM lParam)
{
    switch (nMsg) {
    case WM_DESTROY:
        OnDestroy();
        PostQuitMessage(0);
        return 0;
    }

    return DefWindowProc(hWnd, nMsg, wParam, lParam);
}

int WINAPI WinMain(HINSTANCE hInstance, HINSTANCE, LPSTR, int nCmdShow)
{
    WNDCLASSEX  windowClass = {};
    windowClass.cbSize        = sizeof(WNDCLASSEX);
    windowClass.style         = CS_HREDRAW | CS_VREDRAW;
    windowClass.lpfnWndProc   = WindowProc;
    windowClass.hInstance     = hInstance;
    windowClass.hCursor       = LoadCursor(NULL, IDC_ARROW);
    windowClass.lpszClassName = L"windowClass";
    RegisterClassEx(&windowClass);

    RECT windowRect = { 0, 0, WINDOW_WIDTH, WINDOW_HEIGHT };
    AdjustWindowRect(&windowRect, WS_OVERLAPPEDWINDOW, FALSE);

    HWND hWnd = CreateWindow(
        L"windowClass",
        L"Hello, World!",
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
