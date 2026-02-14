/**
 * DirectX 12 Compute Shader Harmonograph
 *
 * - Creates a Win32 window
 * - Uses a compute shader to fill UAV buffers (positions + colors)
 * - Uses a vertex/pixel shader to render LINE_STRIP from buffer data
 *
 * Build: dub build
 * Requires: directx-d package (https://github.com/evilrat666/directx-d)
 */

import core.stdc.string : memcpy;
import core.stdc.math : fmodf, sinf, cosf, expf;
import std.stdio;
import std.string : toStringz, fromStringz;
import std.conv : to;
import std.random : uniform;
import std.format : format;
import std.file : read, exists, getcwd;

import directx.d3d12;
import directx.d3d12sdklayers;
import directx.dxgi1_4;
import directx.d3dcompiler;

import core.runtime;
import core.thread;
import core.sys.windows.windows;
import std.typecons;
import std.datetime;

// ============================================================
// Shader file name
// ============================================================
enum SHADER_FILE = "hello.hlsl";

// ============================================================
// Debug Output Function
// ============================================================
void debugPrint(string msg)
{
    import std.utf : toUTF16z;
    OutputDebugStringW(toUTF16z(msg ~ "\n"));
    debug writeln(msg);
}

void debugPrintHR(string msg, HRESULT hr)
{
    debugPrint(format("%s (HRESULT: 0x%08X)", msg, hr));
}

// ============================================================
// Constants
// ============================================================
enum WIDTH = 800;
enum HEIGHT = 600;
enum VERTEX_COUNT = 500_000;
enum PI2 = 6.283185307179586f;

// ============================================================
// Constant buffer structure (must match HLSL cbuffer)
// ============================================================
struct HarmonographParams
{
    float A1, f1, p1, d1;
    float A2, f2, p2, d2;
    float A3, f3, p3, d3;
    float A4, f4, p4, d4;
    uint max_num;
    float[3] padding;
    float[2] resolution;
    float[2] padding2;
}

// ============================================================
// Main Demo Class
// ============================================================
class D3D12Harmonograph
{
    this(uint width, uint height, HWND hWnd)
    {
        debugPrint("=== D3D12Harmonograph Constructor ===");
        
        this.hWnd = hWnd;
        this.width = width;
        this.height = height;

        viewport.MinDepth = 0.0f;
        viewport.MaxDepth = 1.0f;
        OnResize(width, height);

        // Initialize harmonograph parameters
        params.A1 = 50.0f; params.f1 = 2.0f; params.p1 = 1.0f/16.0f; params.d1 = 0.02f;
        params.A2 = 50.0f; params.f2 = 2.0f; params.p2 = 3.0f/2.0f;  params.d2 = 0.0315f;
        params.A3 = 50.0f; params.f3 = 2.0f; params.p3 = 13.0f/15.0f; params.d3 = 0.02f;
        params.A4 = 50.0f; params.f4 = 2.0f; params.p4 = 1.0f;       params.d4 = 0.02f;
        params.max_num = VERTEX_COUNT;
        params.resolution[0] = cast(float)width;
        params.resolution[1] = cast(float)height;

        LoadPipeline();
        LoadAssets();
        
        debugPrint("=== D3D12Harmonograph Constructor Complete ===");
    }

    void LoadPipeline()
    {
        debugPrint("LoadPipeline: Starting...");
        
        HRESULT hr;
        
        // Enable debug layer
        debugPrint("LoadPipeline: Enabling debug layer...");
        {
            ID3D12Debug debugController;
            hr = D3D12GetDebugInterface(&IID_ID3D12Debug, cast(void**)&debugController);
            if (SUCCEEDED(hr) && debugController)
            {
                debugController.EnableDebugLayer();
                debugPrint("LoadPipeline: Debug layer enabled successfully");
                debugController.Release();
            }
            else
            {
                debugPrintHR("LoadPipeline: Failed to enable debug layer", hr);
            }
        }

        IDXGIFactory4 factory;
        scope(exit) if (factory) factory.Release();

        debugPrint("LoadPipeline: Creating DXGI Factory...");
        hr = CreateDXGIFactory1(&IID_IDXGIFactory4, cast(void**)&factory);
        if (FAILED(hr))
        {
            debugPrintHR("LoadPipeline: CreateDXGIFactory1 failed", hr);
            throw new D3D12Exception("Create DXGI Factory failed");
        }
        debugPrint("LoadPipeline: DXGI Factory created successfully");

        IDXGIAdapter1 hardwareAdapter;
        scope(exit) if (hardwareAdapter) hardwareAdapter.Release();
        GetHardwareAdapter(factory, hardwareAdapter);

        debugPrint("LoadPipeline: Creating D3D12 Device...");
        hr = D3D12CreateDevice(hardwareAdapter, D3D_FEATURE_LEVEL_11_0, &IID_ID3D12Device, &device);
        if (FAILED(hr))
        {
            debugPrintHR("LoadPipeline: D3D12CreateDevice failed", hr);
            throw new D3D12Exception("Create device failed");
        }
        debugPrint("LoadPipeline: D3D12 Device created successfully");

        // Create command queue
        debugPrint("LoadPipeline: Creating Command Queue...");
        D3D12_COMMAND_QUEUE_DESC queueDesc;
        queueDesc.Flags = D3D12_COMMAND_QUEUE_FLAG_NONE;
        queueDesc.Type = D3D12_COMMAND_LIST_TYPE_DIRECT;

        hr = device.CreateCommandQueue(&queueDesc, &IID_ID3D12CommandQueue, &commandQueue);
        if (FAILED(hr))
        {
            debugPrintHR("LoadPipeline: CreateCommandQueue failed", hr);
            throw new D3D12Exception("CreateCommandQueue failed");
        }
        debugPrint("LoadPipeline: Command Queue created successfully");

        // Create swap chain
        debugPrint("LoadPipeline: Creating Swap Chain...");
        DXGI_SWAP_CHAIN_DESC swapChainDesc;
        swapChainDesc.BufferCount = frameCount;
        swapChainDesc.BufferDesc.Width = width;
        swapChainDesc.BufferDesc.Height = height;
        swapChainDesc.BufferDesc.Format = DXGI_FORMAT_R8G8B8A8_UNORM;
        swapChainDesc.BufferUsage = DXGI_USAGE_RENDER_TARGET_OUTPUT;
        swapChainDesc.SwapEffect = DXGI_SWAP_EFFECT_FLIP_DISCARD;
        swapChainDesc.OutputWindow = hWnd;
        swapChainDesc.SampleDesc.Count = 1;
        swapChainDesc.Windowed = TRUE;

        IDXGISwapChain swapChain;
        scope(exit) if (swapChain) swapChain.Release();

        hr = factory.CreateSwapChain(commandQueue, &swapChainDesc, &swapChain);
        if (FAILED(hr))
        {
            debugPrintHR("LoadPipeline: CreateSwapChain failed", hr);
            throw new D3D12Exception("Init swapchain failed");
        }

        this.swapChain = cast(IDXGISwapChain3)swapChain;
        if (!this.swapChain)
        {
            debugPrint("LoadPipeline: Failed to get IDXGISwapChain3");
            throw new D3D12Exception("Failed to get IDXGISwapChain3");
        }
        debugPrint("LoadPipeline: Swap Chain created successfully");

        factory.MakeWindowAssociation(null, DXGI_MWA_NO_ALT_ENTER);
        frameIndex = this.swapChain.GetCurrentBackBufferIndex();

        // Create RTV descriptor heap
        debugPrint("LoadPipeline: Creating RTV Descriptor Heap...");
        {
            D3D12_DESCRIPTOR_HEAP_DESC rtvHeapDesc;
            rtvHeapDesc.NumDescriptors = frameCount;
            rtvHeapDesc.Type = D3D12_DESCRIPTOR_HEAP_TYPE_RTV;
            rtvHeapDesc.Flags = D3D12_DESCRIPTOR_HEAP_FLAG_NONE;

            hr = device.CreateDescriptorHeap(&rtvHeapDesc, &IID_ID3D12DescriptorHeap, &rtvHeap);
            if (FAILED(hr))
            {
                debugPrintHR("LoadPipeline: CreateDescriptorHeap (RTV) failed", hr);
                throw new D3D12Exception("Failed to create RTV descriptor heap");
            }

            rtvDescriptorSize = device.GetDescriptorHandleIncrementSize(D3D12_DESCRIPTOR_HEAP_TYPE_RTV);
        }
        debugPrint("LoadPipeline: RTV Descriptor Heap created successfully");

        // Create SRV/UAV/CBV descriptor heap
        debugPrint("LoadPipeline: Creating SRV/UAV/CBV Descriptor Heap...");
        {
            D3D12_DESCRIPTOR_HEAP_DESC srvUavHeapDesc;
            srvUavHeapDesc.NumDescriptors = 5; // 2 UAV + 2 SRV + 1 CBV
            srvUavHeapDesc.Type = D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV;
            srvUavHeapDesc.Flags = D3D12_DESCRIPTOR_HEAP_FLAG_SHADER_VISIBLE;

            hr = device.CreateDescriptorHeap(&srvUavHeapDesc, &IID_ID3D12DescriptorHeap, &srvUavHeap);
            if (FAILED(hr))
            {
                debugPrintHR("LoadPipeline: CreateDescriptorHeap (SRV/UAV) failed", hr);
                throw new D3D12Exception("Failed to create SRV/UAV descriptor heap");
            }

            srvUavDescriptorSize = device.GetDescriptorHandleIncrementSize(D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV);
        }
        debugPrint("LoadPipeline: SRV/UAV/CBV Descriptor Heap created successfully");

        // Create render target views
        debugPrint("LoadPipeline: Creating Render Target Views...");
        {
            D3D12_CPU_DESCRIPTOR_HANDLE rtvHandle = rtvHeap.GetCPUDescriptorHandleForHeapStart();

            for (uint n = 0; n < frameCount; n++)
            {
                hr = swapChain.GetBuffer(n, &IID_ID3D12Resource, cast(void**)&renderTargets[n]);
                if (FAILED(hr))
                {
                    debugPrintHR(format("LoadPipeline: GetBuffer(%d) failed", n), hr);
                    throw new D3D12Exception("Failed to get swap chain buffer");
                }
                device.CreateRenderTargetView(renderTargets[n], null, rtvHandle);
                rtvHandle.ptr += rtvDescriptorSize;
            }
        }
        debugPrint("LoadPipeline: Render Target Views created successfully");

        // Create command allocators
        debugPrint("LoadPipeline: Creating Command Allocators...");
        hr = device.CreateCommandAllocator(D3D12_COMMAND_LIST_TYPE_DIRECT, &IID_ID3D12CommandAllocator, &graphicsCommandAllocator);
        if (FAILED(hr))
        {
            debugPrintHR("LoadPipeline: CreateCommandAllocator (graphics) failed", hr);
            throw new D3D12Exception("Failed to create graphics command allocator");
        }

        hr = device.CreateCommandAllocator(D3D12_COMMAND_LIST_TYPE_DIRECT, &IID_ID3D12CommandAllocator, &computeCommandAllocator);
        if (FAILED(hr))
        {
            debugPrintHR("LoadPipeline: CreateCommandAllocator (compute) failed", hr);
            throw new D3D12Exception("Failed to create compute command allocator");
        }
        debugPrint("LoadPipeline: Command Allocators created successfully");
        
        debugPrint("LoadPipeline: Complete");
    }

    void LoadAssets()
    {
        debugPrint("LoadAssets: Starting...");
        
        // Create position and color buffers (UAV)
        CreateBuffers();

        // Create constant buffer
        CreateConstantBuffer();

        // Create root signatures
        CreateRootSignatures();

        // Create pipeline states
        CreatePipelineStates();

        // Create command lists
        debugPrint("LoadAssets: Creating Command Lists...");
        HRESULT hr = device.CreateCommandList(0, D3D12_COMMAND_LIST_TYPE_DIRECT, graphicsCommandAllocator, graphicsPipelineState, &IID_ID3D12GraphicsCommandList, cast(ID3D12CommandList*)&graphicsCommandList);
        if (FAILED(hr))
        {
            debugPrintHR("LoadAssets: CreateCommandList (graphics) failed", hr);
            throw new D3D12Exception("Failed to create graphics command list");
        }
        graphicsCommandList.Close();

        hr = device.CreateCommandList(0, D3D12_COMMAND_LIST_TYPE_DIRECT, computeCommandAllocator, computePipelineState, &IID_ID3D12GraphicsCommandList, cast(ID3D12CommandList*)&computeCommandList);
        if (FAILED(hr))
        {
            debugPrintHR("LoadAssets: CreateCommandList (compute) failed", hr);
            throw new D3D12Exception("Failed to create compute command list");
        }
        computeCommandList.Close();
        debugPrint("LoadAssets: Command Lists created successfully");

        // Create fence
        debugPrint("LoadAssets: Creating Fence...");
        hr = device.CreateFence(0, D3D12_FENCE_FLAG_NONE, &IID_ID3D12Fence, &fence);
        if (FAILED(hr))
        {
            debugPrintHR("LoadAssets: CreateFence failed", hr);
            throw new D3D12Exception("Failed to create fence");
        }
        fenceValue = 1;
        fenceEvent = CreateEvent(null, FALSE, FALSE, null);
        debugPrint("LoadAssets: Fence created successfully");

        WaitForPreviousFrame();
        
        debugPrint("LoadAssets: Complete");
    }

    void CreateBuffers()
    {
        debugPrint("CreateBuffers: Starting...");
        
        HRESULT hr;
        
        // Create position buffer
        auto heapProps = D3D12_HEAP_PROPERTIES(D3D12_HEAP_TYPE_DEFAULT, D3D12_CPU_PAGE_PROPERTY_UNKNOWN, D3D12_MEMORY_POOL_UNKNOWN, 1, 1);
        auto bufferDesc = D3D12_RESOURCE_DESC(
            D3D12_RESOURCE_DIMENSION_BUFFER, 0,
            VERTEX_COUNT * 16, 1, 1, 1,  // float4 = 16 bytes
            DXGI_FORMAT_UNKNOWN,
            DXGI_SAMPLE_DESC(1, 0),
            D3D12_TEXTURE_LAYOUT_ROW_MAJOR,
            D3D12_RESOURCE_FLAG_ALLOW_UNORDERED_ACCESS
        );

        debugPrint("CreateBuffers: Creating Position Buffer...");
        hr = device.CreateCommittedResource(&heapProps, D3D12_HEAP_FLAG_NONE, &bufferDesc,
            D3D12_RESOURCE_STATE_UNORDERED_ACCESS, null, &IID_ID3D12Resource, &positionBuffer);
        if (FAILED(hr))
        {
            debugPrintHR("CreateBuffers: CreateCommittedResource (position) failed", hr);
            throw new D3D12Exception("Failed to create position buffer");
        }

        debugPrint("CreateBuffers: Creating Color Buffer...");
        hr = device.CreateCommittedResource(&heapProps, D3D12_HEAP_FLAG_NONE, &bufferDesc,
            D3D12_RESOURCE_STATE_UNORDERED_ACCESS, null, &IID_ID3D12Resource, &colorBuffer);
        if (FAILED(hr))
        {
            debugPrintHR("CreateBuffers: CreateCommittedResource (color) failed", hr);
            throw new D3D12Exception("Failed to create color buffer");
        }

        // Create UAVs and SRVs
        debugPrint("CreateBuffers: Creating UAVs and SRVs...");
        auto srvUavHandle = srvUavHeap.GetCPUDescriptorHandleForHeapStart();

        // UAV for position buffer (u0)
        D3D12_UNORDERED_ACCESS_VIEW_DESC uavDesc;
        uavDesc.Format = DXGI_FORMAT_UNKNOWN;
        uavDesc.ViewDimension = D3D12_UAV_DIMENSION_BUFFER;
        uavDesc.Buffer.NumElements = VERTEX_COUNT;
        uavDesc.Buffer.StructureByteStride = 16;
        device.CreateUnorderedAccessView(positionBuffer, null, &uavDesc, srvUavHandle);
        srvUavHandle.ptr += srvUavDescriptorSize;

        // UAV for color buffer (u1)
        device.CreateUnorderedAccessView(colorBuffer, null, &uavDesc, srvUavHandle);
        srvUavHandle.ptr += srvUavDescriptorSize;

        // CBV slot (b0) - will be created in CreateConstantBuffer
        srvUavHandle.ptr += srvUavDescriptorSize;

        // SRV for position buffer (t0)
        D3D12_SHADER_RESOURCE_VIEW_DESC srvDesc;
        srvDesc.Format = DXGI_FORMAT_UNKNOWN;
        srvDesc.ViewDimension = D3D12_SRV_DIMENSION_BUFFER;
        srvDesc.Shader4ComponentMapping = D3D12_DEFAULT_SHADER_4_COMPONENT_MAPPING;
        srvDesc.Buffer.NumElements = VERTEX_COUNT;
        srvDesc.Buffer.StructureByteStride = 16;
        device.CreateShaderResourceView(positionBuffer, &srvDesc, srvUavHandle);
        srvUavHandle.ptr += srvUavDescriptorSize;

        // SRV for color buffer (t1)
        device.CreateShaderResourceView(colorBuffer, &srvDesc, srvUavHandle);
        
        debugPrint("CreateBuffers: Complete");
    }

    void CreateConstantBuffer()
    {
        debugPrint("CreateConstantBuffer: Starting...");
        
        HRESULT hr;
        
        auto heapProps = D3D12_HEAP_PROPERTIES(D3D12_HEAP_TYPE_UPLOAD, D3D12_CPU_PAGE_PROPERTY_UNKNOWN, D3D12_MEMORY_POOL_UNKNOWN, 1, 1);
        auto bufferDesc = D3D12_RESOURCE_DESC(
            D3D12_RESOURCE_DIMENSION_BUFFER, 0,
            256, 1, 1, 1,  // 256-byte aligned
            DXGI_FORMAT_UNKNOWN,
            DXGI_SAMPLE_DESC(1, 0),
            D3D12_TEXTURE_LAYOUT_ROW_MAJOR,
            D3D12_RESOURCE_FLAG_NONE
        );

        hr = device.CreateCommittedResource(&heapProps, D3D12_HEAP_FLAG_NONE, &bufferDesc,
            D3D12_RESOURCE_STATE_GENERIC_READ, null, &IID_ID3D12Resource, &constantBuffer);
        if (FAILED(hr))
        {
            debugPrintHR("CreateConstantBuffer: CreateCommittedResource failed", hr);
            throw new D3D12Exception("Failed to create constant buffer");
        }

        // Map constant buffer
        auto readRange = D3D12_RANGE(0, 0);
        hr = constantBuffer.Map(0, &readRange, cast(void**)&constantBufferData);
        if (FAILED(hr))
        {
            debugPrintHR("CreateConstantBuffer: Map failed", hr);
            throw new D3D12Exception("Failed to map constant buffer");
        }

        // Create CBV
        auto srvUavHandle = srvUavHeap.GetCPUDescriptorHandleForHeapStart();
        srvUavHandle.ptr += srvUavDescriptorSize * 2; // Skip UAVs

        D3D12_CONSTANT_BUFFER_VIEW_DESC cbvDesc;
        cbvDesc.BufferLocation = constantBuffer.GetGPUVirtualAddress();
        cbvDesc.SizeInBytes = 256;
        device.CreateConstantBufferView(&cbvDesc, srvUavHandle);
        
        debugPrint("CreateConstantBuffer: Complete");
    }

    void CreateRootSignatures()
    {
        debugPrint("CreateRootSignatures: Starting...");
        
        HRESULT hr;
        ID3DBlob signature;
        ID3DBlob error;
        scope(exit) { if (signature) signature.Release(); if (error) error.Release(); }

        // Compute root signature
        debugPrint("CreateRootSignatures: Creating Compute Root Signature...");
        {
            D3D12_DESCRIPTOR_RANGE[2] computeRanges;
            
            // UAV range (u0, u1)
            computeRanges[0].RangeType = D3D12_DESCRIPTOR_RANGE_TYPE_UAV;
            computeRanges[0].NumDescriptors = 2;
            computeRanges[0].BaseShaderRegister = 0;
            computeRanges[0].RegisterSpace = 0;
            computeRanges[0].OffsetInDescriptorsFromTableStart = 0;

            // CBV range (b0)
            computeRanges[1].RangeType = D3D12_DESCRIPTOR_RANGE_TYPE_CBV;
            computeRanges[1].NumDescriptors = 1;
            computeRanges[1].BaseShaderRegister = 0;
            computeRanges[1].RegisterSpace = 0;
            computeRanges[1].OffsetInDescriptorsFromTableStart = 2;

            D3D12_ROOT_PARAMETER[1] computeParams;
            computeParams[0].ParameterType = D3D12_ROOT_PARAMETER_TYPE_DESCRIPTOR_TABLE;
            computeParams[0].DescriptorTable.NumDescriptorRanges = 2;
            computeParams[0].DescriptorTable.pDescriptorRanges = computeRanges.ptr;
            computeParams[0].ShaderVisibility = D3D12_SHADER_VISIBILITY_ALL;

            D3D12_ROOT_SIGNATURE_DESC computeRsDesc;
            computeRsDesc.NumParameters = 1;
            computeRsDesc.pParameters = computeParams.ptr;
            computeRsDesc.NumStaticSamplers = 0;
            computeRsDesc.pStaticSamplers = null;
            computeRsDesc.Flags = D3D12_ROOT_SIGNATURE_FLAG_NONE;

            hr = D3D12SerializeRootSignature(&computeRsDesc, D3D_ROOT_SIGNATURE_VERSION_1, &signature, &error);
            if (FAILED(hr))
            {
                if (error)
                {
                    debugPrint("CreateRootSignatures: Compute serialize error: " ~ cast(string)fromStringz(cast(char*)error.GetBufferPointer()));
                }
                debugPrintHR("CreateRootSignatures: D3D12SerializeRootSignature (compute) failed", hr);
                throw new D3D12Exception("Failed to serialize compute root signature");
            }
            hr = device.CreateRootSignature(0, signature.GetBufferPointer(), signature.GetBufferSize(), &IID_ID3D12RootSignature, &computeRootSignature);
            if (FAILED(hr))
            {
                debugPrintHR("CreateRootSignatures: CreateRootSignature (compute) failed", hr);
                throw new D3D12Exception("Failed to create compute root signature");
            }
            signature.Release();
            signature = null;
        }
        debugPrint("CreateRootSignatures: Compute Root Signature created successfully");

        // Graphics root signature
        debugPrint("CreateRootSignatures: Creating Graphics Root Signature...");
        {
            D3D12_DESCRIPTOR_RANGE[2] graphicsRanges;

            // SRV range (t0, t1)
            graphicsRanges[0].RangeType = D3D12_DESCRIPTOR_RANGE_TYPE_SRV;
            graphicsRanges[0].NumDescriptors = 2;
            graphicsRanges[0].BaseShaderRegister = 0;
            graphicsRanges[0].RegisterSpace = 0;
            graphicsRanges[0].OffsetInDescriptorsFromTableStart = 0;

            // CBV range (b0)
            graphicsRanges[1].RangeType = D3D12_DESCRIPTOR_RANGE_TYPE_CBV;
            graphicsRanges[1].NumDescriptors = 1;
            graphicsRanges[1].BaseShaderRegister = 0;
            graphicsRanges[1].RegisterSpace = 0;
            graphicsRanges[1].OffsetInDescriptorsFromTableStart = 0;

            D3D12_ROOT_PARAMETER[2] graphicsParams;
            
            // Table 0: SRVs
            graphicsParams[0].ParameterType = D3D12_ROOT_PARAMETER_TYPE_DESCRIPTOR_TABLE;
            graphicsParams[0].DescriptorTable.NumDescriptorRanges = 1;
            graphicsParams[0].DescriptorTable.pDescriptorRanges = &graphicsRanges[0];
            graphicsParams[0].ShaderVisibility = D3D12_SHADER_VISIBILITY_VERTEX;

            // Table 1: CBV
            graphicsParams[1].ParameterType = D3D12_ROOT_PARAMETER_TYPE_DESCRIPTOR_TABLE;
            graphicsParams[1].DescriptorTable.NumDescriptorRanges = 1;
            graphicsParams[1].DescriptorTable.pDescriptorRanges = &graphicsRanges[1];
            graphicsParams[1].ShaderVisibility = D3D12_SHADER_VISIBILITY_VERTEX;

            D3D12_ROOT_SIGNATURE_DESC graphicsRsDesc;
            graphicsRsDesc.NumParameters = 2;
            graphicsRsDesc.pParameters = graphicsParams.ptr;
            graphicsRsDesc.NumStaticSamplers = 0;
            graphicsRsDesc.pStaticSamplers = null;
            graphicsRsDesc.Flags = D3D12_ROOT_SIGNATURE_FLAG_NONE;

            hr = D3D12SerializeRootSignature(&graphicsRsDesc, D3D_ROOT_SIGNATURE_VERSION_1, &signature, &error);
            if (FAILED(hr))
            {
                if (error)
                {
                    debugPrint("CreateRootSignatures: Graphics serialize error: " ~ cast(string)fromStringz(cast(char*)error.GetBufferPointer()));
                }
                debugPrintHR("CreateRootSignatures: D3D12SerializeRootSignature (graphics) failed", hr);
                throw new D3D12Exception("Failed to serialize graphics root signature");
            }
            hr = device.CreateRootSignature(0, signature.GetBufferPointer(), signature.GetBufferSize(), &IID_ID3D12RootSignature, &graphicsRootSignature);
            if (FAILED(hr))
            {
                debugPrintHR("CreateRootSignatures: CreateRootSignature (graphics) failed", hr);
                throw new D3D12Exception("Failed to create graphics root signature");
            }
        }
        debugPrint("CreateRootSignatures: Graphics Root Signature created successfully");
        
        debugPrint("CreateRootSignatures: Complete");
    }

    void CreatePipelineStates()
    {
        debugPrint("CreatePipelineStates: Starting...");
        
        HRESULT hr;
        ID3DBlob computeShader;
        ID3DBlob vertexShader;
        ID3DBlob pixelShader;
        ID3DBlob errorBlob;
        scope(exit)
        {
            if (computeShader) computeShader.Release();
            if (vertexShader) vertexShader.Release();
            if (pixelShader) pixelShader.Release();
            if (errorBlob) errorBlob.Release();
        }

        uint compileFlags = D3DCOMPILE_DEBUG | D3DCOMPILE_SKIP_OPTIMIZATION;

        // Load shader source from file
        debugPrint("CreatePipelineStates: Loading shader from " ~ SHADER_FILE ~ "...");
        debugPrint("CreatePipelineStates: Current working directory: " ~ getcwd());
        
        if (!exists(SHADER_FILE))
        {
            debugPrint("CreatePipelineStates: ERROR - Shader file not found: " ~ SHADER_FILE);
            throw new D3D12Exception("Shader file not found: " ~ SHADER_FILE);
        }
        
        // Read shader source from file
        string shaderSource = cast(string)read(SHADER_FILE);
        debugPrint(format("CreatePipelineStates: Loaded shader source: %d bytes", shaderSource.length));

        // Compile compute shader
        debugPrint("CreatePipelineStates: Compiling CSMain...");
        hr = D3DCompile(
            shaderSource.ptr,
            shaderSource.length,
            SHADER_FILE.ptr,  // pSourceName for error messages
            null,             // pDefines
            null,             // pInclude
            "CSMain",
            cs_5_0,
            compileFlags,
            0,
            &computeShader,
            &errorBlob
        );
        if (FAILED(hr))
        {
            debugPrintHR("CreatePipelineStates: D3DCompile (CSMain) failed", hr);
            if (errorBlob)
            {
                string errorMsg = cast(string)fromStringz(cast(char*)errorBlob.GetBufferPointer());
                debugPrint("Compute shader compile error:\n" ~ errorMsg);
                errorBlob.Release();
                errorBlob = null;
            }
            throw new D3D12Exception("Unable to compile compute shader");
        }
        debugPrint("CreatePipelineStates: CSMain compiled successfully");

        // Compile vertex shader
        debugPrint("CreatePipelineStates: Compiling VSMain...");
        hr = D3DCompile(
            shaderSource.ptr,
            shaderSource.length,
            SHADER_FILE.ptr,
            null,
            null,
            "VSMain",
            vs_5_0,
            compileFlags,
            0,
            &vertexShader,
            &errorBlob
        );
        if (FAILED(hr))
        {
            debugPrintHR("CreatePipelineStates: D3DCompile (VSMain) failed", hr);
            if (errorBlob)
            {
                string errorMsg = cast(string)fromStringz(cast(char*)errorBlob.GetBufferPointer());
                debugPrint("Vertex shader compile error:\n" ~ errorMsg);
                errorBlob.Release();
                errorBlob = null;
            }
            throw new D3D12Exception("Unable to compile vertex shader");
        }
        debugPrint("CreatePipelineStates: VSMain compiled successfully");

        // Compile pixel shader
        debugPrint("CreatePipelineStates: Compiling PSMain...");
        hr = D3DCompile(
            shaderSource.ptr,
            shaderSource.length,
            SHADER_FILE.ptr,
            null,
            null,
            "PSMain",
            ps_5_0,
            compileFlags,
            0,
            &pixelShader,
            &errorBlob
        );
        if (FAILED(hr))
        {
            debugPrintHR("CreatePipelineStates: D3DCompile (PSMain) failed", hr);
            if (errorBlob)
            {
                string errorMsg = cast(string)fromStringz(cast(char*)errorBlob.GetBufferPointer());
                debugPrint("Pixel shader compile error:\n" ~ errorMsg);
                errorBlob.Release();
                errorBlob = null;
            }
            throw new D3D12Exception("Unable to compile pixel shader");
        }
        debugPrint("CreatePipelineStates: PSMain compiled successfully");

        // Create compute pipeline state
        debugPrint("CreatePipelineStates: Creating Compute Pipeline State...");
        D3D12_COMPUTE_PIPELINE_STATE_DESC computePsoDesc;
        computePsoDesc.pRootSignature = computeRootSignature;
        computePsoDesc.CS = D3D12_SHADER_BYTECODE(computeShader.GetBufferPointer(), computeShader.GetBufferSize());

        hr = device.CreateComputePipelineState(&computePsoDesc, &IID_ID3D12PipelineState, &computePipelineState);
        if (FAILED(hr))
        {
            debugPrintHR("CreatePipelineStates: CreateComputePipelineState failed", hr);
            throw new D3D12Exception("Failed to create compute pipeline state");
        }
        debugPrint("CreatePipelineStates: Compute Pipeline State created successfully");

        // Create graphics pipeline state
        debugPrint("CreatePipelineStates: Creating Graphics Pipeline State...");
        D3D12_GRAPHICS_PIPELINE_STATE_DESC graphicsPsoDesc;
        graphicsPsoDesc.pRootSignature = graphicsRootSignature;
        graphicsPsoDesc.VS = D3D12_SHADER_BYTECODE(vertexShader.GetBufferPointer(), vertexShader.GetBufferSize());
        graphicsPsoDesc.PS = D3D12_SHADER_BYTECODE(pixelShader.GetBufferPointer(), pixelShader.GetBufferSize());
        graphicsPsoDesc.RasterizerState = D3D12_RASTERIZER_DESC();
        graphicsPsoDesc.RasterizerState.CullMode = D3D12_CULL_MODE_NONE;

        D3D12_RENDER_TARGET_BLEND_DESC[8] renderTargetBlendDescs;
        foreach (i; 0 .. 8)
        {
            renderTargetBlendDescs[i] = D3D12_RENDER_TARGET_BLEND_DESC(
                FALSE, FALSE,
                D3D12_BLEND_ONE, D3D12_BLEND_ZERO, D3D12_BLEND_OP_ADD,
                D3D12_BLEND_ONE, D3D12_BLEND_ZERO, D3D12_BLEND_OP_ADD,
                D3D12_LOGIC_OP_NOOP, D3D12_COLOR_WRITE_ENABLE_ALL
            );
        }

        graphicsPsoDesc.BlendState = D3D12_BLEND_DESC(FALSE, FALSE, renderTargetBlendDescs);
        graphicsPsoDesc.DepthStencilState.DepthEnable = FALSE;
        graphicsPsoDesc.DepthStencilState.StencilEnable = FALSE;
        graphicsPsoDesc.SampleMask = uint.max;
        graphicsPsoDesc.PrimitiveTopologyType = D3D12_PRIMITIVE_TOPOLOGY_TYPE_LINE;
        graphicsPsoDesc.NumRenderTargets = 1;
        graphicsPsoDesc.RTVFormats[0] = DXGI_FORMAT_R8G8B8A8_UNORM;
        graphicsPsoDesc.SampleDesc.Count = 1;

        hr = device.CreateGraphicsPipelineState(&graphicsPsoDesc, &IID_ID3D12PipelineState, &graphicsPipelineState);
        if (FAILED(hr))
        {
            debugPrintHR("CreatePipelineStates: CreateGraphicsPipelineState failed", hr);
            throw new D3D12Exception("Failed to create graphics pipeline state");
        }
        debugPrint("CreatePipelineStates: Graphics Pipeline State created successfully");
        
        debugPrint("CreatePipelineStates: Complete");
    }

    void WaitForPreviousFrame()
    {
        const ulong lfence = fenceValue;
        if (FAILED(commandQueue.Signal(fence, lfence)))
        {
            throw new D3D12Exception("Command queue signal failed");
        }
        fenceValue++;

        if (fence.GetCompletedValue() < lfence)
        {
            if (FAILED(fence.SetEventOnCompletion(lfence, fenceEvent)))
            {
                throw new D3D12Exception("Failed to set fence completion event");
            }
            WaitForSingleObject(fenceEvent, INFINITE);
        }

        frameIndex = swapChain.GetCurrentBackBufferIndex();
    }

    void OnUpdate(float deltaSec)
    {
        // Animate harmonograph parameters
        params.f1 = fmodf(params.f1 + uniform(0.0f, 1.0f) / 40.0f, 10.0f);
        params.f2 = fmodf(params.f2 + uniform(0.0f, 1.0f) / 40.0f, 10.0f);
        params.f3 = fmodf(params.f3 + uniform(0.0f, 1.0f) / 40.0f, 10.0f);
        params.f4 = fmodf(params.f4 + uniform(0.0f, 1.0f) / 40.0f, 10.0f);
        params.p1 += PI2 * 0.5f / 360.0f;

        // Update constant buffer
        memcpy(constantBufferData, &params, HarmonographParams.sizeof);

        OnRender();
    }

    void OnRender()
    {
        // Execute compute pass
        PopulateComputeCommandList();
        ID3D12CommandList[] computeLists = [computeCommandList];
        commandQueue.ExecuteCommandLists(1, computeLists.ptr);
        WaitForPreviousFrame();

        // Execute graphics pass
        PopulateGraphicsCommandList();
        ID3D12CommandList[] graphicsLists = [graphicsCommandList];
        commandQueue.ExecuteCommandLists(1, graphicsLists.ptr);

        if (FAILED(swapChain.Present(1, 0)))
        {
            throw new D3D12Exception("Swapchain present error");
        }

        WaitForPreviousFrame();
    }

    void PopulateComputeCommandList()
    {
        if (FAILED(computeCommandAllocator.Reset()))
        {
            throw new D3D12Exception("Failed to reset compute command allocator");
        }

        if (FAILED(computeCommandList.Reset(computeCommandAllocator, computePipelineState)))
        {
            throw new D3D12Exception("Failed to reset compute command list");
        }

        computeCommandList.SetComputeRootSignature(computeRootSignature);

        ID3D12DescriptorHeap[] heaps = [srvUavHeap];
        computeCommandList.SetDescriptorHeaps(1, heaps.ptr);

        auto gpuHandle = srvUavHeap.GetGPUDescriptorHandleForHeapStart();
        computeCommandList.SetComputeRootDescriptorTable(0, gpuHandle);

        computeCommandList.Dispatch((VERTEX_COUNT + 63) / 64, 1, 1);

        // UAV barrier
        D3D12_RESOURCE_BARRIER[2] uavBarriers;
        uavBarriers[0].Type = D3D12_RESOURCE_BARRIER_TYPE_UAV;
        uavBarriers[0].Flags = D3D12_RESOURCE_BARRIER_FLAG_NONE;
        uavBarriers[0].UAV.pResource = positionBuffer;
        uavBarriers[1].Type = D3D12_RESOURCE_BARRIER_TYPE_UAV;
        uavBarriers[1].Flags = D3D12_RESOURCE_BARRIER_FLAG_NONE;
        uavBarriers[1].UAV.pResource = colorBuffer;

        computeCommandList.ResourceBarrier(2, uavBarriers.ptr);

        if (FAILED(computeCommandList.Close()))
        {
            throw new D3D12Exception("Failed to close compute command list");
        }
    }

    void PopulateGraphicsCommandList()
    {
        if (FAILED(graphicsCommandAllocator.Reset()))
        {
            throw new D3D12Exception("Failed to reset graphics command allocator");
        }

        if (FAILED(graphicsCommandList.Reset(graphicsCommandAllocator, graphicsPipelineState)))
        {
            throw new D3D12Exception("Failed to reset graphics command list");
        }

        graphicsCommandList.SetGraphicsRootSignature(graphicsRootSignature);

        ID3D12DescriptorHeap[] heaps = [srvUavHeap];
        graphicsCommandList.SetDescriptorHeaps(1, heaps.ptr);

        // Set SRV table (offset to SRV position)
        auto gpuHandle = srvUavHeap.GetGPUDescriptorHandleForHeapStart();
        gpuHandle.ptr += srvUavDescriptorSize * 3; // Skip UAVs and CBV
        graphicsCommandList.SetGraphicsRootDescriptorTable(0, gpuHandle);

        // Set CBV table
        gpuHandle = srvUavHeap.GetGPUDescriptorHandleForHeapStart();
        gpuHandle.ptr += srvUavDescriptorSize * 2; // Skip UAVs
        graphicsCommandList.SetGraphicsRootDescriptorTable(1, gpuHandle);

        graphicsCommandList.RSSetViewports(1, &viewport);
        graphicsCommandList.RSSetScissorRects(1, &scissorRect);

        // Transition render target to render target state
        D3D12_RESOURCE_BARRIER resBarrier;
        resBarrier.Type = D3D12_RESOURCE_BARRIER_TYPE_TRANSITION;
        resBarrier.Flags = D3D12_RESOURCE_BARRIER_FLAG_NONE;
        resBarrier.Transition.pResource = renderTargets[frameIndex];
        resBarrier.Transition.StateBefore = D3D12_RESOURCE_STATE_PRESENT;
        resBarrier.Transition.StateAfter = D3D12_RESOURCE_STATE_RENDER_TARGET;
        resBarrier.Transition.Subresource = D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES;
        graphicsCommandList.ResourceBarrier(1, &resBarrier);

        auto rtvHandle = D3D12_CPU_DESCRIPTOR_HANDLE(
            cast(size_t)(rtvHeap.GetCPUDescriptorHandleForHeapStart().ptr +
            cast(void*)(frameIndex * rtvDescriptorSize))
        );

        const float[4] clearColor = [0.0f, 0.0f, 0.0f, 1.0f];
        graphicsCommandList.ClearRenderTargetView(rtvHandle, clearColor.ptr, 0, null);
        graphicsCommandList.OMSetRenderTargets(1, &rtvHandle, FALSE, null);
        graphicsCommandList.IASetPrimitiveTopology(D3D_PRIMITIVE_TOPOLOGY_LINESTRIP);
        graphicsCommandList.DrawInstanced(VERTEX_COUNT, 1, 0, 0);

        // Transition render target to present state
        resBarrier.Transition.StateBefore = D3D12_RESOURCE_STATE_RENDER_TARGET;
        resBarrier.Transition.StateAfter = D3D12_RESOURCE_STATE_PRESENT;
        graphicsCommandList.ResourceBarrier(1, &resBarrier);

        if (FAILED(graphicsCommandList.Close()))
        {
            throw new D3D12Exception("Failed to close graphics command list");
        }
    }

    void OnResize(int w, int h)
    {
        viewport.Width = w;
        viewport.Height = h;
        scissorRect.left = 0;
        scissorRect.top = 0;
        scissorRect.right = w;
        scissorRect.bottom = h;
    }

    void OnDestroy()
    {
        debugPrint("OnDestroy: Starting cleanup...");
        
        WaitForPreviousFrame();
        CloseHandle(fenceEvent);

        constantBuffer.Unmap(0, null);

        if (computeCommandList) computeCommandList.Release();
        if (graphicsCommandList) graphicsCommandList.Release();
        if (computeCommandAllocator) computeCommandAllocator.Release();
        if (graphicsCommandAllocator) graphicsCommandAllocator.Release();
        if (computePipelineState) computePipelineState.Release();
        if (graphicsPipelineState) graphicsPipelineState.Release();
        if (computeRootSignature) computeRootSignature.Release();
        if (graphicsRootSignature) graphicsRootSignature.Release();
        if (constantBuffer) constantBuffer.Release();
        if (positionBuffer) positionBuffer.Release();
        if (colorBuffer) colorBuffer.Release();
        if (srvUavHeap) srvUavHeap.Release();
        foreach (rt; renderTargets)
            if (rt) rt.Release();
        if (rtvHeap) rtvHeap.Release();
        if (swapChain) swapChain.Release();
        if (fence) fence.Release();
        if (commandQueue) commandQueue.Release();
        if (device) device.Release();
        
        debugPrint("OnDestroy: Cleanup complete");
    }

private:
    static enum frameCount = 2;

    uint width;
    uint height;
    HWND hWnd;

    HarmonographParams params;
    HarmonographParams* constantBufferData;

    D3D12_VIEWPORT viewport;
    D3D12_RECT scissorRect;

    // Device and swap chain
    ID3D12Device device;
    IDXGISwapChain3 swapChain;
    ID3D12CommandQueue commandQueue;

    // Descriptor heaps
    ID3D12DescriptorHeap rtvHeap;
    ID3D12DescriptorHeap srvUavHeap;
    uint rtvDescriptorSize;
    uint srvUavDescriptorSize;

    // Resources
    ID3D12Resource[frameCount] renderTargets;
    ID3D12Resource positionBuffer;
    ID3D12Resource colorBuffer;
    ID3D12Resource constantBuffer;

    // Pipeline
    ID3D12RootSignature computeRootSignature;
    ID3D12RootSignature graphicsRootSignature;
    ID3D12PipelineState computePipelineState;
    ID3D12PipelineState graphicsPipelineState;

    // Command infrastructure
    ID3D12CommandAllocator graphicsCommandAllocator;
    ID3D12CommandAllocator computeCommandAllocator;
    ID3D12GraphicsCommandList graphicsCommandList;
    ID3D12GraphicsCommandList computeCommandList;

    // Synchronization
    uint frameIndex;
    HANDLE fenceEvent;
    ID3D12Fence fence;
    ulong fenceValue;
}

// ============================================================
// Helper Functions
// ============================================================
private void GetHardwareAdapter(IDXGIFactory2 pFactory, ref IDXGIAdapter1 ppAdapter)
{
    debugPrint("GetHardwareAdapter: Searching for hardware adapter...");
    
    IDXGIAdapter1 adapter;
    ppAdapter = null;

    for (uint adapterIndex = 0; DXGI_ERROR_NOT_FOUND != pFactory.EnumAdapters1(adapterIndex, &adapter); ++adapterIndex)
    {
        DXGI_ADAPTER_DESC1 desc;
        adapter.GetDesc1(&desc);

        if (desc.Flags & DXGI_ADAPTER_FLAG_SOFTWARE)
        {
            continue;
        }

        if (SUCCEEDED(D3D12CreateDevice(adapter, D3D_FEATURE_LEVEL_11_0, &IID_ID3D12Device, null)))
        {
            // Convert description to string for debug output
            wchar[128] descStr;
            descStr[] = desc.Description[];
            import std.utf : toUTF8;
            debugPrint("GetHardwareAdapter: Found adapter: " ~ toUTF8(descStr[0..128]));
            break;
        }
    }

    ppAdapter = adapter;
}

class D3D12Exception : Exception
{
    this() { super("D3D12 exception"); }
    this(string msg) { super(msg); }
}

// ============================================================
// Window Management
// ============================================================
alias RefWindow = RefCounted!Window;

struct Window
{
    private enum WndClassName = "HarmonographWndClass"w;

    static RefWindow Create(wstring Title = "DirectX 12 Compute Harmonograph"w, int Width = WIDTH, int Height = HEIGHT)
    {
        debugPrint("Window.Create: Creating window...");
        
        HINSTANCE hInst = GetModuleHandle(null);
        WNDCLASS wc;

        wc.lpszClassName = WndClassName.ptr;
        wc.style = CS_OWNDC | CS_HREDRAW | CS_VREDRAW;
        wc.lpfnWndProc = &WindowProc;
        wc.hInstance = hInst;
        wc.hIcon = LoadIcon(cast(HINSTANCE)null, IDI_APPLICATION);
        wc.hCursor = LoadCursor(cast(HINSTANCE)null, IDC_ARROW);
        wc.hbrBackground = cast(HBRUSH)(COLOR_WINDOW + 1);
        wc.lpszMenuName = null;
        wc.cbClsExtra = wc.cbWndExtra = 0;

        const auto wclass = RegisterClass(&wc);
        assert(wclass);

        HWND hWnd = CreateWindow(
            WndClassName.ptr, Title.ptr,
            WS_THICKFRAME | WS_MAXIMIZEBOX | WS_MINIMIZEBOX | WS_SYSMENU | WS_VISIBLE,
            CW_USEDEFAULT, CW_USEDEFAULT, Width, Height,
            HWND_DESKTOP, cast(HMENU)null, hInst, null
        );
        assert(hWnd);

        RefWindow window;
        window.hWnd = hWnd;
        windowMap[hWnd] = window;

        debugPrint("Window.Create: Window created successfully");
        return window;
    }

    HWND hWnd;
    D3D12Harmonograph demoInstance;

    package static RefWindow[HWND] windowMap;
}

extern(Windows)
LRESULT WindowProc(HWND hWnd, uint uMsg, WPARAM wParam, LPARAM lParam) nothrow
{
    switch (uMsg)
    {
        case WM_KEYDOWN:
            if (wParam == VK_ESCAPE)
            {
                PostQuitMessage(0);
                return 0;
            }
            break;

        case WM_DESTROY:
            PostQuitMessage(0);
            break;

        default:
            break;
    }

    return DefWindowProc(hWnd, uMsg, wParam, lParam);
}

// ============================================================
// Entry Point
// ============================================================
extern(Windows)
int WinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, LPSTR lpCmdLine, int nCmdShow)
{
    int result;

    try
    {
        Runtime.initialize();
        result = myWinMain();
        Runtime.terminate();
    }
    catch (Exception e)
    {
        import std.utf : toUTF16z;
        debugPrint("Exception: " ~ e.msg);
        MessageBox(null, to!wstring(e.msg).toUTF16z(), "Error"w.ptr, MB_OK | MB_ICONEXCLAMATION);
        result = 0;
    }

    return result;
}

int myWinMain()
{
    debugPrint("=== Application Starting ===");
    
    auto startTime = Clock.currTime();
    auto lastTime = startTime;

    auto window = Window.Create();
    auto example = new D3D12Harmonograph(WIDTH, HEIGHT, window.hWnd);
    window.demoInstance = example;

    debugPrint("=== Entering Main Loop ===");
    
    MSG msg;
    while (true)
    {
        auto timeNow = Clock.currTime();
        auto deltaTime = (timeNow - lastTime).total!"msecs" / 1000.0f;
        lastTime = timeNow;

        if (PeekMessage(&msg, cast(HWND)null, 0, 0, PM_REMOVE))
        {
            TranslateMessage(&msg);
            DispatchMessage(&msg);

            if (msg.message == WM_QUIT)
                break;
        }

        example.OnUpdate(deltaTime);

        Thread.sleep(dur!"msecs"(1));
    }

    debugPrint("=== Exiting Main Loop ===");
    
    example.OnDestroy();

    debugPrint("=== Application Terminated ===");
    
    return 1;
}