Attribute VB_Name = "hello"
Option Explicit

' ============================================================
'  Excel VBA (64-bit) + DirectX 11 - Triangle Rendering
'   - Creates a Win32 window
'   - Creates D3D11 Device and SwapChain
'   - Compiles shaders using D3DCompile
'   - Renders a colored triangle
'   - Debug log: C:\TEMP\dx11_debug.log
'
'  Based on OpenGL VBA sample architecture with x64 thunks.
' ============================================================

' -----------------------------
' Win32 constants
' -----------------------------
Private Const PM_REMOVE As Long = &H1&
Private Const WM_QUIT As Long = &H12&
Private Const WM_DESTROY As Long = &H2&
Private Const WM_CLOSE As Long = &H10&
Private Const WM_SIZE As Long = &H5&

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

' -----------------------------
' DirectX constants
' -----------------------------
Private Const D3D_DRIVER_TYPE_HARDWARE As Long = 1
Private Const D3D_FEATURE_LEVEL_11_0 As Long = &HB000&

Private Const D3D11_SDK_VERSION As Long = 7

Private Const DXGI_FORMAT_R8G8B8A8_UNORM As Long = 28
Private Const DXGI_FORMAT_R32G32B32_FLOAT As Long = 6
Private Const DXGI_FORMAT_R32G32B32A32_FLOAT As Long = 2

Private Const DXGI_USAGE_RENDER_TARGET_OUTPUT As Long = &H20&

Private Const D3D11_BIND_VERTEX_BUFFER As Long = &H1&
Private Const D3D11_USAGE_DEFAULT As Long = 0
Private Const D3D11_INPUT_PER_VERTEX_DATA As Long = 0

Private Const D3D11_PRIMITIVE_TOPOLOGY_TRIANGLELIST As Long = 4

Private Const D3DCOMPILE_ENABLE_STRICTNESS As Long = &H800&

' -----------------------------
' vtable indices (from vtable.txt)
' -----------------------------
' IUnknown
Private Const ONVTBL_IUnknown_Release As Long = 2

' ID3D11Device
Private Const VTBL_Device_CreateBuffer As Long = 3
Private Const VTBL_Device_CreateRenderTargetView As Long = 9
Private Const VTBL_Device_CreateInputLayout As Long = 11
Private Const VTBL_Device_CreateVertexShader As Long = 12
Private Const VTBL_Device_CreatePixelShader As Long = 15

' ID3D11DeviceContext
Private Const VTBL_Context_PSSetShader As Long = 9
Private Const VTBL_Context_VSSetShader As Long = 11
Private Const VTBL_Context_Draw As Long = 13
Private Const VTBL_Context_IASetInputLayout As Long = 17
Private Const VTBL_Context_IASetVertexBuffers As Long = 18
Private Const VTBL_Context_IASetPrimitiveTopology As Long = 24
Private Const VTBL_Context_OMSetRenderTargets As Long = 33
Private Const VTBL_Context_RSSetViewports As Long = 44
Private Const VTBL_Context_ClearRenderTargetView As Long = 50

' IDXGISwapChain
Private Const VTBL_SwapChain_Present As Long = 8
Private Const VTBL_SwapChain_GetBuffer As Long = 9

' ID3DBlob
Private Const VTBL_Blob_GetBufferPointer As Long = 3
Private Const VTBL_Blob_GetBufferSize As Long = 4

' -----------------------------
' Class / window names
' -----------------------------
Private Const CLASS_NAME As String = "helloDX11WindowVBA"
Private Const WINDOW_NAME As String = "Hello DirectX 11 (VBA64)"

' -----------------------------
' Types
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

Private Type GUID
    Data1 As Long
    Data2 As Integer
    Data3 As Integer
    Data4(0 To 7) As Byte
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

Private Type D3D11_BUFFER_DESC
    ByteWidth As Long
    Usage As Long
    BindFlags As Long
    CPUAccessFlags As Long
    MiscFlags As Long
    StructureByteStride As Long
End Type

Private Type D3D11_SUBRESOURCE_DATA
    pSysMem As LongPtr
    SysMemPitch As Long
    SysMemSlicePitch As Long
End Type

Private Type D3D11_INPUT_ELEMENT_DESC
    SemanticName As LongPtr
    SemanticIndex As Long
    Format As Long
    InputSlot As Long
    AlignedByteOffset As Long
    InputSlotClass As Long
    InstanceDataStepRate As Long
End Type

Private Type D3D11_VIEWPORT
    TopLeftX As Single
    TopLeftY As Single
    Width As Single
    Height As Single
    MinDepth As Single
    MaxDepth As Single
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

' Thunk argument structures
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
Private g_pDevice As LongPtr
Private g_pContext As LongPtr
Private g_pSwapChain As LongPtr
Private g_pRenderTargetView As LongPtr
Private g_pVertexShader As LongPtr
Private g_pPixelShader As LongPtr
Private g_pInputLayout As LongPtr
Private g_pVertexBuffer As LongPtr

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
Private p_thunk11 As LongPtr

' Semantic name strings (must persist)
Private g_semanticPosition() As Byte
Private g_semanticColor() As Byte

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

    ' Generic caller
    Private Declare PtrSafe Function CallWindowProcW Lib "user32" ( _
        ByVal lpPrevWndFunc As LongPtr, _
        ByVal hWnd As LongPtr, _
        ByVal msg As LongPtr, _
        ByVal wParam As LongPtr, _
        ByVal lParam As LongPtr) As LongPtr

    ' DirectX
    Private Declare PtrSafe Function D3D11CreateDeviceAndSwapChain Lib "d3d11.dll" ( _
        ByVal pAdapter As LongPtr, _
        ByVal DriverType As Long, _
        ByVal Software As LongPtr, _
        ByVal Flags As Long, _
        ByVal pFeatureLevels As LongPtr, _
        ByVal FeatureLevels As Long, _
        ByVal SDKVersion As Long, _
        ByRef pSwapChainDesc As DXGI_SWAP_CHAIN_DESC, _
        ByRef ppSwapChain As LongPtr, _
        ByRef ppDevice As LongPtr, _
        ByRef pFeatureLevel As Long, _
        ByRef ppImmediateContext As LongPtr) As Long

    ' D3DCompile - we'll use thunk for this (11 args)
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
    Private Declare PtrSafe Function CloseHandle Lib "kernel32" (ByVal hObject As LongPtr) As Long

    Private Declare PtrSafe Function lstrlenA Lib "kernel32" (ByVal lpString As LongPtr) As Long
    Private Declare PtrSafe Sub RtlMoveMemory Lib "kernel32" (ByRef Destination As Any, ByVal Source As LongPtr, ByVal Length As Long)
    Private Declare PtrSafe Sub RtlMoveMemoryFromPtr Lib "kernel32" Alias "RtlMoveMemory" (ByVal Destination As LongPtr, ByRef Source As Any, ByVal Length As Long)
    Private Declare PtrSafe Sub CopyMemory Lib "kernel32" Alias "RtlMoveMemory" (ByVal Destination As LongPtr, ByVal Source As LongPtr, ByVal Length As LongPtr)
    Private Declare PtrSafe Sub CopyMemoryByRef Lib "kernel32" Alias "RtlMoveMemory" (ByRef Destination As Any, ByRef Source As Any, ByVal Length As LongPtr)

    Private Declare PtrSafe Function VirtualAlloc Lib "kernel32" (ByVal lpAddress As LongPtr, ByVal dwSize As LongPtr, ByVal flAllocationType As Long, ByVal flProtect As Long) As LongPtr
    Private Declare PtrSafe Function VirtualFree Lib "kernel32" (ByVal lpAddress As LongPtr, ByVal dwSize As LongPtr, ByVal dwFreeType As Long) As Long
#End If

' ============================================================
' Logger
' ============================================================
Private Sub LogOpen()
    On Error Resume Next
    CreateDirectoryW StrPtr("C:\TEMP"), 0
    g_log = CreateFileW(StrPtr("C:\TEMP\dx11_debug.log"), GENERIC_WRITE, FILE_SHARE_READ Or FILE_SHARE_WRITE, 0, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, 0)
    If g_log = 0 Or g_log = -1 Then g_log = 0
    LogMsg "==== DX11 LOG START ===="
End Sub

Private Sub LogClose()
    On Error Resume Next
    If g_log <> 0 Then
        LogMsg "==== DX11 LOG END ===="
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
Private Function IID_ID3D11Texture2D() As GUID
    ' {6F15AAF2-D208-4E89-9AB4-489535D34F9C}
    With IID_ID3D11Texture2D
        .Data1 = &H6F15AAF2
        .Data2 = &HD208
        .Data3 = &H4E89
        .Data4(0) = &H9A
        .Data4(1) = &HB4
        .Data4(2) = &H48
        .Data4(3) = &H95
        .Data4(4) = &H35
        .Data4(5) = &HD3
        .Data4(6) = &H4F
        .Data4(7) = &H9C
    End With
End Function

' ============================================================
' COM vtable helpers
' ============================================================
Private Function GetVTableMethod(ByVal pObj As LongPtr, ByVal vtIndex As Long) As LongPtr
    Dim vtable As LongPtr
    Dim methodAddr As LongPtr
    Dim offset As LongPtr
    
    ' Read vtable pointer from object (use CopyMemory with explicit addresses)
    CopyMemory VarPtr(vtable), pObj, 8
    
    ' Calculate offset
    offset = CLngPtr(vtIndex) * 8
    
    ' Read method address from vtable
    CopyMemory VarPtr(methodAddr), vtable + offset, 8
    
    GetVTableMethod = methodAddr
End Function

Private Function COM_Call1(ByVal pObj As LongPtr, ByVal vtIndex As Long) As LongPtr
    Dim methodAddr As LongPtr
    methodAddr = GetVTableMethod(pObj, vtIndex)
    
    ' Use thunk for safer calling
    If p_thunk1 <> 0 Then VirtualFree p_thunk1, 0, MEM_RELEASE
    p_thunk1 = BuildThunk1(methodAddr)
    
    Dim args As ThunkArgs1
    args.a1 = pObj
    
    COM_Call1 = CallWindowProcW(p_thunk1, 0, 0, VarPtr(args), 0)
End Function

Private Function COM_Call2(ByVal pObj As LongPtr, ByVal vtIndex As Long, ByVal a2 As LongPtr) As LongPtr
    Dim methodAddr As LongPtr
    methodAddr = GetVTableMethod(pObj, vtIndex)
    LogMsg "  COM_Call2: obj=" & Hex$(pObj) & ", vtIdx=" & vtIndex & ", method=" & Hex$(methodAddr) & ", a2=" & Hex$(a2)
    
    ' Use thunk for safer calling
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
    LogMsg "  COM_Call3: obj=" & Hex$(pObj) & ", vtIdx=" & vtIndex & ", method=" & Hex$(methodAddr) & ", a2=" & Hex$(a2) & ", a3=" & Hex$(a3)
    
    ' Use thunk for safer calling
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
    LogMsg "  COM_Call4: obj=" & Hex$(pObj) & ", vtIdx=" & vtIndex & ", method=" & Hex$(methodAddr)
    LogMsg "  COM_Call4: a2=" & Hex$(a2) & ", a3=" & Hex$(a3) & ", a4=" & Hex$(a4)
    
    ' Use thunk for safer calling
    If p_thunk4 <> 0 Then VirtualFree p_thunk4, 0, MEM_RELEASE
    p_thunk4 = BuildThunk4(methodAddr)
    
    Dim args As ThunkArgs4
    args.a1 = pObj
    args.a2 = a2
    args.a3 = a3
    args.a4 = a4
    
    COM_Call4 = CallWindowProcW(p_thunk4, 0, 0, VarPtr(args), 0)
End Function

Private Sub COM_Release(ByVal pObj As LongPtr)
    If pObj <> 0 Then
        COM_Call1 pObj, ONVTBL_IUnknown_Release
    End If
End Sub

' ============================================================
' Thunk builders for 1, 2, 3, 4, 5, 6, and 11 argument functions
' ============================================================

' Build thunk for 1-argument function (COM method with 0 args + this)
' Args in struct: a1(rcx=this)
Private Function BuildThunk1(ByVal target As LongPtr) As LongPtr
    Dim code(0 To 39) As Byte
    Dim i As Long: i = 0
    
    ' sub rsp, 28h (allocate shadow space)
    code(i) = &H48: i = i + 1
    code(i) = &H83: i = i + 1
    code(i) = &HEC: i = i + 1
    code(i) = &H28: i = i + 1
    
    ' mov r10, r8 (r8 = wParam = args*)
    code(i) = &H4D: i = i + 1
    code(i) = &H89: i = i + 1
    code(i) = &HC2: i = i + 1
    
    ' mov rcx, [r10+0]
    code(i) = &H49: i = i + 1
    code(i) = &H8B: i = i + 1
    code(i) = &HA: i = i + 1
    
    ' mov rax, imm64 (target)
    code(i) = &H48: i = i + 1
    code(i) = &HB8: i = i + 1
    Dim t As LongLong: t = target
    RtlMoveMemoryFromPtr VarPtr(code(i)), t, 8
    i = i + 8
    
    ' call rax
    code(i) = &HFF: i = i + 1
    code(i) = &HD0: i = i + 1
    
    ' add rsp, 28h
    code(i) = &H48: i = i + 1
    code(i) = &H83: i = i + 1
    code(i) = &HC4: i = i + 1
    code(i) = &H28: i = i + 1
    
    ' ret
    code(i) = &HC3
    
    Dim mem As LongPtr
    mem = VirtualAlloc(0, 64, MEM_COMMIT Or MEM_RESERVE, PAGE_EXECUTE_READWRITE)
    If mem = 0 Then Err.Raise vbObjectError + 8996, , "VirtualAlloc failed for Thunk1"
    CopyMemory mem, VarPtr(code(0)), CLngPtr(i + 1)
    BuildThunk1 = mem
End Function

' Build thunk for 2-argument function (COM method with 1 arg + this)
' Args in struct: a1(rcx=this), a2(rdx)
Private Function BuildThunk2(ByVal target As LongPtr) As LongPtr
    Dim code(0 To 47) As Byte
    Dim i As Long: i = 0
    
    ' sub rsp, 28h (allocate shadow space)
    code(i) = &H48: i = i + 1
    code(i) = &H83: i = i + 1
    code(i) = &HEC: i = i + 1
    code(i) = &H28: i = i + 1
    
    ' mov r10, r8 (r8 = wParam = args*)
    code(i) = &H4D: i = i + 1
    code(i) = &H89: i = i + 1
    code(i) = &HC2: i = i + 1
    
    ' mov rcx, [r10+0]
    code(i) = &H49: i = i + 1
    code(i) = &H8B: i = i + 1
    code(i) = &HA: i = i + 1
    
    ' mov rdx, [r10+8]
    code(i) = &H49: i = i + 1
    code(i) = &H8B: i = i + 1
    code(i) = &H52: i = i + 1
    code(i) = &H8: i = i + 1
    
    ' mov rax, imm64 (target)
    code(i) = &H48: i = i + 1
    code(i) = &HB8: i = i + 1
    Dim t As LongLong: t = target
    RtlMoveMemoryFromPtr VarPtr(code(i)), t, 8
    i = i + 8
    
    ' call rax
    code(i) = &HFF: i = i + 1
    code(i) = &HD0: i = i + 1
    
    ' add rsp, 28h
    code(i) = &H48: i = i + 1
    code(i) = &H83: i = i + 1
    code(i) = &HC4: i = i + 1
    code(i) = &H28: i = i + 1
    
    ' ret
    code(i) = &HC3
    
    Dim mem As LongPtr
    mem = VirtualAlloc(0, 64, MEM_COMMIT Or MEM_RESERVE, PAGE_EXECUTE_READWRITE)
    If mem = 0 Then Err.Raise vbObjectError + 8997, , "VirtualAlloc failed for Thunk2"
    CopyMemory mem, VarPtr(code(0)), CLngPtr(i + 1)
    BuildThunk2 = mem
End Function

' Build thunk for 3-argument function (COM method with 2 args + this)
' Args in struct: a1(rcx=this), a2(rdx), a3(r8)
Private Function BuildThunk3(ByVal target As LongPtr) As LongPtr
    Dim code(0 To 55) As Byte
    Dim i As Long: i = 0
    
    ' sub rsp, 28h (allocate shadow space)
    code(i) = &H48: i = i + 1
    code(i) = &H83: i = i + 1
    code(i) = &HEC: i = i + 1
    code(i) = &H28: i = i + 1
    
    ' mov r10, r8 (r8 = wParam = args*)
    code(i) = &H4D: i = i + 1
    code(i) = &H89: i = i + 1
    code(i) = &HC2: i = i + 1
    
    ' mov rcx, [r10+0]
    code(i) = &H49: i = i + 1
    code(i) = &H8B: i = i + 1
    code(i) = &HA: i = i + 1
    
    ' mov rdx, [r10+8]
    code(i) = &H49: i = i + 1
    code(i) = &H8B: i = i + 1
    code(i) = &H52: i = i + 1
    code(i) = &H8: i = i + 1
    
    ' mov r8, [r10+16]
    code(i) = &H4D: i = i + 1
    code(i) = &H8B: i = i + 1
    code(i) = &H42: i = i + 1
    code(i) = &H10: i = i + 1
    
    ' mov rax, imm64 (target)
    code(i) = &H48: i = i + 1
    code(i) = &HB8: i = i + 1
    Dim t As LongLong: t = target
    RtlMoveMemoryFromPtr VarPtr(code(i)), t, 8
    i = i + 8
    
    ' call rax
    code(i) = &HFF: i = i + 1
    code(i) = &HD0: i = i + 1
    
    ' add rsp, 28h
    code(i) = &H48: i = i + 1
    code(i) = &H83: i = i + 1
    code(i) = &HC4: i = i + 1
    code(i) = &H28: i = i + 1
    
    ' ret
    code(i) = &HC3
    
    Dim mem As LongPtr
    mem = VirtualAlloc(0, 64, MEM_COMMIT Or MEM_RESERVE, PAGE_EXECUTE_READWRITE)
    If mem = 0 Then Err.Raise vbObjectError + 8998, , "VirtualAlloc failed for Thunk3"
    CopyMemory mem, VarPtr(code(0)), CLngPtr(i + 1)
    BuildThunk3 = mem
End Function

' Build thunk for 4-argument function (COM method with 3 args + this)
' Args in struct: a1(rcx=this), a2(rdx), a3(r8), a4(r9)
Private Function BuildThunk4(ByVal target As LongPtr) As LongPtr
    Dim code(0 To 63) As Byte
    Dim i As Long: i = 0
    
    ' sub rsp, 28h (allocate shadow space)
    code(i) = &H48: i = i + 1
    code(i) = &H83: i = i + 1
    code(i) = &HEC: i = i + 1
    code(i) = &H28: i = i + 1
    
    ' mov r10, r8 (r8 = wParam = args*)
    code(i) = &H4D: i = i + 1
    code(i) = &H89: i = i + 1
    code(i) = &HC2: i = i + 1
    
    ' mov rcx, [r10+0]
    code(i) = &H49: i = i + 1
    code(i) = &H8B: i = i + 1
    code(i) = &HA: i = i + 1
    
    ' mov rdx, [r10+8]
    code(i) = &H49: i = i + 1
    code(i) = &H8B: i = i + 1
    code(i) = &H52: i = i + 1
    code(i) = &H8: i = i + 1
    
    ' mov r8, [r10+16]
    code(i) = &H4D: i = i + 1
    code(i) = &H8B: i = i + 1
    code(i) = &H42: i = i + 1
    code(i) = &H10: i = i + 1
    
    ' mov r9, [r10+24]
    code(i) = &H4D: i = i + 1
    code(i) = &H8B: i = i + 1
    code(i) = &H4A: i = i + 1
    code(i) = &H18: i = i + 1
    
    ' mov rax, imm64 (target)
    code(i) = &H48: i = i + 1
    code(i) = &HB8: i = i + 1
    Dim t As LongLong: t = target
    RtlMoveMemoryFromPtr VarPtr(code(i)), t, 8
    i = i + 8
    
    ' call rax
    code(i) = &HFF: i = i + 1
    code(i) = &HD0: i = i + 1
    
    ' add rsp, 28h
    code(i) = &H48: i = i + 1
    code(i) = &H83: i = i + 1
    code(i) = &HC4: i = i + 1
    code(i) = &H28: i = i + 1
    
    ' ret
    code(i) = &HC3
    
    Dim mem As LongPtr
    mem = VirtualAlloc(0, 128, MEM_COMMIT Or MEM_RESERVE, PAGE_EXECUTE_READWRITE)
    If mem = 0 Then Err.Raise vbObjectError + 8999, , "VirtualAlloc failed for Thunk4"
    CopyMemory mem, VarPtr(code(0)), CLngPtr(i + 1)
    BuildThunk4 = mem
End Function

' Build thunk for 5-argument function
' Args in struct: a1(rcx), a2(rdx), a3(r8), a4(r9), a5(stack)
Private Function BuildThunk5(ByVal target As LongPtr) As LongPtr
    Dim code(0 To 79) As Byte
    Dim i As Long: i = 0
    
    ' sub rsp, 38h (allocate shadow space + stack args)
    code(i) = &H48: i = i + 1
    code(i) = &H83: i = i + 1
    code(i) = &HEC: i = i + 1
    code(i) = &H38: i = i + 1
    
    ' mov r10, r8 (r8 = wParam = args*)
    code(i) = &H4D: i = i + 1
    code(i) = &H89: i = i + 1
    code(i) = &HC2: i = i + 1
    
    ' mov rcx, [r10+0]
    code(i) = &H49: i = i + 1
    code(i) = &H8B: i = i + 1
    code(i) = &HA: i = i + 1
    
    ' mov rdx, [r10+8]
    code(i) = &H49: i = i + 1
    code(i) = &H8B: i = i + 1
    code(i) = &H52: i = i + 1
    code(i) = &H8: i = i + 1
    
    ' mov r8, [r10+16]
    code(i) = &H4D: i = i + 1
    code(i) = &H8B: i = i + 1
    code(i) = &H42: i = i + 1
    code(i) = &H10: i = i + 1
    
    ' mov r9, [r10+24]
    code(i) = &H4D: i = i + 1
    code(i) = &H8B: i = i + 1
    code(i) = &H4A: i = i + 1
    code(i) = &H18: i = i + 1
    
    ' mov rax, [r10+32] ; 5th arg
    code(i) = &H49: i = i + 1
    code(i) = &H8B: i = i + 1
    code(i) = &H42: i = i + 1
    code(i) = &H20: i = i + 1
    
    ' mov [rsp+20h], rax
    code(i) = &H48: i = i + 1
    code(i) = &H89: i = i + 1
    code(i) = &H44: i = i + 1
    code(i) = &H24: i = i + 1
    code(i) = &H20: i = i + 1
    
    ' mov rax, imm64 (target)
    code(i) = &H48: i = i + 1
    code(i) = &HB8: i = i + 1
    Dim t As LongLong: t = target
    RtlMoveMemoryFromPtr VarPtr(code(i)), t, 8
    i = i + 8
    
    ' call rax
    code(i) = &HFF: i = i + 1
    code(i) = &HD0: i = i + 1
    
    ' add rsp, 38h
    code(i) = &H48: i = i + 1
    code(i) = &H83: i = i + 1
    code(i) = &HC4: i = i + 1
    code(i) = &H38: i = i + 1
    
    ' ret
    code(i) = &HC3
    
    Dim mem As LongPtr
    mem = VirtualAlloc(0, 128, MEM_COMMIT Or MEM_RESERVE, PAGE_EXECUTE_READWRITE)
    If mem = 0 Then Err.Raise vbObjectError + 9000, , "VirtualAlloc failed for Thunk5"
    CopyMemory mem, VarPtr(code(0)), CLngPtr(i + 1)
    BuildThunk5 = mem
End Function

' Build thunk for 6-argument function
Private Function BuildThunk6(ByVal target As LongPtr) As LongPtr
    Dim code(0 To 99) As Byte
    Dim i As Long: i = 0
    
    ' sub rsp, 48h
    code(i) = &H48: i = i + 1
    code(i) = &H83: i = i + 1
    code(i) = &HEC: i = i + 1
    code(i) = &H48: i = i + 1
    
    ' mov r10, r8
    code(i) = &H4D: i = i + 1
    code(i) = &H89: i = i + 1
    code(i) = &HC2: i = i + 1
    
    ' mov rcx, [r10+0]
    code(i) = &H49: i = i + 1
    code(i) = &H8B: i = i + 1
    code(i) = &HA: i = i + 1
    
    ' mov rdx, [r10+8]
    code(i) = &H49: i = i + 1
    code(i) = &H8B: i = i + 1
    code(i) = &H52: i = i + 1
    code(i) = &H8: i = i + 1
    
    ' mov r8, [r10+16]
    code(i) = &H4D: i = i + 1
    code(i) = &H8B: i = i + 1
    code(i) = &H42: i = i + 1
    code(i) = &H10: i = i + 1
    
    ' mov r9, [r10+24]
    code(i) = &H4D: i = i + 1
    code(i) = &H8B: i = i + 1
    code(i) = &H4A: i = i + 1
    code(i) = &H18: i = i + 1
    
    ' mov rax, [r10+32] ; 5th arg
    code(i) = &H49: i = i + 1
    code(i) = &H8B: i = i + 1
    code(i) = &H42: i = i + 1
    code(i) = &H20: i = i + 1
    
    ' mov [rsp+20h], rax
    code(i) = &H48: i = i + 1
    code(i) = &H89: i = i + 1
    code(i) = &H44: i = i + 1
    code(i) = &H24: i = i + 1
    code(i) = &H20: i = i + 1
    
    ' mov rax, [r10+40] ; 6th arg
    code(i) = &H49: i = i + 1
    code(i) = &H8B: i = i + 1
    code(i) = &H42: i = i + 1
    code(i) = &H28: i = i + 1
    
    ' mov [rsp+28h], rax
    code(i) = &H48: i = i + 1
    code(i) = &H89: i = i + 1
    code(i) = &H44: i = i + 1
    code(i) = &H24: i = i + 1
    code(i) = &H28: i = i + 1
    
    ' mov rax, imm64 (target)
    code(i) = &H48: i = i + 1
    code(i) = &HB8: i = i + 1
    Dim t As LongLong: t = target
    RtlMoveMemoryFromPtr VarPtr(code(i)), t, 8
    i = i + 8
    
    ' call rax
    code(i) = &HFF: i = i + 1
    code(i) = &HD0: i = i + 1
    
    ' add rsp, 48h
    code(i) = &H48: i = i + 1
    code(i) = &H83: i = i + 1
    code(i) = &HC4: i = i + 1
    code(i) = &H48: i = i + 1
    
    ' ret
    code(i) = &HC3
    
    Dim mem As LongPtr
    mem = VirtualAlloc(0, 128, MEM_COMMIT Or MEM_RESERVE, PAGE_EXECUTE_READWRITE)
    If mem = 0 Then Err.Raise vbObjectError + 9001, , "VirtualAlloc failed for Thunk6"
    CopyMemory mem, VarPtr(code(0)), CLngPtr(i + 1)
    BuildThunk6 = mem
End Function

' Build thunk for 11-argument function (D3DCompile)
Private Function BuildThunk11(ByVal target As LongPtr) As LongPtr
    Dim code(0 To 159) As Byte
    Dim i As Long: i = 0
    
    ' sub rsp, 78h (shadow space + 7 stack args)
    code(i) = &H48: i = i + 1
    code(i) = &H83: i = i + 1
    code(i) = &HEC: i = i + 1
    code(i) = &H78: i = i + 1
    
    ' mov r10, r8
    code(i) = &H4D: i = i + 1
    code(i) = &H89: i = i + 1
    code(i) = &HC2: i = i + 1
    
    ' mov rcx, [r10+0]
    code(i) = &H49: i = i + 1
    code(i) = &H8B: i = i + 1
    code(i) = &HA: i = i + 1
    
    ' mov rdx, [r10+8]
    code(i) = &H49: i = i + 1
    code(i) = &H8B: i = i + 1
    code(i) = &H52: i = i + 1
    code(i) = &H8: i = i + 1
    
    ' mov r8, [r10+16]
    code(i) = &H4D: i = i + 1
    code(i) = &H8B: i = i + 1
    code(i) = &H42: i = i + 1
    code(i) = &H10: i = i + 1
    
    ' mov r9, [r10+24]
    code(i) = &H4D: i = i + 1
    code(i) = &H8B: i = i + 1
    code(i) = &H4A: i = i + 1
    code(i) = &H18: i = i + 1
    
    ' 5th arg: mov rax, [r10+32]; mov [rsp+20h], rax
    code(i) = &H49: i = i + 1
    code(i) = &H8B: i = i + 1
    code(i) = &H42: i = i + 1
    code(i) = &H20: i = i + 1
    code(i) = &H48: i = i + 1
    code(i) = &H89: i = i + 1
    code(i) = &H44: i = i + 1
    code(i) = &H24: i = i + 1
    code(i) = &H20: i = i + 1
    
    ' 6th arg: mov rax, [r10+40]; mov [rsp+28h], rax
    code(i) = &H49: i = i + 1
    code(i) = &H8B: i = i + 1
    code(i) = &H42: i = i + 1
    code(i) = &H28: i = i + 1
    code(i) = &H48: i = i + 1
    code(i) = &H89: i = i + 1
    code(i) = &H44: i = i + 1
    code(i) = &H24: i = i + 1
    code(i) = &H28: i = i + 1
    
    ' 7th arg: mov rax, [r10+48]; mov [rsp+30h], rax
    code(i) = &H49: i = i + 1
    code(i) = &H8B: i = i + 1
    code(i) = &H42: i = i + 1
    code(i) = &H30: i = i + 1
    code(i) = &H48: i = i + 1
    code(i) = &H89: i = i + 1
    code(i) = &H44: i = i + 1
    code(i) = &H24: i = i + 1
    code(i) = &H30: i = i + 1
    
    ' 8th arg: mov rax, [r10+56]; mov [rsp+38h], rax
    code(i) = &H49: i = i + 1
    code(i) = &H8B: i = i + 1
    code(i) = &H42: i = i + 1
    code(i) = &H38: i = i + 1
    code(i) = &H48: i = i + 1
    code(i) = &H89: i = i + 1
    code(i) = &H44: i = i + 1
    code(i) = &H24: i = i + 1
    code(i) = &H38: i = i + 1
    
    ' 9th arg: mov rax, [r10+64]; mov [rsp+40h], rax
    code(i) = &H49: i = i + 1
    code(i) = &H8B: i = i + 1
    code(i) = &H42: i = i + 1
    code(i) = &H40: i = i + 1
    code(i) = &H48: i = i + 1
    code(i) = &H89: i = i + 1
    code(i) = &H44: i = i + 1
    code(i) = &H24: i = i + 1
    code(i) = &H40: i = i + 1
    
    ' 10th arg: mov rax, [r10+72]; mov [rsp+48h], rax
    code(i) = &H49: i = i + 1
    code(i) = &H8B: i = i + 1
    code(i) = &H42: i = i + 1
    code(i) = &H48: i = i + 1
    code(i) = &H48: i = i + 1
    code(i) = &H89: i = i + 1
    code(i) = &H44: i = i + 1
    code(i) = &H24: i = i + 1
    code(i) = &H48: i = i + 1
    
    ' 11th arg: mov rax, [r10+80]; mov [rsp+50h], rax
    code(i) = &H49: i = i + 1
    code(i) = &H8B: i = i + 1
    code(i) = &H42: i = i + 1
    code(i) = &H50: i = i + 1
    code(i) = &H48: i = i + 1
    code(i) = &H89: i = i + 1
    code(i) = &H44: i = i + 1
    code(i) = &H24: i = i + 1
    code(i) = &H50: i = i + 1
    
    ' mov rax, imm64 (target)
    code(i) = &H48: i = i + 1
    code(i) = &HB8: i = i + 1
    Dim t As LongLong: t = target
    RtlMoveMemoryFromPtr VarPtr(code(i)), t, 8
    i = i + 8
    
    ' call rax
    code(i) = &HFF: i = i + 1
    code(i) = &HD0: i = i + 1
    
    ' add rsp, 78h
    code(i) = &H48: i = i + 1
    code(i) = &H83: i = i + 1
    code(i) = &HC4: i = i + 1
    code(i) = &H78: i = i + 1
    
    ' ret
    code(i) = &HC3
    
    Dim mem As LongPtr
    mem = VirtualAlloc(0, 256, MEM_COMMIT Or MEM_RESERVE, PAGE_EXECUTE_READWRITE)
    If mem = 0 Then Err.Raise vbObjectError + 9002, , "VirtualAlloc failed for Thunk11"
    CopyMemory mem, VarPtr(code(0)), CLngPtr(i + 1)
    BuildThunk11 = mem
End Function

Private Sub FreeThunks()
    On Error Resume Next
    If p_thunk1 <> 0 Then VirtualFree p_thunk1, 0, MEM_RELEASE: p_thunk1 = 0
    If p_thunk2 <> 0 Then VirtualFree p_thunk2, 0, MEM_RELEASE: p_thunk2 = 0
    If p_thunk3 <> 0 Then VirtualFree p_thunk3, 0, MEM_RELEASE: p_thunk3 = 0
    If p_thunk4 <> 0 Then VirtualFree p_thunk4, 0, MEM_RELEASE: p_thunk4 = 0
    If p_thunk5 <> 0 Then VirtualFree p_thunk5, 0, MEM_RELEASE: p_thunk5 = 0
    If p_thunk6 <> 0 Then VirtualFree p_thunk6, 0, MEM_RELEASE: p_thunk6 = 0
    If p_thunk11 <> 0 Then VirtualFree p_thunk11, 0, MEM_RELEASE: p_thunk11 = 0
End Sub

' ============================================================
' HLSL Shader source
' ============================================================
Private Function GetShaderSource() As String
    GetShaderSource = _
        "struct VS_OUTPUT {" & vbLf & _
        "    float4 position : SV_POSITION;" & vbLf & _
        "    float4 color : COLOR0;" & vbLf & _
        "};" & vbLf & _
        "VS_OUTPUT VS(float4 position : POSITION, float4 color : COLOR) {" & vbLf & _
        "    VS_OUTPUT output = (VS_OUTPUT)0;" & vbLf & _
        "    output.position = position;" & vbLf & _
        "    output.color = color;" & vbLf & _
        "    return output;" & vbLf & _
        "}" & vbLf & _
        "float4 PS(VS_OUTPUT input) : SV_Target {" & vbLf & _
        "    return input.color;" & vbLf & _
        "}"
End Function

' ============================================================
' Compile shader using D3DCompile
' ============================================================
Private Function CompileShader(ByVal shaderSrc As String, ByVal entryPoint As String, ByVal profile As String) As LongPtr
    LogMsg "CompileShader: " & entryPoint & " / " & profile
    
    ' Load d3dcompiler_47.dll
    Dim hCompiler As LongPtr
    hCompiler = LoadLibraryW(StrPtr("d3dcompiler_47.dll"))
    If hCompiler = 0 Then
        LogMsg "Failed to load d3dcompiler_47.dll"
        Err.Raise vbObjectError + 8100, , "Failed to load d3dcompiler_47.dll"
    End If
    LogMsg "d3dcompiler_47.dll loaded: " & Hex$(hCompiler)
    
    ' Get D3DCompile address
    Dim procNameBytes() As Byte
    procNameBytes = AnsiZBytes("D3DCompile")
    Dim pD3DCompile As LongPtr
    pD3DCompile = GetProcAddress(hCompiler, VarPtr(procNameBytes(0)))
    If pD3DCompile = 0 Then
        FreeLibrary hCompiler
        Err.Raise vbObjectError + 8101, , "D3DCompile not found"
    End If
    LogMsg "D3DCompile address: " & Hex$(pD3DCompile)
    
    ' Build thunk for D3DCompile (11 args)
    If p_thunk11 <> 0 Then VirtualFree p_thunk11, 0, MEM_RELEASE
    p_thunk11 = BuildThunk11(pD3DCompile)
    LogMsg "Thunk11 built: " & Hex$(p_thunk11)
    
    ' Prepare args
    Dim srcBytes() As Byte
    srcBytes = AnsiZBytes(shaderSrc)
    
    Dim entryBytes() As Byte
    entryBytes = AnsiZBytes(entryPoint)
    
    Dim profileBytes() As Byte
    profileBytes = AnsiZBytes(profile)
    
    Dim pBlob As LongPtr: pBlob = 0
    Dim pErrorBlob As LongPtr: pErrorBlob = 0
    
    ' D3DCompile(pSrcData, SrcDataSize, pSourceName, pDefines, pInclude,
    '            pEntrypoint, pTarget, Flags1, Flags2, ppCode, ppErrorMsgs)
    Dim args As ThunkArgs11
    args.a1 = VarPtr(srcBytes(0))           ' pSrcData
    args.a2 = UBound(srcBytes)              ' SrcDataSize (without null terminator is fine)
    args.a3 = 0                              ' pSourceName
    args.a4 = 0                              ' pDefines
    args.a5 = 0                              ' pInclude
    args.a6 = VarPtr(entryBytes(0))          ' pEntrypoint
    args.a7 = VarPtr(profileBytes(0))        ' pTarget
    args.a8 = D3DCOMPILE_ENABLE_STRICTNESS   ' Flags1
    args.a9 = 0                              ' Flags2
    args.a10 = VarPtr(pBlob)                 ' ppCode
    args.a11 = VarPtr(pErrorBlob)            ' ppErrorMsgs
    
    Dim hr As Long
    hr = CLng(CallWindowProcW(p_thunk11, 0, 0, VarPtr(args), 0))
    LogMsg "D3DCompile returned: " & Hex$(hr)
    
    If hr < 0 Then
        ' Get error message
        If pErrorBlob <> 0 Then
            Dim errPtr As LongPtr
            errPtr = COM_Call1(pErrorBlob, VTBL_Blob_GetBufferPointer)
            Dim errMsg As String
            errMsg = PtrToAnsiString(errPtr)
            LogMsg "Shader compile error: " & errMsg
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
' Initialize DirectX 11
' ============================================================
Private Function InitD3D11(ByVal hWnd As LongPtr, ByVal Width As Long, ByVal Height As Long) As Boolean
    LogMsg "InitD3D11: start (" & Width & "x" & Height & ")"
    
    Dim hr As Long
    
    ' Setup swap chain description
    Dim sd As DXGI_SWAP_CHAIN_DESC
    sd.BufferDesc.Width = Width
    sd.BufferDesc.Height = Height
    sd.BufferDesc.RefreshRate.Numerator = 60
    sd.BufferDesc.RefreshRate.Denominator = 1
    sd.BufferDesc.Format = DXGI_FORMAT_R8G8B8A8_UNORM
    sd.BufferDesc.ScanlineOrdering = 0
    sd.BufferDesc.Scaling = 0
    sd.SampleDesc.Count = 1
    sd.SampleDesc.Quality = 0
    sd.BufferUsage = DXGI_USAGE_RENDER_TARGET_OUTPUT
    sd.BufferCount = 1
    sd.OutputWindow = hWnd
    sd.Windowed = 1
    sd.SwapEffect = 0  ' DXGI_SWAP_EFFECT_DISCARD
    sd.Flags = 0
    
    ' Feature levels
    Dim featureLevels(0) As Long
    featureLevels(0) = D3D_FEATURE_LEVEL_11_0
    
    Dim featureLevelOut As Long
    
    ' Create device and swap chain
    ' Args: pAdapter, DriverType, Software, Flags, pFeatureLevels, FeatureLevels,
    '       SDKVersion, pSwapChainDesc, ppSwapChain, ppDevice, pFeatureLevel, ppImmediateContext
    hr = D3D11CreateDeviceAndSwapChain( _
        0, _
        D3D_DRIVER_TYPE_HARDWARE, _
        0, _
        0, _
        VarPtr(featureLevels(0)), _
        1, _
        D3D11_SDK_VERSION, _
        sd, _
        g_pSwapChain, _
        g_pDevice, _
        featureLevelOut, _
        g_pContext)
    
    LogMsg "D3D11CreateDeviceAndSwapChain returned: " & Hex$(hr)
    LogMsg "Device=" & Hex$(g_pDevice) & ", Context=" & Hex$(g_pContext) & ", SwapChain=" & Hex$(g_pSwapChain)
    
    If hr < 0 Then
        LogMsg "Failed to create D3D11 device"
        InitD3D11 = False
        Exit Function
    End If
    
    ' Get back buffer
    Dim pBackBuffer As LongPtr
    Dim iid As GUID
    iid = IID_ID3D11Texture2D()
    
    ' IDXGISwapChain::GetBuffer(this, Buffer, riid, ppSurface)
    hr = CLng(COM_Call4(g_pSwapChain, VTBL_SwapChain_GetBuffer, 0, VarPtr(iid), VarPtr(pBackBuffer)))
    LogMsg "GetBuffer returned: " & Hex$(hr) & ", BackBuffer=" & Hex$(pBackBuffer)
    
    If hr < 0 Or pBackBuffer = 0 Then
        LogMsg "Failed to get back buffer"
        InitD3D11 = False
        Exit Function
    End If
    
    ' Create render target view
    ' ID3D11Device::CreateRenderTargetView(this, pResource, pDesc, ppRTView)
    LogMsg "Calling CreateRenderTargetView..."
    LogMsg "  Device=" & Hex$(g_pDevice) & ", BackBuffer=" & Hex$(pBackBuffer)
    
    hr = CLng(COM_Call4(g_pDevice, VTBL_Device_CreateRenderTargetView, pBackBuffer, 0, VarPtr(g_pRenderTargetView)))
    LogMsg "CreateRenderTargetView returned: " & Hex$(hr) & ", RTV=" & Hex$(g_pRenderTargetView)
    
    COM_Release pBackBuffer
    
    If hr < 0 Or g_pRenderTargetView = 0 Then
        LogMsg "Failed to create render target view"
        InitD3D11 = False
        Exit Function
    End If
    
    ' Set render target
    ' ID3D11DeviceContext::OMSetRenderTargets(this, NumViews, ppRenderTargetViews, pDepthStencilView)
    COM_Call4 g_pContext, VTBL_Context_OMSetRenderTargets, 1, VarPtr(g_pRenderTargetView), 0
    LogMsg "OMSetRenderTargets called"
    
    ' Setup viewport
    Dim vp As D3D11_VIEWPORT
    vp.TopLeftX = 0
    vp.TopLeftY = 0
    vp.Width = CSng(Width)
    vp.Height = CSng(Height)
    vp.MinDepth = 0!
    vp.MaxDepth = 1!
    
    ' ID3D11DeviceContext::RSSetViewports(this, NumViewports, pViewports)
    COM_Call3 g_pContext, VTBL_Context_RSSetViewports, 1, VarPtr(vp)
    LogMsg "RSSetViewports called"
    
    InitD3D11 = True
    LogMsg "InitD3D11: done"
End Function

' ============================================================
' Create shaders
' ============================================================
Private Function CreateShaders() As Boolean
    LogMsg "CreateShaders: start"
    
    Dim shaderSrc As String
    shaderSrc = GetShaderSource()
    
    ' Compile vertex shader
    Dim pVSBlob As LongPtr
    pVSBlob = CompileShader(shaderSrc, "VS", "vs_4_0")
    If pVSBlob = 0 Then
        CreateShaders = False
        Exit Function
    End If
    
    ' Get VS bytecode
    Dim vsCodePtr As LongPtr
    vsCodePtr = COM_Call1(pVSBlob, VTBL_Blob_GetBufferPointer)
    Dim vsCodeSize As LongPtr
    vsCodeSize = COM_Call1(pVSBlob, VTBL_Blob_GetBufferSize)
    LogMsg "VS bytecode: ptr=" & Hex$(vsCodePtr) & ", size=" & vsCodeSize
    
    ' Create vertex shader using thunk (5 args)
    ' ID3D11Device::CreateVertexShader(this, pShaderBytecode, BytecodeLength, pClassLinkage, ppVertexShader)
    Dim methodAddr As LongPtr
    methodAddr = GetVTableMethod(g_pDevice, VTBL_Device_CreateVertexShader)
    
    If p_thunk5 <> 0 Then VirtualFree p_thunk5, 0, MEM_RELEASE
    p_thunk5 = BuildThunk5(methodAddr)
    
    Dim args5 As ThunkArgs5
    args5.a1 = g_pDevice
    args5.a2 = vsCodePtr
    args5.a3 = vsCodeSize
    args5.a4 = 0
    args5.a5 = VarPtr(g_pVertexShader)
    
    Dim hr As Long
    hr = CLng(CallWindowProcW(p_thunk5, 0, 0, VarPtr(args5), 0))
    LogMsg "CreateVertexShader returned: " & Hex$(hr) & ", VS=" & Hex$(g_pVertexShader)
    
    If hr < 0 Then
        COM_Release pVSBlob
        CreateShaders = False
        Exit Function
    End If
    
    ' Create input layout using thunk (6 args)
    ' ID3D11Device::CreateInputLayout(this, pInputElementDescs, NumElements,
    '                                  pShaderBytecodeWithInputSignature, BytecodeLength, ppInputLayout)
    
    ' Prepare semantic name strings (must persist during call)
    g_semanticPosition = AnsiZBytes("POSITION")
    g_semanticColor = AnsiZBytes("COLOR")
    
    ' Input element descriptors
    Dim layout(0 To 1) As D3D11_INPUT_ELEMENT_DESC
    
    ' POSITION
    layout(0).SemanticName = VarPtr(g_semanticPosition(0))
    layout(0).SemanticIndex = 0
    layout(0).Format = DXGI_FORMAT_R32G32B32_FLOAT
    layout(0).InputSlot = 0
    layout(0).AlignedByteOffset = 0
    layout(0).InputSlotClass = D3D11_INPUT_PER_VERTEX_DATA
    layout(0).InstanceDataStepRate = 0
    
    ' COLOR
    layout(1).SemanticName = VarPtr(g_semanticColor(0))
    layout(1).SemanticIndex = 0
    layout(1).Format = DXGI_FORMAT_R32G32B32A32_FLOAT
    layout(1).InputSlot = 0
    layout(1).AlignedByteOffset = 12  ' offset after POSITION (3 floats = 12 bytes)
    layout(1).InputSlotClass = D3D11_INPUT_PER_VERTEX_DATA
    layout(1).InstanceDataStepRate = 0
    
    methodAddr = GetVTableMethod(g_pDevice, VTBL_Device_CreateInputLayout)
    
    If p_thunk6 <> 0 Then VirtualFree p_thunk6, 0, MEM_RELEASE
    p_thunk6 = BuildThunk6(methodAddr)
    
    Dim args6 As ThunkArgs6
    args6.a1 = g_pDevice
    args6.a2 = VarPtr(layout(0))
    args6.a3 = 2  ' NumElements
    args6.a4 = vsCodePtr
    args6.a5 = vsCodeSize
    args6.a6 = VarPtr(g_pInputLayout)
    
    hr = CLng(CallWindowProcW(p_thunk6, 0, 0, VarPtr(args6), 0))
    LogMsg "CreateInputLayout returned: " & Hex$(hr) & ", IL=" & Hex$(g_pInputLayout)
    
    COM_Release pVSBlob
    
    If hr < 0 Then
        CreateShaders = False
        Exit Function
    End If
    
    ' Compile pixel shader
    Dim pPSBlob As LongPtr
    pPSBlob = CompileShader(shaderSrc, "PS", "ps_4_0")
    If pPSBlob = 0 Then
        CreateShaders = False
        Exit Function
    End If
    
    ' Get PS bytecode
    Dim psCodePtr As LongPtr
    psCodePtr = COM_Call1(pPSBlob, VTBL_Blob_GetBufferPointer)
    Dim psCodeSize As LongPtr
    psCodeSize = COM_Call1(pPSBlob, VTBL_Blob_GetBufferSize)
    LogMsg "PS bytecode: ptr=" & Hex$(psCodePtr) & ", size=" & psCodeSize
    
    ' Create pixel shader using thunk (5 args)
    methodAddr = GetVTableMethod(g_pDevice, VTBL_Device_CreatePixelShader)
    
    If p_thunk5 <> 0 Then VirtualFree p_thunk5, 0, MEM_RELEASE
    p_thunk5 = BuildThunk5(methodAddr)
    
    args5.a1 = g_pDevice
    args5.a2 = psCodePtr
    args5.a3 = psCodeSize
    args5.a4 = 0
    args5.a5 = VarPtr(g_pPixelShader)
    
    hr = CLng(CallWindowProcW(p_thunk5, 0, 0, VarPtr(args5), 0))
    LogMsg "CreatePixelShader returned: " & Hex$(hr) & ", PS=" & Hex$(g_pPixelShader)
    
    COM_Release pPSBlob
    
    If hr < 0 Then
        CreateShaders = False
        Exit Function
    End If
    
    CreateShaders = True
    LogMsg "CreateShaders: done"
End Function

' ============================================================
' Create vertex buffer
' ============================================================
Private Function CreateVertexBuffer() As Boolean
    LogMsg "CreateVertexBuffer: start"
    
    ' Triangle vertices (position + color)
    Dim vertices(0 To 2) As VERTEX
    
    ' Top vertex - Red
    vertices(0).x = 0!
    vertices(0).y = 0.5!
    vertices(0).z = 0.5!
    vertices(0).r = 1!
    vertices(0).g = 0!
    vertices(0).b = 0!
    vertices(0).a = 1!
    
    ' Bottom right - Green
    vertices(1).x = 0.5!
    vertices(1).y = -0.5!
    vertices(1).z = 0.5!
    vertices(1).r = 0!
    vertices(1).g = 1!
    vertices(1).b = 0!
    vertices(1).a = 1!
    
    ' Bottom left - Blue
    vertices(2).x = -0.5!
    vertices(2).y = -0.5!
    vertices(2).z = 0.5!
    vertices(2).r = 0!
    vertices(2).g = 0!
    vertices(2).b = 1!
    vertices(2).a = 1!
    
    Dim vertexSize As Long
    vertexSize = LenB(vertices(0))
    LogMsg "Vertex size: " & vertexSize & " bytes"
    
    ' Buffer description
    Dim bd As D3D11_BUFFER_DESC
    bd.ByteWidth = vertexSize * 3
    bd.Usage = D3D11_USAGE_DEFAULT
    bd.BindFlags = D3D11_BIND_VERTEX_BUFFER
    bd.CPUAccessFlags = 0
    bd.MiscFlags = 0
    bd.StructureByteStride = 0
    
    ' Subresource data
    Dim initData As D3D11_SUBRESOURCE_DATA
    initData.pSysMem = VarPtr(vertices(0))
    initData.SysMemPitch = 0
    initData.SysMemSlicePitch = 0
    
    ' ID3D11Device::CreateBuffer(this, pDesc, pInitialData, ppBuffer)
    Dim hr As Long
    hr = CLng(COM_Call4(g_pDevice, VTBL_Device_CreateBuffer, VarPtr(bd), VarPtr(initData), VarPtr(g_pVertexBuffer)))
    LogMsg "CreateBuffer returned: " & Hex$(hr) & ", VB=" & Hex$(g_pVertexBuffer)
    
    If hr < 0 Or g_pVertexBuffer = 0 Then
        CreateVertexBuffer = False
        Exit Function
    End If
    
    CreateVertexBuffer = True
    LogMsg "CreateVertexBuffer: done"
End Function

' ============================================================
' Setup pipeline
' ============================================================
Private Sub SetupPipeline()
    LogMsg "SetupPipeline: start"
    
    ' Set input layout
    ' ID3D11DeviceContext::IASetInputLayout(this, pInputLayout)
    LogMsg "  Calling IASetInputLayout..."
    COM_Call2 g_pContext, VTBL_Context_IASetInputLayout, g_pInputLayout
    LogMsg "  IASetInputLayout done"
    
    ' Set primitive topology
    ' ID3D11DeviceContext::IASetPrimitiveTopology(this, Topology)
    LogMsg "  Calling IASetPrimitiveTopology..."
    COM_Call2 g_pContext, VTBL_Context_IASetPrimitiveTopology, D3D11_PRIMITIVE_TOPOLOGY_TRIANGLELIST
    LogMsg "  IASetPrimitiveTopology done"
    
    ' Set vertex buffer using thunk (6 args)
    ' ID3D11DeviceContext::IASetVertexBuffers(this, StartSlot, NumBuffers, ppVertexBuffers, pStrides, pOffsets)
    LogMsg "  Calling IASetVertexBuffers..."
    Dim stride As Long: stride = 28  ' sizeof(VERTEX) = 7 floats * 4 bytes
    Dim offset As Long: offset = 0
    
    Dim methodAddr As LongPtr
    methodAddr = GetVTableMethod(g_pContext, VTBL_Context_IASetVertexBuffers)
    LogMsg "    IASetVertexBuffers method addr=" & Hex$(methodAddr)
    
    If p_thunk6 <> 0 Then VirtualFree p_thunk6, 0, MEM_RELEASE
    p_thunk6 = BuildThunk6(methodAddr)
    LogMsg "    Thunk6 built=" & Hex$(p_thunk6)
    
    Dim args6 As ThunkArgs6
    args6.a1 = g_pContext
    args6.a2 = 0  ' StartSlot
    args6.a3 = 1  ' NumBuffers
    args6.a4 = VarPtr(g_pVertexBuffer)
    args6.a5 = VarPtr(stride)
    args6.a6 = VarPtr(offset)
    
    LogMsg "    Calling thunk6..."
    CallWindowProcW p_thunk6, 0, 0, VarPtr(args6), 0
    LogMsg "  IASetVertexBuffers done"
    
    ' Set shaders
    ' ID3D11DeviceContext::VSSetShader(this, pVertexShader, ppClassInstances, NumClassInstances)
    LogMsg "  Calling VSSetShader..."
    COM_Call4 g_pContext, VTBL_Context_VSSetShader, g_pVertexShader, 0, 0
    LogMsg "  VSSetShader done"
    
    ' ID3D11DeviceContext::PSSetShader(this, pPixelShader, ppClassInstances, NumClassInstances)
    LogMsg "  Calling PSSetShader..."
    COM_Call4 g_pContext, VTBL_Context_PSSetShader, g_pPixelShader, 0, 0
    LogMsg "  PSSetShader done"
    
    LogMsg "SetupPipeline: done"
End Sub

' ============================================================
' Render frame
' ============================================================
Private Sub RenderFrame()
    ' Clear render target to white
    Dim clearColor(0 To 3) As Single
    clearColor(0) = 1!  ' R
    clearColor(1) = 1!  ' G
    clearColor(2) = 1!  ' B
    clearColor(3) = 1!  ' A
    
    ' ID3D11DeviceContext::ClearRenderTargetView(this, pRenderTargetView, ColorRGBA)
    COM_Call3 g_pContext, VTBL_Context_ClearRenderTargetView, g_pRenderTargetView, VarPtr(clearColor(0))
    
    ' Draw triangle
    ' ID3D11DeviceContext::Draw(this, VertexCount, StartVertexLocation)
    COM_Call3 g_pContext, VTBL_Context_Draw, 3, 0
    
    ' Present
    ' IDXGISwapChain::Present(this, SyncInterval, Flags)
    COM_Call3 g_pSwapChain, VTBL_SwapChain_Present, 0, 0
End Sub

' ============================================================
' Cleanup
' ============================================================
Private Sub CleanupD3D11()
    LogMsg "CleanupD3D11: start"
    
    If g_pVertexBuffer <> 0 Then COM_Release g_pVertexBuffer: g_pVertexBuffer = 0
    If g_pInputLayout <> 0 Then COM_Release g_pInputLayout: g_pInputLayout = 0
    If g_pPixelShader <> 0 Then COM_Release g_pPixelShader: g_pPixelShader = 0
    If g_pVertexShader <> 0 Then COM_Release g_pVertexShader: g_pVertexShader = 0
    If g_pRenderTargetView <> 0 Then COM_Release g_pRenderTargetView: g_pRenderTargetView = 0
    If g_pSwapChain <> 0 Then COM_Release g_pSwapChain: g_pSwapChain = 0
    If g_pContext <> 0 Then COM_Release g_pContext: g_pContext = 0
    If g_pDevice <> 0 Then COM_Release g_pDevice: g_pDevice = 0
    
    LogMsg "CleanupD3D11: done"
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
                            CW_USEDEFAULT, CW_USEDEFAULT, 640, 480, 0, 0, hInstance, 0)
    LogMsg "CreateWindowExW hWnd=" & Hex$(g_hWnd)
    If g_hWnd = 0 Then
        LogMsg "CreateWindowExW failed. GetLastError=" & GetLastError()
        MsgBox "CreateWindowExW failed.", vbCritical
        GoTo FIN
    End If

    ShowWindow g_hWnd, SW_SHOWDEFAULT
    UpdateWindow g_hWnd
    LogMsg "ShowWindow/UpdateWindow OK"

    ' Get client rect for D3D11 init
    Dim rc As RECT
    GetClientRect g_hWnd, rc
    Dim clientWidth As Long, clientHeight As Long
    clientWidth = rc.Right - rc.Left
    clientHeight = rc.Bottom - rc.Top
    LogMsg "Client size: " & clientWidth & "x" & clientHeight

    ' Initialize D3D11
    If Not InitD3D11(g_hWnd, clientWidth, clientHeight) Then
        MsgBox "Failed to initialize DirectX 11.", vbCritical
        GoTo FIN
    End If

    ' Create shaders
    If Not CreateShaders() Then
        MsgBox "Failed to create shaders.", vbCritical
        GoTo FIN
    End If

    ' Create vertex buffer
    If Not CreateVertexBuffer() Then
        MsgBox "Failed to create vertex buffer.", vbCritical
        GoTo FIN
    End If

    ' Setup pipeline
    SetupPipeline

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

            Sleep 1
        End If
    Loop

FIN:
    LogMsg "Cleanup: start"
    FreeThunks
    CleanupD3D11
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
