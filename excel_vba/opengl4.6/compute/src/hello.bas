Attribute VB_Name = "hello"
Option Explicit

' ============================================================
'  Excel VBA (64-bit) + Raw OpenGL 4.6 Core Profile
'   - Compute shader Harmonograph
'   - FIXED: Thunk copy size bug (ret instruction was not copied)
' ============================================================

' -----------------------------
' Win32 constants
' -----------------------------
Private Const PM_REMOVE As Long = &H1&
Private Const WM_QUIT  As Long = &H12&
Private Const WM_DESTROY As Long = &H2&
Private Const WM_CLOSE   As Long = &H10&
Private Const WM_SIZE    As Long = &H5&
Private Const WM_KEYDOWN As Long = &H100&
Private Const VK_ESCAPE  As Long = &H1B&

Private Const CS_VREDRAW As Long = &H1&
Private Const CS_HREDRAW As Long = &H2&
Private Const CS_OWNDC   As Long = &H20&

Private Const IDI_APPLICATION As Long = 32512&
Private Const IDC_ARROW       As Long = 32512&

Private Const COLOR_WINDOW As Long = 5&
Private Const CW_USEDEFAULT As Long = &H80000000

Private Const WS_OVERLAPPED As Long = &H0&
Private Const WS_MAXIMIZEBOX As Long = &H10000
Private Const WS_MINIMIZEBOX As Long = &H20000
Private Const WS_THICKFRAME  As Long = &H40000
Private Const WS_SYSMENU     As Long = &H80000
Private Const WS_CAPTION     As Long = &HC00000
Private Const WS_OVERLAPPEDWINDOW As Long = (WS_OVERLAPPED Or WS_CAPTION Or WS_SYSMENU Or WS_THICKFRAME Or WS_MINIMIZEBOX Or WS_MAXIMIZEBOX)

Private Const SW_SHOWDEFAULT As Long = 10

' -----------------------------
' Pixel format flags
' -----------------------------
Private Const PFD_DOUBLEBUFFER As Long = 1
Private Const PFD_DRAW_TO_WINDOW As Long = 4
Private Const PFD_SUPPORT_OPENGL As Long = 32

' -----------------------------
' OpenGL constants
' -----------------------------
Private Const GL_COLOR_BUFFER_BIT As Long = &H4000&
Private Const GL_DEPTH_BUFFER_BIT As Long = &H100&

Private Const GL_VENDOR   As Long = &H1F00&
Private Const GL_RENDERER As Long = &H1F01&
Private Const GL_VERSION  As Long = &H1F02&
Private Const GL_SHADING_LANGUAGE_VERSION As Long = &H8B8C&

Private Const GL_VERTEX_SHADER   As Long = &H8B31&
Private Const GL_FRAGMENT_SHADER As Long = &H8B30&
Private Const GL_COMPUTE_SHADER  As Long = &H91B9&
Private Const GL_COMPILE_STATUS  As Long = &H8B81&
Private Const GL_LINK_STATUS     As Long = &H8B82&
Private Const GL_INFO_LOG_LENGTH As Long = &H8B84&

Private Const GL_DYNAMIC_DRAW As Long = &H88E8&
Private Const GL_SHADER_STORAGE_BUFFER As Long = &H90D2&
Private Const GL_SHADER_STORAGE_BARRIER_BIT As Long = &H2000&
Private Const GL_LINE_STRIP As Long = &H3&

' -----------------------------
' WGL_ARB_create_context constants
' -----------------------------
Private Const WGL_CONTEXT_MAJOR_VERSION_ARB As Long = &H2091&
Private Const WGL_CONTEXT_MINOR_VERSION_ARB As Long = &H2092&
Private Const WGL_CONTEXT_FLAGS_ARB As Long = &H2094&
Private Const WGL_CONTEXT_PROFILE_MASK_ARB As Long = &H9126&
Private Const WGL_CONTEXT_CORE_PROFILE_BIT_ARB As Long = &H1&

' -----------------------------
' Class / window names
' -----------------------------
Private Const CLASS_NAME As String = "helloWindowVBA_GL46_Harmo"
Private Const WINDOW_NAME As String = "Hello OpenGL 4.6 Compute Harmonograph (VBA64)"

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

Private Type PIXELFORMATDESCRIPTOR
    nSize As Integer
    nVersion As Integer
    dwFlags As Long
    iPixelType As Byte
    cColorBits As Byte
    cRedBits As Byte
    cRedShift As Byte
    cGreenBits As Byte
    cGreenShift As Byte
    cBlueBits As Byte
    cBlueShift As Byte
    cAlphaBits As Byte
    cAlphaShift As Byte
    cAccumBits As Byte
    cAccumRedBits As Byte
    cAccumGreenBits As Byte
    cAccumBlueBits As Byte
    cAccumAlphaBits As Byte
    cDepthBits As Byte
    cStencilBits As Byte
    cAuxBuffers As Byte
    iLayerType As Byte
    bReserved As Byte
    dwLayerMask As Long
    dwVisibleMask As Long
    dwDamageMask As Long
End Type

' -----------------------------
' Globals
' -----------------------------
Private g_hWnd As LongPtr
Private g_hDC  As LongPtr
Private g_hRC  As LongPtr

' GL objects
Private g_progDraw As Long
Private g_progComp As Long
Private g_vao As Long
Private g_ssboPos As Long
Private g_ssboCol As Long

' Number of points
Private Const MAX_NUM As Long = 500000

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

' Thunks
Private p_thunkGen2 As LongPtr
Private p_thunkUniform1f As LongPtr
Private p_thunkUniform2f As LongPtr
Private p_thunkUniform1ui As LongPtr

' Function pointers
Private p_wglCreateContextAttribsARB As LongPtr

Private p_glGenBuffers As LongPtr
Private p_glBindBuffer As LongPtr
Private p_glBufferData As LongPtr
Private p_glBindBufferBase As LongPtr

Private p_glCreateShader As LongPtr
Private p_glShaderSource As LongPtr
Private p_glCompileShader As LongPtr
Private p_glGetShaderiv As LongPtr
Private p_glGetShaderInfoLog As LongPtr
Private p_glDeleteShader As LongPtr

Private p_glCreateProgram As LongPtr
Private p_glAttachShader As LongPtr
Private p_glLinkProgram As LongPtr
Private p_glUseProgram As LongPtr
Private p_glGetProgramiv As LongPtr
Private p_glGetProgramInfoLog As LongPtr

Private p_glGenVertexArrays As LongPtr
Private p_glBindVertexArray As LongPtr

Private p_glDispatchCompute As LongPtr
Private p_glMemoryBarrier As LongPtr

Private p_glUniform1f As LongPtr
Private p_glUniform2f As LongPtr
Private p_glUniform1ui As LongPtr

' Explicit uniform locations
Private Const LOC_RESOLUTION As Long = 0

Private Const LOC_MAX_NUM As Long = 0
Private Const LOC_A1 As Long = 1
Private Const LOC_F1 As Long = 2
Private Const LOC_P1 As Long = 3
Private Const LOC_D1 As Long = 4
Private Const LOC_A2 As Long = 5
Private Const LOC_F2 As Long = 6
Private Const LOC_P2 As Long = 7
Private Const LOC_D2 As Long = 8
Private Const LOC_A3 As Long = 9
Private Const LOC_F3 As Long = 10
Private Const LOC_P3 As Long = 11
Private Const LOC_D3 As Long = 12
Private Const LOC_A4 As Long = 13
Private Const LOC_F4 As Long = 14
Private Const LOC_P4 As Long = 15
Private Const LOC_D4 As Long = 16

' Harmonograph params
Private A1 As Single, f1 As Single, p1 As Single, d1 As Single
Private A2 As Single, f2 As Single, p2 As Single, d2 As Single
Private A3 As Single, f3 As Single, p3 As Single, d3 As Single
Private A4 As Single, f4 As Single, p4 As Single, d4 As Single

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

    Private Declare PtrSafe Function GetDC Lib "user32" (ByVal hWnd As LongPtr) As LongPtr
    Private Declare PtrSafe Function ReleaseDC Lib "user32" (ByVal hWnd As LongPtr, ByVal hDC As LongPtr) As Long
    Private Declare PtrSafe Function GetClientRect Lib "user32" (ByVal hWnd As LongPtr, ByRef lpRect As RECT) As Long
    Private Declare PtrSafe Function SetWindowTextA Lib "user32" (ByVal hWnd As LongPtr, ByVal lpString As LongPtr) As Long

    Private Declare PtrSafe Function ChoosePixelFormat Lib "gdi32" (ByVal hDC As LongPtr, ByRef pfd As PIXELFORMATDESCRIPTOR) As Long
    Private Declare PtrSafe Function SetPixelFormat Lib "gdi32" (ByVal hDC As LongPtr, ByVal iPixelFormat As Long, ByRef pfd As PIXELFORMATDESCRIPTOR) As Long
    Private Declare PtrSafe Function SwapBuffers Lib "gdi32" (ByVal hDC As LongPtr) As Long

    Private Declare PtrSafe Sub Sleep Lib "kernel32" (ByVal dwMilliseconds As Long)
    Private Declare PtrSafe Function GetLastError Lib "kernel32" () As Long
    Private Declare PtrSafe Function GetTickCount Lib "kernel32" () As Long

    Private Declare PtrSafe Function CallWindowProcW Lib "user32" ( _
        ByVal lpPrevWndFunc As LongPtr, _
        ByVal hWnd As LongPtr, _
        ByVal msg As LongPtr, _
        ByVal wParam As LongPtr, _
        ByVal lParam As LongPtr) As LongPtr

    ' WGL
    Private Declare PtrSafe Function wglCreateContext Lib "opengl32.dll" (ByVal hDC As LongPtr) As LongPtr
    Private Declare PtrSafe Function wglMakeCurrent Lib "opengl32.dll" (ByVal hDC As LongPtr, ByVal hGLRC As LongPtr) As Long
    Private Declare PtrSafe Function wglDeleteContext Lib "opengl32.dll" (ByVal hGLRC As LongPtr) As Long
    Private Declare PtrSafe Function wglGetProcAddress Lib "opengl32.dll" (ByVal lpszProc As LongPtr) As LongPtr

    ' OpenGL 1.1 exports
    Private Declare PtrSafe Sub glViewport Lib "opengl32.dll" (ByVal x As Long, ByVal y As Long, ByVal Width As Long, ByVal Height As Long)
    Private Declare PtrSafe Sub glClear Lib "opengl32.dll" (ByVal Mask As Long)
    Private Declare PtrSafe Sub glClearColor Lib "opengl32.dll" (ByVal r As Single, ByVal g As Single, ByVal b As Single, ByVal a As Single)
    Private Declare PtrSafe Function glGetString Lib "opengl32.dll" (ByVal name As Long) As LongPtr
    Private Declare PtrSafe Sub glDrawArrays Lib "opengl32.dll" (ByVal mode As Long, ByVal first As Long, ByVal count As Long)

    ' Logger / memory utils
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
    g_log = CreateFileW(StrPtr("C:\TEMP\debug.log"), GENERIC_WRITE, FILE_SHARE_READ Or FILE_SHARE_WRITE, 0, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, 0)
    If g_log = 0 Or g_log = -1 Then g_log = 0
    LogMsg "==== LOG START ===="
End Sub

Private Sub LogClose()
    On Error Resume Next
    If g_log <> 0 Then
        LogMsg "==== LOG END ===="
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
' Helpers
' ============================================================
Private Function AnsiZBytes(ByVal s As String) As Byte()
    AnsiZBytes = StrConv(s & vbNullChar, vbFromUnicode)
End Function

Private Function GetGLProc(ByVal name As String) As LongPtr
    Dim b() As Byte
    b = AnsiZBytes(name)
    GetGLProc = wglGetProcAddress(VarPtr(b(0)))
End Function

' ============================================================
' CallWindowProc-based generic calls
' ============================================================
Private Function GL_Call0(ByVal proc As LongPtr) As LongPtr
    GL_Call0 = CallWindowProcW(proc, 0, 0, 0, 0)
End Function
Private Function GL_Call1(ByVal proc As LongPtr, ByVal a1 As LongPtr) As LongPtr
    GL_Call1 = CallWindowProcW(proc, a1, 0, 0, 0)
End Function
Private Function GL_Call2(ByVal proc As LongPtr, ByVal a1 As LongPtr, ByVal a2 As LongPtr) As LongPtr
    GL_Call2 = CallWindowProcW(proc, a1, a2, 0, 0)
End Function
Private Function GL_Call3(ByVal proc As LongPtr, ByVal a1 As LongPtr, ByVal a2 As LongPtr, ByVal a3 As LongPtr) As LongPtr
    GL_Call3 = CallWindowProcW(proc, a1, a2, a3, 0)
End Function
Private Function GL_Call4(ByVal proc As LongPtr, ByVal a1 As LongPtr, ByVal a2 As LongPtr, ByVal a3 As LongPtr, ByVal a4 As LongPtr) As LongPtr
    GL_Call4 = CallWindowProcW(proc, a1, a2, a3, a4)
End Function

' ============================================================
' Float bit helpers
' ============================================================
Private Function SingleToLongPtr(ByVal f As Single) As LongPtr
    Dim l As Long
    CopyMemory VarPtr(l), VarPtr(f), 4
    SingleToLongPtr = CLngPtr(l And &HFFFFFFFF)
End Function

' ============================================================
' Thunks - FIXED: use explicit byte count to ensure ret is copied
'
' Thunk calling convention via CallWindowProcW:
'   CallWindowProcW(thunk, hWnd, msg, wParam, lParam)
'   Inside thunk:
'     RCX = hWnd
'     RDX = msg
'     R8  = wParam
'     R9  = lParam
' ============================================================

' Gen2: void glGenXxx(GLsizei n, GLuint* ids)
'   n from RDX (msg), ids from R8 (wParam)
Private Function BuildThunk_Gen2(ByVal target As LongPtr) As LongPtr
    ' Total size: 29 bytes
    Dim code(0 To 31) As Byte
    
    ' sub rsp, 28h (4 bytes)
    code(0) = &H48
    code(1) = &H83
    code(2) = &HEC
    code(3) = &H28
    
    ' mov ecx, edx - n from msg (2 bytes)
    code(4) = &H89
    code(5) = &HD1
    
    ' mov rdx, r8 - ids from wParam (3 bytes)
    code(6) = &H4C
    code(7) = &H89
    code(8) = &HC2
    
    ' mov rax, imm64 (10 bytes)
    code(9) = &H48
    code(10) = &HB8
    Dim t As LongLong: t = target
    RtlMoveMemory code(11), VarPtr(t), 8
    
    ' call rax (2 bytes)
    code(19) = &HFF
    code(20) = &HD0
    
    ' add rsp, 28h (4 bytes)
    code(21) = &H48
    code(22) = &H83
    code(23) = &HC4
    code(24) = &H28
    
    ' xor eax, eax (2 bytes)
    code(25) = &H33
    code(26) = &HC0
    
    ' ret (1 byte)
    code(27) = &HC3

    Dim mem As LongPtr
    mem = VirtualAlloc(0, 64, MEM_COMMIT Or MEM_RESERVE, PAGE_EXECUTE_READWRITE)
    If mem = 0 Then Err.Raise vbObjectError + 9000, , "VirtualAlloc failed (Gen2 thunk)"
    CopyMemory mem, VarPtr(code(0)), 28
    BuildThunk_Gen2 = mem
End Function

' Uniform1f: void glUniform1f(GLint loc, GLfloat v)
'   loc from RDX (msg), v from R8 (wParam) -> XMM1
Private Function BuildThunk_Uniform1f(ByVal target As LongPtr) As LongPtr
    ' Total size: 30 bytes
    Dim code(0 To 31) As Byte
    
    ' sub rsp, 28h (4 bytes)
    code(0) = &H48
    code(1) = &H83
    code(2) = &HEC
    code(3) = &H28
    
    ' mov ecx, edx - loc from msg (2 bytes)
    code(4) = &H89
    code(5) = &HD1
    
    ' movd xmm1, r8d - float bits from wParam (5 bytes)
    code(6) = &H66
    code(7) = &H41
    code(8) = &HF
    code(9) = &H6E
    code(10) = &HC8
    
    ' mov rax, imm64 (10 bytes)
    code(11) = &H48
    code(12) = &HB8
    Dim t As LongLong: t = target
    RtlMoveMemory code(13), VarPtr(t), 8
    
    ' call rax (2 bytes)
    code(21) = &HFF
    code(22) = &HD0
    
    ' add rsp, 28h (4 bytes)
    code(23) = &H48
    code(24) = &H83
    code(25) = &HC4
    code(26) = &H28
    
    ' xor eax, eax (2 bytes)
    code(27) = &H33
    code(28) = &HC0
    
    ' ret (1 byte)
    code(29) = &HC3

    Dim mem As LongPtr
    mem = VirtualAlloc(0, 64, MEM_COMMIT Or MEM_RESERVE, PAGE_EXECUTE_READWRITE)
    If mem = 0 Then Err.Raise vbObjectError + 9001, , "VirtualAlloc failed (Uniform1f thunk)"
    CopyMemory mem, VarPtr(code(0)), 30
    BuildThunk_Uniform1f = mem
End Function

' Uniform2f: void glUniform2f(GLint loc, GLfloat v0, GLfloat v1)
'   loc from RDX (msg), v0 from R8 (wParam) -> XMM1, v1 from R9 (lParam) -> XMM2
Private Function BuildThunk_Uniform2f(ByVal target As LongPtr) As LongPtr
    ' Total size: 35 bytes
    Dim code(0 To 39) As Byte
    
    ' sub rsp, 28h (4 bytes)
    code(0) = &H48
    code(1) = &H83
    code(2) = &HEC
    code(3) = &H28
    
    ' mov ecx, edx - loc from msg (2 bytes)
    code(4) = &H89
    code(5) = &HD1
    
    ' movd xmm1, r8d - v0 from wParam (5 bytes)
    code(6) = &H66
    code(7) = &H41
    code(8) = &HF
    code(9) = &H6E
    code(10) = &HC8
    
    ' movd xmm2, r9d - v1 from lParam (5 bytes)
    code(11) = &H66
    code(12) = &H41
    code(13) = &HF
    code(14) = &H6E
    code(15) = &HD1
    
    ' mov rax, imm64 (10 bytes)
    code(16) = &H48
    code(17) = &HB8
    Dim t As LongLong: t = target
    RtlMoveMemory code(18), VarPtr(t), 8
    
    ' call rax (2 bytes)
    code(26) = &HFF
    code(27) = &HD0
    
    ' add rsp, 28h (4 bytes)
    code(28) = &H48
    code(29) = &H83
    code(30) = &HC4
    code(31) = &H28
    
    ' xor eax, eax (2 bytes)
    code(32) = &H33
    code(33) = &HC0
    
    ' ret (1 byte)
    code(34) = &HC3

    Dim mem As LongPtr
    mem = VirtualAlloc(0, 64, MEM_COMMIT Or MEM_RESERVE, PAGE_EXECUTE_READWRITE)
    If mem = 0 Then Err.Raise vbObjectError + 9002, , "VirtualAlloc failed (Uniform2f thunk)"
    CopyMemory mem, VarPtr(code(0)), 35
    BuildThunk_Uniform2f = mem
End Function

' Uniform1ui: void glUniform1ui(GLint loc, GLuint v)
'   loc from RDX (msg), v from R8 (wParam)
Private Function BuildThunk_Uniform1ui(ByVal target As LongPtr) As LongPtr
    ' Total size: 28 bytes
    Dim code(0 To 31) As Byte
    
    ' sub rsp, 28h (4 bytes)
    code(0) = &H48
    code(1) = &H83
    code(2) = &HEC
    code(3) = &H28
    
    ' mov ecx, edx - loc from msg (2 bytes)
    code(4) = &H89
    code(5) = &HD1
    
    ' mov edx, r8d - v from wParam (3 bytes)
    code(6) = &H44
    code(7) = &H89
    code(8) = &HC2
    
    ' mov rax, imm64 (10 bytes)
    code(9) = &H48
    code(10) = &HB8
    Dim t As LongLong: t = target
    RtlMoveMemory code(11), VarPtr(t), 8
    
    ' call rax (2 bytes)
    code(19) = &HFF
    code(20) = &HD0
    
    ' add rsp, 28h (4 bytes)
    code(21) = &H48
    code(22) = &H83
    code(23) = &HC4
    code(24) = &H28
    
    ' xor eax, eax (2 bytes)
    code(25) = &H33
    code(26) = &HC0
    
    ' ret (1 byte)
    code(27) = &HC3

    Dim mem As LongPtr
    mem = VirtualAlloc(0, 64, MEM_COMMIT Or MEM_RESERVE, PAGE_EXECUTE_READWRITE)
    If mem = 0 Then Err.Raise vbObjectError + 9003, , "VirtualAlloc failed (Uniform1ui thunk)"
    CopyMemory mem, VarPtr(code(0)), 28
    BuildThunk_Uniform1ui = mem
End Function

Private Sub FreeThunks()
    On Error Resume Next
    If p_thunkGen2 <> 0 Then VirtualFree p_thunkGen2, 0, MEM_RELEASE: p_thunkGen2 = 0
    If p_thunkUniform1f <> 0 Then VirtualFree p_thunkUniform1f, 0, MEM_RELEASE: p_thunkUniform1f = 0
    If p_thunkUniform2f <> 0 Then VirtualFree p_thunkUniform2f, 0, MEM_RELEASE: p_thunkUniform2f = 0
    If p_thunkUniform1ui <> 0 Then VirtualFree p_thunkUniform1ui, 0, MEM_RELEASE: p_thunkUniform1ui = 0
End Sub

' ============================================================
' GLSL sources
' ============================================================
Private Function DrawVertSrc() As String
    Dim s As String
    s = ""
    s = s & "#version 460 core" & vbCrLf
    s = s & vbCrLf
    s = s & "layout(std430, binding=7) buffer Positions { vec4 pos[]; };" & vbCrLf
    s = s & "layout(std430, binding=8) buffer Colors    { vec4 col[]; };" & vbCrLf
    s = s & vbCrLf
    s = s & "layout(location=0) uniform vec2 resolution;" & vbCrLf
    s = s & "out vec4 vColor;" & vbCrLf
    s = s & vbCrLf
    s = s & "mat4 perspective(float fov, float aspect, float near, float far)" & vbCrLf
    s = s & "{" & vbCrLf
    s = s & "  float v = 1.0 / tan(radians(fov/2.0));" & vbCrLf
    s = s & "  float u = v / aspect;" & vbCrLf
    s = s & "  float w = near - far;" & vbCrLf
    s = s & "  return mat4(" & vbCrLf
    s = s & "    u, 0, 0, 0," & vbCrLf
    s = s & "    0, v, 0, 0," & vbCrLf
    s = s & "    0, 0, (near+far)/w, -1," & vbCrLf
    s = s & "    0, 0, (near*far*2.0)/w, 0" & vbCrLf
    s = s & "  );" & vbCrLf
    s = s & "}" & vbCrLf
    s = s & vbCrLf
    s = s & "mat4 lookAt(vec3 eye, vec3 center, vec3 up)" & vbCrLf
    s = s & "{" & vbCrLf
    s = s & "  vec3 w = normalize(eye - center);" & vbCrLf
    s = s & "  vec3 u = normalize(cross(up, w));" & vbCrLf
    s = s & "  vec3 v = cross(w, u);" & vbCrLf
    s = s & "  return mat4(" & vbCrLf
    s = s & "    u.x, v.x, w.x, 0," & vbCrLf
    s = s & "    u.y, v.y, w.y, 0," & vbCrLf
    s = s & "    u.z, v.z, w.z, 0," & vbCrLf
    s = s & "    -dot(u, eye), -dot(v, eye), -dot(w, eye), 1" & vbCrLf
    s = s & "  );" & vbCrLf
    s = s & "}" & vbCrLf
    s = s & vbCrLf
    s = s & "void main(){" & vbCrLf
    s = s & "  vec4 p = pos[gl_VertexID];" & vbCrLf
    s = s & "  mat4 pMat = perspective(45.0, resolution.x / resolution.y, 0.1, 200.0);" & vbCrLf
    s = s & "  vec3 camera = vec3(0, 5, 10);" & vbCrLf
    s = s & "  vec3 center = vec3(0, 0, 0);" & vbCrLf
    s = s & "  mat4 vMat = lookAt(camera, center, vec3(0,1,0));" & vbCrLf
    s = s & "  gl_Position = pMat * vMat * p;" & vbCrLf
    s = s & "  vColor = col[gl_VertexID];" & vbCrLf
    s = s & "}" & vbCrLf
    DrawVertSrc = s
End Function

Private Function DrawFragSrc() As String
    Dim s As String
    s = ""
    s = s & "#version 460 core" & vbCrLf
    s = s & "in vec4 vColor;" & vbCrLf
    s = s & "layout(location=0) out vec4 outColor;" & vbCrLf
    s = s & "void main(){" & vbCrLf
    s = s & "  outColor = vColor;" & vbCrLf
    s = s & "}" & vbCrLf
    DrawFragSrc = s
End Function

Private Function ComputeSrc() As String
    Dim s As String
    s = ""
    s = s & "#version 460 core" & vbCrLf
    s = s & vbCrLf
    s = s & "layout(local_size_x=64, local_size_y=1, local_size_z=1) in;" & vbCrLf
    s = s & vbCrLf
    s = s & "layout(std430, binding=7) buffer Positions { vec4 pos[]; };" & vbCrLf
    s = s & "layout(std430, binding=8) buffer Colors    { vec4 col[]; };" & vbCrLf
    s = s & vbCrLf
    s = s & "layout(location=0)  uniform uint  max_num;" & vbCrLf
    s = s & "layout(location=1)  uniform float A1;" & vbCrLf
    s = s & "layout(location=2)  uniform float f1;" & vbCrLf
    s = s & "layout(location=3)  uniform float p1;" & vbCrLf
    s = s & "layout(location=4)  uniform float d1;" & vbCrLf
    s = s & "layout(location=5)  uniform float A2;" & vbCrLf
    s = s & "layout(location=6)  uniform float f2;" & vbCrLf
    s = s & "layout(location=7)  uniform float p2;" & vbCrLf
    s = s & "layout(location=8)  uniform float d2;" & vbCrLf
    s = s & "layout(location=9)  uniform float A3;" & vbCrLf
    s = s & "layout(location=10) uniform float f3;" & vbCrLf
    s = s & "layout(location=11) uniform float p3;" & vbCrLf
    s = s & "layout(location=12) uniform float d3;" & vbCrLf
    s = s & "layout(location=13) uniform float A4;" & vbCrLf
    s = s & "layout(location=14) uniform float f4;" & vbCrLf
    s = s & "layout(location=15) uniform float p4;" & vbCrLf
    s = s & "layout(location=16) uniform float d4;" & vbCrLf
    s = s & vbCrLf
    s = s & "vec3 hsv2rgb(float h, float sat, float v){" & vbCrLf
    s = s & "  float c = v*sat;" & vbCrLf
    s = s & "  float hp = h/60.0;" & vbCrLf
    s = s & "  float x = c*(1.0-abs(mod(hp,2.0)-1.0));" & vbCrLf
    s = s & "  vec3 rgb;" & vbCrLf
    s = s & "  if      (hp < 1.0) rgb = vec3(c,x,0.0);" & vbCrLf
    s = s & "  else if (hp < 2.0) rgb = vec3(x,c,0.0);" & vbCrLf
    s = s & "  else if (hp < 3.0) rgb = vec3(0.0,c,x);" & vbCrLf
    s = s & "  else if (hp < 4.0) rgb = vec3(0.0,x,c);" & vbCrLf
    s = s & "  else if (hp < 5.0) rgb = vec3(x,0.0,c);" & vbCrLf
    s = s & "  else               rgb = vec3(c,0.0,x);" & vbCrLf
    s = s & "  float m = v - c;" & vbCrLf
    s = s & "  return rgb + vec3(m);" & vbCrLf
    s = s & "}" & vbCrLf
    s = s & vbCrLf
    s = s & "void main(){" & vbCrLf
    s = s & "  uint idx = gl_GlobalInvocationID.x;" & vbCrLf
    s = s & "  if(idx >= max_num) return;" & vbCrLf
    s = s & "  float t = float(idx) * 0.001;" & vbCrLf
    s = s & "  float PI = 3.14159265;" & vbCrLf
    s = s & "  float x = A1*sin(f1*t + PI*p1)*exp(-d1*t) + A2*sin(f2*t + PI*p2)*exp(-d2*t);" & vbCrLf
    s = s & "  float y = A3*sin(f3*t + PI*p3)*exp(-d3*t) + A4*sin(f4*t + PI*p4)*exp(-d4*t);" & vbCrLf
    s = s & "  float z = A1*cos(f1*t + PI*p1)*exp(-d1*t) + A2*cos(f2*t + PI*p2)*exp(-d2*t);" & vbCrLf
    s = s & "  pos[idx] = vec4(x, y, z, 1.0);" & vbCrLf
    s = s & "  float hue = mod((t/20.0)*360.0, 360.0);" & vbCrLf
    s = s & "  vec3 rgb = hsv2rgb(hue, 1.0, 1.0);" & vbCrLf
    s = s & "  col[idx] = vec4(rgb, 1.0);" & vbCrLf
    s = s & "}" & vbCrLf
    ComputeSrc = s
End Function

' ============================================================
' Shader info logs
' ============================================================
Private Function GetShaderInfoLog(ByVal shader As Long) As String
    Dim logLen As Long
    Call GL_Call3(p_glGetShaderiv, shader, GL_INFO_LOG_LENGTH, VarPtr(logLen))
    If logLen <= 1 Then GetShaderInfoLog = "": Exit Function

    Dim b() As Byte
    ReDim b(0 To logLen - 1) As Byte

    Dim outLen As Long: outLen = 0
    Call GL_Call4(p_glGetShaderInfoLog, shader, logLen, VarPtr(outLen), VarPtr(b(0)))

    If outLen > 0 Then ReDim Preserve b(0 To outLen - 1)
    GetShaderInfoLog = StrConv(b, vbUnicode)
End Function

Private Function GetProgramInfoLog(ByVal prog As Long) As String
    Dim logLen As Long
    Call GL_Call3(p_glGetProgramiv, prog, GL_INFO_LOG_LENGTH, VarPtr(logLen))
    If logLen <= 1 Then GetProgramInfoLog = "": Exit Function

    Dim b() As Byte
    ReDim b(0 To logLen - 1) As Byte

    Dim outLen As Long: outLen = 0
    Call GL_Call4(p_glGetProgramInfoLog, prog, logLen, VarPtr(outLen), VarPtr(b(0)))

    If outLen > 0 Then ReDim Preserve b(0 To outLen - 1)
    GetProgramInfoLog = StrConv(b, vbUnicode)
End Function

Private Function CompileShader(ByVal shaderType As Long, ByVal src As String, ByVal tag As String) As Long
    LogMsg "CompileShader(" & tag & "): glCreateShader"
    Dim sh As Long
    sh = CLng(GL_Call1(p_glCreateShader, shaderType))
    LogMsg "CompileShader(" & tag & "): id=" & sh
    If sh = 0 Then Err.Raise vbObjectError + 7000, , "glCreateShader failed (" & tag & ")"

    Dim srcBytes() As Byte: srcBytes = AnsiZBytes(src)
    Dim pStr As LongPtr: pStr = VarPtr(srcBytes(0))
    Dim ppStr As LongPtr: ppStr = VarPtr(pStr)

    LogMsg "CompileShader(" & tag & "): glShaderSource"
    Call GL_Call4(p_glShaderSource, sh, 1, ppStr, 0)

    LogMsg "CompileShader(" & tag & "): glCompileShader"
    Call GL_Call1(p_glCompileShader, sh)

    Dim ok As Long
    Call GL_Call3(p_glGetShaderiv, sh, GL_COMPILE_STATUS, VarPtr(ok))
    LogMsg "CompileShader(" & tag & "): COMPILE_STATUS=" & ok

    If ok = 0 Then
        Dim info As String: info = GetShaderInfoLog(sh)
        LogMsg "ShaderInfoLog(" & tag & "): " & Replace(info, vbCrLf, "\n")
        Err.Raise vbObjectError + 7001, , "Shader compile failed (" & tag & ")"
    End If

    CompileShader = sh
End Function

Private Function LinkProgram(ByRef shaders() As Long, ByVal count As Long, ByVal tag As String) As Long
    Dim prog As Long
    prog = CLng(GL_Call0(p_glCreateProgram))
    LogMsg "LinkProgram(" & tag & "): prog=" & prog
    If prog = 0 Then Err.Raise vbObjectError + 7200, , "glCreateProgram failed (" & tag & ")"

    Dim i As Long
    For i = 0 To count - 1
        Call GL_Call2(p_glAttachShader, prog, shaders(i))
    Next i

    Call GL_Call1(p_glLinkProgram, prog)

    Dim ok As Long
    Call GL_Call3(p_glGetProgramiv, prog, GL_LINK_STATUS, VarPtr(ok))
    LogMsg "LinkProgram(" & tag & "): LINK_STATUS=" & ok
    If ok = 0 Then
        Dim info As String: info = GetProgramInfoLog(prog)
        LogMsg "ProgramInfoLog(" & tag & "): " & Replace(info, vbCrLf, "\n")
        Err.Raise vbObjectError + 7201, , "Program link failed (" & tag & ")"
    End If

    If p_glDeleteShader <> 0 Then
        For i = 0 To count - 1
            Call GL_Call1(p_glDeleteShader, shaders(i))
        Next i
    End If

    LinkProgram = prog
End Function

' ============================================================
' Window proc
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

        Case WM_SIZE
            If g_hRC <> 0 And g_hDC <> 0 Then
                Dim rc As RECT
                If GetClientRect(hWnd, rc) <> 0 Then
                    Dim w As Long, h As Long
                    w = rc.Right - rc.Left
                    h = rc.Bottom - rc.Top
                    If w > 0 And h > 0 Then
                        wglMakeCurrent g_hDC, g_hRC
                        glViewport 0, 0, w, h
                    End If
                End If
            End If
            WindowProc = 0
            Exit Function

        Case WM_KEYDOWN
            If wParam = VK_ESCAPE Then
                LogMsg "WindowProc: VK_ESCAPE"
                DestroyWindow hWnd
                WindowProc = 0
                Exit Function
            End If
    End Select

    WindowProc = DefWindowProcW(hWnd, uMsg, wParam, lParam)
End Function

' ============================================================
' Create OpenGL 4.6 Core context
' ============================================================
Private Function CreateGL46CoreContext(ByVal hWnd As LongPtr, ByVal hDC As LongPtr) As LongPtr
    LogMsg "CreateGL46CoreContext: start"

    Dim pfd As PIXELFORMATDESCRIPTOR
    pfd.nSize = LenB(pfd)
    pfd.nVersion = 1
    pfd.dwFlags = (PFD_DRAW_TO_WINDOW Or PFD_SUPPORT_OPENGL Or PFD_DOUBLEBUFFER)
    pfd.iPixelType = 0
    pfd.cColorBits = 24
    pfd.cDepthBits = 16
    pfd.iLayerType = 0

    Dim iFormat As Long
    iFormat = ChoosePixelFormat(hDC, pfd)
    LogMsg "ChoosePixelFormat=" & iFormat
    If iFormat = 0 Then Err.Raise vbObjectError + 8000, , "ChoosePixelFormat failed"

    If SetPixelFormat(hDC, iFormat, pfd) = 0 Then
        LogMsg "SetPixelFormat failed. GetLastError=" & GetLastError()
        Err.Raise vbObjectError + 8001, , "SetPixelFormat failed"
    End If

    Dim hRC_old As LongPtr
    hRC_old = wglCreateContext(hDC)
    LogMsg "wglCreateContext(legacy)=" & Hex$(hRC_old)
    If hRC_old = 0 Then Err.Raise vbObjectError + 8002, , "wglCreateContext failed"
    If wglMakeCurrent(hDC, hRC_old) = 0 Then Err.Raise vbObjectError + 8003, , "wglMakeCurrent(old) failed"

    p_wglCreateContextAttribsARB = GetGLProc("wglCreateContextAttribsARB")
    LogMsg "Proc wglCreateContextAttribsARB=" & Hex$(p_wglCreateContextAttribsARB)
    If p_wglCreateContextAttribsARB = 0 Then Err.Raise vbObjectError + 8004, , "wglCreateContextAttribsARB not available"

    Dim attribs(0 To 8) As Long
    attribs(0) = WGL_CONTEXT_MAJOR_VERSION_ARB: attribs(1) = 4
    attribs(2) = WGL_CONTEXT_MINOR_VERSION_ARB: attribs(3) = 6
    attribs(4) = WGL_CONTEXT_PROFILE_MASK_ARB:  attribs(5) = WGL_CONTEXT_CORE_PROFILE_BIT_ARB
    attribs(6) = WGL_CONTEXT_FLAGS_ARB:         attribs(7) = 0
    attribs(8) = 0

    LogMsg "CreateGL46CoreContext: creating core 4.6..."
    Dim hRC_new As LongPtr
    hRC_new = CallWindowProcW(p_wglCreateContextAttribsARB, hDC, 0, CLngPtr(VarPtr(attribs(0))), 0)
    LogMsg "wglCreateContextAttribsARB returned=" & Hex$(hRC_new)
    If hRC_new = 0 Then Err.Raise vbObjectError + 8005, , "wglCreateContextAttribsARB failed (core 4.6)"
    If wglMakeCurrent(hDC, hRC_new) = 0 Then Err.Raise vbObjectError + 8006, , "wglMakeCurrent(new) failed"

    wglDeleteContext hRC_old
    LogMsg "Deleted legacy context"

    Dim rc As RECT
    If GetClientRect(hWnd, rc) <> 0 Then
        glViewport 0, 0, (rc.Right - rc.Left), (rc.Bottom - rc.Top)
        LogMsg "glViewport set to " & (rc.Right - rc.Left) & "x" & (rc.Bottom - rc.Top)
    End If

    LogMsg "CreateGL46CoreContext: done"
    CreateGL46CoreContext = hRC_new
End Function

Private Sub DisableOpenGL(ByVal hWnd As LongPtr, ByVal hDC As LongPtr, ByVal hRC As LongPtr)
    LogMsg "DisableOpenGL: start"
    If hRC <> 0 Then
        wglMakeCurrent 0, 0
        wglDeleteContext hRC
    End If
    If hDC <> 0 Then
        ReleaseDC hWnd, hDC
    End If
    LogMsg "DisableOpenGL: done"
End Sub

' ============================================================
' Load OpenGL 4.6 core functions
' ============================================================
Private Sub LoadGL46Functions()
    LogMsg "LoadGL46Functions: start"

    LogMsg "glGetString(VENDOR)   = " & PtrToAnsiString(glGetString(GL_VENDOR))
    LogMsg "glGetString(RENDERER) = " & PtrToAnsiString(glGetString(GL_RENDERER))
    LogMsg "glGetString(VERSION)  = " & PtrToAnsiString(glGetString(GL_VERSION))
    LogMsg "glGetString(GLSL)     = " & PtrToAnsiString(glGetString(GL_SHADING_LANGUAGE_VERSION))

    p_glGenBuffers = GetGLProc("glGenBuffers")
    p_glBindBuffer = GetGLProc("glBindBuffer")
    p_glBufferData = GetGLProc("glBufferData")
    p_glBindBufferBase = GetGLProc("glBindBufferBase")

    p_glGenVertexArrays = GetGLProc("glGenVertexArrays")
    p_glBindVertexArray = GetGLProc("glBindVertexArray")

    p_glCreateShader = GetGLProc("glCreateShader")
    p_glShaderSource = GetGLProc("glShaderSource")
    p_glCompileShader = GetGLProc("glCompileShader")
    p_glGetShaderiv = GetGLProc("glGetShaderiv")
    p_glGetShaderInfoLog = GetGLProc("glGetShaderInfoLog")
    p_glDeleteShader = GetGLProc("glDeleteShader")

    p_glCreateProgram = GetGLProc("glCreateProgram")
    p_glAttachShader = GetGLProc("glAttachShader")
    p_glLinkProgram = GetGLProc("glLinkProgram")
    p_glUseProgram = GetGLProc("glUseProgram")
    p_glGetProgramiv = GetGLProc("glGetProgramiv")
    p_glGetProgramInfoLog = GetGLProc("glGetProgramInfoLog")

    p_glDispatchCompute = GetGLProc("glDispatchCompute")
    p_glMemoryBarrier = GetGLProc("glMemoryBarrier")

    p_glUniform1f = GetGLProc("glUniform1f")
    p_glUniform2f = GetGLProc("glUniform2f")
    p_glUniform1ui = GetGLProc("glUniform1ui")

    LogMsg "Proc glGenBuffers=" & Hex$(p_glGenBuffers)
    LogMsg "Proc glGenVertexArrays=" & Hex$(p_glGenVertexArrays)
    LogMsg "Proc glBindBufferBase=" & Hex$(p_glBindBufferBase)
    LogMsg "Proc glDispatchCompute=" & Hex$(p_glDispatchCompute)
    LogMsg "Proc glMemoryBarrier=" & Hex$(p_glMemoryBarrier)
    LogMsg "Proc glUniform1f=" & Hex$(p_glUniform1f)
    LogMsg "Proc glUniform2f=" & Hex$(p_glUniform2f)
    LogMsg "Proc glUniform1ui=" & Hex$(p_glUniform1ui)

    If p_glGenBuffers = 0 Or p_glBindBuffer = 0 Or p_glBufferData = 0 Then Err.Raise vbObjectError + 8100, , "Buffer entry points missing"
    If p_glBindBufferBase = 0 Then Err.Raise vbObjectError + 8101, , "glBindBufferBase missing"
    If p_glGenVertexArrays = 0 Or p_glBindVertexArray = 0 Then Err.Raise vbObjectError + 8102, , "VAO entry points missing"
    If p_glCreateShader = 0 Or p_glCreateProgram = 0 Or p_glGetShaderiv = 0 Then Err.Raise vbObjectError + 8103, , "Shader entry points missing"
    If p_glDispatchCompute = 0 Or p_glMemoryBarrier = 0 Then Err.Raise vbObjectError + 8104, , "Compute entry points missing"
    If p_glUniform1f = 0 Or p_glUniform2f = 0 Or p_glUniform1ui = 0 Then Err.Raise vbObjectError + 8105, , "Uniform entry points missing"

    ' Build ALL thunks
    If p_thunkUniform1f <> 0 Then VirtualFree p_thunkUniform1f, 0, MEM_RELEASE: p_thunkUniform1f = 0
    If p_thunkUniform2f <> 0 Then VirtualFree p_thunkUniform2f, 0, MEM_RELEASE: p_thunkUniform2f = 0
    If p_thunkUniform1ui <> 0 Then VirtualFree p_thunkUniform1ui, 0, MEM_RELEASE: p_thunkUniform1ui = 0
    
    p_thunkUniform1f = BuildThunk_Uniform1f(p_glUniform1f)
    p_thunkUniform2f = BuildThunk_Uniform2f(p_glUniform2f)
    p_thunkUniform1ui = BuildThunk_Uniform1ui(p_glUniform1ui)
    
    LogMsg "Built thunks: Uniform1f=" & Hex$(p_thunkUniform1f) & ", Uniform2f=" & Hex$(p_thunkUniform2f) & ", Uniform1ui=" & Hex$(p_thunkUniform1ui)

    LogMsg "LoadGL46Functions: done"
End Sub

' ============================================================
' Uniform helpers - ALL using thunks
' ============================================================
Private Sub U1f(ByVal loc As Long, ByVal v As Single)
    If loc < 0 Then Exit Sub
    CallWindowProcW p_thunkUniform1f, 0, CLngPtr(loc), SingleToLongPtr(v), 0
End Sub

Private Sub U2f(ByVal loc As Long, ByVal v0 As Single, ByVal v1 As Single)
    If loc < 0 Then Exit Sub
    CallWindowProcW p_thunkUniform2f, 0, CLngPtr(loc), SingleToLongPtr(v0), SingleToLongPtr(v1)
End Sub

Private Sub U1ui(ByVal loc As Long, ByVal v As Long)
    If loc < 0 Then Exit Sub
    CallWindowProcW p_thunkUniform1ui, 0, CLngPtr(loc), CLngPtr(v), 0
End Sub

' ============================================================
' Create VAO + SSBOs + Programs
' ============================================================
Private Sub InitResources()
    LogMsg "InitResources: start"

    ' ---- VAO ----
    Dim vaoOut As Long
    vaoOut = 0
    If p_thunkGen2 <> 0 Then VirtualFree p_thunkGen2, 0, MEM_RELEASE: p_thunkGen2 = 0
    p_thunkGen2 = BuildThunk_Gen2(p_glGenVertexArrays)
    CallWindowProcW p_thunkGen2, g_hWnd, 1, CLngPtr(VarPtr(vaoOut)), 0
    LogMsg "glGenVertexArrays -> vao=" & vaoOut
    If vaoOut = 0 Then Err.Raise vbObjectError + 8300, , "glGenVertexArrays failed"
    g_vao = vaoOut
    Call GL_Call1(p_glBindVertexArray, g_vao)

    ' ---- SSBOs ----
    Dim bufs(0 To 1) As Long
    bufs(0) = 0: bufs(1) = 0
    If p_thunkGen2 <> 0 Then VirtualFree p_thunkGen2, 0, MEM_RELEASE: p_thunkGen2 = 0
    p_thunkGen2 = BuildThunk_Gen2(p_glGenBuffers)
    CallWindowProcW p_thunkGen2, g_hWnd, 2, CLngPtr(VarPtr(bufs(0))), 0
    LogMsg "glGenBuffers -> ssboPos=" & bufs(0) & ", ssboCol=" & bufs(1)
    If bufs(0) = 0 Or bufs(1) = 0 Then Err.Raise vbObjectError + 8301, , "glGenBuffers failed"
    g_ssboPos = bufs(0)
    g_ssboCol = bufs(1)

    Dim bytesOne As LongPtr
    bytesOne = CLngPtr(MAX_NUM) * 16
    LogMsg "SSBO bytes each=" & bytesOne & " (MAX_NUM=" & MAX_NUM & ")"

    Call GL_Call2(p_glBindBuffer, GL_SHADER_STORAGE_BUFFER, g_ssboPos)
    Call GL_Call4(p_glBufferData, GL_SHADER_STORAGE_BUFFER, bytesOne, 0, GL_DYNAMIC_DRAW)
    Call GL_Call3(p_glBindBufferBase, GL_SHADER_STORAGE_BUFFER, 7, g_ssboPos)

    Call GL_Call2(p_glBindBuffer, GL_SHADER_STORAGE_BUFFER, g_ssboCol)
    Call GL_Call4(p_glBufferData, GL_SHADER_STORAGE_BUFFER, bytesOne, 0, GL_DYNAMIC_DRAW)
    Call GL_Call3(p_glBindBufferBase, GL_SHADER_STORAGE_BUFFER, 8, g_ssboCol)

    Call GL_Call2(p_glBindBuffer, GL_SHADER_STORAGE_BUFFER, 0)

    ' ---- Programs ----
    Dim sh(0 To 1) As Long

    sh(0) = CompileShader(GL_VERTEX_SHADER, DrawVertSrc(), "DrawVS")
    sh(1) = CompileShader(GL_FRAGMENT_SHADER, DrawFragSrc(), "DrawFS")
    g_progDraw = LinkProgram(sh, 2, "DrawProg")

    Dim shc(0 To 0) As Long
    shc(0) = CompileShader(GL_COMPUTE_SHADER, ComputeSrc(), "CompCS")
    g_progComp = LinkProgram(shc, 1, "CompProg")

    LogMsg "Using explicit uniform locations"

    Call GL_Call1(p_glUseProgram, 0)
    Call GL_Call1(p_glBindVertexArray, 0)

    LogMsg "InitResources: done"
End Sub

' ============================================================
' Per-frame: animate params
' ============================================================
Private Function RandF() As Single
    RandF = CSng(Rnd)
End Function

Private Sub InitParams()
    Randomize
    A1 = 50!: f1 = 2!: p1 = CSng(1# / 16#): d1 = 0.02!
    A2 = 50!: f2 = 2!: p2 = CSng(3# / 2#):  d2 = 0.0315!
    A3 = 50!: f3 = 2!: p3 = CSng(13# / 15#): d3 = 0.02!
    A4 = 50!: f4 = 2!: p4 = 1!:              d4 = 0.02!
End Sub

Private Sub AnimateParams()
    Const PI2 As Single = 6.2831853!

    f1 = f1 + RandF() / 40!
    If f1 >= 10! Then f1 = f1 - 10!
    f2 = f2 + RandF() / 40!
    If f2 >= 10! Then f2 = f2 - 10!
    f3 = f3 + RandF() / 40!
    If f3 >= 10! Then f3 = f3 - 10!
    f4 = f4 + RandF() / 40!
    If f4 >= 10! Then f4 = f4 - 10!

    p1 = p1 + (PI2 * 0.5! / 360!)
End Sub

' ============================================================
' Run compute
' ============================================================
Private Sub RunCompute()
    Call GL_Call1(p_glUseProgram, g_progComp)

    U1ui LOC_MAX_NUM, MAX_NUM

    U1f LOC_A1, A1: U1f LOC_F1, f1: U1f LOC_P1, p1: U1f LOC_D1, d1
    U1f LOC_A2, A2: U1f LOC_F2, f2: U1f LOC_P2, p2: U1f LOC_D2, d2
    U1f LOC_A3, A3: U1f LOC_F3, f3: U1f LOC_P3, p3: U1f LOC_D3, d3
    U1f LOC_A4, A4: U1f LOC_F4, f4: U1f LOC_P4, p4: U1f LOC_D4, d4

    Call GL_Call3(p_glBindBufferBase, GL_SHADER_STORAGE_BUFFER, 7, g_ssboPos)
    Call GL_Call3(p_glBindBufferBase, GL_SHADER_STORAGE_BUFFER, 8, g_ssboCol)

    Dim groups As Long
    groups = (MAX_NUM + 63) \ 64

    Call GL_Call3(p_glDispatchCompute, groups, 1, 1)
    Call GL_Call1(p_glMemoryBarrier, GL_SHADER_STORAGE_BARRIER_BIT)
End Sub

' ============================================================
' Render
' ============================================================
Private Sub RenderFrame()
    Dim rc As RECT
    Dim w As Long, h As Long
    w = 1: h = 1
    If GetClientRect(g_hWnd, rc) <> 0 Then
        w = rc.Right - rc.Left
        h = rc.Bottom - rc.Top
        If w < 1 Then w = 1
        If h < 1 Then h = 1
    End If

    Call GL_Call1(p_glUseProgram, g_progDraw)
    U2f LOC_RESOLUTION, CSng(w), CSng(h)

    Call GL_Call1(p_glBindVertexArray, g_vao)
    glDrawArrays GL_LINE_STRIP, 0, MAX_NUM
    Call GL_Call1(p_glBindVertexArray, 0)
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

    LogMsg "CreateWindowExW..."
    g_hWnd = CreateWindowExW(0, StrPtr(CLASS_NAME), StrPtr(WINDOW_NAME), WS_OVERLAPPEDWINDOW, _
                            CW_USEDEFAULT, CW_USEDEFAULT, 900, 700, 0, 0, hInstance, 0)
    LogMsg "CreateWindowExW hWnd=" & Hex$(g_hWnd)
    If g_hWnd = 0 Then
        LogMsg "CreateWindowExW failed. GetLastError=" & GetLastError()
        MsgBox "CreateWindowExW failed.", vbCritical
        GoTo FIN
    End If

    ShowWindow g_hWnd, SW_SHOWDEFAULT
    UpdateWindow g_hWnd

    g_hDC = GetDC(g_hWnd)
    LogMsg "GetDC hDC=" & Hex$(g_hDC)
    If g_hDC = 0 Then
        LogMsg "GetDC failed. GetLastError=" & GetLastError()
        MsgBox "GetDC failed.", vbCritical
        GoTo FIN
    End If

    g_hRC = CreateGL46CoreContext(g_hWnd, g_hDC)
    LogMsg "GL46 core hRC=" & Hex$(g_hRC)

    LoadGL46Functions
    InitParams
    InitResources

    Dim msg As MSGW
    Dim quit As Boolean: quit = False

    Dim frame As Long: frame = 0
    Dim startTick As Long: startTick = GetTickCount()
    Dim lastFpsTick As Long: lastFpsTick = startTick
    Dim framesInSec As Long: framesInSec = 0

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
            Dim nowTick As Long
            nowTick = GetTickCount()
            If (nowTick - startTick) > 60000 Then
                quit = True
            Else
                wglMakeCurrent g_hDC, g_hRC

                AnimateParams
                RunCompute

                glClearColor 0!, 0!, 0!, 1!
                glClear GL_COLOR_BUFFER_BIT Or GL_DEPTH_BUFFER_BIT

                RenderFrame
                SwapBuffers g_hDC

                frame = frame + 1
                framesInSec = framesInSec + 1

                If (nowTick - lastFpsTick) >= 1000 Then
                    Dim fps As Single
                    fps = CSng(framesInSec) * 1000! / CSng(nowTick - lastFpsTick)
                    framesInSec = 0
                    lastFpsTick = nowTick

                    Dim title As String
                    title = "OpenGL 4.6 Compute Harmonograph (VBA64) - FPS: " & Format$(fps, "0.0")
                    Dim tb() As Byte
                    tb = AnsiZBytes(title)
                    SetWindowTextA g_hWnd, VarPtr(tb(0))
                End If

                If (frame Mod 60) = 0 Then
                    LogMsg "Loop: frame=" & frame
                    DoEvents
                End If

                Sleep 1
            End If
        End If
    Loop

FIN:
    LogMsg "Cleanup: start"
    FreeThunks
    If g_hRC <> 0 Or g_hDC <> 0 Then DisableOpenGL g_hWnd, g_hDC, g_hRC
    If g_hWnd <> 0 Then DestroyWindow g_hWnd

    g_progDraw = 0: g_progComp = 0
    g_vao = 0
    g_ssboPos = 0: g_ssboCol = 0
    g_hRC = 0: g_hDC = 0: g_hWnd = 0

    LogMsg "Cleanup: done"
    LogMsg "Main: end"
    LogClose
    Exit Sub

EH:
    LogMsg "ERROR: " & Err.Number & " / " & Err.Description
    Resume FIN
End Sub
