using System;
using System.Drawing;
using System.Windows.Forms;
using System.Runtime.InteropServices;
using System.IO;
using System.Collections.Generic;
using System.Linq;
using System.Diagnostics;

class HelloForm : Form
{
    [DllImport("kernel32.dll", CharSet = CharSet.Auto)]
    private static extern IntPtr GetModuleHandle(string lpModuleName);

    [DllImport("kernel32.dll")]
    private static extern IntPtr LoadLibrary(string dllToLoad);

    [DllImport("kernel32.dll")]
    static extern uint GetLastError();

    delegate IntPtr WndProcDelegate(IntPtr hWnd, uint uMsg, IntPtr wParam, IntPtr lParam);

    public enum VkPhysicalDeviceType
    {
        VK_PHYSICAL_DEVICE_TYPE_OTHER = 0,
        VK_PHYSICAL_DEVICE_TYPE_INTEGRATED_GPU = 1,
        VK_PHYSICAL_DEVICE_TYPE_DISCRETE_GPU = 2,
        VK_PHYSICAL_DEVICE_TYPE_VIRTUAL_GPU = 3,
        VK_PHYSICAL_DEVICE_TYPE_CPU = 4
    }

    public enum VkDebugUtilsMessageSeverityFlagsEXT : uint
    {
        VK_DEBUG_UTILS_MESSAGE_SEVERITY_VERBOSE_BIT_EXT = 0x00000001,
        VK_DEBUG_UTILS_MESSAGE_SEVERITY_INFO_BIT_EXT = 0x00000010,
        VK_DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT = 0x00000100,
        VK_DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT = 0x00001000
    }

    public enum VkDebugUtilsMessageTypeFlagsEXT : uint
    {
        VK_DEBUG_UTILS_MESSAGE_TYPE_GENERAL_BIT_EXT = 0x00000001,
        VK_DEBUG_UTILS_MESSAGE_TYPE_VALIDATION_BIT_EXT = 0x00000002,
        VK_DEBUG_UTILS_MESSAGE_TYPE_PERFORMANCE_BIT_EXT = 0x00000004
    }

    public enum VkStructureType : uint
    {
        VK_STRUCTURE_TYPE_APPLICATION_INFO = 0,
        VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO = 1,
        VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO = 2,
        VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO = 3,
        VK_STRUCTURE_TYPE_SUBMIT_INFO = 4,
        VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO = 5,
        VK_STRUCTURE_TYPE_MAPPED_MEMORY_RANGE = 6,
        VK_STRUCTURE_TYPE_BIND_SPARSE_INFO = 7,
        VK_STRUCTURE_TYPE_FENCE_CREATE_INFO = 8,
        VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO = 9,
        VK_STRUCTURE_TYPE_EVENT_CREATE_INFO = 10,
        VK_STRUCTURE_TYPE_QUERY_POOL_CREATE_INFO = 11,
        VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO = 12,
        VK_STRUCTURE_TYPE_BUFFER_VIEW_CREATE_INFO = 13,
        VK_STRUCTURE_TYPE_IMAGE_CREATE_INFO = 14,
        VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO = 15,
        VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO = 16,
        VK_STRUCTURE_TYPE_PIPELINE_CACHE_CREATE_INFO = 17,
        VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO = 18,
        VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO = 19,
        VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO = 20,
        VK_STRUCTURE_TYPE_PIPELINE_TESSELLATION_STATE_CREATE_INFO = 21,
        VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO = 22,
        VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO = 23,
        VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO = 24,
        VK_STRUCTURE_TYPE_PIPELINE_DEPTH_STENCIL_STATE_CREATE_INFO = 25,
        VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO = 26,
        VK_STRUCTURE_TYPE_PIPELINE_DYNAMIC_STATE_CREATE_INFO = 27,
        VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO = 28,
        VK_STRUCTURE_TYPE_COMPUTE_PIPELINE_CREATE_INFO = 29,
        VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO = 30,
        VK_STRUCTURE_TYPE_SAMPLER_CREATE_INFO = 31,
        VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO = 32,
        VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO = 33,
        VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO = 34,
        VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET = 35,
        VK_STRUCTURE_TYPE_COPY_DESCRIPTOR_SET = 36,
        VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO = 37,
        VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO = 38,
        VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO = 39,
        VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO = 40,
        VK_STRUCTURE_TYPE_COMMAND_BUFFER_INHERITANCE_INFO = 41,
        VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO = 42,
        VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO = 43,
        VK_STRUCTURE_TYPE_BUFFER_MEMORY_BARRIER = 44,
        VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER = 45,
        VK_STRUCTURE_TYPE_MEMORY_BARRIER = 46,
        VK_STRUCTURE_TYPE_LOADER_INSTANCE_CREATE_INFO = 47,
        VK_STRUCTURE_TYPE_LOADER_DEVICE_CREATE_INFO = 48,
        VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR = 1000001000,
        VK_STRUCTURE_TYPE_PRESENT_INFO_KHR = 1000001001,
        VK_STRUCTURE_TYPE_DISPLAY_MODE_CREATE_INFO_KHR = 1000002000,
        VK_STRUCTURE_TYPE_DISPLAY_SURFACE_CREATE_INFO_KHR = 1000002001,
        VK_STRUCTURE_TYPE_DISPLAY_PRESENT_INFO_KHR = 1000003000,
        VK_STRUCTURE_TYPE_XLIB_SURFACE_CREATE_INFO_KHR = 1000004000,
        VK_STRUCTURE_TYPE_XCB_SURFACE_CREATE_INFO_KHR = 1000005000,
        VK_STRUCTURE_TYPE_WAYLAND_SURFACE_CREATE_INFO_KHR = 1000006000,
        VK_STRUCTURE_TYPE_MIR_SURFACE_CREATE_INFO_KHR = 1000007000,
        VK_STRUCTURE_TYPE_ANDROID_SURFACE_CREATE_INFO_KHR = 1000008000,
        VK_STRUCTURE_TYPE_WIN32_SURFACE_CREATE_INFO_KHR = 1000009000,
        VK_STRUCTURE_TYPE_DEBUG_REPORT_CREATE_INFO_EXT = 1000011000,
        VK_STRUCTURE_TYPE_DEBUG_UTILS_MESSENGER_CREATE_INFO_EXT = 1000128004,
    }

    [Flags]
    public enum VkInstanceCreateFlags : uint
    {
        None = 0
    }

    [Flags]
    public enum VkQueueFlags : uint
    {
        VK_QUEUE_GRAPHICS_BIT = 0x00000001,
        VK_QUEUE_COMPUTE_BIT = 0x00000002,
        VK_QUEUE_TRANSFER_BIT = 0x00000004,
        VK_QUEUE_SPARSE_BINDING_BIT = 0x00000008,
    }

    [Flags]
    public enum VkWin32SurfaceCreateFlagsKHR : uint
    {
        None = 0
    }

    [Flags]
    public enum VkSwapchainCreateFlagsKHR : uint
    {
        None = 0
    }

    public enum VkPresentModeKHR : uint
    {
        VK_PRESENT_MODE_IMMEDIATE_KHR = 0,
        VK_PRESENT_MODE_MAILBOX_KHR = 1,
        VK_PRESENT_MODE_FIFO_KHR = 2,
        VK_PRESENT_MODE_FIFO_RELAXED_KHR = 3
    }

    [Flags]
    public enum VkImageUsageFlags : uint
    {
        VK_IMAGE_USAGE_TRANSFER_SRC_BIT = 0x00000001,
        VK_IMAGE_USAGE_TRANSFER_DST_BIT = 0x00000002,
        VK_IMAGE_USAGE_SAMPLED_BIT = 0x00000004,
        VK_IMAGE_USAGE_STORAGE_BIT = 0x00000008,
        VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT = 0x00000010,
        VK_IMAGE_USAGE_DEPTH_STENCIL_ATTACHMENT_BIT = 0x00000020,
        VK_IMAGE_USAGE_TRANSIENT_ATTACHMENT_BIT = 0x00000040,
        VK_IMAGE_USAGE_INPUT_ATTACHMENT_BIT = 0x00000080
    }

    [Flags]
    public enum VkSurfaceTransformFlagBitsKHR : uint
    {
        VK_SURFACE_TRANSFORM_IDENTITY_BIT_KHR = 0x00000001,
        VK_SURFACE_TRANSFORM_ROTATE_90_BIT_KHR = 0x00000002,
        VK_SURFACE_TRANSFORM_ROTATE_180_BIT_KHR = 0x00000004,
        VK_SURFACE_TRANSFORM_ROTATE_270_BIT_KHR = 0x00000008,
        VK_SURFACE_TRANSFORM_HORIZONTAL_MIRROR_BIT_KHR = 0x00000010,
        VK_SURFACE_TRANSFORM_HORIZONTAL_MIRROR_ROTATE_90_BIT_KHR = 0x00000020,
        VK_SURFACE_TRANSFORM_HORIZONTAL_MIRROR_ROTATE_180_BIT_KHR = 0x00000040,
        VK_SURFACE_TRANSFORM_HORIZONTAL_MIRROR_ROTATE_270_BIT_KHR = 0x00000080,
        VK_SURFACE_TRANSFORM_INHERIT_BIT_KHR = 0x00000100
    }

    [Flags]
    public enum VkCompositeAlphaFlagsKHR : uint
    {
        VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR = 0x00000001,
        VK_COMPOSITE_ALPHA_PRE_MULTIPLIED_BIT_KHR = 0x00000002,
        VK_COMPOSITE_ALPHA_POST_MULTIPLIED_BIT_KHR = 0x00000004,
        VK_COMPOSITE_ALPHA_INHERIT_BIT_KHR = 0x00000008
    }

    public enum VkResult : int
    {
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
        VK_ERROR_OUT_OF_DATE_KHR = -1000001004
    }

    public enum VkBool32 : uint
    {
        False = 0,
        True = 1
    }

    public enum VkPrimitiveTopology : uint
    {
        VK_PRIMITIVE_TOPOLOGY_POINT_LIST = 0,
        VK_PRIMITIVE_TOPOLOGY_LINE_LIST = 1,
        VK_PRIMITIVE_TOPOLOGY_LINE_STRIP = 2,
        VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST = 3,
        VK_PRIMITIVE_TOPOLOGY_TRIANGLE_STRIP = 4,
        VK_PRIMITIVE_TOPOLOGY_TRIANGLE_FAN = 5,
    }

    [Flags]
    public enum VkPipelineInputAssemblyStateCreateFlags : uint
    {
        None = 0 
    }

    [Flags]
    public enum VkPipelineVertexInputStateCreateFlags : uint
    {
        None = 0
    }

    public enum VkVertexInputRate : uint
    {
        VK_VERTEX_INPUT_RATE_VERTEX = 0,
        VK_VERTEX_INPUT_RATE_INSTANCE = 1
    }

    [Flags]
    public enum VkPipelineShaderStageCreateFlags : uint
    {
        None = 0
    }

    [Flags]
    public enum VkShaderStageFlags : uint
    {
        VK_SHADER_STAGE_VERTEX_BIT = 0x00000001,
        VK_SHADER_STAGE_FRAGMENT_BIT = 0x00000010,
    }

    [Flags]
    public enum VkPipelineStageFlags : uint
    {
        VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT = 0x00000001,
        VK_PIPELINE_STAGE_DRAW_INDIRECT_BIT = 0x00000002,
        VK_PIPELINE_STAGE_VERTEX_INPUT_BIT = 0x00000004,
        VK_PIPELINE_STAGE_VERTEX_SHADER_BIT = 0x00000008,
        VK_PIPELINE_STAGE_FRAGMENT_SHADER_BIT = 0x00000010,
        VK_PIPELINE_STAGE_EARLY_FRAGMENT_TESTS_BIT = 0x00000020,
        VK_PIPELINE_STAGE_LATE_FRAGMENT_TESTS_BIT = 0x00000040,
        VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT = 0x00000080,
        VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT = 0x00000200,
        VK_PIPELINE_STAGE_TRANSFER_BIT = 0x00001000,
        VK_PIPELINE_STAGE_BOTTOM_OF_PIPE_BIT = 0x00002000,
        VK_PIPELINE_STAGE_HOST_BIT = 0x00004000,
        VK_PIPELINE_STAGE_ALL_GRAPHICS_BIT = 0x00008000,
        VK_PIPELINE_STAGE_ALL_COMMANDS_BIT = 0x00010000,
    }


    [Flags]
    public enum VkAttachmentDescriptionFlags : uint
    {
        None = 0
    }

    public enum VkAttachmentLoadOp : uint
    {
        VK_ATTACHMENT_LOAD_OP_LOAD = 0,
        VK_ATTACHMENT_LOAD_OP_CLEAR = 1,
        VK_ATTACHMENT_LOAD_OP_DONT_CARE = 2
    }

    public enum VkAttachmentStoreOp : uint
    {
        VK_ATTACHMENT_STORE_OP_STORE = 0,
        VK_ATTACHMENT_STORE_OP_DONT_CARE = 1
    }

    public enum VkImageLayout : uint
    {
        VK_IMAGE_LAYOUT_UNDEFINED = 0,
        VK_IMAGE_LAYOUT_GENERAL = 1,
        VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL = 2,
        VK_IMAGE_LAYOUT_DEPTH_STENCIL_ATTACHMENT_OPTIMAL = 3,
        VK_IMAGE_LAYOUT_DEPTH_STENCIL_READ_ONLY_OPTIMAL = 4,
        VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL = 5,
        VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL = 6,
        VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL = 7,
        VK_IMAGE_LAYOUT_PRESENT_SRC_KHR = 1000001002
    }

    public enum VkSampleCountFlags : uint
    {
        VK_SAMPLE_COUNT_1_BIT = 0x00000001,
        VK_SAMPLE_COUNT_2_BIT = 0x00000002,
        VK_SAMPLE_COUNT_4_BIT = 0x00000004,
        VK_SAMPLE_COUNT_8_BIT = 0x00000008,
        VK_SAMPLE_COUNT_16_BIT = 0x00000010,
        VK_SAMPLE_COUNT_32_BIT = 0x00000020,
        VK_SAMPLE_COUNT_64_BIT = 0x00000040
    }

    public enum VkFormat : uint
    {
        VK_FORMAT_UNDEFINED = 0,
        VK_FORMAT_R8G8B8A8_UNORM = 37,
        VK_FORMAT_B8G8R8A8_UNORM = 50,
        VK_FORMAT_B8G8R8A8_SRGB = 50,
        VK_FORMAT_D32_SFLOAT = 126,
        VK_FORMAT_D32_SFLOAT_S8_UINT = 127,
        VK_FORMAT_D24_UNORM_S8_UINT = 129
    }

    public enum VkColorSpaceKHR
    {
        VK_COLOR_SPACE_SRGB_NONLINEAR_KHR = 0
    }

    [Flags]
    public enum VkSurfaceTransformFlagsKHR : uint
    {
        VK_SURFACE_TRANSFORM_IDENTITY_BIT_KHR = 0x00000001
    }

    public enum VkSharingMode : uint
    {
        VK_SHARING_MODE_EXCLUSIVE = 0, 
        VK_SHARING_MODE_CONCURRENT = 1 
    }

    [Flags]
    public enum VkSubpassDescriptionFlags : uint
    {
        None = 0
    }

    public enum VkPipelineBindPoint : uint
    {
        VK_PIPELINE_BIND_POINT_GRAPHICS = 0,
        VK_PIPELINE_BIND_POINT_COMPUTE = 1
    }

    [Flags]
    public enum VkAccessFlags : uint
    {
        VK_ACCESS_INDIRECT_COMMAND_READ_BIT = 0x00000001,
        VK_ACCESS_INDEX_READ_BIT = 0x00000002,
        VK_ACCESS_VERTEX_ATTRIBUTE_READ_BIT = 0x00000004,
        VK_ACCESS_UNIFORM_READ_BIT = 0x00000008,
        VK_ACCESS_INPUT_ATTACHMENT_READ_BIT = 0x00000010,
        VK_ACCESS_SHADER_READ_BIT = 0x00000020,
        VK_ACCESS_SHADER_WRITE_BIT = 0x00000040,
        VK_ACCESS_COLOR_ATTACHMENT_READ_BIT = 0x00000080,
        VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT = 0x00000100,
        VK_ACCESS_DEPTH_STENCIL_ATTACHMENT_READ_BIT = 0x00000200,
        VK_ACCESS_DEPTH_STENCIL_ATTACHMENT_WRITE_BIT = 0x00000400,
        VK_ACCESS_TRANSFER_READ_BIT = 0x00000800,
        VK_ACCESS_TRANSFER_WRITE_BIT = 0x00001000,
        VK_ACCESS_HOST_READ_BIT = 0x00002000,
        VK_ACCESS_HOST_WRITE_BIT = 0x00004000,
        VK_ACCESS_MEMORY_READ_BIT = 0x00008000,
        VK_ACCESS_MEMORY_WRITE_BIT = 0x00010000,
    }

    [Flags]
    public enum VkDependencyFlags : uint
    {
        VK_DEPENDENCY_BY_REGION_BIT = 0x00000001,
        VK_DEPENDENCY_DEVICE_GROUP_BIT = 0x00000004,
        VK_DEPENDENCY_VIEW_LOCAL_BIT = 0x00000002,
    }

    [Flags]
    public enum VkFormatFeatureFlags : uint
    {
        VK_FORMAT_FEATURE_SAMPLED_IMAGE_BIT = 0x00000001,
        VK_FORMAT_FEATURE_STORAGE_IMAGE_BIT = 0x00000002,
        VK_FORMAT_FEATURE_STORAGE_IMAGE_ATOMIC_BIT = 0x00000004,
        VK_FORMAT_FEATURE_UNIFORM_TEXEL_BUFFER_BIT = 0x00000008,
        VK_FORMAT_FEATURE_STORAGE_TEXEL_BUFFER_BIT = 0x00000010,
        VK_FORMAT_FEATURE_STORAGE_TEXEL_BUFFER_ATOMIC_BIT = 0x00000020,
        VK_FORMAT_FEATURE_VERTEX_BUFFER_BIT = 0x00000040,
        VK_FORMAT_FEATURE_COLOR_ATTACHMENT_BIT = 0x00000080,
        VK_FORMAT_FEATURE_COLOR_ATTACHMENT_BLEND_BIT = 0x00000100,
        VK_FORMAT_FEATURE_DEPTH_STENCIL_ATTACHMENT_BIT = 0x00000200,
        VK_FORMAT_FEATURE_BLIT_SRC_BIT = 0x00000400,
        VK_FORMAT_FEATURE_BLIT_DST_BIT = 0x00000800,
        VK_FORMAT_FEATURE_SAMPLED_IMAGE_FILTER_LINEAR_BIT = 0x00001000,
        VK_FORMAT_FEATURE_SAMPLED_IMAGE_FILTER_CUBIC_BIT_IMG = 0x00002000,
        VK_FORMAT_FEATURE_TRANSFER_SRC_BIT = 0x00004000,
        VK_FORMAT_FEATURE_TRANSFER_DST_BIT = 0x00008000,
        VK_FORMAT_FEATURE_SAMPLED_IMAGE_FILTER_MINMAX_BIT = 0x00010000,
        VK_FORMAT_FEATURE_MIDPOINT_CHROMA_SAMPLES_BIT = 0x00020000,
        VK_FORMAT_FEATURE_SAMPLED_IMAGE_YCBCR_CONVERSION_LINEAR_FILTER_BIT = 0x00040000,
        VK_FORMAT_FEATURE_SAMPLED_IMAGE_YCBCR_CONVERSION_SEPARATE_RECONSTRUCTION_FILTER_BIT = 0x00080000,
        VK_FORMAT_FEATURE_SAMPLED_IMAGE_YCBCR_CONVERSION_CHROMA_RECONSTRUCTION_EXPLICIT_BIT = 0x00100000,
        VK_FORMAT_FEATURE_SAMPLED_IMAGE_YCBCR_CONVERSION_CHROMA_RECONSTRUCTION_EXPLICIT_FORCEABLE_BIT = 0x00200000,
        VK_FORMAT_FEATURE_DISJOINT_BIT = 0x00400000,
        VK_FORMAT_FEATURE_COSITED_CHROMA_SAMPLES_BIT = 0x00800000,
    }

    [Flags]
    public enum VkShaderModuleCreateFlags : uint
    {
        None = 0
    }

    [Flags]
    public enum VkPipelineViewportStateCreateFlags : uint
    {
        None = 0
    }

    public enum VkPolygonMode : uint
    {
        VK_POLYGON_MODE_FILL = 0,
        VK_POLYGON_MODE_LINE = 1,
        VK_POLYGON_MODE_POINT = 2,
    }

    [Flags]
    public enum VkCullModeFlags : uint
    {
        VK_CULL_MODE_NONE = 0,
        VK_CULL_MODE_FRONT_BIT = 0x1,
        VK_CULL_MODE_BACK_BIT = 0x2,
        VK_CULL_MODE_FRONT_AND_BACK = 0x3,
    }

    public enum VkFrontFace : uint
    {
        VK_FRONT_FACE_COUNTER_CLOCKWISE = 0,
        VK_FRONT_FACE_CLOCKWISE = 1,
    }

    [Flags]
    public enum VkPipelineRasterizationStateCreateFlags : uint
    {
        None = 0,
    }

    [Flags]
    public enum VkPipelineMultisampleStateCreateFlags : uint
    {
        None = 0
    }

    public enum VkBlendFactor : uint
    {
        VK_BLEND_FACTOR_ZERO = 0,
        VK_BLEND_FACTOR_ONE = 1,
        VK_BLEND_FACTOR_SRC_COLOR = 2,
        VK_BLEND_FACTOR_ONE_MINUS_SRC_COLOR = 3,
        VK_BLEND_FACTOR_DST_COLOR = 4,
        VK_BLEND_FACTOR_ONE_MINUS_DST_COLOR = 5,
        VK_BLEND_FACTOR_SRC_ALPHA = 6,
        VK_BLEND_FACTOR_ONE_MINUS_SRC_ALPHA = 7,
        VK_BLEND_FACTOR_DST_ALPHA = 8,
        VK_BLEND_FACTOR_ONE_MINUS_DST_ALPHA = 9,
        VK_BLEND_FACTOR_CONSTANT_COLOR = 10,
        VK_BLEND_FACTOR_ONE_MINUS_CONSTANT_COLOR = 11,
        VK_BLEND_FACTOR_CONSTANT_ALPHA = 12,
        VK_BLEND_FACTOR_ONE_MINUS_CONSTANT_ALPHA = 13,
        VK_BLEND_FACTOR_SRC_ALPHA_SATURATE = 14,
        VK_BLEND_FACTOR_SRC1_COLOR = 15,
        VK_BLEND_FACTOR_ONE_MINUS_SRC1_COLOR = 16,
        VK_BLEND_FACTOR_SRC1_ALPHA = 17,
        VK_BLEND_FACTOR_ONE_MINUS_SRC1_ALPHA = 18
    }


    public enum VkBlendOp : uint
    {
        VK_BLEND_OP_ADD = 0,
        VK_BLEND_OP_SUBTRACT = 1,
        VK_BLEND_OP_REVERSE_SUBTRACT = 2,
        VK_BLEND_OP_MIN = 3,
        VK_BLEND_OP_MAX = 4
    }

    [Flags]
    public enum VkColorComponentFlags : uint
    {
        VK_COLOR_COMPONENT_R_BIT = 0x00000001,
        VK_COLOR_COMPONENT_G_BIT = 0x00000002,
        VK_COLOR_COMPONENT_B_BIT = 0x00000004,
        VK_COLOR_COMPONENT_A_BIT = 0x00000008
    }

    [Flags]
    public enum VkPipelineColorBlendStateCreateFlags : uint
    {
        None = 0
    }

    public enum VkLogicOp : uint
    {
        VK_LOGIC_OP_CLEAR = 0,
        VK_LOGIC_OP_AND = 1,
        VK_LOGIC_OP_AND_REVERSE = 2,
        VK_LOGIC_OP_COPY = 3,
        VK_LOGIC_OP_AND_INVERTED = 4,
        VK_LOGIC_OP_NO_OP = 5,
        VK_LOGIC_OP_XOR = 6,
        VK_LOGIC_OP_OR = 7,
        VK_LOGIC_OP_NOR = 8,
        VK_LOGIC_OP_EQUIVALENT = 9,
        VK_LOGIC_OP_INVERT = 10,
        VK_LOGIC_OP_OR_REVERSE = 11,
        VK_LOGIC_OP_COPY_INVERTED = 12,
        VK_LOGIC_OP_OR_INVERTED = 13,
        VK_LOGIC_OP_NAND = 14,
        VK_LOGIC_OP_SET = 15
    }

    [Flags]
    public enum VkPipelineLayoutCreateFlags : uint
    {
        None = 0
    }

    [Flags]
    public enum VkPipelineCreateFlags : uint
    {
        None = 0,
        VK_PIPELINE_CREATE_DISABLE_OPTIMIZATION_BIT = 0x00000001,
        VK_PIPELINE_CREATE_ALLOW_DERIVATIVES_BIT = 0x00000002,
        VK_PIPELINE_CREATE_DERIVATIVE_BIT = 0x00000004,
    }

    [Flags]
    public enum VkCommandBufferUsageFlags : uint
    {
        VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT = 0x00000001,
        VK_COMMAND_BUFFER_USAGE_RENDER_PASS_CONTINUE_BIT = 0x00000002,
        VK_COMMAND_BUFFER_USAGE_SIMULTANEOUS_USE_BIT = 0x00000004,
    }

    public enum VkSubpassContents : uint
    {
        VK_SUBPASS_CONTENTS_INLINE = 0,
        VK_SUBPASS_CONTENTS_SECONDARY_COMMAND_BUFFERS = 1,
    }

    public enum VkCommandBufferLevel
    {
        VK_COMMAND_BUFFER_LEVEL_PRIMARY = 0,
        VK_COMMAND_BUFFER_LEVEL_SECONDARY = 1
    }

    [Flags]
    public enum VkCommandPoolCreateFlags : uint
    {
        VK_COMMAND_POOL_CREATE_TRANSIENT_BIT = 0x00000001,
        VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT = 0x00000002
    }

    [Flags]
    public enum VkPipelineDepthStencilStateCreateFlags : uint
    {
        None = 0
    }

    public enum VkCompareOp : uint
    {
        VK_COMPARE_OP_NEVER = 0,            
        VK_COMPARE_OP_LESS = 1,             
        VK_COMPARE_OP_EQUAL = 2,            
        VK_COMPARE_OP_LESS_OR_EQUAL = 3,    
        VK_COMPARE_OP_GREATER = 4,          
        VK_COMPARE_OP_NOT_EQUAL = 5,        
        VK_COMPARE_OP_GREATER_OR_EQUAL = 6, 
        VK_COMPARE_OP_ALWAYS = 7            
    }

    public enum VkStencilOp : uint
    {
        VK_STENCIL_OP_KEEP = 0,                  
        VK_STENCIL_OP_ZERO = 1,                  
        VK_STENCIL_OP_REPLACE = 2,               
        VK_STENCIL_OP_INCREMENT_AND_CLAMP = 3,   
        VK_STENCIL_OP_DECREMENT_AND_CLAMP = 4,   
        VK_STENCIL_OP_INVERT = 5,                
        VK_STENCIL_OP_INCREMENT_AND_WRAP = 6,    
        VK_STENCIL_OP_DECREMENT_AND_WRAP = 7     
    }

    [Flags]
    public enum VkFenceCreateFlags : uint
    {
        VK_FENCE_CREATE_SIGNALED_BIT = 0x00000001
    }

    public enum VkImageViewType
    {
        VK_IMAGE_VIEW_TYPE_1D = 0,
        VK_IMAGE_VIEW_TYPE_2D = 1,
        VK_IMAGE_VIEW_TYPE_3D = 2,
        VK_IMAGE_VIEW_TYPE_CUBE = 3,
        VK_IMAGE_VIEW_TYPE_1D_ARRAY = 4,
        VK_IMAGE_VIEW_TYPE_2D_ARRAY = 5,
        VK_IMAGE_VIEW_TYPE_CUBE_ARRAY = 6
    }

    [Flags]
    public enum VkImageViewCreateFlags : uint
    {
        None = 0,
        VK_IMAGE_VIEW_CREATE_FRAGMENT_DENSITY_MAP_DYNAMIC_BIT_EXT = 0x1,
        VK_IMAGE_VIEW_CREATE_FRAGMENT_DENSITY_MAP_DEFERRED_BIT_EXT = 0x2
    }


    [Flags]
    public enum VkImageAspectFlags : uint
    {
        VK_IMAGE_ASPECT_COLOR_BIT = 0x1,        
        VK_IMAGE_ASPECT_DEPTH_BIT = 0x2,        
        VK_IMAGE_ASPECT_STENCIL_BIT = 0x4,      
        VK_IMAGE_ASPECT_METADATA_BIT = 0x8,     
        VK_IMAGE_ASPECT_PLANE_0_BIT = 0x10,     
        VK_IMAGE_ASPECT_PLANE_1_BIT = 0x20,     
        VK_IMAGE_ASPECT_PLANE_2_BIT = 0x40      
    }

    public enum VkComponentSwizzle : uint
    {
        VK_COMPONENT_SWIZZLE_IDENTITY = 0,  
        VK_COMPONENT_SWIZZLE_ZERO = 1,      
        VK_COMPONENT_SWIZZLE_ONE = 2,       
        VK_COMPONENT_SWIZZLE_R = 3,         
        VK_COMPONENT_SWIZZLE_G = 4,         
        VK_COMPONENT_SWIZZLE_B = 5,         
        VK_COMPONENT_SWIZZLE_A = 6          
    }

    public enum VkImageType : uint
    {
        VK_IMAGE_TYPE_1D = 0,
        VK_IMAGE_TYPE_2D = 1,
        VK_IMAGE_TYPE_3D = 2
    }

    public enum VkImageTiling : uint
    {
        VK_IMAGE_TILING_OPTIMAL = 0,
        VK_IMAGE_TILING_LINEAR = 1
    }

    [Flags]
    public enum VkMemoryPropertyFlags : uint
    {
        VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT = 0x1,
        VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT = 0x2,
        VK_MEMORY_PROPERTY_HOST_COHERENT_BIT = 0x4,
        VK_MEMORY_PROPERTY_HOST_CACHED_BIT = 0x8,
        VK_MEMORY_PROPERTY_LAZILY_ALLOCATED_BIT = 0x10,
        VK_MEMORY_PROPERTY_PROTECTED_BIT = 0x20
    }

    [Flags]
    public enum VkImageCreateFlags : uint
    {
        VK_IMAGE_CREATE_SPARSE_BINDING_BIT = 0x00000001,
        VK_IMAGE_CREATE_SPARSE_RESIDENCY_BIT = 0x00000002,
        VK_IMAGE_CREATE_SPARSE_ALIASED_BIT = 0x00000004,
        VK_IMAGE_CREATE_MUTABLE_FORMAT_BIT = 0x00000008,
        VK_IMAGE_CREATE_CUBE_COMPATIBLE_BIT = 0x00000010,
        VK_IMAGE_CREATE_ALIAS_BIT = 0x00000400,
        VK_IMAGE_CREATE_SPLIT_INSTANCE_BIND_REGIONS_BIT = 0x00000040,
        VK_IMAGE_CREATE_2D_ARRAY_COMPATIBLE_BIT = 0x00000020,
        VK_IMAGE_CREATE_BLOCK_TEXEL_VIEW_COMPATIBLE_BIT = 0x00000080,
        VK_IMAGE_CREATE_EXTENDED_USAGE_BIT = 0x00000100,
        VK_IMAGE_CREATE_PROTECTED_BIT = 0x00000800,
        VK_IMAGE_CREATE_DISJOINT_BIT = 0x00000200
    }

    [Flags]
    public enum VkMemoryHeapFlags : uint
    {
        VK_MEMORY_HEAP_DEVICE_LOCAL_BIT = 0x00000001
    }

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
    struct VkInstanceCreateInfo
    {
        public VkStructureType sType;
        public IntPtr pNext;
        public VkInstanceCreateFlags flags;
        public IntPtr pApplicationInfo;
        public uint enabledLayerCount;
        public IntPtr ppEnabledLayerNames;
        public uint enabledExtensionCount;
        public IntPtr ppEnabledExtensionNames;
    }

    public struct VkDebugUtilsMessengerCreateInfoEXT
    {
        public VkStructureType sType;
        public IntPtr pNext;
        public uint flags; 
        public VkDebugUtilsMessageSeverityFlagsEXT messageSeverity;
        public VkDebugUtilsMessageTypeFlagsEXT messageType;
        public IntPtr pfnUserCallback;
        public IntPtr pUserData;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct VkQueueFamilyProperties
    {
        public VkQueueFlags queueFlags;
        public uint queueCount;
        public uint timestampValidBits;
        public VkExtent3D minImageTransferGranularity;
    }

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Ansi, Pack = 1)] 
    struct VkExtensionProperties
    {
        [MarshalAs(UnmanagedType.ByValArray, SizeConst = 256)] 
        public byte[] extensionName; 
        public uint specVersion;

        public void Initialize()
        {
            extensionName = new byte[256]; 
            specVersion = 0;
        }
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct VkExtent3D
    {
        public uint width;
        public uint height;
        public uint depth;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct VkPhysicalDevice
    {
        public IntPtr Handle;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct VkPhysicalDeviceProperties
    {
        public uint apiVersion;
        public uint driverVersion;
        public uint vendorID;
        public uint deviceID;
        public VkPhysicalDeviceType deviceType;
        [MarshalAs(UnmanagedType.ByValArray, SizeConst = 256)]
        public byte[] deviceName;
        [MarshalAs(UnmanagedType.ByValArray, SizeConst = 16)]
        public byte[] pipelineCacheUUID;
        public VkPhysicalDeviceLimits limits;
        public VkPhysicalDeviceSparseProperties sparseProperties;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct VkPhysicalDeviceLimits
    {
        public uint maxImageDimension1D;
        public uint maxImageDimension2D;
        public uint maxImageDimension3D;
        public uint maxImageDimensionCube;
        public uint maxImageArrayLayers;
        public uint maxTexelBufferElements;
        public uint maxUniformBufferRange;
        public uint maxStorageBufferRange;
        public uint maxPushConstantsSize;
        public uint maxMemoryAllocationCount;
        public uint maxSamplerAllocationCount;
        public ulong bufferImageGranularity;
        public ulong sparseAddressSpaceSize;
        public uint maxBoundDescriptorSets;
        public uint maxPerStageDescriptorSamplers;
        public uint maxPerStageDescriptorUniformBuffers;
        public uint maxPerStageDescriptorStorageBuffers;
        public uint maxPerStageDescriptorSampledImages;
        public uint maxPerStageDescriptorStorageImages;
        public uint maxPerStageDescriptorInputAttachments;
        public uint maxPerStageResources;
        public uint maxDescriptorSetSamplers;
        public uint maxDescriptorSetUniformBuffers;
        public uint maxDescriptorSetUniformBuffersDynamic;
        public uint maxDescriptorSetStorageBuffers;
        public uint maxDescriptorSetStorageBuffersDynamic;
        public uint maxDescriptorSetSampledImages;
        public uint maxDescriptorSetStorageImages;
        public uint maxDescriptorSetInputAttachments;
        public uint maxVertexInputAttributes;
        public uint maxVertexInputBindings;
        public uint maxVertexInputAttributeOffset;
        public uint maxVertexInputBindingStride;
        public uint maxVertexOutputComponents;
        public uint maxTessellationGenerationLevel;
        public uint maxTessellationPatchSize;
        public uint maxTessellationControlPerVertexInputComponents;
        public uint maxTessellationControlPerVertexOutputComponents;
        public uint maxTessellationControlPerPatchOutputComponents;
        public uint maxTessellationControlTotalOutputComponents;
        public uint maxTessellationEvaluationInputComponents;
        public uint maxTessellationEvaluationOutputComponents;
        public uint maxGeometryShaderInvocations;
        public uint maxGeometryInputComponents;
        public uint maxGeometryOutputComponents;
        public uint maxGeometryOutputVertices;
        public uint maxGeometryTotalOutputComponents;
        public uint maxFragmentInputComponents;
        public uint maxFragmentOutputAttachments;
        public uint maxFragmentDualSrcAttachments;
        public uint maxFragmentCombinedOutputResources;
        public uint maxComputeSharedMemorySize;
        [MarshalAs(UnmanagedType.ByValArray, SizeConst = 3)]
        public uint[] maxComputeWorkGroupCount;
        public uint maxComputeWorkGroupInvocations;
        [MarshalAs(UnmanagedType.ByValArray, SizeConst = 3)]
        public uint[] maxComputeWorkGroupSize;
        public uint subPixelPrecisionBits;
        public uint subTexelPrecisionBits;
        public uint mipmapPrecisionBits;
        public uint maxDrawIndexedIndexValue;
        public uint maxDrawIndirectCount;
        public float maxSamplerLodBias;
        public float maxSamplerAnisotropy;
        public uint maxViewports;
        [MarshalAs(UnmanagedType.ByValArray, SizeConst = 2)]
        public uint[] maxViewportDimensions;
        [MarshalAs(UnmanagedType.ByValArray, SizeConst = 2)]
        public float[] viewportBoundsRange;
        public uint viewportSubPixelBits;
        public nuint minMemoryMapAlignment;
        public ulong minTexelBufferOffsetAlignment;
        public ulong minUniformBufferOffsetAlignment;
        public ulong minStorageBufferOffsetAlignment;
        public int minTexelOffset;
        public uint maxTexelOffset;
        public int minTexelGatherOffset;
        public uint maxTexelGatherOffset;
        public float minInterpolationOffset;
        public float maxInterpolationOffset;
        public uint subPixelInterpolationOffsetBits;
        public uint maxFramebufferWidth;
        public uint maxFramebufferHeight;
        public uint maxFramebufferLayers;
        public VkSampleCountFlags framebufferColorSampleCounts;
        public VkSampleCountFlags framebufferDepthSampleCounts;
        public VkSampleCountFlags framebufferStencilSampleCounts;
        public VkSampleCountFlags framebufferNoAttachmentsSampleCounts;
        public uint maxColorAttachments;
        public VkSampleCountFlags sampledImageColorSampleCounts;
        public VkSampleCountFlags sampledImageIntegerSampleCounts;
        public VkSampleCountFlags sampledImageDepthSampleCounts;
        public VkSampleCountFlags sampledImageStencilSampleCounts;
        public VkSampleCountFlags storageImageSampleCounts;
        public uint maxSampleMaskWords;
        public VkBool32 timestampComputeAndGraphics;
        public float timestampPeriod;
        public uint maxClipDistances;
        public uint maxCullDistances;
        public uint maxCombinedClipAndCullDistances;
        public uint discreteQueuePriorities;
        [MarshalAs(UnmanagedType.ByValArray, SizeConst = 2)]
        public float[] pointSizeRange;
        [MarshalAs(UnmanagedType.ByValArray, SizeConst = 2)]
        public float[] lineWidthRange;
        public float pointSizeGranularity;
        public float lineWidthGranularity;
        public VkBool32 strictLines;
        public VkBool32 standardSampleLocations;
        public ulong optimalBufferCopyOffsetAlignment;
        public ulong optimalBufferCopyRowPitchAlignment;
        public ulong nonCoherentAtomSize;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct VkPhysicalDeviceSparseProperties
    {
        public uint residencyStandard2DBlockShape;
        public uint residencyStandard2DMultisampleBlockShape;
        public uint residencyStandard3DBlockShape;
        public uint residencyAlignedMipSize;
        public uint residencyNonResidentStrict;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct SwapChainSupportDetails
    {
        public VkSurfaceCapabilitiesKHR capabilities;
        public VkSurfaceFormatKHR[] formats;
        public VkPresentModeKHR[] presentModes;

        public void Initialize()
        {
            capabilities = new VkSurfaceCapabilitiesKHR();
            formats = new VkSurfaceFormatKHR[0];
            presentModes = new VkPresentModeKHR[0];
        }
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
        public VkSurfaceTransformFlagsKHR supportedTransforms;
        public VkSurfaceTransformFlagBitsKHR currentTransform;
        public VkCompositeAlphaFlagsKHR supportedCompositeAlpha;
        public VkImageUsageFlags supportedUsageFlags;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct VkWin32SurfaceCreateInfoKHR
    {
        public VkStructureType sType;
        public IntPtr pNext;
        public VkWin32SurfaceCreateFlagsKHR flags;
        public IntPtr hinstance;  
        public IntPtr hwnd;       
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct VkDebugUtilsMessengerCallbackDataEXT
    {
        public VkStructureType sType;
        public IntPtr pNext;
        public uint flags;
        public IntPtr pMessageIdName;
        public int messageIdNumber;
        public IntPtr pMessage;
        public uint queueLabelCount;
        public IntPtr pQueueLabels;
        public uint cmdBufLabelCount;
        public IntPtr pCmdBufLabels;
        public uint objectCount;
        public IntPtr pObjects;
    }

    public struct QueueFamilyIndices
    {
        public int? GraphicsFamily; 
        public int? PresentFamily;  

        public bool IsComplete()
        {
            return GraphicsFamily.HasValue && PresentFamily.HasValue;
        }
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
    public struct VkPhysicalDeviceFeatures
    {
        public VkBool32 robustBufferAccess;
        public VkBool32 fullDrawIndexUint32;
        public VkBool32 imageCubeArray;
        public VkBool32 independentBlend;
        public VkBool32 geometryShader;
        public VkBool32 tessellationShader;
        public VkBool32 sampleRateShading;
        public VkBool32 dualSrcBlend;
        public VkBool32 logicOp;
        public VkBool32 multiDrawIndirect;
        public VkBool32 drawIndirectFirstInstance;
        public VkBool32 depthClamp;
        public VkBool32 depthBiasClamp;
        public VkBool32 fillModeNonSolid;
        public VkBool32 depthBounds;
        public VkBool32 wideLines;
        public VkBool32 largePoints;
        public VkBool32 alphaToOne;
        public VkBool32 multiViewport;
        public VkBool32 samplerAnisotropy;
        public VkBool32 textureCompressionETC2;
        public VkBool32 textureCompressionASTC_LDR;
        public VkBool32 textureCompressionBC;
        public VkBool32 occlusionQueryPrecise;
        public VkBool32 pipelineStatisticsQuery;
        public VkBool32 vertexPipelineStoresAndAtomics;
        public VkBool32 fragmentStoresAndAtomics;
        public VkBool32 shaderTessellationAndGeometryPointSize;
        public VkBool32 shaderImageGatherExtended;
        public VkBool32 shaderStorageImageExtendedFormats;
        public VkBool32 shaderStorageImageMultisample;
        public VkBool32 shaderStorageImageReadWithoutFormat;
        public VkBool32 shaderStorageImageWriteWithoutFormat;
        public VkBool32 shaderUniformBufferArrayDynamicIndexing;
        public VkBool32 shaderSampledImageArrayDynamicIndexing;
        public VkBool32 shaderStorageBufferArrayDynamicIndexing;
        public VkBool32 shaderStorageImageArrayDynamicIndexing;
        public VkBool32 shaderClipDistance;
        public VkBool32 shaderCullDistance;
        public VkBool32 shaderFloat64;
        public VkBool32 shaderInt64;
        public VkBool32 shaderInt16;
        public VkBool32 shaderResourceResidency;
        public VkBool32 shaderResourceMinLod;
        public VkBool32 sparseBinding;
        public VkBool32 sparseResidencyBuffer;
        public VkBool32 sparseResidencyImage2D;
        public VkBool32 sparseResidencyImage3D;
        public VkBool32 sparseResidency2Samples;
        public VkBool32 sparseResidency4Samples;
        public VkBool32 sparseResidency8Samples;
        public VkBool32 sparseResidency16Samples;
        public VkBool32 sparseResidencyAliased;
        public VkBool32 variableMultisampleRate;
        public VkBool32 inheritedQueries;
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
        public VkSwapchainCreateFlagsKHR flags;        
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
    public struct VkFormatProperties
    {
        public VkFormatFeatureFlags linearTilingFeatures;
        public VkFormatFeatureFlags optimalTilingFeatures;
        public VkFormatFeatureFlags bufferFeatures;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct VkExtent2D
    {
        public uint width;
        public uint height;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct VkSurfaceFormatKHR
    {
        public VkFormat format;
        public VkColorSpaceKHR colorSpace;

        public VkSurfaceFormatKHR(VkFormat format, VkColorSpaceKHR colorSpace)
        {
            this.format = format;
            this.colorSpace = colorSpace;
        }
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct VkAttachmentDescription
    {
        public VkAttachmentDescriptionFlags flags;
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
        public VkSubpassDescriptionFlags flags; 
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
    public struct VkSubpassDependency
    {
        public uint srcSubpass; 
        public uint dstSubpass; 
        public VkPipelineStageFlags srcStageMask; 
        public VkPipelineStageFlags dstStageMask; 
        public VkAccessFlags srcAccessMask; 
        public VkAccessFlags dstAccessMask; 
        public VkDependencyFlags dependencyFlags; 
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
    public struct VkPipelineShaderStageCreateInfo
    {
        public VkStructureType sType;
        public IntPtr pNext;
        public VkPipelineShaderStageCreateFlags flags;
        public VkShaderStageFlags stage;
        public IntPtr module; 
        public IntPtr pName;
        public IntPtr pSpecializationInfo; 
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct VkShaderModuleCreateInfo
    {
        public VkStructureType sType;          
        public IntPtr pNext;                   
        public VkShaderModuleCreateFlags flags; 
        public UIntPtr codeSize;               
        public IntPtr pCode;                   
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct VkPipelineVertexInputStateCreateInfo
    {
        public VkStructureType sType;
        public IntPtr pNext;
        public VkPipelineVertexInputStateCreateFlags flags;
        public uint vertexBindingDescriptionCount;
        public IntPtr pVertexBindingDescriptions; 
        public uint vertexAttributeDescriptionCount;
        public IntPtr pVertexAttributeDescriptions; 
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct VkVertexInputBindingDescription
    {
        public uint binding;
        public uint stride;
        public VkVertexInputRate inputRate;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct VkVertexInputAttributeDescription
    {
        public uint location;
        public uint binding;
        public VkFormat format;
        public uint offset;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct VkPipelineInputAssemblyStateCreateInfo
    {
        public VkStructureType sType;                
        public IntPtr pNext;                         
        public VkPipelineInputAssemblyStateCreateFlags flags; 
        public VkPrimitiveTopology topology;         
        public VkBool32 primitiveRestartEnable;      
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct VkViewport
    {
        public float x;        
        public float y;        
        public float width;    
        public float height;   
        public float minDepth; 
        public float maxDepth; 
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct VkOffset2D
    {
        public int x; 
        public int y; 
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct VkRect2D
    {
        public VkOffset2D offset; 
        public VkExtent2D extent; 
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct VkPipelineViewportStateCreateInfo
    {
        public VkStructureType sType;            
        public IntPtr pNext;                     
        public VkPipelineViewportStateCreateFlags flags; 
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
        public VkPipelineRasterizationStateCreateFlags flags; 
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
        public VkPipelineMultisampleStateCreateFlags flags; 
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
        public VkBlendFactor srcColorBlendFactor;  
        public VkBlendFactor dstColorBlendFactor;  
        public VkBlendOp colorBlendOp;             
        public VkBlendFactor srcAlphaBlendFactor;  
        public VkBlendFactor dstAlphaBlendFactor;  
        public VkBlendOp alphaBlendOp;             
        public VkColorComponentFlags colorWriteMask; 
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct VkPipelineColorBlendStateCreateInfo
    {
        public VkStructureType sType;                 
        public IntPtr pNext;                          
        public VkPipelineColorBlendStateCreateFlags flags; 
        public VkBool32 logicOpEnable;               
        public VkLogicOp logicOp;                    
        public uint attachmentCount;                 
        public IntPtr pAttachments;                  
        public float blendConstants0;                
        public float blendConstants1;                
        public float blendConstants2;                
        public float blendConstants3;                
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct VkPipelineLayoutCreateInfo
    {
        public VkStructureType sType;
        public IntPtr pNext; 
        public VkPipelineLayoutCreateFlags flags; 
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
        public VkPipelineCreateFlags flags;
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
    public struct VkCommandBufferBeginInfo
    {
        public VkStructureType sType;
        public IntPtr pNext;
        public VkCommandBufferUsageFlags flags;
        public IntPtr pInheritanceInfo;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct VkClearValue
    {
        public VkClearColorValue color;
        public VkClearDepthStencilValue depthStencil;
    }

    [StructLayout(LayoutKind.Sequential)]  
    public struct VkClearColorValue
    {
        [MarshalAs(UnmanagedType.ByValArray, SizeConst = 4)]
        public float[] float32;  
    }

    public struct VkClearDepthStencilValue
    {
        public float depth;
        public uint stencil;
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
    public struct VkPipelineDepthStencilStateCreateInfo
    {
        public VkStructureType sType;
        public IntPtr pNext;
        public VkPipelineDepthStencilStateCreateFlags flags;
        public VkBool32 depthTestEnable;
        public VkBool32 depthWriteEnable;
        public VkCompareOp depthCompareOp;
        public VkBool32 depthBoundsTestEnable;
        public VkBool32 stencilTestEnable;
        public VkStencilOpState front;
        public VkStencilOpState back;
        public float minDepthBounds;
        public float maxDepthBounds;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct VkStencilOpState
    {
        public VkStencilOp failOp;
        public VkStencilOp passOp;
        public VkStencilOp depthFailOp;
        public VkCompareOp compareOp;
        public uint compareMask;
        public uint writeMask;
        public uint reference;
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

    public struct VkImageViewCreateInfo
    {
        public VkStructureType sType;
        public IntPtr pNext;
        public VkImageViewCreateFlags flags;
        public IntPtr image; 
        public VkImageViewType viewType;
        public VkFormat format;
        public VkComponentMapping components;
        public VkImageSubresourceRange subresourceRange;
    }

    public struct VkImageSubresourceRange
    {
        public VkImageAspectFlags aspectMask;
        public uint baseMipLevel;
        public uint levelCount;
        public uint baseArrayLayer;
        public uint layerCount;
    }


    public struct VkImageCreateInfo
    {
        public VkStructureType sType;
        public IntPtr pNext;
        public VkImageCreateFlags flags;
        public VkImageType imageType;
        public VkFormat format;
        public VkExtent3D extent;
        public uint mipLevels;
        public uint arrayLayers;
        public VkSampleCountFlags samples;
        public VkImageTiling tiling;
        public VkImageUsageFlags usage;
        public VkSharingMode sharingMode;
        public uint queueFamilyIndexCount;
        public IntPtr pQueueFamilyIndices;
        public VkImageLayout initialLayout;
    }

    public struct VkMemoryRequirements
    {
        public ulong size;
        public ulong alignment;
        public uint memoryTypeBits;
    }

    public struct VkComponentMapping
    {
        public VkComponentSwizzle r;
        public VkComponentSwizzle g;
        public VkComponentSwizzle b;
        public VkComponentSwizzle a;
    }

    public struct VkMemoryAllocateInfo
    {
        public VkStructureType sType;
        public IntPtr pNext;
        public ulong allocationSize;
        public uint memoryTypeIndex;
    }

    public struct VkPhysicalDeviceMemoryProperties
    {
        public uint memoryTypeCount;
        [MarshalAs(UnmanagedType.ByValArray, SizeConst = 32)]
        public VkMemoryType[] memoryTypes;
        public uint memoryHeapCount;
        [MarshalAs(UnmanagedType.ByValArray, SizeConst = 16)]
        public VkMemoryHeap[] memoryHeaps;
    }

    public struct VkMemoryType
    {
        public VkMemoryPropertyFlags propertyFlags;
        public uint heapIndex;
    }

    public struct VkMemoryHeap
    {
        public ulong size;
        public VkMemoryHeapFlags flags;
    }

    [DllImport("vulkan-1.dll")]
    static extern int vkCreateInstance(
        ref VkInstanceCreateInfo pCreateInfo,
        IntPtr pAllocator,
        out IntPtr pInstance
    );

    [DllImport("vulkan-1.dll")]
    static extern int vkEnumeratePhysicalDevices(
       IntPtr instance,
       ref uint deviceCount,
       [Optional] IntPtr[] pDevices
    );

    [DllImport("vulkan-1.dll", CallingConvention = CallingConvention.Winapi)]
    static extern void vkGetPhysicalDeviceProperties(
        IntPtr device,
        IntPtr propertiesPtr 
    );

    [DllImport("vulkan-1.dll", CallingConvention = CallingConvention.Winapi)]
    static extern VkResult vkEnumerateDeviceExtensionProperties(
        IntPtr device,
        IntPtr pLayerName,
        ref uint propertyCount,
        IntPtr pProperties
    );

    [DllImport("vulkan-1.dll")]
    static extern int vkGetPhysicalDeviceSurfaceCapabilitiesKHR(
       IntPtr physicalDevice,
       IntPtr surface,
       out VkSurfaceCapabilitiesKHR pSurfaceCapabilities);

    [DllImport("vulkan-1.dll")]
    static extern int vkGetPhysicalDeviceSurfaceFormatsKHR(
        IntPtr physicalDevice,
        IntPtr surface,
        ref uint pSurfaceFormatCount,
        [Optional][Out] VkSurfaceFormatKHR[] pSurfaceFormats);

    [DllImport("vulkan-1.dll", CallingConvention = CallingConvention.Winapi)]
    private static extern VkResult vkGetPhysicalDeviceSurfacePresentModesKHR(
        IntPtr physicalDevice,
        IntPtr surface,
        ref uint pPresentModeCount,
        [Optional] VkPresentModeKHR[] pPresentModes);

    [DllImport("vulkan-1.dll", CallingConvention = CallingConvention.Winapi)]
    static extern VkResult vkCreateDevice(
        IntPtr physicalDevice,
        ref VkDeviceCreateInfo pCreateInfo,
        IntPtr pAllocator,
        out IntPtr pDevice
    );

    [DllImport("vulkan-1.dll", CallingConvention = CallingConvention.Winapi)]
    static extern void vkGetPhysicalDeviceQueueFamilyProperties(
        IntPtr physicalDevice,
        ref uint pQueueFamilyPropertyCount,
        IntPtr pQueueFamilyProperties 
    );

    [DllImport("vulkan-1.dll", CallingConvention = CallingConvention.Winapi)]
    static extern void vkGetPhysicalDeviceQueueFamilyProperties(
        IntPtr physicalDevice,
        ref uint pQueueFamilyPropertyCount,
        [Out] VkQueueFamilyProperties[] pQueueFamilyProperties
    );

    [DllImport("vulkan-1.dll", CallingConvention = CallingConvention.Winapi)]
    private static extern VkResult vkGetPhysicalDeviceSurfaceSupportKHR(
        IntPtr physicalDevice,
        uint queueFamilyIndex,
        IntPtr surface,
        out VkBool32 pSupported
    );

    [DllImport("vulkan-1.dll", CallingConvention = CallingConvention.Winapi)]
    private static extern VkResult vkCreateWin32SurfaceKHR(
        IntPtr instance,
        ref VkWin32SurfaceCreateInfoKHR pCreateInfo,
        IntPtr pAllocator,
        out IntPtr pSurface
    );

    [DllImport("vulkan-1.dll")]
    static extern void vkGetDeviceQueue(
        IntPtr device,
        uint queueFamilyIndex,
        uint queueIndex,
        out IntPtr pQueue);


    [DllImport("vulkan-1.dll")]
    static extern IntPtr vkGetInstanceProcAddr(IntPtr instance, string name);

    [DllImport("vulkan-1.dll", CallingConvention = CallingConvention.Winapi)]
    public static extern VkResult vkCreateSwapchainKHR(
        IntPtr device,
        ref VkSwapchainCreateInfoKHR pCreateInfo,
        IntPtr pAllocator,
        out IntPtr pSwapchain
    );

    [DllImport("vulkan-1.dll", CallingConvention = CallingConvention.Winapi)]
    public static extern VkResult vkGetSwapchainImagesKHR(
        IntPtr device,
        IntPtr swapchain,
        ref uint pSwapchainImageCount,
        [Optional] IntPtr pSwapchainImages
    );

    [DllImport("vulkan-1.dll", CallingConvention = CallingConvention.Winapi)]
    public static extern VkResult vkCreateRenderPass(
        IntPtr device,
        ref VkRenderPassCreateInfo pCreateInfo,
        IntPtr pAllocator,
        out IntPtr pRenderPass
    );

    [DllImport("vulkan-1.dll", CallingConvention = CallingConvention.Winapi)]
    public static extern void vkGetPhysicalDeviceFormatProperties(
        IntPtr physicalDevice,
        VkFormat format,
        out VkFormatProperties pFormatProperties
    );

    [DllImport("vulkan-1.dll", CallingConvention = CallingConvention.Winapi)]
    public static extern VkResult vkCreateShaderModule(
        IntPtr device,                              
        ref VkShaderModuleCreateInfo createInfo,    
        IntPtr pAllocator,                          
        out IntPtr pShaderModule                    
    );

    [DllImport("vulkan-1.dll", CallingConvention = CallingConvention.Winapi)]
    public static extern VkResult vkCreatePipelineLayout(
        IntPtr device, 
        ref VkPipelineLayoutCreateInfo pCreateInfo, 
        IntPtr pAllocator, 
        out IntPtr pPipelineLayout 
    );

    [DllImport("vulkan-1.dll", CallingConvention = CallingConvention.Winapi)]
    public static extern VkResult vkCreateGraphicsPipelines(
        IntPtr device,
        IntPtr pipelineCache,
        uint createInfoCount,
        IntPtr pCreateInfos, 
        IntPtr pAllocator,
        out IntPtr pPipelines 
    );

    [DllImport("vulkan-1.dll")]
    static extern VkResult vkAcquireNextImageKHR(IntPtr device, IntPtr swapchain, ulong timeout,
        IntPtr semaphore, IntPtr fence, ref uint pImageIndex);

    [DllImport("vulkan-1.dll")]
    static extern VkResult vkBeginCommandBuffer(IntPtr commandBuffer, ref VkCommandBufferBeginInfo pBeginInfo);

    [DllImport("vulkan-1.dll")]
    static extern void vkCmdBeginRenderPass(IntPtr commandBuffer, ref VkRenderPassBeginInfo pRenderPassBegin,
        VkSubpassContents contents);

    [DllImport("vulkan-1.dll")]
    static extern void vkCmdBindPipeline(IntPtr commandBuffer, VkPipelineBindPoint pipelineBindPoint,
        IntPtr pipeline);

    [DllImport("vulkan-1.dll")]
    static extern void vkCmdDraw(IntPtr commandBuffer, uint vertexCount, uint instanceCount,
        uint firstVertex, uint firstInstance);

    [DllImport("vulkan-1.dll")]
    static extern void vkCmdEndRenderPass(IntPtr commandBuffer);

    [DllImport("vulkan-1.dll")]
    static extern VkResult vkEndCommandBuffer(IntPtr commandBuffer);

    [DllImport("vulkan-1.dll")]
    static extern VkResult vkQueueSubmit(IntPtr queue, uint submitCount, ref VkSubmitInfo pSubmits,
        IntPtr fence);

    [DllImport("vulkan-1.dll")]
    static extern VkResult vkQueuePresentKHR(IntPtr queue, ref VkPresentInfoKHR pPresentInfo);

    [DllImport("vulkan-1.dll")]
    static extern VkResult vkCreateFramebuffer(IntPtr device, ref VkFramebufferCreateInfo pCreateInfo,
        IntPtr pAllocator, out IntPtr pFramebuffer);

    [DllImport("vulkan-1.dll")]
    static extern VkResult vkCreateCommandPool(IntPtr device, ref VkCommandPoolCreateInfo pCreateInfo,
        IntPtr pAllocator, out IntPtr pCommandPool);

    [DllImport("vulkan-1.dll")]
    static extern VkResult vkAllocateCommandBuffers(IntPtr device, ref VkCommandBufferAllocateInfo pAllocateInfo,
        out IntPtr pCommandBuffers);

    [DllImport("vulkan-1.dll")]
    static extern void vkDestroyFramebuffer(IntPtr device, IntPtr framebuffer, IntPtr pAllocator);

    [DllImport("vulkan-1.dll")]
    static extern void vkDestroyPipeline(IntPtr device, IntPtr pipeline, IntPtr pAllocator);

    [DllImport("vulkan-1.dll")]
    static extern void vkDestroyPipelineLayout(IntPtr device, IntPtr pipelineLayout, IntPtr pAllocator);

    [DllImport("vulkan-1.dll")]
    static extern void vkDestroyRenderPass(IntPtr device, IntPtr renderPass, IntPtr pAllocator);

    [DllImport("vulkan-1.dll")]
    static extern void vkDestroyImageView(IntPtr device, IntPtr imageView, IntPtr pAllocator);

    [DllImport("vulkan-1.dll")]
    static extern void vkDestroySwapchainKHR(IntPtr device, IntPtr swapchain, IntPtr pAllocator);

    [DllImport("vulkan-1.dll")]
    static extern void vkDestroyDevice(IntPtr device, IntPtr pAllocator);

    [DllImport("vulkan-1.dll")]
    static extern void vkDestroySurfaceKHR(IntPtr instance, IntPtr surface, IntPtr pAllocator);

    [DllImport("vulkan-1.dll")]
    static extern void vkDestroyInstance(IntPtr instance, IntPtr pAllocator);

    [DllImport("vulkan-1.dll", CallingConvention = CallingConvention.Cdecl)]
    public static extern VkResult vkCreateSemaphore(
        IntPtr device,
        ref VkSemaphoreCreateInfo pCreateInfo,
        IntPtr pAllocator,
        out IntPtr pSemaphore
    );

    [DllImport("vulkan-1.dll", CallingConvention = CallingConvention.Cdecl)]
    public static extern IntPtr vkGetDeviceProcAddr(IntPtr device, string pName);

    [DllImport("vulkan-1.dll")]
    public static extern VkResult vkCreateImage(IntPtr device, ref VkImageCreateInfo pCreateInfo, IntPtr pAllocator, out IntPtr pImage);

    [DllImport("vulkan-1.dll")]
    public static extern void vkGetImageMemoryRequirements(IntPtr device, IntPtr image, out VkMemoryRequirements pMemoryRequirements);

    [DllImport("vulkan-1.dll")]
    public static extern VkResult vkAllocateMemory(IntPtr device, ref VkMemoryAllocateInfo pAllocateInfo, IntPtr pAllocator, out IntPtr pMemory);

    [DllImport("vulkan-1.dll")]
    public static extern VkResult vkBindImageMemory(IntPtr device, IntPtr image, IntPtr memory, ulong memoryOffset);

    [DllImport("vulkan-1.dll")]
    static extern void vkGetPhysicalDeviceMemoryProperties(IntPtr physicalDevice, out VkPhysicalDeviceMemoryProperties pMemoryProperties);

    [DllImport("vulkan-1.dll", CallingConvention = CallingConvention.Winapi)]
    public static extern VkResult vkDeviceWaitIdle(IntPtr device);

    [DllImport("vulkan-1.dll", CallingConvention = CallingConvention.Winapi)]
    public static extern void vkDestroySemaphore(IntPtr device, IntPtr semaphore, IntPtr pAllocator);

    [DllImport("vulkan-1.dll", CallingConvention = CallingConvention.Winapi)]
    public static extern void vkDestroyFence(IntPtr device, IntPtr fence, IntPtr pAllocator);

    [DllImport("vulkan-1.dll", CallingConvention = CallingConvention.Winapi)]
    public static extern void vkDestroyDebugUtilsMessengerEXT(IntPtr instance, IntPtr messenger, IntPtr pAllocator);

    [DllImport("vulkan-1.dll", CallingConvention = CallingConvention.Winapi)]
    public static extern void vkDestroyCommandPool(IntPtr device, IntPtr commandPool, IntPtr pAllocator);

    [DllImport("vulkan-1.dll", CallingConvention = CallingConvention.Winapi)]
    public static extern void vkDestroyShaderModule(IntPtr device, IntPtr shaderModule, IntPtr pAllocator);

    [DllImport("vulkan-1.dll", CallingConvention = CallingConvention.Winapi)]
    public static extern void vkFreeMemory(IntPtr device, IntPtr memory, IntPtr pAllocator);

    [DllImport("vulkan-1.dll", CallingConvention = CallingConvention.Winapi)]
    public static extern void vkDestroyImage(IntPtr device, IntPtr image, IntPtr pAllocator);

    [UnmanagedFunctionPointer(CallingConvention.Cdecl)]
    public delegate uint VkDebugUtilsMessengerCallbackEXT(
        VkDebugUtilsMessageSeverityFlagsEXT messageSeverity,
        VkDebugUtilsMessageTypeFlagsEXT messageType,
        IntPtr pCallbackData,
        IntPtr pUserData);

    [UnmanagedFunctionPointer(CallingConvention.Cdecl)]
    delegate VkResult vkCreateDebugUtilsMessengerEXTFunc(
        IntPtr instance,
        ref VkDebugUtilsMessengerCreateInfoEXT pCreateInfo,
        IntPtr pAllocator,
        out IntPtr pMessenger
    );

    [UnmanagedFunctionPointer(CallingConvention.Winapi)]
    private delegate void vkDestroyDebugUtilsMessengerEXTFunc(IntPtr instance, IntPtr messenger, IntPtr pAllocator);

    [UnmanagedFunctionPointer(CallingConvention.Cdecl)]
    public delegate VkBool32 DebugUtilsMessengerCallbackEXT(
        VkDebugUtilsMessageSeverityFlagsEXT messageSeverity,
        VkDebugUtilsMessageTypeFlagsEXT messageType,
        IntPtr pCallbackData,
        IntPtr pUserData);

    [UnmanagedFunctionPointer(CallingConvention.Cdecl)]
    public delegate VkResult vkCreateFenceDelegate(
        IntPtr device,
        ref VkFenceCreateInfo pCreateInfo,
        IntPtr pAllocator,
        out IntPtr pFence
    );

    [UnmanagedFunctionPointer(CallingConvention.Cdecl)]
    public delegate VkResult vkCreateImageViewDelegate(
        IntPtr device,
        ref VkImageViewCreateInfo pCreateInfo,
        IntPtr pAllocator,
        out IntPtr pView
    );

    [UnmanagedFunctionPointer(CallingConvention.Cdecl)]
    public delegate VkResult vkWaitForFencesDelegate(IntPtr device, uint fenceCount, ref IntPtr pFences, VkBool32 waitAll, ulong timeout);

    [UnmanagedFunctionPointer(CallingConvention.Cdecl)]
    public delegate VkResult vkResetFencesDelegate(IntPtr device, uint fenceCount, ref IntPtr pFences);


    private readonly string[] deviceExtensions = {
        "VK_KHR_swapchain"
    };

    public static class VulkanConstants
    {
        public const uint VK_ATTACHMENT_UNUSED = ~0u; 
        public const uint VK_SUBPASS_EXTERNAL = ~0u; 
    }

    public static class VkVersion
    {
        public static uint MakeVersion(int major, int minor, int patch)
        {
            return (uint)((major << 22) | (minor << 12) | patch);
        }
    }

    private bool isInitialized = false;
    private VkFormat swapChainImageFormat; 
    private VkExtent2D swapChainExtent;    
    private IntPtr vertShaderModule;
    private IntPtr fragShaderModule;
    private IntPtr graphicsQueue; 
    private IntPtr presentQueue; 
    private IntPtr pipelineLayout;
    private IntPtr graphicsPipeline;
    private IntPtr[] swapChainFramebuffers;
    private IntPtr commandPool;
    private IntPtr commandBuffer;

    private IntPtr[] swapChainImages;
    private IntPtr[] swapChainImageViews;

    private IntPtr depthImage;
    private IntPtr depthImageMemory;
    private IntPtr depthImageView;

    private IntPtr[] imageAvailableSemaphores;
    private IntPtr[] renderFinishedSemaphores;
    private IntPtr[] inFlightFences;
    private IntPtr[] imagesInFlight;

    private vkCreateFenceDelegate vkCreateFence;
    private vkCreateImageViewDelegate vkCreateImageView;
    private vkWaitForFencesDelegate vkWaitForFences;
    private vkResetFencesDelegate vkResetFences;

    private int frameIndex = 0;

    private const int MAX_FRAMES_IN_FLIGHT = 2;

    IntPtr instance;
    IntPtr physicalDevice = IntPtr.Zero;
    IntPtr device;
    IntPtr surface;
    IntPtr swapChain;
    IntPtr renderPass;
    
    IntPtr debugMessenger;

    public HelloForm()
    {
        this.Size = new Size( 640, 480 );
        this.Text = "Hello, World!";
    }
    protected override void OnHandleCreated(EventArgs e)
    {
        base.OnHandleCreated(e);
        Initialize();
        isInitialized = true;
    }
    
    protected override void OnPaint(PaintEventArgs e) {  
        base.OnPaint(e); 
        DrawFrame();
    }
    
    protected override void OnResize(EventArgs e)
    {
        base.OnResize(e);
        if (isInitialized)
        {
            RecreateSwapChain();
        }
    }

    protected override void OnClosed(EventArgs e) {
        base.OnClosed(e);
        Cleanup();
    }


    private static VkBool32 DebugCallback(
        VkDebugUtilsMessageSeverityFlagsEXT messageSeverity,
        VkDebugUtilsMessageTypeFlagsEXT messageType,
        IntPtr pCallbackData,
        IntPtr pUserData)
    {
        var callbackData = Marshal.PtrToStructure<VkDebugUtilsMessengerCallbackDataEXT>(pCallbackData);
        Console.WriteLine($"[Vulkan Debug] {callbackData.pMessage}");
        return VkBool32.False;
    }

    public void Initialize()
    {
        Console.WriteLine("----------------------------------------");
        Console.WriteLine("[HelloForm::Initialize] - Start");

        CreateInstance();
        CreateSurface();
        CreateDevice();
        CreateSwapChain();
        CreateRenderPass();
        CreateGraphicsPipeline();

        CreateCommandPool(); 
        CreateDepthResources();
        CreateFramebuffers(); 
        CreateCommandBuffers(); 
        CreateSyncObjects(); 

        Console.WriteLine("[HelloForm::Initialize] - End");
    }

    private void CreateInstance()
    {
        Console.WriteLine("----------------------------------------");
        Console.WriteLine("[HelloForm::CreateInstance] - Start");

        IntPtr appNamePtr = Marshal.StringToHGlobalAnsi("Hello Triangle");
        IntPtr engineNamePtr = Marshal.StringToHGlobalAnsi("No Engine");

        DebugUtilsMessengerCallbackEXT DebugCallback = (messageSeverity, messageType, pCallbackData, pUserData) =>
        {
            var callbackData = Marshal.PtrToStructure<VkDebugUtilsMessengerCallbackDataEXT>(pCallbackData);
            Console.WriteLine($"[Vulkan Debug] Severity: {messageSeverity}, Type: {messageType}, Message: {Marshal.PtrToStringAnsi(callbackData.pMessage)}");
            return VkBool32.False;
        };

        try
        {
            var appInfo = new VkApplicationInfo
            {
                sType = VkStructureType.VK_STRUCTURE_TYPE_APPLICATION_INFO,
                pNext = IntPtr.Zero,
                pApplicationName = appNamePtr,
                applicationVersion = VkVersion.MakeVersion(1, 0, 0),
                pEngineName = engineNamePtr,
                engineVersion = VkVersion.MakeVersion(1, 0, 0),
                apiVersion = VkVersion.MakeVersion(1, 3, 0)
            };

            string[] layers = { "VK_LAYER_KHRONOS_validation" };

            string[] extensions = {
                "VK_EXT_debug_utils",   
                "VK_KHR_surface",       
                "VK_KHR_win32_surface"  
            };

            var debugCreateInfo = new VkDebugUtilsMessengerCreateInfoEXT
            {
                sType = VkStructureType.VK_STRUCTURE_TYPE_DEBUG_UTILS_MESSENGER_CREATE_INFO_EXT,
                pNext = IntPtr.Zero,
                flags = 0,
                messageSeverity = VkDebugUtilsMessageSeverityFlagsEXT.VK_DEBUG_UTILS_MESSAGE_SEVERITY_VERBOSE_BIT_EXT |
                                  VkDebugUtilsMessageSeverityFlagsEXT.VK_DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT |
                                  VkDebugUtilsMessageSeverityFlagsEXT.VK_DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT,
                messageType = VkDebugUtilsMessageTypeFlagsEXT.VK_DEBUG_UTILS_MESSAGE_TYPE_GENERAL_BIT_EXT |
                              VkDebugUtilsMessageTypeFlagsEXT.VK_DEBUG_UTILS_MESSAGE_TYPE_VALIDATION_BIT_EXT |
                              VkDebugUtilsMessageTypeFlagsEXT.VK_DEBUG_UTILS_MESSAGE_TYPE_PERFORMANCE_BIT_EXT,
                pfnUserCallback = Marshal.GetFunctionPointerForDelegate(DebugCallback),
                pUserData = IntPtr.Zero
            };

            IntPtr[] layerPtrs = layers.Select(l => Marshal.StringToHGlobalAnsi(l)).ToArray();
            IntPtr layersPtr = Marshal.AllocHGlobal(IntPtr.Size * layerPtrs.Length);
            Marshal.Copy(layerPtrs, 0, layersPtr, layerPtrs.Length);

            IntPtr[] extensionPtrs = extensions.Select(e => Marshal.StringToHGlobalAnsi(e)).ToArray();
            IntPtr extensionsPtr = Marshal.AllocHGlobal(IntPtr.Size * extensionPtrs.Length);
            Marshal.Copy(extensionPtrs, 0, extensionsPtr, extensionPtrs.Length);

            var createInfo = new VkInstanceCreateInfo
            {
                sType = VkStructureType.VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
                pNext = Marshal.AllocHGlobal(Marshal.SizeOf(debugCreateInfo)),
                flags = 0,
                pApplicationInfo = Marshal.AllocHGlobal(Marshal.SizeOf(appInfo)),
                enabledLayerCount = (uint)layers.Length,
                ppEnabledLayerNames = layersPtr,
                enabledExtensionCount = (uint)extensions.Length,
                ppEnabledExtensionNames = extensionsPtr
            };

            Marshal.StructureToPtr(appInfo, createInfo.pApplicationInfo, false);
            Marshal.StructureToPtr(debugCreateInfo, createInfo.pNext, false);

            VkResult result = (VkResult)vkCreateInstance(ref createInfo, IntPtr.Zero, out instance);
            if (result != VkResult.VK_SUCCESS)
            {
                throw new Exception("Failed to create Vulkan instance.");
            }
            Console.WriteLine("Vulkan instance created successfully.");

            IntPtr vkCreateDebugUtilsMessengerEXTPtr = vkGetInstanceProcAddr(instance, "vkCreateDebugUtilsMessengerEXT");
            var vkCreateDebugUtilsMessengerEXT = (vkCreateDebugUtilsMessengerEXTFunc)Marshal.GetDelegateForFunctionPointer(
                vkCreateDebugUtilsMessengerEXTPtr, typeof(vkCreateDebugUtilsMessengerEXTFunc));
            if (vkCreateDebugUtilsMessengerEXT(instance, ref debugCreateInfo, IntPtr.Zero, out debugMessenger) != VkResult.VK_SUCCESS)
            {
                throw new Exception("Failed to create debug messenger.");
            }

            Console.WriteLine("Debug messenger created successfully.");

            foreach (var ptr in layerPtrs) Marshal.FreeHGlobal(ptr);
            foreach (var ptr in extensionPtrs) Marshal.FreeHGlobal(ptr);
            Marshal.FreeHGlobal(layersPtr);
            Marshal.FreeHGlobal(extensionsPtr);
            Marshal.FreeHGlobal(createInfo.pNext);
            Marshal.FreeHGlobal(createInfo.pApplicationInfo);
        }
        finally
        {
            Marshal.FreeHGlobal(appNamePtr);
            Marshal.FreeHGlobal(engineNamePtr);
        }
    }

    private void CreateSurface()
    {
        Console.WriteLine("----------------------------------------");
        Console.WriteLine("[HelloForm::CreateSurface] - Start");

        var surfaceCreateInfo = new VkWin32SurfaceCreateInfoKHR
        {
            sType = VkStructureType.VK_STRUCTURE_TYPE_WIN32_SURFACE_CREATE_INFO_KHR,
            hinstance = GetModuleHandle(null), // hInstance, 
            hwnd = this.Handle // hWnd
        };

        VkResult result = vkCreateWin32SurfaceKHR(instance, ref surfaceCreateInfo, IntPtr.Zero, out surface);
        if (result != VkResult.VK_SUCCESS)
        {
            throw new Exception("Failed to create Win32 surface!");
        }

        Console.WriteLine($"Surface created: {surface}");
    }


    void CreateDevice()
    {
        Console.WriteLine("----------------------------------------");
        Console.WriteLine("[HelloForm::CreateDevice] - Start");

        uint deviceCount = 0;
        vkEnumeratePhysicalDevices(instance, ref deviceCount, null);
        var devices = new IntPtr[deviceCount];
        vkEnumeratePhysicalDevices(instance, ref deviceCount, devices);

        foreach (var device in devices)
        {
            if (IsDeviceSuitable(device))
            {
                physicalDevice = device;
                break;
            }
        }

        if (physicalDevice == IntPtr.Zero)
        {
            throw new Exception("Failed to find a suitable GPU!");
        }

        var propertiesPtr = Marshal.AllocHGlobal(Marshal.SizeOf<VkPhysicalDeviceProperties>());
        try
        {
            vkGetPhysicalDeviceProperties(physicalDevice, propertiesPtr);
            var properties = Marshal.PtrToStructure<VkPhysicalDeviceProperties>(propertiesPtr);
            var name = System.Text.Encoding.UTF8.GetString(properties.deviceName).TrimEnd('\0');
            Console.WriteLine($"Selected Device: {name}");
        }
        finally
        {
            Marshal.FreeHGlobal(propertiesPtr);
        }

        CreateLogicalDevice();

        LoadVulkanFunctions();

        Console.WriteLine("[HelloForm::CreateDevice] - End");
    }

    private void CreateSwapChain()
    {
        Console.WriteLine("----------------------------------------");
        Console.WriteLine("[HelloForm::CreateSwapChain] - Start");

        var swapChainSupport = QuerySwapChainSupport(physicalDevice);

        var surfaceFormat = ChooseSwapSurfaceFormat(swapChainSupport.formats);
        var presentMode = ChooseSwapPresentMode(swapChainSupport.presentModes);
        var extent = ChooseSwapExtent(swapChainSupport.capabilities);

        uint imageCount = swapChainSupport.capabilities.minImageCount + 1;
        if (swapChainSupport.capabilities.maxImageCount > 0 && imageCount > swapChainSupport.capabilities.maxImageCount)
        {
            imageCount = swapChainSupport.capabilities.maxImageCount;
        }

        var createInfo = new VkSwapchainCreateInfoKHR
        {
            sType = VkStructureType.VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR,
            surface = surface,
            minImageCount = imageCount,
            imageFormat = surfaceFormat.format,
            imageColorSpace = surfaceFormat.colorSpace,
            imageExtent = extent,
            imageArrayLayers = 1,
            imageUsage = VkImageUsageFlags.VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT
        };

        QueueFamilyIndices indices = FindQueueFamilies(physicalDevice);
        uint[] queueFamilyIndices = { (uint)indices.GraphicsFamily.Value, (uint)indices.PresentFamily.Value };

        if (indices.GraphicsFamily != indices.PresentFamily)
        {
            createInfo.imageSharingMode = VkSharingMode.VK_SHARING_MODE_CONCURRENT;
            createInfo.queueFamilyIndexCount = (uint)queueFamilyIndices.Length;

            GCHandle queueFamilyHandle = GCHandle.Alloc(queueFamilyIndices, GCHandleType.Pinned);
            createInfo.pQueueFamilyIndices = queueFamilyHandle.AddrOfPinnedObject();
        }
        else
        {
            createInfo.imageSharingMode = VkSharingMode.VK_SHARING_MODE_EXCLUSIVE;
        }

        if ((swapChainSupport.capabilities.supportedTransforms & VkSurfaceTransformFlagsKHR.VK_SURFACE_TRANSFORM_IDENTITY_BIT_KHR) != 0)
        {
            createInfo.preTransform = (VkSurfaceTransformFlagBitsKHR)VkSurfaceTransformFlagsKHR.VK_SURFACE_TRANSFORM_IDENTITY_BIT_KHR;
        }
        else
        {
            createInfo.preTransform = (VkSurfaceTransformFlagBitsKHR)swapChainSupport.capabilities.currentTransform;
        }

        if ((swapChainSupport.capabilities.supportedCompositeAlpha & VkCompositeAlphaFlagsKHR.VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR) != 0)
        {
            createInfo.compositeAlpha = VkCompositeAlphaFlagsKHR.VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR;
        }
        else
        {
            createInfo.compositeAlpha = (VkCompositeAlphaFlagsKHR)swapChainSupport.capabilities.supportedCompositeAlpha;
        }

        VkResult result = vkCreateSwapchainKHR(device, ref createInfo, IntPtr.Zero, out swapChain);
        if (result != VkResult.VK_SUCCESS)
        {
            throw new Exception($"Failed to create swap chain! Error code: {result}");
        }

        vkGetSwapchainImagesKHR(device, swapChain, ref imageCount, IntPtr.Zero);
        swapChainImages = new IntPtr[imageCount];
        GCHandle imageHandle = GCHandle.Alloc(swapChainImages, GCHandleType.Pinned);

        try
        {
            IntPtr imagePointer = imageHandle.AddrOfPinnedObject();
            result = vkGetSwapchainImagesKHR(device, swapChain, ref imageCount, imagePointer);
            if (result != VkResult.VK_SUCCESS)
            {
                throw new Exception($"Failed to get swap chain images! Error code: {result}");
            }

            Console.WriteLine($"[HelloForm::CreateSwapChain] - Swap chain images initialized. Count: {imageCount}");
        }
        finally
        {
            imageHandle.Free();
        }

        swapChainImageFormat = surfaceFormat.format;
        swapChainExtent = extent;

        CreateSwapChainImageViews();

        Console.WriteLine("[HelloForm::CreateSwapChain] - End");
    }

    private void CreateRenderPass()
    {
        Console.WriteLine("----------------------------------------");
        Console.WriteLine("[HelloForm::CreateRenderPass] - Start");

        var colorAttachment = new VkAttachmentDescription
        {
            format = swapChainImageFormat,
            samples = VkSampleCountFlags.VK_SAMPLE_COUNT_1_BIT,
            loadOp = VkAttachmentLoadOp.VK_ATTACHMENT_LOAD_OP_CLEAR,
            storeOp = VkAttachmentStoreOp.VK_ATTACHMENT_STORE_OP_STORE,
            stencilLoadOp = VkAttachmentLoadOp.VK_ATTACHMENT_LOAD_OP_DONT_CARE,
            stencilStoreOp = VkAttachmentStoreOp.VK_ATTACHMENT_STORE_OP_DONT_CARE,
            initialLayout = VkImageLayout.VK_IMAGE_LAYOUT_UNDEFINED,
            finalLayout = VkImageLayout.VK_IMAGE_LAYOUT_PRESENT_SRC_KHR
        };

        var colorAttachmentRef = new VkAttachmentReference
        {
            attachment = 0,
            layout = VkImageLayout.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL
        };

        var dependency = new VkSubpassDependency
        {
            srcSubpass = VulkanConstants.VK_SUBPASS_EXTERNAL,
            dstSubpass = 0,
            srcStageMask = VkPipelineStageFlags.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT,
            srcAccessMask = 0,
            dstStageMask = VkPipelineStageFlags.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT,
            dstAccessMask = VkAccessFlags.VK_ACCESS_COLOR_ATTACHMENT_READ_BIT | VkAccessFlags.VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT
        };

        GCHandle colorAttachmentRefHandle = GCHandle.Alloc(colorAttachmentRef, GCHandleType.Pinned);
        GCHandle dependencyHandle = GCHandle.Alloc(dependency, GCHandleType.Pinned);
        GCHandle attachmentsHandle = GCHandle.Alloc(new[] { colorAttachment }, GCHandleType.Pinned);

        try
        {
            var subpass = new VkSubpassDescription
            {
                pipelineBindPoint = VkPipelineBindPoint.VK_PIPELINE_BIND_POINT_GRAPHICS,
                colorAttachmentCount = 1,
                pColorAttachments = colorAttachmentRefHandle.AddrOfPinnedObject(),
                pDepthStencilAttachment = IntPtr.Zero
            };

            GCHandle subpassHandle = GCHandle.Alloc(new[] { subpass }, GCHandleType.Pinned);

            try
            {
                var renderPassInfo = new VkRenderPassCreateInfo
                {
                    sType = VkStructureType.VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO,
                    attachmentCount = 1,
                    pAttachments = attachmentsHandle.AddrOfPinnedObject(),
                    subpassCount = 1,
                    pSubpasses = subpassHandle.AddrOfPinnedObject(),
                    dependencyCount = 1,
                    pDependencies = dependencyHandle.AddrOfPinnedObject()
                };

                VkResult result = vkCreateRenderPass(device, ref renderPassInfo, IntPtr.Zero, out renderPass);
                if (result != VkResult.VK_SUCCESS)
                {
                    throw new Exception($"Failed to create render pass! Error code: {result}");
                }
            }
            finally
            {
                subpassHandle.Free();
            }
        }
        finally
        {
            colorAttachmentRefHandle.Free();
            dependencyHandle.Free();
            attachmentsHandle.Free();
        }

        Console.WriteLine("Render pass created successfully.");
        Console.WriteLine("[HelloForm::CreateRenderPass] - End");
    }

    void CreateGraphicsPipeline()
    {
        Console.WriteLine("----------------------------------------");
        Console.WriteLine("[HelloForm::CreateGraphicsPipeline] - Start");

        vertShaderModule = LoadShaderModule("hello_vert.spv");
        fragShaderModule = LoadShaderModule("hello_frag.spv");

        if (vertShaderModule == IntPtr.Zero || fragShaderModule == IntPtr.Zero)
        {
            throw new Exception("Failed to load shader modules.");
        }

        Console.WriteLine($"Vertex Shader Module: {vertShaderModule}");
        Console.WriteLine($"Fragment Shader Module: {fragShaderModule}");

        IntPtr vertShaderNamePtr = Marshal.StringToHGlobalAnsi("main");
        IntPtr fragShaderNamePtr = Marshal.StringToHGlobalAnsi("main");

        var vertShaderStageInfo = new VkPipelineShaderStageCreateInfo
        {
            sType = VkStructureType.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
            stage = VkShaderStageFlags.VK_SHADER_STAGE_VERTEX_BIT,
            module = vertShaderModule,
            pName = vertShaderNamePtr,
            pSpecializationInfo = IntPtr.Zero
        };

        var fragShaderStageInfo = new VkPipelineShaderStageCreateInfo
        {
            sType = VkStructureType.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
            stage = VkShaderStageFlags.VK_SHADER_STAGE_FRAGMENT_BIT,
            module = fragShaderModule,
            pName = fragShaderNamePtr,
            pSpecializationInfo = IntPtr.Zero
        };

        Console.WriteLine($"Shader stage create info - Vertex: {vertShaderStageInfo.stage}, Fragment: {fragShaderStageInfo.stage}");
        Console.WriteLine($"Entry point names - Vertex: {Marshal.PtrToStringAnsi(vertShaderStageInfo.pName)}, Fragment: {Marshal.PtrToStringAnsi(fragShaderStageInfo.pName)}");

        var shaderStages = new[] { vertShaderStageInfo, fragShaderStageInfo };

        var vertexInputInfo = new VkPipelineVertexInputStateCreateInfo
        {
            sType = VkStructureType.VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO,
            vertexBindingDescriptionCount = 0,
            pVertexBindingDescriptions = IntPtr.Zero,
            vertexAttributeDescriptionCount = 0,
            pVertexAttributeDescriptions = IntPtr.Zero
        };

        var inputAssembly = new VkPipelineInputAssemblyStateCreateInfo
        {
            sType = VkStructureType.VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO,
            topology = VkPrimitiveTopology.VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST,
            primitiveRestartEnable = VkBool32.False
        };

        var viewport = new VkViewport
        {
            x = 0.0f,
            y = 0.0f,
            width = swapChainExtent.width,
            height = swapChainExtent.height,
            minDepth = 0.0f,
            maxDepth = 1.0f
        };

        var scissor = new VkRect2D
        {
            offset = new VkOffset2D { x = 0, y = 0 },
            extent = swapChainExtent
        };

        var viewportState = new VkPipelineViewportStateCreateInfo
        {
            sType = VkStructureType.VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO,
            viewportCount = 1,
            pViewports = Marshal.AllocHGlobal(Marshal.SizeOf<VkViewport>()),
            scissorCount = 1,
            pScissors = Marshal.AllocHGlobal(Marshal.SizeOf<VkRect2D>())
        };

        Marshal.StructureToPtr(viewport, viewportState.pViewports, false);
        Marshal.StructureToPtr(scissor, viewportState.pScissors, false);

        var rasterizer = new VkPipelineRasterizationStateCreateInfo
        {
            sType = VkStructureType.VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO,
            depthClampEnable = VkBool32.False,
            rasterizerDiscardEnable = VkBool32.False,
            polygonMode = VkPolygonMode.VK_POLYGON_MODE_FILL,
            lineWidth = 1.0f,
            cullMode = VkCullModeFlags.VK_CULL_MODE_BACK_BIT,
            frontFace = VkFrontFace.VK_FRONT_FACE_CLOCKWISE,
            depthBiasEnable = VkBool32.False
        };

        var multisampling = new VkPipelineMultisampleStateCreateInfo
        {
            sType = VkStructureType.VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO,
            rasterizationSamples = VkSampleCountFlags.VK_SAMPLE_COUNT_1_BIT,
            sampleShadingEnable = VkBool32.False
        };

        var depthStencil = new VkPipelineDepthStencilStateCreateInfo
        {
            sType = VkStructureType.VK_STRUCTURE_TYPE_PIPELINE_DEPTH_STENCIL_STATE_CREATE_INFO,
            depthTestEnable = VkBool32.True,
            depthWriteEnable = VkBool32.True,
            depthCompareOp = VkCompareOp.VK_COMPARE_OP_LESS,
            depthBoundsTestEnable = VkBool32.False,
            stencilTestEnable = VkBool32.False
        };

        var colorBlendAttachment = new VkPipelineColorBlendAttachmentState
        {
            colorWriteMask = VkColorComponentFlags.VK_COLOR_COMPONENT_R_BIT |
                             VkColorComponentFlags.VK_COLOR_COMPONENT_G_BIT |
                             VkColorComponentFlags.VK_COLOR_COMPONENT_B_BIT |
                             VkColorComponentFlags.VK_COLOR_COMPONENT_A_BIT,
            blendEnable = VkBool32.False
        };

        var colorBlending = new VkPipelineColorBlendStateCreateInfo
        {
            sType = VkStructureType.VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO,
            logicOpEnable = VkBool32.False,
            attachmentCount = 1,
            pAttachments = Marshal.AllocHGlobal(Marshal.SizeOf<VkPipelineColorBlendAttachmentState>())
        };

        Marshal.StructureToPtr(colorBlendAttachment, colorBlending.pAttachments, false);

        var pipelineLayoutInfo = new VkPipelineLayoutCreateInfo
        {
            sType = VkStructureType.VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO
        };

        if (vkCreatePipelineLayout(device, ref pipelineLayoutInfo, IntPtr.Zero, out pipelineLayout) != VkResult.VK_SUCCESS)
        {
            throw new Exception("Failed to create pipeline layout.");
        }

        var pipelineInfo = new VkGraphicsPipelineCreateInfo
        {
            sType = VkStructureType.VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO,
            stageCount = (uint)shaderStages.Length,
            pStages = Marshal.UnsafeAddrOfPinnedArrayElement(shaderStages, 0),
            pVertexInputState = Marshal.AllocHGlobal(Marshal.SizeOf<VkPipelineVertexInputStateCreateInfo>()),
            pInputAssemblyState = Marshal.AllocHGlobal(Marshal.SizeOf<VkPipelineInputAssemblyStateCreateInfo>()),
            pViewportState = Marshal.AllocHGlobal(Marshal.SizeOf<VkPipelineViewportStateCreateInfo>()),
            pRasterizationState = Marshal.AllocHGlobal(Marshal.SizeOf<VkPipelineRasterizationStateCreateInfo>()),
            pMultisampleState = Marshal.AllocHGlobal(Marshal.SizeOf<VkPipelineMultisampleStateCreateInfo>()),
            pDepthStencilState = Marshal.AllocHGlobal(Marshal.SizeOf<VkPipelineDepthStencilStateCreateInfo>()),
            pColorBlendState = Marshal.AllocHGlobal(Marshal.SizeOf<VkPipelineColorBlendStateCreateInfo>()),
            layout = pipelineLayout,
            renderPass = renderPass,
            subpass = 0
        };

        Marshal.StructureToPtr(vertexInputInfo, pipelineInfo.pVertexInputState, false);
        Marshal.StructureToPtr(inputAssembly, pipelineInfo.pInputAssemblyState, false);
        Marshal.StructureToPtr(viewportState, pipelineInfo.pViewportState, false);
        Marshal.StructureToPtr(rasterizer, pipelineInfo.pRasterizationState, false);
        Marshal.StructureToPtr(multisampling, pipelineInfo.pMultisampleState, false);
        Marshal.StructureToPtr(depthStencil, pipelineInfo.pDepthStencilState, false);
        Marshal.StructureToPtr(colorBlending, pipelineInfo.pColorBlendState, false);

        GCHandle pipelineInfoHandle = GCHandle.Alloc(pipelineInfo, GCHandleType.Pinned);
        try
        {
            IntPtr pipelineInfoPtr = pipelineInfoHandle.AddrOfPinnedObject();

            if (vkCreateGraphicsPipelines(device, IntPtr.Zero, 1, pipelineInfoPtr, IntPtr.Zero, out graphicsPipeline) != VkResult.VK_SUCCESS)
            {
                throw new Exception("Failed to create graphics pipeline.");
            }
        }
        finally
        {
            pipelineInfoHandle.Free();
            Marshal.FreeHGlobal(colorBlending.pAttachments);
            Marshal.FreeHGlobal(viewportState.pViewports);
            Marshal.FreeHGlobal(viewportState.pScissors);
        }

        Console.WriteLine("Graphics pipeline created successfully.");
    }

    private void CreateCommandPool()
    {
        Console.WriteLine("----------------------------------------");
        Console.WriteLine("[HelloForm::CreateCommandPool] - Start");

        QueueFamilyIndices indices = FindQueueFamilies(physicalDevice);
        if (!indices.GraphicsFamily.HasValue)
        {
            throw new Exception("Failed to find a suitable graphics queue family!");
        }

        int graphicsQueueFamilyIndex = indices.GraphicsFamily.Value;

        VkCommandPoolCreateInfo poolInfo = new VkCommandPoolCreateInfo
        {
            sType = VkStructureType.VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO,
            queueFamilyIndex = (uint)graphicsQueueFamilyIndex, 
            flags = VkCommandPoolCreateFlags.VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT
        };

        VkResult result = vkCreateCommandPool(device, ref poolInfo, IntPtr.Zero, out commandPool);
        if (result != VkResult.VK_SUCCESS)
        {
            throw new Exception("Failed to create command pool!");
        }

        Console.WriteLine($"Command pool created successfully: {commandPool}");
        Console.WriteLine("[HelloForm::CreateCommandPool] - End");
    }

    private void CreateDepthResources()
    {
        Console.WriteLine("----------------------------------------");
        Console.WriteLine("[HelloForm::CreateDepthResources] - Start");

        VkFormat depthFormat = FindDepthFormat();
        CreateImage(swapChainExtent.width, swapChainExtent.height, depthFormat,
            VkImageTiling.VK_IMAGE_TILING_OPTIMAL,
            VkImageUsageFlags.VK_IMAGE_USAGE_DEPTH_STENCIL_ATTACHMENT_BIT,
            VkMemoryPropertyFlags.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT,
            out depthImage, out depthImageMemory);

        depthImageView = CreateImageView(depthImage, depthFormat, VkImageAspectFlags.VK_IMAGE_ASPECT_DEPTH_BIT);

        Console.WriteLine("[HelloForm::CreateDepthResources] - End");
    }

    private void CreateFramebuffers()
    {
        Console.WriteLine("----------------------------------------");
        Console.WriteLine("[HelloForm::CreateFramebuffers] - Start");

        swapChainFramebuffers = new IntPtr[swapChainImageViews.Length];

        for (int i = 0; i < swapChainImageViews.Length; i++)
        {
            var attachments = new[] { swapChainImageViews[i] };  
            GCHandle attachmentsHandle = GCHandle.Alloc(attachments, GCHandleType.Pinned);

            try
            {
                var framebufferInfo = new VkFramebufferCreateInfo
                {
                    sType = VkStructureType.VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO,
                    renderPass = renderPass,
                    attachmentCount = 1,  
                    pAttachments = attachmentsHandle.AddrOfPinnedObject(),
                    width = swapChainExtent.width,
                    height = swapChainExtent.height,
                    layers = 1
                };

                VkResult result = vkCreateFramebuffer(device, ref framebufferInfo, IntPtr.Zero, out swapChainFramebuffers[i]);
                if (result != VkResult.VK_SUCCESS)
                {
                    throw new Exception($"Failed to create framebuffer! Result: {result}");
                }
            }
            finally
            {
                attachmentsHandle.Free();
            }
        }

        Console.WriteLine("[HelloForm::CreateFramebuffers] - End");
    }

    private void CreateCommandBuffers()
    {
        Console.WriteLine("----------------------------------------");
        Console.WriteLine("[HelloForm::CreateCommandBuffers] - Start");

        var allocInfo = new VkCommandBufferAllocateInfo
        {
            sType = VkStructureType.VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
            commandPool = commandPool, 
            level = VkCommandBufferLevel.VK_COMMAND_BUFFER_LEVEL_PRIMARY,
            commandBufferCount = 1 
        };

        VkResult result = vkAllocateCommandBuffers(device, ref allocInfo, out commandBuffer);
        if (result != VkResult.VK_SUCCESS)
        {
            throw new Exception("Failed to allocate command buffers!");
        }

        Console.WriteLine("Command buffer created successfully.");

        Console.WriteLine("[HelloForm::CreateCommandBuffers] - End");
    }

    public void CreateSyncObjects()
    {
        Console.WriteLine("----------------------------------------");
        Console.WriteLine("[HelloForm::CreateSyncObjects] - Start");

        Console.WriteLine($"Creating sync objects for {MAX_FRAMES_IN_FLIGHT} frames");

        imageAvailableSemaphores = new IntPtr[MAX_FRAMES_IN_FLIGHT];
        renderFinishedSemaphores = new IntPtr[MAX_FRAMES_IN_FLIGHT];
        inFlightFences = new IntPtr[MAX_FRAMES_IN_FLIGHT];
        imagesInFlight = new IntPtr[swapChainImages.Length]; 

        var semaphoreInfo = new VkSemaphoreCreateInfo
        {
            sType = VkStructureType.VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO
        };

        var fenceInfo = new VkFenceCreateInfo
        {
            sType = VkStructureType.VK_STRUCTURE_TYPE_FENCE_CREATE_INFO,
            flags = VkFenceCreateFlags.VK_FENCE_CREATE_SIGNALED_BIT 
        };

        for (int i = 0; i < MAX_FRAMES_IN_FLIGHT; i++)
        {
            Console.WriteLine($"[HelloForm::CreateSyncObjects] - Creating sync objects for frame {i + 1}/{MAX_FRAMES_IN_FLIGHT}");

            VkResult semaphoreResult1 = vkCreateSemaphore(device, ref semaphoreInfo, IntPtr.Zero, out imageAvailableSemaphores[i]);
            VkResult semaphoreResult2 = vkCreateSemaphore(device, ref semaphoreInfo, IntPtr.Zero, out renderFinishedSemaphores[i]);
            if (semaphoreResult1 != VkResult.VK_SUCCESS || semaphoreResult2 != VkResult.VK_SUCCESS)
            {
                Console.WriteLine($"[HelloForm::CreateSyncObjects] - Failed to create semaphores for frame {i + 1}");
                throw new Exception($"Failed to create semaphores! Results: imageAvailable={semaphoreResult1}, renderFinished={semaphoreResult2}");
            }
            Console.WriteLine($"[HelloForm::CreateSyncObjects] - Semaphores created: imageAvailable={imageAvailableSemaphores[i]}, renderFinished={renderFinishedSemaphores[i]}");

            VkResult fenceResult = vkCreateFence(device, ref fenceInfo, IntPtr.Zero, out inFlightFences[i]);
            if (fenceResult != VkResult.VK_SUCCESS)
            {
                Console.WriteLine($"[HelloForm::CreateSyncObjects] - Failed to create fence for frame {i + 1}");
                throw new Exception($"Failed to create fence! Result: {fenceResult}");
            }
            Console.WriteLine($"[HelloForm::CreateSyncObjects] - Fence created: inFlightFence={inFlightFences[i]}");
        }

        Console.WriteLine("[HelloForm::CreateSyncObjects] - All sync objects created successfully.");
        Console.WriteLine("[HelloForm::CreateSyncObjects] - End");
    }

    public void LoadVulkanFunctions()
    {
        IntPtr funcPtr = vkGetDeviceProcAddr(device, "vkCreateFence");
        if (funcPtr == IntPtr.Zero)
        {
            throw new Exception("Failed to load vkCreateFence!");
        }
        vkCreateFence = Marshal.GetDelegateForFunctionPointer<vkCreateFenceDelegate>(funcPtr);

        funcPtr = vkGetDeviceProcAddr(device, "vkCreateImageView");
        if (funcPtr == IntPtr.Zero)
        {
            throw new Exception("Failed to load vkCreateImageView function pointer!");
        }

        vkCreateImageView = Marshal.GetDelegateForFunctionPointer<vkCreateImageViewDelegate>(funcPtr);

        funcPtr = vkGetDeviceProcAddr(device, "vkWaitForFences");
        if (funcPtr == IntPtr.Zero)
        {
            throw new Exception("Failed to load vkWaitForFences!");
        }

        vkWaitForFences = Marshal.GetDelegateForFunctionPointer<vkWaitForFencesDelegate>(funcPtr);

        funcPtr = vkGetDeviceProcAddr(device, "vkResetFences");
        if (funcPtr == IntPtr.Zero)
        {
            throw new Exception("Failed to load vkResetFences!");
        }

        vkResetFences = Marshal.GetDelegateForFunctionPointer<vkResetFencesDelegate>(funcPtr);
    }

    private bool IsDeviceSuitable(IntPtr device)
    {
        Console.WriteLine("----------------------------------------");
        Console.WriteLine("[HelloForm::IsDeviceSuitable] - Start");

        var indices = FindQueueFamilies(device);

        Console.WriteLine($"Device handle: {device}");
        if (device == IntPtr.Zero)
        {
            throw new Exception("Invalid device handle.");
        }

        bool extensionsSupported = CheckDeviceExtensionSupport(device);
        bool swapChainAdequate = false;

        if (extensionsSupported)
        {
            var swapChainSupport = QuerySwapChainSupport(device);
            swapChainAdequate = swapChainSupport.formats.Any() && swapChainSupport.presentModes.Any();
        }

        return indices.IsComplete() && extensionsSupported && swapChainAdequate;
    }

    private bool CheckDeviceExtensionSupport(IntPtr device)
    {
        Console.WriteLine("----------------------------------------");
        Console.WriteLine("[HelloForm::CheckDeviceExtensionSupport] - Start");

        uint extensionCount = 0;

        VkResult result = vkEnumerateDeviceExtensionProperties(device, IntPtr.Zero, ref extensionCount, IntPtr.Zero);
        if (result != VkResult.VK_SUCCESS)
        {
            Console.WriteLine($"Failed to query device extension count: {result}");
            return false;
        }

        Console.WriteLine($"Number of extensions found: {extensionCount}");

        if (extensionCount == 0)
        {
            Console.WriteLine("No extensions available for the device.");
            return false;
        }

        int structSize = Marshal.SizeOf(typeof(VkExtensionProperties));
        IntPtr buffer = Marshal.AllocHGlobal(structSize * (int)extensionCount);

        try
        {
            result = vkEnumerateDeviceExtensionProperties(device, IntPtr.Zero, ref extensionCount, buffer);
            if (result != VkResult.VK_SUCCESS)
            {
                Console.WriteLine($"Failed to enumerate device extensions: {result}");
                return false;
            }

            var extensions = new VkExtensionProperties[extensionCount];
            for (int i = 0; i < extensionCount; i++)
            {
                IntPtr offset = IntPtr.Add(buffer, i * structSize);
                extensions[i] = Marshal.PtrToStructure<VkExtensionProperties>(offset);
            }

            foreach (var ext in extensions)
            {
                string extensionName = System.Text.Encoding.UTF8.GetString(ext.extensionName).TrimEnd('\0');
            }

            var requiredExtensions = new HashSet<string> { "VK_KHR_swapchain" };
            var availableExtensions = extensions
                .Select(e => System.Text.Encoding.UTF8.GetString(e.extensionName).TrimEnd('\0'))
                .ToHashSet();

            if (requiredExtensions.All(ext => availableExtensions.Contains(ext)))
            {
                Console.WriteLine("All required extensions are supported.");
                return true;
            }
            else
            {
                Console.WriteLine("Missing required extensions:");
                foreach (var ext in requiredExtensions.Except(availableExtensions))
                {
                    Console.WriteLine($" - {ext}");
                }
                return false;
            }
        }
        finally
        {
            Marshal.FreeHGlobal(buffer);
        }
    }

    private SwapChainSupportDetails QuerySwapChainSupport(IntPtr device)
    {
        Console.WriteLine("----------------------------------------");
        Console.WriteLine("[HelloForm::QuerySwapChainSupport] - Start");

        var details = new SwapChainSupportDetails();
        details.Initialize();
        var capResult = vkGetPhysicalDeviceSurfaceCapabilitiesKHR(device, surface, out details.capabilities);
        Console.WriteLine($"Capabilities result: {capResult}");

        uint formatCount = 0;
        var formatResult = vkGetPhysicalDeviceSurfaceFormatsKHR(device, surface, ref formatCount, null);
        Console.WriteLine($"Format count: {formatCount}, result: {formatResult}");

        if (formatCount != 0)
        {
            details.formats = new VkSurfaceFormatKHR[formatCount];
            GCHandle handle = GCHandle.Alloc(details.formats, GCHandleType.Pinned);
            try
            {
                formatResult = vkGetPhysicalDeviceSurfaceFormatsKHR(device, surface, ref formatCount, details.formats);
                Console.WriteLine($"Format get result: {formatResult}");
            }
            finally
            {
                handle.Free();
            }
        }

        uint presentModeCount = 0;
        vkGetPhysicalDeviceSurfacePresentModesKHR(device, surface, ref presentModeCount, null);
        Console.WriteLine($"Present mode count: {presentModeCount}");

        if (presentModeCount != 0)
        {
            details.presentModes = new VkPresentModeKHR[presentModeCount];
            int size = sizeof(int); 
            IntPtr modesPtr = Marshal.AllocHGlobal((int)(presentModeCount * size));
            try
            {
                vkGetPhysicalDeviceSurfacePresentModesKHR(device, surface, ref presentModeCount, details.presentModes);
                for (int i = 0; i < presentModeCount; i++)
                {
                    details.presentModes[i] = (VkPresentModeKHR)Marshal.ReadInt32(IntPtr.Add(modesPtr, i * size));
                }
            }
            finally
            {
                Marshal.FreeHGlobal(modesPtr);
            }
        }

        Console.WriteLine("[HelloForm::QuerySwapChainSupport] - End");
        return details;
    }

    private void CreateLogicalDevice()
    {
        Console.WriteLine("----------------------------------------");
        Console.WriteLine("[HelloForm::CreateLogicalDevice] - Start");

        try
        {
            QueueFamilyIndices indices = FindQueueFamilies(physicalDevice);
            Console.WriteLine($"Queue Families - Graphics: {indices.GraphicsFamily}, Present: {indices.PresentFamily}");

            float queuePriority = 1.0f;
            var queueCreateInfo = new VkDeviceQueueCreateInfo
            {
                sType = VkStructureType.VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
                queueFamilyIndex = (uint)indices.GraphicsFamily.Value,
                queueCount = 1,
                pQueuePriorities = Marshal.AllocHGlobal(sizeof(float))
            };
            Console.WriteLine($"Queue Create Info - sType: {queueCreateInfo.sType}, familyIndex: {queueCreateInfo.queueFamilyIndex}, queueCount: {queueCreateInfo.queueCount}");

            Marshal.Copy(new[] { queuePriority }, 0, queueCreateInfo.pQueuePriorities, 1);
            Console.WriteLine("Queue priorities copied");

            var deviceFeatures = new VkPhysicalDeviceFeatures
            {
                samplerAnisotropy = VkBool32.True 
            };
            Console.WriteLine("Device features created");

            string[] deviceExtensions = { "VK_KHR_swapchain" };
            IntPtr[] extensionPointers = deviceExtensions
                .Select(ext => Marshal.StringToHGlobalAnsi(ext))
                .ToArray();
            Console.WriteLine($"Extension pointers created: {extensionPointers.Length}");

            var createInfo = new VkDeviceCreateInfo
            {
                sType = VkStructureType.VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO,
                queueCreateInfoCount = 1,
                pQueueCreateInfos = Marshal.AllocHGlobal(Marshal.SizeOf(queueCreateInfo)),
                ppEnabledExtensionNames = Marshal.AllocHGlobal(IntPtr.Size * extensionPointers.Length),
                enabledExtensionCount = (uint)extensionPointers.Length,
                pEnabledFeatures = Marshal.AllocHGlobal(Marshal.SizeOf(deviceFeatures))
            };
            Console.WriteLine($"Device create info - sType: {createInfo.sType}, queueCount: {createInfo.queueCreateInfoCount}, extCount: {createInfo.enabledExtensionCount}");

            Marshal.StructureToPtr(queueCreateInfo, createInfo.pQueueCreateInfos, false);
            Console.WriteLine("Queue create info marshalled");

            Marshal.Copy(extensionPointers, 0, createInfo.ppEnabledExtensionNames, extensionPointers.Length);
            Console.WriteLine("Extension pointers copied");

            Marshal.StructureToPtr(deviceFeatures, createInfo.pEnabledFeatures, false);
            Console.WriteLine("Device features marshalled");

            Console.WriteLine($"Calling vkCreateDevice with physicalDevice: {physicalDevice}");
            VkResult result = vkCreateDevice(physicalDevice, ref createInfo, IntPtr.Zero, out device);
            Console.WriteLine($"vkCreateDevice result: {result}");

            if (result != VkResult.VK_SUCCESS)
            {
                Console.WriteLine($"Failed to create logical device! Error code: {result}");
                CleanupExtensions(extensionPointers);
                Marshal.FreeHGlobal(createInfo.pQueueCreateInfos);
                Marshal.FreeHGlobal(createInfo.ppEnabledExtensionNames);
                Marshal.FreeHGlobal(createInfo.pEnabledFeatures);
                Marshal.FreeHGlobal(queueCreateInfo.pQueuePriorities);
                return;
            }

            Console.WriteLine($"Logical device created successfully: {device}");

            vkGetDeviceQueue(device, (uint)indices.GraphicsFamily.Value, 0, out graphicsQueue);
            Console.WriteLine($"Graphics queue retrieved: {graphicsQueue}");

            vkGetDeviceQueue(device, (uint)indices.PresentFamily.Value, 0, out presentQueue);
            Console.WriteLine($"Present queue retrieved: {presentQueue}");

            CleanupExtensions(extensionPointers);
            Marshal.FreeHGlobal(createInfo.pQueueCreateInfos);
            Marshal.FreeHGlobal(createInfo.ppEnabledExtensionNames);
            Marshal.FreeHGlobal(createInfo.pEnabledFeatures);
            Marshal.FreeHGlobal(queueCreateInfo.pQueuePriorities);

            Console.WriteLine("[HelloForm::CreateLogicalDevice] - End");
        }
        catch (Exception ex)
        {
            Console.WriteLine($"Exception in CreateLogicalDevice: {ex.Message}");
            Console.WriteLine($"Stack trace: {ex.StackTrace}");
            throw;
        }
    }

    private void CleanupExtensions(IntPtr[] extensionPointers)
    {
        Console.WriteLine("----------------------------------------");
        Console.WriteLine("[HelloForm::CleanupExtensions] - Start");

        foreach (var ptr in extensionPointers)
        {
            Marshal.FreeHGlobal(ptr);
        }

        Console.WriteLine("[HelloForm::CleanupExtensions] - End");
    }

    private QueueFamilyIndices FindQueueFamilies(IntPtr physicalDevice)
    {
        QueueFamilyIndices indices = new QueueFamilyIndices();

        uint queueFamilyCount = 0;
        vkGetPhysicalDeviceQueueFamilyProperties(physicalDevice, ref queueFamilyCount, IntPtr.Zero);

        IntPtr queueFamiliesPtr = Marshal.AllocHGlobal((int)queueFamilyCount * Marshal.SizeOf<VkQueueFamilyProperties>());
        vkGetPhysicalDeviceQueueFamilyProperties(physicalDevice, ref queueFamilyCount, queueFamiliesPtr);

        for (uint i = 0; i < queueFamilyCount; i++)
        {
            IntPtr currentFamilyPtr = IntPtr.Add(queueFamiliesPtr, (int)i * Marshal.SizeOf<VkQueueFamilyProperties>());
            VkQueueFamilyProperties queueFamily = Marshal.PtrToStructure<VkQueueFamilyProperties>(currentFamilyPtr);

            if ((queueFamily.queueFlags & VkQueueFlags.VK_QUEUE_GRAPHICS_BIT) != 0)
            {
                indices.GraphicsFamily = (int)i;
            }

            vkGetPhysicalDeviceSurfaceSupportKHR(physicalDevice, i, surface, out VkBool32 presentSupport);
            if (presentSupport == VkBool32.True)
            {
                indices.PresentFamily = (int)i;
            }

            if (indices.IsComplete())
            {
                break;
            }
        }

        Marshal.FreeHGlobal(queueFamiliesPtr);
        return indices;
    }

    private void CreateSwapChainImageViews()
    {
        Console.WriteLine("----------------------------------------");
        Console.WriteLine("[HelloForm::CreateSwapChainImageViews] - Start");

        if (swapChainImages == null || swapChainImages.Length == 0)
        {
            Console.WriteLine("[HelloForm::CreateSwapChainImageViews] - No swap chain images available!");
            throw new Exception("Swap chain images are null or empty.");
        }

        if (device == IntPtr.Zero)
        {
            throw new Exception("[HelloForm::CreateSwapChainImageViews] - Vulkan device is not initialized.");
        }

        Console.WriteLine($"[HelloForm::CreateSwapChainImageViews] - Total swap chain images: {swapChainImages.Length}");
        swapChainImageViews = new IntPtr[swapChainImages.Length];

        for (int i = 0; i < swapChainImages.Length; i++)
        {
            if (swapChainImages[i] == IntPtr.Zero)
            {
                Console.WriteLine($"[HelloForm::CreateSwapChainImageViews] - swapChainImages[{i}] is invalid.");
                throw new Exception($"[HelloForm::CreateSwapChainImageViews] - Invalid swap chain image at index {i}.");
            }

            var createInfo = new VkImageViewCreateInfo
            {
                sType = VkStructureType.VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO,
                pNext = IntPtr.Zero,
                flags = 0,
                image = swapChainImages[i],
                viewType = VkImageViewType.VK_IMAGE_VIEW_TYPE_2D,
                format = swapChainImageFormat,
                components = new VkComponentMapping
                {
                    r = VkComponentSwizzle.VK_COMPONENT_SWIZZLE_IDENTITY,
                    g = VkComponentSwizzle.VK_COMPONENT_SWIZZLE_IDENTITY,
                    b = VkComponentSwizzle.VK_COMPONENT_SWIZZLE_IDENTITY,
                    a = VkComponentSwizzle.VK_COMPONENT_SWIZZLE_IDENTITY
                },
                subresourceRange = new VkImageSubresourceRange
                {
                    aspectMask = VkImageAspectFlags.VK_IMAGE_ASPECT_COLOR_BIT,
                    baseMipLevel = 0,
                    levelCount = 1,
                    baseArrayLayer = 0,
                    layerCount = 1
                }
            };

            Console.WriteLine($"[HelloForm::CreateSwapChainImageViews] - Full VkImageViewCreateInfo for image {i}:");
            Console.WriteLine($"    sType: {createInfo.sType}");
            Console.WriteLine($"    image: {createInfo.image}");
            Console.WriteLine($"    viewType: {createInfo.viewType}");
            Console.WriteLine($"    format: {createInfo.format}");
            Console.WriteLine($"    r: {createInfo.components.r}");
            Console.WriteLine($"    g: {createInfo.components.g}");
            Console.WriteLine($"    b: {createInfo.components.b}");
            Console.WriteLine($"    a: {createInfo.components.a}");
            Console.WriteLine($"    aspectMask: {createInfo.subresourceRange.aspectMask}");
            Console.WriteLine($"    baseMipLevel: {createInfo.subresourceRange.baseMipLevel}");
            Console.WriteLine($"    levelCount: {createInfo.subresourceRange.levelCount}");
            Console.WriteLine($"    baseArrayLayer: {createInfo.subresourceRange.baseArrayLayer}");
            Console.WriteLine($"    layerCount: {createInfo.subresourceRange.layerCount}");

            if (vkCreateImageView == null)
            {
                throw new Exception("vkCreateImageView is not initialized. Ensure that it is loaded using vkGetDeviceProcAddr.");
            }

            VkResult result = vkCreateImageView(device, ref createInfo, IntPtr.Zero, out swapChainImageViews[i]);
            if (result != VkResult.VK_SUCCESS)
            {
                Console.WriteLine($"[HelloForm::CreateSwapChainImageViews] - vkCreateImageView failed for image {i}. VkResult: {result}");
                throw new Exception($"[HelloForm::CreateSwapChainImageViews] - Failed to create image view for image {i}. VkResult: {result}");
            }

            Console.WriteLine($"[HelloForm::CreateSwapChainImageViews] - Image view created successfully for image {i}: {swapChainImageViews[i]}");
        }

        Console.WriteLine("[HelloForm::CreateSwapChainImageViews] - Successfully created all image views.");
        Console.WriteLine("[HelloForm::CreateSwapChainImageViews] - End");
    }

    private VkSurfaceFormatKHR ChooseSwapSurfaceFormat(VkSurfaceFormatKHR[] availableFormats)
    {
        Console.WriteLine("----------------------------------------");
        Console.WriteLine("[HelloForm::ChooseSwapSurfaceFormat] - Start");

        Console.WriteLine("Available surface formats:");
        foreach (var format in availableFormats)
        {
            Console.WriteLine($"Format: {format.format}, ColorSpace: {format.colorSpace}");
        }

        foreach (var format in availableFormats)
        {
            if (format.format == VkFormat.VK_FORMAT_B8G8R8A8_SRGB &&
                format.colorSpace == VkColorSpaceKHR.VK_COLOR_SPACE_SRGB_NONLINEAR_KHR)
            {
                Console.WriteLine($"Selected format: {format.format}, ColorSpace: {format.colorSpace}");

                Console.WriteLine("[HelloForm::ChooseSwapSurfaceFormat] - End");
                return format;
            }
        }

        Console.WriteLine($"Fallback format: {availableFormats[0].format}, ColorSpace: {availableFormats[0].colorSpace}");

        Console.WriteLine("[HelloForm::ChooseSwapSurfaceFormat] - End");
        return availableFormats[0];
    }

    private VkPresentModeKHR ChooseSwapPresentMode(VkPresentModeKHR[] availablePresentModes)
    {
        Console.WriteLine("----------------------------------------");
        Console.WriteLine("[HelloForm::ChooseSwapPresentMode] - Start");

        foreach (var presentMode in availablePresentModes)
        {
            if (presentMode == VkPresentModeKHR.VK_PRESENT_MODE_MAILBOX_KHR)
            {
                return presentMode;
            }
        }

        Console.WriteLine("[HelloForm::ChooseSwapPresentMode] - End");

        return VkPresentModeKHR.VK_PRESENT_MODE_FIFO_KHR;
    }

    private VkExtent2D ChooseSwapExtent(VkSurfaceCapabilitiesKHR capabilities)
    {
        if (capabilities.currentExtent.width != uint.MaxValue)
        {
            return capabilities.currentExtent;
        }

        VkExtent2D actualExtent = new VkExtent2D
        {
            width = (uint)this.ClientSize.Width,
            height = (uint)this.ClientSize.Height
        };

        actualExtent.width = Math.Max(capabilities.minImageExtent.width, 
            Math.Min(capabilities.maxImageExtent.width, actualExtent.width));
        actualExtent.height = Math.Max(capabilities.minImageExtent.height, 
            Math.Min(capabilities.maxImageExtent.height, actualExtent.height));

        return actualExtent;
    }

    private VkFormat FindDepthFormat()
    {
        VkFormat[] candidates = {
            VkFormat.VK_FORMAT_D32_SFLOAT,
            VkFormat.VK_FORMAT_D32_SFLOAT_S8_UINT,
            VkFormat.VK_FORMAT_D24_UNORM_S8_UINT
        };

        foreach (var format in candidates)
        {
            VkFormatProperties props;
            vkGetPhysicalDeviceFormatProperties(physicalDevice, format, out props);
            if ((props.optimalTilingFeatures & VkFormatFeatureFlags.VK_FORMAT_FEATURE_DEPTH_STENCIL_ATTACHMENT_BIT) != 0)
            {
                return format;
            }
        }

        throw new Exception("Failed to find a suitable depth format!");
    }

    private IntPtr LoadShaderModule(string filePath)
    {
        Console.WriteLine("----------------------------------------");
        Console.WriteLine("[HelloForm::LoadShaderModule] - Start");
        Console.WriteLine($"filePath : {filePath}");

        byte[] code = File.ReadAllBytes(filePath);

        var createInfo = new VkShaderModuleCreateInfo
        {
            sType = VkStructureType.VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO,
            codeSize = (UIntPtr)code.Length,
            pCode = Marshal.UnsafeAddrOfPinnedArrayElement(code, 0)
        };

        if (vkCreateShaderModule(device, ref createInfo, IntPtr.Zero, out IntPtr shaderModule) != VkResult.VK_SUCCESS)
        {
            throw new Exception($"Failed to create shader module for {filePath}");
        }

        Console.WriteLine("[HelloForm::LoadShaderModule] - End");

        return shaderModule;
    }

    private void CreateImage(uint width, uint height, VkFormat format, VkImageTiling tiling,
        VkImageUsageFlags usage, VkMemoryPropertyFlags properties,
        out IntPtr image, out IntPtr imageMemory)
    {
        Console.WriteLine("----------------------------------------");
        Console.WriteLine("[HelloForm::CreateImage] - Start");

        var imageInfo = new VkImageCreateInfo
        {
            sType = VkStructureType.VK_STRUCTURE_TYPE_IMAGE_CREATE_INFO,
            imageType = VkImageType.VK_IMAGE_TYPE_2D,
            extent = new VkExtent3D { width = width, height = height, depth = 1 },
            mipLevels = 1,
            arrayLayers = 1,
            format = format,
            tiling = tiling,
            initialLayout = VkImageLayout.VK_IMAGE_LAYOUT_UNDEFINED,
            usage = usage,
            sharingMode = VkSharingMode.VK_SHARING_MODE_EXCLUSIVE,
            samples = VkSampleCountFlags.VK_SAMPLE_COUNT_1_BIT
        };

        VkResult result = vkCreateImage(device, ref imageInfo, IntPtr.Zero, out image);
        if (result != VkResult.VK_SUCCESS)
        {
            throw new Exception("Failed to create image!");
        }

        VkMemoryRequirements memRequirements;
        vkGetImageMemoryRequirements(device, image, out memRequirements);

        var allocInfo = new VkMemoryAllocateInfo
        {
            sType = VkStructureType.VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
            allocationSize = memRequirements.size,
            memoryTypeIndex = FindMemoryType(memRequirements.memoryTypeBits, properties)
        };

        result = vkAllocateMemory(device, ref allocInfo, IntPtr.Zero, out imageMemory);
        if (result != VkResult.VK_SUCCESS)
        {
            throw new Exception("Failed to allocate image memory!");
        }

        vkBindImageMemory(device, image, imageMemory, 0);

        Console.WriteLine("[HelloForm::CreateImage] - End");
    }

    private uint FindMemoryType(uint typeFilter, VkMemoryPropertyFlags properties)
    {
        Console.WriteLine("----------------------------------------");
        Console.WriteLine("[HelloForm::FindMemoryType] - Start");

        VkPhysicalDeviceMemoryProperties memProperties;
        vkGetPhysicalDeviceMemoryProperties(physicalDevice, out memProperties);

        for (uint i = 0; i < memProperties.memoryTypeCount; i++)
        {
            if ((typeFilter & (1u << (int)i)) != 0 &&
                (memProperties.memoryTypes[i].propertyFlags & properties) == properties)
            {
                Console.WriteLine("[HelloForm::FindMemoryType] - End");
                return i;
            }
        }

        Console.WriteLine("[HelloForm::FindMemoryType] - End");
        return 0;
    }

    private IntPtr CreateImageView(IntPtr image, VkFormat format, VkImageAspectFlags aspectFlags)
    {
        Console.WriteLine("----------------------------------------");
        Console.WriteLine("[HelloForm::CreateImageView] - Start");

        var createInfo = new VkImageViewCreateInfo
        {
            sType = VkStructureType.VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO,
            image = image,
            viewType = VkImageViewType.VK_IMAGE_VIEW_TYPE_2D,
            format = format,
            components = new VkComponentMapping
            {
                r = VkComponentSwizzle.VK_COMPONENT_SWIZZLE_IDENTITY,
                g = VkComponentSwizzle.VK_COMPONENT_SWIZZLE_IDENTITY,
                b = VkComponentSwizzle.VK_COMPONENT_SWIZZLE_IDENTITY,
                a = VkComponentSwizzle.VK_COMPONENT_SWIZZLE_IDENTITY
            },
            subresourceRange = new VkImageSubresourceRange
            {
                aspectMask = aspectFlags,
                baseMipLevel = 0,
                levelCount = 1,
                baseArrayLayer = 0,
                layerCount = 1
            }
        };

        IntPtr imageView;
        if (vkCreateImageView(device, ref createInfo, IntPtr.Zero, out imageView) != VkResult.VK_SUCCESS)
        {
            throw new Exception("Failed to create image view!");
        }

        Console.WriteLine("[HelloForm::CreateImageView] - End");

        return imageView;
    }

    private void CreateCommandBuffer()
    {
        Console.WriteLine("----------------------------------------");
        Console.WriteLine("[HelloForm::CreateCommandBuffer] - Start");

        var allocInfo = new VkCommandBufferAllocateInfo
        {
            sType = VkStructureType.VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
            commandPool = commandPool,
            level = VkCommandBufferLevel.VK_COMMAND_BUFFER_LEVEL_PRIMARY,
            commandBufferCount = 1
        };

        if (vkAllocateCommandBuffers(device, ref allocInfo, out commandBuffer) != VkResult.VK_SUCCESS)
        {
            throw new Exception("Failed to allocate command buffers!");
        }

        Console.WriteLine("[HelloForm::CreateCommandBuffer] - End");
    }

    public void DrawFrame()
    {
        Console.WriteLine("----------------------------------------");
        Console.WriteLine("[HelloForm::DrawFrame] - Start");

        int currentFrame = frameIndex % MAX_FRAMES_IN_FLIGHT;

        Console.WriteLine($"Current frame: {currentFrame}, Frame index: {frameIndex}");
        Console.WriteLine($"CommandBuffer: {commandBuffer}");
        Console.WriteLine($"ImageAvailableSemaphore: {imageAvailableSemaphores[currentFrame]}");
        Console.WriteLine($"RenderFinishedSemaphore: {renderFinishedSemaphores[currentFrame]}");
        Console.WriteLine($"InFlightFence: {inFlightFences[currentFrame]}");

        vkWaitForFences(device, 1, ref inFlightFences[currentFrame], VkBool32.True, ulong.MaxValue);
        vkResetFences(device, 1, ref inFlightFences[currentFrame]);

        uint imageIndex = 0;
        VkResult result = vkAcquireNextImageKHR(device, swapChain, ulong.MaxValue, imageAvailableSemaphores[currentFrame], IntPtr.Zero, ref imageIndex);

        Console.WriteLine($"vkAcquireNextImageKHR result: {result}, imageIndex: {imageIndex}");

        if (result != VkResult.VK_SUCCESS && result != VkResult.VK_SUBOPTIMAL_KHR)
        {
            throw new Exception("Failed to acquire swap chain image!");
        }

        var beginInfo = new VkCommandBufferBeginInfo
        {
            sType = VkStructureType.VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
            flags = VkCommandBufferUsageFlags.VK_COMMAND_BUFFER_USAGE_SIMULTANEOUS_USE_BIT 
        };

        if (vkBeginCommandBuffer(commandBuffer, ref beginInfo) != VkResult.VK_SUCCESS)
        {
            throw new Exception("Failed to begin recording command buffer!");
        }

        Console.WriteLine($"RenderPass: {renderPass}");
        Console.WriteLine($"Framebuffer: {swapChainFramebuffers[imageIndex]}");
        Console.WriteLine($"SwapChainExtent: {swapChainExtent.width}x{swapChainExtent.height}");

        VkClearValue[] clearValues = new VkClearValue[2];
        clearValues[0].color = new VkClearColorValue { float32 = new[] { 0.0f, 0.0f, 0.0f, 1.0f } };
        clearValues[1].depthStencil = new VkClearDepthStencilValue { depth = 1.0f, stencil = 0 };

        var renderPassInfo = new VkRenderPassBeginInfo
        {
            sType = VkStructureType.VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO,
            renderPass = renderPass,
            framebuffer = swapChainFramebuffers[imageIndex],
            renderArea = new VkRect2D
            {
                offset = new VkOffset2D { x = 0, y = 0 },
                extent = swapChainExtent
            },
            clearValueCount = (uint)clearValues.Length,
            pClearValues = Marshal.UnsafeAddrOfPinnedArrayElement(clearValues, 0)
        };

        vkCmdBeginRenderPass(commandBuffer, ref renderPassInfo, VkSubpassContents.VK_SUBPASS_CONTENTS_INLINE);

        vkCmdBindPipeline(commandBuffer, VkPipelineBindPoint.VK_PIPELINE_BIND_POINT_GRAPHICS, graphicsPipeline);
        vkCmdDraw(commandBuffer, 3, 1, 0, 0);

        vkCmdEndRenderPass(commandBuffer);

        if (vkEndCommandBuffer(commandBuffer) != VkResult.VK_SUCCESS)
        {
            throw new Exception("Failed to record command buffer!");
        }

        VkPipelineStageFlags waitStages = VkPipelineStageFlags.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT;
        var submitInfo = new VkSubmitInfo
        {
            sType = VkStructureType.VK_STRUCTURE_TYPE_SUBMIT_INFO,
            waitSemaphoreCount = 1,
            pWaitSemaphores = Marshal.UnsafeAddrOfPinnedArrayElement(imageAvailableSemaphores, currentFrame),
            pWaitDstStageMask = Marshal.UnsafeAddrOfPinnedArrayElement(new[] { waitStages }, 0),
            commandBufferCount = 1,
            pCommandBuffers = Marshal.UnsafeAddrOfPinnedArrayElement(new[] { commandBuffer }, 0),
            signalSemaphoreCount = 1,
            pSignalSemaphores = Marshal.UnsafeAddrOfPinnedArrayElement(renderFinishedSemaphores, currentFrame)
        };

        if (vkQueueSubmit(graphicsQueue, 1, ref submitInfo, inFlightFences[currentFrame]) != VkResult.VK_SUCCESS)
        {
            throw new Exception("Failed to submit draw command buffer!");
        }

        var presentInfo = new VkPresentInfoKHR
        {
            sType = VkStructureType.VK_STRUCTURE_TYPE_PRESENT_INFO_KHR,
            waitSemaphoreCount = 1,
            pWaitSemaphores = Marshal.UnsafeAddrOfPinnedArrayElement(renderFinishedSemaphores, currentFrame),
            swapchainCount = 1,
            pSwapchains = Marshal.UnsafeAddrOfPinnedArrayElement(new[] { swapChain }, 0),
            pImageIndices = Marshal.UnsafeAddrOfPinnedArrayElement(new[] { imageIndex }, 0)
        };

        result = vkQueuePresentKHR(presentQueue, ref presentInfo);

        if (result == VkResult.VK_ERROR_OUT_OF_DATE_KHR || result == VkResult.VK_SUBOPTIMAL_KHR)
        {
            RecreateSwapChain();
            return;
        }
        else if (result != VkResult.VK_SUCCESS)
        {
            throw new Exception("Failed to present swap chain image!");
        }

        frameIndex++;
        Console.WriteLine("[HelloForm::DrawFrame] - End");
    }

    private void RecreateSwapChain()
    {
        foreach (var framebuffer in swapChainFramebuffers)
        {
            vkDestroyFramebuffer(device, framebuffer, IntPtr.Zero);
        }

        vkDestroyPipeline(device, graphicsPipeline, IntPtr.Zero);
        vkDestroyPipelineLayout(device, pipelineLayout, IntPtr.Zero);

        foreach (var imageView in swapChainImageViews)
        {
            vkDestroyImageView(device, imageView, IntPtr.Zero);
        }

        vkDestroySwapchainKHR(device, swapChain, IntPtr.Zero);

        CreateSwapChain();
        CreateSwapChainImageViews();
        CreateGraphicsPipeline();
        CreateFramebuffers();
    }

    public void Cleanup()
    {
       Console.WriteLine("----------------------------------------");
       Console.WriteLine("[HelloForm::Cleanup] - Start");

       vkDeviceWaitIdle(device);

       vkDestroyImageView(device, depthImageView, IntPtr.Zero);
       vkDestroyImage(device, depthImage, IntPtr.Zero);
       vkFreeMemory(device, depthImageMemory, IntPtr.Zero); 
   
       for (int i = 0; i < MAX_FRAMES_IN_FLIGHT; i++)
       {
           vkDestroySemaphore(device, imageAvailableSemaphores[i], IntPtr.Zero);
           vkDestroySemaphore(device, renderFinishedSemaphores[i], IntPtr.Zero);
           vkDestroyFence(device, inFlightFences[i], IntPtr.Zero);
       }

       vkDestroyCommandPool(device, commandPool, IntPtr.Zero);
       
       vkDestroyShaderModule(device, fragShaderModule, IntPtr.Zero);
       vkDestroyShaderModule(device, vertShaderModule, IntPtr.Zero);

       for (var i = 0; i < swapChainFramebuffers.Length; i++)
       {
           vkDestroyFramebuffer(device, swapChainFramebuffers[i], IntPtr.Zero);
       }

       vkDestroyPipeline(device, graphicsPipeline, IntPtr.Zero);
       vkDestroyPipelineLayout(device, pipelineLayout, IntPtr.Zero);
       vkDestroyRenderPass(device, renderPass, IntPtr.Zero);

       for (var i = 0; i < swapChainImages.Length; i++)
       {
           vkDestroyImageView(device, swapChainImageViews[i], IntPtr.Zero);
       }

       vkDestroySwapchainKHR(device, swapChain, IntPtr.Zero);
       vkDestroyDevice(device, IntPtr.Zero);

       if (debugMessenger != IntPtr.Zero)
       {
           var vkDestroyDebugUtilsMessengerEXTPtr = vkGetInstanceProcAddr(instance, "vkDestroyDebugUtilsMessengerEXT");
           var vkDestroyDebugUtilsMessengerEXT = (vkDestroyDebugUtilsMessengerEXTFunc)Marshal.GetDelegateForFunctionPointer(
               vkDestroyDebugUtilsMessengerEXTPtr, typeof(vkDestroyDebugUtilsMessengerEXTFunc));
           vkDestroyDebugUtilsMessengerEXT(instance, debugMessenger, IntPtr.Zero);
       }

       vkDestroySurfaceKHR(instance, surface, IntPtr.Zero);
       vkDestroyInstance(instance, IntPtr.Zero);

       Console.WriteLine("[HelloForm::Cleanup] - End");
    }

    [STAThread]
    static void Main()
    {
        Console.WriteLine("----------------------------------------");
        Console.WriteLine("[HelloForm::Main] - Start");

        HelloForm form = new HelloForm();
        Application.Run(form);

        Console.WriteLine("[HelloForm::Main] - End");
    }
}
