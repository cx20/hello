@file:OptIn(kotlinx.cinterop.ExperimentalForeignApi::class, kotlin.experimental.ExperimentalNativeApi::class)

import kotlinx.cinterop.*
import platform.windows.*

// ============================================================
// Kotlin/Native  EDirectComposition composite of three triangles:
//   Left:   OpenGL 4.6 (WGL_NV_DX_interop -> DXGI SwapChain)
//   Centre: Direct3D 11
//   Right:  Vulkan 1.4 (offscreen -> readback -> D3D11 staging -> SwapChain)
//
// Build (Kotlin/Native, mingwX64):
//   kotlinc-native hello.kt -o hello -linker-options "-lopengl32"
//
// Runtime requirements on PATH / working directory:
//   vulkan-1.dll, shaderc_shared.dll, d3d11.dll, dxgi.dll,
//   d3dcompiler_47.dll, dcomp.dll
// ============================================================

// ============================================================
// Debug
// ============================================================
private fun debugPrint(msg: String) { println(msg) }

// ============================================================
// Pointer / handle helpers
// ============================================================
private fun Long.asPtr(): COpaquePointer? {
    if (this == 0L) return null
    val tmp = nativeHeap.alloc<LongVar>()
    tmp.value = this
    val v = tmp.ptr.reinterpret<COpaquePointerVar>()[0]
    nativeHeap.free(tmp)
    return v
}

private fun CPointer<*>?.asLong(): Long {
    if (this == null) return 0L
    val tmp = nativeHeap.alloc<COpaquePointerVar>()
    tmp.value = this
    val v = tmp.ptr.reinterpret<LongVar>()[0]
    nativeHeap.free(tmp)
    return v
}

// Struct write helpers (write at byte offset into raw memory)
private fun CPointer<ByteVar>.w32(off: Int, v: UInt) { (this + off)!!.reinterpret<UIntVar>()[0] = v }
private fun CPointer<ByteVar>.w32(off: Int, v: Int) { (this + off)!!.reinterpret<IntVar>()[0] = v }
private fun CPointer<ByteVar>.w16(off: Int, v: UShort) { (this + off)!!.reinterpret<UShortVar>()[0] = v }
private fun CPointer<ByteVar>.w64(off: Int, v: Long) { (this + off)!!.reinterpret<LongVar>()[0] = v }
private fun CPointer<ByteVar>.wF(off: Int, v: Float) { (this + off)!!.reinterpret<FloatVar>()[0] = v }
private fun CPointer<ByteVar>.wP(off: Int, p: CPointer<*>?) { w64(off, p.asLong()) }
private fun CPointer<ByteVar>.r32(off: Int): UInt = (this + off)!!.reinterpret<UIntVar>()[0]
private fun CPointer<ByteVar>.r64(off: Int): Long = (this + off)!!.reinterpret<LongVar>()[0]
private fun CPointer<ByteVar>.rP(off: Int): COpaquePointer? = r64(off).asPtr()

// Zero-filled struct allocation
private fun NativePlacement.zalloc(size: Int): CPointer<ByteVar> {
    val p = allocArray<ByteVar>(size)
    for (i in 0 until size) p[i] = 0
    return p
}

// Persistent allocation (survives memScoped)
private val _keep = mutableListOf<Any>()
private fun keepAlive(p: CPointer<*>) { _keep.add(p) }

private fun heapZalloc(size: Int): CPointer<ByteVar> {
    val p = nativeHeap.allocArray<ByteVar>(size)
    for (i in 0 until size) p[i] = 0
    keepAlive(p)
    return p
}

private fun heapCstr(s: String): CPointer<ByteVar> {
    val bytes = s.encodeToByteArray()
    val p = nativeHeap.allocArray<ByteVar>(bytes.size + 1)
    for (i in bytes.indices) p[i] = bytes[i]
    p[bytes.size] = 0
    keepAlive(p)
    return p
}

// ============================================================
// COM vtable call helpers
//
// A COM object pointer is a pointer to a pointer to the vtable.
//   obj -> [vtbl*]  ->  [slot0, slot1, slot2, ...]
//
// VTBL(obj) = *(void***)obj = pointer to vtable array
// SLOT(obj, i) = VTBL(obj)[i]
// ============================================================
private fun vtbl(obj: COpaquePointer?): CPointer<COpaquePointerVar> {
    // obj points to a struct whose first member is the vtable pointer
    return obj!!.reinterpret<COpaquePointerVar>()[0]!!.reinterpret()
}

private fun slot(obj: COpaquePointer?, index: Int): COpaquePointer? {
    return vtbl(obj)[index]
}

// IUnknown helpers
private fun comQI(obj: COpaquePointer?, iid: CPointer<ByteVar>, ppOut: CPointer<COpaquePointerVar>): Int {
    // slot 0 = QueryInterface(this, riid, ppvObject)
    val fn = slot(obj, 0)!!.reinterpret<CFunction<(COpaquePointer?, COpaquePointer?, COpaquePointer?) -> Int>>()
    return fn(obj, iid, ppOut)
}

private fun comRelease(obj: COpaquePointer?): UInt {
    if (obj == null) return 0u
    // slot 2 = Release(this)
    val fn = slot(obj, 2)!!.reinterpret<CFunction<(COpaquePointer?) -> UInt>>()
    return fn(obj)
}

// ============================================================
// GUID helpers
// ============================================================
private fun NativePlacement.guid(
    d1: UInt, d2: UShort, d3: UShort,
    b0: Byte, b1: Byte, b2: Byte, b3: Byte,
    b4: Byte, b5: Byte, b6: Byte, b7: Byte
): CPointer<ByteVar> {
    val p = zalloc(16)
    p.w32(0, d1)
    p.w16(4, d2); p.w16(6, d3)
    p[8] = b0; p[9] = b1; p[10] = b2; p[11] = b3
    p[12] = b4; p[13] = b5; p[14] = b6; p[15] = b7
    return p
}

// Heap-allocated (permanent) GUID
private fun heapGuid(
    d1: UInt, d2: UShort, d3: UShort,
    b0: Byte, b1: Byte, b2: Byte, b3: Byte,
    b4: Byte, b5: Byte, b6: Byte, b7: Byte
): CPointer<ByteVar> {
    val p = heapZalloc(16)
    p.w32(0, d1)
    p.w16(4, d2.toUShort()); p.w16(6, d3.toUShort())
    p[8] = b0; p[9] = b1; p[10] = b2; p[11] = b3
    p[12] = b4; p[13] = b5; p[14] = b6; p[15] = b7
    return p
}

// ============================================================
// Well-known GUIDs
// ============================================================
// IID_IDXGIDevice {54ec77fa-1377-44e6-8c32-88fd5f44c84c}
private val IID_IDXGIDevice = heapGuid(
    0x54EC77FAu, 0x1377u, 0x44E6u,
    0x8C.toByte(), 0x32.toByte(), 0x88.toByte(), 0xFD.toByte(),
    0x5F.toByte(), 0x44.toByte(), 0xC8.toByte(), 0x4C.toByte()
)

// IID_IDXGIFactory2 {50c83a1c-e072-4c48-87b0-3630fa36a6d0}
private val IID_IDXGIFactory2 = heapGuid(
    0x50C83A1Cu, 0xE072u, 0x4C48u,
    0x87.toByte(), 0xB0.toByte(), 0x36.toByte(), 0x30.toByte(),
    0xFA.toByte(), 0x36.toByte(), 0xA6.toByte(), 0xD0.toByte()
)

// IID_ID3D11Texture2D {6f15aaf2-d208-4e89-9ab4-489535d34f9c}
private val IID_ID3D11Texture2D = heapGuid(
    0x6F15AAF2u, 0xD208u, 0x4E89u,
    0x9A.toByte(), 0xB4.toByte(), 0x48.toByte(), 0x95.toByte(),
    0x35.toByte(), 0xD3.toByte(), 0x4F.toByte(), 0x9C.toByte()
)

// IID_IDCompositionDevice {C37EA93A-E7AA-450D-B16F-9746CB0407F3}
private val IID_IDCompositionDevice = heapGuid(
    0xC37EA93Au, 0xE7AAu, 0x450Du,
    0xB1.toByte(), 0x6F.toByte(), 0x97.toByte(), 0x46.toByte(),
    0xCB.toByte(), 0x04.toByte(), 0x07.toByte(), 0xF3.toByte()
)

// ============================================================
// D3D11 / DXGI constants
// ============================================================
private const val D3D_DRIVER_TYPE_HARDWARE = 1
private const val D3D11_SDK_VERSION = 7u
private const val D3D_FEATURE_LEVEL_11_0 = 0xB000
private const val D3D11_CREATE_DEVICE_BGRA_SUPPORT = 0x20u
private const val DXGI_FORMAT_B8G8R8A8_UNORM_D3D = 87u
private const val DXGI_FORMAT_R32G32B32_FLOAT = 6u
private const val DXGI_FORMAT_R32G32B32A32_FLOAT = 2u
private const val DXGI_USAGE_RENDER_TARGET_OUTPUT = 0x20u
private const val DXGI_SCALING_STRETCH = 0u
private const val DXGI_SWAP_EFFECT_FLIP_SEQUENTIAL = 3u
private const val DXGI_ALPHA_MODE_PREMULTIPLIED = 1u
private const val D3D11_USAGE_DEFAULT = 0u
private const val D3D11_USAGE_STAGING = 3u
private const val D3D11_BIND_VERTEX_BUFFER = 0x1u
private const val D3D11_CPU_ACCESS_WRITE = 0x10000u
private const val D3D11_MAP_WRITE = 2u
private const val D3D11_INPUT_PER_VERTEX_DATA = 0u
private const val D3D_PRIMITIVE_TOPOLOGY_TRIANGLELIST = 4u
private const val D3DCOMPILE_ENABLE_STRICTNESS = 0x800u

// D3D11 COM vtable slot indices
// ID3D11Device : IUnknown (slots 0-2)
private const val D3D11DEV_CreateBuffer = 3
private const val D3D11DEV_CreateTexture2D = 5
private const val D3D11DEV_CreateRenderTargetView = 9
private const val D3D11DEV_CreateInputLayout = 11
private const val D3D11DEV_CreateVertexShader = 12
private const val D3D11DEV_CreatePixelShader = 15

// ID3D11DeviceContext : ID3D11DeviceChild(3-6) : IUnknown(0-2)
private const val D3D11CTX_PSSetShader = 9
private const val D3D11CTX_VSSetShader = 11
private const val D3D11CTX_Draw = 13
private const val D3D11CTX_Map = 14
private const val D3D11CTX_Unmap = 15
private const val D3D11CTX_IASetInputLayout = 17
private const val D3D11CTX_IASetVertexBuffers = 18
private const val D3D11CTX_IASetPrimitiveTopology = 24
private const val D3D11CTX_OMSetRenderTargets = 33
private const val D3D11CTX_RSSetViewports = 44
private const val D3D11CTX_CopyResource = 47
private const val D3D11CTX_ClearRenderTargetView = 50

// IDXGISwapChain(8-17) : IDXGIDeviceSubObject(7) : IDXGIObject(3-6) : IUnknown(0-2)
private const val DXGISC_Present = 8
private const val DXGISC_GetBuffer = 9

// IDXGIDevice : IDXGIObject(3-6) : IUnknown(0-2)
private const val DXGIDEV_GetAdapter = 7

// IDXGIAdapter/IDXGIObject : IUnknown(0-2)  ->  GetParent = slot 6
private const val DXGIOBJ_GetParent = 6

// IDXGIFactory2(14-24) : IDXGIFactory1(12-13) : IDXGIFactory(7-11) : IDXGIObject(3-6) : IUnknown(0-2)
private const val DXGIFACT2_CreateSwapChainForComposition = 24

// ID3DBlob : IUnknown(0-2)
private const val BLOB_GetBufferPointer = 3
private const val BLOB_GetBufferSize = 4

// IDCompositionDevice : IUnknown(0-2)
private const val DCOMP_Commit = 3
private const val DCOMP_CreateTargetForHwnd = 6
private const val DCOMP_CreateVisual = 7

// IDCompositionTarget : IUnknown(0-2)
private const val DCTARGET_SetRoot = 3

// IDCompositionVisual : IUnknown(0-2)
private const val DCVISUAL_SetOffsetX_Float = 4
private const val DCVISUAL_SetOffsetY_Float = 6
private const val DCVISUAL_SetContent = 15
private const val DCVISUAL_AddVisual = 16

// ============================================================
// OpenGL constants
// ============================================================
private const val GL_TRIANGLES = 0x0004u
private const val GL_FLOAT = 0x1406u
private const val GL_COLOR_BUFFER_BIT = 0x4000u
private const val GL_ARRAY_BUFFER = 0x8892u
private const val GL_STATIC_DRAW = 0x88E4u
private const val GL_FRAGMENT_SHADER = 0x8B30u
private const val GL_VERTEX_SHADER = 0x8B31u
private const val GL_FRAMEBUFFER = 0x8D40u
private const val GL_RENDERBUFFER = 0x8D41u
private const val GL_COLOR_ATTACHMENT0 = 0x8CE0u
private const val GL_FRAMEBUFFER_COMPLETE = 0x8CD5u
private const val GL_COMPILE_STATUS = 0x8B81u
private const val GL_LINK_STATUS = 0x8B82u
private const val GL_FALSE = 0
private const val WGL_CONTEXT_MAJOR_VERSION_ARB = 0x2091
private const val WGL_CONTEXT_MINOR_VERSION_ARB = 0x2092
private const val WGL_CONTEXT_FLAGS_ARB = 0x2094
private const val WGL_CONTEXT_PROFILE_MASK_ARB = 0x9126
private const val WGL_CONTEXT_CORE_PROFILE_BIT_ARB = 0x00000001
private const val WGL_ACCESS_READ_WRITE_NV = 0x0001

// ============================================================
// Vulkan constants
// ============================================================
private const val VK_SUCCESS = 0
private const val VK_STYPE_APP_INFO = 0u
private const val VK_STYPE_INSTANCE_CI = 1u
private const val VK_STYPE_DEVICE_QUEUE_CI = 2u
private const val VK_STYPE_DEVICE_CI = 3u
private const val VK_STYPE_SUBMIT_INFO = 4u
private const val VK_STYPE_FENCE_CI = 8u
private const val VK_STYPE_IMAGE_CI = 14u
private const val VK_STYPE_IMAGE_VIEW_CI = 15u
private const val VK_STYPE_SHADER_MODULE_CI = 16u
private const val VK_STYPE_PIPE_SHADER_STAGE_CI = 18u
private const val VK_STYPE_PIPE_VERTEX_INPUT_CI = 19u
private const val VK_STYPE_PIPE_INPUT_ASM_CI = 20u
private const val VK_STYPE_PIPE_VIEWPORT_CI = 22u
private const val VK_STYPE_PIPE_RASTERIZATION_CI = 23u
private const val VK_STYPE_PIPE_MULTISAMPLE_CI = 24u
private const val VK_STYPE_PIPE_COLOR_BLEND_CI = 26u
private const val VK_STYPE_GRAPHICS_PIPE_CI = 28u
private const val VK_STYPE_PIPE_LAYOUT_CI = 30u
private const val VK_STYPE_MEM_ALLOC_INFO = 5u
private const val VK_STYPE_BUFFER_CI = 12u
private const val VK_STYPE_FRAMEBUFFER_CI = 37u
private const val VK_STYPE_RENDER_PASS_CI = 38u
private const val VK_STYPE_CMD_POOL_CI = 39u
private const val VK_STYPE_CMD_BUF_ALLOC_INFO = 40u
private const val VK_STYPE_CMD_BUF_BEGIN_INFO = 42u
private const val VK_STYPE_RENDER_PASS_BEGIN_INFO = 43u

private const val VK_QUEUE_GRAPHICS_BIT = 0x1u
private const val VK_CMD_POOL_RESET_CMD_BIT = 0x2u
private const val VK_CMD_BUF_LEVEL_PRIMARY = 0u
private const val VK_IMAGE_ASPECT_COLOR = 0x1u
private const val VK_IMAGE_VIEW_TYPE_2D = 1u
private const val VK_FORMAT_B8G8R8A8_UNORM_VK = 44u
private const val VK_IMAGE_LAYOUT_UNDEFINED = 0u
private const val VK_IMAGE_LAYOUT_COLOR_ATT = 2u
private const val VK_IMAGE_LAYOUT_TRANSFER_SRC = 7u
private const val VK_LOAD_OP_CLEAR = 1u
private const val VK_STORE_OP_STORE = 0u
private const val VK_LOAD_OP_DONT_CARE = 2u
private const val VK_STORE_OP_DONT_CARE = 1u
private const val VK_BIND_POINT_GRAPHICS = 0u
private const val VK_TOPO_TRIANGLE_LIST = 3u
private const val VK_POLYGON_FILL = 0u
private const val VK_CULL_NONE = 0u
private const val VK_CULL_BACK = 2u
private const val VK_FRONT_CW = 0u
private const val VK_SAMPLE_1 = 1u
private const val VK_COLOR_RGBA = 0xFu
private const val VK_STAGE_VERTEX = 0x1u
private const val VK_STAGE_FRAGMENT = 0x10u
private const val VK_FENCE_SIGNALED = 0x1u
private const val VK_SUBPASS_INLINE = 0u
private const val VK_IMAGE_TYPE_2D = 1u
private const val VK_IMAGE_TILING_OPTIMAL = 0u
private const val VK_IMAGE_USAGE_COLOR_ATT = 0x10u
private const val VK_IMAGE_USAGE_TRANSFER_SRC = 0x1u
private const val VK_BUFFER_USAGE_TRANSFER_DST = 0x2u
private const val VK_MEMORY_PROPERTY_DEVICE_LOCAL = 0x1u
private const val VK_MEMORY_PROPERTY_HOST_VISIBLE = 0x2u
private const val VK_MEMORY_PROPERTY_HOST_COHERENT = 0x4u

private fun vkVersion(ma: Int, mi: Int, pa: Int): UInt = ((ma shl 22) or (mi shl 12) or pa).toUInt()

private fun vkCheck(res: Int, msg: String) {
    if (res != VK_SUCCESS) throw RuntimeException("$msg failed: VkResult=$res")
}

// ============================================================
// Vulkan function pointer types
// ============================================================
private typealias Fn_PP_P = CFunction<(COpaquePointer?, COpaquePointer?) -> COpaquePointer?>
private typealias Fn_PPP_I = CFunction<(COpaquePointer?, COpaquePointer?, COpaquePointer?) -> Int>
private typealias Fn_PPPP_I = CFunction<(COpaquePointer?, COpaquePointer?, COpaquePointer?, COpaquePointer?) -> Int>
private typealias Fn_PP_V = CFunction<(COpaquePointer?, COpaquePointer?) -> Unit>
private typealias Fn_PLP_V = CFunction<(COpaquePointer?, Long, COpaquePointer?) -> Unit>
private typealias Fn_PPP_V = CFunction<(COpaquePointer?, COpaquePointer?, COpaquePointer?) -> Unit>
private typealias Fn_P_I = CFunction<(COpaquePointer?) -> Int>
private typealias Fn_PUUP_V = CFunction<(COpaquePointer?, UInt, UInt, COpaquePointer?) -> Unit>
private typealias Fn_PLUPP_I = CFunction<(COpaquePointer?, Long, UInt, COpaquePointer?, COpaquePointer?, COpaquePointer?) -> Int>
private typealias Fn_PUP_U_L_I = CFunction<(COpaquePointer?, UInt, COpaquePointer?, UInt, Long) -> Int>
private typealias Fn_PUP_I = CFunction<(COpaquePointer?, UInt, COpaquePointer?) -> Int>
private typealias Fn_PP_I = CFunction<(COpaquePointer?, COpaquePointer?) -> Int>
private typealias Fn_PPU_V = CFunction<(COpaquePointer?, COpaquePointer?, UInt) -> Unit>
private typealias Fn_PUL_V = CFunction<(COpaquePointer?, UInt, Long) -> Unit>
private typealias Fn_PUUUU_V = CFunction<(COpaquePointer?, UInt, UInt, UInt, UInt) -> Unit>
private typealias Fn_P_V = CFunction<(COpaquePointer?) -> Unit>

// Vulkan memory functions
private typealias Fn_PPPP2_I = CFunction<(COpaquePointer?, COpaquePointer?, COpaquePointer?, COpaquePointer?) -> Int> // allocMem
private typealias Fn_PLL_V = CFunction<(COpaquePointer?, Long, Long) -> Unit> // bindImgMem (simplified)
private typealias Fn_PLLLUUP_I = CFunction<(COpaquePointer?, Long, Long, Long, UInt, UInt, COpaquePointer?) -> Int> // mapMemory
private typealias Fn_PL_V = CFunction<(COpaquePointer?, Long) -> Unit> // unmapMemory
private typealias Fn_PPLLLLP_V = CFunction<(COpaquePointer?, COpaquePointer?, Long, Long, UInt, COpaquePointer?) -> Unit> // cmdCopyImgToBuf

// Shaderc
private typealias Fn_Void_P = CFunction<() -> COpaquePointer?>
private typealias Fn_ShP_Void = CFunction<(COpaquePointer?) -> Unit>
private typealias Fn_PInt_V = CFunction<(COpaquePointer?, Int) -> Unit>
private typealias Fn_P_SizeT = CFunction<(COpaquePointer?) -> Long>
private typealias Fn_P_IntSh = CFunction<(COpaquePointer?) -> Int>
private typealias Fn_P_OPtr = CFunction<(COpaquePointer?) -> COpaquePointer?>
private typealias Fn_Compile = CFunction<(COpaquePointer?, COpaquePointer?, Long, Int, COpaquePointer?, COpaquePointer?, COpaquePointer?) -> COpaquePointer?>

// ============================================================
// Vulkan function variables (loaded dynamically)
// ============================================================
private lateinit var vkGetInstanceProcAddr: CPointer<Fn_PP_P>
private lateinit var vkGetDeviceProcAddr: CPointer<Fn_PP_P>
private lateinit var vkDestroyInstance: CPointer<Fn_PP_V>
private lateinit var vkDestroyDevice: CPointer<Fn_PP_V>
private lateinit var vkGetDeviceQueue: CPointer<Fn_PUUP_V>
private lateinit var vkCreateImageView: CPointer<Fn_PPPP_I>
private lateinit var vkDestroyImageView: CPointer<Fn_PLP_V>
private lateinit var vkCreateShaderModule: CPointer<Fn_PPPP_I>
private lateinit var vkDestroyShaderModule: CPointer<Fn_PLP_V>
private lateinit var vkCreateRenderPass: CPointer<Fn_PPPP_I>
private lateinit var vkDestroyRenderPass: CPointer<Fn_PLP_V>
private lateinit var vkCreatePipelineLayout: CPointer<Fn_PPPP_I>
private lateinit var vkDestroyPipelineLayout: CPointer<Fn_PLP_V>
private lateinit var vkCreateGraphicsPipelines: CPointer<Fn_PLUPP_I>
private lateinit var vkDestroyPipeline: CPointer<Fn_PLP_V>
private lateinit var vkCreateFramebuffer: CPointer<Fn_PPPP_I>
private lateinit var vkDestroyFramebuffer: CPointer<Fn_PLP_V>
private lateinit var vkCreateCommandPool: CPointer<Fn_PPPP_I>
private lateinit var vkDestroyCommandPool: CPointer<Fn_PLP_V>
private lateinit var vkAllocateCommandBuffers: CPointer<Fn_PPP_I>
private lateinit var vkBeginCommandBuffer: CPointer<Fn_PP_I>
private lateinit var vkEndCommandBuffer: CPointer<Fn_P_I>
private lateinit var vkCmdBeginRenderPass: CPointer<Fn_PPU_V>
private lateinit var vkCmdEndRenderPass: CPointer<Fn_P_V>
private lateinit var vkCmdBindPipeline: CPointer<Fn_PUL_V>
private lateinit var vkCmdDraw: CPointer<Fn_PUUUU_V>
private lateinit var vkCreateFence: CPointer<Fn_PPPP_I>
private lateinit var vkDestroyFence: CPointer<Fn_PLP_V>
private lateinit var vkWaitForFences: CPointer<Fn_PUP_U_L_I>
private lateinit var vkResetFences: CPointer<Fn_PUP_I>
private lateinit var vkQueueSubmit: CPointer<CFunction<(COpaquePointer?, UInt, COpaquePointer?, Long) -> Int>>
private lateinit var vkDeviceWaitIdle: CPointer<Fn_P_I>
private lateinit var vkCreateImage: CPointer<Fn_PPPP_I>
private lateinit var vkDestroyImage: CPointer<Fn_PLP_V>
private lateinit var vkGetImageMemoryRequirements: CPointer<Fn_PPP_V>
private lateinit var vkAllocateMemory: CPointer<Fn_PPPP_I>
private lateinit var vkFreeMemory: CPointer<Fn_PLP_V>
private lateinit var vkBindImageMemory: CPointer<CFunction<(COpaquePointer?, Long, Long, Long) -> Int>>
private lateinit var vkCreateBuffer: CPointer<Fn_PPPP_I>
private lateinit var vkDestroyBuffer: CPointer<Fn_PLP_V>
private lateinit var vkGetBufferMemoryRequirements: CPointer<Fn_PPP_V>
private lateinit var vkBindBufferMemory: CPointer<CFunction<(COpaquePointer?, Long, Long, Long) -> Int>>
private lateinit var vkMapMemory: CPointer<CFunction<(COpaquePointer?, Long, Long, Long, UInt, COpaquePointer?) -> Int>>
private lateinit var vkUnmapMemory: CPointer<CFunction<(COpaquePointer?, Long) -> Unit>>
private lateinit var vkCmdCopyImageToBuffer: CPointer<CFunction<(COpaquePointer?, Long, UInt, Long, UInt, COpaquePointer?) -> Unit>>
private lateinit var vkGetPhysicalDeviceMemoryProperties: CPointer<Fn_PP_V>
private lateinit var vkResetCommandBuffer: CPointer<CFunction<(COpaquePointer?, UInt) -> Int>>

// ============================================================
// DLL function loaders
// ============================================================
private inline fun <reified T : CFunction<*>> loadDll(dll: HMODULE?, name: String): CPointer<T> {
    return (GetProcAddress(dll, name) ?: throw RuntimeException("$name not found")).reinterpret()
}

private inline fun <reified T : CFunction<*>> loadVkInst(inst: COpaquePointer?, name: String): CPointer<T> {
    val p = vkGetInstanceProcAddr(inst, heapCstr(name))
        ?: throw RuntimeException("vkGetInstanceProcAddr: $name not found")
    return p.reinterpret()
}

private inline fun <reified T : CFunction<*>> loadVkDev(dev: COpaquePointer?, name: String): CPointer<T> {
    val p = vkGetDeviceProcAddr(dev, heapCstr(name))
        ?: throw RuntimeException("vkGetDeviceProcAddr: $name not found")
    return p.reinterpret()
}

// ============================================================
// Shader sources
// ============================================================

// GLSL for OpenGL panel
private val GL_VERT_SRC = """
#version 460 core
layout(location=0) in vec3 position;
layout(location=1) in vec3 color;
out vec4 vColor;
void main(){ vColor=vec4(color,1.0); gl_Position=vec4(position.x,-position.y,position.z,1.0); }
""".trimIndent()

private val GL_FRAG_SRC = """
#version 460 core
in vec4 vColor;
out vec4 outColor;
void main(){ outColor=vColor; }
""".trimIndent()

// HLSL for D3D11 panel
private val D3D_VS_HLSL = """
struct VSInput { float3 pos:POSITION; float4 col:COLOR; };
struct VSOutput{ float4 pos:SV_POSITION; float4 col:COLOR; };
VSOutput main(VSInput i){ VSOutput o; o.pos=float4(i.pos,1); o.col=i.col; return o; }
""".trimIndent()

private val D3D_PS_HLSL = """
struct PSInput { float4 pos:SV_POSITION; float4 col:COLOR; };
float4 main(PSInput i):SV_TARGET{ return i.col; }
""".trimIndent()

// GLSL for Vulkan panel (hardcoded vertices)
private val VK_VERT_SRC = """
#version 450
layout(location = 0) out vec3 fragColor;
const vec2 positions[3] = vec2[](vec2(0.0, -0.5), vec2(0.5, 0.5), vec2(-0.5, 0.5));
const vec3 colors[3]    = vec3[](vec3(1,0,0), vec3(0,1,0), vec3(0,0,1));
void main() {
    gl_Position = vec4(positions[gl_VertexIndex], 0.0, 1.0);
    fragColor = colors[gl_VertexIndex];
}
""".trimIndent()

private val VK_FRAG_SRC = """
#version 450
layout(location = 0) in vec3 fragColor;
layout(location = 0) out vec4 outColor;
void main() { outColor = vec4(fragColor, 1.0); }
""".trimIndent()

// ============================================================
// Shaderc compiler (GLSL -> SPIR-V)
// ============================================================
private fun compileShader(shadercDll: HMODULE?, source: String, kind: Int, filename: String): ByteArray {
    val compilerInit: CPointer<Fn_Void_P> = GetProcAddress(shadercDll, "shaderc_compiler_initialize")!!.reinterpret()
    val compilerRelease: CPointer<Fn_ShP_Void> = GetProcAddress(shadercDll, "shaderc_compiler_release")!!.reinterpret()
    val optsInit: CPointer<Fn_Void_P> = GetProcAddress(shadercDll, "shaderc_compile_options_initialize")!!.reinterpret()
    val optsRelease: CPointer<Fn_ShP_Void> = GetProcAddress(shadercDll, "shaderc_compile_options_release")!!.reinterpret()
    val optsSetOpt: CPointer<Fn_PInt_V> = GetProcAddress(shadercDll, "shaderc_compile_options_set_optimization_level")!!.reinterpret()
    val compile: CPointer<Fn_Compile> = GetProcAddress(shadercDll, "shaderc_compile_into_spv")!!.reinterpret()
    val resRelease: CPointer<Fn_ShP_Void> = GetProcAddress(shadercDll, "shaderc_result_release")!!.reinterpret()
    val resLen: CPointer<Fn_P_SizeT> = GetProcAddress(shadercDll, "shaderc_result_get_length")!!.reinterpret()
    val resBytes: CPointer<Fn_P_OPtr> = GetProcAddress(shadercDll, "shaderc_result_get_bytes")!!.reinterpret()
    val resStatus: CPointer<Fn_P_IntSh> = GetProcAddress(shadercDll, "shaderc_result_get_compilation_status")!!.reinterpret()
    val resErr: CPointer<Fn_P_OPtr> = GetProcAddress(shadercDll, "shaderc_result_get_error_message")!!.reinterpret()

    val compiler = compilerInit() ?: throw RuntimeException("shaderc_compiler_initialize failed")
    val opts = optsInit() ?: throw RuntimeException("shaderc_compile_options_initialize failed")
    optsSetOpt(opts, 2)

    val srcBytes = source.encodeToByteArray()
    val pSrc = heapZalloc(srcBytes.size)
    for (i in srcBytes.indices) pSrc[i] = srcBytes[i]
    val pFile = heapCstr(filename)
    val pEntry = heapCstr("main")

    val res = compile(compiler, pSrc, srcBytes.size.toLong(), kind, pFile, pEntry, opts)
        ?: throw RuntimeException("shaderc_compile_into_spv returned NULL")

    val st = resStatus(res)
    if (st != 0) {
        val errPtr = resErr(res)
        val errMsg = errPtr?.reinterpret<ByteVar>()?.toKString() ?: "(no message)"
        resRelease(res); optsRelease(opts); compilerRelease(compiler)
        throw RuntimeException("shaderc compile failed ($st): $errMsg")
    }

    val len = resLen(res).toInt()
    val bp = resBytes(res)!!.reinterpret<ByteVar>()
    val spv = ByteArray(len) { bp[it] }
    resRelease(res); optsRelease(opts); compilerRelease(compiler)
    return spv
}

// ============================================================
// Window
// ============================================================
private const val CLASS_NAME = "KotlinDCompTriangle"
private const val PANEL_W = 320
private const val PANEL_H = 480
private const val WINDOW_W = PANEL_W * 3
private var shouldQuit = false

private fun wndProc(hWnd: HWND?, uMsg: UINT, wParam: WPARAM, lParam: LPARAM): LRESULT {
    return when (uMsg.toInt()) {
        WM_CLOSE, WM_DESTROY -> { PostQuitMessage(0); shouldQuit = true; 0L }
        else -> DefWindowProcW(hWnd, uMsg, wParam, lParam)
    }
}

// ============================================================
// Typed COM call helpers (via vtable slot)
//
// Naming convention:
//   comCall_<slot>(obj, args...) -> Int (HRESULT)
// ============================================================

// Generic: (this) -> HRESULT
private fun comCall0(obj: COpaquePointer?, s: Int): Int {
    val fn = slot(obj, s)!!.reinterpret<CFunction<(COpaquePointer?) -> Int>>()
    return fn(obj)
}

// (this, ptr) -> HRESULT
private fun comCallP(obj: COpaquePointer?, s: Int, a: COpaquePointer?): Int {
    val fn = slot(obj, s)!!.reinterpret<CFunction<(COpaquePointer?, COpaquePointer?) -> Int>>()
    return fn(obj, a)
}

// (this, ptr, ptr, ptr) -> HRESULT
private fun comCallPPP(obj: COpaquePointer?, s: Int,
                       a: COpaquePointer?, b: COpaquePointer?, c: COpaquePointer?): Int {
    val fn = slot(obj, s)!!.reinterpret<CFunction<(COpaquePointer?, COpaquePointer?, COpaquePointer?, COpaquePointer?) -> Int>>()
    return fn(obj, a, b, c)
}

// (this, UInt, ptr, ptr) -> HRESULT
private fun comCallUPP(obj: COpaquePointer?, s: Int,
                       a: UInt, b: COpaquePointer?, c: COpaquePointer?): Int {
    val fn = slot(obj, s)!!.reinterpret<CFunction<(COpaquePointer?, UInt, COpaquePointer?, COpaquePointer?) -> Int>>()
    return fn(obj, a, b, c)
}

// (this, uint, ptr) -> void
private fun comCallUP_V(obj: COpaquePointer?, s: Int, a: UInt, b: COpaquePointer?) {
    val fn = slot(obj, s)!!.reinterpret<CFunction<(COpaquePointer?, UInt, COpaquePointer?) -> Unit>>()
    fn(obj, a, b)
}

// (this, ptr, ptr) -> void
private fun comCallPP_V(obj: COpaquePointer?, s: Int, a: COpaquePointer?, b: COpaquePointer?) {
    val fn = slot(obj, s)!!.reinterpret<CFunction<(COpaquePointer?, COpaquePointer?, COpaquePointer?) -> Unit>>()
    fn(obj, a, b)
}

// ============================================================
// Main program
// ============================================================
fun main() {
    debugPrint("=== OpenGL + D3D11 + Vulkan via DirectComposition (Kotlin/Native) ===")

    // ---- Load DLLs ----
    val d3d11Dll = LoadLibraryW("d3d11.dll") ?: throw RuntimeException("Cannot load d3d11.dll")
    val dxgiDll = LoadLibraryW("dxgi.dll") ?: throw RuntimeException("Cannot load dxgi.dll")
    val d3dcDll = LoadLibraryW("d3dcompiler_47.dll") ?: throw RuntimeException("Cannot load d3dcompiler_47.dll")
    val dcompDll = LoadLibraryW("dcomp.dll") ?: throw RuntimeException("Cannot load dcomp.dll")
    val gl32Dll = LoadLibraryW("opengl32.dll") ?: throw RuntimeException("Cannot load opengl32.dll")
    val vkDll = LoadLibraryW("vulkan-1.dll") ?: throw RuntimeException("Cannot load vulkan-1.dll")
    val shadercDll = LoadLibraryW("shaderc_shared.dll")
        ?: run {
            val sdk = platform.posix.getenv("VULKAN_SDK")?.toKString()
            if (sdk != null) LoadLibraryW("$sdk\\Bin\\shaderc_shared.dll") else null
        }
        ?: throw RuntimeException("Cannot load shaderc_shared.dll")
    debugPrint("[INIT] All DLLs loaded")

    // ---- Load D3D11 / DXGI / DComp entry points ----
    val pfnD3D11CreateDevice: CPointer<CFunction<(
        COpaquePointer?, Int, COpaquePointer?, UInt,
        COpaquePointer?, UInt, UInt,
        COpaquePointer?, COpaquePointer?, COpaquePointer?) -> Int>> = loadDll(d3d11Dll, "D3D11CreateDevice")

    val pfnD3DCompile: CPointer<CFunction<(
        COpaquePointer?, Long, COpaquePointer?, COpaquePointer?, COpaquePointer?,
        COpaquePointer?, COpaquePointer?, UInt, UInt,
        COpaquePointer?, COpaquePointer?) -> Int>> = loadDll(d3dcDll, "D3DCompile")

    val pfnDCompCreateDevice: CPointer<CFunction<(
        COpaquePointer?, COpaquePointer?, COpaquePointer?) -> Int>> = loadDll(dcompDll, "DCompositionCreateDevice")

    // ---- Load Vulkan base ----
    vkGetInstanceProcAddr = loadDll(vkDll, "vkGetInstanceProcAddr")
    val vkCreateInstance: CPointer<Fn_PPP_I> = loadDll(vkDll, "vkCreateInstance")
    val vkEnumPhysDevices: CPointer<Fn_PPP_I> = loadDll(vkDll, "vkEnumeratePhysicalDevices")
    val vkGetQueueFamilyProps: CPointer<Fn_PPP_V> = loadDll(vkDll, "vkGetPhysicalDeviceQueueFamilyProperties")
    val vkCreateDevice: CPointer<Fn_PPPP_I> = loadDll(vkDll, "vkCreateDevice")

    // ---- Compile Vulkan shaders ----
    val vkVertSpv = compileShader(shadercDll, VK_VERT_SRC, 0, "hello.vert")
    val vkFragSpv = compileShader(shadercDll, VK_FRAG_SRC, 1, "hello.frag")
    debugPrint("[INIT] Vulkan shaders compiled: vert ${vkVertSpv.size}B, frag ${vkFragSpv.size}B")

    // ---- Create window ----
    memScoped {
        val hInstance = GetModuleHandleW(null)
        val wcex = alloc<WNDCLASSEXW>().apply {
            cbSize = sizeOf<WNDCLASSEXW>().toUInt()
            style = (CS_HREDRAW or CS_VREDRAW).toUInt()
            lpfnWndProc = staticCFunction(::wndProc)
            this.hInstance = hInstance
            hCursor = LoadCursorW(null, IDC_ARROW)
            hbrBackground = null
            lpszClassName = CLASS_NAME.wcstr.ptr
        }
        if (RegisterClassExW(wcex.ptr) == 0.toUShort())
            throw RuntimeException("RegisterClassExW failed")

        val style = WS_OVERLAPPEDWINDOW.toInt()
        val rc = alloc<RECT>().apply {
            left = 0; top = 0; right = WINDOW_W; bottom = PANEL_H
        }
        AdjustWindowRect(rc.ptr, style.toUInt(), 0)

        // WS_EX_NOREDIRECTIONBITMAP = 0x00200000
        val hWnd = CreateWindowExW(
            0x00200000u, CLASS_NAME,
            "OpenGL + D3D11 + Vulkan via DirectComposition (Kotlin/Native)",
            style.toUInt(),
            CW_USEDEFAULT, CW_USEDEFAULT,
            rc.right - rc.left, rc.bottom - rc.top,
            null, null, hInstance, null
        ) ?: throw RuntimeException("CreateWindowExW failed")
        ShowWindow(hWnd, SW_SHOWDEFAULT)
        UpdateWindow(hWnd)
        debugPrint("[INIT] Window created (${WINDOW_W}x${PANEL_H})")

        // ============================================================
        // 1. Create D3D11 device
        // ============================================================
        val featureLevelIn = alloc<IntVar>().apply { value = D3D_FEATURE_LEVEL_11_0 }
        val featureLevelOut = alloc<IntVar>()
        val deviceOut = alloc<COpaquePointerVar>()
        val ctxOut = alloc<COpaquePointerVar>()

        var hr = pfnD3D11CreateDevice(
            null, D3D_DRIVER_TYPE_HARDWARE, null, D3D11_CREATE_DEVICE_BGRA_SUPPORT,
            featureLevelIn.ptr.reinterpret(), 1u, D3D11_SDK_VERSION,
            deviceOut.ptr.reinterpret(), featureLevelOut.ptr.reinterpret(), ctxOut.ptr.reinterpret()
        )
        if (hr < 0) throw RuntimeException("D3D11CreateDevice failed: 0x${hr.toUInt().toString(16)}")
        val d3dDevice = deviceOut.value!!
        val d3dCtx = ctxOut.value!!
        debugPrint("[INIT] D3D11 device created")

        // ============================================================
        // Helper: Create SwapChain for Composition on the shared D3D device
        // ============================================================
        fun createSwapChainForComposition(): COpaquePointer {
            val dxgiDevOut = alloc<COpaquePointerVar>()
            hr = comQI(d3dDevice, IID_IDXGIDevice, dxgiDevOut.ptr.reinterpret())
            if (hr < 0) throw RuntimeException("QI(IDXGIDevice) failed: 0x${hr.toUInt().toString(16)}")
            val dxgiDev = dxgiDevOut.value!!

            val adapterOut = alloc<COpaquePointerVar>()
            // IDXGIDevice::GetAdapter = slot 7
            val fnGetAdapter = slot(dxgiDev, DXGIDEV_GetAdapter)!!
                .reinterpret<CFunction<(COpaquePointer?, COpaquePointer?) -> Int>>()
            hr = fnGetAdapter(dxgiDev, adapterOut.ptr.reinterpret())
            comRelease(dxgiDev)
            if (hr < 0) throw RuntimeException("GetAdapter failed: 0x${hr.toUInt().toString(16)}")
            val adapter = adapterOut.value!!

            val factoryOut = alloc<COpaquePointerVar>()
            hr = comQI(adapter, IID_IDXGIFactory2, factoryOut.ptr.reinterpret())
            if (hr < 0) {
                // Fallback: GetParent
                val fnGetParent = slot(adapter, DXGIOBJ_GetParent)!!
                    .reinterpret<CFunction<(COpaquePointer?, COpaquePointer?, COpaquePointer?) -> Int>>()
                hr = fnGetParent(adapter, IID_IDXGIFactory2, factoryOut.ptr.reinterpret())
            }
            comRelease(adapter)
            if (hr < 0) throw RuntimeException("GetParent(IDXGIFactory2) failed: 0x${hr.toUInt().toString(16)}")
            val factory = factoryOut.value!!

            // DXGI_SWAP_CHAIN_DESC1 (48 bytes on x64)
            val desc = zalloc(48)
            desc.w32(0, PANEL_W.toUInt())        // Width
            desc.w32(4, PANEL_H.toUInt())        // Height
            desc.w32(8, DXGI_FORMAT_B8G8R8A8_UNORM_D3D) // Format
            desc.w32(16, 1u)                     // SampleDesc.Count
            desc.w32(24, DXGI_USAGE_RENDER_TARGET_OUTPUT) // BufferUsage
            desc.w32(28, 2u)                     // BufferCount
            desc.w32(32, DXGI_SCALING_STRETCH)   // Scaling
            desc.w32(36, DXGI_SWAP_EFFECT_FLIP_SEQUENTIAL) // SwapEffect
            desc.w32(40, DXGI_ALPHA_MODE_PREMULTIPLIED)    // AlphaMode

            val scOut = alloc<COpaquePointerVar>()
            // IDXGIFactory2::CreateSwapChainForComposition = slot 24
            // (this, pDevice, pDesc, pRestrictToOutput, ppSwapChain) -> HRESULT
            val fnCreate = slot(factory, DXGIFACT2_CreateSwapChainForComposition)!!
                .reinterpret<CFunction<(COpaquePointer?, COpaquePointer?, COpaquePointer?, COpaquePointer?, COpaquePointer?) -> Int>>()
            hr = fnCreate(factory, d3dDevice, desc, null, scOut.ptr.reinterpret())
            comRelease(factory)
            if (hr < 0) throw RuntimeException("CreateSwapChainForComposition failed: 0x${hr.toUInt().toString(16)}")
            return scOut.value!!
        }

        // Helper: get back buffer RTV from a SwapChain
        fun createRTV(sc: COpaquePointer): COpaquePointer {
            val bbOut = alloc<COpaquePointerVar>()
            // IDXGISwapChain::GetBuffer = slot 9
            val fnGetBuf = slot(sc, DXGISC_GetBuffer)!!
                .reinterpret<CFunction<(COpaquePointer?, UInt, COpaquePointer?, COpaquePointer?) -> Int>>()
            hr = fnGetBuf(sc, 0u, IID_ID3D11Texture2D, bbOut.ptr.reinterpret())
            if (hr < 0) throw RuntimeException("GetBuffer failed: 0x${hr.toUInt().toString(16)}")
            val bb = bbOut.value!!

            val rtvOut = alloc<COpaquePointerVar>()
            // ID3D11Device::CreateRenderTargetView = slot 9
            val fnRTV = slot(d3dDevice, D3D11DEV_CreateRenderTargetView)!!
                .reinterpret<CFunction<(COpaquePointer?, COpaquePointer?, COpaquePointer?, COpaquePointer?) -> Int>>()
            hr = fnRTV(d3dDevice, bb, null, rtvOut.ptr.reinterpret())
            if (hr < 0) { comRelease(bb); throw RuntimeException("CreateRTV failed") }

            comRelease(bb)
            return rtvOut.value!!
        }

        // Helper: Present a SwapChain
        fun presentSC(sc: COpaquePointer) {
            val fnPresent = slot(sc, DXGISC_Present)!!
                .reinterpret<CFunction<(COpaquePointer?, UInt, UInt) -> Int>>()
            fnPresent(sc, 1u, 0u)
        }

        // Helper: compile HLSL shader
        fun compileHLSL(src: String, entry: String, target: String): COpaquePointer {
            val srcBytes = src.encodeToByteArray()
            val pSrc = heapZalloc(srcBytes.size)
            for (i in srcBytes.indices) pSrc[i] = srcBytes[i]
            val pEntry = heapCstr(entry)
            val pTarget = heapCstr(target)
            val blobOut = alloc<COpaquePointerVar>()
            val errOut = alloc<COpaquePointerVar>()

            hr = pfnD3DCompile(
                pSrc, srcBytes.size.toLong(), null, null, null,
                pEntry, pTarget, D3DCOMPILE_ENABLE_STRICTNESS, 0u,
                blobOut.ptr.reinterpret(), errOut.ptr.reinterpret()
            )
            if (errOut.value != null) comRelease(errOut.value)
            if (hr < 0) throw RuntimeException("D3DCompile($target) failed: 0x${hr.toUInt().toString(16)}")
            return blobOut.value!!
        }

        // Helper: blob -> pointer,size
        fun blobPtr(blob: COpaquePointer): COpaquePointer {
            val fn = slot(blob, BLOB_GetBufferPointer)!!.reinterpret<CFunction<(COpaquePointer?) -> COpaquePointer?>>()
            return fn(blob)!!
        }
        fun blobSize(blob: COpaquePointer): Long {
            val fn = slot(blob, BLOB_GetBufferSize)!!.reinterpret<CFunction<(COpaquePointer?) -> Long>>()
            return fn(blob)
        }

        // ============================================================
        // 2. Create three SwapChains for Composition
        // ============================================================
        val glSwapChain = createSwapChainForComposition()
        val dxSwapChain = createSwapChainForComposition()
        val vkSwapChain = createSwapChainForComposition()
        debugPrint("[INIT] 3 SwapChains created for composition")

        // ============================================================
        // 3. DirectComposition setup
        // ============================================================

        // Get IDXGIDevice for DCompositionCreateDevice
        val dxgiDevForDComp = alloc<COpaquePointerVar>()
        hr = comQI(d3dDevice, IID_IDXGIDevice, dxgiDevForDComp.ptr.reinterpret())
        if (hr < 0) throw RuntimeException("QI(IDXGIDevice) for DComp failed")

        val dcompDevOut = alloc<COpaquePointerVar>()
        hr = pfnDCompCreateDevice(dxgiDevForDComp.value, IID_IDCompositionDevice, dcompDevOut.ptr.reinterpret())
        comRelease(dxgiDevForDComp.value)
        if (hr < 0) throw RuntimeException("DCompositionCreateDevice failed: 0x${hr.toUInt().toString(16)}")
        val dcompDev = dcompDevOut.value!!
        debugPrint("[INIT] IDCompositionDevice created")

        // CreateTargetForHwnd
        val targetOut = alloc<COpaquePointerVar>()
        val fnCreateTarget = slot(dcompDev, DCOMP_CreateTargetForHwnd)!!
            .reinterpret<CFunction<(COpaquePointer?, HWND?, Int, COpaquePointer?) -> Int>>()
        hr = fnCreateTarget(dcompDev, hWnd, 1, targetOut.ptr.reinterpret())
        if (hr < 0) throw RuntimeException("CreateTargetForHwnd failed: 0x${hr.toUInt().toString(16)}")
        val dcompTarget = targetOut.value!!

        // Create root visual
        val fnCreateVisual = slot(dcompDev, DCOMP_CreateVisual)!!
            .reinterpret<CFunction<(COpaquePointer?, COpaquePointer?) -> Int>>()
        val rootVisOut = alloc<COpaquePointerVar>()
        hr = fnCreateVisual(dcompDev, rootVisOut.ptr.reinterpret())
        if (hr < 0) throw RuntimeException("CreateVisual(root) failed")
        val rootVisual = rootVisOut.value!!

        // SetRoot
        val fnSetRoot = slot(dcompTarget, DCTARGET_SetRoot)!!
            .reinterpret<CFunction<(COpaquePointer?, COpaquePointer?) -> Int>>()
        hr = fnSetRoot(dcompTarget, rootVisual)
        if (hr < 0) throw RuntimeException("SetRoot failed")

        // Helper: add a swapchain as a child visual at offsetX
        fun addSwapChainVisual(sc: COpaquePointer, offsetX: Float): COpaquePointer {
            val visOut = alloc<COpaquePointerVar>()
            hr = fnCreateVisual(dcompDev, visOut.ptr.reinterpret())
            if (hr < 0) throw RuntimeException("CreateVisual failed")
            val vis = visOut.value!!

            // SetOffsetX(float)
            val fnSetOX = slot(vis, DCVISUAL_SetOffsetX_Float)!!
                .reinterpret<CFunction<(COpaquePointer?, Float) -> Int>>()
            fnSetOX(vis, offsetX)

            // SetOffsetY(float)
            val fnSetOY = slot(vis, DCVISUAL_SetOffsetY_Float)!!
                .reinterpret<CFunction<(COpaquePointer?, Float) -> Int>>()
            fnSetOY(vis, 0.0f)

            // SetContent(IUnknown* = swapchain)
            val fnSetContent = slot(vis, DCVISUAL_SetContent)!!
                .reinterpret<CFunction<(COpaquePointer?, COpaquePointer?) -> Int>>()
            hr = fnSetContent(vis, sc)
            if (hr < 0) throw RuntimeException("SetContent failed: 0x${hr.toUInt().toString(16)}")

            // AddVisual(child, insertAbove=TRUE, referenceVisual=NULL)
            val fnAddVis = slot(rootVisual, DCVISUAL_AddVisual)!!
                .reinterpret<CFunction<(COpaquePointer?, COpaquePointer?, Int, COpaquePointer?) -> Int>>()
            hr = fnAddVis(rootVisual, vis, 1, null)
            if (hr < 0) throw RuntimeException("AddVisual failed: 0x${hr.toUInt().toString(16)}")
            return vis
        }

        val glVisual = addSwapChainVisual(glSwapChain, 0.0f)
        val dxVisual = addSwapChainVisual(dxSwapChain, PANEL_W.toFloat())
        val vkVisualDComp = addSwapChainVisual(vkSwapChain, (PANEL_W * 2).toFloat())
        debugPrint("[INIT] DirectComposition visual tree built")

        // ============================================================
        // 4. OpenGL panel setup (WGL_NV_DX_interop)
        // ============================================================
        val glHDC = GetDC(hWnd)!!

        // Set up pixel format
        val pfd = alloc<PIXELFORMATDESCRIPTOR>().apply {
            nSize = sizeOf<PIXELFORMATDESCRIPTOR>().toUShort()
            nVersion = 1u
            dwFlags = (PFD_DRAW_TO_WINDOW or PFD_SUPPORT_OPENGL or PFD_DOUBLEBUFFER).toUInt()
            iPixelType = PFD_TYPE_RGBA.toUByte()
            cColorBits = 32u
            cDepthBits = 24u
            iLayerType = PFD_MAIN_PLANE.toUByte()
        }
        val pf = ChoosePixelFormat(glHDC, pfd.ptr)
        if (pf == 0) throw RuntimeException("ChoosePixelFormat failed")
        SetPixelFormat(glHDC, pf, pfd.ptr)

        // Create legacy context, then upgrade to 4.6 core
        val legacyRC = wglCreateContext(glHDC) ?: throw RuntimeException("wglCreateContext failed")
        wglMakeCurrent(glHDC, legacyRC)

        // Load wglCreateContextAttribsARB
        val pfnWglGetProcAddress: CPointer<CFunction<(COpaquePointer?) -> COpaquePointer?>> =
            loadDll(gl32Dll, "wglGetProcAddress")

        fun getGLProc(name: String): COpaquePointer? {
            val p = pfnWglGetProcAddress(heapCstr(name))
            if (p != null && p.asLong() > 3L && p.asLong() != -1L) return p
            return GetProcAddress(gl32Dll, name)
        }

        val pfnCreateCtxAttribs = getGLProc("wglCreateContextAttribsARB")
        val glRC: HGLRC?
        if (pfnCreateCtxAttribs != null) {
            val attrs = allocArray<IntVar>(9)
            attrs[0] = WGL_CONTEXT_MAJOR_VERSION_ARB; attrs[1] = 4
            attrs[2] = WGL_CONTEXT_MINOR_VERSION_ARB; attrs[3] = 6
            attrs[4] = WGL_CONTEXT_FLAGS_ARB; attrs[5] = 0
            attrs[6] = WGL_CONTEXT_PROFILE_MASK_ARB; attrs[7] = WGL_CONTEXT_CORE_PROFILE_BIT_ARB
            attrs[8] = 0
            val fn = pfnCreateCtxAttribs.reinterpret<CFunction<(COpaquePointer?, COpaquePointer?, COpaquePointer?) -> COpaquePointer?>>()
            val newRC = fn(glHDC, null, attrs)
            if (newRC != null) {
                wglMakeCurrent(glHDC, newRC?.reinterpret())
                wglDeleteContext(legacyRC)
                glRC = newRC.reinterpret()
            } else {
                glRC = legacyRC
            }
        } else {
            glRC = legacyRC
        }
        debugPrint("[INIT] OpenGL context created")

        // Load GL extension functions
        fun loadGL(name: String): COpaquePointer = getGLProc(name)
            ?: throw RuntimeException("GL: $name not found")

        val glGenBuffers = loadGL("glGenBuffers").reinterpret<CFunction<(Int, COpaquePointer?) -> Unit>>()
        val glBindBuffer = loadGL("glBindBuffer").reinterpret<CFunction<(UInt, UInt) -> Unit>>()
        val glBufferData = loadGL("glBufferData").reinterpret<CFunction<(UInt, Long, COpaquePointer?, UInt) -> Unit>>()
        val glCreateShader = loadGL("glCreateShader").reinterpret<CFunction<(UInt) -> UInt>>()
        val glShaderSource = loadGL("glShaderSource").reinterpret<CFunction<(UInt, Int, COpaquePointer?, COpaquePointer?) -> Unit>>()
        val glCompileShader = loadGL("glCompileShader").reinterpret<CFunction<(UInt) -> Unit>>()
        val glGetShaderiv = loadGL("glGetShaderiv").reinterpret<CFunction<(UInt, UInt, COpaquePointer?) -> Unit>>()
        val glCreateProgram = loadGL("glCreateProgram").reinterpret<CFunction<() -> UInt>>()
        val glAttachShader = loadGL("glAttachShader").reinterpret<CFunction<(UInt, UInt) -> Unit>>()
        val glLinkProgram = loadGL("glLinkProgram").reinterpret<CFunction<(UInt) -> Unit>>()
        val glGetProgramiv = loadGL("glGetProgramiv").reinterpret<CFunction<(UInt, UInt, COpaquePointer?) -> Unit>>()
        val glUseProgram = loadGL("glUseProgram").reinterpret<CFunction<(UInt) -> Unit>>()
        val glGetAttribLocation = loadGL("glGetAttribLocation").reinterpret<CFunction<(UInt, COpaquePointer?) -> Int>>()
        val glEnableVertexAttribArray = loadGL("glEnableVertexAttribArray").reinterpret<CFunction<(UInt) -> Unit>>()
        val glVertexAttribPointer = loadGL("glVertexAttribPointer").reinterpret<CFunction<(UInt, Int, UInt, Int, Int, COpaquePointer?) -> Unit>>()
        val glGenVertexArrays = loadGL("glGenVertexArrays").reinterpret<CFunction<(Int, COpaquePointer?) -> Unit>>()
        val glBindVertexArray = loadGL("glBindVertexArray").reinterpret<CFunction<(UInt) -> Unit>>()
        val glGenFramebuffers = loadGL("glGenFramebuffers").reinterpret<CFunction<(Int, COpaquePointer?) -> Unit>>()
        val glBindFramebuffer = loadGL("glBindFramebuffer").reinterpret<CFunction<(UInt, UInt) -> Unit>>()
        val glFramebufferRenderbuffer = loadGL("glFramebufferRenderbuffer").reinterpret<CFunction<(UInt, UInt, UInt, UInt) -> Unit>>()
        val glCheckFramebufferStatus = loadGL("glCheckFramebufferStatus").reinterpret<CFunction<(UInt) -> UInt>>()
        val glGenRenderbuffers = loadGL("glGenRenderbuffers").reinterpret<CFunction<(Int, COpaquePointer?) -> Unit>>()
        val glBindRenderbuffer = loadGL("glBindRenderbuffer").reinterpret<CFunction<(UInt, UInt) -> Unit>>()

        // WGL_NV_DX_interop
        val wglDXOpenDeviceNV = loadGL("wglDXOpenDeviceNV")
            .reinterpret<CFunction<(COpaquePointer?) -> COpaquePointer?>>()
        val wglDXCloseDeviceNV = loadGL("wglDXCloseDeviceNV")
            .reinterpret<CFunction<(COpaquePointer?) -> Int>>()
        val wglDXRegisterObjectNV = loadGL("wglDXRegisterObjectNV")
            .reinterpret<CFunction<(COpaquePointer?, COpaquePointer?, UInt, UInt, UInt) -> COpaquePointer?>>()
        val wglDXUnregisterObjectNV = loadGL("wglDXUnregisterObjectNV")
            .reinterpret<CFunction<(COpaquePointer?, COpaquePointer?) -> Int>>()
        val wglDXLockObjectsNV = loadGL("wglDXLockObjectsNV")
            .reinterpret<CFunction<(COpaquePointer?, Int, COpaquePointer?) -> Int>>()
        val wglDXUnlockObjectsNV = loadGL("wglDXUnlockObjectsNV")
            .reinterpret<CFunction<(COpaquePointer?, Int, COpaquePointer?) -> Int>>()

        // Basic GL functions (from opengl32.dll directly)
        val glViewport: CPointer<CFunction<(Int, Int, Int, Int) -> Unit>> = loadDll(gl32Dll, "glViewport")
        val glClearColor: CPointer<CFunction<(Float, Float, Float, Float) -> Unit>> = loadDll(gl32Dll, "glClearColor")
        val glClear: CPointer<CFunction<(UInt) -> Unit>> = loadDll(gl32Dll, "glClear")
        val glDrawArrays: CPointer<CFunction<(UInt, Int, Int) -> Unit>> = loadDll(gl32Dll, "glDrawArrays")
        val glFlush: CPointer<CFunction<() -> Unit>> = loadDll(gl32Dll, "glFlush")

        // Open NV_DX_interop device
        val glInteropDev = wglDXOpenDeviceNV(d3dDevice) ?: throw RuntimeException("wglDXOpenDeviceNV failed")
        debugPrint("[INIT] WGL_NV_DX_interop device opened")

        // Get GL SwapChain back buffer for interop
        val glBBOut = alloc<COpaquePointerVar>()
        val fnGetBuf = slot(glSwapChain, DXGISC_GetBuffer)!!
            .reinterpret<CFunction<(COpaquePointer?, UInt, COpaquePointer?, COpaquePointer?) -> Int>>()
        hr = fnGetBuf(glSwapChain, 0u, IID_ID3D11Texture2D, glBBOut.ptr.reinterpret())
        if (hr < 0) throw RuntimeException("GL SwapChain GetBuffer failed")
        val glBackBuffer = glBBOut.value!!

        // Register renderbuffer with NV interop
        val rboId = alloc<UIntVar>()
        glGenRenderbuffers(1, rboId.ptr.reinterpret())
        glBindRenderbuffer(GL_RENDERBUFFER, rboId.value)
        val glInteropObj = wglDXRegisterObjectNV(
            glInteropDev, glBackBuffer, rboId.value, GL_RENDERBUFFER, WGL_ACCESS_READ_WRITE_NV.toUInt()
        ) ?: throw RuntimeException("wglDXRegisterObjectNV failed")

        // Create FBO
        val fboId = alloc<UIntVar>()
        glGenFramebuffers(1, fboId.ptr.reinterpret())
        glBindFramebuffer(GL_FRAMEBUFFER, fboId.value)
        glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, rboId.value)
        val fboStatus = glCheckFramebufferStatus(GL_FRAMEBUFFER)
        glBindFramebuffer(GL_FRAMEBUFFER, 0u)
        if (fboStatus != GL_FRAMEBUFFER_COMPLETE)
            throw RuntimeException("FBO incomplete: 0x${fboStatus.toString(16)}")

        // Create VAO + VBOs for triangle
        val vaoId = alloc<UIntVar>()
        glGenVertexArrays(1, vaoId.ptr.reinterpret())
        glBindVertexArray(vaoId.value)

        val glVboIds = allocArray<UIntVar>(2)
        glGenBuffers(2, glVboIds.reinterpret())

        // Position data
        val posData = allocArray<FloatVar>(9)
        posData[0] = -0.5f; posData[1] = -0.5f; posData[2] = 0.0f
        posData[3] =  0.5f; posData[4] = -0.5f; posData[5] = 0.0f
        posData[6] =  0.0f; posData[7] =  0.5f; posData[8] = 0.0f

        // Color data (blue-green-red for OpenGL panel)
        val colData = allocArray<FloatVar>(9)
        colData[0] = 0.0f; colData[1] = 0.0f; colData[2] = 1.0f
        colData[3] = 0.0f; colData[4] = 1.0f; colData[5] = 0.0f
        colData[6] = 1.0f; colData[7] = 0.0f; colData[8] = 0.0f

        glBindBuffer(GL_ARRAY_BUFFER, glVboIds[0])
        glBufferData(GL_ARRAY_BUFFER, 36L, posData, GL_STATIC_DRAW)
        glBindBuffer(GL_ARRAY_BUFFER, glVboIds[1])
        glBufferData(GL_ARRAY_BUFFER, 36L, colData, GL_STATIC_DRAW)

        // Compile GL shaders
        fun compileGLShader(type: UInt, src: String): UInt {
            val shader = glCreateShader(type)
            val pSrc = heapCstr(src)
            val pArr = alloc<COpaquePointerVar>(); pArr.value = pSrc
            glShaderSource(shader, 1, pArr.ptr.reinterpret(), null)
            glCompileShader(shader)
            val ok = alloc<IntVar>()
            glGetShaderiv(shader, GL_COMPILE_STATUS, ok.ptr.reinterpret())
            if (ok.value == 0) throw RuntimeException("GL shader compile failed (type=0x${type.toString(16)})")
            return shader
        }

        val glVS = compileGLShader(GL_VERTEX_SHADER, GL_VERT_SRC)
        val glPS = compileGLShader(GL_FRAGMENT_SHADER, GL_FRAG_SRC)
        val glProgram = glCreateProgram()
        glAttachShader(glProgram, glVS)
        glAttachShader(glProgram, glPS)
        glLinkProgram(glProgram)
        val linkOk = alloc<IntVar>()
        glGetProgramiv(glProgram, GL_LINK_STATUS, linkOk.ptr.reinterpret())
        if (linkOk.value == 0) throw RuntimeException("GL program link failed")

        glUseProgram(glProgram)
        val posAttrib = glGetAttribLocation(glProgram, heapCstr("position"))
        val colAttrib = glGetAttribLocation(glProgram, heapCstr("color"))
        if (posAttrib < 0 || colAttrib < 0) throw RuntimeException("GL attrib lookup failed")
        glEnableVertexAttribArray(posAttrib.toUInt())
        glEnableVertexAttribArray(colAttrib.toUInt())
        debugPrint("[INIT] OpenGL panel ready")

        // ============================================================
        // 5. D3D11 panel setup (compile HLSL, create vertex buffer)
        // ============================================================
        val dxRtv = createRTV(dxSwapChain)

        val vsBlob = compileHLSL(D3D_VS_HLSL, "main", "vs_4_0")
        val psBlob = compileHLSL(D3D_PS_HLSL, "main", "ps_4_0")

        // CreateVertexShader
        val dxVSOut = alloc<COpaquePointerVar>()
        val fnCreateVS = slot(d3dDevice, D3D11DEV_CreateVertexShader)!!
            .reinterpret<CFunction<(COpaquePointer?, COpaquePointer?, Long, COpaquePointer?, COpaquePointer?) -> Int>>()
        hr = fnCreateVS(d3dDevice, blobPtr(vsBlob), blobSize(vsBlob), null, dxVSOut.ptr.reinterpret())
        if (hr < 0) throw RuntimeException("CreateVertexShader failed")
        val dxVS = dxVSOut.value!!

        // CreatePixelShader
        val dxPSOut = alloc<COpaquePointerVar>()
        val fnCreatePS = slot(d3dDevice, D3D11DEV_CreatePixelShader)!!
            .reinterpret<CFunction<(COpaquePointer?, COpaquePointer?, Long, COpaquePointer?, COpaquePointer?) -> Int>>()
        hr = fnCreatePS(d3dDevice, blobPtr(psBlob), blobSize(psBlob), null, dxPSOut.ptr.reinterpret())
        if (hr < 0) throw RuntimeException("CreatePixelShader failed")
        val dxPS = dxPSOut.value!!

        // Input layout: POSITION(R32G32B32_FLOAT) + COLOR(R32G32B32A32_FLOAT)
        // D3D11_INPUT_ELEMENT_DESC = 32 bytes each on x64
        val layoutDesc = zalloc(64)
        val semPos = heapCstr("POSITION"); val semCol = heapCstr("COLOR")
        // Element 0: POSITION
        layoutDesc.wP(0, semPos)        // SemanticName
        layoutDesc.w32(8, 0u)           // SemanticIndex
        layoutDesc.w32(12, DXGI_FORMAT_R32G32B32_FLOAT)  // Format
        layoutDesc.w32(16, 0u)          // InputSlot
        layoutDesc.w32(20, 0u)          // AlignedByteOffset
        layoutDesc.w32(24, D3D11_INPUT_PER_VERTEX_DATA)
        layoutDesc.w32(28, 0u)          // InstanceDataStepRate
        // Element 1: COLOR
        layoutDesc.wP(32, semCol)
        layoutDesc.w32(40, 0u)
        layoutDesc.w32(44, DXGI_FORMAT_R32G32B32A32_FLOAT)
        layoutDesc.w32(48, 0u)
        layoutDesc.w32(52, 12u)         // AlignedByteOffset = sizeof(float3)
        layoutDesc.w32(56, D3D11_INPUT_PER_VERTEX_DATA)
        layoutDesc.w32(60, 0u)

        val ilOut = alloc<COpaquePointerVar>()
        val fnCreateIL = slot(d3dDevice, D3D11DEV_CreateInputLayout)!!
            .reinterpret<CFunction<(COpaquePointer?, COpaquePointer?, UInt, COpaquePointer?, Long, COpaquePointer?) -> Int>>()
        hr = fnCreateIL(d3dDevice, layoutDesc, 2u, blobPtr(vsBlob), blobSize(vsBlob), ilOut.ptr.reinterpret())
        comRelease(vsBlob); comRelease(psBlob)
        if (hr < 0) throw RuntimeException("CreateInputLayout failed")
        val dxInputLayout = ilOut.value!!

        // Vertex buffer: 3 vertices ÁE(float3 pos + float4 color) = 3 ÁE28 bytes = 84 bytes
        val dxVerts = heapZalloc(84)
        // Vertex 0: pos(0, 0.5, 0.5) col(1,0,0,1)
        dxVerts.wF(0, 0.0f); dxVerts.wF(4, 0.5f); dxVerts.wF(8, 0.5f)
        dxVerts.wF(12, 1.0f); dxVerts.wF(16, 0.0f); dxVerts.wF(20, 0.0f); dxVerts.wF(24, 1.0f)
        // Vertex 1: pos(0.5, -0.5, 0.5) col(0,1,0,1)
        dxVerts.wF(28, 0.5f); dxVerts.wF(32, -0.5f); dxVerts.wF(36, 0.5f)
        dxVerts.wF(40, 0.0f); dxVerts.wF(44, 1.0f); dxVerts.wF(48, 0.0f); dxVerts.wF(52, 1.0f)
        // Vertex 2: pos(-0.5, -0.5, 0.5) col(0,0,1,1)
        dxVerts.wF(56, -0.5f); dxVerts.wF(60, -0.5f); dxVerts.wF(64, 0.5f)
        dxVerts.wF(68, 0.0f); dxVerts.wF(72, 0.0f); dxVerts.wF(76, 1.0f); dxVerts.wF(80, 1.0f)

        // D3D11_BUFFER_DESC (24 bytes)
        val bd = zalloc(24)
        bd.w32(0, 84u)                   // ByteWidth
        bd.w32(4, D3D11_USAGE_DEFAULT)   // Usage
        bd.w32(8, D3D11_BIND_VERTEX_BUFFER) // BindFlags

        // D3D11_SUBRESOURCE_DATA (16 bytes on x64)
        val initData = zalloc(16)
        initData.wP(0, dxVerts)          // pSysMem

        val vbOut = alloc<COpaquePointerVar>()
        val fnCreateBuf = slot(d3dDevice, D3D11DEV_CreateBuffer)!!
            .reinterpret<CFunction<(COpaquePointer?, COpaquePointer?, COpaquePointer?, COpaquePointer?) -> Int>>()
        hr = fnCreateBuf(d3dDevice, bd, initData, vbOut.ptr.reinterpret())
        if (hr < 0) throw RuntimeException("CreateBuffer(VB) failed")
        val dxVB = vbOut.value!!
        debugPrint("[INIT] D3D11 panel ready")

        // ============================================================
        // 6. Vulkan panel setup (offscreen -> readback -> D3D11)
        // ============================================================

        // D3D11 resources for Vulkan panel
        val vkBBOut = alloc<COpaquePointerVar>()
        hr = fnGetBuf(vkSwapChain, 0u, IID_ID3D11Texture2D, vkBBOut.ptr.reinterpret())
        if (hr < 0) throw RuntimeException("VK SwapChain GetBuffer failed")
        val vkBackBuffer = vkBBOut.value!!

        // Staging texture for CPU write
        // D3D11_TEXTURE2D_DESC (44 bytes)
        val texDesc = zalloc(48)
        texDesc.w32(0, PANEL_W.toUInt())    // Width
        texDesc.w32(4, PANEL_H.toUInt())    // Height
        texDesc.w32(8, 1u)                  // MipLevels
        texDesc.w32(12, 1u)                 // ArraySize
        texDesc.w32(16, DXGI_FORMAT_B8G8R8A8_UNORM_D3D) // Format
        texDesc.w32(20, 1u)                 // SampleDesc.Count
        texDesc.w32(28, D3D11_USAGE_STAGING) // Usage
        texDesc.w32(36, D3D11_CPU_ACCESS_WRITE) // CPUAccessFlags

        val stgOut = alloc<COpaquePointerVar>()
        val fnCreateTex2D = slot(d3dDevice, D3D11DEV_CreateTexture2D)!!
            .reinterpret<CFunction<(COpaquePointer?, COpaquePointer?, COpaquePointer?, COpaquePointer?) -> Int>>()
        hr = fnCreateTex2D(d3dDevice, texDesc, null, stgOut.ptr.reinterpret())
        if (hr < 0) throw RuntimeException("CreateTexture2D(staging) failed")
        val vkStagingTex = stgOut.value!!

        // Vulkan initialization
        val pAppName = heapCstr("KotlinDCompTriangleVk")
        val appInfo = zalloc(48)
        appInfo.w32(0, VK_STYPE_APP_INFO); appInfo.wP(16, pAppName)
        appInfo.w32(44, vkVersion(1, 4, 0))

        val ici = zalloc(64)
        ici.w32(0, VK_STYPE_INSTANCE_CI); ici.wP(24, appInfo)

        val instOut = alloc<LongVar>()
        vkCheck(vkCreateInstance(ici, null, instOut.ptr.reinterpret()), "vkCreateInstance")
        val vkInst = instOut.value.asPtr()
        debugPrint("[INIT] Vulkan instance created")

        vkDestroyInstance = loadVkInst(vkInst, "vkDestroyInstance")
        vkGetDeviceProcAddr = loadVkInst(vkInst, "vkGetDeviceProcAddr")

        // Physical device
        val devCount = alloc<UIntVar>()
        vkCheck(vkEnumPhysDevices(vkInst, devCount.ptr.reinterpret(), null), "vkEnumPhysDevices")
        if (devCount.value == 0u) throw RuntimeException("No Vulkan physical devices")
        val devList = allocArray<LongVar>(devCount.value.toInt())
        vkCheck(vkEnumPhysDevices(vkInst, devCount.ptr.reinterpret(), devList.reinterpret()), "vkEnumPhysDevices")
        val physDev = devList[0].asPtr()

        // Find graphics queue family
        val qCount = alloc<UIntVar>()
        vkGetQueueFamilyProps(physDev, qCount.ptr.reinterpret(), null)
        val qProps = allocArray<ByteVar>(qCount.value.toInt() * 24)
        vkGetQueueFamilyProps(physDev, qCount.ptr.reinterpret(), qProps)

        var vkGfxQ = -1
        for (i in 0 until qCount.value.toInt()) {
            val flags = qProps.r32(i * 24)
            if ((flags and VK_QUEUE_GRAPHICS_BIT) != 0u) { vkGfxQ = i; break }
        }
        if (vkGfxQ < 0) throw RuntimeException("No Vulkan graphics queue")

        // Create device
        val prio = heapZalloc(4); prio.wF(0, 1.0f)
        val dqci = zalloc(40)
        dqci.w32(0, VK_STYPE_DEVICE_QUEUE_CI)
        dqci.w32(20, vkGfxQ.toUInt()); dqci.w32(24, 1u); dqci.wP(32, prio)

        val dci = zalloc(72)
        dci.w32(0, VK_STYPE_DEVICE_CI)
        dci.w32(20, 1u); dci.wP(24, dqci)

        val vkDevOut = alloc<LongVar>()
        vkCheck(vkCreateDevice(physDev, dci, null, vkDevOut.ptr.reinterpret()), "vkCreateDevice")
        val vkDevice = vkDevOut.value.asPtr()
        debugPrint("[INIT] Vulkan device created")

        // Load all device-level functions
        vkDestroyDevice = loadVkDev(vkDevice, "vkDestroyDevice")
        vkGetDeviceQueue = loadVkDev(vkDevice, "vkGetDeviceQueue")
        vkCreateImageView = loadVkDev(vkDevice, "vkCreateImageView")
        vkDestroyImageView = loadVkDev(vkDevice, "vkDestroyImageView")
        vkCreateShaderModule = loadVkDev(vkDevice, "vkCreateShaderModule")
        vkDestroyShaderModule = loadVkDev(vkDevice, "vkDestroyShaderModule")
        vkCreateRenderPass = loadVkDev(vkDevice, "vkCreateRenderPass")
        vkDestroyRenderPass = loadVkDev(vkDevice, "vkDestroyRenderPass")
        vkCreatePipelineLayout = loadVkDev(vkDevice, "vkCreatePipelineLayout")
        vkDestroyPipelineLayout = loadVkDev(vkDevice, "vkDestroyPipelineLayout")
        vkCreateGraphicsPipelines = loadVkDev(vkDevice, "vkCreateGraphicsPipelines")
        vkDestroyPipeline = loadVkDev(vkDevice, "vkDestroyPipeline")
        vkCreateFramebuffer = loadVkDev(vkDevice, "vkCreateFramebuffer")
        vkDestroyFramebuffer = loadVkDev(vkDevice, "vkDestroyFramebuffer")
        vkCreateCommandPool = loadVkDev(vkDevice, "vkCreateCommandPool")
        vkDestroyCommandPool = loadVkDev(vkDevice, "vkDestroyCommandPool")
        vkAllocateCommandBuffers = loadVkDev(vkDevice, "vkAllocateCommandBuffers")
        vkBeginCommandBuffer = loadVkDev(vkDevice, "vkBeginCommandBuffer")
        vkEndCommandBuffer = loadVkDev(vkDevice, "vkEndCommandBuffer")
        vkCmdBeginRenderPass = loadVkDev(vkDevice, "vkCmdBeginRenderPass")
        vkCmdEndRenderPass = loadVkDev(vkDevice, "vkCmdEndRenderPass")
        vkCmdBindPipeline = loadVkDev(vkDevice, "vkCmdBindPipeline")
        vkCmdDraw = loadVkDev(vkDevice, "vkCmdDraw")
        vkCreateFence = loadVkDev(vkDevice, "vkCreateFence")
        vkDestroyFence = loadVkDev(vkDevice, "vkDestroyFence")
        vkWaitForFences = loadVkDev(vkDevice, "vkWaitForFences")
        vkResetFences = loadVkDev(vkDevice, "vkResetFences")
        vkQueueSubmit = loadVkDev(vkDevice, "vkQueueSubmit")
        vkDeviceWaitIdle = loadVkDev(vkDevice, "vkDeviceWaitIdle")
        vkCreateImage = loadVkDev(vkDevice, "vkCreateImage")
        vkDestroyImage = loadVkDev(vkDevice, "vkDestroyImage")
        vkGetImageMemoryRequirements = loadVkDev(vkDevice, "vkGetImageMemoryRequirements")
        vkAllocateMemory = loadVkDev(vkDevice, "vkAllocateMemory")
        vkFreeMemory = loadVkDev(vkDevice, "vkFreeMemory")
        vkBindImageMemory = loadVkDev(vkDevice, "vkBindImageMemory")
        vkCreateBuffer = loadVkDev(vkDevice, "vkCreateBuffer")
        vkDestroyBuffer = loadVkDev(vkDevice, "vkDestroyBuffer")
        vkGetBufferMemoryRequirements = loadVkDev(vkDevice, "vkGetBufferMemoryRequirements")
        vkBindBufferMemory = loadVkDev(vkDevice, "vkBindBufferMemory")
        vkMapMemory = loadVkDev(vkDevice, "vkMapMemory")
        vkUnmapMemory = loadVkDev(vkDevice, "vkUnmapMemory")
        vkCmdCopyImageToBuffer = loadVkDev(vkDevice, "vkCmdCopyImageToBuffer")
        vkGetPhysicalDeviceMemoryProperties = loadVkInst(vkInst, "vkGetPhysicalDeviceMemoryProperties")
        vkResetCommandBuffer = loadVkDev(vkDevice, "vkResetCommandBuffer")

        // Queue
        val qOut = alloc<LongVar>()
        vkGetDeviceQueue(vkDevice, vkGfxQ.toUInt(), 0u, qOut.ptr.reinterpret())
        val vkQueue = qOut.value.asPtr()

        // Offscreen image
        val imgci = zalloc(88) // VkImageCreateInfo
        imgci.w32(0, VK_STYPE_IMAGE_CI)
        imgci.w32(20, VK_IMAGE_TYPE_2D); imgci.w32(24, VK_FORMAT_B8G8R8A8_UNORM_VK)
        imgci.w32(28, PANEL_W.toUInt()); imgci.w32(32, PANEL_H.toUInt()); imgci.w32(36, 1u) // extent
        imgci.w32(40, 1u); imgci.w32(44, 1u) // mipLevels, arrayLayers
        imgci.w32(48, VK_SAMPLE_1) // samples
        imgci.w32(52, VK_IMAGE_TILING_OPTIMAL)
        imgci.w32(56, VK_IMAGE_USAGE_COLOR_ATT or VK_IMAGE_USAGE_TRANSFER_SRC)
        imgci.w32(60, 0u) // sharingMode = VK_SHARING_MODE_EXCLUSIVE
        imgci.w32(80, VK_IMAGE_LAYOUT_UNDEFINED) // initialLayout

        val imgOut = alloc<LongVar>()
        vkCheck(vkCreateImage(vkDevice, imgci, null, imgOut.ptr.reinterpret()), "vkCreateImage")
        val vkOffImage = imgOut.value

        // Memory for offscreen image
        val memReqs = zalloc(40) // VkMemoryRequirements (24 bytes, but allocate extra)
        vkGetImageMemoryRequirements(vkDevice, vkOffImage.asPtr(), memReqs)
        val memSize = memReqs.r64(0)  // size
        val memTypeBits = memReqs.r32(16)  // memoryTypeBits

        // Find device-local memory type
        val memProps = zalloc(520) // VkPhysicalDeviceMemoryProperties
        vkGetPhysicalDeviceMemoryProperties(physDev, memProps)
        val memTypeCount = memProps.r32(0)
        var memTypeIdx = -1
        for (i in 0 until memTypeCount.toInt()) {
            if ((memTypeBits and (1u shl i)) != 0u) {
                val propFlags = memProps.r32(4 + i * 8) // propertyFlags
                if ((propFlags and VK_MEMORY_PROPERTY_DEVICE_LOCAL) != 0u) { memTypeIdx = i; break }
            }
        }
        if (memTypeIdx < 0) throw RuntimeException("No device-local memory type")

        val allocInfo = zalloc(32) // VkMemoryAllocateInfo
        allocInfo.w32(0, VK_STYPE_MEM_ALLOC_INFO)
        allocInfo.w64(16, memSize); allocInfo.w32(24, memTypeIdx.toUInt())

        val memOut = alloc<LongVar>()
        vkCheck(vkAllocateMemory(vkDevice, allocInfo, null, memOut.ptr.reinterpret()), "vkAllocateMemory(img)")
        val vkOffMem = memOut.value
        vkCheck(vkBindImageMemory(vkDevice, vkOffImage, vkOffMem, 0L), "vkBindImageMemory")

        // Image view
        val ivci = zalloc(80)
        ivci.w32(0, VK_STYPE_IMAGE_VIEW_CI)
        ivci.w64(24, vkOffImage); ivci.w32(32, VK_IMAGE_VIEW_TYPE_2D); ivci.w32(36, VK_FORMAT_B8G8R8A8_UNORM_VK)
        ivci.w32(56, VK_IMAGE_ASPECT_COLOR); ivci.w32(64, 1u); ivci.w32(72, 1u)

        val viewOut = alloc<LongVar>()
        vkCheck(vkCreateImageView(vkDevice, ivci, null, viewOut.ptr.reinterpret()), "vkCreateImageView")
        val vkOffView = viewOut.value

        // Readback buffer (host-visible)
        val bufSize = PANEL_W.toLong() * PANEL_H.toLong() * 4
        val bci = zalloc(56) // VkBufferCreateInfo (x64)
        bci.w32(0, VK_STYPE_BUFFER_CI)
        bci.w64(24, bufSize); bci.w32(32, VK_BUFFER_USAGE_TRANSFER_DST); bci.w32(36, 0u) // sharingMode = VK_SHARING_MODE_EXCLUSIVE

        val bufOut = alloc<LongVar>()
        vkCheck(vkCreateBuffer(vkDevice, bci, null, bufOut.ptr.reinterpret()), "vkCreateBuffer")
        val vkReadbackBuf = bufOut.value

        val bufMemReqs = zalloc(40)
        vkGetBufferMemoryRequirements(vkDevice, vkReadbackBuf.asPtr(), bufMemReqs)
        val bufMemSize = bufMemReqs.r64(0)
        val bufMemTypeBits = bufMemReqs.r32(16)

        // Find host-visible memory
        var bufMemTypeIdx = -1
        for (i in 0 until memTypeCount.toInt()) {
            if ((bufMemTypeBits and (1u shl i)) != 0u) {
                val propFlags = memProps.r32(4 + i * 8)
                if ((propFlags and (VK_MEMORY_PROPERTY_HOST_VISIBLE or VK_MEMORY_PROPERTY_HOST_COHERENT))
                    == (VK_MEMORY_PROPERTY_HOST_VISIBLE or VK_MEMORY_PROPERTY_HOST_COHERENT)
                ) { bufMemTypeIdx = i; break }
            }
        }
        if (bufMemTypeIdx < 0) throw RuntimeException("No host-visible memory type")

        val bufAllocInfo = zalloc(32)
        bufAllocInfo.w32(0, VK_STYPE_MEM_ALLOC_INFO)
        bufAllocInfo.w64(16, bufMemSize); bufAllocInfo.w32(24, bufMemTypeIdx.toUInt())

        val bufMemOut = alloc<LongVar>()
        vkCheck(vkAllocateMemory(vkDevice, bufAllocInfo, null, bufMemOut.ptr.reinterpret()), "vkAllocateMemory(buf)")
        val vkReadbackMem = bufMemOut.value
        vkCheck(vkBindBufferMemory(vkDevice, vkReadbackBuf, vkReadbackMem, 0L), "vkBindBufferMemory")

        // Render pass (finalLayout = TRANSFER_SRC_OPTIMAL for readback)
        val attach = zalloc(36)
        attach.w32(4, VK_FORMAT_B8G8R8A8_UNORM_VK); attach.w32(8, VK_SAMPLE_1)
        attach.w32(12, VK_LOAD_OP_CLEAR); attach.w32(16, VK_STORE_OP_STORE)
        attach.w32(20, VK_LOAD_OP_DONT_CARE); attach.w32(24, VK_STORE_OP_DONT_CARE)
        attach.w32(28, VK_IMAGE_LAYOUT_UNDEFINED); attach.w32(32, VK_IMAGE_LAYOUT_TRANSFER_SRC)

        val aref = zalloc(8)
        aref.w32(0, 0u); aref.w32(4, VK_IMAGE_LAYOUT_COLOR_ATT)

        val subpass = zalloc(72)
        subpass.w32(4, VK_BIND_POINT_GRAPHICS); subpass.w32(24, 1u); subpass.wP(32, aref)

        val rpci = zalloc(64)
        rpci.w32(0, VK_STYPE_RENDER_PASS_CI)
        rpci.w32(20, 1u); rpci.wP(24, attach); rpci.w32(32, 1u); rpci.wP(40, subpass)

        val rpOut = alloc<LongVar>()
        vkCheck(vkCreateRenderPass(vkDevice, rpci, null, rpOut.ptr.reinterpret()), "vkCreateRenderPass")
        val vkRenderPass = rpOut.value

        // Framebuffer
        val pAttach = zalloc(8); pAttach.w64(0, vkOffView)
        val fbci = zalloc(64)
        fbci.w32(0, VK_STYPE_FRAMEBUFFER_CI)
        fbci.w64(24, vkRenderPass); fbci.w32(32, 1u); fbci.wP(40, pAttach)
        fbci.w32(48, PANEL_W.toUInt()); fbci.w32(52, PANEL_H.toUInt()); fbci.w32(56, 1u)

        val fbOut = alloc<LongVar>()
        vkCheck(vkCreateFramebuffer(vkDevice, fbci, null, fbOut.ptr.reinterpret()), "vkCreateFramebuffer")
        val vkFramebuffer = fbOut.value

        // Shader modules
        fun vkShaderModule(spv: ByteArray): Long {
            val pCode = heapZalloc(spv.size)
            for (i in spv.indices) pCode[i] = spv[i]
            val smci = zalloc(40)
            smci.w32(0, VK_STYPE_SHADER_MODULE_CI)
            smci.w64(24, spv.size.toLong()); smci.wP(32, pCode)
            val out = alloc<LongVar>()
            vkCheck(vkCreateShaderModule(vkDevice, smci, null, out.ptr.reinterpret()), "vkCreateShaderModule")
            return out.value
        }
        val vkVertMod = vkShaderModule(vkVertSpv)
        val vkFragMod = vkShaderModule(vkFragSpv)

        // Pipeline layout (empty)
        val plci = zalloc(48); plci.w32(0, VK_STYPE_PIPE_LAYOUT_CI)
        val plOut = alloc<LongVar>()
        vkCheck(vkCreatePipelineLayout(vkDevice, plci, null, plOut.ptr.reinterpret()), "vkCreatePipelineLayout")
        val vkPipelineLayout = plOut.value

        // Graphics pipeline
        val pEntry = heapCstr("main")
        val stages = zalloc(96)
        stages.w32(0, VK_STYPE_PIPE_SHADER_STAGE_CI)
        stages.w32(20, VK_STAGE_VERTEX); stages.w64(24, vkVertMod); stages.wP(32, pEntry)
        stages.w32(48, VK_STYPE_PIPE_SHADER_STAGE_CI)
        stages.w32(68, VK_STAGE_FRAGMENT); stages.w64(72, vkFragMod); stages.wP(80, pEntry)

        val vi = zalloc(48); vi.w32(0, VK_STYPE_PIPE_VERTEX_INPUT_CI)
        val ia = zalloc(32); ia.w32(0, VK_STYPE_PIPE_INPUT_ASM_CI); ia.w32(20, VK_TOPO_TRIANGLE_LIST)
        val viewport = zalloc(24)
        viewport.wF(8, PANEL_W.toFloat()); viewport.wF(12, PANEL_H.toFloat()); viewport.wF(20, 1f)
        val scissor = zalloc(16)
        scissor.w32(8, PANEL_W.toUInt()); scissor.w32(12, PANEL_H.toUInt())
        val vps = zalloc(48); vps.w32(0, VK_STYPE_PIPE_VIEWPORT_CI)
        vps.w32(20, 1u); vps.wP(24, viewport); vps.w32(32, 1u); vps.wP(40, scissor)
        val rast = zalloc(64); rast.w32(0, VK_STYPE_PIPE_RASTERIZATION_CI)
        rast.w32(28, VK_POLYGON_FILL); rast.w32(32, VK_CULL_NONE)
        rast.w32(36, VK_FRONT_CW); rast.wF(56, 1.0f)
        val ms = zalloc(48); ms.w32(0, VK_STYPE_PIPE_MULTISAMPLE_CI); ms.w32(20, VK_SAMPLE_1)
        val cba = zalloc(32); cba.w32(28, VK_COLOR_RGBA)
        val cb = zalloc(56); cb.w32(0, VK_STYPE_PIPE_COLOR_BLEND_CI); cb.w32(28, 1u); cb.wP(32, cba)

        val gpci = zalloc(144); gpci.w32(0, VK_STYPE_GRAPHICS_PIPE_CI)
        gpci.w32(20, 2u); gpci.wP(24, stages)
        gpci.wP(32, vi); gpci.wP(40, ia); gpci.wP(56, vps); gpci.wP(64, rast)
        gpci.wP(72, ms); gpci.wP(88, cb)
        gpci.w64(104, vkPipelineLayout); gpci.w64(112, vkRenderPass)
        gpci.w32(136, (-1))

        val pipeOut = alloc<LongVar>()
        vkCheck(vkCreateGraphicsPipelines(vkDevice, 0L, 1u, gpci, null, pipeOut.ptr.reinterpret()), "vkCreateGraphicsPipelines")
        val vkPipeline = pipeOut.value
        debugPrint("[INIT] Vulkan pipeline created")

        // Command pool + buffer
        val cpci = zalloc(24); cpci.w32(0, VK_STYPE_CMD_POOL_CI)
        cpci.w32(16, VK_CMD_POOL_RESET_CMD_BIT); cpci.w32(20, vkGfxQ.toUInt())
        val cpOut = alloc<LongVar>()
        vkCheck(vkCreateCommandPool(vkDevice, cpci, null, cpOut.ptr.reinterpret()), "vkCreateCommandPool")
        val vkCmdPool = cpOut.value

        val cbai = zalloc(32); cbai.w32(0, VK_STYPE_CMD_BUF_ALLOC_INFO)
        cbai.w64(16, vkCmdPool); cbai.w32(24, VK_CMD_BUF_LEVEL_PRIMARY); cbai.w32(28, 1u)
        val cmdBufOut = alloc<LongVar>()
        vkCheck(vkAllocateCommandBuffers(vkDevice, cbai, cmdBufOut.ptr.reinterpret()), "vkAllocateCommandBuffers")
        val vkCmdBuf = cmdBufOut.value

        // Fence
        val fci = zalloc(24); fci.w32(0, VK_STYPE_FENCE_CI); fci.w32(16, VK_FENCE_SIGNALED)
        val fOut = alloc<LongVar>()
        vkCheck(vkCreateFence(vkDevice, fci, null, fOut.ptr.reinterpret()), "vkCreateFence")
        val vkFence = fOut.value
        debugPrint("[INIT] Vulkan panel ready")

        // ============================================================
        // Commit DirectComposition
        // ============================================================
        val fnCommit = slot(dcompDev, DCOMP_Commit)!!.reinterpret<CFunction<(COpaquePointer?) -> Int>>()
        hr = fnCommit(dcompDev)
        if (hr < 0) throw RuntimeException("DComp Commit failed: 0x${hr.toUInt().toString(16)}")
        debugPrint("[INIT] DirectComposition committed")

        // ============================================================
        // Render loop
        // ============================================================
        debugPrint("[RENDER] Starting main loop. Close window to exit.")
        val msg = alloc<MSG>()

        // D3D11 context function pointers (pre-resolve for render loop)
        val fnCtxClear = slot(d3dCtx, D3D11CTX_ClearRenderTargetView)!!
            .reinterpret<CFunction<(COpaquePointer?, COpaquePointer?, COpaquePointer?) -> Unit>>()
        val fnCtxOMSetRT = slot(d3dCtx, D3D11CTX_OMSetRenderTargets)!!
            .reinterpret<CFunction<(COpaquePointer?, UInt, COpaquePointer?, COpaquePointer?) -> Unit>>()
        val fnCtxVP = slot(d3dCtx, D3D11CTX_RSSetViewports)!!
            .reinterpret<CFunction<(COpaquePointer?, UInt, COpaquePointer?) -> Unit>>()
        val fnCtxSetIL = slot(d3dCtx, D3D11CTX_IASetInputLayout)!!
            .reinterpret<CFunction<(COpaquePointer?, COpaquePointer?) -> Unit>>()
        val fnCtxSetVB = slot(d3dCtx, D3D11CTX_IASetVertexBuffers)!!
            .reinterpret<CFunction<(COpaquePointer?, UInt, UInt, COpaquePointer?, COpaquePointer?, COpaquePointer?) -> Unit>>()
        val fnCtxSetTopo = slot(d3dCtx, D3D11CTX_IASetPrimitiveTopology)!!
            .reinterpret<CFunction<(COpaquePointer?, UInt) -> Unit>>()
        val fnCtxVSSet = slot(d3dCtx, D3D11CTX_VSSetShader)!!
            .reinterpret<CFunction<(COpaquePointer?, COpaquePointer?, COpaquePointer?, UInt) -> Unit>>()
        val fnCtxPSSet = slot(d3dCtx, D3D11CTX_PSSetShader)!!
            .reinterpret<CFunction<(COpaquePointer?, COpaquePointer?, COpaquePointer?, UInt) -> Unit>>()
        val fnCtxDraw = slot(d3dCtx, D3D11CTX_Draw)!!
            .reinterpret<CFunction<(COpaquePointer?, UInt, UInt) -> Unit>>()
        val fnCtxMap = slot(d3dCtx, D3D11CTX_Map)!!
            .reinterpret<CFunction<(COpaquePointer?, COpaquePointer?, UInt, UInt, UInt, COpaquePointer?) -> Int>>()
        val fnCtxUnmap = slot(d3dCtx, D3D11CTX_Unmap)!!
            .reinterpret<CFunction<(COpaquePointer?, COpaquePointer?, UInt) -> Unit>>()
        val fnCtxCopyRes = slot(d3dCtx, D3D11CTX_CopyResource)!!
            .reinterpret<CFunction<(COpaquePointer?, COpaquePointer?, COpaquePointer?) -> Unit>>()

        var frameNo = 0
        val vkLogEvery = 120
        while (!shouldQuit) {
            frameNo++
            val vkLogThisFrame = (frameNo % vkLogEvery) == 1
            while (PeekMessageW(msg.ptr, null, 0u, 0u, PM_REMOVE.toUInt()) != 0) {
                if (msg.message.toInt() == WM_QUIT) { shouldQuit = true; break }
                TranslateMessage(msg.ptr); DispatchMessageW(msg.ptr)
            }
            if (shouldQuit) break

            // ---- Render OpenGL panel ----
            wglMakeCurrent(glHDC, glRC)
            val objArr = alloc<COpaquePointerVar>(); objArr.value = glInteropObj
            if (wglDXLockObjectsNV(glInteropDev, 1, objArr.ptr.reinterpret()) != 0) {
                glBindFramebuffer(GL_FRAMEBUFFER, fboId.value)
                glViewport(0, 0, PANEL_W, PANEL_H)
                glClearColor(0.05f, 0.05f, 0.15f, 1.0f)
                glClear(GL_COLOR_BUFFER_BIT)

                glUseProgram(glProgram)
                glBindBuffer(GL_ARRAY_BUFFER, glVboIds[0])
                glVertexAttribPointer(posAttrib.toUInt(), 3, GL_FLOAT, GL_FALSE, 0, null)
                glBindBuffer(GL_ARRAY_BUFFER, glVboIds[1])
                glVertexAttribPointer(colAttrib.toUInt(), 3, GL_FLOAT, GL_FALSE, 0, null)
                glDrawArrays(GL_TRIANGLES, 0, 3)
                glFlush()
                glBindFramebuffer(GL_FRAMEBUFFER, 0u)
                wglDXUnlockObjectsNV(glInteropDev, 1, objArr.ptr.reinterpret())
            }
            presentSC(glSwapChain)

            // ---- Render D3D11 panel ----
            val d3dVP = zalloc(24) // D3D11_VIEWPORT
            d3dVP.wF(8, PANEL_W.toFloat()); d3dVP.wF(12, PANEL_H.toFloat()); d3dVP.wF(20, 1.0f)
            fnCtxVP(d3dCtx, 1u, d3dVP)

            val rtvArr = alloc<COpaquePointerVar>(); rtvArr.value = dxRtv
            fnCtxOMSetRT(d3dCtx, 1u, rtvArr.ptr.reinterpret(), null)
            val clearColor = allocArray<FloatVar>(4)
            clearColor[0] = 0.05f; clearColor[1] = 0.15f; clearColor[2] = 0.05f; clearColor[3] = 1.0f
            fnCtxClear(d3dCtx, dxRtv, clearColor.reinterpret())

            val stride = alloc<UIntVar>(); stride.value = 28u // sizeof(float3 + float4)
            val offset = alloc<UIntVar>(); offset.value = 0u
            val vbArr = alloc<COpaquePointerVar>(); vbArr.value = dxVB
            fnCtxSetIL(d3dCtx, dxInputLayout)
            fnCtxSetVB(d3dCtx, 0u, 1u, vbArr.ptr.reinterpret(), stride.ptr.reinterpret(), offset.ptr.reinterpret())
            fnCtxSetTopo(d3dCtx, D3D_PRIMITIVE_TOPOLOGY_TRIANGLELIST)
            fnCtxVSSet(d3dCtx, dxVS, null, 0u)
            fnCtxPSSet(d3dCtx, dxPS, null, 0u)
            fnCtxDraw(d3dCtx, 3u, 0u)
            presentSC(dxSwapChain)

            // ---- Render Vulkan panel ----
            if (vkLogThisFrame) debugPrint("[VK][RenderVulkan] frame=$frameNo begin")
            val vkFenceArr = alloc<LongVar>(); vkFenceArr.value = vkFence
            var vkRes = vkWaitForFences(vkDevice, 1u, vkFenceArr.ptr.reinterpret(), 1u, 1_000_000_000L)
            if (vkLogThisFrame) debugPrint("[VK][RenderVulkan] vkWaitForFences(before)=$vkRes")
            vkCheck(vkRes, "vkWaitForFences(before)")
            vkRes = vkResetFences(vkDevice, 1u, vkFenceArr.ptr.reinterpret())
            if (vkLogThisFrame) debugPrint("[VK][RenderVulkan] vkResetFences=$vkRes")
            vkCheck(vkRes, "vkResetFences")
            vkRes = vkResetCommandBuffer(vkCmdBuf.asPtr(), 0u)
            if (vkLogThisFrame) debugPrint("[VK][RenderVulkan] vkResetCommandBuffer=$vkRes")
            vkCheck(vkRes, "vkResetCommandBuffer")

            val bi = zalloc(32); bi.w32(0, VK_STYPE_CMD_BUF_BEGIN_INFO)
            vkRes = vkBeginCommandBuffer(vkCmdBuf.asPtr(), bi)
            if (vkLogThisFrame) debugPrint("[VK][RenderVulkan] vkBeginCommandBuffer=$vkRes")
            vkCheck(vkRes, "vkBeginCommandBuffer")

            val clearVal = zalloc(16)
            clearVal.wF(0, 0.15f); clearVal.wF(4, 0.05f); clearVal.wF(8, 0.05f); clearVal.wF(12, 1.0f)
            val rpbi = zalloc(64); rpbi.w32(0, VK_STYPE_RENDER_PASS_BEGIN_INFO)
            rpbi.w64(16, vkRenderPass); rpbi.w64(24, vkFramebuffer)
            rpbi.w32(40, PANEL_W.toUInt()); rpbi.w32(44, PANEL_H.toUInt())
            rpbi.w32(48, 1u); rpbi.wP(56, clearVal)

            vkCmdBeginRenderPass(vkCmdBuf.asPtr(), rpbi, VK_SUBPASS_INLINE)
            vkCmdBindPipeline(vkCmdBuf.asPtr(), VK_BIND_POINT_GRAPHICS, vkPipeline)
            vkCmdDraw(vkCmdBuf.asPtr(), 3u, 1u, 0u, 0u)
            vkCmdEndRenderPass(vkCmdBuf.asPtr())
            if (vkLogThisFrame) debugPrint("[VK][RenderVulkan] renderpass+draw recorded")

            // Copy image to readback buffer
            // VkBufferImageCopy (x64):
            //   0:  bufferOffset (u64)
            //   8:  bufferRowLength (u32)
            //  12:  bufferImageHeight (u32)
            //  16:  imageSubresource.aspectMask (u32)
            //  20:  imageSubresource.mipLevel (u32)
            //  24:  imageSubresource.baseArrayLayer (u32)
            //  28:  imageSubresource.layerCount (u32)
            //  32:  imageOffset.x (i32)
            //  36:  imageOffset.y (i32)
            //  40:  imageOffset.z (i32)
            //  44:  imageExtent.width (u32)
            //  48:  imageExtent.height (u32)
            //  52:  imageExtent.depth (u32)
            val region = zalloc(56) // VkBufferImageCopy
            region.w32(8, 0u)   // bufferRowLength (tightly packed)
            region.w32(12, 0u)  // bufferImageHeight (tightly packed)
            region.w32(16, VK_IMAGE_ASPECT_COLOR) // imageSubresource.aspectMask
            region.w32(28, 1u)  // imageSubresource.layerCount
            region.w32(44, PANEL_W.toUInt()); region.w32(48, PANEL_H.toUInt()); region.w32(52, 1u) // imageExtent

            if (vkLogThisFrame) debugPrint("[VK][RenderVulkan] vkCmdCopyImageToBuffer begin")
            vkCmdCopyImageToBuffer(vkCmdBuf.asPtr(), vkOffImage, VK_IMAGE_LAYOUT_TRANSFER_SRC, vkReadbackBuf, 1u, region)
            if (vkLogThisFrame) debugPrint("[VK][RenderVulkan] vkCmdCopyImageToBuffer end")
            vkRes = vkEndCommandBuffer(vkCmdBuf.asPtr())
            if (vkLogThisFrame) debugPrint("[VK][RenderVulkan] vkEndCommandBuffer=$vkRes")
            vkCheck(vkRes, "vkEndCommandBuffer")

            // Submit
            val cmdRef = alloc<LongVar>(); cmdRef.value = vkCmdBuf
            val submit = zalloc(72); submit.w32(0, VK_STYPE_SUBMIT_INFO.toUInt())
            submit.w32(40, 1u); submit.wP(48, cmdRef.ptr) // commandBufferCount, pCommandBuffers

            vkRes = vkQueueSubmit(vkQueue, 1u, submit, vkFence)
            if (vkLogThisFrame) debugPrint("[VK][RenderVulkan] vkQueueSubmit=$vkRes")
            vkCheck(vkRes, "vkQueueSubmit")
            vkFenceArr.value = vkFence
            vkRes = vkWaitForFences(vkDevice, 1u, vkFenceArr.ptr.reinterpret(), 1u, 1_000_000_000L)
            if (vkLogThisFrame) debugPrint("[VK][RenderVulkan] vkWaitForFences(after)=$vkRes")
            vkCheck(vkRes, "vkWaitForFences(after)")

            // Map Vulkan readback -> D3D11 staging -> copy to back buffer
            val dataOut = alloc<COpaquePointerVar>()
            val mapRes = vkMapMemory(vkDevice, vkReadbackMem, 0L, bufSize, 0u, dataOut.ptr.reinterpret())
            if (vkLogThisFrame) debugPrint("[VK][RenderVulkan] vkMapMemory=$mapRes")
            if (mapRes == VK_SUCCESS) {
                val mapped = zalloc(16) // D3D11_MAPPED_SUBRESOURCE
                val mapHr = fnCtxMap(d3dCtx, vkStagingTex, 0u, D3D11_MAP_WRITE, 0u, mapped)
                if (vkLogThisFrame) debugPrint("[VK][RenderVulkan] D3D11.Map(staging)=0x${mapHr.toUInt().toString(16)}")
                if (mapHr >= 0) {
                    val src = dataOut.value!!.reinterpret<ByteVar>()
                    val dst = mapped.rP(0)!!.reinterpret<ByteVar>()
                    val rowPitch = mapped.r32(8).toInt()
                    val pitch = PANEL_W * 4
                    if (vkLogThisFrame) {
                        val b = src[0].toInt() and 0xFF
                        val g = src[1].toInt() and 0xFF
                        val r = src[2].toInt() and 0xFF
                        val a = src[3].toInt() and 0xFF
                        debugPrint("[VK][RenderVulkan] readback firstPixel BGRA=($b,$g,$r,$a), srcPitch=$pitch, dstRowPitch=$rowPitch")
                    }
                    for (y in 0 until PANEL_H) {
                        platform.posix.memcpy(
                            (dst + y.toLong() * rowPitch)!!,
                            (src + y.toLong() * pitch)!!,
                            pitch.toLong().toULong()
                        )
                    }
                    fnCtxUnmap(d3dCtx, vkStagingTex, 0u)
                    fnCtxCopyRes(d3dCtx, vkBackBuffer, vkStagingTex)
                    if (vkLogThisFrame) debugPrint("[VK][RenderVulkan] D3D11.CopyResource(staging->backbuffer) done")
                }
                vkUnmapMemory(vkDevice, vkReadbackMem)
            }
            presentSC(vkSwapChain)
            if (vkLogThisFrame) debugPrint("[VK][RenderVulkan] present done")

            Sleep(1u)
        }

        // ============================================================
        // Cleanup
        // ============================================================
        debugPrint("[CLEANUP] Starting...")

        // Vulkan cleanup
        vkDeviceWaitIdle(vkDevice)
        vkDestroyFence(vkDevice, vkFence, null)
        vkDestroyCommandPool(vkDevice, vkCmdPool, null)
        vkDestroyPipeline(vkDevice, vkPipeline, null)
        vkDestroyPipelineLayout(vkDevice, vkPipelineLayout, null)
        vkDestroyShaderModule(vkDevice, vkFragMod, null)
        vkDestroyShaderModule(vkDevice, vkVertMod, null)
        vkDestroyFramebuffer(vkDevice, vkFramebuffer, null)
        vkDestroyRenderPass(vkDevice, vkRenderPass, null)
        vkDestroyImageView(vkDevice, vkOffView, null)
        vkDestroyImage(vkDevice, vkOffImage, null)
        vkFreeMemory(vkDevice, vkOffMem, null)
        vkDestroyBuffer(vkDevice, vkReadbackBuf, null)
        vkFreeMemory(vkDevice, vkReadbackMem, null)
        vkDestroyDevice(vkDevice, null)
        vkDestroyInstance(vkInst, null)

        // OpenGL / WGL interop cleanup
        wglDXUnregisterObjectNV(glInteropDev, glInteropObj)
        wglDXCloseDeviceNV(glInteropDev)
        wglMakeCurrent(null, null)
        wglDeleteContext(glRC)
        ReleaseDC(hWnd, glHDC)

        // DirectComposition cleanup
        comRelease(vkVisualDComp)
        comRelease(dxVisual)
        comRelease(glVisual)
        comRelease(rootVisual)
        comRelease(dcompTarget)
        comRelease(dcompDev)

        // D3D11 cleanup
        comRelease(glBackBuffer)
        comRelease(vkBackBuffer)
        comRelease(vkStagingTex)
        comRelease(dxRtv)
        comRelease(dxVB)
        comRelease(dxInputLayout)
        comRelease(dxPS)
        comRelease(dxVS)
        comRelease(glSwapChain)
        comRelease(dxSwapChain)
        comRelease(vkSwapChain)
        comRelease(d3dCtx)
        comRelease(d3dDevice)

        debugPrint("[CLEANUP] Done. === Program End ===")
    }
}





