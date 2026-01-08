package main

import (
    "runtime"
    "syscall"
    "unsafe"
)

const className = "OpenGLClass"

const (
    CW_USEDEFAULT int32 = -2147483648 // 0x80000000 as signed int32
    WS_OVERLAPPEDWINDOW       = 0x00CF0000

    WM_DESTROY = 0x0002
    WM_CLOSE   = 0x0010
    WM_QUIT    = 0x0012

    PM_REMOVE = 0x0001

    CS_OWNDC        = 0x0020
    IDC_ARROW       = 32512
    IDI_APPLICATION = 32512
    BLACK_BRUSH     = 4

    PFD_DRAW_TO_WINDOW = 0x00000004
    PFD_SUPPORT_OPENGL = 0x00000020
    PFD_DOUBLEBUFFER   = 0x00000001
    PFD_TYPE_RGBA      = 0
    PFD_MAIN_PLANE     = 0

    GL_COLOR_BUFFER_BIT = 0x00004000
    GL_TRIANGLES        = 0x0004
    GL_FLOAT            = 0x1406
    GL_FALSE            = 0

    GL_ARRAY_BUFFER    = 0x8892
    GL_STATIC_DRAW     = 0x88E4
    GL_FRAGMENT_SHADER = 0x8B30
    GL_VERTEX_SHADER   = 0x8B31
)

type POINT struct {
    x, y int32
}

type MSG struct {
    hwnd    syscall.Handle
    message uint32
    _       uint32
    wParam  uintptr
    lParam  uintptr
    time    uint32
    pt      POINT
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

// Shader sources (GLSL 1.10 for OpenGL 2.0)
var vertexSource = `#version 110
attribute vec3 position;
attribute vec3 color;
varying vec4 vColor;
void main()
{
  vColor = vec4(color, 1.0);
  gl_Position = vec4(position, 1.0);
}
`

var fragmentSource = `#version 110
varying vec4 vColor;
void main()
{
  gl_FragColor = vColor;
}
`

// OpenGL 2.0 extension function pointers
var (
    ptrGlGenBuffers              uintptr
    ptrGlBindBuffer              uintptr
    ptrGlBufferData              uintptr
    ptrGlCreateShader            uintptr
    ptrGlShaderSource            uintptr
    ptrGlCompileShader           uintptr
    ptrGlCreateProgram           uintptr
    ptrGlAttachShader            uintptr
    ptrGlLinkProgram             uintptr
    ptrGlUseProgram              uintptr
    ptrGlGetAttribLocation       uintptr
    ptrGlEnableVertexAttribArray uintptr
    ptrGlVertexAttribPointer     uintptr
    ptrGlGetShaderiv             uintptr
    ptrGlGetShaderInfoLog        uintptr
    ptrGlGetProgramiv            uintptr
    ptrGlGetProgramInfoLog       uintptr
)

const (
    GL_COMPILE_STATUS  = 0x8B81
    GL_LINK_STATUS     = 0x8B82
    GL_INFO_LOG_LENGTH = 0x8B84
)

// VBO and attribute locations
var (
    vbo       [2]uint32
    posAttrib int32
    colAttrib int32
)

func main() {
    runtime.LockOSThread()

    instance := getModuleHandle()

    wcx := WNDCLASSEXW{
        style:      CS_OWNDC,
        wndProc:    syscall.NewCallback(wndProc),
        instance:   instance,
        icon:       loadIcon(0, IDI_APPLICATION),
        cursor:     loadCursor(0, IDC_ARROW),
        background: getStockObject(BLACK_BRUSH),
        className:  syscall.StringToUTF16Ptr(className),
        iconSm:     loadIcon(0, IDI_APPLICATION),
    }
    wcx.size = uint32(unsafe.Sizeof(wcx))

    registerClassEx(&wcx)

    hwnd := createWindowEx(
        0,
        className,
        "Hello, OpenGL 2.0 (Go) World!",
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

    showWindow(hwnd, 5)

    hdc = getDC(hwnd)
    hglrc = enableOpenGL(hdc)

    initOpenGLFunc()
    initShader()

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

func wndProc(hwnd syscall.Handle, msg uint32, wparam, lparam uintptr) uintptr {
    switch msg {
    case WM_CLOSE:
        postQuitMessage(0)
        return 0
    case WM_DESTROY:
        return 0
    default:
        return defWindowProc(hwnd, msg, wparam, lparam)
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

func initOpenGLFunc() {
    ptrGlGenBuffers = wglGetProcAddress("glGenBuffers")
    ptrGlBindBuffer = wglGetProcAddress("glBindBuffer")
    ptrGlBufferData = wglGetProcAddress("glBufferData")
    ptrGlCreateShader = wglGetProcAddress("glCreateShader")
    ptrGlShaderSource = wglGetProcAddress("glShaderSource")
    ptrGlCompileShader = wglGetProcAddress("glCompileShader")
    ptrGlCreateProgram = wglGetProcAddress("glCreateProgram")
    ptrGlAttachShader = wglGetProcAddress("glAttachShader")
    ptrGlLinkProgram = wglGetProcAddress("glLinkProgram")
    ptrGlUseProgram = wglGetProcAddress("glUseProgram")
    ptrGlGetAttribLocation = wglGetProcAddress("glGetAttribLocation")
    ptrGlEnableVertexAttribArray = wglGetProcAddress("glEnableVertexAttribArray")
    ptrGlVertexAttribPointer = wglGetProcAddress("glVertexAttribPointer")
    ptrGlGetShaderiv = wglGetProcAddress("glGetShaderiv")
    ptrGlGetShaderInfoLog = wglGetProcAddress("glGetShaderInfoLog")
    ptrGlGetProgramiv = wglGetProcAddress("glGetProgramiv")
    ptrGlGetProgramInfoLog = wglGetProcAddress("glGetProgramInfoLog")
}

func initShader() {
    // Generate VBOs
    glGenBuffers(2, &vbo[0])

    vertices := []float32{
        0.0, 0.5, 0.0,
        0.5, -0.5, 0.0,
        -0.5, -0.5, 0.0,
    }

    colors := []float32{
        1.0, 0.0, 0.0,
        0.0, 1.0, 0.0,
        0.0, 0.0, 1.0,
    }

    glBindBuffer(GL_ARRAY_BUFFER, vbo[0])
    glBufferData(GL_ARRAY_BUFFER, len(vertices)*4, unsafe.Pointer(&vertices[0]), GL_STATIC_DRAW)

    glBindBuffer(GL_ARRAY_BUFFER, vbo[1])
    glBufferData(GL_ARRAY_BUFFER, len(colors)*4, unsafe.Pointer(&colors[0]), GL_STATIC_DRAW)

    // Create and compile the vertex shader
    vertexShader := glCreateShader(GL_VERTEX_SHADER)
    glShaderSource(vertexShader, vertexSource)
    glCompileShader(vertexShader)

    // Check vertex shader compilation
    if !glGetShaderCompileStatus(vertexShader) {
        log := glGetShaderInfoLogString(vertexShader)
        messageBox(0, "Vertex Shader Error:\n"+log, "Shader Error")
    }

    // Create and compile the fragment shader
    fragmentShader := glCreateShader(GL_FRAGMENT_SHADER)
    glShaderSource(fragmentShader, fragmentSource)
    glCompileShader(fragmentShader)

    // Check fragment shader compilation
    if !glGetShaderCompileStatus(fragmentShader) {
        log := glGetShaderInfoLogString(fragmentShader)
        messageBox(0, "Fragment Shader Error:\n"+log, "Shader Error")
    }

    // Link the vertex and fragment shader into a shader program
    shaderProgram := glCreateProgram()
    glAttachShader(shaderProgram, vertexShader)
    glAttachShader(shaderProgram, fragmentShader)
    glLinkProgram(shaderProgram)

    // Check program link status
    if !glGetProgramLinkStatus(shaderProgram) {
        log := glGetProgramInfoLogString(shaderProgram)
        messageBox(0, "Program Link Error:\n"+log, "Shader Error")
    }

    glUseProgram(shaderProgram)

    // Specify the layout of the vertex data
    posAttrib = glGetAttribLocation(shaderProgram, "position")
    glEnableVertexAttribArray(uint32(posAttrib))

    colAttrib = glGetAttribLocation(shaderProgram, "color")
    glEnableVertexAttribArray(uint32(colAttrib))
}

func drawTriangle() {
    glBindBuffer(GL_ARRAY_BUFFER, vbo[0])
    glVertexAttribPointer(uint32(posAttrib), 3, GL_FLOAT, GL_FALSE, 0, 0)

    glBindBuffer(GL_ARRAY_BUFFER, vbo[1])
    glVertexAttribPointer(uint32(colAttrib), 3, GL_FLOAT, GL_FALSE, 0, 0)

    glClear(GL_COLOR_BUFFER_BIT)

    glDrawArrays(GL_TRIANGLES, 0, 3)
}

// ===== OpenGL 2.0 extension functions (via wglGetProcAddress) =====

func glGenBuffers(n int32, buffers *uint32) {
    syscall.SyscallN(ptrGlGenBuffers, uintptr(n), uintptr(unsafe.Pointer(buffers)))
}

func glBindBuffer(target uint32, buffer uint32) {
    syscall.SyscallN(ptrGlBindBuffer, uintptr(target), uintptr(buffer))
}

func glBufferData(target uint32, size int, data unsafe.Pointer, usage uint32) {
    syscall.SyscallN(ptrGlBufferData, uintptr(target), uintptr(size), uintptr(data), uintptr(usage))
}

func glCreateShader(shaderType uint32) uint32 {
    ret, _, _ := syscall.SyscallN(ptrGlCreateShader, uintptr(shaderType))
    return uint32(ret)
}

func glShaderSource(shader uint32, source string) {
    csource, _ := syscall.BytePtrFromString(source)
    syscall.SyscallN(ptrGlShaderSource, uintptr(shader), 1, uintptr(unsafe.Pointer(&csource)), 0)
}

func glCompileShader(shader uint32) {
    syscall.SyscallN(ptrGlCompileShader, uintptr(shader))
}

func glCreateProgram() uint32 {
    ret, _, _ := syscall.SyscallN(ptrGlCreateProgram)
    return uint32(ret)
}

func glAttachShader(program, shader uint32) {
    syscall.SyscallN(ptrGlAttachShader, uintptr(program), uintptr(shader))
}

func glLinkProgram(program uint32) {
    syscall.SyscallN(ptrGlLinkProgram, uintptr(program))
}

func glUseProgram(program uint32) {
    syscall.SyscallN(ptrGlUseProgram, uintptr(program))
}

func glGetAttribLocation(program uint32, name string) int32 {
    cname, _ := syscall.BytePtrFromString(name)
    ret, _, _ := syscall.SyscallN(ptrGlGetAttribLocation, uintptr(program), uintptr(unsafe.Pointer(cname)))
    return int32(ret)
}

func glEnableVertexAttribArray(index uint32) {
    syscall.SyscallN(ptrGlEnableVertexAttribArray, uintptr(index))
}

func glVertexAttribPointer(index uint32, size int32, xtype uint32, normalized uint8, stride int32, pointer uintptr) {
    syscall.SyscallN(ptrGlVertexAttribPointer,
        uintptr(index),
        uintptr(size),
        uintptr(xtype),
        uintptr(normalized),
        uintptr(stride),
        pointer,
    )
}

func glGetShaderiv(shader uint32, pname uint32, params *int32) {
    syscall.SyscallN(ptrGlGetShaderiv, uintptr(shader), uintptr(pname), uintptr(unsafe.Pointer(params)))
}

func glGetShaderInfoLog(shader uint32, maxLength int32, length *int32, infoLog *byte) {
    syscall.SyscallN(ptrGlGetShaderInfoLog, uintptr(shader), uintptr(maxLength), uintptr(unsafe.Pointer(length)), uintptr(unsafe.Pointer(infoLog)))
}

func glGetProgramiv(program uint32, pname uint32, params *int32) {
    syscall.SyscallN(ptrGlGetProgramiv, uintptr(program), uintptr(pname), uintptr(unsafe.Pointer(params)))
}

func glGetProgramInfoLog(program uint32, maxLength int32, length *int32, infoLog *byte) {
    syscall.SyscallN(ptrGlGetProgramInfoLog, uintptr(program), uintptr(maxLength), uintptr(unsafe.Pointer(length)), uintptr(unsafe.Pointer(infoLog)))
}

func glGetShaderCompileStatus(shader uint32) bool {
    var status int32
    glGetShaderiv(shader, GL_COMPILE_STATUS, &status)
    return status != 0
}

func glGetShaderInfoLogString(shader uint32) string {
    var length int32
    glGetShaderiv(shader, GL_INFO_LOG_LENGTH, &length)
    if length == 0 {
        return ""
    }
    buf := make([]byte, length)
    glGetShaderInfoLog(shader, length, nil, &buf[0])
    // Find first NUL and truncate
    for i, b := range buf {
        if b == 0 {
            return string(buf[:i])
        }
    }
    return string(buf)
}

func glGetProgramLinkStatus(program uint32) bool {
    var status int32
    glGetProgramiv(program, GL_LINK_STATUS, &status)
    return status != 0
}

func glGetProgramInfoLogString(program uint32) string {
    var length int32
    glGetProgramiv(program, GL_INFO_LOG_LENGTH, &length)
    if length == 0 {
        return ""
    }
    buf := make([]byte, length)
    glGetProgramInfoLog(program, length, nil, &buf[0])
    // Find first NUL and truncate
    for i, b := range buf {
        if b == 0 {
            return string(buf[:i])
        }
    }
    return string(buf)
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
    procMessageBoxW     = user32.NewProc("MessageBoxW")
)

func messageBox(hwnd syscall.Handle, text, caption string) {
    // Remove NUL characters from text
    cleanText := ""
    for _, c := range text {
        if c != 0 {
            cleanText += string(c)
        }
    }
    procMessageBoxW.Call(
        uintptr(hwnd),
        uintptr(unsafe.Pointer(syscall.StringToUTF16Ptr(cleanText))),
        uintptr(unsafe.Pointer(syscall.StringToUTF16Ptr(caption))),
        0,
    )
}

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

func defWindowProc(hwnd syscall.Handle, msg uint32, wparam, lparam uintptr) uintptr {
    ret, _, _ := procDefWindowProcW.Call(uintptr(hwnd), uintptr(msg), wparam, lparam)
    return ret
}

func destroyWindow(hwnd syscall.Handle) {
    procDestroyWindow.Call(uintptr(hwnd))
}

func registerClassEx(wcx *WNDCLASSEXW) {
    procRegisterClassEx.Call(uintptr(unsafe.Pointer(wcx)))
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
    opengl32               = syscall.NewLazyDLL("opengl32.dll")
    procWglCreateContext   = opengl32.NewProc("wglCreateContext")
    procWglMakeCurrent     = opengl32.NewProc("wglMakeCurrent")
    procWglDeleteContext   = opengl32.NewProc("wglDeleteContext")
    procWglGetProcAddress  = opengl32.NewProc("wglGetProcAddress")
    procGlClearColor       = opengl32.NewProc("glClearColor")
    procGlClear            = opengl32.NewProc("glClear")
    procGlDrawArrays       = opengl32.NewProc("glDrawArrays")
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

func wglGetProcAddress(name string) uintptr {
    cname, _ := syscall.BytePtrFromString(name)
    ret, _, _ := procWglGetProcAddress.Call(uintptr(unsafe.Pointer(cname)))
    return ret
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

func glDrawArrays(mode uint32, first, count int32) {
    procGlDrawArrays.Call(uintptr(mode), uintptr(first), uintptr(count))
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
