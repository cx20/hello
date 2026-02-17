@file:OptIn(kotlinx.cinterop.ExperimentalForeignApi::class)

import kotlinx.cinterop.*
import platform.windows.*
import platform.posix.memcpy
import platform.posix.memset
import kotlin.math.cos
import kotlin.math.sin

// ============================================================
// DirectX 12 Harmonograph with Compute Shader
// ============================================================

const val FRAME_COUNT = 2u
const val NUM_VERTICES = 500000

// DXGI Constants
const val DXGI_FORMAT_R8G8B8A8_UNORM: UInt = 28u
const val DXGI_FORMAT_R32G32B32A32_FLOAT: UInt = 2u
const val DXGI_FORMAT_UNKNOWN: UInt = 0u
const val DXGI_USAGE_RENDER_TARGET_OUTPUT: UInt = 0x00000020u
const val DXGI_SWAP_EFFECT_FLIP_DISCARD: UInt = 4u

// D3D12 Constants
const val D3D_FEATURE_LEVEL_11_0: UInt = 0xB000u
const val D3D12_COMMAND_QUEUE_FLAG_NONE: UInt = 0u
const val D3D12_COMMAND_LIST_TYPE_DIRECT: UInt = 0u
const val D3D12_DESCRIPTOR_HEAP_TYPE_RTV: UInt = 2u
const val D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV: UInt = 0u
const val D3D12_DESCRIPTOR_HEAP_FLAG_NONE: UInt = 0u
const val D3D12_DESCRIPTOR_HEAP_FLAG_SHADER_VISIBLE: UInt = 1u
const val D3D12_INPUT_CLASSIFICATION_PER_VERTEX_DATA: UInt = 0u
const val D3D12_RESOURCE_STATE_RENDER_TARGET: UInt = 0x4u
const val D3D12_RESOURCE_STATE_PRESENT: UInt = 0u
const val D3D12_RESOURCE_STATE_GENERIC_READ: UInt = 0x1u
const val D3D12_RESOURCE_STATE_UNORDERED_ACCESS: UInt = 0x8u
const val D3D12_RESOURCE_STATE_NON_PIXEL_SHADER_RESOURCE: UInt = 0x40u
const val D3D12_RESOURCE_BARRIER_TYPE_TRANSITION: UInt = 0u
const val D3D12_RESOURCE_BARRIER_TYPE_ALIASING: UInt = 1u
const val D3D12_RESOURCE_BARRIER_TYPE_UAV: UInt = 2u
const val D3D12_RESOURCE_BARRIER_FLAG_NONE: UInt = 0u
const val D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES: UInt = 0xFFFFFFFFu
const val D3D12_HEAP_TYPE_DEFAULT: UInt = 1u
const val D3D12_HEAP_TYPE_UPLOAD: UInt = 2u
const val D3D12_HEAP_FLAG_NONE: UInt = 0u
const val D3D12_RESOURCE_DIMENSION_BUFFER: UInt = 1u
const val D3D12_TEXTURE_LAYOUT_ROW_MAJOR: UInt = 1u
const val D3D12_RESOURCE_FLAG_NONE: UInt = 0u
const val D3D12_RESOURCE_FLAG_ALLOW_UNORDERED_ACCESS: UInt = 0x4u
const val D3D12_PRIMITIVE_TOPOLOGY_TYPE_LINE: UInt = 2u
const val D3D_PRIMITIVE_TOPOLOGY_LINESTRIP: UInt = 3u
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

// Root Parameter Types
const val D3D12_ROOT_PARAMETER_TYPE_DESCRIPTOR_TABLE: UInt = 0u
const val D3D12_ROOT_PARAMETER_TYPE_32BIT_CONSTANTS: UInt = 1u
const val D3D12_ROOT_PARAMETER_TYPE_CBV: UInt = 2u
const val D3D12_ROOT_PARAMETER_TYPE_SRV: UInt = 3u
const val D3D12_ROOT_PARAMETER_TYPE_UAV: UInt = 4u

// Descriptor Range Types
const val D3D12_DESCRIPTOR_RANGE_TYPE_SRV: UInt = 0u
const val D3D12_DESCRIPTOR_RANGE_TYPE_UAV: UInt = 1u
const val D3D12_DESCRIPTOR_RANGE_TYPE_CBV: UInt = 2u

// Shader Visibility
const val D3D12_SHADER_VISIBILITY_ALL: UInt = 0u
const val D3D12_SHADER_VISIBILITY_VERTEX: UInt = 1u

// Window Constants
const val WM_DESTROY = 0x0002
const val WM_CLOSE = 0x0010
const val WM_QUIT = 0x0012
const val WM_PAINT = 0x000F
const val WM_KEYUP = 0x0101
const val VK_ESCAPE = 0x1B
const val CS_HREDRAW = 0x0002
const val CS_VREDRAW = 0x0001
const val WS_OVERLAPPEDWINDOW = 0x00CF0000u
val CW_USEDEFAULT = 0x80000000u.toInt()
const val SW_SHOW = 5
const val PM_REMOVE = 0x0001u
const val IDC_ARROW = 32512
const val COLOR_WINDOW = 5

const val WINDOW_WIDTH = 640
const val WINDOW_HEIGHT = 480

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
var g_computeRootSignature: COpaquePointer? = null
var g_pipelineState: COpaquePointer? = null
var g_computePipelineState: COpaquePointer? = null
var g_rtvHeap: COpaquePointer? = null
var g_srvUavHeap: COpaquePointer? = null
var g_fence: COpaquePointer? = null
var g_positionBuffer: COpaquePointer? = null
var g_colorBuffer: COpaquePointer? = null
var g_constantBuffer: COpaquePointer? = null
var g_fenceEvent: HANDLE? = null
var g_fenceValue: ULong = 1u
var g_frameIndex: UInt = 0u
var g_rtvDescriptorSize: UInt = 0u
var g_srvUavDescriptorSize: UInt = 0u
var g_rtvHeapStartValue: ULong = 0u
var g_srvUavHeapStartCpu: ULong = 0u
var g_srvUavHeapStartGpu: ULong = 0u
var g_renderTargets = arrayOfNulls<COpaquePointer>(2)
var g_time: Float = 0.0f

// Harmonograph parameters
var g_A1 = 50.0f
var g_f1 = 2.0f
var g_p1 = 1.0f / 16.0f
var g_d1 = 0.02f
var g_A2 = 50.0f
var g_f2 = 2.0f
var g_p2 = 3.0f / 2.0f
var g_d2 = 0.0315f
var g_A3 = 50.0f
var g_f3 = 2.0f
var g_p3 = 13.0f / 15.0f
var g_d3 = 0.02f
var g_A4 = 50.0f
var g_f4 = 2.0f
var g_p4 = 1.0f
var g_d4 = 0.02f

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
// HLSL Compute Shader Code
// ============================================================
private val g_computeShaderCode = """
// Harmonograph Compute Shader

cbuffer HarmonographParams : register(b0)
{
    float A1, f1, p1, d1;
    float A2, f2, p2, d2;
    float A3, f3, p3, d3;
    float A4, f4, p4, d4;
    uint max_num;
    float3 padding;
    float2 resolution;
    float2 padding2;
};

RWStructuredBuffer<float4> positionBuffer : register(u0);
RWStructuredBuffer<float4> colorBuffer : register(u1);

float3 hsv2rgb(float h, float s, float v)
{
    float c = v * s;
    float hp = h / 60.0;
    float x = c * (1.0 - abs(fmod(hp, 2.0) - 1.0));
    float3 rgb;

    if (hp < 1.0)
        rgb = float3(c, x, 0.0);
    else if (hp < 2.0)
        rgb = float3(x, c, 0.0);
    else if (hp < 3.0)
        rgb = float3(0.0, c, x);
    else if (hp < 4.0)
        rgb = float3(0.0, x, c);
    else if (hp < 5.0)
        rgb = float3(x, 0.0, c);
    else
        rgb = float3(c, 0.0, x);

    float m = v - c;
    return rgb + float3(m, m, m);
}

[numthreads(64, 1, 1)]
void CSMain(uint3 dispatchThreadID : SV_DispatchThreadID)
{
    uint idx = dispatchThreadID.x;
    if (idx >= max_num)
        return;

    float t = (float)idx * 0.001;
    float PI = 3.14159265;

    float x = A1 * sin(f1 * t + PI * p1) * exp(-d1 * t) +
              A2 * sin(f2 * t + PI * p2) * exp(-d2 * t);

    float y = A3 * sin(f3 * t + PI * p3) * exp(-d3 * t) +
              A4 * sin(f4 * t + PI * p4) * exp(-d4 * t);

    float z = A1 * cos(f1 * t + PI * p1) * exp(-d1 * t) +
              A2 * cos(f2 * t + PI * p2) * exp(-d2 * t);

    positionBuffer[idx] = float4(x, y, z, 1.0);

    float hue = fmod((t / 20.0) * 360.0, 360.0);
    float3 rgb = hsv2rgb(hue, 1.0, 1.0);
    colorBuffer[idx] = float4(rgb, 1.0);
}
""".trimIndent()

// ============================================================
// HLSL Graphics Shader Code
// ============================================================
private val g_graphicsShaderCode = """
// Harmonograph Graphics Shaders

cbuffer HarmonographParams : register(b0)
{
    float A1, f1, p1, d1;
    float A2, f2, p2, d2;
    float A3, f3, p3, d3;
    float A4, f4, p4, d4;
    uint max_num;
    float3 padding;
    float2 resolution;
    float2 padding2;
};

StructuredBuffer<float4> positionSRV : register(t0);
StructuredBuffer<float4> colorSRV : register(t1);

struct VSOutput
{
    float4 position : SV_POSITION;
    float4 color : COLOR;
};

float4x4 perspective(float fov, float aspect, float nearZ, float farZ)
{
    float rad = radians(fov / 2.0);
    float v = 1.0 / tan(rad);
    float u = v / aspect;
    float w = nearZ - farZ;

    return float4x4(
        u, 0, 0, 0,
        0, v, 0, 0,
        0, 0, (nearZ + farZ) / w, -1,
        0, 0, (nearZ * farZ * 2.0) / w, 0
    );
}

float4x4 lookAt(float3 eye, float3 center, float3 up)
{
    float3 w = normalize(eye - center);
    float3 u = normalize(cross(up, w));
    float3 v = cross(w, u);

    return float4x4(
        u.x, v.x, w.x, 0,
        u.y, v.y, w.y, 0,
        u.z, v.z, w.z, 0,
        -dot(u, eye), -dot(v, eye), -dot(w, eye), 1
    );
}

VSOutput VSMain(uint vertexID : SV_VertexID)
{
    VSOutput output;

    float4 pos = positionSRV[vertexID];

    float4x4 proj = perspective(45.0, resolution.x / resolution.y, 0.1, 200.0);
    
    // Fixed camera position
    float3 cameraPos = float3(0, 5, 10);
    float3 cameraTarget = float3(0, 0, 0);
    float3 cameraUp = float3(0, 1, 0);
    float4x4 view = lookAt(cameraPos, cameraTarget, cameraUp);

    output.position = mul(mul(pos, view), proj);
    output.color = colorSRV[vertexID];

    return output;
}

float4 PSMain(VSOutput input) : SV_TARGET
{
    return input.color;
}
""".trimIndent()

// ============================================================
// Shader Compilation Helper
// ============================================================
private fun compileShader(code: String, entry: String, target: String): COpaquePointer? {
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
        
        val hr = code.cstr.getPointer(this).let { codePtr ->
            entry.cstr.getPointer(this).let { entryPtr ->
                target.cstr.getPointer(this).let { targetPtr ->
                    compileFunc.invoke(
                        codePtr as COpaquePointer,
                        code.length.toULong(),
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
                val errPtr = blobGetPointer(errVar.value)
                if (errPtr != null) {
                    val errMsg = errPtr.reinterpret<ByteVar>().toKString()
                    debugOutput("[Shader] Error message: $errMsg")
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
// Structure Definitions
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

class D3D12_GPU_DESCRIPTOR_HANDLE(rawPtr: NativePtr) : CStructVar(rawPtr) {
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

    fun uav(): D3D12_RESOURCE_UAV_BARRIER {
        val addr = this.ptr.rawValue + 8L
        return interpretCPointer<D3D12_RESOURCE_UAV_BARRIER>(addr)!!.pointed
    }
}

class D3D12_RESOURCE_UAV_BARRIER(rawPtr: NativePtr) : CStructVar(rawPtr) {
    companion object : Type(8, 8)

    var pResource: COpaquePointer?
        get() = this.ptr.reinterpret<COpaquePointerVar>().pointed.value
        set(value) { this.ptr.reinterpret<COpaquePointerVar>().pointed.value = value }
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
        val offset = 8 + (index * D3D12_RENDER_TARGET_BLEND_DESC.size)
        return interpretCPointer<D3D12_RENDER_TARGET_BLEND_DESC>(this.ptr.rawValue + offset.toLong())!!.pointed
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

class D3D12_INPUT_LAYOUT_DESC(rawPtr: NativePtr) : CStructVar(rawPtr) {
    companion object : Type(16, 8)

    var pInputElementDescs: COpaquePointer?
        get() = this.ptr.reinterpret<COpaquePointerVar>().pointed.value
        set(value) { this.ptr.reinterpret<COpaquePointerVar>().pointed.value = value }

    var NumElements: UInt
        get() = this.ptr.rawValue.plus(8).toLong().toCPointer<UIntVar>()!!.pointed.value
        set(value) { this.ptr.rawValue.plus(8).toLong().toCPointer<UIntVar>()!!.pointed.value = value }
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

// Compute Pipeline State Desc (size = 56)
class D3D12_COMPUTE_PIPELINE_STATE_DESC(rawPtr: NativePtr) : CStructVar(rawPtr) {
    companion object : Type(56, 8)

    var pRootSignature: COpaquePointer?
        get() = this.ptr.reinterpret<COpaquePointerVar>().pointed.value
        set(value) { this.ptr.reinterpret<COpaquePointerVar>().pointed.value = value }

    fun cs(): D3D12_SHADER_BYTECODE {
        val addr = this.ptr.rawValue + 8L
        return interpretCPointer<D3D12_SHADER_BYTECODE>(addr)!!.pointed
    }

    var NodeMask: UInt
        get() = interpretCPointer<UIntVar>(this.ptr.rawValue + 24)!!.pointed.value
        set(value) { interpretCPointer<UIntVar>(this.ptr.rawValue + 24)!!.pointed.value = value }

    fun cachedPSO(): D3D12_CACHED_PIPELINE_STATE {
        val addr = this.ptr.rawValue + 32L
        return interpretCPointer<D3D12_CACHED_PIPELINE_STATE>(addr)!!.pointed
    }

    var Flags: UInt
        get() = interpretCPointer<UIntVar>(this.ptr.rawValue + 48)!!.pointed.value
        set(value) { interpretCPointer<UIntVar>(this.ptr.rawValue + 48)!!.pointed.value = value }
}

// Root Signature structures
class D3D12_DESCRIPTOR_RANGE(rawPtr: NativePtr) : CStructVar(rawPtr) {
    companion object : Type(24, 4)

    var RangeType: UInt
        get() = this.ptr.reinterpret<UIntVar>().pointed.value
        set(value) { this.ptr.reinterpret<UIntVar>().pointed.value = value }

    var NumDescriptors: UInt
        get() = interpretCPointer<UIntVar>(this.ptr.rawValue + 4)!!.pointed.value
        set(value) { interpretCPointer<UIntVar>(this.ptr.rawValue + 4)!!.pointed.value = value }

    var BaseShaderRegister: UInt
        get() = interpretCPointer<UIntVar>(this.ptr.rawValue + 8)!!.pointed.value
        set(value) { interpretCPointer<UIntVar>(this.ptr.rawValue + 8)!!.pointed.value = value }

    var RegisterSpace: UInt
        get() = interpretCPointer<UIntVar>(this.ptr.rawValue + 12)!!.pointed.value
        set(value) { interpretCPointer<UIntVar>(this.ptr.rawValue + 12)!!.pointed.value = value }

    var OffsetInDescriptorsFromTableStart: UInt
        get() = interpretCPointer<UIntVar>(this.ptr.rawValue + 16)!!.pointed.value
        set(value) { interpretCPointer<UIntVar>(this.ptr.rawValue + 16)!!.pointed.value = value }
}

class D3D12_ROOT_DESCRIPTOR_TABLE(rawPtr: NativePtr) : CStructVar(rawPtr) {
    companion object : Type(16, 8)

    var NumDescriptorRanges: UInt
        get() = this.ptr.reinterpret<UIntVar>().pointed.value
        set(value) { this.ptr.reinterpret<UIntVar>().pointed.value = value }

    var pDescriptorRanges: CPointer<D3D12_DESCRIPTOR_RANGE>?
        get() = interpretCPointer<CPointerVar<D3D12_DESCRIPTOR_RANGE>>(this.ptr.rawValue + 8)!!.pointed.value
        set(value) { interpretCPointer<CPointerVar<D3D12_DESCRIPTOR_RANGE>>(this.ptr.rawValue + 8)!!.pointed.value = value }
}

class D3D12_ROOT_CONSTANTS(rawPtr: NativePtr) : CStructVar(rawPtr) {
    companion object : Type(12, 4)

    var ShaderRegister: UInt
        get() = this.ptr.reinterpret<UIntVar>().pointed.value
        set(value) { this.ptr.reinterpret<UIntVar>().pointed.value = value }

    var RegisterSpace: UInt
        get() = interpretCPointer<UIntVar>(this.ptr.rawValue + 4)!!.pointed.value
        set(value) { interpretCPointer<UIntVar>(this.ptr.rawValue + 4)!!.pointed.value = value }

    var Num32BitValues: UInt
        get() = interpretCPointer<UIntVar>(this.ptr.rawValue + 8)!!.pointed.value
        set(value) { interpretCPointer<UIntVar>(this.ptr.rawValue + 8)!!.pointed.value = value }
}

class D3D12_ROOT_PARAMETER(rawPtr: NativePtr) : CStructVar(rawPtr) {
    companion object : Type(32, 8)

    var ParameterType: UInt
        get() = this.ptr.reinterpret<UIntVar>().pointed.value
        set(value) { this.ptr.reinterpret<UIntVar>().pointed.value = value }

    fun descriptorTable(): D3D12_ROOT_DESCRIPTOR_TABLE {
        val addr = this.ptr.rawValue + 8L
        return interpretCPointer<D3D12_ROOT_DESCRIPTOR_TABLE>(addr)!!.pointed
    }

    fun constants(): D3D12_ROOT_CONSTANTS {
        val addr = this.ptr.rawValue + 8L
        return interpretCPointer<D3D12_ROOT_CONSTANTS>(addr)!!.pointed
    }

    var ShaderVisibility: UInt
        get() = interpretCPointer<UIntVar>(this.ptr.rawValue + 24)!!.pointed.value
        set(value) { interpretCPointer<UIntVar>(this.ptr.rawValue + 24)!!.pointed.value = value }
}

class D3D12_ROOT_SIGNATURE_DESC(rawPtr: NativePtr) : CStructVar(rawPtr) {
    companion object : Type(40, 8)

    var NumParameters: UInt
        get() = this.ptr.reinterpret<UIntVar>().pointed.value
        set(value) { this.ptr.reinterpret<UIntVar>().pointed.value = value }

    var pParameters: CPointer<D3D12_ROOT_PARAMETER>?
        get() = interpretCPointer<CPointerVar<D3D12_ROOT_PARAMETER>>(this.ptr.rawValue + 8)!!.pointed.value
        set(value) { interpretCPointer<CPointerVar<D3D12_ROOT_PARAMETER>>(this.ptr.rawValue + 8)!!.pointed.value = value }

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

// Buffer View structures
class D3D12_UNORDERED_ACCESS_VIEW_DESC(rawPtr: NativePtr) : CStructVar(rawPtr) {
    companion object : Type(40, 8)

    var Format: UInt
        get() = this.ptr.reinterpret<UIntVar>().pointed.value
        set(value) { this.ptr.reinterpret<UIntVar>().pointed.value = value }

    var ViewDimension: UInt
        get() = interpretCPointer<UIntVar>(this.ptr.rawValue + 4)!!.pointed.value
        set(value) { interpretCPointer<UIntVar>(this.ptr.rawValue + 4)!!.pointed.value = value }

    // For Buffer view (union starts at offset 8)
    var FirstElement: ULong
        get() = interpretCPointer<ULongVar>(this.ptr.rawValue + 8)!!.pointed.value
        set(value) { interpretCPointer<ULongVar>(this.ptr.rawValue + 8)!!.pointed.value = value }

    var NumElements: UInt
        get() = interpretCPointer<UIntVar>(this.ptr.rawValue + 16)!!.pointed.value
        set(value) { interpretCPointer<UIntVar>(this.ptr.rawValue + 16)!!.pointed.value = value }

    var StructureByteStride: UInt
        get() = interpretCPointer<UIntVar>(this.ptr.rawValue + 20)!!.pointed.value
        set(value) { interpretCPointer<UIntVar>(this.ptr.rawValue + 20)!!.pointed.value = value }

    var CounterOffsetInBytes: ULong
        get() = interpretCPointer<ULongVar>(this.ptr.rawValue + 24)!!.pointed.value
        set(value) { interpretCPointer<ULongVar>(this.ptr.rawValue + 24)!!.pointed.value = value }

    var Flags: UInt
        get() = interpretCPointer<UIntVar>(this.ptr.rawValue + 32)!!.pointed.value
        set(value) { interpretCPointer<UIntVar>(this.ptr.rawValue + 32)!!.pointed.value = value }
}

class D3D12_SHADER_RESOURCE_VIEW_DESC(rawPtr: NativePtr) : CStructVar(rawPtr) {
    companion object : Type(40, 8)

    var Format: UInt
        get() = this.ptr.reinterpret<UIntVar>().pointed.value
        set(value) { this.ptr.reinterpret<UIntVar>().pointed.value = value }

    var ViewDimension: UInt
        get() = interpretCPointer<UIntVar>(this.ptr.rawValue + 4)!!.pointed.value
        set(value) { interpretCPointer<UIntVar>(this.ptr.rawValue + 4)!!.pointed.value = value }

    var Shader4ComponentMapping: UInt
        get() = interpretCPointer<UIntVar>(this.ptr.rawValue + 8)!!.pointed.value
        set(value) { interpretCPointer<UIntVar>(this.ptr.rawValue + 8)!!.pointed.value = value }

    // For Buffer view (union starts at offset 16 with padding)
    var FirstElement: ULong
        get() = interpretCPointer<ULongVar>(this.ptr.rawValue + 16)!!.pointed.value
        set(value) { interpretCPointer<ULongVar>(this.ptr.rawValue + 16)!!.pointed.value = value }

    var NumElements: UInt
        get() = interpretCPointer<UIntVar>(this.ptr.rawValue + 24)!!.pointed.value
        set(value) { interpretCPointer<UIntVar>(this.ptr.rawValue + 24)!!.pointed.value = value }

    var StructureByteStride: UInt
        get() = interpretCPointer<UIntVar>(this.ptr.rawValue + 28)!!.pointed.value
        set(value) { interpretCPointer<UIntVar>(this.ptr.rawValue + 28)!!.pointed.value = value }

    var Flags: ULong
        get() = interpretCPointer<ULongVar>(this.ptr.rawValue + 32)!!.pointed.value
        set(value) { interpretCPointer<ULongVar>(this.ptr.rawValue + 32)!!.pointed.value = value }
}

// Constants
const val D3D12_UAV_DIMENSION_BUFFER: UInt = 1u
const val D3D12_SRV_DIMENSION_BUFFER: UInt = 1u
const val D3D12_DEFAULT_SHADER_4_COMPONENT_MAPPING: UInt = 0x00001688u

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

        debugOutput("[initD3D12] Loading dxgi.dll...")
        g_hDXGI = LoadLibraryW("dxgi.dll")
        if (g_hDXGI == null) {
            debugOutput("[initD3D12] ERROR: Failed to load dxgi.dll")
            return false
        }

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
                // ID3D12Debug::EnableDebugLayer (vtable #3)
                val enableDebugLayerFunc = comMethod(debugVar.value, 3)
                    ?.reinterpret<CFunction<(COpaquePointer?) -> Unit>>()
                enableDebugLayerFunc?.invoke(debugVar.value)
                debugOutput("[initD3D12] Debug layer enabled")
                releaseComObject(debugVar.value)
            }
        }

        // Create Device
        val createDeviceFunc = GetProcAddress(g_hD3D12, "D3D12CreateDevice")
        if (createDeviceFunc == null) {
            debugOutput("[initD3D12] ERROR: Failed to get D3D12CreateDevice")
            return false
        }

        val deviceVar = alloc<COpaquePointerVar>()
        val iidDevice = alloc<GUID>()
        initIID_ID3D12Device(iidDevice)

        val hrDevice = createDeviceFunc.reinterpret<CFunction<(COpaquePointer?, UInt, CPointer<GUID>?, CPointer<COpaquePointerVar>?) -> Int>>()
            .invoke(null, D3D_FEATURE_LEVEL_11_0, iidDevice.ptr, deviceVar.ptr)
        if (hrDevice != 0) {
            debugOutput("[initD3D12] ERROR: D3D12CreateDevice failed: HRESULT=0x${toHex(hrDevice.toLong())}")
            return false
        }
        g_device = deviceVar.value
        debugOutput("[initD3D12] Device created: 0x${toHex(g_device!!.rawValue.toLong())}")

        // Create Command Queue
        val queueDesc = alloc<D3D12_COMMAND_QUEUE_DESC>()
        queueDesc.Type = D3D12_COMMAND_LIST_TYPE_DIRECT
        queueDesc.Priority = 0
        queueDesc.Flags = D3D12_COMMAND_QUEUE_FLAG_NONE
        queueDesc.NodeMask = 0u

        val queueVar = alloc<COpaquePointerVar>()
        val iidQueue = alloc<GUID>()
        initIID_ID3D12CommandQueue(iidQueue)
        // ID3D12Device::CreateCommandQueue (vtable #8)
        val createQueueFunc = comMethod(g_device, 8)
            ?.reinterpret<CFunction<(COpaquePointer?, CPointer<D3D12_COMMAND_QUEUE_DESC>?, CPointer<GUID>?, CPointer<COpaquePointerVar>?) -> Int>>()
        val hrQueue = createQueueFunc?.invoke(g_device, queueDesc.ptr, iidQueue.ptr, queueVar.ptr) ?: -1
        if (hrQueue != 0) {
            debugOutput("[initD3D12] ERROR: CreateCommandQueue failed: HRESULT=0x${toHex(hrQueue.toLong())}")
            return false
        }
        g_commandQueue = queueVar.value
        debugOutput("[initD3D12] Command queue created")

        // Create DXGI Factory
        val createFactoryFunc = GetProcAddress(g_hDXGI, "CreateDXGIFactory1")
            ?.reinterpret<CFunction<(CPointer<GUID>?, CPointer<COpaquePointerVar>?) -> Int>>()
        if (createFactoryFunc == null) {
            debugOutput("[initD3D12] ERROR: CreateDXGIFactory1 not found")
            return false
        }

        val factoryVar = alloc<COpaquePointerVar>()
        val iidFactory = alloc<GUID>()
        initIID_IDXGIFactory4(iidFactory)
        val hrFactory = createFactoryFunc.invoke(iidFactory.ptr, factoryVar.ptr)
        if (hrFactory != 0) {
            debugOutput("[initD3D12] ERROR: CreateDXGIFactory1 failed")
            return false
        }
        val factory = factoryVar.value

        // Create Swap Chain
        val swapChainDesc = alloc<DXGI_SWAP_CHAIN_DESC1>()
        swapChainDesc.Width = WINDOW_WIDTH.toUInt()
        swapChainDesc.Height = WINDOW_HEIGHT.toUInt()
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

        val iidSwapChain3 = alloc<GUID>()
        initIID_IDXGISwapChain3(iidSwapChain3)
        val swapChain3 = queryInterface(swapChainVar.value, iidSwapChain3)
        if (swapChain3 == null) {
            g_swapChain = swapChainVar.value
        } else {
            g_swapChain = swapChain3
            releaseComObject(swapChainVar.value)
        }
        debugOutput("[initD3D12] Swap chain created")

        g_frameIndex = 0u

        // Create RTV Descriptor Heap
        val rtvHeapDesc = alloc<D3D12_DESCRIPTOR_HEAP_DESC>()
        rtvHeapDesc.Type = D3D12_DESCRIPTOR_HEAP_TYPE_RTV
        rtvHeapDesc.NumDescriptors = FRAME_COUNT
        rtvHeapDesc.Flags = D3D12_DESCRIPTOR_HEAP_FLAG_NONE
        rtvHeapDesc.NodeMask = 0u

        val rtvHeapVar = alloc<COpaquePointerVar>()
        val iidHeap = alloc<GUID>()
        initIID_ID3D12DescriptorHeap(iidHeap)
        // ID3D12Device::CreateDescriptorHeap (vtable #14)
        val createHeapFunc = comMethod(g_device, 14)
            ?.reinterpret<CFunction<(COpaquePointer?, CPointer<D3D12_DESCRIPTOR_HEAP_DESC>?, CPointer<GUID>?, CPointer<COpaquePointerVar>?) -> Int>>()
        val hrHeap = createHeapFunc?.invoke(g_device, rtvHeapDesc.ptr, iidHeap.ptr, rtvHeapVar.ptr) ?: -1
        if (hrHeap != 0) {
            debugOutput("[initD3D12] ERROR: CreateDescriptorHeap (RTV) failed")
            return false
        }
        g_rtvHeap = rtvHeapVar.value

        // ID3D12Device::GetDescriptorHandleIncrementSize (vtable #15)
        val getDescSizeFunc = comMethod(g_device, 15)
            ?.reinterpret<CFunction<(COpaquePointer?, UInt) -> UInt>>()
        g_rtvDescriptorSize = getDescSizeFunc?.invoke(g_device, D3D12_DESCRIPTOR_HEAP_TYPE_RTV) ?: 0u
        g_srvUavDescriptorSize = getDescSizeFunc?.invoke(g_device, D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV) ?: 0u

        // ID3D12DescriptorHeap::GetCPUDescriptorHandleForHeapStart (vtable #9)
        val rtvStartHandle = alloc<D3D12_CPU_DESCRIPTOR_HANDLE>()
        val getCpuStartFunc = comMethod(g_rtvHeap, 9)
            ?.reinterpret<CFunction<(COpaquePointer?, CPointer<D3D12_CPU_DESCRIPTOR_HANDLE>?) -> COpaquePointer?>>()
        getCpuStartFunc?.invoke(g_rtvHeap, rtvStartHandle.ptr)
        g_rtvHeapStartValue = rtvStartHandle.value

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
                debugOutput("[initD3D12] ERROR: GetBuffer($i) failed")
                return false
            }
            g_renderTargets[i] = backBufferVar.value

            val handleValue = g_rtvHeapStartValue + (i.toULong() * g_rtvDescriptorSize.toULong())
            createRTVFunc?.invoke(g_device, g_renderTargets[i], null, handleValue)
        }
        debugOutput("[initD3D12] Render target views created")

        // Create SRV/UAV Descriptor Heap (4 descriptors: 2 UAVs for compute, 2 SRVs for graphics)
        val srvUavHeapDesc = alloc<D3D12_DESCRIPTOR_HEAP_DESC>()
        srvUavHeapDesc.Type = D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV
        srvUavHeapDesc.NumDescriptors = 3u  // 2 UAVs + 1 CBV
        srvUavHeapDesc.Flags = D3D12_DESCRIPTOR_HEAP_FLAG_SHADER_VISIBLE
        srvUavHeapDesc.NodeMask = 0u

        val srvUavHeapVar = alloc<COpaquePointerVar>()
        val hrSrvUavHeap = createHeapFunc?.invoke(g_device, srvUavHeapDesc.ptr, iidHeap.ptr, srvUavHeapVar.ptr) ?: -1
        if (hrSrvUavHeap != 0) {
            debugOutput("[initD3D12] ERROR: CreateDescriptorHeap (SRV/UAV) failed")
            return false
        }
        g_srvUavHeap = srvUavHeapVar.value

        // Get SRV/UAV heap start handles
        val srvUavCpuStartHandle = alloc<D3D12_CPU_DESCRIPTOR_HANDLE>()
        getCpuStartFunc?.invoke(g_srvUavHeap, srvUavCpuStartHandle.ptr)
        g_srvUavHeapStartCpu = srvUavCpuStartHandle.value

        // ID3D12DescriptorHeap::GetGPUDescriptorHandleForHeapStart (vtable #10)
        val srvUavGpuStartHandle = alloc<D3D12_GPU_DESCRIPTOR_HANDLE>()
        val getGpuStartFunc = comMethod(g_srvUavHeap, 10)
            ?.reinterpret<CFunction<(COpaquePointer?, CPointer<D3D12_GPU_DESCRIPTOR_HANDLE>?) -> COpaquePointer?>>()
        getGpuStartFunc?.invoke(g_srvUavHeap, srvUavGpuStartHandle.ptr)
        g_srvUavHeapStartGpu = srvUavGpuStartHandle.value
        debugOutput("[initD3D12] SRV/UAV heap created")

        // Create Command Allocator and Command List
        val allocatorVar = alloc<COpaquePointerVar>()
        val iidAllocator = alloc<GUID>()
        initIID_ID3D12CommandAllocator(iidAllocator)
        // ID3D12Device::CreateCommandAllocator (vtable #9)
        val createAllocatorFunc = comMethod(g_device, 9)
            ?.reinterpret<CFunction<(COpaquePointer?, UInt, CPointer<GUID>?, CPointer<COpaquePointerVar>?) -> Int>>()
        val hrAllocator = createAllocatorFunc?.invoke(g_device, D3D12_COMMAND_LIST_TYPE_DIRECT, iidAllocator.ptr, allocatorVar.ptr) ?: -1
        if (hrAllocator != 0) {
            debugOutput("[initD3D12] ERROR: CreateCommandAllocator failed")
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
            debugOutput("[initD3D12] ERROR: CreateCommandList failed")
            return false
        }
        g_commandList = commandListVar.value

        // ID3D12GraphicsCommandList::Close (vtable #9)
        val closeFunc = comMethod(g_commandList, 9)
            ?.reinterpret<CFunction<(COpaquePointer?) -> Int>>()
        closeFunc?.invoke(g_commandList)
        debugOutput("[initD3D12] Command allocator and list created")

        // Create Compute Root Signature
        debugOutput("[initD3D12] Creating compute root signature...")
        val serializeFunc = GetProcAddress(g_hD3D12, "D3D12SerializeRootSignature")
            ?.reinterpret<CFunction<(CPointer<D3D12_ROOT_SIGNATURE_DESC>?, UInt, CPointer<COpaquePointerVar>?, CPointer<COpaquePointerVar>?) -> Int>>()
        if (serializeFunc == null) {
            debugOutput("[initD3D12] ERROR: D3D12SerializeRootSignature not found")
            return false
        }

        // Compute root signature: 1 root constants (cbuffer) + 1 descriptor table (2 UAVs)
        val computeRanges = allocArray<D3D12_DESCRIPTOR_RANGE>(1)
        computeRanges[0].RangeType = D3D12_DESCRIPTOR_RANGE_TYPE_UAV
        computeRanges[0].NumDescriptors = 2u
        computeRanges[0].BaseShaderRegister = 0u
        computeRanges[0].RegisterSpace = 0u
        computeRanges[0].OffsetInDescriptorsFromTableStart = 0u

        val computeParams = allocArray<D3D12_ROOT_PARAMETER>(2)
        // Parameter 0: Root constants (16 floats for harmonograph params + 1 uint + padding = 24 values)
        computeParams[0].ParameterType = D3D12_ROOT_PARAMETER_TYPE_32BIT_CONSTANTS
        computeParams[0].constants().ShaderRegister = 0u
        computeParams[0].constants().RegisterSpace = 0u
        computeParams[0].constants().Num32BitValues = 24u
        computeParams[0].ShaderVisibility = D3D12_SHADER_VISIBILITY_ALL

        // Parameter 1: Descriptor table for UAVs
        computeParams[1].ParameterType = D3D12_ROOT_PARAMETER_TYPE_DESCRIPTOR_TABLE
        computeParams[1].descriptorTable().NumDescriptorRanges = 1u
        computeParams[1].descriptorTable().pDescriptorRanges = computeRanges
        computeParams[1].ShaderVisibility = D3D12_SHADER_VISIBILITY_ALL

        val computeRsDesc = alloc<D3D12_ROOT_SIGNATURE_DESC>()
        computeRsDesc.NumParameters = 2u
        computeRsDesc.pParameters = computeParams
        computeRsDesc.NumStaticSamplers = 0u
        computeRsDesc.pStaticSamplers = null
        computeRsDesc.Flags = 0u

        val computeRsBlobVar = alloc<COpaquePointerVar>()
        val computeRsErrorVar = alloc<COpaquePointerVar>()
        val hrSerializeCompute = serializeFunc.invoke(computeRsDesc.ptr, D3D12_ROOT_SIGNATURE_VERSION_1, computeRsBlobVar.ptr, computeRsErrorVar.ptr)
        if (hrSerializeCompute != 0) {
            debugOutput("[initD3D12] ERROR: Serialize compute root signature failed: HRESULT=0x${toHex(hrSerializeCompute.toLong())}")
            if (computeRsErrorVar.value != null) {
                releaseComObject(computeRsErrorVar.value)
            }
            return false
        }
        if (computeRsErrorVar.value != null) {
            releaseComObject(computeRsErrorVar.value)
        }

        val computeRootSigVar = alloc<COpaquePointerVar>()
        val iidRootSig = alloc<GUID>()
        initIID_ID3D12RootSignature(iidRootSig)
        // ID3D12Device::CreateRootSignature (vtable #16)
        val createRootSigFunc = comMethod(g_device, 16)
            ?.reinterpret<CFunction<(COpaquePointer?, UInt, COpaquePointer?, ULong, CPointer<GUID>?, CPointer<COpaquePointerVar>?) -> Int>>()
        val computeRsPtr = blobGetPointer(computeRsBlobVar.value)
        val computeRsSize = blobGetSize(computeRsBlobVar.value)
        val hrComputeRs = createRootSigFunc?.invoke(g_device, 0u, computeRsPtr, computeRsSize, iidRootSig.ptr, computeRootSigVar.ptr) ?: -1
        releaseComObject(computeRsBlobVar.value)
        if (hrComputeRs != 0) {
            debugOutput("[initD3D12] ERROR: CreateRootSignature (compute) failed")
            return false
        }
        g_computeRootSignature = computeRootSigVar.value
        debugOutput("[initD3D12] Compute root signature created")

        // Create Graphics Root Signature
        debugOutput("[initD3D12] Creating graphics root signature...")
        // Graphics root signature: 1 root constants + 1 descriptor table (2 SRVs)
        val graphicsRanges = allocArray<D3D12_DESCRIPTOR_RANGE>(1)
        graphicsRanges[0].RangeType = D3D12_DESCRIPTOR_RANGE_TYPE_SRV
        graphicsRanges[0].NumDescriptors = 2u
        graphicsRanges[0].BaseShaderRegister = 0u
        graphicsRanges[0].RegisterSpace = 0u
        graphicsRanges[0].OffsetInDescriptorsFromTableStart = 0u

        val graphicsParams = allocArray<D3D12_ROOT_PARAMETER>(2)
        // Parameter 0: Root constants (same structure as compute)
        graphicsParams[0].ParameterType = D3D12_ROOT_PARAMETER_TYPE_32BIT_CONSTANTS
        graphicsParams[0].constants().ShaderRegister = 0u
        graphicsParams[0].constants().RegisterSpace = 0u
        graphicsParams[0].constants().Num32BitValues = 24u
        graphicsParams[0].ShaderVisibility = D3D12_SHADER_VISIBILITY_ALL

        // Parameter 1: Descriptor table for SRVs
        graphicsParams[1].ParameterType = D3D12_ROOT_PARAMETER_TYPE_DESCRIPTOR_TABLE
        graphicsParams[1].descriptorTable().NumDescriptorRanges = 1u
        graphicsParams[1].descriptorTable().pDescriptorRanges = graphicsRanges
        graphicsParams[1].ShaderVisibility = D3D12_SHADER_VISIBILITY_VERTEX

        val graphicsRsDesc = alloc<D3D12_ROOT_SIGNATURE_DESC>()
        graphicsRsDesc.NumParameters = 2u
        graphicsRsDesc.pParameters = graphicsParams
        graphicsRsDesc.NumStaticSamplers = 0u
        graphicsRsDesc.pStaticSamplers = null
        graphicsRsDesc.Flags = 0u

        val graphicsRsBlobVar = alloc<COpaquePointerVar>()
        val graphicsRsErrorVar = alloc<COpaquePointerVar>()
        val hrSerializeGraphics = serializeFunc.invoke(graphicsRsDesc.ptr, D3D12_ROOT_SIGNATURE_VERSION_1, graphicsRsBlobVar.ptr, graphicsRsErrorVar.ptr)
        if (hrSerializeGraphics != 0) {
            debugOutput("[initD3D12] ERROR: Serialize graphics root signature failed")
            if (graphicsRsErrorVar.value != null) {
                releaseComObject(graphicsRsErrorVar.value)
            }
            return false
        }
        if (graphicsRsErrorVar.value != null) {
            releaseComObject(graphicsRsErrorVar.value)
        }

        val graphicsRootSigVar = alloc<COpaquePointerVar>()
        val graphicsRsPtr = blobGetPointer(graphicsRsBlobVar.value)
        val graphicsRsSize = blobGetSize(graphicsRsBlobVar.value)
        val hrGraphicsRs = createRootSigFunc?.invoke(g_device, 0u, graphicsRsPtr, graphicsRsSize, iidRootSig.ptr, graphicsRootSigVar.ptr) ?: -1
        releaseComObject(graphicsRsBlobVar.value)
        if (hrGraphicsRs != 0) {
            debugOutput("[initD3D12] ERROR: CreateRootSignature (graphics) failed")
            return false
        }
        g_rootSignature = graphicsRootSigVar.value
        debugOutput("[initD3D12] Graphics root signature created")

        // Create Compute Pipeline State
        debugOutput("[initD3D12] Creating compute pipeline state...")
        val csBlob = compileShader(g_computeShaderCode, "CSMain", "cs_5_0")
        if (csBlob == null) {
            debugOutput("[initD3D12] ERROR: Compute shader compilation failed")
            return false
        }

        val computePsoDesc = alloc<D3D12_COMPUTE_PIPELINE_STATE_DESC>()
        memset(computePsoDesc.ptr, 0, D3D12_COMPUTE_PIPELINE_STATE_DESC.size.convert())
        computePsoDesc.pRootSignature = g_computeRootSignature
        computePsoDesc.cs().pShaderBytecode = blobGetPointer(csBlob)
        computePsoDesc.cs().BytecodeLength = blobGetSize(csBlob)
        computePsoDesc.NodeMask = 0u
        computePsoDesc.cachedPSO().pCachedBlob = null
        computePsoDesc.cachedPSO().CachedBlobSizeInBytes = 0u
        computePsoDesc.Flags = 0u

        val computePsoVar = alloc<COpaquePointerVar>()
        val iidPso = alloc<GUID>()
        initIID_ID3D12PipelineState(iidPso)
        // ID3D12Device::CreateComputePipelineState (vtable #11)
        val createComputePsoFunc = comMethod(g_device, 11)
            ?.reinterpret<CFunction<(COpaquePointer?, CPointer<D3D12_COMPUTE_PIPELINE_STATE_DESC>?, CPointer<GUID>?, CPointer<COpaquePointerVar>?) -> Int>>()
        val hrComputePso = createComputePsoFunc?.invoke(g_device, computePsoDesc.ptr, iidPso.ptr, computePsoVar.ptr) ?: -1
        releaseComObject(csBlob)
        if (hrComputePso != 0) {
            debugOutput("[initD3D12] ERROR: CreateComputePipelineState failed: HRESULT=0x${toHex(hrComputePso.toLong())}")
            return false
        }
        g_computePipelineState = computePsoVar.value
        debugOutput("[initD3D12] Compute pipeline state created")

        // Create Graphics Pipeline State
        debugOutput("[initD3D12] Creating graphics pipeline state...")
        val vsBlob = compileShader(g_graphicsShaderCode, "VSMain", "vs_5_0")
        if (vsBlob == null) {
            debugOutput("[initD3D12] ERROR: Vertex shader compilation failed")
            return false
        }
        val psBlob = compileShader(g_graphicsShaderCode, "PSMain", "ps_5_0")
        if (psBlob == null) {
            releaseComObject(vsBlob)
            debugOutput("[initD3D12] ERROR: Pixel shader compilation failed")
            return false
        }

        val psoDesc = alloc<D3D12_GRAPHICS_PIPELINE_STATE_DESC>()
        memset(psoDesc.ptr, 0, D3D12_GRAPHICS_PIPELINE_STATE_DESC.size.convert())
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
        rs.AntialiasedLineEnable = 1
        rs.ForcedSampleCount = 0u
        rs.ConservativeRaster = 0u

        val ds = psoDesc.depthStencilState()
        ds.DepthEnable = 0
        ds.DepthWriteMask = D3D12_DEPTH_WRITE_MASK_ZERO
        ds.DepthFunc = D3D12_COMPARISON_FUNC_ALWAYS
        ds.StencilEnable = 0
        ds.StencilReadMask = 0u
        ds.StencilWriteMask = 0u

        // No input layout - we use SV_VertexID
        psoDesc.inputLayout().pInputElementDescs = null
        psoDesc.inputLayout().NumElements = 0u

        psoDesc.IBStripCutValue = 0u
        psoDesc.PrimitiveTopologyType = D3D12_PRIMITIVE_TOPOLOGY_TYPE_LINE
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
        // ID3D12Device::CreateGraphicsPipelineState (vtable #10)
        val createPsoFunc = comMethod(g_device, 10)
            ?.reinterpret<CFunction<(COpaquePointer?, CPointer<D3D12_GRAPHICS_PIPELINE_STATE_DESC>?, CPointer<GUID>?, CPointer<COpaquePointerVar>?) -> Int>>()
        val hrPso = createPsoFunc?.invoke(g_device, psoDesc.ptr, iidPso.ptr, psoVar.ptr) ?: -1
        releaseComObject(vsBlob)
        releaseComObject(psBlob)
        if (hrPso != 0) {
            debugOutput("[initD3D12] ERROR: CreateGraphicsPipelineState failed: HRESULT=0x${toHex(hrPso.toLong())}")
            return false
        }
        g_pipelineState = psoVar.value
        debugOutput("[initD3D12] Graphics pipeline state created")

        // Create Position Buffer
        debugOutput("[initD3D12] Creating position buffer...")
        val bufferSize = (NUM_VERTICES * 16).toULong()  // float4 = 16 bytes

        val heapPropsDefault = alloc<D3D12_HEAP_PROPERTIES>()
        heapPropsDefault.Type = D3D12_HEAP_TYPE_DEFAULT
        heapPropsDefault.CPUPageProperty = 0u
        heapPropsDefault.MemoryPoolPreference = 0u
        heapPropsDefault.CreationNodeMask = 1u
        heapPropsDefault.VisibleNodeMask = 1u

        val bufferDesc = alloc<D3D12_RESOURCE_DESC>()
        bufferDesc.Dimension = D3D12_RESOURCE_DIMENSION_BUFFER
        bufferDesc.Alignment = 0u
        bufferDesc.Width = bufferSize
        bufferDesc.Height = 1u
        bufferDesc.DepthOrArraySize = 1u.toUShort()
        bufferDesc.MipLevels = 1u.toUShort()
        bufferDesc.Format = DXGI_FORMAT_UNKNOWN
        bufferDesc.setSampleDesc(1u, 0u)
        bufferDesc.Layout = D3D12_TEXTURE_LAYOUT_ROW_MAJOR
        bufferDesc.Flags = D3D12_RESOURCE_FLAG_ALLOW_UNORDERED_ACCESS

        val posBufferVar = alloc<COpaquePointerVar>()
        // ID3D12Device::CreateCommittedResource (vtable #27)
        val createResourceFunc = comMethod(g_device, 27)
            ?.reinterpret<CFunction<(COpaquePointer?, CPointer<D3D12_HEAP_PROPERTIES>?, UInt, CPointer<D3D12_RESOURCE_DESC>?, UInt, COpaquePointer?, CPointer<GUID>?, CPointer<COpaquePointerVar>?) -> Int>>()
        val hrPosBuffer = createResourceFunc?.invoke(g_device, heapPropsDefault.ptr, D3D12_HEAP_FLAG_NONE, bufferDesc.ptr, D3D12_RESOURCE_STATE_UNORDERED_ACCESS, null, iidResource.ptr, posBufferVar.ptr) ?: -1
        if (hrPosBuffer != 0) {
            debugOutput("[initD3D12] ERROR: CreateCommittedResource (position buffer) failed: HRESULT=0x${toHex(hrPosBuffer.toLong())}")
            return false
        }
        g_positionBuffer = posBufferVar.value
        debugOutput("[initD3D12] Position buffer created")

        // Create Color Buffer
        debugOutput("[initD3D12] Creating color buffer...")
        val colorBufferVar = alloc<COpaquePointerVar>()
        val hrColorBuffer = createResourceFunc?.invoke(g_device, heapPropsDefault.ptr, D3D12_HEAP_FLAG_NONE, bufferDesc.ptr, D3D12_RESOURCE_STATE_UNORDERED_ACCESS, null, iidResource.ptr, colorBufferVar.ptr) ?: -1
        if (hrColorBuffer != 0) {
            debugOutput("[initD3D12] ERROR: CreateCommittedResource (color buffer) failed")
            return false
        }
        g_colorBuffer = colorBufferVar.value
        debugOutput("[initD3D12] Color buffer created")

        // Create UAVs for compute shader (descriptors 0, 1)
        debugOutput("[initD3D12] Creating UAVs...")
        // ID3D12Device::CreateUnorderedAccessView (vtable #19)
        val createUavFunc = comMethod(g_device, 19)
            ?.reinterpret<CFunction<(COpaquePointer?, COpaquePointer?, COpaquePointer?, CPointer<D3D12_UNORDERED_ACCESS_VIEW_DESC>?, ULong) -> Unit>>()

        val uavDesc = alloc<D3D12_UNORDERED_ACCESS_VIEW_DESC>()
        memset(uavDesc.ptr, 0, D3D12_UNORDERED_ACCESS_VIEW_DESC.size.convert())
        uavDesc.Format = DXGI_FORMAT_UNKNOWN
        uavDesc.ViewDimension = D3D12_UAV_DIMENSION_BUFFER
        uavDesc.FirstElement = 0u
        uavDesc.NumElements = NUM_VERTICES.toUInt()
        uavDesc.StructureByteStride = 16u  // sizeof(float4)
        uavDesc.CounterOffsetInBytes = 0u
        uavDesc.Flags = 0u

        // UAV 0: Position buffer
        val uav0Handle = g_srvUavHeapStartCpu
        createUavFunc?.invoke(g_device, g_positionBuffer, null, uavDesc.ptr, uav0Handle)

        // UAV 1: Color buffer
        val uav1Handle = g_srvUavHeapStartCpu + g_srvUavDescriptorSize.toULong()
        createUavFunc?.invoke(g_device, g_colorBuffer, null, uavDesc.ptr, uav1Handle)
        debugOutput("[initD3D12] UAVs created")

        // Create CBV (descriptor 2)
        debugOutput("[initD3D12] Creating CBV...")
        // For now, we'll skip CBV creation and use root constants instead
        debugOutput("[initD3D12] CBV skipped (using root constants)")

        // Create Fence
        debugOutput("[initD3D12] Creating fence...")
        val fenceVar = alloc<COpaquePointerVar>()
        val iidFence = alloc<GUID>()
        initIID_ID3D12Fence(iidFence)
        // ID3D12Device::CreateFence (vtable #36)
        val createFenceFunc = comMethod(g_device, 36)
            ?.reinterpret<CFunction<(COpaquePointer?, ULong, UInt, CPointer<GUID>?, CPointer<COpaquePointerVar>?) -> Int>>()
        val hrFence = createFenceFunc?.invoke(g_device, 0u, 0u, iidFence.ptr, fenceVar.ptr) ?: -1
        if (hrFence != 0) {
            debugOutput("[initD3D12] ERROR: CreateFence failed")
            return false
        }
        g_fence = fenceVar.value
        g_fenceEvent = CreateEventW(null, 0, 0, null)
        debugOutput("[initD3D12] Fence created")

        debugOutput("[initD3D12] DirectX 12 Harmonograph pipeline initialized")
    }

    return true
}

private fun getRtvHandle(index: UInt): ULong {
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

    releaseComObject(g_positionBuffer)
    g_positionBuffer = null

    releaseComObject(g_colorBuffer)
    g_colorBuffer = null

    releaseComObject(g_constantBuffer)
    g_constantBuffer = null

    releaseComObject(g_pipelineState)
    g_pipelineState = null

    releaseComObject(g_computePipelineState)
    g_computePipelineState = null

    releaseComObject(g_rootSignature)
    g_rootSignature = null

    releaseComObject(g_computeRootSignature)
    g_computeRootSignature = null

    releaseComObject(g_commandList)
    g_commandList = null

    releaseComObject(g_commandAllocator)
    g_commandAllocator = null

    releaseComObject(g_srvUavHeap)
    g_srvUavHeap = null

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
    if (g_device == null || g_commandList == null || g_commandAllocator == null ||
        g_pipelineState == null || g_rootSignature == null ||
        g_computePipelineState == null || g_computeRootSignature == null) {
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
    resetCmdFunc?.invoke(g_commandList, g_commandAllocator, null)

    memScoped {
        // ===== COMPUTE PASS =====
        // ID3D12GraphicsCommandList::SetComputeRootSignature (vtable #29)
        val setComputeRootSigFunc = comMethod(g_commandList, 29)
            ?.reinterpret<CFunction<(COpaquePointer?, COpaquePointer?) -> Unit>>()
        setComputeRootSigFunc?.invoke(g_commandList, g_computeRootSignature)

        // ID3D12GraphicsCommandList::SetPipelineState (vtable #25)
        val setPipelineFunc = comMethod(g_commandList, 25)
            ?.reinterpret<CFunction<(COpaquePointer?, COpaquePointer?) -> Unit>>()
        setPipelineFunc?.invoke(g_commandList, g_computePipelineState)

        // ID3D12GraphicsCommandList::SetDescriptorHeaps (vtable #28)
        val setDescHeapsFunc = comMethod(g_commandList, 28)
            ?.reinterpret<CFunction<(COpaquePointer?, UInt, CPointer<COpaquePointerVar>?) -> Unit>>()
        val heapVar = alloc<COpaquePointerVar>()
        heapVar.value = g_srvUavHeap
        setDescHeapsFunc?.invoke(g_commandList, 1u, heapVar.ptr)

        // Set harmonograph parameters as root constants
        // ID3D12GraphicsCommandList::SetComputeRoot32BitConstants (vtable #35)
        val setComputeConstantsFunc = comMethod(g_commandList, 35)
            ?.reinterpret<CFunction<(COpaquePointer?, UInt, UInt, CPointer<FloatVar>?, UInt) -> Unit>>()

        // Animate parameters
        g_f1 = (g_f1 + kotlin.random.Random.nextFloat() / 40.0f) % 10.0f
        g_f2 = (g_f2 + kotlin.random.Random.nextFloat() / 40.0f) % 10.0f
        g_f3 = (g_f3 + kotlin.random.Random.nextFloat() / 40.0f) % 10.0f
        g_f4 = (g_f4 + kotlin.random.Random.nextFloat() / 40.0f) % 10.0f
        g_p1 += (6.283185307179586f * 0.5f / 360.0f)

        // Harmonograph parameters (animated)
        val params = allocArray<FloatVar>(24)

        // A1, f1, p1, d1
        params[0] = g_A1
        params[1] = g_f1
        params[2] = g_p1
        params[3] = g_d1

        // A2, f2, p2, d2
        params[4] = g_A2
        params[5] = g_f2
        params[6] = g_p2
        params[7] = g_d2

        // A3, f3, p3, d3
        params[8] = g_A3
        params[9] = g_f3
        params[10] = g_p3
        params[11] = g_d3

        // A4, f4, p4, d4
        params[12] = g_A4
        params[13] = g_f4
        params[14] = g_p4
        params[15] = g_d4

        // max_num (as uint, stored in float slot)
        val maxNumPtr = (params + 16)!!.reinterpret<UIntVar>()
        maxNumPtr.pointed.value = NUM_VERTICES.toUInt()

        // padding (3 floats)
        params[17] = 0.0f
        params[18] = 0.0f
        params[19] = 0.0f

        // resolution
        params[20] = WINDOW_WIDTH.toFloat()
        params[21] = WINDOW_HEIGHT.toFloat()

        // padding2
        params[22] = 0.0f
        params[23] = 0.0f

        setComputeConstantsFunc?.invoke(g_commandList, 0u, 24u, params, 0u)

        // Set UAV descriptor table (parameter 1)
        // ID3D12GraphicsCommandList::SetComputeRootDescriptorTable (vtable #31)
        val setComputeTableFunc = comMethod(g_commandList, 31)
            ?.reinterpret<CFunction<(COpaquePointer?, UInt, ULong) -> Unit>>()
        setComputeTableFunc?.invoke(g_commandList, 1u, g_srvUavHeapStartGpu)

        // Dispatch compute shader
        // ID3D12GraphicsCommandList::Dispatch (vtable #14)
        val dispatchFunc = comMethod(g_commandList, 14)
            ?.reinterpret<CFunction<(COpaquePointer?, UInt, UInt, UInt) -> Unit>>()
        val numGroups = (NUM_VERTICES + 63) / 64
        dispatchFunc?.invoke(g_commandList, numGroups.toUInt(), 1u, 1u)

        // Resource barrier: UAV synchronization
        // ID3D12GraphicsCommandList::ResourceBarrier (vtable #26)
        val resourceBarrierFunc = comMethod(g_commandList, 26)
            ?.reinterpret<CFunction<(COpaquePointer?, UInt, CPointer<D3D12_RESOURCE_BARRIER>?) -> Unit>>()

        val barrier = alloc<D3D12_RESOURCE_BARRIER>()
        
        // Position buffer UAV barrier
        memset(barrier.ptr, 0, D3D12_RESOURCE_BARRIER.size.convert())
        barrier.Type = D3D12_RESOURCE_BARRIER_TYPE_UAV
        barrier.Flags = D3D12_RESOURCE_BARRIER_FLAG_NONE
        val pResourcePtr1 = interpretCPointer<COpaquePointerVar>(barrier.ptr.rawValue + 8)!!
        pResourcePtr1.pointed.value = g_positionBuffer
        resourceBarrierFunc?.invoke(g_commandList, 1u, barrier.ptr)

        // Color buffer UAV barrier
        memset(barrier.ptr, 0, D3D12_RESOURCE_BARRIER.size.convert())
        barrier.Type = D3D12_RESOURCE_BARRIER_TYPE_UAV
        barrier.Flags = D3D12_RESOURCE_BARRIER_FLAG_NONE
        val pResourcePtr2 = interpretCPointer<COpaquePointerVar>(barrier.ptr.rawValue + 8)!!
        pResourcePtr2.pointed.value = g_colorBuffer
        resourceBarrierFunc?.invoke(g_commandList, 1u, barrier.ptr)

        // ===== GRAPHICS PASS =====
        // ID3D12GraphicsCommandList::SetGraphicsRootSignature (vtable #30)
        val setRootSigFunc = comMethod(g_commandList, 30)
            ?.reinterpret<CFunction<(COpaquePointer?, COpaquePointer?) -> Unit>>()
        setRootSigFunc?.invoke(g_commandList, g_rootSignature)

        setPipelineFunc?.invoke(g_commandList, g_pipelineState)

        val viewport = alloc<D3D12_VIEWPORT>()
        viewport.TopLeftX = 0.0f
        viewport.TopLeftY = 0.0f
        viewport.Width = WINDOW_WIDTH.toFloat()
        viewport.Height = WINDOW_HEIGHT.toFloat()
        viewport.MinDepth = 0.0f
        viewport.MaxDepth = 1.0f

        val scissor = alloc<D3D12_RECT>()
        scissor.left = 0
        scissor.top = 0
        scissor.right = WINDOW_WIDTH
        scissor.bottom = WINDOW_HEIGHT

        // ID3D12GraphicsCommandList::RSSetViewports (vtable #21)
        val rsViewports = comMethod(g_commandList, 21)
            ?.reinterpret<CFunction<(COpaquePointer?, UInt, CPointer<D3D12_VIEWPORT>?) -> Unit>>()
        // ID3D12GraphicsCommandList::RSSetScissorRects (vtable #22)
        val rsScissors = comMethod(g_commandList, 22)
            ?.reinterpret<CFunction<(COpaquePointer?, UInt, CPointer<D3D12_RECT>?) -> Unit>>()
        rsViewports?.invoke(g_commandList, 1u, viewport.ptr)
        rsScissors?.invoke(g_commandList, 1u, scissor.ptr)

        // Transition render target
        val rtBarrier = alloc<D3D12_RESOURCE_BARRIER>()
        rtBarrier.Type = D3D12_RESOURCE_BARRIER_TYPE_TRANSITION
        rtBarrier.Flags = D3D12_RESOURCE_BARRIER_FLAG_NONE
        rtBarrier.transition().pResource = g_renderTargets[g_frameIndex.toInt()]
        rtBarrier.transition().Subresource = D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES
        rtBarrier.transition().StateBefore = D3D12_RESOURCE_STATE_PRESENT
        rtBarrier.transition().StateAfter = D3D12_RESOURCE_STATE_RENDER_TARGET
        resourceBarrierFunc?.invoke(g_commandList, 1u, rtBarrier.ptr)

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
        clearColor[0] = 0.0f
        clearColor[1] = 0.0f
        clearColor[2] = 0.02f
        clearColor[3] = 1.0f
        clearRTFunc?.invoke(g_commandList, rtvHandleValue, clearColor, 0u, null)

        // Set graphics root constants
        // ID3D12GraphicsCommandList::SetGraphicsRoot32BitConstants (vtable #36)
        val setGraphicsConstantsFunc = comMethod(g_commandList, 36)
            ?.reinterpret<CFunction<(COpaquePointer?, UInt, UInt, CPointer<FloatVar>?, UInt) -> Unit>>()
        setGraphicsConstantsFunc?.invoke(g_commandList, 0u, 24u, params, 0u)

        // Set SRV descriptor table (parameter 1) - use UAV descriptors at heap start
        // ID3D12GraphicsCommandList::SetGraphicsRootDescriptorTable (vtable #32)
        val setGraphicsTableFunc = comMethod(g_commandList, 32)
            ?.reinterpret<CFunction<(COpaquePointer?, UInt, ULong) -> Unit>>()
        setGraphicsTableFunc?.invoke(g_commandList, 1u, g_srvUavHeapStartGpu)

        // ID3D12GraphicsCommandList::IASetPrimitiveTopology (vtable #20)
        val iaSetTopoFunc = comMethod(g_commandList, 20)
            ?.reinterpret<CFunction<(COpaquePointer?, UInt) -> Unit>>()
        iaSetTopoFunc?.invoke(g_commandList, D3D_PRIMITIVE_TOPOLOGY_LINESTRIP)

        // ID3D12GraphicsCommandList::DrawInstanced (vtable #12)
        val drawFunc = comMethod(g_commandList, 12)
            ?.reinterpret<CFunction<(COpaquePointer?, UInt, UInt, UInt, UInt) -> Unit>>()
        drawFunc?.invoke(g_commandList, NUM_VERTICES.toUInt(), 1u, 0u, 0u)

        // Transition render target back
        rtBarrier.transition().StateBefore = D3D12_RESOURCE_STATE_RENDER_TARGET
        rtBarrier.transition().StateAfter = D3D12_RESOURCE_STATE_PRESENT
        resourceBarrierFunc?.invoke(g_commandList, 1u, rtBarrier.ptr)
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

    // Update time
    g_time += 0.016f

    renderCount++
}

// ============================================================
// Window Callback
// ============================================================
private val wndProcCallback = staticCFunction { hwnd: HWND?, msg: UInt, wParam: WPARAM, lParam: LPARAM ->
    when (msg.toInt()) {
        WM_KEYUP -> {
            if (wParam.toInt() == VK_ESCAPE) {
                PostQuitMessage(0)
                0
            } else {
                DefWindowProcW(hwnd, msg, wParam, lParam)
            }
        }
        WM_CLOSE -> {
            PostQuitMessage(0)
            0
        }
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
    debugOutput("[MAIN] DirectX 12 Harmonograph with Compute Shader")
    debugOutput("[MAIN] Debug output enabled - check DebugView for detailed messages")

    memScoped {
        val hInstance = GetModuleHandleW(null)
        val className = "HarmonographWindow"
        val windowName = "DirectX 12 Harmonograph - Compute Shader"

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
            nWidth = WINDOW_WIDTH,
            nHeight = WINDOW_HEIGHT,
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

        val startTime = GetTickCount64()
        var lastTime = startTime

        while (true) {
            if (PeekMessageW(msg.ptr, null, 0u, 0u, PM_REMOVE) != 0) {
                if (msg.message == WM_QUIT.toUInt()) {
                    break
                }
                TranslateMessage(msg.ptr)
                DispatchMessageW(msg.ptr)
            } else {
                // Check timeout (60 seconds)
                val currentTime = GetTickCount64()
                if (currentTime - startTime > 60000u) {
                    PostQuitMessage(0)
                    break
                }
                
                render()
                
                // Simple frame rate control
                Sleep(1u)
            }
        }

        debugOutput("[MAIN] Message loop ended")
    }
}
