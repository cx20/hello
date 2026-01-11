/*
 * DirectX 12 Compute Shader Harmonograph (C / Win32 / No external libs)
 *
 * - Creates a Win32 window
 * - Uses a compute shader to fill UAV buffers (positions + colors)
 * - Uses a vertex/fragment shader to render LINE_STRIP from buffer data
 *
 * Build: cl harmonograph_dx12.c /link d3d12.lib dxgi.lib d3dcompiler.lib user32.lib
 */

#include <tchar.h>
#include <windows.h>
#include <d3d12.h>
#include <dxgi1_4.h>
#include <d3dcompiler.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>

#define WIDTH 640
#define HEIGHT 480
#define FRAMES 2
#define VERTEX_COUNT 500000

/* Constant buffer for harmonograph parameters */
typedef struct HARMONOGRAPH_PARAMS
{
    float A1, f1, p1, d1;
    float A2, f2, p2, d2;
    float A3, f3, p3, d3;
    float A4, f4, p4, d4;
    unsigned int max_num;
    float padding[3];
    float resolution[2];
    float padding2[2];
} HARMONOGRAPH_PARAMS;

/* Global variables */
IDXGISwapChain3*           g_swapChain;
ID3D12Device*              g_device;
ID3D12Resource*            g_renderTarget[FRAMES];
ID3D12CommandAllocator*    g_commandAllocator;
ID3D12CommandAllocator*    g_computeCommandAllocator;
ID3D12CommandQueue*        g_commandQueue;
ID3D12DescriptorHeap*      g_rtvHeap;
ID3D12DescriptorHeap*      g_srvUavHeap;
ID3D12PipelineState*       g_graphicsPso;
ID3D12PipelineState*       g_computePso;
ID3D12GraphicsCommandList* g_commandList;
ID3D12GraphicsCommandList* g_computeCommandList;
ID3D12RootSignature*       g_graphicsRootSignature;
ID3D12RootSignature*       g_computeRootSignature;
HANDLE                     g_fenceEvent;
ID3D12Fence*               g_fence;
UINT64                     g_fenceValue;
UINT                       g_frameIndex;

ID3D12Resource*            g_positionBuffer;
ID3D12Resource*            g_colorBuffer;
ID3D12Resource*            g_constantBuffer;
HARMONOGRAPH_PARAMS*       g_constantBufferData;

UINT g_rtvDescriptorSize;
UINT g_srvUavDescriptorSize;

/* Harmonograph parameters */
float g_A1 = 50.0f, g_f1 = 2.0f, g_p1 = 1.0f/16.0f, g_d1 = 0.02f;
float g_A2 = 50.0f, g_f2 = 2.0f, g_p2 = 3.0f/2.0f,  g_d2 = 0.0315f;
float g_A3 = 50.0f, g_f3 = 2.0f, g_p3 = 13.0f/15.0f, g_d3 = 0.02f;
float g_A4 = 50.0f, g_f4 = 2.0f, g_p4 = 1.0f,       g_d4 = 0.02f;

#define PI2 6.283185307179586f

float randf() {
    return (float)rand() / (float)RAND_MAX;
}

void WaitForPreviousFrame()
{
    const UINT64 fence = g_fenceValue;
    g_commandQueue->lpVtbl->Signal(g_commandQueue, g_fence, fence);
    g_fenceValue++;
    if (g_fence->lpVtbl->GetCompletedValue(g_fence) < fence)
    {
        g_fence->lpVtbl->SetEventOnCompletion(g_fence, fence, g_fenceEvent);
        WaitForSingleObject(g_fenceEvent, INFINITE);
    }
    g_frameIndex = g_swapChain->lpVtbl->GetCurrentBackBufferIndex(g_swapChain);
}

static LRESULT CALLBACK WindowProc(HWND hWnd, UINT uMsg, WPARAM wParam, LPARAM lParam)
{
    if ((uMsg == WM_KEYUP && wParam == VK_ESCAPE) || uMsg == WM_CLOSE || uMsg == WM_DESTROY)
    {
        PostQuitMessage(0);
        return 0;
    }
    return DefWindowProc(hWnd, uMsg, wParam, lParam);
}

int WINAPI WinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, LPSTR lpCmdLine, int nCmdShow)
{
    int exit = 0;
    MSG msg;
    DWORD startTime, currentTime, lastFpsTime;
    int frameCount = 0;
    float fps = 0.0f;
    char titleBuffer[256];

    srand((unsigned int)time(NULL));

    /* Create window */
    WNDCLASS win;
    ZeroMemory(&win, sizeof(WNDCLASS));
    win.style = CS_OWNDC | CS_HREDRAW | CS_VREDRAW;
    win.lpfnWndProc = WindowProc;
    win.hInstance = hInstance;
    win.lpszClassName = "HarmonographDX12";
    win.hbrBackground = (HBRUSH)(COLOR_WINDOW + 1);
    RegisterClass(&win);

    HWND hWnd = CreateWindowEx(0, win.lpszClassName, "DirectX 12 Compute Harmonograph",
                               WS_VISIBLE | WS_OVERLAPPEDWINDOW, 0, 0, WIDTH, HEIGHT, 0, 0, 0, 0);
    
    /* Create DXGI Factory and Device */
    IDXGIFactory4* pFactory;
    CreateDXGIFactory1(&IID_IDXGIFactory4, (void**)&pFactory);
    D3D12CreateDevice(NULL, D3D_FEATURE_LEVEL_12_0, &IID_ID3D12Device, (void**)&g_device);

    /* Create Command Queue */
    D3D12_COMMAND_QUEUE_DESC queueDesc = {
        D3D12_COMMAND_LIST_TYPE_DIRECT,
        0,
        D3D12_COMMAND_QUEUE_FLAG_NONE,
        0
    };
    g_device->lpVtbl->CreateCommandQueue(g_device, &queueDesc, &IID_ID3D12CommandQueue, (void**)&g_commandQueue);

    /* Create Swap Chain */
    DXGI_SWAP_CHAIN_DESC descSwapChain = {
        { WIDTH, HEIGHT, {0, 0}, DXGI_FORMAT_R8G8B8A8_UNORM, 0, 0 },
        { 1, 0 },
        DXGI_USAGE_RENDER_TARGET_OUTPUT,
        FRAMES,
        hWnd,
        TRUE,
        DXGI_SWAP_EFFECT_FLIP_DISCARD,
        0
    };
    IDXGISwapChain* swapChain;
    pFactory->lpVtbl->CreateSwapChain(pFactory, (IUnknown*)g_commandQueue, &descSwapChain, &swapChain);
    swapChain->lpVtbl->QueryInterface(swapChain, &IID_IDXGISwapChain3, (void**)&g_swapChain);
    swapChain->lpVtbl->Release(swapChain);
    g_frameIndex = g_swapChain->lpVtbl->GetCurrentBackBufferIndex(g_swapChain);

    /* Create RTV Descriptor Heap */
    D3D12_DESCRIPTOR_HEAP_DESC rtvHeapDesc = {
        D3D12_DESCRIPTOR_HEAP_TYPE_RTV,
        FRAMES,
        D3D12_DESCRIPTOR_HEAP_FLAG_NONE,
        0
    };
    g_device->lpVtbl->CreateDescriptorHeap(g_device, &rtvHeapDesc, &IID_ID3D12DescriptorHeap, (void**)&g_rtvHeap);
    g_rtvDescriptorSize = g_device->lpVtbl->GetDescriptorHandleIncrementSize(g_device, D3D12_DESCRIPTOR_HEAP_TYPE_RTV);

    /* Create SRV/UAV Descriptor Heap */
    D3D12_DESCRIPTOR_HEAP_DESC srvUavHeapDesc = {
        D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV,
        3, /* 2 UAVs + 1 CBV */
        D3D12_DESCRIPTOR_HEAP_FLAG_SHADER_VISIBLE,
        0
    };
    g_device->lpVtbl->CreateDescriptorHeap(g_device, &srvUavHeapDesc, &IID_ID3D12DescriptorHeap, (void**)&g_srvUavHeap);
    g_srvUavDescriptorSize = g_device->lpVtbl->GetDescriptorHandleIncrementSize(g_device, D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV);

    /* Create Render Target Views */
    D3D12_CPU_DESCRIPTOR_HANDLE rtvHandle;
    ((void(__stdcall*)(ID3D12DescriptorHeap*, D3D12_CPU_DESCRIPTOR_HANDLE*))
        g_rtvHeap->lpVtbl->GetCPUDescriptorHandleForHeapStart)(g_rtvHeap, &rtvHandle);
    for (UINT i = 0; i < FRAMES; i++)
    {
        g_swapChain->lpVtbl->GetBuffer(g_swapChain, i, &IID_ID3D12Resource, (void**)&g_renderTarget[i]);
        g_device->lpVtbl->CreateRenderTargetView(g_device, g_renderTarget[i], NULL, rtvHandle);
        rtvHandle.ptr += g_rtvDescriptorSize;
    }

    /* Create Position Buffer (UAV) */
    D3D12_HEAP_PROPERTIES defaultHeapProps = {
        D3D12_HEAP_TYPE_DEFAULT, D3D12_CPU_PAGE_PROPERTY_UNKNOWN,
        D3D12_MEMORY_POOL_UNKNOWN, 1, 1
    };
    D3D12_RESOURCE_DESC bufferDesc = {
        D3D12_RESOURCE_DIMENSION_BUFFER, 0,
        VERTEX_COUNT * 16, 1, 1, 1,
        DXGI_FORMAT_UNKNOWN, {1, 0},
        D3D12_TEXTURE_LAYOUT_ROW_MAJOR,
        D3D12_RESOURCE_FLAG_ALLOW_UNORDERED_ACCESS
    };
    g_device->lpVtbl->CreateCommittedResource(g_device, &defaultHeapProps, D3D12_HEAP_FLAG_NONE,
        &bufferDesc, D3D12_RESOURCE_STATE_UNORDERED_ACCESS, NULL, &IID_ID3D12Resource, (void**)&g_positionBuffer);

    /* Create Color Buffer (UAV) */
    g_device->lpVtbl->CreateCommittedResource(g_device, &defaultHeapProps, D3D12_HEAP_FLAG_NONE,
        &bufferDesc, D3D12_RESOURCE_STATE_UNORDERED_ACCESS, NULL, &IID_ID3D12Resource, (void**)&g_colorBuffer);

    /* Create Constant Buffer */
    D3D12_HEAP_PROPERTIES uploadHeapProps = {
        D3D12_HEAP_TYPE_UPLOAD, D3D12_CPU_PAGE_PROPERTY_UNKNOWN,
        D3D12_MEMORY_POOL_UNKNOWN, 1, 1
    };
    D3D12_RESOURCE_DESC cbDesc = {
        D3D12_RESOURCE_DIMENSION_BUFFER, 0,
        256, 1, 1, 1,
        DXGI_FORMAT_UNKNOWN, {1, 0},
        D3D12_TEXTURE_LAYOUT_ROW_MAJOR, D3D12_RESOURCE_FLAG_NONE
    };
    g_device->lpVtbl->CreateCommittedResource(g_device, &uploadHeapProps, D3D12_HEAP_FLAG_NONE,
        &cbDesc, D3D12_RESOURCE_STATE_GENERIC_READ, NULL, &IID_ID3D12Resource, (void**)&g_constantBuffer);
    g_constantBuffer->lpVtbl->Map(g_constantBuffer, 0, NULL, (void**)&g_constantBufferData);

    /* Create UAVs and CBV */
    D3D12_CPU_DESCRIPTOR_HANDLE srvUavHandle;
    ((void(__stdcall*)(ID3D12DescriptorHeap*, D3D12_CPU_DESCRIPTOR_HANDLE*))
        g_srvUavHeap->lpVtbl->GetCPUDescriptorHandleForHeapStart)(g_srvUavHeap, &srvUavHandle);

    D3D12_UNORDERED_ACCESS_VIEW_DESC uavDesc = {0};
    uavDesc.Format = DXGI_FORMAT_UNKNOWN;
    uavDesc.ViewDimension = D3D12_UAV_DIMENSION_BUFFER;
    uavDesc.Buffer.FirstElement = 0;
    uavDesc.Buffer.NumElements = VERTEX_COUNT;
    uavDesc.Buffer.StructureByteStride = 16;
    uavDesc.Buffer.CounterOffsetInBytes = 0;
    uavDesc.Buffer.Flags = D3D12_BUFFER_UAV_FLAG_NONE;

    g_device->lpVtbl->CreateUnorderedAccessView(g_device, g_positionBuffer, NULL, &uavDesc, srvUavHandle);
    srvUavHandle.ptr += g_srvUavDescriptorSize;
    g_device->lpVtbl->CreateUnorderedAccessView(g_device, g_colorBuffer, NULL, &uavDesc, srvUavHandle);
    srvUavHandle.ptr += g_srvUavDescriptorSize;

    D3D12_CONSTANT_BUFFER_VIEW_DESC cbvDesc = {0};
    cbvDesc.BufferLocation = g_constantBuffer->lpVtbl->GetGPUVirtualAddress(g_constantBuffer);
    cbvDesc.SizeInBytes = 256;
    g_device->lpVtbl->CreateConstantBufferView(g_device, &cbvDesc, srvUavHandle);

    /* Create Compute Root Signature */
    D3D12_DESCRIPTOR_RANGE uavRange = {
        D3D12_DESCRIPTOR_RANGE_TYPE_UAV, 2, 0, 0, D3D12_DESCRIPTOR_RANGE_OFFSET_APPEND
    };
    D3D12_DESCRIPTOR_RANGE cbvRange = {
        D3D12_DESCRIPTOR_RANGE_TYPE_CBV, 1, 0, 0, D3D12_DESCRIPTOR_RANGE_OFFSET_APPEND
    };
    D3D12_ROOT_PARAMETER computeRootParams[2];
    computeRootParams[0].ParameterType = D3D12_ROOT_PARAMETER_TYPE_DESCRIPTOR_TABLE;
    computeRootParams[0].DescriptorTable.NumDescriptorRanges = 1;
    computeRootParams[0].DescriptorTable.pDescriptorRanges = &uavRange;
    computeRootParams[0].ShaderVisibility = D3D12_SHADER_VISIBILITY_ALL;
    computeRootParams[1].ParameterType = D3D12_ROOT_PARAMETER_TYPE_DESCRIPTOR_TABLE;
    computeRootParams[1].DescriptorTable.NumDescriptorRanges = 1;
    computeRootParams[1].DescriptorTable.pDescriptorRanges = &cbvRange;
    computeRootParams[1].ShaderVisibility = D3D12_SHADER_VISIBILITY_ALL;

    D3D12_ROOT_SIGNATURE_DESC computeRootSigDesc = {
        2, computeRootParams, 0, NULL, D3D12_ROOT_SIGNATURE_FLAG_NONE
    };
    ID3DBlob* signature;
    ID3DBlob* error;
    D3D12SerializeRootSignature(&computeRootSigDesc, D3D_ROOT_SIGNATURE_VERSION_1, &signature, &error);
    g_device->lpVtbl->CreateRootSignature(g_device, 0,
        signature->lpVtbl->GetBufferPointer(signature),
        signature->lpVtbl->GetBufferSize(signature),
        &IID_ID3D12RootSignature, (void**)&g_computeRootSignature);
    signature->lpVtbl->Release(signature);

    /* Create Graphics Root Signature */
    D3D12_DESCRIPTOR_RANGE srvRange = {
        D3D12_DESCRIPTOR_RANGE_TYPE_SRV, 2, 0, 0, D3D12_DESCRIPTOR_RANGE_OFFSET_APPEND
    };
    D3D12_ROOT_PARAMETER graphicsRootParams[2];
    graphicsRootParams[0].ParameterType = D3D12_ROOT_PARAMETER_TYPE_DESCRIPTOR_TABLE;
    graphicsRootParams[0].DescriptorTable.NumDescriptorRanges = 1;
    graphicsRootParams[0].DescriptorTable.pDescriptorRanges = &srvRange;
    graphicsRootParams[0].ShaderVisibility = D3D12_SHADER_VISIBILITY_VERTEX;
    graphicsRootParams[1].ParameterType = D3D12_ROOT_PARAMETER_TYPE_DESCRIPTOR_TABLE;
    graphicsRootParams[1].DescriptorTable.NumDescriptorRanges = 1;
    graphicsRootParams[1].DescriptorTable.pDescriptorRanges = &cbvRange;
    graphicsRootParams[1].ShaderVisibility = D3D12_SHADER_VISIBILITY_VERTEX;

    D3D12_ROOT_SIGNATURE_DESC graphicsRootSigDesc = {
        2, graphicsRootParams, 0, NULL, D3D12_ROOT_SIGNATURE_FLAG_NONE
    };
    D3D12SerializeRootSignature(&graphicsRootSigDesc, D3D_ROOT_SIGNATURE_VERSION_1, &signature, &error);
    g_device->lpVtbl->CreateRootSignature(g_device, 0,
        signature->lpVtbl->GetBufferPointer(signature),
        signature->lpVtbl->GetBufferSize(signature),
        &IID_ID3D12RootSignature, (void**)&g_graphicsRootSignature);
    signature->lpVtbl->Release(signature);

    /* Compile Shaders */
    ID3DBlob* computeShader;
    ID3DBlob* vertexShader;
    ID3DBlob* pixelShader;
    UINT compileFlags = 0;

    HRESULT hr;
    hr = D3DCompileFromFile(L"hello.hlsl", NULL, NULL, "CSMain", "cs_5_0", compileFlags, 0, &computeShader, &error);
    if (FAILED(hr)) {
        if (error) {
            MessageBoxA(NULL, (char*)error->lpVtbl->GetBufferPointer(error), "Compute Shader Error", MB_OK);
            error->lpVtbl->Release(error);
        }
        return 1;
    }
    hr = D3DCompileFromFile(L"hello.hlsl", NULL, NULL, "VSMain", "vs_5_0", compileFlags, 0, &vertexShader, &error);
    if (FAILED(hr)) {
        if (error) {
            MessageBoxA(NULL, (char*)error->lpVtbl->GetBufferPointer(error), "Vertex Shader Error", MB_OK);
            error->lpVtbl->Release(error);
        }
        return 1;
    }
    hr = D3DCompileFromFile(L"hello.hlsl", NULL, NULL, "PSMain", "ps_5_0", compileFlags, 0, &pixelShader, &error);
    if (FAILED(hr)) {
        if (error) {
            MessageBoxA(NULL, (char*)error->lpVtbl->GetBufferPointer(error), "Pixel Shader Error", MB_OK);
            error->lpVtbl->Release(error);
        }
        return 1;
    }

    /* Create Compute Pipeline State */
    D3D12_COMPUTE_PIPELINE_STATE_DESC computePsoDesc = {0};
    computePsoDesc.pRootSignature = g_computeRootSignature;
    computePsoDesc.CS.pShaderBytecode = computeShader->lpVtbl->GetBufferPointer(computeShader);
    computePsoDesc.CS.BytecodeLength = computeShader->lpVtbl->GetBufferSize(computeShader);
    g_device->lpVtbl->CreateComputePipelineState(g_device, &computePsoDesc, &IID_ID3D12PipelineState, (void**)&g_computePso);

    /* Create Graphics Pipeline State */
    D3D12_RASTERIZER_DESC rasterizer = {
        D3D12_FILL_MODE_SOLID, D3D12_CULL_MODE_NONE, FALSE,
        D3D12_DEFAULT_DEPTH_BIAS, D3D12_DEFAULT_DEPTH_BIAS_CLAMP, 0.0f,
        TRUE, FALSE, FALSE, 0, D3D12_CONSERVATIVE_RASTERIZATION_MODE_OFF
    };
    D3D12_BLEND_DESC blendState = {0};
    blendState.RenderTarget[0].RenderTargetWriteMask = D3D12_COLOR_WRITE_ENABLE_ALL;

    D3D12_GRAPHICS_PIPELINE_STATE_DESC graphicsPsoDesc = {0};
    graphicsPsoDesc.pRootSignature = g_graphicsRootSignature;
    graphicsPsoDesc.VS.pShaderBytecode = vertexShader->lpVtbl->GetBufferPointer(vertexShader);
    graphicsPsoDesc.VS.BytecodeLength = vertexShader->lpVtbl->GetBufferSize(vertexShader);
    graphicsPsoDesc.PS.pShaderBytecode = pixelShader->lpVtbl->GetBufferPointer(pixelShader);
    graphicsPsoDesc.PS.BytecodeLength = pixelShader->lpVtbl->GetBufferSize(pixelShader);
    graphicsPsoDesc.RasterizerState = rasterizer;
    graphicsPsoDesc.BlendState = blendState;
    graphicsPsoDesc.DepthStencilState.DepthEnable = FALSE;
    graphicsPsoDesc.DepthStencilState.StencilEnable = FALSE;
    graphicsPsoDesc.SampleMask = UINT_MAX;
    graphicsPsoDesc.PrimitiveTopologyType = D3D12_PRIMITIVE_TOPOLOGY_TYPE_LINE;
    graphicsPsoDesc.NumRenderTargets = 1;
    graphicsPsoDesc.RTVFormats[0] = DXGI_FORMAT_R8G8B8A8_UNORM;
    graphicsPsoDesc.SampleDesc.Count = 1;
    g_device->lpVtbl->CreateGraphicsPipelineState(g_device, &graphicsPsoDesc, &IID_ID3D12PipelineState, (void**)&g_graphicsPso);

    /* Create Command Allocators and Command Lists */
    g_device->lpVtbl->CreateCommandAllocator(g_device, D3D12_COMMAND_LIST_TYPE_DIRECT,
        &IID_ID3D12CommandAllocator, (void**)&g_commandAllocator);
    g_device->lpVtbl->CreateCommandAllocator(g_device, D3D12_COMMAND_LIST_TYPE_DIRECT,
        &IID_ID3D12CommandAllocator, (void**)&g_computeCommandAllocator);

    g_device->lpVtbl->CreateCommandList(g_device, 0, D3D12_COMMAND_LIST_TYPE_DIRECT,
        g_commandAllocator, g_graphicsPso, &IID_ID3D12GraphicsCommandList, (void**)&g_commandList);
    g_commandList->lpVtbl->Close(g_commandList);

    g_device->lpVtbl->CreateCommandList(g_device, 0, D3D12_COMMAND_LIST_TYPE_DIRECT,
        g_computeCommandAllocator, g_computePso, &IID_ID3D12GraphicsCommandList, (void**)&g_computeCommandList);
    g_computeCommandList->lpVtbl->Close(g_computeCommandList);

    /* Create Fence */
    g_device->lpVtbl->CreateFence(g_device, 0, D3D12_FENCE_FLAG_NONE, &IID_ID3D12Fence, (void**)&g_fence);
    g_fenceValue = 1;
    g_fenceEvent = CreateEventEx(NULL, FALSE, FALSE, EVENT_ALL_ACCESS);

    D3D12_VIEWPORT viewport = {0.0f, 0.0f, (float)WIDTH, (float)HEIGHT, 0.0f, 1.0f};
    D3D12_RECT scissorRect = {0, 0, WIDTH, HEIGHT};

    startTime = GetTickCount();
    lastFpsTime = startTime;

    /* Main Loop */
    while (!exit)
    {
        while (PeekMessage(&msg, 0, 0, 0, PM_REMOVE))
        {
            if (msg.message == WM_QUIT) exit = 1;
            TranslateMessage(&msg);
            DispatchMessage(&msg);
        }

        currentTime = GetTickCount();
        if (currentTime - startTime > 60000) {
            exit = 1;
            continue;
        }

        /* Animate parameters */
        g_f1 = fmodf(g_f1 + randf() / 40.0f, 10.0f);
        g_f2 = fmodf(g_f2 + randf() / 40.0f, 10.0f);
        g_f3 = fmodf(g_f3 + randf() / 40.0f, 10.0f);
        g_f4 = fmodf(g_f4 + randf() / 40.0f, 10.0f);
        g_p1 += (PI2 * 0.5f / 360.0f);

        /* Update constant buffer */
        g_constantBufferData->A1 = g_A1; g_constantBufferData->f1 = g_f1;
        g_constantBufferData->p1 = g_p1; g_constantBufferData->d1 = g_d1;
        g_constantBufferData->A2 = g_A2; g_constantBufferData->f2 = g_f2;
        g_constantBufferData->p2 = g_p2; g_constantBufferData->d2 = g_d2;
        g_constantBufferData->A3 = g_A3; g_constantBufferData->f3 = g_f3;
        g_constantBufferData->p3 = g_p3; g_constantBufferData->d3 = g_d3;
        g_constantBufferData->A4 = g_A4; g_constantBufferData->f4 = g_f4;
        g_constantBufferData->p4 = g_p4; g_constantBufferData->d4 = g_d4;
        g_constantBufferData->max_num = VERTEX_COUNT;
        g_constantBufferData->resolution[0] = (float)WIDTH;
        g_constantBufferData->resolution[1] = (float)HEIGHT;

        /* Compute Pass */
        g_computeCommandAllocator->lpVtbl->Reset(g_computeCommandAllocator);
        g_computeCommandList->lpVtbl->Reset(g_computeCommandList, g_computeCommandAllocator, g_computePso);

        ID3D12DescriptorHeap* heaps[] = {g_srvUavHeap};
        g_computeCommandList->lpVtbl->SetDescriptorHeaps(g_computeCommandList, 1, heaps);
        g_computeCommandList->lpVtbl->SetComputeRootSignature(g_computeCommandList, g_computeRootSignature);

        D3D12_GPU_DESCRIPTOR_HANDLE gpuHandle;
        ((void(__stdcall*)(ID3D12DescriptorHeap*, D3D12_GPU_DESCRIPTOR_HANDLE*))
            g_srvUavHeap->lpVtbl->GetGPUDescriptorHandleForHeapStart)(g_srvUavHeap, &gpuHandle);
        g_computeCommandList->lpVtbl->SetComputeRootDescriptorTable(g_computeCommandList, 0, gpuHandle);
        gpuHandle.ptr += g_srvUavDescriptorSize * 2;
        g_computeCommandList->lpVtbl->SetComputeRootDescriptorTable(g_computeCommandList, 1, gpuHandle);

        g_computeCommandList->lpVtbl->Dispatch(g_computeCommandList, (VERTEX_COUNT + 63) / 64, 1, 1);

        /* Barrier: UAV -> SRV */
        D3D12_RESOURCE_BARRIER uavBarrier = {0};
        uavBarrier.Type = D3D12_RESOURCE_BARRIER_TYPE_UAV;
        uavBarrier.UAV.pResource = g_positionBuffer;
        g_computeCommandList->lpVtbl->ResourceBarrier(g_computeCommandList, 1, &uavBarrier);
        uavBarrier.UAV.pResource = g_colorBuffer;
        g_computeCommandList->lpVtbl->ResourceBarrier(g_computeCommandList, 1, &uavBarrier);

        g_computeCommandList->lpVtbl->Close(g_computeCommandList);
        ID3D12CommandList* computeLists[] = {(ID3D12CommandList*)g_computeCommandList};
        g_commandQueue->lpVtbl->ExecuteCommandLists(g_commandQueue, 1, computeLists);
        WaitForPreviousFrame();

        /* Graphics Pass */
        g_commandAllocator->lpVtbl->Reset(g_commandAllocator);
        g_commandList->lpVtbl->Reset(g_commandList, g_commandAllocator, g_graphicsPso);

        g_commandList->lpVtbl->SetDescriptorHeaps(g_commandList, 1, heaps);
        g_commandList->lpVtbl->SetGraphicsRootSignature(g_commandList, g_graphicsRootSignature);

        ((void(__stdcall*)(ID3D12DescriptorHeap*, D3D12_GPU_DESCRIPTOR_HANDLE*))
            g_srvUavHeap->lpVtbl->GetGPUDescriptorHandleForHeapStart)(g_srvUavHeap, &gpuHandle);
        g_commandList->lpVtbl->SetGraphicsRootDescriptorTable(g_commandList, 0, gpuHandle);
        gpuHandle.ptr += g_srvUavDescriptorSize * 2;
        g_commandList->lpVtbl->SetGraphicsRootDescriptorTable(g_commandList, 1, gpuHandle);

        g_commandList->lpVtbl->RSSetViewports(g_commandList, 1, &viewport);
        g_commandList->lpVtbl->RSSetScissorRects(g_commandList, 1, &scissorRect);

        D3D12_RESOURCE_BARRIER rtBarrier = {0};
        rtBarrier.Type = D3D12_RESOURCE_BARRIER_TYPE_TRANSITION;
        rtBarrier.Transition.pResource = g_renderTarget[g_frameIndex];
        rtBarrier.Transition.StateBefore = D3D12_RESOURCE_STATE_PRESENT;
        rtBarrier.Transition.StateAfter = D3D12_RESOURCE_STATE_RENDER_TARGET;
        rtBarrier.Transition.Subresource = D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES;
        g_commandList->lpVtbl->ResourceBarrier(g_commandList, 1, &rtBarrier);

        ((void(__stdcall*)(ID3D12DescriptorHeap*, D3D12_CPU_DESCRIPTOR_HANDLE*))
            g_rtvHeap->lpVtbl->GetCPUDescriptorHandleForHeapStart)(g_rtvHeap, &rtvHandle);
        rtvHandle.ptr += g_frameIndex * g_rtvDescriptorSize;

        float clearColor[] = {0.0f, 0.0f, 0.0f, 1.0f};
        g_commandList->lpVtbl->ClearRenderTargetView(g_commandList, rtvHandle, clearColor, 0, NULL);
        g_commandList->lpVtbl->OMSetRenderTargets(g_commandList, 1, &rtvHandle, FALSE, NULL);
        g_commandList->lpVtbl->IASetPrimitiveTopology(g_commandList, D3D_PRIMITIVE_TOPOLOGY_LINESTRIP);
        g_commandList->lpVtbl->DrawInstanced(g_commandList, VERTEX_COUNT, 1, 0, 0);

        rtBarrier.Transition.StateBefore = D3D12_RESOURCE_STATE_RENDER_TARGET;
        rtBarrier.Transition.StateAfter = D3D12_RESOURCE_STATE_PRESENT;
        g_commandList->lpVtbl->ResourceBarrier(g_commandList, 1, &rtBarrier);

        g_commandList->lpVtbl->Close(g_commandList);
        ID3D12CommandList* graphicsLists[] = {(ID3D12CommandList*)g_commandList};
        g_commandQueue->lpVtbl->ExecuteCommandLists(g_commandQueue, 1, graphicsLists);

        g_swapChain->lpVtbl->Present(g_swapChain, 0, 0);
        WaitForPreviousFrame();

        /* FPS calculation */
        frameCount++;
        if (currentTime - lastFpsTime >= 1000) {
            fps = (float)frameCount * 1000.0f / (float)(currentTime - lastFpsTime);
            frameCount = 0;
            lastFpsTime = currentTime;
            sprintf(titleBuffer, "DirectX 12 Compute Harmonograph - FPS: %.1f", fps);
            SetWindowTextA(hWnd, titleBuffer);
        }

        Sleep(1);
    }

    WaitForPreviousFrame();
    CloseHandle(g_fenceEvent);

    /* Cleanup */
    g_constantBuffer->lpVtbl->Unmap(g_constantBuffer, 0, NULL);
    g_constantBuffer->lpVtbl->Release(g_constantBuffer);
    g_positionBuffer->lpVtbl->Release(g_positionBuffer);
    g_colorBuffer->lpVtbl->Release(g_colorBuffer);
    g_computePso->lpVtbl->Release(g_computePso);
    g_graphicsPso->lpVtbl->Release(g_graphicsPso);
    g_computeRootSignature->lpVtbl->Release(g_computeRootSignature);
    g_graphicsRootSignature->lpVtbl->Release(g_graphicsRootSignature);
    g_computeCommandList->lpVtbl->Release(g_computeCommandList);
    g_commandList->lpVtbl->Release(g_commandList);
    g_computeCommandAllocator->lpVtbl->Release(g_computeCommandAllocator);
    g_commandAllocator->lpVtbl->Release(g_commandAllocator);
    g_srvUavHeap->lpVtbl->Release(g_srvUavHeap);
    g_rtvHeap->lpVtbl->Release(g_rtvHeap);
    for (UINT i = 0; i < FRAMES; i++) {
        g_renderTarget[i]->lpVtbl->Release(g_renderTarget[i]);
    }
    g_fence->lpVtbl->Release(g_fence);
    g_commandQueue->lpVtbl->Release(g_commandQueue);
    g_swapChain->lpVtbl->Release(g_swapChain);
    g_device->lpVtbl->Release(g_device);
    pFactory->lpVtbl->Release(pFactory);

    return 0;
}
