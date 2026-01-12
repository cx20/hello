$source = @"
using System;
using System.Runtime.InteropServices;
using System.IO;
using System.Text;

public class Harmonograph
{
    #region Win32 Structures & Constants

    [StructLayout(LayoutKind.Sequential)]
    public struct POINT { public int X; public int Y; }

    [StructLayout(LayoutKind.Sequential)]
    public struct MSG
    {
        public IntPtr hwnd;
        public uint message;
        public IntPtr wParam;
        public IntPtr lParam;
        public uint time;
        public POINT pt;
    }

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    struct WNDCLASSEX
    {
        public uint cbSize;
        public uint style;
        public IntPtr lpfnWndProc;
        public int cbClsExtra;
        public int cbWndExtra;
        public IntPtr hInstance;
        public IntPtr hIcon;
        public IntPtr hCursor;
        public IntPtr hbrBackground;
        public string lpszMenuName;
        public string lpszClassName;
        public IntPtr hIconSm;
    }

    delegate IntPtr WndProcDelegate(IntPtr hWnd, uint uMsg, IntPtr wParam, IntPtr lParam);

    const int IDC_ARROW = 32512;
    const uint WM_DESTROY = 0x0002;
    const uint WM_QUIT    = 0x0012;
    const uint PM_REMOVE  = 0x0001;

    const uint WS_OVERLAPPEDWINDOW = 0x00CF0000;
    const uint WS_VISIBLE          = 0x10000000;

    const uint INFINITE = 0xFFFFFFFF;

    #endregion

    #region DX12 Structures

    [StructLayout(LayoutKind.Sequential)] struct D3D12_COMMAND_QUEUE_DESC { public int Type; public int Priority; public int Flags; public uint NodeMask; }
    [StructLayout(LayoutKind.Sequential)] struct D3D12_DESCRIPTOR_HEAP_DESC { public int Type; public uint NumDescriptors; public int Flags; public uint NodeMask; }
    [StructLayout(LayoutKind.Sequential)] struct DXGI_SWAP_CHAIN_DESC1 { public uint Width; public uint Height; public uint Format; public int Stereo; public DXGI_SAMPLE_DESC SampleDesc; public uint BufferUsage; public uint BufferCount; public int Scaling; public uint SwapEffect; public int AlphaMode; public uint Flags; }
    [StructLayout(LayoutKind.Sequential)] struct DXGI_SAMPLE_DESC { public uint Count; public uint Quality; }
    [StructLayout(LayoutKind.Sequential)] struct D3D12_RESOURCE_DESC { public int Dimension; public ulong Alignment; public ulong Width; public uint Height; public ushort DepthOrArraySize; public ushort MipLevels; public uint Format; public DXGI_SAMPLE_DESC SampleDesc; public int Layout; public int Flags; }
    [StructLayout(LayoutKind.Sequential)] struct D3D12_HEAP_PROPERTIES { public int Type; public int CPUPageProperty; public int MemoryPoolPreference; public uint CreationNodeMask; public uint VisibleNodeMask; }
    [StructLayout(LayoutKind.Sequential)] struct D3D12_CPU_DESCRIPTOR_HANDLE { public IntPtr ptr; }
    [StructLayout(LayoutKind.Sequential)] struct D3D12_GPU_DESCRIPTOR_HANDLE { public ulong ptr; }
    [StructLayout(LayoutKind.Sequential)] struct D3D12_RESOURCE_BARRIER { public int Type; public int Flags; public IntPtr pResource; public uint Subresource; public int StateBefore; public int StateAfter; }
    [StructLayout(LayoutKind.Sequential)] struct D3D12_VIEWPORT { public float TopLeftX; public float TopLeftY; public float Width; public float Height; public float MinDepth; public float MaxDepth; }
    [StructLayout(LayoutKind.Sequential)] struct D3D12_RECT { public int left; public int top; public int right; public int bottom; }
    [StructLayout(LayoutKind.Sequential)] struct D3D12_ROOT_SIGNATURE_DESC { public uint NumParameters; public IntPtr pParameters; public uint NumStaticSamplers; public IntPtr pStaticSamplers; public int Flags; }

    [StructLayout(LayoutKind.Explicit, Size = 32)]
    struct D3D12_ROOT_PARAMETER
    {
        [FieldOffset(0)]  public int ParameterType;
        [FieldOffset(8)]  public D3D12_ROOT_DESCRIPTOR_TABLE DescriptorTable;
        [FieldOffset(24)] public int ShaderVisibility;
    }

    [StructLayout(LayoutKind.Sequential)] struct D3D12_ROOT_DESCRIPTOR_TABLE { public uint NumDescriptorRanges; public IntPtr pDescriptorRanges; }

    [StructLayout(LayoutKind.Sequential)]
    struct D3D12_DESCRIPTOR_RANGE
    {
        public int RangeType;
        public uint NumDescriptors;
        public uint BaseShaderRegister;
        public uint RegisterSpace;
        public uint OffsetInDescriptorsFromTableStart;
    }

    [StructLayout(LayoutKind.Sequential)] struct D3D12_SHADER_BYTECODE { public IntPtr pShaderBytecode; public IntPtr BytecodeLength; }

    [StructLayout(LayoutKind.Sequential)]
    struct D3D12_GRAPHICS_PIPELINE_STATE_DESC
    {
        public IntPtr pRootSignature;
        public D3D12_SHADER_BYTECODE VS;
        public D3D12_SHADER_BYTECODE PS;
        public D3D12_SHADER_BYTECODE DS;
        public D3D12_SHADER_BYTECODE HS;
        public D3D12_SHADER_BYTECODE GS;
        public D3D12_STREAM_OUTPUT_DESC StreamOutput;
        public D3D12_BLEND_DESC BlendState;
        public uint SampleMask;
        public D3D12_RASTERIZER_DESC RasterizerState;
        public D3D12_DEPTH_STENCIL_DESC DepthStencilState;
        public D3D12_INPUT_LAYOUT_DESC InputLayout;
        public int IBStripCutValue;
        public int PrimitiveTopologyType;
        public uint NumRenderTargets;
        [MarshalAs(UnmanagedType.ByValArray, SizeConst = 8)] public uint[] RTVFormats;
        public uint DSVFormat;
        public DXGI_SAMPLE_DESC SampleDesc;
        public uint NodeMask;
        public D3D12_CACHED_PIPELINE_STATE CachedPSO;
        public int Flags;
    }

    [StructLayout(LayoutKind.Sequential)]
    struct D3D12_COMPUTE_PIPELINE_STATE_DESC
    {
        public IntPtr pRootSignature;
        public D3D12_SHADER_BYTECODE CS;
        public uint NodeMask;
        public D3D12_CACHED_PIPELINE_STATE CachedPSO;
        public int Flags;
    }

    [StructLayout(LayoutKind.Sequential)] struct D3D12_STREAM_OUTPUT_DESC { public IntPtr pSODeclaration; public uint NumEntries; public IntPtr pBufferStrides; public uint NumStrides; public uint RasterizedStream; }
    [StructLayout(LayoutKind.Sequential)] struct D3D12_BLEND_DESC { public int AlphaToCoverageEnable; public int IndependentBlendEnable; [MarshalAs(UnmanagedType.ByValArray, SizeConst = 8)] public D3D12_RENDER_TARGET_BLEND_DESC[] RenderTarget; }
    [StructLayout(LayoutKind.Sequential)] struct D3D12_RENDER_TARGET_BLEND_DESC { public int BlendEnable; public int LogicOpEnable; public int SrcBlend; public int DestBlend; public int BlendOp; public int SrcBlendAlpha; public int DestBlendAlpha; public int BlendOpAlpha; public int LogicOp; public byte RenderTargetWriteMask; }
    [StructLayout(LayoutKind.Sequential)] struct D3D12_RASTERIZER_DESC { public int FillMode; public int CullMode; public int FrontCounterClockwise; public int DepthBias; public float DepthBiasClamp; public float SlopeScaledDepthBias; public int DepthClipEnable; public int MultisampleEnable; public int AntialiasedLineEnable; public uint ForcedSampleCount; public int ConservativeRaster; }
    [StructLayout(LayoutKind.Sequential)] struct D3D12_DEPTH_STENCIL_DESC { public int DepthEnable; public int DepthWriteMask; public int DepthFunc; public int StencilEnable; public byte StencilReadMask; public byte StencilWriteMask; public D3D12_DEPTH_STENCILOP_DESC FrontFace; public D3D12_DEPTH_STENCILOP_DESC BackFace; }
    [StructLayout(LayoutKind.Sequential)] struct D3D12_DEPTH_STENCILOP_DESC { public int StencilFailOp; public int StencilDepthFailOp; public int StencilPassOp; public int StencilFunc; }
    [StructLayout(LayoutKind.Sequential)] struct D3D12_INPUT_LAYOUT_DESC { public IntPtr pInputElementDescs; public uint NumElements; }
    [StructLayout(LayoutKind.Sequential)] struct D3D12_CACHED_PIPELINE_STATE { public IntPtr pCachedBlob; public IntPtr CachedBlobSizeInBytes; }

    [StructLayout(LayoutKind.Sequential)] struct D3D12_UNORDERED_ACCESS_VIEW_DESC { public uint Format; public int ViewDimension; public ulong Buffer_FirstElement; public uint Buffer_NumElements; public uint Buffer_StructureByteStride; public ulong Buffer_CounterOffsetInBytes; public int Buffer_Flags; }
    [StructLayout(LayoutKind.Sequential)] struct D3D12_SHADER_RESOURCE_VIEW_DESC { public uint Format; public int ViewDimension; public int Shader4ComponentMapping; public ulong Buffer_FirstElement; public uint Buffer_NumElements; public uint Buffer_StructureByteStride; public int Buffer_Flags; }
    [StructLayout(LayoutKind.Sequential)] struct D3D12_CONSTANT_BUFFER_VIEW_DESC { public ulong BufferLocation; public uint SizeInBytes; }
    [StructLayout(LayoutKind.Sequential)] struct D3D12_RANGE { public ulong Begin; public ulong End; }

    [StructLayout(LayoutKind.Sequential)]
    struct HarmonographParams
    {
        public float A1, f1, p1, d1;
        public float A2, f2, p2, d2;
        public float A3, f3, p3, d3;
        public float A4, f4, p4, d4;
        public uint max_num;
        public float pad1, pad2, pad3;
        public float resX, resY;
        public float pad4, pad5;
    }

    #endregion

    #region Imports (W版固定)

    [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Unicode, EntryPoint="DefWindowProcW")]
    static extern IntPtr DefWindowProc(IntPtr hWnd, uint uMsg, IntPtr wParam, IntPtr lParam);

    [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Unicode, EntryPoint="LoadCursorW")]
    static extern IntPtr LoadCursor(IntPtr hInstance, int lpCursorName);

    [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Unicode, EntryPoint="RegisterClassExW")]
    static extern ushort RegisterClassEx([In] ref WNDCLASSEX lpwcx);

    [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Unicode, EntryPoint="CreateWindowExW")]
    static extern IntPtr CreateWindowEx(uint dwExStyle, string lpClassName, string lpWindowName, uint dwStyle,
        int x, int y, int nWidth, int nHeight, IntPtr hWndParent, IntPtr hMenu, IntPtr hInstance, IntPtr lpParam);

    [DllImport("user32.dll", CharSet = CharSet.Unicode, EntryPoint="PeekMessageW")]
    static extern bool PeekMessage(out MSG lpMsg, IntPtr hWnd, uint wMsgFilterMin, uint wMsgFilterMax, uint wRemoveMsg);

    [DllImport("user32.dll", CharSet = CharSet.Unicode, EntryPoint="TranslateMessage")]
    static extern bool TranslateMessage([In] ref MSG lpMsg);

    [DllImport("user32.dll", CharSet = CharSet.Unicode, EntryPoint="DispatchMessageW")]
    static extern IntPtr DispatchMessage([In] ref MSG lpMsg);

    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    static extern void PostQuitMessage(int nExitCode);

    [DllImport("kernel32.dll")]
    static extern IntPtr CreateEvent(IntPtr lpEventAttributes, bool bManualReset, bool bInitialState, string lpName);

    [DllImport("kernel32.dll")]
    static extern uint WaitForSingleObject(IntPtr hHandle, uint dwMilliseconds);

    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, EntryPoint="GetModuleHandleW")]
    static extern IntPtr GetModuleHandle(string lpModuleName);

    [DllImport("d3d12.dll")] static extern int D3D12CreateDevice(IntPtr pAdapter, uint MinimumFeatureLevel, ref Guid riid, out IntPtr ppDevice);
    [DllImport("d3d12.dll")] static extern int D3D12SerializeRootSignature(ref D3D12_ROOT_SIGNATURE_DESC pRootSignature, uint Version, out IntPtr ppBlob, out IntPtr ppErrorBlob);
    [DllImport("d3d12.dll")] static extern int D3D12GetDebugInterface(ref Guid riid, out IntPtr ppvDebug);
    [DllImport("dxgi.dll")]  static extern int CreateDXGIFactory1(ref Guid riid, out IntPtr ppFactory);

    [DllImport("d3dcompiler_47.dll")]
    static extern int D3DCompile(IntPtr pSrcData, IntPtr SrcDataSize, string pSourceName, IntPtr pDefines, IntPtr pInclude,
        string pEntrypoint, string pTarget, uint Flags1, uint Flags2, out IntPtr ppCode, out IntPtr ppErrorMsgs);

    #endregion

    #region Delegates

    [UnmanagedFunctionPointer(CallingConvention.StdCall)] delegate int  CreateCommandQueueDelegate(IntPtr device, ref D3D12_COMMAND_QUEUE_DESC pDesc, ref Guid riid, out IntPtr ppCommandQueue);
    [UnmanagedFunctionPointer(CallingConvention.StdCall)] delegate int  CreateCommandAllocatorDelegate(IntPtr device, int type, ref Guid riid, out IntPtr ppCommandAllocator);
    [UnmanagedFunctionPointer(CallingConvention.StdCall)] delegate int  CreateGraphicsPipelineStateDelegate(IntPtr device, ref D3D12_GRAPHICS_PIPELINE_STATE_DESC pDesc, ref Guid riid, out IntPtr ppPipelineState);
    [UnmanagedFunctionPointer(CallingConvention.StdCall)] delegate int  CreateComputePipelineStateDelegate(IntPtr device, ref D3D12_COMPUTE_PIPELINE_STATE_DESC pDesc, ref Guid riid, out IntPtr ppPipelineState);
    [UnmanagedFunctionPointer(CallingConvention.StdCall)] delegate int  CreateCommandListDelegate(IntPtr device, uint nodeMask, int type, IntPtr pCommandAllocator, IntPtr pInitialState, ref Guid riid, out IntPtr ppCommandList);
    [UnmanagedFunctionPointer(CallingConvention.StdCall)] delegate int  CreateDescriptorHeapDelegate(IntPtr device, ref D3D12_DESCRIPTOR_HEAP_DESC pDesc, ref Guid riid, out IntPtr ppHeap);
    [UnmanagedFunctionPointer(CallingConvention.StdCall)] delegate uint GetDescriptorHandleIncrementSizeDelegate(IntPtr device, int descriptorHeapType);
    [UnmanagedFunctionPointer(CallingConvention.StdCall)] delegate int  CreateRootSignatureDelegate(IntPtr device, uint nodeMask, IntPtr pBlobWithRootSignature, IntPtr blobLengthInBytes, ref Guid riid, out IntPtr ppvRootSignature);
    [UnmanagedFunctionPointer(CallingConvention.StdCall)] delegate int  CreateCommittedResourceDelegate(IntPtr device, ref D3D12_HEAP_PROPERTIES pHeapProperties, int HeapFlags, ref D3D12_RESOURCE_DESC pDesc, int InitialResourceState, IntPtr pOptimizedClearValue, ref Guid riid, out IntPtr ppvResource);
    [UnmanagedFunctionPointer(CallingConvention.StdCall)] delegate int  CreateFenceDelegate(IntPtr device, ulong InitialValue, int Flags, ref Guid riid, out IntPtr ppFence);
    [UnmanagedFunctionPointer(CallingConvention.StdCall)] delegate void CreateRenderTargetViewDelegate(IntPtr device, IntPtr pResource, IntPtr pDesc, D3D12_CPU_DESCRIPTOR_HANDLE DestDescriptor);
    [UnmanagedFunctionPointer(CallingConvention.StdCall)] delegate void CreateUnorderedAccessViewDelegate(IntPtr device, IntPtr pResource, IntPtr pCounterResource, ref D3D12_UNORDERED_ACCESS_VIEW_DESC pDesc, D3D12_CPU_DESCRIPTOR_HANDLE DestDescriptor);
    [UnmanagedFunctionPointer(CallingConvention.StdCall)] delegate void CreateShaderResourceViewDelegate(IntPtr device, IntPtr pResource, ref D3D12_SHADER_RESOURCE_VIEW_DESC pDesc, D3D12_CPU_DESCRIPTOR_HANDLE DestDescriptor);
    [UnmanagedFunctionPointer(CallingConvention.StdCall)] delegate void CreateConstantBufferViewDelegate(IntPtr device, ref D3D12_CONSTANT_BUFFER_VIEW_DESC pDesc, D3D12_CPU_DESCRIPTOR_HANDLE DestDescriptor);
    [UnmanagedFunctionPointer(CallingConvention.StdCall)] delegate int  CreateSwapChainForHwndDelegate(IntPtr factory, IntPtr pDevice, IntPtr hWnd, ref DXGI_SWAP_CHAIN_DESC1 pDesc, IntPtr pFullscreenDesc, IntPtr pRestrictToOutput, out IntPtr ppSwapChain);
    [UnmanagedFunctionPointer(CallingConvention.StdCall)] delegate int  GetBufferDelegate(IntPtr swapChain, uint Buffer, ref Guid riid, out IntPtr ppSurface);
    [UnmanagedFunctionPointer(CallingConvention.StdCall)] delegate int  PresentDelegate(IntPtr swapChain, uint SyncInterval, uint Flags);
    [UnmanagedFunctionPointer(CallingConvention.StdCall)] delegate uint GetCurrentBackBufferIndexDelegate(IntPtr swapChain);
    [UnmanagedFunctionPointer(CallingConvention.StdCall)] delegate int  CloseDelegate(IntPtr commandList);
    [UnmanagedFunctionPointer(CallingConvention.StdCall)] delegate int  ResetDelegate(IntPtr commandList, IntPtr pAllocator, IntPtr pInitialState);
    [UnmanagedFunctionPointer(CallingConvention.StdCall)] delegate int  ResetAllocDelegate(IntPtr commandAllocator);
    [UnmanagedFunctionPointer(CallingConvention.StdCall)] delegate void DrawInstancedDelegate(IntPtr commandList, uint VertexCountPerInstance, uint InstanceCount, uint StartVertexLocation, uint StartInstanceLocation);
    [UnmanagedFunctionPointer(CallingConvention.StdCall)] delegate void DispatchDelegate(IntPtr commandList, uint ThreadGroupCountX, uint ThreadGroupCountY, uint ThreadGroupCountZ);
    [UnmanagedFunctionPointer(CallingConvention.StdCall)] delegate void ExecuteCommandListsDelegate(IntPtr commandQueue, uint NumCommandLists, IntPtr[] ppCommandLists);
    [UnmanagedFunctionPointer(CallingConvention.StdCall)] delegate int  SignalDelegate(IntPtr commandQueue, IntPtr fence, ulong Value);
    [UnmanagedFunctionPointer(CallingConvention.StdCall)] delegate ulong GetCompletedValueDelegate(IntPtr fence);
    [UnmanagedFunctionPointer(CallingConvention.StdCall)] delegate int  SetEventOnCompletionDelegate(IntPtr fence, ulong Value, IntPtr hEvent);
    [UnmanagedFunctionPointer(CallingConvention.StdCall)] delegate void ResourceBarrierDelegate(IntPtr commandList, uint NumBarriers, ref D3D12_RESOURCE_BARRIER pBarriers);
    [UnmanagedFunctionPointer(CallingConvention.StdCall)] delegate void SetGraphicsRootSignatureDelegate(IntPtr commandList, IntPtr pRootSignature);
    [UnmanagedFunctionPointer(CallingConvention.StdCall)] delegate void SetComputeRootSignatureDelegate(IntPtr commandList, IntPtr pRootSignature);
    [UnmanagedFunctionPointer(CallingConvention.StdCall)] delegate void SetPipelineStateDelegate(IntPtr commandList, IntPtr pPipelineState);
    [UnmanagedFunctionPointer(CallingConvention.StdCall)] delegate void RSSetViewportsDelegate(IntPtr commandList, uint NumViewports, ref D3D12_VIEWPORT pViewports);
    [UnmanagedFunctionPointer(CallingConvention.StdCall)] delegate void RSSetScissorRectsDelegate(IntPtr commandList, uint NumRects, ref D3D12_RECT pRects);
    [UnmanagedFunctionPointer(CallingConvention.StdCall)] delegate void OMSetRenderTargetsDelegate(IntPtr commandList, uint NumRenderTargetDescriptors, ref D3D12_CPU_DESCRIPTOR_HANDLE pRenderTargetDescriptors, bool RTsSingleHandleToDescriptorRange, IntPtr pDepthStencilDescriptor);
    [UnmanagedFunctionPointer(CallingConvention.StdCall)] delegate void ClearRenderTargetViewDelegate(IntPtr commandList, D3D12_CPU_DESCRIPTOR_HANDLE RenderTargetView, float[] ColorRGBA, uint NumRects, IntPtr pRects);
    [UnmanagedFunctionPointer(CallingConvention.StdCall)] delegate void IASetPrimitiveTopologyDelegate(IntPtr commandList, int PrimitiveTopology);
    [UnmanagedFunctionPointer(CallingConvention.StdCall)] delegate void SetDescriptorHeapsDelegate(IntPtr commandList, uint NumDescriptorHeaps, IntPtr[] ppDescriptorHeaps);
    [UnmanagedFunctionPointer(CallingConvention.StdCall)] delegate void SetGraphicsRootDescriptorTableDelegate(IntPtr commandList, uint RootParameterIndex, D3D12_GPU_DESCRIPTOR_HANDLE BaseDescriptor);
    [UnmanagedFunctionPointer(CallingConvention.StdCall)] delegate void SetComputeRootDescriptorTableDelegate(IntPtr commandList, uint RootParameterIndex, D3D12_GPU_DESCRIPTOR_HANDLE BaseDescriptor);
    [UnmanagedFunctionPointer(CallingConvention.StdCall)] delegate IntPtr GetBufferPointerDelegate(IntPtr blob);
    [UnmanagedFunctionPointer(CallingConvention.StdCall)] delegate IntPtr GetBufferSizeDelegate(IntPtr blob);
    [UnmanagedFunctionPointer(CallingConvention.StdCall)] delegate int  MapDelegate(IntPtr resource, uint Subresource, ref D3D12_RANGE pReadRange, out IntPtr ppData);
    [UnmanagedFunctionPointer(CallingConvention.StdCall)] delegate void UnmapDelegate(IntPtr resource, uint Subresource, ref D3D12_RANGE pWrittenRange);
    [UnmanagedFunctionPointer(CallingConvention.StdCall)] delegate ulong GetGPUVirtualAddressDelegate(IntPtr resource);
    [UnmanagedFunctionPointer(CallingConvention.StdCall)] delegate void EnableDebugLayerDelegate(IntPtr debug);

    [UnmanagedFunctionPointer(CallingConvention.StdCall)] delegate void GetCPUDescriptorHandleForHeapStartDelegate(IntPtr pThis, IntPtr pOut);
    [UnmanagedFunctionPointer(CallingConvention.StdCall)] delegate void GetGPUDescriptorHandleForHeapStartDelegate(IntPtr pThis, IntPtr pOut);

    #endregion

    #region Member Variables

    static IntPtr device, commandQueue, swapChain, rtvHeap, srvUavHeap, commandAllocator, commandList, fence, fenceEvent;
    static IntPtr graphicsPipelineState, computePipelineState, rootSignature;
    static IntPtr[] renderTargets;
    static IntPtr posBuffer, colBuffer, constantBuffer;
    static ulong fenceValue;
    static uint rtvDescriptorSize, srvUavDescriptorSize;
    static uint vertexCount = 100000;
    static IntPtr constantBufferPtr;
    static HarmonographParams hParams;
    static Random rand = new Random();

    static WndProcDelegate wndProcDelegate;

    #endregion

    static void Log(string msg) { Console.WriteLine("[DEBUG] " + msg); }

    static T GetDelegate<T>(IntPtr ptr, int index) where T : class
    {
        IntPtr vTable = Marshal.ReadIntPtr(ptr);
        IntPtr methodPtr = Marshal.ReadIntPtr(vTable, index * IntPtr.Size);
        return Marshal.GetDelegateForFunctionPointer(methodPtr, typeof(T)) as T;
    }

    static IntPtr GetCPUHandle(IntPtr heap, int offsetIndex = 0, uint descriptorSize = 0)
    {
        IntPtr vTable = Marshal.ReadIntPtr(heap);
        IntPtr methodPtr = Marshal.ReadIntPtr(vTable, 9 * IntPtr.Size);
        IntPtr pOut = Marshal.AllocHGlobal(8);
        try
        {
            var func = Marshal.GetDelegateForFunctionPointer(methodPtr, typeof(GetCPUDescriptorHandleForHeapStartDelegate)) as GetCPUDescriptorHandleForHeapStartDelegate;
            func(heap, pOut);
            IntPtr handle = Marshal.ReadIntPtr(pOut);
            return new IntPtr(handle.ToInt64() + (long)offsetIndex * descriptorSize);
        }
        finally { Marshal.FreeHGlobal(pOut); }
    }

    static ulong GetGPUHandle(IntPtr heap, int offsetIndex = 0, uint descriptorSize = 0)
    {
        IntPtr vTable = Marshal.ReadIntPtr(heap);
        IntPtr methodPtr = Marshal.ReadIntPtr(vTable, 10 * IntPtr.Size);
        IntPtr pOut = Marshal.AllocHGlobal(8);
        try
        {
            var func = Marshal.GetDelegateForFunctionPointer(methodPtr, typeof(GetGPUDescriptorHandleForHeapStartDelegate)) as GetGPUDescriptorHandleForHeapStartDelegate;
            func(heap, pOut);
            ulong handle = (ulong)Marshal.ReadInt64(pOut);
            return handle + (ulong)offsetIndex * descriptorSize;
        }
        finally { Marshal.FreeHGlobal(pOut); }
    }

    static void CheckResult(int result, string msg)
    {
        if (result < 0) throw new Exception(msg + " failed. HRESULT: 0x" + result.ToString("X"));
        Log(msg + " OK");
    }

    static IntPtr CompileShaderFromFile(string filename, string entryPoint, string target)
    {
        string source = File.ReadAllText(filename);
        byte[] sourceBytes = Encoding.UTF8.GetBytes(source);
        IntPtr pSource = Marshal.AllocHGlobal(sourceBytes.Length);
        Marshal.Copy(sourceBytes, 0, pSource, sourceBytes.Length);

        IntPtr ppCode, ppErrors;
        int hr = D3DCompile(pSource, new IntPtr(sourceBytes.Length), filename, IntPtr.Zero, IntPtr.Zero,
                            entryPoint, target, 0, 0, out ppCode, out ppErrors);

        Marshal.FreeHGlobal(pSource);

        if (hr < 0)
        {
            string errorMsg = "Unknown error";
            if (ppErrors != IntPtr.Zero)
            {
                var getPtr = GetDelegate<GetBufferPointerDelegate>(ppErrors, 3);
                var getSize = GetDelegate<GetBufferSizeDelegate>(ppErrors, 4);
                IntPtr errPtr = getPtr(ppErrors);
                int errSize = (int)getSize(ppErrors).ToInt64();
                byte[] errBytes = new byte[errSize];
                Marshal.Copy(errPtr, errBytes, 0, errSize);
                errorMsg = Encoding.UTF8.GetString(errBytes);
                Marshal.Release(ppErrors);
            }
            throw new Exception("Shader compile failed (" + entryPoint + "): " + errorMsg);
        }
        return ppCode;
    }

    public static void EnableDebugLayer()
    {
        Guid debugGuid = new Guid("344488b7-6846-474b-b989-f027448245e0");
        IntPtr debugInterface;
        if (D3D12GetDebugInterface(ref debugGuid, out debugInterface) >= 0)
        {
            GetDelegate<EnableDebugLayerDelegate>(debugInterface, 3)(debugInterface);
            Marshal.Release(debugInterface);
        }
    }

    public static void LoadPipeline(IntPtr hwnd)
    {
        EnableDebugLayer();

        Guid factoryGuid = new Guid("1bc6ea02-ef36-464f-bf0c-21ca39e5168a");
        IntPtr factory;
        CheckResult(CreateDXGIFactory1(ref factoryGuid, out factory), "CreateDXGIFactory1");

        Guid deviceGuid = new Guid("189819f1-1db6-4b57-be54-1821339b85f7");
        CheckResult(D3D12CreateDevice(IntPtr.Zero, 0xb000, ref deviceGuid, out device), "D3D12CreateDevice");

        var queueDesc = new D3D12_COMMAND_QUEUE_DESC();
        var createQueue = GetDelegate<CreateCommandQueueDelegate>(device, 8);
        Guid queueIID = new Guid("0ec870a6-5d7e-4c22-8cfc-5baae07616ed");
        CheckResult(createQueue(device, ref queueDesc, ref queueIID, out commandQueue), "CreateCommandQueue");

        var swapChainDesc = new DXGI_SWAP_CHAIN_DESC1
        {
            Width = 800, Height = 600, Format = 28, BufferUsage = 0x20,
            BufferCount = 2, SwapEffect = 4, SampleDesc = new DXGI_SAMPLE_DESC { Count = 1 }, Flags = 0
        };
        var createSwapChain = GetDelegate<CreateSwapChainForHwndDelegate>(factory, 15);
        IntPtr tempSwapChain;
        CheckResult(createSwapChain(factory, commandQueue, hwnd, ref swapChainDesc, IntPtr.Zero, IntPtr.Zero, out tempSwapChain), "CreateSwapChainForHwnd");
        Guid sc3Guid = new Guid("94d99bdb-f1f8-4ab0-b236-7da0170edab1");
        Marshal.QueryInterface(tempSwapChain, ref sc3Guid, out swapChain);

        var rtvHeapDesc = new D3D12_DESCRIPTOR_HEAP_DESC { Type = 2, NumDescriptors = 2 };
        var createHeap = GetDelegate<CreateDescriptorHeapDelegate>(device, 14);
        Guid heapGuid = new Guid("8efb471d-616c-4f49-90f7-127bb763fa51");
        CheckResult(createHeap(device, ref rtvHeapDesc, ref heapGuid, out rtvHeap), "CreateDescriptorHeap(RTV)");

        var srvHeapDesc = new D3D12_DESCRIPTOR_HEAP_DESC { Type = 0, NumDescriptors = 5, Flags = 1 };
        CheckResult(createHeap(device, ref srvHeapDesc, ref heapGuid, out srvUavHeap), "CreateDescriptorHeap(SRV/UAV)");

        var getInc = GetDelegate<GetDescriptorHandleIncrementSizeDelegate>(device, 15);
        rtvDescriptorSize = getInc(device, 2);
        srvUavDescriptorSize = getInc(device, 0);

        renderTargets = new IntPtr[2];
        var createRTV = GetDelegate<CreateRenderTargetViewDelegate>(device, 20);
        var getBuffer = GetDelegate<GetBufferDelegate>(swapChain, 9);
        Guid resGuid = new Guid("696442be-a72e-4059-bc79-5b5c98040fad");

        for (uint i = 0; i < 2; i++)
        {
            getBuffer(swapChain, i, ref resGuid, out renderTargets[i]);
            var handle = new D3D12_CPU_DESCRIPTOR_HANDLE { ptr = GetCPUHandle(rtvHeap, (int)i, rtvDescriptorSize) };
            createRTV(device, renderTargets[i], IntPtr.Zero, handle);
        }

        var createAlloc = GetDelegate<CreateCommandAllocatorDelegate>(device, 9);
        Guid allocGuid = new Guid("6102dee4-af59-4b09-b999-b44d73f09b24");
        CheckResult(createAlloc(device, 0, ref allocGuid, out commandAllocator), "CreateCommandAllocator");

        Marshal.Release(factory);
    }

    public static void LoadAssets()
    {
        Log("=== LoadAssets START ===");

        // Descriptor Ranges (APPEND = 0xFFFFFFFF)
        var rangeUAV = new D3D12_DESCRIPTOR_RANGE { RangeType = 1, NumDescriptors = 2, BaseShaderRegister = 0, RegisterSpace = 0, OffsetInDescriptorsFromTableStart = 0xFFFFFFFF };
        var rangeSRV = new D3D12_DESCRIPTOR_RANGE { RangeType = 0, NumDescriptors = 2, BaseShaderRegister = 0, RegisterSpace = 0, OffsetInDescriptorsFromTableStart = 0xFFFFFFFF };
        var rangeCBV = new D3D12_DESCRIPTOR_RANGE { RangeType = 2, NumDescriptors = 1, BaseShaderRegister = 0, RegisterSpace = 0, OffsetInDescriptorsFromTableStart = 0xFFFFFFFF };

        int rangeSize = Marshal.SizeOf(typeof(D3D12_DESCRIPTOR_RANGE));
        IntPtr pRangeUAV = Marshal.AllocHGlobal(rangeSize); Marshal.StructureToPtr(rangeUAV, pRangeUAV, false);
        IntPtr pRangeSRV = Marshal.AllocHGlobal(rangeSize); Marshal.StructureToPtr(rangeSRV, pRangeSRV, false);
        IntPtr pRangeCBV = Marshal.AllocHGlobal(rangeSize); Marshal.StructureToPtr(rangeCBV, pRangeCBV, false);

        var paramsArr = new D3D12_ROOT_PARAMETER[3];
        paramsArr[0].ParameterType = 0; paramsArr[0].DescriptorTable.NumDescriptorRanges = 1; paramsArr[0].DescriptorTable.pDescriptorRanges = pRangeUAV; paramsArr[0].ShaderVisibility = 0;
        paramsArr[1].ParameterType = 0; paramsArr[1].DescriptorTable.NumDescriptorRanges = 1; paramsArr[1].DescriptorTable.pDescriptorRanges = pRangeSRV; paramsArr[1].ShaderVisibility = 0;
        paramsArr[2].ParameterType = 0; paramsArr[2].DescriptorTable.NumDescriptorRanges = 1; paramsArr[2].DescriptorTable.pDescriptorRanges = pRangeCBV; paramsArr[2].ShaderVisibility = 0;

        int paramSize = 32; // Explicit(Size=32)
        IntPtr pParams = Marshal.AllocHGlobal(paramSize * 3);
        for (int i = 0; i < 3; i++)
            Marshal.StructureToPtr(paramsArr[i], new IntPtr(pParams.ToInt64() + i * paramSize), false);

        // ALLOW_INPUT_ASSEMBLER_INPUT_LAYOUT = 0x1
        var rootDesc = new D3D12_ROOT_SIGNATURE_DESC { NumParameters = 3, pParameters = pParams, Flags = 0x1 };
        IntPtr sigBlob, errBlob;
        CheckResult(D3D12SerializeRootSignature(ref rootDesc, 1, out sigBlob, out errBlob), "D3D12SerializeRootSignature");

        var createRootSig = GetDelegate<CreateRootSignatureDelegate>(device, 16);
        Guid rsGuid = new Guid("c54a6b66-72df-4ee8-8be5-a946a1429214");
        var getBlobPtr = GetDelegate<GetBufferPointerDelegate>(sigBlob, 3);
        var getBlobSize = GetDelegate<GetBufferSizeDelegate>(sigBlob, 4);
        CheckResult(createRootSig(device, 0, getBlobPtr(sigBlob), getBlobSize(sigBlob), ref rsGuid, out rootSignature), "CreateRootSignature");

        Log("Compiling hello.hlsl...");
        string shaderFile = "hello.hlsl";
        IntPtr csBlob = CompileShaderFromFile(shaderFile, "CSMain", "cs_5_0");
        IntPtr vsBlob = CompileShaderFromFile(shaderFile, "VSMain", "vs_5_0");
        IntPtr psBlob = CompileShaderFromFile(shaderFile, "PSMain", "ps_5_0");

        var csPsoDesc = new D3D12_COMPUTE_PIPELINE_STATE_DESC
        {
            pRootSignature = rootSignature,
            CS = new D3D12_SHADER_BYTECODE
            {
                pShaderBytecode = GetDelegate<GetBufferPointerDelegate>(csBlob, 3)(csBlob),
                BytecodeLength = GetDelegate<GetBufferSizeDelegate>(csBlob, 4)(csBlob)
            }
        };
        var createComputePSO = GetDelegate<CreateComputePipelineStateDelegate>(device, 11);
        Guid psoGuid = new Guid("765a30f3-f624-4c6f-a828-ace948622445");
        CheckResult(createComputePSO(device, ref csPsoDesc, ref psoGuid, out computePipelineState), "CreateComputePSO");

        var gfxPsoDesc = new D3D12_GRAPHICS_PIPELINE_STATE_DESC
        {
            pRootSignature = rootSignature,
            VS = new D3D12_SHADER_BYTECODE
            {
                pShaderBytecode = GetDelegate<GetBufferPointerDelegate>(vsBlob, 3)(vsBlob),
                BytecodeLength = GetDelegate<GetBufferSizeDelegate>(vsBlob, 4)(vsBlob)
            },
            PS = new D3D12_SHADER_BYTECODE
            {
                pShaderBytecode = GetDelegate<GetBufferPointerDelegate>(psBlob, 3)(psBlob),
                BytecodeLength = GetDelegate<GetBufferSizeDelegate>(psBlob, 4)(psBlob)
            },
            BlendState = new D3D12_BLEND_DESC { RenderTarget = new D3D12_RENDER_TARGET_BLEND_DESC[8] },
            RasterizerState = new D3D12_RASTERIZER_DESC { FillMode = 3, CullMode = 1, DepthClipEnable = 1 },
            DepthStencilState = new D3D12_DEPTH_STENCIL_DESC { DepthEnable = 0 },
            PrimitiveTopologyType = 2,
            NumRenderTargets = 1,
            RTVFormats = new uint[] { 28, 0, 0, 0, 0, 0, 0, 0 },
            SampleDesc = new DXGI_SAMPLE_DESC { Count = 1 },
            SampleMask = 0xFFFFFFFF
        };
        gfxPsoDesc.BlendState.RenderTarget[0].RenderTargetWriteMask = 0x0F;

        var createGraphicsPSO = GetDelegate<CreateGraphicsPipelineStateDelegate>(device, 10);
        CheckResult(createGraphicsPSO(device, ref gfxPsoDesc, ref psoGuid, out graphicsPipelineState), "CreateGraphicsPSO");

        Log("Creating buffers...");
        ulong bufferSize = (ulong)(vertexCount * 16);
        var heapDefault = new D3D12_HEAP_PROPERTIES { Type = 1, CreationNodeMask = 1, VisibleNodeMask = 1 };
        var bufDesc = new D3D12_RESOURCE_DESC
        {
            Dimension = 1, Width = bufferSize, Height = 1, DepthOrArraySize = 1, MipLevels = 1,
            Format = 0, Layout = 1, Flags = 4, SampleDesc = new DXGI_SAMPLE_DESC { Count = 1 }
        };
        var createResource = GetDelegate<CreateCommittedResourceDelegate>(device, 27);
        Guid resGuid = new Guid("696442be-a72e-4059-bc79-5b5c98040fad");

        CheckResult(createResource(device, ref heapDefault, 0, ref bufDesc, 0, IntPtr.Zero, ref resGuid, out posBuffer), "CreatePosBuffer");
        CheckResult(createResource(device, ref heapDefault, 0, ref bufDesc, 0, IntPtr.Zero, ref resGuid, out colBuffer), "CreateColBuffer");

        var heapUpload = new D3D12_HEAP_PROPERTIES { Type = 2, CreationNodeMask = 1, VisibleNodeMask = 1 };
        var cbDesc = new D3D12_RESOURCE_DESC
        {
            Dimension = 1, Width = 256, Height = 1, DepthOrArraySize = 1, MipLevels = 1,
            Format = 0, Layout = 1, Flags = 0, SampleDesc = new DXGI_SAMPLE_DESC { Count = 1 }
        };
        CheckResult(createResource(device, ref heapUpload, 0, ref cbDesc, 1, IntPtr.Zero, ref resGuid, out constantBuffer), "CreateConstantBuffer");

        var map = GetDelegate<MapDelegate>(constantBuffer, 8);
        D3D12_RANGE readRange = new D3D12_RANGE();
        CheckResult(map(constantBuffer, 0, ref readRange, out constantBufferPtr), "Map(ConstantBuffer)");

        Log("Creating views...");
        var createUAV = GetDelegate<CreateUnorderedAccessViewDelegate>(device, 19);
        var uavDesc = new D3D12_UNORDERED_ACCESS_VIEW_DESC { Format = 0, ViewDimension = 1, Buffer_NumElements = vertexCount, Buffer_StructureByteStride = 16 };

        createUAV(device, posBuffer, IntPtr.Zero, ref uavDesc, new D3D12_CPU_DESCRIPTOR_HANDLE { ptr = GetCPUHandle(srvUavHeap, 0, srvUavDescriptorSize) });
        createUAV(device, colBuffer, IntPtr.Zero, ref uavDesc, new D3D12_CPU_DESCRIPTOR_HANDLE { ptr = GetCPUHandle(srvUavHeap, 1, srvUavDescriptorSize) });

        var createSRV = GetDelegate<CreateShaderResourceViewDelegate>(device, 18);
        var srvDesc = new D3D12_SHADER_RESOURCE_VIEW_DESC { Format = 0, ViewDimension = 1, Shader4ComponentMapping = 5768, Buffer_NumElements = vertexCount, Buffer_StructureByteStride = 16 };

        createSRV(device, posBuffer, ref srvDesc, new D3D12_CPU_DESCRIPTOR_HANDLE { ptr = GetCPUHandle(srvUavHeap, 2, srvUavDescriptorSize) });
        createSRV(device, colBuffer, ref srvDesc, new D3D12_CPU_DESCRIPTOR_HANDLE { ptr = GetCPUHandle(srvUavHeap, 3, srvUavDescriptorSize) });

        var getGpuVA = GetDelegate<GetGPUVirtualAddressDelegate>(constantBuffer, 11);
        var cbvDesc = new D3D12_CONSTANT_BUFFER_VIEW_DESC { BufferLocation = getGpuVA(constantBuffer), SizeInBytes = 256 };
        var createCBV = GetDelegate<CreateConstantBufferViewDelegate>(device, 17);
        createCBV(device, ref cbvDesc, new D3D12_CPU_DESCRIPTOR_HANDLE { ptr = GetCPUHandle(srvUavHeap, 4, srvUavDescriptorSize) });

        var createCmdList = GetDelegate<CreateCommandListDelegate>(device, 12);
        Guid listGuid = new Guid("5b160d0f-ac1b-4185-8ba8-b3ae42a5a455");
        CheckResult(createCmdList(device, 0, 0, commandAllocator, IntPtr.Zero, ref listGuid, out commandList), "CreateCommandList");
        GetDelegate<CloseDelegate>(commandList, 9)(commandList);

        var createFence = GetDelegate<CreateFenceDelegate>(device, 36);
        Guid fenceGuid = new Guid("0a753dcf-c4d8-4b91-adf6-be5a60d95a76");
        CheckResult(createFence(device, 0, 0, ref fenceGuid, out fence), "CreateFence");
        fenceEvent = CreateEvent(IntPtr.Zero, false, false, null);
        fenceValue = 1;

        hParams.A1 = 50.0f; hParams.f1 = 2.0f; hParams.p1 = 1.0f / 16.0f; hParams.d1 = 0.02f;
        hParams.A2 = 50.0f; hParams.f2 = 2.0f; hParams.p2 = 3.0f / 2.0f;  hParams.d2 = 0.0315f;
        hParams.A3 = 50.0f; hParams.f3 = 2.0f; hParams.p3 = 13.0f / 15.0f;hParams.d3 = 0.02f;
        hParams.A4 = 50.0f; hParams.f4 = 2.0f; hParams.p4 = 1.0f;         hParams.d4 = 0.02f;

        hParams.max_num = vertexCount;
        hParams.resX = 800; hParams.resY = 600;

        Log("=== LoadAssets END ===");
    }

    public static void Render()
    {
        hParams.f1 = (hParams.f1 + (float)rand.NextDouble() / 200f) % 10f;
        hParams.f2 = (hParams.f2 + (float)rand.NextDouble() / 200f) % 10f;
        hParams.p1 += (6.2831853f * 0.5f / 360f);

        Marshal.StructureToPtr(hParams, constantBufferPtr, false);

        var resetAlloc = GetDelegate<ResetAllocDelegate>(commandAllocator, 8);
        CheckResult(resetAlloc(commandAllocator), "ResetAllocator");

        var resetList = GetDelegate<ResetDelegate>(commandList, 10);
        CheckResult(resetList(commandList, commandAllocator, IntPtr.Zero), "ResetCommandList");

        var setHeaps = GetDelegate<SetDescriptorHeapsDelegate>(commandList, 28);
        setHeaps(commandList, 1, new IntPtr[] { srvUavHeap });

        // --- Compute Pass ---
        var setComputeRootSig = GetDelegate<SetComputeRootSignatureDelegate>(commandList, 29);
        setComputeRootSig(commandList, rootSignature);

        var setPSO = GetDelegate<SetPipelineStateDelegate>(commandList, 25);
        setPSO(commandList, computePipelineState);

        var setComputeTable = GetDelegate<SetComputeRootDescriptorTableDelegate>(commandList, 31);
        setComputeTable(commandList, 0, new D3D12_GPU_DESCRIPTOR_HANDLE { ptr = GetGPUHandle(srvUavHeap, 0, srvUavDescriptorSize) });
        setComputeTable(commandList, 2, new D3D12_GPU_DESCRIPTOR_HANDLE { ptr = GetGPUHandle(srvUavHeap, 4, srvUavDescriptorSize) });

        var dispatch = GetDelegate<DispatchDelegate>(commandList, 14);
        dispatch(commandList, (uint)((vertexCount + 63) / 64), 1, 1);

        var barrier = GetDelegate<ResourceBarrierDelegate>(commandList, 26);
        // UAV -> SRV(NonPixel+Pixel = 0xC0)
        var b1 = new D3D12_RESOURCE_BARRIER { Type = 0, pResource = posBuffer, Subresource = 0xFFFFFFFF, StateBefore = 0x8, StateAfter = 0xC0 };
        barrier(commandList, 1, ref b1);
        var b2 = new D3D12_RESOURCE_BARRIER { Type = 0, pResource = colBuffer, Subresource = 0xFFFFFFFF, StateBefore = 0x8, StateAfter = 0xC0 };
        barrier(commandList, 1, ref b2);

        // --- Graphics Pass ---
        var setGraphicsRootSig = GetDelegate<SetGraphicsRootSignatureDelegate>(commandList, 30);
        setGraphicsRootSig(commandList, rootSignature);
        setPSO(commandList, graphicsPipelineState);

        var viewport = new D3D12_VIEWPORT { Width = 800, Height = 600, MinDepth = 0, MaxDepth = 1.0f };
        var setViewport = GetDelegate<RSSetViewportsDelegate>(commandList, 21);
        setViewport(commandList, 1, ref viewport);

        var scissor = new D3D12_RECT { left = 0, top = 0, right = 800, bottom = 600 };
        var setScissor = GetDelegate<RSSetScissorRectsDelegate>(commandList, 22);
        setScissor(commandList, 1, ref scissor);

        var getBackBufferIdx = GetDelegate<GetCurrentBackBufferIndexDelegate>(swapChain, 36);
        uint frameIdx = getBackBufferIdx(swapChain);

        var barrierRT = new D3D12_RESOURCE_BARRIER { Type = 0, pResource = renderTargets[frameIdx], Subresource = 0xFFFFFFFF, StateBefore = 0, StateAfter = 4 };
        barrier(commandList, 1, ref barrierRT);

        var omSetRT = GetDelegate<OMSetRenderTargetsDelegate>(commandList, 46);
        var rtvHandle = new D3D12_CPU_DESCRIPTOR_HANDLE { ptr = GetCPUHandle(rtvHeap, (int)frameIdx, rtvDescriptorSize) };
        omSetRT(commandList, 1, ref rtvHandle, false, IntPtr.Zero);

        var clearRT = GetDelegate<ClearRenderTargetViewDelegate>(commandList, 48);
        clearRT(commandList, rtvHandle, new float[] { 0.05f, 0.05f, 0.1f, 1.0f }, 0, IntPtr.Zero);

        var setGfxTable = GetDelegate<SetGraphicsRootDescriptorTableDelegate>(commandList, 32);
        setGfxTable(commandList, 1, new D3D12_GPU_DESCRIPTOR_HANDLE { ptr = GetGPUHandle(srvUavHeap, 2, srvUavDescriptorSize) });
        setGfxTable(commandList, 2, new D3D12_GPU_DESCRIPTOR_HANDLE { ptr = GetGPUHandle(srvUavHeap, 4, srvUavDescriptorSize) });

        var iaSetTopo = GetDelegate<IASetPrimitiveTopologyDelegate>(commandList, 20);
        iaSetTopo(commandList, 3); // LINESTRIP

        var draw = GetDelegate<DrawInstancedDelegate>(commandList, 12);
        draw(commandList, vertexCount, 1, 0, 0);

        barrierRT.StateBefore = 4; barrierRT.StateAfter = 0;
        barrier(commandList, 1, ref barrierRT);

        // SRV -> UAV
        b1.StateBefore = 0xC0; b1.StateAfter = 0x8; barrier(commandList, 1, ref b1);
        b2.StateBefore = 0xC0; b2.StateAfter = 0x8; barrier(commandList, 1, ref b2);

        CheckResult(GetDelegate<CloseDelegate>(commandList, 9)(commandList), "CloseCommandList");
        GetDelegate<ExecuteCommandListsDelegate>(commandQueue, 10)(commandQueue, 1, new IntPtr[] { commandList });
        GetDelegate<PresentDelegate>(swapChain, 8)(swapChain, 1, 0);

        // Fence
        var signal = GetDelegate<SignalDelegate>(commandQueue, 14);
        ulong fv = fenceValue++;
        signal(commandQueue, fence, fv);

        var getCompleted = GetDelegate<GetCompletedValueDelegate>(fence, 8);
        if (getCompleted(fence) < fv)
        {
            var setEvent = GetDelegate<SetEventOnCompletionDelegate>(fence, 9);
            setEvent(fence, fv, fenceEvent);
            WaitForSingleObject(fenceEvent, INFINITE);
        }
    }

    public static void Main()
    {
        Log("=== Main START ===");

        IntPtr hInstance = GetModuleHandle(null);

        wndProcDelegate = new WndProcDelegate(WndProc);
        string className = "D3D12Harmonograph_" + Guid.NewGuid().ToString("N");

        var wndClass = new WNDCLASSEX
        {
            cbSize = (uint)Marshal.SizeOf(typeof(WNDCLASSEX)),
            style = 0x20, // CS_OWNDC
            lpfnWndProc = Marshal.GetFunctionPointerForDelegate(wndProcDelegate),
            hInstance = hInstance,
            lpszClassName = className,
            hCursor = LoadCursor(IntPtr.Zero, IDC_ARROW),
        };

        RegisterClassEx(ref wndClass);

        IntPtr hwnd = CreateWindowEx(
            0,
            className,
            "PowerShell DX12 Compute Harmonograph",
            WS_OVERLAPPEDWINDOW | WS_VISIBLE,
            100, 100, 800, 600,
            IntPtr.Zero, IntPtr.Zero, hInstance, IntPtr.Zero
        );

        LoadPipeline(hwnd);
        LoadAssets();

        Log("=== Entering message loop ===");
        MSG msg;
        while (true)
        {
            if (PeekMessage(out msg, IntPtr.Zero, 0, 0, PM_REMOVE))
            {
                if (msg.message == WM_QUIT) break;
                TranslateMessage(ref msg);
                DispatchMessage(ref msg);
            }
            else
            {
                Render();
            }
        }
    }

    static IntPtr WndProc(IntPtr hWnd, uint uMsg, IntPtr wParam, IntPtr lParam)
    {
        if (uMsg == WM_DESTROY) { PostQuitMessage(0); return IntPtr.Zero; }
        return DefWindowProc(hWnd, uMsg, wParam, lParam);
    }
}
"@

Add-Type -TypeDefinition $source -Language CSharp
[Harmonograph]::Main()
