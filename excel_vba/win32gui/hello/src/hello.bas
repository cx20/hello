Attribute VB_Name = "hello"
Private Const WS_OVERLAPPED As Long = &H0
Private Const WS_MAXIMIZEBOX As Long = &H10000
Private Const WS_MINIMIZEBOX As Long = &H20000
Private Const WS_THICKFRAME As Long = &H40000
Private Const WS_SYSMENU As Long = &H80000
Private Const WS_CAPTION As Long = &HC00000
Private Const WS_EX_APPWINDOW As Long = &H40000
Private Const WS_OVERLAPPEDWINDOW As Long = (WS_OVERLAPPED Or WS_CAPTION Or WS_SYSMENU Or WS_THICKFRAME Or WS_MINIMIZEBOX Or WS_MAXIMIZEBOX)

Private Const CS_VREDRAW As Long = &H1
Private Const CS_HREDRAW As Long = &H2

Private Const IDI_APPLICATION As Long = 32512
Private Const IDC_ARROW As Long = 32512

Private Const COLOR_WINDOW As Long = 5
Private Const COLOR_BTNFACE As Long = 15

Private Const WHITE_BRUSH As Long = 0

Private Const CW_USEDEFAULT As Long = &H80000000

Private Const SW_SHOWNORMAL As Long = 1
Private Const SW_SHOW As Long = 5
Private Const SW_SHOWDEFAULT As Long = 10

Private Const WM_DESTROY As Long = &H2
Private Const WM_PAINT As Long = &HF

Private Const CLASS_NAME As String = "helloWindow"
Private Const WINDOW_NAME As String = "Hello, World!"

Private Type POINTAPI
    x As Long
    y As Long
End Type

Private Type MSG
    hwnd As Long
    message As Long
    wParam As Long
    lParam As Long
    time As Long
    pt As POINTAPI
End Type

Private Type WNDCLASSEX
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
    hdc As Long
    fErase As Long
    rcPaint As RECT
    fRestore As Long
    fIncUpdate As Long
    rgbReserved As Byte
End Type

Private Declare Function GetModuleHandle Lib "kernel32" Alias "GetModuleHandleA" (ByVal lpModuleName As Long) As Long
Private Declare Function LoadIcon Lib "user32" Alias "LoadIconA" (ByVal hInstance As Long, ByVal lpIconName As Long) As Long
Private Declare Function LoadCursor Lib "user32" Alias "LoadCursorA" (ByVal hInstance As Long, ByVal lpCursorName As Long) As Long
Private Declare Function GetStockObject Lib "gdi32" (ByVal fnObject As Long) As Long
Private Declare Function RegisterClassEx Lib "user32" Alias "RegisterClassExA" (lpwcx As WNDCLASSEX) As Long
Private Declare Function CreateWindowEx Lib "user32" Alias "CreateWindowExA" (ByVal dwExStyle As Long, ByVal lpClassName As String, ByVal lpWindowName As String, ByVal dwStyle As Long, ByVal x As Long, ByVal y As Long, ByVal nWidth As Long, ByVal nHeight As Long, ByVal hWndParent As Long, ByVal hMenu As Long, ByVal hInstance As Long, lpParam As Any) As Long
Private Declare Function ShowWindow Lib "user32" (ByVal hwnd As Long, ByVal nCmdShow As Long) As Long
Private Declare Function UpdateWindow Lib "user32" (ByVal lhwnd As Long) As Long
Private Declare Function GetMessage Lib "user32" Alias "GetMessageA" (lpMsg As MSG, ByVal hwnd As Long, ByVal wMsgFilterMin As Long, ByVal wMsgFilterMax As Long) As Long
Private Declare Function TranslateMessage Lib "user32" (lpMsg As MSG) As Long
Private Declare Function DispatchMessage Lib "user32" Alias "DispatchMessageA" (lpMsg As MSG) As Long
Private Declare Sub PostQuitMessage Lib "user32" (ByVal nExitCode As Long)
Private Declare Function DefWindowProc Lib "user32" Alias "DefWindowProcA" (ByVal hwnd As Long, ByVal wMsg As Long, ByVal wParam As Long, ByVal lParam As Long) As Long
Private Declare Function BeginPaint Lib "user32" (ByVal hwnd As Long, lpPaint As PAINTSTRUCT) As Long
Private Declare Function EndPaint Lib "user32" (ByVal hwnd As Long, lpPaint As PAINTSTRUCT) As Long
Private Declare Function TextOut Lib "gdi32" Alias "TextOutA" (ByVal hdc As Long, ByVal x As Long, ByVal y As Long, ByVal lpString As String, ByVal nCount As Long) As Long

Private Function FuncPtr(ByVal p As Long) As Long
    FuncPtr = p
End Function

Private Function WindowProc(ByVal hwnd As Long, ByVal uMsg As Long, ByVal wParam As Long, ByVal lParam As Long) As Long
    Dim ps As PAINTSTRUCT
    Dim hdc As Long
    Dim strMessage As String
    strMessage = "Hello, Win32 GUI(VBA) World!"
    
    Select Case uMsg
    Case WM_PAINT
        hdc = BeginPaint(hwnd, ps)
        TextOut hdc, 0, 0, strMessage, Len(strMessage)
        EndPaint hwnd, ps
    Case WM_DESTROY
        Call PostQuitMessage(0)
    Case Else
        WindowProc = DefWindowProc(hwnd, uMsg, wParam, lParam)
        Exit Function
    End Select
    WindowProc = 0
End Function

Public Function WinMain() As Integer
    Dim wcex As WNDCLASSEX
    Dim hwnd As Long
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
    
    Call RegisterClassEx(wcex)
    
    hwnd = CreateWindowEx( _
        0, _
        CLASS_NAME, _
        WINDOW_NAME, _
        WS_OVERLAPPEDWINDOW, _
        CW_USEDEFAULT, CW_USEDEFAULT, 640, 480, _
        0, 0, wcex.hInstance, 0)
    
    Call ShowWindow(hwnd, SW_SHOWDEFAULT)
    Call UpdateWindow(hwnd)
    
    Do While (GetMessage(message, 0, 0, 0))
        Call TranslateMessage(message)
        Call DispatchMessage(message)
    Loop
    
    WinMain = message.wParam
End Function

Public Sub main()
    Call WinMain
End Sub

