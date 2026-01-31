Imports System
Imports System.Runtime.InteropServices

Public Class Hello

#Region "Win32 Structures and Constants"

    <StructLayout(LayoutKind.Sequential)>
    Private Structure POINT
        Public X As Integer
        Public Y As Integer
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Private Structure MSG
        Public hwnd As IntPtr
        Public message As UInteger
        Public wParam As IntPtr
        Public lParam As IntPtr
        Public time As UInteger
        Public pt As POINT
    End Structure

    <StructLayout(LayoutKind.Sequential, CharSet:=CharSet.Auto)>
    Private Structure WNDCLASSEX
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

    <StructLayout(LayoutKind.Sequential)>
    Private Structure RECT
        Public Left As Integer
        Public Top As Integer
        Public Right As Integer
        Public Bottom As Integer
    End Structure

    Private Delegate Function WndProcDelegate(hWnd As IntPtr, uMsg As UInteger, wParam As IntPtr, lParam As IntPtr) As IntPtr

    Private Const WS_OVERLAPPEDWINDOW As UInteger = &HCF0000UI
    Private Const WS_VISIBLE As UInteger = &H10000000UI
    Private Const CS_HREDRAW As UInteger = &H2UI
    Private Const CS_VREDRAW As UInteger = &H1UI
    Private Const WM_PAINT As UInteger = &HF
    Private Const WM_SIZE As UInteger = &H5
    Private Const WM_DESTROY As UInteger = &H2
    Private Const WM_QUIT As UInteger = &H12
    Private Const PM_REMOVE As UInteger = &H1
    Private Const CW_USEDEFAULT As Integer = &H80000000
    Private Const SW_SHOWDEFAULT As UInteger = 10
    Private Const IDI_APPLICATION As Integer = 32512
    Private Const IDC_ARROW As Integer = 32512
    Private Const COLOR_WINDOW As UInteger = 5

#End Region

#Region "Win32 Imports"

    <DllImport("user32.dll", CharSet:=CharSet.Auto)>
    Private Shared Function LoadIcon(hInstance As IntPtr, lpIconName As IntPtr) As IntPtr
    End Function

    <DllImport("user32.dll", CharSet:=CharSet.Auto)>
    Private Shared Function LoadCursor(hInstance As IntPtr, lpCursorName As IntPtr) As IntPtr
    End Function

    <DllImport("user32.dll", CharSet:=CharSet.Auto)>
    Private Shared Function RegisterClassEx(<[In]> ByRef lpwcx As WNDCLASSEX) As Short
    End Function

    <DllImport("user32.dll", CharSet:=CharSet.Auto)>
    Private Shared Function CreateWindowEx(dwExStyle As UInteger, lpClassName As String, lpWindowName As String,
        dwStyle As UInteger, x As Integer, y As Integer, nWidth As Integer, nHeight As Integer,
        hWndParent As IntPtr, hMenu As IntPtr, hInstance As IntPtr, lpParam As IntPtr) As IntPtr
    End Function

    <DllImport("user32.dll", CharSet:=CharSet.Auto)>
    Private Shared Function ShowWindow(hWnd As IntPtr, nCmdShow As UInteger) As Boolean
    End Function

    <DllImport("user32.dll", CharSet:=CharSet.Auto)>
    Private Shared Function UpdateWindow(hWnd As IntPtr) As Boolean
    End Function

    <DllImport("user32.dll", CharSet:=CharSet.Auto)>
    Private Shared Function GetMessage(<Out> ByRef lpMsg As MSG, hWnd As IntPtr, wMsgFilterMin As UInteger, wMsgFilterMax As UInteger) As Integer
    End Function

    <DllImport("user32.dll", CharSet:=CharSet.Auto)>
    Private Shared Function TranslateMessage(<[In]> ByRef lpMsg As MSG) As Integer
    End Function

    <DllImport("user32.dll", CharSet:=CharSet.Auto)>
    Private Shared Function DispatchMessage(<[In]> ByRef lpMsg As MSG) As IntPtr
    End Function

    <DllImport("user32.dll", CharSet:=CharSet.Auto)>
    Private Shared Sub PostQuitMessage(nExitCode As Integer)
    End Sub

    <DllImport("user32.dll", CharSet:=CharSet.Auto)>
    Private Shared Function DefWindowProc(hWnd As IntPtr, uMsg As UInteger, wParam As IntPtr, lParam As IntPtr) As IntPtr
    End Function

    <DllImport("user32.dll", CharSet:=CharSet.Auto)>
    Private Shared Function ValidateRect(hWnd As IntPtr, lpRect As IntPtr) As Boolean
    End Function

    <DllImport("user32.dll", CharSet:=CharSet.Auto)>
    Private Shared Function GetClientRect(hWnd As IntPtr, <Out> ByRef lpRect As RECT) As Boolean
    End Function

    <DllImport("kernel32.dll", CharSet:=CharSet.Auto)>
    Private Shared Function LoadLibrary(lpFileName As String) As IntPtr
    End Function

    <DllImport("kernel32.dll", CharSet:=CharSet.Ansi)>
    Private Shared Function GetProcAddress(hModule As IntPtr, lpProcName As String) As IntPtr
    End Function

    <DllImport("kernel32.dll")>
    Private Shared Function FreeLibrary(hModule As IntPtr) As Boolean
    End Function

#End Region

#Region "Direct2D Structures"

    <StructLayout(LayoutKind.Sequential)>
    Private Structure D2D1_COLOR_F
        Public r As Single
        Public g As Single
        Public b As Single
        Public a As Single

        Public Sub New(r As Single, g As Single, b As Single, a As Single)
            Me.r = r
            Me.g = g
            Me.b = b
            Me.a = a
        End Sub
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Private Structure D2D1_POINT_2F
        Public x As Single
        Public y As Single

        Public Sub New(x As Single, y As Single)
            Me.x = x
            Me.y = y
        End Sub
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Private Structure D2D1_SIZE_U
        Public width As UInteger
        Public height As UInteger

        Public Sub New(w As UInteger, h As UInteger)
            width = w
            height = h
        End Sub
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Private Structure D2D1_PIXEL_FORMAT
        Public format As UInteger
        Public alphaMode As UInteger
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Private Structure D2D1_RENDER_TARGET_PROPERTIES
        Public type As UInteger
        Public pixelFormat As D2D1_PIXEL_FORMAT
        Public dpiX As Single
        Public dpiY As Single
        Public usage As UInteger
        Public minLevel As UInteger
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Private Structure D2D1_HWND_RENDER_TARGET_PROPERTIES
        Public hwnd As IntPtr
        Public pixelSize As D2D1_SIZE_U
        Public presentOptions As UInteger
    End Structure

#End Region

#Region "Direct2D COM Delegates"

    <UnmanagedFunctionPointer(CallingConvention.StdCall)>
    Private Delegate Function D2D1CreateFactoryDelegate(factoryType As UInteger, ByRef riid As Guid, pFactoryOptions As IntPtr, <Out> ByRef ppFactory As IntPtr) As Integer

    <UnmanagedFunctionPointer(CallingConvention.StdCall)>
    Private Delegate Function CreateHwndRenderTargetDelegate(factory As IntPtr, ByRef rtProps As D2D1_RENDER_TARGET_PROPERTIES,
        ByRef hwndProps As D2D1_HWND_RENDER_TARGET_PROPERTIES, <Out> ByRef renderTarget As IntPtr) As Integer

    <UnmanagedFunctionPointer(CallingConvention.StdCall)>
    Private Delegate Function CreateSolidColorBrushDelegate(renderTarget As IntPtr, ByRef color As D2D1_COLOR_F, brushProps As IntPtr, <Out> ByRef brush As IntPtr) As Integer

    <UnmanagedFunctionPointer(CallingConvention.StdCall)>
    Private Delegate Sub BeginDrawDelegate(renderTarget As IntPtr)

    <UnmanagedFunctionPointer(CallingConvention.StdCall)>
    Private Delegate Function EndDrawDelegate(renderTarget As IntPtr, <Out> ByRef tag1 As ULong, <Out> ByRef tag2 As ULong) As Integer

    <UnmanagedFunctionPointer(CallingConvention.StdCall)>
    Private Delegate Sub ClearDelegate(renderTarget As IntPtr, ByRef color As D2D1_COLOR_F)

    <UnmanagedFunctionPointer(CallingConvention.StdCall)>
    Private Delegate Sub DrawLineDelegate(renderTarget As IntPtr, p0 As D2D1_POINT_2F, p1 As D2D1_POINT_2F, brush As IntPtr, strokeWidth As Single, strokeStyle As IntPtr)

    <UnmanagedFunctionPointer(CallingConvention.StdCall)>
    Private Delegate Function ResizeDelegate(renderTarget As IntPtr, ByRef size As D2D1_SIZE_U) As Integer

    <UnmanagedFunctionPointer(CallingConvention.StdCall)>
    Private Delegate Function ReleaseDelegate(obj As IntPtr) As UInteger

#End Region

    Private Shared g_hD2D1 As IntPtr
    Private Shared g_factory As IntPtr
    Private Shared g_renderTarget As IntPtr
    Private Shared g_brush As IntPtr
    Private Shared g_wndProc As WndProcDelegate

    Private Shared ReadOnly IID_ID2D1Factory As New Guid("06152247-6f50-465a-9245-118bfd3b6007")

    Private Shared Function WndProc(hWnd As IntPtr, msg As UInteger, wParam As IntPtr, lParam As IntPtr) As IntPtr
        Select Case msg
            Case WM_PAINT
                If g_renderTarget <> IntPtr.Zero Then Draw()
                ValidateRect(hWnd, IntPtr.Zero)
                Return IntPtr.Zero

            Case WM_SIZE
                If g_renderTarget <> IntPtr.Zero Then
                    Dim width As UInteger = CUInt(lParam.ToInt64() And &HFFFF)
                    Dim height As UInteger = CUInt((lParam.ToInt64() >> 16) And &HFFFF)
                    Dim size As New D2D1_SIZE_U(width, height)

                    Dim vt As IntPtr = Marshal.ReadIntPtr(g_renderTarget)
                    Dim resizePtr As IntPtr = Marshal.ReadIntPtr(vt, 58 * IntPtr.Size)  ' #58 ID2D1HwndRenderTarget::Resize
                    Dim resize As ResizeDelegate = Marshal.GetDelegateForFunctionPointer(Of ResizeDelegate)(resizePtr)
                    resize(g_renderTarget, size)
                End If
                Return IntPtr.Zero

            Case WM_DESTROY
                PostQuitMessage(0)
                Return IntPtr.Zero
        End Select

        Return DefWindowProc(hWnd, msg, wParam, lParam)
    End Function

    Private Shared Sub Draw()
        Dim vt As IntPtr = Marshal.ReadIntPtr(g_renderTarget)

        ' BeginDraw (#48)
        Dim beginDraw As BeginDrawDelegate = Marshal.GetDelegateForFunctionPointer(Of BeginDrawDelegate)(Marshal.ReadIntPtr(vt, 48 * IntPtr.Size))
        beginDraw(g_renderTarget)

        ' Clear (#47) - white
        Dim clear As ClearDelegate = Marshal.GetDelegateForFunctionPointer(Of ClearDelegate)(Marshal.ReadIntPtr(vt, 47 * IntPtr.Size))
        Dim white As New D2D1_COLOR_F(1, 1, 1, 1)
        clear(g_renderTarget, white)

        ' DrawLine (#15) - triangle
        Dim drawLine As DrawLineDelegate = Marshal.GetDelegateForFunctionPointer(Of DrawLineDelegate)(Marshal.ReadIntPtr(vt, 15 * IntPtr.Size))
        Dim p1 As New D2D1_POINT_2F(320, 120)
        Dim p2 As New D2D1_POINT_2F(480, 360)
        Dim p3 As New D2D1_POINT_2F(160, 360)

        drawLine(g_renderTarget, p1, p2, g_brush, 2.0F, IntPtr.Zero)
        drawLine(g_renderTarget, p2, p3, g_brush, 2.0F, IntPtr.Zero)
        drawLine(g_renderTarget, p3, p1, g_brush, 2.0F, IntPtr.Zero)

        ' EndDraw (#49)
        Dim endDraw As EndDrawDelegate = Marshal.GetDelegateForFunctionPointer(Of EndDrawDelegate)(Marshal.ReadIntPtr(vt, 49 * IntPtr.Size))
        Dim tag1, tag2 As ULong
        endDraw(g_renderTarget, tag1, tag2)
    End Sub

    Private Shared Function InitDirect2D(hWnd As IntPtr) As Boolean
        g_hD2D1 = LoadLibrary("d2d1.dll")
        If g_hD2D1 = IntPtr.Zero Then Return False

        Dim procAddr As IntPtr = GetProcAddress(g_hD2D1, "D2D1CreateFactory")
        If procAddr = IntPtr.Zero Then Return False

        Dim createFactory As D2D1CreateFactoryDelegate = Marshal.GetDelegateForFunctionPointer(Of D2D1CreateFactoryDelegate)(procAddr)
        Dim iid As Guid = IID_ID2D1Factory
        Dim hr As Integer = createFactory(0, iid, IntPtr.Zero, g_factory)
        If hr < 0 Then Return False

        ' Get client rect
        Dim rect As RECT
        GetClientRect(hWnd, rect)
        Dim width As UInteger = CUInt(rect.Right - rect.Left)
        Dim height As UInteger = CUInt(rect.Bottom - rect.Top)

        ' CreateHwndRenderTarget (#14)
        Dim rtProps As New D2D1_RENDER_TARGET_PROPERTIES()
        Dim hwndProps As New D2D1_HWND_RENDER_TARGET_PROPERTIES() With {
            .hwnd = hWnd,
            .pixelSize = New D2D1_SIZE_U(width, height),
            .presentOptions = 0
        }

        Dim vt As IntPtr = Marshal.ReadIntPtr(g_factory)
        Dim createHwndRTPtr As IntPtr = Marshal.ReadIntPtr(vt, 14 * IntPtr.Size)
        Dim createHwndRT As CreateHwndRenderTargetDelegate = Marshal.GetDelegateForFunctionPointer(Of CreateHwndRenderTargetDelegate)(createHwndRTPtr)
        hr = createHwndRT(g_factory, rtProps, hwndProps, g_renderTarget)
        If hr < 0 Then Return False

        ' CreateSolidColorBrush (#8) - blue
        vt = Marshal.ReadIntPtr(g_renderTarget)
        Dim createBrushPtr As IntPtr = Marshal.ReadIntPtr(vt, 8 * IntPtr.Size)
        Dim createBrush As CreateSolidColorBrushDelegate = Marshal.GetDelegateForFunctionPointer(Of CreateSolidColorBrushDelegate)(createBrushPtr)
        Dim blue As New D2D1_COLOR_F(0, 0, 1, 1)
        hr = createBrush(g_renderTarget, blue, IntPtr.Zero, g_brush)

        Return hr >= 0
    End Function

    Private Shared Sub Cleanup()
        If g_brush <> IntPtr.Zero Then
            Dim vt As IntPtr = Marshal.ReadIntPtr(g_brush)
            Dim release As ReleaseDelegate = Marshal.GetDelegateForFunctionPointer(Of ReleaseDelegate)(Marshal.ReadIntPtr(vt, 2 * IntPtr.Size))
            release(g_brush)
            g_brush = IntPtr.Zero
        End If

        If g_renderTarget <> IntPtr.Zero Then
            Dim vt As IntPtr = Marshal.ReadIntPtr(g_renderTarget)
            Dim release As ReleaseDelegate = Marshal.GetDelegateForFunctionPointer(Of ReleaseDelegate)(Marshal.ReadIntPtr(vt, 2 * IntPtr.Size))
            release(g_renderTarget)
            g_renderTarget = IntPtr.Zero
        End If

        If g_factory <> IntPtr.Zero Then
            Dim vt As IntPtr = Marshal.ReadIntPtr(g_factory)
            Dim release As ReleaseDelegate = Marshal.GetDelegateForFunctionPointer(Of ReleaseDelegate)(Marshal.ReadIntPtr(vt, 2 * IntPtr.Size))
            release(g_factory)
            g_factory = IntPtr.Zero
        End If

        If g_hD2D1 <> IntPtr.Zero Then
            FreeLibrary(g_hD2D1)
            g_hD2D1 = IntPtr.Zero
        End If
    End Sub

    <STAThread>
    Public Shared Function Main() As Integer
        Dim hInstance As IntPtr = Marshal.GetHINSTANCE(GetType(Hello).Module)
        g_wndProc = New WndProcDelegate(AddressOf WndProc)

        Dim wcex As New WNDCLASSEX() With {
            .cbSize = CUInt(Marshal.SizeOf(Of WNDCLASSEX)()),
            .style = CS_HREDRAW Or CS_VREDRAW,
            .lpfnWndProc = g_wndProc,
            .hInstance = hInstance,
            .hIcon = LoadIcon(hInstance, New IntPtr(IDI_APPLICATION)),
            .hCursor = LoadCursor(IntPtr.Zero, New IntPtr(IDC_ARROW)),
            .hbrBackground = New IntPtr(COLOR_WINDOW + 1),
            .lpszMenuName = "",
            .lpszClassName = "HelloD2DClass"
        }

        RegisterClassEx(wcex)

        Dim hWnd As IntPtr = CreateWindowEx(0, wcex.lpszClassName, "Hello, Direct2D(VB.NET) World!",
            WS_OVERLAPPEDWINDOW, CW_USEDEFAULT, CW_USEDEFAULT, 640, 480,
            IntPtr.Zero, IntPtr.Zero, hInstance, IntPtr.Zero)

        If hWnd = IntPtr.Zero OrElse Not InitDirect2D(hWnd) Then
            Console.WriteLine("Initialization failed")
            Cleanup()
            Return 1
        End If

        ShowWindow(hWnd, SW_SHOWDEFAULT)
        UpdateWindow(hWnd)

        Dim msg As MSG
        While GetMessage(msg, IntPtr.Zero, 0, 0) <> 0
            TranslateMessage(msg)
            DispatchMessage(msg)
        End While

        Cleanup()
        Return CInt(msg.wParam)
    End Function

End Class
