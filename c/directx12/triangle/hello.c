// forked from https://www.shadertoy.com/view/wtB3RG

#include <tchar.h>
#include <windows.h>
#include <d3d12.h>
#include <dxgi1_4.h>
#include <d3dcompiler.h>

#define WIDTH 640
#define HEIGHT 480
#define FRAMES 2

typedef struct STRUCT_VERTEX
{
    float position[3];
    float color[4];
} VERTEX;

IDXGISwapChain3*           g_swapChain;
ID3D12Device*              g_device;
ID3D12Resource*            g_renderTarget[FRAMES];
ID3D12CommandAllocator*    g_commandAllocator;
ID3D12CommandQueue*        g_commandQueue;
ID3D12DescriptorHeap*      g_descriptorHeap;
ID3D12PipelineState*       g_pso;
ID3D12GraphicsCommandList* g_commandList;
ID3D12RootSignature*       g_rootSignature;
HANDLE                     g_fenceEvent;
ID3D12Fence*               g_fence;
UINT64                     g_fenceValue;
UINT                       g_frameIndex;
ID3D12Resource*            buffer;

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
    else
    {
        return DefWindowProc(hWnd, uMsg, wParam, lParam);
    }
}

int WINAPI WinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, LPSTR lpCmdLine, int nCmdShow)
{
    int exit = 0;
    MSG msg;
    WNDCLASS win;
    ZeroMemory(&win, sizeof(WNDCLASS));
    win.style = CS_OWNDC | CS_HREDRAW | CS_VREDRAW;
    win.lpfnWndProc = WindowProc;
    win.hInstance = 0;
    win.lpszClassName = "helloWorld";
    win.hbrBackground = (HBRUSH)(COLOR_WINDOW + 1);
    RegisterClass(&win);

    HWND hWnd = CreateWindowEx(0, win.lpszClassName, "Hello, World!", WS_VISIBLE | WS_OVERLAPPEDWINDOW, 0, 0, WIDTH, HEIGHT, 0, 0, 0, 0);
    HDC hdc = GetDC(hWnd);
    IDXGIFactory4 *pFactory;
    CreateDXGIFactory1((REFIID)&IID_IDXGIFactory4, (LPVOID *)(&pFactory));
    D3D12CreateDevice(NULL, D3D_FEATURE_LEVEL_12_0, (REFIID)&IID_ID3D12Device, (LPVOID *)(&g_device));
    D3D12_COMMAND_QUEUE_DESC queueDesc = {
        D3D12_COMMAND_LIST_TYPE_DIRECT, 
        0, 
        D3D12_COMMAND_QUEUE_FLAG_NONE, 
        0
    };
    g_device->lpVtbl->CreateCommandQueue(g_device, &queueDesc, (REFIID)&IID_ID3D12CommandQueue, (LPVOID *)(&g_commandQueue));
    DXGI_SWAP_CHAIN_DESC descSwapChain = {
        (DXGI_MODE_DESC){
            WIDTH, 
            HEIGHT, 
            {0, 0}, 
            DXGI_FORMAT_R8G8B8A8_UNORM, 
            0, 
            0
        }, 
        (DXGI_SAMPLE_DESC){1, 0}, 
        1L << (1 + 4), 
        FRAMES, 
        hWnd, 
        1, 
        3, 
        0
    };
    IDXGISwapChain *SwapChain;
    pFactory->lpVtbl->CreateSwapChain(pFactory, (IUnknown *)g_commandQueue, &descSwapChain, &SwapChain);
    SwapChain->lpVtbl->QueryInterface(SwapChain, (REFIID)&IID_IDXGISwapChain3, (LPVOID *)(&g_swapChain));
    SwapChain->lpVtbl->Release(SwapChain);
    D3D12_INPUT_ELEMENT_DESC layout[] = {
        { "POSITION", 0, DXGI_FORMAT_R32G32B32_FLOAT,    0,  0, D3D12_INPUT_CLASSIFICATION_PER_VERTEX_DATA, 0},
        { "COLOR",    0, DXGI_FORMAT_R32G32B32A32_FLOAT, 0, 12, D3D12_INPUT_CLASSIFICATION_PER_VERTEX_DATA, 0},
    };
    ID3DBlob *blob;
    D3D12_ROOT_PARAMETER timeParam;
    ZeroMemory(&timeParam, sizeof(timeParam));
    timeParam.ShaderVisibility = D3D12_SHADER_VISIBILITY_PIXEL;
    timeParam.ParameterType = D3D12_ROOT_PARAMETER_TYPE_32BIT_CONSTANTS;
    timeParam.Constants = (D3D12_ROOT_CONSTANTS){0, 0, 1};
    D3D12_ROOT_SIGNATURE_DESC descRootSignature = {
        1, 
        &timeParam, 
        0, 
        NULL, 
        D3D12_ROOT_SIGNATURE_FLAG_ALLOW_INPUT_ASSEMBLER_INPUT_LAYOUT
    };
    D3D12SerializeRootSignature(&descRootSignature, D3D_ROOT_SIGNATURE_VERSION_1, &blob, 0);
    g_device->lpVtbl->CreateRootSignature(g_device, 0, blob->lpVtbl->GetBufferPointer(blob), blob->lpVtbl->GetBufferSize(blob), (REFIID)&IID_ID3D12RootSignature, (LPVOID *)(&g_rootSignature));
    D3D12_RASTERIZER_DESC rasterizer = {
        D3D12_FILL_MODE_SOLID, 
        D3D12_CULL_MODE_BACK, 
        0, 
        D3D12_DEFAULT_DEPTH_BIAS, 
        D3D12_DEFAULT_DEPTH_BIAS_CLAMP, 
        0.0f, 
        1, 
        0, 
        0, 
        0, 
        0
    };
    D3D12_BLEND_DESC blendstate = {
        0, 
        0, 
        {
            0, 
            0, 
            1, 
            0, 
            D3D12_BLEND_OP_ADD, 
            1, 
            0, 
            D3D12_BLEND_OP_ADD, 
            D3D12_LOGIC_OP_NOOP, 
            D3D12_COLOR_WRITE_ENABLE_ALL
        }
    };
    static D3D12_GRAPHICS_PIPELINE_STATE_DESC pDesc;
    pDesc.pRootSignature = g_rootSignature;
    
    ID3DBlob* vertexShader;
    ID3DBlob* pixelShader;

    UINT compileFlags = 0;

    D3DCompileFromFile(L"hello.hlsl", NULL, NULL, "VSMain", "vs_5_0", compileFlags, 0, &vertexShader, NULL);
    D3DCompileFromFile(L"hello.hlsl", NULL, NULL, "PSMain", "ps_5_0", compileFlags, 0, &pixelShader, NULL);
    
    pDesc.VS.pShaderBytecode = vertexShader->lpVtbl->GetBufferPointer(vertexShader);
    pDesc.VS.BytecodeLength  = vertexShader->lpVtbl->GetBufferSize(vertexShader);
    
    pDesc.PS.pShaderBytecode = pixelShader->lpVtbl->GetBufferPointer(pixelShader);
    pDesc.PS.BytecodeLength  = pixelShader->lpVtbl->GetBufferSize(pixelShader);

    pDesc.InputLayout = (D3D12_INPUT_LAYOUT_DESC){layout, _countof(layout)};
    pDesc.RasterizerState = rasterizer;
    pDesc.BlendState = blendstate;
    pDesc.DepthStencilState = (D3D12_DEPTH_STENCIL_DESC){0, 0, 0, 0, 0, 0, 0, 0};
    pDesc.SampleMask = UINT_MAX;
    pDesc.PrimitiveTopologyType = D3D12_PRIMITIVE_TOPOLOGY_TYPE_TRIANGLE;
    pDesc.NumRenderTargets = 1;
    pDesc.RTVFormats[0] = DXGI_FORMAT_R8G8B8A8_UNORM;
    pDesc.SampleDesc.Count = 1;
    g_device->lpVtbl->CreateGraphicsPipelineState(g_device, &pDesc, (REFIID)&IID_ID3D12PipelineState, (LPVOID *)(&g_pso));
    static D3D12_DESCRIPTOR_HEAP_DESC descHeap = {
        D3D12_DESCRIPTOR_HEAP_TYPE_RTV, 
        FRAMES, 
        D3D12_DESCRIPTOR_HEAP_FLAG_NONE, 
        0
    };
    g_device->lpVtbl->CreateDescriptorHeap(g_device, &descHeap, (REFIID)&IID_ID3D12DescriptorHeap, (LPVOID *)(&g_descriptorHeap));
    UINT mrtvDescriptorIncrSize = g_device->lpVtbl->GetDescriptorHandleIncrementSize(g_device, D3D12_DESCRIPTOR_HEAP_TYPE_RTV);
    D3D12_CPU_DESCRIPTOR_HANDLE rtvHandle;
    ((void(__stdcall *)(ID3D12DescriptorHeap *, D3D12_CPU_DESCRIPTOR_HANDLE *))g_descriptorHeap->lpVtbl->GetCPUDescriptorHandleForHeapStart)(g_descriptorHeap, &rtvHandle);
    for (UINT i = 0; i < FRAMES; i++)
    {
        g_swapChain->lpVtbl->GetBuffer(g_swapChain, i, (REFIID)&IID_ID3D12Resource, (LPVOID *)(&g_renderTarget[i]));
        g_device->lpVtbl->CreateRenderTargetView(g_device, g_renderTarget[i], NULL, rtvHandle);
        rtvHandle.ptr += mrtvDescriptorIncrSize;
    }
    g_device->lpVtbl->CreateCommandAllocator(g_device, D3D12_COMMAND_LIST_TYPE_DIRECT, (REFIID)&IID_ID3D12CommandAllocator, (LPVOID *)(&g_commandAllocator));
    g_device->lpVtbl->CreateCommandList(g_device, 0, D3D12_COMMAND_LIST_TYPE_DIRECT, g_commandAllocator, g_pso, (REFIID)&IID_ID3D12CommandList, (LPVOID *)(&g_commandList));
    D3D12_VIEWPORT mViewport = {0.0f, 0.0f, (float)(WIDTH), (float)(HEIGHT), 0.0f, 1.0f};
    D3D12_RECT mRectScissor = {0, 0, (LONG)(WIDTH), (LONG)(HEIGHT)};
    VERTEX vertices[] = {
        { { 0.0f,  0.5f, 0.0f}, {1.0f, 0.0f, 0.0f, 1.0f}},
        { { 0.5f, -0.5f, 0.0f}, {0.0f, 1.0f, 0.0f, 1.0f}},
        { {-0.5f, -0.5f, 0.0f}, {0.0f, 0.0f, 1.0f, 1.0f}}
    };
    static D3D12_HEAP_PROPERTIES heapProperties = {
        D3D12_HEAP_TYPE_UPLOAD, 
        D3D12_CPU_PAGE_PROPERTY_UNKNOWN, 
        D3D12_MEMORY_POOL_UNKNOWN, 
        1, 
        1
    };
    static D3D12_RESOURCE_DESC VertexBufferDesc = {
        D3D12_RESOURCE_DIMENSION_BUFFER, 
        0, 
        _countof(vertices) * sizeof(VERTEX), 
        1, 
        1, 
        1, 
        DXGI_FORMAT_UNKNOWN, 
        {1, 0}, 
        1, 
        0
    };
    g_device->lpVtbl->CreateCommittedResource(
        g_device, 
        &heapProperties, 
        0, 
        &VertexBufferDesc, 
        D3D12_RESOURCE_STATE_GENERIC_READ, 
        NULL, 
        (REFIID)&IID_ID3D12Resource, 
        (LPVOID *)(&buffer)
    );
    float *data;
    buffer->lpVtbl->Map(buffer, 0, NULL, (void **)(&data));
    memcpy(data, vertices, sizeof(vertices));
    buffer->lpVtbl->Unmap(buffer, 0, NULL);
    D3D12_VERTEX_BUFFER_VIEW mDescViewBufVert = {
        buffer->lpVtbl->GetGPUVirtualAddress(buffer), 
        sizeof(vertices), 
        sizeof(VERTEX)
    };
    g_commandList->lpVtbl->Close(g_commandList);
    g_device->lpVtbl->CreateFence(g_device, 0, D3D12_FENCE_FLAG_NONE, (REFIID)&IID_ID3D12Fence, (LPVOID *)(&g_fence));
    g_fenceValue = 1;
    g_fenceEvent = CreateEventEx(NULL, FALSE, FALSE, EVENT_ALL_ACCESS);
    while (!exit)
    {
        while (PeekMessage(&msg, 0, 0, 0, PM_REMOVE))
        {
            if (msg.message == WM_QUIT)
                exit = 1;
            TranslateMessage(&msg);
            DispatchMessage(&msg);
        }
        g_commandAllocator->lpVtbl->Reset(g_commandAllocator);
        g_commandList->lpVtbl->Reset(g_commandList, g_commandAllocator, g_pso);
        g_commandList->lpVtbl->SetGraphicsRootSignature(g_commandList, g_rootSignature);
        float timer = GetTickCount() * 0.001f;
        g_commandList->lpVtbl->SetGraphicsRoot32BitConstants(g_commandList, 0, 1, &timer, 0);
        g_commandList->lpVtbl->RSSetViewports(g_commandList, 1, &mViewport);
        g_commandList->lpVtbl->RSSetScissorRects(g_commandList, 1, &mRectScissor);
        D3D12_RESOURCE_BARRIER barrierRTAsTexture = {
            0, 
            0, 
            {
                g_renderTarget[g_frameIndex], 
                D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES, 
                D3D12_RESOURCE_STATE_PRESENT, 
                D3D12_RESOURCE_STATE_RENDER_TARGET
            }
        };
        g_commandList->lpVtbl->ResourceBarrier(g_commandList, 1, &barrierRTAsTexture);
        ((void(__stdcall *)(ID3D12DescriptorHeap *, D3D12_CPU_DESCRIPTOR_HANDLE *))g_descriptorHeap->lpVtbl->GetCPUDescriptorHandleForHeapStart)(g_descriptorHeap, &rtvHandle);
        rtvHandle.ptr += g_frameIndex * mrtvDescriptorIncrSize;
        float clearColor[] = {0.0f, 0.0f, 0.0f, 1.0f};
        g_commandList->lpVtbl->ClearRenderTargetView(g_commandList, rtvHandle, clearColor, 0, NULL);
        g_commandList->lpVtbl->OMSetRenderTargets(g_commandList, 1, &rtvHandle, TRUE, NULL);
        g_commandList->lpVtbl->IASetPrimitiveTopology(g_commandList, D3D_PRIMITIVE_TOPOLOGY_TRIANGLELIST);
        g_commandList->lpVtbl->IASetVertexBuffers(g_commandList, 0, 1, &mDescViewBufVert);
        g_commandList->lpVtbl->DrawInstanced(g_commandList, 3, 1, 0, 0);

        D3D12_RESOURCE_BARRIER barrierRTForPresent = {
            0, 
            0, 
            {
                g_renderTarget[g_frameIndex], 
                D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES, 
                D3D12_RESOURCE_STATE_RENDER_TARGET, 
                D3D12_RESOURCE_STATE_PRESENT
            }
        };
        g_commandList->lpVtbl->ResourceBarrier(g_commandList, 1, &barrierRTForPresent);
        g_commandList->lpVtbl->Close(g_commandList);
        ID3D12CommandList *ppCommandLists[] = {(ID3D12CommandList *)g_commandList};
        g_commandQueue->lpVtbl->ExecuteCommandLists(g_commandQueue, _countof(ppCommandLists), ppCommandLists);
        g_swapChain->lpVtbl->Present(g_swapChain, 0, 0);
        WaitForPreviousFrame();
    }
    WaitForPreviousFrame();
    CloseHandle(g_fenceEvent);

    g_device->lpVtbl->Release(g_device);
    g_swapChain->lpVtbl->Release(g_swapChain);
    buffer->lpVtbl->Release(buffer);
    for (UINT n = 0; n < FRAMES; n++) {
        g_renderTarget[n]->lpVtbl->Release(g_renderTarget[n]);
    }
    g_commandAllocator->lpVtbl->Release(g_commandAllocator);
    g_commandQueue->lpVtbl->Release(g_commandQueue);
    g_descriptorHeap->lpVtbl->Release(g_descriptorHeap);
    g_commandList->lpVtbl->Release(g_commandList);
    g_pso->lpVtbl->Release(g_pso);
    g_fence->lpVtbl->Release(g_fence);
    g_rootSignature->lpVtbl->Release(g_rootSignature);
    
    return 0;
}
