/*
 * DirectX 12 Compute Shader Harmonograph (Fixed Coordinate System)
 *
 * Build: csc Harmonograph.cs
 * Run:   Harmonograph.exe
 */

using System;
using System.Runtime.InteropServices;
using System.Diagnostics;

public class Harmonograph
{
    #region Win32 Structures and Constants

    [StructLayout(LayoutKind.Sequential)]
    public struct POINT { public int X, Y; }

    [StructLayout(LayoutKind.Sequential)]
    public struct MSG
    {
        public IntPtr hwnd;
        public uint message;
        public IntPtr wParam, lParam;
        public uint time;
        public POINT pt;
    }

    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate IntPtr WndProcDelegate(IntPtr hWnd, uint uMsg, IntPtr wParam, IntPtr lParam);

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Auto)]
    struct WNDCLASSEX
    {
        public uint cbSize, style;
        public WndProcDelegate lpfnWndProc;
        public int cbClsExtra, cbWndExtra;
        public IntPtr hInstance, hIcon, hCursor, hbrBackground;
        public string lpszMenuName, lpszClassName;
        public IntPtr hIconSm;
    }

    const uint WS_OVERLAPPEDWINDOW = 0x00CF0000, WS_VISIBLE = 0x10000000;
    const uint WM_DESTROY = 0x0002, WM_QUIT = 0x0012, PM_REMOVE = 0x0001;
    const uint CS_OWNDC = 0x0020;
    const int IDC_ARROW = 32512;
    const uint INFINITE = 0xFFFFFFFF;

    const int WIDTH = 800, HEIGHT = 600, FRAME_COUNT = 2;
    const int VERTEX_COUNT = 100000;

    #endregion

    #region Win32 Imports

    [DllImport("user32.dll", CharSet = CharSet.Auto)] static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    [DllImport("user32.dll", CharSet = CharSet.Auto)] static extern IntPtr LoadCursor(IntPtr hInstance, int lpCursorName);
    [DllImport("user32.dll", CharSet = CharSet.Auto)] static extern ushort RegisterClassEx([In] ref WNDCLASSEX lpwcx);
    [DllImport("user32.dll", CharSet = CharSet.Auto)] static extern IntPtr CreateWindowEx(uint dwExStyle, string lpClassName, string lpWindowName, uint dwStyle, int x, int y, int nWidth, int nHeight, IntPtr hWndParent, IntPtr hMenu, IntPtr hInstance, IntPtr lpParam);
    [DllImport("user32.dll", CharSet = CharSet.Auto)] static extern bool PeekMessage(out MSG lpMsg, IntPtr hWnd, uint wMsgFilterMin, uint wMsgFilterMax, uint wRemoveMsg);
    [DllImport("user32.dll", CharSet = CharSet.Auto)] static extern bool TranslateMessage([In] ref MSG lpMsg);
    [DllImport("user32.dll", CharSet = CharSet.Auto)] static extern IntPtr DispatchMessage([In] ref MSG lpMsg);
    [DllImport("user32.dll", CharSet = CharSet.Auto)] static extern void PostQuitMessage(int nExitCode);
    [DllImport("user32.dll", CharSet = CharSet.Auto)] static extern IntPtr DefWindowProc(IntPtr hWnd, uint uMsg, IntPtr wParam, IntPtr lParam);
    [DllImport("kernel32.dll")] static extern IntPtr CreateEvent(IntPtr lpEventAttributes, bool bManualReset, bool bInitialState, string lpName);
    [DllImport("kernel32.dll")] static extern uint WaitForSingleObject(IntPtr hHandle, uint dwMilliseconds);
    [DllImport("kernel32.dll")] static extern bool CloseHandle(IntPtr hObject);
    [DllImport("kernel32.dll")] static extern uint GetTickCount();

    #endregion

    #region DirectX Imports and GUIDs

    [DllImport("d3d12.dll")] static extern int D3D12GetDebugInterface(ref Guid riid, out IntPtr ppvDebug);
    [DllImport("d3d12.dll")] static extern int D3D12CreateDevice(IntPtr pAdapter, uint MinimumFeatureLevel, ref Guid riid, out IntPtr ppDevice);
    [DllImport("dxgi.dll")] static extern int CreateDXGIFactory1(ref Guid riid, out IntPtr ppFactory);
    [DllImport("d3d12.dll")] static extern int D3D12SerializeRootSignature(ref D3D12_ROOT_SIGNATURE_DESC pRootSignature, uint Version, out IntPtr ppBlob, out IntPtr ppErrorBlob);
    [DllImport("d3dcompiler_47.dll")] static extern int D3DCompileFromFile([MarshalAs(UnmanagedType.LPWStr)] string pFileName, IntPtr pDefines, IntPtr pInclude, [MarshalAs(UnmanagedType.LPStr)] string pEntrypoint, [MarshalAs(UnmanagedType.LPStr)] string pTarget, uint Flags1, uint Flags2, out IntPtr ppCode, out IntPtr ppErrorMsgs);

    static Guid IID_ID3D12Debug = new Guid("344488b7-6846-474b-b989-f027448245e0");
    static Guid IID_IDXGIFactory4 = new Guid("1bc6ea02-ef36-464f-bf0c-21ca39e5168a");
    static Guid IID_ID3D12Device = new Guid("189819f1-1db6-4b57-be54-1821339b85f7");
    static Guid IID_ID3D12CommandQueue = new Guid("0ec870a6-5d7e-4c22-8cfc-5baae07616ed");
    static Guid IID_IDXGISwapChain3 = new Guid("94d99bdb-f1f8-4ab0-b236-7da0170edab1");
    static Guid IID_ID3D12DescriptorHeap = new Guid("8efb471d-616c-4f49-90f7-127bb763fa51");
    static Guid IID_ID3D12Resource = new Guid("696442be-a72e-4059-bc79-5b5c98040fad");
    static Guid IID_ID3D12CommandAllocator = new Guid("6102dee4-af59-4b09-b999-b44d73f09b24");
    static Guid IID_ID3D12RootSignature = new Guid("c54a6b66-72df-4ee8-8be5-a946a1429214");
    static Guid IID_ID3D12PipelineState = new Guid("765a30f3-f624-4c6f-a828-ace948622445");
    static Guid IID_ID3D12GraphicsCommandList = new Guid("5b160d0f-ac1b-4185-8ba8-b3ae42a5a455");
    static Guid IID_ID3D12Fence = new Guid("0a753dcf-c4d8-4b91-adf6-be5a60d95a76");

    const uint D3D_FEATURE_LEVEL_12_0 = 0xc000;
    const uint D3D_ROOT_SIGNATURE_VERSION_1 = 1;
    const uint DXGI_FORMAT_R8G8B8A8_UNORM = 28;

    // Descriptor Range Types
    const int D3D12_DESCRIPTOR_RANGE_TYPE_SRV = 0;
    const int D3D12_DESCRIPTOR_RANGE_TYPE_UAV = 1;
    const int D3D12_DESCRIPTOR_RANGE_TYPE_CBV = 2;

    // SRV Dimensions
    const int D3D12_SRV_DIMENSION_BUFFER = 1;

    #endregion

    #region DirectX Structures

    [StructLayout(LayoutKind.Sequential)]
    struct DXGI_SWAP_CHAIN_DESC1
    {
        public uint Width, Height, Format;
        public int Stereo;
        public DXGI_SAMPLE_DESC SampleDesc;
        public uint BufferUsage, BufferCount;
        public int Scaling, SwapEffect, AlphaMode;
        public uint Flags;
    }

    [StructLayout(LayoutKind.Sequential)]
    struct DXGI_SAMPLE_DESC { public uint Count, Quality; }

    [StructLayout(LayoutKind.Sequential)]
    struct D3D12_COMMAND_QUEUE_DESC { public int Type, Priority, Flags; public uint NodeMask; }

    [StructLayout(LayoutKind.Sequential)]
    struct D3D12_DESCRIPTOR_HEAP_DESC { public int Type; public uint NumDescriptors; public int Flags; public uint NodeMask; }

    [StructLayout(LayoutKind.Sequential)]
    struct D3D12_CPU_DESCRIPTOR_HANDLE { public IntPtr ptr; }

    [StructLayout(LayoutKind.Sequential)]
    struct D3D12_GPU_DESCRIPTOR_HANDLE { public ulong ptr; }

    [StructLayout(LayoutKind.Sequential)]
    struct D3D12_HEAP_PROPERTIES { public int Type, CPUPageProperty, MemoryPoolPreference; public uint CreationNodeMask, VisibleNodeMask; }

    [StructLayout(LayoutKind.Sequential)]
    struct D3D12_RESOURCE_DESC
    {
        public int Dimension;
        public ulong Alignment, Width;
        public uint Height;
        public ushort DepthOrArraySize, MipLevels;
        public uint Format;
        public DXGI_SAMPLE_DESC SampleDesc;
        public int Layout, Flags;
    }

    [StructLayout(LayoutKind.Sequential)]
    struct D3D12_SHADER_BYTECODE { public IntPtr pShaderBytecode; public IntPtr BytecodeLength; }

    [StructLayout(LayoutKind.Sequential)]
    struct D3D12_COMPUTE_PIPELINE_STATE_DESC
    {
        public IntPtr pRootSignature;
        public D3D12_SHADER_BYTECODE CS;
        public uint NodeMask;
        public IntPtr CachedPSO_pCachedBlob;
        public IntPtr CachedPSO_CachedBlobSizeInBytes;
        public int Flags;
    }

    [StructLayout(LayoutKind.Sequential)]
    struct D3D12_GRAPHICS_PIPELINE_STATE_DESC
    {
        public IntPtr pRootSignature;
        public D3D12_SHADER_BYTECODE VS, PS, DS, HS, GS;
        public D3D12_STREAM_OUTPUT_DESC StreamOutput;
        public D3D12_BLEND_DESC BlendState;
        public uint SampleMask;
        public D3D12_RASTERIZER_DESC RasterizerState;
        public D3D12_DEPTH_STENCIL_DESC DepthStencilState;
        public D3D12_INPUT_LAYOUT_DESC InputLayout;
        public int IBStripCutValue, PrimitiveTopologyType;
        public uint NumRenderTargets;
        [MarshalAs(UnmanagedType.ByValArray, SizeConst = 8)] public uint[] RTVFormats;
        public uint DSVFormat;
        public DXGI_SAMPLE_DESC SampleDesc;
        public uint NodeMask;
        public IntPtr CachedPSO_pCachedBlob;
        public IntPtr CachedPSO_CachedBlobSizeInBytes;
        public int Flags;
    }

    [StructLayout(LayoutKind.Sequential)]
    struct D3D12_STREAM_OUTPUT_DESC { public IntPtr pSODeclaration; public uint NumEntries, NumStrides; public IntPtr pBufferStrides; public uint RasterizedStream; }

    [StructLayout(LayoutKind.Sequential)]
    struct D3D12_BLEND_DESC
    {
        public int AlphaToCoverageEnable, IndependentBlendEnable;
        public D3D12_RENDER_TARGET_BLEND_DESC RT0, RT1, RT2, RT3, RT4, RT5, RT6, RT7;
    }

    [StructLayout(LayoutKind.Sequential)]
    struct D3D12_RENDER_TARGET_BLEND_DESC
    {
        public int BlendEnable, LogicOpEnable;
        public int SrcBlend, DestBlend, BlendOp, SrcBlendAlpha, DestBlendAlpha, BlendOpAlpha, LogicOp;
        public byte RenderTargetWriteMask;
    }

    [StructLayout(LayoutKind.Sequential)]
    struct D3D12_RASTERIZER_DESC
    {
        public int FillMode, CullMode, FrontCounterClockwise;
        public int DepthBias;
        public float DepthBiasClamp, SlopeScaledDepthBias;
        public int DepthClipEnable, MultisampleEnable, AntialiasedLineEnable, ForcedSampleCount, ConservativeRaster;
    }

    [StructLayout(LayoutKind.Sequential)]
    struct D3D12_DEPTH_STENCIL_DESC
    {
        public int DepthEnable, DepthWriteMask, DepthFunc, StencilEnable;
        public byte StencilReadMask, StencilWriteMask;
        public D3D12_DEPTH_STENCILOP_DESC FrontFace, BackFace;
    }

    [StructLayout(LayoutKind.Sequential)]
    struct D3D12_DEPTH_STENCILOP_DESC { public int StencilFailOp, StencilDepthFailOp, StencilPassOp, StencilFunc; }

    [StructLayout(LayoutKind.Sequential)]
    struct D3D12_INPUT_LAYOUT_DESC { public IntPtr pInputElementDescs; public uint NumElements; }

    [StructLayout(LayoutKind.Sequential)]
    struct D3D12_ROOT_SIGNATURE_DESC { public uint NumParameters; public IntPtr pParameters; public uint NumStaticSamplers; public IntPtr pStaticSamplers; public int Flags; }

    [StructLayout(LayoutKind.Sequential)]
    struct D3D12_ROOT_PARAMETER { public int ParameterType; public D3D12_ROOT_DESCRIPTOR_TABLE DescriptorTable; public int ShaderVisibility; }

    [StructLayout(LayoutKind.Sequential)]
    struct D3D12_ROOT_DESCRIPTOR_TABLE { public uint NumDescriptorRanges; public IntPtr pDescriptorRanges; }

    [StructLayout(LayoutKind.Sequential)]
    struct D3D12_DESCRIPTOR_RANGE { public int RangeType; public uint NumDescriptors, BaseShaderRegister, RegisterSpace; public int OffsetInDescriptorsFromTableStart; }

    [StructLayout(LayoutKind.Sequential)]
    struct D3D12_RESOURCE_BARRIER
    {
        public int Type, Flags;
        public IntPtr pResource;
        public uint Subresource;
        public int StateBefore, StateAfter;
    }

    [StructLayout(LayoutKind.Sequential)]
    struct D3D12_VIEWPORT { public float TopLeftX, TopLeftY, Width, Height, MinDepth, MaxDepth; }

    [StructLayout(LayoutKind.Sequential)]
    struct D3D12_RECT { public int left, top, right, bottom; }

    [StructLayout(LayoutKind.Sequential)]
    struct D3D12_RANGE { public IntPtr Begin, End; }

    [StructLayout(LayoutKind.Sequential)]
    struct D3D12_UNORDERED_ACCESS_VIEW_DESC
    {
        public uint Format;
        public int ViewDimension;
        public ulong Buffer_FirstElement;
        public uint Buffer_NumElements, Buffer_StructureByteStride;
        public ulong Buffer_CounterOffsetInBytes;
        public int Buffer_Flags;
    }

    [StructLayout(LayoutKind.Sequential)]
    struct D3D12_SHADER_RESOURCE_VIEW_DESC
    {
        public uint Format;
        public int ViewDimension;
        public int Shader4ComponentMapping;
        public ulong Buffer_FirstElement;
        public uint Buffer_NumElements, Buffer_StructureByteStride;
        public int Buffer_Flags;
    }

    [StructLayout(LayoutKind.Sequential)]
    struct D3D12_CONSTANT_BUFFER_VIEW_DESC { public ulong BufferLocation; public uint SizeInBytes; }

    [StructLayout(LayoutKind.Sequential)]
    struct HarmonographParams
    {
        public float A1, f1, p1, d1;
        public float A2, f2, p2, d2;
        public float A3, f3, p3, d3;
        public float A4, f4, p4, d4;
        public uint max_num;
        public float padding1, padding2, padding3;
        public float resolutionX, resolutionY;
        public float padding4, padding5;
    }

    #endregion

    #region Delegates

    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate void EnableDebugLayerDelegate(IntPtr debug);

    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate int CreateCommandQueueDelegate(IntPtr device, ref D3D12_COMMAND_QUEUE_DESC desc, ref Guid riid, out IntPtr queue);

    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate int CreateDescriptorHeapDelegate(IntPtr device, ref D3D12_DESCRIPTOR_HEAP_DESC desc, ref Guid riid, out IntPtr heap);

    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate uint GetDescriptorHandleIncrementSizeDelegate(IntPtr device, int type);

    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate int CreateCommandAllocatorDelegate(IntPtr device, int type, ref Guid riid, out IntPtr allocator);

    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate int CreateRootSignatureDelegate(IntPtr device, uint nodeMask, IntPtr pBlobWithRootSignature, IntPtr blobLengthInBytes, ref Guid riid, out IntPtr rootSignature);

    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate int CreateGraphicsPipelineStateDelegate(IntPtr device, ref D3D12_GRAPHICS_PIPELINE_STATE_DESC desc, ref Guid riid, out IntPtr pso);

    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate int CreateComputePipelineStateDelegate(IntPtr device, ref D3D12_COMPUTE_PIPELINE_STATE_DESC desc, ref Guid riid, out IntPtr pso);

    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate int CreateCommandListDelegate(IntPtr device, uint nodeMask, int type, IntPtr allocator, IntPtr initialState, ref Guid riid, out IntPtr commandList);

    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate int CreateCommittedResourceDelegate(IntPtr device, ref D3D12_HEAP_PROPERTIES heapProperties, int heapFlags, ref D3D12_RESOURCE_DESC desc, int initialState, IntPtr optimizedClearValue, ref Guid riid, out IntPtr resource);

    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate int CreateFenceDelegate(IntPtr device, ulong initialValue, int flags, ref Guid riid, out IntPtr fence);

    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate void CreateRenderTargetViewDelegate(IntPtr device, IntPtr resource, IntPtr desc, D3D12_CPU_DESCRIPTOR_HANDLE destDescriptor);

    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate void CreateUnorderedAccessViewDelegate(IntPtr device, IntPtr resource, IntPtr counterResource, ref D3D12_UNORDERED_ACCESS_VIEW_DESC desc, D3D12_CPU_DESCRIPTOR_HANDLE destDescriptor);

    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate void CreateConstantBufferViewDelegate(IntPtr device, ref D3D12_CONSTANT_BUFFER_VIEW_DESC desc, D3D12_CPU_DESCRIPTOR_HANDLE destDescriptor);

    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate int GetBufferDelegate(IntPtr swapChain, uint buffer, ref Guid riid, out IntPtr surface);

    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate int PresentDelegate(IntPtr swapChain, uint syncInterval, uint flags);

    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate uint GetCurrentBackBufferIndexDelegate(IntPtr swapChain);

    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate int CreateSwapChainForHwndDelegate(IntPtr factory, IntPtr device, IntPtr hwnd, ref DXGI_SWAP_CHAIN_DESC1 desc, IntPtr fullscreenDesc, IntPtr restrictToOutput, out IntPtr swapChain);

    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate int ResetCommandAllocatorDelegate(IntPtr allocator);

    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate int ResetCommandListDelegate(IntPtr commandList, IntPtr allocator, IntPtr pso);

    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate int CloseCommandListDelegate(IntPtr commandList);

    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate void SetDescriptorHeapsDelegate(IntPtr commandList, uint numHeaps, IntPtr[] heaps);

    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate void SetComputeRootSignatureDelegate(IntPtr commandList, IntPtr rootSignature);

    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate void SetGraphicsRootSignatureDelegate(IntPtr commandList, IntPtr rootSignature);

    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate void SetComputeRootDescriptorTableDelegate(IntPtr commandList, uint rootParameterIndex, D3D12_GPU_DESCRIPTOR_HANDLE baseDescriptor);

    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate void SetGraphicsRootDescriptorTableDelegate(IntPtr commandList, uint rootParameterIndex, D3D12_GPU_DESCRIPTOR_HANDLE baseDescriptor);

    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate void DispatchDelegate(IntPtr commandList, uint threadGroupCountX, uint threadGroupCountY, uint threadGroupCountZ);

    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate void ResourceBarrierDelegate(IntPtr commandList, uint numBarriers, ref D3D12_RESOURCE_BARRIER barriers);

    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate void RSSetViewportsDelegate(IntPtr commandList, uint numViewports, ref D3D12_VIEWPORT viewports);

    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate void RSSetScissorRectsDelegate(IntPtr commandList, uint numRects, ref D3D12_RECT rects);

    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate void ClearRenderTargetViewDelegate(IntPtr commandList, D3D12_CPU_DESCRIPTOR_HANDLE renderTargetView, float[] colorRGBA, uint numRects, IntPtr rects);

    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate void OMSetRenderTargetsDelegate(IntPtr commandList, uint numRenderTargetDescriptors, ref D3D12_CPU_DESCRIPTOR_HANDLE renderTargetDescriptors, int rtsSingleHandleToDescriptorRange, IntPtr depthStencilDescriptor);

    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate void IASetPrimitiveTopologyDelegate(IntPtr commandList, int primitiveTopology);

    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate void DrawInstancedDelegate(IntPtr commandList, uint vertexCountPerInstance, uint instanceCount, uint startVertexLocation, uint startInstanceLocation);

    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate void SetPipelineStateDelegate(IntPtr commandList, IntPtr pso);

    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate void ExecuteCommandListsDelegate(IntPtr commandQueue, uint numCommandLists, IntPtr[] commandLists);

    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate int SignalDelegate(IntPtr commandQueue, IntPtr fence, ulong value);

    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate ulong GetCompletedValueDelegate(IntPtr fence);

    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate int SetEventOnCompletionDelegate(IntPtr fence, ulong value, IntPtr hEvent);

    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate int QueryInterfaceDelegate(IntPtr pThis, ref Guid riid, out IntPtr ppvObject);

    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate int MapDelegate(IntPtr resource, uint subresource, ref D3D12_RANGE readRange, out IntPtr data);

    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate void UnmapDelegate(IntPtr resource, uint subresource, ref D3D12_RANGE writtenRange);

    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate ulong GetGPUVirtualAddressDelegate(IntPtr resource);

    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate IntPtr GetBufferPointerDelegate(IntPtr blob);

    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate IntPtr GetBufferSizeDelegate(IntPtr blob);

    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate void GetCPUDescriptorHandleForHeapStartDelegate(IntPtr heap, out D3D12_CPU_DESCRIPTOR_HANDLE handle);

    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate void GetGPUDescriptorHandleForHeapStartDelegate(IntPtr heap, out D3D12_GPU_DESCRIPTOR_HANDLE handle);

    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate void CreateSRVDelegate(IntPtr device, IntPtr resource, ref D3D12_SHADER_RESOURCE_VIEW_DESC desc, D3D12_CPU_DESCRIPTOR_HANDLE handle);

    #endregion

    #region Member Variables

    IntPtr device, commandQueue, swapChain, rtvHeap, srvUavHeap;
    IntPtr[] renderTargets = new IntPtr[FRAME_COUNT];
    IntPtr commandAllocator, computeCommandAllocator;
    IntPtr graphicsRootSignature, computeRootSignature;
    IntPtr graphicsPso, computePso;
    IntPtr commandList, computeCommandList;
    IntPtr positionBuffer, colorBuffer, constantBuffer;
    IntPtr fence, fenceEvent;
    ulong fenceValue;
    uint frameIndex;
    uint rtvDescriptorSize, srvUavDescriptorSize;
    IntPtr constantBufferPtr;

    float A1 = 50f, f1 = 2f, p1 = 1f / 16f, d1 = 0.02f;
    float A2 = 50f, f2 = 2f, p2 = 3f / 2f, d2 = 0.0315f;
    float A3 = 50f, f3 = 2f, p3 = 13f / 15f, d3 = 0.02f;
    float A4 = 50f, f4 = 2f, p4 = 1f, d4 = 0.02f;
    const float PI2 = 6.283185307179586f;
    Random rand = new Random();

    static WndProcDelegate wndProcDelegate;

    #endregion

    #region Helper Methods

    void CheckResult(int hr, string message)
    {
        if (hr < 0)
        {
            throw new Exception($"FAILED: {message} (HRESULT: 0x{hr:X})");
        }
    }

    void Log(string message)
    {
        Console.WriteLine($"[INFO] {message}");
    }

    IntPtr GetCPUDescriptorHandleForHeapStart(IntPtr heap)
    {
        IntPtr vTable = Marshal.ReadIntPtr(heap);
        IntPtr funcPtr = Marshal.ReadIntPtr(vTable, 9 * IntPtr.Size);
        var func = Marshal.GetDelegateForFunctionPointer<GetCPUDescriptorHandleForHeapStartDelegate>(funcPtr);
        D3D12_CPU_DESCRIPTOR_HANDLE handle;
        func(heap, out handle);
        return handle.ptr;
    }

    D3D12_GPU_DESCRIPTOR_HANDLE GetGPUDescriptorHandleForHeapStart(IntPtr heap)
    {
        IntPtr vTable = Marshal.ReadIntPtr(heap);
        IntPtr funcPtr = Marshal.ReadIntPtr(vTable, 10 * IntPtr.Size);
        var func = Marshal.GetDelegateForFunctionPointer<GetGPUDescriptorHandleForHeapStartDelegate>(funcPtr);
        D3D12_GPU_DESCRIPTOR_HANDLE handle;
        func(heap, out handle);
        return handle;
    }

    IntPtr CompileShader(string filename, string entryPoint, string target)
    {
        int result = D3DCompileFromFile(filename, IntPtr.Zero, IntPtr.Zero, entryPoint, target, 0, 0, out IntPtr blob, out IntPtr error);
        if (result < 0)
        {
            if (error != IntPtr.Zero)
            {
                IntPtr vTable = Marshal.ReadIntPtr(error);
                IntPtr getPtr = Marshal.ReadIntPtr(vTable, 3 * IntPtr.Size);
                var getBufferPointer = Marshal.GetDelegateForFunctionPointer<GetBufferPointerDelegate>(getPtr);
                IntPtr msgPtr = getBufferPointer(error);
                string msg = Marshal.PtrToStringAnsi(msgPtr);
                Console.WriteLine($"Shader compile error: {msg}");
            }
            throw new Exception($"Failed to compile shader {entryPoint}: {result:X}");
        }
        return blob;
    }

    IntPtr GetBlobBufferPointer(IntPtr blob)
    {
        IntPtr vTable = Marshal.ReadIntPtr(blob);
        IntPtr funcPtr = Marshal.ReadIntPtr(vTable, 3 * IntPtr.Size);
        var func = Marshal.GetDelegateForFunctionPointer<GetBufferPointerDelegate>(funcPtr);
        return func(blob);
    }

    IntPtr GetBlobBufferSize(IntPtr blob)
    {
        IntPtr vTable = Marshal.ReadIntPtr(blob);
        IntPtr funcPtr = Marshal.ReadIntPtr(vTable, 4 * IntPtr.Size);
        var func = Marshal.GetDelegateForFunctionPointer<GetBufferSizeDelegate>(funcPtr);
        return func(blob);
    }

    #endregion

    void EnableDebugLayer()
    {
        Log("Enabling Debug Layer...");
        Guid uuid = IID_ID3D12Debug;
        IntPtr debugController;
        int hr = D3D12GetDebugInterface(ref uuid, out debugController);
        if (hr >= 0 && debugController != IntPtr.Zero)
        {
            IntPtr vTable = Marshal.ReadIntPtr(debugController);
            IntPtr enablePtr = Marshal.ReadIntPtr(vTable, 3 * IntPtr.Size);
            var enableDebug = Marshal.GetDelegateForFunctionPointer<EnableDebugLayerDelegate>(enablePtr);
            enableDebug(debugController);
            Marshal.Release(debugController);
            Log("Debug Layer Enabled.");
        }
    }

    void LoadPipeline(IntPtr hwnd)
    {
        Log("LoadPipeline Started.");

        Guid factoryGuid = IID_IDXGIFactory4;
        CheckResult(CreateDXGIFactory1(ref factoryGuid, out IntPtr factory), "CreateDXGIFactory1");

        Guid deviceGuid = IID_ID3D12Device;
        CheckResult(D3D12CreateDevice(IntPtr.Zero, D3D_FEATURE_LEVEL_12_0, ref deviceGuid, out device), "D3D12CreateDevice");

        var queueDesc = new D3D12_COMMAND_QUEUE_DESC { Type = 0, Priority = 0, Flags = 0, NodeMask = 0 };
        IntPtr vTable = Marshal.ReadIntPtr(device);
        var createQueue = Marshal.GetDelegateForFunctionPointer<CreateCommandQueueDelegate>(Marshal.ReadIntPtr(vTable, 8 * IntPtr.Size));
        Guid queueGuid = IID_ID3D12CommandQueue;
        CheckResult(createQueue(device, ref queueDesc, ref queueGuid, out commandQueue), "CreateCommandQueue");

        var swapChainDesc = new DXGI_SWAP_CHAIN_DESC1
        {
            Width = WIDTH, Height = HEIGHT, Format = DXGI_FORMAT_R8G8B8A8_UNORM, Stereo = 0,
            SampleDesc = new DXGI_SAMPLE_DESC { Count = 1, Quality = 0 },
            BufferUsage = 0x20, BufferCount = FRAME_COUNT, Scaling = 1, SwapEffect = 4, AlphaMode = 0, Flags = 0
        };

        IntPtr factoryVTable = Marshal.ReadIntPtr(factory);
        var createSwapChain = Marshal.GetDelegateForFunctionPointer<CreateSwapChainForHwndDelegate>(Marshal.ReadIntPtr(factoryVTable, 15 * IntPtr.Size));
        CheckResult(createSwapChain(factory, commandQueue, hwnd, ref swapChainDesc, IntPtr.Zero, IntPtr.Zero, out IntPtr tempSwapChain), "CreateSwapChainForHwnd");

        IntPtr tempVTable = Marshal.ReadIntPtr(tempSwapChain);
        var queryInterface = Marshal.GetDelegateForFunctionPointer<QueryInterfaceDelegate>(Marshal.ReadIntPtr(tempVTable, 0));
        Guid swapChain3Guid = IID_IDXGISwapChain3;
        CheckResult(queryInterface(tempSwapChain, ref swapChain3Guid, out swapChain), "QueryInterface IDXGISwapChain3");
        Marshal.Release(tempSwapChain);

        var rtvHeapDesc = new D3D12_DESCRIPTOR_HEAP_DESC { Type = 2, NumDescriptors = FRAME_COUNT, Flags = 0, NodeMask = 0 };
        var createHeap = Marshal.GetDelegateForFunctionPointer<CreateDescriptorHeapDelegate>(Marshal.ReadIntPtr(vTable, 14 * IntPtr.Size));
        Guid heapGuid = IID_ID3D12DescriptorHeap;
        CheckResult(createHeap(device, ref rtvHeapDesc, ref heapGuid, out rtvHeap), "CreateDescriptorHeap (RTV)");
        Log("RTV Heap Created.");

        var getIncrement = Marshal.GetDelegateForFunctionPointer<GetDescriptorHandleIncrementSizeDelegate>(Marshal.ReadIntPtr(vTable, 15 * IntPtr.Size));
        rtvDescriptorSize = getIncrement(device, 2);

        var srvUavHeapDesc = new D3D12_DESCRIPTOR_HEAP_DESC { Type = 0, NumDescriptors = 5, Flags = 1, NodeMask = 0 };
        CheckResult(createHeap(device, ref srvUavHeapDesc, ref heapGuid, out srvUavHeap), "CreateDescriptorHeap (SRV/UAV)");
        srvUavDescriptorSize = getIncrement(device, 0);

        var createRTV = Marshal.GetDelegateForFunctionPointer<CreateRenderTargetViewDelegate>(Marshal.ReadIntPtr(vTable, 20 * IntPtr.Size));
        IntPtr swapChainVTable = Marshal.ReadIntPtr(swapChain);
        var getBuffer = Marshal.GetDelegateForFunctionPointer<GetBufferDelegate>(Marshal.ReadIntPtr(swapChainVTable, 9 * IntPtr.Size));

        D3D12_CPU_DESCRIPTOR_HANDLE rtvHandle = new D3D12_CPU_DESCRIPTOR_HANDLE { ptr = GetCPUDescriptorHandleForHeapStart(rtvHeap) };
        Guid resourceGuid = IID_ID3D12Resource;
        for (int i = 0; i < FRAME_COUNT; i++)
        {
            CheckResult(getBuffer(swapChain, (uint)i, ref resourceGuid, out renderTargets[i]), $"GetBuffer[{i}]");
            createRTV(device, renderTargets[i], IntPtr.Zero, rtvHandle);
            rtvHandle.ptr = IntPtr.Add(rtvHandle.ptr, (int)rtvDescriptorSize);
        }
        Log("RTVs Created.");

        var createAllocator = Marshal.GetDelegateForFunctionPointer<CreateCommandAllocatorDelegate>(Marshal.ReadIntPtr(vTable, 9 * IntPtr.Size));
        Guid allocatorGuid = IID_ID3D12CommandAllocator;
        CheckResult(createAllocator(device, 0, ref allocatorGuid, out commandAllocator), "CreateCommandAllocator (Graphics)");
        CheckResult(createAllocator(device, 0, ref allocatorGuid, out computeCommandAllocator), "CreateCommandAllocator (Compute)");
        Log("CommandAllocators Created.");

        Marshal.Release(factory);
    }

    void CreateSRV(IntPtr resource, D3D12_SHADER_RESOURCE_VIEW_DESC desc, D3D12_CPU_DESCRIPTOR_HANDLE handle)
    {
        IntPtr vTable = Marshal.ReadIntPtr(device);
        IntPtr funcPtr = Marshal.ReadIntPtr(vTable, 18 * IntPtr.Size);
        var func = Marshal.GetDelegateForFunctionPointer<CreateSRVDelegate>(funcPtr);
        func(device, resource, ref desc, handle);
    }

    void LoadAssets()
    {
        Log("LoadAssets Started.");
        IntPtr vTable = Marshal.ReadIntPtr(device);

        // --- Compute Root Signature ---
        var uavRange = new D3D12_DESCRIPTOR_RANGE { RangeType = D3D12_DESCRIPTOR_RANGE_TYPE_UAV, NumDescriptors = 2, BaseShaderRegister = 0, RegisterSpace = 0, OffsetInDescriptorsFromTableStart = -1 };
        var cbvRange = new D3D12_DESCRIPTOR_RANGE { RangeType = D3D12_DESCRIPTOR_RANGE_TYPE_CBV, NumDescriptors = 1, BaseShaderRegister = 0, RegisterSpace = 0, OffsetInDescriptorsFromTableStart = -1 };

        GCHandle uavRangeHandle = GCHandle.Alloc(uavRange, GCHandleType.Pinned);
        GCHandle cbvRangeHandle = GCHandle.Alloc(cbvRange, GCHandleType.Pinned);

        var computeParams = new D3D12_ROOT_PARAMETER[2];
        computeParams[0] = new D3D12_ROOT_PARAMETER { ParameterType = 0, DescriptorTable = new D3D12_ROOT_DESCRIPTOR_TABLE { NumDescriptorRanges = 1, pDescriptorRanges = uavRangeHandle.AddrOfPinnedObject() }, ShaderVisibility = 0 };
        computeParams[1] = new D3D12_ROOT_PARAMETER { ParameterType = 0, DescriptorTable = new D3D12_ROOT_DESCRIPTOR_TABLE { NumDescriptorRanges = 1, pDescriptorRanges = cbvRangeHandle.AddrOfPinnedObject() }, ShaderVisibility = 0 };

        GCHandle computeParamsHandle = GCHandle.Alloc(computeParams, GCHandleType.Pinned);
        var computeRootSigDesc = new D3D12_ROOT_SIGNATURE_DESC { NumParameters = 2, pParameters = computeParamsHandle.AddrOfPinnedObject(), NumStaticSamplers = 0, pStaticSamplers = IntPtr.Zero, Flags = 0 };
        D3D12SerializeRootSignature(ref computeRootSigDesc, D3D_ROOT_SIGNATURE_VERSION_1, out IntPtr computeSigBlob, out _);

        var createRootSig = Marshal.GetDelegateForFunctionPointer<CreateRootSignatureDelegate>(Marshal.ReadIntPtr(vTable, 16 * IntPtr.Size));
        Guid rootSigGuid = IID_ID3D12RootSignature;
        CheckResult(createRootSig(device, 0, GetBlobBufferPointer(computeSigBlob), GetBlobBufferSize(computeSigBlob), ref rootSigGuid, out computeRootSignature), "CreateRootSignature (Compute)");

        // --- Graphics Root Signature ---
        var srvRange = new D3D12_DESCRIPTOR_RANGE { RangeType = D3D12_DESCRIPTOR_RANGE_TYPE_SRV, NumDescriptors = 2, BaseShaderRegister = 0, RegisterSpace = 0, OffsetInDescriptorsFromTableStart = -1 };
        GCHandle srvRangeHandle = GCHandle.Alloc(srvRange, GCHandleType.Pinned);

        var graphicsParams = new D3D12_ROOT_PARAMETER[2];
        graphicsParams[0] = new D3D12_ROOT_PARAMETER { ParameterType = 0, DescriptorTable = new D3D12_ROOT_DESCRIPTOR_TABLE { NumDescriptorRanges = 1, pDescriptorRanges = srvRangeHandle.AddrOfPinnedObject() }, ShaderVisibility = 1 };
        graphicsParams[1] = new D3D12_ROOT_PARAMETER { ParameterType = 0, DescriptorTable = new D3D12_ROOT_DESCRIPTOR_TABLE { NumDescriptorRanges = 1, pDescriptorRanges = cbvRangeHandle.AddrOfPinnedObject() }, ShaderVisibility = 1 };

        GCHandle graphicsParamsHandle = GCHandle.Alloc(graphicsParams, GCHandleType.Pinned);
        var graphicsRootSigDesc = new D3D12_ROOT_SIGNATURE_DESC { NumParameters = 2, pParameters = graphicsParamsHandle.AddrOfPinnedObject(), NumStaticSamplers = 0, pStaticSamplers = IntPtr.Zero, Flags = 0 };
        D3D12SerializeRootSignature(ref graphicsRootSigDesc, D3D_ROOT_SIGNATURE_VERSION_1, out IntPtr graphicsSigBlob, out _);
        CheckResult(createRootSig(device, 0, GetBlobBufferPointer(graphicsSigBlob), GetBlobBufferSize(graphicsSigBlob), ref rootSigGuid, out graphicsRootSignature), "CreateRootSignature (Graphics)");

        IntPtr computeShader = CompileShader("hello.hlsl", "CSMain", "cs_5_0");
        IntPtr vertexShader = CompileShader("hello.hlsl", "VSMain", "vs_5_0");
        IntPtr pixelShader = CompileShader("hello.hlsl", "PSMain", "ps_5_0");

        var computePsoDesc = new D3D12_COMPUTE_PIPELINE_STATE_DESC
        {
            pRootSignature = computeRootSignature,
            CS = new D3D12_SHADER_BYTECODE { pShaderBytecode = GetBlobBufferPointer(computeShader), BytecodeLength = GetBlobBufferSize(computeShader) }
        };
        var createComputePso = Marshal.GetDelegateForFunctionPointer<CreateComputePipelineStateDelegate>(Marshal.ReadIntPtr(vTable, 11 * IntPtr.Size));
        Guid psoGuid = IID_ID3D12PipelineState;
        CheckResult(createComputePso(device, ref computePsoDesc, ref psoGuid, out computePso), "CreateComputePipelineState");

        var graphicsPsoDesc = new D3D12_GRAPHICS_PIPELINE_STATE_DESC
        {
            pRootSignature = graphicsRootSignature,
            VS = new D3D12_SHADER_BYTECODE { pShaderBytecode = GetBlobBufferPointer(vertexShader), BytecodeLength = GetBlobBufferSize(vertexShader) },
            PS = new D3D12_SHADER_BYTECODE { pShaderBytecode = GetBlobBufferPointer(pixelShader), BytecodeLength = GetBlobBufferSize(pixelShader) },
            BlendState = new D3D12_BLEND_DESC
            {
                RT0 = new D3D12_RENDER_TARGET_BLEND_DESC { BlendEnable = 0, LogicOpEnable = 0, SrcBlend = 2, DestBlend = 1, BlendOp = 1, SrcBlendAlpha = 2, DestBlendAlpha = 1, BlendOpAlpha = 1, RenderTargetWriteMask = 0xF }
            },
            SampleMask = uint.MaxValue,
            RasterizerState = new D3D12_RASTERIZER_DESC { FillMode = 3, CullMode = 1, DepthClipEnable = 1 },
            DepthStencilState = new D3D12_DEPTH_STENCIL_DESC { DepthEnable = 0, StencilEnable = 0 },
            PrimitiveTopologyType = 2,
            NumRenderTargets = 1,
            RTVFormats = new uint[] { DXGI_FORMAT_R8G8B8A8_UNORM, 0, 0, 0, 0, 0, 0, 0 },
            SampleDesc = new DXGI_SAMPLE_DESC { Count = 1, Quality = 0 }
        };
        var createGraphicsPso = Marshal.GetDelegateForFunctionPointer<CreateGraphicsPipelineStateDelegate>(Marshal.ReadIntPtr(vTable, 10 * IntPtr.Size));
        CheckResult(createGraphicsPso(device, ref graphicsPsoDesc, ref psoGuid, out graphicsPso), "CreateGraphicsPipelineState");

        var defaultHeap = new D3D12_HEAP_PROPERTIES { Type = 1, CPUPageProperty = 0, MemoryPoolPreference = 0, CreationNodeMask = 1, VisibleNodeMask = 1 };
        var uploadHeap = new D3D12_HEAP_PROPERTIES { Type = 2, CPUPageProperty = 0, MemoryPoolPreference = 0, CreationNodeMask = 1, VisibleNodeMask = 1 };

        var bufferDesc = new D3D12_RESOURCE_DESC
        {
            Dimension = 1, Alignment = 0, Width = (ulong)(VERTEX_COUNT * 16), Height = 1,
            DepthOrArraySize = 1, MipLevels = 1, Format = 0, SampleDesc = new DXGI_SAMPLE_DESC { Count = 1, Quality = 0 },
            Layout = 1, Flags = 0x4
        };
        var createResource = Marshal.GetDelegateForFunctionPointer<CreateCommittedResourceDelegate>(Marshal.ReadIntPtr(vTable, 27 * IntPtr.Size));
        Guid resourceGuid = IID_ID3D12Resource;

        // Buffers created with COMMON state (0)
        CheckResult(createResource(device, ref defaultHeap, 0, ref bufferDesc, 0, IntPtr.Zero, ref resourceGuid, out positionBuffer), "CreateResource (Position)");
        CheckResult(createResource(device, ref defaultHeap, 0, ref bufferDesc, 0, IntPtr.Zero, ref resourceGuid, out colorBuffer), "CreateResource (Color)");

        var cbDesc = new D3D12_RESOURCE_DESC
        {
            Dimension = 1, Alignment = 0, Width = 256, Height = 1,
            DepthOrArraySize = 1, MipLevels = 1, Format = 0, SampleDesc = new DXGI_SAMPLE_DESC { Count = 1, Quality = 0 },
            Layout = 1, Flags = 0
        };
        CheckResult(createResource(device, ref uploadHeap, 0, ref cbDesc, 0x1, IntPtr.Zero, ref resourceGuid, out constantBuffer), "CreateResource (ConstantBuffer)");

        IntPtr cbVTable = Marshal.ReadIntPtr(constantBuffer);
        var map = Marshal.GetDelegateForFunctionPointer<MapDelegate>(Marshal.ReadIntPtr(cbVTable, 8 * IntPtr.Size));
        D3D12_RANGE readRange = new D3D12_RANGE();
        CheckResult(map(constantBuffer, 0, ref readRange, out constantBufferPtr), "Map ConstantBuffer");

        var createUAV = Marshal.GetDelegateForFunctionPointer<CreateUnorderedAccessViewDelegate>(Marshal.ReadIntPtr(vTable, 19 * IntPtr.Size));
        var createCBV = Marshal.GetDelegateForFunctionPointer<CreateConstantBufferViewDelegate>(Marshal.ReadIntPtr(vTable, 17 * IntPtr.Size));

        D3D12_CPU_DESCRIPTOR_HANDLE heapHandle = new D3D12_CPU_DESCRIPTOR_HANDLE { ptr = GetCPUDescriptorHandleForHeapStart(srvUavHeap) };

        // 1. UAVs (Slot 0, 1)
        var uavDesc = new D3D12_UNORDERED_ACCESS_VIEW_DESC { Format = 0, ViewDimension = 1, Buffer_FirstElement = 0, Buffer_NumElements = VERTEX_COUNT, Buffer_StructureByteStride = 16 };
        createUAV(device, positionBuffer, IntPtr.Zero, ref uavDesc, heapHandle);
        heapHandle.ptr = IntPtr.Add(heapHandle.ptr, (int)srvUavDescriptorSize);
        createUAV(device, colorBuffer, IntPtr.Zero, ref uavDesc, heapHandle);
        heapHandle.ptr = IntPtr.Add(heapHandle.ptr, (int)srvUavDescriptorSize);

        // 2. SRVs (Slot 2, 3) - Fixed ViewDimension to BUFFER (1)
        var srvDesc = new D3D12_SHADER_RESOURCE_VIEW_DESC { Format = 0, ViewDimension = D3D12_SRV_DIMENSION_BUFFER, Shader4ComponentMapping = 5768, Buffer_FirstElement = 0, Buffer_NumElements = VERTEX_COUNT, Buffer_StructureByteStride = 16 };
        CreateSRV(positionBuffer, srvDesc, heapHandle);
        heapHandle.ptr = IntPtr.Add(heapHandle.ptr, (int)srvUavDescriptorSize);
        CreateSRV(colorBuffer, srvDesc, heapHandle);
        heapHandle.ptr = IntPtr.Add(heapHandle.ptr, (int)srvUavDescriptorSize);

        // 3. CBV (Slot 4)
        IntPtr cbResVTable = Marshal.ReadIntPtr(constantBuffer);
        var getGPUVirtualAddress = Marshal.GetDelegateForFunctionPointer<GetGPUVirtualAddressDelegate>(Marshal.ReadIntPtr(cbResVTable, 11 * IntPtr.Size));
        var cbvDesc = new D3D12_CONSTANT_BUFFER_VIEW_DESC { BufferLocation = getGPUVirtualAddress(constantBuffer), SizeInBytes = 256 };
        createCBV(device, ref cbvDesc, heapHandle);

        var createCommandList = Marshal.GetDelegateForFunctionPointer<CreateCommandListDelegate>(Marshal.ReadIntPtr(vTable, 12 * IntPtr.Size));
        Guid cmdListGuid = IID_ID3D12GraphicsCommandList;
        CheckResult(createCommandList(device, 0, 0, commandAllocator, graphicsPso, ref cmdListGuid, out commandList), "CreateCommandList (Graphics)");
        CheckResult(createCommandList(device, 0, 0, computeCommandAllocator, computePso, ref cmdListGuid, out computeCommandList), "CreateCommandList (Compute)");

        IntPtr cmdListVTable = Marshal.ReadIntPtr(commandList);
        var close = Marshal.GetDelegateForFunctionPointer<CloseCommandListDelegate>(Marshal.ReadIntPtr(cmdListVTable, 9 * IntPtr.Size));
        close(commandList);
        close(computeCommandList);

        var createFence = Marshal.GetDelegateForFunctionPointer<CreateFenceDelegate>(Marshal.ReadIntPtr(vTable, 36 * IntPtr.Size));
        Guid fenceGuid = IID_ID3D12Fence;
        CheckResult(createFence(device, 0, 0, ref fenceGuid, out fence), "CreateFence");
        fenceValue = 1;
        fenceEvent = CreateEvent(IntPtr.Zero, false, false, null);
        Log("Fence Created. Assets Loaded.");

        uavRangeHandle.Free();
        cbvRangeHandle.Free();
        srvRangeHandle.Free();
        computeParamsHandle.Free();
        graphicsParamsHandle.Free();
    }

    void WaitForPreviousFrame()
    {
        ulong currentFenceValue = fenceValue;

        IntPtr queueVTable = Marshal.ReadIntPtr(commandQueue);
        var signal = Marshal.GetDelegateForFunctionPointer<SignalDelegate>(Marshal.ReadIntPtr(queueVTable, 14 * IntPtr.Size));
        signal(commandQueue, fence, currentFenceValue);
        fenceValue++;

        IntPtr fenceVTable = Marshal.ReadIntPtr(fence);
        var getCompletedValue = Marshal.GetDelegateForFunctionPointer<GetCompletedValueDelegate>(Marshal.ReadIntPtr(fenceVTable, 8 * IntPtr.Size));
        if (getCompletedValue(fence) < currentFenceValue)
        {
            var setEventOnCompletion = Marshal.GetDelegateForFunctionPointer<SetEventOnCompletionDelegate>(Marshal.ReadIntPtr(fenceVTable, 9 * IntPtr.Size));
            setEventOnCompletion(fence, currentFenceValue, fenceEvent);
            WaitForSingleObject(fenceEvent, INFINITE);
        }

        IntPtr swapChainVTable = Marshal.ReadIntPtr(swapChain);
        var getCurrentBackBufferIndex = Marshal.GetDelegateForFunctionPointer<GetCurrentBackBufferIndexDelegate>(Marshal.ReadIntPtr(swapChainVTable, 36 * IntPtr.Size));
        frameIndex = getCurrentBackBufferIndex(swapChain);
    }

    void Render()
    {
        f1 = (f1 + (float)rand.NextDouble() / 200f) % 10f;
        f2 = (f2 + (float)rand.NextDouble() / 200f) % 10f;
        p1 += (PI2 * 0.5f / 360f);

        var cbData = new HarmonographParams
        {
            A1 = A1, f1 = f1, p1 = p1, d1 = d1,
            A2 = A2, f2 = f2, p2 = p2, d2 = d2,
            A3 = A3, f3 = f3, p3 = p3, d3 = d3,
            A4 = A4, f4 = f4, p4 = p4, d4 = d4,
            max_num = VERTEX_COUNT,
            resolutionX = WIDTH, resolutionY = HEIGHT
        };
        Marshal.StructureToPtr(cbData, constantBufferPtr, false);

        IntPtr computeAllocVTable = Marshal.ReadIntPtr(computeCommandAllocator);
        var resetAllocator = Marshal.GetDelegateForFunctionPointer<ResetCommandAllocatorDelegate>(Marshal.ReadIntPtr(computeAllocVTable, 8 * IntPtr.Size));
        resetAllocator(computeCommandAllocator);

        IntPtr computeCmdVTable = Marshal.ReadIntPtr(computeCommandList);
        var resetCmdList = Marshal.GetDelegateForFunctionPointer<ResetCommandListDelegate>(Marshal.ReadIntPtr(computeCmdVTable, 10 * IntPtr.Size));
        resetCmdList(computeCommandList, computeCommandAllocator, computePso);

        var setDescriptorHeaps = Marshal.GetDelegateForFunctionPointer<SetDescriptorHeapsDelegate>(Marshal.ReadIntPtr(computeCmdVTable, 28 * IntPtr.Size));
        var setComputeRootSig = Marshal.GetDelegateForFunctionPointer<SetComputeRootSignatureDelegate>(Marshal.ReadIntPtr(computeCmdVTable, 29 * IntPtr.Size));
        var setComputeRootDescTable = Marshal.GetDelegateForFunctionPointer<SetComputeRootDescriptorTableDelegate>(Marshal.ReadIntPtr(computeCmdVTable, 31 * IntPtr.Size));
        var dispatch = Marshal.GetDelegateForFunctionPointer<DispatchDelegate>(Marshal.ReadIntPtr(computeCmdVTable, 14 * IntPtr.Size));
        var resourceBarrier = Marshal.GetDelegateForFunctionPointer<ResourceBarrierDelegate>(Marshal.ReadIntPtr(computeCmdVTable, 26 * IntPtr.Size));
        var closeCmdList = Marshal.GetDelegateForFunctionPointer<CloseCommandListDelegate>(Marshal.ReadIntPtr(computeCmdVTable, 9 * IntPtr.Size));

        IntPtr[] heaps = new IntPtr[] { srvUavHeap };
        setDescriptorHeaps(computeCommandList, 1, heaps);
        setComputeRootSig(computeCommandList, computeRootSignature);

        D3D12_GPU_DESCRIPTOR_HANDLE gpuHandle = GetGPUDescriptorHandleForHeapStart(srvUavHeap);
        setComputeRootDescTable(computeCommandList, 0, gpuHandle);
        gpuHandle.ptr += srvUavDescriptorSize * 4;
        setComputeRootDescTable(computeCommandList, 1, gpuHandle);

        dispatch(computeCommandList, (uint)((VERTEX_COUNT + 63) / 64), 1, 1);

        var barriers = new D3D12_RESOURCE_BARRIER[] {
            new D3D12_RESOURCE_BARRIER { Type = 0, Flags = 0, pResource = positionBuffer, Subresource = 0xFFFFFFFF, StateBefore = 0x8, StateAfter = 0x40 },
            new D3D12_RESOURCE_BARRIER { Type = 0, Flags = 0, pResource = colorBuffer, Subresource = 0xFFFFFFFF, StateBefore = 0x8, StateAfter = 0x40 }
        };
        resourceBarrier(computeCommandList, 2, ref barriers[0]);

        closeCmdList(computeCommandList);

        IntPtr queueVTable = Marshal.ReadIntPtr(commandQueue);
        var executeCommandLists = Marshal.GetDelegateForFunctionPointer<ExecuteCommandListsDelegate>(Marshal.ReadIntPtr(queueVTable, 10 * IntPtr.Size));
        IntPtr[] computeLists = new IntPtr[] { computeCommandList };
        executeCommandLists(commandQueue, 1, computeLists);

        IntPtr allocVTable = Marshal.ReadIntPtr(commandAllocator);
        resetAllocator = Marshal.GetDelegateForFunctionPointer<ResetCommandAllocatorDelegate>(Marshal.ReadIntPtr(allocVTable, 8 * IntPtr.Size));
        resetAllocator(commandAllocator);

        IntPtr cmdVTable = Marshal.ReadIntPtr(commandList);
        resetCmdList = Marshal.GetDelegateForFunctionPointer<ResetCommandListDelegate>(Marshal.ReadIntPtr(cmdVTable, 10 * IntPtr.Size));
        resetCmdList(commandList, commandAllocator, graphicsPso);

        var setGraphicsRootSig = Marshal.GetDelegateForFunctionPointer<SetGraphicsRootSignatureDelegate>(Marshal.ReadIntPtr(cmdVTable, 30 * IntPtr.Size));
        var setGraphicsRootDescTable = Marshal.GetDelegateForFunctionPointer<SetGraphicsRootDescriptorTableDelegate>(Marshal.ReadIntPtr(cmdVTable, 32 * IntPtr.Size));
        var rsSetViewports = Marshal.GetDelegateForFunctionPointer<RSSetViewportsDelegate>(Marshal.ReadIntPtr(cmdVTable, 21 * IntPtr.Size));
        var rsSetScissorRects = Marshal.GetDelegateForFunctionPointer<RSSetScissorRectsDelegate>(Marshal.ReadIntPtr(cmdVTable, 22 * IntPtr.Size));
        var clearRTV = Marshal.GetDelegateForFunctionPointer<ClearRenderTargetViewDelegate>(Marshal.ReadIntPtr(cmdVTable, 48 * IntPtr.Size));
        var omSetRenderTargets = Marshal.GetDelegateForFunctionPointer<OMSetRenderTargetsDelegate>(Marshal.ReadIntPtr(cmdVTable, 46 * IntPtr.Size));
        var iaSetPrimitiveTopology = Marshal.GetDelegateForFunctionPointer<IASetPrimitiveTopologyDelegate>(Marshal.ReadIntPtr(cmdVTable, 20 * IntPtr.Size));
        var drawInstanced = Marshal.GetDelegateForFunctionPointer<DrawInstancedDelegate>(Marshal.ReadIntPtr(cmdVTable, 12 * IntPtr.Size));

        setDescriptorHeaps(commandList, 1, heaps);
        setGraphicsRootSig(commandList, graphicsRootSignature);

        gpuHandle = GetGPUDescriptorHandleForHeapStart(srvUavHeap);
        gpuHandle.ptr += srvUavDescriptorSize * 2;
        setGraphicsRootDescTable(commandList, 0, gpuHandle);
        gpuHandle.ptr += srvUavDescriptorSize * 2;
        setGraphicsRootDescTable(commandList, 1, gpuHandle);

        var viewport = new D3D12_VIEWPORT { TopLeftX = 0, TopLeftY = 0, Width = WIDTH, Height = HEIGHT, MinDepth = 0, MaxDepth = 1 };
        var scissorRect = new D3D12_RECT { left = 0, top = 0, right = WIDTH, bottom = HEIGHT };
        rsSetViewports(commandList, 1, ref viewport);
        rsSetScissorRects(commandList, 1, ref scissorRect);

        var rtBarrier = new D3D12_RESOURCE_BARRIER { Type = 0, Flags = 0, pResource = renderTargets[frameIndex], Subresource = 0xFFFFFFFF, StateBefore = 0, StateAfter = 4 };
        resourceBarrier(commandList, 1, ref rtBarrier);

        D3D12_CPU_DESCRIPTOR_HANDLE rtvHandle = new D3D12_CPU_DESCRIPTOR_HANDLE { ptr = GetCPUDescriptorHandleForHeapStart(rtvHeap) };
        rtvHandle.ptr = IntPtr.Add(rtvHandle.ptr, (int)(frameIndex * rtvDescriptorSize));

        float[] clearColor = { 0.05f, 0.05f, 0.1f, 1f };
        clearRTV(commandList, rtvHandle, clearColor, 0, IntPtr.Zero);
        omSetRenderTargets(commandList, 1, ref rtvHandle, 0, IntPtr.Zero);

        iaSetPrimitiveTopology(commandList, 3);
        drawInstanced(commandList, VERTEX_COUNT, 1, 0, 0);

        rtBarrier.StateBefore = 4;
        rtBarrier.StateAfter = 0;
        resourceBarrier(commandList, 1, ref rtBarrier);

        barriers[0].StateBefore = 0x40; barriers[0].StateAfter = 0x8;
        barriers[1].StateBefore = 0x40; barriers[1].StateAfter = 0x8;
        resourceBarrier(commandList, 2, ref barriers[0]);

        closeCmdList(commandList);

        IntPtr[] graphicsLists = new IntPtr[] { commandList };
        executeCommandLists(commandQueue, 1, graphicsLists);

        IntPtr swapChainVTable = Marshal.ReadIntPtr(swapChain);
        var present = Marshal.GetDelegateForFunctionPointer<PresentDelegate>(Marshal.ReadIntPtr(swapChainVTable, 8 * IntPtr.Size));
        present(swapChain, 1, 0);

        WaitForPreviousFrame();
    }

    static IntPtr WndProc(IntPtr hWnd, uint uMsg, IntPtr wParam, IntPtr lParam)
    {
        if (uMsg == WM_DESTROY) { PostQuitMessage(0); return IntPtr.Zero; }
        return DefWindowProc(hWnd, uMsg, wParam, lParam);
    }

    [STAThread]
    static int Main(string[] args)
    {
        var app = new Harmonograph();

        try
        {
            app.EnableDebugLayer();

            wndProcDelegate = new WndProcDelegate(WndProc);

            var wndClass = new WNDCLASSEX
            {
                cbSize = (uint)Marshal.SizeOf(typeof(WNDCLASSEX)),
                style = CS_OWNDC,
                lpfnWndProc = wndProcDelegate,
                hCursor = LoadCursor(IntPtr.Zero, IDC_ARROW),
                lpszClassName = "HarmonographDX12"
            };
            RegisterClassEx(ref wndClass);

            IntPtr hwnd = CreateWindowEx(0, "HarmonographDX12", "DirectX 12 Compute Harmonograph (Fixed SRV)",
                WS_OVERLAPPEDWINDOW | WS_VISIBLE, 100, 100, WIDTH, HEIGHT, IntPtr.Zero, IntPtr.Zero, IntPtr.Zero, IntPtr.Zero);

            app.LoadPipeline(hwnd);
            app.LoadAssets();
            ShowWindow(hwnd, 1);

            MSG msg = new MSG();
            while (msg.message != WM_QUIT)
            {
                if (PeekMessage(out msg, IntPtr.Zero, 0, 0, PM_REMOVE))
                {
                    TranslateMessage(ref msg);
                    DispatchMessage(ref msg);
                }
                else
                {
                    app.Render();
                }
            }
        }
        catch (Exception ex)
        {
            Console.WriteLine($"\n[ERROR] Unhandled Exception: {ex.Message}");
            Console.WriteLine(ex.StackTrace);
            Console.WriteLine("\nPress Enter to exit...");
            Console.ReadLine();
        }

        return 0;
    }
}