//go:build windows
// +build windows

package main

import (
    "syscall"
    "unsafe"
)

var (
    user32   = syscall.NewLazyDLL("user32.dll")
    kernel32 = syscall.NewLazyDLL("kernel32.dll")
    d2d1     = syscall.NewLazyDLL("d2d1.dll")

    registerClassExW = user32.NewProc("RegisterClassExW")
    createWindowExW  = user32.NewProc("CreateWindowExW")
    defWindowProcW   = user32.NewProc("DefWindowProcW")
    getMessageW      = user32.NewProc("GetMessageW")
    translateMessage = user32.NewProc("TranslateMessage")
    dispatchMessageW = user32.NewProc("DispatchMessageW")
    loadCursorW      = user32.NewProc("LoadCursorW")
    postQuitMessage  = user32.NewProc("PostQuitMessage")
    showWindow       = user32.NewProc("ShowWindow")
    updateWindow     = user32.NewProc("UpdateWindow")
    getClientRect    = user32.NewProc("GetClientRect")
    validateRect     = user32.NewProc("ValidateRect")

    getModuleHandleW = kernel32.NewProc("GetModuleHandleW")

    d2d1CreateFactory = d2d1.NewProc("D2D1CreateFactory")
)

// ===== Win32 types =====

type GUID struct {
    Data1 uint32
    Data2 uint16
    Data3 uint16
    Data4 [8]byte
}

type WNDCLASSEX struct {
    CbSize        uint32
    Style         uint32
    LpfnWndProc   uintptr
    CbClsExtra    int32
    CbWndExtra    int32
    HInstance     syscall.Handle
    HIcon         syscall.Handle
    HCursor       syscall.Handle
    HbrBackground syscall.Handle
    LpszMenuName  *uint16
    LpszClassName *uint16
    HIconSm       syscall.Handle
}

type MSG struct {
    Hwnd    syscall.Handle
    Message uint32
    WParam  uintptr
    LParam  uintptr
    Time    uint32
    Pt      POINT
}

type POINT struct {
    X int32
    Y int32
}

type RECT struct {
    Left, Top, Right, Bottom int32
}

// ===== Direct2D types =====

type D2D1_COLOR_F struct {
    R, G, B, A float32
}

type D2D1_POINT_2F struct {
    X, Y float32
}

type D2D1_SIZE_U struct {
    Width, Height uint32
}

type D2D1_PIXEL_FORMAT struct {
    Format    uint32
    AlphaMode uint32
}

type D2D1_RENDER_TARGET_PROPERTIES struct {
    Type        uint32
    PixelFormat D2D1_PIXEL_FORMAT
    DpiX        float32
    DpiY        float32
    Usage       uint32
    MinLevel    uint32
}

type D2D1_HWND_RENDER_TARGET_PROPERTIES struct {
    Hwnd           syscall.Handle
    PixelSize      D2D1_SIZE_U
    PresentOptions uint32
}

// ===== Constants =====

const (
    WS_OVERLAPPEDWINDOW = 0x00CF0000
    WS_VISIBLE          = 0x10000000
    CS_HREDRAW          = 0x0002
    CS_VREDRAW          = 0x0001
    CW_USEDEFAULT       = 0x80000000

    WM_PAINT   = 0x000F
    WM_SIZE    = 0x0005
    WM_DESTROY = 0x0002

    SW_SHOWDEFAULT = 10
    COLOR_WINDOW   = 5
    IDC_ARROW      = 32512
)

// ===== VTable indices (from vtable.txt) =====

const (
    // IUnknown
    IUnknown_Release = 2

    // ID2D1Factory
    ID2D1Factory_CreateHwndRenderTarget = 14

    // ID2D1RenderTarget
    ID2D1RenderTarget_CreateSolidColorBrush = 8
    ID2D1RenderTarget_DrawLine              = 15
    ID2D1RenderTarget_Clear                 = 47
    ID2D1RenderTarget_BeginDraw             = 48
    ID2D1RenderTarget_EndDraw               = 49

    // ID2D1HwndRenderTarget
    ID2D1HwndRenderTarget_Resize = 58
)

// ===== COM IIDs =====

var IID_ID2D1Factory = GUID{0x06152247, 0x6f50, 0x465a, [8]byte{0x92, 0x45, 0x11, 0x8b, 0xfd, 0x3b, 0x60, 0x07}}

// ===== Globals =====

var (
    g_factory      uintptr
    g_renderTarget uintptr
    g_brush        uintptr
)

// ===== COM helper =====

func comCall(obj uintptr, methodIndex int, args ...uintptr) uintptr {
    if obj == 0 {
        return 0
    }
    vtable := *(*uintptr)(unsafe.Pointer(obj))
    method := *(*uintptr)(unsafe.Pointer(vtable + uintptr(methodIndex)*unsafe.Sizeof(uintptr(0))))

    allArgs := make([]uintptr, 1+len(args))
    allArgs[0] = obj
    copy(allArgs[1:], args)

    ret, _, _ := syscall.SyscallN(method, allArgs...)
    return ret
}

func comRelease(obj uintptr) {
    if obj != 0 {
        comCall(obj, IUnknown_Release)
    }
}

// ===== Direct2D initialization =====

func initDirect2D(hWnd syscall.Handle) bool {
    // Create factory
    var factory uintptr
    hr, _, _ := d2d1CreateFactory.Call(
        0, // D2D1_FACTORY_TYPE_SINGLE_THREADED
        uintptr(unsafe.Pointer(&IID_ID2D1Factory)),
        0,
        uintptr(unsafe.Pointer(&factory)),
    )
    if hr != 0 {
        return false
    }
    g_factory = factory

    // Get client rect
    var rect RECT
    getClientRect.Call(uintptr(hWnd), uintptr(unsafe.Pointer(&rect)))
    width := uint32(rect.Right - rect.Left)
    height := uint32(rect.Bottom - rect.Top)

    // Create HwndRenderTarget
    rtProps := D2D1_RENDER_TARGET_PROPERTIES{}
    hwndProps := D2D1_HWND_RENDER_TARGET_PROPERTIES{
        Hwnd:           hWnd,
        PixelSize:      D2D1_SIZE_U{Width: width, Height: height},
        PresentOptions: 0,
    }

    var renderTarget uintptr
    hr = comCall(g_factory, ID2D1Factory_CreateHwndRenderTarget,
        uintptr(unsafe.Pointer(&rtProps)),
        uintptr(unsafe.Pointer(&hwndProps)),
        uintptr(unsafe.Pointer(&renderTarget)),
    )
    if hr != 0 {
        return false
    }
    g_renderTarget = renderTarget

    // Create SolidColorBrush (blue)
    blue := D2D1_COLOR_F{R: 0, G: 0, B: 1, A: 1}
    var brush uintptr
    hr = comCall(g_renderTarget, ID2D1RenderTarget_CreateSolidColorBrush,
        uintptr(unsafe.Pointer(&blue)),
        0,
        uintptr(unsafe.Pointer(&brush)),
    )
    if hr != 0 {
        return false
    }
    g_brush = brush

    return true
}

// ===== Drawing =====

func draw() {
    if g_renderTarget == 0 || g_brush == 0 {
        return
    }

    // BeginDraw
    comCall(g_renderTarget, ID2D1RenderTarget_BeginDraw)

    // Clear (white)
    white := D2D1_COLOR_F{R: 1, G: 1, B: 1, A: 1}
    comCall(g_renderTarget, ID2D1RenderTarget_Clear, uintptr(unsafe.Pointer(&white)))

    // DrawLine - triangle vertices
    p1 := D2D1_POINT_2F{X: 320, Y: 120}
    p2 := D2D1_POINT_2F{X: 480, Y: 360}
    p3 := D2D1_POINT_2F{X: 160, Y: 360}

    // D2D1_POINT_2F is 8 bytes, passed by value (fits in uintptr on x64)
    // DrawLine(p0, p1, brush, strokeWidth, strokeStyle)
    strokeWidth := float32(2.0)

    comCall(g_renderTarget, ID2D1RenderTarget_DrawLine,
        *(*uintptr)(unsafe.Pointer(&p1)),
        *(*uintptr)(unsafe.Pointer(&p2)),
        g_brush,
        uintptr(*(*uint32)(unsafe.Pointer(&strokeWidth))),
        0,
    )

    comCall(g_renderTarget, ID2D1RenderTarget_DrawLine,
        *(*uintptr)(unsafe.Pointer(&p2)),
        *(*uintptr)(unsafe.Pointer(&p3)),
        g_brush,
        uintptr(*(*uint32)(unsafe.Pointer(&strokeWidth))),
        0,
    )

    comCall(g_renderTarget, ID2D1RenderTarget_DrawLine,
        *(*uintptr)(unsafe.Pointer(&p3)),
        *(*uintptr)(unsafe.Pointer(&p1)),
        g_brush,
        uintptr(*(*uint32)(unsafe.Pointer(&strokeWidth))),
        0,
    )

    // EndDraw
    comCall(g_renderTarget, ID2D1RenderTarget_EndDraw, 0, 0)
}

// ===== Window procedure =====

func WndProc(hWnd syscall.Handle, msg uint32, wParam, lParam uintptr) uintptr {
    switch msg {
    case WM_PAINT:
        if g_renderTarget != 0 {
            draw()
        }
        validateRect.Call(uintptr(hWnd), 0)
        return 0

    case WM_SIZE:
        if g_renderTarget != 0 {
            width := uint32(lParam & 0xFFFF)
            height := uint32((lParam >> 16) & 0xFFFF)
            size := D2D1_SIZE_U{Width: width, Height: height}
            comCall(g_renderTarget, ID2D1HwndRenderTarget_Resize, uintptr(unsafe.Pointer(&size)))
        }
        return 0

    case WM_DESTROY:
        postQuitMessage.Call(0)
        return 0

    default:
        r, _, _ := defWindowProcW.Call(uintptr(hWnd), uintptr(msg), wParam, lParam)
        return r
    }
}

// ===== Cleanup =====

func cleanup() {
    if g_brush != 0 {
        comRelease(g_brush)
        g_brush = 0
    }
    if g_renderTarget != 0 {
        comRelease(g_renderTarget)
        g_renderTarget = 0
    }
    if g_factory != 0 {
        comRelease(g_factory)
        g_factory = 0
    }
}

// ===== Main =====

func main() {
    className := syscall.StringToUTF16Ptr("HelloD2DClass")
    windowName := syscall.StringToUTF16Ptr("Hello, Direct2D(Go) World!")

    hInstance, _, _ := getModuleHandleW.Call(0)
    hCursor, _, _ := loadCursorW.Call(0, IDC_ARROW)

    var wc WNDCLASSEX
    wc.CbSize = uint32(unsafe.Sizeof(wc))
    wc.Style = CS_HREDRAW | CS_VREDRAW
    wc.LpfnWndProc = syscall.NewCallback(WndProc)
    wc.HInstance = syscall.Handle(hInstance)
    wc.HCursor = syscall.Handle(hCursor)
    wc.HbrBackground = syscall.Handle(COLOR_WINDOW + 1)
    wc.LpszClassName = className

    ret, _, _ := registerClassExW.Call(uintptr(unsafe.Pointer(&wc)))
    if ret == 0 {
        return
    }

    hWnd, _, _ := createWindowExW.Call(
        0,
        uintptr(unsafe.Pointer(className)),
        uintptr(unsafe.Pointer(windowName)),
        WS_OVERLAPPEDWINDOW,
        uintptr(CW_USEDEFAULT), uintptr(CW_USEDEFAULT), 640, 480,
        0, 0, hInstance, 0,
    )
    if hWnd == 0 {
        return
    }

    if !initDirect2D(syscall.Handle(hWnd)) {
        cleanup()
        return
    }

    showWindow.Call(hWnd, SW_SHOWDEFAULT)
    updateWindow.Call(hWnd)

    var msg MSG
    for {
        r, _, _ := getMessageW.Call(uintptr(unsafe.Pointer(&msg)), 0, 0, 0)
        if r == 0 || int32(r) == -1 {
            break
        }
        translateMessage.Call(uintptr(unsafe.Pointer(&msg)))
        dispatchMessageW.Call(uintptr(unsafe.Pointer(&msg)))
    }

    cleanup()
}
