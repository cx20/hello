Attribute VB_Name = "hello"
Option Explicit

' ============================================================
'  Excel VBA (64-bit) + DirectX 12 - Raymarching Rendering
'   - OPTIMIZED VERSION: Thunk caching for better performance
'   - Creates a Win32 window
'   - Creates D3D12 Device, CommandQueue, SwapChain
'   - Creates RootSignature with CBV, PipelineState
'   - Manages GPU synchronization with Fence
'   - Renders raymarching scene using external hello.hlsl
'   - Debug log: C:\TEMP\dx12_raymarching.log
'
'  Based on DirectX 12 VBA triangle sample.
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
Private Const DXGI_FORMAT_R32G32_FLOAT As Long = 16
Private Const DXGI_FORMAT_UNKNOWN As Long = 0

Private Const DXGI_USAGE_RENDER_TARGET_OUTPUT As Long = &H20&
Private Const DXGI_SWAP_EFFECT_FLIP_DISCARD As Long = 4

Private Const D3D12_COMMAND_LIST_TYPE_DIRECT As Long = 0
Private Const D3D12_COMMAND_QUEUE_FLAG_NONE As Long = 0

Private Const D3D12_DESCRIPTOR_HEAP_TYPE_RTV As Long = 2
Private Const D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV As Long = 0
Private Const D3D12_DESCRIPTOR_HEAP_FLAG_NONE As Long = 0
Private Const D3D12_DESCRIPTOR_HEAP_FLAG_SHADER_VISIBLE As Long = 1

Private Const D3D12_HEAP_TYPE_UPLOAD As Long = 2
Private Const D3D12_HEAP_FLAG_NONE As Long = 0
Private Const D3D12_RESOURCE_STATE_GENERIC_READ As Long = &H1& Or &H2& Or &H40& Or &H80& Or &H200& Or &H800&
Private Const D3D12_RESOURCE_STATE_PRESENT As Long = 0
Private Const D3D12_RESOURCE_STATE_RENDER_TARGET As Long = &H4&
Private Const D3D12_RESOURCE_DIMENSION_BUFFER As Long = 1

Private Const D3D12_FENCE_FLAG_NONE As Long = 0

Private Const D3D12_ROOT_SIGNATURE_FLAG_ALLOW_INPUT_ASSEMBLER_INPUT_LAYOUT As Long = &H1&
Private Const D3D_ROOT_SIGNATURE_VERSION_1 As Long = 1

Private Const D3D12_FILL_MODE_SOLID As Long = 3
Private Const D3D12_CULL_MODE_NONE As Long = 1

Private Const D3D12_PRIMITIVE_TOPOLOGY_TYPE_TRIANGLE As Long = 3
Private Const D3D_PRIMITIVE_TOPOLOGY_TRIANGLELIST As Long = 4

Private Const D3D12_INPUT_CLASSIFICATION_PER_VERTEX_DATA As Long = 0

Private Const D3D12_RESOURCE_BARRIER_TYPE_TRANSITION As Long = 0
Private Const D3D12_RESOURCE_BARRIER_FLAG_NONE As Long = 0
Private Const D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES As Long = &HFFFFFFFF

Private Const D3D12_DEFAULT_DEPTH_BIAS As Long = 0
Private Const D3D12_DEFAULT_SLOPE_SCALED_DEPTH_BIAS As Single = 0!
Private Const D3D12_DEFAULT_DEPTH_BIAS_CLAMP As Single = 0!

Private Const D3D12_BLEND_ONE As Long = 2
Private Const D3D12_BLEND_ZERO As Long = 1
Private Const D3D12_BLEND_OP_ADD As Long = 1
Private Const D3D12_LOGIC_OP_NOOP As Long = 5
Private Const D3D12_COLOR_WRITE_ENABLE_ALL As Long = 15

Private Const D3DCOMPILE_ENABLE_STRICTNESS As Long = &H800&

Private Const D3D12_ROOT_PARAMETER_TYPE_DESCRIPTOR_TABLE As Long = 0
Private Const D3D12_DESCRIPTOR_RANGE_TYPE_CBV As Long = 2
Private Const D3D12_SHADER_VISIBILITY_PIXEL As Long = 5
Private Const D3D12_DESCRIPTOR_RANGE_OFFSET_APPEND As Long = &HFFFFFFFF

Private Const FRAME_COUNT As Long = 2
Private Const WIDTH As Long = 800
Private Const HEIGHT As Long = 600

' -----------------------------
' vtable indices (from vtable.txt)
' -----------------------------
' IUnknown
Private Const ONVTBL_IUnknown_QueryInterface As Long = 0
Private Const ONVTBL_IUnknown_AddRef As Long = 1
Private Const ONVTBL_IUnknown_Release As Long = 2

' ID3D12Device
Private Const VTBL_Device_CreateCommandQueue As Long = 8
Private Const VTBL_Device_CreateCommandAllocator As Long = 9
Private Const VTBL_Device_CreateGraphicsPipelineState As Long = 10
Private Const VTBL_Device_CreateCommandList As Long = 12
Private Const VTBL_Device_CreateDescriptorHeap As Long = 14
Private Const VTBL_Device_GetDescriptorHandleIncrementSize As Long = 15
Private Const VTBL_Device_CreateRootSignature As Long = 16
Private Const VTBL_Device_CreateConstantBufferView As Long = 17
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
Private Const VTBL_CmdList_IASetPrimitiveTopology As Long = 20
Private Const VTBL_CmdList_RSSetViewports As Long = 21
Private Const VTBL_CmdList_RSSetScissorRects As Long = 22
Private Const VTBL_CmdList_SetPipelineState As Long = 25
Private Const VTBL_CmdList_ResourceBarrier As Long = 26
Private Const VTBL_CmdList_SetDescriptorHeaps As Long = 28
Private Const VTBL_CmdList_SetGraphicsRootSignature As Long = 30
Private Const VTBL_CmdList_SetGraphicsRootDescriptorTable As Long = 32
Private Const VTBL_CmdList_IASetVertexBuffers As Long = 44
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
Private Const CLASS_NAME As String = "RaymarchingDX12WindowVBA"
Private Const WINDOW_NAME As String = "Raymarching - DirectX 12 (VBA64)"

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
    Count As Long
    Quality As Long
End Type

Private Type DXGI_SWAP_CHAIN_DESC
    BufferDesc As DXGI_MODE_DESC
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

' Root Signature types
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

Private Type D3D12_INPUT_ELEMENT_DESC
    SemanticName As LongPtr
    SemanticIndex As Long
    Format As Long
    InputSlot As Long
    AlignedByteOffset As Long
    InputSlotClass As Long
    InstanceDataStepRate As Long
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

Private Type D3D12_VERTEX_BUFFER_VIEW
    BufferLocation As LongLong
    SizeInBytes As Long
    StrideInBytes As Long
End Type

Private Type D3D12_CONSTANT_BUFFER_VIEW_DESC
    BufferLocation As LongLong
    SizeInBytes As Long
End Type

' Fullscreen quad vertex (position only)
Private Type VERTEX
    x As Single
    y As Single
End Type

' Constant buffer data
Private Type CONSTANT_BUFFER_DATA
    iTime As Single
    iResolutionX As Single
    iResolutionY As Single
    padding As Single
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
Private g_pCbvHeap As LongPtr
Private g_pCommandAllocator As LongPtr
Private g_pCommandList As LongPtr
Private g_pRootSignature As LongPtr
Private g_pPipelineState As LongPtr
Private g_pFence As LongPtr
Private g_fenceEvent As LongPtr
Private g_fenceValue As LongLong
Private g_frameIndex As Long
Private g_rtvDescriptorSize As Long
Private g_cbvDescriptorSize As Long
Private g_pRenderTargets(0 To FRAME_COUNT - 1) As LongPtr
Private g_pVertexBuffer As LongPtr
Private g_pConstantBuffer As LongPtr
Private g_constantBufferDataBegin As LongPtr
Private g_vertexBufferView As D3D12_VERTEX_BUFFER_VIEW

' Semantic name strings (must persist)
Private g_semanticPosition() As Byte

' Timer
Private g_startTime As Double

' Logger
Private g_log As LongPtr
Private Const GENERIC_WRITE As Long = &H40000000
Private Const GENERIC_READ As Long = &H80000000
Private Const FILE_SHARE_READ As Long = &H1
Private Const FILE_SHARE_WRITE As Long = &H2
Private Const CREATE_ALWAYS As Long = 2
Private Const OPEN_EXISTING As Long = 3
Private Const FILE_ATTRIBUTE_NORMAL As Long = &H80
Private Const INVALID_HANDLE_VALUE As LongPtr = -1

' Thunk memory - CACHED (allocated once, reused)
Private Const MEM_COMMIT As Long = &H1000&
Private Const MEM_RESERVE As Long = &H2000&
Private Const MEM_RELEASE As Long = &H8000&
Private Const PAGE_EXECUTE_READWRITE As Long = &H40&

' Cached thunk pointers
Private g_thunk1 As LongPtr
Private g_thunk2 As LongPtr
Private g_thunk3 As LongPtr
Private g_thunk4 As LongPtr
Private g_thunk5 As LongPtr
Private g_thunk6 As LongPtr
Private g_thunk7 As LongPtr
Private g_thunk8 As LongPtr
Private g_thunk9 As LongPtr
Private g_thunkRetStruct As LongPtr
Private g_thunkRetStructGPU As LongPtr

' Target address offsets within each thunk
Private Const THUNK1_TARGET_OFFSET As Long = 12
Private Const THUNK2_TARGET_OFFSET As Long = 16
Private Const THUNK3_TARGET_OFFSET As Long = 20
Private Const THUNK4_TARGET_OFFSET As Long = 24
Private Const THUNK5_TARGET_OFFSET As Long = 33
Private Const THUNK6_TARGET_OFFSET As Long = 42
Private Const THUNK7_TARGET_OFFSET As Long = 51
Private Const THUNK8_TARGET_OFFSET As Long = 60
Private Const THUNK9_TARGET_OFFSET As Long = 69
Private Const THUNK_RETSTRUCT_TARGET_OFFSET As Long = 16
Private Const THUNK_RETSTRUCT_GPU_TARGET_OFFSET As Long = 16

' Thunks initialized flag
Private g_thunksInitialized As Boolean

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

    Private Declare PtrSafe Function GetClientRect Lib "user32" (ByVal hWnd As LongPtr, ByRef lpRect As RECT) As Long

    Private Declare PtrSafe Sub Sleep Lib "kernel32" (ByVal dwMilliseconds As Long)
    Private Declare PtrSafe Function GetLastError Lib "kernel32" () As Long
    Private Declare PtrSafe Function GetTickCount Lib "kernel32" () As Long

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

    ' File operations
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

    Private Declare PtrSafe Function ReadFile Lib "kernel32" ( _
        ByVal hFile As LongPtr, _
        ByRef lpBuffer As Any, _
        ByVal nNumberOfBytesToRead As Long, _
        ByRef lpNumberOfBytesRead As Long, _
        ByVal lpOverlapped As LongPtr) As Long

    Private Declare PtrSafe Function GetFileSize Lib "kernel32" (ByVal hFile As LongPtr, ByRef lpFileSizeHigh As Long) As Long

    Private Declare PtrSafe Function FlushFileBuffers Lib "kernel32" (ByVal hFile As LongPtr) As Long

    Private Declare PtrSafe Function lstrlenA Lib "kernel32" (ByVal lpString As LongPtr) As Long
    Private Declare PtrSafe Sub RtlMoveMemory Lib "kernel32" (ByRef Destination As Any, ByVal Source As LongPtr, ByVal Length As Long)
    Private Declare PtrSafe Sub RtlMoveMemoryFromPtr Lib "kernel32" Alias "RtlMoveMemory" (ByVal Destination As LongPtr, ByRef Source As Any, ByVal Length As Long)
    Private Declare PtrSafe Sub CopyMemory Lib "kernel32" Alias "RtlMoveMemory" (ByVal Destination As LongPtr, ByVal Source As LongPtr, ByVal Length As LongPtr)

    Private Declare PtrSafe Function VirtualAlloc Lib "kernel32" (ByVal lpAddress As LongPtr, ByVal dwSize As LongPtr, ByVal flAllocationType As Long, ByVal flProtect As Long) As LongPtr
    Private Declare PtrSafe Function VirtualFree Lib "kernel32" (ByVal lpAddress As LongPtr, ByVal dwSize As LongPtr, ByVal dwFreeType As Long) As Long
    
    ' Performance counter
    Private Declare PtrSafe Function QueryPerformanceCounter Lib "kernel32" (ByRef lpPerformanceCount As Currency) As Long
    Private Declare PtrSafe Function QueryPerformanceFrequency Lib "kernel32" (ByRef lpFrequency As Currency) As Long
#End If

' ============================================================
' Logger
' ============================================================
Private Sub LogOpen()
    On Error Resume Next
    CreateDirectoryW StrPtr("C:\TEMP"), 0
    g_log = CreateFileW(StrPtr("C:\TEMP\dx12_raymarching.log"), GENERIC_WRITE, FILE_SHARE_READ Or FILE_SHARE_WRITE, 0, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, 0)
    If g_log = 0 Or g_log = -1 Then g_log = 0
    LogMsg "==== DX12 RAYMARCHING LOG START (OPTIMIZED) ===="
End Sub

Private Sub LogClose()
    On Error Resume Next
    If g_log <> 0 Then
        LogMsg "==== DX12 LOG END ===="
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

Private Function GetTime() As Double
    Dim counter As Currency, freq As Currency
    QueryPerformanceCounter counter
    QueryPerformanceFrequency freq
    GetTime = CDbl(counter) / CDbl(freq)
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
' CACHED Thunk builders - Build once, reuse many times
' Each thunk has a placeholder for the target address
' ============================================================
Private Function BuildThunk1Cached() As LongPtr
    ' Thunk for 1 argument COM call
    ' Target address at offset 12
    Dim code(0 To 39) As Byte
    Dim i As Long: i = 0
    
    ' sub rsp, 0x28
    code(i) = &H48: i = i + 1: code(i) = &H83: i = i + 1: code(i) = &HEC: i = i + 1: code(i) = &H28: i = i + 1
    ' mov r10, r8 (args pointer)
    code(i) = &H4D: i = i + 1: code(i) = &H89: i = i + 1: code(i) = &HC2: i = i + 1
    ' mov rcx, [r10] (this pointer)
    code(i) = &H49: i = i + 1: code(i) = &H8B: i = i + 1: code(i) = &HA: i = i + 1
    ' mov rax, target (placeholder - 8 bytes at offset 12)
    code(i) = &H48: i = i + 1: code(i) = &HB8: i = i + 1
    ' Target address placeholder (8 bytes of zeros)
    Dim j As Long
    For j = 0 To 7: code(i + j) = 0: Next j
    i = i + 8
    ' call rax
    code(i) = &HFF: i = i + 1: code(i) = &HD0: i = i + 1
    ' add rsp, 0x28
    code(i) = &H48: i = i + 1: code(i) = &H83: i = i + 1: code(i) = &HC4: i = i + 1: code(i) = &H28: i = i + 1
    ' ret
    code(i) = &HC3
    
    Dim mem As LongPtr
    mem = VirtualAlloc(0, 64, MEM_COMMIT Or MEM_RESERVE, PAGE_EXECUTE_READWRITE)
    If mem = 0 Then Err.Raise vbObjectError + 8996, , "VirtualAlloc failed"
    CopyMemory mem, VarPtr(code(0)), CLngPtr(i + 1)
    BuildThunk1Cached = mem
End Function

Private Function BuildThunk2Cached() As LongPtr
    Dim code(0 To 47) As Byte
    Dim i As Long: i = 0
    
    code(i) = &H48: i = i + 1: code(i) = &H83: i = i + 1: code(i) = &HEC: i = i + 1: code(i) = &H28: i = i + 1
    code(i) = &H4D: i = i + 1: code(i) = &H89: i = i + 1: code(i) = &HC2: i = i + 1
    code(i) = &H49: i = i + 1: code(i) = &H8B: i = i + 1: code(i) = &HA: i = i + 1
    code(i) = &H49: i = i + 1: code(i) = &H8B: i = i + 1: code(i) = &H52: i = i + 1: code(i) = &H8: i = i + 1
    code(i) = &H48: i = i + 1: code(i) = &HB8: i = i + 1
    Dim j As Long: For j = 0 To 7: code(i + j) = 0: Next j: i = i + 8
    code(i) = &HFF: i = i + 1: code(i) = &HD0: i = i + 1
    code(i) = &H48: i = i + 1: code(i) = &H83: i = i + 1: code(i) = &HC4: i = i + 1: code(i) = &H28: i = i + 1
    code(i) = &HC3
    
    Dim mem As LongPtr
    mem = VirtualAlloc(0, 64, MEM_COMMIT Or MEM_RESERVE, PAGE_EXECUTE_READWRITE)
    If mem = 0 Then Err.Raise vbObjectError + 8997, , "VirtualAlloc failed"
    CopyMemory mem, VarPtr(code(0)), CLngPtr(i + 1)
    BuildThunk2Cached = mem
End Function

Private Function BuildThunk3Cached() As LongPtr
    Dim code(0 To 55) As Byte
    Dim i As Long: i = 0
    
    code(i) = &H48: i = i + 1: code(i) = &H83: i = i + 1: code(i) = &HEC: i = i + 1: code(i) = &H28: i = i + 1
    code(i) = &H4D: i = i + 1: code(i) = &H89: i = i + 1: code(i) = &HC2: i = i + 1
    code(i) = &H49: i = i + 1: code(i) = &H8B: i = i + 1: code(i) = &HA: i = i + 1
    code(i) = &H49: i = i + 1: code(i) = &H8B: i = i + 1: code(i) = &H52: i = i + 1: code(i) = &H8: i = i + 1
    code(i) = &H4D: i = i + 1: code(i) = &H8B: i = i + 1: code(i) = &H42: i = i + 1: code(i) = &H10: i = i + 1
    code(i) = &H48: i = i + 1: code(i) = &HB8: i = i + 1
    Dim j As Long: For j = 0 To 7: code(i + j) = 0: Next j: i = i + 8
    code(i) = &HFF: i = i + 1: code(i) = &HD0: i = i + 1
    code(i) = &H48: i = i + 1: code(i) = &H83: i = i + 1: code(i) = &HC4: i = i + 1: code(i) = &H28: i = i + 1
    code(i) = &HC3
    
    Dim mem As LongPtr
    mem = VirtualAlloc(0, 64, MEM_COMMIT Or MEM_RESERVE, PAGE_EXECUTE_READWRITE)
    If mem = 0 Then Err.Raise vbObjectError + 8998, , "VirtualAlloc failed"
    CopyMemory mem, VarPtr(code(0)), CLngPtr(i + 1)
    BuildThunk3Cached = mem
End Function

Private Function BuildThunk4Cached() As LongPtr
    Dim code(0 To 63) As Byte
    Dim i As Long: i = 0
    
    code(i) = &H48: i = i + 1: code(i) = &H83: i = i + 1: code(i) = &HEC: i = i + 1: code(i) = &H28: i = i + 1
    code(i) = &H4D: i = i + 1: code(i) = &H89: i = i + 1: code(i) = &HC2: i = i + 1
    code(i) = &H49: i = i + 1: code(i) = &H8B: i = i + 1: code(i) = &HA: i = i + 1
    code(i) = &H49: i = i + 1: code(i) = &H8B: i = i + 1: code(i) = &H52: i = i + 1: code(i) = &H8: i = i + 1
    code(i) = &H4D: i = i + 1: code(i) = &H8B: i = i + 1: code(i) = &H42: i = i + 1: code(i) = &H10: i = i + 1
    code(i) = &H4D: i = i + 1: code(i) = &H8B: i = i + 1: code(i) = &H4A: i = i + 1: code(i) = &H18: i = i + 1
    code(i) = &H48: i = i + 1: code(i) = &HB8: i = i + 1
    Dim j As Long: For j = 0 To 7: code(i + j) = 0: Next j: i = i + 8
    code(i) = &HFF: i = i + 1: code(i) = &HD0: i = i + 1
    code(i) = &H48: i = i + 1: code(i) = &H83: i = i + 1: code(i) = &HC4: i = i + 1: code(i) = &H28: i = i + 1
    code(i) = &HC3
    
    Dim mem As LongPtr
    mem = VirtualAlloc(0, 128, MEM_COMMIT Or MEM_RESERVE, PAGE_EXECUTE_READWRITE)
    If mem = 0 Then Err.Raise vbObjectError + 8999, , "VirtualAlloc failed"
    CopyMemory mem, VarPtr(code(0)), CLngPtr(i + 1)
    BuildThunk4Cached = mem
End Function

Private Function BuildThunk5Cached() As LongPtr
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
    Dim j As Long: For j = 0 To 7: code(i + j) = 0: Next j: i = i + 8
    code(i) = &HFF: i = i + 1: code(i) = &HD0: i = i + 1
    code(i) = &H48: i = i + 1: code(i) = &H83: i = i + 1: code(i) = &HC4: i = i + 1: code(i) = &H38: i = i + 1
    code(i) = &HC3
    
    Dim mem As LongPtr
    mem = VirtualAlloc(0, 128, MEM_COMMIT Or MEM_RESERVE, PAGE_EXECUTE_READWRITE)
    If mem = 0 Then Err.Raise vbObjectError + 9000, , "VirtualAlloc failed"
    CopyMemory mem, VarPtr(code(0)), CLngPtr(i + 1)
    BuildThunk5Cached = mem
End Function

Private Function BuildThunk6Cached() As LongPtr
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
    Dim j As Long: For j = 0 To 7: code(i + j) = 0: Next j: i = i + 8
    code(i) = &HFF: i = i + 1: code(i) = &HD0: i = i + 1
    code(i) = &H48: i = i + 1: code(i) = &H83: i = i + 1: code(i) = &HC4: i = i + 1: code(i) = &H48: i = i + 1
    code(i) = &HC3
    
    Dim mem As LongPtr
    mem = VirtualAlloc(0, 128, MEM_COMMIT Or MEM_RESERVE, PAGE_EXECUTE_READWRITE)
    If mem = 0 Then Err.Raise vbObjectError + 9001, , "VirtualAlloc failed"
    CopyMemory mem, VarPtr(code(0)), CLngPtr(i + 1)
    BuildThunk6Cached = mem
End Function

Private Function BuildThunk7Cached() As LongPtr
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
    Dim j As Long: For j = 0 To 7: code(i + j) = 0: Next j: i = i + 8
    code(i) = &HFF: i = i + 1: code(i) = &HD0: i = i + 1
    code(i) = &H48: i = i + 1: code(i) = &H83: i = i + 1: code(i) = &HC4: i = i + 1: code(i) = &H58: i = i + 1
    code(i) = &HC3
    
    Dim mem As LongPtr
    mem = VirtualAlloc(0, 128, MEM_COMMIT Or MEM_RESERVE, PAGE_EXECUTE_READWRITE)
    If mem = 0 Then Err.Raise vbObjectError + 9002, , "VirtualAlloc failed"
    CopyMemory mem, VarPtr(code(0)), CLngPtr(i + 1)
    BuildThunk7Cached = mem
End Function

Private Function BuildThunk8Cached() As LongPtr
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
    Dim j As Long: For j = 0 To 7: code(i + j) = 0: Next j: i = i + 8
    code(i) = &HFF: i = i + 1: code(i) = &HD0: i = i + 1
    code(i) = &H48: i = i + 1: code(i) = &H83: i = i + 1: code(i) = &HC4: i = i + 1: code(i) = &H68: i = i + 1
    code(i) = &HC3
    
    Dim mem As LongPtr
    mem = VirtualAlloc(0, 160, MEM_COMMIT Or MEM_RESERVE, PAGE_EXECUTE_READWRITE)
    If mem = 0 Then Err.Raise vbObjectError + 9003, , "VirtualAlloc failed"
    CopyMemory mem, VarPtr(code(0)), CLngPtr(i + 1)
    BuildThunk8Cached = mem
End Function

Private Function BuildThunk9Cached() As LongPtr
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
    Dim j As Long: For j = 0 To 7: code(i + j) = 0: Next j: i = i + 8
    code(i) = &HFF: i = i + 1: code(i) = &HD0: i = i + 1
    code(i) = &H48: i = i + 1: code(i) = &H83: i = i + 1: code(i) = &HC4: i = i + 1: code(i) = &H68: i = i + 1
    code(i) = &HC3
    
    Dim mem As LongPtr
    mem = VirtualAlloc(0, 160, MEM_COMMIT Or MEM_RESERVE, PAGE_EXECUTE_READWRITE)
    If mem = 0 Then Err.Raise vbObjectError + 9004, , "VirtualAlloc failed"
    CopyMemory mem, VarPtr(code(0)), CLngPtr(i + 1)
    BuildThunk9Cached = mem
End Function

Private Function BuildThunkRetStructCached() As LongPtr
    Dim code(0 To 47) As Byte
    Dim i As Long: i = 0
    
    code(i) = &H48: i = i + 1: code(i) = &H83: i = i + 1: code(i) = &HEC: i = i + 1: code(i) = &H28: i = i + 1
    code(i) = &H4D: i = i + 1: code(i) = &H89: i = i + 1: code(i) = &HC2: i = i + 1
    code(i) = &H49: i = i + 1: code(i) = &H8B: i = i + 1: code(i) = &HA: i = i + 1
    code(i) = &H49: i = i + 1: code(i) = &H8B: i = i + 1: code(i) = &H52: i = i + 1: code(i) = &H8: i = i + 1
    code(i) = &H48: i = i + 1: code(i) = &HB8: i = i + 1
    Dim j As Long: For j = 0 To 7: code(i + j) = 0: Next j: i = i + 8
    code(i) = &HFF: i = i + 1: code(i) = &HD0: i = i + 1
    code(i) = &H48: i = i + 1: code(i) = &H83: i = i + 1: code(i) = &HC4: i = i + 1: code(i) = &H28: i = i + 1
    code(i) = &HC3
    
    Dim mem As LongPtr
    mem = VirtualAlloc(0, 64, MEM_COMMIT Or MEM_RESERVE, PAGE_EXECUTE_READWRITE)
    If mem = 0 Then Err.Raise vbObjectError + 9005, , "VirtualAlloc failed"
    CopyMemory mem, VarPtr(code(0)), CLngPtr(i + 1)
    BuildThunkRetStructCached = mem
End Function

' ============================================================
' Initialize all cached thunks (call once at startup)
' ============================================================
Private Sub InitThunks()
    If g_thunksInitialized Then Exit Sub
    
    LogMsg "InitThunks: Building cached thunks..."
    
    g_thunk1 = BuildThunk1Cached()
    g_thunk2 = BuildThunk2Cached()
    g_thunk3 = BuildThunk3Cached()
    g_thunk4 = BuildThunk4Cached()
    g_thunk5 = BuildThunk5Cached()
    g_thunk6 = BuildThunk6Cached()
    g_thunk7 = BuildThunk7Cached()
    g_thunk8 = BuildThunk8Cached()
    g_thunk9 = BuildThunk9Cached()
    g_thunkRetStruct = BuildThunkRetStructCached()
    g_thunkRetStructGPU = BuildThunkRetStructCached()
    
    g_thunksInitialized = True
    LogMsg "InitThunks: All thunks cached successfully"
End Sub

' ============================================================
' Free all cached thunks (call once at cleanup)
' ============================================================
Private Sub FreeThunks()
    On Error Resume Next
    
    If g_thunk1 <> 0 Then VirtualFree g_thunk1, 0, MEM_RELEASE: g_thunk1 = 0
    If g_thunk2 <> 0 Then VirtualFree g_thunk2, 0, MEM_RELEASE: g_thunk2 = 0
    If g_thunk3 <> 0 Then VirtualFree g_thunk3, 0, MEM_RELEASE: g_thunk3 = 0
    If g_thunk4 <> 0 Then VirtualFree g_thunk4, 0, MEM_RELEASE: g_thunk4 = 0
    If g_thunk5 <> 0 Then VirtualFree g_thunk5, 0, MEM_RELEASE: g_thunk5 = 0
    If g_thunk6 <> 0 Then VirtualFree g_thunk6, 0, MEM_RELEASE: g_thunk6 = 0
    If g_thunk7 <> 0 Then VirtualFree g_thunk7, 0, MEM_RELEASE: g_thunk7 = 0
    If g_thunk8 <> 0 Then VirtualFree g_thunk8, 0, MEM_RELEASE: g_thunk8 = 0
    If g_thunk9 <> 0 Then VirtualFree g_thunk9, 0, MEM_RELEASE: g_thunk9 = 0
    If g_thunkRetStruct <> 0 Then VirtualFree g_thunkRetStruct, 0, MEM_RELEASE: g_thunkRetStruct = 0
    If g_thunkRetStructGPU <> 0 Then VirtualFree g_thunkRetStructGPU, 0, MEM_RELEASE: g_thunkRetStructGPU = 0
    
    g_thunksInitialized = False
End Sub

' ============================================================
' Update target address in cached thunk (fast - just 8 bytes write)
' ============================================================
Private Sub SetThunkTarget(ByVal pThunk As LongPtr, ByVal offset As Long, ByVal target As LongPtr)
    CopyMemory pThunk + CLngPtr(offset), VarPtr(target), 8
End Sub

' ============================================================
' COM Call helpers - OPTIMIZED (no VirtualAlloc/Free per call)
' ============================================================
Private Function COM_Call1(ByVal pObj As LongPtr, ByVal vtIndex As Long) As LongPtr
    Dim methodAddr As LongPtr: methodAddr = GetVTableMethod(pObj, vtIndex)
    SetThunkTarget g_thunk1, THUNK1_TARGET_OFFSET, methodAddr
    Dim args As ThunkArgs1: args.a1 = pObj
    COM_Call1 = CallWindowProcW(g_thunk1, 0, 0, VarPtr(args), 0)
End Function

Private Function COM_Call2(ByVal pObj As LongPtr, ByVal vtIndex As Long, ByVal a2 As LongPtr) As LongPtr
    Dim methodAddr As LongPtr: methodAddr = GetVTableMethod(pObj, vtIndex)
    SetThunkTarget g_thunk2, THUNK2_TARGET_OFFSET, methodAddr
    Dim args As ThunkArgs2: args.a1 = pObj: args.a2 = a2
    COM_Call2 = CallWindowProcW(g_thunk2, 0, 0, VarPtr(args), 0)
End Function

Private Function COM_Call3(ByVal pObj As LongPtr, ByVal vtIndex As Long, ByVal a2 As LongPtr, ByVal a3 As LongPtr) As LongPtr
    Dim methodAddr As LongPtr: methodAddr = GetVTableMethod(pObj, vtIndex)
    SetThunkTarget g_thunk3, THUNK3_TARGET_OFFSET, methodAddr
    Dim args As ThunkArgs3: args.a1 = pObj: args.a2 = a2: args.a3 = a3
    COM_Call3 = CallWindowProcW(g_thunk3, 0, 0, VarPtr(args), 0)
End Function

Private Function COM_Call4(ByVal pObj As LongPtr, ByVal vtIndex As Long, ByVal a2 As LongPtr, ByVal a3 As LongPtr, ByVal a4 As LongPtr) As LongPtr
    Dim methodAddr As LongPtr: methodAddr = GetVTableMethod(pObj, vtIndex)
    SetThunkTarget g_thunk4, THUNK4_TARGET_OFFSET, methodAddr
    Dim args As ThunkArgs4: args.a1 = pObj: args.a2 = a2: args.a3 = a3: args.a4 = a4
    COM_Call4 = CallWindowProcW(g_thunk4, 0, 0, VarPtr(args), 0)
End Function

Private Function COM_Call5(ByVal pObj As LongPtr, ByVal vtIndex As Long, ByVal a2 As LongPtr, ByVal a3 As LongPtr, ByVal a4 As LongPtr, ByVal a5 As LongPtr) As LongPtr
    Dim methodAddr As LongPtr: methodAddr = GetVTableMethod(pObj, vtIndex)
    SetThunkTarget g_thunk5, THUNK5_TARGET_OFFSET, methodAddr
    Dim args As ThunkArgs5: args.a1 = pObj: args.a2 = a2: args.a3 = a3: args.a4 = a4: args.a5 = a5
    COM_Call5 = CallWindowProcW(g_thunk5, 0, 0, VarPtr(args), 0)
End Function

Private Function COM_Call6(ByVal pObj As LongPtr, ByVal vtIndex As Long, ByVal a2 As LongPtr, ByVal a3 As LongPtr, ByVal a4 As LongPtr, ByVal a5 As LongPtr, ByVal a6 As LongPtr) As LongPtr
    Dim methodAddr As LongPtr: methodAddr = GetVTableMethod(pObj, vtIndex)
    SetThunkTarget g_thunk6, THUNK6_TARGET_OFFSET, methodAddr
    Dim args As ThunkArgs6: args.a1 = pObj: args.a2 = a2: args.a3 = a3: args.a4 = a4: args.a5 = a5: args.a6 = a6
    COM_Call6 = CallWindowProcW(g_thunk6, 0, 0, VarPtr(args), 0)
End Function

Private Function COM_Call7(ByVal pObj As LongPtr, ByVal vtIndex As Long, ByVal a2 As LongPtr, ByVal a3 As LongPtr, ByVal a4 As LongPtr, ByVal a5 As LongPtr, ByVal a6 As LongPtr, ByVal a7 As LongPtr) As LongPtr
    Dim methodAddr As LongPtr: methodAddr = GetVTableMethod(pObj, vtIndex)
    SetThunkTarget g_thunk7, THUNK7_TARGET_OFFSET, methodAddr
    Dim args As ThunkArgs7: args.a1 = pObj: args.a2 = a2: args.a3 = a3: args.a4 = a4: args.a5 = a5: args.a6 = a6: args.a7 = a7
    COM_Call7 = CallWindowProcW(g_thunk7, 0, 0, VarPtr(args), 0)
End Function

Private Sub COM_Release(ByVal pObj As LongPtr)
    If pObj <> 0 Then COM_Call1 pObj, ONVTBL_IUnknown_Release
End Sub

Private Sub COM_GetCPUDescriptorHandle(ByVal pHeap As LongPtr, ByRef outHandle As D3D12_CPU_DESCRIPTOR_HANDLE)
    Dim methodAddr As LongPtr: methodAddr = GetVTableMethod(pHeap, VTBL_DescHeap_GetCPUDescriptorHandleForHeapStart)
    SetThunkTarget g_thunkRetStruct, THUNK_RETSTRUCT_TARGET_OFFSET, methodAddr
    Dim args As ThunkArgs2: args.a1 = pHeap: args.a2 = VarPtr(outHandle)
    CallWindowProcW g_thunkRetStruct, 0, 0, VarPtr(args), 0
End Sub

Private Sub COM_GetGPUDescriptorHandle(ByVal pHeap As LongPtr, ByRef outHandle As D3D12_GPU_DESCRIPTOR_HANDLE)
    Dim methodAddr As LongPtr: methodAddr = GetVTableMethod(pHeap, VTBL_DescHeap_GetGPUDescriptorHandleForHeapStart)
    SetThunkTarget g_thunkRetStructGPU, THUNK_RETSTRUCT_GPU_TARGET_OFFSET, methodAddr
    Dim args As ThunkArgs2: args.a1 = pHeap: args.a2 = VarPtr(outHandle)
    CallWindowProcW g_thunkRetStructGPU, 0, 0, VarPtr(args), 0
End Sub

' ============================================================
' Safe HRESULT conversion
' ============================================================
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
' Read shader file
' ============================================================
Private Function ReadShaderFile(ByVal filePath As String) As String
    Dim hFile As LongPtr
    hFile = CreateFileW(StrPtr(filePath), GENERIC_READ, FILE_SHARE_READ, 0, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, 0)
    If hFile = INVALID_HANDLE_VALUE Then
        LogMsg "Failed to open shader file: " & filePath
        ReadShaderFile = ""
        Exit Function
    End If
    
    Dim fileSize As Long
    fileSize = GetFileSize(hFile, 0)
    If fileSize <= 0 Then
        CloseHandle hFile
        ReadShaderFile = ""
        Exit Function
    End If
    
    Dim buffer() As Byte
    ReDim buffer(0 To fileSize - 1)
    Dim bytesRead As Long
    ReadFile hFile, buffer(0), fileSize, bytesRead, 0
    CloseHandle hFile
    
    ReadShaderFile = StrConv(buffer, vbUnicode)
    LogMsg "Read shader file: " & fileSize & " bytes"
End Function

' ============================================================
' Compile shader using D3DCompileFromFile
' ============================================================
Private Function CompileShaderFromFile(ByVal filePath As String, ByVal entryPoint As String, ByVal profile As String) As LongPtr
    LogMsg "CompileShaderFromFile: " & filePath & " / " & entryPoint & " / " & profile
    
    Dim hCompiler As LongPtr
    hCompiler = LoadLibraryW(StrPtr("d3dcompiler_47.dll"))
    If hCompiler = 0 Then
        LogMsg "Failed to load d3dcompiler_47.dll"
        Err.Raise vbObjectError + 8100, , "Failed to load d3dcompiler_47.dll"
    End If
    
    ' Get D3DCompileFromFile function
    Dim procNameBytes() As Byte
    procNameBytes = AnsiZBytes("D3DCompileFromFile")
    Dim pD3DCompileFromFile As LongPtr
    pD3DCompileFromFile = GetProcAddress(hCompiler, VarPtr(procNameBytes(0)))
    If pD3DCompileFromFile = 0 Then
        FreeLibrary hCompiler
        Err.Raise vbObjectError + 8101, , "D3DCompileFromFile not found"
    End If
    
    ' Use cached thunk9
    SetThunkTarget g_thunk9, THUNK9_TARGET_OFFSET, pD3DCompileFromFile
    
    Dim entryBytes() As Byte: entryBytes = AnsiZBytes(entryPoint)
    Dim profileBytes() As Byte: profileBytes = AnsiZBytes(profile)
    
    Dim pBlob As LongPtr: pBlob = 0
    Dim pErrorBlob As LongPtr: pErrorBlob = 0
    
    ' D3DCompileFromFile(pFileName, pDefines, pInclude, pEntrypoint, pTarget, Flags1, Flags2, ppCode, ppErrorMsgs)
    Dim args9 As ThunkArgs9
    args9.a1 = StrPtr(filePath)
    args9.a2 = 0  ' pDefines
    args9.a3 = 0  ' pInclude
    args9.a4 = VarPtr(entryBytes(0))
    args9.a5 = VarPtr(profileBytes(0))
    args9.a6 = 0  ' Flags1
    args9.a7 = 0  ' Flags2
    args9.a8 = VarPtr(pBlob)
    args9.a9 = VarPtr(pErrorBlob)
    
    Dim hr As Long
    hr = ToHResult(CallWindowProcW(g_thunk9, 0, 0, VarPtr(args9), 0))
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
    If hr < 0 Or pFactory = 0 Then InitD3D12 = False: Exit Function
    
    ' Create D3D12 Device
    Dim deviceIID As GUID: deviceIID = IID_ID3D12Device()
    hr = D3D12CreateDevice(0, D3D_FEATURE_LEVEL_12_0, deviceIID, g_pDevice)
    LogMsg "D3D12CreateDevice returned: " & Hex$(hr)
    If hr < 0 Or g_pDevice = 0 Then COM_Release pFactory: InitD3D12 = False: Exit Function
    
    ' Create Command Queue
    Dim queueDesc As D3D12_COMMAND_QUEUE_DESC
    queueDesc.cType = D3D12_COMMAND_LIST_TYPE_DIRECT
    Dim queueIID As GUID: queueIID = IID_ID3D12CommandQueue()
    hr = ToHResult(COM_Call4(g_pDevice, VTBL_Device_CreateCommandQueue, VarPtr(queueDesc), VarPtr(queueIID), VarPtr(g_pCommandQueue)))
    LogMsg "CreateCommandQueue returned: " & Hex$(hr)
    If hr < 0 Or g_pCommandQueue = 0 Then COM_Release pFactory: InitD3D12 = False: Exit Function
    
    ' Create Swap Chain
    Dim swapChainDesc As DXGI_SWAP_CHAIN_DESC
    swapChainDesc.BufferDesc.Width = WIDTH
    swapChainDesc.BufferDesc.Height = HEIGHT
    swapChainDesc.BufferDesc.Format = DXGI_FORMAT_R8G8B8A8_UNORM
    swapChainDesc.SampleDesc.Count = 1
    swapChainDesc.BufferUsage = DXGI_USAGE_RENDER_TARGET_OUTPUT
    swapChainDesc.BufferCount = FRAME_COUNT
    swapChainDesc.OutputWindow = hWnd
    swapChainDesc.Windowed = 1
    swapChainDesc.SwapEffect = DXGI_SWAP_EFFECT_FLIP_DISCARD
    
    hr = ToHResult(COM_Call4(pFactory, VTBL_Factory_CreateSwapChain, g_pCommandQueue, VarPtr(swapChainDesc), VarPtr(g_pSwapChain)))
    LogMsg "CreateSwapChain returned: " & Hex$(hr)
    If hr < 0 Or g_pSwapChain = 0 Then COM_Release pFactory: InitD3D12 = False: Exit Function
    
    ' Query IDXGISwapChain3
    Dim swapChain3IID As GUID: swapChain3IID = IID_IDXGISwapChain3()
    hr = ToHResult(COM_Call3(g_pSwapChain, ONVTBL_IUnknown_QueryInterface, VarPtr(swapChain3IID), VarPtr(g_pSwapChain3)))
    If hr < 0 Or g_pSwapChain3 = 0 Then COM_Release pFactory: InitD3D12 = False: Exit Function
    
    g_frameIndex = CLng(COM_Call1(g_pSwapChain3, VTBL_SwapChain3_GetCurrentBackBufferIndex))
    
    ' Create RTV Descriptor Heap
    Dim rtvHeapDesc As D3D12_DESCRIPTOR_HEAP_DESC
    rtvHeapDesc.cType = D3D12_DESCRIPTOR_HEAP_TYPE_RTV
    rtvHeapDesc.NumDescriptors = FRAME_COUNT
    rtvHeapDesc.Flags = D3D12_DESCRIPTOR_HEAP_FLAG_NONE
    
    Dim heapIID As GUID: heapIID = IID_ID3D12DescriptorHeap()
    hr = ToHResult(COM_Call4(g_pDevice, VTBL_Device_CreateDescriptorHeap, VarPtr(rtvHeapDesc), VarPtr(heapIID), VarPtr(g_pRtvHeap)))
    LogMsg "CreateRtvHeap returned: " & Hex$(hr)
    If hr < 0 Or g_pRtvHeap = 0 Then COM_Release pFactory: InitD3D12 = False: Exit Function
    
    g_rtvDescriptorSize = CLng(COM_Call2(g_pDevice, VTBL_Device_GetDescriptorHandleIncrementSize, D3D12_DESCRIPTOR_HEAP_TYPE_RTV))
    
    ' Create CBV Descriptor Heap (shader visible)
    Dim cbvHeapDesc As D3D12_DESCRIPTOR_HEAP_DESC
    cbvHeapDesc.cType = D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV
    cbvHeapDesc.NumDescriptors = 1
    cbvHeapDesc.Flags = D3D12_DESCRIPTOR_HEAP_FLAG_SHADER_VISIBLE
    
    hr = ToHResult(COM_Call4(g_pDevice, VTBL_Device_CreateDescriptorHeap, VarPtr(cbvHeapDesc), VarPtr(heapIID), VarPtr(g_pCbvHeap)))
    LogMsg "CreateCbvHeap returned: " & Hex$(hr)
    If hr < 0 Or g_pCbvHeap = 0 Then COM_Release pFactory: InitD3D12 = False: Exit Function
    
    g_cbvDescriptorSize = CLng(COM_Call2(g_pDevice, VTBL_Device_GetDescriptorHandleIncrementSize, D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV))
    
    ' Create render target views
    Dim rtvHandle As D3D12_CPU_DESCRIPTOR_HANDLE
    COM_GetCPUDescriptorHandle g_pRtvHeap, rtvHandle
    
    Dim resourceIID As GUID: resourceIID = IID_ID3D12Resource()
    Dim frameIdx As Long
    For frameIdx = 0 To FRAME_COUNT - 1
        hr = ToHResult(COM_Call4(g_pSwapChain, VTBL_SwapChain_GetBuffer, frameIdx, VarPtr(resourceIID), VarPtr(g_pRenderTargets(frameIdx))))
        If hr < 0 Then COM_Release pFactory: InitD3D12 = False: Exit Function
        COM_Call4 g_pDevice, VTBL_Device_CreateRenderTargetView, g_pRenderTargets(frameIdx), 0, rtvHandle.ptr
        rtvHandle.ptr = rtvHandle.ptr + g_rtvDescriptorSize
    Next frameIdx
    
    ' Create Command Allocator
    Dim allocIID As GUID: allocIID = IID_ID3D12CommandAllocator()
    hr = ToHResult(COM_Call4(g_pDevice, VTBL_Device_CreateCommandAllocator, D3D12_COMMAND_LIST_TYPE_DIRECT, VarPtr(allocIID), VarPtr(g_pCommandAllocator)))
    LogMsg "CreateCommandAllocator returned: " & Hex$(hr)
    If hr < 0 Or g_pCommandAllocator = 0 Then COM_Release pFactory: InitD3D12 = False: Exit Function
    
    COM_Release pFactory
    InitD3D12 = True
    LogMsg "InitD3D12: done"
End Function

' ============================================================
' Create Root Signature with CBV
' ============================================================
Private Function CreateRootSignature() As Boolean
    LogMsg "CreateRootSignature: start"
    
    ' Descriptor range for CBV
    Dim cbvRange As D3D12_DESCRIPTOR_RANGE
    cbvRange.RangeType = D3D12_DESCRIPTOR_RANGE_TYPE_CBV
    cbvRange.NumDescriptors = 1
    cbvRange.BaseShaderRegister = 0
    cbvRange.RegisterSpace = 0
    cbvRange.OffsetInDescriptorsFromTableStart = D3D12_DESCRIPTOR_RANGE_OFFSET_APPEND
    
    ' Root parameter
    Dim rootParam As D3D12_ROOT_PARAMETER
    rootParam.ParameterType = D3D12_ROOT_PARAMETER_TYPE_DESCRIPTOR_TABLE
    rootParam.DescriptorTable.NumDescriptorRanges = 1
    rootParam.DescriptorTable.pDescriptorRanges = VarPtr(cbvRange)
    rootParam.ShaderVisibility = D3D12_SHADER_VISIBILITY_PIXEL
    
    Dim rootSigDesc As D3D12_ROOT_SIGNATURE_DESC
    rootSigDesc.NumParameters = 1
    rootSigDesc.pParameters = VarPtr(rootParam)
    rootSigDesc.NumStaticSamplers = 0
    rootSigDesc.pStaticSamplers = 0
    rootSigDesc.Flags = D3D12_ROOT_SIGNATURE_FLAG_ALLOW_INPUT_ASSEMBLER_INPUT_LAYOUT
    
    Dim pSignatureBlob As LongPtr
    Dim pErrorBlob As LongPtr
    
    Dim hr As Long
    hr = D3D12SerializeRootSignature(rootSigDesc, D3D_ROOT_SIGNATURE_VERSION_1, pSignatureBlob, pErrorBlob)
    LogMsg "D3D12SerializeRootSignature returned: " & Hex$(hr)
    
    If hr < 0 Then
        If pErrorBlob <> 0 Then
            Dim errPtr As LongPtr
            errPtr = COM_Call1(pErrorBlob, VTBL_Blob_GetBufferPointer)
            LogMsg "RootSignature error: " & PtrToAnsiString(errPtr)
            COM_Release pErrorBlob
        End If
        CreateRootSignature = False
        Exit Function
    End If
    
    Dim blobPtr As LongPtr: blobPtr = COM_Call1(pSignatureBlob, VTBL_Blob_GetBufferPointer)
    Dim blobSize As LongPtr: blobSize = COM_Call1(pSignatureBlob, VTBL_Blob_GetBufferSize)
    
    Dim rootSigIID As GUID: rootSigIID = IID_ID3D12RootSignature()
    hr = ToHResult(COM_Call6(g_pDevice, VTBL_Device_CreateRootSignature, 0, blobPtr, blobSize, VarPtr(rootSigIID), VarPtr(g_pRootSignature)))
    LogMsg "CreateRootSignature returned: " & Hex$(hr)
    
    COM_Release pSignatureBlob
    If pErrorBlob <> 0 Then COM_Release pErrorBlob
    
    If hr < 0 Or g_pRootSignature = 0 Then CreateRootSignature = False: Exit Function
    
    CreateRootSignature = True
    LogMsg "CreateRootSignature: done"
End Function

' ============================================================
' Create Pipeline State Object
' ============================================================
Private Function CreatePipelineState(ByVal shaderPath As String) As Boolean
    LogMsg "CreatePipelineState: start"
    
    ' Compile shaders from file
    Dim pVSBlob As LongPtr
    pVSBlob = CompileShaderFromFile(shaderPath, "VSMain", "vs_5_0")
    If pVSBlob = 0 Then CreatePipelineState = False: Exit Function
    
    Dim pPSBlob As LongPtr
    pPSBlob = CompileShaderFromFile(shaderPath, "PSMain", "ps_5_0")
    If pPSBlob = 0 Then COM_Release pVSBlob: CreatePipelineState = False: Exit Function
    
    Dim vsCodePtr As LongPtr: vsCodePtr = COM_Call1(pVSBlob, VTBL_Blob_GetBufferPointer)
    Dim vsCodeSize As LongPtr: vsCodeSize = COM_Call1(pVSBlob, VTBL_Blob_GetBufferSize)
    Dim psCodePtr As LongPtr: psCodePtr = COM_Call1(pPSBlob, VTBL_Blob_GetBufferPointer)
    Dim psCodeSize As LongPtr: psCodeSize = COM_Call1(pPSBlob, VTBL_Blob_GetBufferSize)
    
    ' Input layout (position only for fullscreen quad)
    g_semanticPosition = AnsiZBytes("POSITION")
    
    Dim inputElements(0 To 0) As D3D12_INPUT_ELEMENT_DESC
    inputElements(0).SemanticName = VarPtr(g_semanticPosition(0))
    inputElements(0).SemanticIndex = 0
    inputElements(0).Format = DXGI_FORMAT_R32G32_FLOAT
    inputElements(0).InputSlot = 0
    inputElements(0).AlignedByteOffset = 0
    inputElements(0).InputSlotClass = D3D12_INPUT_CLASSIFICATION_PER_VERTEX_DATA
    inputElements(0).InstanceDataStepRate = 0
    
    ' Build PSO desc
    Dim psoDesc As D3D12_GRAPHICS_PIPELINE_STATE_DESC
    
    psoDesc.pRootSignature = g_pRootSignature
    psoDesc.VS.pShaderBytecode = vsCodePtr
    psoDesc.VS.BytecodeLength = vsCodeSize
    psoDesc.PS.pShaderBytecode = psCodePtr
    psoDesc.PS.BytecodeLength = psCodeSize
    
    ' Blend state
    psoDesc.BlendState.AlphaToCoverageEnable = 0
    psoDesc.BlendState.IndependentBlendEnable = 0
    psoDesc.BlendState.RenderTarget(0).BlendEnable = 0
    psoDesc.BlendState.RenderTarget(0).LogicOpEnable = 0
    psoDesc.BlendState.RenderTarget(0).SrcBlend = D3D12_BLEND_ONE
    psoDesc.BlendState.RenderTarget(0).DestBlend = D3D12_BLEND_ZERO
    psoDesc.BlendState.RenderTarget(0).BlendOp = D3D12_BLEND_OP_ADD
    psoDesc.BlendState.RenderTarget(0).SrcBlendAlpha = D3D12_BLEND_ONE
    psoDesc.BlendState.RenderTarget(0).DestBlendAlpha = D3D12_BLEND_ZERO
    psoDesc.BlendState.RenderTarget(0).BlendOpAlpha = D3D12_BLEND_OP_ADD
    psoDesc.BlendState.RenderTarget(0).LogicOp = D3D12_LOGIC_OP_NOOP
    psoDesc.BlendState.RenderTarget(0).RenderTargetWriteMask = D3D12_COLOR_WRITE_ENABLE_ALL
    
    psoDesc.SampleMask = &HFFFFFFFF
    
    ' Rasterizer state (no culling for fullscreen quad)
    psoDesc.RasterizerState.FillMode = D3D12_FILL_MODE_SOLID
    psoDesc.RasterizerState.CullMode = D3D12_CULL_MODE_NONE
    psoDesc.RasterizerState.FrontCounterClockwise = 0
    psoDesc.RasterizerState.DepthBias = D3D12_DEFAULT_DEPTH_BIAS
    psoDesc.RasterizerState.DepthBiasClamp = D3D12_DEFAULT_DEPTH_BIAS_CLAMP
    psoDesc.RasterizerState.SlopeScaledDepthBias = D3D12_DEFAULT_SLOPE_SCALED_DEPTH_BIAS
    psoDesc.RasterizerState.DepthClipEnable = 1
    
    ' Depth stencil (disabled)
    psoDesc.DepthStencilState.DepthEnable = 0
    psoDesc.DepthStencilState.StencilEnable = 0
    
    ' Input layout
    psoDesc.InputLayout.pInputElementDescs = VarPtr(inputElements(0))
    psoDesc.InputLayout.NumElements = 1
    
    psoDesc.PrimitiveTopologyType = D3D12_PRIMITIVE_TOPOLOGY_TYPE_TRIANGLE
    psoDesc.NumRenderTargets = 1
    psoDesc.RTVFormats(0) = DXGI_FORMAT_R8G8B8A8_UNORM
    psoDesc.DSVFormat = DXGI_FORMAT_UNKNOWN
    psoDesc.SampleDesc.Count = 1
    psoDesc.SampleDesc.Quality = 0
    
    Dim psoIID As GUID: psoIID = IID_ID3D12PipelineState()
    Dim hr As Long
    hr = ToHResult(COM_Call4(g_pDevice, VTBL_Device_CreateGraphicsPipelineState, VarPtr(psoDesc), VarPtr(psoIID), VarPtr(g_pPipelineState)))
    LogMsg "CreateGraphicsPipelineState returned: " & Hex$(hr)
    
    COM_Release pVSBlob
    COM_Release pPSBlob
    
    If hr < 0 Or g_pPipelineState = 0 Then CreatePipelineState = False: Exit Function
    
    CreatePipelineState = True
    LogMsg "CreatePipelineState: done"
End Function

' ============================================================
' Create Command List
' ============================================================
Private Function CreateCommandList() As Boolean
    LogMsg "CreateCommandList: start"
    
    Dim cmdListIID As GUID: cmdListIID = IID_ID3D12GraphicsCommandList()
    Dim hr As Long
    hr = ToHResult(COM_Call7(g_pDevice, VTBL_Device_CreateCommandList, 0, D3D12_COMMAND_LIST_TYPE_DIRECT, g_pCommandAllocator, g_pPipelineState, VarPtr(cmdListIID), VarPtr(g_pCommandList)))
    LogMsg "CreateCommandList returned: " & Hex$(hr)
    
    If hr < 0 Or g_pCommandList = 0 Then CreateCommandList = False: Exit Function
    
    hr = ToHResult(COM_Call1(g_pCommandList, VTBL_CmdList_Close))
    
    CreateCommandList = True
    LogMsg "CreateCommandList: done"
End Function

' ============================================================
' Create Vertex Buffer (Fullscreen Quad)
' ============================================================
Private Function CreateVertexBuffer() As Boolean
    LogMsg "CreateVertexBuffer: start"
    
    ' Fullscreen quad (2 triangles, 6 vertices)
    Dim vertices(0 To 5) As VERTEX
    
    ' Triangle 1
    vertices(0).x = -1!: vertices(0).y = 1!   ' Top-left
    vertices(1).x = 1!: vertices(1).y = -1!   ' Bottom-right
    vertices(2).x = -1!: vertices(2).y = -1!  ' Bottom-left
    
    ' Triangle 2
    vertices(3).x = -1!: vertices(3).y = 1!   ' Top-left
    vertices(4).x = 1!: vertices(4).y = 1!    ' Top-right
    vertices(5).x = 1!: vertices(5).y = -1!   ' Bottom-right
    
    Dim vertexSize As Long: vertexSize = LenB(vertices(0))
    Dim bufferSize As LongLong: bufferSize = CLngLng(vertexSize) * 6
    LogMsg "Vertex size: " & vertexSize & ", Buffer size: " & bufferSize
    
    ' Heap properties
    Dim heapProps As D3D12_HEAP_PROPERTIES
    heapProps.cType = D3D12_HEAP_TYPE_UPLOAD
    heapProps.CreationNodeMask = 1
    heapProps.VisibleNodeMask = 1
    
    ' Resource desc
    Dim resourceDesc As D3D12_RESOURCE_DESC
    resourceDesc.Dimension = D3D12_RESOURCE_DIMENSION_BUFFER
    resourceDesc.Alignment = 0
    resourceDesc.Width = bufferSize
    resourceDesc.Height = 1
    resourceDesc.DepthOrArraySize = 1
    resourceDesc.MipLevels = 1
    resourceDesc.Format = DXGI_FORMAT_UNKNOWN
    resourceDesc.SampleDesc.Count = 1
    resourceDesc.SampleDesc.Quality = 0
    resourceDesc.Layout = 1
    resourceDesc.Flags = 0
    
    Dim resourceIID As GUID: resourceIID = IID_ID3D12Resource()
    Dim hr As Long
    
    Dim methodAddr As LongPtr
    methodAddr = GetVTableMethod(g_pDevice, VTBL_Device_CreateCommittedResource)
    
    ' Use cached thunk8
    SetThunkTarget g_thunk8, THUNK8_TARGET_OFFSET, methodAddr
    
    Dim args8 As ThunkArgs8
    args8.a1 = g_pDevice
    args8.a2 = VarPtr(heapProps)
    args8.a3 = D3D12_HEAP_FLAG_NONE
    args8.a4 = VarPtr(resourceDesc)
    args8.a5 = D3D12_RESOURCE_STATE_GENERIC_READ
    args8.a6 = 0
    args8.a7 = VarPtr(resourceIID)
    args8.a8 = VarPtr(g_pVertexBuffer)
    
    hr = ToHResult(CallWindowProcW(g_thunk8, 0, 0, VarPtr(args8), 0))
    LogMsg "CreateCommittedResource (VB) returned: " & Hex$(hr)
    
    If hr < 0 Or g_pVertexBuffer = 0 Then CreateVertexBuffer = False: Exit Function
    
    ' Map and copy data
    Dim pData As LongPtr
    hr = ToHResult(COM_Call4(g_pVertexBuffer, VTBL_Resource_Map, 0, 0, VarPtr(pData)))
    
    If hr >= 0 And pData <> 0 Then
        CopyMemory pData, VarPtr(vertices(0)), CLngPtr(bufferSize)
        COM_Call3 g_pVertexBuffer, VTBL_Resource_Unmap, 0, 0
    End If
    
    ' Setup vertex buffer view
    g_vertexBufferView.BufferLocation = COM_Call1(g_pVertexBuffer, VTBL_Resource_GetGPUVirtualAddress)
    g_vertexBufferView.SizeInBytes = CLng(bufferSize)
    g_vertexBufferView.StrideInBytes = vertexSize
    
    CreateVertexBuffer = True
    LogMsg "CreateVertexBuffer: done"
End Function

' ============================================================
' Create Constant Buffer
' ============================================================
Private Function CreateConstantBuffer() As Boolean
    LogMsg "CreateConstantBuffer: start"
    
    ' Constant buffer must be 256-byte aligned
    Dim cbSize As LongLong: cbSize = 256
    
    ' Heap properties
    Dim heapProps As D3D12_HEAP_PROPERTIES
    heapProps.cType = D3D12_HEAP_TYPE_UPLOAD
    heapProps.CreationNodeMask = 1
    heapProps.VisibleNodeMask = 1
    
    ' Resource desc
    Dim resourceDesc As D3D12_RESOURCE_DESC
    resourceDesc.Dimension = D3D12_RESOURCE_DIMENSION_BUFFER
    resourceDesc.Width = cbSize
    resourceDesc.Height = 1
    resourceDesc.DepthOrArraySize = 1
    resourceDesc.MipLevels = 1
    resourceDesc.Format = DXGI_FORMAT_UNKNOWN
    resourceDesc.SampleDesc.Count = 1
    resourceDesc.Layout = 1
    
    Dim resourceIID As GUID: resourceIID = IID_ID3D12Resource()
    Dim hr As Long
    
    Dim methodAddr As LongPtr
    methodAddr = GetVTableMethod(g_pDevice, VTBL_Device_CreateCommittedResource)
    
    ' Use cached thunk8
    SetThunkTarget g_thunk8, THUNK8_TARGET_OFFSET, methodAddr
    
    Dim args8 As ThunkArgs8
    args8.a1 = g_pDevice
    args8.a2 = VarPtr(heapProps)
    args8.a3 = D3D12_HEAP_FLAG_NONE
    args8.a4 = VarPtr(resourceDesc)
    args8.a5 = D3D12_RESOURCE_STATE_GENERIC_READ
    args8.a6 = 0
    args8.a7 = VarPtr(resourceIID)
    args8.a8 = VarPtr(g_pConstantBuffer)
    
    hr = ToHResult(CallWindowProcW(g_thunk8, 0, 0, VarPtr(args8), 0))
    LogMsg "CreateCommittedResource (CB) returned: " & Hex$(hr)
    
    If hr < 0 Or g_pConstantBuffer = 0 Then CreateConstantBuffer = False: Exit Function
    
    ' Map constant buffer (keep mapped)
    hr = ToHResult(COM_Call4(g_pConstantBuffer, VTBL_Resource_Map, 0, 0, VarPtr(g_constantBufferDataBegin)))
    LogMsg "Map CB returned: " & Hex$(hr)
    
    If hr < 0 Or g_constantBufferDataBegin = 0 Then CreateConstantBuffer = False: Exit Function
    
    ' Create CBV
    Dim cbvDesc As D3D12_CONSTANT_BUFFER_VIEW_DESC
    cbvDesc.BufferLocation = COM_Call1(g_pConstantBuffer, VTBL_Resource_GetGPUVirtualAddress)
    cbvDesc.SizeInBytes = CLng(cbSize)
    
    Dim cbvHandle As D3D12_CPU_DESCRIPTOR_HANDLE
    COM_GetCPUDescriptorHandle g_pCbvHeap, cbvHandle
    
    COM_Call3 g_pDevice, VTBL_Device_CreateConstantBufferView, VarPtr(cbvDesc), cbvHandle.ptr
    LogMsg "CreateConstantBufferView done"
    
    CreateConstantBuffer = True
    LogMsg "CreateConstantBuffer: done"
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
    
    If hr < 0 Or g_pFence = 0 Then CreateFence = False: Exit Function
    
    g_fenceValue = 1
    g_fenceEvent = CreateEventW(0, 0, 0, 0)
    
    If g_fenceEvent = 0 Then CreateFence = False: Exit Function
    
    CreateFence = True
    LogMsg "CreateFence: done"
End Function

' ============================================================
' Wait for previous frame
' ============================================================
Private Sub WaitForPreviousFrame()
    Dim fence As LongLong
    fence = g_fenceValue
    
    COM_Call3 g_pCommandQueue, VTBL_CmdQueue_Signal, g_pFence, CLngPtr(fence)
    g_fenceValue = g_fenceValue + 1
    
    Dim completed As LongLong
    completed = COM_Call1(g_pFence, VTBL_Fence_GetCompletedValue)
    
    If completed < fence Then
        COM_Call3 g_pFence, VTBL_Fence_SetEventOnCompletion, CLngPtr(fence), g_fenceEvent
        WaitForSingleObject g_fenceEvent, INFINITE
    End If
    
    g_frameIndex = CLng(COM_Call1(g_pSwapChain3, VTBL_SwapChain3_GetCurrentBackBufferIndex))
End Sub

' ============================================================
' Render frame
' ============================================================
Private Sub RenderFrame()
    ' Update constant buffer
    Dim cbData As CONSTANT_BUFFER_DATA
    cbData.iTime = CSng(GetTime() - g_startTime)
    cbData.iResolutionX = CSng(WIDTH)
    cbData.iResolutionY = CSng(HEIGHT)
    cbData.padding = 0!
    
    CopyMemory g_constantBufferDataBegin, VarPtr(cbData), CLngPtr(LenB(cbData))
    
    ' Reset command allocator and command list
    COM_Call1 g_pCommandAllocator, VTBL_CmdAlloc_Reset
    COM_Call3 g_pCommandList, VTBL_CmdList_Reset, g_pCommandAllocator, g_pPipelineState
    
    ' Set root signature
    COM_Call2 g_pCommandList, VTBL_CmdList_SetGraphicsRootSignature, g_pRootSignature
    
    ' Set descriptor heaps
    Dim ppHeaps As LongPtr
    ppHeaps = g_pCbvHeap
    COM_Call3 g_pCommandList, VTBL_CmdList_SetDescriptorHeaps, 1, VarPtr(ppHeaps)
    
    ' Set root descriptor table
    Dim gpuHandle As D3D12_GPU_DESCRIPTOR_HANDLE
    COM_GetGPUDescriptorHandle g_pCbvHeap, gpuHandle
    
    ' SetGraphicsRootDescriptorTable takes GPU handle as 8-byte value
    COM_Call3 g_pCommandList, VTBL_CmdList_SetGraphicsRootDescriptorTable, 0, CLngPtr(gpuHandle.ptr)
    
    ' Set viewport
    Dim vp As D3D12_VIEWPORT
    vp.TopLeftX = 0!: vp.TopLeftY = 0!
    vp.Width = CSng(WIDTH): vp.Height = CSng(HEIGHT)
    vp.MinDepth = 0!: vp.MaxDepth = 1!
    COM_Call3 g_pCommandList, VTBL_CmdList_RSSetViewports, 1, VarPtr(vp)
    
    ' Set scissor rect
    Dim sr As D3D12_RECT
    sr.Left = 0: sr.Top = 0: sr.Right = WIDTH: sr.Bottom = HEIGHT
    COM_Call3 g_pCommandList, VTBL_CmdList_RSSetScissorRects, 1, VarPtr(sr)
    
    ' Transition render target to RENDER_TARGET state
    Dim barrierToRT As D3D12_RESOURCE_BARRIER
    barrierToRT.cType = D3D12_RESOURCE_BARRIER_TYPE_TRANSITION
    barrierToRT.Flags = D3D12_RESOURCE_BARRIER_FLAG_NONE
    barrierToRT.Transition.pResource = g_pRenderTargets(g_frameIndex)
    barrierToRT.Transition.Subresource = D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES
    barrierToRT.Transition.StateBefore = D3D12_RESOURCE_STATE_PRESENT
    barrierToRT.Transition.StateAfter = D3D12_RESOURCE_STATE_RENDER_TARGET
    COM_Call3 g_pCommandList, VTBL_CmdList_ResourceBarrier, 1, VarPtr(barrierToRT)
    
    ' Get RTV handle for current frame
    Dim rtvHandle As D3D12_CPU_DESCRIPTOR_HANDLE
    COM_GetCPUDescriptorHandle g_pRtvHeap, rtvHandle
    rtvHandle.ptr = rtvHandle.ptr + CLngPtr(g_frameIndex) * CLngPtr(g_rtvDescriptorSize)
    
    ' Clear render target
    Dim clearColor(0 To 3) As Single
    clearColor(0) = 0!: clearColor(1) = 0!: clearColor(2) = 0!: clearColor(3) = 1!
    COM_Call5 g_pCommandList, VTBL_CmdList_ClearRenderTargetView, rtvHandle.ptr, VarPtr(clearColor(0)), 0, 0
    
    ' Set render target
    COM_Call5 g_pCommandList, VTBL_CmdList_OMSetRenderTargets, 1, VarPtr(rtvHandle), 1, 0
    
    ' Set primitive topology
    COM_Call2 g_pCommandList, VTBL_CmdList_IASetPrimitiveTopology, D3D_PRIMITIVE_TOPOLOGY_TRIANGLELIST
    
    ' Set vertex buffer
    COM_Call4 g_pCommandList, VTBL_CmdList_IASetVertexBuffers, 0, 1, VarPtr(g_vertexBufferView)
    
    ' Draw fullscreen quad (6 vertices)
    COM_Call5 g_pCommandList, VTBL_CmdList_DrawInstanced, 6, 1, 0, 0
    
    ' Transition render target to PRESENT state
    Dim barrierToPresent As D3D12_RESOURCE_BARRIER
    barrierToPresent.cType = D3D12_RESOURCE_BARRIER_TYPE_TRANSITION
    barrierToPresent.Flags = D3D12_RESOURCE_BARRIER_FLAG_NONE
    barrierToPresent.Transition.pResource = g_pRenderTargets(g_frameIndex)
    barrierToPresent.Transition.Subresource = D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES
    barrierToPresent.Transition.StateBefore = D3D12_RESOURCE_STATE_RENDER_TARGET
    barrierToPresent.Transition.StateAfter = D3D12_RESOURCE_STATE_PRESENT
    COM_Call3 g_pCommandList, VTBL_CmdList_ResourceBarrier, 1, VarPtr(barrierToPresent)
    
    ' Close command list
    COM_Call1 g_pCommandList, VTBL_CmdList_Close
    
    ' Execute command list
    Dim ppCommandLists As LongPtr
    ppCommandLists = g_pCommandList
    COM_Call3 g_pCommandQueue, VTBL_CmdQueue_ExecuteCommandLists, 1, VarPtr(ppCommandLists)
    
    ' Present
    COM_Call3 g_pSwapChain, VTBL_SwapChain_Present, 1, 0
    
    ' Wait for frame
    WaitForPreviousFrame
End Sub

' ============================================================
' Cleanup
' ============================================================
Private Sub CleanupD3D12()
    LogMsg "CleanupD3D12: start"
    
    WaitForPreviousFrame
    
    If g_fenceEvent <> 0 Then CloseHandle g_fenceEvent: g_fenceEvent = 0
    
    If g_pConstantBuffer <> 0 Then COM_Release g_pConstantBuffer: g_pConstantBuffer = 0
    If g_pVertexBuffer <> 0 Then COM_Release g_pVertexBuffer: g_pVertexBuffer = 0
    If g_pFence <> 0 Then COM_Release g_pFence: g_pFence = 0
    If g_pCommandList <> 0 Then COM_Release g_pCommandList: g_pCommandList = 0
    If g_pPipelineState <> 0 Then COM_Release g_pPipelineState: g_pPipelineState = 0
    If g_pRootSignature <> 0 Then COM_Release g_pRootSignature: g_pRootSignature = 0
    If g_pCommandAllocator <> 0 Then COM_Release g_pCommandAllocator: g_pCommandAllocator = 0
    
    Dim i As Long
    For i = 0 To FRAME_COUNT - 1
        If g_pRenderTargets(i) <> 0 Then COM_Release g_pRenderTargets(i): g_pRenderTargets(i) = 0
    Next i
    
    If g_pCbvHeap <> 0 Then COM_Release g_pCbvHeap: g_pCbvHeap = 0
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

    LogMsg "Main: start (OPTIMIZED VERSION)"
    
    ' Initialize cached thunks FIRST (before any COM calls)
    InitThunks
    
    ' Shader file path (same directory as Excel file)
    Dim shaderPath As String
    shaderPath = ThisWorkbook.Path & "\hello.hlsl"
    LogMsg "Shader path: " & shaderPath

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
        LogMsg "RegisterClassExW failed"
        MsgBox "RegisterClassExW failed.", vbCritical
        GoTo FIN
    End If

    g_hWnd = CreateWindowExW(0, StrPtr(CLASS_NAME), StrPtr(WINDOW_NAME), WS_OVERLAPPEDWINDOW, _
                            CW_USEDEFAULT, CW_USEDEFAULT, WIDTH, HEIGHT, 0, 0, hInstance, 0)
    If g_hWnd = 0 Then
        LogMsg "CreateWindowExW failed"
        MsgBox "CreateWindowExW failed.", vbCritical
        GoTo FIN
    End If

    ShowWindow g_hWnd, SW_SHOWDEFAULT
    UpdateWindow g_hWnd

    ' Initialize D3D12
    If Not InitD3D12(g_hWnd) Then
        MsgBox "Failed to initialize DirectX 12.", vbCritical
        GoTo FIN
    End If

    ' Create root signature with CBV
    If Not CreateRootSignature() Then
        MsgBox "Failed to create root signature.", vbCritical
        GoTo FIN
    End If

    ' Create pipeline state
    If Not CreatePipelineState(shaderPath) Then
        MsgBox "Failed to create pipeline state. Check shader file: " & shaderPath, vbCritical
        GoTo FIN
    End If

    ' Create command list
    If Not CreateCommandList() Then
        MsgBox "Failed to create command list.", vbCritical
        GoTo FIN
    End If

    ' Create vertex buffer (fullscreen quad)
    If Not CreateVertexBuffer() Then
        MsgBox "Failed to create vertex buffer.", vbCritical
        GoTo FIN
    End If

    ' Create constant buffer
    If Not CreateConstantBuffer() Then
        MsgBox "Failed to create constant buffer.", vbCritical
        GoTo FIN
    End If

    ' Create fence
    If Not CreateFence() Then
        MsgBox "Failed to create fence.", vbCritical
        GoTo FIN
    End If

    ' Initialize start time
    g_startTime = GetTime()

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
                DoEvents
            End If
        End If
    Loop

FIN:
    LogMsg "Cleanup: start"
    CleanupD3D12
    FreeThunks  ' Free cached thunks at the very end
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
