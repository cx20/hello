// harmonograph.cpp
// Vulkan 1.4 Animated Harmonograph sample for C++/CLI (Win32)
//
// Architecture:
//   1. Every frame: updateUBO() ? advance animTime, modulate f1-f4 via sin, drift p1
//   2. Compute shader (hello.comp) recomputes all VERTEX_COUNT positions + colors
//   3. Pipeline barrier: compute WRITE -> vertex SHADER READ
//   4. Vertex shader (hello.vert) reads SSBOs via gl_VertexIndex
//   5. Fragment shader (hello.frag) outputs interpolated color
//
// Animation (identical to C and C# reference):
//   animTime += 0.016 per frame
//   f1 = 2 + 0.5*sin(animTime*0.7)
//   f2 = 2 + 0.5*sin(animTime*0.9)
//   f3 = 2 + 0.5*sin(animTime*1.1)
//   f4 = 2 + 0.5*sin(animTime*1.3)
//   p1 += 0.002 per frame
//
// Compilation:
//   cl harmonograph.cpp /clr /std:c++20 /EHa
//     /link user32.lib gdi32.lib vulkan-1.lib shaderc_combined.lib /SUBSYSTEM:WINDOWS

// ============================================================================
// All Vulkan/Win32 code must be compiled as unmanaged
// ============================================================================
#pragma managed(push, off)

#define VK_USE_PLATFORM_WIN32_KHR
#define WIN32_LEAN_AND_MEAN
#define NOMINMAX
#include <windows.h>
#include <tchar.h>
#include <vulkan/vulkan.h>
#include <vulkan/vulkan_win32.h>
#include <shaderc/shaderc.hpp>

#include <stdexcept>
#include <algorithm>
#include <vector>
#include <cstring>
#include <cstdlib>
#include <cstdint>
#include <cmath>
#include <optional>
#include <set>
#include <string>
#include <array>

// ============================================================================
// Window / rendering constants
// ============================================================================
static const uint32_t WIDTH            = 960;
static const uint32_t HEIGHT           = 720;
static const int      MAX_FRAMES       = 2;
static const uint32_t VERTEX_COUNT     = 500000;   // matches C / C# reference
static const float    ANIM_DT          = 0.016f;   // time step per frame (?60 fps)

// ============================================================================
// Inline GLSL sources  (taken verbatim from project files)
// ============================================================================

// hello.comp Ñü compute harmonograph positions and HSV-based colors
static const char* COMPUTE_GLSL = R"glsl(
#version 450

layout(local_size_x = 256, local_size_y = 1, local_size_z = 1) in;

layout(std430, binding = 0) buffer Positions { vec4 pos[]; };
layout(std430, binding = 1) buffer Colors    { vec4 col[]; };

layout(std140, binding = 2) uniform Params
{
    uint  max_num;
    float dt;
    float scale;
    float pad0;

    float A1; float f1; float p1; float d1;
    float A2; float f2; float p2; float d2;
    float A3; float f3; float p3; float d3;
    float A4; float f4; float p4; float d4;
} u;

vec3 hsv2rgb(float h, float s, float v)
{
    float c  = v * s;
    float hp = h / 60.0;
    float x  = c * (1.0 - abs(mod(hp, 2.0) - 1.0));
    vec3 rgb;

    if      (hp < 1.0) rgb = vec3(c, x, 0.0);
    else if (hp < 2.0) rgb = vec3(x, c, 0.0);
    else if (hp < 3.0) rgb = vec3(0.0, c, x);
    else if (hp < 4.0) rgb = vec3(0.0, x, c);
    else if (hp < 5.0) rgb = vec3(x, 0.0, c);
    else               rgb = vec3(c, 0.0, x);

    float m = v - c;
    return rgb + vec3(m);
}

void main()
{
    uint idx = gl_GlobalInvocationID.x;
    if (idx >= u.max_num) return;

    float t  = float(idx) * u.dt;
    float PI = 3.141592653589793;

    // X axis: superposition of two damped sinusoids (pendulums 1 & 2)
    float x = u.A1 * sin(u.f1 * t + PI * u.p1) * exp(-u.d1 * t) +
              u.A2 * sin(u.f2 * t + PI * u.p2) * exp(-u.d2 * t);

    // Y axis: superposition of two damped sinusoids (pendulums 3 & 4)
    float y = u.A3 * sin(u.f3 * t + PI * u.p3) * exp(-u.d3 * t) +
              u.A4 * sin(u.f4 * t + PI * u.p4) * exp(-u.d4 * t);

    vec2 p   = vec2(x, y) * u.scale;
    pos[idx] = vec4(p.x, p.y, 0.0, 1.0);

    // Assign a rainbow color based on normalized time
    float hue = mod((t / 20.0) * 360.0, 360.0);
    vec3  rgb = hsv2rgb(hue, 1.0, 1.0);
    col[idx]  = vec4(rgb, 1.0);
}
)glsl";

// hello.vert Ñü read position/color from SSBOs using gl_VertexIndex
static const char* VERTEX_GLSL = R"glsl(
#version 450

layout(std430, binding = 0) buffer Positions { vec4 pos[]; };
layout(std430, binding = 1) buffer Colors    { vec4 col[]; };

layout(location = 0) out vec4 vColor;

void main()
{
    uint idx    = uint(gl_VertexIndex);
    gl_Position = pos[idx];
    vColor      = col[idx];
}
)glsl";

// hello.frag Ñü pass-through color output
static const char* FRAGMENT_GLSL = R"glsl(
#version 450

layout(location = 0) in  vec4 vColor;
layout(location = 0) out vec4 outColor;

void main()
{
    outColor = vColor;
}
)glsl";

// ============================================================================
// Runtime GLSLÅ®SPIR-V compiler wrapper (shaderc)
// ============================================================================
class ShaderCompiler {
public:
    static std::vector<uint32_t> compile(
        const std::string& src, shaderc_shader_kind kind, const char* name)
    {
        shaderc::Compiler       compiler;
        shaderc::CompileOptions opts;
        opts.SetOptimizationLevel(shaderc_optimization_level_performance);

        auto result = compiler.CompileGlslToSpv(src, kind, name, opts);
        if (result.GetCompilationStatus() != shaderc_compilation_status_success)
            throw std::runtime_error(std::string("Shader compile failed [") + name + "]: "
                + result.GetErrorMessage());

        return { result.cbegin(), result.cend() };
    }

    static std::vector<uint32_t> compileVert(const std::string& s)
        { return compile(s, shaderc_glsl_vertex_shader,   "vert"); }
    static std::vector<uint32_t> compileFrag(const std::string& s)
        { return compile(s, shaderc_glsl_fragment_shader, "frag"); }
    static std::vector<uint32_t> compileComp(const std::string& s)
        { return compile(s, shaderc_glsl_compute_shader,  "comp"); }
};

// ============================================================================
// Vulkan instance / validation layer setup
// ============================================================================
static const std::vector<const char*> kValidationLayers = {
    "VK_LAYER_KHRONOS_validation"
};
static const std::vector<const char*> kDeviceExtensions = {
    VK_KHR_SWAPCHAIN_EXTENSION_NAME
};

#ifdef NDEBUG
static const bool kEnableValidation = false;
#else
static const bool kEnableValidation = true;
#endif

static VkResult CreateDebugUtilsMessengerEXT(
    VkInstance instance,
    const VkDebugUtilsMessengerCreateInfoEXT* pCI,
    const VkAllocationCallbacks* pAlloc,
    VkDebugUtilsMessengerEXT* pOut)
{
    auto fn = (PFN_vkCreateDebugUtilsMessengerEXT)
        vkGetInstanceProcAddr(instance, "vkCreateDebugUtilsMessengerEXT");
    return fn ? fn(instance, pCI, pAlloc, pOut) : VK_ERROR_EXTENSION_NOT_PRESENT;
}

static void DestroyDebugUtilsMessengerEXT(
    VkInstance instance,
    VkDebugUtilsMessengerEXT messenger,
    const VkAllocationCallbacks* pAlloc)
{
    auto fn = (PFN_vkDestroyDebugUtilsMessengerEXT)
        vkGetInstanceProcAddr(instance, "vkDestroyDebugUtilsMessengerEXT");
    if (fn) fn(instance, messenger, pAlloc);
}

// ============================================================================
// Helper structs
// ============================================================================

// Queue family indices: requires graphics, present, AND compute
struct QueueFamilyIndices {
    std::optional<uint32_t> graphicsFamily;
    std::optional<uint32_t> presentFamily;
    std::optional<uint32_t> computeFamily;

    bool isComplete() const {
        return graphicsFamily.has_value()
            && presentFamily.has_value()
            && computeFamily.has_value();
    }
};

struct SwapChainSupport {
    VkSurfaceCapabilitiesKHR        capabilities;
    std::vector<VkSurfaceFormatKHR> formats;
    std::vector<VkPresentModeKHR>   presentModes;
};

// Harmonograph uniform block Ñü must match std140 layout in hello.comp
struct alignas(16) HarmonographParams {
    uint32_t max_num;
    float    dt;
    float    scale;
    float    pad0;
    // X-axis pendulums (1, 2)
    float A1, f1, p1, d1;
    float A2, f2, p2, d2;
    // Y-axis pendulums (3, 4)
    float A3, f3, p3, d3;
    float A4, f4, p4, d4;
};

// ============================================================================
// Global window state
// ============================================================================
static bool g_framebufferResized = false;
static bool g_running            = true;

// ============================================================================
// HarmonographApp
// ============================================================================
class HarmonographApp {
public:
    void run() {
        initWindow();
        initVulkan();
        mainLoop();
        cleanup();
    }

private:
    // ÑüÑü Win32 ÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑü
    HWND      m_hwnd  = nullptr;
    HINSTANCE m_hInst = nullptr;

    // ÑüÑü Vulkan core ÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑü
    VkInstance               m_instance       = VK_NULL_HANDLE;
    VkDebugUtilsMessengerEXT m_debugMessenger = VK_NULL_HANDLE;
    VkSurfaceKHR             m_surface        = VK_NULL_HANDLE;
    VkPhysicalDevice         m_physDevice     = VK_NULL_HANDLE;
    VkDevice                 m_device         = VK_NULL_HANDLE;

    // ÑüÑü Queues ÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑü
    // Graphics and compute may share the same queue family on desktop GPUs.
    VkQueue m_graphicsQueue = VK_NULL_HANDLE;
    VkQueue m_presentQueue  = VK_NULL_HANDLE;
    VkQueue m_computeQueue  = VK_NULL_HANDLE;

    // ÑüÑü Swapchain ÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑü
    VkSwapchainKHR             m_swapChain       = VK_NULL_HANDLE;
    std::vector<VkImage>       m_scImages;
    VkFormat                   m_scFormat        = VK_FORMAT_UNDEFINED;
    VkExtent2D                 m_scExtent         = {};
    std::vector<VkImageView>   m_scImageViews;
    std::vector<VkFramebuffer> m_scFramebuffers;

    // ÑüÑü Render pass / graphics pipeline ÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑü
    VkRenderPass     m_renderPass      = VK_NULL_HANDLE;
    VkPipelineLayout m_graphicsLayout  = VK_NULL_HANDLE;
    VkPipeline       m_graphicsPipeline = VK_NULL_HANDLE;

    // ÑüÑü Compute pipeline ÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑü
    VkPipelineLayout m_computeLayout   = VK_NULL_HANDLE;
    VkPipeline       m_computePipeline = VK_NULL_HANDLE;

    // ÑüÑü Descriptors ÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑü
    // One shared descriptor set layout / set for both pipelines:
    //   binding 0: SSBO positions (compute WRITE + vertex READ)
    //   binding 1: SSBO colors    (compute WRITE + vertex READ)
    //   binding 2: UBO params     (compute READ only)
    VkDescriptorSetLayout m_descSetLayout = VK_NULL_HANDLE;
    VkDescriptorPool      m_descPool      = VK_NULL_HANDLE;
    VkDescriptorSet       m_descSet       = VK_NULL_HANDLE;

    // ÑüÑü Buffers ÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑü
    VkBuffer       m_posBuffer     = VK_NULL_HANDLE;
    VkDeviceMemory m_posMem        = VK_NULL_HANDLE;
    VkBuffer       m_colBuffer     = VK_NULL_HANDLE;
    VkDeviceMemory m_colMem        = VK_NULL_HANDLE;
    VkBuffer       m_uniformBuffer = VK_NULL_HANDLE;
    VkDeviceMemory m_uniformMem    = VK_NULL_HANDLE;

    // ÑüÑü Commands ÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑü
    VkCommandPool                m_cmdPool = VK_NULL_HANDLE;
    std::vector<VkCommandBuffer> m_cmdBuffers;

    // ÑüÑü Sync objects ÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑü
    std::vector<VkSemaphore> m_imageAvailSems;
    std::vector<VkSemaphore> m_renderDoneSems;
    std::vector<VkFence>     m_inFlightFences;
    std::vector<VkFence>     m_imagesInFlight;   // per swapchain image
    size_t                   m_currentFrame = 0;

    // ÑüÑü Animation state ÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑü
    // m_animTime: accumulated frame time, drives sinusoidal frequency modulation
    float m_animTime = 0.0f;

    // =========================================================================
    // Window procedure
    // =========================================================================
    static LRESULT CALLBACK WindowProc(HWND hWnd, UINT msg, WPARAM wp, LPARAM lp) {
        switch (msg) {
        case WM_SIZE:    g_framebufferResized = true; return 0;
        case WM_CLOSE:   g_running = false; DestroyWindow(hWnd); return 0;
        case WM_DESTROY: PostQuitMessage(0); return 0;
        }
        return DefWindowProc(hWnd, msg, wp, lp);
    }

    // =========================================================================
    // initWindow
    // =========================================================================
    void initWindow() {
        m_hInst = GetModuleHandle(nullptr);

        WNDCLASSEX wc    = {};
        wc.cbSize        = sizeof(wc);
        wc.style         = CS_HREDRAW | CS_VREDRAW;
        wc.lpfnWndProc   = WindowProc;
        wc.hInstance     = m_hInst;
        wc.hCursor       = LoadCursor(nullptr, IDC_ARROW);
        wc.hbrBackground = (HBRUSH)GetStockObject(BLACK_BRUSH);
        wc.lpszClassName = _T("VkHarmonograph");
        if (!RegisterClassEx(&wc))
            throw std::runtime_error("RegisterClassEx failed");

        RECT rc = { 0, 0, (LONG)WIDTH, (LONG)HEIGHT };
        AdjustWindowRect(&rc, WS_OVERLAPPEDWINDOW, FALSE);

        m_hwnd = CreateWindowEx(
            0,
            _T("VkHarmonograph"),
            _T("Harmonograph  ?  Vulkan 1.4 Compute Shader"),
            WS_OVERLAPPEDWINDOW,
            CW_USEDEFAULT, CW_USEDEFAULT,
            rc.right  - rc.left,
            rc.bottom - rc.top,
            nullptr, nullptr, m_hInst, nullptr);
        if (!m_hwnd)
            throw std::runtime_error("CreateWindowEx failed");

        ShowWindow(m_hwnd, SW_SHOW);
        UpdateWindow(m_hwnd);
    }

    // =========================================================================
    // initVulkan Ñü ordered initialization sequence
    // =========================================================================
    void initVulkan() {
        createInstance();
        setupDebugMessenger();
        createSurface();
        pickPhysicalDevice();
        createLogicalDevice();
        createSwapChain();
        createImageViews();
        createRenderPass();
        createDescriptorSetLayout();
        createComputePipeline();   // compile + create compute pipeline
        createGraphicsPipeline();  // compile + create graphics pipeline
        createFramebuffers();
        createCommandPool();
        createStorageBuffers();    // device-local SSBOs (pos, col)
        createUniformBuffer();     // host-visible UBO (params)
        createDescriptorPool();
        createDescriptorSet();     // bind buffers to descriptor set
        allocateCommandBuffers();  // allocate (recording done per-frame)
        createSyncObjects();
    }

    // =========================================================================
    // Main loop
    // =========================================================================
    void mainLoop() {
        MSG msg = {};
        while (g_running) {
            while (PeekMessage(&msg, nullptr, 0, 0, PM_REMOVE)) {
                if (msg.message == WM_QUIT) { g_running = false; break; }
                TranslateMessage(&msg);
                DispatchMessage(&msg);
            }
            if (g_running) drawFrame();
        }
        vkDeviceWaitIdle(m_device);
    }

    // =========================================================================
    // createInstance
    // =========================================================================
    void createInstance() {
        if (kEnableValidation && !checkValidationLayerSupport())
            throw std::runtime_error("Validation layers not available");

        VkApplicationInfo ai{};
        ai.sType              = VK_STRUCTURE_TYPE_APPLICATION_INFO;
        ai.pApplicationName   = "Harmonograph";
        ai.applicationVersion = VK_MAKE_VERSION(1, 0, 0);
        ai.pEngineName        = "No Engine";
        ai.engineVersion      = VK_MAKE_VERSION(1, 0, 0);
        ai.apiVersion         = VK_API_VERSION_1_4;  // Vulkan 1.4

        auto exts = getRequiredExtensions();

        VkInstanceCreateInfo ci{};
        ci.sType                   = VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO;
        ci.pApplicationInfo        = &ai;
        ci.enabledExtensionCount   = (uint32_t)exts.size();
        ci.ppEnabledExtensionNames = exts.data();

        VkDebugUtilsMessengerCreateInfoEXT dbgCI{};
        if (kEnableValidation) {
            ci.enabledLayerCount   = (uint32_t)kValidationLayers.size();
            ci.ppEnabledLayerNames = kValidationLayers.data();
            populateDebugCI(dbgCI);
            ci.pNext = &dbgCI;
        }

        if (vkCreateInstance(&ci, nullptr, &m_instance) != VK_SUCCESS)
            throw std::runtime_error("vkCreateInstance failed");
    }

    // =========================================================================
    // Debug messenger
    // =========================================================================
    void populateDebugCI(VkDebugUtilsMessengerCreateInfoEXT& ci) {
        ci                 = {};
        ci.sType           = VK_STRUCTURE_TYPE_DEBUG_UTILS_MESSENGER_CREATE_INFO_EXT;
        ci.messageSeverity = VK_DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT
                           | VK_DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT;
        ci.messageType     = VK_DEBUG_UTILS_MESSAGE_TYPE_GENERAL_BIT_EXT
                           | VK_DEBUG_UTILS_MESSAGE_TYPE_VALIDATION_BIT_EXT
                           | VK_DEBUG_UTILS_MESSAGE_TYPE_PERFORMANCE_BIT_EXT;
        ci.pfnUserCallback = debugCallback;
    }

    void setupDebugMessenger() {
        if (!kEnableValidation) return;
        VkDebugUtilsMessengerCreateInfoEXT ci{};
        populateDebugCI(ci);
        if (CreateDebugUtilsMessengerEXT(m_instance, &ci, nullptr, &m_debugMessenger) != VK_SUCCESS)
            throw std::runtime_error("Failed to create debug messenger");
    }

    // =========================================================================
    // createSurface
    // =========================================================================
    void createSurface() {
        VkWin32SurfaceCreateInfoKHR ci{};
        ci.sType     = VK_STRUCTURE_TYPE_WIN32_SURFACE_CREATE_INFO_KHR;
        ci.hwnd      = m_hwnd;
        ci.hinstance = m_hInst;
        if (vkCreateWin32SurfaceKHR(m_instance, &ci, nullptr, &m_surface) != VK_SUCCESS)
            throw std::runtime_error("vkCreateWin32SurfaceKHR failed");
    }

    // =========================================================================
    // pickPhysicalDevice
    // =========================================================================
    void pickPhysicalDevice() {
        uint32_t cnt = 0;
        vkEnumeratePhysicalDevices(m_instance, &cnt, nullptr);
        if (cnt == 0) throw std::runtime_error("No Vulkan GPU found");
        std::vector<VkPhysicalDevice> devs(cnt);
        vkEnumeratePhysicalDevices(m_instance, &cnt, devs.data());
        for (auto d : devs) {
            if (isDeviceSuitable(d)) { m_physDevice = d; break; }
        }
        if (m_physDevice == VK_NULL_HANDLE)
            throw std::runtime_error("No suitable GPU found");
    }

    bool isDeviceSuitable(VkPhysicalDevice d) {
        if (!findQueueFamilies(d).isComplete())    return false;
        if (!checkDeviceExtensionSupport(d))       return false;
        auto sc = querySwapChainSupport(d);
        return !sc.formats.empty() && !sc.presentModes.empty();
    }

    // =========================================================================
    // createLogicalDevice
    // =========================================================================
    void createLogicalDevice() {
        auto idx = findQueueFamilies(m_physDevice);

        // Collect unique queue families (graphics, present, compute may overlap)
        std::set<uint32_t> uniqueFamilies = {
            idx.graphicsFamily.value(),
            idx.presentFamily.value(),
            idx.computeFamily.value()
        };

        float priority = 1.0f;
        std::vector<VkDeviceQueueCreateInfo> queueCIs;
        for (uint32_t family : uniqueFamilies) {
            VkDeviceQueueCreateInfo q{};
            q.sType            = VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO;
            q.queueFamilyIndex = family;
            q.queueCount       = 1;
            q.pQueuePriorities = &priority;
            queueCIs.push_back(q);
        }

        VkPhysicalDeviceFeatures features{};

        VkDeviceCreateInfo ci{};
        ci.sType                   = VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO;
        ci.queueCreateInfoCount    = (uint32_t)queueCIs.size();
        ci.pQueueCreateInfos       = queueCIs.data();
        ci.pEnabledFeatures        = &features;
        ci.enabledExtensionCount   = (uint32_t)kDeviceExtensions.size();
        ci.ppEnabledExtensionNames = kDeviceExtensions.data();
        if (kEnableValidation) {
            ci.enabledLayerCount   = (uint32_t)kValidationLayers.size();
            ci.ppEnabledLayerNames = kValidationLayers.data();
        }

        if (vkCreateDevice(m_physDevice, &ci, nullptr, &m_device) != VK_SUCCESS)
            throw std::runtime_error("vkCreateDevice failed");

        vkGetDeviceQueue(m_device, idx.graphicsFamily.value(), 0, &m_graphicsQueue);
        vkGetDeviceQueue(m_device, idx.presentFamily.value(),  0, &m_presentQueue);
        vkGetDeviceQueue(m_device, idx.computeFamily.value(),  0, &m_computeQueue);
    }

    // =========================================================================
    // Swapchain creation
    // =========================================================================
    void createSwapChain() {
        auto sc     = querySwapChainSupport(m_physDevice);
        auto fmt    = chooseSurfaceFormat(sc.formats);
        auto mode   = choosePresentMode(sc.presentModes);
        auto extent = chooseExtent(sc.capabilities);

        uint32_t imgCount = sc.capabilities.minImageCount + 1;
        if (sc.capabilities.maxImageCount > 0)
            imgCount = std::min(imgCount, sc.capabilities.maxImageCount);

        VkSwapchainCreateInfoKHR ci{};
        ci.sType            = VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR;
        ci.surface          = m_surface;
        ci.minImageCount    = imgCount;
        ci.imageFormat      = fmt.format;
        ci.imageColorSpace  = fmt.colorSpace;
        ci.imageExtent      = extent;
        ci.imageArrayLayers = 1;
        ci.imageUsage       = VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT;

        auto idx = findQueueFamilies(m_physDevice);
        uint32_t families[] = { idx.graphicsFamily.value(), idx.presentFamily.value() };
        if (idx.graphicsFamily.value() != idx.presentFamily.value()) {
            ci.imageSharingMode      = VK_SHARING_MODE_CONCURRENT;
            ci.queueFamilyIndexCount = 2;
            ci.pQueueFamilyIndices   = families;
        } else {
            ci.imageSharingMode = VK_SHARING_MODE_EXCLUSIVE;
        }

        ci.preTransform   = sc.capabilities.currentTransform;
        ci.compositeAlpha = VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR;
        ci.presentMode    = mode;
        ci.clipped        = VK_TRUE;

        if (vkCreateSwapchainKHR(m_device, &ci, nullptr, &m_swapChain) != VK_SUCCESS)
            throw std::runtime_error("vkCreateSwapchainKHR failed");

        vkGetSwapchainImagesKHR(m_device, m_swapChain, &imgCount, nullptr);
        m_scImages.resize(imgCount);
        vkGetSwapchainImagesKHR(m_device, m_swapChain, &imgCount, m_scImages.data());
        m_scFormat = fmt.format;
        m_scExtent = extent;
    }

    void createImageViews() {
        m_scImageViews.resize(m_scImages.size());
        for (size_t i = 0; i < m_scImages.size(); i++) {
            VkImageViewCreateInfo ci{};
            ci.sType                           = VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO;
            ci.image                           = m_scImages[i];
            ci.viewType                        = VK_IMAGE_VIEW_TYPE_2D;
            ci.format                          = m_scFormat;
            ci.components.r                    = VK_COMPONENT_SWIZZLE_IDENTITY;
            ci.components.g                    = VK_COMPONENT_SWIZZLE_IDENTITY;
            ci.components.b                    = VK_COMPONENT_SWIZZLE_IDENTITY;
            ci.components.a                    = VK_COMPONENT_SWIZZLE_IDENTITY;
            ci.subresourceRange.aspectMask     = VK_IMAGE_ASPECT_COLOR_BIT;
            ci.subresourceRange.baseMipLevel   = 0;
            ci.subresourceRange.levelCount     = 1;
            ci.subresourceRange.baseArrayLayer = 0;
            ci.subresourceRange.layerCount     = 1;
            if (vkCreateImageView(m_device, &ci, nullptr, &m_scImageViews[i]) != VK_SUCCESS)
                throw std::runtime_error("vkCreateImageView failed");
        }
    }

    // =========================================================================
    // Render pass  (single color attachment, black clear)
    // =========================================================================
    void createRenderPass() {
        VkAttachmentDescription color{};
        color.format         = m_scFormat;
        color.samples        = VK_SAMPLE_COUNT_1_BIT;
        color.loadOp         = VK_ATTACHMENT_LOAD_OP_CLEAR;
        color.storeOp        = VK_ATTACHMENT_STORE_OP_STORE;
        color.stencilLoadOp  = VK_ATTACHMENT_LOAD_OP_DONT_CARE;
        color.stencilStoreOp = VK_ATTACHMENT_STORE_OP_DONT_CARE;
        color.initialLayout  = VK_IMAGE_LAYOUT_UNDEFINED;
        color.finalLayout    = VK_IMAGE_LAYOUT_PRESENT_SRC_KHR;

        VkAttachmentReference colorRef{};
        colorRef.attachment = 0;
        colorRef.layout     = VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL;

        VkSubpassDescription subpass{};
        subpass.pipelineBindPoint    = VK_PIPELINE_BIND_POINT_GRAPHICS;
        subpass.colorAttachmentCount = 1;
        subpass.pColorAttachments    = &colorRef;

        VkSubpassDependency dep{};
        dep.srcSubpass    = VK_SUBPASS_EXTERNAL;
        dep.dstSubpass    = 0;
        dep.srcStageMask  = VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT;
        dep.srcAccessMask = 0;
        dep.dstStageMask  = VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT;
        dep.dstAccessMask = VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT;

        VkRenderPassCreateInfo ci{};
        ci.sType           = VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO;
        ci.attachmentCount = 1;
        ci.pAttachments    = &color;
        ci.subpassCount    = 1;
        ci.pSubpasses      = &subpass;
        ci.dependencyCount = 1;
        ci.pDependencies   = &dep;

        if (vkCreateRenderPass(m_device, &ci, nullptr, &m_renderPass) != VK_SUCCESS)
            throw std::runtime_error("vkCreateRenderPass failed");
    }

    void createFramebuffers() {
        m_scFramebuffers.resize(m_scImageViews.size());
        for (size_t i = 0; i < m_scImageViews.size(); i++) {
            VkFramebufferCreateInfo ci{};
            ci.sType           = VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO;
            ci.renderPass      = m_renderPass;
            ci.attachmentCount = 1;
            ci.pAttachments    = &m_scImageViews[i];
            ci.width           = m_scExtent.width;
            ci.height          = m_scExtent.height;
            ci.layers          = 1;
            if (vkCreateFramebuffer(m_device, &ci, nullptr, &m_scFramebuffers[i]) != VK_SUCCESS)
                throw std::runtime_error("vkCreateFramebuffer failed");
        }
    }

    // =========================================================================
    // Descriptor set layout  (shared between compute and graphics)
    //
    //  Binding 0  STORAGE_BUFFER  pos[]  compute(W) + vertex(R)
    //  Binding 1  STORAGE_BUFFER  col[]  compute(W) + vertex(R)
    //  Binding 2  UNIFORM_BUFFER  Params compute(R) only
    // =========================================================================
    void createDescriptorSetLayout() {
        std::array<VkDescriptorSetLayoutBinding, 3> b{};

        b[0].binding         = 0;
        b[0].descriptorType  = VK_DESCRIPTOR_TYPE_STORAGE_BUFFER;
        b[0].descriptorCount = 1;
        b[0].stageFlags      = VK_SHADER_STAGE_COMPUTE_BIT | VK_SHADER_STAGE_VERTEX_BIT;

        b[1].binding         = 1;
        b[1].descriptorType  = VK_DESCRIPTOR_TYPE_STORAGE_BUFFER;
        b[1].descriptorCount = 1;
        b[1].stageFlags      = VK_SHADER_STAGE_COMPUTE_BIT | VK_SHADER_STAGE_VERTEX_BIT;

        b[2].binding         = 2;
        b[2].descriptorType  = VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER;
        b[2].descriptorCount = 1;
        b[2].stageFlags      = VK_SHADER_STAGE_COMPUTE_BIT;

        VkDescriptorSetLayoutCreateInfo ci{};
        ci.sType        = VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO;
        ci.bindingCount = (uint32_t)b.size();
        ci.pBindings    = b.data();
        if (vkCreateDescriptorSetLayout(m_device, &ci, nullptr, &m_descSetLayout) != VK_SUCCESS)
            throw std::runtime_error("vkCreateDescriptorSetLayout failed");
    }

    // =========================================================================
    // Compute pipeline  (hello.comp)
    // =========================================================================
    void createComputePipeline() {
        auto spv = ShaderCompiler::compileComp(COMPUTE_GLSL);
        VkShaderModule mod = createShaderModule(spv);

        VkPipelineShaderStageCreateInfo stage{};
        stage.sType  = VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO;
        stage.stage  = VK_SHADER_STAGE_COMPUTE_BIT;
        stage.module = mod;
        stage.pName  = "main";

        VkPipelineLayoutCreateInfo layoutCI{};
        layoutCI.sType          = VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO;
        layoutCI.setLayoutCount = 1;
        layoutCI.pSetLayouts    = &m_descSetLayout;
        if (vkCreatePipelineLayout(m_device, &layoutCI, nullptr, &m_computeLayout) != VK_SUCCESS)
            throw std::runtime_error("Compute pipeline layout creation failed");

        VkComputePipelineCreateInfo pipeCI{};
        pipeCI.sType  = VK_STRUCTURE_TYPE_COMPUTE_PIPELINE_CREATE_INFO;
        pipeCI.stage  = stage;
        pipeCI.layout = m_computeLayout;
        if (vkCreateComputePipelines(m_device, VK_NULL_HANDLE, 1, &pipeCI, nullptr, &m_computePipeline) != VK_SUCCESS)
            throw std::runtime_error("Compute pipeline creation failed");

        vkDestroyShaderModule(m_device, mod, nullptr);
    }

    // =========================================================================
    // Graphics pipeline  (hello.vert + hello.frag, LINE_STRIP topology)
    //
    // No vertex input bindings: positions are fetched from SSBO inside the
    // vertex shader using gl_VertexIndex, so VkPipelineVertexInputStateCreateInfo
    // has zero bindings and zero attributes.
    // =========================================================================
    void createGraphicsPipeline() {
        auto vertSpv = ShaderCompiler::compileVert(VERTEX_GLSL);
        auto fragSpv = ShaderCompiler::compileFrag(FRAGMENT_GLSL);
        VkShaderModule vertMod = createShaderModule(vertSpv);
        VkShaderModule fragMod = createShaderModule(fragSpv);

        VkPipelineShaderStageCreateInfo stages[2] = {};
        stages[0].sType  = VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO;
        stages[0].stage  = VK_SHADER_STAGE_VERTEX_BIT;
        stages[0].module = vertMod;
        stages[0].pName  = "main";
        stages[1].sType  = VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO;
        stages[1].stage  = VK_SHADER_STAGE_FRAGMENT_BIT;
        stages[1].module = fragMod;
        stages[1].pName  = "main";

        // No vertex buffer bindings: data comes from SSBOs
        VkPipelineVertexInputStateCreateInfo vertexInput{};
        vertexInput.sType = VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO;

        // LINE_STRIP: draws the harmonograph as a continuous polyline
        VkPipelineInputAssemblyStateCreateInfo inputAssembly{};
        inputAssembly.sType    = VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO;
        inputAssembly.topology = VK_PRIMITIVE_TOPOLOGY_LINE_STRIP;

        VkViewport viewport{};
        viewport.width    = (float)m_scExtent.width;
        viewport.height   = (float)m_scExtent.height;
        viewport.minDepth = 0.0f;
        viewport.maxDepth = 1.0f;

        VkRect2D scissor{};
        scissor.extent = m_scExtent;

        VkPipelineViewportStateCreateInfo vpState{};
        vpState.sType         = VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO;
        vpState.viewportCount = 1;
        vpState.pViewports    = &viewport;
        vpState.scissorCount  = 1;
        vpState.pScissors     = &scissor;

        VkPipelineRasterizationStateCreateInfo raster{};
        raster.sType       = VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO;
        raster.polygonMode = VK_POLYGON_MODE_FILL;
        raster.cullMode    = VK_CULL_MODE_NONE;
        raster.frontFace   = VK_FRONT_FACE_CLOCKWISE;
        raster.lineWidth   = 1.0f;

        VkPipelineMultisampleStateCreateInfo msaa{};
        msaa.sType                = VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO;
        msaa.rasterizationSamples = VK_SAMPLE_COUNT_1_BIT;

        // Alpha blending: allows semi-transparent overdraw for denser regions
        VkPipelineColorBlendAttachmentState blendAtt{};
        blendAtt.colorWriteMask      = VK_COLOR_COMPONENT_R_BIT | VK_COLOR_COMPONENT_G_BIT
                                     | VK_COLOR_COMPONENT_B_BIT | VK_COLOR_COMPONENT_A_BIT;
        blendAtt.blendEnable         = VK_TRUE;
        blendAtt.srcColorBlendFactor = VK_BLEND_FACTOR_SRC_ALPHA;
        blendAtt.dstColorBlendFactor = VK_BLEND_FACTOR_ONE_MINUS_SRC_ALPHA;
        blendAtt.colorBlendOp        = VK_BLEND_OP_ADD;
        blendAtt.srcAlphaBlendFactor = VK_BLEND_FACTOR_ONE;
        blendAtt.dstAlphaBlendFactor = VK_BLEND_FACTOR_ZERO;
        blendAtt.alphaBlendOp        = VK_BLEND_OP_ADD;

        VkPipelineColorBlendStateCreateInfo blend{};
        blend.sType           = VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO;
        blend.attachmentCount = 1;
        blend.pAttachments    = &blendAtt;

        VkPipelineLayoutCreateInfo layoutCI{};
        layoutCI.sType          = VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO;
        layoutCI.setLayoutCount = 1;
        layoutCI.pSetLayouts    = &m_descSetLayout;
        if (vkCreatePipelineLayout(m_device, &layoutCI, nullptr, &m_graphicsLayout) != VK_SUCCESS)
            throw std::runtime_error("Graphics pipeline layout creation failed");

        VkGraphicsPipelineCreateInfo pipeCI{};
        pipeCI.sType               = VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO;
        pipeCI.stageCount          = 2;
        pipeCI.pStages             = stages;
        pipeCI.pVertexInputState   = &vertexInput;
        pipeCI.pInputAssemblyState = &inputAssembly;
        pipeCI.pViewportState      = &vpState;
        pipeCI.pRasterizationState = &raster;
        pipeCI.pMultisampleState   = &msaa;
        pipeCI.pColorBlendState    = &blend;
        pipeCI.layout              = m_graphicsLayout;
        pipeCI.renderPass          = m_renderPass;
        pipeCI.subpass             = 0;
        if (vkCreateGraphicsPipelines(m_device, VK_NULL_HANDLE, 1, &pipeCI, nullptr, &m_graphicsPipeline) != VK_SUCCESS)
            throw std::runtime_error("Graphics pipeline creation failed");

        vkDestroyShaderModule(m_device, vertMod, nullptr);
        vkDestroyShaderModule(m_device, fragMod, nullptr);
    }

    // =========================================================================
    // Command pool
    // =========================================================================
    void createCommandPool() {
        auto idx = findQueueFamilies(m_physDevice);

        VkCommandPoolCreateInfo ci{};
        ci.sType            = VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO;
        ci.queueFamilyIndex = idx.graphicsFamily.value();
        ci.flags            = VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT;
        if (vkCreateCommandPool(m_device, &ci, nullptr, &m_cmdPool) != VK_SUCCESS)
            throw std::runtime_error("vkCreateCommandPool failed");
    }

    // =========================================================================
    // Buffer helpers
    // =========================================================================
    uint32_t findMemoryType(uint32_t typeFilter, VkMemoryPropertyFlags props) {
        VkPhysicalDeviceMemoryProperties mp;
        vkGetPhysicalDeviceMemoryProperties(m_physDevice, &mp);
        for (uint32_t i = 0; i < mp.memoryTypeCount; i++) {
            if ((typeFilter & (1u << i)) &&
                (mp.memoryTypes[i].propertyFlags & props) == props)
                return i;
        }
        throw std::runtime_error("No suitable memory type found");
    }

    void createBuffer(VkDeviceSize size, VkBufferUsageFlags usage,
        VkMemoryPropertyFlags memProps,
        VkBuffer& outBuf, VkDeviceMemory& outMem)
    {
        VkBufferCreateInfo ci{};
        ci.sType       = VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO;
        ci.size        = size;
        ci.usage       = usage;
        ci.sharingMode = VK_SHARING_MODE_EXCLUSIVE;
        if (vkCreateBuffer(m_device, &ci, nullptr, &outBuf) != VK_SUCCESS)
            throw std::runtime_error("vkCreateBuffer failed");

        VkMemoryRequirements req;
        vkGetBufferMemoryRequirements(m_device, outBuf, &req);

        VkMemoryAllocateInfo ai{};
        ai.sType           = VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO;
        ai.allocationSize  = req.size;
        ai.memoryTypeIndex = findMemoryType(req.memoryTypeBits, memProps);
        if (vkAllocateMemory(m_device, &ai, nullptr, &outMem) != VK_SUCCESS)
            throw std::runtime_error("vkAllocateMemory failed");

        vkBindBufferMemory(m_device, outBuf, outMem, 0);
    }

    // =========================================================================
    // createStorageBuffers  Ñü device-local SSBOs for positions and colors
    //
    // Both buffers are STORAGE_BUFFER: written by compute shader, then read
    // by vertex shader.  They do not need to be HOST_VISIBLE because the
    // CPU never writes directly to them.
    // =========================================================================
    void createStorageBuffers() {
        VkDeviceSize bufSize = (VkDeviceSize)VERTEX_COUNT * sizeof(float) * 4; // vec4

        createBuffer(bufSize,
            VK_BUFFER_USAGE_STORAGE_BUFFER_BIT,
            VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT,
            m_posBuffer, m_posMem);

        createBuffer(bufSize,
            VK_BUFFER_USAGE_STORAGE_BUFFER_BIT,
            VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT,
            m_colBuffer, m_colMem);
    }

    // =========================================================================
    // createUniformBuffer  Ñü host-visible UBO for harmonograph parameters
    // =========================================================================
    void createUniformBuffer() {
        createBuffer(sizeof(HarmonographParams),
            VK_BUFFER_USAGE_UNIFORM_BUFFER_BIT,
            VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | VK_MEMORY_PROPERTY_HOST_COHERENT_BIT,
            m_uniformBuffer, m_uniformMem);

        // Set constant parameters; frequencies will be animated each frame
        initParams();
        updateUBO();
    }

    // =========================================================================
    // updateUBO
    //
    // Called every frame.  Mirrors the animation logic of the C and C# reference:
    //
    //   animTime += 0.016
    //   f1 = 2.0 + 0.5 * sin(animTime * 0.7)
    //   f2 = 2.0 + 0.5 * sin(animTime * 0.9)
    //   f3 = 2.0 + 0.5 * sin(animTime * 1.1)
    //   f4 = 2.0 + 0.5 * sin(animTime * 1.3)
    //   p1 += 0.002
    //
    // All other parameters are constant and identical to the reference.
    // =========================================================================
    // Persistent UBO state (matches g_params / uboParams in the reference)
    HarmonographParams m_params = {};

    void initParams() {
        m_params.max_num = VERTEX_COUNT;
        m_params.dt      = 0.001f;
        m_params.scale   = 0.02f;
        m_params.pad0    = 0.0f;
        // X pendulums  (same as C / C# reference)
        m_params.A1 = 50.0f; m_params.f1 = 2.0f; m_params.p1 = 1.0f/16.0f; m_params.d1 = 0.02f;
        m_params.A2 = 50.0f; m_params.f2 = 2.0f; m_params.p2 = 3.0f/2.0f;  m_params.d2 = 0.0315f;
        // Y pendulums
        m_params.A3 = 50.0f; m_params.f3 = 2.0f; m_params.p3 = 13.0f/15.0f; m_params.d3 = 0.02f;
        m_params.A4 = 50.0f; m_params.f4 = 2.0f; m_params.p4 = 1.0f;         m_params.d4 = 0.02f;
    }

    void updateUBO() {
        // Advance animation time
        m_animTime += ANIM_DT;

        // Sinusoidal frequency modulation (4 oscillators at different rates)
        m_params.f1 = 2.0f + 0.5f * sinf(m_animTime * 0.7f);
        m_params.f2 = 2.0f + 0.5f * sinf(m_animTime * 0.9f);
        m_params.f3 = 2.0f + 0.5f * sinf(m_animTime * 1.1f);
        m_params.f4 = 2.0f + 0.5f * sinf(m_animTime * 1.3f);

        // Continuous phase drift for p1
        m_params.p1 += 0.002f;

        void* mapped;
        vkMapMemory(m_device, m_uniformMem, 0, sizeof(m_params), 0, &mapped);
        memcpy(mapped, &m_params, sizeof(m_params));
        vkUnmapMemory(m_device, m_uniformMem);
    }

    // =========================================================================
    // Descriptor pool and set
    // =========================================================================
    void createDescriptorPool() {
        std::array<VkDescriptorPoolSize, 2> sizes{};
        sizes[0].type            = VK_DESCRIPTOR_TYPE_STORAGE_BUFFER;
        sizes[0].descriptorCount = 2;   // pos + col
        sizes[1].type            = VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER;
        sizes[1].descriptorCount = 1;   // params

        VkDescriptorPoolCreateInfo ci{};
        ci.sType         = VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO;
        ci.poolSizeCount = (uint32_t)sizes.size();
        ci.pPoolSizes    = sizes.data();
        ci.maxSets       = 1;
        if (vkCreateDescriptorPool(m_device, &ci, nullptr, &m_descPool) != VK_SUCCESS)
            throw std::runtime_error("vkCreateDescriptorPool failed");
    }

    void createDescriptorSet() {
        VkDescriptorSetAllocateInfo ai{};
        ai.sType              = VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO;
        ai.descriptorPool     = m_descPool;
        ai.descriptorSetCount = 1;
        ai.pSetLayouts        = &m_descSetLayout;
        if (vkAllocateDescriptorSets(m_device, &ai, &m_descSet) != VK_SUCCESS)
            throw std::runtime_error("vkAllocateDescriptorSets failed");

        VkDescriptorBufferInfo posInfo{};
        posInfo.buffer = m_posBuffer;
        posInfo.offset = 0;
        posInfo.range  = VK_WHOLE_SIZE;

        VkDescriptorBufferInfo colInfo{};
        colInfo.buffer = m_colBuffer;
        colInfo.offset = 0;
        colInfo.range  = VK_WHOLE_SIZE;

        VkDescriptorBufferInfo uboInfo{};
        uboInfo.buffer = m_uniformBuffer;
        uboInfo.offset = 0;
        uboInfo.range  = sizeof(HarmonographParams);

        std::array<VkWriteDescriptorSet, 3> writes{};
        writes[0].sType           = VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET;
        writes[0].dstSet          = m_descSet;
        writes[0].dstBinding      = 0;
        writes[0].descriptorType  = VK_DESCRIPTOR_TYPE_STORAGE_BUFFER;
        writes[0].descriptorCount = 1;
        writes[0].pBufferInfo     = &posInfo;

        writes[1].sType           = VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET;
        writes[1].dstSet          = m_descSet;
        writes[1].dstBinding      = 1;
        writes[1].descriptorType  = VK_DESCRIPTOR_TYPE_STORAGE_BUFFER;
        writes[1].descriptorCount = 1;
        writes[1].pBufferInfo     = &colInfo;

        writes[2].sType           = VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET;
        writes[2].dstSet          = m_descSet;
        writes[2].dstBinding      = 2;
        writes[2].descriptorType  = VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER;
        writes[2].descriptorCount = 1;
        writes[2].pBufferInfo     = &uboInfo;

        vkUpdateDescriptorSets(m_device, (uint32_t)writes.size(), writes.data(), 0, nullptr);
    }

    // =========================================================================
    // allocateCommandBuffers  Ñü one command buffer per frame-in-flight
    //
    // The C/C# reference uses g_cmd[MAX_FRAMES_IN_FLIGHT] indexed by frameIndex.
    // We follow the same pattern: allocate MAX_FRAMES buffers, not one per
    // swapchain image, so drawFrame can index by m_currentFrame.
    // =========================================================================
    void allocateCommandBuffers() {
        m_cmdBuffers.resize(MAX_FRAMES);

        VkCommandBufferAllocateInfo ai{};
        ai.sType              = VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO;
        ai.commandPool        = m_cmdPool;
        ai.level              = VK_COMMAND_BUFFER_LEVEL_PRIMARY;
        ai.commandBufferCount = MAX_FRAMES;
        if (vkAllocateCommandBuffers(m_device, &ai, m_cmdBuffers.data()) != VK_SUCCESS)
            throw std::runtime_error("vkAllocateCommandBuffers failed");
    }

    // =========================================================================
    // recordCommandBuffer
    //
    // Called every frame.  A single command buffer contains:
    //   1. Compute dispatch  (recompute ALL VERTEX_COUNT positions + colors)
    //   2. Pipeline barrier  (COMPUTE WRITE Å® VERTEX READ)
    //   3. Render pass       (LINE_STRIP draw of all VERTEX_COUNT vertices)
    // =========================================================================
    void recordCommandBuffer(VkCommandBuffer cmd, uint32_t imageIdx) {
        vkResetCommandBuffer(cmd, 0);

        VkCommandBufferBeginInfo bi{};
        bi.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO;
        vkBeginCommandBuffer(cmd, &bi);

        // ÑüÑü 1. Compute dispatch ÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑü
        vkCmdBindPipeline(cmd, VK_PIPELINE_BIND_POINT_COMPUTE, m_computePipeline);
        vkCmdBindDescriptorSets(cmd, VK_PIPELINE_BIND_POINT_COMPUTE,
            m_computeLayout, 0, 1, &m_descSet, 0, nullptr);

        uint32_t groups = (VERTEX_COUNT + 255u) / 256u;
        vkCmdDispatch(cmd, groups, 1, 1);

        // ÑüÑü 2. Pipeline barrier: compute WRITE Å® vertex SHADER READ ÑüÑüÑüÑüÑüÑüÑüÑüÑü
        std::array<VkBufferMemoryBarrier, 2> barriers{};
        for (auto& b : barriers) {
            b.sType               = VK_STRUCTURE_TYPE_BUFFER_MEMORY_BARRIER;
            b.srcAccessMask       = VK_ACCESS_SHADER_WRITE_BIT;
            b.dstAccessMask       = VK_ACCESS_SHADER_READ_BIT;
            b.srcQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
            b.dstQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
            b.offset              = 0;
            b.size                = VK_WHOLE_SIZE;
        }
        barriers[0].buffer = m_posBuffer;
        barriers[1].buffer = m_colBuffer;

        vkCmdPipelineBarrier(cmd,
            VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT,
            VK_PIPELINE_STAGE_VERTEX_SHADER_BIT,
            0,
            0, nullptr,
            (uint32_t)barriers.size(), barriers.data(),
            0, nullptr);

        // ÑüÑü 3. Render pass ÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑü
        VkClearValue clearVal = { {{ 0.0f, 0.0f, 0.0f, 1.0f }} };  // pure black (matches reference)

        VkRenderPassBeginInfo rpBI{};
        rpBI.sType             = VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO;
        rpBI.renderPass        = m_renderPass;
        rpBI.framebuffer       = m_scFramebuffers[imageIdx];
        rpBI.renderArea.offset = { 0, 0 };
        rpBI.renderArea.extent = m_scExtent;
        rpBI.clearValueCount   = 1;
        rpBI.pClearValues      = &clearVal;

        vkCmdBeginRenderPass(cmd, &rpBI, VK_SUBPASS_CONTENTS_INLINE);

        vkCmdBindPipeline(cmd, VK_PIPELINE_BIND_POINT_GRAPHICS, m_graphicsPipeline);
        vkCmdBindDescriptorSets(cmd, VK_PIPELINE_BIND_POINT_GRAPHICS,
            m_graphicsLayout, 0, 1, &m_descSet, 0, nullptr);

        // Always draw all VERTEX_COUNT vertices as LINE_STRIP
        vkCmdDraw(cmd, VERTEX_COUNT, 1, 0, 0);

        vkCmdEndRenderPass(cmd);

        if (vkEndCommandBuffer(cmd) != VK_SUCCESS)
            throw std::runtime_error("vkEndCommandBuffer failed");
    }

    // =========================================================================
    // createSyncObjects
    // =========================================================================
    void createSyncObjects() {
        m_imageAvailSems.resize(MAX_FRAMES);
        m_renderDoneSems.resize(MAX_FRAMES);
        m_inFlightFences.resize(MAX_FRAMES);
        m_imagesInFlight.assign(m_scImages.size(), VK_NULL_HANDLE);

        VkSemaphoreCreateInfo semCI{};
        semCI.sType = VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO;
        VkFenceCreateInfo fenceCI{};
        fenceCI.sType = VK_STRUCTURE_TYPE_FENCE_CREATE_INFO;
        fenceCI.flags = VK_FENCE_CREATE_SIGNALED_BIT;

        for (int i = 0; i < MAX_FRAMES; i++) {
            if (vkCreateSemaphore(m_device, &semCI, nullptr, &m_imageAvailSems[i]) != VK_SUCCESS ||
                vkCreateSemaphore(m_device, &semCI, nullptr, &m_renderDoneSems[i]) != VK_SUCCESS ||
                vkCreateFence(m_device, &fenceCI, nullptr, &m_inFlightFences[i]) != VK_SUCCESS)
                throw std::runtime_error("Sync object creation failed");
        }
    }

    // =========================================================================
    // drawFrame
    //
    // Per-frame sequence matching the C and C# reference implementations:
    //   1. updateUBO()  ? advance animTime, modulate f1-f4, drift p1
    //   2. Acquire swapchain image
    //   3. Re-record command buffer (compute dispatch + draw)
    //   4. Submit + present
    // =========================================================================
    void drawFrame() {
        // ÑüÑü 1. Update animation parameters ÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑü
        updateUBO();

        // ÑüÑü 2. Vulkan frame synchronization ÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑü
        vkWaitForFences(m_device, 1, &m_inFlightFences[m_currentFrame], VK_TRUE, UINT64_MAX);

        uint32_t imageIdx;
        VkResult result = vkAcquireNextImageKHR(
            m_device, m_swapChain, UINT64_MAX,
            m_imageAvailSems[m_currentFrame], VK_NULL_HANDLE, &imageIdx);

        if (result == VK_ERROR_OUT_OF_DATE_KHR) { recreateSwapChain(); return; }
        if (result != VK_SUCCESS && result != VK_SUBOPTIMAL_KHR)
            throw std::runtime_error("vkAcquireNextImageKHR failed");

        if (m_imagesInFlight[imageIdx] != VK_NULL_HANDLE)
            vkWaitForFences(m_device, 1, &m_imagesInFlight[imageIdx], VK_TRUE, UINT64_MAX);
        m_imagesInFlight[imageIdx] = m_inFlightFences[m_currentFrame];

        // ÑüÑü 3. Re-record command buffer ÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑü
        recordCommandBuffer(m_cmdBuffers[m_currentFrame], imageIdx);

        // ÑüÑü 4. Submit ÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑü
        VkPipelineStageFlags waitStage = VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT;

        VkSubmitInfo si{};
        si.sType                = VK_STRUCTURE_TYPE_SUBMIT_INFO;
        si.waitSemaphoreCount   = 1;
        si.pWaitSemaphores      = &m_imageAvailSems[m_currentFrame];
        si.pWaitDstStageMask    = &waitStage;
        si.commandBufferCount   = 1;
        si.pCommandBuffers      = &m_cmdBuffers[m_currentFrame];
        si.signalSemaphoreCount = 1;
        si.pSignalSemaphores    = &m_renderDoneSems[m_currentFrame];

        vkResetFences(m_device, 1, &m_inFlightFences[m_currentFrame]);
        if (vkQueueSubmit(m_graphicsQueue, 1, &si, m_inFlightFences[m_currentFrame]) != VK_SUCCESS)
            throw std::runtime_error("vkQueueSubmit failed");

        // ÑüÑü 5. Present ÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑüÑü
        VkPresentInfoKHR pi{};
        pi.sType              = VK_STRUCTURE_TYPE_PRESENT_INFO_KHR;
        pi.waitSemaphoreCount = 1;
        pi.pWaitSemaphores    = &m_renderDoneSems[m_currentFrame];
        pi.swapchainCount     = 1;
        pi.pSwapchains        = &m_swapChain;
        pi.pImageIndices      = &imageIdx;

        result = vkQueuePresentKHR(m_presentQueue, &pi);
        if (result == VK_ERROR_OUT_OF_DATE_KHR || result == VK_SUBOPTIMAL_KHR || g_framebufferResized) {
            g_framebufferResized = false;
            recreateSwapChain();
        } else if (result != VK_SUCCESS) {
            throw std::runtime_error("vkQueuePresentKHR failed");
        }

        m_currentFrame = (m_currentFrame + 1) % MAX_FRAMES;
    }

    // =========================================================================
    // Swapchain recreation (window resize)
    // =========================================================================
    void cleanupSwapChain() {
        for (auto fb : m_scFramebuffers) vkDestroyFramebuffer(m_device, fb, nullptr);
        // Note: command buffers are NOT freed here; they are independent of the swapchain
        // and are freed only in cleanup() via vkDestroyCommandPool.
        vkDestroyPipeline(m_device, m_graphicsPipeline, nullptr);
        vkDestroyPipelineLayout(m_device, m_graphicsLayout, nullptr);
        vkDestroyRenderPass(m_device, m_renderPass, nullptr);
        for (auto iv : m_scImageViews) vkDestroyImageView(m_device, iv, nullptr);
        vkDestroySwapchainKHR(m_device, m_swapChain, nullptr);
    }

    void recreateSwapChain() {
        // Wait while window is minimized
        RECT rc;
        GetClientRect(m_hwnd, &rc);
        while (rc.right == 0 || rc.bottom == 0) {
            Sleep(10);
            GetClientRect(m_hwnd, &rc);
        }
        vkDeviceWaitIdle(m_device);

        cleanupSwapChain();
        createSwapChain();
        createImageViews();
        createRenderPass();
        createGraphicsPipeline();
        createFramebuffers();
        // Command buffers are reused (re-recorded each frame); no re-allocation needed

        m_imagesInFlight.assign(m_scImages.size(), VK_NULL_HANDLE);
    }

    // =========================================================================
    // cleanup  Ñü release all Vulkan / Win32 resources
    // =========================================================================
    void cleanup() {
        cleanupSwapChain();

        // Compute pipeline
        vkDestroyPipeline(m_device, m_computePipeline, nullptr);
        vkDestroyPipelineLayout(m_device, m_computeLayout, nullptr);

        // Descriptors
        vkDestroyDescriptorPool(m_device, m_descPool, nullptr);
        vkDestroyDescriptorSetLayout(m_device, m_descSetLayout, nullptr);

        // Buffers
        vkDestroyBuffer(m_device, m_posBuffer, nullptr);
        vkFreeMemory(m_device,    m_posMem,    nullptr);
        vkDestroyBuffer(m_device, m_colBuffer, nullptr);
        vkFreeMemory(m_device,    m_colMem,    nullptr);
        vkDestroyBuffer(m_device, m_uniformBuffer, nullptr);
        vkFreeMemory(m_device,    m_uniformMem,    nullptr);

        // Sync objects
        for (int i = 0; i < MAX_FRAMES; i++) {
            vkDestroySemaphore(m_device, m_imageAvailSems[i], nullptr);
            vkDestroySemaphore(m_device, m_renderDoneSems[i], nullptr);
            vkDestroyFence(m_device,    m_inFlightFences[i], nullptr);
        }

        vkDestroyCommandPool(m_device, m_cmdPool, nullptr);
        vkDestroyDevice(m_device, nullptr);
        if (kEnableValidation)
            DestroyDebugUtilsMessengerEXT(m_instance, m_debugMessenger, nullptr);
        vkDestroySurfaceKHR(m_instance, m_surface, nullptr);
        vkDestroyInstance(m_instance, nullptr);

        DestroyWindow(m_hwnd);
        UnregisterClass(_T("VkHarmonograph"), m_hInst);
    }

    // =========================================================================
    // Utility helpers
    // =========================================================================
    VkShaderModule createShaderModule(const std::vector<uint32_t>& spv) {
        VkShaderModuleCreateInfo ci{};
        ci.sType    = VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO;
        ci.codeSize = spv.size() * sizeof(uint32_t);
        ci.pCode    = spv.data();
        VkShaderModule mod;
        if (vkCreateShaderModule(m_device, &ci, nullptr, &mod) != VK_SUCCESS)
            throw std::runtime_error("vkCreateShaderModule failed");
        return mod;
    }

    // Find queue families (graphics + present + compute).
    // On most desktop GPUs a single family satisfies all three; this loop
    // will use it for all three roles to minimize queue count.
    QueueFamilyIndices findQueueFamilies(VkPhysicalDevice d) {
        QueueFamilyIndices idx;
        uint32_t cnt = 0;
        vkGetPhysicalDeviceQueueFamilyProperties(d, &cnt, nullptr);
        std::vector<VkQueueFamilyProperties> fams(cnt);
        vkGetPhysicalDeviceQueueFamilyProperties(d, &cnt, fams.data());

        for (uint32_t i = 0; i < cnt; i++) {
            VkBool32 presentOk = VK_FALSE;
            vkGetPhysicalDeviceSurfaceSupportKHR(d, i, m_surface, &presentOk);

            bool hasGraphics = (fams[i].queueFlags & VK_QUEUE_GRAPHICS_BIT) != 0;
            bool hasCompute  = (fams[i].queueFlags & VK_QUEUE_COMPUTE_BIT)  != 0;

            if (hasGraphics)  idx.graphicsFamily = i;
            if (hasCompute)   idx.computeFamily  = i;
            if (presentOk)    idx.presentFamily  = i;

            // Prefer a family that supports both graphics and compute
            if (hasGraphics && hasCompute) {
                idx.graphicsFamily = i;
                idx.computeFamily  = i;
            }

            if (idx.isComplete()) break;
        }
        return idx;
    }

    bool checkDeviceExtensionSupport(VkPhysicalDevice d) {
        uint32_t cnt;
        vkEnumerateDeviceExtensionProperties(d, nullptr, &cnt, nullptr);
        std::vector<VkExtensionProperties> exts(cnt);
        vkEnumerateDeviceExtensionProperties(d, nullptr, &cnt, exts.data());
        std::set<std::string> needed(kDeviceExtensions.begin(), kDeviceExtensions.end());
        for (const auto& e : exts) needed.erase(e.extensionName);
        return needed.empty();
    }

    SwapChainSupport querySwapChainSupport(VkPhysicalDevice d) {
        SwapChainSupport sc;
        vkGetPhysicalDeviceSurfaceCapabilitiesKHR(d, m_surface, &sc.capabilities);
        uint32_t n;
        vkGetPhysicalDeviceSurfaceFormatsKHR(d, m_surface, &n, nullptr);
        if (n) { sc.formats.resize(n); vkGetPhysicalDeviceSurfaceFormatsKHR(d, m_surface, &n, sc.formats.data()); }
        vkGetPhysicalDeviceSurfacePresentModesKHR(d, m_surface, &n, nullptr);
        if (n) { sc.presentModes.resize(n); vkGetPhysicalDeviceSurfacePresentModesKHR(d, m_surface, &n, sc.presentModes.data()); }
        return sc;
    }

    VkSurfaceFormatKHR chooseSurfaceFormat(const std::vector<VkSurfaceFormatKHR>& fmts) {
        for (const auto& f : fmts)
            if (f.format == VK_FORMAT_B8G8R8A8_SRGB &&
                f.colorSpace == VK_COLOR_SPACE_SRGB_NONLINEAR_KHR) return f;
        return fmts[0];
    }

    VkPresentModeKHR choosePresentMode(const std::vector<VkPresentModeKHR>& modes) {
        for (auto m : modes) if (m == VK_PRESENT_MODE_MAILBOX_KHR) return m;
        return VK_PRESENT_MODE_FIFO_KHR;
    }

    VkExtent2D chooseExtent(const VkSurfaceCapabilitiesKHR& cap) {
        if (cap.currentExtent.width != UINT32_MAX) return cap.currentExtent;
        RECT rc; GetClientRect(m_hwnd, &rc);
        return {
            std::max(cap.minImageExtent.width,  std::min(cap.maxImageExtent.width,  (uint32_t)(rc.right  - rc.left))),
            std::max(cap.minImageExtent.height, std::min(cap.maxImageExtent.height, (uint32_t)(rc.bottom - rc.top)))
        };
    }

    std::vector<const char*> getRequiredExtensions() {
        std::vector<const char*> v = {
            VK_KHR_SURFACE_EXTENSION_NAME,
            VK_KHR_WIN32_SURFACE_EXTENSION_NAME
        };
        if (kEnableValidation) v.push_back(VK_EXT_DEBUG_UTILS_EXTENSION_NAME);
        return v;
    }

    bool checkValidationLayerSupport() {
        uint32_t cnt;
        vkEnumerateInstanceLayerProperties(&cnt, nullptr);
        std::vector<VkLayerProperties> layers(cnt);
        vkEnumerateInstanceLayerProperties(&cnt, layers.data());
        for (const char* name : kValidationLayers) {
            bool found = false;
            for (const auto& l : layers)
                if (strcmp(name, l.layerName) == 0) { found = true; break; }
            if (!found) return false;
        }
        return true;
    }

    static VKAPI_ATTR VkBool32 VKAPI_CALL debugCallback(
        VkDebugUtilsMessageSeverityFlagBitsEXT,
        VkDebugUtilsMessageTypeFlagsEXT,
        const VkDebugUtilsMessengerCallbackDataEXT* data,
        void*)
    {
        OutputDebugStringA("VK: ");
        OutputDebugStringA(data->pMessage);
        OutputDebugStringA("\n");
        return VK_FALSE;
    }
};

// ============================================================================
// Unmanaged entry point
// ============================================================================
static int HarmonographMain() {
    HarmonographApp app;
    try {
        app.run();
    }
    catch (const std::exception& e) {
        MessageBoxA(nullptr, e.what(), "Harmonograph Error", MB_OK | MB_ICONERROR);
        return EXIT_FAILURE;
    }
    return EXIT_SUCCESS;
}

#pragma managed(pop)

// ============================================================================
// C++/CLI managed entry point  (WinMain)
// ============================================================================
int APIENTRY _tWinMain(HINSTANCE, HINSTANCE, LPTSTR, int) {
    return HarmonographMain();
}
