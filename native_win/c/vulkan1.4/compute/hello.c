#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <vulkan/vulkan.h>
#include <vulkan/vulkan_win32.h>
#include <stdint.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

#pragma comment(lib, "user32.lib")
#pragma comment(lib, "gdi32.lib")

// ------------------------------------------------------------
// Config
// ------------------------------------------------------------
#define APP_NAME               "Vulkan 1.4 Compute Harmonograph (No external libs)"
#define WIN_W                  960
#define WIN_H                  720

#define MAX_FRAMES_IN_FLIGHT   2
#define VERTEX_COUNT           500000u

static const char* g_deviceExts[] = { VK_KHR_SWAPCHAIN_EXTENSION_NAME };

#ifdef NDEBUG
static const bool g_enableValidation = false;
#else
static const bool g_enableValidation = true;
#endif

static const char* g_validationLayers[] = { "VK_LAYER_KHRONOS_validation" };

// ------------------------------------------------------------
// Simple logging / fail
// ------------------------------------------------------------
static void die(const char* msg) {
    MessageBoxA(NULL, msg, "Fatal", MB_OK | MB_ICONERROR);
    ExitProcess(1);
}

static void dieVk(VkResult r, const char* where) {
    char buf[512];
    snprintf(buf, sizeof(buf), "%s failed: VkResult=%d", where, (int)r);
    die(buf);
}

// ------------------------------------------------------------
// File read
// ------------------------------------------------------------
typedef struct FileData {
    uint8_t* data;
    size_t   size;
} FileData;

static FileData readFile(const char* path) {
    FileData f = {0};
    FILE* fp = NULL;
    fopen_s(&fp, path, "rb");
    if (!fp) {
        char buf[512];
        snprintf(buf, sizeof(buf), "Cannot open file: %s", path);
        die(buf);
    }
    fseek(fp, 0, SEEK_END);
    f.size = (size_t)ftell(fp);
    fseek(fp, 0, SEEK_SET);

    f.data = (uint8_t*)malloc(f.size);
    if (!f.data) die("malloc failed");

    if (fread(f.data, 1, f.size, fp) != f.size) die("fread failed");
    fclose(fp);
    return f;
}

static void freeFile(FileData* f) {
    if (f->data) free(f->data);
    f->data = NULL;
    f->size = 0;
}

// ------------------------------------------------------------
// Win32 window
// ------------------------------------------------------------
static HWND      g_hwnd;
static HINSTANCE g_hinst;
static bool      g_running = true;
static bool      g_resized = false;

static LRESULT CALLBACK WndProc(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam) {
    switch (msg) {
    case WM_CLOSE:
        g_running = false;
        PostQuitMessage(0);
        return 0;
    case WM_SIZE:
        g_resized = true;
        return 0;
    case WM_KEYDOWN:
        if (wParam == VK_ESCAPE) {
            g_running = false;
            PostQuitMessage(0);
        }
        return 0;
    default:
        return DefWindowProc(hWnd, msg, wParam, lParam);
    }
}

static void createWindowWin32(void) {
    g_hinst = GetModuleHandleW(NULL);

    WNDCLASSEXA wc;
    memset(&wc, 0, sizeof(wc));
    wc.cbSize        = sizeof(wc);
    wc.style         = CS_HREDRAW | CS_VREDRAW;
    wc.lpfnWndProc   = WndProc;
    wc.hInstance     = g_hinst;
    wc.hCursor       = LoadCursor(NULL, IDC_ARROW);
    wc.lpszClassName = "VkHarmonographClass";

    if (!RegisterClassExA(&wc)) die("RegisterClassEx failed");

    RECT rc = { 0, 0, WIN_W, WIN_H };
    AdjustWindowRect(&rc, WS_OVERLAPPEDWINDOW, FALSE);

    g_hwnd = CreateWindowExA(
        0, wc.lpszClassName, APP_NAME,
        WS_OVERLAPPEDWINDOW,
        CW_USEDEFAULT, CW_USEDEFAULT,
        rc.right - rc.left, rc.bottom - rc.top,
        NULL, NULL, g_hinst, NULL);

    if (!g_hwnd) die("CreateWindowEx failed");
    ShowWindow(g_hwnd, SW_SHOW);
}

// ------------------------------------------------------------
// Vulkan: Debug utils messenger
// ------------------------------------------------------------
static VkDebugUtilsMessengerEXT g_dbgMessenger;

static VKAPI_ATTR VkBool32 VKAPI_CALL dbgCb(
    VkDebugUtilsMessageSeverityFlagBitsEXT severity,
    VkDebugUtilsMessageTypeFlagsEXT types,
    const VkDebugUtilsMessengerCallbackDataEXT* cb,
    void* user)
{
    (void)types; (void)user;
    if (severity >= VK_DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT) {
        OutputDebugStringA(cb->pMessage);
        OutputDebugStringA("\n");
    }
    return VK_FALSE;
}

static VkResult CreateDebugUtilsMessengerEXT(
    VkInstance instance,
    const VkDebugUtilsMessengerCreateInfoEXT* ci,
    const VkAllocationCallbacks* ac,
    VkDebugUtilsMessengerEXT* out)
{
    PFN_vkCreateDebugUtilsMessengerEXT fn =
        (PFN_vkCreateDebugUtilsMessengerEXT)vkGetInstanceProcAddr(instance, "vkCreateDebugUtilsMessengerEXT");
    if (!fn) return VK_ERROR_EXTENSION_NOT_PRESENT;
    return fn(instance, ci, ac, out);
}

static void DestroyDebugUtilsMessengerEXT(
    VkInstance instance,
    VkDebugUtilsMessengerEXT messenger,
    const VkAllocationCallbacks* ac)
{
    PFN_vkDestroyDebugUtilsMessengerEXT fn =
        (PFN_vkDestroyDebugUtilsMessengerEXT)vkGetInstanceProcAddr(instance, "vkDestroyDebugUtilsMessengerEXT");
    if (fn) fn(instance, messenger, ac);
}

// ------------------------------------------------------------
// Vulkan globals
// ------------------------------------------------------------
static VkInstance       g_instance;
static VkSurfaceKHR     g_surface;

static VkPhysicalDevice g_phys;
static VkDevice         g_dev;

static uint32_t         g_qfam;
static VkQueue          g_queue;

static VkSwapchainKHR   g_swapchain;
static VkFormat         g_scfmt;
static VkExtent2D       g_extent;
static VkImage*         g_scImages;
static VkImageView*     g_scViews;
static VkFramebuffer*   g_framebuffers;
static uint32_t         g_scCount;

static VkRenderPass     g_renderPass;

static VkDescriptorSetLayout g_dsl;
static VkDescriptorPool      g_dpool;
static VkDescriptorSet       g_dset;

static VkPipelineLayout g_plCompute;
static VkPipeline       g_pCompute;

static VkPipelineLayout g_plGfx;
static VkPipeline       g_pGfx;

static VkCommandPool    g_cmdPool;
static VkCommandBuffer  g_cmd[MAX_FRAMES_IN_FLIGHT];

static VkSemaphore      g_imgAvail[MAX_FRAMES_IN_FLIGHT];
static VkSemaphore      g_renderDone[MAX_FRAMES_IN_FLIGHT];
static VkFence          g_inFlight[MAX_FRAMES_IN_FLIGHT];
static uint32_t         g_frameIndex = 0;

// Buffers
typedef struct Buffer {
    VkBuffer        buf;
    VkDeviceMemory  mem;
    VkDeviceSize    size;
} Buffer;

static Buffer g_posBuf;   // storage
static Buffer g_colBuf;   // storage
static Buffer g_ubo;      // uniform

// Params for UBO (std140)
#pragma pack(push, 1)
typedef struct ParamsUBO {
    uint32_t max_num;
    float    dt;
    float    scale;
    float    pad0;

    float A1,f1,p1,d1;
    float A2,f2,p2,d2;
    float A3,f3,p3,d3;
    float A4,f4,p4,d4;
} ParamsUBO;
#pragma pack(pop)

static ParamsUBO g_params;

// ------------------------------------------------------------
// Helpers
// ------------------------------------------------------------
static bool hasLayer(const char* name) {
    uint32_t n = 0;
    vkEnumerateInstanceLayerProperties(&n, NULL);
    VkLayerProperties* props = (VkLayerProperties*)malloc(sizeof(VkLayerProperties)*n);
    vkEnumerateInstanceLayerProperties(&n, props);
    bool ok = false;
    for (uint32_t i=0;i<n;i++){
        if (strcmp(props[i].layerName, name)==0) { ok = true; break; }
    }
    free(props);
    return ok;
}

static bool hasDeviceExtension(VkPhysicalDevice pd, const char* ext) {
    uint32_t n=0;
    vkEnumerateDeviceExtensionProperties(pd, NULL, &n, NULL);
    VkExtensionProperties* p = (VkExtensionProperties*)malloc(sizeof(VkExtensionProperties)*n);
    vkEnumerateDeviceExtensionProperties(pd, NULL, &n, p);
    bool ok=false;
    for (uint32_t i=0;i<n;i++){
        if (strcmp(p[i].extensionName, ext)==0) { ok=true; break; }
    }
    free(p);
    return ok;
}

static uint32_t findMemoryType(uint32_t typeBits, VkMemoryPropertyFlags flags) {
    VkPhysicalDeviceMemoryProperties mp;
    vkGetPhysicalDeviceMemoryProperties(g_phys, &mp);
    for (uint32_t i=0;i<mp.memoryTypeCount;i++){
        if ((typeBits & (1u<<i)) && ((mp.memoryTypes[i].propertyFlags & flags) == flags)) return i;
    }
    die("No suitable memory type");
    return 0;
}

static void createBuffer(VkDeviceSize size, VkBufferUsageFlags usage, VkMemoryPropertyFlags flags, Buffer* out) {
    out->size = size;

    VkBufferCreateInfo bi = {0};
    bi.sType = VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO;
    bi.size  = size;
    bi.usage = usage;
    bi.sharingMode = VK_SHARING_MODE_EXCLUSIVE;

    VkResult r = vkCreateBuffer(g_dev, &bi, NULL, &out->buf);
    if (r) dieVk(r, "vkCreateBuffer");

    VkMemoryRequirements req;
    vkGetBufferMemoryRequirements(g_dev, out->buf, &req);

    VkMemoryAllocateInfo ai = {0};
    ai.sType = VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO;
    ai.allocationSize = req.size;
    ai.memoryTypeIndex = findMemoryType(req.memoryTypeBits, flags);

    r = vkAllocateMemory(g_dev, &ai, NULL, &out->mem);
    if (r) dieVk(r, "vkAllocateMemory");

    r = vkBindBufferMemory(g_dev, out->buf, out->mem, 0);
    if (r) dieVk(r, "vkBindBufferMemory");
}

static void destroyBuffer(Buffer* b) {
    if (b->buf) vkDestroyBuffer(g_dev, b->buf, NULL);
    if (b->mem) vkFreeMemory(g_dev, b->mem, NULL);
    memset(b, 0, sizeof(*b));
}

static VkShaderModule createShaderModuleFromFile(const char* path) {
    FileData f = readFile(path);

    VkShaderModuleCreateInfo ci = {0};
    ci.sType = VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO;
    ci.codeSize = f.size;
    ci.pCode = (const uint32_t*)f.data;

    VkShaderModule m;
    VkResult r = vkCreateShaderModule(g_dev, &ci, NULL, &m);
    freeFile(&f);
    if (r) dieVk(r, "vkCreateShaderModule");
    return m;
}

// ------------------------------------------------------------
// Vulkan init
// ------------------------------------------------------------
static void createInstanceAndSurface(void) {
    if (g_enableValidation) {
        for (int i=0;i<(int)(sizeof(g_validationLayers)/sizeof(g_validationLayers[0]));i++){
            if (!hasLayer(g_validationLayers[i])) die("Validation layer not available (VK_LAYER_KHRONOS_validation)");
        }
    }

    VkApplicationInfo ai = {0};
    ai.sType = VK_STRUCTURE_TYPE_APPLICATION_INFO;
    ai.pApplicationName = APP_NAME;
    ai.applicationVersion = VK_MAKE_VERSION(1,0,0);
    ai.pEngineName = "No Engine";
    ai.engineVersion = VK_MAKE_VERSION(1,0,0);
    ai.apiVersion = VK_API_VERSION_1_4;

    const char* exts[8];
    uint32_t extCount = 0;
    exts[extCount++] = VK_KHR_SURFACE_EXTENSION_NAME;
    exts[extCount++] = VK_KHR_WIN32_SURFACE_EXTENSION_NAME;
    if (g_enableValidation) exts[extCount++] = VK_EXT_DEBUG_UTILS_EXTENSION_NAME;

    VkInstanceCreateInfo ici = {0};
    ici.sType = VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO;
    ici.pApplicationInfo = &ai;
    ici.enabledExtensionCount = extCount;
    ici.ppEnabledExtensionNames = exts;

    VkDebugUtilsMessengerCreateInfoEXT dbgCI = {0};
    if (g_enableValidation) {
        dbgCI.sType = VK_STRUCTURE_TYPE_DEBUG_UTILS_MESSENGER_CREATE_INFO_EXT;
        dbgCI.messageSeverity =
            VK_DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT |
            VK_DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT;
        dbgCI.messageType =
            VK_DEBUG_UTILS_MESSAGE_TYPE_GENERAL_BIT_EXT |
            VK_DEBUG_UTILS_MESSAGE_TYPE_VALIDATION_BIT_EXT |
            VK_DEBUG_UTILS_MESSAGE_TYPE_PERFORMANCE_BIT_EXT;
        dbgCI.pfnUserCallback = dbgCb;

        ici.enabledLayerCount = 1;
        ici.ppEnabledLayerNames = g_validationLayers;
        ici.pNext = &dbgCI;
    }

    VkResult r = vkCreateInstance(&ici, NULL, &g_instance);
    if (r) dieVk(r, "vkCreateInstance");

    if (g_enableValidation) {
        r = CreateDebugUtilsMessengerEXT(g_instance, &dbgCI, NULL, &g_dbgMessenger);
        if (r) dieVk(r, "CreateDebugUtilsMessengerEXT");
    }

    VkWin32SurfaceCreateInfoKHR sci = {0};
    sci.sType = VK_STRUCTURE_TYPE_WIN32_SURFACE_CREATE_INFO_KHR;
    sci.hinstance = g_hinst;
    sci.hwnd = g_hwnd;

    r = vkCreateWin32SurfaceKHR(g_instance, &sci, NULL, &g_surface);
    if (r) dieVk(r, "vkCreateWin32SurfaceKHR");
}

static bool isGoodDevice(VkPhysicalDevice pd, uint32_t* outQfam) {
    // swapchain ext
    for (uint32_t i=0;i<(uint32_t)(sizeof(g_deviceExts)/sizeof(g_deviceExts[0]));i++){
        if (!hasDeviceExtension(pd, g_deviceExts[i])) return false;
    }

    uint32_t qn=0;
    vkGetPhysicalDeviceQueueFamilyProperties(pd, &qn, NULL);
    VkQueueFamilyProperties* q = (VkQueueFamilyProperties*)malloc(sizeof(VkQueueFamilyProperties)*qn);
    vkGetPhysicalDeviceQueueFamilyProperties(pd, &qn, q);

    for (uint32_t i=0;i<qn;i++){
        VkBool32 present = VK_FALSE;
        vkGetPhysicalDeviceSurfaceSupportKHR(pd, i, g_surface, &present);

        bool graphics = (q[i].queueFlags & VK_QUEUE_GRAPHICS_BIT) != 0;
        bool compute  = (q[i].queueFlags & VK_QUEUE_COMPUTE_BIT)  != 0;

        if (graphics && compute && present) {
            *outQfam = i;
            free(q);
            return true;
        }
    }
    free(q);
    return false;
}

static void pickDeviceAndCreateLogical(void) {
    uint32_t n=0;
    vkEnumeratePhysicalDevices(g_instance, &n, NULL);
    if (!n) die("No Vulkan physical devices found.");

    VkPhysicalDevice* devs = (VkPhysicalDevice*)malloc(sizeof(VkPhysicalDevice)*n);
    vkEnumeratePhysicalDevices(g_instance, &n, devs);

    g_phys = VK_NULL_HANDLE;
    for (uint32_t i=0;i<n;i++){
        uint32_t fam = 0;
        if (isGoodDevice(devs[i], &fam)) {
            g_phys = devs[i];
            g_qfam = fam;
            break;
        }
    }
    free(devs);
    if (!g_phys) die("No suitable device found (need graphics+present+compute in same queue family).");

    float prio = 1.0f;
    VkDeviceQueueCreateInfo qci = {0};
    qci.sType = VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO;
    qci.queueFamilyIndex = g_qfam;
    qci.queueCount = 1;
    qci.pQueuePriorities = &prio;

    VkPhysicalDeviceFeatures feats;
    memset(&feats, 0, sizeof(feats));

    VkDeviceCreateInfo dci = {0};
    dci.sType = VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO;
    dci.queueCreateInfoCount = 1;
    dci.pQueueCreateInfos = &qci;
    dci.enabledExtensionCount = (uint32_t)(sizeof(g_deviceExts)/sizeof(g_deviceExts[0]));
    dci.ppEnabledExtensionNames = g_deviceExts;
    dci.pEnabledFeatures = &feats;

    if (g_enableValidation) {
        dci.enabledLayerCount = 1;
        dci.ppEnabledLayerNames = g_validationLayers;
    }

    VkResult r = vkCreateDevice(g_phys, &dci, NULL, &g_dev);
    if (r) dieVk(r, "vkCreateDevice");

    vkGetDeviceQueue(g_dev, g_qfam, 0, &g_queue);
}

static VkSurfaceFormatKHR chooseSurfaceFormat(VkPhysicalDevice pd) {
    uint32_t n=0;
    vkGetPhysicalDeviceSurfaceFormatsKHR(pd, g_surface, &n, NULL);
    VkSurfaceFormatKHR* fmts = (VkSurfaceFormatKHR*)malloc(sizeof(VkSurfaceFormatKHR)*n);
    vkGetPhysicalDeviceSurfaceFormatsKHR(pd, g_surface, &n, fmts);

    VkSurfaceFormatKHR chosen = fmts[0];
    for (uint32_t i=0;i<n;i++){
        if (fmts[i].format == VK_FORMAT_B8G8R8A8_UNORM &&
            fmts[i].colorSpace == VK_COLOR_SPACE_SRGB_NONLINEAR_KHR)
        {
            chosen = fmts[i];
            break;
        }
    }
    free(fmts);
    return chosen;
}

static VkPresentModeKHR choosePresentMode(VkPhysicalDevice pd) {
    uint32_t n=0;
    vkGetPhysicalDeviceSurfacePresentModesKHR(pd, g_surface, &n, NULL);
    VkPresentModeKHR* pm = (VkPresentModeKHR*)malloc(sizeof(VkPresentModeKHR)*n);
    vkGetPhysicalDeviceSurfacePresentModesKHR(pd, g_surface, &n, pm);

    VkPresentModeKHR chosen = VK_PRESENT_MODE_FIFO_KHR; // always available
    for (uint32_t i=0;i<n;i++){
        if (pm[i] == VK_PRESENT_MODE_MAILBOX_KHR) { chosen = pm[i]; break; }
    }
    free(pm);
    return chosen;
}

static VkExtent2D chooseExtent(const VkSurfaceCapabilitiesKHR* caps) {
    if (caps->currentExtent.width != 0xFFFFFFFFu) return caps->currentExtent;

    RECT rc;
    GetClientRect(g_hwnd, &rc);
    uint32_t w = (uint32_t)(rc.right - rc.left);
    uint32_t h = (uint32_t)(rc.bottom - rc.top);

    VkExtent2D e;
    e.width  = w < caps->minImageExtent.width ? caps->minImageExtent.width :
               w > caps->maxImageExtent.width ? caps->maxImageExtent.width : w;
    e.height = h < caps->minImageExtent.height ? caps->minImageExtent.height :
               h > caps->maxImageExtent.height ? caps->maxImageExtent.height : h;
    return e;
}

static void cleanupSwapchain(void) {
    if (g_framebuffers) {
        for (uint32_t i=0;i<g_scCount;i++) vkDestroyFramebuffer(g_dev, g_framebuffers[i], NULL);
        free(g_framebuffers);
        g_framebuffers = NULL;
    }
    if (g_scViews) {
        for (uint32_t i=0;i<g_scCount;i++) vkDestroyImageView(g_dev, g_scViews[i], NULL);
        free(g_scViews);
        g_scViews = NULL;
    }
    if (g_scImages) {
        free(g_scImages);
        g_scImages = NULL;
    }
    if (g_swapchain) {
        vkDestroySwapchainKHR(g_dev, g_swapchain, NULL);
        g_swapchain = VK_NULL_HANDLE;
    }
}

static void createSwapchainAndViews(void) {
    VkSurfaceCapabilitiesKHR caps;
    vkGetPhysicalDeviceSurfaceCapabilitiesKHR(g_phys, g_surface, &caps);

    VkSurfaceFormatKHR fmt = chooseSurfaceFormat(g_phys);
    VkPresentModeKHR pm    = choosePresentMode(g_phys);
    VkExtent2D extent      = chooseExtent(&caps);

    uint32_t imgCount = caps.minImageCount + 1;
    if (caps.maxImageCount && imgCount > caps.maxImageCount) imgCount = caps.maxImageCount;

    VkSwapchainCreateInfoKHR ci = {0};
    ci.sType = VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR;
    ci.surface = g_surface;
    ci.minImageCount = imgCount;
    ci.imageFormat = fmt.format;
    ci.imageColorSpace = fmt.colorSpace;
    ci.imageExtent = extent;
    ci.imageArrayLayers = 1;
    ci.imageUsage = VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT;
    ci.imageSharingMode = VK_SHARING_MODE_EXCLUSIVE;
    ci.preTransform = caps.currentTransform;
    ci.compositeAlpha = VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR;
    ci.presentMode = pm;
    ci.clipped = VK_TRUE;
    ci.oldSwapchain = VK_NULL_HANDLE;

    VkResult r = vkCreateSwapchainKHR(g_dev, &ci, NULL, &g_swapchain);
    if (r) dieVk(r, "vkCreateSwapchainKHR");

    g_scfmt = fmt.format;
    g_extent = extent;

    vkGetSwapchainImagesKHR(g_dev, g_swapchain, &g_scCount, NULL);
    g_scImages = (VkImage*)malloc(sizeof(VkImage)*g_scCount);
    vkGetSwapchainImagesKHR(g_dev, g_swapchain, &g_scCount, g_scImages);

    g_scViews = (VkImageView*)malloc(sizeof(VkImageView)*g_scCount);
    for (uint32_t i=0;i<g_scCount;i++){
        VkImageViewCreateInfo vi = {0};
        vi.sType = VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO;
        vi.image = g_scImages[i];
        vi.viewType = VK_IMAGE_VIEW_TYPE_2D;
        vi.format = g_scfmt;
        vi.subresourceRange.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT;
        vi.subresourceRange.levelCount = 1;
        vi.subresourceRange.layerCount = 1;

        r = vkCreateImageView(g_dev, &vi, NULL, &g_scViews[i]);
        if (r) dieVk(r, "vkCreateImageView");
    }
}

static void createRenderPass(void) {
    VkAttachmentDescription color = {0};
    color.format = g_scfmt;
    color.samples = VK_SAMPLE_COUNT_1_BIT;
    color.loadOp = VK_ATTACHMENT_LOAD_OP_CLEAR;
    color.storeOp = VK_ATTACHMENT_STORE_OP_STORE;
    color.initialLayout = VK_IMAGE_LAYOUT_UNDEFINED;
    color.finalLayout   = VK_IMAGE_LAYOUT_PRESENT_SRC_KHR;

    VkAttachmentReference ref = {0};
    ref.attachment = 0;
    ref.layout = VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL;

    VkSubpassDescription sub = {0};
    sub.pipelineBindPoint = VK_PIPELINE_BIND_POINT_GRAPHICS;
    sub.colorAttachmentCount = 1;
    sub.pColorAttachments = &ref;

    VkSubpassDependency dep = {0};
    dep.srcSubpass = VK_SUBPASS_EXTERNAL;
    dep.dstSubpass = 0;
    dep.srcStageMask = VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT;
    dep.dstStageMask = VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT;
    dep.dstAccessMask = VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT;

    VkRenderPassCreateInfo rp = {0};
    rp.sType = VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO;
    rp.attachmentCount = 1;
    rp.pAttachments = &color;
    rp.subpassCount = 1;
    rp.pSubpasses = &sub;
    rp.dependencyCount = 1;
    rp.pDependencies = &dep;

    VkResult r = vkCreateRenderPass(g_dev, &rp, NULL, &g_renderPass);
    if (r) dieVk(r, "vkCreateRenderPass");
}

static void createFramebuffers(void) {
    g_framebuffers = (VkFramebuffer*)malloc(sizeof(VkFramebuffer)*g_scCount);

    for (uint32_t i=0;i<g_scCount;i++){
        VkImageView atts[] = { g_scViews[i] };

        VkFramebufferCreateInfo fi = {0};
        fi.sType = VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO;
        fi.renderPass = g_renderPass;
        fi.attachmentCount = 1;
        fi.pAttachments = atts;
        fi.width  = g_extent.width;
        fi.height = g_extent.height;
        fi.layers = 1;

        VkResult r = vkCreateFramebuffer(g_dev, &fi, NULL, &g_framebuffers[i]);
        if (r) dieVk(r, "vkCreateFramebuffer");
    }
}

static void createDescriptorLayoutAndSet(void) {
    VkDescriptorSetLayoutBinding b[3];
    memset(b, 0, sizeof(b));

    // Positions SSBO
    b[0].binding = 0;
    b[0].descriptorType = VK_DESCRIPTOR_TYPE_STORAGE_BUFFER;
    b[0].descriptorCount = 1;
    b[0].stageFlags = VK_SHADER_STAGE_COMPUTE_BIT | VK_SHADER_STAGE_VERTEX_BIT;

    // Colors SSBO
    b[1].binding = 1;
    b[1].descriptorType = VK_DESCRIPTOR_TYPE_STORAGE_BUFFER;
    b[1].descriptorCount = 1;
    b[1].stageFlags = VK_SHADER_STAGE_COMPUTE_BIT | VK_SHADER_STAGE_VERTEX_BIT;

    // UBO
    b[2].binding = 2;
    b[2].descriptorType = VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER;
    b[2].descriptorCount = 1;
    b[2].stageFlags = VK_SHADER_STAGE_COMPUTE_BIT;

    VkDescriptorSetLayoutCreateInfo ci = {0};
    ci.sType = VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO;
    ci.bindingCount = 3;
    ci.pBindings = b;

    VkResult r = vkCreateDescriptorSetLayout(g_dev, &ci, NULL, &g_dsl);
    if (r) dieVk(r, "vkCreateDescriptorSetLayout");

    VkDescriptorPoolSize ps[2];
    ps[0].type = VK_DESCRIPTOR_TYPE_STORAGE_BUFFER;
    ps[0].descriptorCount = 2;
    ps[1].type = VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER;
    ps[1].descriptorCount = 1;

    VkDescriptorPoolCreateInfo pci = {0};
    pci.sType = VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO;
    pci.maxSets = 1;
    pci.poolSizeCount = 2;
    pci.pPoolSizes = ps;

    r = vkCreateDescriptorPool(g_dev, &pci, NULL, &g_dpool);
    if (r) dieVk(r, "vkCreateDescriptorPool");

    VkDescriptorSetAllocateInfo ai = {0};
    ai.sType = VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO;
    ai.descriptorPool = g_dpool;
    ai.descriptorSetCount = 1;
    ai.pSetLayouts = &g_dsl;

    r = vkAllocateDescriptorSets(g_dev, &ai, &g_dset);
    if (r) dieVk(r, "vkAllocateDescriptorSets");
}

static void createPipelines(void) {
    // --- Compute pipeline ---
    VkShaderModule smComp = createShaderModuleFromFile("hello_comp.spv");

    VkPipelineLayoutCreateInfo plci = {0};
    plci.sType = VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO;
    plci.setLayoutCount = 1;
    plci.pSetLayouts = &g_dsl;

    VkResult r = vkCreatePipelineLayout(g_dev, &plci, NULL, &g_plCompute);
    if (r) dieVk(r, "vkCreatePipelineLayout (compute)");

    VkComputePipelineCreateInfo cpi = {0};
    cpi.sType = VK_STRUCTURE_TYPE_COMPUTE_PIPELINE_CREATE_INFO;
    cpi.stage.sType = VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO;
    cpi.stage.stage = VK_SHADER_STAGE_COMPUTE_BIT;
    cpi.stage.module = smComp;
    cpi.stage.pName = "main";
    cpi.layout = g_plCompute;

    r = vkCreateComputePipelines(g_dev, VK_NULL_HANDLE, 1, &cpi, NULL, &g_pCompute);
    if (r) dieVk(r, "vkCreateComputePipelines");

    vkDestroyShaderModule(g_dev, smComp, NULL);

    // --- Graphics pipeline ---
    VkShaderModule smVS = createShaderModuleFromFile("hello_vert.spv");
    VkShaderModule smFS = createShaderModuleFromFile("hello_frag.spv");

    VkPipelineLayoutCreateInfo gl = {0};
    gl.sType = VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO;
    gl.setLayoutCount = 1;
    gl.pSetLayouts = &g_dsl;

    r = vkCreatePipelineLayout(g_dev, &gl, NULL, &g_plGfx);
    if (r) dieVk(r, "vkCreatePipelineLayout (gfx)");

    VkPipelineShaderStageCreateInfo stages[2];
    memset(stages, 0, sizeof(stages));
    stages[0].sType  = VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO;
    stages[0].stage  = VK_SHADER_STAGE_VERTEX_BIT;
    stages[0].module = smVS;
    stages[0].pName  = "main";

    stages[1].sType  = VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO;
    stages[1].stage  = VK_SHADER_STAGE_FRAGMENT_BIT;
    stages[1].module = smFS;
    stages[1].pName  = "main";

    VkPipelineVertexInputStateCreateInfo vi = {0};
    vi.sType = VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO;

    VkPipelineInputAssemblyStateCreateInfo ia = {0};
    ia.sType = VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO;
    ia.topology = VK_PRIMITIVE_TOPOLOGY_LINE_STRIP;
    ia.primitiveRestartEnable = VK_FALSE;

    VkViewport vp = {0};
    vp.x = 0; vp.y = 0;
    vp.width  = (float)g_extent.width;
    vp.height = (float)g_extent.height;
    vp.minDepth = 0.0f;
    vp.maxDepth = 1.0f;

    VkRect2D sc = {0};
    sc.offset.x = 0; sc.offset.y = 0;
    sc.extent = g_extent;

    VkPipelineViewportStateCreateInfo vs = {0};
    vs.sType = VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO;
    vs.viewportCount = 1;
    vs.pViewports = &vp;
    vs.scissorCount = 1;
    vs.pScissors = &sc;

    VkPipelineRasterizationStateCreateInfo rs = {0};
    rs.sType = VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO;
    rs.polygonMode = VK_POLYGON_MODE_FILL;
    rs.cullMode = VK_CULL_MODE_NONE;
    rs.frontFace = VK_FRONT_FACE_COUNTER_CLOCKWISE;
    rs.lineWidth = 1.0f;

    VkPipelineMultisampleStateCreateInfo ms = {0};
    ms.sType = VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO;
    ms.rasterizationSamples = VK_SAMPLE_COUNT_1_BIT;

    VkPipelineColorBlendAttachmentState cba = {0};
    cba.colorWriteMask =
        VK_COLOR_COMPONENT_R_BIT | VK_COLOR_COMPONENT_G_BIT |
        VK_COLOR_COMPONENT_B_BIT | VK_COLOR_COMPONENT_A_BIT;
    cba.blendEnable = VK_FALSE;

    VkPipelineColorBlendStateCreateInfo cb = {0};
    cb.sType = VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO;
    cb.attachmentCount = 1;
    cb.pAttachments = &cba;

    VkGraphicsPipelineCreateInfo gp = {0};
    gp.sType = VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO;
    gp.stageCount = 2;
    gp.pStages = stages;
    gp.pVertexInputState = &vi;
    gp.pInputAssemblyState = &ia;
    gp.pViewportState = &vs;
    gp.pRasterizationState = &rs;
    gp.pMultisampleState = &ms;
    gp.pColorBlendState = &cb;
    gp.layout = g_plGfx;
    gp.renderPass = g_renderPass;
    gp.subpass = 0;

    r = vkCreateGraphicsPipelines(g_dev, VK_NULL_HANDLE, 1, &gp, NULL, &g_pGfx);
    if (r) dieVk(r, "vkCreateGraphicsPipelines");

    vkDestroyShaderModule(g_dev, smVS, NULL);
    vkDestroyShaderModule(g_dev, smFS, NULL);
}

static void createCommandObjects(void) {
    VkCommandPoolCreateInfo pci = {0};
    pci.sType = VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO;
    pci.queueFamilyIndex = g_qfam;
    pci.flags = VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT;

    VkResult r = vkCreateCommandPool(g_dev, &pci, NULL, &g_cmdPool);
    if (r) dieVk(r, "vkCreateCommandPool");

    VkCommandBufferAllocateInfo ai = {0};
    ai.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO;
    ai.commandPool = g_cmdPool;
    ai.level = VK_COMMAND_BUFFER_LEVEL_PRIMARY;
    ai.commandBufferCount = MAX_FRAMES_IN_FLIGHT;

    r = vkAllocateCommandBuffers(g_dev, &ai, g_cmd);
    if (r) dieVk(r, "vkAllocateCommandBuffers");
}

static void createSync(void) {
    VkSemaphoreCreateInfo si = {0};
    si.sType = VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO;

    VkFenceCreateInfo fi = {0};
    fi.sType = VK_STRUCTURE_TYPE_FENCE_CREATE_INFO;
    fi.flags = VK_FENCE_CREATE_SIGNALED_BIT;

    for (uint32_t i=0;i<MAX_FRAMES_IN_FLIGHT;i++){
        VkResult r = vkCreateSemaphore(g_dev, &si, NULL, &g_imgAvail[i]);
        if (r) dieVk(r, "vkCreateSemaphore imgAvail");
        r = vkCreateSemaphore(g_dev, &si, NULL, &g_renderDone[i]);
        if (r) dieVk(r, "vkCreateSemaphore renderDone");
        r = vkCreateFence(g_dev, &fi, NULL, &g_inFlight[i]);
        if (r) dieVk(r, "vkCreateFence");
    }
}

static void createBuffersAndDescriptors(void) {
    // SSBOs (device local)
    createBuffer((VkDeviceSize)VERTEX_COUNT * 16u,
                 VK_BUFFER_USAGE_STORAGE_BUFFER_BIT,
                 VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT,
                 &g_posBuf);

    createBuffer((VkDeviceSize)VERTEX_COUNT * 16u,
                 VK_BUFFER_USAGE_STORAGE_BUFFER_BIT,
                 VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT,
                 &g_colBuf);

    // UBO (host visible)
    createBuffer((VkDeviceSize)sizeof(ParamsUBO),
                 VK_BUFFER_USAGE_UNIFORM_BUFFER_BIT,
                 VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | VK_MEMORY_PROPERTY_HOST_COHERENT_BIT,
                 &g_ubo);

    // write descriptor set
    VkDescriptorBufferInfo posInfo = { g_posBuf.buf, 0, g_posBuf.size };
    VkDescriptorBufferInfo colInfo = { g_colBuf.buf, 0, g_colBuf.size };
    VkDescriptorBufferInfo uboInfo = { g_ubo.buf,    0, sizeof(ParamsUBO) };

    VkWriteDescriptorSet w[3];
    memset(w, 0, sizeof(w));

    w[0].sType = VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET;
    w[0].dstSet = g_dset;
    w[0].dstBinding = 0;
    w[0].descriptorType = VK_DESCRIPTOR_TYPE_STORAGE_BUFFER;
    w[0].descriptorCount = 1;
    w[0].pBufferInfo = &posInfo;

    w[1].sType = VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET;
    w[1].dstSet = g_dset;
    w[1].dstBinding = 1;
    w[1].descriptorType = VK_DESCRIPTOR_TYPE_STORAGE_BUFFER;
    w[1].descriptorCount = 1;
    w[1].pBufferInfo = &colInfo;

    w[2].sType = VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET;
    w[2].dstSet = g_dset;
    w[2].dstBinding = 2;
    w[2].descriptorType = VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER;
    w[2].descriptorCount = 1;
    w[2].pBufferInfo = &uboInfo;

    vkUpdateDescriptorSets(g_dev, 3, w, 0, NULL);

    // init params
    g_params.max_num = VERTEX_COUNT;
    g_params.dt = 0.001f;
    g_params.scale = 0.02f;
    g_params.pad0 = 0.0f;

    g_params.A1 = 50.0f; g_params.f1 = 2.0f; g_params.p1 = 1.0f/16.0f; g_params.d1 = 0.02f;
    g_params.A2 = 50.0f; g_params.f2 = 2.0f; g_params.p2 = 3.0f/2.0f;  g_params.d2 = 0.0315f;
    g_params.A3 = 50.0f; g_params.f3 = 2.0f; g_params.p3 = 13.0f/15.0f; g_params.d3 = 0.02f;
    g_params.A4 = 50.0f; g_params.f4 = 2.0f; g_params.p4 = 1.0f;        g_params.d4 = 0.02f;
}

static void updateUBO(void) {
    void* p = NULL;
    VkResult r = vkMapMemory(g_dev, g_ubo.mem, 0, sizeof(ParamsUBO), 0, &p);
    if (r) dieVk(r, "vkMapMemory");
    memcpy(p, &g_params, sizeof(ParamsUBO));
    vkUnmapMemory(g_dev, g_ubo.mem);
}

static void recordCmd(VkCommandBuffer cmd, uint32_t imageIndex) {
    VkCommandBufferBeginInfo bi = {0};
    bi.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO;
    VkResult r = vkBeginCommandBuffer(cmd, &bi);
    if (r) dieVk(r, "vkBeginCommandBuffer");

    // --- compute ---
    vkCmdBindPipeline(cmd, VK_PIPELINE_BIND_POINT_COMPUTE, g_pCompute);
    vkCmdBindDescriptorSets(cmd, VK_PIPELINE_BIND_POINT_COMPUTE, g_plCompute, 0, 1, &g_dset, 0, NULL);

    uint32_t groupsX = (VERTEX_COUNT + 255u) / 256u;
    vkCmdDispatch(cmd, groupsX, 1, 1);

    // barrier: compute writes -> vertex reads
    VkBufferMemoryBarrier bmb[2];
    memset(bmb, 0, sizeof(bmb));
    bmb[0].sType = VK_STRUCTURE_TYPE_BUFFER_MEMORY_BARRIER;
    bmb[0].srcAccessMask = VK_ACCESS_SHADER_WRITE_BIT;
    bmb[0].dstAccessMask = VK_ACCESS_SHADER_READ_BIT;
    bmb[0].srcQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
    bmb[0].dstQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
    bmb[0].buffer = g_posBuf.buf;
    bmb[0].offset = 0;
    bmb[0].size   = g_posBuf.size;

    bmb[1] = bmb[0];
    bmb[1].buffer = g_colBuf.buf;
    bmb[1].size   = g_colBuf.size;

    vkCmdPipelineBarrier(
        cmd,
        VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT,
        VK_PIPELINE_STAGE_VERTEX_SHADER_BIT,
        0,
        0, NULL,
        2, bmb,
        0, NULL);

    // --- render ---
    VkClearValue cv;
    cv.color.float32[0] = 0.0f;
    cv.color.float32[1] = 0.0f;
    cv.color.float32[2] = 0.0f;
    cv.color.float32[3] = 1.0f;

    VkRenderPassBeginInfo rp = {0};
    rp.sType = VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO;
    rp.renderPass = g_renderPass;
    rp.framebuffer = g_framebuffers[imageIndex];
    rp.renderArea.offset.x = 0;
    rp.renderArea.offset.y = 0;
    rp.renderArea.extent   = g_extent;
    rp.clearValueCount = 1;
    rp.pClearValues = &cv;

    vkCmdBeginRenderPass(cmd, &rp, VK_SUBPASS_CONTENTS_INLINE);

    vkCmdBindPipeline(cmd, VK_PIPELINE_BIND_POINT_GRAPHICS, g_pGfx);
    vkCmdBindDescriptorSets(cmd, VK_PIPELINE_BIND_POINT_GRAPHICS, g_plGfx, 0, 1, &g_dset, 0, NULL);

    vkCmdDraw(cmd, VERTEX_COUNT, 1, 0, 0);

    vkCmdEndRenderPass(cmd);

    r = vkEndCommandBuffer(cmd);
    if (r) dieVk(r, "vkEndCommandBuffer");
}

static void recreateSwapchain(void) {
    RECT rc;
    do {
        GetClientRect(g_hwnd, &rc);
        if ((rc.right-rc.left) == 0 || (rc.bottom-rc.top) == 0) Sleep(16);
    } while ((rc.right-rc.left) == 0 || (rc.bottom-rc.top) == 0);

    vkDeviceWaitIdle(g_dev);

    cleanupSwapchain();
    createSwapchainAndViews();
    createFramebuffers();

    g_resized = false;
}

static void drawFrame(void) {
    vkWaitForFences(g_dev, 1, &g_inFlight[g_frameIndex], VK_TRUE, UINT64_MAX);
    vkResetFences(g_dev, 1, &g_inFlight[g_frameIndex]);

    uint32_t imageIndex = 0;
    VkResult r = vkAcquireNextImageKHR(
        g_dev, g_swapchain, UINT64_MAX,
        g_imgAvail[g_frameIndex], VK_NULL_HANDLE,
        &imageIndex);

    if (r == VK_ERROR_OUT_OF_DATE_KHR) { recreateSwapchain(); return; }
    if (r != VK_SUCCESS && r != VK_SUBOPTIMAL_KHR) dieVk(r, "vkAcquireNextImageKHR");

    // animate params a bit (CPU side)
    static float t = 0.0f;
    t += 0.016f;
    g_params.f1 = 2.0f + 0.5f * sinf(t*0.7f);
    g_params.f2 = 2.0f + 0.5f * sinf(t*0.9f);
    g_params.f3 = 2.0f + 0.5f * sinf(t*1.1f);
    g_params.f4 = 2.0f + 0.5f * sinf(t*1.3f);
    g_params.p1 += 0.002f;

    updateUBO();

    vkResetCommandBuffer(g_cmd[g_frameIndex], 0);
    recordCmd(g_cmd[g_frameIndex], imageIndex);

    VkPipelineStageFlags waitStage = VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT;

    VkSubmitInfo si = {0};
    si.sType = VK_STRUCTURE_TYPE_SUBMIT_INFO;
    si.waitSemaphoreCount = 1;
    si.pWaitSemaphores = &g_imgAvail[g_frameIndex];
    si.pWaitDstStageMask = &waitStage;
    si.commandBufferCount = 1;
    si.pCommandBuffers = &g_cmd[g_frameIndex];
    si.signalSemaphoreCount = 1;
    si.pSignalSemaphores = &g_renderDone[g_frameIndex];

    r = vkQueueSubmit(g_queue, 1, &si, g_inFlight[g_frameIndex]);
    if (r) dieVk(r, "vkQueueSubmit");

    VkPresentInfoKHR pi = {0};
    pi.sType = VK_STRUCTURE_TYPE_PRESENT_INFO_KHR;
    pi.waitSemaphoreCount = 1;
    pi.pWaitSemaphores = &g_renderDone[g_frameIndex];
    pi.swapchainCount = 1;
    pi.pSwapchains = &g_swapchain;
    pi.pImageIndices = &imageIndex;

    r = vkQueuePresentKHR(g_queue, &pi);
    if (r == VK_ERROR_OUT_OF_DATE_KHR || r == VK_SUBOPTIMAL_KHR || g_resized) {
        recreateSwapchain();
    } else if (r) {
        dieVk(r, "vkQueuePresentKHR");
    }

    g_frameIndex = (g_frameIndex + 1) % MAX_FRAMES_IN_FLIGHT;
}

static void initVulkanAll(void) {
    createInstanceAndSurface();
    pickDeviceAndCreateLogical();
    createSwapchainAndViews();
    createRenderPass();
    createFramebuffers();
    createDescriptorLayoutAndSet();
    createPipelines();
    createCommandObjects();
    createSync();
    createBuffersAndDescriptors();
}

static void shutdownVulkanAll(void) {
    vkDeviceWaitIdle(g_dev);

    destroyBuffer(&g_posBuf);
    destroyBuffer(&g_colBuf);
    destroyBuffer(&g_ubo);

    for (uint32_t i=0;i<MAX_FRAMES_IN_FLIGHT;i++){
        if (g_imgAvail[i]) vkDestroySemaphore(g_dev, g_imgAvail[i], NULL);
        if (g_renderDone[i]) vkDestroySemaphore(g_dev, g_renderDone[i], NULL);
        if (g_inFlight[i]) vkDestroyFence(g_dev, g_inFlight[i], NULL);
    }

    if (g_cmdPool) vkDestroyCommandPool(g_dev, g_cmdPool, NULL);

    if (g_pGfx) vkDestroyPipeline(g_dev, g_pGfx, NULL);
    if (g_plGfx) vkDestroyPipelineLayout(g_dev, g_plGfx, NULL);
    if (g_pCompute) vkDestroyPipeline(g_dev, g_pCompute, NULL);
    if (g_plCompute) vkDestroyPipelineLayout(g_dev, g_plCompute, NULL);

    if (g_dpool) vkDestroyDescriptorPool(g_dev, g_dpool, NULL);
    if (g_dsl) vkDestroyDescriptorSetLayout(g_dev, g_dsl, NULL);

    if (g_renderPass) vkDestroyRenderPass(g_dev, g_renderPass, NULL);

    cleanupSwapchain();

    if (g_dev) vkDestroyDevice(g_dev, NULL);

    if (g_surface) vkDestroySurfaceKHR(g_instance, g_surface, NULL);

    if (g_enableValidation && g_dbgMessenger) {
        DestroyDebugUtilsMessengerEXT(g_instance, g_dbgMessenger, NULL);
    }

    if (g_instance) vkDestroyInstance(g_instance, NULL);
}

// ------------------------------------------------------------
// Main loop
// ------------------------------------------------------------
int WINAPI WinMain(HINSTANCE hInst, HINSTANCE hPrev, LPSTR lpCmd, int nShow) {
    (void)hInst; (void)hPrev; (void)lpCmd; (void)nShow;

    createWindowWin32();
    initVulkanAll();

    MSG msg;
    uint64_t startTick = GetTickCount64();

    while (g_running) {
        while (PeekMessageA(&msg, NULL, 0, 0, PM_REMOVE)) {
            TranslateMessage(&msg);
            DispatchMessageA(&msg);
        }

        uint64_t now = GetTickCount64();
        if (now - startTick > 60000ull) g_running = false;

        drawFrame();
        Sleep(1);
    }

    shutdownVulkanAll();
    DestroyWindow(g_hwnd);
    return 0;
}

