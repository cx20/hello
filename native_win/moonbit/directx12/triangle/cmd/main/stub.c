#include <windows.h>
#ifndef _Null_
#define _Null_
#endif
#ifndef _In_
#define _In_
#endif
#ifndef _In_opt_
#define _In_opt_
#endif
#ifndef _Inout_
#define _Inout_
#endif
#ifndef _Inout_opt_
#define _Inout_opt_
#endif
#ifndef _Out_
#define _Out_
#endif
#ifndef _Out_opt_
#define _Out_opt_
#endif
#ifndef _In_count_
#define _In_count_(...)
#endif
#ifndef _In_opt_count_
#define _In_opt_count_(...)
#endif
#ifndef _Out_count_
#define _Out_count_(...)
#endif
#ifndef _Out_opt_count_
#define _Out_opt_count_(...)
#endif
#ifndef _In_reads_
#define _In_reads_(...)
#endif
#ifndef _In_reads_opt_
#define _In_reads_opt_(...)
#endif
#ifndef _In_reads_bytes_
#define _In_reads_bytes_(...)
#endif
#ifndef _In_reads_bytes_opt_
#define _In_reads_bytes_opt_(...)
#endif
#ifndef _Out_writes_
#define _Out_writes_(...)
#endif
#ifndef _Out_writes_opt_
#define _Out_writes_opt_(...)
#endif
#ifndef _Out_writes_bytes_
#define _Out_writes_bytes_(...)
#endif
#ifndef _Out_writes_bytes_opt_
#define _Out_writes_bytes_opt_(...)
#endif
#ifndef _Field_size_
#define _Field_size_(...)
#endif
#ifndef _Field_size_opt_
#define _Field_size_opt_(...)
#endif
#ifndef _Field_size_part_
#define _Field_size_part_(...)
#endif
#ifndef _Field_size_part_opt_
#define _Field_size_part_opt_(...)
#endif
#ifndef _Field_size_bytes_
#define _Field_size_bytes_(...)
#endif
#ifndef _Field_size_bytes_opt_
#define _Field_size_bytes_opt_(...)
#endif
#ifndef _Field_size_bytes_part_
#define _Field_size_bytes_part_(...)
#endif
#ifndef _Field_size_bytes_part_opt_
#define _Field_size_bytes_part_opt_(...)
#endif
#ifndef _Function_class_
#define _Function_class_(...)
#endif
#ifndef _Maybe_raises_SEH_exception_
#define _Maybe_raises_SEH_exception_(...)
#endif
#ifndef _Raises_SEH_exception_
#define _Raises_SEH_exception_(...)
#endif
#include "C:/Program Files (x86)/Windows Kits/10/Include/10.0.22621.0/um/d3d12.h"
#include "C:/Program Files (x86)/Windows Kits/10/Include/10.0.22621.0/shared/dxgi1_4.h"
#include "C:/Program Files (x86)/Windows Kits/10/Include/10.0.22621.0/um/d3dcompiler.h"
#include <string.h>

#define WIDTH 640
#define HEIGHT 480
#define FRAMES 2

typedef struct _VERTEX {
    float position[3];
    float color[4];
} VERTEX;

static IDXGISwapChain3 *g_swapChain = NULL;
static ID3D12Device *g_device = NULL;
static ID3D12Resource *g_renderTargets[FRAMES] = { NULL, NULL };
static ID3D12CommandAllocator *g_commandAllocator = NULL;
static ID3D12CommandQueue *g_commandQueue = NULL;
static ID3D12DescriptorHeap *g_descriptorHeap = NULL;
static ID3D12PipelineState *g_pso = NULL;
static ID3D12GraphicsCommandList *g_commandList = NULL;
static ID3D12RootSignature *g_rootSignature = NULL;
static ID3D12Resource *g_vertexBuffer = NULL;
static HANDLE g_fenceEvent = NULL;
static ID3D12Fence *g_fence = NULL;
static UINT64 g_fenceValue = 1;
static UINT g_frameIndex = 0;

static LRESULT CALLBACK WindowProc(HWND hWnd, UINT uMsg, WPARAM wParam, LPARAM lParam);
static HRESULT InitD3D12(HWND hWnd, D3D12_VERTEX_BUFFER_VIEW *vertexView, D3D12_VIEWPORT *viewport, D3D12_RECT *scissorRect);
static HRESULT CompileShaderFromSource(const char *source, const char *entry, const char *target, ID3DBlob **blobOut);
static void PopulateCommandList(const D3D12_VERTEX_BUFFER_VIEW *vertexView, const D3D12_VIEWPORT *viewport, const D3D12_RECT *scissorRect);
static void WaitForPreviousFrame(void);
static void CleanupD3D12(void);

void run_directx12(void) {
    WNDCLASSEXA wc;
    HWND hWnd;
    MSG msg;
    BOOL quit = FALSE;
    HINSTANCE hInstance = GetModuleHandleA(NULL);
    D3D12_VERTEX_BUFFER_VIEW vertexView;
    D3D12_VIEWPORT viewport;
    D3D12_RECT scissorRect;

    ZeroMemory(&wc, sizeof(wc));
    wc.cbSize = sizeof(wc);
    wc.style = CS_HREDRAW | CS_VREDRAW;
    wc.lpfnWndProc = WindowProc;
    wc.hInstance = hInstance;
    wc.hCursor = LoadCursorA(NULL, IDC_ARROW);
    wc.hbrBackground = (HBRUSH)(COLOR_WINDOW + 1);
    wc.lpszClassName = "helloWindow";

    if (!RegisterClassExA(&wc)) {
        return;
    }

    hWnd = CreateWindowExA(
        0,
        "helloWindow",
        "Hello, World!",
        WS_OVERLAPPEDWINDOW,
        CW_USEDEFAULT,
        CW_USEDEFAULT,
        WIDTH,
        HEIGHT,
        NULL,
        NULL,
        hInstance,
        NULL
    );

    if (hWnd == NULL) {
        return;
    }

    if (FAILED(InitD3D12(hWnd, &vertexView, &viewport, &scissorRect))) {
        CleanupD3D12();
        DestroyWindow(hWnd);
        return;
    }

    ShowWindow(hWnd, SW_SHOWDEFAULT);
    UpdateWindow(hWnd);

    while (!quit) {
        while (PeekMessageA(&msg, NULL, 0, 0, PM_REMOVE)) {
            if (msg.message == WM_QUIT) {
                quit = TRUE;
            }
            TranslateMessage(&msg);
            DispatchMessageA(&msg);
        }

        if (!quit) {
            PopulateCommandList(&vertexView, &viewport, &scissorRect);
            g_swapChain->lpVtbl->Present(g_swapChain, 1, 0);
            WaitForPreviousFrame();
        }
    }

    WaitForPreviousFrame();
    CleanupD3D12();
    DestroyWindow(hWnd);
}

static LRESULT CALLBACK WindowProc(HWND hWnd, UINT uMsg, WPARAM wParam, LPARAM lParam) {
    (void)lParam;

    if ((uMsg == WM_KEYUP && wParam == VK_ESCAPE) || uMsg == WM_CLOSE || uMsg == WM_DESTROY) {
        PostQuitMessage(0);
        return 0;
    }

    return DefWindowProcA(hWnd, uMsg, wParam, lParam);
}

static HRESULT CompileShaderFromSource(const char *source, const char *entry, const char *target, ID3DBlob **blobOut) {
    ID3DBlob *errorBlob = NULL;
    HRESULT hr = D3DCompile(
        source,
        (SIZE_T)lstrlenA(source),
        NULL,
        NULL,
        NULL,
        entry,
        target,
        D3DCOMPILE_ENABLE_STRICTNESS,
        0,
        blobOut,
        &errorBlob
    );

    if (errorBlob != NULL) {
        errorBlob->lpVtbl->Release(errorBlob);
    }

    return hr;
}

static HRESULT InitD3D12(HWND hWnd, D3D12_VERTEX_BUFFER_VIEW *vertexView, D3D12_VIEWPORT *viewport, D3D12_RECT *scissorRect) {
    IDXGIFactory4 *factory = NULL;
    IDXGISwapChain *swapChain = NULL;
    D3D12_COMMAND_QUEUE_DESC queueDesc;
    DXGI_SWAP_CHAIN_DESC swapDesc;
    D3D12_INPUT_ELEMENT_DESC layout[] = {
        { "POSITION", 0, DXGI_FORMAT_R32G32B32_FLOAT, 0, 0, D3D12_INPUT_CLASSIFICATION_PER_VERTEX_DATA, 0 },
        { "COLOR", 0, DXGI_FORMAT_R32G32B32A32_FLOAT, 0, 12, D3D12_INPUT_CLASSIFICATION_PER_VERTEX_DATA, 0 },
    };
    D3D12_ROOT_SIGNATURE_DESC rootSigDesc;
    ID3DBlob *rootSigBlob = NULL;
    ID3DBlob *rootSigErr = NULL;
    ID3DBlob *vsBlob = NULL;
    ID3DBlob *psBlob = NULL;
    D3D12_GRAPHICS_PIPELINE_STATE_DESC psoDesc;
    D3D12_DESCRIPTOR_HEAP_DESC rtvHeapDesc;
    D3D12_CPU_DESCRIPTOR_HANDLE rtvHandle;
    UINT rtvDescriptorSize;
    UINT i;
    VERTEX vertices[] = {
        { { 0.0f, 0.5f, 0.0f }, { 1.0f, 0.0f, 0.0f, 1.0f } },
        { { 0.5f, -0.5f, 0.0f }, { 0.0f, 1.0f, 0.0f, 1.0f } },
        { { -0.5f, -0.5f, 0.0f }, { 0.0f, 0.0f, 1.0f, 1.0f } },
    };
    D3D12_HEAP_PROPERTIES heapProps;
    D3D12_RESOURCE_DESC resourceDesc;
    void *mapped = NULL;
    const char *vsSource =
        "struct VS_IN { float3 pos : POSITION; float4 col : COLOR; };"
        "struct PS_IN { float4 pos : SV_POSITION; float4 col : COLOR; };"
        "PS_IN VSMain(VS_IN input) {"
        "  PS_IN output;"
        "  output.pos = float4(input.pos, 1.0);"
        "  output.col = input.col;"
        "  return output;"
        "}";
    const char *psSource =
        "struct PS_IN { float4 pos : SV_POSITION; float4 col : COLOR; };"
        "float4 PSMain(PS_IN input) : SV_Target {"
        "  return input.col;"
        "}";
    HRESULT hr;

    hr = CreateDXGIFactory1((REFIID)&IID_IDXGIFactory4, (void **)&factory);
    if (FAILED(hr)) {
        return hr;
    }

    hr = D3D12CreateDevice(NULL, D3D_FEATURE_LEVEL_12_0, (REFIID)&IID_ID3D12Device, (void **)&g_device);
    if (FAILED(hr)) {
        factory->lpVtbl->Release(factory);
        return hr;
    }

    ZeroMemory(&queueDesc, sizeof(queueDesc));
    queueDesc.Type = D3D12_COMMAND_LIST_TYPE_DIRECT;
    queueDesc.Flags = D3D12_COMMAND_QUEUE_FLAG_NONE;

    hr = g_device->lpVtbl->CreateCommandQueue(g_device, &queueDesc, (REFIID)&IID_ID3D12CommandQueue, (void **)&g_commandQueue);
    if (FAILED(hr)) {
        factory->lpVtbl->Release(factory);
        return hr;
    }

    ZeroMemory(&swapDesc, sizeof(swapDesc));
    swapDesc.BufferCount = FRAMES;
    swapDesc.BufferDesc.Width = WIDTH;
    swapDesc.BufferDesc.Height = HEIGHT;
    swapDesc.BufferDesc.Format = DXGI_FORMAT_R8G8B8A8_UNORM;
    swapDesc.BufferUsage = DXGI_USAGE_RENDER_TARGET_OUTPUT;
    swapDesc.SwapEffect = DXGI_SWAP_EFFECT_FLIP_DISCARD;
    swapDesc.OutputWindow = hWnd;
    swapDesc.SampleDesc.Count = 1;
    swapDesc.Windowed = TRUE;

    hr = factory->lpVtbl->CreateSwapChain(factory, (IUnknown *)g_commandQueue, &swapDesc, &swapChain);
    if (FAILED(hr)) {
        factory->lpVtbl->Release(factory);
        return hr;
    }

    hr = swapChain->lpVtbl->QueryInterface(swapChain, (REFIID)&IID_IDXGISwapChain3, (void **)&g_swapChain);
    swapChain->lpVtbl->Release(swapChain);
    factory->lpVtbl->Release(factory);
    if (FAILED(hr)) {
        return hr;
    }

    g_frameIndex = g_swapChain->lpVtbl->GetCurrentBackBufferIndex(g_swapChain);

    ZeroMemory(&rootSigDesc, sizeof(rootSigDesc));
    rootSigDesc.Flags = D3D12_ROOT_SIGNATURE_FLAG_ALLOW_INPUT_ASSEMBLER_INPUT_LAYOUT;

    hr = D3D12SerializeRootSignature(&rootSigDesc, D3D_ROOT_SIGNATURE_VERSION_1, &rootSigBlob, &rootSigErr);
    if (FAILED(hr)) {
        if (rootSigErr != NULL) {
            rootSigErr->lpVtbl->Release(rootSigErr);
        }
        return hr;
    }
    if (rootSigErr != NULL) {
        rootSigErr->lpVtbl->Release(rootSigErr);
    }

    hr = g_device->lpVtbl->CreateRootSignature(
        g_device,
        0,
        rootSigBlob->lpVtbl->GetBufferPointer(rootSigBlob),
        rootSigBlob->lpVtbl->GetBufferSize(rootSigBlob),
        (REFIID)&IID_ID3D12RootSignature,
        (void **)&g_rootSignature
    );
    rootSigBlob->lpVtbl->Release(rootSigBlob);
    if (FAILED(hr)) {
        return hr;
    }

    hr = CompileShaderFromSource(vsSource, "VSMain", "vs_5_0", &vsBlob);
    if (FAILED(hr)) {
        return hr;
    }

    hr = CompileShaderFromSource(psSource, "PSMain", "ps_5_0", &psBlob);
    if (FAILED(hr)) {
        vsBlob->lpVtbl->Release(vsBlob);
        return hr;
    }

    ZeroMemory(&psoDesc, sizeof(psoDesc));
    psoDesc.InputLayout.pInputElementDescs = layout;
    psoDesc.InputLayout.NumElements = (UINT)(sizeof(layout) / sizeof(layout[0]));
    psoDesc.pRootSignature = g_rootSignature;
    psoDesc.VS.pShaderBytecode = vsBlob->lpVtbl->GetBufferPointer(vsBlob);
    psoDesc.VS.BytecodeLength = vsBlob->lpVtbl->GetBufferSize(vsBlob);
    psoDesc.PS.pShaderBytecode = psBlob->lpVtbl->GetBufferPointer(psBlob);
    psoDesc.PS.BytecodeLength = psBlob->lpVtbl->GetBufferSize(psBlob);
    psoDesc.RasterizerState.FillMode = D3D12_FILL_MODE_SOLID;
    psoDesc.RasterizerState.CullMode = D3D12_CULL_MODE_BACK;
    psoDesc.RasterizerState.FrontCounterClockwise = FALSE;
    psoDesc.RasterizerState.DepthBias = D3D12_DEFAULT_DEPTH_BIAS;
    psoDesc.RasterizerState.DepthBiasClamp = D3D12_DEFAULT_DEPTH_BIAS_CLAMP;
    psoDesc.RasterizerState.SlopeScaledDepthBias = D3D12_DEFAULT_SLOPE_SCALED_DEPTH_BIAS;
    psoDesc.RasterizerState.DepthClipEnable = TRUE;
    psoDesc.RasterizerState.MultisampleEnable = FALSE;
    psoDesc.RasterizerState.AntialiasedLineEnable = FALSE;
    psoDesc.RasterizerState.ForcedSampleCount = 0;
    psoDesc.RasterizerState.ConservativeRaster = D3D12_CONSERVATIVE_RASTERIZATION_MODE_OFF;
    psoDesc.BlendState.AlphaToCoverageEnable = FALSE;
    psoDesc.BlendState.IndependentBlendEnable = FALSE;
    psoDesc.BlendState.RenderTarget[0].BlendEnable = FALSE;
    psoDesc.BlendState.RenderTarget[0].LogicOpEnable = FALSE;
    psoDesc.BlendState.RenderTarget[0].SrcBlend = D3D12_BLEND_ONE;
    psoDesc.BlendState.RenderTarget[0].DestBlend = D3D12_BLEND_ZERO;
    psoDesc.BlendState.RenderTarget[0].BlendOp = D3D12_BLEND_OP_ADD;
    psoDesc.BlendState.RenderTarget[0].SrcBlendAlpha = D3D12_BLEND_ONE;
    psoDesc.BlendState.RenderTarget[0].DestBlendAlpha = D3D12_BLEND_ZERO;
    psoDesc.BlendState.RenderTarget[0].BlendOpAlpha = D3D12_BLEND_OP_ADD;
    psoDesc.BlendState.RenderTarget[0].LogicOp = D3D12_LOGIC_OP_NOOP;
    psoDesc.BlendState.RenderTarget[0].RenderTargetWriteMask = D3D12_COLOR_WRITE_ENABLE_ALL;
    psoDesc.SampleMask = UINT_MAX;
    psoDesc.PrimitiveTopologyType = D3D12_PRIMITIVE_TOPOLOGY_TYPE_TRIANGLE;
    psoDesc.NumRenderTargets = 1;
    psoDesc.RTVFormats[0] = DXGI_FORMAT_R8G8B8A8_UNORM;
    psoDesc.SampleDesc.Count = 1;
    psoDesc.SampleDesc.Quality = 0;

    hr = g_device->lpVtbl->CreateGraphicsPipelineState(g_device, &psoDesc, (REFIID)&IID_ID3D12PipelineState, (void **)&g_pso);
    vsBlob->lpVtbl->Release(vsBlob);
    psBlob->lpVtbl->Release(psBlob);
    if (FAILED(hr)) {
        return hr;
    }

    ZeroMemory(&rtvHeapDesc, sizeof(rtvHeapDesc));
    rtvHeapDesc.NumDescriptors = FRAMES;
    rtvHeapDesc.Type = D3D12_DESCRIPTOR_HEAP_TYPE_RTV;
    rtvHeapDesc.Flags = D3D12_DESCRIPTOR_HEAP_FLAG_NONE;

    hr = g_device->lpVtbl->CreateDescriptorHeap(g_device, &rtvHeapDesc, (REFIID)&IID_ID3D12DescriptorHeap, (void **)&g_descriptorHeap);
    if (FAILED(hr)) {
        return hr;
    }

    rtvDescriptorSize = g_device->lpVtbl->GetDescriptorHandleIncrementSize(g_device, D3D12_DESCRIPTOR_HEAP_TYPE_RTV);
    g_descriptorHeap->lpVtbl->GetCPUDescriptorHandleForHeapStart(g_descriptorHeap, &rtvHandle);

    for (i = 0; i < FRAMES; i++) {
        hr = g_swapChain->lpVtbl->GetBuffer(g_swapChain, i, (REFIID)&IID_ID3D12Resource, (void **)&g_renderTargets[i]);
        if (FAILED(hr)) {
            return hr;
        }
        g_device->lpVtbl->CreateRenderTargetView(g_device, g_renderTargets[i], NULL, rtvHandle);
        rtvHandle.ptr += rtvDescriptorSize;
    }

    hr = g_device->lpVtbl->CreateCommandAllocator(
        g_device,
        D3D12_COMMAND_LIST_TYPE_DIRECT,
        (REFIID)&IID_ID3D12CommandAllocator,
        (void **)&g_commandAllocator
    );
    if (FAILED(hr)) {
        return hr;
    }

    hr = g_device->lpVtbl->CreateCommandList(
        g_device,
        0,
        D3D12_COMMAND_LIST_TYPE_DIRECT,
        g_commandAllocator,
        g_pso,
        (REFIID)&IID_ID3D12GraphicsCommandList,
        (void **)&g_commandList
    );
    if (FAILED(hr)) {
        return hr;
    }

    g_commandList->lpVtbl->Close(g_commandList);

    ZeroMemory(&heapProps, sizeof(heapProps));
    heapProps.Type = D3D12_HEAP_TYPE_UPLOAD;
    heapProps.CPUPageProperty = D3D12_CPU_PAGE_PROPERTY_UNKNOWN;
    heapProps.MemoryPoolPreference = D3D12_MEMORY_POOL_UNKNOWN;
    heapProps.CreationNodeMask = 1;
    heapProps.VisibleNodeMask = 1;

    ZeroMemory(&resourceDesc, sizeof(resourceDesc));
    resourceDesc.Dimension = D3D12_RESOURCE_DIMENSION_BUFFER;
    resourceDesc.Alignment = 0;
    resourceDesc.Width = sizeof(vertices);
    resourceDesc.Height = 1;
    resourceDesc.DepthOrArraySize = 1;
    resourceDesc.MipLevels = 1;
    resourceDesc.Format = DXGI_FORMAT_UNKNOWN;
    resourceDesc.SampleDesc.Count = 1;
    resourceDesc.SampleDesc.Quality = 0;
    resourceDesc.Layout = D3D12_TEXTURE_LAYOUT_ROW_MAJOR;
    resourceDesc.Flags = D3D12_RESOURCE_FLAG_NONE;

    hr = g_device->lpVtbl->CreateCommittedResource(
        g_device,
        &heapProps,
        D3D12_HEAP_FLAG_NONE,
        &resourceDesc,
        D3D12_RESOURCE_STATE_GENERIC_READ,
        NULL,
        (REFIID)&IID_ID3D12Resource,
        (void **)&g_vertexBuffer
    );
    if (FAILED(hr)) {
        return hr;
    }

    hr = g_vertexBuffer->lpVtbl->Map(g_vertexBuffer, 0, NULL, &mapped);
    if (FAILED(hr)) {
        return hr;
    }

    memcpy(mapped, vertices, sizeof(vertices));
    g_vertexBuffer->lpVtbl->Unmap(g_vertexBuffer, 0, NULL);

    vertexView->BufferLocation = g_vertexBuffer->lpVtbl->GetGPUVirtualAddress(g_vertexBuffer);
    vertexView->SizeInBytes = sizeof(vertices);
    vertexView->StrideInBytes = sizeof(VERTEX);

    viewport->TopLeftX = 0.0f;
    viewport->TopLeftY = 0.0f;
    viewport->Width = (float)WIDTH;
    viewport->Height = (float)HEIGHT;
    viewport->MinDepth = 0.0f;
    viewport->MaxDepth = 1.0f;

    scissorRect->left = 0;
    scissorRect->top = 0;
    scissorRect->right = WIDTH;
    scissorRect->bottom = HEIGHT;

    hr = g_device->lpVtbl->CreateFence(g_device, 0, D3D12_FENCE_FLAG_NONE, (REFIID)&IID_ID3D12Fence, (void **)&g_fence);
    if (FAILED(hr)) {
        return hr;
    }

    g_fenceValue = 1;
    g_fenceEvent = CreateEventA(NULL, FALSE, FALSE, NULL);
    if (g_fenceEvent == NULL) {
        return E_FAIL;
    }

    return S_OK;
}

static void PopulateCommandList(const D3D12_VERTEX_BUFFER_VIEW *vertexView, const D3D12_VIEWPORT *viewport, const D3D12_RECT *scissorRect) {
    D3D12_RESOURCE_BARRIER barrier;
    D3D12_CPU_DESCRIPTOR_HANDLE rtvHandle;
    UINT rtvDescriptorSize;
    FLOAT clearColor[4] = { 1.0f, 1.0f, 1.0f, 1.0f };
    ID3D12CommandList *commandLists[] = { (ID3D12CommandList *)g_commandList };

    g_commandAllocator->lpVtbl->Reset(g_commandAllocator);
    g_commandList->lpVtbl->Reset(g_commandList, g_commandAllocator, g_pso);

    g_commandList->lpVtbl->SetGraphicsRootSignature(g_commandList, g_rootSignature);
    g_commandList->lpVtbl->RSSetViewports(g_commandList, 1, viewport);
    g_commandList->lpVtbl->RSSetScissorRects(g_commandList, 1, scissorRect);

    ZeroMemory(&barrier, sizeof(barrier));
    barrier.Type = D3D12_RESOURCE_BARRIER_TYPE_TRANSITION;
    barrier.Flags = D3D12_RESOURCE_BARRIER_FLAG_NONE;
    barrier.Transition.pResource = g_renderTargets[g_frameIndex];
    barrier.Transition.Subresource = D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES;
    barrier.Transition.StateBefore = D3D12_RESOURCE_STATE_PRESENT;
    barrier.Transition.StateAfter = D3D12_RESOURCE_STATE_RENDER_TARGET;
    g_commandList->lpVtbl->ResourceBarrier(g_commandList, 1, &barrier);

    g_descriptorHeap->lpVtbl->GetCPUDescriptorHandleForHeapStart(g_descriptorHeap, &rtvHandle);
    rtvDescriptorSize = g_device->lpVtbl->GetDescriptorHandleIncrementSize(g_device, D3D12_DESCRIPTOR_HEAP_TYPE_RTV);
    rtvHandle.ptr += ((SIZE_T)g_frameIndex * rtvDescriptorSize);

    g_commandList->lpVtbl->OMSetRenderTargets(g_commandList, 1, &rtvHandle, TRUE, NULL);
    g_commandList->lpVtbl->ClearRenderTargetView(g_commandList, rtvHandle, clearColor, 0, NULL);
    g_commandList->lpVtbl->IASetPrimitiveTopology(g_commandList, D3D_PRIMITIVE_TOPOLOGY_TRIANGLELIST);
    g_commandList->lpVtbl->IASetVertexBuffers(g_commandList, 0, 1, vertexView);
    g_commandList->lpVtbl->DrawInstanced(g_commandList, 3, 1, 0, 0);

    barrier.Transition.StateBefore = D3D12_RESOURCE_STATE_RENDER_TARGET;
    barrier.Transition.StateAfter = D3D12_RESOURCE_STATE_PRESENT;
    g_commandList->lpVtbl->ResourceBarrier(g_commandList, 1, &barrier);

    g_commandList->lpVtbl->Close(g_commandList);
    g_commandQueue->lpVtbl->ExecuteCommandLists(g_commandQueue, 1, commandLists);
}

static void WaitForPreviousFrame(void) {
    UINT64 fenceToWaitFor = g_fenceValue;

    g_commandQueue->lpVtbl->Signal(g_commandQueue, g_fence, fenceToWaitFor);
    g_fenceValue++;

    if (g_fence->lpVtbl->GetCompletedValue(g_fence) < fenceToWaitFor) {
        g_fence->lpVtbl->SetEventOnCompletion(g_fence, fenceToWaitFor, g_fenceEvent);
        WaitForSingleObject(g_fenceEvent, INFINITE);
    }

    g_frameIndex = g_swapChain->lpVtbl->GetCurrentBackBufferIndex(g_swapChain);
}

static void CleanupD3D12(void) {
    UINT i;

    if (g_fenceEvent != NULL) {
        CloseHandle(g_fenceEvent);
        g_fenceEvent = NULL;
    }

    if (g_vertexBuffer != NULL) {
        g_vertexBuffer->lpVtbl->Release(g_vertexBuffer);
        g_vertexBuffer = NULL;
    }

    for (i = 0; i < FRAMES; i++) {
        if (g_renderTargets[i] != NULL) {
            g_renderTargets[i]->lpVtbl->Release(g_renderTargets[i]);
            g_renderTargets[i] = NULL;
        }
    }

    if (g_commandAllocator != NULL) {
        g_commandAllocator->lpVtbl->Release(g_commandAllocator);
        g_commandAllocator = NULL;
    }
    if (g_commandQueue != NULL) {
        g_commandQueue->lpVtbl->Release(g_commandQueue);
        g_commandQueue = NULL;
    }
    if (g_descriptorHeap != NULL) {
        g_descriptorHeap->lpVtbl->Release(g_descriptorHeap);
        g_descriptorHeap = NULL;
    }
    if (g_commandList != NULL) {
        g_commandList->lpVtbl->Release(g_commandList);
        g_commandList = NULL;
    }
    if (g_pso != NULL) {
        g_pso->lpVtbl->Release(g_pso);
        g_pso = NULL;
    }
    if (g_fence != NULL) {
        g_fence->lpVtbl->Release(g_fence);
        g_fence = NULL;
    }
    if (g_rootSignature != NULL) {
        g_rootSignature->lpVtbl->Release(g_rootSignature);
        g_rootSignature = NULL;
    }
    if (g_swapChain != NULL) {
        g_swapChain->lpVtbl->Release(g_swapChain);
        g_swapChain = NULL;
    }
    if (g_device != NULL) {
        g_device->lpVtbl->Release(g_device);
        g_device = NULL;
    }
}
