using System;
using System.Drawing;
using System.Windows.Forms;
using System.Runtime.InteropServices;
using System.Text;
using System.Linq;

// ========================================================================================================
// Shader Compiler Class (Using shaderc_shared.dll)
// ========================================================================================================
public class ShaderCompiler
{
    private const string LibName = "shaderc_shared.dll";

    public enum ShaderKind : int
    {
        Vertex = 0,
        Fragment = 1,
        Compute = 2,
    }

    private enum CompilationStatus : int
    {
        Success = 0,
    }

    [DllImport(LibName, CallingConvention = CallingConvention.Cdecl)]
    private static extern IntPtr shaderc_compiler_initialize();

    [DllImport(LibName, CallingConvention = CallingConvention.Cdecl)]
    private static extern void shaderc_compiler_release(IntPtr compiler);

    [DllImport(LibName, CallingConvention = CallingConvention.Cdecl)]
    private static extern IntPtr shaderc_compile_options_initialize();

    [DllImport(LibName, CallingConvention = CallingConvention.Cdecl)]
    private static extern void shaderc_compile_options_set_optimization_level(IntPtr options, int level);

    [DllImport(LibName, CallingConvention = CallingConvention.Cdecl)]
    private static extern void shaderc_compile_options_release(IntPtr options);

    [DllImport(LibName, CallingConvention = CallingConvention.Cdecl)]
    private static extern IntPtr shaderc_compile_into_spv(
        IntPtr compiler,
        [MarshalAs(UnmanagedType.LPStr)] string source_text,
        UIntPtr source_text_size,
        int shader_kind,
        [MarshalAs(UnmanagedType.LPStr)] string input_file_name,
        [MarshalAs(UnmanagedType.LPStr)] string entry_point_name,
        IntPtr additional_options);

    [DllImport(LibName, CallingConvention = CallingConvention.Cdecl)]
    private static extern void shaderc_result_release(IntPtr result);

    [DllImport(LibName, CallingConvention = CallingConvention.Cdecl)]
    private static extern UIntPtr shaderc_result_get_length(IntPtr result);

    [DllImport(LibName, CallingConvention = CallingConvention.Cdecl)]
    private static extern IntPtr shaderc_result_get_bytes(IntPtr result);

    [DllImport(LibName, CallingConvention = CallingConvention.Cdecl)]
    private static extern CompilationStatus shaderc_result_get_compilation_status(IntPtr result);

    [DllImport(LibName, CallingConvention = CallingConvention.Cdecl)]
    private static extern IntPtr shaderc_result_get_error_message(IntPtr result);

    public static byte[] Compile(string source, ShaderKind kind, string fileName = "shader.glsl", string entryPoint = "main")
    {
        IntPtr compiler = shaderc_compiler_initialize();
        IntPtr options = shaderc_compile_options_initialize();
        shaderc_compile_options_set_optimization_level(options, 2);

        try
        {
            IntPtr result = shaderc_compile_into_spv(
                compiler, source, (UIntPtr)Encoding.UTF8.GetByteCount(source),
                (int)kind, fileName, entryPoint, options);

            try
            {
                var status = shaderc_result_get_compilation_status(result);
                if (status != CompilationStatus.Success)
                {
                    string errorMsg = Marshal.PtrToStringAnsi(shaderc_result_get_error_message(result));
                    throw new Exception($"Shader compilation failed: {errorMsg}");
                }

                ulong length = (ulong)shaderc_result_get_length(result);
                IntPtr bytesPtr = shaderc_result_get_bytes(result);
                byte[] bytecode = new byte[length];
                Marshal.Copy(bytesPtr, bytecode, 0, (int)length);
                return bytecode;
            }
            finally { shaderc_result_release(result); }
        }
        finally
        {
            shaderc_compile_options_release(options);
            shaderc_compiler_release(compiler);
        }
    }
}

// ========================================================================================================
// Main Application
// ========================================================================================================
class HarmonographForm : Form
{
    [DllImport("kernel32.dll", CharSet = CharSet.Auto)]
    private static extern IntPtr GetModuleHandle(string lpModuleName);

    // ========================================================================================================
    // Enums
    // ========================================================================================================
    public enum VkStructureType : uint
    {
        VK_STRUCTURE_TYPE_APPLICATION_INFO = 0,
        VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO = 1,
        VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO = 2,
        VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO = 3,
        VK_STRUCTURE_TYPE_SUBMIT_INFO = 4,
        VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO = 5,
        VK_STRUCTURE_TYPE_FENCE_CREATE_INFO = 8,
        VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO = 9,
        VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO = 12,
        VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO = 15,
        VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO = 16,
        VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO = 18,
        VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO = 19,
        VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO = 20,
        VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO = 22,
        VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO = 23,
        VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO = 24,
        VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO = 26,
        VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO = 28,
        VK_STRUCTURE_TYPE_COMPUTE_PIPELINE_CREATE_INFO = 29,
        VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO = 30,
        VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO = 32,
        VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO = 33,
        VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO = 34,
        VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET = 35,
        VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO = 37,
        VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO = 38,
        VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO = 39,
        VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO = 40,
        VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO = 42,
        VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO = 43,
        VK_STRUCTURE_TYPE_BUFFER_MEMORY_BARRIER = 44,
        VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR = 1000001000,
        VK_STRUCTURE_TYPE_PRESENT_INFO_KHR = 1000001001,
        VK_STRUCTURE_TYPE_WIN32_SURFACE_CREATE_INFO_KHR = 1000009000,
    }

    public enum VkResult : int
    {
        VK_SUCCESS = 0,
        VK_SUBOPTIMAL_KHR = 1000001003,
        VK_ERROR_OUT_OF_DATE_KHR = -1000001004
    }

    public enum VkBool32 : uint { False = 0, True = 1 }

    [Flags]
    public enum VkQueueFlags : uint
    {
        VK_QUEUE_GRAPHICS_BIT = 0x00000001,
        VK_QUEUE_COMPUTE_BIT = 0x00000002,
    }

    public enum VkPresentModeKHR : uint
    {
        VK_PRESENT_MODE_FIFO_KHR = 2,
    }

    [Flags]
    public enum VkImageUsageFlags : uint
    {
        VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT = 0x00000010,
    }

    [Flags]
    public enum VkSurfaceTransformFlagBitsKHR : uint
    {
        VK_SURFACE_TRANSFORM_IDENTITY_BIT_KHR = 0x00000001,
    }

    [Flags]
    public enum VkCompositeAlphaFlagsKHR : uint
    {
        VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR = 0x00000001,
    }

    public enum VkPrimitiveTopology : uint
    {
        VK_PRIMITIVE_TOPOLOGY_LINE_STRIP = 2,
    }

    [Flags]
    public enum VkShaderStageFlags : uint
    {
        VK_SHADER_STAGE_VERTEX_BIT = 0x00000001,
        VK_SHADER_STAGE_FRAGMENT_BIT = 0x00000010,
        VK_SHADER_STAGE_COMPUTE_BIT = 0x00000020,
    }

    [Flags]
    public enum VkPipelineStageFlags : uint
    {
        VK_PIPELINE_STAGE_VERTEX_SHADER_BIT = 0x00000008,
        VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT = 0x00000080,
        VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT = 0x00000800,
    }

    public enum VkAttachmentLoadOp : uint
    {
        VK_ATTACHMENT_LOAD_OP_CLEAR = 1,
    }

    public enum VkAttachmentStoreOp : uint
    {
        VK_ATTACHMENT_STORE_OP_STORE = 0,
    }

    public enum VkImageLayout : uint
    {
        VK_IMAGE_LAYOUT_UNDEFINED = 0,
        VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL = 2,
        VK_IMAGE_LAYOUT_PRESENT_SRC_KHR = 1000001002
    }

    public enum VkSampleCountFlags : uint
    {
        VK_SAMPLE_COUNT_1_BIT = 0x00000001,
    }

    public enum VkFormat : uint
    {
        VK_FORMAT_B8G8R8A8_UNORM = 44,
    }

    public enum VkColorSpaceKHR { VK_COLOR_SPACE_SRGB_NONLINEAR_KHR = 0 }

    public enum VkSharingMode : uint { VK_SHARING_MODE_EXCLUSIVE = 0 }

    public enum VkPipelineBindPoint : uint
    {
        VK_PIPELINE_BIND_POINT_GRAPHICS = 0,
        VK_PIPELINE_BIND_POINT_COMPUTE = 1
    }

    [Flags]
    public enum VkAccessFlags : uint
    {
        VK_ACCESS_SHADER_READ_BIT = 0x00000020,
        VK_ACCESS_SHADER_WRITE_BIT = 0x00000040,
    }

    public enum VkPolygonMode : uint { VK_POLYGON_MODE_FILL = 0 }

    [Flags]
    public enum VkCullModeFlags : uint { VK_CULL_MODE_NONE = 0 }

    public enum VkFrontFace : uint { VK_FRONT_FACE_COUNTER_CLOCKWISE = 0 }

    [Flags]
    public enum VkColorComponentFlags : uint
    {
        VK_COLOR_COMPONENT_R_BIT = 0x00000001,
        VK_COLOR_COMPONENT_G_BIT = 0x00000002,
        VK_COLOR_COMPONENT_B_BIT = 0x00000004,
        VK_COLOR_COMPONENT_A_BIT = 0x00000008
    }

    [Flags]
    public enum VkCommandBufferUsageFlags : uint
    {
        VK_COMMAND_BUFFER_USAGE_SIMULTANEOUS_USE_BIT = 0x00000004,
    }

    public enum VkSubpassContents : uint { VK_SUBPASS_CONTENTS_INLINE = 0 }

    public enum VkCommandBufferLevel { VK_COMMAND_BUFFER_LEVEL_PRIMARY = 0 }

    [Flags]
    public enum VkCommandPoolCreateFlags : uint
    {
        VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT = 0x00000002
    }

    [Flags]
    public enum VkFenceCreateFlags : uint
    {
        VK_FENCE_CREATE_SIGNALED_BIT = 0x00000001
    }

    public enum VkImageViewType { VK_IMAGE_VIEW_TYPE_2D = 1 }

    [Flags]
    public enum VkImageAspectFlags : uint { VK_IMAGE_ASPECT_COLOR_BIT = 0x1 }

    public enum VkComponentSwizzle : uint { VK_COMPONENT_SWIZZLE_IDENTITY = 0 }

    [Flags]
    public enum VkMemoryPropertyFlags : uint
    {
        VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT = 0x1,
        VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT = 0x2,
        VK_MEMORY_PROPERTY_HOST_COHERENT_BIT = 0x4,
    }

    [Flags]
    public enum VkBufferUsageFlags : uint
    {
        VK_BUFFER_USAGE_UNIFORM_BUFFER_BIT = 0x00000010,
        VK_BUFFER_USAGE_STORAGE_BUFFER_BIT = 0x00000020,
    }

    public enum VkDescriptorType : uint
    {
        VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER = 6,
        VK_DESCRIPTOR_TYPE_STORAGE_BUFFER = 7,
    }

    public const uint VK_QUEUE_FAMILY_IGNORED = 0xFFFFFFFF;

    // ========================================================================================================
    // Structures
    // ========================================================================================================
    [StructLayout(LayoutKind.Sequential)]
    public struct VkApplicationInfo
    {
        public VkStructureType sType;
        public IntPtr pNext;
        public IntPtr pApplicationName;
        public uint applicationVersion;
        public IntPtr pEngineName;
        public uint engineVersion;
        public uint apiVersion;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct VkInstanceCreateInfo
    {
        public VkStructureType sType;
        public IntPtr pNext;
        public uint flags;
        public IntPtr pApplicationInfo;
        public uint enabledLayerCount;
        public IntPtr ppEnabledLayerNames;
        public uint enabledExtensionCount;
        public IntPtr ppEnabledExtensionNames;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct VkExtent2D { public uint width; public uint height; }

    [StructLayout(LayoutKind.Sequential)]
    public struct VkExtent3D { public uint width; public uint height; public uint depth; }

    [StructLayout(LayoutKind.Sequential)]
    public struct VkOffset2D { public int x; public int y; }

    [StructLayout(LayoutKind.Sequential)]
    public struct VkRect2D { public VkOffset2D offset; public VkExtent2D extent; }

    [StructLayout(LayoutKind.Sequential)]
    public struct VkQueueFamilyProperties
    {
        public VkQueueFlags queueFlags;
        public uint queueCount;
        public uint timestampValidBits;
        public VkExtent3D minImageTransferGranularity;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct VkSurfaceCapabilitiesKHR
    {
        public uint minImageCount;
        public uint maxImageCount;
        public VkExtent2D currentExtent;
        public VkExtent2D minImageExtent;
        public VkExtent2D maxImageExtent;
        public uint maxImageArrayLayers;
        public uint supportedTransforms;
        public VkSurfaceTransformFlagBitsKHR currentTransform;
        public VkCompositeAlphaFlagsKHR supportedCompositeAlpha;
        public VkImageUsageFlags supportedUsageFlags;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct VkSurfaceFormatKHR
    {
        public VkFormat format;
        public VkColorSpaceKHR colorSpace;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct VkWin32SurfaceCreateInfoKHR
    {
        public VkStructureType sType;
        public IntPtr pNext;
        public uint flags;
        public IntPtr hinstance;
        public IntPtr hwnd;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct VkDeviceQueueCreateInfo
    {
        public VkStructureType sType;
        public IntPtr pNext;
        public uint flags;
        public uint queueFamilyIndex;
        public uint queueCount;
        public IntPtr pQueuePriorities;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct VkDeviceCreateInfo
    {
        public VkStructureType sType;
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
    public struct VkSwapchainCreateInfoKHR
    {
        public VkStructureType sType;
        public IntPtr pNext;
        public uint flags;
        public IntPtr surface;
        public uint minImageCount;
        public VkFormat imageFormat;
        public VkColorSpaceKHR imageColorSpace;
        public VkExtent2D imageExtent;
        public uint imageArrayLayers;
        public VkImageUsageFlags imageUsage;
        public VkSharingMode imageSharingMode;
        public uint queueFamilyIndexCount;
        public IntPtr pQueueFamilyIndices;
        public VkSurfaceTransformFlagBitsKHR preTransform;
        public VkCompositeAlphaFlagsKHR compositeAlpha;
        public VkPresentModeKHR presentMode;
        public VkBool32 clipped;
        public IntPtr oldSwapchain;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct VkComponentMapping
    {
        public VkComponentSwizzle r, g, b, a;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct VkImageSubresourceRange
    {
        public VkImageAspectFlags aspectMask;
        public uint baseMipLevel;
        public uint levelCount;
        public uint baseArrayLayer;
        public uint layerCount;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct VkImageViewCreateInfo
    {
        public VkStructureType sType;
        public IntPtr pNext;
        public uint flags;
        public IntPtr image;
        public VkImageViewType viewType;
        public VkFormat format;
        public VkComponentMapping components;
        public VkImageSubresourceRange subresourceRange;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct VkAttachmentDescription
    {
        public uint flags;
        public VkFormat format;
        public VkSampleCountFlags samples;
        public VkAttachmentLoadOp loadOp;
        public VkAttachmentStoreOp storeOp;
        public VkAttachmentLoadOp stencilLoadOp;
        public VkAttachmentStoreOp stencilStoreOp;
        public VkImageLayout initialLayout;
        public VkImageLayout finalLayout;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct VkAttachmentReference
    {
        public uint attachment;
        public VkImageLayout layout;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct VkSubpassDescription
    {
        public uint flags;
        public VkPipelineBindPoint pipelineBindPoint;
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
    public struct VkRenderPassCreateInfo
    {
        public VkStructureType sType;
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
    public struct VkShaderModuleCreateInfo
    {
        public VkStructureType sType;
        public IntPtr pNext;
        public uint flags;
        public UIntPtr codeSize;
        public IntPtr pCode;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct VkPipelineShaderStageCreateInfo
    {
        public VkStructureType sType;
        public IntPtr pNext;
        public uint flags;
        public VkShaderStageFlags stage;
        public IntPtr module;
        public IntPtr pName;
        public IntPtr pSpecializationInfo;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct VkPipelineVertexInputStateCreateInfo
    {
        public VkStructureType sType;
        public IntPtr pNext;
        public uint flags;
        public uint vertexBindingDescriptionCount;
        public IntPtr pVertexBindingDescriptions;
        public uint vertexAttributeDescriptionCount;
        public IntPtr pVertexAttributeDescriptions;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct VkPipelineInputAssemblyStateCreateInfo
    {
        public VkStructureType sType;
        public IntPtr pNext;
        public uint flags;
        public VkPrimitiveTopology topology;
        public VkBool32 primitiveRestartEnable;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct VkViewport
    {
        public float x, y, width, height, minDepth, maxDepth;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct VkPipelineViewportStateCreateInfo
    {
        public VkStructureType sType;
        public IntPtr pNext;
        public uint flags;
        public uint viewportCount;
        public IntPtr pViewports;
        public uint scissorCount;
        public IntPtr pScissors;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct VkPipelineRasterizationStateCreateInfo
    {
        public VkStructureType sType;
        public IntPtr pNext;
        public uint flags;
        public VkBool32 depthClampEnable;
        public VkBool32 rasterizerDiscardEnable;
        public VkPolygonMode polygonMode;
        public VkCullModeFlags cullMode;
        public VkFrontFace frontFace;
        public VkBool32 depthBiasEnable;
        public float depthBiasConstantFactor;
        public float depthBiasClamp;
        public float depthBiasSlopeFactor;
        public float lineWidth;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct VkPipelineMultisampleStateCreateInfo
    {
        public VkStructureType sType;
        public IntPtr pNext;
        public uint flags;
        public VkSampleCountFlags rasterizationSamples;
        public VkBool32 sampleShadingEnable;
        public float minSampleShading;
        public IntPtr pSampleMask;
        public VkBool32 alphaToCoverageEnable;
        public VkBool32 alphaToOneEnable;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct VkPipelineColorBlendAttachmentState
    {
        public VkBool32 blendEnable;
        public uint srcColorBlendFactor;
        public uint dstColorBlendFactor;
        public uint colorBlendOp;
        public uint srcAlphaBlendFactor;
        public uint dstAlphaBlendFactor;
        public uint alphaBlendOp;
        public VkColorComponentFlags colorWriteMask;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct VkPipelineColorBlendStateCreateInfo
    {
        public VkStructureType sType;
        public IntPtr pNext;
        public uint flags;
        public VkBool32 logicOpEnable;
        public uint logicOp;
        public uint attachmentCount;
        public IntPtr pAttachments;
        public float blendConstant0, blendConstant1, blendConstant2, blendConstant3;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct VkPipelineLayoutCreateInfo
    {
        public VkStructureType sType;
        public IntPtr pNext;
        public uint flags;
        public uint setLayoutCount;
        public IntPtr pSetLayouts;
        public uint pushConstantRangeCount;
        public IntPtr pPushConstantRanges;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct VkGraphicsPipelineCreateInfo
    {
        public VkStructureType sType;
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
    public struct VkComputePipelineCreateInfo
    {
        public VkStructureType sType;
        public IntPtr pNext;
        public uint flags;
        public VkPipelineShaderStageCreateInfo stage;
        public IntPtr layout;
        public IntPtr basePipelineHandle;
        public int basePipelineIndex;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct VkFramebufferCreateInfo
    {
        public VkStructureType sType;
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
    public struct VkCommandPoolCreateInfo
    {
        public VkStructureType sType;
        public IntPtr pNext;
        public VkCommandPoolCreateFlags flags;
        public uint queueFamilyIndex;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct VkCommandBufferAllocateInfo
    {
        public VkStructureType sType;
        public IntPtr pNext;
        public IntPtr commandPool;
        public VkCommandBufferLevel level;
        public uint commandBufferCount;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct VkCommandBufferBeginInfo
    {
        public VkStructureType sType;
        public IntPtr pNext;
        public VkCommandBufferUsageFlags flags;
        public IntPtr pInheritanceInfo;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct VkClearColorValue
    {
        public float r;
        public float g;
        public float b;
        public float a;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct VkClearValue
    {
        public VkClearColorValue color;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct VkRenderPassBeginInfo
    {
        public VkStructureType sType;
        public IntPtr pNext;
        public IntPtr renderPass;
        public IntPtr framebuffer;
        public VkRect2D renderArea;
        public uint clearValueCount;
        public IntPtr pClearValues;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct VkSemaphoreCreateInfo
    {
        public VkStructureType sType;
        public IntPtr pNext;
        public uint flags;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct VkFenceCreateInfo
    {
        public VkStructureType sType;
        public IntPtr pNext;
        public VkFenceCreateFlags flags;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct VkSubmitInfo
    {
        public VkStructureType sType;
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
    public struct VkPresentInfoKHR
    {
        public VkStructureType sType;
        public IntPtr pNext;
        public uint waitSemaphoreCount;
        public IntPtr pWaitSemaphores;
        public uint swapchainCount;
        public IntPtr pSwapchains;
        public IntPtr pImageIndices;
        public IntPtr pResults;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct VkBufferCreateInfo
    {
        public VkStructureType sType;
        public IntPtr pNext;
        public uint flags;
        public ulong size;
        public VkBufferUsageFlags usage;
        public VkSharingMode sharingMode;
        public uint queueFamilyIndexCount;
        public IntPtr pQueueFamilyIndices;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct VkMemoryRequirements
    {
        public ulong size;
        public ulong alignment;
        public uint memoryTypeBits;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct VkMemoryAllocateInfo
    {
        public VkStructureType sType;
        public IntPtr pNext;
        public ulong allocationSize;
        public uint memoryTypeIndex;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct VkMemoryType
    {
        public VkMemoryPropertyFlags propertyFlags;
        public uint heapIndex;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct VkMemoryHeap
    {
        public ulong size;
        public uint flags;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct VkPhysicalDeviceMemoryProperties
    {
        public uint memoryTypeCount;
        [MarshalAs(UnmanagedType.ByValArray, SizeConst = 32)]
        public VkMemoryType[] memoryTypes;
        public uint memoryHeapCount;
        [MarshalAs(UnmanagedType.ByValArray, SizeConst = 16)]
        public VkMemoryHeap[] memoryHeaps;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct VkDescriptorSetLayoutBinding
    {
        public uint binding;
        public VkDescriptorType descriptorType;
        public uint descriptorCount;
        public VkShaderStageFlags stageFlags;
        public IntPtr pImmutableSamplers;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct VkDescriptorSetLayoutCreateInfo
    {
        public VkStructureType sType;
        public IntPtr pNext;
        public uint flags;
        public uint bindingCount;
        public IntPtr pBindings;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct VkDescriptorPoolSize
    {
        public VkDescriptorType type;
        public uint descriptorCount;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct VkDescriptorPoolCreateInfo
    {
        public VkStructureType sType;
        public IntPtr pNext;
        public uint flags;
        public uint maxSets;
        public uint poolSizeCount;
        public IntPtr pPoolSizes;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct VkDescriptorSetAllocateInfo
    {
        public VkStructureType sType;
        public IntPtr pNext;
        public IntPtr descriptorPool;
        public uint descriptorSetCount;
        public IntPtr pSetLayouts;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct VkDescriptorBufferInfo
    {
        public IntPtr buffer;
        public ulong offset;
        public ulong range;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct VkWriteDescriptorSet
    {
        public VkStructureType sType;
        public IntPtr pNext;
        public IntPtr dstSet;
        public uint dstBinding;
        public uint dstArrayElement;
        public uint descriptorCount;
        public VkDescriptorType descriptorType;
        public IntPtr pImageInfo;
        public IntPtr pBufferInfo;
        public IntPtr pTexelBufferView;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct VkBufferMemoryBarrier
    {
        public uint sType;  // VkStructureType as uint for blittable
        public IntPtr pNext;
        public uint srcAccessMask;  // VkAccessFlags as uint for blittable
        public uint dstAccessMask;  // VkAccessFlags as uint for blittable
        public uint srcQueueFamilyIndex;
        public uint dstQueueFamilyIndex;
        public IntPtr buffer;
        public ulong offset;
        public ulong size;
    }

    // ========================================================================================================
    // Params UBO (std140)
    // ========================================================================================================
    [StructLayout(LayoutKind.Sequential, Pack = 4)]
    public struct ParamsUBO
    {
        public uint max_num;
        public float dt;
        public float scale;
        public float pad0;
        public float A1, f1, p1, d1;
        public float A2, f2, p2, d2;
        public float A3, f3, p3, d3;
        public float A4, f4, p4, d4;
    }

    // ========================================================================================================
    // Vulkan DllImports
    // ========================================================================================================
    [DllImport("vulkan-1.dll")] static extern VkResult vkCreateInstance(ref VkInstanceCreateInfo pCreateInfo, IntPtr pAllocator, out IntPtr pInstance);
    [DllImport("vulkan-1.dll")] static extern VkResult vkEnumeratePhysicalDevices(IntPtr instance, ref uint deviceCount, IntPtr[] pDevices);
    [DllImport("vulkan-1.dll")] static extern void vkGetPhysicalDeviceQueueFamilyProperties(IntPtr physicalDevice, ref uint pQueueFamilyPropertyCount, [Out] VkQueueFamilyProperties[] pQueueFamilyProperties);
    [DllImport("vulkan-1.dll")] static extern VkResult vkGetPhysicalDeviceSurfaceSupportKHR(IntPtr physicalDevice, uint queueFamilyIndex, IntPtr surface, out VkBool32 pSupported);
    [DllImport("vulkan-1.dll")] static extern VkResult vkCreateWin32SurfaceKHR(IntPtr instance, ref VkWin32SurfaceCreateInfoKHR pCreateInfo, IntPtr pAllocator, out IntPtr pSurface);
    [DllImport("vulkan-1.dll")] static extern VkResult vkGetPhysicalDeviceSurfaceCapabilitiesKHR(IntPtr physicalDevice, IntPtr surface, out VkSurfaceCapabilitiesKHR pSurfaceCapabilities);
    [DllImport("vulkan-1.dll")] static extern VkResult vkGetPhysicalDeviceSurfaceFormatsKHR(IntPtr physicalDevice, IntPtr surface, ref uint pSurfaceFormatCount, [Out] VkSurfaceFormatKHR[] pSurfaceFormats);
    [DllImport("vulkan-1.dll")] static extern VkResult vkCreateDevice(IntPtr physicalDevice, ref VkDeviceCreateInfo pCreateInfo, IntPtr pAllocator, out IntPtr pDevice);
    [DllImport("vulkan-1.dll")] static extern void vkGetDeviceQueue(IntPtr device, uint queueFamilyIndex, uint queueIndex, out IntPtr pQueue);
    [DllImport("vulkan-1.dll")] static extern VkResult vkCreateSwapchainKHR(IntPtr device, ref VkSwapchainCreateInfoKHR pCreateInfo, IntPtr pAllocator, out IntPtr pSwapchain);
    [DllImport("vulkan-1.dll")] static extern VkResult vkGetSwapchainImagesKHR(IntPtr device, IntPtr swapchain, ref uint pSwapchainImageCount, IntPtr pSwapchainImages);
    [DllImport("vulkan-1.dll")] static extern VkResult vkCreateImageView(IntPtr device, ref VkImageViewCreateInfo pCreateInfo, IntPtr pAllocator, out IntPtr pView);
    [DllImport("vulkan-1.dll")] static extern VkResult vkCreateRenderPass(IntPtr device, ref VkRenderPassCreateInfo pCreateInfo, IntPtr pAllocator, out IntPtr pRenderPass);
    [DllImport("vulkan-1.dll")] static extern VkResult vkCreateShaderModule(IntPtr device, ref VkShaderModuleCreateInfo createInfo, IntPtr pAllocator, out IntPtr pShaderModule);
    [DllImport("vulkan-1.dll")] static extern VkResult vkCreatePipelineLayout(IntPtr device, ref VkPipelineLayoutCreateInfo pCreateInfo, IntPtr pAllocator, out IntPtr pPipelineLayout);
    [DllImport("vulkan-1.dll")] static extern VkResult vkCreateGraphicsPipelines(IntPtr device, IntPtr pipelineCache, uint createInfoCount, IntPtr pCreateInfos, IntPtr pAllocator, out IntPtr pPipelines);
    [DllImport("vulkan-1.dll")] static extern VkResult vkCreateComputePipelines(IntPtr device, IntPtr pipelineCache, uint createInfoCount, ref VkComputePipelineCreateInfo pCreateInfos, IntPtr pAllocator, out IntPtr pPipelines);
    [DllImport("vulkan-1.dll")] static extern VkResult vkCreateFramebuffer(IntPtr device, ref VkFramebufferCreateInfo pCreateInfo, IntPtr pAllocator, out IntPtr pFramebuffer);
    [DllImport("vulkan-1.dll")] static extern VkResult vkCreateCommandPool(IntPtr device, ref VkCommandPoolCreateInfo pCreateInfo, IntPtr pAllocator, out IntPtr pCommandPool);
    [DllImport("vulkan-1.dll")] static extern VkResult vkAllocateCommandBuffers(IntPtr device, ref VkCommandBufferAllocateInfo pAllocateInfo, IntPtr[] pCommandBuffers);
    [DllImport("vulkan-1.dll")] static extern VkResult vkCreateSemaphore(IntPtr device, ref VkSemaphoreCreateInfo pCreateInfo, IntPtr pAllocator, out IntPtr pSemaphore);
    [DllImport("vulkan-1.dll")] static extern VkResult vkCreateFence(IntPtr device, ref VkFenceCreateInfo pCreateInfo, IntPtr pAllocator, out IntPtr pFence);
    [DllImport("vulkan-1.dll")] static extern VkResult vkWaitForFences(IntPtr device, uint fenceCount, ref IntPtr pFences, VkBool32 waitAll, ulong timeout);
    [DllImport("vulkan-1.dll")] static extern VkResult vkResetFences(IntPtr device, uint fenceCount, ref IntPtr pFences);
    [DllImport("vulkan-1.dll")] static extern VkResult vkAcquireNextImageKHR(IntPtr device, IntPtr swapchain, ulong timeout, IntPtr semaphore, IntPtr fence, ref uint pImageIndex);
    [DllImport("vulkan-1.dll")] static extern VkResult vkResetCommandBuffer(IntPtr commandBuffer, uint flags);
    [DllImport("vulkan-1.dll")] static extern VkResult vkBeginCommandBuffer(IntPtr commandBuffer, ref VkCommandBufferBeginInfo pBeginInfo);
    [DllImport("vulkan-1.dll")] static extern VkResult vkEndCommandBuffer(IntPtr commandBuffer);
    [DllImport("vulkan-1.dll")] static extern void vkCmdBindPipeline(IntPtr commandBuffer, VkPipelineBindPoint pipelineBindPoint, IntPtr pipeline);
    [DllImport("vulkan-1.dll")] static extern void vkCmdBindDescriptorSets(IntPtr commandBuffer, VkPipelineBindPoint pipelineBindPoint, IntPtr layout, uint firstSet, uint descriptorSetCount, ref IntPtr pDescriptorSets, uint dynamicOffsetCount, IntPtr pDynamicOffsets);
    [DllImport("vulkan-1.dll")] static extern void vkCmdDispatch(IntPtr commandBuffer, uint groupCountX, uint groupCountY, uint groupCountZ);
    [DllImport("vulkan-1.dll")] static extern void vkCmdPipelineBarrier(IntPtr commandBuffer, VkPipelineStageFlags srcStageMask, VkPipelineStageFlags dstStageMask, uint dependencyFlags, uint memoryBarrierCount, IntPtr pMemoryBarriers, uint bufferMemoryBarrierCount, IntPtr pBufferMemoryBarriers, uint imageMemoryBarrierCount, IntPtr pImageMemoryBarriers);
    [DllImport("vulkan-1.dll")] static extern void vkCmdBeginRenderPass(IntPtr commandBuffer, ref VkRenderPassBeginInfo pRenderPassBegin, VkSubpassContents contents);
    [DllImport("vulkan-1.dll")] static extern void vkCmdEndRenderPass(IntPtr commandBuffer);
    [DllImport("vulkan-1.dll")] static extern void vkCmdDraw(IntPtr commandBuffer, uint vertexCount, uint instanceCount, uint firstVertex, uint firstInstance);
    [DllImport("vulkan-1.dll")] static extern VkResult vkQueueSubmit(IntPtr queue, uint submitCount, ref VkSubmitInfo pSubmits, IntPtr fence);
    [DllImport("vulkan-1.dll")] static extern VkResult vkQueuePresentKHR(IntPtr queue, ref VkPresentInfoKHR pPresentInfo);
    [DllImport("vulkan-1.dll")] static extern VkResult vkDeviceWaitIdle(IntPtr device);
    [DllImport("vulkan-1.dll")] static extern VkResult vkCreateBuffer(IntPtr device, ref VkBufferCreateInfo pCreateInfo, IntPtr pAllocator, out IntPtr pBuffer);
    [DllImport("vulkan-1.dll")] static extern void vkGetBufferMemoryRequirements(IntPtr device, IntPtr buffer, out VkMemoryRequirements pMemoryRequirements);
    [DllImport("vulkan-1.dll")] static extern VkResult vkAllocateMemory(IntPtr device, ref VkMemoryAllocateInfo pAllocateInfo, IntPtr pAllocator, out IntPtr pMemory);
    [DllImport("vulkan-1.dll")] static extern VkResult vkBindBufferMemory(IntPtr device, IntPtr buffer, IntPtr memory, ulong memoryOffset);
    [DllImport("vulkan-1.dll")] static extern void vkGetPhysicalDeviceMemoryProperties(IntPtr physicalDevice, out VkPhysicalDeviceMemoryProperties pMemoryProperties);
    [DllImport("vulkan-1.dll")] static extern VkResult vkMapMemory(IntPtr device, IntPtr memory, ulong offset, ulong size, uint flags, out IntPtr ppData);
    [DllImport("vulkan-1.dll")] static extern void vkUnmapMemory(IntPtr device, IntPtr memory);
    [DllImport("vulkan-1.dll")] static extern VkResult vkCreateDescriptorSetLayout(IntPtr device, ref VkDescriptorSetLayoutCreateInfo pCreateInfo, IntPtr pAllocator, out IntPtr pSetLayout);
    [DllImport("vulkan-1.dll")] static extern VkResult vkCreateDescriptorPool(IntPtr device, ref VkDescriptorPoolCreateInfo pCreateInfo, IntPtr pAllocator, out IntPtr pDescriptorPool);
    [DllImport("vulkan-1.dll")] static extern VkResult vkAllocateDescriptorSets(IntPtr device, ref VkDescriptorSetAllocateInfo pAllocateInfo, out IntPtr pDescriptorSets);
    [DllImport("vulkan-1.dll")] static extern void vkUpdateDescriptorSets(IntPtr device, uint descriptorWriteCount, IntPtr pDescriptorWrites, uint descriptorCopyCount, IntPtr pDescriptorCopies);
    [DllImport("vulkan-1.dll")] static extern void vkDestroyInstance(IntPtr instance, IntPtr pAllocator);
    [DllImport("vulkan-1.dll")] static extern void vkDestroyDevice(IntPtr device, IntPtr pAllocator);
    [DllImport("vulkan-1.dll")] static extern void vkDestroySurfaceKHR(IntPtr instance, IntPtr surface, IntPtr pAllocator);
    [DllImport("vulkan-1.dll")] static extern void vkDestroySwapchainKHR(IntPtr device, IntPtr swapchain, IntPtr pAllocator);
    [DllImport("vulkan-1.dll")] static extern void vkDestroyImageView(IntPtr device, IntPtr imageView, IntPtr pAllocator);
    [DllImport("vulkan-1.dll")] static extern void vkDestroyRenderPass(IntPtr device, IntPtr renderPass, IntPtr pAllocator);
    [DllImport("vulkan-1.dll")] static extern void vkDestroyPipeline(IntPtr device, IntPtr pipeline, IntPtr pAllocator);
    [DllImport("vulkan-1.dll")] static extern void vkDestroyPipelineLayout(IntPtr device, IntPtr pipelineLayout, IntPtr pAllocator);
    [DllImport("vulkan-1.dll")] static extern void vkDestroyFramebuffer(IntPtr device, IntPtr framebuffer, IntPtr pAllocator);
    [DllImport("vulkan-1.dll")] static extern void vkDestroyCommandPool(IntPtr device, IntPtr commandPool, IntPtr pAllocator);
    [DllImport("vulkan-1.dll")] static extern void vkDestroySemaphore(IntPtr device, IntPtr semaphore, IntPtr pAllocator);
    [DllImport("vulkan-1.dll")] static extern void vkDestroyFence(IntPtr device, IntPtr fence, IntPtr pAllocator);
    [DllImport("vulkan-1.dll")] static extern void vkDestroyShaderModule(IntPtr device, IntPtr shaderModule, IntPtr pAllocator);
    [DllImport("vulkan-1.dll")] static extern void vkDestroyBuffer(IntPtr device, IntPtr buffer, IntPtr pAllocator);
    [DllImport("vulkan-1.dll")] static extern void vkFreeMemory(IntPtr device, IntPtr memory, IntPtr pAllocator);
    [DllImport("vulkan-1.dll")] static extern void vkDestroyDescriptorPool(IntPtr device, IntPtr descriptorPool, IntPtr pAllocator);
    [DllImport("vulkan-1.dll")] static extern void vkDestroyDescriptorSetLayout(IntPtr device, IntPtr descriptorSetLayout, IntPtr pAllocator);

    // ========================================================================================================
    // Shader Sources
    // ========================================================================================================
    private const string COMP_SHADER_SRC = @"#version 450
layout(local_size_x = 256, local_size_y = 1, local_size_z = 1) in;

layout(std430, binding = 0) buffer Positions { vec4 pos[]; };
layout(std430, binding = 1) buffer Colors    { vec4 col[]; };

layout(std140, binding = 2) uniform Params
{
    uint  max_num;
    float dt;
    float scale;
    float pad0;

    float A1; float f1; float p1; float d1;
    float A2; float f2; float p2; float d2;
    float A3; float f3; float p3; float d3;
    float A4; float f4; float p4; float d4;
} u;

vec3 hsv2rgb(float h, float s, float v)
{
    float c = v * s;
    float hp = h / 60.0;
    float x = c * (1.0 - abs(mod(hp, 2.0) - 1.0));
    vec3 rgb;

    if      (hp < 1.0) rgb = vec3(c, x, 0.0);
    else if (hp < 2.0) rgb = vec3(x, c, 0.0);
    else if (hp < 3.0) rgb = vec3(0.0, c, x);
    else if (hp < 4.0) rgb = vec3(0.0, x, c);
    else if (hp < 5.0) rgb = vec3(x, 0.0, c);
    else               rgb = vec3(c, 0.0, x);

    float m = v - c;
    return rgb + vec3(m);
}

void main()
{
    uint idx = gl_GlobalInvocationID.x;
    if (idx >= u.max_num) return;

    float t  = float(idx) * u.dt;
    float PI = 3.141592653589793;

    float x = u.A1 * sin(u.f1 * t + PI * u.p1) * exp(-u.d1 * t) +
              u.A2 * sin(u.f2 * t + PI * u.p2) * exp(-u.d2 * t);

    float y = u.A3 * sin(u.f3 * t + PI * u.p3) * exp(-u.d3 * t) +
              u.A4 * sin(u.f4 * t + PI * u.p4) * exp(-u.d4 * t);

    vec2 p = vec2(x, y) * u.scale;
    pos[idx] = vec4(p.x, p.y, 0.0, 1.0);

    float hue = mod((t / 20.0) * 360.0, 360.0);
    vec3 rgb  = hsv2rgb(hue, 1.0, 1.0);
    col[idx]  = vec4(rgb, 1.0);
}
";

    private const string VERT_SHADER_SRC = @"#version 450
layout(std430, binding = 0) buffer Positions { vec4 pos[]; };
layout(std430, binding = 1) buffer Colors    { vec4 col[]; };

layout(location = 0) out vec4 vColor;

void main()
{
    uint idx = uint(gl_VertexIndex);
    gl_Position = pos[idx];
    vColor = col[idx];
}
";

    private const string FRAG_SHADER_SRC = @"#version 450
layout(location = 0) in  vec4 vColor;
layout(location = 0) out vec4 outColor;

void main()
{
    outColor = vColor;
}
";

    // ========================================================================================================
    // Constants and Fields
    // ========================================================================================================
    private const int MAX_FRAMES_IN_FLIGHT = 2;
    private const uint VERTEX_COUNT = 500000;

    private IntPtr instance, physicalDevice, device, surface, swapchain, renderPass;
    private IntPtr queue, commandPool;
    private IntPtr computePipeline, computePipelineLayout;
    private IntPtr graphicsPipeline, graphicsPipelineLayout;
    private IntPtr descriptorSetLayout, descriptorPool, descriptorSet;
    private IntPtr posBuffer, posMemory, colBuffer, colMemory, uboBuffer, uboMemory;
    private IntPtr[] swapchainImages, swapchainImageViews, framebuffers, commandBuffers;
    private IntPtr[] imageAvailableSemaphores, renderFinishedSemaphores, inFlightFences;
    private uint queueFamily;
    private VkExtent2D swapchainExtent;
    private VkFormat swapchainFormat;
    private int frameIndex = 0;
    private bool isInitialized = false;
    private ParamsUBO uboParams;
    private float animTime = 0.0f;

    private System.Windows.Forms.Timer renderTimer;

    public HarmonographForm()
    {
        this.Size = new Size(960, 720);
        this.Text = "Vulkan 1.4 Compute Harmonograph (C#)";
        this.SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.UserPaint, true);
        this.DoubleBuffered = false;
    }

    protected override void OnHandleCreated(EventArgs e)
    {
        base.OnHandleCreated(e);
        Initialize();
        isInitialized = true;
        
        // Start render timer
        renderTimer = new System.Windows.Forms.Timer();
        renderTimer.Interval = 16; // ~60 FPS
        renderTimer.Tick += (s, args) => { if (isInitialized) DrawFrame(); };
        renderTimer.Start();
    }

    protected override void OnPaint(PaintEventArgs e)
    {
        // Don't call base - Vulkan handles all rendering
    }

    protected override void OnPaintBackground(PaintEventArgs e)
    {
        // Don't paint background - Vulkan handles it
    }

    protected override void OnResize(EventArgs e)
    {
        base.OnResize(e);
        if (isInitialized && this.WindowState != FormWindowState.Minimized)
        {
            renderTimer?.Stop();
            RecreateSwapchain();
            renderTimer?.Start();
        }
    }

    protected override void OnFormClosing(FormClosingEventArgs e)
    {
        base.OnFormClosing(e);
        renderTimer?.Stop();
        isInitialized = false;
        Cleanup();
    }

    private void Initialize()
    {
        Console.WriteLine("Initializing Vulkan...");
        CreateInstance();
        CreateSurface();
        PickPhysicalDevice();
        CreateDevice();
        CreateSwapchain();
        CreateRenderPass();
        CreateDescriptorSetLayout();
        CreateBuffers();
        CreateDescriptorPool();
        CreateDescriptorSet();
        CompileShaders();
        CreateComputePipeline();
        CreateGraphicsPipeline();
        CreateFramebuffers();
        CreateCommandPool();
        CreateCommandBuffers();
        CreateSyncObjects();
        InitUBO();
        Console.WriteLine("Vulkan initialized.");
    }

    private void CreateInstance()
    {
        var appNamePtr = Marshal.StringToHGlobalAnsi("Harmonograph");
        var engineNamePtr = Marshal.StringToHGlobalAnsi("NoEngine");

        var appInfo = new VkApplicationInfo
        {
            sType = VkStructureType.VK_STRUCTURE_TYPE_APPLICATION_INFO,
            pApplicationName = appNamePtr,
            applicationVersion = 1,
            pEngineName = engineNamePtr,
            engineVersion = 1,
            apiVersion = (1u << 22) | (4u << 12) | 0
        };

        var extensions = new[] { "VK_KHR_surface", "VK_KHR_win32_surface" };
        var extPtrs = extensions.Select(e => Marshal.StringToHGlobalAnsi(e)).ToArray();
        var extPtrsHandle = GCHandle.Alloc(extPtrs, GCHandleType.Pinned);

        var appInfoHandle = GCHandle.Alloc(appInfo, GCHandleType.Pinned);

        var createInfo = new VkInstanceCreateInfo
        {
            sType = VkStructureType.VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
            pApplicationInfo = appInfoHandle.AddrOfPinnedObject(),
            enabledExtensionCount = (uint)extensions.Length,
            ppEnabledExtensionNames = extPtrsHandle.AddrOfPinnedObject()
        };

        var result = vkCreateInstance(ref createInfo, IntPtr.Zero, out instance);
        if (result != VkResult.VK_SUCCESS) throw new Exception($"vkCreateInstance failed: {result}");

        appInfoHandle.Free();
        extPtrsHandle.Free();
        foreach (var p in extPtrs) Marshal.FreeHGlobal(p);
        Marshal.FreeHGlobal(appNamePtr);
        Marshal.FreeHGlobal(engineNamePtr);
    }

    private void CreateSurface()
    {
        var createInfo = new VkWin32SurfaceCreateInfoKHR
        {
            sType = VkStructureType.VK_STRUCTURE_TYPE_WIN32_SURFACE_CREATE_INFO_KHR,
            hinstance = GetModuleHandle(null),
            hwnd = this.Handle
        };
        var result = vkCreateWin32SurfaceKHR(instance, ref createInfo, IntPtr.Zero, out surface);
        if (result != VkResult.VK_SUCCESS) throw new Exception($"vkCreateWin32SurfaceKHR failed: {result}");
    }

    private void PickPhysicalDevice()
    {
        uint count = 0;
        vkEnumeratePhysicalDevices(instance, ref count, null);
        var devices = new IntPtr[count];
        vkEnumeratePhysicalDevices(instance, ref count, devices);

        foreach (var dev in devices)
        {
            uint qCount = 0;
            vkGetPhysicalDeviceQueueFamilyProperties(dev, ref qCount, null);
            var props = new VkQueueFamilyProperties[qCount];
            vkGetPhysicalDeviceQueueFamilyProperties(dev, ref qCount, props);

            for (uint i = 0; i < qCount; i++)
            {
                bool graphics = (props[i].queueFlags & VkQueueFlags.VK_QUEUE_GRAPHICS_BIT) != 0;
                bool compute = (props[i].queueFlags & VkQueueFlags.VK_QUEUE_COMPUTE_BIT) != 0;
                vkGetPhysicalDeviceSurfaceSupportKHR(dev, i, surface, out var presentSupport);

                if (graphics && compute && presentSupport == VkBool32.True)
                {
                    physicalDevice = dev;
                    queueFamily = i;
                    return;
                }
            }
        }
        throw new Exception("No suitable physical device found");
    }

    private void CreateDevice()
    {
        var priority = 1.0f;
        var priorityHandle = GCHandle.Alloc(priority, GCHandleType.Pinned);

        var queueCreateInfo = new VkDeviceQueueCreateInfo
        {
            sType = VkStructureType.VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
            queueFamilyIndex = queueFamily,
            queueCount = 1,
            pQueuePriorities = priorityHandle.AddrOfPinnedObject()
        };
        var queueHandle = GCHandle.Alloc(queueCreateInfo, GCHandleType.Pinned);

        var ext = "VK_KHR_swapchain";
        var extPtr = Marshal.StringToHGlobalAnsi(ext);
        var extPtrHandle = GCHandle.Alloc(extPtr, GCHandleType.Pinned);

        var deviceCreateInfo = new VkDeviceCreateInfo
        {
            sType = VkStructureType.VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO,
            queueCreateInfoCount = 1,
            pQueueCreateInfos = queueHandle.AddrOfPinnedObject(),
            enabledExtensionCount = 1,
            ppEnabledExtensionNames = extPtrHandle.AddrOfPinnedObject()
        };

        var result = vkCreateDevice(physicalDevice, ref deviceCreateInfo, IntPtr.Zero, out device);
        if (result != VkResult.VK_SUCCESS) throw new Exception($"vkCreateDevice failed: {result}");

        vkGetDeviceQueue(device, queueFamily, 0, out queue);

        priorityHandle.Free();
        queueHandle.Free();
        extPtrHandle.Free();
        Marshal.FreeHGlobal(extPtr);
    }

    private void CreateSwapchain()
    {
        vkGetPhysicalDeviceSurfaceCapabilitiesKHR(physicalDevice, surface, out var caps);

        uint formatCount = 0;
        vkGetPhysicalDeviceSurfaceFormatsKHR(physicalDevice, surface, ref formatCount, null);
        var formats = new VkSurfaceFormatKHR[formatCount];
        vkGetPhysicalDeviceSurfaceFormatsKHR(physicalDevice, surface, ref formatCount, formats);

        swapchainFormat = formats[0].format;
        swapchainExtent = caps.currentExtent;
        if (swapchainExtent.width == 0xFFFFFFFF)
        {
            swapchainExtent.width = (uint)ClientSize.Width;
            swapchainExtent.height = (uint)ClientSize.Height;
        }

        uint imageCount = caps.minImageCount + 1;
        if (caps.maxImageCount > 0 && imageCount > caps.maxImageCount) imageCount = caps.maxImageCount;

        var createInfo = new VkSwapchainCreateInfoKHR
        {
            sType = VkStructureType.VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR,
            surface = surface,
            minImageCount = imageCount,
            imageFormat = swapchainFormat,
            imageColorSpace = VkColorSpaceKHR.VK_COLOR_SPACE_SRGB_NONLINEAR_KHR,
            imageExtent = swapchainExtent,
            imageArrayLayers = 1,
            imageUsage = VkImageUsageFlags.VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT,
            imageSharingMode = VkSharingMode.VK_SHARING_MODE_EXCLUSIVE,
            preTransform = caps.currentTransform,
            compositeAlpha = VkCompositeAlphaFlagsKHR.VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR,
            presentMode = VkPresentModeKHR.VK_PRESENT_MODE_FIFO_KHR,
            clipped = VkBool32.True
        };

        vkCreateSwapchainKHR(device, ref createInfo, IntPtr.Zero, out swapchain);

        uint scImageCount = 0;
        vkGetSwapchainImagesKHR(device, swapchain, ref scImageCount, IntPtr.Zero);
        swapchainImages = new IntPtr[scImageCount];
        var imagesHandle = GCHandle.Alloc(swapchainImages, GCHandleType.Pinned);
        vkGetSwapchainImagesKHR(device, swapchain, ref scImageCount, imagesHandle.AddrOfPinnedObject());
        imagesHandle.Free();

        swapchainImageViews = new IntPtr[scImageCount];
        for (int i = 0; i < scImageCount; i++)
        {
            var viewInfo = new VkImageViewCreateInfo
            {
                sType = VkStructureType.VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO,
                image = swapchainImages[i],
                viewType = VkImageViewType.VK_IMAGE_VIEW_TYPE_2D,
                format = swapchainFormat,
                subresourceRange = new VkImageSubresourceRange
                {
                    aspectMask = VkImageAspectFlags.VK_IMAGE_ASPECT_COLOR_BIT,
                    baseMipLevel = 0,
                    levelCount = 1,
                    baseArrayLayer = 0,
                    layerCount = 1
                }
            };
            vkCreateImageView(device, ref viewInfo, IntPtr.Zero, out swapchainImageViews[i]);
        }
    }

    private void CreateRenderPass()
    {
        var colorAttachment = new VkAttachmentDescription
        {
            format = swapchainFormat,
            samples = VkSampleCountFlags.VK_SAMPLE_COUNT_1_BIT,
            loadOp = VkAttachmentLoadOp.VK_ATTACHMENT_LOAD_OP_CLEAR,
            storeOp = VkAttachmentStoreOp.VK_ATTACHMENT_STORE_OP_STORE,
            initialLayout = VkImageLayout.VK_IMAGE_LAYOUT_UNDEFINED,
            finalLayout = VkImageLayout.VK_IMAGE_LAYOUT_PRESENT_SRC_KHR
        };
        var attachHandle = GCHandle.Alloc(colorAttachment, GCHandleType.Pinned);

        var colorRef = new VkAttachmentReference { attachment = 0, layout = VkImageLayout.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL };
        var refHandle = GCHandle.Alloc(colorRef, GCHandleType.Pinned);

        var subpass = new VkSubpassDescription
        {
            pipelineBindPoint = VkPipelineBindPoint.VK_PIPELINE_BIND_POINT_GRAPHICS,
            colorAttachmentCount = 1,
            pColorAttachments = refHandle.AddrOfPinnedObject()
        };
        var subpassHandle = GCHandle.Alloc(subpass, GCHandleType.Pinned);

        var rpInfo = new VkRenderPassCreateInfo
        {
            sType = VkStructureType.VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO,
            attachmentCount = 1,
            pAttachments = attachHandle.AddrOfPinnedObject(),
            subpassCount = 1,
            pSubpasses = subpassHandle.AddrOfPinnedObject()
        };

        vkCreateRenderPass(device, ref rpInfo, IntPtr.Zero, out renderPass);

        attachHandle.Free();
        refHandle.Free();
        subpassHandle.Free();
    }

    private void CreateDescriptorSetLayout()
    {
        var bindings = new VkDescriptorSetLayoutBinding[]
        {
            new VkDescriptorSetLayoutBinding { binding = 0, descriptorType = VkDescriptorType.VK_DESCRIPTOR_TYPE_STORAGE_BUFFER, descriptorCount = 1, stageFlags = VkShaderStageFlags.VK_SHADER_STAGE_COMPUTE_BIT | VkShaderStageFlags.VK_SHADER_STAGE_VERTEX_BIT },
            new VkDescriptorSetLayoutBinding { binding = 1, descriptorType = VkDescriptorType.VK_DESCRIPTOR_TYPE_STORAGE_BUFFER, descriptorCount = 1, stageFlags = VkShaderStageFlags.VK_SHADER_STAGE_COMPUTE_BIT | VkShaderStageFlags.VK_SHADER_STAGE_VERTEX_BIT },
            new VkDescriptorSetLayoutBinding { binding = 2, descriptorType = VkDescriptorType.VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER, descriptorCount = 1, stageFlags = VkShaderStageFlags.VK_SHADER_STAGE_COMPUTE_BIT }
        };
        var bindHandle = GCHandle.Alloc(bindings, GCHandleType.Pinned);

        var layoutInfo = new VkDescriptorSetLayoutCreateInfo
        {
            sType = VkStructureType.VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
            bindingCount = (uint)bindings.Length,
            pBindings = bindHandle.AddrOfPinnedObject()
        };
        vkCreateDescriptorSetLayout(device, ref layoutInfo, IntPtr.Zero, out descriptorSetLayout);
        bindHandle.Free();
    }

    private uint FindMemoryType(uint typeFilter, VkMemoryPropertyFlags properties)
    {
        vkGetPhysicalDeviceMemoryProperties(physicalDevice, out var memProps);
        for (uint i = 0; i < memProps.memoryTypeCount; i++)
        {
            if ((typeFilter & (1u << (int)i)) != 0 && (memProps.memoryTypes[i].propertyFlags & properties) == properties)
                return i;
        }
        throw new Exception("No suitable memory type");
    }

    private (IntPtr buffer, IntPtr memory) CreateBuffer(ulong size, VkBufferUsageFlags usage, VkMemoryPropertyFlags memProps)
    {
        var bufInfo = new VkBufferCreateInfo
        {
            sType = VkStructureType.VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO,
            size = size,
            usage = usage,
            sharingMode = VkSharingMode.VK_SHARING_MODE_EXCLUSIVE
        };
        vkCreateBuffer(device, ref bufInfo, IntPtr.Zero, out var buffer);
        vkGetBufferMemoryRequirements(device, buffer, out var memReq);

        var allocInfo = new VkMemoryAllocateInfo
        {
            sType = VkStructureType.VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
            allocationSize = memReq.size,
            memoryTypeIndex = FindMemoryType(memReq.memoryTypeBits, memProps)
        };
        vkAllocateMemory(device, ref allocInfo, IntPtr.Zero, out var memory);
        vkBindBufferMemory(device, buffer, memory, 0);

        return (buffer, memory);
    }

    private void CreateBuffers()
    {
        ulong posSize = VERTEX_COUNT * 16;
        ulong colSize = VERTEX_COUNT * 16;
        ulong uboSize = (ulong)Marshal.SizeOf<ParamsUBO>();

        (posBuffer, posMemory) = CreateBuffer(posSize, VkBufferUsageFlags.VK_BUFFER_USAGE_STORAGE_BUFFER_BIT, VkMemoryPropertyFlags.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT);
        (colBuffer, colMemory) = CreateBuffer(colSize, VkBufferUsageFlags.VK_BUFFER_USAGE_STORAGE_BUFFER_BIT, VkMemoryPropertyFlags.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT);
        (uboBuffer, uboMemory) = CreateBuffer(uboSize, VkBufferUsageFlags.VK_BUFFER_USAGE_UNIFORM_BUFFER_BIT, VkMemoryPropertyFlags.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | VkMemoryPropertyFlags.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT);
    }

    private void CreateDescriptorPool()
    {
        var poolSizes = new VkDescriptorPoolSize[]
        {
            new VkDescriptorPoolSize { type = VkDescriptorType.VK_DESCRIPTOR_TYPE_STORAGE_BUFFER, descriptorCount = 2 },
            new VkDescriptorPoolSize { type = VkDescriptorType.VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER, descriptorCount = 1 }
        };
        var poolHandle = GCHandle.Alloc(poolSizes, GCHandleType.Pinned);

        var poolInfo = new VkDescriptorPoolCreateInfo
        {
            sType = VkStructureType.VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO,
            maxSets = 1,
            poolSizeCount = (uint)poolSizes.Length,
            pPoolSizes = poolHandle.AddrOfPinnedObject()
        };
        vkCreateDescriptorPool(device, ref poolInfo, IntPtr.Zero, out descriptorPool);
        poolHandle.Free();
    }

    private void CreateDescriptorSet()
    {
        var layoutHandle = GCHandle.Alloc(descriptorSetLayout, GCHandleType.Pinned);
        var allocInfo = new VkDescriptorSetAllocateInfo
        {
            sType = VkStructureType.VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO,
            descriptorPool = descriptorPool,
            descriptorSetCount = 1,
            pSetLayouts = layoutHandle.AddrOfPinnedObject()
        };
        vkAllocateDescriptorSets(device, ref allocInfo, out descriptorSet);
        layoutHandle.Free();

        var posInfo = new VkDescriptorBufferInfo { buffer = posBuffer, offset = 0, range = VERTEX_COUNT * 16 };
        var colInfo = new VkDescriptorBufferInfo { buffer = colBuffer, offset = 0, range = VERTEX_COUNT * 16 };
        var uboInfo = new VkDescriptorBufferInfo { buffer = uboBuffer, offset = 0, range = (ulong)Marshal.SizeOf<ParamsUBO>() };

        var posInfoHandle = GCHandle.Alloc(posInfo, GCHandleType.Pinned);
        var colInfoHandle = GCHandle.Alloc(colInfo, GCHandleType.Pinned);
        var uboInfoHandle = GCHandle.Alloc(uboInfo, GCHandleType.Pinned);

        var writes = new VkWriteDescriptorSet[]
        {
            new VkWriteDescriptorSet { sType = VkStructureType.VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET, dstSet = descriptorSet, dstBinding = 0, descriptorCount = 1, descriptorType = VkDescriptorType.VK_DESCRIPTOR_TYPE_STORAGE_BUFFER, pBufferInfo = posInfoHandle.AddrOfPinnedObject() },
            new VkWriteDescriptorSet { sType = VkStructureType.VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET, dstSet = descriptorSet, dstBinding = 1, descriptorCount = 1, descriptorType = VkDescriptorType.VK_DESCRIPTOR_TYPE_STORAGE_BUFFER, pBufferInfo = colInfoHandle.AddrOfPinnedObject() },
            new VkWriteDescriptorSet { sType = VkStructureType.VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET, dstSet = descriptorSet, dstBinding = 2, descriptorCount = 1, descriptorType = VkDescriptorType.VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER, pBufferInfo = uboInfoHandle.AddrOfPinnedObject() }
        };
        var writesHandle = GCHandle.Alloc(writes, GCHandleType.Pinned);
        vkUpdateDescriptorSets(device, (uint)writes.Length, writesHandle.AddrOfPinnedObject(), 0, IntPtr.Zero);

        writesHandle.Free();
        posInfoHandle.Free();
        colInfoHandle.Free();
        uboInfoHandle.Free();
    }

    private IntPtr compShaderModule, vertShaderModule, fragShaderModule;

    private void CompileShaders()
    {
        var compSpv = ShaderCompiler.Compile(COMP_SHADER_SRC, ShaderCompiler.ShaderKind.Compute, "harmonograph.comp");
        var vertSpv = ShaderCompiler.Compile(VERT_SHADER_SRC, ShaderCompiler.ShaderKind.Vertex, "harmonograph.vert");
        var fragSpv = ShaderCompiler.Compile(FRAG_SHADER_SRC, ShaderCompiler.ShaderKind.Fragment, "harmonograph.frag");

        compShaderModule = CreateShaderModule(compSpv);
        vertShaderModule = CreateShaderModule(vertSpv);
        fragShaderModule = CreateShaderModule(fragSpv);
    }

    private IntPtr CreateShaderModule(byte[] code)
    {
        var codeHandle = GCHandle.Alloc(code, GCHandleType.Pinned);
        var createInfo = new VkShaderModuleCreateInfo
        {
            sType = VkStructureType.VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO,
            codeSize = (UIntPtr)code.Length,
            pCode = codeHandle.AddrOfPinnedObject()
        };
        vkCreateShaderModule(device, ref createInfo, IntPtr.Zero, out var module);
        codeHandle.Free();
        return module;
    }

    private void CreateComputePipeline()
    {
        var layoutHandle = GCHandle.Alloc(descriptorSetLayout, GCHandleType.Pinned);
        var layoutInfo = new VkPipelineLayoutCreateInfo
        {
            sType = VkStructureType.VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO,
            setLayoutCount = 1,
            pSetLayouts = layoutHandle.AddrOfPinnedObject()
        };
        vkCreatePipelineLayout(device, ref layoutInfo, IntPtr.Zero, out computePipelineLayout);
        layoutHandle.Free();

        var mainPtr = Marshal.StringToHGlobalAnsi("main");
        var stageInfo = new VkPipelineShaderStageCreateInfo
        {
            sType = VkStructureType.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
            stage = VkShaderStageFlags.VK_SHADER_STAGE_COMPUTE_BIT,
            module = compShaderModule,
            pName = mainPtr
        };

        var pipelineInfo = new VkComputePipelineCreateInfo
        {
            sType = VkStructureType.VK_STRUCTURE_TYPE_COMPUTE_PIPELINE_CREATE_INFO,
            stage = stageInfo,
            layout = computePipelineLayout,
            basePipelineIndex = -1
        };

        vkCreateComputePipelines(device, IntPtr.Zero, 1, ref pipelineInfo, IntPtr.Zero, out computePipeline);
        Marshal.FreeHGlobal(mainPtr);
    }

    private void CreateGraphicsPipeline()
    {
        var layoutHandle = GCHandle.Alloc(descriptorSetLayout, GCHandleType.Pinned);
        var layoutInfo = new VkPipelineLayoutCreateInfo
        {
            sType = VkStructureType.VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO,
            setLayoutCount = 1,
            pSetLayouts = layoutHandle.AddrOfPinnedObject()
        };
        vkCreatePipelineLayout(device, ref layoutInfo, IntPtr.Zero, out graphicsPipelineLayout);
        layoutHandle.Free();

        var mainPtr = Marshal.StringToHGlobalAnsi("main");

        var stages = new VkPipelineShaderStageCreateInfo[]
        {
            new VkPipelineShaderStageCreateInfo { sType = VkStructureType.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO, stage = VkShaderStageFlags.VK_SHADER_STAGE_VERTEX_BIT, module = vertShaderModule, pName = mainPtr },
            new VkPipelineShaderStageCreateInfo { sType = VkStructureType.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO, stage = VkShaderStageFlags.VK_SHADER_STAGE_FRAGMENT_BIT, module = fragShaderModule, pName = mainPtr }
        };
        var stagesHandle = GCHandle.Alloc(stages, GCHandleType.Pinned);

        var vertexInput = new VkPipelineVertexInputStateCreateInfo { sType = VkStructureType.VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO };
        var inputAssembly = new VkPipelineInputAssemblyStateCreateInfo { sType = VkStructureType.VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO, topology = VkPrimitiveTopology.VK_PRIMITIVE_TOPOLOGY_LINE_STRIP };

        var viewport = new VkViewport { x = 0, y = 0, width = swapchainExtent.width, height = swapchainExtent.height, minDepth = 0, maxDepth = 1 };
        var scissor = new VkRect2D { extent = swapchainExtent };
        var viewportHandle = GCHandle.Alloc(viewport, GCHandleType.Pinned);
        var scissorHandle = GCHandle.Alloc(scissor, GCHandleType.Pinned);

        var viewportState = new VkPipelineViewportStateCreateInfo
        {
            sType = VkStructureType.VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO,
            viewportCount = 1,
            pViewports = viewportHandle.AddrOfPinnedObject(),
            scissorCount = 1,
            pScissors = scissorHandle.AddrOfPinnedObject()
        };

        var rasterizer = new VkPipelineRasterizationStateCreateInfo
        {
            sType = VkStructureType.VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO,
            polygonMode = VkPolygonMode.VK_POLYGON_MODE_FILL,
            cullMode = VkCullModeFlags.VK_CULL_MODE_NONE,
            frontFace = VkFrontFace.VK_FRONT_FACE_COUNTER_CLOCKWISE,
            lineWidth = 1.0f
        };

        var multisampling = new VkPipelineMultisampleStateCreateInfo
        {
            sType = VkStructureType.VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO,
            rasterizationSamples = VkSampleCountFlags.VK_SAMPLE_COUNT_1_BIT
        };

        var colorBlendAttachment = new VkPipelineColorBlendAttachmentState
        {
            colorWriteMask = VkColorComponentFlags.VK_COLOR_COMPONENT_R_BIT | VkColorComponentFlags.VK_COLOR_COMPONENT_G_BIT | VkColorComponentFlags.VK_COLOR_COMPONENT_B_BIT | VkColorComponentFlags.VK_COLOR_COMPONENT_A_BIT
        };
        var cbaHandle = GCHandle.Alloc(colorBlendAttachment, GCHandleType.Pinned);

        var colorBlending = new VkPipelineColorBlendStateCreateInfo
        {
            sType = VkStructureType.VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO,
            attachmentCount = 1,
            pAttachments = cbaHandle.AddrOfPinnedObject()
        };

        var viHandle = GCHandle.Alloc(vertexInput, GCHandleType.Pinned);
        var iaHandle = GCHandle.Alloc(inputAssembly, GCHandleType.Pinned);
        var vpHandle = GCHandle.Alloc(viewportState, GCHandleType.Pinned);
        var rsHandle = GCHandle.Alloc(rasterizer, GCHandleType.Pinned);
        var msHandle = GCHandle.Alloc(multisampling, GCHandleType.Pinned);
        var cbHandle = GCHandle.Alloc(colorBlending, GCHandleType.Pinned);

        var pipelineInfo = new VkGraphicsPipelineCreateInfo
        {
            sType = VkStructureType.VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO,
            stageCount = 2,
            pStages = stagesHandle.AddrOfPinnedObject(),
            pVertexInputState = viHandle.AddrOfPinnedObject(),
            pInputAssemblyState = iaHandle.AddrOfPinnedObject(),
            pViewportState = vpHandle.AddrOfPinnedObject(),
            pRasterizationState = rsHandle.AddrOfPinnedObject(),
            pMultisampleState = msHandle.AddrOfPinnedObject(),
            pColorBlendState = cbHandle.AddrOfPinnedObject(),
            layout = graphicsPipelineLayout,
            renderPass = renderPass,
            basePipelineIndex = -1
        };

        var pipelineInfoHandle = GCHandle.Alloc(pipelineInfo, GCHandleType.Pinned);
        vkCreateGraphicsPipelines(device, IntPtr.Zero, 1, pipelineInfoHandle.AddrOfPinnedObject(), IntPtr.Zero, out graphicsPipeline);

        pipelineInfoHandle.Free();
        stagesHandle.Free();
        viewportHandle.Free();
        scissorHandle.Free();
        cbaHandle.Free();
        viHandle.Free();
        iaHandle.Free();
        vpHandle.Free();
        rsHandle.Free();
        msHandle.Free();
        cbHandle.Free();
        Marshal.FreeHGlobal(mainPtr);
    }

    private void CreateFramebuffers()
    {
        framebuffers = new IntPtr[swapchainImageViews.Length];
        for (int i = 0; i < swapchainImageViews.Length; i++)
        {
            var attachHandle = GCHandle.Alloc(swapchainImageViews[i], GCHandleType.Pinned);
            var fbInfo = new VkFramebufferCreateInfo
            {
                sType = VkStructureType.VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO,
                renderPass = renderPass,
                attachmentCount = 1,
                pAttachments = attachHandle.AddrOfPinnedObject(),
                width = swapchainExtent.width,
                height = swapchainExtent.height,
                layers = 1
            };
            vkCreateFramebuffer(device, ref fbInfo, IntPtr.Zero, out framebuffers[i]);
            attachHandle.Free();
        }
    }

    private void CreateCommandPool()
    {
        var poolInfo = new VkCommandPoolCreateInfo
        {
            sType = VkStructureType.VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO,
            flags = VkCommandPoolCreateFlags.VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT,
            queueFamilyIndex = queueFamily
        };
        vkCreateCommandPool(device, ref poolInfo, IntPtr.Zero, out commandPool);
    }

    private void CreateCommandBuffers()
    {
        commandBuffers = new IntPtr[MAX_FRAMES_IN_FLIGHT];
        var allocInfo = new VkCommandBufferAllocateInfo
        {
            sType = VkStructureType.VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
            commandPool = commandPool,
            level = VkCommandBufferLevel.VK_COMMAND_BUFFER_LEVEL_PRIMARY,
            commandBufferCount = MAX_FRAMES_IN_FLIGHT
        };
        vkAllocateCommandBuffers(device, ref allocInfo, commandBuffers);
    }

    private void CreateSyncObjects()
    {
        imageAvailableSemaphores = new IntPtr[MAX_FRAMES_IN_FLIGHT];
        renderFinishedSemaphores = new IntPtr[MAX_FRAMES_IN_FLIGHT];
        inFlightFences = new IntPtr[MAX_FRAMES_IN_FLIGHT];

        var semInfo = new VkSemaphoreCreateInfo { sType = VkStructureType.VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO };
        var fenceInfo = new VkFenceCreateInfo { sType = VkStructureType.VK_STRUCTURE_TYPE_FENCE_CREATE_INFO, flags = VkFenceCreateFlags.VK_FENCE_CREATE_SIGNALED_BIT };

        for (int i = 0; i < MAX_FRAMES_IN_FLIGHT; i++)
        {
            vkCreateSemaphore(device, ref semInfo, IntPtr.Zero, out imageAvailableSemaphores[i]);
            vkCreateSemaphore(device, ref semInfo, IntPtr.Zero, out renderFinishedSemaphores[i]);
            vkCreateFence(device, ref fenceInfo, IntPtr.Zero, out inFlightFences[i]);
        }
    }

    private void InitUBO()
    {
        uboParams = new ParamsUBO
        {
            max_num = VERTEX_COUNT,
            dt = 0.001f,
            scale = 0.02f,
            A1 = 50f, f1 = 2f, p1 = 1f / 16f, d1 = 0.02f,
            A2 = 50f, f2 = 2f, p2 = 3f / 2f, d2 = 0.0315f,
            A3 = 50f, f3 = 2f, p3 = 13f / 15f, d3 = 0.02f,
            A4 = 50f, f4 = 2f, p4 = 1f, d4 = 0.02f
        };
    }

    private void UpdateUBO()
    {
        animTime += 0.016f;
        uboParams.f1 = 2.0f + 0.5f * (float)Math.Sin(animTime * 0.7);
        uboParams.f2 = 2.0f + 0.5f * (float)Math.Sin(animTime * 0.9);
        uboParams.f3 = 2.0f + 0.5f * (float)Math.Sin(animTime * 1.1);
        uboParams.f4 = 2.0f + 0.5f * (float)Math.Sin(animTime * 1.3);
        uboParams.p1 += 0.002f;

        vkMapMemory(device, uboMemory, 0, (ulong)Marshal.SizeOf<ParamsUBO>(), 0, out var data);
        Marshal.StructureToPtr(uboParams, data, false);
        vkUnmapMemory(device, uboMemory);
    }

    private void DrawFrame()
    {
        int cur = frameIndex % MAX_FRAMES_IN_FLIGHT;

        vkWaitForFences(device, 1, ref inFlightFences[cur], VkBool32.True, ulong.MaxValue);
        vkResetFences(device, 1, ref inFlightFences[cur]);

        uint imageIndex = 0;
        var result = vkAcquireNextImageKHR(device, swapchain, ulong.MaxValue, imageAvailableSemaphores[cur], IntPtr.Zero, ref imageIndex);
        if (result == VkResult.VK_ERROR_OUT_OF_DATE_KHR) { RecreateSwapchain(); return; }

        UpdateUBO();

        var cmd = commandBuffers[cur];
        vkResetCommandBuffer(cmd, 0);

        var beginInfo = new VkCommandBufferBeginInfo { sType = VkStructureType.VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO };
        vkBeginCommandBuffer(cmd, ref beginInfo);

        // Compute
        vkCmdBindPipeline(cmd, VkPipelineBindPoint.VK_PIPELINE_BIND_POINT_COMPUTE, computePipeline);
        vkCmdBindDescriptorSets(cmd, VkPipelineBindPoint.VK_PIPELINE_BIND_POINT_COMPUTE, computePipelineLayout, 0, 1, ref descriptorSet, 0, IntPtr.Zero);
        vkCmdDispatch(cmd, (VERTEX_COUNT + 255) / 256, 1, 1);

        // Barrier
        var barriers = new VkBufferMemoryBarrier[]
        {
            new VkBufferMemoryBarrier { sType = (uint)VkStructureType.VK_STRUCTURE_TYPE_BUFFER_MEMORY_BARRIER, srcAccessMask = (uint)VkAccessFlags.VK_ACCESS_SHADER_WRITE_BIT, dstAccessMask = (uint)VkAccessFlags.VK_ACCESS_SHADER_READ_BIT, srcQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED, dstQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED, buffer = posBuffer, size = VERTEX_COUNT * 16 },
            new VkBufferMemoryBarrier { sType = (uint)VkStructureType.VK_STRUCTURE_TYPE_BUFFER_MEMORY_BARRIER, srcAccessMask = (uint)VkAccessFlags.VK_ACCESS_SHADER_WRITE_BIT, dstAccessMask = (uint)VkAccessFlags.VK_ACCESS_SHADER_READ_BIT, srcQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED, dstQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED, buffer = colBuffer, size = VERTEX_COUNT * 16 }
        };
        var barrierHandle = GCHandle.Alloc(barriers, GCHandleType.Pinned);
        vkCmdPipelineBarrier(cmd, VkPipelineStageFlags.VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT, VkPipelineStageFlags.VK_PIPELINE_STAGE_VERTEX_SHADER_BIT, 0, 0, IntPtr.Zero, 2, barrierHandle.AddrOfPinnedObject(), 0, IntPtr.Zero);
        barrierHandle.Free();

        // Render pass
        var clearValues = new VkClearValue[]
        {
            new VkClearValue { color = new VkClearColorValue { r = 0f, g = 0f, b = 0f, a = 1f } }
        };
        var clearHandle = GCHandle.Alloc(clearValues, GCHandleType.Pinned);

        var rpBeginInfo = new VkRenderPassBeginInfo
        {
            sType = VkStructureType.VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO,
            renderPass = renderPass,
            framebuffer = framebuffers[imageIndex],
            renderArea = new VkRect2D { extent = swapchainExtent },
            clearValueCount = 1,
            pClearValues = clearHandle.AddrOfPinnedObject()
        };
        vkCmdBeginRenderPass(cmd, ref rpBeginInfo, VkSubpassContents.VK_SUBPASS_CONTENTS_INLINE);
        clearHandle.Free();

        vkCmdBindPipeline(cmd, VkPipelineBindPoint.VK_PIPELINE_BIND_POINT_GRAPHICS, graphicsPipeline);
        vkCmdBindDescriptorSets(cmd, VkPipelineBindPoint.VK_PIPELINE_BIND_POINT_GRAPHICS, graphicsPipelineLayout, 0, 1, ref descriptorSet, 0, IntPtr.Zero);
        vkCmdDraw(cmd, VERTEX_COUNT, 1, 0, 0);

        vkCmdEndRenderPass(cmd);
        vkEndCommandBuffer(cmd);

        // Submit
        var waitStages = new uint[] { (uint)VkPipelineStageFlags.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT };
        var waitStageHandle = GCHandle.Alloc(waitStages, GCHandleType.Pinned);
        var cmdBuffers = new IntPtr[] { cmd };
        var cmdHandle = GCHandle.Alloc(cmdBuffers, GCHandleType.Pinned);

        var submitInfo = new VkSubmitInfo
        {
            sType = VkStructureType.VK_STRUCTURE_TYPE_SUBMIT_INFO,
            waitSemaphoreCount = 1,
            pWaitSemaphores = Marshal.UnsafeAddrOfPinnedArrayElement(imageAvailableSemaphores, cur),
            pWaitDstStageMask = waitStageHandle.AddrOfPinnedObject(),
            commandBufferCount = 1,
            pCommandBuffers = cmdHandle.AddrOfPinnedObject(),
            signalSemaphoreCount = 1,
            pSignalSemaphores = Marshal.UnsafeAddrOfPinnedArrayElement(renderFinishedSemaphores, cur)
        };
        vkQueueSubmit(queue, 1, ref submitInfo, inFlightFences[cur]);
        waitStageHandle.Free();
        cmdHandle.Free();

        // Present
        var swapchains = new IntPtr[] { swapchain };
        var scHandle = GCHandle.Alloc(swapchains, GCHandleType.Pinned);
        var imageIndices = new uint[] { imageIndex };
        var idxHandle = GCHandle.Alloc(imageIndices, GCHandleType.Pinned);

        var presentInfo = new VkPresentInfoKHR
        {
            sType = VkStructureType.VK_STRUCTURE_TYPE_PRESENT_INFO_KHR,
            waitSemaphoreCount = 1,
            pWaitSemaphores = Marshal.UnsafeAddrOfPinnedArrayElement(renderFinishedSemaphores, cur),
            swapchainCount = 1,
            pSwapchains = scHandle.AddrOfPinnedObject(),
            pImageIndices = idxHandle.AddrOfPinnedObject()
        };
        result = vkQueuePresentKHR(queue, ref presentInfo);
        scHandle.Free();
        idxHandle.Free();

        if (result == VkResult.VK_ERROR_OUT_OF_DATE_KHR || result == VkResult.VK_SUBOPTIMAL_KHR)
            RecreateSwapchain();

        frameIndex++;
    }

    private void RecreateSwapchain()
    {
        vkDeviceWaitIdle(device);

        foreach (var fb in framebuffers) vkDestroyFramebuffer(device, fb, IntPtr.Zero);
        vkDestroyPipeline(device, graphicsPipeline, IntPtr.Zero);
        vkDestroyPipelineLayout(device, graphicsPipelineLayout, IntPtr.Zero);
        foreach (var iv in swapchainImageViews) vkDestroyImageView(device, iv, IntPtr.Zero);
        vkDestroySwapchainKHR(device, swapchain, IntPtr.Zero);

        CreateSwapchain();
        CreateGraphicsPipeline();
        CreateFramebuffers();
    }

    private void Cleanup()
    {
        vkDeviceWaitIdle(device);

        vkDestroyBuffer(device, posBuffer, IntPtr.Zero);
        vkFreeMemory(device, posMemory, IntPtr.Zero);
        vkDestroyBuffer(device, colBuffer, IntPtr.Zero);
        vkFreeMemory(device, colMemory, IntPtr.Zero);
        vkDestroyBuffer(device, uboBuffer, IntPtr.Zero);
        vkFreeMemory(device, uboMemory, IntPtr.Zero);

        vkDestroyDescriptorPool(device, descriptorPool, IntPtr.Zero);
        vkDestroyDescriptorSetLayout(device, descriptorSetLayout, IntPtr.Zero);

        for (int i = 0; i < MAX_FRAMES_IN_FLIGHT; i++)
        {
            vkDestroySemaphore(device, imageAvailableSemaphores[i], IntPtr.Zero);
            vkDestroySemaphore(device, renderFinishedSemaphores[i], IntPtr.Zero);
            vkDestroyFence(device, inFlightFences[i], IntPtr.Zero);
        }

        vkDestroyCommandPool(device, commandPool, IntPtr.Zero);

        vkDestroyPipeline(device, computePipeline, IntPtr.Zero);
        vkDestroyPipelineLayout(device, computePipelineLayout, IntPtr.Zero);
        vkDestroyPipeline(device, graphicsPipeline, IntPtr.Zero);
        vkDestroyPipelineLayout(device, graphicsPipelineLayout, IntPtr.Zero);

        vkDestroyShaderModule(device, compShaderModule, IntPtr.Zero);
        vkDestroyShaderModule(device, vertShaderModule, IntPtr.Zero);
        vkDestroyShaderModule(device, fragShaderModule, IntPtr.Zero);

        foreach (var fb in framebuffers) vkDestroyFramebuffer(device, fb, IntPtr.Zero);
        vkDestroyRenderPass(device, renderPass, IntPtr.Zero);
        foreach (var iv in swapchainImageViews) vkDestroyImageView(device, iv, IntPtr.Zero);
        vkDestroySwapchainKHR(device, swapchain, IntPtr.Zero);

        vkDestroyDevice(device, IntPtr.Zero);
        vkDestroySurfaceKHR(instance, surface, IntPtr.Zero);
        vkDestroyInstance(instance, IntPtr.Zero);
    }

    [STAThread]
    static void Main()
    {
        Application.Run(new HarmonographForm());
    }
}
