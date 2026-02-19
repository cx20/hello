// hello_dcomp_vk.cpp - Vulkan Triangle via DirectComposition
//
// Build (Visual Studio Developer Command Prompt):
//   cl /EHsc /std:c++17 /I%VULKAN_SDK%\Include hello_dcomp_vk.cpp ^
//      /link /LIBPATH:%VULKAN_SDK%\Lib vulkan-1.lib d3d11.lib dxgi.lib dcomp.lib user32.lib
//
// Shaders (same as hello.vert / hello.frag):
//   %VULKAN_SDK%\Bin\glslangValidator -V hello.vert -o hello_vert.spv
//   %VULKAN_SDK%\Bin\glslangValidator -V hello.frag -o hello_frag.spv
//
// Architecture:
//   [Vulkan Draw] -> [Offscreen VkImage] -> [Staging Buffer (host-visible)]
//       -> [memcpy] -> [D3D11 Staging Texture] -> [CopyResource]
//       -> [D3D11 BackBuffer / SwapChain] -> [DComp Visual] -> [DWM] -> [Display]
//
// No GLFW required. No VkSurfaceKHR / VkSwapchainKHR used.
// DirectComposition is pure Win32 COM (no WinRT).
//
// Debug output: OutputDebugString - monitor with DebugView (SysInternals)

#define WIN32_LEAN_AND_MEAN
#define NOMINMAX
#include <windows.h>
#include <d3d11.h>
#include <dxgi1_2.h>
#include <dcomp.h>

#define VK_USE_PLATFORM_WIN32_KHR
#include <vulkan/vulkan.h>

#include <vector>
#include <fstream>
#include <string>
#include <cstdio>
#include <cstdarg>
#include <cstring>
#include <stdexcept>

#pragma comment(lib, "d3d11.lib")
#pragma comment(lib, "dxgi.lib")
#pragma comment(lib, "dcomp.lib")
#pragma comment(lib, "user32.lib")

// ============================================================
// Debug output helper
// ============================================================
static void dbg(const char* fmt, ...) {
    char buf[1024];
    va_list args;
    va_start(args, fmt);
    vsnprintf(buf, sizeof(buf), fmt, args);
    va_end(args);
    OutputDebugStringA(buf);
}

// ============================================================
// Constants
// ============================================================
static const uint32_t WIDTH  = 800;
static const uint32_t HEIGHT = 600;

// ============================================================
// Helper: safe release
// ============================================================
template <typename T>
void SafeRelease(T** pp) { if (*pp) { (*pp)->Release(); *pp = nullptr; } }

// ============================================================
// Read SPIR-V file
// ============================================================
static std::vector<char> readFile(const std::string& filename) {
    std::ifstream file(filename, std::ios::ate | std::ios::binary);
    if (!file.is_open())
        throw std::runtime_error("failed to open file: " + filename);
    size_t fileSize = (size_t)file.tellg();
    std::vector<char> buffer(fileSize);
    file.seekg(0);
    file.read(buffer.data(), fileSize);
    return buffer;
}

// ============================================================
// Application class (same pattern as hello.cpp)
// ============================================================
class HelloTriangleApplication {
public:
    void run() {
        initWindow();
        initD3D11();
        initDirectComposition();
        initVulkan();
        mainLoop();
        cleanup();
    }

private:
    // Win32
    HWND hwnd = nullptr;

    // D3D11
    ID3D11Device*           d3dDevice     = nullptr;
    ID3D11DeviceContext*    d3dContext    = nullptr;
    IDXGISwapChain1*        swapChain     = nullptr;
    ID3D11Texture2D*        backBuffer    = nullptr;
    ID3D11Texture2D*        stagingTex    = nullptr;

    // DirectComposition
    IDCompositionDevice*    dcompDevice   = nullptr;
    IDCompositionTarget*    dcompTarget   = nullptr;
    IDCompositionVisual*    dcompVisual   = nullptr;

    // Vulkan
    VkInstance       vkInst           = VK_NULL_HANDLE;
    VkPhysicalDevice vkPhysDev        = VK_NULL_HANDLE;
    VkDevice         vkDev            = VK_NULL_HANDLE;
    VkQueue          graphicsQueue    = VK_NULL_HANDLE;
    uint32_t         graphicsFamily   = 0;

    // Vulkan offscreen rendering
    VkImage          offscreenImage   = VK_NULL_HANDLE;
    VkDeviceMemory   offscreenMemory  = VK_NULL_HANDLE;
    VkImageView      offscreenView    = VK_NULL_HANDLE;
    VkRenderPass     renderPass       = VK_NULL_HANDLE;
    VkFramebuffer    framebuffer      = VK_NULL_HANDLE;

    // Vulkan staging buffer (for GPU -> CPU readback)
    VkBuffer         stagingBuffer    = VK_NULL_HANDLE;
    VkDeviceMemory   stagingMemory    = VK_NULL_HANDLE;

    // Vulkan pipeline
    VkPipelineLayout pipelineLayout   = VK_NULL_HANDLE;
    VkPipeline       graphicsPipeline = VK_NULL_HANDLE;

    // Vulkan command
    VkCommandPool    commandPool      = VK_NULL_HANDLE;
    VkCommandBuffer  commandBuffer    = VK_NULL_HANDLE;
    VkFence          renderFence      = VK_NULL_HANDLE;

    // ========================================================
    // Win32 window
    // ========================================================
    static LRESULT CALLBACK WndProc(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam) {
        if (msg == WM_DESTROY || (msg == WM_KEYDOWN && wParam == VK_ESCAPE)) {
            PostQuitMessage(0);
            return 0;
        }
        return DefWindowProcW(hWnd, msg, wParam, lParam);
    }

    void initWindow() {
        dbg("[initWindow] begin\n");
        WNDCLASSEXW wc = {};
        wc.cbSize        = sizeof(wc);
        wc.style         = CS_HREDRAW | CS_VREDRAW;
        wc.lpfnWndProc   = WndProc;
        wc.hInstance      = GetModuleHandle(nullptr);
        wc.hCursor        = LoadCursor(nullptr, IDC_ARROW);
        wc.lpszClassName  = L"DCompVkTriangleClass";
        RegisterClassExW(&wc);

        RECT rc = { 0, 0, (LONG)WIDTH, (LONG)HEIGHT };
        AdjustWindowRect(&rc, WS_OVERLAPPEDWINDOW, FALSE);
        hwnd = CreateWindowExW(0, wc.lpszClassName,
            L"Vulkan Triangle (DirectComposition)",
            WS_OVERLAPPEDWINDOW, CW_USEDEFAULT, CW_USEDEFAULT,
            rc.right - rc.left, rc.bottom - rc.top,
            nullptr, nullptr, wc.hInstance, nullptr);
        ShowWindow(hwnd, SW_SHOW);
        dbg("[initWindow] HWND=%p\n", hwnd);
    }

    // ========================================================
    // D3D11 - device + SwapChainForComposition + staging texture
    // ========================================================
    void initD3D11() {
        dbg("[initD3D11] begin\n");
        HRESULT hr;

        // Create D3D11 device
        D3D_FEATURE_LEVEL level = D3D_FEATURE_LEVEL_11_0;
        hr = D3D11CreateDevice(nullptr, D3D_DRIVER_TYPE_HARDWARE, nullptr,
            D3D11_CREATE_DEVICE_BGRA_SUPPORT, &level, 1, D3D11_SDK_VERSION,
            &d3dDevice, nullptr, &d3dContext);
        if (FAILED(hr)) throw std::runtime_error("D3D11CreateDevice failed");
        dbg("[initD3D11] Device=%p\n", d3dDevice);

        // Get DXGI Factory2
        IDXGIDevice* dxgiDev = nullptr;
        d3dDevice->QueryInterface(__uuidof(IDXGIDevice), (void**)&dxgiDev);
        IDXGIAdapter* adapter = nullptr;
        dxgiDev->GetAdapter(&adapter);
        IDXGIFactory2* factory = nullptr;
        adapter->GetParent(__uuidof(IDXGIFactory2), (void**)&factory);
        adapter->Release();

        // Create SwapChain FOR COMPOSITION
        DXGI_SWAP_CHAIN_DESC1 scd = {};
        scd.Width       = WIDTH;
        scd.Height      = HEIGHT;
        scd.Format      = DXGI_FORMAT_B8G8R8A8_UNORM;
        scd.SampleDesc  = { 1, 0 };
        scd.BufferUsage = DXGI_USAGE_RENDER_TARGET_OUTPUT;
        scd.BufferCount = 2;
        scd.SwapEffect  = DXGI_SWAP_EFFECT_FLIP_SEQUENTIAL;
        scd.AlphaMode   = DXGI_ALPHA_MODE_PREMULTIPLIED;

        hr = factory->CreateSwapChainForComposition(d3dDevice, &scd, nullptr, &swapChain);
        factory->Release();
        dxgiDev->Release();
        if (FAILED(hr)) throw std::runtime_error("CreateSwapChainForComposition failed");
        dbg("[initD3D11] SwapChain=%p\n", swapChain);

        // Get back buffer
        swapChain->GetBuffer(0, __uuidof(ID3D11Texture2D), (void**)&backBuffer);
        dbg("[initD3D11] BackBuffer=%p\n", backBuffer);

        // Create D3D11 staging texture (CPU writable)
        // Vulkan pixel data will be copied here, then CopyResource to back buffer
        D3D11_TEXTURE2D_DESC td = {};
        td.Width      = WIDTH;
        td.Height     = HEIGHT;
        td.MipLevels  = 1;
        td.ArraySize  = 1;
        td.Format     = DXGI_FORMAT_B8G8R8A8_UNORM;
        td.SampleDesc = { 1, 0 };
        td.Usage      = D3D11_USAGE_STAGING;
        td.CPUAccessFlags = D3D11_CPU_ACCESS_WRITE;
        hr = d3dDevice->CreateTexture2D(&td, nullptr, &stagingTex);
        if (FAILED(hr)) throw std::runtime_error("CreateTexture2D staging failed");
        dbg("[initD3D11] StagingTex=%p\n", stagingTex);

        dbg("[initD3D11] ok\n");
    }

    // ========================================================
    // DirectComposition
    // ========================================================
    void initDirectComposition() {
        dbg("[initDComp] begin\n");
        HRESULT hr;

        IDXGIDevice* dxgiDev = nullptr;
        d3dDevice->QueryInterface(__uuidof(IDXGIDevice), (void**)&dxgiDev);
        hr = DCompositionCreateDevice(dxgiDev, __uuidof(IDCompositionDevice), (void**)&dcompDevice);
        dxgiDev->Release();
        if (FAILED(hr)) throw std::runtime_error("DCompositionCreateDevice failed");

        dcompDevice->CreateTargetForHwnd(hwnd, TRUE, &dcompTarget);
        dcompDevice->CreateVisual(&dcompVisual);
        dcompVisual->SetContent(swapChain);
        dcompTarget->SetRoot(dcompVisual);
        dcompDevice->Commit();

        dbg("[initDComp] ok\n");
    }

    // ========================================================
    // Vulkan initialization
    // ========================================================
    void initVulkan() {
        createInstance();
        pickPhysicalDevice();
        createLogicalDevice();
        createOffscreenResources();
        createRenderPass();
        createFramebuffer();
        createGraphicsPipeline();
        createCommandResources();
        dbg("[initVulkan] all done\n");
    }

    void createInstance() {
        dbg("[createInstance] begin\n");
        VkApplicationInfo appInfo = {};
        appInfo.sType              = VK_STRUCTURE_TYPE_APPLICATION_INFO;
        appInfo.pApplicationName   = "Hello, World!";
        appInfo.applicationVersion = VK_MAKE_VERSION(1, 0, 0);
        appInfo.pEngineName        = "No Engine";
        appInfo.engineVersion      = VK_MAKE_VERSION(1, 0, 0);
        appInfo.apiVersion         = VK_API_VERSION_1_0;

        // No surface extensions needed - we render offscreen
        std::vector<const char*> extensions;
#ifndef NDEBUG
        extensions.push_back(VK_EXT_DEBUG_UTILS_EXTENSION_NAME);
#endif

        std::vector<const char*> layers;
#ifndef NDEBUG
        layers.push_back("VK_LAYER_KHRONOS_validation");
#endif

        VkInstanceCreateInfo ci = {};
        ci.sType                   = VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO;
        ci.pApplicationInfo        = &appInfo;
        ci.enabledExtensionCount   = (uint32_t)extensions.size();
        ci.ppEnabledExtensionNames = extensions.data();
        ci.enabledLayerCount       = (uint32_t)layers.size();
        ci.ppEnabledLayerNames     = layers.data();

        if (vkCreateInstance(&ci, nullptr, &vkInst) != VK_SUCCESS)
            throw std::runtime_error("failed to create Vulkan instance");
        dbg("[createInstance] ok\n");
    }

    void pickPhysicalDevice() {
        uint32_t count = 0;
        vkEnumeratePhysicalDevices(vkInst, &count, nullptr);
        if (count == 0) throw std::runtime_error("no Vulkan GPUs found");

        std::vector<VkPhysicalDevice> devs(count);
        vkEnumeratePhysicalDevices(vkInst, &count, devs.data());

        for (auto& d : devs) {
            uint32_t qfCount = 0;
            vkGetPhysicalDeviceQueueFamilyProperties(d, &qfCount, nullptr);
            std::vector<VkQueueFamilyProperties> qfProps(qfCount);
            vkGetPhysicalDeviceQueueFamilyProperties(d, &qfCount, qfProps.data());

            for (uint32_t i = 0; i < qfCount; i++) {
                if (qfProps[i].queueFlags & VK_QUEUE_GRAPHICS_BIT) {
                    vkPhysDev = d;
                    graphicsFamily = i;
                    break;
                }
            }
            if (vkPhysDev != VK_NULL_HANDLE) break;
        }
        if (vkPhysDev == VK_NULL_HANDLE)
            throw std::runtime_error("no suitable Vulkan GPU found");

        VkPhysicalDeviceProperties props;
        vkGetPhysicalDeviceProperties(vkPhysDev, &props);
        dbg("[pickPhysicalDevice] %s, graphicsFamily=%u\n", props.deviceName, graphicsFamily);
    }

    void createLogicalDevice() {
        float priority = 1.0f;
        VkDeviceQueueCreateInfo qci = {};
        qci.sType            = VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO;
        qci.queueFamilyIndex = graphicsFamily;
        qci.queueCount       = 1;
        qci.pQueuePriorities = &priority;

        // No swapchain extension needed - we render offscreen
        VkPhysicalDeviceFeatures features = {};

        VkDeviceCreateInfo dci = {};
        dci.sType                = VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO;
        dci.queueCreateInfoCount = 1;
        dci.pQueueCreateInfos    = &qci;
        dci.pEnabledFeatures     = &features;

        if (vkCreateDevice(vkPhysDev, &dci, nullptr, &vkDev) != VK_SUCCESS)
            throw std::runtime_error("failed to create Vulkan device");
        vkGetDeviceQueue(vkDev, graphicsFamily, 0, &graphicsQueue);
        dbg("[createLogicalDevice] ok\n");
    }

    // ========================================================
    // Vulkan offscreen image + staging buffer
    // ========================================================
    uint32_t findMemoryType(uint32_t typeFilter, VkMemoryPropertyFlags props) {
        VkPhysicalDeviceMemoryProperties memProps;
        vkGetPhysicalDeviceMemoryProperties(vkPhysDev, &memProps);
        for (uint32_t i = 0; i < memProps.memoryTypeCount; i++) {
            if ((typeFilter & (1 << i)) &&
                (memProps.memoryTypes[i].propertyFlags & props) == props)
                return i;
        }
        throw std::runtime_error("failed to find suitable memory type");
    }

    void createOffscreenResources() {
        dbg("[createOffscreen] begin\n");

        // Create offscreen image (Vulkan render target)
        // Format: B8G8R8A8_UNORM to match D3D11 swap chain
        VkImageCreateInfo ici = {};
        ici.sType         = VK_STRUCTURE_TYPE_IMAGE_CREATE_INFO;
        ici.imageType     = VK_IMAGE_TYPE_2D;
        ici.format        = VK_FORMAT_B8G8R8A8_UNORM;
        ici.extent        = { WIDTH, HEIGHT, 1 };
        ici.mipLevels     = 1;
        ici.arrayLayers   = 1;
        ici.samples       = VK_SAMPLE_COUNT_1_BIT;
        ici.tiling        = VK_IMAGE_TILING_OPTIMAL;
        ici.usage         = VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT | VK_IMAGE_USAGE_TRANSFER_SRC_BIT;
        ici.initialLayout = VK_IMAGE_LAYOUT_UNDEFINED;

        if (vkCreateImage(vkDev, &ici, nullptr, &offscreenImage) != VK_SUCCESS)
            throw std::runtime_error("failed to create offscreen image");

        VkMemoryRequirements memReq;
        vkGetImageMemoryRequirements(vkDev, offscreenImage, &memReq);

        VkMemoryAllocateInfo mai = {};
        mai.sType           = VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO;
        mai.allocationSize  = memReq.size;
        mai.memoryTypeIndex = findMemoryType(memReq.memoryTypeBits,
                                              VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT);

        vkAllocateMemory(vkDev, &mai, nullptr, &offscreenMemory);
        vkBindImageMemory(vkDev, offscreenImage, offscreenMemory, 0);

        // Image view
        VkImageViewCreateInfo ivci = {};
        ivci.sType    = VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO;
        ivci.image    = offscreenImage;
        ivci.viewType = VK_IMAGE_VIEW_TYPE_2D;
        ivci.format   = VK_FORMAT_B8G8R8A8_UNORM;
        ivci.subresourceRange.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT;
        ivci.subresourceRange.levelCount = 1;
        ivci.subresourceRange.layerCount = 1;

        vkCreateImageView(vkDev, &ivci, nullptr, &offscreenView);

        // Create staging buffer (for GPU -> CPU readback)
        VkDeviceSize bufSize = WIDTH * HEIGHT * 4;

        VkBufferCreateInfo bci = {};
        bci.sType = VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO;
        bci.size  = bufSize;
        bci.usage = VK_BUFFER_USAGE_TRANSFER_DST_BIT;

        vkCreateBuffer(vkDev, &bci, nullptr, &stagingBuffer);

        vkGetBufferMemoryRequirements(vkDev, stagingBuffer, &memReq);

        mai.allocationSize  = memReq.size;
        mai.memoryTypeIndex = findMemoryType(memReq.memoryTypeBits,
            VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | VK_MEMORY_PROPERTY_HOST_COHERENT_BIT);

        vkAllocateMemory(vkDev, &mai, nullptr, &stagingMemory);
        vkBindBufferMemory(vkDev, stagingBuffer, stagingMemory, 0);

        dbg("[createOffscreen] ok\n");
    }

    // ========================================================
    // Vulkan render pass
    // ========================================================
    void createRenderPass() {
        VkAttachmentDescription colorAtt = {};
        colorAtt.format         = VK_FORMAT_B8G8R8A8_UNORM;
        colorAtt.samples        = VK_SAMPLE_COUNT_1_BIT;
        colorAtt.loadOp         = VK_ATTACHMENT_LOAD_OP_CLEAR;
        colorAtt.storeOp        = VK_ATTACHMENT_STORE_OP_STORE;
        colorAtt.stencilLoadOp  = VK_ATTACHMENT_LOAD_OP_DONT_CARE;
        colorAtt.stencilStoreOp = VK_ATTACHMENT_STORE_OP_DONT_CARE;
        colorAtt.initialLayout  = VK_IMAGE_LAYOUT_UNDEFINED;
        colorAtt.finalLayout    = VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL;

        VkAttachmentReference colorRef = {};
        colorRef.attachment = 0;
        colorRef.layout     = VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL;

        VkSubpassDescription subpass = {};
        subpass.pipelineBindPoint    = VK_PIPELINE_BIND_POINT_GRAPHICS;
        subpass.colorAttachmentCount = 1;
        subpass.pColorAttachments    = &colorRef;

        VkSubpassDependency dep = {};
        dep.srcSubpass    = VK_SUBPASS_EXTERNAL;
        dep.dstSubpass    = 0;
        dep.srcStageMask  = VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT;
        dep.srcAccessMask = 0;
        dep.dstStageMask  = VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT;
        dep.dstAccessMask = VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT;

        VkRenderPassCreateInfo rpci = {};
        rpci.sType           = VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO;
        rpci.attachmentCount = 1;
        rpci.pAttachments    = &colorAtt;
        rpci.subpassCount    = 1;
        rpci.pSubpasses      = &subpass;
        rpci.dependencyCount = 1;
        rpci.pDependencies   = &dep;

        if (vkCreateRenderPass(vkDev, &rpci, nullptr, &renderPass) != VK_SUCCESS)
            throw std::runtime_error("failed to create render pass");
        dbg("[createRenderPass] ok\n");
    }

    void createFramebuffer() {
        VkFramebufferCreateInfo fci = {};
        fci.sType           = VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO;
        fci.renderPass      = renderPass;
        fci.attachmentCount = 1;
        fci.pAttachments    = &offscreenView;
        fci.width           = WIDTH;
        fci.height          = HEIGHT;
        fci.layers          = 1;

        if (vkCreateFramebuffer(vkDev, &fci, nullptr, &framebuffer) != VK_SUCCESS)
            throw std::runtime_error("failed to create framebuffer");
        dbg("[createFramebuffer] ok\n");
    }

    // ========================================================
    // Vulkan graphics pipeline (same as hello.cpp)
    // ========================================================
    VkShaderModule createShaderModule(const std::vector<char>& code) {
        VkShaderModuleCreateInfo ci = {};
        ci.sType    = VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO;
        ci.codeSize = code.size();
        ci.pCode    = reinterpret_cast<const uint32_t*>(code.data());

        VkShaderModule mod;
        if (vkCreateShaderModule(vkDev, &ci, nullptr, &mod) != VK_SUCCESS)
            throw std::runtime_error("failed to create shader module");
        return mod;
    }

    void createGraphicsPipeline() {
        dbg("[createGraphicsPipeline] begin\n");

        auto vertCode = readFile("hello_vert.spv");
        auto fragCode = readFile("hello_frag.spv");

        VkShaderModule vertMod = createShaderModule(vertCode);
        VkShaderModule fragMod = createShaderModule(fragCode);

        VkPipelineShaderStageCreateInfo vertStage = {};
        vertStage.sType  = VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO;
        vertStage.stage  = VK_SHADER_STAGE_VERTEX_BIT;
        vertStage.module = vertMod;
        vertStage.pName  = "main";

        VkPipelineShaderStageCreateInfo fragStage = {};
        fragStage.sType  = VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO;
        fragStage.stage  = VK_SHADER_STAGE_FRAGMENT_BIT;
        fragStage.module = fragMod;
        fragStage.pName  = "main";

        VkPipelineShaderStageCreateInfo stages[] = { vertStage, fragStage };

        // Vertex input - hardcoded in shader (gl_VertexIndex), no vertex buffers
        VkPipelineVertexInputStateCreateInfo vertexInput = {};
        vertexInput.sType = VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO;

        VkPipelineInputAssemblyStateCreateInfo inputAsm = {};
        inputAsm.sType    = VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO;
        inputAsm.topology = VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST;

        VkViewport viewport = {};
        viewport.width    = (float)WIDTH;
        viewport.height   = (float)HEIGHT;
        viewport.maxDepth = 1.0f;

        VkRect2D scissor = {};
        scissor.extent = { WIDTH, HEIGHT };

        VkPipelineViewportStateCreateInfo viewportState = {};
        viewportState.sType         = VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO;
        viewportState.viewportCount = 1;
        viewportState.pViewports    = &viewport;
        viewportState.scissorCount  = 1;
        viewportState.pScissors     = &scissor;

        VkPipelineRasterizationStateCreateInfo raster = {};
        raster.sType       = VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO;
        raster.polygonMode = VK_POLYGON_MODE_FILL;
        raster.lineWidth   = 1.0f;
        raster.cullMode    = VK_CULL_MODE_BACK_BIT;
        raster.frontFace   = VK_FRONT_FACE_CLOCKWISE;

        VkPipelineMultisampleStateCreateInfo msaa = {};
        msaa.sType                = VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO;
        msaa.rasterizationSamples = VK_SAMPLE_COUNT_1_BIT;

        VkPipelineColorBlendAttachmentState blendAtt = {};
        blendAtt.colorWriteMask = VK_COLOR_COMPONENT_R_BIT | VK_COLOR_COMPONENT_G_BIT |
                                  VK_COLOR_COMPONENT_B_BIT | VK_COLOR_COMPONENT_A_BIT;

        VkPipelineColorBlendStateCreateInfo blend = {};
        blend.sType           = VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO;
        blend.attachmentCount = 1;
        blend.pAttachments    = &blendAtt;

        VkPipelineLayoutCreateInfo plci = {};
        plci.sType = VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO;
        vkCreatePipelineLayout(vkDev, &plci, nullptr, &pipelineLayout);

        VkGraphicsPipelineCreateInfo pci = {};
        pci.sType               = VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO;
        pci.stageCount          = 2;
        pci.pStages             = stages;
        pci.pVertexInputState   = &vertexInput;
        pci.pInputAssemblyState = &inputAsm;
        pci.pViewportState      = &viewportState;
        pci.pRasterizationState = &raster;
        pci.pMultisampleState   = &msaa;
        pci.pColorBlendState    = &blend;
        pci.layout              = pipelineLayout;
        pci.renderPass          = renderPass;

        if (vkCreateGraphicsPipelines(vkDev, VK_NULL_HANDLE, 1, &pci, nullptr, &graphicsPipeline) != VK_SUCCESS)
            throw std::runtime_error("failed to create graphics pipeline");

        vkDestroyShaderModule(vkDev, fragMod, nullptr);
        vkDestroyShaderModule(vkDev, vertMod, nullptr);

        dbg("[createGraphicsPipeline] ok\n");
    }

    // ========================================================
    // Vulkan command pool / buffer / fence
    // ========================================================
    void createCommandResources() {
        VkCommandPoolCreateInfo cpci = {};
        cpci.sType            = VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO;
        cpci.flags            = VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT;
        cpci.queueFamilyIndex = graphicsFamily;
        vkCreateCommandPool(vkDev, &cpci, nullptr, &commandPool);

        VkCommandBufferAllocateInfo cbai = {};
        cbai.sType              = VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO;
        cbai.commandPool        = commandPool;
        cbai.level              = VK_COMMAND_BUFFER_LEVEL_PRIMARY;
        cbai.commandBufferCount = 1;
        vkAllocateCommandBuffers(vkDev, &cbai, &commandBuffer);

        VkFenceCreateInfo fci = {};
        fci.sType = VK_STRUCTURE_TYPE_FENCE_CREATE_INFO;
        fci.flags = VK_FENCE_CREATE_SIGNALED_BIT;
        vkCreateFence(vkDev, &fci, nullptr, &renderFence);

        dbg("[createCommandResources] ok\n");
    }

    // ========================================================
    // Record command buffer: render triangle + copy to staging
    // ========================================================
    void recordCommandBuffer() {
        vkResetCommandBuffer(commandBuffer, 0);

        VkCommandBufferBeginInfo bi = {};
        bi.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO;
        vkBeginCommandBuffer(commandBuffer, &bi);

        // Begin render pass
        VkRenderPassBeginInfo rpbi = {};
        rpbi.sType             = VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO;
        rpbi.renderPass        = renderPass;
        rpbi.framebuffer       = framebuffer;
        rpbi.renderArea.extent = { WIDTH, HEIGHT };

        VkClearValue clearColor = {};
        clearColor.color = { { 0.0f, 0.0f, 0.0f, 1.0f } };
        rpbi.clearValueCount = 1;
        rpbi.pClearValues    = &clearColor;

        vkCmdBeginRenderPass(commandBuffer, &rpbi, VK_SUBPASS_CONTENTS_INLINE);
        vkCmdBindPipeline(commandBuffer, VK_PIPELINE_BIND_POINT_GRAPHICS, graphicsPipeline);
        vkCmdDraw(commandBuffer, 3, 1, 0, 0);
        vkCmdEndRenderPass(commandBuffer);

        // Render pass finalLayout is TRANSFER_SRC_OPTIMAL, so the image is
        // already in the right layout for copying.

        // Copy offscreen image to staging buffer
        VkBufferImageCopy region = {};
        region.bufferRowLength   = WIDTH;
        region.bufferImageHeight = HEIGHT;
        region.imageSubresource.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT;
        region.imageSubresource.layerCount = 1;
        region.imageExtent = { WIDTH, HEIGHT, 1 };

        vkCmdCopyImageToBuffer(commandBuffer, offscreenImage,
            VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL,
            stagingBuffer, 1, &region);

        vkEndCommandBuffer(commandBuffer);
    }

    // ========================================================
    // Draw frame: Vulkan render -> copy to D3D11 -> Present
    // ========================================================
    bool firstFrame = true;

    void drawFrame() {
        // Wait for previous frame
        vkWaitForFences(vkDev, 1, &renderFence, VK_TRUE, UINT64_MAX);
        vkResetFences(vkDev, 1, &renderFence);

        // Record and submit Vulkan commands
        recordCommandBuffer();

        VkSubmitInfo si = {};
        si.sType              = VK_STRUCTURE_TYPE_SUBMIT_INFO;
        si.commandBufferCount = 1;
        si.pCommandBuffers    = &commandBuffer;

        vkQueueSubmit(graphicsQueue, 1, &si, renderFence);
        vkWaitForFences(vkDev, 1, &renderFence, VK_TRUE, UINT64_MAX);

        // Map Vulkan staging buffer
        void* vkData = nullptr;
        vkMapMemory(vkDev, stagingMemory, 0, WIDTH * HEIGHT * 4, 0, &vkData);

        // Map D3D11 staging texture and copy pixel data
        D3D11_MAPPED_SUBRESOURCE mapped = {};
        HRESULT hr = d3dContext->Map(stagingTex, 0, D3D11_MAP_WRITE, 0, &mapped);
        if (SUCCEEDED(hr)) {
            // Copy row by row (D3D11 row pitch may differ from Vulkan)
            const uint8_t* src = (const uint8_t*)vkData;
            uint8_t* dst = (uint8_t*)mapped.pData;
            uint32_t srcPitch = WIDTH * 4;
            for (uint32_t y = 0; y < HEIGHT; y++) {
                memcpy(dst + y * mapped.RowPitch, src + y * srcPitch, srcPitch);
            }
            d3dContext->Unmap(stagingTex, 0);
        }

        vkUnmapMemory(vkDev, stagingMemory);

        // Copy staging -> back buffer, then present
        d3dContext->CopyResource(backBuffer, stagingTex);
        hr = swapChain->Present(1, 0);

        if (firstFrame) {
            dbg("[drawFrame] first frame Present hr=0x%08X\n", hr);
            firstFrame = false;
        }
    }

    // ========================================================
    // Message loop
    // ========================================================
    void mainLoop() {
        dbg("[mainLoop] entering\n");
        MSG msg = {};
        while (msg.message != WM_QUIT) {
            if (PeekMessageW(&msg, nullptr, 0, 0, PM_REMOVE)) {
                TranslateMessage(&msg);
                DispatchMessageW(&msg);
            } else {
                drawFrame();
                Sleep(1);
            }
        }
        vkDeviceWaitIdle(vkDev);
    }

    // ========================================================
    // Cleanup
    // ========================================================
    void cleanup() {
        dbg("[cleanup] begin\n");

        // Vulkan
        if (vkDev) {
            vkDestroyFence(vkDev, renderFence, nullptr);
            vkDestroyCommandPool(vkDev, commandPool, nullptr);
            vkDestroyPipeline(vkDev, graphicsPipeline, nullptr);
            vkDestroyPipelineLayout(vkDev, pipelineLayout, nullptr);
            vkDestroyFramebuffer(vkDev, framebuffer, nullptr);
            vkDestroyRenderPass(vkDev, renderPass, nullptr);
            vkDestroyImageView(vkDev, offscreenView, nullptr);
            vkDestroyImage(vkDev, offscreenImage, nullptr);
            vkFreeMemory(vkDev, offscreenMemory, nullptr);
            vkDestroyBuffer(vkDev, stagingBuffer, nullptr);
            vkFreeMemory(vkDev, stagingMemory, nullptr);
            vkDestroyDevice(vkDev, nullptr);
        }
        if (vkInst) vkDestroyInstance(vkInst, nullptr);

        // DirectComposition
        SafeRelease(&dcompVisual);
        SafeRelease(&dcompTarget);
        SafeRelease(&dcompDevice);

        // D3D11
        SafeRelease(&stagingTex);
        SafeRelease(&backBuffer);
        SafeRelease(&swapChain);
        SafeRelease(&d3dContext);
        SafeRelease(&d3dDevice);

        if (hwnd) DestroyWindow(hwnd);

        dbg("[cleanup] all resources released\n");
    }
};

// ============================================================
// Entry point
// ============================================================
int WINAPI wWinMain(HINSTANCE, HINSTANCE, LPWSTR, int) {
    dbg("========================================\n");
    dbg("Vulkan Triangle via DirectComposition\n");
    dbg("Offscreen render + D3D11 staging + DComp\n");
    dbg("========================================\n");

    HelloTriangleApplication app;
    try {
        app.run();
    } catch (const std::exception& e) {
        dbg("[FATAL] %s\n", e.what());
        MessageBoxA(nullptr, e.what(), "Error", MB_OK | MB_ICONERROR);
        return EXIT_FAILURE;
    }
    return EXIT_SUCCESS;
}
