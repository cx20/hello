Imports System.Runtime.InteropServices
 
Public Class HelloWindow
    Const WS_CAPTION As Integer = &HC00000
    Const WS_MAXIMIZEBOX As Integer = &H10000
    Const WS_MINIMIZEBOX As Integer = &H20000
    Const WS_OVERLAPPED As Integer = &H0
    Const WS_SYSMENU As Integer = &H80000
    Const WS_THICKFRAME As Integer = &H40000
    Const WS_OVERLAPPEDWINDOW As Integer = ( _
        WS_OVERLAPPED Or _
        WS_CAPTION Or _
        WS_SYSMENU Or _
        WS_THICKFRAME Or _
        WS_MINIMIZEBOX Or _
        WS_MAXIMIZEBOX)
 
    Const COLOR_WINDOW As Integer = 5
    Const COLOR_BTNFACE As Integer = 15
 
    Const CS_VREDRAW As Integer = &H1
    Const CS_HREDRAW As Integer = &H2
    Const CW_USEDEFAULT As Integer = &H80000000
 
    Const IDI_APPLICATION As Integer = 32512
    Const IDC_ARROW As Integer = 32512
 
    Const LTGRAY_BRUSH As Integer = 1
 
    Const SW_SHOWNORMAL As Integer = 1
    Const SW_SHOWDEFAULT As Integer = 10
 
    Const WM_DESTROY As Integer = &H2
    Const WM_PAINT As Integer = &HF
 
    Delegate Function WndProcDelgate( _
        ByVal hWnd As IntPtr, _
        ByVal Message As Integer, _
        ByVal wParam As IntPtr, _
        ByVal lParam As IntPtr _
    ) As IntPtr
 
    <StructLayout(LayoutKind.Sequential)> _
    Structure POINTAPI
        Public x As Integer
        Public y As Integer
    End Structure
 
    <StructLayout(LayoutKind.Sequential, CharSet:=CharSet.Auto)> _
    Structure MSG
        Public hWnd As IntPtr
        Public Message As Integer
        Public wParam As IntPtr
        Public lParam As IntPtr
        Public time As Integer
        Public pt As POINTAPI
    End Structure
 
    <StructLayout(LayoutKind.Sequential, CharSet:=CharSet.Auto)> _
    Structure WNDCLASSEX
        Public cbSize As Integer
        Public style As Integer
        Public lpfnWndProc As WndProcDelgate
        Public cbClsExtra As Integer
        Public cbWndExtra As Integer
        Public hInstance As IntPtr
        Public hIcon As IntPtr
        Public hCursor As IntPtr
        Public hbrBackground As IntPtr
        Public lpszMenuName As String
        Public lpszClassName As String
        Public hIconSm As IntPtr
    End Structure
 
    <StructLayout(LayoutKind.Sequential)> _
    Structure RECT
        Public Left As Integer
        Public Top As Integer
        Public Right As Integer
        Public Bottom As Integer
    End Structure
 
    <StructLayout(LayoutKind.Sequential)> _
    Structure PAINTSTRUCT
        Public hdc As IntPtr
        Public fErase As Integer
        Public rcPaint As RECT
        Public fRestore As Integer
        Public fIncUpdate As Integer
        <MarshalAs(UnmanagedType.ByValArray, SizeConst := 32)> _
        Public rgbReserved As Byte()
    End Structure
 
    Declare Auto Function LoadCursor Lib "user32" ( _
        ByVal hInstance As IntPtr, _
        ByVal lpCursorName As IntPtr _
    ) As IntPtr
 
    Declare Auto Function LoadIcon Lib "user32" ( _
        ByVal hInstance As IntPtr, _
        ByVal lpIconName As IntPtr _
    ) As IntPtr
 
    Declare Auto Function RegisterClassEx Lib "user32" ( _
        ByRef pcWndClassEx As WNDCLASSEX _
    ) As Integer
 
    Declare Auto Function CreateWindowEx Lib "user32" ( _
        ByVal dwExStyle As Integer, _
        ByVal lpClassName As String, _
        ByVal lpWindowName As String, _
        ByVal dwStyle As Integer, _
        ByVal x As Integer, _
        ByVal y As Integer, _
        ByVal nWidth As Integer, _
        ByVal nHeight As Integer, _
        ByVal hWndParent As IntPtr, _
        ByVal hMenu As IntPtr, _
        ByVal hInstance As IntPtr, _
        ByVal lpParam As IntPtr _
    ) As IntPtr
 
    Declare Function ShowWindow Lib "user32" ( _
        ByVal hWnd As IntPtr, _
        ByVal nCmdShow As Integer _
    ) As Boolean
 
    Declare Function UpdateWindow Lib "user32" (ByVal hWnd As IntPtr) As Boolean
 
    Declare Auto Function GetMessage Lib "user32" ( _
        ByRef lpMsg As MSG, _
        ByVal hWnd As IntPtr, _
        ByVal wMsgFilterMin As Integer, _
        ByVal wMsgFilterMax As Integer _
     ) As Boolean
 
    Declare Function TranslateMessage Lib "user32" ( _
        ByRef lpMsg As MSG _
    ) As Boolean
 
    Declare Auto Function DispatchMessage Lib "user32" ( _
        ByRef lpMsg As MSG _
    ) As IntPtr
 
    Declare Sub PostQuitMessage Lib "user32" ( _
        ByVal nExitCode As Integer _
    )
 
    Declare Function BeginPaint Lib "user32" ( _
        ByVal hwnd As IntPtr, _
        ByRef lpPaint As PAINTSTRUCT _
    ) As IntPtr
 
    Declare Function EndPaint Lib "user32" ( _
        ByVal hwnd As IntPtr, _
        ByRef lpPaint As PAINTSTRUCT _
    ) As IntPtr
 
    Declare Auto Function TextOut Lib "gdi32" ( _
        ByVal hdc As IntPtr, _
        ByVal x As Integer, _
        ByVal y As Integer, _
        ByVal lpString As String, _
        ByVal nCount As Integer _
    ) As Integer
 
    Declare Function GetStockObject Lib "gdi32" ( _
        ByVal nIndex As Integer _
    ) As IntPtr
 
    Declare Auto Function DefWindowProc Lib "user32" ( _
        ByVal hWnd As IntPtr, _
        ByVal wMsg As Integer, _
        ByVal wParam As IntPtr, _
        ByVal lParam As IntPtr _
    ) As IntPtr
 
    Function WndProc( _
        ByVal hWnd As IntPtr, _
        ByVal msg As Integer, _
        ByVal wParam As IntPtr, _
        ByVal lParam As IntPtr _
    ) As IntPtr
 
        Dim ps As New PAINTSTRUCT
        Dim hdc As IntPtr
        Dim strMessage As String
        strMessage = "Hello, Win32 GUI(VB.NET) World!"
 
        Select Case msg
            Case WM_PAINT
                hdc = BeginPaint(hwnd, ps)
                TextOut( hdc, 0, 0, strMessage, Len(strMessage) )
                EndPaint( hwnd, ps )
            Case WM_DESTROY
                PostQuitMessage(0)
            Case Else
                Return DefWindowProc(hWnd, msg, wParam, lParam)
        End Select
 
        Return IntPtr.Zero
    End Function
 
    Public Function WinMain() As Integer
        Const CLASS_NAME As String = "helloWindow"
        Const WINDOW_NAME As String = "Hello, World!"
 
        Dim hInstance As IntPtr = Marshal.GetHINSTANCE(GetType(HelloWindow).Module)
        Dim hWnd As IntPtr
        Dim msg As MSG
 
        Dim wcex As New WNDCLASSEX
        With wcex
            .cbSize = Marshal.SizeOf(wcex)
            .style = CS_HREDRAW Or CS_VREDRAW
            .lpfnWndProc = New WndProcDelgate(AddressOf WndProc)
            .cbClsExtra = 0
            .cbWndExtra = 0
            .hInstance = hInstance
            .hIcon = LoadIcon(hInstance, New IntPtr(IDI_APPLICATION))
            .hCursor = LoadCursor(hInstance, New IntPtr(IDC_ARROW))
            .hbrBackground = New IntPtr(COLOR_WINDOW + 1)
            .lpszMenuName = Nothing
            .lpszClassName = CLASS_NAME
            .hIconSm = LoadIcon(hInstance, New IntPtr(IDI_APPLICATION))
        End With
 
        RegisterClassEx(wcex)
 
        hWnd = CreateWindowEx( _
            0, _
            CLASS_NAME, _
            WINDOW_NAME, _
            WS_OVERLAPPEDWINDOW, _
            CW_USEDEFAULT, CW_USEDEFAULT, 640, 480, _
            IntPtr.Zero, IntPtr.Zero, hInstance, IntPtr.Zero)
 
        ShowWindow(hWnd, SW_SHOWDEFAULT)
        UpdateWindow(hWnd)
 
        Do While GetMessage(msg, IntPtr.Zero, 0, 0)
            TranslateMessage(msg)
            DispatchMessage(msg)
        Loop
 
        Return CType(msg.wParam, Integer)
    End Function
 
    Public Shared Sub Main()
        Dim hello As New HelloWindow
        hello.WinMain()
    End Sub
End Class
