package main

import (
	"syscall"
	"unsafe"
)

var (
	user32           = syscall.NewLazyDLL("user32.dll")
	kernel32         = syscall.NewLazyDLL("kernel32.dll")
	gdi32            = syscall.NewLazyDLL("gdi32.dll")
	msimg32          = syscall.NewLazyDLL("msimg32.dll")
	registerClassEx  = user32.NewProc("RegisterClassExW")
	createWindowEx   = user32.NewProc("CreateWindowExW")
	defWindowProc    = user32.NewProc("DefWindowProcW")
	getModuleHandle  = kernel32.NewProc("GetModuleHandleW")
	getMessage       = user32.NewProc("GetMessageW")
	translateMessage = user32.NewProc("TranslateMessage")
	dispatchMessage  = user32.NewProc("DispatchMessageW")
	beginPaint       = user32.NewProc("BeginPaint")
	endPaint         = user32.NewProc("EndPaint")
	gradientFill     = msimg32.NewProc("GradientFill")
	loadCursor       = user32.NewProc("LoadCursorW")
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
	Hwnd     syscall.Handle
	Message  uint32
	WParam   uintptr
	LParam   uintptr
	Time     uint32
	Pt       POINT
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

type TRIVERTEX struct {
	X     int32
	Y     int32
	Red   uint16
	Green uint16
	Blue  uint16
	Alpha uint16
}

type GRADIENT_TRIANGLE struct {
	Vertex1 uint32
	Vertex2 uint32
	Vertex3 uint32
}

const (
	WS_OVERLAPPEDWINDOW = 0x00000000 | 0x00C00000 | 0x00080000 | 0x00040000 | 0x00020000 | 0x00010000
	WS_VISIBLE           = 0x10000000
	CW_USEDEFAULT        = -2147483648
	WM_PAINT             = 0x000F
	GRADIENT_FILL_TRIANGLE = 0x00000002
)

func WndProc(hWnd syscall.Handle, msg uint32, wParam, lParam uintptr) uintptr {
	switch msg {
	case WM_PAINT:
		var ps PAINTSTRUCT
		hdc, _, _ := beginPaint.Call(uintptr(hWnd), uintptr(unsafe.Pointer(&ps)))

		vertices := []TRIVERTEX{
			{X: 320, Y: 120, Red: 0xffff, Green: 0, Blue: 0, Alpha: 0},
			{X: 480, Y: 360, Red: 0, Green: 0xffff, Blue: 0, Alpha: 0},
			{X: 160, Y: 360, Red: 0, Green: 0, Blue: 0xffff, Alpha: 0},
		}
		gradientTriangle := GRADIENT_TRIANGLE{Vertex1: 0, Vertex2: 1, Vertex3: 2}

		gradientFill.Call(hdc, uintptr(unsafe.Pointer(&vertices[0])), uintptr(len(vertices)), uintptr(unsafe.Pointer(&gradientTriangle)), uintptr(1), uintptr(GRADIENT_FILL_TRIANGLE))

		endPaint.Call(uintptr(hWnd), uintptr(unsafe.Pointer(&ps)))
		return 0
	case 0x0010: // WM_CLOSE
		syscall.Exit(0)
	default:
		r0, _, _ := defWindowProc.Call(uintptr(hWnd), uintptr(msg), wParam, lParam)
		return r0
	}

	return 0
}

func main() {
	appName := syscall.StringToUTF16Ptr("Hello, World!")
	className := syscall.StringToUTF16Ptr("windowClass")
	hInstance, _, _ := getModuleHandle.Call(0)

	var wc WNDCLASSEX
	wc.CbSize = uint32(unsafe.Sizeof(wc))
	wc.Style = 0x0002 | 0x0001 // CS_HREDRAW | CS_VREDRAW
	wc.LpfnWndProc = syscall.NewCallback(WndProc)
	wc.HInstance = syscall.Handle(hInstance)
	hCursor, _, _ := loadCursor.Call(uintptr(0), uintptr(32512))
	wc.HCursor = syscall.Handle(hCursor)
	wc.HbrBackground = syscall.Handle(uintptr(0))
	wc.LpszClassName = className

	_, _, err := registerClassEx.Call(uintptr(unsafe.Pointer(&wc)))
	if err != nil && err != syscall.Errno(0) {
		panic("RegisterClassEx failed: " + err.Error())
	}

	hWnd, _, err := createWindowEx.Call(0, uintptr(unsafe.Pointer(className)), uintptr(unsafe.Pointer(appName)),
		WS_OVERLAPPEDWINDOW|WS_VISIBLE, 100, 100, 640, 480,
		0, 0, hInstance, 0)

	if hWnd == 0 {
		panic("CreateWindowEx failed: " + err.Error())
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
