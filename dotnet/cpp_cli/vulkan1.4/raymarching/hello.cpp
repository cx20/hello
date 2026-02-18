// hello_raymarching.cpp
// Vulkan 1.4 Ray Marching Sample for C++/CLI (Win32 API - Runtime Shader Compilation)
//
// Features:
//   - Animated SDF shapes (sphere, torus, ground plane)
//   - Soft shadows, ambient occlusion, fog
//   - Push constants for iTime and iResolution
//   - Full-screen triangle rendering
//   - Runtime GLSL->SPIR-V compilation via shaderc
//
// Compilation:
//   cl hello_raymarching.cpp /clr /std:c++20 /EHa ^
//       /link user32.lib gdi32.lib vulkan-1.lib shaderc_combined.lib ^
//       /SUBSYSTEM:WINDOWS
//
// Runtime requirements:
//   hello.vert and hello.frag must exist in the working directory.

// ============================================================================
// All Vulkan / Win32 code must be compiled as unmanaged (native) C++
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

#include <iostream>
#include <fstream>
#include <stdexcept>
#include <algorithm>
#include <vector>
#include <cstring>
#include <cstdlib>
#include <cstdint>
#include <optional>
#include <set>
#include <string>

// ---------------------------------------------------------------------------
// Window / swap-chain dimensions
// ---------------------------------------------------------------------------
const uint32_t WIDTH  = 800;
const uint32_t HEIGHT = 600;
const int      MAX_FRAMES_IN_FLIGHT = 2;

// ---------------------------------------------------------------------------
// Push-constant layout must exactly match the shader declaration:
//
//   layout(push_constant) uniform PushConstants {
//       float iTime;
//       float padding;
//       vec2  iResolution;
//   } pc;
// ---------------------------------------------------------------------------
struct PushConstantsData {
    float iTime;
    float padding;      // keeps iResolution 8-byte aligned
    float iResolutionX;
    float iResolutionY;
};

// ============================================================================
// ShaderCompiler - wraps shaderc for GLSL -> SPIR-V conversion at runtime
// ============================================================================
class ShaderCompiler {
public:
    static std::vector<uint32_t> compileGLSL(
        const std::string& source,
        shaderc_shader_kind kind,
        const char* name)
    {
        shaderc::Compiler       compiler;
        shaderc::CompileOptions options;
        options.SetOptimizationLevel(shaderc_optimization_level_performance);

        auto result = compiler.CompileGlslToSpv(source, kind, name, options);
        if (result.GetCompilationStatus() != shaderc_compilation_status_success) {
            throw std::runtime_error(
                std::string("Shader compilation failed: ") + result.GetErrorMessage());
        }
        return { result.cbegin(), result.cend() };
    }

    static std::vector<uint32_t> compileVertexShader(const std::string& src) {
        return compileGLSL(src, shaderc_glsl_vertex_shader,   "vertex_shader");
    }
    static std::vector<uint32_t> compileFragmentShader(const std::string& src) {
        return compileGLSL(src, shaderc_glsl_fragment_shader, "fragment_shader");
    }
};

// ============================================================================
// Validation layers / device extensions
// ============================================================================
const std::vector<const char*> validationLayers = {
    "VK_LAYER_KHRONOS_validation"
};
const std::vector<const char*> deviceExtensions = {
    VK_KHR_SWAPCHAIN_EXTENSION_NAME
};

#ifdef NDEBUG
const bool enableValidationLayers = false;
#else
const bool enableValidationLayers = true;
#endif

// ---------------------------------------------------------------------------
// Debug messenger helpers
// ---------------------------------------------------------------------------
VkResult CreateDebugUtilsMessengerEXT(
    VkInstance instance,
    const VkDebugUtilsMessengerCreateInfoEXT* pCreateInfo,
    const VkAllocationCallbacks* pAllocator,
    VkDebugUtilsMessengerEXT* pDebugMessenger)
{
    auto func = (PFN_vkCreateDebugUtilsMessengerEXT)
        vkGetInstanceProcAddr(instance, "vkCreateDebugUtilsMessengerEXT");
    return func ? func(instance, pCreateInfo, pAllocator, pDebugMessenger)
                : VK_ERROR_EXTENSION_NOT_PRESENT;
}

void DestroyDebugUtilsMessengerEXT(
    VkInstance instance,
    VkDebugUtilsMessengerEXT debugMessenger,
    const VkAllocationCallbacks* pAllocator)
{
    auto func = (PFN_vkDestroyDebugUtilsMessengerEXT)
        vkGetInstanceProcAddr(instance, "vkDestroyDebugUtilsMessengerEXT");
    if (func) func(instance, debugMessenger, pAllocator);
}

// ---------------------------------------------------------------------------
// Queue-family / swap-chain support structs
// ---------------------------------------------------------------------------
struct QueueFamilyIndices {
    std::optional<uint32_t> graphicsFamily;
    std::optional<uint32_t> presentFamily;
    bool isComplete() const {
        return graphicsFamily.has_value() && presentFamily.has_value();
    }
};

struct SwapChainSupportDetails {
    VkSurfaceCapabilitiesKHR        capabilities;
    std::vector<VkSurfaceFormatKHR> formats;
    std::vector<VkPresentModeKHR>   presentModes;
};

// ---------------------------------------------------------------------------
// Global state used by the window procedure
// ---------------------------------------------------------------------------
static bool g_framebufferResized = false;
static bool g_running            = true;

// ============================================================================
// Main application class
// ============================================================================
class RayMarchingApplication {
public:
    void run() {
        initWindow();
        initVulkan();
        mainLoop();
        cleanup();
    }

private:
    // ---- Win32 ----
    HWND      hwnd;
    HINSTANCE hInstance;

    // ---- Vulkan core ----
    VkInstance               instance;
    VkDebugUtilsMessengerEXT debugMessenger;
    VkSurfaceKHR             surface;
    VkPhysicalDevice         physicalDevice = VK_NULL_HANDLE;
    VkDevice                 device;
    VkQueue                  graphicsQueue;
    VkQueue                  presentQueue;

    // ---- Swap chain ----
    VkSwapchainKHR             swapChain;
    std::vector<VkImage>       swapChainImages;
    VkFormat                   swapChainImageFormat;
    VkExtent2D                 swapChainExtent;
    std::vector<VkImageView>   swapChainImageViews;
    std::vector<VkFramebuffer> swapChainFramebuffers;

    // ---- Pipeline ----
    VkRenderPass     renderPass;
    VkPipelineLayout pipelineLayout;
    VkPipeline       graphicsPipeline;

    // ---- Commands ----
    VkCommandPool                commandPool;
    std::vector<VkCommandBuffer> commandBuffers;

    // ---- Synchronisation ----
    std::vector<VkSemaphore> imageAvailableSemaphores;
    std::vector<VkSemaphore> renderFinishedSemaphores;
    std::vector<VkFence>     inFlightFences;
    std::vector<VkFence>     imagesInFlight;
    size_t                   currentFrame = 0;

    // ---- Timing (for iTime) ----
    LARGE_INTEGER perfFreq;
    LARGE_INTEGER startTime;

    // ============================================================
    // Window
    // ============================================================
    static LRESULT CALLBACK WindowProc(HWND hWnd, UINT uMsg, WPARAM wParam, LPARAM lParam) {
        switch (uMsg) {
        case WM_SIZE:
            g_framebufferResized = true;
            return 0;
        case WM_CLOSE:
            g_running = false;
            DestroyWindow(hWnd);
            return 0;
        case WM_DESTROY:
            PostQuitMessage(0);
            return 0;
        }
        return DefWindowProc(hWnd, uMsg, wParam, lParam);
    }

    void initWindow() {
        hInstance = GetModuleHandle(nullptr);

        WNDCLASSEX wc   = {};
        wc.cbSize       = sizeof(WNDCLASSEX);
        wc.style        = CS_HREDRAW | CS_VREDRAW;
        wc.lpfnWndProc  = WindowProc;
        wc.hInstance    = hInstance;
        wc.hCursor      = LoadCursor(nullptr, IDC_ARROW);
        wc.lpszClassName = _T("VulkanRayMarchClass");

        if (!RegisterClassEx(&wc))
            throw std::runtime_error("Failed to register window class!");

        RECT r = { 0, 0, (LONG)WIDTH, (LONG)HEIGHT };
        AdjustWindowRect(&r, WS_OVERLAPPEDWINDOW, FALSE);

        hwnd = CreateWindowEx(
            0, _T("VulkanRayMarchClass"),
            _T("Vulkan Ray Marching (C++/CLI)"),
            WS_OVERLAPPEDWINDOW,
            CW_USEDEFAULT, CW_USEDEFAULT,
            r.right - r.left, r.bottom - r.top,
            nullptr, nullptr, hInstance, nullptr);

        if (!hwnd)
            throw std::runtime_error("Failed to create window!");

        ShowWindow(hwnd, SW_SHOW);
    }

    // ============================================================
    // Vulkan initialisation
    // ============================================================
    void initVulkan() {
        // Initialise high-resolution timer
        QueryPerformanceFrequency(&perfFreq);
        QueryPerformanceCounter(&startTime);

        createInstance();
        setupDebugMessenger();
        createSurface();
        pickPhysicalDevice();
        createLogicalDevice();
        createSwapChain();
        createImageViews();
        createRenderPass();
        createGraphicsPipeline();
        createFramebuffers();
        createCommandPool();
        createCommandBuffers();
        createSyncObjects();
    }

    // ============================================================
    // Main loop - update push constants every frame
    // ============================================================
    void mainLoop() {
        MSG msg = {};
        while (g_running) {
            while (PeekMessage(&msg, nullptr, 0, 0, PM_REMOVE)) {
                TranslateMessage(&msg);
                DispatchMessage(&msg);
                if (msg.message == WM_QUIT) g_running = false;
            }
            if (g_running) drawFrame();
        }
        vkDeviceWaitIdle(device);
    }

    // ============================================================
    // Resource helpers
    // ============================================================
    static std::string readFile(const std::string& filename) {
        std::ifstream file(filename, std::ios::ate | std::ios::binary);
        if (!file.is_open())
            throw std::runtime_error("Failed to open file: " + filename);
        size_t size = (size_t)file.tellg();
        std::vector<char> buf(size);
        file.seekg(0);
        file.read(buf.data(), size);
        return { buf.begin(), buf.end() };
    }

    VkShaderModule createShaderModule(const std::vector<uint32_t>& code) {
        VkShaderModuleCreateInfo ci{};
        ci.sType    = VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO;
        ci.codeSize = code.size() * sizeof(uint32_t);
        ci.pCode    = code.data();
        VkShaderModule mod;
        if (vkCreateShaderModule(device, &ci, nullptr, &mod) != VK_SUCCESS)
            throw std::runtime_error("Failed to create shader module!");
        return mod;
    }

    // ============================================================
    // Swap-chain cleanup / recreation
    // ============================================================
    void cleanupSwapChain() {
        for (auto fb : swapChainFramebuffers)
            vkDestroyFramebuffer(device, fb, nullptr);

        vkFreeCommandBuffers(device, commandPool,
            static_cast<uint32_t>(commandBuffers.size()),
            commandBuffers.data());

        vkDestroyPipeline(device, graphicsPipeline, nullptr);
        vkDestroyPipelineLayout(device, pipelineLayout, nullptr);
        vkDestroyRenderPass(device, renderPass, nullptr);

        for (auto iv : swapChainImageViews)
            vkDestroyImageView(device, iv, nullptr);

        vkDestroySwapchainKHR(device, swapChain, nullptr);
    }

    void cleanup() {
        cleanupSwapChain();

        for (size_t i = 0; i < MAX_FRAMES_IN_FLIGHT; i++) {
            vkDestroySemaphore(device, renderFinishedSemaphores[i], nullptr);
            vkDestroySemaphore(device, imageAvailableSemaphores[i], nullptr);
            vkDestroyFence(device, inFlightFences[i], nullptr);
        }

        vkDestroyCommandPool(device, commandPool, nullptr);
        vkDestroyDevice(device, nullptr);

        if (enableValidationLayers)
            DestroyDebugUtilsMessengerEXT(instance, debugMessenger, nullptr);

        vkDestroySurfaceKHR(instance, surface, nullptr);
        vkDestroyInstance(instance, nullptr);

        DestroyWindow(hwnd);
        UnregisterClass(_T("VulkanRayMarchClass"), hInstance);
    }

    void recreateSwapChain() {
        // Wait until window is not minimised
        RECT r;
        GetClientRect(hwnd, &r);
        while ((r.right - r.left) == 0 || (r.bottom - r.top) == 0) {
            GetClientRect(hwnd, &r);
            MSG msg;
            if (GetMessage(&msg, nullptr, 0, 0)) {
                TranslateMessage(&msg);
                DispatchMessage(&msg);
            }
        }

        vkDeviceWaitIdle(device);
        cleanupSwapChain();

        createSwapChain();
        createImageViews();
        createRenderPass();
        createGraphicsPipeline();
        createFramebuffers();
        createCommandBuffers();

        imagesInFlight.assign(swapChainImages.size(), VK_NULL_HANDLE);
    }

    // ============================================================
    // Vulkan object creation
    // ============================================================
    void createInstance() {
        if (enableValidationLayers && !checkValidationLayerSupport())
            throw std::runtime_error("Validation layers requested, but not available!");

        VkApplicationInfo appInfo{};
        appInfo.sType              = VK_STRUCTURE_TYPE_APPLICATION_INFO;
        appInfo.pApplicationName   = "Vulkan Ray Marching";
        appInfo.applicationVersion = VK_MAKE_VERSION(1, 0, 0);
        appInfo.pEngineName        = "No Engine";
        appInfo.engineVersion      = VK_MAKE_VERSION(1, 0, 0);
        appInfo.apiVersion         = VK_API_VERSION_1_4;   // Vulkan 1.4

        VkInstanceCreateInfo ci{};
        ci.sType            = VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO;
        ci.pApplicationInfo = &appInfo;

        auto exts = getRequiredExtensions();
        ci.enabledExtensionCount   = static_cast<uint32_t>(exts.size());
        ci.ppEnabledExtensionNames = exts.data();

        VkDebugUtilsMessengerCreateInfoEXT dbgInfo{};
        if (enableValidationLayers) {
            ci.enabledLayerCount   = static_cast<uint32_t>(validationLayers.size());
            ci.ppEnabledLayerNames = validationLayers.data();
            populateDebugMessengerCreateInfo(dbgInfo);
            ci.pNext = &dbgInfo;
        }

        if (vkCreateInstance(&ci, nullptr, &instance) != VK_SUCCESS)
            throw std::runtime_error("Failed to create Vulkan instance!");
    }

    void populateDebugMessengerCreateInfo(VkDebugUtilsMessengerCreateInfoEXT& ci) {
        ci = {};
        ci.sType           = VK_STRUCTURE_TYPE_DEBUG_UTILS_MESSENGER_CREATE_INFO_EXT;
        ci.messageSeverity = VK_DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT |
                             VK_DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT;
        ci.messageType     = VK_DEBUG_UTILS_MESSAGE_TYPE_GENERAL_BIT_EXT    |
                             VK_DEBUG_UTILS_MESSAGE_TYPE_VALIDATION_BIT_EXT  |
                             VK_DEBUG_UTILS_MESSAGE_TYPE_PERFORMANCE_BIT_EXT;
        ci.pfnUserCallback = debugCallback;
    }

    void setupDebugMessenger() {
        if (!enableValidationLayers) return;
        VkDebugUtilsMessengerCreateInfoEXT ci{};
        populateDebugMessengerCreateInfo(ci);
        if (CreateDebugUtilsMessengerEXT(instance, &ci, nullptr, &debugMessenger) != VK_SUCCESS)
            throw std::runtime_error("Failed to set up debug messenger!");
    }

    void createSurface() {
        VkWin32SurfaceCreateInfoKHR ci{};
        ci.sType     = VK_STRUCTURE_TYPE_WIN32_SURFACE_CREATE_INFO_KHR;
        ci.hwnd      = hwnd;
        ci.hinstance = hInstance;
        if (vkCreateWin32SurfaceKHR(instance, &ci, nullptr, &surface) != VK_SUCCESS)
            throw std::runtime_error("Failed to create window surface!");
    }

    void pickPhysicalDevice() {
        uint32_t count = 0;
        vkEnumeratePhysicalDevices(instance, &count, nullptr);
        if (count == 0)
            throw std::runtime_error("No GPUs with Vulkan support found!");

        std::vector<VkPhysicalDevice> devices(count);
        vkEnumeratePhysicalDevices(instance, &count, devices.data());

        for (const auto& dev : devices) {
            if (isDeviceSuitable(dev)) { physicalDevice = dev; break; }
        }
        if (physicalDevice == VK_NULL_HANDLE)
            throw std::runtime_error("Failed to find a suitable GPU!");
    }

    void createLogicalDevice() {
        auto indices = findQueueFamilies(physicalDevice);
        std::set<uint32_t> uniqueFamilies = {
            indices.graphicsFamily.value(), indices.presentFamily.value()
        };

        float priority = 1.0f;
        std::vector<VkDeviceQueueCreateInfo> queueCIs;
        for (uint32_t family : uniqueFamilies) {
            VkDeviceQueueCreateInfo qi{};
            qi.sType            = VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO;
            qi.queueFamilyIndex = family;
            qi.queueCount       = 1;
            qi.pQueuePriorities = &priority;
            queueCIs.push_back(qi);
        }

        VkPhysicalDeviceFeatures features{};
        VkDeviceCreateInfo ci{};
        ci.sType                   = VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO;
        ci.queueCreateInfoCount    = static_cast<uint32_t>(queueCIs.size());
        ci.pQueueCreateInfos       = queueCIs.data();
        ci.pEnabledFeatures        = &features;
        ci.enabledExtensionCount   = static_cast<uint32_t>(deviceExtensions.size());
        ci.ppEnabledExtensionNames = deviceExtensions.data();

        if (enableValidationLayers) {
            ci.enabledLayerCount   = static_cast<uint32_t>(validationLayers.size());
            ci.ppEnabledLayerNames = validationLayers.data();
        }

        if (vkCreateDevice(physicalDevice, &ci, nullptr, &device) != VK_SUCCESS)
            throw std::runtime_error("Failed to create logical device!");

        vkGetDeviceQueue(device, indices.graphicsFamily.value(), 0, &graphicsQueue);
        vkGetDeviceQueue(device, indices.presentFamily.value(),  0, &presentQueue);
    }

    void createSwapChain() {
        auto support      = querySwapChainSupport(physicalDevice);
        auto surfaceFormat = chooseSwapSurfaceFormat(support.formats);
        auto presentMode   = chooseSwapPresentMode(support.presentModes);
        auto extent        = chooseSwapExtent(support.capabilities);

        uint32_t imageCount = support.capabilities.minImageCount + 1;
        if (support.capabilities.maxImageCount > 0 &&
            imageCount > support.capabilities.maxImageCount)
            imageCount = support.capabilities.maxImageCount;

        VkSwapchainCreateInfoKHR ci{};
        ci.sType            = VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR;
        ci.surface          = surface;
        ci.minImageCount    = imageCount;
        ci.imageFormat      = surfaceFormat.format;
        ci.imageColorSpace  = surfaceFormat.colorSpace;
        ci.imageExtent      = extent;
        ci.imageArrayLayers = 1;
        ci.imageUsage       = VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT;

        auto indices = findQueueFamilies(physicalDevice);
        uint32_t families[] = { indices.graphicsFamily.value(), indices.presentFamily.value() };
        if (indices.graphicsFamily != indices.presentFamily) {
            ci.imageSharingMode      = VK_SHARING_MODE_CONCURRENT;
            ci.queueFamilyIndexCount = 2;
            ci.pQueueFamilyIndices   = families;
        } else {
            ci.imageSharingMode = VK_SHARING_MODE_EXCLUSIVE;
        }

        ci.preTransform   = support.capabilities.currentTransform;
        ci.compositeAlpha = VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR;
        ci.presentMode    = presentMode;
        ci.clipped        = VK_TRUE;

        if (vkCreateSwapchainKHR(device, &ci, nullptr, &swapChain) != VK_SUCCESS)
            throw std::runtime_error("Failed to create swap chain!");

        vkGetSwapchainImagesKHR(device, swapChain, &imageCount, nullptr);
        swapChainImages.resize(imageCount);
        vkGetSwapchainImagesKHR(device, swapChain, &imageCount, swapChainImages.data());

        swapChainImageFormat = surfaceFormat.format;
        swapChainExtent      = extent;
    }

    void createImageViews() {
        swapChainImageViews.resize(swapChainImages.size());
        for (size_t i = 0; i < swapChainImages.size(); i++) {
            VkImageViewCreateInfo ci{};
            ci.sType    = VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO;
            ci.image    = swapChainImages[i];
            ci.viewType = VK_IMAGE_VIEW_TYPE_2D;
            ci.format   = swapChainImageFormat;
            ci.components = { VK_COMPONENT_SWIZZLE_IDENTITY,
                              VK_COMPONENT_SWIZZLE_IDENTITY,
                              VK_COMPONENT_SWIZZLE_IDENTITY,
                              VK_COMPONENT_SWIZZLE_IDENTITY };
            ci.subresourceRange.aspectMask     = VK_IMAGE_ASPECT_COLOR_BIT;
            ci.subresourceRange.baseMipLevel   = 0;
            ci.subresourceRange.levelCount     = 1;
            ci.subresourceRange.baseArrayLayer = 0;
            ci.subresourceRange.layerCount     = 1;
            if (vkCreateImageView(device, &ci, nullptr, &swapChainImageViews[i]) != VK_SUCCESS)
                throw std::runtime_error("Failed to create image views!");
        }
    }

    void createRenderPass() {
        VkAttachmentDescription colorAttachment{};
        colorAttachment.format         = swapChainImageFormat;
        colorAttachment.samples        = VK_SAMPLE_COUNT_1_BIT;
        colorAttachment.loadOp         = VK_ATTACHMENT_LOAD_OP_CLEAR;
        colorAttachment.storeOp        = VK_ATTACHMENT_STORE_OP_STORE;
        colorAttachment.stencilLoadOp  = VK_ATTACHMENT_LOAD_OP_DONT_CARE;
        colorAttachment.stencilStoreOp = VK_ATTACHMENT_STORE_OP_DONT_CARE;
        colorAttachment.initialLayout  = VK_IMAGE_LAYOUT_UNDEFINED;
        colorAttachment.finalLayout    = VK_IMAGE_LAYOUT_PRESENT_SRC_KHR;

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
        ci.pAttachments    = &colorAttachment;
        ci.subpassCount    = 1;
        ci.pSubpasses      = &subpass;
        ci.dependencyCount = 1;
        ci.pDependencies   = &dep;

        if (vkCreateRenderPass(device, &ci, nullptr, &renderPass) != VK_SUCCESS)
            throw std::runtime_error("Failed to create render pass!");
    }

    // ----------------------------------------------------------------
    // Graphics pipeline - includes push-constant range for PushConstantsData
    // ----------------------------------------------------------------
    void createGraphicsPipeline() {
        // Load GLSL source and compile to SPIR-V at runtime
        std::string vertSrc = readFile("hello.vert");
        std::string fragSrc = readFile("hello.frag");

        auto vertSpirv = ShaderCompiler::compileVertexShader(vertSrc);
        auto fragSpirv = ShaderCompiler::compileFragmentShader(fragSrc);

        VkShaderModule vertMod = createShaderModule(vertSpirv);
        VkShaderModule fragMod = createShaderModule(fragSpirv);

        VkPipelineShaderStageCreateInfo vertStage{};
        vertStage.sType  = VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO;
        vertStage.stage  = VK_SHADER_STAGE_VERTEX_BIT;
        vertStage.module = vertMod;
        vertStage.pName  = "main";

        VkPipelineShaderStageCreateInfo fragStage{};
        fragStage.sType  = VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO;
        fragStage.stage  = VK_SHADER_STAGE_FRAGMENT_BIT;
        fragStage.module = fragMod;
        fragStage.pName  = "main";

        VkPipelineShaderStageCreateInfo stages[] = { vertStage, fragStage };

        // No vertex buffers - positions are generated in the vertex shader
        VkPipelineVertexInputStateCreateInfo vertexInput{};
        vertexInput.sType = VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO;

        VkPipelineInputAssemblyStateCreateInfo inputAssembly{};
        inputAssembly.sType    = VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO;
        inputAssembly.topology = VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST;

        VkViewport viewport{};
        viewport.width    = (float)swapChainExtent.width;
        viewport.height   = (float)swapChainExtent.height;
        viewport.maxDepth = 1.0f;

        VkRect2D scissor{};
        scissor.extent = swapChainExtent;

        VkPipelineViewportStateCreateInfo viewportState{};
        viewportState.sType         = VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO;
        viewportState.viewportCount = 1;
        viewportState.pViewports    = &viewport;
        viewportState.scissorCount  = 1;
        viewportState.pScissors     = &scissor;

        VkPipelineRasterizationStateCreateInfo rasterizer{};
        rasterizer.sType       = VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO;
        rasterizer.polygonMode = VK_POLYGON_MODE_FILL;
        rasterizer.cullMode    = VK_CULL_MODE_NONE;  // Full-screen triangle has no back face
        rasterizer.frontFace   = VK_FRONT_FACE_CLOCKWISE;
        rasterizer.lineWidth   = 1.0f;

        VkPipelineMultisampleStateCreateInfo multisampling{};
        multisampling.sType                = VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO;
        multisampling.rasterizationSamples = VK_SAMPLE_COUNT_1_BIT;

        VkPipelineColorBlendAttachmentState blendAttachment{};
        blendAttachment.colorWriteMask =
            VK_COLOR_COMPONENT_R_BIT | VK_COLOR_COMPONENT_G_BIT |
            VK_COLOR_COMPONENT_B_BIT | VK_COLOR_COMPONENT_A_BIT;

        VkPipelineColorBlendStateCreateInfo colorBlending{};
        colorBlending.sType           = VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO;
        colorBlending.attachmentCount = 1;
        colorBlending.pAttachments    = &blendAttachment;

        // Push-constant range covers the entire PushConstantsData struct
        VkPushConstantRange pushRange{};
        pushRange.stageFlags = VK_SHADER_STAGE_FRAGMENT_BIT;
        pushRange.offset     = 0;
        pushRange.size       = sizeof(PushConstantsData);

        VkPipelineLayoutCreateInfo layoutCI{};
        layoutCI.sType                  = VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO;
        layoutCI.pushConstantRangeCount = 1;
        layoutCI.pPushConstantRanges    = &pushRange;

        if (vkCreatePipelineLayout(device, &layoutCI, nullptr, &pipelineLayout) != VK_SUCCESS)
            throw std::runtime_error("Failed to create pipeline layout!");

        VkGraphicsPipelineCreateInfo pipelineCI{};
        pipelineCI.sType               = VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO;
        pipelineCI.stageCount          = 2;
        pipelineCI.pStages             = stages;
        pipelineCI.pVertexInputState   = &vertexInput;
        pipelineCI.pInputAssemblyState = &inputAssembly;
        pipelineCI.pViewportState      = &viewportState;
        pipelineCI.pRasterizationState = &rasterizer;
        pipelineCI.pMultisampleState   = &multisampling;
        pipelineCI.pColorBlendState    = &colorBlending;
        pipelineCI.layout              = pipelineLayout;
        pipelineCI.renderPass          = renderPass;
        pipelineCI.subpass             = 0;
        pipelineCI.basePipelineHandle  = VK_NULL_HANDLE;

        if (vkCreateGraphicsPipelines(device, VK_NULL_HANDLE, 1, &pipelineCI,
                                       nullptr, &graphicsPipeline) != VK_SUCCESS)
            throw std::runtime_error("Failed to create graphics pipeline!");

        vkDestroyShaderModule(device, fragMod, nullptr);
        vkDestroyShaderModule(device, vertMod, nullptr);
    }

    void createFramebuffers() {
        swapChainFramebuffers.resize(swapChainImageViews.size());
        for (size_t i = 0; i < swapChainImageViews.size(); i++) {
            VkFramebufferCreateInfo ci{};
            ci.sType           = VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO;
            ci.renderPass      = renderPass;
            ci.attachmentCount = 1;
            ci.pAttachments    = &swapChainImageViews[i];
            ci.width           = swapChainExtent.width;
            ci.height          = swapChainExtent.height;
            ci.layers          = 1;
            if (vkCreateFramebuffer(device, &ci, nullptr, &swapChainFramebuffers[i]) != VK_SUCCESS)
                throw std::runtime_error("Failed to create framebuffer!");
        }
    }

    // ----------------------------------------------------------------
    // Command pool - must allow per-buffer reset so we can re-record
    // push constants every frame without reallocating.
    // ----------------------------------------------------------------
    void createCommandPool() {
        auto indices = findQueueFamilies(physicalDevice);
        VkCommandPoolCreateInfo ci{};
        ci.sType            = VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO;
        ci.queueFamilyIndex = indices.graphicsFamily.value();
        // Allow individual command buffers to be reset and re-recorded
        ci.flags            = VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT;
        if (vkCreateCommandPool(device, &ci, nullptr, &commandPool) != VK_SUCCESS)
            throw std::runtime_error("Failed to create command pool!");
    }

    // Allocate one command buffer per swap-chain image
    void createCommandBuffers() {
        commandBuffers.resize(swapChainFramebuffers.size());
        VkCommandBufferAllocateInfo ai{};
        ai.sType              = VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO;
        ai.commandPool        = commandPool;
        ai.level              = VK_COMMAND_BUFFER_LEVEL_PRIMARY;
        ai.commandBufferCount = static_cast<uint32_t>(commandBuffers.size());
        if (vkAllocateCommandBuffers(device, &ai, commandBuffers.data()) != VK_SUCCESS)
            throw std::runtime_error("Failed to allocate command buffers!");
    }

    void createSyncObjects() {
        imageAvailableSemaphores.resize(MAX_FRAMES_IN_FLIGHT);
        renderFinishedSemaphores.resize(MAX_FRAMES_IN_FLIGHT);
        inFlightFences.resize(MAX_FRAMES_IN_FLIGHT);
        imagesInFlight.assign(swapChainImages.size(), VK_NULL_HANDLE);

        VkSemaphoreCreateInfo si{};
        si.sType = VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO;

        VkFenceCreateInfo fi{};
        fi.sType = VK_STRUCTURE_TYPE_FENCE_CREATE_INFO;
        fi.flags = VK_FENCE_CREATE_SIGNALED_BIT;

        for (size_t i = 0; i < MAX_FRAMES_IN_FLIGHT; i++) {
            if (vkCreateSemaphore(device, &si, nullptr, &imageAvailableSemaphores[i]) != VK_SUCCESS ||
                vkCreateSemaphore(device, &si, nullptr, &renderFinishedSemaphores[i]) != VK_SUCCESS ||
                vkCreateFence   (device, &fi, nullptr, &inFlightFences[i])            != VK_SUCCESS)
                throw std::runtime_error("Failed to create sync objects!");
        }
    }

    // ============================================================
    // Per-frame rendering - records push constants then draws
    // ============================================================
    void drawFrame() {
        vkWaitForFences(device, 1, &inFlightFences[currentFrame], VK_TRUE, UINT64_MAX);

        uint32_t imageIndex;
        VkResult result = vkAcquireNextImageKHR(
            device, swapChain, UINT64_MAX,
            imageAvailableSemaphores[currentFrame],
            VK_NULL_HANDLE, &imageIndex);

        if (result == VK_ERROR_OUT_OF_DATE_KHR) {
            recreateSwapChain();
            return;
        } else if (result != VK_SUCCESS && result != VK_SUBOPTIMAL_KHR) {
            throw std::runtime_error("Failed to acquire swap chain image!");
        }

        if (imagesInFlight[imageIndex] != VK_NULL_HANDLE)
            vkWaitForFences(device, 1, &imagesInFlight[imageIndex], VK_TRUE, UINT64_MAX);
        imagesInFlight[imageIndex] = inFlightFences[currentFrame];

        // ---- Build push constants for this frame ----
        LARGE_INTEGER now;
        QueryPerformanceCounter(&now);
        float elapsed = static_cast<float>(now.QuadPart - startTime.QuadPart) /
                        static_cast<float>(perfFreq.QuadPart);

        PushConstantsData pc{};
        pc.iTime        = elapsed;
        pc.padding      = 0.0f;
        pc.iResolutionX = static_cast<float>(swapChainExtent.width);
        pc.iResolutionY = static_cast<float>(swapChainExtent.height);

        // ---- Re-record the command buffer for this image ----
        auto cb = commandBuffers[imageIndex];

        // Reset and re-record - required because push constants change each frame
        vkResetCommandBuffer(cb, 0);

        VkCommandBufferBeginInfo beginInfo{};
        beginInfo.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO;
        if (vkBeginCommandBuffer(cb, &beginInfo) != VK_SUCCESS)
            throw std::runtime_error("Failed to begin recording command buffer!");

        VkRenderPassBeginInfo rpInfo{};
        rpInfo.sType             = VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO;
        rpInfo.renderPass        = renderPass;
        rpInfo.framebuffer       = swapChainFramebuffers[imageIndex];
        rpInfo.renderArea.offset = { 0, 0 };
        rpInfo.renderArea.extent = swapChainExtent;

        VkClearValue clearColor = { {{ 0.0f, 0.0f, 0.0f, 1.0f }} };
        rpInfo.clearValueCount  = 1;
        rpInfo.pClearValues     = &clearColor;

        vkCmdBeginRenderPass(cb, &rpInfo, VK_SUBPASS_CONTENTS_INLINE);

        vkCmdBindPipeline(cb, VK_PIPELINE_BIND_POINT_GRAPHICS, graphicsPipeline);

        // Upload iTime and iResolution to the fragment shader
        vkCmdPushConstants(cb, pipelineLayout,
            VK_SHADER_STAGE_FRAGMENT_BIT,
            0, sizeof(PushConstantsData), &pc);

        // Draw the full-screen triangle (3 vertices, no vertex buffer)
        vkCmdDraw(cb, 3, 1, 0, 0);

        vkCmdEndRenderPass(cb);

        if (vkEndCommandBuffer(cb) != VK_SUCCESS)
            throw std::runtime_error("Failed to record command buffer!");

        // ---- Submit ----
        VkSemaphore          waitSems[]   = { imageAvailableSemaphores[currentFrame] };
        VkPipelineStageFlags waitStages[] = { VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT };
        VkSemaphore          signalSems[] = { renderFinishedSemaphores[currentFrame] };

        VkSubmitInfo submitInfo{};
        submitInfo.sType                = VK_STRUCTURE_TYPE_SUBMIT_INFO;
        submitInfo.waitSemaphoreCount   = 1;
        submitInfo.pWaitSemaphores      = waitSems;
        submitInfo.pWaitDstStageMask    = waitStages;
        submitInfo.commandBufferCount   = 1;
        submitInfo.pCommandBuffers      = &cb;
        submitInfo.signalSemaphoreCount = 1;
        submitInfo.pSignalSemaphores    = signalSems;

        vkResetFences(device, 1, &inFlightFences[currentFrame]);
        if (vkQueueSubmit(graphicsQueue, 1, &submitInfo, inFlightFences[currentFrame]) != VK_SUCCESS)
            throw std::runtime_error("Failed to submit draw command buffer!");

        // ---- Present ----
        VkSwapchainKHR   swapChains[] = { swapChain };
        VkPresentInfoKHR presentInfo{};
        presentInfo.sType              = VK_STRUCTURE_TYPE_PRESENT_INFO_KHR;
        presentInfo.waitSemaphoreCount = 1;
        presentInfo.pWaitSemaphores    = signalSems;
        presentInfo.swapchainCount     = 1;
        presentInfo.pSwapchains        = swapChains;
        presentInfo.pImageIndices      = &imageIndex;

        result = vkQueuePresentKHR(presentQueue, &presentInfo);
        if (result == VK_ERROR_OUT_OF_DATE_KHR || result == VK_SUBOPTIMAL_KHR || g_framebufferResized) {
            g_framebufferResized = false;
            recreateSwapChain();
        } else if (result != VK_SUCCESS) {
            throw std::runtime_error("Failed to present swap chain image!");
        }

        currentFrame = (currentFrame + 1) % MAX_FRAMES_IN_FLIGHT;
    }

    // ============================================================
    // Device / swap-chain selection helpers
    // ============================================================
    VkSurfaceFormatKHR chooseSwapSurfaceFormat(
        const std::vector<VkSurfaceFormatKHR>& formats)
    {
        // Use UNORM (not SRGB) because the fragment shader already applies manual
        // gamma correction (pow(col, 0.4545)).  Choosing VK_FORMAT_*_SRGB would
        // cause the GPU to apply an additional automatic linear->sRGB conversion
        // on framebuffer write, resulting in double gamma correction and a
        // washed-out / overly bright image.
        for (const auto& f : formats)
            if (f.format == VK_FORMAT_B8G8R8A8_UNORM &&
                f.colorSpace == VK_COLOR_SPACE_SRGB_NONLINEAR_KHR)
                return f;
        // Fallback: prefer any UNORM variant over SRGB
        for (const auto& f : formats)
            if (f.format == VK_FORMAT_R8G8B8A8_UNORM &&
                f.colorSpace == VK_COLOR_SPACE_SRGB_NONLINEAR_KHR)
                return f;
        return formats[0];
    }

    VkPresentModeKHR chooseSwapPresentMode(
        const std::vector<VkPresentModeKHR>& modes)
    {
        for (const auto& m : modes)
            if (m == VK_PRESENT_MODE_MAILBOX_KHR) return m;
        return VK_PRESENT_MODE_FIFO_KHR;
    }

    VkExtent2D chooseSwapExtent(const VkSurfaceCapabilitiesKHR& caps) {
        if (caps.currentExtent.width != UINT32_MAX) return caps.currentExtent;
        RECT r;
        GetClientRect(hwnd, &r);
        VkExtent2D ext = {
            static_cast<uint32_t>(r.right - r.left),
            static_cast<uint32_t>(r.bottom - r.top)
        };
        ext.width  = std::max(caps.minImageExtent.width,  std::min(caps.maxImageExtent.width,  ext.width));
        ext.height = std::max(caps.minImageExtent.height, std::min(caps.maxImageExtent.height, ext.height));
        return ext;
    }

    SwapChainSupportDetails querySwapChainSupport(VkPhysicalDevice dev) {
        SwapChainSupportDetails d;
        vkGetPhysicalDeviceSurfaceCapabilitiesKHR(dev, surface, &d.capabilities);

        uint32_t fc = 0;
        vkGetPhysicalDeviceSurfaceFormatsKHR(dev, surface, &fc, nullptr);
        if (fc) { d.formats.resize(fc); vkGetPhysicalDeviceSurfaceFormatsKHR(dev, surface, &fc, d.formats.data()); }

        uint32_t pc = 0;
        vkGetPhysicalDeviceSurfacePresentModesKHR(dev, surface, &pc, nullptr);
        if (pc) { d.presentModes.resize(pc); vkGetPhysicalDeviceSurfacePresentModesKHR(dev, surface, &pc, d.presentModes.data()); }

        return d;
    }

    bool isDeviceSuitable(VkPhysicalDevice dev) {
        auto idx     = findQueueFamilies(dev);
        bool extOk   = checkDeviceExtensionSupport(dev);
        bool scOk    = false;
        if (extOk) {
            auto sc = querySwapChainSupport(dev);
            scOk = !sc.formats.empty() && !sc.presentModes.empty();
        }
        return idx.isComplete() && extOk && scOk;
    }

    bool checkDeviceExtensionSupport(VkPhysicalDevice dev) {
        uint32_t count = 0;
        vkEnumerateDeviceExtensionProperties(dev, nullptr, &count, nullptr);
        std::vector<VkExtensionProperties> available(count);
        vkEnumerateDeviceExtensionProperties(dev, nullptr, &count, available.data());

        std::set<std::string> required(deviceExtensions.begin(), deviceExtensions.end());
        for (const auto& ext : available) required.erase(ext.extensionName);
        return required.empty();
    }

    QueueFamilyIndices findQueueFamilies(VkPhysicalDevice dev) {
        QueueFamilyIndices idx;
        uint32_t count = 0;
        vkGetPhysicalDeviceQueueFamilyProperties(dev, &count, nullptr);
        std::vector<VkQueueFamilyProperties> families(count);
        vkGetPhysicalDeviceQueueFamilyProperties(dev, &count, families.data());

        for (uint32_t i = 0; i < count; i++) {
            if (families[i].queueFlags & VK_QUEUE_GRAPHICS_BIT) idx.graphicsFamily = i;
            VkBool32 present = false;
            vkGetPhysicalDeviceSurfaceSupportKHR(dev, i, surface, &present);
            if (present) idx.presentFamily = i;
            if (idx.isComplete()) break;
        }
        return idx;
    }

    std::vector<const char*> getRequiredExtensions() {
        std::vector<const char*> exts = {
            VK_KHR_SURFACE_EXTENSION_NAME,
            VK_KHR_WIN32_SURFACE_EXTENSION_NAME
        };
        if (enableValidationLayers) exts.push_back(VK_EXT_DEBUG_UTILS_EXTENSION_NAME);
        return exts;
    }

    bool checkValidationLayerSupport() {
        uint32_t count = 0;
        vkEnumerateInstanceLayerProperties(&count, nullptr);
        std::vector<VkLayerProperties> available(count);
        vkEnumerateInstanceLayerProperties(&count, available.data());
        for (const char* name : validationLayers) {
            bool found = false;
            for (const auto& p : available)
                if (strcmp(name, p.layerName) == 0) { found = true; break; }
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
        OutputDebugStringA("Vulkan: ");
        OutputDebugStringA(data->pMessage);
        OutputDebugStringA("\n");
        return VK_FALSE;
    }
};

// ============================================================================
// Unmanaged entry point
// ============================================================================
int VulkanMain() {
    RayMarchingApplication app;
    try {
        app.run();
    } catch (const std::exception& e) {
        MessageBoxA(nullptr, e.what(), "Error", MB_OK | MB_ICONERROR);
        return EXIT_FAILURE;
    }
    return EXIT_SUCCESS;
}

#pragma managed(pop)

// ============================================================================
// Managed (CLR) entry point - delegates immediately to native code
// ============================================================================
int APIENTRY _tWinMain(HINSTANCE, HINSTANCE, LPTSTR, int) {
    return VulkanMain();
}

