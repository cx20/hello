@file:OptIn(kotlinx.cinterop.ExperimentalForeignApi::class)

import kotlinx.cinterop.*
import platform.windows.*

private const val CLASS_NAME = "WindowClass"
private const val WINDOW_NAME = "Hello, World!"

// ============================================================
// GDI+ Structures and Constants
// ============================================================

// GdiplusStartupInput structure
class GdiplusStartupInput(rawPtr: NativePtr) : CStructVar(rawPtr) {
    companion object : Type(24, 8)
    
    var GdiplusVersion: UInt
        get() = this.ptr.reinterpret<UIntVar>().pointed.value
        set(value) { this.ptr.reinterpret<UIntVar>().pointed.value = value }
    
    var DebugEventCallback: COpaquePointer?
        get() = interpretCPointer<COpaquePointerVar>(this.ptr.rawValue + 8)!!.pointed.value
        set(value) { interpretCPointer<COpaquePointerVar>(this.ptr.rawValue + 8)!!.pointed.value = value }
    
    var SuppressBackgroundThread: Int
        get() = interpretCPointer<IntVar>(this.ptr.rawValue + 16)!!.pointed.value
        set(value) { interpretCPointer<IntVar>(this.ptr.rawValue + 16)!!.pointed.value = value }
    
    var SuppressExternalCodecs: Int
        get() = interpretCPointer<IntVar>(this.ptr.rawValue + 20)!!.pointed.value
        set(value) { interpretCPointer<IntVar>(this.ptr.rawValue + 20)!!.pointed.value = value }
}

// Point structure
class GpPoint(rawPtr: NativePtr) : CStructVar(rawPtr) {
    companion object : Type(8, 4)
    
    var X: Int
        get() = this.ptr.reinterpret<IntVar>().pointed.value
        set(value) { this.ptr.reinterpret<IntVar>().pointed.value = value }
    var Y: Int
        get() = interpretCPointer<IntVar>(this.ptr.rawValue + 4)!!.pointed.value
        set(value) { interpretCPointer<IntVar>(this.ptr.rawValue + 4)!!.pointed.value = value }
}

// Color as 32-bit ARGB
typealias ARGB = UInt

// ============================================================
// GDI+ Function Pointers
// ============================================================

private lateinit var gdiStartup: CPointer<CFunction<(CPointer<UIntVar>?, CPointer<GdiplusStartupInput>?, COpaquePointer?) -> Int>>
private lateinit var gdiShutdown: CPointer<CFunction<(UInt) -> Int>>
private lateinit var createFromHDC: CPointer<CFunction<(HDC?, CPointer<COpaquePointerVar>?) -> Int>>
private lateinit var deleteGraphics: CPointer<CFunction<(COpaquePointer?) -> Int>>
private lateinit var createPath: CPointer<CFunction<(Int, CPointer<COpaquePointerVar>?) -> Int>>
private lateinit var deletePath: CPointer<CFunction<(COpaquePointer?) -> Int>>
private lateinit var addLines: CPointer<CFunction<(COpaquePointer?, CPointer<GpPoint>?, Int) -> Int>>
private lateinit var closePathFigure: CPointer<CFunction<(COpaquePointer?) -> Int>>
private lateinit var createPathGradient: CPointer<CFunction<(COpaquePointer?, CPointer<COpaquePointerVar>?) -> Int>>
private lateinit var deletePathGradient: CPointer<CFunction<(COpaquePointer?) -> Int>>
private lateinit var setPathGradientCenterColor: CPointer<CFunction<(COpaquePointer?, ARGB) -> Int>>
private lateinit var setPathGradientSurroundColors: CPointer<CFunction<(COpaquePointer?, CPointer<UIntVar>?, CPointer<IntVar>?) -> Int>>
private lateinit var fillPath: CPointer<CFunction<(COpaquePointer?, COpaquePointer?, COpaquePointer?) -> Int>>

// ============================================================
// GDI+ Initialization
// ============================================================

private fun initGdiPlus(): Boolean = memScoped {
    val gdiplusModule = LoadLibraryW("gdiplus.dll")
    if (gdiplusModule == null) {
        return@memScoped false
    }
    
    gdiStartup = GetProcAddress(gdiplusModule, "GdiplusStartup")
        ?.reinterpret<CFunction<(CPointer<UIntVar>?, CPointer<GdiplusStartupInput>?, COpaquePointer?) -> Int>>()
        ?: return@memScoped false
    gdiShutdown = GetProcAddress(gdiplusModule, "GdiplusShutdown")
        ?.reinterpret<CFunction<(UInt) -> Int>>()
        ?: return@memScoped false
    createFromHDC = GetProcAddress(gdiplusModule, "GdipCreateFromHDC")
        ?.reinterpret<CFunction<(HDC?, CPointer<COpaquePointerVar>?) -> Int>>()
        ?: return@memScoped false
    deleteGraphics = GetProcAddress(gdiplusModule, "GdipDeleteGraphics")
        ?.reinterpret<CFunction<(COpaquePointer?) -> Int>>()
        ?: return@memScoped false
    createPath = GetProcAddress(gdiplusModule, "GdipCreatePath")
        ?.reinterpret<CFunction<(Int, CPointer<COpaquePointerVar>?) -> Int>>()
        ?: return@memScoped false
    deletePath = GetProcAddress(gdiplusModule, "GdipDeletePath")
        ?.reinterpret<CFunction<(COpaquePointer?) -> Int>>()
        ?: return@memScoped false
    addLines = GetProcAddress(gdiplusModule, "GdipAddPathLine2I")
        ?.reinterpret<CFunction<(COpaquePointer?, CPointer<GpPoint>?, Int) -> Int>>()
        ?: return@memScoped false
    closePathFigure = GetProcAddress(gdiplusModule, "GdipClosePathFigure")
        ?.reinterpret<CFunction<(COpaquePointer?) -> Int>>()
        ?: return@memScoped false
    createPathGradient = GetProcAddress(gdiplusModule, "GdipCreatePathGradientFromPath")
        ?.reinterpret<CFunction<(COpaquePointer?, CPointer<COpaquePointerVar>?) -> Int>>()
        ?: return@memScoped false
    deletePathGradient = GetProcAddress(gdiplusModule, "GdipDeleteBrush")
        ?.reinterpret<CFunction<(COpaquePointer?) -> Int>>()
        ?: return@memScoped false
    setPathGradientCenterColor = GetProcAddress(gdiplusModule, "GdipSetPathGradientCenterColor")
        ?.reinterpret<CFunction<(COpaquePointer?, ARGB) -> Int>>()
        ?: return@memScoped false
    setPathGradientSurroundColors = GetProcAddress(gdiplusModule, "GdipSetPathGradientSurroundColorsWithCount")
        ?.reinterpret<CFunction<(COpaquePointer?, CPointer<UIntVar>?, CPointer<IntVar>?) -> Int>>()
        ?: return@memScoped false
    fillPath = GetProcAddress(gdiplusModule, "GdipFillPath")
        ?.reinterpret<CFunction<(COpaquePointer?, COpaquePointer?, COpaquePointer?) -> Int>>()
        ?: return@memScoped false
    
    true
}

// Helper to create ARGB color
private fun argb(a: Int, r: Int, g: Int, b: Int): ARGB {
    return ((a and 0xFF).toUInt() shl 24) or ((r and 0xFF).toUInt() shl 16) or ((g and 0xFF).toUInt() shl 8) or (b and 0xFF).toUInt()
}

// Draw a gradient triangle using GDI+
private fun drawTriangle(hdc: HDC?, width: Int, height: Int) = memScoped {
    // Create Graphics from HDC
    val graphics = allocArray<COpaquePointerVar>(1)
    val graphicsResult = createFromHDC.invoke(hdc, graphics)
    if (graphicsResult != 0) {
        return@memScoped
    }
    val pGraphics = graphics[0]!!
    
    // Create Path
    val path = allocArray<COpaquePointerVar>(1)
    val pathResult = createPath.invoke(0, path) // 0 = FillModeAlternate
    if (pathResult != 0) {
        deleteGraphics.invoke(pGraphics)
        return@memScoped
    }
    val pPath = path[0]!!
    
    // Add three lines to create a triangle
    val points = allocArray<GpPoint>(3)
    points[0].X = width * 1 / 2
    points[0].Y = height * 1 / 4
    points[1].X = width * 3 / 4
    points[1].Y = height * 3 / 4
    points[2].X = width * 1 / 4
    points[2].Y = height * 3 / 4
    
    addLines.invoke(pPath, points, 3)
    
    // Close the path to form a triangle
    closePathFigure.invoke(pPath)
    
    // Create PathGradientBrush from Path
    val brush = allocArray<COpaquePointerVar>(1)
    val brushResult = createPathGradient.invoke(pPath, brush)
    if (brushResult != 0) {
        deletePath.invoke(pPath)
        deleteGraphics.invoke(pGraphics)
        return@memScoped
    }
    val pBrush = brush[0]!!
    
    // Set center color (gray)
    setPathGradientCenterColor.invoke(pBrush, argb(255, 85, 85, 85))
    
    // Set surround colors (red, green, blue)
    val colorCount = alloc<IntVar>()
    colorCount.value = 3
    setPathGradientSurroundColors.invoke(pBrush, cValuesOf(
        argb(255, 255, 0, 0),
        argb(255, 0, 255, 0),
        argb(255, 0, 0, 255)
    ).ptr, colorCount.ptr)
    
    // Fill the path with the gradient
    fillPath.invoke(pGraphics, pBrush, pPath)
    
    // Clean up
    deletePathGradient.invoke(pBrush)
    deletePath.invoke(pPath)
    deleteGraphics.invoke(pGraphics)
}

// Paint handler: compute the client size and draw the triangle to fit.
private fun onPaint(hWnd: HWND?, hdc: HDC?) = memScoped {
    val rc = alloc<RECT>()
    GetClientRect(hWnd, rc.ptr)

    val w = rc.right - rc.left
    val h = rc.bottom - rc.top

    drawTriangle(hdc, w, h)
}

// Window procedure: handle WM_PAINT and WM_CLOSE, otherwise delegate to DefWindowProcW.
private fun WndProc(hWnd: HWND?, uMsg: UINT, wParam: WPARAM, lParam: LPARAM): LRESULT {
    return when (uMsg.toInt()) {
        WM_CLOSE -> {
            PostQuitMessage(0)
            0L
        }

        WM_DESTROY -> {
            0L
        }

        WM_PAINT -> {
            memScoped {
                val ps = alloc<PAINTSTRUCT>()
                val hdc = BeginPaint(hWnd, ps.ptr)
                onPaint(hWnd, hdc)
                EndPaint(hWnd, ps.ptr)
            }
            0L
        }

        else -> DefWindowProcW(hWnd, uMsg, wParam, lParam)
    }
}

fun main() {
    if (!initGdiPlus()) {
        println("Failed to initialize GDI+")
        return
    }
    
    // Initialize GDI+ once at startup
    val gdiplusToken = memScoped {
        val startupInput = alloc<GdiplusStartupInput>()
        startupInput.GdiplusVersion = 1u
        startupInput.DebugEventCallback = null
        startupInput.SuppressBackgroundThread = 0
        startupInput.SuppressExternalCodecs = 0
        val token = alloc<UIntVar>()
        
        val startResult = gdiStartup.invoke(token.ptr, startupInput.ptr, null)
        if (startResult != 0) {
            println("GdiplusStartup failed!")
            return
        }
        token.value
    }
    
    memScoped {
        val hInstance = GetModuleHandleW(null)

        val classNameW = CLASS_NAME.wcstr.ptr

        val wcex = alloc<WNDCLASSEXW>().apply {
            cbSize = sizeOf<WNDCLASSEXW>().toUInt()
            style = CS_OWNDC.toUInt()
            lpfnWndProc = staticCFunction(::WndProc)
            cbClsExtra = 0
            cbWndExtra = 0
            this.hInstance = hInstance
            hIcon = LoadIconW(null, IDI_APPLICATION)
            hCursor = LoadCursorW(null, IDC_ARROW)
            hbrBackground = GetSysColorBrush(COLOR_WINDOW)
            lpszMenuName = null
            lpszClassName = classNameW
            hIconSm = LoadIconW(null, IDI_APPLICATION)
        }

        if (RegisterClassExW(wcex.ptr) == 0.toUShort()) {
            MessageBoxW(null, "RegisterClassExW failed", "Error", MB_OK.toUInt())
            return
        }

        val hWnd = CreateWindowExW(
            0u,
            CLASS_NAME,
            WINDOW_NAME,
            WS_OVERLAPPEDWINDOW.toUInt(),
            CW_USEDEFAULT,
            CW_USEDEFAULT,
            640,
            480,
            null,
            null,
            hInstance,
            null
        )

        if (hWnd == null) {
            MessageBoxW(null, "CreateWindowExW failed", "Error", MB_OK.toUInt())
            return
        }

        ShowWindow(hWnd, SW_SHOWDEFAULT)
        UpdateWindow(hWnd)

        val msg = alloc<MSG>()
        while (GetMessageW(msg.ptr, null, 0u, 0u) > 0) {
            TranslateMessage(msg.ptr)
            DispatchMessageW(msg.ptr)
        }
    }
    
    // Shutdown GDI+
    gdiShutdown.invoke(gdiplusToken)
}
