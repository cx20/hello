@file:OptIn(kotlinx.cinterop.ExperimentalForeignApi::class)

import kotlinx.cinterop.*
import platform.windows.*

// ============================================================
// Direct2D structures
// ============================================================
class D2D1_COLOR_F(rawPtr: NativePtr) : CStructVar(rawPtr) {
    companion object : Type(16, 4)
    
    var r: Float
        get() = this.ptr.reinterpret<FloatVar>().pointed.value
        set(value) { this.ptr.reinterpret<FloatVar>().pointed.value = value }
    
    var g: Float
        get() = this.ptr.rawValue.plus(4).toLong().toCPointer<FloatVar>()!!.pointed.value
        set(value) { this.ptr.rawValue.plus(4).toLong().toCPointer<FloatVar>()!!.pointed.value = value }
    
    var b: Float
        get() = this.ptr.rawValue.plus(8).toLong().toCPointer<FloatVar>()!!.pointed.value
        set(value) { this.ptr.rawValue.plus(8).toLong().toCPointer<FloatVar>()!!.pointed.value = value }
    
    var a: Float
        get() = this.ptr.rawValue.plus(12).toLong().toCPointer<FloatVar>()!!.pointed.value
        set(value) { this.ptr.rawValue.plus(12).toLong().toCPointer<FloatVar>()!!.pointed.value = value }
}

class D2D1_RECT_F(rawPtr: NativePtr) : CStructVar(rawPtr) {
    companion object : Type(16, 4)
    
    var left: Float
        get() = this.ptr.reinterpret<FloatVar>().pointed.value
        set(value) { this.ptr.reinterpret<FloatVar>().pointed.value = value }
    
    var top: Float
        get() = this.ptr.rawValue.plus(4).toLong().toCPointer<FloatVar>()!!.pointed.value
        set(value) { this.ptr.rawValue.plus(4).toLong().toCPointer<FloatVar>()!!.pointed.value = value }
    
    var right: Float
        get() = this.ptr.rawValue.plus(8).toLong().toCPointer<FloatVar>()!!.pointed.value
        set(value) { this.ptr.rawValue.plus(8).toLong().toCPointer<FloatVar>()!!.pointed.value = value }
    
    var bottom: Float
        get() = this.ptr.rawValue.plus(12).toLong().toCPointer<FloatVar>()!!.pointed.value
        set(value) { this.ptr.rawValue.plus(12).toLong().toCPointer<FloatVar>()!!.pointed.value = value }
}

class D2D1_POINT_2F(rawPtr: NativePtr) : CStructVar(rawPtr) {
    companion object : Type(8, 4)
    
    var x: Float
        get() = this.ptr.reinterpret<FloatVar>().pointed.value
        set(value) { this.ptr.reinterpret<FloatVar>().pointed.value = value }
    
    var y: Float
        get() = this.ptr.rawValue.plus(4).toLong().toCPointer<FloatVar>()!!.pointed.value
        set(value) { this.ptr.rawValue.plus(4).toLong().toCPointer<FloatVar>()!!.pointed.value = value }
}

class D2D1_SIZE_U(rawPtr: NativePtr) : CStructVar(rawPtr) {
    companion object : Type(8, 4)
    
    var width: UInt
        get() = this.ptr.reinterpret<UIntVar>().pointed.value
        set(value) { this.ptr.reinterpret<UIntVar>().pointed.value = value }
    
    var height: UInt
        get() = this.ptr.rawValue.plus(4).toLong().toCPointer<UIntVar>()!!.pointed.value
        set(value) { this.ptr.rawValue.plus(4).toLong().toCPointer<UIntVar>()!!.pointed.value = value }
}

class D2D1_PIXEL_FORMAT(rawPtr: NativePtr) : CStructVar(rawPtr) {
    companion object : Type(8, 4)
    
    var format: UInt
        get() = this.ptr.reinterpret<UIntVar>().pointed.value
        set(value) { this.ptr.reinterpret<UIntVar>().pointed.value = value }
    
    var alphaMode: UInt
        get() = this.ptr.rawValue.plus(4).toLong().toCPointer<UIntVar>()!!.pointed.value
        set(value) { this.ptr.rawValue.plus(4).toLong().toCPointer<UIntVar>()!!.pointed.value = value }
}

class D2D1_RENDER_TARGET_PROPERTIES(rawPtr: NativePtr) : CStructVar(rawPtr) {
    companion object : Type(32, 4)
    
    var type: UInt
        get() = this.ptr.reinterpret<UIntVar>().pointed.value
        set(value) { this.ptr.reinterpret<UIntVar>().pointed.value = value }
}

class D2D1_HWND_RENDER_TARGET_PROPERTIES(rawPtr: NativePtr) : CStructVar(rawPtr) {
    companion object : Type(24, 8)
    
    var hwnd: HWND?
        get() = this.ptr.reinterpret<COpaquePointerVar>().pointed.value?.reinterpret()
        set(value) { this.ptr.reinterpret<COpaquePointerVar>().pointed.value = value?.reinterpret() }
    
    fun setPixelSize(width: UInt, height: UInt) {
        // pixelSize at offset 8
        this.ptr.rawValue.plus(8).toLong().toCPointer<UIntVar>()!!.pointed.value = width
        this.ptr.rawValue.plus(12).toLong().toCPointer<UIntVar>()!!.pointed.value = height
    }
    
    var presentOptions: UInt
        get() = this.ptr.rawValue.plus(16).toLong().toCPointer<UIntVar>()!!.pointed.value
        set(value) { this.ptr.rawValue.plus(16).toLong().toCPointer<UIntVar>()!!.pointed.value = value }
}

// ============================================================
// GUID structure
// ============================================================
class GUID(rawPtr: NativePtr) : CStructVar(rawPtr) {
    companion object : Type(16, 4)
    
    var Data1: UInt
        get() = this.ptr.reinterpret<UIntVar>().pointed.value
        set(value) { this.ptr.reinterpret<UIntVar>().pointed.value = value }
    
    var Data2: UShort
        get() = this.ptr.rawValue.plus(4).toLong().toCPointer<UShortVar>()!!.pointed.value
        set(value) { this.ptr.rawValue.plus(4).toLong().toCPointer<UShortVar>()!!.pointed.value = value }
    
    var Data3: UShort
        get() = this.ptr.rawValue.plus(6).toLong().toCPointer<UShortVar>()!!.pointed.value
        set(value) { this.ptr.rawValue.plus(6).toLong().toCPointer<UShortVar>()!!.pointed.value = value }
    
    fun setData4(index: Int, value: UByte) {
        this.ptr.rawValue.plus(8L + index).toLong().toCPointer<UByteVar>()!!.pointed.value = value
    }
}

// IID_ID2D1Factory = {06152247-6f50-465a-9245-118bfd3b6007}
private fun MemScope.createIID_ID2D1Factory(): CPointer<GUID> {
    val guid = alloc<GUID>()
    guid.Data1 = 0x06152247u
    guid.Data2 = 0x6f50u
    guid.Data3 = 0x465au
    guid.setData4(0, 0x92u)
    guid.setData4(1, 0x45u)
    guid.setData4(2, 0x11u)
    guid.setData4(3, 0x8bu)
    guid.setData4(4, 0xfdu)
    guid.setData4(5, 0x3bu)
    guid.setData4(6, 0x60u)
    guid.setData4(7, 0x07u)
    return guid.ptr
}

// ============================================================
// Constants
// ============================================================
private const val CS_HREDRAW = 0x0002u
private const val CS_VREDRAW = 0x0001u
private const val WS_OVERLAPPEDWINDOW = 0x00CF0000u
private const val CW_USEDEFAULT = 0x80000000.toInt()
private const val SW_SHOW = 5
private const val WM_DESTROY = 0x0002
private const val WM_PAINT = 0x000F
private const val WM_SIZE = 0x0005
private const val IDC_ARROW = 32512
private const val COLOR_WINDOW = 5
private const val D2D1_FACTORY_TYPE_SINGLE_THREADED = 0u

// MAKEINTATOM macro
private fun MAKEINTATOM(atom: Int): COpaquePointer? {
    return atom.toLong().toCPointer()
}

// ============================================================
// Global state
// ============================================================
private var g_hwnd: HWND? = null
private var g_hD2D1: HMODULE? = null
private var g_factory: COpaquePointer? = null
private var g_renderTarget: COpaquePointer? = null
private var g_brush: COpaquePointer? = null

// ============================================================
// COM helper function
// ============================================================
private fun comMethod(obj: COpaquePointer?, index: Int): COpaquePointer? {
    if (obj == null) return null
    // obj is an interface pointer: first member is vtable pointer
    val pVtbl = obj.reinterpret<COpaquePointerVar>().pointed.value ?: return null
    // Get function pointer at vtable[index] (8 bytes per pointer on 64-bit)
    val funcPtrAddr = pVtbl.rawValue.plus((index * 8).toLong())
    return funcPtrAddr.toLong().toCPointer<COpaquePointerVar>()?.pointed?.value
}

// Pack D2D1_POINT_2F (2 floats) into a Long for x64 ABI value passing
private fun packPoint(x: Float, y: Float): Long {
    val xBits = x.toBits().toLong() and 0xFFFFFFFF
    val yBits = y.toBits().toLong() and 0xFFFFFFFF
    return (yBits shl 32) or xBits
}

private fun releaseComObject(obj: COpaquePointer?) {
    if (obj == null) return
    val releaseFunc = comMethod(obj, 2)
        ?.reinterpret<CFunction<(COpaquePointer?) -> UInt>>()
    releaseFunc?.invoke(obj)
}

// ============================================================
// D2D Initialization
// ============================================================
private fun initD2D() {
    memScoped {
        println("[D2D] Loading d2d1.dll...")
        g_hD2D1 = LoadLibraryW("d2d1.dll")
        if (g_hD2D1 == null) {
            println("[D2D] ERROR: Failed to load d2d1.dll")
            return@memScoped
        }
        
        println("[D2D] Getting D2D1CreateFactory...")
        val createFactoryAddr = GetProcAddress(g_hD2D1, "D2D1CreateFactory")
        if (createFactoryAddr == null) {
            println("[D2D] ERROR: Failed to get D2D1CreateFactory")
            return@memScoped
        }
        
        val createFactory = createFactoryAddr
            .reinterpret<CFunction<(UInt, CPointer<GUID>?, COpaquePointer?, CPointer<COpaquePointerVar>?) -> Int>>()
        
        println("[D2D] Creating D2D1 factory...")
        val iid = createIID_ID2D1Factory()
        val factoryVar = alloc<COpaquePointerVar>()
        val hr = createFactory(D2D1_FACTORY_TYPE_SINGLE_THREADED, iid, null, factoryVar.ptr)
        
        if (hr != 0) {
            println("[D2D] ERROR: D2D1CreateFactory failed with HRESULT=0x${hr.toString(16)}")
            return@memScoped
        }
        
        g_factory = factoryVar.value
        println("[D2D] Factory created successfully")
        
        // Get client rect
        val rect = alloc<RECT>()
        GetClientRect(g_hwnd, rect.ptr)
        val width = (rect.right - rect.left).toUInt()
        val height = (rect.bottom - rect.top).toUInt()
        println("[D2D] Client size: ${width} x ${height}")
        
        // Create render target properties
        val rtProps = alloc<D2D1_RENDER_TARGET_PROPERTIES>()
        rtProps.type = 0u
        
        // Create HWND render target properties
        val hwndProps = alloc<D2D1_HWND_RENDER_TARGET_PROPERTIES>()
        hwndProps.hwnd = g_hwnd
        hwndProps.setPixelSize(width, height)
        hwndProps.presentOptions = 0u
        
        // Factory::CreateHwndRenderTarget (vtable #14)
        println("[D2D] Creating HWND render target...")
        val createRtFunc = comMethod(g_factory, 14)
            ?.reinterpret<CFunction<(COpaquePointer?, CPointer<D2D1_RENDER_TARGET_PROPERTIES>?, CPointer<D2D1_HWND_RENDER_TARGET_PROPERTIES>?, CPointer<COpaquePointerVar>?) -> Int>>()
        
        val rtVar = alloc<COpaquePointerVar>()
        val hrRt = createRtFunc?.invoke(g_factory, rtProps.ptr, hwndProps.ptr, rtVar.ptr) ?: -1
        
        if (hrRt != 0) {
            println("[D2D] ERROR: CreateHwndRenderTarget failed with HRESULT=0x${hrRt.toString(16)}")
            return@memScoped
        }
        
        g_renderTarget = rtVar.value
        println("[D2D] Render target created successfully")
        
        // RenderTarget::CreateSolidColorBrush (vtable #8)
        println("[D2D] Creating blue brush...")
        val color = alloc<D2D1_COLOR_F>()
        color.r = 0.0f
        color.g = 0.0f
        color.b = 1.0f
        color.a = 1.0f
        
        val createBrushFunc = comMethod(g_renderTarget, 8)
            ?.reinterpret<CFunction<(COpaquePointer?, CPointer<D2D1_COLOR_F>?, COpaquePointer?, CPointer<COpaquePointerVar>?) -> Int>>()
        
        val brushVar = alloc<COpaquePointerVar>()
        val hrBrush = createBrushFunc?.invoke(g_renderTarget, color.ptr, null, brushVar.ptr) ?: -1
        
        if (hrBrush != 0) {
            println("[D2D] ERROR: CreateSolidColorBrush failed with HRESULT=0x${hrBrush.toString(16)}")
            return@memScoped
        }
        
        g_brush = brushVar.value
        println("[D2D] Brush created successfully")
    }
}

// ============================================================
// Cleanup
// ============================================================
private fun cleanupD2D() {
    releaseComObject(g_brush)
    g_brush = null
    
    releaseComObject(g_renderTarget)
    g_renderTarget = null
    
    releaseComObject(g_factory)
    g_factory = null
    
    if (g_hD2D1 != null) {
        FreeLibrary(g_hD2D1)
        g_hD2D1 = null
    }
}

// ============================================================
// Drawing
// ============================================================
private fun draw() {
    if (g_renderTarget == null) return
    
    println("[draw] Starting draw...")
    
    memScoped {
        // BeginDraw (vtable #48)
        val beginDrawFunc = comMethod(g_renderTarget, 48)
            ?.reinterpret<CFunction<(COpaquePointer?) -> Unit>>()
        beginDrawFunc?.invoke(g_renderTarget)
        println("[draw] BeginDraw called")
        
        // Clear with white (vtable #47)
        val white = alloc<D2D1_COLOR_F>()
        white.r = 1.0f
        white.g = 1.0f
        white.b = 1.0f
        white.a = 1.0f
        println("[draw] Color created, calling Clear...")
        
        val clearFunc = comMethod(g_renderTarget, 47)
            ?.reinterpret<CFunction<(COpaquePointer?, CPointer<D2D1_COLOR_F>?) -> Unit>>()
        clearFunc?.invoke(g_renderTarget, white.ptr)
        println("[draw] Clear called")
        
        // Draw triangle using DrawLine (vtable #15)
        // void DrawLine(D2D1_POINT_2F point0, D2D1_POINT_2F point1, ID2D1Brush* brush, FLOAT strokeWidth, ID2D1StrokeStyle* strokeStyle)
        // On x64, D2D1_POINT_2F (8 bytes = 2 floats) is passed by value in a single register
        // We pack each point as a Long (64-bit integer with float bits)
        val drawLineFunc = comMethod(g_renderTarget, 15)
            ?.reinterpret<CFunction<(COpaquePointer?, Long, Long, COpaquePointer?, Float, COpaquePointer?) -> Unit>>()
        
        println("[draw] DrawLine function: ${drawLineFunc?.rawValue}")
        println("[draw] Brush pointer: ${g_brush?.rawValue}")
        
        if (drawLineFunc != null) {
            // Triangle vertices
            val p1 = packPoint(320.0f, 120.0f)
            val p2 = packPoint(480.0f, 360.0f)
            val p3 = packPoint(160.0f, 360.0f)
            
            println("[draw] Drawing line 1...")
            drawLineFunc.invoke(g_renderTarget, p1, p2, g_brush, 2.0f, null)
            println("[draw] Drawing line 2...")
            drawLineFunc.invoke(g_renderTarget, p2, p3, g_brush, 2.0f, null)
            println("[draw] Drawing line 3...")
            drawLineFunc.invoke(g_renderTarget, p3, p1, g_brush, 2.0f, null)
            println("[draw] All lines drawn")
        }
        
        // EndDraw (vtable #49)
        println("[draw] Calling EndDraw...")
        val endDrawFunc = comMethod(g_renderTarget, 49)
            ?.reinterpret<CFunction<(COpaquePointer?, CPointer<ULongVar>?, CPointer<ULongVar>?) -> Int>>()
        val hrDraw = endDrawFunc?.invoke(g_renderTarget, null, null) ?: -1
        
        if (hrDraw != 0) {
            println("[draw] EndDraw returned: 0x${hrDraw.toString(16)}")
        } else {
            println("[draw] EndDraw succeeded")
        }
        println("[draw] Draw complete")
    }
}

// ============================================================
// Window callback
// ============================================================
private val wndProcCallback = staticCFunction { hwnd: HWND?, msg: UInt, wParam: WPARAM, lParam: LPARAM ->
    when (msg.toInt()) {
        WM_PAINT -> {
            println("[WndProc] WM_PAINT received")
            draw()
            ValidateRect(hwnd, null)
            println("[WndProc] WM_PAINT handled")
            0
        }
        WM_DESTROY -> {
            println("[WndProc] WM_DESTROY received")
            PostQuitMessage(0)
            0
        }
        else -> DefWindowProcW(hwnd, msg, wParam, lParam)
    }
}

// ============================================================
// Main
// ============================================================
fun main() {
    memScoped {
        val hInstance = GetModuleHandleW(null)
        val className = "KotlinD2DWindow"
        val windowName = "Hello, Direct2D(Kotlin/Native) World!"
        
        val wndClass = alloc<WNDCLASSEXW>()
        wndClass.cbSize = sizeOf<WNDCLASSEXW>().toUInt()
        wndClass.style = CS_HREDRAW or CS_VREDRAW
        wndClass.lpfnWndProc = wndProcCallback
        wndClass.hInstance = hInstance
        wndClass.hCursor = LoadCursorW(null, MAKEINTATOM(IDC_ARROW)?.reinterpret())
        wndClass.hbrBackground = (COLOR_WINDOW + 1).toULong().toLong().toCPointer()
        wndClass.lpszClassName = className.wcstr.ptr
        
        if (RegisterClassExW(wndClass.ptr).toInt() == 0) {
            println("[ERROR] RegisterClassEx failed")
            return@memScoped
        }
        
        g_hwnd = CreateWindowExW(
            0u,
            lpClassName = className,
            lpWindowName = windowName,
            dwStyle = WS_OVERLAPPEDWINDOW,
            X = CW_USEDEFAULT,
            Y = CW_USEDEFAULT,
            nWidth = 640,
            nHeight = 480,
            hWndParent = null,
            hMenu = null,
            hInstance = hInstance,
            lpParam = null
        )
        
        if (g_hwnd == null) {
            println("[ERROR] CreateWindowEx failed")
            return@memScoped
        }
        
        println("[MAIN] Window created")
        
        initD2D()
        
        ShowWindow(g_hwnd, SW_SHOW)
        UpdateWindow(g_hwnd)
        
        println("[MAIN] Entering message loop...")
        val msg = alloc<MSG>()
        while (GetMessageW(msg.ptr, null, 0u, 0u) != 0) {
            TranslateMessage(msg.ptr)
            DispatchMessageW(msg.ptr)
        }
        
        println("[MAIN] Message loop ended, cleaning up...")
        cleanupD2D()
    }
}

