Attribute VB_Name = "hello"
Option Explicit

' ============================================================
'  Excel VBA (64-bit) + DirectX 12 - Compute Shader Harmonograph
'   - Compute shader calculates harmonograph positions/colors
'   - Graphics shader renders the result as points
'   - Shader file: hello.hlsl (must be in same directory as Excel file)
'   - Debug log: C:\TEMP\dx12_harmonograph.log
' ============================================================

' -----------------------------
' Win32 constants
' -----------------------------
Private Const PM_REMOVE As Long = &H1&
Private Const WM_QUIT As Long = &H12&
Private Const WM_DESTROY As Long = &H2&
Private Const WM_CLOSE As Long = &H10&

Private Const CS_VREDRAW As Long = &H1&
Private Const CS_HREDRAW As Long = &H2&
Private Const CS_OWNDC As Long = &H20&

Private Const IDI_APPLICATION As Long = 32512&
Private Const IDC_ARROW As Long = 32512&

Private Const COLOR_WINDOW As Long = 5&
Private Const CW_USEDEFAULT As Long = &H80000000

Private Const WS_OVERLAPPED As Long = &H0&
Private Const WS_MAXIMIZEBOX As Long = &H10000
Private Const WS_MINIMIZEBOX As Long = &H20000
Private Const WS_THICKFRAME As Long = &H40000
Private Const WS_SYSMENU As Long = &H80000
Private Const WS_CAPTION As Long = &HC00000
Private Const WS_OVERLAPPEDWINDOW As Long = (WS_OVERLAPPED Or WS_CAPTION Or WS_SYSMENU Or WS_THICKFRAME Or WS_MINIMIZEBOX Or WS_MAXIMIZEBOX)

Private Const SW_SHOWDEFAULT As Long = 10
Private Const INFINITE As Long = &HFFFFFFFF

' -----------------------------
' DirectX 12 constants
' -----------------------------
Private Const D3D_FEATURE_LEVEL_12_0 As Long = &HC000&

Private Const DXGI_FORMAT_R8G8B8A8_UNORM As Long = 28
Private Const DXGI_FORMAT_UNKNOWN As Long = 0

Private Const DXGI_USAGE_RENDER_TARGET_OUTPUT As Long = &H20&
Private Const DXGI_SWAP_EFFECT_FLIP_DISCARD As Long = 4

Private Const D3D12_COMMAND_LIST_TYPE_DIRECT As Long = 0
Private Const D3D12_COMMAND_QUEUE_FLAG_NONE As Long = 0

Private Const D3D12_DESCRIPTOR_HEAP_TYPE_RTV As Long = 2
Private Const D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV As Long = 0
Private Const D3D12_DESCRIPTOR_HEAP_FLAG_NONE As Long = 0
Private Const D3D12_DESCRIPTOR_HEAP_FLAG_SHADER_VISIBLE As Long = 1

Private Const D3D12_HEAP_TYPE_DEFAULT As Long = 1
Private Const D3D12_HEAP_TYPE_UPLOAD As Long = 2
Private Const D3D12_HEAP_FLAG_NONE As Long = 0

Private Const D3D12_RESOURCE_STATE_COMMON As Long = 0
Private Const D3D12_RESOURCE_STATE_GENERIC_READ As Long = &H1& Or &H2& Or &H40& Or &H80& Or &H200& Or &H800&
Private Const D3D12_RESOURCE_STATE_PRESENT As Long = 0
Private Const D3D12_RESOURCE_STATE_RENDER_TARGET As Long = &H4&
Private Const D3D12_RESOURCE_STATE_UNORDERED_ACCESS As Long = &H8&
Private Const D3D12_RESOURCE_STATE_NON_PIXEL_SHADER_RESOURCE As Long = &H40&

Private Const D3D12_RESOURCE_DIMENSION_BUFFER As Long = 1
Private Const D3D12_RESOURCE_FLAG_ALLOW_UNORDERED_ACCESS As Long = &H4&

Private Const D3D12_FENCE_FLAG_NONE As Long = 0

Private Const D3D12_ROOT_SIGNATURE_FLAG_NONE As Long = 0
Private Const D3D12_ROOT_SIGNATURE_FLAG_ALLOW_INPUT_ASSEMBLER_INPUT_LAYOUT As Long = &H1&
Private Const D3D_ROOT_SIGNATURE_VERSION_1 As Long = 1

Private Const D3D12_ROOT_PARAMETER_TYPE_DESCRIPTOR_TABLE As Long = 0
Private Const D3D12_DESCRIPTOR_RANGE_TYPE_SRV As Long = 0
Private Const D3D12_DESCRIPTOR_RANGE_TYPE_UAV As Long = 1
Private Const D3D12_DESCRIPTOR_RANGE_TYPE_CBV As Long = 2
Private Const D3D12_DESCRIPTOR_RANGE_OFFSET_APPEND As Long = &HFFFFFFFF
Private Const D3D12_SHADER_VISIBILITY_ALL As Long = 0
Private Const D3D12_SHADER_VISIBILITY_VERTEX As Long = 1

Private Const D3D12_SRV_DIMENSION_BUFFER As Long = 1
Private Const D3D12_UAV_DIMENSION_BUFFER As Long = 1

Private Const D3D12_DEFAULT_SHADER_4_COMPONENT_MAPPING As Long = 5768

Private Const D3D12_FILL_MODE_SOLID As Long = 3
Private Const D3D12_CULL_MODE_NONE As Long = 1

Private Const D3D12_PRIMITIVE_TOPOLOGY_TYPE_POINT As Long = 1
Private Const D3D_PRIMITIVE_TOPOLOGY_POINTLIST As Long = 1

Private Const D3D12_RESOURCE_BARRIER_TYPE_TRANSITION As Long = 0
Private Const D3D12_RESOURCE_BARRIER_FLAG_NONE As Long = 0
Private Const D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES As Long = &HFFFFFFFF

Private Const D3D12_BLEND_ONE As Long = 2
Private Const D3D12_BLEND_ZERO As Long = 1
Private Const D3D12_BLEND_OP_ADD As Long = 1
Private Const D3D12_LOGIC_OP_NOOP As Long = 5
Private Const D3D12_COLOR_WRITE_ENABLE_ALL As Long = 15

Private Const D3DCOMPILE_ENABLE_STRICTNESS As Long = &H800&

Private Const FRAME_COUNT As Long = 2
Private Const Width As Long = 800
Private Const Height As Long = 600
Private Const VERTEX_COUNT As Long = 100000

' -----------------------------
' vtable indices
' -----------------------------
' IUnknown
Private Const ONVTBL_IUnknown_QueryInterface As Long = 0
Private Const ONVTBL_IUnknown_AddRef As Long = 1
Private Const ONVTBL_IUnknown_Release As Long = 2

' ID3D12Device
Private Const VTBL_Device_CreateCommandQueue As Long = 8
Private Const VTBL_Device_CreateCommandAllocator As Long = 9
Private Const VTBL_Device_CreateGraphicsPipelineState As Long = 10
Private Const VTBL_Device_CreateComputePipelineState As Long = 11
Private Const VTBL_Device_CreateCommandList As Long = 12
Private Const VTBL_Device_CreateDescriptorHeap As Long = 14
Private Const VTBL_Device_GetDescriptorHandleIncrementSize As Long = 15
Private Const VTBL_Device_CreateRootSignature As Long = 16
Private Const VTBL_Device_CreateConstantBufferView As Long = 17
Private Const VTBL_Device_CreateShaderResourceView As Long = 18
Private Const VTBL_Device_CreateUnorderedAccessView As Long = 19
Private Const VTBL_Device_CreateRenderTargetView As Long = 20
Private Const VTBL_Device_CreateCommittedResource As Long = 27
Private Const VTBL_Device_CreateFence As Long = 36

' ID3D12DescriptorHeap
Private Const VTBL_DescHeap_GetCPUDescriptorHandleForHeapStart As Long = 9
Private Const VTBL_DescHeap_GetGPUDescriptorHandleForHeapStart As Long = 10

' ID3D12GraphicsCommandList
Private Const VTBL_CmdList_Close As Long = 9
Private Const VTBL_CmdList_Reset As Long = 10
Private Const VTBL_CmdList_DrawInstanced As Long = 12
Private Const VTBL_CmdList_Dispatch As Long = 14
Private Const VTBL_CmdList_IASetPrimitiveTopology As Long = 20
Private Const VTBL_CmdList_RSSetViewports As Long = 21
Private Const VTBL_CmdList_RSSetScissorRects As Long = 22
Private Const VTBL_CmdList_SetPipelineState As Long = 25
Private Const VTBL_CmdList_ResourceBarrier As Long = 26
Private Const VTBL_CmdList_SetDescriptorHeaps As Long = 28
Private Const VTBL_CmdList_SetComputeRootSignature As Long = 29
Private Const VTBL_CmdList_SetGraphicsRootSignature As Long = 30
Private Const VTBL_CmdList_SetComputeRootDescriptorTable As Long = 31
Private Const VTBL_CmdList_SetGraphicsRootDescriptorTable As Long = 32
Private Const VTBL_CmdList_OMSetRenderTargets As Long = 46
Private Const VTBL_CmdList_ClearRenderTargetView As Long = 48

' ID3D12CommandQueue
Private Const VTBL_CmdQueue_ExecuteCommandLists As Long = 10
Private Const VTBL_CmdQueue_Signal As Long = 14

' ID3D12Fence
Private Const VTBL_Fence_GetCompletedValue As Long = 8
Private Const VTBL_Fence_SetEventOnCompletion As Long = 9

' ID3D12CommandAllocator
Private Const VTBL_CmdAlloc_Reset As Long = 8

' ID3D12Resource
Private Const VTBL_Resource_Map As Long = 8
Private Const VTBL_Resource_Unmap As Long = 9
Private Const VTBL_Resource_GetGPUVirtualAddress As Long = 11

' IDXGISwapChain
Private Const VTBL_SwapChain_Present As Long = 8
Private Const VTBL_SwapChain_GetBuffer As Long = 9

' IDXGISwapChain3
Private Const VTBL_SwapChain3_GetCurrentBackBufferIndex As Long = 36

' IDXGIFactory
Private Const VTBL_Factory_CreateSwapChain As Long = 10

' ID3DBlob
Private Const VTBL_Blob_GetBufferPointer As Long = 3
Private Const VTBL_Blob_GetBufferSize As Long = 4

' -----------------------------
' Class / window names
' -----------------------------
Private Const CLASS_NAME As String = "HarmonographDX12VBA"
Private Const WINDOW_NAME As String = "DirectX 12 Compute Harmonograph (VBA64)"

' -----------------------------
' Types - GUID
' -----------------------------
Private Type GUID
    Data1 As Long
    Data2 As Integer
    Data3 As Integer
    Data4(0 To 7) As Byte
End Type

' -----------------------------
' Types - Win32
' -----------------------------
Private Type POINTAPI
    x As Long
    y As Long
End Type

Private Type MSGW
    hWnd As LongPtr
    message As Long
    wParam As LongPtr
    lParam As LongPtr
    time As Long
    pt As POINTAPI
End Type

Private Type WNDCLASSEXW
    cbSize As Long
    style As Long
    lpfnWndProc As LongPtr
    cbClsExtra As Long
    cbWndExtra As Long
    hInstance As LongPtr
    hIcon As LongPtr
    hCursor As LongPtr
    hbrBackground As LongPtr
    lpszMenuName As LongPtr
    lpszClassName As LongPtr
    hIconSm As LongPtr
End Type

Private Type RECT
    Left As Long
    Top As Long
    Right As Long
    Bottom As Long
End Type

' -----------------------------
' Types - DXGI
' -----------------------------
Private Type DXGI_RATIONAL
    Numerator As Long
    Denominator As Long
End Type

Private Type DXGI_MODE_DESC
    Width As Long
    Height As Long
    RefreshRate As DXGI_RATIONAL
    Format As Long
    ScanlineOrdering As Long
    Scaling As Long
End Type

Private Type DXGI_SAMPLE_DESC
    count As Long
    Quality As Long
End Type

Private Type DXGI_SWAP_CHAIN_DESC
    bufferDesc As DXGI_MODE_DESC
    SampleDesc As DXGI_SAMPLE_DESC
    BufferUsage As Long
    BufferCount As Long
    OutputWindow As LongPtr
    Windowed As Long
    SwapEffect As Long
    Flags As Long
End Type

' -----------------------------
' Types - D3D12
' -----------------------------
Private Type D3D12_COMMAND_QUEUE_DESC
    cType As Long
    Priority As Long
    Flags As Long
    NodeMask As Long
End Type

Private Type D3D12_DESCRIPTOR_HEAP_DESC
    cType As Long
    NumDescriptors As Long
    Flags As Long
    NodeMask As Long
End Type

Private Type D3D12_CPU_DESCRIPTOR_HANDLE
    ptr As LongPtr
End Type

Private Type D3D12_GPU_DESCRIPTOR_HANDLE
    ptr As LongLong
End Type

Private Type D3D12_HEAP_PROPERTIES
    cType As Long
    CPUPageProperty As Long
    MemoryPoolPreference As Long
    CreationNodeMask As Long
    VisibleNodeMask As Long
End Type

Private Type D3D12_RESOURCE_DESC
    Dimension As Long
    Alignment As LongLong
    Width As LongLong
    Height As Long
    DepthOrArraySize As Integer
    MipLevels As Integer
    Format As Long
    SampleDesc As DXGI_SAMPLE_DESC
    Layout As Long
    Flags As Long
End Type

Private Type D3D12_DESCRIPTOR_RANGE
    RangeType As Long
    NumDescriptors As Long
    BaseShaderRegister As Long
    RegisterSpace As Long
    OffsetInDescriptorsFromTableStart As Long
End Type

Private Type D3D12_ROOT_DESCRIPTOR_TABLE
    NumDescriptorRanges As Long
    pDescriptorRanges As LongPtr
End Type

Private Type D3D12_ROOT_PARAMETER
    ParameterType As Long
    DescriptorTable As D3D12_ROOT_DESCRIPTOR_TABLE
    ShaderVisibility As Long
End Type

Private Type D3D12_ROOT_SIGNATURE_DESC
    NumParameters As Long
    pParameters As LongPtr
    NumStaticSamplers As Long
    pStaticSamplers As LongPtr
    Flags As Long
End Type

Private Type D3D12_SHADER_BYTECODE
    pShaderBytecode As LongPtr
    BytecodeLength As LongPtr
End Type

Private Type D3D12_COMPUTE_PIPELINE_STATE_DESC
    pRootSignature As LongPtr
    CS As D3D12_SHADER_BYTECODE
    NodeMask As Long
    CachedPSO_pCachedBlob As LongPtr
    CachedPSO_CachedBlobSizeInBytes As LongPtr
    Flags As Long
End Type

Private Type D3D12_INPUT_LAYOUT_DESC
    pInputElementDescs As LongPtr
    NumElements As Long
End Type

Private Type D3D12_RENDER_TARGET_BLEND_DESC
    BlendEnable As Long
    LogicOpEnable As Long
    SrcBlend As Long
    DestBlend As Long
    BlendOp As Long
    SrcBlendAlpha As Long
    DestBlendAlpha As Long
    BlendOpAlpha As Long
    LogicOp As Long
    RenderTargetWriteMask As Byte
    padding1 As Byte
    padding2 As Byte
    padding3 As Byte
End Type

Private Type D3D12_BLEND_DESC
    AlphaToCoverageEnable As Long
    IndependentBlendEnable As Long
    RenderTarget(0 To 7) As D3D12_RENDER_TARGET_BLEND_DESC
End Type

Private Type D3D12_RASTERIZER_DESC
    FillMode As Long
    CullMode As Long
    FrontCounterClockwise As Long
    DepthBias As Long
    DepthBiasClamp As Single
    SlopeScaledDepthBias As Single
    DepthClipEnable As Long
    MultisampleEnable As Long
    AntialiasedLineEnable As Long
    ForcedSampleCount As Long
    ConservativeRaster As Long
End Type

Private Type D3D12_DEPTH_STENCILOP_DESC
    StencilFailOp As Long
    StencilDepthFailOp As Long
    StencilPassOp As Long
    StencilFunc As Long
End Type

Private Type D3D12_DEPTH_STENCIL_DESC
    DepthEnable As Long
    DepthWriteMask As Long
    DepthFunc As Long
    StencilEnable As Long
    StencilReadMask As Byte
    StencilWriteMask As Byte
    padding1 As Byte
    padding2 As Byte
    FrontFace As D3D12_DEPTH_STENCILOP_DESC
    BackFace As D3D12_DEPTH_STENCILOP_DESC
End Type

Private Type D3D12_STREAM_OUTPUT_DESC
    pSODeclaration As LongPtr
    NumEntries As Long
    pBufferStrides As LongPtr
    NumStrides As Long
    RasterizedStream As Long
End Type

Private Type D3D12_CACHED_PIPELINE_STATE
    pCachedBlob As LongPtr
    CachedBlobSizeInBytes As LongPtr
End Type

Private Type D3D12_GRAPHICS_PIPELINE_STATE_DESC
    pRootSignature As LongPtr
    VS As D3D12_SHADER_BYTECODE
    PS As D3D12_SHADER_BYTECODE
    DS As D3D12_SHADER_BYTECODE
    HS As D3D12_SHADER_BYTECODE
    GS As D3D12_SHADER_BYTECODE
    StreamOutput As D3D12_STREAM_OUTPUT_DESC
    BlendState As D3D12_BLEND_DESC
    SampleMask As Long
    RasterizerState As D3D12_RASTERIZER_DESC
    DepthStencilState As D3D12_DEPTH_STENCIL_DESC
    InputLayout As D3D12_INPUT_LAYOUT_DESC
    IBStripCutValue As Long
    PrimitiveTopologyType As Long
    NumRenderTargets As Long
    RTVFormats(0 To 7) As Long
    DSVFormat As Long
    SampleDesc As DXGI_SAMPLE_DESC
    NodeMask As Long
    CachedPSO As D3D12_CACHED_PIPELINE_STATE
    Flags As Long
End Type

Private Type D3D12_VIEWPORT
    TopLeftX As Single
    TopLeftY As Single
    Width As Single
    Height As Single
    MinDepth As Single
    MaxDepth As Single
End Type

Private Type D3D12_RECT
    Left As Long
    Top As Long
    Right As Long
    Bottom As Long
End Type

Private Type D3D12_RESOURCE_TRANSITION_BARRIER
    pResource As LongPtr
    Subresource As Long
    StateBefore As Long
    StateAfter As Long
End Type

Private Type D3D12_RESOURCE_BARRIER
    cType As Long
    Flags As Long
    Transition As D3D12_RESOURCE_TRANSITION_BARRIER
End Type

Private Type D3D12_RANGE
    BeginOffset As LongPtr
    EndOffset As LongPtr
End Type

Private Type D3D12_UNORDERED_ACCESS_VIEW_DESC
    Format As Long
    ViewDimension As Long
    Buffer_FirstElement As LongLong
    Buffer_NumElements As Long
    Buffer_StructureByteStride As Long
    Buffer_CounterOffsetInBytes As LongLong
    Buffer_Flags As Long
End Type

Private Type D3D12_SHADER_RESOURCE_VIEW_DESC
    Format As Long
    ViewDimension As Long
    Shader4ComponentMapping As Long
    Buffer_FirstElement As LongLong
    Buffer_NumElements As Long
    Buffer_StructureByteStride As Long
    Buffer_Flags As Long
End Type

Private Type D3D12_CONSTANT_BUFFER_VIEW_DESC
    BufferLocation As LongLong
    SizeInBytes As Long
End Type

' Harmonograph parameters (must match HLSL)
Private Type HarmonographParams
    a1 As Single: f1 As Single: p1 As Single: d1 As Single
    a2 As Single: f2 As Single: p2 As Single: d2 As Single
    a3 As Single: f3 As Single: p3 As Single: d3 As Single
    a4 As Single: f4 As Single: p4 As Single: d4 As Single
    max_num As Long
    time As Single       ' Animation time
    padding2 As Single: padding3 As Single
    resolutionX As Single: resolutionY As Single
    padding4 As Single: padding5 As Single
End Type

' -----------------------------
' Thunk argument structures
' -----------------------------
Private Type ThunkArgs1
    a1 As LongPtr
End Type

Private Type ThunkArgs2
    a1 As LongPtr
    a2 As LongPtr
End Type

Private Type ThunkArgs3
    a1 As LongPtr
    a2 As LongPtr
    a3 As LongPtr
End Type

Private Type ThunkArgs4
    a1 As LongPtr
    a2 As LongPtr
    a3 As LongPtr
    a4 As LongPtr
End Type

Private Type ThunkArgs5
    a1 As LongPtr
    a2 As LongPtr
    a3 As LongPtr
    a4 As LongPtr
    a5 As LongPtr
End Type

Private Type ThunkArgs6
    a1 As LongPtr
    a2 As LongPtr
    a3 As LongPtr
    a4 As LongPtr
    a5 As LongPtr
    a6 As LongPtr
End Type

Private Type ThunkArgs7
    a1 As LongPtr
    a2 As LongPtr
    a3 As LongPtr
    a4 As LongPtr
    a5 As LongPtr
    a6 As LongPtr
    a7 As LongPtr
End Type

Private Type ThunkArgs8
    a1 As LongPtr
    a2 As LongPtr
    a3 As LongPtr
    a4 As LongPtr
    a5 As LongPtr
    a6 As LongPtr
    a7 As LongPtr
    a8 As LongPtr
End Type

Private Type ThunkArgs9
    a1 As LongPtr
    a2 As LongPtr
    a3 As LongPtr
    a4 As LongPtr
    a5 As LongPtr
    a6 As LongPtr
    a7 As LongPtr
    a8 As LongPtr
    a9 As LongPtr
End Type

' -----------------------------
' Globals
' -----------------------------
Private g_hWnd As LongPtr

' D3D12 objects
Private g_pDevice As LongPtr
Private g_pCommandQueue As LongPtr
Private g_pSwapChain As LongPtr
Private g_pSwapChain3 As LongPtr
Private g_pRtvHeap As LongPtr
Private g_pSrvUavHeap As LongPtr
Private g_pGraphicsCommandList As LongPtr

Private g_pCommandAllocators(0 To FRAME_COUNT - 1) As LongPtr
Private g_fenceValues(0 To FRAME_COUNT - 1) As LongLong

Private g_pComputeRootSignature As LongPtr
Private g_pGraphicsRootSignature As LongPtr
Private g_pComputePipelineState As LongPtr
Private g_pGraphicsPipelineState As LongPtr
Private g_pFence As LongPtr
Private g_fenceEvent As LongPtr
Private g_fenceValue As LongLong
Private g_frameIndex As Long
Private g_rtvDescriptorSize As Long
Private g_srvUavDescriptorSize As Long
Private g_pRenderTargets(0 To FRAME_COUNT - 1) As LongPtr

' Buffers
Private g_pPositionBuffer As LongPtr
Private g_pColorBuffer As LongPtr
Private g_pConstantBuffer As LongPtr
Private g_pConstantBufferPtr As LongPtr

' Shader path
Private g_shaderPath As String

' Logger
Private g_log As LongPtr
Private Const GENERIC_WRITE As Long = &H40000000
Private Const FILE_SHARE_READ As Long = &H1
Private Const FILE_SHARE_WRITE As Long = &H2
Private Const CREATE_ALWAYS As Long = 2
Private Const FILE_ATTRIBUTE_NORMAL As Long = &H80

' Thunk memory
Private Const MEM_COMMIT As Long = &H1000&
Private Const MEM_RESERVE As Long = &H2000&
Private Const MEM_RELEASE As Long = &H8000&
Private Const PAGE_EXECUTE_READWRITE As Long = &H40&

' Thunk cache - store up to 64 thunks per argument count
Private Type ThunkCache
    targets(0 To 63) As LongPtr
    thunks(0 To 63) As LongPtr
    count As Long
End Type

Private g_thunkCache1 As ThunkCache
Private g_thunkCache2 As ThunkCache
Private g_thunkCache3 As ThunkCache
Private g_thunkCache4 As ThunkCache
Private g_thunkCache5 As ThunkCache
Private g_thunkCache6 As ThunkCache
Private g_thunkCache7 As ThunkCache
Private g_thunkCache8 As ThunkCache
Private g_thunkCache9 As ThunkCache
Private g_thunkCacheRetStruct As ThunkCache

' Animation
Private g_startTime As Double
Private g_frameCount As Long

#If VBA7 Then
    ' Win32
    Private Declare PtrSafe Function GetModuleHandleW Lib "kernel32" (ByVal lpModuleName As LongPtr) As LongPtr
    Private Declare PtrSafe Function LoadIconW Lib "user32" (ByVal hInstance As LongPtr, ByVal lpIconName As LongPtr) As LongPtr
    Private Declare PtrSafe Function LoadCursorW Lib "user32" (ByVal hInstance As LongPtr, ByVal lpCursorName As LongPtr) As LongPtr

    Private Declare PtrSafe Function RegisterClassExW Lib "user32" (ByRef lpwcx As WNDCLASSEXW) As Integer
    Private Declare PtrSafe Function CreateWindowExW Lib "user32" ( _
        ByVal dwExStyle As Long, _
        ByVal lpClassName As LongPtr, _
        ByVal lpWindowName As LongPtr, _
        ByVal dwStyle As Long, _
        ByVal x As Long, ByVal y As Long, _
        ByVal nWidth As Long, ByVal nHeight As Long, _
        ByVal hWndParent As LongPtr, _
        ByVal hMenu As LongPtr, _
        ByVal hInstance As LongPtr, _
        ByVal lpParam As LongPtr) As LongPtr

    Private Declare PtrSafe Function ShowWindow Lib "user32" (ByVal hWnd As LongPtr, ByVal nCmdShow As Long) As Long
    Private Declare PtrSafe Function UpdateWindow Lib "user32" (ByVal hWnd As LongPtr) As Long
    Private Declare PtrSafe Function DestroyWindow Lib "user32" (ByVal hWnd As LongPtr) As Long

    Private Declare PtrSafe Function PeekMessageW Lib "user32" ( _
        ByRef lpMsg As MSGW, ByVal hWnd As LongPtr, _
        ByVal wMsgFilterMin As Long, ByVal wMsgFilterMax As Long, _
        ByVal wRemoveMsg As Long) As Long

    Private Declare PtrSafe Function TranslateMessage Lib "user32" (ByRef lpMsg As MSGW) As Long
    Private Declare PtrSafe Function DispatchMessageW Lib "user32" (ByRef lpMsg As MSGW) As LongPtr
    Private Declare PtrSafe Sub PostQuitMessage Lib "user32" (ByVal nExitCode As Long)
    Private Declare PtrSafe Function DefWindowProcW Lib "user32" (ByVal hWnd As LongPtr, ByVal uMsg As Long, ByVal wParam As LongPtr, ByVal lParam As LongPtr) As LongPtr

    ' Event
    Private Declare PtrSafe Function CreateEventW Lib "kernel32" ( _
        ByVal lpEventAttributes As LongPtr, _
        ByVal bManualReset As Long, _
        ByVal bInitialState As Long, _
        ByVal lpName As LongPtr) As LongPtr
    Private Declare PtrSafe Function WaitForSingleObject Lib "kernel32" (ByVal hHandle As LongPtr, ByVal dwMilliseconds As Long) As Long
    Private Declare PtrSafe Function CloseHandle Lib "kernel32" (ByVal hObject As LongPtr) As Long

    ' Generic caller
    Private Declare PtrSafe Function CallWindowProcW Lib "user32" ( _
        ByVal lpPrevWndFunc As LongPtr, _
        ByVal hWnd As LongPtr, _
        ByVal msg As LongPtr, _
        ByVal wParam As LongPtr, _
        ByVal lParam As LongPtr) As LongPtr

    ' DirectX 12
    Private Declare PtrSafe Function D3D12CreateDevice Lib "d3d12.dll" ( _
        ByVal pAdapter As LongPtr, _
        ByVal MinimumFeatureLevel As Long, _
        ByRef riid As GUID, _
        ByRef ppDevice As LongPtr) As Long

    Private Declare PtrSafe Function CreateDXGIFactory1 Lib "dxgi.dll" ( _
        ByRef riid As GUID, _
        ByRef ppFactory As LongPtr) As Long

    Private Declare PtrSafe Function D3D12SerializeRootSignature Lib "d3d12.dll" ( _
        ByRef pRootSignature As D3D12_ROOT_SIGNATURE_DESC, _
        ByVal Version As Long, _
        ByRef ppBlob As LongPtr, _
        ByRef ppErrorBlob As LongPtr) As Long

    ' D3DCompiler
    Private Declare PtrSafe Function GetProcAddress Lib "kernel32" (ByVal hModule As LongPtr, ByVal lpProcName As LongPtr) As LongPtr
    Private Declare PtrSafe Function LoadLibraryW Lib "kernel32" (ByVal lpLibFileName As LongPtr) As LongPtr
    Private Declare PtrSafe Function FreeLibrary Lib "kernel32" (ByVal hLibModule As LongPtr) As Long

    ' Memory utils
    Private Declare PtrSafe Function CreateDirectoryW Lib "kernel32" (ByVal lpPathName As LongPtr, ByVal lpSecurityAttributes As LongPtr) As Long
    Private Declare PtrSafe Function CreateFileW Lib "kernel32" ( _
        ByVal lpFileName As LongPtr, _
        ByVal dwDesiredAccess As Long, _
        ByVal dwShareMode As Long, _
        ByVal lpSecurityAttributes As LongPtr, _
        ByVal dwCreationDisposition As Long, _
        ByVal dwFlagsAndAttributes As Long, _
        ByVal hTemplateFile As LongPtr) As LongPtr

    Private Declare PtrSafe Function WriteFile Lib "kernel32" ( _
        ByVal hFile As LongPtr, _
        ByRef lpBuffer As Any, _
        ByVal nNumberOfBytesToWrite As Long, _
        ByRef lpNumberOfBytesWritten As Long, _
        ByVal lpOverlapped As LongPtr) As Long

    Private Declare PtrSafe Function FlushFileBuffers Lib "kernel32" (ByVal hFile As LongPtr) As Long

    Private Declare PtrSafe Function lstrlenA Lib "kernel32" (ByVal lpString As LongPtr) As Long
    Private Declare PtrSafe Sub RtlMoveMemory Lib "kernel32" (ByRef Destination As Any, ByVal Source As LongPtr, ByVal Length As Long)
    Private Declare PtrSafe Sub RtlMoveMemoryFromPtr Lib "kernel32" Alias "RtlMoveMemory" (ByVal Destination As LongPtr, ByRef Source As Any, ByVal Length As Long)
    Private Declare PtrSafe Sub CopyMemory Lib "kernel32" Alias "RtlMoveMemory" (ByVal Destination As LongPtr, ByVal Source As LongPtr, ByVal Length As LongPtr)

    Private Declare PtrSafe Function VirtualAlloc Lib "kernel32" (ByVal lpAddress As LongPtr, ByVal dwSize As LongPtr, ByVal flAllocationType As Long, ByVal flProtect As Long) As LongPtr
    Private Declare PtrSafe Function VirtualFree Lib "kernel32" (ByVal lpAddress As LongPtr, ByVal dwSize As LongPtr, ByVal dwFreeType As Long) As Long
#End If

' ============================================================
' Logger
' ============================================================
Private Sub LogOpen()
    On Error Resume Next
    CreateDirectoryW StrPtr("C:\TEMP"), 0
    g_log = CreateFileW(StrPtr("C:\TEMP\dx12_harmonograph.log"), GENERIC_WRITE, FILE_SHARE_READ Or FILE_SHARE_WRITE, 0, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, 0)
    If g_log = 0 Or g_log = -1 Then g_log = 0
    LogMsg "==== DX12 HARMONOGRAPH LOG START ===="
End Sub

Private Sub LogClose()
    On Error Resume Next
    If g_log <> 0 Then
        LogMsg "==== DX12 HARMONOGRAPH LOG END ===="
        CloseHandle g_log
        g_log = 0
    End If
End Sub

Private Sub LogMsg(ByVal s As String)
    On Error Resume Next
    If g_log = 0 Then Exit Sub

    Dim line As String
    line = Format$(Now, "yyyy-mm-dd hh:nn:ss.000") & " | " & s & vbCrLf

    Dim b() As Byte
    b = StrConv(line, vbFromUnicode)

    Dim written As Long
    WriteFile g_log, b(0), UBound(b) + 1, written, 0
    FlushFileBuffers g_log
End Sub

' ============================================================
' Helpers
' ============================================================
Private Function AnsiZBytes(ByVal s As String) As Byte()
    AnsiZBytes = StrConv(s & vbNullChar, vbFromUnicode)
End Function

Private Function PtrToAnsiString(ByVal p As LongPtr) As String
    If p = 0 Then PtrToAnsiString = "": Exit Function
    Dim n As Long: n = lstrlenA(p)
    If n <= 0 Then PtrToAnsiString = "": Exit Function
    Dim b() As Byte
    ReDim b(0 To n - 1) As Byte
    RtlMoveMemory b(0), p, n
    PtrToAnsiString = StrConv(b, vbUnicode)
End Function

Private Function ToHResult(ByVal v As LongPtr) As Long
    If v >= 0 And v <= &H7FFFFFFF Then
        ToHResult = CLng(v)
    Else
        Dim lo As Long
        CopyMemory VarPtr(lo), VarPtr(v), 4
        ToHResult = lo
    End If
End Function

' ============================================================
' GUID helpers
' ============================================================
Private Function IID_IDXGIFactory1() As GUID
    With IID_IDXGIFactory1
        .Data1 = &H770AAE78: .Data2 = &HF26F: .Data3 = &H4DBA
        .Data4(0) = &HA8: .Data4(1) = &H29: .Data4(2) = &H25: .Data4(3) = &H3C
        .Data4(4) = &H83: .Data4(5) = &HD1: .Data4(6) = &HB3: .Data4(7) = &H87
    End With
End Function

Private Function IID_ID3D12Device() As GUID
    With IID_ID3D12Device
        .Data1 = &H189819F1: .Data2 = &H1DB6: .Data3 = &H4B57
        .Data4(0) = &HBE: .Data4(1) = &H54: .Data4(2) = &H18: .Data4(3) = &H21
        .Data4(4) = &H33: .Data4(5) = &H9B: .Data4(6) = &H85: .Data4(7) = &HF7
    End With
End Function

Private Function IID_ID3D12CommandQueue() As GUID
    With IID_ID3D12CommandQueue
        .Data1 = &HEC870A6: .Data2 = &H5D7E: .Data3 = &H4C22
        .Data4(0) = &H8C: .Data4(1) = &HFC: .Data4(2) = &H5B: .Data4(3) = &HAA
        .Data4(4) = &HE0: .Data4(5) = &H76: .Data4(6) = &H16: .Data4(7) = &HED
    End With
End Function

Private Function IID_ID3D12DescriptorHeap() As GUID
    With IID_ID3D12DescriptorHeap
        .Data1 = &H8EFB471D: .Data2 = &H616C: .Data3 = &H4F49
        .Data4(0) = &H90: .Data4(1) = &HF7: .Data4(2) = &H12: .Data4(3) = &H7B
        .Data4(4) = &HB7: .Data4(5) = &H63: .Data4(6) = &HFA: .Data4(7) = &H51
    End With
End Function

Private Function IID_ID3D12Resource() As GUID
    With IID_ID3D12Resource
        .Data1 = &H696442BE: .Data2 = &HA72E: .Data3 = &H4059
        .Data4(0) = &HBC: .Data4(1) = &H79: .Data4(2) = &H5B: .Data4(3) = &H5C
        .Data4(4) = &H98: .Data4(5) = &H4: .Data4(6) = &HF: .Data4(7) = &HAD
    End With
End Function

Private Function IID_ID3D12CommandAllocator() As GUID
    With IID_ID3D12CommandAllocator
        .Data1 = &H6102DEE4: .Data2 = &HAF59: .Data3 = &H4B09
        .Data4(0) = &HB9: .Data4(1) = &H99: .Data4(2) = &HB4: .Data4(3) = &H4D
        .Data4(4) = &H73: .Data4(5) = &HF0: .Data4(6) = &H9B: .Data4(7) = &H24
    End With
End Function

Private Function IID_ID3D12RootSignature() As GUID
    With IID_ID3D12RootSignature
        .Data1 = &HC54A6B66: .Data2 = &H72DF: .Data3 = &H4EE8
        .Data4(0) = &H8B: .Data4(1) = &HE5: .Data4(2) = &HA9: .Data4(3) = &H46
        .Data4(4) = &HA1: .Data4(5) = &H42: .Data4(6) = &H92: .Data4(7) = &H14
    End With
End Function

Private Function IID_ID3D12PipelineState() As GUID
    With IID_ID3D12PipelineState
        .Data1 = &H765A30F3: .Data2 = &HF624: .Data3 = &H4C6F
        .Data4(0) = &HA8: .Data4(1) = &H28: .Data4(2) = &HAC: .Data4(3) = &HE9
        .Data4(4) = &H48: .Data4(5) = &H62: .Data4(6) = &H24: .Data4(7) = &H45
    End With
End Function

Private Function IID_ID3D12GraphicsCommandList() As GUID
    With IID_ID3D12GraphicsCommandList
        .Data1 = &H5B160D0F: .Data2 = &HAC1B: .Data3 = &H4185
        .Data4(0) = &H8B: .Data4(1) = &HA8: .Data4(2) = &HB3: .Data4(3) = &HAE
        .Data4(4) = &H42: .Data4(5) = &HA5: .Data4(6) = &HA4: .Data4(7) = &H55
    End With
End Function

Private Function IID_ID3D12Fence() As GUID
    With IID_ID3D12Fence
        .Data1 = &HA753DCF: .Data2 = &HC4D8: .Data3 = &H4B91
        .Data4(0) = &HAD: .Data4(1) = &HF6: .Data4(2) = &HBE: .Data4(3) = &H5A
        .Data4(4) = &H60: .Data4(5) = &HD9: .Data4(6) = &H5A: .Data4(7) = &H76
    End With
End Function

Private Function IID_IDXGISwapChain3() As GUID
    With IID_IDXGISwapChain3
        .Data1 = &H94D99BDB: .Data2 = &HF1F8: .Data3 = &H4AB0
        .Data4(0) = &HB2: .Data4(1) = &H36: .Data4(2) = &H7D: .Data4(3) = &HA0
        .Data4(4) = &H17: .Data4(5) = &HE: .Data4(6) = &HDA: .Data4(7) = &HB1
    End With
End Function

' ============================================================
' COM vtable helpers
' ============================================================
Private Function GetVTableMethod(ByVal pObj As LongPtr, ByVal vtIndex As Long) As LongPtr
    Dim vtable As LongPtr
    Dim methodAddr As LongPtr
    Dim offset As LongPtr
    
    CopyMemory VarPtr(vtable), pObj, 8
    offset = CLngPtr(vtIndex) * 8
    CopyMemory VarPtr(methodAddr), vtable + offset, 8
    
    GetVTableMethod = methodAddr
End Function

' ============================================================
' Thunk builders
' ============================================================
Private Function BuildThunk1(ByVal target As LongPtr) As LongPtr
    Dim code(0 To 39) As Byte
    Dim i As Long: i = 0
    
    code(i) = &H48: i = i + 1: code(i) = &H83: i = i + 1: code(i) = &HEC: i = i + 1: code(i) = &H28: i = i + 1
    code(i) = &H4D: i = i + 1: code(i) = &H89: i = i + 1: code(i) = &HC2: i = i + 1
    code(i) = &H49: i = i + 1: code(i) = &H8B: i = i + 1: code(i) = &HA: i = i + 1
    code(i) = &H48: i = i + 1: code(i) = &HB8: i = i + 1
    Dim t As LongLong: t = target
    RtlMoveMemoryFromPtr VarPtr(code(i)), t, 8: i = i + 8
    code(i) = &HFF: i = i + 1: code(i) = &HD0: i = i + 1
    code(i) = &H48: i = i + 1: code(i) = &H83: i = i + 1: code(i) = &HC4: i = i + 1: code(i) = &H28: i = i + 1
    code(i) = &HC3
    
    Dim mem As LongPtr
    mem = VirtualAlloc(0, 64, MEM_COMMIT Or MEM_RESERVE, PAGE_EXECUTE_READWRITE)
    If mem = 0 Then Err.Raise vbObjectError + 8996, , "VirtualAlloc failed for Thunk1"
    CopyMemory mem, VarPtr(code(0)), CLngPtr(i + 1)
    BuildThunk1 = mem
End Function

Private Function BuildThunk2(ByVal target As LongPtr) As LongPtr
    Dim code(0 To 47) As Byte
    Dim i As Long: i = 0
    
    code(i) = &H48: i = i + 1: code(i) = &H83: i = i + 1: code(i) = &HEC: i = i + 1: code(i) = &H28: i = i + 1
    code(i) = &H4D: i = i + 1: code(i) = &H89: i = i + 1: code(i) = &HC2: i = i + 1
    code(i) = &H49: i = i + 1: code(i) = &H8B: i = i + 1: code(i) = &HA: i = i + 1
    code(i) = &H49: i = i + 1: code(i) = &H8B: i = i + 1: code(i) = &H52: i = i + 1: code(i) = &H8: i = i + 1
    code(i) = &H48: i = i + 1: code(i) = &HB8: i = i + 1
    Dim t As LongLong: t = target
    RtlMoveMemoryFromPtr VarPtr(code(i)), t, 8: i = i + 8
    code(i) = &HFF: i = i + 1: code(i) = &HD0: i = i + 1
    code(i) = &H48: i = i + 1: code(i) = &H83: i = i + 1: code(i) = &HC4: i = i + 1: code(i) = &H28: i = i + 1
    code(i) = &HC3
    
    Dim mem As LongPtr
    mem = VirtualAlloc(0, 64, MEM_COMMIT Or MEM_RESERVE, PAGE_EXECUTE_READWRITE)
    If mem = 0 Then Err.Raise vbObjectError + 8997, , "VirtualAlloc failed for Thunk2"
    CopyMemory mem, VarPtr(code(0)), CLngPtr(i + 1)
    BuildThunk2 = mem
End Function

Private Function BuildThunk3(ByVal target As LongPtr) As LongPtr
    Dim code(0 To 55) As Byte
    Dim i As Long: i = 0
    
    code(i) = &H48: i = i + 1: code(i) = &H83: i = i + 1: code(i) = &HEC: i = i + 1: code(i) = &H28: i = i + 1
    code(i) = &H4D: i = i + 1: code(i) = &H89: i = i + 1: code(i) = &HC2: i = i + 1
    code(i) = &H49: i = i + 1: code(i) = &H8B: i = i + 1: code(i) = &HA: i = i + 1
    code(i) = &H49: i = i + 1: code(i) = &H8B: i = i + 1: code(i) = &H52: i = i + 1: code(i) = &H8: i = i + 1
    code(i) = &H4D: i = i + 1: code(i) = &H8B: i = i + 1: code(i) = &H42: i = i + 1: code(i) = &H10: i = i + 1
    code(i) = &H48: i = i + 1: code(i) = &HB8: i = i + 1
    Dim t As LongLong: t = target
    RtlMoveMemoryFromPtr VarPtr(code(i)), t, 8: i = i + 8
    code(i) = &HFF: i = i + 1: code(i) = &HD0: i = i + 1
    code(i) = &H48: i = i + 1: code(i) = &H83: i = i + 1: code(i) = &HC4: i = i + 1: code(i) = &H28: i = i + 1
    code(i) = &HC3
    
    Dim mem As LongPtr
    mem = VirtualAlloc(0, 64, MEM_COMMIT Or MEM_RESERVE, PAGE_EXECUTE_READWRITE)
    If mem = 0 Then Err.Raise vbObjectError + 8998, , "VirtualAlloc failed for Thunk3"
    CopyMemory mem, VarPtr(code(0)), CLngPtr(i + 1)
    BuildThunk3 = mem
End Function

Private Function BuildThunk4(ByVal target As LongPtr) As LongPtr
    Dim code(0 To 63) As Byte
    Dim i As Long: i = 0
    
    code(i) = &H48: i = i + 1: code(i) = &H83: i = i + 1: code(i) = &HEC: i = i + 1: code(i) = &H28: i = i + 1
    code(i) = &H4D: i = i + 1: code(i) = &H89: i = i + 1: code(i) = &HC2: i = i + 1
    code(i) = &H49: i = i + 1: code(i) = &H8B: i = i + 1: code(i) = &HA: i = i + 1
    code(i) = &H49: i = i + 1: code(i) = &H8B: i = i + 1: code(i) = &H52: i = i + 1: code(i) = &H8: i = i + 1
    code(i) = &H4D: i = i + 1: code(i) = &H8B: i = i + 1: code(i) = &H42: i = i + 1: code(i) = &H10: i = i + 1
    code(i) = &H4D: i = i + 1: code(i) = &H8B: i = i + 1: code(i) = &H4A: i = i + 1: code(i) = &H18: i = i + 1
    code(i) = &H48: i = i + 1: code(i) = &HB8: i = i + 1
    Dim t As LongLong: t = target
    RtlMoveMemoryFromPtr VarPtr(code(i)), t, 8: i = i + 8
    code(i) = &HFF: i = i + 1: code(i) = &HD0: i = i + 1
    code(i) = &H48: i = i + 1: code(i) = &H83: i = i + 1: code(i) = &HC4: i = i + 1: code(i) = &H28: i = i + 1
    code(i) = &HC3
    
    Dim mem As LongPtr
    mem = VirtualAlloc(0, 128, MEM_COMMIT Or MEM_RESERVE, PAGE_EXECUTE_READWRITE)
    If mem = 0 Then Err.Raise vbObjectError + 8999, , "VirtualAlloc failed for Thunk4"
    CopyMemory mem, VarPtr(code(0)), CLngPtr(i + 1)
    BuildThunk4 = mem
End Function

Private Function BuildThunk5(ByVal target As LongPtr) As LongPtr
    Dim code(0 To 79) As Byte
    Dim i As Long: i = 0
    
    code(i) = &H48: i = i + 1: code(i) = &H83: i = i + 1: code(i) = &HEC: i = i + 1: code(i) = &H38: i = i + 1
    code(i) = &H4D: i = i + 1: code(i) = &H89: i = i + 1: code(i) = &HC2: i = i + 1
    code(i) = &H49: i = i + 1: code(i) = &H8B: i = i + 1: code(i) = &HA: i = i + 1
    code(i) = &H49: i = i + 1: code(i) = &H8B: i = i + 1: code(i) = &H52: i = i + 1: code(i) = &H8: i = i + 1
    code(i) = &H4D: i = i + 1: code(i) = &H8B: i = i + 1: code(i) = &H42: i = i + 1: code(i) = &H10: i = i + 1
    code(i) = &H4D: i = i + 1: code(i) = &H8B: i = i + 1: code(i) = &H4A: i = i + 1: code(i) = &H18: i = i + 1
    code(i) = &H49: i = i + 1: code(i) = &H8B: i = i + 1: code(i) = &H42: i = i + 1: code(i) = &H20: i = i + 1
    code(i) = &H48: i = i + 1: code(i) = &H89: i = i + 1: code(i) = &H44: i = i + 1: code(i) = &H24: i = i + 1: code(i) = &H20: i = i + 1
    code(i) = &H48: i = i + 1: code(i) = &HB8: i = i + 1
    Dim t As LongLong: t = target
    RtlMoveMemoryFromPtr VarPtr(code(i)), t, 8: i = i + 8
    code(i) = &HFF: i = i + 1: code(i) = &HD0: i = i + 1
    code(i) = &H48: i = i + 1: code(i) = &H83: i = i + 1: code(i) = &HC4: i = i + 1: code(i) = &H38: i = i + 1
    code(i) = &HC3
    
    Dim mem As LongPtr
    mem = VirtualAlloc(0, 128, MEM_COMMIT Or MEM_RESERVE, PAGE_EXECUTE_READWRITE)
    If mem = 0 Then Err.Raise vbObjectError + 9000, , "VirtualAlloc failed for Thunk5"
    CopyMemory mem, VarPtr(code(0)), CLngPtr(i + 1)
    BuildThunk5 = mem
End Function

Private Function BuildThunk6(ByVal target As LongPtr) As LongPtr
    Dim code(0 To 99) As Byte
    Dim i As Long: i = 0
    
    code(i) = &H48: i = i + 1: code(i) = &H83: i = i + 1: code(i) = &HEC: i = i + 1: code(i) = &H48: i = i + 1
    code(i) = &H4D: i = i + 1: code(i) = &H89: i = i + 1: code(i) = &HC2: i = i + 1
    code(i) = &H49: i = i + 1: code(i) = &H8B: i = i + 1: code(i) = &HA: i = i + 1
    code(i) = &H49: i = i + 1: code(i) = &H8B: i = i + 1: code(i) = &H52: i = i + 1: code(i) = &H8: i = i + 1
    code(i) = &H4D: i = i + 1: code(i) = &H8B: i = i + 1: code(i) = &H42: i = i + 1: code(i) = &H10: i = i + 1
    code(i) = &H4D: i = i + 1: code(i) = &H8B: i = i + 1: code(i) = &H4A: i = i + 1: code(i) = &H18: i = i + 1
    code(i) = &H49: i = i + 1: code(i) = &H8B: i = i + 1: code(i) = &H42: i = i + 1: code(i) = &H20: i = i + 1
    code(i) = &H48: i = i + 1: code(i) = &H89: i = i + 1: code(i) = &H44: i = i + 1: code(i) = &H24: i = i + 1: code(i) = &H20: i = i + 1
    code(i) = &H49: i = i + 1: code(i) = &H8B: i = i + 1: code(i) = &H42: i = i + 1: code(i) = &H28: i = i + 1
    code(i) = &H48: i = i + 1: code(i) = &H89: i = i + 1: code(i) = &H44: i = i + 1: code(i) = &H24: i = i + 1: code(i) = &H28: i = i + 1
    code(i) = &H48: i = i + 1: code(i) = &HB8: i = i + 1
    Dim t As LongLong: t = target
    RtlMoveMemoryFromPtr VarPtr(code(i)), t, 8: i = i + 8
    code(i) = &HFF: i = i + 1: code(i) = &HD0: i = i + 1
    code(i) = &H48: i = i + 1: code(i) = &H83: i = i + 1: code(i) = &HC4: i = i + 1: code(i) = &H48: i = i + 1
    code(i) = &HC3
    
    Dim mem As LongPtr
    mem = VirtualAlloc(0, 128, MEM_COMMIT Or MEM_RESERVE, PAGE_EXECUTE_READWRITE)
    If mem = 0 Then Err.Raise vbObjectError + 9001, , "VirtualAlloc failed for Thunk6"
    CopyMemory mem, VarPtr(code(0)), CLngPtr(i + 1)
    BuildThunk6 = mem
End Function

Private Function BuildThunk7(ByVal target As LongPtr) As LongPtr
    Dim code(0 To 119) As Byte
    Dim i As Long: i = 0
    
    code(i) = &H48: i = i + 1: code(i) = &H83: i = i + 1: code(i) = &HEC: i = i + 1: code(i) = &H58: i = i + 1
    code(i) = &H4D: i = i + 1: code(i) = &H89: i = i + 1: code(i) = &HC2: i = i + 1
    code(i) = &H49: i = i + 1: code(i) = &H8B: i = i + 1: code(i) = &HA: i = i + 1
    code(i) = &H49: i = i + 1: code(i) = &H8B: i = i + 1: code(i) = &H52: i = i + 1: code(i) = &H8: i = i + 1
    code(i) = &H4D: i = i + 1: code(i) = &H8B: i = i + 1: code(i) = &H42: i = i + 1: code(i) = &H10: i = i + 1
    code(i) = &H4D: i = i + 1: code(i) = &H8B: i = i + 1: code(i) = &H4A: i = i + 1: code(i) = &H18: i = i + 1
    code(i) = &H49: i = i + 1: code(i) = &H8B: i = i + 1: code(i) = &H42: i = i + 1: code(i) = &H20: i = i + 1
    code(i) = &H48: i = i + 1: code(i) = &H89: i = i + 1: code(i) = &H44: i = i + 1: code(i) = &H24: i = i + 1: code(i) = &H20: i = i + 1
    code(i) = &H49: i = i + 1: code(i) = &H8B: i = i + 1: code(i) = &H42: i = i + 1: code(i) = &H28: i = i + 1
    code(i) = &H48: i = i + 1: code(i) = &H89: i = i + 1: code(i) = &H44: i = i + 1: code(i) = &H24: i = i + 1: code(i) = &H28: i = i + 1
    code(i) = &H49: i = i + 1: code(i) = &H8B: i = i + 1: code(i) = &H42: i = i + 1: code(i) = &H30: i = i + 1
    code(i) = &H48: i = i + 1: code(i) = &H89: i = i + 1: code(i) = &H44: i = i + 1: code(i) = &H24: i = i + 1: code(i) = &H30: i = i + 1
    code(i) = &H48: i = i + 1: code(i) = &HB8: i = i + 1
    Dim t As LongLong: t = target
    RtlMoveMemoryFromPtr VarPtr(code(i)), t, 8: i = i + 8
    code(i) = &HFF: i = i + 1: code(i) = &HD0: i = i + 1
    code(i) = &H48: i = i + 1: code(i) = &H83: i = i + 1: code(i) = &HC4: i = i + 1: code(i) = &H58: i = i + 1
    code(i) = &HC3
    
    Dim mem As LongPtr
    mem = VirtualAlloc(0, 128, MEM_COMMIT Or MEM_RESERVE, PAGE_EXECUTE_READWRITE)
    If mem = 0 Then Err.Raise vbObjectError + 9002, , "VirtualAlloc failed for Thunk7"
    CopyMemory mem, VarPtr(code(0)), CLngPtr(i + 1)
    BuildThunk7 = mem
End Function

Private Function BuildThunk8(ByVal target As LongPtr) As LongPtr
    Dim code(0 To 127) As Byte
    Dim i As Long: i = 0
    
    code(i) = &H48: i = i + 1: code(i) = &H83: i = i + 1: code(i) = &HEC: i = i + 1: code(i) = &H68: i = i + 1
    code(i) = &H4D: i = i + 1: code(i) = &H89: i = i + 1: code(i) = &HC2: i = i + 1
    code(i) = &H49: i = i + 1: code(i) = &H8B: i = i + 1: code(i) = &HA: i = i + 1
    code(i) = &H49: i = i + 1: code(i) = &H8B: i = i + 1: code(i) = &H52: i = i + 1: code(i) = &H8: i = i + 1
    code(i) = &H4D: i = i + 1: code(i) = &H8B: i = i + 1: code(i) = &H42: i = i + 1: code(i) = &H10: i = i + 1
    code(i) = &H4D: i = i + 1: code(i) = &H8B: i = i + 1: code(i) = &H4A: i = i + 1: code(i) = &H18: i = i + 1
    code(i) = &H49: i = i + 1: code(i) = &H8B: i = i + 1: code(i) = &H42: i = i + 1: code(i) = &H20: i = i + 1
    code(i) = &H48: i = i + 1: code(i) = &H89: i = i + 1: code(i) = &H44: i = i + 1: code(i) = &H24: i = i + 1: code(i) = &H20: i = i + 1
    code(i) = &H49: i = i + 1: code(i) = &H8B: i = i + 1: code(i) = &H42: i = i + 1: code(i) = &H28: i = i + 1
    code(i) = &H48: i = i + 1: code(i) = &H89: i = i + 1: code(i) = &H44: i = i + 1: code(i) = &H24: i = i + 1: code(i) = &H28: i = i + 1
    code(i) = &H49: i = i + 1: code(i) = &H8B: i = i + 1: code(i) = &H42: i = i + 1: code(i) = &H30: i = i + 1
    code(i) = &H48: i = i + 1: code(i) = &H89: i = i + 1: code(i) = &H44: i = i + 1: code(i) = &H24: i = i + 1: code(i) = &H30: i = i + 1
    code(i) = &H49: i = i + 1: code(i) = &H8B: i = i + 1: code(i) = &H42: i = i + 1: code(i) = &H38: i = i + 1
    code(i) = &H48: i = i + 1: code(i) = &H89: i = i + 1: code(i) = &H44: i = i + 1: code(i) = &H24: i = i + 1: code(i) = &H38: i = i + 1
    code(i) = &H48: i = i + 1: code(i) = &HB8: i = i + 1
    Dim t As LongLong: t = target
    RtlMoveMemoryFromPtr VarPtr(code(i)), t, 8: i = i + 8
    code(i) = &HFF: i = i + 1: code(i) = &HD0: i = i + 1
    code(i) = &H48: i = i + 1: code(i) = &H83: i = i + 1: code(i) = &HC4: i = i + 1: code(i) = &H68: i = i + 1
    code(i) = &HC3
    
    Dim mem As LongPtr
    mem = VirtualAlloc(0, 160, MEM_COMMIT Or MEM_RESERVE, PAGE_EXECUTE_READWRITE)
    If mem = 0 Then Err.Raise vbObjectError + 9003, , "VirtualAlloc failed for Thunk8"
    CopyMemory mem, VarPtr(code(0)), CLngPtr(i + 1)
    BuildThunk8 = mem
End Function

Private Function BuildThunk9(ByVal target As LongPtr) As LongPtr
    Dim code(0 To 143) As Byte
    Dim i As Long: i = 0
    
    code(i) = &H48: i = i + 1: code(i) = &H83: i = i + 1: code(i) = &HEC: i = i + 1: code(i) = &H68: i = i + 1
    code(i) = &H4D: i = i + 1: code(i) = &H89: i = i + 1: code(i) = &HC2: i = i + 1
    code(i) = &H49: i = i + 1: code(i) = &H8B: i = i + 1: code(i) = &HA: i = i + 1
    code(i) = &H49: i = i + 1: code(i) = &H8B: i = i + 1: code(i) = &H52: i = i + 1: code(i) = &H8: i = i + 1
    code(i) = &H4D: i = i + 1: code(i) = &H8B: i = i + 1: code(i) = &H42: i = i + 1: code(i) = &H10: i = i + 1
    code(i) = &H4D: i = i + 1: code(i) = &H8B: i = i + 1: code(i) = &H4A: i = i + 1: code(i) = &H18: i = i + 1
    code(i) = &H49: i = i + 1: code(i) = &H8B: i = i + 1: code(i) = &H42: i = i + 1: code(i) = &H20: i = i + 1
    code(i) = &H48: i = i + 1: code(i) = &H89: i = i + 1: code(i) = &H44: i = i + 1: code(i) = &H24: i = i + 1: code(i) = &H20: i = i + 1
    code(i) = &H49: i = i + 1: code(i) = &H8B: i = i + 1: code(i) = &H42: i = i + 1: code(i) = &H28: i = i + 1
    code(i) = &H48: i = i + 1: code(i) = &H89: i = i + 1: code(i) = &H44: i = i + 1: code(i) = &H24: i = i + 1: code(i) = &H28: i = i + 1
    code(i) = &H49: i = i + 1: code(i) = &H8B: i = i + 1: code(i) = &H42: i = i + 1: code(i) = &H30: i = i + 1
    code(i) = &H48: i = i + 1: code(i) = &H89: i = i + 1: code(i) = &H44: i = i + 1: code(i) = &H24: i = i + 1: code(i) = &H30: i = i + 1
    code(i) = &H49: i = i + 1: code(i) = &H8B: i = i + 1: code(i) = &H42: i = i + 1: code(i) = &H38: i = i + 1
    code(i) = &H48: i = i + 1: code(i) = &H89: i = i + 1: code(i) = &H44: i = i + 1: code(i) = &H24: i = i + 1: code(i) = &H38: i = i + 1
    code(i) = &H49: i = i + 1: code(i) = &H8B: i = i + 1: code(i) = &H42: i = i + 1: code(i) = &H40: i = i + 1
    code(i) = &H48: i = i + 1: code(i) = &H89: i = i + 1: code(i) = &H44: i = i + 1: code(i) = &H24: i = i + 1: code(i) = &H40: i = i + 1
    code(i) = &H48: i = i + 1: code(i) = &HB8: i = i + 1
    Dim t As LongLong: t = target
    RtlMoveMemoryFromPtr VarPtr(code(i)), t, 8: i = i + 8
    code(i) = &HFF: i = i + 1: code(i) = &HD0: i = i + 1
    code(i) = &H48: i = i + 1: code(i) = &H83: i = i + 1: code(i) = &HC4: i = i + 1: code(i) = &H68: i = i + 1
    code(i) = &HC3
    
    Dim mem As LongPtr
    mem = VirtualAlloc(0, 192, MEM_COMMIT Or MEM_RESERVE, PAGE_EXECUTE_READWRITE)
    If mem = 0 Then Err.Raise vbObjectError + 9004, , "VirtualAlloc failed for Thunk9"
    CopyMemory mem, VarPtr(code(0)), CLngPtr(i + 1)
    BuildThunk9 = mem
End Function

' Special thunk for functions that return struct via hidden first parameter (CPU handle)
Private Function BuildThunkRetStruct(ByVal target As LongPtr) As LongPtr
    Dim code(0 To 47) As Byte
    Dim i As Long: i = 0
    
    code(i) = &H48: i = i + 1: code(i) = &H83: i = i + 1: code(i) = &HEC: i = i + 1: code(i) = &H28: i = i + 1
    code(i) = &H4D: i = i + 1: code(i) = &H89: i = i + 1: code(i) = &HC2: i = i + 1
    code(i) = &H49: i = i + 1: code(i) = &H8B: i = i + 1: code(i) = &HA: i = i + 1
    code(i) = &H49: i = i + 1: code(i) = &H8B: i = i + 1: code(i) = &H52: i = i + 1: code(i) = &H8: i = i + 1
    code(i) = &H48: i = i + 1: code(i) = &HB8: i = i + 1
    Dim t As LongLong: t = target
    RtlMoveMemoryFromPtr VarPtr(code(i)), t, 8: i = i + 8
    code(i) = &HFF: i = i + 1: code(i) = &HD0: i = i + 1
    code(i) = &H48: i = i + 1: code(i) = &H83: i = i + 1: code(i) = &HC4: i = i + 1: code(i) = &H28: i = i + 1
    code(i) = &HC3
    
    Dim mem As LongPtr
    mem = VirtualAlloc(0, 64, MEM_COMMIT Or MEM_RESERVE, PAGE_EXECUTE_READWRITE)
    If mem = 0 Then Err.Raise vbObjectError + 9005, , "VirtualAlloc failed for ThunkRetStruct"
    CopyMemory mem, VarPtr(code(0)), CLngPtr(i + 1)
    BuildThunkRetStruct = mem
End Function

Private Sub FreeThunkCache(ByRef cache As ThunkCache)
    Dim i As Long
    For i = 0 To cache.count - 1
        If cache.thunks(i) <> 0 Then
            VirtualFree cache.thunks(i), 0, MEM_RELEASE
            cache.thunks(i) = 0
        End If
        cache.targets(i) = 0
    Next i
    cache.count = 0
End Sub

Private Sub FreeThunks()
    On Error Resume Next
    FreeThunkCache g_thunkCache1
    FreeThunkCache g_thunkCache2
    FreeThunkCache g_thunkCache3
    FreeThunkCache g_thunkCache4
    FreeThunkCache g_thunkCache5
    FreeThunkCache g_thunkCache6
    FreeThunkCache g_thunkCache7
    FreeThunkCache g_thunkCache8
    FreeThunkCache g_thunkCache9
    FreeThunkCache g_thunkCacheRetStruct
End Sub

' Get or create cached thunk
Private Function GetCachedThunk1(ByVal target As LongPtr) As LongPtr
    Dim i As Long
    For i = 0 To g_thunkCache1.count - 1
        If g_thunkCache1.targets(i) = target Then
            GetCachedThunk1 = g_thunkCache1.thunks(i)
            Exit Function
        End If
    Next i
    ' Create new thunk
    If g_thunkCache1.count < 64 Then
        g_thunkCache1.targets(g_thunkCache1.count) = target
        g_thunkCache1.thunks(g_thunkCache1.count) = BuildThunk1(target)
        GetCachedThunk1 = g_thunkCache1.thunks(g_thunkCache1.count)
        g_thunkCache1.count = g_thunkCache1.count + 1
    Else
        GetCachedThunk1 = BuildThunk1(target)
    End If
End Function

Private Function GetCachedThunk2(ByVal target As LongPtr) As LongPtr
    Dim i As Long
    For i = 0 To g_thunkCache2.count - 1
        If g_thunkCache2.targets(i) = target Then
            GetCachedThunk2 = g_thunkCache2.thunks(i)
            Exit Function
        End If
    Next i
    If g_thunkCache2.count < 64 Then
        g_thunkCache2.targets(g_thunkCache2.count) = target
        g_thunkCache2.thunks(g_thunkCache2.count) = BuildThunk2(target)
        GetCachedThunk2 = g_thunkCache2.thunks(g_thunkCache2.count)
        g_thunkCache2.count = g_thunkCache2.count + 1
    Else
        GetCachedThunk2 = BuildThunk2(target)
    End If
End Function

Private Function GetCachedThunk3(ByVal target As LongPtr) As LongPtr
    Dim i As Long
    For i = 0 To g_thunkCache3.count - 1
        If g_thunkCache3.targets(i) = target Then
            GetCachedThunk3 = g_thunkCache3.thunks(i)
            Exit Function
        End If
    Next i
    If g_thunkCache3.count < 64 Then
        g_thunkCache3.targets(g_thunkCache3.count) = target
        g_thunkCache3.thunks(g_thunkCache3.count) = BuildThunk3(target)
        GetCachedThunk3 = g_thunkCache3.thunks(g_thunkCache3.count)
        g_thunkCache3.count = g_thunkCache3.count + 1
    Else
        GetCachedThunk3 = BuildThunk3(target)
    End If
End Function

Private Function GetCachedThunk4(ByVal target As LongPtr) As LongPtr
    Dim i As Long
    For i = 0 To g_thunkCache4.count - 1
        If g_thunkCache4.targets(i) = target Then
            GetCachedThunk4 = g_thunkCache4.thunks(i)
            Exit Function
        End If
    Next i
    If g_thunkCache4.count < 64 Then
        g_thunkCache4.targets(g_thunkCache4.count) = target
        g_thunkCache4.thunks(g_thunkCache4.count) = BuildThunk4(target)
        GetCachedThunk4 = g_thunkCache4.thunks(g_thunkCache4.count)
        g_thunkCache4.count = g_thunkCache4.count + 1
    Else
        GetCachedThunk4 = BuildThunk4(target)
    End If
End Function

Private Function GetCachedThunk5(ByVal target As LongPtr) As LongPtr
    Dim i As Long
    For i = 0 To g_thunkCache5.count - 1
        If g_thunkCache5.targets(i) = target Then
            GetCachedThunk5 = g_thunkCache5.thunks(i)
            Exit Function
        End If
    Next i
    If g_thunkCache5.count < 64 Then
        g_thunkCache5.targets(g_thunkCache5.count) = target
        g_thunkCache5.thunks(g_thunkCache5.count) = BuildThunk5(target)
        GetCachedThunk5 = g_thunkCache5.thunks(g_thunkCache5.count)
        g_thunkCache5.count = g_thunkCache5.count + 1
    Else
        GetCachedThunk5 = BuildThunk5(target)
    End If
End Function

Private Function GetCachedThunk6(ByVal target As LongPtr) As LongPtr
    Dim i As Long
    For i = 0 To g_thunkCache6.count - 1
        If g_thunkCache6.targets(i) = target Then
            GetCachedThunk6 = g_thunkCache6.thunks(i)
            Exit Function
        End If
    Next i
    If g_thunkCache6.count < 64 Then
        g_thunkCache6.targets(g_thunkCache6.count) = target
        g_thunkCache6.thunks(g_thunkCache6.count) = BuildThunk6(target)
        GetCachedThunk6 = g_thunkCache6.thunks(g_thunkCache6.count)
        g_thunkCache6.count = g_thunkCache6.count + 1
    Else
        GetCachedThunk6 = BuildThunk6(target)
    End If
End Function

Private Function GetCachedThunk7(ByVal target As LongPtr) As LongPtr
    Dim i As Long
    For i = 0 To g_thunkCache7.count - 1
        If g_thunkCache7.targets(i) = target Then
            GetCachedThunk7 = g_thunkCache7.thunks(i)
            Exit Function
        End If
    Next i
    If g_thunkCache7.count < 64 Then
        g_thunkCache7.targets(g_thunkCache7.count) = target
        g_thunkCache7.thunks(g_thunkCache7.count) = BuildThunk7(target)
        GetCachedThunk7 = g_thunkCache7.thunks(g_thunkCache7.count)
        g_thunkCache7.count = g_thunkCache7.count + 1
    Else
        GetCachedThunk7 = BuildThunk7(target)
    End If
End Function

Private Function GetCachedThunk8(ByVal target As LongPtr) As LongPtr
    Dim i As Long
    For i = 0 To g_thunkCache8.count - 1
        If g_thunkCache8.targets(i) = target Then
            GetCachedThunk8 = g_thunkCache8.thunks(i)
            Exit Function
        End If
    Next i
    If g_thunkCache8.count < 64 Then
        g_thunkCache8.targets(g_thunkCache8.count) = target
        g_thunkCache8.thunks(g_thunkCache8.count) = BuildThunk8(target)
        GetCachedThunk8 = g_thunkCache8.thunks(g_thunkCache8.count)
        g_thunkCache8.count = g_thunkCache8.count + 1
    Else
        GetCachedThunk8 = BuildThunk8(target)
    End If
End Function

Private Function GetCachedThunk9(ByVal target As LongPtr) As LongPtr
    Dim i As Long
    For i = 0 To g_thunkCache9.count - 1
        If g_thunkCache9.targets(i) = target Then
            GetCachedThunk9 = g_thunkCache9.thunks(i)
            Exit Function
        End If
    Next i
    If g_thunkCache9.count < 64 Then
        g_thunkCache9.targets(g_thunkCache9.count) = target
        g_thunkCache9.thunks(g_thunkCache9.count) = BuildThunk9(target)
        GetCachedThunk9 = g_thunkCache9.thunks(g_thunkCache9.count)
        g_thunkCache9.count = g_thunkCache9.count + 1
    Else
        GetCachedThunk9 = BuildThunk9(target)
    End If
End Function

Private Function GetCachedThunkRetStruct(ByVal target As LongPtr) As LongPtr
    Dim i As Long
    For i = 0 To g_thunkCacheRetStruct.count - 1
        If g_thunkCacheRetStruct.targets(i) = target Then
            GetCachedThunkRetStruct = g_thunkCacheRetStruct.thunks(i)
            Exit Function
        End If
    Next i
    If g_thunkCacheRetStruct.count < 64 Then
        g_thunkCacheRetStruct.targets(g_thunkCacheRetStruct.count) = target
        g_thunkCacheRetStruct.thunks(g_thunkCacheRetStruct.count) = BuildThunkRetStruct(target)
        GetCachedThunkRetStruct = g_thunkCacheRetStruct.thunks(g_thunkCacheRetStruct.count)
        g_thunkCacheRetStruct.count = g_thunkCacheRetStruct.count + 1
    Else
        GetCachedThunkRetStruct = BuildThunkRetStruct(target)
    End If
End Function

' ============================================================
' COM Call helpers (using cached thunks)
' ============================================================
Private Function COM_Call1(ByVal pObj As LongPtr, ByVal vtIndex As Long) As LongPtr
    Dim methodAddr As LongPtr
    methodAddr = GetVTableMethod(pObj, vtIndex)
    
    Dim thunk As LongPtr
    thunk = GetCachedThunk1(methodAddr)
    
    Dim args As ThunkArgs1
    args.a1 = pObj
    
    COM_Call1 = CallWindowProcW(thunk, 0, 0, VarPtr(args), 0)
End Function

Private Function COM_Call2(ByVal pObj As LongPtr, ByVal vtIndex As Long, ByVal a2 As LongPtr) As LongPtr
    Dim methodAddr As LongPtr
    methodAddr = GetVTableMethod(pObj, vtIndex)
    
    Dim thunk As LongPtr
    thunk = GetCachedThunk2(methodAddr)
    
    Dim args As ThunkArgs2
    args.a1 = pObj
    args.a2 = a2
    
    COM_Call2 = CallWindowProcW(thunk, 0, 0, VarPtr(args), 0)
End Function

Private Function COM_Call3(ByVal pObj As LongPtr, ByVal vtIndex As Long, ByVal a2 As LongPtr, ByVal a3 As LongPtr) As LongPtr
    Dim methodAddr As LongPtr
    methodAddr = GetVTableMethod(pObj, vtIndex)
    
    Dim thunk As LongPtr
    thunk = GetCachedThunk3(methodAddr)
    
    Dim args As ThunkArgs3
    args.a1 = pObj
    args.a2 = a2
    args.a3 = a3
    
    COM_Call3 = CallWindowProcW(thunk, 0, 0, VarPtr(args), 0)
End Function

Private Function COM_Call4(ByVal pObj As LongPtr, ByVal vtIndex As Long, ByVal a2 As LongPtr, ByVal a3 As LongPtr, ByVal a4 As LongPtr) As LongPtr
    Dim methodAddr As LongPtr
    methodAddr = GetVTableMethod(pObj, vtIndex)
    
    Dim thunk As LongPtr
    thunk = GetCachedThunk4(methodAddr)
    
    Dim args As ThunkArgs4
    args.a1 = pObj
    args.a2 = a2
    args.a3 = a3
    args.a4 = a4
    
    COM_Call4 = CallWindowProcW(thunk, 0, 0, VarPtr(args), 0)
End Function

Private Function COM_Call5(ByVal pObj As LongPtr, ByVal vtIndex As Long, ByVal a2 As LongPtr, ByVal a3 As LongPtr, ByVal a4 As LongPtr, ByVal a5 As LongPtr) As LongPtr
    Dim methodAddr As LongPtr
    methodAddr = GetVTableMethod(pObj, vtIndex)
    
    Dim thunk As LongPtr
    thunk = GetCachedThunk5(methodAddr)
    
    Dim args As ThunkArgs5
    args.a1 = pObj
    args.a2 = a2
    args.a3 = a3
    args.a4 = a4
    args.a5 = a5
    
    COM_Call5 = CallWindowProcW(thunk, 0, 0, VarPtr(args), 0)
End Function

Private Function COM_Call6(ByVal pObj As LongPtr, ByVal vtIndex As Long, ByVal a2 As LongPtr, ByVal a3 As LongPtr, ByVal a4 As LongPtr, ByVal a5 As LongPtr, ByVal a6 As LongPtr) As LongPtr
    Dim methodAddr As LongPtr
    methodAddr = GetVTableMethod(pObj, vtIndex)
    
    Dim thunk As LongPtr
    thunk = GetCachedThunk6(methodAddr)
    
    Dim args As ThunkArgs6
    args.a1 = pObj
    args.a2 = a2
    args.a3 = a3
    args.a4 = a4
    args.a5 = a5
    args.a6 = a6
    
    COM_Call6 = CallWindowProcW(thunk, 0, 0, VarPtr(args), 0)
End Function

Private Function COM_Call7(ByVal pObj As LongPtr, ByVal vtIndex As Long, ByVal a2 As LongPtr, ByVal a3 As LongPtr, ByVal a4 As LongPtr, ByVal a5 As LongPtr, ByVal a6 As LongPtr, ByVal a7 As LongPtr) As LongPtr
    Dim methodAddr As LongPtr
    methodAddr = GetVTableMethod(pObj, vtIndex)
    
    Dim thunk As LongPtr
    thunk = GetCachedThunk7(methodAddr)
    
    Dim args As ThunkArgs7
    args.a1 = pObj
    args.a2 = a2
    args.a3 = a3
    args.a4 = a4
    args.a5 = a5
    args.a6 = a6
    args.a7 = a7
    
    COM_Call7 = CallWindowProcW(thunk, 0, 0, VarPtr(args), 0)
End Function

Private Sub COM_Release(ByVal pObj As LongPtr)
    If pObj <> 0 Then
        COM_Call1 pObj, ONVTBL_IUnknown_Release
    End If
End Sub

' Special call for GetCPUDescriptorHandleForHeapStart
Private Sub COM_GetCPUDescriptorHandle(ByVal pHeap As LongPtr, ByRef outHandle As D3D12_CPU_DESCRIPTOR_HANDLE)
    Dim methodAddr As LongPtr
    methodAddr = GetVTableMethod(pHeap, VTBL_DescHeap_GetCPUDescriptorHandleForHeapStart)
    
    Dim thunk As LongPtr
    thunk = GetCachedThunkRetStruct(methodAddr)
    
    Dim args As ThunkArgs2
    args.a1 = pHeap
    args.a2 = VarPtr(outHandle)
    
    CallWindowProcW thunk, 0, 0, VarPtr(args), 0
End Sub

' Special call for GetGPUDescriptorHandleForHeapStart
Private Sub COM_GetGPUDescriptorHandle(ByVal pHeap As LongPtr, ByRef outHandle As D3D12_GPU_DESCRIPTOR_HANDLE)
    Dim methodAddr As LongPtr
    methodAddr = GetVTableMethod(pHeap, VTBL_DescHeap_GetGPUDescriptorHandleForHeapStart)
    
    Dim thunk As LongPtr
    thunk = GetCachedThunkRetStruct(methodAddr)
    
    Dim args As ThunkArgs2
    args.a1 = pHeap
    args.a2 = VarPtr(outHandle)
    
    CallWindowProcW thunk, 0, 0, VarPtr(args), 0
End Sub

' ============================================================
' Compile shader from file using D3DCompileFromFile
' ============================================================
Private Function CompileShaderFromFile(ByVal filePath As String, ByVal entryPoint As String, ByVal profile As String) As LongPtr
    LogMsg "CompileShaderFromFile: " & filePath & " / " & entryPoint & " / " & profile
    
    Dim hCompiler As LongPtr
    hCompiler = LoadLibraryW(StrPtr("d3dcompiler_47.dll"))
    If hCompiler = 0 Then
        LogMsg "Failed to load d3dcompiler_47.dll"
        Err.Raise vbObjectError + 8100, , "Failed to load d3dcompiler_47.dll"
    End If
    
    Dim procNameBytes() As Byte
    procNameBytes = AnsiZBytes("D3DCompileFromFile")
    Dim pD3DCompileFromFile As LongPtr
    pD3DCompileFromFile = GetProcAddress(hCompiler, VarPtr(procNameBytes(0)))
    If pD3DCompileFromFile = 0 Then
        FreeLibrary hCompiler
        Err.Raise vbObjectError + 8101, , "D3DCompileFromFile not found"
    End If
    
    Dim thunk As LongPtr
    thunk = GetCachedThunk9(pD3DCompileFromFile)
    
    Dim entryBytes() As Byte: entryBytes = AnsiZBytes(entryPoint)
    Dim profileBytes() As Byte: profileBytes = AnsiZBytes(profile)
    
    Dim pBlob As LongPtr: pBlob = 0
    Dim pErrorBlob As LongPtr: pErrorBlob = 0
    
    ' D3DCompileFromFile(pFileName, pDefines, pInclude, pEntrypoint, pTarget, Flags1, Flags2, ppCode, ppErrorMsgs)
    Dim args As ThunkArgs9
    args.a1 = StrPtr(filePath)
    args.a2 = 0
    args.a3 = 0
    args.a4 = VarPtr(entryBytes(0))
    args.a5 = VarPtr(profileBytes(0))
    args.a6 = D3DCOMPILE_ENABLE_STRICTNESS
    args.a7 = 0
    args.a8 = VarPtr(pBlob)
    args.a9 = VarPtr(pErrorBlob)
    
    Dim hr As Long
    hr = ToHResult(CallWindowProcW(thunk, 0, 0, VarPtr(args), 0))
    LogMsg "D3DCompileFromFile returned: " & Hex$(hr)
    
    If hr < 0 Then
        If pErrorBlob <> 0 Then
            Dim errPtr As LongPtr
            errPtr = COM_Call1(pErrorBlob, VTBL_Blob_GetBufferPointer)
            LogMsg "Shader error: " & PtrToAnsiString(errPtr)
            COM_Release pErrorBlob
        End If
        FreeLibrary hCompiler
        Err.Raise vbObjectError + 8102, , "Shader compile failed: " & entryPoint
    End If
    
    If pErrorBlob <> 0 Then COM_Release pErrorBlob
    FreeLibrary hCompiler
    
    CompileShaderFromFile = pBlob
End Function

' ============================================================
' Window Procedure
' ============================================================
Public Function WindowProc(ByVal hWnd As LongPtr, ByVal uMsg As Long, ByVal wParam As LongPtr, ByVal lParam As LongPtr) As LongPtr
    Select Case uMsg
        Case WM_CLOSE
            LogMsg "WindowProc: WM_CLOSE"
            DestroyWindow hWnd
            WindowProc = 0
            Exit Function
        Case WM_DESTROY
            LogMsg "WindowProc: WM_DESTROY"
            PostQuitMessage 0
            WindowProc = 0
            Exit Function
    End Select

    WindowProc = DefWindowProcW(hWnd, uMsg, wParam, lParam)
End Function

' ============================================================
' Initialize DirectX 12
' ============================================================
Private Function InitD3D12(ByVal hWnd As LongPtr) As Boolean
    LogMsg "InitD3D12: start"
    
    Dim hr As Long
    
    ' Create DXGI Factory
    Dim pFactory As LongPtr
    Dim factoryIID As GUID: factoryIID = IID_IDXGIFactory1()
    hr = CreateDXGIFactory1(factoryIID, pFactory)
    LogMsg "CreateDXGIFactory1 returned: " & Hex$(hr)
    If hr < 0 Or pFactory = 0 Then
        InitD3D12 = False
        Exit Function
    End If
    
    ' Create D3D12 Device
    Dim deviceIID As GUID: deviceIID = IID_ID3D12Device()
    hr = D3D12CreateDevice(0, D3D_FEATURE_LEVEL_12_0, deviceIID, g_pDevice)
    LogMsg "D3D12CreateDevice returned: " & Hex$(hr)
    If hr < 0 Or g_pDevice = 0 Then
        COM_Release pFactory
        InitD3D12 = False
        Exit Function
    End If
    
    ' Create Command Queue
    Dim queueDesc As D3D12_COMMAND_QUEUE_DESC
    queueDesc.cType = D3D12_COMMAND_LIST_TYPE_DIRECT
    
    Dim queueIID As GUID: queueIID = IID_ID3D12CommandQueue()
    hr = ToHResult(COM_Call4(g_pDevice, VTBL_Device_CreateCommandQueue, VarPtr(queueDesc), VarPtr(queueIID), VarPtr(g_pCommandQueue)))
    LogMsg "CreateCommandQueue returned: " & Hex$(hr)
    If hr < 0 Then
        COM_Release pFactory
        InitD3D12 = False
        Exit Function
    End If
    
    ' Create Swap Chain
    Dim swapChainDesc As DXGI_SWAP_CHAIN_DESC
    swapChainDesc.bufferDesc.Width = Width
    swapChainDesc.bufferDesc.Height = Height
    swapChainDesc.bufferDesc.Format = DXGI_FORMAT_R8G8B8A8_UNORM
    swapChainDesc.SampleDesc.count = 1
    swapChainDesc.BufferUsage = DXGI_USAGE_RENDER_TARGET_OUTPUT
    swapChainDesc.BufferCount = FRAME_COUNT
    swapChainDesc.OutputWindow = hWnd
    swapChainDesc.Windowed = 1
    swapChainDesc.SwapEffect = DXGI_SWAP_EFFECT_FLIP_DISCARD
    
    hr = ToHResult(COM_Call4(pFactory, VTBL_Factory_CreateSwapChain, g_pCommandQueue, VarPtr(swapChainDesc), VarPtr(g_pSwapChain)))
    LogMsg "CreateSwapChain returned: " & Hex$(hr)
    If hr < 0 Then
        COM_Release pFactory
        InitD3D12 = False
        Exit Function
    End If
    
    ' Query IDXGISwapChain3
    Dim swapChain3IID As GUID: swapChain3IID = IID_IDXGISwapChain3()
    hr = ToHResult(COM_Call3(g_pSwapChain, ONVTBL_IUnknown_QueryInterface, VarPtr(swapChain3IID), VarPtr(g_pSwapChain3)))
    LogMsg "QueryInterface SwapChain3 returned: " & Hex$(hr)
    If hr < 0 Then
        COM_Release pFactory
        InitD3D12 = False
        Exit Function
    End If
    
    g_frameIndex = CLng(COM_Call1(g_pSwapChain3, VTBL_SwapChain3_GetCurrentBackBufferIndex))
    LogMsg "Initial frame index: " & g_frameIndex
    
    ' Create RTV Descriptor Heap
    Dim rtvHeapDesc As D3D12_DESCRIPTOR_HEAP_DESC
    rtvHeapDesc.cType = D3D12_DESCRIPTOR_HEAP_TYPE_RTV
    rtvHeapDesc.NumDescriptors = FRAME_COUNT
    rtvHeapDesc.Flags = D3D12_DESCRIPTOR_HEAP_FLAG_NONE
    
    Dim heapIID As GUID: heapIID = IID_ID3D12DescriptorHeap()
    hr = ToHResult(COM_Call4(g_pDevice, VTBL_Device_CreateDescriptorHeap, VarPtr(rtvHeapDesc), VarPtr(heapIID), VarPtr(g_pRtvHeap)))
    LogMsg "CreateDescriptorHeap (RTV) returned: " & Hex$(hr)
    If hr < 0 Then
        COM_Release pFactory
        InitD3D12 = False
        Exit Function
    End If
    
    g_rtvDescriptorSize = CLng(COM_Call2(g_pDevice, VTBL_Device_GetDescriptorHandleIncrementSize, D3D12_DESCRIPTOR_HEAP_TYPE_RTV))
    LogMsg "RTV descriptor size: " & g_rtvDescriptorSize
    
    ' Create SRV/UAV Descriptor Heap (SHADER_VISIBLE)
    Dim srvUavHeapDesc As D3D12_DESCRIPTOR_HEAP_DESC
    srvUavHeapDesc.cType = D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV
    srvUavHeapDesc.NumDescriptors = 5  ' UAV0, UAV1, SRV0, SRV1, CBV
    srvUavHeapDesc.Flags = D3D12_DESCRIPTOR_HEAP_FLAG_SHADER_VISIBLE
    
    hr = ToHResult(COM_Call4(g_pDevice, VTBL_Device_CreateDescriptorHeap, VarPtr(srvUavHeapDesc), VarPtr(heapIID), VarPtr(g_pSrvUavHeap)))
    LogMsg "CreateDescriptorHeap (SRV/UAV) returned: " & Hex$(hr)
    If hr < 0 Then
        COM_Release pFactory
        InitD3D12 = False
        Exit Function
    End If
    
    g_srvUavDescriptorSize = CLng(COM_Call2(g_pDevice, VTBL_Device_GetDescriptorHandleIncrementSize, D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV))
    LogMsg "SRV/UAV descriptor size: " & g_srvUavDescriptorSize
    
    ' Get CPU descriptor handle for RTV heap start
    Dim rtvHandle As D3D12_CPU_DESCRIPTOR_HANDLE
    COM_GetCPUDescriptorHandle g_pRtvHeap, rtvHandle
    
    ' Create render target views for each frame
    Dim resourceIID As GUID: resourceIID = IID_ID3D12Resource()
    Dim frameIdx As Long
    For frameIdx = 0 To FRAME_COUNT - 1
        hr = ToHResult(COM_Call4(g_pSwapChain, VTBL_SwapChain_GetBuffer, frameIdx, VarPtr(resourceIID), VarPtr(g_pRenderTargets(frameIdx))))
        LogMsg "GetBuffer[" & frameIdx & "] returned: " & Hex$(hr)
        If hr < 0 Then
            COM_Release pFactory
            InitD3D12 = False
            Exit Function
        End If
        
        COM_Call4 g_pDevice, VTBL_Device_CreateRenderTargetView, g_pRenderTargets(frameIdx), 0, rtvHandle.ptr
        rtvHandle.ptr = rtvHandle.ptr + g_rtvDescriptorSize
    Next frameIdx

    ' Create Command Allocators (for each frame)
    Dim allocIID As GUID: allocIID = IID_ID3D12CommandAllocator()
    Dim i As Long
    For i = 0 To FRAME_COUNT - 1
        hr = ToHResult(COM_Call4(g_pDevice, VTBL_Device_CreateCommandAllocator, D3D12_COMMAND_LIST_TYPE_DIRECT, VarPtr(allocIID), VarPtr(g_pCommandAllocators(i))))
        LogMsg "CreateCommandAllocator[" & i & "] returned: " & Hex$(hr)
        If hr < 0 Then
            COM_Release pFactory
            InitD3D12 = False
            Exit Function
        End If
        g_fenceValues(i) = 0
    Next i
    
    COM_Release pFactory
    
    InitD3D12 = True
    LogMsg "InitD3D12: done"
End Function

' ============================================================
' Create Compute Root Signature
' ============================================================
Private Function CreateComputeRootSignature() As Boolean
    LogMsg "CreateComputeRootSignature: start"
    
    ' UAV range (u0, u1) - 2 descriptors
    Dim uavRange As D3D12_DESCRIPTOR_RANGE
    uavRange.RangeType = D3D12_DESCRIPTOR_RANGE_TYPE_UAV
    uavRange.NumDescriptors = 2
    uavRange.BaseShaderRegister = 0
    uavRange.RegisterSpace = 0
    uavRange.OffsetInDescriptorsFromTableStart = D3D12_DESCRIPTOR_RANGE_OFFSET_APPEND
    
    ' CBV range (b0) - 1 descriptor
    Dim cbvRange As D3D12_DESCRIPTOR_RANGE
    cbvRange.RangeType = D3D12_DESCRIPTOR_RANGE_TYPE_CBV
    cbvRange.NumDescriptors = 1
    cbvRange.BaseShaderRegister = 0
    cbvRange.RegisterSpace = 0
    cbvRange.OffsetInDescriptorsFromTableStart = D3D12_DESCRIPTOR_RANGE_OFFSET_APPEND
    
    ' Root parameters
    Dim rootParams(0 To 1) As D3D12_ROOT_PARAMETER
    
    ' Parameter 0: UAV table
    rootParams(0).ParameterType = D3D12_ROOT_PARAMETER_TYPE_DESCRIPTOR_TABLE
    rootParams(0).DescriptorTable.NumDescriptorRanges = 1
    rootParams(0).DescriptorTable.pDescriptorRanges = VarPtr(uavRange)
    rootParams(0).ShaderVisibility = D3D12_SHADER_VISIBILITY_ALL
    
    ' Parameter 1: CBV table
    rootParams(1).ParameterType = D3D12_ROOT_PARAMETER_TYPE_DESCRIPTOR_TABLE
    rootParams(1).DescriptorTable.NumDescriptorRanges = 1
    rootParams(1).DescriptorTable.pDescriptorRanges = VarPtr(cbvRange)
    rootParams(1).ShaderVisibility = D3D12_SHADER_VISIBILITY_ALL
    
    Dim rootSigDesc As D3D12_ROOT_SIGNATURE_DESC
    rootSigDesc.NumParameters = 2
    rootSigDesc.pParameters = VarPtr(rootParams(0))
    rootSigDesc.NumStaticSamplers = 0
    rootSigDesc.pStaticSamplers = 0
    rootSigDesc.Flags = D3D12_ROOT_SIGNATURE_FLAG_NONE
    
    Dim pSignatureBlob As LongPtr
    Dim pErrorBlob As LongPtr
    
    Dim hr As Long
    hr = D3D12SerializeRootSignature(rootSigDesc, D3D_ROOT_SIGNATURE_VERSION_1, pSignatureBlob, pErrorBlob)
    LogMsg "D3D12SerializeRootSignature (Compute) returned: " & Hex$(hr)
    
    If hr < 0 Then
        If pErrorBlob <> 0 Then
            LogMsg "RootSignature error: " & PtrToAnsiString(COM_Call1(pErrorBlob, VTBL_Blob_GetBufferPointer))
            COM_Release pErrorBlob
        End If
        CreateComputeRootSignature = False
        Exit Function
    End If
    
    Dim blobPtr As LongPtr: blobPtr = COM_Call1(pSignatureBlob, VTBL_Blob_GetBufferPointer)
    Dim blobSize As LongPtr: blobSize = COM_Call1(pSignatureBlob, VTBL_Blob_GetBufferSize)
    
    Dim rootSigIID As GUID: rootSigIID = IID_ID3D12RootSignature()
    hr = ToHResult(COM_Call6(g_pDevice, VTBL_Device_CreateRootSignature, 0, blobPtr, blobSize, VarPtr(rootSigIID), VarPtr(g_pComputeRootSignature)))
    LogMsg "CreateRootSignature (Compute) returned: " & Hex$(hr)
    
    COM_Release pSignatureBlob
    If pErrorBlob <> 0 Then COM_Release pErrorBlob
    
    CreateComputeRootSignature = (hr >= 0)
    LogMsg "CreateComputeRootSignature: done"
End Function

' ============================================================
' Create Graphics Root Signature
' ============================================================
Private Function CreateGraphicsRootSignature() As Boolean
    LogMsg "CreateGraphicsRootSignature: start"
    
    ' SRV range (t0, t1) - 2 descriptors
    Dim srvRange As D3D12_DESCRIPTOR_RANGE
    srvRange.RangeType = D3D12_DESCRIPTOR_RANGE_TYPE_SRV
    srvRange.NumDescriptors = 2
    srvRange.BaseShaderRegister = 0
    srvRange.RegisterSpace = 0
    srvRange.OffsetInDescriptorsFromTableStart = D3D12_DESCRIPTOR_RANGE_OFFSET_APPEND
    
    ' CBV range (b0) - 1 descriptor
    Dim cbvRange As D3D12_DESCRIPTOR_RANGE
    cbvRange.RangeType = D3D12_DESCRIPTOR_RANGE_TYPE_CBV
    cbvRange.NumDescriptors = 1
    cbvRange.BaseShaderRegister = 0
    cbvRange.RegisterSpace = 0
    cbvRange.OffsetInDescriptorsFromTableStart = D3D12_DESCRIPTOR_RANGE_OFFSET_APPEND
    
    ' Root parameters
    Dim rootParams(0 To 1) As D3D12_ROOT_PARAMETER
    
    ' Parameter 0: SRV table
    rootParams(0).ParameterType = D3D12_ROOT_PARAMETER_TYPE_DESCRIPTOR_TABLE
    rootParams(0).DescriptorTable.NumDescriptorRanges = 1
    rootParams(0).DescriptorTable.pDescriptorRanges = VarPtr(srvRange)
    rootParams(0).ShaderVisibility = D3D12_SHADER_VISIBILITY_VERTEX
    
    ' Parameter 1: CBV table
    rootParams(1).ParameterType = D3D12_ROOT_PARAMETER_TYPE_DESCRIPTOR_TABLE
    rootParams(1).DescriptorTable.NumDescriptorRanges = 1
    rootParams(1).DescriptorTable.pDescriptorRanges = VarPtr(cbvRange)
    rootParams(1).ShaderVisibility = D3D12_SHADER_VISIBILITY_VERTEX
    
    Dim rootSigDesc As D3D12_ROOT_SIGNATURE_DESC
    rootSigDesc.NumParameters = 2
    rootSigDesc.pParameters = VarPtr(rootParams(0))
    rootSigDesc.NumStaticSamplers = 0
    rootSigDesc.pStaticSamplers = 0
    rootSigDesc.Flags = D3D12_ROOT_SIGNATURE_FLAG_NONE
    
    Dim pSignatureBlob As LongPtr
    Dim pErrorBlob As LongPtr
    
    Dim hr As Long
    hr = D3D12SerializeRootSignature(rootSigDesc, D3D_ROOT_SIGNATURE_VERSION_1, pSignatureBlob, pErrorBlob)
    LogMsg "D3D12SerializeRootSignature (Graphics) returned: " & Hex$(hr)
    
    If hr < 0 Then
        If pErrorBlob <> 0 Then
            LogMsg "RootSignature error: " & PtrToAnsiString(COM_Call1(pErrorBlob, VTBL_Blob_GetBufferPointer))
            COM_Release pErrorBlob
        End If
        CreateGraphicsRootSignature = False
        Exit Function
    End If
    
    Dim blobPtr As LongPtr: blobPtr = COM_Call1(pSignatureBlob, VTBL_Blob_GetBufferPointer)
    Dim blobSize As LongPtr: blobSize = COM_Call1(pSignatureBlob, VTBL_Blob_GetBufferSize)
    
    Dim rootSigIID As GUID: rootSigIID = IID_ID3D12RootSignature()
    hr = ToHResult(COM_Call6(g_pDevice, VTBL_Device_CreateRootSignature, 0, blobPtr, blobSize, VarPtr(rootSigIID), VarPtr(g_pGraphicsRootSignature)))
    LogMsg "CreateRootSignature (Graphics) returned: " & Hex$(hr)
    
    COM_Release pSignatureBlob
    If pErrorBlob <> 0 Then COM_Release pErrorBlob
    
    CreateGraphicsRootSignature = (hr >= 0)
    LogMsg "CreateGraphicsRootSignature: done"
End Function

' ============================================================
' Create Pipeline States
' ============================================================
Private Function CreatePipelineStates() As Boolean
    LogMsg "CreatePipelineStates: start"
    
    ' Compile shaders
    Dim pCSBlob As LongPtr
    pCSBlob = CompileShaderFromFile(g_shaderPath, "CSMain", "cs_5_0")
    If pCSBlob = 0 Then
        CreatePipelineStates = False
        Exit Function
    End If
    
    Dim pVSBlob As LongPtr
    pVSBlob = CompileShaderFromFile(g_shaderPath, "VSMain", "vs_5_0")
    If pVSBlob = 0 Then
        COM_Release pCSBlob
        CreatePipelineStates = False
        Exit Function
    End If
    
    Dim pPSBlob As LongPtr
    pPSBlob = CompileShaderFromFile(g_shaderPath, "PSMain", "ps_5_0")
    If pPSBlob = 0 Then
        COM_Release pCSBlob
        COM_Release pVSBlob
        CreatePipelineStates = False
        Exit Function
    End If
    
    ' Create Compute Pipeline State
    Dim computePsoDesc As D3D12_COMPUTE_PIPELINE_STATE_DESC
    computePsoDesc.pRootSignature = g_pComputeRootSignature
    computePsoDesc.CS.pShaderBytecode = COM_Call1(pCSBlob, VTBL_Blob_GetBufferPointer)
    computePsoDesc.CS.BytecodeLength = COM_Call1(pCSBlob, VTBL_Blob_GetBufferSize)
    
    Dim psoIID As GUID: psoIID = IID_ID3D12PipelineState()
    Dim hr As Long
    hr = ToHResult(COM_Call4(g_pDevice, VTBL_Device_CreateComputePipelineState, VarPtr(computePsoDesc), VarPtr(psoIID), VarPtr(g_pComputePipelineState)))
    LogMsg "CreateComputePipelineState returned: " & Hex$(hr)
    
    If hr < 0 Then
        COM_Release pCSBlob
        COM_Release pVSBlob
        COM_Release pPSBlob
        CreatePipelineStates = False
        Exit Function
    End If
    
    ' Create Graphics Pipeline State
    Dim graphicsPsoDesc As D3D12_GRAPHICS_PIPELINE_STATE_DESC
    graphicsPsoDesc.pRootSignature = g_pGraphicsRootSignature
    graphicsPsoDesc.VS.pShaderBytecode = COM_Call1(pVSBlob, VTBL_Blob_GetBufferPointer)
    graphicsPsoDesc.VS.BytecodeLength = COM_Call1(pVSBlob, VTBL_Blob_GetBufferSize)
    graphicsPsoDesc.PS.pShaderBytecode = COM_Call1(pPSBlob, VTBL_Blob_GetBufferPointer)
    graphicsPsoDesc.PS.BytecodeLength = COM_Call1(pPSBlob, VTBL_Blob_GetBufferSize)
    
    ' Blend state
    graphicsPsoDesc.BlendState.RenderTarget(0).BlendEnable = 0
    graphicsPsoDesc.BlendState.RenderTarget(0).SrcBlend = D3D12_BLEND_ONE
    graphicsPsoDesc.BlendState.RenderTarget(0).DestBlend = D3D12_BLEND_ZERO
    graphicsPsoDesc.BlendState.RenderTarget(0).BlendOp = D3D12_BLEND_OP_ADD
    graphicsPsoDesc.BlendState.RenderTarget(0).SrcBlendAlpha = D3D12_BLEND_ONE
    graphicsPsoDesc.BlendState.RenderTarget(0).DestBlendAlpha = D3D12_BLEND_ZERO
    graphicsPsoDesc.BlendState.RenderTarget(0).BlendOpAlpha = D3D12_BLEND_OP_ADD
    graphicsPsoDesc.BlendState.RenderTarget(0).RenderTargetWriteMask = D3D12_COLOR_WRITE_ENABLE_ALL
    
    graphicsPsoDesc.SampleMask = &HFFFFFFFF
    
    ' Rasterizer state
    graphicsPsoDesc.RasterizerState.FillMode = D3D12_FILL_MODE_SOLID
    graphicsPsoDesc.RasterizerState.CullMode = D3D12_CULL_MODE_NONE
    graphicsPsoDesc.RasterizerState.DepthClipEnable = 1
    
    ' Depth stencil state (disabled)
    graphicsPsoDesc.DepthStencilState.DepthEnable = 0
    graphicsPsoDesc.DepthStencilState.StencilEnable = 0
    
    ' No input layout (using SV_VertexID)
    graphicsPsoDesc.InputLayout.pInputElementDescs = 0
    graphicsPsoDesc.InputLayout.NumElements = 0
    
    graphicsPsoDesc.PrimitiveTopologyType = D3D12_PRIMITIVE_TOPOLOGY_TYPE_POINT
    graphicsPsoDesc.NumRenderTargets = 1
    graphicsPsoDesc.RTVFormats(0) = DXGI_FORMAT_R8G8B8A8_UNORM
    graphicsPsoDesc.SampleDesc.count = 1
    
    hr = ToHResult(COM_Call4(g_pDevice, VTBL_Device_CreateGraphicsPipelineState, VarPtr(graphicsPsoDesc), VarPtr(psoIID), VarPtr(g_pGraphicsPipelineState)))
    LogMsg "CreateGraphicsPipelineState returned: " & Hex$(hr)
    
    COM_Release pCSBlob
    COM_Release pVSBlob
    COM_Release pPSBlob
    
    CreatePipelineStates = (hr >= 0)
    LogMsg "CreatePipelineStates: done"
End Function

' ============================================================
' Create Command Lists
' ============================================================
Private Function CreateCommandLists() As Boolean
    LogMsg "CreateCommandLists: start"
    
    Dim cmdListIID As GUID: cmdListIID = IID_ID3D12GraphicsCommandList()
    Dim hr As Long
    
    ' Create one single command list for both Compute and Graphics
    ' Use index 0 allocator for initial creation
    hr = ToHResult(COM_Call7(g_pDevice, VTBL_Device_CreateCommandList, 0, D3D12_COMMAND_LIST_TYPE_DIRECT, g_pCommandAllocators(0), 0, VarPtr(cmdListIID), VarPtr(g_pGraphicsCommandList)))
    
    LogMsg "CreateCommandList returned: " & Hex$(hr)
    If hr < 0 Then
        CreateCommandLists = False
        Exit Function
    End If
    
    ' Close it immediately (it will be reset in RenderFrame)
    COM_Call1 g_pGraphicsCommandList, VTBL_CmdList_Close
    
    CreateCommandLists = True
    LogMsg "CreateCommandLists: done"
End Function

' ============================================================
' Create Buffers
' ============================================================
Private Function CreateBuffers() As Boolean
    LogMsg "CreateBuffers: start"
    
    Dim bufferSize As LongLong
    bufferSize = CLngLng(VERTEX_COUNT) * 16  ' float4 = 16 bytes
    
    ' Default heap for position/color buffers (GPU only)
    Dim defaultHeap As D3D12_HEAP_PROPERTIES
    defaultHeap.cType = D3D12_HEAP_TYPE_DEFAULT
    defaultHeap.CreationNodeMask = 1
    defaultHeap.VisibleNodeMask = 1
    
    ' Upload heap for constant buffer
    Dim uploadHeap As D3D12_HEAP_PROPERTIES
    uploadHeap.cType = D3D12_HEAP_TYPE_UPLOAD
    uploadHeap.CreationNodeMask = 1
    uploadHeap.VisibleNodeMask = 1
    
    ' Buffer resource desc
    Dim bufferDesc As D3D12_RESOURCE_DESC
    bufferDesc.Dimension = D3D12_RESOURCE_DIMENSION_BUFFER
    bufferDesc.Width = bufferSize
    bufferDesc.Height = 1
    bufferDesc.DepthOrArraySize = 1
    bufferDesc.MipLevels = 1
    bufferDesc.SampleDesc.count = 1
    bufferDesc.Layout = 1  ' ROW_MAJOR
    bufferDesc.Flags = D3D12_RESOURCE_FLAG_ALLOW_UNORDERED_ACCESS
    
    Dim resourceIID As GUID: resourceIID = IID_ID3D12Resource()
    Dim hr As Long
    
    ' Create position buffer
    Dim methodAddr As LongPtr
    methodAddr = GetVTableMethod(g_pDevice, VTBL_Device_CreateCommittedResource)
    
    Dim thunk As LongPtr
    thunk = GetCachedThunk8(methodAddr)
    
    Dim args8 As ThunkArgs8
    args8.a1 = g_pDevice
    args8.a2 = VarPtr(defaultHeap)
    args8.a3 = D3D12_HEAP_FLAG_NONE
    args8.a4 = VarPtr(bufferDesc)
    args8.a5 = D3D12_RESOURCE_STATE_COMMON
    args8.a6 = 0
    args8.a7 = VarPtr(resourceIID)
    args8.a8 = VarPtr(g_pPositionBuffer)
    
    hr = ToHResult(CallWindowProcW(thunk, 0, 0, VarPtr(args8), 0))
    LogMsg "CreateCommittedResource (Position) returned: " & Hex$(hr)
    If hr < 0 Then
        CreateBuffers = False
        Exit Function
    End If
    
    ' Create color buffer
    args8.a8 = VarPtr(g_pColorBuffer)
    hr = ToHResult(CallWindowProcW(thunk, 0, 0, VarPtr(args8), 0))
    LogMsg "CreateCommittedResource (Color) returned: " & Hex$(hr)
    If hr < 0 Then
        CreateBuffers = False
        Exit Function
    End If
    
    ' Create constant buffer (256 bytes aligned)
    Dim cbDesc As D3D12_RESOURCE_DESC
    cbDesc.Dimension = D3D12_RESOURCE_DIMENSION_BUFFER
    cbDesc.Width = 256
    cbDesc.Height = 1
    cbDesc.DepthOrArraySize = 1
    cbDesc.MipLevels = 1
    cbDesc.SampleDesc.count = 1
    cbDesc.Layout = 1
    cbDesc.Flags = 0
    
    args8.a2 = VarPtr(uploadHeap)
    args8.a4 = VarPtr(cbDesc)
    args8.a5 = D3D12_RESOURCE_STATE_GENERIC_READ
    args8.a8 = VarPtr(g_pConstantBuffer)
    
    hr = ToHResult(CallWindowProcW(thunk, 0, 0, VarPtr(args8), 0))
    LogMsg "CreateCommittedResource (ConstantBuffer) returned: " & Hex$(hr)
    If hr < 0 Then
        CreateBuffers = False
        Exit Function
    End If
    
    ' Map constant buffer
    Dim readRange As D3D12_RANGE
    hr = ToHResult(COM_Call4(g_pConstantBuffer, VTBL_Resource_Map, 0, VarPtr(readRange), VarPtr(g_pConstantBufferPtr)))
    LogMsg "Map ConstantBuffer returned: " & Hex$(hr) & ", ptr=" & Hex$(g_pConstantBufferPtr)
    If hr < 0 Then
        CreateBuffers = False
        Exit Function
    End If
    
    CreateBuffers = True
    LogMsg "CreateBuffers: done"
End Function

' ============================================================
' Create Views (UAV, SRV, CBV)
' ============================================================
Private Function CreateViews() As Boolean
    LogMsg "CreateViews: start"
    
    Dim heapHandle As D3D12_CPU_DESCRIPTOR_HANDLE
    COM_GetCPUDescriptorHandle g_pSrvUavHeap, heapHandle
    LogMsg "Heap handle start: " & Hex$(heapHandle.ptr)
    
    ' UAV desc
    Dim uavDesc As D3D12_UNORDERED_ACCESS_VIEW_DESC
    uavDesc.Format = DXGI_FORMAT_UNKNOWN
    uavDesc.ViewDimension = D3D12_UAV_DIMENSION_BUFFER
    uavDesc.Buffer_FirstElement = 0
    uavDesc.Buffer_NumElements = VERTEX_COUNT
    uavDesc.Buffer_StructureByteStride = 16  ' float4
    
    ' Slot 0: Position UAV
    COM_Call5 g_pDevice, VTBL_Device_CreateUnorderedAccessView, g_pPositionBuffer, 0, VarPtr(uavDesc), heapHandle.ptr
    heapHandle.ptr = heapHandle.ptr + g_srvUavDescriptorSize
    
    ' Slot 1: Color UAV
    COM_Call5 g_pDevice, VTBL_Device_CreateUnorderedAccessView, g_pColorBuffer, 0, VarPtr(uavDesc), heapHandle.ptr
    heapHandle.ptr = heapHandle.ptr + g_srvUavDescriptorSize
    
    ' SRV desc
    Dim srvDesc As D3D12_SHADER_RESOURCE_VIEW_DESC
    srvDesc.Format = DXGI_FORMAT_UNKNOWN
    srvDesc.ViewDimension = D3D12_SRV_DIMENSION_BUFFER
    srvDesc.Shader4ComponentMapping = D3D12_DEFAULT_SHADER_4_COMPONENT_MAPPING
    srvDesc.Buffer_FirstElement = 0
    srvDesc.Buffer_NumElements = VERTEX_COUNT
    srvDesc.Buffer_StructureByteStride = 16
    
    ' Slot 2: Position SRV
    COM_Call4 g_pDevice, VTBL_Device_CreateShaderResourceView, g_pPositionBuffer, VarPtr(srvDesc), heapHandle.ptr
    heapHandle.ptr = heapHandle.ptr + g_srvUavDescriptorSize
    
    ' Slot 3: Color SRV
    COM_Call4 g_pDevice, VTBL_Device_CreateShaderResourceView, g_pColorBuffer, VarPtr(srvDesc), heapHandle.ptr
    heapHandle.ptr = heapHandle.ptr + g_srvUavDescriptorSize
    
    ' CBV desc
    Dim cbvDesc As D3D12_CONSTANT_BUFFER_VIEW_DESC
    cbvDesc.BufferLocation = COM_Call1(g_pConstantBuffer, VTBL_Resource_GetGPUVirtualAddress)
    cbvDesc.SizeInBytes = 256
    
    ' Slot 4: CBV
    COM_Call3 g_pDevice, VTBL_Device_CreateConstantBufferView, VarPtr(cbvDesc), heapHandle.ptr
    
    CreateViews = True
    LogMsg "CreateViews: done"
End Function

' ============================================================
' Create Fence
' ============================================================
Private Function CreateFence() As Boolean
    LogMsg "CreateFence: start"
    
    Dim fenceIID As GUID: fenceIID = IID_ID3D12Fence()
    Dim hr As Long
    hr = ToHResult(COM_Call5(g_pDevice, VTBL_Device_CreateFence, 0, D3D12_FENCE_FLAG_NONE, VarPtr(fenceIID), VarPtr(g_pFence)))
    LogMsg "CreateFence returned: " & Hex$(hr)
    
    If hr < 0 Then
        CreateFence = False
        Exit Function
    End If
    
    g_fenceValue = 1
    g_fenceEvent = CreateEventW(0, 0, 0, 0)
    
    CreateFence = (g_fenceEvent <> 0)
    LogMsg "CreateFence: done"
End Function

' ============================================================
' Update Constant Buffer
' ============================================================
Private Sub UpdateConstantBuffer()
    Dim params As HarmonographParams
    
    ' Harmonograph parameters
    params.a1 = 50!: params.f1 = 2.01!: params.p1 = 0!: params.d1 = 0.004!
    params.a2 = 50!: params.f2 = 3!: params.p2 = 0!: params.d2 = 0.0065!
    params.a3 = 50!: params.f3 = 3!: params.p3 = 1.57!: params.d3 = 0.008!
    params.a4 = 50!: params.f4 = 2!: params.p4 = 0!: params.d4 = 0.019!
    params.max_num = VERTEX_COUNT
    
    ' Animation time (seconds since start)
    params.time = CSng((Timer - g_startTime))
    
    params.resolutionX = CSng(Width)
    params.resolutionY = CSng(Height)
    
    CopyMemory g_pConstantBufferPtr, VarPtr(params), CLngPtr(LenB(params))
End Sub

' ============================================================
' Wait for previous frame
' ============================================================
'Private Sub WaitForPreviousFrame()
'    Dim fence As LongLong
'    fence = g_fenceValue
'
'    COM_Call3 g_pCommandQueue, VTBL_CmdQueue_Signal, g_pFence, CLngPtr(fence)
'    g_fenceValue = g_fenceValue + 1
'
'    Dim completed As LongLong
'    completed = COM_Call1(g_pFence, VTBL_Fence_GetCompletedValue)
'
'    If completed < fence Then
'        COM_Call3 g_pFence, VTBL_Fence_SetEventOnCompletion, CLngPtr(fence), g_fenceEvent
'        WaitForSingleObject g_fenceEvent, INFINITE
'    End If
'
'    g_frameIndex = CLng(COM_Call1(g_pSwapChain3, VTBL_SwapChain3_GetCurrentBackBufferIndex))
'End Sub


Private Sub MoveToNextFrame()
    Dim currentFenceValue As LongLong
    currentFenceValue = g_fenceValue
    COM_Call3 g_pCommandQueue, VTBL_CmdQueue_Signal, g_pFence, CLngPtr(currentFenceValue)
    
    Dim nextFrameIndex As Long
    nextFrameIndex = CLng(COM_Call1(g_pSwapChain3, VTBL_SwapChain3_GetCurrentBackBufferIndex))
    
    Dim nextFrameFenceValue As LongLong
    nextFrameFenceValue = g_fenceValues(nextFrameIndex)
    
    If COM_Call1(g_pFence, VTBL_Fence_GetCompletedValue) < nextFrameFenceValue Then
        COM_Call3 g_pFence, VTBL_Fence_SetEventOnCompletion, CLngPtr(nextFrameFenceValue), g_fenceEvent
        WaitForSingleObject g_fenceEvent, INFINITE
    End If
    
    g_fenceValues(nextFrameIndex) = currentFenceValue + 1
    g_fenceValue = currentFenceValue + 1
    g_frameIndex = nextFrameIndex
End Sub

' ============================================================
' Render frame
' ============================================================
Private Sub RenderFrame()
    ' Update constant buffer
    UpdateConstantBuffer
    
    COM_Call1 g_pCommandAllocators(g_frameIndex), VTBL_CmdAlloc_Reset
    
    COM_Call3 g_pGraphicsCommandList, VTBL_CmdList_Reset, g_pCommandAllocators(g_frameIndex), g_pComputePipelineState
    
    Dim heapPtr As LongPtr: heapPtr = g_pSrvUavHeap
    COM_Call3 g_pGraphicsCommandList, VTBL_CmdList_SetDescriptorHeaps, 1, VarPtr(heapPtr)
    
    ' ==========================================
    ' [COMPUTE PASS]
    ' ==========================================
    COM_Call2 g_pGraphicsCommandList, VTBL_CmdList_SetComputeRootSignature, g_pComputeRootSignature
    
    Dim gpuHandle As D3D12_GPU_DESCRIPTOR_HANDLE
    COM_GetGPUDescriptorHandle g_pSrvUavHeap, gpuHandle
    
    ' Table 0: UAVs
    COM_Call3 g_pGraphicsCommandList, VTBL_CmdList_SetComputeRootDescriptorTable, 0, gpuHandle.ptr
    ' Table 1: CBV
    Dim cbvOffsetHandle As LongLong
    cbvOffsetHandle = gpuHandle.ptr + CLngLng(g_srvUavDescriptorSize) * 4
    COM_Call3 g_pGraphicsCommandList, VTBL_CmdList_SetComputeRootDescriptorTable, 1, cbvOffsetHandle
    
    ' Dispatch
    Dim dispatchX As Long
    dispatchX = (VERTEX_COUNT + 63) \ 64
    COM_Call4 g_pGraphicsCommandList, VTBL_CmdList_Dispatch, dispatchX, 1, 1
    
    ' Resource Barrier: UAV -> SRV
    Dim barriers(0 To 1) As D3D12_RESOURCE_BARRIER
    barriers(0).cType = D3D12_RESOURCE_BARRIER_TYPE_TRANSITION
    barriers(0).Transition.pResource = g_pPositionBuffer
    barriers(0).Transition.Subresource = D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES
    barriers(0).Transition.StateBefore = D3D12_RESOURCE_STATE_UNORDERED_ACCESS
    barriers(0).Transition.StateAfter = D3D12_RESOURCE_STATE_NON_PIXEL_SHADER_RESOURCE
    
    barriers(1).cType = D3D12_RESOURCE_BARRIER_TYPE_TRANSITION
    barriers(1).Transition.pResource = g_pColorBuffer
    barriers(1).Transition.Subresource = D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES
    barriers(1).Transition.StateBefore = D3D12_RESOURCE_STATE_UNORDERED_ACCESS
    barriers(1).Transition.StateAfter = D3D12_RESOURCE_STATE_NON_PIXEL_SHADER_RESOURCE
    
    COM_Call3 g_pGraphicsCommandList, VTBL_CmdList_ResourceBarrier, 2, VarPtr(barriers(0))
    
    ' ==========================================
    ' [GRAPHICS PASS]
    ' ==========================================
    COM_Call2 g_pGraphicsCommandList, VTBL_CmdList_SetGraphicsRootSignature, g_pGraphicsRootSignature
    COM_Call2 g_pGraphicsCommandList, VTBL_CmdList_SetPipelineState, g_pGraphicsPipelineState
    
    ' Table 0: SRVs
    Dim srvOffsetHandle As LongLong
    srvOffsetHandle = gpuHandle.ptr + CLngLng(g_srvUavDescriptorSize) * 2
    COM_Call3 g_pGraphicsCommandList, VTBL_CmdList_SetGraphicsRootDescriptorTable, 0, srvOffsetHandle
    ' Table 1: CBV
    COM_Call3 g_pGraphicsCommandList, VTBL_CmdList_SetGraphicsRootDescriptorTable, 1, cbvOffsetHandle
    
    ' Viewport & Scissor
    Dim vp As D3D12_VIEWPORT
    vp.Width = CSng(Width): vp.Height = CSng(Height): vp.MaxDepth = 1!
    COM_Call3 g_pGraphicsCommandList, VTBL_CmdList_RSSetViewports, 1, VarPtr(vp)
    
    Dim sr As D3D12_RECT
    sr.Right = Width: sr.Bottom = Height
    COM_Call3 g_pGraphicsCommandList, VTBL_CmdList_RSSetScissorRects, 1, VarPtr(sr)
    
    ' Barrier: Present -> RenderTarget
    Dim rtBarrier As D3D12_RESOURCE_BARRIER
    rtBarrier.cType = D3D12_RESOURCE_BARRIER_TYPE_TRANSITION
    rtBarrier.Transition.pResource = g_pRenderTargets(g_frameIndex)
    rtBarrier.Transition.Subresource = D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES
    rtBarrier.Transition.StateBefore = D3D12_RESOURCE_STATE_PRESENT
    rtBarrier.Transition.StateAfter = D3D12_RESOURCE_STATE_RENDER_TARGET
    COM_Call3 g_pGraphicsCommandList, VTBL_CmdList_ResourceBarrier, 1, VarPtr(rtBarrier)
    
    ' RTV & Clear
    Dim rtvHandle As D3D12_CPU_DESCRIPTOR_HANDLE
    COM_GetCPUDescriptorHandle g_pRtvHeap, rtvHandle
    rtvHandle.ptr = rtvHandle.ptr + CLngPtr(g_frameIndex) * CLngPtr(g_rtvDescriptorSize)
    
    Dim clearColor(0 To 3) As Single
    clearColor(0) = 0.05!: clearColor(1) = 0.05!: clearColor(2) = 0.1!: clearColor(3) = 1!
    
    COM_Call5 g_pGraphicsCommandList, VTBL_CmdList_OMSetRenderTargets, 1, VarPtr(rtvHandle), 1, 0
    COM_Call5 g_pGraphicsCommandList, VTBL_CmdList_ClearRenderTargetView, rtvHandle.ptr, VarPtr(clearColor(0)), 0, 0
    
    ' Draw
    COM_Call2 g_pGraphicsCommandList, VTBL_CmdList_IASetPrimitiveTopology, 1 ' POINTLIST
    COM_Call5 g_pGraphicsCommandList, VTBL_CmdList_DrawInstanced, VERTEX_COUNT, 1, 0, 0
    
    ' Barrier: RenderTarget -> Present
    rtBarrier.Transition.StateBefore = D3D12_RESOURCE_STATE_RENDER_TARGET
    rtBarrier.Transition.StateAfter = D3D12_RESOURCE_STATE_PRESENT
    COM_Call3 g_pGraphicsCommandList, VTBL_CmdList_ResourceBarrier, 1, VarPtr(rtBarrier)
    
    ' Barrier: SRV -> UAV
    barriers(0).Transition.StateBefore = D3D12_RESOURCE_STATE_NON_PIXEL_SHADER_RESOURCE
    barriers(0).Transition.StateAfter = D3D12_RESOURCE_STATE_UNORDERED_ACCESS
    barriers(1).Transition.StateBefore = D3D12_RESOURCE_STATE_NON_PIXEL_SHADER_RESOURCE
    barriers(1).Transition.StateAfter = D3D12_RESOURCE_STATE_UNORDERED_ACCESS
    COM_Call3 g_pGraphicsCommandList, VTBL_CmdList_ResourceBarrier, 2, VarPtr(barriers(0))
    
    ' Close & Execute
    COM_Call1 g_pGraphicsCommandList, VTBL_CmdList_Close
    
    Dim ptrList As LongPtr: ptrList = g_pGraphicsCommandList
    COM_Call3 g_pCommandQueue, VTBL_CmdQueue_ExecuteCommandLists, 1, VarPtr(ptrList)
    
    ' Present
    COM_Call3 g_pSwapChain, VTBL_SwapChain_Present, 1, 0 ' VSync ON
    ' COM_Call3 g_pSwapChain, VTBL_SwapChain_Present, 0, 0 ' VSync OFF
    
    MoveToNextFrame
End Sub

' ============================================================
' Wait for GPU to finish all work (for cleanup)
' ============================================================
Private Sub WaitForGpu()
    g_fenceValue = g_fenceValue + 1
    
    Call COM_Call3(g_pCommandQueue, VTBL_CmdQueue_Signal, g_pFence, CLngPtr(g_fenceValue))
    
    If COM_Call1(g_pFence, VTBL_Fence_GetCompletedValue) < g_fenceValue Then
        Call COM_Call3(g_pFence, VTBL_Fence_SetEventOnCompletion, CLngPtr(g_fenceValue), g_fenceEvent)
        WaitForSingleObject g_fenceEvent, INFINITE
    End If
End Sub

' ============================================================
' Cleanup
' ============================================================
Private Sub CleanupD3D12()
    LogMsg "CleanupD3D12: start"
    
    WaitForGpu
    
    If g_fenceEvent <> 0 Then CloseHandle g_fenceEvent: g_fenceEvent = 0
    
    If g_pConstantBuffer <> 0 Then
        COM_Call3 g_pConstantBuffer, VTBL_Resource_Unmap, 0, 0
        COM_Release g_pConstantBuffer
        g_pConstantBuffer = 0
    End If
    
    If g_pColorBuffer <> 0 Then COM_Release g_pColorBuffer: g_pColorBuffer = 0
    If g_pPositionBuffer <> 0 Then COM_Release g_pPositionBuffer: g_pPositionBuffer = 0
    If g_pFence <> 0 Then COM_Release g_pFence: g_pFence = 0
    'If g_pComputeCommandList <> 0 Then COM_Release g_pComputeCommandList: g_pComputeCommandList = 0
    If g_pGraphicsCommandList <> 0 Then COM_Release g_pGraphicsCommandList: g_pGraphicsCommandList = 0
    If g_pGraphicsPipelineState <> 0 Then COM_Release g_pGraphicsPipelineState: g_pGraphicsPipelineState = 0
    If g_pComputePipelineState <> 0 Then COM_Release g_pComputePipelineState: g_pComputePipelineState = 0
    If g_pGraphicsRootSignature <> 0 Then COM_Release g_pGraphicsRootSignature: g_pGraphicsRootSignature = 0
    If g_pComputeRootSignature <> 0 Then COM_Release g_pComputeRootSignature: g_pComputeRootSignature = 0
    'If g_pComputeCommandAllocator <> 0 Then COM_Release g_pComputeCommandAllocator: g_pComputeCommandAllocator = 0
    'If g_pGraphicsCommandAllocator <> 0 Then COM_Release g_pGraphicsCommandAllocator: g_pGraphicsCommandAllocator = 0

    Dim j As Long
    For j = 0 To FRAME_COUNT - 1
        If g_pCommandAllocators(j) <> 0 Then COM_Release g_pCommandAllocators(j): g_pCommandAllocators(j) = 0
    Next j
    
    Dim i As Long
    For i = 0 To FRAME_COUNT - 1
        If g_pRenderTargets(i) <> 0 Then COM_Release g_pRenderTargets(i): g_pRenderTargets(i) = 0
    Next i
    
    If g_pSrvUavHeap <> 0 Then COM_Release g_pSrvUavHeap: g_pSrvUavHeap = 0
    If g_pRtvHeap <> 0 Then COM_Release g_pRtvHeap: g_pRtvHeap = 0
    If g_pSwapChain3 <> 0 Then COM_Release g_pSwapChain3: g_pSwapChain3 = 0
    If g_pSwapChain <> 0 Then COM_Release g_pSwapChain: g_pSwapChain = 0
    If g_pCommandQueue <> 0 Then COM_Release g_pCommandQueue: g_pCommandQueue = 0
    If g_pDevice <> 0 Then COM_Release g_pDevice: g_pDevice = 0
    
    LogMsg "CleanupD3D12: done"
End Sub

' ============================================================
' Entry point
' ============================================================
Public Sub Main()
    LogOpen
    On Error GoTo EH

    LogMsg "Main: start"
    
    ' Get shader path (same directory as Excel file)
    g_shaderPath = ThisWorkbook.Path & "\hello.hlsl"
    LogMsg "Shader path: " & g_shaderPath
    
    ' Check if shader file exists
    If Dir(g_shaderPath) = "" Then
        MsgBox "Shader file not found: " & g_shaderPath, vbCritical
        GoTo FIN
    End If

    Dim wcex As WNDCLASSEXW
    Dim hInstance As LongPtr
    hInstance = GetModuleHandleW(0)

    wcex.cbSize = LenB(wcex)
    wcex.style = CS_HREDRAW Or CS_VREDRAW Or CS_OWNDC
    wcex.lpfnWndProc = VBA.CLngPtr(AddressOf WindowProc)
    wcex.hInstance = hInstance
    wcex.hIcon = LoadIconW(0, IDI_APPLICATION)
    wcex.hCursor = LoadCursorW(0, IDC_ARROW)
    wcex.hbrBackground = (COLOR_WINDOW + 1)
    wcex.lpszClassName = StrPtr(CLASS_NAME)
    wcex.hIconSm = LoadIconW(0, IDI_APPLICATION)

    If RegisterClassExW(wcex) = 0 Then
        MsgBox "RegisterClassExW failed.", vbCritical
        GoTo FIN
    End If

    g_hWnd = CreateWindowExW(0, StrPtr(CLASS_NAME), StrPtr(WINDOW_NAME), WS_OVERLAPPEDWINDOW, _
                            CW_USEDEFAULT, CW_USEDEFAULT, Width, Height, 0, 0, hInstance, 0)
    If g_hWnd = 0 Then
        MsgBox "CreateWindowExW failed.", vbCritical
        GoTo FIN
    End If

    ShowWindow g_hWnd, SW_SHOWDEFAULT
    UpdateWindow g_hWnd

    If Not InitD3D12(g_hWnd) Then
        MsgBox "Failed to initialize DirectX 12.", vbCritical
        GoTo FIN
    End If

    If Not CreateComputeRootSignature() Then
        MsgBox "Failed to create compute root signature.", vbCritical
        GoTo FIN
    End If

    If Not CreateGraphicsRootSignature() Then
        MsgBox "Failed to create graphics root signature.", vbCritical
        GoTo FIN
    End If

    If Not CreatePipelineStates() Then
        MsgBox "Failed to create pipeline states.", vbCritical
        GoTo FIN
    End If

    If Not CreateCommandLists() Then
        MsgBox "Failed to create command lists.", vbCritical
        GoTo FIN
    End If

    If Not CreateBuffers() Then
        MsgBox "Failed to create buffers.", vbCritical
        GoTo FIN
    End If

    If Not CreateViews() Then
        MsgBox "Failed to create views.", vbCritical
        GoTo FIN
    End If

    If Not CreateFence() Then
        MsgBox "Failed to create fence.", vbCritical
        GoTo FIN
    End If

    ' Initialize animation timer
    g_startTime = Timer
    g_frameCount = 0

    ' Message loop
    Dim msg As MSGW
    Dim quit As Boolean: quit = False
    Dim frame As Long: frame = 0

    LogMsg "Loop: start"
    Do While Not quit
        If PeekMessageW(msg, 0, 0, 0, PM_REMOVE) <> 0 Then
            If msg.message = WM_QUIT Then
                quit = True
            Else
                TranslateMessage msg
                DispatchMessageW msg
            End If
        Else
            RenderFrame

            frame = frame + 1
            If (frame Mod 60) = 0 Then
                LogMsg "Loop: frame=" & frame
                DoEvents
            End If
        End If
    Loop

FIN:
    LogMsg "Cleanup: start"
    FreeThunks
    CleanupD3D12
    If g_hWnd <> 0 Then DestroyWindow g_hWnd
    g_hWnd = 0

    LogMsg "Cleanup: done"
    LogMsg "Main: end"
    LogClose
    Exit Sub

EH:
    LogMsg "ERROR: " & Err.Number & " / " & Err.Description
    Resume FIN
End Sub


