Imports System
Imports System.Runtime.InteropServices

Public Class HelloWindow
    Structure POINT
        Public x As Integer
        Public y As Integer
    End Structure

    Structure MSG
        Public hwnd As IntPtr
        Public message As UInteger
        Public wParam As IntPtr
        Public lParam As IntPtr
        Public time As UInteger
        Public pt As POINT
    End Structure

    Delegate Function WndProcDelegate(hWnd As IntPtr, uMsg As UInteger, wParam As IntPtr, lParam As IntPtr) As IntPtr

    <StructLayout(LayoutKind.Sequential, CharSet := CharSet.Auto)>
    Structure WNDCLASSEX
        Public cbSize As UInteger
        Public style As UInteger
        Public lpfnWndProc As WndProcDelegate
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

    Structure RECT
        Public Left As Integer
        Public Top As Integer
        Public Right As Integer
        Public Bottom As Integer
    End Structure

    Structure PAINTSTRUCT
        Public hdc As IntPtr
        Public fErase As Integer
        Public rcPaint As RECT
        Public fRestore As Integer
        Public fIncUpdate As Integer
        <MarshalAs(UnmanagedType.ByValArray, SizeConst := 32)>
        Public rgbReserved As Byte()
    End Structure

    Structure TRIVERTEX
        Public x As Integer
        Public y As Integer
        Public Red As UShort
        Public Green As UShort
        Public Blue As UShort
        Public Alpha As UShort
    End Structure

    Structure GRADIENT_TRIANGLE
        Public Vertex1 As UInteger
        Public Vertex2 As UInteger
        Public Vertex3 As UInteger
    End Structure

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
     ) As Integer
 
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

    Declare Auto Function GradientFill Lib "msimg32.dll" ( _
        hdc As IntPtr, _
        pVertex As TRIVERTEX(), _
        nVertex As UInteger, _
        pMesh As IntPtr, _
        nMesh As UInteger, _
        ulMode As UInteger _
    ) As Integer

     Function WndProc(hWnd As IntPtr, uMsg As UInteger, wParam As IntPtr, lParam As IntPtr) As IntPtr
        Dim pAINTSTRUCT As PAINTSTRUCT = Nothing
        Dim result As IntPtr
        If uMsg <> 2 Then
            If uMsg <> 15 Then
                result = DefWindowProc(hWnd, uMsg, wParam, lParam)
                Return result
            End If
            Dim hdc As IntPtr = BeginPaint(hWnd, pAINTSTRUCT)
            OnPaint(hdc)
            EndPaint(hWnd, pAINTSTRUCT)
        Else
            PostQuitMessage(0)
        End If
        result = IntPtr.Zero
        Return result
    End Function

     Sub OnPaint(hdc As IntPtr)
        DrawTriangle(hdc)
    End Sub

     Sub DrawTriangle(hdc As IntPtr)
        Dim WIDTH As Integer = 640
        Dim HEIGHT As Integer = 480

        Dim array As TRIVERTEX() = New TRIVERTEX(3 - 1) {}
        array(0).x     = WIDTH / 2
        array(0).y     = HEIGHT / 4
        array(0).Red   = &hffff
        array(0).Green = 0
        array(0).Blue  = 0
        array(0).Alpha = 0

        array(1).x     = WIDTH * 3 / 4
        array(1).y     = HEIGHT * 3 / 4
        array(1).Red   = 0
        array(1).Green = &hffff
        array(1).Blue  = 0
        array(1).Alpha = 0

        array(2).x     = WIDTH / 4
        array(2).y     = HEIGHT * 3 / 4
        array(2).Red   = 0
        array(2).Green = 0
        array(2).Blue  = &hffff
        array(2).Alpha = 0

        Dim vertexArray As Integer() = New Integer() { 0, 1, 2 }
        GradientFill(hdc, array, 3,  Marshal.UnsafeAddrOfPinnedArrayElement(Of Integer)(vertexArray, 0), 1, 2)
    End Sub

     Function WinMain() As Integer
        Dim hINSTANCE As IntPtr = Marshal.GetHINSTANCE(GetType(HelloWindow).[Module])

        Dim wcex As WNDCLASSEX = Nothing
        wcex.cbSize         = CUInt(Marshal.SizeOf(Of WNDCLASSEX)(wcex))
        wcex.style          = CS_HREDRAW Or CS_VREDRAW
        wcex.lpfnWndProc    = New WndProcDelegate(AddressOf WndProc)
        wcex.cbClsExtra     = 0
        wcex.cbWndExtra     = 0
        wcex.hInstance      = hINSTANCE
        wcex.hIcon          = LoadIcon(hINSTANCE, New IntPtr(IDI_APPLICATION))
        wcex.hCursor        = LoadIcon(hINSTANCE, New IntPtr(IDC_ARROW))
        wcex.hbrBackground  = New IntPtr(COLOR_WINDOW + 1)
        wcex.lpszMenuName   = ""
        wcex.lpszClassName  = "helloWindow"
        wcex.hIconSm        = IntPtr.Zero
        RegisterClassEx(wcex)

        Dim hWnd As IntPtr = CreateWindowEx(0, 
            wcex.lpszClassName, 
            "Hello, World!", 
            WS_OVERLAPPEDWINDOW, _
            CW_USEDEFAULT, CW_USEDEFAULT, 640, 480, _
            IntPtr.Zero, IntPtr.Zero, hInstance, IntPtr.Zero)
 
        ShowWindow(hWnd, SW_SHOWDEFAULT)
        UpdateWindow(hWnd)

        Dim msg As MSG = Nothing
        While GetMessage(msg, IntPtr.Zero, 0, 0) > 0
            TranslateMessage(msg)
            DispatchMessage(msg)
        End While

        Return CInt(msg.wParam)
    End Function

    <STAThread()> _
    Public Shared Sub Main()
        Dim hello As New HelloWindow
        hello.WinMain()
    End Sub
End Class
