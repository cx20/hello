// hello_vulkan_rt.cpp
// Vulkan swapchain sample adapted from a simple GLFW triangle app,
// but rendering a triangle via Vulkan Ray Tracing (KHR) instead of rasterization.
//
// Single-file sample notes:
//   - No external .spv files are needed.
//   - GLSL ray tracing shaders are embedded below and compiled at runtime with shaderc.
//   - Requires a Vulkan SDK with ray tracing support and shaderc headers/libs.
//   - Requires a GPU/driver that supports:
//       VK_KHR_acceleration_structure
//       VK_KHR_ray_tracing_pipeline
//       VK_KHR_deferred_host_operations
//       bufferDeviceAddress
//
// Example build (Visual Studio Developer Command Prompt; adjust GLFW path as needed):
//   cl /EHsc /std:c++17 hello_vulkan_rt.cpp /I %VULKAN_SDK%\Include /I path\to\glfw\include ^
//      /link /LIBPATH:%VULKAN_SDK%\Lib path\to\glfw3.lib vulkan-1.lib shaderc_combined.lib user32.lib gdi32.lib shell32.lib advapi32.lib
//
// If you use GLFW from vcpkg, replace the GLFW include/lib paths accordingly.
//
// The sample traces primary rays against a single triangle BLAS/TLAS and writes the result to a storage image,
// then copies that image to the swapchain image for presentation.

#define GLFW_INCLUDE_VULKAN
#include <GLFW/glfw3.h>
#include <shaderc/shaderc.hpp>

#include <algorithm>
#include <array>
#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <fstream>
#include <iostream>
#include <optional>
#include <set>
#include <stdexcept>
#include <string>
#include <vector>

#ifdef _MSC_VER
#pragma comment(lib, "vulkan-1.lib")
#endif

const uint32_t WIDTH = 800;
const uint32_t HEIGHT = 600;
const int MAX_FRAMES_IN_FLIGHT = 2;

const std::vector<const char*> validationLayers = {
    "VK_LAYER_KHRONOS_validation"
};

const std::vector<const char*> deviceExtensions = {
    VK_KHR_SWAPCHAIN_EXTENSION_NAME,
    VK_KHR_DEFERRED_HOST_OPERATIONS_EXTENSION_NAME,
    VK_KHR_ACCELERATION_STRUCTURE_EXTENSION_NAME,
    VK_KHR_RAY_TRACING_PIPELINE_EXTENSION_NAME,
};

#ifdef NDEBUG
const bool enableValidationLayers = false;
#else
const bool enableValidationLayers = true;
#endif

#if defined(VK_API_VERSION_1_4)
static constexpr uint32_t APP_VK_API_VERSION = VK_API_VERSION_1_4;
#else
static constexpr uint32_t APP_VK_API_VERSION = VK_API_VERSION_1_2;
#endif

static const char* kRaygenShader = R"glsl(
#version 460
#extension GL_EXT_ray_tracing : require

layout(set = 0, binding = 0) uniform accelerationStructureEXT uTLAS;
layout(set = 0, binding = 1, rgba8) uniform image2D uOutput;
layout(location = 0) rayPayloadEXT vec3 payloadColor;

void main() {
    vec2 pixelCenter = vec2(gl_LaunchIDEXT.xy) + vec2(0.5);
    vec2 uv = pixelCenter / vec2(gl_LaunchSizeEXT.xy);
    vec2 d = uv * 2.0 - 1.0;

    vec3 origin = vec3(0.0, 0.0, -2.0);
    vec3 dir = normalize(vec3(d.x, -d.y, 1.5));

    payloadColor = vec3(0.0);

    traceRayEXT(
        uTLAS,
        gl_RayFlagsOpaqueEXT,
        0xFF,
        0,
        0,
        0,
        origin,
        0.001,
        dir,
        10000.0,
        0
    );

    imageStore(uOutput, ivec2(gl_LaunchIDEXT.xy), vec4(payloadColor, 1.0));
}
)glsl";

static const char* kMissShader = R"glsl(
#version 460
#extension GL_EXT_ray_tracing : require

layout(location = 0) rayPayloadInEXT vec3 payloadColor;

void main() {
    payloadColor = vec3(0.05, 0.08, 0.12);
}
)glsl";

static const char* kClosestHitShader = R"glsl(
#version 460
#extension GL_EXT_ray_tracing : require

layout(location = 0) rayPayloadInEXT vec3 payloadColor;
hitAttributeEXT vec2 attribs;

void main() {
    vec3 bary = vec3(1.0 - attribs.x - attribs.y, attribs.x, attribs.y);
    payloadColor = bary;
}
)glsl";

VkResult CreateDebugUtilsMessengerEXT(
    VkInstance instance,
    const VkDebugUtilsMessengerCreateInfoEXT* pCreateInfo,
    const VkAllocationCallbacks* pAllocator,
    VkDebugUtilsMessengerEXT* pDebugMessenger) {
    auto func = (PFN_vkCreateDebugUtilsMessengerEXT)vkGetInstanceProcAddr(instance, "vkCreateDebugUtilsMessengerEXT");
    if (func != nullptr) {
        return func(instance, pCreateInfo, pAllocator, pDebugMessenger);
    }
    return VK_ERROR_EXTENSION_NOT_PRESENT;
}

void DestroyDebugUtilsMessengerEXT(
    VkInstance instance,
    VkDebugUtilsMessengerEXT debugMessenger,
    const VkAllocationCallbacks* pAllocator) {
    auto func = (PFN_vkDestroyDebugUtilsMessengerEXT)vkGetInstanceProcAddr(instance, "vkDestroyDebugUtilsMessengerEXT");
    if (func != nullptr) {
        func(instance, debugMessenger, pAllocator);
    }
}

struct QueueFamilyIndices {
    std::optional<uint32_t> graphicsFamily;
    std::optional<uint32_t> presentFamily;

    bool isComplete() const {
        return graphicsFamily.has_value() && presentFamily.has_value();
    }
};

struct SwapChainSupportDetails {
    VkSurfaceCapabilitiesKHR capabilities{};
    std::vector<VkSurfaceFormatKHR> formats;
    std::vector<VkPresentModeKHR> presentModes;
};

struct Buffer {
    VkBuffer buffer = VK_NULL_HANDLE;
    VkDeviceMemory memory = VK_NULL_HANDLE;
    VkDeviceAddress address = 0;
    VkDeviceSize size = 0;
};

struct Image {
    VkImage image = VK_NULL_HANDLE;
    VkDeviceMemory memory = VK_NULL_HANDLE;
    VkImageView view = VK_NULL_HANDLE;
    VkFormat format = VK_FORMAT_UNDEFINED;
};

struct AccelerationStructure {
    VkAccelerationStructureKHR handle = VK_NULL_HANDLE;
    Buffer storage;
};

class HelloTriangleApplication {
public:
    void run() {
        initWindow();
        initVulkan();
        mainLoop();
        cleanup();
    }

private:
    GLFWwindow* window = nullptr;

    VkInstance instance = VK_NULL_HANDLE;
    VkDebugUtilsMessengerEXT debugMessenger = VK_NULL_HANDLE;
    VkSurfaceKHR surface = VK_NULL_HANDLE;

    VkPhysicalDevice physicalDevice = VK_NULL_HANDLE;
    VkDevice device = VK_NULL_HANDLE;

    VkQueue graphicsQueue = VK_NULL_HANDLE;
    VkQueue presentQueue = VK_NULL_HANDLE;

    VkSwapchainKHR swapChain = VK_NULL_HANDLE;
    std::vector<VkImage> swapChainImages;
    VkFormat swapChainImageFormat = VK_FORMAT_UNDEFINED;
    VkExtent2D swapChainExtent{};

    VkCommandPool commandPool = VK_NULL_HANDLE;
    std::vector<VkCommandBuffer> commandBuffers;

    std::vector<VkSemaphore> imageAvailableSemaphores;
    std::vector<VkSemaphore> renderFinishedSemaphores;
    std::vector<VkFence> inFlightFences;
    std::vector<VkFence> imagesInFlight;
    size_t currentFrame = 0;
    bool framebufferResized = false;

    VkPhysicalDeviceRayTracingPipelinePropertiesKHR rtPipelineProps{
        VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_RAY_TRACING_PIPELINE_PROPERTIES_KHR
    };
    VkPhysicalDeviceAccelerationStructurePropertiesKHR asProps{
        VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_ACCELERATION_STRUCTURE_PROPERTIES_KHR
    };

    PFN_vkCreateAccelerationStructureKHR fpCreateAccelerationStructureKHR = nullptr;
    PFN_vkDestroyAccelerationStructureKHR fpDestroyAccelerationStructureKHR = nullptr;
    PFN_vkGetAccelerationStructureBuildSizesKHR fpGetAccelerationStructureBuildSizesKHR = nullptr;
    PFN_vkCmdBuildAccelerationStructuresKHR fpCmdBuildAccelerationStructuresKHR = nullptr;
    PFN_vkGetAccelerationStructureDeviceAddressKHR fpGetAccelerationStructureDeviceAddressKHR = nullptr;
    PFN_vkCreateRayTracingPipelinesKHR fpCreateRayTracingPipelinesKHR = nullptr;
    PFN_vkGetRayTracingShaderGroupHandlesKHR fpGetRayTracingShaderGroupHandlesKHR = nullptr;
    PFN_vkCmdTraceRaysKHR fpCmdTraceRaysKHR = nullptr;

    Buffer vertexBuffer;
    AccelerationStructure blas;
    AccelerationStructure tlas;

    VkDescriptorSetLayout rtDescriptorSetLayout = VK_NULL_HANDLE;
    VkDescriptorPool descriptorPool = VK_NULL_HANDLE;
    VkDescriptorSet rtDescriptorSet = VK_NULL_HANDLE;
    VkPipelineLayout rtPipelineLayout = VK_NULL_HANDLE;
    VkPipeline rtPipeline = VK_NULL_HANDLE;

    VkShaderModule raygenShaderModule = VK_NULL_HANDLE;
    VkShaderModule missShaderModule = VK_NULL_HANDLE;
    VkShaderModule chitShaderModule = VK_NULL_HANDLE;

    Buffer shaderBindingTable;
    VkStridedDeviceAddressRegionKHR raygenRegion{};
    VkStridedDeviceAddressRegionKHR missRegion{};
    VkStridedDeviceAddressRegionKHR hitRegion{};
    VkStridedDeviceAddressRegionKHR callableRegion{};

    Image outputImage;

    struct Vertex {
        float x, y, z;
    };

    void initWindow() {
        glfwInit();
        glfwWindowHint(GLFW_CLIENT_API, GLFW_NO_API);
        window = glfwCreateWindow(WIDTH, HEIGHT, "Hello, Vulkan Ray Tracing!", nullptr, nullptr);
        glfwSetWindowUserPointer(window, this);
        glfwSetFramebufferSizeCallback(window, framebufferResizeCallback);
    }

    static void framebufferResizeCallback(GLFWwindow* window, int, int) {
        auto app = reinterpret_cast<HelloTriangleApplication*>(glfwGetWindowUserPointer(window));
        app->framebufferResized = true;
    }

    void initVulkan() {
        createInstance();
        setupDebugMessenger();
        createSurface();
        pickPhysicalDevice();
        createLogicalDevice();
        loadRayTracingFunctionPointers();
        createCommandPool();
        createSwapChain();
        createVertexBuffer();
        createAccelerationStructures();
        createOutputImage();
        createDescriptorSetLayout();
        createDescriptorPool();
        allocateAndWriteDescriptorSet();
        createRayTracingPipeline();
        createShaderBindingTable();
        createCommandBuffers();
        createSyncObjects();
    }

    void mainLoop() {
        while (!glfwWindowShouldClose(window)) {
            glfwPollEvents();
            drawFrame();
        }
        vkDeviceWaitIdle(device);
    }

    void cleanupSwapChain() {
        if (!commandBuffers.empty()) {
            vkFreeCommandBuffers(device, commandPool, static_cast<uint32_t>(commandBuffers.size()), commandBuffers.data());
            commandBuffers.clear();
        }

        destroyImage(outputImage);

        if (swapChain != VK_NULL_HANDLE) {
            vkDestroySwapchainKHR(device, swapChain, nullptr);
            swapChain = VK_NULL_HANDLE;
        }

        swapChainImages.clear();
    }

    void cleanup() {
        cleanupSwapChain();

        destroyBuffer(shaderBindingTable);

        if (rtPipeline != VK_NULL_HANDLE) {
            vkDestroyPipeline(device, rtPipeline, nullptr);
        }
        if (rtPipelineLayout != VK_NULL_HANDLE) {
            vkDestroyPipelineLayout(device, rtPipelineLayout, nullptr);
        }
        if (raygenShaderModule != VK_NULL_HANDLE) {
            vkDestroyShaderModule(device, raygenShaderModule, nullptr);
        }
        if (missShaderModule != VK_NULL_HANDLE) {
            vkDestroyShaderModule(device, missShaderModule, nullptr);
        }
        if (chitShaderModule != VK_NULL_HANDLE) {
            vkDestroyShaderModule(device, chitShaderModule, nullptr);
        }
        if (descriptorPool != VK_NULL_HANDLE) {
            vkDestroyDescriptorPool(device, descriptorPool, nullptr);
        }
        if (rtDescriptorSetLayout != VK_NULL_HANDLE) {
            vkDestroyDescriptorSetLayout(device, rtDescriptorSetLayout, nullptr);
        }

        destroyAccelerationStructure(tlas);
        destroyAccelerationStructure(blas);
        destroyBuffer(vertexBuffer);

        for (size_t i = 0; i < MAX_FRAMES_IN_FLIGHT; i++) {
            if (renderFinishedSemaphores[i] != VK_NULL_HANDLE) {
                vkDestroySemaphore(device, renderFinishedSemaphores[i], nullptr);
            }
            if (imageAvailableSemaphores[i] != VK_NULL_HANDLE) {
                vkDestroySemaphore(device, imageAvailableSemaphores[i], nullptr);
            }
            if (inFlightFences[i] != VK_NULL_HANDLE) {
                vkDestroyFence(device, inFlightFences[i], nullptr);
            }
        }

        if (commandPool != VK_NULL_HANDLE) {
            vkDestroyCommandPool(device, commandPool, nullptr);
        }
        if (device != VK_NULL_HANDLE) {
            vkDestroyDevice(device, nullptr);
        }
        if (enableValidationLayers && debugMessenger != VK_NULL_HANDLE) {
            DestroyDebugUtilsMessengerEXT(instance, debugMessenger, nullptr);
        }
        if (surface != VK_NULL_HANDLE) {
            vkDestroySurfaceKHR(instance, surface, nullptr);
        }
        if (instance != VK_NULL_HANDLE) {
            vkDestroyInstance(instance, nullptr);
        }
        if (window) {
            glfwDestroyWindow(window);
        }
        glfwTerminate();
    }

    void recreateSwapChain() {
        int width = 0;
        int height = 0;
        glfwGetFramebufferSize(window, &width, &height);
        while (width == 0 || height == 0) {
            glfwGetFramebufferSize(window, &width, &height);
            glfwWaitEvents();
        }

        vkDeviceWaitIdle(device);

        cleanupSwapChain();
        createSwapChain();
        createOutputImage();
        updateDescriptorSetImage();
        createCommandBuffers();

        imagesInFlight.resize(swapChainImages.size(), VK_NULL_HANDLE);
    }

    void createInstance() {
        if (enableValidationLayers && !checkValidationLayerSupport()) {
            throw std::runtime_error("validation layers requested, but not available!");
        }

        VkApplicationInfo appInfo{};
        appInfo.sType = VK_STRUCTURE_TYPE_APPLICATION_INFO;
        appInfo.pApplicationName = "Hello, Vulkan Ray Tracing!";
        appInfo.applicationVersion = VK_MAKE_VERSION(1, 0, 0);
        appInfo.pEngineName = "No Engine";
        appInfo.engineVersion = VK_MAKE_VERSION(1, 0, 0);
        appInfo.apiVersion = APP_VK_API_VERSION;

        VkInstanceCreateInfo createInfo{};
        createInfo.sType = VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO;
        createInfo.pApplicationInfo = &appInfo;

        auto extensions = getRequiredExtensions();
        createInfo.enabledExtensionCount = static_cast<uint32_t>(extensions.size());
        createInfo.ppEnabledExtensionNames = extensions.data();

        VkDebugUtilsMessengerCreateInfoEXT debugCreateInfo{};
        if (enableValidationLayers) {
            createInfo.enabledLayerCount = static_cast<uint32_t>(validationLayers.size());
            createInfo.ppEnabledLayerNames = validationLayers.data();
            populateDebugMessengerCreateInfo(debugCreateInfo);
            createInfo.pNext = &debugCreateInfo;
        } else {
            createInfo.enabledLayerCount = 0;
        }

        if (vkCreateInstance(&createInfo, nullptr, &instance) != VK_SUCCESS) {
            throw std::runtime_error("failed to create instance!");
        }
    }

    void populateDebugMessengerCreateInfo(VkDebugUtilsMessengerCreateInfoEXT& createInfo) {
        createInfo = {};
        createInfo.sType = VK_STRUCTURE_TYPE_DEBUG_UTILS_MESSENGER_CREATE_INFO_EXT;
        createInfo.messageSeverity =
            VK_DEBUG_UTILS_MESSAGE_SEVERITY_VERBOSE_BIT_EXT |
            VK_DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT |
            VK_DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT;
        createInfo.messageType =
            VK_DEBUG_UTILS_MESSAGE_TYPE_GENERAL_BIT_EXT |
            VK_DEBUG_UTILS_MESSAGE_TYPE_VALIDATION_BIT_EXT |
            VK_DEBUG_UTILS_MESSAGE_TYPE_PERFORMANCE_BIT_EXT;
        createInfo.pfnUserCallback = debugCallback;
    }

    void setupDebugMessenger() {
        if (!enableValidationLayers) return;

        VkDebugUtilsMessengerCreateInfoEXT createInfo{};
        populateDebugMessengerCreateInfo(createInfo);
        if (CreateDebugUtilsMessengerEXT(instance, &createInfo, nullptr, &debugMessenger) != VK_SUCCESS) {
            throw std::runtime_error("failed to set up debug messenger!");
        }
    }

    void createSurface() {
        if (glfwCreateWindowSurface(instance, window, nullptr, &surface) != VK_SUCCESS) {
            throw std::runtime_error("failed to create window surface!");
        }
    }

    void pickPhysicalDevice() {
        uint32_t deviceCount = 0;
        vkEnumeratePhysicalDevices(instance, &deviceCount, nullptr);
        if (deviceCount == 0) {
            throw std::runtime_error("failed to find GPUs with Vulkan support!");
        }

        std::vector<VkPhysicalDevice> devices(deviceCount);
        vkEnumeratePhysicalDevices(instance, &deviceCount, devices.data());

        for (const auto& dev : devices) {
            if (isDeviceSuitable(dev)) {
                physicalDevice = dev;
                break;
            }
        }

        if (physicalDevice == VK_NULL_HANDLE) {
            throw std::runtime_error("failed to find a suitable GPU with Vulkan ray tracing support!");
        }

        asProps.pNext = nullptr;
        rtPipelineProps.pNext = &asProps;

        VkPhysicalDeviceProperties2 props2{};
        props2.sType = VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_PROPERTIES_2;
        props2.pNext = &rtPipelineProps;
        vkGetPhysicalDeviceProperties2(physicalDevice, &props2);
    }

    void createLogicalDevice() {
        QueueFamilyIndices indices = findQueueFamilies(physicalDevice);

        std::vector<VkDeviceQueueCreateInfo> queueCreateInfos;
        std::set<uint32_t> uniqueQueueFamilies = {
            indices.graphicsFamily.value(),
            indices.presentFamily.value()
        };

        float queuePriority = 1.0f;
        for (uint32_t queueFamily : uniqueQueueFamilies) {
            VkDeviceQueueCreateInfo queueCreateInfo{};
            queueCreateInfo.sType = VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO;
            queueCreateInfo.queueFamilyIndex = queueFamily;
            queueCreateInfo.queueCount = 1;
            queueCreateInfo.pQueuePriorities = &queuePriority;
            queueCreateInfos.push_back(queueCreateInfo);
        }

        VkPhysicalDeviceBufferDeviceAddressFeatures bdaFeatures{};
        bdaFeatures.sType = VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_BUFFER_DEVICE_ADDRESS_FEATURES;
        bdaFeatures.bufferDeviceAddress = VK_TRUE;

        VkPhysicalDeviceAccelerationStructureFeaturesKHR asFeatures{};
        asFeatures.sType = VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_ACCELERATION_STRUCTURE_FEATURES_KHR;
        asFeatures.pNext = &bdaFeatures;
        asFeatures.accelerationStructure = VK_TRUE;

        VkPhysicalDeviceRayTracingPipelineFeaturesKHR rtFeatures{};
        rtFeatures.sType = VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_RAY_TRACING_PIPELINE_FEATURES_KHR;
        rtFeatures.pNext = &asFeatures;
        rtFeatures.rayTracingPipeline = VK_TRUE;

        VkPhysicalDeviceFeatures2 deviceFeatures2{};
        deviceFeatures2.sType = VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_FEATURES_2;
        deviceFeatures2.pNext = &rtFeatures;

        VkDeviceCreateInfo createInfo{};
        createInfo.sType = VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO;
        createInfo.pNext = &deviceFeatures2;
        createInfo.queueCreateInfoCount = static_cast<uint32_t>(queueCreateInfos.size());
        createInfo.pQueueCreateInfos = queueCreateInfos.data();
        createInfo.enabledExtensionCount = static_cast<uint32_t>(deviceExtensions.size());
        createInfo.ppEnabledExtensionNames = deviceExtensions.data();

        if (enableValidationLayers) {
            createInfo.enabledLayerCount = static_cast<uint32_t>(validationLayers.size());
            createInfo.ppEnabledLayerNames = validationLayers.data();
        }

        if (vkCreateDevice(physicalDevice, &createInfo, nullptr, &device) != VK_SUCCESS) {
            throw std::runtime_error("failed to create logical device!");
        }

        vkGetDeviceQueue(device, indices.graphicsFamily.value(), 0, &graphicsQueue);
        vkGetDeviceQueue(device, indices.presentFamily.value(), 0, &presentQueue);
    }

    void loadRayTracingFunctionPointers() {
        fpCreateAccelerationStructureKHR =
            reinterpret_cast<PFN_vkCreateAccelerationStructureKHR>(vkGetDeviceProcAddr(device, "vkCreateAccelerationStructureKHR"));
        fpDestroyAccelerationStructureKHR =
            reinterpret_cast<PFN_vkDestroyAccelerationStructureKHR>(vkGetDeviceProcAddr(device, "vkDestroyAccelerationStructureKHR"));
        fpGetAccelerationStructureBuildSizesKHR =
            reinterpret_cast<PFN_vkGetAccelerationStructureBuildSizesKHR>(vkGetDeviceProcAddr(device, "vkGetAccelerationStructureBuildSizesKHR"));
        fpCmdBuildAccelerationStructuresKHR =
            reinterpret_cast<PFN_vkCmdBuildAccelerationStructuresKHR>(vkGetDeviceProcAddr(device, "vkCmdBuildAccelerationStructuresKHR"));
        fpGetAccelerationStructureDeviceAddressKHR =
            reinterpret_cast<PFN_vkGetAccelerationStructureDeviceAddressKHR>(vkGetDeviceProcAddr(device, "vkGetAccelerationStructureDeviceAddressKHR"));
        fpCreateRayTracingPipelinesKHR =
            reinterpret_cast<PFN_vkCreateRayTracingPipelinesKHR>(vkGetDeviceProcAddr(device, "vkCreateRayTracingPipelinesKHR"));
        fpGetRayTracingShaderGroupHandlesKHR =
            reinterpret_cast<PFN_vkGetRayTracingShaderGroupHandlesKHR>(vkGetDeviceProcAddr(device, "vkGetRayTracingShaderGroupHandlesKHR"));
        fpCmdTraceRaysKHR =
            reinterpret_cast<PFN_vkCmdTraceRaysKHR>(vkGetDeviceProcAddr(device, "vkCmdTraceRaysKHR"));

        if (!fpCreateAccelerationStructureKHR ||
            !fpDestroyAccelerationStructureKHR ||
            !fpGetAccelerationStructureBuildSizesKHR ||
            !fpCmdBuildAccelerationStructuresKHR ||
            !fpGetAccelerationStructureDeviceAddressKHR ||
            !fpCreateRayTracingPipelinesKHR ||
            !fpGetRayTracingShaderGroupHandlesKHR ||
            !fpCmdTraceRaysKHR) {
            throw std::runtime_error("failed to load Vulkan ray tracing function pointers!");
        }
    }

    void createCommandPool() {
        QueueFamilyIndices queueFamilyIndices = findQueueFamilies(physicalDevice);

        VkCommandPoolCreateInfo poolInfo{};
        poolInfo.sType = VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO;
        poolInfo.flags = VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT;
        poolInfo.queueFamilyIndex = queueFamilyIndices.graphicsFamily.value();

        if (vkCreateCommandPool(device, &poolInfo, nullptr, &commandPool) != VK_SUCCESS) {
            throw std::runtime_error("failed to create command pool!");
        }
    }

    void createSwapChain() {
        SwapChainSupportDetails swapChainSupport = querySwapChainSupport(physicalDevice);

        VkSurfaceFormatKHR surfaceFormat = chooseSwapSurfaceFormat(swapChainSupport.formats);
        VkPresentModeKHR presentMode = chooseSwapPresentMode(swapChainSupport.presentModes);
        VkExtent2D extent = chooseSwapExtent(swapChainSupport.capabilities);

        uint32_t imageCount = swapChainSupport.capabilities.minImageCount + 1;
        if (swapChainSupport.capabilities.maxImageCount > 0 && imageCount > swapChainSupport.capabilities.maxImageCount) {
            imageCount = swapChainSupport.capabilities.maxImageCount;
        }

        VkSwapchainCreateInfoKHR createInfo{};
        createInfo.sType = VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR;
        createInfo.surface = surface;
        createInfo.minImageCount = imageCount;
        createInfo.imageFormat = surfaceFormat.format;
        createInfo.imageColorSpace = surfaceFormat.colorSpace;
        createInfo.imageExtent = extent;
        createInfo.imageArrayLayers = 1;
        createInfo.imageUsage = VK_IMAGE_USAGE_TRANSFER_DST_BIT;

        QueueFamilyIndices indices = findQueueFamilies(physicalDevice);
        uint32_t queueFamilyIndices[] = {
            indices.graphicsFamily.value(),
            indices.presentFamily.value()
        };

        if (indices.graphicsFamily != indices.presentFamily) {
            createInfo.imageSharingMode = VK_SHARING_MODE_CONCURRENT;
            createInfo.queueFamilyIndexCount = 2;
            createInfo.pQueueFamilyIndices = queueFamilyIndices;
        } else {
            createInfo.imageSharingMode = VK_SHARING_MODE_EXCLUSIVE;
        }

        createInfo.preTransform = swapChainSupport.capabilities.currentTransform;
        createInfo.compositeAlpha = VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR;
        createInfo.presentMode = presentMode;
        createInfo.clipped = VK_TRUE;

        if (vkCreateSwapchainKHR(device, &createInfo, nullptr, &swapChain) != VK_SUCCESS) {
            throw std::runtime_error("failed to create swap chain!");
        }

        vkGetSwapchainImagesKHR(device, swapChain, &imageCount, nullptr);
        swapChainImages.resize(imageCount);
        vkGetSwapchainImagesKHR(device, swapChain, &imageCount, swapChainImages.data());

        swapChainImageFormat = surfaceFormat.format;
        swapChainExtent = extent;

        VkFormatProperties formatProps{};
        vkGetPhysicalDeviceFormatProperties(physicalDevice, swapChainImageFormat, &formatProps);
        if ((formatProps.optimalTilingFeatures & VK_FORMAT_FEATURE_STORAGE_IMAGE_BIT) == 0) {
            throw std::runtime_error("swapchain format does not support storage image usage; choose a different surface format or GPU/driver.");
        }
    }

    void createVertexBuffer() {
        const Vertex vertices[3] = {
            { 0.0f,  0.5f, 0.0f },
            { 0.5f, -0.5f, 0.0f },
            {-0.5f, -0.5f, 0.0f },
        };

        vertexBuffer = createBuffer(
            sizeof(vertices),
            VK_BUFFER_USAGE_TRANSFER_DST_BIT |
            VK_BUFFER_USAGE_SHADER_DEVICE_ADDRESS_BIT |
            VK_BUFFER_USAGE_ACCELERATION_STRUCTURE_BUILD_INPUT_READ_ONLY_BIT_KHR,
            VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | VK_MEMORY_PROPERTY_HOST_COHERENT_BIT);

        void* mapped = nullptr;
        vkMapMemory(device, vertexBuffer.memory, 0, sizeof(vertices), 0, &mapped);
        std::memcpy(mapped, vertices, sizeof(vertices));
        vkUnmapMemory(device, vertexBuffer.memory);
    }

    void createAccelerationStructures() {
        createBottomLevelAS();
        createTopLevelAS();
    }

    void createBottomLevelAS() {
        VkAccelerationStructureGeometryTrianglesDataKHR triangles{};
        triangles.sType = VK_STRUCTURE_TYPE_ACCELERATION_STRUCTURE_GEOMETRY_TRIANGLES_DATA_KHR;
        triangles.vertexFormat = VK_FORMAT_R32G32B32_SFLOAT;
        triangles.vertexData.deviceAddress = vertexBuffer.address;
        triangles.vertexStride = sizeof(Vertex);
        triangles.maxVertex = 3;
        triangles.indexType = VK_INDEX_TYPE_NONE_KHR;
        triangles.transformData.deviceAddress = 0;

        VkAccelerationStructureGeometryKHR geometry{};
        geometry.sType = VK_STRUCTURE_TYPE_ACCELERATION_STRUCTURE_GEOMETRY_KHR;
        geometry.geometryType = VK_GEOMETRY_TYPE_TRIANGLES_KHR;
        geometry.flags = VK_GEOMETRY_OPAQUE_BIT_KHR;
        geometry.geometry.triangles = triangles;

        VkAccelerationStructureBuildGeometryInfoKHR buildInfo{};
        buildInfo.sType = VK_STRUCTURE_TYPE_ACCELERATION_STRUCTURE_BUILD_GEOMETRY_INFO_KHR;
        buildInfo.type = VK_ACCELERATION_STRUCTURE_TYPE_BOTTOM_LEVEL_KHR;
        buildInfo.flags = VK_BUILD_ACCELERATION_STRUCTURE_PREFER_FAST_TRACE_BIT_KHR;
        buildInfo.mode = VK_BUILD_ACCELERATION_STRUCTURE_MODE_BUILD_KHR;
        buildInfo.geometryCount = 1;
        buildInfo.pGeometries = &geometry;

        uint32_t primitiveCount = 1;
        VkAccelerationStructureBuildSizesInfoKHR sizeInfo{};
        sizeInfo.sType = VK_STRUCTURE_TYPE_ACCELERATION_STRUCTURE_BUILD_SIZES_INFO_KHR;
        fpGetAccelerationStructureBuildSizesKHR(
            device,
            VK_ACCELERATION_STRUCTURE_BUILD_TYPE_DEVICE_KHR,
            &buildInfo,
            &primitiveCount,
            &sizeInfo);

        blas.storage = createBuffer(
            sizeInfo.accelerationStructureSize,
            VK_BUFFER_USAGE_ACCELERATION_STRUCTURE_STORAGE_BIT_KHR |
            VK_BUFFER_USAGE_SHADER_DEVICE_ADDRESS_BIT,
            VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT);

        VkAccelerationStructureCreateInfoKHR createInfo{};
        createInfo.sType = VK_STRUCTURE_TYPE_ACCELERATION_STRUCTURE_CREATE_INFO_KHR;
        createInfo.type = VK_ACCELERATION_STRUCTURE_TYPE_BOTTOM_LEVEL_KHR;
        createInfo.size = sizeInfo.accelerationStructureSize;
        createInfo.buffer = blas.storage.buffer;

        if (fpCreateAccelerationStructureKHR(device, &createInfo, nullptr, &blas.handle) != VK_SUCCESS) {
            throw std::runtime_error("failed to create BLAS!");
        }

        Buffer scratch = createBuffer(
            sizeInfo.buildScratchSize,
            VK_BUFFER_USAGE_STORAGE_BUFFER_BIT | VK_BUFFER_USAGE_SHADER_DEVICE_ADDRESS_BIT,
            VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT);

        buildInfo.dstAccelerationStructure = blas.handle;
        buildInfo.scratchData.deviceAddress = scratch.address;

        VkAccelerationStructureBuildRangeInfoKHR rangeInfo{};
        rangeInfo.primitiveCount = 1;
        const VkAccelerationStructureBuildRangeInfoKHR* rangeInfos[] = { &rangeInfo };

        VkCommandBuffer cmd = beginSingleTimeCommands();
        fpCmdBuildAccelerationStructuresKHR(cmd, 1, &buildInfo, rangeInfos);
        insertAccelerationStructureBarrier(cmd);
        endSingleTimeCommands(cmd);

        destroyBuffer(scratch);
    }

    void createTopLevelAS() {
        VkAccelerationStructureDeviceAddressInfoKHR blasAddressInfo{};
        blasAddressInfo.sType = VK_STRUCTURE_TYPE_ACCELERATION_STRUCTURE_DEVICE_ADDRESS_INFO_KHR;
        blasAddressInfo.accelerationStructure = blas.handle;
        VkDeviceAddress blasAddress = fpGetAccelerationStructureDeviceAddressKHR(device, &blasAddressInfo);

        VkTransformMatrixKHR transformMatrix = {
            1.0f, 0.0f, 0.0f, 0.0f,
            0.0f, 1.0f, 0.0f, 0.0f,
            0.0f, 0.0f, 1.0f, 0.0f
        };

        VkAccelerationStructureInstanceKHR instanceDesc{};
        instanceDesc.transform = transformMatrix;
        instanceDesc.instanceCustomIndex = 0;
        instanceDesc.mask = 0xFF;
        instanceDesc.instanceShaderBindingTableRecordOffset = 0;
        instanceDesc.flags = VK_GEOMETRY_INSTANCE_TRIANGLE_FACING_CULL_DISABLE_BIT_KHR;
        instanceDesc.accelerationStructureReference = blasAddress;

        Buffer instanceBuffer = createBuffer(
            sizeof(instanceDesc),
            VK_BUFFER_USAGE_SHADER_DEVICE_ADDRESS_BIT |
            VK_BUFFER_USAGE_ACCELERATION_STRUCTURE_BUILD_INPUT_READ_ONLY_BIT_KHR,
            VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | VK_MEMORY_PROPERTY_HOST_COHERENT_BIT);

        void* mapped = nullptr;
        vkMapMemory(device, instanceBuffer.memory, 0, sizeof(instanceDesc), 0, &mapped);
        std::memcpy(mapped, &instanceDesc, sizeof(instanceDesc));
        vkUnmapMemory(device, instanceBuffer.memory);

        VkAccelerationStructureGeometryInstancesDataKHR instancesData{};
        instancesData.sType = VK_STRUCTURE_TYPE_ACCELERATION_STRUCTURE_GEOMETRY_INSTANCES_DATA_KHR;
        instancesData.arrayOfPointers = VK_FALSE;
        instancesData.data.deviceAddress = instanceBuffer.address;

        VkAccelerationStructureGeometryKHR geometry{};
        geometry.sType = VK_STRUCTURE_TYPE_ACCELERATION_STRUCTURE_GEOMETRY_KHR;
        geometry.geometryType = VK_GEOMETRY_TYPE_INSTANCES_KHR;
        geometry.geometry.instances = instancesData;

        VkAccelerationStructureBuildGeometryInfoKHR buildInfo{};
        buildInfo.sType = VK_STRUCTURE_TYPE_ACCELERATION_STRUCTURE_BUILD_GEOMETRY_INFO_KHR;
        buildInfo.type = VK_ACCELERATION_STRUCTURE_TYPE_TOP_LEVEL_KHR;
        buildInfo.flags = VK_BUILD_ACCELERATION_STRUCTURE_PREFER_FAST_TRACE_BIT_KHR;
        buildInfo.mode = VK_BUILD_ACCELERATION_STRUCTURE_MODE_BUILD_KHR;
        buildInfo.geometryCount = 1;
        buildInfo.pGeometries = &geometry;

        uint32_t primitiveCount = 1;
        VkAccelerationStructureBuildSizesInfoKHR sizeInfo{};
        sizeInfo.sType = VK_STRUCTURE_TYPE_ACCELERATION_STRUCTURE_BUILD_SIZES_INFO_KHR;
        fpGetAccelerationStructureBuildSizesKHR(
            device,
            VK_ACCELERATION_STRUCTURE_BUILD_TYPE_DEVICE_KHR,
            &buildInfo,
            &primitiveCount,
            &sizeInfo);

        tlas.storage = createBuffer(
            sizeInfo.accelerationStructureSize,
            VK_BUFFER_USAGE_ACCELERATION_STRUCTURE_STORAGE_BIT_KHR |
            VK_BUFFER_USAGE_SHADER_DEVICE_ADDRESS_BIT,
            VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT);

        VkAccelerationStructureCreateInfoKHR createInfo{};
        createInfo.sType = VK_STRUCTURE_TYPE_ACCELERATION_STRUCTURE_CREATE_INFO_KHR;
        createInfo.type = VK_ACCELERATION_STRUCTURE_TYPE_TOP_LEVEL_KHR;
        createInfo.size = sizeInfo.accelerationStructureSize;
        createInfo.buffer = tlas.storage.buffer;

        if (fpCreateAccelerationStructureKHR(device, &createInfo, nullptr, &tlas.handle) != VK_SUCCESS) {
            throw std::runtime_error("failed to create TLAS!");
        }

        Buffer scratch = createBuffer(
            sizeInfo.buildScratchSize,
            VK_BUFFER_USAGE_STORAGE_BUFFER_BIT | VK_BUFFER_USAGE_SHADER_DEVICE_ADDRESS_BIT,
            VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT);

        buildInfo.dstAccelerationStructure = tlas.handle;
        buildInfo.scratchData.deviceAddress = scratch.address;

        VkAccelerationStructureBuildRangeInfoKHR rangeInfo{};
        rangeInfo.primitiveCount = 1;
        const VkAccelerationStructureBuildRangeInfoKHR* rangeInfos[] = { &rangeInfo };

        VkCommandBuffer cmd = beginSingleTimeCommands();
        fpCmdBuildAccelerationStructuresKHR(cmd, 1, &buildInfo, rangeInfos);
        insertAccelerationStructureBarrier(cmd);
        endSingleTimeCommands(cmd);

        destroyBuffer(scratch);
        destroyBuffer(instanceBuffer);
    }

    void createOutputImage() {
        outputImage = createImage(
            swapChainExtent.width,
            swapChainExtent.height,
            swapChainImageFormat,
            VK_IMAGE_USAGE_STORAGE_BIT |
            VK_IMAGE_USAGE_TRANSFER_SRC_BIT,
            VK_IMAGE_ASPECT_COLOR_BIT);

        transitionImageLayoutOneTime(
            outputImage.image,
            VK_IMAGE_LAYOUT_UNDEFINED,
            VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL,
            VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT,
            VK_PIPELINE_STAGE_TRANSFER_BIT,
            0,
            VK_ACCESS_TRANSFER_READ_BIT);
    }

    void createDescriptorSetLayout() {
        VkDescriptorSetLayoutBinding tlasBinding{};
        tlasBinding.binding = 0;
        tlasBinding.descriptorCount = 1;
        tlasBinding.descriptorType = VK_DESCRIPTOR_TYPE_ACCELERATION_STRUCTURE_KHR;
        tlasBinding.stageFlags = VK_SHADER_STAGE_RAYGEN_BIT_KHR;

        VkDescriptorSetLayoutBinding outputBinding{};
        outputBinding.binding = 1;
        outputBinding.descriptorCount = 1;
        outputBinding.descriptorType = VK_DESCRIPTOR_TYPE_STORAGE_IMAGE;
        outputBinding.stageFlags = VK_SHADER_STAGE_RAYGEN_BIT_KHR;

        std::array<VkDescriptorSetLayoutBinding, 2> bindings = { tlasBinding, outputBinding };

        VkDescriptorSetLayoutCreateInfo layoutInfo{};
        layoutInfo.sType = VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO;
        layoutInfo.bindingCount = static_cast<uint32_t>(bindings.size());
        layoutInfo.pBindings = bindings.data();

        if (vkCreateDescriptorSetLayout(device, &layoutInfo, nullptr, &rtDescriptorSetLayout) != VK_SUCCESS) {
            throw std::runtime_error("failed to create descriptor set layout!");
        }
    }

    void createDescriptorPool() {
        std::array<VkDescriptorPoolSize, 2> poolSizes{};
        poolSizes[0].type = VK_DESCRIPTOR_TYPE_ACCELERATION_STRUCTURE_KHR;
        poolSizes[0].descriptorCount = 1;
        poolSizes[1].type = VK_DESCRIPTOR_TYPE_STORAGE_IMAGE;
        poolSizes[1].descriptorCount = 1;

        VkDescriptorPoolCreateInfo poolInfo{};
        poolInfo.sType = VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO;
        poolInfo.maxSets = 1;
        poolInfo.poolSizeCount = static_cast<uint32_t>(poolSizes.size());
        poolInfo.pPoolSizes = poolSizes.data();

        if (vkCreateDescriptorPool(device, &poolInfo, nullptr, &descriptorPool) != VK_SUCCESS) {
            throw std::runtime_error("failed to create descriptor pool!");
        }
    }

    void allocateAndWriteDescriptorSet() {
        VkDescriptorSetAllocateInfo allocInfo{};
        allocInfo.sType = VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO;
        allocInfo.descriptorPool = descriptorPool;
        allocInfo.descriptorSetCount = 1;
        allocInfo.pSetLayouts = &rtDescriptorSetLayout;

        if (vkAllocateDescriptorSets(device, &allocInfo, &rtDescriptorSet) != VK_SUCCESS) {
            throw std::runtime_error("failed to allocate descriptor set!");
        }

        updateDescriptorSetImage();
    }

    void updateDescriptorSetImage() {
        VkWriteDescriptorSetAccelerationStructureKHR asInfo{};
        asInfo.sType = VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET_ACCELERATION_STRUCTURE_KHR;
        asInfo.accelerationStructureCount = 1;
        asInfo.pAccelerationStructures = &tlas.handle;

        VkWriteDescriptorSet writeAS{};
        writeAS.sType = VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET;
        writeAS.pNext = &asInfo;
        writeAS.dstSet = rtDescriptorSet;
        writeAS.dstBinding = 0;
        writeAS.descriptorCount = 1;
        writeAS.descriptorType = VK_DESCRIPTOR_TYPE_ACCELERATION_STRUCTURE_KHR;

        VkDescriptorImageInfo imageInfo{};
        imageInfo.imageView = outputImage.view;
        imageInfo.imageLayout = VK_IMAGE_LAYOUT_GENERAL;

        VkWriteDescriptorSet writeImage{};
        writeImage.sType = VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET;
        writeImage.dstSet = rtDescriptorSet;
        writeImage.dstBinding = 1;
        writeImage.descriptorCount = 1;
        writeImage.descriptorType = VK_DESCRIPTOR_TYPE_STORAGE_IMAGE;
        writeImage.pImageInfo = &imageInfo;

        std::array<VkWriteDescriptorSet, 2> writes = { writeAS, writeImage };
        vkUpdateDescriptorSets(device, static_cast<uint32_t>(writes.size()), writes.data(), 0, nullptr);
    }

    void createRayTracingPipeline() {
        std::vector<uint32_t> rgenSpv = compileGlsl(kRaygenShader, shaderc_glsl_raygen_shader, "hello.rgen");
        std::vector<uint32_t> rmissSpv = compileGlsl(kMissShader, shaderc_glsl_miss_shader, "hello.rmiss");
        std::vector<uint32_t> rchitSpv = compileGlsl(kClosestHitShader, shaderc_glsl_closesthit_shader, "hello.rchit");

        raygenShaderModule = createShaderModule(rgenSpv);
        missShaderModule = createShaderModule(rmissSpv);
        chitShaderModule = createShaderModule(rchitSpv);

        std::array<VkPipelineShaderStageCreateInfo, 3> stages{};

        stages[0].sType = VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO;
        stages[0].stage = VK_SHADER_STAGE_RAYGEN_BIT_KHR;
        stages[0].module = raygenShaderModule;
        stages[0].pName = "main";

        stages[1].sType = VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO;
        stages[1].stage = VK_SHADER_STAGE_MISS_BIT_KHR;
        stages[1].module = missShaderModule;
        stages[1].pName = "main";

        stages[2].sType = VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO;
        stages[2].stage = VK_SHADER_STAGE_CLOSEST_HIT_BIT_KHR;
        stages[2].module = chitShaderModule;
        stages[2].pName = "main";

        std::array<VkRayTracingShaderGroupCreateInfoKHR, 3> groups{};

        groups[0].sType = VK_STRUCTURE_TYPE_RAY_TRACING_SHADER_GROUP_CREATE_INFO_KHR;
        groups[0].type = VK_RAY_TRACING_SHADER_GROUP_TYPE_GENERAL_KHR;
        groups[0].generalShader = 0;
        groups[0].closestHitShader = VK_SHADER_UNUSED_KHR;
        groups[0].anyHitShader = VK_SHADER_UNUSED_KHR;
        groups[0].intersectionShader = VK_SHADER_UNUSED_KHR;

        groups[1].sType = VK_STRUCTURE_TYPE_RAY_TRACING_SHADER_GROUP_CREATE_INFO_KHR;
        groups[1].type = VK_RAY_TRACING_SHADER_GROUP_TYPE_GENERAL_KHR;
        groups[1].generalShader = 1;
        groups[1].closestHitShader = VK_SHADER_UNUSED_KHR;
        groups[1].anyHitShader = VK_SHADER_UNUSED_KHR;
        groups[1].intersectionShader = VK_SHADER_UNUSED_KHR;

        groups[2].sType = VK_STRUCTURE_TYPE_RAY_TRACING_SHADER_GROUP_CREATE_INFO_KHR;
        groups[2].type = VK_RAY_TRACING_SHADER_GROUP_TYPE_TRIANGLES_HIT_GROUP_KHR;
        groups[2].generalShader = VK_SHADER_UNUSED_KHR;
        groups[2].closestHitShader = 2;
        groups[2].anyHitShader = VK_SHADER_UNUSED_KHR;
        groups[2].intersectionShader = VK_SHADER_UNUSED_KHR;

        VkPipelineLayoutCreateInfo layoutInfo{};
        layoutInfo.sType = VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO;
        layoutInfo.setLayoutCount = 1;
        layoutInfo.pSetLayouts = &rtDescriptorSetLayout;

        if (vkCreatePipelineLayout(device, &layoutInfo, nullptr, &rtPipelineLayout) != VK_SUCCESS) {
            throw std::runtime_error("failed to create ray tracing pipeline layout!");
        }

        VkRayTracingPipelineCreateInfoKHR pipelineInfo{};
        pipelineInfo.sType = VK_STRUCTURE_TYPE_RAY_TRACING_PIPELINE_CREATE_INFO_KHR;
        pipelineInfo.stageCount = static_cast<uint32_t>(stages.size());
        pipelineInfo.pStages = stages.data();
        pipelineInfo.groupCount = static_cast<uint32_t>(groups.size());
        pipelineInfo.pGroups = groups.data();
        pipelineInfo.maxPipelineRayRecursionDepth = 1;
        pipelineInfo.layout = rtPipelineLayout;

        if (fpCreateRayTracingPipelinesKHR(device, VK_NULL_HANDLE, VK_NULL_HANDLE, 1, &pipelineInfo, nullptr, &rtPipeline) != VK_SUCCESS) {
            throw std::runtime_error("failed to create ray tracing pipeline!");
        }
    }

    void createShaderBindingTable() {
        const uint32_t groupCount = 3;
        const uint32_t handleSize = rtPipelineProps.shaderGroupHandleSize;
        const uint32_t handleAlignment = rtPipelineProps.shaderGroupHandleAlignment;
        const uint32_t baseAlignment = rtPipelineProps.shaderGroupBaseAlignment;
        const uint32_t handleSizeAligned = alignUp(handleSize, handleAlignment);

        const uint32_t raygenSize = alignUp(handleSizeAligned, baseAlignment);
        const uint32_t missSize = alignUp(handleSizeAligned, baseAlignment);
        const uint32_t hitSize = alignUp(handleSizeAligned, baseAlignment);
        const uint32_t sbtSize = raygenSize + missSize + hitSize;

        std::vector<uint8_t> handles(groupCount * handleSize);
        if (fpGetRayTracingShaderGroupHandlesKHR(device, rtPipeline, 0, groupCount, handles.size(), handles.data()) != VK_SUCCESS) {
            throw std::runtime_error("failed to get ray tracing shader group handles!");
        }

        shaderBindingTable = createBuffer(
            sbtSize,
            VK_BUFFER_USAGE_SHADER_BINDING_TABLE_BIT_KHR |
            VK_BUFFER_USAGE_SHADER_DEVICE_ADDRESS_BIT,
            VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | VK_MEMORY_PROPERTY_HOST_COHERENT_BIT);

        uint8_t* mapped = nullptr;
        vkMapMemory(device, shaderBindingTable.memory, 0, sbtSize, 0, reinterpret_cast<void**>(&mapped));
        std::memcpy(mapped + 0, handles.data() + handleSize * 0, handleSize);
        std::memcpy(mapped + raygenSize, handles.data() + handleSize * 1, handleSize);
        std::memcpy(mapped + raygenSize + missSize, handles.data() + handleSize * 2, handleSize);
        vkUnmapMemory(device, shaderBindingTable.memory);

        raygenRegion.deviceAddress = shaderBindingTable.address + 0;
        raygenRegion.stride = raygenSize;
        raygenRegion.size = raygenSize;

        missRegion.deviceAddress = shaderBindingTable.address + raygenSize;
        missRegion.stride = missSize;
        missRegion.size = missSize;

        hitRegion.deviceAddress = shaderBindingTable.address + raygenSize + missSize;
        hitRegion.stride = hitSize;
        hitRegion.size = hitSize;

        callableRegion = {};
    }

    void createCommandBuffers() {
        commandBuffers.resize(swapChainImages.size());

        VkCommandBufferAllocateInfo allocInfo{};
        allocInfo.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO;
        allocInfo.commandPool = commandPool;
        allocInfo.level = VK_COMMAND_BUFFER_LEVEL_PRIMARY;
        allocInfo.commandBufferCount = static_cast<uint32_t>(commandBuffers.size());

        if (vkAllocateCommandBuffers(device, &allocInfo, commandBuffers.data()) != VK_SUCCESS) {
            throw std::runtime_error("failed to allocate command buffers!");
        }

        for (size_t i = 0; i < commandBuffers.size(); i++) {
            recordCommandBuffer(commandBuffers[i], swapChainImages[i]);
        }
    }

    void recordCommandBuffer(VkCommandBuffer cmd, VkImage swapImage) {
        VkCommandBufferBeginInfo beginInfo{};
        beginInfo.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO;

        if (vkBeginCommandBuffer(cmd, &beginInfo) != VK_SUCCESS) {
            throw std::runtime_error("failed to begin recording command buffer!");
        }

        transitionImageLayout(
            cmd,
            outputImage.image,
            VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL,
            VK_IMAGE_LAYOUT_GENERAL,
            VK_PIPELINE_STAGE_TRANSFER_BIT,
            VK_PIPELINE_STAGE_RAY_TRACING_SHADER_BIT_KHR,
            VK_ACCESS_TRANSFER_READ_BIT,
            VK_ACCESS_SHADER_WRITE_BIT,
            VK_IMAGE_ASPECT_COLOR_BIT);

        vkCmdBindPipeline(cmd, VK_PIPELINE_BIND_POINT_RAY_TRACING_KHR, rtPipeline);
        vkCmdBindDescriptorSets(
            cmd,
            VK_PIPELINE_BIND_POINT_RAY_TRACING_KHR,
            rtPipelineLayout,
            0,
            1,
            &rtDescriptorSet,
            0,
            nullptr);

        fpCmdTraceRaysKHR(
            cmd,
            &raygenRegion,
            &missRegion,
            &hitRegion,
            &callableRegion,
            swapChainExtent.width,
            swapChainExtent.height,
            1);

        transitionImageLayout(
            cmd,
            outputImage.image,
            VK_IMAGE_LAYOUT_GENERAL,
            VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL,
            VK_PIPELINE_STAGE_RAY_TRACING_SHADER_BIT_KHR,
            VK_PIPELINE_STAGE_TRANSFER_BIT,
            VK_ACCESS_SHADER_WRITE_BIT,
            VK_ACCESS_TRANSFER_READ_BIT,
            VK_IMAGE_ASPECT_COLOR_BIT);

        transitionImageLayout(
            cmd,
            swapImage,
            VK_IMAGE_LAYOUT_UNDEFINED,
            VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
            VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT,
            VK_PIPELINE_STAGE_TRANSFER_BIT,
            0,
            VK_ACCESS_TRANSFER_WRITE_BIT,
            VK_IMAGE_ASPECT_COLOR_BIT);

        VkImageCopy copyRegion{};
        copyRegion.srcSubresource.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT;
        copyRegion.srcSubresource.mipLevel = 0;
        copyRegion.srcSubresource.baseArrayLayer = 0;
        copyRegion.srcSubresource.layerCount = 1;
        copyRegion.dstSubresource.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT;
        copyRegion.dstSubresource.mipLevel = 0;
        copyRegion.dstSubresource.baseArrayLayer = 0;
        copyRegion.dstSubresource.layerCount = 1;
        copyRegion.extent.width = swapChainExtent.width;
        copyRegion.extent.height = swapChainExtent.height;
        copyRegion.extent.depth = 1;

        vkCmdCopyImage(
            cmd,
            outputImage.image,
            VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL,
            swapImage,
            VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
            1,
            &copyRegion);

        transitionImageLayout(
            cmd,
            swapImage,
            VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
            VK_IMAGE_LAYOUT_PRESENT_SRC_KHR,
            VK_PIPELINE_STAGE_TRANSFER_BIT,
            VK_PIPELINE_STAGE_BOTTOM_OF_PIPE_BIT,
            VK_ACCESS_TRANSFER_WRITE_BIT,
            0,
            VK_IMAGE_ASPECT_COLOR_BIT);

        if (vkEndCommandBuffer(cmd) != VK_SUCCESS) {
            throw std::runtime_error("failed to record command buffer!");
        }
    }

    void createSyncObjects() {
        imageAvailableSemaphores.resize(MAX_FRAMES_IN_FLIGHT);
        renderFinishedSemaphores.resize(MAX_FRAMES_IN_FLIGHT);
        inFlightFences.resize(MAX_FRAMES_IN_FLIGHT);
        imagesInFlight.resize(swapChainImages.size(), VK_NULL_HANDLE);

        VkSemaphoreCreateInfo semaphoreInfo{};
        semaphoreInfo.sType = VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO;

        VkFenceCreateInfo fenceInfo{};
        fenceInfo.sType = VK_STRUCTURE_TYPE_FENCE_CREATE_INFO;
        fenceInfo.flags = VK_FENCE_CREATE_SIGNALED_BIT;

        for (size_t i = 0; i < MAX_FRAMES_IN_FLIGHT; i++) {
            if (vkCreateSemaphore(device, &semaphoreInfo, nullptr, &imageAvailableSemaphores[i]) != VK_SUCCESS ||
                vkCreateSemaphore(device, &semaphoreInfo, nullptr, &renderFinishedSemaphores[i]) != VK_SUCCESS ||
                vkCreateFence(device, &fenceInfo, nullptr, &inFlightFences[i]) != VK_SUCCESS) {
                throw std::runtime_error("failed to create synchronization objects!");
            }
        }
    }

    void drawFrame() {
        vkWaitForFences(device, 1, &inFlightFences[currentFrame], VK_TRUE, UINT64_MAX);

        uint32_t imageIndex = 0;
        VkResult result = vkAcquireNextImageKHR(
            device,
            swapChain,
            UINT64_MAX,
            imageAvailableSemaphores[currentFrame],
            VK_NULL_HANDLE,
            &imageIndex);

        if (result == VK_ERROR_OUT_OF_DATE_KHR) {
            recreateSwapChain();
            return;
        }
        if (result != VK_SUCCESS && result != VK_SUBOPTIMAL_KHR) {
            throw std::runtime_error("failed to acquire swap chain image!");
        }

        if (imagesInFlight[imageIndex] != VK_NULL_HANDLE) {
            vkWaitForFences(device, 1, &imagesInFlight[imageIndex], VK_TRUE, UINT64_MAX);
        }
        imagesInFlight[imageIndex] = inFlightFences[currentFrame];

        VkSubmitInfo submitInfo{};
        submitInfo.sType = VK_STRUCTURE_TYPE_SUBMIT_INFO;

        VkSemaphore waitSemaphores[] = { imageAvailableSemaphores[currentFrame] };
        VkPipelineStageFlags waitStages[] = { VK_PIPELINE_STAGE_TRANSFER_BIT };
        submitInfo.waitSemaphoreCount = 1;
        submitInfo.pWaitSemaphores = waitSemaphores;
        submitInfo.pWaitDstStageMask = waitStages;
        submitInfo.commandBufferCount = 1;
        submitInfo.pCommandBuffers = &commandBuffers[imageIndex];

        VkSemaphore signalSemaphores[] = { renderFinishedSemaphores[currentFrame] };
        submitInfo.signalSemaphoreCount = 1;
        submitInfo.pSignalSemaphores = signalSemaphores;

        vkResetFences(device, 1, &inFlightFences[currentFrame]);
        if (vkQueueSubmit(graphicsQueue, 1, &submitInfo, inFlightFences[currentFrame]) != VK_SUCCESS) {
            throw std::runtime_error("failed to submit draw command buffer!");
        }

        VkPresentInfoKHR presentInfo{};
        presentInfo.sType = VK_STRUCTURE_TYPE_PRESENT_INFO_KHR;
        presentInfo.waitSemaphoreCount = 1;
        presentInfo.pWaitSemaphores = signalSemaphores;
        presentInfo.swapchainCount = 1;
        presentInfo.pSwapchains = &swapChain;
        presentInfo.pImageIndices = &imageIndex;

        result = vkQueuePresentKHR(presentQueue, &presentInfo);
        if (result == VK_ERROR_OUT_OF_DATE_KHR || result == VK_SUBOPTIMAL_KHR || framebufferResized) {
            framebufferResized = false;
            recreateSwapChain();
        } else if (result != VK_SUCCESS) {
            throw std::runtime_error("failed to present swap chain image!");
        }

        currentFrame = (currentFrame + 1) % MAX_FRAMES_IN_FLIGHT;
    }

    VkShaderModule createShaderModule(const std::vector<uint32_t>& code) {
        VkShaderModuleCreateInfo createInfo{};
        createInfo.sType = VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO;
        createInfo.codeSize = code.size() * sizeof(uint32_t);
        createInfo.pCode = code.data();

        VkShaderModule shaderModule = VK_NULL_HANDLE;
        if (vkCreateShaderModule(device, &createInfo, nullptr, &shaderModule) != VK_SUCCESS) {
            throw std::runtime_error("failed to create shader module!");
        }
        return shaderModule;
    }

    std::vector<uint32_t> compileGlsl(const std::string& source, shaderc_shader_kind kind, const std::string& name) {
        shaderc::Compiler compiler;
        shaderc::CompileOptions options;
        options.SetSourceLanguage(shaderc_source_language_glsl);
        options.SetTargetEnvironment(shaderc_target_env_vulkan, shaderc_env_version_vulkan_1_2);
        options.SetTargetSpirv(shaderc_spirv_version_1_4);
        options.SetOptimizationLevel(shaderc_optimization_level_zero);
        options.SetGenerateDebugInfo();

        shaderc::SpvCompilationResult result = compiler.CompileGlslToSpv(source, kind, name.c_str(), options);
        if (result.GetCompilationStatus() != shaderc_compilation_status_success) {
            throw std::runtime_error("shaderc compile failed (" + name + "): " + result.GetErrorMessage());
        }
        return { result.cbegin(), result.cend() };
    }

    VkSurfaceFormatKHR chooseSwapSurfaceFormat(const std::vector<VkSurfaceFormatKHR>& availableFormats) {
        for (const auto& availableFormat : availableFormats) {
            if (availableFormat.format == VK_FORMAT_B8G8R8A8_UNORM &&
                availableFormat.colorSpace == VK_COLOR_SPACE_SRGB_NONLINEAR_KHR) {
                return availableFormat;
            }
        }
        for (const auto& availableFormat : availableFormats) {
            if (availableFormat.format == VK_FORMAT_R8G8B8A8_UNORM &&
                availableFormat.colorSpace == VK_COLOR_SPACE_SRGB_NONLINEAR_KHR) {
                return availableFormat;
            }
        }
        return availableFormats[0];
    }

    VkPresentModeKHR chooseSwapPresentMode(const std::vector<VkPresentModeKHR>& availablePresentModes) {
        for (const auto& availablePresentMode : availablePresentModes) {
            if (availablePresentMode == VK_PRESENT_MODE_MAILBOX_KHR) {
                return availablePresentMode;
            }
        }
        return VK_PRESENT_MODE_FIFO_KHR;
    }

    VkExtent2D chooseSwapExtent(const VkSurfaceCapabilitiesKHR& capabilities) {
        if (capabilities.currentExtent.width != UINT32_MAX) {
            return capabilities.currentExtent;
        }

        int width = 0;
        int height = 0;
        glfwGetFramebufferSize(window, &width, &height);

        VkExtent2D actualExtent = {
            static_cast<uint32_t>(width),
            static_cast<uint32_t>(height)
        };

        actualExtent.width = std::max(capabilities.minImageExtent.width,
                                      std::min(capabilities.maxImageExtent.width, actualExtent.width));
        actualExtent.height = std::max(capabilities.minImageExtent.height,
                                       std::min(capabilities.maxImageExtent.height, actualExtent.height));
        return actualExtent;
    }

    SwapChainSupportDetails querySwapChainSupport(VkPhysicalDevice dev) {
        SwapChainSupportDetails details;
        vkGetPhysicalDeviceSurfaceCapabilitiesKHR(dev, surface, &details.capabilities);

        uint32_t formatCount = 0;
        vkGetPhysicalDeviceSurfaceFormatsKHR(dev, surface, &formatCount, nullptr);
        if (formatCount != 0) {
            details.formats.resize(formatCount);
            vkGetPhysicalDeviceSurfaceFormatsKHR(dev, surface, &formatCount, details.formats.data());
        }

        uint32_t presentModeCount = 0;
        vkGetPhysicalDeviceSurfacePresentModesKHR(dev, surface, &presentModeCount, nullptr);
        if (presentModeCount != 0) {
            details.presentModes.resize(presentModeCount);
            vkGetPhysicalDeviceSurfacePresentModesKHR(dev, surface, &presentModeCount, details.presentModes.data());
        }
        return details;
    }

    bool isDeviceSuitable(VkPhysicalDevice dev) {
        QueueFamilyIndices indices = findQueueFamilies(dev);
        bool extensionsSupported = checkDeviceExtensionSupport(dev);

        bool swapChainAdequate = false;
        if (extensionsSupported) {
            SwapChainSupportDetails swapChainSupport = querySwapChainSupport(dev);
            swapChainAdequate = !swapChainSupport.formats.empty() && !swapChainSupport.presentModes.empty();
        }

        VkPhysicalDeviceBufferDeviceAddressFeatures bdaFeatures{};
        bdaFeatures.sType = VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_BUFFER_DEVICE_ADDRESS_FEATURES;

        VkPhysicalDeviceAccelerationStructureFeaturesKHR asFeatures{};
        asFeatures.sType = VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_ACCELERATION_STRUCTURE_FEATURES_KHR;
        asFeatures.pNext = &bdaFeatures;

        VkPhysicalDeviceRayTracingPipelineFeaturesKHR rtFeatures{};
        rtFeatures.sType = VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_RAY_TRACING_PIPELINE_FEATURES_KHR;
        rtFeatures.pNext = &asFeatures;

        VkPhysicalDeviceFeatures2 features2{};
        features2.sType = VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_FEATURES_2;
        features2.pNext = &rtFeatures;
        vkGetPhysicalDeviceFeatures2(dev, &features2);

        return indices.isComplete() &&
               extensionsSupported &&
               swapChainAdequate &&
               bdaFeatures.bufferDeviceAddress &&
               asFeatures.accelerationStructure &&
               rtFeatures.rayTracingPipeline;
    }

    bool checkDeviceExtensionSupport(VkPhysicalDevice dev) {
        uint32_t extensionCount = 0;
        vkEnumerateDeviceExtensionProperties(dev, nullptr, &extensionCount, nullptr);

        std::vector<VkExtensionProperties> availableExtensions(extensionCount);
        vkEnumerateDeviceExtensionProperties(dev, nullptr, &extensionCount, availableExtensions.data());

        std::set<std::string> requiredExtensions(deviceExtensions.begin(), deviceExtensions.end());
        for (const auto& extension : availableExtensions) {
            requiredExtensions.erase(extension.extensionName);
        }
        return requiredExtensions.empty();
    }

    QueueFamilyIndices findQueueFamilies(VkPhysicalDevice dev) {
        QueueFamilyIndices indices;

        uint32_t queueFamilyCount = 0;
        vkGetPhysicalDeviceQueueFamilyProperties(dev, &queueFamilyCount, nullptr);
        std::vector<VkQueueFamilyProperties> queueFamilies(queueFamilyCount);
        vkGetPhysicalDeviceQueueFamilyProperties(dev, &queueFamilyCount, queueFamilies.data());

        for (uint32_t i = 0; i < queueFamilyCount; i++) {
            if (queueFamilies[i].queueFlags & VK_QUEUE_GRAPHICS_BIT) {
                indices.graphicsFamily = i;
            }

            VkBool32 presentSupport = VK_FALSE;
            vkGetPhysicalDeviceSurfaceSupportKHR(dev, i, surface, &presentSupport);
            if (presentSupport) {
                indices.presentFamily = i;
            }

            if (indices.isComplete()) {
                break;
            }
        }

        return indices;
    }

    std::vector<const char*> getRequiredExtensions() {
        uint32_t glfwExtensionCount = 0;
        const char** glfwExtensions = glfwGetRequiredInstanceExtensions(&glfwExtensionCount);
        std::vector<const char*> extensions(glfwExtensions, glfwExtensions + glfwExtensionCount);
        if (enableValidationLayers) {
            extensions.push_back(VK_EXT_DEBUG_UTILS_EXTENSION_NAME);
        }
        return extensions;
    }

    bool checkValidationLayerSupport() {
        uint32_t layerCount = 0;
        vkEnumerateInstanceLayerProperties(&layerCount, nullptr);
        std::vector<VkLayerProperties> availableLayers(layerCount);
        vkEnumerateInstanceLayerProperties(&layerCount, availableLayers.data());

        for (const char* layerName : validationLayers) {
            bool layerFound = false;
            for (const auto& layerProperties : availableLayers) {
                if (std::strcmp(layerName, layerProperties.layerName) == 0) {
                    layerFound = true;
                    break;
                }
            }
            if (!layerFound) {
                return false;
            }
        }
        return true;
    }

    uint32_t findMemoryType(uint32_t typeFilter, VkMemoryPropertyFlags properties) {
        VkPhysicalDeviceMemoryProperties memProperties{};
        vkGetPhysicalDeviceMemoryProperties(physicalDevice, &memProperties);

        for (uint32_t i = 0; i < memProperties.memoryTypeCount; i++) {
            if ((typeFilter & (1u << i)) &&
                (memProperties.memoryTypes[i].propertyFlags & properties) == properties) {
                return i;
            }
        }

        throw std::runtime_error("failed to find suitable memory type!");
    }

    Buffer createBuffer(VkDeviceSize size, VkBufferUsageFlags usage, VkMemoryPropertyFlags properties) {
        Buffer out{};
        out.size = size;

        VkBufferCreateInfo bufferInfo{};
        bufferInfo.sType = VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO;
        bufferInfo.size = size;
        bufferInfo.usage = usage;
        bufferInfo.sharingMode = VK_SHARING_MODE_EXCLUSIVE;

        if (vkCreateBuffer(device, &bufferInfo, nullptr, &out.buffer) != VK_SUCCESS) {
            throw std::runtime_error("failed to create buffer!");
        }

        VkMemoryRequirements memRequirements{};
        vkGetBufferMemoryRequirements(device, out.buffer, &memRequirements);

        VkMemoryAllocateFlagsInfo allocFlags{};
        allocFlags.sType = VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_FLAGS_INFO;
        allocFlags.flags = VK_MEMORY_ALLOCATE_DEVICE_ADDRESS_BIT;

        VkMemoryAllocateInfo allocInfo{};
        allocInfo.sType = VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO;
        allocInfo.pNext = &allocFlags;
        allocInfo.allocationSize = memRequirements.size;
        allocInfo.memoryTypeIndex = findMemoryType(memRequirements.memoryTypeBits, properties);

        if (vkAllocateMemory(device, &allocInfo, nullptr, &out.memory) != VK_SUCCESS) {
            throw std::runtime_error("failed to allocate buffer memory!");
        }

        if (vkBindBufferMemory(device, out.buffer, out.memory, 0) != VK_SUCCESS) {
            throw std::runtime_error("failed to bind buffer memory!");
        }

        if (usage & VK_BUFFER_USAGE_SHADER_DEVICE_ADDRESS_BIT) {
            VkBufferDeviceAddressInfo addressInfo{};
            addressInfo.sType = VK_STRUCTURE_TYPE_BUFFER_DEVICE_ADDRESS_INFO;
            addressInfo.buffer = out.buffer;
            out.address = vkGetBufferDeviceAddress(device, &addressInfo);
        }

        return out;
    }

    void destroyBuffer(Buffer& buffer) {
        if (buffer.buffer != VK_NULL_HANDLE) {
            vkDestroyBuffer(device, buffer.buffer, nullptr);
        }
        if (buffer.memory != VK_NULL_HANDLE) {
            vkFreeMemory(device, buffer.memory, nullptr);
        }
        buffer = {};
    }

    Image createImage(
        uint32_t width,
        uint32_t height,
        VkFormat format,
        VkImageUsageFlags usage,
        VkImageAspectFlags aspectMask) {
        Image img{};
        img.format = format;

        VkImageCreateInfo imageInfo{};
        imageInfo.sType = VK_STRUCTURE_TYPE_IMAGE_CREATE_INFO;
        imageInfo.imageType = VK_IMAGE_TYPE_2D;
        imageInfo.extent.width = width;
        imageInfo.extent.height = height;
        imageInfo.extent.depth = 1;
        imageInfo.mipLevels = 1;
        imageInfo.arrayLayers = 1;
        imageInfo.format = format;
        imageInfo.tiling = VK_IMAGE_TILING_OPTIMAL;
        imageInfo.initialLayout = VK_IMAGE_LAYOUT_UNDEFINED;
        imageInfo.usage = usage;
        imageInfo.sharingMode = VK_SHARING_MODE_EXCLUSIVE;
        imageInfo.samples = VK_SAMPLE_COUNT_1_BIT;

        if (vkCreateImage(device, &imageInfo, nullptr, &img.image) != VK_SUCCESS) {
            throw std::runtime_error("failed to create image!");
        }

        VkMemoryRequirements memRequirements{};
        vkGetImageMemoryRequirements(device, img.image, &memRequirements);

        VkMemoryAllocateInfo allocInfo{};
        allocInfo.sType = VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO;
        allocInfo.allocationSize = memRequirements.size;
        allocInfo.memoryTypeIndex = findMemoryType(memRequirements.memoryTypeBits, VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT);

        if (vkAllocateMemory(device, &allocInfo, nullptr, &img.memory) != VK_SUCCESS) {
            throw std::runtime_error("failed to allocate image memory!");
        }

        if (vkBindImageMemory(device, img.image, img.memory, 0) != VK_SUCCESS) {
            throw std::runtime_error("failed to bind image memory!");
        }

        VkImageViewCreateInfo viewInfo{};
        viewInfo.sType = VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO;
        viewInfo.image = img.image;
        viewInfo.viewType = VK_IMAGE_VIEW_TYPE_2D;
        viewInfo.format = format;
        viewInfo.subresourceRange.aspectMask = aspectMask;
        viewInfo.subresourceRange.baseMipLevel = 0;
        viewInfo.subresourceRange.levelCount = 1;
        viewInfo.subresourceRange.baseArrayLayer = 0;
        viewInfo.subresourceRange.layerCount = 1;

        if (vkCreateImageView(device, &viewInfo, nullptr, &img.view) != VK_SUCCESS) {
            throw std::runtime_error("failed to create image view!");
        }

        return img;
    }

    void destroyImage(Image& image) {
        if (image.view != VK_NULL_HANDLE) {
            vkDestroyImageView(device, image.view, nullptr);
        }
        if (image.image != VK_NULL_HANDLE) {
            vkDestroyImage(device, image.image, nullptr);
        }
        if (image.memory != VK_NULL_HANDLE) {
            vkFreeMemory(device, image.memory, nullptr);
        }
        image = {};
    }

    void destroyAccelerationStructure(AccelerationStructure& as) {
        if (as.handle != VK_NULL_HANDLE) {
            fpDestroyAccelerationStructureKHR(device, as.handle, nullptr);
        }
        destroyBuffer(as.storage);
        as.handle = VK_NULL_HANDLE;
    }

    VkCommandBuffer beginSingleTimeCommands() {
        VkCommandBufferAllocateInfo allocInfo{};
        allocInfo.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO;
        allocInfo.level = VK_COMMAND_BUFFER_LEVEL_PRIMARY;
        allocInfo.commandPool = commandPool;
        allocInfo.commandBufferCount = 1;

        VkCommandBuffer commandBuffer = VK_NULL_HANDLE;
        vkAllocateCommandBuffers(device, &allocInfo, &commandBuffer);

        VkCommandBufferBeginInfo beginInfo{};
        beginInfo.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO;
        beginInfo.flags = VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT;
        vkBeginCommandBuffer(commandBuffer, &beginInfo);

        return commandBuffer;
    }

    void endSingleTimeCommands(VkCommandBuffer commandBuffer) {
        vkEndCommandBuffer(commandBuffer);

        VkSubmitInfo submitInfo{};
        submitInfo.sType = VK_STRUCTURE_TYPE_SUBMIT_INFO;
        submitInfo.commandBufferCount = 1;
        submitInfo.pCommandBuffers = &commandBuffer;

        vkQueueSubmit(graphicsQueue, 1, &submitInfo, VK_NULL_HANDLE);
        vkQueueWaitIdle(graphicsQueue);
        vkFreeCommandBuffers(device, commandPool, 1, &commandBuffer);
    }

    void transitionImageLayoutOneTime(
        VkImage image,
        VkImageLayout oldLayout,
        VkImageLayout newLayout,
        VkPipelineStageFlags srcStage,
        VkPipelineStageFlags dstStage,
        VkAccessFlags srcAccessMask,
        VkAccessFlags dstAccessMask) {
        VkCommandBuffer cmd = beginSingleTimeCommands();
        transitionImageLayout(cmd, image, oldLayout, newLayout, srcStage, dstStage, srcAccessMask, dstAccessMask, VK_IMAGE_ASPECT_COLOR_BIT);
        endSingleTimeCommands(cmd);
    }

    void transitionImageLayout(
        VkCommandBuffer cmd,
        VkImage image,
        VkImageLayout oldLayout,
        VkImageLayout newLayout,
        VkPipelineStageFlags srcStage,
        VkPipelineStageFlags dstStage,
        VkAccessFlags srcAccessMask,
        VkAccessFlags dstAccessMask,
        VkImageAspectFlags aspectMask) {
        VkImageMemoryBarrier barrier{};
        barrier.sType = VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER;
        barrier.oldLayout = oldLayout;
        barrier.newLayout = newLayout;
        barrier.srcQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
        barrier.dstQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
        barrier.image = image;
        barrier.subresourceRange.aspectMask = aspectMask;
        barrier.subresourceRange.baseMipLevel = 0;
        barrier.subresourceRange.levelCount = 1;
        barrier.subresourceRange.baseArrayLayer = 0;
        barrier.subresourceRange.layerCount = 1;
        barrier.srcAccessMask = srcAccessMask;
        barrier.dstAccessMask = dstAccessMask;

        vkCmdPipelineBarrier(
            cmd,
            srcStage,
            dstStage,
            0,
            0,
            nullptr,
            0,
            nullptr,
            1,
            &barrier);
    }

    void insertAccelerationStructureBarrier(VkCommandBuffer cmd) {
        VkMemoryBarrier barrier{};
        barrier.sType = VK_STRUCTURE_TYPE_MEMORY_BARRIER;
        barrier.srcAccessMask = VK_ACCESS_ACCELERATION_STRUCTURE_WRITE_BIT_KHR;
        barrier.dstAccessMask = VK_ACCESS_ACCELERATION_STRUCTURE_READ_BIT_KHR;

        vkCmdPipelineBarrier(
            cmd,
            VK_PIPELINE_STAGE_ACCELERATION_STRUCTURE_BUILD_BIT_KHR,
            VK_PIPELINE_STAGE_ACCELERATION_STRUCTURE_BUILD_BIT_KHR |
                VK_PIPELINE_STAGE_RAY_TRACING_SHADER_BIT_KHR,
            0,
            1,
            &barrier,
            0,
            nullptr,
            0,
            nullptr);
    }

    static uint32_t alignUp(uint32_t value, uint32_t alignment) {
        return (value + alignment - 1) & ~(alignment - 1);
    }

    static VKAPI_ATTR VkBool32 VKAPI_CALL debugCallback(
        VkDebugUtilsMessageSeverityFlagBitsEXT,
        VkDebugUtilsMessageTypeFlagsEXT,
        const VkDebugUtilsMessengerCallbackDataEXT* pCallbackData,
        void*) {
        std::cerr << "validation layer: " << pCallbackData->pMessage << std::endl;
        return VK_FALSE;
    }
};

int main() {
    HelloTriangleApplication app;

    try {
        app.run();
    } catch (const std::exception& e) {
        std::cerr << e.what() << std::endl;
        return EXIT_FAILURE;
    }

    return EXIT_SUCCESS;
}
