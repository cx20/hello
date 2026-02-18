// F# DirectX 12 Compute Harmonograph Sample - No external libraries
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
    let DXGI_FORMAT_R32G32_FLOAT        = 16u
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
    let D3D12_DESCRIPTOR_RANGE_OFFSET_APPEND = 0xffffffffu
    let D3D12_DEFAULT_SHADER_4_COMPONENT_MAPPING = 5768
    let D3D12_SRV_DIMENSION_BUFFER = 1

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
type D3D12_CONSTANT_BUFFER_VIEW_DESC =
    val mutable BufferLocation: uint64
    val mutable SizeInBytes: uint32

[<Struct; StructLayout(LayoutKind.Sequential)>]
type D3D12_ROOT_SIGNATURE_DESC =
    val mutable NumParameters: uint32
    val mutable pParameters: IntPtr
    val mutable NumStaticSamplers: uint32
    val mutable pStaticSamplers: IntPtr
    val mutable Flags: int

[<Struct; StructLayout(LayoutKind.Sequential)>]
type D3D12_ROOT_DESCRIPTOR_TABLE =
    val mutable NumDescriptorRanges: uint32
    val mutable pDescriptorRanges: IntPtr

[<Struct; StructLayout(LayoutKind.Sequential)>]
type D3D12_ROOT_PARAMETER =
    val mutable ParameterType: int
    val mutable DescriptorTable: D3D12_ROOT_DESCRIPTOR_TABLE
    val mutable ShaderVisibility: int

[<Struct; StructLayout(LayoutKind.Sequential)>]
type D3D12_DESCRIPTOR_RANGE =
    val mutable RangeType: int
    val mutable NumDescriptors: uint32
    val mutable BaseShaderRegister: uint32
    val mutable RegisterSpace: uint32
    val mutable OffsetInDescriptorsFromTableStart: uint32

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
type D3D12_COMPUTE_PIPELINE_STATE_DESC =
    val mutable pRootSignature: IntPtr
    val mutable CS: D3D12_SHADER_BYTECODE
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

[<Struct; StructLayout(LayoutKind.Sequential)>]
type D3D12_UNORDERED_ACCESS_VIEW_DESC =
    val mutable Format: uint32
    val mutable ViewDimension: int
    val mutable Buffer_FirstElement: uint64
    val mutable Buffer_NumElements: uint32
    val mutable Buffer_StructureByteStride: uint32
    val mutable Buffer_CounterOffsetInBytes: uint64
    val mutable Buffer_Flags: int

[<Struct; StructLayout(LayoutKind.Sequential)>]
type D3D12_SHADER_RESOURCE_VIEW_DESC =
    val mutable Format: uint32
    val mutable ViewDimension: int
    val mutable Shader4ComponentMapping: int
    val mutable Buffer_FirstElement: uint64
    val mutable Buffer_NumElements: uint32
    val mutable Buffer_StructureByteStride: uint32
    val mutable Buffer_Flags: int

[<Struct; StructLayout(LayoutKind.Sequential)>]
type HarmonographParams =
    val mutable A1: float32
    val mutable f1: float32
    val mutable p1: float32
    val mutable d1: float32
    val mutable A2: float32
    val mutable f2: float32
    val mutable p2: float32
    val mutable d2: float32
    val mutable A3: float32
    val mutable f3: float32
    val mutable p3: float32
    val mutable d3: float32
    val mutable A4: float32
    val mutable f4: float32
    val mutable p4: float32
    val mutable d4: float32
    val mutable max_num: uint32
    val mutable padding1: float32
    val mutable padding2: float32
    val mutable padding3: float32
    val mutable resolutionX: float32
    val mutable resolutionY: float32
    val mutable padding4: float32
    val mutable padding5: float32

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
    type CreateComputePipelineStateDelegate = delegate of IntPtr * byref<D3D12_COMPUTE_PIPELINE_STATE_DESC> * byref<Guid> * byref<IntPtr> -> int
    type CreateCommandListDelegate = delegate of IntPtr * uint32 * int * IntPtr * IntPtr * byref<Guid> * byref<IntPtr> -> int
    type CreateDescriptorHeapDelegate = delegate of IntPtr * byref<D3D12_DESCRIPTOR_HEAP_DESC> * byref<Guid> * byref<IntPtr> -> int
    type GetDescriptorHandleIncrementSizeDelegate = delegate of IntPtr * int -> uint32
    type CreateRootSignatureDelegate = delegate of IntPtr * uint32 * IntPtr * IntPtr * byref<Guid> * byref<IntPtr> -> int
    type CreateShaderResourceViewDelegate = delegate of IntPtr * IntPtr * byref<D3D12_SHADER_RESOURCE_VIEW_DESC> * D3D12_CPU_DESCRIPTOR_HANDLE -> unit
    type CreateUnorderedAccessViewDelegate = delegate of IntPtr * IntPtr * IntPtr * byref<D3D12_UNORDERED_ACCESS_VIEW_DESC> * D3D12_CPU_DESCRIPTOR_HANDLE -> unit
    type CreateRenderTargetViewDelegate = delegate of IntPtr * IntPtr * IntPtr * D3D12_CPU_DESCRIPTOR_HANDLE -> unit
    type CreateConstantBufferViewDelegate = delegate of IntPtr * byref<D3D12_CONSTANT_BUFFER_VIEW_DESC> * D3D12_CPU_DESCRIPTOR_HANDLE -> unit
    type CreateCommittedResourceDelegate = delegate of IntPtr * byref<D3D12_HEAP_PROPERTIES> * int * byref<D3D12_RESOURCE_DESC> * int * IntPtr * byref<Guid> * byref<IntPtr> -> int
    type CreateFenceDelegate = delegate of IntPtr * uint64 * int * byref<Guid> * byref<IntPtr> -> int

    // ID3D12GraphicsCommandList
    type CloseDelegate = delegate of IntPtr -> int
    type ResetCommandListDelegate = delegate of IntPtr * IntPtr * IntPtr -> int
    type DispatchDelegate = delegate of IntPtr * uint32 * uint32 * uint32 -> unit
    type IASetPrimitiveTopologyDelegate = delegate of IntPtr * int -> unit
    type RSSetViewportsDelegate = delegate of IntPtr * uint32 * D3D12_VIEWPORT[] -> unit
    type RSSetScissorRectsDelegate = delegate of IntPtr * uint32 * D3D12_RECT[] -> unit
    type ResourceBarrierDelegate = delegate of IntPtr * uint32 * D3D12_RESOURCE_BARRIER[] -> unit
    type SetComputeRootSignatureDelegate = delegate of IntPtr * IntPtr -> unit
    type SetGraphicsRootSignatureDelegate = delegate of IntPtr * IntPtr -> unit
    type SetDescriptorHeapsDelegate = delegate of IntPtr * uint32 * IntPtr[] -> unit
    type SetComputeRootDescriptorTableDelegate = delegate of IntPtr * uint32 * D3D12_GPU_DESCRIPTOR_HANDLE -> unit
    type SetGraphicsRootDescriptorTableDelegate = delegate of IntPtr * uint32 * D3D12_GPU_DESCRIPTOR_HANDLE -> unit
    type OMSetRenderTargetsDelegate = delegate of IntPtr * uint32 * D3D12_CPU_DESCRIPTOR_HANDLE_ARRAY[] * bool * IntPtr -> unit
    type ClearRenderTargetViewDelegate = delegate of IntPtr * D3D12_CPU_DESCRIPTOR_HANDLE * float32[] * uint32 * IntPtr -> unit
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
    type GetGPUDescriptorHandleForHeapStartDelegate = delegate of IntPtr * byref<D3D12_GPU_DESCRIPTOR_HANDLE> -> unit

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
    let IID_IDXGISwapChain3         = Guid("94d99bdb-f1f8-4ab0-b236-7da0170edab1")

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

    let getGPUDescriptorHandleForHeapStart (descriptorHeap: IntPtr) : D3D12_GPU_DESCRIPTOR_HANDLE =
        let getHandle = getVTableMethod<DelegateTypes.GetGPUDescriptorHandleForHeapStartDelegate> descriptorHeap 10
        let mutable handle = D3D12_GPU_DESCRIPTOR_HANDLE()
        getHandle.Invoke(descriptorHeap, &handle)
        handle

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
    let Width = 800
    let Height = 600
    let FrameCount = 2
    let VertexCount = 100000u
    let PI2 = 6.283185307179586f

    let mutable device = IntPtr.Zero
    let mutable commandQueue = IntPtr.Zero
    let mutable swapChain = IntPtr.Zero
    let renderTargets = Array.zeroCreate<IntPtr> FrameCount
    let mutable commandAllocator = IntPtr.Zero
    let mutable computeCommandAllocator = IntPtr.Zero
    let mutable commandList = IntPtr.Zero
    let mutable computeCommandList = IntPtr.Zero
    let mutable graphicsPipelineState = IntPtr.Zero
    let mutable computePipelineState = IntPtr.Zero
    let mutable graphicsRootSignature = IntPtr.Zero
    let mutable computeRootSignature = IntPtr.Zero
    let mutable rtvHeap = IntPtr.Zero
    let mutable srvUavHeap = IntPtr.Zero
    let mutable rtvDescriptorSize = 0u
    let mutable srvUavDescriptorSize = 0u
    let mutable positionBuffer = IntPtr.Zero
    let mutable colorBuffer = IntPtr.Zero
    let mutable constantBuffer = IntPtr.Zero
    let mutable constantBufferDataBegin = IntPtr.Zero
    let mutable fence = IntPtr.Zero
    let mutable fenceEvent = IntPtr.Zero
    let mutable fenceValue = 1UL
    let mutable frameIndex = 0

    let mutable A1 = 50.0f
    let mutable f1 = 2.0f
    let mutable p1 = 1.0f / 16.0f
    let mutable d1 = 0.02f
    let mutable A2 = 50.0f
    let mutable f2 = 2.0f
    let mutable p2 = 3.0f / 2.0f
    let mutable d2 = 0.0315f
    let mutable A3 = 50.0f
    let mutable f3 = 2.0f
    let mutable p3 = 13.0f / 15.0f
    let mutable d3 = 0.02f
    let mutable A4 = 50.0f
    let mutable f4 = 2.0f
    let mutable p4 = 1.0f
    let mutable d4 = 0.02f
    let rand = Random()

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

    member private this.GetCurrentBackBufferIndex() : int =
        let getCurrent = Helpers.getVTableMethod<DelegateTypes.GetCurrentBackBufferIndexDelegate> swapChain 36
        int (getCurrent.Invoke(swapChain))

    member private this.LoadPipeline(hwnd: IntPtr) =
        let mutable debugInterface = IntPtr.Zero
        let mutable debugGuid = Guids.IID_ID3D12Debug
        let debugResult = NativeMethods.D3D12GetDebugInterface(&debugGuid, &debugInterface)
        if debugResult >= 0 && debugInterface <> IntPtr.Zero then
            let enableDebugLayer = Helpers.getVTableMethod<DelegateTypes.EnableDebugLayerDelegate> debugInterface 3
            enableDebugLayer.Invoke(debugInterface)
            Marshal.Release(debugInterface) |> ignore

        let mutable factory = IntPtr.Zero
        let mutable factoryGuid = Guids.IID_IDXGIFactory4
        let factoryResult = NativeMethods.CreateDXGIFactory2(0u, &factoryGuid, &factory)
        if factoryResult < 0 then failwithf "CreateDXGIFactory2 failed: %X" factoryResult

        let mutable deviceGuid = Guids.IID_ID3D12Device
        let deviceResult = NativeMethods.D3D12CreateDevice(IntPtr.Zero, D3D12Constants.D3D_FEATURE_LEVEL_11_0, &deviceGuid, &device)
        if deviceResult < 0 then failwithf "D3D12CreateDevice failed: %X" deviceResult

        let mutable queueDesc = D3D12_COMMAND_QUEUE_DESC()
        queueDesc.Type <- 0
        queueDesc.Priority <- 0
        queueDesc.Flags <- 0
        queueDesc.NodeMask <- 0u

        let mutable queueGuid = Guids.IID_ID3D12CommandQueue
        let createCommandQueue = Helpers.getVTableMethod<DelegateTypes.CreateCommandQueueDelegate> device 8
        let queueResult = createCommandQueue.Invoke(device, &queueDesc, &queueGuid, &commandQueue)
        if queueResult < 0 then failwithf "CreateCommandQueue failed: %X" queueResult

        let mutable sampleDesc = DXGI_SAMPLE_DESC()
        sampleDesc.Count <- 1u
        sampleDesc.Quality <- 0u

        let mutable swapChainDesc = DXGI_SWAP_CHAIN_DESC1()
        swapChainDesc.Width <- uint32 Width
        swapChainDesc.Height <- uint32 Height
        swapChainDesc.Format <- DXGIConstants.DXGI_FORMAT_R8G8B8A8_UNORM
        swapChainDesc.Stereo <- false
        swapChainDesc.SampleDesc <- sampleDesc
        swapChainDesc.BufferUsage <- DXGIConstants.DXGI_USAGE_RENDER_TARGET_OUTPUT
        swapChainDesc.BufferCount <- uint32 FrameCount
        swapChainDesc.Scaling <- 0
        swapChainDesc.SwapEffect <- DXGIConstants.DXGI_SWAP_EFFECT_FLIP_DISCARD
        swapChainDesc.AlphaMode <- 0
        swapChainDesc.Flags <- DXGIConstants.DXGI_SWAP_CHAIN_FLAG_ALLOW_MODE_SWITCH ||| DXGIConstants.DXGI_SWAP_CHAIN_FLAG_FRAME_LATENCY_WAITABLE_OBJECT

        let createSwapChainForHwnd = Helpers.getVTableMethod<DelegateTypes.CreateSwapChainForHwndDelegate> factory 15
        let swapChainResult = createSwapChainForHwnd.Invoke(factory, commandQueue, hwnd, &swapChainDesc, IntPtr.Zero, IntPtr.Zero, &swapChain)
        if swapChainResult < 0 then failwithf "CreateSwapChainForHwnd failed: %X" swapChainResult

        let swapChain1 = swapChain
        let mutable swapChain3Guid = Guids.IID_IDXGISwapChain3
        let queryResult = Marshal.QueryInterface(swapChain1, &swapChain3Guid, &swapChain)
        if queryResult < 0 then failwithf "QueryInterface IDXGISwapChain3 failed: %X" queryResult
        Marshal.Release(swapChain1) |> ignore
        frameIndex <- this.GetCurrentBackBufferIndex()

        let mutable rtvHeapDesc = D3D12_DESCRIPTOR_HEAP_DESC()
        rtvHeapDesc.Type <- 2
        rtvHeapDesc.NumDescriptors <- uint32 FrameCount
        rtvHeapDesc.Flags <- 0
        rtvHeapDesc.NodeMask <- 0u

        let mutable heapGuid = Guids.IID_ID3D12DescriptorHeap
        let createHeap = Helpers.getVTableMethod<DelegateTypes.CreateDescriptorHeapDelegate> device 14
        let heapResult = createHeap.Invoke(device, &rtvHeapDesc, &heapGuid, &rtvHeap)
        if heapResult < 0 then failwithf "CreateDescriptorHeap RTV failed: %X" heapResult

        let getIncrement = Helpers.getVTableMethod<DelegateTypes.GetDescriptorHandleIncrementSizeDelegate> device 15
        rtvDescriptorSize <- getIncrement.Invoke(device, 2)
        srvUavDescriptorSize <- getIncrement.Invoke(device, 0)

        let mutable srvHeapDesc = D3D12_DESCRIPTOR_HEAP_DESC()
        srvHeapDesc.Type <- 0
        srvHeapDesc.NumDescriptors <- 5u
        srvHeapDesc.Flags <- 1
        srvHeapDesc.NodeMask <- 0u
        let srvHeapResult = createHeap.Invoke(device, &srvHeapDesc, &heapGuid, &srvUavHeap)
        if srvHeapResult < 0 then failwithf "CreateDescriptorHeap SRV/UAV failed: %X" srvHeapResult

        let mutable rtvHandle = D3D12_CPU_DESCRIPTOR_HANDLE()
        rtvHandle.ptr <- Helpers.getCPUDescriptorHandleForHeapStart rtvHeap
        
        let getBuffer = Helpers.getVTableMethod<DelegateTypes.GetBufferDelegate> swapChain 9
        let createRTV = Helpers.getVTableMethod<DelegateTypes.CreateRenderTargetViewDelegate> device 20

        for i in 0 .. FrameCount - 1 do
            let mutable resourceGuid = Guids.IID_ID3D12Resource
            let mutable resourcePtr = IntPtr.Zero
            let bufferResult = getBuffer.Invoke(swapChain, uint32 i, &resourceGuid, &resourcePtr)
            if bufferResult < 0 then failwithf "GetBuffer failed: %X" bufferResult
            renderTargets.[i] <- resourcePtr
            createRTV.Invoke(device, resourcePtr, IntPtr.Zero, rtvHandle)
            rtvHandle.ptr <- IntPtr.Add(rtvHandle.ptr, int rtvDescriptorSize)

        let mutable allocatorGuid = Guids.IID_ID3D12CommandAllocator
        let createAllocator = Helpers.getVTableMethod<DelegateTypes.CreateCommandAllocatorDelegate> device 9
        let allocatorResult = createAllocator.Invoke(device, 0, &allocatorGuid, &commandAllocator)
        if allocatorResult < 0 then failwithf "CreateCommandAllocator graphics failed: %X" allocatorResult
        let computeAllocatorResult = createAllocator.Invoke(device, 0, &allocatorGuid, &computeCommandAllocator)
        if computeAllocatorResult < 0 then failwithf "CreateCommandAllocator compute failed: %X" computeAllocatorResult

        Marshal.Release(factory) |> ignore

    member private this.LoadAssets() =
        let createRootSignature = Helpers.getVTableMethod<DelegateTypes.CreateRootSignatureDelegate> device 16

        // Compute root signature: u0-u1 (UAV), b0 (CBV)
        let mutable uavRange = D3D12_DESCRIPTOR_RANGE()
        uavRange.RangeType <- 1
        uavRange.NumDescriptors <- 2u
        uavRange.BaseShaderRegister <- 0u
        uavRange.RegisterSpace <- 0u
        uavRange.OffsetInDescriptorsFromTableStart <- D3D12Constants.D3D12_DESCRIPTOR_RANGE_OFFSET_APPEND
        let uavRanges = [| uavRange |]
        let uavRangeHandle = GCHandle.Alloc(uavRanges, GCHandleType.Pinned)

        let mutable cbvRange = D3D12_DESCRIPTOR_RANGE()
        cbvRange.RangeType <- 2
        cbvRange.NumDescriptors <- 1u
        cbvRange.BaseShaderRegister <- 0u
        cbvRange.RegisterSpace <- 0u
        cbvRange.OffsetInDescriptorsFromTableStart <- D3D12Constants.D3D12_DESCRIPTOR_RANGE_OFFSET_APPEND
        let cbvRanges = [| cbvRange |]
        let cbvRangeHandle = GCHandle.Alloc(cbvRanges, GCHandleType.Pinned)

        let mutable computeRootParam0 = D3D12_ROOT_PARAMETER()
        let mutable computeTable0 = D3D12_ROOT_DESCRIPTOR_TABLE()
        computeTable0.NumDescriptorRanges <- 1u
        computeTable0.pDescriptorRanges <- uavRangeHandle.AddrOfPinnedObject()
        computeRootParam0.ParameterType <- 0
        computeRootParam0.DescriptorTable <- computeTable0
        computeRootParam0.ShaderVisibility <- 0

        let mutable computeRootParam1 = D3D12_ROOT_PARAMETER()
        let mutable computeTable1 = D3D12_ROOT_DESCRIPTOR_TABLE()
        computeTable1.NumDescriptorRanges <- 1u
        computeTable1.pDescriptorRanges <- cbvRangeHandle.AddrOfPinnedObject()
        computeRootParam1.ParameterType <- 0
        computeRootParam1.DescriptorTable <- computeTable1
        computeRootParam1.ShaderVisibility <- 0

        let computeRootParams = [| computeRootParam0; computeRootParam1 |]
        let computeRootParamsHandle = GCHandle.Alloc(computeRootParams, GCHandleType.Pinned)
        let mutable computeRootDesc = D3D12_ROOT_SIGNATURE_DESC()
        computeRootDesc.NumParameters <- 2u
        computeRootDesc.pParameters <- computeRootParamsHandle.AddrOfPinnedObject()
        computeRootDesc.NumStaticSamplers <- 0u
        computeRootDesc.pStaticSamplers <- IntPtr.Zero
        computeRootDesc.Flags <- 0

        let mutable computeSigBlob = IntPtr.Zero
        let mutable computeSigErr = IntPtr.Zero
        let computeSigResult = NativeMethods.D3D12SerializeRootSignature(&computeRootDesc, D3D12Constants.D3D_ROOT_SIGNATURE_VERSION_1, &computeSigBlob, &computeSigErr)
        if computeSigResult < 0 then failwithf "Serialize compute root signature failed: %X" computeSigResult

        let mutable rootSigGuid = Guids.IID_ID3D12RootSignature
        let computeRootResult = createRootSignature.Invoke(device, 0u, Helpers.getBufferPointer computeSigBlob, IntPtr(Helpers.getBlobSize computeSigBlob), &rootSigGuid, &computeRootSignature)
        if computeRootResult < 0 then failwithf "CreateRootSignature compute failed: %X" computeRootResult
        Marshal.Release(computeSigBlob) |> ignore

        // Graphics root signature: t0-t1 (SRV), b0 (CBV)
        let mutable srvRange = D3D12_DESCRIPTOR_RANGE()
        srvRange.RangeType <- 0
        srvRange.NumDescriptors <- 2u
        srvRange.BaseShaderRegister <- 0u
        srvRange.RegisterSpace <- 0u
        srvRange.OffsetInDescriptorsFromTableStart <- D3D12Constants.D3D12_DESCRIPTOR_RANGE_OFFSET_APPEND
        let srvRanges = [| srvRange |]
        let srvRangeHandle = GCHandle.Alloc(srvRanges, GCHandleType.Pinned)

        let mutable graphicsRootParam0 = D3D12_ROOT_PARAMETER()
        let mutable graphicsTable0 = D3D12_ROOT_DESCRIPTOR_TABLE()
        graphicsTable0.NumDescriptorRanges <- 1u
        graphicsTable0.pDescriptorRanges <- srvRangeHandle.AddrOfPinnedObject()
        graphicsRootParam0.ParameterType <- 0
        graphicsRootParam0.DescriptorTable <- graphicsTable0
        graphicsRootParam0.ShaderVisibility <- 1

        let mutable graphicsRootParam1 = D3D12_ROOT_PARAMETER()
        let mutable graphicsTable1 = D3D12_ROOT_DESCRIPTOR_TABLE()
        graphicsTable1.NumDescriptorRanges <- 1u
        graphicsTable1.pDescriptorRanges <- cbvRangeHandle.AddrOfPinnedObject()
        graphicsRootParam1.ParameterType <- 0
        graphicsRootParam1.DescriptorTable <- graphicsTable1
        graphicsRootParam1.ShaderVisibility <- 1

        let graphicsRootParams = [| graphicsRootParam0; graphicsRootParam1 |]
        let graphicsRootParamsHandle = GCHandle.Alloc(graphicsRootParams, GCHandleType.Pinned)
        let mutable graphicsRootDesc = D3D12_ROOT_SIGNATURE_DESC()
        graphicsRootDesc.NumParameters <- 2u
        graphicsRootDesc.pParameters <- graphicsRootParamsHandle.AddrOfPinnedObject()
        graphicsRootDesc.NumStaticSamplers <- 0u
        graphicsRootDesc.pStaticSamplers <- IntPtr.Zero
        graphicsRootDesc.Flags <- 0

        let mutable graphicsSigBlob = IntPtr.Zero
        let mutable graphicsSigErr = IntPtr.Zero
        let graphicsSigResult = NativeMethods.D3D12SerializeRootSignature(&graphicsRootDesc, D3D12Constants.D3D_ROOT_SIGNATURE_VERSION_1, &graphicsSigBlob, &graphicsSigErr)
        if graphicsSigResult < 0 then failwithf "Serialize graphics root signature failed: %X" graphicsSigResult

        let graphicsRootResult = createRootSignature.Invoke(device, 0u, Helpers.getBufferPointer graphicsSigBlob, IntPtr(Helpers.getBlobSize graphicsSigBlob), &rootSigGuid, &graphicsRootSignature)
        if graphicsRootResult < 0 then failwithf "CreateRootSignature graphics failed: %X" graphicsRootResult
        Marshal.Release(graphicsSigBlob) |> ignore

        uavRangeHandle.Free()
        cbvRangeHandle.Free()
        srvRangeHandle.Free()
        computeRootParamsHandle.Free()
        graphicsRootParamsHandle.Free()

        let computeShader = this.CompileShaderFromFile("hello.hlsl", "CSMain", "cs_5_0")
        let vertexShader = this.CompileShaderFromFile("hello.hlsl", "VSMain", "vs_5_0")
        let pixelShader = this.CompileShaderFromFile("hello.hlsl", "PSMain", "ps_5_0")
        if computeShader = IntPtr.Zero || vertexShader = IntPtr.Zero || pixelShader = IntPtr.Zero then
            failwith "Failed to compile one or more shaders"

        let mutable psoGuid = Guids.IID_ID3D12PipelineState
        let createComputePso = Helpers.getVTableMethod<DelegateTypes.CreateComputePipelineStateDelegate> device 11
        let mutable computePsoDesc = D3D12_COMPUTE_PIPELINE_STATE_DESC()
        let mutable csBytecode = D3D12_SHADER_BYTECODE()
        csBytecode.pShaderBytecode <- Helpers.getBufferPointer computeShader
        csBytecode.BytecodeLength <- IntPtr(Helpers.getBlobSize computeShader)
        computePsoDesc.pRootSignature <- computeRootSignature
        computePsoDesc.CS <- csBytecode
        let computePsoResult = createComputePso.Invoke(device, &computePsoDesc, &psoGuid, &computePipelineState)
        if computePsoResult < 0 then failwithf "CreateComputePipelineState failed: %X" computePsoResult

        let createGraphicsPso = Helpers.getVTableMethod<DelegateTypes.CreateGraphicsPipelineStateDelegate> device 10
        let mutable graphicsPsoDesc = D3D12_GRAPHICS_PIPELINE_STATE_DESC()
        let mutable vsBytecode = D3D12_SHADER_BYTECODE()
        vsBytecode.pShaderBytecode <- Helpers.getBufferPointer vertexShader
        vsBytecode.BytecodeLength <- IntPtr(Helpers.getBlobSize vertexShader)
        let mutable psBytecode = D3D12_SHADER_BYTECODE()
        psBytecode.pShaderBytecode <- Helpers.getBufferPointer pixelShader
        psBytecode.BytecodeLength <- IntPtr(Helpers.getBlobSize pixelShader)
        let mutable emptyInputLayout = D3D12_INPUT_LAYOUT_DESC()
        emptyInputLayout.pInputElementDescs <- IntPtr.Zero
        emptyInputLayout.NumElements <- 0u
        let mutable psoSampleDesc = DXGI_SAMPLE_DESC()
        psoSampleDesc.Count <- 1u
        psoSampleDesc.Quality <- 0u
        graphicsPsoDesc.pRootSignature <- graphicsRootSignature
        graphicsPsoDesc.VS <- vsBytecode
        graphicsPsoDesc.PS <- psBytecode
        graphicsPsoDesc.BlendState <- Helpers.createDefaultBlendDesc()
        graphicsPsoDesc.SampleMask <- UInt32.MaxValue
        graphicsPsoDesc.RasterizerState <- Helpers.createDefaultRasterizerDesc()
        graphicsPsoDesc.DepthStencilState <- Helpers.createDefaultDepthStencilDesc()
        graphicsPsoDesc.InputLayout <- emptyInputLayout
        graphicsPsoDesc.PrimitiveTopologyType <- 2
        graphicsPsoDesc.NumRenderTargets <- 1u
        graphicsPsoDesc.RTVFormats <- [| DXGIConstants.DXGI_FORMAT_R8G8B8A8_UNORM; 0u; 0u; 0u; 0u; 0u; 0u; 0u |]
        graphicsPsoDesc.DSVFormat <- DXGIConstants.DXGI_FORMAT_UNKNOWN
        graphicsPsoDesc.SampleDesc <- psoSampleDesc
        graphicsPsoDesc.NodeMask <- 0u
        graphicsPsoDesc.RasterizerState.CullMode <- 1
        graphicsPsoDesc.DepthStencilState.DepthEnable <- false
        let graphicsPsoResult = createGraphicsPso.Invoke(device, &graphicsPsoDesc, &psoGuid, &graphicsPipelineState)
        if graphicsPsoResult < 0 then failwithf "CreateGraphicsPipelineState failed: %X" graphicsPsoResult

        let mutable defaultHeap = D3D12_HEAP_PROPERTIES()
        defaultHeap.Type <- 1
        defaultHeap.CPUPageProperty <- 0
        defaultHeap.MemoryPoolPreference <- 0
        defaultHeap.CreationNodeMask <- 1u
        defaultHeap.VisibleNodeMask <- 1u

        let mutable uploadHeap = D3D12_HEAP_PROPERTIES()
        uploadHeap.Type <- 2
        uploadHeap.CPUPageProperty <- 0
        uploadHeap.MemoryPoolPreference <- 0
        uploadHeap.CreationNodeMask <- 1u
        uploadHeap.VisibleNodeMask <- 1u

        let mutable resourceGuid = Guids.IID_ID3D12Resource
        let createCommittedResource = Helpers.getVTableMethod<DelegateTypes.CreateCommittedResourceDelegate> device 27

        let mutable bufferDesc = D3D12_RESOURCE_DESC()
        bufferDesc.Dimension <- 1
        bufferDesc.Alignment <- 0UL
        bufferDesc.Width <- uint64 VertexCount * 16UL
        bufferDesc.Height <- 1u
        bufferDesc.DepthOrArraySize <- 1us
        bufferDesc.MipLevels <- 1us
        bufferDesc.Format <- 0u
        bufferDesc.SampleDesc <- psoSampleDesc
        bufferDesc.Layout <- 1
        bufferDesc.Flags <- 0x4

        let posResult = createCommittedResource.Invoke(device, &defaultHeap, 0, &bufferDesc, 0, IntPtr.Zero, &resourceGuid, &positionBuffer)
        if posResult < 0 then failwithf "CreateResource position failed: %X" posResult
        let colorResult = createCommittedResource.Invoke(device, &defaultHeap, 0, &bufferDesc, 0, IntPtr.Zero, &resourceGuid, &colorBuffer)
        if colorResult < 0 then failwithf "CreateResource color failed: %X" colorResult

        let mutable cbDesc = D3D12_RESOURCE_DESC()
        cbDesc.Dimension <- 1
        cbDesc.Alignment <- 0UL
        cbDesc.Width <- 256UL
        cbDesc.Height <- 1u
        cbDesc.DepthOrArraySize <- 1us
        cbDesc.MipLevels <- 1us
        cbDesc.Format <- 0u
        cbDesc.SampleDesc <- psoSampleDesc
        cbDesc.Layout <- 1
        cbDesc.Flags <- 0
        let cbResult = createCommittedResource.Invoke(device, &uploadHeap, 0, &cbDesc, 0x1 ||| 0x2 ||| 0x40 ||| 0x80 ||| 0x200 ||| 0x800, IntPtr.Zero, &resourceGuid, &constantBuffer)
        if cbResult < 0 then failwithf "CreateResource constant buffer failed: %X" cbResult

        let mutable readRange = D3D12_RANGE()
        readRange.Begin <- 0UL
        readRange.End <- 0UL
        let mutable mapped = IntPtr.Zero
        let map = Helpers.getVTableMethod<DelegateTypes.MapDelegate> constantBuffer 8
        let mapResult = map.Invoke(constantBuffer, 0u, &readRange, &mapped)
        if mapResult < 0 then failwithf "Map constant buffer failed: %X" mapResult
        constantBufferDataBegin <- mapped

        let createUAV = Helpers.getVTableMethod<DelegateTypes.CreateUnorderedAccessViewDelegate> device 19
        let createSRV = Helpers.getVTableMethod<DelegateTypes.CreateShaderResourceViewDelegate> device 18
        let createCBV = Helpers.getVTableMethod<DelegateTypes.CreateConstantBufferViewDelegate> device 17

        let mutable heapHandle = D3D12_CPU_DESCRIPTOR_HANDLE()
        heapHandle.ptr <- Helpers.getCPUDescriptorHandleForHeapStart srvUavHeap

        let mutable uavDesc = D3D12_UNORDERED_ACCESS_VIEW_DESC()
        uavDesc.Format <- 0u
        uavDesc.ViewDimension <- 1
        uavDesc.Buffer_FirstElement <- 0UL
        uavDesc.Buffer_NumElements <- VertexCount
        uavDesc.Buffer_StructureByteStride <- 16u
        uavDesc.Buffer_CounterOffsetInBytes <- 0UL
        uavDesc.Buffer_Flags <- 0
        createUAV.Invoke(device, positionBuffer, IntPtr.Zero, &uavDesc, heapHandle)
        heapHandle.ptr <- IntPtr.Add(heapHandle.ptr, int srvUavDescriptorSize)
        createUAV.Invoke(device, colorBuffer, IntPtr.Zero, &uavDesc, heapHandle)
        heapHandle.ptr <- IntPtr.Add(heapHandle.ptr, int srvUavDescriptorSize)

        let mutable srvDesc = D3D12_SHADER_RESOURCE_VIEW_DESC()
        srvDesc.Format <- 0u
        srvDesc.ViewDimension <- D3D12Constants.D3D12_SRV_DIMENSION_BUFFER
        srvDesc.Shader4ComponentMapping <- D3D12Constants.D3D12_DEFAULT_SHADER_4_COMPONENT_MAPPING
        srvDesc.Buffer_FirstElement <- 0UL
        srvDesc.Buffer_NumElements <- VertexCount
        srvDesc.Buffer_StructureByteStride <- 16u
        srvDesc.Buffer_Flags <- 0
        createSRV.Invoke(device, positionBuffer, &srvDesc, heapHandle)
        heapHandle.ptr <- IntPtr.Add(heapHandle.ptr, int srvUavDescriptorSize)
        createSRV.Invoke(device, colorBuffer, &srvDesc, heapHandle)
        heapHandle.ptr <- IntPtr.Add(heapHandle.ptr, int srvUavDescriptorSize)

        let getGPUVirtualAddress = Helpers.getVTableMethod<DelegateTypes.GetGPUVirtualAddressDelegate> constantBuffer 11
        let mutable cbvDesc = D3D12_CONSTANT_BUFFER_VIEW_DESC()
        cbvDesc.BufferLocation <- getGPUVirtualAddress.Invoke(constantBuffer)
        cbvDesc.SizeInBytes <- 256u
        createCBV.Invoke(device, &cbvDesc, heapHandle)

        let mutable cmdListGuid = Guids.IID_ID3D12GraphicsCommandList
        let createCommandList = Helpers.getVTableMethod<DelegateTypes.CreateCommandListDelegate> device 12
        let gfxCmdResult = createCommandList.Invoke(device, 0u, 0, commandAllocator, graphicsPipelineState, &cmdListGuid, &commandList)
        if gfxCmdResult < 0 then failwithf "CreateCommandList graphics failed: %X" gfxCmdResult
        let compCmdResult = createCommandList.Invoke(device, 0u, 0, computeCommandAllocator, computePipelineState, &cmdListGuid, &computeCommandList)
        if compCmdResult < 0 then failwithf "CreateCommandList compute failed: %X" compCmdResult

        let closeCmd = Helpers.getVTableMethod<DelegateTypes.CloseDelegate> commandList 9
        closeCmd.Invoke(commandList) |> ignore
        closeCmd.Invoke(computeCommandList) |> ignore

        let mutable fenceGuid = Guids.IID_ID3D12Fence
        let createFence = Helpers.getVTableMethod<DelegateTypes.CreateFenceDelegate> device 36
        let fenceResult = createFence.Invoke(device, 0UL, 0, &fenceGuid, &fence)
        if fenceResult < 0 then failwithf "CreateFence failed: %X" fenceResult
        fenceValue <- 1UL
        fenceEvent <- NativeMethods.CreateEvent(IntPtr.Zero, false, false, null)

        Marshal.Release(computeShader) |> ignore
        Marshal.Release(vertexShader) |> ignore
        Marshal.Release(pixelShader) |> ignore

    member private this.WaitForPreviousFrame() =
        let currentFenceValue = fenceValue
        let signalFunc = Helpers.getVTableMethod<DelegateTypes.SignalDelegate> commandQueue 14
        signalFunc.Invoke(commandQueue, fence, currentFenceValue) |> ignore
        fenceValue <- fenceValue + 1UL

        let getCompleted = Helpers.getVTableMethod<DelegateTypes.GetCompletedValueDelegate> fence 8
        if getCompleted.Invoke(fence) < currentFenceValue then
            let setEvent = Helpers.getVTableMethod<DelegateTypes.SetEventOnCompletionDelegate> fence 9
            setEvent.Invoke(fence, currentFenceValue, fenceEvent) |> ignore
            NativeMethods.WaitForSingleObject(fenceEvent, Win32Constants.INFINITE) |> ignore

        frameIndex <- this.GetCurrentBackBufferIndex()

    member this.Render() =
        f1 <- (f1 + (float32 (rand.NextDouble()) / 200.0f)) % 10.0f
        f2 <- (f2 + (float32 (rand.NextDouble()) / 200.0f)) % 10.0f
        p1 <- p1 + (PI2 * 0.5f / 360.0f)

        let mutable cbData = HarmonographParams()
        cbData.A1 <- A1; cbData.f1 <- f1; cbData.p1 <- p1; cbData.d1 <- d1
        cbData.A2 <- A2; cbData.f2 <- f2; cbData.p2 <- p2; cbData.d2 <- d2
        cbData.A3 <- A3; cbData.f3 <- f3; cbData.p3 <- p3; cbData.d3 <- d3
        cbData.A4 <- A4; cbData.f4 <- f4; cbData.p4 <- p4; cbData.d4 <- d4
        cbData.max_num <- VertexCount
        cbData.resolutionX <- float32 Width
        cbData.resolutionY <- float32 Height
        Marshal.StructureToPtr(cbData, constantBufferDataBegin, false)

        // Compute pass
        let resetComputeAllocator = Helpers.getVTableMethod<DelegateTypes.ResetCommandAllocatorDelegate> computeCommandAllocator 8
        resetComputeAllocator.Invoke(computeCommandAllocator) |> ignore
        let resetComputeCmdList = Helpers.getVTableMethod<DelegateTypes.ResetCommandListDelegate> computeCommandList 10
        resetComputeCmdList.Invoke(computeCommandList, computeCommandAllocator, computePipelineState) |> ignore

        let setComputeHeaps = Helpers.getVTableMethod<DelegateTypes.SetDescriptorHeapsDelegate> computeCommandList 28
        setComputeHeaps.Invoke(computeCommandList, 1u, [| srvUavHeap |])
        let setComputeRootSignature = Helpers.getVTableMethod<DelegateTypes.SetComputeRootSignatureDelegate> computeCommandList 29
        setComputeRootSignature.Invoke(computeCommandList, computeRootSignature)
        let setComputeRootDesc = Helpers.getVTableMethod<DelegateTypes.SetComputeRootDescriptorTableDelegate> computeCommandList 31
        let mutable computeGpuHandle = Helpers.getGPUDescriptorHandleForHeapStart srvUavHeap
        setComputeRootDesc.Invoke(computeCommandList, 0u, computeGpuHandle)
        computeGpuHandle.ptr <- computeGpuHandle.ptr + (uint64 srvUavDescriptorSize * 4UL)
        setComputeRootDesc.Invoke(computeCommandList, 1u, computeGpuHandle)

        let dispatch = Helpers.getVTableMethod<DelegateTypes.DispatchDelegate> computeCommandList 14
        dispatch.Invoke(computeCommandList, (VertexCount + 63u) / 64u, 1u, 1u)

        let computeBarrier = Helpers.getVTableMethod<DelegateTypes.ResourceBarrierDelegate> computeCommandList 26
        let computeToSrvBarriers = [|
            Helpers.createTransitionBarrier positionBuffer 0x8 0x40
            Helpers.createTransitionBarrier colorBuffer 0x8 0x40
        |]
        computeBarrier.Invoke(computeCommandList, 2u, computeToSrvBarriers)

        let closeCmd = Helpers.getVTableMethod<DelegateTypes.CloseDelegate> computeCommandList 9
        closeCmd.Invoke(computeCommandList) |> ignore

        let execute = Helpers.getVTableMethod<DelegateTypes.ExecuteCommandListsDelegate> commandQueue 10
        execute.Invoke(commandQueue, 1u, [| computeCommandList |])

        // Graphics pass
        let resetGraphicsAllocator = Helpers.getVTableMethod<DelegateTypes.ResetCommandAllocatorDelegate> commandAllocator 8
        resetGraphicsAllocator.Invoke(commandAllocator) |> ignore
        let resetGraphicsCmdList = Helpers.getVTableMethod<DelegateTypes.ResetCommandListDelegate> commandList 10
        resetGraphicsCmdList.Invoke(commandList, commandAllocator, graphicsPipelineState) |> ignore

        let setGraphicsHeaps = Helpers.getVTableMethod<DelegateTypes.SetDescriptorHeapsDelegate> commandList 28
        setGraphicsHeaps.Invoke(commandList, 1u, [| srvUavHeap |])
        let setGraphicsRootSignature = Helpers.getVTableMethod<DelegateTypes.SetGraphicsRootSignatureDelegate> commandList 30
        setGraphicsRootSignature.Invoke(commandList, graphicsRootSignature)
        let setGraphicsRootDesc = Helpers.getVTableMethod<DelegateTypes.SetGraphicsRootDescriptorTableDelegate> commandList 32
        let mutable graphicsGpuHandle = Helpers.getGPUDescriptorHandleForHeapStart srvUavHeap
        graphicsGpuHandle.ptr <- graphicsGpuHandle.ptr + (uint64 srvUavDescriptorSize * 2UL)
        setGraphicsRootDesc.Invoke(commandList, 0u, graphicsGpuHandle)
        graphicsGpuHandle.ptr <- graphicsGpuHandle.ptr + (uint64 srvUavDescriptorSize * 2UL)
        setGraphicsRootDesc.Invoke(commandList, 1u, graphicsGpuHandle)

        let mutable viewport = D3D12_VIEWPORT()
        viewport.TopLeftX <- 0.0f
        viewport.TopLeftY <- 0.0f
        viewport.Width <- float32 Width
        viewport.Height <- float32 Height
        viewport.MinDepth <- 0.0f
        viewport.MaxDepth <- 1.0f
        let setViewports = Helpers.getVTableMethod<DelegateTypes.RSSetViewportsDelegate> commandList 21
        setViewports.Invoke(commandList, 1u, [| viewport |])

        let mutable scissorRect = D3D12_RECT()
        scissorRect.left <- 0
        scissorRect.top <- 0
        scissorRect.right <- Width
        scissorRect.bottom <- Height
        let setScissorRects = Helpers.getVTableMethod<DelegateTypes.RSSetScissorRectsDelegate> commandList 22
        setScissorRects.Invoke(commandList, 1u, [| scissorRect |])

        let graphicsBarrier = Helpers.getVTableMethod<DelegateTypes.ResourceBarrierDelegate> commandList 26
        let barrier1 = Helpers.createTransitionBarrier renderTargets.[frameIndex] 0 4
        graphicsBarrier.Invoke(commandList, 1u, [| barrier1 |])

        let mutable rtvHandle = D3D12_CPU_DESCRIPTOR_HANDLE()
        rtvHandle.ptr <- IntPtr.Add(Helpers.getCPUDescriptorHandleForHeapStart rtvHeap, frameIndex * int rtvDescriptorSize)
        let mutable rtvHandleArray = D3D12_CPU_DESCRIPTOR_HANDLE_ARRAY()
        rtvHandleArray.ptr <- rtvHandle.ptr
        let setRenderTargets = Helpers.getVTableMethod<DelegateTypes.OMSetRenderTargetsDelegate> commandList 46
        setRenderTargets.Invoke(commandList, 1u, [| rtvHandleArray |], false, IntPtr.Zero)

        let clearRTV = Helpers.getVTableMethod<DelegateTypes.ClearRenderTargetViewDelegate> commandList 48
        clearRTV.Invoke(commandList, rtvHandle, [| 0.05f; 0.05f; 0.1f; 1.0f |], 0u, IntPtr.Zero)

        let setPrimTopo = Helpers.getVTableMethod<DelegateTypes.IASetPrimitiveTopologyDelegate> commandList 20
        setPrimTopo.Invoke(commandList, 3)

        let draw = Helpers.getVTableMethod<DelegateTypes.DrawInstancedDelegate> commandList 12
        draw.Invoke(commandList, VertexCount, 1u, 0u, 0u)

        let barrier2 = Helpers.createTransitionBarrier renderTargets.[frameIndex] 4 0
        graphicsBarrier.Invoke(commandList, 1u, [| barrier2 |])

        let graphicsToUavBarriers = [|
            Helpers.createTransitionBarrier positionBuffer 0x40 0x8
            Helpers.createTransitionBarrier colorBuffer 0x40 0x8
        |]
        graphicsBarrier.Invoke(commandList, 2u, graphicsToUavBarriers)

        closeCmd.Invoke(commandList) |> ignore
        execute.Invoke(commandQueue, 1u, [| commandList |])

        let present = Helpers.getVTableMethod<DelegateTypes.PresentDelegate> swapChain 8
        present.Invoke(swapChain, 1u, 0u) |> ignore

        this.WaitForPreviousFrame()

    member this.Cleanup() =
        NativeMethods.CloseHandle(fenceEvent) |> ignore

        if fence <> IntPtr.Zero then Marshal.Release(fence) |> ignore
        if constantBuffer <> IntPtr.Zero then Marshal.Release(constantBuffer) |> ignore
        if colorBuffer <> IntPtr.Zero then Marshal.Release(colorBuffer) |> ignore
        if positionBuffer <> IntPtr.Zero then Marshal.Release(positionBuffer) |> ignore
        if computePipelineState <> IntPtr.Zero then Marshal.Release(computePipelineState) |> ignore
        if graphicsPipelineState <> IntPtr.Zero then Marshal.Release(graphicsPipelineState) |> ignore
        if computeRootSignature <> IntPtr.Zero then Marshal.Release(computeRootSignature) |> ignore
        if graphicsRootSignature <> IntPtr.Zero then Marshal.Release(graphicsRootSignature) |> ignore
        if computeCommandList <> IntPtr.Zero then Marshal.Release(computeCommandList) |> ignore
        if commandList <> IntPtr.Zero then Marshal.Release(commandList) |> ignore
        if computeCommandAllocator <> IntPtr.Zero then Marshal.Release(computeCommandAllocator) |> ignore
        if commandAllocator <> IntPtr.Zero then Marshal.Release(commandAllocator) |> ignore
        if srvUavHeap <> IntPtr.Zero then Marshal.Release(srvUavHeap) |> ignore
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
        | msg when msg = Win32Constants.WM_DESTROY ->
            NativeMethods.PostQuitMessage(0)
            IntPtr.Zero
        | _ ->
            NativeMethods.DefWindowProc(hWnd, uMsg, wParam, lParam)

    [<EntryPoint; STAThread>]
    let main argv =
        printfn "=========================================="
        printfn "[Main] - F# DirectX 12 Compute Harmonograph Demo"
        printfn "=========================================="

        let app = HelloDX12()

        let CLASS_NAME = "MyDX12WindowClass"
        let WINDOW_NAME = "DirectX 12 Compute Harmonograph (F#)"

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
