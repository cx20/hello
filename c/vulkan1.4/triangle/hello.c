#define GLFW_INCLUDE_VULKAN
#include <GLFW/glfw3.h>

#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/*
 * Minimal Vulkan triangle in C (GLFW surface)
 */

#define WIDTH 800
#define HEIGHT 600
#define MAX_FRAMES_IN_FLIGHT 2

static const char *VALIDATION_LAYERS[] = {"VK_LAYER_KHRONOS_validation"};
static const uint32_t VALIDATION_LAYER_COUNT = 1;

static const char *DEVICE_EXTENSIONS[] = {VK_KHR_SWAPCHAIN_EXTENSION_NAME};
static const uint32_t DEVICE_EXTENSION_COUNT = 1;

#ifdef NDEBUG
static const bool enableValidationLayers = false;
#else
static const bool enableValidationLayers = true;
#endif

typedef struct QueueFamilyIndices {
    uint32_t graphicsFamily;
    bool graphicsFamilyHasValue;
    uint32_t presentFamily;
    bool presentFamilyHasValue;
} QueueFamilyIndices;

typedef struct SwapChainSupportDetails {
    VkSurfaceCapabilitiesKHR capabilities;
    VkSurfaceFormatKHR *formats;
    uint32_t formatCount;
    VkPresentModeKHR *presentModes;
    uint32_t presentModeCount;
} SwapChainSupportDetails;

typedef struct FileData {
    char *data;
    size_t size;
} FileData;

typedef struct App {
    GLFWwindow *window;

    VkInstance instance;
    VkDebugUtilsMessengerEXT debugMessenger;
    VkSurfaceKHR surface;

    VkPhysicalDevice physicalDevice;
    VkDevice device;

    VkQueue graphicsQueue;
    VkQueue presentQueue;

    VkSwapchainKHR swapChain;
    VkImage *swapChainImages;
    uint32_t swapChainImageCount;
    VkFormat swapChainImageFormat;
    VkExtent2D swapChainExtent;
    VkImageView *swapChainImageViews;
    VkFramebuffer *swapChainFramebuffers;

    VkRenderPass renderPass;
    VkPipelineLayout pipelineLayout;
    VkPipeline graphicsPipeline;

    VkCommandPool commandPool;
    VkCommandBuffer *commandBuffers;

    VkSemaphore imageAvailableSemaphores[MAX_FRAMES_IN_FLIGHT];
    VkSemaphore renderFinishedSemaphores[MAX_FRAMES_IN_FLIGHT];
    VkFence inFlightFences[MAX_FRAMES_IN_FLIGHT];
    VkFence *imagesInFlight;
    size_t currentFrame;

    bool framebufferResized;
} App;

static VkResult CreateDebugUtilsMessengerEXT(VkInstance instance, const VkDebugUtilsMessengerCreateInfoEXT *pCreateInfo, const VkAllocationCallbacks *pAllocator, VkDebugUtilsMessengerEXT *pDebugMessenger) {
    PFN_vkCreateDebugUtilsMessengerEXT func = (PFN_vkCreateDebugUtilsMessengerEXT)vkGetInstanceProcAddr(instance, "vkCreateDebugUtilsMessengerEXT");
    if (func != NULL) {
        return func(instance, pCreateInfo, pAllocator, pDebugMessenger);
    }
    return VK_ERROR_EXTENSION_NOT_PRESENT;
}

static void DestroyDebugUtilsMessengerEXT(VkInstance instance, VkDebugUtilsMessengerEXT debugMessenger, const VkAllocationCallbacks *pAllocator) {
    PFN_vkDestroyDebugUtilsMessengerEXT func = (PFN_vkDestroyDebugUtilsMessengerEXT)vkGetInstanceProcAddr(instance, "vkDestroyDebugUtilsMessengerEXT");
    if (func != NULL) {
        func(instance, debugMessenger, pAllocator);
    }
}

static VKAPI_ATTR VkBool32 VKAPI_CALL debugCallback(VkDebugUtilsMessageSeverityFlagBitsEXT messageSeverity, VkDebugUtilsMessageTypeFlagsEXT messageType, const VkDebugUtilsMessengerCallbackDataEXT *pCallbackData, void *pUserData) {
    (void)messageSeverity;
    (void)messageType;
    (void)pUserData;
    fprintf(stderr, "validation layer: %s\n", pCallbackData->pMessage);
    return VK_FALSE;
}

static bool queueFamilyComplete(const QueueFamilyIndices *idx) {
    return idx->graphicsFamilyHasValue && idx->presentFamilyHasValue;
}

static void framebufferResizeCallback(GLFWwindow *window, int width, int height) {
    (void)width;
    (void)height;
    App *app = (App *)glfwGetWindowUserPointer(window);
    app->framebufferResized = true;
}

static void initWindow(App *app) {
    glfwInit();
    glfwWindowHint(GLFW_CLIENT_API, GLFW_NO_API);
    app->window = glfwCreateWindow(WIDTH, HEIGHT, "Hello Vulkan (C)", NULL, NULL);
    glfwSetWindowUserPointer(app->window, app);
    glfwSetFramebufferSizeCallback(app->window, framebufferResizeCallback);
}

static const char **getRequiredExtensions(uint32_t *extensionCount) {
    uint32_t glfwExtensionCount = 0;
    const char **glfwExtensions = glfwGetRequiredInstanceExtensions(&glfwExtensionCount);
    uint32_t total = glfwExtensionCount + (enableValidationLayers ? 1 : 0);
    const char **extensions = malloc(sizeof(char *) * total);
    for (uint32_t i = 0; i < glfwExtensionCount; i++) {
        extensions[i] = glfwExtensions[i];
    }
    if (enableValidationLayers) {
        extensions[glfwExtensionCount] = VK_EXT_DEBUG_UTILS_EXTENSION_NAME;
    }
    *extensionCount = total;
    return extensions;
}

static bool checkValidationLayerSupport(void) {
    uint32_t layerCount = 0;
    vkEnumerateInstanceLayerProperties(&layerCount, NULL);
    VkLayerProperties *availableLayers = malloc(sizeof(VkLayerProperties) * layerCount);
    vkEnumerateInstanceLayerProperties(&layerCount, availableLayers);

    for (uint32_t i = 0; i < VALIDATION_LAYER_COUNT; i++) {
        bool found = false;
        for (uint32_t j = 0; j < layerCount; j++) {
            if (strcmp(VALIDATION_LAYERS[i], availableLayers[j].layerName) == 0) {
                found = true;
                break;
            }
        }
        if (!found) {
            free(availableLayers);
            return false;
        }
    }
    free(availableLayers);
    return true;
}

static void populateDebugMessengerCreateInfo(VkDebugUtilsMessengerCreateInfoEXT *createInfo) {
    memset(createInfo, 0, sizeof(*createInfo));
    createInfo->sType = VK_STRUCTURE_TYPE_DEBUG_UTILS_MESSENGER_CREATE_INFO_EXT;
    createInfo->messageSeverity = VK_DEBUG_UTILS_MESSAGE_SEVERITY_VERBOSE_BIT_EXT |
                                  VK_DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT |
                                  VK_DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT;
    createInfo->messageType = VK_DEBUG_UTILS_MESSAGE_TYPE_GENERAL_BIT_EXT |
                              VK_DEBUG_UTILS_MESSAGE_TYPE_VALIDATION_BIT_EXT |
                              VK_DEBUG_UTILS_MESSAGE_TYPE_PERFORMANCE_BIT_EXT;
    createInfo->pfnUserCallback = debugCallback;
}

static void createInstance(App *app) {
    if (enableValidationLayers && !checkValidationLayerSupport()) {
        fprintf(stderr, "validation layers requested, but not available!\n");
        exit(EXIT_FAILURE);
    }

    VkApplicationInfo appInfo;
    memset(&appInfo, 0, sizeof(appInfo));
    appInfo.sType = VK_STRUCTURE_TYPE_APPLICATION_INFO;
    appInfo.pApplicationName = "Hello Triangle";
    appInfo.applicationVersion = VK_MAKE_VERSION(1, 0, 0);
    appInfo.pEngineName = "No Engine";
    appInfo.engineVersion = VK_MAKE_VERSION(1, 0, 0);
    appInfo.apiVersion = VK_API_VERSION_1_0;

    VkInstanceCreateInfo createInfo;
    memset(&createInfo, 0, sizeof(createInfo));
    createInfo.sType = VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO;
    createInfo.pApplicationInfo = &appInfo;

    uint32_t extensionCount = 0;
    const char **extensions = getRequiredExtensions(&extensionCount);
    createInfo.enabledExtensionCount = extensionCount;
    createInfo.ppEnabledExtensionNames = extensions;

    VkDebugUtilsMessengerCreateInfoEXT debugCreateInfo;
    if (enableValidationLayers) {
        createInfo.enabledLayerCount = VALIDATION_LAYER_COUNT;
        createInfo.ppEnabledLayerNames = VALIDATION_LAYERS;
        populateDebugMessengerCreateInfo(&debugCreateInfo);
        createInfo.pNext = &debugCreateInfo;
    } else {
        createInfo.enabledLayerCount = 0;
        createInfo.pNext = NULL;
    }

    if (vkCreateInstance(&createInfo, NULL, &app->instance) != VK_SUCCESS) {
        fprintf(stderr, "failed to create instance!\n");
        free(extensions);
        exit(EXIT_FAILURE);
    }
    free(extensions);
}

static void setupDebugMessenger(App *app) {
    if (!enableValidationLayers) {
        return;
    }
    VkDebugUtilsMessengerCreateInfoEXT createInfo;
    populateDebugMessengerCreateInfo(&createInfo);
    if (CreateDebugUtilsMessengerEXT(app->instance, &createInfo, NULL, &app->debugMessenger) != VK_SUCCESS) {
        fprintf(stderr, "failed to set up debug messenger!\n");
        exit(EXIT_FAILURE);
    }
}

static void createSurface(App *app) {
    if (glfwCreateWindowSurface(app->instance, app->window, NULL, &app->surface) != VK_SUCCESS) {
        fprintf(stderr, "failed to create window surface!\n");
        exit(EXIT_FAILURE);
    }
}

static SwapChainSupportDetails querySwapChainSupport(App *app, VkPhysicalDevice device) {
    SwapChainSupportDetails details;
    memset(&details, 0, sizeof(details));

    vkGetPhysicalDeviceSurfaceCapabilitiesKHR(device, app->surface, &details.capabilities);

    uint32_t formatCount = 0;
    vkGetPhysicalDeviceSurfaceFormatsKHR(device, app->surface, &formatCount, NULL);
    if (formatCount != 0) {
        details.formats = malloc(sizeof(VkSurfaceFormatKHR) * formatCount);
        vkGetPhysicalDeviceSurfaceFormatsKHR(device, app->surface, &formatCount, details.formats);
        details.formatCount = formatCount;
    }

    uint32_t presentModeCount = 0;
    vkGetPhysicalDeviceSurfacePresentModesKHR(device, app->surface, &presentModeCount, NULL);
    if (presentModeCount != 0) {
        details.presentModes = malloc(sizeof(VkPresentModeKHR) * presentModeCount);
        vkGetPhysicalDeviceSurfacePresentModesKHR(device, app->surface, &presentModeCount, details.presentModes);
        details.presentModeCount = presentModeCount;
    }
    return details;
}

static void freeSwapChainSupportDetails(SwapChainSupportDetails *details) {
    free(details->formats);
    free(details->presentModes);
    details->formats = NULL;
    details->presentModes = NULL;
    details->formatCount = 0;
    details->presentModeCount = 0;
}

static bool checkDeviceExtensionSupport(VkPhysicalDevice device) {
    uint32_t extensionCount = 0;
    vkEnumerateDeviceExtensionProperties(device, NULL, &extensionCount, NULL);
    VkExtensionProperties *available = malloc(sizeof(VkExtensionProperties) * extensionCount);
    vkEnumerateDeviceExtensionProperties(device, NULL, &extensionCount, available);

    for (uint32_t i = 0; i < DEVICE_EXTENSION_COUNT; i++) {
        bool found = false;
        for (uint32_t j = 0; j < extensionCount; j++) {
            if (strcmp(DEVICE_EXTENSIONS[i], available[j].extensionName) == 0) {
                found = true;
                break;
            }
        }
        if (!found) {
            free(available);
            return false;
        }
    }
    free(available);
    return true;
}

static QueueFamilyIndices findQueueFamilies(App *app, VkPhysicalDevice device) {
    QueueFamilyIndices indices = {0};

    uint32_t queueFamilyCount = 0;
    vkGetPhysicalDeviceQueueFamilyProperties(device, &queueFamilyCount, NULL);
    VkQueueFamilyProperties *queueFamilies = malloc(sizeof(VkQueueFamilyProperties) * queueFamilyCount);
    vkGetPhysicalDeviceQueueFamilyProperties(device, &queueFamilyCount, queueFamilies);

    for (uint32_t i = 0; i < queueFamilyCount; i++) {
        if (queueFamilies[i].queueFlags & VK_QUEUE_GRAPHICS_BIT) {
            indices.graphicsFamily = i;
            indices.graphicsFamilyHasValue = true;
        }
        VkBool32 presentSupport = VK_FALSE;
        vkGetPhysicalDeviceSurfaceSupportKHR(device, i, app->surface, &presentSupport);
        if (presentSupport) {
            indices.presentFamily = i;
            indices.presentFamilyHasValue = true;
        }
        if (queueFamilyComplete(&indices)) {
            break;
        }
    }
    free(queueFamilies);
    return indices;
}

static bool isDeviceSuitable(App *app, VkPhysicalDevice device) {
    QueueFamilyIndices indices = findQueueFamilies(app, device);
    bool extensionsSupported = checkDeviceExtensionSupport(device);

    bool swapChainAdequate = false;
    if (extensionsSupported) {
        SwapChainSupportDetails details = querySwapChainSupport(app, device);
        swapChainAdequate = details.formatCount > 0 && details.presentModeCount > 0;
        freeSwapChainSupportDetails(&details);
    }

    return queueFamilyComplete(&indices) && extensionsSupported && swapChainAdequate;
}

static void pickPhysicalDevice(App *app) {
    uint32_t deviceCount = 0;
    vkEnumeratePhysicalDevices(app->instance, &deviceCount, NULL);
    if (deviceCount == 0) {
        fprintf(stderr, "failed to find GPUs with Vulkan support!\n");
        exit(EXIT_FAILURE);
    }
    VkPhysicalDevice *devices = malloc(sizeof(VkPhysicalDevice) * deviceCount);
    vkEnumeratePhysicalDevices(app->instance, &deviceCount, devices);
    for (uint32_t i = 0; i < deviceCount; i++) {
        if (isDeviceSuitable(app, devices[i])) {
            app->physicalDevice = devices[i];
            break;
        }
    }
    free(devices);
    if (app->physicalDevice == VK_NULL_HANDLE) {
        fprintf(stderr, "failed to find a suitable GPU!\n");
        exit(EXIT_FAILURE);
    }
}

static void createLogicalDevice(App *app) {
    QueueFamilyIndices indices = findQueueFamilies(app, app->physicalDevice);
    uint32_t uniqueFamilies[2];
    uint32_t uniqueCount = 0;
    uniqueFamilies[uniqueCount++] = indices.graphicsFamily;
    if (indices.presentFamily != indices.graphicsFamily) {
        uniqueFamilies[uniqueCount++] = indices.presentFamily;
    }

    float queuePriority = 1.0f;
    VkDeviceQueueCreateInfo queueInfos[2];
    memset(queueInfos, 0, sizeof(queueInfos));
    for (uint32_t i = 0; i < uniqueCount; i++) {
        queueInfos[i].sType = VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO;
        queueInfos[i].queueFamilyIndex = uniqueFamilies[i];
        queueInfos[i].queueCount = 1;
        queueInfos[i].pQueuePriorities = &queuePriority;
    }

    VkPhysicalDeviceFeatures deviceFeatures = {0};

    VkDeviceCreateInfo createInfo;
    memset(&createInfo, 0, sizeof(createInfo));
    createInfo.sType = VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO;
    createInfo.queueCreateInfoCount = uniqueCount;
    createInfo.pQueueCreateInfos = queueInfos;
    createInfo.pEnabledFeatures = &deviceFeatures;
    createInfo.enabledExtensionCount = DEVICE_EXTENSION_COUNT;
    createInfo.ppEnabledExtensionNames = DEVICE_EXTENSIONS;
    if (enableValidationLayers) {
        createInfo.enabledLayerCount = VALIDATION_LAYER_COUNT;
        createInfo.ppEnabledLayerNames = VALIDATION_LAYERS;
    } else {
        createInfo.enabledLayerCount = 0;
    }

    if (vkCreateDevice(app->physicalDevice, &createInfo, NULL, &app->device) != VK_SUCCESS) {
        fprintf(stderr, "failed to create logical device!\n");
        exit(EXIT_FAILURE);
    }
    vkGetDeviceQueue(app->device, indices.graphicsFamily, 0, &app->graphicsQueue);
    vkGetDeviceQueue(app->device, indices.presentFamily, 0, &app->presentQueue);
}

static VkSurfaceFormatKHR chooseSwapSurfaceFormat(const SwapChainSupportDetails *details) {
    for (uint32_t i = 0; i < details->formatCount; i++) {
        if (details->formats[i].format == VK_FORMAT_B8G8R8A8_SRGB &&
            details->formats[i].colorSpace == VK_COLOR_SPACE_SRGB_NONLINEAR_KHR) {
            return details->formats[i];
        }
    }
    return details->formats[0];
}

static VkPresentModeKHR chooseSwapPresentMode(const SwapChainSupportDetails *details) {
    for (uint32_t i = 0; i < details->presentModeCount; i++) {
        if (details->presentModes[i] == VK_PRESENT_MODE_MAILBOX_KHR) {
            return details->presentModes[i];
        }
    }
    return VK_PRESENT_MODE_FIFO_KHR;
}

static VkExtent2D chooseSwapExtent(const SwapChainSupportDetails *details, GLFWwindow *window) {
    if (details->capabilities.currentExtent.width != UINT32_MAX) {
        return details->capabilities.currentExtent;
    }
    int width = 0;
    int height = 0;
    glfwGetFramebufferSize(window, &width, &height);
    VkExtent2D actual = {(uint32_t)width, (uint32_t)height};
    if (actual.width < details->capabilities.minImageExtent.width) actual.width = details->capabilities.minImageExtent.width;
    if (actual.width > details->capabilities.maxImageExtent.width) actual.width = details->capabilities.maxImageExtent.width;
    if (actual.height < details->capabilities.minImageExtent.height) actual.height = details->capabilities.minImageExtent.height;
    if (actual.height > details->capabilities.maxImageExtent.height) actual.height = details->capabilities.maxImageExtent.height;
    return actual;
}

static void createSwapChain(App *app) {
    SwapChainSupportDetails support = querySwapChainSupport(app, app->physicalDevice);
    VkSurfaceFormatKHR surfaceFormat = chooseSwapSurfaceFormat(&support);
    VkPresentModeKHR presentMode = chooseSwapPresentMode(&support);
    VkExtent2D extent = chooseSwapExtent(&support, app->window);

    uint32_t imageCount = support.capabilities.minImageCount + 1;
    if (support.capabilities.maxImageCount > 0 && imageCount > support.capabilities.maxImageCount) {
        imageCount = support.capabilities.maxImageCount;
    }

    VkSwapchainCreateInfoKHR createInfo;
    memset(&createInfo, 0, sizeof(createInfo));
    createInfo.sType = VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR;
    createInfo.surface = app->surface;
    createInfo.minImageCount = imageCount;
    createInfo.imageFormat = surfaceFormat.format;
    createInfo.imageColorSpace = surfaceFormat.colorSpace;
    createInfo.imageExtent = extent;
    createInfo.imageArrayLayers = 1;
    createInfo.imageUsage = VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT;

    QueueFamilyIndices indices = findQueueFamilies(app, app->physicalDevice);
    uint32_t queueFamilyIndices[2] = {indices.graphicsFamily, indices.presentFamily};
    if (indices.graphicsFamily != indices.presentFamily) {
        createInfo.imageSharingMode = VK_SHARING_MODE_CONCURRENT;
        createInfo.queueFamilyIndexCount = 2;
        createInfo.pQueueFamilyIndices = queueFamilyIndices;
    } else {
        createInfo.imageSharingMode = VK_SHARING_MODE_EXCLUSIVE;
    }

    createInfo.preTransform = support.capabilities.currentTransform;
    createInfo.compositeAlpha = VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR;
    createInfo.presentMode = presentMode;
    createInfo.clipped = VK_TRUE;
    createInfo.oldSwapchain = VK_NULL_HANDLE;

    if (vkCreateSwapchainKHR(app->device, &createInfo, NULL, &app->swapChain) != VK_SUCCESS) {
        freeSwapChainSupportDetails(&support);
        fprintf(stderr, "failed to create swap chain!\n");
        exit(EXIT_FAILURE);
    }

    vkGetSwapchainImagesKHR(app->device, app->swapChain, &imageCount, NULL);
    app->swapChainImages = malloc(sizeof(VkImage) * imageCount);
    vkGetSwapchainImagesKHR(app->device, app->swapChain, &imageCount, app->swapChainImages);
    app->swapChainImageCount = imageCount;
    app->swapChainImageFormat = surfaceFormat.format;
    app->swapChainExtent = extent;

    freeSwapChainSupportDetails(&support);
}

static void createImageViews(App *app) {
    app->swapChainImageViews = malloc(sizeof(VkImageView) * app->swapChainImageCount);
    for (uint32_t i = 0; i < app->swapChainImageCount; i++) {
        VkImageViewCreateInfo createInfo;
        memset(&createInfo, 0, sizeof(createInfo));
        createInfo.sType = VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO;
        createInfo.image = app->swapChainImages[i];
        createInfo.viewType = VK_IMAGE_VIEW_TYPE_2D;
        createInfo.format = app->swapChainImageFormat;
        createInfo.components = (VkComponentMapping){VK_COMPONENT_SWIZZLE_IDENTITY, VK_COMPONENT_SWIZZLE_IDENTITY, VK_COMPONENT_SWIZZLE_IDENTITY, VK_COMPONENT_SWIZZLE_IDENTITY};
        createInfo.subresourceRange.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT;
        createInfo.subresourceRange.baseMipLevel = 0;
        createInfo.subresourceRange.levelCount = 1;
        createInfo.subresourceRange.baseArrayLayer = 0;
        createInfo.subresourceRange.layerCount = 1;
        if (vkCreateImageView(app->device, &createInfo, NULL, &app->swapChainImageViews[i]) != VK_SUCCESS) {
            fprintf(stderr, "failed to create image view!\n");
            exit(EXIT_FAILURE);
        }
    }
}

static void createRenderPass(App *app) {
    VkAttachmentDescription colorAttachment;
    memset(&colorAttachment, 0, sizeof(colorAttachment));
    colorAttachment.format = app->swapChainImageFormat;
    colorAttachment.samples = VK_SAMPLE_COUNT_1_BIT;
    colorAttachment.loadOp = VK_ATTACHMENT_LOAD_OP_CLEAR;
    colorAttachment.storeOp = VK_ATTACHMENT_STORE_OP_STORE;
    colorAttachment.stencilLoadOp = VK_ATTACHMENT_LOAD_OP_DONT_CARE;
    colorAttachment.stencilStoreOp = VK_ATTACHMENT_STORE_OP_DONT_CARE;
    colorAttachment.initialLayout = VK_IMAGE_LAYOUT_UNDEFINED;
    colorAttachment.finalLayout = VK_IMAGE_LAYOUT_PRESENT_SRC_KHR;

    VkAttachmentReference colorAttachmentRef = {0, VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL};

    VkSubpassDescription subpass;
    memset(&subpass, 0, sizeof(subpass));
    subpass.pipelineBindPoint = VK_PIPELINE_BIND_POINT_GRAPHICS;
    subpass.colorAttachmentCount = 1;
    subpass.pColorAttachments = &colorAttachmentRef;

    VkSubpassDependency dependency;
    memset(&dependency, 0, sizeof(dependency));
    dependency.srcSubpass = VK_SUBPASS_EXTERNAL;
    dependency.dstSubpass = 0;
    dependency.srcStageMask = VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT;
    dependency.dstStageMask = VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT;
    dependency.dstAccessMask = VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT;

    VkRenderPassCreateInfo renderPassInfo;
    memset(&renderPassInfo, 0, sizeof(renderPassInfo));
    renderPassInfo.sType = VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO;
    renderPassInfo.attachmentCount = 1;
    renderPassInfo.pAttachments = &colorAttachment;
    renderPassInfo.subpassCount = 1;
    renderPassInfo.pSubpasses = &subpass;
    renderPassInfo.dependencyCount = 1;
    renderPassInfo.pDependencies = &dependency;

    if (vkCreateRenderPass(app->device, &renderPassInfo, NULL, &app->renderPass) != VK_SUCCESS) {
        fprintf(stderr, "failed to create render pass!\n");
        exit(EXIT_FAILURE);
    }
}

static FileData readFile(const char *filename) {
    FileData data = {0};
    FILE *f = fopen(filename, "rb");
    if (!f) {
        fprintf(stderr, "failed to open %s\n", filename);
        exit(EXIT_FAILURE);
    }
    fseek(f, 0, SEEK_END);
    long size = ftell(f);
    if (size < 0) {
        fclose(f);
        fprintf(stderr, "failed to size %s\n", filename);
        exit(EXIT_FAILURE);
    }
    rewind(f);
    data.size = (size_t)size;
    data.data = malloc(data.size);
    if (fread(data.data, 1, data.size, f) != data.size) {
        fclose(f);
        fprintf(stderr, "failed to read %s\n", filename);
        exit(EXIT_FAILURE);
    }
    fclose(f);
    return data;
}

static VkShaderModule createShaderModule(App *app, const FileData *code) {
    VkShaderModuleCreateInfo createInfo;
    memset(&createInfo, 0, sizeof(createInfo));
    createInfo.sType = VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO;
    createInfo.codeSize = code->size;
    createInfo.pCode = (const uint32_t *)code->data;
    VkShaderModule module;
    if (vkCreateShaderModule(app->device, &createInfo, NULL, &module) != VK_SUCCESS) {
        fprintf(stderr, "failed to create shader module!\n");
        exit(EXIT_FAILURE);
    }
    return module;
}

static void createGraphicsPipeline(App *app) {
    FileData vert = readFile("hello_vert.spv");
    FileData frag = readFile("hello_frag.spv");

    VkShaderModule vertModule = createShaderModule(app, &vert);
    VkShaderModule fragModule = createShaderModule(app, &frag);

    VkPipelineShaderStageCreateInfo stages[2];
    memset(stages, 0, sizeof(stages));
    stages[0].sType = VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO;
    stages[0].stage = VK_SHADER_STAGE_VERTEX_BIT;
    stages[0].module = vertModule;
    stages[0].pName = "main";
    stages[1].sType = VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO;
    stages[1].stage = VK_SHADER_STAGE_FRAGMENT_BIT;
    stages[1].module = fragModule;
    stages[1].pName = "main";

    VkPipelineVertexInputStateCreateInfo vertexInput;
    memset(&vertexInput, 0, sizeof(vertexInput));
    vertexInput.sType = VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO;

    VkPipelineInputAssemblyStateCreateInfo inputAssembly;
    memset(&inputAssembly, 0, sizeof(inputAssembly));
    inputAssembly.sType = VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO;
    inputAssembly.topology = VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST;

    VkViewport viewport = {0.0f, 0.0f, (float)app->swapChainExtent.width, (float)app->swapChainExtent.height, 0.0f, 1.0f};
    VkRect2D scissor = {{0, 0}, app->swapChainExtent};

    VkPipelineViewportStateCreateInfo viewportState;
    memset(&viewportState, 0, sizeof(viewportState));
    viewportState.sType = VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO;
    viewportState.viewportCount = 1;
    viewportState.pViewports = &viewport;
    viewportState.scissorCount = 1;
    viewportState.pScissors = &scissor;

    VkPipelineRasterizationStateCreateInfo rasterizer;
    memset(&rasterizer, 0, sizeof(rasterizer));
    rasterizer.sType = VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO;
    rasterizer.polygonMode = VK_POLYGON_MODE_FILL;
    rasterizer.cullMode = VK_CULL_MODE_BACK_BIT;
    rasterizer.frontFace = VK_FRONT_FACE_CLOCKWISE;
    rasterizer.lineWidth = 1.0f;

    VkPipelineMultisampleStateCreateInfo multisampling;
    memset(&multisampling, 0, sizeof(multisampling));
    multisampling.sType = VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO;
    multisampling.rasterizationSamples = VK_SAMPLE_COUNT_1_BIT;

    VkPipelineColorBlendAttachmentState colorBlendAttachment;
    memset(&colorBlendAttachment, 0, sizeof(colorBlendAttachment));
    colorBlendAttachment.colorWriteMask = VK_COLOR_COMPONENT_R_BIT | VK_COLOR_COMPONENT_G_BIT |
                                          VK_COLOR_COMPONENT_B_BIT | VK_COLOR_COMPONENT_A_BIT;

    VkPipelineColorBlendStateCreateInfo colorBlending;
    memset(&colorBlending, 0, sizeof(colorBlending));
    colorBlending.sType = VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO;
    colorBlending.attachmentCount = 1;
    colorBlending.pAttachments = &colorBlendAttachment;

    VkPipelineLayoutCreateInfo layoutInfo;
    memset(&layoutInfo, 0, sizeof(layoutInfo));
    layoutInfo.sType = VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO;

    if (vkCreatePipelineLayout(app->device, &layoutInfo, NULL, &app->pipelineLayout) != VK_SUCCESS) {
        fprintf(stderr, "failed to create pipeline layout!\n");
        exit(EXIT_FAILURE);
    }

    VkGraphicsPipelineCreateInfo pipelineInfo;
    memset(&pipelineInfo, 0, sizeof(pipelineInfo));
    pipelineInfo.sType = VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO;
    pipelineInfo.stageCount = 2;
    pipelineInfo.pStages = stages;
    pipelineInfo.pVertexInputState = &vertexInput;
    pipelineInfo.pInputAssemblyState = &inputAssembly;
    pipelineInfo.pViewportState = &viewportState;
    pipelineInfo.pRasterizationState = &rasterizer;
    pipelineInfo.pMultisampleState = &multisampling;
    pipelineInfo.pColorBlendState = &colorBlending;
    pipelineInfo.layout = app->pipelineLayout;
    pipelineInfo.renderPass = app->renderPass;
    pipelineInfo.subpass = 0;

    if (vkCreateGraphicsPipelines(app->device, VK_NULL_HANDLE, 1, &pipelineInfo, NULL, &app->graphicsPipeline) != VK_SUCCESS) {
        fprintf(stderr, "failed to create graphics pipeline!\n");
        exit(EXIT_FAILURE);
    }

    vkDestroyShaderModule(app->device, fragModule, NULL);
    vkDestroyShaderModule(app->device, vertModule, NULL);
    free(vert.data);
    free(frag.data);
}

static void createFramebuffers(App *app) {
    app->swapChainFramebuffers = malloc(sizeof(VkFramebuffer) * app->swapChainImageCount);
    for (uint32_t i = 0; i < app->swapChainImageCount; i++) {
        VkImageView attachments[] = {app->swapChainImageViews[i]};
        VkFramebufferCreateInfo info;
        memset(&info, 0, sizeof(info));
        info.sType = VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO;
        info.renderPass = app->renderPass;
        info.attachmentCount = 1;
        info.pAttachments = attachments;
        info.width = app->swapChainExtent.width;
        info.height = app->swapChainExtent.height;
        info.layers = 1;
        if (vkCreateFramebuffer(app->device, &info, NULL, &app->swapChainFramebuffers[i]) != VK_SUCCESS) {
            fprintf(stderr, "failed to create framebuffer!\n");
            exit(EXIT_FAILURE);
        }
    }
}

static void createCommandPool(App *app) {
    QueueFamilyIndices indices = findQueueFamilies(app, app->physicalDevice);
    VkCommandPoolCreateInfo info;
    memset(&info, 0, sizeof(info));
    info.sType = VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO;
    info.queueFamilyIndex = indices.graphicsFamily;
    if (vkCreateCommandPool(app->device, &info, NULL, &app->commandPool) != VK_SUCCESS) {
        fprintf(stderr, "failed to create command pool!\n");
        exit(EXIT_FAILURE);
    }
}

static void createCommandBuffers(App *app) {
    app->commandBuffers = malloc(sizeof(VkCommandBuffer) * app->swapChainImageCount);
    VkCommandBufferAllocateInfo alloc;
    memset(&alloc, 0, sizeof(alloc));
    alloc.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO;
    alloc.commandPool = app->commandPool;
    alloc.level = VK_COMMAND_BUFFER_LEVEL_PRIMARY;
    alloc.commandBufferCount = app->swapChainImageCount;
    if (vkAllocateCommandBuffers(app->device, &alloc, app->commandBuffers) != VK_SUCCESS) {
        fprintf(stderr, "failed to allocate command buffers!\n");
        exit(EXIT_FAILURE);
    }

    for (uint32_t i = 0; i < app->swapChainImageCount; i++) {
        VkCommandBufferBeginInfo begin;
        memset(&begin, 0, sizeof(begin));
        begin.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO;
        vkBeginCommandBuffer(app->commandBuffers[i], &begin);

        VkRenderPassBeginInfo rp;
        memset(&rp, 0, sizeof(rp));
        rp.sType = VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO;
        rp.renderPass = app->renderPass;
        rp.framebuffer = app->swapChainFramebuffers[i];
        rp.renderArea.offset = (VkOffset2D){0, 0};
        rp.renderArea.extent = app->swapChainExtent;
        VkClearValue clear = {.color = {{0.0f, 0.0f, 0.0f, 1.0f}}};
        rp.clearValueCount = 1;
        rp.pClearValues = &clear;

        vkCmdBeginRenderPass(app->commandBuffers[i], &rp, VK_SUBPASS_CONTENTS_INLINE);
        vkCmdBindPipeline(app->commandBuffers[i], VK_PIPELINE_BIND_POINT_GRAPHICS, app->graphicsPipeline);
        vkCmdDraw(app->commandBuffers[i], 3, 1, 0, 0);
        vkCmdEndRenderPass(app->commandBuffers[i]);
        vkEndCommandBuffer(app->commandBuffers[i]);
    }
}

static void createSyncObjects(App *app) {
    VkSemaphoreCreateInfo sem;
    memset(&sem, 0, sizeof(sem));
    sem.sType = VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO;
    VkFenceCreateInfo fence;
    memset(&fence, 0, sizeof(fence));
    fence.sType = VK_STRUCTURE_TYPE_FENCE_CREATE_INFO;
    fence.flags = VK_FENCE_CREATE_SIGNALED_BIT;
    for (int i = 0; i < MAX_FRAMES_IN_FLIGHT; i++) {
        if (vkCreateSemaphore(app->device, &sem, NULL, &app->imageAvailableSemaphores[i]) != VK_SUCCESS ||
            vkCreateSemaphore(app->device, &sem, NULL, &app->renderFinishedSemaphores[i]) != VK_SUCCESS ||
            vkCreateFence(app->device, &fence, NULL, &app->inFlightFences[i]) != VK_SUCCESS) {
            fprintf(stderr, "failed to create sync objects!\n");
            exit(EXIT_FAILURE);
        }
    }
    app->imagesInFlight = calloc(app->swapChainImageCount, sizeof(VkFence));
    app->currentFrame = 0;
}

static void recreateSwapChain(App *app) {
    int width = 0, height = 0;
    glfwGetFramebufferSize(app->window, &width, &height);
    while (width == 0 || height == 0) {
        glfwGetFramebufferSize(app->window, &width, &height);
        glfwWaitEvents();
    }
    vkDeviceWaitIdle(app->device);

    for (uint32_t i = 0; i < app->swapChainImageCount; i++) {
        vkDestroyFramebuffer(app->device, app->swapChainFramebuffers[i], NULL);
        vkDestroyImageView(app->device, app->swapChainImageViews[i], NULL);
    }
    free(app->swapChainFramebuffers);
    free(app->swapChainImageViews);
    free(app->swapChainImages);

    vkDestroyPipeline(app->device, app->graphicsPipeline, NULL);
    vkDestroyPipelineLayout(app->device, app->pipelineLayout, NULL);
    vkDestroyRenderPass(app->device, app->renderPass, NULL);

    createSwapChain(app);
    createImageViews(app);
    createRenderPass(app);
    createGraphicsPipeline(app);
    createFramebuffers(app);
    createCommandBuffers(app);
}

static void drawFrame(App *app) {
    vkWaitForFences(app->device, 1, &app->inFlightFences[app->currentFrame], VK_TRUE, UINT64_MAX);

    uint32_t imageIndex = 0;
    VkResult result = vkAcquireNextImageKHR(app->device, app->swapChain, UINT64_MAX, app->imageAvailableSemaphores[app->currentFrame], VK_NULL_HANDLE, &imageIndex);
    if (result == VK_ERROR_OUT_OF_DATE_KHR) {
        recreateSwapChain(app);
        return;
    } else if (result != VK_SUCCESS && result != VK_SUBOPTIMAL_KHR) {
        fprintf(stderr, "failed to acquire swap chain image!\n");
        exit(EXIT_FAILURE);
    }

    if (app->imagesInFlight[imageIndex] != VK_NULL_HANDLE) {
        vkWaitForFences(app->device, 1, &app->imagesInFlight[imageIndex], VK_TRUE, UINT64_MAX);
    }
    app->imagesInFlight[imageIndex] = app->inFlightFences[app->currentFrame];

    VkSubmitInfo submitInfo;
    memset(&submitInfo, 0, sizeof(submitInfo));
    submitInfo.sType = VK_STRUCTURE_TYPE_SUBMIT_INFO;
    VkSemaphore waitSemaphores[] = {app->imageAvailableSemaphores[app->currentFrame]};
    VkPipelineStageFlags waitStages[] = {VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT};
    submitInfo.waitSemaphoreCount = 1;
    submitInfo.pWaitSemaphores = waitSemaphores;
    submitInfo.pWaitDstStageMask = waitStages;
    submitInfo.commandBufferCount = 1;
    submitInfo.pCommandBuffers = &app->commandBuffers[imageIndex];
    VkSemaphore signalSemaphores[] = {app->renderFinishedSemaphores[app->currentFrame]};
    submitInfo.signalSemaphoreCount = 1;
    submitInfo.pSignalSemaphores = signalSemaphores;

    vkResetFences(app->device, 1, &app->inFlightFences[app->currentFrame]);
    if (vkQueueSubmit(app->graphicsQueue, 1, &submitInfo, app->inFlightFences[app->currentFrame]) != VK_SUCCESS) {
        fprintf(stderr, "failed to submit draw command buffer!\n");
        exit(EXIT_FAILURE);
    }

    VkPresentInfoKHR presentInfo;
    memset(&presentInfo, 0, sizeof(presentInfo));
    presentInfo.sType = VK_STRUCTURE_TYPE_PRESENT_INFO_KHR;
    presentInfo.waitSemaphoreCount = 1;
    presentInfo.pWaitSemaphores = signalSemaphores;
    VkSwapchainKHR swapChains[] = {app->swapChain};
    presentInfo.swapchainCount = 1;
    presentInfo.pSwapchains = swapChains;
    presentInfo.pImageIndices = &imageIndex;

    result = vkQueuePresentKHR(app->presentQueue, &presentInfo);
    if (result == VK_ERROR_OUT_OF_DATE_KHR || result == VK_SUBOPTIMAL_KHR || app->framebufferResized) {
        app->framebufferResized = false;
        recreateSwapChain(app);
    } else if (result != VK_SUCCESS) {
        fprintf(stderr, "failed to present swap chain image!\n");
        exit(EXIT_FAILURE);
    }

    app->currentFrame = (app->currentFrame + 1) % MAX_FRAMES_IN_FLIGHT;
}

static void createCommandPool(App *app);

static void initVulkan(App *app) {
    createInstance(app);
    setupDebugMessenger(app);
    createSurface(app);
    pickPhysicalDevice(app);
    createLogicalDevice(app);
    createSwapChain(app);
    createImageViews(app);
    createRenderPass(app);
    createGraphicsPipeline(app);
    createFramebuffers(app);
    createCommandPool(app);
    createCommandBuffers(app);
    createSyncObjects(app);
}

static void cleanup(App *app) {
    vkDeviceWaitIdle(app->device);

    for (int i = 0; i < MAX_FRAMES_IN_FLIGHT; i++) {
        vkDestroySemaphore(app->device, app->renderFinishedSemaphores[i], NULL);
        vkDestroySemaphore(app->device, app->imageAvailableSemaphores[i], NULL);
        vkDestroyFence(app->device, app->inFlightFences[i], NULL);
    }

    for (uint32_t i = 0; i < app->swapChainImageCount; i++) {
        vkDestroyFramebuffer(app->device, app->swapChainFramebuffers[i], NULL);
        vkDestroyImageView(app->device, app->swapChainImageViews[i], NULL);
    }
    free(app->swapChainFramebuffers);
    free(app->swapChainImageViews);
    free(app->swapChainImages);

    vkDestroyPipeline(app->device, app->graphicsPipeline, NULL);
    vkDestroyPipelineLayout(app->device, app->pipelineLayout, NULL);
    vkDestroyRenderPass(app->device, app->renderPass, NULL);

    vkDestroyCommandPool(app->device, app->commandPool, NULL);
    vkDestroySwapchainKHR(app->device, app->swapChain, NULL);
    vkDestroyDevice(app->device, NULL);

    if (enableValidationLayers) {
        DestroyDebugUtilsMessengerEXT(app->instance, app->debugMessenger, NULL);
    }
    vkDestroySurfaceKHR(app->instance, app->surface, NULL);
    vkDestroyInstance(app->instance, NULL);

    glfwDestroyWindow(app->window);
    glfwTerminate();
}

static void mainLoop(App *app) {
    while (!glfwWindowShouldClose(app->window)) {
        glfwPollEvents();
        drawFrame(app);
    }
    vkDeviceWaitIdle(app->device);
}

int main(void) {
    App app = {0};
    initWindow(&app);
    initVulkan(&app);
    mainLoop(&app);
    cleanup(&app);
    return 0;
}
