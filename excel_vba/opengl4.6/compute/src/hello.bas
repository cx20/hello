Attribute VB_Name = "hello"
Option Explicit

' ============================================================
'  Excel VBA (64-bit) + Raw OpenGL 4.6 Core Profile
'   - Compute shader Harmonograph
'   - OPTIMIZED: Uses Uniform Buffer Object (UBO) instead of
'     individual glUniform calls to avoid slow thunk overhead
' ============================================================

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

Private Const PFD_DOUBLEBUFFER As Long = 1
Private Const PFD_DRAW_TO_WINDOW As Long = 4
Private Const PFD_SUPPORT_OPENGL As Long = 32

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
Private Const GL_UNIFORM_BUFFER As Long = &H8A11&
Private Const GL_SHADER_STORAGE_BARRIER_BIT As Long = &H2000&
Private Const GL_LINE_STRIP As Long = &H3&

Private Const WGL_CONTEXT_MAJOR_VERSION_ARB As Long = &H2091&
Private Const WGL_CONTEXT_MINOR_VERSION_ARB As Long = &H2092&
Private Const WGL_CONTEXT_FLAGS_ARB As Long = &H2094&
Private Const WGL_CONTEXT_PROFILE_MASK_ARB As Long = &H9126&
Private Const WGL_CONTEXT_CORE_PROFILE_BIT_ARB As Long = &H1&

Private Const CLASS_NAME As String = "helloWindowVBA_GL46_Harmo"
Private Const WINDOW_NAME As String = "Hello OpenGL 4.6 Compute Harmonograph (VBA64 UBO)"

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

' UBO data structures (std140 layout)
Private Type ComputeUBOData
    MAX_NUM As Long      ' offset 0
    pad1 As Long         ' offset 4 (padding)
    pad2 As Long         ' offset 8 (padding)
    pad3 As Long         ' offset 12 (padding)
    a1 As Single         ' offset 16
    f1 As Single         ' offset 20
    p1 As Single         ' offset 24
    d1 As Single         ' offset 28
    a2 As Single         ' offset 32
    f2 As Single         ' offset 36
    p2 As Single         ' offset 40
    d2 As Single         ' offset 44
    a3 As Single         ' offset 48
    f3 As Single         ' offset 52
    p3 As Single         ' offset 56
    d3 As Single         ' offset 60
    a4 As Single         ' offset 64
    f4 As Single         ' offset 68
    p4 As Single         ' offset 72
    d4 As Single         ' offset 76
End Type

Private Type DrawUBOData
    resX As Single       ' offset 0
    resY As Single       ' offset 4
    pad1 As Single       ' offset 8
    pad2 As Single       ' offset 12
End Type

Private g_hWnd As LongPtr
Private g_hDC  As LongPtr
Private g_hRC  As LongPtr

Private g_progDraw As Long
Private g_progComp As Long
Private g_vao As Long
Private g_ssboPos As Long
Private g_ssboCol As Long
Private g_uboDraw As Long
Private g_uboCompute As Long

Private Const MAX_NUM As Long = 500000

Private g_log As LongPtr
Private Const GENERIC_WRITE As Long = &H40000000
Private Const FILE_SHARE_READ As Long = &H1
Private Const FILE_SHARE_WRITE As Long = &H2
Private Const CREATE_ALWAYS As Long = 2
Private Const FILE_ATTRIBUTE_NORMAL As Long = &H80

Private Const MEM_COMMIT As Long = &H1000&
Private Const MEM_RESERVE As Long = &H2000&
Private Const MEM_RELEASE As Long = &H8000&
Private Const PAGE_EXECUTE_READWRITE As Long = &H40&

Private p_thunkGen2 As LongPtr

Private p_wglCreateContextAttribsARB As LongPtr

Private p_glGenBuffers As LongPtr
Private p_glBindBuffer As LongPtr
Private p_glBufferData As LongPtr
Private p_glBufferSubData As LongPtr
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

Private p_wglSwapIntervalEXT As LongPtr

' Harmonograph params
Private g_A1 As Single, g_f1 As Single, g_p1 As Single, g_d1 As Single
Private g_A2 As Single, g_f2 As Single, g_p2 As Single, g_d2 As Single
Private g_A3 As Single, g_f3 As Single, g_p3 As Single, g_d3 As Single
Private g_A4 As Single, g_f4 As Single, g_p4 As Single, g_d4 As Single

#If VBA7 Then
    Private Declare PtrSafe Function GetModuleHandleW Lib "kernel32" (ByVal lpModuleName As LongPtr) As LongPtr
    Private Declare PtrSafe Function LoadIconW Lib "user32" (ByVal hInstance As LongPtr, ByVal lpIconName As LongPtr) As LongPtr
    Private Declare PtrSafe Function LoadCursorW Lib "user32" (ByVal hInstance As LongPtr, ByVal lpCursorName As LongPtr) As LongPtr

    Private Declare PtrSafe Function RegisterClassExW Lib "user32" (ByRef lpwcx As WNDCLASSEXW) As Integer
    Private Declare PtrSafe Function CreateWindowExW Lib "user32" ( _
        ByVal dwExStyle As Long, ByVal lpClassName As LongPtr, ByVal lpWindowName As LongPtr, _
        ByVal dwStyle As Long, ByVal x As Long, ByVal y As Long, _
        ByVal nWidth As Long, ByVal nHeight As Long, _
        ByVal hWndParent As LongPtr, ByVal hMenu As LongPtr, _
        ByVal hInstance As LongPtr, ByVal lpParam As LongPtr) As LongPtr

    Private Declare PtrSafe Function ShowWindow Lib "user32" (ByVal hWnd As LongPtr, ByVal nCmdShow As Long) As Long
    Private Declare PtrSafe Function UpdateWindow Lib "user32" (ByVal hWnd As LongPtr) As Long
    Private Declare PtrSafe Function DestroyWindow Lib "user32" (ByVal hWnd As LongPtr) As Long

    Private Declare PtrSafe Function PeekMessageW Lib "user32" (ByRef lpMsg As MSGW, ByVal hWnd As LongPtr, _
        ByVal wMsgFilterMin As Long, ByVal wMsgFilterMax As Long, ByVal wRemoveMsg As Long) As Long
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

    Private Declare PtrSafe Function GetTickCount Lib "kernel32" () As Long

    Private Declare PtrSafe Function CallWindowProcW Lib "user32" (ByVal lpPrevWndFunc As LongPtr, _
        ByVal hWnd As LongPtr, ByVal msg As LongPtr, ByVal wParam As LongPtr, ByVal lParam As LongPtr) As LongPtr

    Private Declare PtrSafe Function wglCreateContext Lib "opengl32.dll" (ByVal hDC As LongPtr) As LongPtr
    Private Declare PtrSafe Function wglMakeCurrent Lib "opengl32.dll" (ByVal hDC As LongPtr, ByVal hGLRC As LongPtr) As Long
    Private Declare PtrSafe Function wglDeleteContext Lib "opengl32.dll" (ByVal hGLRC As LongPtr) As Long
    Private Declare PtrSafe Function wglGetProcAddress Lib "opengl32.dll" (ByVal lpszProc As LongPtr) As LongPtr

    Private Declare PtrSafe Sub glViewport Lib "opengl32.dll" (ByVal x As Long, ByVal y As Long, ByVal Width As Long, ByVal Height As Long)
    Private Declare PtrSafe Sub glClear Lib "opengl32.dll" (ByVal Mask As Long)
    Private Declare PtrSafe Sub glClearColor Lib "opengl32.dll" (ByVal r As Single, ByVal g As Single, ByVal b As Single, ByVal a As Single)
    Private Declare PtrSafe Function glGetString Lib "opengl32.dll" (ByVal name As Long) As LongPtr
    Private Declare PtrSafe Sub glDrawArrays Lib "opengl32.dll" (ByVal mode As Long, ByVal first As Long, ByVal count As Long)

    Private Declare PtrSafe Function CreateDirectoryW Lib "kernel32" (ByVal lpPathName As LongPtr, ByVal lpSecurityAttributes As LongPtr) As Long
    Private Declare PtrSafe Function CreateFileW Lib "kernel32" (ByVal lpFileName As LongPtr, ByVal dwDesiredAccess As Long, _
        ByVal dwShareMode As Long, ByVal lpSecurityAttributes As LongPtr, ByVal dwCreationDisposition As Long, _
        ByVal dwFlagsAndAttributes As Long, ByVal hTemplateFile As LongPtr) As LongPtr
    Private Declare PtrSafe Function WriteFile Lib "kernel32" (ByVal hFile As LongPtr, ByRef lpBuffer As Any, _
        ByVal nNumberOfBytesToWrite As Long, ByRef lpNumberOfBytesWritten As Long, ByVal lpOverlapped As LongPtr) As Long
    Private Declare PtrSafe Function FlushFileBuffers Lib "kernel32" (ByVal hFile As LongPtr) As Long
    Private Declare PtrSafe Function CloseHandle Lib "kernel32" (ByVal hObject As LongPtr) As Long

    Private Declare PtrSafe Function lstrlenA Lib "kernel32" (ByVal lpString As LongPtr) As Long
    Private Declare PtrSafe Sub RtlMoveMemory Lib "kernel32" (ByRef Destination As Any, ByVal Source As LongPtr, ByVal Length As Long)
    Private Declare PtrSafe Sub CopyMemory Lib "kernel32" Alias "RtlMoveMemory" (ByVal Destination As LongPtr, ByVal Source As LongPtr, ByVal Length As LongPtr)

    Private Declare PtrSafe Function VirtualAlloc Lib "kernel32" (ByVal lpAddress As LongPtr, ByVal dwSize As LongPtr, ByVal flAllocationType As Long, ByVal flProtect As Long) As LongPtr
    Private Declare PtrSafe Function VirtualFree Lib "kernel32" (ByVal lpAddress As LongPtr, ByVal dwSize As LongPtr, ByVal dwFreeType As Long) As Long
#End If

Private Sub LogOpen()
    On Error Resume Next
    CreateDirectoryW StrPtr("C:\TEMP"), 0
    g_log = CreateFileW(StrPtr("C:\TEMP\debug.log"), GENERIC_WRITE, FILE_SHARE_READ Or FILE_SHARE_WRITE, 0, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, 0)
    If g_log = 0 Or g_log = -1 Then g_log = 0
    LogMsg "==== LOG START ===="
End Sub

Private Sub LogClose()
    On Error Resume Next
    If g_log <> 0 Then LogMsg "==== LOG END ====": CloseHandle g_log: g_log = 0
End Sub

Private Sub LogMsg(ByVal s As String)
    On Error Resume Next
    If g_log = 0 Then Exit Sub
    Dim line As String: line = Format$(Now, "yyyy-mm-dd hh:nn:ss.000") & " | " & s & vbCrLf
    Dim b() As Byte: b = StrConv(line, vbFromUnicode)
    Dim written As Long: WriteFile g_log, b(0), UBound(b) + 1, written, 0: FlushFileBuffers g_log
End Sub

Private Function PtrToAnsiString(ByVal p As LongPtr) As String
    If p = 0 Then PtrToAnsiString = "": Exit Function
    Dim n As Long: n = lstrlenA(p): If n <= 0 Then PtrToAnsiString = "": Exit Function
    Dim b() As Byte: ReDim b(0 To n - 1) As Byte: RtlMoveMemory b(0), p, n
    PtrToAnsiString = StrConv(b, vbUnicode)
End Function

Private Function AnsiZBytes(ByVal s As String) As Byte()
    AnsiZBytes = StrConv(s & vbNullChar, vbFromUnicode)
End Function

Private Function GetGLProc(ByVal name As String) As LongPtr
    Dim b() As Byte: b = AnsiZBytes(name): GetGLProc = wglGetProcAddress(VarPtr(b(0)))
End Function

Private Function GL_Call0(ByVal proc As LongPtr) As LongPtr: GL_Call0 = CallWindowProcW(proc, 0, 0, 0, 0): End Function
Private Function GL_Call1(ByVal proc As LongPtr, ByVal a1 As LongPtr) As LongPtr: GL_Call1 = CallWindowProcW(proc, a1, 0, 0, 0): End Function
Private Function GL_Call2(ByVal proc As LongPtr, ByVal a1 As LongPtr, ByVal a2 As LongPtr) As LongPtr: GL_Call2 = CallWindowProcW(proc, a1, a2, 0, 0): End Function
Private Function GL_Call3(ByVal proc As LongPtr, ByVal a1 As LongPtr, ByVal a2 As LongPtr, ByVal a3 As LongPtr) As LongPtr: GL_Call3 = CallWindowProcW(proc, a1, a2, a3, 0): End Function
Private Function GL_Call4(ByVal proc As LongPtr, ByVal a1 As LongPtr, ByVal a2 As LongPtr, ByVal a3 As LongPtr, ByVal a4 As LongPtr) As LongPtr: GL_Call4 = CallWindowProcW(proc, a1, a2, a3, a4): End Function

Private Function BuildThunk_Gen2(ByVal target As LongPtr) As LongPtr
    Dim code(0 To 31) As Byte
    code(0) = &H48: code(1) = &H83: code(2) = &HEC: code(3) = &H28
    code(4) = &H89: code(5) = &HD1
    code(6) = &H4C: code(7) = &H89: code(8) = &HC2
    code(9) = &H48: code(10) = &HB8
    Dim t As LongLong: t = target: RtlMoveMemory code(11), VarPtr(t), 8
    code(19) = &HFF: code(20) = &HD0
    code(21) = &H48: code(22) = &H83: code(23) = &HC4: code(24) = &H28
    code(25) = &H33: code(26) = &HC0: code(27) = &HC3
    Dim mem As LongPtr: mem = VirtualAlloc(0, 64, MEM_COMMIT Or MEM_RESERVE, PAGE_EXECUTE_READWRITE)
    If mem = 0 Then Err.Raise vbObjectError + 9000
    CopyMemory mem, VarPtr(code(0)), 28
    BuildThunk_Gen2 = mem
End Function

Private Sub FreeThunks()
    On Error Resume Next
    If p_thunkGen2 <> 0 Then VirtualFree p_thunkGen2, 0, MEM_RELEASE: p_thunkGen2 = 0
End Sub

' GLSL with UBO
Private Function DrawVertSrc() As String
    Dim s As String
    s = "#version 460 core" & vbCrLf
    s = s & "layout(std430, binding=7) buffer Positions { vec4 pos[]; };" & vbCrLf
    s = s & "layout(std430, binding=8) buffer Colors    { vec4 col[]; };" & vbCrLf
    s = s & "layout(std140, binding=0) uniform DrawParams { vec2 resolution; };" & vbCrLf
    s = s & "out vec4 vColor;" & vbCrLf
    s = s & "mat4 perspective(float fov, float aspect, float near, float far){" & vbCrLf
    s = s & "  float v = 1.0 / tan(radians(fov/2.0)); float u = v / aspect; float w = near - far;" & vbCrLf
    s = s & "  return mat4(u,0,0,0, 0,v,0,0, 0,0,(near+far)/w,-1, 0,0,(near*far*2.0)/w,0);}" & vbCrLf
    s = s & "mat4 lookAt(vec3 eye, vec3 center, vec3 up){" & vbCrLf
    s = s & "  vec3 w = normalize(eye - center); vec3 u = normalize(cross(up, w)); vec3 v = cross(w, u);" & vbCrLf
    s = s & "  return mat4(u.x,v.x,w.x,0, u.y,v.y,w.y,0, u.z,v.z,w.z,0, -dot(u,eye),-dot(v,eye),-dot(w,eye),1);}" & vbCrLf
    s = s & "void main(){" & vbCrLf
    s = s & "  vec4 p = pos[gl_VertexID];" & vbCrLf
    s = s & "  mat4 pMat = perspective(45.0, resolution.x / resolution.y, 0.1, 200.0);" & vbCrLf
    s = s & "  mat4 vMat = lookAt(vec3(0,5,10), vec3(0,0,0), vec3(0,1,0));" & vbCrLf
    s = s & "  gl_Position = pMat * vMat * p; vColor = col[gl_VertexID];}" & vbCrLf
    DrawVertSrc = s
End Function

Private Function DrawFragSrc() As String
    DrawFragSrc = "#version 460 core" & vbCrLf & "in vec4 vColor; layout(location=0) out vec4 outColor; void main(){ outColor = vColor; }" & vbCrLf
End Function

Private Function ComputeSrc() As String
    Dim s As String
    s = "#version 460 core" & vbCrLf
    s = s & "layout(local_size_x=64) in;" & vbCrLf
    s = s & "layout(std430, binding=7) buffer Positions { vec4 pos[]; };" & vbCrLf
    s = s & "layout(std430, binding=8) buffer Colors    { vec4 col[]; };" & vbCrLf
    s = s & "layout(std140, binding=1) uniform ComputeParams {" & vbCrLf
    s = s & "  uint max_num; uint pad1; uint pad2; uint pad3;" & vbCrLf
    s = s & "  float A1, f1, p1, d1;" & vbCrLf
    s = s & "  float A2, f2, p2, d2;" & vbCrLf
    s = s & "  float A3, f3, p3, d3;" & vbCrLf
    s = s & "  float A4, f4, p4, d4;" & vbCrLf
    s = s & "};" & vbCrLf
    s = s & "vec3 hsv2rgb(float h, float sat, float v){ float c=v*sat; float hp=h/60.0; float x=c*(1.0-abs(mod(hp,2.0)-1.0)); vec3 rgb;" & vbCrLf
    s = s & "  if(hp<1.0) rgb=vec3(c,x,0); else if(hp<2.0) rgb=vec3(x,c,0); else if(hp<3.0) rgb=vec3(0,c,x);" & vbCrLf
    s = s & "  else if(hp<4.0) rgb=vec3(0,x,c); else if(hp<5.0) rgb=vec3(x,0,c); else rgb=vec3(c,0,x); return rgb+vec3(v-c);}" & vbCrLf
    s = s & "void main(){ uint idx=gl_GlobalInvocationID.x; if(idx>=max_num) return; float t=float(idx)*0.001; float PI=3.14159265;" & vbCrLf
    s = s & "  float x=A1*sin(f1*t+PI*p1)*exp(-d1*t)+A2*sin(f2*t+PI*p2)*exp(-d2*t);" & vbCrLf
    s = s & "  float y=A3*sin(f3*t+PI*p3)*exp(-d3*t)+A4*sin(f4*t+PI*p4)*exp(-d4*t);" & vbCrLf
    s = s & "  float z=A1*cos(f1*t+PI*p1)*exp(-d1*t)+A2*cos(f2*t+PI*p2)*exp(-d2*t);" & vbCrLf
    s = s & "  pos[idx]=vec4(x,y,z,1.0); col[idx]=vec4(hsv2rgb(mod((t/20.0)*360.0,360.0),1.0,1.0),1.0);}" & vbCrLf
    ComputeSrc = s
End Function

Private Function GetShaderInfoLog(ByVal shader As Long) As String
    Dim logLen As Long: Call GL_Call3(p_glGetShaderiv, shader, GL_INFO_LOG_LENGTH, VarPtr(logLen))
    If logLen <= 1 Then GetShaderInfoLog = "": Exit Function
    Dim b() As Byte: ReDim b(0 To logLen - 1) As Byte
    Dim outLen As Long: Call GL_Call4(p_glGetShaderInfoLog, shader, logLen, VarPtr(outLen), VarPtr(b(0)))
    If outLen > 0 Then ReDim Preserve b(0 To outLen - 1)
    GetShaderInfoLog = StrConv(b, vbUnicode)
End Function

Private Function GetProgramInfoLog(ByVal prog As Long) As String
    Dim logLen As Long: Call GL_Call3(p_glGetProgramiv, prog, GL_INFO_LOG_LENGTH, VarPtr(logLen))
    If logLen <= 1 Then GetProgramInfoLog = "": Exit Function
    Dim b() As Byte: ReDim b(0 To logLen - 1) As Byte
    Dim outLen As Long: Call GL_Call4(p_glGetProgramInfoLog, prog, logLen, VarPtr(outLen), VarPtr(b(0)))
    If outLen > 0 Then ReDim Preserve b(0 To outLen - 1)
    GetProgramInfoLog = StrConv(b, vbUnicode)
End Function

Private Function CompileShader(ByVal shaderType As Long, ByVal src As String, ByVal tag As String) As Long
    Dim sh As Long: sh = CLng(GL_Call1(p_glCreateShader, shaderType))
    If sh = 0 Then Err.Raise vbObjectError + 7000, , "glCreateShader failed (" & tag & ")"
    Dim srcBytes() As Byte: srcBytes = AnsiZBytes(src)
    Dim pStr As LongPtr: pStr = VarPtr(srcBytes(0))
    Dim ppStr As LongPtr: ppStr = VarPtr(pStr)
    Call GL_Call4(p_glShaderSource, sh, 1, ppStr, 0)
    Call GL_Call1(p_glCompileShader, sh)
    Dim ok As Long: Call GL_Call3(p_glGetShaderiv, sh, GL_COMPILE_STATUS, VarPtr(ok))
    If ok = 0 Then
        LogMsg "ShaderInfoLog(" & tag & "): " & GetShaderInfoLog(sh)
        Err.Raise vbObjectError + 7001, , "Shader compile failed (" & tag & ")"
    End If
    CompileShader = sh
End Function

Private Function LinkProgram(ByRef shaders() As Long, ByVal count As Long, ByVal tag As String) As Long
    Dim prog As Long: prog = CLng(GL_Call0(p_glCreateProgram))
    If prog = 0 Then Err.Raise vbObjectError + 7200
    Dim i As Long: For i = 0 To count - 1: Call GL_Call2(p_glAttachShader, prog, shaders(i)): Next i
    Call GL_Call1(p_glLinkProgram, prog)
    Dim ok As Long: Call GL_Call3(p_glGetProgramiv, prog, GL_LINK_STATUS, VarPtr(ok))
    If ok = 0 Then
        LogMsg "ProgramInfoLog(" & tag & "): " & GetProgramInfoLog(prog)
        Err.Raise vbObjectError + 7201
    End If
    If p_glDeleteShader <> 0 Then For i = 0 To count - 1: Call GL_Call1(p_glDeleteShader, shaders(i)): Next i
    LinkProgram = prog
End Function

Public Function WindowProc(ByVal hWnd As LongPtr, ByVal uMsg As Long, ByVal wParam As LongPtr, ByVal lParam As LongPtr) As LongPtr
    Select Case uMsg
        Case WM_CLOSE: DestroyWindow hWnd: WindowProc = 0: Exit Function
        Case WM_DESTROY: PostQuitMessage 0: WindowProc = 0: Exit Function
        Case WM_SIZE
            If g_hRC <> 0 And g_hDC <> 0 Then
                Dim rc As RECT
                If GetClientRect(hWnd, rc) <> 0 Then
                    Dim w As Long, h As Long: w = rc.Right - rc.Left: h = rc.Bottom - rc.Top
                    If w > 0 And h > 0 Then wglMakeCurrent g_hDC, g_hRC: glViewport 0, 0, w, h
                End If
            End If
            WindowProc = 0: Exit Function
        Case WM_KEYDOWN
            If wParam = VK_ESCAPE Then DestroyWindow hWnd: WindowProc = 0: Exit Function
    End Select
    WindowProc = DefWindowProcW(hWnd, uMsg, wParam, lParam)
End Function

Private Function CreateGL46CoreContext(ByVal hWnd As LongPtr, ByVal hDC As LongPtr) As LongPtr
    Dim pfd As PIXELFORMATDESCRIPTOR
    pfd.nSize = LenB(pfd): pfd.nVersion = 1
    pfd.dwFlags = (PFD_DRAW_TO_WINDOW Or PFD_SUPPORT_OPENGL Or PFD_DOUBLEBUFFER)
    pfd.cColorBits = 24: pfd.cDepthBits = 16
    Dim iFormat As Long: iFormat = ChoosePixelFormat(hDC, pfd)
    If iFormat = 0 Then Err.Raise vbObjectError + 8000
    If SetPixelFormat(hDC, iFormat, pfd) = 0 Then Err.Raise vbObjectError + 8001
    Dim hRC_old As LongPtr: hRC_old = wglCreateContext(hDC)
    If hRC_old = 0 Then Err.Raise vbObjectError + 8002
    If wglMakeCurrent(hDC, hRC_old) = 0 Then Err.Raise vbObjectError + 8003
    p_wglCreateContextAttribsARB = GetGLProc("wglCreateContextAttribsARB")
    If p_wglCreateContextAttribsARB = 0 Then Err.Raise vbObjectError + 8004
    Dim attribs(0 To 8) As Long
    attribs(0) = WGL_CONTEXT_MAJOR_VERSION_ARB: attribs(1) = 4
    attribs(2) = WGL_CONTEXT_MINOR_VERSION_ARB: attribs(3) = 6
    attribs(4) = WGL_CONTEXT_PROFILE_MASK_ARB: attribs(5) = WGL_CONTEXT_CORE_PROFILE_BIT_ARB
    attribs(6) = WGL_CONTEXT_FLAGS_ARB: attribs(7) = 0: attribs(8) = 0
    Dim hRC_new As LongPtr
    hRC_new = CallWindowProcW(p_wglCreateContextAttribsARB, hDC, 0, CLngPtr(VarPtr(attribs(0))), 0)
    If hRC_new = 0 Then Err.Raise vbObjectError + 8005
    If wglMakeCurrent(hDC, hRC_new) = 0 Then Err.Raise vbObjectError + 8006
    wglDeleteContext hRC_old
    Dim rc As RECT: If GetClientRect(hWnd, rc) <> 0 Then glViewport 0, 0, (rc.Right - rc.Left), (rc.Bottom - rc.Top)
    CreateGL46CoreContext = hRC_new
End Function

Private Sub DisableOpenGL(ByVal hWnd As LongPtr, ByVal hDC As LongPtr, ByVal hRC As LongPtr)
    If hRC <> 0 Then wglMakeCurrent 0, 0: wglDeleteContext hRC
    If hDC <> 0 Then ReleaseDC hWnd, hDC
End Sub

Private Sub LoadGL46Functions()
    LogMsg "glGetString(VENDOR)   = " & PtrToAnsiString(glGetString(GL_VENDOR))
    LogMsg "glGetString(RENDERER) = " & PtrToAnsiString(glGetString(GL_RENDERER))
    LogMsg "glGetString(VERSION)  = " & PtrToAnsiString(glGetString(GL_VERSION))

    p_glGenBuffers = GetGLProc("glGenBuffers")
    p_glBindBuffer = GetGLProc("glBindBuffer")
    p_glBufferData = GetGLProc("glBufferData")
    p_glBufferSubData = GetGLProc("glBufferSubData")
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

    LogMsg "Proc glBufferSubData=" & Hex$(p_glBufferSubData)

    p_wglSwapIntervalEXT = GetGLProc("wglSwapIntervalEXT")
    If p_wglSwapIntervalEXT <> 0 Then Call GL_Call1(p_wglSwapIntervalEXT, 0): LogMsg "VSync disabled"
End Sub

Private Sub InitResources()
    LogMsg "InitResources: start"
    
    ' VAO
    Dim vaoOut As Long: vaoOut = 0
    If p_thunkGen2 <> 0 Then VirtualFree p_thunkGen2, 0, MEM_RELEASE: p_thunkGen2 = 0
    p_thunkGen2 = BuildThunk_Gen2(p_glGenVertexArrays)
    CallWindowProcW p_thunkGen2, g_hWnd, 1, CLngPtr(VarPtr(vaoOut)), 0
    g_vao = vaoOut
    Call GL_Call1(p_glBindVertexArray, g_vao)

    ' SSBOs + UBOs (4 buffers)
    Dim bufs(0 To 3) As Long
    If p_thunkGen2 <> 0 Then VirtualFree p_thunkGen2, 0, MEM_RELEASE: p_thunkGen2 = 0
    p_thunkGen2 = BuildThunk_Gen2(p_glGenBuffers)
    CallWindowProcW p_thunkGen2, g_hWnd, 4, CLngPtr(VarPtr(bufs(0))), 0
    g_ssboPos = bufs(0)
    g_ssboCol = bufs(1)
    g_uboDraw = bufs(2)
    g_uboCompute = bufs(3)
    LogMsg "Buffers: ssboPos=" & g_ssboPos & ", ssboCol=" & g_ssboCol & ", uboDraw=" & g_uboDraw & ", uboCompute=" & g_uboCompute

    Dim bytesSSBO As LongPtr: bytesSSBO = CLngPtr(MAX_NUM) * 16
    LogMsg "SSBO bytes each=" & bytesSSBO

    Call GL_Call2(p_glBindBuffer, GL_SHADER_STORAGE_BUFFER, g_ssboPos)
    Call GL_Call4(p_glBufferData, GL_SHADER_STORAGE_BUFFER, bytesSSBO, 0, GL_DYNAMIC_DRAW)
    Call GL_Call3(p_glBindBufferBase, GL_SHADER_STORAGE_BUFFER, 7, g_ssboPos)

    Call GL_Call2(p_glBindBuffer, GL_SHADER_STORAGE_BUFFER, g_ssboCol)
    Call GL_Call4(p_glBufferData, GL_SHADER_STORAGE_BUFFER, bytesSSBO, 0, GL_DYNAMIC_DRAW)
    Call GL_Call3(p_glBindBufferBase, GL_SHADER_STORAGE_BUFFER, 8, g_ssboCol)

    Call GL_Call2(p_glBindBuffer, GL_SHADER_STORAGE_BUFFER, 0)

    ' UBO for draw (binding=0)
    Call GL_Call2(p_glBindBuffer, GL_UNIFORM_BUFFER, g_uboDraw)
    Call GL_Call4(p_glBufferData, GL_UNIFORM_BUFFER, 16, 0, GL_DYNAMIC_DRAW)
    Call GL_Call3(p_glBindBufferBase, GL_UNIFORM_BUFFER, 0, g_uboDraw)

    ' UBO for compute (binding=1)
    Call GL_Call2(p_glBindBuffer, GL_UNIFORM_BUFFER, g_uboCompute)
    Call GL_Call4(p_glBufferData, GL_UNIFORM_BUFFER, 80, 0, GL_DYNAMIC_DRAW)
    Call GL_Call3(p_glBindBufferBase, GL_UNIFORM_BUFFER, 1, g_uboCompute)

    Call GL_Call2(p_glBindBuffer, GL_UNIFORM_BUFFER, 0)

    Dim sh(0 To 1) As Long
    sh(0) = CompileShader(GL_VERTEX_SHADER, DrawVertSrc(), "DrawVS")
    sh(1) = CompileShader(GL_FRAGMENT_SHADER, DrawFragSrc(), "DrawFS")
    g_progDraw = LinkProgram(sh, 2, "DrawProg")

    Dim shc(0 To 0) As Long
    shc(0) = CompileShader(GL_COMPUTE_SHADER, ComputeSrc(), "CompCS")
    g_progComp = LinkProgram(shc, 1, "CompProg")

    Call GL_Call1(p_glUseProgram, 0)
    Call GL_Call1(p_glBindVertexArray, 0)

    LogMsg "InitResources: done"
End Sub

Private Sub InitParams()
    Randomize
    g_A1 = 50!: g_f1 = 2!: g_p1 = CSng(1# / 16#): g_d1 = 0.02!
    g_A2 = 50!: g_f2 = 2!: g_p2 = CSng(3# / 2#): g_d2 = 0.0315!
    g_A3 = 50!: g_f3 = 2!: g_p3 = CSng(13# / 15#): g_d3 = 0.02!
    g_A4 = 50!: g_f4 = 2!: g_p4 = 1!: g_d4 = 0.02!
End Sub

Private Sub AnimateParams()
    g_f1 = g_f1 + 0.01!: If g_f1 >= 10! Then g_f1 = g_f1 - 10!
    g_f2 = g_f2 + 0.012!: If g_f2 >= 10! Then g_f2 = g_f2 - 10!
    g_f3 = g_f3 + 0.011!: If g_f3 >= 10! Then g_f3 = g_f3 - 10!
    g_f4 = g_f4 + 0.013!: If g_f4 >= 10! Then g_f4 = g_f4 - 10!
    g_p1 = g_p1 + 0.00873!
End Sub

Private Sub RunCompute()
    Call GL_Call1(p_glUseProgram, g_progComp)

    ' ONE buffer update instead of 17 uniform calls
    Dim uboData As ComputeUBOData
    uboData.MAX_NUM = MAX_NUM
    uboData.a1 = g_A1: uboData.f1 = g_f1: uboData.p1 = g_p1: uboData.d1 = g_d1
    uboData.a2 = g_A2: uboData.f2 = g_f2: uboData.p2 = g_p2: uboData.d2 = g_d2
    uboData.a3 = g_A3: uboData.f3 = g_f3: uboData.p3 = g_p3: uboData.d3 = g_d3
    uboData.a4 = g_A4: uboData.f4 = g_f4: uboData.p4 = g_p4: uboData.d4 = g_d4

    Call GL_Call2(p_glBindBuffer, GL_UNIFORM_BUFFER, g_uboCompute)
    Call GL_Call4(p_glBufferSubData, GL_UNIFORM_BUFFER, 0, CLngPtr(LenB(uboData)), VarPtr(uboData))

    Dim groups As Long: groups = (MAX_NUM + 63) \ 64
    Call GL_Call3(p_glDispatchCompute, groups, 1, 1)
    Call GL_Call1(p_glMemoryBarrier, GL_SHADER_STORAGE_BARRIER_BIT)
End Sub

Private Sub RenderFrame()
    Dim rc As RECT
    Dim w As Long, h As Long: w = 800: h = 600
    If GetClientRect(g_hWnd, rc) <> 0 Then
        w = rc.Right - rc.Left: h = rc.Bottom - rc.Top
        If w < 1 Then w = 1
        If h < 1 Then h = 1
    End If

    Call GL_Call1(p_glUseProgram, g_progDraw)

    Dim drawData As DrawUBOData
    drawData.resX = CSng(w)
    drawData.resY = CSng(h)

    Call GL_Call2(p_glBindBuffer, GL_UNIFORM_BUFFER, g_uboDraw)
    Call GL_Call4(p_glBufferSubData, GL_UNIFORM_BUFFER, 0, CLngPtr(LenB(drawData)), VarPtr(drawData))

    Call GL_Call1(p_glBindVertexArray, g_vao)
    glDrawArrays GL_LINE_STRIP, 0, MAX_NUM
    Call GL_Call1(p_glBindVertexArray, 0)
End Sub

Public Sub Main()
    LogOpen
    On Error GoTo EH

    LogMsg "Main: start, MAX_NUM=" & MAX_NUM

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

    If RegisterClassExW(wcex) = 0 Then LogMsg "RegisterClassExW failed": GoTo FIN

    g_hWnd = CreateWindowExW(0, StrPtr(CLASS_NAME), StrPtr(WINDOW_NAME), WS_OVERLAPPEDWINDOW, _
                            CW_USEDEFAULT, CW_USEDEFAULT, 900, 700, 0, 0, hInstance, 0)
    If g_hWnd = 0 Then LogMsg "CreateWindowExW failed": GoTo FIN

    ShowWindow g_hWnd, SW_SHOWDEFAULT
    UpdateWindow g_hWnd

    g_hDC = GetDC(g_hWnd)
    If g_hDC = 0 Then LogMsg "GetDC failed": GoTo FIN

    g_hRC = CreateGL46CoreContext(g_hWnd, g_hDC)
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
            If msg.message = WM_QUIT Then quit = True Else TranslateMessage msg: DispatchMessageW msg
        Else
            Dim nowTick As Long: nowTick = GetTickCount()
            If (nowTick - startTick) > 60000 Then quit = True

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
                Dim fps As Single: fps = CSng(framesInSec) * 1000! / CSng(nowTick - lastFpsTick)
                framesInSec = 0: lastFpsTick = nowTick
                Dim title As String: title = "OpenGL 4.6 Harmonograph (UBO) - FPS: " & Format$(fps, "0.0")
                Dim tb() As Byte: tb = AnsiZBytes(title)
                SetWindowTextA g_hWnd, VarPtr(tb(0))
            End If

            If (frame Mod 500) = 0 Then DoEvents
        End If
    Loop

FIN:
    LogMsg "Cleanup"
    FreeThunks
    If g_hRC <> 0 Or g_hDC <> 0 Then DisableOpenGL g_hWnd, g_hDC, g_hRC
    If g_hWnd <> 0 Then DestroyWindow g_hWnd
    g_progDraw = 0: g_progComp = 0: g_vao = 0
    g_ssboPos = 0: g_ssboCol = 0: g_uboDraw = 0: g_uboCompute = 0
    g_hRC = 0: g_hDC = 0: g_hWnd = 0
    LogMsg "Main: end"
    LogClose
    Exit Sub

EH:
    LogMsg "ERROR: " & Err.Number & " / " & Err.Description
    Resume FIN
End Sub


