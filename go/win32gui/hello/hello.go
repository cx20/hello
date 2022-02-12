package main

import (
	"syscall"
	"unsafe"
)

const className = "helloClass"

const (
	SW_USE_DEFAULT      = 0x80000000
	WS_VISIBLE          = 0x10000000
	WS_OVERLAPPEDWINDOW = 0x00CF0000

	WM_DESTROY = 0x0002
	WM_CLOSE   = 0x0010
	WM_PAINT   = 0x000F

	IDC_ARROW    = 32512
	COLOR_WINDOW = 5
)

type POINT struct {
	x, y int32
}

type MSG struct {
	hwnd    syscall.Handle
	message uint32
	wParam  uintptr
	lParam  uintptr
	time    uint32
	pt      POINT
}

type RECT struct {
	Left   int32
	Top    int32
	Right  int32
	Bottom int32
}

type PAINTSTRUCT struct {
	hdc         syscall.Handle
	fErace      uint32
	rcPaint     RECT
	fRestore    uint32
	fIncUpdate  uint32
	rgbReserved byte
}

type WNDCLASSEXW struct {
	size       uint32
	style      uint32
	wndProc    uintptr
	clsExtra   int32
	wndExtra   int32
	instance   syscall.Handle
	icon       syscall.Handle
	cursor     syscall.Handle
	background syscall.Handle
	menuName   *uint16
	className  *uint16
	iconSm     syscall.Handle
}

func main() {
	instance := getModuleHandle()

	cursor := loadCursorResource(IDC_ARROW)

	wcx := WNDCLASSEXW{
		wndProc:    syscall.NewCallback(wndProc),
		instance:   instance,
		cursor:     cursor,
		background: COLOR_WINDOW + 1,
		className:  syscall.StringToUTF16Ptr(className),
	}
	wcx.size = uint32(unsafe.Sizeof(wcx))

	registerClassEx(&wcx);

	_ = createWindow(
		className,
		"Hello, World!",
		WS_VISIBLE|WS_OVERLAPPEDWINDOW,
		SW_USE_DEFAULT,
		SW_USE_DEFAULT,
		640,
		480,
		0,
		0,
		instance,
	)

	for {
		msg := MSG{}
		gotMessage := getMessage(&msg, 0, 0, 0)
		if gotMessage {
			translateMessage(&msg)
			dispatchMessage(&msg)
		} else {
			break
		}
	}
}

func wndProc(hwnd syscall.Handle, msg uint32, wparam, lparam uintptr) (uintptr) {
	switch msg {
	case WM_CLOSE:
		destroyWindow(hwnd)
	case WM_DESTROY:
		postQuitMessage(0)
	case WM_PAINT:
		var ps PAINTSTRUCT
		hdc := beginPaint(hwnd, &ps)
		textOut(hdc, "Hello, Win32 GUI(Go) World!")
		endPaint(hdc, &ps)
		return 0
	default:
		ret := defWindowProc(hwnd, msg, wparam, lparam)
		return ret
	}
	return 0
}

var (
	user32           = syscall.NewLazyDLL("user32.dll")
	CreateWindowExW  = user32.NewProc("CreateWindowExW")
	DefWindowProcW   = user32.NewProc("DefWindowProcW")
	DestroyWindow    = user32.NewProc("DestroyWindow")
	DispatchMessageW = user32.NewProc("DispatchMessageW")
	GetMessageW      = user32.NewProc("GetMessageW")
	LoadCursorW      = user32.NewProc("LoadCursorW")
	PostQuitMessage  = user32.NewProc("PostQuitMessage")
	RegisterClassExW = user32.NewProc("RegisterClassExW")
	TranslateMessage = user32.NewProc("TranslateMessage")
	BeginPaint       = user32.NewProc("BeginPaint")
	EndPaint         = user32.NewProc("EndPaint")
)

func createWindow(className, windowName string, style uint32, x, y, width, height uint32, parent, menu, instance syscall.Handle) (syscall.Handle) {
	ret, _, _ := CreateWindowExW.Call(
		uintptr(0),
		uintptr(unsafe.Pointer(syscall.StringToUTF16Ptr(className))),
		uintptr(unsafe.Pointer(syscall.StringToUTF16Ptr(windowName))),
		uintptr(style),
		uintptr(x),
		uintptr(y),
		uintptr(width),
		uintptr(height),
		uintptr(parent),
		uintptr(menu),
		uintptr(instance),
		uintptr(0),
	)
	return syscall.Handle(ret)
}

func defWindowProc(hwnd syscall.Handle, msg uint32, wparam, lparam uintptr) (uintptr) {
	ret, _, _ := DefWindowProcW.Call(
		uintptr(hwnd),
		uintptr(msg),
		uintptr(wparam),
		uintptr(lparam),
	)
	return uintptr(ret)
}

func destroyWindow(hwnd syscall.Handle)  {
	DestroyWindow.Call(uintptr(hwnd))
}

func beginPaint(hwnd syscall.Handle, p *PAINTSTRUCT) (syscall.Handle) {

	ret, _, _ := BeginPaint.Call(
		uintptr(hwnd),
		uintptr(unsafe.Pointer(p)),
	)
	return syscall.Handle(ret)
}

func endPaint(hwnd syscall.Handle, p *PAINTSTRUCT) (syscall.Handle) {

	ret, _, _ := EndPaint.Call(
		uintptr(hwnd),
		uintptr(unsafe.Pointer(p)),
	)
	return syscall.Handle(ret)
}

func registerClassEx(wcx *WNDCLASSEXW) {
	RegisterClassExW.Call(
		uintptr(unsafe.Pointer(wcx)),
	)
}

func translateMessage(msg *MSG) {
	TranslateMessage.Call(uintptr(unsafe.Pointer(msg)))
}

func dispatchMessage(msg *MSG) {
	DispatchMessageW.Call(uintptr(unsafe.Pointer(msg)))
}

func loadCursorResource(cursorName uint32) (syscall.Handle) {
	ret, _, _ := LoadCursorW.Call(
		uintptr(0),
		uintptr(uint16(cursorName)),
	)
	return syscall.Handle(ret)
}

func postQuitMessage(exitCode int32) {
	PostQuitMessage.Call(uintptr(exitCode))
}

func getMessage(msg *MSG, hwnd syscall.Handle, msgFilterMin, msgFilterMax uint32) (bool) {
	ret, _, _ := GetMessageW.Call(
		uintptr(unsafe.Pointer(msg)),
		uintptr(hwnd),
		uintptr(msgFilterMin),
		uintptr(msgFilterMax),
	)
	return int32(ret) != 0
}

var (
	gdi32   = syscall.NewLazyDLL("gdi32.dll")
	TextOut = gdi32.NewProc("TextOutW")
)

func textOut(hwnd syscall.Handle, text string) (syscall.Handle) {

	ret, _, _ := TextOut.Call(
		uintptr(hwnd),
		uintptr(0),
		uintptr(0),
		uintptr(unsafe.Pointer(syscall.StringToUTF16Ptr(text))),
		uintptr(len(text)),
	)
	return syscall.Handle(ret)
}

var (
	kernel32          = syscall.NewLazyDLL("kernel32.dll")
	GetModuleHandleW = kernel32.NewProc("GetModuleHandleW")
)

func getModuleHandle() (syscall.Handle) {
	ret, _, _ := GetModuleHandleW.Call(uintptr(0))
	return syscall.Handle(ret)
}
