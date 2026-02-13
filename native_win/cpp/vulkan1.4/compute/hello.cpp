#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <tchar.h>
#include <vulkan/vulkan.h>
#include <vulkan/vulkan_win32.h>

#include <algorithm>
#include <array>
#include <cmath>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <fstream>
#include <string>
#include <vector>

#pragma comment(lib, "user32.lib")
#pragma comment(lib, "gdi32.lib")

// ------------------------------------------------------------
// Config
// ------------------------------------------------------------
static constexpr const TCHAR* APP_NAME = _T("Vulkan 1.4 Compute Harmonograph (C++)");
static constexpr uint32_t WIN_W = 960;
static constexpr uint32_t WIN_H = 720;
static constexpr int MAX_FRAMES_IN_FLIGHT = 2;
static constexpr uint32_t VERTEX_COUNT = 500000u;

static const char* g_deviceExts[]       = { VK_KHR_SWAPCHAIN_EXTENSION_NAME };
static const char* g_validationLayers[] = { "VK_LAYER_KHRONOS_validation" };

#ifdef NDEBUG
static constexpr bool g_enableValidation = false;
#else
static constexpr bool g_enableValidation = true;
#endif

// ------------------------------------------------------------
// Fatal helpers
// ------------------------------------------------------------
[[noreturn]] static void die(const TCHAR* msg) {
    MessageBox(nullptr, msg, _T("Fatal"), MB_OK | MB_ICONERROR);
    ExitProcess(1);
}
[[noreturn]] static void dieVk(VkResult r, const TCHAR* where) {
    TCHAR buf[512];
    _sntprintf_s(buf, sizeof(buf) / sizeof(buf[0]), _TRUNCATE, _T("%s failed: VkResult=%d"), where, static_cast<int>(r));
    die(buf);
}
static void vkCheck(VkResult r, const TCHAR* where) { if (r != VK_SUCCESS) dieVk(r, where); }

// ------------------------------------------------------------
// File read
// ------------------------------------------------------------
static std::vector<char> readFileBinary(const std::string& path) {
    std::ifstream f(path, std::ios::ate | std::ios::binary);
    if (!f.is_open()) die(_T("Cannot open file"));
    auto sz = static_cast<size_t>(f.tellg());
    std::vector<char> buf(sz);
    f.seekg(0);
    f.read(buf.data(), static_cast<std::streamsize>(sz));
    return buf;
}

// ------------------------------------------------------------
// UBO layout (std140)
// ------------------------------------------------------------
#pragma pack(push, 1)
struct ParamsUBO {
    uint32_t max_num;
    float    dt;
    float    scale;
    float    pad0;
    float A1, f1, p1, d1;
    float A2, f2, p2, d2;
    float A3, f3, p3, d3;
    float A4, f4, p4, d4;
};
#pragma pack(pop)

// ------------------------------------------------------------
// Buffer wrapper
// ------------------------------------------------------------
struct GpuBuffer {
    VkBuffer       buf  = VK_NULL_HANDLE;
    VkDeviceMemory mem  = VK_NULL_HANDLE;
    VkDeviceSize   size = 0;
};

// ------------------------------------------------------------
// Win32 window (globals for WndProc callback)
// ------------------------------------------------------------
static HWND      g_hwnd    = nullptr;
static HINSTANCE g_hinst   = nullptr;
static bool      g_running = true;
static bool      g_resized = false;

static LRESULT CALLBACK WndProc(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam) {
    switch (msg) {
    case WM_CLOSE:   g_running = false; PostQuitMessage(0); return 0;
    case WM_SIZE:    g_resized = true; return 0;
    case WM_KEYDOWN: if (wParam == VK_ESCAPE) { g_running = false; PostQuitMessage(0); } return 0;
    default:         return DefWindowProc(hWnd, msg, wParam, lParam);
    }
}

// ============================================================
// Application class
// ============================================================
class HarmonographApp {
public:
    void run() {
        createWindowWin32();
        initVulkan();
        mainLoop();
        shutdownVulkan();
        DestroyWindow(g_hwnd);
    }

private:
    // --- Vulkan handles ---
    VkInstance               instance_     = VK_NULL_HANDLE;
    VkDebugUtilsMessengerEXT dbgMessenger_ = VK_NULL_HANDLE;
    VkSurfaceKHR             surface_      = VK_NULL_HANDLE;
    VkPhysicalDevice         physDev_      = VK_NULL_HANDLE;
    VkDevice                 dev_          = VK_NULL_HANDLE;
    uint32_t                 qfam_         = 0;
    VkQueue                  queue_        = VK_NULL_HANDLE;

    VkSwapchainKHR             swapchain_ = VK_NULL_HANDLE;
    VkFormat                   scFmt_{};
    VkExtent2D                 scExtent_{};
    std::vector<VkImage>       scImages_;
    std::vector<VkImageView>   scViews_;
    std::vector<VkFramebuffer> framebuffers_;

    VkRenderPass             renderPass_ = VK_NULL_HANDLE;
    VkDescriptorSetLayout    dsl_        = VK_NULL_HANDLE;
    VkDescriptorPool         dpool_      = VK_NULL_HANDLE;
    VkDescriptorSet          dset_       = VK_NULL_HANDLE;

    VkPipelineLayout plCompute_ = VK_NULL_HANDLE;
    VkPipeline       pCompute_  = VK_NULL_HANDLE;
    VkPipelineLayout plGfx_     = VK_NULL_HANDLE;
    VkPipeline       pGfx_      = VK_NULL_HANDLE;

    VkCommandPool cmdPool_ = VK_NULL_HANDLE;
    std::array<VkCommandBuffer, MAX_FRAMES_IN_FLIGHT> cmd_{};
    std::array<VkSemaphore, MAX_FRAMES_IN_FLIGHT>     imgAvail_{};
    std::array<VkSemaphore, MAX_FRAMES_IN_FLIGHT>     renderDone_{};
    std::array<VkFence, MAX_FRAMES_IN_FLIGHT>          inFlight_{};
    uint32_t frameIdx_ = 0;

    GpuBuffer posBuf_{}, colBuf_{}, ubo_{};
    ParamsUBO params_{};

    // ========================================================
    // Win32 window
    // ========================================================
    void createWindowWin32() {
        g_hinst = GetModuleHandle(nullptr);
        WNDCLASSEX wc;
        std::memset(&wc, 0, sizeof(wc));
        wc.cbSize        = sizeof(wc);
        wc.style         = CS_HREDRAW | CS_VREDRAW;
        wc.lpfnWndProc   = WndProc;
        wc.hInstance     = g_hinst;
        wc.hCursor       = LoadCursor(nullptr, IDC_ARROW);
        wc.lpszClassName = _T("VkHarmonographCpp");
        if (!RegisterClassEx(&wc)) die(_T("RegisterClassEx failed"));

        RECT rc = { 0, 0, static_cast<LONG>(WIN_W), static_cast<LONG>(WIN_H) };
        AdjustWindowRect(&rc, WS_OVERLAPPEDWINDOW, FALSE);
        g_hwnd = CreateWindowEx(0, wc.lpszClassName, APP_NAME, WS_OVERLAPPEDWINDOW,
            CW_USEDEFAULT, CW_USEDEFAULT,
            rc.right - rc.left, rc.bottom - rc.top,
            nullptr, nullptr, g_hinst, nullptr);
        if (!g_hwnd) die(_T("CreateWindowEx failed"));
        ShowWindow(g_hwnd, SW_SHOW);
    }

    // ========================================================
    // Debug callback
    // ========================================================
    static VKAPI_ATTR VkBool32 VKAPI_CALL dbgCb(
        VkDebugUtilsMessageSeverityFlagBitsEXT severity,
        VkDebugUtilsMessageTypeFlagsEXT, const VkDebugUtilsMessengerCallbackDataEXT* cb, void*)
    {
        if (severity >= VK_DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT) {
            OutputDebugStringA(cb->pMessage);
            OutputDebugStringA("\n");
        }
        return VK_FALSE;
    }

    // ========================================================
    // Helpers: memory, buffer, shader
    // ========================================================
    uint32_t findMemoryType(uint32_t typeBits, VkMemoryPropertyFlags flags) {
        VkPhysicalDeviceMemoryProperties mp;
        vkGetPhysicalDeviceMemoryProperties(physDev_, &mp);
        for (uint32_t i = 0; i < mp.memoryTypeCount; i++)
            if ((typeBits & (1u << i)) && (mp.memoryTypes[i].propertyFlags & flags) == flags) return i;
        die("No suitable memory type");
        return 0;
    }

    void createBuf(VkDeviceSize size, VkBufferUsageFlags usage, VkMemoryPropertyFlags memFlags, GpuBuffer& out) {
        out.size = size;
        VkBufferCreateInfo bi;  std::memset(&bi, 0, sizeof(bi));
        bi.sType = VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO;
        bi.size = size;  bi.usage = usage;  bi.sharingMode = VK_SHARING_MODE_EXCLUSIVE;
        vkCheck(vkCreateBuffer(dev_, &bi, nullptr, &out.buf), "vkCreateBuffer");

        VkMemoryRequirements req;
        vkGetBufferMemoryRequirements(dev_, out.buf, &req);
        VkMemoryAllocateInfo ai;  std::memset(&ai, 0, sizeof(ai));
        ai.sType = VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO;
        ai.allocationSize  = req.size;
        ai.memoryTypeIndex = findMemoryType(req.memoryTypeBits, memFlags);
        vkCheck(vkAllocateMemory(dev_, &ai, nullptr, &out.mem), "vkAllocateMemory");
        vkCheck(vkBindBufferMemory(dev_, out.buf, out.mem, 0), "vkBindBufferMemory");
    }

    void destroyBuf(GpuBuffer& b) {
        if (b.buf) vkDestroyBuffer(dev_, b.buf, nullptr);
        if (b.mem) vkFreeMemory(dev_, b.mem, nullptr);
        b = {};
    }

    VkShaderModule loadShader(const std::string& path) {
        auto code = readFileBinary(path);
        VkShaderModuleCreateInfo ci;  std::memset(&ci, 0, sizeof(ci));
        ci.sType    = VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO;
        ci.codeSize = code.size();
        ci.pCode    = reinterpret_cast<const uint32_t*>(code.data());
        VkShaderModule m;
        vkCheck(vkCreateShaderModule(dev_, &ci, nullptr, &m), "vkCreateShaderModule");
        return m;
    }

    // ========================================================
    // Instance & Surface
    // ========================================================
    void createInstanceAndSurface() {
        if (g_enableValidation) {
            uint32_t n = 0;
            vkEnumerateInstanceLayerProperties(&n, nullptr);
            std::vector<VkLayerProperties> lp(n);
            vkEnumerateInstanceLayerProperties(&n, lp.data());
            bool found = false;
            for (auto& l : lp) if (std::strcmp(l.layerName, g_validationLayers[0]) == 0) found = true;
            if (!found) die(_T("Validation layer not available"));
        }

        VkApplicationInfo ai;  std::memset(&ai, 0, sizeof(ai));
        ai.sType = VK_STRUCTURE_TYPE_APPLICATION_INFO;
        ai.pApplicationName   = APP_NAME;
        ai.applicationVersion = VK_MAKE_VERSION(1,0,0);
        ai.pEngineName        = "No Engine";
        ai.engineVersion      = VK_MAKE_VERSION(1,0,0);
        ai.apiVersion         = VK_API_VERSION_1_4;

        const char* exts[4];  uint32_t extN = 0;
        exts[extN++] = VK_KHR_SURFACE_EXTENSION_NAME;
        exts[extN++] = VK_KHR_WIN32_SURFACE_EXTENSION_NAME;
        if (g_enableValidation) exts[extN++] = VK_EXT_DEBUG_UTILS_EXTENSION_NAME;

        VkInstanceCreateInfo ici;  std::memset(&ici, 0, sizeof(ici));
        ici.sType = VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO;
        ici.pApplicationInfo        = &ai;
        ici.enabledExtensionCount   = extN;
        ici.ppEnabledExtensionNames = exts;

        VkDebugUtilsMessengerCreateInfoEXT dbgCI;
        std::memset(&dbgCI, 0, sizeof(dbgCI));
        if (g_enableValidation) {
            dbgCI.sType           = VK_STRUCTURE_TYPE_DEBUG_UTILS_MESSENGER_CREATE_INFO_EXT;
            dbgCI.messageSeverity = VK_DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT |
                                    VK_DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT;
            dbgCI.messageType     = VK_DEBUG_UTILS_MESSAGE_TYPE_GENERAL_BIT_EXT |
                                    VK_DEBUG_UTILS_MESSAGE_TYPE_VALIDATION_BIT_EXT |
                                    VK_DEBUG_UTILS_MESSAGE_TYPE_PERFORMANCE_BIT_EXT;
            dbgCI.pfnUserCallback = dbgCb;
            ici.enabledLayerCount   = 1;
            ici.ppEnabledLayerNames = g_validationLayers;
            ici.pNext               = &dbgCI;
        }

        vkCheck(vkCreateInstance(&ici, nullptr, &instance_), _T("vkCreateInstance"));

        if (g_enableValidation) {
            auto fn = reinterpret_cast<PFN_vkCreateDebugUtilsMessengerEXT>(
                vkGetInstanceProcAddr(instance_, "vkCreateDebugUtilsMessengerEXT"));
            if (fn) fn(instance_, &dbgCI, nullptr, &dbgMessenger_);
        }

        VkWin32SurfaceCreateInfoKHR sci;  std::memset(&sci, 0, sizeof(sci));
        sci.sType     = VK_STRUCTURE_TYPE_WIN32_SURFACE_CREATE_INFO_KHR;
        sci.hinstance = g_hinst;
        sci.hwnd      = g_hwnd;
        vkCheck(vkCreateWin32SurfaceKHR(instance_, &sci, nullptr, &surface_), _T("vkCreateWin32SurfaceKHR"));
    }

    // ========================================================
    // Device
    // ========================================================
    void pickDeviceAndCreate() {
        uint32_t n = 0;
        vkEnumeratePhysicalDevices(instance_, &n, nullptr);
        if (!n) die(_T("No Vulkan physical devices found."));
        std::vector<VkPhysicalDevice> devs(n);
        vkEnumeratePhysicalDevices(instance_, &n, devs.data());

        for (auto pd : devs) {
            // check extension
            uint32_t en = 0;
            vkEnumerateDeviceExtensionProperties(pd, nullptr, &en, nullptr);
            std::vector<VkExtensionProperties> ep(en);
            vkEnumerateDeviceExtensionProperties(pd, nullptr, &en, ep.data());
            bool hasExt = false;
            for (auto& e : ep)
                if (std::strcmp(e.extensionName, VK_KHR_SWAPCHAIN_EXTENSION_NAME) == 0) { hasExt = true; break; }
            if (!hasExt) continue;

            // find queue family: graphics + compute + present
            uint32_t qn = 0;
            vkGetPhysicalDeviceQueueFamilyProperties(pd, &qn, nullptr);
            std::vector<VkQueueFamilyProperties> qf(qn);
            vkGetPhysicalDeviceQueueFamilyProperties(pd, &qn, qf.data());
            for (uint32_t i = 0; i < qn; i++) {
                VkBool32 present = VK_FALSE;
                vkGetPhysicalDeviceSurfaceSupportKHR(pd, i, surface_, &present);
                if ((qf[i].queueFlags & VK_QUEUE_GRAPHICS_BIT) &&
                    (qf[i].queueFlags & VK_QUEUE_COMPUTE_BIT) && present) {
                    physDev_ = pd;  qfam_ = i;  break;
                }
            }
            if (physDev_) break;
        }
        if (!physDev_) die(_T("No suitable device (need graphics+compute+present in same queue family)."));

        float prio = 1.0f;
        VkDeviceQueueCreateInfo qci;  std::memset(&qci, 0, sizeof(qci));
        qci.sType            = VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO;
        qci.queueFamilyIndex = qfam_;
        qci.queueCount       = 1;
        qci.pQueuePriorities = &prio;

        VkPhysicalDeviceFeatures feats;  std::memset(&feats, 0, sizeof(feats));

        VkDeviceCreateInfo dci;  std::memset(&dci, 0, sizeof(dci));
        dci.sType                   = VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO;
        dci.queueCreateInfoCount    = 1;
        dci.pQueueCreateInfos       = &qci;
        dci.enabledExtensionCount   = 1;
        dci.ppEnabledExtensionNames = g_deviceExts;
        dci.pEnabledFeatures        = &feats;
        if (g_enableValidation) {
            dci.enabledLayerCount   = 1;
            dci.ppEnabledLayerNames = g_validationLayers;
        }
        vkCheck(vkCreateDevice(physDev_, &dci, nullptr, &dev_), _T("vkCreateDevice"));
        vkGetDeviceQueue(dev_, qfam_, 0, &queue_);
    }

    // ========================================================
    // Swap chain helpers
    // ========================================================
    VkSurfaceFormatKHR chooseSurfaceFormat() {
        uint32_t n = 0;
        vkGetPhysicalDeviceSurfaceFormatsKHR(physDev_, surface_, &n, nullptr);
        std::vector<VkSurfaceFormatKHR> fmts(n);
        vkGetPhysicalDeviceSurfaceFormatsKHR(physDev_, surface_, &n, fmts.data());
        for (auto& f : fmts)
            if (f.format == VK_FORMAT_B8G8R8A8_UNORM && f.colorSpace == VK_COLOR_SPACE_SRGB_NONLINEAR_KHR) return f;
        return fmts[0];
    }

    VkPresentModeKHR choosePresentMode() {
        uint32_t n = 0;
        vkGetPhysicalDeviceSurfacePresentModesKHR(physDev_, surface_, &n, nullptr);
        std::vector<VkPresentModeKHR> pm(n);
        vkGetPhysicalDeviceSurfacePresentModesKHR(physDev_, surface_, &n, pm.data());
        for (auto m : pm) if (m == VK_PRESENT_MODE_MAILBOX_KHR) return m;
        return VK_PRESENT_MODE_FIFO_KHR;
    }

    VkExtent2D chooseExtent(const VkSurfaceCapabilitiesKHR& caps) {
        if (caps.currentExtent.width != 0xFFFFFFFFu) return caps.currentExtent;
        RECT rc;  GetClientRect(g_hwnd, &rc);
        uint32_t w = static_cast<uint32_t>(rc.right - rc.left);
        uint32_t h = static_cast<uint32_t>(rc.bottom - rc.top);
        VkExtent2D e;
        e.width  = (std::min)((std::max)(w, caps.minImageExtent.width),  caps.maxImageExtent.width);
        e.height = (std::min)((std::max)(h, caps.minImageExtent.height), caps.maxImageExtent.height);
        return e;
    }

    // ========================================================
    // Swap chain
    // ========================================================
    void createSwapchainAndViews() {
        VkSurfaceCapabilitiesKHR caps;
        vkGetPhysicalDeviceSurfaceCapabilitiesKHR(physDev_, surface_, &caps);
        auto fmt = chooseSurfaceFormat();
        auto pm  = choosePresentMode();
        auto ext = chooseExtent(caps);

        uint32_t imgCount = caps.minImageCount + 1;
        if (caps.maxImageCount && imgCount > caps.maxImageCount) imgCount = caps.maxImageCount;

        VkSwapchainCreateInfoKHR ci;  std::memset(&ci, 0, sizeof(ci));
        ci.sType            = VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR;
        ci.surface          = surface_;
        ci.minImageCount    = imgCount;
        ci.imageFormat      = fmt.format;
        ci.imageColorSpace  = fmt.colorSpace;
        ci.imageExtent      = ext;
        ci.imageArrayLayers = 1;
        ci.imageUsage       = VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT;
        ci.imageSharingMode = VK_SHARING_MODE_EXCLUSIVE;
        ci.preTransform     = caps.currentTransform;
        ci.compositeAlpha   = VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR;
        ci.presentMode      = pm;
        ci.clipped          = VK_TRUE;
        vkCheck(vkCreateSwapchainKHR(dev_, &ci, nullptr, &swapchain_), _T("vkCreateSwapchainKHR"));
        scFmt_ = fmt.format;  scExtent_ = ext;

        uint32_t cnt = 0;
        vkGetSwapchainImagesKHR(dev_, swapchain_, &cnt, nullptr);
        scImages_.resize(cnt);
        vkGetSwapchainImagesKHR(dev_, swapchain_, &cnt, scImages_.data());

        scViews_.resize(cnt);
        for (uint32_t i = 0; i < cnt; i++) {
            VkImageViewCreateInfo vi;  std::memset(&vi, 0, sizeof(vi));
            vi.sType    = VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO;
            vi.image    = scImages_[i];
            vi.viewType = VK_IMAGE_VIEW_TYPE_2D;
            vi.format   = scFmt_;
            vi.subresourceRange.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT;
            vi.subresourceRange.levelCount = 1;
            vi.subresourceRange.layerCount = 1;
            vkCheck(vkCreateImageView(dev_, &vi, nullptr, &scViews_[i]), _T("vkCreateImageView"));
        }
    }

    void cleanupSwapchain() {
        for (auto fb : framebuffers_) vkDestroyFramebuffer(dev_, fb, nullptr);
        framebuffers_.clear();
        for (auto iv : scViews_) vkDestroyImageView(dev_, iv, nullptr);
        scViews_.clear();  scImages_.clear();
        if (swapchain_) { vkDestroySwapchainKHR(dev_, swapchain_, nullptr); swapchain_ = VK_NULL_HANDLE; }
    }

    // ========================================================
    // Render pass & Framebuffers
    // ========================================================
    void createRenderPass() {
        VkAttachmentDescription color;  std::memset(&color, 0, sizeof(color));
        color.format      = scFmt_;
        color.samples     = VK_SAMPLE_COUNT_1_BIT;
        color.loadOp      = VK_ATTACHMENT_LOAD_OP_CLEAR;
        color.storeOp     = VK_ATTACHMENT_STORE_OP_STORE;
        color.initialLayout = VK_IMAGE_LAYOUT_UNDEFINED;
        color.finalLayout   = VK_IMAGE_LAYOUT_PRESENT_SRC_KHR;

        VkAttachmentReference ref;  std::memset(&ref, 0, sizeof(ref));
        ref.attachment = 0;  ref.layout = VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL;

        VkSubpassDescription sub;  std::memset(&sub, 0, sizeof(sub));
        sub.pipelineBindPoint    = VK_PIPELINE_BIND_POINT_GRAPHICS;
        sub.colorAttachmentCount = 1;
        sub.pColorAttachments    = &ref;

        VkSubpassDependency dep;  std::memset(&dep, 0, sizeof(dep));
        dep.srcSubpass    = VK_SUBPASS_EXTERNAL;
        dep.dstSubpass    = 0;
        dep.srcStageMask  = VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT;
        dep.dstStageMask  = VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT;
        dep.dstAccessMask = VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT;

        VkRenderPassCreateInfo rp;  std::memset(&rp, 0, sizeof(rp));
        rp.sType           = VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO;
        rp.attachmentCount = 1;  rp.pAttachments = &color;
        rp.subpassCount    = 1;  rp.pSubpasses   = &sub;
        rp.dependencyCount = 1;  rp.pDependencies = &dep;
        vkCheck(vkCreateRenderPass(dev_, &rp, nullptr, &renderPass_), _T("vkCreateRenderPass"));
    }

    void createFramebuffers() {
        framebuffers_.resize(scViews_.size());
        for (size_t i = 0; i < scViews_.size(); i++) {
            VkImageView atts[] = { scViews_[i] };
            VkFramebufferCreateInfo fi;  std::memset(&fi, 0, sizeof(fi));
            fi.sType           = VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO;
            fi.renderPass      = renderPass_;
            fi.attachmentCount = 1;
            fi.pAttachments    = atts;
            fi.width  = scExtent_.width;
            fi.height = scExtent_.height;
            fi.layers = 1;
            vkCheck(vkCreateFramebuffer(dev_, &fi, nullptr, &framebuffers_[i]), _T("vkCreateFramebuffer"));
        }
    }

    // ========================================================
    // Descriptors
    // ========================================================
    void createDescriptorLayoutAndSet() {
        VkDescriptorSetLayoutBinding b[3];
        std::memset(b, 0, sizeof(b));
        // Positions SSBO (compute + vertex)
        b[0].binding = 0;  b[0].descriptorType = VK_DESCRIPTOR_TYPE_STORAGE_BUFFER;
        b[0].descriptorCount = 1;
        b[0].stageFlags = static_cast<VkShaderStageFlags>(VK_SHADER_STAGE_COMPUTE_BIT | VK_SHADER_STAGE_VERTEX_BIT);
        // Colors SSBO (compute + vertex)
        b[1].binding = 1;  b[1].descriptorType = VK_DESCRIPTOR_TYPE_STORAGE_BUFFER;
        b[1].descriptorCount = 1;
        b[1].stageFlags = static_cast<VkShaderStageFlags>(VK_SHADER_STAGE_COMPUTE_BIT | VK_SHADER_STAGE_VERTEX_BIT);
        // UBO (compute only)
        b[2].binding = 2;  b[2].descriptorType = VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER;
        b[2].descriptorCount = 1;
        b[2].stageFlags = static_cast<VkShaderStageFlags>(VK_SHADER_STAGE_COMPUTE_BIT);

        VkDescriptorSetLayoutCreateInfo ci;  std::memset(&ci, 0, sizeof(ci));
        ci.sType        = VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO;
        ci.bindingCount = 3;  ci.pBindings = b;
        vkCheck(vkCreateDescriptorSetLayout(dev_, &ci, nullptr, &dsl_), _T("vkCreateDescriptorSetLayout"));

        VkDescriptorPoolSize ps[2];
        ps[0].type = VK_DESCRIPTOR_TYPE_STORAGE_BUFFER; ps[0].descriptorCount = 2;
        ps[1].type = VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER; ps[1].descriptorCount = 1;

        VkDescriptorPoolCreateInfo pci;  std::memset(&pci, 0, sizeof(pci));
        pci.sType         = VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO;
        pci.maxSets       = 1;
        pci.poolSizeCount = 2;  pci.pPoolSizes = ps;
        vkCheck(vkCreateDescriptorPool(dev_, &pci, nullptr, &dpool_), _T("vkCreateDescriptorPool"));

        VkDescriptorSetAllocateInfo dai;  std::memset(&dai, 0, sizeof(dai));
        dai.sType              = VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO;
        dai.descriptorPool     = dpool_;
        dai.descriptorSetCount = 1;
        dai.pSetLayouts        = &dsl_;
        vkCheck(vkAllocateDescriptorSets(dev_, &dai, &dset_), _T("vkAllocateDescriptorSets"));
    }

    // ========================================================
    // Pipelines
    // ========================================================
    void createPipelines() {
        // --- Compute pipeline ---
        VkShaderModule smComp = loadShader("hello_comp.spv");

        VkPipelineLayoutCreateInfo plci;  std::memset(&plci, 0, sizeof(plci));
        plci.sType          = VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO;
        plci.setLayoutCount = 1;  plci.pSetLayouts = &dsl_;
        vkCheck(vkCreatePipelineLayout(dev_, &plci, nullptr, &plCompute_), _T("PipelineLayout(compute)"));

        VkComputePipelineCreateInfo cpi;  std::memset(&cpi, 0, sizeof(cpi));
        cpi.sType        = VK_STRUCTURE_TYPE_COMPUTE_PIPELINE_CREATE_INFO;
        cpi.stage.sType  = VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO;
        cpi.stage.stage  = VK_SHADER_STAGE_COMPUTE_BIT;
        cpi.stage.module = smComp;
        cpi.stage.pName  = "main";
        cpi.layout       = plCompute_;
        vkCheck(vkCreateComputePipelines(dev_, VK_NULL_HANDLE, 1, &cpi, nullptr, &pCompute_), _T("ComputePipeline"));
        vkDestroyShaderModule(dev_, smComp, nullptr);

        // --- Graphics pipeline ---
        VkShaderModule smVS = loadShader("hello_vert.spv");
        VkShaderModule smFS = loadShader("hello_frag.spv");

        VkPipelineLayoutCreateInfo glci;  std::memset(&glci, 0, sizeof(glci));
        glci.sType          = VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO;
        glci.setLayoutCount = 1;  glci.pSetLayouts = &dsl_;
        vkCheck(vkCreatePipelineLayout(dev_, &glci, nullptr, &plGfx_), _T("PipelineLayout(gfx)"));

        VkPipelineShaderStageCreateInfo stages[2];
        std::memset(stages, 0, sizeof(stages));
        stages[0].sType = VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO;
        stages[0].stage = VK_SHADER_STAGE_VERTEX_BIT;   stages[0].module = smVS; stages[0].pName = "main";
        stages[1].sType = VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO;
        stages[1].stage = VK_SHADER_STAGE_FRAGMENT_BIT;  stages[1].module = smFS; stages[1].pName = "main";

        VkPipelineVertexInputStateCreateInfo vi;  std::memset(&vi, 0, sizeof(vi));
        vi.sType = VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO;

        VkPipelineInputAssemblyStateCreateInfo ia;  std::memset(&ia, 0, sizeof(ia));
        ia.sType    = VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO;
        ia.topology = VK_PRIMITIVE_TOPOLOGY_LINE_STRIP;

        VkViewport vp;  std::memset(&vp, 0, sizeof(vp));
        vp.width = static_cast<float>(scExtent_.width);
        vp.height = static_cast<float>(scExtent_.height);
        vp.maxDepth = 1.0f;

        VkRect2D sc;  std::memset(&sc, 0, sizeof(sc));
        sc.extent = scExtent_;

        VkPipelineViewportStateCreateInfo vs;  std::memset(&vs, 0, sizeof(vs));
        vs.sType = VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO;
        vs.viewportCount = 1;  vs.pViewports = &vp;
        vs.scissorCount  = 1;  vs.pScissors  = &sc;

        VkPipelineRasterizationStateCreateInfo rs;  std::memset(&rs, 0, sizeof(rs));
        rs.sType       = VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO;
        rs.polygonMode = VK_POLYGON_MODE_FILL;
        rs.cullMode    = VK_CULL_MODE_NONE;
        rs.frontFace   = VK_FRONT_FACE_COUNTER_CLOCKWISE;
        rs.lineWidth   = 1.0f;

        VkPipelineMultisampleStateCreateInfo ms;  std::memset(&ms, 0, sizeof(ms));
        ms.sType = VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO;
        ms.rasterizationSamples = VK_SAMPLE_COUNT_1_BIT;

        VkPipelineColorBlendAttachmentState cba;  std::memset(&cba, 0, sizeof(cba));
        cba.colorWriteMask = VK_COLOR_COMPONENT_R_BIT | VK_COLOR_COMPONENT_G_BIT |
                             VK_COLOR_COMPONENT_B_BIT | VK_COLOR_COMPONENT_A_BIT;

        VkPipelineColorBlendStateCreateInfo cb;  std::memset(&cb, 0, sizeof(cb));
        cb.sType           = VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO;
        cb.attachmentCount = 1;  cb.pAttachments = &cba;

        VkGraphicsPipelineCreateInfo gp;  std::memset(&gp, 0, sizeof(gp));
        gp.sType               = VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO;
        gp.stageCount          = 2;         gp.pStages             = stages;
        gp.pVertexInputState   = &vi;       gp.pInputAssemblyState = &ia;
        gp.pViewportState      = &vs;       gp.pRasterizationState = &rs;
        gp.pMultisampleState   = &ms;       gp.pColorBlendState    = &cb;
        gp.layout              = plGfx_;    gp.renderPass          = renderPass_;
        vkCheck(vkCreateGraphicsPipelines(dev_, VK_NULL_HANDLE, 1, &gp, nullptr, &pGfx_), _T("GraphicsPipeline"));

        vkDestroyShaderModule(dev_, smVS, nullptr);
        vkDestroyShaderModule(dev_, smFS, nullptr);
    }

    // ========================================================
    // Command pool / buffers / sync
    // ========================================================
    void createCommandObjects() {
        VkCommandPoolCreateInfo pci;  std::memset(&pci, 0, sizeof(pci));
        pci.sType            = VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO;
        pci.queueFamilyIndex = qfam_;
        pci.flags            = VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT;
        vkCheck(vkCreateCommandPool(dev_, &pci, nullptr, &cmdPool_), _T("vkCreateCommandPool"));

        VkCommandBufferAllocateInfo ai;  std::memset(&ai, 0, sizeof(ai));
        ai.sType              = VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO;
        ai.commandPool        = cmdPool_;
        ai.level              = VK_COMMAND_BUFFER_LEVEL_PRIMARY;
        ai.commandBufferCount = MAX_FRAMES_IN_FLIGHT;
        vkCheck(vkAllocateCommandBuffers(dev_, &ai, cmd_.data()), _T("vkAllocateCommandBuffers"));
    }

    void createSync() {
        VkSemaphoreCreateInfo si;  std::memset(&si, 0, sizeof(si));
        si.sType = VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO;
        VkFenceCreateInfo fi;  std::memset(&fi, 0, sizeof(fi));
        fi.sType = VK_STRUCTURE_TYPE_FENCE_CREATE_INFO;
        fi.flags = VK_FENCE_CREATE_SIGNALED_BIT;
        for (int i = 0; i < MAX_FRAMES_IN_FLIGHT; i++) {
            vkCheck(vkCreateSemaphore(dev_, &si, nullptr, &imgAvail_[i]),   _T("semaphore"));
            vkCheck(vkCreateSemaphore(dev_, &si, nullptr, &renderDone_[i]), _T("semaphore"));
            vkCheck(vkCreateFence(dev_, &fi, nullptr, &inFlight_[i]),       _T("fence"));
        }
    }

    // ========================================================
    // Buffers & Descriptor writes
    // ========================================================
    void createBuffersAndDescriptors() {
        createBuf(static_cast<VkDeviceSize>(VERTEX_COUNT) * 16u,
                  VK_BUFFER_USAGE_STORAGE_BUFFER_BIT, VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT, posBuf_);
        createBuf(static_cast<VkDeviceSize>(VERTEX_COUNT) * 16u,
                  VK_BUFFER_USAGE_STORAGE_BUFFER_BIT, VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT, colBuf_);
        createBuf(static_cast<VkDeviceSize>(sizeof(ParamsUBO)),
                  VK_BUFFER_USAGE_UNIFORM_BUFFER_BIT,
                  VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | VK_MEMORY_PROPERTY_HOST_COHERENT_BIT, ubo_);

        VkDescriptorBufferInfo posInfo = { posBuf_.buf, 0, posBuf_.size };
        VkDescriptorBufferInfo colInfo = { colBuf_.buf, 0, colBuf_.size };
        VkDescriptorBufferInfo uboInfo = { ubo_.buf,    0, sizeof(ParamsUBO) };

        VkWriteDescriptorSet w[3];  std::memset(w, 0, sizeof(w));
        w[0].sType = VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET;  w[0].dstSet = dset_;
        w[0].dstBinding = 0;  w[0].descriptorType = VK_DESCRIPTOR_TYPE_STORAGE_BUFFER;
        w[0].descriptorCount = 1;  w[0].pBufferInfo = &posInfo;

        w[1].sType = VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET;  w[1].dstSet = dset_;
        w[1].dstBinding = 1;  w[1].descriptorType = VK_DESCRIPTOR_TYPE_STORAGE_BUFFER;
        w[1].descriptorCount = 1;  w[1].pBufferInfo = &colInfo;

        w[2].sType = VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET;  w[2].dstSet = dset_;
        w[2].dstBinding = 2;  w[2].descriptorType = VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER;
        w[2].descriptorCount = 1;  w[2].pBufferInfo = &uboInfo;

        vkUpdateDescriptorSets(dev_, 3, w, 0, nullptr);

        // Init params
        params_.max_num = VERTEX_COUNT;
        params_.dt    = 0.001f;
        params_.scale = 0.02f;
        params_.pad0  = 0.0f;
        params_.A1 = 50.0f; params_.f1 = 2.0f; params_.p1 = 1.0f/16.0f; params_.d1 = 0.02f;
        params_.A2 = 50.0f; params_.f2 = 2.0f; params_.p2 = 3.0f/2.0f;  params_.d2 = 0.0315f;
        params_.A3 = 50.0f; params_.f3 = 2.0f; params_.p3 = 13.0f/15.0f; params_.d3 = 0.02f;
        params_.A4 = 50.0f; params_.f4 = 2.0f; params_.p4 = 1.0f;        params_.d4 = 0.02f;
    }

    // ========================================================
    // UBO upload
    // ========================================================
    void updateUBO() {
        void* p = nullptr;
        vkCheck(vkMapMemory(dev_, ubo_.mem, 0, sizeof(ParamsUBO), 0, &p), "vkMapMemory");
        std::memcpy(p, &params_, sizeof(ParamsUBO));
        vkUnmapMemory(dev_, ubo_.mem);
    }

    // ========================================================
    // Record command buffer
    // ========================================================
    void recordCmd(VkCommandBuffer cmd, uint32_t imageIndex) {
        VkCommandBufferBeginInfo bi;  std::memset(&bi, 0, sizeof(bi));
        bi.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO;
        vkCheck(vkBeginCommandBuffer(cmd, &bi), _T("vkBeginCommandBuffer"));

        // Compute dispatch
        vkCmdBindPipeline(cmd, VK_PIPELINE_BIND_POINT_COMPUTE, pCompute_);
        vkCmdBindDescriptorSets(cmd, VK_PIPELINE_BIND_POINT_COMPUTE, plCompute_, 0, 1, &dset_, 0, nullptr);
        vkCmdDispatch(cmd, (VERTEX_COUNT + 255u) / 256u, 1, 1);

        // Barrier: compute writes -> vertex reads
        VkBufferMemoryBarrier bmb[2];  std::memset(bmb, 0, sizeof(bmb));
        bmb[0].sType = VK_STRUCTURE_TYPE_BUFFER_MEMORY_BARRIER;
        bmb[0].srcAccessMask = VK_ACCESS_SHADER_WRITE_BIT;
        bmb[0].dstAccessMask = VK_ACCESS_SHADER_READ_BIT;
        bmb[0].srcQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
        bmb[0].dstQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
        bmb[0].buffer = posBuf_.buf;  bmb[0].size = posBuf_.size;
        bmb[1] = bmb[0];
        bmb[1].buffer = colBuf_.buf;  bmb[1].size = colBuf_.size;

        vkCmdPipelineBarrier(cmd,
            VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT, VK_PIPELINE_STAGE_VERTEX_SHADER_BIT,
            0, 0, nullptr, 2, bmb, 0, nullptr);

        // Render pass
        VkClearValue cv;
        cv.color.float32[0] = 0.0f;  cv.color.float32[1] = 0.0f;
        cv.color.float32[2] = 0.0f;  cv.color.float32[3] = 1.0f;

        VkRenderPassBeginInfo rp;  std::memset(&rp, 0, sizeof(rp));
        rp.sType             = VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO;
        rp.renderPass        = renderPass_;
        rp.framebuffer       = framebuffers_[imageIndex];
        rp.renderArea.extent = scExtent_;
        rp.clearValueCount   = 1;
        rp.pClearValues      = &cv;

        vkCmdBeginRenderPass(cmd, &rp, VK_SUBPASS_CONTENTS_INLINE);
        vkCmdBindPipeline(cmd, VK_PIPELINE_BIND_POINT_GRAPHICS, pGfx_);
        vkCmdBindDescriptorSets(cmd, VK_PIPELINE_BIND_POINT_GRAPHICS, plGfx_, 0, 1, &dset_, 0, nullptr);
        vkCmdDraw(cmd, VERTEX_COUNT, 1, 0, 0);
        vkCmdEndRenderPass(cmd);

        vkCheck(vkEndCommandBuffer(cmd), _T("vkEndCommandBuffer"));
    }

    // ========================================================
    // Swap chain recreation
    // ========================================================
    void recreateSwapchain() {
        RECT rc;
        do { GetClientRect(g_hwnd, &rc);
             if ((rc.right-rc.left)==0 || (rc.bottom-rc.top)==0) Sleep(16);
        } while ((rc.right-rc.left)==0 || (rc.bottom-rc.top)==0);
        vkDeviceWaitIdle(dev_);
        cleanupSwapchain();
        createSwapchainAndViews();
        createFramebuffers();
        g_resized = false;
    }

    // ========================================================
    // Draw frame
    // ========================================================
    void drawFrame() {
        vkWaitForFences(dev_, 1, &inFlight_[frameIdx_], VK_TRUE, UINT64_MAX);
        vkResetFences(dev_, 1, &inFlight_[frameIdx_]);

        uint32_t imgIdx = 0;
        VkResult r = vkAcquireNextImageKHR(dev_, swapchain_, UINT64_MAX,
                                           imgAvail_[frameIdx_], VK_NULL_HANDLE, &imgIdx);
        if (r == VK_ERROR_OUT_OF_DATE_KHR) { recreateSwapchain(); return; }
        if (r != VK_SUCCESS && r != VK_SUBOPTIMAL_KHR) dieVk(r, "vkAcquireNextImageKHR");

        // Animate
        static float t = 0.0f;
        t += 0.016f;
        params_.f1 = 2.0f + 0.5f * sinf(t * 0.7f);
        params_.f2 = 2.0f + 0.5f * sinf(t * 0.9f);
        params_.f3 = 2.0f + 0.5f * sinf(t * 1.1f);
        params_.f4 = 2.0f + 0.5f * sinf(t * 1.3f);
        params_.p1 += 0.002f;
        updateUBO();

        vkResetCommandBuffer(cmd_[frameIdx_], 0);
        recordCmd(cmd_[frameIdx_], imgIdx);

        VkPipelineStageFlags waitStage = VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT;
        VkSubmitInfo si;  std::memset(&si, 0, sizeof(si));
        si.sType                = VK_STRUCTURE_TYPE_SUBMIT_INFO;
        si.waitSemaphoreCount   = 1;  si.pWaitSemaphores   = &imgAvail_[frameIdx_];
        si.pWaitDstStageMask    = &waitStage;
        si.commandBufferCount   = 1;  si.pCommandBuffers   = &cmd_[frameIdx_];
        si.signalSemaphoreCount = 1;  si.pSignalSemaphores = &renderDone_[frameIdx_];
        vkCheck(vkQueueSubmit(queue_, 1, &si, inFlight_[frameIdx_]), _T("vkQueueSubmit"));

        VkPresentInfoKHR pi;  std::memset(&pi, 0, sizeof(pi));
        pi.sType              = VK_STRUCTURE_TYPE_PRESENT_INFO_KHR;
        pi.waitSemaphoreCount = 1;  pi.pWaitSemaphores = &renderDone_[frameIdx_];
        pi.swapchainCount     = 1;  pi.pSwapchains     = &swapchain_;
        pi.pImageIndices      = &imgIdx;
        r = vkQueuePresentKHR(queue_, &pi);
        if (r == VK_ERROR_OUT_OF_DATE_KHR || r == VK_SUBOPTIMAL_KHR || g_resized) recreateSwapchain();
        else if (r != VK_SUCCESS) dieVk(r, "vkQueuePresentKHR");

        frameIdx_ = (frameIdx_ + 1) % MAX_FRAMES_IN_FLIGHT;
    }

    // ========================================================
    // Init / Main loop / Shutdown
    // ========================================================
    void initVulkan() {
        createInstanceAndSurface();
        pickDeviceAndCreate();
        createSwapchainAndViews();
        createRenderPass();
        createFramebuffers();
        createDescriptorLayoutAndSet();
        createPipelines();
        createCommandObjects();
        createSync();
        createBuffersAndDescriptors();
    }

    void mainLoop() {
        MSG msg;
        ULONGLONG startTick = GetTickCount64();
        while (g_running) {
            while (PeekMessage(&msg, nullptr, 0, 0, PM_REMOVE)) {
                TranslateMessage(&msg);  DispatchMessage(&msg);
            }
            if (GetTickCount64() - startTick > 60000ull) g_running = false;
            drawFrame();
            Sleep(1);
        }
    }

    void shutdownVulkan() {
        vkDeviceWaitIdle(dev_);
        destroyBuf(posBuf_);  destroyBuf(colBuf_);  destroyBuf(ubo_);
        for (int i = 0; i < MAX_FRAMES_IN_FLIGHT; i++) {
            if (imgAvail_[i])   vkDestroySemaphore(dev_, imgAvail_[i], nullptr);
            if (renderDone_[i]) vkDestroySemaphore(dev_, renderDone_[i], nullptr);
            if (inFlight_[i])   vkDestroyFence(dev_, inFlight_[i], nullptr);
        }
        if (cmdPool_)    vkDestroyCommandPool(dev_, cmdPool_, nullptr);
        if (pGfx_)       vkDestroyPipeline(dev_, pGfx_, nullptr);
        if (plGfx_)      vkDestroyPipelineLayout(dev_, plGfx_, nullptr);
        if (pCompute_)   vkDestroyPipeline(dev_, pCompute_, nullptr);
        if (plCompute_)  vkDestroyPipelineLayout(dev_, plCompute_, nullptr);
        if (dpool_)      vkDestroyDescriptorPool(dev_, dpool_, nullptr);
        if (dsl_)        vkDestroyDescriptorSetLayout(dev_, dsl_, nullptr);
        if (renderPass_) vkDestroyRenderPass(dev_, renderPass_, nullptr);
        cleanupSwapchain();
        if (dev_)     vkDestroyDevice(dev_, nullptr);
        if (surface_) vkDestroySurfaceKHR(instance_, surface_, nullptr);
        if (g_enableValidation && dbgMessenger_) {
            auto fn = reinterpret_cast<PFN_vkDestroyDebugUtilsMessengerEXT>(
                vkGetInstanceProcAddr(instance_, "vkDestroyDebugUtilsMessengerEXT"));
            if (fn) fn(instance_, dbgMessenger_, nullptr);
        }
        if (instance_) vkDestroyInstance(instance_, nullptr);
    }
};

// ============================================================
// WinMain
// ============================================================
int WINAPI WinMain(HINSTANCE, HINSTANCE, LPSTR, int) {
    HarmonographApp app;
    app.run();
    return 0;
}
