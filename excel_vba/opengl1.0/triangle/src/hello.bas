Attribute VB_Name = "hello"
Option Explicit

' ============================================================
'  OpenGL 1.0 Triangle (Immediate Mode) in Excel VBA (64-bit safe)
'  - Creates a Win32 window, sets pixel format, creates WGL context
'  - Renders a simple RGB triangle using glBegin/glEnd
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
' OpenGL constants (1.0)
' -----------------------------
Private Const GL_COLOR_BUFFER_BIT As Long = &H4000&
Private Const GL_TRIANGLES As Long = &H4&

' Pixel format flags
Private Const PFD_DOUBLEBUFFER As Long = 1
Private Const PFD_DRAW_TO_WINDOW As Long = 4
Private Const PFD_SUPPORT_OPENGL As Long = 32

' -----------------------------
' Class / window names
' -----------------------------
Private Const CLASS_NAME As String = "helloWindowVBA_GL10"
Private Const WINDOW_NAME As String = "Hello OpenGL 1.0 (VBA64)"

' -----------------------------
' Types (64-bit safe)
' -----------------------------
Private Type POINTAPI
    x As Long
    y As Long
End Type

Private Type msg
    hWnd As LongPtr
    message As Long
    wParam As LongPtr
    lParam As LongPtr
    time As Long
    pt As POINTAPI
End Type

Private Type WNDCLASSEX
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

' ============================================================
' Win32 API (Unicode, PtrSafe)
' ============================================================
#If VBA7 Then
    Private Declare PtrSafe Function GetModuleHandleW Lib "kernel32" (ByVal lpModuleName As LongPtr) As LongPtr
    Private Declare PtrSafe Function LoadIconW Lib "user32" (ByVal hInstance As LongPtr, ByVal lpIconName As LongPtr) As LongPtr
    Private Declare PtrSafe Function LoadCursorW Lib "user32" (ByVal hInstance As LongPtr, ByVal lpCursorName As LongPtr) As LongPtr

    Private Declare PtrSafe Function RegisterClassExW Lib "user32" (ByRef lpwcx As WNDCLASSEX) As Integer
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
        ByRef lpMsg As msg, ByVal hWnd As LongPtr, _
        ByVal wMsgFilterMin As Long, ByVal wMsgFilterMax As Long, _
        ByVal wRemoveMsg As Long) As Long
    Private Declare PtrSafe Function TranslateMessage Lib "user32" (ByRef lpMsg As msg) As Long
    Private Declare PtrSafe Function DispatchMessageW Lib "user32" (ByRef lpMsg As msg) As LongPtr
    Private Declare PtrSafe Sub PostQuitMessage Lib "user32" (ByVal nExitCode As Long)
    Private Declare PtrSafe Function DefWindowProcW Lib "user32" (ByVal hWnd As LongPtr, ByVal uMsg As Long, ByVal wParam As LongPtr, ByVal lParam As LongPtr) As LongPtr

    Private Declare PtrSafe Function GetDC Lib "user32" (ByVal hWnd As LongPtr) As LongPtr
    Private Declare PtrSafe Function ReleaseDC Lib "user32" (ByVal hWnd As LongPtr, ByVal hDC As LongPtr) As Long

    Private Declare PtrSafe Function GetClientRect Lib "user32" (ByVal hWnd As LongPtr, ByRef lpRect As RECT) As Long

    Private Declare PtrSafe Function ChoosePixelFormat Lib "gdi32" (ByVal hDC As LongPtr, ByRef pfd As PIXELFORMATDESCRIPTOR) As Long
    Private Declare PtrSafe Function SetPixelFormat Lib "gdi32" (ByVal hDC As LongPtr, ByVal iPixelFormat As Long, ByRef pfd As PIXELFORMATDESCRIPTOR) As Long
    Private Declare PtrSafe Function SwapBuffers Lib "gdi32" (ByVal hDC As LongPtr) As Long

    Private Declare PtrSafe Sub Sleep Lib "kernel32" (ByVal dwMilliseconds As Long)

    ' WGL
    Private Declare PtrSafe Function wglCreateContext Lib "opengl32.dll" (ByVal hDC As LongPtr) As LongPtr
    Private Declare PtrSafe Function wglMakeCurrent Lib "opengl32.dll" (ByVal hDC As LongPtr, ByVal hGLRC As LongPtr) As Long
    Private Declare PtrSafe Function wglDeleteContext Lib "opengl32.dll" (ByVal hGLRC As LongPtr) As Long

    ' OpenGL 1.0 (immediate mode)
    Private Declare PtrSafe Sub glViewport Lib "opengl32.dll" (ByVal x As Long, ByVal y As Long, ByVal Width As Long, ByVal Height As Long)
    Private Declare PtrSafe Sub glClearColor Lib "opengl32.dll" (ByVal r As Single, ByVal g As Single, ByVal b As Single, ByVal a As Single)
    Private Declare PtrSafe Sub glClear Lib "opengl32.dll" (ByVal Mask As Long)

    Private Declare PtrSafe Sub glBegin Lib "opengl32.dll" (ByVal mode As Long)
    Private Declare PtrSafe Sub glEnd Lib "opengl32.dll" ()
    Private Declare PtrSafe Sub glColor3f Lib "opengl32.dll" (ByVal r As Single, ByVal g As Single, ByVal b As Single)
    Private Declare PtrSafe Sub glVertex2f Lib "opengl32.dll" (ByVal x As Single, ByVal y As Single)
#End If

' ============================================================
' Window procedure
' ============================================================
Public Function WindowProc(ByVal hWnd As LongPtr, ByVal uMsg As Long, ByVal wParam As LongPtr, ByVal lParam As LongPtr) As LongPtr
    Select Case uMsg
        Case WM_CLOSE
            DestroyWindow hWnd
            WindowProc = 0
            Exit Function

        Case WM_DESTROY
            PostQuitMessage 0
            WindowProc = 0
            Exit Function

        Case WM_SIZE
            ' Update viewport if GL is ready
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
    End Select

    WindowProc = DefWindowProcW(hWnd, uMsg, wParam, lParam)
End Function

' ============================================================
' OpenGL init / shutdown
' ============================================================
Private Function EnableOpenGL(ByVal hWnd As LongPtr, ByVal hDC As LongPtr) As LongPtr
    Dim pfd As PIXELFORMATDESCRIPTOR
    pfd.nSize = LenB(pfd)
    pfd.nVersion = 1
    pfd.dwFlags = (PFD_DRAW_TO_WINDOW Or PFD_SUPPORT_OPENGL Or PFD_DOUBLEBUFFER)
    pfd.iPixelType = 0 ' PFD_TYPE_RGBA
    pfd.cColorBits = 24
    pfd.cDepthBits = 16
    pfd.iLayerType = 0 ' PFD_MAIN_PLANE

    Dim fmt As Long
    fmt = ChoosePixelFormat(hDC, pfd)
    If fmt = 0 Then
        EnableOpenGL = 0
        Exit Function
    End If

    If SetPixelFormat(hDC, fmt, pfd) = 0 Then
        EnableOpenGL = 0
        Exit Function
    End If

    Dim hRC As LongPtr
    hRC = wglCreateContext(hDC)
    If hRC = 0 Then
        EnableOpenGL = 0
        Exit Function
    End If

    If wglMakeCurrent(hDC, hRC) = 0 Then
        wglDeleteContext hRC
        EnableOpenGL = 0
        Exit Function
    End If

    ' initial viewport
    Dim rc As RECT
    If GetClientRect(hWnd, rc) <> 0 Then
        glViewport 0, 0, (rc.Right - rc.Left), (rc.Bottom - rc.Top)
    End If

    EnableOpenGL = hRC
End Function

Private Sub DisableOpenGL(ByVal hWnd As LongPtr, ByVal hDC As LongPtr, ByVal hRC As LongPtr)
    If hRC <> 0 Then
        wglMakeCurrent 0, 0
        wglDeleteContext hRC
    End If
    If hDC <> 0 Then
        ReleaseDC hWnd, hDC
    End If
End Sub

' ============================================================
' Rendering (OpenGL 1.0 immediate mode)
' ============================================================
Private Sub DrawTriangle()
    glBegin GL_TRIANGLES

    glColor3f 1!, 0!, 0!
    glVertex2f 0!, 0.6!

    glColor3f 0!, 1!, 0!
    glVertex2f 0.6!, -0.6!

    glColor3f 0!, 0!, 1!
    glVertex2f -0.6!, -0.6!

    glEnd
End Sub

' ============================================================
' Entry point
' ============================================================
Public Sub Main()
    Dim wcex As WNDCLASSEX
    Dim hInst As LongPtr
    hInst = GetModuleHandleW(0)

    wcex.cbSize = LenB(wcex)
    wcex.style = CS_HREDRAW Or CS_VREDRAW
    wcex.lpfnWndProc = VBA.CLngPtr(AddressOf WindowProc)
    wcex.cbClsExtra = 0
    wcex.cbWndExtra = 0
    wcex.hInstance = hInst
    wcex.hIcon = LoadIconW(0, IDI_APPLICATION)
    wcex.hCursor = LoadCursorW(0, IDC_ARROW)
    wcex.hbrBackground = (COLOR_WINDOW + 1)
    wcex.lpszMenuName = 0
    wcex.lpszClassName = StrPtr(CLASS_NAME)
    wcex.hIconSm = LoadIconW(0, IDI_APPLICATION)

    If RegisterClassExW(wcex) = 0 Then
        MsgBox "RegisterClassExW failed.", vbCritical
        Exit Sub
    End If

    g_hWnd = CreateWindowExW( _
        0, _
        StrPtr(CLASS_NAME), _
        StrPtr(WINDOW_NAME), _
        WS_OVERLAPPEDWINDOW, _
        CW_USEDEFAULT, CW_USEDEFAULT, 640, 480, _
        0, 0, hInst, 0)

    If g_hWnd = 0 Then
        MsgBox "CreateWindowExW failed.", vbCritical
        Exit Sub
    End If

    ShowWindow g_hWnd, SW_SHOWDEFAULT
    UpdateWindow g_hWnd

    g_hDC = GetDC(g_hWnd)
    If g_hDC = 0 Then
        MsgBox "GetDC failed.", vbCritical
        DestroyWindow g_hWnd
        Exit Sub
    End If

    g_hRC = EnableOpenGL(g_hWnd, g_hDC)
    If g_hRC = 0 Then
        MsgBox "EnableOpenGL failed.", vbCritical
        DisableOpenGL g_hWnd, g_hDC, g_hRC
        DestroyWindow g_hWnd
        Exit Sub
    End If

    ' Message loop + render loop
    Dim msg As msg
    Dim quit As Boolean
    quit = False

    Do While Not quit
        If PeekMessageW(msg, 0, 0, 0, PM_REMOVE) <> 0 Then
            If msg.message = WM_QUIT Then
                quit = True
            Else
                TranslateMessage msg
                DispatchMessageW msg
            End If
        Else
            wglMakeCurrent g_hDC, g_hRC

            glClearColor 0!, 0!, 0!, 1!
            glClear GL_COLOR_BUFFER_BIT

            DrawTriangle
            SwapBuffers g_hDC

            Sleep 1
        End If
    Loop

    ' Cleanup
    DisableOpenGL g_hWnd, g_hDC, g_hRC
    DestroyWindow g_hWnd

    g_hRC = 0: g_hDC = 0: g_hWnd = 0
End Sub


