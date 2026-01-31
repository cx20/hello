// F# Direct2D Triangle Sample - No external libraries
// Using P/Invoke and COM vtable calls

open System
open System.Runtime.InteropServices

// ============================================================================
// Win32 Constants
// ============================================================================
module Win32Constants =
    let WS_OVERLAPPEDWINDOW = 0x00CF0000u
    let WS_VISIBLE          = 0x10000000u
    let CS_HREDRAW          = 0x0002u
    let CS_VREDRAW          = 0x0001u

    let WM_PAINT            = 0x000Fu
    let WM_SIZE             = 0x0005u
    let WM_DESTROY          = 0x0002u
    let WM_QUIT             = 0x0012u

    let CW_USEDEFAULT       = 0x80000000
    let SW_SHOWDEFAULT      = 10u
    let IDI_APPLICATION     = 32512
    let IDC_ARROW           = 32512
    let COLOR_WINDOW        = 5u

// ============================================================================
// Win32 Structures
// ============================================================================
[<Struct; StructLayout(LayoutKind.Sequential)>]
type POINT =
    val mutable X: int
    val mutable Y: int

[<Struct; StructLayout(LayoutKind.Sequential)>]
type MSG =
    val mutable hwnd: IntPtr
    val mutable message: uint32
    val mutable wParam: IntPtr
    val mutable lParam: IntPtr
    val mutable time: uint32
    val mutable pt: POINT

[<Struct; StructLayout(LayoutKind.Sequential)>]
type RECT =
    val mutable Left: int
    val mutable Top: int
    val mutable Right: int
    val mutable Bottom: int

type WndProcDelegate = delegate of IntPtr * uint32 * IntPtr * IntPtr -> IntPtr

[<Struct; StructLayout(LayoutKind.Sequential, CharSet = CharSet.Auto)>]
type WNDCLASSEX =
    val mutable cbSize: uint32
    val mutable style: uint32
    val mutable lpfnWndProc: WndProcDelegate
    val mutable cbClsExtra: int
    val mutable cbWndExtra: int
    val mutable hInstance: IntPtr
    val mutable hIcon: IntPtr
    val mutable hCursor: IntPtr
    val mutable hbrBackground: IntPtr
    val mutable lpszMenuName: string
    val mutable lpszClassName: string
    val mutable hIconSm: IntPtr

// ============================================================================
// Direct2D Structures
// ============================================================================
[<Struct; StructLayout(LayoutKind.Sequential)>]
type D2D1_COLOR_F =
    val mutable r: float32
    val mutable g: float32
    val mutable b: float32
    val mutable a: float32

    new(r, g, b, a) = { r = r; g = g; b = b; a = a }

[<Struct; StructLayout(LayoutKind.Sequential)>]
type D2D1_POINT_2F =
    val mutable x: float32
    val mutable y: float32

    new(x, y) = { x = x; y = y }

[<Struct; StructLayout(LayoutKind.Sequential)>]
type D2D1_SIZE_U =
    val mutable width: uint32
    val mutable height: uint32

    new(w, h) = { width = w; height = h }

[<Struct; StructLayout(LayoutKind.Sequential)>]
type D2D1_PIXEL_FORMAT =
    val mutable format: uint32
    val mutable alphaMode: uint32

[<Struct; StructLayout(LayoutKind.Sequential)>]
type D2D1_RENDER_TARGET_PROPERTIES =
    val mutable ``type``: uint32
    val mutable pixelFormat: D2D1_PIXEL_FORMAT
    val mutable dpiX: float32
    val mutable dpiY: float32
    val mutable usage: uint32
    val mutable minLevel: uint32

[<Struct; StructLayout(LayoutKind.Sequential)>]
type D2D1_HWND_RENDER_TARGET_PROPERTIES =
    val mutable hwnd: IntPtr
    val mutable pixelSize: D2D1_SIZE_U
    val mutable presentOptions: uint32

// ============================================================================
// P/Invoke Declarations
// ============================================================================
module NativeMethods =
    [<DllImport("user32.dll", CharSet = CharSet.Auto)>]
    extern IntPtr LoadIcon(IntPtr hInstance, IntPtr lpIconName)

    [<DllImport("user32.dll", CharSet = CharSet.Auto)>]
    extern IntPtr LoadCursor(IntPtr hInstance, IntPtr lpCursorName)

    [<DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)>]
    extern int16 RegisterClassEx([<In>] WNDCLASSEX& lpwcx)

    [<DllImport("user32.dll", CharSet = CharSet.Auto)>]
    extern IntPtr CreateWindowEx(
        uint32 dwExStyle,
        string lpClassName,
        string lpWindowName,
        uint32 dwStyle,
        int x, int y, int nWidth, int nHeight,
        IntPtr hWndParent,
        IntPtr hMenu,
        IntPtr hInstance,
        IntPtr lpParam)

    [<DllImport("user32.dll", CharSet = CharSet.Auto)>]
    extern bool ShowWindow(IntPtr hWnd, uint32 nCmdShow)

    [<DllImport("user32.dll", CharSet = CharSet.Auto)>]
    extern bool UpdateWindow(IntPtr hWnd)

    [<DllImport("user32.dll", CharSet = CharSet.Auto)>]
    extern int GetMessage([<Out>] MSG& lpMsg, IntPtr hWnd, uint32 wMsgFilterMin, uint32 wMsgFilterMax)

    [<DllImport("user32.dll", CharSet = CharSet.Auto)>]
    extern int TranslateMessage([<In>] MSG& lpMsg)

    [<DllImport("user32.dll", CharSet = CharSet.Auto)>]
    extern IntPtr DispatchMessage([<In>] MSG& lpMsg)

    [<DllImport("user32.dll", CharSet = CharSet.Auto)>]
    extern unit PostQuitMessage(int nExitCode)

    [<DllImport("user32.dll", CharSet = CharSet.Auto)>]
    extern IntPtr DefWindowProc(IntPtr hWnd, uint32 uMsg, IntPtr wParam, IntPtr lParam)

    [<DllImport("user32.dll", CharSet = CharSet.Auto)>]
    extern bool ValidateRect(IntPtr hWnd, IntPtr lpRect)

    [<DllImport("user32.dll", CharSet = CharSet.Auto)>]
    extern bool GetClientRect(IntPtr hWnd, [<Out>] RECT& lpRect)

    [<DllImport("kernel32.dll", CharSet = CharSet.Auto)>]
    extern IntPtr LoadLibrary(string lpFileName)

    [<DllImport("kernel32.dll", CharSet = CharSet.Ansi)>]
    extern IntPtr GetProcAddress(IntPtr hModule, string lpProcName)

    [<DllImport("kernel32.dll")>]
    extern bool FreeLibrary(IntPtr hModule)

// ============================================================================
// Direct2D COM Delegate Types
// ============================================================================
module DelegateTypes =
    // D2D1CreateFactory
    type D2D1CreateFactoryDelegate = delegate of uint32 * byref<Guid> * IntPtr * byref<IntPtr> -> int

    // ID2D1Factory
    type CreateHwndRenderTargetDelegate = delegate of IntPtr * byref<D2D1_RENDER_TARGET_PROPERTIES> * byref<D2D1_HWND_RENDER_TARGET_PROPERTIES> * byref<IntPtr> -> int

    // ID2D1RenderTarget
    type CreateSolidColorBrushDelegate = delegate of IntPtr * byref<D2D1_COLOR_F> * IntPtr * byref<IntPtr> -> int
    type BeginDrawDelegate = delegate of IntPtr -> unit
    type EndDrawDelegate = delegate of IntPtr * byref<uint64> * byref<uint64> -> int
    type ClearDelegate = delegate of IntPtr * byref<D2D1_COLOR_F> -> unit
    type DrawLineDelegate = delegate of IntPtr * D2D1_POINT_2F * D2D1_POINT_2F * IntPtr * float32 * IntPtr -> unit

    // ID2D1HwndRenderTarget
    type ResizeDelegate = delegate of IntPtr * byref<D2D1_SIZE_U> -> int

    // IUnknown
    type ReleaseDelegate = delegate of IntPtr -> uint32

// ============================================================================
// Helper Functions
// ============================================================================
module Helpers =
    let inline getVTableMethod<'TDelegate when 'TDelegate :> Delegate> (comPtr: IntPtr) (index: int) : 'TDelegate =
        let vTable = Marshal.ReadIntPtr(comPtr)
        let methodPtr = Marshal.ReadIntPtr(vTable, index * IntPtr.Size)
        Marshal.GetDelegateForFunctionPointer<'TDelegate>(methodPtr)

    let releaseComObject (ptr: IntPtr) =
        if ptr <> IntPtr.Zero then
            let release = getVTableMethod<DelegateTypes.ReleaseDelegate> ptr 2
            release.Invoke(ptr) |> ignore

// ============================================================================
// GUIDs
// ============================================================================
module Guids =
    let IID_ID2D1Factory = Guid("06152247-6f50-465a-9245-118bfd3b6007")

// ============================================================================
// Direct2D Application
// ============================================================================
module Direct2DApp =
    let mutable private g_hD2D1 = IntPtr.Zero
    let mutable private g_factory = IntPtr.Zero
    let mutable private g_renderTarget = IntPtr.Zero
    let mutable private g_brush = IntPtr.Zero

    let private draw () =
        if g_renderTarget <> IntPtr.Zero then
            // BeginDraw (#48)
            let beginDraw = Helpers.getVTableMethod<DelegateTypes.BeginDrawDelegate> g_renderTarget 48
            beginDraw.Invoke(g_renderTarget)

            // Clear (#47) - white
            let clear = Helpers.getVTableMethod<DelegateTypes.ClearDelegate> g_renderTarget 47
            let mutable white = D2D1_COLOR_F(1.0f, 1.0f, 1.0f, 1.0f)
            clear.Invoke(g_renderTarget, &white)

            // DrawLine (#15) - triangle
            let drawLine = Helpers.getVTableMethod<DelegateTypes.DrawLineDelegate> g_renderTarget 15
            let p1 = D2D1_POINT_2F(320.0f, 120.0f)
            let p2 = D2D1_POINT_2F(480.0f, 360.0f)
            let p3 = D2D1_POINT_2F(160.0f, 360.0f)

            drawLine.Invoke(g_renderTarget, p1, p2, g_brush, 2.0f, IntPtr.Zero)
            drawLine.Invoke(g_renderTarget, p2, p3, g_brush, 2.0f, IntPtr.Zero)
            drawLine.Invoke(g_renderTarget, p3, p1, g_brush, 2.0f, IntPtr.Zero)

            // EndDraw (#49)
            let endDraw = Helpers.getVTableMethod<DelegateTypes.EndDrawDelegate> g_renderTarget 49
            let mutable tag1 = 0UL
            let mutable tag2 = 0UL
            endDraw.Invoke(g_renderTarget, &tag1, &tag2) |> ignore

    let private resize (width: uint32) (height: uint32) =
        if g_renderTarget <> IntPtr.Zero then
            let mutable size = D2D1_SIZE_U(width, height)
            let resize = Helpers.getVTableMethod<DelegateTypes.ResizeDelegate> g_renderTarget 58
            resize.Invoke(g_renderTarget, &size) |> ignore

    let wndProc (hWnd: IntPtr) (msg: uint32) (wParam: IntPtr) (lParam: IntPtr) : IntPtr =
        match msg with
        | m when m = Win32Constants.WM_PAINT ->
            draw ()
            NativeMethods.ValidateRect(hWnd, IntPtr.Zero) |> ignore
            IntPtr.Zero

        | m when m = Win32Constants.WM_SIZE ->
            let width = uint32 (lParam.ToInt64() &&& 0xFFFFL)
            let height = uint32 ((lParam.ToInt64() >>> 16) &&& 0xFFFFL)
            resize width height
            IntPtr.Zero

        | m when m = Win32Constants.WM_DESTROY ->
            NativeMethods.PostQuitMessage(0)
            IntPtr.Zero

        | _ ->
            NativeMethods.DefWindowProc(hWnd, msg, wParam, lParam)

    let initDirect2D (hWnd: IntPtr) : bool =
        // Load d2d1.dll
        g_hD2D1 <- NativeMethods.LoadLibrary("d2d1.dll")
        if g_hD2D1 = IntPtr.Zero then
            printfn "Failed to load d2d1.dll"
            false
        else
            // Get D2D1CreateFactory
            let procAddr = NativeMethods.GetProcAddress(g_hD2D1, "D2D1CreateFactory")
            if procAddr = IntPtr.Zero then
                printfn "Failed to get D2D1CreateFactory"
                false
            else
                // Create Factory
                let createFactory = Marshal.GetDelegateForFunctionPointer<DelegateTypes.D2D1CreateFactoryDelegate>(procAddr)
                let mutable iid = Guids.IID_ID2D1Factory
                let hr = createFactory.Invoke(0u, &iid, IntPtr.Zero, &g_factory)

                if hr < 0 then
                    printfn "Failed to create D2D1 factory: %X" hr
                    false
                else
                    printfn "D2D1 Factory created: %X" (int64 g_factory)

                    // Get client rect
                    let mutable rect = RECT()
                    NativeMethods.GetClientRect(hWnd, &rect) |> ignore
                    let width = uint32 (rect.Right - rect.Left)
                    let height = uint32 (rect.Bottom - rect.Top)

                    // Create HwndRenderTarget (#14)
                    let mutable rtProps = D2D1_RENDER_TARGET_PROPERTIES()
                    let mutable hwndProps = D2D1_HWND_RENDER_TARGET_PROPERTIES()
                    hwndProps.hwnd <- hWnd
                    hwndProps.pixelSize <- D2D1_SIZE_U(width, height)
                    hwndProps.presentOptions <- 0u

                    let createHwndRT = Helpers.getVTableMethod<DelegateTypes.CreateHwndRenderTargetDelegate> g_factory 14
                    let hrRT = createHwndRT.Invoke(g_factory, &rtProps, &hwndProps, &g_renderTarget)

                    if hrRT < 0 then
                        printfn "Failed to create render target: %X" hrRT
                        false
                    else
                        printfn "Render target created: %X" (int64 g_renderTarget)

                        // Create SolidColorBrush (#8) - blue
                        let createBrush = Helpers.getVTableMethod<DelegateTypes.CreateSolidColorBrushDelegate> g_renderTarget 8
                        let mutable blue = D2D1_COLOR_F(0.0f, 0.0f, 1.0f, 1.0f)
                        let hrBrush = createBrush.Invoke(g_renderTarget, &blue, IntPtr.Zero, &g_brush)

                        if hrBrush < 0 then
                            printfn "Failed to create brush: %X" hrBrush
                            false
                        else
                            printfn "Brush created: %X" (int64 g_brush)
                            true

    let cleanup () =
        printfn "[Cleanup] - Start"

        // Release brush
        if g_brush <> IntPtr.Zero then
            Helpers.releaseComObject g_brush
            g_brush <- IntPtr.Zero

        // Release render target
        if g_renderTarget <> IntPtr.Zero then
            Helpers.releaseComObject g_renderTarget
            g_renderTarget <- IntPtr.Zero

        // Release factory
        if g_factory <> IntPtr.Zero then
            Helpers.releaseComObject g_factory
            g_factory <- IntPtr.Zero

        // Free library
        if g_hD2D1 <> IntPtr.Zero then
            NativeMethods.FreeLibrary(g_hD2D1) |> ignore
            g_hD2D1 <- IntPtr.Zero

// ============================================================================
// Entry Point
// ============================================================================
module Program =
    let mutable private wndProcDelegate: WndProcDelegate = null

    [<EntryPoint; STAThread>]
    let main argv =
        printfn "=========================================="
        printfn "[Main] - F# Direct2D Triangle Demo"
        printfn "=========================================="

        let CLASS_NAME = "HelloD2DClass"
        let WINDOW_NAME = "Hello, Direct2D(F#) World!"

        let hInstance = Marshal.GetHINSTANCE(typeof<D2D1_COLOR_F>.Module)
        printfn "hInstance: %X" (int64 hInstance)

        wndProcDelegate <- WndProcDelegate(Direct2DApp.wndProc)

        let mutable wndClassEx = WNDCLASSEX()
        wndClassEx.cbSize <- uint32 (Marshal.SizeOf(typeof<WNDCLASSEX>))
        wndClassEx.style <- Win32Constants.CS_HREDRAW ||| Win32Constants.CS_VREDRAW
        wndClassEx.lpfnWndProc <- wndProcDelegate
        wndClassEx.cbClsExtra <- 0
        wndClassEx.cbWndExtra <- 0
        wndClassEx.hInstance <- hInstance
        wndClassEx.hIcon <- NativeMethods.LoadIcon(hInstance, IntPtr(Win32Constants.IDI_APPLICATION))
        wndClassEx.hCursor <- NativeMethods.LoadCursor(IntPtr.Zero, IntPtr(Win32Constants.IDC_ARROW))
        wndClassEx.hbrBackground <- IntPtr(int (Win32Constants.COLOR_WINDOW + 1u))
        wndClassEx.lpszMenuName <- ""
        wndClassEx.lpszClassName <- CLASS_NAME
        wndClassEx.hIconSm <- IntPtr.Zero

        let atom = NativeMethods.RegisterClassEx(&wndClassEx)
        if atom = 0s then
            let error = Marshal.GetLastWin32Error()
            printfn "Failed to register window class. Error: %d" error
            1
        else
            printfn "Window class registered. Atom: %d" atom

            let hwnd = NativeMethods.CreateWindowEx(
                0u,
                CLASS_NAME,
                WINDOW_NAME,
                Win32Constants.WS_OVERLAPPEDWINDOW,
                Win32Constants.CW_USEDEFAULT,
                Win32Constants.CW_USEDEFAULT,
                640, 480,
                IntPtr.Zero,
                IntPtr.Zero,
                hInstance,
                IntPtr.Zero
            )

            if hwnd = IntPtr.Zero then
                printfn "Failed to create window"
                1
            else
                printfn "Window created: %X" (int64 hwnd)

                if not (Direct2DApp.initDirect2D hwnd) then
                    printfn "Failed to initialize Direct2D"
                    Direct2DApp.cleanup ()
                    1
                else
                    NativeMethods.ShowWindow(hwnd, Win32Constants.SW_SHOWDEFAULT) |> ignore
                    NativeMethods.UpdateWindow(hwnd) |> ignore

                    let mutable msg = MSG()
                    while NativeMethods.GetMessage(&msg, IntPtr.Zero, 0u, 0u) <> 0 do
                        NativeMethods.TranslateMessage(&msg) |> ignore
                        NativeMethods.DispatchMessage(&msg) |> ignore

                    Direct2DApp.cleanup ()
                    int msg.wParam
