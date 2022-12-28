Attribute VB_Name = "hello"
Option Explicit

Const PM_REMOVE As Long = &H1
Const WM_QUIT  As Long = &H12

Const WS_OVERLAPPED As Long = &H0
Const WS_MAXIMIZEBOX As Long = &H10000
Const WS_MINIMIZEBOX As Long = &H20000
Const WS_THICKFRAME As Long = &H40000
Const WS_SYSMENU As Long = &H80000
Const WS_CAPTION As Long = &HC00000
Const WS_EX_APPWINDOW As Long = &H40000
Const WS_OVERLAPPEDWINDOW As Long = (WS_OVERLAPPED Or WS_CAPTION Or WS_SYSMENU Or WS_THICKFRAME Or WS_MINIMIZEBOX Or WS_MAXIMIZEBOX)
 
Const CS_VREDRAW As Long = &H1
Const CS_HREDRAW As Long = &H2
 
Const IDI_APPLICATION As Long = 32512
Const IDC_ARROW As Long = 32512
 
Const COLOR_WINDOW As Long = 5
Const COLOR_BTNFACE As Long = 15
 
Const WHITE_BRUSH As Long = 0
 
Const CW_USEDEFAULT As Long = &H80000000
 
Const SW_SHOWNORMAL As Long = 1
Const SW_SHOW As Long = 5
Const SW_SHOWDEFAULT As Long = 10
 
Const WM_DESTROY As Long = &H2
Const WM_CLOSE As Long = &H10
Const WM_PAINT As Long = &HF
 
Const GL_AMBIENT_AND_DIFFUSE = &H1602
Const GL_COLOR_BUFFER_BIT = &H4000
Const GL_DEPTH_BUFFER_BIT = &H100
Const GL_DEPTH_TEST = &HB71
Const GL_LIGHT0 = &H4000
Const GL_LIGHTING = &HB50
Const GL_MODELVIEW = &H1700
Const GL_PROJECTION = &H1701
Const GL_TRIANGLES = &H4
Const GL_FRONT = 1028
Const GL_VERTEX_ARRAY = &H8074&
Const GL_NORMAL_ARRAY = &H8075&
Const GL_COLOR_ARRAY = &H8076&
Const GL_DOUBLE = &H140A
Const PFD_DOUBLEBUFFER = 1
Const PFD_DRAW_TO_WINDOW = 4
Const PFD_SUPPORT_OPENGL = 32

Const CLASS_NAME As String = "helloWindow"
Const WINDOW_NAME As String = "Hello, World!"
 
Type POINTAPI
    x As Long
    y As Long
End Type
 
Type MSG
    hWnd As Long
    message As Long
    wParam As Long
    lParam As Long
    time As Long
    pt As POINTAPI
End Type
 
Type WNDCLASSEX
    cbSize As Long
    style As Long
    lpfnWndProc As Long
    cbClsExtra As Long
    cbWndExtra As Long
    hInstance As Long
    hIcon As Long
    hCursor As Long
    hbrBackground As Long
    lpszMenuName As String
    lpszClassName As String
    hIconSm As Long
End Type
 
Type RECT
    Left As Long
    Top As Long
    Right As Long
    Bottom As Long
End Type
 
Type PAINTSTRUCT
    hDC As Long
    fErase As Long
    rcPaint As RECT
    fRestore As Long
    fIncUpdate As Long
    rgbReserved As Byte
End Type

Public Type PIXELFORMATDESCRIPTOR
    nSize As Long
    nVersion As Long
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

Declare Function GetModuleHandle Lib "kernel32" Alias "GetModuleHandleA" (ByVal lpModuleName As Long) As Long
Declare Function LoadIcon Lib "user32" Alias "LoadIconA" (ByVal hInstance As Long, ByVal lpIconName As Long) As Long
Declare Function LoadCursor Lib "user32" Alias "LoadCursorA" (ByVal hInstance As Long, ByVal lpCursorName As Long) As Long
Declare Function GetStockObject Lib "gdi32" (ByVal fnObject As Long) As Long
Declare Function RegisterClassEx Lib "user32" Alias "RegisterClassExA" (lpwcx As WNDCLASSEX) As Long
Declare Function CreateWindowEx Lib "user32" Alias "CreateWindowExA" (ByVal dwExStyle As Long, ByVal lpClassName As String, ByVal lpWindowName As String, ByVal dwStyle As Long, ByVal x As Long, ByVal y As Long, ByVal nWidth As Long, ByVal nHeight As Long, ByVal hWndParent As Long, ByVal hMenu As Long, ByVal hInstance As Long, lpParam As Any) As Long
Declare Function ShowWindow Lib "user32" (ByVal hWnd As Long, ByVal nCmdShow As Long) As Long
Declare Function UpdateWindow Lib "user32" (ByVal lhwnd As Long) As Long
Declare Function DestroyWindow Lib "user32" (ByVal lhwnd As Long) As Long
Declare Function GetMessage Lib "user32" Alias "GetMessageA" (lpMsg As MSG, ByVal hWnd As Long, ByVal wMsgFilterMin As Long, ByVal wMsgFilterMax As Long) As Long
Declare Function TranslateMessage Lib "user32" (lpMsg As MSG) As Long
Declare Function DispatchMessage Lib "user32" Alias "DispatchMessageA" (lpMsg As MSG) As Long
Declare Sub PostQuitMessage Lib "user32" (ByVal nExitCode As Long)
Declare Function DefWindowProc Lib "user32" Alias "DefWindowProcA" (ByVal hWnd As Long, ByVal wMsg As Long, ByVal wParam As Long, ByVal lParam As Long) As Long
Declare Function BeginPaint Lib "user32" (ByVal hWnd As Long, lpPaint As PAINTSTRUCT) As Long
Declare Function EndPaint Lib "user32" (ByVal hWnd As Long, lpPaint As PAINTSTRUCT) As Long
Declare Function TextOut Lib "gdi32" Alias "TextOutA" (ByVal hDC As Long, ByVal x As Long, ByVal y As Long, ByVal lpString As String, ByVal nCount As Long) As Long
 
Declare Function PeekMessage& Lib "user32" Alias "PeekMessageA" (lpMsg As MSG, ByVal hWnd&, ByVal wMsgFilterMin&, ByVal wMsgFilterMax&, ByVal wRemoveMsg&)
Declare Sub Sleep Lib "kernel32" (ByVal ms As Long)

Declare PtrSafe Function GetDC Lib "user32" (ByVal hWnd As LongPtr) As Long
Declare PtrSafe Function ReleaseDC Lib "user32" (ByVal hWnd As LongPtr, ByVal hDC As Long) As Long

Declare PtrSafe Function SelectObject Lib "gdi32" (ByVal hDC As Long, ByVal hObject As Long) As Long
Declare PtrSafe Function DeleteObject Lib "gdi32" (ByVal hObject As Long) As Long
Declare PtrSafe Function ChoosePixelFormat Lib "gdi32" (ByVal hDC As Long, ByRef pfd As PIXELFORMATDESCRIPTOR) As Long
Declare PtrSafe Function SetPixelFormat Lib "gdi32" (ByVal hDC As Long, ByVal format As Long, ByRef ppfd As PIXELFORMATDESCRIPTOR) As Long
Declare PtrSafe Function SwapBuffers Lib "gdi32" (ByVal hDC As Long) As Long

Declare PtrSafe Sub gluPerspective Lib "glu32.dll" (ByVal FovY As Double, ByVal aspect As Double, ByVal zNear As Double, ByVal zfar As Double)
Declare PtrSafe Sub gluLookAt Lib "glu32.dll" (ByVal eyeX As Double, ByVal eyeY As Double, ByVal eyeZ As Double, ByVal centerX As Double, ByVal centerY As Double, ByVal centerZ As Double, ByVal upx As Double, ByVal upy As Double, ByVal upz As Double)

Declare PtrSafe Function wglCreateContext Lib "opengl32.dll" (ByVal hDC As Long) As Long
Declare PtrSafe Function wglMakeCurrent Lib "opengl32.dll" (ByVal hDC As Long, ByVal hGLRC As LongPtr) As Long
Declare PtrSafe Function wglDeleteContext Lib "opengl32.dll" (ByVal hDC As Long) As Long
Declare PtrSafe Sub glViewport Lib "opengl32.dll" (ByVal x As Long, ByVal y As Long, ByVal Width As Long, ByVal Height As Long)

Declare PtrSafe Sub glBegin Lib "opengl32.dll" (ByVal Glenum As Long)
Declare PtrSafe Sub glEnd Lib "opengl32.dll" ()
Declare PtrSafe Sub glColor3f Lib "opengl32.dll" (ByVal red As Single, ByVal green As Single, ByVal blue As Single)
Declare PtrSafe Sub glVertex2f Lib "opengl32.dll" (ByVal x As Single, ByVal y As Single)

Declare PtrSafe Sub glEnable Lib "opengl32.dll" (ByVal Glenum As Long)
Declare PtrSafe Sub glDisable Lib "opengl32.dll" (ByVal Glenum As Long)
Declare PtrSafe Sub glEnableClientState Lib "opengl32.dll" (ByVal Glenum As Long)
Declare PtrSafe Sub glDisableClientState Lib "opengl32.dll" (ByVal Glenum As Long)

Declare PtrSafe Sub glClear Lib "opengl32.dll" (ByVal Mask As Long)
Declare PtrSafe Sub glClearColor Lib "opengl32.dll" (ByVal red As Single, ByVal green As Single, ByVal blue As Single, ByVal alpha As Single)

Declare PtrSafe Sub glColorPointer Lib "opengl32.dll" (ByVal Size As Long, ByVal Glenum As Long, ByVal Stride As Long, ByVal Ptr As LongPtr)
Declare PtrSafe Sub glVertexPointer Lib "opengl32.dll" (ByVal Size As Long, ByVal Glenum As Long, ByVal Stride As Long, ByVal Ptr As LongPtr)
Declare PtrSafe Sub glDrawArrays Lib "opengl32.dll" (ByVal Glenum As Long, ByVal First As Long, ByVal Size As Long)

Function FuncPtr(ByVal p As Long) As Long
    FuncPtr = p
End Function

Function WindowProc(ByVal hWnd As Long, ByVal uMsg As Long, ByVal wParam As Long, ByVal lParam As Long) As Long
    Dim ps As PAINTSTRUCT
    Dim hDC As Long
    Dim strMessage As String
    strMessage = "Hello, Win32 GUI(VBA) World!"
 
    Select Case uMsg
    Case WM_DESTROY
        Call PostQuitMessage(0)
    Case Else
        WindowProc = DefWindowProc(hWnd, uMsg, wParam, lParam)
        Exit Function
    End Select
    WindowProc = 0
End Function
 
Function EnableOpenGL(hDC As Long)
    Dim pfd As PIXELFORMATDESCRIPTOR
    With pfd
        .nSize = 40 ' LenB(pfd)
        .nVersion = 1
        .dwFlags = (PFD_DOUBLEBUFFER Or PFD_DRAW_TO_WINDOW Or PFD_SUPPORT_OPENGL)
        .iPixelType = 0 ' PFD_TYPE_RGBA
        .cColorBits = 24
        .cDepthBits = 16
        .iLayerType = 0 'PFD_MAIN_PLANE
    End With
    
    Dim hRC As Long
    Dim iFormat As Long
    
    iFormat = ChoosePixelFormat(hDC, pfd)
    
    SetPixelFormat hDC, iFormat, pfd
    
    hRC = wglCreateContext(hDC)
    wglMakeCurrent hDC, hRC
    
    EnableOpenGL = hRC
    
End Function

Sub DisableOpenGL(hWnd As Long, hDC As Long, hRC As Long)
    Call wglMakeCurrent(0, 0)
    Call wglDeleteContext(hRC)
    Call ReleaseDC(hWnd, hDC)
End Sub

Function WinMain() As Integer
    Dim wcex As WNDCLASSEX
    Dim hWnd As Long
    Dim message As MSG
    Dim pfnc As Long
    wcex.cbSize = Len(wcex)
    wcex.style = CS_HREDRAW Or CS_VREDRAW
    wcex.lpfnWndProc = FuncPtr(AddressOf WindowProc)
    wcex.cbClsExtra = 0
    wcex.cbWndExtra = 0
    wcex.hInstance = GetModuleHandle(0)
    wcex.hIcon = LoadIcon(0, IDI_APPLICATION)
    wcex.hCursor = LoadCursor(0, IDC_ARROW)
    wcex.hbrBackground = COLOR_WINDOW + 1
    wcex.lpszMenuName = vbNullString
    wcex.lpszClassName = CLASS_NAME
    wcex.hIconSm = LoadIcon(0, IDI_APPLICATION)
 
    Dim hDC As Long
    Dim hRC As Long

    Call RegisterClassEx(wcex)
 
    hWnd = CreateWindowEx( _
        0, _
        CLASS_NAME, _
        WINDOW_NAME, _
        WS_OVERLAPPEDWINDOW, _
        CW_USEDEFAULT, CW_USEDEFAULT, 640, 480, _
        0, 0, wcex.hInstance, 0)
 
    Call ShowWindow(hWnd, SW_SHOWDEFAULT)
    Call UpdateWindow(hWnd)
 
    hDC = GetDC(hWnd)
    hRC = EnableOpenGL(hDC)
 
    Dim bQuit As Boolean
    bQuit = False
 
    While Not bQuit
        If PeekMessage(message, 0, 0, 0, PM_REMOVE) <> 0 Then
            If message.message = WM_QUIT Then
                bQuit = True
            Else
                Call TranslateMessage(message)
                Call DispatchMessage(message)
            End If
        Else
            glClearColor 0#, 0#, 0#, 0#
            glClear GL_COLOR_BUFFER_BIT
            
            DrawTriangle
            
            SwapBuffers hDC
        
            Sleep 1
        End If
    Wend
 
    Call DisableOpenGL(hWnd, hDC, hRC)
    Call DestroyWindow(hWnd)
 
    WinMain = message.wParam
End Function

Sub DrawTriangle()

    glBegin GL_TRIANGLES

    glColor3f 1#, 0#, 0#
    glVertex2f 0#, 0.5
    glColor3f 0#, 1#, 0#
    glVertex2f 0.5, -0.5
    glColor3f 0#, 0#, 1#
    glVertex2f -0.5, -0.5

    glEnd
End Sub

Public Sub Main()
    Call WinMain
End Sub


