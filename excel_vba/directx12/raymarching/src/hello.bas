Attribute VB_Name = "hello"
Option Explicit

Private g_qpcFreq As Double
' ============================================================
'  Excel VBA (64-bit) + DirectX 12 - Raymarching Rendering
'   - PIPELINED VERSION: Proper frame-in-flight management
'   - Creates a Win32 window
'   - Creates D3D12 Device, CommandQueue, SwapChain
'   - Creates RootSignature with CBV, PipelineState
'   - Manages GPU synchronization with per-frame Fences
'   - Renders raymarching scene using external hello.hlsl
'   - Debug log: C:\TEMP\dx12_raymarching.log
'
'  KEY OPTIMIZATION: Frame pipelining - CPU and GPU work in parallel
' ============================================================

' -------- Settings --------
Public Const PROF_WINDOW_FRAMES As Long = 300
Public Const PROF_LOG_PATH As String = "C:\TEMP\dx12_raymarch_prof.log"

' -------- Sections --------
Public Const PROF_WAIT As Long = 0
Public Const PROF_RESET As Long = 1
Public Const PROF_UPDATE As Long = 2
Public Const PROF_RECORD As Long = 3
Public Const PROF_EXECUTE As Long = 4
Public Const PROF_PRESENT As Long = 5
Public Const PROF_SIGNAL As Long = 6
Public Const PROF_TOTAL As Long = 7
Public Const PROF_COUNT As Long = 8

Private Type LARGE_INTEGER
    QuadPart As LongLong
End Type

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
Private Const WAIT_OBJECT_0 As Long = 0

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

' Frame management constants
Private Const FRAME_COUNT As Long = 3
Private Const Width As Long = 800
Private Const Height As Long = 600

' -----------------------------
' vtable indices
' -----------------------------
Private Const ONVTBL_IUnknown_QueryInterface As Long = 0
Private Const ONVTBL_IUnknown_AddRef As Long = 1
Private Const ONVTBL_IUnknown_Release As Long = 2

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

Private Const VTBL_DescHeap_GetCPUDescriptorHandleForHeapStart As Long = 9
Private Const VTBL_DescHeap_GetGPUDescriptorHandleForHeapStart As Long = 10

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

Private Const CLASS_NAME As String = "RaymarchingDX12WindowVBA"
Private Const WINDOW_NAME As String = "Raymarching - DirectX 12 (VBA64) - Pipelined"

' -----------------------------
' Types
' -----------------------------
Private Type GUID
    Data1 As Long
    Data2 As Integer
    Data3 As Integer
    Data4(0 To 7) As Byte
End Type

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

Private Type VERTEX
    x As Single
    y As Single
End Type

Private Type CONSTANT_BUFFER_DATA
    iTime As Single
    iResolutionX As Single
    iResolutionY As Single
    padding As Single
End Type

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
Private g_pCommandList As LongPtr
Private g_pFrameCommandLists(0 To FRAME_COUNT - 1) As LongPtr
Private g_pRootSignature As LongPtr
Private g_pPipelineState As LongPtr
Private g_pFence As LongPtr
Private g_fenceEvent As LongPtr
Private g_rtvDescriptorSize As Long
Private g_cbvDescriptorSize As Long
Private g_pRenderTargets(0 To FRAME_COUNT - 1) As LongPtr
Private g_pVertexBuffer As LongPtr
'Private g_pConstantBuffer As LongPtr
'Private g_constantBufferDataBegin As LongPtr
Private g_pConstantBuffers(0 To FRAME_COUNT - 1) As LongPtr
Private g_constantBufferDataBegins(0 To FRAME_COUNT - 1) As LongPtr

Private g_vertexBufferView As D3D12_VERTEX_BUFFER_VIEW

' *** KEY CHANGE: Per-frame resources for pipelining ***
Private g_pCommandAllocators(0 To FRAME_COUNT - 1) As LongPtr
Private g_frameFenceValues(0 To FRAME_COUNT - 1) As LongLong
Private g_currentFenceValue As LongLong
Private g_frameIndex As Long

' Semantic name strings
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

' Thunk memory - CACHED
Private Const MEM_COMMIT As Long = &H1000&
Private Const MEM_RESERVE As Long = &H2000&
Private Const MEM_RELEASE As Long = &H8000&
Private Const PAGE_EXECUTE_READWRITE As Long = &H40&

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

Private g_thunksInitialized As Boolean

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
    Private Declare PtrSafe Function GetClientRect Lib "user32" (ByVal hWnd As LongPtr, ByRef lpRect As RECT) As Long
    Private Declare PtrSafe Sub Sleep Lib "kernel32" (ByVal dwMilliseconds As Long)
    Private Declare PtrSafe Function GetLastError Lib "kernel32" () As Long
    Private Declare PtrSafe Function GetTickCount Lib "kernel32" () As Long
    Private Declare PtrSafe Function CreateEventW Lib "kernel32" (ByVal lpEventAttributes As LongPtr, ByVal bManualReset As Long, ByVal bInitialState As Long, ByVal lpName As LongPtr) As LongPtr
    Private Declare PtrSafe Function WaitForSingleObject Lib "kernel32" (ByVal hHandle As LongPtr, ByVal dwMilliseconds As Long) As Long
    Private Declare PtrSafe Function CloseHandle Lib "kernel32" (ByVal hObject As LongPtr) As Long
    Private Declare PtrSafe Function CallWindowProcW Lib "user32" (ByVal lpPrevWndFunc As LongPtr, ByVal hWnd As LongPtr, ByVal msg As LongPtr, ByVal wParam As LongPtr, ByVal lParam As LongPtr) As LongPtr
    Private Declare PtrSafe Function D3D12CreateDevice Lib "d3d12.dll" (ByVal pAdapter As LongPtr, ByVal MinimumFeatureLevel As Long, ByRef riid As GUID, ByRef ppDevice As LongPtr) As Long
    Private Declare PtrSafe Function CreateDXGIFactory1 Lib "dxgi.dll" (ByRef riid As GUID, ByRef ppFactory As LongPtr) As Long
    Private Declare PtrSafe Function D3D12SerializeRootSignature Lib "d3d12.dll" (ByRef pRootSignature As D3D12_ROOT_SIGNATURE_DESC, ByVal Version As Long, ByRef ppBlob As LongPtr, ByRef ppErrorBlob As LongPtr) As Long
    Private Declare PtrSafe Function GetProcAddress Lib "kernel32" (ByVal hModule As LongPtr, ByVal lpProcName As LongPtr) As LongPtr
    Private Declare PtrSafe Function LoadLibraryW Lib "kernel32" (ByVal lpLibFileName As LongPtr) As LongPtr
    Private Declare PtrSafe Function FreeLibrary Lib "kernel32" (ByVal hLibModule As LongPtr) As Long
    Private Declare PtrSafe Function CreateDirectoryW Lib "kernel32" (ByVal lpPathName As LongPtr, ByVal lpSecurityAttributes As LongPtr) As Long
    Private Declare PtrSafe Function CreateFileW Lib "kernel32" (ByVal lpFileName As LongPtr, ByVal dwDesiredAccess As Long, ByVal dwShareMode As Long, ByVal lpSecurityAttributes As LongPtr, ByVal dwCreationDisposition As Long, ByVal dwFlagsAndAttributes As Long, ByVal hTemplateFile As LongPtr) As LongPtr
    Private Declare PtrSafe Function WriteFile Lib "kernel32" (ByVal hFile As LongPtr, ByRef lpBuffer As Any, ByVal nNumberOfBytesToWrite As Long, ByRef lpNumberOfBytesWritten As Long, ByVal lpOverlapped As LongPtr) As Long
    Private Declare PtrSafe Function ReadFile Lib "kernel32" (ByVal hFile As LongPtr, ByRef lpBuffer As Any, ByVal nNumberOfBytesToRead As Long, ByRef lpNumberOfBytesRead As Long, ByVal lpOverlapped As LongPtr) As Long
    Private Declare PtrSafe Function GetFileSize Lib "kernel32" (ByVal hFile As LongPtr, ByRef lpFileSizeHigh As Long) As Long
    Private Declare PtrSafe Function FlushFileBuffers Lib "kernel32" (ByVal hFile As LongPtr) As Long
    Private Declare PtrSafe Function lstrlenA Lib "kernel32" (ByVal lpString As LongPtr) As Long
    Private Declare PtrSafe Sub RtlMoveMemory Lib "kernel32" (ByRef Destination As Any, ByVal Source As LongPtr, ByVal Length As Long)
    Private Declare PtrSafe Sub RtlMoveMemoryFromPtr Lib "kernel32" Alias "RtlMoveMemory" (ByVal Destination As LongPtr, ByRef Source As Any, ByVal Length As Long)
    Private Declare PtrSafe Sub CopyMemory Lib "kernel32" Alias "RtlMoveMemory" (ByVal Destination As LongPtr, ByVal Source As LongPtr, ByVal Length As LongPtr)
    Private Declare PtrSafe Function VirtualAlloc Lib "kernel32" (ByVal lpAddress As LongPtr, ByVal dwSize As LongPtr, ByVal flAllocationType As Long, ByVal flProtect As Long) As LongPtr
    Private Declare PtrSafe Function VirtualFree Lib "kernel32" (ByVal lpAddress As LongPtr, ByVal dwSize As LongPtr, ByVal dwFreeType As Long) As Long
    Private Declare PtrSafe Function QueryPerformanceCounter Lib "kernel32" (ByRef lpPerformanceCount As LARGE_INTEGER) As Long
    Private Declare PtrSafe Function QueryPerformanceFrequency Lib "kernel32" (ByRef lpFrequency As LARGE_INTEGER) As Long
#End If

Private g_profFreq As Double
Private g_t0 As Double
Private g_prev As Double
Private g_acc(0 To PROF_COUNT - 1) As Double
Private g_frames As Long

' Public API
Public Sub ProfilerInit()
    Dim f As LARGE_INTEGER
    If QueryPerformanceFrequency(f) = 0 Then
        g_profFreq = 0#
    Else
        g_profFreq = CDbl(f.QuadPart)
    End If
End Sub

Public Sub ProfilerReset()
    Dim i As Long
    For i = 0 To PROF_COUNT - 1
        g_acc(i) = 0#
    Next i
    g_frames = 0
End Sub

Public Sub ProfilerBeginFrame()
    Dim t As Double
    t = NowQpcMs()
    g_t0 = t
    g_prev = t
End Sub

Public Sub ProfilerMark(ByVal sectionId As Long)
    Dim t As Double
    t = NowQpcMs()
    If sectionId >= 0 And sectionId < PROF_COUNT Then
        g_acc(sectionId) = g_acc(sectionId) + (t - g_prev)
    End If
    g_prev = t
End Sub

Public Sub ProfilerEndFrame()
    Dim t As Double
    t = NowQpcMs()
    g_acc(PROF_TOTAL) = g_acc(PROF_TOTAL) + (t - g_t0)
    g_prev = t

    g_frames = g_frames + 1
    If g_frames Mod PROF_WINDOW_FRAMES = 0 Then
        ProfilerDumpAverage
    End If
End Sub

Public Sub ProfilerFlush()
    If g_frames > 0 Then
        ProfilerDumpAverage
    End If
End Sub

' Internals
Private Function NowQpcMs() As Double
    Dim c As LARGE_INTEGER
    If g_profFreq = 0# Then
        NowQpcMs = 0#
        Exit Function
    End If
    QueryPerformanceCounter c
    NowQpcMs = (CDbl(c.QuadPart) * 1000#) / g_profFreq
End Function

Private Sub ProfilerDumpAverage()
    On Error Resume Next

    Dim denom As Double
    denom = CDbl(g_frames)
    If denom <= 0# Then Exit Sub

    Dim s As String
    s = "=== DX12 PROFILE (avg ms over " & CStr(g_frames) & " frames) ===" & vbCrLf & _
        "  Wait:    " & FmtMs(g_acc(PROF_WAIT) / denom) & vbCrLf & _
        "  Reset:   " & FmtMs(g_acc(PROF_RESET) / denom) & vbCrLf & _
        "  Update:  " & FmtMs(g_acc(PROF_UPDATE) / denom) & vbCrLf & _
        "  Record:  " & FmtMs(g_acc(PROF_RECORD) / denom) & vbCrLf & _
        "  Execute: " & FmtMs(g_acc(PROF_EXECUTE) / denom) & vbCrLf & _
        "  Present: " & FmtMs(g_acc(PROF_PRESENT) / denom) & vbCrLf & _
        "  Signal:  " & FmtMs(g_acc(PROF_SIGNAL) / denom) & vbCrLf & _
        "  TOTAL:   " & FmtMs(g_acc(PROF_TOTAL) / denom) & vbCrLf & _
        "  Est FPS: " & Format$(IIf(g_acc(PROF_TOTAL) > 0#, (1000# * denom) / g_acc(PROF_TOTAL), 0#), "0.0") & vbCrLf & _
        "============================================="

    Debug.Print s

    Dim ff As Integer
    ff = FreeFile
    Open PROF_LOG_PATH For Append As #ff
    Print #ff, s
    Close #ff

End Sub

Private Function FmtMs(ByVal v As Double) As String
    FmtMs = Format$(v, "0.000") & " ms"
End Function

' ============================================================
' Logger
' ============================================================
Private Sub LogOpen()
    On Error Resume Next
    CreateDirectoryW StrPtr("C:\TEMP"), 0
    g_log = CreateFileW(StrPtr("C:\TEMP\dx12_raymarching.log"), GENERIC_WRITE, FILE_SHARE_READ Or FILE_SHARE_WRITE, 0, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, 0)
    If g_log = 0 Or g_log = -1 Then g_log = 0
    LogMsg "==== DX12 RAYMARCHING LOG START (PIPELINED) ===="
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
    ' Returns seconds (high-resolution). Uses cached QPC frequency.
    If g_qpcFreq = 0# Then
        Dim f As LARGE_INTEGER
        If QueryPerformanceFrequency(f) = 0 Then
            g_qpcFreq = 0#
        Else
            g_qpcFreq = CDbl(f.QuadPart)
        End If
    End If
    If g_qpcFreq = 0# Then
        GetTime = Timer
        Exit Function
    End If
    Dim c As LARGE_INTEGER
    QueryPerformanceCounter c
    GetTime = CDbl(c.QuadPart) / g_qpcFreq
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
' Vtable helpers
' ============================================================
Private Function GetVTableMethod(ByVal pObj As LongPtr, ByVal vtIndex As Long) As LongPtr
    Dim vtable As LongPtr
    Dim methodAddr As LongPtr
    CopyMemory VarPtr(vtable), pObj, 8
    CopyMemory VarPtr(methodAddr), vtable + CLngPtr(vtIndex) * 8, 8
    GetVTableMethod = methodAddr
End Function

' ============================================================
' Cached Thunk builders
' ============================================================
Private Function BuildThunk1Cached() As LongPtr
    Dim code(0 To 39) As Byte
    Dim i As Long: i = 0
    code(i) = &H48: i = i + 1: code(i) = &H83: i = i + 1: code(i) = &HEC: i = i + 1: code(i) = &H28: i = i + 1
    code(i) = &H4D: i = i + 1: code(i) = &H89: i = i + 1: code(i) = &HC2: i = i + 1
    code(i) = &H49: i = i + 1: code(i) = &H8B: i = i + 1: code(i) = &HA: i = i + 1
    code(i) = &H48: i = i + 1: code(i) = &HB8: i = i + 1
    Dim j As Long: For j = 0 To 7: code(i + j) = 0: Next j: i = i + 8
    code(i) = &HFF: i = i + 1: code(i) = &HD0: i = i + 1
    code(i) = &H48: i = i + 1: code(i) = &H83: i = i + 1: code(i) = &HC4: i = i + 1: code(i) = &H28: i = i + 1
    code(i) = &HC3
    Dim mem As LongPtr: mem = VirtualAlloc(0, 64, MEM_COMMIT Or MEM_RESERVE, PAGE_EXECUTE_READWRITE)
    If mem = 0 Then Err.Raise vbObjectError + 8996
    CopyMemory mem, VarPtr(code(0)), CLngPtr(i + 1)
    BuildThunk1Cached = mem
End Function

Private Function BuildThunk2Cached() As LongPtr
    Dim code(0 To 47) As Byte: Dim i As Long: i = 0
    code(i) = &H48: i = i + 1: code(i) = &H83: i = i + 1: code(i) = &HEC: i = i + 1: code(i) = &H28: i = i + 1
    code(i) = &H4D: i = i + 1: code(i) = &H89: i = i + 1: code(i) = &HC2: i = i + 1
    code(i) = &H49: i = i + 1: code(i) = &H8B: i = i + 1: code(i) = &HA: i = i + 1
    code(i) = &H49: i = i + 1: code(i) = &H8B: i = i + 1: code(i) = &H52: i = i + 1: code(i) = &H8: i = i + 1
    code(i) = &H48: i = i + 1: code(i) = &HB8: i = i + 1
    Dim j As Long: For j = 0 To 7: code(i + j) = 0: Next j: i = i + 8
    code(i) = &HFF: i = i + 1: code(i) = &HD0: i = i + 1
    code(i) = &H48: i = i + 1: code(i) = &H83: i = i + 1: code(i) = &HC4: i = i + 1: code(i) = &H28: i = i + 1
    code(i) = &HC3
    Dim mem As LongPtr: mem = VirtualAlloc(0, 64, MEM_COMMIT Or MEM_RESERVE, PAGE_EXECUTE_READWRITE)
    If mem = 0 Then Err.Raise vbObjectError + 8997
    CopyMemory mem, VarPtr(code(0)), CLngPtr(i + 1)
    BuildThunk2Cached = mem
End Function

Private Function BuildThunk3Cached() As LongPtr
    Dim code(0 To 55) As Byte: Dim i As Long: i = 0
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
    Dim mem As LongPtr: mem = VirtualAlloc(0, 64, MEM_COMMIT Or MEM_RESERVE, PAGE_EXECUTE_READWRITE)
    If mem = 0 Then Err.Raise vbObjectError + 8998
    CopyMemory mem, VarPtr(code(0)), CLngPtr(i + 1)
    BuildThunk3Cached = mem
End Function

Private Function BuildThunk4Cached() As LongPtr
    Dim code(0 To 63) As Byte: Dim i As Long: i = 0
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
    Dim mem As LongPtr: mem = VirtualAlloc(0, 128, MEM_COMMIT Or MEM_RESERVE, PAGE_EXECUTE_READWRITE)
    If mem = 0 Then Err.Raise vbObjectError + 8999
    CopyMemory mem, VarPtr(code(0)), CLngPtr(i + 1)
    BuildThunk4Cached = mem
End Function

Private Function BuildThunk5Cached() As LongPtr
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
    Dim j As Long: For j = 0 To 7: code(i + j) = 0: Next j: i = i + 8
    code(i) = &HFF: i = i + 1: code(i) = &HD0: i = i + 1
    code(i) = &H48: i = i + 1: code(i) = &H83: i = i + 1: code(i) = &HC4: i = i + 1: code(i) = &H38: i = i + 1
    code(i) = &HC3
    Dim mem As LongPtr: mem = VirtualAlloc(0, 128, MEM_COMMIT Or MEM_RESERVE, PAGE_EXECUTE_READWRITE)
    If mem = 0 Then Err.Raise vbObjectError + 9000
    CopyMemory mem, VarPtr(code(0)), CLngPtr(i + 1)
    BuildThunk5Cached = mem
End Function

Private Function BuildThunk6Cached() As LongPtr
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
    Dim j As Long: For j = 0 To 7: code(i + j) = 0: Next j: i = i + 8
    code(i) = &HFF: i = i + 1: code(i) = &HD0: i = i + 1
    code(i) = &H48: i = i + 1: code(i) = &H83: i = i + 1: code(i) = &HC4: i = i + 1: code(i) = &H48: i = i + 1
    code(i) = &HC3
    Dim mem As LongPtr: mem = VirtualAlloc(0, 128, MEM_COMMIT Or MEM_RESERVE, PAGE_EXECUTE_READWRITE)
    If mem = 0 Then Err.Raise vbObjectError + 9001
    CopyMemory mem, VarPtr(code(0)), CLngPtr(i + 1)
    BuildThunk6Cached = mem
End Function

Private Function BuildThunk7Cached() As LongPtr
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
    Dim j As Long: For j = 0 To 7: code(i + j) = 0: Next j: i = i + 8
    code(i) = &HFF: i = i + 1: code(i) = &HD0: i = i + 1
    code(i) = &H48: i = i + 1: code(i) = &H83: i = i + 1: code(i) = &HC4: i = i + 1: code(i) = &H58: i = i + 1
    code(i) = &HC3
    Dim mem As LongPtr: mem = VirtualAlloc(0, 128, MEM_COMMIT Or MEM_RESERVE, PAGE_EXECUTE_READWRITE)
    If mem = 0 Then Err.Raise vbObjectError + 9002
    CopyMemory mem, VarPtr(code(0)), CLngPtr(i + 1)
    BuildThunk7Cached = mem
End Function

Private Function BuildThunk8Cached() As LongPtr
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
    Dim j As Long: For j = 0 To 7: code(i + j) = 0: Next j: i = i + 8
    code(i) = &HFF: i = i + 1: code(i) = &HD0: i = i + 1
    code(i) = &H48: i = i + 1: code(i) = &H83: i = i + 1: code(i) = &HC4: i = i + 1: code(i) = &H68: i = i + 1
    code(i) = &HC3
    Dim mem As LongPtr: mem = VirtualAlloc(0, 160, MEM_COMMIT Or MEM_RESERVE, PAGE_EXECUTE_READWRITE)
    If mem = 0 Then Err.Raise vbObjectError + 9003
    CopyMemory mem, VarPtr(code(0)), CLngPtr(i + 1)
    BuildThunk8Cached = mem
End Function

Private Function BuildThunk9Cached() As LongPtr
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
    Dim j As Long: For j = 0 To 7: code(i + j) = 0: Next j: i = i + 8
    code(i) = &HFF: i = i + 1: code(i) = &HD0: i = i + 1
    code(i) = &H48: i = i + 1: code(i) = &H83: i = i + 1: code(i) = &HC4: i = i + 1: code(i) = &H68: i = i + 1
    code(i) = &HC3
    Dim mem As LongPtr: mem = VirtualAlloc(0, 160, MEM_COMMIT Or MEM_RESERVE, PAGE_EXECUTE_READWRITE)
    If mem = 0 Then Err.Raise vbObjectError + 9004
    CopyMemory mem, VarPtr(code(0)), CLngPtr(i + 1)
    BuildThunk9Cached = mem
End Function

Private Function BuildThunkRetStructCached() As LongPtr
    Dim code(0 To 47) As Byte: Dim i As Long: i = 0
    code(i) = &H48: i = i + 1: code(i) = &H83: i = i + 1: code(i) = &HEC: i = i + 1: code(i) = &H28: i = i + 1
    code(i) = &H4D: i = i + 1: code(i) = &H89: i = i + 1: code(i) = &HC2: i = i + 1
    code(i) = &H49: i = i + 1: code(i) = &H8B: i = i + 1: code(i) = &HA: i = i + 1
    code(i) = &H49: i = i + 1: code(i) = &H8B: i = i + 1: code(i) = &H52: i = i + 1: code(i) = &H8: i = i + 1
    code(i) = &H48: i = i + 1: code(i) = &HB8: i = i + 1
    Dim j As Long: For j = 0 To 7: code(i + j) = 0: Next j: i = i + 8
    code(i) = &HFF: i = i + 1: code(i) = &HD0: i = i + 1
    code(i) = &H48: i = i + 1: code(i) = &H83: i = i + 1: code(i) = &HC4: i = i + 1: code(i) = &H28: i = i + 1
    code(i) = &HC3
    Dim mem As LongPtr: mem = VirtualAlloc(0, 64, MEM_COMMIT Or MEM_RESERVE, PAGE_EXECUTE_READWRITE)
    If mem = 0 Then Err.Raise vbObjectError + 9005
    CopyMemory mem, VarPtr(code(0)), CLngPtr(i + 1)
    BuildThunkRetStructCached = mem
End Function

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
    LogMsg "InitThunks: done"
End Sub

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

Private Sub SetThunkTarget(ByVal pThunk As LongPtr, ByVal offset As Long, ByVal target As LongPtr)
    CopyMemory pThunk + CLngPtr(offset), VarPtr(target), 8
End Sub

' ============================================================
' COM Call helpers
' ============================================================
Private Function COM_Call1(ByVal pObj As LongPtr, ByVal vtIndex As Long) As LongPtr
    SetThunkTarget g_thunk1, THUNK1_TARGET_OFFSET, GetVTableMethod(pObj, vtIndex)
    Dim args As ThunkArgs1: args.a1 = pObj
    COM_Call1 = CallWindowProcW(g_thunk1, 0, 0, VarPtr(args), 0)
End Function

Private Function COM_Call2(ByVal pObj As LongPtr, ByVal vtIndex As Long, ByVal a2 As LongPtr) As LongPtr
    SetThunkTarget g_thunk2, THUNK2_TARGET_OFFSET, GetVTableMethod(pObj, vtIndex)
    Dim args As ThunkArgs2: args.a1 = pObj: args.a2 = a2
    COM_Call2 = CallWindowProcW(g_thunk2, 0, 0, VarPtr(args), 0)
End Function

Private Function COM_Call3(ByVal pObj As LongPtr, ByVal vtIndex As Long, ByVal a2 As LongPtr, ByVal a3 As LongPtr) As LongPtr
    SetThunkTarget g_thunk3, THUNK3_TARGET_OFFSET, GetVTableMethod(pObj, vtIndex)
    Dim args As ThunkArgs3: args.a1 = pObj: args.a2 = a2: args.a3 = a3
    COM_Call3 = CallWindowProcW(g_thunk3, 0, 0, VarPtr(args), 0)
End Function

Private Function COM_Call4(ByVal pObj As LongPtr, ByVal vtIndex As Long, ByVal a2 As LongPtr, ByVal a3 As LongPtr, ByVal a4 As LongPtr) As LongPtr
    SetThunkTarget g_thunk4, THUNK4_TARGET_OFFSET, GetVTableMethod(pObj, vtIndex)
    Dim args As ThunkArgs4: args.a1 = pObj: args.a2 = a2: args.a3 = a3: args.a4 = a4
    COM_Call4 = CallWindowProcW(g_thunk4, 0, 0, VarPtr(args), 0)
End Function

Private Function COM_Call5(ByVal pObj As LongPtr, ByVal vtIndex As Long, ByVal a2 As LongPtr, ByVal a3 As LongPtr, ByVal a4 As LongPtr, ByVal a5 As LongPtr) As LongPtr
    SetThunkTarget g_thunk5, THUNK5_TARGET_OFFSET, GetVTableMethod(pObj, vtIndex)
    Dim args As ThunkArgs5: args.a1 = pObj: args.a2 = a2: args.a3 = a3: args.a4 = a4: args.a5 = a5
    COM_Call5 = CallWindowProcW(g_thunk5, 0, 0, VarPtr(args), 0)
End Function

Private Function COM_Call6(ByVal pObj As LongPtr, ByVal vtIndex As Long, ByVal a2 As LongPtr, ByVal a3 As LongPtr, ByVal a4 As LongPtr, ByVal a5 As LongPtr, ByVal a6 As LongPtr) As LongPtr
    SetThunkTarget g_thunk6, THUNK6_TARGET_OFFSET, GetVTableMethod(pObj, vtIndex)
    Dim args As ThunkArgs6: args.a1 = pObj: args.a2 = a2: args.a3 = a3: args.a4 = a4: args.a5 = a5: args.a6 = a6
    COM_Call6 = CallWindowProcW(g_thunk6, 0, 0, VarPtr(args), 0)
End Function

Private Function COM_Call7(ByVal pObj As LongPtr, ByVal vtIndex As Long, ByVal a2 As LongPtr, ByVal a3 As LongPtr, ByVal a4 As LongPtr, ByVal a5 As LongPtr, ByVal a6 As LongPtr, ByVal a7 As LongPtr) As LongPtr
    SetThunkTarget g_thunk7, THUNK7_TARGET_OFFSET, GetVTableMethod(pObj, vtIndex)
    Dim args As ThunkArgs7: args.a1 = pObj: args.a2 = a2: args.a3 = a3: args.a4 = a4: args.a5 = a5: args.a6 = a6: args.a7 = a7
    COM_Call7 = CallWindowProcW(g_thunk7, 0, 0, VarPtr(args), 0)
End Function

Private Sub COM_Release(ByVal pObj As LongPtr)
    If pObj <> 0 Then COM_Call1 pObj, ONVTBL_IUnknown_Release
End Sub

Private Sub COM_GetCPUDescriptorHandle(ByVal pHeap As LongPtr, ByRef outHandle As D3D12_CPU_DESCRIPTOR_HANDLE)
    SetThunkTarget g_thunkRetStruct, THUNK_RETSTRUCT_TARGET_OFFSET, GetVTableMethod(pHeap, VTBL_DescHeap_GetCPUDescriptorHandleForHeapStart)
    Dim args As ThunkArgs2: args.a1 = pHeap: args.a2 = VarPtr(outHandle)
    CallWindowProcW g_thunkRetStruct, 0, 0, VarPtr(args), 0
End Sub

Private Sub COM_GetGPUDescriptorHandle(ByVal pHeap As LongPtr, ByRef outHandle As D3D12_GPU_DESCRIPTOR_HANDLE)
    SetThunkTarget g_thunkRetStructGPU, THUNK_RETSTRUCT_TARGET_OFFSET, GetVTableMethod(pHeap, VTBL_DescHeap_GetGPUDescriptorHandleForHeapStart)
    Dim args As ThunkArgs2: args.a1 = pHeap: args.a2 = VarPtr(outHandle)
    CallWindowProcW g_thunkRetStructGPU, 0, 0, VarPtr(args), 0
End Sub

Private Function ToHResult(ByVal v As LongPtr) As Long
    If v >= 0 And v <= &H7FFFFFFF Then ToHResult = CLng(v) Else Dim lo As Long: CopyMemory VarPtr(lo), VarPtr(v), 4: ToHResult = lo
End Function

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
    SetThunkTarget g_thunk9, THUNK9_TARGET_OFFSET, pD3DCompileFromFile
    Dim entryBytes() As Byte: entryBytes = AnsiZBytes(entryPoint)
    Dim profileBytes() As Byte: profileBytes = AnsiZBytes(profile)
    Dim pBlob As LongPtr, pErrorBlob As LongPtr
    Dim args9 As ThunkArgs9
    args9.a1 = StrPtr(filePath): args9.a2 = 0: args9.a3 = 0: args9.a4 = VarPtr(entryBytes(0)): args9.a5 = VarPtr(profileBytes(0))
    args9.a6 = 0: args9.a7 = 0: args9.a8 = VarPtr(pBlob): args9.a9 = VarPtr(pErrorBlob)
    Dim hr As Long: hr = ToHResult(CallWindowProcW(g_thunk9, 0, 0, VarPtr(args9), 0))
    If hr < 0 Then
        If pErrorBlob <> 0 Then LogMsg "Shader error: " & PtrToAnsiString(COM_Call1(pErrorBlob, VTBL_Blob_GetBufferPointer)): COM_Release pErrorBlob
        FreeLibrary hCompiler: Err.Raise vbObjectError + 8102
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
        Case WM_CLOSE: DestroyWindow hWnd: WindowProc = 0: Exit Function
        Case WM_DESTROY: PostQuitMessage 0: WindowProc = 0: Exit Function
    End Select
    WindowProc = DefWindowProcW(hWnd, uMsg, wParam, lParam)
End Function

' ============================================================
' Initialize DirectX 12 with per-frame command allocators
' ============================================================
Private Function InitD3D12(ByVal hWnd As LongPtr) As Boolean
    LogMsg "InitD3D12: start (pipelined)"
    Dim hr As Long
    
    Dim pFactory As LongPtr
    Dim factoryIID As GUID: factoryIID = IID_IDXGIFactory1()
    hr = CreateDXGIFactory1(factoryIID, pFactory)
    If hr < 0 Or pFactory = 0 Then InitD3D12 = False: Exit Function
    
    Dim deviceIID As GUID: deviceIID = IID_ID3D12Device()
    hr = D3D12CreateDevice(0, D3D_FEATURE_LEVEL_12_0, deviceIID, g_pDevice)
    If hr < 0 Or g_pDevice = 0 Then COM_Release pFactory: InitD3D12 = False: Exit Function
    
    Dim queueDesc As D3D12_COMMAND_QUEUE_DESC: queueDesc.cType = D3D12_COMMAND_LIST_TYPE_DIRECT
    Dim queueIID As GUID: queueIID = IID_ID3D12CommandQueue()
    hr = ToHResult(COM_Call4(g_pDevice, VTBL_Device_CreateCommandQueue, VarPtr(queueDesc), VarPtr(queueIID), VarPtr(g_pCommandQueue)))
    If hr < 0 Or g_pCommandQueue = 0 Then COM_Release pFactory: InitD3D12 = False: Exit Function
    
    Dim swapChainDesc As DXGI_SWAP_CHAIN_DESC
    swapChainDesc.BufferDesc.Width = Width: swapChainDesc.BufferDesc.Height = Height
    swapChainDesc.BufferDesc.Format = DXGI_FORMAT_R8G8B8A8_UNORM
    swapChainDesc.SampleDesc.Count = 1: swapChainDesc.BufferUsage = DXGI_USAGE_RENDER_TARGET_OUTPUT
    swapChainDesc.BufferCount = FRAME_COUNT: swapChainDesc.OutputWindow = hWnd
    swapChainDesc.Windowed = 1: swapChainDesc.SwapEffect = DXGI_SWAP_EFFECT_FLIP_DISCARD
    
    hr = ToHResult(COM_Call4(pFactory, VTBL_Factory_CreateSwapChain, g_pCommandQueue, VarPtr(swapChainDesc), VarPtr(g_pSwapChain)))
    If hr < 0 Or g_pSwapChain = 0 Then COM_Release pFactory: InitD3D12 = False: Exit Function
    
    Dim swapChain3IID As GUID: swapChain3IID = IID_IDXGISwapChain3()
    hr = ToHResult(COM_Call3(g_pSwapChain, ONVTBL_IUnknown_QueryInterface, VarPtr(swapChain3IID), VarPtr(g_pSwapChain3)))
    If hr < 0 Or g_pSwapChain3 = 0 Then COM_Release pFactory: InitD3D12 = False: Exit Function
    
    g_frameIndex = CLng(COM_Call1(g_pSwapChain3, VTBL_SwapChain3_GetCurrentBackBufferIndex))
    
    Dim rtvHeapDesc As D3D12_DESCRIPTOR_HEAP_DESC
    rtvHeapDesc.cType = D3D12_DESCRIPTOR_HEAP_TYPE_RTV: rtvHeapDesc.NumDescriptors = FRAME_COUNT
    Dim heapIID As GUID: heapIID = IID_ID3D12DescriptorHeap()
    hr = ToHResult(COM_Call4(g_pDevice, VTBL_Device_CreateDescriptorHeap, VarPtr(rtvHeapDesc), VarPtr(heapIID), VarPtr(g_pRtvHeap)))
    If hr < 0 Then COM_Release pFactory: InitD3D12 = False: Exit Function
    
    g_rtvDescriptorSize = CLng(COM_Call2(g_pDevice, VTBL_Device_GetDescriptorHandleIncrementSize, D3D12_DESCRIPTOR_HEAP_TYPE_RTV))
    
    Dim cbvHeapDesc As D3D12_DESCRIPTOR_HEAP_DESC
    cbvHeapDesc.cType = D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV
    '(cbvHeapDesc.NumDescriptors = 1
    cbvHeapDesc.NumDescriptors = FRAME_COUNT
    cbvHeapDesc.Flags = D3D12_DESCRIPTOR_HEAP_FLAG_SHADER_VISIBLE
    hr = ToHResult(COM_Call4(g_pDevice, VTBL_Device_CreateDescriptorHeap, VarPtr(cbvHeapDesc), VarPtr(heapIID), VarPtr(g_pCbvHeap)))
    If hr < 0 Then COM_Release pFactory: InitD3D12 = False: Exit Function
    
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
    
    ' *** KEY CHANGE: Create per-frame command allocators ***
    Dim allocIID As GUID: allocIID = IID_ID3D12CommandAllocator()
    For frameIdx = 0 To FRAME_COUNT - 1
        hr = ToHResult(COM_Call4(g_pDevice, VTBL_Device_CreateCommandAllocator, D3D12_COMMAND_LIST_TYPE_DIRECT, VarPtr(allocIID), VarPtr(g_pCommandAllocators(frameIdx))))
        If hr < 0 Or g_pCommandAllocators(frameIdx) = 0 Then
            LogMsg "Failed to create command allocator " & frameIdx
            COM_Release pFactory: InitD3D12 = False: Exit Function
        End If
        g_frameFenceValues(frameIdx) = 0
    Next frameIdx
    LogMsg "Created " & FRAME_COUNT & " command allocators"
    
    COM_Release pFactory
    InitD3D12 = True
    LogMsg "InitD3D12: done"
End Function

Private Function CreateRootSignature() As Boolean
    Dim cbvRange As D3D12_DESCRIPTOR_RANGE
    cbvRange.RangeType = D3D12_DESCRIPTOR_RANGE_TYPE_CBV: cbvRange.NumDescriptors = 1
    cbvRange.OffsetInDescriptorsFromTableStart = D3D12_DESCRIPTOR_RANGE_OFFSET_APPEND
    
    Dim rootParam As D3D12_ROOT_PARAMETER
    rootParam.ParameterType = D3D12_ROOT_PARAMETER_TYPE_DESCRIPTOR_TABLE
    rootParam.DescriptorTable.NumDescriptorRanges = 1
    rootParam.DescriptorTable.pDescriptorRanges = VarPtr(cbvRange)
    rootParam.ShaderVisibility = D3D12_SHADER_VISIBILITY_PIXEL
    
    Dim rootSigDesc As D3D12_ROOT_SIGNATURE_DESC
    rootSigDesc.NumParameters = 1: rootSigDesc.pParameters = VarPtr(rootParam)
    rootSigDesc.Flags = D3D12_ROOT_SIGNATURE_FLAG_ALLOW_INPUT_ASSEMBLER_INPUT_LAYOUT
    
    Dim pSignatureBlob As LongPtr, pErrorBlob As LongPtr
    Dim hr As Long: hr = D3D12SerializeRootSignature(rootSigDesc, D3D_ROOT_SIGNATURE_VERSION_1, pSignatureBlob, pErrorBlob)
    If hr < 0 Then CreateRootSignature = False: Exit Function
    
    Dim rootSigIID As GUID: rootSigIID = IID_ID3D12RootSignature()
    hr = ToHResult(COM_Call6(g_pDevice, VTBL_Device_CreateRootSignature, 0, COM_Call1(pSignatureBlob, VTBL_Blob_GetBufferPointer), COM_Call1(pSignatureBlob, VTBL_Blob_GetBufferSize), VarPtr(rootSigIID), VarPtr(g_pRootSignature)))
    COM_Release pSignatureBlob
    CreateRootSignature = (hr >= 0 And g_pRootSignature <> 0)
End Function

Private Function CreatePipelineState(ByVal shaderPath As String) As Boolean
    Dim pVSBlob As LongPtr: pVSBlob = CompileShaderFromFile(shaderPath, "VSMain", "vs_5_0")
    If pVSBlob = 0 Then CreatePipelineState = False: Exit Function
    Dim pPSBlob As LongPtr: pPSBlob = CompileShaderFromFile(shaderPath, "PSMain", "ps_5_0")
    If pPSBlob = 0 Then COM_Release pVSBlob: CreatePipelineState = False: Exit Function
    
    g_semanticPosition = AnsiZBytes("POSITION")
    Dim inputElements(0 To 0) As D3D12_INPUT_ELEMENT_DESC
    inputElements(0).SemanticName = VarPtr(g_semanticPosition(0))
    inputElements(0).Format = DXGI_FORMAT_R32G32_FLOAT
    
    Dim psoDesc As D3D12_GRAPHICS_PIPELINE_STATE_DESC
    psoDesc.pRootSignature = g_pRootSignature
    psoDesc.VS.pShaderBytecode = COM_Call1(pVSBlob, VTBL_Blob_GetBufferPointer)
    psoDesc.VS.BytecodeLength = COM_Call1(pVSBlob, VTBL_Blob_GetBufferSize)
    psoDesc.PS.pShaderBytecode = COM_Call1(pPSBlob, VTBL_Blob_GetBufferPointer)
    psoDesc.PS.BytecodeLength = COM_Call1(pPSBlob, VTBL_Blob_GetBufferSize)
    psoDesc.BlendState.RenderTarget(0).SrcBlend = D3D12_BLEND_ONE
    psoDesc.BlendState.RenderTarget(0).DestBlend = D3D12_BLEND_ZERO
    psoDesc.BlendState.RenderTarget(0).BlendOp = D3D12_BLEND_OP_ADD
    psoDesc.BlendState.RenderTarget(0).SrcBlendAlpha = D3D12_BLEND_ONE
    psoDesc.BlendState.RenderTarget(0).DestBlendAlpha = D3D12_BLEND_ZERO
    psoDesc.BlendState.RenderTarget(0).BlendOpAlpha = D3D12_BLEND_OP_ADD
    psoDesc.BlendState.RenderTarget(0).LogicOp = D3D12_LOGIC_OP_NOOP
    psoDesc.BlendState.RenderTarget(0).RenderTargetWriteMask = D3D12_COLOR_WRITE_ENABLE_ALL
    psoDesc.SampleMask = &HFFFFFFFF
    psoDesc.RasterizerState.FillMode = D3D12_FILL_MODE_SOLID
    psoDesc.RasterizerState.CullMode = D3D12_CULL_MODE_NONE
    psoDesc.RasterizerState.DepthClipEnable = 1
    psoDesc.InputLayout.pInputElementDescs = VarPtr(inputElements(0))
    psoDesc.InputLayout.NumElements = 1
    psoDesc.PrimitiveTopologyType = D3D12_PRIMITIVE_TOPOLOGY_TYPE_TRIANGLE
    psoDesc.NumRenderTargets = 1
    psoDesc.RTVFormats(0) = DXGI_FORMAT_R8G8B8A8_UNORM
    psoDesc.SampleDesc.Count = 1
    
    Dim psoIID As GUID: psoIID = IID_ID3D12PipelineState()
    Dim hr As Long: hr = ToHResult(COM_Call4(g_pDevice, VTBL_Device_CreateGraphicsPipelineState, VarPtr(psoDesc), VarPtr(psoIID), VarPtr(g_pPipelineState)))
    COM_Release pVSBlob: COM_Release pPSBlob
    CreatePipelineState = (hr >= 0 And g_pPipelineState <> 0)
End Function

Private Function CreateFrameCommandLists() As Boolean
    ' Create one direct command list per swapchain buffer (frame).
    ' We will record each list once at init and reuse it every frame.
    Dim cmdListIID As GUID: cmdListIID = IID_ID3D12GraphicsCommandList()
    Dim hr As Long
    Dim frameIdx As Long

    For frameIdx = 0 To FRAME_COUNT - 1
        hr = ToHResult(COM_Call7(g_pDevice, VTBL_Device_CreateCommandList, 0, D3D12_COMMAND_LIST_TYPE_DIRECT, g_pCommandAllocators(frameIdx), g_pPipelineState, VarPtr(cmdListIID), VarPtr(g_pFrameCommandLists(frameIdx))))
        If hr < 0 Or g_pFrameCommandLists(frameIdx) = 0 Then
            LogMsg "Failed to create command list " & frameIdx & " hr=" & Hex$(hr)
            CreateFrameCommandLists = False
            Exit Function
        End If

        ' Close for now; will be Reset+recorded once after all resources are ready.
        COM_Call1 g_pFrameCommandLists(frameIdx), VTBL_CmdList_Close
    Next frameIdx

    CreateFrameCommandLists = True
End Function


Private Function CreateVertexBuffer() As Boolean
    Dim vertices(0 To 5) As VERTEX
    vertices(0).x = -1!: vertices(0).y = 1!
    vertices(1).x = 1!: vertices(1).y = -1!
    vertices(2).x = -1!: vertices(2).y = -1!
    vertices(3).x = -1!: vertices(3).y = 1!
    vertices(4).x = 1!: vertices(4).y = 1!
    vertices(5).x = 1!: vertices(5).y = -1!
    
    Dim bufferSize As LongLong: bufferSize = CLngLng(LenB(vertices(0))) * 6
    Dim heapProps As D3D12_HEAP_PROPERTIES: heapProps.cType = D3D12_HEAP_TYPE_UPLOAD: heapProps.CreationNodeMask = 1: heapProps.VisibleNodeMask = 1
    Dim resourceDesc As D3D12_RESOURCE_DESC
    resourceDesc.Dimension = D3D12_RESOURCE_DIMENSION_BUFFER: resourceDesc.Width = bufferSize: resourceDesc.Height = 1
    resourceDesc.DepthOrArraySize = 1: resourceDesc.MipLevels = 1: resourceDesc.SampleDesc.Count = 1: resourceDesc.Layout = 1
    
    Dim resourceIID As GUID: resourceIID = IID_ID3D12Resource()
    SetThunkTarget g_thunk8, THUNK8_TARGET_OFFSET, GetVTableMethod(g_pDevice, VTBL_Device_CreateCommittedResource)
    Dim args8 As ThunkArgs8
    args8.a1 = g_pDevice: args8.a2 = VarPtr(heapProps): args8.a3 = D3D12_HEAP_FLAG_NONE: args8.a4 = VarPtr(resourceDesc)
    args8.a5 = D3D12_RESOURCE_STATE_GENERIC_READ: args8.a6 = 0: args8.a7 = VarPtr(resourceIID): args8.a8 = VarPtr(g_pVertexBuffer)
    Dim hr As Long: hr = ToHResult(CallWindowProcW(g_thunk8, 0, 0, VarPtr(args8), 0))
    If hr < 0 Or g_pVertexBuffer = 0 Then CreateVertexBuffer = False: Exit Function
    
    Dim pData As LongPtr: hr = ToHResult(COM_Call4(g_pVertexBuffer, VTBL_Resource_Map, 0, 0, VarPtr(pData)))
    If hr >= 0 And pData <> 0 Then CopyMemory pData, VarPtr(vertices(0)), CLngPtr(bufferSize): COM_Call3 g_pVertexBuffer, VTBL_Resource_Unmap, 0, 0
    
    g_vertexBufferView.BufferLocation = COM_Call1(g_pVertexBuffer, VTBL_Resource_GetGPUVirtualAddress)
    g_vertexBufferView.SizeInBytes = CLng(bufferSize)
    g_vertexBufferView.StrideInBytes = LenB(vertices(0))
    CreateVertexBuffer = True
End Function

Private Function CreateConstantBuffer() As Boolean
    Dim cbSize As LongLong: cbSize = 256
    Dim heapProps As D3D12_HEAP_PROPERTIES
    heapProps.cType = D3D12_HEAP_TYPE_UPLOAD
    heapProps.CreationNodeMask = 1
    heapProps.VisibleNodeMask = 1
    
    Dim resourceDesc As D3D12_RESOURCE_DESC
    resourceDesc.Dimension = D3D12_RESOURCE_DIMENSION_BUFFER
    resourceDesc.Width = cbSize
    resourceDesc.Height = 1
    resourceDesc.DepthOrArraySize = 1
    resourceDesc.MipLevels = 1
    resourceDesc.SampleDesc.Count = 1
    resourceDesc.Layout = 1
    
    Dim resourceIID As GUID: resourceIID = IID_ID3D12Resource()
    Dim cbvHandle As D3D12_CPU_DESCRIPTOR_HANDLE
    COM_GetCPUDescriptorHandle g_pCbvHeap, cbvHandle
    
    g_cbvDescriptorSize = CLng(COM_Call2(g_pDevice, VTBL_Device_GetDescriptorHandleIncrementSize, D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV))
    
    Dim frameIdx As Long
    For frameIdx = 0 To FRAME_COUNT - 1
        SetThunkTarget g_thunk8, THUNK8_TARGET_OFFSET, GetVTableMethod(g_pDevice, VTBL_Device_CreateCommittedResource)
        Dim args8 As ThunkArgs8
        args8.a1 = g_pDevice
        args8.a2 = VarPtr(heapProps)
        args8.a3 = D3D12_HEAP_FLAG_NONE
        args8.a4 = VarPtr(resourceDesc)
        args8.a5 = D3D12_RESOURCE_STATE_GENERIC_READ
        args8.a6 = 0
        args8.a7 = VarPtr(resourceIID)
        args8.a8 = VarPtr(g_pConstantBuffers(frameIdx))
        
        Dim hr As Long: hr = ToHResult(CallWindowProcW(g_thunk8, 0, 0, VarPtr(args8), 0))
        If hr < 0 Or g_pConstantBuffers(frameIdx) = 0 Then
            CreateConstantBuffer = False: Exit Function
        End If
        
        hr = ToHResult(COM_Call4(g_pConstantBuffers(frameIdx), VTBL_Resource_Map, 0, 0, VarPtr(g_constantBufferDataBegins(frameIdx))))
        If hr < 0 Then CreateConstantBuffer = False: Exit Function
        
        Dim cbvDesc As D3D12_CONSTANT_BUFFER_VIEW_DESC
        cbvDesc.BufferLocation = COM_Call1(g_pConstantBuffers(frameIdx), VTBL_Resource_GetGPUVirtualAddress)
        cbvDesc.SizeInBytes = CLng(cbSize)
        
        COM_Call3 g_pDevice, VTBL_Device_CreateConstantBufferView, VarPtr(cbvDesc), cbvHandle.ptr
        cbvHandle.ptr = cbvHandle.ptr + g_cbvDescriptorSize
    Next frameIdx
    
    CreateConstantBuffer = True
End Function

Private Function CreateFence() As Boolean
    Dim fenceIID As GUID: fenceIID = IID_ID3D12Fence()
    Dim hr As Long: hr = ToHResult(COM_Call5(g_pDevice, VTBL_Device_CreateFence, 0, D3D12_FENCE_FLAG_NONE, VarPtr(fenceIID), VarPtr(g_pFence)))
    If hr < 0 Or g_pFence = 0 Then CreateFence = False: Exit Function
    g_currentFenceValue = 1
    g_fenceEvent = CreateEventW(0, 0, 0, 0)
    CreateFence = (g_fenceEvent <> 0)
End Function

' UINT64を正しく取得するための専用サンク
Private Function GetFenceCompletedValue(ByVal pFence As LongPtr) As LongLong
    ' GetCompletedValueはUINT64を返す - RAXレジスタから直接取得
    Dim result As LongLong
    SetThunkTarget g_thunk1, THUNK1_TARGET_OFFSET, GetVTableMethod(pFence, VTBL_Fence_GetCompletedValue)
    Dim args As ThunkArgs1: args.a1 = pFence
    
    ' 戻り値を直接LongLongとして受け取る
    Dim retVal As LongPtr
    retVal = CallWindowProcW(g_thunk1, 0, 0, VarPtr(args), 0)
    CopyMemory VarPtr(result), VarPtr(retVal), 8
    GetFenceCompletedValue = result
End Function

' ============================================================
' *** KEY CHANGE: Wait only for the specific frame's resources ***
' This allows pipelining - we only wait when we need to reuse resources
' ============================================================
'
' ============================================================
' Record per-frame command lists ONCE (no per-frame recording).
' This is the single biggest performance lever for VBA + DX12:
' it collapses hundreds of COM/vtbl calls per frame to ~0.
' ============================================================
Private Sub RecordAllFrameCommandListsOnce()
    Dim frameIdx As Long
    For frameIdx = 0 To FRAME_COUNT - 1
        RecordCommandListForFrame frameIdx
    Next frameIdx
End Sub

Private Sub RecordCommandListForFrame(ByVal frameIdx As Long)
    Dim pCmd As LongPtr: pCmd = g_pFrameCommandLists(frameIdx)
    If pCmd = 0 Then Exit Sub

    ' Reset allocator/list ONCE (at init only)
    COM_Call1 g_pCommandAllocators(frameIdx), VTBL_CmdAlloc_Reset
    COM_Call3 pCmd, VTBL_CmdList_Reset, g_pCommandAllocators(frameIdx), g_pPipelineState

    ' Root signature + heaps
    COM_Call2 pCmd, VTBL_CmdList_SetGraphicsRootSignature, g_pRootSignature
    Dim ppHeaps As LongPtr: ppHeaps = g_pCbvHeap
    COM_Call3 pCmd, VTBL_CmdList_SetDescriptorHeaps, 1, VarPtr(ppHeaps)

    ' Frame-specific CBV descriptor (baked into the command list)
    Dim gpuHandle As D3D12_GPU_DESCRIPTOR_HANDLE
    COM_GetGPUDescriptorHandle g_pCbvHeap, gpuHandle
    gpuHandle.ptr = gpuHandle.ptr + CLngLng(frameIdx) * CLngLng(g_cbvDescriptorSize)
    COM_Call3 pCmd, VTBL_CmdList_SetGraphicsRootDescriptorTable, 0, CLngPtr(gpuHandle.ptr)

    ' Viewport / scissor (fixed size in this sample)
    Dim vp As D3D12_VIEWPORT: vp.Width = CSng(Width): vp.Height = CSng(Height): vp.MaxDepth = 1!
    COM_Call3 pCmd, VTBL_CmdList_RSSetViewports, 1, VarPtr(vp)
    Dim sr As D3D12_RECT: sr.Right = Width: sr.Bottom = Height
    COM_Call3 pCmd, VTBL_CmdList_RSSetScissorRects, 1, VarPtr(sr)

    ' PRESENT -> RT
    Dim barrierToRT As D3D12_RESOURCE_BARRIER
    barrierToRT.cType = D3D12_RESOURCE_BARRIER_TYPE_TRANSITION
    barrierToRT.Transition.pResource = g_pRenderTargets(frameIdx)
    barrierToRT.Transition.Subresource = D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES
    barrierToRT.Transition.StateBefore = D3D12_RESOURCE_STATE_PRESENT
    barrierToRT.Transition.StateAfter = D3D12_RESOURCE_STATE_RENDER_TARGET
    COM_Call3 pCmd, VTBL_CmdList_ResourceBarrier, 1, VarPtr(barrierToRT)

    ' RTV handle for this backbuffer
    Dim rtvHandle As D3D12_CPU_DESCRIPTOR_HANDLE
    COM_GetCPUDescriptorHandle g_pRtvHeap, rtvHandle
    rtvHandle.ptr = rtvHandle.ptr + CLngPtr(frameIdx) * CLngPtr(g_rtvDescriptorSize)

    ' Clear + draw fullscreen triangle (raymarch in PS)
    Dim clearColor(0 To 3) As Single: clearColor(3) = 1!
    COM_Call5 pCmd, VTBL_CmdList_ClearRenderTargetView, rtvHandle.ptr, VarPtr(clearColor(0)), 0, 0
    COM_Call5 pCmd, VTBL_CmdList_OMSetRenderTargets, 1, VarPtr(rtvHandle), 1, 0

    COM_Call2 pCmd, VTBL_CmdList_IASetPrimitiveTopology, D3D_PRIMITIVE_TOPOLOGY_TRIANGLELIST
    COM_Call4 pCmd, VTBL_CmdList_IASetVertexBuffers, 0, 1, VarPtr(g_vertexBufferView)
    COM_Call5 pCmd, VTBL_CmdList_DrawInstanced, 6, 1, 0, 0

    ' RT -> PRESENT
    Dim barrierToPresent As D3D12_RESOURCE_BARRIER
    barrierToPresent.cType = D3D12_RESOURCE_BARRIER_TYPE_TRANSITION
    barrierToPresent.Transition.pResource = g_pRenderTargets(frameIdx)
    barrierToPresent.Transition.Subresource = D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES
    barrierToPresent.Transition.StateBefore = D3D12_RESOURCE_STATE_RENDER_TARGET
    barrierToPresent.Transition.StateAfter = D3D12_RESOURCE_STATE_PRESENT
    COM_Call3 pCmd, VTBL_CmdList_ResourceBarrier, 1, VarPtr(barrierToPresent)

    COM_Call1 pCmd, VTBL_CmdList_Close
End Sub

'Private Sub WaitForFrame(ByVal frameIdx As Long)
'    Dim fenceValue As LongLong
'    fenceValue = g_frameFenceValues(frameIdx)
'
'    ' Only wait if GPU hasn't completed this frame yet
'    If fenceValue <> 0 Then
'        Dim completed As LongLong
'        completed = COM_Call1(g_pFence, VTBL_Fence_GetCompletedValue)
'
'        If completed < fenceValue Then
'            COM_Call3 g_pFence, VTBL_Fence_SetEventOnCompletion, CLngPtr(fenceValue), g_fenceEvent
'            'WaitForSingleObject g_fenceEvent, INFINITE
'        End If
'    End If
'End Sub


Private Sub WaitForFrame(ByVal frameIdx As Long)
    Dim fenceValue As LongLong
    fenceValue = g_frameFenceValues(frameIdx)
    
    If fenceValue = 0 Then Exit Sub  ' 初回は待機不要
    
    Dim completed As LongLong
    completed = GetFenceCompletedValue(g_pFence)
    
    ' 既に完了していれば待機しない
    If completed >= fenceValue Then Exit Sub
    
    ' タイムアウト付き待機（無限待機を避ける）
    COM_Call3 g_pFence, VTBL_Fence_SetEventOnCompletion, CLngPtr(fenceValue), g_fenceEvent
    Dim waitResult As Long
    waitResult = WaitForSingleObject(g_fenceEvent, 100)  ' 100ms timeout
    
    If waitResult <> WAIT_OBJECT_0 Then
        LogMsg "WaitForFrame: timeout or error for frame " & frameIdx
    End If
End Sub

' ============================================================
' Render frame with pipelining
' ============================================================
Private Sub RenderFrame()
    ProfilerBeginFrame

    g_frameIndex = CLng(COM_Call1(g_pSwapChain3, VTBL_SwapChain3_GetCurrentBackBufferIndex))

    WaitForFrame g_frameIndex
    ProfilerMark PROF_WAIT

    ' Frame-specific constant buffer update (persistently mapped)
    Dim cbData As CONSTANT_BUFFER_DATA
    cbData.iTime = CSng(GetTime() - g_startTime)
    cbData.iResolutionX = CSng(Width)
    cbData.iResolutionY = CSng(Height)
    CopyMemory g_constantBufferDataBegins(g_frameIndex), VarPtr(cbData), CLngPtr(LenB(cbData))
    ProfilerMark PROF_UPDATE

    ' No per-frame Reset/Record anymore
    ProfilerMark PROF_RESET
    ProfilerMark PROF_RECORD

    ' Execute pre-recorded command list for this backbuffer
    Dim pCmd As LongPtr: pCmd = g_pFrameCommandLists(g_frameIndex)
    Dim ppCommandLists As LongPtr: ppCommandLists = pCmd
    COM_Call3 g_pCommandQueue, VTBL_CmdQueue_ExecuteCommandLists, 1, VarPtr(ppCommandLists)
    ProfilerMark PROF_EXECUTE

    g_frameFenceValues(g_frameIndex) = g_currentFenceValue
    COM_Call3 g_pCommandQueue, VTBL_CmdQueue_Signal, g_pFence, CLngPtr(g_currentFenceValue)
    ProfilerMark PROF_SIGNAL
    g_currentFenceValue = g_currentFenceValue + 1

    COM_Call3 g_pSwapChain, VTBL_SwapChain_Present, 0, 0
    ProfilerMark PROF_PRESENT

    ProfilerEndFrame
End Sub


' ============================================================
' Wait for all GPU work to complete (for cleanup)
' ============================================================
Private Sub WaitForAllFrames()
    Dim i As Long
    For i = 0 To FRAME_COUNT - 1
        WaitForFrame i
    Next i
End Sub

' ============================================================
' Cleanup
' ============================================================
Private Sub CleanupD3D12()
    LogMsg "CleanupD3D12: start"
    WaitForAllFrames
    
    If g_fenceEvent <> 0 Then CloseHandle g_fenceEvent: g_fenceEvent = 0
    'If g_pConstantBuffer <> 0 Then COM_Release g_pConstantBuffer: g_pConstantBuffer = 0
    If g_pVertexBuffer <> 0 Then COM_Release g_pVertexBuffer: g_pVertexBuffer = 0
    If g_pFence <> 0 Then COM_Release g_pFence: g_pFence = 0
    Dim frameIdx As Long
    For frameIdx = 0 To FRAME_COUNT - 1
        If g_pFrameCommandLists(frameIdx) <> 0 Then COM_Release g_pFrameCommandLists(frameIdx): g_pFrameCommandLists(frameIdx) = 0
    Next frameIdx
    If g_pCommandList <> 0 Then COM_Release g_pCommandList: g_pCommandList = 0
    If g_pPipelineState <> 0 Then COM_Release g_pPipelineState: g_pPipelineState = 0
    If g_pRootSignature <> 0 Then COM_Release g_pRootSignature: g_pRootSignature = 0
    
    Dim i As Long
    For i = 0 To FRAME_COUNT - 1
        If g_pConstantBuffers(i) <> 0 Then COM_Release g_pConstantBuffers(i): g_pConstantBuffers(i) = 0
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
    LogMsg "Main: start (PIPELINED VERSION)"
    
    InitThunks
    
    Dim shaderPath As String: shaderPath = ThisWorkbook.Path & "\hello.hlsl"
    LogMsg "Shader path: " & shaderPath

    Dim wcex As WNDCLASSEXW
    Dim hInstance As LongPtr: hInstance = GetModuleHandleW(0)
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
    If Not CreateRootSignature() Then MsgBox "Failed to create root signature.", vbCritical: GoTo FIN
    If Not CreatePipelineState(shaderPath) Then MsgBox "Failed to create pipeline state.", vbCritical: GoTo FIN
    If Not CreateFrameCommandLists() Then MsgBox "Failed to create command lists.", vbCritical: GoTo FIN
    If Not CreateVertexBuffer() Then MsgBox "Failed to create vertex buffer.", vbCritical: GoTo FIN
    If Not CreateConstantBuffer() Then MsgBox "Failed to create constant buffer.", vbCritical: GoTo FIN
    If Not CreateFence() Then MsgBox "Failed to create fence.", vbCritical: GoTo FIN

    ' Record command lists once (per backbuffer)
    RecordAllFrameCommandListsOnce

    g_startTime = GetTime()

    ' ---- Profiler (CPU-side timing) ----
    ProfilerInit
    ProfilerReset


    Dim msg As MSGW
    Dim quit As Boolean: quit = False
    Dim frame As Long: frame = 0

    LogMsg "Loop: start"
    Do While Not quit
        If PeekMessageW(msg, 0, 0, 0, PM_REMOVE) <> 0 Then
            If msg.message = WM_QUIT Then quit = True Else TranslateMessage msg: DispatchMessageW msg
        Else
            RenderFrame
            frame = frame + 1
            Sleep 1
            
            If (frame Mod 60) = 0 Then DoEvents
        End If
    Loop

FIN:
    ' ---- Profiler flush ----
    ProfilerFlush
    LogMsg "Cleanup: start"
    CleanupD3D12
    FreeThunks
    If g_hWnd <> 0 Then DestroyWindow g_hWnd
    g_hWnd = 0
    LogMsg "Main: end"
    LogClose
    Exit Sub

EH:
    LogMsg "ERROR: " & Err.Number & " / " & Err.Description
    Resume FIN
End Sub
