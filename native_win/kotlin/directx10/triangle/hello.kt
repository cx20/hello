@file:OptIn(kotlinx.cinterop.ExperimentalForeignApi::class)

import kotlinx.cinterop.*
import platform.windows.*

// ============================================================
// DirectX 10 Constants
// ============================================================
const val D3D10_SDK_VERSION: UInt = 29u
const val D3D10_DRIVER_TYPE_NULL: UInt = 0u
const val D3D10_DRIVER_TYPE_HARDWARE: UInt = 1u
const val D3D10_DRIVER_TYPE_REFERENCE: UInt = 2u
const val D3D10_DRIVER_TYPE_SOFTWARE: UInt = 3u
const val D3D10_DRIVER_TYPE_WARP: UInt = 5u
const val D3D10_CREATE_DEVICE_DEBUG: UInt = 0x00000002u
const val DXGI_FORMAT_R8G8B8A8_UNORM: UInt = 28u
const val DXGI_FORMAT_R32G32B32_FLOAT: UInt = 6u
const val DXGI_FORMAT_R32G32B32A32_FLOAT: UInt = 2u
const val DXGI_USAGE_RENDER_TARGET_OUTPUT: UInt = 0x00000020u
const val D3D10_USAGE_DEFAULT: UInt = 0u
const val D3D10_BIND_VERTEX_BUFFER: UInt = 0x00000001u
const val D3D10_INPUT_PER_VERTEX_DATA: UInt = 0u
const val D3D10_PRIMITIVE_TOPOLOGY_TRIANGLELIST: UInt = 4u
const val D3DCOMPILE_ENABLE_STRICTNESS: UInt = 0x00000002u

// Window constants
const val WM_DESTROY = 0x0002
const val WM_CLOSE = 0x0010
const val WM_QUIT = 0x0012
const val WM_PAINT = 0x000F
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
// GUID Helper
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
    
    fun setData4(b0: UByte, b1: UByte, b2: UByte, b3: UByte, b4: UByte, b5: UByte, b6: UByte, b7: UByte) {
        this.ptr.rawValue.plus(8).toLong().toCPointer<UByteVar>()!!.pointed.value = b0
        this.ptr.rawValue.plus(9).toLong().toCPointer<UByteVar>()!!.pointed.value = b1
        this.ptr.rawValue.plus(10).toLong().toCPointer<UByteVar>()!!.pointed.value = b2
        this.ptr.rawValue.plus(11).toLong().toCPointer<UByteVar>()!!.pointed.value = b3
        this.ptr.rawValue.plus(12).toLong().toCPointer<UByteVar>()!!.pointed.value = b4
        this.ptr.rawValue.plus(13).toLong().toCPointer<UByteVar>()!!.pointed.value = b5
        this.ptr.rawValue.plus(14).toLong().toCPointer<UByteVar>()!!.pointed.value = b6
        this.ptr.rawValue.plus(15).toLong().toCPointer<UByteVar>()!!.pointed.value = b7
    }
}

// IID_ID3D10Texture2D: {9B7E4C04-342C-4106-A19F-4F2704F689F0}
private fun initIID_ID3D10Texture2D(guid: GUID) {
    guid.Data1 = 0x9B7E4C04u
    guid.Data2 = 0x342Cu.toUShort()
    guid.Data3 = 0x4106u.toUShort()
    guid.setData4(0xA1u, 0x9Fu, 0x4Fu, 0x27u, 0x04u, 0xF6u, 0x89u, 0xF0u)
}

// ============================================================
// DirectX 10 Structures
// ============================================================
class DXGI_RATIONAL(rawPtr: NativePtr) : CStructVar(rawPtr) {
    companion object : Type(8, 4)
    
    var Numerator: UInt
        get() = this.ptr.reinterpret<UIntVar>().pointed.value
        set(value) { this.ptr.reinterpret<UIntVar>().pointed.value = value }
    
    var Denominator: UInt
        get() = this.ptr.rawValue.plus(4).toLong().toCPointer<UIntVar>()!!.pointed.value
        set(value) { this.ptr.rawValue.plus(4).toLong().toCPointer<UIntVar>()!!.pointed.value = value }
}

class DXGI_MODE_DESC(rawPtr: NativePtr) : CStructVar(rawPtr) {
    companion object : Type(28, 4)
    
    var Width: UInt
        get() = this.ptr.reinterpret<UIntVar>().pointed.value
        set(value) { this.ptr.reinterpret<UIntVar>().pointed.value = value }
    
    var Height: UInt
        get() = this.ptr.rawValue.plus(4).toLong().toCPointer<UIntVar>()!!.pointed.value
        set(value) { this.ptr.rawValue.plus(4).toLong().toCPointer<UIntVar>()!!.pointed.value = value }
    
    fun setRefreshRate(num: UInt, denom: UInt) {
        this.ptr.rawValue.plus(8).toLong().toCPointer<UIntVar>()!!.pointed.value = num
        this.ptr.rawValue.plus(12).toLong().toCPointer<UIntVar>()!!.pointed.value = denom
    }
    
    var Format: UInt
        get() = this.ptr.rawValue.plus(16).toLong().toCPointer<UIntVar>()!!.pointed.value
        set(value) { this.ptr.rawValue.plus(16).toLong().toCPointer<UIntVar>()!!.pointed.value = value }
}

class DXGI_SAMPLE_DESC(rawPtr: NativePtr) : CStructVar(rawPtr) {
    companion object : Type(8, 4)
    
    var Count: UInt
        get() = this.ptr.reinterpret<UIntVar>().pointed.value
        set(value) { this.ptr.reinterpret<UIntVar>().pointed.value = value }
    
    var Quality: UInt
        get() = this.ptr.rawValue.plus(4).toLong().toCPointer<UIntVar>()!!.pointed.value
        set(value) { this.ptr.rawValue.plus(4).toLong().toCPointer<UIntVar>()!!.pointed.value = value }
}

class DXGI_SWAP_CHAIN_DESC(rawPtr: NativePtr) : CStructVar(rawPtr) {
    companion object : Type(72, 8)  // Padding for x64
    
    fun setBufferDesc(width: UInt, height: UInt, format: UInt) {
        // DXGI_MODE_DESC at offset 0 (28 bytes)
        this.ptr.reinterpret<UIntVar>().pointed.value = width
        this.ptr.rawValue.plus(4).toLong().toCPointer<UIntVar>()!!.pointed.value = height
        // RefreshRate at offset 8
        this.ptr.rawValue.plus(8).toLong().toCPointer<UIntVar>()!!.pointed.value = 60u  // Numerator
        this.ptr.rawValue.plus(12).toLong().toCPointer<UIntVar>()!!.pointed.value = 1u  // Denominator
        this.ptr.rawValue.plus(16).toLong().toCPointer<UIntVar>()!!.pointed.value = format
        this.ptr.rawValue.plus(20).toLong().toCPointer<UIntVar>()!!.pointed.value = 0u  // ScanlineOrdering
        this.ptr.rawValue.plus(24).toLong().toCPointer<UIntVar>()!!.pointed.value = 0u  // Scaling
    }
    
    fun setSampleDesc(count: UInt, quality: UInt) {
        // DXGI_SAMPLE_DESC at offset 28
        this.ptr.rawValue.plus(28).toLong().toCPointer<UIntVar>()!!.pointed.value = count
        this.ptr.rawValue.plus(32).toLong().toCPointer<UIntVar>()!!.pointed.value = quality
    }
    
    var BufferUsage: UInt
        get() = this.ptr.rawValue.plus(36).toLong().toCPointer<UIntVar>()!!.pointed.value
        set(value) { this.ptr.rawValue.plus(36).toLong().toCPointer<UIntVar>()!!.pointed.value = value }
    
    var BufferCount: UInt
        get() = this.ptr.rawValue.plus(40).toLong().toCPointer<UIntVar>()!!.pointed.value
        set(value) { this.ptr.rawValue.plus(40).toLong().toCPointer<UIntVar>()!!.pointed.value = value }
    
    // Padding at 44-47 for x64 alignment
    
    var OutputWindow: COpaquePointer?
        get() = this.ptr.rawValue.plus(48).toLong().toCPointer<COpaquePointerVar>()!!.pointed.value
        set(value) { this.ptr.rawValue.plus(48).toLong().toCPointer<COpaquePointerVar>()!!.pointed.value = value }
    
    var Windowed: Int
        get() = this.ptr.rawValue.plus(56).toLong().toCPointer<IntVar>()!!.pointed.value
        set(value) { this.ptr.rawValue.plus(56).toLong().toCPointer<IntVar>()!!.pointed.value = value }
    
    var SwapEffect: UInt
        get() = this.ptr.rawValue.plus(60).toLong().toCPointer<UIntVar>()!!.pointed.value
        set(value) { this.ptr.rawValue.plus(60).toLong().toCPointer<UIntVar>()!!.pointed.value = value }
    
    var Flags: UInt
        get() = this.ptr.rawValue.plus(64).toLong().toCPointer<UIntVar>()!!.pointed.value
        set(value) { this.ptr.rawValue.plus(64).toLong().toCPointer<UIntVar>()!!.pointed.value = value }
}

class D3D10_VIEWPORT(rawPtr: NativePtr) : CStructVar(rawPtr) {
    companion object : Type(24, 4)
    
    var TopLeftX: Int
        get() = this.ptr.reinterpret<IntVar>().pointed.value
        set(value) { this.ptr.reinterpret<IntVar>().pointed.value = value }
    
    var TopLeftY: Int
        get() = this.ptr.rawValue.plus(4).toLong().toCPointer<IntVar>()!!.pointed.value
        set(value) { this.ptr.rawValue.plus(4).toLong().toCPointer<IntVar>()!!.pointed.value = value }
    
    var Width: UInt
        get() = this.ptr.rawValue.plus(8).toLong().toCPointer<UIntVar>()!!.pointed.value
        set(value) { this.ptr.rawValue.plus(8).toLong().toCPointer<UIntVar>()!!.pointed.value = value }
    
    var Height: UInt
        get() = this.ptr.rawValue.plus(12).toLong().toCPointer<UIntVar>()!!.pointed.value
        set(value) { this.ptr.rawValue.plus(12).toLong().toCPointer<UIntVar>()!!.pointed.value = value }
    
    var MinDepth: Float
        get() = this.ptr.rawValue.plus(16).toLong().toCPointer<FloatVar>()!!.pointed.value
        set(value) { this.ptr.rawValue.plus(16).toLong().toCPointer<FloatVar>()!!.pointed.value = value }
    
    var MaxDepth: Float
        get() = this.ptr.rawValue.plus(20).toLong().toCPointer<FloatVar>()!!.pointed.value
        set(value) { this.ptr.rawValue.plus(20).toLong().toCPointer<FloatVar>()!!.pointed.value = value }
}

class D3D10_BUFFER_DESC(rawPtr: NativePtr) : CStructVar(rawPtr) {
    companion object : Type(24, 4)
    
    var ByteWidth: UInt
        get() = this.ptr.reinterpret<UIntVar>().pointed.value
        set(value) { this.ptr.reinterpret<UIntVar>().pointed.value = value }
    
    var Usage: UInt
        get() = this.ptr.rawValue.plus(4).toLong().toCPointer<UIntVar>()!!.pointed.value
        set(value) { this.ptr.rawValue.plus(4).toLong().toCPointer<UIntVar>()!!.pointed.value = value }
    
    var BindFlags: UInt
        get() = this.ptr.rawValue.plus(8).toLong().toCPointer<UIntVar>()!!.pointed.value
        set(value) { this.ptr.rawValue.plus(8).toLong().toCPointer<UIntVar>()!!.pointed.value = value }
    
    var CPUAccessFlags: UInt
        get() = this.ptr.rawValue.plus(12).toLong().toCPointer<UIntVar>()!!.pointed.value
        set(value) { this.ptr.rawValue.plus(12).toLong().toCPointer<UIntVar>()!!.pointed.value = value }
    
    var MiscFlags: UInt
        get() = this.ptr.rawValue.plus(16).toLong().toCPointer<UIntVar>()!!.pointed.value
        set(value) { this.ptr.rawValue.plus(16).toLong().toCPointer<UIntVar>()!!.pointed.value = value }
    
    var StructureByteStride: UInt
        get() = this.ptr.rawValue.plus(20).toLong().toCPointer<UIntVar>()!!.pointed.value
        set(value) { this.ptr.rawValue.plus(20).toLong().toCPointer<UIntVar>()!!.pointed.value = value }
}

class D3D10_SUBRESOURCE_DATA(rawPtr: NativePtr) : CStructVar(rawPtr) {
    companion object : Type(24, 8)  // Padding for x64
    
    var pSysMem: COpaquePointer?
        get() = this.ptr.reinterpret<COpaquePointerVar>().pointed.value
        set(value) { this.ptr.reinterpret<COpaquePointerVar>().pointed.value = value }
    
    var SysMemPitch: UInt
        get() = this.ptr.rawValue.plus(8).toLong().toCPointer<UIntVar>()!!.pointed.value
        set(value) { this.ptr.rawValue.plus(8).toLong().toCPointer<UIntVar>()!!.pointed.value = value }
    
    var SysMemSlicePitch: UInt
        get() = this.ptr.rawValue.plus(12).toLong().toCPointer<UIntVar>()!!.pointed.value
        set(value) { this.ptr.rawValue.plus(12).toLong().toCPointer<UIntVar>()!!.pointed.value = value }
}

class D3D10_INPUT_ELEMENT_DESC(rawPtr: NativePtr) : CStructVar(rawPtr) {
    companion object : Type(32, 4)  // 32 bytes, 4-byte alignment
    
    var SemanticName: COpaquePointer?
        get() = this.ptr.reinterpret<COpaquePointerVar>().pointed.value
        set(value) { this.ptr.reinterpret<COpaquePointerVar>().pointed.value = value }
    
    var SemanticIndex: UInt
        get() = this.ptr.rawValue.plus(8).toLong().toCPointer<UIntVar>()!!.pointed.value
        set(value) { this.ptr.rawValue.plus(8).toLong().toCPointer<UIntVar>()!!.pointed.value = value }
    
    var Format: UInt
        get() = this.ptr.rawValue.plus(12).toLong().toCPointer<UIntVar>()!!.pointed.value
        set(value) { this.ptr.rawValue.plus(12).toLong().toCPointer<UIntVar>()!!.pointed.value = value }
    
    var InputSlot: UInt
        get() = this.ptr.rawValue.plus(16).toLong().toCPointer<UIntVar>()!!.pointed.value
        set(value) { this.ptr.rawValue.plus(16).toLong().toCPointer<UIntVar>()!!.pointed.value = value }
    
    var AlignedByteOffset: UInt
        get() = this.ptr.rawValue.plus(20).toLong().toCPointer<UIntVar>()!!.pointed.value
        set(value) { this.ptr.rawValue.plus(20).toLong().toCPointer<UIntVar>()!!.pointed.value = value }
    
    var InputSlotClass: UInt
        get() = this.ptr.rawValue.plus(24).toLong().toCPointer<UIntVar>()!!.pointed.value
        set(value) { this.ptr.rawValue.plus(24).toLong().toCPointer<UIntVar>()!!.pointed.value = value }
    
    var InstanceDataStepRate: UInt
        get() = this.ptr.rawValue.plus(28).toLong().toCPointer<UIntVar>()!!.pointed.value
        set(value) { this.ptr.rawValue.plus(28).toLong().toCPointer<UIntVar>()!!.pointed.value = value }
}

class VERTEX(rawPtr: NativePtr) : CStructVar(rawPtr) {
    companion object : Type(28, 4)  // 3 floats (pos) + 4 floats (color) = 28 bytes
    
    var x: Float
        get() = this.ptr.reinterpret<FloatVar>().pointed.value
        set(value) { this.ptr.reinterpret<FloatVar>().pointed.value = value }
    
    var y: Float
        get() = this.ptr.rawValue.plus(4).toLong().toCPointer<FloatVar>()!!.pointed.value
        set(value) { this.ptr.rawValue.plus(4).toLong().toCPointer<FloatVar>()!!.pointed.value = value }
    
    var z: Float
        get() = this.ptr.rawValue.plus(8).toLong().toCPointer<FloatVar>()!!.pointed.value
        set(value) { this.ptr.rawValue.plus(8).toLong().toCPointer<FloatVar>()!!.pointed.value = value }
    
    var r: Float
        get() = this.ptr.rawValue.plus(12).toLong().toCPointer<FloatVar>()!!.pointed.value
        set(value) { this.ptr.rawValue.plus(12).toLong().toCPointer<FloatVar>()!!.pointed.value = value }
    
    var g: Float
        get() = this.ptr.rawValue.plus(16).toLong().toCPointer<FloatVar>()!!.pointed.value
        set(value) { this.ptr.rawValue.plus(16).toLong().toCPointer<FloatVar>()!!.pointed.value = value }
    
    var b: Float
        get() = this.ptr.rawValue.plus(20).toLong().toCPointer<FloatVar>()!!.pointed.value
        set(value) { this.ptr.rawValue.plus(20).toLong().toCPointer<FloatVar>()!!.pointed.value = value }
    
    var a: Float
        get() = this.ptr.rawValue.plus(24).toLong().toCPointer<FloatVar>()!!.pointed.value
        set(value) { this.ptr.rawValue.plus(24).toLong().toCPointer<FloatVar>()!!.pointed.value = value }
}

// ============================================================
// Global variables
// ============================================================
var g_device: COpaquePointer? = null
var g_swap: COpaquePointer? = null
var g_rtv: COpaquePointer? = null
var g_vs: COpaquePointer? = null
var g_ps: COpaquePointer? = null
var g_layout: COpaquePointer? = null
var g_vb: COpaquePointer? = null
var g_hD3D10: HMODULE? = null
var g_hCompiler: HMODULE? = null

// Semantic names (allocated persistently for input layout)
val g_semanticPosition: CPointer<ByteVar> by lazy {
    nativeHeap.allocArray<ByteVar>(9).also { ptr ->
        "POSITION\u0000".encodeToByteArray().forEachIndexed { i, b ->
            ptr[i] = b
        }
    }
}
val g_semanticColor: CPointer<ByteVar> by lazy {
    nativeHeap.allocArray<ByteVar>(6).also { ptr ->
        "COLOR\u0000".encodeToByteArray().forEachIndexed { i, b ->
            ptr[i] = b
        }
    }
}

// ============================================================
// HLSL Shader Source
// ============================================================
val HLSL_SOURCE = """
struct VS_OUTPUT
{
    float4 position : SV_POSITION;
    float4 color : COLOR0;
};

VS_OUTPUT VS(float4 position : POSITION, float4 color : COLOR)
{
    VS_OUTPUT output = (VS_OUTPUT)0;
    output.position = position;
    output.color = color;
    return output;
}

float4 PS(VS_OUTPUT input) : SV_Target
{
    return input.color;
}
"""

// ============================================================
// COM helper function
// ============================================================
private fun toHex(value: Long): String {
    if (value == 0L) return "0"
    val hex = "0123456789abcdef"
    var num = value
    var result = ""
    while (num != 0L) {
        result = hex[(num and 0xF).toInt()] + result
        num = num ushr 4
    }
    return result
}

private fun setupDebugLayer() {
    // D3D11GetDebugInterface to enable additional debugging
    val d3d11Dll = LoadLibraryW("d3d11.dll")
    if (d3d11Dll != null) {
        val debugFunc = GetProcAddress(d3d11Dll, "D3D11CreateDevice")
        if (debugFunc != null) {
            println("[DEBUG] Debug layer enabled for detailed output")
        }
    }
}

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
// Shader Compilation
// ============================================================
private fun compileShader(entry: String, target: String): COpaquePointer? {
    memScoped {
        val codeVar = alloc<COpaquePointerVar>()
        val errVar = alloc<COpaquePointerVar>()
        
        // D3DCompileFromFile function
        val compileFunc = GetProcAddress(g_hCompiler, "D3DCompileFromFile")
            ?.reinterpret<CFunction<(CPointer<UShortVar>?, COpaquePointer?, COpaquePointer?, COpaquePointer?, COpaquePointer?, UInt, UInt, CPointer<COpaquePointerVar>?, CPointer<COpaquePointerVar>?) -> Int>>()
        
        if (compileFunc == null) {
            println("[Shader] ERROR: Failed to get D3DCompileFromFile")
            return null
        }
        
        val fileName = "hello.fx"
        val hr = compileFunc.invoke(
            fileName.wcstr.ptr,
            null,
            null,
            entry.cstr.ptr.reinterpret(),
            target.cstr.ptr.reinterpret(),
            D3DCOMPILE_ENABLE_STRICTNESS,
            0u,
            codeVar.ptr,
            errVar.ptr
        )
        
        if (hr != 0) {
            println("[Shader] ERROR: D3DCompileFromFile failed for $entry: HRESULT=0x${toHex(hr.toLong())}")
            if (errVar.value != null) {
                // Print error message if available
                val errorPtr = blobGetPointer(errVar.value)
                if (errorPtr != null) {
                    println("[Shader] Error: ${errorPtr.reinterpret<ByteVar>().toKString()}")
                }
                releaseComObject(errVar.value)
            }
            return null
        }
        
        if (errVar.value != null) {
            releaseComObject(errVar.value)
        }
        
        return codeVar.value
    }
}

// ID3DBlob::GetBufferPointer (vtable #3)
private fun blobGetPointer(blob: COpaquePointer?): COpaquePointer? {
    val func = comMethod(blob, 3)
        ?.reinterpret<CFunction<(COpaquePointer?) -> COpaquePointer?>>()
    return func?.invoke(blob)
}

// ID3DBlob::GetBufferSize (vtable #4)
private fun blobGetSize(blob: COpaquePointer?): ULong {
    val func = comMethod(blob, 4)
        ?.reinterpret<CFunction<(COpaquePointer?) -> ULong>>()
    return func?.invoke(blob) ?: 0u
}

// ============================================================
// DirectX 10 Initialization
// ============================================================
private fun initD3D(hwnd: HWND?): Boolean {
    println("[initD3D] START")
    memScoped {
        // Load DLLs
        println("[initD3D] Loading d3d10.dll...")
        g_hD3D10 = LoadLibraryW("d3d10.dll")
        if (g_hD3D10 == null) {
            println("[initD3D] ERROR: Failed to load d3d10.dll")
            return false
        }
        println("[initD3D] d3d10.dll loaded successfully")
        
        // Try d3dcompiler_47.dll first, then d3dcompiler_43.dll
        println("[initD3D] Loading d3dcompiler_47.dll...")
        g_hCompiler = LoadLibraryW("d3dcompiler_47.dll")
        if (g_hCompiler == null) {
            println("[initD3D] d3dcompiler_47.dll not found, trying d3dcompiler_43.dll...")
            g_hCompiler = LoadLibraryW("d3dcompiler_43.dll")
        }
        if (g_hCompiler == null) {
            println("[initD3D] ERROR: Failed to load d3dcompiler")
            return false
        }
        println("[initD3D] d3dcompiler loaded successfully")
        
        // Get client area size
        println("[initD3D] Getting window client area...")
        val rc = alloc<RECT>()
        GetClientRect(hwnd, rc.ptr)
        val width = (rc.right - rc.left).toUInt()
        val height = (rc.bottom - rc.top).toUInt()
        println("[initD3D] Client area: ${width}x${height}")
        
        // Setup swap chain description
        println("[initD3D] Setting up swap chain description...")
        val sd = alloc<DXGI_SWAP_CHAIN_DESC>()
        sd.setBufferDesc(width, height, DXGI_FORMAT_R8G8B8A8_UNORM)
        sd.setSampleDesc(1u, 0u)
        sd.BufferUsage = DXGI_USAGE_RENDER_TARGET_OUTPUT
        sd.BufferCount = 1u
        sd.OutputWindow = hwnd?.reinterpret()
        sd.Windowed = 1
        sd.SwapEffect = 0u
        sd.Flags = 0u
        println("[initD3D] Swap chain desc configured")
        
        // D3D10CreateDeviceAndSwapChain
        println("[initD3D] Getting D3D10CreateDeviceAndSwapChain function...")
        val createFunc = GetProcAddress(g_hD3D10, "D3D10CreateDeviceAndSwapChain")
            ?.reinterpret<CFunction<(COpaquePointer?, UInt, HMODULE?, UInt, UInt, CPointer<DXGI_SWAP_CHAIN_DESC>?, CPointer<COpaquePointerVar>?, CPointer<COpaquePointerVar>?) -> Int>>()
        
        if (createFunc == null) {
            println("[initD3D] ERROR: Failed to get D3D10CreateDeviceAndSwapChain")
            return false
        }
        println("[initD3D] D3D10CreateDeviceAndSwapChain function obtained")
        
        val swapVar = alloc<COpaquePointerVar>()
        val deviceVar = alloc<COpaquePointerVar>()
        
        println("[initD3D] Calling D3D10CreateDeviceAndSwapChain with DEBUG flag...")
        val hr = createFunc.invoke(
            null,
            D3D10_DRIVER_TYPE_HARDWARE,
            null,
            D3D10_CREATE_DEVICE_DEBUG,  // Enable debug layer
            D3D10_SDK_VERSION,
            sd.ptr,
            swapVar.ptr,
            deviceVar.ptr
        )
        
        if (hr != 0) {
            println("[initD3D] ERROR: D3D10CreateDeviceAndSwapChain failed: HRESULT=0x${toHex(hr.toLong())}")
            return false
        }
        
        g_device = deviceVar.value
        g_swap = swapVar.value
        
        println("[initD3D] Device and swap chain created successfully")
        println("[initD3D] Device=0x${g_device?.rawValue?.toLong()?.let { toHex(it) } ?: "null"}, SwapChain=0x${g_swap?.rawValue?.toLong()?.let { toHex(it) } ?: "null"}")
        
        // Get back buffer
        println("[initD3D] Creating IID_ID3D10Texture2D...")
        val iid = alloc<GUID>()
        initIID_ID3D10Texture2D(iid)
        println("[initD3D] IID: Data1=0x${toHex(iid.Data1.toLong())}, Data2=0x${toHex(iid.Data2.toLong())}, Data3=0x${toHex(iid.Data3.toLong())}")
        val backbufVar = alloc<COpaquePointerVar>()
        
        // IDXGISwapChain::GetBuffer (vtable #9)
        println("[initD3D] Calling IDXGISwapChain::GetBuffer (vtable #9)...")
        val getBufferFunc = comMethod(g_swap, 9)
            ?.reinterpret<CFunction<(COpaquePointer?, UInt, CPointer<GUID>?, CPointer<COpaquePointerVar>?) -> Int>>()
        if (getBufferFunc == null) {
            println("[initD3D] ERROR: Failed to get GetBuffer function")
            return false
        }
        println("[initD3D] GetBuffer function obtained, calling...")
        val hrBuf = getBufferFunc.invoke(g_swap, 0u, iid.ptr, backbufVar.ptr)
        
        if (hrBuf != 0) {
            println("[initD3D] ERROR: GetBuffer failed: HRESULT=0x${toHex(hrBuf.toLong())}")
            return false
        }
        println("[initD3D] GetBuffer succeeded, backbuffer=0x${backbufVar.value?.rawValue?.toLong()?.let { toHex(it) } ?: "null"}")
        
        // ID3D10Device::CreateRenderTargetView (vtable #76)
        println("[initD3D] Calling ID3D10Device::CreateRenderTargetView (vtable #76)...")
        val createRTVFunc = comMethod(g_device, 76)
            ?.reinterpret<CFunction<(COpaquePointer?, COpaquePointer?, COpaquePointer?, CPointer<COpaquePointerVar>?) -> Int>>()
        val rtvVar = alloc<COpaquePointerVar>()
        val hrRTV = createRTVFunc?.invoke(g_device, backbufVar.value, null, rtvVar.ptr) ?: -1
        
        releaseComObject(backbufVar.value)
        
        if (hrRTV != 0) {
            println("[initD3D] ERROR: CreateRenderTargetView failed: HRESULT=0x${toHex(hrRTV.toLong())}")
            return false
        }
        
        g_rtv = rtvVar.value
        println("[initD3D] Render target view created: 0x${g_rtv?.rawValue?.toLong()?.let { toHex(it) } ?: "null"}")
        
        // OMSetRenderTargets (device vtable #24)
        println("[initD3D] Calling OMSetRenderTargets (device vtable #24)...")
        val omSetFunc = comMethod(g_device, 24)
            ?.reinterpret<CFunction<(COpaquePointer?, UInt, CPointer<COpaquePointerVar>?, COpaquePointer?) -> Unit>>()
        val rtvArray = allocArray<COpaquePointerVar>(1)
        rtvArray[0] = g_rtv
        omSetFunc?.invoke(g_device, 1u, rtvArray, null)
        println("[initD3D] OMSetRenderTargets completed")
        
        // RSSetViewports (device vtable #30)
        println("[initD3D] Calling RSSetViewports (device vtable #30)...")
        val rsSetFunc = comMethod(g_device, 30)
            ?.reinterpret<CFunction<(COpaquePointer?, UInt, CPointer<D3D10_VIEWPORT>?) -> Unit>>()
        val vp = alloc<D3D10_VIEWPORT>()
        vp.TopLeftX = 0
        vp.TopLeftY = 0
        vp.Width = width.toUInt()
        vp.Height = height.toUInt()
        vp.MinDepth = 0.0f
        vp.MaxDepth = 1.0f
        rsSetFunc?.invoke(g_device, 1u, vp.ptr)
        println("[initD3D] RSSetViewports completed")
        
        // Compile shaders
        println("[initD3D] Compiling vertex shader...")
        val vsBlob = compileShader("VS", "vs_4_0")
        if (vsBlob == null) {
            println("[initD3D] ERROR: Failed to compile vertex shader")
            return false
        }
        println("[initD3D] Vertex shader compiled, blob=0x${toHex(vsBlob.rawValue.toLong())}")
        
        println("[initD3D] Compiling pixel shader...")
        val psBlob = compileShader("PS", "ps_4_0")
        if (psBlob == null) {
            println("[initD3D] ERROR: Failed to compile pixel shader")
            releaseComObject(vsBlob)
            return false
        }
        println("[initD3D] Pixel shader compiled, blob=0x${toHex(psBlob.rawValue.toLong())}")
        
        // ID3D10Device::CreateVertexShader (vtable #79)
        println("[initD3D] Calling CreateVertexShader (vtable #79)...")
        val createVSFunc = comMethod(g_device, 79)
            ?.reinterpret<CFunction<(COpaquePointer?, COpaquePointer?, ULong, CPointer<COpaquePointerVar>?) -> Int>>()
        val vsVar = alloc<COpaquePointerVar>()
        val vsPtr = blobGetPointer(vsBlob)
        val vsSize = blobGetSize(vsBlob)
        println("[initD3D] VS blob pointer=0x${vsPtr?.rawValue?.toLong()?.let { toHex(it) } ?: "null"}, size=${vsSize}")
        val hrVS = createVSFunc?.invoke(g_device, vsPtr, vsSize, vsVar.ptr) ?: -1
        
        if (hrVS != 0) {
            println("[initD3D] ERROR: CreateVertexShader failed: HRESULT=0x${toHex(hrVS.toLong())}")
            releaseComObject(vsBlob)
            releaseComObject(psBlob)
            return false
        }
        
        g_vs = vsVar.value
        println("[initD3D] Vertex shader created: 0x${g_vs?.rawValue?.toLong()?.let { toHex(it) } ?: "null"}")
        
        // Create input layout
        println("[initD3D] Creating input layout...")
        
        // Get blob pointers again for input layout
        val vsBlobPtr = blobGetPointer(vsBlob)
        val vsBlobSize = blobGetSize(vsBlob)
        println("[initD3D] VS blob for layout: ptr=0x${vsBlobPtr?.rawValue?.toLong()?.let { toHex(it) } ?: "null"}, size=${vsBlobSize}")
        
        memScoped {
            val layout = allocArray<D3D10_INPUT_ELEMENT_DESC>(2)
            
            // Element 0: POSITION
            layout[0].SemanticName = g_semanticPosition as COpaquePointer?
            layout[0].SemanticIndex = 0u
            layout[0].Format = DXGI_FORMAT_R32G32B32_FLOAT
            layout[0].InputSlot = 0u
            layout[0].AlignedByteOffset = 0u
            layout[0].InputSlotClass = D3D10_INPUT_PER_VERTEX_DATA
            layout[0].InstanceDataStepRate = 0u
            println("[initD3D] Element [0] POSITION: name=${g_semanticPosition as COpaquePointer?}")
            
            // Element 1: COLOR
            layout[1].SemanticName = g_semanticColor as COpaquePointer?
            layout[1].SemanticIndex = 0u
            layout[1].Format = DXGI_FORMAT_R32G32B32A32_FLOAT
            layout[1].InputSlot = 0u
            layout[1].AlignedByteOffset = 12u
            layout[1].InputSlotClass = D3D10_INPUT_PER_VERTEX_DATA
            layout[1].InstanceDataStepRate = 0u
            println("[initD3D] Element [1] COLOR: name=${g_semanticColor as COpaquePointer?}")
            
            println("[initD3D] Input layout desc configured (size=${sizeOf<D3D10_INPUT_ELEMENT_DESC>()})")
        
            // ID3D10Device::CreateInputLayout (vtable #78)
            println("[initD3D] Calling CreateInputLayout (vtable #78)...")
            val createLayoutFunc = comMethod(g_device, 78)
                ?.reinterpret<CFunction<(COpaquePointer?, CPointer<D3D10_INPUT_ELEMENT_DESC>?, UInt, COpaquePointer?, ULong, CPointer<COpaquePointerVar>?) -> Int>>()
            val layoutVar = alloc<COpaquePointerVar>()
            val hrLayout = createLayoutFunc?.invoke(g_device, layout, 2u, vsBlobPtr, vsBlobSize, layoutVar.ptr) ?: -1
            println("[initD3D] CreateInputLayout returned: HRESULT=0x${toHex(hrLayout.toLong())}")
            
            if (hrLayout != 0) {
                println("[initD3D] ERROR: CreateInputLayout failed: HRESULT=0x${toHex(hrLayout.toLong())}")
                releaseComObject(vsBlob)
                releaseComObject(psBlob)
                return false
            }
            
            g_layout = layoutVar.value
            println("[initD3D] Input layout created: 0x${g_layout?.rawValue?.toLong()?.let { toHex(it) } ?: "null"}")
        }
        
        // IASetInputLayout (device vtable #11)
        println("[initD3D] Calling IASetInputLayout (device vtable #11)...")
        val iaLayoutFunc = comMethod(g_device, 11)
            ?.reinterpret<CFunction<(COpaquePointer?, COpaquePointer?) -> Unit>>()
        iaLayoutFunc?.invoke(g_device, g_layout)
        println("[initD3D] IASetInputLayout completed")
        
        // ID3D10Device::CreatePixelShader (vtable #82)
        println("[initD3D] Calling CreatePixelShader (vtable #82)...")
        val createPSFunc = comMethod(g_device, 82)
            ?.reinterpret<CFunction<(COpaquePointer?, COpaquePointer?, ULong, CPointer<COpaquePointerVar>?) -> Int>>()
        val psVar = alloc<COpaquePointerVar>()
        val psPtr = blobGetPointer(psBlob)
        val psSize = blobGetSize(psBlob)
        println("[initD3D] PS blob pointer=0x${psPtr?.rawValue?.toLong()?.let { toHex(it) } ?: "null"}, size=${psSize}")
        val hrPS = createPSFunc?.invoke(g_device, psPtr, psSize, psVar.ptr) ?: -1
        
        if (hrPS != 0) {
            println("[initD3D] ERROR: CreatePixelShader failed: HRESULT=0x${toHex(hrPS.toLong())}")
            releaseComObject(vsBlob)
            releaseComObject(psBlob)
            return false
        }
        
        g_ps = psVar.value
        println("[initD3D] Pixel shader created: 0x${g_ps?.rawValue?.toLong()?.let { toHex(it) } ?: "null"}")
        
        // Release shader blobs
        println("[initD3D] Releasing shader blobs...")
        releaseComObject(vsBlob)
        releaseComObject(psBlob)
        println("[initD3D] Shader blobs released")
        
        // Create vertex buffer
        println("[initD3D] Creating vertex buffer...")
        val vertices = allocArray<VERTEX>(3)
        vertices[0].x = 0.0f; vertices[0].y = 0.5f; vertices[0].z = 0.5f
        vertices[0].r = 1.0f; vertices[0].g = 0.0f; vertices[0].b = 0.0f; vertices[0].a = 1.0f
        
        vertices[1].x = 0.5f; vertices[1].y = -0.5f; vertices[1].z = 0.5f
        vertices[1].r = 0.0f; vertices[1].g = 1.0f; vertices[1].b = 0.0f; vertices[1].a = 1.0f
        
        vertices[2].x = -0.5f; vertices[2].y = -0.5f; vertices[2].z = 0.5f
        vertices[2].r = 0.0f; vertices[2].g = 0.0f; vertices[2].b = 1.0f; vertices[2].a = 1.0f
        println("[initD3D] Vertices initialized")
        
        val bd = alloc<D3D10_BUFFER_DESC>()
        bd.Usage = D3D10_USAGE_DEFAULT
        bd.ByteWidth = (sizeOf<VERTEX>() * 3).toUInt()
        bd.BindFlags = D3D10_BIND_VERTEX_BUFFER
        bd.CPUAccessFlags = 0u
        bd.MiscFlags = 0u
        bd.StructureByteStride = 0u
        
        val initData = alloc<D3D10_SUBRESOURCE_DATA>()
        initData.pSysMem = vertices.reinterpret()
        initData.SysMemPitch = 0u
        initData.SysMemSlicePitch = 0u
        
        // ID3D10Device::CreateBuffer (vtable #71)
        println("[initD3D] Calling CreateBuffer (vtable #71)...")
        val createBufFunc = comMethod(g_device, 71)
            ?.reinterpret<CFunction<(COpaquePointer?, CPointer<D3D10_BUFFER_DESC>?, CPointer<D3D10_SUBRESOURCE_DATA>?, CPointer<COpaquePointerVar>?) -> Int>>()
        val vbVar = alloc<COpaquePointerVar>()
        val hrBuf2 = createBufFunc?.invoke(g_device, bd.ptr, initData.ptr, vbVar.ptr) ?: -1
        
        if (hrBuf2 != 0) {
            println("[initD3D] ERROR: CreateBuffer failed: HRESULT=0x${toHex(hrBuf2.toLong())}")
            return false
        }
        
        g_vb = vbVar.value
        println("[initD3D] Vertex buffer created: 0x${g_vb?.rawValue?.toLong()?.let { toHex(it) } ?: "null"}")
        
        // IASetVertexBuffers (device vtable #12)
        println("[initD3D] Calling IASetVertexBuffers (device vtable #12)...")
        val iaVBFunc = comMethod(g_device, 12)
            ?.reinterpret<CFunction<(COpaquePointer?, UInt, UInt, CPointer<COpaquePointerVar>?, CPointer<UIntVar>?, CPointer<UIntVar>?) -> Unit>>()
        val stride = alloc<UIntVar>()
        stride.value = sizeOf<VERTEX>().toUInt()
        val offset = alloc<UIntVar>()
        offset.value = 0u
        val vbArray = allocArray<COpaquePointerVar>(1)
        vbArray[0] = g_vb
        iaVBFunc?.invoke(g_device, 0u, 1u, vbArray, stride.ptr, offset.ptr)
        println("[initD3D] IASetVertexBuffers completed (stride=${stride.value})")
        
        // IASetPrimitiveTopology (device vtable #18)
        println("[initD3D] Calling IASetPrimitiveTopology (device vtable #18)...")
        val iaTopoFunc = comMethod(g_device, 18)
            ?.reinterpret<CFunction<(COpaquePointer?, UInt) -> Unit>>()
        iaTopoFunc?.invoke(g_device, D3D10_PRIMITIVE_TOPOLOGY_TRIANGLELIST)
        println("[initD3D] IASetPrimitiveTopology completed")
        
        println("[initD3D] Initialization complete - SUCCESS")
    }
    
    return true
}

// ============================================================
// Cleanup
// ============================================================
private fun cleanup() {
    println("[cleanup] START")
    releaseComObject(g_vb)
    g_vb = null
    
    releaseComObject(g_layout)
    g_layout = null
    
    releaseComObject(g_vs)
    g_vs = null
    
    releaseComObject(g_ps)
    g_ps = null
    
    releaseComObject(g_rtv)
    g_rtv = null
    
    releaseComObject(g_swap)
    g_swap = null
    
    releaseComObject(g_device)
    g_device = null
    
    if (g_hCompiler != null) {
        FreeLibrary(g_hCompiler)
        g_hCompiler = null
    }
    
    if (g_hD3D10 != null) {
        FreeLibrary(g_hD3D10)
        g_hD3D10 = null
    }
    
    println("[cleanup] COMPLETE")
}

// ============================================================
// Rendering
// ============================================================
private var renderCount = 0
private fun render() {
    if (g_device == null) return
    
    if (renderCount == 0) {
        println("[render] First frame rendering...")
    }
    
    if (renderCount % 60 == 0 && renderCount > 0) {
        println("[render] Frame count: $renderCount")
    }
    
    memScoped {
        // ClearRenderTargetView (device vtable #35)
        val clearFunc = comMethod(g_device, 35)
            ?.reinterpret<CFunction<(COpaquePointer?, COpaquePointer?, CPointer<FloatVar>?) -> Unit>>()
        val clearColor = allocArray<FloatVar>(4)
        clearColor[0] = 0.0f  // R
        clearColor[1] = 0.125f  // G
        clearColor[2] = 0.3f  // B (blue background)
        clearColor[3] = 1.0f  // A
        clearFunc?.invoke(g_device, g_rtv, clearColor)
        
        if (renderCount == 0) {
            println("[render] ClearRenderTargetView called")
            println("[render] g_vs=0x${g_vs?.rawValue?.toLong()?.let { toHex(it) } ?: "null"}")
            println("[render] g_ps=0x${g_ps?.rawValue?.toLong()?.let { toHex(it) } ?: "null"}")
            println("[render] g_layout=0x${g_layout?.rawValue?.toLong()?.let { toHex(it) } ?: "null"}")
            println("[render] g_vb=0x${g_vb?.rawValue?.toLong()?.let { toHex(it) } ?: "null"}")
        }
        
        // OMSetRenderTargets (device vtable #24) - set every frame
        val omSetFunc = comMethod(g_device, 24)
            ?.reinterpret<CFunction<(COpaquePointer?, UInt, CPointer<COpaquePointerVar>?, COpaquePointer?) -> Unit>>()
        val rtvArray = allocArray<COpaquePointerVar>(1)
        rtvArray[0] = g_rtv
        omSetFunc?.invoke(g_device, 1u, rtvArray, null)
        
        // IASetInputLayout (device vtable #11)
        val iaLayoutFunc = comMethod(g_device, 11)
            ?.reinterpret<CFunction<(COpaquePointer?, COpaquePointer?) -> Unit>>()
        iaLayoutFunc?.invoke(g_device, g_layout)
        
        // IASetVertexBuffers (device vtable #12)
        val iaVBFunc = comMethod(g_device, 12)
            ?.reinterpret<CFunction<(COpaquePointer?, UInt, UInt, CPointer<COpaquePointerVar>?, CPointer<UIntVar>?, CPointer<UIntVar>?) -> Unit>>()
        val stride = alloc<UIntVar>()
        stride.value = 28u  // sizeof(VERTEX)
        val offset = alloc<UIntVar>()
        offset.value = 0u
        val vbArray = allocArray<COpaquePointerVar>(1)
        vbArray[0] = g_vb
        iaVBFunc?.invoke(g_device, 0u, 1u, vbArray, stride.ptr, offset.ptr)
        
        // IASetPrimitiveTopology (device vtable #18)
        val iaTopoFunc = comMethod(g_device, 18)
            ?.reinterpret<CFunction<(COpaquePointer?, UInt) -> Unit>>()
        iaTopoFunc?.invoke(g_device, D3D10_PRIMITIVE_TOPOLOGY_TRIANGLELIST)
        
        // RSSetViewports (device vtable #30) - set every frame
        val vp = alloc<D3D10_VIEWPORT>()
        vp.TopLeftX = 0
        vp.TopLeftY = 0
        vp.Width = 640u
        vp.Height = 480u
        vp.MinDepth = 0.0f
        vp.MaxDepth = 1.0f
        val rsSetViewFunc = comMethod(g_device, 30)
            ?.reinterpret<CFunction<(COpaquePointer?, UInt, CPointer<D3D10_VIEWPORT>?) -> Unit>>()
        rsSetViewFunc?.invoke(g_device, 1u, vp.ptr)
        
        if (renderCount == 0) {
            println("[render] Input Assembly configured")
        }
        
        // VSSetShader (device vtable #7)
        val vsSetFunc = comMethod(g_device, 7)
            ?.reinterpret<CFunction<(COpaquePointer?, COpaquePointer?) -> Unit>>()
        vsSetFunc?.invoke(g_device, g_vs)
        
        if (renderCount == 0) {
            println("[render] VSSetShader called")
        }
        
        // PSSetShader (device vtable #5)
        val psSetFunc = comMethod(g_device, 5)
            ?.reinterpret<CFunction<(COpaquePointer?, COpaquePointer?) -> Unit>>()
        psSetFunc?.invoke(g_device, g_ps)
        
        if (renderCount == 0) {
            println("[render] PSSetShader called")
        }
        
        // Draw (device vtable #9)
        val drawFunc = comMethod(g_device, 9)
            ?.reinterpret<CFunction<(COpaquePointer?, UInt, UInt) -> Unit>>()
        drawFunc?.invoke(g_device, 3u, 0u)
        
        if (renderCount == 0) {
            println("[render] Draw called (3 vertices)")
        }
        
        // Present (swapchain vtable #8)
        val presentFunc = comMethod(g_swap, 8)
            ?.reinterpret<CFunction<(COpaquePointer?, UInt, UInt) -> Int>>()
        presentFunc?.invoke(g_swap, 0u, 0u)
    }
    
    if (renderCount == 0) {
        println("[render] First frame completed")
    }
    renderCount++
}

// ============================================================
// Window callback
// ============================================================
private val wndProcCallback = staticCFunction { hwnd: HWND?, msg: UInt, wParam: WPARAM, lParam: LPARAM ->
    when (msg.toInt()) {
        WM_PAINT -> {
            DefWindowProcW(hwnd, msg, wParam, lParam)
        }
        WM_CLOSE -> {
            println("[WndProc] WM_CLOSE received")
            DefWindowProcW(hwnd, msg, wParam, lParam)
        }
        WM_DESTROY -> {
            println("[WndProc] WM_DESTROY received")
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
    println("[MAIN] DirectX 10 Hello Triangle with Debug Layer")
    setupDebugLayer()
    println("[MAIN] Debug layer setup complete")
    memScoped {
        val hInstance = GetModuleHandleW(null)
        val className = "DirectX10Window"
        val windowName = "Hello, DirectX 10!"
        
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
        
        // Initialize DirectX 10
        if (!initD3D(hwnd)) {
            println("[MAIN] ERROR: initD3D failed")
            return
        }
        
        ShowWindow(hwnd, SW_SHOW)
        UpdateWindow(hwnd)
        
        // Message loop with rendering
        val msg = alloc<MSG>()
        println("[MAIN] Entering message loop...")
        
        var loopCount = 0
        while (true) {
            if (PeekMessageW(msg.ptr, null, 0u, 0u, PM_REMOVE) != 0) {
                if (msg.message == WM_QUIT.toUInt()) {
                    println("[MAIN] WM_QUIT received, exiting loop")
                    break
                }
                TranslateMessage(msg.ptr)
                DispatchMessageW(msg.ptr)
            } else {
                render()
                loopCount++
            }
        }
        
        println("[MAIN] Message loop ended (loop count: $loopCount)")
    }
}

