// forked from https://github.com/evilrat666/directx-d/blob/master/examples/d3d12_hello/source/d3d12_hello.d

import core.stdc.string : memcpy;
import std.stdio;
import std.string : toStringz, format;
import std.conv : to;

import directx.d3d12;
import directx.d3d12sdklayers;
import directx.dxgi1_4;
import directx.d3dcompiler;

import core.runtime;
import core.thread;
import core.sys.windows.windows;
import std.typecons;
import std.string;

// Debug output helper
extern (Windows) void OutputDebugStringW(const(wchar)* lpOutputString);

void DebugLog(string message)
{
    import std.utf : toUTF16z;
    try {
        writeln("[DEBUG] ", message);
    } catch (Exception e) {
        // Ignore console write errors
    }
    auto wstr = format("[%d] %s\0", GetCurrentProcessId(), message).toUTF16z();
    OutputDebugStringW(wstr);
}

class D3D12Hello
{
    this(uint width, uint height, HWND hWnd)
    {
        this.hWnd = hWnd;
        this.width = width;
        this.height = height;

        viewport.MinDepth = 0.0f;
        viewport.MaxDepth = 1.0f;
        OnResize(width, height);

        LoadPipeline();
        LoadAssets();
    }

    void LoadPipeline()
    {
        DebugLog("LoadPipeline: Starting");

        // Enable debug layer
        ID3D12Debug debugController;
        if (SUCCEEDED(D3D12GetDebugInterface(&IID_ID3D12Debug, cast(void**)&debugController)))
        {
            DebugLog("LoadPipeline: Debug interface obtained");
            debugController.EnableDebugLayer();
            DebugLog("LoadPipeline: Debug layer enabled");
            debugController.Release();
        }

        IDXGIFactory4 factory;
        scope(exit)
            if (factory)
                factory.Release();

        DebugLog("LoadPipeline: Creating DXGI Factory");
        if(FAILED(CreateDXGIFactory1(&IID_IDXGIFactory4, cast(void**)&factory)))
        {
            throw new D3D12Exception("Create DXGI Factory failed");
        }

        IDXGIAdapter1 hardwareAdapter;
        scope(exit)
            if (hardwareAdapter)
                hardwareAdapter.Release();

        DebugLog("LoadPipeline: Getting hardware adapter");
        GetHardwareAdapter(factory, hardwareAdapter);

        DebugLog("LoadPipeline: Creating device");
        if(FAILED(D3D12CreateDevice(hardwareAdapter, D3D_FEATURE_LEVEL_11_0, &IID_ID3D12Device,&device)))
        {
            throw new D3D12Exception("Create device failed");
        }

        DebugLog("LoadPipeline: Device created");

        D3D12_COMMAND_QUEUE_DESC queueDesc;
        queueDesc.Flags = D3D12_COMMAND_QUEUE_FLAG_NONE;
        queueDesc.Type  = D3D12_COMMAND_LIST_TYPE_DIRECT;

        DebugLog("LoadPipeline: Creating command queue");
        if (FAILED(device.CreateCommandQueue(&queueDesc, &IID_ID3D12CommandQueue, &commandQueue)))
        {
            throw new D3D12Exception("CreateCommandQueue failed");
        }

        DebugLog("LoadPipeline: Command queue created");

        DXGI_SWAP_CHAIN_DESC swapChainDesc;
        swapChainDesc.BufferCount       = frameCount;
        swapChainDesc.BufferDesc.Width  = width;
        swapChainDesc.BufferDesc.Height = height;
        swapChainDesc.BufferDesc.Format = DXGI_FORMAT_R8G8B8A8_UNORM;
        swapChainDesc.BufferUsage       = DXGI_USAGE_RENDER_TARGET_OUTPUT;
        swapChainDesc.SwapEffect        = DXGI_SWAP_EFFECT_FLIP_DISCARD;
        swapChainDesc.OutputWindow      = hWnd;
        swapChainDesc.SampleDesc.Count  = 1;
        swapChainDesc.Windowed          = TRUE;

        IDXGISwapChain swapChain;
        scope(exit) if (swapChain) swapChain.Release();

        DebugLog("LoadPipeline: Creating swap chain");
        if (FAILED(factory.CreateSwapChain(commandQueue, &swapChainDesc, &swapChain)))
        {
            throw new D3D12Exception("Init swapchain failed");
        }

        this.swapChain = cast(IDXGISwapChain3)swapChain;
        if( !this.swapChain )
        {
            throw new D3D12Exception("failed to assign swap chain");
        }

        if (FAILED(factory.MakeWindowAssociation(null, DXGI_MWA_NO_ALT_ENTER)))
        {
            throw new D3D12Exception("Window association error");
        }

        frameIndex = this.swapChain.GetCurrentBackBufferIndex();

        DebugLog("LoadPipeline: Creating RTV descriptor heap");
        {
            D3D12_DESCRIPTOR_HEAP_DESC rtvHeapDesc;
            rtvHeapDesc.NumDescriptors = frameCount;
            rtvHeapDesc.Type  = D3D12_DESCRIPTOR_HEAP_TYPE_RTV;
            rtvHeapDesc.Flags = D3D12_DESCRIPTOR_HEAP_FLAG_NONE;
            auto hr = device.CreateDescriptorHeap(&rtvHeapDesc, &IID_ID3D12DescriptorHeap, &rtvHeap);
            if (FAILED(hr))
            {
                throw new D3D12Exception("failed to create descriptor heap");
            }

            rtvDescriptorSize = device.GetDescriptorHandleIncrementSize(D3D12_DESCRIPTOR_HEAP_TYPE_RTV);
            DebugLog("LoadPipeline: RTV descriptor size = " ~ to!string(rtvDescriptorSize));
        }

        DebugLog("LoadPipeline: Creating render target views");
        {
            D3D12_CPU_DESCRIPTOR_HANDLE rtvHandle = rtvHeap.GetCPUDescriptorHandleForHeapStart();

            for (UINT n = 0; n < frameCount; n++)
            {
                if (FAILED(swapChain.GetBuffer(n, &IID_ID3D12Resource, cast(void**)&renderTargets[n])))
                {
                    throw new D3D12Exception("failed to create frame resource N=" ~ to!string(n));
                }

                device.CreateRenderTargetView(renderTargets[n], null, rtvHandle);
                rtvHandle.ptr += cast(size_t)(1 * rtvDescriptorSize);
            }
        }

        DebugLog("LoadPipeline: Creating command allocator");
        if (FAILED(device.CreateCommandAllocator(D3D12_COMMAND_LIST_TYPE_DIRECT, &IID_ID3D12CommandAllocator, &commandAllocator)))
        {
            throw new D3D12Exception("failed to create command allocators");
        }

        DebugLog("LoadPipeline: Completed successfully");
    }

    void LoadAssets()
    {
        DebugLog("LoadAssets: Starting");

        // Create Root Signature
        {
            DebugLog("LoadAssets: Creating root signature");
            D3D12_ROOT_PARAMETER[1] rootParams;
            rootParams[0].ParameterType = D3D12_ROOT_PARAMETER_TYPE_CBV;
            rootParams[0].Descriptor.ShaderRegister = 0;
            rootParams[0].Descriptor.RegisterSpace = 0;
            rootParams[0].ShaderVisibility = D3D12_SHADER_VISIBILITY_ALL;  // Changed from VERTEX to ALL

            D3D12_ROOT_SIGNATURE_DESC rootSignatureDesc;
            rootSignatureDesc.NumParameters = rootParams.length;
            rootSignatureDesc.pParameters = rootParams.ptr;
            rootSignatureDesc.NumStaticSamplers = 0;
            rootSignatureDesc.pStaticSamplers = null;
            rootSignatureDesc.Flags = D3D12_ROOT_SIGNATURE_FLAG_ALLOW_INPUT_ASSEMBLER_INPUT_LAYOUT;

            ID3DBlob signature;
            ID3DBlob error;
            scope(exit) { if (signature) signature.Release(); if (error) error.Release(); }
            if (FAILED(D3D12SerializeRootSignature(&rootSignatureDesc, D3D_ROOT_SIGNATURE_VERSION_1, &signature, &error)))
            {
                throw new D3D12Exception("Unable to serialize root signature");
            }
            if (FAILED(device.CreateRootSignature(0, signature.GetBufferPointer(), signature.GetBufferSize(), &IID_ID3D12RootSignature, &rootSignature)))
            {
                throw new D3D12Exception("Unable to create root signature");
            }
            DebugLog("LoadAssets: Root signature created");
        }

        // Compile shaders
        {
            DebugLog("LoadAssets: Compiling shaders");
            try {
                import std.file : getcwd;
                DebugLog("Current directory: " ~ getcwd());
            } catch (Exception e) {
                DebugLog("Could not get current directory: " ~ e.msg);
            }
            ID3DBlob vertexShader;
            ID3DBlob pixelShader;
            ID3DBlob errorBlob;
            scope(exit)
            {
                if(vertexShader) vertexShader.Release();
                if(pixelShader) pixelShader.Release();
                if(errorBlob) errorBlob.Release();
            }

            UINT compileFlags = D3DCOMPILE_DEBUG | D3DCOMPILE_SKIP_OPTIMIZATION;

            DebugLog("LoadAssets: Compiling vertex shader");
            auto vsResult = D3DCompileFromFile("hello.hlsl", null, null, "VSMain", vs_5_0, compileFlags, 0, &vertexShader, &errorBlob);
            if (FAILED(vsResult))
            {
                DebugLog(format("VS Compilation failed: HRESULT=0x%08x", vsResult));
                if (errorBlob)
                {
                    char* errorMsg = cast(char*)errorBlob.GetBufferPointer();
                    string errStr = (cast(char[])errorMsg[0..errorBlob.GetBufferSize()]).idup;
                    DebugLog("Vertex shader compilation error: " ~ errStr);
                    throw new D3D12Exception("Vertex shader compile error: " ~ errStr);
                }
                else
                {
                    DebugLog("VS: No error blob, file may not exist");
                    throw new D3D12Exception("unable to compile vertex shader (file not found?)");
                }
            }
            DebugLog("LoadAssets: Vertex shader compiled successfully");

            if (errorBlob) 
            {
                errorBlob.Release();
                errorBlob = null;
            }

            DebugLog("LoadAssets: Compiling pixel shader");
            auto psResult = D3DCompileFromFile("source/hello.hlsl", null, null, "PSMain", ps_5_0, compileFlags, 0, &pixelShader, &errorBlob);
            if (FAILED(psResult))
            {
                DebugLog(format("PS Compilation failed: HRESULT=0x%08x", psResult));
                if (errorBlob)
                {
                    char* errorMsg = cast(char*)errorBlob.GetBufferPointer();
                    string errStr = (cast(char[])errorMsg[0..errorBlob.GetBufferSize()]).idup;
                    DebugLog("Pixel shader compilation error: " ~ errStr);
                    throw new D3D12Exception("Pixel shader compile error: " ~ errStr);
                }
                else
                {
                    DebugLog("PS: No error blob, file may not exist");
                    throw new D3D12Exception("unable to compile pixel shader (file not found?)");
                }
            }
            DebugLog("LoadAssets: Pixel shader compiled successfully");

            D3D12_INPUT_ELEMENT_DESC[] inputElementDescs =
            [
                { "POSITION", 0, DXGI_FORMAT_R32G32_FLOAT, 0, 0, D3D12_INPUT_CLASSIFICATION_PER_VERTEX_DATA, 0 }
            ];

            DebugLog("LoadAssets: Creating graphics pipeline state");

            D3D12_GRAPHICS_PIPELINE_STATE_DESC psoDesc;
            psoDesc.InputLayout           = D3D12_INPUT_LAYOUT_DESC( inputElementDescs.ptr, cast(uint)inputElementDescs.length );
            psoDesc.pRootSignature        = rootSignature;
            psoDesc.VS                    = D3D12_SHADER_BYTECODE ( vertexShader.GetBufferPointer(), vertexShader.GetBufferSize() );
            psoDesc.PS                    = D3D12_SHADER_BYTECODE ( pixelShader.GetBufferPointer(), pixelShader.GetBufferSize() );
            
            // Disable culling to see both front and back faces
            auto rasterizerDesc = D3D12_RASTERIZER_DESC();
            rasterizerDesc.CullMode = D3D12_CULL_MODE_NONE;
            psoDesc.RasterizerState       = rasterizerDesc;

            D3D12_RENDER_TARGET_BLEND_DESC[8] renderTargetBlendDescs;

            renderTargetBlendDescs[0] = D3D12_RENDER_TARGET_BLEND_DESC(
                FALSE, FALSE,
                D3D12_BLEND_ONE, D3D12_BLEND_ZERO, D3D12_BLEND_OP_ADD,
                D3D12_BLEND_ONE, D3D12_BLEND_ZERO, D3D12_BLEND_OP_ADD,
                D3D12_LOGIC_OP_NOOP, D3D12_COLOR_WRITE_ENABLE_ALL
            );

            foreach (i; 1 .. 8)
            {
                renderTargetBlendDescs[i] = D3D12_RENDER_TARGET_BLEND_DESC(
                    FALSE, FALSE,
                    D3D12_BLEND_ONE, D3D12_BLEND_ZERO, D3D12_BLEND_OP_ADD,
                    D3D12_BLEND_ONE, D3D12_BLEND_ZERO, D3D12_BLEND_OP_ADD,
                    D3D12_LOGIC_OP_NOOP, D3D12_COLOR_WRITE_ENABLE_ALL
                );
            }

            psoDesc.BlendState = D3D12_BLEND_DESC(
                FALSE, FALSE,
                renderTargetBlendDescs
            );

            psoDesc.DepthStencilState.DepthEnable   = FALSE;
            psoDesc.DepthStencilState.StencilEnable = FALSE;
            psoDesc.SampleMask            = UINT.max;
            psoDesc.PrimitiveTopologyType = D3D12_PRIMITIVE_TOPOLOGY_TYPE_TRIANGLE;
            psoDesc.NumRenderTargets      = 1;
            psoDesc.RTVFormats[0]         = DXGI_FORMAT_R8G8B8A8_UNORM;
            psoDesc.SampleDesc.Count      = 1;

            DebugLog(format("LoadAssets: PSO: NumRenderTargets=%d", psoDesc.NumRenderTargets));
            DebugLog(format("LoadAssets: PSO: RTVFormat=%d", psoDesc.RTVFormats[0]));
            DebugLog(format("LoadAssets: PSO: SampleCount=%d", psoDesc.SampleDesc.Count));

            auto psoResult = device.CreateGraphicsPipelineState(&psoDesc, &IID_ID3D12PipelineState, &pipelineState);
            
            if (FAILED(psoResult))
            {
                DebugLog(format("LoadAssets: Pipeline state creation failed with HRESULT=0x%08x", psoResult));
                throw new D3D12Exception("unable to create pipeline state");
            }

            DebugLog("LoadAssets: Graphics pipeline state created successfully");
        }

        // Create the command list
        DebugLog("LoadAssets: Creating command list");
        if (FAILED(device.CreateCommandList(0u, D3D12_COMMAND_LIST_TYPE_DIRECT, commandAllocator, pipelineState, &IID_ID3D12GraphicsCommandList, cast(ID3D12CommandList*)&commandList)))
        {
            throw new D3D12Exception("failed to create command lists");
        }

        if (FAILED(commandList.Close()))
        {
            throw new D3D12Exception("failed to close command list");
        }

        DebugLog("LoadAssets: Command list created");

        // Create vertex buffer
        {
            DebugLog("LoadAssets: Creating vertex buffer");
            if ( height < 1) height = 1;

            // Full-screen quad: 2 triangles (6 vertices)
            Vertex[] quadVertices =
            [
                { [ -1.0f, -1.0f ] },
                { [  1.0f, -1.0f ] },
                { [ -1.0f,  1.0f ] },
                { [  1.0f, -1.0f ] },
                { [  1.0f,  1.0f ] },
                { [ -1.0f,  1.0f ] }
            ];

            const UINT vertexBufferSize = cast(UINT)(quadVertices.length * Vertex.sizeof);

            auto heapProperties = D3D12_HEAP_PROPERTIES(D3D12_HEAP_TYPE_UPLOAD, D3D12_CPU_PAGE_PROPERTY_UNKNOWN, D3D12_MEMORY_POOL_UNKNOWN, 1, 1);
            auto resourceDesc = D3D12_RESOURCE_DESC(D3D12_RESOURCE_DIMENSION_BUFFER, 0, vertexBufferSize, 1, 1, 1,DXGI_FORMAT_UNKNOWN, DXGI_SAMPLE_DESC(1,0), D3D12_TEXTURE_LAYOUT_ROW_MAJOR, D3D12_RESOURCE_FLAG_NONE);
            if (FAILED(device.CreateCommittedResource(
                    &heapProperties,
                    D3D12_HEAP_FLAG_NONE,
                    &resourceDesc,
                    D3D12_RESOURCE_STATE_GENERIC_READ,
                    null,
                    &IID_ID3D12Resource,
                    &vertexBuffer)))
            {
                throw new D3D12Exception("failed to vertex buffer resource");
            }

            ubyte* pVertexDataBegin;
            auto readRange = D3D12_RANGE(0, 0);
            if (FAILED(vertexBuffer.Map(0, &readRange, cast(void**)&pVertexDataBegin)))
            {
                throw new D3D12Exception("failed to map vertex buffer");
            }

            memcpy(pVertexDataBegin, quadVertices.ptr, vertexBufferSize);
            vertexBuffer.Unmap(0, null);

            vertexBufferView.BufferLocation = vertexBuffer.GetGPUVirtualAddress();
            vertexBufferView.StrideInBytes = Vertex.sizeof;
            vertexBufferView.SizeInBytes = vertexBufferSize;

            DebugLog(format("LoadAssets: Vertex buffer created, size=%d bytes", vertexBufferSize));
        }

        // Create constant buffer for raymarching parameters
        {
            DebugLog("LoadAssets: Creating constant buffer");
            const UINT constantBufferSize = cast(UINT)((ConstantBuffer.sizeof + 255) & ~255); // Align to 256 bytes

            auto heapProperties = D3D12_HEAP_PROPERTIES(D3D12_HEAP_TYPE_UPLOAD, D3D12_CPU_PAGE_PROPERTY_UNKNOWN, D3D12_MEMORY_POOL_UNKNOWN, 1, 1);
            auto resourceDesc = D3D12_RESOURCE_DESC(D3D12_RESOURCE_DIMENSION_BUFFER, 0, constantBufferSize, 1, 1, 1, DXGI_FORMAT_UNKNOWN, DXGI_SAMPLE_DESC(1,0), D3D12_TEXTURE_LAYOUT_ROW_MAJOR, D3D12_RESOURCE_FLAG_NONE);
            
            if (FAILED(device.CreateCommittedResource(
                    &heapProperties,
                    D3D12_HEAP_FLAG_NONE,
                    &resourceDesc,
                    D3D12_RESOURCE_STATE_GENERIC_READ,
                    null,
                    &IID_ID3D12Resource,
                    &constantBuffer)))
            {
                throw new D3D12Exception("failed to create constant buffer");
            }

            auto readRange = D3D12_RANGE(0, 0);
            if (FAILED(constantBuffer.Map(0, &readRange, cast(void**)&pConstantBufferDataBegin)))
            {
                throw new D3D12Exception("failed to map constant buffer");
            }

            constantBufferGPUAddress = constantBuffer.GetGPUVirtualAddress();
            DebugLog(format("LoadAssets: Constant buffer created, size=%d bytes", constantBufferSize));
        }

        // Create fence
        {
            DebugLog("LoadAssets: Creating fence");
            if (FAILED(device.CreateFence(0, D3D12_FENCE_FLAG_NONE, &IID_ID3D12Fence, &fence)))
            {
                throw new D3D12Exception("failed to create fence");
            }
            fenceValue = 1;

            fenceEvent = CreateEvent(null, FALSE, FALSE, null);
            if (fenceEvent == null)
            {
                if (FAILED(HRESULT_FROM_WIN32(GetLastError())))
                {
                    throw new D3D12Exception("failed to fence event");
                }
            }

            DebugLog("LoadAssets: Fence created");
            WaitForPreviousFrame();
            DebugLog("LoadAssets: Completed successfully");
        }
    }


    void WaitForPreviousFrame()
    {
        static int callCount = 0;
        callCount++;
        if (callCount == 1 || callCount % 120 == 0)  // Log first call and every 120 calls
            DebugLog(format("WaitForPreviousFrame: call #%d", callCount));
            
        const UINT64 lfence = fenceValue;
        if (FAILED(commandQueue.Signal(fence, lfence)))
        {
            throw new D3D12Exception("command queue signal fail");
        }
        fenceValue++;

        if (fence.GetCompletedValue() < lfence)
        {
            if (FAILED(fence.SetEventOnCompletion(lfence, fenceEvent)))
            {
                throw new D3D12Exception("failed to set fence completion event");
            }
            WaitForSingleObject(fenceEvent, INFINITE);
        }

        frameIndex = swapChain.GetCurrentBackBufferIndex();
    }

    void PopulateCommandList()
    {
        static int populateCount = 0;
        populateCount++;
        if (populateCount <= 5 || populateCount % 60 == 0)
            DebugLog(format("PopulateCommandList: call #%d", populateCount));
            
        if (FAILED(commandAllocator.Reset()))
        {
            throw new D3D12Exception("failed to reset command allocators");
        }
        if (populateCount <= 2) DebugLog("PopulateCommandList: commandAllocator.Reset OK");

        if (FAILED(commandList.Reset(commandAllocator, pipelineState)))
        {
            throw new D3D12Exception("failed to reset command list");
        }
        if (populateCount <= 2) DebugLog("PopulateCommandList: commandList.Reset OK");

        // Update constant buffer
        core.sys.windows.winnt.LARGE_INTEGER currentCounter;
        QueryPerformanceCounter(&currentCounter);
        float timeSinceStart = cast(float)(currentCounter.QuadPart - startCounter.QuadPart) / cast(float)performanceFrequency.QuadPart;
        
        ConstantBuffer* pCB = cast(ConstantBuffer*)pConstantBufferDataBegin;
        pCB.iTime = timeSinceStart;
        pCB.iResolution[0] = cast(float)width;
        pCB.iResolution[1] = cast(float)height;
        if (populateCount <= 2) DebugLog(format("PopulateCommandList: CB updated, time=%.2f, res=%dx%d", timeSinceStart, width, height));

        commandList.SetGraphicsRootSignature(rootSignature);
        commandList.SetGraphicsRootConstantBufferView(0, constantBufferGPUAddress);
        commandList.RSSetViewports(1, &viewport);
        commandList.RSSetScissorRects(1, &scissorRect);
        if (populateCount <= 2) DebugLog("PopulateCommandList: Root signature and viewport set");

        D3D12_RESOURCE_BARRIER resBarrier;
        resBarrier.Type                   = D3D12_RESOURCE_BARRIER_TYPE_TRANSITION;
        resBarrier.Flags                  = D3D12_RESOURCE_BARRIER_FLAG_NONE;
        resBarrier.Transition.pResource   = renderTargets[frameIndex];
        resBarrier.Transition.StateBefore = D3D12_RESOURCE_STATE_PRESENT;
        resBarrier.Transition.StateAfter  = D3D12_RESOURCE_STATE_RENDER_TARGET;
        resBarrier.Transition.Subresource = D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES;

        commandList.ResourceBarrier(1, &resBarrier);
        if (populateCount <= 2) DebugLog("PopulateCommandList: Resource barrier 1 set");

        auto rtvHandle = D3D12_CPU_DESCRIPTOR_HANDLE(cast(size_t)(rtvHeap.GetCPUDescriptorHandleForHeapStart().ptr + cast(void*)(frameIndex * rtvDescriptorSize)));
        commandList.OMSetRenderTargets(1, &rtvHandle, FALSE, null);
        if (populateCount <= 2) DebugLog("PopulateCommandList: Render targets set");

        const float[4] clearColor = [ 1.0f, 0.0f, 0.0f, 1.0f ];  // Red color - should be overwritten by shader
        commandList.ClearRenderTargetView(rtvHandle, clearColor.ptr, 0, null);
        commandList.IASetPrimitiveTopology(D3D_PRIMITIVE_TOPOLOGY_TRIANGLELIST);
        commandList.IASetVertexBuffers(0, 1, &vertexBufferView);
        commandList.DrawInstanced(6, 1, 0, 0);
        if (populateCount <= 2) DebugLog("PopulateCommandList: Draw commands issued");

        resBarrier.Type                   = D3D12_RESOURCE_BARRIER_TYPE_TRANSITION;
        resBarrier.Flags                  = D3D12_RESOURCE_BARRIER_FLAG_NONE;
        resBarrier.Transition.pResource   = renderTargets[frameIndex];
        resBarrier.Transition.StateBefore = D3D12_RESOURCE_STATE_RENDER_TARGET;
        resBarrier.Transition.StateAfter  = D3D12_RESOURCE_STATE_PRESENT;
        resBarrier.Transition.Subresource = D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES;
        commandList.ResourceBarrier(1, &resBarrier);
        if (populateCount <= 2) DebugLog("PopulateCommandList: Resource barrier 2 set");

        if (FAILED(commandList.Close()))
        {
            throw new D3D12Exception("command list close failed");
        }
        if (populateCount <= 2) DebugLog("PopulateCommandList: Command list closed");
    }


    final void OnResize(int w, int h)
    {
        viewport.Width = w;
        viewport.Height = h;

        scissorRect.left = 0;
        scissorRect.top = 0;
        scissorRect.right = w;
        scissorRect.bottom = h;
    }

    void OnUpdate(float deltaSec) 
    {
        static int frameCount = 0;
        frameCount++;
        if (frameCount <= 5 || frameCount % 60 == 1)  // Log first 5 frames and every 60 frames
            DebugLog(format("OnUpdate: frame %d, deltaTime=%.3f", frameCount, deltaSec));
        
        try 
        {
            OnRender();
        }
        catch (Exception e)
        {
            DebugLog("OnUpdate Exception: " ~ e.msg);
            throw e;
        }
    }


    void OnRender() 
    {
        static int renderCount = 0;
        renderCount++;
        if (renderCount <= 5 || renderCount % 60 == 0)
            DebugLog(format("OnRender: render #%d", renderCount));
            
        try
        {
            PopulateCommandList();
            if (renderCount <= 2) DebugLog("OnRender: PopulateCommandList completed");

            ID3D12CommandList[] ppCommandLists = [ commandList ];
            commandQueue.ExecuteCommandLists( cast(UINT) ppCommandLists.length, ppCommandLists.ptr);
            if (renderCount <= 2) DebugLog("OnRender: CommandLists executed");

            if (FAILED(swapChain.Present(1, 0)))
            {
                throw new D3D12Exception("swapchain present error");
            }
            if (renderCount <= 2) DebugLog("OnRender: Present completed");

            WaitForPreviousFrame();
            if (renderCount <= 2) DebugLog("OnRender: WaitForPreviousFrame completed");
        }
        catch (Exception e)
        {
            DebugLog("OnRender Exception: " ~ e.msg);
            throw e;
        }
    }

    void OnDestroy()
    {
        WaitForPreviousFrame();

        CloseHandle(fenceEvent);

        commandList.Release();
        commandQueue.Release();
        commandAllocator.Release();
        vertexBuffer.Release();
        constantBuffer.Release();
        foreach( rt; renderTargets) 
            rt.Release();
        rtvHeap.Release();
        pipelineState.Release();
        swapChain.Release();
        fence.Release();

        rootSignature.Release();
        device.Release();
    }

    private struct Vertex
    {
        float[2] position;
    }

    private struct ConstantBuffer
    {
        float iTime;
        float[2] iResolution;
        float padding;
    }

    static enum frameCount = 2;

private:
    uint width;
    uint height;
    HWND hWnd;

    D3D12_VIEWPORT viewport;
    D3D12_RECT scissorRect;
    IDXGISwapChain3 swapChain;
    ID3D12Device device;
    ID3D12Resource[frameCount] renderTargets;
    ID3D12CommandAllocator commandAllocator;
    ID3D12CommandQueue commandQueue;
    ID3D12RootSignature rootSignature;
    ID3D12DescriptorHeap rtvHeap;
    ID3D12PipelineState pipelineState;
    ID3D12GraphicsCommandList commandList;
    UINT rtvDescriptorSize;

    ID3D12Resource vertexBuffer;
    D3D12_VERTEX_BUFFER_VIEW vertexBufferView;

    ID3D12Resource constantBuffer;
    ubyte* pConstantBufferDataBegin;
    D3D12_GPU_VIRTUAL_ADDRESS constantBufferGPUAddress;

    UINT frameIndex;
    HANDLE fenceEvent;
    ID3D12Fence fence;
    UINT64 fenceValue;
}

private void GetHardwareAdapter(IDXGIFactory2 pFactory, ref IDXGIAdapter1 ppAdapter)
{
    IDXGIAdapter1 adapter;
    ppAdapter = null;

    for (UINT adapterIndex = 0; DXGI_ERROR_NOT_FOUND != pFactory.EnumAdapters1(adapterIndex, &adapter); ++adapterIndex)
    {
        DXGI_ADAPTER_DESC1 desc;
        adapter.GetDesc1(&desc);

        if (desc.Flags & DXGI_ADAPTER_FLAG_SOFTWARE)
        {
            continue;
        }

        if (SUCCEEDED(D3D12CreateDevice(adapter, D3D_FEATURE_LEVEL_11_0, &IID_ID3D12Device, null)))
        {
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

alias RefWindow = RefCounted!Window;

// Performance counter for timing
static core.sys.windows.winnt.LARGE_INTEGER performanceFrequency;
static core.sys.windows.winnt.LARGE_INTEGER startCounter;


struct Window
{
    private enum WndClassName = "DWndClass"w;

    static RefWindow Create(wstring Title="Hello, World!", int Width=640, int Height=480)
    {
        HINSTANCE hInst = GetModuleHandle(null);
        WNDCLASS  wc;

        wc.lpszClassName = WndClassName.ptr;
        wc.style         = CS_OWNDC | CS_HREDRAW | CS_VREDRAW;
        wc.lpfnWndProc   = &WindowProc;
        wc.hInstance     = hInst;
        wc.hIcon         = LoadIcon(cast(HINSTANCE) null, IDI_APPLICATION);
        wc.hCursor       = LoadCursor(cast(HINSTANCE) null, IDC_CROSS);
        wc.hbrBackground = cast(HBRUSH) (COLOR_WINDOW + 1);
        wc.lpszMenuName  = null;
        wc.cbClsExtra    = wc.cbWndExtra = 0;
        const auto wclass = RegisterClass(&wc);
        assert(wclass);

        HWND hWnd;
        hWnd = CreateWindow(WndClassName.ptr, Title.ptr, WS_THICKFRAME |
                            WS_MAXIMIZEBOX | WS_MINIMIZEBOX | WS_SYSMENU | WS_VISIBLE,
                            CW_USEDEFAULT, CW_USEDEFAULT, Width, Height, HWND_DESKTOP,
                            cast(HMENU) null, hInst, null);
        assert(hWnd);

        RefWindow window;
        window.hWnd = hWnd;

        windowMap[hWnd] = window;

        return window;
    }

    package void onUpdate_() nothrow
    {
    }

    HWND hWnd;

    D3D12Hello demoInstance;

    package static RefWindow[HWND] windowMap;

}

version(Windows)
{
    extern (Windows)
    LRESULT WindowProc(HWND hWnd, uint uMsg, WPARAM wParam, LPARAM lParam) nothrow
    {
        auto window = hWnd in Window.windowMap;
                

        switch (uMsg)
        {
            case WM_COMMAND:
                break;
                
            case WM_PAINT:
                if (window)
                    (window).onUpdate_();
                break;

            case WM_DESTROY:
                PostQuitMessage(0);
                break;

            default:
                break;
        }

        return DefWindowProc(hWnd, uMsg, wParam, lParam);
    }
}

extern (Windows)
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
        import std.conv : to;
        import std.utf : toUTF16z;
        MessageBox(null, to!wstring(e.msg).toUTF16z(), "Error", MB_OK | MB_ICONEXCLAMATION);
        result = 0; // failed
    }

    return result;
}

int myWinMain()
{
    DebugLog("myWinMain: Starting");
    QueryPerformanceFrequency(&performanceFrequency);
    QueryPerformanceCounter(&startCounter);
    core.sys.windows.winnt.LARGE_INTEGER lastCounter = startCounter;

    auto window = Window.Create();
    auto example = new D3D12Hello(600,400,window.hWnd);
    window.demoInstance = example;

    DebugLog("myWinMain: Entering main loop");
    MSG msg;
    int frameCount = 0;
    while(true)
    {
        try 
        {
            core.sys.windows.winnt.LARGE_INTEGER currentCounter;
            QueryPerformanceCounter(&currentCounter);
            float deltaTime = cast(float)(currentCounter.QuadPart - lastCounter.QuadPart) / cast(float)performanceFrequency.QuadPart;
            lastCounter = currentCounter;

            if ( PeekMessage(&msg, cast(HWND) null, 0, 0, PM_REMOVE) )
            {
                if (msg.message == WM_QUIT)
                {
                    DebugLog("myWinMain: WM_QUIT received, exiting");
                    break;
                }
                
                TranslateMessage(&msg);
                DispatchMessage(&msg);
            }

            example.OnUpdate(deltaTime);

            Thread.sleep( dur!("msecs")(1) );
            
            frameCount++;
            if (frameCount % 60 == 0)
            {
                DebugLog(format("myWinMain: %d frames rendered", frameCount));
            }
        }
        catch (Exception e)
        {
            DebugLog("myWinMain loop exception: " ~ e.msg);
            import std.conv : to;
            import std.utf : toUTF16z;
            MessageBox(null, to!wstring("Loop error: " ~ e.msg).toUTF16z(), "Runtime Error", MB_OK | MB_ICONERROR);
            break;
        }
    }

    DebugLog("myWinMain: Destroying resources");
    example.OnDestroy();

    DebugLog(format("myWinMain: Exiting after %d frames", frameCount));
    return 1;
}
