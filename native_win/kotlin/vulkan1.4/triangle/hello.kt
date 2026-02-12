@file:OptIn(kotlinx.cinterop.ExperimentalForeignApi::class, kotlin.experimental.ExperimentalNativeApi::class)

import kotlinx.cinterop.*
import platform.windows.*

// ============================================================
// Debug
// ============================================================
private fun debugPrint(msg: String) { println(msg) }

// ============================================================
// Pointer/handle helpers
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
private fun CPointer<ByteVar>.w32(off: Int, v: UInt)  { (this + off)!!.reinterpret<UIntVar>()[0]  = v }
private fun CPointer<ByteVar>.w32(off: Int, v: Int)   { (this + off)!!.reinterpret<IntVar>()[0]   = v }
private fun CPointer<ByteVar>.w64(off: Int, v: Long)  { (this + off)!!.reinterpret<LongVar>()[0]  = v }
private fun CPointer<ByteVar>.wF(off: Int, v: Float)  { (this + off)!!.reinterpret<FloatVar>()[0] = v }
private fun CPointer<ByteVar>.wP(off: Int, p: CPointer<*>?) { w64(off, p.asLong()) }
private fun CPointer<ByteVar>.r32(off: Int): UInt  = (this + off)!!.reinterpret<UIntVar>()[0]
private fun CPointer<ByteVar>.r64(off: Int): Long  = (this + off)!!.reinterpret<LongVar>()[0]

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
// Vulkan constants
// ============================================================
private const val VK_SUCCESS = 0
private const val VK_SUBOPTIMAL_KHR = 1000001003

private const val VK_STYPE_APP_INFO                      = 0u
private const val VK_STYPE_INSTANCE_CI                   = 1u
private const val VK_STYPE_DEVICE_QUEUE_CI               = 2u
private const val VK_STYPE_DEVICE_CI                     = 3u
private const val VK_STYPE_SUBMIT_INFO                   = 4u
private const val VK_STYPE_FENCE_CI                      = 8u
private const val VK_STYPE_SEMAPHORE_CI                  = 9u
private const val VK_STYPE_IMAGE_VIEW_CI                 = 15u
private const val VK_STYPE_SHADER_MODULE_CI              = 16u
private const val VK_STYPE_PIPE_SHADER_STAGE_CI          = 18u
private const val VK_STYPE_PIPE_VERTEX_INPUT_CI          = 19u
private const val VK_STYPE_PIPE_INPUT_ASM_CI             = 20u
private const val VK_STYPE_PIPE_VIEWPORT_CI              = 22u
private const val VK_STYPE_PIPE_RASTERIZATION_CI         = 23u
private const val VK_STYPE_PIPE_MULTISAMPLE_CI           = 24u
private const val VK_STYPE_PIPE_COLOR_BLEND_CI           = 26u
private const val VK_STYPE_GRAPHICS_PIPE_CI              = 28u
private const val VK_STYPE_PIPE_LAYOUT_CI                = 30u
private const val VK_STYPE_FRAMEBUFFER_CI                = 37u
private const val VK_STYPE_RENDER_PASS_CI                = 38u
private const val VK_STYPE_CMD_POOL_CI                   = 39u
private const val VK_STYPE_CMD_BUF_ALLOC_INFO            = 40u
private const val VK_STYPE_CMD_BUF_BEGIN_INFO            = 42u
private const val VK_STYPE_RENDER_PASS_BEGIN_INFO        = 43u
private const val VK_STYPE_WIN32_SURFACE_CI              = 1000009000u
private const val VK_STYPE_SWAPCHAIN_CI                  = 1000001000u
private const val VK_STYPE_PRESENT_INFO                  = 1000001002u

private const val VK_QUEUE_GRAPHICS_BIT        = 0x1u
private const val VK_CMD_POOL_RESET_CMD_BIT    = 0x2u
private const val VK_CMD_BUF_LEVEL_PRIMARY     = 0u
private const val VK_IMAGE_ASPECT_COLOR        = 0x1u
private const val VK_IMAGE_VIEW_TYPE_2D        = 1u
private const val VK_FORMAT_B8G8R8A8_UNORM     = 44u
private const val VK_FORMAT_B8G8R8A8_SRGB      = 50u
private const val VK_COLORSPACE_SRGB_NONLINEAR = 0u
private const val VK_IMAGE_LAYOUT_UNDEFINED    = 0u
private const val VK_IMAGE_LAYOUT_PRESENT_SRC  = 1000001002u
private const val VK_IMAGE_LAYOUT_COLOR_ATT    = 2u
private const val VK_LOAD_OP_CLEAR             = 1u
private const val VK_STORE_OP_STORE            = 0u
private const val VK_LOAD_OP_DONT_CARE         = 2u
private const val VK_STORE_OP_DONT_CARE        = 1u
private const val VK_BIND_POINT_GRAPHICS       = 0u
private const val VK_TOPO_TRIANGLE_LIST        = 3u
private const val VK_POLYGON_FILL              = 0u
private const val VK_CULL_NONE                 = 0u
private const val VK_FRONT_CCW                 = 1u
private const val VK_SAMPLE_1                  = 1u
private const val VK_COLOR_RGBA                = 0xFu
private const val VK_STAGE_VERTEX              = 0x1u
private const val VK_STAGE_FRAGMENT            = 0x10u
private const val VK_PIPE_STAGE_COLOR_ATT_OUT  = 0x400u
private const val VK_USAGE_COLOR_ATT           = 0x10u
private const val VK_SHARING_EXCLUSIVE         = 0u
private const val VK_PRESENT_FIFO              = 2u
private const val VK_COMPOSITE_OPAQUE          = 0x1u
private const val VK_TRANSFORM_IDENTITY        = 0x1u
private const val VK_FENCE_SIGNALED            = 0x1u
private const val VK_SUBPASS_INLINE            = 0u

private fun vkVersion(ma: Int, mi: Int, pa: Int): UInt = ((ma shl 22) or (mi shl 12) or pa).toUInt()

private fun vkCheck(res: Int, msg: String) {
    if (res != VK_SUCCESS) throw RuntimeException("$msg failed: VkResult=$res")
}

// ============================================================
// Vulkan function pointer types
// ============================================================
// Naming: P=ptr, L=long/handle, U=uint32, I=int32 return, V=void return
private typealias Fn_PP_P  = CFunction<(COpaquePointer?, COpaquePointer?) -> COpaquePointer?>  // getProcAddr
private typealias Fn_PPP_I = CFunction<(COpaquePointer?, COpaquePointer?, COpaquePointer?) -> Int>
private typealias Fn_PPPP_I = CFunction<(COpaquePointer?, COpaquePointer?, COpaquePointer?, COpaquePointer?) -> Int>
private typealias Fn_PP_V  = CFunction<(COpaquePointer?, COpaquePointer?) -> Unit>
private typealias Fn_PLP_V = CFunction<(COpaquePointer?, Long, COpaquePointer?) -> Unit>  // destroy(dev, handle, alloc)
private typealias Fn_PPP_V = CFunction<(COpaquePointer?, COpaquePointer?, COpaquePointer?) -> Unit>
private typealias Fn_P_I   = CFunction<(COpaquePointer?) -> Int>
private typealias Fn_PUUP_V   = CFunction<(COpaquePointer?, UInt, UInt, COpaquePointer?) -> Unit>     // getDeviceQueue
private typealias Fn_PLPP_I   = CFunction<(COpaquePointer?, Long, COpaquePointer?, COpaquePointer?) -> Int>  // getSwapImgs
private typealias Fn_PLP_I    = CFunction<(COpaquePointer?, Long, COpaquePointer?) -> Int>  // getSurfaceCaps
private typealias Fn_PLPP2_I  = CFunction<(COpaquePointer?, Long, COpaquePointer?, COpaquePointer?) -> Int>  // getSurfaceFmts
private typealias Fn_PULP_I   = CFunction<(COpaquePointer?, UInt, Long, COpaquePointer?) -> Int>  // surfaceSupport
private typealias Fn_PLUPP_I  = CFunction<(COpaquePointer?, Long, UInt, COpaquePointer?, COpaquePointer?, COpaquePointer?) -> Int>  // createGraphicsPipes
private typealias Fn_PUP_U_L_I = CFunction<(COpaquePointer?, UInt, COpaquePointer?, UInt, Long) -> Int>  // waitForFences
private typealias Fn_PUP_I    = CFunction<(COpaquePointer?, UInt, COpaquePointer?) -> Int>  // resetFences
private typealias Fn_PLLLLLP_I = CFunction<(COpaquePointer?, Long, Long, Long, Long, COpaquePointer?) -> Int> // acquireNextImage
private typealias Fn_PUPL_I   = CFunction<(COpaquePointer?, UInt, COpaquePointer?, Long) -> Int>  // queueSubmit
private typealias Fn_PP_I     = CFunction<(COpaquePointer?, COpaquePointer?) -> Int>  // queuePresent, beginCB, endCB
private typealias Fn_PPU_V    = CFunction<(COpaquePointer?, COpaquePointer?, UInt) -> Unit>  // cmdBeginRP
private typealias Fn_PUL_V    = CFunction<(COpaquePointer?, UInt, Long) -> Unit>  // cmdBindPipeline
private typealias Fn_PUUUU_V  = CFunction<(COpaquePointer?, UInt, UInt, UInt, UInt) -> Unit>  // cmdDraw
private typealias Fn_P_V      = CFunction<(COpaquePointer?) -> Unit>  // cmdEndRP

// Shaderc
private typealias Fn_Void_P   = CFunction<() -> COpaquePointer?>
private typealias Fn_P_Void   = CFunction<(COpaquePointer?) -> Unit>
private typealias Fn_PInt_V   = CFunction<(COpaquePointer?, Int) -> Unit>
private typealias Fn_P_SizeT  = CFunction<(COpaquePointer?) -> Long>
private typealias Fn_P_Int    = CFunction<(COpaquePointer?) -> Int>
private typealias Fn_P_OPtr   = CFunction<(COpaquePointer?) -> COpaquePointer?>
private typealias Fn_Compile  = CFunction<(COpaquePointer?, COpaquePointer?, Long, Int, COpaquePointer?, COpaquePointer?, COpaquePointer?) -> COpaquePointer?>

// ============================================================
// Vulkan function variables (loaded dynamically)
// ============================================================
private lateinit var vkGetInstanceProcAddr: CPointer<Fn_PP_P>
private lateinit var vkGetDeviceProcAddr: CPointer<Fn_PP_P>

// Instance-level
private lateinit var vkDestroyInstance: CPointer<Fn_PP_V>
private lateinit var vkCreateWin32SurfaceKHR: CPointer<Fn_PPPP_I>
private lateinit var vkDestroySurfaceKHR: CPointer<Fn_PLP_V>
private lateinit var vkGetPhysicalDeviceSurfaceSupportKHR: CPointer<Fn_PULP_I>
private lateinit var vkGetPhysicalDeviceSurfaceCapabilitiesKHR: CPointer<Fn_PLP_I>
private lateinit var vkGetPhysicalDeviceSurfaceFormatsKHR: CPointer<Fn_PLPP2_I>

// Device-level
private lateinit var vkDestroyDevice: CPointer<Fn_PP_V>
private lateinit var vkGetDeviceQueue: CPointer<Fn_PUUP_V>
private lateinit var vkCreateSwapchainKHR: CPointer<Fn_PPPP_I>
private lateinit var vkDestroySwapchainKHR: CPointer<Fn_PLP_V>
private lateinit var vkGetSwapchainImagesKHR: CPointer<Fn_PLPP_I>
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
private lateinit var vkCreateSemaphore: CPointer<Fn_PPPP_I>
private lateinit var vkDestroySemaphore: CPointer<Fn_PLP_V>
private lateinit var vkCreateFence: CPointer<Fn_PPPP_I>
private lateinit var vkDestroyFence: CPointer<Fn_PLP_V>
private lateinit var vkWaitForFences: CPointer<Fn_PUP_U_L_I>
private lateinit var vkResetFences: CPointer<Fn_PUP_I>
private lateinit var vkAcquireNextImageKHR: CPointer<Fn_PLLLLLP_I>
private lateinit var vkQueueSubmit: CPointer<Fn_PUPL_I>
private lateinit var vkQueuePresentKHR: CPointer<Fn_PP_I>
private lateinit var vkDeviceWaitIdle: CPointer<Fn_P_I>

// ============================================================
// Function loaders
// ============================================================
private inline fun <reified T : CFunction<*>> loadVk(dll: HMODULE?, name: String): CPointer<T> {
    return (GetProcAddress(dll, name) ?: throw RuntimeException("vulkan-1.dll: $name not found")).reinterpret()
}

private inline fun <reified T : CFunction<*>> loadInst(inst: COpaquePointer?, name: String): CPointer<T> {
    val p = vkGetInstanceProcAddr(inst, heapCstr(name))
        ?: throw RuntimeException("vkGetInstanceProcAddr: $name not found")
    return p.reinterpret()
}

private inline fun <reified T : CFunction<*>> loadDev(dev: COpaquePointer?, name: String): CPointer<T> {
    val p = vkGetDeviceProcAddr(dev, heapCstr(name))
        ?: throw RuntimeException("vkGetDeviceProcAddr: $name not found")
    return p.reinterpret()
}

// ============================================================
// Shader sources (GLSL 450 – hardcoded vertices in shader)
// ============================================================
private val VERT_SRC = """
#version 450
layout(location = 0) out vec3 fragColor;
const vec2 positions[3] = vec2[](vec2(0.0, -0.5), vec2(0.5, 0.5), vec2(-0.5, 0.5));
const vec3 colors[3]    = vec3[](vec3(1,0,0), vec3(0,1,0), vec3(0,0,1));
void main() {
    gl_Position = vec4(positions[gl_VertexIndex], 0.0, 1.0);
    fragColor = colors[gl_VertexIndex];
}
""".trimIndent()

private val FRAG_SRC = """
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
    val compilerRelease: CPointer<Fn_P_Void> = GetProcAddress(shadercDll, "shaderc_compiler_release")!!.reinterpret()
    val optsInit: CPointer<Fn_Void_P> = GetProcAddress(shadercDll, "shaderc_compile_options_initialize")!!.reinterpret()
    val optsRelease: CPointer<Fn_P_Void> = GetProcAddress(shadercDll, "shaderc_compile_options_release")!!.reinterpret()
    val optsSetOpt: CPointer<Fn_PInt_V> = GetProcAddress(shadercDll, "shaderc_compile_options_set_optimization_level")!!.reinterpret()
    val compile: CPointer<Fn_Compile> = GetProcAddress(shadercDll, "shaderc_compile_into_spv")!!.reinterpret()
    val resRelease: CPointer<Fn_P_Void> = GetProcAddress(shadercDll, "shaderc_result_release")!!.reinterpret()
    val resLen: CPointer<Fn_P_SizeT> = GetProcAddress(shadercDll, "shaderc_result_get_length")!!.reinterpret()
    val resBytes: CPointer<Fn_P_OPtr> = GetProcAddress(shadercDll, "shaderc_result_get_bytes")!!.reinterpret()
    val resStatus: CPointer<Fn_P_Int> = GetProcAddress(shadercDll, "shaderc_result_get_compilation_status")!!.reinterpret()
    val resErr: CPointer<Fn_P_OPtr> = GetProcAddress(shadercDll, "shaderc_result_get_error_message")!!.reinterpret()

    val compiler = compilerInit() ?: throw RuntimeException("shaderc_compiler_initialize failed")
    val opts = optsInit() ?: throw RuntimeException("shaderc_compile_options_initialize failed")
    optsSetOpt(opts, 2) // performance optimization

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
// Win32 Window
// ============================================================
private const val CLASS_NAME = "KotlinVulkanTriangle"
private var shouldQuit = false

private fun wndProc(hWnd: HWND?, uMsg: UINT, wParam: WPARAM, lParam: LPARAM): LRESULT {
    return when (uMsg.toInt()) {
        WM_CLOSE, WM_DESTROY -> { PostQuitMessage(0); shouldQuit = true; 0L }
        else -> DefWindowProcW(hWnd, uMsg, wParam, lParam)
    }
}

// ============================================================
// Main
// ============================================================
fun main() {
    debugPrint("=== Vulkan 1.4 Triangle (Kotlin/Native) ===")

    // ---- Load shaderc ----
    val shadercDll = LoadLibraryW("shaderc_shared.dll")
        ?: run {
            val sdk = platform.posix.getenv("VULKAN_SDK")?.toKString()
            if (sdk != null) LoadLibraryW("$sdk\\Bin\\shaderc_shared.dll") else null
        }
        ?: throw RuntimeException("Cannot load shaderc_shared.dll")
    debugPrint("[INIT] shaderc loaded")

    val vertSpv = compileShader(shadercDll, VERT_SRC, 0, "hello.vert") // 0=vertex
    val fragSpv = compileShader(shadercDll, FRAG_SRC, 1, "hello.frag") // 1=fragment
    debugPrint("[INIT] Shaders compiled: vert ${vertSpv.size}B, frag ${fragSpv.size}B")

    // ---- Load vulkan-1.dll ----
    val vkDll = LoadLibraryW("vulkan-1.dll") ?: throw RuntimeException("Cannot load vulkan-1.dll")
    vkGetInstanceProcAddr = loadVk(vkDll, "vkGetInstanceProcAddr")
    val vkCreateInstance: CPointer<Fn_PPP_I> = loadVk(vkDll, "vkCreateInstance")
    val vkEnumPhysDevices: CPointer<Fn_PPP_I> = loadVk(vkDll, "vkEnumeratePhysicalDevices")
    val vkGetQueueFamilyProps: CPointer<Fn_PPP_V> = loadVk(vkDll, "vkGetPhysicalDeviceQueueFamilyProperties")
    val vkCreateDevice: CPointer<Fn_PPPP_I> = loadVk(vkDll, "vkCreateDevice")
    debugPrint("[INIT] vulkan-1.dll loaded")

    // ---- Create window ----
    memScoped {
        val hInstance = GetModuleHandleW(null)
        val wcex = alloc<WNDCLASSEXW>().apply {
            cbSize = sizeOf<WNDCLASSEXW>().toUInt()
            style = (CS_HREDRAW or CS_VREDRAW).toUInt()
            lpfnWndProc = staticCFunction(::wndProc)
            this.hInstance = hInstance
            hCursor = LoadCursorW(null, IDC_ARROW)
            lpszClassName = CLASS_NAME.wcstr.ptr
        }
        if (RegisterClassExW(wcex.ptr) == 0.toUShort())
            throw RuntimeException("RegisterClassExW failed")

        val hWnd = CreateWindowExW(0u, CLASS_NAME, "Vulkan 1.4 Triangle (Kotlin/Native)",
            WS_OVERLAPPEDWINDOW.toUInt(), CW_USEDEFAULT, CW_USEDEFAULT, 800, 600,
            null, null, hInstance, null
        ) ?: throw RuntimeException("CreateWindowExW failed")
        ShowWindow(hWnd, SW_SHOWDEFAULT)
        UpdateWindow(hWnd)
        debugPrint("[INIT] Window created")

        // Get client size
        val rc = alloc<RECT>()
        GetClientRect(hWnd, rc.ptr)
        var curW = (rc.right - rc.left).coerceAtLeast(1)
        var curH = (rc.bottom - rc.top).coerceAtLeast(1)

        // ============================================================
        // Vulkan initialization
        // ============================================================

        // --- Instance ---
        val pAppName = heapCstr("KotlinVulkanTriangle")
        val pEngine = heapCstr("none")
        val appInfo = zalloc(48)
        appInfo.w32(0, VK_STYPE_APP_INFO); appInfo.wP(16, pAppName)
        appInfo.w32(24, 1u); appInfo.wP(32, pEngine); appInfo.w32(40, 1u)
        appInfo.w32(44, vkVersion(1, 4, 0))

        val extSurface = heapCstr("VK_KHR_surface")
        val extWin32 = heapCstr("VK_KHR_win32_surface")
        val extArr = heapZalloc(16)
        extArr.wP(0, extSurface); extArr.wP(8, extWin32)

        val ici = zalloc(64)
        ici.w32(0, VK_STYPE_INSTANCE_CI); ici.wP(24, appInfo)
        ici.w32(48, 2u); ici.wP(56, extArr)

        val instOut = alloc<LongVar>()
        vkCheck(vkCreateInstance(ici, null, instOut.ptr.reinterpret()), "vkCreateInstance")
        val instance = instOut.value.asPtr()
        debugPrint("[INIT] Instance: ${instOut.value.toString(16)}")

        // --- Instance-level functions ---
        vkDestroyInstance = loadInst(instance, "vkDestroyInstance")
        vkCreateWin32SurfaceKHR = loadInst(instance, "vkCreateWin32SurfaceKHR")
        vkDestroySurfaceKHR = loadInst(instance, "vkDestroySurfaceKHR")
        vkGetPhysicalDeviceSurfaceSupportKHR = loadInst(instance, "vkGetPhysicalDeviceSurfaceSupportKHR")
        vkGetPhysicalDeviceSurfaceCapabilitiesKHR = loadInst(instance, "vkGetPhysicalDeviceSurfaceCapabilitiesKHR")
        vkGetPhysicalDeviceSurfaceFormatsKHR = loadInst(instance, "vkGetPhysicalDeviceSurfaceFormatsKHR")
        vkGetDeviceProcAddr = loadInst(instance, "vkGetDeviceProcAddr")

        // --- Physical device ---
        val devCount = alloc<UIntVar>()
        vkCheck(vkEnumPhysDevices(instance, devCount.ptr.reinterpret(), null), "vkEnumPhysDevices(count)")
        if (devCount.value == 0u) throw RuntimeException("No Vulkan physical devices")
        val devList = allocArray<LongVar>(devCount.value.toInt())
        vkCheck(vkEnumPhysDevices(instance, devCount.ptr.reinterpret(), devList.reinterpret()), "vkEnumPhysDevices(list)")
        val physDev = devList[0].asPtr()
        debugPrint("[INIT] Physical device found")

        // --- Surface ---
        val sci = zalloc(40)
        sci.w32(0, VK_STYPE_WIN32_SURFACE_CI)
        sci.wP(24, hInstance as COpaquePointer?); sci.wP(32, hWnd as COpaquePointer?)

        val surfOut = alloc<LongVar>()
        vkCheck(vkCreateWin32SurfaceKHR(instance, sci, null, surfOut.ptr.reinterpret()), "vkCreateWin32SurfaceKHR")
        val surface = surfOut.value
        debugPrint("[INIT] Surface created")

        // --- Queue family selection (graphics + present) ---
        val qCount = alloc<UIntVar>()
        vkGetQueueFamilyProps(physDev, qCount.ptr.reinterpret(), null)
        val qProps = allocArray<ByteVar>(qCount.value.toInt() * 24) // VkQueueFamilyProperties = 24 bytes
        vkGetQueueFamilyProps(physDev, qCount.ptr.reinterpret(), qProps)

        var gfxQ = -1; var presentQ = -1
        for (i in 0 until qCount.value.toInt()) {
            val flags = qProps.r32(i * 24)
            val supBuf = alloc<UIntVar>()
            vkCheck(vkGetPhysicalDeviceSurfaceSupportKHR(physDev, i.toUInt(), surface, supBuf.ptr.reinterpret()),
                "vkGetPhysicalDeviceSurfaceSupportKHR")
            val present = supBuf.value != 0u
            if ((flags and VK_QUEUE_GRAPHICS_BIT) != 0u) {
                if (gfxQ < 0) gfxQ = i
                if (present && presentQ < 0) presentQ = i
            }
            if (present && presentQ < 0) presentQ = i
        }
        if (gfxQ < 0) throw RuntimeException("No graphics queue")
        if (presentQ < 0) throw RuntimeException("No present queue")
        debugPrint("[INIT] Queue families: gfx=$gfxQ present=$presentQ")

        // --- Device ---
        val prio = heapZalloc(4); prio.wF(0, 1.0f)
        val dqci = zalloc(40)
        dqci.w32(0, VK_STYPE_DEVICE_QUEUE_CI)
        // flags@16, queueFamilyIndex@20, queueCount@24, pad@28, pQueuePriorities@32
        dqci.w32(20, gfxQ.toUInt()); dqci.w32(24, 1u); dqci.wP(32, prio)

        val devExt = heapCstr("VK_KHR_swapchain")
        val devExtArr = heapZalloc(8); devExtArr.wP(0, devExt)

        val dci = zalloc(72)
        dci.w32(0, VK_STYPE_DEVICE_CI)
        // flags@16, queueCreateInfoCount@20, pQueueCreateInfos@24
        dci.w32(20, 1u); dci.wP(24, dqci)
        dci.w32(48, 1u); dci.wP(56, devExtArr) // extensionCount=1

        val devOut = alloc<LongVar>()
        vkCheck(vkCreateDevice(physDev, dci, null, devOut.ptr.reinterpret()), "vkCreateDevice")
        val device = devOut.value.asPtr()
        debugPrint("[INIT] Device created")

        // --- Device-level functions ---
        vkDestroyDevice = loadDev(device, "vkDestroyDevice")
        vkGetDeviceQueue = loadDev(device, "vkGetDeviceQueue")
        vkCreateSwapchainKHR = loadDev(device, "vkCreateSwapchainKHR")
        vkDestroySwapchainKHR = loadDev(device, "vkDestroySwapchainKHR")
        vkGetSwapchainImagesKHR = loadDev(device, "vkGetSwapchainImagesKHR")
        vkCreateImageView = loadDev(device, "vkCreateImageView")
        vkDestroyImageView = loadDev(device, "vkDestroyImageView")
        vkCreateShaderModule = loadDev(device, "vkCreateShaderModule")
        vkDestroyShaderModule = loadDev(device, "vkDestroyShaderModule")
        vkCreateRenderPass = loadDev(device, "vkCreateRenderPass")
        vkDestroyRenderPass = loadDev(device, "vkDestroyRenderPass")
        vkCreatePipelineLayout = loadDev(device, "vkCreatePipelineLayout")
        vkDestroyPipelineLayout = loadDev(device, "vkDestroyPipelineLayout")
        vkCreateGraphicsPipelines = loadDev(device, "vkCreateGraphicsPipelines")
        vkDestroyPipeline = loadDev(device, "vkDestroyPipeline")
        vkCreateFramebuffer = loadDev(device, "vkCreateFramebuffer")
        vkDestroyFramebuffer = loadDev(device, "vkDestroyFramebuffer")
        vkCreateCommandPool = loadDev(device, "vkCreateCommandPool")
        vkDestroyCommandPool = loadDev(device, "vkDestroyCommandPool")
        vkAllocateCommandBuffers = loadDev(device, "vkAllocateCommandBuffers")
        vkBeginCommandBuffer = loadDev(device, "vkBeginCommandBuffer")
        vkEndCommandBuffer = loadDev(device, "vkEndCommandBuffer")
        vkCmdBeginRenderPass = loadDev(device, "vkCmdBeginRenderPass")
        vkCmdEndRenderPass = loadDev(device, "vkCmdEndRenderPass")
        vkCmdBindPipeline = loadDev(device, "vkCmdBindPipeline")
        vkCmdDraw = loadDev(device, "vkCmdDraw")
        vkCreateSemaphore = loadDev(device, "vkCreateSemaphore")
        vkDestroySemaphore = loadDev(device, "vkDestroySemaphore")
        vkCreateFence = loadDev(device, "vkCreateFence")
        vkDestroyFence = loadDev(device, "vkDestroyFence")
        vkWaitForFences = loadDev(device, "vkWaitForFences")
        vkResetFences = loadDev(device, "vkResetFences")
        vkAcquireNextImageKHR = loadDev(device, "vkAcquireNextImageKHR")
        vkQueueSubmit = loadDev(device, "vkQueueSubmit")
        vkQueuePresentKHR = loadDev(device, "vkQueuePresentKHR")
        vkDeviceWaitIdle = loadDev(device, "vkDeviceWaitIdle")

        // --- Queues ---
        val qOut = alloc<LongVar>()
        vkGetDeviceQueue(device, gfxQ.toUInt(), 0u, qOut.ptr.reinterpret())
        val graphicsQueue = qOut.value.asPtr()
        vkGetDeviceQueue(device, presentQ.toUInt(), 0u, qOut.ptr.reinterpret())
        val presentQueue = qOut.value.asPtr()

        // ============================================================
        // Swapchain
        // ============================================================
        val caps = zalloc(52)
        vkCheck(vkGetPhysicalDeviceSurfaceCapabilitiesKHR(physDev, surface, caps), "getSurfaceCaps")
        val minImg = caps.r32(0); val maxImg = caps.r32(4)
        val capW = caps.r32(8); val capH = caps.r32(12)
        if (capW != 0xFFFFFFFFu) { curW = capW.toInt(); curH = capH.toInt() }
        var minImages = maxOf(minImg + 1u, 2u)
        if (maxImg != 0u && minImages > maxImg) minImages = maxImg

        val fmtCount = alloc<UIntVar>()
        vkCheck(vkGetPhysicalDeviceSurfaceFormatsKHR(physDev, surface, fmtCount.ptr.reinterpret(), null), "getSurfFormats(count)")
        val fmts = allocArray<ByteVar>(fmtCount.value.toInt() * 8)
        vkCheck(vkGetPhysicalDeviceSurfaceFormatsKHR(physDev, surface, fmtCount.ptr.reinterpret(), fmts), "getSurfFormats(list)")
        var chosenFmt = VK_FORMAT_B8G8R8A8_UNORM; var chosenCs = VK_COLORSPACE_SRGB_NONLINEAR
        for (i in 0 until fmtCount.value.toInt()) {
            val f = fmts.r32(i * 8); val cs = fmts.r32(i * 8 + 4)
            if (f == VK_FORMAT_B8G8R8A8_SRGB || f == VK_FORMAT_B8G8R8A8_UNORM) {
                chosenFmt = f; chosenCs = cs; break
            }
        }
        debugPrint("[INIT] Swapchain: ${curW}x${curH} fmt=$chosenFmt images=$minImages")

        // VkSwapchainCreateInfoKHR (104 bytes)
        val swci = zalloc(104)
        swci.w32(0, VK_STYPE_SWAPCHAIN_CI)
        swci.w64(24, surface) // surface
        swci.w32(32, minImages); swci.w32(36, chosenFmt); swci.w32(40, chosenCs)
        swci.w32(44, curW.toUInt()); swci.w32(48, curH.toUInt()) // imageExtent
        swci.w32(52, 1u) // imageArrayLayers
        swci.w32(56, VK_USAGE_COLOR_ATT)
        swci.w32(60, VK_SHARING_EXCLUSIVE)
        // queueFamilyIndexCount=0 at offset 64, pQueueFamilyIndices=0 at offset 72 (already zero)
        swci.w32(80, VK_TRANSFORM_IDENTITY)
        swci.w32(84, VK_COMPOSITE_OPAQUE)
        swci.w32(88, VK_PRESENT_FIFO)
        swci.w32(92, 1u) // clipped = VK_TRUE

        val swOut = alloc<LongVar>()
        vkCheck(vkCreateSwapchainKHR(device, swci, null, swOut.ptr.reinterpret()), "vkCreateSwapchainKHR")
        val swapchain = swOut.value

        val imgCount = alloc<UIntVar>()
        vkCheck(vkGetSwapchainImagesKHR(device, swapchain, imgCount.ptr.reinterpret(), null), "getSwapImgs(count)")
        val imageCount = imgCount.value.toInt()
        val imgBuf = allocArray<LongVar>(imageCount)
        vkCheck(vkGetSwapchainImagesKHR(device, swapchain, imgCount.ptr.reinterpret(), imgBuf.reinterpret()), "getSwapImgs(list)")
        debugPrint("[INIT] Swapchain images: $imageCount")

        // --- Image views ---
        val views = LongArray(imageCount)
        for (i in 0 until imageCount) {
            // VkImageViewCreateInfo (80 bytes)
            val ivci = zalloc(80)
            ivci.w32(0, VK_STYPE_IMAGE_VIEW_CI)
            ivci.w64(24, imgBuf[i]) // image
            ivci.w32(32, VK_IMAGE_VIEW_TYPE_2D); ivci.w32(36, chosenFmt)
            // components = all 0 (identity) at offsets 40-55
            ivci.w32(56, VK_IMAGE_ASPECT_COLOR) // subresourceRange.aspectMask
            ivci.w32(60, 0u) // baseMipLevel
            ivci.w32(64, 1u) // levelCount
            ivci.w32(68, 0u) // baseArrayLayer
            ivci.w32(72, 1u) // layerCount

            val vOut = alloc<LongVar>()
            vkCheck(vkCreateImageView(device, ivci, null, vOut.ptr.reinterpret()), "vkCreateImageView")
            views[i] = vOut.value
        }

        // ============================================================
        // Render pass
        // ============================================================
        // VkAttachmentDescription (36 bytes)
        val attach = zalloc(36)
        attach.w32(4, chosenFmt); attach.w32(8, VK_SAMPLE_1)
        attach.w32(12, VK_LOAD_OP_CLEAR); attach.w32(16, VK_STORE_OP_STORE)
        attach.w32(20, VK_LOAD_OP_DONT_CARE); attach.w32(24, VK_STORE_OP_DONT_CARE)
        attach.w32(28, VK_IMAGE_LAYOUT_UNDEFINED); attach.w32(32, VK_IMAGE_LAYOUT_PRESENT_SRC)

        // VkAttachmentReference (8 bytes)
        val aref = zalloc(8)
        aref.w32(0, 0u); aref.w32(4, VK_IMAGE_LAYOUT_COLOR_ATT)

        // VkSubpassDescription (72 bytes)
        val subpass = zalloc(72)
        // flags@0, pipelineBindPoint@4, inputCount@8, pad@12, pInput@16
        // colorAttachmentCount@24, pad@28, pColorAttachments@32
        subpass.w32(4, VK_BIND_POINT_GRAPHICS)
        subpass.w32(24, 1u) // colorAttachmentCount
        subpass.wP(32, aref) // pColorAttachments

        // VkRenderPassCreateInfo (64 bytes)
        val rpci = zalloc(64)
        rpci.w32(0, VK_STYPE_RENDER_PASS_CI)
        // flags@16, attachmentCount@20, pAttachments@24, subpassCount@32, pad@36, pSubpasses@40
        rpci.w32(20, 1u); rpci.wP(24, attach)
        rpci.w32(32, 1u); rpci.wP(40, subpass)

        val rpOut = alloc<LongVar>()
        vkCheck(vkCreateRenderPass(device, rpci, null, rpOut.ptr.reinterpret()), "vkCreateRenderPass")
        val renderPass = rpOut.value
        debugPrint("[INIT] Render pass created")

        // ============================================================
        // Shader modules
        // ============================================================
        fun createShaderModule(spv: ByteArray): Long {
            val pCode = heapZalloc(spv.size)
            for (i in spv.indices) pCode[i] = spv[i]
            val smci = zalloc(40)
            smci.w32(0, VK_STYPE_SHADER_MODULE_CI)
            smci.w64(24, spv.size.toLong()); smci.wP(32, pCode)
            val out = alloc<LongVar>()
            vkCheck(vkCreateShaderModule(device, smci, null, out.ptr.reinterpret()), "vkCreateShaderModule")
            return out.value
        }
        val vertMod = createShaderModule(vertSpv)
        val fragMod = createShaderModule(fragSpv)
        debugPrint("[INIT] Shader modules created")

        // ============================================================
        // Pipeline layout (empty)
        // ============================================================
        val plci = zalloc(48)
        plci.w32(0, VK_STYPE_PIPE_LAYOUT_CI)
        val plOut = alloc<LongVar>()
        vkCheck(vkCreatePipelineLayout(device, plci, null, plOut.ptr.reinterpret()), "vkCreatePipelineLayout")
        val pipelineLayout = plOut.value

        // ============================================================
        // Graphics pipeline (fixed viewport/scissor)
        // ============================================================
        debugPrint("[INIT] Creating graphics pipeline...")
        val pEntry = heapCstr("main")

        // Two VkPipelineShaderStageCreateInfo (48 bytes each, 96 total)
        val stages = zalloc(96)
        // VkPipelineShaderStageCI: flags@16, stage@20, module@24, pName@32, pSpec@40
        // Vertex stage (offset 0)
        stages.w32(0, VK_STYPE_PIPE_SHADER_STAGE_CI)
        stages.w32(20, VK_STAGE_VERTEX); stages.w64(24, vertMod); stages.wP(32, pEntry)
        // Fragment stage (offset 48)
        stages.w32(48, VK_STYPE_PIPE_SHADER_STAGE_CI)
        stages.w32(68, VK_STAGE_FRAGMENT); stages.w64(72, fragMod); stages.wP(80, pEntry)

        // VkPipelineVertexInputStateCreateInfo (48 bytes)
        val vi = zalloc(48); vi.w32(0, VK_STYPE_PIPE_VERTEX_INPUT_CI)

        // VkPipelineInputAssemblyStateCreateInfo (32 bytes)
        // flags@16, topology@20, primitiveRestartEnable@24
        val ia = zalloc(32); ia.w32(0, VK_STYPE_PIPE_INPUT_ASM_CI); ia.w32(20, VK_TOPO_TRIANGLE_LIST)

        // VkViewport (24 bytes) + VkRect2D (16 bytes)
        val viewport = zalloc(24)
        viewport.wF(0, 0f); viewport.wF(4, 0f)
        viewport.wF(8, curW.toFloat()); viewport.wF(12, curH.toFloat())
        viewport.wF(16, 0f); viewport.wF(20, 1f)
        val scissor = zalloc(16)
        scissor.w32(8, curW.toUInt()); scissor.w32(12, curH.toUInt())

        // VkPipelineViewportStateCreateInfo (48 bytes)
        // flags@16, viewportCount@20, pViewports@24, scissorCount@32, pad@36, pScissors@40
        val vps = zalloc(48); vps.w32(0, VK_STYPE_PIPE_VIEWPORT_CI)
        vps.w32(20, 1u); vps.wP(24, viewport); vps.w32(32, 1u); vps.wP(40, scissor)

        // VkPipelineRasterizationStateCreateInfo (64 bytes)
        // flags@16, depthClamp@20, discard@24, polygonMode@28, cullMode@32,
        // frontFace@36, depthBiasEn@40, biasFactor@44, biasClamp@48, biasSlope@52, lineWidth@56
        val rast = zalloc(64); rast.w32(0, VK_STYPE_PIPE_RASTERIZATION_CI)
        rast.w32(28, VK_POLYGON_FILL); rast.w32(32, VK_CULL_NONE)
        rast.w32(36, VK_FRONT_CCW); rast.wF(56, 1.0f) // lineWidth

        // VkPipelineMultisampleStateCreateInfo (48 bytes)
        // flags@16, rasterizationSamples@20, sampleShading@24, minSample@28, pMask@32
        val ms = zalloc(48); ms.w32(0, VK_STYPE_PIPE_MULTISAMPLE_CI)
        ms.w32(20, VK_SAMPLE_1)

        // VkPipelineColorBlendAttachmentState (32 bytes)
        val cba = zalloc(32)
        cba.w32(28, VK_COLOR_RGBA) // colorWriteMask

        // VkPipelineColorBlendStateCreateInfo (56 bytes)
        // flags@16, logicOpEnable@20, logicOp@24, attachmentCount@28, pAttachments@32
        val cb = zalloc(56); cb.w32(0, VK_STYPE_PIPE_COLOR_BLEND_CI)
        cb.w32(28, 1u); cb.wP(32, cba)

        // VkGraphicsPipelineCreateInfo (144 bytes)
        val gpci = zalloc(144)
        gpci.w32(0, VK_STYPE_GRAPHICS_PIPE_CI)
        gpci.w32(20, 2u) // stageCount
        gpci.wP(24, stages)
        gpci.wP(32, vi)   // pVertexInputState
        gpci.wP(40, ia)   // pInputAssemblyState
        // pTessellationState = null (48)
        gpci.wP(56, vps)  // pViewportState
        gpci.wP(64, rast) // pRasterizationState
        gpci.wP(72, ms)   // pMultisampleState
        // pDepthStencilState = null (80)
        gpci.wP(88, cb)   // pColorBlendState
        // pDynamicState = null (96)
        gpci.w64(104, pipelineLayout) // layout
        gpci.w64(112, renderPass)     // renderPass
        gpci.w32(120, 0u) // subpass
        gpci.w32(136, (-1)) // basePipelineIndex @ 136

        val pipeOut = alloc<LongVar>()
        vkCheck(vkCreateGraphicsPipelines(device, 0L, 1u, gpci, null, pipeOut.ptr.reinterpret()),
            "vkCreateGraphicsPipelines")
        val pipeline = pipeOut.value
        debugPrint("[INIT] Graphics pipeline created")

        // ============================================================
        // Framebuffers
        // ============================================================
        val framebuffers = LongArray(imageCount)
        for (i in 0 until imageCount) {
            val pAttach = zalloc(8); pAttach.w64(0, views[i])
            val fbci = zalloc(64)
            fbci.w32(0, VK_STYPE_FRAMEBUFFER_CI)
            fbci.w64(24, renderPass)
            fbci.w32(32, 1u); fbci.wP(40, pAttach)
            fbci.w32(48, curW.toUInt()); fbci.w32(52, curH.toUInt()); fbci.w32(56, 1u)
            val fbOut = alloc<LongVar>()
            vkCheck(vkCreateFramebuffer(device, fbci, null, fbOut.ptr.reinterpret()), "vkCreateFramebuffer")
            framebuffers[i] = fbOut.value
        }

        // ============================================================
        // Command pool + buffers
        // ============================================================
        val cpci = zalloc(24)
        cpci.w32(0, VK_STYPE_CMD_POOL_CI)
        cpci.w32(16, VK_CMD_POOL_RESET_CMD_BIT); cpci.w32(20, gfxQ.toUInt())
        val cpOut = alloc<LongVar>()
        vkCheck(vkCreateCommandPool(device, cpci, null, cpOut.ptr.reinterpret()), "vkCreateCommandPool")
        val cmdPool = cpOut.value

        val cbai = zalloc(32)
        cbai.w32(0, VK_STYPE_CMD_BUF_ALLOC_INFO)
        cbai.w64(16, cmdPool)
        cbai.w32(24, VK_CMD_BUF_LEVEL_PRIMARY); cbai.w32(28, imageCount.toUInt())
        val cmdBufs = allocArray<LongVar>(imageCount) // VkCommandBuffer = dispatchable = ptr
        vkCheck(vkAllocateCommandBuffers(device, cbai, cmdBufs.reinterpret()), "vkAllocateCommandBuffers")
        debugPrint("[INIT] Command buffers allocated: $imageCount")

        // --- Record command buffers ---
        for (i in 0 until imageCount) {
            val cmd = cmdBufs[i].asPtr()
            val bi = zalloc(32)
            bi.w32(0, VK_STYPE_CMD_BUF_BEGIN_INFO)
            vkCheck(vkBeginCommandBuffer(cmd, bi), "vkBeginCommandBuffer")

            val clearVal = zalloc(16)
            clearVal.wF(0, 0.1f); clearVal.wF(4, 0.1f); clearVal.wF(8, 0.1f); clearVal.wF(12, 1.0f)
            val rpbi = zalloc(64)
            rpbi.w32(0, VK_STYPE_RENDER_PASS_BEGIN_INFO)
            rpbi.w64(16, renderPass); rpbi.w64(24, framebuffers[i])
            rpbi.w32(32, 0); rpbi.w32(36, 0) // offset
            rpbi.w32(40, curW.toUInt()); rpbi.w32(44, curH.toUInt()) // extent
            rpbi.w32(48, 1u); rpbi.wP(56, clearVal)

            vkCmdBeginRenderPass(cmd, rpbi, VK_SUBPASS_INLINE)
            vkCmdBindPipeline(cmd, VK_BIND_POINT_GRAPHICS, pipeline)
            vkCmdDraw(cmd, 3u, 1u, 0u, 0u)
            vkCmdEndRenderPass(cmd)
            vkCheck(vkEndCommandBuffer(cmd), "vkEndCommandBuffer")
        }

        // ============================================================
        // Sync objects (double-buffered)
        // ============================================================
        val MAX_FRAMES = 2
        val imageAvail = LongArray(MAX_FRAMES)
        val renderDone = LongArray(MAX_FRAMES)
        val inFlight   = LongArray(MAX_FRAMES)

        for (i in 0 until MAX_FRAMES) {
            val semCi = zalloc(24); semCi.w32(0, VK_STYPE_SEMAPHORE_CI)
            val fenCi = zalloc(24); fenCi.w32(0, VK_STYPE_FENCE_CI); fenCi.w32(16, VK_FENCE_SIGNALED)

            val s1 = alloc<LongVar>(); val s2 = alloc<LongVar>(); val f = alloc<LongVar>()
            vkCheck(vkCreateSemaphore(device, semCi, null, s1.ptr.reinterpret()), "vkCreateSemaphore")
            vkCheck(vkCreateSemaphore(device, semCi, null, s2.ptr.reinterpret()), "vkCreateSemaphore")
            vkCheck(vkCreateFence(device, fenCi, null, f.ptr.reinterpret()), "vkCreateFence")
            imageAvail[i] = s1.value; renderDone[i] = s2.value; inFlight[i] = f.value
        }
        debugPrint("[INIT] Sync objects created")

        // ============================================================
        // Render loop
        // ============================================================
        debugPrint("[RENDER] Starting main loop. Close window to exit.")
        val msg = alloc<MSG>()
        var frame = 0

        while (!shouldQuit) {
            // Pump messages
            while (PeekMessageW(msg.ptr, null, 0u, 0u, PM_REMOVE.toUInt()) != 0) {
                if (msg.message.toInt() == WM_QUIT) { shouldQuit = true; break }
                TranslateMessage(msg.ptr); DispatchMessageW(msg.ptr)
            }
            if (shouldQuit) break

            val cur = frame % MAX_FRAMES

            // Wait
            val fences = alloc<LongVar>(); fences.value = inFlight[cur]
            vkCheck(vkWaitForFences(device, 1u, fences.ptr.reinterpret(), 1u, 1_000_000_000L), "vkWaitForFences")
            vkCheck(vkResetFences(device, 1u, fences.ptr.reinterpret()), "vkResetFences")

            // Acquire
            val imgIdx = alloc<UIntVar>()
            val acqRes = vkAcquireNextImageKHR(device, swapchain, 1_000_000_000L,
                imageAvail[cur], 0L, imgIdx.ptr.reinterpret())
            if (acqRes != VK_SUCCESS && acqRes != VK_SUBOPTIMAL_KHR)
                throw RuntimeException("vkAcquireNextImageKHR failed: $acqRes")
            val idx = imgIdx.value.toInt()

            // Submit
            val waitSem = alloc<LongVar>(); waitSem.value = imageAvail[cur]
            val sigSem = alloc<LongVar>(); sigSem.value = renderDone[cur]
            val waitStage = alloc<UIntVar>(); waitStage.value = VK_PIPE_STAGE_COLOR_ATT_OUT
            val cmdRef = alloc<LongVar>(); cmdRef.value = cmdBufs[idx]

            val submit = zalloc(72)
            submit.w32(0, VK_STYPE_SUBMIT_INFO.toUInt())
            submit.w32(16, 1u); submit.wP(24, waitSem.ptr)   // waitSemaphoreCount, pWaitSemaphores
            submit.wP(32, waitStage.ptr)                       // pWaitDstStageMask
            submit.w32(40, 1u); submit.wP(48, cmdRef.ptr)     // commandBufferCount, pCommandBuffers
            submit.w32(56, 1u); submit.wP(64, sigSem.ptr)     // signalSemaphoreCount, pSignalSemaphores

            vkCheck(vkQueueSubmit(graphicsQueue, 1u, submit, inFlight[cur]), "vkQueueSubmit")

            // Present
            val presSC = alloc<LongVar>(); presSC.value = swapchain
            val presIdx = alloc<UIntVar>(); presIdx.value = imgIdx.value
            val presSem = alloc<LongVar>(); presSem.value = renderDone[cur]

            val present = zalloc(64)
            present.w32(0, VK_STYPE_PRESENT_INFO.toUInt())
            present.w32(16, 1u); present.wP(24, presSem.ptr)  // waitSemaphoreCount, pWaitSemaphores
            present.w32(32, 1u); present.wP(40, presSC.ptr)   // swapchainCount, pSwapchains
            present.wP(48, presIdx.ptr)                         // pImageIndices

            val presRes = vkQueuePresentKHR(presentQueue, present)
            if (presRes != VK_SUCCESS && presRes != VK_SUBOPTIMAL_KHR)
                throw RuntimeException("vkQueuePresentKHR failed: $presRes")

            frame++
            Sleep(1u)
        }

        // ============================================================
        // Cleanup
        // ============================================================
        debugPrint("[CLEANUP] Starting...")
        vkDeviceWaitIdle(device)

        for (i in 0 until MAX_FRAMES) {
            vkDestroyFence(device, inFlight[i], null)
            vkDestroySemaphore(device, renderDone[i], null)
            vkDestroySemaphore(device, imageAvail[i], null)
        }
        vkDestroyPipeline(device, pipeline, null)
        vkDestroyPipelineLayout(device, pipelineLayout, null)
        vkDestroyShaderModule(device, fragMod, null)
        vkDestroyShaderModule(device, vertMod, null)
        for (i in 0 until imageCount) vkDestroyFramebuffer(device, framebuffers[i], null)
        vkDestroyRenderPass(device, renderPass, null)
        for (i in 0 until imageCount) vkDestroyImageView(device, views[i], null)
        vkDestroyCommandPool(device, cmdPool, null)
        vkDestroySwapchainKHR(device, swapchain, null)
        vkDestroyDevice(device, null)
        vkDestroySurfaceKHR(instance, surface, null)
        vkDestroyInstance(instance, null)

        debugPrint("[CLEANUP] Done. === Program End ===")
    }
}