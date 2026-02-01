// hello_wtl.cpp
// WTL + Vulkan 1.4 Triangle (no GLFW, no extra libs)
//
// Build (example):
//  cl hello_wtl.cpp /std:c++20 /EHsc /DUNICODE /D_UNICODE /I"%VULKAN_SDK%\Include" ^
//    /link /LIBPATH:"%VULKAN_SDK%\Lib" user32.lib gdi32.lib shell32.lib vulkan-1.lib /SUBSYSTEM:WINDOWS
//
// Shaders (place next to exe):
//  hello_vert.spv, hello_frag.spv

#define WIN32_LEAN_AND_MEAN
#define NOMINMAX
#define VK_USE_PLATFORM_WIN32_KHR

#include <windows.h>
#include <vulkan/vulkan.h>

#include <atlbase.h>
#include <atlapp.h>
#include <atlwin.h>
#include <atlframe.h>

#include <vector>
#include <string>
#include <fstream>
#include <stdexcept>
#include <algorithm>
#include <cstdint>

CAppModule _Module;

static void VkCheck(VkResult r, const char* what)
{
    if (r != VK_SUCCESS) {
        char buf[256];
        wsprintfA(buf, "%s failed: VkResult=%d", what, (int)r);
        ::MessageBoxA(nullptr, buf, "Vulkan Error", MB_ICONERROR | MB_OK);
        ::ExitProcess((UINT)r);
    }
}

static std::vector<char> ReadFile(const char* path)
{
    std::ifstream f(path, std::ios::binary | std::ios::ate);
    if (!f) throw std::runtime_error(std::string("failed to open: ") + path);
    const std::streamsize size = f.tellg();
    f.seekg(0);
    std::vector<char> data((size_t)size);
    f.read(data.data(), size);
    return data;
}

#ifdef _DEBUG
static VKAPI_ATTR VkBool32 VKAPI_CALL DebugCallback(
    VkDebugUtilsMessageSeverityFlagBitsEXT severity,
    VkDebugUtilsMessageTypeFlagsEXT type,
    const VkDebugUtilsMessengerCallbackDataEXT* cb,
    void* user)
{
    (void)severity; (void)type; (void)user;
    ::OutputDebugStringA(cb->pMessage);
    ::OutputDebugStringA("\n");
    return VK_FALSE;
}

static VkResult CreateDebugUtilsMessengerEXT(
    VkInstance inst,
    const VkDebugUtilsMessengerCreateInfoEXT* ci,
    const VkAllocationCallbacks* alloc,
    VkDebugUtilsMessengerEXT* out)
{
    auto fn = (PFN_vkCreateDebugUtilsMessengerEXT)vkGetInstanceProcAddr(inst, "vkCreateDebugUtilsMessengerEXT");
    return fn ? fn(inst, ci, alloc, out) : VK_ERROR_EXTENSION_NOT_PRESENT;
}
static void DestroyDebugUtilsMessengerEXT(
    VkInstance inst,
    VkDebugUtilsMessengerEXT m,
    const VkAllocationCallbacks* alloc)
{
    auto fn = (PFN_vkDestroyDebugUtilsMessengerEXT)vkGetInstanceProcAddr(inst, "vkDestroyDebugUtilsMessengerEXT");
    if (fn) fn(inst, m, alloc);
}
#endif

class CMainFrame :
    public CFrameWindowImpl<CMainFrame>,
    public CIdleHandler
{
public:
    DECLARE_FRAME_WND_CLASS(_T("WTL_VulkanTriangle"), 0)

    BEGIN_MSG_MAP(CMainFrame)
        MESSAGE_HANDLER(WM_CREATE, OnCreate)
        MESSAGE_HANDLER(WM_SIZE, OnSize)
        MESSAGE_HANDLER(WM_DESTROY, OnDestroy)
        CHAIN_MSG_MAP(CFrameWindowImpl<CMainFrame>)
    END_MSG_MAP()

    BOOL OnIdle() override
    {
        RenderFrame();
        return TRUE; // keep rendering
    }

private:
    // --- Vulkan objects ---
    VkInstance m_instance = VK_NULL_HANDLE;
#ifdef _DEBUG
    VkDebugUtilsMessengerEXT m_debug = VK_NULL_HANDLE;
#endif
    VkSurfaceKHR m_surface = VK_NULL_HANDLE;
    VkPhysicalDevice m_phys = VK_NULL_HANDLE;
    VkDevice m_device = VK_NULL_HANDLE;

    uint32_t m_gfxFam = UINT32_MAX;
    uint32_t m_presFam = UINT32_MAX;
    VkQueue m_gfxQ = VK_NULL_HANDLE;
    VkQueue m_presQ = VK_NULL_HANDLE;

    VkSwapchainKHR m_swap = VK_NULL_HANDLE;
    VkFormat m_swapFmt = VK_FORMAT_B8G8R8A8_UNORM;
    VkExtent2D m_extent{ 0,0 };
    std::vector<VkImage> m_images;
    std::vector<VkImageView> m_views;

    VkRenderPass m_rp = VK_NULL_HANDLE;
    VkPipelineLayout m_pl = VK_NULL_HANDLE;
    VkPipeline m_pipe = VK_NULL_HANDLE;
    std::vector<VkFramebuffer> m_fbs;

    VkCommandPool m_pool = VK_NULL_HANDLE;
    std::vector<VkCommandBuffer> m_cbs;

    static constexpr uint32_t kFrames = 2;
    uint32_t m_frame = 0;
    VkSemaphore m_imgAvail[kFrames]{};
    VkSemaphore m_done[kFrames]{};
    VkFence     m_fence[kFrames]{};

    bool m_needRecreate = false;
    bool m_minimized = false;

public:
    LRESULT OnCreate(UINT, WPARAM, LPARAM, BOOL&)
    {
        InitVulkan();
        CreateSwapchainAndFriends();
        CreateSync();

        if (auto loop = _Module.GetMessageLoop()) {
            loop->AddIdleHandler(this);
        }
        return 0;
    }

    LRESULT OnSize(UINT, WPARAM wParam, LPARAM lParam, BOOL&)
    {
        if (wParam == SIZE_MINIMIZED) {
            m_minimized = true;
            return 0;
        }
        m_minimized = false;

        const UINT w = LOWORD(lParam);
        const UINT h = HIWORD(lParam);
        if (w == 0 || h == 0) return 0;

        m_needRecreate = true;
        return 0;
    }

    LRESULT OnDestroy(UINT, WPARAM, LPARAM, BOOL&)
    {
        if (auto loop = _Module.GetMessageLoop()) {
            loop->RemoveIdleHandler(this);
        }
        Cleanup();
        ::PostQuitMessage(0);
        return 0;
    }

private:
    void InitVulkan()
    {
        // Instance
        VkApplicationInfo app{ VK_STRUCTURE_TYPE_APPLICATION_INFO };
        app.pApplicationName = "WTL Vulkan Triangle";
        app.applicationVersion = VK_MAKE_VERSION(1, 0, 0);
        app.pEngineName = "no-engine";
        app.engineVersion = VK_MAKE_VERSION(1, 0, 0);
        app.apiVersion = VK_API_VERSION_1_4;

        std::vector<const char*> exts = {
            VK_KHR_SURFACE_EXTENSION_NAME,
            VK_KHR_WIN32_SURFACE_EXTENSION_NAME
        };
#ifdef _DEBUG
        exts.push_back(VK_EXT_DEBUG_UTILS_EXTENSION_NAME);
        const char* layers[] = { "VK_LAYER_KHRONOS_validation" };
#endif

        VkInstanceCreateInfo ci{ VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO };
        ci.pApplicationInfo = &app;
        ci.enabledExtensionCount = (uint32_t)exts.size();
        ci.ppEnabledExtensionNames = exts.data();
#ifdef _DEBUG
        ci.enabledLayerCount = 1;
        ci.ppEnabledLayerNames = layers;

        VkDebugUtilsMessengerCreateInfoEXT dbgci{ VK_STRUCTURE_TYPE_DEBUG_UTILS_MESSENGER_CREATE_INFO_EXT };
        dbgci.messageSeverity =
            VK_DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT |
            VK_DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT;
        dbgci.messageType =
            VK_DEBUG_UTILS_MESSAGE_TYPE_GENERAL_BIT_EXT |
            VK_DEBUG_UTILS_MESSAGE_TYPE_VALIDATION_BIT_EXT |
            VK_DEBUG_UTILS_MESSAGE_TYPE_PERFORMANCE_BIT_EXT;
        dbgci.pfnUserCallback = DebugCallback;
        ci.pNext = &dbgci;
#endif

        VkCheck(vkCreateInstance(&ci, nullptr, &m_instance), "vkCreateInstance");

#ifdef _DEBUG
        VkDebugUtilsMessengerCreateInfoEXT dbgci2{ VK_STRUCTURE_TYPE_DEBUG_UTILS_MESSENGER_CREATE_INFO_EXT };
        dbgci2.messageSeverity =
            VK_DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT |
            VK_DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT;
        dbgci2.messageType =
            VK_DEBUG_UTILS_MESSAGE_TYPE_GENERAL_BIT_EXT |
            VK_DEBUG_UTILS_MESSAGE_TYPE_VALIDATION_BIT_EXT |
            VK_DEBUG_UTILS_MESSAGE_TYPE_PERFORMANCE_BIT_EXT;
        dbgci2.pfnUserCallback = DebugCallback;
        VkCheck(CreateDebugUtilsMessengerEXT(m_instance, &dbgci2, nullptr, &m_debug), "CreateDebugUtilsMessengerEXT");
#endif

        // Surface (WTL HWND)
        VkWin32SurfaceCreateInfoKHR sci{ VK_STRUCTURE_TYPE_WIN32_SURFACE_CREATE_INFO_KHR };
        sci.hinstance = ::GetModuleHandleW(nullptr);
        sci.hwnd = m_hWnd;
        VkCheck(vkCreateWin32SurfaceKHR(m_instance, &sci, nullptr, &m_surface), "vkCreateWin32SurfaceKHR");

        PickPhysicalDevice();
        CreateDevice();
        CreateCommandPool();
    }

    void PickPhysicalDevice()
    {
        uint32_t count = 0;
        VkCheck(vkEnumeratePhysicalDevices(m_instance, &count, nullptr), "vkEnumeratePhysicalDevices(count)");
        if (count == 0) {
            ::MessageBoxW(nullptr, L"No Vulkan devices found.", L"Error", MB_ICONERROR | MB_OK);
            ::ExitProcess(1);
        }
        std::vector<VkPhysicalDevice> devs(count);
        VkCheck(vkEnumeratePhysicalDevices(m_instance, &count, devs.data()), "vkEnumeratePhysicalDevices(list)");

        for (auto pd : devs) {
            uint32_t qCount = 0;
            vkGetPhysicalDeviceQueueFamilyProperties(pd, &qCount, nullptr);
            std::vector<VkQueueFamilyProperties> qprops(qCount);
            vkGetPhysicalDeviceQueueFamilyProperties(pd, &qCount, qprops.data());

            uint32_t gfx = UINT32_MAX, pres = UINT32_MAX;
            for (uint32_t i = 0; i < qCount; i++) {
                if ((qprops[i].queueFlags & VK_QUEUE_GRAPHICS_BIT) && gfx == UINT32_MAX)
                    gfx = i;

                VkBool32 sup = VK_FALSE;
                VkCheck(vkGetPhysicalDeviceSurfaceSupportKHR(pd, i, m_surface, &sup),
                        "vkGetPhysicalDeviceSurfaceSupportKHR");
                if (sup && pres == UINT32_MAX) pres = i;
            }
            if (gfx == UINT32_MAX || pres == UINT32_MAX) continue;

            // swapchain ext
            uint32_t ecount = 0;
            VkCheck(vkEnumerateDeviceExtensionProperties(pd, nullptr, &ecount, nullptr),
                    "vkEnumerateDeviceExtensionProperties(count)");
            std::vector<VkExtensionProperties> exts(ecount);
            VkCheck(vkEnumerateDeviceExtensionProperties(pd, nullptr, &ecount, exts.data()),
                    "vkEnumerateDeviceExtensionProperties(list)");
            bool hasSwap = false;
            for (auto& e : exts) {
                if (strcmp(e.extensionName, VK_KHR_SWAPCHAIN_EXTENSION_NAME) == 0) { hasSwap = true; break; }
            }
            if (!hasSwap) continue;

            m_phys = pd;
            m_gfxFam = gfx;
            m_presFam = pres;
            return;
        }

        ::MessageBoxW(nullptr, L"No suitable Vulkan device.", L"Error", MB_ICONERROR | MB_OK);
        ::ExitProcess(1);
    }

    void CreateDevice()
    {
        float prio = 1.0f;
        std::vector<VkDeviceQueueCreateInfo> qcis;

        auto addQ = [&](uint32_t fam) {
            VkDeviceQueueCreateInfo q{ VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO };
            q.queueFamilyIndex = fam;
            q.queueCount = 1;
            q.pQueuePriorities = &prio;
            qcis.push_back(q);
        };

        if (m_gfxFam == m_presFam) addQ(m_gfxFam);
        else { addQ(m_gfxFam); addQ(m_presFam); }

        const char* devExts[] = { VK_KHR_SWAPCHAIN_EXTENSION_NAME };

        VkDeviceCreateInfo dci{ VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO };
        dci.queueCreateInfoCount = (uint32_t)qcis.size();
        dci.pQueueCreateInfos = qcis.data();
        dci.enabledExtensionCount = 1;
        dci.ppEnabledExtensionNames = devExts;

#ifdef _DEBUG
        const char* layers[] = { "VK_LAYER_KHRONOS_validation" };
        dci.enabledLayerCount = 1;
        dci.ppEnabledLayerNames = layers;
#endif

        VkCheck(vkCreateDevice(m_phys, &dci, nullptr, &m_device), "vkCreateDevice");

        vkGetDeviceQueue(m_device, m_gfxFam, 0, &m_gfxQ);
        vkGetDeviceQueue(m_device, m_presFam, 0, &m_presQ);
    }

    void CreateCommandPool()
    {
        VkCommandPoolCreateInfo ci{ VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO };
        ci.queueFamilyIndex = m_gfxFam;
        ci.flags = VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT;
        VkCheck(vkCreateCommandPool(m_device, &ci, nullptr, &m_pool), "vkCreateCommandPool");
    }

    VkSurfaceFormatKHR ChooseFormat(const std::vector<VkSurfaceFormatKHR>& fmts)
    {
        for (auto& f : fmts) {
            if (f.format == VK_FORMAT_B8G8R8A8_UNORM &&
                f.colorSpace == VK_COLOR_SPACE_SRGB_NONLINEAR_KHR)
                return f;
        }
        return fmts[0];
    }

    VkExtent2D ChooseExtent(const VkSurfaceCapabilitiesKHR& caps)
    {
        if (caps.currentExtent.width != 0xFFFFFFFF) return caps.currentExtent;

        RECT rc{};
        ::GetClientRect(m_hWnd, &rc);
        uint32_t w = std::max<LONG>(1, rc.right - rc.left);
        uint32_t h = std::max<LONG>(1, rc.bottom - rc.top);

        VkExtent2D e;
        e.width = std::clamp<uint32_t>(w, caps.minImageExtent.width, caps.maxImageExtent.width);
        e.height = std::clamp<uint32_t>(h, caps.minImageExtent.height, caps.maxImageExtent.height);
        return e;
    }

    void CreateSwapchain()
    {
        VkSurfaceCapabilitiesKHR caps{};
        VkCheck(vkGetPhysicalDeviceSurfaceCapabilitiesKHR(m_phys, m_surface, &caps),
                "vkGetPhysicalDeviceSurfaceCapabilitiesKHR");

        uint32_t fcount = 0;
        VkCheck(vkGetPhysicalDeviceSurfaceFormatsKHR(m_phys, m_surface, &fcount, nullptr),
                "vkGetPhysicalDeviceSurfaceFormatsKHR(count)");
        std::vector<VkSurfaceFormatKHR> fmts(fcount);
        VkCheck(vkGetPhysicalDeviceSurfaceFormatsKHR(m_phys, m_surface, &fcount, fmts.data()),
                "vkGetPhysicalDeviceSurfaceFormatsKHR(list)");

        uint32_t mcount = 0;
        VkCheck(vkGetPhysicalDeviceSurfacePresentModesKHR(m_phys, m_surface, &mcount, nullptr),
                "vkGetPhysicalDeviceSurfacePresentModesKHR(count)");
        std::vector<VkPresentModeKHR> modes(mcount);
        VkCheck(vkGetPhysicalDeviceSurfacePresentModesKHR(m_phys, m_surface, &mcount, modes.data()),
                "vkGetPhysicalDeviceSurfacePresentModesKHR(list)");

        VkSurfaceFormatKHR sf = ChooseFormat(fmts);
        VkPresentModeKHR pm = VK_PRESENT_MODE_FIFO_KHR; // always supported
        VkExtent2D ex = ChooseExtent(caps);

        uint32_t imgCount = caps.minImageCount + 1;
        if (caps.maxImageCount && imgCount > caps.maxImageCount) imgCount = caps.maxImageCount;

        VkSwapchainCreateInfoKHR ci{ VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR };
        ci.surface = m_surface;
        ci.minImageCount = imgCount;
        ci.imageFormat = sf.format;
        ci.imageColorSpace = sf.colorSpace;
        ci.imageExtent = ex;
        ci.imageArrayLayers = 1;
        ci.imageUsage = VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT;

        uint32_t qIdx[2] = { m_gfxFam, m_presFam };
        if (m_gfxFam != m_presFam) {
            ci.imageSharingMode = VK_SHARING_MODE_CONCURRENT;
            ci.queueFamilyIndexCount = 2;
            ci.pQueueFamilyIndices = qIdx;
        } else {
            ci.imageSharingMode = VK_SHARING_MODE_EXCLUSIVE;
        }

        ci.preTransform = caps.currentTransform;
        ci.compositeAlpha = VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR;
        ci.presentMode = pm;
        ci.clipped = VK_TRUE;

        VkCheck(vkCreateSwapchainKHR(m_device, &ci, nullptr, &m_swap), "vkCreateSwapchainKHR");

        uint32_t sc = 0;
        VkCheck(vkGetSwapchainImagesKHR(m_device, m_swap, &sc, nullptr), "vkGetSwapchainImagesKHR(count)");
        m_images.resize(sc);
        VkCheck(vkGetSwapchainImagesKHR(m_device, m_swap, &sc, m_images.data()), "vkGetSwapchainImagesKHR(list)");

        m_swapFmt = sf.format;
        m_extent = ex;
    }

    void CreateViews()
    {
        m_views.resize(m_images.size());
        for (size_t i = 0; i < m_images.size(); i++) {
            VkImageViewCreateInfo ci{ VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO };
            ci.image = m_images[i];
            ci.viewType = VK_IMAGE_VIEW_TYPE_2D;
            ci.format = m_swapFmt;
            ci.subresourceRange.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT;
            ci.subresourceRange.levelCount = 1;
            ci.subresourceRange.layerCount = 1;
            VkCheck(vkCreateImageView(m_device, &ci, nullptr, &m_views[i]), "vkCreateImageView");
        }
    }

    void CreateRenderPass()
    {
        VkAttachmentDescription color{};
        color.format = m_swapFmt;
        color.samples = VK_SAMPLE_COUNT_1_BIT;
        color.loadOp = VK_ATTACHMENT_LOAD_OP_CLEAR;
        color.storeOp = VK_ATTACHMENT_STORE_OP_STORE;
        color.initialLayout = VK_IMAGE_LAYOUT_UNDEFINED;
        color.finalLayout = VK_IMAGE_LAYOUT_PRESENT_SRC_KHR;

        VkAttachmentReference ref{};
        ref.attachment = 0;
        ref.layout = VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL;

        VkSubpassDescription sub{};
        sub.pipelineBindPoint = VK_PIPELINE_BIND_POINT_GRAPHICS;
        sub.colorAttachmentCount = 1;
        sub.pColorAttachments = &ref;

        VkSubpassDependency dep{};
        dep.srcSubpass = VK_SUBPASS_EXTERNAL;
        dep.dstSubpass = 0;
        dep.srcStageMask = VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT;
        dep.dstStageMask = VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT;
        dep.dstAccessMask = VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT;

        VkRenderPassCreateInfo ci{ VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO };
        ci.attachmentCount = 1;
        ci.pAttachments = &color;
        ci.subpassCount = 1;
        ci.pSubpasses = &sub;
        ci.dependencyCount = 1;
        ci.pDependencies = &dep;

        VkCheck(vkCreateRenderPass(m_device, &ci, nullptr, &m_rp), "vkCreateRenderPass");
    }

    VkShaderModule CreateShaderModule(const std::vector<char>& code)
    {
        VkShaderModuleCreateInfo ci{ VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO };
        ci.codeSize = code.size();
        ci.pCode = (const uint32_t*)code.data();
        VkShaderModule m = VK_NULL_HANDLE;
        VkCheck(vkCreateShaderModule(m_device, &ci, nullptr, &m), "vkCreateShaderModule");
        return m;
    }

    void CreatePipeline()
    {
        auto vsCode = ReadFile("hello_vert.spv");
        auto fsCode = ReadFile("hello_frag.spv");
        VkShaderModule vs = CreateShaderModule(vsCode);
        VkShaderModule fs = CreateShaderModule(fsCode);

        VkPipelineShaderStageCreateInfo st[2]{};
        st[0].sType = VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO;
        st[0].stage = VK_SHADER_STAGE_VERTEX_BIT;
        st[0].module = vs;
        st[0].pName = "main";
        st[1].sType = VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO;
        st[1].stage = VK_SHADER_STAGE_FRAGMENT_BIT;
        st[1].module = fs;
        st[1].pName = "main";

        VkPipelineVertexInputStateCreateInfo vin{ VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO };
        VkPipelineInputAssemblyStateCreateInfo ia{ VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO };
        ia.topology = VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST;

        VkPipelineViewportStateCreateInfo vp{ VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO };
        vp.viewportCount = 1;
        vp.scissorCount = 1;

        VkPipelineRasterizationStateCreateInfo rs{ VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO };
        rs.polygonMode = VK_POLYGON_MODE_FILL;
        rs.cullMode = VK_CULL_MODE_NONE;
        rs.frontFace = VK_FRONT_FACE_COUNTER_CLOCKWISE;
        rs.lineWidth = 1.0f;

        VkPipelineMultisampleStateCreateInfo ms{ VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO };
        ms.rasterizationSamples = VK_SAMPLE_COUNT_1_BIT;

        VkPipelineColorBlendAttachmentState att{};
        att.colorWriteMask =
            VK_COLOR_COMPONENT_R_BIT | VK_COLOR_COMPONENT_G_BIT |
            VK_COLOR_COMPONENT_B_BIT | VK_COLOR_COMPONENT_A_BIT;

        VkPipelineColorBlendStateCreateInfo cb{ VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO };
        cb.attachmentCount = 1;
        cb.pAttachments = &att;

        VkDynamicState dyns[] = { VK_DYNAMIC_STATE_VIEWPORT, VK_DYNAMIC_STATE_SCISSOR };
        VkPipelineDynamicStateCreateInfo dyn{ VK_STRUCTURE_TYPE_PIPELINE_DYNAMIC_STATE_CREATE_INFO };
        dyn.dynamicStateCount = 2;
        dyn.pDynamicStates = dyns;

        VkPipelineLayoutCreateInfo pl{ VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO };
        VkCheck(vkCreatePipelineLayout(m_device, &pl, nullptr, &m_pl), "vkCreatePipelineLayout");

        VkGraphicsPipelineCreateInfo gp{ VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO };
        gp.stageCount = 2;
        gp.pStages = st;
        gp.pVertexInputState = &vin;
        gp.pInputAssemblyState = &ia;
        gp.pViewportState = &vp;
        gp.pRasterizationState = &rs;
        gp.pMultisampleState = &ms;
        gp.pColorBlendState = &cb;
        gp.pDynamicState = &dyn;
        gp.layout = m_pl;
        gp.renderPass = m_rp;
        gp.subpass = 0;

        VkCheck(vkCreateGraphicsPipelines(m_device, VK_NULL_HANDLE, 1, &gp, nullptr, &m_pipe),
                "vkCreateGraphicsPipelines");

        vkDestroyShaderModule(m_device, fs, nullptr);
        vkDestroyShaderModule(m_device, vs, nullptr);
    }

    void CreateFramebuffers()
    {
        m_fbs.resize(m_views.size());
        for (size_t i = 0; i < m_views.size(); i++) {
            VkImageView atts[] = { m_views[i] };
            VkFramebufferCreateInfo ci{ VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO };
            ci.renderPass = m_rp;
            ci.attachmentCount = 1;
            ci.pAttachments = atts;
            ci.width = m_extent.width;
            ci.height = m_extent.height;
            ci.layers = 1;
            VkCheck(vkCreateFramebuffer(m_device, &ci, nullptr, &m_fbs[i]), "vkCreateFramebuffer");
        }
    }

    void AllocAndRecordCB()
    {
        m_cbs.resize(m_fbs.size());
        VkCommandBufferAllocateInfo ai{ VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO };
        ai.commandPool = m_pool;
        ai.level = VK_COMMAND_BUFFER_LEVEL_PRIMARY;
        ai.commandBufferCount = (uint32_t)m_cbs.size();
        VkCheck(vkAllocateCommandBuffers(m_device, &ai, m_cbs.data()), "vkAllocateCommandBuffers");

        for (uint32_t i = 0; i < (uint32_t)m_cbs.size(); i++) {
            VkCommandBuffer cb = m_cbs[i];

            VkCommandBufferBeginInfo bi{ VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO };
            VkCheck(vkBeginCommandBuffer(cb, &bi), "vkBeginCommandBuffer");

            VkClearValue clear{};
            clear.color = { { 0.05f, 0.05f, 0.08f, 1.0f } };

            VkRenderPassBeginInfo rp{ VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO };
            rp.renderPass = m_rp;
            rp.framebuffer = m_fbs[i];
            rp.renderArea.extent = m_extent;
            rp.clearValueCount = 1;
            rp.pClearValues = &clear;

            vkCmdBeginRenderPass(cb, &rp, VK_SUBPASS_CONTENTS_INLINE);
            vkCmdBindPipeline(cb, VK_PIPELINE_BIND_POINT_GRAPHICS, m_pipe);

            VkViewport v{};
            v.width = (float)m_extent.width;
            v.height = (float)m_extent.height;
            v.maxDepth = 1.0f;
            vkCmdSetViewport(cb, 0, 1, &v);

            VkRect2D s{};
            s.extent = m_extent;
            vkCmdSetScissor(cb, 0, 1, &s);

            vkCmdDraw(cb, 3, 1, 0, 0);
            vkCmdEndRenderPass(cb);

            VkCheck(vkEndCommandBuffer(cb), "vkEndCommandBuffer");
        }
    }

    void CreateSwapchainAndFriends()
    {
        CreateSwapchain();
        CreateViews();
        CreateRenderPass();
        CreatePipeline();
        CreateFramebuffers();
        AllocAndRecordCB();
    }

    void DestroySwapchainAndFriends()
    {
        if (!m_device) return;
        vkDeviceWaitIdle(m_device);

        if (!m_cbs.empty()) {
            vkFreeCommandBuffers(m_device, m_pool, (uint32_t)m_cbs.size(), m_cbs.data());
            m_cbs.clear();
        }

        for (auto fb : m_fbs) vkDestroyFramebuffer(m_device, fb, nullptr);
        m_fbs.clear();

        if (m_pipe) vkDestroyPipeline(m_device, m_pipe, nullptr), m_pipe = VK_NULL_HANDLE;
        if (m_pl) vkDestroyPipelineLayout(m_device, m_pl, nullptr), m_pl = VK_NULL_HANDLE;
        if (m_rp) vkDestroyRenderPass(m_device, m_rp, nullptr), m_rp = VK_NULL_HANDLE;

        for (auto v : m_views) vkDestroyImageView(m_device, v, nullptr);
        m_views.clear();

        if (m_swap) vkDestroySwapchainKHR(m_device, m_swap, nullptr), m_swap = VK_NULL_HANDLE;
        m_images.clear();
        m_extent = { 0,0 };
    }

    void RecreateSwapchain()
    {
        if (m_minimized) return;

        RECT rc{};
        ::GetClientRect(m_hWnd, &rc);
        if ((rc.right - rc.left) == 0 || (rc.bottom - rc.top) == 0) return;

        DestroySwapchainAndFriends();
        CreateSwapchainAndFriends();
        m_needRecreate = false;
    }

    void CreateSync()
    {
        VkSemaphoreCreateInfo si{ VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO };
        VkFenceCreateInfo fi{ VK_STRUCTURE_TYPE_FENCE_CREATE_INFO };
        fi.flags = VK_FENCE_CREATE_SIGNALED_BIT;

        for (uint32_t i = 0; i < kFrames; i++) {
            VkCheck(vkCreateSemaphore(m_device, &si, nullptr, &m_imgAvail[i]), "vkCreateSemaphore(imgAvail)");
            VkCheck(vkCreateSemaphore(m_device, &si, nullptr, &m_done[i]), "vkCreateSemaphore(done)");
            VkCheck(vkCreateFence(m_device, &fi, nullptr, &m_fence[i]), "vkCreateFence(fence)");
        }
    }

    void RenderFrame()
    {
        if (!m_device) return;

        if (m_needRecreate) {
            RecreateSwapchain();
            return;
        }
        if (m_minimized || !m_swap) return;

        VkFence f = m_fence[m_frame];
        VkCheck(vkWaitForFences(m_device, 1, &f, VK_TRUE, UINT64_MAX), "vkWaitForFences");
        VkCheck(vkResetFences(m_device, 1, &f), "vkResetFences");

        uint32_t imgIndex = 0;
        VkResult acq = vkAcquireNextImageKHR(m_device, m_swap, UINT64_MAX, m_imgAvail[m_frame], VK_NULL_HANDLE, &imgIndex);
        if (acq == VK_ERROR_OUT_OF_DATE_KHR) { m_needRecreate = true; return; }
        VkCheck(acq, "vkAcquireNextImageKHR");

        VkPipelineStageFlags waitStage = VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT;

        VkSubmitInfo sub{ VK_STRUCTURE_TYPE_SUBMIT_INFO };
        sub.waitSemaphoreCount = 1;
        sub.pWaitSemaphores = &m_imgAvail[m_frame];
        sub.pWaitDstStageMask = &waitStage;
        sub.commandBufferCount = 1;
        sub.pCommandBuffers = &m_cbs[imgIndex];
        sub.signalSemaphoreCount = 1;
        sub.pSignalSemaphores = &m_done[m_frame];

        VkCheck(vkQueueSubmit(m_gfxQ, 1, &sub, f), "vkQueueSubmit");

        VkPresentInfoKHR pi{ VK_STRUCTURE_TYPE_PRESENT_INFO_KHR };
        pi.waitSemaphoreCount = 1;
        pi.pWaitSemaphores = &m_done[m_frame];
        pi.swapchainCount = 1;
        pi.pSwapchains = &m_swap;
        pi.pImageIndices = &imgIndex;

        VkResult pres = vkQueuePresentKHR(m_presQ, &pi);
        if (pres == VK_ERROR_OUT_OF_DATE_KHR || pres == VK_SUBOPTIMAL_KHR) {
            m_needRecreate = true;
        } else {
            VkCheck(pres, "vkQueuePresentKHR");
        }

        m_frame = (m_frame + 1) % kFrames;
    }

    void Cleanup()
    {
        if (m_device) vkDeviceWaitIdle(m_device);

        for (uint32_t i = 0; i < kFrames; i++) {
            if (m_fence[i]) vkDestroyFence(m_device, m_fence[i], nullptr);
            if (m_done[i]) vkDestroySemaphore(m_device, m_done[i], nullptr);
            if (m_imgAvail[i]) vkDestroySemaphore(m_device, m_imgAvail[i], nullptr);
            m_fence[i] = VK_NULL_HANDLE;
            m_done[i] = VK_NULL_HANDLE;
            m_imgAvail[i] = VK_NULL_HANDLE;
        }

        DestroySwapchainAndFriends();

        if (m_pool) vkDestroyCommandPool(m_device, m_pool, nullptr), m_pool = VK_NULL_HANDLE;
        if (m_device) vkDestroyDevice(m_device, nullptr), m_device = VK_NULL_HANDLE;

        if (m_surface) vkDestroySurfaceKHR(m_instance, m_surface, nullptr), m_surface = VK_NULL_HANDLE;

#ifdef _DEBUG
        if (m_debug) DestroyDebugUtilsMessengerEXT(m_instance, m_debug, nullptr), m_debug = VK_NULL_HANDLE;
#endif
        if (m_instance) vkDestroyInstance(m_instance, nullptr), m_instance = VK_NULL_HANDLE;
    }
};

int WINAPI wWinMain(HINSTANCE hInst, HINSTANCE, PWSTR, int nCmdShow)
{
    _Module.Init(nullptr, hInst);

    CMessageLoop loop;
    _Module.AddMessageLoop(&loop);

    CMainFrame wnd;
    if (wnd.CreateEx() == nullptr) return 0;
    wnd.SetWindowText(_T("Hello Vulkan (WTL)"));
    wnd.ResizeClient(800, 600);
    wnd.ShowWindow(nCmdShow);

    int ret = loop.Run();

    _Module.RemoveMessageLoop();
    _Module.Term();
    return ret;
}
