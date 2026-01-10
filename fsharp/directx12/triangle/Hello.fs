// F# DirectX 12 Triangle Sample - No external libraries
// Based on the C# sample, using P/Invoke and COM interop

open System
open System.Runtime.InteropServices
open System.Text

// ============================================================================
// Win32 Constants
// ============================================================================
module Win32Constants =
    let WS_OVERLAPPED       = 0x00000000u
    let WS_CAPTION          = 0x00C00000u
    let WS_SYSMENU          = 0x00080000u
    let WS_THICKFRAME       = 0x00040000u
    let WS_MINIMIZEBOX      = 0x00020000u
    let WS_MAXIMIZEBOX      = 0x00010000u
    let WS_OVERLAPPEDWINDOW = WS_OVERLAPPED ||| WS_CAPTION ||| WS_SYSMENU ||| WS_THICKFRAME ||| WS_MINIMIZEBOX ||| WS_MAXIMIZEBOX
    let WS_VISIBLE          = 0x10000000u

    let CS_OWNDC            = 0x0020u

    let WM_CREATE           = 0x0001u
    let WM_DESTROY          = 0x0002u
    let WM_PAINT            = 0x000Fu
    let WM_CLOSE            = 0x0010u
    let WM_QUIT             = 0x0012u

    let PM_REMOVE           = 0x0001u

    let IDC_ARROW           = 32512

    let INFINITE            = 0xFFFFFFFFu

// ============================================================================
// DXGI Constants
// ============================================================================
module DXGIConstants =
    let DXGI_FORMAT_UNKNOWN             = 0u
    let DXGI_FORMAT_R32G32B32_FLOAT     = 6u
    let DXGI_FORMAT_R32G32B32A32_FLOAT  = 2u
    let DXGI_FORMAT_R8G8B8A8_UNORM      = 28u

    let DXGI_USAGE_RENDER_TARGET_OUTPUT = 0x20u

    let DXGI_SWAP_EFFECT_FLIP_DISCARD   = 4u

    let DXGI_SWAP_CHAIN_FLAG_ALLOW_MODE_SWITCH           = 2u
    let DXGI_SWAP_CHAIN_FLAG_FRAME_LATENCY_WAITABLE_OBJECT = 64u

// ============================================================================
// D3D12 Constants
// ============================================================================
module D3D12Constants =
    let D3D_FEATURE_LEVEL_11_0          = 0xb000u
    let D3D_ROOT_SIGNATURE_VERSION_1    = 0x1u

    let D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES = 0xffffffffu

// ============================================================================
// Win32 Structures
// ============================================================================
[<Struct; StructLayout(LayoutKind.Sequential)>]
type POINT =
    val mutable X: int
    val mutable Y: int

[<Struct; StructLayout(LayoutKind.Sequential)>]
type MSG =
    val mutable hwnd: IntPtr
    val mutable message: uint32
    val mutable wParam: IntPtr
    val mutable lParam: IntPtr
    val mutable time: uint32
    val mutable pt: POINT

[<Struct; StructLayout(LayoutKind.Sequential)>]
type RECT =
    val mutable Left: int
    val mutable Top: int
    val mutable Right: int
    val mutable Bottom: int

[<Struct; StructLayout(LayoutKind.Sequential)>]
type PAINTSTRUCT =
    val mutable hdc: IntPtr
    val mutable fErase: int
    val mutable rcPaint: RECT
    val mutable fRestore: int
    val mutable fIncUpdate: int
    [<MarshalAs(UnmanagedType.ByValArray, SizeConst = 32)>]
    val mutable rgbReserved: byte[]

// ============================================================================
// DXGI Structures
// ============================================================================
[<Struct; StructLayout(LayoutKind.Sequential)>]
type DXGI_SAMPLE_DESC =
    val mutable Count: uint32
    val mutable Quality: uint32

[<Struct; StructLayout(LayoutKind.Sequential)>]
type DXGI_SWAP_CHAIN_DESC1 =
    val mutable Width: uint32
    val mutable Height: uint32
    val mutable Format: uint32
    val mutable Stereo: bool
    val mutable SampleDesc: DXGI_SAMPLE_DESC
    val mutable BufferUsage: uint32
    val mutable BufferCount: uint32
    val mutable Scaling: int
    val mutable SwapEffect: uint32
    val mutable AlphaMode: int
    val mutable Flags: uint32

// ============================================================================
// D3D12 Structures
// ============================================================================
[<Struct; StructLayout(LayoutKind.Sequential)>]
type D3D12_COMMAND_QUEUE_DESC =
    val mutable Type: int
    val mutable Priority: int
    val mutable Flags: int
    val mutable NodeMask: uint32

[<Struct; StructLayout(LayoutKind.Sequential)>]
type D3D12_DESCRIPTOR_HEAP_DESC =
    val mutable Type: int
    val mutable NumDescriptors: uint32
    val mutable Flags: int
    val mutable NodeMask: uint32

[<Struct; StructLayout(LayoutKind.Sequential)>]
type D3D12_CPU_DESCRIPTOR_HANDLE =
    val mutable ptr: IntPtr

[<Struct; StructLayout(LayoutKind.Sequential)>]
type D3D12_GPU_DESCRIPTOR_HANDLE =
    val mutable ptr: uint64

[<Struct; StructLayout(LayoutKind.Sequential)>]
type D3D12_HEAP_PROPERTIES =
    val mutable Type: int
    val mutable CPUPageProperty: int
    val mutable MemoryPoolPreference: int
    val mutable CreationNodeMask: uint32
    val mutable VisibleNodeMask: uint32

[<Struct; StructLayout(LayoutKind.Sequential)>]
type D3D12_RESOURCE_DESC =
    val mutable Dimension: int
    val mutable Alignment: uint64
    val mutable Width: uint64
    val mutable Height: uint32
    val mutable DepthOrArraySize: uint16
    val mutable MipLevels: uint16
    val mutable Format: uint32
    val mutable SampleDesc: DXGI_SAMPLE_DESC
    val mutable Layout: int
    val mutable Flags: int

[<Struct; StructLayout(LayoutKind.Sequential)>]
type D3D12_RANGE =
    val mutable Begin: uint64
    val mutable End: uint64

[<Struct; StructLayout(LayoutKind.Sequential)>]
type D3D12_VERTEX_BUFFER_VIEW =
    val mutable BufferLocation: uint64
    val mutable SizeInBytes: uint32
    val mutable StrideInBytes: uint32

[<Struct; StructLayout(LayoutKind.Sequential)>]
type D3D12_ROOT_SIGNATURE_DESC =
    val mutable NumParameters: uint32
    val mutable pParameters: IntPtr
    val mutable NumStaticSamplers: uint32
    val mutable pStaticSamplers: IntPtr
    val mutable Flags: int

[<Struct; StructLayout(LayoutKind.Sequential)>]
type D3D12_SHADER_BYTECODE =
    val mutable pShaderBytecode: IntPtr
    val mutable BytecodeLength: IntPtr

[<Struct; StructLayout(LayoutKind.Sequential)>]
type D3D12_INPUT_ELEMENT_DESC =
    val mutable SemanticName: IntPtr
    val mutable SemanticIndex: uint32
    val mutable Format: uint32
    val mutable InputSlot: uint32
    val mutable AlignedByteOffset: uint32
    val mutable InputSlotClass: int
    val mutable InstanceDataStepRate: uint32

[<Struct; StructLayout(LayoutKind.Sequential)>]
type D3D12_INPUT_LAYOUT_DESC =
    val mutable pInputElementDescs: IntPtr
    val mutable NumElements: uint32

[<Struct; StructLayout(LayoutKind.Sequential)>]
type D3D12_RENDER_TARGET_BLEND_DESC =
    val mutable BlendEnable: bool
    val mutable LogicOpEnable: bool
    val mutable SrcBlend: int
    val mutable DestBlend: int
    val mutable BlendOp: int
    val mutable SrcBlendAlpha: int
    val mutable DestBlendAlpha: int
    val mutable BlendOpAlpha: int
    val mutable LogicOp: int
    val mutable RenderTargetWriteMask: byte

[<Struct; StructLayout(LayoutKind.Sequential)>]
type D3D12_BLEND_DESC =
    val mutable AlphaToCoverageEnable: bool
    val mutable IndependentBlendEnable: bool
    [<MarshalAs(UnmanagedType.ByValArray, SizeConst = 8)>]
    val mutable RenderTarget: D3D12_RENDER_TARGET_BLEND_DESC[]

[<Struct; StructLayout(LayoutKind.Sequential)>]
type D3D12_RASTERIZER_DESC =
    val mutable FillMode: int
    val mutable CullMode: int
    val mutable FrontCounterClockwise: bool
    val mutable DepthBias: int
    val mutable DepthBiasClamp: float32
    val mutable SlopeScaledDepthBias: float32
    val mutable DepthClipEnable: bool
    val mutable MultisampleEnable: bool
    val mutable AntialiasedLineEnable: bool
    val mutable ForcedSampleCount: uint32
    val mutable ConservativeRaster: int

[<Struct; StructLayout(LayoutKind.Sequential)>]
type D3D12_DEPTH_STENCILOP_DESC =
    val mutable StencilFailOp: int
    val mutable StencilDepthFailOp: int
    val mutable StencilPassOp: int
    val mutable StencilFunc: int

[<Struct; StructLayout(LayoutKind.Sequential)>]
type D3D12_DEPTH_STENCIL_DESC =
    val mutable DepthEnable: bool
    val mutable DepthWriteMask: int
    val mutable DepthFunc: int
    val mutable StencilEnable: bool
    val mutable StencilReadMask: byte
    val mutable StencilWriteMask: byte
    val mutable FrontFace: D3D12_DEPTH_STENCILOP_DESC
    val mutable BackFace: D3D12_DEPTH_STENCILOP_DESC

[<Struct; StructLayout(LayoutKind.Sequential)>]
type D3D12_STREAM_OUTPUT_DESC =
    val mutable pSODeclaration: IntPtr
    val mutable NumEntries: uint32
    val mutable pBufferStrides: IntPtr
    val mutable NumStrides: uint32
    val mutable RasterizedStream: uint32

[<Struct; StructLayout(LayoutKind.Sequential)>]
type D3D12_CACHED_PIPELINE_STATE =
    val mutable pCachedBlob: IntPtr
    val mutable CachedBlobSizeInBytes: IntPtr

[<Struct; StructLayout(LayoutKind.Sequential)>]
type D3D12_GRAPHICS_PIPELINE_STATE_DESC =
    val mutable pRootSignature: IntPtr
    val mutable VS: D3D12_SHADER_BYTECODE
    val mutable PS: D3D12_SHADER_BYTECODE
    val mutable DS: D3D12_SHADER_BYTECODE
    val mutable HS: D3D12_SHADER_BYTECODE
    val mutable GS: D3D12_SHADER_BYTECODE
    val mutable StreamOutput: D3D12_STREAM_OUTPUT_DESC
    val mutable BlendState: D3D12_BLEND_DESC
    val mutable SampleMask: uint32
    val mutable RasterizerState: D3D12_RASTERIZER_DESC
    val mutable DepthStencilState: D3D12_DEPTH_STENCIL_DESC
    val mutable InputLayout: D3D12_INPUT_LAYOUT_DESC
    val mutable IBStripCutValue: int
    val mutable PrimitiveTopologyType: int
    val mutable NumRenderTargets: uint32
    [<MarshalAs(UnmanagedType.ByValArray, SizeConst = 8)>]
    val mutable RTVFormats: uint32[]
    val mutable DSVFormat: uint32
    val mutable SampleDesc: DXGI_SAMPLE_DESC
    val mutable NodeMask: uint32
    val mutable CachedPSO: D3D12_CACHED_PIPELINE_STATE
    val mutable Flags: int

[<Struct; StructLayout(LayoutKind.Sequential)>]
type D3D12_VIEWPORT =
    val mutable TopLeftX: float32
    val mutable TopLeftY: float32
    val mutable Width: float32
    val mutable Height: float32
    val mutable MinDepth: float32
    val mutable MaxDepth: float32

[<Struct; StructLayout(LayoutKind.Sequential)>]
type D3D12_RECT =
    val mutable left: int
    val mutable top: int
    val mutable right: int
    val mutable bottom: int

[<Struct; StructLayout(LayoutKind.Sequential)>]
type D3D12_RESOURCE_TRANSITION_BARRIER =
    val mutable pResource: IntPtr
    val mutable Subresource: uint32
    val mutable StateBefore: int
    val mutable StateAfter: int

[<Struct; StructLayout(LayoutKind.Sequential)>]
type D3D12_RESOURCE_BARRIER =
    val mutable Type: int
    val mutable Flags: int
    val mutable Transition: D3D12_RESOURCE_TRANSITION_BARRIER

[<Struct; StructLayout(LayoutKind.Sequential)>]
type D3D12_CPU_DESCRIPTOR_HANDLE_ARRAY =
    val mutable ptr: IntPtr

// Vertex structure
[<Struct; StructLayout(LayoutKind.Sequential)>]
type Vertex =
    val mutable X: float32
    val mutable Y: float32
    val mutable Z: float32
    val mutable R: float32
    val mutable G: float32
    val mutable B: float32
    val mutable A: float32

// ============================================================================
// WNDCLASSEX Structure with delegate
// ============================================================================
type WndProcDelegate = delegate of IntPtr * uint32 * IntPtr * IntPtr -> IntPtr

[<Struct; StructLayout(LayoutKind.Sequential, CharSet = CharSet.Auto)>]
type WNDCLASSEX =
    val mutable cbSize: uint32
    val mutable style: uint32
    val mutable lpfnWndProc: WndProcDelegate
    val mutable cbClsExtra: int
    val mutable cbWndExtra: int
    val mutable hInstance: IntPtr
    val mutable hIcon: IntPtr
    val mutable hCursor: IntPtr
    val mutable hbrBackground: IntPtr
    val mutable lpszMenuName: string
    val mutable lpszClassName: string
    val mutable hIconSm: IntPtr

// ============================================================================
// P/Invoke Declarations
// ============================================================================
module NativeMethods =
    [<DllImport("user32.dll", CharSet = CharSet.Auto)>]
    extern bool ShowWindow(IntPtr hWnd, int nCmdShow)

    [<DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)>]
    extern IntPtr LoadCursor(IntPtr hInstance, int lpCursorName)

    [<DllImport("user32.dll", EntryPoint = "RegisterClassEx", CharSet = CharSet.Auto, SetLastError = true)>]
    extern uint16 RegisterClassEx([<In>] WNDCLASSEX& lpwcx)

    [<DllImport("user32.dll", CharSet = CharSet.Auto)>]
    extern IntPtr CreateWindowEx(
        uint32 dwExStyle,
        string lpClassName,
        string lpWindowName,
        uint32 dwStyle,
        int x,
        int y,
        int nWidth,
        int nHeight,
        IntPtr hWndParent,
        IntPtr hMenu,
        IntPtr hInstance,
        IntPtr lpParam)

    [<DllImport("user32.dll", CharSet = CharSet.Auto)>]
    extern bool PeekMessage([<Out>] MSG& lpMsg, IntPtr hWnd, uint32 wMsgFilterMin, uint32 wMsgFilterMax, uint32 wRemoveMsg)

    [<DllImport("user32.dll", CharSet = CharSet.Auto)>]
    extern bool TranslateMessage([<In>] MSG& lpMsg)

    [<DllImport("user32.dll", CharSet = CharSet.Auto)>]
    extern IntPtr DispatchMessage([<In>] MSG& lpMsg)

    [<DllImport("user32.dll", CharSet = CharSet.Auto)>]
    extern unit PostQuitMessage(int nExitCode)

    [<DllImport("user32.dll", CharSet = CharSet.Auto)>]
    extern IntPtr DefWindowProc(IntPtr hWnd, uint32 uMsg, IntPtr wParam, IntPtr lParam)

    [<DllImport("user32.dll", CharSet = CharSet.Auto)>]
    extern IntPtr BeginPaint(IntPtr hWnd, [<Out>] PAINTSTRUCT& lpPaint)

    [<DllImport("user32.dll", CharSet = CharSet.Auto)>]
    extern IntPtr EndPaint(IntPtr hWnd, PAINTSTRUCT& lpPaint)

    [<DllImport("gdi32.dll", CharSet = CharSet.Auto)>]
    extern IntPtr TextOut(IntPtr hdc, int x, int y, string lpString, int nCount)

    [<DllImport("kernel32.dll")>]
    extern IntPtr CreateEvent(IntPtr lpEventAttributes, bool bManualReset, bool bInitialState, string lpName)

    [<DllImport("kernel32.dll", SetLastError = true)>]
    extern uint32 WaitForSingleObject(IntPtr hHandle, uint32 dwMilliseconds)

    [<DllImport("kernel32.dll", SetLastError = true)>]
    extern bool CloseHandle(IntPtr hObject)

    // D3D12 Functions
    [<DllImport("d3d12.dll")>]
    extern int D3D12GetDebugInterface([<In>] Guid& riid, [<Out>] IntPtr& ppvDebug)

    [<DllImport("d3d12.dll")>]
    extern int D3D12CreateDevice(
        IntPtr pAdapter,
        uint32 MinimumFeatureLevel,
        Guid& riid,
        [<Out>] IntPtr& ppDevice)

    [<DllImport("d3d12.dll")>]
    extern int D3D12SerializeRootSignature(
        [<In>] D3D12_ROOT_SIGNATURE_DESC& pRootSignature,
        uint32 Version,
        [<Out>] IntPtr& ppBlob,
        [<Out>] IntPtr& ppErrorBlob)

    // DXGI Functions
    [<DllImport("dxgi.dll")>]
    extern int CreateDXGIFactory2(uint32 Flags, Guid& riid, [<Out>] IntPtr& ppFactory)

    // D3DCompiler Functions
    [<DllImport("d3dcompiler_47.dll", CallingConvention = CallingConvention.Winapi)>]
    extern int D3DCompileFromFile(
        [<MarshalAs(UnmanagedType.LPWStr)>] string pFileName,
        IntPtr pDefines,
        IntPtr pInclude,
        [<MarshalAs(UnmanagedType.LPStr)>] string pEntrypoint,
        [<MarshalAs(UnmanagedType.LPStr)>] string pTarget,
        uint32 Flags1,
        uint32 Flags2,
        [<Out>] IntPtr& ppCode,
        [<Out>] IntPtr& ppErrorMsgs)

// ============================================================================
// COM Delegate Types for VTable calls
// ============================================================================
module DelegateTypes =
    // ID3D12Debug
    type EnableDebugLayerDelegate = delegate of IntPtr -> unit

    // IDXGIFactory2
    type CreateSwapChainForHwndDelegate = delegate of IntPtr * IntPtr * IntPtr * byref<DXGI_SWAP_CHAIN_DESC1> * IntPtr * IntPtr * byref<IntPtr> -> int

    // IDXGISwapChain
    type PresentDelegate = delegate of IntPtr * uint32 * uint32 -> int
    type GetBufferDelegate = delegate of IntPtr * uint32 * byref<Guid> * byref<IntPtr> -> int

    // IDXGISwapChain3
    type GetCurrentBackBufferIndexDelegate = delegate of IntPtr -> uint32

    // ID3D12Device
    type CreateCommandQueueDelegate = delegate of IntPtr * byref<D3D12_COMMAND_QUEUE_DESC> * byref<Guid> * byref<IntPtr> -> int
    type CreateCommandAllocatorDelegate = delegate of IntPtr * int * byref<Guid> * byref<IntPtr> -> int
    type CreateGraphicsPipelineStateDelegate = delegate of IntPtr * byref<D3D12_GRAPHICS_PIPELINE_STATE_DESC> * byref<Guid> * byref<IntPtr> -> int
    type CreateCommandListDelegate = delegate of IntPtr * uint32 * int * IntPtr * IntPtr * byref<Guid> * byref<IntPtr> -> int
    type CreateDescriptorHeapDelegate = delegate of IntPtr * byref<D3D12_DESCRIPTOR_HEAP_DESC> * byref<Guid> * byref<IntPtr> -> int
    type GetDescriptorHandleIncrementSizeDelegate = delegate of IntPtr * int -> uint32
    type CreateRootSignatureDelegate = delegate of IntPtr * uint32 * IntPtr * IntPtr * byref<Guid> * byref<IntPtr> -> int
    type CreateRenderTargetViewDelegate = delegate of IntPtr * IntPtr * IntPtr * D3D12_CPU_DESCRIPTOR_HANDLE -> unit
    type CreateCommittedResourceDelegate = delegate of IntPtr * byref<D3D12_HEAP_PROPERTIES> * int * byref<D3D12_RESOURCE_DESC> * int * IntPtr * byref<Guid> * byref<IntPtr> -> int
    type CreateFenceDelegate = delegate of IntPtr * uint64 * int * byref<Guid> * byref<IntPtr> -> int

    // ID3D12GraphicsCommandList
    type CloseDelegate = delegate of IntPtr -> int
    type ResetCommandListDelegate = delegate of IntPtr * IntPtr * IntPtr -> int
    type IASetPrimitiveTopologyDelegate = delegate of IntPtr * int -> unit
    type RSSetViewportsDelegate = delegate of IntPtr * uint32 * D3D12_VIEWPORT[] -> unit
    type RSSetScissorRectsDelegate = delegate of IntPtr * uint32 * D3D12_RECT[] -> unit
    type ResourceBarrierDelegate = delegate of IntPtr * uint32 * D3D12_RESOURCE_BARRIER[] -> unit
    type SetGraphicsRootSignatureDelegate = delegate of IntPtr * IntPtr -> unit
    type OMSetRenderTargetsDelegate = delegate of IntPtr * uint32 * D3D12_CPU_DESCRIPTOR_HANDLE_ARRAY[] * bool * IntPtr -> unit
    type ClearRenderTargetViewDelegate = delegate of IntPtr * D3D12_CPU_DESCRIPTOR_HANDLE * float32[] * uint32 * IntPtr -> unit
    type IASetVertexBuffersDelegate = delegate of IntPtr * uint32 * uint32 * D3D12_VERTEX_BUFFER_VIEW[] -> unit
    type DrawInstancedDelegate = delegate of IntPtr * uint32 * uint32 * uint32 * uint32 -> unit

    // ID3D12CommandQueue
    type ExecuteCommandListsDelegate = delegate of IntPtr * uint32 * IntPtr[] -> unit
    type SignalDelegate = delegate of IntPtr * IntPtr * uint64 -> int

    // ID3D12CommandAllocator
    type ResetCommandAllocatorDelegate = delegate of IntPtr -> int

    // ID3D12Fence
    type GetCompletedValueDelegate = delegate of IntPtr -> uint64
    type SetEventOnCompletionDelegate = delegate of IntPtr * uint64 * IntPtr -> int

    // ID3D12DescriptorHeap
    type GetCPUDescriptorHandleForHeapStartDelegate = delegate of IntPtr * byref<D3D12_CPU_DESCRIPTOR_HANDLE> -> unit

    // ID3D12Resource
    type MapDelegate = delegate of IntPtr * uint32 * byref<D3D12_RANGE> * byref<IntPtr> -> int
    type UnmapDelegate = delegate of IntPtr * uint32 * byref<D3D12_RANGE> -> int
    type GetGPUVirtualAddressDelegate = delegate of IntPtr -> uint64

    // ID3DBlob
    type GetBufferPointerDelegate = delegate of IntPtr -> IntPtr
    type GetBufferSizeDelegate = delegate of IntPtr -> int

// ============================================================================
// GUIDs
// ============================================================================
module Guids =
    let IID_ID3D12Debug             = Guid("344488b7-6846-474b-b989-f027448245e0")
    let IID_ID3D12Device            = Guid("189819f1-1db6-4b57-be54-1821339b85f7")
    let IID_ID3D12Resource          = Guid("696442be-a72e-4059-bc79-5b5c98040fad")
    let IID_ID3D12PipelineState     = Guid("765a30f3-f624-4c6f-a828-ace948622445")
    let IID_ID3D12GraphicsCommandList = Guid("5b160d0f-ac1b-4185-8ba8-b3ae42a5a455")
    let IID_ID3D12Fence             = Guid("0a753dcf-c4d8-4b91-adf6-be5a60d95a76")
    let IID_ID3D12CommandQueue      = Guid("0ec870a6-5d7e-4c22-8cfc-5baae07616ed")
    let IID_ID3D12DescriptorHeap    = Guid("8efb471d-616c-4f49-90f7-127bb763fa51")
    let IID_ID3D12CommandAllocator  = Guid("6102dee4-af59-4b09-b999-b44d73f09b24")
    let IID_ID3D12RootSignature     = Guid("c54a6b66-72df-4ee8-8be5-a946a1429214")
    let IID_ID3DBlob                = Guid("8ba5fb08-5195-40e2-ac58-0d989c3a0102")
    let IID_IDXGIFactory4           = Guid("1bc6ea02-ef36-464f-bf0c-21ca39e5168a")
    let IID_IDXGISwapChain1         = Guid("790a45f7-0d42-4876-983a-0a55cfe6f4aa")

// ============================================================================
// Helper Functions
// ============================================================================
module Helpers =
    let inline getVTableMethod<'TDelegate when 'TDelegate :> Delegate> (comPtr: IntPtr) (index: int) : 'TDelegate =
        let vTable = Marshal.ReadIntPtr(comPtr)
        let methodPtr = Marshal.ReadIntPtr(vTable, index * IntPtr.Size)
        Marshal.GetDelegateForFunctionPointer<'TDelegate>(methodPtr)

    let getCPUDescriptorHandleForHeapStart (descriptorHeap: IntPtr) : IntPtr =
        let getHandle = getVTableMethod<DelegateTypes.GetCPUDescriptorHandleForHeapStartDelegate> descriptorHeap 9
        let mutable handle = D3D12_CPU_DESCRIPTOR_HANDLE()
        getHandle.Invoke(descriptorHeap, &handle)
        handle.ptr

    let getBufferPointer (blob: IntPtr) : IntPtr =
        if blob = IntPtr.Zero then IntPtr.Zero
        else
            let getPtr = getVTableMethod<DelegateTypes.GetBufferPointerDelegate> blob 3
            getPtr.Invoke(blob)

    let getBlobSize (blob: IntPtr) : int =
        if blob = IntPtr.Zero then 0
        else
            let getSize = getVTableMethod<DelegateTypes.GetBufferSizeDelegate> blob 4
            getSize.Invoke(blob)

    let structArrayToByteArray<'T when 'T : struct> (structures: 'T[]) : byte[] =
        let size = Marshal.SizeOf<'T>()
        let arr = Array.zeroCreate<byte> (size * structures.Length)
        let handle = GCHandle.Alloc(structures, GCHandleType.Pinned)
        try
            let ptr = handle.AddrOfPinnedObject()
            Marshal.Copy(ptr, arr, 0, arr.Length)
        finally
            handle.Free()
        arr

    let createDefaultRenderTargetBlendDesc () : D3D12_RENDER_TARGET_BLEND_DESC =
        let mutable desc = D3D12_RENDER_TARGET_BLEND_DESC()
        desc.BlendEnable <- false
        desc.LogicOpEnable <- false
        desc.SrcBlend <- 2       // D3D12_BLEND_ONE
        desc.DestBlend <- 1      // D3D12_BLEND_ZERO
        desc.BlendOp <- 1        // D3D12_BLEND_OP_ADD
        desc.SrcBlendAlpha <- 2  // D3D12_BLEND_ONE
        desc.DestBlendAlpha <- 1 // D3D12_BLEND_ZERO
        desc.BlendOpAlpha <- 1   // D3D12_BLEND_OP_ADD
        desc.LogicOp <- 4        // D3D12_LOGIC_OP_NOOP
        desc.RenderTargetWriteMask <- 0xfuy
        desc

    let createDefaultBlendDesc () : D3D12_BLEND_DESC =
        let mutable desc = D3D12_BLEND_DESC()
        desc.AlphaToCoverageEnable <- false
        desc.IndependentBlendEnable <- false
        desc.RenderTarget <- Array.init 8 (fun _ -> createDefaultRenderTargetBlendDesc())
        desc

    let createDefaultRasterizerDesc () : D3D12_RASTERIZER_DESC =
        let mutable desc = D3D12_RASTERIZER_DESC()
        desc.FillMode <- 3               // D3D12_FILL_MODE_SOLID
        desc.CullMode <- 3               // D3D12_CULL_MODE_BACK
        desc.FrontCounterClockwise <- false
        desc.DepthBias <- 0
        desc.DepthBiasClamp <- 0.0f
        desc.SlopeScaledDepthBias <- 0.0f
        desc.DepthClipEnable <- true
        desc.MultisampleEnable <- false
        desc.AntialiasedLineEnable <- false
        desc.ForcedSampleCount <- 0u
        desc.ConservativeRaster <- 0     // D3D12_CONSERVATIVE_RASTERIZATION_MODE_OFF
        desc

    let createDefaultDepthStencilOpDesc () : D3D12_DEPTH_STENCILOP_DESC =
        let mutable desc = D3D12_DEPTH_STENCILOP_DESC()
        desc.StencilFailOp <- 1          // D3D12_STENCIL_OP_KEEP
        desc.StencilDepthFailOp <- 1     // D3D12_STENCIL_OP_KEEP
        desc.StencilPassOp <- 1          // D3D12_STENCIL_OP_KEEP
        desc.StencilFunc <- 8            // D3D12_COMPARISON_FUNC_ALWAYS
        desc

    let createDefaultDepthStencilDesc () : D3D12_DEPTH_STENCIL_DESC =
        let mutable desc = D3D12_DEPTH_STENCIL_DESC()
        desc.DepthEnable <- false
        desc.DepthWriteMask <- 1         // D3D12_DEPTH_WRITE_MASK_ALL
        desc.DepthFunc <- 2              // D3D12_COMPARISON_FUNC_LESS
        desc.StencilEnable <- false
        desc.StencilReadMask <- 0xffuy
        desc.StencilWriteMask <- 0xffuy
        desc.FrontFace <- createDefaultDepthStencilOpDesc()
        desc.BackFace <- createDefaultDepthStencilOpDesc()
        desc

    let createTransitionBarrier (resource: IntPtr) (stateBefore: int) (stateAfter: int) : D3D12_RESOURCE_BARRIER =
        let mutable transition = D3D12_RESOURCE_TRANSITION_BARRIER()
        transition.pResource <- resource
        transition.Subresource <- D3D12Constants.D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES
        transition.StateBefore <- stateBefore
        transition.StateAfter <- stateAfter
        
        let mutable barrier = D3D12_RESOURCE_BARRIER()
        barrier.Type <- 0   // D3D12_RESOURCE_BARRIER_TYPE_TRANSITION
        barrier.Flags <- 0
        barrier.Transition <- transition
        barrier

// ============================================================================
// Main Application
// ============================================================================
type HelloDX12() =
    let FrameCount = 2
    
    let mutable device = IntPtr.Zero
    let mutable commandQueue = IntPtr.Zero
    let mutable swapChain = IntPtr.Zero
    let renderTargets = Array.zeroCreate<IntPtr> FrameCount
    let mutable commandAllocator = IntPtr.Zero
    let mutable commandList = IntPtr.Zero
    let mutable pipelineState = IntPtr.Zero
    let mutable rootSignature = IntPtr.Zero
    let mutable rtvHeap = IntPtr.Zero
    let mutable rtvDescriptorSize = 0u
    let mutable vertexBuffer = IntPtr.Zero
    let mutable vertexBufferView = D3D12_VERTEX_BUFFER_VIEW()
    let mutable fence = IntPtr.Zero
    let mutable fenceEvent = IntPtr.Zero
    let mutable fenceValue = 1UL
    let mutable frameIndex = 0

    let mutable swapChainDesc = DXGI_SWAP_CHAIN_DESC1()

    member private this.CompileShaderFromFile(fileName: string, entryPoint: string, profile: string) : IntPtr =
        printfn "[CompileShaderFromFile] File: %s, Entry: %s, Profile: %s" fileName entryPoint profile
        let mutable shaderBlob = IntPtr.Zero
        let mutable errorBlob = IntPtr.Zero

        let compileFlags = 
            let D3DCOMPILE_ENABLE_STRICTNESS = 1u <<< 11
            D3DCOMPILE_ENABLE_STRICTNESS

        let result = NativeMethods.D3DCompileFromFile(
            fileName,
            IntPtr.Zero,
            IntPtr.Zero,
            entryPoint,
            profile,
            compileFlags,
            0u,
            &shaderBlob,
            &errorBlob
        )

        if result < 0 then
            if errorBlob <> IntPtr.Zero then
                let errorMessage = Marshal.PtrToStringAnsi(Helpers.getBufferPointer errorBlob)
                printfn "Shader compilation error: %s" errorMessage
                Marshal.Release(errorBlob) |> ignore
            IntPtr.Zero
        else
            printfn "Shader compiled successfully. Blob: %X, Size: %d" (int64 shaderBlob) (Helpers.getBlobSize shaderBlob)
            shaderBlob

    member private this.LoadPipeline(hwnd: IntPtr) =
        printfn "[LoadPipeline] - Start"
        
        // Enable debug layer
        let mutable debugInterface = IntPtr.Zero
        let mutable debugGuid = Guids.IID_ID3D12Debug
        let debugResult = NativeMethods.D3D12GetDebugInterface(&debugGuid, &debugInterface)
        if debugResult >= 0 && debugInterface <> IntPtr.Zero then
            printfn "Enabling debug layer..."
            let enableDebugLayer = Helpers.getVTableMethod<DelegateTypes.EnableDebugLayerDelegate> debugInterface 3
            enableDebugLayer.Invoke(debugInterface)
            Marshal.Release(debugInterface) |> ignore

        // Create DXGI Factory
        let mutable factory = IntPtr.Zero
        let mutable factoryGuid = Guids.IID_IDXGIFactory4
        let factoryResult = NativeMethods.CreateDXGIFactory2(0u, &factoryGuid, &factory)
        if factoryResult < 0 then
            failwithf "Failed to create DXGI Factory: %X" factoryResult
        printfn "Factory created: %X" (int64 factory)

        // Create D3D12 Device
        let mutable deviceGuid = Guids.IID_ID3D12Device
        let deviceResult = NativeMethods.D3D12CreateDevice(IntPtr.Zero, D3D12Constants.D3D_FEATURE_LEVEL_11_0, &deviceGuid, &device)
        if deviceResult < 0 then
            failwithf "Failed to create D3D12 Device: %X" deviceResult
        printfn "Device created: %X" (int64 device)

        // Create Command Queue
        let mutable queueDesc = D3D12_COMMAND_QUEUE_DESC()
        queueDesc.Type <- 0       // D3D12_COMMAND_LIST_TYPE_DIRECT
        queueDesc.Priority <- 0
        queueDesc.Flags <- 0
        queueDesc.NodeMask <- 0u

        let mutable queueGuid = Guids.IID_ID3D12CommandQueue
        let createCommandQueue = Helpers.getVTableMethod<DelegateTypes.CreateCommandQueueDelegate> device 8
        let queueResult = createCommandQueue.Invoke(device, &queueDesc, &queueGuid, &commandQueue)
        if queueResult < 0 then
            failwithf "Failed to create Command Queue: %X" queueResult
        printfn "Command Queue created: %X" (int64 commandQueue)

        // Create Swap Chain
        let mutable sampleDesc = DXGI_SAMPLE_DESC()
        sampleDesc.Count <- 1u
        sampleDesc.Quality <- 0u

        swapChainDesc <- DXGI_SWAP_CHAIN_DESC1()
        swapChainDesc.Width <- 800u
        swapChainDesc.Height <- 600u
        swapChainDesc.Format <- DXGIConstants.DXGI_FORMAT_R8G8B8A8_UNORM
        swapChainDesc.Stereo <- false
        swapChainDesc.SampleDesc <- sampleDesc
        swapChainDesc.BufferUsage <- DXGIConstants.DXGI_USAGE_RENDER_TARGET_OUTPUT
        swapChainDesc.BufferCount <- uint32 FrameCount
        swapChainDesc.Scaling <- 0    // DXGI_SCALING_STRETCH
        swapChainDesc.SwapEffect <- DXGIConstants.DXGI_SWAP_EFFECT_FLIP_DISCARD
        swapChainDesc.AlphaMode <- 0  // DXGI_ALPHA_MODE_UNSPECIFIED
        swapChainDesc.Flags <- DXGIConstants.DXGI_SWAP_CHAIN_FLAG_ALLOW_MODE_SWITCH ||| DXGIConstants.DXGI_SWAP_CHAIN_FLAG_FRAME_LATENCY_WAITABLE_OBJECT

        let createSwapChainForHwnd = Helpers.getVTableMethod<DelegateTypes.CreateSwapChainForHwndDelegate> factory 15
        let swapChainResult = createSwapChainForHwnd.Invoke(factory, commandQueue, hwnd, &swapChainDesc, IntPtr.Zero, IntPtr.Zero, &swapChain)
        if swapChainResult < 0 then
            failwithf "Failed to create Swap Chain: %X" swapChainResult
        printfn "Swap Chain created: %X" (int64 swapChain)

        // Create RTV Descriptor Heap
        let mutable rtvHeapDesc = D3D12_DESCRIPTOR_HEAP_DESC()
        rtvHeapDesc.Type <- 2       // D3D12_DESCRIPTOR_HEAP_TYPE_RTV
        rtvHeapDesc.NumDescriptors <- uint32 FrameCount
        rtvHeapDesc.Flags <- 0      // D3D12_DESCRIPTOR_HEAP_FLAG_NONE
        rtvHeapDesc.NodeMask <- 0u

        let mutable heapGuid = Guids.IID_ID3D12DescriptorHeap
        let createHeap = Helpers.getVTableMethod<DelegateTypes.CreateDescriptorHeapDelegate> device 14
        let heapResult = createHeap.Invoke(device, &rtvHeapDesc, &heapGuid, &rtvHeap)
        if heapResult < 0 then
            failwithf "Failed to create Descriptor Heap: %X" heapResult
        printfn "RTV Heap created: %X" (int64 rtvHeap)

        let getIncrement = Helpers.getVTableMethod<DelegateTypes.GetDescriptorHandleIncrementSizeDelegate> device 15
        rtvDescriptorSize <- getIncrement.Invoke(device, 2)  // D3D12_DESCRIPTOR_HEAP_TYPE_RTV
        printfn "RTV Descriptor Size: %d" rtvDescriptorSize

        // Create RTVs
        let mutable rtvHandle = D3D12_CPU_DESCRIPTOR_HANDLE()
        rtvHandle.ptr <- Helpers.getCPUDescriptorHandleForHeapStart rtvHeap
        
        let getBuffer = Helpers.getVTableMethod<DelegateTypes.GetBufferDelegate> swapChain 9
        let createRTV = Helpers.getVTableMethod<DelegateTypes.CreateRenderTargetViewDelegate> device 20

        for i in 0 .. FrameCount - 1 do
            let mutable resourceGuid = Guids.IID_ID3D12Resource
            let mutable resourcePtr = IntPtr.Zero
            let bufferResult = getBuffer.Invoke(swapChain, uint32 i, &resourceGuid, &resourcePtr)
            if bufferResult < 0 then
                failwithf "Failed to get Buffer %d: %X" i bufferResult
            renderTargets.[i] <- resourcePtr
            createRTV.Invoke(device, resourcePtr, IntPtr.Zero, rtvHandle)
            rtvHandle.ptr <- IntPtr.Add(rtvHandle.ptr, int rtvDescriptorSize)
            printfn "Render Target %d created: %X" i (int64 resourcePtr)

        // Create Command Allocator
        let mutable allocatorGuid = Guids.IID_ID3D12CommandAllocator
        let createAllocator = Helpers.getVTableMethod<DelegateTypes.CreateCommandAllocatorDelegate> device 9
        let allocatorResult = createAllocator.Invoke(device, 0, &allocatorGuid, &commandAllocator)  // D3D12_COMMAND_LIST_TYPE_DIRECT
        if allocatorResult < 0 then
            failwithf "Failed to create Command Allocator: %X" allocatorResult
        printfn "Command Allocator created: %X" (int64 commandAllocator)

        Marshal.Release(factory) |> ignore

    member private this.LoadAssets() =
        printfn "[LoadAssets] - Start"

        // Create Root Signature
        let mutable rootSignatureDesc = D3D12_ROOT_SIGNATURE_DESC()
        rootSignatureDesc.NumParameters <- 0u
        rootSignatureDesc.pParameters <- IntPtr.Zero
        rootSignatureDesc.NumStaticSamplers <- 0u
        rootSignatureDesc.pStaticSamplers <- IntPtr.Zero
        rootSignatureDesc.Flags <- 1       // D3D12_ROOT_SIGNATURE_FLAG_ALLOW_INPUT_ASSEMBLER_INPUT_LAYOUT

        let mutable signature = IntPtr.Zero
        let mutable error = IntPtr.Zero
        let serializeResult = NativeMethods.D3D12SerializeRootSignature(&rootSignatureDesc, D3D12Constants.D3D_ROOT_SIGNATURE_VERSION_1, &signature, &error)
        if serializeResult < 0 then
            if error <> IntPtr.Zero then
                let errorMessage = Marshal.PtrToStringAnsi(Helpers.getBufferPointer error)
                printfn "Root signature serialization error: %s" errorMessage
                Marshal.Release(error) |> ignore
            failwithf "Failed to serialize root signature: %X" serializeResult

        let mutable rootSigGuid = Guids.IID_ID3D12RootSignature
        let createRootSignature = Helpers.getVTableMethod<DelegateTypes.CreateRootSignatureDelegate> device 16
        let rootSigResult = createRootSignature.Invoke(
            device,
            0u,
            Helpers.getBufferPointer signature,
            IntPtr(Helpers.getBlobSize signature),
            &rootSigGuid,
            &rootSignature
        )
        if rootSigResult < 0 then
            failwithf "Failed to create root signature: %X" rootSigResult
        printfn "Root Signature created: %X" (int64 rootSignature)
        Marshal.Release(signature) |> ignore

        // Compile Shaders
        let vertexShader = this.CompileShaderFromFile("hello.hlsl", "VSMain", "vs_5_0")
        let pixelShader = this.CompileShaderFromFile("hello.hlsl", "PSMain", "ps_5_0")

        if vertexShader = IntPtr.Zero || pixelShader = IntPtr.Zero then
            failwith "Failed to compile shaders"

        // Create Input Layout
        let positionSemanticName = Marshal.StringToHGlobalAnsi("POSITION")
        let colorSemanticName = Marshal.StringToHGlobalAnsi("COLOR")

        let mutable positionElement = D3D12_INPUT_ELEMENT_DESC()
        positionElement.SemanticName <- positionSemanticName
        positionElement.SemanticIndex <- 0u
        positionElement.Format <- DXGIConstants.DXGI_FORMAT_R32G32B32_FLOAT
        positionElement.InputSlot <- 0u
        positionElement.AlignedByteOffset <- 0u
        positionElement.InputSlotClass <- 0     // D3D12_INPUT_CLASSIFICATION_PER_VERTEX_DATA
        positionElement.InstanceDataStepRate <- 0u

        let mutable colorElement = D3D12_INPUT_ELEMENT_DESC()
        colorElement.SemanticName <- colorSemanticName
        colorElement.SemanticIndex <- 0u
        colorElement.Format <- DXGIConstants.DXGI_FORMAT_R32G32B32A32_FLOAT
        colorElement.InputSlot <- 0u
        colorElement.AlignedByteOffset <- 12u
        colorElement.InputSlotClass <- 0
        colorElement.InstanceDataStepRate <- 0u

        let inputElementDescs = [| positionElement; colorElement |]

        let inputElementsHandle = GCHandle.Alloc(inputElementDescs, GCHandleType.Pinned)
        let pInputElementDescs = inputElementsHandle.AddrOfPinnedObject()

        // Create Pipeline State
        let mutable vsShaderBytecode = D3D12_SHADER_BYTECODE()
        vsShaderBytecode.pShaderBytecode <- Helpers.getBufferPointer vertexShader
        vsShaderBytecode.BytecodeLength <- IntPtr(Helpers.getBlobSize vertexShader)

        let mutable psShaderBytecode = D3D12_SHADER_BYTECODE()
        psShaderBytecode.pShaderBytecode <- Helpers.getBufferPointer pixelShader
        psShaderBytecode.BytecodeLength <- IntPtr(Helpers.getBlobSize pixelShader)

        let mutable inputLayout = D3D12_INPUT_LAYOUT_DESC()
        inputLayout.pInputElementDescs <- pInputElementDescs
        inputLayout.NumElements <- uint32 inputElementDescs.Length

        let mutable sampleDesc = DXGI_SAMPLE_DESC()
        sampleDesc.Count <- 1u
        sampleDesc.Quality <- 0u

        let mutable psoDesc = D3D12_GRAPHICS_PIPELINE_STATE_DESC()
        psoDesc.pRootSignature <- rootSignature
        psoDesc.VS <- vsShaderBytecode
        psoDesc.PS <- psShaderBytecode
        psoDesc.BlendState <- Helpers.createDefaultBlendDesc()
        psoDesc.SampleMask <- UInt32.MaxValue
        psoDesc.RasterizerState <- Helpers.createDefaultRasterizerDesc()
        psoDesc.DepthStencilState <- Helpers.createDefaultDepthStencilDesc()
        psoDesc.InputLayout <- inputLayout
        psoDesc.PrimitiveTopologyType <- 3  // D3D12_PRIMITIVE_TOPOLOGY_TYPE_TRIANGLE
        psoDesc.NumRenderTargets <- 1u
        psoDesc.RTVFormats <- [| DXGIConstants.DXGI_FORMAT_R8G8B8A8_UNORM; 0u; 0u; 0u; 0u; 0u; 0u; 0u |]
        psoDesc.DSVFormat <- DXGIConstants.DXGI_FORMAT_UNKNOWN
        psoDesc.SampleDesc <- sampleDesc
        psoDesc.NodeMask <- 0u

        let mutable pipelineGuid = Guids.IID_ID3D12PipelineState
        let createPipelineState = Helpers.getVTableMethod<DelegateTypes.CreateGraphicsPipelineStateDelegate> device 10
        let pipelineResult = createPipelineState.Invoke(device, &psoDesc, &pipelineGuid, &pipelineState)
        
        inputElementsHandle.Free()
        Marshal.FreeHGlobal(positionSemanticName)
        Marshal.FreeHGlobal(colorSemanticName)

        if pipelineResult < 0 then
            failwithf "Failed to create pipeline state: %X" pipelineResult
        printfn "Pipeline State created: %X" (int64 pipelineState)

        // Create Command List
        let mutable cmdListGuid = Guids.IID_ID3D12GraphicsCommandList
        let createCommandList = Helpers.getVTableMethod<DelegateTypes.CreateCommandListDelegate> device 12
        let cmdListResult = createCommandList.Invoke(device, 0u, 0, commandAllocator, pipelineState, &cmdListGuid, &commandList)
        if cmdListResult < 0 then
            failwithf "Failed to create command list: %X" cmdListResult
        printfn "Command List created: %X" (int64 commandList)

        // Close command list
        let closeCmd = Helpers.getVTableMethod<DelegateTypes.CloseDelegate> commandList 9
        closeCmd.Invoke(commandList) |> ignore

        // Create Vertex Buffer
        let aspectRatio = 800.0f / 600.0f
        
        let mutable v0 = Vertex()
        v0.X <- 0.0f; v0.Y <- 0.5f * aspectRatio; v0.Z <- 0.0f
        v0.R <- 1.0f; v0.G <- 0.0f; v0.B <- 0.0f; v0.A <- 1.0f

        let mutable v1 = Vertex()
        v1.X <- 0.5f; v1.Y <- -0.5f * aspectRatio; v1.Z <- 0.0f
        v1.R <- 0.0f; v1.G <- 1.0f; v1.B <- 0.0f; v1.A <- 1.0f

        let mutable v2 = Vertex()
        v2.X <- -0.5f; v2.Y <- -0.5f * aspectRatio; v2.Z <- 0.0f
        v2.R <- 0.0f; v2.G <- 0.0f; v2.B <- 1.0f; v2.A <- 1.0f

        let triangleVertices = [| v0; v1; v2 |]

        let vertexBufferSize = uint32 (Marshal.SizeOf<Vertex>() * triangleVertices.Length)

        let mutable heapProps = D3D12_HEAP_PROPERTIES()
        heapProps.Type <- 2       // D3D12_HEAP_TYPE_UPLOAD
        heapProps.CPUPageProperty <- 0
        heapProps.MemoryPoolPreference <- 0
        heapProps.CreationNodeMask <- 0u
        heapProps.VisibleNodeMask <- 0u

        let mutable vbSampleDesc = DXGI_SAMPLE_DESC()
        vbSampleDesc.Count <- 1u
        vbSampleDesc.Quality <- 0u

        let mutable resourceDesc = D3D12_RESOURCE_DESC()
        resourceDesc.Dimension <- 1  // D3D12_RESOURCE_DIMENSION_BUFFER
        resourceDesc.Alignment <- 0UL
        resourceDesc.Width <- uint64 vertexBufferSize
        resourceDesc.Height <- 1u
        resourceDesc.DepthOrArraySize <- 1us
        resourceDesc.MipLevels <- 1us
        resourceDesc.Format <- DXGIConstants.DXGI_FORMAT_UNKNOWN
        resourceDesc.SampleDesc <- vbSampleDesc
        resourceDesc.Layout <- 1     // D3D12_TEXTURE_LAYOUT_ROW_MAJOR
        resourceDesc.Flags <- 0

        let mutable resourceGuid = Guids.IID_ID3D12Resource
        let createCommittedResource = Helpers.getVTableMethod<DelegateTypes.CreateCommittedResourceDelegate> device 27
        let resourceResult = createCommittedResource.Invoke(
            device,
            &heapProps,
            0,              // D3D12_HEAP_FLAG_NONE
            &resourceDesc,
            0x1 ||| 0x2 ||| 0x40 ||| 0x80 ||| 0x200 ||| 0x800, // D3D12_RESOURCE_STATE_GENERIC_READ
            IntPtr.Zero,
            &resourceGuid,
            &vertexBuffer
        )
        if resourceResult < 0 then
            failwithf "Failed to create vertex buffer: %X" resourceResult
        printfn "Vertex Buffer created: %X" (int64 vertexBuffer)

        // Upload vertex data
        let mutable pData = IntPtr.Zero
        let mutable readRange = D3D12_RANGE()
        readRange.Begin <- 0UL
        readRange.End <- 0UL
        
        let mapFunc = Helpers.getVTableMethod<DelegateTypes.MapDelegate> vertexBuffer 8
        let mapResult = mapFunc.Invoke(vertexBuffer, 0u, &readRange, &pData)
        if mapResult >= 0 then
            let vertexData = Helpers.structArrayToByteArray triangleVertices
            Marshal.Copy(vertexData, 0, pData, int vertexBufferSize)
            
            let mutable emptyRange = D3D12_RANGE()
            emptyRange.Begin <- 0UL
            emptyRange.End <- 0UL
            let unmapFunc = Helpers.getVTableMethod<DelegateTypes.UnmapDelegate> vertexBuffer 9
            unmapFunc.Invoke(vertexBuffer, 0u, &emptyRange) |> ignore

        // Create Vertex Buffer View
        let getGPUVirtualAddress = Helpers.getVTableMethod<DelegateTypes.GetGPUVirtualAddressDelegate> vertexBuffer 11
        vertexBufferView <- D3D12_VERTEX_BUFFER_VIEW()
        vertexBufferView.BufferLocation <- getGPUVirtualAddress.Invoke(vertexBuffer)
        vertexBufferView.StrideInBytes <- uint32 (Marshal.SizeOf<Vertex>())
        vertexBufferView.SizeInBytes <- vertexBufferSize
        printfn "Vertex Buffer View - Location: %X, Stride: %d, Size: %d" vertexBufferView.BufferLocation vertexBufferView.StrideInBytes vertexBufferView.SizeInBytes

        // Create Fence
        let mutable fenceGuid = Guids.IID_ID3D12Fence
        let createFence = Helpers.getVTableMethod<DelegateTypes.CreateFenceDelegate> device 36
        let fenceResult = createFence.Invoke(device, 0UL, 0, &fenceGuid, &fence)
        if fenceResult < 0 then
            failwithf "Failed to create fence: %X" fenceResult
        printfn "Fence created: %X" (int64 fence)

        fenceValue <- 1UL
        fenceEvent <- NativeMethods.CreateEvent(IntPtr.Zero, false, false, null)

        // Cleanup shader blobs
        Marshal.Release(vertexShader) |> ignore
        Marshal.Release(pixelShader) |> ignore

    member private this.PopulateCommandList() =
        // Reset command allocator
        let resetAllocator = Helpers.getVTableMethod<DelegateTypes.ResetCommandAllocatorDelegate> commandAllocator 8
        resetAllocator.Invoke(commandAllocator) |> ignore

        // Reset command list
        let resetCmdList = Helpers.getVTableMethod<DelegateTypes.ResetCommandListDelegate> commandList 10
        resetCmdList.Invoke(commandList, commandAllocator, pipelineState) |> ignore

        // Set root signature
        let setRootSig = Helpers.getVTableMethod<DelegateTypes.SetGraphicsRootSignatureDelegate> commandList 30
        setRootSig.Invoke(commandList, rootSignature)

        // Set viewports
        let mutable viewport = D3D12_VIEWPORT()
        viewport.TopLeftX <- 0.0f
        viewport.TopLeftY <- 0.0f
        viewport.Width <- 800.0f
        viewport.Height <- 600.0f
        viewport.MinDepth <- 0.0f
        viewport.MaxDepth <- 1.0f
        let viewports = [| viewport |]
        let setViewports = Helpers.getVTableMethod<DelegateTypes.RSSetViewportsDelegate> commandList 21
        setViewports.Invoke(commandList, 1u, viewports)

        // Set scissor rects
        let mutable scissorRect = D3D12_RECT()
        scissorRect.left <- 0
        scissorRect.top <- 0
        scissorRect.right <- 800
        scissorRect.bottom <- 600
        let scissorRects = [| scissorRect |]
        let setScissorRects = Helpers.getVTableMethod<DelegateTypes.RSSetScissorRectsDelegate> commandList 22
        setScissorRects.Invoke(commandList, 1u, scissorRects)

        // Transition: PRESENT -> RENDER_TARGET
        let barrier1 = Helpers.createTransitionBarrier renderTargets.[frameIndex] 0 4  // PRESENT -> RENDER_TARGET
        let resourceBarrier = Helpers.getVTableMethod<DelegateTypes.ResourceBarrierDelegate> commandList 26
        resourceBarrier.Invoke(commandList, 1u, [| barrier1 |])

        // Set render target
        let mutable rtvHandle = D3D12_CPU_DESCRIPTOR_HANDLE()
        rtvHandle.ptr <- IntPtr.Add(Helpers.getCPUDescriptorHandleForHeapStart rtvHeap, frameIndex * int rtvDescriptorSize)
        let mutable rtvHandleArray = D3D12_CPU_DESCRIPTOR_HANDLE_ARRAY()
        rtvHandleArray.ptr <- rtvHandle.ptr
        let rtvHandleArrays = [| rtvHandleArray |]
        let setRenderTargets = Helpers.getVTableMethod<DelegateTypes.OMSetRenderTargetsDelegate> commandList 46
        setRenderTargets.Invoke(commandList, 1u, rtvHandleArrays, false, IntPtr.Zero)

        // Clear render target
        let clearColor = [| 0.0f; 0.2f; 0.4f; 1.0f |]
        let clearRTV = Helpers.getVTableMethod<DelegateTypes.ClearRenderTargetViewDelegate> commandList 48
        clearRTV.Invoke(commandList, rtvHandle, clearColor, 0u, IntPtr.Zero)

        // Set primitive topology
        let setPrimTopo = Helpers.getVTableMethod<DelegateTypes.IASetPrimitiveTopologyDelegate> commandList 20
        setPrimTopo.Invoke(commandList, 4)  // D3D_PRIMITIVE_TOPOLOGY_TRIANGLELIST

        // Set vertex buffer
        let setVB = Helpers.getVTableMethod<DelegateTypes.IASetVertexBuffersDelegate> commandList 44
        setVB.Invoke(commandList, 0u, 1u, [| vertexBufferView |])

        // Draw
        let draw = Helpers.getVTableMethod<DelegateTypes.DrawInstancedDelegate> commandList 12
        draw.Invoke(commandList, 3u, 1u, 0u, 0u)

        // Transition: RENDER_TARGET -> PRESENT
        let barrier2 = Helpers.createTransitionBarrier renderTargets.[frameIndex] 4 0  // RENDER_TARGET -> PRESENT
        resourceBarrier.Invoke(commandList, 1u, [| barrier2 |])

        // Close command list
        let closeCmd = Helpers.getVTableMethod<DelegateTypes.CloseDelegate> commandList 9
        closeCmd.Invoke(commandList) |> ignore

    member private this.WaitForPreviousFrame() =
        // Signal
        let signalFunc = Helpers.getVTableMethod<DelegateTypes.SignalDelegate> commandQueue 14
        signalFunc.Invoke(commandQueue, fence, fenceValue) |> ignore

        // Wait
        let getCompleted = Helpers.getVTableMethod<DelegateTypes.GetCompletedValueDelegate> fence 8
        if getCompleted.Invoke(fence) < fenceValue then
            let setEvent = Helpers.getVTableMethod<DelegateTypes.SetEventOnCompletionDelegate> fence 9
            setEvent.Invoke(fence, fenceValue, fenceEvent) |> ignore
            NativeMethods.WaitForSingleObject(fenceEvent, Win32Constants.INFINITE) |> ignore

        fenceValue <- fenceValue + 1UL

    member this.Render() =
        this.PopulateCommandList()

        // Execute command list
        let commandLists = [| commandList |]
        let execute = Helpers.getVTableMethod<DelegateTypes.ExecuteCommandListsDelegate> commandQueue 10
        execute.Invoke(commandQueue, 1u, commandLists)

        // Present
        let present = Helpers.getVTableMethod<DelegateTypes.PresentDelegate> swapChain 8
        present.Invoke(swapChain, 0u, 0u) |> ignore

        this.WaitForPreviousFrame()

    member this.Cleanup() =
        printfn "[Cleanup] - Start"
        
        NativeMethods.CloseHandle(fenceEvent) |> ignore

        if fence <> IntPtr.Zero then Marshal.Release(fence) |> ignore
        if vertexBuffer <> IntPtr.Zero then Marshal.Release(vertexBuffer) |> ignore
        if pipelineState <> IntPtr.Zero then Marshal.Release(pipelineState) |> ignore
        if rootSignature <> IntPtr.Zero then Marshal.Release(rootSignature) |> ignore
        if commandList <> IntPtr.Zero then Marshal.Release(commandList) |> ignore
        if commandAllocator <> IntPtr.Zero then Marshal.Release(commandAllocator) |> ignore
        if rtvHeap <> IntPtr.Zero then Marshal.Release(rtvHeap) |> ignore

        for rt in renderTargets do
            if rt <> IntPtr.Zero then Marshal.Release(rt) |> ignore

        if swapChain <> IntPtr.Zero then Marshal.Release(swapChain) |> ignore
        if commandQueue <> IntPtr.Zero then Marshal.Release(commandQueue) |> ignore
        if device <> IntPtr.Zero then Marshal.Release(device) |> ignore

    member this.Run(hwnd: IntPtr) =
        this.LoadPipeline(hwnd)
        this.LoadAssets()

// ============================================================================
// Entry Point
// ============================================================================
module Program =
    let mutable wndProcDelegate: WndProcDelegate = null

    let WndProc (hWnd: IntPtr) (uMsg: uint32) (wParam: IntPtr) (lParam: IntPtr) : IntPtr =
        match uMsg with
        | msg when msg = Win32Constants.WM_PAINT ->
            let mutable ps = PAINTSTRUCT()
            let hdc = NativeMethods.BeginPaint(hWnd, &ps)
            let text = "Hello, DirectX 12 (F#) World!"
            NativeMethods.TextOut(hdc, 0, 0, text, text.Length) |> ignore
            NativeMethods.EndPaint(hWnd, &ps) |> ignore
            IntPtr.Zero
        | msg when msg = Win32Constants.WM_DESTROY ->
            NativeMethods.PostQuitMessage(0)
            IntPtr.Zero
        | _ ->
            NativeMethods.DefWindowProc(hWnd, uMsg, wParam, lParam)

    [<EntryPoint; STAThread>]
    let main argv =
        printfn "=========================================="
        printfn "[Main] - F# DirectX 12 Triangle Demo"
        printfn "=========================================="

        let app = HelloDX12()

        let CLASS_NAME = "MyDX12WindowClass"
        let WINDOW_NAME = "Hello, World!"

        let hInstance = Marshal.GetHINSTANCE(typeof<HelloDX12>.Module)
        printfn "hInstance: %X" (int64 hInstance)

        // Keep delegate reference alive
        wndProcDelegate <- WndProcDelegate(WndProc)

        let mutable wndClassEx = WNDCLASSEX()
        wndClassEx.cbSize <- uint32 (Marshal.SizeOf(typeof<WNDCLASSEX>))
        wndClassEx.style <- Win32Constants.CS_OWNDC
        wndClassEx.lpfnWndProc <- wndProcDelegate
        wndClassEx.cbClsExtra <- 0
        wndClassEx.cbWndExtra <- 0
        wndClassEx.hInstance <- hInstance
        wndClassEx.hIcon <- IntPtr.Zero
        wndClassEx.hCursor <- NativeMethods.LoadCursor(IntPtr.Zero, Win32Constants.IDC_ARROW)
        wndClassEx.hbrBackground <- IntPtr.Zero
        wndClassEx.lpszMenuName <- null
        wndClassEx.lpszClassName <- CLASS_NAME
        wndClassEx.hIconSm <- IntPtr.Zero

        let atom = NativeMethods.RegisterClassEx(&wndClassEx)
        if atom = 0us then
            let error = Marshal.GetLastWin32Error()
            printfn "Failed to register window class. Error: %d" error
            1
        else
            printfn "Window class registered. Atom: %d" atom

            let hwnd = NativeMethods.CreateWindowEx(
                0u,
                CLASS_NAME,
                WINDOW_NAME,
                Win32Constants.WS_OVERLAPPEDWINDOW ||| Win32Constants.WS_VISIBLE,
                100, 100,
                800, 600,
                IntPtr.Zero,
                IntPtr.Zero,
                hInstance,
                IntPtr.Zero
            )

            if hwnd = IntPtr.Zero then
                printfn "Failed to create window"
                1
            else
                printfn "Window created: %X" (int64 hwnd)

                try
                    app.Run(hwnd)
                    NativeMethods.ShowWindow(hwnd, 1) |> ignore

                    let mutable msg = MSG()
                    let mutable running = true

                    while running do
                        if NativeMethods.PeekMessage(&msg, IntPtr.Zero, 0u, 0u, Win32Constants.PM_REMOVE) then
                            if msg.message = Win32Constants.WM_QUIT then
                                running <- false
                            else
                                NativeMethods.TranslateMessage(&msg) |> ignore
                                NativeMethods.DispatchMessage(&msg) |> ignore
                        else
                            app.Render()

                    int msg.wParam
                finally
                    app.Cleanup()
