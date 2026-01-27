package main

import (
    "syscall"
    "unsafe"
)

var (
    user32           = syscall.NewLazyDLL("user32.dll")
    kernel32         = syscall.NewLazyDLL("kernel32.dll")
    gdi32            = syscall.NewLazyDLL("gdi32.dll")
    gdiplus          = syscall.NewLazyDLL("gdiplus.dll")
    registerClassEx  = user32.NewProc("RegisterClassExW")
    createWindowEx   = user32.NewProc("CreateWindowExW")
    defWindowProc    = user32.NewProc("DefWindowProcW")
    getModuleHandle  = kernel32.NewProc("GetModuleHandleW")
    getMessage       = user32.NewProc("GetMessageW")
    translateMessage = user32.NewProc("TranslateMessage")
    dispatchMessage  = user32.NewProc("DispatchMessageW")
    beginPaint       = user32.NewProc("BeginPaint")
    endPaint         = user32.NewProc("EndPaint")
    loadCursor       = user32.NewProc("LoadCursorW")
    getStockObject   = gdi32.NewProc("GetStockObject")

    gdiplusStartup                            = gdiplus.NewProc("GdiplusStartup")
    gdiplusShutdown                           = gdiplus.NewProc("GdiplusShutdown")
    gdipCreateFromHDC                         = gdiplus.NewProc("GdipCreateFromHDC")
    gdipDeleteGraphics                        = gdiplus.NewProc("GdipDeleteGraphics")
    gdipCreatePath                            = gdiplus.NewProc("GdipCreatePath")
    gdipDeletePath                            = gdiplus.NewProc("GdipDeletePath")
    gdipAddPathLine2I                         = gdiplus.NewProc("GdipAddPathLine2I")
    gdipClosePathFigure                       = gdiplus.NewProc("GdipClosePathFigure")
    gdipCreatePathGradientFromPath            = gdiplus.NewProc("GdipCreatePathGradientFromPath")
    gdipDeleteBrush                           = gdiplus.NewProc("GdipDeleteBrush")
    gdipSetPathGradientCenterColor            = gdiplus.NewProc("GdipSetPathGradientCenterColor")
    gdipSetPathGradientSurroundColorsWithCount = gdiplus.NewProc("GdipSetPathGradientSurroundColorsWithCount")
    gdipFillPath                              = gdiplus.NewProc("GdipFillPath")
)

type WNDCLASSEX struct {
    CbSize        uint32
    Style         uint32
    LpfnWndProc   uintptr
    CnClsExtra    int32
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

type PAINTSTRUCT struct {
    Hdc         syscall.Handle
    Erase       int32
    RcPaint     RECT
    Restore     int32
    IncUpdate   int32
    RgbReserved [32]byte
}

type RECT struct {
    Left   int32
    Top    int32
    Right  int32
    Bottom int32
}

type GdiplusStartupInput struct {
    GdiplusVersion           uint32
    DebugEventCallback       uintptr
    SuppressBackgroundThread int32
    SuppressExternalCodecs   int32
}

type GdiplusStartupOutput struct {
    NotificationHook   uintptr
    NotificationUnhook uintptr
}

// GDI+ Point (int32)
type GpPoint struct {
    X int32
    Y int32
}

const (
    WS_OVERLAPPEDWINDOW = 0x00000000 | 0x00C00000 | 0x00080000 | 0x00040000 | 0x00020000 | 0x00010000
    WS_VISIBLE          = 0x10000000
    CW_USEDEFAULT       = -2147483648
    WM_PAINT            = 0x000F
    WM_CLOSE            = 0x0010
    WM_DESTROY          = 0x0002
    BLACK_BRUSH         = 4
    FillModeAlternate   = 0
)

var gdiplusToken uintptr

func ARGB(a, r, g, b uint8) uint32 {
    return uint32(a)<<24 | uint32(r)<<16 | uint32(g)<<8 | uint32(b)
}

func DrawTriangle(hdc uintptr) {
    WIDTH := int32(640)
    HEIGHT := int32(480)

    // Graphicsオブジェクトを作成
    var graphics uintptr
    gdipCreateFromHDC.Call(hdc, uintptr(unsafe.Pointer(&graphics)))
    defer gdipDeleteGraphics.Call(graphics)

    // 三角形の頂点を定義
    points := []GpPoint{
        {X: WIDTH * 1 / 2, Y: HEIGHT * 1 / 4},
        {X: WIDTH * 3 / 4, Y: HEIGHT * 3 / 4},
        {X: WIDTH * 1 / 4, Y: HEIGHT * 3 / 4},
    }

    // GraphicsPathを作成
    var path uintptr
    gdipCreatePath.Call(uintptr(FillModeAlternate), uintptr(unsafe.Pointer(&path)))
    defer gdipDeletePath.Call(path)

    // パスに線を追加
    gdipAddPathLine2I.Call(path, uintptr(unsafe.Pointer(&points[0])), uintptr(len(points)))
    gdipClosePathFigure.Call(path)

    // PathGradientBrushを作成
    var brush uintptr
    gdipCreatePathGradientFromPath.Call(path, uintptr(unsafe.Pointer(&brush)))
    defer gdipDeleteBrush.Call(brush)

    // 中心色を設定 (RGB各85 = 255/3)
    centerColor := ARGB(255, 85, 85, 85)
    gdipSetPathGradientCenterColor.Call(brush, uintptr(centerColor))

    // 周囲の色を設定 (赤、緑、青)
    surroundColors := []uint32{
        ARGB(255, 255, 0, 0),   // 赤
        ARGB(255, 0, 255, 0),   // 緑
        ARGB(255, 0, 0, 255),   // 青
    }
    count := int32(3)
    gdipSetPathGradientSurroundColorsWithCount.Call(
        brush,
        uintptr(unsafe.Pointer(&surroundColors[0])),
        uintptr(unsafe.Pointer(&count)),
    )

    // パスを塗りつぶし
    gdipFillPath.Call(graphics, brush, path)
}

func WndProc(hWnd syscall.Handle, msg uint32, wParam, lParam uintptr) uintptr {
    switch msg {
    case WM_PAINT:
        var ps PAINTSTRUCT
        hdc, _, _ := beginPaint.Call(uintptr(hWnd), uintptr(unsafe.Pointer(&ps)))
        DrawTriangle(hdc)
        endPaint.Call(uintptr(hWnd), uintptr(unsafe.Pointer(&ps)))
        return 0

    case WM_CLOSE:
        syscall.Exit(0)

    case WM_DESTROY:
        return 0

    default:
        r0, _, _ := defWindowProc.Call(uintptr(hWnd), uintptr(msg), wParam, lParam)
        return r0
    }

    return 0
}

func main() {
    // GDI+の初期化
    var input GdiplusStartupInput
    input.GdiplusVersion = 1
    var output GdiplusStartupOutput
    gdiplusStartup.Call(
        uintptr(unsafe.Pointer(&gdiplusToken)),
        uintptr(unsafe.Pointer(&input)),
        uintptr(unsafe.Pointer(&output)),
    )
    defer gdiplusShutdown.Call(gdiplusToken)

    appName := syscall.StringToUTF16Ptr("Hello, World!")
    className := syscall.StringToUTF16Ptr("WindowClass")
    hInstance, _, _ := getModuleHandle.Call(0)

    var wc WNDCLASSEX
    wc.CbSize = uint32(unsafe.Sizeof(wc))
    wc.Style = 0x0020 // CS_OWNDC
    wc.LpfnWndProc = syscall.NewCallback(WndProc)
    wc.HInstance = syscall.Handle(hInstance)
    hCursor, _, _ := loadCursor.Call(uintptr(0), uintptr(32512))
    wc.HCursor = syscall.Handle(hCursor)
    hBrush, _, _ := getStockObject.Call(BLACK_BRUSH)
    wc.HbrBackground = syscall.Handle(hBrush)
    wc.LpszClassName = className

    registerClassEx.Call(uintptr(unsafe.Pointer(&wc)))

    hWnd, _, _ := createWindowEx.Call(
        0,
        uintptr(unsafe.Pointer(className)),
        uintptr(unsafe.Pointer(appName)),
        WS_OVERLAPPEDWINDOW|WS_VISIBLE,
        100, 100, 640, 480,
        0, 0, hInstance, 0,
    )

    if hWnd == 0 {
        panic("CreateWindowEx failed")
    }

    var msg MSG
    for {
        ret, _, _ := getMessage.Call(uintptr(unsafe.Pointer(&msg)), 0, 0, 0)
        if ret == 0 {
            break
        }
        translateMessage.Call(uintptr(unsafe.Pointer(&msg)))
        dispatchMessage.Call(uintptr(unsafe.Pointer(&msg)))
    }
}
