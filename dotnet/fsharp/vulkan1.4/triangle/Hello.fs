open System
open System.Drawing
open System.Runtime.InteropServices
open System.Windows.Forms
open System.IO
open System.Text

// ========================================================================================================
// Shader Compiler Class (Using shaderc_shared.dll)
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

    let Compile (source: string) (kind: int) (fileName: string) : byte[] =
        let compiler = shaderc_compiler_initialize()
        let options = shaderc_compile_options_initialize()
        shaderc_compile_options_set_optimization_level(options, 2)
        
        try
            let sourceSize = unativeint (Encoding.UTF8.GetByteCount(source))
            let result = shaderc_compile_into_spv(compiler, source, sourceSize, kind, fileName, "main", options)
            
            try
                let status = shaderc_result_get_compilation_status(result)
                if status <> 0 then
                    let errorMsg = Marshal.PtrToStringAnsi(shaderc_result_get_error_message(result))
                    failwithf "Shader compilation failed: %s" errorMsg
                
                let length = int (shaderc_result_get_length(result))
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

type VkPhysicalDeviceType =
    | VK_PHYSICAL_DEVICE_TYPE_OTHER = 0
    | VK_PHYSICAL_DEVICE_TYPE_INTEGRATED_GPU = 1
    | VK_PHYSICAL_DEVICE_TYPE_DISCRETE_GPU = 2
    | VK_PHYSICAL_DEVICE_TYPE_VIRTUAL_GPU = 3
    | VK_PHYSICAL_DEVICE_TYPE_CPU = 4

type VkStructureType =
    | VK_STRUCTURE_TYPE_APPLICATION_INFO = 0u
    | VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO = 1u
    | VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO = 2u
    | VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO = 3u
    | VK_STRUCTURE_TYPE_SUBMIT_INFO = 4u
    | VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO = 15u
    | VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO = 16u
    | VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO = 18u
    | VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO = 19u
    | VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO = 20u
    | VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO = 22u
    | VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO = 23u
    | VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO = 24u
    | VK_STRUCTURE_TYPE_PIPELINE_DEPTH_STENCIL_STATE_CREATE_INFO = 25u
    | VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO = 26u
    | VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO = 28u
    | VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO = 30u
    | VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO = 37u
    | VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO = 38u
    | VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO = 39u
    | VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO = 40u
    | VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO = 42u
    | VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO = 43u
    | VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR = 1000001000u
    | VK_STRUCTURE_TYPE_PRESENT_INFO_KHR = 1000001001u
    | VK_STRUCTURE_TYPE_WIN32_SURFACE_CREATE_INFO_KHR = 1000009000u
    | VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO = 9u
    | VK_STRUCTURE_TYPE_FENCE_CREATE_INFO = 8u

type VkFormat =
    | VK_FORMAT_UNDEFINED = 0
    | VK_FORMAT_B8G8R8A8_SRGB = 50
    | VK_FORMAT_B8G8R8A8_UNORM = 44
    | VK_FORMAT_R8G8B8A8_SRGB = 43
    | VK_FORMAT_D32_SFLOAT = 126
    | VK_FORMAT_D32_SFLOAT_S8_UINT = 130
    | VK_FORMAT_D24_UNORM_S8_UINT = 129

type VkColorSpaceKHR =
    | VK_COLOR_SPACE_SRGB_NONLINEAR_KHR = 0

type VkPresentModeKHR =
    | VK_PRESENT_MODE_IMMEDIATE_KHR = 0
    | VK_PRESENT_MODE_MAILBOX_KHR = 1
    | VK_PRESENT_MODE_FIFO_KHR = 2
    | VK_PRESENT_MODE_FIFO_RELAXED_KHR = 3

type VkSharingMode =
    | VK_SHARING_MODE_EXCLUSIVE = 0
    | VK_SHARING_MODE_CONCURRENT = 1

type VkImageUsageFlags =
    | VK_IMAGE_USAGE_TRANSFER_SRC_BIT = 0x1u
    | VK_IMAGE_USAGE_TRANSFER_DST_BIT = 0x2u
    | VK_IMAGE_USAGE_SAMPLED_BIT = 0x4u
    | VK_IMAGE_USAGE_STORAGE_BIT = 0x8u
    | VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT = 0x10u
    | VK_IMAGE_USAGE_DEPTH_STENCIL_ATTACHMENT_BIT = 0x20u
    | VK_IMAGE_USAGE_TRANSIENT_ATTACHMENT_BIT = 0x40u
    | VK_IMAGE_USAGE_INPUT_ATTACHMENT_BIT = 0x80u

type VkCompositeAlphaFlagsKHR =
    | VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR = 0x1u
    | VK_COMPOSITE_ALPHA_PRE_MULTIPLIED_BIT_KHR = 0x2u
    | VK_COMPOSITE_ALPHA_POST_MULTIPLIED_BIT_KHR = 0x4u
    | VK_COMPOSITE_ALPHA_INHERIT_BIT_KHR = 0x8u

type VkImageViewType =
    | VK_IMAGE_VIEW_TYPE_1D = 0
    | VK_IMAGE_VIEW_TYPE_2D = 1
    | VK_IMAGE_VIEW_TYPE_3D = 2
    | VK_IMAGE_VIEW_TYPE_CUBE = 3
    | VK_IMAGE_VIEW_TYPE_1D_ARRAY = 4
    | VK_IMAGE_VIEW_TYPE_2D_ARRAY = 5
    | VK_IMAGE_VIEW_TYPE_CUBE_ARRAY = 6

type VkComponentSwizzle =
    | VK_COMPONENT_SWIZZLE_IDENTITY = 0
    | VK_COMPONENT_SWIZZLE_ZERO = 1
    | VK_COMPONENT_SWIZZLE_ONE = 2
    | VK_COMPONENT_SWIZZLE_R = 3
    | VK_COMPONENT_SWIZZLE_G = 4
    | VK_COMPONENT_SWIZZLE_B = 5
    | VK_COMPONENT_SWIZZLE_A = 6

type VkImageAspectFlags =
    | VK_IMAGE_ASPECT_COLOR_BIT = 0x1u
    | VK_IMAGE_ASPECT_DEPTH_BIT = 0x2u
    | VK_IMAGE_ASPECT_STENCIL_BIT = 0x4u
    | VK_IMAGE_ASPECT_METADATA_BIT = 0x8u

type VkShaderStageFlags =
    | VK_SHADER_STAGE_VERTEX_BIT = 0x1u
    | VK_SHADER_STAGE_TESSELLATION_CONTROL_BIT = 0x2u
    | VK_SHADER_STAGE_TESSELLATION_EVALUATION_BIT = 0x4u
    | VK_SHADER_STAGE_GEOMETRY_BIT = 0x8u
    | VK_SHADER_STAGE_FRAGMENT_BIT = 0x10u
    | VK_SHADER_STAGE_COMPUTE_BIT = 0x20u
    | VK_SHADER_STAGE_ALL_GRAPHICS = 0x1Fu
    | VK_SHADER_STAGE_ALL = 0x7FFFFFFFu

type VkPrimitiveTopology =
    | VK_PRIMITIVE_TOPOLOGY_POINT_LIST = 0
    | VK_PRIMITIVE_TOPOLOGY_LINE_LIST = 1
    | VK_PRIMITIVE_TOPOLOGY_LINE_STRIP = 2
    | VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST = 3
    | VK_PRIMITIVE_TOPOLOGY_TRIANGLE_STRIP = 4
    | VK_PRIMITIVE_TOPOLOGY_TRIANGLE_FAN = 5

type VkPolygonMode =
    | VK_POLYGON_MODE_FILL = 0
    | VK_POLYGON_MODE_LINE = 1
    | VK_POLYGON_MODE_POINT = 2

type VkCullModeFlags =
    | VK_CULL_MODE_NONE = 0u
    | VK_CULL_MODE_FRONT_BIT = 0x1u
    | VK_CULL_MODE_BACK_BIT = 0x2u
    | VK_CULL_MODE_FRONT_AND_BACK = 0x3u

type VkFrontFace =
    | VK_FRONT_FACE_COUNTER_CLOCKWISE = 0
    | VK_FRONT_FACE_CLOCKWISE = 1

type VkSampleCountFlags =
    | VK_SAMPLE_COUNT_1_BIT = 0x1u
    | VK_SAMPLE_COUNT_2_BIT = 0x2u
    | VK_SAMPLE_COUNT_4_BIT = 0x4u
    | VK_SAMPLE_COUNT_8_BIT = 0x8u
    | VK_SAMPLE_COUNT_16_BIT = 0x10u
    | VK_SAMPLE_COUNT_32_BIT = 0x20u
    | VK_SAMPLE_COUNT_64_BIT = 0x40u

type VkBlendFactor =
    | VK_BLEND_FACTOR_ZERO = 0
    | VK_BLEND_FACTOR_ONE = 1
    | VK_BLEND_FACTOR_SRC_COLOR = 2
    | VK_BLEND_FACTOR_ONE_MINUS_SRC_COLOR = 3
    | VK_BLEND_FACTOR_DST_COLOR = 4
    | VK_BLEND_FACTOR_ONE_MINUS_DST_COLOR = 5
    | VK_BLEND_FACTOR_SRC_ALPHA = 6
    | VK_BLEND_FACTOR_ONE_MINUS_SRC_ALPHA = 7
    | VK_BLEND_FACTOR_DST_ALPHA = 8
    | VK_BLEND_FACTOR_ONE_MINUS_DST_ALPHA = 9

type VkBlendOp =
    | VK_BLEND_OP_ADD = 0
    | VK_BLEND_OP_SUBTRACT = 1
    | VK_BLEND_OP_REVERSE_SUBTRACT = 2
    | VK_BLEND_OP_MIN = 3
    | VK_BLEND_OP_MAX = 4

type VkColorComponentFlags =
    | VK_COLOR_COMPONENT_R_BIT = 0x1u
    | VK_COLOR_COMPONENT_G_BIT = 0x2u
    | VK_COLOR_COMPONENT_B_BIT = 0x4u
    | VK_COLOR_COMPONENT_A_BIT = 0x8u

type VkAttachmentLoadOp =
    | VK_ATTACHMENT_LOAD_OP_LOAD = 0
    | VK_ATTACHMENT_LOAD_OP_CLEAR = 1
    | VK_ATTACHMENT_LOAD_OP_DONT_CARE = 2

type VkAttachmentStoreOp =
    | VK_ATTACHMENT_STORE_OP_STORE = 0
    | VK_ATTACHMENT_STORE_OP_DONT_CARE = 1

type VkImageLayout =
    | VK_IMAGE_LAYOUT_UNDEFINED = 0
    | VK_IMAGE_LAYOUT_GENERAL = 1
    | VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL = 2
    | VK_IMAGE_LAYOUT_DEPTH_STENCIL_ATTACHMENT_OPTIMAL = 3
    | VK_IMAGE_LAYOUT_DEPTH_STENCIL_READ_ONLY_OPTIMAL = 4
    | VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL = 5
    | VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL = 6
    | VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL = 7
    | VK_IMAGE_LAYOUT_PREINITIALIZED = 8
    | VK_IMAGE_LAYOUT_PRESENT_SRC_KHR = 1000001002

type VkPipelineBindPoint =
    | VK_PIPELINE_BIND_POINT_GRAPHICS = 0
    | VK_PIPELINE_BIND_POINT_COMPUTE = 1

type VkResult =
    | VK_SUCCESS = 0
    | VK_NOT_READY = 1
    | VK_TIMEOUT = 2
    | VK_EVENT_SET = 3
    | VK_EVENT_RESET = 4
    | VK_INCOMPLETE = 5
    | VK_ERROR_OUT_OF_HOST_MEMORY = -1
    | VK_ERROR_OUT_OF_DEVICE_MEMORY = -2
    | VK_ERROR_INITIALIZATION_FAILED = -3
    | VK_ERROR_DEVICE_LOST = -4
    | VK_ERROR_MEMORY_MAP_FAILED = -5
    | VK_ERROR_LAYER_NOT_PRESENT = -6
    | VK_ERROR_EXTENSION_NOT_PRESENT = -7
    | VK_ERROR_FEATURE_NOT_PRESENT = -8
    | VK_ERROR_INCOMPATIBLE_DRIVER = -9
    | VK_ERROR_TOO_MANY_OBJECTS = -10
    | VK_ERROR_FORMAT_NOT_SUPPORTED = -11
    | VK_ERROR_FRAGMENTED_POOL = -12
    | VK_ERROR_SURFACE_LOST_KHR = -1000000000
    | VK_SUBOPTIMAL_KHR = 1000001003
    | VK_ERROR_OUT_OF_DATE_KHR = -1000001004

type VkBool32 =
    | False = 0u
    | True = 1u

type VkCompareOp =
    | VK_COMPARE_OP_NEVER = 0
    | VK_COMPARE_OP_LESS = 1
    | VK_COMPARE_OP_EQUAL = 2
    | VK_COMPARE_OP_LESS_OR_EQUAL = 3
    | VK_COMPARE_OP_GREATER = 4
    | VK_COMPARE_OP_NOT_EQUAL = 5
    | VK_COMPARE_OP_GREATER_OR_EQUAL = 6
    | VK_COMPARE_OP_ALWAYS = 7

type VkStencilOp =
    | VK_STENCIL_OP_KEEP = 0
    | VK_STENCIL_OP_ZERO = 1
    | VK_STENCIL_OP_REPLACE = 2
    | VK_STENCIL_OP_INCREMENT_AND_CLAMP = 3
    | VK_STENCIL_OP_DECREMENT_AND_CLAMP = 4
    | VK_STENCIL_OP_INVERT = 5
    | VK_STENCIL_OP_INCREMENT_AND_WRAP = 6
    | VK_STENCIL_OP_DECREMENT_AND_WRAP = 7

type VkCommandPoolCreateFlags =
    | VK_COMMAND_POOL_CREATE_TRANSIENT_BIT = 0x1u
    | VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT = 0x2u
    | VK_COMMAND_POOL_CREATE_PROTECTED_BIT = 0x4u

type VkCommandBufferLevel =
    | VK_COMMAND_BUFFER_LEVEL_PRIMARY = 0
    | VK_COMMAND_BUFFER_LEVEL_SECONDARY = 1

type VkSubpassContents =
    | VK_SUBPASS_CONTENTS_INLINE = 0
    | VK_SUBPASS_CONTENTS_SECONDARY_COMMAND_BUFFERS = 1

type VkPipelineStageFlags =
    | VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT = 0x1u
    | VK_PIPELINE_STAGE_DRAW_INDIRECT_BIT = 0x2u
    | VK_PIPELINE_STAGE_VERTEX_INPUT_BIT = 0x4u
    | VK_PIPELINE_STAGE_VERTEX_SHADER_BIT = 0x8u
    | VK_PIPELINE_STAGE_FRAGMENT_SHADER_BIT = 0x80u
    | VK_PIPELINE_STAGE_EARLY_FRAGMENT_TESTS_BIT = 0x100u
    | VK_PIPELINE_STAGE_LATE_FRAGMENT_TESTS_BIT = 0x200u
    | VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT = 0x400u
    | VK_PIPELINE_STAGE_TRANSFER_BIT = 0x1000u
    | VK_PIPELINE_STAGE_BOTTOM_OF_PIPE_BIT = 0x2000u
    | VK_PIPELINE_STAGE_ALL_GRAPHICS_BIT = 0xFFFFu
    | VK_PIPELINE_STAGE_ALL_COMMANDS_BIT = 0x10000u

type VkCommandBufferUsageFlags =
    | VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT = 0x1u
    | VK_COMMAND_BUFFER_USAGE_RENDER_PASS_CONTINUE_BIT = 0x2u
    | VK_COMMAND_BUFFER_USAGE_SIMULTANEOUS_USE_BIT = 0x4u

// ========================================================================================================
// Vulkan Structures
// ========================================================================================================

[<Struct; StructLayout(LayoutKind.Sequential, CharSet = CharSet.Ansi)>]
type VkApplicationInfo = 
    {
        mutable sType: uint32
        mutable pNext: nativeint
        [<MarshalAs(UnmanagedType.LPStr)>]
        mutable pApplicationName: string
        mutable applicationVersion: uint32
        [<MarshalAs(UnmanagedType.LPStr)>]
        mutable pEngineName: string
        mutable engineVersion: uint32
        mutable apiVersion: uint32
    }

[<Struct; StructLayout(LayoutKind.Sequential)>]
type VkInstanceCreateInfo = 
    {
        mutable sType: uint32
        mutable pNext: nativeint
        mutable flags: uint32
        mutable pApplicationInfo: nativeint
        mutable enabledLayerCount: uint32
        mutable ppEnabledLayerNames: nativeint
        mutable enabledExtensionCount: uint32
        mutable ppEnabledExtensionNames: nativeint
    }

[<Struct; StructLayout(LayoutKind.Sequential)>]
type VkWin32SurfaceCreateInfoKHR = 
    {
        mutable sType: uint32
        mutable pNext: nativeint
        mutable flags: uint32
        mutable hinstance: nativeint
        mutable hwnd: nativeint
    }

[<Struct; StructLayout(LayoutKind.Sequential)>]
type VkQueueFamilyProperties = 
    {
        mutable queueFlags: uint32
        mutable queueCount: uint32
        mutable timestampValidBits: uint32
        mutable minImageTransferGranularity: VkExtent3D
    }

and [<Struct; StructLayout(LayoutKind.Sequential)>]
    VkExtent3D = 
    {
        mutable width: uint32
        mutable height: uint32
        mutable depth: uint32
    }

[<Struct; StructLayout(LayoutKind.Sequential)>]
type VkDeviceQueueCreateInfo = 
    {
        mutable sType: uint32
        mutable pNext: nativeint
        mutable flags: uint32
        mutable queueFamilyIndex: uint32
        mutable queueCount: uint32
        mutable pQueuePriorities: nativeint
    }

[<Struct; StructLayout(LayoutKind.Sequential)>]
type VkDeviceCreateInfo = 
    {
        mutable sType: uint32
        mutable pNext: nativeint
        mutable flags: uint32
        mutable queueCreateInfoCount: uint32
        mutable pQueueCreateInfos: nativeint
        mutable enabledLayerCount: uint32
        mutable ppEnabledLayerNames: nativeint
        mutable enabledExtensionCount: uint32
        mutable ppEnabledExtensionNames: nativeint
        mutable pEnabledFeatures: nativeint
    }

[<Struct; StructLayout(LayoutKind.Sequential)>]
type VkOffset2D = { mutable x: int; mutable y: int }

[<Struct; StructLayout(LayoutKind.Sequential)>]
type VkExtent2D = { mutable width: uint32; mutable height: uint32 }

[<Struct; StructLayout(LayoutKind.Sequential)>]
type VkSurfaceCapabilitiesKHR = 
    {
        mutable minImageCount: uint32
        mutable maxImageCount: uint32
        mutable currentExtent: VkExtent2D
        mutable minImageExtent: VkExtent2D
        mutable maxImageExtent: VkExtent2D
        mutable maxImageArrayLayers: uint32
        mutable supportedTransforms: uint32
        mutable currentTransform: uint32
        mutable supportedCompositeAlpha: uint32
        mutable supportedUsageFlags: uint32
    }

[<Struct; StructLayout(LayoutKind.Sequential)>]
type VkSurfaceFormatKHR = 
    {
        mutable format: int
        mutable colorSpace: int
    }

[<Struct; StructLayout(LayoutKind.Sequential)>]
type VkSwapchainCreateInfoKHR = 
    {
        mutable sType: uint32
        mutable pNext: nativeint
        mutable flags: uint32
        mutable surface: nativeint
        mutable minImageCount: uint32
        mutable imageFormat: int
        mutable imageColorSpace: int
        mutable imageExtent: VkExtent2D
        mutable imageArrayLayers: uint32
        mutable imageUsage: uint32
        mutable imageSharingMode: int
        mutable queueFamilyIndexCount: uint32
        mutable pQueueFamilyIndices: nativeint
        mutable preTransform: uint32
        mutable compositeAlpha: uint32
        mutable presentMode: int
        mutable clipped: uint32
        mutable oldSwapchain: nativeint
    }

[<Struct; StructLayout(LayoutKind.Sequential)>]
type VkAttachmentDescription = 
    {
        mutable flags: uint32
        mutable format: int
        mutable samples: int
        mutable loadOp: int
        mutable storeOp: int
        mutable stencilLoadOp: int
        mutable stencilStoreOp: int
        mutable initialLayout: int
        mutable finalLayout: int
    }

[<Struct; StructLayout(LayoutKind.Sequential)>]
type VkAttachmentReference = 
    {
        mutable attachment: uint32
        mutable layout: int
    }

[<Struct; StructLayout(LayoutKind.Sequential)>]
type VkComponentMapping = { mutable r: int; mutable g: int; mutable b: int; mutable a: int }

[<Struct; StructLayout(LayoutKind.Sequential)>]
type VkImageSubresourceRange = 
    {
        mutable aspectMask: uint32
        mutable baseMipLevel: uint32
        mutable levelCount: uint32
        mutable baseArrayLayer: uint32
        mutable layerCount: uint32
    }

[<Struct; StructLayout(LayoutKind.Sequential)>]
type VkSubpassDescription = 
    {
        mutable flags: uint32
        mutable pipelineBindPoint: int
        mutable inputAttachmentCount: uint32
        mutable pInputAttachments: nativeint
        mutable colorAttachmentCount: uint32
        mutable pColorAttachments: nativeint
        mutable pResolveAttachments: nativeint
        mutable pDepthStencilAttachment: nativeint
        mutable preserveAttachmentCount: uint32
        mutable pPreserveAttachments: nativeint
    }

[<Struct; StructLayout(LayoutKind.Sequential)>]
type VkSubpassDependency = 
    {
        mutable srcSubpass: uint32
        mutable dstSubpass: uint32
        mutable srcStageMask: uint32
        mutable dstStageMask: uint32
        mutable srcAccessMask: uint32
        mutable dstAccessMask: uint32
        mutable dependencyFlags: uint32
    }

[<Struct; StructLayout(LayoutKind.Sequential)>]
type VkRenderPassCreateInfo = 
    {
        mutable sType: int
        mutable pNext: nativeint
        mutable flags: uint32
        mutable attachmentCount: uint32
        mutable pAttachments: nativeint
        mutable subpassCount: uint32
        mutable pSubpasses: nativeint
        mutable dependencyCount: uint32
        mutable pDependencies: nativeint
    }

[<Struct; StructLayout(LayoutKind.Sequential)>]
type VkRect2D = { mutable offset: VkOffset2D; mutable extent: VkExtent2D }

[<Struct; StructLayout(LayoutKind.Sequential)>]
type VkImageViewCreateInfo = 
    {
        mutable sType: int
        mutable pNext: nativeint
        mutable flags: uint32
        mutable image: nativeint
        mutable viewType: int
        mutable format: int
        mutable components: VkComponentMapping
        mutable subresourceRange: VkImageSubresourceRange
    }

[<Struct; StructLayout(LayoutKind.Sequential)>]
type VkFramebufferCreateInfo = 
    {
        mutable sType: int
        mutable pNext: nativeint
        mutable flags: uint32
        mutable renderPass: nativeint
        mutable attachmentCount: uint32
        mutable pAttachments: nativeint
        mutable width: uint32
        mutable height: uint32
        mutable layers: uint32
    }

[<Struct; StructLayout(LayoutKind.Sequential)>]
type VkCommandPoolCreateInfo = 
    {
        mutable sType: int
        mutable pNext: nativeint
        mutable flags: uint32
        mutable queueFamilyIndex: uint32
    }

[<Struct; StructLayout(LayoutKind.Sequential)>]
type VkCommandBufferAllocateInfo = 
    {
        mutable sType: int
        mutable pNext: nativeint
        mutable commandPool: nativeint
        mutable level: int
        mutable commandBufferCount: uint32
    }

[<Struct; StructLayout(LayoutKind.Sequential)>]
type VkSemaphoreCreateInfo = 
    {
        mutable sType: int
        mutable pNext: nativeint
        mutable flags: uint32
    }

[<Struct; StructLayout(LayoutKind.Sequential)>]
type VkFenceCreateInfo = 
    {
        mutable sType: int
        mutable pNext: nativeint
        mutable flags: uint32
    }

[<Struct; StructLayout(LayoutKind.Sequential)>]
type VkCommandBufferBeginInfo = 
    {
        mutable sType: int
        mutable pNext: nativeint
        mutable flags: uint32
        mutable pInheritanceInfo: nativeint
    }

[<Struct; StructLayout(LayoutKind.Sequential)>]
type VkRenderPassBeginInfo = 
    {
        mutable sType: int
        mutable pNext: nativeint
        mutable renderPass: nativeint
        mutable framebuffer: nativeint
        mutable renderArea: VkRect2D
        mutable clearValueCount: uint32
        mutable pClearValues: nativeint
    }

[<Struct; StructLayout(LayoutKind.Sequential)>]
type VkSubmitInfo = 
    {
        mutable sType: int
        mutable pNext: nativeint
        mutable waitSemaphoreCount: uint32
        mutable pWaitSemaphores: nativeint
        mutable pWaitDstStageMask: nativeint
        mutable commandBufferCount: uint32
        mutable pCommandBuffers: nativeint
        mutable signalSemaphoreCount: uint32
        mutable pSignalSemaphores: nativeint
    }

[<Struct; StructLayout(LayoutKind.Sequential)>]
type VkPresentInfoKHR = 
    {
        mutable sType: int
        mutable pNext: nativeint
        mutable waitSemaphoreCount: uint32
        mutable pWaitSemaphores: nativeint
        mutable swapchainCount: uint32
        mutable pSwapchains: nativeint
        mutable pImageIndices: nativeint
        mutable pResults: nativeint
    }

[<Struct; StructLayout(LayoutKind.Sequential)>]
type VkViewport = 
    {
        mutable x: float32
        mutable y: float32
        mutable width: float32
        mutable height: float32
        mutable minDepth: float32
        mutable maxDepth: float32
    }

[<Struct; StructLayout(LayoutKind.Sequential)>]
type VkClearColorValue = 
    {
        mutable float32_0: float32
        mutable float32_1: float32
        mutable float32_2: float32
        mutable float32_3: float32
    }

[<Struct; StructLayout(LayoutKind.Sequential)>]
type VkClearDepthStencilValue = { mutable depth: float32; mutable stencil: uint32 }

[<Struct; StructLayout(LayoutKind.Explicit)>]
type VkClearValue = 
    {
        [<FieldOffset(0)>]
        mutable color: VkClearColorValue
        [<FieldOffset(0)>]
        mutable depthStencil: VkClearDepthStencilValue
    }

[<Struct; StructLayout(LayoutKind.Sequential)>]
type VkStencilOpState = 
    {
        mutable failOp: int
        mutable passOp: int
        mutable depthFailOp: int
        mutable compareOp: int
        mutable compareMask: uint32
        mutable writeMask: uint32
        mutable reference: uint32
    }

[<Struct; StructLayout(LayoutKind.Sequential)>]
type VkShaderModuleCreateInfo = 
    {
        mutable sType: int
        mutable pNext: nativeint
        mutable flags: uint32
        mutable codeSize: nativeint  // UIntPtr equivalent
        mutable pCode: nativeint
    }

[<Struct; StructLayout(LayoutKind.Sequential)>]
type VkPipelineLayoutCreateInfo = 
    {
        mutable sType: int
        mutable pNext: nativeint
        mutable flags: uint32
        mutable setLayoutCount: uint32
        mutable pSetLayouts: nativeint
        mutable pushConstantRangeCount: uint32
        mutable pPushConstantRanges: nativeint
    }

[<Struct; StructLayout(LayoutKind.Sequential)>]
type VkPipelineShaderStageCreateInfo = 
    {
        mutable sType: int
        mutable pNext: nativeint
        mutable flags: uint32
        mutable stage: int
        mutable modul: nativeint
        mutable pName: nativeint
        mutable pSpecializationInfo: nativeint
    }

[<Struct; StructLayout(LayoutKind.Sequential)>]
type VkPipelineVertexInputStateCreateInfo = 
    {
        mutable sType: int
        mutable pNext: nativeint
        mutable flags: uint32
        mutable vertexBindingDescriptionCount: uint32
        mutable pVertexBindingDescriptions: nativeint
        mutable vertexAttributeDescriptionCount: uint32
        mutable pVertexAttributeDescriptions: nativeint
    }

[<Struct; StructLayout(LayoutKind.Sequential)>]
type VkPipelineInputAssemblyStateCreateInfo = 
    {
        mutable sType: int
        mutable pNext: nativeint
        mutable flags: uint32
        mutable topology: int
        mutable primitiveRestartEnable: uint32
    }

[<Struct; StructLayout(LayoutKind.Sequential)>]
type VkPipelineViewportStateCreateInfo = 
    {
        mutable sType: int
        mutable pNext: nativeint
        mutable flags: uint32
        mutable viewportCount: uint32
        mutable pViewports: nativeint
        mutable scissorCount: uint32
        mutable pScissors: nativeint
    }

[<Struct; StructLayout(LayoutKind.Sequential)>]
type VkPipelineRasterizationStateCreateInfo = 
    {
        mutable sType: int
        mutable pNext: nativeint
        mutable flags: uint32
        mutable depthClampEnable: uint32
        mutable rasterizerDiscardEnable: uint32
        mutable polygonMode: int
        mutable cullMode: uint32
        mutable frontFace: int
        mutable depthBiasEnable: uint32
        mutable depthBiasConstantFactor: float32
        mutable depthBiasClamp: float32
        mutable depthBiasSlopeFactor: float32
        mutable lineWidth: float32
    }

[<Struct; StructLayout(LayoutKind.Sequential)>]
type VkPipelineMultisampleStateCreateInfo = 
    {
        mutable sType: int
        mutable pNext: nativeint
        mutable flags: uint32
        mutable rasterizationSamples: int
        mutable sampleShadingEnable: uint32
        mutable minSampleShading: float32
        mutable pSampleMask: nativeint
        mutable alphaToCoverageEnable: uint32
        mutable alphaToOneEnable: uint32
    }

[<Struct; StructLayout(LayoutKind.Sequential)>]
type VkPipelineColorBlendAttachmentState = 
    {
        mutable blendEnable: uint32
        mutable srcColorBlendFactor: int
        mutable dstColorBlendFactor: int
        mutable colorBlendOp: int
        mutable srcAlphaBlendFactor: int
        mutable dstAlphaBlendFactor: int
        mutable alphaBlendOp: int
        mutable colorWriteMask: uint32
    }

[<Struct; StructLayout(LayoutKind.Sequential)>]
type VkPipelineColorBlendStateCreateInfo = 
    {
        mutable sType: int
        mutable pNext: nativeint
        mutable flags: uint32
        mutable logicOpEnable: uint32
        mutable logicOp: int
        mutable attachmentCount: uint32
        mutable pAttachments: nativeint
        mutable blendConstants: nativeint
    }

[<Struct; StructLayout(LayoutKind.Sequential)>]
type VkGraphicsPipelineCreateInfo = 
    {
        mutable sType: int
        mutable pNext: nativeint
        mutable flags: uint32
        mutable stageCount: uint32
        mutable pStages: nativeint
        mutable pVertexInputState: nativeint
        mutable pInputAssemblyState: nativeint
        mutable pTessellationState: nativeint
        mutable pViewportState: nativeint
        mutable pRasterizationState: nativeint
        mutable pMultisampleState: nativeint
        mutable pDepthStencilState: nativeint
        mutable pColorBlendState: nativeint
        mutable pDynamicState: nativeint
        mutable layout: nativeint
        mutable renderPass: nativeint
        mutable subpass: uint32
        mutable basePipelineHandle: nativeint
        mutable basePipelineIndex: int
    }

// ========================================================================================================
// Vulkan P/Invoke
// ========================================================================================================

type vkCreateWin32SurfaceKHRFunc = delegate of nativeint * VkWin32SurfaceCreateInfoKHR byref * nativeint * nativeint byref -> int

[<DllImport("kernel32.dll", CharSet = CharSet.Auto)>]
extern IntPtr GetModuleHandle(string lpModuleName)

[<DllImport("vulkan-1.dll", CallingConvention = CallingConvention.StdCall)>]
extern int vkCreateInstance(VkInstanceCreateInfo& pCreateInfo, nativeint pAllocator, nativeint& pInstance)

[<DllImport("vulkan-1.dll", CallingConvention = CallingConvention.StdCall, CharSet = CharSet.Ansi)>]
extern nativeint vkGetInstanceProcAddr(nativeint instance, [<MarshalAs(UnmanagedType.LPStr)>] string pName)

[<DllImport("vulkan-1.dll")>]
extern void vkDestroyInstance(nativeint instance, nativeint pAllocator)

[<DllImport("vulkan-1.dll")>]
extern void vkDestroySurfaceKHR(nativeint instance, nativeint surface, nativeint pAllocator)

[<DllImport("vulkan-1.dll", CallingConvention = CallingConvention.StdCall)>]
extern int vkEnumeratePhysicalDevices(nativeint instance, uint32& pPhysicalDeviceCount, nativeint pPhysicalDevices)

[<DllImport("vulkan-1.dll", CallingConvention = CallingConvention.StdCall)>]
extern void vkGetPhysicalDeviceProperties(nativeint physicalDevice, nativeint pProperties)

[<DllImport("vulkan-1.dll", CallingConvention = CallingConvention.StdCall)>]
extern void vkGetPhysicalDeviceQueueFamilyProperties(nativeint physicalDevice, uint32& pQueueFamilyPropertyCount, nativeint pQueueFamilyProperties)

[<DllImport("vulkan-1.dll", CallingConvention = CallingConvention.StdCall)>]
extern int vkGetPhysicalDeviceSurfaceSupportKHR(nativeint physicalDevice, uint32 queueFamilyIndex, nativeint surface, uint32& pSupported)

[<DllImport("vulkan-1.dll", CallingConvention = CallingConvention.StdCall)>]
extern int vkCreateDevice(nativeint physicalDevice, VkDeviceCreateInfo& pCreateInfo, nativeint pAllocator, nativeint& pDevice)

[<DllImport("vulkan-1.dll")>]
extern void vkGetDeviceQueue(nativeint device, uint32 queueFamilyIndex, uint32 queueIndex, nativeint& pQueue)

[<DllImport("vulkan-1.dll", CallingConvention = CallingConvention.StdCall)>]
extern int vkDeviceWaitIdle(nativeint device)

[<DllImport("vulkan-1.dll")>]
extern void vkDestroyDevice(nativeint device, nativeint pAllocator)

[<DllImport("vulkan-1.dll", CallingConvention = CallingConvention.StdCall)>]
extern int vkGetPhysicalDeviceSurfaceCapabilitiesKHR(nativeint physicalDevice, nativeint surface, VkSurfaceCapabilitiesKHR& pSurfaceCapabilities)

[<DllImport("vulkan-1.dll", CallingConvention = CallingConvention.StdCall)>]
extern int vkGetPhysicalDeviceSurfaceFormatsKHR(nativeint physicalDevice, nativeint surface, uint32& pSurfaceFormatCount, nativeint pSurfaceFormats)

[<DllImport("vulkan-1.dll", CallingConvention = CallingConvention.StdCall)>]
extern int vkGetPhysicalDeviceSurfacePresentModesKHR(nativeint physicalDevice, nativeint surface, uint32& pPresentModeCount, nativeint pPresentModes)

[<DllImport("vulkan-1.dll", CallingConvention = CallingConvention.StdCall)>]
extern int vkCreateSwapchainKHR(nativeint device, VkSwapchainCreateInfoKHR& pCreateInfo, nativeint pAllocator, nativeint& pSwapchain)

[<DllImport("vulkan-1.dll", CallingConvention = CallingConvention.StdCall)>]
extern void vkDestroySwapchainKHR(nativeint device, nativeint swapchain, nativeint pAllocator)

[<DllImport("vulkan-1.dll", CallingConvention = CallingConvention.StdCall)>]
extern int vkGetSwapchainImagesKHR(nativeint device, nativeint swapchain, uint32& pSwapchainImageCount, nativeint pSwapchainImages)

[<DllImport("vulkan-1.dll")>]
extern int vkCreateImageView(nativeint device, VkImageViewCreateInfo& pCreateInfo, nativeint pAllocator, nativeint& pView)

[<DllImport("vulkan-1.dll")>]
extern void vkDestroyImageView(nativeint device, nativeint imageView, nativeint pAllocator)

[<DllImport("vulkan-1.dll", CallingConvention = CallingConvention.StdCall)>]
extern int vkCreateShaderModule(nativeint device, VkShaderModuleCreateInfo& pCreateInfo, nativeint pAllocator, nativeint& pShaderModule)

[<DllImport("vulkan-1.dll")>]
extern void vkDestroyShaderModule(nativeint device, nativeint shaderModule, nativeint pAllocator)

[<DllImport("vulkan-1.dll", CallingConvention = CallingConvention.StdCall)>]
extern int vkCreateRenderPass(nativeint device, VkRenderPassCreateInfo& pCreateInfo, nativeint pAllocator, nativeint& pRenderPass)

[<DllImport("vulkan-1.dll")>]
extern void vkDestroyRenderPass(nativeint device, nativeint renderPass, nativeint pAllocator)

[<DllImport("vulkan-1.dll")>]
extern int vkCreatePipelineLayout(nativeint device, VkPipelineLayoutCreateInfo& pCreateInfo, nativeint pAllocator, nativeint& pPipelineLayout)

[<DllImport("vulkan-1.dll")>]
extern void vkDestroyPipelineLayout(nativeint device, nativeint pipelineLayout, nativeint pAllocator)

[<DllImport("vulkan-1.dll")>]
extern int vkCreateGraphicsPipelines(nativeint device, nativeint pipelineCache, uint32 createInfoCount, nativeint pCreateInfos, nativeint pAllocator, nativeint pPipelines)

[<DllImport("vulkan-1.dll")>]
extern void vkDestroyPipeline(nativeint device, nativeint pipeline, nativeint pAllocator)

[<DllImport("vulkan-1.dll")>]
extern int vkCreateFramebuffer(nativeint device, VkFramebufferCreateInfo& pCreateInfo, nativeint pAllocator, nativeint& pFramebuffer)

[<DllImport("vulkan-1.dll")>]
extern void vkDestroyFramebuffer(nativeint device, nativeint framebuffer, nativeint pAllocator)

[<DllImport("vulkan-1.dll")>]
extern int vkCreateCommandPool(nativeint device, VkCommandPoolCreateInfo& pCreateInfo, nativeint pAllocator, nativeint& pCommandPool)

[<DllImport("vulkan-1.dll")>]
extern void vkDestroyCommandPool(nativeint device, nativeint commandPool, nativeint pAllocator)

[<DllImport("vulkan-1.dll")>]
extern int vkAllocateCommandBuffers(nativeint device, VkCommandBufferAllocateInfo& pAllocateInfo, nativeint& pCommandBuffers)

[<DllImport("vulkan-1.dll")>]
extern int vkEndCommandBuffer(nativeint commandBuffer)

[<DllImport("vulkan-1.dll")>]
extern void vkCmdEndRenderPass(nativeint commandBuffer)

[<DllImport("vulkan-1.dll")>]
extern void vkCmdBindPipeline(nativeint commandBuffer, int pipelineBindPoint, nativeint pipeline)

[<DllImport("vulkan-1.dll")>]
extern void vkCmdDraw(nativeint commandBuffer, uint32 vertexCount, uint32 instanceCount, uint32 firstVertex, uint32 firstInstance)

[<DllImport("vulkan-1.dll", CallingConvention = CallingConvention.StdCall)>]
extern int vkCreateSemaphore(nativeint device, VkSemaphoreCreateInfo& pCreateInfo, nativeint pAllocator, nativeint& pSemaphore)

[<DllImport("vulkan-1.dll", CallingConvention = CallingConvention.StdCall)>]
extern void vkDestroySemaphore(nativeint device, nativeint semaphore, nativeint pAllocator)

[<DllImport("vulkan-1.dll", CallingConvention = CallingConvention.StdCall)>]
extern int vkCreateFence(nativeint device, VkFenceCreateInfo& pCreateInfo, nativeint pAllocator, nativeint& pFence)

[<DllImport("vulkan-1.dll")>]
extern void vkDestroyFence(nativeint device, nativeint fence, nativeint pAllocator)

[<DllImport("vulkan-1.dll", CallingConvention = CallingConvention.StdCall)>]
extern int vkWaitForFences(nativeint device, uint32 fenceCount, nativeint pFences, uint32 waitAll, uint64 timeout)

[<DllImport("vulkan-1.dll", CallingConvention = CallingConvention.StdCall)>]
extern int vkResetFences(nativeint device, uint32 fenceCount, nativeint pFences)

[<DllImport("vulkan-1.dll", CallingConvention = CallingConvention.StdCall)>]
extern int vkAcquireNextImageKHR(nativeint device, nativeint swapchain, uint64 timeout, nativeint semaphore, nativeint fence, uint32& pImageIndex)

[<DllImport("vulkan-1.dll", CallingConvention = CallingConvention.StdCall)>]
extern int vkBeginCommandBuffer(nativeint commandBuffer, VkCommandBufferBeginInfo& pBeginInfo)

[<DllImport("vulkan-1.dll")>]
extern void vkCmdBeginRenderPass(nativeint commandBuffer, VkRenderPassBeginInfo& pRenderPassBegin, int contents)

[<DllImport("vulkan-1.dll")>]
extern int vkQueueSubmit(nativeint queue, uint32 submitCount, VkSubmitInfo& pSubmits, nativeint fence)

[<DllImport("vulkan-1.dll")>]
extern int vkQueuePresentKHR(nativeint queue, VkPresentInfoKHR& pPresentInfo)

// ========================================================================================================
// Main Application
// ========================================================================================================

type HelloForm() as this =
    inherit Form()
    
    let mutable vkInstance = IntPtr.Zero
    let mutable vkPhysicalDevice = IntPtr.Zero
    let mutable vkDevice = IntPtr.Zero
    let mutable graphicsQueue = IntPtr.Zero
    let mutable presentQueue = IntPtr.Zero
    let mutable graphicsQueueFamilyIndex = 0u
    let mutable presentQueueFamilyIndex = 0u
    let mutable vkSurface = IntPtr.Zero
    let mutable vkSwapChain = IntPtr.Zero
    let mutable swapChainImageFormat = 0
    let mutable swapChainExtent = { VkExtent2D.width = 0u; height = 0u }
    let mutable swapChainImages: nativeint[] = [||]
    let mutable vkRenderPass = IntPtr.Zero
    let mutable pipelineLayout = IntPtr.Zero
    let mutable graphicsPipeline = IntPtr.Zero
    let mutable commandPool = IntPtr.Zero
    let mutable commandBuffer = IntPtr.Zero
    let mutable vertShaderModule = IntPtr.Zero
    let mutable fragShaderModule = IntPtr.Zero
    let mutable swapChainImageViews = [||]
    let mutable swapChainFramebuffers = [||]
    let mutable imageAvailableSemaphores = [||]
    let mutable renderFinishedSemaphores = [||]
    let mutable inFlightFences = [||]
    let mutable frameIndex = 0
    let MAX_FRAMES_IN_FLIGHT = 2
    let mutable isDisposed = false
    
    do
        this.Text <- "F# Vulkan 1.4 Triangle"
        this.Size <- Size(800, 600)
        this.BackColor <- Color.Black
    
    member private this.PrintLog(msg: string) =
        printfn "[HelloForm] %s" msg
    
    member private this.MakeVersion(major: uint32, minor: uint32, patch: uint32) : uint32 =
        (major <<< 22) ||| (minor <<< 12) ||| patch
    
    member private this.StringArrayToPtr(strings: string[]) : nativeint =
        let ptrs = Array.map Marshal.StringToHGlobalAnsi strings
        let arrayPtr = Marshal.AllocHGlobal(nativeint ptrs.Length * nativeint IntPtr.Size)
        Marshal.Copy(ptrs, 0, arrayPtr, ptrs.Length)
        arrayPtr
    
    member private this.FreeStringArray(arrayPtr: nativeint, count: int) =
        let ptrs: nativeint[] = Array.zeroCreate count
        Marshal.Copy(arrayPtr, ptrs, 0, count)
        for ptr in ptrs do
            Marshal.FreeHGlobal(ptr)
        Marshal.FreeHGlobal(arrayPtr)
    
    member private this.FindQueueFamily() : uint32 =
        let mutable queueFamilyCount = 0u
        vkGetPhysicalDeviceQueueFamilyProperties(vkPhysicalDevice, &queueFamilyCount, IntPtr.Zero)
        
        let queueFamilies: VkQueueFamilyProperties[] = Array.zeroCreate (int queueFamilyCount)
        let queueFamiliesHandle = GCHandle.Alloc(queueFamilies, GCHandleType.Pinned)
        
        try
            vkGetPhysicalDeviceQueueFamilyProperties(vkPhysicalDevice, &queueFamilyCount, queueFamiliesHandle.AddrOfPinnedObject())
            
            let mutable foundIndex = None
            for i in 0u .. queueFamilyCount - 1u do
                if foundIndex.IsNone then
                    // Check for graphics bit (0x1)
                    if (queueFamilies.[int i].queueFlags &&& 0x1u) <> 0u then
                        let mutable presentSupport = 0u
                        vkGetPhysicalDeviceSurfaceSupportKHR(vkPhysicalDevice, i, vkSurface, &presentSupport) |> ignore
                        if presentSupport <> 0u then
                            graphicsQueueFamilyIndex <- i
                            presentQueueFamilyIndex <- i
                            foundIndex <- Some i
            
            match foundIndex with
            | Some index -> index
            | None -> failwith "Failed to find suitable queue family!"
        finally
            queueFamiliesHandle.Free()
    member private this.CreateShaderModule(code: byte[]) : IntPtr =
        this.PrintLog("CreateShaderModule - Start")
        
        try
            // Pin the code array directly in managed memory (like VB.NET does)
            let codeHandle = GCHandle.Alloc(code, GCHandleType.Pinned)
            
            try
                let mutable createInfo: VkShaderModuleCreateInfo = {
                    sType = int VkStructureType.VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO
                    pNext = IntPtr.Zero
                    flags = 0u
                    codeSize = nativeint code.Length
                    pCode = codeHandle.AddrOfPinnedObject()
                }
                
                let mutable shaderModule = IntPtr.Zero
                let result = vkCreateShaderModule(vkDevice, &createInfo, IntPtr.Zero, &shaderModule)
                
                if result <> int VkResult.VK_SUCCESS then
                    this.PrintLog(sprintf "ERROR: vkCreateShaderModule failed with result: %d" result)
                    IntPtr.Zero
                else
                    shaderModule
            finally
                codeHandle.Free()
        with
        | ex ->
            this.PrintLog(sprintf "CreateShaderModule Error: %s" ex.Message)
            IntPtr.Zero
    
    member private this.CreateGraphicsPipeline() =
        this.PrintLog("CreateGraphicsPipeline - Start")
        
        try
            let vertShaderCode = File.ReadAllText("hello.vert")
            let fragShaderCode = File.ReadAllText("hello.frag")
            
            let vertSpirv = ShaderCompiler.Compile vertShaderCode 0 "hello.vert"
            let fragSpirv = ShaderCompiler.Compile fragShaderCode 1 "hello.frag"
            
            vertShaderModule <- this.CreateShaderModule(vertSpirv)
            fragShaderModule <- this.CreateShaderModule(fragSpirv)
            
            // Create pipeline layout
            let mutable pipelineLayoutInfo: VkPipelineLayoutCreateInfo = {
                sType = int VkStructureType.VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO
                pNext = IntPtr.Zero
                flags = 0u
                setLayoutCount = 0u
                pSetLayouts = IntPtr.Zero
                pushConstantRangeCount = 0u
                pPushConstantRanges = IntPtr.Zero
            }
            
            let mutable newPipelineLayout = IntPtr.Zero
            if vkCreatePipelineLayout(vkDevice, &pipelineLayoutInfo, IntPtr.Zero, &newPipelineLayout) <> int VkResult.VK_SUCCESS then
                failwith "Failed to create pipeline layout!"
            
            // Assign to member variable
            pipelineLayout <- newPipelineLayout
            
            // Create shader stages
            let vertShaderNamePtr = Marshal.StringToHGlobalAnsi("main")
            let fragShaderNamePtr = Marshal.StringToHGlobalAnsi("main")
            
            let mutable vertShaderStageInfo: VkPipelineShaderStageCreateInfo = {
                sType = int VkStructureType.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO
                pNext = IntPtr.Zero
                flags = 0u
                stage = int VkShaderStageFlags.VK_SHADER_STAGE_VERTEX_BIT
                modul = vertShaderModule
                pName = vertShaderNamePtr
                pSpecializationInfo = IntPtr.Zero
            }
            
            let mutable fragShaderStageInfo: VkPipelineShaderStageCreateInfo = {
                sType = int VkStructureType.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO
                pNext = IntPtr.Zero
                flags = 0u
                stage = int VkShaderStageFlags.VK_SHADER_STAGE_FRAGMENT_BIT
                modul = fragShaderModule
                pName = fragShaderNamePtr
                pSpecializationInfo = IntPtr.Zero
            }
            
            let shaderStages = [| vertShaderStageInfo; fragShaderStageInfo |]
            
            // Vertex input state
            let mutable vertexInputInfo: VkPipelineVertexInputStateCreateInfo = {
                sType = int VkStructureType.VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO
                pNext = IntPtr.Zero
                flags = 0u
                vertexBindingDescriptionCount = 0u
                pVertexBindingDescriptions = IntPtr.Zero
                vertexAttributeDescriptionCount = 0u
                pVertexAttributeDescriptions = IntPtr.Zero
            }
            
            // Input assembly
            let mutable inputAssembly: VkPipelineInputAssemblyStateCreateInfo = {
                sType = int VkStructureType.VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO
                pNext = IntPtr.Zero
                flags = 0u
                topology = int VkPrimitiveTopology.VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST
                primitiveRestartEnable = 0u
            }
            
            // Viewport and scissors
            let mutable viewport: VkViewport = {
                x = 0.0f
                y = 0.0f
                width = float32 swapChainExtent.width
                height = float32 swapChainExtent.height
                minDepth = 0.0f
                maxDepth = 1.0f
            }
            
            let mutable scissor: VkRect2D = {
                offset = { x = 0; y = 0 }
                extent = swapChainExtent
            }
            
            let viewportHandle = GCHandle.Alloc(viewport, GCHandleType.Pinned)
            let scissorHandle = GCHandle.Alloc(scissor, GCHandleType.Pinned)
            
            let mutable viewportState: VkPipelineViewportStateCreateInfo = {
                sType = int VkStructureType.VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO
                pNext = IntPtr.Zero
                flags = 0u
                viewportCount = 1u
                pViewports = viewportHandle.AddrOfPinnedObject()
                scissorCount = 1u
                pScissors = scissorHandle.AddrOfPinnedObject()
            }
            
            // Rasterizer
            let mutable rasterizer: VkPipelineRasterizationStateCreateInfo = {
                sType = int VkStructureType.VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO
                pNext = IntPtr.Zero
                flags = 0u
                depthClampEnable = 0u
                rasterizerDiscardEnable = 0u
                polygonMode = int VkPolygonMode.VK_POLYGON_MODE_FILL
                lineWidth = 1.0f
                cullMode = uint32 (int VkCullModeFlags.VK_CULL_MODE_BACK_BIT)
                frontFace = int VkFrontFace.VK_FRONT_FACE_CLOCKWISE
                depthBiasEnable = 0u
                depthBiasConstantFactor = 0.0f
                depthBiasClamp = 0.0f
                depthBiasSlopeFactor = 0.0f
            }
            
            // Multisampling
            let mutable multisampling: VkPipelineMultisampleStateCreateInfo = {
                sType = int VkStructureType.VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO
                pNext = IntPtr.Zero
                flags = 0u
                rasterizationSamples = int VkSampleCountFlags.VK_SAMPLE_COUNT_1_BIT
                sampleShadingEnable = 0u
                minSampleShading = 1.0f
                pSampleMask = IntPtr.Zero
                alphaToCoverageEnable = 0u
                alphaToOneEnable = 0u
            }
            
            // Color blend
            let mutable colorBlendAttachment: VkPipelineColorBlendAttachmentState = {
                blendEnable = 0u
                srcColorBlendFactor = int VkBlendFactor.VK_BLEND_FACTOR_ONE
                dstColorBlendFactor = int VkBlendFactor.VK_BLEND_FACTOR_ZERO
                colorBlendOp = int VkBlendOp.VK_BLEND_OP_ADD
                srcAlphaBlendFactor = int VkBlendFactor.VK_BLEND_FACTOR_ONE
                dstAlphaBlendFactor = int VkBlendFactor.VK_BLEND_FACTOR_ZERO
                alphaBlendOp = int VkBlendOp.VK_BLEND_OP_ADD
                colorWriteMask = uint32 (0x0Fu) // VK_COLOR_COMPONENT_R_BIT | G_BIT | B_BIT | A_BIT
            }
            
            let colorBlendAttachmentHandle = GCHandle.Alloc(colorBlendAttachment, GCHandleType.Pinned)
            let blendConstants = [| 0.0f; 0.0f; 0.0f; 0.0f |]
            let blendConstantsHandle = GCHandle.Alloc(blendConstants, GCHandleType.Pinned)
            
            let mutable colorBlending: VkPipelineColorBlendStateCreateInfo = {
                sType = int VkStructureType.VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO
                pNext = IntPtr.Zero
                flags = 0u
                logicOpEnable = 0u
                logicOp = 0 // VK_LOGIC_OP_COPY (not used when logicOpEnable = 0)
                attachmentCount = 1u
                pAttachments = colorBlendAttachmentHandle.AddrOfPinnedObject()
                blendConstants = blendConstantsHandle.AddrOfPinnedObject()
            }
            
            // Create graphics pipeline
            let shaderStagesHandle = GCHandle.Alloc(shaderStages, GCHandleType.Pinned)
            let vertexInputInfoHandle = GCHandle.Alloc(vertexInputInfo, GCHandleType.Pinned)
            let inputAssemblyHandle = GCHandle.Alloc(inputAssembly, GCHandleType.Pinned)
            let viewportStateHandle = GCHandle.Alloc(viewportState, GCHandleType.Pinned)
            let rasterizerHandle = GCHandle.Alloc(rasterizer, GCHandleType.Pinned)
            let multisamplingHandle = GCHandle.Alloc(multisampling, GCHandleType.Pinned)
            let colorBlendingHandle = GCHandle.Alloc(colorBlending, GCHandleType.Pinned)
            
            try
                let mutable pipelineInfo: VkGraphicsPipelineCreateInfo = {
                    sType = int VkStructureType.VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO
                    pNext = IntPtr.Zero
                    flags = 0u
                    stageCount = 2u
                    pStages = shaderStagesHandle.AddrOfPinnedObject()
                    pVertexInputState = vertexInputInfoHandle.AddrOfPinnedObject()
                    pInputAssemblyState = inputAssemblyHandle.AddrOfPinnedObject()
                    pTessellationState = IntPtr.Zero
                    pViewportState = viewportStateHandle.AddrOfPinnedObject()
                    pRasterizationState = rasterizerHandle.AddrOfPinnedObject()
                    pMultisampleState = multisamplingHandle.AddrOfPinnedObject()
                    pDepthStencilState = IntPtr.Zero
                    pColorBlendState = colorBlendingHandle.AddrOfPinnedObject()
                    pDynamicState = IntPtr.Zero
                    layout = newPipelineLayout
                    renderPass = vkRenderPass
                    subpass = 0u
                    basePipelineHandle = IntPtr.Zero
                    basePipelineIndex = -1
                }
                
                let pipelineInfoHandle = GCHandle.Alloc(pipelineInfo, GCHandleType.Pinned)
                let pipelinesArray = [| IntPtr.Zero |]
                let pipelinesHandle = GCHandle.Alloc(pipelinesArray, GCHandleType.Pinned)
                
                try
                    if vkCreateGraphicsPipelines(vkDevice, IntPtr.Zero, 1u, pipelineInfoHandle.AddrOfPinnedObject(), IntPtr.Zero, pipelinesHandle.AddrOfPinnedObject()) <> int VkResult.VK_SUCCESS then
                        failwith "Failed to create graphics pipeline!"
                    
                    graphicsPipeline <- pipelinesArray.[0]
                finally
                    pipelineInfoHandle.Free()
                    pipelinesHandle.Free()
            finally
                shaderStagesHandle.Free()
                vertexInputInfoHandle.Free()
                inputAssemblyHandle.Free()
                viewportStateHandle.Free()
                rasterizerHandle.Free()
                multisamplingHandle.Free()
                colorBlendingHandle.Free()
                colorBlendAttachmentHandle.Free()
                blendConstantsHandle.Free()
                viewportHandle.Free()
                scissorHandle.Free()
                Marshal.FreeHGlobal(vertShaderNamePtr)
                Marshal.FreeHGlobal(fragShaderNamePtr)
            
            this.PrintLog("CreateGraphicsPipeline - End")
        with
        | ex -> this.PrintLog(sprintf "CreateGraphicsPipeline Error: %s" ex.Message)
    
    member private this.CreateRenderPass() =
        this.PrintLog("CreateRenderPass - Start")
        
        let mutable colorAttachment: VkAttachmentDescription = {
            flags = 0u
            format = swapChainImageFormat
            samples = int VkSampleCountFlags.VK_SAMPLE_COUNT_1_BIT
            loadOp = int VkAttachmentLoadOp.VK_ATTACHMENT_LOAD_OP_CLEAR
            storeOp = int VkAttachmentStoreOp.VK_ATTACHMENT_STORE_OP_STORE
            stencilLoadOp = int VkAttachmentLoadOp.VK_ATTACHMENT_LOAD_OP_DONT_CARE
            stencilStoreOp = int VkAttachmentStoreOp.VK_ATTACHMENT_STORE_OP_DONT_CARE
            initialLayout = int VkImageLayout.VK_IMAGE_LAYOUT_UNDEFINED
            finalLayout = int VkImageLayout.VK_IMAGE_LAYOUT_PRESENT_SRC_KHR
        }
        
        let mutable colorAttachmentRef: VkAttachmentReference = {
            attachment = 0u
            layout = int VkImageLayout.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL
        }
        
        let colorAttachmentRefHandle = GCHandle.Alloc(colorAttachmentRef, GCHandleType.Pinned)
        
        let mutable subpass: VkSubpassDescription = {
            flags = 0u
            pipelineBindPoint = int VkPipelineBindPoint.VK_PIPELINE_BIND_POINT_GRAPHICS
            inputAttachmentCount = 0u
            pInputAttachments = IntPtr.Zero
            colorAttachmentCount = 1u
            pColorAttachments = colorAttachmentRefHandle.AddrOfPinnedObject()
            pResolveAttachments = IntPtr.Zero
            pDepthStencilAttachment = IntPtr.Zero
            preserveAttachmentCount = 0u
            pPreserveAttachments = IntPtr.Zero
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
        
        let attachments = [| colorAttachment |]
        let attachmentsHandle = GCHandle.Alloc(attachments, GCHandleType.Pinned)
        let subpassHandle = GCHandle.Alloc(subpass, GCHandleType.Pinned)
        let dependencyHandle = GCHandle.Alloc(dependency, GCHandleType.Pinned)
        
        try
            let mutable renderPassInfo: VkRenderPassCreateInfo = {
                sType = int VkStructureType.VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO
                pNext = IntPtr.Zero
                flags = 0u
                attachmentCount = uint32 attachments.Length
                pAttachments = attachmentsHandle.AddrOfPinnedObject()
                subpassCount = 1u
                pSubpasses = subpassHandle.AddrOfPinnedObject()
                dependencyCount = 1u
                pDependencies = dependencyHandle.AddrOfPinnedObject()
            }
            
            if vkCreateRenderPass(vkDevice, &renderPassInfo, IntPtr.Zero, &vkRenderPass) <> int VkResult.VK_SUCCESS then
                failwith "Failed to create render pass!"
        finally
            colorAttachmentRefHandle.Free()
            attachmentsHandle.Free()
            subpassHandle.Free()
            dependencyHandle.Free()
        
        this.PrintLog("CreateRenderPass - End")
    
    member private this.CreateSwapChain() =
        this.PrintLog("CreateSwapChain - Start")
        
        // Surface Capabilitiesを取得
        let mutable surfaceCapabilities = Unchecked.defaultof<VkSurfaceCapabilitiesKHR>
        vkGetPhysicalDeviceSurfaceCapabilitiesKHR(vkPhysicalDevice, vkSurface, &surfaceCapabilities) |> ignore
        
        // Surface Formatsを取得
        let mutable formatCount = 0u
        vkGetPhysicalDeviceSurfaceFormatsKHR(vkPhysicalDevice, vkSurface, &formatCount, IntPtr.Zero) |> ignore
        let formats: VkSurfaceFormatKHR[] = Array.zeroCreate (int formatCount)
        let formatsHandle = GCHandle.Alloc(formats, GCHandleType.Pinned)
        try
            vkGetPhysicalDeviceSurfaceFormatsKHR(vkPhysicalDevice, vkSurface, &formatCount, formatsHandle.AddrOfPinnedObject()) |> ignore
        finally
            formatsHandle.Free()
        
        swapChainImageFormat <- formats.[0].format
        swapChainExtent <- surfaceCapabilities.currentExtent
        
        // イメージカウントを決定
        let mutable imageCount = surfaceCapabilities.minImageCount + 1u
        if surfaceCapabilities.maxImageCount > 0u && imageCount > surfaceCapabilities.maxImageCount then
            imageCount <- surfaceCapabilities.maxImageCount
        
        // SwapChain作成情報
        let mutable createInfo: VkSwapchainCreateInfoKHR = {
            sType = uint32 (int VkStructureType.VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR)
            pNext = IntPtr.Zero
            flags = 0u
            surface = vkSurface
            minImageCount = imageCount
            imageFormat = swapChainImageFormat
            imageColorSpace = formats.[0].colorSpace
            imageExtent = swapChainExtent
            imageArrayLayers = 1u
            imageUsage = uint32 (int VkImageUsageFlags.VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT)
            imageSharingMode = int VkSharingMode.VK_SHARING_MODE_EXCLUSIVE
            queueFamilyIndexCount = 0u
            pQueueFamilyIndices = IntPtr.Zero
            preTransform = surfaceCapabilities.currentTransform
            compositeAlpha = uint32 (int VkCompositeAlphaFlagsKHR.VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR)
            presentMode = int VkPresentModeKHR.VK_PRESENT_MODE_FIFO_KHR
            clipped = 1u
            oldSwapchain = IntPtr.Zero
        }
        
        // SwapChainを作成
        if vkCreateSwapchainKHR(vkDevice, &createInfo, IntPtr.Zero, &vkSwapChain) <> int VkResult.VK_SUCCESS then
            failwith "Failed to create swap chain!"
        
        // SwapChain Imagesを取得
        let mutable swapChainImageCount = 0u
        vkGetSwapchainImagesKHR(vkDevice, vkSwapChain, &swapChainImageCount, IntPtr.Zero) |> ignore
        swapChainImages <- Array.zeroCreate (int swapChainImageCount)
        let imagesHandle = GCHandle.Alloc(swapChainImages, GCHandleType.Pinned)
        try
            vkGetSwapchainImagesKHR(vkDevice, vkSwapChain, &swapChainImageCount, imagesHandle.AddrOfPinnedObject()) |> ignore
        finally
            imagesHandle.Free()
        
        this.PrintLog($"SwapChain: {vkSwapChain}")
        this.PrintLog($"SwapChain Image Count: {swapChainImageCount}")
        this.PrintLog("CreateSwapChain - End")
    
    member private this.CreateSwapChainImageViews() =
        this.PrintLog("CreateSwapChainImageViews - Start")
        
        swapChainImageViews <- Array.zeroCreate swapChainImages.Length
        
        for i in 0 .. swapChainImages.Length - 1 do
            let mutable createInfo: VkImageViewCreateInfo = {
                sType = int VkStructureType.VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO
                pNext = IntPtr.Zero
                flags = 0u
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
                    baseMipLevel = 0u
                    levelCount = 1u
                    baseArrayLayer = 0u
                    layerCount = 1u
                }
            }
            
            if vkCreateImageView(vkDevice, &createInfo, IntPtr.Zero, &swapChainImageViews.[i]) <> int VkResult.VK_SUCCESS then
                failwith "Failed to create image views!"
        
        this.PrintLog("CreateSwapChainImageViews - End")
    
    member private this.CreateCommandBuffers() =
        this.PrintLog("CreateCommandBuffer - Start")
        
        let mutable allocInfo: VkCommandBufferAllocateInfo = {
            sType = int VkStructureType.VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO
            pNext = IntPtr.Zero
            commandPool = commandPool
            level = int VkCommandBufferLevel.VK_COMMAND_BUFFER_LEVEL_PRIMARY
            commandBufferCount = 1u
        }
        
        let mutable cb = IntPtr.Zero
        if vkAllocateCommandBuffers(vkDevice, &allocInfo, &cb) <> int VkResult.VK_SUCCESS then
            failwith "Failed to allocate command buffers!"
        
        commandBuffer <- cb
        this.PrintLog("CreateCommandBuffer - End")
    
    member private this.CreateSyncObjects() =
        this.PrintLog("CreateSyncObjects - Start")
        
        imageAvailableSemaphores <- Array.zeroCreate MAX_FRAMES_IN_FLIGHT
        renderFinishedSemaphores <- Array.zeroCreate MAX_FRAMES_IN_FLIGHT
        inFlightFences <- Array.zeroCreate MAX_FRAMES_IN_FLIGHT
        
        let mutable semaphoreInfo: VkSemaphoreCreateInfo = {
            sType = int VkStructureType.VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO
            pNext = IntPtr.Zero
            flags = 0u
        }
        
        let mutable fenceInfo: VkFenceCreateInfo = {
            sType = int VkStructureType.VK_STRUCTURE_TYPE_FENCE_CREATE_INFO
            pNext = IntPtr.Zero
            flags = 1u  // VK_FENCE_CREATE_SIGNALED_BIT
        }
        
        for i in 0 .. MAX_FRAMES_IN_FLIGHT - 1 do
            if vkCreateSemaphore(vkDevice, &semaphoreInfo, IntPtr.Zero, &imageAvailableSemaphores.[i]) <> int VkResult.VK_SUCCESS then
                failwith "Failed to create image available semaphore!"
            
            if vkCreateSemaphore(vkDevice, &semaphoreInfo, IntPtr.Zero, &renderFinishedSemaphores.[i]) <> int VkResult.VK_SUCCESS then
                failwith "Failed to create render finished semaphore!"
            
            if vkCreateFence(vkDevice, &fenceInfo, IntPtr.Zero, &inFlightFences.[i]) <> int VkResult.VK_SUCCESS then
                failwith "Failed to create fence!"
        
        this.PrintLog("CreateSyncObjects - End")
    
    member private this.CreateFramebuffers() =
        this.PrintLog("CreateFramebuffers - Start")
        
        swapChainFramebuffers <- Array.zeroCreate swapChainImageViews.Length
        
        for i in 0 .. swapChainImageViews.Length - 1 do
            let attachments = [| swapChainImageViews.[i] |]  // Only color attachment, no depth
            let attachmentsHandle = GCHandle.Alloc(attachments, GCHandleType.Pinned)
            
            try
                let mutable framebufferInfo: VkFramebufferCreateInfo = {
                    sType = int VkStructureType.VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO
                    pNext = IntPtr.Zero
                    flags = 0u
                    renderPass = vkRenderPass
                    attachmentCount = uint32 attachments.Length
                    pAttachments = attachmentsHandle.AddrOfPinnedObject()
                    width = swapChainExtent.width
                    height = swapChainExtent.height
                    layers = 1u
                }
                
                if vkCreateFramebuffer(vkDevice, &framebufferInfo, IntPtr.Zero, &swapChainFramebuffers.[i]) <> int VkResult.VK_SUCCESS then
                    failwith "Failed to create framebuffer!"
            finally
                attachmentsHandle.Free()
        
        this.PrintLog("CreateFramebuffers - End")
    
    member private this.CreateCommandPool() =
        this.PrintLog("CreateCommandPool - Start")
        
        let mutable poolInfo: VkCommandPoolCreateInfo = {
            sType = int VkStructureType.VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO
            pNext = IntPtr.Zero
            flags = uint32 (int VkCommandPoolCreateFlags.VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT)
            queueFamilyIndex = graphicsQueueFamilyIndex
        }
        
        if vkCreateCommandPool(vkDevice, &poolInfo, IntPtr.Zero, &commandPool) <> int VkResult.VK_SUCCESS then
            failwith "Failed to create command pool!"
        
        this.PrintLog("CreateCommandPool - End")
    
    member private this.CreateLogicalDevice() =
        printfn "----------------------------------------"
        this.PrintLog("CreateLogicalDevice - Start")
        try
            let queueFamilyIndex = this.FindQueueFamily()
            this.PrintLog(sprintf "Queue Family Index: %d" queueFamilyIndex)
            
            let queuePriority = 1.0f
            let priorityHandle = GCHandle.Alloc(queuePriority, GCHandleType.Pinned)
            
            let mutable queueCreateInfo: VkDeviceQueueCreateInfo = 
                { sType = uint32 VkStructureType.VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO
                  pNext = IntPtr.Zero
                  flags = 0u
                  queueFamilyIndex = queueFamilyIndex
                  queueCount = 1u
                  pQueuePriorities = priorityHandle.AddrOfPinnedObject() }
            
            let queueCreateInfoHandle = GCHandle.Alloc(queueCreateInfo, GCHandleType.Pinned)
            
            let extensions = [| "VK_KHR_swapchain" |]
            let extensionsPtr = this.StringArrayToPtr(extensions)
            
            try
                let mutable createInfo: VkDeviceCreateInfo = 
                    { sType = uint32 VkStructureType.VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO
                      pNext = IntPtr.Zero
                      flags = 0u
                      queueCreateInfoCount = 1u
                      pQueueCreateInfos = queueCreateInfoHandle.AddrOfPinnedObject()
                      enabledLayerCount = 0u
                      ppEnabledLayerNames = IntPtr.Zero
                      enabledExtensionCount = uint32 extensions.Length
                      ppEnabledExtensionNames = extensionsPtr
                      pEnabledFeatures = IntPtr.Zero }
                
                let mutable device = IntPtr.Zero
                let result = vkCreateDevice(vkPhysicalDevice, &createInfo, IntPtr.Zero, &device)
                
                if result <> 0 then
                    failwithf "Failed to create logical device! Result: %d" result
                
                vkDevice <- device
                
                // Get queues
                let mutable queue = IntPtr.Zero
                vkGetDeviceQueue(vkDevice, queueFamilyIndex, 0u, &queue)
                graphicsQueue <- queue
                presentQueue <- queue
                
                this.PrintLog(sprintf "Logical Device created: %A" vkDevice)
                this.PrintLog("CreateLogicalDevice - End")
            finally
                queueCreateInfoHandle.Free()
                priorityHandle.Free()
                this.FreeStringArray(extensionsPtr, extensions.Length)
        with
        | ex -> this.PrintLog(sprintf "CreateLogicalDevice Error: %s" ex.Message)
    
    member private this.PickPhysicalDevice() =
        printfn "----------------------------------------"
        this.PrintLog("PickPhysicalDevice - Start")
        try
            let mutable deviceCount = 0u
            vkEnumeratePhysicalDevices(vkInstance, &deviceCount, IntPtr.Zero) |> ignore
            
            if deviceCount = 0u then
                failwith "Failed to find GPUs with Vulkan support!"
            
            this.PrintLog(sprintf "Found %d GPU(s)" deviceCount)
            
            // Allocate array for device handles
            let devices: nativeint[] = Array.zeroCreate (int deviceCount)
            let devicesHandle = GCHandle.Alloc(devices, GCHandleType.Pinned)
            
            try
                vkEnumeratePhysicalDevices(vkInstance, &deviceCount, devicesHandle.AddrOfPinnedObject()) |> ignore
                
                // Pick the first device
                vkPhysicalDevice <- devices.[0]
                
                this.PrintLog(sprintf "Selected PhysicalDevice: %A" vkPhysicalDevice)
                this.PrintLog("PickPhysicalDevice - End")
            finally
                devicesHandle.Free()
        with
        | ex -> this.PrintLog(sprintf "PickPhysicalDevice Error: %s" ex.Message)
    
    member private this.CreateSurface() =
        printfn "----------------------------------------"
        this.PrintLog("CreateSurface - Start")
        try
            let mutable createInfo: VkWin32SurfaceCreateInfoKHR = 
                { sType = uint32 VkStructureType.VK_STRUCTURE_TYPE_WIN32_SURFACE_CREATE_INFO_KHR
                  pNext = IntPtr.Zero
                  flags = 0u
                  hinstance = GetModuleHandle(null)
                  hwnd = this.Handle }
            
            let vkCreateWin32SurfaceKHRPtr = vkGetInstanceProcAddr(vkInstance, "vkCreateWin32SurfaceKHR")
            if vkCreateWin32SurfaceKHRPtr = IntPtr.Zero then
                failwith "Failed to get vkCreateWin32SurfaceKHR function pointer"
            
            let vkCreateWin32SurfaceKHR = 
                Marshal.GetDelegateForFunctionPointer<vkCreateWin32SurfaceKHRFunc>(vkCreateWin32SurfaceKHRPtr)
            
            let mutable surface = IntPtr.Zero
            let result = vkCreateWin32SurfaceKHR.Invoke(vkInstance, &createInfo, IntPtr.Zero, &surface)
            
            if result <> 0 then
                failwithf "Failed to create window surface! Result: %d" result
            
            vkSurface <- surface
            this.PrintLog(sprintf "Surface created: %A" surface)
            this.PrintLog("CreateSurface - End")
        with
        | ex -> this.PrintLog(sprintf "CreateSurface Error: %s" ex.Message)
    
    member private this.CreateInstance() =
        this.PrintLog("CreateInstance - Start")
        try
            let appInfo: VkApplicationInfo = 
                { sType = uint32 VkStructureType.VK_STRUCTURE_TYPE_APPLICATION_INFO
                  pNext = IntPtr.Zero
                  pApplicationName = "Vulkan App (F#)"
                  applicationVersion = this.MakeVersion(1u, 0u, 0u)
                  pEngineName = "No Engine"
                  engineVersion = this.MakeVersion(1u, 0u, 0u)
                  apiVersion = this.MakeVersion(1u, 4u, 0u) }
            
            let extensions = [| "VK_KHR_surface"; "VK_KHR_win32_surface"; "VK_EXT_debug_utils" |]
            let extensionsPtr = this.StringArrayToPtr(extensions)
            
            let validationLayers = [| "VK_LAYER_KHRONOS_validation" |]
            let layersPtr = this.StringArrayToPtr(validationLayers)
            
            // VkApplicationInfo contains Strings (non-blittable), so marshal it into unmanaged memory
            let appInfoPtr = Marshal.AllocHGlobal(Marshal.SizeOf(typeof<VkApplicationInfo>))
            Marshal.StructureToPtr(appInfo, appInfoPtr, false)
            
            try
                let mutable createInfo: VkInstanceCreateInfo = 
                    { sType = uint32 VkStructureType.VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO
                      pNext = IntPtr.Zero
                      flags = 0u
                      pApplicationInfo = appInfoPtr
                      enabledLayerCount = uint32 validationLayers.Length
                      ppEnabledLayerNames = layersPtr
                      enabledExtensionCount = uint32 extensions.Length
                      ppEnabledExtensionNames = extensionsPtr }
                
                let mutable instance = IntPtr.Zero
                let result = vkCreateInstance(&createInfo, IntPtr.Zero, &instance)
                
                if result <> 0 then
                    failwithf "Failed to create instance! Result: %d" result
                
                vkInstance <- instance
                this.PrintLog(sprintf "Instance created: %A" instance)
                this.PrintLog("CreateInstance - End")
            finally
                Marshal.DestroyStructure(appInfoPtr, typeof<VkApplicationInfo>)
                Marshal.FreeHGlobal(appInfoPtr)
                this.FreeStringArray(extensionsPtr, extensions.Length)
                this.FreeStringArray(layersPtr, validationLayers.Length)
        with
        | ex -> this.PrintLog(sprintf "CreateInstance Error: %s" ex.Message)
    
    member private this.InitVulkan() =
        this.PrintLog("InitVulkan - Start")
        
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
            this.CreateCommandBuffers()
            this.CreateSyncObjects()
        with
        | ex -> this.PrintLog(sprintf "InitVulkan Error: %s" ex.Message)
        
        this.PrintLog("InitVulkan - End")
    
    member private this.DrawFrame() =
        try
            if commandBuffer <> IntPtr.Zero then
                let currentFrame = frameIndex % MAX_FRAMES_IN_FLIGHT
                printfn "----------------------------------------"
                printfn "[HelloForm::DrawFrame] - Start (Frame: %d, CurrentFrame: %d)" frameIndex currentFrame
                
                // Wait for fence
                let fenceArray = [| inFlightFences.[currentFrame] |]
                let fenceHandle = GCHandle.Alloc(fenceArray, GCHandleType.Pinned)
                try
                    vkWaitForFences(vkDevice, 1u, fenceHandle.AddrOfPinnedObject(), 1u, UInt64.MaxValue) |> ignore
                    vkResetFences(vkDevice, 1u, fenceHandle.AddrOfPinnedObject()) |> ignore
                finally
                    fenceHandle.Free()
                
                // Acquire next image
                let mutable imageIndex = 0u
                let result = vkAcquireNextImageKHR(vkDevice, vkSwapChain, UInt64.MaxValue, imageAvailableSemaphores.[currentFrame], IntPtr.Zero, &imageIndex)
                
                if result <> int VkResult.VK_SUCCESS && result <> int VkResult.VK_SUBOPTIMAL_KHR then
                    printfn "Failed to acquire swap chain image: %d" result
                else
                    // Begin command buffer
                    let mutable beginInfo: VkCommandBufferBeginInfo = {
                        sType = int VkStructureType.VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO
                        pNext = IntPtr.Zero
                        flags = uint32 (int VkCommandBufferUsageFlags.VK_COMMAND_BUFFER_USAGE_SIMULTANEOUS_USE_BIT)
                        pInheritanceInfo = IntPtr.Zero
                    }
                    
                    if vkBeginCommandBuffer(commandBuffer, &beginInfo) <> int VkResult.VK_SUCCESS then
                        printfn "Failed to begin recording command buffer!"
                    else
                        // Setup clear values
                        let clearValues: VkClearValue[] = Array.zeroCreate 1
                        clearValues.[0].color <- { float32_0 = 0.0f; float32_1 = 0.0f; float32_2 = 0.0f; float32_3 = 1.0f }
                        
                        let clearValuesHandle = GCHandle.Alloc(clearValues, GCHandleType.Pinned)
                        try
                            let mutable renderPassInfo: VkRenderPassBeginInfo = {
                                sType = int VkStructureType.VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO
                                pNext = IntPtr.Zero
                                renderPass = vkRenderPass
                                framebuffer = swapChainFramebuffers.[int imageIndex]
                                renderArea = { offset = { x = 0; y = 0 }; extent = swapChainExtent }
                                clearValueCount = 1u
                                pClearValues = clearValuesHandle.AddrOfPinnedObject()
                            }
                            
                            vkCmdBeginRenderPass(commandBuffer, &renderPassInfo, int VkSubpassContents.VK_SUBPASS_CONTENTS_INLINE)
                            vkCmdBindPipeline(commandBuffer, int VkPipelineBindPoint.VK_PIPELINE_BIND_POINT_GRAPHICS, graphicsPipeline)
                            vkCmdDraw(commandBuffer, 3u, 1u, 0u, 0u)
                            vkCmdEndRenderPass(commandBuffer)
                            
                            if vkEndCommandBuffer(commandBuffer) <> int VkResult.VK_SUCCESS then
                                printfn "Failed to record command buffer!"
                            else
                                // Submit command buffer
                                let waitSemaphores = [| imageAvailableSemaphores.[currentFrame] |]
                                let waitSemaphoresHandle = GCHandle.Alloc(waitSemaphores, GCHandleType.Pinned)
                                
                                let signalSemaphores = [| renderFinishedSemaphores.[currentFrame] |]
                                let signalSemaphoresHandle = GCHandle.Alloc(signalSemaphores, GCHandleType.Pinned)
                                
                                let commandBuffers = [| commandBuffer |]
                                let commandBuffersHandle = GCHandle.Alloc(commandBuffers, GCHandleType.Pinned)
                                
                                let waitStages = [| int VkPipelineStageFlags.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT |]
                                let waitStagesHandle = GCHandle.Alloc(waitStages, GCHandleType.Pinned)
                                
                                try
                                    let mutable submitInfo: VkSubmitInfo = {
                                        sType = int VkStructureType.VK_STRUCTURE_TYPE_SUBMIT_INFO
                                        pNext = IntPtr.Zero
                                        waitSemaphoreCount = 1u
                                        pWaitSemaphores = waitSemaphoresHandle.AddrOfPinnedObject()
                                        pWaitDstStageMask = waitStagesHandle.AddrOfPinnedObject()
                                        commandBufferCount = 1u
                                        pCommandBuffers = commandBuffersHandle.AddrOfPinnedObject()
                                        signalSemaphoreCount = 1u
                                        pSignalSemaphores = signalSemaphoresHandle.AddrOfPinnedObject()
                                    }
                                    
                                    if vkQueueSubmit(graphicsQueue, 1u, &submitInfo, inFlightFences.[currentFrame]) <> int VkResult.VK_SUCCESS then
                                        printfn "Failed to submit draw command buffer!"
                                    else
                                        // Present frame
                                        let swapchains = [| vkSwapChain |]
                                        let swapchainsHandle = GCHandle.Alloc(swapchains, GCHandleType.Pinned)
                                        
                                        let imageIndices = [| imageIndex |]
                                        let imageIndicesHandle = GCHandle.Alloc(imageIndices, GCHandleType.Pinned)
                                        
                                        let presentWaitSemaphores = [| renderFinishedSemaphores.[currentFrame] |]
                                        let presentWaitSemaphoresHandle = GCHandle.Alloc(presentWaitSemaphores, GCHandleType.Pinned)
                                        
                                        try
                                            let mutable presentInfo: VkPresentInfoKHR = {
                                                sType = int VkStructureType.VK_STRUCTURE_TYPE_PRESENT_INFO_KHR
                                                pNext = IntPtr.Zero
                                                waitSemaphoreCount = 1u
                                                pWaitSemaphores = presentWaitSemaphoresHandle.AddrOfPinnedObject()
                                                swapchainCount = 1u
                                                pSwapchains = swapchainsHandle.AddrOfPinnedObject()
                                                pImageIndices = imageIndicesHandle.AddrOfPinnedObject()
                                                pResults = IntPtr.Zero
                                            }
                                            
                                            let presentResult = vkQueuePresentKHR(presentQueue, &presentInfo)
                                            if presentResult = int VkResult.VK_ERROR_OUT_OF_DATE_KHR || presentResult = int VkResult.VK_SUBOPTIMAL_KHR then
                                                printfn "Swapchain is out of date or suboptimal"
                                            elif presentResult <> int VkResult.VK_SUCCESS then
                                                printfn "Failed to present swap chain image: %d" presentResult
                                            else
                                                printfn "Frame %d presented successfully" frameIndex
                                        finally
                                            presentWaitSemaphoresHandle.Free()
                                            imageIndicesHandle.Free()
                                            swapchainsHandle.Free()
                                finally
                                    waitStagesHandle.Free()
                                    commandBuffersHandle.Free()
                                    signalSemaphoresHandle.Free()
                                    waitSemaphoresHandle.Free()
                        finally
                            clearValuesHandle.Free()
                
                frameIndex <- frameIndex + 1
                printfn "[HelloForm::DrawFrame] - End"
                printfn "----------------------------------------"
        with
        | ex -> printfn "DrawFrame Exception: %s\nStackTrace: %s" ex.Message ex.StackTrace
    
    member private this.Cleanup() =
        if isDisposed then
            ()
        else
            isDisposed <- true
            printfn "----------------------------------------"
            this.PrintLog("Cleanup - Start")
            
            if vkDevice <> IntPtr.Zero then
                vkDeviceWaitIdle(vkDevice) |> ignore
            
            if inFlightFences.Length > 0 then
                for fence in inFlightFences do
                    if fence <> IntPtr.Zero then
                        vkDestroyFence(vkDevice, fence, IntPtr.Zero)
            
            if renderFinishedSemaphores.Length > 0 then
                for semaphore in renderFinishedSemaphores do
                    if semaphore <> IntPtr.Zero then
                        vkDestroySemaphore(vkDevice, semaphore, IntPtr.Zero)
            
            if imageAvailableSemaphores.Length > 0 then
                for semaphore in imageAvailableSemaphores do
                    if semaphore <> IntPtr.Zero then
                        vkDestroySemaphore(vkDevice, semaphore, IntPtr.Zero)
            
            if commandPool <> IntPtr.Zero then
                vkDestroyCommandPool(vkDevice, commandPool, IntPtr.Zero)
            
            if fragShaderModule <> IntPtr.Zero then
                vkDestroyShaderModule(vkDevice, fragShaderModule, IntPtr.Zero)
            
            if vertShaderModule <> IntPtr.Zero then
                vkDestroyShaderModule(vkDevice, vertShaderModule, IntPtr.Zero)
            
            if swapChainFramebuffers.Length > 0 then
                for fb in swapChainFramebuffers do
                    if fb <> IntPtr.Zero then
                        vkDestroyFramebuffer(vkDevice, fb, IntPtr.Zero)
            
            if graphicsPipeline <> IntPtr.Zero then
                this.PrintLog(sprintf "Destroying graphicsPipeline: 0x%X" (graphicsPipeline.ToInt64()))
                vkDestroyPipeline(vkDevice, graphicsPipeline, IntPtr.Zero)
            
            if pipelineLayout <> IntPtr.Zero then
                this.PrintLog(sprintf "Destroying pipelineLayout: 0x%X" (pipelineLayout.ToInt64()))
                vkDestroyPipelineLayout(vkDevice, pipelineLayout, IntPtr.Zero)
            else
                this.PrintLog("pipelineLayout is IntPtr.Zero - NOT destroying")
            
            if vkRenderPass <> IntPtr.Zero then
                vkDestroyRenderPass(vkDevice, vkRenderPass, IntPtr.Zero)
            
            if swapChainImageViews.Length > 0 then
                for view in swapChainImageViews do
                    if view <> IntPtr.Zero then
                        vkDestroyImageView(vkDevice, view, IntPtr.Zero)
            
            if vkSwapChain <> IntPtr.Zero then
                vkDestroySwapchainKHR(vkDevice, vkSwapChain, IntPtr.Zero)
            
            if vkDevice <> IntPtr.Zero then
                vkDestroyDevice(vkDevice, IntPtr.Zero)
            
            if vkSurface <> IntPtr.Zero then
                vkDestroySurfaceKHR(vkInstance, vkSurface, IntPtr.Zero)
            
            if vkInstance <> IntPtr.Zero then
                vkDestroyInstance(vkInstance, IntPtr.Zero)
            
            this.PrintLog("Cleanup - End")
            printfn "----------------------------------------"
    
    override this.OnHandleCreated(e) =
        base.OnHandleCreated(e)
        printfn "----------------------------------------"
        printfn "[HelloForm::Main] - Start"
        printfn "----------------------------------------"
        this.InitVulkan()
        printfn "Form loaded"
    
    override this.OnPaint(e) =
        base.OnPaint(e)
        this.DrawFrame()
    
    override this.Dispose(disposing) =
        if disposing then
            this.Cleanup()
        base.Dispose(disposing)

[<EntryPoint>]
let main argv =
    Application.SetCompatibleTextRenderingDefault(false)
    Application.EnableVisualStyles()
    use form = new HelloForm()
    Application.Run(form)
    printfn "[HelloForm::Main] - End"
    0
