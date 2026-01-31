package main

import (
    "runtime"
    "syscall"
    "unsafe"
)

// Constants
const (
    CW_USEDEFAULT         int32 = -2147483648
    WS_OVERLAPPEDWINDOW         = 0x00CF0000
    WM_DESTROY                  = 0x0002
    WM_QUIT                     = 0x0012
    PM_REMOVE                   = 0x0001
    CS_HREDRAW                  = 0x0002
    CS_VREDRAW                  = 0x0001
    IDC_ARROW                   = 32512
    COLOR_WINDOW                = 5
    SW_SHOWDEFAULT              = 10

    // DirectX 9 constants
    D3D_SDK_VERSION                     = 32
    D3DADAPTER_DEFAULT                  = 0
    D3DDEVTYPE_HAL                      = 1
    D3DCREATE_SOFTWARE_VERTEXPROCESSING = 0x00000020
    D3DFMT_UNKNOWN                      = 0
    D3DSWAPEFFECT_DISCARD               = 1
    D3DMULTISAMPLE_NONE                 = 0
    D3DPOOL_DEFAULT                     = 0
    D3DCLEAR_TARGET                     = 0x00000001
    D3DPT_TRIANGLELIST                  = 4

    // FVF flags
    D3DFVF_XYZRHW  = 0x004
    D3DFVF_DIFFUSE = 0x040
)

var D3DFVF_VERTEX = D3DFVF_XYZRHW | D3DFVF_DIFFUSE

// Windows structures
type POINT struct {
    X, Y int32
}

type MSG struct {
    Hwnd    syscall.Handle
    Message uint32
    _       uint32
    WParam  uintptr
    LParam  uintptr
    Time    uint32
    Pt      POINT
}

type WNDCLASSEXW struct {
    Size       uint32
    Style      uint32
    WndProc    uintptr
    ClsExtra   int32
    WndExtra   int32
    Instance   syscall.Handle
    Icon       syscall.Handle
    Cursor     syscall.Handle
    Background syscall.Handle
    MenuName   *uint16
    ClassName  *uint16
    IconSm     syscall.Handle
}

type RECT struct {
    Left, Top, Right, Bottom int32
}

// DirectX 9 structures
type D3DPRESENT_PARAMETERS struct {
    BackBufferWidth            uint32
    BackBufferHeight           uint32
    BackBufferFormat           uint32
    BackBufferCount            uint32
    MultiSampleType            uint32
    MultiSampleQuality         uint32
    SwapEffect                 uint32
    HDeviceWindow              syscall.Handle
    Windowed                   int32
    EnableAutoDepthStencil     int32
    AutoDepthStencilFormat     uint32
    Flags                      uint32
    FullScreen_RefreshRateInHz uint32
    PresentationInterval       uint32
}

// Vertex structure (transformed with color)
type VERTEX struct {
    X, Y, Z, RHW float32
    Color        uint32
}

// COM interface pointers
var (
    g_hWnd       syscall.Handle
    g_pD3D       uintptr
    g_pd3dDevice uintptr
    g_pVB        uintptr
)

// DLLs
var (
    user32   = syscall.NewLazyDLL("user32.dll")
    kernel32 = syscall.NewLazyDLL("kernel32.dll")
    d3d9     = syscall.NewLazyDLL("d3d9.dll")

    procRegisterClassExW = user32.NewProc("RegisterClassExW")
    procCreateWindowExW  = user32.NewProc("CreateWindowExW")
    procShowWindow       = user32.NewProc("ShowWindow")
    procUpdateWindow     = user32.NewProc("UpdateWindow")
    procPeekMessageW     = user32.NewProc("PeekMessageW")
    procTranslateMessage = user32.NewProc("TranslateMessage")
    procDispatchMessageW = user32.NewProc("DispatchMessageW")
    procDefWindowProcW   = user32.NewProc("DefWindowProcW")
    procPostQuitMessage  = user32.NewProc("PostQuitMessage")
    procLoadCursorW      = user32.NewProc("LoadCursorW")

    procGetModuleHandleW = kernel32.NewProc("GetModuleHandleW")

    procDirect3DCreate9 = d3d9.NewProc("Direct3DCreate9")
)

// D3DCOLOR_XRGB macro replacement
func D3DCOLOR_XRGB(r, g, b uint8) uint32 {
    return 0xFF000000 | (uint32(r) << 16) | (uint32(g) << 8) | uint32(b)
}

func main() {
    runtime.LockOSThread()

    instance := getModuleHandle()

    if !initWindow(instance) {
        return
    }

    if !initD3D() {
        cleanup()
        return
    }

    if !initVB() {
        cleanup()
        return
    }

    // Message loop
    msg := MSG{}
    for msg.Message != WM_QUIT {
        if peekMessage(&msg, 0, 0, 0, PM_REMOVE) {
            translateMessage(&msg)
            dispatchMessage(&msg)
        } else {
            render()
        }
    }

    cleanup()
}

func wndProc(hwnd syscall.Handle, msg uint32, wParam, lParam uintptr) uintptr {
    switch msg {
    case WM_DESTROY:
        postQuitMessage(0)
        return 0
    default:
        return defWindowProc(hwnd, msg, wParam, lParam)
    }
}

func initWindow(instance syscall.Handle) bool {
    className := syscall.StringToUTF16Ptr("D3D9WindowClass")

    wcex := WNDCLASSEXW{
        Style:      CS_HREDRAW | CS_VREDRAW,
        WndProc:    syscall.NewCallback(wndProc),
        Instance:   instance,
        Cursor:     loadCursor(0, IDC_ARROW),
        Background: syscall.Handle(COLOR_WINDOW + 1),
        ClassName:  className,
    }
    wcex.Size = uint32(unsafe.Sizeof(wcex))

    if !registerClassEx(&wcex) {
        return false
    }

    g_hWnd = createWindowEx(
        0,
        className,
        syscall.StringToUTF16Ptr("Hello, World!"),
        WS_OVERLAPPEDWINDOW,
        CW_USEDEFAULT,
        CW_USEDEFAULT,
        640,
        480,
        0,
        0,
        instance,
        0,
    )

    if g_hWnd == 0 {
        return false
    }

    showWindow(g_hWnd, SW_SHOWDEFAULT)
    updateWindow(g_hWnd)
    return true
}

func initD3D() bool {
    // Create Direct3D9 object
    ret, _, _ := procDirect3DCreate9.Call(D3D_SDK_VERSION)
    if ret == 0 {
        return false
    }
    g_pD3D = ret

    // Set up present parameters
    d3dpp := D3DPRESENT_PARAMETERS{
        Windowed:         1,
        SwapEffect:       D3DSWAPEFFECT_DISCARD,
        BackBufferFormat: D3DFMT_UNKNOWN,
        HDeviceWindow:    g_hWnd,
    }

    // Create device
    // IDirect3D9::CreateDevice is at vtable index 16
    hr := comCall(g_pD3D, 16,
        D3DADAPTER_DEFAULT,
        D3DDEVTYPE_HAL,
        uintptr(g_hWnd),
        D3DCREATE_SOFTWARE_VERTEXPROCESSING,
        uintptr(unsafe.Pointer(&d3dpp)),
        uintptr(unsafe.Pointer(&g_pd3dDevice)),
    )

    if hr != 0 {
        return false
    }

    return true
}

func initVB() bool {
    // Triangle vertices with RGB colors
    vertices := []VERTEX{
        {320.0, 100.0, 0.0, 1.0, D3DCOLOR_XRGB(255, 0, 0)},   // Top (Red)
        {520.0, 380.0, 0.0, 1.0, D3DCOLOR_XRGB(0, 255, 0)},   // Right (Green)
        {120.0, 380.0, 0.0, 1.0, D3DCOLOR_XRGB(0, 0, 255)},   // Left (Blue)
    }

    vertexSize := uint32(unsafe.Sizeof(VERTEX{}))

    // IDirect3DDevice9::CreateVertexBuffer is at vtable index 26
    hr := comCall(g_pd3dDevice, 26,
        uintptr(3*vertexSize),       // Length
        uintptr(0),                  // Usage
        uintptr(D3DFVF_VERTEX),      // FVF
        uintptr(D3DPOOL_DEFAULT),    // Pool
        uintptr(unsafe.Pointer(&g_pVB)),
        uintptr(0),                  // pSharedHandle
    )

    if hr != 0 {
        return false
    }

    // Lock vertex buffer
    var pVertices uintptr
    // IDirect3DVertexBuffer9::Lock is at vtable index 11
    hr = comCall(g_pVB, 11,
        uintptr(0),
        uintptr(3*vertexSize),
        uintptr(unsafe.Pointer(&pVertices)),
        uintptr(0),
    )

    if hr != 0 {
        return false
    }

    // Copy vertex data
    for i, v := range vertices {
        dst := (*VERTEX)(unsafe.Pointer(pVertices + uintptr(i)*uintptr(vertexSize)))
        *dst = v
    }

    // Unlock vertex buffer
    // IDirect3DVertexBuffer9::Unlock is at vtable index 12
    comCall(g_pVB, 12)

    return true
}

func cleanup() {
    if g_pVB != 0 {
        comRelease(g_pVB)
        g_pVB = 0
    }
    if g_pd3dDevice != 0 {
        comRelease(g_pd3dDevice)
        g_pd3dDevice = 0
    }
    if g_pD3D != 0 {
        comRelease(g_pD3D)
        g_pD3D = 0
    }
}

func render() {
    if g_pd3dDevice == 0 {
        return
    }

    // Clear the backbuffer to white
    // IDirect3DDevice9::Clear is at vtable index 43
    comCall(g_pd3dDevice, 43,
        uintptr(0),
        uintptr(0),
        uintptr(D3DCLEAR_TARGET),
        uintptr(D3DCOLOR_XRGB(255, 255, 255)),
        uintptr(0), // Z (as uint64 bits for float 1.0)
        uintptr(0),
    )

    // Begin scene
    // IDirect3DDevice9::BeginScene is at vtable index 41
    hr := comCall(g_pd3dDevice, 41)
    if hr == 0 {
        // Set stream source
        // IDirect3DDevice9::SetStreamSource is at vtable index 100
        vertexSize := uint32(unsafe.Sizeof(VERTEX{}))
        comCall(g_pd3dDevice, 100,
            uintptr(0),
            g_pVB,
            uintptr(0),
            uintptr(vertexSize),
        )

        // Set FVF
        // IDirect3DDevice9::SetFVF is at vtable index 89
        comCall(g_pd3dDevice, 89, uintptr(D3DFVF_VERTEX))

        // Draw primitive
        // IDirect3DDevice9::DrawPrimitive is at vtable index 81
        comCall(g_pd3dDevice, 81,
            uintptr(D3DPT_TRIANGLELIST),
            uintptr(0),
            uintptr(1),
        )

        // End scene
        // IDirect3DDevice9::EndScene is at vtable index 42
        comCall(g_pd3dDevice, 42)
    }

    // Present
    // IDirect3DDevice9::Present is at vtable index 17
    comCall(g_pd3dDevice, 17,
        uintptr(0),
        uintptr(0),
        uintptr(0),
        uintptr(0),
    )
}

// COM helper functions
func comCall(obj uintptr, methodIndex int, args ...uintptr) uintptr {
    if obj == 0 {
        return 0
    }
    vtable := *(*uintptr)(unsafe.Pointer(obj))
    method := *(*uintptr)(unsafe.Pointer(vtable + uintptr(methodIndex)*unsafe.Sizeof(uintptr(0))))

    // Build argument list with 'this' pointer first
    allArgs := make([]uintptr, 1+len(args))
    allArgs[0] = obj
    copy(allArgs[1:], args)

    ret, _, _ := syscall.SyscallN(method, allArgs...)
    return ret
}

func comRelease(obj uintptr) {
    if obj != 0 {
        comCall(obj, 2) // Release is always at index 2
    }
}

// Windows API wrappers
func getModuleHandle() syscall.Handle {
    ret, _, _ := procGetModuleHandleW.Call(0)
    return syscall.Handle(ret)
}

func registerClassEx(wcex *WNDCLASSEXW) bool {
    ret, _, _ := procRegisterClassExW.Call(uintptr(unsafe.Pointer(wcex)))
    return ret != 0
}

func createWindowEx(exStyle uint32, className, windowName *uint16, style uint32, x, y, width, height int32, parent, menu, instance syscall.Handle, param uintptr) syscall.Handle {
    ret, _, _ := procCreateWindowExW.Call(
        uintptr(exStyle),
        uintptr(unsafe.Pointer(className)),
        uintptr(unsafe.Pointer(windowName)),
        uintptr(style),
        uintptr(x), uintptr(y),
        uintptr(width), uintptr(height),
        uintptr(parent), uintptr(menu),
        uintptr(instance), param,
    )
    return syscall.Handle(ret)
}

func showWindow(hwnd syscall.Handle, nCmdShow int32) {
    procShowWindow.Call(uintptr(hwnd), uintptr(nCmdShow))
}

func updateWindow(hwnd syscall.Handle) {
    procUpdateWindow.Call(uintptr(hwnd))
}

func peekMessage(msg *MSG, hwnd syscall.Handle, msgFilterMin, msgFilterMax, removeMsg uint32) bool {
    ret, _, _ := procPeekMessageW.Call(
        uintptr(unsafe.Pointer(msg)),
        uintptr(hwnd),
        uintptr(msgFilterMin), uintptr(msgFilterMax),
        uintptr(removeMsg),
    )
    return ret != 0
}

func translateMessage(msg *MSG) {
    procTranslateMessage.Call(uintptr(unsafe.Pointer(msg)))
}

func dispatchMessage(msg *MSG) {
    procDispatchMessageW.Call(uintptr(unsafe.Pointer(msg)))
}

func defWindowProc(hwnd syscall.Handle, msg uint32, wParam, lParam uintptr) uintptr {
    ret, _, _ := procDefWindowProcW.Call(uintptr(hwnd), uintptr(msg), wParam, lParam)
    return ret
}

func postQuitMessage(exitCode int32) {
    procPostQuitMessage.Call(uintptr(exitCode))
}

func loadCursor(hInstance syscall.Handle, cursorName uint32) syscall.Handle {
    ret, _, _ := procLoadCursorW.Call(uintptr(hInstance), uintptr(cursorName))
    return syscall.Handle(ret)
}
