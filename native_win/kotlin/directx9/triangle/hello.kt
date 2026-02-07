@file:OptIn(kotlinx.cinterop.ExperimentalForeignApi::class)

import kotlinx.cinterop.*
import platform.windows.*

// ============================================================
// DirectX 9 Constants
// ============================================================
const val D3D_SDK_VERSION: UInt = 32u
const val D3DADAPTER_DEFAULT: UInt = 0u
const val D3DDEVTYPE_HAL: UInt = 1u
const val D3DCREATE_SOFTWARE_VERTEXPROCESSING: UInt = 0x00000020u
const val D3DFMT_UNKNOWN: UInt = 0u
const val D3DSWAPEFFECT_DISCARD: UInt = 1u
const val D3DMULTISAMPLE_NONE: UInt = 0u
const val D3DPOOL_DEFAULT: UInt = 0u
const val D3DCLEAR_TARGET: UInt = 0x00000001u
const val D3DPT_TRIANGLELIST: UInt = 4u

// FVF flags
const val D3DFVF_XYZRHW: UInt = 0x004u
const val D3DFVF_DIFFUSE: UInt = 0x040u
val D3DFVF_VERTEX: UInt = D3DFVF_XYZRHW or D3DFVF_DIFFUSE

// Window constants
const val WM_DESTROY = 0x0002
const val WM_QUIT = 0x0012
const val CS_HREDRAW = 0x0002
const val CS_VREDRAW = 0x0001
const val WS_OVERLAPPEDWINDOW = 0x00CF0000u
val CW_USEDEFAULT = 0x80000000u.toInt()
const val SW_SHOW = 5
const val PM_REMOVE = 0x0001u
const val IDC_ARROW = 32512
const val COLOR_WINDOW = 5

// ============================================================
// MAKEINTATOM macro
// ============================================================
fun MAKEINTATOM(atom: Int): COpaquePointer? {
    return atom.toLong().toCPointer()
}

// ============================================================
// D3DCOLOR_XRGB macro
// ============================================================
fun D3DCOLOR_XRGB(r: UInt, g: UInt, b: UInt): UInt {
    return 0xff000000u or (r shl 16) or (g shl 8) or b
}

// ============================================================
// DirectX 9 Structures
// ============================================================
class D3DPRESENT_PARAMETERS(rawPtr: NativePtr) : CStructVar(rawPtr) {
    companion object : Type(64, 8)  // 64 bytes with proper alignment
    
    var BackBufferWidth: UInt
        get() = this.ptr.reinterpret<UIntVar>().pointed.value
        set(value) { this.ptr.reinterpret<UIntVar>().pointed.value = value }
    
    var BackBufferHeight: UInt
        get() = this.ptr.rawValue.plus(4).toLong().toCPointer<UIntVar>()!!.pointed.value
        set(value) { this.ptr.rawValue.plus(4).toLong().toCPointer<UIntVar>()!!.pointed.value = value }
    
    var BackBufferFormat: UInt
        get() = this.ptr.rawValue.plus(8).toLong().toCPointer<UIntVar>()!!.pointed.value
        set(value) { this.ptr.rawValue.plus(8).toLong().toCPointer<UIntVar>()!!.pointed.value = value }
    
    var BackBufferCount: UInt
        get() = this.ptr.rawValue.plus(12).toLong().toCPointer<UIntVar>()!!.pointed.value
        set(value) { this.ptr.rawValue.plus(12).toLong().toCPointer<UIntVar>()!!.pointed.value = value }
    
    var MultiSampleType: UInt
        get() = this.ptr.rawValue.plus(16).toLong().toCPointer<UIntVar>()!!.pointed.value
        set(value) { this.ptr.rawValue.plus(16).toLong().toCPointer<UIntVar>()!!.pointed.value = value }
    
    var MultiSampleQuality: UInt
        get() = this.ptr.rawValue.plus(20).toLong().toCPointer<UIntVar>()!!.pointed.value
        set(value) { this.ptr.rawValue.plus(20).toLong().toCPointer<UIntVar>()!!.pointed.value = value }
    
    var SwapEffect: UInt
        get() = this.ptr.rawValue.plus(24).toLong().toCPointer<UIntVar>()!!.pointed.value
        set(value) { this.ptr.rawValue.plus(24).toLong().toCPointer<UIntVar>()!!.pointed.value = value }
    
    // Note: 4 bytes padding here (28-31) for x64 alignment
    
    var hDeviceWindow: COpaquePointer?
        get() = this.ptr.rawValue.plus(32).toLong().toCPointer<COpaquePointerVar>()!!.pointed.value
        set(value) { this.ptr.rawValue.plus(32).toLong().toCPointer<COpaquePointerVar>()!!.pointed.value = value }
    
    var Windowed: Int
        get() = this.ptr.rawValue.plus(40).toLong().toCPointer<IntVar>()!!.pointed.value
        set(value) { this.ptr.rawValue.plus(40).toLong().toCPointer<IntVar>()!!.pointed.value = value }
    
    var EnableAutoDepthStencil: Int
        get() = this.ptr.rawValue.plus(44).toLong().toCPointer<IntVar>()!!.pointed.value
        set(value) { this.ptr.rawValue.plus(44).toLong().toCPointer<IntVar>()!!.pointed.value = value }
    
    var AutoDepthStencilFormat: UInt
        get() = this.ptr.rawValue.plus(48).toLong().toCPointer<UIntVar>()!!.pointed.value
        set(value) { this.ptr.rawValue.plus(48).toLong().toCPointer<UIntVar>()!!.pointed.value = value }
    
    var Flags: UInt
        get() = this.ptr.rawValue.plus(52).toLong().toCPointer<UIntVar>()!!.pointed.value
        set(value) { this.ptr.rawValue.plus(52).toLong().toCPointer<UIntVar>()!!.pointed.value = value }
    
    var FullScreen_RefreshRateInHz: UInt
        get() = this.ptr.rawValue.plus(56).toLong().toCPointer<UIntVar>()!!.pointed.value
        set(value) { this.ptr.rawValue.plus(56).toLong().toCPointer<UIntVar>()!!.pointed.value = value }
    
    var PresentationInterval: UInt
        get() = this.ptr.rawValue.plus(60).toLong().toCPointer<UIntVar>()!!.pointed.value
        set(value) { this.ptr.rawValue.plus(60).toLong().toCPointer<UIntVar>()!!.pointed.value = value }
}

class VERTEX(rawPtr: NativePtr) : CStructVar(rawPtr) {
    companion object : Type(20, 4)  // 4 floats (16) + 1 DWORD (4) = 20 bytes
    
    var x: Float
        get() = this.ptr.reinterpret<FloatVar>().pointed.value
        set(value) { this.ptr.reinterpret<FloatVar>().pointed.value = value }
    
    var y: Float
        get() = this.ptr.rawValue.plus(4).toLong().toCPointer<FloatVar>()!!.pointed.value
        set(value) { this.ptr.rawValue.plus(4).toLong().toCPointer<FloatVar>()!!.pointed.value = value }
    
    var z: Float
        get() = this.ptr.rawValue.plus(8).toLong().toCPointer<FloatVar>()!!.pointed.value
        set(value) { this.ptr.rawValue.plus(8).toLong().toCPointer<FloatVar>()!!.pointed.value = value }
    
    var rhw: Float
        get() = this.ptr.rawValue.plus(12).toLong().toCPointer<FloatVar>()!!.pointed.value
        set(value) { this.ptr.rawValue.plus(12).toLong().toCPointer<FloatVar>()!!.pointed.value = value }
    
    var color: UInt
        get() = this.ptr.rawValue.plus(16).toLong().toCPointer<UIntVar>()!!.pointed.value
        set(value) { this.ptr.rawValue.plus(16).toLong().toCPointer<UIntVar>()!!.pointed.value = value }
}

// ============================================================
// Global variables
// ============================================================
var g_pD3D: COpaquePointer? = null
var g_pd3dDevice: COpaquePointer? = null
var g_pVB: COpaquePointer? = null
var g_hD3D9: HMODULE? = null

// ============================================================
// COM helper function
// ============================================================
private fun comMethod(obj: COpaquePointer?, index: Int): COpaquePointer? {
    if (obj == null) return null
    val pVtbl = obj.reinterpret<COpaquePointerVar>().pointed.value ?: return null
    val funcPtrAddr = pVtbl.rawValue.plus((index * 8).toLong())
    return funcPtrAddr.toLong().toCPointer<COpaquePointerVar>()?.pointed?.value
}

private fun releaseComObject(obj: COpaquePointer?) {
    if (obj == null) return
    val releaseFunc = comMethod(obj, 2)
        ?.reinterpret<CFunction<(COpaquePointer?) -> UInt>>()
    releaseFunc?.invoke(obj)
}

// ============================================================
// DirectX 9 Initialization
// ============================================================
private fun initD3D(hwnd: HWND?): Boolean {
    memScoped {
        // Load d3d9.dll
        g_hD3D9 = LoadLibraryW("d3d9.dll")
        if (g_hD3D9 == null) {
            println("[D3D9] ERROR: Failed to load d3d9.dll")
            return false
        }
        
        // Get Direct3DCreate9
        val createFunc = GetProcAddress(g_hD3D9, "Direct3DCreate9")
            ?.reinterpret<CFunction<(UInt) -> COpaquePointer?>>()
        
        if (createFunc == null) {
            println("[D3D9] ERROR: Failed to get Direct3DCreate9")
            return false
        }
        
        // Create IDirect3D9
        g_pD3D = createFunc.invoke(D3D_SDK_VERSION)
        if (g_pD3D == null) {
            println("[D3D9] ERROR: Direct3DCreate9 failed")
            return false
        }
        
        println("[D3D9] IDirect3D9 created successfully")
        
        // Set up D3DPRESENT_PARAMETERS - initialize all fields
        val d3dpp = alloc<D3DPRESENT_PARAMETERS>()
        d3dpp.BackBufferWidth = 0u
        d3dpp.BackBufferHeight = 0u
        d3dpp.BackBufferFormat = D3DFMT_UNKNOWN
        d3dpp.BackBufferCount = 0u
        d3dpp.MultiSampleType = D3DMULTISAMPLE_NONE
        d3dpp.MultiSampleQuality = 0u
        d3dpp.SwapEffect = D3DSWAPEFFECT_DISCARD
        d3dpp.hDeviceWindow = null
        d3dpp.Windowed = 1
        d3dpp.EnableAutoDepthStencil = 0
        d3dpp.AutoDepthStencilFormat = D3DFMT_UNKNOWN
        d3dpp.Flags = 0u
        d3dpp.FullScreen_RefreshRateInHz = 0u
        d3dpp.PresentationInterval = 0u
        
        // IDirect3D9::CreateDevice (vtable #16)
        val createDeviceFunc = comMethod(g_pD3D, 16)
            ?.reinterpret<CFunction<(COpaquePointer?, UInt, UInt, HWND?, UInt, CPointer<D3DPRESENT_PARAMETERS>?, CPointer<COpaquePointerVar>?) -> Int>>()
        
        val deviceVar = alloc<COpaquePointerVar>()
        val hr = createDeviceFunc?.invoke(
            g_pD3D,
            D3DADAPTER_DEFAULT,
            D3DDEVTYPE_HAL,
            hwnd,
            D3DCREATE_SOFTWARE_VERTEXPROCESSING,
            d3dpp.ptr,
            deviceVar.ptr
        ) ?: -1
        
        if (hr != 0) {
            println("[D3D9] ERROR: CreateDevice failed with HRESULT=0x${hr.toString(16)}")
            return false
        }
        
        g_pd3dDevice = deviceVar.value
        println("[D3D9] IDirect3DDevice9 created successfully")
    }
    
    return true
}

private fun initVB(): Boolean {
    memScoped {
        // Define triangle vertices
        val vertices = allocArray<VERTEX>(3)
        vertices[0].x = 320.0f
        vertices[0].y = 100.0f
        vertices[0].z = 0.0f
        vertices[0].rhw = 1.0f
        vertices[0].color = D3DCOLOR_XRGB(255u, 0u, 0u)  // Red
        
        vertices[1].x = 520.0f
        vertices[1].y = 380.0f
        vertices[1].z = 0.0f
        vertices[1].rhw = 1.0f
        vertices[1].color = D3DCOLOR_XRGB(0u, 255u, 0u)  // Green
        
        vertices[2].x = 120.0f
        vertices[2].y = 380.0f
        vertices[2].z = 0.0f
        vertices[2].rhw = 1.0f
        vertices[2].color = D3DCOLOR_XRGB(0u, 0u, 255u)  // Blue
        
        // IDirect3DDevice9::CreateVertexBuffer (vtable #26)
        val createVBFunc = comMethod(g_pd3dDevice, 26)
            ?.reinterpret<CFunction<(COpaquePointer?, UInt, UInt, UInt, UInt, CPointer<COpaquePointerVar>?, COpaquePointer?) -> Int>>()
        
        val vbVar = alloc<COpaquePointerVar>()
        val hr = createVBFunc?.invoke(
            g_pd3dDevice,
            (3 * sizeOf<VERTEX>()).toUInt(),
            0u,
            D3DFVF_VERTEX,
            D3DPOOL_DEFAULT,
            vbVar.ptr,
            null
        ) ?: -1
        
        if (hr != 0) {
            println("[D3D9] ERROR: CreateVertexBuffer failed with HRESULT=0x${hr.toString(16)}")
            return false
        }
        
        g_pVB = vbVar.value
        println("[D3D9] Vertex buffer created successfully")
        
        // IDirect3DVertexBuffer9::Lock (vtable #11)
        val lockFunc = comMethod(g_pVB, 11)
            ?.reinterpret<CFunction<(COpaquePointer?, UInt, UInt, CPointer<COpaquePointerVar>?, UInt) -> Int>>()
        
        val pVerticesVar = alloc<COpaquePointerVar>()
        val hrLock = lockFunc?.invoke(
            g_pVB,
            0u,
            (3 * sizeOf<VERTEX>()).toUInt(),
            pVerticesVar.ptr,
            0u
        ) ?: -1
        
        if (hrLock != 0) {
            println("[D3D9] ERROR: Lock failed with HRESULT=0x${hrLock.toString(16)}")
            return false
        }
        
        // Copy vertex data
        val pVertices = pVerticesVar.value?.reinterpret<VERTEX>()
        if (pVertices != null) {
            for (i in 0 until 3) {
                pVertices[i].x = vertices[i].x
                pVertices[i].y = vertices[i].y
                pVertices[i].z = vertices[i].z
                pVertices[i].rhw = vertices[i].rhw
                pVertices[i].color = vertices[i].color
            }
        }
        
        // IDirect3DVertexBuffer9::Unlock (vtable #12)
        val unlockFunc = comMethod(g_pVB, 12)
            ?.reinterpret<CFunction<(COpaquePointer?) -> Int>>()
        unlockFunc?.invoke(g_pVB)
        
        println("[D3D9] Vertex buffer initialized")
    }
    
    return true
}

// ============================================================
// Cleanup
// ============================================================
private fun cleanup() {
    releaseComObject(g_pVB)
    g_pVB = null
    
    releaseComObject(g_pd3dDevice)
    g_pd3dDevice = null
    
    releaseComObject(g_pD3D)
    g_pD3D = null
    
    if (g_hD3D9 != null) {
        FreeLibrary(g_hD3D9)
        g_hD3D9 = null
    }
}

// ============================================================
// Rendering
// ============================================================
private fun render() {
    if (g_pd3dDevice == null) return
    
    // IDirect3DDevice9::Clear (vtable #43)
    val clearFunc = comMethod(g_pd3dDevice, 43)
        ?.reinterpret<CFunction<(COpaquePointer?, UInt, COpaquePointer?, UInt, UInt, Float, UInt) -> Int>>()
    clearFunc?.invoke(g_pd3dDevice, 0u, null, D3DCLEAR_TARGET, D3DCOLOR_XRGB(255u, 255u, 255u), 1.0f, 0u)
    
    // IDirect3DDevice9::BeginScene (vtable #41)
    val beginSceneFunc = comMethod(g_pd3dDevice, 41)
        ?.reinterpret<CFunction<(COpaquePointer?) -> Int>>()
    val hr = beginSceneFunc?.invoke(g_pd3dDevice) ?: -1
    
    if (hr == 0) {
        // IDirect3DDevice9::SetStreamSource (vtable #100)
        val setStreamFunc = comMethod(g_pd3dDevice, 100)
            ?.reinterpret<CFunction<(COpaquePointer?, UInt, COpaquePointer?, UInt, UInt) -> Int>>()
        setStreamFunc?.invoke(g_pd3dDevice, 0u, g_pVB, 0u, sizeOf<VERTEX>().toUInt())
        
        // IDirect3DDevice9::SetFVF (vtable #89)
        val setFVFFunc = comMethod(g_pd3dDevice, 89)
            ?.reinterpret<CFunction<(COpaquePointer?, UInt) -> Int>>()
        setFVFFunc?.invoke(g_pd3dDevice, D3DFVF_VERTEX)
        
        // IDirect3DDevice9::DrawPrimitive (vtable #81)
        val drawPrimFunc = comMethod(g_pd3dDevice, 81)
            ?.reinterpret<CFunction<(COpaquePointer?, UInt, UInt, UInt) -> Int>>()
        drawPrimFunc?.invoke(g_pd3dDevice, D3DPT_TRIANGLELIST, 0u, 1u)
        
        // IDirect3DDevice9::EndScene (vtable #42)
        val endSceneFunc = comMethod(g_pd3dDevice, 42)
            ?.reinterpret<CFunction<(COpaquePointer?) -> Int>>()
        endSceneFunc?.invoke(g_pd3dDevice)
    }
    
    // IDirect3DDevice9::Present (vtable #17)
    val presentFunc = comMethod(g_pd3dDevice, 17)
        ?.reinterpret<CFunction<(COpaquePointer?, COpaquePointer?, COpaquePointer?, HWND?, COpaquePointer?) -> Int>>()
    presentFunc?.invoke(g_pd3dDevice, null, null, null, null)
}

// ============================================================
// Window callback
// ============================================================
private val wndProcCallback = staticCFunction { hwnd: HWND?, msg: UInt, wParam: WPARAM, lParam: LPARAM ->
    when (msg.toInt()) {
        WM_DESTROY -> {
            cleanup()
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
        val className = "DirectX9Window"
        val windowName = "Hello, DirectX 9!"
        
        // Register window class
        val wc = alloc<WNDCLASSEXW>()
        wc.cbSize = sizeOf<WNDCLASSEXW>().toUInt()
        wc.style = (CS_HREDRAW or CS_VREDRAW).toUInt()
        wc.lpfnWndProc = wndProcCallback
        wc.cbClsExtra = 0
        wc.cbWndExtra = 0
        wc.hInstance = hInstance
        wc.hIcon = LoadIconW(null, MAKEINTATOM(IDC_ARROW)?.reinterpret())
        wc.hCursor = LoadCursorW(null, MAKEINTATOM(IDC_ARROW)?.reinterpret())
        wc.hbrBackground = (COLOR_WINDOW + 1).toLong().toCPointer<HBRUSH__>()
        wc.lpszMenuName = null
        wc.lpszClassName = className.wcstr.ptr
        wc.hIconSm = null
        
        RegisterClassExW(wc.ptr)
        
        // Create window
        val hwnd = CreateWindowExW(
            dwExStyle = 0u,
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
        
        if (hwnd == null) {
            println("[MAIN] ERROR: CreateWindowExW failed")
            return
        }
        
        println("[MAIN] Window created")
        
        // Initialize DirectX 9
        if (!initD3D(hwnd)) {
            println("[MAIN] ERROR: initD3D failed")
            return
        }
        
        if (!initVB()) {
            println("[MAIN] ERROR: initVB failed")
            return
        }
        
        ShowWindow(hwnd, SW_SHOW)
        UpdateWindow(hwnd)
        
        // Message loop with rendering
        val msg = alloc<MSG>()
        println("[MAIN] Entering message loop...")
        
        while (true) {
            if (PeekMessageW(msg.ptr, null, 0u, 0u, PM_REMOVE) != 0) {
                if (msg.message == WM_QUIT.toUInt()) {
                    break
                }
                TranslateMessage(msg.ptr)
                DispatchMessageW(msg.ptr)
            } else {
                render()
            }
        }
        
        println("[MAIN] Message loop ended")
    }
}

