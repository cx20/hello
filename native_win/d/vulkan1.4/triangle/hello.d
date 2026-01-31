// Vulkan 1.4 Triangle Example in D Language
// Win32 API + Manual Vulkan Bindings
// Compile: dmd hello_vulkan.d -L/SUBSYSTEM:WINDOWS
// Note: Vulkan SDK must be installed

import core.runtime;
import core.stdc.stdio;
import core.stdc.stdlib;
import core.stdc.string;
import core.sys.windows.windows;
import core.sys.windows.windef;
import core.sys.windows.winuser;

// =============================================================================
// Vulkan Type Definitions
// =============================================================================

extern(System) {
    alias VkFlags = uint;
    alias VkBool32 = uint;
    alias VkDeviceSize = ulong;
    alias VkSampleCountFlagBits = uint;

    struct VkInstance_T;
    alias VkInstance = VkInstance_T*;

    struct VkPhysicalDevice_T;
    alias VkPhysicalDevice = VkPhysicalDevice_T*;

    struct VkDevice_T;
    alias VkDevice = VkDevice_T*;

    struct VkQueue_T;
    alias VkQueue = VkQueue_T*;

    struct VkSurfaceKHR_T;
    alias VkSurfaceKHR = VkSurfaceKHR_T*;

    struct VkSwapchainKHR_T;
    alias VkSwapchainKHR = VkSwapchainKHR_T*;

    struct VkImage_T;
    alias VkImage = VkImage_T*;

    struct VkImageView_T;
    alias VkImageView = VkImageView_T*;

    struct VkRenderPass_T;
    alias VkRenderPass = VkRenderPass_T*;

    struct VkPipelineLayout_T;
    alias VkPipelineLayout = VkPipelineLayout_T*;

    struct VkPipeline_T;
    alias VkPipeline = VkPipeline_T*;

    struct VkFramebuffer_T;
    alias VkFramebuffer = VkFramebuffer_T*;

    struct VkCommandPool_T;
    alias VkCommandPool = VkCommandPool_T*;

    struct VkCommandBuffer_T;
    alias VkCommandBuffer = VkCommandBuffer_T*;

    struct VkSemaphore_T;
    alias VkSemaphore = VkSemaphore_T*;

    struct VkFence_T;
    alias VkFence = VkFence_T*;

    struct VkShaderModule_T;
    alias VkShaderModule = VkShaderModule_T*;

    struct VkDebugUtilsMessengerEXT_T;
    alias VkDebugUtilsMessengerEXT = VkDebugUtilsMessengerEXT_T*;

    alias VkResult = int;
    enum : VkResult {
        VK_SUCCESS = 0,
        VK_NOT_READY = 1,
        VK_TIMEOUT = 2,
        VK_EVENT_SET = 3,
        VK_EVENT_RESET = 4,
        VK_INCOMPLETE = 5,
        VK_ERROR_OUT_OF_HOST_MEMORY = -1,
        VK_ERROR_OUT_OF_DEVICE_MEMORY = -2,
        VK_ERROR_INITIALIZATION_FAILED = -3,
        VK_ERROR_DEVICE_LOST = -4,
        VK_ERROR_MEMORY_MAP_FAILED = -5,
        VK_ERROR_LAYER_NOT_PRESENT = -6,
        VK_ERROR_EXTENSION_NOT_PRESENT = -7,
        VK_ERROR_FEATURE_NOT_PRESENT = -8,
        VK_ERROR_INCOMPATIBLE_DRIVER = -9,
        VK_ERROR_TOO_MANY_OBJECTS = -10,
        VK_ERROR_FORMAT_NOT_SUPPORTED = -11,
        VK_ERROR_FRAGMENTED_POOL = -12,
        VK_ERROR_SURFACE_LOST_KHR = -1000000000,
        VK_SUBOPTIMAL_KHR = 1000001003,
        VK_ERROR_OUT_OF_DATE_KHR = -1000001004,
    }

    alias VkStructureType = int;
    enum : VkStructureType {
        VK_STRUCTURE_TYPE_APPLICATION_INFO = 0,
        VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO = 1,
        VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO = 2,
        VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO = 3,
        VK_STRUCTURE_TYPE_SUBMIT_INFO = 4,
        VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO = 5,
        VK_STRUCTURE_TYPE_MAPPED_MEMORY_RANGE = 6,
        VK_STRUCTURE_TYPE_FENCE_CREATE_INFO = 8,
        VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO = 9,
        VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO = 16,
        VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO = 18,
        VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO = 19,
        VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO = 20,
        VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO = 22,
        VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO = 23,
        VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO = 24,
        VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO = 26,
        VK_STRUCTURE_TYPE_PIPELINE_DYNAMIC_STATE_CREATE_INFO = 27,
        VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO = 30,
        VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO = 38,
        VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO = 28,
        VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO = 37,
        VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO = 39,
        VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO = 40,
        VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO = 42,
        VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO = 43,
        VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO = 15,
        VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR = 1000001000,
        VK_STRUCTURE_TYPE_PRESENT_INFO_KHR = 1000001001,
        VK_STRUCTURE_TYPE_WIN32_SURFACE_CREATE_INFO_KHR = 1000009000,
        VK_STRUCTURE_TYPE_DEBUG_UTILS_MESSENGER_CREATE_INFO_EXT = 1000128004,
    }

    alias VkFormat = int;
    enum : VkFormat {
        VK_FORMAT_UNDEFINED = 0,
        VK_FORMAT_B8G8R8A8_SRGB = 50,
        VK_FORMAT_B8G8R8A8_UNORM = 44,
    }

    alias VkColorSpaceKHR = int;
    enum : VkColorSpaceKHR {
        VK_COLOR_SPACE_SRGB_NONLINEAR_KHR = 0,
    }

    alias VkPresentModeKHR = int;
    enum : VkPresentModeKHR {
        VK_PRESENT_MODE_IMMEDIATE_KHR = 0,
        VK_PRESENT_MODE_MAILBOX_KHR = 1,
        VK_PRESENT_MODE_FIFO_KHR = 2,
        VK_PRESENT_MODE_FIFO_RELAXED_KHR = 3,
    }

    alias VkImageUsageFlagBits = uint;
    enum : VkImageUsageFlagBits {
        VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT = 0x00000010,
    }

    alias VkSharingMode = int;
    enum : VkSharingMode {
        VK_SHARING_MODE_EXCLUSIVE = 0,
        VK_SHARING_MODE_CONCURRENT = 1,
    }

    alias VkCompositeAlphaFlagBitsKHR = uint;
    enum : VkCompositeAlphaFlagBitsKHR {
        VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR = 0x00000001,
    }

    alias VkSurfaceTransformFlagBitsKHR = uint;
    enum : VkSurfaceTransformFlagBitsKHR {
        VK_SURFACE_TRANSFORM_IDENTITY_BIT_KHR = 0x00000001,
    }

    alias VkImageViewType = int;
    enum : VkImageViewType {
        VK_IMAGE_VIEW_TYPE_2D = 1,
    }

    alias VkComponentSwizzle = int;
    enum : VkComponentSwizzle {
        VK_COMPONENT_SWIZZLE_IDENTITY = 0,
    }

    alias VkImageAspectFlagBits = uint;
    enum : VkImageAspectFlagBits {
        VK_IMAGE_ASPECT_COLOR_BIT = 0x00000001,
    }

    alias VkAttachmentLoadOp = int;
    enum : VkAttachmentLoadOp {
        VK_ATTACHMENT_LOAD_OP_LOAD = 0,
        VK_ATTACHMENT_LOAD_OP_CLEAR = 1,
        VK_ATTACHMENT_LOAD_OP_DONT_CARE = 2,
    }

    alias VkAttachmentStoreOp = int;
    enum : VkAttachmentStoreOp {
        VK_ATTACHMENT_STORE_OP_STORE = 0,
        VK_ATTACHMENT_STORE_OP_DONT_CARE = 1,
    }

    alias VkImageLayout = int;
    enum : VkImageLayout {
        VK_IMAGE_LAYOUT_UNDEFINED = 0,
        VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL = 2,
        VK_IMAGE_LAYOUT_PRESENT_SRC_KHR = 1000001002,
    }

    alias VkPipelineBindPoint = int;
    enum : VkPipelineBindPoint {
        VK_PIPELINE_BIND_POINT_GRAPHICS = 0,
    }

    alias VkPipelineStageFlagBits = uint;
    enum : VkPipelineStageFlagBits {
        VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT = 0x00000400,
    }

    alias VkAccessFlagBits = uint;
    enum : VkAccessFlagBits {
        VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT = 0x00000100,
    }

    alias VkShaderStageFlagBits = uint;
    enum : VkShaderStageFlagBits {
        VK_SHADER_STAGE_VERTEX_BIT = 0x00000001,
        VK_SHADER_STAGE_FRAGMENT_BIT = 0x00000010,
    }

    alias VkPrimitiveTopology = int;
    enum : VkPrimitiveTopology {
        VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST = 3,
    }

    alias VkPolygonMode = int;
    enum : VkPolygonMode {
        VK_POLYGON_MODE_FILL = 0,
    }

    alias VkCullModeFlagBits = uint;
    enum : VkCullModeFlagBits {
        VK_CULL_MODE_NONE = 0,
        VK_CULL_MODE_BACK_BIT = 0x00000002,
    }

    alias VkFrontFace = int;
    enum : VkFrontFace {
        VK_FRONT_FACE_COUNTER_CLOCKWISE = 0,
        VK_FRONT_FACE_CLOCKWISE = 1,
    }

    alias VkBlendFactor = int;
    enum : VkBlendFactor {
        VK_BLEND_FACTOR_ZERO = 0,
        VK_BLEND_FACTOR_ONE = 1,
    }

    alias VkBlendOp = int;
    enum : VkBlendOp {
        VK_BLEND_OP_ADD = 0,
    }

    alias VkColorComponentFlagBits = uint;
    enum : VkColorComponentFlagBits {
        VK_COLOR_COMPONENT_R_BIT = 0x00000001,
        VK_COLOR_COMPONENT_G_BIT = 0x00000002,
        VK_COLOR_COMPONENT_B_BIT = 0x00000004,
        VK_COLOR_COMPONENT_A_BIT = 0x00000008,
    }

    alias VkDynamicState = int;
    enum : VkDynamicState {
        VK_DYNAMIC_STATE_VIEWPORT = 0,
        VK_DYNAMIC_STATE_SCISSOR = 1,
    }

    alias VkSubpassContents = int;
    enum : VkSubpassContents {
        VK_SUBPASS_CONTENTS_INLINE = 0,
    }

    alias VkCommandBufferLevel = int;
    enum : VkCommandBufferLevel {
        VK_COMMAND_BUFFER_LEVEL_PRIMARY = 0,
    }

    alias VkFenceCreateFlagBits = uint;
    enum : VkFenceCreateFlagBits {
        VK_FENCE_CREATE_SIGNALED_BIT = 0x00000001,
    }

    alias VkQueueFlagBits = uint;
    enum : VkQueueFlagBits {
        VK_QUEUE_GRAPHICS_BIT = 0x00000001,
    }

    alias VkCommandPoolCreateFlagBits = uint;
    enum : VkCommandPoolCreateFlagBits {
        VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT = 0x00000002,
    }

    enum VK_SUBPASS_EXTERNAL = ~0U;
    enum VK_NULL_HANDLE = null;

    alias VkDebugUtilsMessageSeverityFlagBitsEXT = uint;
    enum : VkDebugUtilsMessageSeverityFlagBitsEXT {
        VK_DEBUG_UTILS_MESSAGE_SEVERITY_VERBOSE_BIT_EXT = 0x00000001,
        VK_DEBUG_UTILS_MESSAGE_SEVERITY_INFO_BIT_EXT = 0x00000010,
        VK_DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT = 0x00000100,
        VK_DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT = 0x00001000,
    }

    alias VkDebugUtilsMessageTypeFlagBitsEXT = uint;
    enum : VkDebugUtilsMessageTypeFlagBitsEXT {
        VK_DEBUG_UTILS_MESSAGE_TYPE_GENERAL_BIT_EXT = 0x00000001,
        VK_DEBUG_UTILS_MESSAGE_TYPE_VALIDATION_BIT_EXT = 0x00000002,
        VK_DEBUG_UTILS_MESSAGE_TYPE_PERFORMANCE_BIT_EXT = 0x00000004,
    }
}

// =============================================================================
// Vulkan Structure Definitions
// =============================================================================

extern(System) {
    struct VkExtent2D {
        uint width;
        uint height;
    }

    struct VkExtent3D {
        uint width;
        uint height;
        uint depth;
    }

    struct VkOffset2D {
        int x;
        int y;
    }

    struct VkRect2D {
        VkOffset2D offset;
        VkExtent2D extent;
    }

    struct VkViewport {
        float x;
        float y;
        float width;
        float height;
        float minDepth;
        float maxDepth;
    }

    struct VkClearColorValue {
        float[4] float32;
    }

    struct VkClearValue {
        VkClearColorValue color;
    }

    struct VkApplicationInfo {
        VkStructureType sType = VK_STRUCTURE_TYPE_APPLICATION_INFO;
        const(void)* pNext;
        const(char)* pApplicationName;
        uint applicationVersion;
        const(char)* pEngineName;
        uint engineVersion;
        uint apiVersion;
    }

    struct VkInstanceCreateInfo {
        VkStructureType sType = VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO;
        const(void)* pNext;
        VkFlags flags;
        const(VkApplicationInfo)* pApplicationInfo;
        uint enabledLayerCount;
        const(char*)* ppEnabledLayerNames;
        uint enabledExtensionCount;
        const(char*)* ppEnabledExtensionNames;
    }

    struct VkPhysicalDeviceProperties {
        uint apiVersion;
        uint driverVersion;
        uint vendorID;
        uint deviceID;
        uint deviceType;
        char[256] deviceName;
        ubyte[16] pipelineCacheUUID;
        VkPhysicalDeviceLimits limits;
        VkPhysicalDeviceSparseProperties sparseProperties;
    }

    struct VkPhysicalDeviceLimits {
        uint maxImageDimension1D;
        uint maxImageDimension2D;
        uint maxImageDimension3D;
        uint maxImageDimensionCube;
        uint maxImageArrayLayers;
        uint maxTexelBufferElements;
        uint maxUniformBufferRange;
        uint maxStorageBufferRange;
        uint maxPushConstantsSize;
        uint maxMemoryAllocationCount;
        uint maxSamplerAllocationCount;
        VkDeviceSize bufferImageGranularity;
        VkDeviceSize sparseAddressSpaceSize;
        uint maxBoundDescriptorSets;
        uint maxPerStageDescriptorSamplers;
        uint maxPerStageDescriptorUniformBuffers;
        uint maxPerStageDescriptorStorageBuffers;
        uint maxPerStageDescriptorSampledImages;
        uint maxPerStageDescriptorStorageImages;
        uint maxPerStageDescriptorInputAttachments;
        uint maxPerStageResources;
        uint maxDescriptorSetSamplers;
        uint maxDescriptorSetUniformBuffers;
        uint maxDescriptorSetUniformBuffersDynamic;
        uint maxDescriptorSetStorageBuffers;
        uint maxDescriptorSetStorageBuffersDynamic;
        uint maxDescriptorSetSampledImages;
        uint maxDescriptorSetStorageImages;
        uint maxDescriptorSetInputAttachments;
        uint maxVertexInputAttributes;
        uint maxVertexInputBindings;
        uint maxVertexInputAttributeOffset;
        uint maxVertexInputBindingStride;
        uint maxVertexOutputComponents;
        uint maxTessellationGenerationLevel;
        uint maxTessellationPatchSize;
        uint maxTessellationControlPerVertexInputComponents;
        uint maxTessellationControlPerVertexOutputComponents;
        uint maxTessellationControlPerPatchOutputComponents;
        uint maxTessellationControlTotalOutputComponents;
        uint maxTessellationEvaluationInputComponents;
        uint maxTessellationEvaluationOutputComponents;
        uint maxGeometryShaderInvocations;
        uint maxGeometryInputComponents;
        uint maxGeometryOutputComponents;
        uint maxGeometryOutputVertices;
        uint maxGeometryTotalOutputComponents;
        uint maxFragmentInputComponents;
        uint maxFragmentOutputAttachments;
        uint maxFragmentDualSrcAttachments;
        uint maxFragmentCombinedOutputResources;
        uint maxComputeSharedMemorySize;
        uint[3] maxComputeWorkGroupCount;
        uint maxComputeWorkGroupInvocations;
        uint[3] maxComputeWorkGroupSize;
        uint subPixelPrecisionBits;
        uint subTexelPrecisionBits;
        uint mipmapPrecisionBits;
        uint maxDrawIndexedIndexValue;
        uint maxDrawIndirectCount;
        float maxSamplerLodBias;
        float maxSamplerAnisotropy;
        uint maxViewports;
        uint[2] maxViewportDimensions;
        float[2] viewportBoundsRange;
        uint viewportSubPixelBits;
        size_t minMemoryMapAlignment;
        VkDeviceSize minTexelBufferOffsetAlignment;
        VkDeviceSize minUniformBufferOffsetAlignment;
        VkDeviceSize minStorageBufferOffsetAlignment;
        int minTexelOffset;
        uint maxTexelOffset;
        int minTexelGatherOffset;
        uint maxTexelGatherOffset;
        float minInterpolationOffset;
        float maxInterpolationOffset;
        uint subPixelInterpolationOffsetBits;
        uint maxFramebufferWidth;
        uint maxFramebufferHeight;
        uint maxFramebufferLayers;
        VkSampleCountFlagBits framebufferColorSampleCounts;
        VkSampleCountFlagBits framebufferDepthSampleCounts;
        VkSampleCountFlagBits framebufferStencilSampleCounts;
        VkSampleCountFlagBits framebufferNoAttachmentsSampleCounts;
        uint maxColorAttachments;
        VkSampleCountFlagBits sampledImageColorSampleCounts;
        VkSampleCountFlagBits sampledImageIntegerSampleCounts;
        VkSampleCountFlagBits sampledImageDepthSampleCounts;
        VkSampleCountFlagBits sampledImageStencilSampleCounts;
        VkSampleCountFlagBits storageImageSampleCounts;
        uint maxSampleMaskWords;
        VkBool32 timestampComputeAndGraphics;
        float timestampPeriod;
        uint maxClipDistances;
        uint maxCullDistances;
        uint maxCombinedClipAndCullDistances;
        uint discreteQueuePriorities;
        float[2] pointSizeRange;
        float[2] lineWidthRange;
        float pointSizeGranularity;
        float lineWidthGranularity;
        VkBool32 strictLines;
        VkBool32 standardSampleLocations;
        VkDeviceSize optimalBufferCopyOffsetAlignment;
        VkDeviceSize optimalBufferCopyRowPitchAlignment;
        VkDeviceSize nonCoherentAtomSize;
    }

    struct VkPhysicalDeviceSparseProperties {
        VkBool32 residencyStandard2DBlockShape;
        VkBool32 residencyStandard2DMultisampleBlockShape;
        VkBool32 residencyStandard3DBlockShape;
        VkBool32 residencyAlignedMipSize;
        VkBool32 residencyNonResidentStrict;
    }

    struct VkQueueFamilyProperties {
        VkFlags queueFlags;
        uint queueCount;
        uint timestampValidBits;
        VkExtent3D minImageTransferGranularity;
    }

    struct VkDeviceQueueCreateInfo {
        VkStructureType sType = VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO;
        const(void)* pNext;
        VkFlags flags;
        uint queueFamilyIndex;
        uint queueCount;
        const(float)* pQueuePriorities;
    }

    struct VkPhysicalDeviceFeatures {
        VkBool32 robustBufferAccess;
        VkBool32 fullDrawIndexUint32;
        VkBool32 imageCubeArray;
        VkBool32 independentBlend;
        VkBool32 geometryShader;
        VkBool32 tessellationShader;
        VkBool32 sampleRateShading;
        VkBool32 dualSrcBlend;
        VkBool32 logicOp;
        VkBool32 multiDrawIndirect;
        VkBool32 drawIndirectFirstInstance;
        VkBool32 depthClamp;
        VkBool32 depthBiasClamp;
        VkBool32 fillModeNonSolid;
        VkBool32 depthBounds;
        VkBool32 wideLines;
        VkBool32 largePoints;
        VkBool32 alphaToOne;
        VkBool32 multiViewport;
        VkBool32 samplerAnisotropy;
        VkBool32 textureCompressionETC2;
        VkBool32 textureCompressionASTC_LDR;
        VkBool32 textureCompressionBC;
        VkBool32 occlusionQueryPrecise;
        VkBool32 pipelineStatisticsQuery;
        VkBool32 vertexPipelineStoresAndAtomics;
        VkBool32 fragmentStoresAndAtomics;
        VkBool32 shaderTessellationAndGeometryPointSize;
        VkBool32 shaderImageGatherExtended;
        VkBool32 shaderStorageImageExtendedFormats;
        VkBool32 shaderStorageImageMultisample;
        VkBool32 shaderStorageImageReadWithoutFormat;
        VkBool32 shaderStorageImageWriteWithoutFormat;
        VkBool32 shaderUniformBufferArrayDynamicIndexing;
        VkBool32 shaderSampledImageArrayDynamicIndexing;
        VkBool32 shaderStorageBufferArrayDynamicIndexing;
        VkBool32 shaderStorageImageArrayDynamicIndexing;
        VkBool32 shaderClipDistance;
        VkBool32 shaderCullDistance;
        VkBool32 shaderFloat64;
        VkBool32 shaderInt64;
        VkBool32 shaderInt16;
        VkBool32 shaderResourceResidency;
        VkBool32 shaderResourceMinLod;
        VkBool32 sparseBinding;
        VkBool32 sparseResidencyBuffer;
        VkBool32 sparseResidencyImage2D;
        VkBool32 sparseResidencyImage3D;
        VkBool32 sparseResidency2Samples;
        VkBool32 sparseResidency4Samples;
        VkBool32 sparseResidency8Samples;
        VkBool32 sparseResidency16Samples;
        VkBool32 sparseResidencyAliased;
        VkBool32 variableMultisampleRate;
        VkBool32 inheritedQueries;
    }

    struct VkDeviceCreateInfo {
        VkStructureType sType = VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO;
        const(void)* pNext;
        VkFlags flags;
        uint queueCreateInfoCount;
        const(VkDeviceQueueCreateInfo)* pQueueCreateInfos;
        uint enabledLayerCount;
        const(char*)* ppEnabledLayerNames;
        uint enabledExtensionCount;
        const(char*)* ppEnabledExtensionNames;
        const(VkPhysicalDeviceFeatures)* pEnabledFeatures;
    }

    struct VkSurfaceCapabilitiesKHR {
        uint minImageCount;
        uint maxImageCount;
        VkExtent2D currentExtent;
        VkExtent2D minImageExtent;
        VkExtent2D maxImageExtent;
        uint maxImageArrayLayers;
        VkFlags supportedTransforms;
        VkSurfaceTransformFlagBitsKHR currentTransform;
        VkFlags supportedCompositeAlpha;
        VkFlags supportedUsageFlags;
    }

    struct VkSurfaceFormatKHR {
        VkFormat format;
        VkColorSpaceKHR colorSpace;
    }

    struct VkSwapchainCreateInfoKHR {
        VkStructureType sType = VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR;
        const(void)* pNext;
        VkFlags flags;
        VkSurfaceKHR surface;
        uint minImageCount;
        VkFormat imageFormat;
        VkColorSpaceKHR imageColorSpace;
        VkExtent2D imageExtent;
        uint imageArrayLayers;
        VkFlags imageUsage;
        VkSharingMode imageSharingMode;
        uint queueFamilyIndexCount;
        const(uint)* pQueueFamilyIndices;
        VkSurfaceTransformFlagBitsKHR preTransform;
        VkCompositeAlphaFlagBitsKHR compositeAlpha;
        VkPresentModeKHR presentMode;
        VkBool32 clipped;
        VkSwapchainKHR oldSwapchain;
    }

    struct VkComponentMapping {
        VkComponentSwizzle r;
        VkComponentSwizzle g;
        VkComponentSwizzle b;
        VkComponentSwizzle a;
    }

    struct VkImageSubresourceRange {
        VkFlags aspectMask;
        uint baseMipLevel;
        uint levelCount;
        uint baseArrayLayer;
        uint layerCount;
    }

    struct VkImageViewCreateInfo {
        VkStructureType sType = VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO;
        const(void)* pNext;
        VkFlags flags;
        VkImage image;
        VkImageViewType viewType;
        VkFormat format;
        VkComponentMapping components;
        VkImageSubresourceRange subresourceRange;
    }

    struct VkAttachmentDescription {
        VkFlags flags;
        VkFormat format;
        VkSampleCountFlagBits samples;
        VkAttachmentLoadOp loadOp;
        VkAttachmentStoreOp storeOp;
        VkAttachmentLoadOp stencilLoadOp;
        VkAttachmentStoreOp stencilStoreOp;
        VkImageLayout initialLayout;
        VkImageLayout finalLayout;
    }

    struct VkAttachmentReference {
        uint attachment;
        VkImageLayout layout;
    }

    struct VkSubpassDescription {
        VkFlags flags;
        VkPipelineBindPoint pipelineBindPoint;
        uint inputAttachmentCount;
        const(VkAttachmentReference)* pInputAttachments;
        uint colorAttachmentCount;
        const(VkAttachmentReference)* pColorAttachments;
        const(VkAttachmentReference)* pResolveAttachments;
        const(VkAttachmentReference)* pDepthStencilAttachment;
        uint preserveAttachmentCount;
        const(uint)* pPreserveAttachments;
    }

    struct VkSubpassDependency {
        uint srcSubpass;
        uint dstSubpass;
        VkFlags srcStageMask;
        VkFlags dstStageMask;
        VkFlags srcAccessMask;
        VkFlags dstAccessMask;
        VkFlags dependencyFlags;
    }

    struct VkRenderPassCreateInfo {
        VkStructureType sType = VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO;
        const(void)* pNext;
        VkFlags flags;
        uint attachmentCount;
        const(VkAttachmentDescription)* pAttachments;
        uint subpassCount;
        const(VkSubpassDescription)* pSubpasses;
        uint dependencyCount;
        const(VkSubpassDependency)* pDependencies;
    }

    struct VkShaderModuleCreateInfo {
        VkStructureType sType = VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO;
        const(void)* pNext;
        VkFlags flags;
        size_t codeSize;
        const(uint)* pCode;
    }

    struct VkPipelineShaderStageCreateInfo {
        VkStructureType sType = VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO;
        const(void)* pNext;
        VkFlags flags;
        VkShaderStageFlagBits stage;
        VkShaderModule _module;
        const(char)* pName;
        const(void)* pSpecializationInfo;
    }

    struct VkPipelineVertexInputStateCreateInfo {
        VkStructureType sType = VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO;
        const(void)* pNext;
        VkFlags flags;
        uint vertexBindingDescriptionCount;
        const(void)* pVertexBindingDescriptions;
        uint vertexAttributeDescriptionCount;
        const(void)* pVertexAttributeDescriptions;
    }

    struct VkPipelineInputAssemblyStateCreateInfo {
        VkStructureType sType = VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO;
        const(void)* pNext;
        VkFlags flags;
        VkPrimitiveTopology topology;
        VkBool32 primitiveRestartEnable;
    }

    struct VkPipelineViewportStateCreateInfo {
        VkStructureType sType = VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO;
        const(void)* pNext;
        VkFlags flags;
        uint viewportCount;
        const(VkViewport)* pViewports;
        uint scissorCount;
        const(VkRect2D)* pScissors;
    }

    struct VkPipelineRasterizationStateCreateInfo {
        VkStructureType sType = VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO;
        const(void)* pNext;
        VkFlags flags;
        VkBool32 depthClampEnable;
        VkBool32 rasterizerDiscardEnable;
        VkPolygonMode polygonMode;
        VkCullModeFlagBits cullMode;
        VkFrontFace frontFace;
        VkBool32 depthBiasEnable;
        float depthBiasConstantFactor;
        float depthBiasClamp;
        float depthBiasSlopeFactor;
        float lineWidth;
    }

    struct VkPipelineMultisampleStateCreateInfo {
        VkStructureType sType = VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO;
        const(void)* pNext;
        VkFlags flags;
        VkSampleCountFlagBits rasterizationSamples;
        VkBool32 sampleShadingEnable;
        float minSampleShading;
        const(uint)* pSampleMask;
        VkBool32 alphaToCoverageEnable;
        VkBool32 alphaToOneEnable;
    }

    struct VkPipelineColorBlendAttachmentState {
        VkBool32 blendEnable;
        VkBlendFactor srcColorBlendFactor;
        VkBlendFactor dstColorBlendFactor;
        VkBlendOp colorBlendOp;
        VkBlendFactor srcAlphaBlendFactor;
        VkBlendFactor dstAlphaBlendFactor;
        VkBlendOp alphaBlendOp;
        VkFlags colorWriteMask;
    }

    struct VkPipelineColorBlendStateCreateInfo {
        VkStructureType sType = VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO;
        const(void)* pNext;
        VkFlags flags;
        VkBool32 logicOpEnable;
        int logicOp;
        uint attachmentCount;
        const(VkPipelineColorBlendAttachmentState)* pAttachments;
        float[4] blendConstants;
    }

    struct VkPipelineDynamicStateCreateInfo {
        VkStructureType sType = VK_STRUCTURE_TYPE_PIPELINE_DYNAMIC_STATE_CREATE_INFO;
        const(void)* pNext;
        VkFlags flags;
        uint dynamicStateCount;
        const(VkDynamicState)* pDynamicStates;
    }

    struct VkPipelineLayoutCreateInfo {
        VkStructureType sType = VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO;
        const(void)* pNext;
        VkFlags flags;
        uint setLayoutCount;
        const(void)* pSetLayouts;
        uint pushConstantRangeCount;
        const(void)* pPushConstantRanges;
    }

    struct VkGraphicsPipelineCreateInfo {
        VkStructureType sType = VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO;
        const(void)* pNext;
        VkFlags flags;
        uint stageCount;
        const(VkPipelineShaderStageCreateInfo)* pStages;
        const(VkPipelineVertexInputStateCreateInfo)* pVertexInputState;
        const(VkPipelineInputAssemblyStateCreateInfo)* pInputAssemblyState;
        const(void)* pTessellationState;
        const(VkPipelineViewportStateCreateInfo)* pViewportState;
        const(VkPipelineRasterizationStateCreateInfo)* pRasterizationState;
        const(VkPipelineMultisampleStateCreateInfo)* pMultisampleState;
        const(void)* pDepthStencilState;
        const(VkPipelineColorBlendStateCreateInfo)* pColorBlendState;
        const(VkPipelineDynamicStateCreateInfo)* pDynamicState;
        VkPipelineLayout layout;
        VkRenderPass renderPass;
        uint subpass;
        VkPipeline basePipelineHandle;
        int basePipelineIndex;
    }

    struct VkFramebufferCreateInfo {
        VkStructureType sType = VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO;
        const(void)* pNext;
        VkFlags flags;
        VkRenderPass renderPass;
        uint attachmentCount;
        const(VkImageView)* pAttachments;
        uint width;
        uint height;
        uint layers;
    }

    struct VkCommandPoolCreateInfo {
        VkStructureType sType = VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO;
        const(void)* pNext;
        VkFlags flags;
        uint queueFamilyIndex;
    }

    struct VkCommandBufferAllocateInfo {
        VkStructureType sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO;
        const(void)* pNext;
        VkCommandPool commandPool;
        VkCommandBufferLevel level;
        uint commandBufferCount;
    }

    struct VkCommandBufferBeginInfo {
        VkStructureType sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO;
        const(void)* pNext;
        VkFlags flags;
        const(void)* pInheritanceInfo;
    }

    struct VkRenderPassBeginInfo {
        VkStructureType sType = VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO;
        const(void)* pNext;
        VkRenderPass renderPass;
        VkFramebuffer framebuffer;
        VkRect2D renderArea;
        uint clearValueCount;
        const(VkClearValue)* pClearValues;
    }

    struct VkSemaphoreCreateInfo {
        VkStructureType sType = VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO;
        const(void)* pNext;
        VkFlags flags;
    }

    struct VkFenceCreateInfo {
        VkStructureType sType = VK_STRUCTURE_TYPE_FENCE_CREATE_INFO;
        const(void)* pNext;
        VkFlags flags;
    }

    struct VkSubmitInfo {
        VkStructureType sType = VK_STRUCTURE_TYPE_SUBMIT_INFO;
        const(void)* pNext;
        uint waitSemaphoreCount;
        const(VkSemaphore)* pWaitSemaphores;
        const(VkFlags)* pWaitDstStageMask;
        uint commandBufferCount;
        const(VkCommandBuffer)* pCommandBuffers;
        uint signalSemaphoreCount;
        const(VkSemaphore)* pSignalSemaphores;
    }

    struct VkPresentInfoKHR {
        VkStructureType sType = VK_STRUCTURE_TYPE_PRESENT_INFO_KHR;
        const(void)* pNext;
        uint waitSemaphoreCount;
        const(VkSemaphore)* pWaitSemaphores;
        uint swapchainCount;
        const(VkSwapchainKHR)* pSwapchains;
        const(uint)* pImageIndices;
        VkResult* pResults;
    }

    struct VkWin32SurfaceCreateInfoKHR {
        VkStructureType sType = VK_STRUCTURE_TYPE_WIN32_SURFACE_CREATE_INFO_KHR;
        const(void)* pNext;
        VkFlags flags;
        HINSTANCE hinstance;
        HWND hwnd;
    }

    struct VkDebugUtilsMessengerCallbackDataEXT {
        VkStructureType sType;
        const(void)* pNext;
        VkFlags flags;
        const(char)* pMessageIdName;
        int messageIdNumber;
        const(char)* pMessage;
        uint queueLabelCount;
        const(void)* pQueueLabels;
        uint cmdBufLabelCount;
        const(void)* pCmdBufLabels;
        uint objectCount;
        const(void)* pObjects;
    }

    alias PFN_vkDebugUtilsMessengerCallbackEXT = extern(System) VkBool32 function(
        VkDebugUtilsMessageSeverityFlagBitsEXT messageSeverity,
        VkDebugUtilsMessageTypeFlagBitsEXT messageTypes,
        const(VkDebugUtilsMessengerCallbackDataEXT)* pCallbackData,
        void* pUserData) nothrow;

    struct VkDebugUtilsMessengerCreateInfoEXT {
        VkStructureType sType = VK_STRUCTURE_TYPE_DEBUG_UTILS_MESSENGER_CREATE_INFO_EXT;
        const(void)* pNext;
        VkFlags flags;
        VkFlags messageSeverity;
        VkFlags messageType;
        PFN_vkDebugUtilsMessengerCallbackEXT pfnUserCallback;
        void* pUserData;
    }

    struct VkLayerProperties {
        char[256] layerName;
        uint specVersion;
        uint implementationVersion;
        char[256] description;
    }

    struct VkExtensionProperties {
        char[256] extensionName;
        uint specVersion;
    }
}

// =============================================================================
// Vulkan Function Prototypes
// =============================================================================

extern(System) {
    // Instance functions
    alias PFN_vkCreateInstance = VkResult function(const(VkInstanceCreateInfo)*, const(void)*, VkInstance*);
    alias PFN_vkDestroyInstance = void function(VkInstance, const(void)*);
    alias PFN_vkEnumeratePhysicalDevices = VkResult function(VkInstance, uint*, VkPhysicalDevice*);
    alias PFN_vkGetPhysicalDeviceProperties = void function(VkPhysicalDevice, VkPhysicalDeviceProperties*);
    alias PFN_vkGetPhysicalDeviceQueueFamilyProperties = void function(VkPhysicalDevice, uint*, VkQueueFamilyProperties*);
    alias PFN_vkCreateDevice = VkResult function(VkPhysicalDevice, const(VkDeviceCreateInfo)*, const(void)*, VkDevice*);
    alias PFN_vkDestroyDevice = void function(VkDevice, const(void)*);
    alias PFN_vkGetDeviceQueue = void function(VkDevice, uint, uint, VkQueue*);
    alias PFN_vkEnumerateInstanceLayerProperties = VkResult function(uint*, VkLayerProperties*);
    alias PFN_vkEnumerateDeviceExtensionProperties = VkResult function(VkPhysicalDevice, const(char)*, uint*, VkExtensionProperties*);
    alias PFN_vkGetInstanceProcAddr = void* function(VkInstance, const(char)*);
    alias PFN_vkGetDeviceProcAddr = void* function(VkDevice, const(char)*);

    // Surface functions
    alias PFN_vkDestroySurfaceKHR = void function(VkInstance, VkSurfaceKHR, const(void)*);
    alias PFN_vkGetPhysicalDeviceSurfaceSupportKHR = VkResult function(VkPhysicalDevice, uint, VkSurfaceKHR, VkBool32*);
    alias PFN_vkGetPhysicalDeviceSurfaceCapabilitiesKHR = VkResult function(VkPhysicalDevice, VkSurfaceKHR, VkSurfaceCapabilitiesKHR*);
    alias PFN_vkGetPhysicalDeviceSurfaceFormatsKHR = VkResult function(VkPhysicalDevice, VkSurfaceKHR, uint*, VkSurfaceFormatKHR*);
    alias PFN_vkGetPhysicalDeviceSurfacePresentModesKHR = VkResult function(VkPhysicalDevice, VkSurfaceKHR, uint*, VkPresentModeKHR*);
    alias PFN_vkCreateWin32SurfaceKHR = VkResult function(VkInstance, const(VkWin32SurfaceCreateInfoKHR)*, const(void)*, VkSurfaceKHR*);

    // Swapchain functions
    alias PFN_vkCreateSwapchainKHR = VkResult function(VkDevice, const(VkSwapchainCreateInfoKHR)*, const(void)*, VkSwapchainKHR*);
    alias PFN_vkDestroySwapchainKHR = void function(VkDevice, VkSwapchainKHR, const(void)*);
    alias PFN_vkGetSwapchainImagesKHR = VkResult function(VkDevice, VkSwapchainKHR, uint*, VkImage*);
    alias PFN_vkAcquireNextImageKHR = VkResult function(VkDevice, VkSwapchainKHR, ulong, VkSemaphore, VkFence, uint*);
    alias PFN_vkQueuePresentKHR = VkResult function(VkQueue, const(VkPresentInfoKHR)*);

    // Image view & render pass functions
    alias PFN_vkCreateImageView = VkResult function(VkDevice, const(VkImageViewCreateInfo)*, const(void)*, VkImageView*);
    alias PFN_vkDestroyImageView = void function(VkDevice, VkImageView, const(void)*);
    alias PFN_vkCreateRenderPass = VkResult function(VkDevice, const(VkRenderPassCreateInfo)*, const(void)*, VkRenderPass*);
    alias PFN_vkDestroyRenderPass = void function(VkDevice, VkRenderPass, const(void)*);

    // Pipeline functions
    alias PFN_vkCreateShaderModule = VkResult function(VkDevice, const(VkShaderModuleCreateInfo)*, const(void)*, VkShaderModule*);
    alias PFN_vkDestroyShaderModule = void function(VkDevice, VkShaderModule, const(void)*);
    alias PFN_vkCreatePipelineLayout = VkResult function(VkDevice, const(VkPipelineLayoutCreateInfo)*, const(void)*, VkPipelineLayout*);
    alias PFN_vkDestroyPipelineLayout = void function(VkDevice, VkPipelineLayout, const(void)*);
    alias PFN_vkCreateGraphicsPipelines = VkResult function(VkDevice, void*, uint, const(VkGraphicsPipelineCreateInfo)*, const(void)*, VkPipeline*);
    alias PFN_vkDestroyPipeline = void function(VkDevice, VkPipeline, const(void)*);

    // Framebuffer functions
    alias PFN_vkCreateFramebuffer = VkResult function(VkDevice, const(VkFramebufferCreateInfo)*, const(void)*, VkFramebuffer*);
    alias PFN_vkDestroyFramebuffer = void function(VkDevice, VkFramebuffer, const(void)*);

    // Command buffer functions
    alias PFN_vkCreateCommandPool = VkResult function(VkDevice, const(VkCommandPoolCreateInfo)*, const(void)*, VkCommandPool*);
    alias PFN_vkDestroyCommandPool = void function(VkDevice, VkCommandPool, const(void)*);
    alias PFN_vkAllocateCommandBuffers = VkResult function(VkDevice, const(VkCommandBufferAllocateInfo)*, VkCommandBuffer*);
    alias PFN_vkFreeCommandBuffers = void function(VkDevice, VkCommandPool, uint, const(VkCommandBuffer)*);
    alias PFN_vkBeginCommandBuffer = VkResult function(VkCommandBuffer, const(VkCommandBufferBeginInfo)*);
    alias PFN_vkEndCommandBuffer = VkResult function(VkCommandBuffer);
    alias PFN_vkResetCommandBuffer = VkResult function(VkCommandBuffer, VkFlags);
    alias PFN_vkCmdBeginRenderPass = void function(VkCommandBuffer, const(VkRenderPassBeginInfo)*, VkSubpassContents);
    alias PFN_vkCmdEndRenderPass = void function(VkCommandBuffer);
    alias PFN_vkCmdBindPipeline = void function(VkCommandBuffer, VkPipelineBindPoint, VkPipeline);
    alias PFN_vkCmdSetViewport = void function(VkCommandBuffer, uint, uint, const(VkViewport)*);
    alias PFN_vkCmdSetScissor = void function(VkCommandBuffer, uint, uint, const(VkRect2D)*);
    alias PFN_vkCmdDraw = void function(VkCommandBuffer, uint, uint, uint, uint);

    // Synchronization objects
    alias PFN_vkCreateSemaphore = VkResult function(VkDevice, const(VkSemaphoreCreateInfo)*, const(void)*, VkSemaphore*);
    alias PFN_vkDestroySemaphore = void function(VkDevice, VkSemaphore, const(void)*);
    alias PFN_vkCreateFence = VkResult function(VkDevice, const(VkFenceCreateInfo)*, const(void)*, VkFence*);
    alias PFN_vkDestroyFence = void function(VkDevice, VkFence, const(void)*);
    alias PFN_vkWaitForFences = VkResult function(VkDevice, uint, const(VkFence)*, VkBool32, ulong);
    alias PFN_vkResetFences = VkResult function(VkDevice, uint, const(VkFence)*);

    // Queue functions
    alias PFN_vkQueueSubmit = VkResult function(VkQueue, uint, const(VkSubmitInfo)*, VkFence);
    alias PFN_vkDeviceWaitIdle = VkResult function(VkDevice);

    // Debug functions
    alias PFN_vkCreateDebugUtilsMessengerEXT = VkResult function(VkInstance, const(VkDebugUtilsMessengerCreateInfoEXT)*, const(void)*, VkDebugUtilsMessengerEXT*);
    alias PFN_vkDestroyDebugUtilsMessengerEXT = void function(VkInstance, VkDebugUtilsMessengerEXT, const(void)*);
}

// =============================================================================
// Global Function Pointers
// =============================================================================

__gshared {
    PFN_vkCreateInstance vkCreateInstance;
    PFN_vkDestroyInstance vkDestroyInstance;
    PFN_vkEnumeratePhysicalDevices vkEnumeratePhysicalDevices;
    PFN_vkGetPhysicalDeviceProperties vkGetPhysicalDeviceProperties;
    PFN_vkGetPhysicalDeviceQueueFamilyProperties vkGetPhysicalDeviceQueueFamilyProperties;
    PFN_vkCreateDevice vkCreateDevice;
    PFN_vkDestroyDevice vkDestroyDevice;
    PFN_vkGetDeviceQueue vkGetDeviceQueue;
    PFN_vkEnumerateInstanceLayerProperties vkEnumerateInstanceLayerProperties;
    PFN_vkEnumerateDeviceExtensionProperties vkEnumerateDeviceExtensionProperties;
    PFN_vkGetInstanceProcAddr vkGetInstanceProcAddr;
    PFN_vkGetDeviceProcAddr vkGetDeviceProcAddr;

    PFN_vkDestroySurfaceKHR vkDestroySurfaceKHR;
    PFN_vkGetPhysicalDeviceSurfaceSupportKHR vkGetPhysicalDeviceSurfaceSupportKHR;
    PFN_vkGetPhysicalDeviceSurfaceCapabilitiesKHR vkGetPhysicalDeviceSurfaceCapabilitiesKHR;
    PFN_vkGetPhysicalDeviceSurfaceFormatsKHR vkGetPhysicalDeviceSurfaceFormatsKHR;
    PFN_vkGetPhysicalDeviceSurfacePresentModesKHR vkGetPhysicalDeviceSurfacePresentModesKHR;
    PFN_vkCreateWin32SurfaceKHR vkCreateWin32SurfaceKHR;

    PFN_vkCreateSwapchainKHR vkCreateSwapchainKHR;
    PFN_vkDestroySwapchainKHR vkDestroySwapchainKHR;
    PFN_vkGetSwapchainImagesKHR vkGetSwapchainImagesKHR;
    PFN_vkAcquireNextImageKHR vkAcquireNextImageKHR;
    PFN_vkQueuePresentKHR vkQueuePresentKHR;

    PFN_vkCreateImageView vkCreateImageView;
    PFN_vkDestroyImageView vkDestroyImageView;
    PFN_vkCreateRenderPass vkCreateRenderPass;
    PFN_vkDestroyRenderPass vkDestroyRenderPass;

    PFN_vkCreateShaderModule vkCreateShaderModule;
    PFN_vkDestroyShaderModule vkDestroyShaderModule;
    PFN_vkCreatePipelineLayout vkCreatePipelineLayout;
    PFN_vkDestroyPipelineLayout vkDestroyPipelineLayout;
    PFN_vkCreateGraphicsPipelines vkCreateGraphicsPipelines;
    PFN_vkDestroyPipeline vkDestroyPipeline;

    PFN_vkCreateFramebuffer vkCreateFramebuffer;
    PFN_vkDestroyFramebuffer vkDestroyFramebuffer;

    PFN_vkCreateCommandPool vkCreateCommandPool;
    PFN_vkDestroyCommandPool vkDestroyCommandPool;
    PFN_vkAllocateCommandBuffers vkAllocateCommandBuffers;
    PFN_vkFreeCommandBuffers vkFreeCommandBuffers;
    PFN_vkBeginCommandBuffer vkBeginCommandBuffer;
    PFN_vkEndCommandBuffer vkEndCommandBuffer;
    PFN_vkResetCommandBuffer vkResetCommandBuffer;
    PFN_vkCmdBeginRenderPass vkCmdBeginRenderPass;
    PFN_vkCmdEndRenderPass vkCmdEndRenderPass;
    PFN_vkCmdBindPipeline vkCmdBindPipeline;
    PFN_vkCmdSetViewport vkCmdSetViewport;
    PFN_vkCmdSetScissor vkCmdSetScissor;
    PFN_vkCmdDraw vkCmdDraw;

    PFN_vkCreateSemaphore vkCreateSemaphore;
    PFN_vkDestroySemaphore vkDestroySemaphore;
    PFN_vkCreateFence vkCreateFence;
    PFN_vkDestroyFence vkDestroyFence;
    PFN_vkWaitForFences vkWaitForFences;
    PFN_vkResetFences vkResetFences;

    PFN_vkQueueSubmit vkQueueSubmit;
    PFN_vkDeviceWaitIdle vkDeviceWaitIdle;

    PFN_vkCreateDebugUtilsMessengerEXT vkCreateDebugUtilsMessengerEXT;
    PFN_vkDestroyDebugUtilsMessengerEXT vkDestroyDebugUtilsMessengerEXT;
}

// =============================================================================
// Constants
// =============================================================================

enum WIDTH = 800;
enum HEIGHT = 600;
enum MAX_FRAMES_IN_FLIGHT = 2;
enum bool ENABLE_VALIDATION = true;

// =============================================================================
// Application Structure
// =============================================================================

struct App {
    HWND hwnd;
    HINSTANCE hInstance;

    VkInstance instance;
    VkDebugUtilsMessengerEXT debugMessenger;
    VkSurfaceKHR surface;
    VkPhysicalDevice physicalDevice;
    VkDevice device;
    VkQueue graphicsQueue;
    VkQueue presentQueue;
    uint graphicsFamily;
    uint presentFamily;

    VkSwapchainKHR swapChain;
    VkImage[] swapChainImages;
    VkFormat swapChainImageFormat;
    VkExtent2D swapChainExtent;
    VkImageView[] swapChainImageViews;
    VkFramebuffer[] swapChainFramebuffers;

    VkRenderPass renderPass;
    VkPipelineLayout pipelineLayout;
    VkPipeline graphicsPipeline;

    VkCommandPool commandPool;
    VkCommandBuffer[] commandBuffers;

    VkSemaphore[MAX_FRAMES_IN_FLIGHT] imageAvailableSemaphores;
    VkSemaphore[MAX_FRAMES_IN_FLIGHT] renderFinishedSemaphores;
    VkFence[MAX_FRAMES_IN_FLIGHT] inFlightFences;
    size_t currentFrame;

    bool framebufferResized;
}

__gshared App gApp;
__gshared HMODULE gVulkanDLL;

// =============================================================================
// SPIR-V Shaders (Pre-compiled Bytecode)
// =============================================================================

// Vertex shader (compiled from hello.vert)
static immutable uint[] vertShaderCode = [
    0x07230203, 0x00010000, 0x0008000b, 0x00000036, 0x00000000, 0x00020011,
    0x00000001, 0x0006000b, 0x00000001, 0x4c534c47, 0x6474732e, 0x3035342e,
    0x00000000, 0x0003000e, 0x00000000, 0x00000001, 0x0008000f, 0x00000000,
    0x00000004, 0x6e69616d, 0x00000000, 0x00000022, 0x00000026, 0x00000031,
    0x00030003, 0x00000002, 0x000001c2, 0x00040005, 0x00000004, 0x6e69616d,
    0x00000000, 0x00050005, 0x0000000c, 0x69736f70, 0x6e6f6974, 0x00000073,
    0x00040005, 0x00000017, 0x6f6c6f63, 0x00007372, 0x00060005, 0x00000020,
    0x505f6c67, 0x65567265, 0x78657472, 0x00000000, 0x00060006, 0x00000020,
    0x00000000, 0x505f6c67, 0x7469736f, 0x006e6f69, 0x00070006, 0x00000020,
    0x00000001, 0x505f6c67, 0x746e696f, 0x657a6953, 0x00000000, 0x00070006,
    0x00000020, 0x00000002, 0x435f6c67, 0x4470696c, 0x61747369, 0x0065636e,
    0x00070006, 0x00000020, 0x00000003, 0x435f6c67, 0x446c6c75, 0x61747369,
    0x0065636e, 0x00030005, 0x00000022, 0x00000000, 0x00060005, 0x00000026,
    0x565f6c67, 0x65747265, 0x646e4978, 0x00007865, 0x00050005, 0x00000031,
    0x67617266, 0x6f6c6f43, 0x00000072, 0x00050048, 0x00000020, 0x00000000,
    0x0000000b, 0x00000000, 0x00050048, 0x00000020, 0x00000001, 0x0000000b,
    0x00000001, 0x00050048, 0x00000020, 0x00000002, 0x0000000b, 0x00000003,
    0x00050048, 0x00000020, 0x00000003, 0x0000000b, 0x00000004, 0x00030047,
    0x00000020, 0x00000002, 0x00040047, 0x00000026, 0x0000000b, 0x0000002a,
    0x00040047, 0x00000031, 0x0000001e, 0x00000000, 0x00020013, 0x00000002,
    0x00030021, 0x00000003, 0x00000002, 0x00030016, 0x00000006, 0x00000020,
    0x00040017, 0x00000007, 0x00000006, 0x00000002, 0x00040015, 0x00000008,
    0x00000020, 0x00000000, 0x0004002b, 0x00000008, 0x00000009, 0x00000003,
    0x0004001c, 0x0000000a, 0x00000007, 0x00000009, 0x00040020, 0x0000000b,
    0x00000006, 0x0000000a, 0x0004003b, 0x0000000b, 0x0000000c, 0x00000006,
    0x0004002b, 0x00000006, 0x0000000d, 0x00000000, 0x0004002b, 0x00000006,
    0x0000000e, 0xbf000000, 0x0005002c, 0x00000007, 0x0000000f, 0x0000000d,
    0x0000000e, 0x0004002b, 0x00000006, 0x00000010, 0x3f000000, 0x0005002c,
    0x00000007, 0x00000011, 0x00000010, 0x00000010, 0x0005002c, 0x00000007,
    0x00000012, 0x0000000e, 0x00000010, 0x0006002c, 0x0000000a, 0x00000013,
    0x0000000f, 0x00000011, 0x00000012, 0x00040017, 0x00000014, 0x00000006,
    0x00000003, 0x0004001c, 0x00000015, 0x00000014, 0x00000009, 0x00040020,
    0x00000016, 0x00000006, 0x00000015, 0x0004003b, 0x00000016, 0x00000017,
    0x00000006, 0x0004002b, 0x00000006, 0x00000018, 0x3f800000, 0x0006002c,
    0x00000014, 0x00000019, 0x00000018, 0x0000000d, 0x0000000d, 0x0006002c,
    0x00000014, 0x0000001a, 0x0000000d, 0x00000018, 0x0000000d, 0x0006002c,
    0x00000014, 0x0000001b, 0x0000000d, 0x0000000d, 0x00000018, 0x0006002c,
    0x00000015, 0x0000001c, 0x00000019, 0x0000001a, 0x0000001b, 0x00040017,
    0x0000001d, 0x00000006, 0x00000004, 0x0004002b, 0x00000008, 0x0000001e,
    0x00000001, 0x0004001c, 0x0000001f, 0x00000006, 0x0000001e, 0x0006001e,
    0x00000020, 0x0000001d, 0x00000006, 0x0000001f, 0x0000001f, 0x00040020,
    0x00000021, 0x00000003, 0x00000020, 0x0004003b, 0x00000021, 0x00000022,
    0x00000003, 0x00040015, 0x00000023, 0x00000020, 0x00000001, 0x0004002b,
    0x00000023, 0x00000024, 0x00000000, 0x00040020, 0x00000025, 0x00000001,
    0x00000023, 0x0004003b, 0x00000025, 0x00000026, 0x00000001, 0x00040020,
    0x00000028, 0x00000006, 0x00000007, 0x00040020, 0x0000002d, 0x00000003,
    0x0000001d, 0x00040020, 0x00000030, 0x00000003, 0x00000014, 0x0004003b,
    0x00000030, 0x00000031, 0x00000003, 0x00040020, 0x00000033, 0x00000006,
    0x00000014, 0x00050036, 0x00000002, 0x00000004, 0x00000000, 0x00000003,
    0x000200f8, 0x00000005, 0x0003003e, 0x0000000c, 0x00000013, 0x0003003e,
    0x00000017, 0x0000001c, 0x0004003d, 0x00000023, 0x00000027, 0x00000026,
    0x00050041, 0x00000028, 0x00000029, 0x0000000c, 0x00000027, 0x0004003d,
    0x00000007, 0x0000002a, 0x00000029, 0x00050051, 0x00000006, 0x0000002b,
    0x0000002a, 0x00000000, 0x00050051, 0x00000006, 0x0000002c, 0x0000002a,
    0x00000001, 0x00070050, 0x0000001d, 0x0000002e, 0x0000002b, 0x0000002c,
    0x0000000d, 0x00000018, 0x00050041, 0x0000002d, 0x0000002f, 0x00000022,
    0x00000024, 0x0003003e, 0x0000002f, 0x0000002e, 0x0004003d, 0x00000023,
    0x00000032, 0x00000026, 0x00050041, 0x00000033, 0x00000034, 0x00000017,
    0x00000032, 0x0004003d, 0x00000014, 0x00000035, 0x00000034, 0x0003003e,
    0x00000031, 0x00000035, 0x000100fd, 0x00010038
];

// Fragment shader (compiled from hello.frag)
static immutable uint[] fragShaderCode = [
    0x07230203, 0x00010000, 0x0008000b, 0x00000013, 0x00000000, 0x00020011,
    0x00000001, 0x0006000b, 0x00000001, 0x4c534c47, 0x6474732e, 0x3035342e,
    0x00000000, 0x0003000e, 0x00000000, 0x00000001, 0x0007000f, 0x00000004,
    0x00000004, 0x6e69616d, 0x00000000, 0x00000009, 0x0000000c, 0x00030010,
    0x00000004, 0x00000007, 0x00030003, 0x00000002, 0x000001c2, 0x00040005,
    0x00000004, 0x6e69616d, 0x00000000, 0x00050005, 0x00000009, 0x4374756f,
    0x726f6c6f, 0x00000000, 0x00050005, 0x0000000c, 0x67617266, 0x6f6c6f43,
    0x00000072, 0x00040047, 0x00000009, 0x0000001e, 0x00000000, 0x00040047,
    0x0000000c, 0x0000001e, 0x00000000, 0x00020013, 0x00000002, 0x00030021,
    0x00000003, 0x00000002, 0x00030016, 0x00000006, 0x00000020, 0x00040017,
    0x00000007, 0x00000006, 0x00000004, 0x00040020, 0x00000008, 0x00000003,
    0x00000007, 0x0004003b, 0x00000008, 0x00000009, 0x00000003, 0x00040017,
    0x0000000a, 0x00000006, 0x00000003, 0x00040020, 0x0000000b, 0x00000001,
    0x0000000a, 0x0004003b, 0x0000000b, 0x0000000c, 0x00000001, 0x0004002b,
    0x00000006, 0x0000000e, 0x3f800000, 0x00050036, 0x00000002, 0x00000004,
    0x00000000, 0x00000003, 0x000200f8, 0x00000005, 0x0004003d, 0x0000000a,
    0x0000000d, 0x0000000c, 0x00050051, 0x00000006, 0x0000000f, 0x0000000d,
    0x00000000, 0x00050051, 0x00000006, 0x00000010, 0x0000000d, 0x00000001,
    0x00050051, 0x00000006, 0x00000011, 0x0000000d, 0x00000002, 0x00070050,
    0x00000007, 0x00000012, 0x0000000f, 0x00000010, 0x00000011, 0x0000000e,
    0x0003003e, 0x00000009, 0x00000012, 0x000100fd, 0x00010038
];

// =============================================================================
// Utility Functions
// =============================================================================

auto toUTF16z(S)(S s) {
    return cast(const(wchar)*)s.ptr;
}

T* allocArray(T)(size_t count) {
    return cast(T*)malloc(T.sizeof * count);
}

void freeArray(T)(T* ptr) {
    if (ptr !is null) free(ptr);
}

// =============================================================================
// Vulkan Loader
// =============================================================================

bool loadVulkan() {
    gVulkanDLL = LoadLibraryA("vulkan-1.dll");
    if (gVulkanDLL is null) {
        printf("Failed to load vulkan-1.dll\n");
        return false;
    }

    vkGetInstanceProcAddr = cast(PFN_vkGetInstanceProcAddr)GetProcAddress(gVulkanDLL, "vkGetInstanceProcAddr");
    if (vkGetInstanceProcAddr is null) {
        printf("Failed to get vkGetInstanceProcAddr\n");
        return false;
    }

    // Load global functions
    vkCreateInstance = cast(PFN_vkCreateInstance)vkGetInstanceProcAddr(null, "vkCreateInstance");
    vkEnumerateInstanceLayerProperties = cast(PFN_vkEnumerateInstanceLayerProperties)vkGetInstanceProcAddr(null, "vkEnumerateInstanceLayerProperties");

    return true;
}

void loadInstanceFunctions(VkInstance instance) {
    vkDestroyInstance = cast(PFN_vkDestroyInstance)vkGetInstanceProcAddr(instance, "vkDestroyInstance");
    vkEnumeratePhysicalDevices = cast(PFN_vkEnumeratePhysicalDevices)vkGetInstanceProcAddr(instance, "vkEnumeratePhysicalDevices");
    vkGetPhysicalDeviceProperties = cast(PFN_vkGetPhysicalDeviceProperties)vkGetInstanceProcAddr(instance, "vkGetPhysicalDeviceProperties");
    vkGetPhysicalDeviceQueueFamilyProperties = cast(PFN_vkGetPhysicalDeviceQueueFamilyProperties)vkGetInstanceProcAddr(instance, "vkGetPhysicalDeviceQueueFamilyProperties");
    vkCreateDevice = cast(PFN_vkCreateDevice)vkGetInstanceProcAddr(instance, "vkCreateDevice");
    vkEnumerateDeviceExtensionProperties = cast(PFN_vkEnumerateDeviceExtensionProperties)vkGetInstanceProcAddr(instance, "vkEnumerateDeviceExtensionProperties");
    vkGetDeviceProcAddr = cast(PFN_vkGetDeviceProcAddr)vkGetInstanceProcAddr(instance, "vkGetDeviceProcAddr");

    // Surface functions
    vkDestroySurfaceKHR = cast(PFN_vkDestroySurfaceKHR)vkGetInstanceProcAddr(instance, "vkDestroySurfaceKHR");
    vkGetPhysicalDeviceSurfaceSupportKHR = cast(PFN_vkGetPhysicalDeviceSurfaceSupportKHR)vkGetInstanceProcAddr(instance, "vkGetPhysicalDeviceSurfaceSupportKHR");
    vkGetPhysicalDeviceSurfaceCapabilitiesKHR = cast(PFN_vkGetPhysicalDeviceSurfaceCapabilitiesKHR)vkGetInstanceProcAddr(instance, "vkGetPhysicalDeviceSurfaceCapabilitiesKHR");
    vkGetPhysicalDeviceSurfaceFormatsKHR = cast(PFN_vkGetPhysicalDeviceSurfaceFormatsKHR)vkGetInstanceProcAddr(instance, "vkGetPhysicalDeviceSurfaceFormatsKHR");
    vkGetPhysicalDeviceSurfacePresentModesKHR = cast(PFN_vkGetPhysicalDeviceSurfacePresentModesKHR)vkGetInstanceProcAddr(instance, "vkGetPhysicalDeviceSurfacePresentModesKHR");
    vkCreateWin32SurfaceKHR = cast(PFN_vkCreateWin32SurfaceKHR)vkGetInstanceProcAddr(instance, "vkCreateWin32SurfaceKHR");

    // Debug functions
    vkCreateDebugUtilsMessengerEXT = cast(PFN_vkCreateDebugUtilsMessengerEXT)vkGetInstanceProcAddr(instance, "vkCreateDebugUtilsMessengerEXT");
    vkDestroyDebugUtilsMessengerEXT = cast(PFN_vkDestroyDebugUtilsMessengerEXT)vkGetInstanceProcAddr(instance, "vkDestroyDebugUtilsMessengerEXT");
}

void loadDeviceFunctions(VkDevice device) {
    vkDestroyDevice = cast(PFN_vkDestroyDevice)vkGetDeviceProcAddr(device, "vkDestroyDevice");
    vkGetDeviceQueue = cast(PFN_vkGetDeviceQueue)vkGetDeviceProcAddr(device, "vkGetDeviceQueue");

    // Swapchain functions
    vkCreateSwapchainKHR = cast(PFN_vkCreateSwapchainKHR)vkGetDeviceProcAddr(device, "vkCreateSwapchainKHR");
    vkDestroySwapchainKHR = cast(PFN_vkDestroySwapchainKHR)vkGetDeviceProcAddr(device, "vkDestroySwapchainKHR");
    vkGetSwapchainImagesKHR = cast(PFN_vkGetSwapchainImagesKHR)vkGetDeviceProcAddr(device, "vkGetSwapchainImagesKHR");
    vkAcquireNextImageKHR = cast(PFN_vkAcquireNextImageKHR)vkGetDeviceProcAddr(device, "vkAcquireNextImageKHR");
    vkQueuePresentKHR = cast(PFN_vkQueuePresentKHR)vkGetDeviceProcAddr(device, "vkQueuePresentKHR");

    // Image view & render pass functions
    vkCreateImageView = cast(PFN_vkCreateImageView)vkGetDeviceProcAddr(device, "vkCreateImageView");
    vkDestroyImageView = cast(PFN_vkDestroyImageView)vkGetDeviceProcAddr(device, "vkDestroyImageView");
    vkCreateRenderPass = cast(PFN_vkCreateRenderPass)vkGetDeviceProcAddr(device, "vkCreateRenderPass");
    vkDestroyRenderPass = cast(PFN_vkDestroyRenderPass)vkGetDeviceProcAddr(device, "vkDestroyRenderPass");

    // Pipeline functions
    vkCreateShaderModule = cast(PFN_vkCreateShaderModule)vkGetDeviceProcAddr(device, "vkCreateShaderModule");
    vkDestroyShaderModule = cast(PFN_vkDestroyShaderModule)vkGetDeviceProcAddr(device, "vkDestroyShaderModule");
    vkCreatePipelineLayout = cast(PFN_vkCreatePipelineLayout)vkGetDeviceProcAddr(device, "vkCreatePipelineLayout");
    vkDestroyPipelineLayout = cast(PFN_vkDestroyPipelineLayout)vkGetDeviceProcAddr(device, "vkDestroyPipelineLayout");
    vkCreateGraphicsPipelines = cast(PFN_vkCreateGraphicsPipelines)vkGetDeviceProcAddr(device, "vkCreateGraphicsPipelines");
    vkDestroyPipeline = cast(PFN_vkDestroyPipeline)vkGetDeviceProcAddr(device, "vkDestroyPipeline");

    // Framebuffer functions
    vkCreateFramebuffer = cast(PFN_vkCreateFramebuffer)vkGetDeviceProcAddr(device, "vkCreateFramebuffer");
    vkDestroyFramebuffer = cast(PFN_vkDestroyFramebuffer)vkGetDeviceProcAddr(device, "vkDestroyFramebuffer");

    // Command buffer functions
    vkCreateCommandPool = cast(PFN_vkCreateCommandPool)vkGetDeviceProcAddr(device, "vkCreateCommandPool");
    vkDestroyCommandPool = cast(PFN_vkDestroyCommandPool)vkGetDeviceProcAddr(device, "vkDestroyCommandPool");
    vkAllocateCommandBuffers = cast(PFN_vkAllocateCommandBuffers)vkGetDeviceProcAddr(device, "vkAllocateCommandBuffers");
    vkFreeCommandBuffers = cast(PFN_vkFreeCommandBuffers)vkGetDeviceProcAddr(device, "vkFreeCommandBuffers");
    vkBeginCommandBuffer = cast(PFN_vkBeginCommandBuffer)vkGetDeviceProcAddr(device, "vkBeginCommandBuffer");
    vkEndCommandBuffer = cast(PFN_vkEndCommandBuffer)vkGetDeviceProcAddr(device, "vkEndCommandBuffer");
    vkResetCommandBuffer = cast(PFN_vkResetCommandBuffer)vkGetDeviceProcAddr(device, "vkResetCommandBuffer");
    vkCmdBeginRenderPass = cast(PFN_vkCmdBeginRenderPass)vkGetDeviceProcAddr(device, "vkCmdBeginRenderPass");
    vkCmdEndRenderPass = cast(PFN_vkCmdEndRenderPass)vkGetDeviceProcAddr(device, "vkCmdEndRenderPass");
    vkCmdBindPipeline = cast(PFN_vkCmdBindPipeline)vkGetDeviceProcAddr(device, "vkCmdBindPipeline");
    vkCmdSetViewport = cast(PFN_vkCmdSetViewport)vkGetDeviceProcAddr(device, "vkCmdSetViewport");
    vkCmdSetScissor = cast(PFN_vkCmdSetScissor)vkGetDeviceProcAddr(device, "vkCmdSetScissor");
    vkCmdDraw = cast(PFN_vkCmdDraw)vkGetDeviceProcAddr(device, "vkCmdDraw");

    // Synchronization objects
    vkCreateSemaphore = cast(PFN_vkCreateSemaphore)vkGetDeviceProcAddr(device, "vkCreateSemaphore");
    vkDestroySemaphore = cast(PFN_vkDestroySemaphore)vkGetDeviceProcAddr(device, "vkDestroySemaphore");
    vkCreateFence = cast(PFN_vkCreateFence)vkGetDeviceProcAddr(device, "vkCreateFence");
    vkDestroyFence = cast(PFN_vkDestroyFence)vkGetDeviceProcAddr(device, "vkDestroyFence");
    vkWaitForFences = cast(PFN_vkWaitForFences)vkGetDeviceProcAddr(device, "vkWaitForFences");
    vkResetFences = cast(PFN_vkResetFences)vkGetDeviceProcAddr(device, "vkResetFences");

    // Queue functions
    vkQueueSubmit = cast(PFN_vkQueueSubmit)vkGetDeviceProcAddr(device, "vkQueueSubmit");
    vkDeviceWaitIdle = cast(PFN_vkDeviceWaitIdle)vkGetDeviceProcAddr(device, "vkDeviceWaitIdle");
}

// =============================================================================
// Debug Callback
// =============================================================================

extern(System) VkBool32 debugCallback(
    VkDebugUtilsMessageSeverityFlagBitsEXT messageSeverity,
    VkDebugUtilsMessageTypeFlagBitsEXT messageTypes,
    const(VkDebugUtilsMessengerCallbackDataEXT)* pCallbackData,
    void* pUserData) nothrow
{
    printf("Validation: %s\n", pCallbackData.pMessage);
    return 0;
}

// =============================================================================
// Vulkan Initialization Functions
// =============================================================================

void createInstance() {
    VkApplicationInfo appInfo;
    appInfo.pApplicationName = "Hello Vulkan (D)";
    appInfo.applicationVersion = 1;
    appInfo.pEngineName = "No Engine";
    appInfo.engineVersion = 1;
    appInfo.apiVersion = (1 << 22) | (4 << 12); // VK_API_VERSION_1_4

    const(char)*[3] extensions = [
        "VK_KHR_surface",
        "VK_KHR_win32_surface",
        "VK_EXT_debug_utils"
    ];

    const(char)*[1] layers = ["VK_LAYER_KHRONOS_validation"];

    VkDebugUtilsMessengerCreateInfoEXT debugCreateInfo;
    debugCreateInfo.messageSeverity = VK_DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT |
                                      VK_DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT;
    debugCreateInfo.messageType = VK_DEBUG_UTILS_MESSAGE_TYPE_GENERAL_BIT_EXT |
                                  VK_DEBUG_UTILS_MESSAGE_TYPE_VALIDATION_BIT_EXT |
                                  VK_DEBUG_UTILS_MESSAGE_TYPE_PERFORMANCE_BIT_EXT;
    debugCreateInfo.pfnUserCallback = &debugCallback;

    VkInstanceCreateInfo createInfo;
    createInfo.pApplicationInfo = &appInfo;
    createInfo.enabledExtensionCount = cast(uint)(ENABLE_VALIDATION ? 3 : 2);
    createInfo.ppEnabledExtensionNames = extensions.ptr;
    if (ENABLE_VALIDATION) {
        createInfo.enabledLayerCount = 1;
        createInfo.ppEnabledLayerNames = layers.ptr;
        createInfo.pNext = &debugCreateInfo;
    }

    if (vkCreateInstance(&createInfo, null, &gApp.instance) != VK_SUCCESS) {
        printf("Failed to create instance!\n");
        exit(1);
    }

    loadInstanceFunctions(gApp.instance);

    if (ENABLE_VALIDATION && vkCreateDebugUtilsMessengerEXT !is null) {
        vkCreateDebugUtilsMessengerEXT(gApp.instance, &debugCreateInfo, null, &gApp.debugMessenger);
    }
}

void createSurface() {
    VkWin32SurfaceCreateInfoKHR createInfo;
    createInfo.hinstance = gApp.hInstance;
    createInfo.hwnd = gApp.hwnd;

    if (vkCreateWin32SurfaceKHR(gApp.instance, &createInfo, null, &gApp.surface) != VK_SUCCESS) {
        printf("Failed to create window surface!\n");
        exit(1);
    }
}

void pickPhysicalDevice() {
    uint deviceCount = 0;
    vkEnumeratePhysicalDevices(gApp.instance, &deviceCount, null);
    if (deviceCount == 0) {
        printf("No Vulkan devices found!\n");
        exit(1);
    }

    auto devices = allocArray!VkPhysicalDevice(deviceCount);
    vkEnumeratePhysicalDevices(gApp.instance, &deviceCount, devices);

    // Use first device
    gApp.physicalDevice = devices[0];

    VkPhysicalDeviceProperties props;
    vkGetPhysicalDeviceProperties(gApp.physicalDevice, &props);
    printf("Using device: %s\n", props.deviceName.ptr);

    freeArray(devices);

    // Find queue families
    uint queueFamilyCount = 0;
    vkGetPhysicalDeviceQueueFamilyProperties(gApp.physicalDevice, &queueFamilyCount, null);

    auto queueFamilies = allocArray!VkQueueFamilyProperties(queueFamilyCount);
    vkGetPhysicalDeviceQueueFamilyProperties(gApp.physicalDevice, &queueFamilyCount, queueFamilies);

    bool foundGraphics = false;
    bool foundPresent = false;

    for (uint i = 0; i < queueFamilyCount; i++) {
        if ((queueFamilies[i].queueFlags & VK_QUEUE_GRAPHICS_BIT) && !foundGraphics) {
            gApp.graphicsFamily = i;
            foundGraphics = true;
        }

        VkBool32 presentSupport = 0;
        vkGetPhysicalDeviceSurfaceSupportKHR(gApp.physicalDevice, i, gApp.surface, &presentSupport);
        if (presentSupport && !foundPresent) {
            gApp.presentFamily = i;
            foundPresent = true;
        }

        if (foundGraphics && foundPresent) break;
    }

    freeArray(queueFamilies);

    if (!foundGraphics || !foundPresent) {
        printf("Failed to find suitable queue families!\n");
        exit(1);
    }
}

void createLogicalDevice() {
    float queuePriority = 1.0f;

    VkDeviceQueueCreateInfo[2] queueCreateInfos;
    uint queueCount = 1;

    queueCreateInfos[0].queueFamilyIndex = gApp.graphicsFamily;
    queueCreateInfos[0].queueCount = 1;
    queueCreateInfos[0].pQueuePriorities = &queuePriority;

    if (gApp.graphicsFamily != gApp.presentFamily) {
        queueCreateInfos[1].queueFamilyIndex = gApp.presentFamily;
        queueCreateInfos[1].queueCount = 1;
        queueCreateInfos[1].pQueuePriorities = &queuePriority;
        queueCount = 2;
    }

    const(char)*[1] deviceExtensions = ["VK_KHR_swapchain"];

    VkDeviceCreateInfo createInfo;
    createInfo.queueCreateInfoCount = queueCount;
    createInfo.pQueueCreateInfos = queueCreateInfos.ptr;
    createInfo.enabledExtensionCount = 1;
    createInfo.ppEnabledExtensionNames = deviceExtensions.ptr;

    if (vkCreateDevice(gApp.physicalDevice, &createInfo, null, &gApp.device) != VK_SUCCESS) {
        printf("Failed to create logical device!\n");
        exit(1);
    }

    loadDeviceFunctions(gApp.device);

    vkGetDeviceQueue(gApp.device, gApp.graphicsFamily, 0, &gApp.graphicsQueue);
    vkGetDeviceQueue(gApp.device, gApp.presentFamily, 0, &gApp.presentQueue);
}

VkSurfaceFormatKHR chooseSwapSurfaceFormat(VkSurfaceFormatKHR* formats, uint count) {
    for (uint i = 0; i < count; i++) {
        if (formats[i].format == VK_FORMAT_B8G8R8A8_SRGB &&
            formats[i].colorSpace == VK_COLOR_SPACE_SRGB_NONLINEAR_KHR) {
            return formats[i];
        }
    }
    return formats[0];
}

VkPresentModeKHR chooseSwapPresentMode(VkPresentModeKHR* modes, uint count) {
    for (uint i = 0; i < count; i++) {
        if (modes[i] == VK_PRESENT_MODE_MAILBOX_KHR) {
            return VK_PRESENT_MODE_MAILBOX_KHR;
        }
    }
    return VK_PRESENT_MODE_FIFO_KHR;
}

VkExtent2D chooseSwapExtent(const(VkSurfaceCapabilitiesKHR)* caps) {
    if (caps.currentExtent.width != uint.max) {
        return caps.currentExtent;
    }
    VkExtent2D extent = VkExtent2D(WIDTH, HEIGHT);
    if (extent.width < caps.minImageExtent.width) extent.width = caps.minImageExtent.width;
    if (extent.width > caps.maxImageExtent.width) extent.width = caps.maxImageExtent.width;
    if (extent.height < caps.minImageExtent.height) extent.height = caps.minImageExtent.height;
    if (extent.height > caps.maxImageExtent.height) extent.height = caps.maxImageExtent.height;
    return extent;
}

void createSwapChain() {
    VkSurfaceCapabilitiesKHR caps;
    vkGetPhysicalDeviceSurfaceCapabilitiesKHR(gApp.physicalDevice, gApp.surface, &caps);

    uint formatCount = 0;
    vkGetPhysicalDeviceSurfaceFormatsKHR(gApp.physicalDevice, gApp.surface, &formatCount, null);
    auto formats = allocArray!VkSurfaceFormatKHR(formatCount);
    vkGetPhysicalDeviceSurfaceFormatsKHR(gApp.physicalDevice, gApp.surface, &formatCount, formats);

    uint modeCount = 0;
    vkGetPhysicalDeviceSurfacePresentModesKHR(gApp.physicalDevice, gApp.surface, &modeCount, null);
    auto modes = allocArray!VkPresentModeKHR(modeCount);
    vkGetPhysicalDeviceSurfacePresentModesKHR(gApp.physicalDevice, gApp.surface, &modeCount, modes);

    VkSurfaceFormatKHR surfaceFormat = chooseSwapSurfaceFormat(formats, formatCount);
    VkPresentModeKHR presentMode = chooseSwapPresentMode(modes, modeCount);
    VkExtent2D extent = chooseSwapExtent(&caps);

    uint imageCount = caps.minImageCount + 1;
    if (caps.maxImageCount > 0 && imageCount > caps.maxImageCount) {
        imageCount = caps.maxImageCount;
    }

    VkSwapchainCreateInfoKHR createInfo;
    createInfo.surface = gApp.surface;
    createInfo.minImageCount = imageCount;
    createInfo.imageFormat = surfaceFormat.format;
    createInfo.imageColorSpace = surfaceFormat.colorSpace;
    createInfo.imageExtent = extent;
    createInfo.imageArrayLayers = 1;
    createInfo.imageUsage = VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT;

    uint[2] queueFamilyIndices = [gApp.graphicsFamily, gApp.presentFamily];
    if (gApp.graphicsFamily != gApp.presentFamily) {
        createInfo.imageSharingMode = VK_SHARING_MODE_CONCURRENT;
        createInfo.queueFamilyIndexCount = 2;
        createInfo.pQueueFamilyIndices = queueFamilyIndices.ptr;
    } else {
        createInfo.imageSharingMode = VK_SHARING_MODE_EXCLUSIVE;
    }

    createInfo.preTransform = caps.currentTransform;
    createInfo.compositeAlpha = VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR;
    createInfo.presentMode = presentMode;
    createInfo.clipped = 1;

    if (vkCreateSwapchainKHR(gApp.device, &createInfo, null, &gApp.swapChain) != VK_SUCCESS) {
        printf("Failed to create swap chain!\n");
        exit(1);
    }

    gApp.swapChainImageFormat = surfaceFormat.format;
    gApp.swapChainExtent = extent;

    // Get images
    vkGetSwapchainImagesKHR(gApp.device, gApp.swapChain, &imageCount, null);
    gApp.swapChainImages = new VkImage[imageCount];
    vkGetSwapchainImagesKHR(gApp.device, gApp.swapChain, &imageCount, gApp.swapChainImages.ptr);

    freeArray(formats);
    freeArray(modes);
}

void createImageViews() {
    gApp.swapChainImageViews = new VkImageView[gApp.swapChainImages.length];

    foreach (i, image; gApp.swapChainImages) {
        VkImageViewCreateInfo createInfo;
        createInfo.image = image;
        createInfo.viewType = VK_IMAGE_VIEW_TYPE_2D;
        createInfo.format = gApp.swapChainImageFormat;
        createInfo.components.r = VK_COMPONENT_SWIZZLE_IDENTITY;
        createInfo.components.g = VK_COMPONENT_SWIZZLE_IDENTITY;
        createInfo.components.b = VK_COMPONENT_SWIZZLE_IDENTITY;
        createInfo.components.a = VK_COMPONENT_SWIZZLE_IDENTITY;
        createInfo.subresourceRange.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT;
        createInfo.subresourceRange.baseMipLevel = 0;
        createInfo.subresourceRange.levelCount = 1;
        createInfo.subresourceRange.baseArrayLayer = 0;
        createInfo.subresourceRange.layerCount = 1;

        if (vkCreateImageView(gApp.device, &createInfo, null, &gApp.swapChainImageViews[i]) != VK_SUCCESS) {
            printf("Failed to create image views!\n");
            exit(1);
        }
    }
}

void createRenderPass() {
    VkAttachmentDescription colorAttachment;
    colorAttachment.format = gApp.swapChainImageFormat;
    colorAttachment.samples = 1;
    colorAttachment.loadOp = VK_ATTACHMENT_LOAD_OP_CLEAR;
    colorAttachment.storeOp = VK_ATTACHMENT_STORE_OP_STORE;
    colorAttachment.stencilLoadOp = VK_ATTACHMENT_LOAD_OP_DONT_CARE;
    colorAttachment.stencilStoreOp = VK_ATTACHMENT_STORE_OP_DONT_CARE;
    colorAttachment.initialLayout = VK_IMAGE_LAYOUT_UNDEFINED;
    colorAttachment.finalLayout = VK_IMAGE_LAYOUT_PRESENT_SRC_KHR;

    VkAttachmentReference colorAttachmentRef;
    colorAttachmentRef.attachment = 0;
    colorAttachmentRef.layout = VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL;

    VkSubpassDescription subpass;
    subpass.pipelineBindPoint = VK_PIPELINE_BIND_POINT_GRAPHICS;
    subpass.colorAttachmentCount = 1;
    subpass.pColorAttachments = &colorAttachmentRef;

    VkSubpassDependency dependency;
    dependency.srcSubpass = VK_SUBPASS_EXTERNAL;
    dependency.dstSubpass = 0;
    dependency.srcStageMask = VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT;
    dependency.srcAccessMask = 0;
    dependency.dstStageMask = VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT;
    dependency.dstAccessMask = VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT;

    VkRenderPassCreateInfo renderPassInfo;
    renderPassInfo.attachmentCount = 1;
    renderPassInfo.pAttachments = &colorAttachment;
    renderPassInfo.subpassCount = 1;
    renderPassInfo.pSubpasses = &subpass;
    renderPassInfo.dependencyCount = 1;
    renderPassInfo.pDependencies = &dependency;

    if (vkCreateRenderPass(gApp.device, &renderPassInfo, null, &gApp.renderPass) != VK_SUCCESS) {
        printf("Failed to create render pass!\n");
        exit(1);
    }
}

VkShaderModule createShaderModule(const(uint)[] code) {
    VkShaderModuleCreateInfo createInfo;
    createInfo.codeSize = code.length * uint.sizeof;
    createInfo.pCode = code.ptr;

    VkShaderModule shaderModule;
    if (vkCreateShaderModule(gApp.device, &createInfo, null, &shaderModule) != VK_SUCCESS) {
        printf("Failed to create shader module!\n");
        exit(1);
    }
    return shaderModule;
}

void createGraphicsPipeline() {
    VkShaderModule vertShaderModule = createShaderModule(vertShaderCode);
    VkShaderModule fragShaderModule = createShaderModule(fragShaderCode);

    VkPipelineShaderStageCreateInfo vertShaderStageInfo;
    vertShaderStageInfo.stage = VK_SHADER_STAGE_VERTEX_BIT;
    vertShaderStageInfo._module = vertShaderModule;
    vertShaderStageInfo.pName = "main";

    VkPipelineShaderStageCreateInfo fragShaderStageInfo;
    fragShaderStageInfo.stage = VK_SHADER_STAGE_FRAGMENT_BIT;
    fragShaderStageInfo._module = fragShaderModule;
    fragShaderStageInfo.pName = "main";

    VkPipelineShaderStageCreateInfo[2] shaderStages = [vertShaderStageInfo, fragShaderStageInfo];

    VkPipelineVertexInputStateCreateInfo vertexInputInfo;

    VkPipelineInputAssemblyStateCreateInfo inputAssembly;
    inputAssembly.topology = VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST;
    inputAssembly.primitiveRestartEnable = 0;

    VkPipelineViewportStateCreateInfo viewportState;
    viewportState.viewportCount = 1;
    viewportState.scissorCount = 1;

    VkPipelineRasterizationStateCreateInfo rasterizer;
    rasterizer.depthClampEnable = 0;
    rasterizer.rasterizerDiscardEnable = 0;
    rasterizer.polygonMode = VK_POLYGON_MODE_FILL;
    rasterizer.lineWidth = 1.0f;
    rasterizer.cullMode = VK_CULL_MODE_BACK_BIT;
    rasterizer.frontFace = VK_FRONT_FACE_CLOCKWISE;
    rasterizer.depthBiasEnable = 0;

    VkPipelineMultisampleStateCreateInfo multisampling;
    multisampling.sampleShadingEnable = 0;
    multisampling.rasterizationSamples = 1;

    VkPipelineColorBlendAttachmentState colorBlendAttachment;
    colorBlendAttachment.colorWriteMask = VK_COLOR_COMPONENT_R_BIT | VK_COLOR_COMPONENT_G_BIT |
                                          VK_COLOR_COMPONENT_B_BIT | VK_COLOR_COMPONENT_A_BIT;
    colorBlendAttachment.blendEnable = 0;

    VkPipelineColorBlendStateCreateInfo colorBlending;
    colorBlending.logicOpEnable = 0;
    colorBlending.attachmentCount = 1;
    colorBlending.pAttachments = &colorBlendAttachment;

    VkDynamicState[2] dynamicStates = [VK_DYNAMIC_STATE_VIEWPORT, VK_DYNAMIC_STATE_SCISSOR];

    VkPipelineDynamicStateCreateInfo dynamicState;
    dynamicState.dynamicStateCount = 2;
    dynamicState.pDynamicStates = dynamicStates.ptr;

    VkPipelineLayoutCreateInfo pipelineLayoutInfo;

    if (vkCreatePipelineLayout(gApp.device, &pipelineLayoutInfo, null, &gApp.pipelineLayout) != VK_SUCCESS) {
        printf("Failed to create pipeline layout!\n");
        exit(1);
    }

    VkGraphicsPipelineCreateInfo pipelineInfo;
    pipelineInfo.stageCount = 2;
    pipelineInfo.pStages = shaderStages.ptr;
    pipelineInfo.pVertexInputState = &vertexInputInfo;
    pipelineInfo.pInputAssemblyState = &inputAssembly;
    pipelineInfo.pViewportState = &viewportState;
    pipelineInfo.pRasterizationState = &rasterizer;
    pipelineInfo.pMultisampleState = &multisampling;
    pipelineInfo.pColorBlendState = &colorBlending;
    pipelineInfo.pDynamicState = &dynamicState;
    pipelineInfo.layout = gApp.pipelineLayout;
    pipelineInfo.renderPass = gApp.renderPass;
    pipelineInfo.subpass = 0;
    pipelineInfo.basePipelineIndex = -1;

    if (vkCreateGraphicsPipelines(gApp.device, null, 1, &pipelineInfo, null, &gApp.graphicsPipeline) != VK_SUCCESS) {
        printf("Failed to create graphics pipeline!\n");
        exit(1);
    }

    vkDestroyShaderModule(gApp.device, fragShaderModule, null);
    vkDestroyShaderModule(gApp.device, vertShaderModule, null);
}

void createFramebuffers() {
    gApp.swapChainFramebuffers = new VkFramebuffer[gApp.swapChainImageViews.length];

    foreach (i, imageView; gApp.swapChainImageViews) {
        VkImageView[1] attachments = [imageView];

        VkFramebufferCreateInfo framebufferInfo;
        framebufferInfo.renderPass = gApp.renderPass;
        framebufferInfo.attachmentCount = 1;
        framebufferInfo.pAttachments = attachments.ptr;
        framebufferInfo.width = gApp.swapChainExtent.width;
        framebufferInfo.height = gApp.swapChainExtent.height;
        framebufferInfo.layers = 1;

        if (vkCreateFramebuffer(gApp.device, &framebufferInfo, null, &gApp.swapChainFramebuffers[i]) != VK_SUCCESS) {
            printf("Failed to create framebuffer!\n");
            exit(1);
        }
    }
}

void createCommandPool() {
    VkCommandPoolCreateInfo poolInfo;
    poolInfo.flags = VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT;
    poolInfo.queueFamilyIndex = gApp.graphicsFamily;

    if (vkCreateCommandPool(gApp.device, &poolInfo, null, &gApp.commandPool) != VK_SUCCESS) {
        printf("Failed to create command pool!\n");
        exit(1);
    }
}

void createCommandBuffers() {
    gApp.commandBuffers = new VkCommandBuffer[MAX_FRAMES_IN_FLIGHT];

    VkCommandBufferAllocateInfo allocInfo;
    allocInfo.commandPool = gApp.commandPool;
    allocInfo.level = VK_COMMAND_BUFFER_LEVEL_PRIMARY;
    allocInfo.commandBufferCount = MAX_FRAMES_IN_FLIGHT;

    if (vkAllocateCommandBuffers(gApp.device, &allocInfo, gApp.commandBuffers.ptr) != VK_SUCCESS) {
        printf("Failed to allocate command buffers!\n");
        exit(1);
    }
}

void createSyncObjects() {
    VkSemaphoreCreateInfo semaphoreInfo;
    VkFenceCreateInfo fenceInfo;
    fenceInfo.flags = VK_FENCE_CREATE_SIGNALED_BIT;

    for (int i = 0; i < MAX_FRAMES_IN_FLIGHT; i++) {
        if (vkCreateSemaphore(gApp.device, &semaphoreInfo, null, &gApp.imageAvailableSemaphores[i]) != VK_SUCCESS ||
            vkCreateSemaphore(gApp.device, &semaphoreInfo, null, &gApp.renderFinishedSemaphores[i]) != VK_SUCCESS ||
            vkCreateFence(gApp.device, &fenceInfo, null, &gApp.inFlightFences[i]) != VK_SUCCESS) {
            printf("Failed to create sync objects!\n");
            exit(1);
        }
    }
}

void recordCommandBuffer(VkCommandBuffer commandBuffer, uint imageIndex) {
    VkCommandBufferBeginInfo beginInfo;

    if (vkBeginCommandBuffer(commandBuffer, &beginInfo) != VK_SUCCESS) {
        printf("Failed to begin recording command buffer!\n");
        exit(1);
    }

    VkClearValue clearColor;
    clearColor.color.float32 = [0.0f, 0.0f, 0.0f, 1.0f];

    VkRenderPassBeginInfo renderPassInfo;
    renderPassInfo.renderPass = gApp.renderPass;
    renderPassInfo.framebuffer = gApp.swapChainFramebuffers[imageIndex];
    renderPassInfo.renderArea.offset = VkOffset2D(0, 0);
    renderPassInfo.renderArea.extent = gApp.swapChainExtent;
    renderPassInfo.clearValueCount = 1;
    renderPassInfo.pClearValues = &clearColor;

    vkCmdBeginRenderPass(commandBuffer, &renderPassInfo, VK_SUBPASS_CONTENTS_INLINE);
    vkCmdBindPipeline(commandBuffer, VK_PIPELINE_BIND_POINT_GRAPHICS, gApp.graphicsPipeline);

    VkViewport viewport;
    viewport.x = 0.0f;
    viewport.y = 0.0f;
    viewport.width = cast(float)gApp.swapChainExtent.width;
    viewport.height = cast(float)gApp.swapChainExtent.height;
    viewport.minDepth = 0.0f;
    viewport.maxDepth = 1.0f;
    vkCmdSetViewport(commandBuffer, 0, 1, &viewport);

    VkRect2D scissor;
    scissor.offset = VkOffset2D(0, 0);
    scissor.extent = gApp.swapChainExtent;
    vkCmdSetScissor(commandBuffer, 0, 1, &scissor);

    vkCmdDraw(commandBuffer, 3, 1, 0, 0);
    vkCmdEndRenderPass(commandBuffer);

    if (vkEndCommandBuffer(commandBuffer) != VK_SUCCESS) {
        printf("Failed to record command buffer!\n");
        exit(1);
    }
}

void drawFrame() {
    vkWaitForFences(gApp.device, 1, &gApp.inFlightFences[gApp.currentFrame], 1, ulong.max);

    uint imageIndex;
    VkResult result = vkAcquireNextImageKHR(gApp.device, gApp.swapChain, ulong.max,
                                            gApp.imageAvailableSemaphores[gApp.currentFrame],
                                            null, &imageIndex);

    if (result == VK_ERROR_OUT_OF_DATE_KHR) {
        return;
    }

    vkResetFences(gApp.device, 1, &gApp.inFlightFences[gApp.currentFrame]);
    vkResetCommandBuffer(gApp.commandBuffers[gApp.currentFrame], 0);

    recordCommandBuffer(gApp.commandBuffers[gApp.currentFrame], imageIndex);

    VkSemaphore[1] waitSemaphores = [gApp.imageAvailableSemaphores[gApp.currentFrame]];
    VkFlags[1] waitStages = [VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT];
    VkSemaphore[1] signalSemaphores = [gApp.renderFinishedSemaphores[gApp.currentFrame]];

    VkSubmitInfo submitInfo;
    submitInfo.waitSemaphoreCount = 1;
    submitInfo.pWaitSemaphores = waitSemaphores.ptr;
    submitInfo.pWaitDstStageMask = waitStages.ptr;
    submitInfo.commandBufferCount = 1;
    submitInfo.pCommandBuffers = &gApp.commandBuffers[gApp.currentFrame];
    submitInfo.signalSemaphoreCount = 1;
    submitInfo.pSignalSemaphores = signalSemaphores.ptr;

    if (vkQueueSubmit(gApp.graphicsQueue, 1, &submitInfo, gApp.inFlightFences[gApp.currentFrame]) != VK_SUCCESS) {
        printf("Failed to submit draw command buffer!\n");
        exit(1);
    }

    VkSwapchainKHR[1] swapChains = [gApp.swapChain];

    VkPresentInfoKHR presentInfo;
    presentInfo.waitSemaphoreCount = 1;
    presentInfo.pWaitSemaphores = signalSemaphores.ptr;
    presentInfo.swapchainCount = 1;
    presentInfo.pSwapchains = swapChains.ptr;
    presentInfo.pImageIndices = &imageIndex;

    vkQueuePresentKHR(gApp.presentQueue, &presentInfo);

    gApp.currentFrame = (gApp.currentFrame + 1) % MAX_FRAMES_IN_FLIGHT;
}

void cleanup() {
    vkDeviceWaitIdle(gApp.device);

    for (int i = 0; i < MAX_FRAMES_IN_FLIGHT; i++) {
        vkDestroySemaphore(gApp.device, gApp.renderFinishedSemaphores[i], null);
        vkDestroySemaphore(gApp.device, gApp.imageAvailableSemaphores[i], null);
        vkDestroyFence(gApp.device, gApp.inFlightFences[i], null);
    }

    vkDestroyCommandPool(gApp.device, gApp.commandPool, null);

    foreach (fb; gApp.swapChainFramebuffers) {
        vkDestroyFramebuffer(gApp.device, fb, null);
    }

    vkDestroyPipeline(gApp.device, gApp.graphicsPipeline, null);
    vkDestroyPipelineLayout(gApp.device, gApp.pipelineLayout, null);
    vkDestroyRenderPass(gApp.device, gApp.renderPass, null);

    foreach (iv; gApp.swapChainImageViews) {
        vkDestroyImageView(gApp.device, iv, null);
    }

    vkDestroySwapchainKHR(gApp.device, gApp.swapChain, null);
    vkDestroyDevice(gApp.device, null);

    if (ENABLE_VALIDATION && vkDestroyDebugUtilsMessengerEXT !is null) {
        vkDestroyDebugUtilsMessengerEXT(gApp.instance, gApp.debugMessenger, null);
    }

    vkDestroySurfaceKHR(gApp.instance, gApp.surface, null);
    vkDestroyInstance(gApp.instance, null);

    if (gVulkanDLL !is null) FreeLibrary(gVulkanDLL);
}

void initVulkan() {
    createInstance();
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

// =============================================================================
// Windows Window Handling
// =============================================================================

extern (Windows)
LRESULT WndProc(HWND hwnd, UINT message, WPARAM wParam, LPARAM lParam) nothrow {
    switch (message) {
        case WM_DESTROY:
        case WM_CLOSE:
            PostQuitMessage(0);
            return 0;
        default:
            return DefWindowProc(hwnd, message, wParam, lParam);
    }
}

extern (Windows)
int WinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, LPSTR lpCmdLine, int nCmdShow) {
    Runtime.initialize();
    int result = myWinMain(hInstance, hPrevInstance, lpCmdLine, nCmdShow);
    Runtime.terminate();
    return result;
}

int myWinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, LPSTR lpCmdLine, int nCmdShow) {
    gApp.hInstance = hInstance;

    // Load Vulkan
    if (!loadVulkan()) {
        return 1;
    }

    // Register window class
    string className = "VulkanTriangle";
    WNDCLASSEX wcex;
    wcex.cbSize = WNDCLASSEX.sizeof;
    wcex.style = CS_OWNDC;
    wcex.lpfnWndProc = &WndProc;
    wcex.hInstance = hInstance;
    wcex.hIcon = LoadIcon(null, IDI_APPLICATION);
    wcex.hCursor = LoadCursor(null, IDC_ARROW);
    wcex.hbrBackground = cast(HBRUSH)GetStockObject(BLACK_BRUSH);
    wcex.lpszClassName = className.toUTF16z;
    wcex.hIconSm = LoadIcon(null, IDI_APPLICATION);

    RegisterClassEx(&wcex);

    // Create window
    gApp.hwnd = CreateWindowEx(
        0,
        className.toUTF16z,
        "Hello Vulkan (D)",
        WS_OVERLAPPEDWINDOW,
        CW_USEDEFAULT,
        CW_USEDEFAULT,
        WIDTH,
        HEIGHT,
        null,
        null,
        hInstance,
        null);

    ShowWindow(gApp.hwnd, nCmdShow);

    // Initialize Vulkan
    initVulkan();

    printf("Vulkan initialized successfully!\n");

    // Main loop
    MSG msg;
    bool quit = false;
    while (!quit) {
        if (PeekMessage(&msg, null, 0, 0, PM_REMOVE)) {
            if (msg.message == WM_QUIT) {
                quit = true;
            } else {
                TranslateMessage(&msg);
                DispatchMessage(&msg);
            }
        } else {
            drawFrame();
        }
    }

    // Cleanup
    cleanup();

    return cast(int)msg.wParam;
}