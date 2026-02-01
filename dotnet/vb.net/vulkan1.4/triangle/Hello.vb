Imports System
Imports System.Drawing
Imports System.Windows.Forms
Imports System.Runtime.InteropServices
Imports System.IO
Imports System.Collections.Generic
Imports System.Linq
Imports System.Diagnostics
Imports System.Text

' ========================================================================================================
' Shader Compiler Class (Using shaderc_shared.dll)
' ========================================================================================================
Public Class ShaderCompiler
    Private Const LibName As String = "shaderc_shared.dll"

    Public Enum ShaderKind As Integer
        Vertex = 0
        Fragment = 1
        Compute = 2
        Geometry = 3
        TessControl = 4
        TessEvaluation = 5
    End Enum

    Private Enum CompilationStatus As Integer
        Success = 0
        InvalidStage = 1
        CompilationError = 2
        InternalError = 3
        NullResultObject = 4
        InvalidAssembly = 5
        ValidationError = 6
        TransformationError = 7
        ConfigurationError = 8
    End Enum

    <DllImport(LibName, CallingConvention:=CallingConvention.Cdecl)>
    Private Shared Function shaderc_compiler_initialize() As IntPtr
    End Function

    <DllImport(LibName, CallingConvention:=CallingConvention.Cdecl)>
    Private Shared Sub shaderc_compiler_release(ByVal compiler As IntPtr)
    End Sub

    <DllImport(LibName, CallingConvention:=CallingConvention.Cdecl)>
    Private Shared Function shaderc_compile_options_initialize() As IntPtr
    End Function

    <DllImport(LibName, CallingConvention:=CallingConvention.Cdecl)>
    Private Shared Sub shaderc_compile_options_set_optimization_level(ByVal options As IntPtr, ByVal level As Integer)
    End Sub

    <DllImport(LibName, CallingConvention:=CallingConvention.Cdecl)>
    Private Shared Sub shaderc_compile_options_release(ByVal options As IntPtr)
    End Sub

    <DllImport(LibName, CallingConvention:=CallingConvention.Cdecl)>
    Private Shared Function shaderc_compile_into_spv(
        ByVal compiler As IntPtr,
        <MarshalAs(UnmanagedType.LPStr)> ByVal source_text As String,
        ByVal source_text_size As UIntPtr,
        ByVal shader_kind As Integer,
        <MarshalAs(UnmanagedType.LPStr)> ByVal input_file_name As String,
        <MarshalAs(UnmanagedType.LPStr)> ByVal entry_point_name As String,
        ByVal additional_options As IntPtr) As IntPtr
    End Function

    <DllImport(LibName, CallingConvention:=CallingConvention.Cdecl)>
    Private Shared Sub shaderc_result_release(ByVal result As IntPtr)
    End Sub

    <DllImport(LibName, CallingConvention:=CallingConvention.Cdecl)>
    Private Shared Function shaderc_result_get_length(ByVal result As IntPtr) As UIntPtr
    End Function

    <DllImport(LibName, CallingConvention:=CallingConvention.Cdecl)>
    Private Shared Function shaderc_result_get_bytes(ByVal result As IntPtr) As IntPtr
    End Function

    <DllImport(LibName, CallingConvention:=CallingConvention.Cdecl)>
    Private Shared Function shaderc_result_get_compilation_status(ByVal result As IntPtr) As CompilationStatus
    End Function

    <DllImport(LibName, CallingConvention:=CallingConvention.Cdecl)>
    Private Shared Function shaderc_result_get_error_message(ByVal result As IntPtr) As IntPtr
    End Function

    Public Shared Function Compile(ByVal source As String, ByVal kind As ShaderKind, Optional ByVal fileName As String = "shader.glsl", Optional ByVal entryPoint As String = "main") As Byte()
        Dim compiler As IntPtr = shaderc_compiler_initialize()
        Dim options As IntPtr = shaderc_compile_options_initialize()

        ' Optimization Level: Performance
        shaderc_compile_options_set_optimization_level(options, 2)

        Try
            Dim result As IntPtr = shaderc_compile_into_spv(
                compiler,
                source,
                CType(Encoding.UTF8.GetByteCount(source), UIntPtr),
                CInt(kind),
                fileName,
                entryPoint,
                options
            )

            Try
                Dim status As CompilationStatus = shaderc_result_get_compilation_status(result)
                If status <> CompilationStatus.Success Then
                    Dim errorMsg As String = Marshal.PtrToStringAnsi(shaderc_result_get_error_message(result))
                    Throw New Exception($"Shader compilation failed: {errorMsg}")
                End If

                Dim length As ULong = CULng(shaderc_result_get_length(result))
                Dim bytesPtr As IntPtr = shaderc_result_get_bytes(result)

                Dim bytecode(length - 1) As Byte
                Marshal.Copy(bytesPtr, bytecode, 0, CInt(length))
                Return bytecode
            Finally
                shaderc_result_release(result)
            End Try
        Finally
            shaderc_compile_options_release(options)
            shaderc_compiler_release(compiler)
        End Try
    End Function
End Class

' ========================================================================================================
' Main Application
' ========================================================================================================

Class HelloForm
    Inherits Form

    <DllImport("kernel32.dll", CharSet:=CharSet.Auto)>
    Private Shared Function GetModuleHandle(ByVal lpModuleName As String) As IntPtr
    End Function

    <DllImport("kernel32.dll")>
    Private Shared Function LoadLibrary(ByVal dllToLoad As String) As IntPtr
    End Function

    <DllImport("kernel32.dll")>
    Private Shared Function GetLastError() As UInteger
    End Function

    Delegate Function WndProcDelegate(ByVal hWnd As IntPtr, ByVal uMsg As UInteger, ByVal wParam As IntPtr, ByVal lParam As IntPtr) As IntPtr

    Public Enum VkPhysicalDeviceType
        VK_PHYSICAL_DEVICE_TYPE_OTHER = 0
        VK_PHYSICAL_DEVICE_TYPE_INTEGRATED_GPU = 1
        VK_PHYSICAL_DEVICE_TYPE_DISCRETE_GPU = 2
        VK_PHYSICAL_DEVICE_TYPE_VIRTUAL_GPU = 3
        VK_PHYSICAL_DEVICE_TYPE_CPU = 4
    End Enum

    Public Enum VkDebugUtilsMessageSeverityFlagsEXT As UInteger
        VK_DEBUG_UTILS_MESSAGE_SEVERITY_VERBOSE_BIT_EXT = &H1UI
        VK_DEBUG_UTILS_MESSAGE_SEVERITY_INFO_BIT_EXT = &H10UI
        VK_DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT = &H100UI
        VK_DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT = &H1000UI
    End Enum

    Public Enum VkDebugUtilsMessageTypeFlagsEXT As UInteger
        VK_DEBUG_UTILS_MESSAGE_TYPE_GENERAL_BIT_EXT = &H1UI
        VK_DEBUG_UTILS_MESSAGE_TYPE_VALIDATION_BIT_EXT = &H2UI
        VK_DEBUG_UTILS_MESSAGE_TYPE_PERFORMANCE_BIT_EXT = &H4UI
    End Enum

    Public Enum VkStructureType As UInteger
        VK_STRUCTURE_TYPE_APPLICATION_INFO = 0
        VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO = 1
        VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO = 2
        VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO = 3
        VK_STRUCTURE_TYPE_SUBMIT_INFO = 4
        VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO = 5
        VK_STRUCTURE_TYPE_MAPPED_MEMORY_RANGE = 6
        VK_STRUCTURE_TYPE_BIND_SPARSE_INFO = 7
        VK_STRUCTURE_TYPE_FENCE_CREATE_INFO = 8
        VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO = 9
        VK_STRUCTURE_TYPE_EVENT_CREATE_INFO = 10
        VK_STRUCTURE_TYPE_QUERY_POOL_CREATE_INFO = 11
        VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO = 12
        VK_STRUCTURE_TYPE_BUFFER_VIEW_CREATE_INFO = 13
        VK_STRUCTURE_TYPE_IMAGE_CREATE_INFO = 14
        VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO = 15
        VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO = 16
        VK_STRUCTURE_TYPE_PIPELINE_CACHE_CREATE_INFO = 17
        VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO = 18
        VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO = 19
        VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO = 20
        VK_STRUCTURE_TYPE_PIPELINE_TESSELLATION_STATE_CREATE_INFO = 21
        VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO = 22
        VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO = 23
        VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO = 24
        VK_STRUCTURE_TYPE_PIPELINE_DEPTH_STENCIL_STATE_CREATE_INFO = 25
        VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO = 26
        VK_STRUCTURE_TYPE_PIPELINE_DYNAMIC_STATE_CREATE_INFO = 27
        VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO = 28
        VK_STRUCTURE_TYPE_COMPUTE_PIPELINE_CREATE_INFO = 29
        VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO = 30
        VK_STRUCTURE_TYPE_SAMPLER_CREATE_INFO = 31
        VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO = 32
        VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO = 33
        VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO = 34
        VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET = 35
        VK_STRUCTURE_TYPE_COPY_DESCRIPTOR_SET = 36
        VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO = 37
        VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO = 38
        VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO = 39
        VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO = 40
        VK_STRUCTURE_TYPE_COMMAND_BUFFER_INHERITANCE_INFO = 41
        VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO = 42
        VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO = 43
        VK_STRUCTURE_TYPE_BUFFER_MEMORY_BARRIER = 44
        VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER = 45
        VK_STRUCTURE_TYPE_MEMORY_BARRIER = 46
        VK_STRUCTURE_TYPE_WIN32_SURFACE_CREATE_INFO_KHR = 1000009000
        VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR = 1000001000
        VK_STRUCTURE_TYPE_PRESENT_INFO_KHR = 1000001001
        VK_STRUCTURE_TYPE_DEBUG_UTILS_MESSENGER_CREATE_INFO_EXT = 1000128004
    End Enum

    Public Enum VkFormat As Integer
        VK_FORMAT_UNDEFINED = 0
        VK_FORMAT_B8G8R8A8_SRGB = 50
        VK_FORMAT_B8G8R8A8_UNORM = 44
        VK_FORMAT_R8G8B8A8_SRGB = 43
        VK_FORMAT_D32_SFLOAT = 126
        VK_FORMAT_D32_SFLOAT_S8_UINT = 130
        VK_FORMAT_D24_UNORM_S8_UINT = 129
    End Enum

    Public Enum VkColorSpaceKHR
        VK_COLOR_SPACE_SRGB_NONLINEAR_KHR = 0
    End Enum

    Public Enum VkPresentModeKHR
        VK_PRESENT_MODE_IMMEDIATE_KHR = 0
        VK_PRESENT_MODE_MAILBOX_KHR = 1
        VK_PRESENT_MODE_FIFO_KHR = 2
        VK_PRESENT_MODE_FIFO_RELAXED_KHR = 3
    End Enum

    Public Enum VkSharingMode
        VK_SHARING_MODE_EXCLUSIVE = 0
        VK_SHARING_MODE_CONCURRENT = 1
    End Enum

    Public Enum VkImageUsageFlags As UInteger
        VK_IMAGE_USAGE_TRANSFER_SRC_BIT = &H1UI
        VK_IMAGE_USAGE_TRANSFER_DST_BIT = &H2UI
        VK_IMAGE_USAGE_SAMPLED_BIT = &H4UI
        VK_IMAGE_USAGE_STORAGE_BIT = &H8UI
        VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT = &H10UI
        VK_IMAGE_USAGE_DEPTH_STENCIL_ATTACHMENT_BIT = &H20UI
        VK_IMAGE_USAGE_TRANSIENT_ATTACHMENT_BIT = &H40UI
        VK_IMAGE_USAGE_INPUT_ATTACHMENT_BIT = &H80UI
    End Enum

    Public Enum VkCompositeAlphaFlagsKHR As UInteger
        VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR = &H1UI
        VK_COMPOSITE_ALPHA_PRE_MULTIPLIED_BIT_KHR = &H2UI
        VK_COMPOSITE_ALPHA_POST_MULTIPLIED_BIT_KHR = &H4UI
        VK_COMPOSITE_ALPHA_INHERIT_BIT_KHR = &H8UI
    End Enum

    Public Enum VkImageViewType
        VK_IMAGE_VIEW_TYPE_1D = 0
        VK_IMAGE_VIEW_TYPE_2D = 1
        VK_IMAGE_VIEW_TYPE_3D = 2
        VK_IMAGE_VIEW_TYPE_CUBE = 3
        VK_IMAGE_VIEW_TYPE_1D_ARRAY = 4
        VK_IMAGE_VIEW_TYPE_2D_ARRAY = 5
        VK_IMAGE_VIEW_TYPE_CUBE_ARRAY = 6
    End Enum

    Public Enum VkComponentSwizzle
        VK_COMPONENT_SWIZZLE_IDENTITY = 0
        VK_COMPONENT_SWIZZLE_ZERO = 1
        VK_COMPONENT_SWIZZLE_ONE = 2
        VK_COMPONENT_SWIZZLE_R = 3
        VK_COMPONENT_SWIZZLE_G = 4
        VK_COMPONENT_SWIZZLE_B = 5
        VK_COMPONENT_SWIZZLE_A = 6
    End Enum

    Public Enum VkImageAspectFlags As UInteger
        VK_IMAGE_ASPECT_COLOR_BIT = &H1UI
        VK_IMAGE_ASPECT_DEPTH_BIT = &H2UI
        VK_IMAGE_ASPECT_STENCIL_BIT = &H4UI
        VK_IMAGE_ASPECT_METADATA_BIT = &H8UI
    End Enum

    Public Enum VkShaderStageFlags As UInteger
        VK_SHADER_STAGE_VERTEX_BIT = &H1UI
        VK_SHADER_STAGE_TESSELLATION_CONTROL_BIT = &H2UI
        VK_SHADER_STAGE_TESSELLATION_EVALUATION_BIT = &H4UI
        VK_SHADER_STAGE_GEOMETRY_BIT = &H8UI
        VK_SHADER_STAGE_FRAGMENT_BIT = &H10UI
        VK_SHADER_STAGE_COMPUTE_BIT = &H20UI
        VK_SHADER_STAGE_ALL_GRAPHICS = &H1FUI
        VK_SHADER_STAGE_ALL = &H7FFFFFFFUI
    End Enum

    Public Enum VkPrimitiveTopology
        VK_PRIMITIVE_TOPOLOGY_POINT_LIST = 0
        VK_PRIMITIVE_TOPOLOGY_LINE_LIST = 1
        VK_PRIMITIVE_TOPOLOGY_LINE_STRIP = 2
        VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST = 3
        VK_PRIMITIVE_TOPOLOGY_TRIANGLE_STRIP = 4
        VK_PRIMITIVE_TOPOLOGY_TRIANGLE_FAN = 5
    End Enum

    Public Enum VkPolygonMode
        VK_POLYGON_MODE_FILL = 0
        VK_POLYGON_MODE_LINE = 1
        VK_POLYGON_MODE_POINT = 2
    End Enum

    Public Enum VkCullModeFlags As UInteger
        VK_CULL_MODE_NONE = 0
        VK_CULL_MODE_FRONT_BIT = &H1UI
        VK_CULL_MODE_BACK_BIT = &H2UI
        VK_CULL_MODE_FRONT_AND_BACK = &H3UI
    End Enum

    Public Enum VkFrontFace
        VK_FRONT_FACE_COUNTER_CLOCKWISE = 0
        VK_FRONT_FACE_CLOCKWISE = 1
    End Enum

    Public Enum VkSampleCountFlags As UInteger
        VK_SAMPLE_COUNT_1_BIT = &H1UI
        VK_SAMPLE_COUNT_2_BIT = &H2UI
        VK_SAMPLE_COUNT_4_BIT = &H4UI
        VK_SAMPLE_COUNT_8_BIT = &H8UI
        VK_SAMPLE_COUNT_16_BIT = &H10UI
        VK_SAMPLE_COUNT_32_BIT = &H20UI
        VK_SAMPLE_COUNT_64_BIT = &H40UI
    End Enum

    Public Enum VkBlendFactor
        VK_BLEND_FACTOR_ZERO = 0
        VK_BLEND_FACTOR_ONE = 1
        VK_BLEND_FACTOR_SRC_COLOR = 2
        VK_BLEND_FACTOR_ONE_MINUS_SRC_COLOR = 3
        VK_BLEND_FACTOR_DST_COLOR = 4
        VK_BLEND_FACTOR_ONE_MINUS_DST_COLOR = 5
        VK_BLEND_FACTOR_SRC_ALPHA = 6
        VK_BLEND_FACTOR_ONE_MINUS_SRC_ALPHA = 7
        VK_BLEND_FACTOR_DST_ALPHA = 8
        VK_BLEND_FACTOR_ONE_MINUS_DST_ALPHA = 9
    End Enum

    Public Enum VkBlendOp
        VK_BLEND_OP_ADD = 0
        VK_BLEND_OP_SUBTRACT = 1
        VK_BLEND_OP_REVERSE_SUBTRACT = 2
        VK_BLEND_OP_MIN = 3
        VK_BLEND_OP_MAX = 4
    End Enum

    Public Enum VkColorComponentFlags As UInteger
        VK_COLOR_COMPONENT_R_BIT = &H1UI
        VK_COLOR_COMPONENT_G_BIT = &H2UI
        VK_COLOR_COMPONENT_B_BIT = &H4UI
        VK_COLOR_COMPONENT_A_BIT = &H8UI
    End Enum

    Public Enum VkAttachmentLoadOp
        VK_ATTACHMENT_LOAD_OP_LOAD = 0
        VK_ATTACHMENT_LOAD_OP_CLEAR = 1
        VK_ATTACHMENT_LOAD_OP_DONT_CARE = 2
    End Enum

    Public Enum VkAttachmentStoreOp
        VK_ATTACHMENT_STORE_OP_STORE = 0
        VK_ATTACHMENT_STORE_OP_DONT_CARE = 1
    End Enum

    Public Enum VkImageLayout
        VK_IMAGE_LAYOUT_UNDEFINED = 0
        VK_IMAGE_LAYOUT_GENERAL = 1
        VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL = 2
        VK_IMAGE_LAYOUT_DEPTH_STENCIL_ATTACHMENT_OPTIMAL = 3
        VK_IMAGE_LAYOUT_DEPTH_STENCIL_READ_ONLY_OPTIMAL = 4
        VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL = 5
        VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL = 6
        VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL = 7
        VK_IMAGE_LAYOUT_PREINITIALIZED = 8
        VK_IMAGE_LAYOUT_PRESENT_SRC_KHR = 1000001002
    End Enum

    Public Enum VkPipelineBindPoint
        VK_PIPELINE_BIND_POINT_GRAPHICS = 0
        VK_PIPELINE_BIND_POINT_COMPUTE = 1
    End Enum

    Public Enum VkCommandPoolCreateFlags As UInteger
        VK_COMMAND_POOL_CREATE_TRANSIENT_BIT = &H1UI
        VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT = &H2UI
        VK_COMMAND_POOL_CREATE_PROTECTED_BIT = &H4UI
    End Enum

    Public Enum VkCommandBufferLevel
        VK_COMMAND_BUFFER_LEVEL_PRIMARY = 0
        VK_COMMAND_BUFFER_LEVEL_SECONDARY = 1
    End Enum

    Public Enum VkSubpassContents
        VK_SUBPASS_CONTENTS_INLINE = 0
        VK_SUBPASS_CONTENTS_SECONDARY_COMMAND_BUFFERS = 1
    End Enum

    Public Enum VkPipelineStageFlags As UInteger
        VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT = &H1UI
        VK_PIPELINE_STAGE_DRAW_INDIRECT_BIT = &H2UI
        VK_PIPELINE_STAGE_VERTEX_INPUT_BIT = &H4UI
        VK_PIPELINE_STAGE_VERTEX_SHADER_BIT = &H8UI
        VK_PIPELINE_STAGE_FRAGMENT_SHADER_BIT = &H80UI
        VK_PIPELINE_STAGE_EARLY_FRAGMENT_TESTS_BIT = &H100UI
        VK_PIPELINE_STAGE_LATE_FRAGMENT_TESTS_BIT = &H200UI
        VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT = &H400UI
        VK_PIPELINE_STAGE_TRANSFER_BIT = &H1000UI
        VK_PIPELINE_STAGE_BOTTOM_OF_PIPE_BIT = &H2000UI
        VK_PIPELINE_STAGE_ALL_GRAPHICS_BIT = &HFFFFUI
        VK_PIPELINE_STAGE_ALL_COMMANDS_BIT = &H10000UI
    End Enum

    Public Enum VkCommandBufferUsageFlags As UInteger
        VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT = &H1UI
        VK_COMMAND_BUFFER_USAGE_RENDER_PASS_CONTINUE_BIT = &H2UI
        VK_COMMAND_BUFFER_USAGE_SIMULTANEOUS_USE_BIT = &H4UI
    End Enum

    Public Enum VkResult
        VK_SUCCESS = 0
        VK_NOT_READY = 1
        VK_TIMEOUT = 2
        VK_EVENT_SET = 3
        VK_EVENT_RESET = 4
        VK_INCOMPLETE = 5
        VK_ERROR_OUT_OF_HOST_MEMORY = -1
        VK_ERROR_OUT_OF_DEVICE_MEMORY = -2
        VK_ERROR_INITIALIZATION_FAILED = -3
        VK_ERROR_DEVICE_LOST = -4
        VK_ERROR_MEMORY_MAP_FAILED = -5
        VK_ERROR_LAYER_NOT_PRESENT = -6
        VK_ERROR_EXTENSION_NOT_PRESENT = -7
        VK_ERROR_FEATURE_NOT_PRESENT = -8
        VK_ERROR_INCOMPATIBLE_DRIVER = -9
        VK_ERROR_TOO_MANY_OBJECTS = -10
        VK_ERROR_FORMAT_NOT_SUPPORTED = -11
        VK_ERROR_SURFACE_LOST_KHR = -1000000000
        VK_ERROR_NATIVE_WINDOW_IN_USE_KHR = -1000000001
        VK_SUBOPTIMAL_KHR = 1000001003
        VK_ERROR_OUT_OF_DATE_KHR = -1000001004
    End Enum

    Public Enum VkBool32
        [False] = 0
        [True] = 1
    End Enum

    Public Enum VkCompareOp
        VK_COMPARE_OP_NEVER = 0
        VK_COMPARE_OP_LESS = 1
        VK_COMPARE_OP_EQUAL = 2
        VK_COMPARE_OP_LESS_OR_EQUAL = 3
        VK_COMPARE_OP_GREATER = 4
        VK_COMPARE_OP_NOT_EQUAL = 5
        VK_COMPARE_OP_GREATER_OR_EQUAL = 6
        VK_COMPARE_OP_ALWAYS = 7
    End Enum

    Public Enum VkStencilOp
        VK_STENCIL_OP_KEEP = 0
        VK_STENCIL_OP_ZERO = 1
        VK_STENCIL_OP_REPLACE = 2
        VK_STENCIL_OP_INCREMENT_AND_CLAMP = 3
        VK_STENCIL_OP_DECREMENT_AND_CLAMP = 4
        VK_STENCIL_OP_INVERT = 5
        VK_STENCIL_OP_INCREMENT_AND_WRAP = 6
        VK_STENCIL_OP_DECREMENT_AND_WRAP = 7
    End Enum

    Public Enum VkImageTiling
        VK_IMAGE_TILING_OPTIMAL = 0
        VK_IMAGE_TILING_LINEAR = 1
    End Enum

    Public Enum VkMemoryPropertyFlags As UInteger
        VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT = &H1UI
        VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT = &H2UI
        VK_MEMORY_PROPERTY_HOST_COHERENT_BIT = &H4UI
        VK_MEMORY_PROPERTY_HOST_CACHED_BIT = &H8UI
        VK_MEMORY_PROPERTY_LAZILY_ALLOCATED_BIT = &H10UI
    End Enum

    <StructLayout(LayoutKind.Sequential)>
    Public Structure VkOffset2D
        Public x As Integer
        Public y As Integer
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Public Structure VkExtent2D
        Public width As UInteger
        Public height As UInteger
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Public Structure VkExtent3D
        Public width As UInteger
        Public height As UInteger
        Public depth As UInteger
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Public Structure VkRect2D
        Public offset As VkOffset2D
        Public extent As VkExtent2D
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Public Structure VkViewport
        Public x As Single
        Public y As Single
        Public width As Single
        Public height As Single
        Public minDepth As Single
        Public maxDepth As Single
    End Structure

    <StructLayout(LayoutKind.Sequential, CharSet:=CharSet.Ansi)>
    Public Structure VkApplicationInfo
        Public sType As VkStructureType
        Public pNext As IntPtr
        <MarshalAs(UnmanagedType.LPStr)> Public pApplicationName As String
        Public applicationVersion As UInteger
        <MarshalAs(UnmanagedType.LPStr)> Public pEngineName As String
        Public engineVersion As UInteger
        Public apiVersion As UInteger
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Public Structure VkInstanceCreateInfo
        Public sType As VkStructureType
        Public pNext As IntPtr
        Public flags As UInteger
        Public pApplicationInfo As IntPtr
        Public enabledLayerCount As UInteger
        Public ppEnabledLayerNames As IntPtr
        Public enabledExtensionCount As UInteger
        Public ppEnabledExtensionNames As IntPtr
    End Structure

    <StructLayout(LayoutKind.Sequential, CharSet:=CharSet.Ansi)>
    Public Structure VkPhysicalDeviceProperties
        Public apiVersion As UInteger
        Public driverVersion As UInteger
        Public vendorID As UInteger
        Public deviceID As UInteger
        Public deviceType As VkPhysicalDeviceType
        <MarshalAs(UnmanagedType.ByValTStr, SizeConst:=256)> Public deviceName As String
        <MarshalAs(UnmanagedType.ByValArray, SizeConst:=16)> Public pipelineCacheUUID() As Byte
        Public limits As VkPhysicalDeviceLimits
        Public sparseProperties As VkPhysicalDeviceSparseProperties
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Public Structure VkPhysicalDeviceLimits
        Public maxImageDimension1D As UInteger
        Public maxImageDimension2D As UInteger
        Public maxImageDimension3D As UInteger
        Public maxImageDimensionCube As UInteger
        Public maxImageArrayLayers As UInteger
        Public maxTexelBufferElements As UInteger
        Public maxUniformBufferRange As UInteger
        Public maxStorageBufferRange As UInteger
        Public maxPushConstantsSize As UInteger
        Public maxMemoryAllocationCount As UInteger
        Public maxSamplerAllocationCount As UInteger
        Public bufferImageGranularity As ULong
        Public sparseAddressSpaceSize As ULong
        Public maxBoundDescriptorSets As UInteger
        Public maxPerStageDescriptorSamplers As UInteger
        Public maxPerStageDescriptorUniformBuffers As UInteger
        Public maxPerStageDescriptorStorageBuffers As UInteger
        Public maxPerStageDescriptorSampledImages As UInteger
        Public maxPerStageDescriptorStorageImages As UInteger
        Public maxPerStageDescriptorInputAttachments As UInteger
        Public maxPerStageResources As UInteger
        Public maxDescriptorSetSamplers As UInteger
        Public maxDescriptorSetUniformBuffers As UInteger
        Public maxDescriptorSetUniformBuffersDynamic As UInteger
        Public maxDescriptorSetStorageBuffers As UInteger
        Public maxDescriptorSetStorageBuffersDynamic As UInteger
        Public maxDescriptorSetSampledImages As UInteger
        Public maxDescriptorSetStorageImages As UInteger
        Public maxDescriptorSetInputAttachments As UInteger
        Public maxVertexInputAttributes As UInteger
        Public maxVertexInputBindings As UInteger
        Public maxVertexInputAttributeOffset As UInteger
        Public maxVertexInputBindingStride As UInteger
        Public maxVertexOutputComponents As UInteger
        Public maxTessellationGenerationLevel As UInteger
        Public maxTessellationPatchSize As UInteger
        Public maxTessellationControlPerVertexInputComponents As UInteger
        Public maxTessellationControlPerVertexOutputComponents As UInteger
        Public maxTessellationControlPerPatchOutputComponents As UInteger
        Public maxTessellationControlTotalOutputComponents As UInteger
        Public maxTessellationEvaluationInputComponents As UInteger
        Public maxTessellationEvaluationOutputComponents As UInteger
        Public maxGeometryShaderInvocations As UInteger
        Public maxGeometryInputComponents As UInteger
        Public maxGeometryOutputComponents As UInteger
        Public maxGeometryOutputVertices As UInteger
        Public maxGeometryTotalOutputComponents As UInteger
        Public maxFragmentInputComponents As UInteger
        Public maxFragmentOutputAttachments As UInteger
        Public maxFragmentDualSrcAttachments As UInteger
        Public maxFragmentCombinedOutputResources As UInteger
        Public maxComputeSharedMemorySize As UInteger
        <MarshalAs(UnmanagedType.ByValArray, SizeConst:=3)> Public maxComputeWorkGroupCount() As UInteger
        Public maxComputeWorkGroupInvocations As UInteger
        <MarshalAs(UnmanagedType.ByValArray, SizeConst:=3)> Public maxComputeWorkGroupSize() As UInteger
        Public subPixelPrecisionBits As UInteger
        Public subTexelPrecisionBits As UInteger
        Public mipmapPrecisionBits As UInteger
        Public maxDrawIndexedIndexValue As UInteger
        Public maxDrawIndirectCount As UInteger
        Public maxSamplerLodBias As Single
        Public maxSamplerAnisotropy As Single
        Public maxViewports As UInteger
        <MarshalAs(UnmanagedType.ByValArray, SizeConst:=2)> Public maxViewportDimensions() As UInteger
        <MarshalAs(UnmanagedType.ByValArray, SizeConst:=2)> Public viewportBoundsRange() As Single
        Public viewportSubPixelBits As UInteger
        Public minMemoryMapAlignment As UIntPtr
        Public minTexelBufferOffsetAlignment As ULong
        Public minUniformBufferOffsetAlignment As ULong
        Public minStorageBufferOffsetAlignment As ULong
        Public minTexelOffset As Integer
        Public maxTexelOffset As UInteger
        Public minTexelGatherOffset As Integer
        Public maxTexelGatherOffset As UInteger
        Public minInterpolationOffset As Single
        Public maxInterpolationOffset As Single
        Public subPixelInterpolationOffsetBits As UInteger
        Public maxFramebufferWidth As UInteger
        Public maxFramebufferHeight As UInteger
        Public maxFramebufferLayers As UInteger
        Public framebufferColorSampleCounts As VkSampleCountFlags
        Public framebufferDepthSampleCounts As VkSampleCountFlags
        Public framebufferStencilSampleCounts As VkSampleCountFlags
        Public framebufferNoAttachmentsSampleCounts As VkSampleCountFlags
        Public maxColorAttachments As UInteger
        Public sampledImageColorSampleCounts As VkSampleCountFlags
        Public sampledImageIntegerSampleCounts As VkSampleCountFlags
        Public sampledImageDepthSampleCounts As VkSampleCountFlags
        Public sampledImageStencilSampleCounts As VkSampleCountFlags
        Public storageImageSampleCounts As VkSampleCountFlags
        Public maxSampleMaskWords As UInteger
        Public timestampComputeAndGraphics As VkBool32
        Public timestampPeriod As Single
        Public maxClipDistances As UInteger
        Public maxCullDistances As UInteger
        Public maxCombinedClipAndCullDistances As UInteger
        Public discreteQueuePriorities As UInteger
        <MarshalAs(UnmanagedType.ByValArray, SizeConst:=2)> Public pointSizeRange() As Single
        <MarshalAs(UnmanagedType.ByValArray, SizeConst:=2)> Public lineWidthRange() As Single
        Public pointSizeGranularity As Single
        Public lineWidthGranularity As Single
        Public strictLines As VkBool32
        Public standardSampleLocations As VkBool32
        Public optimalBufferCopyOffsetAlignment As ULong
        Public optimalBufferCopyRowPitchAlignment As ULong
        Public nonCoherentAtomSize As ULong
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Public Structure VkPhysicalDeviceSparseProperties
        Public residencyStandard2DBlockShape As VkBool32
        Public residencyStandard2DMultisampleBlockShape As VkBool32
        Public residencyStandard3DBlockShape As VkBool32
        Public residencyAlignedMipSize As VkBool32
        Public residencyNonResidentStrict As VkBool32
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Public Structure VkQueueFamilyProperties
        Public queueFlags As UInteger
        Public queueCount As UInteger
        Public timestampValidBits As UInteger
        Public minImageTransferGranularity As VkExtent3D
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Public Structure VkDeviceQueueCreateInfo
        Public sType As VkStructureType
        Public pNext As IntPtr
        Public flags As UInteger
        Public queueFamilyIndex As UInteger
        Public queueCount As UInteger
        Public pQueuePriorities As IntPtr
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Public Structure VkPhysicalDeviceFeatures
        Public robustBufferAccess As VkBool32
        Public fullDrawIndexUint32 As VkBool32
        Public imageCubeArray As VkBool32
        Public independentBlend As VkBool32
        Public geometryShader As VkBool32
        Public tessellationShader As VkBool32
        Public sampleRateShading As VkBool32
        Public dualSrcBlend As VkBool32
        Public logicOp As VkBool32
        Public multiDrawIndirect As VkBool32
        Public drawIndirectFirstInstance As VkBool32
        Public depthClamp As VkBool32
        Public depthBiasClamp As VkBool32
        Public fillModeNonSolid As VkBool32
        Public depthBounds As VkBool32
        Public wideLines As VkBool32
        Public largePoints As VkBool32
        Public alphaToOne As VkBool32
        Public multiViewport As VkBool32
        Public samplerAnisotropy As VkBool32
        Public textureCompressionETC2 As VkBool32
        Public textureCompressionASTC_LDR As VkBool32
        Public textureCompressionBC As VkBool32
        Public occlusionQueryPrecise As VkBool32
        Public pipelineStatisticsQuery As VkBool32
        Public vertexPipelineStoresAndAtomics As VkBool32
        Public fragmentStoresAndAtomics As VkBool32
        Public shaderTessellationAndGeometryPointSize As VkBool32
        Public shaderImageGatherExtended As VkBool32
        Public shaderStorageImageExtendedFormats As VkBool32
        Public shaderStorageImageMultisample As VkBool32
        Public shaderStorageImageReadWithoutFormat As VkBool32
        Public shaderStorageImageWriteWithoutFormat As VkBool32
        Public shaderUniformBufferArrayDynamicIndexing As VkBool32
        Public shaderSampledImageArrayDynamicIndexing As VkBool32
        Public shaderStorageBufferArrayDynamicIndexing As VkBool32
        Public shaderStorageImageArrayDynamicIndexing As VkBool32
        Public shaderClipDistance As VkBool32
        Public shaderCullDistance As VkBool32
        Public shaderFloat64 As VkBool32
        Public shaderInt64 As VkBool32
        Public shaderInt16 As VkBool32
        Public shaderResourceResidency As VkBool32
        Public shaderResourceMinLod As VkBool32
        Public sparseBinding As VkBool32
        Public sparseResidencyBuffer As VkBool32
        Public sparseResidencyImage2D As VkBool32
        Public sparseResidencyImage3D As VkBool32
        Public sparseResidency2Samples As VkBool32
        Public sparseResidency4Samples As VkBool32
        Public sparseResidency8Samples As VkBool32
        Public sparseResidency16Samples As VkBool32
        Public sparseResidencyAliased As VkBool32
        Public variableMultisampleRate As VkBool32
        Public inheritedQueries As VkBool32
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Public Structure VkDeviceCreateInfo
        Public sType As VkStructureType
        Public pNext As IntPtr
        Public flags As UInteger
        Public queueCreateInfoCount As UInteger
        Public pQueueCreateInfos As IntPtr
        Public enabledLayerCount As UInteger
        Public ppEnabledLayerNames As IntPtr
        Public enabledExtensionCount As UInteger
        Public ppEnabledExtensionNames As IntPtr
        Public pEnabledFeatures As IntPtr
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Public Structure VkWin32SurfaceCreateInfoKHR
        Public sType As VkStructureType
        Public pNext As IntPtr
        Public flags As UInteger
        Public hinstance As IntPtr
        Public hwnd As IntPtr
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Public Structure VkSurfaceCapabilitiesKHR
        Public minImageCount As UInteger
        Public maxImageCount As UInteger
        Public currentExtent As VkExtent2D
        Public minImageExtent As VkExtent2D
        Public maxImageExtent As VkExtent2D
        Public maxImageArrayLayers As UInteger
        Public supportedTransforms As UInteger
        Public currentTransform As UInteger
        Public supportedCompositeAlpha As UInteger
        Public supportedUsageFlags As UInteger
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Public Structure VkSurfaceFormatKHR
        Public format As VkFormat
        Public colorSpace As VkColorSpaceKHR
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Public Structure VkSwapchainCreateInfoKHR
        Public sType As VkStructureType
        Public pNext As IntPtr
        Public flags As UInteger
        Public surface As IntPtr
        Public minImageCount As UInteger
        Public imageFormat As VkFormat
        Public imageColorSpace As VkColorSpaceKHR
        Public imageExtent As VkExtent2D
        Public imageArrayLayers As UInteger
        Public imageUsage As VkImageUsageFlags
        Public imageSharingMode As VkSharingMode
        Public queueFamilyIndexCount As UInteger
        Public pQueueFamilyIndices As IntPtr
        Public preTransform As UInteger
        Public compositeAlpha As VkCompositeAlphaFlagsKHR
        Public presentMode As VkPresentModeKHR
        Public clipped As VkBool32
        Public oldSwapchain As IntPtr
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Public Structure VkComponentMapping
        Public r As VkComponentSwizzle
        Public g As VkComponentSwizzle
        Public b As VkComponentSwizzle
        Public a As VkComponentSwizzle
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Public Structure VkImageSubresourceRange
        Public aspectMask As VkImageAspectFlags
        Public baseMipLevel As UInteger
        Public levelCount As UInteger
        Public baseArrayLayer As UInteger
        Public layerCount As UInteger
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Public Structure VkImageViewCreateInfo
        Public sType As VkStructureType
        Public pNext As IntPtr
        Public flags As UInteger
        Public image As IntPtr
        Public viewType As VkImageViewType
        Public format As VkFormat
        Public components As VkComponentMapping
        Public subresourceRange As VkImageSubresourceRange
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Public Structure VkShaderModuleCreateInfo
        Public sType As VkStructureType
        Public pNext As IntPtr
        Public flags As UInteger
        Public codeSize As UIntPtr
        Public pCode As IntPtr
    End Structure

    <StructLayout(LayoutKind.Sequential, CharSet:=CharSet.Ansi)>
    Public Structure VkPipelineShaderStageCreateInfo
        Public sType As VkStructureType
        Public pNext As IntPtr
        Public flags As UInteger
        Public stage As VkShaderStageFlags
        Public [module] As IntPtr
        Public pName As IntPtr
        Public pSpecializationInfo As IntPtr
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Public Structure VkPipelineVertexInputStateCreateInfo
        Public sType As VkStructureType
        Public pNext As IntPtr
        Public flags As UInteger
        Public vertexBindingDescriptionCount As UInteger
        Public pVertexBindingDescriptions As IntPtr
        Public vertexAttributeDescriptionCount As UInteger
        Public pVertexAttributeDescriptions As IntPtr
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Public Structure VkPipelineInputAssemblyStateCreateInfo
        Public sType As VkStructureType
        Public pNext As IntPtr
        Public flags As UInteger
        Public topology As VkPrimitiveTopology
        Public primitiveRestartEnable As VkBool32
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Public Structure VkPipelineViewportStateCreateInfo
        Public sType As VkStructureType
        Public pNext As IntPtr
        Public flags As UInteger
        Public viewportCount As UInteger
        Public pViewports As IntPtr
        Public scissorCount As UInteger
        Public pScissors As IntPtr
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Public Structure VkPipelineRasterizationStateCreateInfo
        Public sType As VkStructureType
        Public pNext As IntPtr
        Public flags As UInteger
        Public depthClampEnable As VkBool32
        Public rasterizerDiscardEnable As VkBool32
        Public polygonMode As VkPolygonMode
        Public cullMode As VkCullModeFlags
        Public frontFace As VkFrontFace
        Public depthBiasEnable As VkBool32
        Public depthBiasConstantFactor As Single
        Public depthBiasClamp As Single
        Public depthBiasSlopeFactor As Single
        Public lineWidth As Single
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Public Structure VkPipelineMultisampleStateCreateInfo
        Public sType As VkStructureType
        Public pNext As IntPtr
        Public flags As UInteger
        Public rasterizationSamples As VkSampleCountFlags
        Public sampleShadingEnable As VkBool32
        Public minSampleShading As Single
        Public pSampleMask As IntPtr
        Public alphaToCoverageEnable As VkBool32
        Public alphaToOneEnable As VkBool32
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Public Structure VkStencilOpState
        Public failOp As VkStencilOp
        Public passOp As VkStencilOp
        Public depthFailOp As VkStencilOp
        Public compareOp As VkCompareOp
        Public compareMask As UInteger
        Public writeMask As UInteger
        Public reference As UInteger
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Public Structure VkPipelineDepthStencilStateCreateInfo
        Public sType As VkStructureType
        Public pNext As IntPtr
        Public flags As UInteger
        Public depthTestEnable As VkBool32
        Public depthWriteEnable As VkBool32
        Public depthCompareOp As VkCompareOp
        Public depthBoundsTestEnable As VkBool32
        Public stencilTestEnable As VkBool32
        Public front As VkStencilOpState
        Public back As VkStencilOpState
        Public minDepthBounds As Single
        Public maxDepthBounds As Single
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Public Structure VkPipelineColorBlendAttachmentState
        Public blendEnable As VkBool32
        Public srcColorBlendFactor As VkBlendFactor
        Public dstColorBlendFactor As VkBlendFactor
        Public colorBlendOp As VkBlendOp
        Public srcAlphaBlendFactor As VkBlendFactor
        Public dstAlphaBlendFactor As VkBlendFactor
        Public alphaBlendOp As VkBlendOp
        Public colorWriteMask As VkColorComponentFlags
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Public Structure VkPipelineColorBlendStateCreateInfo
        Public sType As VkStructureType
        Public pNext As IntPtr
        Public flags As UInteger
        Public logicOpEnable As VkBool32
        Public logicOp As Integer
        Public attachmentCount As UInteger
        Public pAttachments As IntPtr
        <MarshalAs(UnmanagedType.ByValArray, SizeConst:=4)> Public blendConstants() As Single
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Public Structure VkPipelineLayoutCreateInfo
        Public sType As VkStructureType
        Public pNext As IntPtr
        Public flags As UInteger
        Public setLayoutCount As UInteger
        Public pSetLayouts As IntPtr
        Public pushConstantRangeCount As UInteger
        Public pPushConstantRanges As IntPtr
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Public Structure VkAttachmentDescription
        Public flags As UInteger
        Public format As VkFormat
        Public samples As VkSampleCountFlags
        Public loadOp As VkAttachmentLoadOp
        Public storeOp As VkAttachmentStoreOp
        Public stencilLoadOp As VkAttachmentLoadOp
        Public stencilStoreOp As VkAttachmentStoreOp
        Public initialLayout As VkImageLayout
        Public finalLayout As VkImageLayout
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Public Structure VkAttachmentReference
        Public attachment As UInteger
        Public layout As VkImageLayout
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Public Structure VkSubpassDescription
        Public flags As UInteger
        Public pipelineBindPoint As VkPipelineBindPoint
        Public inputAttachmentCount As UInteger
        Public pInputAttachments As IntPtr
        Public colorAttachmentCount As UInteger
        Public pColorAttachments As IntPtr
        Public pResolveAttachments As IntPtr
        Public pDepthStencilAttachment As IntPtr
        Public preserveAttachmentCount As UInteger
        Public pPreserveAttachments As IntPtr
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Public Structure VkSubpassDependency
        Public srcSubpass As UInteger
        Public dstSubpass As UInteger
        Public srcStageMask As VkPipelineStageFlags
        Public dstStageMask As VkPipelineStageFlags
        Public srcAccessMask As UInteger
        Public dstAccessMask As UInteger
        Public dependencyFlags As UInteger
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Public Structure VkRenderPassCreateInfo
        Public sType As VkStructureType
        Public pNext As IntPtr
        Public flags As UInteger
        Public attachmentCount As UInteger
        Public pAttachments As IntPtr
        Public subpassCount As UInteger
        Public pSubpasses As IntPtr
        Public dependencyCount As UInteger
        Public pDependencies As IntPtr
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Public Structure VkGraphicsPipelineCreateInfo
        Public sType As VkStructureType
        Public pNext As IntPtr
        Public flags As UInteger
        Public stageCount As UInteger
        Public pStages As IntPtr
        Public pVertexInputState As IntPtr
        Public pInputAssemblyState As IntPtr
        Public pTessellationState As IntPtr
        Public pViewportState As IntPtr
        Public pRasterizationState As IntPtr
        Public pMultisampleState As IntPtr
        Public pDepthStencilState As IntPtr
        Public pColorBlendState As IntPtr
        Public pDynamicState As IntPtr
        Public layout As IntPtr
        Public renderPass As IntPtr
        Public subpass As UInteger
        Public basePipelineHandle As IntPtr
        Public basePipelineIndex As Integer
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Public Structure VkFramebufferCreateInfo
        Public sType As VkStructureType
        Public pNext As IntPtr
        Public flags As UInteger
        Public renderPass As IntPtr
        Public attachmentCount As UInteger
        Public pAttachments As IntPtr
        Public width As UInteger
        Public height As UInteger
        Public layers As UInteger
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Public Structure VkCommandPoolCreateInfo
        Public sType As VkStructureType
        Public pNext As IntPtr
        Public flags As VkCommandPoolCreateFlags
        Public queueFamilyIndex As UInteger
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Public Structure VkCommandBufferAllocateInfo
        Public sType As VkStructureType
        Public pNext As IntPtr
        Public commandPool As IntPtr
        Public level As VkCommandBufferLevel
        Public commandBufferCount As UInteger
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Public Structure VkCommandBufferBeginInfo
        Public sType As VkStructureType
        Public pNext As IntPtr
        Public flags As VkCommandBufferUsageFlags
        Public pInheritanceInfo As IntPtr
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Public Structure VkClearColorValue
        Public float32_0 As Single
        Public float32_1 As Single
        Public float32_2 As Single
        Public float32_3 As Single
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Public Structure VkClearDepthStencilValue
        Public depth As Single
        Public stencil As UInteger
    End Structure

    <StructLayout(LayoutKind.Explicit)>
    Public Structure VkClearValue
        <FieldOffset(0)> Public color As VkClearColorValue
        <FieldOffset(0)> Public depthStencil As VkClearDepthStencilValue
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Public Structure VkRenderPassBeginInfo
        Public sType As VkStructureType
        Public pNext As IntPtr
        Public renderPass As IntPtr
        Public framebuffer As IntPtr
        Public renderArea As VkRect2D
        Public clearValueCount As UInteger
        Public pClearValues As IntPtr
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Public Structure VkSubmitInfo
        Public sType As VkStructureType
        Public pNext As IntPtr
        Public waitSemaphoreCount As UInteger
        Public pWaitSemaphores As IntPtr
        Public pWaitDstStageMask As IntPtr
        Public commandBufferCount As UInteger
        Public pCommandBuffers As IntPtr
        Public signalSemaphoreCount As UInteger
        Public pSignalSemaphores As IntPtr
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Public Structure VkPresentInfoKHR
        Public sType As VkStructureType
        Public pNext As IntPtr
        Public waitSemaphoreCount As UInteger
        Public pWaitSemaphores As IntPtr
        Public swapchainCount As UInteger
        Public pSwapchains As IntPtr
        Public pImageIndices As IntPtr
        Public pResults As IntPtr
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Public Structure VkSemaphoreCreateInfo
        Public sType As VkStructureType
        Public pNext As IntPtr
        Public flags As UInteger
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Public Structure VkFenceCreateInfo
        Public sType As VkStructureType
        Public pNext As IntPtr
        Public flags As UInteger
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Public Structure VkImageCreateInfo
        Public sType As VkStructureType
        Public pNext As IntPtr
        Public flags As UInteger
        Public imageType As Integer
        Public format As VkFormat
        Public extent As VkExtent3D
        Public mipLevels As UInteger
        Public arrayLayers As UInteger
        Public samples As VkSampleCountFlags
        Public tiling As VkImageTiling
        Public usage As VkImageUsageFlags
        Public sharingMode As VkSharingMode
        Public queueFamilyIndexCount As UInteger
        Public pQueueFamilyIndices As IntPtr
        Public initialLayout As VkImageLayout
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Public Structure VkMemoryRequirements
        Public size As ULong
        Public alignment As ULong
        Public memoryTypeBits As UInteger
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Public Structure VkPhysicalDeviceMemoryProperties
        Public memoryTypeCount As UInteger
        <MarshalAs(UnmanagedType.ByValArray, SizeConst:=32)> Public memoryTypes() As VkMemoryType
        Public memoryHeapCount As UInteger
        <MarshalAs(UnmanagedType.ByValArray, SizeConst:=16)> Public memoryHeaps() As VkMemoryHeap
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Public Structure VkMemoryType
        Public propertyFlags As VkMemoryPropertyFlags
        Public heapIndex As UInteger
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Public Structure VkMemoryHeap
        Public size As ULong
        Public flags As UInteger
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Public Structure VkMemoryAllocateInfo
        Public sType As VkStructureType
        Public pNext As IntPtr
        Public allocationSize As ULong
        Public memoryTypeIndex As UInteger
    End Structure

    <StructLayout(LayoutKind.Sequential, CharSet:=CharSet.Ansi)>
    Public Structure VkDebugUtilsMessengerCallbackDataEXT
        Public sType As VkStructureType
        Public pNext As IntPtr
        Public flags As UInteger
        <MarshalAs(UnmanagedType.LPStr)> Public pMessageIdName As String
        Public messageIdNumber As Integer
        <MarshalAs(UnmanagedType.LPStr)> Public pMessage As String
        Public queueLabelCount As UInteger
        Public pQueueLabels As IntPtr
        Public cmdBufLabelCount As UInteger
        Public pCmdBufLabels As IntPtr
        Public objectCount As UInteger
        Public pObjects As IntPtr
    End Structure

    Delegate Function DebugCallback(ByVal messageSeverity As VkDebugUtilsMessageSeverityFlagsEXT,
                                     ByVal messageTypes As VkDebugUtilsMessageTypeFlagsEXT,
                                     ByRef pCallbackData As VkDebugUtilsMessengerCallbackDataEXT,
                                     ByVal pUserData As IntPtr) As VkBool32

    <StructLayout(LayoutKind.Sequential)>
    Public Structure VkDebugUtilsMessengerCreateInfoEXT
        Public sType As VkStructureType
        Public pNext As IntPtr
        Public flags As UInteger
        Public messageSeverity As VkDebugUtilsMessageSeverityFlagsEXT
        Public messageType As VkDebugUtilsMessageTypeFlagsEXT
        Public pfnUserCallback As IntPtr
        Public pUserData As IntPtr
    End Structure

    ' Vulkan function imports
    Private Const VulkanLib As String = "vulkan-1.dll"

    <DllImport(VulkanLib, CallingConvention:=CallingConvention.StdCall)>
    Private Shared Function vkCreateInstance(ByRef pCreateInfo As VkInstanceCreateInfo, ByVal pAllocator As IntPtr, ByRef pInstance As IntPtr) As VkResult
    End Function

    <DllImport(VulkanLib, CallingConvention:=CallingConvention.StdCall)>
    Private Shared Sub vkDestroyInstance(ByVal instance As IntPtr, ByVal pAllocator As IntPtr)
    End Sub

    <DllImport(VulkanLib, CallingConvention:=CallingConvention.StdCall)>
    Private Shared Function vkEnumeratePhysicalDevices(ByVal instance As IntPtr, ByRef pPhysicalDeviceCount As UInteger, ByVal pPhysicalDevices As IntPtr) As VkResult
    End Function

    <DllImport(VulkanLib, CallingConvention:=CallingConvention.StdCall)>
    Private Shared Sub vkGetPhysicalDeviceProperties(ByVal physicalDevice As IntPtr, ByRef pProperties As VkPhysicalDeviceProperties)
    End Sub

    <DllImport(VulkanLib, CallingConvention:=CallingConvention.StdCall)>
    Private Shared Sub vkGetPhysicalDeviceQueueFamilyProperties(ByVal physicalDevice As IntPtr, ByRef pQueueFamilyPropertyCount As UInteger, ByVal pQueueFamilyProperties As IntPtr)
    End Sub

    <DllImport(VulkanLib, CallingConvention:=CallingConvention.StdCall)>
    Private Shared Function vkCreateDevice(ByVal physicalDevice As IntPtr, ByRef pCreateInfo As VkDeviceCreateInfo, ByVal pAllocator As IntPtr, ByRef pDevice As IntPtr) As VkResult
    End Function

    <DllImport(VulkanLib, CallingConvention:=CallingConvention.StdCall)>
    Private Shared Sub vkDestroyDevice(ByVal device As IntPtr, ByVal pAllocator As IntPtr)
    End Sub

    <DllImport(VulkanLib, CallingConvention:=CallingConvention.StdCall)>
    Private Shared Sub vkGetDeviceQueue(ByVal device As IntPtr, ByVal queueFamilyIndex As UInteger, ByVal queueIndex As UInteger, ByRef pQueue As IntPtr)
    End Sub

    <DllImport(VulkanLib, CallingConvention:=CallingConvention.StdCall, CharSet:=CharSet.Ansi)>
    Private Shared Function vkGetInstanceProcAddr(ByVal instance As IntPtr, <MarshalAs(UnmanagedType.LPStr)> ByVal pName As String) As IntPtr
    End Function

    <DllImport(VulkanLib, CallingConvention:=CallingConvention.StdCall)>
    Private Shared Function vkGetPhysicalDeviceSurfaceSupportKHR(ByVal physicalDevice As IntPtr, ByVal queueFamilyIndex As UInteger, ByVal surface As IntPtr, ByRef pSupported As VkBool32) As VkResult
    End Function

    <DllImport(VulkanLib, CallingConvention:=CallingConvention.StdCall)>
    Private Shared Function vkGetPhysicalDeviceSurfaceCapabilitiesKHR(ByVal physicalDevice As IntPtr, ByVal surface As IntPtr, ByRef pSurfaceCapabilities As VkSurfaceCapabilitiesKHR) As VkResult
    End Function

    <DllImport(VulkanLib, CallingConvention:=CallingConvention.StdCall)>
    Private Shared Function vkGetPhysicalDeviceSurfaceFormatsKHR(ByVal physicalDevice As IntPtr, ByVal surface As IntPtr, ByRef pSurfaceFormatCount As UInteger, ByVal pSurfaceFormats As IntPtr) As VkResult
    End Function

    <DllImport(VulkanLib, CallingConvention:=CallingConvention.StdCall)>
    Private Shared Function vkGetPhysicalDeviceSurfacePresentModesKHR(ByVal physicalDevice As IntPtr, ByVal surface As IntPtr, ByRef pPresentModeCount As UInteger, ByVal pPresentModes As IntPtr) As VkResult
    End Function

    <DllImport(VulkanLib, CallingConvention:=CallingConvention.StdCall)>
    Private Shared Function vkCreateSwapchainKHR(ByVal device As IntPtr, ByRef pCreateInfo As VkSwapchainCreateInfoKHR, ByVal pAllocator As IntPtr, ByRef pSwapchain As IntPtr) As VkResult
    End Function

    <DllImport(VulkanLib, CallingConvention:=CallingConvention.StdCall)>
    Private Shared Sub vkDestroySwapchainKHR(ByVal device As IntPtr, ByVal swapchain As IntPtr, ByVal pAllocator As IntPtr)
    End Sub

    <DllImport(VulkanLib, CallingConvention:=CallingConvention.StdCall)>
    Private Shared Function vkGetSwapchainImagesKHR(ByVal device As IntPtr, ByVal swapchain As IntPtr, ByRef pSwapchainImageCount As UInteger, ByVal pSwapchainImages As IntPtr) As VkResult
    End Function

    <DllImport(VulkanLib, CallingConvention:=CallingConvention.StdCall)>
    Private Shared Function vkCreateImageView(ByVal device As IntPtr, ByRef pCreateInfo As VkImageViewCreateInfo, ByVal pAllocator As IntPtr, ByRef pView As IntPtr) As VkResult
    End Function

    <DllImport(VulkanLib, CallingConvention:=CallingConvention.StdCall)>
    Private Shared Sub vkDestroyImageView(ByVal device As IntPtr, ByVal imageView As IntPtr, ByVal pAllocator As IntPtr)
    End Sub

    <DllImport(VulkanLib, CallingConvention:=CallingConvention.StdCall)>
    Private Shared Function vkCreateShaderModule(ByVal device As IntPtr, ByRef pCreateInfo As VkShaderModuleCreateInfo, ByVal pAllocator As IntPtr, ByRef pShaderModule As IntPtr) As VkResult
    End Function

    <DllImport(VulkanLib, CallingConvention:=CallingConvention.StdCall)>
    Private Shared Sub vkDestroyShaderModule(ByVal device As IntPtr, ByVal shaderModule As IntPtr, ByVal pAllocator As IntPtr)
    End Sub

    <DllImport(VulkanLib, CallingConvention:=CallingConvention.StdCall)>
    Private Shared Function vkCreatePipelineLayout(ByVal device As IntPtr, ByRef pCreateInfo As VkPipelineLayoutCreateInfo, ByVal pAllocator As IntPtr, ByRef pPipelineLayout As IntPtr) As VkResult
    End Function

    <DllImport(VulkanLib, CallingConvention:=CallingConvention.StdCall)>
    Private Shared Sub vkDestroyPipelineLayout(ByVal device As IntPtr, ByVal pipelineLayout As IntPtr, ByVal pAllocator As IntPtr)
    End Sub

    <DllImport(VulkanLib, CallingConvention:=CallingConvention.StdCall)>
    Private Shared Function vkCreateRenderPass(ByVal device As IntPtr, ByRef pCreateInfo As VkRenderPassCreateInfo, ByVal pAllocator As IntPtr, ByRef pRenderPass As IntPtr) As VkResult
    End Function

    <DllImport(VulkanLib, CallingConvention:=CallingConvention.StdCall)>
    Private Shared Sub vkDestroyRenderPass(ByVal device As IntPtr, ByVal renderPass As IntPtr, ByVal pAllocator As IntPtr)
    End Sub

    <DllImport(VulkanLib, CallingConvention:=CallingConvention.StdCall)>
    Private Shared Function vkCreateGraphicsPipelines(ByVal device As IntPtr, ByVal pipelineCache As IntPtr, ByVal createInfoCount As UInteger, ByVal pCreateInfos As IntPtr, ByVal pAllocator As IntPtr, ByVal pPipelines As IntPtr) As VkResult
    End Function

    <DllImport(VulkanLib, CallingConvention:=CallingConvention.StdCall)>
    Private Shared Sub vkDestroyPipeline(ByVal device As IntPtr, ByVal pipeline As IntPtr, ByVal pAllocator As IntPtr)
    End Sub

    <DllImport(VulkanLib, CallingConvention:=CallingConvention.StdCall)>
    Private Shared Function vkCreateFramebuffer(ByVal device As IntPtr, ByRef pCreateInfo As VkFramebufferCreateInfo, ByVal pAllocator As IntPtr, ByRef pFramebuffer As IntPtr) As VkResult
    End Function

    <DllImport(VulkanLib, CallingConvention:=CallingConvention.StdCall)>
    Private Shared Sub vkDestroyFramebuffer(ByVal device As IntPtr, ByVal framebuffer As IntPtr, ByVal pAllocator As IntPtr)
    End Sub

    <DllImport(VulkanLib, CallingConvention:=CallingConvention.StdCall)>
    Private Shared Function vkCreateCommandPool(ByVal device As IntPtr, ByRef pCreateInfo As VkCommandPoolCreateInfo, ByVal pAllocator As IntPtr, ByRef pCommandPool As IntPtr) As VkResult
    End Function

    <DllImport(VulkanLib, CallingConvention:=CallingConvention.StdCall)>
    Private Shared Sub vkDestroyCommandPool(ByVal device As IntPtr, ByVal commandPool As IntPtr, ByVal pAllocator As IntPtr)
    End Sub

    <DllImport(VulkanLib, CallingConvention:=CallingConvention.StdCall)>
    Private Shared Function vkAllocateCommandBuffers(ByVal device As IntPtr, ByRef pAllocateInfo As VkCommandBufferAllocateInfo, ByVal pCommandBuffers As IntPtr) As VkResult
    End Function

    <DllImport(VulkanLib, CallingConvention:=CallingConvention.StdCall)>
    Private Shared Function vkBeginCommandBuffer(ByVal commandBuffer As IntPtr, ByRef pBeginInfo As VkCommandBufferBeginInfo) As VkResult
    End Function

    <DllImport(VulkanLib, CallingConvention:=CallingConvention.StdCall)>
    Private Shared Function vkEndCommandBuffer(ByVal commandBuffer As IntPtr) As VkResult
    End Function

    <DllImport(VulkanLib, CallingConvention:=CallingConvention.StdCall)>
    Private Shared Sub vkCmdBeginRenderPass(ByVal commandBuffer As IntPtr, ByRef pRenderPassBegin As VkRenderPassBeginInfo, ByVal contents As VkSubpassContents)
    End Sub

    <DllImport(VulkanLib, CallingConvention:=CallingConvention.StdCall)>
    Private Shared Sub vkCmdEndRenderPass(ByVal commandBuffer As IntPtr)
    End Sub

    <DllImport(VulkanLib, CallingConvention:=CallingConvention.StdCall)>
    Private Shared Sub vkCmdBindPipeline(ByVal commandBuffer As IntPtr, ByVal pipelineBindPoint As VkPipelineBindPoint, ByVal pipeline As IntPtr)
    End Sub

    <DllImport(VulkanLib, CallingConvention:=CallingConvention.StdCall)>
    Private Shared Sub vkCmdDraw(ByVal commandBuffer As IntPtr, ByVal vertexCount As UInteger, ByVal instanceCount As UInteger, ByVal firstVertex As UInteger, ByVal firstInstance As UInteger)
    End Sub

    <DllImport(VulkanLib, CallingConvention:=CallingConvention.StdCall)>
    Private Shared Function vkQueueSubmit(ByVal queue As IntPtr, ByVal submitCount As UInteger, ByRef pSubmits As VkSubmitInfo, ByVal fence As IntPtr) As VkResult
    End Function

    <DllImport(VulkanLib, CallingConvention:=CallingConvention.StdCall)>
    Private Shared Function vkQueueWaitIdle(ByVal queue As IntPtr) As VkResult
    End Function

    <DllImport(VulkanLib, CallingConvention:=CallingConvention.StdCall)>
    Private Shared Function vkDeviceWaitIdle(ByVal device As IntPtr) As VkResult
    End Function

    <DllImport(VulkanLib, CallingConvention:=CallingConvention.StdCall)>
    Private Shared Function vkAcquireNextImageKHR(ByVal device As IntPtr, ByVal swapchain As IntPtr, ByVal timeout As ULong, ByVal semaphore As IntPtr, ByVal fence As IntPtr, ByRef pImageIndex As UInteger) As VkResult
    End Function

    <DllImport(VulkanLib, CallingConvention:=CallingConvention.StdCall)>
    Private Shared Function vkQueuePresentKHR(ByVal queue As IntPtr, ByRef pPresentInfo As VkPresentInfoKHR) As VkResult
    End Function

    <DllImport(VulkanLib, CallingConvention:=CallingConvention.StdCall)>
    Private Shared Function vkCreateSemaphore(ByVal device As IntPtr, ByRef pCreateInfo As VkSemaphoreCreateInfo, ByVal pAllocator As IntPtr, ByRef pSemaphore As IntPtr) As VkResult
    End Function

    <DllImport(VulkanLib, CallingConvention:=CallingConvention.StdCall)>
    Private Shared Sub vkDestroySemaphore(ByVal device As IntPtr, ByVal semaphore As IntPtr, ByVal pAllocator As IntPtr)
    End Sub

    <DllImport(VulkanLib, CallingConvention:=CallingConvention.StdCall)>
    Private Shared Function vkCreateFence(ByVal device As IntPtr, ByRef pCreateInfo As VkFenceCreateInfo, ByVal pAllocator As IntPtr, ByRef pFence As IntPtr) As VkResult
    End Function

    <DllImport(VulkanLib, CallingConvention:=CallingConvention.StdCall)>
    Private Shared Sub vkDestroyFence(ByVal device As IntPtr, ByVal fence As IntPtr, ByVal pAllocator As IntPtr)
    End Sub

    <DllImport(VulkanLib, CallingConvention:=CallingConvention.StdCall)>
    Private Shared Function vkWaitForFences(ByVal device As IntPtr, ByVal fenceCount As UInteger, ByRef pFences As IntPtr, ByVal waitAll As VkBool32, ByVal timeout As ULong) As VkResult
    End Function

    <DllImport(VulkanLib, CallingConvention:=CallingConvention.StdCall)>
    Private Shared Function vkResetFences(ByVal device As IntPtr, ByVal fenceCount As UInteger, ByRef pFences As IntPtr) As VkResult
    End Function

    <DllImport(VulkanLib, CallingConvention:=CallingConvention.StdCall)>
    Private Shared Sub vkDestroySurfaceKHR(ByVal instance As IntPtr, ByVal surface As IntPtr, ByVal pAllocator As IntPtr)
    End Sub

    <DllImport(VulkanLib, CallingConvention:=CallingConvention.StdCall)>
    Private Shared Function vkCreateImage(ByVal device As IntPtr, ByRef pCreateInfo As VkImageCreateInfo, ByVal pAllocator As IntPtr, ByRef pImage As IntPtr) As VkResult
    End Function

    <DllImport(VulkanLib, CallingConvention:=CallingConvention.StdCall)>
    Private Shared Sub vkDestroyImage(ByVal device As IntPtr, ByVal image As IntPtr, ByVal pAllocator As IntPtr)
    End Sub

    <DllImport(VulkanLib, CallingConvention:=CallingConvention.StdCall)>
    Private Shared Sub vkGetImageMemoryRequirements(ByVal device As IntPtr, ByVal image As IntPtr, ByRef pMemoryRequirements As VkMemoryRequirements)
    End Sub

    <DllImport(VulkanLib, CallingConvention:=CallingConvention.StdCall)>
    Private Shared Sub vkGetPhysicalDeviceMemoryProperties(ByVal physicalDevice As IntPtr, ByRef pMemoryProperties As VkPhysicalDeviceMemoryProperties)
    End Sub

    <DllImport(VulkanLib, CallingConvention:=CallingConvention.StdCall)>
    Private Shared Function vkAllocateMemory(ByVal device As IntPtr, ByRef pAllocateInfo As VkMemoryAllocateInfo, ByVal pAllocator As IntPtr, ByRef pMemory As IntPtr) As VkResult
    End Function

    <DllImport(VulkanLib, CallingConvention:=CallingConvention.StdCall)>
    Private Shared Sub vkFreeMemory(ByVal device As IntPtr, ByVal memory As IntPtr, ByVal pAllocator As IntPtr)
    End Sub

    <DllImport(VulkanLib, CallingConvention:=CallingConvention.StdCall)>
    Private Shared Function vkBindImageMemory(ByVal device As IntPtr, ByVal image As IntPtr, ByVal memory As IntPtr, ByVal memoryOffset As ULong) As VkResult
    End Function

    <DllImport(VulkanLib, CallingConvention:=CallingConvention.StdCall)>
    Private Shared Function vkGetPhysicalDeviceFormatProperties(ByVal physicalDevice As IntPtr, ByVal format As VkFormat, ByRef pFormatProperties As IntPtr) As VkResult
    End Function

    Delegate Function vkCreateWin32SurfaceKHRFunc(ByVal instance As IntPtr, ByRef pCreateInfo As VkWin32SurfaceCreateInfoKHR, ByVal pAllocator As IntPtr, ByRef pSurface As IntPtr) As VkResult
    Delegate Function vkCreateDebugUtilsMessengerEXTFunc(ByVal instance As IntPtr, ByRef pCreateInfo As VkDebugUtilsMessengerCreateInfoEXT, ByVal pAllocator As IntPtr, ByRef pMessenger As IntPtr) As VkResult
    Delegate Sub vkDestroyDebugUtilsMessengerEXTFunc(ByVal instance As IntPtr, ByVal messenger As IntPtr, ByVal pAllocator As IntPtr)

    Private instance As IntPtr
    Private physicalDevice As IntPtr
    Private device As IntPtr
    Private graphicsQueue As IntPtr
    Private presentQueue As IntPtr
    Private surface As IntPtr
    Private swapChain As IntPtr
    Private swapChainImages() As IntPtr
    Private swapChainImageViews() As IntPtr
    Private swapChainImageFormat As VkFormat
    Private swapChainExtent As VkExtent2D
    Private renderPass As IntPtr
    Private pipelineLayout As IntPtr
    Private graphicsPipeline As IntPtr
    Private swapChainFramebuffers() As IntPtr
    Private commandPool As IntPtr
    Private commandBuffer As IntPtr
    Private imageAvailableSemaphores() As IntPtr
    Private renderFinishedSemaphores() As IntPtr
    Private inFlightFences() As IntPtr
    Private currentFrame As Integer = 0
    Private frameIndex As Integer = 0
    Private Const MAX_FRAMES_IN_FLIGHT As Integer = 2
    Private debugMessenger As IntPtr
    Private vertShaderModule As IntPtr
    Private fragShaderModule As IntPtr
    Private depthImage As IntPtr
    Private depthImageMemory As IntPtr
    Private depthImageView As IntPtr

    Private debugCallbackDelegate As DebugCallback

    Public Sub New()
        Me.Text = "Vulkan Triangle (VB.NET)"
        Me.ClientSize = New Size(800, 600)
        Me.StartPosition = FormStartPosition.CenterScreen

        AddHandler Me.Load, AddressOf HandleLoad
        AddHandler Me.FormClosing, AddressOf HandleFormClosing
        AddHandler Me.Paint, AddressOf HandlePaint

        InitVulkan()
    End Sub

    Private Sub HandleLoad(ByVal sender As Object, ByVal e As EventArgs)
        Console.WriteLine("Form loaded")
    End Sub

    Private Sub HandleFormClosing(ByVal sender As Object, ByVal e As FormClosingEventArgs)
        Cleanup()
    End Sub

    Private Sub HandlePaint(ByVal sender As Object, ByVal e As PaintEventArgs)
        DrawFrame()
    End Sub

    Protected Overrides Sub OnPaintBackground(ByVal e As PaintEventArgs)
        ' Do nothing to prevent flickering
    End Sub

    ' --------------------------------------------------------------------------------------------------------
    ' Marshal-safe initializers for Vulkan "out" structs that contain managed arrays (ByValArray).
    ' These must be allocated before passing the struct ByRef into vkGet* functions.
    ' --------------------------------------------------------------------------------------------------------
    Private Shared Sub InitPhysicalDeviceProperties(ByRef props As VkPhysicalDeviceProperties)
        If props.pipelineCacheUUID Is Nothing OrElse props.pipelineCacheUUID.Length <> 16 Then
            props.pipelineCacheUUID = New Byte(15) {}
        End If
        InitPhysicalDeviceLimits(props.limits)
    End Sub

    Private Shared Sub InitPhysicalDeviceLimits(ByRef lim As VkPhysicalDeviceLimits)
        If lim.maxComputeWorkGroupCount Is Nothing OrElse lim.maxComputeWorkGroupCount.Length <> 3 Then
            lim.maxComputeWorkGroupCount = New UInteger(2) {}
        End If
        If lim.maxComputeWorkGroupSize Is Nothing OrElse lim.maxComputeWorkGroupSize.Length <> 3 Then
            lim.maxComputeWorkGroupSize = New UInteger(2) {}
        End If
        If lim.maxViewportDimensions Is Nothing OrElse lim.maxViewportDimensions.Length <> 2 Then
            lim.maxViewportDimensions = New UInteger(1) {}
        End If
        If lim.viewportBoundsRange Is Nothing OrElse lim.viewportBoundsRange.Length <> 2 Then
            lim.viewportBoundsRange = New Single(1) {}
        End If
        If lim.pointSizeRange Is Nothing OrElse lim.pointSizeRange.Length <> 2 Then
            lim.pointSizeRange = New Single(1) {}
        End If
        If lim.lineWidthRange Is Nothing OrElse lim.lineWidthRange.Length <> 2 Then
            lim.lineWidthRange = New Single(1) {}
        End If
    End Sub

    Private Shared Sub InitPhysicalDeviceMemoryProperties(ByRef memProps As VkPhysicalDeviceMemoryProperties)
        If memProps.memoryTypes Is Nothing OrElse memProps.memoryTypes.Length <> 32 Then
            memProps.memoryTypes = New VkMemoryType(31) {}
        End If
        If memProps.memoryHeaps Is Nothing OrElse memProps.memoryHeaps.Length <> 16 Then
            memProps.memoryHeaps = New VkMemoryHeap(15) {}
        End If
    End Sub



    Private Function DebugCallbackFunction(ByVal messageSeverity As VkDebugUtilsMessageSeverityFlagsEXT,
                                           ByVal messageTypes As VkDebugUtilsMessageTypeFlagsEXT,
                                           ByRef pCallbackData As VkDebugUtilsMessengerCallbackDataEXT,
                                           ByVal pUserData As IntPtr) As VkBool32
        Console.WriteLine($"[Validation Layer] {pCallbackData.pMessage}")
        Return VkBool32.False
    End Function

    Private Sub InitVulkan()
        Console.WriteLine("----------------------------------------")
        Console.WriteLine("[HelloForm::InitVulkan] - Start")

        CreateInstance()
        SetupDebugMessenger()
        CreateSurface()
        PickPhysicalDevice()
        CreateLogicalDevice()
        CreateSwapChain()
        CreateSwapChainImageViews()
        CreateDepthResources()
        CreateRenderPass()
        CreateGraphicsPipeline()
        CreateFramebuffers()
        CreateCommandPool()
        CreateCommandBuffer()
        CreateSyncObjects()

        Console.WriteLine("[HelloForm::InitVulkan] - End")
    End Sub

    Private Sub CreateInstance()
        Console.WriteLine("----------------------------------------")
        Console.WriteLine("[HelloForm::CreateInstance] - Start")

        Dim appInfo As New VkApplicationInfo With {
            .sType = VkStructureType.VK_STRUCTURE_TYPE_APPLICATION_INFO,
            .pApplicationName = "Vulkan App (VB.NET)",
            .applicationVersion = MakeVersion(1, 0, 0),
            .pEngineName = "No Engine",
            .engineVersion = MakeVersion(1, 0, 0),
            .apiVersion = MakeVersion(1, 4, 0)
        }

        Dim extensions() As String = {"VK_KHR_surface", "VK_KHR_win32_surface", "VK_EXT_debug_utils"}
        Dim extensionsPtr As IntPtr = StringArrayToPtr(extensions)

        Dim validationLayers() As String = {"VK_LAYER_KHRONOS_validation"}
        Dim layersPtr As IntPtr = StringArrayToPtr(validationLayers)

        ' VkApplicationInfo contains Strings (non-blittable), so don't pin it.
        ' Marshal it into unmanaged memory and pass that pointer.
        Dim appInfoPtr As IntPtr = Marshal.AllocHGlobal(Marshal.SizeOf(GetType(VkApplicationInfo)))
        Marshal.StructureToPtr(appInfo, appInfoPtr, False)

        Try
            Dim createInfo As New VkInstanceCreateInfo With {
                .sType = VkStructureType.VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
                .pApplicationInfo = appInfoPtr,
                .enabledExtensionCount = CUInt(extensions.Length),
                .ppEnabledExtensionNames = extensionsPtr,
                .enabledLayerCount = CUInt(validationLayers.Length),
                .ppEnabledLayerNames = layersPtr
            }

            If vkCreateInstance(createInfo, IntPtr.Zero, instance) <> VkResult.VK_SUCCESS Then
                Throw New Exception("Failed to create instance!")
            End If
        Finally
            Marshal.DestroyStructure(appInfoPtr, GetType(VkApplicationInfo))
            Marshal.FreeHGlobal(appInfoPtr)
            FreeStringArray(extensionsPtr, extensions.Length)
            FreeStringArray(layersPtr, validationLayers.Length)
        End Try

        Console.WriteLine($"Instance: {instance}")
        Console.WriteLine("[HelloForm::CreateInstance] - End")
    End Sub

    Private Sub SetupDebugMessenger()
        debugCallbackDelegate = AddressOf DebugCallbackFunction

        Dim createInfo As New VkDebugUtilsMessengerCreateInfoEXT With {
            .sType = VkStructureType.VK_STRUCTURE_TYPE_DEBUG_UTILS_MESSENGER_CREATE_INFO_EXT,
            .messageSeverity = VkDebugUtilsMessageSeverityFlagsEXT.VK_DEBUG_UTILS_MESSAGE_SEVERITY_VERBOSE_BIT_EXT Or
                               VkDebugUtilsMessageSeverityFlagsEXT.VK_DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT Or
                               VkDebugUtilsMessageSeverityFlagsEXT.VK_DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT,
            .messageType = VkDebugUtilsMessageTypeFlagsEXT.VK_DEBUG_UTILS_MESSAGE_TYPE_GENERAL_BIT_EXT Or
                           VkDebugUtilsMessageTypeFlagsEXT.VK_DEBUG_UTILS_MESSAGE_TYPE_VALIDATION_BIT_EXT Or
                           VkDebugUtilsMessageTypeFlagsEXT.VK_DEBUG_UTILS_MESSAGE_TYPE_PERFORMANCE_BIT_EXT,
            .pfnUserCallback = Marshal.GetFunctionPointerForDelegate(debugCallbackDelegate)
        }

        Dim vkCreateDebugUtilsMessengerEXTPtr As IntPtr = vkGetInstanceProcAddr(instance, "vkCreateDebugUtilsMessengerEXT")
        If vkCreateDebugUtilsMessengerEXTPtr <> IntPtr.Zero Then
            Dim vkCreateDebugUtilsMessengerEXT As vkCreateDebugUtilsMessengerEXTFunc = 
                CType(Marshal.GetDelegateForFunctionPointer(vkCreateDebugUtilsMessengerEXTPtr, GetType(vkCreateDebugUtilsMessengerEXTFunc)), vkCreateDebugUtilsMessengerEXTFunc)
            vkCreateDebugUtilsMessengerEXT(instance, createInfo, IntPtr.Zero, debugMessenger)
        End If
    End Sub

    Private Sub CreateSurface()
        Console.WriteLine("----------------------------------------")
        Console.WriteLine("[HelloForm::CreateSurface] - Start")

        Dim createInfo As New VkWin32SurfaceCreateInfoKHR With {
            .sType = VkStructureType.VK_STRUCTURE_TYPE_WIN32_SURFACE_CREATE_INFO_KHR,
            .hinstance = GetModuleHandle(Nothing),
            .hwnd = Me.Handle
        }

        Dim vkCreateWin32SurfaceKHRPtr As IntPtr = vkGetInstanceProcAddr(instance, "vkCreateWin32SurfaceKHR")
        Dim vkCreateWin32SurfaceKHR As vkCreateWin32SurfaceKHRFunc = 
            CType(Marshal.GetDelegateForFunctionPointer(vkCreateWin32SurfaceKHRPtr, GetType(vkCreateWin32SurfaceKHRFunc)), vkCreateWin32SurfaceKHRFunc)

        If vkCreateWin32SurfaceKHR(instance, createInfo, IntPtr.Zero, surface) <> VkResult.VK_SUCCESS Then
            Throw New Exception("Failed to create window surface!")
        End If

        Console.WriteLine($"Surface: {surface}")
        Console.WriteLine("[HelloForm::CreateSurface] - End")
    End Sub

    Private Sub PickPhysicalDevice()
        Console.WriteLine("----------------------------------------")
        Console.WriteLine("[HelloForm::PickPhysicalDevice] - Start")

        Dim deviceCount As UInteger = 0
        vkEnumeratePhysicalDevices(instance, deviceCount, IntPtr.Zero)

        If deviceCount = 0 Then
            Throw New Exception("Failed to find GPUs with Vulkan support!")
        End If

        Dim devices(deviceCount - 1) As IntPtr
        Dim devicesHandle As GCHandle = GCHandle.Alloc(devices, GCHandleType.Pinned)

        Try
            vkEnumeratePhysicalDevices(instance, deviceCount, devicesHandle.AddrOfPinnedObject())
            physicalDevice = devices(0)

            Dim props As New VkPhysicalDeviceProperties()
            InitPhysicalDeviceProperties(props)
            vkGetPhysicalDeviceProperties(physicalDevice, props)
            Console.WriteLine($"Selected GPU: {props.deviceName}")
        Finally
            devicesHandle.Free()
        End Try

        Console.WriteLine($"PhysicalDevice: {physicalDevice}")
        Console.WriteLine("[HelloForm::PickPhysicalDevice] - End")
    End Sub

    Private Sub CreateLogicalDevice()
        Console.WriteLine("----------------------------------------")
        Console.WriteLine("[HelloForm::CreateLogicalDevice] - Start")

        Dim queueFamilyIndex As UInteger = FindQueueFamily()

        Dim queuePriority As Single = 1.0F
        Dim priorityHandle As GCHandle = GCHandle.Alloc(queuePriority, GCHandleType.Pinned)

        Dim queueCreateInfo As New VkDeviceQueueCreateInfo With {
            .sType = VkStructureType.VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
            .queueFamilyIndex = queueFamilyIndex,
            .queueCount = 1,
            .pQueuePriorities = priorityHandle.AddrOfPinnedObject()
        }

        Dim queueCreateInfoHandle As GCHandle = GCHandle.Alloc(queueCreateInfo, GCHandleType.Pinned)

        Dim deviceFeatures As New VkPhysicalDeviceFeatures
        Dim deviceFeaturesHandle As GCHandle = GCHandle.Alloc(deviceFeatures, GCHandleType.Pinned)

        Dim deviceExtensions() As String = {"VK_KHR_swapchain"}
        Dim extensionsPtr As IntPtr = StringArrayToPtr(deviceExtensions)

        Try
            Dim createInfo As New VkDeviceCreateInfo With {
                .sType = VkStructureType.VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO,
                .pQueueCreateInfos = queueCreateInfoHandle.AddrOfPinnedObject(),
                .queueCreateInfoCount = 1,
                .pEnabledFeatures = deviceFeaturesHandle.AddrOfPinnedObject(),
                .enabledExtensionCount = CUInt(deviceExtensions.Length),
                .ppEnabledExtensionNames = extensionsPtr,
                .enabledLayerCount = 0
            }

            If vkCreateDevice(physicalDevice, createInfo, IntPtr.Zero, device) <> VkResult.VK_SUCCESS Then
                Throw New Exception("Failed to create logical device!")
            End If

            vkGetDeviceQueue(device, queueFamilyIndex, 0, graphicsQueue)
            vkGetDeviceQueue(device, queueFamilyIndex, 0, presentQueue)
        Finally
            priorityHandle.Free()
            queueCreateInfoHandle.Free()
            deviceFeaturesHandle.Free()
            FreeStringArray(extensionsPtr, deviceExtensions.Length)
        End Try

        Console.WriteLine($"Device: {device}")
        Console.WriteLine($"GraphicsQueue: {graphicsQueue}")
        Console.WriteLine($"PresentQueue: {presentQueue}")
        Console.WriteLine("[HelloForm::CreateLogicalDevice] - End")
    End Sub

    Private Function FindQueueFamily() As UInteger
        Dim queueFamilyCount As UInteger = 0
        vkGetPhysicalDeviceQueueFamilyProperties(physicalDevice, queueFamilyCount, IntPtr.Zero)

        Dim queueFamilies(queueFamilyCount - 1) As VkQueueFamilyProperties
        Dim queueFamiliesHandle As GCHandle = GCHandle.Alloc(queueFamilies, GCHandleType.Pinned)

        Try
            vkGetPhysicalDeviceQueueFamilyProperties(physicalDevice, queueFamilyCount, queueFamiliesHandle.AddrOfPinnedObject())

            For i As UInteger = 0 To queueFamilyCount - 1
                If (queueFamilies(i).queueFlags And &H1UI) <> 0 Then ' VK_QUEUE_GRAPHICS_BIT
                    Dim presentSupport As VkBool32 = VkBool32.False
                    vkGetPhysicalDeviceSurfaceSupportKHR(physicalDevice, i, surface, presentSupport)
                    If presentSupport = VkBool32.True Then
                        Return i
                    End If
                End If
            Next
        Finally
            queueFamiliesHandle.Free()
        End Try

        Throw New Exception("Failed to find suitable queue family!")
    End Function

    Private Sub CreateSwapChain()
        Console.WriteLine("----------------------------------------")
        Console.WriteLine("[HelloForm::CreateSwapChain] - Start")

        Dim surfaceCapabilities As VkSurfaceCapabilitiesKHR
        vkGetPhysicalDeviceSurfaceCapabilitiesKHR(physicalDevice, surface, surfaceCapabilities)

        Dim formatCount As UInteger = 0
        vkGetPhysicalDeviceSurfaceFormatsKHR(physicalDevice, surface, formatCount, IntPtr.Zero)
        Dim formats(formatCount - 1) As VkSurfaceFormatKHR
        Dim formatsHandle As GCHandle = GCHandle.Alloc(formats, GCHandleType.Pinned)
        vkGetPhysicalDeviceSurfaceFormatsKHR(physicalDevice, surface, formatCount, formatsHandle.AddrOfPinnedObject())
        formatsHandle.Free()

        swapChainImageFormat = formats(0).format
        swapChainExtent = surfaceCapabilities.currentExtent

        Dim imageCount As UInteger = surfaceCapabilities.minImageCount + 1
        If surfaceCapabilities.maxImageCount > 0 AndAlso imageCount > surfaceCapabilities.maxImageCount Then
            imageCount = surfaceCapabilities.maxImageCount
        End If

        Dim createInfo As New VkSwapchainCreateInfoKHR With {
            .sType = VkStructureType.VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR,
            .surface = surface,
            .minImageCount = imageCount,
            .imageFormat = swapChainImageFormat,
            .imageColorSpace = formats(0).colorSpace,
            .imageExtent = swapChainExtent,
            .imageArrayLayers = 1,
            .imageUsage = VkImageUsageFlags.VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT,
            .imageSharingMode = VkSharingMode.VK_SHARING_MODE_EXCLUSIVE,
            .preTransform = surfaceCapabilities.currentTransform,
            .compositeAlpha = VkCompositeAlphaFlagsKHR.VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR,
            .presentMode = VkPresentModeKHR.VK_PRESENT_MODE_FIFO_KHR,
            .clipped = VkBool32.True,
            .oldSwapchain = IntPtr.Zero
        }

        If vkCreateSwapchainKHR(device, createInfo, IntPtr.Zero, swapChain) <> VkResult.VK_SUCCESS Then
            Throw New Exception("Failed to create swap chain!")
        End If

        Dim swapChainImageCount As UInteger = 0
        vkGetSwapchainImagesKHR(device, swapChain, swapChainImageCount, IntPtr.Zero)
        ReDim swapChainImages(swapChainImageCount - 1)
        Dim imagesHandle As GCHandle = GCHandle.Alloc(swapChainImages, GCHandleType.Pinned)
        vkGetSwapchainImagesKHR(device, swapChain, swapChainImageCount, imagesHandle.AddrOfPinnedObject())
        imagesHandle.Free()

        Console.WriteLine($"SwapChain: {swapChain}")
        Console.WriteLine($"SwapChain Image Count: {swapChainImageCount}")
        Console.WriteLine("[HelloForm::CreateSwapChain] - End")
    End Sub

    Private Sub CreateSwapChainImageViews()
        Console.WriteLine("----------------------------------------")
        Console.WriteLine("[HelloForm::CreateSwapChainImageViews] - Start")

        ReDim swapChainImageViews(swapChainImages.Length - 1)

        For i As Integer = 0 To swapChainImages.Length - 1
            Dim createInfo As New VkImageViewCreateInfo With {
                .sType = VkStructureType.VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO,
                .image = swapChainImages(i),
                .viewType = VkImageViewType.VK_IMAGE_VIEW_TYPE_2D,
                .format = swapChainImageFormat,
                .components = New VkComponentMapping With {
                    .r = VkComponentSwizzle.VK_COMPONENT_SWIZZLE_IDENTITY,
                    .g = VkComponentSwizzle.VK_COMPONENT_SWIZZLE_IDENTITY,
                    .b = VkComponentSwizzle.VK_COMPONENT_SWIZZLE_IDENTITY,
                    .a = VkComponentSwizzle.VK_COMPONENT_SWIZZLE_IDENTITY
                },
                .subresourceRange = New VkImageSubresourceRange With {
                    .aspectMask = VkImageAspectFlags.VK_IMAGE_ASPECT_COLOR_BIT,
                    .baseMipLevel = 0,
                    .levelCount = 1,
                    .baseArrayLayer = 0,
                    .layerCount = 1
                }
            }

            If vkCreateImageView(device, createInfo, IntPtr.Zero, swapChainImageViews(i)) <> VkResult.VK_SUCCESS Then
                Throw New Exception("Failed to create image views!")
            End If
        Next

        Console.WriteLine("[HelloForm::CreateSwapChainImageViews] - End")
    End Sub

    Private Sub CreateDepthResources()
        Dim depthFormat As VkFormat = VkFormat.VK_FORMAT_D32_SFLOAT

        Dim imageInfo As New VkImageCreateInfo With {
            .sType = VkStructureType.VK_STRUCTURE_TYPE_IMAGE_CREATE_INFO,
            .imageType = 1, ' VK_IMAGE_TYPE_2D
            .extent = New VkExtent3D With {.width = swapChainExtent.width, .height = swapChainExtent.height, .depth = 1},
            .mipLevels = 1,
            .arrayLayers = 1,
            .format = depthFormat,
            .tiling = VkImageTiling.VK_IMAGE_TILING_OPTIMAL,
            .initialLayout = VkImageLayout.VK_IMAGE_LAYOUT_UNDEFINED,
            .usage = VkImageUsageFlags.VK_IMAGE_USAGE_DEPTH_STENCIL_ATTACHMENT_BIT,
            .samples = VkSampleCountFlags.VK_SAMPLE_COUNT_1_BIT,
            .sharingMode = VkSharingMode.VK_SHARING_MODE_EXCLUSIVE
        }

        If vkCreateImage(device, imageInfo, IntPtr.Zero, depthImage) <> VkResult.VK_SUCCESS Then
            Throw New Exception("Failed to create depth image!")
        End If

        Dim memRequirements As VkMemoryRequirements
        vkGetImageMemoryRequirements(device, depthImage, memRequirements)

        Dim memProperties As New VkPhysicalDeviceMemoryProperties()
        InitPhysicalDeviceMemoryProperties(memProperties)
        vkGetPhysicalDeviceMemoryProperties(physicalDevice, memProperties)

        Dim memoryTypeIndex As UInteger = FindMemoryType(memRequirements.memoryTypeBits, VkMemoryPropertyFlags.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT, memProperties)

        Dim allocInfo As New VkMemoryAllocateInfo With {
            .sType = VkStructureType.VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
            .allocationSize = memRequirements.size,
            .memoryTypeIndex = memoryTypeIndex
        }

        If vkAllocateMemory(device, allocInfo, IntPtr.Zero, depthImageMemory) <> VkResult.VK_SUCCESS Then
            Throw New Exception("Failed to allocate depth image memory!")
        End If

        vkBindImageMemory(device, depthImage, depthImageMemory, 0)

        Dim viewInfo As New VkImageViewCreateInfo With {
            .sType = VkStructureType.VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO,
            .image = depthImage,
            .viewType = VkImageViewType.VK_IMAGE_VIEW_TYPE_2D,
            .format = depthFormat,
            .subresourceRange = New VkImageSubresourceRange With {
                .aspectMask = VkImageAspectFlags.VK_IMAGE_ASPECT_DEPTH_BIT,
                .baseMipLevel = 0,
                .levelCount = 1,
                .baseArrayLayer = 0,
                .layerCount = 1
            }
        }

        If vkCreateImageView(device, viewInfo, IntPtr.Zero, depthImageView) <> VkResult.VK_SUCCESS Then
            Throw New Exception("Failed to create depth image view!")
        End If
    End Sub

    Private Function FindMemoryType(ByVal typeFilter As UInteger, ByVal properties As VkMemoryPropertyFlags, ByRef memProperties As VkPhysicalDeviceMemoryProperties) As UInteger
        For i As UInteger = 0 To memProperties.memoryTypeCount - 1
            If (typeFilter And (1UI << CInt(i))) <> 0 AndAlso (memProperties.memoryTypes(i).propertyFlags And properties) = properties Then
                Return i
            End If
        Next
        Throw New Exception("Failed to find suitable memory type!")
    End Function

    Private Sub CreateRenderPass()
        Console.WriteLine("----------------------------------------")
        Console.WriteLine("[HelloForm::CreateRenderPass] - Start")

        Dim colorAttachment As New VkAttachmentDescription With {
            .format = swapChainImageFormat,
            .samples = VkSampleCountFlags.VK_SAMPLE_COUNT_1_BIT,
            .loadOp = VkAttachmentLoadOp.VK_ATTACHMENT_LOAD_OP_CLEAR,
            .storeOp = VkAttachmentStoreOp.VK_ATTACHMENT_STORE_OP_STORE,
            .stencilLoadOp = VkAttachmentLoadOp.VK_ATTACHMENT_LOAD_OP_DONT_CARE,
            .stencilStoreOp = VkAttachmentStoreOp.VK_ATTACHMENT_STORE_OP_DONT_CARE,
            .initialLayout = VkImageLayout.VK_IMAGE_LAYOUT_UNDEFINED,
            .finalLayout = VkImageLayout.VK_IMAGE_LAYOUT_PRESENT_SRC_KHR
        }

        Dim depthAttachment As New VkAttachmentDescription With {
            .format = VkFormat.VK_FORMAT_D32_SFLOAT,
            .samples = VkSampleCountFlags.VK_SAMPLE_COUNT_1_BIT,
            .loadOp = VkAttachmentLoadOp.VK_ATTACHMENT_LOAD_OP_CLEAR,
            .storeOp = VkAttachmentStoreOp.VK_ATTACHMENT_STORE_OP_DONT_CARE,
            .stencilLoadOp = VkAttachmentLoadOp.VK_ATTACHMENT_LOAD_OP_DONT_CARE,
            .stencilStoreOp = VkAttachmentStoreOp.VK_ATTACHMENT_STORE_OP_DONT_CARE,
            .initialLayout = VkImageLayout.VK_IMAGE_LAYOUT_UNDEFINED,
            .finalLayout = VkImageLayout.VK_IMAGE_LAYOUT_DEPTH_STENCIL_ATTACHMENT_OPTIMAL
        }

        Dim colorAttachmentRef As New VkAttachmentReference With {
            .attachment = 0,
            .layout = VkImageLayout.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL
        }

        Dim depthAttachmentRef As New VkAttachmentReference With {
            .attachment = 1,
            .layout = VkImageLayout.VK_IMAGE_LAYOUT_DEPTH_STENCIL_ATTACHMENT_OPTIMAL
        }

        Dim colorAttachmentRefHandle As GCHandle = GCHandle.Alloc(colorAttachmentRef, GCHandleType.Pinned)
        Dim depthAttachmentRefHandle As GCHandle = GCHandle.Alloc(depthAttachmentRef, GCHandleType.Pinned)

        Dim subpass As New VkSubpassDescription With {
            .pipelineBindPoint = VkPipelineBindPoint.VK_PIPELINE_BIND_POINT_GRAPHICS,
            .colorAttachmentCount = 1,
            .pColorAttachments = colorAttachmentRefHandle.AddrOfPinnedObject(),
            .pDepthStencilAttachment = depthAttachmentRefHandle.AddrOfPinnedObject()
        }

        Dim dependency As New VkSubpassDependency With {
            .srcSubpass = &HFFFFFFFFUI, ' VK_SUBPASS_EXTERNAL
            .dstSubpass = 0,
            .srcStageMask = VkPipelineStageFlags.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT Or VkPipelineStageFlags.VK_PIPELINE_STAGE_EARLY_FRAGMENT_TESTS_BIT,
            .srcAccessMask = 0,
            .dstStageMask = VkPipelineStageFlags.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT Or VkPipelineStageFlags.VK_PIPELINE_STAGE_EARLY_FRAGMENT_TESTS_BIT,
            .dstAccessMask = &H100UI Or &H400UI ' VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT | VK_ACCESS_DEPTH_STENCIL_ATTACHMENT_WRITE_BIT
        }

        Dim attachments() As VkAttachmentDescription = {colorAttachment, depthAttachment}
        Dim attachmentsHandle As GCHandle = GCHandle.Alloc(attachments, GCHandleType.Pinned)
        Dim subpassHandle As GCHandle = GCHandle.Alloc(subpass, GCHandleType.Pinned)
        Dim dependencyHandle As GCHandle = GCHandle.Alloc(dependency, GCHandleType.Pinned)

        Try
            Dim renderPassInfo As New VkRenderPassCreateInfo With {
                .sType = VkStructureType.VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO,
                .attachmentCount = CUInt(attachments.Length),
                .pAttachments = attachmentsHandle.AddrOfPinnedObject(),
                .subpassCount = 1,
                .pSubpasses = subpassHandle.AddrOfPinnedObject(),
                .dependencyCount = 1,
                .pDependencies = dependencyHandle.AddrOfPinnedObject()
            }

            If vkCreateRenderPass(device, renderPassInfo, IntPtr.Zero, renderPass) <> VkResult.VK_SUCCESS Then
                Throw New Exception("Failed to create render pass!")
            End If
        Finally
            colorAttachmentRefHandle.Free()
            depthAttachmentRefHandle.Free()
            attachmentsHandle.Free()
            subpassHandle.Free()
            dependencyHandle.Free()
        End Try

        Console.WriteLine($"RenderPass: {renderPass}")
        Console.WriteLine("[HelloForm::CreateRenderPass] - End")
    End Sub

    Private Sub CreateGraphicsPipeline()
        Console.WriteLine("----------------------------------------")
        Console.WriteLine("[HelloForm::CreateGraphicsPipeline] - Start")

        Dim vertShaderCode As String = File.ReadAllText("hello.vert")
        Dim fragShaderCode As String = File.ReadAllText("hello.frag")

        Dim vertSpirv As Byte() = ShaderCompiler.Compile(vertShaderCode, ShaderCompiler.ShaderKind.Vertex, "hello.vert")
        Dim fragSpirv As Byte() = ShaderCompiler.Compile(fragShaderCode, ShaderCompiler.ShaderKind.Fragment, "hello.frag")

        vertShaderModule = CreateShaderModule(vertSpirv)
        fragShaderModule = CreateShaderModule(fragSpirv)

        Dim vertShaderNamePtr As IntPtr = Marshal.StringToHGlobalAnsi("main")
        Dim fragShaderNamePtr As IntPtr = Marshal.StringToHGlobalAnsi("main")

        Dim vertShaderStageInfo As New VkPipelineShaderStageCreateInfo With {
            .sType = VkStructureType.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
            .stage = VkShaderStageFlags.VK_SHADER_STAGE_VERTEX_BIT,
            .[module] = vertShaderModule,
            .pName = vertShaderNamePtr
        }

        Dim fragShaderStageInfo As New VkPipelineShaderStageCreateInfo With {
            .sType = VkStructureType.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
            .stage = VkShaderStageFlags.VK_SHADER_STAGE_FRAGMENT_BIT,
            .[module] = fragShaderModule,
            .pName = fragShaderNamePtr
        }

        Dim shaderStages() As VkPipelineShaderStageCreateInfo = {vertShaderStageInfo, fragShaderStageInfo}

        Dim vertexInputInfo As New VkPipelineVertexInputStateCreateInfo With {
            .sType = VkStructureType.VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO,
            .vertexBindingDescriptionCount = 0,
            .vertexAttributeDescriptionCount = 0
        }

        Dim inputAssembly As New VkPipelineInputAssemblyStateCreateInfo With {
            .sType = VkStructureType.VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO,
            .topology = VkPrimitiveTopology.VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST,
            .primitiveRestartEnable = VkBool32.False
        }

        Dim viewport As New VkViewport With {
            .x = 0.0F,
            .y = 0.0F,
            .width = CSng(swapChainExtent.width),
            .height = CSng(swapChainExtent.height),
            .minDepth = 0.0F,
            .maxDepth = 1.0F
        }

        Dim scissor As New VkRect2D With {
            .offset = New VkOffset2D With {.x = 0, .y = 0},
            .extent = swapChainExtent
        }

        Dim viewportHandle As GCHandle = GCHandle.Alloc(viewport, GCHandleType.Pinned)
        Dim scissorHandle As GCHandle = GCHandle.Alloc(scissor, GCHandleType.Pinned)

        Dim viewportState As New VkPipelineViewportStateCreateInfo With {
            .sType = VkStructureType.VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO,
            .viewportCount = 1,
            .pViewports = viewportHandle.AddrOfPinnedObject(),
            .scissorCount = 1,
            .pScissors = scissorHandle.AddrOfPinnedObject()
        }

        Dim rasterizer As New VkPipelineRasterizationStateCreateInfo With {
            .sType = VkStructureType.VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO,
            .depthClampEnable = VkBool32.False,
            .rasterizerDiscardEnable = VkBool32.False,
            .polygonMode = VkPolygonMode.VK_POLYGON_MODE_FILL,
            .lineWidth = 1.0F,
            .cullMode = VkCullModeFlags.VK_CULL_MODE_BACK_BIT,
            .frontFace = VkFrontFace.VK_FRONT_FACE_CLOCKWISE,
            .depthBiasEnable = VkBool32.False
        }

        Dim multisampling As New VkPipelineMultisampleStateCreateInfo With {
            .sType = VkStructureType.VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO,
            .sampleShadingEnable = VkBool32.False,
            .rasterizationSamples = VkSampleCountFlags.VK_SAMPLE_COUNT_1_BIT
        }

        Dim depthStencil As New VkPipelineDepthStencilStateCreateInfo With {
            .sType = VkStructureType.VK_STRUCTURE_TYPE_PIPELINE_DEPTH_STENCIL_STATE_CREATE_INFO,
            .depthTestEnable = VkBool32.True,
            .depthWriteEnable = VkBool32.True,
            .depthCompareOp = VkCompareOp.VK_COMPARE_OP_LESS,
            .depthBoundsTestEnable = VkBool32.False,
            .stencilTestEnable = VkBool32.False
        }

        Dim colorBlendAttachment As New VkPipelineColorBlendAttachmentState With {
            .colorWriteMask = VkColorComponentFlags.VK_COLOR_COMPONENT_R_BIT Or
                              VkColorComponentFlags.VK_COLOR_COMPONENT_G_BIT Or
                              VkColorComponentFlags.VK_COLOR_COMPONENT_B_BIT Or
                              VkColorComponentFlags.VK_COLOR_COMPONENT_A_BIT,
            .blendEnable = VkBool32.False
        }

        Dim colorBlendAttachmentHandle As GCHandle = GCHandle.Alloc(colorBlendAttachment, GCHandleType.Pinned)

        Dim colorBlending As New VkPipelineColorBlendStateCreateInfo With {
            .sType = VkStructureType.VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO,
            .logicOpEnable = VkBool32.False,
            .logicOp = 0,
            .attachmentCount = 1,
            .pAttachments = colorBlendAttachmentHandle.AddrOfPinnedObject()
        }
        colorBlending.blendConstants = New Single() {0.0F, 0.0F, 0.0F, 0.0F}

        Dim colorBlendingPtr As IntPtr = Marshal.AllocHGlobal(Marshal.SizeOf(GetType(VkPipelineColorBlendStateCreateInfo)))
        Marshal.StructureToPtr(colorBlending, colorBlendingPtr, False)

        Dim pipelineLayoutInfo As New VkPipelineLayoutCreateInfo With {
            .sType = VkStructureType.VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO,
            .setLayoutCount = 0,
            .pushConstantRangeCount = 0
        }

        If vkCreatePipelineLayout(device, pipelineLayoutInfo, IntPtr.Zero, pipelineLayout) <> VkResult.VK_SUCCESS Then
            Throw New Exception("Failed to create pipeline layout!")
        End If

        Dim shaderStagesHandle As GCHandle = GCHandle.Alloc(shaderStages, GCHandleType.Pinned)
        Dim vertexInputInfoHandle As GCHandle = GCHandle.Alloc(vertexInputInfo, GCHandleType.Pinned)
        Dim inputAssemblyHandle As GCHandle = GCHandle.Alloc(inputAssembly, GCHandleType.Pinned)
        Dim viewportStateHandle As GCHandle = GCHandle.Alloc(viewportState, GCHandleType.Pinned)
        Dim rasterizerHandle As GCHandle = GCHandle.Alloc(rasterizer, GCHandleType.Pinned)
        Dim multisamplingHandle As GCHandle = GCHandle.Alloc(multisampling, GCHandleType.Pinned)
        Dim depthStencilHandle As GCHandle = GCHandle.Alloc(depthStencil, GCHandleType.Pinned)
        Try
            Dim pipelineInfo As New VkGraphicsPipelineCreateInfo With {
                .sType = VkStructureType.VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO,
                .stageCount = 2,
                .pStages = shaderStagesHandle.AddrOfPinnedObject(),
                .pVertexInputState = vertexInputInfoHandle.AddrOfPinnedObject(),
                .pInputAssemblyState = inputAssemblyHandle.AddrOfPinnedObject(),
                .pViewportState = viewportStateHandle.AddrOfPinnedObject(),
                .pRasterizationState = rasterizerHandle.AddrOfPinnedObject(),
                .pMultisampleState = multisamplingHandle.AddrOfPinnedObject(),
                .pDepthStencilState = depthStencilHandle.AddrOfPinnedObject(),
                .pColorBlendState = colorBlendingPtr,
                .layout = pipelineLayout,
                .renderPass = renderPass,
                .subpass = 0,
                .basePipelineHandle = IntPtr.Zero
            }

            Dim pipelineInfoHandle As GCHandle = GCHandle.Alloc(pipelineInfo, GCHandleType.Pinned)
            Dim pipelinesHandle As GCHandle = GCHandle.Alloc(graphicsPipeline, GCHandleType.Pinned)

            Try
                If vkCreateGraphicsPipelines(device, IntPtr.Zero, 1, pipelineInfoHandle.AddrOfPinnedObject(), IntPtr.Zero, pipelinesHandle.AddrOfPinnedObject()) <> VkResult.VK_SUCCESS Then
                    Throw New Exception("Failed to create graphics pipeline!")
                End If
                graphicsPipeline = CType(pipelinesHandle.Target, IntPtr)
            Finally
                pipelineInfoHandle.Free()
                pipelinesHandle.Free()
            End Try
        Finally
            viewportHandle.Free()
            scissorHandle.Free()
            colorBlendAttachmentHandle.Free()
            shaderStagesHandle.Free()
            vertexInputInfoHandle.Free()
            inputAssemblyHandle.Free()
            viewportStateHandle.Free()
            rasterizerHandle.Free()
            multisamplingHandle.Free()
            depthStencilHandle.Free()
            Marshal.FreeHGlobal(colorBlendingPtr)
            If vertShaderNamePtr <> IntPtr.Zero Then Marshal.FreeHGlobal(vertShaderNamePtr)
            If fragShaderNamePtr <> IntPtr.Zero Then Marshal.FreeHGlobal(fragShaderNamePtr)
        End Try

        Console.WriteLine($"GraphicsPipeline: {graphicsPipeline}")
        Console.WriteLine("[HelloForm::CreateGraphicsPipeline] - End")
    End Sub

    Private Function CreateShaderModule(ByVal code As Byte()) As IntPtr
        Dim codeHandle As GCHandle = GCHandle.Alloc(code, GCHandleType.Pinned)

        Try
            Dim createInfo As New VkShaderModuleCreateInfo With {
                .sType = VkStructureType.VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO,
                .codeSize = CType(code.Length, UIntPtr),
                .pCode = codeHandle.AddrOfPinnedObject()
            }

            Dim shaderModule As IntPtr
            If vkCreateShaderModule(device, createInfo, IntPtr.Zero, shaderModule) <> VkResult.VK_SUCCESS Then
                Throw New Exception("Failed to create shader module!")
            End If

            Return shaderModule
        Finally
            codeHandle.Free()
        End Try
    End Function

    Private Sub CreateFramebuffers()
        Console.WriteLine("----------------------------------------")
        Console.WriteLine("[HelloForm::CreateFramebuffers] - Start")

        ReDim swapChainFramebuffers(swapChainImageViews.Length - 1)

        For i As Integer = 0 To swapChainImageViews.Length - 1
            Dim attachments() As IntPtr = {swapChainImageViews(i), depthImageView}
            Dim attachmentsHandle As GCHandle = GCHandle.Alloc(attachments, GCHandleType.Pinned)

            Try
                Dim framebufferInfo As New VkFramebufferCreateInfo With {
                    .sType = VkStructureType.VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO,
                    .renderPass = renderPass,
                    .attachmentCount = CUInt(attachments.Length),
                    .pAttachments = attachmentsHandle.AddrOfPinnedObject(),
                    .width = swapChainExtent.width,
                    .height = swapChainExtent.height,
                    .layers = 1
                }

                If vkCreateFramebuffer(device, framebufferInfo, IntPtr.Zero, swapChainFramebuffers(i)) <> VkResult.VK_SUCCESS Then
                    Throw New Exception("Failed to create framebuffer!")
                End If
            Finally
                attachmentsHandle.Free()
            End Try
        Next

        Console.WriteLine("[HelloForm::CreateFramebuffers] - End")
    End Sub

    Private Sub CreateCommandPool()
        Console.WriteLine("----------------------------------------")
        Console.WriteLine("[HelloForm::CreateCommandPool] - Start")

        Dim queueFamilyIndex As UInteger = FindQueueFamily()

        Dim poolInfo As New VkCommandPoolCreateInfo With {
            .sType = VkStructureType.VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO,
            .flags = VkCommandPoolCreateFlags.VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT,
            .queueFamilyIndex = queueFamilyIndex
        }

        If vkCreateCommandPool(device, poolInfo, IntPtr.Zero, commandPool) <> VkResult.VK_SUCCESS Then
            Throw New Exception("Failed to create command pool!")
        End If

        Console.WriteLine($"CommandPool: {commandPool}")
        Console.WriteLine("[HelloForm::CreateCommandPool] - End")
    End Sub

    Private Sub CreateCommandBuffer()
        Console.WriteLine("----------------------------------------")
        Console.WriteLine("[HelloForm::CreateCommandBuffer] - Start")

        Dim allocInfo As New VkCommandBufferAllocateInfo With {
            .sType = VkStructureType.VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
            .commandPool = commandPool,
            .level = VkCommandBufferLevel.VK_COMMAND_BUFFER_LEVEL_PRIMARY,
            .commandBufferCount = 1
        }

        Dim commandBuffersHandle As GCHandle = GCHandle.Alloc(commandBuffer, GCHandleType.Pinned)

        Try
            If vkAllocateCommandBuffers(device, allocInfo, commandBuffersHandle.AddrOfPinnedObject()) <> VkResult.VK_SUCCESS Then
                Throw New Exception("Failed to allocate command buffers!")
            End If
            commandBuffer = CType(commandBuffersHandle.Target, IntPtr)
        Finally
            commandBuffersHandle.Free()
        End Try

        Console.WriteLine($"CommandBuffer: {commandBuffer}")
        Console.WriteLine("[HelloForm::CreateCommandBuffer] - End")
    End Sub

    Private Sub CreateSyncObjects()
        Console.WriteLine("----------------------------------------")
        Console.WriteLine("[HelloForm::CreateSyncObjects] - Start")

        ReDim imageAvailableSemaphores(MAX_FRAMES_IN_FLIGHT - 1)
        ReDim renderFinishedSemaphores(MAX_FRAMES_IN_FLIGHT - 1)
        ReDim inFlightFences(MAX_FRAMES_IN_FLIGHT - 1)

        Dim semaphoreInfo As New VkSemaphoreCreateInfo With {
            .sType = VkStructureType.VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO
        }

        Dim fenceInfo As New VkFenceCreateInfo With {
            .sType = VkStructureType.VK_STRUCTURE_TYPE_FENCE_CREATE_INFO,
            .flags = 1 ' VK_FENCE_CREATE_SIGNALED_BIT
        }

        For i As Integer = 0 To MAX_FRAMES_IN_FLIGHT - 1
            If vkCreateSemaphore(device, semaphoreInfo, IntPtr.Zero, imageAvailableSemaphores(i)) <> VkResult.VK_SUCCESS OrElse
               vkCreateSemaphore(device, semaphoreInfo, IntPtr.Zero, renderFinishedSemaphores(i)) <> VkResult.VK_SUCCESS OrElse
               vkCreateFence(device, fenceInfo, IntPtr.Zero, inFlightFences(i)) <> VkResult.VK_SUCCESS Then
                Throw New Exception("Failed to create synchronization objects!")
            End If
        Next

        Console.WriteLine("[HelloForm::CreateSyncObjects] - End")
    End Sub

    Private Function MakeVersion(ByVal major As UInteger, ByVal minor As UInteger, ByVal patch As UInteger) As UInteger
        Return (major << 22) Or (minor << 12) Or patch
    End Function

    Private Function StringArrayToPtr(ByVal strings As String()) As IntPtr
        Dim ptrs(strings.Length - 1) As IntPtr
        For i As Integer = 0 To strings.Length - 1
            ptrs(i) = Marshal.StringToHGlobalAnsi(strings(i))
        Next
        Dim arrayPtr As IntPtr = Marshal.AllocHGlobal(IntPtr.Size * strings.Length)
        Marshal.Copy(ptrs, 0, arrayPtr, strings.Length)
        Return arrayPtr
    End Function

    Private Sub FreeStringArray(ByVal arrayPtr As IntPtr, ByVal count As Integer)
        Dim ptrs(count - 1) As IntPtr
        Marshal.Copy(arrayPtr, ptrs, 0, count)
        For Each ptr As IntPtr In ptrs
            Marshal.FreeHGlobal(ptr)
        Next
        Marshal.FreeHGlobal(arrayPtr)
    End Sub

    Private Sub DrawFrame()
        currentFrame = frameIndex Mod MAX_FRAMES_IN_FLIGHT

        Console.WriteLine("----------------------------------------")
        Console.WriteLine($"[HelloForm::DrawFrame] - Start (Frame: {frameIndex}, CurrentFrame: {currentFrame})")
        Console.WriteLine($"ImageAvailableSemaphore: {imageAvailableSemaphores(currentFrame)}")
        Console.WriteLine($"RenderFinishedSemaphore: {renderFinishedSemaphores(currentFrame)}")
        Console.WriteLine($"InFlightFence: {inFlightFences(currentFrame)}")

        vkWaitForFences(device, 1, inFlightFences(currentFrame), VkBool32.True, ULong.MaxValue)
        vkResetFences(device, 1, inFlightFences(currentFrame))

        Dim imageIndex As UInteger = 0
        Dim result As VkResult = vkAcquireNextImageKHR(device, swapChain, ULong.MaxValue, imageAvailableSemaphores(currentFrame), IntPtr.Zero, imageIndex)

        Console.WriteLine($"vkAcquireNextImageKHR result: {result}, imageIndex: {imageIndex}")

        If result <> VkResult.VK_SUCCESS AndAlso result <> VkResult.VK_SUBOPTIMAL_KHR Then
            Throw New Exception("Failed to acquire swap chain image!")
        End If

        Dim beginInfo As New VkCommandBufferBeginInfo With {
            .sType = VkStructureType.VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
            .flags = VkCommandBufferUsageFlags.VK_COMMAND_BUFFER_USAGE_SIMULTANEOUS_USE_BIT
        }

        If vkBeginCommandBuffer(commandBuffer, beginInfo) <> VkResult.VK_SUCCESS Then
            Throw New Exception("Failed to begin recording command buffer!")
        End If

        Console.WriteLine($"RenderPass: {renderPass}")
        Console.WriteLine($"Framebuffer: {swapChainFramebuffers(imageIndex)}")
        Console.WriteLine($"SwapChainExtent: {swapChainExtent.width}x{swapChainExtent.height}")

        Dim clearValues(1) As VkClearValue
        clearValues(0).color = New VkClearColorValue With {
            .float32_0 = 0.0F,
            .float32_1 = 0.0F,
            .float32_2 = 0.0F,
            .float32_3 = 1.0F
        }
        clearValues(1).depthStencil = New VkClearDepthStencilValue With {.depth = 1.0F, .stencil = 0}

        Dim renderPassInfo As New VkRenderPassBeginInfo With {
            .sType = VkStructureType.VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO,
            .renderPass = renderPass,
            .framebuffer = swapChainFramebuffers(imageIndex),
            .renderArea = New VkRect2D With {
                .offset = New VkOffset2D With {.x = 0, .y = 0},
                .extent = swapChainExtent
            },
            .clearValueCount = CUInt(clearValues.Length),
            .pClearValues = Marshal.UnsafeAddrOfPinnedArrayElement(clearValues, 0)
        }

        vkCmdBeginRenderPass(commandBuffer, renderPassInfo, VkSubpassContents.VK_SUBPASS_CONTENTS_INLINE)

        vkCmdBindPipeline(commandBuffer, VkPipelineBindPoint.VK_PIPELINE_BIND_POINT_GRAPHICS, graphicsPipeline)
        vkCmdDraw(commandBuffer, 3, 1, 0, 0)

        vkCmdEndRenderPass(commandBuffer)

        If vkEndCommandBuffer(commandBuffer) <> VkResult.VK_SUCCESS Then
            Throw New Exception("Failed to record command buffer!")
        End If

        Dim waitStages As VkPipelineStageFlags = VkPipelineStageFlags.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT
        Dim submitInfo As New VkSubmitInfo With {
            .sType = VkStructureType.VK_STRUCTURE_TYPE_SUBMIT_INFO,
            .waitSemaphoreCount = 1,
            .pWaitSemaphores = Marshal.UnsafeAddrOfPinnedArrayElement(imageAvailableSemaphores, currentFrame),
            .pWaitDstStageMask = Marshal.UnsafeAddrOfPinnedArrayElement(New VkPipelineStageFlags() {waitStages}, 0),
            .commandBufferCount = 1,
            .pCommandBuffers = Marshal.UnsafeAddrOfPinnedArrayElement(New IntPtr() {commandBuffer}, 0),
            .signalSemaphoreCount = 1,
            .pSignalSemaphores = Marshal.UnsafeAddrOfPinnedArrayElement(renderFinishedSemaphores, currentFrame)
        }

        If vkQueueSubmit(graphicsQueue, 1, submitInfo, inFlightFences(currentFrame)) <> VkResult.VK_SUCCESS Then
            Throw New Exception("Failed to submit draw command buffer!")
        End If

        Dim presentInfo As New VkPresentInfoKHR With {
            .sType = VkStructureType.VK_STRUCTURE_TYPE_PRESENT_INFO_KHR,
            .waitSemaphoreCount = 1,
            .pWaitSemaphores = Marshal.UnsafeAddrOfPinnedArrayElement(renderFinishedSemaphores, currentFrame),
            .swapchainCount = 1,
            .pSwapchains = Marshal.UnsafeAddrOfPinnedArrayElement(New IntPtr() {swapChain}, 0),
            .pImageIndices = Marshal.UnsafeAddrOfPinnedArrayElement(New UInteger() {imageIndex}, 0)
        }

        result = vkQueuePresentKHR(presentQueue, presentInfo)

        If result = VkResult.VK_ERROR_OUT_OF_DATE_KHR OrElse result = VkResult.VK_SUBOPTIMAL_KHR Then
            RecreateSwapChain()
            Return
        ElseIf result <> VkResult.VK_SUCCESS Then
            Throw New Exception("Failed to present swap chain image!")
        End If

        frameIndex += 1
        Console.WriteLine("[HelloForm::DrawFrame] - End")
    End Sub

    Private Sub RecreateSwapChain()
        For Each framebuffer As IntPtr In swapChainFramebuffers
            vkDestroyFramebuffer(device, framebuffer, IntPtr.Zero)
        Next

        vkDestroyPipeline(device, graphicsPipeline, IntPtr.Zero)
        vkDestroyPipelineLayout(device, pipelineLayout, IntPtr.Zero)

        For Each imageView As IntPtr In swapChainImageViews
            vkDestroyImageView(device, imageView, IntPtr.Zero)
        Next

        vkDestroySwapchainKHR(device, swapChain, IntPtr.Zero)

        CreateSwapChain()
        CreateSwapChainImageViews()
        CreateGraphicsPipeline()
        CreateFramebuffers()
    End Sub

    Public Sub Cleanup()
        Console.WriteLine("----------------------------------------")
        Console.WriteLine("[HelloForm::Cleanup] - Start")

        vkDeviceWaitIdle(device)

        vkDestroyImageView(device, depthImageView, IntPtr.Zero)
        vkDestroyImage(device, depthImage, IntPtr.Zero)
        vkFreeMemory(device, depthImageMemory, IntPtr.Zero)

        For i As Integer = 0 To MAX_FRAMES_IN_FLIGHT - 1
            vkDestroySemaphore(device, imageAvailableSemaphores(i), IntPtr.Zero)
            vkDestroySemaphore(device, renderFinishedSemaphores(i), IntPtr.Zero)
            vkDestroyFence(device, inFlightFences(i), IntPtr.Zero)
        Next

        vkDestroyCommandPool(device, commandPool, IntPtr.Zero)

        vkDestroyShaderModule(device, fragShaderModule, IntPtr.Zero)
        vkDestroyShaderModule(device, vertShaderModule, IntPtr.Zero)

        For i As Integer = 0 To swapChainFramebuffers.Length - 1
            vkDestroyFramebuffer(device, swapChainFramebuffers(i), IntPtr.Zero)
        Next

        vkDestroyPipeline(device, graphicsPipeline, IntPtr.Zero)
        vkDestroyPipelineLayout(device, pipelineLayout, IntPtr.Zero)
        vkDestroyRenderPass(device, renderPass, IntPtr.Zero)

        For i As Integer = 0 To swapChainImages.Length - 1
            vkDestroyImageView(device, swapChainImageViews(i), IntPtr.Zero)
        Next

        vkDestroySwapchainKHR(device, swapChain, IntPtr.Zero)
        vkDestroyDevice(device, IntPtr.Zero)

        If debugMessenger <> IntPtr.Zero Then
            Dim vkDestroyDebugUtilsMessengerEXTPtr As IntPtr = vkGetInstanceProcAddr(instance, "vkDestroyDebugUtilsMessengerEXT")
            Dim vkDestroyDebugUtilsMessengerEXT As vkDestroyDebugUtilsMessengerEXTFunc =
                CType(Marshal.GetDelegateForFunctionPointer(vkDestroyDebugUtilsMessengerEXTPtr, GetType(vkDestroyDebugUtilsMessengerEXTFunc)), vkDestroyDebugUtilsMessengerEXTFunc)
            vkDestroyDebugUtilsMessengerEXT(instance, debugMessenger, IntPtr.Zero)
        End If

        vkDestroySurfaceKHR(instance, surface, IntPtr.Zero)
        vkDestroyInstance(instance, IntPtr.Zero)

        Console.WriteLine("[HelloForm::Cleanup] - End")
    End Sub

    <STAThread>
    Shared Sub Main()
        Console.WriteLine("----------------------------------------")
        Console.WriteLine("[HelloForm::Main] - Start")

        Dim form As New HelloForm()
        Application.Run(form)

        Console.WriteLine("[HelloForm::Main] - End")
    End Sub
End Class
