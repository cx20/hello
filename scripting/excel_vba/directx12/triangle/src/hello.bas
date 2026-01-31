Attribute VB_Name = "hello"
Option Explicit

' ============================================================
'  Excel VBA (64-bit) + DirectX 12 - Triangle Rendering
'   - Creates a Win32 window
'   - Creates D3D12 Device, CommandQueue, SwapChain
'   - Creates RootSignature, PipelineState
'   - Manages GPU synchronization with Fence
'   - Renders a colored triangle
'   - Debug log: C:\TEMP\dx12_debug.log
'
'  Based on DirectX 11 VBA sample with extended thunks.
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
Private Const DXGI_FORMAT_R32G32B32_FLOAT As Long = 6
Private Const DXGI_FORMAT_R32G32B32A32_FLOAT As Long = 2
Private Const DXGI_FORMAT_UNKNOWN As Long = 0

Private Const DXGI_USAGE_RENDER_TARGET_OUTPUT As Long = &H20&
Private Const DXGI_SWAP_EFFECT_FLIP_DISCARD As Long = 4

Private Const D3D12_COMMAND_LIST_TYPE_DIRECT As Long = 0
Private Const D3D12_COMMAND_QUEUE_FLAG_NONE As Long = 0

Private Const D3D12_DESCRIPTOR_HEAP_TYPE_RTV As Long = 2
Private Const D3D12_DESCRIPTOR_HEAP_FLAG_NONE As Long = 0

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
Private Const D3D12_CULL_MODE_BACK As Long = 3
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

Private Const FRAME_COUNT As Long = 2
Private Const WIDTH As Long = 640
Private Const HEIGHT As Long = 480

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
Private Const VTBL_Device_CreateRenderTargetView As Long = 20
Private Const VTBL_Device_CreateCommittedResource As Long = 27
Private Const VTBL_Device_CreateFence As Long = 36

' ID3D12DescriptorHeap
Private Const VTBL_DescHeap_GetCPUDescriptorHandleForHeapStart As Long = 9

' ID3D12GraphicsCommandList
Private Const VTBL_CmdList_Close As Long = 9
Private Const VTBL_CmdList_Reset As Long = 10
Private Const VTBL_CmdList_DrawInstanced As Long = 12
Private Const VTBL_CmdList_IASetPrimitiveTopology As Long = 20
Private Const VTBL_CmdList_RSSetViewports As Long = 21
Private Const VTBL_CmdList_RSSetScissorRects As Long = 22
Private Const VTBL_CmdList_SetPipelineState As Long = 25
Private Const VTBL_CmdList_ResourceBarrier As Long = 26
Private Const VTBL_CmdList_SetGraphicsRootSignature As Long = 30
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
Private Const CLASS_NAME As String = "helloDX12WindowVBA"
Private Const WINDOW_NAME As String = "Hello DirectX 12 (VBA64)"

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

' D3D12_GRAPHICS_PIPELINE_STATE_DESC - very large structure
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

Private Type VERTEX
    x As Single
    y As Single
    z As Single
    r As Single
    g As Single
    b As Single
    a As Single
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

Private Type ThunkArgs11
    a1 As LongPtr
    a2 As LongPtr
    a3 As LongPtr
    a4 As LongPtr
    a5 As LongPtr
    a6 As LongPtr
    a7 As LongPtr
    a8 As LongPtr
    a9 As LongPtr
    a10 As LongPtr
    a11 As LongPtr
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
Private g_pCommandAllocator As LongPtr
Private g_pCommandList As LongPtr
Private g_pRootSignature As LongPtr
Private g_pPipelineState As LongPtr
Private g_pFence As LongPtr
Private g_fenceEvent As LongPtr
Private g_fenceValue As LongLong
Private g_frameIndex As Long
Private g_rtvDescriptorSize As Long
Private g_pRenderTargets(0 To FRAME_COUNT - 1) As LongPtr
Private g_pVertexBuffer As LongPtr
Private g_vertexBufferView As D3D12_VERTEX_BUFFER_VIEW

' Semantic name strings (must persist)
Private g_semanticPosition() As Byte
Private g_semanticColor() As Byte

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

Private p_thunk1 As LongPtr
Private p_thunk2 As LongPtr
Private p_thunk3 As LongPtr
Private p_thunk4 As LongPtr
Private p_thunk5 As LongPtr
Private p_thunk6 As LongPtr
Private p_thunk7 As LongPtr
Private p_thunk8 As LongPtr
Private p_thunk11 As LongPtr
Private p_thunkRetStruct As LongPtr

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
    g_log = CreateFileW(StrPtr("C:\TEMP\dx12_debug.log"), GENERIC_WRITE, FILE_SHARE_READ Or FILE_SHARE_WRITE, 0, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, 0)
    If g_log = 0 Or g_log = -1 Then g_log = 0
    LogMsg "==== DX12 LOG START ===="
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

' ============================================================
' GUID helpers
' ============================================================
Private Function IID_IDXGIFactory1() As GUID
    ' {770aae78-f26f-4dba-a829-253c83d1b387}
    With IID_IDXGIFactory1
        .Data1 = &H770AAE78
        .Data2 = &HF26F
        .Data3 = &H4DBA
        .Data4(0) = &HA8
        .Data4(1) = &H29
        .Data4(2) = &H25
        .Data4(3) = &H3C
        .Data4(4) = &H83
        .Data4(5) = &HD1
        .Data4(6) = &HB3
        .Data4(7) = &H87
    End With
End Function

Private Function IID_ID3D12Device() As GUID
    ' {189819f1-1db6-4b57-be54-1821339b85f7}
    With IID_ID3D12Device
        .Data1 = &H189819F1
        .Data2 = &H1DB6
        .Data3 = &H4B57
        .Data4(0) = &HBE
        .Data4(1) = &H54
        .Data4(2) = &H18
        .Data4(3) = &H21
        .Data4(4) = &H33
        .Data4(5) = &H9B
        .Data4(6) = &H85
        .Data4(7) = &HF7
    End With
End Function

Private Function IID_ID3D12CommandQueue() As GUID
    ' {0ec870a6-5d7e-4c22-8cfc-5baae07616ed}
    With IID_ID3D12CommandQueue
        .Data1 = &HEC870A6
        .Data2 = &H5D7E
        .Data3 = &H4C22
        .Data4(0) = &H8C
        .Data4(1) = &HFC
        .Data4(2) = &H5B
        .Data4(3) = &HAA
        .Data4(4) = &HE0
        .Data4(5) = &H76
        .Data4(6) = &H16
        .Data4(7) = &HED
    End With
End Function

Private Function IID_ID3D12DescriptorHeap() As GUID
    ' {8efb471d-616c-4f49-90f7-127bb763fa51}
    With IID_ID3D12DescriptorHeap
        .Data1 = &H8EFB471D
        .Data2 = &H616C
        .Data3 = &H4F49
        .Data4(0) = &H90
        .Data4(1) = &HF7
        .Data4(2) = &H12
        .Data4(3) = &H7B
        .Data4(4) = &HB7
        .Data4(5) = &H63
        .Data4(6) = &HFA
        .Data4(7) = &H51
    End With
End Function

Private Function IID_ID3D12Resource() As GUID
    ' {696442be-a72e-4059-bc79-5b5c98040fad}
    With IID_ID3D12Resource
        .Data1 = &H696442BE
        .Data2 = &HA72E
        .Data3 = &H4059
        .Data4(0) = &HBC
        .Data4(1) = &H79
        .Data4(2) = &H5B
        .Data4(3) = &H5C
        .Data4(4) = &H98
        .Data4(5) = &H4
        .Data4(6) = &HF
        .Data4(7) = &HAD
    End With
End Function

Private Function IID_ID3D12CommandAllocator() As GUID
    ' {6102dee4-af59-4b09-b999-b44d73f09b24}
    With IID_ID3D12CommandAllocator
        .Data1 = &H6102DEE4
        .Data2 = &HAF59
        .Data3 = &H4B09
        .Data4(0) = &HB9
        .Data4(1) = &H99
        .Data4(2) = &HB4
        .Data4(3) = &H4D
        .Data4(4) = &H73
        .Data4(5) = &HF0
        .Data4(6) = &H9B
        .Data4(7) = &H24
    End With
End Function

Private Function IID_ID3D12RootSignature() As GUID
    ' {c54a6b66-72df-4ee8-8be5-a946a1429214}
    With IID_ID3D12RootSignature
        .Data1 = &HC54A6B66
        .Data2 = &H72DF
        .Data3 = &H4EE8
        .Data4(0) = &H8B
        .Data4(1) = &HE5
        .Data4(2) = &HA9
        .Data4(3) = &H46
        .Data4(4) = &HA1
        .Data4(5) = &H42
        .Data4(6) = &H92
        .Data4(7) = &H14
    End With
End Function

Private Function IID_ID3D12PipelineState() As GUID
    ' {765a30f3-f624-4c6f-a828-ace948622445}
    With IID_ID3D12PipelineState
        .Data1 = &H765A30F3
        .Data2 = &HF624
        .Data3 = &H4C6F
        .Data4(0) = &HA8
        .Data4(1) = &H28
        .Data4(2) = &HAC
        .Data4(3) = &HE9
        .Data4(4) = &H48
        .Data4(5) = &H62
        .Data4(6) = &H24
        .Data4(7) = &H45
    End With
End Function

Private Function IID_ID3D12GraphicsCommandList() As GUID
    ' {5b160d0f-ac1b-4185-8ba8-b3ae42a5a455}
    With IID_ID3D12GraphicsCommandList
        .Data1 = &H5B160D0F
        .Data2 = &HAC1B
        .Data3 = &H4185
        .Data4(0) = &H8B
        .Data4(1) = &HA8
        .Data4(2) = &HB3
        .Data4(3) = &HAE
        .Data4(4) = &H42
        .Data4(5) = &HA5
        .Data4(6) = &HA4
        .Data4(7) = &H55
    End With
End Function

Private Function IID_ID3D12Fence() As GUID
    ' {0a753dcf-c4d8-4b91-adf6-be5a60d95a76}
    With IID_ID3D12Fence
        .Data1 = &HA753DCF
        .Data2 = &HC4D8
        .Data3 = &H4B91
        .Data4(0) = &HAD
        .Data4(1) = &HF6
        .Data4(2) = &HBE
        .Data4(3) = &H5A
        .Data4(4) = &H60
        .Data4(5) = &HD9
        .Data4(6) = &H5A
        .Data4(7) = &H76
    End With
End Function

Private Function IID_IDXGISwapChain3() As GUID
    ' {94d99bdb-f1f8-4ab0-b236-7da0170edab1}
    With IID_IDXGISwapChain3
        .Data1 = &H94D99BDB
        .Data2 = &HF1F8
        .Data3 = &H4AB0
        .Data4(0) = &HB2
        .Data4(1) = &H36
        .Data4(2) = &H7D
        .Data4(3) = &HA0
        .Data4(4) = &H17
        .Data4(5) = &HE
        .Data4(6) = &HDA
        .Data4(7) = &HB1
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

Private Function BuildThunk11(ByVal target As LongPtr) As LongPtr
    Dim code(0 To 159) As Byte
    Dim i As Long: i = 0
    
    code(i) = &H48: i = i + 1: code(i) = &H83: i = i + 1: code(i) = &HEC: i = i + 1: code(i) = &H78: i = i + 1
    code(i) = &H4D: i = i + 1: code(i) = &H89: i = i + 1: code(i) = &HC2: i = i + 1
    code(i) = &H49: i = i + 1: code(i) = &H8B: i = i + 1: code(i) = &HA: i = i + 1
    code(i) = &H49: i = i + 1: code(i) = &H8B: i = i + 1: code(i) = &H52: i = i + 1: code(i) = &H8: i = i + 1
    code(i) = &H4D: i = i + 1: code(i) = &H8B: i = i + 1: code(i) = &H42: i = i + 1: code(i) = &H10: i = i + 1
    code(i) = &H4D: i = i + 1: code(i) = &H8B: i = i + 1: code(i) = &H4A: i = i + 1: code(i) = &H18: i = i + 1
    
    ' Args 5-11 on stack
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
    code(i) = &H49: i = i + 1: code(i) = &H8B: i = i + 1: code(i) = &H42: i = i + 1: code(i) = &H48: i = i + 1
    code(i) = &H48: i = i + 1: code(i) = &H89: i = i + 1: code(i) = &H44: i = i + 1: code(i) = &H24: i = i + 1: code(i) = &H48: i = i + 1
    code(i) = &H49: i = i + 1: code(i) = &H8B: i = i + 1: code(i) = &H42: i = i + 1: code(i) = &H50: i = i + 1
    code(i) = &H48: i = i + 1: code(i) = &H89: i = i + 1: code(i) = &H44: i = i + 1: code(i) = &H24: i = i + 1: code(i) = &H50: i = i + 1
    
    code(i) = &H48: i = i + 1: code(i) = &HB8: i = i + 1
    Dim t As LongLong: t = target
    RtlMoveMemoryFromPtr VarPtr(code(i)), t, 8: i = i + 8
    code(i) = &HFF: i = i + 1: code(i) = &HD0: i = i + 1
    code(i) = &H48: i = i + 1: code(i) = &H83: i = i + 1: code(i) = &HC4: i = i + 1: code(i) = &H78: i = i + 1
    code(i) = &HC3
    
    Dim mem As LongPtr
    mem = VirtualAlloc(0, 256, MEM_COMMIT Or MEM_RESERVE, PAGE_EXECUTE_READWRITE)
    If mem = 0 Then Err.Raise vbObjectError + 9004, , "VirtualAlloc failed for Thunk11"
    CopyMemory mem, VarPtr(code(0)), CLngPtr(i + 1)
    BuildThunk11 = mem
End Function

' Special thunk for functions that return struct via hidden first parameter
' GetCPUDescriptorHandleForHeapStart: void(ID3D12DescriptorHeap* this, D3D12_CPU_DESCRIPTOR_HANDLE* retval)
Private Function BuildThunkRetStruct(ByVal target As LongPtr) As LongPtr
    Dim code(0 To 47) As Byte
    Dim i As Long: i = 0
    
    ' sub rsp, 28h
    code(i) = &H48: i = i + 1: code(i) = &H83: i = i + 1: code(i) = &HEC: i = i + 1: code(i) = &H28: i = i + 1
    ' mov r10, r8 (args ptr)
    code(i) = &H4D: i = i + 1: code(i) = &H89: i = i + 1: code(i) = &HC2: i = i + 1
    ' mov rcx, [r10+0] (this)
    code(i) = &H49: i = i + 1: code(i) = &H8B: i = i + 1: code(i) = &HA: i = i + 1
    ' mov rdx, [r10+8] (retval ptr)
    code(i) = &H49: i = i + 1: code(i) = &H8B: i = i + 1: code(i) = &H52: i = i + 1: code(i) = &H8: i = i + 1
    ' mov rax, imm64
    code(i) = &H48: i = i + 1: code(i) = &HB8: i = i + 1
    Dim t As LongLong: t = target
    RtlMoveMemoryFromPtr VarPtr(code(i)), t, 8: i = i + 8
    ' call rax
    code(i) = &HFF: i = i + 1: code(i) = &HD0: i = i + 1
    ' add rsp, 28h
    code(i) = &H48: i = i + 1: code(i) = &H83: i = i + 1: code(i) = &HC4: i = i + 1: code(i) = &H28: i = i + 1
    ' ret
    code(i) = &HC3
    
    Dim mem As LongPtr
    mem = VirtualAlloc(0, 64, MEM_COMMIT Or MEM_RESERVE, PAGE_EXECUTE_READWRITE)
    If mem = 0 Then Err.Raise vbObjectError + 9005, , "VirtualAlloc failed for ThunkRetStruct"
    CopyMemory mem, VarPtr(code(0)), CLngPtr(i + 1)
    BuildThunkRetStruct = mem
End Function

Private Sub FreeThunks()
    On Error Resume Next
    If p_thunk1 <> 0 Then VirtualFree p_thunk1, 0, MEM_RELEASE: p_thunk1 = 0
    If p_thunk2 <> 0 Then VirtualFree p_thunk2, 0, MEM_RELEASE: p_thunk2 = 0
    If p_thunk3 <> 0 Then VirtualFree p_thunk3, 0, MEM_RELEASE: p_thunk3 = 0
    If p_thunk4 <> 0 Then VirtualFree p_thunk4, 0, MEM_RELEASE: p_thunk4 = 0
    If p_thunk5 <> 0 Then VirtualFree p_thunk5, 0, MEM_RELEASE: p_thunk5 = 0
    If p_thunk6 <> 0 Then VirtualFree p_thunk6, 0, MEM_RELEASE: p_thunk6 = 0
    If p_thunk7 <> 0 Then VirtualFree p_thunk7, 0, MEM_RELEASE: p_thunk7 = 0
    If p_thunk8 <> 0 Then VirtualFree p_thunk8, 0, MEM_RELEASE: p_thunk8 = 0
    If p_thunk11 <> 0 Then VirtualFree p_thunk11, 0, MEM_RELEASE: p_thunk11 = 0
    If p_thunkRetStruct <> 0 Then VirtualFree p_thunkRetStruct, 0, MEM_RELEASE: p_thunkRetStruct = 0
End Sub

' ============================================================
' COM Call helpers
' ============================================================
Private Function COM_Call1(ByVal pObj As LongPtr, ByVal vtIndex As Long) As LongPtr
    Dim methodAddr As LongPtr
    methodAddr = GetVTableMethod(pObj, vtIndex)
    
    If p_thunk1 <> 0 Then VirtualFree p_thunk1, 0, MEM_RELEASE
    p_thunk1 = BuildThunk1(methodAddr)
    
    Dim args As ThunkArgs1
    args.a1 = pObj
    
    COM_Call1 = CallWindowProcW(p_thunk1, 0, 0, VarPtr(args), 0)
End Function

Private Function COM_Call2(ByVal pObj As LongPtr, ByVal vtIndex As Long, ByVal a2 As LongPtr) As LongPtr
    Dim methodAddr As LongPtr
    methodAddr = GetVTableMethod(pObj, vtIndex)
    
    If p_thunk2 <> 0 Then VirtualFree p_thunk2, 0, MEM_RELEASE
    p_thunk2 = BuildThunk2(methodAddr)
    
    Dim args As ThunkArgs2
    args.a1 = pObj
    args.a2 = a2
    
    COM_Call2 = CallWindowProcW(p_thunk2, 0, 0, VarPtr(args), 0)
End Function

Private Function COM_Call3(ByVal pObj As LongPtr, ByVal vtIndex As Long, ByVal a2 As LongPtr, ByVal a3 As LongPtr) As LongPtr
    Dim methodAddr As LongPtr
    methodAddr = GetVTableMethod(pObj, vtIndex)
    
    If p_thunk3 <> 0 Then VirtualFree p_thunk3, 0, MEM_RELEASE
    p_thunk3 = BuildThunk3(methodAddr)
    
    Dim args As ThunkArgs3
    args.a1 = pObj
    args.a2 = a2
    args.a3 = a3
    
    COM_Call3 = CallWindowProcW(p_thunk3, 0, 0, VarPtr(args), 0)
End Function

Private Function COM_Call4(ByVal pObj As LongPtr, ByVal vtIndex As Long, ByVal a2 As LongPtr, ByVal a3 As LongPtr, ByVal a4 As LongPtr) As LongPtr
    Dim methodAddr As LongPtr
    methodAddr = GetVTableMethod(pObj, vtIndex)
    
    If p_thunk4 <> 0 Then VirtualFree p_thunk4, 0, MEM_RELEASE
    p_thunk4 = BuildThunk4(methodAddr)
    
    Dim args As ThunkArgs4
    args.a1 = pObj
    args.a2 = a2
    args.a3 = a3
    args.a4 = a4
    
    COM_Call4 = CallWindowProcW(p_thunk4, 0, 0, VarPtr(args), 0)
End Function

Private Function COM_Call5(ByVal pObj As LongPtr, ByVal vtIndex As Long, ByVal a2 As LongPtr, ByVal a3 As LongPtr, ByVal a4 As LongPtr, ByVal a5 As LongPtr) As LongPtr
    Dim methodAddr As LongPtr
    methodAddr = GetVTableMethod(pObj, vtIndex)
    
    If p_thunk5 <> 0 Then VirtualFree p_thunk5, 0, MEM_RELEASE
    p_thunk5 = BuildThunk5(methodAddr)
    
    Dim args As ThunkArgs5
    args.a1 = pObj
    args.a2 = a2
    args.a3 = a3
    args.a4 = a4
    args.a5 = a5
    
    COM_Call5 = CallWindowProcW(p_thunk5, 0, 0, VarPtr(args), 0)
End Function

Private Function COM_Call6(ByVal pObj As LongPtr, ByVal vtIndex As Long, ByVal a2 As LongPtr, ByVal a3 As LongPtr, ByVal a4 As LongPtr, ByVal a5 As LongPtr, ByVal a6 As LongPtr) As LongPtr
    Dim methodAddr As LongPtr
    methodAddr = GetVTableMethod(pObj, vtIndex)
    
    If p_thunk6 <> 0 Then VirtualFree p_thunk6, 0, MEM_RELEASE
    p_thunk6 = BuildThunk6(methodAddr)
    
    Dim args As ThunkArgs6
    args.a1 = pObj
    args.a2 = a2
    args.a3 = a3
    args.a4 = a4
    args.a5 = a5
    args.a6 = a6
    
    COM_Call6 = CallWindowProcW(p_thunk6, 0, 0, VarPtr(args), 0)
End Function

Private Function COM_Call7(ByVal pObj As LongPtr, ByVal vtIndex As Long, ByVal a2 As LongPtr, ByVal a3 As LongPtr, ByVal a4 As LongPtr, ByVal a5 As LongPtr, ByVal a6 As LongPtr, ByVal a7 As LongPtr) As LongPtr
    Dim methodAddr As LongPtr
    methodAddr = GetVTableMethod(pObj, vtIndex)
    
    If p_thunk7 <> 0 Then VirtualFree p_thunk7, 0, MEM_RELEASE
    p_thunk7 = BuildThunk7(methodAddr)
    
    Dim args As ThunkArgs7
    args.a1 = pObj
    args.a2 = a2
    args.a3 = a3
    args.a4 = a4
    args.a5 = a5
    args.a6 = a6
    args.a7 = a7
    
    COM_Call7 = CallWindowProcW(p_thunk7, 0, 0, VarPtr(args), 0)
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
    
    If p_thunkRetStruct <> 0 Then VirtualFree p_thunkRetStruct, 0, MEM_RELEASE
    p_thunkRetStruct = BuildThunkRetStruct(methodAddr)
    
    Dim args As ThunkArgs2
    args.a1 = pHeap
    args.a2 = VarPtr(outHandle)
    
    CallWindowProcW p_thunkRetStruct, 0, 0, VarPtr(args), 0
End Sub

' ============================================================
' HLSL Shader source
' ============================================================
Private Function GetShaderSource() As String
    GetShaderSource = _
        "struct PSInput {" & vbLf & _
        "    float4 position : SV_POSITION;" & vbLf & _
        "    float4 color : COLOR;" & vbLf & _
        "};" & vbLf & _
        "PSInput VSMain(float4 position : POSITION, float4 color : COLOR) {" & vbLf & _
        "    PSInput result;" & vbLf & _
        "    result.position = position;" & vbLf & _
        "    result.color = color;" & vbLf & _
        "    return result;" & vbLf & _
        "}" & vbLf & _
        "float4 PSMain(PSInput input) : SV_TARGET {" & vbLf & _
        "    return input.color;" & vbLf & _
        "}"
End Function

' ============================================================
' Compile shader using D3DCompile
' ============================================================
Private Function CompileShader(ByVal shaderSrc As String, ByVal entryPoint As String, ByVal profile As String) As LongPtr
    LogMsg "CompileShader: " & entryPoint & " / " & profile
    
    Dim hCompiler As LongPtr
    hCompiler = LoadLibraryW(StrPtr("d3dcompiler_47.dll"))
    If hCompiler = 0 Then
        LogMsg "Failed to load d3dcompiler_47.dll"
        Err.Raise vbObjectError + 8100, , "Failed to load d3dcompiler_47.dll"
    End If
    
    Dim procNameBytes() As Byte
    procNameBytes = AnsiZBytes("D3DCompile")
    Dim pD3DCompile As LongPtr
    pD3DCompile = GetProcAddress(hCompiler, VarPtr(procNameBytes(0)))
    If pD3DCompile = 0 Then
        FreeLibrary hCompiler
        Err.Raise vbObjectError + 8101, , "D3DCompile not found"
    End If
    
    If p_thunk11 <> 0 Then VirtualFree p_thunk11, 0, MEM_RELEASE
    p_thunk11 = BuildThunk11(pD3DCompile)
    
    Dim srcBytes() As Byte: srcBytes = AnsiZBytes(shaderSrc)
    Dim entryBytes() As Byte: entryBytes = AnsiZBytes(entryPoint)
    Dim profileBytes() As Byte: profileBytes = AnsiZBytes(profile)
    
    Dim pBlob As LongPtr: pBlob = 0
    Dim pErrorBlob As LongPtr: pErrorBlob = 0
    
    Dim args As ThunkArgs11
    args.a1 = VarPtr(srcBytes(0))
    args.a2 = UBound(srcBytes)
    args.a3 = 0
    args.a4 = 0
    args.a5 = 0
    args.a6 = VarPtr(entryBytes(0))
    args.a7 = VarPtr(profileBytes(0))
    args.a8 = D3DCOMPILE_ENABLE_STRICTNESS
    args.a9 = 0
    args.a10 = VarPtr(pBlob)
    args.a11 = VarPtr(pErrorBlob)
    
    Dim hr As Long
    hr = ToHResult(CallWindowProcW(p_thunk11, 0, 0, VarPtr(args), 0))
    LogMsg "D3DCompile returned: " & Hex$(hr)
    
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
    
    CompileShader = pBlob
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
' Safe HRESULT conversion (LongPtr to Long without overflow)
' ============================================================
Private Function ToHResult(ByVal v As LongPtr) As Long
    ' Extract lower 32 bits safely
    If v >= 0 And v <= &H7FFFFFFF Then
        ToHResult = CLng(v)
    Else
        ' For negative values or values > 2^31, use bit manipulation
        Dim lo As Long
        CopyMemory VarPtr(lo), VarPtr(v), 4
        ToHResult = lo
    End If
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
    LogMsg "CreateDXGIFactory1 returned: " & Hex$(hr) & ", Factory=" & Hex$(pFactory)
    If hr < 0 Or pFactory = 0 Then
        LogMsg "Failed to create DXGI Factory"
        InitD3D12 = False
        Exit Function
    End If
    
    ' Create D3D12 Device
    Dim deviceIID As GUID: deviceIID = IID_ID3D12Device()
    hr = D3D12CreateDevice(0, D3D_FEATURE_LEVEL_12_0, deviceIID, g_pDevice)
    LogMsg "D3D12CreateDevice returned: " & Hex$(hr) & ", Device=" & Hex$(g_pDevice)
    If hr < 0 Or g_pDevice = 0 Then
        LogMsg "Failed to create D3D12 Device"
        COM_Release pFactory
        InitD3D12 = False
        Exit Function
    End If
    
    ' Create Command Queue
    LogMsg "Creating Command Queue..."
    Dim queueDesc As D3D12_COMMAND_QUEUE_DESC
    queueDesc.cType = D3D12_COMMAND_LIST_TYPE_DIRECT
    queueDesc.Priority = 0
    queueDesc.Flags = D3D12_COMMAND_QUEUE_FLAG_NONE
    queueDesc.NodeMask = 0
    LogMsg "  queueDesc initialized"
    
    Dim queueIID As GUID: queueIID = IID_ID3D12CommandQueue()
    LogMsg "  Calling COM_Call4 for CreateCommandQueue..."
    Dim hrResult As LongPtr
    hrResult = COM_Call4(g_pDevice, VTBL_Device_CreateCommandQueue, VarPtr(queueDesc), VarPtr(queueIID), VarPtr(g_pCommandQueue))
    LogMsg "  COM_Call4 returned: " & Hex$(hrResult)
    hr = ToHResult(hrResult)
    LogMsg "CreateCommandQueue returned: " & Hex$(hr) & ", Queue=" & Hex$(g_pCommandQueue)
    If hr < 0 Or g_pCommandQueue = 0 Then
        LogMsg "Failed to create Command Queue"
        COM_Release pFactory
        InitD3D12 = False
        Exit Function
    End If
    
    ' Create Swap Chain
    Dim swapChainDesc As DXGI_SWAP_CHAIN_DESC
    swapChainDesc.BufferDesc.Width = WIDTH
    swapChainDesc.BufferDesc.Height = HEIGHT
    swapChainDesc.BufferDesc.RefreshRate.Numerator = 0
    swapChainDesc.BufferDesc.RefreshRate.Denominator = 0
    swapChainDesc.BufferDesc.Format = DXGI_FORMAT_R8G8B8A8_UNORM
    swapChainDesc.BufferDesc.ScanlineOrdering = 0
    swapChainDesc.BufferDesc.Scaling = 0
    swapChainDesc.SampleDesc.Count = 1
    swapChainDesc.SampleDesc.Quality = 0
    swapChainDesc.BufferUsage = DXGI_USAGE_RENDER_TARGET_OUTPUT
    swapChainDesc.BufferCount = FRAME_COUNT
    swapChainDesc.OutputWindow = hWnd
    swapChainDesc.Windowed = 1
    swapChainDesc.SwapEffect = DXGI_SWAP_EFFECT_FLIP_DISCARD
    swapChainDesc.Flags = 0
    
    hr = ToHResult(COM_Call4(pFactory, VTBL_Factory_CreateSwapChain, g_pCommandQueue, VarPtr(swapChainDesc), VarPtr(g_pSwapChain)))
    LogMsg "CreateSwapChain returned: " & Hex$(hr) & ", SwapChain=" & Hex$(g_pSwapChain)
    If hr < 0 Or g_pSwapChain = 0 Then
        LogMsg "Failed to create Swap Chain"
        COM_Release pFactory
        InitD3D12 = False
        Exit Function
    End If
    
    ' Query IDXGISwapChain3
    Dim swapChain3IID As GUID: swapChain3IID = IID_IDXGISwapChain3()
    hr = ToHResult(COM_Call3(g_pSwapChain, ONVTBL_IUnknown_QueryInterface, VarPtr(swapChain3IID), VarPtr(g_pSwapChain3)))
    LogMsg "QueryInterface SwapChain3 returned: " & Hex$(hr) & ", SwapChain3=" & Hex$(g_pSwapChain3)
    If hr < 0 Or g_pSwapChain3 = 0 Then
        LogMsg "Failed to query SwapChain3"
        COM_Release pFactory
        InitD3D12 = False
        Exit Function
    End If
    
    g_frameIndex = CLng(COM_Call1(g_pSwapChain3, VTBL_SwapChain3_GetCurrentBackBufferIndex))
    LogMsg "Initial frame index: " & g_frameIndex
    
    ' Create RTV Descriptor Heap
    Dim heapDesc As D3D12_DESCRIPTOR_HEAP_DESC
    heapDesc.cType = D3D12_DESCRIPTOR_HEAP_TYPE_RTV
    heapDesc.NumDescriptors = FRAME_COUNT
    heapDesc.Flags = D3D12_DESCRIPTOR_HEAP_FLAG_NONE
    heapDesc.NodeMask = 0
    
    Dim heapIID As GUID: heapIID = IID_ID3D12DescriptorHeap()
    hr = ToHResult(COM_Call4(g_pDevice, VTBL_Device_CreateDescriptorHeap, VarPtr(heapDesc), VarPtr(heapIID), VarPtr(g_pRtvHeap)))
    LogMsg "CreateDescriptorHeap returned: " & Hex$(hr) & ", RtvHeap=" & Hex$(g_pRtvHeap)
    If hr < 0 Or g_pRtvHeap = 0 Then
        LogMsg "Failed to create RTV Heap"
        COM_Release pFactory
        InitD3D12 = False
        Exit Function
    End If
    
    g_rtvDescriptorSize = CLng(COM_Call2(g_pDevice, VTBL_Device_GetDescriptorHandleIncrementSize, D3D12_DESCRIPTOR_HEAP_TYPE_RTV))
    LogMsg "RTV descriptor size: " & g_rtvDescriptorSize
    
    ' Get CPU descriptor handle for heap start
    Dim rtvHandle As D3D12_CPU_DESCRIPTOR_HANDLE
    COM_GetCPUDescriptorHandle g_pRtvHeap, rtvHandle
    LogMsg "RTV handle start: " & Hex$(rtvHandle.ptr)
    
    ' Create render target views for each frame
    Dim resourceIID As GUID: resourceIID = IID_ID3D12Resource()
    Dim frameIdx As Long
    For frameIdx = 0 To FRAME_COUNT - 1
        hr = ToHResult(COM_Call4(g_pSwapChain, VTBL_SwapChain_GetBuffer, frameIdx, VarPtr(resourceIID), VarPtr(g_pRenderTargets(frameIdx))))
        LogMsg "GetBuffer[" & frameIdx & "] returned: " & Hex$(hr) & ", Resource=" & Hex$(g_pRenderTargets(frameIdx))
        If hr < 0 Then
            LogMsg "Failed to get back buffer " & frameIdx
            COM_Release pFactory
            InitD3D12 = False
            Exit Function
        End If
        
        ' CreateRenderTargetView (this, pResource, pDesc, DestDescriptor)
        ' Note: DestDescriptor is passed by value (8 bytes)
        COM_Call4 g_pDevice, VTBL_Device_CreateRenderTargetView, g_pRenderTargets(frameIdx), 0, rtvHandle.ptr
        
        rtvHandle.ptr = rtvHandle.ptr + g_rtvDescriptorSize
    Next frameIdx
    
    ' Create Command Allocator
    Dim allocIID As GUID: allocIID = IID_ID3D12CommandAllocator()
    hr = ToHResult(COM_Call4(g_pDevice, VTBL_Device_CreateCommandAllocator, D3D12_COMMAND_LIST_TYPE_DIRECT, VarPtr(allocIID), VarPtr(g_pCommandAllocator)))
    LogMsg "CreateCommandAllocator returned: " & Hex$(hr) & ", Allocator=" & Hex$(g_pCommandAllocator)
    If hr < 0 Or g_pCommandAllocator = 0 Then
        LogMsg "Failed to create Command Allocator"
        COM_Release pFactory
        InitD3D12 = False
        Exit Function
    End If
    
    COM_Release pFactory
    
    InitD3D12 = True
    LogMsg "InitD3D12: done"
End Function

' ============================================================
' Create Root Signature
' ============================================================
Private Function CreateRootSignature() As Boolean
    LogMsg "CreateRootSignature: start"
    
    Dim rootSigDesc As D3D12_ROOT_SIGNATURE_DESC
    rootSigDesc.NumParameters = 0
    rootSigDesc.pParameters = 0
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
    
    Dim blobPtr As LongPtr
    blobPtr = COM_Call1(pSignatureBlob, VTBL_Blob_GetBufferPointer)
    Dim blobSize As LongPtr
    blobSize = COM_Call1(pSignatureBlob, VTBL_Blob_GetBufferSize)
    LogMsg "Signature blob: ptr=" & Hex$(blobPtr) & ", size=" & blobSize
    
    ' CreateRootSignature (this, nodeMask, pBlobWithRootSignature, blobLengthInBytes, riid, ppvRootSignature)
    Dim rootSigIID As GUID: rootSigIID = IID_ID3D12RootSignature()
    hr = ToHResult(COM_Call6(g_pDevice, VTBL_Device_CreateRootSignature, 0, blobPtr, blobSize, VarPtr(rootSigIID), VarPtr(g_pRootSignature)))
    LogMsg "CreateRootSignature returned: " & Hex$(hr) & ", RootSig=" & Hex$(g_pRootSignature)
    
    COM_Release pSignatureBlob
    If pErrorBlob <> 0 Then COM_Release pErrorBlob
    
    If hr < 0 Or g_pRootSignature = 0 Then
        CreateRootSignature = False
        Exit Function
    End If
    
    CreateRootSignature = True
    LogMsg "CreateRootSignature: done"
End Function

' ============================================================
' Create Pipeline State Object
' ============================================================
Private Function CreatePipelineState() As Boolean
    LogMsg "CreatePipelineState: start"
    
    ' Compile shaders
    Dim shaderSrc As String
    shaderSrc = GetShaderSource()
    
    Dim pVSBlob As LongPtr
    pVSBlob = CompileShader(shaderSrc, "VSMain", "vs_5_0")
    If pVSBlob = 0 Then
        CreatePipelineState = False
        Exit Function
    End If
    
    Dim pPSBlob As LongPtr
    pPSBlob = CompileShader(shaderSrc, "PSMain", "ps_5_0")
    If pPSBlob = 0 Then
        COM_Release pVSBlob
        CreatePipelineState = False
        Exit Function
    End If
    
    Dim vsCodePtr As LongPtr: vsCodePtr = COM_Call1(pVSBlob, VTBL_Blob_GetBufferPointer)
    Dim vsCodeSize As LongPtr: vsCodeSize = COM_Call1(pVSBlob, VTBL_Blob_GetBufferSize)
    Dim psCodePtr As LongPtr: psCodePtr = COM_Call1(pPSBlob, VTBL_Blob_GetBufferPointer)
    Dim psCodeSize As LongPtr: psCodeSize = COM_Call1(pPSBlob, VTBL_Blob_GetBufferSize)
    
    ' Input layout
    g_semanticPosition = AnsiZBytes("POSITION")
    g_semanticColor = AnsiZBytes("COLOR")
    
    Dim inputElements(0 To 1) As D3D12_INPUT_ELEMENT_DESC
    inputElements(0).SemanticName = VarPtr(g_semanticPosition(0))
    inputElements(0).SemanticIndex = 0
    inputElements(0).Format = DXGI_FORMAT_R32G32B32_FLOAT
    inputElements(0).InputSlot = 0
    inputElements(0).AlignedByteOffset = 0
    inputElements(0).InputSlotClass = D3D12_INPUT_CLASSIFICATION_PER_VERTEX_DATA
    inputElements(0).InstanceDataStepRate = 0
    
    inputElements(1).SemanticName = VarPtr(g_semanticColor(0))
    inputElements(1).SemanticIndex = 0
    inputElements(1).Format = DXGI_FORMAT_R32G32B32A32_FLOAT
    inputElements(1).InputSlot = 0
    inputElements(1).AlignedByteOffset = 12
    inputElements(1).InputSlotClass = D3D12_INPUT_CLASSIFICATION_PER_VERTEX_DATA
    inputElements(1).InstanceDataStepRate = 0
    
    ' Build PSO desc
    Dim psoDesc As D3D12_GRAPHICS_PIPELINE_STATE_DESC
    
    psoDesc.pRootSignature = g_pRootSignature
    psoDesc.VS.pShaderBytecode = vsCodePtr
    psoDesc.VS.BytecodeLength = vsCodeSize
    psoDesc.PS.pShaderBytecode = psCodePtr
    psoDesc.PS.BytecodeLength = psCodeSize
    
    ' Blend state (default)
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
    
    ' Rasterizer state
    psoDesc.RasterizerState.FillMode = D3D12_FILL_MODE_SOLID
    psoDesc.RasterizerState.CullMode = D3D12_CULL_MODE_NONE
    psoDesc.RasterizerState.FrontCounterClockwise = 0
    psoDesc.RasterizerState.DepthBias = D3D12_DEFAULT_DEPTH_BIAS
    psoDesc.RasterizerState.DepthBiasClamp = D3D12_DEFAULT_DEPTH_BIAS_CLAMP
    psoDesc.RasterizerState.SlopeScaledDepthBias = D3D12_DEFAULT_SLOPE_SCALED_DEPTH_BIAS
    psoDesc.RasterizerState.DepthClipEnable = 1
    psoDesc.RasterizerState.MultisampleEnable = 0
    psoDesc.RasterizerState.AntialiasedLineEnable = 0
    psoDesc.RasterizerState.ForcedSampleCount = 0
    psoDesc.RasterizerState.ConservativeRaster = 0
    
    ' Depth stencil state (disabled)
    psoDesc.DepthStencilState.DepthEnable = 0
    psoDesc.DepthStencilState.StencilEnable = 0
    
    ' Input layout
    psoDesc.InputLayout.pInputElementDescs = VarPtr(inputElements(0))
    psoDesc.InputLayout.NumElements = 2
    
    psoDesc.IBStripCutValue = 0
    psoDesc.PrimitiveTopologyType = D3D12_PRIMITIVE_TOPOLOGY_TYPE_TRIANGLE
    psoDesc.NumRenderTargets = 1
    psoDesc.RTVFormats(0) = DXGI_FORMAT_R8G8B8A8_UNORM
    psoDesc.DSVFormat = DXGI_FORMAT_UNKNOWN
    psoDesc.SampleDesc.Count = 1
    psoDesc.SampleDesc.Quality = 0
    psoDesc.NodeMask = 0
    psoDesc.Flags = 0
    
    ' CreateGraphicsPipelineState
    Dim psoIID As GUID: psoIID = IID_ID3D12PipelineState()
    Dim hr As Long
    hr = ToHResult(COM_Call4(g_pDevice, VTBL_Device_CreateGraphicsPipelineState, VarPtr(psoDesc), VarPtr(psoIID), VarPtr(g_pPipelineState)))
    LogMsg "CreateGraphicsPipelineState returned: " & Hex$(hr) & ", PSO=" & Hex$(g_pPipelineState)
    
    COM_Release pVSBlob
    COM_Release pPSBlob
    
    If hr < 0 Or g_pPipelineState = 0 Then
        CreatePipelineState = False
        Exit Function
    End If
    
    CreatePipelineState = True
    LogMsg "CreatePipelineState: done"
End Function

' ============================================================
' Create Command List
' ============================================================
Private Function CreateCommandList() As Boolean
    LogMsg "CreateCommandList: start"
    
    ' CreateCommandList (this, nodeMask, type, pCommandAllocator, pInitialState, riid, ppCommandList)
    Dim cmdListIID As GUID: cmdListIID = IID_ID3D12GraphicsCommandList()
    Dim hr As Long
    hr = ToHResult(COM_Call7(g_pDevice, VTBL_Device_CreateCommandList, 0, D3D12_COMMAND_LIST_TYPE_DIRECT, g_pCommandAllocator, g_pPipelineState, VarPtr(cmdListIID), VarPtr(g_pCommandList)))
    LogMsg "CreateCommandList returned: " & Hex$(hr) & ", CmdList=" & Hex$(g_pCommandList)
    
    If hr < 0 Or g_pCommandList = 0 Then
        CreateCommandList = False
        Exit Function
    End If
    
    ' Close command list (it starts in recording state)
    hr = ToHResult(COM_Call1(g_pCommandList, VTBL_CmdList_Close))
    LogMsg "CommandList Close returned: " & Hex$(hr)
    
    CreateCommandList = True
    LogMsg "CreateCommandList: done"
End Function

' ============================================================
' Create Vertex Buffer
' ============================================================
Private Function CreateVertexBuffer() As Boolean
    LogMsg "CreateVertexBuffer: start"
    
    ' Triangle vertices
    Dim vertices(0 To 2) As VERTEX
    
    vertices(0).x = 0!: vertices(0).y = 0.5!: vertices(0).z = 0!
    vertices(0).r = 1!: vertices(0).g = 0!: vertices(0).b = 0!: vertices(0).a = 1!
    
    vertices(1).x = 0.5!: vertices(1).y = -0.5!: vertices(1).z = 0!
    vertices(1).r = 0!: vertices(1).g = 1!: vertices(1).b = 0!: vertices(1).a = 1!
    
    vertices(2).x = -0.5!: vertices(2).y = -0.5!: vertices(2).z = 0!
    vertices(2).r = 0!: vertices(2).g = 0!: vertices(2).b = 1!: vertices(2).a = 1!
    
    Dim vertexSize As Long: vertexSize = LenB(vertices(0))
    Dim bufferSize As LongLong: bufferSize = CLngLng(vertexSize) * 3
    LogMsg "Vertex size: " & vertexSize & ", Buffer size: " & bufferSize
    
    ' Heap properties
    Dim heapProps As D3D12_HEAP_PROPERTIES
    heapProps.cType = D3D12_HEAP_TYPE_UPLOAD
    heapProps.CPUPageProperty = 0
    heapProps.MemoryPoolPreference = 0
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
    resourceDesc.Layout = 1  ' D3D12_TEXTURE_LAYOUT_ROW_MAJOR
    resourceDesc.Flags = 0
    
    ' CreateCommittedResource (this, pHeapProperties, HeapFlags, pDesc, InitialResourceState, pOptimizedClearValue, riid, ppvResource)
    Dim resourceIID As GUID: resourceIID = IID_ID3D12Resource()
    Dim hr As Long
    
    ' Use ThunkArgs8 for 8-arg call
    Dim methodAddr As LongPtr
    methodAddr = GetVTableMethod(g_pDevice, VTBL_Device_CreateCommittedResource)
    
    If p_thunk8 <> 0 Then VirtualFree p_thunk8, 0, MEM_RELEASE
    p_thunk8 = BuildThunk8(methodAddr)
    
    Dim args8 As ThunkArgs8
    args8.a1 = g_pDevice
    args8.a2 = VarPtr(heapProps)
    args8.a3 = D3D12_HEAP_FLAG_NONE
    args8.a4 = VarPtr(resourceDesc)
    args8.a5 = D3D12_RESOURCE_STATE_GENERIC_READ
    args8.a6 = 0
    args8.a7 = VarPtr(resourceIID)
    args8.a8 = VarPtr(g_pVertexBuffer)
    
    hr = ToHResult(CallWindowProcW(p_thunk8, 0, 0, VarPtr(args8), 0))
    LogMsg "CreateCommittedResource returned: " & Hex$(hr) & ", VB=" & Hex$(g_pVertexBuffer)
    
    If hr < 0 Or g_pVertexBuffer = 0 Then
        CreateVertexBuffer = False
        Exit Function
    End If
    
    ' Map and copy data
    Dim pData As LongPtr
    hr = ToHResult(COM_Call4(g_pVertexBuffer, VTBL_Resource_Map, 0, 0, VarPtr(pData)))
    LogMsg "Map returned: " & Hex$(hr) & ", pData=" & Hex$(pData)
    
    If hr >= 0 And pData <> 0 Then
        CopyMemory pData, VarPtr(vertices(0)), CLngPtr(bufferSize)
        COM_Call3 g_pVertexBuffer, VTBL_Resource_Unmap, 0, 0
        LogMsg "Data copied and unmapped"
    End If
    
    ' Setup vertex buffer view
    g_vertexBufferView.BufferLocation = COM_Call1(g_pVertexBuffer, VTBL_Resource_GetGPUVirtualAddress)
    g_vertexBufferView.SizeInBytes = CLng(bufferSize)
    g_vertexBufferView.StrideInBytes = vertexSize
    LogMsg "VBV: Location=" & Hex$(g_vertexBufferView.BufferLocation) & ", Size=" & g_vertexBufferView.SizeInBytes & ", Stride=" & g_vertexBufferView.StrideInBytes
    
    CreateVertexBuffer = True
    LogMsg "CreateVertexBuffer: done"
End Function

' ============================================================
' Create Fence for GPU synchronization
' ============================================================
Private Function CreateFence() As Boolean
    LogMsg "CreateFence: start"
    
    Dim fenceIID As GUID: fenceIID = IID_ID3D12Fence()
    Dim hr As Long
    hr = ToHResult(COM_Call5(g_pDevice, VTBL_Device_CreateFence, 0, D3D12_FENCE_FLAG_NONE, VarPtr(fenceIID), VarPtr(g_pFence)))
    LogMsg "CreateFence returned: " & Hex$(hr) & ", Fence=" & Hex$(g_pFence)
    
    If hr < 0 Or g_pFence = 0 Then
        CreateFence = False
        Exit Function
    End If
    
    g_fenceValue = 1
    
    g_fenceEvent = CreateEventW(0, 0, 0, 0)
    LogMsg "FenceEvent=" & Hex$(g_fenceEvent)
    
    If g_fenceEvent = 0 Then
        CreateFence = False
        Exit Function
    End If
    
    CreateFence = True
    LogMsg "CreateFence: done"
End Function

' ============================================================
' Wait for previous frame
' ============================================================
Private Sub WaitForPreviousFrame()
    Dim fence As LongLong
    fence = g_fenceValue
    
    ' Signal
    COM_Call3 g_pCommandQueue, VTBL_CmdQueue_Signal, g_pFence, CLngPtr(fence)
    g_fenceValue = g_fenceValue + 1
    
    ' Check if completed
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
    ' Reset command allocator and command list
    COM_Call1 g_pCommandAllocator, VTBL_CmdAlloc_Reset
    COM_Call3 g_pCommandList, VTBL_CmdList_Reset, g_pCommandAllocator, g_pPipelineState
    
    ' Set root signature
    COM_Call2 g_pCommandList, VTBL_CmdList_SetGraphicsRootSignature, g_pRootSignature
    
    ' Set viewport
    Dim vp As D3D12_VIEWPORT
    vp.TopLeftX = 0!
    vp.TopLeftY = 0!
    vp.Width = CSng(WIDTH)
    vp.Height = CSng(HEIGHT)
    vp.MinDepth = 0!
    vp.MaxDepth = 1!
    COM_Call3 g_pCommandList, VTBL_CmdList_RSSetViewports, 1, VarPtr(vp)
    
    ' Set scissor rect
    Dim sr As D3D12_RECT
    sr.Left = 0
    sr.Top = 0
    sr.Right = WIDTH
    sr.Bottom = HEIGHT
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
    
    ' ClearRenderTargetView (this, RenderTargetView, ColorRGBA, NumRects, pRects)
    COM_Call5 g_pCommandList, VTBL_CmdList_ClearRenderTargetView, rtvHandle.ptr, VarPtr(clearColor(0)), 0, 0
    
    ' Set render target
    ' OMSetRenderTargets (this, NumRenderTargetDescriptors, pRenderTargetDescriptors, RTsSingleHandleToDescriptorRange, pDepthStencilDescriptor)
    COM_Call5 g_pCommandList, VTBL_CmdList_OMSetRenderTargets, 1, VarPtr(rtvHandle), 1, 0
    
    ' Set primitive topology
    COM_Call2 g_pCommandList, VTBL_CmdList_IASetPrimitiveTopology, D3D_PRIMITIVE_TOPOLOGY_TRIANGLELIST
    
    ' Set vertex buffer
    COM_Call4 g_pCommandList, VTBL_CmdList_IASetVertexBuffers, 0, 1, VarPtr(g_vertexBufferView)
    
    ' Draw
    ' DrawInstanced (this, VertexCountPerInstance, InstanceCount, StartVertexLocation, StartInstanceLocation)
    COM_Call5 g_pCommandList, VTBL_CmdList_DrawInstanced, 3, 1, 0, 0
    
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
    COM_Call3 g_pSwapChain, VTBL_SwapChain_Present, 0, 0
    
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

    Dim wcex As WNDCLASSEXW
    Dim hInstance As LongPtr
    hInstance = GetModuleHandleW(0)
    LogMsg "GetModuleHandleW=" & Hex$(hInstance)

    wcex.cbSize = LenB(wcex)
    wcex.style = CS_HREDRAW Or CS_VREDRAW Or CS_OWNDC
    wcex.lpfnWndProc = VBA.CLngPtr(AddressOf WindowProc)
    wcex.hInstance = hInstance
    wcex.hIcon = LoadIconW(0, IDI_APPLICATION)
    wcex.hCursor = LoadCursorW(0, IDC_ARROW)
    wcex.hbrBackground = (COLOR_WINDOW + 1)
    wcex.lpszClassName = StrPtr(CLASS_NAME)
    wcex.hIconSm = LoadIconW(0, IDI_APPLICATION)

    LogMsg "RegisterClassExW..."
    If RegisterClassExW(wcex) = 0 Then
        LogMsg "RegisterClassExW failed. GetLastError=" & GetLastError()
        MsgBox "RegisterClassExW failed.", vbCritical
        GoTo FIN
    End If
    LogMsg "RegisterClassExW OK"

    LogMsg "CreateWindowExW..."
    g_hWnd = CreateWindowExW(0, StrPtr(CLASS_NAME), StrPtr(WINDOW_NAME), WS_OVERLAPPEDWINDOW, _
                            CW_USEDEFAULT, CW_USEDEFAULT, WIDTH, HEIGHT, 0, 0, hInstance, 0)
    LogMsg "CreateWindowExW hWnd=" & Hex$(g_hWnd)
    If g_hWnd = 0 Then
        LogMsg "CreateWindowExW failed. GetLastError=" & GetLastError()
        MsgBox "CreateWindowExW failed.", vbCritical
        GoTo FIN
    End If

    ShowWindow g_hWnd, SW_SHOWDEFAULT
    UpdateWindow g_hWnd
    LogMsg "ShowWindow/UpdateWindow OK"

    ' Initialize D3D12
    If Not InitD3D12(g_hWnd) Then
        MsgBox "Failed to initialize DirectX 12.", vbCritical
        GoTo FIN
    End If

    ' Create root signature
    If Not CreateRootSignature() Then
        MsgBox "Failed to create root signature.", vbCritical
        GoTo FIN
    End If

    ' Create pipeline state
    If Not CreatePipelineState() Then
        MsgBox "Failed to create pipeline state.", vbCritical
        GoTo FIN
    End If

    ' Create command list
    If Not CreateCommandList() Then
        MsgBox "Failed to create command list.", vbCritical
        GoTo FIN
    End If

    ' Create vertex buffer
    If Not CreateVertexBuffer() Then
        MsgBox "Failed to create vertex buffer.", vbCritical
        GoTo FIN
    End If

    ' Create fence
    If Not CreateFence() Then
        MsgBox "Failed to create fence.", vbCritical
        GoTo FIN
    End If

    ' Message loop
    Dim msg As MSGW
    Dim quit As Boolean: quit = False
    Dim frame As Long: frame = 0

    LogMsg "Loop: start"
    Do While Not quit
        If PeekMessageW(msg, 0, 0, 0, PM_REMOVE) <> 0 Then
            If msg.message = WM_QUIT Then
                LogMsg "Loop: WM_QUIT"
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
