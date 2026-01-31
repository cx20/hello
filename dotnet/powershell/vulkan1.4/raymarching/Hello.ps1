$VulkanCode = @'
using System;
using System.IO;
using System.Text;
using System.Drawing;
using System.Windows.Forms;
using System.Runtime.InteropServices;
using System.Collections.Generic;
using System.Diagnostics;

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
    
    const uint VK_IMAGE_LAYOUT_UNDEFINED = 0;
    const uint VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL = 2;
    const uint VK_IMAGE_LAYOUT_PRESENT_SRC_KHR = 1000001002;
    
    const uint VK_ATTACHMENT_LOAD_OP_CLEAR = 1;
    const uint VK_ATTACHMENT_STORE_OP_STORE = 0;
    const uint VK_ATTACHMENT_STORE_OP_DONT_CARE = 2;
    
    const uint VK_PIPELINE_BIND_POINT_GRAPHICS = 0;
    
    const uint VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT = 0x00000400;
    
    const uint VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT = 0x00000100;
    
    const uint VK_SUBPASS_EXTERNAL = 0xFFFFFFFF;
    
    const uint VK_SHADER_STAGE_VERTEX_BIT = 0x00000001;
    const uint VK_SHADER_STAGE_FRAGMENT_BIT = 0x00000010;
    
    const uint VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST = 3;
    
    const uint VK_POLYGON_MODE_FILL = 0;
    const uint VK_CULL_MODE_NONE = 0;
    const uint VK_FRONT_FACE_COUNTER_CLOCKWISE = 0;
    
    const uint VK_SAMPLE_COUNT_1_BIT = 0x00000001;
    
    const uint VK_COLOR_COMPONENT_R_BIT = 0x00000001;
    const uint VK_COLOR_COMPONENT_G_BIT = 0x00000002;
    const uint VK_COLOR_COMPONENT_B_BIT = 0x00000004;
    const uint VK_COLOR_COMPONENT_A_BIT = 0x00000008;
    
    const uint VK_BLEND_FACTOR_ZERO = 0;
    const uint VK_BLEND_FACTOR_ONE = 1;
    const uint VK_BLEND_OP_ADD = 0;
    const uint VK_LOGIC_OP_COPY = 3;
    
    const uint VK_DYNAMIC_STATE_VIEWPORT = 0;
    const uint VK_DYNAMIC_STATE_SCISSOR = 1;
    
    const uint VK_FORMAT_B8G8R8A8_SRGB = 50;
    const uint VK_FORMAT_B8G8R8A8_UNORM = 44;
    const uint VK_COLOR_SPACE_SRGB_NONLINEAR_KHR = 0;
    
    const uint VK_PRESENT_MODE_FIFO_KHR = 2;
    const uint VK_PRESENT_MODE_MAILBOX_KHR = 1;
    
    const uint VK_SHARING_MODE_EXCLUSIVE = 0;
    
    const uint VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT = 0x00000010;
    
    const uint VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR = 0x00000001;
    
    const uint VK_IMAGE_VIEW_TYPE_2D = 1;
    const uint VK_IMAGE_ASPECT_COLOR_BIT = 0x00000001;
    const uint VK_COMPONENT_SWIZZLE_IDENTITY = 0;
    
    const uint VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT = 0x00000002;
    const uint VK_COMMAND_BUFFER_LEVEL_PRIMARY = 0;
    const uint VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT = 0x00000001;
    
    const uint VK_SUBPASS_CONTENTS_INLINE = 0;
    
    const uint VK_FENCE_CREATE_SIGNALED_BIT = 0x00000001;
    
    const ulong VK_WHOLE_SIZE = 0xFFFFFFFFFFFFFFFF;
    
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
    struct VkWin32SurfaceCreateInfoKHR
    {
        public uint sType;
        public IntPtr pNext;
        public uint flags;
        public IntPtr hinstance;
        public IntPtr hwnd;
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
        public uint minImageTransferGranularity_width;
        public uint minImageTransferGranularity_height;
        public uint minImageTransferGranularity_depth;
    }

    [StructLayout(LayoutKind.Sequential)]
    struct VkSurfaceCapabilitiesKHR
    {
        public uint minImageCount;
        public uint maxImageCount;
        public uint currentExtent_width;
        public uint currentExtent_height;
        public uint minImageExtent_width;
        public uint minImageExtent_height;
        public uint maxImageExtent_width;
        public uint maxImageExtent_height;
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
        public uint imageExtent_width;
        public uint imageExtent_height;
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
    struct VkExtent2D
    {
        public uint width;
        public uint height;
    }

    [StructLayout(LayoutKind.Sequential)]
    struct VkClearValue
    {
        public VkClearColorValue color;
    }

    [StructLayout(LayoutKind.Sequential)]
    struct VkClearColorValue
    {
        public float r;
        public float g;
        public float b;
        public float a;
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
    [DllImport("vulkan-1.dll")]
    static extern int vkCreateInstance(ref VkInstanceCreateInfo createInfo, IntPtr allocator, out IntPtr instance);

    [DllImport("vulkan-1.dll")]
    static extern void vkDestroyInstance(IntPtr instance, IntPtr allocator);

    [DllImport("vulkan-1.dll")]
    static extern int vkEnumeratePhysicalDevices(IntPtr instance, ref uint physicalDeviceCount, IntPtr[] physicalDevices);

    [DllImport("vulkan-1.dll")]
    static extern void vkGetPhysicalDeviceQueueFamilyProperties(IntPtr physicalDevice, ref uint queueFamilyPropertyCount, IntPtr pQueueFamilyProperties);

    [DllImport("vulkan-1.dll")]
    static extern int vkCreateDevice(IntPtr physicalDevice, ref VkDeviceCreateInfo createInfo, IntPtr allocator, out IntPtr device);

    [DllImport("vulkan-1.dll")]
    static extern void vkDestroyDevice(IntPtr device, IntPtr allocator);

    [DllImport("vulkan-1.dll")]
    static extern void vkGetDeviceQueue(IntPtr device, uint queueFamilyIndex, uint queueIndex, out IntPtr queue);

    [DllImport("vulkan-1.dll")]
    static extern int vkCreateWin32SurfaceKHR(IntPtr instance, ref VkWin32SurfaceCreateInfoKHR createInfo, IntPtr allocator, out IntPtr surface);

    [DllImport("vulkan-1.dll")]
    static extern void vkDestroySurfaceKHR(IntPtr instance, IntPtr surface, IntPtr allocator);

    [DllImport("vulkan-1.dll")]
    static extern int vkGetPhysicalDeviceSurfaceSupportKHR(IntPtr physicalDevice, uint queueFamilyIndex, IntPtr surface, out uint supported);

    [DllImport("vulkan-1.dll")]
    static extern int vkGetPhysicalDeviceSurfaceCapabilitiesKHR(IntPtr physicalDevice, IntPtr surface, out VkSurfaceCapabilitiesKHR surfaceCapabilities);

    [DllImport("vulkan-1.dll")]
    static extern int vkGetPhysicalDeviceSurfaceFormatsKHR(IntPtr physicalDevice, IntPtr surface, ref uint surfaceFormatCount, IntPtr pSurfaceFormats);

    [DllImport("vulkan-1.dll")]
    static extern int vkCreateSwapchainKHR(IntPtr device, ref VkSwapchainCreateInfoKHR createInfo, IntPtr allocator, out IntPtr swapchain);

    [DllImport("vulkan-1.dll")]
    static extern void vkDestroySwapchainKHR(IntPtr device, IntPtr swapchain, IntPtr allocator);

    [DllImport("vulkan-1.dll")]
    static extern int vkGetSwapchainImagesKHR(IntPtr device, IntPtr swapchain, ref uint swapchainImageCount, IntPtr[] swapchainImages);

    [DllImport("vulkan-1.dll")]
    static extern int vkCreateImageView(IntPtr device, ref VkImageViewCreateInfo createInfo, IntPtr allocator, out IntPtr imageView);

    [DllImport("vulkan-1.dll")]
    static extern void vkDestroyImageView(IntPtr device, IntPtr imageView, IntPtr allocator);

    [DllImport("vulkan-1.dll")]
    static extern int vkCreateRenderPass(IntPtr device, ref VkRenderPassCreateInfo createInfo, IntPtr allocator, out IntPtr renderPass);

    [DllImport("vulkan-1.dll")]
    static extern void vkDestroyRenderPass(IntPtr device, IntPtr renderPass, IntPtr allocator);

    [DllImport("vulkan-1.dll")]
    static extern int vkCreateShaderModule(IntPtr device, ref VkShaderModuleCreateInfo createInfo, IntPtr allocator, out IntPtr shaderModule);

    [DllImport("vulkan-1.dll")]
    static extern void vkDestroyShaderModule(IntPtr device, IntPtr shaderModule, IntPtr allocator);

    [DllImport("vulkan-1.dll")]
    static extern int vkCreatePipelineLayout(IntPtr device, ref VkPipelineLayoutCreateInfo createInfo, IntPtr allocator, out IntPtr pipelineLayout);

    [DllImport("vulkan-1.dll")]
    static extern void vkDestroyPipelineLayout(IntPtr device, IntPtr pipelineLayout, IntPtr allocator);

    [DllImport("vulkan-1.dll")]
    static extern int vkCreateGraphicsPipelines(IntPtr device, IntPtr pipelineCache, uint createInfoCount, ref VkGraphicsPipelineCreateInfo createInfos, IntPtr allocator, out IntPtr pipelines);

    [DllImport("vulkan-1.dll")]
    static extern void vkDestroyPipeline(IntPtr device, IntPtr pipeline, IntPtr allocator);

    [DllImport("vulkan-1.dll")]
    static extern int vkCreateFramebuffer(IntPtr device, ref VkFramebufferCreateInfo createInfo, IntPtr allocator, out IntPtr framebuffer);

    [DllImport("vulkan-1.dll")]
    static extern void vkDestroyFramebuffer(IntPtr device, IntPtr framebuffer, IntPtr allocator);

    [DllImport("vulkan-1.dll")]
    static extern int vkCreateCommandPool(IntPtr device, ref VkCommandPoolCreateInfo createInfo, IntPtr allocator, out IntPtr commandPool);

    [DllImport("vulkan-1.dll")]
    static extern void vkDestroyCommandPool(IntPtr device, IntPtr commandPool, IntPtr allocator);

    [DllImport("vulkan-1.dll")]
    static extern int vkAllocateCommandBuffers(IntPtr device, ref VkCommandBufferAllocateInfo allocateInfo, IntPtr[] commandBuffers);

    [DllImport("vulkan-1.dll")]
    static extern int vkBeginCommandBuffer(IntPtr commandBuffer, ref VkCommandBufferBeginInfo beginInfo);

    [DllImport("vulkan-1.dll")]
    static extern int vkEndCommandBuffer(IntPtr commandBuffer);

    [DllImport("vulkan-1.dll")]
    static extern void vkCmdBeginRenderPass(IntPtr commandBuffer, ref VkRenderPassBeginInfo renderPassBegin, uint contents);

    [DllImport("vulkan-1.dll")]
    static extern void vkCmdEndRenderPass(IntPtr commandBuffer);

    [DllImport("vulkan-1.dll")]
    static extern void vkCmdBindPipeline(IntPtr commandBuffer, uint pipelineBindPoint, IntPtr pipeline);

    [DllImport("vulkan-1.dll")]
    static extern void vkCmdSetViewport(IntPtr commandBuffer, uint firstViewport, uint viewportCount, ref VkViewport viewports);

    [DllImport("vulkan-1.dll")]
    static extern void vkCmdSetScissor(IntPtr commandBuffer, uint firstScissor, uint scissorCount, ref VkRect2D scissors);

    [DllImport("vulkan-1.dll")]
    static extern void vkCmdDraw(IntPtr commandBuffer, uint vertexCount, uint instanceCount, uint firstVertex, uint firstInstance);

    [DllImport("vulkan-1.dll")]
    static extern void vkCmdPushConstants(IntPtr commandBuffer, IntPtr layout, uint stageFlags, uint offset, uint size, IntPtr pValues);

    [DllImport("vulkan-1.dll")]
    static extern int vkCreateSemaphore(IntPtr device, ref VkSemaphoreCreateInfo createInfo, IntPtr allocator, out IntPtr semaphore);

    [DllImport("vulkan-1.dll")]
    static extern void vkDestroySemaphore(IntPtr device, IntPtr semaphore, IntPtr allocator);

    [DllImport("vulkan-1.dll")]
    static extern int vkCreateFence(IntPtr device, ref VkFenceCreateInfo createInfo, IntPtr allocator, out IntPtr fence);

    [DllImport("vulkan-1.dll")]
    static extern void vkDestroyFence(IntPtr device, IntPtr fence, IntPtr allocator);

    [DllImport("vulkan-1.dll")]
    static extern int vkWaitForFences(IntPtr device, uint fenceCount, IntPtr[] fences, uint waitAll, ulong timeout);

    [DllImport("vulkan-1.dll")]
    static extern int vkResetFences(IntPtr device, uint fenceCount, IntPtr[] fences);

    [DllImport("vulkan-1.dll")]
    static extern int vkResetCommandBuffer(IntPtr commandBuffer, uint flags);

    [DllImport("vulkan-1.dll")]
    static extern int vkAcquireNextImageKHR(IntPtr device, IntPtr swapchain, ulong timeout, IntPtr semaphore, IntPtr fence, out uint imageIndex);

    [DllImport("vulkan-1.dll")]
    static extern int vkQueueSubmit(IntPtr queue, uint submitCount, ref VkSubmitInfo submitInfo, IntPtr fence);

    [DllImport("vulkan-1.dll")]
    static extern int vkQueuePresentKHR(IntPtr queue, ref VkPresentInfoKHR presentInfo);

    [DllImport("vulkan-1.dll")]
    static extern int vkDeviceWaitIdle(IntPtr device);

    [DllImport("kernel32.dll")]
    static extern IntPtr GetModuleHandle(string moduleName);
    #endregion

    #region Member Variables
    string vertexShaderPath;
    string fragmentShaderPath;

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
    uint swapchainExtentWidth;
    uint swapchainExtentHeight;

    int currentFrame = 0;
    bool framebufferResized = false;
    
    Stopwatch stopwatch;
    Timer timer;
    #endregion

    public VulkanRaymarching(string vertPath, string fragPath)
    {
        vertexShaderPath = vertPath;
        fragmentShaderPath = fragPath;

        this.Text = "Raymarching - Vulkan 1.4 / PowerShell";
        this.ClientSize = new Size(800, 600);
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
            timer.Interval = 16;
            timer.Tick += (s, args) => DrawFrame();
            timer.Start();
        }
        catch (Exception ex)
        {
            MessageBox.Show("Vulkan initialization failed:\n" + ex.Message + "\n\n" + ex.StackTrace, "Error", MessageBoxButtons.OK, MessageBoxIcon.Error);
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
        
        Cleanup();
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

    void CreateInstance()
    {
        IntPtr appName = Marshal.StringToHGlobalAnsi("Vulkan Raymarching");
        IntPtr engineName = Marshal.StringToHGlobalAnsi("No Engine");

        VkApplicationInfo appInfo = new VkApplicationInfo();
        appInfo.sType = VK_STRUCTURE_TYPE_APPLICATION_INFO;
        appInfo.pApplicationName = appName;
        appInfo.applicationVersion = 1;
        appInfo.pEngineName = engineName;
        appInfo.engineVersion = 1;
        appInfo.apiVersion = VK_API_VERSION_1_4;

        GCHandle appInfoHandle = GCHandle.Alloc(appInfo, GCHandleType.Pinned);

        string[] extensions = { "VK_KHR_surface", "VK_KHR_win32_surface" };
        IntPtr[] extensionPtrs = new IntPtr[extensions.Length];
        for (int i = 0; i < extensions.Length; i++)
            extensionPtrs[i] = Marshal.StringToHGlobalAnsi(extensions[i]);

        IntPtr extensionsPtr = Marshal.AllocHGlobal(IntPtr.Size * extensions.Length);
        Marshal.Copy(extensionPtrs, 0, extensionsPtr, extensions.Length);

        VkInstanceCreateInfo createInfo = new VkInstanceCreateInfo();
        createInfo.sType = VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO;
        createInfo.pApplicationInfo = appInfoHandle.AddrOfPinnedObject();
        createInfo.enabledExtensionCount = (uint)extensions.Length;
        createInfo.ppEnabledExtensionNames = extensionsPtr;

        int result = vkCreateInstance(ref createInfo, IntPtr.Zero, out instance);

        appInfoHandle.Free();
        Marshal.FreeHGlobal(appName);
        Marshal.FreeHGlobal(engineName);
        Marshal.FreeHGlobal(extensionsPtr);
        foreach (var ptr in extensionPtrs) Marshal.FreeHGlobal(ptr);

        if (result != VK_SUCCESS)
            throw new Exception("Failed to create Vulkan instance: " + result);
    }

    void CreateSurface()
    {
        VkWin32SurfaceCreateInfoKHR createInfo = new VkWin32SurfaceCreateInfoKHR();
        createInfo.sType = VK_STRUCTURE_TYPE_WIN32_SURFACE_CREATE_INFO_KHR;
        createInfo.hinstance = GetModuleHandle(null);
        createInfo.hwnd = this.Handle;

        int result = vkCreateWin32SurfaceKHR(instance, ref createInfo, IntPtr.Zero, out surface);
        if (result != VK_SUCCESS)
            throw new Exception("Failed to create window surface: " + result);
    }

    void PickPhysicalDevice()
    {
        uint deviceCount = 0;
        vkEnumeratePhysicalDevices(instance, ref deviceCount, null);

        if (deviceCount == 0)
            throw new Exception("No Vulkan-compatible GPU found");

        IntPtr[] devices = new IntPtr[deviceCount];
        vkEnumeratePhysicalDevices(instance, ref deviceCount, devices);
        physicalDevice = devices[0];

        uint queueFamilyCount = 0;
        vkGetPhysicalDeviceQueueFamilyProperties(physicalDevice, ref queueFamilyCount, IntPtr.Zero);

        VkQueueFamilyProperties[] queueFamilies = new VkQueueFamilyProperties[queueFamilyCount];
        GCHandle queueFamiliesHandle = GCHandle.Alloc(queueFamilies, GCHandleType.Pinned);
        vkGetPhysicalDeviceQueueFamilyProperties(physicalDevice, ref queueFamilyCount, queueFamiliesHandle.AddrOfPinnedObject());
        queueFamiliesHandle.Free();

        graphicsQueueFamily = uint.MaxValue;
        presentQueueFamily = uint.MaxValue;

        for (uint i = 0; i < queueFamilyCount; i++)
        {
            if ((queueFamilies[i].queueFlags & VK_QUEUE_GRAPHICS_BIT) != 0)
                graphicsQueueFamily = i;

            uint presentSupport = 0;
            vkGetPhysicalDeviceSurfaceSupportKHR(physicalDevice, i, surface, out presentSupport);
            if (presentSupport == VK_TRUE)
                presentQueueFamily = i;

            if (graphicsQueueFamily != uint.MaxValue && presentQueueFamily != uint.MaxValue)
                break;
        }

        if (graphicsQueueFamily == uint.MaxValue || presentQueueFamily == uint.MaxValue)
            throw new Exception("No suitable queue family found");
    }

    void CreateLogicalDevice()
    {
        HashSet<uint> uniqueQueueFamilies = new HashSet<uint> { graphicsQueueFamily, presentQueueFamily };
        List<VkDeviceQueueCreateInfo> queueCreateInfos = new List<VkDeviceQueueCreateInfo>();

        float[] priorities = { 1.0f };
        GCHandle priorityHandle = GCHandle.Alloc(priorities, GCHandleType.Pinned);

        foreach (uint queueFamily in uniqueQueueFamilies)
        {
            VkDeviceQueueCreateInfo queueCreateInfo = new VkDeviceQueueCreateInfo();
            queueCreateInfo.sType = VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO;
            queueCreateInfo.queueFamilyIndex = queueFamily;
            queueCreateInfo.queueCount = 1;
            queueCreateInfo.pQueuePriorities = priorityHandle.AddrOfPinnedObject();
            queueCreateInfos.Add(queueCreateInfo);
        }

        VkDeviceQueueCreateInfo[] queueCreateInfoArray = queueCreateInfos.ToArray();
        GCHandle queueInfoHandle = GCHandle.Alloc(queueCreateInfoArray, GCHandleType.Pinned);

        string[] deviceExtensions = { "VK_KHR_swapchain" };
        IntPtr[] deviceExtensionPtrs = new IntPtr[deviceExtensions.Length];
        for (int i = 0; i < deviceExtensions.Length; i++)
            deviceExtensionPtrs[i] = Marshal.StringToHGlobalAnsi(deviceExtensions[i]);

        IntPtr extensionsPtr = Marshal.AllocHGlobal(IntPtr.Size * deviceExtensions.Length);
        Marshal.Copy(deviceExtensionPtrs, 0, extensionsPtr, deviceExtensions.Length);

        VkDeviceCreateInfo createInfo = new VkDeviceCreateInfo();
        createInfo.sType = VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO;
        createInfo.queueCreateInfoCount = (uint)queueCreateInfoArray.Length;
        createInfo.pQueueCreateInfos = queueInfoHandle.AddrOfPinnedObject();
        createInfo.enabledExtensionCount = (uint)deviceExtensions.Length;
        createInfo.ppEnabledExtensionNames = extensionsPtr;

        int result = vkCreateDevice(physicalDevice, ref createInfo, IntPtr.Zero, out device);
        if (result != VK_SUCCESS)
            throw new Exception("Failed to create logical device: " + result);

        vkGetDeviceQueue(device, graphicsQueueFamily, 0, out graphicsQueue);
        vkGetDeviceQueue(device, presentQueueFamily, 0, out presentQueue);

        priorityHandle.Free();
        queueInfoHandle.Free();
        Marshal.FreeHGlobal(extensionsPtr);
        foreach (var ptr in deviceExtensionPtrs) Marshal.FreeHGlobal(ptr);
    }

    void CreateSwapchain()
    {
        VkSurfaceCapabilitiesKHR capabilities;
        vkGetPhysicalDeviceSurfaceCapabilitiesKHR(physicalDevice, surface, out capabilities);

        uint formatCount = 0;
        vkGetPhysicalDeviceSurfaceFormatsKHR(physicalDevice, surface, ref formatCount, IntPtr.Zero);
        VkSurfaceFormatKHR[] formats = new VkSurfaceFormatKHR[formatCount];
        GCHandle formatHandle = GCHandle.Alloc(formats, GCHandleType.Pinned);
        vkGetPhysicalDeviceSurfaceFormatsKHR(physicalDevice, surface, ref formatCount, formatHandle.AddrOfPinnedObject());
        formatHandle.Free();

        swapchainImageFormat = formats[0].format;
        uint colorSpace = formats[0].colorSpace;

        // Prefer UNORM to avoid double gamma correction
        for (int i = 0; i < formats.Length; i++)
        {
            if (formats[i].format == VK_FORMAT_B8G8R8A8_UNORM && formats[i].colorSpace == VK_COLOR_SPACE_SRGB_NONLINEAR_KHR)
            {
                swapchainImageFormat = formats[i].format;
                colorSpace = formats[i].colorSpace;
                break;
            }
        }

        swapchainExtentWidth = capabilities.currentExtent_width;
        swapchainExtentHeight = capabilities.currentExtent_height;

        if (swapchainExtentWidth == 0xFFFFFFFF)
        {
            swapchainExtentWidth = (uint)Math.Max((int)capabilities.minImageExtent_width, Math.Min(this.ClientSize.Width, (int)capabilities.maxImageExtent_width));
            swapchainExtentHeight = (uint)Math.Max((int)capabilities.minImageExtent_height, Math.Min(this.ClientSize.Height, (int)capabilities.maxImageExtent_height));
        }

        uint imageCount = capabilities.minImageCount + 1;
        if (capabilities.maxImageCount > 0 && imageCount > capabilities.maxImageCount)
            imageCount = capabilities.maxImageCount;

        VkSwapchainCreateInfoKHR createInfo = new VkSwapchainCreateInfoKHR();
        createInfo.sType = VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR;
        createInfo.surface = surface;
        createInfo.minImageCount = imageCount;
        createInfo.imageFormat = swapchainImageFormat;
        createInfo.imageColorSpace = colorSpace;
        createInfo.imageExtent_width = swapchainExtentWidth;
        createInfo.imageExtent_height = swapchainExtentHeight;
        createInfo.imageArrayLayers = 1;
        createInfo.imageUsage = VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT;
        createInfo.imageSharingMode = VK_SHARING_MODE_EXCLUSIVE;
        createInfo.preTransform = capabilities.currentTransform;
        createInfo.compositeAlpha = VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR;
        createInfo.presentMode = VK_PRESENT_MODE_FIFO_KHR;
        createInfo.clipped = VK_TRUE;

        int result = vkCreateSwapchainKHR(device, ref createInfo, IntPtr.Zero, out swapchain);
        if (result != VK_SUCCESS)
            throw new Exception("Failed to create swap chain: " + result);

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
            VkImageViewCreateInfo createInfo = new VkImageViewCreateInfo();
            createInfo.sType = VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO;
            createInfo.image = swapchainImages[i];
            createInfo.viewType = VK_IMAGE_VIEW_TYPE_2D;
            createInfo.format = swapchainImageFormat;
            createInfo.components.r = VK_COMPONENT_SWIZZLE_IDENTITY;
            createInfo.components.g = VK_COMPONENT_SWIZZLE_IDENTITY;
            createInfo.components.b = VK_COMPONENT_SWIZZLE_IDENTITY;
            createInfo.components.a = VK_COMPONENT_SWIZZLE_IDENTITY;
            createInfo.subresourceRange.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT;
            createInfo.subresourceRange.baseMipLevel = 0;
            createInfo.subresourceRange.levelCount = 1;
            createInfo.subresourceRange.baseArrayLayer = 0;
            createInfo.subresourceRange.layerCount = 1;

            int result = vkCreateImageView(device, ref createInfo, IntPtr.Zero, out swapchainImageViews[i]);
            if (result != VK_SUCCESS)
                throw new Exception("Failed to create image views: " + result);
        }
    }

    void CreateRenderPass()
    {
        VkAttachmentDescription colorAttachment = new VkAttachmentDescription();
        colorAttachment.format = swapchainImageFormat;
        colorAttachment.samples = VK_SAMPLE_COUNT_1_BIT;
        colorAttachment.loadOp = VK_ATTACHMENT_LOAD_OP_CLEAR;
        colorAttachment.storeOp = VK_ATTACHMENT_STORE_OP_STORE;
        colorAttachment.stencilLoadOp = VK_ATTACHMENT_LOAD_OP_CLEAR;
        colorAttachment.stencilStoreOp = VK_ATTACHMENT_STORE_OP_DONT_CARE;
        colorAttachment.initialLayout = VK_IMAGE_LAYOUT_UNDEFINED;
        colorAttachment.finalLayout = VK_IMAGE_LAYOUT_PRESENT_SRC_KHR;

        VkAttachmentReference colorAttachmentRef = new VkAttachmentReference();
        colorAttachmentRef.attachment = 0;
        colorAttachmentRef.layout = VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL;

        GCHandle colorRefHandle = GCHandle.Alloc(colorAttachmentRef, GCHandleType.Pinned);

        VkSubpassDescription subpass = new VkSubpassDescription();
        subpass.pipelineBindPoint = VK_PIPELINE_BIND_POINT_GRAPHICS;
        subpass.colorAttachmentCount = 1;
        subpass.pColorAttachments = colorRefHandle.AddrOfPinnedObject();

        VkSubpassDependency dependency = new VkSubpassDependency();
        dependency.srcSubpass = VK_SUBPASS_EXTERNAL;
        dependency.dstSubpass = 0;
        dependency.srcStageMask = VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT;
        dependency.srcAccessMask = 0;
        dependency.dstStageMask = VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT;
        dependency.dstAccessMask = VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT;

        GCHandle attachmentHandle = GCHandle.Alloc(colorAttachment, GCHandleType.Pinned);
        GCHandle subpassHandle = GCHandle.Alloc(subpass, GCHandleType.Pinned);
        GCHandle dependencyHandle = GCHandle.Alloc(dependency, GCHandleType.Pinned);

        VkRenderPassCreateInfo renderPassInfo = new VkRenderPassCreateInfo();
        renderPassInfo.sType = VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO;
        renderPassInfo.attachmentCount = 1;
        renderPassInfo.pAttachments = attachmentHandle.AddrOfPinnedObject();
        renderPassInfo.subpassCount = 1;
        renderPassInfo.pSubpasses = subpassHandle.AddrOfPinnedObject();
        renderPassInfo.dependencyCount = 1;
        renderPassInfo.pDependencies = dependencyHandle.AddrOfPinnedObject();

        int result = vkCreateRenderPass(device, ref renderPassInfo, IntPtr.Zero, out renderPass);
        
        colorRefHandle.Free();
        attachmentHandle.Free();
        subpassHandle.Free();
        dependencyHandle.Free();

        if (result != VK_SUCCESS)
            throw new Exception("Failed to create render pass: " + result);
    }

    byte[] CompileShader(string shaderPath, string stage)
    {
        string outputPath = Path.GetTempFileName() + ".spv";
        
        ProcessStartInfo psi = new ProcessStartInfo();
        psi.FileName = "glslangValidator";
        psi.Arguments = string.Format("-V -S {0} \"{1}\" -o \"{2}\"", stage, shaderPath, outputPath);
        psi.RedirectStandardOutput = true;
        psi.RedirectStandardError = true;
        psi.UseShellExecute = false;
        psi.CreateNoWindow = true;

        try
        {
            using (Process process = Process.Start(psi))
            {
                process.WaitForExit();
                string output = process.StandardOutput.ReadToEnd();
                string error = process.StandardError.ReadToEnd();
                
                if (process.ExitCode != 0)
                {
                    throw new Exception(string.Format("Shader compilation failed:\n{0}\n{1}", output, error));
                }
            }

            byte[] spirv = File.ReadAllBytes(outputPath);
            File.Delete(outputPath);
            return spirv;
        }
        catch (System.ComponentModel.Win32Exception)
        {
            throw new Exception("glslangValidator not found. Please install Vulkan SDK and add it to PATH.");
        }
    }

    IntPtr CreateShaderModule(byte[] code)
    {
        GCHandle codeHandle = GCHandle.Alloc(code, GCHandleType.Pinned);

        VkShaderModuleCreateInfo createInfo = new VkShaderModuleCreateInfo();
        createInfo.sType = VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO;
        createInfo.codeSize = (UIntPtr)code.Length;
        createInfo.pCode = codeHandle.AddrOfPinnedObject();

        IntPtr shaderModule;
        int result = vkCreateShaderModule(device, ref createInfo, IntPtr.Zero, out shaderModule);
        
        codeHandle.Free();

        if (result != VK_SUCCESS)
            throw new Exception("Failed to create shader module: " + result);

        return shaderModule;
    }

    void CreateGraphicsPipeline()
    {
        byte[] vertShaderCode = CompileShader(vertexShaderPath, "vert");
        byte[] fragShaderCode = CompileShader(fragmentShaderPath, "frag");

        IntPtr vertShaderModule = CreateShaderModule(vertShaderCode);
        IntPtr fragShaderModule = CreateShaderModule(fragShaderCode);

        IntPtr mainPtr = Marshal.StringToHGlobalAnsi("main");

        VkPipelineShaderStageCreateInfo vertShaderStageInfo = new VkPipelineShaderStageCreateInfo();
        vertShaderStageInfo.sType = VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO;
        vertShaderStageInfo.stage = VK_SHADER_STAGE_VERTEX_BIT;
        vertShaderStageInfo.module = vertShaderModule;
        vertShaderStageInfo.pName = mainPtr;

        VkPipelineShaderStageCreateInfo fragShaderStageInfo = new VkPipelineShaderStageCreateInfo();
        fragShaderStageInfo.sType = VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO;
        fragShaderStageInfo.stage = VK_SHADER_STAGE_FRAGMENT_BIT;
        fragShaderStageInfo.module = fragShaderModule;
        fragShaderStageInfo.pName = mainPtr;

        VkPipelineShaderStageCreateInfo[] shaderStages = { vertShaderStageInfo, fragShaderStageInfo };
        GCHandle shaderStagesHandle = GCHandle.Alloc(shaderStages, GCHandleType.Pinned);

        VkPipelineVertexInputStateCreateInfo vertexInputInfo = new VkPipelineVertexInputStateCreateInfo();
        vertexInputInfo.sType = VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO;

        VkPipelineInputAssemblyStateCreateInfo inputAssembly = new VkPipelineInputAssemblyStateCreateInfo();
        inputAssembly.sType = VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO;
        inputAssembly.topology = VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST;

        VkPipelineViewportStateCreateInfo viewportState = new VkPipelineViewportStateCreateInfo();
        viewportState.sType = VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO;
        viewportState.viewportCount = 1;
        viewportState.scissorCount = 1;

        VkPipelineRasterizationStateCreateInfo rasterizer = new VkPipelineRasterizationStateCreateInfo();
        rasterizer.sType = VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO;
        rasterizer.polygonMode = VK_POLYGON_MODE_FILL;
        rasterizer.lineWidth = 1.0f;
        rasterizer.cullMode = VK_CULL_MODE_NONE;
        rasterizer.frontFace = VK_FRONT_FACE_COUNTER_CLOCKWISE;

        VkPipelineMultisampleStateCreateInfo multisampling = new VkPipelineMultisampleStateCreateInfo();
        multisampling.sType = VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO;
        multisampling.rasterizationSamples = VK_SAMPLE_COUNT_1_BIT;

        VkPipelineColorBlendAttachmentState colorBlendAttachment = new VkPipelineColorBlendAttachmentState();
        colorBlendAttachment.colorWriteMask = VK_COLOR_COMPONENT_R_BIT | VK_COLOR_COMPONENT_G_BIT | VK_COLOR_COMPONENT_B_BIT | VK_COLOR_COMPONENT_A_BIT;
        colorBlendAttachment.blendEnable = VK_FALSE;

        GCHandle blendAttachmentHandle = GCHandle.Alloc(colorBlendAttachment, GCHandleType.Pinned);

        VkPipelineColorBlendStateCreateInfo colorBlending = new VkPipelineColorBlendStateCreateInfo();
        colorBlending.sType = VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO;
        colorBlending.attachmentCount = 1;
        colorBlending.pAttachments = blendAttachmentHandle.AddrOfPinnedObject();

        uint[] dynamicStates = { VK_DYNAMIC_STATE_VIEWPORT, VK_DYNAMIC_STATE_SCISSOR };
        GCHandle dynamicStatesHandle = GCHandle.Alloc(dynamicStates, GCHandleType.Pinned);

        VkPipelineDynamicStateCreateInfo dynamicState = new VkPipelineDynamicStateCreateInfo();
        dynamicState.sType = VK_STRUCTURE_TYPE_PIPELINE_DYNAMIC_STATE_CREATE_INFO;
        dynamicState.dynamicStateCount = (uint)dynamicStates.Length;
        dynamicState.pDynamicStates = dynamicStatesHandle.AddrOfPinnedObject();

        // Push constant range for iTime and iResolution
        VkPushConstantRange pushConstantRange = new VkPushConstantRange();
        pushConstantRange.stageFlags = VK_SHADER_STAGE_FRAGMENT_BIT;
        pushConstantRange.offset = 0;
        pushConstantRange.size = 16; // 4 floats

        GCHandle pushConstantRangeHandle = GCHandle.Alloc(pushConstantRange, GCHandleType.Pinned);

        VkPipelineLayoutCreateInfo pipelineLayoutInfo = new VkPipelineLayoutCreateInfo();
        pipelineLayoutInfo.sType = VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO;
        pipelineLayoutInfo.pushConstantRangeCount = 1;
        pipelineLayoutInfo.pPushConstantRanges = pushConstantRangeHandle.AddrOfPinnedObject();

        int result = vkCreatePipelineLayout(device, ref pipelineLayoutInfo, IntPtr.Zero, out pipelineLayout);
        
        pushConstantRangeHandle.Free();
        
        if (result != VK_SUCCESS)
            throw new Exception("Failed to create pipeline layout: " + result);

        GCHandle vertexInputHandle = GCHandle.Alloc(vertexInputInfo, GCHandleType.Pinned);
        GCHandle inputAssemblyHandle = GCHandle.Alloc(inputAssembly, GCHandleType.Pinned);
        GCHandle viewportStateHandle = GCHandle.Alloc(viewportState, GCHandleType.Pinned);
        GCHandle rasterizerHandle = GCHandle.Alloc(rasterizer, GCHandleType.Pinned);
        GCHandle multisamplingHandle = GCHandle.Alloc(multisampling, GCHandleType.Pinned);
        GCHandle colorBlendingHandle = GCHandle.Alloc(colorBlending, GCHandleType.Pinned);
        GCHandle dynamicStateHandle = GCHandle.Alloc(dynamicState, GCHandleType.Pinned);

        VkGraphicsPipelineCreateInfo pipelineInfo = new VkGraphicsPipelineCreateInfo();
        pipelineInfo.sType = VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO;
        pipelineInfo.stageCount = 2;
        pipelineInfo.pStages = shaderStagesHandle.AddrOfPinnedObject();
        pipelineInfo.pVertexInputState = vertexInputHandle.AddrOfPinnedObject();
        pipelineInfo.pInputAssemblyState = inputAssemblyHandle.AddrOfPinnedObject();
        pipelineInfo.pViewportState = viewportStateHandle.AddrOfPinnedObject();
        pipelineInfo.pRasterizationState = rasterizerHandle.AddrOfPinnedObject();
        pipelineInfo.pMultisampleState = multisamplingHandle.AddrOfPinnedObject();
        pipelineInfo.pColorBlendState = colorBlendingHandle.AddrOfPinnedObject();
        pipelineInfo.pDynamicState = dynamicStateHandle.AddrOfPinnedObject();
        pipelineInfo.layout = pipelineLayout;
        pipelineInfo.renderPass = renderPass;
        pipelineInfo.subpass = 0;
        pipelineInfo.basePipelineIndex = -1;

        result = vkCreateGraphicsPipelines(device, IntPtr.Zero, 1, ref pipelineInfo, IntPtr.Zero, out graphicsPipeline);

        // Cleanup
        shaderStagesHandle.Free();
        blendAttachmentHandle.Free();
        dynamicStatesHandle.Free();
        vertexInputHandle.Free();
        inputAssemblyHandle.Free();
        viewportStateHandle.Free();
        rasterizerHandle.Free();
        multisamplingHandle.Free();
        colorBlendingHandle.Free();
        dynamicStateHandle.Free();

        vkDestroyShaderModule(device, fragShaderModule, IntPtr.Zero);
        vkDestroyShaderModule(device, vertShaderModule, IntPtr.Zero);
        Marshal.FreeHGlobal(mainPtr);

        if (result != VK_SUCCESS)
            throw new Exception("Failed to create graphics pipeline: " + result);
    }

    void CreateFramebuffers()
    {
        swapchainFramebuffers = new IntPtr[swapchainImageViews.Length];

        for (int i = 0; i < swapchainImageViews.Length; i++)
        {
            IntPtr[] attachments = { swapchainImageViews[i] };
            GCHandle attachmentsHandle = GCHandle.Alloc(attachments, GCHandleType.Pinned);

            VkFramebufferCreateInfo framebufferInfo = new VkFramebufferCreateInfo();
            framebufferInfo.sType = VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO;
            framebufferInfo.renderPass = renderPass;
            framebufferInfo.attachmentCount = 1;
            framebufferInfo.pAttachments = attachmentsHandle.AddrOfPinnedObject();
            framebufferInfo.width = swapchainExtentWidth;
            framebufferInfo.height = swapchainExtentHeight;
            framebufferInfo.layers = 1;

            int result = vkCreateFramebuffer(device, ref framebufferInfo, IntPtr.Zero, out swapchainFramebuffers[i]);
            attachmentsHandle.Free();

            if (result != VK_SUCCESS)
                throw new Exception("Failed to create framebuffer: " + result);
        }
    }

    void CreateCommandPool()
    {
        VkCommandPoolCreateInfo poolInfo = new VkCommandPoolCreateInfo();
        poolInfo.sType = VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO;
        poolInfo.flags = VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT;
        poolInfo.queueFamilyIndex = graphicsQueueFamily;

        int result = vkCreateCommandPool(device, ref poolInfo, IntPtr.Zero, out commandPool);
        if (result != VK_SUCCESS)
            throw new Exception("Failed to create command pool: " + result);
    }

    void CreateCommandBuffers()
    {
        commandBuffers = new IntPtr[MAX_FRAMES_IN_FLIGHT];

        VkCommandBufferAllocateInfo allocInfo = new VkCommandBufferAllocateInfo();
        allocInfo.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO;
        allocInfo.commandPool = commandPool;
        allocInfo.level = VK_COMMAND_BUFFER_LEVEL_PRIMARY;
        allocInfo.commandBufferCount = (uint)MAX_FRAMES_IN_FLIGHT;

        int result = vkAllocateCommandBuffers(device, ref allocInfo, commandBuffers);
        if (result != VK_SUCCESS)
            throw new Exception("Failed to allocate command buffers: " + result);
    }

    void CreateSyncObjects()
    {
        imageAvailableSemaphores = new IntPtr[MAX_FRAMES_IN_FLIGHT];
        renderFinishedSemaphores = new IntPtr[MAX_FRAMES_IN_FLIGHT];
        inFlightFences = new IntPtr[MAX_FRAMES_IN_FLIGHT];

        VkSemaphoreCreateInfo semaphoreInfo = new VkSemaphoreCreateInfo();
        semaphoreInfo.sType = VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO;

        VkFenceCreateInfo fenceInfo = new VkFenceCreateInfo();
        fenceInfo.sType = VK_STRUCTURE_TYPE_FENCE_CREATE_INFO;
        fenceInfo.flags = VK_FENCE_CREATE_SIGNALED_BIT;

        for (int i = 0; i < MAX_FRAMES_IN_FLIGHT; i++)
        {
            if (vkCreateSemaphore(device, ref semaphoreInfo, IntPtr.Zero, out imageAvailableSemaphores[i]) != VK_SUCCESS ||
                vkCreateSemaphore(device, ref semaphoreInfo, IntPtr.Zero, out renderFinishedSemaphores[i]) != VK_SUCCESS ||
                vkCreateFence(device, ref fenceInfo, IntPtr.Zero, out inFlightFences[i]) != VK_SUCCESS)
            {
                throw new Exception("Failed to create synchronization objects");
            }
        }
    }

    void RecordCommandBuffer(IntPtr commandBuffer, uint imageIndex)
    {
        VkCommandBufferBeginInfo beginInfo = new VkCommandBufferBeginInfo();
        beginInfo.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO;

        vkBeginCommandBuffer(commandBuffer, ref beginInfo);

        VkClearValue clearColor = new VkClearValue();
        clearColor.color.r = 0.0f;
        clearColor.color.g = 0.0f;
        clearColor.color.b = 0.0f;
        clearColor.color.a = 1.0f;

        GCHandle clearColorHandle = GCHandle.Alloc(clearColor, GCHandleType.Pinned);

        VkRenderPassBeginInfo renderPassInfo = new VkRenderPassBeginInfo();
        renderPassInfo.sType = VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO;
        renderPassInfo.renderPass = renderPass;
        renderPassInfo.framebuffer = swapchainFramebuffers[imageIndex];
        renderPassInfo.renderArea.offset.x = 0;
        renderPassInfo.renderArea.offset.y = 0;
        renderPassInfo.renderArea.extent.width = swapchainExtentWidth;
        renderPassInfo.renderArea.extent.height = swapchainExtentHeight;
        renderPassInfo.clearValueCount = 1;
        renderPassInfo.pClearValues = clearColorHandle.AddrOfPinnedObject();

        vkCmdBeginRenderPass(commandBuffer, ref renderPassInfo, VK_SUBPASS_CONTENTS_INLINE);
        vkCmdBindPipeline(commandBuffer, VK_PIPELINE_BIND_POINT_GRAPHICS, graphicsPipeline);

        VkViewport viewport = new VkViewport();
        viewport.x = 0.0f;
        viewport.y = 0.0f;
        viewport.width = swapchainExtentWidth;
        viewport.height = swapchainExtentHeight;
        viewport.minDepth = 0.0f;
        viewport.maxDepth = 1.0f;
        vkCmdSetViewport(commandBuffer, 0, 1, ref viewport);

        VkRect2D scissor = new VkRect2D();
        scissor.offset.x = 0;
        scissor.offset.y = 0;
        scissor.extent.width = swapchainExtentWidth;
        scissor.extent.height = swapchainExtentHeight;
        vkCmdSetScissor(commandBuffer, 0, 1, ref scissor);

        // Push constants for time and resolution
        PushConstants pushConstants = new PushConstants();
        pushConstants.iTime = (float)stopwatch.Elapsed.TotalSeconds;
        pushConstants.padding = 0.0f;
        pushConstants.iResolutionX = swapchainExtentWidth;
        pushConstants.iResolutionY = swapchainExtentHeight;

        GCHandle pushConstantsHandle = GCHandle.Alloc(pushConstants, GCHandleType.Pinned);
        vkCmdPushConstants(commandBuffer, pipelineLayout, VK_SHADER_STAGE_FRAGMENT_BIT, 0, 16, pushConstantsHandle.AddrOfPinnedObject());
        pushConstantsHandle.Free();

        vkCmdDraw(commandBuffer, 3, 1, 0, 0);

        vkCmdEndRenderPass(commandBuffer);
        vkEndCommandBuffer(commandBuffer);

        clearColorHandle.Free();
    }

    void DrawFrame()
    {
        if (device == IntPtr.Zero) return;

        IntPtr[] fences = { inFlightFences[currentFrame] };
        vkWaitForFences(device, 1, fences, VK_TRUE, VK_WHOLE_SIZE);

        uint imageIndex;
        int result = vkAcquireNextImageKHR(device, swapchain, VK_WHOLE_SIZE, imageAvailableSemaphores[currentFrame], IntPtr.Zero, out imageIndex);

        if (result == VK_ERROR_OUT_OF_DATE_KHR)
        {
            RecreateSwapchain();
            return;
        }

        vkResetFences(device, 1, fences);
        vkResetCommandBuffer(commandBuffers[currentFrame], 0);
        RecordCommandBuffer(commandBuffers[currentFrame], imageIndex);

        IntPtr[] waitSemaphores = { imageAvailableSemaphores[currentFrame] };
        IntPtr[] signalSemaphores = { renderFinishedSemaphores[currentFrame] };
        uint[] waitStages = { VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT };
        IntPtr[] cmdBuffers = { commandBuffers[currentFrame] };

        GCHandle waitSemaphoresHandle = GCHandle.Alloc(waitSemaphores, GCHandleType.Pinned);
        GCHandle signalSemaphoresHandle = GCHandle.Alloc(signalSemaphores, GCHandleType.Pinned);
        GCHandle waitStagesHandle = GCHandle.Alloc(waitStages, GCHandleType.Pinned);
        GCHandle cmdBuffersHandle = GCHandle.Alloc(cmdBuffers, GCHandleType.Pinned);

        VkSubmitInfo submitInfo = new VkSubmitInfo();
        submitInfo.sType = VK_STRUCTURE_TYPE_SUBMIT_INFO;
        submitInfo.waitSemaphoreCount = 1;
        submitInfo.pWaitSemaphores = waitSemaphoresHandle.AddrOfPinnedObject();
        submitInfo.pWaitDstStageMask = waitStagesHandle.AddrOfPinnedObject();
        submitInfo.commandBufferCount = 1;
        submitInfo.pCommandBuffers = cmdBuffersHandle.AddrOfPinnedObject();
        submitInfo.signalSemaphoreCount = 1;
        submitInfo.pSignalSemaphores = signalSemaphoresHandle.AddrOfPinnedObject();

        vkQueueSubmit(graphicsQueue, 1, ref submitInfo, inFlightFences[currentFrame]);

        IntPtr[] swapchains = { swapchain };
        uint[] imageIndices = { imageIndex };

        GCHandle swapchainsHandle = GCHandle.Alloc(swapchains, GCHandleType.Pinned);
        GCHandle imageIndicesHandle = GCHandle.Alloc(imageIndices, GCHandleType.Pinned);

        VkPresentInfoKHR presentInfo = new VkPresentInfoKHR();
        presentInfo.sType = VK_STRUCTURE_TYPE_PRESENT_INFO_KHR;
        presentInfo.waitSemaphoreCount = 1;
        presentInfo.pWaitSemaphores = signalSemaphoresHandle.AddrOfPinnedObject();
        presentInfo.swapchainCount = 1;
        presentInfo.pSwapchains = swapchainsHandle.AddrOfPinnedObject();
        presentInfo.pImageIndices = imageIndicesHandle.AddrOfPinnedObject();

        result = vkQueuePresentKHR(presentQueue, ref presentInfo);

        waitSemaphoresHandle.Free();
        signalSemaphoresHandle.Free();
        waitStagesHandle.Free();
        cmdBuffersHandle.Free();
        swapchainsHandle.Free();
        imageIndicesHandle.Free();

        if (result == VK_ERROR_OUT_OF_DATE_KHR || result == VK_SUBOPTIMAL_KHR || framebufferResized)
        {
            framebufferResized = false;
            RecreateSwapchain();
        }

        currentFrame = (currentFrame + 1) % MAX_FRAMES_IN_FLIGHT;
    }

    void CleanupSwapchain()
    {
        foreach (var framebuffer in swapchainFramebuffers)
            vkDestroyFramebuffer(device, framebuffer, IntPtr.Zero);

        foreach (var imageView in swapchainImageViews)
            vkDestroyImageView(device, imageView, IntPtr.Zero);

        vkDestroySwapchainKHR(device, swapchain, IntPtr.Zero);
    }

    void RecreateSwapchain()
    {
        if (this.ClientSize.Width == 0 || this.ClientSize.Height == 0)
            return;

        vkDeviceWaitIdle(device);
        CleanupSwapchain();

        CreateSwapchain();
        CreateImageViews();
        CreateFramebuffers();
    }

    void Cleanup()
    {
        if (device == IntPtr.Zero) return;

        vkDeviceWaitIdle(device);

        for (int i = 0; i < MAX_FRAMES_IN_FLIGHT; i++)
        {
            vkDestroySemaphore(device, renderFinishedSemaphores[i], IntPtr.Zero);
            vkDestroySemaphore(device, imageAvailableSemaphores[i], IntPtr.Zero);
            vkDestroyFence(device, inFlightFences[i], IntPtr.Zero);
        }

        vkDestroyCommandPool(device, commandPool, IntPtr.Zero);

        foreach (var framebuffer in swapchainFramebuffers)
            vkDestroyFramebuffer(device, framebuffer, IntPtr.Zero);

        vkDestroyPipeline(device, graphicsPipeline, IntPtr.Zero);
        vkDestroyPipelineLayout(device, pipelineLayout, IntPtr.Zero);
        vkDestroyRenderPass(device, renderPass, IntPtr.Zero);

        foreach (var imageView in swapchainImageViews)
            vkDestroyImageView(device, imageView, IntPtr.Zero);

        vkDestroySwapchainKHR(device, swapchain, IntPtr.Zero);
        vkDestroyDevice(device, IntPtr.Zero);
        vkDestroySurfaceKHR(instance, surface, IntPtr.Zero);
        vkDestroyInstance(instance, IntPtr.Zero);
    }

    [STAThread]
    public static void Main(string[] args)
    {
        if (args.Length < 2)
        {
            Console.WriteLine("Usage: VulkanRaymarching <vertex_shader.vert> <fragment_shader.frag>");
            return;
        }

        Application.EnableVisualStyles();
        Application.SetCompatibleTextRenderingDefault(false);
        Application.Run(new VulkanRaymarching(args[0], args[1]));
    }
}
'@

$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
if ([string]::IsNullOrEmpty($scriptPath)) {
    $scriptPath = Get-Location
}

$vertShaderPath = Join-Path $scriptPath "hello.vert"
$fragShaderPath = Join-Path $scriptPath "hello.frag"

if (-not (Test-Path $vertShaderPath)) {
    Write-Host "Error: hello.vert not found at $vertShaderPath"
    Write-Host "Please place hello.vert in the same directory as this script."
    exit 1
}

if (-not (Test-Path $fragShaderPath)) {
    Write-Host "Error: hello.frag not found at $fragShaderPath"
    Write-Host "Please place hello.frag in the same directory as this script."
    exit 1
}

$glslangPath = Get-Command glslangValidator -ErrorAction SilentlyContinue
if ($null -eq $glslangPath) {
    Write-Host "Error: glslangValidator not found."
    Write-Host "Please install Vulkan SDK from https://vulkan.lunarg.com/ and add it to PATH."
    exit 1
}

Write-Host "Vulkan 1.4 Raymarching Sample (PowerShell)"
Write-Host "==========================================="
Write-Host "Vertex Shader: $vertShaderPath"
Write-Host "Fragment Shader: $fragShaderPath"
Write-Host ""
Write-Host "Compiling C# code and running..."

try {
    Add-Type -TypeDefinition $VulkanCode -ReferencedAssemblies @(
        'System.Windows.Forms',
        'System.Drawing',
        'System.Drawing.Primitives'
    ) -Language CSharp

    [System.Windows.Forms.Application]::EnableVisualStyles()
    [System.Windows.Forms.Application]::SetCompatibleTextRenderingDefault($false)
    
    $form = New-Object VulkanRaymarching($vertShaderPath, $fragShaderPath)
    [System.Windows.Forms.Application]::Run($form)
}
catch {
    Write-Host "Error: $_"
    Write-Host ""
    Write-Host "Note: This sample requires:"
    Write-Host "  1. Windows OS with Vulkan 1.4 capable GPU and drivers"
    Write-Host "  2. Vulkan SDK installed (for glslangValidator)"
    Write-Host "  3. vulkan-1.dll in system PATH"
}
