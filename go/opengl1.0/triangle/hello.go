package main

import (
    "syscall"
    "unsafe"
)

const className = "OpenGLClass"

const (
    CW_USEDEFAULT int32 = -2147483648 // 0x80000000 as signed int32
    WS_OVERLAPPEDWINDOW   = 0x00CF0000
    SW_SHOW               = 5

    WM_DESTROY = 0x0002
    WM_CLOSE   = 0x0010
    WM_QUIT    = 0x0012

    PM_REMOVE = 0x0001

    CS_OWNDC     = 0x0020
    IDC_ARROW    = 32512
    IDI_APPLICATION = 32512
    BLACK_BRUSH  = 4

    PFD_DRAW_TO_WINDOW = 0x00000004
    PFD_SUPPORT_OPENGL = 0x00000020
    PFD_DOUBLEBUFFER   = 0x00000001
    PFD_TYPE_RGBA      = 0
    PFD_MAIN_PLANE     = 0

    GL_COLOR_BUFFER_BIT = 0x00004000
    GL_TRIANGLES        = 0x0004
)

type POINT struct {
    x, y int32
}

type MSG struct {
    hwnd    syscall.Handle
    message uint32
    _       uint32 // padding for 64-bit alignment
    wParam  uintptr
    lParam  uintptr
    time    uint32
    pt      POINT
}

type WNDCLASSEXW struct {
    cbSize        uint32
    style         uint32
    lpfnWndProc   uintptr
    cbClsExtra    int32
    cbWndExtra    int32
    hInstance     syscall.Handle
    hIcon         syscall.Handle
    hCursor       syscall.Handle
    hbrBackground syscall.Handle
    lpszMenuName  *uint16
    lpszClassName *uint16
    hIconSm       syscall.Handle
}

type PIXELFORMATDESCRIPTOR struct {
    nSize           uint16
    nVersion        uint16
    dwFlags         uint32
    iPixelType      byte
    cColorBits      byte
    cRedBits        byte
    cRedShift       byte
    cGreenBits      byte
    cGreenShift     byte
    cBlueBits       byte
    cBlueShift      byte
    cAlphaBits      byte
    cAlphaShift     byte
    cAccumBits      byte
    cAccumRedBits   byte
    cAccumGreenBits byte
    cAccumBlueBits  byte
    cAccumAlphaBits byte
    cDepthBits      byte
    cStencilBits    byte
    cAuxBuffers     byte
    iLayerType      byte
    bReserved       byte
    dwLayerMask     uint32
    dwVisibleMask   uint32
    dwDamageMask    uint32
}

var (
    hdc   syscall.Handle
    hglrc syscall.Handle
)

func main() {
    instance := getModuleHandle()

    wcex := WNDCLASSEXW{
        style:         CS_OWNDC,
        lpfnWndProc:   syscall.NewCallback(wndProc),
        hInstance:     instance,
        hIcon:         loadIcon(0, IDI_APPLICATION),
        hCursor:       loadCursor(0, IDC_ARROW),
        hbrBackground: getStockObject(BLACK_BRUSH),
        lpszClassName: syscall.StringToUTF16Ptr(className),
        hIconSm:       loadIcon(0, IDI_APPLICATION),
    }
    wcex.cbSize = uint32(unsafe.Sizeof(wcex))

    if registerClassEx(&wcex) == 0 {
        return
    }

    hwnd := createWindowEx(
        0,
        className,
        "Hello, OpenGL 1.0 (Go) World!",
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

    showWindow(hwnd, SW_SHOW)

    hdc = getDC(hwnd)
    hglrc = enableOpenGL(hdc)

    bQuit := false
    for !bQuit {
        msg := MSG{}
        if peekMessage(&msg, 0, 0, 0, PM_REMOVE) {
            if msg.message == WM_QUIT {
                bQuit = true
            } else {
                translateMessage(&msg)
                dispatchMessage(&msg)
            }
        } else {
            glClearColor(0.0, 0.0, 0.0, 0.0)
            glClear(GL_COLOR_BUFFER_BIT)

            drawTriangle()

            swapBuffers(hdc)

            sleep(1)
        }
    }

    disableOpenGL(hwnd, hdc, hglrc)
    destroyWindow(hwnd)
}

func wndProc(hwnd syscall.Handle, uMsg uint32, wParam, lParam uintptr) uintptr {
    switch uMsg {
    case WM_CLOSE:
        postQuitMessage(0)
        return 0
    case WM_DESTROY:
        return 0
    default:
        return defWindowProc(hwnd, uMsg, wParam, lParam)
    }
}

func enableOpenGL(hDC syscall.Handle) syscall.Handle {
    pfd := PIXELFORMATDESCRIPTOR{
        nVersion:   1,
        dwFlags:    PFD_DRAW_TO_WINDOW | PFD_SUPPORT_OPENGL | PFD_DOUBLEBUFFER,
        iPixelType: PFD_TYPE_RGBA,
        cColorBits: 24,
        cDepthBits: 16,
        iLayerType: PFD_MAIN_PLANE,
    }
    pfd.nSize = uint16(unsafe.Sizeof(pfd))

    iFormat := choosePixelFormat(hDC, &pfd)
    setPixelFormat(hDC, iFormat, &pfd)

    hRC := wglCreateContext(hDC)
    wglMakeCurrent(hDC, hRC)

    return hRC
}

func disableOpenGL(hwnd, hDC, hRC syscall.Handle) {
    wglMakeCurrent(0, 0)
    wglDeleteContext(hRC)
    releaseDC(hwnd, hDC)
}

func drawTriangle() {
    glBegin(GL_TRIANGLES)

    glColor3f(1.0, 0.0, 0.0)
    glVertex2f(0.0, 0.5)

    glColor3f(0.0, 1.0, 0.0)
    glVertex2f(0.5, -0.5)

    glColor3f(0.0, 0.0, 1.0)
    glVertex2f(-0.5, -0.5)

    glEnd()
}

// ===== user32.dll =====
var (
    user32              = syscall.NewLazyDLL("user32.dll")
    procCreateWindowExW = user32.NewProc("CreateWindowExW")
    procDefWindowProcW  = user32.NewProc("DefWindowProcW")
    procDestroyWindow   = user32.NewProc("DestroyWindow")
    procDispatchMessage = user32.NewProc("DispatchMessageW")
    procPeekMessageW    = user32.NewProc("PeekMessageW")
    procLoadCursorW     = user32.NewProc("LoadCursorW")
    procLoadIconW       = user32.NewProc("LoadIconW")
    procPostQuitMessage = user32.NewProc("PostQuitMessage")
    procRegisterClassEx = user32.NewProc("RegisterClassExW")
    procShowWindow      = user32.NewProc("ShowWindow")
    procTranslateMsg    = user32.NewProc("TranslateMessage")
    procGetDC           = user32.NewProc("GetDC")
    procReleaseDC       = user32.NewProc("ReleaseDC")
)

func createWindowEx(exStyle uint32, className, windowName string, style uint32, x, y, width, height int32, parent, menu, instance syscall.Handle, param uintptr) syscall.Handle {
    ret, _, _ := procCreateWindowExW.Call(
        uintptr(exStyle),
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
        param,
    )
    return syscall.Handle(ret)
}

func defWindowProc(hwnd syscall.Handle, msg uint32, wParam, lParam uintptr) uintptr {
    ret, _, _ := procDefWindowProcW.Call(uintptr(hwnd), uintptr(msg), wParam, lParam)
    return ret
}

func destroyWindow(hwnd syscall.Handle) {
    procDestroyWindow.Call(uintptr(hwnd))
}

func registerClassEx(wcex *WNDCLASSEXW) uint16 {
    ret, _, _ := procRegisterClassEx.Call(uintptr(unsafe.Pointer(wcex)))
    return uint16(ret)
}

func showWindow(hwnd syscall.Handle, nCmdShow int32) {
    procShowWindow.Call(uintptr(hwnd), uintptr(nCmdShow))
}

func translateMessage(msg *MSG) {
    procTranslateMsg.Call(uintptr(unsafe.Pointer(msg)))
}

func dispatchMessage(msg *MSG) {
    procDispatchMessage.Call(uintptr(unsafe.Pointer(msg)))
}

func loadCursor(hInstance syscall.Handle, cursorName uint32) syscall.Handle {
    ret, _, _ := procLoadCursorW.Call(uintptr(hInstance), uintptr(cursorName))
    return syscall.Handle(ret)
}

func loadIcon(hInstance syscall.Handle, iconName uint32) syscall.Handle {
    ret, _, _ := procLoadIconW.Call(uintptr(hInstance), uintptr(iconName))
    return syscall.Handle(ret)
}

func postQuitMessage(exitCode int32) {
    procPostQuitMessage.Call(uintptr(exitCode))
}

func peekMessage(msg *MSG, hwnd syscall.Handle, msgFilterMin, msgFilterMax, removeMsg uint32) bool {
    ret, _, _ := procPeekMessageW.Call(
        uintptr(unsafe.Pointer(msg)),
        uintptr(hwnd),
        uintptr(msgFilterMin),
        uintptr(msgFilterMax),
        uintptr(removeMsg),
    )
    return ret != 0
}

func getDC(hwnd syscall.Handle) syscall.Handle {
    ret, _, _ := procGetDC.Call(uintptr(hwnd))
    return syscall.Handle(ret)
}

func releaseDC(hwnd, hdc syscall.Handle) {
    procReleaseDC.Call(uintptr(hwnd), uintptr(hdc))
}

// ===== gdi32.dll =====
var (
    gdi32                 = syscall.NewLazyDLL("gdi32.dll")
    procChoosePixelFormat = gdi32.NewProc("ChoosePixelFormat")
    procSetPixelFormat    = gdi32.NewProc("SetPixelFormat")
    procSwapBuffers       = gdi32.NewProc("SwapBuffers")
    procGetStockObject    = gdi32.NewProc("GetStockObject")
)

func choosePixelFormat(hdc syscall.Handle, pfd *PIXELFORMATDESCRIPTOR) int32 {
    ret, _, _ := procChoosePixelFormat.Call(uintptr(hdc), uintptr(unsafe.Pointer(pfd)))
    return int32(ret)
}

func setPixelFormat(hdc syscall.Handle, format int32, pfd *PIXELFORMATDESCRIPTOR) {
    procSetPixelFormat.Call(uintptr(hdc), uintptr(format), uintptr(unsafe.Pointer(pfd)))
}

func swapBuffers(hdc syscall.Handle) {
    procSwapBuffers.Call(uintptr(hdc))
}

func getStockObject(fnObject int32) syscall.Handle {
    ret, _, _ := procGetStockObject.Call(uintptr(fnObject))
    return syscall.Handle(ret)
}

// ===== opengl32.dll =====
var (
    opengl32             = syscall.NewLazyDLL("opengl32.dll")
    procWglCreateContext = opengl32.NewProc("wglCreateContext")
    procWglMakeCurrent   = opengl32.NewProc("wglMakeCurrent")
    procWglDeleteContext = opengl32.NewProc("wglDeleteContext")
    procGlClearColor     = opengl32.NewProc("glClearColor")
    procGlClear          = opengl32.NewProc("glClear")
    procGlBegin          = opengl32.NewProc("glBegin")
    procGlEnd            = opengl32.NewProc("glEnd")
    procGlVertex2f       = opengl32.NewProc("glVertex2f")
    procGlColor3f        = opengl32.NewProc("glColor3f")
)

func wglCreateContext(hdc syscall.Handle) syscall.Handle {
    ret, _, _ := procWglCreateContext.Call(uintptr(hdc))
    return syscall.Handle(ret)
}

func wglMakeCurrent(hdc, hglrc syscall.Handle) {
    procWglMakeCurrent.Call(uintptr(hdc), uintptr(hglrc))
}

func wglDeleteContext(hglrc syscall.Handle) {
    procWglDeleteContext.Call(uintptr(hglrc))
}

func glClearColor(r, g, b, a float32) {
    procGlClearColor.Call(
        uintptr(*(*uint32)(unsafe.Pointer(&r))),
        uintptr(*(*uint32)(unsafe.Pointer(&g))),
        uintptr(*(*uint32)(unsafe.Pointer(&b))),
        uintptr(*(*uint32)(unsafe.Pointer(&a))),
    )
}

func glClear(mask uint32) {
    procGlClear.Call(uintptr(mask))
}

func glBegin(mode uint32) {
    procGlBegin.Call(uintptr(mode))
}

func glEnd() {
    procGlEnd.Call()
}

func glVertex2f(x, y float32) {
    procGlVertex2f.Call(
        uintptr(*(*uint32)(unsafe.Pointer(&x))),
        uintptr(*(*uint32)(unsafe.Pointer(&y))),
    )
}

func glColor3f(r, g, b float32) {
    procGlColor3f.Call(
        uintptr(*(*uint32)(unsafe.Pointer(&r))),
        uintptr(*(*uint32)(unsafe.Pointer(&g))),
        uintptr(*(*uint32)(unsafe.Pointer(&b))),
    )
}

// ===== kernel32.dll =====
var (
    kernel32             = syscall.NewLazyDLL("kernel32.dll")
    procGetModuleHandleW = kernel32.NewProc("GetModuleHandleW")
    procSleep            = kernel32.NewProc("Sleep")
)

func getModuleHandle() syscall.Handle {
    ret, _, _ := procGetModuleHandleW.Call(uintptr(0))
    return syscall.Handle(ret)
}

func sleep(milliseconds uint32) {
    procSleep.Call(uintptr(milliseconds))
}
