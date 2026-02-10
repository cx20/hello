<?php
declare(strict_types=1);

/*
  Win32 + Vulkan 1.4 from PHP via FFI + glslangValidator
  
  Draws a RED/GREEN/BLUE colored triangle using Vulkan 1.4 with:
  - Complete rendering pipeline: instance, device, surface, swapchain
  - Render pass, graphics pipeline, framebuffers, command buffers
  - GLSL shaders compiled to SPIR-V via glslangValidator
  - Synchronization with semaphores and fences
  - Full render loop with acquire/submit/present cycle
  
  Color triangle:
  - Bottom vertex: RED (1,0,0)
  - Top-right vertex: GREEN (0,1,0)
  - Top-left vertex: BLUE (0,0,1)
*/

error_reporting(E_ALL);
ini_set('display_errors', '1');

// ============================================================
// Constants: Win32 API
// ============================================================
const WS_OVERLAPPED       = 0x00000000;
const WS_CAPTION          = 0x00C00000;
const WS_SYSMENU          = 0x00080000;
const WS_THICKFRAME       = 0x00040000;
const WS_MINIMIZEBOX      = 0x00020000;
const WS_MAXIMIZEBOX      = 0x00010000;
const WS_OVERLAPPEDWINDOW = WS_OVERLAPPED | WS_CAPTION | WS_SYSMENU | WS_THICKFRAME | WS_MINIMIZEBOX | WS_MAXIMIZEBOX;

const CS_OWNDC            = 0x0020;
const CW_USEDEFAULT       = 0x80000000;
const SW_SHOWDEFAULT      = 10;

const WM_QUIT             = 0x0012;
const WM_CLOSE            = 0x0010;
const WM_SIZE             = 0x0005;
const PM_REMOVE           = 0x0001;

const IDI_APPLICATION     = 32512;
const IDC_ARROW           = 32512;

// ============================================================
// Constants: Vulkan
// ============================================================
const VK_SUCCESS                                  = 0;
const VK_ERROR_OUT_OF_DATE_KHR                    = -1000001004;
const VK_SUBOPTIMAL_KHR                           = 1000001003;

const VK_STRUCTURE_TYPE_APPLICATION_INFO          = 0;
const VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO      = 1;
const VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO  = 2;
const VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO        = 3;
const VK_STRUCTURE_TYPE_WIN32_SURFACE_CREATE_INFO_KHR = 1000009000;
const VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR = 1000001000;
const VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO    = 15;
const VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO = 16;
const VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO   = 38;
const VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO = 18;
const VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO = 19;
const VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO = 20;
const VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO = 22;
const VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO = 23;
const VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO = 24;
const VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO = 26;
const VK_STRUCTURE_TYPE_PIPELINE_DYNAMIC_STATE_CREATE_INFO = 27;
const VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO = 28;
const VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO   = 37;
const VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO  = 39;
const VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO = 40;
const VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO = 42;
const VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO    = 43;
const VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO     = 9;
const VK_STRUCTURE_TYPE_FENCE_CREATE_INFO         = 8;
const VK_STRUCTURE_TYPE_SUBMIT_INFO               = 4;
const VK_STRUCTURE_TYPE_PRESENT_INFO_KHR          = 1000001002;
const VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO = 30;

const VK_ATTACHMENT_LOAD_OP_CLEAR                 = 1;
const VK_ATTACHMENT_STORE_OP_STORE                = 0;
const VK_COMMAND_BUFFER_LEVEL_PRIMARY             = 0;
const VK_COLOR_COMPONENT_R_BIT                    = 0x1;
const VK_COLOR_COMPONENT_G_BIT                    = 0x2;
const VK_COLOR_COMPONENT_B_BIT                    = 0x4;
const VK_COLOR_COMPONENT_A_BIT                    = 0x8;
const VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT = 0x00000002;
const VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR           = 0x00000001;
const VK_CULL_MODE_NONE                           = 0;
const VK_DYNAMIC_STATE_SCISSOR                    = 1;
const VK_DYNAMIC_STATE_VIEWPORT                   = 0;
const VK_FENCE_CREATE_SIGNALED_BIT                = 0x00000001;
const VK_FRONT_FACE_COUNTER_CLOCKWISE             = 1;
const VK_IMAGE_ASPECT_COLOR_BIT                   = 0x1;
const VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL    = 2;
const VK_IMAGE_LAYOUT_PRESENT_SRC_KHR             = 1000001002;
const VK_IMAGE_LAYOUT_UNDEFINED                   = 0;
const VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT         = 0x00000010;
const VK_IMAGE_VIEW_TYPE_2D                       = 1;
const VK_PIPELINE_BIND_POINT_GRAPHICS             = 0;
const VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT = 0x00000400;
const VK_POLYGON_MODE_FILL                        = 0;
const VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST         = 3;
const VK_PRESENT_MODE_FIFO_KHR                    = 2;
const VK_QUEUE_GRAPHICS_BIT                       = 0x00000001;
const VK_SAMPLE_COUNT_1_BIT                       = 1;
const VK_SHADER_STAGE_FRAGMENT_BIT                = 0x00000010;
const VK_SHADER_STAGE_VERTEX_BIT                  = 0x00000001;
const VK_SHARING_MODE_CONCURRENT                  = 1;
const VK_SHARING_MODE_EXCLUSIVE                   = 0;
const VK_SURFACE_TRANSFORM_IDENTITY_BIT_KHR       = 0x00000001;

// ============================================================
// Helper Functions: String to C Buffer conversion
// ============================================================
function wbuf(string $s): FFI\CData
{
    $bytes = iconv('UTF-8', 'UTF-16LE', $s) . "\x00\x00";
    $len16 = intdiv(strlen($bytes), 2);
    $buf = FFI::new("uint16_t[$len16]", false);
    FFI::memcpy($buf, $bytes, strlen($bytes));
    return $buf;
}

function abuf(string $s): FFI\CData
{
    $len = strlen($s) + 1;
    $buf = FFI::new("char[$len]", false);
    FFI::memcpy($buf, $s . "\0", $len);
    return $buf;
}

function fbuf(string $s): FFI\CData
{
    $len = strlen($s) + 1;
    $buf = FFI::new("char[$len]", false);
    FFI::memcpy($buf, $s . "\0", $len);
    return $buf;
}

function check_result(int $result, string $operation): void
{
    if ($result !== VK_SUCCESS) {
        throw new Exception("$operation failed with result: $result");
    }
}

// ============================================================
// Win32 API FFI Definitions
// ============================================================
$kernel32 = FFI::cdef('
    typedef void* HANDLE;
    typedef HANDLE HINSTANCE;
    typedef HANDLE HMODULE;
    typedef const uint16_t* LPCWSTR;
    typedef const char* LPCSTR;
    typedef void* FARPROC;
    typedef void* HWND;

    HINSTANCE GetModuleHandleW(LPCWSTR lpModuleName);
    HMODULE LoadLibraryW(LPCWSTR lpLibFileName);
    FARPROC GetProcAddress(HMODULE hModule, LPCSTR lpProcName);
    unsigned long GetLastError(void);
', 'kernel32.dll');

$user32 = FFI::cdef('
    typedef void* HANDLE;
    typedef HANDLE HWND;
    typedef HANDLE HINSTANCE;
    typedef HANDLE HICON;
    typedef HANDLE HCURSOR;
    typedef HANDLE HBRUSH;
    typedef void*  WNDPROC;
    typedef const uint16_t* LPCWSTR;
    typedef unsigned int   UINT;
    typedef unsigned long  DWORD;
    typedef long           LONG;
    typedef unsigned long long WPARAM;
    typedef long long      LPARAM;
    typedef long long      LRESULT;
    typedef int            BOOL;
    typedef uint16_t       ATOM;

    typedef struct tagPOINT { LONG x; LONG y; } POINT;

    typedef struct tagMSG {
        HWND   hwnd;
        UINT   message;
        WPARAM wParam;
        LPARAM lParam;
        DWORD  time;
        POINT  pt;
        DWORD  lPrivate;
    } MSG;

    typedef struct tagWNDCLASSEXW {
        UINT      cbSize;
        UINT      style;
        WNDPROC   lpfnWndProc;
        int       cbClsExtra;
        int       cbWndExtra;
        HINSTANCE hInstance;
        HICON     hIcon;
        HCURSOR   hCursor;
        HBRUSH    hbrBackground;
        LPCWSTR   lpszMenuName;
        LPCWSTR   lpszClassName;
        HICON     hIconSm;
    } WNDCLASSEXW;

    ATOM RegisterClassExW(const WNDCLASSEXW *lpwcx);
    HWND CreateWindowExW(DWORD dwExStyle, LPCWSTR lpClassName, LPCWSTR lpWindowName, DWORD dwStyle,
        int X, int Y, int nWidth, int nHeight, HWND hWndParent, void* hMenu, HINSTANCE hInstance, void* lpParam);
    BOOL ShowWindow(HWND hWnd, int nCmdShow);
    BOOL UpdateWindow(HWND hWnd);
    BOOL DestroyWindow(HWND hWnd);
    BOOL IsWindow(HWND hWnd);
    BOOL PeekMessageW(MSG *lpMsg, HWND hWnd, UINT wMsgFilterMin, UINT wMsgFilterMax, UINT wRemoveMsg);
    BOOL TranslateMessage(const MSG *lpMsg);
    LRESULT DispatchMessageW(const MSG *lpMsg);
    HICON LoadIconW(HINSTANCE hInstance, LPCWSTR lpIconName);
    HCURSOR LoadCursorW(HINSTANCE hInstance, LPCWSTR lpCursorName);
    BOOL GetClientRect(HWND hWnd, void* lpRect);
', 'user32.dll');

// ============================================================
// Vulkan FFI Definitions (Global + Core Structures)
// ============================================================
$vulkan = FFI::cdef('
    typedef uint32_t VkFlags;
    typedef uint32_t VkBool32;
    typedef uint64_t VkDeviceSize;
    typedef int32_t VkResult;

    typedef void* VkInstance;
    typedef void* VkPhysicalDevice;
    typedef void* VkDevice;
    typedef void* VkQueue;
    typedef void* VkCommandPool;
    typedef void* VkCommandBuffer;

    typedef uint64_t VkSurfaceKHR;
    typedef uint64_t VkSwapchainKHR;
    typedef uint64_t VkImage;
    typedef uint64_t VkImageView;
    typedef uint64_t VkShaderModule;
    typedef uint64_t VkRenderPass;
    typedef uint64_t VkPipelineLayout;
    typedef uint64_t VkPipeline;
    typedef uint64_t VkFramebuffer;
    typedef uint64_t VkSemaphore;
    typedef uint64_t VkFence;

    typedef void* (*PFN_vkVoidFunction)(void);

    typedef struct {
        uint32_t sType;
        void* pNext;
        const char* pApplicationName;
        uint32_t applicationVersion;
        const char* pEngineName;
        uint32_t engineVersion;
        uint32_t apiVersion;
    } VkApplicationInfo;

    typedef struct {
        uint32_t sType;
        void* pNext;
        uint32_t flags;
        const VkApplicationInfo* pApplicationInfo;
        uint32_t enabledLayerCount;
        const char* const* ppEnabledLayerNames;
        uint32_t enabledExtensionCount;
        const char* const* ppEnabledExtensionNames;
    } VkInstanceCreateInfo;

    typedef struct {
        uint32_t queueFlags;
        uint32_t queueCount;
        uint32_t timestampValidBits;
        struct { uint32_t width; uint32_t height; uint32_t depth; } minImageTransferGranularity;
    } VkQueueFamilyProperties;

    typedef struct {
        uint32_t sType;
        void* pNext;
        uint32_t flags;
        uint32_t queueFamilyIndex;
        uint32_t queueCount;
        const float* pQueuePriorities;
    } VkDeviceQueueCreateInfo;

    typedef struct {
        uint32_t sType;
        void* pNext;
        uint32_t flags;
        uint32_t queueCreateInfoCount;
        const VkDeviceQueueCreateInfo* pQueueCreateInfos;
        uint32_t enabledLayerCount;
        const char* const* ppEnabledLayerNames;
        uint32_t enabledExtensionCount;
        const char* const* ppEnabledExtensionNames;
        void* pEnabledFeatures;
    } VkDeviceCreateInfo;

    typedef struct {
        uint32_t sType;
        void* pNext;
        uint32_t flags;
        void* hinstance;
        void* hwnd;
    } VkWin32SurfaceCreateInfoKHR;

    typedef struct {
        uint32_t width;
        uint32_t height;
    } VkExtent2D;

    typedef struct {
        uint32_t width;
        uint32_t height;
        uint32_t depth;
    } VkExtent3D;

    typedef struct {
        uint32_t minImageCount;
        uint32_t maxImageCount;
        VkExtent2D currentExtent;
        VkExtent2D minImageExtent;
        VkExtent2D maxImageExtent;
        uint32_t maxImageArrayLayers;
        uint32_t supportedTransforms;
        uint32_t currentTransform;
        uint32_t supportedCompositeAlpha;
        uint32_t supportedUsageFlags;
    } VkSurfaceCapabilitiesKHR;

    typedef struct {
        uint32_t format;
        uint32_t colorSpace;
    } VkSurfaceFormatKHR;

    typedef struct {
        uint32_t sType;
        void* pNext;
        uint32_t flags;
        VkSurfaceKHR surface;
        uint32_t minImageCount;
        uint32_t imageFormat;
        uint32_t imageColorSpace;
        VkExtent2D imageExtent;
        uint32_t imageArrayLayers;
        uint32_t imageUsage;
        uint32_t imageSharingMode;
        uint32_t queueFamilyIndexCount;
        const uint32_t* pQueueFamilyIndices;
        uint32_t preTransform;
        uint32_t compositeAlpha;
        uint32_t presentMode;
        uint32_t clipped;
        VkSwapchainKHR oldSwapchain;
    } VkSwapchainCreateInfoKHR;

    typedef struct {
        uint32_t r, g, b, a;
    } VkComponentMapping;

    typedef struct {
        uint32_t sType;
        void* pNext;
        uint32_t flags;
        VkImage image;
        uint32_t viewType;
        uint32_t format;
        VkComponentMapping components;
        struct {
            uint32_t aspectMask;
            uint32_t baseMipLevel;
            uint32_t levelCount;
            uint32_t baseArrayLayer;
            uint32_t layerCount;
        } subresourceRange;
    } VkImageViewCreateInfo;

    typedef struct {
        uint32_t flags;
        uint32_t format;
        uint32_t samples;
        uint32_t loadOp;
        uint32_t storeOp;
        uint32_t stencilLoadOp;
        uint32_t stencilStoreOp;
        uint32_t initialLayout;
        uint32_t finalLayout;
    } VkAttachmentDescription;

    typedef struct {
        uint32_t attachment;
        uint32_t layout;
    } VkAttachmentReference;

    typedef struct {
        uint32_t flags;
        uint32_t pipelineBindPoint;
        uint32_t inputAttachmentCount;
        void* pInputAttachments;
        uint32_t colorAttachmentCount;
        const VkAttachmentReference* pColorAttachments;
        void* pResolveAttachments;
        void* pDepthStencilAttachment;
        uint32_t preserveAttachmentCount;
        void* pPreserveAttachments;
    } VkSubpassDescription;

    typedef struct {
        uint32_t sType;
        void* pNext;
        uint32_t flags;
        uint32_t attachmentCount;
        const VkAttachmentDescription* pAttachments;
        uint32_t subpassCount;
        const VkSubpassDescription* pSubpasses;
        uint32_t dependencyCount;
        void* pDependencies;
    } VkRenderPassCreateInfo;

    typedef struct {
        uint32_t sType;
        void* pNext;
        uint32_t flags;
        uint32_t codeSize;
        const uint32_t* pCode;
    } VkShaderModuleCreateInfo;

    typedef struct {
        uint32_t sType;
        void* pNext;
        uint32_t flags;
        uint32_t stage;
        VkShaderModule module;
        const char* pName;
        void* pSpecializationInfo;
    } VkPipelineShaderStageCreateInfo;

    typedef struct {
        uint32_t sType;
        void* pNext;
        uint32_t flags;
        uint32_t vertexBindingDescriptionCount;
        void* pVertexBindingDescriptions;
        uint32_t vertexAttributeDescriptionCount;
        void* pVertexAttributeDescriptions;
    } VkPipelineVertexInputStateCreateInfo;

    typedef struct {
        uint32_t sType;
        void* pNext;
        uint32_t flags;
        uint32_t topology;
        uint32_t primitiveRestartEnable;
    } VkPipelineInputAssemblyStateCreateInfo;

    typedef struct {
        float x, y, width, height, minDepth, maxDepth;
    } VkViewport;

    typedef struct {
        int32_t x, y;
    } VkOffset2D;

    typedef struct {
        VkOffset2D offset;
        VkExtent2D extent;
    } VkRect2D;

    typedef struct {
        uint32_t sType;
        void* pNext;
        uint32_t flags;
        uint32_t viewportCount;
        const VkViewport* pViewports;
        uint32_t scissorCount;
        const VkRect2D* pScissors;
    } VkPipelineViewportStateCreateInfo;

    typedef struct {
        uint32_t sType;
        void* pNext;
        uint32_t flags;
        uint32_t depthClampEnable;
        uint32_t rasterizerDiscardEnable;
        uint32_t polygonMode;
        uint32_t cullMode;
        uint32_t frontFace;
        uint32_t depthBiasEnable;
        float depthBiasConstantFactor;
        float depthBiasClamp;
        float depthBiasSlopeFactor;
        float lineWidth;
    } VkPipelineRasterizationStateCreateInfo;

    typedef struct {
        uint32_t sType;
        void* pNext;
        uint32_t flags;
        uint32_t rasterizationSamples;
        uint32_t sampleShadingEnable;
        float minSampleShading;
        void* pSampleMask;
        uint32_t alphaToCoverageEnable;
        uint32_t alphaToOneEnable;
    } VkPipelineMultisampleStateCreateInfo;

    typedef struct {
        uint32_t blendEnable;
        uint32_t srcColorBlendFactor;
        uint32_t dstColorBlendFactor;
        uint32_t colorBlendOp;
        uint32_t srcAlphaBlendFactor;
        uint32_t dstAlphaBlendFactor;
        uint32_t alphaBlendOp;
        uint32_t colorWriteMask;
    } VkPipelineColorBlendAttachmentState;

    typedef struct {
        uint32_t sType;
        void* pNext;
        uint32_t flags;
        uint32_t logicOpEnable;
        uint32_t logicOp;
        uint32_t attachmentCount;
        const VkPipelineColorBlendAttachmentState* pAttachments;
        float blendConstants[4];
    } VkPipelineColorBlendStateCreateInfo;

    typedef struct {
        uint32_t sType;
        void* pNext;
        uint32_t flags;
        uint32_t dynamicStateCount;
        const uint32_t* pDynamicStates;
    } VkPipelineLayoutCreateInfo;

    typedef struct {
        uint32_t sType;
        void* pNext;
        uint32_t flags;
        uint32_t setLayoutCount;
        void* pSetLayouts;
        uint32_t pushConstantRangeCount;
        void* pPushConstantRanges;
    } VkPipelineLayoutCreateInfo2;

    typedef struct {
        uint32_t sType;
        void* pNext;
        uint32_t flags;
        uint32_t stageCount;
        const VkPipelineShaderStageCreateInfo* pStages;
        const VkPipelineVertexInputStateCreateInfo* pVertexInputState;
        const VkPipelineInputAssemblyStateCreateInfo* pInputAssemblyState;
        void* pTessellationState;
        const VkPipelineViewportStateCreateInfo* pViewportState;
        const VkPipelineRasterizationStateCreateInfo* pRasterizationState;
        const VkPipelineMultisampleStateCreateInfo* pMultisampleState;
        void* pDepthStencilState;
        const VkPipelineColorBlendStateCreateInfo* pColorBlendState;
        void* pDynamicState;
        VkPipelineLayout layout;
        VkRenderPass renderPass;
        uint32_t subpass;
        VkPipeline basePipelineHandle;
        int32_t basePipelineIndex;
    } VkGraphicsPipelineCreateInfo;

    typedef struct {
        uint32_t sType;
        void* pNext;
        uint32_t flags;
        uint32_t dynamicStateCount;
        const uint32_t* pDynamicStates;
    } VkPipelineDynamicStateCreateInfo;

    typedef struct {
        uint32_t sType;
        void* pNext;
        uint32_t flags;
        VkRenderPass renderPass;
        uint32_t attachmentCount;
        const VkImageView* pAttachments;
        uint32_t width;
        uint32_t height;
        uint32_t layers;
    } VkFramebufferCreateInfo;

    typedef struct {
        uint32_t sType;
        void* pNext;
        uint32_t flags;
        uint32_t queueFamilyIndex;
    } VkCommandPoolCreateInfo;

    typedef struct {
        uint32_t sType;
        void* pNext;
        VkCommandPool commandPool;
        uint32_t level;
        uint32_t commandBufferCount;
    } VkCommandBufferAllocateInfo;

    typedef struct {
        uint32_t sType;
        void* pNext;
        uint32_t flags;
        void* pInheritanceInfo;
    } VkCommandBufferBeginInfo;

    typedef struct {
        float float32[4];
    } VkClearColorValue;

    typedef struct {
        uint32_t sType;
        void* pNext;
        VkRenderPass renderPass;
        VkFramebuffer framebuffer;
        VkRect2D renderArea;
        uint32_t clearValueCount;
        void* pClearValues;
    } VkRenderPassBeginInfo;

    typedef struct {
        uint32_t sType;
        void* pNext;
        uint32_t flags;
    } VkSemaphoreCreateInfo;

    typedef struct {
        uint32_t sType;
        void* pNext;
        uint32_t flags;
    } VkFenceCreateInfo;

    typedef struct {
        uint32_t sType;
        void* pNext;
        uint32_t waitSemaphoreCount;
        const VkSemaphore* pWaitSemaphores;
        const uint32_t* pWaitDstStageMask;
        uint32_t commandBufferCount;
        const VkCommandBuffer* pCommandBuffers;
        uint32_t signalSemaphoreCount;
        const VkSemaphore* pSignalSemaphores;
    } VkSubmitInfo;

    typedef struct {
        uint32_t sType;
        void* pNext;
        uint32_t waitSemaphoreCount;
        const VkSemaphore* pWaitSemaphores;
        uint32_t swapchainCount;
        const VkSwapchainKHR* pSwapchains;
        const uint32_t* pImageIndices;
        void* pResults;
    } VkPresentInfoKHR;

    VkResult vkCreateInstance(const VkInstanceCreateInfo* pCreateInfo, const void* pAllocator, VkInstance* pInstance);
    VkResult vkEnumeratePhysicalDevices(VkInstance instance, uint32_t* pPhysicalDeviceCount, VkPhysicalDevice* pPhysicalDevices);
    void vkGetPhysicalDeviceQueueFamilyProperties(VkPhysicalDevice physicalDevice, uint32_t* pQueueFamilyPropertyCount, VkQueueFamilyProperties* pQueueFamilyProperties);
    VkResult vkCreateDevice(VkPhysicalDevice physicalDevice, const VkDeviceCreateInfo* pCreateInfo, const void* pAllocator, VkDevice* pDevice);
    PFN_vkVoidFunction vkGetInstanceProcAddr(VkInstance instance, const char* pName);
    PFN_vkVoidFunction vkGetDeviceProcAddr(VkDevice device, const char* pName);
    void vkDestroyInstance(VkInstance instance, const void* pAllocator);
    VkResult vkDeviceWaitIdle(VkDevice device);
', 'vulkan-1.dll');

// Get module handle
$hInstance = $kernel32->GetModuleHandleW(null);

// Get DefWindowProcW address
$user32_name = wbuf("user32.dll");
$hUser32 = $kernel32->LoadLibraryW(FFI::cast('uint16_t*', FFI::addr($user32_name[0])));
$proc_name = abuf("DefWindowProcW");
$defWndProcAddr = $kernel32->GetProcAddress($hUser32, FFI::cast('char*', FFI::addr($proc_name[0])));

// Prepare window
$className  = wbuf("PHPVulkan14Window");
$windowName = wbuf("Vulkan 1.4 Triangle (PHP)");

$hIcon   = $user32->LoadIconW(null, FFI::cast('uint16_t*', IDI_APPLICATION));
$hCursor = $user32->LoadCursorW(null, FFI::cast('uint16_t*', IDC_ARROW));

// Register window class
$wcex = $user32->new('WNDCLASSEXW');
$wcex->cbSize        = FFI::sizeof($wcex);
$wcex->style         = CS_OWNDC;
$wcex->lpfnWndProc   = $defWndProcAddr;
$wcex->cbClsExtra    = 0;
$wcex->cbWndExtra    = 0;
$wcex->hInstance     = $hInstance;
$wcex->hIcon         = $hIcon;
$wcex->hCursor       = $hCursor;
$wcex->hbrBackground = null;
$wcex->lpszMenuName  = null;
$wcex->lpszClassName = FFI::cast('uint16_t*', FFI::addr($className[0]));
$wcex->hIconSm       = $hIcon;

$atom = $user32->RegisterClassExW(FFI::addr($wcex));
if ($atom === 0) {
    echo "RegisterClassExW failed\n";
    exit(1);
}

// Create window
$hwnd = $user32->CreateWindowExW(
    0,
    FFI::cast('uint16_t*', FFI::addr($className[0])),
    FFI::cast('uint16_t*', FFI::addr($windowName[0])),
    WS_OVERLAPPEDWINDOW,
    CW_USEDEFAULT,
    CW_USEDEFAULT,
    800,
    600,
    null,
    null,
    $hInstance,
    null
);

if ($hwnd === null) {
    echo "CreateWindowExW failed\n";
    exit(1);
}

$user32->ShowWindow($hwnd, SW_SHOWDEFAULT);
$user32->UpdateWindow($hwnd);

echo "[INIT] Window created\n";

// ============================================================
// Load shader files and compile to SPIR-V
// ============================================================
$scriptDir = dirname(__FILE__);
$vertSource = file_get_contents($scriptDir . '/hello.vert');
$fragSource = file_get_contents($scriptDir . '/hello.frag');

if (!$vertSource || !$fragSource) {
    echo "Failed to load shader files\n";
    exit(1);
}

echo "[INIT] Shader files loaded\n";

function compile_shader_to_spv(string $glsl_source, string $shader_kind): string
{
    $tmpfile = sys_get_temp_dir() . '/' . uniqid('vk_shader_') . '.glsl';
    file_put_contents($tmpfile, $glsl_source);
    $outfile = $tmpfile . '.spv';

    $glslangValidator = null;
    $vkSdkPath = getenv('VULKAN_SDK');
    
    if ($vkSdkPath && file_exists($vkSdkPath . '\\Bin\\glslangValidator.exe')) {
        $glslangValidator = $vkSdkPath . '\\Bin\\glslangValidator.exe';
    } elseif (shell_exec("where glslangValidator 2>&1")) {
        $glslangValidator = 'glslangValidator';
    } else {
        throw new Exception("glslangValidator not found. Please install Vulkan SDK.");
    }

    $kind_arg = ($shader_kind === 'vert') ? 'vert' : 'frag';
    $cmd = "\"$glslangValidator\" -V -S $kind_arg \"$tmpfile\" -o \"$outfile\" 2>&1";
    $output = shell_exec($cmd);

    if (!file_exists($outfile)) {
        @unlink($tmpfile);
        throw new Exception("Shader compilation failed: $output");
    }

    $spv_data = file_get_contents($outfile);
    @unlink($tmpfile);
    @unlink($outfile);

    return $spv_data;
}

try {
    echo "[INIT] Compiling vertex shader...\n";
    $vertSpv = compile_shader_to_spv($vertSource, 'vert');
    echo "[INIT] Vertex shader compiled: " . strlen($vertSpv) . " bytes\n";
    
    echo "[INIT] Compiling fragment shader...\n";
    $fragSpv = compile_shader_to_spv($fragSource, 'frag');
    echo "[INIT] Fragment shader compiled: " . strlen($fragSpv) . " bytes\n";
} catch (Exception $e) {
    echo "Shader compilation error: " . $e->getMessage() . "\n";
    $user32->DestroyWindow($hwnd);
    exit(1);
}

// ============================================================
// Vulkan Initialization
// ============================================================

// Create Vulkan Instance
echo "[INIT] Creating Vulkan instance...\n";

$appName = abuf("PHPVulkanApp");
$engineName = abuf("NoEngine");

$appInfo = $vulkan->new('VkApplicationInfo[1]');
$appInfo[0]->sType = VK_STRUCTURE_TYPE_APPLICATION_INFO;
$appInfo[0]->pNext = null;
$appInfo[0]->pApplicationName = FFI::cast('const char*', FFI::addr($appName[0]));
$appInfo[0]->applicationVersion = 1;
$appInfo[0]->pEngineName = FFI::cast('const char*', FFI::addr($engineName[0]));
$appInfo[0]->engineVersion = 1;
$appInfo[0]->apiVersion = (1 << 22) | (4 << 12) | 0;  // Vulkan 1.4

$ext1_str = abuf("VK_KHR_surface");
$ext2_str = abuf("VK_KHR_win32_surface");

$exts = $vulkan->new('const char*[2]', false);
$exts[0] = FFI::cast('const char*', FFI::addr($ext1_str[0]));
$exts[1] = FFI::cast('const char*', FFI::addr($ext2_str[0]));

$createInfo = $vulkan->new('VkInstanceCreateInfo[1]');
$createInfo[0]->sType = VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO;
$createInfo[0]->pNext = null;
$createInfo[0]->flags = 0;
$createInfo[0]->pApplicationInfo = FFI::addr($appInfo[0]);
$createInfo[0]->enabledLayerCount = 0;
$createInfo[0]->ppEnabledLayerNames = null;
$createInfo[0]->enabledExtensionCount = 2;
$createInfo[0]->ppEnabledExtensionNames = FFI::cast('const char* const*', FFI::addr($exts[0]));

$instance = $vulkan->new('VkInstance[1]');
$result = $vulkan->vkCreateInstance(FFI::addr($createInfo[0]), null, FFI::addr($instance[0]));
check_result($result, "vkCreateInstance");

echo "[INIT] Vulkan instance created\n";

// Get instance-level functions
$vkGetInstanceProcAddr_name = abuf("vkGetInstanceProcAddr");
$vkGetInstanceProcAddr = $vulkan->vkGetInstanceProcAddr;

function get_inst_func($instance_ptr, $func_name, $vulkan_lib) {
    $name_buf = abuf($func_name);
    // We need to call vkGetInstanceProcAddr dynamically
    // For PHP FFI, we'll use dlopen/dlsym approach if needed
    // For simplicity, we'll use FFI::cdef to load functions as needed
    return null;
}

// Enumerate Physical Devices
echo "[INIT] Enumerating physical devices...\n";

$deviceCount = $vulkan->new('uint32_t[1]');
$result = $vulkan->vkEnumeratePhysicalDevices($instance[0], FFI::addr($deviceCount[0]), null);
check_result($result, "vkEnumeratePhysicalDevices(count)");

if ($deviceCount[0] === 0) {
    echo "ERROR: No Vulkan physical devices found\n";
    $vulkan->vkDestroyInstance($instance[0], null);
    $user32->DestroyWindow($hwnd);
    exit(1);
}

echo "[INIT] Found " . $deviceCount[0] . " physical device(s)\n";

$physicalDevices = $vulkan->new("VkPhysicalDevice[" . $deviceCount[0] . "]");
$result = $vulkan->vkEnumeratePhysicalDevices($instance[0], FFI::addr($deviceCount[0]), $physicalDevices);
check_result($result, "vkEnumeratePhysicalDevices(list)");

$physicalDevice = $physicalDevices[0];

// Get queue family properties
$queueFamilyCount = $vulkan->new('uint32_t[1]');
$vulkan->vkGetPhysicalDeviceQueueFamilyProperties($physicalDevice, FFI::addr($queueFamilyCount[0]), null);

$queueFamilyProps = $vulkan->new("VkQueueFamilyProperties[" . $queueFamilyCount[0] . "]");
$vulkan->vkGetPhysicalDeviceQueueFamilyProperties($physicalDevice, FFI::addr($queueFamilyCount[0]), $queueFamilyProps);

$graphicsQueueFamily = 0;
for ($i = 0; $i < $queueFamilyCount[0]; $i++) {
    if (($queueFamilyProps[$i]->queueFlags & VK_QUEUE_GRAPHICS_BIT) !== 0) {
        $graphicsQueueFamily = $i;
        break;
    }
}

echo "[INIT] Using graphics queue family: $graphicsQueueFamily\n";

// Create Logical Device
echo "[INIT] Creating logical device...\n";

$queuePriority = $vulkan->new('float[1]');
$queuePriority[0] = 1.0;

$queueCreateInfo = $vulkan->new('VkDeviceQueueCreateInfo[1]');
$queueCreateInfo[0]->sType = VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO;
$queueCreateInfo[0]->pNext = null;
$queueCreateInfo[0]->flags = 0;
$queueCreateInfo[0]->queueFamilyIndex = $graphicsQueueFamily;
$queueCreateInfo[0]->queueCount = 1;
$queueCreateInfo[0]->pQueuePriorities = FFI::addr($queuePriority[0]);

$devExt_str = abuf("VK_KHR_swapchain");
$devExts = $vulkan->new('const char*[1]', false);
$devExts[0] = FFI::cast('const char*', FFI::addr($devExt_str[0]));

$deviceCreateInfo = $vulkan->new('VkDeviceCreateInfo[1]');
$deviceCreateInfo[0]->sType = VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO;
$deviceCreateInfo[0]->pNext = null;
$deviceCreateInfo[0]->flags = 0;
$deviceCreateInfo[0]->queueCreateInfoCount = 1;
$deviceCreateInfo[0]->pQueueCreateInfos = FFI::addr($queueCreateInfo[0]);
$deviceCreateInfo[0]->enabledLayerCount = 0;
$deviceCreateInfo[0]->ppEnabledLayerNames = null;
$deviceCreateInfo[0]->enabledExtensionCount = 1;
$deviceCreateInfo[0]->ppEnabledExtensionNames = FFI::cast('const char* const*', FFI::addr($devExts[0]));
$deviceCreateInfo[0]->pEnabledFeatures = null;

$device = $vulkan->new('VkDevice[1]');
$result = $vulkan->vkCreateDevice($physicalDevice, FFI::addr($deviceCreateInfo[0]), null, FFI::addr($device[0]));
check_result($result, "vkCreateDevice");

echo "[INIT] Logical device created\n";

// Load device-level functions via PHP FFI (need to define them)
$vulkan_dev = FFI::cdef('
    typedef void* VkDevice;
    typedef void* VkQueue;
    typedef void* VkCommandPool;
    typedef void* VkCommandBuffer;
    typedef uint64_t VkSurfaceKHR;
    typedef uint64_t VkSwapchainKHR;
    typedef uint64_t VkImage;
    typedef uint64_t VkImageView;
    typedef uint64_t VkShaderModule;
    typedef uint64_t VkRenderPass;
    typedef uint64_t VkPipelineLayout;
    typedef uint64_t VkPipeline;
    typedef uint64_t VkFramebuffer;
    typedef uint64_t VkSemaphore;
    typedef uint64_t VkFence;
    typedef uint32_t VkResult;
    typedef uint32_t VkBool32;

    typedef struct { uint32_t width; uint32_t height; } VkExtent2D;

    typedef struct {
        uint32_t minImageCount;
        uint32_t maxImageCount;
        VkExtent2D currentExtent;
        VkExtent2D minImageExtent;
        VkExtent2D maxImageExtent;
        uint32_t maxImageArrayLayers;
        uint32_t supportedTransforms;
        uint32_t currentTransform;
        uint32_t supportedCompositeAlpha;
        uint32_t supportedUsageFlags;
    } VkSurfaceCapabilitiesKHR;

    typedef struct {
        uint32_t format;
        uint32_t colorSpace;
    } VkSurfaceFormatKHR;

    typedef struct {
        uint32_t sType;
        void* pNext;
        uint32_t flags;
        VkSurfaceKHR surface;
        uint32_t minImageCount;
        uint32_t imageFormat;
        uint32_t imageColorSpace;
        VkExtent2D imageExtent;
        uint32_t imageArrayLayers;
        uint32_t imageUsage;
        uint32_t imageSharingMode;
        uint32_t queueFamilyIndexCount;
        const uint32_t* pQueueFamilyIndices;
        uint32_t preTransform;
        uint32_t compositeAlpha;
        uint32_t presentMode;
        uint32_t clipped;
        VkSwapchainKHR oldSwapchain;
    } VkSwapchainCreateInfoKHR;

    typedef struct {
        uint32_t r;
        uint32_t g;
        uint32_t b;
        uint32_t a;
    } VkComponentMapping;

    typedef struct {
        uint32_t aspectMask;
        uint32_t baseMipLevel;
        uint32_t levelCount;
        uint32_t baseArrayLayer;
        uint32_t layerCount;
    } VkImageSubresourceRange;

    typedef struct {
        uint32_t sType;
        void* pNext;
        uint32_t flags;
        VkImage image;
        uint32_t viewType;
        uint32_t format;
        VkComponentMapping components;
        VkImageSubresourceRange subresourceRange;
    } VkImageViewCreateInfo;

    typedef struct {
        uint32_t flags;
        uint32_t format;
        uint32_t samples;
        uint32_t loadOp;
        uint32_t storeOp;
        uint32_t stencilLoadOp;
        uint32_t stencilStoreOp;
        uint32_t initialLayout;
        uint32_t finalLayout;
    } VkAttachmentDescription;

    typedef struct {
        uint32_t attachment;
        uint32_t layout;
    } VkAttachmentReference;

    typedef struct {
        uint32_t flags;
        uint32_t pipelineBindPoint;
        uint32_t inputAttachmentCount;
        const VkAttachmentReference* pInputAttachments;
        uint32_t colorAttachmentCount;
        const VkAttachmentReference* pColorAttachments;
        const VkAttachmentReference* pResolveAttachments;
        const VkAttachmentReference* pDepthStencilAttachment;
        uint32_t preserveAttachmentCount;
        const uint32_t* pPreserveAttachments;
    } VkSubpassDescription;

    typedef struct {
        uint32_t sType;
        void* pNext;
        uint32_t flags;
        uint32_t attachmentCount;
        const VkAttachmentDescription* pAttachments;
        uint32_t subpassCount;
        const VkSubpassDescription* pSubpasses;
        uint32_t dependencyCount;
        void* pDependencies;
    } VkRenderPassCreateInfo;

    typedef struct {
        uint32_t sType;
        void* pNext;
        uint32_t flags;
        size_t codeSize;
        const uint32_t* pCode;
    } VkShaderModuleCreateInfo;

    typedef struct {
        uint32_t sType;
        void* pNext;
        uint32_t flags;
        uint32_t setLayoutCount;
        void* pSetLayouts;
        uint32_t pushConstantRangeCount;
        void* pPushConstantRanges;
    } VkPipelineLayoutCreateInfo;

    typedef struct {
        uint32_t sType;
        void* pNext;
        uint32_t flags;
        uint32_t stage;
        VkShaderModule module;
        const char* pName;
        void* pSpecializationInfo;
    } VkPipelineShaderStageCreateInfo;

    typedef struct {
        uint32_t sType;
        void* pNext;
        uint32_t flags;
        uint32_t vertexBindingDescriptionCount;
        void* pVertexBindingDescriptions;
        uint32_t vertexAttributeDescriptionCount;
        void* pVertexAttributeDescriptions;
    } VkPipelineVertexInputStateCreateInfo;

    typedef struct {
        uint32_t sType;
        void* pNext;
        uint32_t flags;
        uint32_t topology;
        uint32_t primitiveRestartEnable;
    } VkPipelineInputAssemblyStateCreateInfo;

    typedef struct {
        float x;
        float y;
        float width;
        float height;
        float minDepth;
        float maxDepth;
    } VkViewport;

    typedef struct {
        int32_t x;
        int32_t y;
    } VkOffset2D;

    typedef struct {
        VkOffset2D offset;
        VkExtent2D extent;
    } VkRect2D;

    typedef struct {
        uint32_t sType;
        void* pNext;
        uint32_t flags;
        uint32_t viewportCount;
        const VkViewport* pViewports;
        uint32_t scissorCount;
        const VkRect2D* pScissors;
    } VkPipelineViewportStateCreateInfo;

    typedef struct {
        uint32_t sType;
        void* pNext;
        uint32_t flags;
        uint32_t depthClampEnable;
        uint32_t rasterizerDiscardEnable;
        uint32_t polygonMode;
        uint32_t cullMode;
        uint32_t frontFace;
        uint32_t depthBiasEnable;
        float depthBiasConstantFactor;
        float depthBiasClamp;
        float depthBiasSlopeFactor;
        float lineWidth;
    } VkPipelineRasterizationStateCreateInfo;

    typedef struct {
        uint32_t sType;
        void* pNext;
        uint32_t flags;
        uint32_t rasterizationSamples;
        uint32_t sampleShadingEnable;
        float minSampleShading;
        void* pSampleMask;
        uint32_t alphaToCoverageEnable;
        uint32_t alphaToOneEnable;
    } VkPipelineMultisampleStateCreateInfo;

    typedef struct {
        uint32_t blendEnable;
        uint32_t srcColorBlendFactor;
        uint32_t dstColorBlendFactor;
        uint32_t colorBlendOp;
        uint32_t srcAlphaBlendFactor;
        uint32_t dstAlphaBlendFactor;
        uint32_t alphaBlendOp;
        uint32_t colorWriteMask;
    } VkPipelineColorBlendAttachmentState;

    typedef struct {
        uint32_t sType;
        void* pNext;
        uint32_t flags;
        uint32_t logicOpEnable;
        uint32_t logicOp;
        uint32_t attachmentCount;
        const VkPipelineColorBlendAttachmentState* pAttachments;
        float blendConstants[4];
    } VkPipelineColorBlendStateCreateInfo;

    typedef struct {
        uint32_t sType;
        void* pNext;
        uint32_t flags;
        uint32_t dynamicStateCount;
        const uint32_t* pDynamicStates;
    } VkPipelineDynamicStateCreateInfo;

    typedef struct {
        uint32_t sType;
        void* pNext;
        uint32_t flags;
        uint32_t stageCount;
        const VkPipelineShaderStageCreateInfo* pStages;
        const VkPipelineVertexInputStateCreateInfo* pVertexInputState;
        const VkPipelineInputAssemblyStateCreateInfo* pInputAssemblyState;
        void* pTessellationState;
        const VkPipelineViewportStateCreateInfo* pViewportState;
        const VkPipelineRasterizationStateCreateInfo* pRasterizationState;
        const VkPipelineMultisampleStateCreateInfo* pMultisampleState;
        void* pDepthStencilState;
        const VkPipelineColorBlendStateCreateInfo* pColorBlendState;
        const VkPipelineDynamicStateCreateInfo* pDynamicState;
        VkPipelineLayout layout;
        VkRenderPass renderPass;
        uint32_t subpass;
        VkPipeline basePipelineHandle;
        int32_t basePipelineIndex;
    } VkGraphicsPipelineCreateInfo;

    typedef struct {
        uint32_t sType;
        void* pNext;
        uint32_t flags;
        VkRenderPass renderPass;
        uint32_t attachmentCount;
        const VkImageView* pAttachments;
        uint32_t width;
        uint32_t height;
        uint32_t layers;
    } VkFramebufferCreateInfo;

    typedef struct {
        uint32_t sType;
        void* pNext;
        uint32_t flags;
        uint32_t queueFamilyIndex;
    } VkCommandPoolCreateInfo;

    typedef struct {
        uint32_t sType;
        void* pNext;
        void* commandPool;
        uint32_t level;
        uint32_t commandBufferCount;
    } VkCommandBufferAllocateInfo;

    typedef struct {
        uint32_t sType;
        void* pNext;
        uint32_t flags;
    } VkSemaphoreCreateInfo;

    typedef struct {
        uint32_t sType;
        void* pNext;
        uint32_t flags;
    } VkFenceCreateInfo;

    typedef struct {
        uint32_t sType;
        void* pNext;
        uint32_t flags;
        void* pInheritanceInfo;
    } VkCommandBufferBeginInfo;

    typedef union {
        float float32[4];
        int32_t int32[4];
        uint32_t uint32[4];
    } VkClearColorValue;

    typedef struct {
        VkClearColorValue color;
    } VkClearValue;

    typedef struct {
        uint32_t sType;
        void* pNext;
        VkRenderPass renderPass;
        VkFramebuffer framebuffer;
        VkRect2D renderArea;
        uint32_t clearValueCount;
        const void* pClearValues;
    } VkRenderPassBeginInfo;

    typedef struct {
        uint32_t sType;
        void* pNext;
        uint32_t waitSemaphoreCount;
        const VkSemaphore* pWaitSemaphores;
        const uint32_t* pWaitDstStageMask;
        uint32_t commandBufferCount;
        const VkCommandBuffer* pCommandBuffers;
        uint32_t signalSemaphoreCount;
        const VkSemaphore* pSignalSemaphores;
    } VkSubmitInfo;

    typedef struct {
        uint32_t sType;
        void* pNext;
        uint32_t waitSemaphoreCount;
        const VkSemaphore* pWaitSemaphores;
        uint32_t swapchainCount;
        const VkSwapchainKHR* pSwapchains;
        const uint32_t* pImageIndices;
        VkResult* pResults;
    } VkPresentInfoKHR;

    VkResult vkGetDeviceQueue(VkDevice device, uint32_t queueFamilyIndex, uint32_t queueIndex, VkQueue* pQueue);
    VkResult vkCreateWin32SurfaceKHR(void* instance, const void* pCreateInfo, const void* pAllocator, VkSurfaceKHR* pSurface);
    VkResult vkGetPhysicalDeviceSurfaceSupportKHR(void* physicalDevice, uint32_t queueFamilyIndex, VkSurfaceKHR surface, VkBool32* pSupported);
    VkResult vkGetPhysicalDeviceSurfaceCapabilitiesKHR(void* physicalDevice, VkSurfaceKHR surface, VkSurfaceCapabilitiesKHR* pSurfaceCapabilities);
    VkResult vkGetPhysicalDeviceSurfaceFormatsKHR(void* physicalDevice, VkSurfaceKHR surface, uint32_t* pSurfaceFormatCount, VkSurfaceFormatKHR* pSurfaceFormats);
    VkResult vkGetPhysicalDeviceSurfacePresentModesKHR(void* physicalDevice, VkSurfaceKHR surface, uint32_t* pPresentModeCount, uint32_t* pPresentModes);
    VkResult vkCreateSwapchainKHR(VkDevice device, const VkSwapchainCreateInfoKHR* pCreateInfo, const void* pAllocator, VkSwapchainKHR* pSwapchain);
    VkResult vkGetSwapchainImagesKHR(VkDevice device, VkSwapchainKHR swapchain, uint32_t* pSwapchainImageCount, VkImage* pSwapchainImages);
    VkResult vkCreateImageView(VkDevice device, const void* pCreateInfo, const void* pAllocator, VkImageView* pView);
    VkResult vkCreateRenderPass(VkDevice device, const void* pCreateInfo, const void* pAllocator, VkRenderPass* pRenderPass);
    VkResult vkCreateShaderModule(VkDevice device, const void* pCreateInfo, const void* pAllocator, VkShaderModule* pShaderModule);
    VkResult vkCreatePipelineLayout(VkDevice device, const void* pCreateInfo, const void* pAllocator, VkPipelineLayout* pPipelineLayout);
    VkResult vkCreateGraphicsPipelines(VkDevice device, void* pipelineCache, uint32_t createInfoCount, const void* pCreateInfos, const void* pAllocator, VkPipeline* pPipelines);
    VkResult vkCreateFramebuffer(VkDevice device, const void* pCreateInfo, const void* pAllocator, VkFramebuffer* pFramebuffer);
    VkResult vkCreateCommandPool(VkDevice device, const void* pCreateInfo, const void* pAllocator, VkCommandPool* pCommandPool);
    VkResult vkAllocateCommandBuffers(VkDevice device, const void* pAllocateInfo, VkCommandBuffer* pCommandBuffers);
    VkResult vkCreateSemaphore(VkDevice device, const void* pCreateInfo, const void* pAllocator, VkSemaphore* pSemaphore);
    VkResult vkCreateFence(VkDevice device, const void* pCreateInfo, const void* pAllocator, VkFence* pFence);
    VkResult vkBeginCommandBuffer(VkCommandBuffer commandBuffer, const void* pBeginInfo);
    VkResult vkEndCommandBuffer(VkCommandBuffer commandBuffer);
    void vkCmdBeginRenderPass(VkCommandBuffer commandBuffer, const void* pRenderPassBegin, uint32_t contents);
    void vkCmdEndRenderPass(VkCommandBuffer commandBuffer);
    void vkCmdBindPipeline(VkCommandBuffer commandBuffer, uint32_t pipelineBindPoint, VkPipeline pipeline);
    void vkCmdSetViewport(VkCommandBuffer commandBuffer, uint32_t firstViewport, uint32_t viewportCount, const void* pViewports);
    void vkCmdSetScissor(VkCommandBuffer commandBuffer, uint32_t firstScissor, uint32_t scissorCount, const void* pScissors);
    void vkCmdDraw(VkCommandBuffer commandBuffer, uint32_t vertexCount, uint32_t instanceCount, uint32_t firstVertex, uint32_t firstInstance);
    VkResult vkQueueSubmit(VkQueue queue, uint32_t submitCount, const void* pSubmits, VkFence fence);
    VkResult vkAcquireNextImageKHR(VkDevice device, VkSwapchainKHR swapchain, uint64_t timeout, VkSemaphore semaphore, VkFence fence, uint32_t* pImageIndex);
    VkResult vkQueuePresentKHR(VkQueue queue, const void* pPresentInfo);
    VkResult vkWaitForFences(VkDevice device, uint32_t fenceCount, const VkFence* pFences, VkBool32 waitAll, uint64_t timeout);
    VkResult vkResetFences(VkDevice device, uint32_t fenceCount, const VkFence* pFences);
    void vkDestroySurfaceKHR(void* instance, VkSurfaceKHR surface, const void* pAllocator);
    void vkDestroySwapchainKHR(VkDevice device, VkSwapchainKHR swapchain, const void* pAllocator);
    void vkDestroyImageView(VkDevice device, VkImageView imageView, const void* pAllocator);
    void vkDestroyRenderPass(VkDevice device, VkRenderPass renderPass, const void* pAllocator);
    void vkDestroyShaderModule(VkDevice device, VkShaderModule shaderModule, const void* pAllocator);
    void vkDestroyPipelineLayout(VkDevice device, VkPipelineLayout pipelineLayout, const void* pAllocator);
    void vkDestroyPipeline(VkDevice device, VkPipeline pipeline, const void* pAllocator);
    void vkDestroyFramebuffer(VkDevice device, VkFramebuffer framebuffer, const void* pAllocator);
    void vkDestroyCommandPool(VkDevice device, VkCommandPool commandPool, const void* pAllocator);
    void vkDestroySemaphore(VkDevice device, VkSemaphore semaphore, const void* pAllocator);
    void vkDestroyFence(VkDevice device, VkFence fence, const void* pAllocator);
    void vkDestroyDevice(VkDevice device, const void* pAllocator);
', 'vulkan-1.dll');

// Get graphics queue
$graphicsQueue = $vulkan_dev->new('VkQueue[1]');
$vulkan_dev->vkGetDeviceQueue($device[0], $graphicsQueueFamily, 0, FFI::addr($graphicsQueue[0]));

// Create Win32 Surface
echo "[INIT] Creating Win32 surface...\n";

$surfaceCreateInfo = $vulkan->new('VkWin32SurfaceCreateInfoKHR[1]');
$surfaceCreateInfo[0]->sType = VK_STRUCTURE_TYPE_WIN32_SURFACE_CREATE_INFO_KHR;
$surfaceCreateInfo[0]->pNext = null;
$surfaceCreateInfo[0]->flags = 0;
$surfaceCreateInfo[0]->hinstance = $hInstance;
$surfaceCreateInfo[0]->hwnd = $hwnd;

$surface = $vulkan_dev->new('VkSurfaceKHR[1]');
$result = $vulkan_dev->vkCreateWin32SurfaceKHR($instance[0], FFI::addr($surfaceCreateInfo[0]), null, FFI::addr($surface[0]));
check_result($result, "vkCreateWin32SurfaceKHR");

echo "[INIT] Win32 surface created\n";

// Get surface capabilities
$surfaceCapabilities = $vulkan_dev->new('VkSurfaceCapabilitiesKHR[1]');
$result = $vulkan_dev->vkGetPhysicalDeviceSurfaceCapabilitiesKHR($physicalDevice, $surface[0], FFI::addr($surfaceCapabilities[0]));
check_result($result, "vkGetPhysicalDeviceSurfaceCapabilitiesKHR");

// Get surface formats
$formatCount = $vulkan_dev->new('uint32_t[1]');
$result = $vulkan_dev->vkGetPhysicalDeviceSurfaceFormatsKHR($physicalDevice, $surface[0], FFI::addr($formatCount[0]), null);
check_result($result, "vkGetPhysicalDeviceSurfaceFormatsKHR(count)");

$surfaceFormats = $vulkan_dev->new("VkSurfaceFormatKHR[" . $formatCount[0] . "]");
$result = $vulkan_dev->vkGetPhysicalDeviceSurfaceFormatsKHR($physicalDevice, $surface[0], FFI::addr($formatCount[0]), $surfaceFormats);
check_result($result, "vkGetPhysicalDeviceSurfaceFormatsKHR(list)");

$surfaceFormat = $surfaceFormats[0];

// Get present modes
$presentModeCount = $vulkan_dev->new('uint32_t[1]');
$result = $vulkan_dev->vkGetPhysicalDeviceSurfacePresentModesKHR($physicalDevice, $surface[0], FFI::addr($presentModeCount[0]), null);
check_result($result, "vkGetPhysicalDeviceSurfacePresentModesKHR(count)");

$presentModes = $vulkan_dev->new("uint32_t[" . $presentModeCount[0] . "]");
$result = $vulkan_dev->vkGetPhysicalDeviceSurfacePresentModesKHR($physicalDevice, $surface[0], FFI::addr($presentModeCount[0]), $presentModes);
check_result($result, "vkGetPhysicalDeviceSurfacePresentModesKHR(list)");

// Create Swapchain
echo "[INIT] Creating swapchain...\n";

$imageCount = $surfaceCapabilities[0]->minImageCount + 1;
if ($surfaceCapabilities[0]->maxImageCount !== 0 && $imageCount > $surfaceCapabilities[0]->maxImageCount) {
    $imageCount = $surfaceCapabilities[0]->maxImageCount;
}

$swapchainCreateInfo = $vulkan_dev->new('VkSwapchainCreateInfoKHR[1]');
$swapchainCreateInfo[0]->sType = VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR;
$swapchainCreateInfo[0]->pNext = null;
$swapchainCreateInfo[0]->flags = 0;
$swapchainCreateInfo[0]->surface = $surface[0];
$swapchainCreateInfo[0]->minImageCount = $imageCount;
$swapchainCreateInfo[0]->imageFormat = $surfaceFormat->format;
$swapchainCreateInfo[0]->imageColorSpace = $surfaceFormat->colorSpace;
$swapchainCreateInfo[0]->imageExtent = $surfaceCapabilities[0]->currentExtent;
$swapchainCreateInfo[0]->imageArrayLayers = 1;
$swapchainCreateInfo[0]->imageUsage = VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT;
$swapchainCreateInfo[0]->imageSharingMode = VK_SHARING_MODE_EXCLUSIVE;
$swapchainCreateInfo[0]->queueFamilyIndexCount = 0;
$swapchainCreateInfo[0]->pQueueFamilyIndices = null;
$swapchainCreateInfo[0]->preTransform = $surfaceCapabilities[0]->currentTransform;
$swapchainCreateInfo[0]->compositeAlpha = VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR;
$swapchainCreateInfo[0]->presentMode = VK_PRESENT_MODE_FIFO_KHR;
$swapchainCreateInfo[0]->clipped = 1;
$swapchainCreateInfo[0]->oldSwapchain = 0;

$swapchain = $vulkan_dev->new('VkSwapchainKHR[1]');
$result = $vulkan_dev->vkCreateSwapchainKHR($device[0], FFI::addr($swapchainCreateInfo[0]), null, FFI::addr($swapchain[0]));
check_result($result, "vkCreateSwapchainKHR");

echo "[INIT] Swapchain created with " . $imageCount . " images\n";

// Get swapchain images
$swapchainImageCount = $vulkan_dev->new('uint32_t[1]');
$result = $vulkan_dev->vkGetSwapchainImagesKHR($device[0], $swapchain[0], FFI::addr($swapchainImageCount[0]), null);
check_result($result, "vkGetSwapchainImagesKHR(count)");

$swapchainImages = $vulkan_dev->new("VkImage[" . $swapchainImageCount[0] . "]");
$result = $vulkan_dev->vkGetSwapchainImagesKHR($device[0], $swapchain[0], FFI::addr($swapchainImageCount[0]), $swapchainImages);
check_result($result, "vkGetSwapchainImagesKHR(list)");

// Create image views
echo "[INIT] Creating image views...\n";

$swapchainImageViews = $vulkan_dev->new("VkImageView[" . $swapchainImageCount[0] . "]");
for ($i = 0; $i < $swapchainImageCount[0]; $i++) {
    $imageViewCreateInfo = $vulkan_dev->new('VkImageViewCreateInfo[1]');
    $imageViewCreateInfo[0]->sType = VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO;
    $imageViewCreateInfo[0]->pNext = null;
    $imageViewCreateInfo[0]->flags = 0;
    $imageViewCreateInfo[0]->image = $swapchainImages[$i];
    $imageViewCreateInfo[0]->viewType = VK_IMAGE_VIEW_TYPE_2D;
    $imageViewCreateInfo[0]->format = $surfaceFormat->format;
    $imageViewCreateInfo[0]->components->r = 0;
    $imageViewCreateInfo[0]->components->g = 0;
    $imageViewCreateInfo[0]->components->b = 0;
    $imageViewCreateInfo[0]->components->a = 0;
    $imageViewCreateInfo[0]->subresourceRange->aspectMask = VK_IMAGE_ASPECT_COLOR_BIT;
    $imageViewCreateInfo[0]->subresourceRange->baseMipLevel = 0;
    $imageViewCreateInfo[0]->subresourceRange->levelCount = 1;
    $imageViewCreateInfo[0]->subresourceRange->baseArrayLayer = 0;
    $imageViewCreateInfo[0]->subresourceRange->layerCount = 1;

    $result = $vulkan_dev->vkCreateImageView($device[0], FFI::addr($imageViewCreateInfo[0]), null, FFI::addr($swapchainImageViews[$i]));
    check_result($result, "vkCreateImageView");
}

echo "[INIT] Created " . $swapchainImageCount[0] . " image views\n";

// Create render pass
echo "[INIT] Creating render pass...\n";

$colorAttachment = $vulkan_dev->new('VkAttachmentDescription[1]');
$colorAttachment[0]->flags = 0;
$colorAttachment[0]->format = $surfaceFormat->format;
$colorAttachment[0]->samples = VK_SAMPLE_COUNT_1_BIT;
$colorAttachment[0]->loadOp = VK_ATTACHMENT_LOAD_OP_CLEAR;
$colorAttachment[0]->storeOp = VK_ATTACHMENT_STORE_OP_STORE;
$colorAttachment[0]->stencilLoadOp = 0;
$colorAttachment[0]->stencilStoreOp = 0;
$colorAttachment[0]->initialLayout = VK_IMAGE_LAYOUT_UNDEFINED;
$colorAttachment[0]->finalLayout = VK_IMAGE_LAYOUT_PRESENT_SRC_KHR;

$colorAttachmentRef = $vulkan_dev->new('VkAttachmentReference[1]');
$colorAttachmentRef[0]->attachment = 0;
$colorAttachmentRef[0]->layout = VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL;

$subpass = $vulkan_dev->new('VkSubpassDescription[1]');
$subpass[0]->flags = 0;
$subpass[0]->pipelineBindPoint = VK_PIPELINE_BIND_POINT_GRAPHICS;
$subpass[0]->inputAttachmentCount = 0;
$subpass[0]->pInputAttachments = null;
$subpass[0]->colorAttachmentCount = 1;
$subpass[0]->pColorAttachments = FFI::addr($colorAttachmentRef[0]);
$subpass[0]->pResolveAttachments = null;
$subpass[0]->pDepthStencilAttachment = null;
$subpass[0]->preserveAttachmentCount = 0;
$subpass[0]->pPreserveAttachments = null;

$renderPassCreateInfo = $vulkan_dev->new('VkRenderPassCreateInfo[1]');
$renderPassCreateInfo[0]->sType = VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO;
$renderPassCreateInfo[0]->pNext = null;
$renderPassCreateInfo[0]->flags = 0;
$renderPassCreateInfo[0]->attachmentCount = 1;
$renderPassCreateInfo[0]->pAttachments = FFI::addr($colorAttachment[0]);
$renderPassCreateInfo[0]->subpassCount = 1;
$renderPassCreateInfo[0]->pSubpasses = FFI::addr($subpass[0]);
$renderPassCreateInfo[0]->dependencyCount = 0;
$renderPassCreateInfo[0]->pDependencies = null;

$renderPass = $vulkan_dev->new('VkRenderPass[1]');
$result = $vulkan_dev->vkCreateRenderPass($device[0], FFI::addr($renderPassCreateInfo[0]), null, FFI::addr($renderPass[0]));
check_result($result, "vkCreateRenderPass");

echo "[INIT] Render pass created\n";

// Create shader modules
echo "[INIT] Creating shader modules...\n";

// Convert SPIR-V bytes to uint32_t array
$vertSpvSize = strlen($vertSpv);
$fragSpvSize = strlen($fragSpv);

if ($vertSpvSize % 4 !== 0 || $fragSpvSize % 4 !== 0) {
    throw new Exception("SPIR-V size must be multiple of 4");
}

$vertSpvU32Count = $vertSpvSize / 4;
$fragSpvU32Count = $fragSpvSize / 4;

$vertSpvCode = $vulkan_dev->new("uint32_t[$vertSpvU32Count]", false);
$fragSpvCode = $vulkan_dev->new("uint32_t[$fragSpvU32Count]", false);

FFI::memcpy($vertSpvCode, $vertSpv, $vertSpvSize);
FFI::memcpy($fragSpvCode, $fragSpv, $fragSpvSize);

$vertShaderModuleCreateInfo = $vulkan_dev->new('VkShaderModuleCreateInfo[1]');
$vertShaderModuleCreateInfo[0]->sType = VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO;
$vertShaderModuleCreateInfo[0]->pNext = null;
$vertShaderModuleCreateInfo[0]->flags = 0;
$vertShaderModuleCreateInfo[0]->codeSize = $vertSpvSize;
$vertShaderModuleCreateInfo[0]->pCode = $vertSpvCode;

$vertShaderModule = $vulkan_dev->new('VkShaderModule[1]');
$result = $vulkan_dev->vkCreateShaderModule($device[0], FFI::addr($vertShaderModuleCreateInfo[0]), null, FFI::addr($vertShaderModule[0]));
check_result($result, "vkCreateShaderModule (vertex)");

$fragShaderModuleCreateInfo = $vulkan_dev->new('VkShaderModuleCreateInfo[1]');
$fragShaderModuleCreateInfo[0]->sType = VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO;
$fragShaderModuleCreateInfo[0]->pNext = null;
$fragShaderModuleCreateInfo[0]->flags = 0;
$fragShaderModuleCreateInfo[0]->codeSize = $fragSpvSize;
$fragShaderModuleCreateInfo[0]->pCode = $fragSpvCode;

$fragShaderModule = $vulkan_dev->new('VkShaderModule[1]');
$result = $vulkan_dev->vkCreateShaderModule($device[0], FFI::addr($fragShaderModuleCreateInfo[0]), null, FFI::addr($fragShaderModule[0]));
check_result($result, "vkCreateShaderModule (fragment)");

echo "[INIT] Shader modules created\n";

// Create pipeline layout
echo "[INIT] Creating pipeline layout...\n";

$pipelineLayoutCreateInfo = $vulkan_dev->new('VkPipelineLayoutCreateInfo[1]');
$pipelineLayoutCreateInfo[0]->sType = VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO;
$pipelineLayoutCreateInfo[0]->pNext = null;
$pipelineLayoutCreateInfo[0]->flags = 0;
$pipelineLayoutCreateInfo[0]->setLayoutCount = 0;
$pipelineLayoutCreateInfo[0]->pSetLayouts = null;
$pipelineLayoutCreateInfo[0]->pushConstantRangeCount = 0;
$pipelineLayoutCreateInfo[0]->pPushConstantRanges = null;

$pipelineLayout = $vulkan_dev->new('VkPipelineLayout[1]');
$result = $vulkan_dev->vkCreatePipelineLayout($device[0], FFI::addr($pipelineLayoutCreateInfo[0]), null, FFI::addr($pipelineLayout[0]));
check_result($result, "vkCreatePipelineLayout");

echo "[INIT] Pipeline layout created\n";

// Create graphics pipeline
echo "[INIT] Creating graphics pipeline...\n";

$main_str = abuf("main");

$shaderStages = $vulkan_dev->new('VkPipelineShaderStageCreateInfo[2]');

$shaderStages[0]->sType = VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO;
$shaderStages[0]->pNext = null;
$shaderStages[0]->flags = 0;
$shaderStages[0]->stage = VK_SHADER_STAGE_VERTEX_BIT;
$shaderStages[0]->module = $vertShaderModule[0];
$shaderStages[0]->pName = FFI::cast('const char*', FFI::addr($main_str[0]));
$shaderStages[0]->pSpecializationInfo = null;

$shaderStages[1]->sType = VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO;
$shaderStages[1]->pNext = null;
$shaderStages[1]->flags = 0;
$shaderStages[1]->stage = VK_SHADER_STAGE_FRAGMENT_BIT;
$shaderStages[1]->module = $fragShaderModule[0];
$shaderStages[1]->pName = FFI::cast('const char*', FFI::addr($main_str[0]));
$shaderStages[1]->pSpecializationInfo = null;

$vertexInput = $vulkan_dev->new('VkPipelineVertexInputStateCreateInfo[1]');
$vertexInput[0]->sType = VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO;
$vertexInput[0]->pNext = null;
$vertexInput[0]->flags = 0;
$vertexInput[0]->vertexBindingDescriptionCount = 0;
$vertexInput[0]->pVertexBindingDescriptions = null;
$vertexInput[0]->vertexAttributeDescriptionCount = 0;
$vertexInput[0]->pVertexAttributeDescriptions = null;

$inputAssembly = $vulkan_dev->new('VkPipelineInputAssemblyStateCreateInfo[1]');
$inputAssembly[0]->sType = VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO;
$inputAssembly[0]->pNext = null;
$inputAssembly[0]->flags = 0;
$inputAssembly[0]->topology = VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST;
$inputAssembly[0]->primitiveRestartEnable = 0;

$extent = $surfaceCapabilities[0]->currentExtent;

$viewport = $vulkan_dev->new('VkViewport[1]');
$viewport[0]->x = 0.0;
$viewport[0]->y = 0.0;
$viewport[0]->width = (float)$extent->width;
$viewport[0]->height = (float)$extent->height;
$viewport[0]->minDepth = 0.0;
$viewport[0]->maxDepth = 1.0;

$scissor = $vulkan_dev->new('VkRect2D[1]');
$scissor[0]->offset->x = 0;
$scissor[0]->offset->y = 0;
$scissor[0]->extent->width = $extent->width;
$scissor[0]->extent->height = $extent->height;

$viewportState = $vulkan_dev->new('VkPipelineViewportStateCreateInfo[1]');
$viewportState[0]->sType = VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO;
$viewportState[0]->pNext = null;
$viewportState[0]->flags = 0;
$viewportState[0]->viewportCount = 1;
$viewportState[0]->pViewports = FFI::addr($viewport[0]);
$viewportState[0]->scissorCount = 1;
$viewportState[0]->pScissors = FFI::addr($scissor[0]);

$rasterizationState = $vulkan_dev->new('VkPipelineRasterizationStateCreateInfo[1]');
$rasterizationState[0]->sType = VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO;
$rasterizationState[0]->pNext = null;
$rasterizationState[0]->flags = 0;
$rasterizationState[0]->depthClampEnable = 0;
$rasterizationState[0]->rasterizerDiscardEnable = 0;
$rasterizationState[0]->polygonMode = VK_POLYGON_MODE_FILL;
$rasterizationState[0]->cullMode = VK_CULL_MODE_NONE;
$rasterizationState[0]->frontFace = VK_FRONT_FACE_COUNTER_CLOCKWISE;
$rasterizationState[0]->depthBiasEnable = 0;
$rasterizationState[0]->depthBiasConstantFactor = 0.0;
$rasterizationState[0]->depthBiasClamp = 0.0;
$rasterizationState[0]->depthBiasSlopeFactor = 0.0;
$rasterizationState[0]->lineWidth = 1.0;

$multisampleState = $vulkan_dev->new('VkPipelineMultisampleStateCreateInfo[1]');
$multisampleState[0]->sType = VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO;
$multisampleState[0]->pNext = null;
$multisampleState[0]->flags = 0;
$multisampleState[0]->rasterizationSamples = VK_SAMPLE_COUNT_1_BIT;
$multisampleState[0]->sampleShadingEnable = 0;
$multisampleState[0]->minSampleShading = 1.0;
$multisampleState[0]->pSampleMask = null;
$multisampleState[0]->alphaToCoverageEnable = 0;
$multisampleState[0]->alphaToOneEnable = 0;

$colorBlendAttachment = $vulkan_dev->new('VkPipelineColorBlendAttachmentState[1]');
$colorBlendAttachment[0]->blendEnable = 0;
$colorBlendAttachment[0]->srcColorBlendFactor = 0;
$colorBlendAttachment[0]->dstColorBlendFactor = 0;
$colorBlendAttachment[0]->colorBlendOp = 0;
$colorBlendAttachment[0]->srcAlphaBlendFactor = 0;
$colorBlendAttachment[0]->dstAlphaBlendFactor = 0;
$colorBlendAttachment[0]->alphaBlendOp = 0;
$colorBlendAttachment[0]->colorWriteMask = VK_COLOR_COMPONENT_R_BIT | VK_COLOR_COMPONENT_G_BIT | VK_COLOR_COMPONENT_B_BIT | VK_COLOR_COMPONENT_A_BIT;

$colorBlendState = $vulkan_dev->new('VkPipelineColorBlendStateCreateInfo[1]');
$colorBlendState[0]->sType = VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO;
$colorBlendState[0]->pNext = null;
$colorBlendState[0]->flags = 0;
$colorBlendState[0]->logicOpEnable = 0;
$colorBlendState[0]->logicOp = 0;
$colorBlendState[0]->attachmentCount = 1;
$colorBlendState[0]->pAttachments = FFI::addr($colorBlendAttachment[0]);
$colorBlendState[0]->blendConstants[0] = 0.0;
$colorBlendState[0]->blendConstants[1] = 0.0;
$colorBlendState[0]->blendConstants[2] = 0.0;
$colorBlendState[0]->blendConstants[3] = 0.0;

$dynamicStates = $vulkan_dev->new('uint32_t[2]');
$dynamicStates[0] = VK_DYNAMIC_STATE_VIEWPORT;
$dynamicStates[1] = VK_DYNAMIC_STATE_SCISSOR;

$dynamicState = $vulkan_dev->new('VkPipelineDynamicStateCreateInfo[1]');
$dynamicState[0]->sType = VK_STRUCTURE_TYPE_PIPELINE_DYNAMIC_STATE_CREATE_INFO;
$dynamicState[0]->pNext = null;
$dynamicState[0]->flags = 0;
$dynamicState[0]->dynamicStateCount = 2;
$dynamicState[0]->pDynamicStates = FFI::addr($dynamicStates[0]);

$graphicsPipelineCreateInfo = $vulkan_dev->new('VkGraphicsPipelineCreateInfo[1]');
$graphicsPipelineCreateInfo[0]->sType = VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO;
$graphicsPipelineCreateInfo[0]->pNext = null;
$graphicsPipelineCreateInfo[0]->flags = 0;
$graphicsPipelineCreateInfo[0]->stageCount = 2;
$graphicsPipelineCreateInfo[0]->pStages = FFI::addr($shaderStages[0]);
$graphicsPipelineCreateInfo[0]->pVertexInputState = FFI::addr($vertexInput[0]);
$graphicsPipelineCreateInfo[0]->pInputAssemblyState = FFI::addr($inputAssembly[0]);
$graphicsPipelineCreateInfo[0]->pTessellationState = null;
$graphicsPipelineCreateInfo[0]->pViewportState = FFI::addr($viewportState[0]);
$graphicsPipelineCreateInfo[0]->pRasterizationState = FFI::addr($rasterizationState[0]);
$graphicsPipelineCreateInfo[0]->pMultisampleState = FFI::addr($multisampleState[0]);
$graphicsPipelineCreateInfo[0]->pDepthStencilState = null;
$graphicsPipelineCreateInfo[0]->pColorBlendState = FFI::addr($colorBlendState[0]);
$graphicsPipelineCreateInfo[0]->pDynamicState = FFI::addr($dynamicState[0]);
$graphicsPipelineCreateInfo[0]->layout = $pipelineLayout[0];
$graphicsPipelineCreateInfo[0]->renderPass = $renderPass[0];
$graphicsPipelineCreateInfo[0]->subpass = 0;
$graphicsPipelineCreateInfo[0]->basePipelineHandle = 0;
$graphicsPipelineCreateInfo[0]->basePipelineIndex = -1;

$graphicsPipeline = $vulkan_dev->new('VkPipeline[1]');
$result = $vulkan_dev->vkCreateGraphicsPipelines($device[0], null, 1, FFI::addr($graphicsPipelineCreateInfo[0]), null, FFI::addr($graphicsPipeline[0]));
check_result($result, "vkCreateGraphicsPipelines");

echo "[INIT] Graphics pipeline created\n";

// Destroy shader modules (no longer needed after pipeline creation)
$vulkan_dev->vkDestroyShaderModule($device[0], $vertShaderModule[0], null);
$vulkan_dev->vkDestroyShaderModule($device[0], $fragShaderModule[0], null);

// Create framebuffers
echo "[INIT] Creating framebuffers...\n";

$framebuffers = $vulkan_dev->new("VkFramebuffer[" . $swapchainImageCount[0] . "]");
for ($i = 0; $i < $swapchainImageCount[0]; $i++) {
    $attachments = $vulkan_dev->new('VkImageView[1]');
    $attachments[0] = $swapchainImageViews[$i];

    $framebufferCreateInfo = $vulkan_dev->new('VkFramebufferCreateInfo[1]');
    $framebufferCreateInfo[0]->sType = VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO;
    $framebufferCreateInfo[0]->pNext = null;
    $framebufferCreateInfo[0]->flags = 0;
    $framebufferCreateInfo[0]->renderPass = $renderPass[0];
    $framebufferCreateInfo[0]->attachmentCount = 1;
    $framebufferCreateInfo[0]->pAttachments = FFI::addr($attachments[0]);
    $framebufferCreateInfo[0]->width = $extent->width;
    $framebufferCreateInfo[0]->height = $extent->height;
    $framebufferCreateInfo[0]->layers = 1;

    $result = $vulkan_dev->vkCreateFramebuffer($device[0], FFI::addr($framebufferCreateInfo[0]), null, FFI::addr($framebuffers[$i]));
    check_result($result, "vkCreateFramebuffer");
}

echo "[INIT] Created " . $swapchainImageCount[0] . " framebuffers\n";

// Create command pool
echo "[INIT] Creating command pool...\n";

$commandPoolCreateInfo = $vulkan_dev->new('VkCommandPoolCreateInfo[1]');
$commandPoolCreateInfo[0]->sType = VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO;
$commandPoolCreateInfo[0]->pNext = null;
$commandPoolCreateInfo[0]->flags = VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT;
$commandPoolCreateInfo[0]->queueFamilyIndex = $graphicsQueueFamily;

$commandPool = $vulkan_dev->new('VkCommandPool[1]');
$result = $vulkan_dev->vkCreateCommandPool($device[0], FFI::addr($commandPoolCreateInfo[0]), null, FFI::addr($commandPool[0]));
check_result($result, "vkCreateCommandPool");

echo "[INIT] Command pool created\n";

// Allocate command buffers
echo "[INIT] Allocating command buffers...\n";

$commandBufferAllocateInfo = $vulkan_dev->new('VkCommandBufferAllocateInfo[1]');
$commandBufferAllocateInfo[0]->sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO;
$commandBufferAllocateInfo[0]->pNext = null;
$commandBufferAllocateInfo[0]->commandPool = $commandPool[0];
$commandBufferAllocateInfo[0]->level = VK_COMMAND_BUFFER_LEVEL_PRIMARY;
$commandBufferAllocateInfo[0]->commandBufferCount = $swapchainImageCount[0];

$commandBuffers = $vulkan_dev->new("VkCommandBuffer[" . $swapchainImageCount[0] . "]");
$result = $vulkan_dev->vkAllocateCommandBuffers($device[0], FFI::addr($commandBufferAllocateInfo[0]), $commandBuffers);
check_result($result, "vkAllocateCommandBuffers");

echo "[INIT] Allocated " . $swapchainImageCount[0] . " command buffers\n";

// Record command buffers
echo "[INIT] Recording command buffers...\n";

for ($i = 0; $i < $swapchainImageCount[0]; $i++) {
    $commandBufferBeginInfo = $vulkan_dev->new('VkCommandBufferBeginInfo[1]');
    $commandBufferBeginInfo[0]->sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO;
    $commandBufferBeginInfo[0]->pNext = null;
    $commandBufferBeginInfo[0]->flags = 0;
    $commandBufferBeginInfo[0]->pInheritanceInfo = null;

    $result = $vulkan_dev->vkBeginCommandBuffer($commandBuffers[$i], FFI::addr($commandBufferBeginInfo[0]));
    check_result($result, "vkBeginCommandBuffer");

    // Clear color
    $clearColor = $vulkan_dev->new('VkClearColorValue[1]');
    $clearColor[0]->float32[0] = 0.05;
    $clearColor[0]->float32[1] = 0.05;
    $clearColor[0]->float32[2] = 0.10;
    $clearColor[0]->float32[3] = 1.0;

    $renderPassBeginInfo = $vulkan_dev->new('VkRenderPassBeginInfo[1]');
    $renderPassBeginInfo[0]->sType = VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO;
    $renderPassBeginInfo[0]->pNext = null;
    $renderPassBeginInfo[0]->renderPass = $renderPass[0];
    $renderPassBeginInfo[0]->framebuffer = $framebuffers[$i];
    $renderPassBeginInfo[0]->renderArea->offset->x = 0;
    $renderPassBeginInfo[0]->renderArea->offset->y = 0;
    $renderPassBeginInfo[0]->renderArea->extent->width = $extent->width;
    $renderPassBeginInfo[0]->renderArea->extent->height = $extent->height;
    $renderPassBeginInfo[0]->clearValueCount = 1;
    $renderPassBeginInfo[0]->pClearValues = FFI::cast('void*', FFI::addr($clearColor[0]));

    $vulkan_dev->vkCmdBeginRenderPass($commandBuffers[$i], FFI::addr($renderPassBeginInfo[0]), 0);
    $vulkan_dev->vkCmdBindPipeline($commandBuffers[$i], VK_PIPELINE_BIND_POINT_GRAPHICS, $graphicsPipeline[0]);
    
    $vulkan_dev->vkCmdSetViewport($commandBuffers[$i], 0, 1, FFI::addr($viewport[0]));
    $vulkan_dev->vkCmdSetScissor($commandBuffers[$i], 0, 1, FFI::addr($scissor[0]));
    
    $vulkan_dev->vkCmdDraw($commandBuffers[$i], 3, 1, 0, 0);
    
    $vulkan_dev->vkCmdEndRenderPass($commandBuffers[$i]);

    $result = $vulkan_dev->vkEndCommandBuffer($commandBuffers[$i]);
    check_result($result, "vkEndCommandBuffer");
}

echo "[INIT] Command buffers recorded\n";

// Create synchronization objects (semaphores and fences)
echo "[INIT] Creating synchronization objects...\n";

$maxFramesInFlight = 2;

$imageAvailableSemaphores = $vulkan_dev->new("VkSemaphore[$maxFramesInFlight]");
$renderFinishedSemaphores = $vulkan_dev->new("VkSemaphore[$maxFramesInFlight]");
$inFlightFences = $vulkan_dev->new("VkFence[$maxFramesInFlight]");

for ($i = 0; $i < $maxFramesInFlight; $i++) {
    $semaphoreCreateInfo = $vulkan_dev->new('VkSemaphoreCreateInfo[1]');
    $semaphoreCreateInfo[0]->sType = VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO;
    $semaphoreCreateInfo[0]->pNext = null;
    $semaphoreCreateInfo[0]->flags = 0;

    $result = $vulkan_dev->vkCreateSemaphore($device[0], FFI::addr($semaphoreCreateInfo[0]), null, FFI::addr($imageAvailableSemaphores[$i]));
    check_result($result, "vkCreateSemaphore");

    $result = $vulkan_dev->vkCreateSemaphore($device[0], FFI::addr($semaphoreCreateInfo[0]), null, FFI::addr($renderFinishedSemaphores[$i]));
    check_result($result, "vkCreateSemaphore");

    $fenceCreateInfo = $vulkan_dev->new('VkFenceCreateInfo[1]');
    $fenceCreateInfo[0]->sType = VK_STRUCTURE_TYPE_FENCE_CREATE_INFO;
    $fenceCreateInfo[0]->pNext = null;
    $fenceCreateInfo[0]->flags = VK_FENCE_CREATE_SIGNALED_BIT;

    $result = $vulkan_dev->vkCreateFence($device[0], FFI::addr($fenceCreateInfo[0]), null, FFI::addr($inFlightFences[$i]));
    check_result($result, "vkCreateFence");
}

echo "[INIT] Synchronization objects created\n";

// ============================================================
// Render Loop
// ============================================================
echo "\n[RENDER] Starting render loop. Close window to exit.\n";

// Suppress deprecated warnings in render loop for cleaner output
error_reporting(E_ALL & ~E_DEPRECATED & ~E_WARNING);

$msg = $user32->new('MSG');
$bQuit = false;
$frameCount = 0;
$currentFrame = 0;

while (!$bQuit) {
    if ($user32->IsWindow($hwnd) == 0) {
        break;
    }

    if ($user32->PeekMessageW(FFI::addr($msg), null, 0, 0, PM_REMOVE) != 0) {
        if ((int)$msg->message === WM_QUIT) {
            $bQuit = true;
        } else if ((int)$msg->message === WM_CLOSE) {
            $bQuit = true;
        } else {
            $user32->TranslateMessage(FFI::addr($msg));
            $user32->DispatchMessageW(FFI::addr($msg));
        }
    } else {
        // Render frame
        $frameIdx = $currentFrame % $maxFramesInFlight;

        // Wait for fence
        $fenceArray = $vulkan_dev->new('VkFence[1]');
        $fenceArray[0] = $inFlightFences[$frameIdx];
        $vulkan_dev->vkWaitForFences($device[0], 1, FFI::addr($fenceArray[0]), 1, 0xFFFFFFFFFFFFFFFF);
        $vulkan_dev->vkResetFences($device[0], 1, FFI::addr($fenceArray[0]));

        // Acquire next image
        $imageIndex = $vulkan_dev->new('uint32_t[1]');
        $res = $vulkan_dev->vkAcquireNextImageKHR($device[0], $swapchain[0], 0xFFFFFFFFFFFFFFFF, $imageAvailableSemaphores[$frameIdx], 0, FFI::addr($imageIndex[0]));

        if ($res !== VK_SUCCESS && $res !== VK_SUBOPTIMAL_KHR) {
            if ($res !== VK_ERROR_OUT_OF_DATE_KHR) {
                check_result($res, "vkAcquireNextImageKHR");
            }
        }

        $imgIdx = $imageIndex[0];

        // Submit command buffer
        $waitSemaphoreArray = $vulkan_dev->new('VkSemaphore[1]');
        $waitSemaphoreArray[0] = $imageAvailableSemaphores[$frameIdx];

        $signalSemaphoreArray = $vulkan_dev->new('VkSemaphore[1]');
        $signalSemaphoreArray[0] = $renderFinishedSemaphores[$frameIdx];

        $waitStages = $vulkan_dev->new('uint32_t[1]');
        $waitStages[0] = VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT;

        $cmdArray = $vulkan_dev->new('VkCommandBuffer[1]');
        $cmdArray[0] = $commandBuffers[$imgIdx];

        $submitInfo = $vulkan_dev->new('VkSubmitInfo[1]');
        $submitInfo[0]->sType = VK_STRUCTURE_TYPE_SUBMIT_INFO;
        $submitInfo[0]->pNext = null;
        $submitInfo[0]->waitSemaphoreCount = 1;
        $submitInfo[0]->pWaitSemaphores = FFI::addr($waitSemaphoreArray[0]);
        $submitInfo[0]->pWaitDstStageMask = FFI::addr($waitStages[0]);
        $submitInfo[0]->commandBufferCount = 1;
        $submitInfo[0]->pCommandBuffers = FFI::addr($cmdArray[0]);
        $submitInfo[0]->signalSemaphoreCount = 1;
        $submitInfo[0]->pSignalSemaphores = FFI::addr($signalSemaphoreArray[0]);

        $result = $vulkan_dev->vkQueueSubmit($graphicsQueue[0], 1, FFI::addr($submitInfo[0]), $inFlightFences[$frameIdx]);
        check_result($result, "vkQueueSubmit");

        // Present image
        $swapchainArray = $vulkan_dev->new('VkSwapchainKHR[1]');
        $swapchainArray[0] = $swapchain[0];

        $imageIndexArray = $vulkan_dev->new('uint32_t[1]');
        $imageIndexArray[0] = $imgIdx;

        $presentInfo = $vulkan_dev->new('VkPresentInfoKHR[1]');
        $presentInfo[0]->sType = VK_STRUCTURE_TYPE_PRESENT_INFO_KHR;
        $presentInfo[0]->pNext = null;
        $presentInfo[0]->waitSemaphoreCount = 1;
        $presentInfo[0]->pWaitSemaphores = FFI::addr($signalSemaphoreArray[0]);
        $presentInfo[0]->swapchainCount = 1;
        $presentInfo[0]->pSwapchains = FFI::addr($swapchainArray[0]);
        $presentInfo[0]->pImageIndices = FFI::addr($imageIndexArray[0]);
        $presentInfo[0]->pResults = null;

        $res = $vulkan_dev->vkQueuePresentKHR($graphicsQueue[0], FFI::addr($presentInfo[0]));
        if ($res !== VK_SUCCESS && $res !== VK_SUBOPTIMAL_KHR && $res !== VK_ERROR_OUT_OF_DATE_KHR) {
            check_result($res, "vkQueuePresentKHR");
        }

        $currentFrame++;
        $frameCount++;

        // Optional: Log every 300 frames (~5 seconds at 60fps)
        // if ($frameCount % 300 === 0) {
        //     echo "[RENDER] Frame: $frameCount\n";
        // }

        usleep(16000);  // ~60 FPS
    }
}

// Cleanup
echo "[CLEANUP] Waiting for device idle...\n";
$vulkan_dev->vkDeviceWaitIdle($device[0]);

echo "[CLEANUP] Destroying synchronization objects...\n";
for ($i = 0; $i < $maxFramesInFlight; $i++) {
    $vulkan_dev->vkDestroySemaphore($device[0], $imageAvailableSemaphores[$i], null);
    $vulkan_dev->vkDestroySemaphore($device[0], $renderFinishedSemaphores[$i], null);
    $vulkan_dev->vkDestroyFence($device[0], $inFlightFences[$i], null);
}

echo "[CLEANUP] Destroying command pool...\n";
$vulkan_dev->vkDestroyCommandPool($device[0], $commandPool[0], null);

echo "[CLEANUP] Destroying framebuffers...\n";
for ($i = 0; $i < $swapchainImageCount[0]; $i++) {
    $vulkan_dev->vkDestroyFramebuffer($device[0], $framebuffers[$i], null);
}

echo "[CLEANUP] Destroying pipeline...\n";
$vulkan_dev->vkDestroyPipeline($device[0], $graphicsPipeline[0], null);

echo "[CLEANUP] Destroying pipeline layout...\n";
$vulkan_dev->vkDestroyPipelineLayout($device[0], $pipelineLayout[0], null);

echo "[CLEANUP] Destroying render pass...\n";
$vulkan_dev->vkDestroyRenderPass($device[0], $renderPass[0], null);

echo "[CLEANUP] Destroying image views...\n";
for ($i = 0; $i < $swapchainImageCount[0]; $i++) {
    $vulkan_dev->vkDestroyImageView($device[0], $swapchainImageViews[$i], null);
}

echo "[CLEANUP] Destroying swapchain...\n";
$vulkan_dev->vkDestroySwapchainKHR($device[0], $swapchain[0], null);

echo "[CLEANUP] Destroying surface...\n";
$vulkan_dev->vkDestroySurfaceKHR($instance[0], $surface[0], null);

echo "[CLEANUP] Destroying device...\n";
$vulkan_dev->vkDestroyDevice($device[0], null);

echo "[CLEANUP] Destroying instance...\n";
$vulkan->vkDestroyInstance($instance[0], null);

echo "[CLEANUP] Destroying window...\n";
$user32->DestroyWindow($hwnd);

echo "\n[EXIT] Vulkan 1.4 Triangle (PHP) - Program ended normally.\n";
echo "[EXIT] Total frames rendered: $frameCount\n";
