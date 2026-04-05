program hello;

{$mode objfpc}
{$PACKRECORDS C}

uses SysUtils, Math;

const
    libVulkan = 'libvulkan.so.1';
    libGLFW   = 'libglfw.so.3';

    WIDTH  = 800;
    HEIGHT = 600;
    MAX_FRAMES_IN_FLIGHT = 2;

    { VkResult }
    VK_SUCCESS                = 0;
    VK_SUBOPTIMAL_KHR         = 1000001003;
    VK_ERROR_OUT_OF_DATE_KHR  = LongInt(-1000001004);
    VK_ERROR_EXTENSION_NOT_PRESENT = -7;

    { VkStructureType }
    VK_STRUCTURE_TYPE_APPLICATION_INFO                          = 0;
    VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO                      = 1;
    VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO                  = 2;
    VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO                        = 3;
    VK_STRUCTURE_TYPE_SUBMIT_INFO                               = 4;
    VK_STRUCTURE_TYPE_FENCE_CREATE_INFO                         = 8;
    VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO                     = 9;
    VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO                    = 15;
    VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO                 = 16;
    VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO         = 18;
    VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO   = 19;
    VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO = 20;
    VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO       = 22;
    VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO  = 23;
    VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO    = 24;
    VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO    = 26;
    VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO             = 28;
    VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO               = 30;
    VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO                   = 37;
    VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO                   = 38;
    VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO                  = 39;
    VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO              = 40;
    VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO                 = 42;
    VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO                    = 43;
    VK_STRUCTURE_TYPE_PRESENT_INFO_KHR                          = 1000001001;
    VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR                 = 1000001000;
    VK_STRUCTURE_TYPE_DEBUG_UTILS_MESSENGER_CREATE_INFO_EXT     = 1000128004;

    { VkFormat }
    VK_FORMAT_B8G8R8A8_SRGB = 50;

    { VkColorSpaceKHR }
    VK_COLOR_SPACE_SRGB_NONLINEAR_KHR = 0;

    { VkPresentModeKHR }
    VK_PRESENT_MODE_FIFO_KHR    = 2;
    VK_PRESENT_MODE_MAILBOX_KHR = 1;

    { VkImageUsageFlagBits }
    VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT = $10;

    { VkSharingMode }
    VK_SHARING_MODE_EXCLUSIVE  = 0;
    VK_SHARING_MODE_CONCURRENT = 1;

    { VkCompositeAlphaFlagBitsKHR }
    VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR = 1;

    { VkImageViewType }
    VK_IMAGE_VIEW_TYPE_2D = 1;

    { VkComponentSwizzle }
    VK_COMPONENT_SWIZZLE_IDENTITY = 0;

    { VkImageAspectFlagBits }
    VK_IMAGE_ASPECT_COLOR_BIT = 1;

    { VkShaderStageFlagBits }
    VK_SHADER_STAGE_VERTEX_BIT   = 1;
    VK_SHADER_STAGE_FRAGMENT_BIT = 16;

    { VkPrimitiveTopology }
    VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST = 3;

    { VkPolygonMode }
    VK_POLYGON_MODE_FILL = 0;

    { VkCullModeFlagBits }
    VK_CULL_MODE_BACK_BIT = 2;

    { VkFrontFace }
    VK_FRONT_FACE_CLOCKWISE = 1;

    { VkSampleCountFlagBits }
    VK_SAMPLE_COUNT_1_BIT = 1;

    { VkColorComponentFlagBits }
    VK_COLOR_COMPONENT_R_BIT = 1;
    VK_COLOR_COMPONENT_G_BIT = 2;
    VK_COLOR_COMPONENT_B_BIT = 4;
    VK_COLOR_COMPONENT_A_BIT = 8;

    { VkAttachmentLoadOp }
    VK_ATTACHMENT_LOAD_OP_CLEAR     = 1;
    VK_ATTACHMENT_LOAD_OP_DONT_CARE = 2;

    { VkAttachmentStoreOp }
    VK_ATTACHMENT_STORE_OP_STORE     = 0;
    VK_ATTACHMENT_STORE_OP_DONT_CARE = 1;

    { VkImageLayout }
    VK_IMAGE_LAYOUT_UNDEFINED                = 0;
    VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL = 2;
    VK_IMAGE_LAYOUT_PRESENT_SRC_KHR          = 1000001002;

    { VkPipelineBindPoint }
    VK_PIPELINE_BIND_POINT_GRAPHICS = 0;

    { VkSubpassContents }
    VK_SUBPASS_CONTENTS_INLINE = 0;

    { VkPipelineStageFlagBits }
    VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT = $400;

    { VkAccessFlagBits }
    VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT = $100;

    { VkCommandBufferLevel }
    VK_COMMAND_BUFFER_LEVEL_PRIMARY = 0;

    { VkFenceCreateFlagBits }
    VK_FENCE_CREATE_SIGNALED_BIT = 1;

    { VkQueueFlagBits }
    VK_QUEUE_GRAPHICS_BIT = 1;

    VK_FALSE = Cardinal(0);
    VK_TRUE  = Cardinal(1);

    { Sentinel for "no external subpass" }
    VK_SUBPASS_EXTERNAL = Cardinal($FFFFFFFF);

    { GLFW }
    GLFW_CLIENT_API = $00022001;
    GLFW_NO_API     = 0;

    { Vulkan extensions / layers }
    VK_KHR_SWAPCHAIN_EXTENSION_NAME    = 'VK_KHR_swapchain';
    VK_EXT_DEBUG_UTILS_EXTENSION_NAME  = 'VK_EXT_debug_utils';
    VK_LAYER_KHRONOS_VALIDATION        = 'VK_LAYER_KHRONOS_validation';

    { VkDebugUtilsMessageSeverityFlagBitsEXT }
    VK_DEBUG_UTILS_MESSAGE_SEVERITY_VERBOSE_BIT_EXT = $0001;
    VK_DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT = $0100;
    VK_DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT   = $1000;

    { VkDebugUtilsMessageTypeFlagBitsEXT }
    VK_DEBUG_UTILS_MESSAGE_TYPE_GENERAL_BIT_EXT     = $0001;
    VK_DEBUG_UTILS_MESSAGE_TYPE_VALIDATION_BIT_EXT  = $0002;
    VK_DEBUG_UTILS_MESSAGE_TYPE_PERFORMANCE_BIT_EXT = $0004;

    UINT64_MAX = UInt64($FFFFFFFFFFFFFFFF);

    ENABLE_VALIDATION_LAYERS = True;

type
    VkBool32   = Cardinal;
    VkResult   = LongInt;
    VkFlags    = Cardinal;
    VkDeviceSize = UInt64;

    { Dispatchable handles }
    VkInstance       = Pointer;
    VkPhysicalDevice = Pointer;
    VkDevice         = Pointer;
    VkQueue          = Pointer;
    VkCommandBuffer  = Pointer;

    { Non-dispatchable handles }
    VkSemaphore              = UInt64;
    VkFence                  = UInt64;
    VkImage                  = UInt64;
    VkImageView              = UInt64;
    VkSwapchainKHR           = UInt64;
    VkSurfaceKHR             = UInt64;
    VkShaderModule           = UInt64;
    VkPipelineLayout         = UInt64;
    VkRenderPass             = UInt64;
    VkPipeline               = UInt64;
    VkPipelineCache          = UInt64;
    VkFramebuffer            = UInt64;
    VkCommandPool            = UInt64;
    VkDebugUtilsMessengerEXT = UInt64;

    { Pointer types }
    PVkBool32        = ^VkBool32;
    PVkResult        = ^VkResult;
    PVkInstance      = ^VkInstance;
    PVkPhysicalDevice = ^VkPhysicalDevice;
    PVkDevice        = ^VkDevice;
    PVkQueue         = ^VkQueue;
    PVkSemaphore     = ^VkSemaphore;
    PVkFence         = ^VkFence;
    PVkImage         = ^VkImage;
    PVkImageView     = ^VkImageView;
    PVkSwapchainKHR  = ^VkSwapchainKHR;
    PVkSurfaceKHR    = ^VkSurfaceKHR;
    PVkShaderModule  = ^VkShaderModule;
    PVkPipelineLayout = ^VkPipelineLayout;
    PVkRenderPass    = ^VkRenderPass;
    PVkPipeline      = ^VkPipeline;
    PVkFramebuffer   = ^VkFramebuffer;
    PVkCommandPool   = ^VkCommandPool;
    PVkDebugUtilsMessengerEXT = ^VkDebugUtilsMessengerEXT;
    PVkCommandBuffer          = ^VkCommandBuffer;
    PPAnsiChar                = ^PAnsiChar;
    PVkSurfaceCapabilitiesKHR = ^VkSurfaceCapabilitiesKHR;
    PVkFlags                  = ^VkFlags;

    { Structs }
    VkExtent2D = record
        width  : Cardinal;
        height : Cardinal;
    end;
    PVkExtent2D = ^VkExtent2D;

    VkOffset2D = record
        x : LongInt;
        y : LongInt;
    end;

    VkRect2D = record
        offset : VkOffset2D;
        extent : VkExtent2D;
    end;
    PVkRect2D = ^VkRect2D;

    VkApplicationInfo = record
        sType              : LongInt;
        pNext              : Pointer;
        pApplicationName   : PAnsiChar;
        applicationVersion : Cardinal;
        pEngineName        : PAnsiChar;
        engineVersion      : Cardinal;
        apiVersion         : Cardinal;
    end;
    PVkApplicationInfo = ^VkApplicationInfo;

    VkInstanceCreateInfo = record
        sType                   : LongInt;
        pNext                   : Pointer;
        flags                   : VkFlags;
        pApplicationInfo        : PVkApplicationInfo;
        enabledLayerCount       : Cardinal;
        ppEnabledLayerNames     : PPAnsiChar;
        enabledExtensionCount   : Cardinal;
        ppEnabledExtensionNames : PPAnsiChar;
    end;
    PVkInstanceCreateInfo = ^VkInstanceCreateInfo;

    VkDebugUtilsMessengerCallbackDataEXT = record
        sType            : LongInt;
        pNext            : Pointer;
        flags            : VkFlags;
        pMessageIdName   : PAnsiChar;
        messageIdNumber  : LongInt;
        pMessage         : PAnsiChar;
        queueLabelCount  : Cardinal;
        pQueueLabels     : Pointer;
        cmdBufLabelCount : Cardinal;
        pCmdBufLabels    : Pointer;
        objectCount      : Cardinal;
        pObjects         : Pointer;
    end;
    PVkDebugUtilsMessengerCallbackDataEXT = ^VkDebugUtilsMessengerCallbackDataEXT;

    PFN_vkDebugUtilsMessengerCallbackEXT = function(
        messageSeverity : Cardinal;
        messageType     : Cardinal;
        pCallbackData   : PVkDebugUtilsMessengerCallbackDataEXT;
        pUserData       : Pointer
    ): VkBool32; cdecl;

    VkDebugUtilsMessengerCreateInfoEXT = record
        sType           : LongInt;
        pNext           : Pointer;
        flags           : VkFlags;
        messageSeverity : Cardinal;
        messageType     : Cardinal;
        pfnUserCallback : PFN_vkDebugUtilsMessengerCallbackEXT;
        pUserData       : Pointer;
    end;
    PVkDebugUtilsMessengerCreateInfoEXT = ^VkDebugUtilsMessengerCreateInfoEXT;

    VkLayerProperties = record
        layerName             : array[0..255] of AnsiChar;
        specVersion           : Cardinal;
        implementationVersion : Cardinal;
        description           : array[0..255] of AnsiChar;
    end;
    PVkLayerProperties = ^VkLayerProperties;

    VkExtensionProperties = record
        extensionName : array[0..255] of AnsiChar;
        specVersion   : Cardinal;
    end;
    PVkExtensionProperties = ^VkExtensionProperties;

    VkExtent3D = record
        width  : Cardinal;
        height : Cardinal;
        depth  : Cardinal;
    end;

    VkQueueFamilyProperties = record
        queueFlags                  : VkFlags;
        queueCount                  : Cardinal;
        timestampValidBits          : Cardinal;
        minImageTransferGranularity : VkExtent3D;
    end;
    PVkQueueFamilyProperties = ^VkQueueFamilyProperties;

    VkSurfaceCapabilitiesKHR = record
        minImageCount           : Cardinal;
        maxImageCount           : Cardinal;
        currentExtent           : VkExtent2D;
        minImageExtent          : VkExtent2D;
        maxImageExtent          : VkExtent2D;
        maxImageArrayLayers     : Cardinal;
        supportedTransforms     : VkFlags;
        currentTransform        : Cardinal;
        supportedCompositeAlpha : VkFlags;
        supportedUsageFlags     : VkFlags;
    end;

    VkSurfaceFormatKHR = record
        format     : LongInt;
        colorSpace : LongInt;
    end;
    PVkSurfaceFormatKHR = ^VkSurfaceFormatKHR;

    VkDeviceQueueCreateInfo = record
        sType            : LongInt;
        pNext            : Pointer;
        flags            : VkFlags;
        queueFamilyIndex : Cardinal;
        queueCount       : Cardinal;
        pQueuePriorities : PSingle;
    end;
    PVkDeviceQueueCreateInfo = ^VkDeviceQueueCreateInfo;

    VkPhysicalDeviceFeatures = record
        robustBufferAccess                      : VkBool32;
        fullDrawIndexUint32                     : VkBool32;
        imageCubeArray                          : VkBool32;
        independentBlend                        : VkBool32;
        geometryShader                          : VkBool32;
        tessellationShader                      : VkBool32;
        sampleRateShading                       : VkBool32;
        dualSrcBlend                            : VkBool32;
        logicOp                                 : VkBool32;
        multiDrawIndirect                       : VkBool32;
        drawIndirectFirstInstance               : VkBool32;
        depthClamp                              : VkBool32;
        depthBiasClamp                          : VkBool32;
        fillModeNonSolid                        : VkBool32;
        depthBounds                             : VkBool32;
        wideLines                               : VkBool32;
        largePoints                             : VkBool32;
        alphaToOne                              : VkBool32;
        multiViewport                           : VkBool32;
        samplerAnisotropy                       : VkBool32;
        textureCompressionETC2                  : VkBool32;
        textureCompressionASTC_LDR              : VkBool32;
        textureCompressionBC                    : VkBool32;
        occlusionQueryPrecise                   : VkBool32;
        pipelineStatisticsQuery                 : VkBool32;
        vertexPipelineStoresAndAtomics          : VkBool32;
        fragmentStoresAndAtomics                : VkBool32;
        shaderTessellationAndGeometryPointSize  : VkBool32;
        shaderImageGatherExtended               : VkBool32;
        shaderStorageImageExtendedFormats       : VkBool32;
        shaderStorageImageMultisample           : VkBool32;
        shaderStorageImageReadWithoutFormat     : VkBool32;
        shaderStorageImageWriteWithoutFormat    : VkBool32;
        shaderUniformBufferArrayDynamicIndexing : VkBool32;
        shaderSampledImageArrayDynamicIndexing  : VkBool32;
        shaderStorageBufferArrayDynamicIndexing : VkBool32;
        shaderStorageImageArrayDynamicIndexing  : VkBool32;
        shaderClipDistance                      : VkBool32;
        shaderCullDistance                      : VkBool32;
        shaderFloat64                           : VkBool32;
        shaderInt64                             : VkBool32;
        shaderInt16                             : VkBool32;
        shaderResourceResidency                 : VkBool32;
        shaderResourceMinLod                    : VkBool32;
        sparseBinding                           : VkBool32;
        sparseResidencyBuffer                   : VkBool32;
        sparseResidencyImage2D                  : VkBool32;
        sparseResidencyImage3D                  : VkBool32;
        sparseResidency2Samples                 : VkBool32;
        sparseResidency4Samples                 : VkBool32;
        sparseResidency8Samples                 : VkBool32;
        sparseResidency16Samples                : VkBool32;
        sparseResidencyAliased                  : VkBool32;
        variableMultisampleRate                 : VkBool32;
        inheritedQueries                        : VkBool32;
    end;
    PVkPhysicalDeviceFeatures = ^VkPhysicalDeviceFeatures;

    VkDeviceCreateInfo = record
        sType                   : LongInt;
        pNext                   : Pointer;
        flags                   : VkFlags;
        queueCreateInfoCount    : Cardinal;
        pQueueCreateInfos       : PVkDeviceQueueCreateInfo;
        enabledLayerCount       : Cardinal;
        ppEnabledLayerNames     : PPAnsiChar;
        enabledExtensionCount   : Cardinal;
        ppEnabledExtensionNames : PPAnsiChar;
        pEnabledFeatures        : PVkPhysicalDeviceFeatures;
    end;
    PVkDeviceCreateInfo = ^VkDeviceCreateInfo;

    VkSwapchainCreateInfoKHR = record
        sType                 : LongInt;
        pNext                 : Pointer;
        flags                 : VkFlags;
        surface               : VkSurfaceKHR;
        minImageCount         : Cardinal;
        imageFormat           : LongInt;
        imageColorSpace       : LongInt;
        imageExtent           : VkExtent2D;
        imageArrayLayers      : Cardinal;
        imageUsage            : VkFlags;
        imageSharingMode      : Cardinal;
        queueFamilyIndexCount : Cardinal;
        pQueueFamilyIndices   : PCardinal;
        preTransform          : Cardinal;
        compositeAlpha        : Cardinal;
        presentMode           : LongInt;
        clipped               : VkBool32;
        oldSwapchain          : VkSwapchainKHR;
    end;
    PVkSwapchainCreateInfoKHR = ^VkSwapchainCreateInfoKHR;

    VkComponentMapping = record
        r : LongInt;
        g : LongInt;
        b : LongInt;
        a : LongInt;
    end;

    VkImageSubresourceRange = record
        aspectMask     : VkFlags;
        baseMipLevel   : Cardinal;
        levelCount     : Cardinal;
        baseArrayLayer : Cardinal;
        layerCount     : Cardinal;
    end;

    VkImageViewCreateInfo = record
        sType            : LongInt;
        pNext            : Pointer;
        flags            : VkFlags;
        image            : VkImage;
        viewType         : LongInt;
        format           : LongInt;
        components       : VkComponentMapping;
        subresourceRange : VkImageSubresourceRange;
    end;
    PVkImageViewCreateInfo = ^VkImageViewCreateInfo;

    VkAttachmentDescription = record
        flags          : VkFlags;
        format         : LongInt;
        samples        : Cardinal;
        loadOp         : LongInt;
        storeOp        : LongInt;
        stencilLoadOp  : LongInt;
        stencilStoreOp : LongInt;
        initialLayout  : LongInt;
        finalLayout    : LongInt;
    end;
    PVkAttachmentDescription = ^VkAttachmentDescription;

    VkAttachmentReference = record
        attachment : Cardinal;
        layout     : LongInt;
    end;
    PVkAttachmentReference = ^VkAttachmentReference;

    VkSubpassDescription = record
        flags                   : VkFlags;
        pipelineBindPoint       : Cardinal;
        inputAttachmentCount    : Cardinal;
        pInputAttachments       : PVkAttachmentReference;
        colorAttachmentCount    : Cardinal;
        pColorAttachments       : PVkAttachmentReference;
        pResolveAttachments     : PVkAttachmentReference;
        pDepthStencilAttachment : PVkAttachmentReference;
        preserveAttachmentCount : Cardinal;
        pPreserveAttachments    : PCardinal;
    end;
    PVkSubpassDescription = ^VkSubpassDescription;

    VkSubpassDependency = record
        srcSubpass      : Cardinal;
        dstSubpass      : Cardinal;
        srcStageMask    : VkFlags;
        dstStageMask    : VkFlags;
        srcAccessMask   : VkFlags;
        dstAccessMask   : VkFlags;
        dependencyFlags : VkFlags;
    end;
    PVkSubpassDependency = ^VkSubpassDependency;

    VkRenderPassCreateInfo = record
        sType           : LongInt;
        pNext           : Pointer;
        flags           : VkFlags;
        attachmentCount : Cardinal;
        pAttachments    : PVkAttachmentDescription;
        subpassCount    : Cardinal;
        pSubpasses      : PVkSubpassDescription;
        dependencyCount : Cardinal;
        pDependencies   : PVkSubpassDependency;
    end;
    PVkRenderPassCreateInfo = ^VkRenderPassCreateInfo;

    VkShaderModuleCreateInfo = record
        sType    : LongInt;
        pNext    : Pointer;
        flags    : VkFlags;
        codeSize : PtrUInt;
        pCode    : PCardinal;
    end;
    PVkShaderModuleCreateInfo = ^VkShaderModuleCreateInfo;

    VkPipelineShaderStageCreateInfo = record
        sType               : LongInt;
        pNext               : Pointer;
        flags               : VkFlags;
        stage               : Cardinal;
        module              : VkShaderModule;
        pName               : PAnsiChar;
        pSpecializationInfo : Pointer;
    end;
    PVkPipelineShaderStageCreateInfo = ^VkPipelineShaderStageCreateInfo;

    VkPipelineVertexInputStateCreateInfo = record
        sType                           : LongInt;
        pNext                           : Pointer;
        flags                           : VkFlags;
        vertexBindingDescriptionCount   : Cardinal;
        pVertexBindingDescriptions      : Pointer;
        vertexAttributeDescriptionCount : Cardinal;
        pVertexAttributeDescriptions    : Pointer;
    end;
    PVkPipelineVertexInputStateCreateInfo = ^VkPipelineVertexInputStateCreateInfo;

    VkPipelineInputAssemblyStateCreateInfo = record
        sType                  : LongInt;
        pNext                  : Pointer;
        flags                  : VkFlags;
        topology               : LongInt;
        primitiveRestartEnable : VkBool32;
    end;
    PVkPipelineInputAssemblyStateCreateInfo = ^VkPipelineInputAssemblyStateCreateInfo;

    VkViewport = record
        x        : Single;
        y        : Single;
        width    : Single;
        height   : Single;
        minDepth : Single;
        maxDepth : Single;
    end;
    PVkViewport = ^VkViewport;

    VkPipelineViewportStateCreateInfo = record
        sType         : LongInt;
        pNext         : Pointer;
        flags         : VkFlags;
        viewportCount : Cardinal;
        pViewports    : PVkViewport;
        scissorCount  : Cardinal;
        pScissors     : PVkRect2D;
    end;
    PVkPipelineViewportStateCreateInfo = ^VkPipelineViewportStateCreateInfo;

    VkPipelineRasterizationStateCreateInfo = record
        sType                   : LongInt;
        pNext                   : Pointer;
        flags                   : VkFlags;
        depthClampEnable        : VkBool32;
        rasterizerDiscardEnable : VkBool32;
        polygonMode             : LongInt;
        cullMode                : VkFlags;
        frontFace               : LongInt;
        depthBiasEnable         : VkBool32;
        depthBiasConstantFactor : Single;
        depthBiasClamp          : Single;
        depthBiasSlopeFactor    : Single;
        lineWidth               : Single;
    end;
    PVkPipelineRasterizationStateCreateInfo = ^VkPipelineRasterizationStateCreateInfo;

    VkPipelineMultisampleStateCreateInfo = record
        sType                 : LongInt;
        pNext                 : Pointer;
        flags                 : VkFlags;
        rasterizationSamples  : Cardinal;
        sampleShadingEnable   : VkBool32;
        minSampleShading      : Single;
        pSampleMask           : Pointer;
        alphaToCoverageEnable : VkBool32;
        alphaToOneEnable      : VkBool32;
    end;
    PVkPipelineMultisampleStateCreateInfo = ^VkPipelineMultisampleStateCreateInfo;

    VkPipelineColorBlendAttachmentState = record
        blendEnable         : VkBool32;
        srcColorBlendFactor : LongInt;
        dstColorBlendFactor : LongInt;
        colorBlendOp        : LongInt;
        srcAlphaBlendFactor : LongInt;
        dstAlphaBlendFactor : LongInt;
        alphaBlendOp        : LongInt;
        colorWriteMask      : VkFlags;
    end;
    PVkPipelineColorBlendAttachmentState = ^VkPipelineColorBlendAttachmentState;

    VkPipelineColorBlendStateCreateInfo = record
        sType           : LongInt;
        pNext           : Pointer;
        flags           : VkFlags;
        logicOpEnable   : VkBool32;
        logicOp         : LongInt;
        attachmentCount : Cardinal;
        pAttachments    : PVkPipelineColorBlendAttachmentState;
        blendConstants  : array[0..3] of Single;
    end;
    PVkPipelineColorBlendStateCreateInfo = ^VkPipelineColorBlendStateCreateInfo;

    VkPipelineLayoutCreateInfo = record
        sType                  : LongInt;
        pNext                  : Pointer;
        flags                  : VkFlags;
        setLayoutCount         : Cardinal;
        pSetLayouts            : Pointer;
        pushConstantRangeCount : Cardinal;
        pPushConstantRanges    : Pointer;
    end;
    PVkPipelineLayoutCreateInfo = ^VkPipelineLayoutCreateInfo;

    VkGraphicsPipelineCreateInfo = record
        sType               : LongInt;
        pNext               : Pointer;
        flags               : VkFlags;
        stageCount          : Cardinal;
        pStages             : PVkPipelineShaderStageCreateInfo;
        pVertexInputState   : PVkPipelineVertexInputStateCreateInfo;
        pInputAssemblyState : PVkPipelineInputAssemblyStateCreateInfo;
        pTessellationState  : Pointer;
        pViewportState      : PVkPipelineViewportStateCreateInfo;
        pRasterizationState : PVkPipelineRasterizationStateCreateInfo;
        pMultisampleState   : PVkPipelineMultisampleStateCreateInfo;
        pDepthStencilState  : Pointer;
        pColorBlendState    : PVkPipelineColorBlendStateCreateInfo;
        pDynamicState       : Pointer;
        layout              : VkPipelineLayout;
        renderPass          : VkRenderPass;
        subpass             : Cardinal;
        basePipelineHandle  : VkPipeline;
        basePipelineIndex   : LongInt;
    end;
    PVkGraphicsPipelineCreateInfo = ^VkGraphicsPipelineCreateInfo;

    VkFramebufferCreateInfo = record
        sType           : LongInt;
        pNext           : Pointer;
        flags           : VkFlags;
        renderPass      : VkRenderPass;
        attachmentCount : Cardinal;
        pAttachments    : PVkImageView;
        width           : Cardinal;
        height          : Cardinal;
        layers          : Cardinal;
    end;
    PVkFramebufferCreateInfo = ^VkFramebufferCreateInfo;

    VkCommandPoolCreateInfo = record
        sType            : LongInt;
        pNext            : Pointer;
        flags            : VkFlags;
        queueFamilyIndex : Cardinal;
    end;
    PVkCommandPoolCreateInfo = ^VkCommandPoolCreateInfo;

    VkCommandBufferAllocateInfo = record
        sType              : LongInt;
        pNext              : Pointer;
        commandPool        : VkCommandPool;
        level              : LongInt;
        commandBufferCount : Cardinal;
    end;
    PVkCommandBufferAllocateInfo = ^VkCommandBufferAllocateInfo;

    VkCommandBufferBeginInfo = record
        sType            : LongInt;
        pNext            : Pointer;
        flags            : VkFlags;
        pInheritanceInfo : Pointer;
    end;
    PVkCommandBufferBeginInfo = ^VkCommandBufferBeginInfo;

    VkClearColorValue = record
        case integer of
            0: (float32 : array[0..3] of Single);
            1: (int32   : array[0..3] of LongInt);
            2: (uint32  : array[0..3] of Cardinal);
    end;

    VkClearDepthStencilValue = record
        depth   : Single;
        stencil : Cardinal;
    end;

    VkClearValue = record
        case integer of
            0: (color        : VkClearColorValue);
            1: (depthStencil : VkClearDepthStencilValue);
    end;
    PVkClearValue = ^VkClearValue;

    VkRenderPassBeginInfo = record
        sType           : LongInt;
        pNext           : Pointer;
        renderPass      : VkRenderPass;
        framebuffer     : VkFramebuffer;
        renderArea      : VkRect2D;
        clearValueCount : Cardinal;
        pClearValues    : PVkClearValue;
    end;
    PVkRenderPassBeginInfo = ^VkRenderPassBeginInfo;

    VkSemaphoreCreateInfo = record
        sType : LongInt;
        pNext : Pointer;
        flags : VkFlags;
    end;
    PVkSemaphoreCreateInfo = ^VkSemaphoreCreateInfo;

    VkFenceCreateInfo = record
        sType : LongInt;
        pNext : Pointer;
        flags : VkFlags;
    end;
    PVkFenceCreateInfo = ^VkFenceCreateInfo;

    VkSubmitInfo = record
        sType                : LongInt;
        pNext                : Pointer;
        waitSemaphoreCount   : Cardinal;
        pWaitSemaphores      : PVkSemaphore;
        pWaitDstStageMask    : PVkFlags;
        commandBufferCount   : Cardinal;
        pCommandBuffers      : PVkCommandBuffer;
        signalSemaphoreCount : Cardinal;
        pSignalSemaphores    : PVkSemaphore;
    end;
    PVkSubmitInfo = ^VkSubmitInfo;

    VkPresentInfoKHR = record
        sType              : LongInt;
        pNext              : Pointer;
        waitSemaphoreCount : Cardinal;
        pWaitSemaphores    : PVkSemaphore;
        swapchainCount     : Cardinal;
        pSwapchains        : PVkSwapchainKHR;
        pImageIndices      : ^Cardinal;
        pResults           : PVkResult;
    end;
    PVkPresentInfoKHR = ^VkPresentInfoKHR;

    QueueFamilyIndices = record
        graphicsFamily         : Cardinal;
        graphicsFamilyHasValue : Boolean;
        presentFamily          : Cardinal;
        presentFamilyHasValue  : Boolean;
    end;

    SwapChainSupportDetails = record
        capabilities     : VkSurfaceCapabilitiesKHR;
        formats          : PVkSurfaceFormatKHR;
        formatCount      : Cardinal;
        presentModes     : PLongInt;
        presentModeCount : Cardinal;
    end;

    PFN_vkCreateDebugUtilsMessengerEXT = function(
        instance    : VkInstance;
        pCreateInfo : PVkDebugUtilsMessengerCreateInfoEXT;
        pAllocator  : Pointer;
        pMessenger  : PVkDebugUtilsMessengerEXT
    ): VkResult; cdecl;

    PFN_vkDestroyDebugUtilsMessengerEXT = procedure(
        instance   : VkInstance;
        messenger  : VkDebugUtilsMessengerEXT;
        pAllocator : Pointer
    ); cdecl;

    PFN_vkVoidFunction = procedure; cdecl;

{ === GLFW external functions === }
function  glfwInit: LongInt; cdecl; external libGLFW;
procedure glfwTerminate; cdecl; external libGLFW;
procedure glfwWindowHint(hint, value: LongInt); cdecl; external libGLFW;
function  glfwCreateWindow(width, height: LongInt; title: PAnsiChar; monitor, share: Pointer): Pointer; cdecl; external libGLFW;
procedure glfwDestroyWindow(window: Pointer); cdecl; external libGLFW;
function  glfwWindowShouldClose(window: Pointer): LongInt; cdecl; external libGLFW;
procedure glfwPollEvents; cdecl; external libGLFW;
procedure glfwWaitEvents; cdecl; external libGLFW;
procedure glfwSetWindowUserPointer(window: Pointer; ptr: Pointer); cdecl; external libGLFW;
function  glfwGetWindowUserPointer(window: Pointer): Pointer; cdecl; external libGLFW;
procedure glfwSetFramebufferSizeCallback(window: Pointer; callback: Pointer); cdecl; external libGLFW;
procedure glfwGetFramebufferSize(window: Pointer; width, height: PLongInt); cdecl; external libGLFW;
function  glfwGetRequiredInstanceExtensions(count: PCardinal): PPAnsiChar; cdecl; external libGLFW;
function  glfwCreateWindowSurface(instance: VkInstance; window: Pointer; allocator: Pointer; surface: PVkSurfaceKHR): VkResult; cdecl; external libGLFW;

{ === Vulkan external functions === }
function  vkCreateInstance(pCreateInfo: PVkInstanceCreateInfo; pAllocator: Pointer; pInstance: PVkInstance): VkResult; cdecl; external libVulkan;
procedure vkDestroyInstance(instance: VkInstance; pAllocator: Pointer); cdecl; external libVulkan;
function  vkGetInstanceProcAddr(instance: VkInstance; pName: PAnsiChar): PFN_vkVoidFunction; cdecl; external libVulkan;
function  vkEnumerateInstanceLayerProperties(pPropertyCount: PCardinal; pProperties: PVkLayerProperties): VkResult; cdecl; external libVulkan;
function  vkEnumeratePhysicalDevices(instance: VkInstance; pPhysicalDeviceCount: PCardinal; pPhysicalDevices: PVkPhysicalDevice): VkResult; cdecl; external libVulkan;
procedure vkGetPhysicalDeviceQueueFamilyProperties(physicalDevice: VkPhysicalDevice; pQueueFamilyPropertyCount: PCardinal; pQueueFamilyProperties: PVkQueueFamilyProperties); cdecl; external libVulkan;
function  vkGetPhysicalDeviceSurfaceSupportKHR(physicalDevice: VkPhysicalDevice; queueFamilyIndex: Cardinal; surface: VkSurfaceKHR; pSupported: PVkBool32): VkResult; cdecl; external libVulkan;
function  vkEnumerateDeviceExtensionProperties(physicalDevice: VkPhysicalDevice; pLayerName: PAnsiChar; pPropertyCount: PCardinal; pProperties: PVkExtensionProperties): VkResult; cdecl; external libVulkan;
function  vkGetPhysicalDeviceSurfaceCapabilitiesKHR(physicalDevice: VkPhysicalDevice; surface: VkSurfaceKHR; pSurfaceCapabilities: PVkSurfaceCapabilitiesKHR): VkResult; cdecl; external libVulkan;
function  vkGetPhysicalDeviceSurfaceFormatsKHR(physicalDevice: VkPhysicalDevice; surface: VkSurfaceKHR; pSurfaceFormatCount: PCardinal; pSurfaceFormats: PVkSurfaceFormatKHR): VkResult; cdecl; external libVulkan;
function  vkGetPhysicalDeviceSurfacePresentModesKHR(physicalDevice: VkPhysicalDevice; surface: VkSurfaceKHR; pPresentModeCount: PCardinal; pPresentModes: PLongInt): VkResult; cdecl; external libVulkan;
function  vkCreateDevice(physicalDevice: VkPhysicalDevice; pCreateInfo: PVkDeviceCreateInfo; pAllocator: Pointer; pDevice: PVkDevice): VkResult; cdecl; external libVulkan;
procedure vkDestroyDevice(device: VkDevice; pAllocator: Pointer); cdecl; external libVulkan;
procedure vkGetDeviceQueue(device: VkDevice; queueFamilyIndex: Cardinal; queueIndex: Cardinal; pQueue: PVkQueue); cdecl; external libVulkan;
function  vkCreateSwapchainKHR(device: VkDevice; pCreateInfo: PVkSwapchainCreateInfoKHR; pAllocator: Pointer; pSwapchain: PVkSwapchainKHR): VkResult; cdecl; external libVulkan;
procedure vkDestroySwapchainKHR(device: VkDevice; swapchain: VkSwapchainKHR; pAllocator: Pointer); cdecl; external libVulkan;
function  vkGetSwapchainImagesKHR(device: VkDevice; swapchain: VkSwapchainKHR; pSwapchainImageCount: PCardinal; pSwapchainImages: PVkImage): VkResult; cdecl; external libVulkan;
function  vkCreateImageView(device: VkDevice; pCreateInfo: PVkImageViewCreateInfo; pAllocator: Pointer; pView: PVkImageView): VkResult; cdecl; external libVulkan;
procedure vkDestroyImageView(device: VkDevice; imageView: VkImageView; pAllocator: Pointer); cdecl; external libVulkan;
function  vkCreateRenderPass(device: VkDevice; pCreateInfo: PVkRenderPassCreateInfo; pAllocator: Pointer; pRenderPass: PVkRenderPass): VkResult; cdecl; external libVulkan;
procedure vkDestroyRenderPass(device: VkDevice; renderPass: VkRenderPass; pAllocator: Pointer); cdecl; external libVulkan;
function  vkCreateShaderModule(device: VkDevice; pCreateInfo: PVkShaderModuleCreateInfo; pAllocator: Pointer; pShaderModule: PVkShaderModule): VkResult; cdecl; external libVulkan;
procedure vkDestroyShaderModule(device: VkDevice; shaderModule: VkShaderModule; pAllocator: Pointer); cdecl; external libVulkan;
function  vkCreatePipelineLayout(device: VkDevice; pCreateInfo: PVkPipelineLayoutCreateInfo; pAllocator: Pointer; pPipelineLayout: PVkPipelineLayout): VkResult; cdecl; external libVulkan;
procedure vkDestroyPipelineLayout(device: VkDevice; pipelineLayout: VkPipelineLayout; pAllocator: Pointer); cdecl; external libVulkan;
function  vkCreateGraphicsPipelines(device: VkDevice; pipelineCache: VkPipelineCache; createInfoCount: Cardinal; pCreateInfos: PVkGraphicsPipelineCreateInfo; pAllocator: Pointer; pPipelines: PVkPipeline): VkResult; cdecl; external libVulkan;
procedure vkDestroyPipeline(device: VkDevice; pipeline: VkPipeline; pAllocator: Pointer); cdecl; external libVulkan;
function  vkCreateFramebuffer(device: VkDevice; pCreateInfo: PVkFramebufferCreateInfo; pAllocator: Pointer; pFramebuffer: PVkFramebuffer): VkResult; cdecl; external libVulkan;
procedure vkDestroyFramebuffer(device: VkDevice; framebuffer: VkFramebuffer; pAllocator: Pointer); cdecl; external libVulkan;
function  vkCreateCommandPool(device: VkDevice; pCreateInfo: PVkCommandPoolCreateInfo; pAllocator: Pointer; pCommandPool: PVkCommandPool): VkResult; cdecl; external libVulkan;
procedure vkDestroyCommandPool(device: VkDevice; commandPool: VkCommandPool; pAllocator: Pointer); cdecl; external libVulkan;
function  vkAllocateCommandBuffers(device: VkDevice; pAllocateInfo: PVkCommandBufferAllocateInfo; pCommandBuffers: PVkCommandBuffer): VkResult; cdecl; external libVulkan;
procedure vkFreeCommandBuffers(device: VkDevice; commandPool: VkCommandPool; commandBufferCount: Cardinal; pCommandBuffers: PVkCommandBuffer); cdecl; external libVulkan;
function  vkBeginCommandBuffer(commandBuffer: VkCommandBuffer; pBeginInfo: PVkCommandBufferBeginInfo): VkResult; cdecl; external libVulkan;
function  vkEndCommandBuffer(commandBuffer: VkCommandBuffer): VkResult; cdecl; external libVulkan;
procedure vkCmdBeginRenderPass(commandBuffer: VkCommandBuffer; pRenderPassBegin: PVkRenderPassBeginInfo; contents: LongInt); cdecl; external libVulkan;
procedure vkCmdBindPipeline(commandBuffer: VkCommandBuffer; pipelineBindPoint: LongInt; pipeline: VkPipeline); cdecl; external libVulkan;
procedure vkCmdDraw(commandBuffer: VkCommandBuffer; vertexCount, instanceCount, firstVertex, firstInstance: Cardinal); cdecl; external libVulkan;
procedure vkCmdEndRenderPass(commandBuffer: VkCommandBuffer); cdecl; external libVulkan;
function  vkCreateSemaphore(device: VkDevice; pCreateInfo: PVkSemaphoreCreateInfo; pAllocator: Pointer; pSemaphore: PVkSemaphore): VkResult; cdecl; external libVulkan;
procedure vkDestroySemaphore(device: VkDevice; semaphore: VkSemaphore; pAllocator: Pointer); cdecl; external libVulkan;
function  vkCreateFence(device: VkDevice; pCreateInfo: PVkFenceCreateInfo; pAllocator: Pointer; pFence: PVkFence): VkResult; cdecl; external libVulkan;
procedure vkDestroyFence(device: VkDevice; fence: VkFence; pAllocator: Pointer); cdecl; external libVulkan;
function  vkWaitForFences(device: VkDevice; fenceCount: Cardinal; pFences: PVkFence; waitAll: VkBool32; timeout: UInt64): VkResult; cdecl; external libVulkan;
function  vkResetFences(device: VkDevice; fenceCount: Cardinal; pFences: PVkFence): VkResult; cdecl; external libVulkan;
function  vkAcquireNextImageKHR(device: VkDevice; swapchain: VkSwapchainKHR; timeout: UInt64; semaphore: VkSemaphore; fence: VkFence; pImageIndex: PCardinal): VkResult; cdecl; external libVulkan;
function  vkQueueSubmit(queue: VkQueue; submitCount: Cardinal; pSubmits: PVkSubmitInfo; fence: VkFence): VkResult; cdecl; external libVulkan;
function  vkQueuePresentKHR(queue: VkQueue; pPresentInfo: PVkPresentInfoKHR): VkResult; cdecl; external libVulkan;
function  vkDeviceWaitIdle(device: VkDevice): VkResult; cdecl; external libVulkan;
procedure vkDestroySurfaceKHR(instance: VkInstance; surface: VkSurfaceKHR; pAllocator: Pointer); cdecl; external libVulkan;

var
    gWindow           : Pointer;
    gInstance         : VkInstance;
    gDebugMessenger   : VkDebugUtilsMessengerEXT;
    gSurface          : VkSurfaceKHR;
    gPhysicalDevice   : VkPhysicalDevice;
    gDevice           : VkDevice;
    gGraphicsQueue    : VkQueue;
    gPresentQueue     : VkQueue;
    gSwapChain        : VkSwapchainKHR;
    gSwapChainImages  : PVkImage;
    gSwapChainImageCount  : Cardinal;
    gSwapChainImageFormat : LongInt;
    gSwapChainExtent      : VkExtent2D;
    gSwapChainImageViews  : PVkImageView;
    gSwapChainFramebuffers: PVkFramebuffer;
    gRenderPass       : VkRenderPass;
    gPipelineLayout   : VkPipelineLayout;
    gGraphicsPipeline : VkPipeline;
    gCommandPool      : VkCommandPool;
    gCommandBuffers   : PVkCommandBuffer;
    gImageAvailableSemaphores: array[0..MAX_FRAMES_IN_FLIGHT-1] of VkSemaphore;
    gRenderFinishedSemaphores: array[0..MAX_FRAMES_IN_FLIGHT-1] of VkSemaphore;
    gInFlightFences          : array[0..MAX_FRAMES_IN_FLIGHT-1] of VkFence;
    gImagesInFlight   : PVkFence;
    gCurrentFrame     : SizeUInt;
    gFramebufferResized: Boolean;

{ === Debug callback === }
function debugCallback(
    messageSeverity : Cardinal;
    messageType     : Cardinal;
    pCallbackData   : PVkDebugUtilsMessengerCallbackDataEXT;
    pUserData       : Pointer): VkBool32; cdecl;
begin
    WriteLn(StdErr, 'validation layer: ', pCallbackData^.pMessage);
    Result := VK_FALSE;
end;

procedure populateDebugMessengerCreateInfo(var info: VkDebugUtilsMessengerCreateInfoEXT);
begin
    FillChar(info, SizeOf(info), 0);
    info.sType           := VK_STRUCTURE_TYPE_DEBUG_UTILS_MESSENGER_CREATE_INFO_EXT;
    info.messageSeverity := VK_DEBUG_UTILS_MESSAGE_SEVERITY_VERBOSE_BIT_EXT
                          or VK_DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT
                          or VK_DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT;
    info.messageType     := VK_DEBUG_UTILS_MESSAGE_TYPE_GENERAL_BIT_EXT
                          or VK_DEBUG_UTILS_MESSAGE_TYPE_VALIDATION_BIT_EXT
                          or VK_DEBUG_UTILS_MESSAGE_TYPE_PERFORMANCE_BIT_EXT;
    info.pfnUserCallback := @debugCallback;
end;

function CreateDebugUtilsMessengerEXT(instance: VkInstance;
    pCreateInfo: PVkDebugUtilsMessengerCreateInfoEXT;
    pAllocator: Pointer;
    pDebugMessenger: PVkDebugUtilsMessengerEXT): VkResult;
var
    func: PFN_vkCreateDebugUtilsMessengerEXT;
begin
    func := PFN_vkCreateDebugUtilsMessengerEXT(
        vkGetInstanceProcAddr(instance, 'vkCreateDebugUtilsMessengerEXT'));
    if func <> nil then
        Result := func(instance, pCreateInfo, pAllocator, pDebugMessenger)
    else
        Result := VK_ERROR_EXTENSION_NOT_PRESENT;
end;

procedure DestroyDebugUtilsMessengerEXT(instance: VkInstance;
    messenger: VkDebugUtilsMessengerEXT; pAllocator: Pointer);
var
    func: PFN_vkDestroyDebugUtilsMessengerEXT;
begin
    func := PFN_vkDestroyDebugUtilsMessengerEXT(
        vkGetInstanceProcAddr(instance, 'vkDestroyDebugUtilsMessengerEXT'));
    if func <> nil then
        func(instance, messenger, pAllocator);
end;

{ === Framebuffer resize callback === }
procedure framebufferResizeCallback(window: Pointer; width, height: LongInt); cdecl;
begin
    gFramebufferResized := True;
end;

{ === Validation layer support check === }
function checkValidationLayerSupport: Boolean;
var
    layerCount      : Cardinal;
    availableLayers : PVkLayerProperties;
    i               : Cardinal;
begin
    layerCount := 0;
    vkEnumerateInstanceLayerProperties(@layerCount, nil);
    GetMem(availableLayers, SizeOf(VkLayerProperties) * layerCount);
    vkEnumerateInstanceLayerProperties(@layerCount, availableLayers);
    Result := False;
    for i := 0 to layerCount - 1 do
    begin
        if StrComp(availableLayers[i].layerName, VK_LAYER_KHRONOS_VALIDATION) = 0 then
        begin
            Result := True;
            Break;
        end;
    end;
    FreeMem(availableLayers);
end;

{ === Window initialization === }
procedure initWindow;
begin
    glfwInit;
    glfwWindowHint(GLFW_CLIENT_API, GLFW_NO_API);
    gWindow := glfwCreateWindow(WIDTH, HEIGHT, 'Hello, Pascal World!', nil, nil);
    glfwSetWindowUserPointer(gWindow, nil);
    glfwSetFramebufferSizeCallback(gWindow, @framebufferResizeCallback);
end;

{ === Vulkan instance creation === }
procedure createInstance;
var
    appInfo          : VkApplicationInfo;
    createInfo       : VkInstanceCreateInfo;
    debugCreateInfo  : VkDebugUtilsMessengerCreateInfoEXT;
    glfwExtCount     : Cardinal;
    glfwExts         : PPAnsiChar;
    extensions       : PPAnsiChar;
    total            : Cardinal;
    layers           : PPAnsiChar;
    layerName        : PAnsiChar;
    extDebug         : PAnsiChar;
begin
    if ENABLE_VALIDATION_LAYERS and not checkValidationLayerSupport then
    begin
        WriteLn(StdErr, 'validation layers requested, but not available!');
        Halt(1);
    end;

    FillChar(appInfo, SizeOf(appInfo), 0);
    appInfo.sType              := VK_STRUCTURE_TYPE_APPLICATION_INFO;
    appInfo.pApplicationName   := 'Hello Triangle';
    appInfo.applicationVersion := Cardinal((1 shl 22) or (0 shl 12) or 0);
    appInfo.pEngineName        := 'No Engine';
    appInfo.engineVersion      := Cardinal((1 shl 22) or (0 shl 12) or 0);
    appInfo.apiVersion         := Cardinal((1 shl 22) or (0 shl 12) or 0);

    glfwExtCount := 0;
    glfwExts := glfwGetRequiredInstanceExtensions(@glfwExtCount);
    if ENABLE_VALIDATION_LAYERS then
        total := glfwExtCount + 1
    else
        total := glfwExtCount;
    GetMem(extensions, SizeOf(PAnsiChar) * total);
    Move(glfwExts^, extensions^, SizeOf(PAnsiChar) * glfwExtCount);
    if ENABLE_VALIDATION_LAYERS then
    begin
        extDebug := VK_EXT_DEBUG_UTILS_EXTENSION_NAME;
        extensions[glfwExtCount] := extDebug;
    end;

    FillChar(createInfo, SizeOf(createInfo), 0);
    createInfo.sType                   := VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO;
    createInfo.pApplicationInfo        := @appInfo;
    createInfo.enabledExtensionCount   := total;
    createInfo.ppEnabledExtensionNames := extensions;

    if ENABLE_VALIDATION_LAYERS then
    begin
        populateDebugMessengerCreateInfo(debugCreateInfo);
        layerName := VK_LAYER_KHRONOS_VALIDATION;
        GetMem(layers, SizeOf(PAnsiChar));
        layers[0] := layerName;
        createInfo.enabledLayerCount   := 1;
        createInfo.ppEnabledLayerNames := layers;
        createInfo.pNext               := @debugCreateInfo;
    end
    else
    begin
        layers := nil;
        createInfo.enabledLayerCount := 0;
    end;

    if vkCreateInstance(@createInfo, nil, @gInstance) <> VK_SUCCESS then
    begin
        WriteLn(StdErr, 'failed to create instance!');
        FreeMem(extensions);
        if layers <> nil then FreeMem(layers);
        Halt(1);
    end;
    FreeMem(extensions);
    if layers <> nil then FreeMem(layers);
end;

procedure setupDebugMessenger;
var
    createInfo: VkDebugUtilsMessengerCreateInfoEXT;
begin
    if not ENABLE_VALIDATION_LAYERS then Exit;
    populateDebugMessengerCreateInfo(createInfo);
    if CreateDebugUtilsMessengerEXT(gInstance, @createInfo, nil, @gDebugMessenger) <> VK_SUCCESS then
    begin
        WriteLn(StdErr, 'failed to set up debug messenger!');
        Halt(1);
    end;
end;

procedure createSurface;
begin
    if glfwCreateWindowSurface(gInstance, gWindow, nil, @gSurface) <> VK_SUCCESS then
    begin
        WriteLn(StdErr, 'failed to create window surface!');
        Halt(1);
    end;
end;

{ === Queue family and swap chain helpers === }
function findQueueFamilies(physDev: VkPhysicalDevice): QueueFamilyIndices;
var
    indices          : QueueFamilyIndices;
    queueFamilyCount : Cardinal;
    queueFamilies    : PVkQueueFamilyProperties;
    i                : Cardinal;
    presentSupport   : VkBool32;
begin
    FillChar(indices, SizeOf(indices), 0);
    queueFamilyCount := 0;
    vkGetPhysicalDeviceQueueFamilyProperties(physDev, @queueFamilyCount, nil);
    GetMem(queueFamilies, SizeOf(VkQueueFamilyProperties) * queueFamilyCount);
    vkGetPhysicalDeviceQueueFamilyProperties(physDev, @queueFamilyCount, queueFamilies);
    for i := 0 to queueFamilyCount - 1 do
    begin
        if (queueFamilies[i].queueFlags and VK_QUEUE_GRAPHICS_BIT) <> 0 then
        begin
            indices.graphicsFamily := i;
            indices.graphicsFamilyHasValue := True;
        end;
        presentSupport := VK_FALSE;
        vkGetPhysicalDeviceSurfaceSupportKHR(physDev, i, gSurface, @presentSupport);
        if presentSupport <> 0 then
        begin
            indices.presentFamily := i;
            indices.presentFamilyHasValue := True;
        end;
        if indices.graphicsFamilyHasValue and indices.presentFamilyHasValue then Break;
    end;
    FreeMem(queueFamilies);
    Result := indices;
end;

function checkDeviceExtensionSupport(physDev: VkPhysicalDevice): Boolean;
var
    extCount  : Cardinal;
    available : PVkExtensionProperties;
    i         : Cardinal;
    needed    : PAnsiChar;
begin
    extCount := 0;
    vkEnumerateDeviceExtensionProperties(physDev, nil, @extCount, nil);
    GetMem(available, SizeOf(VkExtensionProperties) * extCount);
    vkEnumerateDeviceExtensionProperties(physDev, nil, @extCount, available);
    Result := False;
    needed := VK_KHR_SWAPCHAIN_EXTENSION_NAME;
    for i := 0 to extCount - 1 do
    begin
        if StrComp(available[i].extensionName, needed) = 0 then
        begin
            Result := True;
            Break;
        end;
    end;
    FreeMem(available);
end;

function querySwapChainSupport(physDev: VkPhysicalDevice): SwapChainSupportDetails;
var
    details      : SwapChainSupportDetails;
    formatCount  : Cardinal;
    presentCount : Cardinal;
begin
    FillChar(details, SizeOf(details), 0);
    vkGetPhysicalDeviceSurfaceCapabilitiesKHR(physDev, gSurface, @details.capabilities);

    formatCount := 0;
    vkGetPhysicalDeviceSurfaceFormatsKHR(physDev, gSurface, @formatCount, nil);
    if formatCount > 0 then
    begin
        GetMem(details.formats, SizeOf(VkSurfaceFormatKHR) * formatCount);
        vkGetPhysicalDeviceSurfaceFormatsKHR(physDev, gSurface, @formatCount, details.formats);
        details.formatCount := formatCount;
    end;

    presentCount := 0;
    vkGetPhysicalDeviceSurfacePresentModesKHR(physDev, gSurface, @presentCount, nil);
    if presentCount > 0 then
    begin
        GetMem(details.presentModes, SizeOf(LongInt) * presentCount);
        vkGetPhysicalDeviceSurfacePresentModesKHR(physDev, gSurface, @presentCount, details.presentModes);
        details.presentModeCount := presentCount;
    end;
    Result := details;
end;

procedure freeSwapChainSupportDetails(var details: SwapChainSupportDetails);
begin
    if details.formats <> nil then FreeMem(details.formats);
    if details.presentModes <> nil then FreeMem(details.presentModes);
    FillChar(details, SizeOf(details), 0);
end;

function isDeviceSuitable(physDev: VkPhysicalDevice): Boolean;
var
    indices  : QueueFamilyIndices;
    extOk    : Boolean;
    support  : SwapChainSupportDetails;
    scOk     : Boolean;
begin
    indices := findQueueFamilies(physDev);
    extOk   := checkDeviceExtensionSupport(physDev);
    scOk    := False;
    if extOk then
    begin
        support := querySwapChainSupport(physDev);
        scOk    := (support.formatCount > 0) and (support.presentModeCount > 0);
        freeSwapChainSupportDetails(support);
    end;
    Result := indices.graphicsFamilyHasValue and indices.presentFamilyHasValue and extOk and scOk;
end;

procedure pickPhysicalDevice;
var
    deviceCount : Cardinal;
    devices     : ^VkPhysicalDevice;
    i           : Cardinal;
begin
    deviceCount := 0;
    vkEnumeratePhysicalDevices(gInstance, @deviceCount, nil);
    if deviceCount = 0 then
    begin
        WriteLn(StdErr, 'failed to find GPUs with Vulkan support!');
        Halt(1);
    end;
    GetMem(devices, SizeOf(VkPhysicalDevice) * deviceCount);
    vkEnumeratePhysicalDevices(gInstance, @deviceCount, devices);
    gPhysicalDevice := nil;
    for i := 0 to deviceCount - 1 do
    begin
        if isDeviceSuitable(devices[i]) then
        begin
            gPhysicalDevice := devices[i];
            Break;
        end;
    end;
    FreeMem(devices);
    if gPhysicalDevice = nil then
    begin
        WriteLn(StdErr, 'failed to find a suitable GPU!');
        Halt(1);
    end;
end;

procedure createLogicalDevice;
var
    indices        : QueueFamilyIndices;
    uniqueFamilies : array[0..1] of Cardinal;
    uniqueCount    : Cardinal;
    queuePriority  : Single;
    queueInfos     : array[0..1] of VkDeviceQueueCreateInfo;
    deviceFeatures : VkPhysicalDeviceFeatures;
    createInfo     : VkDeviceCreateInfo;
    layers         : PPAnsiChar;
    layerName      : PAnsiChar;
    extName        : PAnsiChar;
    extNames       : PPAnsiChar;
    i              : Cardinal;
begin
    indices := findQueueFamilies(gPhysicalDevice);
    uniqueCount := 0;
    uniqueFamilies[uniqueCount] := indices.graphicsFamily;
    Inc(uniqueCount);
    if indices.presentFamily <> indices.graphicsFamily then
    begin
        uniqueFamilies[uniqueCount] := indices.presentFamily;
        Inc(uniqueCount);
    end;

    queuePriority := 1.0;
    for i := 0 to uniqueCount - 1 do
    begin
        FillChar(queueInfos[i], SizeOf(VkDeviceQueueCreateInfo), 0);
        queueInfos[i].sType            := VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO;
        queueInfos[i].queueFamilyIndex := uniqueFamilies[i];
        queueInfos[i].queueCount       := 1;
        queueInfos[i].pQueuePriorities := @queuePriority;
    end;

    FillChar(deviceFeatures, SizeOf(deviceFeatures), 0);

    extName := VK_KHR_SWAPCHAIN_EXTENSION_NAME;
    GetMem(extNames, SizeOf(PAnsiChar));
    extNames[0] := extName;

    FillChar(createInfo, SizeOf(createInfo), 0);
    createInfo.sType                   := VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO;
    createInfo.queueCreateInfoCount    := uniqueCount;
    createInfo.pQueueCreateInfos       := @queueInfos[0];
    createInfo.pEnabledFeatures        := @deviceFeatures;
    createInfo.enabledExtensionCount   := 1;
    createInfo.ppEnabledExtensionNames := extNames;

    if ENABLE_VALIDATION_LAYERS then
    begin
        layerName := VK_LAYER_KHRONOS_VALIDATION;
        GetMem(layers, SizeOf(PAnsiChar));
        layers[0] := layerName;
        createInfo.enabledLayerCount   := 1;
        createInfo.ppEnabledLayerNames := layers;
    end
    else
    begin
        layers := nil;
        createInfo.enabledLayerCount := 0;
    end;

    if vkCreateDevice(gPhysicalDevice, @createInfo, nil, @gDevice) <> VK_SUCCESS then
    begin
        WriteLn(StdErr, 'failed to create logical device!');
        FreeMem(extNames);
        if layers <> nil then FreeMem(layers);
        Halt(1);
    end;
    FreeMem(extNames);
    if layers <> nil then FreeMem(layers);

    vkGetDeviceQueue(gDevice, indices.graphicsFamily, 0, @gGraphicsQueue);
    vkGetDeviceQueue(gDevice, indices.presentFamily, 0, @gPresentQueue);
end;

{ === Swap chain creation === }
function chooseSwapSurfaceFormat(details: SwapChainSupportDetails): VkSurfaceFormatKHR;
var
    i: Cardinal;
begin
    for i := 0 to details.formatCount - 1 do
    begin
        if (details.formats[i].format = VK_FORMAT_B8G8R8A8_SRGB) and
           (details.formats[i].colorSpace = VK_COLOR_SPACE_SRGB_NONLINEAR_KHR) then
        begin
            Result := details.formats[i];
            Exit;
        end;
    end;
    Result := details.formats[0];
end;

function chooseSwapPresentMode(details: SwapChainSupportDetails): LongInt;
var
    i: Cardinal;
begin
    for i := 0 to details.presentModeCount - 1 do
    begin
        if details.presentModes[i] = VK_PRESENT_MODE_MAILBOX_KHR then
        begin
            Result := VK_PRESENT_MODE_MAILBOX_KHR;
            Exit;
        end;
    end;
    Result := VK_PRESENT_MODE_FIFO_KHR;
end;

function chooseSwapExtent(const caps: VkSurfaceCapabilitiesKHR): VkExtent2D;
var
    w, h   : LongInt;
    actual : VkExtent2D;
begin
    if caps.currentExtent.width <> Cardinal($FFFFFFFF) then
    begin
        Result := caps.currentExtent;
        Exit;
    end;
    glfwGetFramebufferSize(gWindow, @w, @h);
    actual.width  := Cardinal(w);
    actual.height := Cardinal(h);
    if actual.width  < caps.minImageExtent.width  then actual.width  := caps.minImageExtent.width;
    if actual.width  > caps.maxImageExtent.width  then actual.width  := caps.maxImageExtent.width;
    if actual.height < caps.minImageExtent.height then actual.height := caps.minImageExtent.height;
    if actual.height > caps.maxImageExtent.height then actual.height := caps.maxImageExtent.height;
    Result := actual;
end;

procedure createSwapChain;
var
    support       : SwapChainSupportDetails;
    surfaceFormat : VkSurfaceFormatKHR;
    presentMode   : LongInt;
    extent        : VkExtent2D;
    imageCount    : Cardinal;
    createInfo    : VkSwapchainCreateInfoKHR;
    indices       : QueueFamilyIndices;
    queueIndices  : array[0..1] of Cardinal;
begin
    support       := querySwapChainSupport(gPhysicalDevice);
    surfaceFormat := chooseSwapSurfaceFormat(support);
    presentMode   := chooseSwapPresentMode(support);
    extent        := chooseSwapExtent(support.capabilities);

    imageCount := support.capabilities.minImageCount + 1;
    if (support.capabilities.maxImageCount > 0) and (imageCount > support.capabilities.maxImageCount) then
        imageCount := support.capabilities.maxImageCount;

    FillChar(createInfo, SizeOf(createInfo), 0);
    createInfo.sType            := VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR;
    createInfo.surface          := gSurface;
    createInfo.minImageCount    := imageCount;
    createInfo.imageFormat      := surfaceFormat.format;
    createInfo.imageColorSpace  := surfaceFormat.colorSpace;
    createInfo.imageExtent      := extent;
    createInfo.imageArrayLayers := 1;
    createInfo.imageUsage       := VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT;

    indices := findQueueFamilies(gPhysicalDevice);
    queueIndices[0] := indices.graphicsFamily;
    queueIndices[1] := indices.presentFamily;
    if indices.graphicsFamily <> indices.presentFamily then
    begin
        createInfo.imageSharingMode      := VK_SHARING_MODE_CONCURRENT;
        createInfo.queueFamilyIndexCount := 2;
        createInfo.pQueueFamilyIndices   := @queueIndices[0];
    end
    else
    begin
        createInfo.imageSharingMode := VK_SHARING_MODE_EXCLUSIVE;
    end;

    createInfo.preTransform   := support.capabilities.currentTransform;
    createInfo.compositeAlpha := VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR;
    createInfo.presentMode    := presentMode;
    createInfo.clipped        := VK_TRUE;
    createInfo.oldSwapchain   := UInt64(0);

    if vkCreateSwapchainKHR(gDevice, @createInfo, nil, @gSwapChain) <> VK_SUCCESS then
    begin
        freeSwapChainSupportDetails(support);
        WriteLn(StdErr, 'failed to create swap chain!');
        Halt(1);
    end;

    vkGetSwapchainImagesKHR(gDevice, gSwapChain, @imageCount, nil);
    GetMem(gSwapChainImages, SizeOf(VkImage) * imageCount);
    vkGetSwapchainImagesKHR(gDevice, gSwapChain, @imageCount, gSwapChainImages);
    gSwapChainImageCount  := imageCount;
    gSwapChainImageFormat := surfaceFormat.format;
    gSwapChainExtent      := extent;

    freeSwapChainSupportDetails(support);
end;

procedure createImageViews;
var
    i          : Cardinal;
    createInfo : VkImageViewCreateInfo;
begin
    GetMem(gSwapChainImageViews, SizeOf(VkImageView) * gSwapChainImageCount);
    for i := 0 to gSwapChainImageCount - 1 do
    begin
        FillChar(createInfo, SizeOf(createInfo), 0);
        createInfo.sType                           := VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO;
        createInfo.image                           := gSwapChainImages[i];
        createInfo.viewType                        := VK_IMAGE_VIEW_TYPE_2D;
        createInfo.format                          := gSwapChainImageFormat;
        createInfo.components.r                    := VK_COMPONENT_SWIZZLE_IDENTITY;
        createInfo.components.g                    := VK_COMPONENT_SWIZZLE_IDENTITY;
        createInfo.components.b                    := VK_COMPONENT_SWIZZLE_IDENTITY;
        createInfo.components.a                    := VK_COMPONENT_SWIZZLE_IDENTITY;
        createInfo.subresourceRange.aspectMask     := VK_IMAGE_ASPECT_COLOR_BIT;
        createInfo.subresourceRange.baseMipLevel   := 0;
        createInfo.subresourceRange.levelCount     := 1;
        createInfo.subresourceRange.baseArrayLayer := 0;
        createInfo.subresourceRange.layerCount     := 1;
        if vkCreateImageView(gDevice, @createInfo, nil, @gSwapChainImageViews[i]) <> VK_SUCCESS then
        begin
            WriteLn(StdErr, 'failed to create image view!');
            Halt(1);
        end;
    end;
end;

procedure createRenderPass;
var
    colorAttachment    : VkAttachmentDescription;
    colorAttachmentRef : VkAttachmentReference;
    subpass            : VkSubpassDescription;
    dependency         : VkSubpassDependency;
    renderPassInfo     : VkRenderPassCreateInfo;
begin
    FillChar(colorAttachment, SizeOf(colorAttachment), 0);
    colorAttachment.format         := gSwapChainImageFormat;
    colorAttachment.samples        := VK_SAMPLE_COUNT_1_BIT;
    colorAttachment.loadOp         := VK_ATTACHMENT_LOAD_OP_CLEAR;
    colorAttachment.storeOp        := VK_ATTACHMENT_STORE_OP_STORE;
    colorAttachment.stencilLoadOp  := VK_ATTACHMENT_LOAD_OP_DONT_CARE;
    colorAttachment.stencilStoreOp := VK_ATTACHMENT_STORE_OP_DONT_CARE;
    colorAttachment.initialLayout  := VK_IMAGE_LAYOUT_UNDEFINED;
    colorAttachment.finalLayout    := VK_IMAGE_LAYOUT_PRESENT_SRC_KHR;

    colorAttachmentRef.attachment := 0;
    colorAttachmentRef.layout     := VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL;

    FillChar(subpass, SizeOf(subpass), 0);
    subpass.pipelineBindPoint    := VK_PIPELINE_BIND_POINT_GRAPHICS;
    subpass.colorAttachmentCount := 1;
    subpass.pColorAttachments    := @colorAttachmentRef;

    FillChar(dependency, SizeOf(dependency), 0);
    dependency.srcSubpass    := VK_SUBPASS_EXTERNAL;
    dependency.dstSubpass    := 0;
    dependency.srcStageMask  := VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT;
    dependency.dstStageMask  := VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT;
    dependency.dstAccessMask := VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT;

    FillChar(renderPassInfo, SizeOf(renderPassInfo), 0);
    renderPassInfo.sType           := VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO;
    renderPassInfo.attachmentCount := 1;
    renderPassInfo.pAttachments    := @colorAttachment;
    renderPassInfo.subpassCount    := 1;
    renderPassInfo.pSubpasses      := @subpass;
    renderPassInfo.dependencyCount := 1;
    renderPassInfo.pDependencies   := @dependency;

    if vkCreateRenderPass(gDevice, @renderPassInfo, nil, @gRenderPass) <> VK_SUCCESS then
    begin
        WriteLn(StdErr, 'failed to create render pass!');
        Halt(1);
    end;
end;

{ === Shader loading === }
type
    TFileData = record
        data : Pointer;
        size : PtrUInt;
    end;

function readFile(const filename: String): TFileData;
var
    f    : File;
    sz   : Int64;
    buf  : Pointer;
    read : LongInt;
begin
    Assign(f, filename);
    {$I-} Reset(f, 1); {$I+}
    if IOResult <> 0 then
    begin
        WriteLn(StdErr, 'failed to open ', filename);
        Halt(1);
    end;
    sz := FileSize(f);
    GetMem(buf, sz);
    BlockRead(f, buf^, sz, read);
    Close(f);
    if read <> sz then
    begin
        WriteLn(StdErr, 'failed to read ', filename);
        Halt(1);
    end;
    Result.data := buf;
    Result.size := PtrUInt(sz);
end;

function createShaderModule(const code: TFileData): VkShaderModule;
var
    createInfo : VkShaderModuleCreateInfo;
    shModule   : VkShaderModule;
begin
    FillChar(createInfo, SizeOf(createInfo), 0);
    createInfo.sType    := VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO;
    createInfo.codeSize := code.size;
    createInfo.pCode    := PCardinal(code.data);
    if vkCreateShaderModule(gDevice, @createInfo, nil, @shModule) <> VK_SUCCESS then
    begin
        WriteLn(StdErr, 'failed to create shader module!');
        Halt(1);
    end;
    Result := shModule;
end;

procedure createGraphicsPipeline;
var
    vert             : TFileData;
    frag             : TFileData;
    vertModule       : VkShaderModule;
    fragModule       : VkShaderModule;
    stages           : array[0..1] of VkPipelineShaderStageCreateInfo;
    vertexInput      : VkPipelineVertexInputStateCreateInfo;
    inputAssembly    : VkPipelineInputAssemblyStateCreateInfo;
    viewport         : VkViewport;
    scissor          : VkRect2D;
    viewportState    : VkPipelineViewportStateCreateInfo;
    rasterizer       : VkPipelineRasterizationStateCreateInfo;
    multisampling    : VkPipelineMultisampleStateCreateInfo;
    colorBlendAttach : VkPipelineColorBlendAttachmentState;
    colorBlending    : VkPipelineColorBlendStateCreateInfo;
    layoutInfo       : VkPipelineLayoutCreateInfo;
    pipelineInfo     : VkGraphicsPipelineCreateInfo;
    mainName         : PAnsiChar;
begin
    vert := readFile('hello_vert.spv');
    frag := readFile('hello_frag.spv');

    vertModule := createShaderModule(vert);
    fragModule := createShaderModule(frag);

    mainName := 'main';
    FillChar(stages, SizeOf(stages), 0);
    stages[0].sType  := VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO;
    stages[0].stage  := VK_SHADER_STAGE_VERTEX_BIT;
    stages[0].module := vertModule;
    stages[0].pName  := mainName;
    stages[1].sType  := VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO;
    stages[1].stage  := VK_SHADER_STAGE_FRAGMENT_BIT;
    stages[1].module := fragModule;
    stages[1].pName  := mainName;

    FillChar(vertexInput, SizeOf(vertexInput), 0);
    vertexInput.sType := VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO;

    FillChar(inputAssembly, SizeOf(inputAssembly), 0);
    inputAssembly.sType    := VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO;
    inputAssembly.topology := VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST;

    viewport.x        := 0.0;
    viewport.y        := 0.0;
    viewport.width    := gSwapChainExtent.width;
    viewport.height   := gSwapChainExtent.height;
    viewport.minDepth := 0.0;
    viewport.maxDepth := 1.0;

    scissor.offset.x      := 0;
    scissor.offset.y      := 0;
    scissor.extent        := gSwapChainExtent;

    FillChar(viewportState, SizeOf(viewportState), 0);
    viewportState.sType         := VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO;
    viewportState.viewportCount := 1;
    viewportState.pViewports    := @viewport;
    viewportState.scissorCount  := 1;
    viewportState.pScissors     := @scissor;

    FillChar(rasterizer, SizeOf(rasterizer), 0);
    rasterizer.sType       := VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO;
    rasterizer.polygonMode := VK_POLYGON_MODE_FILL;
    rasterizer.cullMode    := VK_CULL_MODE_BACK_BIT;
    rasterizer.frontFace   := VK_FRONT_FACE_CLOCKWISE;
    rasterizer.lineWidth   := 1.0;

    FillChar(multisampling, SizeOf(multisampling), 0);
    multisampling.sType                := VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO;
    multisampling.rasterizationSamples := VK_SAMPLE_COUNT_1_BIT;

    FillChar(colorBlendAttach, SizeOf(colorBlendAttach), 0);
    colorBlendAttach.colorWriteMask := VK_COLOR_COMPONENT_R_BIT or VK_COLOR_COMPONENT_G_BIT
                                    or VK_COLOR_COMPONENT_B_BIT or VK_COLOR_COMPONENT_A_BIT;

    FillChar(colorBlending, SizeOf(colorBlending), 0);
    colorBlending.sType           := VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO;
    colorBlending.attachmentCount := 1;
    colorBlending.pAttachments    := @colorBlendAttach;

    FillChar(layoutInfo, SizeOf(layoutInfo), 0);
    layoutInfo.sType := VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO;

    if vkCreatePipelineLayout(gDevice, @layoutInfo, nil, @gPipelineLayout) <> VK_SUCCESS then
    begin
        WriteLn(StdErr, 'failed to create pipeline layout!');
        Halt(1);
    end;

    FillChar(pipelineInfo, SizeOf(pipelineInfo), 0);
    pipelineInfo.sType               := VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO;
    pipelineInfo.stageCount          := 2;
    pipelineInfo.pStages             := @stages[0];
    pipelineInfo.pVertexInputState   := @vertexInput;
    pipelineInfo.pInputAssemblyState := @inputAssembly;
    pipelineInfo.pViewportState      := @viewportState;
    pipelineInfo.pRasterizationState := @rasterizer;
    pipelineInfo.pMultisampleState   := @multisampling;
    pipelineInfo.pColorBlendState    := @colorBlending;
    pipelineInfo.layout              := gPipelineLayout;
    pipelineInfo.renderPass          := gRenderPass;
    pipelineInfo.subpass             := 0;

    if vkCreateGraphicsPipelines(gDevice, UInt64(0), 1, @pipelineInfo, nil, @gGraphicsPipeline) <> VK_SUCCESS then
    begin
        WriteLn(StdErr, 'failed to create graphics pipeline!');
        Halt(1);
    end;

    vkDestroyShaderModule(gDevice, fragModule, nil);
    vkDestroyShaderModule(gDevice, vertModule, nil);
    FreeMem(vert.data);
    FreeMem(frag.data);
end;

procedure createFramebuffers;
var
    i    : Cardinal;
    info : VkFramebufferCreateInfo;
    att  : VkImageView;
begin
    GetMem(gSwapChainFramebuffers, SizeOf(VkFramebuffer) * gSwapChainImageCount);
    for i := 0 to gSwapChainImageCount - 1 do
    begin
        att := gSwapChainImageViews[i];
        FillChar(info, SizeOf(info), 0);
        info.sType           := VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO;
        info.renderPass      := gRenderPass;
        info.attachmentCount := 1;
        info.pAttachments    := @att;
        info.width           := gSwapChainExtent.width;
        info.height          := gSwapChainExtent.height;
        info.layers          := 1;
        if vkCreateFramebuffer(gDevice, @info, nil, @gSwapChainFramebuffers[i]) <> VK_SUCCESS then
        begin
            WriteLn(StdErr, 'failed to create framebuffer!');
            Halt(1);
        end;
    end;
end;

procedure createCommandPool;
var
    indices : QueueFamilyIndices;
    info    : VkCommandPoolCreateInfo;
begin
    indices := findQueueFamilies(gPhysicalDevice);
    FillChar(info, SizeOf(info), 0);
    info.sType            := VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO;
    info.queueFamilyIndex := indices.graphicsFamily;
    if vkCreateCommandPool(gDevice, @info, nil, @gCommandPool) <> VK_SUCCESS then
    begin
        WriteLn(StdErr, 'failed to create command pool!');
        Halt(1);
    end;
end;

procedure createCommandBuffers;
var
    alloc  : VkCommandBufferAllocateInfo;
    i      : Cardinal;
    begin_ : VkCommandBufferBeginInfo;
    rp     : VkRenderPassBeginInfo;
    clear  : VkClearValue;
begin
    GetMem(gCommandBuffers, SizeOf(VkCommandBuffer) * gSwapChainImageCount);

    FillChar(alloc, SizeOf(alloc), 0);
    alloc.sType              := VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO;
    alloc.commandPool        := gCommandPool;
    alloc.level              := VK_COMMAND_BUFFER_LEVEL_PRIMARY;
    alloc.commandBufferCount := gSwapChainImageCount;
    if vkAllocateCommandBuffers(gDevice, @alloc, gCommandBuffers) <> VK_SUCCESS then
    begin
        WriteLn(StdErr, 'failed to allocate command buffers!');
        Halt(1);
    end;

    for i := 0 to gSwapChainImageCount - 1 do
    begin
        FillChar(begin_, SizeOf(begin_), 0);
        begin_.sType := VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO;
        vkBeginCommandBuffer(gCommandBuffers[i], @begin_);

        FillChar(clear, SizeOf(clear), 0);
        clear.color.float32[0] := 0.0;
        clear.color.float32[1] := 0.0;
        clear.color.float32[2] := 0.0;
        clear.color.float32[3] := 1.0;

        FillChar(rp, SizeOf(rp), 0);
        rp.sType               := VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO;
        rp.renderPass          := gRenderPass;
        rp.framebuffer         := gSwapChainFramebuffers[i];
        rp.renderArea.offset.x := 0;
        rp.renderArea.offset.y := 0;
        rp.renderArea.extent   := gSwapChainExtent;
        rp.clearValueCount     := 1;
        rp.pClearValues        := @clear;

        vkCmdBeginRenderPass(gCommandBuffers[i], @rp, VK_SUBPASS_CONTENTS_INLINE);
        vkCmdBindPipeline(gCommandBuffers[i], VK_PIPELINE_BIND_POINT_GRAPHICS, gGraphicsPipeline);
        vkCmdDraw(gCommandBuffers[i], 3, 1, 0, 0);
        vkCmdEndRenderPass(gCommandBuffers[i]);
        vkEndCommandBuffer(gCommandBuffers[i]);
    end;
end;

procedure createSyncObjects;
var
    semInfo   : VkSemaphoreCreateInfo;
    fenceInfo : VkFenceCreateInfo;
    i         : Integer;
begin
    FillChar(semInfo, SizeOf(semInfo), 0);
    semInfo.sType := VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO;
    FillChar(fenceInfo, SizeOf(fenceInfo), 0);
    fenceInfo.sType := VK_STRUCTURE_TYPE_FENCE_CREATE_INFO;
    fenceInfo.flags := VK_FENCE_CREATE_SIGNALED_BIT;

    for i := 0 to MAX_FRAMES_IN_FLIGHT - 1 do
    begin
        if (vkCreateSemaphore(gDevice, @semInfo, nil, @gImageAvailableSemaphores[i]) <> VK_SUCCESS) or
           (vkCreateSemaphore(gDevice, @semInfo, nil, @gRenderFinishedSemaphores[i]) <> VK_SUCCESS) or
           (vkCreateFence(gDevice, @fenceInfo, nil, @gInFlightFences[i]) <> VK_SUCCESS) then
        begin
            WriteLn(StdErr, 'failed to create sync objects!');
            Halt(1);
        end;
    end;
    GetMem(gImagesInFlight, SizeOf(VkFence) * gSwapChainImageCount);
    FillChar(gImagesInFlight^, SizeOf(VkFence) * gSwapChainImageCount, 0);
    gCurrentFrame := 0;
end;

{ === Swap chain recreation === }
procedure recreateSwapChain; forward;

procedure cleanupSwapChain;
var
    i: Cardinal;
begin
    for i := 0 to gSwapChainImageCount - 1 do
    begin
        vkDestroyFramebuffer(gDevice, gSwapChainFramebuffers[i], nil);
        vkDestroyImageView(gDevice, gSwapChainImageViews[i], nil);
    end;
    FreeMem(gSwapChainFramebuffers);
    FreeMem(gSwapChainImageViews);
    FreeMem(gSwapChainImages);

    vkFreeCommandBuffers(gDevice, gCommandPool, gSwapChainImageCount, gCommandBuffers);
    FreeMem(gCommandBuffers);

    vkDestroyPipeline(gDevice, gGraphicsPipeline, nil);
    vkDestroyPipelineLayout(gDevice, gPipelineLayout, nil);
    vkDestroyRenderPass(gDevice, gRenderPass, nil);
    vkDestroySwapchainKHR(gDevice, gSwapChain, nil);
end;

procedure recreateSwapChain;
var
    w, h: LongInt;
begin
    w := 0; h := 0;
    glfwGetFramebufferSize(gWindow, @w, @h);
    while (w = 0) or (h = 0) do
    begin
        glfwGetFramebufferSize(gWindow, @w, @h);
        glfwWaitEvents;
    end;
    vkDeviceWaitIdle(gDevice);

    cleanupSwapChain;

    createSwapChain;
    createImageViews;
    createRenderPass;
    createGraphicsPipeline;
    createFramebuffers;
    createCommandBuffers;
end;

{ === Frame drawing === }
procedure drawFrame;
var
    imageIndex       : Cardinal;
    result_          : VkResult;
    waitSem          : VkSemaphore;
    signalSem        : VkSemaphore;
    waitStage        : VkFlags;
    submitInfo       : VkSubmitInfo;
    cmdBuf           : VkCommandBuffer;
    presentInfo      : VkPresentInfoKHR;
    swapChainHandle  : VkSwapchainKHR;
begin
    vkWaitForFences(gDevice, 1, @gInFlightFences[gCurrentFrame], VK_TRUE, UINT64_MAX);

    imageIndex := 0;
    result_ := vkAcquireNextImageKHR(gDevice, gSwapChain, UINT64_MAX,
        gImageAvailableSemaphores[gCurrentFrame], UInt64(0), @imageIndex);
    if result_ = VK_ERROR_OUT_OF_DATE_KHR then
    begin
        recreateSwapChain;
        Exit;
    end
    else if (result_ <> VK_SUCCESS) and (result_ <> VK_SUBOPTIMAL_KHR) then
    begin
        WriteLn(StdErr, 'failed to acquire swap chain image!');
        Halt(1);
    end;

    if gImagesInFlight[imageIndex] <> 0 then
        vkWaitForFences(gDevice, 1, @gImagesInFlight[imageIndex], VK_TRUE, UINT64_MAX);
    gImagesInFlight[imageIndex] := gInFlightFences[gCurrentFrame];

    waitSem   := gImageAvailableSemaphores[gCurrentFrame];
    signalSem := gRenderFinishedSemaphores[gCurrentFrame];
    waitStage := VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT;
    cmdBuf    := gCommandBuffers[imageIndex];

    FillChar(submitInfo, SizeOf(submitInfo), 0);
    submitInfo.sType                := VK_STRUCTURE_TYPE_SUBMIT_INFO;
    submitInfo.waitSemaphoreCount   := 1;
    submitInfo.pWaitSemaphores      := @waitSem;
    submitInfo.pWaitDstStageMask    := @waitStage;
    submitInfo.commandBufferCount   := 1;
    submitInfo.pCommandBuffers      := @cmdBuf;
    submitInfo.signalSemaphoreCount := 1;
    submitInfo.pSignalSemaphores    := @signalSem;

    vkResetFences(gDevice, 1, @gInFlightFences[gCurrentFrame]);
    if vkQueueSubmit(gGraphicsQueue, 1, @submitInfo, gInFlightFences[gCurrentFrame]) <> VK_SUCCESS then
    begin
        WriteLn(StdErr, 'failed to submit draw command buffer!');
        Halt(1);
    end;

    swapChainHandle := gSwapChain;
    FillChar(presentInfo, SizeOf(presentInfo), 0);
    presentInfo.sType              := VK_STRUCTURE_TYPE_PRESENT_INFO_KHR;
    presentInfo.waitSemaphoreCount := 1;
    presentInfo.pWaitSemaphores    := @signalSem;
    presentInfo.swapchainCount     := 1;
    presentInfo.pSwapchains        := @swapChainHandle;
    presentInfo.pImageIndices      := @imageIndex;

    result_ := vkQueuePresentKHR(gPresentQueue, @presentInfo);
    if (result_ = VK_ERROR_OUT_OF_DATE_KHR) or (result_ = VK_SUBOPTIMAL_KHR) or gFramebufferResized then
    begin
        gFramebufferResized := False;
        recreateSwapChain;
    end
    else if result_ <> VK_SUCCESS then
    begin
        WriteLn(StdErr, 'failed to present swap chain image!');
        Halt(1);
    end;

    gCurrentFrame := (gCurrentFrame + 1) mod MAX_FRAMES_IN_FLIGHT;
end;

{ === Cleanup === }
procedure cleanup;
var
    i: Integer;
begin
    vkDeviceWaitIdle(gDevice);

    for i := 0 to MAX_FRAMES_IN_FLIGHT - 1 do
    begin
        vkDestroySemaphore(gDevice, gRenderFinishedSemaphores[i], nil);
        vkDestroySemaphore(gDevice, gImageAvailableSemaphores[i], nil);
        vkDestroyFence(gDevice, gInFlightFences[i], nil);
    end;

    cleanupSwapChain;

    FreeMem(gImagesInFlight);
    vkDestroyCommandPool(gDevice, gCommandPool, nil);
    vkDestroyDevice(gDevice, nil);

    if ENABLE_VALIDATION_LAYERS then
        DestroyDebugUtilsMessengerEXT(gInstance, gDebugMessenger, nil);

    vkDestroySurfaceKHR(gInstance, gSurface, nil);
    vkDestroyInstance(gInstance, nil);

    glfwDestroyWindow(gWindow);
    glfwTerminate;
end;

{ === Main === }
begin
    SetExceptionMask(GetExceptionMask + [exInvalidOp, exZeroDivide, exOverflow, exUnderflow, exPrecision]);

    initWindow;

    createInstance;
    setupDebugMessenger;
    createSurface;
    pickPhysicalDevice;
    createLogicalDevice;
    createSwapChain;
    createImageViews;
    createRenderPass;
    createGraphicsPipeline;
    createFramebuffers;
    createCommandPool;
    createCommandBuffers;
    createSyncObjects;

    while glfwWindowShouldClose(gWindow) = 0 do
    begin
        glfwPollEvents;
        drawFrame;
    end;
    vkDeviceWaitIdle(gDevice);

    cleanup;
end.
