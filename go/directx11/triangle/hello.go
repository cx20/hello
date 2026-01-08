package main

import (
    "runtime"
    "syscall"
    "unsafe"
)

// Constants
const (
    CW_USEDEFAULT int32 = -2147483648
    WS_OVERLAPPEDWINDOW = 0x00CF0000

    WM_DESTROY = 0x0002
    WM_PAINT   = 0x000F
    WM_QUIT    = 0x0012

    PM_REMOVE = 0x0001

    CS_HREDRAW = 0x0002
    CS_VREDRAW = 0x0001
    IDC_ARROW  = 32512

    COLOR_WINDOW = 5

    D3D11_SDK_VERSION = 7

    D3D_DRIVER_TYPE_HARDWARE = 1
    D3D_DRIVER_TYPE_WARP     = 2
    D3D_DRIVER_TYPE_REFERENCE = 3

    D3D_FEATURE_LEVEL_11_0 = 0xb000

    DXGI_FORMAT_R8G8B8A8_UNORM    = 28
    DXGI_FORMAT_R32G32B32_FLOAT   = 6
    DXGI_FORMAT_R32G32B32A32_FLOAT = 2

    DXGI_USAGE_RENDER_TARGET_OUTPUT = 0x20

    D3D11_USAGE_DEFAULT        = 0
    D3D11_BIND_VERTEX_BUFFER   = 0x1
    D3D11_INPUT_PER_VERTEX_DATA = 0

    D3D11_PRIMITIVE_TOPOLOGY_TRIANGLELIST = 4

    D3DCOMPILE_ENABLE_STRICTNESS = 0x800
)

// GUID definitions
var (
    IID_ID3D11Texture2D = GUID{0x6f15aaf2, 0xd208, 0x4e89, [8]byte{0x9a, 0xb4, 0x48, 0x95, 0x35, 0xd3, 0x4f, 0x9c}}
)

type GUID struct {
    Data1 uint32
    Data2 uint16
    Data3 uint16
    Data4 [8]byte
}

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

type PAINTSTRUCT struct {
    HDC         syscall.Handle
    FErase      int32
    RcPaint     RECT
    FRestore    int32
    FIncUpdate  int32
    RgbReserved [32]byte
}

// DirectX structures
type DXGI_RATIONAL struct {
    Numerator   uint32
    Denominator uint32
}

type DXGI_MODE_DESC struct {
    Width            uint32
    Height           uint32
    RefreshRate      DXGI_RATIONAL
    Format           uint32
    ScanlineOrdering uint32
    Scaling          uint32
}

type DXGI_SAMPLE_DESC struct {
    Count   uint32
    Quality uint32
}

type DXGI_SWAP_CHAIN_DESC struct {
    BufferDesc   DXGI_MODE_DESC
    SampleDesc   DXGI_SAMPLE_DESC
    BufferUsage  uint32
    BufferCount  uint32
    OutputWindow syscall.Handle
    Windowed     int32
    SwapEffect   uint32
    Flags        uint32
}

type D3D11_VIEWPORT struct {
    TopLeftX float32
    TopLeftY float32
    Width    float32
    Height   float32
    MinDepth float32
    MaxDepth float32
}

type D3D11_BUFFER_DESC struct {
    ByteWidth           uint32
    Usage               uint32
    BindFlags           uint32
    CPUAccessFlags      uint32
    MiscFlags           uint32
    StructureByteStride uint32
}

type D3D11_SUBRESOURCE_DATA struct {
    PSysMem          unsafe.Pointer
    SysMemPitch      uint32
    SysMemSlicePitch uint32
}

type D3D11_INPUT_ELEMENT_DESC struct {
    SemanticName         *byte
    SemanticIndex        uint32
    Format               uint32
    InputSlot            uint32
    AlignedByteOffset    uint32
    InputSlotClass       uint32
    InstanceDataStepRate uint32
}

type VERTEX struct {
    X, Y, Z    float32
    R, G, B, A float32
}

// COM interface pointers (stored as uintptr to vtable)
var (
    g_hWnd              syscall.Handle
    g_pd3dDevice        uintptr
    g_pImmediateContext uintptr
    g_pSwapChain        uintptr
    g_pRenderTargetView uintptr
    g_pVertexShader     uintptr
    g_pPixelShader      uintptr
    g_pVertexLayout     uintptr
    g_pVertexBuffer     uintptr
)

// DLLs
var (
    user32   = syscall.NewLazyDLL("user32.dll")
    kernel32 = syscall.NewLazyDLL("kernel32.dll")
    d3d11    = syscall.NewLazyDLL("d3d11.dll")
    d3dcompiler = syscall.NewLazyDLL("d3dcompiler_47.dll")

    procRegisterClassExW     = user32.NewProc("RegisterClassExW")
    procCreateWindowExW      = user32.NewProc("CreateWindowExW")
    procShowWindow           = user32.NewProc("ShowWindow")
    procPeekMessageW         = user32.NewProc("PeekMessageW")
    procTranslateMessage     = user32.NewProc("TranslateMessage")
    procDispatchMessageW     = user32.NewProc("DispatchMessageW")
    procDefWindowProcW       = user32.NewProc("DefWindowProcW")
    procPostQuitMessage      = user32.NewProc("PostQuitMessage")
    procLoadCursorW          = user32.NewProc("LoadCursorW")
    procGetClientRect        = user32.NewProc("GetClientRect")
    procAdjustWindowRect     = user32.NewProc("AdjustWindowRect")
    procBeginPaint           = user32.NewProc("BeginPaint")
    procEndPaint             = user32.NewProc("EndPaint")
    procMessageBoxW          = user32.NewProc("MessageBoxW")

    procGetModuleHandleW = kernel32.NewProc("GetModuleHandleW")

    procD3D11CreateDeviceAndSwapChain = d3d11.NewProc("D3D11CreateDeviceAndSwapChain")
    procD3DCompile                    = d3dcompiler.NewProc("D3DCompile")
)

func messageBox(hwnd syscall.Handle, text, caption string) {
    procMessageBoxW.Call(
        uintptr(hwnd),
        uintptr(unsafe.Pointer(syscall.StringToUTF16Ptr(text))),
        uintptr(unsafe.Pointer(syscall.StringToUTF16Ptr(caption))),
        0,
    )
}

// Shader source code (embedded)
var shaderSource = `
struct VS_INPUT
{
    float4 Pos : POSITION;
    float4 Color : COLOR;
};

struct PS_INPUT
{
    float4 Pos : SV_POSITION;
    float4 Color : COLOR;
};

PS_INPUT VS(VS_INPUT input)
{
    PS_INPUT output;
    output.Pos = input.Pos;
    output.Color = input.Color;
    return output;
}

float4 PS(PS_INPUT input) : SV_Target
{
    return input.Color;
}
`

func main() {
    runtime.LockOSThread()

    instance := getModuleHandle()

    if !initWindow(instance, 5) {
        return
    }

    if !initDevice() {
        cleanupDevice()
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

    cleanupDevice()
}

func wndProc(hwnd syscall.Handle, msg uint32, wParam, lParam uintptr) uintptr {
    switch msg {
    case WM_PAINT:
        var ps PAINTSTRUCT
        beginPaint(hwnd, &ps)
        endPaint(hwnd, &ps)
        return 0
    case WM_DESTROY:
        postQuitMessage(0)
        return 0
    default:
        return defWindowProc(hwnd, msg, wParam, lParam)
    }
}

func initWindow(instance syscall.Handle, nCmdShow int32) bool {
    className := syscall.StringToUTF16Ptr("D3D11WindowClass")

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

    rc := RECT{0, 0, 640, 480}
    adjustWindowRect(&rc, WS_OVERLAPPEDWINDOW, false)

    g_hWnd = createWindowEx(
        0,
        className,
        syscall.StringToUTF16Ptr("Hello, DirectX 11 (Go) World!"),
        WS_OVERLAPPEDWINDOW,
        CW_USEDEFAULT,
        CW_USEDEFAULT,
        rc.Right-rc.Left,
        rc.Bottom-rc.Top,
        0,
        0,
        instance,
        0,
    )

    if g_hWnd == 0 {
        return false
    }

    showWindow(g_hWnd, nCmdShow)
    return true
}

func initDevice() bool {
    var rc RECT
    getClientRect(g_hWnd, &rc)
    width := uint32(rc.Right - rc.Left)
    height := uint32(rc.Bottom - rc.Top)

    sd := DXGI_SWAP_CHAIN_DESC{
        BufferDesc: DXGI_MODE_DESC{
            Width:  width,
            Height: height,
            Format: DXGI_FORMAT_R8G8B8A8_UNORM,
            RefreshRate: DXGI_RATIONAL{
                Numerator:   60,
                Denominator: 1,
            },
        },
        SampleDesc: DXGI_SAMPLE_DESC{
            Count:   1,
            Quality: 0,
        },
        BufferUsage:  DXGI_USAGE_RENDER_TARGET_OUTPUT,
        BufferCount:  1,
        OutputWindow: g_hWnd,
        Windowed:     1,
    }

    driverTypes := []uint32{D3D_DRIVER_TYPE_HARDWARE, D3D_DRIVER_TYPE_WARP, D3D_DRIVER_TYPE_REFERENCE}
    featureLevels := []uint32{D3D_FEATURE_LEVEL_11_0}

    var hr uintptr
    for _, driverType := range driverTypes {
        hr, _, _ = procD3D11CreateDeviceAndSwapChain.Call(
            0, // pAdapter
            uintptr(driverType),
            0, // Software
            0, // Flags
            uintptr(unsafe.Pointer(&featureLevels[0])),
            uintptr(len(featureLevels)),
            D3D11_SDK_VERSION,
            uintptr(unsafe.Pointer(&sd)),
            uintptr(unsafe.Pointer(&g_pSwapChain)),
            uintptr(unsafe.Pointer(&g_pd3dDevice)),
            0, // pFeatureLevel
            uintptr(unsafe.Pointer(&g_pImmediateContext)),
        )
        if hr == 0 {
            break
        }
    }
    if hr != 0 {
        return false
    }

    // Get back buffer
    var pBackBuffer uintptr
    hr = comCall(g_pSwapChain, 9, // GetBuffer is at index 9 in IDXGISwapChain vtable
        0,
        uintptr(unsafe.Pointer(&IID_ID3D11Texture2D)),
        uintptr(unsafe.Pointer(&pBackBuffer)),
    )
    if hr != 0 {
        return false
    }

    // Create render target view
    hr = comCall(g_pd3dDevice, 9, // CreateRenderTargetView is at index 9 in ID3D11Device vtable
        pBackBuffer,
        0,
        uintptr(unsafe.Pointer(&g_pRenderTargetView)),
    )
    comRelease(pBackBuffer)
    if hr != 0 {
        return false
    }

    // Set render target
    comCall(g_pImmediateContext, 33, // OMSetRenderTargets is at index 33
        1,
        uintptr(unsafe.Pointer(&g_pRenderTargetView)),
        0,
    )

    // Set viewport
    vp := D3D11_VIEWPORT{
        Width:    float32(width),
        Height:   float32(height),
        MinDepth: 0.0,
        MaxDepth: 1.0,
        TopLeftX: 0,
        TopLeftY: 0,
    }
    comCall(g_pImmediateContext, 44, // RSSetViewports is at index 44
        1,
        uintptr(unsafe.Pointer(&vp)),
    )

    // Compile and create vertex shader
    var pVSBlob uintptr
    var pErrorBlob uintptr
    shaderBytes := []byte(shaderSource)
    vsEntry, _ := syscall.BytePtrFromString("VS")
    vsModel, _ := syscall.BytePtrFromString("vs_4_0")

    hr, _, _ = procD3DCompile.Call(
        uintptr(unsafe.Pointer(&shaderBytes[0])),
        uintptr(len(shaderBytes)),
        0, // pSourceName
        0, // pDefines
        0, // pInclude
        uintptr(unsafe.Pointer(vsEntry)),
        uintptr(unsafe.Pointer(vsModel)),
        D3DCOMPILE_ENABLE_STRICTNESS,
        0,
        uintptr(unsafe.Pointer(&pVSBlob)),
        uintptr(unsafe.Pointer(&pErrorBlob)),
    )
    if hr != 0 {
        if pErrorBlob != 0 {
            errPtr := comCall(pErrorBlob, 3) // GetBufferPointer
            if errPtr != 0 {
                errMsg := goString(errPtr)
                messageBox(0, "Vertex Shader Error: "+errMsg, "Shader Error")
            }
            comRelease(pErrorBlob)
        }
        return false
    }

    vsBufferPtr := comCall(pVSBlob, 3) // GetBufferPointer is at index 3
    vsBufferSize := comCall(pVSBlob, 4) // GetBufferSize is at index 4

    hr = comCall(g_pd3dDevice, 12, // CreateVertexShader is at index 12
        vsBufferPtr,
        vsBufferSize,
        0,
        uintptr(unsafe.Pointer(&g_pVertexShader)),
    )
    if hr != 0 {
        comRelease(pVSBlob)
        return false
    }

    // Create input layout
    positionName, _ := syscall.BytePtrFromString("POSITION")
    colorName, _ := syscall.BytePtrFromString("COLOR")

    layout := []D3D11_INPUT_ELEMENT_DESC{
        {
            SemanticName:      positionName,
            SemanticIndex:     0,
            Format:            DXGI_FORMAT_R32G32B32_FLOAT,
            InputSlot:         0,
            AlignedByteOffset: 0,
            InputSlotClass:    D3D11_INPUT_PER_VERTEX_DATA,
        },
        {
            SemanticName:      colorName,
            SemanticIndex:     0,
            Format:            DXGI_FORMAT_R32G32B32A32_FLOAT,
            InputSlot:         0,
            AlignedByteOffset: 12,
            InputSlotClass:    D3D11_INPUT_PER_VERTEX_DATA,
        },
    }

    hr = comCall(g_pd3dDevice, 11, // CreateInputLayout is at index 11
        uintptr(unsafe.Pointer(&layout[0])),
        uintptr(len(layout)),
        vsBufferPtr,
        vsBufferSize,
        uintptr(unsafe.Pointer(&g_pVertexLayout)),
    )
    comRelease(pVSBlob)
    if hr != 0 {
        return false
    }

    // Set input layout
    comCall(g_pImmediateContext, 17, // IASetInputLayout is at index 17
        g_pVertexLayout,
    )

    // Compile and create pixel shader
    var pPSBlob uintptr
    psEntry, _ := syscall.BytePtrFromString("PS")
    psModel, _ := syscall.BytePtrFromString("ps_4_0")

    hr, _, _ = procD3DCompile.Call(
        uintptr(unsafe.Pointer(&shaderBytes[0])),
        uintptr(len(shaderBytes)),
        0, 0, 0,
        uintptr(unsafe.Pointer(psEntry)),
        uintptr(unsafe.Pointer(psModel)),
        D3DCOMPILE_ENABLE_STRICTNESS,
        0,
        uintptr(unsafe.Pointer(&pPSBlob)),
        uintptr(unsafe.Pointer(&pErrorBlob)),
    )
    if hr != 0 {
        if pErrorBlob != 0 {
            comRelease(pErrorBlob)
        }
        return false
    }

    psBufferPtr := comCall(pPSBlob, 3)
    psBufferSize := comCall(pPSBlob, 4)

    hr = comCall(g_pd3dDevice, 15, // CreatePixelShader is at index 15
        psBufferPtr,
        psBufferSize,
        0,
        uintptr(unsafe.Pointer(&g_pPixelShader)),
    )
    comRelease(pPSBlob)
    if hr != 0 {
        return false
    }

    // Create vertex buffer
    vertices := []VERTEX{
        {0.0, 0.5, 0.5, 1.0, 0.0, 0.0, 1.0},
        {0.5, -0.5, 0.5, 0.0, 1.0, 0.0, 1.0},
        {-0.5, -0.5, 0.5, 0.0, 0.0, 1.0, 1.0},
    }

    bd := D3D11_BUFFER_DESC{
        Usage:     D3D11_USAGE_DEFAULT,
        ByteWidth: uint32(unsafe.Sizeof(VERTEX{})) * 3,
        BindFlags: D3D11_BIND_VERTEX_BUFFER,
    }

    initData := D3D11_SUBRESOURCE_DATA{
        PSysMem: unsafe.Pointer(&vertices[0]),
    }

    hr = comCall(g_pd3dDevice, 3, // CreateBuffer is at index 3
        uintptr(unsafe.Pointer(&bd)),
        uintptr(unsafe.Pointer(&initData)),
        uintptr(unsafe.Pointer(&g_pVertexBuffer)),
    )
    if hr != 0 {
        return false
    }

    // Set vertex buffer
    stride := uint32(unsafe.Sizeof(VERTEX{}))
    offset := uint32(0)
    comCall(g_pImmediateContext, 18, // IASetVertexBuffers is at index 18
        0, 1,
        uintptr(unsafe.Pointer(&g_pVertexBuffer)),
        uintptr(unsafe.Pointer(&stride)),
        uintptr(unsafe.Pointer(&offset)),
    )

    // Set primitive topology
    comCall(g_pImmediateContext, 24, // IASetPrimitiveTopology is at index 24
        D3D11_PRIMITIVE_TOPOLOGY_TRIANGLELIST,
    )

    return true
}

func cleanupDevice() {
    if g_pImmediateContext != 0 {
        comCall(g_pImmediateContext, 106) // ClearState is at index 106
    }
    if g_pVertexBuffer != 0 {
        comRelease(g_pVertexBuffer)
    }
    if g_pVertexLayout != 0 {
        comRelease(g_pVertexLayout)
    }
    if g_pVertexShader != 0 {
        comRelease(g_pVertexShader)
    }
    if g_pPixelShader != 0 {
        comRelease(g_pPixelShader)
    }
    if g_pRenderTargetView != 0 {
        comRelease(g_pRenderTargetView)
    }
    if g_pSwapChain != 0 {
        comRelease(g_pSwapChain)
    }
    if g_pImmediateContext != 0 {
        comRelease(g_pImmediateContext)
    }
    if g_pd3dDevice != 0 {
        comRelease(g_pd3dDevice)
    }
}

func render() {
    // Clear (white background like C version)
    clearColor := [4]float32{1.0, 1.0, 1.0, 1.0}
    comCall(g_pImmediateContext, 50, // ClearRenderTargetView is at index 50
        g_pRenderTargetView,
        uintptr(unsafe.Pointer(&clearColor[0])),
    )

    // Set shaders
    comCall(g_pImmediateContext, 11, // VSSetShader is at index 11
        g_pVertexShader, 0, 0,
    )
    comCall(g_pImmediateContext, 9, // PSSetShader is at index 9
        g_pPixelShader, 0, 0,
    )

    // Draw
    comCall(g_pImmediateContext, 13, // Draw is at index 13
        3, 0,
    )

    // Present
    comCall(g_pSwapChain, 8, // Present is at index 8 in IDXGISwapChain vtable
        0, 0,
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

// goString converts a null-terminated C string to a Go string
func goString(ptr uintptr) string {
    if ptr == 0 {
        return ""
    }
    var buf []byte
    for {
        b := *(*byte)(unsafe.Pointer(ptr))
        if b == 0 {
            break
        }
        buf = append(buf, b)
        ptr++
    }
    return string(buf)
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

func getClientRect(hwnd syscall.Handle, rect *RECT) bool {
    ret, _, _ := procGetClientRect.Call(uintptr(hwnd), uintptr(unsafe.Pointer(rect)))
    return ret != 0
}

func adjustWindowRect(rect *RECT, style uint32, menu bool) bool {
    var m uintptr
    if menu {
        m = 1
    }
    ret, _, _ := procAdjustWindowRect.Call(uintptr(unsafe.Pointer(rect)), uintptr(style), m)
    return ret != 0
}

func beginPaint(hwnd syscall.Handle, ps *PAINTSTRUCT) syscall.Handle {
    ret, _, _ := procBeginPaint.Call(uintptr(hwnd), uintptr(unsafe.Pointer(ps)))
    return syscall.Handle(ret)
}

func endPaint(hwnd syscall.Handle, ps *PAINTSTRUCT) {
    procEndPaint.Call(uintptr(hwnd), uintptr(unsafe.Pointer(ps)))
}
