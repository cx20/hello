// =============================================================================
// DirectX Raytracing (DXR) - Triangle Sample
// =============================================================================
// Minimal DXR sample: renders a single triangle using raytracing.
//
// Requirements:
//   - Windows 10 Version 1809+
//   - Visual Studio 2019/2022
//   - Windows SDK 10.0.20348.0+ (for dxcapi.h)
//   - DXR-capable GPU (NVIDIA RTX / AMD RDNA2+) or WARP (software fallback)
//   - dxcompiler.dll and dxil.dll in PATH or exe directory
//
// Build (Developer Command Prompt for VS 2022):
//   cl /EHsc /std:c++17 hello.cpp /link d3d12.lib dxgi.lib dxguid.lib user32.lib ole32.lib /SUBSYSTEM:WINDOWS
//
// Note: dxcompiler.dll is loaded at runtime via DxcCreateInstance.
//       No need to link dxcompiler.lib.
// =============================================================================

#define WIN32_LEAN_AND_MEAN
#define NOMINMAX
#define UNICODE
#define _UNICODE
#include <windows.h>
#include <d3d12.h>
#include <dxgi1_6.h>
#include <dxcapi.h>       // DXC compiler (replaces d3dcompiler.h for lib_6_3+)
#include <DirectXMath.h>
#include <wrl/client.h>

#include <cstdio>
#include <cstdarg>
#include <vector>
#include <string>
#include <stdexcept>

using Microsoft::WRL::ComPtr;
using namespace DirectX;

// =============================================================================
// Constants
// =============================================================================
constexpr UINT WIDTH      = 800;
constexpr UINT HEIGHT     = 600;
constexpr UINT FRAME_COUNT = 2;

// =============================================================================
// Debug output helper - sends formatted string to OutputDebugString (DebugView)
// =============================================================================
static void DebugLog(const char* fmt, ...) {
    char buf[1024];
    va_list args;
    va_start(args, fmt);
    vsnprintf(buf, sizeof(buf), fmt, args);
    va_end(args);
    OutputDebugStringA(buf);
}

// =============================================================================
// Error check macro - logs to DebugView before throwing
// =============================================================================
// Forward declaration for debug message flushing
static void FlushDebugMessages();

#define THROW_IF_FAILED(hr)                                                    \
    do {                                                                       \
        HRESULT _hr = (hr);                                                    \
        if (FAILED(_hr)) {                                                     \
            FlushDebugMessages();                                              \
            char buf[512];                                                     \
            sprintf_s(buf, "[DXR] HRESULT FAILED: 0x%08X at %s:%d\n",         \
                      (unsigned)_hr, __FILE__, __LINE__);                      \
            OutputDebugStringA(buf);                                           \
            throw std::runtime_error(buf);                                     \
        }                                                                      \
    } while (0)

// =============================================================================
// HLSL Shader Code (inline, UTF-16 for DXC)
// =============================================================================
// DXR requires 3 shader types:
//   1. Ray Generation Shader - fires a ray for each pixel
//   2. Closest Hit Shader    - computes color when a ray hits geometry
//   3. Miss Shader           - returns background color when ray hits nothing
// =============================================================================
static const wchar_t* g_shaderCode = LR"(
// UAV output texture
RWTexture2D<float4> gOutput : register(u0);

// Top-Level Acceleration Structure
RaytracingAccelerationStructure gScene : register(t0);

// Camera constant buffer
cbuffer CameraParams : register(b0)
{
    float4x4 viewInverse;
    float4x4 projInverse;
};

// Payload passed between ray generation and hit/miss shaders
struct RayPayload
{
    float4 color;
};

// Triangle hit attributes (barycentric coordinates)
struct TriAttributes
{
    float2 barycentrics;
};

// ---------------------------------------------------------------------------
// Ray Generation Shader
// ---------------------------------------------------------------------------
[shader("raygeneration")]
void RayGen()
{
    uint2 launchIndex = DispatchRaysIndex().xy;
    float2 dims       = float2(DispatchRaysDimensions().xy);

    // Convert pixel coordinates to NDC (-1 to +1)
    float2 d = (((float2)launchIndex + 0.5f) / dims) * 2.0f - 1.0f;

    // Generate ray from camera
    //
    // Matrix convention:
    //   HLSL default = column-major storage.
    //   DirectXMath  = row-major storage.
    //   When DirectXMath data is read as column-major by HLSL, it appears transposed.
    //   This implicit transpose makes mul(M, v) equivalent to DirectXMath's v * M.
    //
    float4 origin    = mul(viewInverse, float4(0, 0, 0, 1));

    // Unproject screen point through inverse projection, then perspective divide
    float4 target    = mul(projInverse, float4(d.x, -d.y, 1, 1));
    target.xyz /= target.w;  // perspective divide: clip space -> view space

    float4 direction = mul(viewInverse, float4(normalize(target.xyz), 0));

    // Define ray
    RayDesc ray;
    ray.Origin    = origin.xyz;
    ray.Direction = direction.xyz;
    ray.TMin      = 0.001f;
    ray.TMax      = 10000.0f;

    // Initialize payload
    RayPayload payload;
    payload.color = float4(0, 0, 0, 1);

    // Trace ray (no face culling - triangle is back-facing from this camera angle)
    TraceRay(
        gScene,
        RAY_FLAG_NONE,
        0xFF,   // instance mask
        0,      // hit group index
        0,      // hit group stride
        0,      // miss shader index
        ray,
        payload
    );

    // Write result
    gOutput[launchIndex] = payload.color;
}

// ---------------------------------------------------------------------------
// Closest Hit Shader
// ---------------------------------------------------------------------------
[shader("closesthit")]
void ClosestHit(inout RayPayload payload, in TriAttributes attribs)
{
    // Interpolate vertex colors using barycentric coordinates
    float3 barycentrics = float3(
        1.0f - attribs.barycentrics.x - attribs.barycentrics.y,
        attribs.barycentrics.x,
        attribs.barycentrics.y
    );

    // Assign R/G/B to each vertex of the triangle
    payload.color = float4(barycentrics, 1.0f);
}

// ---------------------------------------------------------------------------
// Miss Shader
// ---------------------------------------------------------------------------
[shader("miss")]
void Miss(inout RayPayload payload)
{
    // Background color (cornflower blue)
    payload.color = float4(0.392f, 0.584f, 0.929f, 1.0f);
}
)";

// =============================================================================
// Global Variables
// =============================================================================
HWND g_hwnd = nullptr;

// D3D12 core objects
ComPtr<IDXGIFactory6>              g_factory;
ComPtr<ID3D12Device5>              g_device;         // DXR requires ID3D12Device5
ComPtr<ID3D12CommandQueue>         g_commandQueue;
ComPtr<ID3D12CommandAllocator>     g_commandAllocator;
ComPtr<ID3D12GraphicsCommandList4> g_commandList;    // DXR requires CommandList4
ComPtr<IDXGISwapChain3>            g_swapChain;
ComPtr<ID3D12DescriptorHeap>       g_rtvHeap;
ComPtr<ID3D12Resource>             g_renderTargets[FRAME_COUNT];
UINT                               g_rtvDescriptorSize = 0;
UINT                               g_frameIndex = 0;

// Synchronization
ComPtr<ID3D12Fence> g_fence;
UINT64              g_fenceValue = 0;
HANDLE              g_fenceEvent = nullptr;

// DXR-specific objects
ComPtr<ID3D12Resource>        g_vertexBuffer;
ComPtr<ID3D12Resource>        g_bottomLevelAS;   // BLAS
ComPtr<ID3D12Resource>        g_topLevelAS;      // TLAS
ComPtr<ID3D12Resource>        g_instanceBuffer;
ComPtr<ID3D12StateObject>     g_stateObject;     // Raytracing pipeline
ComPtr<ID3D12Resource>        g_outputResource;  // UAV output texture
ComPtr<ID3D12DescriptorHeap>  g_srvUavHeap;
ComPtr<ID3D12RootSignature>   g_globalRootSig;
ComPtr<ID3D12Resource>        g_shaderTable;
ComPtr<ID3D12Resource>        g_cameraBuffer;

// Scratch buffers for BLAS/TLAS build
ComPtr<ID3D12Resource> g_scratchBLAS;
ComPtr<ID3D12Resource> g_scratchTLAS;

// =============================================================================
// Helper Functions
// =============================================================================

// Create an upload heap buffer
ComPtr<ID3D12Resource> CreateUploadBuffer(UINT64 size) {
    ComPtr<ID3D12Resource> buffer;
    D3D12_HEAP_PROPERTIES hp = {};
    hp.Type = D3D12_HEAP_TYPE_UPLOAD;
    D3D12_RESOURCE_DESC rd = {};
    rd.Dimension        = D3D12_RESOURCE_DIMENSION_BUFFER;
    rd.Width            = size;
    rd.Height           = 1;
    rd.DepthOrArraySize = 1;
    rd.MipLevels        = 1;
    rd.SampleDesc.Count = 1;
    rd.Layout           = D3D12_TEXTURE_LAYOUT_ROW_MAJOR;
    rd.Flags            = D3D12_RESOURCE_FLAG_NONE;

    THROW_IF_FAILED(g_device->CreateCommittedResource(
        &hp, D3D12_HEAP_FLAG_NONE, &rd,
        D3D12_RESOURCE_STATE_GENERIC_READ, nullptr,
        IID_PPV_ARGS(&buffer)));
    return buffer;
}

// Create a default heap buffer
ComPtr<ID3D12Resource> CreateDefaultBuffer(
    UINT64 size,
    D3D12_RESOURCE_FLAGS flags = D3D12_RESOURCE_FLAG_NONE,
    D3D12_RESOURCE_STATES initialState = D3D12_RESOURCE_STATE_COMMON)
{
    ComPtr<ID3D12Resource> buffer;
    D3D12_HEAP_PROPERTIES hp = {};
    hp.Type = D3D12_HEAP_TYPE_DEFAULT;
    D3D12_RESOURCE_DESC rd = {};
    rd.Dimension        = D3D12_RESOURCE_DIMENSION_BUFFER;
    rd.Width            = size;
    rd.Height           = 1;
    rd.DepthOrArraySize = 1;
    rd.MipLevels        = 1;
    rd.SampleDesc.Count = 1;
    rd.Layout           = D3D12_TEXTURE_LAYOUT_ROW_MAJOR;
    rd.Flags            = flags;

    THROW_IF_FAILED(g_device->CreateCommittedResource(
        &hp, D3D12_HEAP_FLAG_NONE, &rd,
        initialState, nullptr,
        IID_PPV_ARGS(&buffer)));
    return buffer;
}

// Wait for GPU to complete all pending work
void WaitForGPU() {
    g_fenceValue++;
    THROW_IF_FAILED(g_commandQueue->Signal(g_fence.Get(), g_fenceValue));
    if (g_fence->GetCompletedValue() < g_fenceValue) {
        THROW_IF_FAILED(g_fence->SetEventOnCompletion(g_fenceValue, g_fenceEvent));
        WaitForSingleObject(g_fenceEvent, INFINITE);
    }
}

// Execute command list and wait for completion
void ExecuteAndWait() {
    THROW_IF_FAILED(g_commandList->Close());
    ID3D12CommandList* lists[] = { g_commandList.Get() };
    g_commandQueue->ExecuteCommandLists(1, lists);
    WaitForGPU();
    THROW_IF_FAILED(g_commandAllocator->Reset());
    THROW_IF_FAILED(g_commandList->Reset(g_commandAllocator.Get(), nullptr));
}

// Alignment helper
inline UINT64 Align(UINT64 size, UINT64 alignment) {
    return (size + alignment - 1) & ~(alignment - 1);
}

// =============================================================================
// FlushDebugMessages - Dump D3D12 debug layer messages to DebugView
// =============================================================================
static void FlushDebugMessages() {
    if (!g_device) return;
    ComPtr<ID3D12InfoQueue> infoQueue;
    if (SUCCEEDED(g_device.As(&infoQueue))) {
        UINT64 numMsgs = infoQueue->GetNumStoredMessages();
        for (UINT64 i = 0; i < numMsgs; i++) {
            SIZE_T msgLen = 0;
            infoQueue->GetMessage(i, nullptr, &msgLen);
            std::vector<char> buf(msgLen);
            auto* msg = reinterpret_cast<D3D12_MESSAGE*>(buf.data());
            infoQueue->GetMessage(i, msg, &msgLen);
            DebugLog("[D3D12 %s] %s\n",
                msg->Severity == D3D12_MESSAGE_SEVERITY_ERROR ? "ERROR" :
                msg->Severity == D3D12_MESSAGE_SEVERITY_WARNING ? "WARN" : "INFO",
                msg->pDescription);
        }
        infoQueue->ClearStoredMessages();
    }
}

// =============================================================================
// InitD3D12 - Create device, command queue, swap chain, descriptor heaps
// =============================================================================
void InitD3D12() {
    DebugLog("[DXR] InitD3D12: BEGIN\n");

    // Enable debug layer (always enabled for diagnostics)
    {
        ComPtr<ID3D12Debug> debug;
        if (SUCCEEDED(D3D12GetDebugInterface(IID_PPV_ARGS(&debug)))) {
            debug->EnableDebugLayer();
            DebugLog("[DXR] InitD3D12: Debug layer enabled\n");
        }
    }

    // Create DXGI factory
    THROW_IF_FAILED(CreateDXGIFactory2(0, IID_PPV_ARGS(&g_factory)));
    DebugLog("[DXR] InitD3D12: DXGI factory created\n");

    // Enumerate adapters and find a DXR-capable device
    ComPtr<IDXGIAdapter1> adapter;
    for (UINT i = 0; g_factory->EnumAdapters1(i, &adapter) != DXGI_ERROR_NOT_FOUND; i++) {
        DXGI_ADAPTER_DESC1 desc;
        adapter->GetDesc1(&desc);
        if (desc.Flags & DXGI_ADAPTER_FLAG_SOFTWARE) {
            adapter.Reset();
            continue;
        }

        // Try creating a D3D12 device
        if (SUCCEEDED(D3D12CreateDevice(adapter.Get(), D3D_FEATURE_LEVEL_12_1,
                                         IID_PPV_ARGS(&g_device)))) {
            // Check DXR support
            D3D12_FEATURE_DATA_D3D12_OPTIONS5 opts5 = {};
            if (SUCCEEDED(g_device->CheckFeatureSupport(
                    D3D12_FEATURE_D3D12_OPTIONS5, &opts5, sizeof(opts5)))) {
                if (opts5.RaytracingTier >= D3D12_RAYTRACING_TIER_1_0) {
                    DebugLog("[DXR] InitD3D12: Found DXR-capable adapter: %ls\n", desc.Description);
                    break;
                }
            }
            g_device.Reset();
        }
        adapter.Reset();
    }

    if (!g_device) {
        // Fallback to WARP software adapter
        DebugLog("[DXR] InitD3D12: No DXR GPU found, falling back to WARP\n");
        ComPtr<IDXGIAdapter> warpAdapter;
        THROW_IF_FAILED(g_factory->EnumWarpAdapter(IID_PPV_ARGS(&warpAdapter)));
        THROW_IF_FAILED(D3D12CreateDevice(warpAdapter.Get(), D3D_FEATURE_LEVEL_12_1,
                                           IID_PPV_ARGS(&g_device)));

        // Verify WARP supports DXR
        D3D12_FEATURE_DATA_D3D12_OPTIONS5 warpOpts5 = {};
        if (SUCCEEDED(g_device->CheckFeatureSupport(
                D3D12_FEATURE_D3D12_OPTIONS5, &warpOpts5, sizeof(warpOpts5)))) {
            DebugLog("[DXR] InitD3D12: WARP raytracing tier = %d\n", warpOpts5.RaytracingTier);
            if (warpOpts5.RaytracingTier < D3D12_RAYTRACING_TIER_1_0) {
                throw std::runtime_error("WARP does not support DXR on this system. "
                    "Requires Windows 10 version 2004+ with latest updates.");
            }
        }
    }
    DebugLog("[DXR] InitD3D12: D3D12 device created\n");

    // Create command queue
    D3D12_COMMAND_QUEUE_DESC queueDesc = {};
    queueDesc.Type = D3D12_COMMAND_LIST_TYPE_DIRECT;
    THROW_IF_FAILED(g_device->CreateCommandQueue(&queueDesc, IID_PPV_ARGS(&g_commandQueue)));
    DebugLog("[DXR] InitD3D12: Command queue created\n");

    // Create command allocator and command list
    THROW_IF_FAILED(g_device->CreateCommandAllocator(
        D3D12_COMMAND_LIST_TYPE_DIRECT, IID_PPV_ARGS(&g_commandAllocator)));
    THROW_IF_FAILED(g_device->CreateCommandList(
        0, D3D12_COMMAND_LIST_TYPE_DIRECT, g_commandAllocator.Get(), nullptr,
        IID_PPV_ARGS(&g_commandList)));
    DebugLog("[DXR] InitD3D12: Command allocator & list created\n");

    // Create swap chain
    DXGI_SWAP_CHAIN_DESC1 scDesc = {};
    scDesc.Width       = WIDTH;
    scDesc.Height      = HEIGHT;
    scDesc.Format      = DXGI_FORMAT_R8G8B8A8_UNORM;
    scDesc.BufferUsage = DXGI_USAGE_RENDER_TARGET_OUTPUT;
    scDesc.BufferCount = FRAME_COUNT;
    scDesc.SwapEffect  = DXGI_SWAP_EFFECT_FLIP_DISCARD;
    scDesc.SampleDesc.Count = 1;

    ComPtr<IDXGISwapChain1> swapChain1;
    THROW_IF_FAILED(g_factory->CreateSwapChainForHwnd(
        g_commandQueue.Get(), g_hwnd, &scDesc, nullptr, nullptr, &swapChain1));
    THROW_IF_FAILED(swapChain1.As(&g_swapChain));
    g_frameIndex = g_swapChain->GetCurrentBackBufferIndex();
    DebugLog("[DXR] InitD3D12: Swap chain created (%ux%u)\n", WIDTH, HEIGHT);

    // Create RTV descriptor heap
    D3D12_DESCRIPTOR_HEAP_DESC rtvHeapDesc = {};
    rtvHeapDesc.NumDescriptors = FRAME_COUNT;
    rtvHeapDesc.Type  = D3D12_DESCRIPTOR_HEAP_TYPE_RTV;
    rtvHeapDesc.Flags = D3D12_DESCRIPTOR_HEAP_FLAG_NONE;
    THROW_IF_FAILED(g_device->CreateDescriptorHeap(&rtvHeapDesc, IID_PPV_ARGS(&g_rtvHeap)));
    g_rtvDescriptorSize = g_device->GetDescriptorHandleIncrementSize(D3D12_DESCRIPTOR_HEAP_TYPE_RTV);

    // Create render target views
    D3D12_CPU_DESCRIPTOR_HANDLE rtvHandle = g_rtvHeap->GetCPUDescriptorHandleForHeapStart();
    for (UINT i = 0; i < FRAME_COUNT; i++) {
        THROW_IF_FAILED(g_swapChain->GetBuffer(i, IID_PPV_ARGS(&g_renderTargets[i])));
        g_device->CreateRenderTargetView(g_renderTargets[i].Get(), nullptr, rtvHandle);
        rtvHandle.ptr += g_rtvDescriptorSize;
    }
    DebugLog("[DXR] InitD3D12: RTVs created\n");

    // Create fence
    THROW_IF_FAILED(g_device->CreateFence(0, D3D12_FENCE_FLAG_NONE, IID_PPV_ARGS(&g_fence)));
    g_fenceEvent = CreateEvent(nullptr, FALSE, FALSE, nullptr);
    DebugLog("[DXR] InitD3D12: Fence created\n");

    // Create SRV/UAV/CBV descriptor heap (shader visible)
    D3D12_DESCRIPTOR_HEAP_DESC srvHeapDesc = {};
    srvHeapDesc.NumDescriptors = 3; // UAV(output), SRV(TLAS), CBV(camera)
    srvHeapDesc.Type  = D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV;
    srvHeapDesc.Flags = D3D12_DESCRIPTOR_HEAP_FLAG_SHADER_VISIBLE;
    THROW_IF_FAILED(g_device->CreateDescriptorHeap(&srvHeapDesc, IID_PPV_ARGS(&g_srvUavHeap)));
    DebugLog("[DXR] InitD3D12: SRV/UAV heap created\n");

    DebugLog("[DXR] InitD3D12: DONE\n");
}

// =============================================================================
// CreateVertexBuffer - Define the triangle's 3 vertices
// =============================================================================
void CreateVertexBuffer() {
    DebugLog("[DXR] CreateVertexBuffer: BEGIN\n");

    // Triangle vertices (x, y, z)
    float vertices[] = {
         0.0f,  0.7f, 0.0f,   // top
        -0.7f, -0.7f, 0.0f,   // bottom-left
         0.7f, -0.7f, 0.0f,   // bottom-right
    };

    UINT bufferSize = sizeof(vertices);
    g_vertexBuffer = CreateUploadBuffer(bufferSize);

    void* mapped = nullptr;
    THROW_IF_FAILED(g_vertexBuffer->Map(0, nullptr, &mapped));
    memcpy(mapped, vertices, bufferSize);
    g_vertexBuffer->Unmap(0, nullptr);

    DebugLog("[DXR] CreateVertexBuffer: DONE (3 vertices, %u bytes)\n", bufferSize);
}

// =============================================================================
// BuildAccelerationStructures - Build BLAS and TLAS
// =============================================================================
void BuildAccelerationStructures() {
    DebugLog("[DXR] BuildAccelerationStructures: BEGIN\n");

    // === Bottom-Level Acceleration Structure (BLAS) ===
    // Register geometry (triangle)
    D3D12_RAYTRACING_GEOMETRY_DESC geomDesc = {};
    geomDesc.Type  = D3D12_RAYTRACING_GEOMETRY_TYPE_TRIANGLES;
    geomDesc.Flags = D3D12_RAYTRACING_GEOMETRY_FLAG_OPAQUE;
    geomDesc.Triangles.VertexBuffer.StartAddress  = g_vertexBuffer->GetGPUVirtualAddress();
    geomDesc.Triangles.VertexBuffer.StrideInBytes  = sizeof(float) * 3;
    geomDesc.Triangles.VertexFormat = DXGI_FORMAT_R32G32B32_FLOAT;
    geomDesc.Triangles.VertexCount  = 3;

    // Query BLAS prebuild info
    D3D12_BUILD_RAYTRACING_ACCELERATION_STRUCTURE_INPUTS blasInputs = {};
    blasInputs.Type           = D3D12_RAYTRACING_ACCELERATION_STRUCTURE_TYPE_BOTTOM_LEVEL;
    blasInputs.DescsLayout    = D3D12_ELEMENTS_LAYOUT_ARRAY;
    blasInputs.NumDescs       = 1;
    blasInputs.pGeometryDescs = &geomDesc;
    blasInputs.Flags          = D3D12_RAYTRACING_ACCELERATION_STRUCTURE_BUILD_FLAG_PREFER_FAST_TRACE;

    D3D12_RAYTRACING_ACCELERATION_STRUCTURE_PREBUILD_INFO blasPrebuild = {};
    g_device->GetRaytracingAccelerationStructurePrebuildInfo(&blasInputs, &blasPrebuild);
    DebugLog("[DXR] BuildAccelerationStructures: BLAS result=%llu bytes, scratch=%llu bytes\n",
             blasPrebuild.ResultDataMaxSizeInBytes, blasPrebuild.ScratchDataSizeInBytes);

    // Create BLAS buffer and scratch buffer
    g_bottomLevelAS = CreateDefaultBuffer(
        blasPrebuild.ResultDataMaxSizeInBytes,
        D3D12_RESOURCE_FLAG_ALLOW_UNORDERED_ACCESS,
        D3D12_RESOURCE_STATE_RAYTRACING_ACCELERATION_STRUCTURE);
    g_scratchBLAS = CreateDefaultBuffer(
        blasPrebuild.ScratchDataSizeInBytes,
        D3D12_RESOURCE_FLAG_ALLOW_UNORDERED_ACCESS);

    // Build BLAS
    D3D12_BUILD_RAYTRACING_ACCELERATION_STRUCTURE_DESC blasBuildDesc = {};
    blasBuildDesc.Inputs                           = blasInputs;
    blasBuildDesc.DestAccelerationStructureData     = g_bottomLevelAS->GetGPUVirtualAddress();
    blasBuildDesc.ScratchAccelerationStructureData  = g_scratchBLAS->GetGPUVirtualAddress();
    g_commandList->BuildRaytracingAccelerationStructure(&blasBuildDesc, 0, nullptr);
    DebugLog("[DXR] BuildAccelerationStructures: BLAS build command recorded\n");

    // UAV barrier between BLAS and TLAS builds
    D3D12_RESOURCE_BARRIER uavBarrier = {};
    uavBarrier.Type          = D3D12_RESOURCE_BARRIER_TYPE_UAV;
    uavBarrier.UAV.pResource = g_bottomLevelAS.Get();
    g_commandList->ResourceBarrier(1, &uavBarrier);

    // === Top-Level Acceleration Structure (TLAS) ===
    // Instance descriptor (identity transform = no transformation)
    D3D12_RAYTRACING_INSTANCE_DESC instanceDesc = {};
    instanceDesc.Transform[0][0] = 1.0f;
    instanceDesc.Transform[1][1] = 1.0f;
    instanceDesc.Transform[2][2] = 1.0f;
    instanceDesc.InstanceMask = 0xFF;
    instanceDesc.AccelerationStructure = g_bottomLevelAS->GetGPUVirtualAddress();

    g_instanceBuffer = CreateUploadBuffer(sizeof(instanceDesc));
    void* mapped = nullptr;
    THROW_IF_FAILED(g_instanceBuffer->Map(0, nullptr, &mapped));
    memcpy(mapped, &instanceDesc, sizeof(instanceDesc));
    g_instanceBuffer->Unmap(0, nullptr);

    // Query TLAS prebuild info
    D3D12_BUILD_RAYTRACING_ACCELERATION_STRUCTURE_INPUTS tlasInputs = {};
    tlasInputs.Type          = D3D12_RAYTRACING_ACCELERATION_STRUCTURE_TYPE_TOP_LEVEL;
    tlasInputs.DescsLayout   = D3D12_ELEMENTS_LAYOUT_ARRAY;
    tlasInputs.NumDescs      = 1;
    tlasInputs.InstanceDescs = g_instanceBuffer->GetGPUVirtualAddress();
    tlasInputs.Flags         = D3D12_RAYTRACING_ACCELERATION_STRUCTURE_BUILD_FLAG_PREFER_FAST_TRACE;

    D3D12_RAYTRACING_ACCELERATION_STRUCTURE_PREBUILD_INFO tlasPrebuild = {};
    g_device->GetRaytracingAccelerationStructurePrebuildInfo(&tlasInputs, &tlasPrebuild);
    DebugLog("[DXR] BuildAccelerationStructures: TLAS result=%llu bytes, scratch=%llu bytes\n",
             tlasPrebuild.ResultDataMaxSizeInBytes, tlasPrebuild.ScratchDataSizeInBytes);

    // Create TLAS buffer and scratch buffer
    g_topLevelAS = CreateDefaultBuffer(
        tlasPrebuild.ResultDataMaxSizeInBytes,
        D3D12_RESOURCE_FLAG_ALLOW_UNORDERED_ACCESS,
        D3D12_RESOURCE_STATE_RAYTRACING_ACCELERATION_STRUCTURE);
    g_scratchTLAS = CreateDefaultBuffer(
        tlasPrebuild.ScratchDataSizeInBytes,
        D3D12_RESOURCE_FLAG_ALLOW_UNORDERED_ACCESS);

    // Build TLAS
    D3D12_BUILD_RAYTRACING_ACCELERATION_STRUCTURE_DESC tlasBuildDesc = {};
    tlasBuildDesc.Inputs                           = tlasInputs;
    tlasBuildDesc.DestAccelerationStructureData     = g_topLevelAS->GetGPUVirtualAddress();
    tlasBuildDesc.ScratchAccelerationStructureData  = g_scratchTLAS->GetGPUVirtualAddress();
    g_commandList->BuildRaytracingAccelerationStructure(&tlasBuildDesc, 0, nullptr);
    DebugLog("[DXR] BuildAccelerationStructures: TLAS build command recorded\n");

    // Execute and wait for GPU to finish
    ExecuteAndWait();

    DebugLog("[DXR] BuildAccelerationStructures: DONE\n");
}

// =============================================================================
// CreateRootSignature - Define global root signature for DXR pipeline
// =============================================================================
void CreateRootSignature() {
    DebugLog("[DXR] CreateRootSignature: BEGIN\n");

    // Global root signature layout:
    //   [0] UAV  - output texture (u0)  via descriptor table
    //   [1] SRV  - acceleration structure (t0)  via root SRV
    //   [2] CBV  - camera parameters (b0)  via root CBV

    D3D12_DESCRIPTOR_RANGE ranges[1] = {};
    ranges[0].RangeType          = D3D12_DESCRIPTOR_RANGE_TYPE_UAV;
    ranges[0].NumDescriptors     = 1;
    ranges[0].BaseShaderRegister = 0;

    D3D12_ROOT_PARAMETER params[3] = {};

    // UAV (descriptor table)
    params[0].ParameterType    = D3D12_ROOT_PARAMETER_TYPE_DESCRIPTOR_TABLE;
    params[0].DescriptorTable.NumDescriptorRanges = 1;
    params[0].DescriptorTable.pDescriptorRanges   = ranges;

    // SRV (root SRV for acceleration structure)
    params[1].ParameterType             = D3D12_ROOT_PARAMETER_TYPE_SRV;
    params[1].Descriptor.ShaderRegister = 0;

    // CBV (root CBV for camera)
    params[2].ParameterType             = D3D12_ROOT_PARAMETER_TYPE_CBV;
    params[2].Descriptor.ShaderRegister = 0;

    D3D12_ROOT_SIGNATURE_DESC rootSigDesc = {};
    rootSigDesc.NumParameters = _countof(params);
    rootSigDesc.pParameters   = params;

    ComPtr<ID3DBlob> blob, error;
    THROW_IF_FAILED(D3D12SerializeRootSignature(
        &rootSigDesc, D3D_ROOT_SIGNATURE_VERSION_1, &blob, &error));
    THROW_IF_FAILED(g_device->CreateRootSignature(
        0, blob->GetBufferPointer(), blob->GetBufferSize(),
        IID_PPV_ARGS(&g_globalRootSig)));

    DebugLog("[DXR] CreateRootSignature: DONE\n");
}

// =============================================================================
// CreateRaytracingPipeline - Compile shaders with DXC and create state object
// =============================================================================
void CreateRaytracingPipeline() {
    DebugLog("[DXR] CreateRaytracingPipeline: BEGIN\n");

    // --- Compile HLSL using DXC (lib_6_3 target) ---
    // DXC is required because the legacy FXC compiler (D3DCompile / d3dcompiler_47.dll)
    // does not support raytracing library targets (lib_6_3+).
    DebugLog("[DXR] CreateRaytracingPipeline: Creating DXC compiler instance...\n");

    // Dynamically load dxcompiler.dll (no need to link dxcompiler.lib)
    HMODULE dxcModule = LoadLibraryW(L"dxcompiler.dll");
    if (!dxcModule) {
        DebugLog("[DXR] CreateRaytracingPipeline: ERROR - Failed to load dxcompiler.dll\n");
        throw std::runtime_error("Failed to load dxcompiler.dll. "
            "Ensure dxcompiler.dll and dxil.dll are in PATH or exe directory.");
    }
    DebugLog("[DXR] CreateRaytracingPipeline: dxcompiler.dll loaded\n");

    typedef HRESULT(WINAPI* DxcCreateInstanceProc)(REFCLSID, REFIID, LPVOID*);
    auto pDxcCreateInstance = (DxcCreateInstanceProc)GetProcAddress(dxcModule, "DxcCreateInstance");
    if (!pDxcCreateInstance) {
        FreeLibrary(dxcModule);
        throw std::runtime_error("Failed to find DxcCreateInstance in dxcompiler.dll");
    }

    ComPtr<IDxcUtils> dxcUtils;
    ComPtr<IDxcCompiler3> dxcCompiler;
    THROW_IF_FAILED(pDxcCreateInstance(CLSID_DxcUtils, IID_PPV_ARGS(&dxcUtils)));
    THROW_IF_FAILED(pDxcCreateInstance(CLSID_DxcCompiler, IID_PPV_ARGS(&dxcCompiler)));
    DebugLog("[DXR] CreateRaytracingPipeline: DXC compiler created\n");

    // Create source blob from inline HLSL (UTF-16 encoded)
    ComPtr<IDxcBlobEncoding> sourceBlob;
    THROW_IF_FAILED(dxcUtils->CreateBlobFromPinned(
        g_shaderCode,
        (UINT)(wcslen(g_shaderCode) * sizeof(wchar_t)),
        DXC_CP_UTF16,
        &sourceBlob));

    // Compiler arguments
    LPCWSTR args[] = {
        L"-T", L"lib_6_3",     // target profile: raytracing library
    };

    DxcBuffer sourceBuffer = {};
    sourceBuffer.Ptr      = sourceBlob->GetBufferPointer();
    sourceBuffer.Size     = sourceBlob->GetBufferSize();
    sourceBuffer.Encoding = DXC_CP_UTF16;

    DebugLog("[DXR] CreateRaytracingPipeline: Compiling HLSL with DXC (lib_6_3)...\n");

    ComPtr<IDxcResult> result;
    THROW_IF_FAILED(dxcCompiler->Compile(
        &sourceBuffer,
        args, _countof(args),
        nullptr,  // no include handler
        IID_PPV_ARGS(&result)));

    // Check for compilation errors
    ComPtr<IDxcBlobUtf8> errors;
    result->GetOutput(DXC_OUT_ERRORS, IID_PPV_ARGS(&errors), nullptr);
    if (errors && errors->GetStringLength() > 0) {
        DebugLog("[DXR] CreateRaytracingPipeline: Shader compile output:\n%s\n",
                 errors->GetStringPointer());
    }

    HRESULT compileStatus;
    result->GetStatus(&compileStatus);
    if (FAILED(compileStatus)) {
        DebugLog("[DXR] CreateRaytracingPipeline: Shader compilation FAILED (0x%08X)\n",
                 (unsigned)compileStatus);
    }
    THROW_IF_FAILED(compileStatus);

    ComPtr<IDxcBlob> shaderBlob;
    THROW_IF_FAILED(result->GetOutput(DXC_OUT_OBJECT, IID_PPV_ARGS(&shaderBlob), nullptr));
    DebugLog("[DXR] CreateRaytracingPipeline: Shader compiled OK (%zu bytes)\n",
             shaderBlob->GetBufferSize());

    // --- Build State Object (raytracing pipeline) ---
    // Subobjects:
    //   1. DXIL Library (compiled shader blob)
    //   2. Hit Group ("HitGroup" -> ClosestHit)
    //   3. Shader Config (payload/attribute sizes)
    //   4. Global Root Signature
    //   5. Pipeline Config (max recursion depth)

    std::vector<D3D12_STATE_SUBOBJECT> subobjects;
    subobjects.reserve(8);

    // --- DXIL Library ---
    D3D12_DXIL_LIBRARY_DESC libDesc = {};
    libDesc.DXILLibrary.pShaderBytecode = shaderBlob->GetBufferPointer();
    libDesc.DXILLibrary.BytecodeLength  = shaderBlob->GetBufferSize();
    libDesc.NumExports = 0; // export all shaders

    D3D12_STATE_SUBOBJECT libSubobject = {};
    libSubobject.Type  = D3D12_STATE_SUBOBJECT_TYPE_DXIL_LIBRARY;
    libSubobject.pDesc = &libDesc;
    subobjects.push_back(libSubobject);
    DebugLog("[DXR] CreateRaytracingPipeline: DXIL library subobject added\n");

    // --- Hit Group ---
    D3D12_HIT_GROUP_DESC hitGroupDesc = {};
    hitGroupDesc.HitGroupExport         = L"HitGroup";
    hitGroupDesc.ClosestHitShaderImport = L"ClosestHit";
    hitGroupDesc.Type                   = D3D12_HIT_GROUP_TYPE_TRIANGLES;

    D3D12_STATE_SUBOBJECT hitGroupSubobject = {};
    hitGroupSubobject.Type  = D3D12_STATE_SUBOBJECT_TYPE_HIT_GROUP;
    hitGroupSubobject.pDesc = &hitGroupDesc;
    subobjects.push_back(hitGroupSubobject);
    DebugLog("[DXR] CreateRaytracingPipeline: Hit group subobject added\n");

    // --- Shader Config ---
    D3D12_RAYTRACING_SHADER_CONFIG shaderConfig = {};
    shaderConfig.MaxPayloadSizeInBytes   = sizeof(float) * 4; // RayPayload: float4
    shaderConfig.MaxAttributeSizeInBytes = sizeof(float) * 2; // TriAttributes: float2

    D3D12_STATE_SUBOBJECT shaderConfigSubobject = {};
    shaderConfigSubobject.Type  = D3D12_STATE_SUBOBJECT_TYPE_RAYTRACING_SHADER_CONFIG;
    shaderConfigSubobject.pDesc = &shaderConfig;
    subobjects.push_back(shaderConfigSubobject);
    DebugLog("[DXR] CreateRaytracingPipeline: Shader config added (payload=%u, attrib=%u)\n",
             shaderConfig.MaxPayloadSizeInBytes, shaderConfig.MaxAttributeSizeInBytes);

    // --- Global Root Signature ---
    D3D12_GLOBAL_ROOT_SIGNATURE globalRootSigDesc = {};
    globalRootSigDesc.pGlobalRootSignature = g_globalRootSig.Get();

    D3D12_STATE_SUBOBJECT rootSigSubobject = {};
    rootSigSubobject.Type  = D3D12_STATE_SUBOBJECT_TYPE_GLOBAL_ROOT_SIGNATURE;
    rootSigSubobject.pDesc = &globalRootSigDesc;
    subobjects.push_back(rootSigSubobject);

    // --- Pipeline Config ---
    D3D12_RAYTRACING_PIPELINE_CONFIG pipelineConfig = {};
    pipelineConfig.MaxTraceRecursionDepth = 1; // no recursion

    D3D12_STATE_SUBOBJECT pipelineConfigSubobject = {};
    pipelineConfigSubobject.Type  = D3D12_STATE_SUBOBJECT_TYPE_RAYTRACING_PIPELINE_CONFIG;
    pipelineConfigSubobject.pDesc = &pipelineConfig;
    subobjects.push_back(pipelineConfigSubobject);

    // --- Create State Object ---
    D3D12_STATE_OBJECT_DESC stateObjectDesc = {};
    stateObjectDesc.Type          = D3D12_STATE_OBJECT_TYPE_RAYTRACING_PIPELINE;
    stateObjectDesc.NumSubobjects = (UINT)subobjects.size();
    stateObjectDesc.pSubobjects   = subobjects.data();

    DebugLog("[DXR] CreateRaytracingPipeline: Creating state object (%u subobjects)...\n",
             (UINT)subobjects.size());
    THROW_IF_FAILED(g_device->CreateStateObject(&stateObjectDesc, IID_PPV_ARGS(&g_stateObject)));

    DebugLog("[DXR] CreateRaytracingPipeline: DONE\n");
}

// =============================================================================
// CreateOutputResource - Create UAV texture for raytracing output
// =============================================================================
void CreateOutputResource() {
    DebugLog("[DXR] CreateOutputResource: BEGIN\n");

    // UAV texture (raytracing writes results here)
    D3D12_RESOURCE_DESC texDesc = {};
    texDesc.Dimension        = D3D12_RESOURCE_DIMENSION_TEXTURE2D;
    texDesc.Width            = WIDTH;
    texDesc.Height           = HEIGHT;
    texDesc.DepthOrArraySize = 1;
    texDesc.MipLevels        = 1;
    texDesc.Format           = DXGI_FORMAT_R8G8B8A8_UNORM;
    texDesc.SampleDesc.Count = 1;
    texDesc.Flags            = D3D12_RESOURCE_FLAG_ALLOW_UNORDERED_ACCESS;

    D3D12_HEAP_PROPERTIES hp = {};
    hp.Type = D3D12_HEAP_TYPE_DEFAULT;
    THROW_IF_FAILED(g_device->CreateCommittedResource(
        &hp, D3D12_HEAP_FLAG_NONE, &texDesc,
        D3D12_RESOURCE_STATE_UNORDERED_ACCESS, nullptr,
        IID_PPV_ARGS(&g_outputResource)));

    // Create UAV descriptor
    D3D12_CPU_DESCRIPTOR_HANDLE cpuHandle = g_srvUavHeap->GetCPUDescriptorHandleForHeapStart();
    D3D12_UNORDERED_ACCESS_VIEW_DESC uavDesc = {};
    uavDesc.ViewDimension = D3D12_UAV_DIMENSION_TEXTURE2D;
    g_device->CreateUnorderedAccessView(g_outputResource.Get(), nullptr, &uavDesc, cpuHandle);

    DebugLog("[DXR] CreateOutputResource: DONE (%ux%u UAV texture)\n", WIDTH, HEIGHT);
}

// =============================================================================
// CreateCameraBuffer - Set up camera matrices (view inverse, projection inverse)
// =============================================================================
void CreateCameraBuffer() {
    DebugLog("[DXR] CreateCameraBuffer: BEGIN\n");

    // Two 4x4 matrices: viewInverse and projInverse
    UINT bufferSize = (UINT)Align(sizeof(XMFLOAT4X4) * 2, 256);
    g_cameraBuffer = CreateUploadBuffer(bufferSize);

    // Camera setup
    XMVECTOR eye    = XMVectorSet(0.0f, 0.0f, -2.5f, 1.0f);
    XMVECTOR target = XMVectorSet(0.0f, 0.0f, 0.0f, 1.0f);
    XMVECTOR up     = XMVectorSet(0.0f, 1.0f, 0.0f, 0.0f);
    XMMATRIX view   = XMMatrixLookAtLH(eye, target, up);
    XMMATRIX proj   = XMMatrixPerspectiveFovLH(
        XMConvertToRadians(60.0f), (float)WIDTH / HEIGHT, 0.1f, 1000.0f);

    XMMATRIX viewInv = XMMatrixInverse(nullptr, view);
    XMMATRIX projInv = XMMatrixInverse(nullptr, proj);

    // DirectXMath stores matrices in row-major order.
    // HLSL default (without -Zpr) reads them as column-major, effectively transposing.
    // This implicit transpose makes mul(M, v) in HLSL equivalent to v * M in DirectXMath.
    // Therefore, NO explicit transpose is needed.
    XMFLOAT4X4 matrices[2];
    XMStoreFloat4x4(&matrices[0], viewInv);
    XMStoreFloat4x4(&matrices[1], projInv);

    void* mapped = nullptr;
    THROW_IF_FAILED(g_cameraBuffer->Map(0, nullptr, &mapped));
    memcpy(mapped, matrices, sizeof(matrices));
    g_cameraBuffer->Unmap(0, nullptr);

    DebugLog("[DXR] CreateCameraBuffer: DONE (eye=0,0,-2.5  fov=60)\n");
}

// =============================================================================
// CreateShaderTable - Build shader record table for DispatchRays
// =============================================================================
void CreateShaderTable() {
    DebugLog("[DXR] CreateShaderTable: BEGIN\n");

    // The shader table stores pointers to each shader in the raytracing pipeline.
    // Layout: [RayGen Record] [Miss Record] [HitGroup Record]

    ComPtr<ID3D12StateObjectProperties> stateProps;
    THROW_IF_FAILED(g_stateObject.As(&stateProps));

    void* rayGenId = stateProps->GetShaderIdentifier(L"RayGen");
    void* missId   = stateProps->GetShaderIdentifier(L"Miss");
    void* hitId    = stateProps->GetShaderIdentifier(L"HitGroup");

    if (!rayGenId || !missId || !hitId) {
        DebugLog("[DXR] CreateShaderTable: ERROR - Failed to get shader identifiers!\n");
        throw std::runtime_error("Failed to get shader identifiers");
    }
    DebugLog("[DXR] CreateShaderTable: Shader identifiers retrieved (RayGen, Miss, HitGroup)\n");

    UINT shaderIdSize = D3D12_SHADER_IDENTIFIER_SIZE_IN_BYTES; // 32 bytes
    // Each record's StartAddress must be aligned to D3D12_RAYTRACING_SHADER_TABLE_BYTE_ALIGNMENT (64 bytes)
    // StrideInBytes must be aligned to D3D12_RAYTRACING_SHADER_RECORD_BYTE_ALIGNMENT (32 bytes)
    UINT recordSize = (UINT)Align(shaderIdSize, D3D12_RAYTRACING_SHADER_TABLE_BYTE_ALIGNMENT); // 64 bytes

    // Buffer for 3 records
    UINT tableSize = recordSize * 3;
    g_shaderTable = CreateUploadBuffer(tableSize);

    uint8_t* mapped = nullptr;
    THROW_IF_FAILED(g_shaderTable->Map(0, nullptr, (void**)&mapped));
    memcpy(mapped + recordSize * 0, rayGenId, shaderIdSize);
    memcpy(mapped + recordSize * 1, missId,   shaderIdSize);
    memcpy(mapped + recordSize * 2, hitId,    shaderIdSize);
    g_shaderTable->Unmap(0, nullptr);

    DebugLog("[DXR] CreateShaderTable: DONE (recordSize=%u, tableSize=%u)\n", recordSize, tableSize);
}

// =============================================================================
// Render - Dispatch rays and copy result to back buffer
// =============================================================================
void Render() {
    static bool firstFrame = true;
    if (firstFrame) DebugLog("[DXR] Render: first frame BEGIN\n");

    THROW_IF_FAILED(g_commandAllocator->Reset());
    THROW_IF_FAILED(g_commandList->Reset(g_commandAllocator.Get(), nullptr));
    if (firstFrame) DebugLog("[DXR] Render: command list reset OK\n");

    // Set descriptor heap
    ID3D12DescriptorHeap* heaps[] = { g_srvUavHeap.Get() };
    g_commandList->SetDescriptorHeaps(1, heaps);

    // Set global root signature and parameters
    g_commandList->SetComputeRootSignature(g_globalRootSig.Get());
    g_commandList->SetComputeRootDescriptorTable(0,
        g_srvUavHeap->GetGPUDescriptorHandleForHeapStart()); // UAV
    g_commandList->SetComputeRootShaderResourceView(1,
        g_topLevelAS->GetGPUVirtualAddress());                // TLAS
    g_commandList->SetComputeRootConstantBufferView(2,
        g_cameraBuffer->GetGPUVirtualAddress());              // Camera

    // Set pipeline state object
    g_commandList->SetPipelineState1(g_stateObject.Get());

    // DispatchRays
    // Record size must match the alignment used in CreateShaderTable
    UINT recordSize = (UINT)Align(
        D3D12_SHADER_IDENTIFIER_SIZE_IN_BYTES,
        D3D12_RAYTRACING_SHADER_TABLE_BYTE_ALIGNMENT); // 64 bytes

    D3D12_DISPATCH_RAYS_DESC dispatchDesc = {};

    // Ray Generation shader record
    dispatchDesc.RayGenerationShaderRecord.StartAddress =
        g_shaderTable->GetGPUVirtualAddress() + recordSize * 0;
    dispatchDesc.RayGenerationShaderRecord.SizeInBytes = recordSize;

    // Miss shader table
    dispatchDesc.MissShaderTable.StartAddress =
        g_shaderTable->GetGPUVirtualAddress() + recordSize * 1;
    dispatchDesc.MissShaderTable.SizeInBytes   = recordSize;
    dispatchDesc.MissShaderTable.StrideInBytes  = recordSize;

    // Hit Group table
    dispatchDesc.HitGroupTable.StartAddress =
        g_shaderTable->GetGPUVirtualAddress() + recordSize * 2;
    dispatchDesc.HitGroupTable.SizeInBytes   = recordSize;
    dispatchDesc.HitGroupTable.StrideInBytes  = recordSize;

    // Resolution
    dispatchDesc.Width  = WIDTH;
    dispatchDesc.Height = HEIGHT;
    dispatchDesc.Depth  = 1;

    if (firstFrame) DebugLog("[DXR] Render: calling DispatchRays (%ux%u)...\n", WIDTH, HEIGHT);
    g_commandList->DispatchRays(&dispatchDesc);
    if (firstFrame) DebugLog("[DXR] Render: DispatchRays recorded\n");

    // Copy output texture to back buffer
    D3D12_RESOURCE_BARRIER barriers[2] = {};

    // Output texture: UAV -> COPY_SOURCE
    barriers[0].Type                   = D3D12_RESOURCE_BARRIER_TYPE_TRANSITION;
    barriers[0].Transition.pResource   = g_outputResource.Get();
    barriers[0].Transition.StateBefore = D3D12_RESOURCE_STATE_UNORDERED_ACCESS;
    barriers[0].Transition.StateAfter  = D3D12_RESOURCE_STATE_COPY_SOURCE;
    barriers[0].Transition.Subresource = D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES;

    // Back buffer: PRESENT -> COPY_DEST
    barriers[1].Type                   = D3D12_RESOURCE_BARRIER_TYPE_TRANSITION;
    barriers[1].Transition.pResource   = g_renderTargets[g_frameIndex].Get();
    barriers[1].Transition.StateBefore = D3D12_RESOURCE_STATE_PRESENT;
    barriers[1].Transition.StateAfter  = D3D12_RESOURCE_STATE_COPY_DEST;
    barriers[1].Transition.Subresource = D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES;

    g_commandList->ResourceBarrier(2, barriers);
    g_commandList->CopyResource(g_renderTargets[g_frameIndex].Get(), g_outputResource.Get());

    // Restore states
    barriers[0].Transition.StateBefore = D3D12_RESOURCE_STATE_COPY_SOURCE;
    barriers[0].Transition.StateAfter  = D3D12_RESOURCE_STATE_UNORDERED_ACCESS;
    barriers[1].Transition.StateBefore = D3D12_RESOURCE_STATE_COPY_DEST;
    barriers[1].Transition.StateAfter  = D3D12_RESOURCE_STATE_PRESENT;
    g_commandList->ResourceBarrier(2, barriers);

    if (firstFrame) DebugLog("[DXR] Render: closing command list...\n");
    THROW_IF_FAILED(g_commandList->Close());
    ID3D12CommandList* lists[] = { g_commandList.Get() };
    g_commandQueue->ExecuteCommandLists(1, lists);

    // Present
    if (firstFrame) DebugLog("[DXR] Render: presenting...\n");
    THROW_IF_FAILED(g_swapChain->Present(1, 0));
    WaitForGPU();
    g_frameIndex = g_swapChain->GetCurrentBackBufferIndex();
    if (firstFrame) {
        DebugLog("[DXR] Render: first frame DONE\n");
        firstFrame = false;
    }
}

// =============================================================================
// Window Procedure
// =============================================================================
LRESULT CALLBACK WndProc(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam) {
    switch (msg) {
    case WM_KEYDOWN:
        if (wParam == VK_ESCAPE) PostQuitMessage(0);
        return 0;
    case WM_DESTROY:
        PostQuitMessage(0);
        return 0;
    }
    return DefWindowProc(hwnd, msg, wParam, lParam);
}

// =============================================================================
// Entry Point
// =============================================================================
int WINAPI WinMain(HINSTANCE hInstance, HINSTANCE, LPSTR, int nCmdShow) {
    try {
        DebugLog("[DXR] ====== DXR Triangle Sample START ======\n");

        // Register window class
        WNDCLASSEX wc = { sizeof(WNDCLASSEX) };
        wc.style         = CS_HREDRAW | CS_VREDRAW;
        wc.lpfnWndProc   = WndProc;
        wc.hInstance      = hInstance;
        wc.hCursor        = LoadCursor(nullptr, IDC_ARROW);
        wc.lpszClassName  = L"DXRTriangle";
        RegisterClassEx(&wc);

        // Create window
        RECT rc = { 0, 0, (LONG)WIDTH, (LONG)HEIGHT };
        AdjustWindowRect(&rc, WS_OVERLAPPEDWINDOW, FALSE);
        g_hwnd = CreateWindowEx(0, L"DXRTriangle", L"DXR Triangle Sample",
            WS_OVERLAPPEDWINDOW, CW_USEDEFAULT, CW_USEDEFAULT,
            rc.right - rc.left, rc.bottom - rc.top,
            nullptr, nullptr, hInstance, nullptr);
        ShowWindow(g_hwnd, nCmdShow);
        DebugLog("[DXR] Window created (%ux%u)\n", WIDTH, HEIGHT);

        // Initialization pipeline
        InitD3D12();
        CreateVertexBuffer();
        BuildAccelerationStructures();
        CreateRootSignature();
        CreateRaytracingPipeline();
        CreateOutputResource();
        CreateCameraBuffer();
        CreateShaderTable();

        // Close the command list before entering the render loop.
        // ExecuteAndWait() in BuildAccelerationStructures left it in recording state.
        // Render() needs to call allocator->Reset() first, which requires
        // the command list to NOT be in recording state.
        THROW_IF_FAILED(g_commandList->Close());

        DebugLog("[DXR] ====== Initialization COMPLETE - entering render loop ======\n");

        // Message loop
        MSG msg = {};
        while (msg.message != WM_QUIT) {
            if (PeekMessage(&msg, nullptr, 0, 0, PM_REMOVE)) {
                TranslateMessage(&msg);
                DispatchMessage(&msg);
            } else {
                Render();
            }
        }

        WaitForGPU();
        CloseHandle(g_fenceEvent);
        DebugLog("[DXR] ====== DXR Triangle Sample END ======\n");

    } catch (const std::exception& e) {
        DebugLog("[DXR] FATAL EXCEPTION: %s\n", e.what());
        MessageBoxA(nullptr, e.what(), "Error", MB_OK | MB_ICONERROR);
        return 1;
    }
    return 0;
}