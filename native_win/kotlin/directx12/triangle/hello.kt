@file:OptIn(kotlinx.cinterop.ExperimentalForeignApi::class)

import kotlinx.cinterop.*
import platform.windows.*
import platform.posix.memcpy
import platform.posix.memset

// ============================================================
// DirectX 12 Constants
// ============================================================
const val FRAME_COUNT = 2u

// DXGI Constants
const val DXGI_FORMAT_R8G8B8A8_UNORM: UInt = 28u
const val DXGI_FORMAT_R32G32B32_FLOAT: UInt = 6u
const val DXGI_FORMAT_R32G32B32A32_FLOAT: UInt = 2u
const val DXGI_USAGE_RENDER_TARGET_OUTPUT: UInt = 0x00000020u
const val DXGI_SWAP_EFFECT_FLIP_DISCARD: UInt = 4u

// D3D12 Constants
const val D3D_FEATURE_LEVEL_11_0: UInt = 0xB000u
const val D3D12_COMMAND_QUEUE_FLAG_NONE: UInt = 0u
const val D3D12_COMMAND_LIST_TYPE_DIRECT: UInt = 0u
const val D3D12_DESCRIPTOR_HEAP_TYPE_RTV: UInt = 2u
const val D3D12_DESCRIPTOR_HEAP_FLAG_NONE: UInt = 0u
const val D3D12_INPUT_CLASSIFICATION_PER_VERTEX_DATA: UInt = 0u
const val D3D12_RESOURCE_STATE_RENDER_TARGET: UInt = 0x4u
const val D3D12_RESOURCE_STATE_PRESENT: UInt = 0u
const val D3D12_RESOURCE_STATE_GENERIC_READ: UInt = 0x1u
const val D3D12_RESOURCE_BARRIER_TYPE_TRANSITION: UInt = 0u
const val D3D12_RESOURCE_BARRIER_FLAG_NONE: UInt = 0u
const val D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES: UInt = 0xFFFFFFFFu
const val D3D12_HEAP_TYPE_DEFAULT: UInt = 1u
const val D3D12_HEAP_TYPE_UPLOAD: UInt = 2u
const val D3D12_HEAP_FLAG_NONE: UInt = 0u
const val D3D12_RESOURCE_DIMENSION_BUFFER: UInt = 1u
const val D3D12_TEXTURE_LAYOUT_ROW_MAJOR: UInt = 1u
const val D3D12_RESOURCE_FLAG_NONE: UInt = 0u
const val D3D12_PRIMITIVE_TOPOLOGY_TYPE_TRIANGLE: UInt = 3u
const val D3D_PRIMITIVE_TOPOLOGY_TRIANGLELIST: UInt = 4u
const val D3D12_FILL_MODE_SOLID: UInt = 3u
const val D3D12_CULL_MODE_NONE: UInt = 1u
const val D3D12_ROOT_SIGNATURE_FLAG_ALLOW_INPUT_ASSEMBLER_INPUT_LAYOUT: UInt = 0x1u
const val D3D12_ROOT_SIGNATURE_VERSION_1: UInt = 1u
const val D3D12_COMMAND_LIST_FLAG_NONE: UInt = 0u
const val D3D12_COLOR_WRITE_ENABLE_ALL: UByte = 0x0Fu
const val D3D12_BLEND_ONE: UInt = 2u
const val D3D12_BLEND_ZERO: UInt = 1u
const val D3D12_BLEND_OP_ADD: UInt = 1u
const val D3D12_LOGIC_OP_NOOP: UInt = 5u
const val D3D12_COMPARISON_FUNC_ALWAYS: UInt = 8u
const val D3D12_DEPTH_WRITE_MASK_ZERO: UInt = 0u
const val D3DCOMPILE_ENABLE_STRICTNESS: UInt = 0x00000002u
const val DXGI_SAMPLE_DESC_COUNT: UInt = 1u
const val DXGI_SAMPLE_DESC_QUALITY: UInt = 0u

// Window Constants
const val WM_DESTROY = 0x0002
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
// Global Variables
// ============================================================
var g_hD3D12: HMODULE? = null
var g_hDXGI: HMODULE? = null
var g_hCompiler: HMODULE? = null
var g_device: COpaquePointer? = null
var g_commandQueue: COpaquePointer? = null
var g_swapChain: COpaquePointer? = null
var g_commandAllocator: COpaquePointer? = null
var g_commandList: COpaquePointer? = null
var g_rootSignature: COpaquePointer? = null
var g_pipelineState: COpaquePointer? = null
var g_rtvHeap: COpaquePointer? = null
var g_fence: COpaquePointer? = null
var g_vertexBuffer: COpaquePointer? = null
var g_fenceEvent: HANDLE? = null
var g_fenceValue: ULong = 1u
var g_frameIndex: UInt = 0u
var g_rtvDescriptorSize: UInt = 0u
var g_rtvHeapStartValue: ULong = 0u // D3D12_CPU_DESCRIPTOR_HANDLE.ptr (as integer)
var g_renderTargets = arrayOfNulls<COpaquePointer>(2)
var g_vertexBufferViewPtr: CPointer<D3D12_VERTEX_BUFFER_VIEW>? = null

// ============================================================
// MAKEINTATOM macro
// ============================================================
fun MAKEINTATOM(atom: Int): COpaquePointer? {
    return atom.toLong().toCPointer()
}

// ============================================================
// Hex Conversion Helper
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

// ============================================================
// COM Helper
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

private fun queryInterface(obj: COpaquePointer?, iid: GUID): COpaquePointer? {
    if (obj == null) return null
    val qiFunc = comMethod(obj, 0)
        ?.reinterpret<CFunction<(COpaquePointer?, CPointer<GUID>?, CPointer<COpaquePointerVar>?) -> Int>>()
        ?: return null
    return memScoped {
        val outVar = alloc<COpaquePointerVar>()
        val hr = qiFunc.invoke(obj, iid.ptr, outVar.ptr)
        if (hr != 0) {
            debugOutput("[QueryInterface] ERROR: HRESULT=0x${toHex(hr.toLong())}")
            null
        } else {
            outVar.value
        }
    }
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

// IID_ID3D12Device: {189819f1-1db6-4b57-be54-1821339b85f7}
private fun initIID_ID3D12Device(guid: GUID) {
    guid.Data1 = 0x189819f1u
    guid.Data2 = 0x1db6u.toUShort()
    guid.Data3 = 0x4b57u.toUShort()
    guid.setData4(0xbeu, 0x54u, 0x18u, 0x21u, 0x33u, 0x9bu, 0x85u, 0xf7u)
}

// IID_ID3D12Debug: {344488b7-6846-474b-b989-f027448245e0}
private fun initIID_ID3D12Debug(guid: GUID) {
    guid.Data1 = 0x344488b7u
    guid.Data2 = 0x6846u.toUShort()
    guid.Data3 = 0x474bu.toUShort()
    guid.setData4(0xb9u, 0x89u, 0xf0u, 0x27u, 0x44u, 0x82u, 0x45u, 0xe0u)
}

// IID_ID3D12CommandQueue: {0ec870a6-5d7e-4c22-8cfc-5baae07616ed}
private fun initIID_ID3D12CommandQueue(guid: GUID) {
    guid.Data1 = 0x0ec870a6u
    guid.Data2 = 0x5d7eu.toUShort()
    guid.Data3 = 0x4c22u.toUShort()
    guid.setData4(0x8cu, 0xfcu, 0x5bu, 0xaau, 0xe0u, 0x76u, 0x16u, 0xedu)
}

// IID_IDXGIFactory4: {1bc6ea02-ef36-464f-bf0c-21ca39e5168a}
private fun initIID_IDXGIFactory4(guid: GUID) {
    guid.Data1 = 0x1bc6ea02u
    guid.Data2 = 0xef36u.toUShort()
    guid.Data3 = 0x464fu.toUShort()
    guid.setData4(0xbfu, 0x0cu, 0x21u, 0xcau, 0x39u, 0xe5u, 0x16u, 0x8au)
}

// IID_IDXGISwapChain3: {94d99bdb-f1f8-4ab0-b236-7da0170edab1}
private fun initIID_IDXGISwapChain3(guid: GUID) {
    guid.Data1 = 0x94d99bdbu
    guid.Data2 = 0xf1f8u.toUShort()
    guid.Data3 = 0x4ab0u.toUShort()
    guid.setData4(0xb2u, 0x36u, 0x7du, 0xa0u, 0x17u, 0x0eu, 0xdau, 0xb1u)
}

// IID_ID3D12CommandAllocator: {6102dee4-af59-4b09-b999-b44d73f09b24}
private fun initIID_ID3D12CommandAllocator(guid: GUID) {
    guid.Data1 = 0x6102dee4u
    guid.Data2 = 0xaf59u.toUShort()
    guid.Data3 = 0x4b09u.toUShort()
    guid.setData4(0xb9u, 0x99u, 0xb4u, 0x4du, 0x73u, 0xf0u, 0x9bu, 0x24u)
}

// IID_ID3D12GraphicsCommandList: {5b160d0f-ac1b-4185-8ba8-b3ae42a5a455}
private fun initIID_ID3D12GraphicsCommandList(guid: GUID) {
    guid.Data1 = 0x5b160d0fu
    guid.Data2 = 0xac1bu.toUShort()
    guid.Data3 = 0x4185u.toUShort()
    guid.setData4(0x8bu, 0xa8u, 0xb3u, 0xaeu, 0x42u, 0xa5u, 0xa4u, 0x55u)
}

// IID_ID3D12RootSignature: {c54a6b66-72df-4ee8-8be5-a946a1429214}
private fun initIID_ID3D12RootSignature(guid: GUID) {
    guid.Data1 = 0xc54a6b66u
    guid.Data2 = 0x72dfu.toUShort()
    guid.Data3 = 0x4ee8u.toUShort()
    guid.setData4(0x8bu, 0xe5u, 0xa9u, 0x46u, 0xa1u, 0x42u, 0x92u, 0x14u)
}

// IID_ID3D12PipelineState: {765a30f3-f624-4c6f-a828-ace948622445}
private fun initIID_ID3D12PipelineState(guid: GUID) {
    guid.Data1 = 0x765a30f3u
    guid.Data2 = 0xf624u.toUShort()
    guid.Data3 = 0x4c6fu.toUShort()
    guid.setData4(0xa8u, 0x28u, 0xacu, 0xe9u, 0x48u, 0x62u, 0x24u, 0x45u)
}

// IID_ID3D12Resource: {696442be-a72e-4059-bc79-5b5c98040fad}
private fun initIID_ID3D12Resource(guid: GUID) {
    guid.Data1 = 0x696442beu
    guid.Data2 = 0xa72eu.toUShort()
    guid.Data3 = 0x4059u.toUShort()
    guid.setData4(0xbcu, 0x79u, 0x5bu, 0x5cu, 0x98u, 0x04u, 0x0fu, 0xadu)
}

// IID_ID3D12Fence: {0a753dcf-c4d8-4b91-adf6-be5a60d95a76}
private fun initIID_ID3D12Fence(guid: GUID) {
    guid.Data1 = 0x0a753dcfu
    guid.Data2 = 0xc4d8u.toUShort()
    guid.Data3 = 0x4b91u.toUShort()
    guid.setData4(0xadu, 0xf6u, 0xbeu, 0x5au, 0x60u, 0xd9u, 0x5au, 0x76u)
}

// IID_ID3D12DescriptorHeap: {8efb471d-616c-4f49-90f7-127bb763fa51}
private fun initIID_ID3D12DescriptorHeap(guid: GUID) {
    guid.Data1 = 0x8efb471du
    guid.Data2 = 0x616cu.toUShort()
    guid.Data3 = 0x4f49u.toUShort()
    guid.setData4(0x90u, 0xf7u, 0x12u, 0x7bu, 0xb7u, 0x63u, 0xfau, 0x51u)
}

// ============================================================
// Debug Output Helper
// ============================================================
private fun debugOutput(message: String) {
    println(message)
    OutputDebugStringW(message)
}

// ============================================================
// HLSL Shader Code
// ============================================================
private val g_shaderCode = """
struct VS_OUTPUT {
    float4 Position : SV_POSITION;
    float4 Color : COLOR;
};

VS_OUTPUT VS(float3 position : POSITION, float4 color : COLOR) {
    VS_OUTPUT output;
    output.Position = float4(position, 1.0f);
    output.Color = color;
    return output;
}

float4 PS(VS_OUTPUT input) : SV_TARGET {
    return input.Color;
}
""".trimIndent()

// ============================================================
// Shader Compilation Helper
// ============================================================
private fun compileShader(entry: String, target: String): COpaquePointer? {
    if (g_hCompiler == null) return null
    
    val compileFunc = GetProcAddress(g_hCompiler, "D3DCompile")
        ?.reinterpret<CFunction<(COpaquePointer?, ULong, COpaquePointer?, COpaquePointer?, COpaquePointer?, COpaquePointer?, COpaquePointer?, UInt, UInt, CPointer<COpaquePointerVar>?, CPointer<COpaquePointerVar>?) -> Int>>()
    
    if (compileFunc == null) {
        debugOutput("[Shader] ERROR: D3DCompile function not found")
        return null
    }
    
    memScoped {
        val codeVar = alloc<COpaquePointerVar>()
        val errVar = alloc<COpaquePointerVar>()
        
        val hr = g_shaderCode.cstr.getPointer(this).let { codePtr ->
            entry.cstr.getPointer(this).let { entryPtr ->
                target.cstr.getPointer(this).let { targetPtr ->
                    compileFunc.invoke(
                        codePtr as COpaquePointer,
                        g_shaderCode.length.toULong(),
                        null,
                        null,
                        null,
                        entryPtr as COpaquePointer,
                        targetPtr as COpaquePointer,
                        D3DCOMPILE_ENABLE_STRICTNESS,
                        0u,
                        codeVar.ptr,
                        errVar.ptr
                    )
                }
            }
        }
        
        if (hr != 0) {
            debugOutput("[Shader] ERROR: D3DCompile failed for $entry: HRESULT=0x${toHex(hr.toLong())}")
            if (errVar.value != null) {
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
// Vertex Structure
// ============================================================
class VERTEX(rawPtr: NativePtr) : CStructVar(rawPtr) {
    companion object : Type(28, 4)
    
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
// DirectX 12 Structures
// ============================================================
class D3D12_COMMAND_QUEUE_DESC(rawPtr: NativePtr) : CStructVar(rawPtr) {
    companion object : Type(16, 4)
    
    var Type: UInt
        get() = this.ptr.reinterpret<UIntVar>().pointed.value
        set(value) { this.ptr.reinterpret<UIntVar>().pointed.value = value }
    
    var Priority: Int
        get() = this.ptr.rawValue.plus(4).toLong().toCPointer<IntVar>()!!.pointed.value
        set(value) { this.ptr.rawValue.plus(4).toLong().toCPointer<IntVar>()!!.pointed.value = value }
    
    var Flags: UInt
        get() = this.ptr.rawValue.plus(8).toLong().toCPointer<UIntVar>()!!.pointed.value
        set(value) { this.ptr.rawValue.plus(8).toLong().toCPointer<UIntVar>()!!.pointed.value = value }
    
    var NodeMask: UInt
        get() = this.ptr.rawValue.plus(12).toLong().toCPointer<UIntVar>()!!.pointed.value
        set(value) { this.ptr.rawValue.plus(12).toLong().toCPointer<UIntVar>()!!.pointed.value = value }
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

class DXGI_SWAP_CHAIN_DESC1(rawPtr: NativePtr) : CStructVar(rawPtr) {
    companion object : Type(48, 8)
    
    var Width: UInt
        get() = this.ptr.reinterpret<UIntVar>().pointed.value
        set(value) { this.ptr.reinterpret<UIntVar>().pointed.value = value }
    
    var Height: UInt
        get() = this.ptr.rawValue.plus(4).toLong().toCPointer<UIntVar>()!!.pointed.value
        set(value) { this.ptr.rawValue.plus(4).toLong().toCPointer<UIntVar>()!!.pointed.value = value }
    
    var Format: UInt
        get() = this.ptr.rawValue.plus(8).toLong().toCPointer<UIntVar>()!!.pointed.value
        set(value) { this.ptr.rawValue.plus(8).toLong().toCPointer<UIntVar>()!!.pointed.value = value }
    
    var Stereo: Int
        get() = this.ptr.rawValue.plus(12).toLong().toCPointer<IntVar>()!!.pointed.value
        set(value) { this.ptr.rawValue.plus(12).toLong().toCPointer<IntVar>()!!.pointed.value = value }
    
    fun setSampleDesc(count: UInt, quality: UInt) {
        this.ptr.rawValue.plus(16).toLong().toCPointer<UIntVar>()!!.pointed.value = count
        this.ptr.rawValue.plus(20).toLong().toCPointer<UIntVar>()!!.pointed.value = quality
    }
    
    var BufferUsage: UInt
        get() = this.ptr.rawValue.plus(24).toLong().toCPointer<UIntVar>()!!.pointed.value
        set(value) { this.ptr.rawValue.plus(24).toLong().toCPointer<UIntVar>()!!.pointed.value = value }
    
    var BufferCount: UInt
        get() = this.ptr.rawValue.plus(28).toLong().toCPointer<UIntVar>()!!.pointed.value
        set(value) { this.ptr.rawValue.plus(28).toLong().toCPointer<UIntVar>()!!.pointed.value = value }
    
    var Scaling: UInt
        get() = this.ptr.rawValue.plus(32).toLong().toCPointer<UIntVar>()!!.pointed.value
        set(value) { this.ptr.rawValue.plus(32).toLong().toCPointer<UIntVar>()!!.pointed.value = value }
    
    var SwapEffect: UInt
        get() = this.ptr.rawValue.plus(36).toLong().toCPointer<UIntVar>()!!.pointed.value
        set(value) { this.ptr.rawValue.plus(36).toLong().toCPointer<UIntVar>()!!.pointed.value = value }
    
    var AlphaMode: UInt
        get() = this.ptr.rawValue.plus(40).toLong().toCPointer<UIntVar>()!!.pointed.value
        set(value) { this.ptr.rawValue.plus(40).toLong().toCPointer<UIntVar>()!!.pointed.value = value }
    
    var Flags: UInt
        get() = this.ptr.rawValue.plus(44).toLong().toCPointer<UIntVar>()!!.pointed.value
        set(value) { this.ptr.rawValue.plus(44).toLong().toCPointer<UIntVar>()!!.pointed.value = value }
}

class D3D12_DESCRIPTOR_HEAP_DESC(rawPtr: NativePtr) : CStructVar(rawPtr) {
    companion object : Type(16, 4)
    
    var Type: UInt
        get() = this.ptr.reinterpret<UIntVar>().pointed.value
        set(value) { this.ptr.reinterpret<UIntVar>().pointed.value = value }
    
    var NumDescriptors: UInt
        get() = interpretCPointer<UIntVar>(this.ptr.rawValue + 4)!!.pointed.value
        set(value) { interpretCPointer<UIntVar>(this.ptr.rawValue + 4)!!.pointed.value = value }
    
    var Flags: UInt
        get() = interpretCPointer<UIntVar>(this.ptr.rawValue + 8)!!.pointed.value
        set(value) { interpretCPointer<UIntVar>(this.ptr.rawValue + 8)!!.pointed.value = value }
    
    var NodeMask: UInt
        get() = interpretCPointer<UIntVar>(this.ptr.rawValue + 12)!!.pointed.value
        set(value) { interpretCPointer<UIntVar>(this.ptr.rawValue + 12)!!.pointed.value = value }
}

class D3D12_CPU_DESCRIPTOR_HANDLE(rawPtr: NativePtr) : CStructVar(rawPtr) {
    companion object : Type(8, 8)
    
    var value: ULong
        get() = this.ptr.reinterpret<ULongVar>().pointed.value
        set(v) { this.ptr.reinterpret<ULongVar>().pointed.value = v }
}

class D3D12_VIEWPORT(rawPtr: NativePtr) : CStructVar(rawPtr) {
    companion object : Type(24, 4)
    
    var TopLeftX: Float
        get() = this.ptr.reinterpret<FloatVar>().pointed.value
        set(value) { this.ptr.reinterpret<FloatVar>().pointed.value = value }
    
    var TopLeftY: Float
        get() = this.ptr.rawValue.plus(4).toLong().toCPointer<FloatVar>()!!.pointed.value
        set(value) { this.ptr.rawValue.plus(4).toLong().toCPointer<FloatVar>()!!.pointed.value = value }
    
    var Width: Float
        get() = this.ptr.rawValue.plus(8).toLong().toCPointer<FloatVar>()!!.pointed.value
        set(value) { this.ptr.rawValue.plus(8).toLong().toCPointer<FloatVar>()!!.pointed.value = value }
    
    var Height: Float
        get() = this.ptr.rawValue.plus(12).toLong().toCPointer<FloatVar>()!!.pointed.value
        set(value) { this.ptr.rawValue.plus(12).toLong().toCPointer<FloatVar>()!!.pointed.value = value }
    
    var MinDepth: Float
        get() = this.ptr.rawValue.plus(16).toLong().toCPointer<FloatVar>()!!.pointed.value
        set(value) { this.ptr.rawValue.plus(16).toLong().toCPointer<FloatVar>()!!.pointed.value = value }
    
    var MaxDepth: Float
        get() = this.ptr.rawValue.plus(20).toLong().toCPointer<FloatVar>()!!.pointed.value
        set(value) { this.ptr.rawValue.plus(20).toLong().toCPointer<FloatVar>()!!.pointed.value = value }
}

class D3D12_RECT(rawPtr: NativePtr) : CStructVar(rawPtr) {
    companion object : Type(16, 4)
    
    var left: Int
        get() = this.ptr.reinterpret<IntVar>().pointed.value
        set(value) { this.ptr.reinterpret<IntVar>().pointed.value = value }
    
    var top: Int
        get() = this.ptr.rawValue.plus(4).toLong().toCPointer<IntVar>()!!.pointed.value
        set(value) { this.ptr.rawValue.plus(4).toLong().toCPointer<IntVar>()!!.pointed.value = value }
    
    var right: Int
        get() = this.ptr.rawValue.plus(8).toLong().toCPointer<IntVar>()!!.pointed.value
        set(value) { this.ptr.rawValue.plus(8).toLong().toCPointer<IntVar>()!!.pointed.value = value }
    
    var bottom: Int
        get() = this.ptr.rawValue.plus(12).toLong().toCPointer<IntVar>()!!.pointed.value
        set(value) { this.ptr.rawValue.plus(12).toLong().toCPointer<IntVar>()!!.pointed.value = value }
}

class D3D12_INPUT_ELEMENT_DESC(rawPtr: NativePtr) : CStructVar(rawPtr) {
    companion object : Type(32, 8)
    
    var SemanticName: CPointer<ByteVar>?
        get() = this.ptr.reinterpret<CPointerVar<ByteVar>>().pointed.value
        set(value) { this.ptr.reinterpret<CPointerVar<ByteVar>>().pointed.value = value }
    
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

class D3D12_VERTEX_BUFFER_VIEW(rawPtr: NativePtr) : CStructVar(rawPtr) {
    companion object : Type(16, 8)
    
    var BufferLocation: ULong
        get() = this.ptr.reinterpret<ULongVar>().pointed.value
        set(value) { this.ptr.reinterpret<ULongVar>().pointed.value = value }
    
    var SizeInBytes: UInt
        get() = this.ptr.rawValue.plus(8).toLong().toCPointer<UIntVar>()!!.pointed.value
        set(value) { this.ptr.rawValue.plus(8).toLong().toCPointer<UIntVar>()!!.pointed.value = value }
    
    var StrideInBytes: UInt
        get() = this.ptr.rawValue.plus(12).toLong().toCPointer<UIntVar>()!!.pointed.value
        set(value) { this.ptr.rawValue.plus(12).toLong().toCPointer<UIntVar>()!!.pointed.value = value }
}

class D3D12_HEAP_PROPERTIES(rawPtr: NativePtr) : CStructVar(rawPtr) {
    companion object : Type(20, 4)

    var Type: UInt
        get() = this.ptr.reinterpret<UIntVar>().pointed.value
        set(value) { this.ptr.reinterpret<UIntVar>().pointed.value = value }

    var CPUPageProperty: UInt
        get() = interpretCPointer<UIntVar>(this.ptr.rawValue + 4)!!.pointed.value
        set(value) { interpretCPointer<UIntVar>(this.ptr.rawValue + 4)!!.pointed.value = value }

    var MemoryPoolPreference: UInt
        get() = interpretCPointer<UIntVar>(this.ptr.rawValue + 8)!!.pointed.value
        set(value) { interpretCPointer<UIntVar>(this.ptr.rawValue + 8)!!.pointed.value = value }

    var CreationNodeMask: UInt
        get() = interpretCPointer<UIntVar>(this.ptr.rawValue + 12)!!.pointed.value
        set(value) { interpretCPointer<UIntVar>(this.ptr.rawValue + 12)!!.pointed.value = value }

    var VisibleNodeMask: UInt
        get() = interpretCPointer<UIntVar>(this.ptr.rawValue + 16)!!.pointed.value
        set(value) { interpretCPointer<UIntVar>(this.ptr.rawValue + 16)!!.pointed.value = value }
}

class D3D12_RESOURCE_DESC(rawPtr: NativePtr) : CStructVar(rawPtr) {
    companion object : Type(56, 8)

    var Dimension: UInt
        get() = this.ptr.reinterpret<UIntVar>().pointed.value
        set(value) { this.ptr.reinterpret<UIntVar>().pointed.value = value }

    var Alignment: ULong
        get() = interpretCPointer<ULongVar>(this.ptr.rawValue + 8)!!.pointed.value
        set(value) { interpretCPointer<ULongVar>(this.ptr.rawValue + 8)!!.pointed.value = value }

    var Width: ULong
        get() = interpretCPointer<ULongVar>(this.ptr.rawValue + 16)!!.pointed.value
        set(value) { interpretCPointer<ULongVar>(this.ptr.rawValue + 16)!!.pointed.value = value }

    var Height: UInt
        get() = interpretCPointer<UIntVar>(this.ptr.rawValue + 24)!!.pointed.value
        set(value) { interpretCPointer<UIntVar>(this.ptr.rawValue + 24)!!.pointed.value = value }

    var DepthOrArraySize: UShort
        get() = interpretCPointer<UShortVar>(this.ptr.rawValue + 28)!!.pointed.value
        set(value) { interpretCPointer<UShortVar>(this.ptr.rawValue + 28)!!.pointed.value = value }

    var MipLevels: UShort
        get() = interpretCPointer<UShortVar>(this.ptr.rawValue + 30)!!.pointed.value
        set(value) { interpretCPointer<UShortVar>(this.ptr.rawValue + 30)!!.pointed.value = value }

    var Format: UInt
        get() = interpretCPointer<UIntVar>(this.ptr.rawValue + 32)!!.pointed.value
        set(value) { interpretCPointer<UIntVar>(this.ptr.rawValue + 32)!!.pointed.value = value }

    fun setSampleDesc(count: UInt, quality: UInt) {
        interpretCPointer<UIntVar>(this.ptr.rawValue + 36)!!.pointed.value = count
        interpretCPointer<UIntVar>(this.ptr.rawValue + 40)!!.pointed.value = quality
    }

    var Layout: UInt
        get() = interpretCPointer<UIntVar>(this.ptr.rawValue + 44)!!.pointed.value
        set(value) { interpretCPointer<UIntVar>(this.ptr.rawValue + 44)!!.pointed.value = value }

    var Flags: UInt
        get() = interpretCPointer<UIntVar>(this.ptr.rawValue + 48)!!.pointed.value
        set(value) { interpretCPointer<UIntVar>(this.ptr.rawValue + 48)!!.pointed.value = value }
}

class D3D12_RANGE(rawPtr: NativePtr) : CStructVar(rawPtr) {
    companion object : Type(16, 8)

    var Begin: ULong
        get() = this.ptr.reinterpret<ULongVar>().pointed.value
        set(value) { this.ptr.reinterpret<ULongVar>().pointed.value = value }

    var End: ULong
        get() = this.ptr.rawValue.plus(8).toLong().toCPointer<ULongVar>()!!.pointed.value
        set(value) { this.ptr.rawValue.plus(8).toLong().toCPointer<ULongVar>()!!.pointed.value = value }
}

class D3D12_RESOURCE_TRANSITION_BARRIER(rawPtr: NativePtr) : CStructVar(rawPtr) {
    companion object : Type(24, 8)

    var pResource: COpaquePointer?
        get() = this.ptr.reinterpret<COpaquePointerVar>().pointed.value
        set(value) { this.ptr.reinterpret<COpaquePointerVar>().pointed.value = value }

    var Subresource: UInt
        get() = this.ptr.rawValue.plus(8).toLong().toCPointer<UIntVar>()!!.pointed.value
        set(value) { this.ptr.rawValue.plus(8).toLong().toCPointer<UIntVar>()!!.pointed.value = value }

    var StateBefore: UInt
        get() = this.ptr.rawValue.plus(12).toLong().toCPointer<UIntVar>()!!.pointed.value
        set(value) { this.ptr.rawValue.plus(12).toLong().toCPointer<UIntVar>()!!.pointed.value = value }

    var StateAfter: UInt
        get() = this.ptr.rawValue.plus(16).toLong().toCPointer<UIntVar>()!!.pointed.value
        set(value) { this.ptr.rawValue.plus(16).toLong().toCPointer<UIntVar>()!!.pointed.value = value }
}

class D3D12_RESOURCE_BARRIER(rawPtr: NativePtr) : CStructVar(rawPtr) {
    companion object : Type(32, 8)

    var Type: UInt
        get() = this.ptr.reinterpret<UIntVar>().pointed.value
        set(value) { this.ptr.reinterpret<UIntVar>().pointed.value = value }

    var Flags: UInt
        get() = this.ptr.rawValue.plus(4).toLong().toCPointer<UIntVar>()!!.pointed.value
        set(value) { this.ptr.rawValue.plus(4).toLong().toCPointer<UIntVar>()!!.pointed.value = value }

    fun transition(): D3D12_RESOURCE_TRANSITION_BARRIER {
        val addr = this.ptr.rawValue + 8L
        return interpretCPointer<D3D12_RESOURCE_TRANSITION_BARRIER>(addr)!!.pointed
    }
}

class D3D12_SHADER_BYTECODE(rawPtr: NativePtr) : CStructVar(rawPtr) {
    companion object : Type(16, 8)

    var pShaderBytecode: COpaquePointer?
        get() = this.ptr.reinterpret<COpaquePointerVar>().pointed.value
        set(value) { this.ptr.reinterpret<COpaquePointerVar>().pointed.value = value }

    var BytecodeLength: ULong
        get() = this.ptr.rawValue.plus(8).toLong().toCPointer<ULongVar>()!!.pointed.value
        set(value) { this.ptr.rawValue.plus(8).toLong().toCPointer<ULongVar>()!!.pointed.value = value }
}

class D3D12_INPUT_LAYOUT_DESC(rawPtr: NativePtr) : CStructVar(rawPtr) {
    companion object : Type(16, 8)

    var pInputElementDescs: CPointer<D3D12_INPUT_ELEMENT_DESC>?
        get() = this.ptr.reinterpret<CPointerVar<D3D12_INPUT_ELEMENT_DESC>>().pointed.value
        set(value) { this.ptr.reinterpret<CPointerVar<D3D12_INPUT_ELEMENT_DESC>>().pointed.value = value }

    var NumElements: UInt
        get() = this.ptr.rawValue.plus(8).toLong().toCPointer<UIntVar>()!!.pointed.value
        set(value) { this.ptr.rawValue.plus(8).toLong().toCPointer<UIntVar>()!!.pointed.value = value }
}

class D3D12_RENDER_TARGET_BLEND_DESC(rawPtr: NativePtr) : CStructVar(rawPtr) {
    companion object : Type(40, 4)

    var BlendEnable: Int
        get() = this.ptr.reinterpret<IntVar>().pointed.value
        set(value) { this.ptr.reinterpret<IntVar>().pointed.value = value }

    var LogicOpEnable: Int
        get() = this.ptr.rawValue.plus(4).toLong().toCPointer<IntVar>()!!.pointed.value
        set(value) { this.ptr.rawValue.plus(4).toLong().toCPointer<IntVar>()!!.pointed.value = value }

    var SrcBlend: UInt
        get() = this.ptr.rawValue.plus(8).toLong().toCPointer<UIntVar>()!!.pointed.value
        set(value) { this.ptr.rawValue.plus(8).toLong().toCPointer<UIntVar>()!!.pointed.value = value }

    var DestBlend: UInt
        get() = this.ptr.rawValue.plus(12).toLong().toCPointer<UIntVar>()!!.pointed.value
        set(value) { this.ptr.rawValue.plus(12).toLong().toCPointer<UIntVar>()!!.pointed.value = value }

    var BlendOp: UInt
        get() = this.ptr.rawValue.plus(16).toLong().toCPointer<UIntVar>()!!.pointed.value
        set(value) { this.ptr.rawValue.plus(16).toLong().toCPointer<UIntVar>()!!.pointed.value = value }

    var SrcBlendAlpha: UInt
        get() = this.ptr.rawValue.plus(20).toLong().toCPointer<UIntVar>()!!.pointed.value
        set(value) { this.ptr.rawValue.plus(20).toLong().toCPointer<UIntVar>()!!.pointed.value = value }

    var DestBlendAlpha: UInt
        get() = this.ptr.rawValue.plus(24).toLong().toCPointer<UIntVar>()!!.pointed.value
        set(value) { this.ptr.rawValue.plus(24).toLong().toCPointer<UIntVar>()!!.pointed.value = value }

    var BlendOpAlpha: UInt
        get() = this.ptr.rawValue.plus(28).toLong().toCPointer<UIntVar>()!!.pointed.value
        set(value) { this.ptr.rawValue.plus(28).toLong().toCPointer<UIntVar>()!!.pointed.value = value }

    var LogicOp: UInt
        get() = this.ptr.rawValue.plus(32).toLong().toCPointer<UIntVar>()!!.pointed.value
        set(value) { this.ptr.rawValue.plus(32).toLong().toCPointer<UIntVar>()!!.pointed.value = value }

    var RenderTargetWriteMask: UByte
        get() = this.ptr.rawValue.plus(36).toLong().toCPointer<UByteVar>()!!.pointed.value
        set(value) { this.ptr.rawValue.plus(36).toLong().toCPointer<UByteVar>()!!.pointed.value = value }
}

class D3D12_BLEND_DESC(rawPtr: NativePtr) : CStructVar(rawPtr) {
    companion object : Type(328, 4)

    var AlphaToCoverageEnable: Int
        get() = this.ptr.reinterpret<IntVar>().pointed.value
        set(value) { this.ptr.reinterpret<IntVar>().pointed.value = value }

    var IndependentBlendEnable: Int
        get() = this.ptr.rawValue.plus(4).toLong().toCPointer<IntVar>()!!.pointed.value
        set(value) { this.ptr.rawValue.plus(4).toLong().toCPointer<IntVar>()!!.pointed.value = value }

    fun renderTarget(index: Int): D3D12_RENDER_TARGET_BLEND_DESC {
        val offset = 8 + (index * 40)
        val addr = this.ptr.rawValue + offset.toLong()
        return interpretCPointer<D3D12_RENDER_TARGET_BLEND_DESC>(addr)!!.pointed
    }
}

class D3D12_DEPTH_STENCILOP_DESC(rawPtr: NativePtr) : CStructVar(rawPtr) {
    companion object : Type(16, 4)

    var StencilFailOp: UInt
        get() = this.ptr.reinterpret<UIntVar>().pointed.value
        set(value) { this.ptr.reinterpret<UIntVar>().pointed.value = value }

    var StencilDepthFailOp: UInt
        get() = this.ptr.rawValue.plus(4).toLong().toCPointer<UIntVar>()!!.pointed.value
        set(value) { this.ptr.rawValue.plus(4).toLong().toCPointer<UIntVar>()!!.pointed.value = value }

    var StencilPassOp: UInt
        get() = this.ptr.rawValue.plus(8).toLong().toCPointer<UIntVar>()!!.pointed.value
        set(value) { this.ptr.rawValue.plus(8).toLong().toCPointer<UIntVar>()!!.pointed.value = value }

    var StencilFunc: UInt
        get() = this.ptr.rawValue.plus(12).toLong().toCPointer<UIntVar>()!!.pointed.value
        set(value) { this.ptr.rawValue.plus(12).toLong().toCPointer<UIntVar>()!!.pointed.value = value }
}

class D3D12_DEPTH_STENCIL_DESC(rawPtr: NativePtr) : CStructVar(rawPtr) {
    companion object : Type(52, 4)

    var DepthEnable: Int
        get() = this.ptr.reinterpret<IntVar>().pointed.value
        set(value) { this.ptr.reinterpret<IntVar>().pointed.value = value }

    var DepthWriteMask: UInt
        get() = this.ptr.rawValue.plus(4).toLong().toCPointer<UIntVar>()!!.pointed.value
        set(value) { this.ptr.rawValue.plus(4).toLong().toCPointer<UIntVar>()!!.pointed.value = value }

    var DepthFunc: UInt
        get() = this.ptr.rawValue.plus(8).toLong().toCPointer<UIntVar>()!!.pointed.value
        set(value) { this.ptr.rawValue.plus(8).toLong().toCPointer<UIntVar>()!!.pointed.value = value }

    var StencilEnable: Int
        get() = this.ptr.rawValue.plus(12).toLong().toCPointer<IntVar>()!!.pointed.value
        set(value) { this.ptr.rawValue.plus(12).toLong().toCPointer<IntVar>()!!.pointed.value = value }

    var StencilReadMask: UByte
        get() = this.ptr.rawValue.plus(16).toLong().toCPointer<UByteVar>()!!.pointed.value
        set(value) { this.ptr.rawValue.plus(16).toLong().toCPointer<UByteVar>()!!.pointed.value = value }

    var StencilWriteMask: UByte
        get() = this.ptr.rawValue.plus(17).toLong().toCPointer<UByteVar>()!!.pointed.value
        set(value) { this.ptr.rawValue.plus(17).toLong().toCPointer<UByteVar>()!!.pointed.value = value }

    fun frontFace(): D3D12_DEPTH_STENCILOP_DESC {
        val addr = this.ptr.rawValue + 20L
        return interpretCPointer<D3D12_DEPTH_STENCILOP_DESC>(addr)!!.pointed
    }

    fun backFace(): D3D12_DEPTH_STENCILOP_DESC {
        val addr = this.ptr.rawValue + 36L
        return interpretCPointer<D3D12_DEPTH_STENCILOP_DESC>(addr)!!.pointed
    }
}

class D3D12_RASTERIZER_DESC(rawPtr: NativePtr) : CStructVar(rawPtr) {
    companion object : Type(44, 4)

    var FillMode: UInt
        get() = this.ptr.reinterpret<UIntVar>().pointed.value
        set(value) { this.ptr.reinterpret<UIntVar>().pointed.value = value }

    var CullMode: UInt
        get() = this.ptr.rawValue.plus(4).toLong().toCPointer<UIntVar>()!!.pointed.value
        set(value) { this.ptr.rawValue.plus(4).toLong().toCPointer<UIntVar>()!!.pointed.value = value }

    var FrontCounterClockwise: Int
        get() = this.ptr.rawValue.plus(8).toLong().toCPointer<IntVar>()!!.pointed.value
        set(value) { this.ptr.rawValue.plus(8).toLong().toCPointer<IntVar>()!!.pointed.value = value }

    var DepthBias: Int
        get() = this.ptr.rawValue.plus(12).toLong().toCPointer<IntVar>()!!.pointed.value
        set(value) { this.ptr.rawValue.plus(12).toLong().toCPointer<IntVar>()!!.pointed.value = value }

    var DepthBiasClamp: Float
        get() = this.ptr.rawValue.plus(16).toLong().toCPointer<FloatVar>()!!.pointed.value
        set(value) { this.ptr.rawValue.plus(16).toLong().toCPointer<FloatVar>()!!.pointed.value = value }

    var SlopeScaledDepthBias: Float
        get() = this.ptr.rawValue.plus(20).toLong().toCPointer<FloatVar>()!!.pointed.value
        set(value) { this.ptr.rawValue.plus(20).toLong().toCPointer<FloatVar>()!!.pointed.value = value }

    var DepthClipEnable: Int
        get() = this.ptr.rawValue.plus(24).toLong().toCPointer<IntVar>()!!.pointed.value
        set(value) { this.ptr.rawValue.plus(24).toLong().toCPointer<IntVar>()!!.pointed.value = value }

    var MultisampleEnable: Int
        get() = this.ptr.rawValue.plus(28).toLong().toCPointer<IntVar>()!!.pointed.value
        set(value) { this.ptr.rawValue.plus(28).toLong().toCPointer<IntVar>()!!.pointed.value = value }

    var AntialiasedLineEnable: Int
        get() = this.ptr.rawValue.plus(32).toLong().toCPointer<IntVar>()!!.pointed.value
        set(value) { this.ptr.rawValue.plus(32).toLong().toCPointer<IntVar>()!!.pointed.value = value }

    var ForcedSampleCount: UInt
        get() = this.ptr.rawValue.plus(36).toLong().toCPointer<UIntVar>()!!.pointed.value
        set(value) { this.ptr.rawValue.plus(36).toLong().toCPointer<UIntVar>()!!.pointed.value = value }

    var ConservativeRaster: UInt
        get() = this.ptr.rawValue.plus(40).toLong().toCPointer<UIntVar>()!!.pointed.value
        set(value) { this.ptr.rawValue.plus(40).toLong().toCPointer<UIntVar>()!!.pointed.value = value }
}

class D3D12_STREAM_OUTPUT_DESC(rawPtr: NativePtr) : CStructVar(rawPtr) {
    companion object : Type(32, 8)

    var pSODeclaration: COpaquePointer?
        get() = this.ptr.reinterpret<COpaquePointerVar>().pointed.value
        set(value) { this.ptr.reinterpret<COpaquePointerVar>().pointed.value = value }

    var NumEntries: UInt
        get() = this.ptr.rawValue.plus(8).toLong().toCPointer<UIntVar>()!!.pointed.value
        set(value) { this.ptr.rawValue.plus(8).toLong().toCPointer<UIntVar>()!!.pointed.value = value }

    var pBufferStrides: COpaquePointer?
        get() = this.ptr.rawValue.plus(16).toLong().toCPointer<COpaquePointerVar>()!!.pointed.value
        set(value) { this.ptr.rawValue.plus(16).toLong().toCPointer<COpaquePointerVar>()!!.pointed.value = value }

    var NumStrides: UInt
        get() = this.ptr.rawValue.plus(24).toLong().toCPointer<UIntVar>()!!.pointed.value
        set(value) { this.ptr.rawValue.plus(24).toLong().toCPointer<UIntVar>()!!.pointed.value = value }

    var RasterizedStream: UInt
        get() = this.ptr.rawValue.plus(28).toLong().toCPointer<UIntVar>()!!.pointed.value
        set(value) { this.ptr.rawValue.plus(28).toLong().toCPointer<UIntVar>()!!.pointed.value = value }
}

class D3D12_CACHED_PIPELINE_STATE(rawPtr: NativePtr) : CStructVar(rawPtr) {
    companion object : Type(16, 8)

    var pCachedBlob: COpaquePointer?
        get() = this.ptr.reinterpret<COpaquePointerVar>().pointed.value
        set(value) { this.ptr.reinterpret<COpaquePointerVar>().pointed.value = value }

    var CachedBlobSizeInBytes: ULong
        get() = this.ptr.rawValue.plus(8).toLong().toCPointer<ULongVar>()!!.pointed.value
        set(value) { this.ptr.rawValue.plus(8).toLong().toCPointer<ULongVar>()!!.pointed.value = value }
}

class D3D12_GRAPHICS_PIPELINE_STATE_DESC(rawPtr: NativePtr) : CStructVar(rawPtr) {
    companion object : Type(656, 8)

    var pRootSignature: COpaquePointer?
        get() = this.ptr.reinterpret<COpaquePointerVar>().pointed.value
        set(value) { this.ptr.reinterpret<COpaquePointerVar>().pointed.value = value }

    fun vs(): D3D12_SHADER_BYTECODE {
        val addr = this.ptr.rawValue + 8L
        return interpretCPointer<D3D12_SHADER_BYTECODE>(addr)!!.pointed
    }

    fun ps(): D3D12_SHADER_BYTECODE {
        val addr = this.ptr.rawValue + 24L
        return interpretCPointer<D3D12_SHADER_BYTECODE>(addr)!!.pointed
    }

    fun ds(): D3D12_SHADER_BYTECODE {
        val addr = this.ptr.rawValue + 40L
        return interpretCPointer<D3D12_SHADER_BYTECODE>(addr)!!.pointed
    }

    fun hs(): D3D12_SHADER_BYTECODE {
        val addr = this.ptr.rawValue + 56L
        return interpretCPointer<D3D12_SHADER_BYTECODE>(addr)!!.pointed
    }

    fun gs(): D3D12_SHADER_BYTECODE {
        val addr = this.ptr.rawValue + 72L
        return interpretCPointer<D3D12_SHADER_BYTECODE>(addr)!!.pointed
    }

    fun streamOutput(): D3D12_STREAM_OUTPUT_DESC {
        val addr = this.ptr.rawValue + 88L
        return interpretCPointer<D3D12_STREAM_OUTPUT_DESC>(addr)!!.pointed
    }

    fun blendState(): D3D12_BLEND_DESC {
        val addr = this.ptr.rawValue + 120L
        return interpretCPointer<D3D12_BLEND_DESC>(addr)!!.pointed
    }

    var SampleMask: UInt
        get() = this.ptr.rawValue.plus(448).toLong().toCPointer<UIntVar>()!!.pointed.value
        set(value) { this.ptr.rawValue.plus(448).toLong().toCPointer<UIntVar>()!!.pointed.value = value }

    fun rasterizerState(): D3D12_RASTERIZER_DESC {
        val addr = this.ptr.rawValue + 452L
        return interpretCPointer<D3D12_RASTERIZER_DESC>(addr)!!.pointed
    }

    fun depthStencilState(): D3D12_DEPTH_STENCIL_DESC {
        val addr = this.ptr.rawValue + 496L
        return interpretCPointer<D3D12_DEPTH_STENCIL_DESC>(addr)!!.pointed
    }

    fun inputLayout(): D3D12_INPUT_LAYOUT_DESC {
        val addr = this.ptr.rawValue + 552L
        return interpretCPointer<D3D12_INPUT_LAYOUT_DESC>(addr)!!.pointed
    }

    var IBStripCutValue: UInt
        get() = this.ptr.rawValue.plus(568).toLong().toCPointer<UIntVar>()!!.pointed.value
        set(value) { this.ptr.rawValue.plus(568).toLong().toCPointer<UIntVar>()!!.pointed.value = value }

    var PrimitiveTopologyType: UInt
        get() = this.ptr.rawValue.plus(572).toLong().toCPointer<UIntVar>()!!.pointed.value
        set(value) { this.ptr.rawValue.plus(572).toLong().toCPointer<UIntVar>()!!.pointed.value = value }

    var NumRenderTargets: UInt
        get() = this.ptr.rawValue.plus(576).toLong().toCPointer<UIntVar>()!!.pointed.value
        set(value) { this.ptr.rawValue.plus(576).toLong().toCPointer<UIntVar>()!!.pointed.value = value }

    fun rtvFormat(index: Int): CPointer<UIntVar> {
        val offset = 580 + (index * 4)
        return interpretCPointer<UIntVar>(this.ptr.rawValue + offset.toLong())!!
    }

    var DSVFormat: UInt
        get() = this.ptr.rawValue.plus(612).toLong().toCPointer<UIntVar>()!!.pointed.value
        set(value) { this.ptr.rawValue.plus(612).toLong().toCPointer<UIntVar>()!!.pointed.value = value }

    fun setSampleDesc(count: UInt, quality: UInt) {
        this.ptr.rawValue.plus(616).toLong().toCPointer<UIntVar>()!!.pointed.value = count
        this.ptr.rawValue.plus(620).toLong().toCPointer<UIntVar>()!!.pointed.value = quality
    }

    var NodeMask: UInt
        get() = this.ptr.rawValue.plus(624).toLong().toCPointer<UIntVar>()!!.pointed.value
        set(value) { this.ptr.rawValue.plus(624).toLong().toCPointer<UIntVar>()!!.pointed.value = value }

    fun cachedPSO(): D3D12_CACHED_PIPELINE_STATE {
        val addr = this.ptr.rawValue + 632L
        return interpretCPointer<D3D12_CACHED_PIPELINE_STATE>(addr)!!.pointed
    }

    var Flags: UInt
        get() = this.ptr.rawValue.plus(648).toLong().toCPointer<UIntVar>()!!.pointed.value
        set(value) { this.ptr.rawValue.plus(648).toLong().toCPointer<UIntVar>()!!.pointed.value = value }
}

class D3D12_ROOT_SIGNATURE_DESC(rawPtr: NativePtr) : CStructVar(rawPtr) {
    companion object : Type(40, 8)

    var NumParameters: UInt
        get() = this.ptr.reinterpret<UIntVar>().pointed.value
        set(value) { this.ptr.reinterpret<UIntVar>().pointed.value = value }

    var pParameters: COpaquePointer?
        get() = this.ptr.rawValue.plus(8).toLong().toCPointer<COpaquePointerVar>()!!.pointed.value
        set(value) { this.ptr.rawValue.plus(8).toLong().toCPointer<COpaquePointerVar>()!!.pointed.value = value }

    var NumStaticSamplers: UInt
        get() = this.ptr.rawValue.plus(16).toLong().toCPointer<UIntVar>()!!.pointed.value
        set(value) { this.ptr.rawValue.plus(16).toLong().toCPointer<UIntVar>()!!.pointed.value = value }

    var pStaticSamplers: COpaquePointer?
        get() = this.ptr.rawValue.plus(24).toLong().toCPointer<COpaquePointerVar>()!!.pointed.value
        set(value) { this.ptr.rawValue.plus(24).toLong().toCPointer<COpaquePointerVar>()!!.pointed.value = value }

    var Flags: UInt
        get() = this.ptr.rawValue.plus(32).toLong().toCPointer<UIntVar>()!!.pointed.value
        set(value) { this.ptr.rawValue.plus(32).toLong().toCPointer<UIntVar>()!!.pointed.value = value }
}

// ============================================================
// DirectX 12 Initialization
// ============================================================
private fun initD3D12(hwnd: HWND?): Boolean {
    debugOutput("[initD3D12] START")
    
    memScoped {
        // Load DLLs
        debugOutput("[initD3D12] Loading d3d12.dll...")
        g_hD3D12 = LoadLibraryW("d3d12.dll")
        if (g_hD3D12 == null) {
            debugOutput("[initD3D12] ERROR: Failed to load d3d12.dll")
            return false
        }
        debugOutput("[initD3D12] d3d12.dll loaded successfully")
        
        debugOutput("[initD3D12] Loading dxgi.dll...")
        g_hDXGI = LoadLibraryW("dxgi.dll")
        if (g_hDXGI == null) {
            debugOutput("[initD3D12] ERROR: Failed to load dxgi.dll")
            return false
        }
        debugOutput("[initD3D12] dxgi.dll loaded successfully")
        
        debugOutput("[initD3D12] Loading d3dcompiler_47.dll...")
        g_hCompiler = LoadLibraryW("d3dcompiler_47.dll")
        if (g_hCompiler == null) {
            g_hCompiler = LoadLibraryW("d3dcompiler_43.dll")
        }
        if (g_hCompiler == null) {
            debugOutput("[initD3D12] WARNING: d3dcompiler not loaded")
        } else {
            debugOutput("[initD3D12] d3dcompiler loaded successfully")
        }
        
        // Enable Debug Layer
        debugOutput("[initD3D12] Enabling debug layer...")
        val getDebugInterfaceFunc = GetProcAddress(g_hD3D12, "D3D12GetDebugInterface")
        if (getDebugInterfaceFunc != null) {
            val iidDebug = alloc<GUID>()
            initIID_ID3D12Debug(iidDebug)
            
            val debugVar = alloc<COpaquePointerVar>()
            val hrDebug = getDebugInterfaceFunc.reinterpret<CFunction<(CPointer<GUID>?, CPointer<COpaquePointerVar>?) -> Int>>()
                .invoke(iidDebug.ptr, debugVar.ptr)
            
            if (hrDebug == 0 && debugVar.value != null) {
                debugOutput("[initD3D12] Debug interface obtained: 0x${toHex(debugVar.value!!.rawValue.toLong())}")
                
                // ID3D12Debug::EnableDebugLayer (vtable #3)
                val enableDebugLayerFunc = comMethod(debugVar.value, 3)
                    ?.reinterpret<CFunction<(COpaquePointer?) -> Unit>>()
                if (enableDebugLayerFunc != null) {
                    enableDebugLayerFunc.invoke(debugVar.value)
                    debugOutput("[initD3D12] Debug layer enabled successfully")
                } else {
                    debugOutput("[initD3D12] WARNING: EnableDebugLayer function not found")
                }
                
                releaseComObject(debugVar.value)
            } else {
                debugOutput("[initD3D12] WARNING: D3D12GetDebugInterface failed: HRESULT=0x${toHex(hrDebug.toLong())}")
            }
        } else {
            debugOutput("[initD3D12] WARNING: D3D12GetDebugInterface not found")
        }
        
        // Get D3D12CreateDevice function
        val createDeviceFunc = GetProcAddress(g_hD3D12, "D3D12CreateDevice")
        if (createDeviceFunc == null) {
            debugOutput("[initD3D12] ERROR: Failed to get D3D12CreateDevice")
            return false
        }
        
        debugOutput("[initD3D12] Creating D3D12 device...")
        
        // Create IID_ID3D12Device
        val iidDevice = alloc<GUID>()
        initIID_ID3D12Device(iidDevice)
        debugOutput("[initD3D12] IID_ID3D12Device: {${toHex(iidDevice.Data1.toLong())}-${toHex(iidDevice.Data2.toLong())}-${toHex(iidDevice.Data3.toLong())}-...}")
        
        // Create device with proper IID
        val deviceVar = alloc<COpaquePointerVar>()
        val hr = createDeviceFunc.reinterpret<CFunction<(COpaquePointer?, UInt, CPointer<GUID>?, CPointer<COpaquePointerVar>?) -> Int>>()
            .invoke(null, D3D_FEATURE_LEVEL_11_0, iidDevice.ptr, deviceVar.ptr)
        
        if (hr != 0) {
            debugOutput("[initD3D12] ERROR: D3D12CreateDevice failed: HRESULT=0x${toHex(hr.toLong())}")
            debugOutput("[initD3D12] Check DebugView for detailed error messages")
            return false
        }
        
        g_device = deviceVar.value
        debugOutput("[initD3D12] Device created successfully: 0x${g_device?.rawValue?.toLong()?.let { toHex(it) } ?: "null"}")
        
        // ===== Create Command Queue =====
        debugOutput("[initD3D12] Creating command queue...")
        val queueDesc = alloc<D3D12_COMMAND_QUEUE_DESC>()
        queueDesc.Type = D3D12_COMMAND_LIST_TYPE_DIRECT
        queueDesc.Priority = 0
        queueDesc.Flags = D3D12_COMMAND_QUEUE_FLAG_NONE
        queueDesc.NodeMask = 0u
        
        val queueVar = alloc<COpaquePointerVar>()
        // ID3D12Device::CreateCommandQueue (vtable #8)
        val createQueueFunc = comMethod(g_device, 8)
            ?.reinterpret<CFunction<(COpaquePointer?, CPointer<D3D12_COMMAND_QUEUE_DESC>?, CPointer<GUID>?, CPointer<COpaquePointerVar>?) -> Int>>()

        val iidQueue = alloc<GUID>()
        initIID_ID3D12CommandQueue(iidQueue)
        val hrQueue = createQueueFunc?.invoke(g_device, queueDesc.ptr, iidQueue.ptr, queueVar.ptr) ?: -1
        if (hrQueue != 0) {
            debugOutput("[initD3D12] ERROR: CreateCommandQueue failed: HRESULT=0x${toHex(hrQueue.toLong())}")
            return false
        }
        g_commandQueue = queueVar.value
        debugOutput("[initD3D12] Command queue created: 0x${toHex(g_commandQueue!!.rawValue.toLong())}")
        
        // ===== Create Swap Chain =====
        debugOutput("[initD3D12] Creating DXGI factory and swap chain...")
        val createFactoryFunc = GetProcAddress(g_hDXGI, "CreateDXGIFactory2")
        if (createFactoryFunc == null) {
            debugOutput("[initD3D12] ERROR: CreateDXGIFactory2 not found")
            return false
        }
        
        val factoryVar = alloc<COpaquePointerVar>()
        val iidFactory = alloc<GUID>()
        initIID_IDXGIFactory4(iidFactory)
        val hrFactory = createFactoryFunc.reinterpret<CFunction<(UInt, CPointer<GUID>?, CPointer<COpaquePointerVar>?) -> Int>>()
            .invoke(0u, iidFactory.ptr, factoryVar.ptr)
        
        if (hrFactory != 0) {
            debugOutput("[initD3D12] ERROR: CreateDXGIFactory2 failed: HRESULT=0x${toHex(hrFactory.toLong())}")
            return false
        }
        
        val factory = factoryVar.value
        debugOutput("[initD3D12] DXGI Factory created")
        
        val swapChainDesc = alloc<DXGI_SWAP_CHAIN_DESC1>()
        swapChainDesc.Width = 640u
        swapChainDesc.Height = 480u
        swapChainDesc.Format = DXGI_FORMAT_R8G8B8A8_UNORM
        swapChainDesc.Stereo = 0
        swapChainDesc.setSampleDesc(1u, 0u)
        swapChainDesc.BufferUsage = DXGI_USAGE_RENDER_TARGET_OUTPUT
        swapChainDesc.BufferCount = FRAME_COUNT
        swapChainDesc.Scaling = 0u
        swapChainDesc.SwapEffect = DXGI_SWAP_EFFECT_FLIP_DISCARD
        swapChainDesc.AlphaMode = 0u
        swapChainDesc.Flags = 0u
        
        val swapChainVar = alloc<COpaquePointerVar>()
        // IDXGIFactory2::CreateSwapChainForHwnd (vtable #15)
        val createSwapChainFunc = comMethod(factory, 15)
            ?.reinterpret<CFunction<(COpaquePointer?, COpaquePointer?, HWND?, CPointer<DXGI_SWAP_CHAIN_DESC1>?, COpaquePointer?, COpaquePointer?, CPointer<COpaquePointerVar>?) -> Int>>()
        
        val hrSwapChain = createSwapChainFunc?.invoke(factory, g_commandQueue, hwnd, swapChainDesc.ptr, null, null, swapChainVar.ptr) ?: -1
        releaseComObject(factory)
        
        if (hrSwapChain != 0) {
            debugOutput("[initD3D12] ERROR: CreateSwapChainForHwnd failed: HRESULT=0x${toHex(hrSwapChain.toLong())}")
            return false
        }
        val swapChain1 = swapChainVar.value
        if (swapChain1 == null) {
            debugOutput("[initD3D12] ERROR: Swap chain pointer is null")
            return false
        }

        val iidSwapChain3 = alloc<GUID>()
        initIID_IDXGISwapChain3(iidSwapChain3)
        val swapChain3 = queryInterface(swapChain1, iidSwapChain3)
        if (swapChain3 == null) {
            debugOutput("[initD3D12] WARNING: QueryInterface for IDXGISwapChain3 failed; using IDXGISwapChain1")
            g_swapChain = swapChain1
        } else {
            g_swapChain = swapChain3
            releaseComObject(swapChain1)
        }
        debugOutput("[initD3D12] Swap chain created: 0x${toHex(g_swapChain!!.rawValue.toLong())}")

        g_frameIndex = 0u
        debugOutput("[initD3D12] Frame index initialized: $g_frameIndex")

        // ===== Create RTV Descriptor Heap =====
        debugOutput("[initD3D12] Creating RTV descriptor heap...")
        val rtvHeapDesc = alloc<D3D12_DESCRIPTOR_HEAP_DESC>()
        rtvHeapDesc.Type = D3D12_DESCRIPTOR_HEAP_TYPE_RTV
        rtvHeapDesc.NumDescriptors = FRAME_COUNT
        rtvHeapDesc.Flags = D3D12_DESCRIPTOR_HEAP_FLAG_NONE
        rtvHeapDesc.NodeMask = 0u
        
        debugOutput("[initD3D12] Heap Type: ${rtvHeapDesc.Type}, NumDescriptors: ${rtvHeapDesc.NumDescriptors}, Flags: ${rtvHeapDesc.Flags}, NodeMask: ${rtvHeapDesc.NodeMask}")

        val rtvHeapVar = alloc<COpaquePointerVar>()
        val iidHeap = alloc<GUID>()
        initIID_ID3D12DescriptorHeap(iidHeap)
        // ID3D12Device::CreateDescriptorHeap (vtable #14)
        val createHeapFunc = comMethod(g_device, 14)
            ?.reinterpret<CFunction<(COpaquePointer?, CPointer<D3D12_DESCRIPTOR_HEAP_DESC>?, CPointer<GUID>?, CPointer<COpaquePointerVar>?) -> Int>>()
        val hrHeap = createHeapFunc?.invoke(g_device, rtvHeapDesc.ptr, iidHeap.ptr, rtvHeapVar.ptr) ?: -1
        if (hrHeap != 0) {
            debugOutput("[initD3D12] ERROR: CreateDescriptorHeap failed: HRESULT=0x${toHex(hrHeap.toLong())}")
            return false
        }
        g_rtvHeap = rtvHeapVar.value

        // ID3D12Device::GetDescriptorHandleIncrementSize (vtable #15)
        val getDescSizeFunc = comMethod(g_device, 15)
            ?.reinterpret<CFunction<(COpaquePointer?, UInt) -> UInt>>()
        g_rtvDescriptorSize = getDescSizeFunc?.invoke(g_device, D3D12_DESCRIPTOR_HEAP_TYPE_RTV) ?: 0u
        debugOutput("[initD3D12] RTV descriptor size: $g_rtvDescriptorSize")

        // ID3D12DescriptorHeap::GetCPUDescriptorHandleForHeapStart (vtable #9)
        // NOTE:
        //  - Although the C++ header shows: D3D12_CPU_DESCRIPTOR_HANDLE GetCPUDescriptorHandleForHeapStart();
        //  - In practice, when calling through a raw vtable from Kotlin/Native, treating it as an "out-parameter" style
        //    call (this, D3D12_CPU_DESCRIPTOR_HANDLE*) is more robust (matches the working ctypes sample).
        //  - We copy the returned 64-bit handle value into a global (do NOT store the memScoped pointer).
        val rtvStartHandle = alloc<D3D12_CPU_DESCRIPTOR_HANDLE>()
        val getCpuStartFunc = comMethod(g_rtvHeap, 9)
            ?.reinterpret<CFunction<(COpaquePointer?, CPointer<D3D12_CPU_DESCRIPTOR_HANDLE>?) -> COpaquePointer?>>()
        getCpuStartFunc?.invoke(g_rtvHeap, rtvStartHandle.ptr)
        g_rtvHeapStartValue = rtvStartHandle.value
        val rtvStart = g_rtvHeapStartValue

        val getBufferFunc = comMethod(g_swapChain, 9)
            ?.reinterpret<CFunction<(COpaquePointer?, UInt, CPointer<GUID>?, CPointer<COpaquePointerVar>?) -> Int>>()
        // ID3D12Device::CreateRenderTargetView (vtable #20)
        val createRTVFunc = comMethod(g_device, 20)
            ?.reinterpret<CFunction<(COpaquePointer?, COpaquePointer?, COpaquePointer?, ULong) -> Unit>>()

        val iidResource = alloc<GUID>()
        initIID_ID3D12Resource(iidResource)

        for (i in 0 until FRAME_COUNT.toInt()) {
            val backBufferVar = alloc<COpaquePointerVar>()
            val hrBuf = getBufferFunc?.invoke(g_swapChain, i.toUInt(), iidResource.ptr, backBufferVar.ptr) ?: -1
            if (hrBuf != 0) {
                debugOutput("[initD3D12] ERROR: GetBuffer($i) failed: HRESULT=0x${toHex(hrBuf.toLong())}")
                return false
            }
            g_renderTargets[i] = backBufferVar.value

            val handleValue = rtvStart + (i.toULong() * g_rtvDescriptorSize.toULong())
            createRTVFunc?.invoke(g_device, g_renderTargets[i], null, handleValue)
        }
        debugOutput("[initD3D12] Render target views created")

        // ===== Create Command Allocator and Command List =====
        debugOutput("[initD3D12] Creating command allocator and list...")
        val allocatorVar = alloc<COpaquePointerVar>()
        val iidAllocator = alloc<GUID>()
        initIID_ID3D12CommandAllocator(iidAllocator)
        // ID3D12Device::CreateCommandAllocator (vtable #9)
        val createAllocatorFunc = comMethod(g_device, 9)
            ?.reinterpret<CFunction<(COpaquePointer?, UInt, CPointer<GUID>?, CPointer<COpaquePointerVar>?) -> Int>>()
        val hrAllocator = createAllocatorFunc?.invoke(g_device, D3D12_COMMAND_LIST_TYPE_DIRECT, iidAllocator.ptr, allocatorVar.ptr) ?: -1
        if (hrAllocator != 0) {
            debugOutput("[initD3D12] ERROR: CreateCommandAllocator failed: HRESULT=0x${toHex(hrAllocator.toLong())}")
            return false
        }
        g_commandAllocator = allocatorVar.value

        val commandListVar = alloc<COpaquePointerVar>()
        val iidCmdList = alloc<GUID>()
        initIID_ID3D12GraphicsCommandList(iidCmdList)
        // ID3D12Device::CreateCommandList (vtable #12)
        val createCommandListFunc = comMethod(g_device, 12)
            ?.reinterpret<CFunction<(COpaquePointer?, UInt, UInt, COpaquePointer?, COpaquePointer?, CPointer<GUID>?, CPointer<COpaquePointerVar>?) -> Int>>()
        val hrCmdList = createCommandListFunc?.invoke(g_device, 0u, D3D12_COMMAND_LIST_TYPE_DIRECT, g_commandAllocator, null, iidCmdList.ptr, commandListVar.ptr) ?: -1
        if (hrCmdList != 0) {
            debugOutput("[initD3D12] ERROR: CreateCommandList failed: HRESULT=0x${toHex(hrCmdList.toLong())}")
            return false
        }
        g_commandList = commandListVar.value

        // ID3D12GraphicsCommandList::Close (vtable #9)
        val closeFunc = comMethod(g_commandList, 9)
            ?.reinterpret<CFunction<(COpaquePointer?) -> Int>>()
        closeFunc?.invoke(g_commandList)
        debugOutput("[initD3D12] Command allocator and list created")

        // ===== Create Root Signature =====
        debugOutput("[initD3D12] Creating root signature...")
        val serializeFunc = GetProcAddress(g_hD3D12, "D3D12SerializeRootSignature")
            ?.reinterpret<CFunction<(CPointer<D3D12_ROOT_SIGNATURE_DESC>?, UInt, CPointer<COpaquePointerVar>?, CPointer<COpaquePointerVar>?) -> Int>>()
        if (serializeFunc == null) {
            debugOutput("[initD3D12] ERROR: D3D12SerializeRootSignature not found")
            return false
        }

        val rsDesc = alloc<D3D12_ROOT_SIGNATURE_DESC>()
        rsDesc.NumParameters = 0u
        rsDesc.pParameters = null
        rsDesc.NumStaticSamplers = 0u
        rsDesc.pStaticSamplers = null
        rsDesc.Flags = D3D12_ROOT_SIGNATURE_FLAG_ALLOW_INPUT_ASSEMBLER_INPUT_LAYOUT

        val rsBlobVar = alloc<COpaquePointerVar>()
        val rsErrorVar = alloc<COpaquePointerVar>()
        val hrSerialize = serializeFunc.invoke(rsDesc.ptr, D3D12_ROOT_SIGNATURE_VERSION_1, rsBlobVar.ptr, rsErrorVar.ptr)
        if (hrSerialize != 0) {
            debugOutput("[initD3D12] ERROR: D3D12SerializeRootSignature failed: HRESULT=0x${toHex(hrSerialize.toLong())}")
            if (rsErrorVar.value != null) {
                releaseComObject(rsErrorVar.value)
            }
            return false
        }
        if (rsErrorVar.value != null) {
            releaseComObject(rsErrorVar.value)
        }

        val rootSigVar = alloc<COpaquePointerVar>()
        val iidRootSig = alloc<GUID>()
        initIID_ID3D12RootSignature(iidRootSig)
        // ID3D12Device::CreateRootSignature (vtable #16)
        val createRootSigFunc = comMethod(g_device, 16)
            ?.reinterpret<CFunction<(COpaquePointer?, UInt, COpaquePointer?, ULong, CPointer<GUID>?, CPointer<COpaquePointerVar>?) -> Int>>()
        val rsPtr = blobGetPointer(rsBlobVar.value)
        val rsSize = blobGetSize(rsBlobVar.value)
        val hrRoot = createRootSigFunc?.invoke(g_device, 0u, rsPtr, rsSize, iidRootSig.ptr, rootSigVar.ptr) ?: -1
        releaseComObject(rsBlobVar.value)
        if (hrRoot != 0) {
            debugOutput("[initD3D12] ERROR: CreateRootSignature failed: HRESULT=0x${toHex(hrRoot.toLong())}")
            return false
        }
        g_rootSignature = rootSigVar.value
        debugOutput("[initD3D12] Root signature created")

        // ===== Create Pipeline State =====
        debugOutput("[initD3D12] Creating pipeline state...")
        val vsBlob = compileShader("VS", "vs_5_0")
        if (vsBlob == null) {
            debugOutput("[initD3D12] ERROR: Vertex shader compilation failed")
            return false
        }
        val psBlob = compileShader("PS", "ps_5_0")
        if (psBlob == null) {
            releaseComObject(vsBlob)
            debugOutput("[initD3D12] ERROR: Pixel shader compilation failed")
            return false
        }

        memScoped {
            val posName = "POSITION".cstr
            val colorName = "COLOR".cstr

            val layout = allocArray<D3D12_INPUT_ELEMENT_DESC>(2)
            val pos = interpretCPointer<D3D12_INPUT_ELEMENT_DESC>(layout[0].rawPtr)!!.pointed
            pos.SemanticName = posName.ptr
            pos.SemanticIndex = 0u
            pos.Format = DXGI_FORMAT_R32G32B32_FLOAT
            pos.InputSlot = 0u
            pos.AlignedByteOffset = 0u
            pos.InputSlotClass = D3D12_INPUT_CLASSIFICATION_PER_VERTEX_DATA
            pos.InstanceDataStepRate = 0u

            val col = interpretCPointer<D3D12_INPUT_ELEMENT_DESC>(layout[1].rawPtr)!!.pointed
            col.SemanticName = colorName.ptr
            col.SemanticIndex = 0u
            col.Format = DXGI_FORMAT_R32G32B32A32_FLOAT
            col.InputSlot = 0u
            col.AlignedByteOffset = 12u
            col.InputSlotClass = D3D12_INPUT_CLASSIFICATION_PER_VERTEX_DATA
            col.InstanceDataStepRate = 0u

            val psoDesc = alloc<D3D12_GRAPHICS_PIPELINE_STATE_DESC>()
            // Safety: ensure the entire PSO desc is zero-initialized (struct is large and easy to partially miss)
            memset(psoDesc.ptr, 0, 656.convert())
            psoDesc.pRootSignature = g_rootSignature
            psoDesc.vs().pShaderBytecode = blobGetPointer(vsBlob)
            psoDesc.vs().BytecodeLength = blobGetSize(vsBlob)
            psoDesc.ps().pShaderBytecode = blobGetPointer(psBlob)
            psoDesc.ps().BytecodeLength = blobGetSize(psBlob)

            psoDesc.streamOutput().pSODeclaration = null
            psoDesc.streamOutput().NumEntries = 0u
            psoDesc.streamOutput().pBufferStrides = null
            psoDesc.streamOutput().NumStrides = 0u
            psoDesc.streamOutput().RasterizedStream = 0u

            val blend = psoDesc.blendState()
            blend.AlphaToCoverageEnable = 0
            blend.IndependentBlendEnable = 0
            val rt0 = blend.renderTarget(0)
            rt0.BlendEnable = 0
            rt0.LogicOpEnable = 0
            rt0.SrcBlend = D3D12_BLEND_ONE
            rt0.DestBlend = D3D12_BLEND_ZERO
            rt0.BlendOp = D3D12_BLEND_OP_ADD
            rt0.SrcBlendAlpha = D3D12_BLEND_ONE
            rt0.DestBlendAlpha = D3D12_BLEND_ZERO
            rt0.BlendOpAlpha = D3D12_BLEND_OP_ADD
            rt0.LogicOp = D3D12_LOGIC_OP_NOOP
            rt0.RenderTargetWriteMask = D3D12_COLOR_WRITE_ENABLE_ALL

            psoDesc.SampleMask = 0xffffffffu

            val rs = psoDesc.rasterizerState()
            rs.FillMode = D3D12_FILL_MODE_SOLID
            rs.CullMode = D3D12_CULL_MODE_NONE
            rs.FrontCounterClockwise = 0
            rs.DepthBias = 0
            rs.DepthBiasClamp = 0.0f
            rs.SlopeScaledDepthBias = 0.0f
            rs.DepthClipEnable = 1
            rs.MultisampleEnable = 0
            rs.AntialiasedLineEnable = 0
            rs.ForcedSampleCount = 0u
            rs.ConservativeRaster = 0u

            val ds = psoDesc.depthStencilState()
            ds.DepthEnable = 0
            ds.DepthWriteMask = D3D12_DEPTH_WRITE_MASK_ZERO
            ds.DepthFunc = D3D12_COMPARISON_FUNC_ALWAYS
            ds.StencilEnable = 0
            ds.StencilReadMask = 0u
            ds.StencilWriteMask = 0u

            val il = psoDesc.inputLayout()
            il.pInputElementDescs = layout
            il.NumElements = 2u

            psoDesc.IBStripCutValue = 0u
            psoDesc.PrimitiveTopologyType = D3D12_PRIMITIVE_TOPOLOGY_TYPE_TRIANGLE
            psoDesc.NumRenderTargets = 1u
            psoDesc.rtvFormat(0).pointed.value = DXGI_FORMAT_R8G8B8A8_UNORM
            for (i in 1 until 8) {
                psoDesc.rtvFormat(i).pointed.value = 0u
            }
            psoDesc.DSVFormat = 0u
            psoDesc.setSampleDesc(1u, 0u)
            psoDesc.NodeMask = 0u
            psoDesc.cachedPSO().pCachedBlob = null
            psoDesc.cachedPSO().CachedBlobSizeInBytes = 0u
            psoDesc.Flags = 0u

            val psoVar = alloc<COpaquePointerVar>()
            val iidPso = alloc<GUID>()
            initIID_ID3D12PipelineState(iidPso)
            // ID3D12Device::CreateGraphicsPipelineState (vtable #10)
            val createPsoFunc = comMethod(g_device, 10)
                ?.reinterpret<CFunction<(COpaquePointer?, CPointer<D3D12_GRAPHICS_PIPELINE_STATE_DESC>?, CPointer<GUID>?, CPointer<COpaquePointerVar>?) -> Int>>()
            val hrPso = createPsoFunc?.invoke(g_device, psoDesc.ptr, iidPso.ptr, psoVar.ptr) ?: -1
            if (hrPso != 0) {
                debugOutput("[initD3D12] ERROR: CreateGraphicsPipelineState failed: HRESULT=0x${toHex(hrPso.toLong())}")
                releaseComObject(vsBlob)
                releaseComObject(psBlob)
                return false
            }
            g_pipelineState = psoVar.value
        }

        releaseComObject(vsBlob)
        releaseComObject(psBlob)
        debugOutput("[initD3D12] Pipeline state created")

        // ===== Create Vertex Buffer =====
        debugOutput("[initD3D12] Creating vertex buffer...")
        val heapProps = alloc<D3D12_HEAP_PROPERTIES>()
        heapProps.Type = D3D12_HEAP_TYPE_UPLOAD
        heapProps.CPUPageProperty = 0u
        heapProps.MemoryPoolPreference = 0u
        heapProps.CreationNodeMask = 1u
        heapProps.VisibleNodeMask = 1u

        val vertexBufferSize = (VERTEX.size * 3).toULong()
        debugOutput("[initD3D12] Vertex buffer size: $vertexBufferSize bytes (VERTEX.size=${VERTEX.size})")
        
        val resDesc = alloc<D3D12_RESOURCE_DESC>()
        resDesc.Dimension = D3D12_RESOURCE_DIMENSION_BUFFER
        resDesc.Alignment = 0u
        resDesc.Width = vertexBufferSize
        resDesc.Height = 1u
        resDesc.DepthOrArraySize = 1u.toUShort()
        resDesc.MipLevels = 1u.toUShort()
        resDesc.Format = 0u
        resDesc.setSampleDesc(1u, 0u)
        resDesc.Layout = D3D12_TEXTURE_LAYOUT_ROW_MAJOR
        resDesc.Flags = D3D12_RESOURCE_FLAG_NONE
        
        debugOutput("[initD3D12] D3D12_HEAP_PROPERTIES: Type=${heapProps.Type}, CreationNodeMask=${heapProps.CreationNodeMask}, VisibleNodeMask=${heapProps.VisibleNodeMask}")
        debugOutput("[initD3D12] D3D12_RESOURCE_DESC: Dimension=${resDesc.Dimension}, Alignment=${resDesc.Alignment}, Width=${resDesc.Width}, Height=${resDesc.Height}")

        val vbVar = alloc<COpaquePointerVar>()
        // ID3D12Device::CreateCommittedResource (vtable #27)
        val hrVb = comMethod(g_device, 27)
            ?.reinterpret<CFunction<(COpaquePointer?, CPointer<D3D12_HEAP_PROPERTIES>?, UInt, CPointer<D3D12_RESOURCE_DESC>?, UInt, COpaquePointer?, CPointer<GUID>?, CPointer<COpaquePointerVar>?) -> Int>>()
            ?.invoke(g_device, heapProps.ptr, D3D12_HEAP_FLAG_NONE, resDesc.ptr, 0u, null, iidResource.ptr, vbVar.ptr) ?: -1
        if (hrVb != 0) {
            debugOutput("[initD3D12] ERROR: CreateCommittedResource failed: HRESULT=0x${toHex(hrVb.toLong())}")
            return false
        }
        g_vertexBuffer = vbVar.value
        debugOutput("[initD3D12] Vertex buffer created: 0x${toHex(g_vertexBuffer?.rawValue?.toLong() ?: 0)}")

        // ID3D12Resource::Map (vtable #8)
        debugOutput("[initD3D12] Calling Map on vertex buffer...")
        val mapFunc = comMethod(g_vertexBuffer, 8)
            ?.reinterpret<CFunction<(COpaquePointer?, UInt, CPointer<D3D12_RANGE>?, CPointer<COpaquePointerVar>?) -> Int>>()
        if (mapFunc == null) {
            debugOutput("[initD3D12] ERROR: Map function pointer is null")
            return false
        }
        
        val mappedVar = alloc<COpaquePointerVar>()
        debugOutput("[initD3D12] Map parameters: resource=0x${toHex(g_vertexBuffer?.rawValue?.toLong() ?: 0)}, subresource=0, readRange=null")
        val hrMap = mapFunc.invoke(g_vertexBuffer, 0u, null, mappedVar.ptr)
        if (hrMap != 0) {
            debugOutput("[initD3D12] ERROR: Map failed: HRESULT=0x${toHex(hrMap.toLong())}")
            return false
        }
        debugOutput("[initD3D12] Map succeeded, mapped pointer: 0x${toHex(mappedVar.value?.rawValue?.toLong() ?: 0)}")

        memScoped {
            val vertices = allocArray<VERTEX>(3)
            val v0 = interpretCPointer<VERTEX>(vertices[0].rawPtr)!!.pointed
            v0.x = 0.0f
            v0.y = 0.5f
            v0.z = 0.0f
            v0.r = 1.0f
            v0.g = 0.0f
            v0.b = 0.0f
            v0.a = 1.0f

            val v1 = interpretCPointer<VERTEX>(vertices[1].rawPtr)!!.pointed
            v1.x = -0.5f
            v1.y = -0.5f
            v1.z = 0.0f
            v1.r = 0.0f
            v1.g = 1.0f
            v1.b = 0.0f
            v1.a = 1.0f

            val v2 = interpretCPointer<VERTEX>(vertices[2].rawPtr)!!.pointed
            v2.x = 0.5f
            v2.y = -0.5f
            v2.z = 0.0f
            v2.r = 0.0f
            v2.g = 0.0f
            v2.b = 1.0f
            v2.a = 1.0f

            memcpy(mappedVar.value, vertices, vertexBufferSize.toULong())
        }

        // ID3D12Resource::Unmap (vtable #9)
        val unmapFunc = comMethod(g_vertexBuffer, 9)
            ?.reinterpret<CFunction<(COpaquePointer?, UInt, CPointer<D3D12_RANGE>?) -> Unit>>()
        unmapFunc?.invoke(g_vertexBuffer, 0u, null)

        // ID3D12Resource::GetGPUVirtualAddress (vtable #11)
        val getGpuAddrFunc = comMethod(g_vertexBuffer, 11)
            ?.reinterpret<CFunction<(COpaquePointer?) -> ULong>>()
        val gpuAddr = getGpuAddrFunc?.invoke(g_vertexBuffer) ?: 0u

        g_vertexBufferViewPtr = nativeHeap.alloc<D3D12_VERTEX_BUFFER_VIEW>().ptr
        g_vertexBufferViewPtr!!.pointed.BufferLocation = gpuAddr
        g_vertexBufferViewPtr!!.pointed.SizeInBytes = vertexBufferSize.toUInt()
        g_vertexBufferViewPtr!!.pointed.StrideInBytes = VERTEX.size.toUInt()
        debugOutput("[initD3D12] Vertex buffer created")

        // ===== Create Fence =====
        debugOutput("[initD3D12] Creating fence...")
        val fenceVar = alloc<COpaquePointerVar>()
        val iidFence = alloc<GUID>()
        initIID_ID3D12Fence(iidFence)
        // ID3D12Device::CreateFence (vtable #36)
        val createFenceFunc = comMethod(g_device, 36)
            ?.reinterpret<CFunction<(COpaquePointer?, ULong, UInt, CPointer<GUID>?, CPointer<COpaquePointerVar>?) -> Int>>()
        val hrFence = createFenceFunc?.invoke(g_device, 0u, 0u, iidFence.ptr, fenceVar.ptr) ?: -1
        if (hrFence != 0) {
            debugOutput("[initD3D12] ERROR: CreateFence failed: HRESULT=0x${toHex(hrFence.toLong())}")
            return false
        }
        g_fence = fenceVar.value
        g_fenceEvent = CreateEventW(null, 0, 0, null)

        debugOutput("[initD3D12] DirectX 12 pipeline initialized")
    }
    
    return true
}

private fun getRtvHandle(index: UInt): ULong {
    // Use cached heap start. Calling GetCPUDescriptorHandleForHeapStart() repeatedly via a raw vtable
    // is fragile in Kotlin/Native due to ABI edge cases, so we compute from the cached base.
    return g_rtvHeapStartValue + (index.toULong() * g_rtvDescriptorSize.toULong())
}

private fun waitForPreviousFrame() {
    val fence = g_fence ?: return
    val queue = g_commandQueue ?: return

    // ID3D12CommandQueue::Signal (vtable #14)
    val signalFunc = comMethod(queue, 14)
        ?.reinterpret<CFunction<(COpaquePointer?, COpaquePointer?, ULong) -> Int>>()
    // ID3D12Fence::SetEventOnCompletion (vtable #9)
    val setEventFunc = comMethod(fence, 9)
        ?.reinterpret<CFunction<(COpaquePointer?, ULong, HANDLE?) -> Int>>()
    // ID3D12Fence::GetCompletedValue (vtable #8)
    val getCompletedFunc = comMethod(fence, 8)
        ?.reinterpret<CFunction<(COpaquePointer?) -> ULong>>()

    val fenceToWait = g_fenceValue
    signalFunc?.invoke(queue, fence, fenceToWait)
    g_fenceValue++

    val completed = getCompletedFunc?.invoke(fence) ?: 0u
    if (completed < fenceToWait) {
        setEventFunc?.invoke(fence, fenceToWait, g_fenceEvent)
        WaitForSingleObject(g_fenceEvent, INFINITE)
    }

    g_frameIndex = (g_frameIndex + 1u) % FRAME_COUNT
}

// ============================================================
// Cleanup
// ============================================================
private fun cleanup() {
    debugOutput("[cleanup] START")
    
    releaseComObject(g_fence)
    g_fence = null

    releaseComObject(g_vertexBuffer)
    g_vertexBuffer = null

    if (g_vertexBufferViewPtr != null) {
        nativeHeap.free(g_vertexBufferViewPtr!!)
        g_vertexBufferViewPtr = null
    }
    
    releaseComObject(g_pipelineState)
    g_pipelineState = null
    
    releaseComObject(g_rootSignature)
    g_rootSignature = null
    
    releaseComObject(g_commandList)
    g_commandList = null
    
    releaseComObject(g_commandAllocator)
    g_commandAllocator = null
    
    releaseComObject(g_rtvHeap)
    g_rtvHeap = null
    
    for (i in 0 until FRAME_COUNT.toInt()) {
        releaseComObject(g_renderTargets[i])
        g_renderTargets[i] = null
    }
    
    releaseComObject(g_swapChain)
    g_swapChain = null
    
    releaseComObject(g_commandQueue)
    g_commandQueue = null
    
    releaseComObject(g_device)
    g_device = null
    
    if (g_fenceEvent != null) {
        CloseHandle(g_fenceEvent)
        g_fenceEvent = null
    }
    
    if (g_hCompiler != null) {
        FreeLibrary(g_hCompiler)
        g_hCompiler = null
    }
    
    if (g_hDXGI != null) {
        FreeLibrary(g_hDXGI)
        g_hDXGI = null
    }
    
    if (g_hD3D12 != null) {
        FreeLibrary(g_hD3D12)
        g_hD3D12 = null
    }
    
    debugOutput("[cleanup] COMPLETE")
}

// ============================================================
// Rendering
// ============================================================
private var renderCount = 0
private fun render() {
    if (g_device == null || g_commandList == null || g_commandAllocator == null || g_pipelineState == null || g_rootSignature == null) {
        return
    }

    if (renderCount == 0) {
        debugOutput("[render] First frame rendering")
    }

    // ID3D12CommandAllocator::Reset (vtable #8)
    val resetAllocFunc = comMethod(g_commandAllocator, 8)
        ?.reinterpret<CFunction<(COpaquePointer?) -> Int>>()
    // ID3D12GraphicsCommandList::Reset (vtable #10)
    val resetCmdFunc = comMethod(g_commandList, 10)
        ?.reinterpret<CFunction<(COpaquePointer?, COpaquePointer?, COpaquePointer?) -> Int>>()
    // ID3D12GraphicsCommandList::Close (vtable #9)
    val closeFunc = comMethod(g_commandList, 9)
        ?.reinterpret<CFunction<(COpaquePointer?) -> Int>>()

    resetAllocFunc?.invoke(g_commandAllocator)
    resetCmdFunc?.invoke(g_commandList, g_commandAllocator, g_pipelineState)

    // ID3D12GraphicsCommandList::SetGraphicsRootSignature (vtable #30)
    val setRootSigFunc = comMethod(g_commandList, 30)
        ?.reinterpret<CFunction<(COpaquePointer?, COpaquePointer?) -> Unit>>()
    setRootSigFunc?.invoke(g_commandList, g_rootSignature)

    memScoped {
        val viewport = alloc<D3D12_VIEWPORT>()
        viewport.TopLeftX = 0.0f
        viewport.TopLeftY = 0.0f
        viewport.Width = 640.0f
        viewport.Height = 480.0f
        viewport.MinDepth = 0.0f
        viewport.MaxDepth = 1.0f

        val scissor = alloc<D3D12_RECT>()
        scissor.left = 0
        scissor.top = 0
        scissor.right = 640
        scissor.bottom = 480

        // ID3D12GraphicsCommandList::RSSetViewports (vtable #21)
        val rsViewports = comMethod(g_commandList, 21)
            ?.reinterpret<CFunction<(COpaquePointer?, UInt, CPointer<D3D12_VIEWPORT>?) -> Unit>>()
        // ID3D12GraphicsCommandList::RSSetScissorRects (vtable #22)
        val rsScissors = comMethod(g_commandList, 22)
            ?.reinterpret<CFunction<(COpaquePointer?, UInt, CPointer<D3D12_RECT>?) -> Unit>>()
        rsViewports?.invoke(g_commandList, 1u, viewport.ptr)
        rsScissors?.invoke(g_commandList, 1u, scissor.ptr)

        val barrier = alloc<D3D12_RESOURCE_BARRIER>()
        barrier.Type = D3D12_RESOURCE_BARRIER_TYPE_TRANSITION
        barrier.Flags = D3D12_RESOURCE_BARRIER_FLAG_NONE
        val transition = barrier.transition()
        transition.pResource = g_renderTargets[g_frameIndex.toInt()]
        transition.Subresource = D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES
        transition.StateBefore = D3D12_RESOURCE_STATE_PRESENT
        transition.StateAfter = D3D12_RESOURCE_STATE_RENDER_TARGET

        // ID3D12GraphicsCommandList::ResourceBarrier (vtable #26)
        val resourceBarrierFunc = comMethod(g_commandList, 26)
            ?.reinterpret<CFunction<(COpaquePointer?, UInt, CPointer<D3D12_RESOURCE_BARRIER>?) -> Unit>>()
        resourceBarrierFunc?.invoke(g_commandList, 1u, barrier.ptr)

        val rtvHandleValue = getRtvHandle(g_frameIndex)
        val rtvHandle = alloc<D3D12_CPU_DESCRIPTOR_HANDLE>()
        rtvHandle.value = rtvHandleValue

        // ID3D12GraphicsCommandList::OMSetRenderTargets (vtable #46)
        val omSetRTFunc = comMethod(g_commandList, 46)
            ?.reinterpret<CFunction<(COpaquePointer?, UInt, CPointer<D3D12_CPU_DESCRIPTOR_HANDLE>?, Int, COpaquePointer?) -> Unit>>()
        omSetRTFunc?.invoke(g_commandList, 1u, rtvHandle.ptr, 0, null)

        // ID3D12GraphicsCommandList::ClearRenderTargetView (vtable #48)
        val clearRTFunc = comMethod(g_commandList, 48)
            ?.reinterpret<CFunction<(COpaquePointer?, ULong, CPointer<FloatVar>?, UInt, CPointer<D3D12_RECT>?) -> Unit>>()
        val clearColor = allocArray<FloatVar>(4)
        clearColor[0] = 0.1f
        clearColor[1] = 0.1f
        clearColor[2] = 0.3f
        clearColor[3] = 1.0f
        clearRTFunc?.invoke(g_commandList, rtvHandleValue, clearColor, 0u, null)

        // ID3D12GraphicsCommandList::IASetPrimitiveTopology (vtable #20)
        val iaSetTopoFunc = comMethod(g_commandList, 20)
            ?.reinterpret<CFunction<(COpaquePointer?, UInt) -> Unit>>()
        iaSetTopoFunc?.invoke(g_commandList, D3D_PRIMITIVE_TOPOLOGY_TRIANGLELIST)

        // ID3D12GraphicsCommandList::IASetVertexBuffers (vtable #44)
        val iaSetVBFunc = comMethod(g_commandList, 44)
            ?.reinterpret<CFunction<(COpaquePointer?, UInt, UInt, CPointer<D3D12_VERTEX_BUFFER_VIEW>?) -> Unit>>()
        iaSetVBFunc?.invoke(g_commandList, 0u, 1u, g_vertexBufferViewPtr)

        // ID3D12GraphicsCommandList::DrawInstanced (vtable #12)
        val drawFunc = comMethod(g_commandList, 12)
            ?.reinterpret<CFunction<(COpaquePointer?, UInt, UInt, UInt, UInt) -> Unit>>()
        drawFunc?.invoke(g_commandList, 3u, 1u, 0u, 0u)

        transition.StateBefore = D3D12_RESOURCE_STATE_RENDER_TARGET
        transition.StateAfter = D3D12_RESOURCE_STATE_PRESENT
        resourceBarrierFunc?.invoke(g_commandList, 1u, barrier.ptr)
    }

    closeFunc?.invoke(g_commandList)

    // ID3D12CommandQueue::ExecuteCommandLists (vtable #10)
    val executeFunc = comMethod(g_commandQueue, 10)
        ?.reinterpret<CFunction<(COpaquePointer?, UInt, CPointer<COpaquePointerVar>?) -> Unit>>()
    memScoped {
        val listVar = alloc<COpaquePointerVar>()
        listVar.value = g_commandList
        executeFunc?.invoke(g_commandQueue, 1u, listVar.ptr)
    }

    // IDXGISwapChain::Present (vtable #8)
    val presentFunc = comMethod(g_swapChain, 8)
        ?.reinterpret<CFunction<(COpaquePointer?, UInt, UInt) -> Int>>()
    presentFunc?.invoke(g_swapChain, 1u, 0u)

    waitForPreviousFrame()

    renderCount++
}

// ============================================================
// Window Callback
// ============================================================
private val wndProcCallback = staticCFunction { hwnd: HWND?, msg: UInt, wParam: WPARAM, lParam: LPARAM ->
    when (msg.toInt()) {
        WM_PAINT -> {
            DefWindowProcW(hwnd, msg, wParam, lParam)
        }
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
    debugOutput("[MAIN] DirectX 12 Hello Triangle (Minimal Framework)")
    debugOutput("[MAIN] Debug output enabled - check DebugView for detailed messages")
    
    memScoped {
        val hInstance = GetModuleHandleW(null)
        val className = "DirectX12Window"
        val windowName = "Hello, DirectX 12!"
        
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
            debugOutput("[MAIN] ERROR: CreateWindowExW failed")
            return
        }
        
        debugOutput("[MAIN] Window created")
        
        // Initialize DirectX 12
        if (!initD3D12(hwnd)) {
            debugOutput("[MAIN] ERROR: initD3D12 failed")
            debugOutput("[MAIN] Please check DebugView for detailed DirectX 12 error messages")
            return
        }
        
        ShowWindow(hwnd, SW_SHOW)
        UpdateWindow(hwnd)
        
        // Message loop
        val msg = alloc<MSG>()
        debugOutput("[MAIN] Entering message loop...")
        
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
        
        debugOutput("[MAIN] Message loop ended")
    }
}