using System;
using System.IO;
using System.Text;
using System.Drawing;
using System.Windows.Forms;
using System.Runtime.InteropServices;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;

#region Vulkan Type Aliases
using VkFlags = System.UInt32;
using VkBool32 = System.UInt32;
using VkDeviceSize = System.UInt64;
using VkSampleMask = System.UInt32;
#endregion

public class VulkanRaymarching : Form
{
    #region Constants
    const uint VK_TRUE = 1;
    const uint VK_FALSE = 0;
    const uint VK_QUEUE_GRAPHICS_BIT = 0x00000001;
    const uint VK_API_VERSION_1_4 = (1 << 22) | (4 << 12);
    
    const int VK_SUCCESS = 0;
    const int VK_SUBOPTIMAL_KHR = 1000001003;
    const int VK_ERROR_OUT_OF_DATE_KHR = -1000001004;
    
    const uint VK_STRUCTURE_TYPE_APPLICATION_INFO = 0;
    const uint VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO = 1;
    const uint VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO = 2;
    const uint VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO = 3;
    const uint VK_STRUCTURE_TYPE_SUBMIT_INFO = 4;
    const uint VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO = 5;
    const uint VK_STRUCTURE_TYPE_FENCE_CREATE_INFO = 8;
    const uint VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO = 9;
    const uint VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO = 15;
    const uint VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO = 16;
    const uint VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO = 18;
    const uint VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO = 19;
    const uint VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO = 20;
    const uint VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO = 22;
    const uint VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO = 23;
    const uint VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO = 24;
    const uint VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO = 26;
    const uint VK_STRUCTURE_TYPE_PIPELINE_DYNAMIC_STATE_CREATE_INFO = 27;
    const uint VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO = 30;
    const uint VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO = 38;
    const uint VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO = 28;
    const uint VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO = 37;
    const uint VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO = 39;
    const uint VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO = 40;
    const uint VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO = 42;
    const uint VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO = 43;
    const uint VK_STRUCTURE_TYPE_PRESENT_INFO_KHR = 1000001001;
    const uint VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR = 1000001000;
    const uint VK_STRUCTURE_TYPE_WIN32_SURFACE_CREATE_INFO_KHR = 1000009000;
    
    const uint VK_FORMAT_B8G8R8A8_SRGB = 50;
    const uint VK_FORMAT_B8G8R8A8_UNORM = 44;
    const uint VK_COLOR_SPACE_SRGB_NONLINEAR_KHR = 0;
    const uint VK_PRESENT_MODE_FIFO_KHR = 2;
    const uint VK_PRESENT_MODE_MAILBOX_KHR = 1;
    const uint VK_PRESENT_MODE_IMMEDIATE_KHR = 0;
    
    const uint VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT = 0x00000010;
    const uint VK_SHARING_MODE_EXCLUSIVE = 0;
    const uint VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR = 0x00000001;
    
    const uint VK_IMAGE_VIEW_TYPE_2D = 1;
    const uint VK_COMPONENT_SWIZZLE_IDENTITY = 0;
    const uint VK_IMAGE_ASPECT_COLOR_BIT = 0x00000001;
    
    const uint VK_ATTACHMENT_LOAD_OP_CLEAR = 1;
    const uint VK_ATTACHMENT_STORE_OP_STORE = 0;
    const uint VK_ATTACHMENT_LOAD_OP_DONT_CARE = 2;
    const uint VK_ATTACHMENT_STORE_OP_DONT_CARE = 1;
    const uint VK_IMAGE_LAYOUT_UNDEFINED = 0;
    const uint VK_IMAGE_LAYOUT_PRESENT_SRC_KHR = 1000001002;
    const uint VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL = 2;
    const uint VK_SAMPLE_COUNT_1_BIT = 0x00000001;
    
    const uint VK_PIPELINE_BIND_POINT_GRAPHICS = 0;
    const uint VK_SUBPASS_EXTERNAL = 0xFFFFFFFF;
    const uint VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT = 0x00000100;
    const uint VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT = 0x00000400;
    
    const uint VK_SHADER_STAGE_VERTEX_BIT = 0x00000001;
    const uint VK_SHADER_STAGE_FRAGMENT_BIT = 0x00000010;
    
    const uint VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST = 3;
    const uint VK_POLYGON_MODE_FILL = 0;
    const uint VK_CULL_MODE_NONE = 0;
    const uint VK_FRONT_FACE_CLOCKWISE = 0;
    const uint VK_FRONT_FACE_COUNTER_CLOCKWISE = 1;
    const uint VK_LOGIC_OP_COPY = 3;
    const uint VK_BLEND_FACTOR_ONE = 1;
    const uint VK_BLEND_FACTOR_ZERO = 0;
    const uint VK_BLEND_OP_ADD = 0;
    const uint VK_COLOR_COMPONENT_R_BIT = 0x00000001;
    const uint VK_COLOR_COMPONENT_G_BIT = 0x00000002;
    const uint VK_COLOR_COMPONENT_B_BIT = 0x00000004;
    const uint VK_COLOR_COMPONENT_A_BIT = 0x00000008;
    
    const uint VK_DYNAMIC_STATE_VIEWPORT = 0;
    const uint VK_DYNAMIC_STATE_SCISSOR = 1;
    
    const uint VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT = 0x00000002;
    const uint VK_COMMAND_BUFFER_LEVEL_PRIMARY = 0;
    const uint VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT = 0x00000001;
    const uint VK_SUBPASS_CONTENTS_INLINE = 0;
    const uint VK_INDEX_TYPE_UINT16 = 0;
    const uint VK_FENCE_CREATE_SIGNALED_BIT = 0x00000001;
    
    const ulong VK_WHOLE_SIZE = 0xFFFFFFFFFFFFFFFF;
    const ulong UINT64_MAX = 0xFFFFFFFFFFFFFFFF;
    
    const int MAX_FRAMES_IN_FLIGHT = 2;
    #endregion

    #region Structures
    [StructLayout(LayoutKind.Sequential)]
    struct VkApplicationInfo
    {
        public uint sType;
        public IntPtr pNext;
        public IntPtr pApplicationName;
        public uint applicationVersion;
        public IntPtr pEngineName;
        public uint engineVersion;
        public uint apiVersion;
    }

    [StructLayout(LayoutKind.Sequential)]
    struct VkInstanceCreateInfo
    {
        public uint sType;
        public IntPtr pNext;
        public uint flags;
        public IntPtr pApplicationInfo;
        public uint enabledLayerCount;
        public IntPtr ppEnabledLayerNames;
        public uint enabledExtensionCount;
        public IntPtr ppEnabledExtensionNames;
    }

    [StructLayout(LayoutKind.Sequential)]
    struct VkDeviceQueueCreateInfo
    {
        public uint sType;
        public IntPtr pNext;
        public uint flags;
        public uint queueFamilyIndex;
        public uint queueCount;
        public IntPtr pQueuePriorities;
    }

    [StructLayout(LayoutKind.Sequential)]
    struct VkDeviceCreateInfo
    {
        public uint sType;
        public IntPtr pNext;
        public uint flags;
        public uint queueCreateInfoCount;
        public IntPtr pQueueCreateInfos;
        public uint enabledLayerCount;
        public IntPtr ppEnabledLayerNames;
        public uint enabledExtensionCount;
        public IntPtr ppEnabledExtensionNames;
        public IntPtr pEnabledFeatures;
    }

    [StructLayout(LayoutKind.Sequential)]
    struct VkQueueFamilyProperties
    {
        public uint queueFlags;
        public uint queueCount;
        public uint timestampValidBits;
        public VkExtent3D minImageTransferGranularity;
    }

    [StructLayout(LayoutKind.Sequential)]
    struct VkExtent3D
    {
        public uint width;
        public uint height;
        public uint depth;
    }

    [StructLayout(LayoutKind.Sequential)]
    struct VkExtent2D
    {
        public uint width;
        public uint height;
    }

    [StructLayout(LayoutKind.Sequential)]
    struct VkWin32SurfaceCreateInfoKHR
    {
        public uint sType;
        public IntPtr pNext;
        public uint flags;
        public IntPtr hinstance;
        public IntPtr hwnd;
    }

    [StructLayout(LayoutKind.Sequential)]
    struct VkSurfaceCapabilitiesKHR
    {
        public uint minImageCount;
        public uint maxImageCount;
        public VkExtent2D currentExtent;
        public VkExtent2D minImageExtent;
        public VkExtent2D maxImageExtent;
        public uint maxImageArrayLayers;
        public uint supportedTransforms;
        public uint currentTransform;
        public uint supportedCompositeAlpha;
        public uint supportedUsageFlags;
    }

    [StructLayout(LayoutKind.Sequential)]
    struct VkSurfaceFormatKHR
    {
        public uint format;
        public uint colorSpace;
    }

    [StructLayout(LayoutKind.Sequential)]
    struct VkSwapchainCreateInfoKHR
    {
        public uint sType;
        public IntPtr pNext;
        public uint flags;
        public IntPtr surface;
        public uint minImageCount;
        public uint imageFormat;
        public uint imageColorSpace;
        public VkExtent2D imageExtent;
        public uint imageArrayLayers;
        public uint imageUsage;
        public uint imageSharingMode;
        public uint queueFamilyIndexCount;
        public IntPtr pQueueFamilyIndices;
        public uint preTransform;
        public uint compositeAlpha;
        public uint presentMode;
        public uint clipped;
        public IntPtr oldSwapchain;
    }

    [StructLayout(LayoutKind.Sequential)]
    struct VkImageViewCreateInfo
    {
        public uint sType;
        public IntPtr pNext;
        public uint flags;
        public IntPtr image;
        public uint viewType;
        public uint format;
        public VkComponentMapping components;
        public VkImageSubresourceRange subresourceRange;
    }

    [StructLayout(LayoutKind.Sequential)]
    struct VkComponentMapping
    {
        public uint r;
        public uint g;
        public uint b;
        public uint a;
    }

    [StructLayout(LayoutKind.Sequential)]
    struct VkImageSubresourceRange
    {
        public uint aspectMask;
        public uint baseMipLevel;
        public uint levelCount;
        public uint baseArrayLayer;
        public uint layerCount;
    }

    [StructLayout(LayoutKind.Sequential)]
    struct VkAttachmentDescription
    {
        public uint flags;
        public uint format;
        public uint samples;
        public uint loadOp;
        public uint storeOp;
        public uint stencilLoadOp;
        public uint stencilStoreOp;
        public uint initialLayout;
        public uint finalLayout;
    }

    [StructLayout(LayoutKind.Sequential)]
    struct VkAttachmentReference
    {
        public uint attachment;
        public uint layout;
    }

    [StructLayout(LayoutKind.Sequential)]
    struct VkSubpassDescription
    {
        public uint flags;
        public uint pipelineBindPoint;
        public uint inputAttachmentCount;
        public IntPtr pInputAttachments;
        public uint colorAttachmentCount;
        public IntPtr pColorAttachments;
        public IntPtr pResolveAttachments;
        public IntPtr pDepthStencilAttachment;
        public uint preserveAttachmentCount;
        public IntPtr pPreserveAttachments;
    }

    [StructLayout(LayoutKind.Sequential)]
    struct VkSubpassDependency
    {
        public uint srcSubpass;
        public uint dstSubpass;
        public uint srcStageMask;
        public uint dstStageMask;
        public uint srcAccessMask;
        public uint dstAccessMask;
        public uint dependencyFlags;
    }

    [StructLayout(LayoutKind.Sequential)]
    struct VkRenderPassCreateInfo
    {
        public uint sType;
        public IntPtr pNext;
        public uint flags;
        public uint attachmentCount;
        public IntPtr pAttachments;
        public uint subpassCount;
        public IntPtr pSubpasses;
        public uint dependencyCount;
        public IntPtr pDependencies;
    }

    [StructLayout(LayoutKind.Sequential)]
    struct VkShaderModuleCreateInfo
    {
        public uint sType;
        public IntPtr pNext;
        public uint flags;
        public UIntPtr codeSize;
        public IntPtr pCode;
    }

    [StructLayout(LayoutKind.Sequential)]
    struct VkPipelineShaderStageCreateInfo
    {
        public uint sType;
        public IntPtr pNext;
        public uint flags;
        public uint stage;
        public IntPtr module;
        public IntPtr pName;
        public IntPtr pSpecializationInfo;
    }

    [StructLayout(LayoutKind.Sequential)]
    struct VkPipelineVertexInputStateCreateInfo
    {
        public uint sType;
        public IntPtr pNext;
        public uint flags;
        public uint vertexBindingDescriptionCount;
        public IntPtr pVertexBindingDescriptions;
        public uint vertexAttributeDescriptionCount;
        public IntPtr pVertexAttributeDescriptions;
    }

    [StructLayout(LayoutKind.Sequential)]
    struct VkPipelineInputAssemblyStateCreateInfo
    {
        public uint sType;
        public IntPtr pNext;
        public uint flags;
        public uint topology;
        public uint primitiveRestartEnable;
    }

    [StructLayout(LayoutKind.Sequential)]
    struct VkViewport
    {
        public float x;
        public float y;
        public float width;
        public float height;
        public float minDepth;
        public float maxDepth;
    }

    [StructLayout(LayoutKind.Sequential)]
    struct VkRect2D
    {
        public VkOffset2D offset;
        public VkExtent2D extent;
    }

    [StructLayout(LayoutKind.Sequential)]
    struct VkOffset2D
    {
        public int x;
        public int y;
    }

    [StructLayout(LayoutKind.Sequential)]
    struct VkPipelineViewportStateCreateInfo
    {
        public uint sType;
        public IntPtr pNext;
        public uint flags;
        public uint viewportCount;
        public IntPtr pViewports;
        public uint scissorCount;
        public IntPtr pScissors;
    }

    [StructLayout(LayoutKind.Sequential)]
    struct VkPipelineRasterizationStateCreateInfo
    {
        public uint sType;
        public IntPtr pNext;
        public uint flags;
        public uint depthClampEnable;
        public uint rasterizerDiscardEnable;
        public uint polygonMode;
        public uint cullMode;
        public uint frontFace;
        public uint depthBiasEnable;
        public float depthBiasConstantFactor;
        public float depthBiasClamp;
        public float depthBiasSlopeFactor;
        public float lineWidth;
    }

    [StructLayout(LayoutKind.Sequential)]
    struct VkPipelineMultisampleStateCreateInfo
    {
        public uint sType;
        public IntPtr pNext;
        public uint flags;
        public uint rasterizationSamples;
        public uint sampleShadingEnable;
        public float minSampleShading;
        public IntPtr pSampleMask;
        public uint alphaToCoverageEnable;
        public uint alphaToOneEnable;
    }

    [StructLayout(LayoutKind.Sequential)]
    struct VkPipelineColorBlendAttachmentState
    {
        public uint blendEnable;
        public uint srcColorBlendFactor;
        public uint dstColorBlendFactor;
        public uint colorBlendOp;
        public uint srcAlphaBlendFactor;
        public uint dstAlphaBlendFactor;
        public uint alphaBlendOp;
        public uint colorWriteMask;
    }

    [StructLayout(LayoutKind.Sequential)]
    struct VkPipelineColorBlendStateCreateInfo
    {
        public uint sType;
        public IntPtr pNext;
        public uint flags;
        public uint logicOpEnable;
        public uint logicOp;
        public uint attachmentCount;
        public IntPtr pAttachments;
        public float blendConstant0;
        public float blendConstant1;
        public float blendConstant2;
        public float blendConstant3;
    }

    [StructLayout(LayoutKind.Sequential)]
    struct VkPipelineDynamicStateCreateInfo
    {
        public uint sType;
        public IntPtr pNext;
        public uint flags;
        public uint dynamicStateCount;
        public IntPtr pDynamicStates;
    }

    [StructLayout(LayoutKind.Sequential)]
    struct VkPushConstantRange
    {
        public uint stageFlags;
        public uint offset;
        public uint size;
    }

    [StructLayout(LayoutKind.Sequential)]
    struct VkPipelineLayoutCreateInfo
    {
        public uint sType;
        public IntPtr pNext;
        public uint flags;
        public uint setLayoutCount;
        public IntPtr pSetLayouts;
        public uint pushConstantRangeCount;
        public IntPtr pPushConstantRanges;
    }

    [StructLayout(LayoutKind.Sequential)]
    struct VkGraphicsPipelineCreateInfo
    {
        public uint sType;
        public IntPtr pNext;
        public uint flags;
        public uint stageCount;
        public IntPtr pStages;
        public IntPtr pVertexInputState;
        public IntPtr pInputAssemblyState;
        public IntPtr pTessellationState;
        public IntPtr pViewportState;
        public IntPtr pRasterizationState;
        public IntPtr pMultisampleState;
        public IntPtr pDepthStencilState;
        public IntPtr pColorBlendState;
        public IntPtr pDynamicState;
        public IntPtr layout;
        public IntPtr renderPass;
        public uint subpass;
        public IntPtr basePipelineHandle;
        public int basePipelineIndex;
    }

    [StructLayout(LayoutKind.Sequential)]
    struct VkFramebufferCreateInfo
    {
        public uint sType;
        public IntPtr pNext;
        public uint flags;
        public IntPtr renderPass;
        public uint attachmentCount;
        public IntPtr pAttachments;
        public uint width;
        public uint height;
        public uint layers;
    }

    [StructLayout(LayoutKind.Sequential)]
    struct VkCommandPoolCreateInfo
    {
        public uint sType;
        public IntPtr pNext;
        public uint flags;
        public uint queueFamilyIndex;
    }

    [StructLayout(LayoutKind.Sequential)]
    struct VkCommandBufferAllocateInfo
    {
        public uint sType;
        public IntPtr pNext;
        public IntPtr commandPool;
        public uint level;
        public uint commandBufferCount;
    }

    [StructLayout(LayoutKind.Sequential)]
    struct VkCommandBufferBeginInfo
    {
        public uint sType;
        public IntPtr pNext;
        public uint flags;
        public IntPtr pInheritanceInfo;
    }

    [StructLayout(LayoutKind.Sequential)]
    struct VkRenderPassBeginInfo
    {
        public uint sType;
        public IntPtr pNext;
        public IntPtr renderPass;
        public IntPtr framebuffer;
        public VkRect2D renderArea;
        public uint clearValueCount;
        public IntPtr pClearValues;
    }

    [StructLayout(LayoutKind.Sequential)]
    struct VkClearValue
    {
        public float r;
        public float g;
        public float b;
        public float a;
    }

    [StructLayout(LayoutKind.Sequential)]
    struct VkSemaphoreCreateInfo
    {
        public uint sType;
        public IntPtr pNext;
        public uint flags;
    }

    [StructLayout(LayoutKind.Sequential)]
    struct VkFenceCreateInfo
    {
        public uint sType;
        public IntPtr pNext;
        public uint flags;
    }

    [StructLayout(LayoutKind.Sequential)]
    struct VkSubmitInfo
    {
        public uint sType;
        public IntPtr pNext;
        public uint waitSemaphoreCount;
        public IntPtr pWaitSemaphores;
        public IntPtr pWaitDstStageMask;
        public uint commandBufferCount;
        public IntPtr pCommandBuffers;
        public uint signalSemaphoreCount;
        public IntPtr pSignalSemaphores;
    }

    [StructLayout(LayoutKind.Sequential)]
    struct VkPresentInfoKHR
    {
        public uint sType;
        public IntPtr pNext;
        public uint waitSemaphoreCount;
        public IntPtr pWaitSemaphores;
        public uint swapchainCount;
        public IntPtr pSwapchains;
        public IntPtr pImageIndices;
        public IntPtr pResults;
    }

    [StructLayout(LayoutKind.Sequential)]
    struct PushConstants
    {
        public float iTime;
        public float padding;
        public float iResolutionX;
        public float iResolutionY;
    }
    #endregion

    #region DllImports
    [DllImport("vulkan-1.dll", CallingConvention = CallingConvention.StdCall)]
    static extern int vkCreateInstance(ref VkInstanceCreateInfo createInfo, IntPtr allocator, out IntPtr instance);
    
    [DllImport("vulkan-1.dll", CallingConvention = CallingConvention.StdCall)]
    static extern void vkDestroyInstance(IntPtr instance, IntPtr allocator);
    
    [DllImport("vulkan-1.dll", CallingConvention = CallingConvention.StdCall)]
    static extern int vkEnumeratePhysicalDevices(IntPtr instance, ref uint physicalDeviceCount, IntPtr[] physicalDevices);
    
    [DllImport("vulkan-1.dll", CallingConvention = CallingConvention.StdCall)]
    static extern void vkGetPhysicalDeviceQueueFamilyProperties(IntPtr physicalDevice, ref uint queueFamilyCount, [Out] VkQueueFamilyProperties[] queueFamilies);
    
    [DllImport("vulkan-1.dll", CallingConvention = CallingConvention.StdCall)]
    static extern int vkCreateDevice(IntPtr physicalDevice, ref VkDeviceCreateInfo createInfo, IntPtr allocator, out IntPtr device);
    
    [DllImport("vulkan-1.dll", CallingConvention = CallingConvention.StdCall)]
    static extern void vkDestroyDevice(IntPtr device, IntPtr allocator);
    
    [DllImport("vulkan-1.dll", CallingConvention = CallingConvention.StdCall)]
    static extern void vkGetDeviceQueue(IntPtr device, uint queueFamilyIndex, uint queueIndex, out IntPtr queue);
    
    [DllImport("vulkan-1.dll", CallingConvention = CallingConvention.StdCall)]
    static extern int vkCreateWin32SurfaceKHR(IntPtr instance, ref VkWin32SurfaceCreateInfoKHR createInfo, IntPtr allocator, out IntPtr surface);
    
    [DllImport("vulkan-1.dll", CallingConvention = CallingConvention.StdCall)]
    static extern void vkDestroySurfaceKHR(IntPtr instance, IntPtr surface, IntPtr allocator);
    
    [DllImport("vulkan-1.dll", CallingConvention = CallingConvention.StdCall)]
    static extern int vkGetPhysicalDeviceSurfaceSupportKHR(IntPtr physicalDevice, uint queueFamilyIndex, IntPtr surface, out uint supported);
    
    [DllImport("vulkan-1.dll", CallingConvention = CallingConvention.StdCall)]
    static extern int vkGetPhysicalDeviceSurfaceCapabilitiesKHR(IntPtr physicalDevice, IntPtr surface, out VkSurfaceCapabilitiesKHR surfaceCapabilities);
    
    [DllImport("vulkan-1.dll", CallingConvention = CallingConvention.StdCall)]
    static extern int vkGetPhysicalDeviceSurfaceFormatsKHR(IntPtr physicalDevice, IntPtr surface, ref uint formatCount, [Out] VkSurfaceFormatKHR[] formats);
    
    [DllImport("vulkan-1.dll", CallingConvention = CallingConvention.StdCall)]
    static extern int vkGetPhysicalDeviceSurfacePresentModesKHR(IntPtr physicalDevice, IntPtr surface, ref uint presentModeCount, [Out] uint[] presentModes);
    
    [DllImport("vulkan-1.dll", CallingConvention = CallingConvention.StdCall)]
    static extern int vkCreateSwapchainKHR(IntPtr device, ref VkSwapchainCreateInfoKHR createInfo, IntPtr allocator, out IntPtr swapchain);
    
    [DllImport("vulkan-1.dll", CallingConvention = CallingConvention.StdCall)]
    static extern void vkDestroySwapchainKHR(IntPtr device, IntPtr swapchain, IntPtr allocator);
    
    [DllImport("vulkan-1.dll", CallingConvention = CallingConvention.StdCall)]
    static extern int vkGetSwapchainImagesKHR(IntPtr device, IntPtr swapchain, ref uint imageCount, [Out] IntPtr[] images);
    
    [DllImport("vulkan-1.dll", CallingConvention = CallingConvention.StdCall)]
    static extern int vkCreateImageView(IntPtr device, ref VkImageViewCreateInfo createInfo, IntPtr allocator, out IntPtr imageView);
    
    [DllImport("vulkan-1.dll", CallingConvention = CallingConvention.StdCall)]
    static extern void vkDestroyImageView(IntPtr device, IntPtr imageView, IntPtr allocator);
    
    [DllImport("vulkan-1.dll", CallingConvention = CallingConvention.StdCall)]
    static extern int vkCreateRenderPass(IntPtr device, ref VkRenderPassCreateInfo createInfo, IntPtr allocator, out IntPtr renderPass);
    
    [DllImport("vulkan-1.dll", CallingConvention = CallingConvention.StdCall)]
    static extern void vkDestroyRenderPass(IntPtr device, IntPtr renderPass, IntPtr allocator);
    
    [DllImport("vulkan-1.dll", CallingConvention = CallingConvention.StdCall)]
    static extern int vkCreateShaderModule(IntPtr device, ref VkShaderModuleCreateInfo createInfo, IntPtr allocator, out IntPtr shaderModule);
    
    [DllImport("vulkan-1.dll", CallingConvention = CallingConvention.StdCall)]
    static extern void vkDestroyShaderModule(IntPtr device, IntPtr shaderModule, IntPtr allocator);
    
    [DllImport("vulkan-1.dll", CallingConvention = CallingConvention.StdCall)]
    static extern int vkCreatePipelineLayout(IntPtr device, ref VkPipelineLayoutCreateInfo createInfo, IntPtr allocator, out IntPtr pipelineLayout);
    
    [DllImport("vulkan-1.dll", CallingConvention = CallingConvention.StdCall)]
    static extern void vkDestroyPipelineLayout(IntPtr device, IntPtr pipelineLayout, IntPtr allocator);
    
    [DllImport("vulkan-1.dll", CallingConvention = CallingConvention.StdCall)]
    static extern int vkCreateGraphicsPipelines(IntPtr device, IntPtr pipelineCache, uint createInfoCount, ref VkGraphicsPipelineCreateInfo createInfos, IntPtr allocator, out IntPtr pipelines);
    
    [DllImport("vulkan-1.dll", CallingConvention = CallingConvention.StdCall)]
    static extern void vkDestroyPipeline(IntPtr device, IntPtr pipeline, IntPtr allocator);
    
    [DllImport("vulkan-1.dll", CallingConvention = CallingConvention.StdCall)]
    static extern int vkCreateFramebuffer(IntPtr device, ref VkFramebufferCreateInfo createInfo, IntPtr allocator, out IntPtr framebuffer);
    
    [DllImport("vulkan-1.dll", CallingConvention = CallingConvention.StdCall)]
    static extern void vkDestroyFramebuffer(IntPtr device, IntPtr framebuffer, IntPtr allocator);
    
    [DllImport("vulkan-1.dll", CallingConvention = CallingConvention.StdCall)]
    static extern int vkCreateCommandPool(IntPtr device, ref VkCommandPoolCreateInfo createInfo, IntPtr allocator, out IntPtr commandPool);
    
    [DllImport("vulkan-1.dll", CallingConvention = CallingConvention.StdCall)]
    static extern void vkDestroyCommandPool(IntPtr device, IntPtr commandPool, IntPtr allocator);
    
    [DllImport("vulkan-1.dll", CallingConvention = CallingConvention.StdCall)]
    static extern int vkAllocateCommandBuffers(IntPtr device, ref VkCommandBufferAllocateInfo allocateInfo, [Out] IntPtr[] commandBuffers);
    
    [DllImport("vulkan-1.dll", CallingConvention = CallingConvention.StdCall)]
    static extern int vkBeginCommandBuffer(IntPtr commandBuffer, ref VkCommandBufferBeginInfo beginInfo);
    
    [DllImport("vulkan-1.dll", CallingConvention = CallingConvention.StdCall)]
    static extern void vkCmdBeginRenderPass(IntPtr commandBuffer, ref VkRenderPassBeginInfo renderPassBegin, uint contents);
    
    [DllImport("vulkan-1.dll", CallingConvention = CallingConvention.StdCall)]
    static extern void vkCmdBindPipeline(IntPtr commandBuffer, uint pipelineBindPoint, IntPtr pipeline);
    
    [DllImport("vulkan-1.dll", CallingConvention = CallingConvention.StdCall)]
    static extern void vkCmdSetViewport(IntPtr commandBuffer, uint firstViewport, uint viewportCount, ref VkViewport viewports);
    
    [DllImport("vulkan-1.dll", CallingConvention = CallingConvention.StdCall)]
    static extern void vkCmdSetScissor(IntPtr commandBuffer, uint firstScissor, uint scissorCount, ref VkRect2D scissors);
    
    [DllImport("vulkan-1.dll", CallingConvention = CallingConvention.StdCall)]
    static extern void vkCmdDraw(IntPtr commandBuffer, uint vertexCount, uint instanceCount, uint firstVertex, uint firstInstance);
    
    [DllImport("vulkan-1.dll", CallingConvention = CallingConvention.StdCall)]
    static extern void vkCmdEndRenderPass(IntPtr commandBuffer);
    
    [DllImport("vulkan-1.dll", CallingConvention = CallingConvention.StdCall)]
    static extern int vkEndCommandBuffer(IntPtr commandBuffer);
    
    [DllImport("vulkan-1.dll", CallingConvention = CallingConvention.StdCall)]
    static extern int vkCreateSemaphore(IntPtr device, ref VkSemaphoreCreateInfo createInfo, IntPtr allocator, out IntPtr semaphore);
    
    [DllImport("vulkan-1.dll", CallingConvention = CallingConvention.StdCall)]
    static extern void vkDestroySemaphore(IntPtr device, IntPtr semaphore, IntPtr allocator);
    
    [DllImport("vulkan-1.dll", CallingConvention = CallingConvention.StdCall)]
    static extern int vkCreateFence(IntPtr device, ref VkFenceCreateInfo createInfo, IntPtr allocator, out IntPtr fence);
    
    [DllImport("vulkan-1.dll", CallingConvention = CallingConvention.StdCall)]
    static extern void vkDestroyFence(IntPtr device, IntPtr fence, IntPtr allocator);
    
    [DllImport("vulkan-1.dll", CallingConvention = CallingConvention.StdCall)]
    static extern int vkWaitForFences(IntPtr device, uint fenceCount, IntPtr[] fences, uint waitAll, ulong timeout);
    
    [DllImport("vulkan-1.dll", CallingConvention = CallingConvention.StdCall)]
    static extern int vkResetFences(IntPtr device, uint fenceCount, IntPtr[] fences);
    
    [DllImport("vulkan-1.dll", CallingConvention = CallingConvention.StdCall)]
    static extern int vkResetCommandBuffer(IntPtr commandBuffer, uint flags);
    
    [DllImport("vulkan-1.dll", CallingConvention = CallingConvention.StdCall)]
    static extern int vkAcquireNextImageKHR(IntPtr device, IntPtr swapchain, ulong timeout, IntPtr semaphore, IntPtr fence, out uint imageIndex);
    
    [DllImport("vulkan-1.dll", CallingConvention = CallingConvention.StdCall)]
    static extern int vkQueueSubmit(IntPtr queue, uint submitCount, ref VkSubmitInfo submitInfo, IntPtr fence);
    
    [DllImport("vulkan-1.dll", CallingConvention = CallingConvention.StdCall)]
    static extern int vkQueuePresentKHR(IntPtr queue, ref VkPresentInfoKHR presentInfo);
    
    [DllImport("vulkan-1.dll", CallingConvention = CallingConvention.StdCall)]
    static extern int vkDeviceWaitIdle(IntPtr device);
    
    [DllImport("vulkan-1.dll", CallingConvention = CallingConvention.StdCall)]
    static extern void vkCmdPushConstants(IntPtr commandBuffer, IntPtr layout, uint stageFlags, uint offset, uint size, IntPtr pValues);
    
    [DllImport("kernel32.dll")]
    static extern IntPtr GetModuleHandle(string moduleName);
    #endregion

    #region Member Variables
    IntPtr instance;
    IntPtr physicalDevice;
    IntPtr device;
    IntPtr graphicsQueue;
    IntPtr presentQueue;
    IntPtr surface;
    IntPtr swapchain;
    IntPtr[] swapchainImages;
    IntPtr[] swapchainImageViews;
    IntPtr renderPass;
    IntPtr pipelineLayout;
    IntPtr graphicsPipeline;
    IntPtr[] swapchainFramebuffers;
    IntPtr commandPool;
    IntPtr[] commandBuffers;
    IntPtr[] imageAvailableSemaphores;
    IntPtr[] renderFinishedSemaphores;
    IntPtr[] inFlightFences;
    
    uint graphicsQueueFamily;
    uint presentQueueFamily;
    uint swapchainImageFormat;
    VkExtent2D swapchainExtent;
    
    int currentFrame = 0;
    bool framebufferResized = false;
    
    Stopwatch stopwatch;
    Timer timer;
    #endregion

    public VulkanRaymarching()
    {
        this.Size = new Size(800, 600);
        this.Text = "Raymarching - Vulkan 1.4 / C#";
        this.SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.UserPaint, true);
        
        stopwatch = new Stopwatch();
    }

    protected override void OnHandleCreated(EventArgs e)
    {
        base.OnHandleCreated(e);
        
        try
        {
            InitVulkan();
            
            stopwatch.Start();
            
            timer = new Timer();
            timer.Interval = 16; // ~60 FPS
            timer.Tick += (s, args) => DrawFrame();
            timer.Start();
        }
        catch (Exception ex)
        {
            MessageBox.Show($"Vulkan initialization failed:\n{ex.Message}\n\n{ex.StackTrace}", "Error", MessageBoxButtons.OK, MessageBoxIcon.Error);
            Close();
        }
    }

    protected override void OnResize(EventArgs e)
    {
        base.OnResize(e);
        framebufferResized = true;
    }

    protected override void OnClosed(EventArgs e)
    {
        base.OnClosed(e);
        
        if (timer != null)
        {
            timer.Stop();
        }
        
        CleanupVulkan();
    }

    void InitVulkan()
    {
        CreateInstance();
        CreateSurface();
        PickPhysicalDevice();
        CreateLogicalDevice();
        CreateSwapchain();
        CreateImageViews();
        CreateRenderPass();
        CreateGraphicsPipeline();
        CreateFramebuffers();
        CreateCommandPool();
        CreateCommandBuffers();
        CreateSyncObjects();
    }

    void CleanupVulkan()
    {
        if (device != IntPtr.Zero)
        {
            vkDeviceWaitIdle(device);
            
            CleanupSwapchain();
            
            for (int i = 0; i < MAX_FRAMES_IN_FLIGHT; i++)
            {
                if (imageAvailableSemaphores != null && imageAvailableSemaphores[i] != IntPtr.Zero)
                    vkDestroySemaphore(device, imageAvailableSemaphores[i], IntPtr.Zero);
                if (renderFinishedSemaphores != null && renderFinishedSemaphores[i] != IntPtr.Zero)
                    vkDestroySemaphore(device, renderFinishedSemaphores[i], IntPtr.Zero);
                if (inFlightFences != null && inFlightFences[i] != IntPtr.Zero)
                    vkDestroyFence(device, inFlightFences[i], IntPtr.Zero);
            }
            
            if (commandPool != IntPtr.Zero)
                vkDestroyCommandPool(device, commandPool, IntPtr.Zero);
            
            vkDestroyDevice(device, IntPtr.Zero);
        }
        
        if (instance != IntPtr.Zero)
        {
            if (surface != IntPtr.Zero)
                vkDestroySurfaceKHR(instance, surface, IntPtr.Zero);
            
            vkDestroyInstance(instance, IntPtr.Zero);
        }
    }

    void CleanupSwapchain()
    {
        if (swapchainFramebuffers != null)
        {
            foreach (var fb in swapchainFramebuffers)
            {
                if (fb != IntPtr.Zero)
                    vkDestroyFramebuffer(device, fb, IntPtr.Zero);
            }
        }
        
        if (graphicsPipeline != IntPtr.Zero)
            vkDestroyPipeline(device, graphicsPipeline, IntPtr.Zero);
        
        if (pipelineLayout != IntPtr.Zero)
            vkDestroyPipelineLayout(device, pipelineLayout, IntPtr.Zero);
        
        if (renderPass != IntPtr.Zero)
            vkDestroyRenderPass(device, renderPass, IntPtr.Zero);
        
        if (swapchainImageViews != null)
        {
            foreach (var iv in swapchainImageViews)
            {
                if (iv != IntPtr.Zero)
                    vkDestroyImageView(device, iv, IntPtr.Zero);
            }
        }
        
        if (swapchain != IntPtr.Zero)
            vkDestroySwapchainKHR(device, swapchain, IntPtr.Zero);
    }

    void RecreateSwapchain()
    {
        if (ClientSize.Width == 0 || ClientSize.Height == 0)
            return;
        
        vkDeviceWaitIdle(device);
        
        CleanupSwapchain();
        
        CreateSwapchain();
        CreateImageViews();
        CreateRenderPass();
        CreateGraphicsPipeline();
        CreateFramebuffers();
    }

    void CreateInstance()
    {
        var appName = Marshal.StringToHGlobalAnsi("Vulkan Raymarching");
        var engineName = Marshal.StringToHGlobalAnsi("No Engine");
        
        var appInfo = new VkApplicationInfo
        {
            sType = VK_STRUCTURE_TYPE_APPLICATION_INFO,
            pNext = IntPtr.Zero,
            pApplicationName = appName,
            applicationVersion = 1,
            pEngineName = engineName,
            engineVersion = 1,
            apiVersion = VK_API_VERSION_1_4
        };
        
        var appInfoPtr = Marshal.AllocHGlobal(Marshal.SizeOf<VkApplicationInfo>());
        Marshal.StructureToPtr(appInfo, appInfoPtr, false);
        
        var extensions = new string[] { "VK_KHR_surface", "VK_KHR_win32_surface" };
        var extensionPtrs = new IntPtr[extensions.Length];
        for (int i = 0; i < extensions.Length; i++)
        {
            extensionPtrs[i] = Marshal.StringToHGlobalAnsi(extensions[i]);
        }
        
        var extensionArrayPtr = Marshal.AllocHGlobal(IntPtr.Size * extensions.Length);
        Marshal.Copy(extensionPtrs, 0, extensionArrayPtr, extensions.Length);
        
        var createInfo = new VkInstanceCreateInfo
        {
            sType = VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
            pNext = IntPtr.Zero,
            flags = 0,
            pApplicationInfo = appInfoPtr,
            enabledLayerCount = 0,
            ppEnabledLayerNames = IntPtr.Zero,
            enabledExtensionCount = (uint)extensions.Length,
            ppEnabledExtensionNames = extensionArrayPtr
        };
        
        int result = vkCreateInstance(ref createInfo, IntPtr.Zero, out instance);
        
        Marshal.FreeHGlobal(appName);
        Marshal.FreeHGlobal(engineName);
        Marshal.FreeHGlobal(appInfoPtr);
        foreach (var ptr in extensionPtrs)
            Marshal.FreeHGlobal(ptr);
        Marshal.FreeHGlobal(extensionArrayPtr);
        
        if (result != VK_SUCCESS)
            throw new Exception($"Failed to create Vulkan instance: {result}");
    }

    void CreateSurface()
    {
        var createInfo = new VkWin32SurfaceCreateInfoKHR
        {
            sType = VK_STRUCTURE_TYPE_WIN32_SURFACE_CREATE_INFO_KHR,
            pNext = IntPtr.Zero,
            flags = 0,
            hinstance = GetModuleHandle(null),
            hwnd = this.Handle
        };
        
        int result = vkCreateWin32SurfaceKHR(instance, ref createInfo, IntPtr.Zero, out surface);
        if (result != VK_SUCCESS)
            throw new Exception($"Failed to create window surface: {result}");
    }

    void PickPhysicalDevice()
    {
        uint deviceCount = 0;
        vkEnumeratePhysicalDevices(instance, ref deviceCount, null);
        
        if (deviceCount == 0)
            throw new Exception("No Vulkan-compatible GPU found");
        
        var devices = new IntPtr[deviceCount];
        vkEnumeratePhysicalDevices(instance, ref deviceCount, devices);
        
        physicalDevice = devices[0];
        
        uint queueFamilyCount = 0;
        vkGetPhysicalDeviceQueueFamilyProperties(physicalDevice, ref queueFamilyCount, null);
        
        var queueFamilies = new VkQueueFamilyProperties[queueFamilyCount];
        vkGetPhysicalDeviceQueueFamilyProperties(physicalDevice, ref queueFamilyCount, queueFamilies);
        
        graphicsQueueFamily = uint.MaxValue;
        presentQueueFamily = uint.MaxValue;
        
        for (uint i = 0; i < queueFamilyCount; i++)
        {
            if ((queueFamilies[i].queueFlags & VK_QUEUE_GRAPHICS_BIT) != 0)
            {
                graphicsQueueFamily = i;
            }
            
            uint presentSupport = 0;
            vkGetPhysicalDeviceSurfaceSupportKHR(physicalDevice, i, surface, out presentSupport);
            if (presentSupport == VK_TRUE)
            {
                presentQueueFamily = i;
            }
            
            if (graphicsQueueFamily != uint.MaxValue && presentQueueFamily != uint.MaxValue)
                break;
        }
        
        if (graphicsQueueFamily == uint.MaxValue || presentQueueFamily == uint.MaxValue)
            throw new Exception("No suitable queue family found");
    }

    void CreateLogicalDevice()
    {
        var uniqueQueueFamilies = new HashSet<uint> { graphicsQueueFamily, presentQueueFamily };
        var queueCreateInfos = new List<VkDeviceQueueCreateInfo>();
        var queuePriorityPtrs = new List<IntPtr>();
        
        foreach (var queueFamily in uniqueQueueFamilies)
        {
            var priorityPtr = Marshal.AllocHGlobal(sizeof(float));
            Marshal.Copy(new float[] { 1.0f }, 0, priorityPtr, 1);
            queuePriorityPtrs.Add(priorityPtr);
            
            var queueCreateInfo = new VkDeviceQueueCreateInfo
            {
                sType = VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
                pNext = IntPtr.Zero,
                flags = 0,
                queueFamilyIndex = queueFamily,
                queueCount = 1,
                pQueuePriorities = priorityPtr
            };
            queueCreateInfos.Add(queueCreateInfo);
        }
        
        var queueCreateInfoArray = queueCreateInfos.ToArray();
        var queueCreateInfoPtr = Marshal.AllocHGlobal(Marshal.SizeOf<VkDeviceQueueCreateInfo>() * queueCreateInfoArray.Length);
        for (int i = 0; i < queueCreateInfoArray.Length; i++)
        {
            Marshal.StructureToPtr(queueCreateInfoArray[i], queueCreateInfoPtr + i * Marshal.SizeOf<VkDeviceQueueCreateInfo>(), false);
        }
        
        var extensions = new string[] { "VK_KHR_swapchain" };
        var extensionPtrs = new IntPtr[extensions.Length];
        for (int i = 0; i < extensions.Length; i++)
        {
            extensionPtrs[i] = Marshal.StringToHGlobalAnsi(extensions[i]);
        }
        
        var extensionArrayPtr = Marshal.AllocHGlobal(IntPtr.Size * extensions.Length);
        Marshal.Copy(extensionPtrs, 0, extensionArrayPtr, extensions.Length);
        
        var deviceCreateInfo = new VkDeviceCreateInfo
        {
            sType = VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO,
            pNext = IntPtr.Zero,
            flags = 0,
            queueCreateInfoCount = (uint)queueCreateInfoArray.Length,
            pQueueCreateInfos = queueCreateInfoPtr,
            enabledLayerCount = 0,
            ppEnabledLayerNames = IntPtr.Zero,
            enabledExtensionCount = (uint)extensions.Length,
            ppEnabledExtensionNames = extensionArrayPtr,
            pEnabledFeatures = IntPtr.Zero
        };
        
        int result = vkCreateDevice(physicalDevice, ref deviceCreateInfo, IntPtr.Zero, out device);
        
        foreach (var ptr in queuePriorityPtrs)
            Marshal.FreeHGlobal(ptr);
        Marshal.FreeHGlobal(queueCreateInfoPtr);
        foreach (var ptr in extensionPtrs)
            Marshal.FreeHGlobal(ptr);
        Marshal.FreeHGlobal(extensionArrayPtr);
        
        if (result != VK_SUCCESS)
            throw new Exception($"Failed to create logical device: {result}");
        
        vkGetDeviceQueue(device, graphicsQueueFamily, 0, out graphicsQueue);
        vkGetDeviceQueue(device, presentQueueFamily, 0, out presentQueue);
    }

    void CreateSwapchain()
    {
        VkSurfaceCapabilitiesKHR capabilities;
        vkGetPhysicalDeviceSurfaceCapabilitiesKHR(physicalDevice, surface, out capabilities);
        
        uint formatCount = 0;
        vkGetPhysicalDeviceSurfaceFormatsKHR(physicalDevice, surface, ref formatCount, null);
        var formats = new VkSurfaceFormatKHR[formatCount];
        vkGetPhysicalDeviceSurfaceFormatsKHR(physicalDevice, surface, ref formatCount, formats);
        
        uint presentModeCount = 0;
        vkGetPhysicalDeviceSurfacePresentModesKHR(physicalDevice, surface, ref presentModeCount, null);
        var presentModes = new uint[presentModeCount];
        vkGetPhysicalDeviceSurfacePresentModesKHR(physicalDevice, surface, ref presentModeCount, presentModes);
        
        // Choose surface format (prefer UNORM to avoid double gamma correction)
        var surfaceFormat = formats[0];
        foreach (var format in formats)
        {
            if (format.format == VK_FORMAT_B8G8R8A8_UNORM && format.colorSpace == VK_COLOR_SPACE_SRGB_NONLINEAR_KHR)
            {
                surfaceFormat = format;
                break;
            }
        }
        swapchainImageFormat = surfaceFormat.format;
        
        // Choose present mode (prefer Mailbox for smooth animation)
        uint presentMode = VK_PRESENT_MODE_FIFO_KHR;
        foreach (var mode in presentModes)
        {
            if (mode == VK_PRESENT_MODE_MAILBOX_KHR)
            {
                presentMode = mode;
                break;
            }
        }
        
        // Choose swap extent
        if (capabilities.currentExtent.width != uint.MaxValue)
        {
            swapchainExtent = capabilities.currentExtent;
        }
        else
        {
            swapchainExtent.width = (uint)Math.Max((int)capabilities.minImageExtent.width, Math.Min(ClientSize.Width, (int)capabilities.maxImageExtent.width));
            swapchainExtent.height = (uint)Math.Max((int)capabilities.minImageExtent.height, Math.Min(ClientSize.Height, (int)capabilities.maxImageExtent.height));
        }
        
        uint imageCount = capabilities.minImageCount + 1;
        if (capabilities.maxImageCount > 0 && imageCount > capabilities.maxImageCount)
        {
            imageCount = capabilities.maxImageCount;
        }
        
        var createInfo = new VkSwapchainCreateInfoKHR
        {
            sType = VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR,
            pNext = IntPtr.Zero,
            flags = 0,
            surface = surface,
            minImageCount = imageCount,
            imageFormat = surfaceFormat.format,
            imageColorSpace = surfaceFormat.colorSpace,
            imageExtent = swapchainExtent,
            imageArrayLayers = 1,
            imageUsage = VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT,
            imageSharingMode = VK_SHARING_MODE_EXCLUSIVE,
            queueFamilyIndexCount = 0,
            pQueueFamilyIndices = IntPtr.Zero,
            preTransform = capabilities.currentTransform,
            compositeAlpha = VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR,
            presentMode = presentMode,
            clipped = VK_TRUE,
            oldSwapchain = IntPtr.Zero
        };
        
        int result = vkCreateSwapchainKHR(device, ref createInfo, IntPtr.Zero, out swapchain);
        if (result != VK_SUCCESS)
            throw new Exception($"Failed to create swapchain: {result}");
        
        uint swapchainImageCount = 0;
        vkGetSwapchainImagesKHR(device, swapchain, ref swapchainImageCount, null);
        swapchainImages = new IntPtr[swapchainImageCount];
        vkGetSwapchainImagesKHR(device, swapchain, ref swapchainImageCount, swapchainImages);
    }

    void CreateImageViews()
    {
        swapchainImageViews = new IntPtr[swapchainImages.Length];
        
        for (int i = 0; i < swapchainImages.Length; i++)
        {
            var createInfo = new VkImageViewCreateInfo
            {
                sType = VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO,
                pNext = IntPtr.Zero,
                flags = 0,
                image = swapchainImages[i],
                viewType = VK_IMAGE_VIEW_TYPE_2D,
                format = swapchainImageFormat,
                components = new VkComponentMapping
                {
                    r = VK_COMPONENT_SWIZZLE_IDENTITY,
                    g = VK_COMPONENT_SWIZZLE_IDENTITY,
                    b = VK_COMPONENT_SWIZZLE_IDENTITY,
                    a = VK_COMPONENT_SWIZZLE_IDENTITY
                },
                subresourceRange = new VkImageSubresourceRange
                {
                    aspectMask = VK_IMAGE_ASPECT_COLOR_BIT,
                    baseMipLevel = 0,
                    levelCount = 1,
                    baseArrayLayer = 0,
                    layerCount = 1
                }
            };
            
            int result = vkCreateImageView(device, ref createInfo, IntPtr.Zero, out swapchainImageViews[i]);
            if (result != VK_SUCCESS)
                throw new Exception($"Failed to create image view: {result}");
        }
    }

    void CreateRenderPass()
    {
        var colorAttachment = new VkAttachmentDescription
        {
            flags = 0,
            format = swapchainImageFormat,
            samples = VK_SAMPLE_COUNT_1_BIT,
            loadOp = VK_ATTACHMENT_LOAD_OP_CLEAR,
            storeOp = VK_ATTACHMENT_STORE_OP_STORE,
            stencilLoadOp = VK_ATTACHMENT_LOAD_OP_DONT_CARE,
            stencilStoreOp = VK_ATTACHMENT_STORE_OP_DONT_CARE,
            initialLayout = VK_IMAGE_LAYOUT_UNDEFINED,
            finalLayout = VK_IMAGE_LAYOUT_PRESENT_SRC_KHR
        };
        
        var colorAttachmentRef = new VkAttachmentReference
        {
            attachment = 0,
            layout = VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL
        };
        
        var colorAttachmentRefPtr = Marshal.AllocHGlobal(Marshal.SizeOf<VkAttachmentReference>());
        Marshal.StructureToPtr(colorAttachmentRef, colorAttachmentRefPtr, false);
        
        var subpass = new VkSubpassDescription
        {
            flags = 0,
            pipelineBindPoint = VK_PIPELINE_BIND_POINT_GRAPHICS,
            inputAttachmentCount = 0,
            pInputAttachments = IntPtr.Zero,
            colorAttachmentCount = 1,
            pColorAttachments = colorAttachmentRefPtr,
            pResolveAttachments = IntPtr.Zero,
            pDepthStencilAttachment = IntPtr.Zero,
            preserveAttachmentCount = 0,
            pPreserveAttachments = IntPtr.Zero
        };
        
        var dependency = new VkSubpassDependency
        {
            srcSubpass = VK_SUBPASS_EXTERNAL,
            dstSubpass = 0,
            srcStageMask = VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT,
            dstStageMask = VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT,
            srcAccessMask = 0,
            dstAccessMask = VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT,
            dependencyFlags = 0
        };
        
        var colorAttachmentPtr = Marshal.AllocHGlobal(Marshal.SizeOf<VkAttachmentDescription>());
        Marshal.StructureToPtr(colorAttachment, colorAttachmentPtr, false);
        
        var subpassPtr = Marshal.AllocHGlobal(Marshal.SizeOf<VkSubpassDescription>());
        Marshal.StructureToPtr(subpass, subpassPtr, false);
        
        var dependencyPtr = Marshal.AllocHGlobal(Marshal.SizeOf<VkSubpassDependency>());
        Marshal.StructureToPtr(dependency, dependencyPtr, false);
        
        var renderPassInfo = new VkRenderPassCreateInfo
        {
            sType = VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO,
            pNext = IntPtr.Zero,
            flags = 0,
            attachmentCount = 1,
            pAttachments = colorAttachmentPtr,
            subpassCount = 1,
            pSubpasses = subpassPtr,
            dependencyCount = 1,
            pDependencies = dependencyPtr
        };
        
        int result = vkCreateRenderPass(device, ref renderPassInfo, IntPtr.Zero, out renderPass);
        
        Marshal.FreeHGlobal(colorAttachmentRefPtr);
        Marshal.FreeHGlobal(colorAttachmentPtr);
        Marshal.FreeHGlobal(subpassPtr);
        Marshal.FreeHGlobal(dependencyPtr);
        
        if (result != VK_SUCCESS)
            throw new Exception($"Failed to create render pass: {result}");
    }

    byte[] CompileShader(string filename, string stage)
    {
        string spvFile = Path.GetTempFileName();
        
        var startInfo = new ProcessStartInfo
        {
            FileName = "glslangValidator",
            Arguments = $"-V -S {stage} \"{filename}\" -o \"{spvFile}\"",
            UseShellExecute = false,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            CreateNoWindow = true
        };
        
        using (var process = Process.Start(startInfo))
        {
            string output = process.StandardOutput.ReadToEnd();
            string error = process.StandardError.ReadToEnd();
            process.WaitForExit();
            
            if (process.ExitCode != 0)
            {
                throw new Exception($"Shader compilation failed for {filename}:\n{output}\n{error}");
            }
        }
        
        byte[] spirvCode = File.ReadAllBytes(spvFile);
        File.Delete(spvFile);
        
        return spirvCode;
    }

    IntPtr CreateShaderModule(byte[] code)
    {
        var codePtr = Marshal.AllocHGlobal(code.Length);
        Marshal.Copy(code, 0, codePtr, code.Length);
        
        var createInfo = new VkShaderModuleCreateInfo
        {
            sType = VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO,
            pNext = IntPtr.Zero,
            flags = 0,
            codeSize = (UIntPtr)code.Length,
            pCode = codePtr
        };
        
        IntPtr shaderModule;
        int result = vkCreateShaderModule(device, ref createInfo, IntPtr.Zero, out shaderModule);
        
        Marshal.FreeHGlobal(codePtr);
        
        if (result != VK_SUCCESS)
            throw new Exception($"Failed to create shader module: {result}");
        
        return shaderModule;
    }

    void CreateGraphicsPipeline()
    {
        // Compile shaders at runtime
        string basePath = AppDomain.CurrentDomain.BaseDirectory;
        byte[] vertCode = CompileShader(Path.Combine(basePath, "hello.vert"), "vert");
        byte[] fragCode = CompileShader(Path.Combine(basePath, "hello.frag"), "frag");
        
        IntPtr vertShaderModule = CreateShaderModule(vertCode);
        IntPtr fragShaderModule = CreateShaderModule(fragCode);
        
        var mainName = Marshal.StringToHGlobalAnsi("main");
        
        var vertShaderStageInfo = new VkPipelineShaderStageCreateInfo
        {
            sType = VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
            pNext = IntPtr.Zero,
            flags = 0,
            stage = VK_SHADER_STAGE_VERTEX_BIT,
            module = vertShaderModule,
            pName = mainName,
            pSpecializationInfo = IntPtr.Zero
        };
        
        var fragShaderStageInfo = new VkPipelineShaderStageCreateInfo
        {
            sType = VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
            pNext = IntPtr.Zero,
            flags = 0,
            stage = VK_SHADER_STAGE_FRAGMENT_BIT,
            module = fragShaderModule,
            pName = mainName,
            pSpecializationInfo = IntPtr.Zero
        };
        
        var shaderStages = new VkPipelineShaderStageCreateInfo[] { vertShaderStageInfo, fragShaderStageInfo };
        var shaderStagesPtr = Marshal.AllocHGlobal(Marshal.SizeOf<VkPipelineShaderStageCreateInfo>() * 2);
        for (int i = 0; i < 2; i++)
        {
            Marshal.StructureToPtr(shaderStages[i], shaderStagesPtr + i * Marshal.SizeOf<VkPipelineShaderStageCreateInfo>(), false);
        }
        
        var vertexInputInfo = new VkPipelineVertexInputStateCreateInfo
        {
            sType = VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO,
            pNext = IntPtr.Zero,
            flags = 0,
            vertexBindingDescriptionCount = 0,
            pVertexBindingDescriptions = IntPtr.Zero,
            vertexAttributeDescriptionCount = 0,
            pVertexAttributeDescriptions = IntPtr.Zero
        };
        var vertexInputInfoPtr = Marshal.AllocHGlobal(Marshal.SizeOf<VkPipelineVertexInputStateCreateInfo>());
        Marshal.StructureToPtr(vertexInputInfo, vertexInputInfoPtr, false);
        
        var inputAssembly = new VkPipelineInputAssemblyStateCreateInfo
        {
            sType = VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO,
            pNext = IntPtr.Zero,
            flags = 0,
            topology = VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST,
            primitiveRestartEnable = VK_FALSE
        };
        var inputAssemblyPtr = Marshal.AllocHGlobal(Marshal.SizeOf<VkPipelineInputAssemblyStateCreateInfo>());
        Marshal.StructureToPtr(inputAssembly, inputAssemblyPtr, false);
        
        var viewportState = new VkPipelineViewportStateCreateInfo
        {
            sType = VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO,
            pNext = IntPtr.Zero,
            flags = 0,
            viewportCount = 1,
            pViewports = IntPtr.Zero,
            scissorCount = 1,
            pScissors = IntPtr.Zero
        };
        var viewportStatePtr = Marshal.AllocHGlobal(Marshal.SizeOf<VkPipelineViewportStateCreateInfo>());
        Marshal.StructureToPtr(viewportState, viewportStatePtr, false);
        
        var rasterizer = new VkPipelineRasterizationStateCreateInfo
        {
            sType = VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO,
            pNext = IntPtr.Zero,
            flags = 0,
            depthClampEnable = VK_FALSE,
            rasterizerDiscardEnable = VK_FALSE,
            polygonMode = VK_POLYGON_MODE_FILL,
            cullMode = VK_CULL_MODE_NONE,
            frontFace = VK_FRONT_FACE_COUNTER_CLOCKWISE,
            depthBiasEnable = VK_FALSE,
            depthBiasConstantFactor = 0.0f,
            depthBiasClamp = 0.0f,
            depthBiasSlopeFactor = 0.0f,
            lineWidth = 1.0f
        };
        var rasterizerPtr = Marshal.AllocHGlobal(Marshal.SizeOf<VkPipelineRasterizationStateCreateInfo>());
        Marshal.StructureToPtr(rasterizer, rasterizerPtr, false);
        
        var multisampling = new VkPipelineMultisampleStateCreateInfo
        {
            sType = VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO,
            pNext = IntPtr.Zero,
            flags = 0,
            rasterizationSamples = VK_SAMPLE_COUNT_1_BIT,
            sampleShadingEnable = VK_FALSE,
            minSampleShading = 1.0f,
            pSampleMask = IntPtr.Zero,
            alphaToCoverageEnable = VK_FALSE,
            alphaToOneEnable = VK_FALSE
        };
        var multisamplingPtr = Marshal.AllocHGlobal(Marshal.SizeOf<VkPipelineMultisampleStateCreateInfo>());
        Marshal.StructureToPtr(multisampling, multisamplingPtr, false);
        
        var colorBlendAttachment = new VkPipelineColorBlendAttachmentState
        {
            blendEnable = VK_FALSE,
            srcColorBlendFactor = VK_BLEND_FACTOR_ONE,
            dstColorBlendFactor = VK_BLEND_FACTOR_ZERO,
            colorBlendOp = VK_BLEND_OP_ADD,
            srcAlphaBlendFactor = VK_BLEND_FACTOR_ONE,
            dstAlphaBlendFactor = VK_BLEND_FACTOR_ZERO,
            alphaBlendOp = VK_BLEND_OP_ADD,
            colorWriteMask = VK_COLOR_COMPONENT_R_BIT | VK_COLOR_COMPONENT_G_BIT | VK_COLOR_COMPONENT_B_BIT | VK_COLOR_COMPONENT_A_BIT
        };
        var colorBlendAttachmentPtr = Marshal.AllocHGlobal(Marshal.SizeOf<VkPipelineColorBlendAttachmentState>());
        Marshal.StructureToPtr(colorBlendAttachment, colorBlendAttachmentPtr, false);
        
        var colorBlending = new VkPipelineColorBlendStateCreateInfo
        {
            sType = VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO,
            pNext = IntPtr.Zero,
            flags = 0,
            logicOpEnable = VK_FALSE,
            logicOp = VK_LOGIC_OP_COPY,
            attachmentCount = 1,
            pAttachments = colorBlendAttachmentPtr,
            blendConstant0 = 0.0f,
            blendConstant1 = 0.0f,
            blendConstant2 = 0.0f,
            blendConstant3 = 0.0f
        };
        var colorBlendingPtr = Marshal.AllocHGlobal(Marshal.SizeOf<VkPipelineColorBlendStateCreateInfo>());
        Marshal.StructureToPtr(colorBlending, colorBlendingPtr, false);
        
        var dynamicStates = new uint[] { VK_DYNAMIC_STATE_VIEWPORT, VK_DYNAMIC_STATE_SCISSOR };
        var dynamicStatesPtr = Marshal.AllocHGlobal(sizeof(uint) * dynamicStates.Length);
        Marshal.Copy((int[])(object)dynamicStates.Select(x => (int)x).ToArray(), 0, dynamicStatesPtr, dynamicStates.Length);
        
        var dynamicState = new VkPipelineDynamicStateCreateInfo
        {
            sType = VK_STRUCTURE_TYPE_PIPELINE_DYNAMIC_STATE_CREATE_INFO,
            pNext = IntPtr.Zero,
            flags = 0,
            dynamicStateCount = (uint)dynamicStates.Length,
            pDynamicStates = dynamicStatesPtr
        };
        var dynamicStatePtr = Marshal.AllocHGlobal(Marshal.SizeOf<VkPipelineDynamicStateCreateInfo>());
        Marshal.StructureToPtr(dynamicState, dynamicStatePtr, false);
        
        // Push constant range for iTime and iResolution
        var pushConstantRange = new VkPushConstantRange
        {
            stageFlags = VK_SHADER_STAGE_FRAGMENT_BIT,
            offset = 0,
            size = 16 // 4 floats: iTime, padding, iResolutionX, iResolutionY
        };
        var pushConstantRangePtr = Marshal.AllocHGlobal(Marshal.SizeOf<VkPushConstantRange>());
        Marshal.StructureToPtr(pushConstantRange, pushConstantRangePtr, false);
        
        var pipelineLayoutInfo = new VkPipelineLayoutCreateInfo
        {
            sType = VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO,
            pNext = IntPtr.Zero,
            flags = 0,
            setLayoutCount = 0,
            pSetLayouts = IntPtr.Zero,
            pushConstantRangeCount = 1,
            pPushConstantRanges = pushConstantRangePtr
        };
        
        int result = vkCreatePipelineLayout(device, ref pipelineLayoutInfo, IntPtr.Zero, out pipelineLayout);
        if (result != VK_SUCCESS)
            throw new Exception($"Failed to create pipeline layout: {result}");
        
        var pipelineInfo = new VkGraphicsPipelineCreateInfo
        {
            sType = VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO,
            pNext = IntPtr.Zero,
            flags = 0,
            stageCount = 2,
            pStages = shaderStagesPtr,
            pVertexInputState = vertexInputInfoPtr,
            pInputAssemblyState = inputAssemblyPtr,
            pTessellationState = IntPtr.Zero,
            pViewportState = viewportStatePtr,
            pRasterizationState = rasterizerPtr,
            pMultisampleState = multisamplingPtr,
            pDepthStencilState = IntPtr.Zero,
            pColorBlendState = colorBlendingPtr,
            pDynamicState = dynamicStatePtr,
            layout = pipelineLayout,
            renderPass = renderPass,
            subpass = 0,
            basePipelineHandle = IntPtr.Zero,
            basePipelineIndex = -1
        };
        
        result = vkCreateGraphicsPipelines(device, IntPtr.Zero, 1, ref pipelineInfo, IntPtr.Zero, out graphicsPipeline);
        
        // Cleanup
        vkDestroyShaderModule(device, vertShaderModule, IntPtr.Zero);
        vkDestroyShaderModule(device, fragShaderModule, IntPtr.Zero);
        
        Marshal.FreeHGlobal(mainName);
        Marshal.FreeHGlobal(shaderStagesPtr);
        Marshal.FreeHGlobal(vertexInputInfoPtr);
        Marshal.FreeHGlobal(inputAssemblyPtr);
        Marshal.FreeHGlobal(viewportStatePtr);
        Marshal.FreeHGlobal(rasterizerPtr);
        Marshal.FreeHGlobal(multisamplingPtr);
        Marshal.FreeHGlobal(colorBlendAttachmentPtr);
        Marshal.FreeHGlobal(colorBlendingPtr);
        Marshal.FreeHGlobal(dynamicStatesPtr);
        Marshal.FreeHGlobal(dynamicStatePtr);
        Marshal.FreeHGlobal(pushConstantRangePtr);
        
        if (result != VK_SUCCESS)
            throw new Exception($"Failed to create graphics pipeline: {result}");
    }

    void CreateFramebuffers()
    {
        swapchainFramebuffers = new IntPtr[swapchainImageViews.Length];
        
        for (int i = 0; i < swapchainImageViews.Length; i++)
        {
            var attachments = new IntPtr[] { swapchainImageViews[i] };
            var attachmentsPtr = Marshal.AllocHGlobal(IntPtr.Size);
            Marshal.Copy(attachments, 0, attachmentsPtr, 1);
            
            var framebufferInfo = new VkFramebufferCreateInfo
            {
                sType = VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO,
                pNext = IntPtr.Zero,
                flags = 0,
                renderPass = renderPass,
                attachmentCount = 1,
                pAttachments = attachmentsPtr,
                width = swapchainExtent.width,
                height = swapchainExtent.height,
                layers = 1
            };
            
            int result = vkCreateFramebuffer(device, ref framebufferInfo, IntPtr.Zero, out swapchainFramebuffers[i]);
            
            Marshal.FreeHGlobal(attachmentsPtr);
            
            if (result != VK_SUCCESS)
                throw new Exception($"Failed to create framebuffer: {result}");
        }
    }

    void CreateCommandPool()
    {
        var poolInfo = new VkCommandPoolCreateInfo
        {
            sType = VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO,
            pNext = IntPtr.Zero,
            flags = VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT,
            queueFamilyIndex = graphicsQueueFamily
        };
        
        int result = vkCreateCommandPool(device, ref poolInfo, IntPtr.Zero, out commandPool);
        if (result != VK_SUCCESS)
            throw new Exception($"Failed to create command pool: {result}");
    }

    void CreateCommandBuffers()
    {
        commandBuffers = new IntPtr[MAX_FRAMES_IN_FLIGHT];
        
        var allocInfo = new VkCommandBufferAllocateInfo
        {
            sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
            pNext = IntPtr.Zero,
            commandPool = commandPool,
            level = VK_COMMAND_BUFFER_LEVEL_PRIMARY,
            commandBufferCount = (uint)MAX_FRAMES_IN_FLIGHT
        };
        
        int result = vkAllocateCommandBuffers(device, ref allocInfo, commandBuffers);
        if (result != VK_SUCCESS)
            throw new Exception($"Failed to allocate command buffers: {result}");
    }

    void CreateSyncObjects()
    {
        imageAvailableSemaphores = new IntPtr[MAX_FRAMES_IN_FLIGHT];
        renderFinishedSemaphores = new IntPtr[MAX_FRAMES_IN_FLIGHT];
        inFlightFences = new IntPtr[MAX_FRAMES_IN_FLIGHT];
        
        var semaphoreInfo = new VkSemaphoreCreateInfo
        {
            sType = VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO,
            pNext = IntPtr.Zero,
            flags = 0
        };
        
        var fenceInfo = new VkFenceCreateInfo
        {
            sType = VK_STRUCTURE_TYPE_FENCE_CREATE_INFO,
            pNext = IntPtr.Zero,
            flags = VK_FENCE_CREATE_SIGNALED_BIT
        };
        
        for (int i = 0; i < MAX_FRAMES_IN_FLIGHT; i++)
        {
            if (vkCreateSemaphore(device, ref semaphoreInfo, IntPtr.Zero, out imageAvailableSemaphores[i]) != VK_SUCCESS ||
                vkCreateSemaphore(device, ref semaphoreInfo, IntPtr.Zero, out renderFinishedSemaphores[i]) != VK_SUCCESS ||
                vkCreateFence(device, ref fenceInfo, IntPtr.Zero, out inFlightFences[i]) != VK_SUCCESS)
            {
                throw new Exception("Failed to create sync objects");
            }
        }
    }

    void RecordCommandBuffer(IntPtr commandBuffer, uint imageIndex)
    {
        var beginInfo = new VkCommandBufferBeginInfo
        {
            sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
            pNext = IntPtr.Zero,
            flags = 0,
            pInheritanceInfo = IntPtr.Zero
        };
        
        if (vkBeginCommandBuffer(commandBuffer, ref beginInfo) != VK_SUCCESS)
            throw new Exception("Failed to begin recording command buffer");
        
        var clearColor = new VkClearValue { r = 0.0f, g = 0.0f, b = 0.0f, a = 1.0f };
        var clearColorPtr = Marshal.AllocHGlobal(Marshal.SizeOf<VkClearValue>());
        Marshal.StructureToPtr(clearColor, clearColorPtr, false);
        
        var renderPassInfo = new VkRenderPassBeginInfo
        {
            sType = VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO,
            pNext = IntPtr.Zero,
            renderPass = renderPass,
            framebuffer = swapchainFramebuffers[imageIndex],
            renderArea = new VkRect2D
            {
                offset = new VkOffset2D { x = 0, y = 0 },
                extent = swapchainExtent
            },
            clearValueCount = 1,
            pClearValues = clearColorPtr
        };
        
        vkCmdBeginRenderPass(commandBuffer, ref renderPassInfo, VK_SUBPASS_CONTENTS_INLINE);
        
        vkCmdBindPipeline(commandBuffer, VK_PIPELINE_BIND_POINT_GRAPHICS, graphicsPipeline);
        
        var viewport = new VkViewport
        {
            x = 0.0f,
            y = 0.0f,
            width = swapchainExtent.width,
            height = swapchainExtent.height,
            minDepth = 0.0f,
            maxDepth = 1.0f
        };
        vkCmdSetViewport(commandBuffer, 0, 1, ref viewport);
        
        var scissor = new VkRect2D
        {
            offset = new VkOffset2D { x = 0, y = 0 },
            extent = swapchainExtent
        };
        vkCmdSetScissor(commandBuffer, 0, 1, ref scissor);
        
        // Push constants for time and resolution
        var pushConstants = new PushConstants
        {
            iTime = (float)stopwatch.Elapsed.TotalSeconds,
            padding = 0.0f,
            iResolutionX = swapchainExtent.width,
            iResolutionY = swapchainExtent.height
        };
        
        var pushConstantsPtr = Marshal.AllocHGlobal(Marshal.SizeOf<PushConstants>());
        Marshal.StructureToPtr(pushConstants, pushConstantsPtr, false);
        
        vkCmdPushConstants(commandBuffer, pipelineLayout, VK_SHADER_STAGE_FRAGMENT_BIT, 0, 16, pushConstantsPtr);
        
        Marshal.FreeHGlobal(pushConstantsPtr);
        
        // Draw fullscreen triangle (3 vertices)
        vkCmdDraw(commandBuffer, 3, 1, 0, 0);
        
        vkCmdEndRenderPass(commandBuffer);
        
        Marshal.FreeHGlobal(clearColorPtr);
        
        if (vkEndCommandBuffer(commandBuffer) != VK_SUCCESS)
            throw new Exception("Failed to record command buffer");
    }

    void DrawFrame()
    {
        if (device == IntPtr.Zero)
            return;
        
        var fenceArray = new IntPtr[] { inFlightFences[currentFrame] };
        vkWaitForFences(device, 1, fenceArray, VK_TRUE, UINT64_MAX);
        
        uint imageIndex;
        int result = vkAcquireNextImageKHR(device, swapchain, UINT64_MAX, imageAvailableSemaphores[currentFrame], IntPtr.Zero, out imageIndex);
        
        if (result == VK_ERROR_OUT_OF_DATE_KHR)
        {
            RecreateSwapchain();
            return;
        }
        else if (result != VK_SUCCESS && result != VK_SUBOPTIMAL_KHR)
        {
            throw new Exception($"Failed to acquire swapchain image: {result}");
        }
        
        vkResetFences(device, 1, fenceArray);
        
        vkResetCommandBuffer(commandBuffers[currentFrame], 0);
        RecordCommandBuffer(commandBuffers[currentFrame], imageIndex);
        
        var waitSemaphores = new IntPtr[] { imageAvailableSemaphores[currentFrame] };
        var waitSemaphoresPtr = Marshal.AllocHGlobal(IntPtr.Size);
        Marshal.Copy(waitSemaphores, 0, waitSemaphoresPtr, 1);
        
        var waitStages = new uint[] { VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT };
        var waitStagesPtr = Marshal.AllocHGlobal(sizeof(uint));
        Marshal.Copy((int[])(object)waitStages.Select(x => (int)x).ToArray(), 0, waitStagesPtr, 1);
        
        var commandBufferArray = new IntPtr[] { commandBuffers[currentFrame] };
        var commandBufferPtr = Marshal.AllocHGlobal(IntPtr.Size);
        Marshal.Copy(commandBufferArray, 0, commandBufferPtr, 1);
        
        var signalSemaphores = new IntPtr[] { renderFinishedSemaphores[currentFrame] };
        var signalSemaphoresPtr = Marshal.AllocHGlobal(IntPtr.Size);
        Marshal.Copy(signalSemaphores, 0, signalSemaphoresPtr, 1);
        
        var submitInfo = new VkSubmitInfo
        {
            sType = VK_STRUCTURE_TYPE_SUBMIT_INFO,
            pNext = IntPtr.Zero,
            waitSemaphoreCount = 1,
            pWaitSemaphores = waitSemaphoresPtr,
            pWaitDstStageMask = waitStagesPtr,
            commandBufferCount = 1,
            pCommandBuffers = commandBufferPtr,
            signalSemaphoreCount = 1,
            pSignalSemaphores = signalSemaphoresPtr
        };
        
        result = vkQueueSubmit(graphicsQueue, 1, ref submitInfo, inFlightFences[currentFrame]);
        
        Marshal.FreeHGlobal(waitSemaphoresPtr);
        Marshal.FreeHGlobal(waitStagesPtr);
        Marshal.FreeHGlobal(commandBufferPtr);
        Marshal.FreeHGlobal(signalSemaphoresPtr);
        
        if (result != VK_SUCCESS)
            throw new Exception($"Failed to submit draw command buffer: {result}");
        
        var swapchains = new IntPtr[] { swapchain };
        var swapchainsPtr = Marshal.AllocHGlobal(IntPtr.Size);
        Marshal.Copy(swapchains, 0, swapchainsPtr, 1);
        
        var imageIndices = new uint[] { imageIndex };
        var imageIndicesPtr = Marshal.AllocHGlobal(sizeof(uint));
        Marshal.Copy((int[])(object)imageIndices.Select(x => (int)x).ToArray(), 0, imageIndicesPtr, 1);
        
        var presentWaitSemaphoresPtr = Marshal.AllocHGlobal(IntPtr.Size);
        Marshal.Copy(signalSemaphores, 0, presentWaitSemaphoresPtr, 1);
        
        var presentInfo = new VkPresentInfoKHR
        {
            sType = VK_STRUCTURE_TYPE_PRESENT_INFO_KHR,
            pNext = IntPtr.Zero,
            waitSemaphoreCount = 1,
            pWaitSemaphores = presentWaitSemaphoresPtr,
            swapchainCount = 1,
            pSwapchains = swapchainsPtr,
            pImageIndices = imageIndicesPtr,
            pResults = IntPtr.Zero
        };
        
        result = vkQueuePresentKHR(presentQueue, ref presentInfo);
        
        Marshal.FreeHGlobal(swapchainsPtr);
        Marshal.FreeHGlobal(imageIndicesPtr);
        Marshal.FreeHGlobal(presentWaitSemaphoresPtr);
        
        if (result == VK_ERROR_OUT_OF_DATE_KHR || result == VK_SUBOPTIMAL_KHR || framebufferResized)
        {
            framebufferResized = false;
            RecreateSwapchain();
        }
        else if (result != VK_SUCCESS)
        {
            throw new Exception($"Failed to present swapchain image: {result}");
        }
        
        currentFrame = (currentFrame + 1) % MAX_FRAMES_IN_FLIGHT;
    }

    [STAThread]
    public static void Main()
    {
        Application.EnableVisualStyles();
        Application.Run(new VulkanRaymarching());
    }
}
