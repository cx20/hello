Attribute VB_Name = "hello"
Option Explicit

' ============================================================
'  Win32 GUI window from Excel VBA (64-bit / VBA7 safe)
'  - Creates a native Win32 window and draws text in WM_PAINT.
' ============================================================

' -----------------------------
' Constants
' -----------------------------
Private Const WS_OVERLAPPED As Long = &H0&
Private Const WS_MAXIMIZEBOX As Long = &H10000
Private Const WS_MINIMIZEBOX As Long = &H20000
Private Const WS_THICKFRAME  As Long = &H40000
Private Const WS_SYSMENU     As Long = &H80000
Private Const WS_CAPTION     As Long = &HC00000
Private Const WS_OVERLAPPEDWINDOW As Long = (WS_OVERLAPPED Or WS_CAPTION Or WS_SYSMENU Or WS_THICKFRAME Or WS_MINIMIZEBOX Or WS_MAXIMIZEBOX)

Private Const CS_VREDRAW As Long = &H1&
Private Const CS_HREDRAW As Long = &H2&

Private Const IDI_APPLICATION As LongPtr = 32512&
Private Const IDC_ARROW       As LongPtr = 32512&

Private Const COLOR_WINDOW As Long = 5&
Private Const CW_USEDEFAULT As Long = &H80000000

Private Const SW_SHOWDEFAULT As Long = 10

Private Const WM_DESTROY As Long = &H2&
Private Const WM_PAINT   As Long = &HF&
Private Const WM_CLOSE   As Long = &H10&

Private Const PM_REMOVE As Long = &H1&
Private Const WM_QUIT   As Long = &H12&

Private Const CLASS_NAME As String = "helloWindowVBA64"
Private Const WINDOW_NAME As String = "Hello, World! (VBA64)"

' -----------------------------
' Types (64-bit safe)
' -----------------------------
Private Type POINTAPI
    x As Long
    y As Long
End Type

Private Type msg
    hwnd As LongPtr
    message As Long
    wParam As LongPtr
    lParam As LongPtr
    time As Long
    pt As POINTAPI
End Type

Private Type RECT
    Left As Long
    Top As Long
    Right As Long
    Bottom As Long
End Type

Private Type PAINTSTRUCT
    hdc As LongPtr
    fErase As Long
    rcPaint As RECT
    fRestore As Long
    fIncUpdate As Long
    rgbReserved(0 To 31) As Byte ' Win32: BYTE[32]
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

' ============================================================
' API declarations (Unicode / PtrSafe)
' ============================================================
#If VBA7 Then
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

    Private Declare PtrSafe Function ShowWindow Lib "user32" (ByVal hwnd As LongPtr, ByVal nCmdShow As Long) As Long
    Private Declare PtrSafe Function UpdateWindow Lib "user32" (ByVal hwnd As LongPtr) As Long
    Private Declare PtrSafe Function DestroyWindow Lib "user32" (ByVal hwnd As LongPtr) As Long

    Private Declare PtrSafe Function GetMessageW Lib "user32" (ByRef lpMsg As msg, ByVal hwnd As LongPtr, ByVal wMsgFilterMin As Long, ByVal wMsgFilterMax As Long) As Long
    Private Declare PtrSafe Function TranslateMessage Lib "user32" (ByRef lpMsg As msg) As Long
    Private Declare PtrSafe Function DispatchMessageW Lib "user32" (ByRef lpMsg As msg) As LongPtr

    Private Declare PtrSafe Sub PostQuitMessage Lib "user32" (ByVal nExitCode As Long)
    Private Declare PtrSafe Function DefWindowProcW Lib "user32" (ByVal hwnd As LongPtr, ByVal uMsg As Long, ByVal wParam As LongPtr, ByVal lParam As LongPtr) As LongPtr

    Private Declare PtrSafe Function BeginPaint Lib "user32" (ByVal hwnd As LongPtr, ByRef lpPaint As PAINTSTRUCT) As LongPtr
    Private Declare PtrSafe Function EndPaint Lib "user32" (ByVal hwnd As LongPtr, ByRef lpPaint As PAINTSTRUCT) As Long

    Private Declare PtrSafe Function TextOutW Lib "gdi32" (ByVal hdc As LongPtr, ByVal x As Long, ByVal y As Long, ByVal lpString As LongPtr, ByVal nCount As Long) As Long
#End If

' ============================================================
' Window procedure (must be Public in a standard module)
' ============================================================
Public Function WindowProc(ByVal hwnd As LongPtr, ByVal uMsg As Long, ByVal wParam As LongPtr, ByVal lParam As LongPtr) As LongPtr
    Select Case uMsg
        Case WM_PAINT
            Dim ps As PAINTSTRUCT
            Dim hdc As LongPtr
            Dim s As String
            s = "Hello, Win32 GUI (Excel VBA 64-bit) World!"

            hdc = BeginPaint(hwnd, ps)
            ' TextOutW wants a pointer to UTF-16 string
            TextOutW hdc, 0, 0, StrPtr(s), Len(s)
            EndPaint hwnd, ps

            WindowProc = 0
            Exit Function

        Case WM_CLOSE
            DestroyWindow hwnd
            WindowProc = 0
            Exit Function

        Case WM_DESTROY
            PostQuitMessage 0
            WindowProc = 0
            Exit Function
    End Select

    WindowProc = DefWindowProcW(hwnd, uMsg, wParam, lParam)
End Function

' ============================================================
' Entry point
' ============================================================
Public Sub Main()
    Dim wcex As WNDCLASSEXW
    Dim hwnd As LongPtr
    Dim msg As msg
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

    hwnd = CreateWindowExW( _
        0, _
        StrPtr(CLASS_NAME), _
        StrPtr(WINDOW_NAME), _
        WS_OVERLAPPEDWINDOW, _
        CW_USEDEFAULT, CW_USEDEFAULT, 640, 480, _
        0, 0, hInst, 0)

    If hwnd = 0 Then
        MsgBox "CreateWindowExW failed.", vbCritical
        Exit Sub
    End If

    ShowWindow hwnd, SW_SHOWDEFAULT
    UpdateWindow hwnd

    Do While GetMessageW(msg, 0, 0, 0) <> 0
        TranslateMessage msg
        DispatchMessageW msg
    Loop
End Sub


