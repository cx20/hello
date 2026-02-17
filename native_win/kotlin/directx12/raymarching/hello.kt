@file:OptIn(kotlinx.cinterop.ExperimentalForeignApi::class)

import kotlinx.cinterop.*
import platform.windows.*
import platform.posix.memcpy
import platform.posix.memset

// ============================================================
// DirectX 12 Raymarching Sample
// ============================================================
// This sample demonstrates raymarching with DirectX 12 in Kotlin/Native.
// Features:
// - Signed Distance Functions (sphere, box, torus)
// - Smooth blending between shapes
// - Phong lighting with shadows
// - Ambient occlusion
// - Animated scene with rotating torus and bouncing sphere
// - Checkerboard floor pattern
// ============================================================

// ============================================================
// DirectX 12 Constants
// ============================================================
const val FRAME_COUNT = 2u

// DXGI Constants
const val DXGI_FORMAT_R8G8B8A8_UNORM: UInt = 28u
const val DXGI_FORMAT_R32G32_FLOAT: UInt = 16u
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
const val D3D12_ROOT_PARAMETER_TYPE_32BIT_CONSTANTS: UInt = 1u
const val D3D12_SHADER_VISIBILITY_ALL: UInt = 0u

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

// Window dimensions
const val WINDOW_WIDTH = 1280
const val WINDOW_HEIGHT = 720

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
var g_constantBuffer: COpaquePointer? = null
var g_constantBufferMappedPtr: COpaquePointer? = null
var g_fenceEvent: HANDLE? = null
var g_fenceValue: ULong = 1u
var g_frameIndex: UInt = 0u
var g_rtvDescriptorSize: UInt = 0u
var g_rtvHeapStartValue: ULong = 0u
var g_renderTargets = arrayOfNulls<COpaquePointer>(2)
var g_vertexBufferViewPtr: CPointer<D3D12_VERTEX_BUFFER_VIEW>? = null
var g_startTime: Long = 0L

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
// HLSL Raymarching Shader Code
// ============================================================
// This shader implements a complete raymarching pipeline with:
// - Multiple SDF primitives (sphere, box, torus)
// - Smooth minimum blending for organic shapes
// - Phong lighting model with diffuse and specular
// - Soft shadows for realistic shading
// - Ambient occlusion for depth cues
// - Animated objects (rotating torus, bouncing sphere)
// - Checkerboard floor pattern
// - Fog for depth perception
// ============================================================
private val g_shaderCode = """
// Constant buffer containing time and resolution
cbuffer ConstantBuffer : register(b0)
{
    float iTime;       // Elapsed time in seconds
    float2 iResolution; // Screen resolution (width, height)
    float padding;     // Padding for 16-byte alignment
};

// Vertex shader output / Pixel shader input structure
struct PSInput
{
    float4 position : SV_POSITION;
    float2 uv : TEXCOORD0;
};

// Vertex shader: transforms position and computes UV coordinates
PSInput VSMain(float2 position : POSITION)
{
    PSInput result;
    result.position = float4(position, 0.0, 1.0);
    // Convert from clip space [-1,1] to UV space [0,1]
    result.uv = position * 0.5 + 0.5;
    return result;
}

// ============================================================
// Raymarching Constants
// ============================================================
static const int MAX_STEPS = 100;      // Maximum raymarching iterations
static const float MAX_DIST = 100.0;   // Maximum ray travel distance
static const float SURF_DIST = 0.001;  // Surface hit threshold

// ============================================================
// Signed Distance Functions (SDFs)
// ============================================================

// Sphere SDF: returns distance to sphere surface
// p: point to evaluate, r: sphere radius
float sdSphere(float3 p, float r)
{
    return length(p) - r;
}

// Box SDF: returns distance to axis-aligned box surface
// p: point to evaluate, b: box half-extents
float sdBox(float3 p, float3 b)
{
    float3 q = abs(p) - b;
    return length(max(q, 0.0)) + min(max(q.x, max(q.y, q.z)), 0.0);
}

// Torus SDF: returns distance to torus surface
// p: point to evaluate, t: (major radius, minor radius)
float sdTorus(float3 p, float2 t)
{
    float2 q = float2(length(p.xz) - t.x, p.y);
    return length(q) - t.y;
}

// ============================================================
// Smooth Minimum (for blending shapes)
// ============================================================
// Polynomial smooth minimum for organic blending
// a, b: distances to blend, k: blending factor
float smin(float a, float b, float k)
{
    float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
    return lerp(b, a, h) - k * h * (1.0 - h);
}

// ============================================================
// Scene Distance Function
// ============================================================
// Returns the distance to the nearest surface in the scene
float GetDist(float3 p)
{
    // Animated bouncing sphere
    float sphereY = 0.5 + sin(iTime * 2.0) * 0.3;
    float sphereX = sin(iTime) * 1.5;
    float sphere = sdSphere(p - float3(sphereX, sphereY, 0.0), 0.5);
    
    // Rotating torus
    float angle = iTime * 0.5;
    float3 torusPos = p - float3(0.0, 0.5, 0.0);
    
    // Rotate around Y axis
    float cosA = cos(angle);
    float sinA = sin(angle);
    float2 rotatedXZ = float2(
        cosA * torusPos.x - sinA * torusPos.z,
        sinA * torusPos.x + cosA * torusPos.z
    );
    torusPos.x = rotatedXZ.x;
    torusPos.z = rotatedXZ.y;
    
    // Rotate around X axis for tumbling effect
    float angle2 = angle * 0.7;
    float cosA2 = cos(angle2);
    float sinA2 = sin(angle2);
    float2 rotatedXY = float2(
        cosA2 * torusPos.x - sinA2 * torusPos.y,
        sinA2 * torusPos.x + cosA2 * torusPos.y
    );
    torusPos.x = rotatedXY.x;
    torusPos.y = rotatedXY.y;
    
    float torus = sdTorus(torusPos, float2(0.8, 0.2));
    
    // Ground plane at y = -0.5
    float plane = p.y + 0.5;
    
    // Combine sphere and torus with smooth blending
    float d = smin(sphere, torus, 0.3);
    // Add floor without blending (hard edge)
    d = min(d, plane);
    
    return d;
}

// ============================================================
// Normal Calculation using Gradient
// ============================================================
// Computes surface normal by sampling distance field gradient
float3 GetNormal(float3 p)
{
    float d = GetDist(p);
    float2 e = float2(0.001, 0.0);
    
    // Central differences for gradient estimation
    float3 n = d - float3(
        GetDist(p - e.xyy),
        GetDist(p - e.yxy),
        GetDist(p - e.yyx)
    );
    
    return normalize(n);
}

// ============================================================
// Raymarching Algorithm
// ============================================================
// Marches a ray through the scene and returns hit distance
float RayMarch(float3 ro, float3 rd)
{
    float dO = 0.0; // Distance from origin
    
    for (int i = 0; i < MAX_STEPS; i++)
    {
        float3 p = ro + rd * dO;
        float dS = GetDist(p);
        dO += dS;
        
        // Exit if we've gone too far or hit surface
        if (dO > MAX_DIST || dS < SURF_DIST)
            break;
    }
    
    return dO;
}

// ============================================================
// Soft Shadows
// ============================================================
// Computes soft shadow factor using sphere tracing
// ro: shadow ray origin, rd: direction to light
// mint/maxt: min/max trace distances, k: shadow softness
float GetShadow(float3 ro, float3 rd, float mint, float maxt, float k)
{
    float res = 1.0;
    float t = mint;
    
    for (int i = 0; i < 64 && t < maxt; i++)
    {
        float h = GetDist(ro + rd * t);
        if (h < 0.001)
            return 0.0;
        res = min(res, k * h / t);
        t += h;
    }
    
    return res;
}

// ============================================================
// Ambient Occlusion
// ============================================================
// Estimates ambient occlusion by sampling nearby distances
float GetAO(float3 p, float3 n)
{
    float occ = 0.0;
    float sca = 1.0;
    
    for (int i = 0; i < 5; i++)
    {
        float h = 0.01 + 0.12 * float(i) / 4.0;
        float d = GetDist(p + h * n);
        occ += (h - d) * sca;
        sca *= 0.95;
    }
    
    return clamp(1.0 - 3.0 * occ, 0.0, 1.0);
}

// ============================================================
// Pixel Shader Main
// ============================================================
float4 PSMain(PSInput input) : SV_TARGET
{
    // Convert UV to centered coordinates with aspect ratio correction
    float2 uv = input.uv - 0.5;
    uv.x *= iResolution.x / iResolution.y;
    
    // Camera setup
    float3 ro = float3(0.0, 1.5, -4.0);  // Ray origin (camera position)
    float3 rd = normalize(float3(uv.x, uv.y, 1.0));  // Ray direction
    
    // Light position
    float3 lightPos = float3(3.0, 5.0, -2.0);
    
    // Perform raymarching
    float d = RayMarch(ro, rd);
    
    // Initialize output color
    float3 col = float3(0.0, 0.0, 0.0);
    
    if (d < MAX_DIST)
    {
        // Calculate hit point and surface properties
        float3 p = ro + rd * d;
        float3 n = GetNormal(p);
        float3 l = normalize(lightPos - p);
        float3 v = normalize(ro - p);
        float3 r = reflect(-l, n);
        
        // Material color based on position
        float3 matCol = float3(0.4, 0.6, 0.9);  // Default blue-ish color
        
        // Checkerboard pattern for floor
        if (p.y < -0.49)
        {
            float checker = fmod(floor(p.x) + floor(p.z), 2.0);
            matCol = lerp(float3(0.2, 0.2, 0.2), float3(0.8, 0.8, 0.8), checker);
        }
        
        // Lighting calculations
        float diff = max(dot(n, l), 0.0);  // Diffuse
        float spec = pow(max(dot(r, v), 0.0), 32.0);  // Specular
        float ao = GetAO(p, n);  // Ambient occlusion
        float shadow = GetShadow(p + n * 0.01, l, 0.01, length(lightPos - p), 16.0);
        
        // Ambient light color
        float3 ambient = float3(0.1, 0.12, 0.15);
        
        // Combine lighting components
        col = matCol * (ambient * ao + diff * shadow) + float3(1.0, 1.0, 1.0) * spec * shadow * 0.5;
        
        // Apply fog based on distance
        col = lerp(col, float3(0.05, 0.05, 0.1), 1.0 - exp(-0.02 * d * d));
    }
    else
    {
        // Background gradient for sky
        col = lerp(float3(0.1, 0.1, 0.15), float3(0.02, 0.02, 0.05), input.uv.y);
    }
    
    // Gamma correction
    col = pow(col, float3(0.4545, 0.4545, 0.4545));
    
    return float4(col, 1.0);
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
            // Print error message if available
            if (errVar.value != null) {
                val errPtr = blobGetPointer(errVar.value)
                if (errPtr != null) {
                    val errMsg = errPtr.reinterpret<ByteVar>().toKString()
                    debugOutput("[Shader] Compilation error: $errMsg")
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
// Vertex Structure (Position only for fullscreen quad)
// ============================================================
class VERTEX(rawPtr: NativePtr) : CStructVar(rawPtr) {
    companion object : Type(8, 4)  // 2 floats = 8 bytes
    
    var x: Float
        get() = this.ptr.reinterpret<FloatVar>().pointed.value
        set(value) { this.ptr.reinterpret<FloatVar>().pointed.value = value }
    
    var y: Float
        get() = this.ptr.rawValue.plus(4).toLong().toCPointer<FloatVar>()!!.pointed.value
        set(value) { this.ptr.rawValue.plus(4).toLong().toCPointer<FloatVar>()!!.pointed.value = value }
}

// ============================================================
// Constant Buffer Data Structure
// ============================================================
// Layout: iTime (4 bytes), iResolution.x (4 bytes), iResolution.y (4 bytes), padding (4 bytes)
class CONSTANT_BUFFER_DATA(rawPtr: NativePtr) : CStructVar(rawPtr) {
    companion object : Type(16, 4)  // 16 bytes total (aligned)
    
    var iTime: Float
        get() = this.ptr.reinterpret<FloatVar>().pointed.value
        set(value) { this.ptr.reinterpret<FloatVar>().pointed.value = value }
    
    var iResolutionX: Float
        get() = this.ptr.rawValue.plus(4).toLong().toCPointer<FloatVar>()!!.pointed.value
        set(value) { this.ptr.rawValue.plus(4).toLong().toCPointer<FloatVar>()!!.pointed.value = value }
    
    var iResolutionY: Float
        get() = this.ptr.rawValue.plus(8).toLong().toCPointer<FloatVar>()!!.pointed.value
        set(value) { this.ptr.rawValue.plus(8).toLong().toCPointer<FloatVar>()!!.pointed.value = value }
    
    var padding: Float
        get() = this.ptr.rawValue.plus(12).toLong().toCPointer<FloatVar>()!!.pointed.value
        set(value) { this.ptr.rawValue.plus(12).toLong().toCPointer<FloatVar>()!!.pointed.value = value }
}

// ============================================================
// DirectX 12 Structure Definitions
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

// ============================================================
// Root Parameter Structure for Constant Buffer
// ============================================================
// D3D12_ROOT_PARAMETER layout on 64-bit Windows:
// Offset 0:  ParameterType (4 bytes)
// Offset 4:  padding (4 bytes) - to align union to 8 bytes
// Offset 8:  Union (16 bytes) - largest member is DescriptorTable with pointer
// Offset 24: ShaderVisibility (4 bytes)
// Offset 28: padding (4 bytes)
// Total: 32 bytes
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
    companion object : Type(32, 8)  // Correct size for 64-bit

    var ParameterType: UInt
        get() = this.ptr.reinterpret<UIntVar>().pointed.value
        set(value) { this.ptr.reinterpret<UIntVar>().pointed.value = value }

    // Union starts at offset 8 (after 4-byte padding for alignment)
    fun constants(): D3D12_ROOT_CONSTANTS {
        val addr = this.ptr.rawValue + 8L
        return interpretCPointer<D3D12_ROOT_CONSTANTS>(addr)!!.pointed
    }

    // ShaderVisibility is at offset 24 (after 16-byte union)
    var ShaderVisibility: UInt
        get() = interpretCPointer<UIntVar>(this.ptr.rawValue + 24)!!.pointed.value
        set(value) { interpretCPointer<UIntVar>(this.ptr.rawValue + 24)!!.pointed.value = value }
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
    debugOutput("[initD3D12] START - Raymarching Demo")
    
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
                debugOutput("[initD3D12] Debug interface obtained")
                
                // ID3D12Debug::EnableDebugLayer (vtable #3)
                val enableDebugLayerFunc = comMethod(debugVar.value, 3)
                    ?.reinterpret<CFunction<(COpaquePointer?) -> Unit>>()
                if (enableDebugLayerFunc != null) {
                    enableDebugLayerFunc.invoke(debugVar.value)
                    debugOutput("[initD3D12] Debug layer enabled successfully")
                }
                
                releaseComObject(debugVar.value)
            }
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
        
        val deviceVar = alloc<COpaquePointerVar>()
        val hrDevice = createDeviceFunc.reinterpret<CFunction<(COpaquePointer?, UInt, CPointer<GUID>?, CPointer<COpaquePointerVar>?) -> Int>>()
            .invoke(null, D3D_FEATURE_LEVEL_11_0, iidDevice.ptr, deviceVar.ptr)
        
        if (hrDevice != 0) {
            debugOutput("[initD3D12] ERROR: D3D12CreateDevice failed: HRESULT=0x${toHex(hrDevice.toLong())}")
            return false
        }
        g_device = deviceVar.value
        debugOutput("[initD3D12] Device created successfully")
        
        // ===== Create Command Queue =====
        debugOutput("[initD3D12] Creating command queue...")
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
        
        // ===== Create DXGI Factory =====
        debugOutput("[initD3D12] Creating DXGI factory...")
        val createDxgiFactory = GetProcAddress(g_hDXGI, "CreateDXGIFactory1")
            ?.reinterpret<CFunction<(CPointer<GUID>?, CPointer<COpaquePointerVar>?) -> Int>>()
        if (createDxgiFactory == null) {
            debugOutput("[initD3D12] ERROR: CreateDXGIFactory1 not found")
            return false
        }
        
        val iidFactory = alloc<GUID>()
        initIID_IDXGIFactory4(iidFactory)
        val factoryVar = alloc<COpaquePointerVar>()
        val hrFactory = createDxgiFactory.invoke(iidFactory.ptr, factoryVar.ptr)
        if (hrFactory != 0) {
            debugOutput("[initD3D12] ERROR: CreateDXGIFactory1 failed: HRESULT=0x${toHex(hrFactory.toLong())}")
            return false
        }
        val factory = factoryVar.value
        debugOutput("[initD3D12] DXGI factory created")
        
        // ===== Create Swap Chain =====
        debugOutput("[initD3D12] Creating swap chain...")
        val scDesc = alloc<DXGI_SWAP_CHAIN_DESC1>()
        scDesc.Width = WINDOW_WIDTH.toUInt()
        scDesc.Height = WINDOW_HEIGHT.toUInt()
        scDesc.Format = DXGI_FORMAT_R8G8B8A8_UNORM
        scDesc.Stereo = 0
        scDesc.setSampleDesc(DXGI_SAMPLE_DESC_COUNT, DXGI_SAMPLE_DESC_QUALITY)
        scDesc.BufferUsage = DXGI_USAGE_RENDER_TARGET_OUTPUT
        scDesc.BufferCount = FRAME_COUNT
        scDesc.Scaling = 0u
        scDesc.SwapEffect = DXGI_SWAP_EFFECT_FLIP_DISCARD
        scDesc.AlphaMode = 0u
        scDesc.Flags = 0u
        
        val swapChain1Var = alloc<COpaquePointerVar>()
        // IDXGIFactory2::CreateSwapChainForHwnd (vtable #15)
        val createSCFunc = comMethod(factory, 15)
            ?.reinterpret<CFunction<(COpaquePointer?, COpaquePointer?, HWND?, CPointer<DXGI_SWAP_CHAIN_DESC1>?, COpaquePointer?, COpaquePointer?, CPointer<COpaquePointerVar>?) -> Int>>()
        val hrSC = createSCFunc?.invoke(factory, g_commandQueue, hwnd, scDesc.ptr, null, null, swapChain1Var.ptr) ?: -1
        if (hrSC != 0) {
            debugOutput("[initD3D12] ERROR: CreateSwapChainForHwnd failed: HRESULT=0x${toHex(hrSC.toLong())}")
            releaseComObject(factory)
            return false
        }
        
        // Query for IDXGISwapChain3
        val iidSwapChain3 = alloc<GUID>()
        initIID_IDXGISwapChain3(iidSwapChain3)
        g_swapChain = queryInterface(swapChain1Var.value, iidSwapChain3)
        releaseComObject(swapChain1Var.value)
        releaseComObject(factory)
        
        if (g_swapChain == null) {
            debugOutput("[initD3D12] ERROR: Failed to query IDXGISwapChain3")
            return false
        }
        debugOutput("[initD3D12] Swap chain created")
        
        // Get current back buffer index
        // IDXGISwapChain3::GetCurrentBackBufferIndex (vtable #36)
        val getBackBufferIndexFunc = comMethod(g_swapChain, 36)
            ?.reinterpret<CFunction<(COpaquePointer?) -> UInt>>()
        g_frameIndex = getBackBufferIndexFunc?.invoke(g_swapChain) ?: 0u
        
        // ===== Create RTV Heap =====
        debugOutput("[initD3D12] Creating RTV descriptor heap...")
        val rtvHeapDesc = alloc<D3D12_DESCRIPTOR_HEAP_DESC>()
        rtvHeapDesc.Type = D3D12_DESCRIPTOR_HEAP_TYPE_RTV
        rtvHeapDesc.NumDescriptors = FRAME_COUNT
        rtvHeapDesc.Flags = D3D12_DESCRIPTOR_HEAP_FLAG_NONE
        rtvHeapDesc.NodeMask = 0u
        
        val rtvHeapVar = alloc<COpaquePointerVar>()
        val iidRtvHeap = alloc<GUID>()
        initIID_ID3D12DescriptorHeap(iidRtvHeap)
        // ID3D12Device::CreateDescriptorHeap (vtable #14)
        val createHeapFunc = comMethod(g_device, 14)
            ?.reinterpret<CFunction<(COpaquePointer?, CPointer<D3D12_DESCRIPTOR_HEAP_DESC>?, CPointer<GUID>?, CPointer<COpaquePointerVar>?) -> Int>>()
        val hrHeap = createHeapFunc?.invoke(g_device, rtvHeapDesc.ptr, iidRtvHeap.ptr, rtvHeapVar.ptr) ?: -1
        if (hrHeap != 0) {
            debugOutput("[initD3D12] ERROR: CreateDescriptorHeap failed: HRESULT=0x${toHex(hrHeap.toLong())}")
            return false
        }
        g_rtvHeap = rtvHeapVar.value
        
        // ID3D12Device::GetDescriptorHandleIncrementSize (vtable #15)
        val getDescSizeFunc = comMethod(g_device, 15)
            ?.reinterpret<CFunction<(COpaquePointer?, UInt) -> UInt>>()
        g_rtvDescriptorSize = getDescSizeFunc?.invoke(g_device, D3D12_DESCRIPTOR_HEAP_TYPE_RTV) ?: 32u
        
        // Get heap start
        // ID3D12DescriptorHeap::GetCPUDescriptorHandleForHeapStart (vtable #9)
        val cpuHandleStruct = alloc<D3D12_CPU_DESCRIPTOR_HANDLE>()
        val getCpuHandleFunc = comMethod(g_rtvHeap, 9)
            ?.reinterpret<CFunction<(COpaquePointer?, CPointer<D3D12_CPU_DESCRIPTOR_HANDLE>?) -> Unit>>()
        getCpuHandleFunc?.invoke(g_rtvHeap, cpuHandleStruct.ptr)
        g_rtvHeapStartValue = cpuHandleStruct.value
        debugOutput("[initD3D12] RTV heap created, start=0x${toHex(g_rtvHeapStartValue.toLong())}, size=$g_rtvDescriptorSize")
        
        // ===== Create Render Target Views =====
        debugOutput("[initD3D12] Creating render target views...")
        val iidResource = alloc<GUID>()
        initIID_ID3D12Resource(iidResource)
        
        for (i in 0 until FRAME_COUNT.toInt()) {
            val resVar = alloc<COpaquePointerVar>()
            // IDXGISwapChain::GetBuffer (vtable #9)
            val getBufferFunc = comMethod(g_swapChain, 9)
                ?.reinterpret<CFunction<(COpaquePointer?, UInt, CPointer<GUID>?, CPointer<COpaquePointerVar>?) -> Int>>()
            val hrBuffer = getBufferFunc?.invoke(g_swapChain, i.toUInt(), iidResource.ptr, resVar.ptr) ?: -1
            if (hrBuffer != 0) {
                debugOutput("[initD3D12] ERROR: GetBuffer failed for index $i: HRESULT=0x${toHex(hrBuffer.toLong())}")
                return false
            }
            g_renderTargets[i] = resVar.value
            
            val rtvHandle = getRtvHandle(i.toUInt())
            // ID3D12Device::CreateRenderTargetView (vtable #20)
            val createRTVFunc = comMethod(g_device, 20)
                ?.reinterpret<CFunction<(COpaquePointer?, COpaquePointer?, COpaquePointer?, ULong) -> Unit>>()
            createRTVFunc?.invoke(g_device, g_renderTargets[i], null, rtvHandle)
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

        // ===== Create Root Signature with 32-bit Constants =====
        debugOutput("[initD3D12] Creating root signature with constant buffer...")
        val serializeFunc = GetProcAddress(g_hD3D12, "D3D12SerializeRootSignature")
            ?.reinterpret<CFunction<(CPointer<D3D12_ROOT_SIGNATURE_DESC>?, UInt, CPointer<COpaquePointerVar>?, CPointer<COpaquePointerVar>?) -> Int>>()
        if (serializeFunc == null) {
            debugOutput("[initD3D12] ERROR: D3D12SerializeRootSignature not found")
            return false
        }

        // Create root parameter for 32-bit constants (4 floats = 16 bytes)
        val rootParam = alloc<D3D12_ROOT_PARAMETER>()
        memset(rootParam.ptr, 0, 32.convert())  // Clear entire structure
        rootParam.ParameterType = D3D12_ROOT_PARAMETER_TYPE_32BIT_CONSTANTS
        rootParam.constants().ShaderRegister = 0u  // b0
        rootParam.constants().RegisterSpace = 0u
        rootParam.constants().Num32BitValues = 4u  // iTime, iResolution.x, iResolution.y, padding
        rootParam.ShaderVisibility = D3D12_SHADER_VISIBILITY_ALL

        val rsDesc = alloc<D3D12_ROOT_SIGNATURE_DESC>()
        rsDesc.NumParameters = 1u
        rsDesc.pParameters = rootParam.ptr as COpaquePointer
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
        debugOutput("[initD3D12] Root signature created with 32-bit constants")

        // ===== Create Pipeline State =====
        debugOutput("[initD3D12] Creating pipeline state...")
        val vsBlob = compileShader("VSMain", "vs_5_0")
        if (vsBlob == null) {
            debugOutput("[initD3D12] ERROR: Vertex shader compilation failed")
            return false
        }
        val psBlob = compileShader("PSMain", "ps_5_0")
        if (psBlob == null) {
            releaseComObject(vsBlob)
            debugOutput("[initD3D12] ERROR: Pixel shader compilation failed")
            return false
        }

        memScoped {
            val posName = "POSITION".cstr

            // Single input element: POSITION (float2)
            val layout = allocArray<D3D12_INPUT_ELEMENT_DESC>(1)
            val pos = interpretCPointer<D3D12_INPUT_ELEMENT_DESC>(layout[0].rawPtr)!!.pointed
            pos.SemanticName = posName.ptr
            pos.SemanticIndex = 0u
            pos.Format = DXGI_FORMAT_R32G32_FLOAT  // float2
            pos.InputSlot = 0u
            pos.AlignedByteOffset = 0u
            pos.InputSlotClass = D3D12_INPUT_CLASSIFICATION_PER_VERTEX_DATA
            pos.InstanceDataStepRate = 0u

            val psoDesc = alloc<D3D12_GRAPHICS_PIPELINE_STATE_DESC>()
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
            il.NumElements = 1u

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

        // ===== Create Vertex Buffer (Fullscreen Quad) =====
        debugOutput("[initD3D12] Creating vertex buffer for fullscreen quad...")
        val heapProps = alloc<D3D12_HEAP_PROPERTIES>()
        heapProps.Type = D3D12_HEAP_TYPE_UPLOAD
        heapProps.CPUPageProperty = 0u
        heapProps.MemoryPoolPreference = 0u
        heapProps.CreationNodeMask = 1u
        heapProps.VisibleNodeMask = 1u

        // 6 vertices for 2 triangles (fullscreen quad)
        val vertexBufferSize = (VERTEX.size * 6).toULong()
        
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

        // Map and fill vertex buffer
        val mapFunc = comMethod(g_vertexBuffer, 8)
            ?.reinterpret<CFunction<(COpaquePointer?, UInt, CPointer<D3D12_RANGE>?, CPointer<COpaquePointerVar>?) -> Int>>()
        val mappedVar = alloc<COpaquePointerVar>()
        val hrMap = mapFunc?.invoke(g_vertexBuffer, 0u, null, mappedVar.ptr) ?: -1
        if (hrMap != 0) {
            debugOutput("[initD3D12] ERROR: Map failed: HRESULT=0x${toHex(hrMap.toLong())}")
            return false
        }

        // Fullscreen quad vertices (two triangles)
        // Triangle 1: top-left, top-right, bottom-left
        // Triangle 2: bottom-left, top-right, bottom-right
        memScoped {
            val vertices = allocArray<VERTEX>(6)
            
            // Triangle 1
            interpretCPointer<VERTEX>(vertices[0].rawPtr)!!.pointed.apply {
                x = -1.0f; y = 1.0f   // Top-left
            }
            interpretCPointer<VERTEX>(vertices[1].rawPtr)!!.pointed.apply {
                x = 1.0f; y = 1.0f    // Top-right
            }
            interpretCPointer<VERTEX>(vertices[2].rawPtr)!!.pointed.apply {
                x = -1.0f; y = -1.0f  // Bottom-left
            }
            
            // Triangle 2
            interpretCPointer<VERTEX>(vertices[3].rawPtr)!!.pointed.apply {
                x = -1.0f; y = -1.0f  // Bottom-left
            }
            interpretCPointer<VERTEX>(vertices[4].rawPtr)!!.pointed.apply {
                x = 1.0f; y = 1.0f    // Top-right
            }
            interpretCPointer<VERTEX>(vertices[5].rawPtr)!!.pointed.apply {
                x = 1.0f; y = -1.0f   // Bottom-right
            }

            memcpy(mappedVar.value, vertices, vertexBufferSize.toULong())
        }

        // Unmap vertex buffer
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
        debugOutput("[initD3D12] Vertex buffer created for fullscreen quad")

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

        // Initialize start time for animation
        g_startTime = GetTickCount64().toLong()

        debugOutput("[initD3D12] DirectX 12 raymarching pipeline initialized successfully!")
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
        debugOutput("[render] First frame rendering - Raymarching Demo")
    }

    // Calculate elapsed time for animation
    val currentTime = GetTickCount64().toLong()
    val elapsedTime = (currentTime - g_startTime).toFloat() / 1000.0f  // Convert to seconds

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

    // Set 32-bit constants for raymarching
    // ID3D12GraphicsCommandList::SetGraphicsRoot32BitConstants (vtable #36)
    // Vtable layout: 32=SetGraphicsRootDescriptorTable, 33=SetComputeRoot32BitConstant,
    // 34=SetGraphicsRoot32BitConstant, 35=SetComputeRoot32BitConstants, 36=SetGraphicsRoot32BitConstants
    val setConstantsFunc = comMethod(g_commandList, 36)
        ?.reinterpret<CFunction<(COpaquePointer?, UInt, UInt, COpaquePointer?, UInt) -> Unit>>()
    
    memScoped {
        // Create constant buffer data: iTime, iResolution.x, iResolution.y, padding
        val constants = allocArray<FloatVar>(4)
        constants[0] = elapsedTime                    // iTime
        constants[1] = WINDOW_WIDTH.toFloat()         // iResolution.x
        constants[2] = WINDOW_HEIGHT.toFloat()        // iResolution.y
        constants[3] = 0.0f                           // padding
        
        setConstantsFunc?.invoke(g_commandList, 0u, 4u, constants as COpaquePointer, 0u)
        
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
        clearColor[0] = 0.0f
        clearColor[1] = 0.0f
        clearColor[2] = 0.0f
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
        // Draw 6 vertices (2 triangles for fullscreen quad)
        val drawFunc = comMethod(g_commandList, 12)
            ?.reinterpret<CFunction<(COpaquePointer?, UInt, UInt, UInt, UInt) -> Unit>>()
        drawFunc?.invoke(g_commandList, 6u, 1u, 0u, 0u)

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
// Main Entry Point
// ============================================================
fun main() {
    debugOutput("============================================================")
    debugOutput("[MAIN] DirectX 12 Raymarching Demo")
    debugOutput("[MAIN] Features:")
    debugOutput("[MAIN]   - Signed Distance Functions (sphere, torus)")
    debugOutput("[MAIN]   - Smooth blending between shapes")
    debugOutput("[MAIN]   - Phong lighting with soft shadows")
    debugOutput("[MAIN]   - Ambient occlusion")
    debugOutput("[MAIN]   - Animated scene (bouncing sphere, rotating torus)")
    debugOutput("[MAIN]   - Checkerboard floor pattern")
    debugOutput("============================================================")
    
    memScoped {
        val hInstance = GetModuleHandleW(null)
        val className = "DirectX12RaymarchingWindow"
        val windowName = "DirectX 12 Raymarching Demo"
        
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
        
        // Create window with specific size
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
        
        debugOutput("[MAIN] Window created (${WINDOW_WIDTH}x${WINDOW_HEIGHT})")
        
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
        debugOutput("[MAIN] Entering message loop - Enjoy the raymarching animation!")
        
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
