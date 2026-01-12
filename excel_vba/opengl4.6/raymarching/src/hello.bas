Attribute VB_Name = "hello"
Option Explicit

' ============================================================
'  Excel VBA (64-bit) + Raw OpenGL 4.6 Core Profile
'   - Raymarching demo
'   - Creates a Win32 window (CS_OWNDC)
'   - Creates OpenGL 4.6 Core Profile context
'   - Renders raymarching via fullscreen quad + GLSL 460
'   - Debug log: C:\TEMP\debug.log
' ============================================================

' -----------------------------
' Win32 constants
' -----------------------------
Private Const PM_REMOVE As Long = &H1&
Private Const WM_QUIT  As Long = &H12&
Private Const WM_DESTROY As Long = &H2&
Private Const WM_CLOSE   As Long = &H10&
Private Const WM_SIZE    As Long = &H5&

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
Private Const GL_TRIANGLES As Long = &H4&

Private Const GL_VENDOR   As Long = &H1F00&
Private Const GL_RENDERER As Long = &H1F01&
Private Const GL_VERSION  As Long = &H1F02&
Private Const GL_SHADING_LANGUAGE_VERSION As Long = &H8B8C&

Private Const GL_VERTEX_SHADER   As Long = &H8B31&
Private Const GL_FRAGMENT_SHADER As Long = &H8B30&
Private Const GL_COMPILE_STATUS  As Long = &H8B81&
Private Const GL_LINK_STATUS     As Long = &H8B82&
Private Const GL_INFO_LOG_LENGTH As Long = &H8B84&

Private Const GL_ARRAY_BUFFER As Long = &H8892&
Private Const GL_STATIC_DRAW  As Long = &H88E4&
Private Const GL_FLOAT        As Long = &H1406&
Private Const GL_FALSE        As Long = 0

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
Private Const CLASS_NAME As String = "RaymarchingWindowVBA_GL46"
Private Const WINDOW_NAME As String = "Raymarching - OpenGL 4.6 Core (VBA64)"

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

' VertexAttribPointer thunk args (packed as 6 x 8 bytes)
Private Type VAPArgs
    a1_index As LongPtr
    a2_size As LongPtr
    a3_type As LongPtr
    a4_norm As LongPtr
    a5_stride As LongPtr
    a6_ptr As LongPtr
End Type

' -----------------------------
' Globals
' -----------------------------
Private g_hWnd As LongPtr
Private g_hDC  As LongPtr
Private g_hRC  As LongPtr

' GL objects
Private g_program As Long
Private g_vao As Long
Private g_vbo As Long

' Uniform locations
Private g_locTime As Long
Private g_locResolution As Long

' Window size
Private g_width As Long
Private g_height As Long

' Start time
Private g_startTime As LongLong

' Frame counter
Private g_frameCount As Long

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

Private p_thunkGen2 As LongPtr
Private p_thunkVAP As LongPtr
Private p_thunkUniform1f As LongPtr
Private p_thunkUniform2f As LongPtr

' Function pointers
Private p_wglCreateContextAttribsARB As LongPtr

Private p_glGenBuffers As LongPtr
Private p_glBindBuffer As LongPtr
Private p_glBufferData As LongPtr

Private p_glCreateShader As LongPtr
Private p_glShaderSource As LongPtr
Private p_glCompileShader As LongPtr
Private p_glGetShaderiv As LongPtr
Private p_glGetShaderInfoLog As LongPtr

Private p_glCreateProgram As LongPtr
Private p_glAttachShader As LongPtr
Private p_glLinkProgram As LongPtr
Private p_glUseProgram As LongPtr
Private p_glGetProgramiv As LongPtr
Private p_glGetProgramInfoLog As LongPtr
Private p_glDeleteShader As LongPtr

Private p_glGenVertexArrays As LongPtr
Private p_glBindVertexArray As LongPtr
Private p_glEnableVertexAttribArray As LongPtr
Private p_glVertexAttribPointer As LongPtr

Private p_glGetUniformLocation As LongPtr
Private p_glUniform1f As LongPtr
Private p_glUniform2f As LongPtr

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

    Private Declare PtrSafe Function ChoosePixelFormat Lib "gdi32" (ByVal hDC As LongPtr, ByRef pfd As PIXELFORMATDESCRIPTOR) As Long
    Private Declare PtrSafe Function SetPixelFormat Lib "gdi32" (ByVal hDC As LongPtr, ByVal iPixelFormat As Long, ByRef pfd As PIXELFORMATDESCRIPTOR) As Long
    Private Declare PtrSafe Function SwapBuffers Lib "gdi32" (ByVal hDC As LongPtr) As Long

    Private Declare PtrSafe Sub Sleep Lib "kernel32" (ByVal dwMilliseconds As Long)
    Private Declare PtrSafe Function GetLastError Lib "kernel32" () As Long
    Private Declare PtrSafe Function GetTickCount64 Lib "kernel32" () As LongLong

    ' Generic caller (abusing CallWindowProcW)
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

Private Function SingleToLongPtr(ByVal f As Single) As LongPtr
    Dim tmp As Long
    CopyMemory VarPtr(tmp), VarPtr(f), 4
    SingleToLongPtr = CLngPtr(tmp)
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
' Thunk for glGenBuffers / glGenVertexArrays (2 args)
' ============================================================
Private Function BuildThunk_Gen2(ByVal target As LongPtr) As LongPtr
    Dim code(0 To 28) As Byte
    Dim i As Long: i = 0

    code(i) = &H48: i = i + 1
    code(i) = &H83: i = i + 1
    code(i) = &HEC: i = i + 1
    code(i) = &H28: i = i + 1

    code(i) = &H48: i = i + 1
    code(i) = &H89: i = i + 1
    code(i) = &HD1: i = i + 1

    code(i) = &H4C: i = i + 1
    code(i) = &H89: i = i + 1
    code(i) = &HC2: i = i + 1

    code(i) = &H48: i = i + 1
    code(i) = &HB8: i = i + 1

    Dim t As LongLong: t = target
    RtlMoveMemory code(i), VarPtr(t), 8
    i = i + 8

    code(i) = &HFF: i = i + 1
    code(i) = &HD0: i = i + 1

    code(i) = &H48: i = i + 1
    code(i) = &H83: i = i + 1
    code(i) = &HC4: i = i + 1
    code(i) = &H28: i = i + 1

    code(i) = &H33: i = i + 1
    code(i) = &HC0: i = i + 1

    code(i) = &HC3

    Dim mem As LongPtr
    mem = VirtualAlloc(0, 64, MEM_COMMIT Or MEM_RESERVE, PAGE_EXECUTE_READWRITE)
    If mem = 0 Then Err.Raise vbObjectError + 9000, , "VirtualAlloc failed for Gen2 thunk"
    CopyMemory mem, VarPtr(code(0)), 29
    BuildThunk_Gen2 = mem
End Function

' ============================================================
' Thunk for glVertexAttribPointer (6 args)
' ============================================================
Private Function BuildThunk_VAP(ByVal target As LongPtr) As LongPtr
    Dim code(0 To 74) As Byte
    Dim i As Long: i = 0

    code(i) = &H48: i = i + 1
    code(i) = &H83: i = i + 1
    code(i) = &HEC: i = i + 1
    code(i) = &H38: i = i + 1

    code(i) = &H4D: i = i + 1
    code(i) = &H89: i = i + 1
    code(i) = &HC2: i = i + 1

    code(i) = &H49: i = i + 1
    code(i) = &H8B: i = i + 1
    code(i) = &HA:  i = i + 1

    code(i) = &H49: i = i + 1
    code(i) = &H8B: i = i + 1
    code(i) = &H52: i = i + 1
    code(i) = &H8:  i = i + 1

    code(i) = &H4D: i = i + 1
    code(i) = &H8B: i = i + 1
    code(i) = &H42: i = i + 1
    code(i) = &H10: i = i + 1

    code(i) = &H4D: i = i + 1
    code(i) = &H8B: i = i + 1
    code(i) = &H4A: i = i + 1
    code(i) = &H18: i = i + 1

    code(i) = &H49: i = i + 1
    code(i) = &H8B: i = i + 1
    code(i) = &H42: i = i + 1
    code(i) = &H20: i = i + 1

    code(i) = &H48: i = i + 1
    code(i) = &H89: i = i + 1
    code(i) = &H44: i = i + 1
    code(i) = &H24: i = i + 1
    code(i) = &H20: i = i + 1

    code(i) = &H49: i = i + 1
    code(i) = &H8B: i = i + 1
    code(i) = &H42: i = i + 1
    code(i) = &H28: i = i + 1

    code(i) = &H48: i = i + 1
    code(i) = &H89: i = i + 1
    code(i) = &H44: i = i + 1
    code(i) = &H24: i = i + 1
    code(i) = &H28: i = i + 1

    code(i) = &H48: i = i + 1
    code(i) = &HB8: i = i + 1

    Dim t As LongLong: t = target
    RtlMoveMemory code(i), VarPtr(t), 8
    i = i + 8

    code(i) = &HFF: i = i + 1
    code(i) = &HD0: i = i + 1

    code(i) = &H48: i = i + 1
    code(i) = &H83: i = i + 1
    code(i) = &HC4: i = i + 1
    code(i) = &H38: i = i + 1

    code(i) = &H33: i = i + 1
    code(i) = &HC0: i = i + 1

    code(i) = &HC3

    Dim mem As LongPtr
    mem = VirtualAlloc(0, 128, MEM_COMMIT Or MEM_RESERVE, PAGE_EXECUTE_READWRITE)
    If mem = 0 Then Err.Raise vbObjectError + 9001, , "VirtualAlloc failed for VAP thunk"
    CopyMemory mem, VarPtr(code(0)), (i + 1)
    BuildThunk_VAP = mem
End Function

' ============================================================
' Thunk for glUniform1f(int location, float v0)
'   CallWindowProcW(thunk, 0, location, floatBits, 0)
'   CallWindowProcW calls thunk(hWnd=0, msg=location, wParam=floatBits, lParam=0)
'   So in thunk: rcx=0, rdx=location, r8=floatBits, r9=0
' ============================================================
Private Function BuildThunk_Uniform1f(ByVal target As LongPtr) As LongPtr
    Dim code(0 To 40) As Byte
    Dim i As Long: i = 0

    ' sub rsp,28h
    code(i) = &H48: i = i + 1
    code(i) = &H83: i = i + 1
    code(i) = &HEC: i = i + 1
    code(i) = &H28: i = i + 1

    ' mov ecx, edx  (location from rdx -> ecx)
    code(i) = &H89: i = i + 1
    code(i) = &HD1: i = i + 1

    ' movd xmm0, r8d  (float bits from r8 -> xmm0)
    code(i) = &H66: i = i + 1
    code(i) = &H41: i = i + 1
    code(i) = &HF: i = i + 1
    code(i) = &H6E: i = i + 1
    code(i) = &HC0: i = i + 1

    ' mov rax, imm64
    code(i) = &H48: i = i + 1
    code(i) = &HB8: i = i + 1
    Dim t As LongLong: t = target
    RtlMoveMemory code(i), VarPtr(t), 8
    i = i + 8

    ' call rax
    code(i) = &HFF: i = i + 1
    code(i) = &HD0: i = i + 1

    ' add rsp,28h
    code(i) = &H48: i = i + 1
    code(i) = &H83: i = i + 1
    code(i) = &HC4: i = i + 1
    code(i) = &H28: i = i + 1

    ' xor eax,eax
    code(i) = &H33: i = i + 1
    code(i) = &HC0: i = i + 1

    ' ret
    code(i) = &HC3

    Dim mem As LongPtr
    mem = VirtualAlloc(0, 64, MEM_COMMIT Or MEM_RESERVE, PAGE_EXECUTE_READWRITE)
    If mem = 0 Then Err.Raise vbObjectError + 9002, , "VirtualAlloc failed for Uniform1f thunk"
    CopyMemory mem, VarPtr(code(0)), (i + 1)
    BuildThunk_Uniform1f = mem
End Function

' ============================================================
' Thunk for glUniform2f(int location, float v0, float v1)
'   CallWindowProcW(thunk, hWnd=location, msg=v0bits, wParam=v1bits, 0)
' ============================================================
Private Function BuildThunk_Uniform2f(ByVal target As LongPtr) As LongPtr
    Dim code(0 To 50) As Byte
    Dim i As Long: i = 0

    ' sub rsp,28h
    code(i) = &H48: i = i + 1
    code(i) = &H83: i = i + 1
    code(i) = &HEC: i = i + 1
    code(i) = &H28: i = i + 1

    ' mov ecx, edx  (location)
    code(i) = &H89: i = i + 1
    code(i) = &HD1: i = i + 1

    ' movd xmm0, r8d  (v0)
    code(i) = &H66: i = i + 1
    code(i) = &H41: i = i + 1
    code(i) = &HF: i = i + 1
    code(i) = &H6E: i = i + 1
    code(i) = &HC0: i = i + 1

    ' movd xmm1, r9d  (v1)
    code(i) = &H66: i = i + 1
    code(i) = &H41: i = i + 1
    code(i) = &HF: i = i + 1
    code(i) = &H6E: i = i + 1
    code(i) = &HC9: i = i + 1

    ' mov rax, imm64
    code(i) = &H48: i = i + 1
    code(i) = &HB8: i = i + 1
    Dim t As LongLong: t = target
    RtlMoveMemory code(i), VarPtr(t), 8
    i = i + 8

    ' call rax
    code(i) = &HFF: i = i + 1
    code(i) = &HD0: i = i + 1

    ' add rsp,28h
    code(i) = &H48: i = i + 1
    code(i) = &H83: i = i + 1
    code(i) = &HC4: i = i + 1
    code(i) = &H28: i = i + 1

    ' xor eax,eax
    code(i) = &H33: i = i + 1
    code(i) = &HC0: i = i + 1

    ' ret
    code(i) = &HC3

    Dim mem As LongPtr
    mem = VirtualAlloc(0, 64, MEM_COMMIT Or MEM_RESERVE, PAGE_EXECUTE_READWRITE)
    If mem = 0 Then Err.Raise vbObjectError + 9003, , "VirtualAlloc failed for Uniform2f thunk"
    CopyMemory mem, VarPtr(code(0)), (i + 1)
    BuildThunk_Uniform2f = mem
End Function

Private Sub FreeThunks()
    On Error Resume Next
    If p_thunkGen2 <> 0 Then VirtualFree p_thunkGen2, 0, MEM_RELEASE: p_thunkGen2 = 0
    If p_thunkVAP <> 0 Then VirtualFree p_thunkVAP, 0, MEM_RELEASE: p_thunkVAP = 0
    If p_thunkUniform1f <> 0 Then VirtualFree p_thunkUniform1f, 0, MEM_RELEASE: p_thunkUniform1f = 0
    If p_thunkUniform2f <> 0 Then VirtualFree p_thunkUniform2f, 0, MEM_RELEASE: p_thunkUniform2f = 0
End Sub

' ============================================================
' GLSL 460 core - Vertex Shader
' ============================================================
Private Function VertSrc() As String
    VertSrc = _
        "#version 460 core" & vbLf & _
        "layout(location=0) in vec2 position;" & vbLf & _
        "out vec2 fragCoord;" & vbLf & _
        "void main(){" & vbLf & _
        "  fragCoord = position * 0.5 + 0.5;" & vbLf & _
        "  gl_Position = vec4(position, 0.0, 1.0);" & vbLf & _
        "}"
End Function

' ============================================================
' GLSL 460 core - Fragment Shader (Raymarching)
' Use layout(location=X) for uniforms to avoid glGetUniformLocation
' ============================================================
Private Function FragSrc() As String
    Dim s As String
    s = "#version 460 core" & vbLf
    s = s & "precision highp float;" & vbLf
    s = s & "in vec2 fragCoord;" & vbLf
    s = s & "out vec4 outColor;" & vbLf
    s = s & "layout(location=0) uniform float iTime;" & vbLf
    s = s & "layout(location=1) uniform vec2 iResolution;" & vbLf
    s = s & "const int MAX_STEPS = 100;" & vbLf
    s = s & "const float MAX_DIST = 100.0;" & vbLf
    s = s & "const float SURF_DIST = 0.001;" & vbLf
    
    ' SDF functions
    s = s & "float sdSphere(vec3 p, float r) { return length(p) - r; }" & vbLf
    s = s & "float sdTorus(vec3 p, vec2 t) {" & vbLf
    s = s & "  vec2 q = vec2(length(p.xz) - t.x, p.y);" & vbLf
    s = s & "  return length(q) - t.y;" & vbLf
    s = s & "}" & vbLf
    
    ' Smooth min
    s = s & "float smin(float a, float b, float k) {" & vbLf
    s = s & "  float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);" & vbLf
    s = s & "  return mix(b, a, h) - k * h * (1.0 - h);" & vbLf
    s = s & "}" & vbLf
    
    ' Scene - USE HARDCODED TIME FOR TESTING
    s = s & "float GetDist(vec3 p) {" & vbLf
    s = s & "  float t = 1.0;" & vbLf  ' HARDCODED TIME
    s = s & "  float sphere = sdSphere(p - vec3(sin(t) * 1.5, 0.5 + sin(t * 2.0) * 0.3, 0.0), 0.5);" & vbLf
    s = s & "  float angle = t * 0.5;" & vbLf
    s = s & "  vec3 tp = p - vec3(0.0, 0.5, 0.0);" & vbLf
    s = s & "  tp.xz = mat2(cos(angle), -sin(angle), sin(angle), cos(angle)) * tp.xz;" & vbLf
    s = s & "  tp.xy = mat2(cos(angle * 0.7), -sin(angle * 0.7), sin(angle * 0.7), cos(angle * 0.7)) * tp.xy;" & vbLf
    s = s & "  float torus = sdTorus(tp, vec2(0.8, 0.2));" & vbLf
    s = s & "  float plane = p.y + 0.5;" & vbLf
    s = s & "  float d = smin(sphere, torus, 0.3);" & vbLf
    s = s & "  return min(d, plane);" & vbLf
    s = s & "}" & vbLf
    
    ' Normal
    s = s & "vec3 GetNormal(vec3 p) {" & vbLf
    s = s & "  float d = GetDist(p);" & vbLf
    s = s & "  vec2 e = vec2(0.001, 0.0);" & vbLf
    s = s & "  vec3 n = d - vec3(GetDist(p - e.xyy), GetDist(p - e.yxy), GetDist(p - e.yyx));" & vbLf
    s = s & "  return normalize(n);" & vbLf
    s = s & "}" & vbLf
    
    ' Raymarch
    s = s & "float RayMarch(vec3 ro, vec3 rd) {" & vbLf
    s = s & "  float dO = 0.0;" & vbLf
    s = s & "  for(int i = 0; i < MAX_STEPS; i++) {" & vbLf
    s = s & "    vec3 p = ro + rd * dO;" & vbLf
    s = s & "    float dS = GetDist(p);" & vbLf
    s = s & "    dO += dS;" & vbLf
    s = s & "    if(dO > MAX_DIST || dS < SURF_DIST) break;" & vbLf
    s = s & "  }" & vbLf
    s = s & "  return dO;" & vbLf
    s = s & "}" & vbLf
    
    ' Shadow
    s = s & "float GetShadow(vec3 ro, vec3 rd, float mint, float maxt, float k) {" & vbLf
    s = s & "  float res = 1.0;" & vbLf
    s = s & "  float t = mint;" & vbLf
    s = s & "  for(int i = 0; i < 64 && t < maxt; i++) {" & vbLf
    s = s & "    float h = GetDist(ro + rd * t);" & vbLf
    s = s & "    if(h < 0.001) return 0.0;" & vbLf
    s = s & "    res = min(res, k * h / t);" & vbLf
    s = s & "    t += h;" & vbLf
    s = s & "  }" & vbLf
    s = s & "  return res;" & vbLf
    s = s & "}" & vbLf
    
    ' AO
    s = s & "float GetAO(vec3 p, vec3 n) {" & vbLf
    s = s & "  float occ = 0.0;" & vbLf
    s = s & "  float sca = 1.0;" & vbLf
    s = s & "  for(int i = 0; i < 5; i++) {" & vbLf
    s = s & "    float h = 0.01 + 0.12 * float(i) / 4.0;" & vbLf
    s = s & "    float d = GetDist(p + h * n);" & vbLf
    s = s & "    occ += (h - d) * sca;" & vbLf
    s = s & "    sca *= 0.95;" & vbLf
    s = s & "  }" & vbLf
    s = s & "  return clamp(1.0 - 3.0 * occ, 0.0, 1.0);" & vbLf
    s = s & "}" & vbLf
    
    ' Main - USE HARDCODED RESOLUTION FOR TESTING
    s = s & "void main() {" & vbLf
    s = s & "  vec2 res = vec2(784.0, 561.0);" & vbLf  ' HARDCODED RESOLUTION
    s = s & "  vec2 uv = fragCoord - 0.5;" & vbLf
    s = s & "  uv.x *= res.x / res.y;" & vbLf
    s = s & "  vec3 ro = vec3(0.0, 1.5, -4.0);" & vbLf
    s = s & "  vec3 rd = normalize(vec3(uv.x, uv.y, 1.0));" & vbLf
    s = s & "  vec3 lightPos = vec3(3.0, 5.0, -2.0);" & vbLf
    s = s & "  float d = RayMarch(ro, rd);" & vbLf
    s = s & "  vec3 col = vec3(0.0);" & vbLf
    s = s & "  if(d < MAX_DIST) {" & vbLf
    s = s & "    vec3 p = ro + rd * d;" & vbLf
    s = s & "    vec3 n = GetNormal(p);" & vbLf
    s = s & "    vec3 l = normalize(lightPos - p);" & vbLf
    s = s & "    vec3 v = normalize(ro - p);" & vbLf
    s = s & "    vec3 r = reflect(-l, n);" & vbLf
    s = s & "    vec3 matCol = vec3(0.4, 0.6, 0.9);" & vbLf
    s = s & "    if(p.y < -0.49) {" & vbLf
    s = s & "      float checker = mod(floor(p.x) + floor(p.z), 2.0);" & vbLf
    s = s & "      matCol = mix(vec3(0.2), vec3(0.8), checker);" & vbLf
    s = s & "    }" & vbLf
    s = s & "    float diff = max(dot(n, l), 0.0);" & vbLf
    s = s & "    float spec = pow(max(dot(r, v), 0.0), 32.0);" & vbLf
    s = s & "    float ao = GetAO(p, n);" & vbLf
    s = s & "    float shadow = GetShadow(p + n * 0.01, l, 0.01, length(lightPos - p), 16.0);" & vbLf
    s = s & "    vec3 ambient = vec3(0.1, 0.12, 0.15);" & vbLf
    s = s & "    col = matCol * (ambient * ao + diff * shadow) + vec3(1.0) * spec * shadow * 0.5;" & vbLf
    s = s & "    col = mix(col, vec3(0.05, 0.05, 0.1), 1.0 - exp(-0.02 * d * d));" & vbLf
    s = s & "  } else {" & vbLf
    s = s & "    col = mix(vec3(0.1, 0.1, 0.15), vec3(0.02, 0.02, 0.05), fragCoord.y);" & vbLf
    s = s & "  }" & vbLf
    s = s & "  col = pow(col, vec3(0.4545));" & vbLf
    s = s & "  outColor = vec4(col, 1.0);" & vbLf
    s = s & "}" & vbLf
    
    FragSrc = s
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
                    g_width = rc.Right - rc.Left
                    g_height = rc.Bottom - rc.Top
                    If g_width > 0 And g_height > 0 Then
                        wglMakeCurrent g_hDC, g_hRC
                        glViewport 0, 0, g_width, g_height
                    End If
                End If
            End If
            WindowProc = 0
            Exit Function
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
    pfd.cColorBits = 32
    pfd.cAlphaBits = 8
    pfd.cDepthBits = 24
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
    If p_wglCreateContextAttribsARB = 0 Then
        Err.Raise vbObjectError + 8004, , "wglCreateContextAttribsARB not available"
    End If

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
    If hRC_new = 0 Then
        Err.Raise vbObjectError + 8005, , "wglCreateContextAttribsARB failed (core 4.6)"
    End If

    If wglMakeCurrent(hDC, hRC_new) = 0 Then
        Err.Raise vbObjectError + 8006, , "wglMakeCurrent(new) failed"
    End If

    wglDeleteContext hRC_old
    LogMsg "Deleted legacy context"

    Dim rc As RECT
    If GetClientRect(hWnd, rc) <> 0 Then
        g_width = rc.Right - rc.Left
        g_height = rc.Bottom - rc.Top
        glViewport 0, 0, g_width, g_height
        LogMsg "glViewport set to " & g_width & "x" & g_height
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
' Load OpenGL 4.6 core functions + build thunks
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

    p_glGenVertexArrays = GetGLProc("glGenVertexArrays")
    p_glBindVertexArray = GetGLProc("glBindVertexArray")

    p_glEnableVertexAttribArray = GetGLProc("glEnableVertexAttribArray")
    p_glVertexAttribPointer = GetGLProc("glVertexAttribPointer")

    p_glCreateShader = GetGLProc("glCreateShader")
    p_glShaderSource = GetGLProc("glShaderSource")
    p_glCompileShader = GetGLProc("glCompileShader")
    p_glGetShaderiv = GetGLProc("glGetShaderiv")
    p_glGetShaderInfoLog = GetGLProc("glGetShaderInfoLog")

    p_glCreateProgram = GetGLProc("glCreateProgram")
    p_glAttachShader = GetGLProc("glAttachShader")
    p_glLinkProgram = GetGLProc("glLinkProgram")
    p_glUseProgram = GetGLProc("glUseProgram")
    p_glGetProgramiv = GetGLProc("glGetProgramiv")
    p_glGetProgramInfoLog = GetGLProc("glGetProgramInfoLog")
    p_glDeleteShader = GetGLProc("glDeleteShader")

    p_glGetUniformLocation = GetGLProc("glGetUniformLocation")
    p_glUniform1f = GetGLProc("glUniform1f")
    p_glUniform2f = GetGLProc("glUniform2f")

    LogMsg "Proc glGenBuffers=" & Hex$(p_glGenBuffers)
    LogMsg "Proc glGenVertexArrays=" & Hex$(p_glGenVertexArrays)
    LogMsg "Proc glVertexAttribPointer=" & Hex$(p_glVertexAttribPointer)
    LogMsg "Proc glGetUniformLocation=" & Hex$(p_glGetUniformLocation)
    LogMsg "Proc glUniform1f=" & Hex$(p_glUniform1f)
    LogMsg "Proc glUniform2f=" & Hex$(p_glUniform2f)

    If p_glGenBuffers = 0 Or p_glBindBuffer = 0 Or p_glBufferData = 0 Then Err.Raise vbObjectError + 8100, , "VBO entry points missing"
    If p_glGenVertexArrays = 0 Or p_glBindVertexArray = 0 Then Err.Raise vbObjectError + 8101, , "VAO entry points missing"
    If p_glEnableVertexAttribArray = 0 Or p_glVertexAttribPointer = 0 Then Err.Raise vbObjectError + 8102, , "Vertex attrib entry points missing"
    If p_glCreateShader = 0 Or p_glCreateProgram = 0 Or p_glGetShaderiv = 0 Then Err.Raise vbObjectError + 8103, , "Shader entry points missing"
    If p_glGetUniformLocation = 0 Or p_glUniform1f = 0 Or p_glUniform2f = 0 Then Err.Raise vbObjectError + 8104, , "Uniform entry points missing"

    ' Build thunks
    If p_thunkVAP = 0 Then
        LogMsg "BuildThunk_VAP..."
        p_thunkVAP = BuildThunk_VAP(p_glVertexAttribPointer)
        LogMsg "ThunkVAP=" & Hex$(p_thunkVAP)
    End If

    If p_thunkUniform1f = 0 Then
        LogMsg "BuildThunk_Uniform1f..."
        p_thunkUniform1f = BuildThunk_Uniform1f(p_glUniform1f)
        LogMsg "ThunkUniform1f=" & Hex$(p_thunkUniform1f)
    End If

    If p_thunkUniform2f = 0 Then
        LogMsg "BuildThunk_Uniform2f..."
        p_thunkUniform2f = BuildThunk_Uniform2f(p_glUniform2f)
        LogMsg "ThunkUniform2f=" & Hex$(p_thunkUniform2f)
    End If

    LogMsg "LoadGL46Functions: done"
End Sub

' ============================================================
' Create shader program
' ============================================================
Private Sub CreateProgram()
    LogMsg "CreateProgram: start"

    Dim vs As Long, fs As Long
    vs = CompileShader(GL_VERTEX_SHADER, VertSrc(), "VS460")
    fs = CompileShader(GL_FRAGMENT_SHADER, FragSrc(), "FS460")

    g_program = CLng(GL_Call0(p_glCreateProgram))
    LogMsg "Program id=" & g_program
    If g_program = 0 Then Err.Raise vbObjectError + 8200, , "glCreateProgram failed"

    Call GL_Call2(p_glAttachShader, g_program, vs)
    Call GL_Call2(p_glAttachShader, g_program, fs)

    Call GL_Call1(p_glLinkProgram, g_program)

    Dim ok As Long
    Call GL_Call3(p_glGetProgramiv, g_program, GL_LINK_STATUS, VarPtr(ok))
    LogMsg "Program LINK_STATUS=" & ok
    If ok = 0 Then
        Dim info As String: info = GetProgramInfoLog(g_program)
        LogMsg "ProgramInfoLog: " & Replace(info, vbCrLf, "\n")
        Err.Raise vbObjectError + 8201, , "Program link failed"
    End If

    LogMsg "Calling glUseProgram..."
    Call GL_Call1(p_glUseProgram, g_program)
    LogMsg "glUseProgram done"

    If p_glDeleteShader <> 0 Then
        LogMsg "Calling glDeleteShader(vs)..."
        Call GL_Call1(p_glDeleteShader, vs)
        LogMsg "Calling glDeleteShader(fs)..."
        Call GL_Call1(p_glDeleteShader, fs)
        LogMsg "glDeleteShader done"
    End If

    ' Use explicit layout locations from shader (no glGetUniformLocation needed)
    ' layout(location=0) uniform float iTime;
    ' layout(location=1) uniform vec2 iResolution;
    g_locTime = 0
    g_locResolution = 1
    LogMsg "Using explicit uniform locations: iTime=" & g_locTime & ", iResolution=" & g_locResolution

    LogMsg "CreateProgram: done"
End Sub

' ============================================================
' Create VAO + VBO for fullscreen quad
' ============================================================
Private Sub InitGeometry()
    LogMsg "InitGeometry: start"

    ' VAO
    Dim vaoOut As Long: vaoOut = 0

    LogMsg "InitGeometry: build Gen2 thunk for glGenVertexArrays"
    If p_thunkGen2 <> 0 Then VirtualFree p_thunkGen2, 0, MEM_RELEASE: p_thunkGen2 = 0
    p_thunkGen2 = BuildThunk_Gen2(p_glGenVertexArrays)
    LogMsg "ThunkGen2(glGenVertexArrays)=" & Hex$(p_thunkGen2)

    CallWindowProcW p_thunkGen2, g_hWnd, 1, CLngPtr(VarPtr(vaoOut)), 0
    LogMsg "glGenVertexArrays -> vao=" & vaoOut
    If vaoOut = 0 Then Err.Raise vbObjectError + 8300, , "glGenVertexArrays failed"
    g_vao = vaoOut

    Call GL_Call1(p_glBindVertexArray, g_vao)

    ' VBO
    Dim bufOut As Long: bufOut = 0

    LogMsg "InitGeometry: rebuild Gen2 thunk for glGenBuffers"
    If p_thunkGen2 <> 0 Then VirtualFree p_thunkGen2, 0, MEM_RELEASE: p_thunkGen2 = 0
    p_thunkGen2 = BuildThunk_Gen2(p_glGenBuffers)
    LogMsg "ThunkGen2(glGenBuffers)=" & Hex$(p_thunkGen2)

    CallWindowProcW p_thunkGen2, g_hWnd, 1, CLngPtr(VarPtr(bufOut)), 0
    LogMsg "glGenBuffers -> vbo=" & bufOut
    If bufOut = 0 Then Err.Raise vbObjectError + 8301, , "glGenBuffers failed"
    g_vbo = bufOut

    ' Fullscreen quad (2 triangles)
    Dim vertices(0 To 11) As Single
    vertices(0) = -1!: vertices(1) = -1!
    vertices(2) = 1!:  vertices(3) = -1!
    vertices(4) = -1!: vertices(5) = 1!
    vertices(6) = -1!: vertices(7) = 1!
    vertices(8) = 1!:  vertices(9) = -1!
    vertices(10) = 1!: vertices(11) = 1!

    Dim bytesVerts As LongPtr: bytesVerts = 12 * 4

    Call GL_Call2(p_glBindBuffer, GL_ARRAY_BUFFER, g_vbo)
    Call GL_Call4(p_glBufferData, GL_ARRAY_BUFFER, bytesVerts, CLngPtr(VarPtr(vertices(0))), GL_STATIC_DRAW)

    ' Attrib 0: position (vec2)
    Call GL_Call1(p_glEnableVertexAttribArray, 0)

    Dim a As VAPArgs
    a.a1_index = 0
    a.a2_size = 2
    a.a3_type = GL_FLOAT
    a.a4_norm = GL_FALSE
    a.a5_stride = 0
    a.a6_ptr = 0

    CallWindowProcW p_thunkVAP, g_hWnd, 0, CLngPtr(VarPtr(a)), 0

    Call GL_Call2(p_glBindBuffer, GL_ARRAY_BUFFER, 0)
    Call GL_Call1(p_glBindVertexArray, 0)

    LogMsg "InitGeometry: done"
End Sub

' ============================================================
' Render
' ============================================================
Private Sub RenderFrame()
    If g_program <> 0 Then Call GL_Call1(p_glUseProgram, g_program)
    If g_vao <> 0 Then Call GL_Call1(p_glBindVertexArray, g_vao)

    ' Update uniforms
    Dim currentTime As LongLong
    currentTime = GetTickCount64()
    Dim elapsed As Single
    elapsed = CSng(currentTime - g_startTime) / 1000!

    ' Debug: log values on first few frames
    If g_frameCount < 3 Then
        LogMsg "RenderFrame[" & g_frameCount & "]: elapsed=" & elapsed & ", width=" & g_width & ", height=" & g_height
        LogMsg "RenderFrame[" & g_frameCount & "]: locTime=" & g_locTime & ", locResolution=" & g_locResolution
    End If

    ' glUniform1f(iTime, elapsed)
    CallWindowProcW p_thunkUniform1f, 0, CLngPtr(g_locTime), SingleToLongPtr(elapsed), 0

    ' glUniform2f(iResolution, width, height)
    CallWindowProcW p_thunkUniform2f, 0, CLngPtr(g_locResolution), SingleToLongPtr(CSng(g_width)), SingleToLongPtr(CSng(g_height))

    glDrawArrays GL_TRIANGLES, 0, 6

    Call GL_Call1(p_glBindVertexArray, 0)
    
    g_frameCount = g_frameCount + 1
    If g_frameCount = 1 Then
        LogMsg "RenderFrame: first frame completed"
    End If
End Sub

' ============================================================
' Entry point
' ============================================================
Public Sub Main()
    LogOpen
    On Error GoTo EH

    LogMsg "Main: start"

    g_width = 800
    g_height = 600

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
                            CW_USEDEFAULT, CW_USEDEFAULT, g_width, g_height, 0, 0, hInstance, 0)
    LogMsg "CreateWindowExW hWnd=" & Hex$(g_hWnd)
    If g_hWnd = 0 Then
        LogMsg "CreateWindowExW failed. GetLastError=" & GetLastError()
        MsgBox "CreateWindowExW failed.", vbCritical
        GoTo FIN
    End If

    ShowWindow g_hWnd, SW_SHOWDEFAULT
    UpdateWindow g_hWnd
    LogMsg "ShowWindow/UpdateWindow OK"

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

    CreateProgram
    InitGeometry

    g_startTime = GetTickCount64()

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
            wglMakeCurrent g_hDC, g_hRC

            glClearColor 0!, 0!, 0!, 1!
            glClear GL_COLOR_BUFFER_BIT

            RenderFrame
            SwapBuffers g_hDC

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
    If g_hRC <> 0 Or g_hDC <> 0 Then DisableOpenGL g_hWnd, g_hDC, g_hRC
    If g_hWnd <> 0 Then DestroyWindow g_hWnd

    g_program = 0
    g_vao = 0
    g_vbo = 0
    g_hRC = 0: g_hDC = 0: g_hWnd = 0

    LogMsg "Cleanup: done"
    LogMsg "Main: end"
    LogClose
    Exit Sub

EH:
    LogMsg "ERROR: " & Err.Number & " / " & Err.Description
    Resume FIN
End Sub
