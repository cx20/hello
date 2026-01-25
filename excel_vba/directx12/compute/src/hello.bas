Attribute VB_Name = "hello"
Option Explicit

' ============================================================
'  Excel VBA (64-bit) + DirectX 12 - Compute Shader Harmonograph
'  *** BATCH THUNK OPTIMIZED VERSION ***
'
'  Multiple COM calls batched into single native code blocks:
'  - ComputePassBatch: 5 calls -> 1 thunk
'  - GraphicsDrawBatch: 8 calls -> 1 thunk
'  Reduces VBA->Native transitions from ~25 to ~12
' ============================================================

' -----------------------------
' Profiler constants
' -----------------------------
Public Const PROF_WINDOW_FRAMES As Long = 100
Public Const PROF_LOG_PATH As String = "C:\TEMP\dx12_harmonograph_batch.log"

Public Const PROF_UPDATE As Long = 0
Public Const PROF_RESET As Long = 1
Public Const PROF_COMPUTE As Long = 2
Public Const PROF_BARRIER1 As Long = 3
Public Const PROF_GRAPHICS As Long = 4
Public Const PROF_BARRIER2 As Long = 5
Public Const PROF_EXECUTE As Long = 6
Public Const PROF_PRESENT As Long = 7
Public Const PROF_FRAME_SYNC As Long = 8
Public Const PROF_TOTAL As Long = 9
Public Const PROF_COUNT As Long = 10

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
Private Const D3D12_PRIMITIVE_TOPOLOGY_TYPE_LINE As Long = 2
Private Const D3D_PRIMITIVE_TOPOLOGY_POINTLIST As Long = 1
Private Const D3D_PRIMITIVE_TOPOLOGY_LINESTRIP As Long = 3

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
Private Const ONVTBL_IUnknown_QueryInterface As Long = 0
Private Const ONVTBL_IUnknown_AddRef As Long = 1
Private Const ONVTBL_IUnknown_Release As Long = 2

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
Private Const VTBL_Device_GetDeviceRemovedReason As Long = 37
Private Const VTBL_D3D12Debug_EnableDebugLayer As Long = 3

Private Const VTBL_DescHeap_GetCPUDescriptorHandleForHeapStart As Long = 9
Private Const VTBL_DescHeap_GetGPUDescriptorHandleForHeapStart As Long = 10

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

Private Const VTBL_CmdQueue_ExecuteCommandLists As Long = 10
Private Const VTBL_CmdQueue_Signal As Long = 14

Private Const VTBL_Fence_GetCompletedValue As Long = 8
Private Const VTBL_Fence_SetEventOnCompletion As Long = 9

Private Const VTBL_CmdAlloc_Reset As Long = 8

Private Const VTBL_Resource_Map As Long = 8
Private Const VTBL_Resource_Unmap As Long = 9
Private Const VTBL_Resource_GetGPUVirtualAddress As Long = 11

Private Const VTBL_SwapChain_Present As Long = 8
Private Const VTBL_SwapChain_GetBuffer As Long = 9

Private Const VTBL_SwapChain3_GetCurrentBackBufferIndex As Long = 36

Private Const VTBL_Factory_CreateSwapChain As Long = 10

Private Const VTBL_Blob_GetBufferPointer As Long = 3
Private Const VTBL_Blob_GetBufferSize As Long = 4

Private Const CLASS_NAME As String = "HarmonographDX12VBA"
Private Const WINDOW_NAME As String = "DirectX 12 Compute Harmonograph (VBA64) - BATCH THUNKS"

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
    padding1 As Single: padding2 As Single: padding3 As Single
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
' Profiler variables
Private g_profFreq As Double
Private g_profFreqInv As Double
Private g_profT0 As Double
Private g_profPrev As Double
Private g_profAcc(0 To PROF_COUNT - 1) As Double
Private g_profFrames As Long

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

' Thunk for descriptor handle retrieval
Private p_thunkRetStruct As LongPtr

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

' *** V3 OPTIMIZATION: Pre-bound dedicated thunks for hot path ***
Private g_thunk_SwapChain3_GetCurrentBackBufferIndex As LongPtr
Private g_thunk_Fence_GetCompletedValue As LongPtr
Private g_thunk_Fence_SetEventOnCompletion As LongPtr
Private g_thunk_CmdQueue_ExecuteCommandLists As LongPtr
Private g_thunk_CmdQueue_Signal As LongPtr
Private g_thunk_SwapChain_Present As LongPtr
Private g_thunk_CmdList_Close As LongPtr

' *** PERF: Additional pre-bound thunks for RenderFrame ***
Private g_thunk_CmdAlloc_Reset As LongPtr
Private g_thunk_CmdList_Reset As LongPtr
Private g_thunk_CmdList_SetDescriptorHeaps As LongPtr
Private g_thunk_CmdList_SetComputeRootSignature As LongPtr
Private g_thunk_CmdList_SetComputeRootDescriptorTable As LongPtr
Private g_thunk_CmdList_Dispatch As LongPtr
Private g_thunk_CmdList_ResourceBarrier As LongPtr
Private g_thunk_CmdList_SetGraphicsRootSignature As LongPtr
Private g_thunk_CmdList_SetPipelineState As LongPtr
Private g_thunk_CmdList_SetGraphicsRootDescriptorTable As LongPtr
Private g_thunk_CmdList_RSSetViewports As LongPtr
Private g_thunk_CmdList_RSSetScissorRects As LongPtr
Private g_thunk_CmdList_OMSetRenderTargets As LongPtr
Private g_thunk_CmdList_ClearRenderTargetView As LongPtr
Private g_thunk_CmdList_IASetPrimitiveTopology As LongPtr
Private g_thunk_CmdList_DrawInstanced As LongPtr
Private g_thunk_DescHeap_GetGPUHandle As LongPtr
Private g_thunk_DescHeap_GetCPUHandle As LongPtr

' *** V3 OPTIMIZATION: Pre-allocated reusable argument structures ***
Private g_args1_GetBackBufferIndex As ThunkArgs1
Private g_args1_GetFenceValue As ThunkArgs1
Private g_args3_SetEventOnCompletion As ThunkArgs3
Private g_args3_ExecuteCommandLists As ThunkArgs3
Private g_args3_Signal As ThunkArgs3
Private g_args3_Present As ThunkArgs3
Private g_args1_CmdListClose As ThunkArgs1

' *** PERF: Additional pre-allocated argument structures for RenderFrame ***
Private g_args1_CmdAllocReset As ThunkArgs1
Private g_args3_CmdListReset As ThunkArgs3
Private g_args3_SetDescHeaps As ThunkArgs3
Private g_args2_SetComputeRootSig As ThunkArgs2
Private g_args3_SetComputeDescTable0 As ThunkArgs3
Private g_args3_SetComputeDescTable1 As ThunkArgs3
Private g_args4_Dispatch As ThunkArgs4
Private g_args3_ResourceBarrier As ThunkArgs3
Private g_args2_SetGraphicsRootSig As ThunkArgs2
Private g_args2_SetPipelineState As ThunkArgs2
Private g_args3_SetGraphicsDescTable0 As ThunkArgs3
Private g_args3_SetGraphicsDescTable1 As ThunkArgs3
Private g_args3_RSSetViewports As ThunkArgs3
Private g_args3_RSSetScissorRects As ThunkArgs3
Private g_args5_OMSetRenderTargets As ThunkArgs5
Private g_args5_ClearRTV As ThunkArgs5
Private g_args2_IASetTopology As ThunkArgs2
Private g_args5_DrawInstanced As ThunkArgs5
Private g_args2_GetGPUHandle As ThunkArgs2
Private g_args2_GetCPUHandle As ThunkArgs2

' *** PERF: Pre-allocated global structures for RenderFrame ***
Private g_heapPtr As LongPtr
Private g_gpuHandle As D3D12_GPU_DESCRIPTOR_HANDLE
Private g_rtvHandle As D3D12_CPU_DESCRIPTOR_HANDLE
Private g_viewport As D3D12_VIEWPORT
Private g_scissorRect As D3D12_RECT
Private g_clearColor(0 To 3) As Single
Private g_barriers(0 To 1) As D3D12_RESOURCE_BARRIER
Private g_rtBarrier As D3D12_RESOURCE_BARRIER
Private g_dispatchX As Long
Private g_cbvOffset As LongLong
Private g_srvOffset As LongLong
Private g_cmdListPtr As LongPtr

Private g_hotPathThunksBound As Boolean

' Animation
Private g_startTime As Double
Private g_frameCount As Long

' Harmonograph animation parameters
Private g_A1 As Single, g_f1 As Single, g_p1 As Single, g_d1 As Single
Private g_A2 As Single, g_f2 As Single, g_p2 As Single, g_d2 As Single
Private g_A3 As Single, g_f3 As Single, g_p3 As Single, g_d3 As Single
Private g_A4 As Single, g_f4 As Single, g_p4 As Single, g_d4 As Single
Private Const PI2 As Single = 6.283185!

' Pre-allocated constant buffer structure
Private g_cbParams As HarmonographParams
Private g_cbParamsSize As LongPtr

' *** BATCH THUNK: Argument structures ***
' ComputePassBatch args (48 bytes, 8-byte aligned)
Private Type BatchComputeArgs
    pCommandList As LongPtr     ' +0
    pHeapPtrArray As LongPtr    ' +8
    pComputeRootSig As LongPtr  ' +16
    gpuHandle_UAV As LongLong   ' +24
    gpuHandle_CBV As LongLong   ' +32
    dispatchX As Long           ' +40
    padding As Long             ' +44
End Type

' GraphicsDrawBatch args (72 bytes, 8-byte aligned)
Private Type BatchGraphicsArgs
    pCommandList As LongPtr          ' +0
    pGraphicsRootSig As LongPtr      ' +8
    pGraphicsPipelineState As LongPtr ' +16
    gpuHandle_SRV As LongLong        ' +24
    gpuHandle_CBV As LongLong        ' +32
    pViewport As LongPtr             ' +40
    pScissorRect As LongPtr          ' +48
    topology As Long                 ' +56
    vertexCount As Long              ' +60
End Type

' *** BATCH THUNK: Thunk pointers and args ***
Private g_thunk_ComputePassBatch As LongPtr
Private g_thunk_GraphicsDrawBatch As LongPtr
Private g_batchComputeArgs As BatchComputeArgs
Private g_batchGraphicsArgs As BatchGraphicsArgs
Private g_batchThunksBound As Boolean

#If VBA7 Then
    Private Declare PtrSafe Function GetModuleHandleW Lib "kernel32" (ByVal lpModuleName As LongPtr) As LongPtr
    Private Declare PtrSafe Function LoadIconW Lib "user32" (ByVal hInstance As LongPtr, ByVal lpIconName As LongPtr) As LongPtr
    Private Declare PtrSafe Function LoadCursorW Lib "user32" (ByVal hInstance As LongPtr, ByVal lpCursorName As LongPtr) As LongPtr
    Private Declare PtrSafe Function RegisterClassExW Lib "user32" (ByRef lpwcx As WNDCLASSEXW) As Integer
    Private Declare PtrSafe Function CreateWindowExW Lib "user32" (ByVal dwExStyle As Long, ByVal lpClassName As LongPtr, ByVal lpWindowName As LongPtr, ByVal dwStyle As Long, ByVal x As Long, ByVal y As Long, ByVal nWidth As Long, ByVal nHeight As Long, ByVal hWndParent As LongPtr, ByVal hMenu As LongPtr, ByVal hInstance As LongPtr, ByVal lpParam As LongPtr) As LongPtr
    Private Declare PtrSafe Function ShowWindow Lib "user32" (ByVal hWnd As LongPtr, ByVal nCmdShow As Long) As Long
    Private Declare PtrSafe Function UpdateWindow Lib "user32" (ByVal hWnd As LongPtr) As Long
    Private Declare PtrSafe Function DestroyWindow Lib "user32" (ByVal hWnd As LongPtr) As Long
    Private Declare PtrSafe Function PeekMessageW Lib "user32" (ByRef lpMsg As MSGW, ByVal hWnd As LongPtr, ByVal wMsgFilterMin As Long, ByVal wMsgFilterMax As Long, ByVal wRemoveMsg As Long) As Long
    Private Declare PtrSafe Function TranslateMessage Lib "user32" (ByRef lpMsg As MSGW) As Long
    Private Declare PtrSafe Function DispatchMessageW Lib "user32" (ByRef lpMsg As MSGW) As LongPtr
    Private Declare PtrSafe Sub PostQuitMessage Lib "user32" (ByVal nExitCode As Long)
    Private Declare PtrSafe Function DefWindowProcW Lib "user32" (ByVal hWnd As LongPtr, ByVal uMsg As Long, ByVal wParam As LongPtr, ByVal lParam As LongPtr) As LongPtr
    Private Declare PtrSafe Function CreateEventW Lib "kernel32" (ByVal lpEventAttributes As LongPtr, ByVal bManualReset As Long, ByVal bInitialState As Long, ByVal lpName As LongPtr) As LongPtr
    Private Declare PtrSafe Function WaitForSingleObject Lib "kernel32" (ByVal hHandle As LongPtr, ByVal dwMilliseconds As Long) As Long
    Private Declare PtrSafe Function CloseHandle Lib "kernel32" (ByVal hObject As LongPtr) As Long
    Private Declare PtrSafe Function CallWindowProcW Lib "user32" (ByVal lpPrevWndFunc As LongPtr, ByVal hWnd As LongPtr, ByVal msg As LongPtr, ByVal wParam As LongPtr, ByVal lParam As LongPtr) As LongPtr
    Private Declare PtrSafe Function D3D12CreateDevice Lib "d3d12.dll" (ByVal pAdapter As LongPtr, ByVal MinimumFeatureLevel As Long, ByRef riid As GUID, ByRef ppDevice As LongPtr) As Long
    Private Declare PtrSafe Function CreateDXGIFactory1 Lib "dxgi.dll" (ByRef riid As GUID, ByRef ppFactory As LongPtr) As Long
    Private Declare PtrSafe Function D3D12SerializeRootSignature Lib "d3d12.dll" (ByRef pRootSignature As D3D12_ROOT_SIGNATURE_DESC, ByVal Version As Long, ByRef ppBlob As LongPtr, ByRef ppErrorBlob As LongPtr) As Long
    Private Declare PtrSafe Function D3D12GetDebugInterface Lib "d3d12.dll" (ByRef riid As GUID, ByRef ppDebug As LongPtr) As Long
    Private Declare PtrSafe Function GetProcAddress Lib "kernel32" (ByVal hModule As LongPtr, ByVal lpProcName As LongPtr) As LongPtr
    Private Declare PtrSafe Function LoadLibraryW Lib "kernel32" (ByVal lpLibFileName As LongPtr) As LongPtr
    Private Declare PtrSafe Function FreeLibrary Lib "kernel32" (ByVal hLibModule As LongPtr) As Long
    Private Declare PtrSafe Function CreateDirectoryW Lib "kernel32" (ByVal lpPathName As LongPtr, ByVal lpSecurityAttributes As LongPtr) As Long
    Private Declare PtrSafe Function CreateFileW Lib "kernel32" (ByVal lpFileName As LongPtr, ByVal dwDesiredAccess As Long, ByVal dwShareMode As Long, ByVal lpSecurityAttributes As LongPtr, ByVal dwCreationDisposition As Long, ByVal dwFlagsAndAttributes As Long, ByVal hTemplateFile As LongPtr) As LongPtr
    Private Declare PtrSafe Function WriteFile Lib "kernel32" (ByVal hFile As LongPtr, ByRef lpBuffer As Any, ByVal nNumberOfBytesToWrite As Long, ByRef lpNumberOfBytesWritten As Long, ByVal lpOverlapped As LongPtr) As Long
    Private Declare PtrSafe Function FlushFileBuffers Lib "kernel32" (ByVal hFile As LongPtr) As Long
    Private Declare PtrSafe Function lstrlenA Lib "kernel32" (ByVal lpString As LongPtr) As Long
    Private Declare PtrSafe Sub RtlMoveMemory Lib "kernel32" (ByRef Destination As Any, ByVal Source As LongPtr, ByVal Length As Long)
    Private Declare PtrSafe Sub RtlMoveMemoryFromPtr Lib "kernel32" Alias "RtlMoveMemory" (ByVal Destination As LongPtr, ByRef Source As Any, ByVal Length As Long)
    Private Declare PtrSafe Sub CopyMemory Lib "kernel32" Alias "RtlMoveMemory" (ByVal Destination As LongPtr, ByVal Source As LongPtr, ByVal Length As LongPtr)
    Private Declare PtrSafe Function VirtualAlloc Lib "kernel32" (ByVal lpAddress As LongPtr, ByVal dwSize As LongPtr, ByVal flAllocationType As Long, ByVal flProtect As Long) As LongPtr
    Private Declare PtrSafe Function VirtualFree Lib "kernel32" (ByVal lpAddress As LongPtr, ByVal dwSize As LongPtr, ByVal dwFreeType As Long) As Long
#End If

' ============================================================
' DX12 CPU Profiler
' ============================================================
Private Type LARGE_INTEGER_PROF
    QuadPart As LongLong
End Type

#If VBA7 Then
    Private Declare PtrSafe Function QueryPerformanceCounter Lib "kernel32" (ByRef lpPerformanceCount As LARGE_INTEGER_PROF) As Long
    Private Declare PtrSafe Function QueryPerformanceFrequency Lib "kernel32" (ByRef lpFrequency As LARGE_INTEGER_PROF) As Long
#End If

Public Sub ProfilerInit()
    Dim f As LARGE_INTEGER_PROF
    If QueryPerformanceFrequency(f) = 0 Then
        g_profFreq = 0#: g_profFreqInv = 0#
    Else
        g_profFreq = CDbl(f.QuadPart)
        g_profFreqInv = 1000# / g_profFreq
    End If
End Sub

Public Sub ProfilerReset()
    Dim i As Long
    For i = 0 To PROF_COUNT - 1: g_profAcc(i) = 0#: Next i
    g_profFrames = 0
End Sub

Public Sub ProfilerBeginFrame()
    Dim c As LARGE_INTEGER_PROF
    QueryPerformanceCounter c
    g_profT0 = CDbl(c.QuadPart) * g_profFreqInv
    g_profPrev = g_profT0
End Sub

Public Sub ProfilerMark(ByVal sectionId As Long)
    Dim c As LARGE_INTEGER_PROF
    QueryPerformanceCounter c
    Dim t As Double: t = CDbl(c.QuadPart) * g_profFreqInv
    If sectionId >= 0 And sectionId < PROF_COUNT Then g_profAcc(sectionId) = g_profAcc(sectionId) + (t - g_profPrev)
    g_profPrev = t
End Sub

Public Sub ProfilerEndFrame()
    Dim c As LARGE_INTEGER_PROF
    QueryPerformanceCounter c
    Dim t As Double: t = CDbl(c.QuadPart) * g_profFreqInv
    g_profAcc(PROF_TOTAL) = g_profAcc(PROF_TOTAL) + (t - g_profT0)
    g_profPrev = t
    g_profFrames = g_profFrames + 1
    If g_profFrames Mod PROF_WINDOW_FRAMES = 0 Then ProfilerDumpAverage
End Sub

Public Sub ProfilerFlush()
    If g_profFrames > 0 Then ProfilerDumpAverage
End Sub

Private Sub ProfilerDumpAverage()
    On Error Resume Next
    Dim denom As Double: denom = CDbl(g_profFrames)
    If denom <= 0# Then Exit Sub
    
    Dim s As String
    s = "=== DX12 HARMONOGRAPH PROFILE V3 (avg ms over " & CStr(g_profFrames) & " frames) ===" & vbCrLf & _
        "  Update:    " & Format$(g_profAcc(PROF_UPDATE) / denom, "0.000") & " ms" & vbCrLf & _
        "  Reset:     " & Format$(g_profAcc(PROF_RESET) / denom, "0.000") & " ms" & vbCrLf & _
        "  Compute:   " & Format$(g_profAcc(PROF_COMPUTE) / denom, "0.000") & " ms" & vbCrLf & _
        "  Barrier1:  " & Format$(g_profAcc(PROF_BARRIER1) / denom, "0.000") & " ms" & vbCrLf & _
        "  Graphics:  " & Format$(g_profAcc(PROF_GRAPHICS) / denom, "0.000") & " ms" & vbCrLf & _
        "  Barrier2:  " & Format$(g_profAcc(PROF_BARRIER2) / denom, "0.000") & " ms" & vbCrLf & _
        "  Execute:   " & Format$(g_profAcc(PROF_EXECUTE) / denom, "0.000") & " ms" & vbCrLf & _
        "  Present:   " & Format$(g_profAcc(PROF_PRESENT) / denom, "0.000") & " ms" & vbCrLf & _
        "  FrameSync: " & Format$(g_profAcc(PROF_FRAME_SYNC) / denom, "0.000") & " ms" & vbCrLf & _
        "  TOTAL:     " & Format$(g_profAcc(PROF_TOTAL) / denom, "0.000") & " ms" & vbCrLf & _
        "  Est FPS:   " & Format$(IIf(g_profAcc(PROF_TOTAL) > 0#, (1000# * denom) / g_profAcc(PROF_TOTAL), 0#), "0.0") & vbCrLf & _
        "============================================="
    
    Debug.Print s
    
    Dim ff As Integer: ff = FreeFile
    Open PROF_LOG_PATH For Append As #ff
    Print #ff, s
    Close #ff
    
    Dim i As Long
    For i = 0 To PROF_COUNT - 1: g_profAcc(i) = 0#: Next i
    g_profFrames = 0
End Sub

' ============================================================
' Logger
' ============================================================
Private Sub LogOpen()
    On Error Resume Next
    CreateDirectoryW StrPtr("C:\TEMP"), 0
    g_log = CreateFileW(StrPtr("C:\TEMP\dx12_harmonograph_v3.log"), GENERIC_WRITE, FILE_SHARE_READ Or FILE_SHARE_WRITE, 0, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, 0)
    If g_log = 0 Or g_log = -1 Then g_log = 0
    LogMsg "==== DX12 HARMONOGRAPH LOG START (V3 OPTIMIZED) ===="
End Sub

Private Sub LogClose()
    On Error Resume Next
    If g_log <> 0 Then
        LogMsg "==== DX12 HARMONOGRAPH LOG END ===="
        CloseHandle g_log: g_log = 0
    End If
End Sub

Private Sub LogMsg(ByVal s As String)
    On Error Resume Next
    If g_log = 0 Then Exit Sub
    Dim line As String: line = Format$(Now, "yyyy-mm-dd hh:nn:ss.000") & " | " & s & vbCrLf
    Dim b() As Byte: b = StrConv(line, vbFromUnicode)
    Dim written As Long: WriteFile g_log, b(0), UBound(b) + 1, written, 0
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
    Dim b() As Byte: ReDim b(0 To n - 1) As Byte
    RtlMoveMemory b(0), p, n
    PtrToAnsiString = StrConv(b, vbUnicode)
End Function

Private Function GetVTableMethod(ByVal pObj As LongPtr, ByVal vtIndex As Long) As LongPtr
    Dim vtable As LongPtr, methodAddr As LongPtr
    CopyMemory VarPtr(vtable), pObj, 8
    CopyMemory VarPtr(methodAddr), vtable + CLngPtr(vtIndex) * 8, 8
    GetVTableMethod = methodAddr
End Function

Private Function ToHResult(ByVal v As LongPtr) As Long
    If v >= 0 And v <= &H7FFFFFFF Then ToHResult = CLng(v) Else Dim lo As Long: CopyMemory VarPtr(lo), VarPtr(v), 4: ToHResult = lo
End Function

' ============================================================
' GUIDs
' ============================================================
Private Function IID_IDXGIFactory1() As GUID
    With IID_IDXGIFactory1: .Data1 = &H770AAE78: .Data2 = &HF26F: .Data3 = &H4DBA: .Data4(0) = &HA8: .Data4(1) = &H29: .Data4(2) = &H25: .Data4(3) = &H3C: .Data4(4) = &H83: .Data4(5) = &HD1: .Data4(6) = &HB3: .Data4(7) = &H87: End With
End Function

Private Function IID_ID3D12Device() As GUID
    With IID_ID3D12Device: .Data1 = &H189819F1: .Data2 = &H1DB6: .Data3 = &H4B57: .Data4(0) = &HBE: .Data4(1) = &H54: .Data4(2) = &H18: .Data4(3) = &H21: .Data4(4) = &H33: .Data4(5) = &H9B: .Data4(6) = &H85: .Data4(7) = &HF7: End With
End Function

Private Function IID_ID3D12Debug() As GUID
    With IID_ID3D12Debug: .Data1 = &H344488B7: .Data2 = &H6846: .Data3 = &H474B: .Data4(0) = &HB9: .Data4(1) = &H89: .Data4(2) = &HF0: .Data4(3) = &H27: .Data4(4) = &H44: .Data4(5) = &H82: .Data4(6) = &H45: .Data4(7) = &HE0: End With
End Function

Private Function IID_ID3D12CommandQueue() As GUID
    With IID_ID3D12CommandQueue: .Data1 = &HEC870A6: .Data2 = &H5D7E: .Data3 = &H4C22: .Data4(0) = &H8C: .Data4(1) = &HFC: .Data4(2) = &H5B: .Data4(3) = &HAA: .Data4(4) = &HE0: .Data4(5) = &H76: .Data4(6) = &H16: .Data4(7) = &HED: End With
End Function

Private Function IID_ID3D12DescriptorHeap() As GUID
    With IID_ID3D12DescriptorHeap: .Data1 = &H8EFB471D: .Data2 = &H616C: .Data3 = &H4F49: .Data4(0) = &H90: .Data4(1) = &HF7: .Data4(2) = &H12: .Data4(3) = &H7B: .Data4(4) = &HB7: .Data4(5) = &H63: .Data4(6) = &HFA: .Data4(7) = &H51: End With
End Function

Private Function IID_ID3D12Resource() As GUID
    With IID_ID3D12Resource: .Data1 = &H696442BE: .Data2 = &HA72E: .Data3 = &H4059: .Data4(0) = &HBC: .Data4(1) = &H79: .Data4(2) = &H5B: .Data4(3) = &H5C: .Data4(4) = &H98: .Data4(5) = &H4: .Data4(6) = &HF: .Data4(7) = &HAD: End With
End Function

Private Function IID_ID3D12CommandAllocator() As GUID
    With IID_ID3D12CommandAllocator: .Data1 = &H6102DEE4: .Data2 = &HAF59: .Data3 = &H4B09: .Data4(0) = &HB9: .Data4(1) = &H99: .Data4(2) = &HB4: .Data4(3) = &H4D: .Data4(4) = &H73: .Data4(5) = &HF0: .Data4(6) = &H9B: .Data4(7) = &H24: End With
End Function

Private Function IID_ID3D12RootSignature() As GUID
    With IID_ID3D12RootSignature: .Data1 = &HC54A6B66: .Data2 = &H72DF: .Data3 = &H4EE8: .Data4(0) = &H8B: .Data4(1) = &HE5: .Data4(2) = &HA9: .Data4(3) = &H46: .Data4(4) = &HA1: .Data4(5) = &H42: .Data4(6) = &H92: .Data4(7) = &H14: End With
End Function

Private Function IID_ID3D12PipelineState() As GUID
    With IID_ID3D12PipelineState: .Data1 = &H765A30F3: .Data2 = &HF624: .Data3 = &H4C6F: .Data4(0) = &HA8: .Data4(1) = &H28: .Data4(2) = &HAC: .Data4(3) = &HE9: .Data4(4) = &H48: .Data4(5) = &H62: .Data4(6) = &H24: .Data4(7) = &H45: End With
End Function

Private Function IID_ID3D12GraphicsCommandList() As GUID
    With IID_ID3D12GraphicsCommandList: .Data1 = &H5B160D0F: .Data2 = &HAC1B: .Data3 = &H4185: .Data4(0) = &H8B: .Data4(1) = &HA8: .Data4(2) = &HB3: .Data4(3) = &HAE: .Data4(4) = &H42: .Data4(5) = &HA5: .Data4(6) = &HA4: .Data4(7) = &H55: End With
End Function

Private Function IID_ID3D12Fence() As GUID
    With IID_ID3D12Fence: .Data1 = &HA753DCF: .Data2 = &HC4D8: .Data3 = &H4B91: .Data4(0) = &HAD: .Data4(1) = &HF6: .Data4(2) = &HBE: .Data4(3) = &H5A: .Data4(4) = &H60: .Data4(5) = &HD9: .Data4(6) = &H5A: .Data4(7) = &H76: End With
End Function

Private Function IID_IDXGISwapChain3() As GUID
    With IID_IDXGISwapChain3: .Data1 = &H94D99BDB: .Data2 = &HF1F8: .Data3 = &H4AB0: .Data4(0) = &HB2: .Data4(1) = &H36: .Data4(2) = &H7D: .Data4(3) = &HA0: .Data4(4) = &H17: .Data4(5) = &HE: .Data4(6) = &HDA: .Data4(7) = &HB1: End With
End Function

' ============================================================
' Thunk builders
' ============================================================
Private Function BuildThunk1(ByVal target As LongPtr) As LongPtr
    Dim code(0 To 39) As Byte: Dim i As Long: i = 0
    code(i) = &H48: i = i + 1: code(i) = &H83: i = i + 1: code(i) = &HEC: i = i + 1: code(i) = &H28: i = i + 1
    code(i) = &H4D: i = i + 1: code(i) = &H89: i = i + 1: code(i) = &HC2: i = i + 1
    code(i) = &H49: i = i + 1: code(i) = &H8B: i = i + 1: code(i) = &HA: i = i + 1
    code(i) = &H48: i = i + 1: code(i) = &HB8: i = i + 1
    Dim t As LongLong: t = target: RtlMoveMemoryFromPtr VarPtr(code(i)), t, 8: i = i + 8
    code(i) = &HFF: i = i + 1: code(i) = &HD0: i = i + 1
    code(i) = &H48: i = i + 1: code(i) = &H83: i = i + 1: code(i) = &HC4: i = i + 1: code(i) = &H28: i = i + 1
    code(i) = &HC3
    Dim mem As LongPtr: mem = VirtualAlloc(0, 64, MEM_COMMIT Or MEM_RESERVE, PAGE_EXECUTE_READWRITE)
    If mem = 0 Then Err.Raise vbObjectError + 8996
    CopyMemory mem, VarPtr(code(0)), CLngPtr(i + 1)
    BuildThunk1 = mem
End Function

Private Function BuildThunk2(ByVal target As LongPtr) As LongPtr
    Dim code(0 To 47) As Byte: Dim i As Long: i = 0
    code(i) = &H48: i = i + 1: code(i) = &H83: i = i + 1: code(i) = &HEC: i = i + 1: code(i) = &H28: i = i + 1
    code(i) = &H4D: i = i + 1: code(i) = &H89: i = i + 1: code(i) = &HC2: i = i + 1
    code(i) = &H49: i = i + 1: code(i) = &H8B: i = i + 1: code(i) = &HA: i = i + 1
    code(i) = &H49: i = i + 1: code(i) = &H8B: i = i + 1: code(i) = &H52: i = i + 1: code(i) = &H8: i = i + 1
    code(i) = &H48: i = i + 1: code(i) = &HB8: i = i + 1
    Dim t As LongLong: t = target: RtlMoveMemoryFromPtr VarPtr(code(i)), t, 8: i = i + 8
    code(i) = &HFF: i = i + 1: code(i) = &HD0: i = i + 1
    code(i) = &H48: i = i + 1: code(i) = &H83: i = i + 1: code(i) = &HC4: i = i + 1: code(i) = &H28: i = i + 1
    code(i) = &HC3
    Dim mem As LongPtr: mem = VirtualAlloc(0, 64, MEM_COMMIT Or MEM_RESERVE, PAGE_EXECUTE_READWRITE)
    If mem = 0 Then Err.Raise vbObjectError + 8997
    CopyMemory mem, VarPtr(code(0)), CLngPtr(i + 1)
    BuildThunk2 = mem
End Function

Private Function BuildThunk3(ByVal target As LongPtr) As LongPtr
    Dim code(0 To 55) As Byte: Dim i As Long: i = 0
    code(i) = &H48: i = i + 1: code(i) = &H83: i = i + 1: code(i) = &HEC: i = i + 1: code(i) = &H28: i = i + 1
    code(i) = &H4D: i = i + 1: code(i) = &H89: i = i + 1: code(i) = &HC2: i = i + 1
    code(i) = &H49: i = i + 1: code(i) = &H8B: i = i + 1: code(i) = &HA: i = i + 1
    code(i) = &H49: i = i + 1: code(i) = &H8B: i = i + 1: code(i) = &H52: i = i + 1: code(i) = &H8: i = i + 1
    code(i) = &H4D: i = i + 1: code(i) = &H8B: i = i + 1: code(i) = &H42: i = i + 1: code(i) = &H10: i = i + 1
    code(i) = &H48: i = i + 1: code(i) = &HB8: i = i + 1
    Dim t As LongLong: t = target: RtlMoveMemoryFromPtr VarPtr(code(i)), t, 8: i = i + 8
    code(i) = &HFF: i = i + 1: code(i) = &HD0: i = i + 1
    code(i) = &H48: i = i + 1: code(i) = &H83: i = i + 1: code(i) = &HC4: i = i + 1: code(i) = &H28: i = i + 1
    code(i) = &HC3
    Dim mem As LongPtr: mem = VirtualAlloc(0, 64, MEM_COMMIT Or MEM_RESERVE, PAGE_EXECUTE_READWRITE)
    If mem = 0 Then Err.Raise vbObjectError + 8998
    CopyMemory mem, VarPtr(code(0)), CLngPtr(i + 1)
    BuildThunk3 = mem
End Function

Private Function BuildThunk4(ByVal target As LongPtr) As LongPtr
    Dim code(0 To 63) As Byte: Dim i As Long: i = 0
    code(i) = &H48: i = i + 1: code(i) = &H83: i = i + 1: code(i) = &HEC: i = i + 1: code(i) = &H28: i = i + 1
    code(i) = &H4D: i = i + 1: code(i) = &H89: i = i + 1: code(i) = &HC2: i = i + 1
    code(i) = &H49: i = i + 1: code(i) = &H8B: i = i + 1: code(i) = &HA: i = i + 1
    code(i) = &H49: i = i + 1: code(i) = &H8B: i = i + 1: code(i) = &H52: i = i + 1: code(i) = &H8: i = i + 1
    code(i) = &H4D: i = i + 1: code(i) = &H8B: i = i + 1: code(i) = &H42: i = i + 1: code(i) = &H10: i = i + 1
    code(i) = &H4D: i = i + 1: code(i) = &H8B: i = i + 1: code(i) = &H4A: i = i + 1: code(i) = &H18: i = i + 1
    code(i) = &H48: i = i + 1: code(i) = &HB8: i = i + 1
    Dim t As LongLong: t = target: RtlMoveMemoryFromPtr VarPtr(code(i)), t, 8: i = i + 8
    code(i) = &HFF: i = i + 1: code(i) = &HD0: i = i + 1
    code(i) = &H48: i = i + 1: code(i) = &H83: i = i + 1: code(i) = &HC4: i = i + 1: code(i) = &H28: i = i + 1
    code(i) = &HC3
    Dim mem As LongPtr: mem = VirtualAlloc(0, 128, MEM_COMMIT Or MEM_RESERVE, PAGE_EXECUTE_READWRITE)
    If mem = 0 Then Err.Raise vbObjectError + 8999
    CopyMemory mem, VarPtr(code(0)), CLngPtr(i + 1)
    BuildThunk4 = mem
End Function

Private Function BuildThunk5(ByVal target As LongPtr) As LongPtr
    Dim code(0 To 79) As Byte: Dim i As Long: i = 0
    code(i) = &H48: i = i + 1: code(i) = &H83: i = i + 1: code(i) = &HEC: i = i + 1: code(i) = &H38: i = i + 1
    code(i) = &H4D: i = i + 1: code(i) = &H89: i = i + 1: code(i) = &HC2: i = i + 1
    code(i) = &H49: i = i + 1: code(i) = &H8B: i = i + 1: code(i) = &HA: i = i + 1
    code(i) = &H49: i = i + 1: code(i) = &H8B: i = i + 1: code(i) = &H52: i = i + 1: code(i) = &H8: i = i + 1
    code(i) = &H4D: i = i + 1: code(i) = &H8B: i = i + 1: code(i) = &H42: i = i + 1: code(i) = &H10: i = i + 1
    code(i) = &H4D: i = i + 1: code(i) = &H8B: i = i + 1: code(i) = &H4A: i = i + 1: code(i) = &H18: i = i + 1
    code(i) = &H49: i = i + 1: code(i) = &H8B: i = i + 1: code(i) = &H42: i = i + 1: code(i) = &H20: i = i + 1
    code(i) = &H48: i = i + 1: code(i) = &H89: i = i + 1: code(i) = &H44: i = i + 1: code(i) = &H24: i = i + 1: code(i) = &H20: i = i + 1
    code(i) = &H48: i = i + 1: code(i) = &HB8: i = i + 1
    Dim t As LongLong: t = target: RtlMoveMemoryFromPtr VarPtr(code(i)), t, 8: i = i + 8
    code(i) = &HFF: i = i + 1: code(i) = &HD0: i = i + 1
    code(i) = &H48: i = i + 1: code(i) = &H83: i = i + 1: code(i) = &HC4: i = i + 1: code(i) = &H38: i = i + 1
    code(i) = &HC3
    Dim mem As LongPtr: mem = VirtualAlloc(0, 128, MEM_COMMIT Or MEM_RESERVE, PAGE_EXECUTE_READWRITE)
    If mem = 0 Then Err.Raise vbObjectError + 9000
    CopyMemory mem, VarPtr(code(0)), CLngPtr(i + 1)
    BuildThunk5 = mem
End Function

Private Function BuildThunk6(ByVal target As LongPtr) As LongPtr
    Dim code(0 To 99) As Byte: Dim i As Long: i = 0
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
    Dim t As LongLong: t = target: RtlMoveMemoryFromPtr VarPtr(code(i)), t, 8: i = i + 8
    code(i) = &HFF: i = i + 1: code(i) = &HD0: i = i + 1
    code(i) = &H48: i = i + 1: code(i) = &H83: i = i + 1: code(i) = &HC4: i = i + 1: code(i) = &H48: i = i + 1
    code(i) = &HC3
    Dim mem As LongPtr: mem = VirtualAlloc(0, 128, MEM_COMMIT Or MEM_RESERVE, PAGE_EXECUTE_READWRITE)
    If mem = 0 Then Err.Raise vbObjectError + 9001
    CopyMemory mem, VarPtr(code(0)), CLngPtr(i + 1)
    BuildThunk6 = mem
End Function

Private Function BuildThunk7(ByVal target As LongPtr) As LongPtr
    Dim code(0 To 119) As Byte: Dim i As Long: i = 0
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
    Dim t As LongLong: t = target: RtlMoveMemoryFromPtr VarPtr(code(i)), t, 8: i = i + 8
    code(i) = &HFF: i = i + 1: code(i) = &HD0: i = i + 1
    code(i) = &H48: i = i + 1: code(i) = &H83: i = i + 1: code(i) = &HC4: i = i + 1: code(i) = &H58: i = i + 1
    code(i) = &HC3
    Dim mem As LongPtr: mem = VirtualAlloc(0, 128, MEM_COMMIT Or MEM_RESERVE, PAGE_EXECUTE_READWRITE)
    If mem = 0 Then Err.Raise vbObjectError + 9002
    CopyMemory mem, VarPtr(code(0)), CLngPtr(i + 1)
    BuildThunk7 = mem
End Function

Private Function BuildThunk8(ByVal target As LongPtr) As LongPtr
    Dim code(0 To 127) As Byte: Dim i As Long: i = 0
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
    Dim t As LongLong: t = target: RtlMoveMemoryFromPtr VarPtr(code(i)), t, 8: i = i + 8
    code(i) = &HFF: i = i + 1: code(i) = &HD0: i = i + 1
    code(i) = &H48: i = i + 1: code(i) = &H83: i = i + 1: code(i) = &HC4: i = i + 1: code(i) = &H68: i = i + 1
    code(i) = &HC3
    Dim mem As LongPtr: mem = VirtualAlloc(0, 160, MEM_COMMIT Or MEM_RESERVE, PAGE_EXECUTE_READWRITE)
    If mem = 0 Then Err.Raise vbObjectError + 9003
    CopyMemory mem, VarPtr(code(0)), CLngPtr(i + 1)
    BuildThunk8 = mem
End Function

Private Function BuildThunk9(ByVal target As LongPtr) As LongPtr
    Dim code(0 To 143) As Byte: Dim i As Long: i = 0
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
    Dim t As LongLong: t = target: RtlMoveMemoryFromPtr VarPtr(code(i)), t, 8: i = i + 8
    code(i) = &HFF: i = i + 1: code(i) = &HD0: i = i + 1
    code(i) = &H48: i = i + 1: code(i) = &H83: i = i + 1: code(i) = &HC4: i = i + 1: code(i) = &H68: i = i + 1
    code(i) = &HC3
    Dim mem As LongPtr: mem = VirtualAlloc(0, 192, MEM_COMMIT Or MEM_RESERVE, PAGE_EXECUTE_READWRITE)
    If mem = 0 Then Err.Raise vbObjectError + 9004
    CopyMemory mem, VarPtr(code(0)), CLngPtr(i + 1)
    BuildThunk9 = mem
End Function

Private Function BuildThunkRetStruct(ByVal target As LongPtr) As LongPtr
    Dim code(0 To 47) As Byte: Dim i As Long: i = 0
    code(i) = &H48: i = i + 1: code(i) = &H83: i = i + 1: code(i) = &HEC: i = i + 1: code(i) = &H28: i = i + 1
    code(i) = &H4D: i = i + 1: code(i) = &H89: i = i + 1: code(i) = &HC2: i = i + 1
    code(i) = &H49: i = i + 1: code(i) = &H8B: i = i + 1: code(i) = &HA: i = i + 1
    code(i) = &H49: i = i + 1: code(i) = &H8B: i = i + 1: code(i) = &H52: i = i + 1: code(i) = &H8: i = i + 1
    code(i) = &H48: i = i + 1: code(i) = &HB8: i = i + 1
    Dim t As LongLong: t = target: RtlMoveMemoryFromPtr VarPtr(code(i)), t, 8: i = i + 8
    code(i) = &HFF: i = i + 1: code(i) = &HD0: i = i + 1
    code(i) = &H48: i = i + 1: code(i) = &H83: i = i + 1: code(i) = &HC4: i = i + 1: code(i) = &H28: i = i + 1
    code(i) = &HC3
    Dim mem As LongPtr: mem = VirtualAlloc(0, 64, MEM_COMMIT Or MEM_RESERVE, PAGE_EXECUTE_READWRITE)
    If mem = 0 Then Err.Raise vbObjectError + 9005
    CopyMemory mem, VarPtr(code(0)), CLngPtr(i + 1)
    BuildThunkRetStruct = mem
End Function

' ============================================================
' *** BATCH THUNK: ComputePassBatch ***
' Executes: SetDescriptorHeaps, SetComputeRootSignature,
'           SetComputeRootDescriptorTable x2, Dispatch
' ============================================================
Private Function BuildComputePassBatchThunk() As LongPtr
    ' x64 machine code for batched compute pass
    ' Args in r9: BatchComputeArgs structure
    Dim code(0 To 255) As Byte
    Dim i As Long: i = 0
    
    ' sub rsp, 58h
    code(i) = &H48: i = i + 1: code(i) = &H83: i = i + 1: code(i) = &HEC: i = i + 1: code(i) = &H58: i = i + 1
    ' mov [rsp+40h], rbx
    code(i) = &H48: i = i + 1: code(i) = &H89: i = i + 1: code(i) = &H5C: i = i + 1: code(i) = &H24: i = i + 1: code(i) = &H40: i = i + 1
    ' mov [rsp+48h], rsi
    code(i) = &H48: i = i + 1: code(i) = &H89: i = i + 1: code(i) = &H74: i = i + 1: code(i) = &H24: i = i + 1: code(i) = &H48: i = i + 1
    ' mov [rsp+50h], rdi
    code(i) = &H48: i = i + 1: code(i) = &H89: i = i + 1: code(i) = &H7C: i = i + 1: code(i) = &H24: i = i + 1: code(i) = &H50: i = i + 1
    
    ' mov rdi, r9 (args pointer)
    code(i) = &H4C: i = i + 1: code(i) = &H89: i = i + 1: code(i) = &HCF: i = i + 1
    ' mov rsi, [rdi] (pCommandList)
    code(i) = &H48: i = i + 1: code(i) = &H8B: i = i + 1: code(i) = &H37: i = i + 1
    ' mov rbx, [rsi] (vtable)
    code(i) = &H48: i = i + 1: code(i) = &H8B: i = i + 1: code(i) = &H1E: i = i + 1
    
    ' === 1. SetDescriptorHeaps(this, 1, pHeapPtrArray) ===
    ' mov rcx, rsi
    code(i) = &H48: i = i + 1: code(i) = &H89: i = i + 1: code(i) = &HF1: i = i + 1
    ' mov edx, 1
    code(i) = &HBA: i = i + 1: code(i) = &H1: i = i + 1: code(i) = &H0: i = i + 1: code(i) = &H0: i = i + 1: code(i) = &H0: i = i + 1
    ' mov r8, [rdi+8]
    code(i) = &H4C: i = i + 1: code(i) = &H8B: i = i + 1: code(i) = &H47: i = i + 1: code(i) = &H8: i = i + 1
    ' call [rbx+E0h] (28*8=224=0xE0)
    code(i) = &HFF: i = i + 1: code(i) = &H93: i = i + 1: code(i) = &HE0: i = i + 1: code(i) = &H0: i = i + 1: code(i) = &H0: i = i + 1: code(i) = &H0: i = i + 1
    
    ' === 2. SetComputeRootSignature(this, pComputeRootSig) ===
    ' mov rcx, rsi
    code(i) = &H48: i = i + 1: code(i) = &H89: i = i + 1: code(i) = &HF1: i = i + 1
    ' mov rdx, [rdi+10h]
    code(i) = &H48: i = i + 1: code(i) = &H8B: i = i + 1: code(i) = &H57: i = i + 1: code(i) = &H10: i = i + 1
    ' call [rbx+E8h] (29*8=232=0xE8)
    code(i) = &HFF: i = i + 1: code(i) = &H93: i = i + 1: code(i) = &HE8: i = i + 1: code(i) = &H0: i = i + 1: code(i) = &H0: i = i + 1: code(i) = &H0: i = i + 1
    
    ' === 3. SetComputeRootDescriptorTable(this, 0, gpuHandle_UAV) ===
    ' mov rcx, rsi
    code(i) = &H48: i = i + 1: code(i) = &H89: i = i + 1: code(i) = &HF1: i = i + 1
    ' xor edx, edx
    code(i) = &H31: i = i + 1: code(i) = &HD2: i = i + 1
    ' mov r8, [rdi+18h]
    code(i) = &H4C: i = i + 1: code(i) = &H8B: i = i + 1: code(i) = &H47: i = i + 1: code(i) = &H18: i = i + 1
    ' call [rbx+F8h] (31*8=248=0xF8)
    code(i) = &HFF: i = i + 1: code(i) = &H93: i = i + 1: code(i) = &HF8: i = i + 1: code(i) = &H0: i = i + 1: code(i) = &H0: i = i + 1: code(i) = &H0: i = i + 1
    
    ' === 4. SetComputeRootDescriptorTable(this, 1, gpuHandle_CBV) ===
    ' mov rcx, rsi
    code(i) = &H48: i = i + 1: code(i) = &H89: i = i + 1: code(i) = &HF1: i = i + 1
    ' mov edx, 1
    code(i) = &HBA: i = i + 1: code(i) = &H1: i = i + 1: code(i) = &H0: i = i + 1: code(i) = &H0: i = i + 1: code(i) = &H0: i = i + 1
    ' mov r8, [rdi+20h]
    code(i) = &H4C: i = i + 1: code(i) = &H8B: i = i + 1: code(i) = &H47: i = i + 1: code(i) = &H20: i = i + 1
    ' call [rbx+F8h]
    code(i) = &HFF: i = i + 1: code(i) = &H93: i = i + 1: code(i) = &HF8: i = i + 1: code(i) = &H0: i = i + 1: code(i) = &H0: i = i + 1: code(i) = &H0: i = i + 1
    
    ' === 5. Dispatch(this, dispatchX, 1, 1) ===
    ' mov rcx, rsi
    code(i) = &H48: i = i + 1: code(i) = &H89: i = i + 1: code(i) = &HF1: i = i + 1
    ' mov edx, [rdi+28h]
    code(i) = &H8B: i = i + 1: code(i) = &H57: i = i + 1: code(i) = &H28: i = i + 1
    ' mov r8d, 1
    code(i) = &H41: i = i + 1: code(i) = &HB8: i = i + 1: code(i) = &H1: i = i + 1: code(i) = &H0: i = i + 1: code(i) = &H0: i = i + 1: code(i) = &H0: i = i + 1
    ' mov r9d, 1
    code(i) = &H41: i = i + 1: code(i) = &HB9: i = i + 1: code(i) = &H1: i = i + 1: code(i) = &H0: i = i + 1: code(i) = &H0: i = i + 1: code(i) = &H0: i = i + 1
    ' call [rbx+70h] (14*8=112=0x70)
    code(i) = &HFF: i = i + 1: code(i) = &H53: i = i + 1: code(i) = &H70: i = i + 1
    
    ' Epilogue
    ' mov rbx, [rsp+40h]
    code(i) = &H48: i = i + 1: code(i) = &H8B: i = i + 1: code(i) = &H5C: i = i + 1: code(i) = &H24: i = i + 1: code(i) = &H40: i = i + 1
    ' mov rsi, [rsp+48h]
    code(i) = &H48: i = i + 1: code(i) = &H8B: i = i + 1: code(i) = &H74: i = i + 1: code(i) = &H24: i = i + 1: code(i) = &H48: i = i + 1
    ' mov rdi, [rsp+50h]
    code(i) = &H48: i = i + 1: code(i) = &H8B: i = i + 1: code(i) = &H7C: i = i + 1: code(i) = &H24: i = i + 1: code(i) = &H50: i = i + 1
    ' add rsp, 58h
    code(i) = &H48: i = i + 1: code(i) = &H83: i = i + 1: code(i) = &HC4: i = i + 1: code(i) = &H58: i = i + 1
    ' ret
    code(i) = &HC3
    
    Dim mem As LongPtr: mem = VirtualAlloc(0, 512, MEM_COMMIT Or MEM_RESERVE, PAGE_EXECUTE_READWRITE)
    If mem = 0 Then Err.Raise vbObjectError + 9010
    CopyMemory mem, VarPtr(code(0)), CLngPtr(i + 1)
    BuildComputePassBatchThunk = mem
End Function

' ============================================================
' *** BATCH THUNK: GraphicsDrawBatch ***
' Executes: SetGraphicsRootSignature, SetPipelineState,
'           SetGraphicsRootDescriptorTable x2, RSSetViewports,
'           RSSetScissorRects, IASetPrimitiveTopology, DrawInstanced
' ============================================================
Private Function BuildGraphicsDrawBatchThunk() As LongPtr
    ' x64 machine code for batched graphics draw
    ' Args in r9: BatchGraphicsArgs structure
    Dim code(0 To 319) As Byte
    Dim i As Long: i = 0
    
    ' sub rsp, 58h
    code(i) = &H48: i = i + 1: code(i) = &H83: i = i + 1: code(i) = &HEC: i = i + 1: code(i) = &H58: i = i + 1
    ' mov [rsp+40h], rbx
    code(i) = &H48: i = i + 1: code(i) = &H89: i = i + 1: code(i) = &H5C: i = i + 1: code(i) = &H24: i = i + 1: code(i) = &H40: i = i + 1
    ' mov [rsp+48h], rsi
    code(i) = &H48: i = i + 1: code(i) = &H89: i = i + 1: code(i) = &H74: i = i + 1: code(i) = &H24: i = i + 1: code(i) = &H48: i = i + 1
    ' mov [rsp+50h], rdi
    code(i) = &H48: i = i + 1: code(i) = &H89: i = i + 1: code(i) = &H7C: i = i + 1: code(i) = &H24: i = i + 1: code(i) = &H50: i = i + 1
    
    ' mov rdi, r9
    code(i) = &H4C: i = i + 1: code(i) = &H89: i = i + 1: code(i) = &HCF: i = i + 1
    ' mov rsi, [rdi]
    code(i) = &H48: i = i + 1: code(i) = &H8B: i = i + 1: code(i) = &H37: i = i + 1
    ' mov rbx, [rsi]
    code(i) = &H48: i = i + 1: code(i) = &H8B: i = i + 1: code(i) = &H1E: i = i + 1
    
    ' === 1. SetGraphicsRootSignature(this, pGraphicsRootSig) ===
    ' mov rcx, rsi
    code(i) = &H48: i = i + 1: code(i) = &H89: i = i + 1: code(i) = &HF1: i = i + 1
    ' mov rdx, [rdi+8]
    code(i) = &H48: i = i + 1: code(i) = &H8B: i = i + 1: code(i) = &H57: i = i + 1: code(i) = &H8: i = i + 1
    ' call [rbx+F0h] (30*8=240=0xF0)
    code(i) = &HFF: i = i + 1: code(i) = &H93: i = i + 1: code(i) = &HF0: i = i + 1: code(i) = &H0: i = i + 1: code(i) = &H0: i = i + 1: code(i) = &H0: i = i + 1
    
    ' === 2. SetPipelineState(this, pGraphicsPipelineState) ===
    ' mov rcx, rsi
    code(i) = &H48: i = i + 1: code(i) = &H89: i = i + 1: code(i) = &HF1: i = i + 1
    ' mov rdx, [rdi+10h]
    code(i) = &H48: i = i + 1: code(i) = &H8B: i = i + 1: code(i) = &H57: i = i + 1: code(i) = &H10: i = i + 1
    ' call [rbx+C8h] (25*8=200=0xC8)
    code(i) = &HFF: i = i + 1: code(i) = &H93: i = i + 1: code(i) = &HC8: i = i + 1: code(i) = &H0: i = i + 1: code(i) = &H0: i = i + 1: code(i) = &H0: i = i + 1
    
    ' === 3. SetGraphicsRootDescriptorTable(this, 0, gpuHandle_SRV) ===
    ' mov rcx, rsi
    code(i) = &H48: i = i + 1: code(i) = &H89: i = i + 1: code(i) = &HF1: i = i + 1
    ' xor edx, edx
    code(i) = &H31: i = i + 1: code(i) = &HD2: i = i + 1
    ' mov r8, [rdi+18h]
    code(i) = &H4C: i = i + 1: code(i) = &H8B: i = i + 1: code(i) = &H47: i = i + 1: code(i) = &H18: i = i + 1
    ' call [rbx+100h] (32*8=256=0x100)
    code(i) = &HFF: i = i + 1: code(i) = &H93: i = i + 1: code(i) = &H0: i = i + 1: code(i) = &H1: i = i + 1: code(i) = &H0: i = i + 1: code(i) = &H0: i = i + 1
    
    ' === 4. SetGraphicsRootDescriptorTable(this, 1, gpuHandle_CBV) ===
    ' mov rcx, rsi
    code(i) = &H48: i = i + 1: code(i) = &H89: i = i + 1: code(i) = &HF1: i = i + 1
    ' mov edx, 1
    code(i) = &HBA: i = i + 1: code(i) = &H1: i = i + 1: code(i) = &H0: i = i + 1: code(i) = &H0: i = i + 1: code(i) = &H0: i = i + 1
    ' mov r8, [rdi+20h]
    code(i) = &H4C: i = i + 1: code(i) = &H8B: i = i + 1: code(i) = &H47: i = i + 1: code(i) = &H20: i = i + 1
    ' call [rbx+100h]
    code(i) = &HFF: i = i + 1: code(i) = &H93: i = i + 1: code(i) = &H0: i = i + 1: code(i) = &H1: i = i + 1: code(i) = &H0: i = i + 1: code(i) = &H0: i = i + 1
    
    ' === 5. RSSetViewports(this, 1, pViewport) ===
    ' mov rcx, rsi
    code(i) = &H48: i = i + 1: code(i) = &H89: i = i + 1: code(i) = &HF1: i = i + 1
    ' mov edx, 1
    code(i) = &HBA: i = i + 1: code(i) = &H1: i = i + 1: code(i) = &H0: i = i + 1: code(i) = &H0: i = i + 1: code(i) = &H0: i = i + 1
    ' mov r8, [rdi+28h]
    code(i) = &H4C: i = i + 1: code(i) = &H8B: i = i + 1: code(i) = &H47: i = i + 1: code(i) = &H28: i = i + 1
    ' call [rbx+A8h] (21*8=168=0xA8)
    code(i) = &HFF: i = i + 1: code(i) = &H93: i = i + 1: code(i) = &HA8: i = i + 1: code(i) = &H0: i = i + 1: code(i) = &H0: i = i + 1: code(i) = &H0: i = i + 1
    
    ' === 6. RSSetScissorRects(this, 1, pScissorRect) ===
    ' mov rcx, rsi
    code(i) = &H48: i = i + 1: code(i) = &H89: i = i + 1: code(i) = &HF1: i = i + 1
    ' mov edx, 1
    code(i) = &HBA: i = i + 1: code(i) = &H1: i = i + 1: code(i) = &H0: i = i + 1: code(i) = &H0: i = i + 1: code(i) = &H0: i = i + 1
    ' mov r8, [rdi+30h]
    code(i) = &H4C: i = i + 1: code(i) = &H8B: i = i + 1: code(i) = &H47: i = i + 1: code(i) = &H30: i = i + 1
    ' call [rbx+B0h] (22*8=176=0xB0)
    code(i) = &HFF: i = i + 1: code(i) = &H93: i = i + 1: code(i) = &HB0: i = i + 1: code(i) = &H0: i = i + 1: code(i) = &H0: i = i + 1: code(i) = &H0: i = i + 1
    
    ' === 7. IASetPrimitiveTopology(this, topology) ===
    ' mov rcx, rsi
    code(i) = &H48: i = i + 1: code(i) = &H89: i = i + 1: code(i) = &HF1: i = i + 1
    ' mov edx, [rdi+38h]
    code(i) = &H8B: i = i + 1: code(i) = &H57: i = i + 1: code(i) = &H38: i = i + 1
    ' call [rbx+A0h] (20*8=160=0xA0)
    code(i) = &HFF: i = i + 1: code(i) = &H93: i = i + 1: code(i) = &HA0: i = i + 1: code(i) = &H0: i = i + 1: code(i) = &H0: i = i + 1: code(i) = &H0: i = i + 1
    
    ' === 8. DrawInstanced(this, vertexCount, 1, 0, 0) ===
    ' mov rcx, rsi
    code(i) = &H48: i = i + 1: code(i) = &H89: i = i + 1: code(i) = &HF1: i = i + 1
    ' mov edx, [rdi+3Ch]
    code(i) = &H8B: i = i + 1: code(i) = &H57: i = i + 1: code(i) = &H3C: i = i + 1
    ' mov r8d, 1
    code(i) = &H41: i = i + 1: code(i) = &HB8: i = i + 1: code(i) = &H1: i = i + 1: code(i) = &H0: i = i + 1: code(i) = &H0: i = i + 1: code(i) = &H0: i = i + 1
    ' xor r9d, r9d
    code(i) = &H45: i = i + 1: code(i) = &H31: i = i + 1: code(i) = &HC9: i = i + 1
    ' mov dword ptr [rsp+20h], 0
    code(i) = &HC7: i = i + 1: code(i) = &H44: i = i + 1: code(i) = &H24: i = i + 1: code(i) = &H20: i = i + 1
    code(i) = &H0: i = i + 1: code(i) = &H0: i = i + 1: code(i) = &H0: i = i + 1: code(i) = &H0: i = i + 1
    ' call [rbx+60h] (12*8=96=0x60)
    code(i) = &HFF: i = i + 1: code(i) = &H53: i = i + 1: code(i) = &H60: i = i + 1
    
    ' Epilogue
    ' mov rbx, [rsp+40h]
    code(i) = &H48: i = i + 1: code(i) = &H8B: i = i + 1: code(i) = &H5C: i = i + 1: code(i) = &H24: i = i + 1: code(i) = &H40: i = i + 1
    ' mov rsi, [rsp+48h]
    code(i) = &H48: i = i + 1: code(i) = &H8B: i = i + 1: code(i) = &H74: i = i + 1: code(i) = &H24: i = i + 1: code(i) = &H48: i = i + 1
    ' mov rdi, [rsp+50h]
    code(i) = &H48: i = i + 1: code(i) = &H8B: i = i + 1: code(i) = &H7C: i = i + 1: code(i) = &H24: i = i + 1: code(i) = &H50: i = i + 1
    ' add rsp, 58h
    code(i) = &H48: i = i + 1: code(i) = &H83: i = i + 1: code(i) = &HC4: i = i + 1: code(i) = &H58: i = i + 1
    ' ret
    code(i) = &HC3
    
    Dim mem As LongPtr: mem = VirtualAlloc(0, 512, MEM_COMMIT Or MEM_RESERVE, PAGE_EXECUTE_READWRITE)
    If mem = 0 Then Err.Raise vbObjectError + 9011
    CopyMemory mem, VarPtr(code(0)), CLngPtr(i + 1)
    BuildGraphicsDrawBatchThunk = mem
End Function

Private Sub FreeThunkCache(ByRef cache As ThunkCache)
    Dim i As Long
    For i = 0 To cache.count - 1
        If cache.thunks(i) <> 0 Then VirtualFree cache.thunks(i), 0, MEM_RELEASE: cache.thunks(i) = 0
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
    
    ' Free descriptor handle thunk
    If p_thunkRetStruct <> 0 Then VirtualFree p_thunkRetStruct, 0, MEM_RELEASE: p_thunkRetStruct = 0
    
    ' Free V3 dedicated thunks
    If g_thunk_SwapChain3_GetCurrentBackBufferIndex <> 0 Then VirtualFree g_thunk_SwapChain3_GetCurrentBackBufferIndex, 0, MEM_RELEASE: g_thunk_SwapChain3_GetCurrentBackBufferIndex = 0
    If g_thunk_Fence_GetCompletedValue <> 0 Then VirtualFree g_thunk_Fence_GetCompletedValue, 0, MEM_RELEASE: g_thunk_Fence_GetCompletedValue = 0
    If g_thunk_Fence_SetEventOnCompletion <> 0 Then VirtualFree g_thunk_Fence_SetEventOnCompletion, 0, MEM_RELEASE: g_thunk_Fence_SetEventOnCompletion = 0
    If g_thunk_CmdQueue_ExecuteCommandLists <> 0 Then VirtualFree g_thunk_CmdQueue_ExecuteCommandLists, 0, MEM_RELEASE: g_thunk_CmdQueue_ExecuteCommandLists = 0
    If g_thunk_CmdQueue_Signal <> 0 Then VirtualFree g_thunk_CmdQueue_Signal, 0, MEM_RELEASE: g_thunk_CmdQueue_Signal = 0
    If g_thunk_SwapChain_Present <> 0 Then VirtualFree g_thunk_SwapChain_Present, 0, MEM_RELEASE: g_thunk_SwapChain_Present = 0
    If g_thunk_CmdList_Close <> 0 Then VirtualFree g_thunk_CmdList_Close, 0, MEM_RELEASE: g_thunk_CmdList_Close = 0
    
    ' Free PERF additional thunks
    If g_thunk_CmdAlloc_Reset <> 0 Then VirtualFree g_thunk_CmdAlloc_Reset, 0, MEM_RELEASE: g_thunk_CmdAlloc_Reset = 0
    If g_thunk_CmdList_Reset <> 0 Then VirtualFree g_thunk_CmdList_Reset, 0, MEM_RELEASE: g_thunk_CmdList_Reset = 0
    If g_thunk_CmdList_SetDescriptorHeaps <> 0 Then VirtualFree g_thunk_CmdList_SetDescriptorHeaps, 0, MEM_RELEASE: g_thunk_CmdList_SetDescriptorHeaps = 0
    If g_thunk_CmdList_SetComputeRootSignature <> 0 Then VirtualFree g_thunk_CmdList_SetComputeRootSignature, 0, MEM_RELEASE: g_thunk_CmdList_SetComputeRootSignature = 0
    If g_thunk_CmdList_SetComputeRootDescriptorTable <> 0 Then VirtualFree g_thunk_CmdList_SetComputeRootDescriptorTable, 0, MEM_RELEASE: g_thunk_CmdList_SetComputeRootDescriptorTable = 0
    If g_thunk_CmdList_Dispatch <> 0 Then VirtualFree g_thunk_CmdList_Dispatch, 0, MEM_RELEASE: g_thunk_CmdList_Dispatch = 0
    If g_thunk_CmdList_ResourceBarrier <> 0 Then VirtualFree g_thunk_CmdList_ResourceBarrier, 0, MEM_RELEASE: g_thunk_CmdList_ResourceBarrier = 0
    If g_thunk_CmdList_SetGraphicsRootSignature <> 0 Then VirtualFree g_thunk_CmdList_SetGraphicsRootSignature, 0, MEM_RELEASE: g_thunk_CmdList_SetGraphicsRootSignature = 0
    If g_thunk_CmdList_SetPipelineState <> 0 Then VirtualFree g_thunk_CmdList_SetPipelineState, 0, MEM_RELEASE: g_thunk_CmdList_SetPipelineState = 0
    If g_thunk_CmdList_SetGraphicsRootDescriptorTable <> 0 Then VirtualFree g_thunk_CmdList_SetGraphicsRootDescriptorTable, 0, MEM_RELEASE: g_thunk_CmdList_SetGraphicsRootDescriptorTable = 0
    If g_thunk_CmdList_RSSetViewports <> 0 Then VirtualFree g_thunk_CmdList_RSSetViewports, 0, MEM_RELEASE: g_thunk_CmdList_RSSetViewports = 0
    If g_thunk_CmdList_RSSetScissorRects <> 0 Then VirtualFree g_thunk_CmdList_RSSetScissorRects, 0, MEM_RELEASE: g_thunk_CmdList_RSSetScissorRects = 0
    If g_thunk_CmdList_OMSetRenderTargets <> 0 Then VirtualFree g_thunk_CmdList_OMSetRenderTargets, 0, MEM_RELEASE: g_thunk_CmdList_OMSetRenderTargets = 0
    If g_thunk_CmdList_ClearRenderTargetView <> 0 Then VirtualFree g_thunk_CmdList_ClearRenderTargetView, 0, MEM_RELEASE: g_thunk_CmdList_ClearRenderTargetView = 0
    If g_thunk_CmdList_IASetPrimitiveTopology <> 0 Then VirtualFree g_thunk_CmdList_IASetPrimitiveTopology, 0, MEM_RELEASE: g_thunk_CmdList_IASetPrimitiveTopology = 0
    If g_thunk_CmdList_DrawInstanced <> 0 Then VirtualFree g_thunk_CmdList_DrawInstanced, 0, MEM_RELEASE: g_thunk_CmdList_DrawInstanced = 0
    If g_thunk_DescHeap_GetGPUHandle <> 0 Then VirtualFree g_thunk_DescHeap_GetGPUHandle, 0, MEM_RELEASE: g_thunk_DescHeap_GetGPUHandle = 0
    If g_thunk_DescHeap_GetCPUHandle <> 0 Then VirtualFree g_thunk_DescHeap_GetCPUHandle, 0, MEM_RELEASE: g_thunk_DescHeap_GetCPUHandle = 0
    
    ' Free BATCH thunks
    If g_thunk_ComputePassBatch <> 0 Then VirtualFree g_thunk_ComputePassBatch, 0, MEM_RELEASE: g_thunk_ComputePassBatch = 0
    If g_thunk_GraphicsDrawBatch <> 0 Then VirtualFree g_thunk_GraphicsDrawBatch, 0, MEM_RELEASE: g_thunk_GraphicsDrawBatch = 0
    
    g_hotPathThunksBound = False
    g_batchThunksBound = False
End Sub

' ============================================================
' Cached thunk getters
' ============================================================
Private Function GetCachedThunk1(ByVal target As LongPtr) As LongPtr
    Dim i As Long
    For i = 0 To g_thunkCache1.count - 1
        If g_thunkCache1.targets(i) = target Then GetCachedThunk1 = g_thunkCache1.thunks(i): Exit Function
    Next i
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
        If g_thunkCache2.targets(i) = target Then GetCachedThunk2 = g_thunkCache2.thunks(i): Exit Function
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
        If g_thunkCache3.targets(i) = target Then GetCachedThunk3 = g_thunkCache3.thunks(i): Exit Function
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
        If g_thunkCache4.targets(i) = target Then GetCachedThunk4 = g_thunkCache4.thunks(i): Exit Function
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
        If g_thunkCache5.targets(i) = target Then GetCachedThunk5 = g_thunkCache5.thunks(i): Exit Function
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

Private Function GetCachedThunkRetStruct(ByVal target As LongPtr) As LongPtr
    Dim i As Long
    For i = 0 To g_thunkCacheRetStruct.count - 1
        If g_thunkCacheRetStruct.targets(i) = target Then GetCachedThunkRetStruct = g_thunkCacheRetStruct.thunks(i): Exit Function
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
' COM Call helpers (cached - for initialization)
' ============================================================
Private Function COM_Call1(ByVal pObj As LongPtr, ByVal vtIndex As Long) As LongPtr
    Dim methodAddr As LongPtr: methodAddr = GetVTableMethod(pObj, vtIndex)
    Dim thunk As LongPtr: thunk = GetCachedThunk1(methodAddr)
    Dim args As ThunkArgs1: args.a1 = pObj
    COM_Call1 = CallWindowProcW(thunk, 0, 0, VarPtr(args), 0)
End Function

Private Function COM_Call2(ByVal pObj As LongPtr, ByVal vtIndex As Long, ByVal a2 As LongPtr) As LongPtr
    Dim methodAddr As LongPtr: methodAddr = GetVTableMethod(pObj, vtIndex)
    Dim thunk As LongPtr: thunk = GetCachedThunk2(methodAddr)
    Dim args As ThunkArgs2: args.a1 = pObj: args.a2 = a2
    COM_Call2 = CallWindowProcW(thunk, 0, 0, VarPtr(args), 0)
End Function

Private Function COM_Call3(ByVal pObj As LongPtr, ByVal vtIndex As Long, ByVal a2 As LongPtr, ByVal a3 As LongPtr) As LongPtr
    Dim methodAddr As LongPtr: methodAddr = GetVTableMethod(pObj, vtIndex)
    Dim thunk As LongPtr: thunk = GetCachedThunk3(methodAddr)
    Dim args As ThunkArgs3: args.a1 = pObj: args.a2 = a2: args.a3 = a3
    COM_Call3 = CallWindowProcW(thunk, 0, 0, VarPtr(args), 0)
End Function

Private Function COM_Call4(ByVal pObj As LongPtr, ByVal vtIndex As Long, ByVal a2 As LongPtr, ByVal a3 As LongPtr, ByVal a4 As LongPtr) As LongPtr
    Dim methodAddr As LongPtr: methodAddr = GetVTableMethod(pObj, vtIndex)
    Dim thunk As LongPtr: thunk = GetCachedThunk4(methodAddr)
    Dim args As ThunkArgs4: args.a1 = pObj: args.a2 = a2: args.a3 = a3: args.a4 = a4
    COM_Call4 = CallWindowProcW(thunk, 0, 0, VarPtr(args), 0)
End Function

Private Function COM_Call5(ByVal pObj As LongPtr, ByVal vtIndex As Long, ByVal a2 As LongPtr, ByVal a3 As LongPtr, ByVal a4 As LongPtr, ByVal a5 As LongPtr) As LongPtr
    Dim methodAddr As LongPtr: methodAddr = GetVTableMethod(pObj, vtIndex)
    Dim thunk As LongPtr: thunk = GetCachedThunk5(methodAddr)
    Dim args As ThunkArgs5: args.a1 = pObj: args.a2 = a2: args.a3 = a3: args.a4 = a4: args.a5 = a5
    COM_Call5 = CallWindowProcW(thunk, 0, 0, VarPtr(args), 0)
End Function

Private Sub COM_Release(ByVal pObj As LongPtr)
    If pObj <> 0 Then COM_Call1 pObj, ONVTBL_IUnknown_Release
End Sub

Private Sub COM_GetCPUDescriptorHandle(ByVal pHeap As LongPtr, ByRef outHandle As D3D12_CPU_DESCRIPTOR_HANDLE)
    Dim methodAddr As LongPtr
    methodAddr = GetVTableMethod(pHeap, VTBL_DescHeap_GetCPUDescriptorHandleForHeapStart)
    
    If p_thunkRetStruct <> 0 Then VirtualFree p_thunkRetStruct, 0, MEM_RELEASE
    p_thunkRetStruct = BuildThunkRetStruct(methodAddr)
    
    Dim args As ThunkArgs2
    args.a1 = pHeap
    args.a2 = VarPtr(outHandle)
    
    CallWindowProcW p_thunkRetStruct, 0, 0, VarPtr(args), 0
End Sub

Private Sub COM_GetGPUDescriptorHandle(ByVal pHeap As LongPtr, ByRef outHandle As D3D12_GPU_DESCRIPTOR_HANDLE)
    Dim methodAddr As LongPtr
    methodAddr = GetVTableMethod(pHeap, VTBL_DescHeap_GetGPUDescriptorHandleForHeapStart)
    
    If p_thunkRetStruct <> 0 Then VirtualFree p_thunkRetStruct, 0, MEM_RELEASE
    p_thunkRetStruct = BuildThunkRetStruct(methodAddr)
    
    Dim args As ThunkArgs2
    args.a1 = pHeap
    args.a2 = VarPtr(outHandle)
    
    CallWindowProcW p_thunkRetStruct, 0, 0, VarPtr(args), 0
End Sub

' ============================================================
' *** V3 OPTIMIZATION: Fast inline calls using pre-bound thunks ***
' ============================================================

Private Sub BindHotPathThunks()
    If g_hotPathThunksBound Then Exit Sub
    LogMsg "BindHotPathThunks: Binding ALL RenderFrame thunks..."
    
    ' === Original V3 thunks ===
    ' SwapChain3::GetCurrentBackBufferIndex
    g_thunk_SwapChain3_GetCurrentBackBufferIndex = BuildThunk1(GetVTableMethod(g_pSwapChain3, VTBL_SwapChain3_GetCurrentBackBufferIndex))
    g_args1_GetBackBufferIndex.a1 = g_pSwapChain3
    
    ' Fence::GetCompletedValue
    g_thunk_Fence_GetCompletedValue = BuildThunk1(GetVTableMethod(g_pFence, VTBL_Fence_GetCompletedValue))
    g_args1_GetFenceValue.a1 = g_pFence
    
    ' Fence::SetEventOnCompletion
    g_thunk_Fence_SetEventOnCompletion = BuildThunk3(GetVTableMethod(g_pFence, VTBL_Fence_SetEventOnCompletion))
    g_args3_SetEventOnCompletion.a1 = g_pFence
    
    ' CommandQueue::ExecuteCommandLists
    g_thunk_CmdQueue_ExecuteCommandLists = BuildThunk3(GetVTableMethod(g_pCommandQueue, VTBL_CmdQueue_ExecuteCommandLists))
    g_args3_ExecuteCommandLists.a1 = g_pCommandQueue
    g_args3_ExecuteCommandLists.a2 = 1
    
    ' CommandQueue::Signal
    g_thunk_CmdQueue_Signal = BuildThunk3(GetVTableMethod(g_pCommandQueue, VTBL_CmdQueue_Signal))
    g_args3_Signal.a1 = g_pCommandQueue
    g_args3_Signal.a2 = g_pFence
    
    ' SwapChain::Present
    g_thunk_SwapChain_Present = BuildThunk3(GetVTableMethod(g_pSwapChain, VTBL_SwapChain_Present))
    g_args3_Present.a1 = g_pSwapChain
    g_args3_Present.a2 = 0
    g_args3_Present.a3 = 0
    
    ' CommandList::Close
    g_thunk_CmdList_Close = BuildThunk1(GetVTableMethod(g_pGraphicsCommandList, VTBL_CmdList_Close))
    g_args1_CmdListClose.a1 = g_pGraphicsCommandList
    
    ' === PERF: Additional RenderFrame thunks ===
    ' CommandAllocator::Reset (uses frame 0's allocator, will update a1 per frame)
    g_thunk_CmdAlloc_Reset = BuildThunk1(GetVTableMethod(g_pCommandAllocators(0), VTBL_CmdAlloc_Reset))
    
    ' CommandList::Reset
    g_thunk_CmdList_Reset = BuildThunk3(GetVTableMethod(g_pGraphicsCommandList, VTBL_CmdList_Reset))
    g_args3_CmdListReset.a1 = g_pGraphicsCommandList
    g_args3_CmdListReset.a3 = g_pComputePipelineState
    
    ' CommandList::SetDescriptorHeaps
    g_thunk_CmdList_SetDescriptorHeaps = BuildThunk3(GetVTableMethod(g_pGraphicsCommandList, VTBL_CmdList_SetDescriptorHeaps))
    g_heapPtr = g_pSrvUavHeap
    g_args3_SetDescHeaps.a1 = g_pGraphicsCommandList
    g_args3_SetDescHeaps.a2 = 1
    g_args3_SetDescHeaps.a3 = VarPtr(g_heapPtr)
    
    ' CommandList::SetComputeRootSignature
    g_thunk_CmdList_SetComputeRootSignature = BuildThunk2(GetVTableMethod(g_pGraphicsCommandList, VTBL_CmdList_SetComputeRootSignature))
    g_args2_SetComputeRootSig.a1 = g_pGraphicsCommandList
    g_args2_SetComputeRootSig.a2 = g_pComputeRootSignature
    
    ' CommandList::SetComputeRootDescriptorTable
    g_thunk_CmdList_SetComputeRootDescriptorTable = BuildThunk3(GetVTableMethod(g_pGraphicsCommandList, VTBL_CmdList_SetComputeRootDescriptorTable))
    g_args3_SetComputeDescTable0.a1 = g_pGraphicsCommandList
    g_args3_SetComputeDescTable0.a2 = 0
    g_args3_SetComputeDescTable1.a1 = g_pGraphicsCommandList
    g_args3_SetComputeDescTable1.a2 = 1
    
    ' CommandList::Dispatch
    g_thunk_CmdList_Dispatch = BuildThunk4(GetVTableMethod(g_pGraphicsCommandList, VTBL_CmdList_Dispatch))
    g_dispatchX = (VERTEX_COUNT + 63) \ 64
    g_args4_Dispatch.a1 = g_pGraphicsCommandList
    g_args4_Dispatch.a2 = g_dispatchX
    g_args4_Dispatch.a3 = 1
    g_args4_Dispatch.a4 = 1
    
    ' CommandList::ResourceBarrier
    g_thunk_CmdList_ResourceBarrier = BuildThunk3(GetVTableMethod(g_pGraphicsCommandList, VTBL_CmdList_ResourceBarrier))
    g_args3_ResourceBarrier.a1 = g_pGraphicsCommandList
    
    ' CommandList::SetGraphicsRootSignature
    g_thunk_CmdList_SetGraphicsRootSignature = BuildThunk2(GetVTableMethod(g_pGraphicsCommandList, VTBL_CmdList_SetGraphicsRootSignature))
    g_args2_SetGraphicsRootSig.a1 = g_pGraphicsCommandList
    g_args2_SetGraphicsRootSig.a2 = g_pGraphicsRootSignature
    
    ' CommandList::SetPipelineState
    g_thunk_CmdList_SetPipelineState = BuildThunk2(GetVTableMethod(g_pGraphicsCommandList, VTBL_CmdList_SetPipelineState))
    g_args2_SetPipelineState.a1 = g_pGraphicsCommandList
    g_args2_SetPipelineState.a2 = g_pGraphicsPipelineState
    
    ' CommandList::SetGraphicsRootDescriptorTable
    g_thunk_CmdList_SetGraphicsRootDescriptorTable = BuildThunk3(GetVTableMethod(g_pGraphicsCommandList, VTBL_CmdList_SetGraphicsRootDescriptorTable))
    g_args3_SetGraphicsDescTable0.a1 = g_pGraphicsCommandList
    g_args3_SetGraphicsDescTable0.a2 = 0
    g_args3_SetGraphicsDescTable1.a1 = g_pGraphicsCommandList
    g_args3_SetGraphicsDescTable1.a2 = 1
    
    ' CommandList::RSSetViewports
    g_thunk_CmdList_RSSetViewports = BuildThunk3(GetVTableMethod(g_pGraphicsCommandList, VTBL_CmdList_RSSetViewports))
    g_viewport.Width = CSng(Width): g_viewport.Height = CSng(Height): g_viewport.MaxDepth = 1!
    g_args3_RSSetViewports.a1 = g_pGraphicsCommandList
    g_args3_RSSetViewports.a2 = 1
    g_args3_RSSetViewports.a3 = VarPtr(g_viewport)
    
    ' CommandList::RSSetScissorRects
    g_thunk_CmdList_RSSetScissorRects = BuildThunk3(GetVTableMethod(g_pGraphicsCommandList, VTBL_CmdList_RSSetScissorRects))
    g_scissorRect.Right = Width: g_scissorRect.Bottom = Height
    g_args3_RSSetScissorRects.a1 = g_pGraphicsCommandList
    g_args3_RSSetScissorRects.a2 = 1
    g_args3_RSSetScissorRects.a3 = VarPtr(g_scissorRect)
    
    ' CommandList::OMSetRenderTargets
    g_thunk_CmdList_OMSetRenderTargets = BuildThunk5(GetVTableMethod(g_pGraphicsCommandList, VTBL_CmdList_OMSetRenderTargets))
    g_args5_OMSetRenderTargets.a1 = g_pGraphicsCommandList
    g_args5_OMSetRenderTargets.a2 = 1
    g_args5_OMSetRenderTargets.a4 = 1
    g_args5_OMSetRenderTargets.a5 = 0
    
    ' CommandList::ClearRenderTargetView
    g_thunk_CmdList_ClearRenderTargetView = BuildThunk5(GetVTableMethod(g_pGraphicsCommandList, VTBL_CmdList_ClearRenderTargetView))
    g_clearColor(0) = 0.05!: g_clearColor(1) = 0.05!: g_clearColor(2) = 0.1!: g_clearColor(3) = 1!
    g_args5_ClearRTV.a1 = g_pGraphicsCommandList
    g_args5_ClearRTV.a3 = VarPtr(g_clearColor(0))
    g_args5_ClearRTV.a4 = 0
    g_args5_ClearRTV.a5 = 0
    
    ' CommandList::IASetPrimitiveTopology
    g_thunk_CmdList_IASetPrimitiveTopology = BuildThunk2(GetVTableMethod(g_pGraphicsCommandList, VTBL_CmdList_IASetPrimitiveTopology))
    g_args2_IASetTopology.a1 = g_pGraphicsCommandList
    g_args2_IASetTopology.a2 = D3D_PRIMITIVE_TOPOLOGY_LINESTRIP
    
    ' CommandList::DrawInstanced
    g_thunk_CmdList_DrawInstanced = BuildThunk5(GetVTableMethod(g_pGraphicsCommandList, VTBL_CmdList_DrawInstanced))
    g_args5_DrawInstanced.a1 = g_pGraphicsCommandList
    g_args5_DrawInstanced.a2 = VERTEX_COUNT
    g_args5_DrawInstanced.a3 = 1
    g_args5_DrawInstanced.a4 = 0
    g_args5_DrawInstanced.a5 = 0
    
    ' DescriptorHeap::GetGPUDescriptorHandleForHeapStart
    g_thunk_DescHeap_GetGPUHandle = BuildThunkRetStruct(GetVTableMethod(g_pSrvUavHeap, VTBL_DescHeap_GetGPUDescriptorHandleForHeapStart))
    g_args2_GetGPUHandle.a1 = g_pSrvUavHeap
    g_args2_GetGPUHandle.a2 = VarPtr(g_gpuHandle)
    
    ' DescriptorHeap::GetCPUDescriptorHandleForHeapStart (for RTV heap)
    g_thunk_DescHeap_GetCPUHandle = BuildThunkRetStruct(GetVTableMethod(g_pRtvHeap, VTBL_DescHeap_GetCPUDescriptorHandleForHeapStart))
    g_args2_GetCPUHandle.a1 = g_pRtvHeap
    g_args2_GetCPUHandle.a2 = VarPtr(g_rtvHandle)
    
    ' Pre-initialize barriers (static parts)
    g_barriers(0).cType = D3D12_RESOURCE_BARRIER_TYPE_TRANSITION
    g_barriers(0).Transition.pResource = g_pPositionBuffer
    g_barriers(0).Transition.Subresource = D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES
    g_barriers(1).cType = D3D12_RESOURCE_BARRIER_TYPE_TRANSITION
    g_barriers(1).Transition.pResource = g_pColorBuffer
    g_barriers(1).Transition.Subresource = D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES
    
    g_rtBarrier.cType = D3D12_RESOURCE_BARRIER_TYPE_TRANSITION
    g_rtBarrier.Transition.Subresource = D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES
    
    ' Pre-calculate descriptor offsets
    g_cbvOffset = CLngLng(g_srvUavDescriptorSize) * 4
    g_srvOffset = CLngLng(g_srvUavDescriptorSize) * 2
    
    ' Store command list pointer for ExecuteCommandLists
    g_cmdListPtr = g_pGraphicsCommandList
    
    g_hotPathThunksBound = True
    LogMsg "BindHotPathThunks: done (ALL thunks bound)"
    
    ' *** BATCH THUNKS: Build and initialize ***
    If Not g_batchThunksBound Then
        LogMsg "Building BATCH thunks..."
        
        ' Build batch thunks
        g_thunk_ComputePassBatch = BuildComputePassBatchThunk()
        g_thunk_GraphicsDrawBatch = BuildGraphicsDrawBatchThunk()
        
        ' Initialize ComputePassBatch args (static parts)
        g_batchComputeArgs.pCommandList = g_pGraphicsCommandList
        g_batchComputeArgs.pHeapPtrArray = VarPtr(g_heapPtr)
        g_batchComputeArgs.pComputeRootSig = g_pComputeRootSignature
        g_batchComputeArgs.dispatchX = g_dispatchX
        
        ' Initialize GraphicsDrawBatch args (static parts)
        g_batchGraphicsArgs.pCommandList = g_pGraphicsCommandList
        g_batchGraphicsArgs.pGraphicsRootSig = g_pGraphicsRootSignature
        g_batchGraphicsArgs.pGraphicsPipelineState = g_pGraphicsPipelineState
        g_batchGraphicsArgs.pViewport = VarPtr(g_viewport)
        g_batchGraphicsArgs.pScissorRect = VarPtr(g_scissorRect)
        g_batchGraphicsArgs.topology = D3D_PRIMITIVE_TOPOLOGY_LINESTRIP
        g_batchGraphicsArgs.vertexCount = VERTEX_COUNT
        
        g_batchThunksBound = True
        LogMsg "BATCH thunks initialized"
    End If
End Sub

' Fast GetCurrentBackBufferIndex - no cache lookup!
Private Function Fast_GetCurrentBackBufferIndex() As Long
    Fast_GetCurrentBackBufferIndex = CLng(CallWindowProcW(g_thunk_SwapChain3_GetCurrentBackBufferIndex, 0, 0, VarPtr(g_args1_GetBackBufferIndex), 0))
End Function

' Fast GetCompletedValue - no cache lookup!
Private Function Fast_GetFenceCompletedValue() As LongLong
    Dim result As LongLong, retVal As LongPtr
    retVal = CallWindowProcW(g_thunk_Fence_GetCompletedValue, 0, 0, VarPtr(g_args1_GetFenceValue), 0)
    CopyMemory VarPtr(result), VarPtr(retVal), 8
    Fast_GetFenceCompletedValue = result
End Function

' Fast SetEventOnCompletion - no cache lookup!
Private Sub Fast_SetEventOnCompletion(ByVal fenceValue As LongLong, ByVal hEvent As LongPtr)
    g_args3_SetEventOnCompletion.a2 = CLngPtr(fenceValue)
    g_args3_SetEventOnCompletion.a3 = hEvent
    CallWindowProcW g_thunk_Fence_SetEventOnCompletion, 0, 0, VarPtr(g_args3_SetEventOnCompletion), 0
End Sub

' Fast ExecuteCommandLists - no cache lookup!
Private Sub Fast_ExecuteCommandLists(ByVal ppCommandLists As LongPtr)
    g_args3_ExecuteCommandLists.a3 = ppCommandLists
    CallWindowProcW g_thunk_CmdQueue_ExecuteCommandLists, 0, 0, VarPtr(g_args3_ExecuteCommandLists), 0
End Sub

' Fast Signal - no cache lookup!
Private Sub Fast_Signal(ByVal fenceValue As LongLong)
    g_args3_Signal.a3 = CLngPtr(fenceValue)
    CallWindowProcW g_thunk_CmdQueue_Signal, 0, 0, VarPtr(g_args3_Signal), 0
End Sub

' Fast Present - no cache lookup!
Private Sub Fast_Present()
    CallWindowProcW g_thunk_SwapChain_Present, 0, 0, VarPtr(g_args3_Present), 0
End Sub

' Fast CommandList::Close - no cache lookup!
Private Sub Fast_CmdListClose()
    CallWindowProcW g_thunk_CmdList_Close, 0, 0, VarPtr(g_args1_CmdListClose), 0
End Sub

' ============================================================
' Shader compilation
' ============================================================
Private Function CompileShaderFromFile(ByVal filePath As String, ByVal entryPoint As String, ByVal profile As String) As LongPtr
    LogMsg "CompileShaderFromFile: " & filePath & " / " & entryPoint
    Dim hCompiler As LongPtr: hCompiler = LoadLibraryW(StrPtr("d3dcompiler_47.dll"))
    If hCompiler = 0 Then Err.Raise vbObjectError + 8100
    Dim procNameBytes() As Byte: procNameBytes = AnsiZBytes("D3DCompileFromFile")
    Dim pD3DCompileFromFile As LongPtr: pD3DCompileFromFile = GetProcAddress(hCompiler, VarPtr(procNameBytes(0)))
    If pD3DCompileFromFile = 0 Then FreeLibrary hCompiler: Err.Raise vbObjectError + 8101
    
    Dim thunk As LongPtr: thunk = BuildThunk9(pD3DCompileFromFile)
    
    Dim entryBytes() As Byte: entryBytes = AnsiZBytes(entryPoint)
    Dim profileBytes() As Byte: profileBytes = AnsiZBytes(profile)
    Dim pBlob As LongPtr, pErrorBlob As LongPtr
    
    Dim args9 As ThunkArgs9
    args9.a1 = StrPtr(filePath): args9.a2 = 0: args9.a3 = 0
    args9.a4 = VarPtr(entryBytes(0)): args9.a5 = VarPtr(profileBytes(0))
    args9.a6 = 0: args9.a7 = 0
    args9.a8 = VarPtr(pBlob): args9.a9 = VarPtr(pErrorBlob)
    
    Dim hr As Long: hr = ToHResult(CallWindowProcW(thunk, 0, 0, VarPtr(args9), 0))
    
    If hr < 0 Then
        If pErrorBlob <> 0 Then
            LogMsg "Shader error: " & PtrToAnsiString(COM_Call1(pErrorBlob, VTBL_Blob_GetBufferPointer))
            COM_Release pErrorBlob
        End If
        VirtualFree thunk, 0, MEM_RELEASE
        FreeLibrary hCompiler
        Err.Raise vbObjectError + 8102
    End If
    
    If pErrorBlob <> 0 Then COM_Release pErrorBlob
    VirtualFree thunk, 0, MEM_RELEASE
    FreeLibrary hCompiler
    CompileShaderFromFile = pBlob
End Function

' ============================================================
' Window Procedure
' ============================================================
Public Function WindowProc(ByVal hWnd As LongPtr, ByVal uMsg As Long, ByVal wParam As LongPtr, ByVal lParam As LongPtr) As LongPtr
    Select Case uMsg
        Case WM_CLOSE: DestroyWindow hWnd: WindowProc = 0: Exit Function
        Case WM_DESTROY: PostQuitMessage 0: WindowProc = 0: Exit Function
    End Select
    WindowProc = DefWindowProcW(hWnd, uMsg, wParam, lParam)
End Function

' ============================================================
' Initialize DirectX 12 (abbreviated - same as original)
' ============================================================
Private Function InitD3D12(ByVal hWnd As LongPtr) As Boolean
    LogMsg "InitD3D12: start"
    Dim hr As Long

    ' Try to enable D3D12 debug layer (best effort)
    Dim pDebug As LongPtr
    Dim debugIID As GUID: debugIID = IID_ID3D12Debug()
    hr = D3D12GetDebugInterface(debugIID, pDebug)
    If hr >= 0 And pDebug <> 0 Then
        LogMsg "  EnableDebugLayer..."
        COM_Call1 pDebug, VTBL_D3D12Debug_EnableDebugLayer
        COM_Release pDebug
        LogMsg "  EnableDebugLayer: OK"
    Else
        LogMsg "  EnableDebugLayer: unavailable (hr=" & hr & ", pDebug=" & pDebug & ")"
    End If
    
    LogMsg "  CreateDXGIFactory1..."
    Dim pFactory As LongPtr
    Dim factoryIID As GUID: factoryIID = IID_IDXGIFactory1()
    hr = CreateDXGIFactory1(factoryIID, pFactory)
    If hr < 0 Or pFactory = 0 Then LogMsg "  CreateDXGIFactory1: FAILED": InitD3D12 = False: Exit Function
    LogMsg "  CreateDXGIFactory1: OK"
    
    LogMsg "  D3D12CreateDevice..."
    Dim deviceIID As GUID: deviceIID = IID_ID3D12Device()
    hr = D3D12CreateDevice(0, D3D_FEATURE_LEVEL_12_0, deviceIID, g_pDevice)
    If hr < 0 Or g_pDevice = 0 Then LogMsg "  D3D12CreateDevice: FAILED": COM_Release pFactory: InitD3D12 = False: Exit Function
    LogMsg "  D3D12CreateDevice: OK"
    
    LogMsg "  CreateCommandQueue..."
    Dim queueDesc As D3D12_COMMAND_QUEUE_DESC: queueDesc.cType = D3D12_COMMAND_LIST_TYPE_DIRECT
    Dim queueIID As GUID: queueIID = IID_ID3D12CommandQueue()
    hr = ToHResult(COM_Call4(g_pDevice, VTBL_Device_CreateCommandQueue, VarPtr(queueDesc), VarPtr(queueIID), VarPtr(g_pCommandQueue)))
    If hr < 0 Or g_pCommandQueue = 0 Then LogMsg "  CreateCommandQueue: FAILED": COM_Release pFactory: InitD3D12 = False: Exit Function
    LogMsg "  CreateCommandQueue: OK"
    
    Dim swapChainDesc As DXGI_SWAP_CHAIN_DESC
    swapChainDesc.bufferDesc.Width = Width: swapChainDesc.bufferDesc.Height = Height
    swapChainDesc.bufferDesc.Format = DXGI_FORMAT_R8G8B8A8_UNORM
    swapChainDesc.SampleDesc.count = 1: swapChainDesc.BufferUsage = DXGI_USAGE_RENDER_TARGET_OUTPUT
    swapChainDesc.BufferCount = FRAME_COUNT: swapChainDesc.OutputWindow = hWnd
    swapChainDesc.Windowed = 1: swapChainDesc.SwapEffect = DXGI_SWAP_EFFECT_FLIP_DISCARD
    
    LogMsg "  CreateSwapChain..."
    hr = ToHResult(COM_Call4(pFactory, VTBL_Factory_CreateSwapChain, g_pCommandQueue, VarPtr(swapChainDesc), VarPtr(g_pSwapChain)))
    If hr < 0 Or g_pSwapChain = 0 Then LogMsg "  CreateSwapChain: FAILED": COM_Release pFactory: InitD3D12 = False: Exit Function
    LogMsg "  CreateSwapChain: OK"
    
    LogMsg "  QueryInterface SwapChain3..."
    Dim swapChain3IID As GUID: swapChain3IID = IID_IDXGISwapChain3()
    hr = ToHResult(COM_Call3(g_pSwapChain, ONVTBL_IUnknown_QueryInterface, VarPtr(swapChain3IID), VarPtr(g_pSwapChain3)))
    If hr < 0 Or g_pSwapChain3 = 0 Then LogMsg "  QueryInterface SwapChain3: FAILED": COM_Release pFactory: InitD3D12 = False: Exit Function
    LogMsg "  QueryInterface SwapChain3: OK"
    
    g_frameIndex = CLng(COM_Call1(g_pSwapChain3, VTBL_SwapChain3_GetCurrentBackBufferIndex))
    
    ' RTV heap
    LogMsg "  CreateDescriptorHeap (RTV)..."
    Dim rtvHeapDesc As D3D12_DESCRIPTOR_HEAP_DESC
    rtvHeapDesc.cType = D3D12_DESCRIPTOR_HEAP_TYPE_RTV: rtvHeapDesc.NumDescriptors = FRAME_COUNT
    Dim heapIID As GUID: heapIID = IID_ID3D12DescriptorHeap()
    hr = ToHResult(COM_Call4(g_pDevice, VTBL_Device_CreateDescriptorHeap, VarPtr(rtvHeapDesc), VarPtr(heapIID), VarPtr(g_pRtvHeap)))
    If hr < 0 Then LogMsg "  CreateDescriptorHeap (RTV): FAILED": COM_Release pFactory: InitD3D12 = False: Exit Function
    LogMsg "  CreateDescriptorHeap (RTV): OK ptr=" & g_pRtvHeap
    
    g_rtvDescriptorSize = CLng(COM_Call2(g_pDevice, VTBL_Device_GetDescriptorHandleIncrementSize, D3D12_DESCRIPTOR_HEAP_TYPE_RTV))
    
    ' SRV/UAV heap
    LogMsg "  CreateDescriptorHeap (SRV/UAV)..."
    Dim srvUavHeapDesc As D3D12_DESCRIPTOR_HEAP_DESC
    srvUavHeapDesc.cType = D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV
    srvUavHeapDesc.NumDescriptors = 5
    srvUavHeapDesc.Flags = D3D12_DESCRIPTOR_HEAP_FLAG_SHADER_VISIBLE
    hr = ToHResult(COM_Call4(g_pDevice, VTBL_Device_CreateDescriptorHeap, VarPtr(srvUavHeapDesc), VarPtr(heapIID), VarPtr(g_pSrvUavHeap)))
    If hr < 0 Then LogMsg "  CreateDescriptorHeap (SRV/UAV): FAILED": COM_Release pFactory: InitD3D12 = False: Exit Function
    LogMsg "  CreateDescriptorHeap (SRV/UAV): OK ptr=" & g_pSrvUavHeap
    
    g_srvUavDescriptorSize = CLng(COM_Call2(g_pDevice, VTBL_Device_GetDescriptorHandleIncrementSize, D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV))
    LogMsg "  Descriptor sizes: RTV=" & g_rtvDescriptorSize & " SRV/UAV=" & g_srvUavDescriptorSize
    
    ' RTVs
    LogMsg "  CreateRenderTargetViews..."
    Dim rtvHandle As D3D12_CPU_DESCRIPTOR_HANDLE
    LogMsg "    Before GetCPUDescriptorHandle (heap=" & g_pRtvHeap & ")"
    COM_GetCPUDescriptorHandle g_pRtvHeap, rtvHandle
    LogMsg "    After GetCPUDescriptorHandle (handle=0x" & Hex$(rtvHandle.ptr) & ")"
    LogMsg "    RTV heap ptr=" & g_pRtvHeap & " handle=0x" & Hex$(rtvHandle.ptr) & " descSize=" & g_rtvDescriptorSize
    Dim resourceIID As GUID: resourceIID = IID_ID3D12Resource()
    
    Dim frameIdx As Long
    For frameIdx = 0 To FRAME_COUNT - 1
        hr = ToHResult(COM_Call4(g_pSwapChain, VTBL_SwapChain_GetBuffer, frameIdx, VarPtr(resourceIID), VarPtr(g_pRenderTargets(frameIdx))))
        If hr < 0 Then LogMsg "    GetBuffer(" & frameIdx & "): FAILED": COM_Release pFactory: InitD3D12 = False: Exit Function
        LogMsg "    RTV" & frameIdx & " handle=0x" & Hex$(rtvHandle.ptr)
        COM_Call4 g_pDevice, VTBL_Device_CreateRenderTargetView, g_pRenderTargets(frameIdx), 0, rtvHandle.ptr
        rtvHandle.ptr = rtvHandle.ptr + g_rtvDescriptorSize
    Next frameIdx
    LogMsg "  CreateRenderTargetViews: OK"
    
    ' Command allocators
    LogMsg "  CreateCommandAllocators..."
    Dim allocIID As GUID: allocIID = IID_ID3D12CommandAllocator()
    For frameIdx = 0 To FRAME_COUNT - 1
        hr = ToHResult(COM_Call4(g_pDevice, VTBL_Device_CreateCommandAllocator, D3D12_COMMAND_LIST_TYPE_DIRECT, VarPtr(allocIID), VarPtr(g_pCommandAllocators(frameIdx))))
        If hr < 0 Or g_pCommandAllocators(frameIdx) = 0 Then LogMsg "    CreateCommandAllocator(" & frameIdx & "): FAILED": COM_Release pFactory: InitD3D12 = False: Exit Function
        g_fenceValues(frameIdx) = 0
    Next frameIdx
    LogMsg "  CreateCommandAllocators: OK"
    
    COM_Release pFactory
    InitD3D12 = True
    LogMsg "InitD3D12: done (SUCCESS)"
End Function

' ============================================================
' Create Root Signatures (abbreviated)
' ============================================================
Private Function CreateComputeRootSignature() As Boolean
    LogMsg "CreateComputeRootSignature: start"
    Dim ranges(0 To 1) As D3D12_DESCRIPTOR_RANGE
    ranges(0).RangeType = D3D12_DESCRIPTOR_RANGE_TYPE_UAV: ranges(0).NumDescriptors = 2
    ranges(0).BaseShaderRegister = 0: ranges(0).RegisterSpace = 0: ranges(0).OffsetInDescriptorsFromTableStart = D3D12_DESCRIPTOR_RANGE_OFFSET_APPEND
    ranges(1).RangeType = D3D12_DESCRIPTOR_RANGE_TYPE_CBV: ranges(1).NumDescriptors = 1
    ranges(1).BaseShaderRegister = 0: ranges(1).RegisterSpace = 0: ranges(1).OffsetInDescriptorsFromTableStart = D3D12_DESCRIPTOR_RANGE_OFFSET_APPEND
    
    Dim params(0 To 1) As D3D12_ROOT_PARAMETER
    params(0).ParameterType = D3D12_ROOT_PARAMETER_TYPE_DESCRIPTOR_TABLE
    params(0).DescriptorTable.NumDescriptorRanges = 1: params(0).DescriptorTable.pDescriptorRanges = VarPtr(ranges(0))
    params(0).ShaderVisibility = D3D12_SHADER_VISIBILITY_ALL
    params(1).ParameterType = D3D12_ROOT_PARAMETER_TYPE_DESCRIPTOR_TABLE
    params(1).DescriptorTable.NumDescriptorRanges = 1: params(1).DescriptorTable.pDescriptorRanges = VarPtr(ranges(1))
    params(1).ShaderVisibility = D3D12_SHADER_VISIBILITY_ALL
    
    Dim rootSigDesc As D3D12_ROOT_SIGNATURE_DESC
    rootSigDesc.NumParameters = 2: rootSigDesc.pParameters = VarPtr(params(0))
    rootSigDesc.Flags = D3D12_ROOT_SIGNATURE_FLAG_NONE
    
    LogMsg "  SerializeRootSignature..."
    Dim pSignatureBlob As LongPtr, pErrorBlob As LongPtr
    Dim hr As Long: hr = D3D12SerializeRootSignature(rootSigDesc, D3D_ROOT_SIGNATURE_VERSION_1, pSignatureBlob, pErrorBlob)
    If hr < 0 Then LogMsg "  SerializeRootSignature: FAILED": CreateComputeRootSignature = False: Exit Function
    LogMsg "  SerializeRootSignature: OK"
    
    LogMsg "  CreateRootSignature..."
    Dim rootSigIID As GUID: rootSigIID = IID_ID3D12RootSignature()
    hr = ToHResult(COM_Call6(g_pDevice, VTBL_Device_CreateRootSignature, 0, COM_Call1(pSignatureBlob, VTBL_Blob_GetBufferPointer), COM_Call1(pSignatureBlob, VTBL_Blob_GetBufferSize), VarPtr(rootSigIID), VarPtr(g_pComputeRootSignature)))
    COM_Release pSignatureBlob
    If hr >= 0 And g_pComputeRootSignature <> 0 Then
        CreateComputeRootSignature = True
        LogMsg "CreateComputeRootSignature: done (SUCCESS)"
    Else
        LogMsg "  CreateRootSignature: FAILED (hr=" & hr & ")"
        CreateComputeRootSignature = False
    End If
End Function

Private Function COM_Call6(ByVal pObj As LongPtr, ByVal vtIndex As Long, ByVal a2 As LongPtr, ByVal a3 As LongPtr, ByVal a4 As LongPtr, ByVal a5 As LongPtr, ByVal a6 As LongPtr) As LongPtr
    Dim methodAddr As LongPtr: methodAddr = GetVTableMethod(pObj, vtIndex)
    Dim code(0 To 99) As Byte: Dim i As Long: i = 0
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
    Dim t As LongLong: t = methodAddr: RtlMoveMemoryFromPtr VarPtr(code(i)), t, 8: i = i + 8
    code(i) = &HFF: i = i + 1: code(i) = &HD0: i = i + 1
    code(i) = &H48: i = i + 1: code(i) = &H83: i = i + 1: code(i) = &HC4: i = i + 1: code(i) = &H48: i = i + 1
    code(i) = &HC3
    Dim mem As LongPtr: mem = VirtualAlloc(0, 128, MEM_COMMIT Or MEM_RESERVE, PAGE_EXECUTE_READWRITE)
    CopyMemory mem, VarPtr(code(0)), CLngPtr(i + 1)
    Dim args As ThunkArgs6: args.a1 = pObj: args.a2 = a2: args.a3 = a3: args.a4 = a4: args.a5 = a5: args.a6 = a6
    COM_Call6 = CallWindowProcW(mem, 0, 0, VarPtr(args), 0)
    VirtualFree mem, 0, MEM_RELEASE
End Function

Private Function COM_Call7(ByVal pObj As LongPtr, ByVal vtIndex As Long, ByVal a2 As LongPtr, ByVal a3 As LongPtr, ByVal a4 As LongPtr, ByVal a5 As LongPtr, ByVal a6 As LongPtr, ByVal a7 As LongPtr) As LongPtr
    Dim methodAddr As LongPtr: methodAddr = GetVTableMethod(pObj, vtIndex)
    Dim thunk As LongPtr: thunk = BuildThunk7(methodAddr)
    Dim args As ThunkArgs7: args.a1 = pObj: args.a2 = a2: args.a3 = a3: args.a4 = a4: args.a5 = a5: args.a6 = a6: args.a7 = a7
    COM_Call7 = CallWindowProcW(thunk, 0, 0, VarPtr(args), 0)
    VirtualFree thunk, 0, MEM_RELEASE
End Function

Private Function CreateGraphicsRootSignature() As Boolean
    LogMsg "CreateGraphicsRootSignature: start"
    Dim ranges(0 To 1) As D3D12_DESCRIPTOR_RANGE
    ranges(0).RangeType = D3D12_DESCRIPTOR_RANGE_TYPE_SRV: ranges(0).NumDescriptors = 2
    ranges(0).BaseShaderRegister = 0: ranges(0).RegisterSpace = 0: ranges(0).OffsetInDescriptorsFromTableStart = D3D12_DESCRIPTOR_RANGE_OFFSET_APPEND
    ranges(1).RangeType = D3D12_DESCRIPTOR_RANGE_TYPE_CBV: ranges(1).NumDescriptors = 1
    ranges(1).BaseShaderRegister = 0: ranges(1).RegisterSpace = 0: ranges(1).OffsetInDescriptorsFromTableStart = D3D12_DESCRIPTOR_RANGE_OFFSET_APPEND
    
    Dim params(0 To 1) As D3D12_ROOT_PARAMETER
    params(0).ParameterType = D3D12_ROOT_PARAMETER_TYPE_DESCRIPTOR_TABLE
    params(0).DescriptorTable.NumDescriptorRanges = 1: params(0).DescriptorTable.pDescriptorRanges = VarPtr(ranges(0))
    params(0).ShaderVisibility = D3D12_SHADER_VISIBILITY_VERTEX
    params(1).ParameterType = D3D12_ROOT_PARAMETER_TYPE_DESCRIPTOR_TABLE
    params(1).DescriptorTable.NumDescriptorRanges = 1: params(1).DescriptorTable.pDescriptorRanges = VarPtr(ranges(1))
    params(1).ShaderVisibility = D3D12_SHADER_VISIBILITY_ALL
    
    Dim rootSigDesc As D3D12_ROOT_SIGNATURE_DESC
    rootSigDesc.NumParameters = 2: rootSigDesc.pParameters = VarPtr(params(0))
    rootSigDesc.Flags = D3D12_ROOT_SIGNATURE_FLAG_ALLOW_INPUT_ASSEMBLER_INPUT_LAYOUT
    
    LogMsg "  SerializeRootSignature..."
    Dim pSignatureBlob As LongPtr, pErrorBlob As LongPtr
    Dim hr As Long: hr = D3D12SerializeRootSignature(rootSigDesc, D3D_ROOT_SIGNATURE_VERSION_1, pSignatureBlob, pErrorBlob)
    If hr < 0 Then LogMsg "  SerializeRootSignature: FAILED": CreateGraphicsRootSignature = False: Exit Function
    LogMsg "  SerializeRootSignature: OK"
    
    LogMsg "  CreateRootSignature..."
    Dim rootSigIID As GUID: rootSigIID = IID_ID3D12RootSignature()
    hr = ToHResult(COM_Call6(g_pDevice, VTBL_Device_CreateRootSignature, 0, COM_Call1(pSignatureBlob, VTBL_Blob_GetBufferPointer), COM_Call1(pSignatureBlob, VTBL_Blob_GetBufferSize), VarPtr(rootSigIID), VarPtr(g_pGraphicsRootSignature)))
    COM_Release pSignatureBlob
    If hr >= 0 And g_pGraphicsRootSignature <> 0 Then
        CreateGraphicsRootSignature = True
        LogMsg "CreateGraphicsRootSignature: done (SUCCESS)"
    Else
        LogMsg "  CreateRootSignature: FAILED (hr=" & hr & ")"
        CreateGraphicsRootSignature = False
    End If
End Function

Private Function CreatePipelineStates() As Boolean
    LogMsg "CreatePipelineStates: start"
    ' Compute PSO
    LogMsg "  Compiling compute shader..."
    Dim pCSBlob As LongPtr: pCSBlob = CompileShaderFromFile(g_shaderPath, "CSMain", "cs_5_0")
    If pCSBlob = 0 Then LogMsg "  Compiling compute shader: FAILED": CreatePipelineStates = False: Exit Function
    LogMsg "  Compiling compute shader: OK"
    
    Dim computePsoDesc As D3D12_COMPUTE_PIPELINE_STATE_DESC
    computePsoDesc.pRootSignature = g_pComputeRootSignature
    computePsoDesc.CS.pShaderBytecode = COM_Call1(pCSBlob, VTBL_Blob_GetBufferPointer)
    computePsoDesc.CS.BytecodeLength = COM_Call1(pCSBlob, VTBL_Blob_GetBufferSize)
    
    LogMsg "  CreateComputePipelineState..."
    Dim psoIID As GUID: psoIID = IID_ID3D12PipelineState()
    Dim hr As Long: hr = ToHResult(COM_Call4(g_pDevice, VTBL_Device_CreateComputePipelineState, VarPtr(computePsoDesc), VarPtr(psoIID), VarPtr(g_pComputePipelineState)))
    COM_Release pCSBlob
    If hr < 0 Or g_pComputePipelineState = 0 Then LogMsg "  CreateComputePipelineState: FAILED": CreatePipelineStates = False: Exit Function
    LogMsg "  CreateComputePipelineState: OK"
    
    ' Graphics PSO
    LogMsg "  Compiling vertex shader..."
    Dim pVSBlob As LongPtr: pVSBlob = CompileShaderFromFile(g_shaderPath, "VSMain", "vs_5_0")
    If pVSBlob = 0 Then LogMsg "  Compiling vertex shader: FAILED": CreatePipelineStates = False: Exit Function
    LogMsg "  Compiling vertex shader: OK"
    LogMsg "  Compiling pixel shader..."
    Dim pPSBlob As LongPtr: pPSBlob = CompileShaderFromFile(g_shaderPath, "PSMain", "ps_5_0")
    If pPSBlob = 0 Then LogMsg "  Compiling pixel shader: FAILED": COM_Release pVSBlob: CreatePipelineStates = False: Exit Function
    LogMsg "  Compiling pixel shader: OK"
    
    Dim graphicsPsoDesc As D3D12_GRAPHICS_PIPELINE_STATE_DESC
    graphicsPsoDesc.pRootSignature = g_pGraphicsRootSignature
    graphicsPsoDesc.VS.pShaderBytecode = COM_Call1(pVSBlob, VTBL_Blob_GetBufferPointer)
    graphicsPsoDesc.VS.BytecodeLength = COM_Call1(pVSBlob, VTBL_Blob_GetBufferSize)
    graphicsPsoDesc.PS.pShaderBytecode = COM_Call1(pPSBlob, VTBL_Blob_GetBufferPointer)
    graphicsPsoDesc.PS.BytecodeLength = COM_Call1(pPSBlob, VTBL_Blob_GetBufferSize)
    graphicsPsoDesc.BlendState.RenderTarget(0).SrcBlend = D3D12_BLEND_ONE
    graphicsPsoDesc.BlendState.RenderTarget(0).DestBlend = D3D12_BLEND_ZERO
    graphicsPsoDesc.BlendState.RenderTarget(0).BlendOp = D3D12_BLEND_OP_ADD
    graphicsPsoDesc.BlendState.RenderTarget(0).SrcBlendAlpha = D3D12_BLEND_ONE
    graphicsPsoDesc.BlendState.RenderTarget(0).DestBlendAlpha = D3D12_BLEND_ZERO
    graphicsPsoDesc.BlendState.RenderTarget(0).BlendOpAlpha = D3D12_BLEND_OP_ADD
    graphicsPsoDesc.BlendState.RenderTarget(0).LogicOp = D3D12_LOGIC_OP_NOOP
    graphicsPsoDesc.BlendState.RenderTarget(0).RenderTargetWriteMask = D3D12_COLOR_WRITE_ENABLE_ALL
    graphicsPsoDesc.SampleMask = &HFFFFFFFF
    graphicsPsoDesc.RasterizerState.FillMode = D3D12_FILL_MODE_SOLID
    graphicsPsoDesc.RasterizerState.CullMode = D3D12_CULL_MODE_NONE
    graphicsPsoDesc.RasterizerState.DepthClipEnable = 1
    graphicsPsoDesc.PrimitiveTopologyType = D3D12_PRIMITIVE_TOPOLOGY_TYPE_LINE
    graphicsPsoDesc.NumRenderTargets = 1
    graphicsPsoDesc.RTVFormats(0) = DXGI_FORMAT_R8G8B8A8_UNORM
    graphicsPsoDesc.SampleDesc.count = 1
    
    hr = ToHResult(COM_Call4(g_pDevice, VTBL_Device_CreateGraphicsPipelineState, VarPtr(graphicsPsoDesc), VarPtr(psoIID), VarPtr(g_pGraphicsPipelineState)))
    COM_Release pVSBlob: COM_Release pPSBlob
    If hr >= 0 And g_pGraphicsPipelineState <> 0 Then
        CreatePipelineStates = True
        LogMsg "CreatePipelineStates: done (SUCCESS)"
    Else
        LogMsg "  CreateGraphicsPipelineState: FAILED (hr=" & hr & ")"
        CreatePipelineStates = False
    End If
End Function

Private Function CreateCommandLists() As Boolean
    LogMsg "CreateCommandLists: start"
    LogMsg "  CreateCommandList..."
    Dim cmdListIID As GUID: cmdListIID = IID_ID3D12GraphicsCommandList()
    Dim hr As Long: hr = ToHResult(COM_Call7(g_pDevice, VTBL_Device_CreateCommandList, 0, D3D12_COMMAND_LIST_TYPE_DIRECT, g_pCommandAllocators(0), g_pComputePipelineState, VarPtr(cmdListIID), VarPtr(g_pGraphicsCommandList)))
    If hr < 0 Or g_pGraphicsCommandList = 0 Then LogMsg "  CreateCommandList: FAILED": CreateCommandLists = False: Exit Function
    LogMsg "  CreateCommandList: OK"
    LogMsg "  Close command list..."
    COM_Call1 g_pGraphicsCommandList, VTBL_CmdList_Close
    CreateCommandLists = True
    LogMsg "CreateCommandLists: done (SUCCESS)"
End Function

Private Function CreateBuffers() As Boolean
    LogMsg "CreateBuffers: start (" & VERTEX_COUNT & " vertices)"
    Dim bufferSize As LongLong: bufferSize = CLngLng(VERTEX_COUNT) * 16
    
    Dim heapProps As D3D12_HEAP_PROPERTIES
    heapProps.cType = D3D12_HEAP_TYPE_DEFAULT: heapProps.CreationNodeMask = 1: heapProps.VisibleNodeMask = 1
    
    Dim resourceDesc As D3D12_RESOURCE_DESC
    resourceDesc.Dimension = D3D12_RESOURCE_DIMENSION_BUFFER
    resourceDesc.Width = bufferSize: resourceDesc.Height = 1
    resourceDesc.DepthOrArraySize = 1: resourceDesc.MipLevels = 1
    resourceDesc.SampleDesc.count = 1: resourceDesc.Layout = 1
    resourceDesc.Flags = D3D12_RESOURCE_FLAG_ALLOW_UNORDERED_ACCESS
    
    Dim resourceIID As GUID: resourceIID = IID_ID3D12Resource()
    Dim thunk As LongPtr: thunk = BuildThunk8(GetVTableMethod(g_pDevice, VTBL_Device_CreateCommittedResource))
    
    LogMsg "  CreatePositionBuffer..."
    Dim args8 As ThunkArgs8
    args8.a1 = g_pDevice: args8.a2 = VarPtr(heapProps): args8.a3 = D3D12_HEAP_FLAG_NONE
    args8.a4 = VarPtr(resourceDesc): args8.a5 = D3D12_RESOURCE_STATE_UNORDERED_ACCESS
    args8.a6 = 0: args8.a7 = VarPtr(resourceIID): args8.a8 = VarPtr(g_pPositionBuffer)
    
    Dim hr As Long: hr = ToHResult(CallWindowProcW(thunk, 0, 0, VarPtr(args8), 0))
    If hr < 0 Or g_pPositionBuffer = 0 Then LogMsg "  CreatePositionBuffer: FAILED": VirtualFree thunk, 0, MEM_RELEASE: CreateBuffers = False: Exit Function
    LogMsg "  CreatePositionBuffer: OK"
    
    LogMsg "  CreateColorBuffer..."
    args8.a8 = VarPtr(g_pColorBuffer)
    hr = ToHResult(CallWindowProcW(thunk, 0, 0, VarPtr(args8), 0))
    If hr < 0 Or g_pColorBuffer = 0 Then LogMsg "  CreateColorBuffer: FAILED": VirtualFree thunk, 0, MEM_RELEASE: CreateBuffers = False: Exit Function
    LogMsg "  CreateColorBuffer: OK"
    
    ' Constant buffer
    LogMsg "  CreateConstantBuffer..."
    Dim cbSize As LongLong: cbSize = 256
    heapProps.cType = D3D12_HEAP_TYPE_UPLOAD
    resourceDesc.Width = cbSize: resourceDesc.Flags = 0
    args8.a2 = VarPtr(heapProps): args8.a4 = VarPtr(resourceDesc)
    args8.a5 = D3D12_RESOURCE_STATE_GENERIC_READ: args8.a8 = VarPtr(g_pConstantBuffer)
    hr = ToHResult(CallWindowProcW(thunk, 0, 0, VarPtr(args8), 0))
    VirtualFree thunk, 0, MEM_RELEASE
    If hr < 0 Or g_pConstantBuffer = 0 Then LogMsg "  CreateConstantBuffer: FAILED": CreateBuffers = False: Exit Function
    LogMsg "  CreateConstantBuffer: OK"
    
    LogMsg "  Map constant buffer..."
    hr = ToHResult(COM_Call4(g_pConstantBuffer, VTBL_Resource_Map, 0, 0, VarPtr(g_pConstantBufferPtr)))
    If hr < 0 Or g_pConstantBufferPtr = 0 Then LogMsg "  Map constant buffer: FAILED": CreateBuffers = False: Exit Function
    LogMsg "  Map constant buffer: OK"
    
    CreateBuffers = True
    LogMsg "CreateBuffers: done (SUCCESS)"
End Function

Private Function CreateViews() As Boolean
    LogMsg "CreateViews: start"
    Dim cpuHandle As D3D12_CPU_DESCRIPTOR_HANDLE
    COM_GetCPUDescriptorHandle g_pSrvUavHeap, cpuHandle
    LogMsg "  SRV/UAV heap ptr=" & g_pSrvUavHeap & " cpuHandle.ptr=0x" & Hex$(cpuHandle.ptr) & " descSize=" & g_srvUavDescriptorSize
    
    ' Store initial handle for validation
    Dim heapStartHandle As LongPtr: heapStartHandle = cpuHandle.ptr
    
    ' UAVs
    LogMsg "  CreateUnorderedAccessViews..."
    Dim uavDesc As D3D12_UNORDERED_ACCESS_VIEW_DESC
    uavDesc.Format = DXGI_FORMAT_UNKNOWN: uavDesc.ViewDimension = D3D12_UAV_DIMENSION_BUFFER
    uavDesc.Buffer_FirstElement = 0: uavDesc.Buffer_NumElements = VERTEX_COUNT: uavDesc.Buffer_StructureByteStride = 16
    uavDesc.Buffer_CounterOffsetInBytes = 0: uavDesc.Buffer_Flags = 0
    
    COM_Call5 g_pDevice, VTBL_Device_CreateUnorderedAccessView, g_pPositionBuffer, 0, VarPtr(uavDesc), cpuHandle.ptr
    LogMsg "    UAV0 handle=0x" & Hex$(cpuHandle.ptr) & " (offset=" & (cpuHandle.ptr - heapStartHandle) & ")"
    cpuHandle.ptr = cpuHandle.ptr + g_srvUavDescriptorSize
    COM_Call5 g_pDevice, VTBL_Device_CreateUnorderedAccessView, g_pColorBuffer, 0, VarPtr(uavDesc), cpuHandle.ptr
    LogMsg "    UAV1 handle=0x" & Hex$(cpuHandle.ptr) & " (offset=" & (cpuHandle.ptr - heapStartHandle) & ")"
    cpuHandle.ptr = cpuHandle.ptr + g_srvUavDescriptorSize
    LogMsg "  CreateUnorderedAccessViews: OK"
    
    ' SRVs
    LogMsg "  CreateShaderResourceViews..."
    Dim srvDesc As D3D12_SHADER_RESOURCE_VIEW_DESC
    srvDesc.Format = DXGI_FORMAT_UNKNOWN: srvDesc.ViewDimension = D3D12_SRV_DIMENSION_BUFFER
    srvDesc.Shader4ComponentMapping = D3D12_DEFAULT_SHADER_4_COMPONENT_MAPPING
    srvDesc.Buffer_FirstElement = 0: srvDesc.Buffer_NumElements = VERTEX_COUNT: srvDesc.Buffer_StructureByteStride = 16
    srvDesc.Buffer_Flags = 0
    
    LogMsg "    SRV0 handle=0x" & Hex$(cpuHandle.ptr) & " (offset=" & (cpuHandle.ptr - heapStartHandle) & ")"
    COM_Call4 g_pDevice, VTBL_Device_CreateShaderResourceView, g_pPositionBuffer, VarPtr(srvDesc), cpuHandle.ptr
    LogMsg "    SRV0 created"
    cpuHandle.ptr = cpuHandle.ptr + g_srvUavDescriptorSize
    LogMsg "    SRV1 handle=0x" & Hex$(cpuHandle.ptr) & " (offset=" & (cpuHandle.ptr - heapStartHandle) & ")"
    COM_Call4 g_pDevice, VTBL_Device_CreateShaderResourceView, g_pColorBuffer, VarPtr(srvDesc), cpuHandle.ptr
    LogMsg "    SRV1 created"
    cpuHandle.ptr = cpuHandle.ptr + g_srvUavDescriptorSize
    LogMsg "  CreateShaderResourceViews: OK"
    
    ' CBV
    LogMsg "  CreateConstantBufferView..."
    Dim cbvDesc As D3D12_CONSTANT_BUFFER_VIEW_DESC
    cbvDesc.BufferLocation = COM_Call1(g_pConstantBuffer, VTBL_Resource_GetGPUVirtualAddress)
    cbvDesc.SizeInBytes = 256
    LogMsg "    CBV handle=0x" & Hex$(cpuHandle.ptr) & " (offset=" & (cpuHandle.ptr - heapStartHandle) & ")"
    COM_Call3 g_pDevice, VTBL_Device_CreateConstantBufferView, VarPtr(cbvDesc), cpuHandle.ptr
    LogMsg "  CreateConstantBufferView: OK handle=0x" & Hex$(cpuHandle.ptr)
    
    CreateViews = True
    LogMsg "CreateViews: done (SUCCESS)"
End Function

Private Function CreateFence() As Boolean
    LogMsg "CreateFence: start"
    LogMsg "  IID_ID3D12Fence..."
    Dim fenceIID As GUID: fenceIID = IID_ID3D12Fence()
    LogMsg "  CreateFence (COM)..."
    Dim hr As Long: hr = ToHResult(COM_Call5(g_pDevice, VTBL_Device_CreateFence, 0, D3D12_FENCE_FLAG_NONE, VarPtr(fenceIID), VarPtr(g_pFence)))
    If hr < 0 Or g_pFence = 0 Then
        Dim dr As Long: dr = ToHResult(COM_Call1(g_pDevice, VTBL_Device_GetDeviceRemovedReason))
        LogMsg "  CreateFence (COM): FAILED (hr=" & hr & ", pFence=" & g_pFence & ", removedReason=" & dr & ")"
        CreateFence = False: Exit Function
    End If
    LogMsg "  CreateFence (COM): OK (pFence=" & g_pFence & ")"
    g_fenceValue = 1
    LogMsg "  CreateEventW..."
    g_fenceEvent = CreateEventW(0, 0, 0, 0)
    If g_fenceEvent = 0 Then
        LogMsg "  CreateEventW: FAILED"
        CreateFence = False
    Else
        CreateFence = True
        LogMsg "  CreateEventW: OK (hEvent=" & g_fenceEvent & ")"
        LogMsg "CreateFence: done (SUCCESS)"
    End If
End Function

' ============================================================
' Harmonograph parameters (matching C# version)
' ============================================================
Private Sub InitHarmonographParams()
    ' Same initial values as C# version
    g_A1 = 50!: g_f1 = 2!: g_p1 = 1! / 16!: g_d1 = 0.02!
    g_A2 = 50!: g_f2 = 2!: g_p2 = 3! / 2!: g_d2 = 0.0315!
    g_A3 = 50!: g_f3 = 2!: g_p3 = 13! / 15!: g_d3 = 0.02!
    g_A4 = 50!: g_f4 = 2!: g_p4 = 1!: g_d4 = 0.02!
    
    ' Pre-fill constant buffer
    g_cbParams.a1 = g_A1: g_cbParams.f1 = g_f1: g_cbParams.p1 = g_p1: g_cbParams.d1 = g_d1
    g_cbParams.a2 = g_A2: g_cbParams.f2 = g_f2: g_cbParams.p2 = g_p2: g_cbParams.d2 = g_d2
    g_cbParams.a3 = g_A3: g_cbParams.f3 = g_f3: g_cbParams.p3 = g_p3: g_cbParams.d3 = g_d3
    g_cbParams.a4 = g_A4: g_cbParams.f4 = g_f4: g_cbParams.p4 = g_p4: g_cbParams.d4 = g_d4
    g_cbParams.max_num = VERTEX_COUNT
    g_cbParams.resolutionX = CSng(Width): g_cbParams.resolutionY = CSng(Height)
    g_cbParamsSize = CLngPtr(LenB(g_cbParams))
End Sub

Private Function FMod(ByVal x As Single, ByVal y As Single) As Single
    FMod = x - Int(x / y) * y
End Function

Private Sub UpdateConstantBuffer()
    ' Animate parameters exactly like C# version
    g_f1 = FMod(g_f1 + Rnd / 200!, 10!)
    g_f2 = FMod(g_f2 + Rnd / 200!, 10!)
    g_p1 = g_p1 + (PI2 * 0.5! / 360!)
    
    g_cbParams.f1 = g_f1: g_cbParams.p1 = g_p1: g_cbParams.f2 = g_f2
    CopyMemory g_pConstantBufferPtr, VarPtr(g_cbParams), g_cbParamsSize
End Sub

' ============================================================
' *** PERF OPTIMIZED: MoveToNextFrame - no logging ***
' ============================================================
Private Sub MoveToNextFrame()
    Dim currentFenceValue As LongLong: currentFenceValue = g_fenceValue
    Fast_Signal currentFenceValue
    
    Dim nextFrameIndex As Long: nextFrameIndex = Fast_GetCurrentBackBufferIndex()
    Dim nextFrameFenceValue As LongLong: nextFrameFenceValue = g_fenceValues(nextFrameIndex)
    
    Dim completed As LongLong: completed = Fast_GetFenceCompletedValue()
    
    If completed < nextFrameFenceValue Then
        Dim spinCount As Long
        For spinCount = 0 To 9
            completed = Fast_GetFenceCompletedValue()
            If completed >= nextFrameFenceValue Then GoTo SkipWait
        Next spinCount
        Fast_SetEventOnCompletion nextFrameFenceValue, g_fenceEvent
        WaitForSingleObject g_fenceEvent, 50
    End If
    
SkipWait:
    g_fenceValues(nextFrameIndex) = currentFenceValue + 1
    g_fenceValue = currentFenceValue + 1
    g_frameIndex = nextFrameIndex
End Sub

' ============================================================
' *** BATCH OPTIMIZED: RenderFrame - Uses batch thunks ***
' NOTE:
'   - Normal COM thunks: read the argument pointer from R8 (wParam / 4th arg of CallWindowProcW)
'   - Batch thunks:       read the argument pointer from R9 (lParam / 5th arg of CallWindowProcW)
'     => For ComputePassBatch / GraphicsDrawBatch, pass VarPtr(...) via the 5th argument (lParam).
' ============================================================
Private Sub RenderFrame()
    ProfilerBeginFrame

    UpdateConstantBuffer
    ProfilerMark PROF_UPDATE

    ' ------------------------------------------------------------
    ' Reset command allocator and command list
    ' (Normal thunk expects the args pointer in R8 (wParam))
    ' ------------------------------------------------------------
    g_args1_CmdAllocReset.a1 = g_pCommandAllocators(g_frameIndex)
    CallWindowProcW g_thunk_CmdAlloc_Reset, 0, 0, VarPtr(g_args1_CmdAllocReset), 0

    g_args3_CmdListReset.a2 = g_pCommandAllocators(g_frameIndex)
    CallWindowProcW g_thunk_CmdList_Reset, 0, 0, VarPtr(g_args3_CmdListReset), 0
    ProfilerMark PROF_RESET

    ' ------------------------------------------------------------
    ' Fetch the GPU descriptor heap base handle once (used by batched args)
    ' (Normal thunk expects the args pointer in R8 (wParam))
    ' ------------------------------------------------------------
    CallWindowProcW g_thunk_DescHeap_GetGPUHandle, 0, 0, VarPtr(g_args2_GetGPUHandle), 0

    ' ------------------------------------------------------------
    ' === COMPUTE PASS (batched) ===
    ' IMPORTANT:
    '   Batch thunk reads args pointer from R9 (lParam) -> pass VarPtr via the 5th argument.
    ' ------------------------------------------------------------
    g_batchComputeArgs.gpuHandle_UAV = g_gpuHandle.ptr
    g_batchComputeArgs.gpuHandle_CBV = g_gpuHandle.ptr + g_cbvOffset

    ' NOTE: Passing args pointer via lParam (5th arg) is required for this batch thunk.
    CallWindowProcW g_thunk_ComputePassBatch, 0, 0, 0, VarPtr(g_batchComputeArgs)
    ProfilerMark PROF_COMPUTE

    ' ------------------------------------------------------------
    ' Barrier: UAV -> SRV (positions / colors)
    ' - Ensure barrier structs are fully populated each frame to avoid uninitialized fields.
    ' - Field name is .cType in this VBA UDT.
    ' ------------------------------------------------------------
    With g_barriers(0)
        .cType = D3D12_RESOURCE_BARRIER_TYPE_TRANSITION
        .Flags = D3D12_RESOURCE_BARRIER_FLAG_NONE
        .Transition.pResource = g_pPositionBuffer
        .Transition.Subresource = D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES
        .Transition.StateBefore = D3D12_RESOURCE_STATE_UNORDERED_ACCESS
        .Transition.StateAfter = D3D12_RESOURCE_STATE_NON_PIXEL_SHADER_RESOURCE
    End With

    With g_barriers(1)
        .cType = D3D12_RESOURCE_BARRIER_TYPE_TRANSITION
        .Flags = D3D12_RESOURCE_BARRIER_FLAG_NONE
        .Transition.pResource = g_pColorBuffer
        .Transition.Subresource = D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES
        .Transition.StateBefore = D3D12_RESOURCE_STATE_UNORDERED_ACCESS
        .Transition.StateAfter = D3D12_RESOURCE_STATE_NON_PIXEL_SHADER_RESOURCE
    End With

    g_args3_ResourceBarrier.a2 = 2
    g_args3_ResourceBarrier.a3 = VarPtr(g_barriers(0))
    CallWindowProcW g_thunk_CmdList_ResourceBarrier, 0, 0, VarPtr(g_args3_ResourceBarrier), 0
    ProfilerMark PROF_BARRIER1

    ' ------------------------------------------------------------
    ' Barrier: Present -> RenderTarget (current back buffer)
    ' ------------------------------------------------------------
    With g_rtBarrier
        .cType = D3D12_RESOURCE_BARRIER_TYPE_TRANSITION
        .Flags = D3D12_RESOURCE_BARRIER_FLAG_NONE
        .Transition.pResource = g_pRenderTargets(g_frameIndex)
        .Transition.Subresource = D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES
        .Transition.StateBefore = D3D12_RESOURCE_STATE_PRESENT
        .Transition.StateAfter = D3D12_RESOURCE_STATE_RENDER_TARGET
    End With

    g_args3_ResourceBarrier.a2 = 1
    g_args3_ResourceBarrier.a3 = VarPtr(g_rtBarrier)
    CallWindowProcW g_thunk_CmdList_ResourceBarrier, 0, 0, VarPtr(g_args3_ResourceBarrier), 0

    ' ------------------------------------------------------------
    ' Get RTV CPU handle for the current back buffer and bind it as render target
    ' ------------------------------------------------------------
    CallWindowProcW g_thunk_DescHeap_GetCPUHandle, 0, 0, VarPtr(g_args2_GetCPUHandle), 0
    g_rtvHandle.ptr = g_rtvHandle.ptr + CLngPtr(g_frameIndex) * CLngPtr(g_rtvDescriptorSize)

    g_args5_OMSetRenderTargets.a3 = VarPtr(g_rtvHandle)
    CallWindowProcW g_thunk_CmdList_OMSetRenderTargets, 0, 0, VarPtr(g_args5_OMSetRenderTargets), 0

    ' ------------------------------------------------------------
    ' Clear the current render target
    ' ------------------------------------------------------------
    g_args5_ClearRTV.a2 = g_rtvHandle.ptr
    CallWindowProcW g_thunk_CmdList_ClearRenderTargetView, 0, 0, VarPtr(g_args5_ClearRTV), 0

    ' ------------------------------------------------------------
    ' === GRAPHICS PASS (batched) ===
    ' IMPORTANT:
    '   Batch thunk reads args pointer from R9 (lParam) -> pass VarPtr via the 5th argument.
    ' ------------------------------------------------------------
    g_batchGraphicsArgs.gpuHandle_SRV = g_gpuHandle.ptr + g_srvOffset
    g_batchGraphicsArgs.gpuHandle_CBV = g_gpuHandle.ptr + g_cbvOffset

    ' NOTE: Passing args pointer via lParam (5th arg) is required for this batch thunk.
    CallWindowProcW g_thunk_GraphicsDrawBatch, 0, 0, 0, VarPtr(g_batchGraphicsArgs)
    ProfilerMark PROF_GRAPHICS

    ' ------------------------------------------------------------
    ' Barrier: RenderTarget -> Present (current back buffer)
    ' ------------------------------------------------------------
    With g_rtBarrier
        .cType = D3D12_RESOURCE_BARRIER_TYPE_TRANSITION
        .Flags = D3D12_RESOURCE_BARRIER_FLAG_NONE
        .Transition.pResource = g_pRenderTargets(g_frameIndex)
        .Transition.Subresource = D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES
        .Transition.StateBefore = D3D12_RESOURCE_STATE_RENDER_TARGET
        .Transition.StateAfter = D3D12_RESOURCE_STATE_PRESENT
    End With

    g_args3_ResourceBarrier.a2 = 1
    g_args3_ResourceBarrier.a3 = VarPtr(g_rtBarrier)
    CallWindowProcW g_thunk_CmdList_ResourceBarrier, 0, 0, VarPtr(g_args3_ResourceBarrier), 0

    ' ------------------------------------------------------------
    ' Barrier: SRV -> UAV (positions / colors)
    ' ------------------------------------------------------------
    With g_barriers(0)
        .cType = D3D12_RESOURCE_BARRIER_TYPE_TRANSITION
        .Flags = D3D12_RESOURCE_BARRIER_FLAG_NONE
        .Transition.pResource = g_pPositionBuffer
        .Transition.Subresource = D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES
        .Transition.StateBefore = D3D12_RESOURCE_STATE_NON_PIXEL_SHADER_RESOURCE
        .Transition.StateAfter = D3D12_RESOURCE_STATE_UNORDERED_ACCESS
    End With

    With g_barriers(1)
        .cType = D3D12_RESOURCE_BARRIER_TYPE_TRANSITION
        .Flags = D3D12_RESOURCE_BARRIER_FLAG_NONE
        .Transition.pResource = g_pColorBuffer
        .Transition.Subresource = D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES
        .Transition.StateBefore = D3D12_RESOURCE_STATE_NON_PIXEL_SHADER_RESOURCE
        .Transition.StateAfter = D3D12_RESOURCE_STATE_UNORDERED_ACCESS
    End With

    g_args3_ResourceBarrier.a2 = 2
    g_args3_ResourceBarrier.a3 = VarPtr(g_barriers(0))
    CallWindowProcW g_thunk_CmdList_ResourceBarrier, 0, 0, VarPtr(g_args3_ResourceBarrier), 0
    ProfilerMark PROF_BARRIER2

    ' ------------------------------------------------------------
    ' Close, execute, and present
    ' ------------------------------------------------------------
    CallWindowProcW g_thunk_CmdList_Close, 0, 0, VarPtr(g_args1_CmdListClose), 0

    g_args3_ExecuteCommandLists.a3 = VarPtr(g_cmdListPtr)
    CallWindowProcW g_thunk_CmdQueue_ExecuteCommandLists, 0, 0, VarPtr(g_args3_ExecuteCommandLists), 0
    ProfilerMark PROF_EXECUTE

    CallWindowProcW g_thunk_SwapChain_Present, 0, 0, VarPtr(g_args3_Present), 0
    ProfilerMark PROF_PRESENT

    MoveToNextFrame
    ProfilerMark PROF_FRAME_SYNC

    ProfilerEndFrame
    g_frameCount = g_frameCount + 1
End Sub

Private Sub WaitForGpu()
    LogMsg "WaitForGpu: start"
    g_fenceValue = g_fenceValue + 1
    LogMsg "  Signal fence (value=" & g_fenceValue & ")"
    ' Use COM_Call instead of Fast_Signal to avoid using freed thunks
    COM_Call3 g_pCommandQueue, VTBL_CmdQueue_Signal, g_pFence, CLngPtr(g_fenceValue)
    LogMsg "  Check completion..."
    If COM_Call1(g_pFence, VTBL_Fence_GetCompletedValue) < g_fenceValue Then
        LogMsg "  SetEventOnCompletion (waiting...)"
        COM_Call3 g_pFence, VTBL_Fence_SetEventOnCompletion, CLngPtr(g_fenceValue), g_fenceEvent
        WaitForSingleObject g_fenceEvent, INFINITE
    End If
    LogMsg "WaitForGpu: done"
End Sub

Private Sub CleanupD3D12()
    LogMsg "CleanupD3D12: start"
    WaitForGpu

    If g_fenceEvent <> 0 Then
        CloseHandle g_fenceEvent
        g_fenceEvent = 0
    End If

    If g_pConstantBuffer <> 0 Then
        COM_Call3 g_pConstantBuffer, VTBL_Resource_Unmap, 0, 0
        COM_Release g_pConstantBuffer
        g_pConstantBuffer = 0
    End If

    If g_pColorBuffer <> 0 Then COM_Release g_pColorBuffer: g_pColorBuffer = 0
    If g_pPositionBuffer <> 0 Then COM_Release g_pPositionBuffer: g_pPositionBuffer = 0
    If g_pFence <> 0 Then COM_Release g_pFence: g_pFence = 0
    If g_pGraphicsCommandList <> 0 Then COM_Release g_pGraphicsCommandList: g_pGraphicsCommandList = 0
    If g_pGraphicsPipelineState <> 0 Then COM_Release g_pGraphicsPipelineState: g_pGraphicsPipelineState = 0
    If g_pComputePipelineState <> 0 Then COM_Release g_pComputePipelineState: g_pComputePipelineState = 0
    If g_pGraphicsRootSignature <> 0 Then COM_Release g_pGraphicsRootSignature: g_pGraphicsRootSignature = 0
    If g_pComputeRootSignature <> 0 Then COM_Release g_pComputeRootSignature: g_pComputeRootSignature = 0

    Dim j As Long
    For j = 0 To FRAME_COUNT - 1
        If g_pCommandAllocators(j) <> 0 Then
            COM_Release g_pCommandAllocators(j)
            g_pCommandAllocators(j) = 0
        End If
    Next j

    Dim i As Long
    For i = 0 To FRAME_COUNT - 1
        If g_pRenderTargets(i) <> 0 Then
            COM_Release g_pRenderTargets(i)
            g_pRenderTargets(i) = 0
        End If
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
    
    LogMsg "Main: start (V3 OPTIMIZED - Pre-bound Thunks)"
    
    g_shaderPath = ThisWorkbook.Path & "\hello.hlsl"
    LogMsg "Shader path: " & g_shaderPath
    
    If Dir(g_shaderPath) = "" Then MsgBox "Shader file not found: " & g_shaderPath, vbCritical: GoTo FIN
    
    Dim wcex As WNDCLASSEXW, hInstance As LongPtr: hInstance = GetModuleHandleW(0)
    wcex.cbSize = LenB(wcex)
    wcex.style = CS_HREDRAW Or CS_VREDRAW Or CS_OWNDC
    wcex.lpfnWndProc = VBA.CLngPtr(AddressOf WindowProc)
    wcex.hInstance = hInstance
    wcex.hIcon = LoadIconW(0, IDI_APPLICATION)
    wcex.hCursor = LoadCursorW(0, IDC_ARROW)
    wcex.hbrBackground = (COLOR_WINDOW + 1)
    wcex.lpszClassName = StrPtr(CLASS_NAME)
    wcex.hIconSm = LoadIconW(0, IDI_APPLICATION)
    
    If RegisterClassExW(wcex) = 0 Then MsgBox "RegisterClassExW failed.", vbCritical: GoTo FIN
    
    g_hWnd = CreateWindowExW(0, StrPtr(CLASS_NAME), StrPtr(WINDOW_NAME), WS_OVERLAPPEDWINDOW, CW_USEDEFAULT, CW_USEDEFAULT, Width, Height, 0, 0, hInstance, 0)
    If g_hWnd = 0 Then MsgBox "CreateWindowExW failed.", vbCritical: GoTo FIN
    
    ShowWindow g_hWnd, SW_SHOWDEFAULT
    UpdateWindow g_hWnd
    
    If Not InitD3D12(g_hWnd) Then MsgBox "Failed to initialize DirectX 12.", vbCritical: GoTo FIN
    If Not CreateComputeRootSignature() Then MsgBox "Failed to create compute root signature.", vbCritical: GoTo FIN
    If Not CreateGraphicsRootSignature() Then MsgBox "Failed to create graphics root signature.", vbCritical: GoTo FIN
    If Not CreatePipelineStates() Then MsgBox "Failed to create pipeline states.", vbCritical: GoTo FIN
    If Not CreateCommandLists() Then MsgBox "Failed to create command lists.", vbCritical: GoTo FIN
    If Not CreateBuffers() Then MsgBox "Failed to create buffers.", vbCritical: GoTo FIN
    If Not CreateViews() Then MsgBox "Failed to create views.", vbCritical: GoTo FIN
    If Not CreateFence() Then MsgBox "Failed to create fence.", vbCritical: GoTo FIN
    
    ' *** V3: Bind hot path thunks AFTER all D3D12 objects are created ***
    BindHotPathThunks
    
    g_startTime = Timer
    g_frameCount = 0
    
    Randomize Timer
    InitHarmonographParams
    
    ProfilerInit
    ProfilerReset
    
    Dim msg As MSGW, quit As Boolean: quit = False
    Dim frame As Long: frame = 0
    
    LogMsg "Loop: start"
    Do While Not quit
        If PeekMessageW(msg, 0, 0, 0, PM_REMOVE) <> 0 Then
            If msg.message = WM_QUIT Then quit = True Else TranslateMessage msg: DispatchMessageW msg
        Else
            RenderFrame
            frame = frame + 1
            ' *** V3: Increased DoEvents interval (180 -> 300) ***
            If (frame Mod 300) = 0 Then DoEvents
        End If
    Loop
    
FIN:
    ProfilerFlush
    LogMsg "Cleanup: start"
    CleanupD3D12
    FreeThunks
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
