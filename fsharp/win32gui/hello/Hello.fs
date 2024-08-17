open System
open System.Runtime.InteropServices
open Microsoft.FSharp.NativeInterop

[<Literal>]
let WS_OVERLAPPEDWINDOW = 0x00CF0000u

[<Literal>]
let CS_VREDRAW = 0x0001u
[<Literal>]
let CS_HREDRAW = 0x0002u

[<Literal>]
let COLOR_WINDOW = 5
[<Literal>]
let IDI_APPLICATION = 32512
[<Literal>]
let IDC_ARROW = 32512

[<Literal>]
let SW_SHOWDEFAULT = 10

[<Literal>]
let WM_DESTROY = 0x0002u
[<Literal>]
let WM_PAINT = 0x000Fu

[<Struct; StructLayout(LayoutKind.Sequential)>]
type POINT =
    val mutable x: int
    val mutable y: int

[<Struct; StructLayout(LayoutKind.Sequential)>]
type MSG =
    val mutable hwnd: nativeint
    val mutable message: uint32
    val mutable wParam: nativeint
    val mutable lParam: nativeint
    val mutable time: uint32
    val mutable pt: POINT

[<Struct; StructLayout(LayoutKind.Sequential)>]
type WNDCLASSEX =
    val mutable cbSize: uint32
    val mutable style: uint32
    val mutable lpfnWndProc: nativeint
    val mutable cbClsExtra: int32
    val mutable cbWndExtra: int32
    val mutable hInstance: nativeint
    val mutable hIcon: nativeint
    val mutable hCursor: nativeint
    val mutable hbrBackground: nativeint
    val mutable lpszMenuName: string
    val mutable lpszClassName: string
    val mutable hIconSm: nativeint

[<Struct; StructLayout(LayoutKind.Sequential)>]
type RECT =
    val mutable left: int32
    val mutable top: int32
    val mutable right: int32
    val mutable bottom: int32

[<Struct; StructLayout(LayoutKind.Sequential)>]
type PAINTSTRUCT =
    val mutable hdc: nativeint
    val mutable fErase: bool
    val mutable rcPaint: RECT
    val mutable fRestore: bool
    val mutable fIncUpdate: bool
    [<MarshalAs(UnmanagedType.ByValArray, SizeConst = 32)>]
    val mutable rgbReserved: byte[]

module NativeMethods =
    [<DllImport("user32.dll")>]
    extern nativeint LoadCursor(nativeint hInstance, int lpCursorName)

    [<DllImport("user32.dll")>]
    extern nativeint LoadIcon(nativeint hInstance, int lpIconName)

    [<DllImport("user32.dll")>]
    extern uint16 RegisterClassEx([<In>] WNDCLASSEX& lpwcx)

    [<DllImport("user32.dll", EntryPoint = "CreateWindowExW", CharSet = CharSet.Unicode)>]
    extern nativeint CreateWindowEx(uint32 dwExStyle, string lpClassName, string lpWindowName, uint32 dwStyle, int x, int y, int nWidth, int nHeight, nativeint hWndParent, nativeint hMenu, nativeint hInstance, nativeint lpParam)

    [<DllImport("user32.dll")>]
    extern bool ShowWindow(nativeint hWnd, int nCmdShow)

    [<DllImport("user32.dll")>]
    extern bool UpdateWindow(nativeint hWnd)

    [<DllImport("user32.dll")>]
    extern bool GetMessage([<Out>] MSG& lpMsg, nativeint hWnd, uint32 wMsgFilterMin, uint32 wMsgFilterMax)

    [<DllImport("user32.dll")>]
    extern bool TranslateMessage([<In>] MSG& lpMsg)

    [<DllImport("user32.dll")>]
    extern nativeint DispatchMessage([<In>] MSG& lpMsg)

    [<DllImport("user32.dll")>]
    extern void PostQuitMessage(int nExitCode)

    [<DllImport("user32.dll")>]
    extern nativeint BeginPaint(nativeint hwnd, PAINTSTRUCT& lpPaint)

    [<DllImport("user32.dll")>]
    extern bool EndPaint(nativeint hWnd, PAINTSTRUCT& lpPaint)

    [<DllImport("gdi32.dll", CharSet = CharSet.Unicode)>]
    extern bool TextOut(nativeint hdc, int x, int y, string lpString, int c)

    [<DllImport("user32.dll")>]
    extern nativeint DefWindowProc(nativeint hWnd, uint32 msg, nativeint wParam, nativeint lParam)

type WndProcDelegate = delegate of nativeint * uint32 * nativeint * nativeint -> nativeint

let mutable wndProcDelegate : WndProcDelegate = null

let WndProc (hWnd: nativeint) (msg: uint32) (wParam: nativeint) (lParam: nativeint) : nativeint =
    match msg with
    | WM_PAINT ->
        let mutable ps = Unchecked.defaultof<PAINTSTRUCT>
        let hdc = NativeMethods.BeginPaint(hWnd, &ps)
        let message = "Hello, Win32 GUI(F#) World!"
        NativeMethods.TextOut(hdc, 0, 0, message, message.Length) |> ignore
        NativeMethods.EndPaint(hWnd, &ps) |> ignore
        nativeint 0
    | WM_DESTROY ->
        NativeMethods.PostQuitMessage(0)
        nativeint 0
    | _ -> NativeMethods.DefWindowProc(hWnd, msg, wParam, lParam)

[<EntryPoint>]
let main argv =
    let className = "helloWindow"
    let windowName = "Hello, World!"

    let hInstance = Marshal.GetHINSTANCE(typeof<MSG>.Module)

    // Create and keep a reference to the delegate
    wndProcDelegate <- new WndProcDelegate(WndProc)

    let mutable wcex = Unchecked.defaultof<WNDCLASSEX>
    wcex.cbSize <- uint32 (Marshal.SizeOf(typeof<WNDCLASSEX>))
    wcex.style <- CS_HREDRAW ||| CS_VREDRAW
    wcex.lpfnWndProc <- Marshal.GetFunctionPointerForDelegate(wndProcDelegate)
    wcex.cbClsExtra <- 0
    wcex.cbWndExtra <- 0
    wcex.hInstance <- hInstance
    wcex.hIcon <- NativeMethods.LoadIcon(hInstance, IDI_APPLICATION)
    wcex.hCursor <- NativeMethods.LoadCursor(nativeint 0, IDC_ARROW)
    wcex.hbrBackground <- nativeint (COLOR_WINDOW + 1)
    wcex.lpszMenuName <- null
    wcex.lpszClassName <- className
    wcex.hIconSm <- NativeMethods.LoadIcon(hInstance, IDI_APPLICATION)

    let result = NativeMethods.RegisterClassEx(&wcex)
    if result = 0us then
        failwith "Failed to register window class"

    let hWnd = NativeMethods.CreateWindowEx(
        0u, className, windowName, WS_OVERLAPPEDWINDOW,
        100, 100, 640, 480, nativeint 0, nativeint 0, hInstance, nativeint 0)

    if hWnd = nativeint 0 then
        failwith "Failed to create window"

    NativeMethods.ShowWindow(hWnd, SW_SHOWDEFAULT) |> ignore
    NativeMethods.UpdateWindow(hWnd) |> ignore

    let mutable msg = Unchecked.defaultof<MSG>
    let mutable bRet = true

    while bRet do
        bRet <- NativeMethods.GetMessage(&msg, nativeint 0, 0u, 0u)
        if bRet then
            NativeMethods.TranslateMessage(&msg) |> ignore
            NativeMethods.DispatchMessage(&msg) |> ignore

    int msg.wParam
