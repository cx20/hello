open System
open System.Drawing
open System.Runtime.InteropServices
open System.Windows.Forms
open System.IO
open System.Text

// ========================================================================================================
// Shader Compiler (shaderc_shared.dll)
// ========================================================================================================

module ShaderCompiler =
    [<DllImport("shaderc_shared.dll", CallingConvention = CallingConvention.Cdecl)>]
    extern IntPtr private shaderc_compiler_initialize()
    
    [<DllImport("shaderc_shared.dll", CallingConvention = CallingConvention.Cdecl)>]
    extern void private shaderc_compiler_release(IntPtr compiler)
    
    [<DllImport("shaderc_shared.dll", CallingConvention = CallingConvention.Cdecl)>]
    extern IntPtr private shaderc_compile_options_initialize()
    
    [<DllImport("shaderc_shared.dll", CallingConvention = CallingConvention.Cdecl)>]
    extern void private shaderc_compile_options_set_optimization_level(IntPtr options, int level)
    
    [<DllImport("shaderc_shared.dll", CallingConvention = CallingConvention.Cdecl)>]
    extern void private shaderc_compile_options_release(IntPtr options)
    
    [<DllImport("shaderc_shared.dll", CallingConvention = CallingConvention.Cdecl)>]
    extern IntPtr private shaderc_compile_into_spv(IntPtr compiler, [<MarshalAs(UnmanagedType.LPStr)>] string source, unativeint size, int kind, [<MarshalAs(UnmanagedType.LPStr)>] string fileName, [<MarshalAs(UnmanagedType.LPStr)>] string entryPoint, IntPtr options)
    
    [<DllImport("shaderc_shared.dll", CallingConvention = CallingConvention.Cdecl)>]
    extern void private shaderc_result_release(IntPtr result)
    
    [<DllImport("shaderc_shared.dll", CallingConvention = CallingConvention.Cdecl)>]
    extern unativeint private shaderc_result_get_length(IntPtr result)
    
    [<DllImport("shaderc_shared.dll", CallingConvention = CallingConvention.Cdecl)>]
    extern IntPtr private shaderc_result_get_bytes(IntPtr result)
    
    [<DllImport("shaderc_shared.dll", CallingConvention = CallingConvention.Cdecl)>]
    extern int private shaderc_result_get_compilation_status(IntPtr result)
    
    [<DllImport("shaderc_shared.dll", CallingConvention = CallingConvention.Cdecl)>]
    extern IntPtr private shaderc_result_get_error_message(IntPtr result)

    /// Compile GLSL source to SPIR-V bytecode.
    /// kind: 0 = vertex, 1 = fragment
    let Compile (source: string) (kind: int) (fileName: string) : byte[] =
        let compiler = shaderc_compiler_initialize()
        let options  = shaderc_compile_options_initialize()
        shaderc_compile_options_set_optimization_level(options, 2)
        try
            let sourceSize = unativeint (Encoding.UTF8.GetByteCount(source))
            let result = shaderc_compile_into_spv(compiler, source, sourceSize, kind, fileName, "main", options)
            try
                let status = shaderc_result_get_compilation_status(result)
                if status <> 0 then
                    let errorMsg = Marshal.PtrToStringAnsi(shaderc_result_get_error_message(result))
                    failwithf "Shader compilation failed: %s" errorMsg
                let length   = int (shaderc_result_get_length(result))
                let bytesPtr = shaderc_result_get_bytes(result)
                let bytecode = Array.zeroCreate<byte> length
                Marshal.Copy(bytesPtr, bytecode, 0, length)
                bytecode
            finally
                shaderc_result_release(result)
        finally
            shaderc_compile_options_release(options)
            shaderc_compiler_release(compiler)

// ========================================================================================================
// Vulkan Enums
// ========================================================================================================

type VkStructureType =
    | VK_STRUCTURE_TYPE_APPLICATION_INFO                     = 0u
    | VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO                 = 1u
    | VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO             = 2u
    | VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO                   = 3u
    | VK_STRUCTURE_TYPE_SUBMIT_INFO                          = 4u
    | VK_STRUCTURE_TYPE_FENCE_CREATE_INFO                    = 8u
    | VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO                = 9u
    | VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO               = 15u
    | VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO            = 16u
    | VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO   = 18u
    | VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO = 19u
    | VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO = 20u
    | VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO = 22u
    | VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO = 23u
    | VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO = 24u
    | VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO = 26u
    | VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO        = 28u
    | VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO          = 30u
    | VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO              = 37u
    | VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO              = 38u
    | VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO             = 39u
    | VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO         = 40u
    | VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO            = 42u
    | VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO               = 43u
    | VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR            = 1000001000u
    | VK_STRUCTURE_TYPE_PRESENT_INFO_KHR                     = 1000001001u
    | VK_STRUCTURE_TYPE_WIN32_SURFACE_CREATE_INFO_KHR        = 1000009000u

type VkResult =
    | VK_SUCCESS                  =  0
    | VK_SUBOPTIMAL_KHR           =  1000001003
    | VK_ERROR_OUT_OF_DATE_KHR    = -1000001004

type VkFormat =
    | VK_FORMAT_UNDEFINED      = 0
    | VK_FORMAT_B8G8R8A8_SRGB  = 50
    | VK_FORMAT_B8G8R8A8_UNORM = 44

type VkColorSpaceKHR          = VK_COLOR_SPACE_SRGB_NONLINEAR_KHR = 0
type VkPresentModeKHR         = VK_PRESENT_MODE_FIFO_KHR = 2
type VkSharingMode            = VK_SHARING_MODE_EXCLUSIVE = 0
type VkImageUsageFlags        = VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT = 0x10u
type VkCompositeAlphaFlagsKHR = VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR = 0x1u
type VkImageViewType          = VK_IMAGE_VIEW_TYPE_2D = 1
type VkComponentSwizzle       = VK_COMPONENT_SWIZZLE_IDENTITY = 0
type VkImageAspectFlags       = VK_IMAGE_ASPECT_COLOR_BIT = 0x1u
type VkShaderStageFlags       = VK_SHADER_STAGE_VERTEX_BIT = 0x1u | VK_SHADER_STAGE_FRAGMENT_BIT = 0x10u | VK_SHADER_STAGE_ALL_GRAPHICS = 0x1Fu
type VkPrimitiveTopology      = VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST = 3
type VkPolygonMode            = VK_POLYGON_MODE_FILL = 0
type VkCullModeFlags          = VK_CULL_MODE_NONE = 0u
type VkFrontFace              = VK_FRONT_FACE_CLOCKWISE = 1
type VkSampleCountFlags       = VK_SAMPLE_COUNT_1_BIT = 0x1u
type VkBlendFactor            = VK_BLEND_FACTOR_ONE = 1 | VK_BLEND_FACTOR_ZERO = 0
type VkBlendOp                = VK_BLEND_OP_ADD = 0
type VkAttachmentLoadOp       = VK_ATTACHMENT_LOAD_OP_CLEAR = 1 | VK_ATTACHMENT_LOAD_OP_DONT_CARE = 2
type VkAttachmentStoreOp      = VK_ATTACHMENT_STORE_OP_STORE = 0 | VK_ATTACHMENT_STORE_OP_DONT_CARE = 1
type VkImageLayout            = VK_IMAGE_LAYOUT_UNDEFINED = 0 | VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL = 2 | VK_IMAGE_LAYOUT_PRESENT_SRC_KHR = 1000001002
type VkPipelineBindPoint      = VK_PIPELINE_BIND_POINT_GRAPHICS = 0
type VkPipelineStageFlags     = VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT = 0x400u
type VkCommandPoolCreateFlags = VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT = 0x2u
type VkCommandBufferLevel     = VK_COMMAND_BUFFER_LEVEL_PRIMARY = 0
type VkSubpassContents        = VK_SUBPASS_CONTENTS_INLINE = 0
type VkCommandBufferUsageFlags = VK_COMMAND_BUFFER_USAGE_SIMULTANEOUS_USE_BIT = 0x4u

// ========================================================================================================
// Vulkan Structures
// ========================================================================================================

[<Struct; StructLayout(LayoutKind.Sequential, CharSet = CharSet.Ansi)>]
type VkApplicationInfo = {
    mutable sType: uint32
    mutable pNext: nativeint
    [<MarshalAs(UnmanagedType.LPStr)>] mutable pApplicationName: string
    mutable applicationVersion: uint32
    [<MarshalAs(UnmanagedType.LPStr)>] mutable pEngineName: string
    mutable engineVersion: uint32
    mutable apiVersion: uint32
}

[<Struct; StructLayout(LayoutKind.Sequential)>]
type VkInstanceCreateInfo = {
    mutable sType: uint32; mutable pNext: nativeint; mutable flags: uint32
    mutable pApplicationInfo: nativeint
    mutable enabledLayerCount: uint32; mutable ppEnabledLayerNames: nativeint
    mutable enabledExtensionCount: uint32; mutable ppEnabledExtensionNames: nativeint
}

[<Struct; StructLayout(LayoutKind.Sequential)>]
type VkWin32SurfaceCreateInfoKHR = {
    mutable sType: uint32; mutable pNext: nativeint; mutable flags: uint32
    mutable hinstance: nativeint; mutable hwnd: nativeint
}

[<Struct; StructLayout(LayoutKind.Sequential)>]
type VkDeviceQueueCreateInfo = {
    mutable sType: uint32; mutable pNext: nativeint; mutable flags: uint32
    mutable queueFamilyIndex: uint32; mutable queueCount: uint32; mutable pQueuePriorities: nativeint
}

[<Struct; StructLayout(LayoutKind.Sequential)>]
type VkDeviceCreateInfo = {
    mutable sType: uint32; mutable pNext: nativeint; mutable flags: uint32
    mutable queueCreateInfoCount: uint32; mutable pQueueCreateInfos: nativeint
    mutable enabledLayerCount: uint32; mutable ppEnabledLayerNames: nativeint
    mutable enabledExtensionCount: uint32; mutable ppEnabledExtensionNames: nativeint
    mutable pEnabledFeatures: nativeint
}

[<Struct; StructLayout(LayoutKind.Sequential)>]
type VkExtent3D = { mutable width: uint32; mutable height: uint32; mutable depth: uint32 }

[<Struct; StructLayout(LayoutKind.Sequential)>]
type VkQueueFamilyProperties = {
    mutable queueFlags: uint32; mutable queueCount: uint32
    mutable timestampValidBits: uint32; mutable minImageTransferGranularity: VkExtent3D
}

[<Struct; StructLayout(LayoutKind.Sequential)>]
type VkOffset2D = { mutable x: int; mutable y: int }

[<Struct; StructLayout(LayoutKind.Sequential)>]
type VkExtent2D = { mutable width: uint32; mutable height: uint32 }

[<Struct; StructLayout(LayoutKind.Sequential)>]
type VkSurfaceCapabilitiesKHR = {
    mutable minImageCount: uint32; mutable maxImageCount: uint32
    mutable currentExtent: VkExtent2D; mutable minImageExtent: VkExtent2D
    mutable maxImageExtent: VkExtent2D; mutable maxImageArrayLayers: uint32
    mutable supportedTransforms: uint32; mutable currentTransform: uint32
    mutable supportedCompositeAlpha: uint32; mutable supportedUsageFlags: uint32
}

[<Struct; StructLayout(LayoutKind.Sequential)>]
type VkSurfaceFormatKHR = { mutable format: int; mutable colorSpace: int }

[<Struct; StructLayout(LayoutKind.Sequential)>]
type VkSwapchainCreateInfoKHR = {
    mutable sType: uint32; mutable pNext: nativeint; mutable flags: uint32
    mutable surface: nativeint; mutable minImageCount: uint32
    mutable imageFormat: int; mutable imageColorSpace: int; mutable imageExtent: VkExtent2D
    mutable imageArrayLayers: uint32; mutable imageUsage: uint32
    mutable imageSharingMode: int; mutable queueFamilyIndexCount: uint32
    mutable pQueueFamilyIndices: nativeint; mutable preTransform: uint32
    mutable compositeAlpha: uint32; mutable presentMode: int
    mutable clipped: uint32; mutable oldSwapchain: nativeint
}

[<Struct; StructLayout(LayoutKind.Sequential)>]
type VkComponentMapping = { mutable r: int; mutable g: int; mutable b: int; mutable a: int }

[<Struct; StructLayout(LayoutKind.Sequential)>]
type VkImageSubresourceRange = {
    mutable aspectMask: uint32; mutable baseMipLevel: uint32; mutable levelCount: uint32
    mutable baseArrayLayer: uint32; mutable layerCount: uint32
}

[<Struct; StructLayout(LayoutKind.Sequential)>]
type VkImageViewCreateInfo = {
    mutable sType: int; mutable pNext: nativeint; mutable flags: uint32
    mutable image: nativeint; mutable viewType: int; mutable format: int
    mutable components: VkComponentMapping; mutable subresourceRange: VkImageSubresourceRange
}

[<Struct; StructLayout(LayoutKind.Sequential)>]
type VkAttachmentDescription = {
    mutable flags: uint32; mutable format: int; mutable samples: int
    mutable loadOp: int; mutable storeOp: int
    mutable stencilLoadOp: int; mutable stencilStoreOp: int
    mutable initialLayout: int; mutable finalLayout: int
}

[<Struct; StructLayout(LayoutKind.Sequential)>]
type VkAttachmentReference = { mutable attachment: uint32; mutable layout: int }

[<Struct; StructLayout(LayoutKind.Sequential)>]
type VkSubpassDescription = {
    mutable flags: uint32; mutable pipelineBindPoint: int
    mutable inputAttachmentCount: uint32; mutable pInputAttachments: nativeint
    mutable colorAttachmentCount: uint32; mutable pColorAttachments: nativeint
    mutable pResolveAttachments: nativeint; mutable pDepthStencilAttachment: nativeint
    mutable preserveAttachmentCount: uint32; mutable pPreserveAttachments: nativeint
}

[<Struct; StructLayout(LayoutKind.Sequential)>]
type VkSubpassDependency = {
    mutable srcSubpass: uint32; mutable dstSubpass: uint32
    mutable srcStageMask: uint32; mutable dstStageMask: uint32
    mutable srcAccessMask: uint32; mutable dstAccessMask: uint32
    mutable dependencyFlags: uint32
}

[<Struct; StructLayout(LayoutKind.Sequential)>]
type VkRenderPassCreateInfo = {
    mutable sType: int; mutable pNext: nativeint; mutable flags: uint32
    mutable attachmentCount: uint32; mutable pAttachments: nativeint
    mutable subpassCount: uint32; mutable pSubpasses: nativeint
    mutable dependencyCount: uint32; mutable pDependencies: nativeint
}

[<Struct; StructLayout(LayoutKind.Sequential)>]
type VkShaderModuleCreateInfo = {
    mutable sType: int; mutable pNext: nativeint; mutable flags: uint32
    mutable codeSize: nativeint; mutable pCode: nativeint
}

// Push constant range: specifies which shader stages can access push constants
// and the byte range within the push constant block
[<Struct; StructLayout(LayoutKind.Sequential)>]
type VkPushConstantRange = {
    mutable stageFlags: uint32  // Which shader stages can read this range
    mutable offset: uint32      // Byte offset within the push constant block
    mutable size: uint32        // Size in bytes of the range
}

[<Struct; StructLayout(LayoutKind.Sequential)>]
type VkPipelineLayoutCreateInfo = {
    mutable sType: int; mutable pNext: nativeint; mutable flags: uint32
    mutable setLayoutCount: uint32; mutable pSetLayouts: nativeint
    mutable pushConstantRangeCount: uint32; mutable pPushConstantRanges: nativeint
}

[<Struct; StructLayout(LayoutKind.Sequential)>]
type VkPipelineShaderStageCreateInfo = {
    mutable sType: int; mutable pNext: nativeint; mutable flags: uint32
    mutable stage: int; mutable modul: nativeint; mutable pName: nativeint
    mutable pSpecializationInfo: nativeint
}

[<Struct; StructLayout(LayoutKind.Sequential)>]
type VkPipelineVertexInputStateCreateInfo = {
    mutable sType: int; mutable pNext: nativeint; mutable flags: uint32
    mutable vertexBindingDescriptionCount: uint32; mutable pVertexBindingDescriptions: nativeint
    mutable vertexAttributeDescriptionCount: uint32; mutable pVertexAttributeDescriptions: nativeint
}

[<Struct; StructLayout(LayoutKind.Sequential)>]
type VkPipelineInputAssemblyStateCreateInfo = {
    mutable sType: int; mutable pNext: nativeint; mutable flags: uint32
    mutable topology: int; mutable primitiveRestartEnable: uint32
}

[<Struct; StructLayout(LayoutKind.Sequential)>]
type VkViewport = {
    mutable x: float32; mutable y: float32
    mutable width: float32; mutable height: float32
    mutable minDepth: float32; mutable maxDepth: float32
}

[<Struct; StructLayout(LayoutKind.Sequential)>]
type VkRect2D = { mutable offset: VkOffset2D; mutable extent: VkExtent2D }

[<Struct; StructLayout(LayoutKind.Sequential)>]
type VkPipelineViewportStateCreateInfo = {
    mutable sType: int; mutable pNext: nativeint; mutable flags: uint32
    mutable viewportCount: uint32; mutable pViewports: nativeint
    mutable scissorCount: uint32; mutable pScissors: nativeint
}

[<Struct; StructLayout(LayoutKind.Sequential)>]
type VkPipelineRasterizationStateCreateInfo = {
    mutable sType: int; mutable pNext: nativeint; mutable flags: uint32
    mutable depthClampEnable: uint32; mutable rasterizerDiscardEnable: uint32
    mutable polygonMode: int; mutable cullMode: uint32; mutable frontFace: int
    mutable depthBiasEnable: uint32
    mutable depthBiasConstantFactor: float32; mutable depthBiasClamp: float32
    mutable depthBiasSlopeFactor: float32; mutable lineWidth: float32
}

[<Struct; StructLayout(LayoutKind.Sequential)>]
type VkPipelineMultisampleStateCreateInfo = {
    mutable sType: int; mutable pNext: nativeint; mutable flags: uint32
    mutable rasterizationSamples: int; mutable sampleShadingEnable: uint32
    mutable minSampleShading: float32; mutable pSampleMask: nativeint
    mutable alphaToCoverageEnable: uint32; mutable alphaToOneEnable: uint32
}

[<Struct; StructLayout(LayoutKind.Sequential)>]
type VkPipelineColorBlendAttachmentState = {
    mutable blendEnable: uint32
    mutable srcColorBlendFactor: int; mutable dstColorBlendFactor: int; mutable colorBlendOp: int
    mutable srcAlphaBlendFactor: int; mutable dstAlphaBlendFactor: int; mutable alphaBlendOp: int
    mutable colorWriteMask: uint32
}

[<Struct; StructLayout(LayoutKind.Sequential)>]
type VkPipelineColorBlendStateCreateInfo = {
    mutable sType: int; mutable pNext: nativeint; mutable flags: uint32
    mutable logicOpEnable: uint32; mutable logicOp: int
    mutable attachmentCount: uint32; mutable pAttachments: nativeint
    mutable blendConstants: nativeint
}

[<Struct; StructLayout(LayoutKind.Sequential)>]
type VkGraphicsPipelineCreateInfo = {
    mutable sType: int; mutable pNext: nativeint; mutable flags: uint32
    mutable stageCount: uint32; mutable pStages: nativeint
    mutable pVertexInputState: nativeint; mutable pInputAssemblyState: nativeint
    mutable pTessellationState: nativeint; mutable pViewportState: nativeint
    mutable pRasterizationState: nativeint; mutable pMultisampleState: nativeint
    mutable pDepthStencilState: nativeint; mutable pColorBlendState: nativeint
    mutable pDynamicState: nativeint; mutable layout: nativeint
    mutable renderPass: nativeint; mutable subpass: uint32
    mutable basePipelineHandle: nativeint; mutable basePipelineIndex: int
}

[<Struct; StructLayout(LayoutKind.Sequential)>]
type VkFramebufferCreateInfo = {
    mutable sType: int; mutable pNext: nativeint; mutable flags: uint32
    mutable renderPass: nativeint; mutable attachmentCount: uint32; mutable pAttachments: nativeint
    mutable width: uint32; mutable height: uint32; mutable layers: uint32
}

[<Struct; StructLayout(LayoutKind.Sequential)>]
type VkCommandPoolCreateInfo = {
    mutable sType: int; mutable pNext: nativeint; mutable flags: uint32
    mutable queueFamilyIndex: uint32
}

[<Struct; StructLayout(LayoutKind.Sequential)>]
type VkCommandBufferAllocateInfo = {
    mutable sType: int; mutable pNext: nativeint
    mutable commandPool: nativeint; mutable level: int; mutable commandBufferCount: uint32
}

[<Struct; StructLayout(LayoutKind.Sequential)>]
type VkCommandBufferBeginInfo = {
    mutable sType: int; mutable pNext: nativeint; mutable flags: uint32
    mutable pInheritanceInfo: nativeint
}

[<Struct; StructLayout(LayoutKind.Sequential)>]
type VkSemaphoreCreateInfo = { mutable sType: int; mutable pNext: nativeint; mutable flags: uint32 }

[<Struct; StructLayout(LayoutKind.Sequential)>]
type VkFenceCreateInfo = { mutable sType: int; mutable pNext: nativeint; mutable flags: uint32 }

[<Struct; StructLayout(LayoutKind.Sequential)>]
type VkClearColorValue = {
    mutable float32_0: float32; mutable float32_1: float32
    mutable float32_2: float32; mutable float32_3: float32
}

[<Struct; StructLayout(LayoutKind.Sequential)>]
type VkClearDepthStencilValue = { mutable depth: float32; mutable stencil: uint32 }

[<Struct; StructLayout(LayoutKind.Explicit)>]
type VkClearValue = {
    [<FieldOffset(0)>] mutable color: VkClearColorValue
    [<FieldOffset(0)>] mutable depthStencil: VkClearDepthStencilValue
}

[<Struct; StructLayout(LayoutKind.Sequential)>]
type VkRenderPassBeginInfo = {
    mutable sType: int; mutable pNext: nativeint
    mutable renderPass: nativeint; mutable framebuffer: nativeint
    mutable renderArea: VkRect2D
    mutable clearValueCount: uint32; mutable pClearValues: nativeint
}

[<Struct; StructLayout(LayoutKind.Sequential)>]
type VkSubmitInfo = {
    mutable sType: int; mutable pNext: nativeint
    mutable waitSemaphoreCount: uint32; mutable pWaitSemaphores: nativeint
    mutable pWaitDstStageMask: nativeint
    mutable commandBufferCount: uint32; mutable pCommandBuffers: nativeint
    mutable signalSemaphoreCount: uint32; mutable pSignalSemaphores: nativeint
}

[<Struct; StructLayout(LayoutKind.Sequential)>]
type VkPresentInfoKHR = {
    mutable sType: int; mutable pNext: nativeint
    mutable waitSemaphoreCount: uint32; mutable pWaitSemaphores: nativeint
    mutable swapchainCount: uint32; mutable pSwapchains: nativeint
    mutable pImageIndices: nativeint; mutable pResults: nativeint
}

/// Push constants layout matching the GLSL shader:
///   layout(push_constant) uniform PushConstants {
///       float iTime;      // elapsed time in seconds
///       float padding;    // alignment padding
///       vec2  iResolution;// viewport width / height
///   } pc;
[<Struct; StructLayout(LayoutKind.Sequential)>]
type RayMarchPushConstants = {
    mutable iTime: float32
    mutable padding: float32
    mutable iResolutionX: float32
    mutable iResolutionY: float32
}

// ========================================================================================================
// Vulkan P/Invoke
// ========================================================================================================

type vkCreateWin32SurfaceKHRFunc = delegate of nativeint * VkWin32SurfaceCreateInfoKHR byref * nativeint * nativeint byref -> int

[<DllImport("kernel32.dll", CharSet = CharSet.Auto)>]
extern IntPtr GetModuleHandle(string lpModuleName)

[<DllImport("vulkan-1.dll")>] extern int    vkCreateInstance(VkInstanceCreateInfo& pCreateInfo, nativeint pAllocator, nativeint& pInstance)
[<DllImport("vulkan-1.dll", CharSet = CharSet.Ansi)>] extern nativeint vkGetInstanceProcAddr(nativeint instance, [<MarshalAs(UnmanagedType.LPStr)>] string pName)
[<DllImport("vulkan-1.dll")>] extern void   vkDestroyInstance(nativeint instance, nativeint pAllocator)
[<DllImport("vulkan-1.dll")>] extern void   vkDestroySurfaceKHR(nativeint instance, nativeint surface, nativeint pAllocator)
[<DllImport("vulkan-1.dll")>] extern int    vkEnumeratePhysicalDevices(nativeint instance, uint32& pPhysicalDeviceCount, nativeint pPhysicalDevices)
[<DllImport("vulkan-1.dll")>] extern void   vkGetPhysicalDeviceQueueFamilyProperties(nativeint physicalDevice, uint32& pQueueFamilyPropertyCount, nativeint pQueueFamilyProperties)
[<DllImport("vulkan-1.dll")>] extern int    vkGetPhysicalDeviceSurfaceSupportKHR(nativeint physicalDevice, uint32 queueFamilyIndex, nativeint surface, uint32& pSupported)
[<DllImport("vulkan-1.dll")>] extern int    vkCreateDevice(nativeint physicalDevice, VkDeviceCreateInfo& pCreateInfo, nativeint pAllocator, nativeint& pDevice)
[<DllImport("vulkan-1.dll")>] extern void   vkGetDeviceQueue(nativeint device, uint32 queueFamilyIndex, uint32 queueIndex, nativeint& pQueue)
[<DllImport("vulkan-1.dll")>] extern int    vkDeviceWaitIdle(nativeint device)
[<DllImport("vulkan-1.dll")>] extern void   vkDestroyDevice(nativeint device, nativeint pAllocator)
[<DllImport("vulkan-1.dll")>] extern int    vkGetPhysicalDeviceSurfaceCapabilitiesKHR(nativeint physicalDevice, nativeint surface, VkSurfaceCapabilitiesKHR& pSurfaceCapabilities)
[<DllImport("vulkan-1.dll")>] extern int    vkGetPhysicalDeviceSurfaceFormatsKHR(nativeint physicalDevice, nativeint surface, uint32& pSurfaceFormatCount, nativeint pSurfaceFormats)
[<DllImport("vulkan-1.dll")>] extern int    vkGetPhysicalDeviceSurfacePresentModesKHR(nativeint physicalDevice, nativeint surface, uint32& pPresentModeCount, nativeint pPresentModes)
[<DllImport("vulkan-1.dll")>] extern int    vkCreateSwapchainKHR(nativeint device, VkSwapchainCreateInfoKHR& pCreateInfo, nativeint pAllocator, nativeint& pSwapchain)
[<DllImport("vulkan-1.dll")>] extern void   vkDestroySwapchainKHR(nativeint device, nativeint swapchain, nativeint pAllocator)
[<DllImport("vulkan-1.dll")>] extern int    vkGetSwapchainImagesKHR(nativeint device, nativeint swapchain, uint32& pSwapchainImageCount, nativeint pSwapchainImages)
[<DllImport("vulkan-1.dll")>] extern int    vkCreateImageView(nativeint device, VkImageViewCreateInfo& pCreateInfo, nativeint pAllocator, nativeint& pView)
[<DllImport("vulkan-1.dll")>] extern void   vkDestroyImageView(nativeint device, nativeint imageView, nativeint pAllocator)
[<DllImport("vulkan-1.dll")>] extern int    vkCreateShaderModule(nativeint device, VkShaderModuleCreateInfo& pCreateInfo, nativeint pAllocator, nativeint& pShaderModule)
[<DllImport("vulkan-1.dll")>] extern void   vkDestroyShaderModule(nativeint device, nativeint shaderModule, nativeint pAllocator)
[<DllImport("vulkan-1.dll")>] extern int    vkCreateRenderPass(nativeint device, VkRenderPassCreateInfo& pCreateInfo, nativeint pAllocator, nativeint& pRenderPass)
[<DllImport("vulkan-1.dll")>] extern void   vkDestroyRenderPass(nativeint device, nativeint renderPass, nativeint pAllocator)
[<DllImport("vulkan-1.dll")>] extern int    vkCreatePipelineLayout(nativeint device, VkPipelineLayoutCreateInfo& pCreateInfo, nativeint pAllocator, nativeint& pPipelineLayout)
[<DllImport("vulkan-1.dll")>] extern void   vkDestroyPipelineLayout(nativeint device, nativeint pipelineLayout, nativeint pAllocator)
[<DllImport("vulkan-1.dll")>] extern int    vkCreateGraphicsPipelines(nativeint device, nativeint pipelineCache, uint32 createInfoCount, nativeint pCreateInfos, nativeint pAllocator, nativeint pPipelines)
[<DllImport("vulkan-1.dll")>] extern void   vkDestroyPipeline(nativeint device, nativeint pipeline, nativeint pAllocator)
[<DllImport("vulkan-1.dll")>] extern int    vkCreateFramebuffer(nativeint device, VkFramebufferCreateInfo& pCreateInfo, nativeint pAllocator, nativeint& pFramebuffer)
[<DllImport("vulkan-1.dll")>] extern void   vkDestroyFramebuffer(nativeint device, nativeint framebuffer, nativeint pAllocator)
[<DllImport("vulkan-1.dll")>] extern int    vkCreateCommandPool(nativeint device, VkCommandPoolCreateInfo& pCreateInfo, nativeint pAllocator, nativeint& pCommandPool)
[<DllImport("vulkan-1.dll")>] extern void   vkDestroyCommandPool(nativeint device, nativeint commandPool, nativeint pAllocator)
[<DllImport("vulkan-1.dll")>] extern int    vkAllocateCommandBuffers(nativeint device, VkCommandBufferAllocateInfo& pAllocateInfo, nativeint& pCommandBuffers)
[<DllImport("vulkan-1.dll")>] extern int    vkBeginCommandBuffer(nativeint commandBuffer, VkCommandBufferBeginInfo& pBeginInfo)
[<DllImport("vulkan-1.dll")>] extern int    vkEndCommandBuffer(nativeint commandBuffer)
[<DllImport("vulkan-1.dll")>] extern void   vkCmdBeginRenderPass(nativeint commandBuffer, VkRenderPassBeginInfo& pRenderPassBegin, int contents)
[<DllImport("vulkan-1.dll")>] extern void   vkCmdEndRenderPass(nativeint commandBuffer)
[<DllImport("vulkan-1.dll")>] extern void   vkCmdBindPipeline(nativeint commandBuffer, int pipelineBindPoint, nativeint pipeline)
[<DllImport("vulkan-1.dll")>] extern void   vkCmdDraw(nativeint commandBuffer, uint32 vertexCount, uint32 instanceCount, uint32 firstVertex, uint32 firstInstance)

/// Upload push constants directly to the command buffer.
/// stageFlags determines which shader stages read these constants.
/// offset and size describe the byte range being updated.
/// pValues points to the source data (must stay alive for the duration of the call).
[<DllImport("vulkan-1.dll")>]
extern void vkCmdPushConstants(nativeint commandBuffer, nativeint layout, uint32 stageFlags, uint32 offset, uint32 size, nativeint pValues)

[<DllImport("vulkan-1.dll")>] extern int    vkCreateSemaphore(nativeint device, VkSemaphoreCreateInfo& pCreateInfo, nativeint pAllocator, nativeint& pSemaphore)
[<DllImport("vulkan-1.dll")>] extern void   vkDestroySemaphore(nativeint device, nativeint semaphore, nativeint pAllocator)
[<DllImport("vulkan-1.dll")>] extern int    vkCreateFence(nativeint device, VkFenceCreateInfo& pCreateInfo, nativeint pAllocator, nativeint& pFence)
[<DllImport("vulkan-1.dll")>] extern void   vkDestroyFence(nativeint device, nativeint fence, nativeint pAllocator)
[<DllImport("vulkan-1.dll")>] extern int    vkWaitForFences(nativeint device, uint32 fenceCount, nativeint pFences, uint32 waitAll, uint64 timeout)
[<DllImport("vulkan-1.dll")>] extern int    vkResetFences(nativeint device, uint32 fenceCount, nativeint pFences)
[<DllImport("vulkan-1.dll")>] extern int    vkAcquireNextImageKHR(nativeint device, nativeint swapchain, uint64 timeout, nativeint semaphore, nativeint fence, uint32& pImageIndex)
[<DllImport("vulkan-1.dll")>] extern int    vkQueueSubmit(nativeint queue, uint32 submitCount, VkSubmitInfo& pSubmits, nativeint fence)
[<DllImport("vulkan-1.dll")>] extern int    vkQueuePresentKHR(nativeint queue, VkPresentInfoKHR& pPresentInfo)

// ========================================================================================================
// Ray Marching Form
// ========================================================================================================

type RayMarchForm() as this =
    inherit Form()
    
    // Vulkan handles
    let mutable vkInstance      = IntPtr.Zero
    let mutable vkPhysicalDevice = IntPtr.Zero
    let mutable vkDevice        = IntPtr.Zero
    let mutable graphicsQueue   = IntPtr.Zero
    let mutable presentQueue    = IntPtr.Zero
    let mutable graphicsQueueFamilyIndex = 0u
    let mutable presentQueueFamilyIndex  = 0u
    let mutable vkSurface       = IntPtr.Zero
    let mutable vkSwapChain     = IntPtr.Zero
    let mutable swapChainImageFormat = 0
    let mutable swapChainExtent = { VkExtent2D.width = 0u; height = 0u }
    let mutable swapChainImages: nativeint[] = [||]
    let mutable vkRenderPass    = IntPtr.Zero
    let mutable pipelineLayout  = IntPtr.Zero
    let mutable graphicsPipeline = IntPtr.Zero
    let mutable commandPool      = IntPtr.Zero
    // One command buffer per frame-in-flight to avoid overwriting a buffer still used by the GPU
    let mutable commandBuffers: nativeint[] = [||]
    let mutable vertShaderModule = IntPtr.Zero
    let mutable fragShaderModule = IntPtr.Zero
    let mutable swapChainImageViews  = [||]
    let mutable swapChainFramebuffers = [||]
    let mutable imageAvailableSemaphores = [||]
    let mutable renderFinishedSemaphores = [||]
    let mutable inFlightFences   = [||]
    let mutable frameIndex       = 0
    let mutable isDisposed       = false
    let MAX_FRAMES_IN_FLIGHT     = 2
    
    // Animation timer: measures elapsed seconds for iTime
    let startTime = DateTime.UtcNow
    let renderTimer = new Timer()

    do
        this.Text      <- "F# Vulkan 1.4 - Ray Marching"
        this.Size      <- Size(800, 600)
        this.BackColor <- Color.Black
        // Drive continuous rendering at ~60 fps via a Windows Forms timer
        renderTimer.Interval <- 16
        renderTimer.Tick.Add(fun _ -> this.Invalidate())
        renderTimer.Start()
    
    member private this.Log(msg: string) = printfn "[RayMarchForm] %s" msg
    
    member private this.MakeVersion(major: uint32, minor: uint32, patch: uint32) : uint32 =
        (major <<< 22) ||| (minor <<< 12) ||| patch
    
    /// Marshal a string array into a contiguous block of char* pointers.
    member private this.StringArrayToPtr(strings: string[]) : nativeint =
        let ptrs     = Array.map Marshal.StringToHGlobalAnsi strings
        let arrayPtr = Marshal.AllocHGlobal(nativeint ptrs.Length * nativeint IntPtr.Size)
        Marshal.Copy(ptrs, 0, arrayPtr, ptrs.Length)
        arrayPtr
    
    member private this.FreeStringArray(arrayPtr: nativeint, count: int) =
        let ptrs: nativeint[] = Array.zeroCreate count
        Marshal.Copy(arrayPtr, ptrs, 0, count)
        for ptr in ptrs do Marshal.FreeHGlobal(ptr)
        Marshal.FreeHGlobal(arrayPtr)
    
    // ---- Queue family discovery --------------------------------------------------
    member private this.FindQueueFamily() : uint32 =
        let mutable count = 0u
        vkGetPhysicalDeviceQueueFamilyProperties(vkPhysicalDevice, &count, IntPtr.Zero)
        let queueFamilies: VkQueueFamilyProperties[] = Array.zeroCreate (int count)
        let handle = GCHandle.Alloc(queueFamilies, GCHandleType.Pinned)
        try
            vkGetPhysicalDeviceQueueFamilyProperties(vkPhysicalDevice, &count, handle.AddrOfPinnedObject())
            let mutable found = None
            for i in 0u .. count - 1u do
                if found.IsNone && (queueFamilies.[int i].queueFlags &&& 0x1u) <> 0u then
                    let mutable presentSupport = 0u
                    vkGetPhysicalDeviceSurfaceSupportKHR(vkPhysicalDevice, i, vkSurface, &presentSupport) |> ignore
                    if presentSupport <> 0u then
                        graphicsQueueFamilyIndex <- i
                        presentQueueFamilyIndex  <- i
                        found <- Some i
            match found with
            | Some idx -> idx
            | None     -> failwith "No suitable queue family found!"
        finally handle.Free()
    
    // ---- Shader module ----------------------------------------------------------
    member private this.CreateShaderModule(code: byte[]) : IntPtr =
        let handle = GCHandle.Alloc(code, GCHandleType.Pinned)
        try
            let mutable ci: VkShaderModuleCreateInfo = {
                sType = int VkStructureType.VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO
                pNext = IntPtr.Zero; flags = 0u
                codeSize = nativeint code.Length
                pCode = handle.AddrOfPinnedObject()
            }
            let mutable sm = IntPtr.Zero
            if vkCreateShaderModule(vkDevice, &ci, IntPtr.Zero, &sm) <> 0 then IntPtr.Zero
            else sm
        finally handle.Free()
    
    // ---- Graphics pipeline (with push constants) --------------------------------
    member private this.CreateGraphicsPipeline() =
        this.Log("CreateGraphicsPipeline - Start")
        try
            // Load GLSL sources from project shader files and compile to SPIR-V
            let vertSrc  = File.ReadAllText("hello.vert")
            let fragSrc  = File.ReadAllText("hello.frag")
            let vertSpv  = ShaderCompiler.Compile vertSrc 0 "hello.vert"
            let fragSpv  = ShaderCompiler.Compile fragSrc 1 "hello.frag"
            
            vertShaderModule <- this.CreateShaderModule(vertSpv)
            fragShaderModule <- this.CreateShaderModule(fragSpv)
            
            // Push constant range covering all 16 bytes (iTime + padding + iResolution)
            // accessible from both vertex and fragment stages
            let mutable pushRange: VkPushConstantRange = {
                stageFlags = uint32 VkShaderStageFlags.VK_SHADER_STAGE_ALL_GRAPHICS
                offset = 0u
                size   = uint32 (Marshal.SizeOf(typeof<RayMarchPushConstants>))  // 16 bytes
            }
            
            let pushRangeHandle = GCHandle.Alloc(pushRange, GCHandleType.Pinned)
            let mutable layoutInfo: VkPipelineLayoutCreateInfo = {
                sType = int VkStructureType.VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO
                pNext = IntPtr.Zero; flags = 0u
                setLayoutCount = 0u; pSetLayouts = IntPtr.Zero
                pushConstantRangeCount = 1u  // One push constant range
                pPushConstantRanges = pushRangeHandle.AddrOfPinnedObject()
            }
            
            let mutable newLayout = IntPtr.Zero
            if vkCreatePipelineLayout(vkDevice, &layoutInfo, IntPtr.Zero, &newLayout) <> 0 then
                failwith "Failed to create pipeline layout!"
            pushRangeHandle.Free()
            pipelineLayout <- newLayout
            
            // Shader stages
            let vertNamePtr = Marshal.StringToHGlobalAnsi("main")
            let fragNamePtr = Marshal.StringToHGlobalAnsi("main")
            
            let mutable vertStage: VkPipelineShaderStageCreateInfo = {
                sType = int VkStructureType.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO
                pNext = IntPtr.Zero; flags = 0u
                stage = int VkShaderStageFlags.VK_SHADER_STAGE_VERTEX_BIT
                modul = vertShaderModule; pName = vertNamePtr; pSpecializationInfo = IntPtr.Zero
            }
            let mutable fragStage: VkPipelineShaderStageCreateInfo = {
                sType = int VkStructureType.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO
                pNext = IntPtr.Zero; flags = 0u
                stage = int VkShaderStageFlags.VK_SHADER_STAGE_FRAGMENT_BIT
                modul = fragShaderModule; pName = fragNamePtr; pSpecializationInfo = IntPtr.Zero
            }
            let shaderStages = [| vertStage; fragStage |]
            
            // No vertex buffers: positions are generated in the vertex shader
            let mutable vertexInput: VkPipelineVertexInputStateCreateInfo = {
                sType = int VkStructureType.VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO
                pNext = IntPtr.Zero; flags = 0u
                vertexBindingDescriptionCount = 0u; pVertexBindingDescriptions = IntPtr.Zero
                vertexAttributeDescriptionCount = 0u; pVertexAttributeDescriptions = IntPtr.Zero
            }
            
            // Full-screen triangle uses 3 vertices
            let mutable inputAssembly: VkPipelineInputAssemblyStateCreateInfo = {
                sType = int VkStructureType.VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO
                pNext = IntPtr.Zero; flags = 0u
                topology = int VkPrimitiveTopology.VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST
                primitiveRestartEnable = 0u
            }
            
            let mutable viewport: VkViewport = {
                x = 0.0f; y = 0.0f
                width = float32 swapChainExtent.width; height = float32 swapChainExtent.height
                minDepth = 0.0f; maxDepth = 1.0f
            }
            let mutable scissor: VkRect2D = {
                offset = { x = 0; y = 0 }; extent = swapChainExtent
            }
            let viewportHandle = GCHandle.Alloc(viewport, GCHandleType.Pinned)
            let scissorHandle  = GCHandle.Alloc(scissor,  GCHandleType.Pinned)
            
            let mutable viewportState: VkPipelineViewportStateCreateInfo = {
                sType = int VkStructureType.VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO
                pNext = IntPtr.Zero; flags = 0u
                viewportCount = 1u; pViewports = viewportHandle.AddrOfPinnedObject()
                scissorCount  = 1u; pScissors  = scissorHandle.AddrOfPinnedObject()
            }
            
            // No face culling needed for a full-screen triangle
            let mutable rasterizer: VkPipelineRasterizationStateCreateInfo = {
                sType = int VkStructureType.VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO
                pNext = IntPtr.Zero; flags = 0u
                depthClampEnable = 0u; rasterizerDiscardEnable = 0u
                polygonMode = int VkPolygonMode.VK_POLYGON_MODE_FILL
                cullMode = uint32 VkCullModeFlags.VK_CULL_MODE_NONE  // no culling for full-screen pass
                frontFace = int VkFrontFace.VK_FRONT_FACE_CLOCKWISE
                depthBiasEnable = 0u
                depthBiasConstantFactor = 0.0f; depthBiasClamp = 0.0f; depthBiasSlopeFactor = 0.0f
                lineWidth = 1.0f
            }
            
            let mutable multisample: VkPipelineMultisampleStateCreateInfo = {
                sType = int VkStructureType.VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO
                pNext = IntPtr.Zero; flags = 0u
                rasterizationSamples = int VkSampleCountFlags.VK_SAMPLE_COUNT_1_BIT
                sampleShadingEnable = 0u; minSampleShading = 1.0f; pSampleMask = IntPtr.Zero
                alphaToCoverageEnable = 0u; alphaToOneEnable = 0u
            }
            
            let mutable blendAttach: VkPipelineColorBlendAttachmentState = {
                blendEnable = 0u
                srcColorBlendFactor = int VkBlendFactor.VK_BLEND_FACTOR_ONE
                dstColorBlendFactor = int VkBlendFactor.VK_BLEND_FACTOR_ZERO
                colorBlendOp = int VkBlendOp.VK_BLEND_OP_ADD
                srcAlphaBlendFactor = int VkBlendFactor.VK_BLEND_FACTOR_ONE
                dstAlphaBlendFactor = int VkBlendFactor.VK_BLEND_FACTOR_ZERO
                alphaBlendOp = int VkBlendOp.VK_BLEND_OP_ADD
                colorWriteMask = 0x0Fu  // RGBA
            }
            let blendAttachHandle = GCHandle.Alloc(blendAttach, GCHandleType.Pinned)
            let blendConstants    = [| 0.0f; 0.0f; 0.0f; 0.0f |]
            let blendConstsHandle = GCHandle.Alloc(blendConstants, GCHandleType.Pinned)
            
            let mutable blending: VkPipelineColorBlendStateCreateInfo = {
                sType = int VkStructureType.VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO
                pNext = IntPtr.Zero; flags = 0u
                logicOpEnable = 0u; logicOp = 0
                attachmentCount = 1u; pAttachments = blendAttachHandle.AddrOfPinnedObject()
                blendConstants = blendConstsHandle.AddrOfPinnedObject()
            }
            
            let stagesHandle      = GCHandle.Alloc(shaderStages, GCHandleType.Pinned)
            let vertInputHandle   = GCHandle.Alloc(vertexInput,  GCHandleType.Pinned)
            let inputAsmHandle    = GCHandle.Alloc(inputAssembly, GCHandleType.Pinned)
            let viewStateHandle   = GCHandle.Alloc(viewportState, GCHandleType.Pinned)
            let rastHandle        = GCHandle.Alloc(rasterizer,    GCHandleType.Pinned)
            let msHandle          = GCHandle.Alloc(multisample,   GCHandleType.Pinned)
            let blendHandle       = GCHandle.Alloc(blending,      GCHandleType.Pinned)
            
            try
                let mutable pipelineCI: VkGraphicsPipelineCreateInfo = {
                    sType = int VkStructureType.VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO
                    pNext = IntPtr.Zero; flags = 0u
                    stageCount = 2u; pStages = stagesHandle.AddrOfPinnedObject()
                    pVertexInputState  = vertInputHandle.AddrOfPinnedObject()
                    pInputAssemblyState = inputAsmHandle.AddrOfPinnedObject()
                    pTessellationState = IntPtr.Zero
                    pViewportState     = viewStateHandle.AddrOfPinnedObject()
                    pRasterizationState = rastHandle.AddrOfPinnedObject()
                    pMultisampleState  = msHandle.AddrOfPinnedObject()
                    pDepthStencilState = IntPtr.Zero
                    pColorBlendState   = blendHandle.AddrOfPinnedObject()
                    pDynamicState = IntPtr.Zero
                    layout = pipelineLayout; renderPass = vkRenderPass
                    subpass = 0u; basePipelineHandle = IntPtr.Zero; basePipelineIndex = -1
                }
                let piHandle       = GCHandle.Alloc(pipelineCI, GCHandleType.Pinned)
                let pipelines      = [| IntPtr.Zero |]
                let pipelinesHandle = GCHandle.Alloc(pipelines, GCHandleType.Pinned)
                try
                    if vkCreateGraphicsPipelines(vkDevice, IntPtr.Zero, 1u, piHandle.AddrOfPinnedObject(), IntPtr.Zero, pipelinesHandle.AddrOfPinnedObject()) <> 0 then
                        failwith "Failed to create graphics pipeline!"
                    graphicsPipeline <- pipelines.[0]
                finally
                    piHandle.Free(); pipelinesHandle.Free()
            finally
                stagesHandle.Free(); vertInputHandle.Free(); inputAsmHandle.Free()
                viewStateHandle.Free(); rastHandle.Free(); msHandle.Free(); blendHandle.Free()
                blendAttachHandle.Free(); blendConstsHandle.Free()
                viewportHandle.Free(); scissorHandle.Free()
                Marshal.FreeHGlobal(vertNamePtr); Marshal.FreeHGlobal(fragNamePtr)
            
            this.Log("CreateGraphicsPipeline - End")
        with ex -> this.Log(sprintf "CreateGraphicsPipeline Error: %s" ex.Message)
    
    // ---- Render pass ------------------------------------------------------------
    member private this.CreateRenderPass() =
        let mutable colorAttachment: VkAttachmentDescription = {
            flags = 0u; format = swapChainImageFormat
            samples = int VkSampleCountFlags.VK_SAMPLE_COUNT_1_BIT
            loadOp = int VkAttachmentLoadOp.VK_ATTACHMENT_LOAD_OP_CLEAR
            storeOp = int VkAttachmentStoreOp.VK_ATTACHMENT_STORE_OP_STORE
            stencilLoadOp = int VkAttachmentLoadOp.VK_ATTACHMENT_LOAD_OP_DONT_CARE
            stencilStoreOp = int VkAttachmentStoreOp.VK_ATTACHMENT_STORE_OP_DONT_CARE
            initialLayout = int VkImageLayout.VK_IMAGE_LAYOUT_UNDEFINED
            finalLayout = int VkImageLayout.VK_IMAGE_LAYOUT_PRESENT_SRC_KHR
        }
        let mutable colorAttachRef: VkAttachmentReference = {
            attachment = 0u
            layout = int VkImageLayout.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL
        }
        let colorRefHandle = GCHandle.Alloc(colorAttachRef, GCHandleType.Pinned)
        let mutable subpass: VkSubpassDescription = {
            flags = 0u
            pipelineBindPoint = int VkPipelineBindPoint.VK_PIPELINE_BIND_POINT_GRAPHICS
            inputAttachmentCount = 0u; pInputAttachments = IntPtr.Zero
            colorAttachmentCount = 1u; pColorAttachments = colorRefHandle.AddrOfPinnedObject()
            pResolveAttachments = IntPtr.Zero; pDepthStencilAttachment = IntPtr.Zero
            preserveAttachmentCount = 0u; pPreserveAttachments = IntPtr.Zero
        }
        let mutable dependency: VkSubpassDependency = {
            srcSubpass = 0xFFFFFFFFu // VK_SUBPASS_EXTERNAL
            dstSubpass = 0u
            srcStageMask = uint32 (int VkPipelineStageFlags.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT)
            srcAccessMask = 0u
            dstStageMask = uint32 (int VkPipelineStageFlags.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT)
            dstAccessMask = 0x100u // VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT
            dependencyFlags = 0u
        }
        let attachments      = [| colorAttachment |]
        let attachHandle     = GCHandle.Alloc(attachments, GCHandleType.Pinned)
        let subpassHandle    = GCHandle.Alloc(subpass,     GCHandleType.Pinned)
        let dependencyHandle = GCHandle.Alloc(dependency,  GCHandleType.Pinned)
        try
            let mutable rpCI: VkRenderPassCreateInfo = {
                sType = int VkStructureType.VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO
                pNext = IntPtr.Zero; flags = 0u
                attachmentCount = uint32 attachments.Length; pAttachments = attachHandle.AddrOfPinnedObject()
                subpassCount = 1u; pSubpasses = subpassHandle.AddrOfPinnedObject()
                dependencyCount = 1u; pDependencies = dependencyHandle.AddrOfPinnedObject()
            }
            if vkCreateRenderPass(vkDevice, &rpCI, IntPtr.Zero, &vkRenderPass) <> 0 then
                failwith "Failed to create render pass!"
        finally
            colorRefHandle.Free(); attachHandle.Free(); subpassHandle.Free(); dependencyHandle.Free()
    
    // ---- Swap chain -------------------------------------------------------------
    member private this.CreateSwapChain() =
        let mutable caps = Unchecked.defaultof<VkSurfaceCapabilitiesKHR>
        vkGetPhysicalDeviceSurfaceCapabilitiesKHR(vkPhysicalDevice, vkSurface, &caps) |> ignore
        
        let mutable formatCount = 0u
        vkGetPhysicalDeviceSurfaceFormatsKHR(vkPhysicalDevice, vkSurface, &formatCount, IntPtr.Zero) |> ignore
        let formats: VkSurfaceFormatKHR[] = Array.zeroCreate (int formatCount)
        let fmtHandle = GCHandle.Alloc(formats, GCHandleType.Pinned)
        try vkGetPhysicalDeviceSurfaceFormatsKHR(vkPhysicalDevice, vkSurface, &formatCount, fmtHandle.AddrOfPinnedObject()) |> ignore
        finally fmtHandle.Free()
        
        swapChainImageFormat <- formats.[0].format
        swapChainExtent      <- caps.currentExtent
        
        let mutable imageCount = caps.minImageCount + 1u
        if caps.maxImageCount > 0u && imageCount > caps.maxImageCount then
            imageCount <- caps.maxImageCount
        
        let mutable ci: VkSwapchainCreateInfoKHR = {
            sType = uint32 (int VkStructureType.VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR)
            pNext = IntPtr.Zero; flags = 0u
            surface = vkSurface; minImageCount = imageCount
            imageFormat = swapChainImageFormat; imageColorSpace = formats.[0].colorSpace
            imageExtent = swapChainExtent; imageArrayLayers = 1u
            imageUsage = uint32 (int VkImageUsageFlags.VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT)
            imageSharingMode = int VkSharingMode.VK_SHARING_MODE_EXCLUSIVE
            queueFamilyIndexCount = 0u; pQueueFamilyIndices = IntPtr.Zero
            preTransform = caps.currentTransform
            compositeAlpha = uint32 (int VkCompositeAlphaFlagsKHR.VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR)
            presentMode = int VkPresentModeKHR.VK_PRESENT_MODE_FIFO_KHR
            clipped = 1u; oldSwapchain = IntPtr.Zero
        }
        if vkCreateSwapchainKHR(vkDevice, &ci, IntPtr.Zero, &vkSwapChain) <> 0 then
            failwith "Failed to create swap chain!"
        
        let mutable imgCount = 0u
        vkGetSwapchainImagesKHR(vkDevice, vkSwapChain, &imgCount, IntPtr.Zero) |> ignore
        swapChainImages <- Array.zeroCreate (int imgCount)
        let imgHandle = GCHandle.Alloc(swapChainImages, GCHandleType.Pinned)
        try vkGetSwapchainImagesKHR(vkDevice, vkSwapChain, &imgCount, imgHandle.AddrOfPinnedObject()) |> ignore
        finally imgHandle.Free()
    
    // ---- Image views ------------------------------------------------------------
    member private this.CreateSwapChainImageViews() =
        swapChainImageViews <- Array.zeroCreate swapChainImages.Length
        for i in 0 .. swapChainImages.Length - 1 do
            let mutable ci: VkImageViewCreateInfo = {
                sType = int VkStructureType.VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO
                pNext = IntPtr.Zero; flags = 0u
                image = swapChainImages.[i]
                viewType = int VkImageViewType.VK_IMAGE_VIEW_TYPE_2D
                format = swapChainImageFormat
                components = {
                    r = int VkComponentSwizzle.VK_COMPONENT_SWIZZLE_IDENTITY
                    g = int VkComponentSwizzle.VK_COMPONENT_SWIZZLE_IDENTITY
                    b = int VkComponentSwizzle.VK_COMPONENT_SWIZZLE_IDENTITY
                    a = int VkComponentSwizzle.VK_COMPONENT_SWIZZLE_IDENTITY
                }
                subresourceRange = {
                    aspectMask = uint32 (int VkImageAspectFlags.VK_IMAGE_ASPECT_COLOR_BIT)
                    baseMipLevel = 0u; levelCount = 1u; baseArrayLayer = 0u; layerCount = 1u
                }
            }
            if vkCreateImageView(vkDevice, &ci, IntPtr.Zero, &swapChainImageViews.[i]) <> 0 then
                failwith "Failed to create image view!"
    
    // ---- Framebuffers -----------------------------------------------------------
    member private this.CreateFramebuffers() =
        swapChainFramebuffers <- Array.zeroCreate swapChainImageViews.Length
        for i in 0 .. swapChainImageViews.Length - 1 do
            let attachments = [| swapChainImageViews.[i] |]
            let handle = GCHandle.Alloc(attachments, GCHandleType.Pinned)
            try
                let mutable fbCI: VkFramebufferCreateInfo = {
                    sType = int VkStructureType.VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO
                    pNext = IntPtr.Zero; flags = 0u
                    renderPass = vkRenderPass
                    attachmentCount = uint32 attachments.Length
                    pAttachments = handle.AddrOfPinnedObject()
                    width = swapChainExtent.width; height = swapChainExtent.height; layers = 1u
                }
                if vkCreateFramebuffer(vkDevice, &fbCI, IntPtr.Zero, &swapChainFramebuffers.[i]) <> 0 then
                    failwith "Failed to create framebuffer!"
            finally handle.Free()
    
    // ---- Command pool / buffer --------------------------------------------------
    member private this.CreateCommandPool() =
        let mutable poolCI: VkCommandPoolCreateInfo = {
            sType = int VkStructureType.VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO
            pNext = IntPtr.Zero
            flags = uint32 (int VkCommandPoolCreateFlags.VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT)
            queueFamilyIndex = graphicsQueueFamilyIndex
        }
        if vkCreateCommandPool(vkDevice, &poolCI, IntPtr.Zero, &commandPool) <> 0 then
            failwith "Failed to create command pool!"
    
    /// Allocate one command buffer per frame-in-flight.
    /// Each frame slot owns its own command buffer so that frame N+1 can record
    /// new commands while the GPU is still consuming frame N's buffer.
    member private this.CreateCommandBuffers() =
        commandBuffers <- Array.zeroCreate MAX_FRAMES_IN_FLIGHT
        for i in 0 .. MAX_FRAMES_IN_FLIGHT - 1 do
            let mutable allocInfo: VkCommandBufferAllocateInfo = {
                sType = int VkStructureType.VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO
                pNext = IntPtr.Zero
                commandPool = commandPool
                level = int VkCommandBufferLevel.VK_COMMAND_BUFFER_LEVEL_PRIMARY
                commandBufferCount = 1u
            }
            let mutable cb = IntPtr.Zero
            if vkAllocateCommandBuffers(vkDevice, &allocInfo, &cb) <> 0 then
                failwith (sprintf "Failed to allocate command buffer [%d]!" i)
            commandBuffers.[i] <- cb
    
    // ---- Synchronization primitives ---------------------------------------------
    member private this.CreateSyncObjects() =
        imageAvailableSemaphores <- Array.zeroCreate MAX_FRAMES_IN_FLIGHT
        renderFinishedSemaphores <- Array.zeroCreate MAX_FRAMES_IN_FLIGHT
        inFlightFences           <- Array.zeroCreate MAX_FRAMES_IN_FLIGHT
        
        let mutable semCI: VkSemaphoreCreateInfo = {
            sType = int VkStructureType.VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO
            pNext = IntPtr.Zero; flags = 0u
        }
        let mutable fenceCI: VkFenceCreateInfo = {
            sType = int VkStructureType.VK_STRUCTURE_TYPE_FENCE_CREATE_INFO
            pNext = IntPtr.Zero; flags = 1u  // VK_FENCE_CREATE_SIGNALED_BIT
        }
        for i in 0 .. MAX_FRAMES_IN_FLIGHT - 1 do
            vkCreateSemaphore(vkDevice, &semCI,   IntPtr.Zero, &imageAvailableSemaphores.[i]) |> ignore
            vkCreateSemaphore(vkDevice, &semCI,   IntPtr.Zero, &renderFinishedSemaphores.[i]) |> ignore
            vkCreateFence    (vkDevice, &fenceCI, IntPtr.Zero, &inFlightFences.[i])           |> ignore
    
    // ---- Logical device ---------------------------------------------------------
    member private this.CreateLogicalDevice() =
        let queueFamilyIndex = this.FindQueueFamily()
        let queuePriority    = 1.0f
        let priorityHandle   = GCHandle.Alloc(queuePriority, GCHandleType.Pinned)
        let mutable queueCI: VkDeviceQueueCreateInfo = {
            sType = uint32 VkStructureType.VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO
            pNext = IntPtr.Zero; flags = 0u
            queueFamilyIndex = queueFamilyIndex; queueCount = 1u
            pQueuePriorities = priorityHandle.AddrOfPinnedObject()
        }
        let queueCIHandle   = GCHandle.Alloc(queueCI, GCHandleType.Pinned)
        let extensions      = [| "VK_KHR_swapchain" |]
        let extensionsPtr   = this.StringArrayToPtr(extensions)
        try
            let mutable deviceCI: VkDeviceCreateInfo = {
                sType = uint32 VkStructureType.VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO
                pNext = IntPtr.Zero; flags = 0u
                queueCreateInfoCount = 1u; pQueueCreateInfos = queueCIHandle.AddrOfPinnedObject()
                enabledLayerCount = 0u; ppEnabledLayerNames = IntPtr.Zero
                enabledExtensionCount = uint32 extensions.Length; ppEnabledExtensionNames = extensionsPtr
                pEnabledFeatures = IntPtr.Zero
            }
            let mutable device = IntPtr.Zero
            if vkCreateDevice(vkPhysicalDevice, &deviceCI, IntPtr.Zero, &device) <> 0 then
                failwith "Failed to create logical device!"
            vkDevice <- device
            let mutable queue = IntPtr.Zero
            vkGetDeviceQueue(vkDevice, queueFamilyIndex, 0u, &queue)
            graphicsQueue <- queue
            presentQueue  <- queue
        finally
            queueCIHandle.Free(); priorityHandle.Free()
            this.FreeStringArray(extensionsPtr, extensions.Length)
    
    // ---- Physical device --------------------------------------------------------
    member private this.PickPhysicalDevice() =
        let mutable deviceCount = 0u
        vkEnumeratePhysicalDevices(vkInstance, &deviceCount, IntPtr.Zero) |> ignore
        if deviceCount = 0u then failwith "No Vulkan-capable GPUs found!"
        let devices: nativeint[] = Array.zeroCreate (int deviceCount)
        let handle = GCHandle.Alloc(devices, GCHandleType.Pinned)
        try
            vkEnumeratePhysicalDevices(vkInstance, &deviceCount, handle.AddrOfPinnedObject()) |> ignore
            vkPhysicalDevice <- devices.[0]
        finally handle.Free()
    
    // ---- Surface ----------------------------------------------------------------
    member private this.CreateSurface() =
        let mutable ci: VkWin32SurfaceCreateInfoKHR = {
            sType = uint32 VkStructureType.VK_STRUCTURE_TYPE_WIN32_SURFACE_CREATE_INFO_KHR
            pNext = IntPtr.Zero; flags = 0u
            hinstance = GetModuleHandle(null); hwnd = this.Handle
        }
        let ptr = vkGetInstanceProcAddr(vkInstance, "vkCreateWin32SurfaceKHR")
        if ptr = IntPtr.Zero then failwith "vkCreateWin32SurfaceKHR not found!"
        let fn = Marshal.GetDelegateForFunctionPointer<vkCreateWin32SurfaceKHRFunc>(ptr)
        let mutable surface = IntPtr.Zero
        if fn.Invoke(vkInstance, &ci, IntPtr.Zero, &surface) <> 0 then
            failwith "Failed to create Win32 surface!"
        vkSurface <- surface
    
    // ---- Instance ---------------------------------------------------------------
    member private this.CreateInstance() =
        let appInfo: VkApplicationInfo = {
            sType = uint32 VkStructureType.VK_STRUCTURE_TYPE_APPLICATION_INFO
            pNext = IntPtr.Zero
            pApplicationName = "Ray Marching (F#)"
            applicationVersion = this.MakeVersion(1u, 0u, 0u)
            pEngineName = "No Engine"
            engineVersion = this.MakeVersion(1u, 0u, 0u)
            apiVersion = this.MakeVersion(1u, 4u, 0u)  // Vulkan 1.4
        }
        let extensions   = [| "VK_KHR_surface"; "VK_KHR_win32_surface"; "VK_EXT_debug_utils" |]
        let extPtr       = this.StringArrayToPtr(extensions)
        let layers       = [| "VK_LAYER_KHRONOS_validation" |]
        let layersPtr    = this.StringArrayToPtr(layers)
        let appInfoPtr   = Marshal.AllocHGlobal(Marshal.SizeOf(typeof<VkApplicationInfo>))
        Marshal.StructureToPtr(appInfo, appInfoPtr, false)
        try
            let mutable ci: VkInstanceCreateInfo = {
                sType = uint32 VkStructureType.VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO
                pNext = IntPtr.Zero; flags = 0u
                pApplicationInfo = appInfoPtr
                enabledLayerCount = uint32 layers.Length; ppEnabledLayerNames = layersPtr
                enabledExtensionCount = uint32 extensions.Length; ppEnabledExtensionNames = extPtr
            }
            let mutable instance = IntPtr.Zero
            if vkCreateInstance(&ci, IntPtr.Zero, &instance) <> 0 then
                failwith "Failed to create Vulkan instance!"
            vkInstance <- instance
        finally
            Marshal.DestroyStructure(appInfoPtr, typeof<VkApplicationInfo>)
            Marshal.FreeHGlobal(appInfoPtr)
            this.FreeStringArray(extPtr,    extensions.Length)
            this.FreeStringArray(layersPtr, layers.Length)
    
    // ---- Full initialization sequence -------------------------------------------
    member private this.InitVulkan() =
        try
            this.CreateInstance()
            this.CreateSurface()
            this.PickPhysicalDevice()
            this.CreateLogicalDevice()
            this.CreateSwapChain()
            this.CreateSwapChainImageViews()
            this.CreateRenderPass()
            this.CreateGraphicsPipeline()
            this.CreateFramebuffers()
            this.CreateCommandPool()
            this.CreateCommandBuffers()   // allocate one buffer per frame-in-flight
            this.CreateSyncObjects()
            this.Log("InitVulkan complete")
        with ex -> this.Log(sprintf "InitVulkan Error: %s\n%s" ex.Message ex.StackTrace)
    
    // ---- Per-frame rendering ----------------------------------------------------
    member private this.DrawFrame() =
        try
            if commandBuffers.Length = 0 then ()
            else
                let currentFrame  = frameIndex % MAX_FRAMES_IN_FLIGHT
                // Select the command buffer that belongs to this frame slot.
                // Because we waited on inFlightFences.[currentFrame] above,
                // the GPU has finished reading this buffer and we can safely overwrite it.
                let commandBuffer = commandBuffers.[currentFrame]
                
                // Compute elapsed time for the animation
                let elapsedSeconds = float32 (DateTime.UtcNow - startTime).TotalSeconds
                
                // Wait for the previous use of this frame slot to finish
                let fenceArray  = [| inFlightFences.[currentFrame] |]
                let fenceHandle = GCHandle.Alloc(fenceArray, GCHandleType.Pinned)
                try
                    vkWaitForFences(vkDevice, 1u, fenceHandle.AddrOfPinnedObject(), 1u, UInt64.MaxValue) |> ignore
                    vkResetFences  (vkDevice, 1u, fenceHandle.AddrOfPinnedObject()) |> ignore
                finally fenceHandle.Free()
                
                let mutable imageIndex = 0u
                let acquireResult =
                    vkAcquireNextImageKHR(vkDevice, vkSwapChain, UInt64.MaxValue,
                                          imageAvailableSemaphores.[currentFrame],
                                          IntPtr.Zero, &imageIndex)
                
                if acquireResult <> int VkResult.VK_SUCCESS && acquireResult <> int VkResult.VK_SUBOPTIMAL_KHR then
                    this.Log(sprintf "vkAcquireNextImageKHR failed: %d" acquireResult)
                else
                    // Record command buffer
                    let mutable beginInfo: VkCommandBufferBeginInfo = {
                        sType = int VkStructureType.VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO
                        pNext = IntPtr.Zero
                        flags = uint32 (int VkCommandBufferUsageFlags.VK_COMMAND_BUFFER_USAGE_SIMULTANEOUS_USE_BIT)
                        pInheritanceInfo = IntPtr.Zero
                    }
                    if vkBeginCommandBuffer(commandBuffer, &beginInfo) <> 0 then
                        this.Log("vkBeginCommandBuffer failed")
                    else
                        let clearValues: VkClearValue[] = Array.zeroCreate 1
                        clearValues.[0].color <- { float32_0 = 0.0f; float32_1 = 0.0f; float32_2 = 0.0f; float32_3 = 1.0f }
                        let clearHandle = GCHandle.Alloc(clearValues, GCHandleType.Pinned)
                        try
                            let mutable rpBegin: VkRenderPassBeginInfo = {
                                sType = int VkStructureType.VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO
                                pNext = IntPtr.Zero
                                renderPass  = vkRenderPass
                                framebuffer = swapChainFramebuffers.[int imageIndex]
                                renderArea  = { offset = { x = 0; y = 0 }; extent = swapChainExtent }
                                clearValueCount = 1u; pClearValues = clearHandle.AddrOfPinnedObject()
                            }
                            
                            vkCmdBeginRenderPass(commandBuffer, &rpBegin, int VkSubpassContents.VK_SUBPASS_CONTENTS_INLINE)
                            vkCmdBindPipeline   (commandBuffer, int VkPipelineBindPoint.VK_PIPELINE_BIND_POINT_GRAPHICS, graphicsPipeline)
                            
                            // Build push constants with current time and window resolution
                            let mutable pc: RayMarchPushConstants = {
                                iTime        = elapsedSeconds
                                padding      = 0.0f
                                iResolutionX = float32 swapChainExtent.width
                                iResolutionY = float32 swapChainExtent.height
                            }
                            // Pin the struct and upload it to the command buffer
                            let pcHandle = GCHandle.Alloc(pc, GCHandleType.Pinned)
                            try
                                vkCmdPushConstants(
                                    commandBuffer,
                                    pipelineLayout,
                                    uint32 VkShaderStageFlags.VK_SHADER_STAGE_ALL_GRAPHICS,
                                    0u,                                                          // offset
                                    uint32 (Marshal.SizeOf(typeof<RayMarchPushConstants>)),      // 16 bytes
                                    pcHandle.AddrOfPinnedObject())
                            finally pcHandle.Free()
                            
                            // Draw full-screen triangle (3 vertices, no vertex buffer needed)
                            vkCmdDraw(commandBuffer, 3u, 1u, 0u, 0u)
                            vkCmdEndRenderPass(commandBuffer)
                            
                            if vkEndCommandBuffer(commandBuffer) <> 0 then
                                this.Log("vkEndCommandBuffer failed")
                            else
                                // Submit
                                let waitSems     = [| imageAvailableSemaphores.[currentFrame] |]
                                let waitSemsH    = GCHandle.Alloc(waitSems,     GCHandleType.Pinned)
                                let signalSems   = [| renderFinishedSemaphores.[currentFrame] |]
                                let signalSemsH  = GCHandle.Alloc(signalSems,   GCHandleType.Pinned)
                                let cmdBufs      = [| commandBuffer |]
                                let cmdBufsH     = GCHandle.Alloc(cmdBufs,      GCHandleType.Pinned)
                                let waitStages   = [| int VkPipelineStageFlags.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT |]
                                let waitStagesH  = GCHandle.Alloc(waitStages,   GCHandleType.Pinned)
                                try
                                    let mutable submitInfo: VkSubmitInfo = {
                                        sType = int VkStructureType.VK_STRUCTURE_TYPE_SUBMIT_INFO
                                        pNext = IntPtr.Zero
                                        waitSemaphoreCount   = 1u; pWaitSemaphores   = waitSemsH.AddrOfPinnedObject()
                                        pWaitDstStageMask    = waitStagesH.AddrOfPinnedObject()
                                        commandBufferCount   = 1u; pCommandBuffers    = cmdBufsH.AddrOfPinnedObject()
                                        signalSemaphoreCount = 1u; pSignalSemaphores  = signalSemsH.AddrOfPinnedObject()
                                    }
                                    if vkQueueSubmit(graphicsQueue, 1u, &submitInfo, inFlightFences.[currentFrame]) <> 0 then
                                        this.Log("vkQueueSubmit failed")
                                    else
                                        // Present
                                        let swapchains     = [| vkSwapChain |]
                                        let swapchainsH    = GCHandle.Alloc(swapchains,  GCHandleType.Pinned)
                                        let imageIndices   = [| imageIndex |]
                                        let imageIndicesH  = GCHandle.Alloc(imageIndices, GCHandleType.Pinned)
                                        let presentWaitS   = [| renderFinishedSemaphores.[currentFrame] |]
                                        let presentWaitSH  = GCHandle.Alloc(presentWaitS, GCHandleType.Pinned)
                                        try
                                            let mutable presentInfo: VkPresentInfoKHR = {
                                                sType = int VkStructureType.VK_STRUCTURE_TYPE_PRESENT_INFO_KHR
                                                pNext = IntPtr.Zero
                                                waitSemaphoreCount = 1u; pWaitSemaphores = presentWaitSH.AddrOfPinnedObject()
                                                swapchainCount = 1u; pSwapchains   = swapchainsH.AddrOfPinnedObject()
                                                pImageIndices = imageIndicesH.AddrOfPinnedObject()
                                                pResults = IntPtr.Zero
                                            }
                                            vkQueuePresentKHR(presentQueue, &presentInfo) |> ignore
                                        finally
                                            presentWaitSH.Free(); imageIndicesH.Free(); swapchainsH.Free()
                                finally
                                    waitSemsH.Free(); signalSemsH.Free(); cmdBufsH.Free(); waitStagesH.Free()
                        finally clearHandle.Free()
                
                frameIndex <- frameIndex + 1
        with ex -> this.Log(sprintf "DrawFrame Error: %s" ex.Message)
    
    // ---- Cleanup ----------------------------------------------------------------
    member private this.Cleanup() =
        if not isDisposed then
            isDisposed <- true
            renderTimer.Stop()
            renderTimer.Dispose()
            if vkDevice <> IntPtr.Zero then vkDeviceWaitIdle(vkDevice) |> ignore
            for f in inFlightFences           do if f <> IntPtr.Zero then vkDestroyFence    (vkDevice, f, IntPtr.Zero)
            for s in renderFinishedSemaphores do if s <> IntPtr.Zero then vkDestroySemaphore(vkDevice, s, IntPtr.Zero)
            for s in imageAvailableSemaphores do if s <> IntPtr.Zero then vkDestroySemaphore(vkDevice, s, IntPtr.Zero)
            if commandPool       <> IntPtr.Zero then vkDestroyCommandPool   (vkDevice, commandPool,       IntPtr.Zero)
            if fragShaderModule  <> IntPtr.Zero then vkDestroyShaderModule  (vkDevice, fragShaderModule,  IntPtr.Zero)
            if vertShaderModule  <> IntPtr.Zero then vkDestroyShaderModule  (vkDevice, vertShaderModule,  IntPtr.Zero)
            for fb in swapChainFramebuffers    do if fb <> IntPtr.Zero then vkDestroyFramebuffer (vkDevice, fb, IntPtr.Zero)
            if graphicsPipeline  <> IntPtr.Zero then vkDestroyPipeline      (vkDevice, graphicsPipeline,  IntPtr.Zero)
            if pipelineLayout    <> IntPtr.Zero then vkDestroyPipelineLayout(vkDevice, pipelineLayout,    IntPtr.Zero)
            if vkRenderPass      <> IntPtr.Zero then vkDestroyRenderPass    (vkDevice, vkRenderPass,      IntPtr.Zero)
            for v in swapChainImageViews       do if v <> IntPtr.Zero then vkDestroyImageView   (vkDevice, v,  IntPtr.Zero)
            if vkSwapChain       <> IntPtr.Zero then vkDestroySwapchainKHR  (vkDevice, vkSwapChain,       IntPtr.Zero)
            if vkDevice          <> IntPtr.Zero then vkDestroyDevice        (vkDevice,                     IntPtr.Zero)
            if vkSurface         <> IntPtr.Zero then vkDestroySurfaceKHR    (vkInstance, vkSurface,        IntPtr.Zero)
            if vkInstance        <> IntPtr.Zero then vkDestroyInstance      (vkInstance,                   IntPtr.Zero)
    
    // ---- Form overrides ---------------------------------------------------------
    override this.OnHandleCreated(e) =
        base.OnHandleCreated(e)
        this.InitVulkan()
    
    override this.OnPaint(e) =
        base.OnPaint(e)
        this.DrawFrame()
    
    override this.Dispose(disposing) =
        if disposing then this.Cleanup()
        base.Dispose(disposing)

// ========================================================================================================
// Entry point
// ========================================================================================================

[<EntryPoint>]
let main _ =
    Application.SetCompatibleTextRenderingDefault(false)
    Application.EnableVisualStyles()
    use form = new RayMarchForm()
    Application.Run(form)
    0
