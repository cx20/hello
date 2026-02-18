Imports System
Imports System.Drawing
Imports System.Windows.Forms
Imports System.Runtime.InteropServices
Imports System.IO
Imports System.Text

' ========================================================================================================
' Shader Compiler Class (Using shaderc_shared.dll)
' ========================================================================================================
Public Class ShaderCompiler
    Private Const LibName As String = "shaderc_shared.dll"

    Public Enum ShaderKind As Integer
        Vertex  = 0
        Fragment = 1
        Compute  = 2
    End Enum

    Private Enum CompilationStatus As Integer
        Success = 0
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

    Public Shared Function Compile(ByVal source As String, ByVal kind As ShaderKind,
                                   Optional ByVal fileName As String = "shader.glsl",
                                   Optional ByVal entryPoint As String = "main") As Byte()
        Dim compiler As IntPtr = shaderc_compiler_initialize()
        Dim options As IntPtr = shaderc_compile_options_initialize()
        shaderc_compile_options_set_optimization_level(options, 2)

        Try
            Dim result As IntPtr = shaderc_compile_into_spv(
                compiler, source,
                CType(Encoding.UTF8.GetByteCount(source), UIntPtr),
                CInt(kind), fileName, entryPoint, options)
            Try
                Dim status As CompilationStatus = shaderc_result_get_compilation_status(result)
                If status <> CompilationStatus.Success Then
                    Dim msg As String = Marshal.PtrToStringAnsi(shaderc_result_get_error_message(result))
                    Throw New Exception($"Shader compilation failed: {msg}")
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
' Harmonograph Form – Vulkan 1.4 Compute Shader Pipeline
' ========================================================================================================
Class HarmonographForm
    Inherits Form

    ' --------------------------------------------------------------------------------------------------------
    ' Enumerations
    ' --------------------------------------------------------------------------------------------------------
    Public Enum VkStructureType As UInteger
        VK_STRUCTURE_TYPE_APPLICATION_INFO                       = 0
        VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO                   = 1
        VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO               = 2
        VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO                     = 3
        VK_STRUCTURE_TYPE_SUBMIT_INFO                            = 4
        VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO                   = 5
        VK_STRUCTURE_TYPE_FENCE_CREATE_INFO                      = 8
        VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO                  = 9
        VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO                     = 12
        VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO                 = 15
        VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO              = 16
        VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO      = 18
        VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO = 19
        VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO = 20
        VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO    = 22
        VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO = 23
        VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO = 24
        VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO = 26
        VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO          = 28
        VK_STRUCTURE_TYPE_COMPUTE_PIPELINE_CREATE_INFO           = 29
        VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO            = 30
        VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO      = 32
        VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO            = 33
        VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO           = 34
        VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET                   = 35
        VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO                = 37
        VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO                = 38
        VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO               = 39
        VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO           = 40
        VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO              = 42
        VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO                 = 43
        VK_STRUCTURE_TYPE_BUFFER_MEMORY_BARRIER                  = 44
        VK_STRUCTURE_TYPE_WIN32_SURFACE_CREATE_INFO_KHR          = 1000009000
        VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR              = 1000001000
        VK_STRUCTURE_TYPE_PRESENT_INFO_KHR                       = 1000001001
    End Enum

    Public Enum VkResult As Integer
        VK_SUCCESS              = 0
        VK_SUBOPTIMAL_KHR       = 1000001003
        VK_ERROR_OUT_OF_DATE_KHR = -1000001004
    End Enum

    Public Enum VkBool32 As UInteger
        [False] = 0
        [True]  = 1
    End Enum

    <Flags>
    Public Enum VkQueueFlags As UInteger
        VK_QUEUE_GRAPHICS_BIT = &H1UI
        VK_QUEUE_COMPUTE_BIT  = &H2UI
    End Enum

    Public Enum VkPresentModeKHR As UInteger
        VK_PRESENT_MODE_FIFO_KHR = 2
    End Enum

    <Flags>
    Public Enum VkImageUsageFlags As UInteger
        VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT = &H10UI
    End Enum

    <Flags>
    Public Enum VkSurfaceTransformFlagBitsKHR As UInteger
        VK_SURFACE_TRANSFORM_IDENTITY_BIT_KHR = &H1UI
    End Enum

    <Flags>
    Public Enum VkCompositeAlphaFlagsKHR As UInteger
        VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR = &H1UI
    End Enum

    Public Enum VkPrimitiveTopology As UInteger
        VK_PRIMITIVE_TOPOLOGY_LINE_STRIP = 2
    End Enum

    <Flags>
    Public Enum VkShaderStageFlags As UInteger
        VK_SHADER_STAGE_VERTEX_BIT   = &H1UI
        VK_SHADER_STAGE_FRAGMENT_BIT = &H10UI
        VK_SHADER_STAGE_COMPUTE_BIT  = &H20UI
    End Enum

    <Flags>
    Public Enum VkPipelineStageFlags As UInteger
        VK_PIPELINE_STAGE_VERTEX_SHADER_BIT          = &H8UI
        VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT = &H400UI
        VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT          = &H800UI
    End Enum

    Public Enum VkAttachmentLoadOp As UInteger
        VK_ATTACHMENT_LOAD_OP_CLEAR = 1
    End Enum

    Public Enum VkAttachmentStoreOp As UInteger
        VK_ATTACHMENT_STORE_OP_STORE = 0
    End Enum

    Public Enum VkImageLayout As UInteger
        VK_IMAGE_LAYOUT_UNDEFINED              = 0
        VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL = 2
        VK_IMAGE_LAYOUT_PRESENT_SRC_KHR         = 1000001002
    End Enum

    Public Enum VkSampleCountFlags As UInteger
        VK_SAMPLE_COUNT_1_BIT = &H1UI
    End Enum

    Public Enum VkFormat As UInteger
        VK_FORMAT_B8G8R8A8_UNORM = 44
    End Enum

    Public Enum VkColorSpaceKHR As UInteger
        VK_COLOR_SPACE_SRGB_NONLINEAR_KHR = 0
    End Enum

    Public Enum VkSharingMode As UInteger
        VK_SHARING_MODE_EXCLUSIVE = 0
    End Enum

    Public Enum VkPipelineBindPoint As UInteger
        VK_PIPELINE_BIND_POINT_GRAPHICS = 0
        VK_PIPELINE_BIND_POINT_COMPUTE  = 1
    End Enum

    <Flags>
    Public Enum VkAccessFlags As UInteger
        VK_ACCESS_SHADER_READ_BIT  = &H20UI
        VK_ACCESS_SHADER_WRITE_BIT = &H40UI
    End Enum

    Public Enum VkPolygonMode As UInteger
        VK_POLYGON_MODE_FILL = 0
    End Enum

    <Flags>
    Public Enum VkCullModeFlags As UInteger
        VK_CULL_MODE_NONE = 0
    End Enum

    Public Enum VkFrontFace As UInteger
        VK_FRONT_FACE_COUNTER_CLOCKWISE = 0
    End Enum

    <Flags>
    Public Enum VkColorComponentFlags As UInteger
        VK_COLOR_COMPONENT_R_BIT = &H1UI
        VK_COLOR_COMPONENT_G_BIT = &H2UI
        VK_COLOR_COMPONENT_B_BIT = &H4UI
        VK_COLOR_COMPONENT_A_BIT = &H8UI
    End Enum

    <Flags>
    Public Enum VkCommandBufferUsageFlags As UInteger
        VK_COMMAND_BUFFER_USAGE_SIMULTANEOUS_USE_BIT = &H4UI
    End Enum

    Public Enum VkSubpassContents As UInteger
        VK_SUBPASS_CONTENTS_INLINE = 0
    End Enum

    Public Enum VkCommandBufferLevel As UInteger
        VK_COMMAND_BUFFER_LEVEL_PRIMARY = 0
    End Enum

    <Flags>
    Public Enum VkCommandPoolCreateFlags As UInteger
        VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT = &H2UI
    End Enum

    <Flags>
    Public Enum VkFenceCreateFlags As UInteger
        VK_FENCE_CREATE_SIGNALED_BIT = &H1UI
    End Enum

    Public Enum VkImageViewType As UInteger
        VK_IMAGE_VIEW_TYPE_2D = 1
    End Enum

    <Flags>
    Public Enum VkImageAspectFlags As UInteger
        VK_IMAGE_ASPECT_COLOR_BIT = &H1UI
    End Enum

    Public Enum VkComponentSwizzle As UInteger
        VK_COMPONENT_SWIZZLE_IDENTITY = 0
    End Enum

    <Flags>
    Public Enum VkMemoryPropertyFlags As UInteger
        VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT  = &H1UI
        VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT  = &H2UI
        VK_MEMORY_PROPERTY_HOST_COHERENT_BIT = &H4UI
    End Enum

    <Flags>
    Public Enum VkBufferUsageFlags As UInteger
        VK_BUFFER_USAGE_UNIFORM_BUFFER_BIT = &H10UI
        VK_BUFFER_USAGE_STORAGE_BUFFER_BIT = &H20UI
    End Enum

    Public Enum VkDescriptorType As UInteger
        VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER = 6
        VK_DESCRIPTOR_TYPE_STORAGE_BUFFER = 7
    End Enum

    Public Const VK_QUEUE_FAMILY_IGNORED As UInteger = &HFFFFFFFFUI

    ' --------------------------------------------------------------------------------------------------------
    ' Structures
    ' --------------------------------------------------------------------------------------------------------
    <StructLayout(LayoutKind.Sequential)>
    Public Structure VkExtent2D
        Public width  As UInteger
        Public height As UInteger
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Public Structure VkExtent3D
        Public width  As UInteger
        Public height As UInteger
        Public depth  As UInteger
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Public Structure VkOffset2D
        Public x As Integer
        Public y As Integer
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Public Structure VkRect2D
        Public offset As VkOffset2D
        Public extent As VkExtent2D
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Public Structure VkViewport
        Public x        As Single
        Public y        As Single
        Public width    As Single
        Public height   As Single
        Public minDepth As Single
        Public maxDepth As Single
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Public Structure VkApplicationInfo
        Public sType              As VkStructureType
        Public pNext              As IntPtr
        Public pApplicationName   As IntPtr
        Public applicationVersion As UInteger
        Public pEngineName        As IntPtr
        Public engineVersion      As UInteger
        Public apiVersion         As UInteger
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Public Structure VkInstanceCreateInfo
        Public sType                   As VkStructureType
        Public pNext                   As IntPtr
        Public flags                   As UInteger
        Public pApplicationInfo        As IntPtr
        Public enabledLayerCount       As UInteger
        Public ppEnabledLayerNames     As IntPtr
        Public enabledExtensionCount   As UInteger
        Public ppEnabledExtensionNames As IntPtr
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Public Structure VkQueueFamilyProperties
        Public queueFlags                  As VkQueueFlags
        Public queueCount                  As UInteger
        Public timestampValidBits          As UInteger
        Public minImageTransferGranularity As VkExtent3D
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Public Structure VkSurfaceCapabilitiesKHR
        Public minImageCount          As UInteger
        Public maxImageCount          As UInteger
        Public currentExtent          As VkExtent2D
        Public minImageExtent         As VkExtent2D
        Public maxImageExtent         As VkExtent2D
        Public maxImageArrayLayers    As UInteger
        Public supportedTransforms    As UInteger
        Public currentTransform       As VkSurfaceTransformFlagBitsKHR
        Public supportedCompositeAlpha As VkCompositeAlphaFlagsKHR
        Public supportedUsageFlags    As VkImageUsageFlags
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Public Structure VkSurfaceFormatKHR
        Public format     As VkFormat
        Public colorSpace As VkColorSpaceKHR
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Public Structure VkWin32SurfaceCreateInfoKHR
        Public sType     As VkStructureType
        Public pNext     As IntPtr
        Public flags     As UInteger
        Public hinstance As IntPtr
        Public hwnd      As IntPtr
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Public Structure VkDeviceQueueCreateInfo
        Public sType            As VkStructureType
        Public pNext            As IntPtr
        Public flags            As UInteger
        Public queueFamilyIndex As UInteger
        Public queueCount       As UInteger
        Public pQueuePriorities As IntPtr
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Public Structure VkDeviceCreateInfo
        Public sType                   As VkStructureType
        Public pNext                   As IntPtr
        Public flags                   As UInteger
        Public queueCreateInfoCount    As UInteger
        Public pQueueCreateInfos       As IntPtr
        Public enabledLayerCount       As UInteger
        Public ppEnabledLayerNames     As IntPtr
        Public enabledExtensionCount   As UInteger
        Public ppEnabledExtensionNames As IntPtr
        Public pEnabledFeatures        As IntPtr
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Public Structure VkSwapchainCreateInfoKHR
        Public sType            As VkStructureType
        Public pNext            As IntPtr
        Public flags            As UInteger
        Public surface          As IntPtr
        Public minImageCount    As UInteger
        Public imageFormat      As VkFormat
        Public imageColorSpace  As VkColorSpaceKHR
        Public imageExtent      As VkExtent2D
        Public imageArrayLayers As UInteger
        Public imageUsage       As VkImageUsageFlags
        Public imageSharingMode As VkSharingMode
        Public queueFamilyIndexCount As UInteger
        Public pQueueFamilyIndices   As IntPtr
        Public preTransform   As VkSurfaceTransformFlagBitsKHR
        Public compositeAlpha As VkCompositeAlphaFlagsKHR
        Public presentMode    As VkPresentModeKHR
        Public clipped        As VkBool32
        Public oldSwapchain   As IntPtr
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
        Public aspectMask     As VkImageAspectFlags
        Public baseMipLevel   As UInteger
        Public levelCount     As UInteger
        Public baseArrayLayer As UInteger
        Public layerCount     As UInteger
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Public Structure VkImageViewCreateInfo
        Public sType            As VkStructureType
        Public pNext            As IntPtr
        Public flags            As UInteger
        Public image            As IntPtr
        Public viewType         As VkImageViewType
        Public format           As VkFormat
        Public components       As VkComponentMapping
        Public subresourceRange As VkImageSubresourceRange
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Public Structure VkAttachmentDescription
        Public flags          As UInteger
        Public format         As VkFormat
        Public samples        As VkSampleCountFlags
        Public loadOp         As VkAttachmentLoadOp
        Public storeOp        As VkAttachmentStoreOp
        Public stencilLoadOp  As VkAttachmentLoadOp
        Public stencilStoreOp As VkAttachmentStoreOp
        Public initialLayout  As VkImageLayout
        Public finalLayout    As VkImageLayout
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Public Structure VkAttachmentReference
        Public attachment As UInteger
        Public layout     As VkImageLayout
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Public Structure VkSubpassDescription
        Public flags                   As UInteger
        Public pipelineBindPoint       As VkPipelineBindPoint
        Public inputAttachmentCount    As UInteger
        Public pInputAttachments       As IntPtr
        Public colorAttachmentCount    As UInteger
        Public pColorAttachments       As IntPtr
        Public pResolveAttachments     As IntPtr
        Public pDepthStencilAttachment As IntPtr
        Public preserveAttachmentCount As UInteger
        Public pPreserveAttachments    As IntPtr
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Public Structure VkRenderPassCreateInfo
        Public sType          As VkStructureType
        Public pNext          As IntPtr
        Public flags          As UInteger
        Public attachmentCount As UInteger
        Public pAttachments   As IntPtr
        Public subpassCount   As UInteger
        Public pSubpasses     As IntPtr
        Public dependencyCount As UInteger
        Public pDependencies  As IntPtr
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Public Structure VkShaderModuleCreateInfo
        Public sType    As VkStructureType
        Public pNext    As IntPtr
        Public flags    As UInteger
        Public codeSize As UIntPtr
        Public pCode    As IntPtr
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Public Structure VkPipelineShaderStageCreateInfo
        Public sType               As VkStructureType
        Public pNext               As IntPtr
        Public flags               As UInteger
        Public stage               As VkShaderStageFlags
        Public [module]            As IntPtr
        Public pName               As IntPtr
        Public pSpecializationInfo As IntPtr
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Public Structure VkComputePipelineCreateInfo
        Public sType              As VkStructureType
        Public pNext              As IntPtr
        Public flags              As UInteger
        Public stage              As VkPipelineShaderStageCreateInfo
        Public layout             As IntPtr
        Public basePipelineHandle As IntPtr
        Public basePipelineIndex  As Integer
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Public Structure VkPipelineVertexInputStateCreateInfo
        Public sType                           As VkStructureType
        Public pNext                           As IntPtr
        Public flags                           As UInteger
        Public vertexBindingDescriptionCount   As UInteger
        Public pVertexBindingDescriptions      As IntPtr
        Public vertexAttributeDescriptionCount As UInteger
        Public pVertexAttributeDescriptions    As IntPtr
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Public Structure VkPipelineInputAssemblyStateCreateInfo
        Public sType                  As VkStructureType
        Public pNext                  As IntPtr
        Public flags                  As UInteger
        Public topology               As VkPrimitiveTopology
        Public primitiveRestartEnable As VkBool32
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Public Structure VkPipelineViewportStateCreateInfo
        Public sType         As VkStructureType
        Public pNext         As IntPtr
        Public flags         As UInteger
        Public viewportCount As UInteger
        Public pViewports    As IntPtr
        Public scissorCount  As UInteger
        Public pScissors     As IntPtr
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Public Structure VkPipelineRasterizationStateCreateInfo
        Public sType                   As VkStructureType
        Public pNext                   As IntPtr
        Public flags                   As UInteger
        Public depthClampEnable        As VkBool32
        Public rasterizerDiscardEnable As VkBool32
        Public polygonMode             As VkPolygonMode
        Public cullMode                As VkCullModeFlags
        Public frontFace               As VkFrontFace
        Public depthBiasEnable         As VkBool32
        Public depthBiasConstantFactor As Single
        Public depthBiasClamp          As Single
        Public depthBiasSlopeFactor    As Single
        Public lineWidth               As Single
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Public Structure VkPipelineMultisampleStateCreateInfo
        Public sType                 As VkStructureType
        Public pNext                 As IntPtr
        Public flags                 As UInteger
        Public rasterizationSamples  As VkSampleCountFlags
        Public sampleShadingEnable   As VkBool32
        Public minSampleShading      As Single
        Public pSampleMask           As IntPtr
        Public alphaToCoverageEnable As VkBool32
        Public alphaToOneEnable      As VkBool32
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Public Structure VkPipelineColorBlendAttachmentState
        Public blendEnable         As VkBool32
        Public srcColorBlendFactor As UInteger
        Public dstColorBlendFactor As UInteger
        Public colorBlendOp        As UInteger
        Public srcAlphaBlendFactor As UInteger
        Public dstAlphaBlendFactor As UInteger
        Public alphaBlendOp        As UInteger
        Public colorWriteMask      As VkColorComponentFlags
    End Structure

    ' Use four separate floats to keep the struct blittable (GCHandle.Alloc compatible)
    <StructLayout(LayoutKind.Sequential)>
    Public Structure VkPipelineColorBlendStateCreateInfo
        Public sType            As VkStructureType
        Public pNext            As IntPtr
        Public flags            As UInteger
        Public logicOpEnable    As VkBool32
        Public logicOp         As UInteger
        Public attachmentCount  As UInteger
        Public pAttachments     As IntPtr
        Public blendConstant0   As Single
        Public blendConstant1   As Single
        Public blendConstant2   As Single
        Public blendConstant3   As Single
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Public Structure VkPipelineLayoutCreateInfo
        Public sType                  As VkStructureType
        Public pNext                  As IntPtr
        Public flags                  As UInteger
        Public setLayoutCount         As UInteger
        Public pSetLayouts            As IntPtr
        Public pushConstantRangeCount As UInteger
        Public pPushConstantRanges    As IntPtr
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Public Structure VkGraphicsPipelineCreateInfo
        Public sType              As VkStructureType
        Public pNext              As IntPtr
        Public flags              As UInteger
        Public stageCount         As UInteger
        Public pStages            As IntPtr
        Public pVertexInputState  As IntPtr
        Public pInputAssemblyState As IntPtr
        Public pTessellationState As IntPtr
        Public pViewportState     As IntPtr
        Public pRasterizationState As IntPtr
        Public pMultisampleState  As IntPtr
        Public pDepthStencilState As IntPtr
        Public pColorBlendState   As IntPtr
        Public pDynamicState      As IntPtr
        Public layout             As IntPtr
        Public renderPass         As IntPtr
        Public subpass            As UInteger
        Public basePipelineHandle As IntPtr
        Public basePipelineIndex  As Integer
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Public Structure VkFramebufferCreateInfo
        Public sType           As VkStructureType
        Public pNext           As IntPtr
        Public flags           As UInteger
        Public renderPass      As IntPtr
        Public attachmentCount As UInteger
        Public pAttachments    As IntPtr
        Public width           As UInteger
        Public height          As UInteger
        Public layers          As UInteger
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Public Structure VkCommandPoolCreateInfo
        Public sType            As VkStructureType
        Public pNext            As IntPtr
        Public flags            As VkCommandPoolCreateFlags
        Public queueFamilyIndex As UInteger
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Public Structure VkCommandBufferAllocateInfo
        Public sType              As VkStructureType
        Public pNext              As IntPtr
        Public commandPool        As IntPtr
        Public level              As VkCommandBufferLevel
        Public commandBufferCount As UInteger
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Public Structure VkCommandBufferBeginInfo
        Public sType            As VkStructureType
        Public pNext            As IntPtr
        Public flags            As VkCommandBufferUsageFlags
        Public pInheritanceInfo As IntPtr
    End Structure

    ' ClearColorValue as four floats (r,g,b,a)
    <StructLayout(LayoutKind.Sequential)>
    Public Structure VkClearColorValue
        Public r As Single
        Public g As Single
        Public b As Single
        Public a As Single
    End Structure

    ' Simplified ClearValue – only color (no depth union needed here)
    <StructLayout(LayoutKind.Sequential)>
    Public Structure VkClearValue
        Public color As VkClearColorValue
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Public Structure VkRenderPassBeginInfo
        Public sType          As VkStructureType
        Public pNext          As IntPtr
        Public renderPass     As IntPtr
        Public framebuffer    As IntPtr
        Public renderArea     As VkRect2D
        Public clearValueCount As UInteger
        Public pClearValues   As IntPtr
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
        Public flags As VkFenceCreateFlags
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Public Structure VkSubmitInfo
        Public sType                As VkStructureType
        Public pNext                As IntPtr
        Public waitSemaphoreCount   As UInteger
        Public pWaitSemaphores      As IntPtr
        Public pWaitDstStageMask    As IntPtr
        Public commandBufferCount   As UInteger
        Public pCommandBuffers      As IntPtr
        Public signalSemaphoreCount As UInteger
        Public pSignalSemaphores    As IntPtr
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Public Structure VkPresentInfoKHR
        Public sType              As VkStructureType
        Public pNext              As IntPtr
        Public waitSemaphoreCount As UInteger
        Public pWaitSemaphores    As IntPtr
        Public swapchainCount     As UInteger
        Public pSwapchains        As IntPtr
        Public pImageIndices      As IntPtr
        Public pResults           As IntPtr
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Public Structure VkBufferCreateInfo
        Public sType                 As VkStructureType
        Public pNext                 As IntPtr
        Public flags                 As UInteger
        Public size                  As ULong
        Public usage                 As VkBufferUsageFlags
        Public sharingMode           As VkSharingMode
        Public queueFamilyIndexCount As UInteger
        Public pQueueFamilyIndices   As IntPtr
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Public Structure VkMemoryRequirements
        Public size           As ULong
        Public alignment      As ULong
        Public memoryTypeBits As UInteger
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Public Structure VkMemoryAllocateInfo
        Public sType           As VkStructureType
        Public pNext           As IntPtr
        Public allocationSize  As ULong
        Public memoryTypeIndex As UInteger
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Public Structure VkMemoryType
        Public propertyFlags As VkMemoryPropertyFlags
        Public heapIndex     As UInteger
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Public Structure VkMemoryHeap
        Public size  As ULong
        Public flags As UInteger
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Public Structure VkPhysicalDeviceMemoryProperties
        Public memoryTypeCount As UInteger
        <MarshalAs(UnmanagedType.ByValArray, SizeConst:=32)> Public memoryTypes() As VkMemoryType
        Public memoryHeapCount As UInteger
        <MarshalAs(UnmanagedType.ByValArray, SizeConst:=16)> Public memoryHeaps() As VkMemoryHeap
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Public Structure VkDescriptorSetLayoutBinding
        Public binding            As UInteger
        Public descriptorType     As VkDescriptorType
        Public descriptorCount    As UInteger
        Public stageFlags         As VkShaderStageFlags
        Public pImmutableSamplers As IntPtr
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Public Structure VkDescriptorSetLayoutCreateInfo
        Public sType        As VkStructureType
        Public pNext        As IntPtr
        Public flags        As UInteger
        Public bindingCount As UInteger
        Public pBindings    As IntPtr
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Public Structure VkDescriptorPoolSize
        Public type            As VkDescriptorType
        Public descriptorCount As UInteger
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Public Structure VkDescriptorPoolCreateInfo
        Public sType         As VkStructureType
        Public pNext         As IntPtr
        Public flags         As UInteger
        Public maxSets       As UInteger
        Public poolSizeCount As UInteger
        Public pPoolSizes    As IntPtr
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Public Structure VkDescriptorSetAllocateInfo
        Public sType              As VkStructureType
        Public pNext              As IntPtr
        Public descriptorPool     As IntPtr
        Public descriptorSetCount As UInteger
        Public pSetLayouts        As IntPtr
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Public Structure VkDescriptorBufferInfo
        Public buffer As IntPtr
        Public offset As ULong
        Public range  As ULong
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Public Structure VkWriteDescriptorSet
        Public sType            As VkStructureType
        Public pNext            As IntPtr
        Public dstSet           As IntPtr
        Public dstBinding       As UInteger
        Public dstArrayElement  As UInteger
        Public descriptorCount  As UInteger
        Public descriptorType   As VkDescriptorType
        Public pImageInfo       As IntPtr
        Public pBufferInfo      As IntPtr
        Public pTexelBufferView As IntPtr
    End Structure

    ' VkBufferMemoryBarrier uses raw UInteger for access/sType to stay blittable
    <StructLayout(LayoutKind.Sequential)>
    Public Structure VkBufferMemoryBarrier
        Public sType               As UInteger
        Public pNext               As IntPtr
        Public srcAccessMask       As UInteger
        Public dstAccessMask       As UInteger
        Public srcQueueFamilyIndex As UInteger
        Public dstQueueFamilyIndex As UInteger
        Public buffer              As IntPtr
        Public offset              As ULong
        Public size                As ULong
    End Structure

    ' --------------------------------------------------------------------------------------------------------
    ' ParamsUBO – matches the std140 uniform block in hello.comp
    ' --------------------------------------------------------------------------------------------------------
    <StructLayout(LayoutKind.Sequential, Pack:=4)>
    Public Structure ParamsUBO
        Public max_num As UInteger
        Public dt      As Single
        Public scale   As Single
        Public pad0    As Single
        Public A1 As Single
        Public f1 As Single
        Public p1 As Single
        Public d1 As Single
        Public A2 As Single
        Public f2 As Single
        Public p2 As Single
        Public d2 As Single
        Public A3 As Single
        Public f3 As Single
        Public p3 As Single
        Public d3 As Single
        Public A4 As Single
        Public f4 As Single
        Public p4 As Single
        Public d4 As Single
    End Structure

    ' --------------------------------------------------------------------------------------------------------
    ' Vulkan DLL Imports
    ' --------------------------------------------------------------------------------------------------------
    Private Const VulkanLib As String = "vulkan-1.dll"

    <DllImport("kernel32.dll", CharSet:=CharSet.Auto)>
    Private Shared Function GetModuleHandle(ByVal lpModuleName As String) As IntPtr
    End Function

    <DllImport(VulkanLib)> Private Shared Function vkCreateInstance(ByRef ci As VkInstanceCreateInfo, ByVal pa As IntPtr, ByRef inst As IntPtr) As VkResult
    End Function
    <DllImport(VulkanLib)> Private Shared Sub vkDestroyInstance(ByVal inst As IntPtr, ByVal pa As IntPtr)
    End Sub
    <DllImport(VulkanLib)> Private Shared Function vkEnumeratePhysicalDevices(ByVal inst As IntPtr, ByRef count As UInteger, ByVal devs As IntPtr) As VkResult
    End Function
    <DllImport(VulkanLib)> Private Shared Sub vkGetPhysicalDeviceQueueFamilyProperties(ByVal pd As IntPtr, ByRef count As UInteger, ByVal props As IntPtr)
    End Sub
    <DllImport(VulkanLib)> Private Shared Function vkGetPhysicalDeviceSurfaceSupportKHR(ByVal pd As IntPtr, ByVal qfi As UInteger, ByVal surf As IntPtr, ByRef supported As VkBool32) As VkResult
    End Function
    <DllImport(VulkanLib)> Private Shared Function vkCreateWin32SurfaceKHR(ByVal inst As IntPtr, ByRef ci As VkWin32SurfaceCreateInfoKHR, ByVal pa As IntPtr, ByRef surf As IntPtr) As VkResult
    End Function
    <DllImport(VulkanLib)> Private Shared Sub vkDestroySurfaceKHR(ByVal inst As IntPtr, ByVal surf As IntPtr, ByVal pa As IntPtr)
    End Sub
    <DllImport(VulkanLib)> Private Shared Function vkGetPhysicalDeviceSurfaceCapabilitiesKHR(ByVal pd As IntPtr, ByVal surf As IntPtr, ByRef caps As VkSurfaceCapabilitiesKHR) As VkResult
    End Function
    <DllImport(VulkanLib)> Private Shared Function vkGetPhysicalDeviceSurfaceFormatsKHR(ByVal pd As IntPtr, ByVal surf As IntPtr, ByRef count As UInteger, ByVal fmts As IntPtr) As VkResult
    End Function
    <DllImport(VulkanLib)> Private Shared Function vkCreateDevice(ByVal pd As IntPtr, ByRef ci As VkDeviceCreateInfo, ByVal pa As IntPtr, ByRef dev As IntPtr) As VkResult
    End Function
    <DllImport(VulkanLib)> Private Shared Sub vkDestroyDevice(ByVal dev As IntPtr, ByVal pa As IntPtr)
    End Sub
    <DllImport(VulkanLib)> Private Shared Sub vkGetDeviceQueue(ByVal dev As IntPtr, ByVal qfi As UInteger, ByVal qi As UInteger, ByRef q As IntPtr)
    End Sub
    <DllImport(VulkanLib)> Private Shared Function vkCreateSwapchainKHR(ByVal dev As IntPtr, ByRef ci As VkSwapchainCreateInfoKHR, ByVal pa As IntPtr, ByRef sc As IntPtr) As VkResult
    End Function
    <DllImport(VulkanLib)> Private Shared Sub vkDestroySwapchainKHR(ByVal dev As IntPtr, ByVal sc As IntPtr, ByVal pa As IntPtr)
    End Sub
    <DllImport(VulkanLib)> Private Shared Function vkGetSwapchainImagesKHR(ByVal dev As IntPtr, ByVal sc As IntPtr, ByRef count As UInteger, ByVal images As IntPtr) As VkResult
    End Function
    <DllImport(VulkanLib)> Private Shared Function vkCreateImageView(ByVal dev As IntPtr, ByRef ci As VkImageViewCreateInfo, ByVal pa As IntPtr, ByRef view As IntPtr) As VkResult
    End Function
    <DllImport(VulkanLib)> Private Shared Sub vkDestroyImageView(ByVal dev As IntPtr, ByVal view As IntPtr, ByVal pa As IntPtr)
    End Sub
    <DllImport(VulkanLib)> Private Shared Function vkCreateRenderPass(ByVal dev As IntPtr, ByRef ci As VkRenderPassCreateInfo, ByVal pa As IntPtr, ByRef rp As IntPtr) As VkResult
    End Function
    <DllImport(VulkanLib)> Private Shared Sub vkDestroyRenderPass(ByVal dev As IntPtr, ByVal rp As IntPtr, ByVal pa As IntPtr)
    End Sub
    <DllImport(VulkanLib)> Private Shared Function vkCreateShaderModule(ByVal dev As IntPtr, ByRef ci As VkShaderModuleCreateInfo, ByVal pa As IntPtr, ByRef sm As IntPtr) As VkResult
    End Function
    <DllImport(VulkanLib)> Private Shared Sub vkDestroyShaderModule(ByVal dev As IntPtr, ByVal sm As IntPtr, ByVal pa As IntPtr)
    End Sub
    <DllImport(VulkanLib)> Private Shared Function vkCreatePipelineLayout(ByVal dev As IntPtr, ByRef ci As VkPipelineLayoutCreateInfo, ByVal pa As IntPtr, ByRef pl As IntPtr) As VkResult
    End Function
    <DllImport(VulkanLib)> Private Shared Sub vkDestroyPipelineLayout(ByVal dev As IntPtr, ByVal pl As IntPtr, ByVal pa As IntPtr)
    End Sub
    <DllImport(VulkanLib)> Private Shared Function vkCreateComputePipelines(ByVal dev As IntPtr, ByVal cache As IntPtr, ByVal count As UInteger, ByRef ci As VkComputePipelineCreateInfo, ByVal pa As IntPtr, ByRef pip As IntPtr) As VkResult
    End Function
    <DllImport(VulkanLib)> Private Shared Function vkCreateGraphicsPipelines(ByVal dev As IntPtr, ByVal cache As IntPtr, ByVal count As UInteger, ByVal ci As IntPtr, ByVal pa As IntPtr, ByRef pip As IntPtr) As VkResult
    End Function
    <DllImport(VulkanLib)> Private Shared Sub vkDestroyPipeline(ByVal dev As IntPtr, ByVal pip As IntPtr, ByVal pa As IntPtr)
    End Sub
    <DllImport(VulkanLib)> Private Shared Function vkCreateFramebuffer(ByVal dev As IntPtr, ByRef ci As VkFramebufferCreateInfo, ByVal pa As IntPtr, ByRef fb As IntPtr) As VkResult
    End Function
    <DllImport(VulkanLib)> Private Shared Sub vkDestroyFramebuffer(ByVal dev As IntPtr, ByVal fb As IntPtr, ByVal pa As IntPtr)
    End Sub
    <DllImport(VulkanLib)> Private Shared Function vkCreateCommandPool(ByVal dev As IntPtr, ByRef ci As VkCommandPoolCreateInfo, ByVal pa As IntPtr, ByRef cp As IntPtr) As VkResult
    End Function
    <DllImport(VulkanLib)> Private Shared Sub vkDestroyCommandPool(ByVal dev As IntPtr, ByVal cp As IntPtr, ByVal pa As IntPtr)
    End Sub
    <DllImport(VulkanLib)> Private Shared Function vkAllocateCommandBuffers(ByVal dev As IntPtr, ByRef ci As VkCommandBufferAllocateInfo, ByVal cbs As IntPtr) As VkResult
    End Function
    <DllImport(VulkanLib)> Private Shared Function vkBeginCommandBuffer(ByVal cb As IntPtr, ByRef bi As VkCommandBufferBeginInfo) As VkResult
    End Function
    <DllImport(VulkanLib)> Private Shared Function vkEndCommandBuffer(ByVal cb As IntPtr) As VkResult
    End Function
    <DllImport(VulkanLib)> Private Shared Function vkResetCommandBuffer(ByVal cb As IntPtr, ByVal flags As UInteger) As VkResult
    End Function
    <DllImport(VulkanLib)> Private Shared Sub vkCmdBindPipeline(ByVal cb As IntPtr, ByVal bp As VkPipelineBindPoint, ByVal pip As IntPtr)
    End Sub
    <DllImport(VulkanLib)> Private Shared Sub vkCmdBindDescriptorSets(ByVal cb As IntPtr, ByVal bp As VkPipelineBindPoint, ByVal layout As IntPtr, ByVal first As UInteger, ByVal count As UInteger, ByRef ds As IntPtr, ByVal dynCount As UInteger, ByVal pDynOffsets As IntPtr)
    End Sub
    <DllImport(VulkanLib)> Private Shared Sub vkCmdDispatch(ByVal cb As IntPtr, ByVal x As UInteger, ByVal y As UInteger, ByVal z As UInteger)
    End Sub
    <DllImport(VulkanLib)> Private Shared Sub vkCmdPipelineBarrier(ByVal cb As IntPtr, ByVal src As VkPipelineStageFlags, ByVal dst As VkPipelineStageFlags, ByVal depFlags As UInteger, ByVal memCount As UInteger, ByVal pMemBarriers As IntPtr, ByVal bufCount As UInteger, ByVal pBufBarriers As IntPtr, ByVal imgCount As UInteger, ByVal pImgBarriers As IntPtr)
    End Sub
    <DllImport(VulkanLib)> Private Shared Sub vkCmdBeginRenderPass(ByVal cb As IntPtr, ByRef bi As VkRenderPassBeginInfo, ByVal contents As VkSubpassContents)
    End Sub
    <DllImport(VulkanLib)> Private Shared Sub vkCmdEndRenderPass(ByVal cb As IntPtr)
    End Sub
    <DllImport(VulkanLib)> Private Shared Sub vkCmdDraw(ByVal cb As IntPtr, ByVal vertexCount As UInteger, ByVal instanceCount As UInteger, ByVal firstVertex As UInteger, ByVal firstInstance As UInteger)
    End Sub
    <DllImport(VulkanLib)> Private Shared Function vkQueueSubmit(ByVal q As IntPtr, ByVal count As UInteger, ByRef si As VkSubmitInfo, ByVal fence As IntPtr) As VkResult
    End Function
    <DllImport(VulkanLib)> Private Shared Function vkQueuePresentKHR(ByVal q As IntPtr, ByRef pi As VkPresentInfoKHR) As VkResult
    End Function
    <DllImport(VulkanLib)> Private Shared Function vkDeviceWaitIdle(ByVal dev As IntPtr) As VkResult
    End Function
    <DllImport(VulkanLib)> Private Shared Function vkCreateSemaphore(ByVal dev As IntPtr, ByRef ci As VkSemaphoreCreateInfo, ByVal pa As IntPtr, ByRef sem As IntPtr) As VkResult
    End Function
    <DllImport(VulkanLib)> Private Shared Sub vkDestroySemaphore(ByVal dev As IntPtr, ByVal sem As IntPtr, ByVal pa As IntPtr)
    End Sub
    <DllImport(VulkanLib)> Private Shared Function vkCreateFence(ByVal dev As IntPtr, ByRef ci As VkFenceCreateInfo, ByVal pa As IntPtr, ByRef fence As IntPtr) As VkResult
    End Function
    <DllImport(VulkanLib)> Private Shared Sub vkDestroyFence(ByVal dev As IntPtr, ByVal fence As IntPtr, ByVal pa As IntPtr)
    End Sub
    <DllImport(VulkanLib)> Private Shared Function vkWaitForFences(ByVal dev As IntPtr, ByVal count As UInteger, ByRef fence As IntPtr, ByVal waitAll As VkBool32, ByVal timeout As ULong) As VkResult
    End Function
    <DllImport(VulkanLib)> Private Shared Function vkResetFences(ByVal dev As IntPtr, ByVal count As UInteger, ByRef fence As IntPtr) As VkResult
    End Function
    <DllImport(VulkanLib)> Private Shared Function vkAcquireNextImageKHR(ByVal dev As IntPtr, ByVal sc As IntPtr, ByVal timeout As ULong, ByVal sem As IntPtr, ByVal fence As IntPtr, ByRef imageIndex As UInteger) As VkResult
    End Function
    <DllImport(VulkanLib)> Private Shared Function vkCreateBuffer(ByVal dev As IntPtr, ByRef ci As VkBufferCreateInfo, ByVal pa As IntPtr, ByRef buf As IntPtr) As VkResult
    End Function
    <DllImport(VulkanLib)> Private Shared Sub vkGetBufferMemoryRequirements(ByVal dev As IntPtr, ByVal buf As IntPtr, ByRef req As VkMemoryRequirements)
    End Sub
    <DllImport(VulkanLib)> Private Shared Function vkAllocateMemory(ByVal dev As IntPtr, ByRef ci As VkMemoryAllocateInfo, ByVal pa As IntPtr, ByRef mem As IntPtr) As VkResult
    End Function
    <DllImport(VulkanLib)> Private Shared Function vkBindBufferMemory(ByVal dev As IntPtr, ByVal buf As IntPtr, ByVal mem As IntPtr, ByVal offset As ULong) As VkResult
    End Function
    <DllImport(VulkanLib)> Private Shared Sub vkFreeMemory(ByVal dev As IntPtr, ByVal mem As IntPtr, ByVal pa As IntPtr)
    End Sub
    <DllImport(VulkanLib)> Private Shared Sub vkDestroyBuffer(ByVal dev As IntPtr, ByVal buf As IntPtr, ByVal pa As IntPtr)
    End Sub
    <DllImport(VulkanLib)> Private Shared Sub vkGetPhysicalDeviceMemoryProperties(ByVal pd As IntPtr, ByRef props As VkPhysicalDeviceMemoryProperties)
    End Sub
    <DllImport(VulkanLib)> Private Shared Function vkMapMemory(ByVal dev As IntPtr, ByVal mem As IntPtr, ByVal offset As ULong, ByVal size As ULong, ByVal flags As UInteger, ByRef data As IntPtr) As VkResult
    End Function
    <DllImport(VulkanLib)> Private Shared Sub vkUnmapMemory(ByVal dev As IntPtr, ByVal mem As IntPtr)
    End Sub
    <DllImport(VulkanLib)> Private Shared Function vkCreateDescriptorSetLayout(ByVal dev As IntPtr, ByRef ci As VkDescriptorSetLayoutCreateInfo, ByVal pa As IntPtr, ByRef dsl As IntPtr) As VkResult
    End Function
    <DllImport(VulkanLib)> Private Shared Sub vkDestroyDescriptorSetLayout(ByVal dev As IntPtr, ByVal dsl As IntPtr, ByVal pa As IntPtr)
    End Sub
    <DllImport(VulkanLib)> Private Shared Function vkCreateDescriptorPool(ByVal dev As IntPtr, ByRef ci As VkDescriptorPoolCreateInfo, ByVal pa As IntPtr, ByRef dp As IntPtr) As VkResult
    End Function
    <DllImport(VulkanLib)> Private Shared Sub vkDestroyDescriptorPool(ByVal dev As IntPtr, ByVal dp As IntPtr, ByVal pa As IntPtr)
    End Sub
    <DllImport(VulkanLib)> Private Shared Function vkAllocateDescriptorSets(ByVal dev As IntPtr, ByRef ci As VkDescriptorSetAllocateInfo, ByRef ds As IntPtr) As VkResult
    End Function
    <DllImport(VulkanLib)> Private Shared Sub vkUpdateDescriptorSets(ByVal dev As IntPtr, ByVal writeCount As UInteger, ByVal pWrites As IntPtr, ByVal copyCount As UInteger, ByVal pCopies As IntPtr)
    End Sub

    ' --------------------------------------------------------------------------------------------------------
    ' Constants and Fields
    ' --------------------------------------------------------------------------------------------------------
    Private Const MAX_FRAMES_IN_FLIGHT As Integer = 2
    Private Const VERTEX_COUNT         As UInteger = 500000UI

    Private instance           As IntPtr
    Private physicalDevice     As IntPtr
    Private device             As IntPtr
    Private surface            As IntPtr
    Private swapchain          As IntPtr
    Private renderPass         As IntPtr
    Private queue              As IntPtr
    Private commandPool        As IntPtr

    Private computePipeline       As IntPtr
    Private computePipelineLayout As IntPtr
    Private graphicsPipeline      As IntPtr
    Private graphicsPipelineLayout As IntPtr

    Private descriptorSetLayout As IntPtr
    Private descriptorPool      As IntPtr
    Private descriptorSet       As IntPtr

    Private posBuffer As IntPtr
    Private posMemory As IntPtr
    Private colBuffer As IntPtr
    Private colMemory As IntPtr
    Private uboBuffer As IntPtr
    Private uboMemory As IntPtr

    Private compShaderModule As IntPtr
    Private vertShaderModule As IntPtr
    Private fragShaderModule As IntPtr

    Private swapchainImages()    As IntPtr
    Private swapchainImageViews() As IntPtr
    Private framebuffers()       As IntPtr
    Private commandBuffers()     As IntPtr

    Private imageAvailableSemaphores() As IntPtr
    Private renderFinishedSemaphores() As IntPtr
    Private inFlightFences()           As IntPtr

    Private queueFamily     As UInteger
    Private swapchainExtent As VkExtent2D
    Private swapchainFormat As VkFormat
    Private frameIndex      As Integer = 0
    Private isInitialized   As Boolean = False
    Private uboParams       As ParamsUBO
    Private animTime        As Single   = 0.0F

    Private renderTimer As System.Windows.Forms.Timer

    ' --------------------------------------------------------------------------------------------------------
    ' Constructor
    ' --------------------------------------------------------------------------------------------------------
    Public Sub New()
        Me.Size          = New Size(960, 720)
        Me.Text          = "Vulkan 1.4 Compute Harmonograph (VB.NET)"
        Me.SetStyle(ControlStyles.AllPaintingInWmPaint Or ControlStyles.UserPaint, True)
        Me.DoubleBuffered = False
    End Sub

    ' --------------------------------------------------------------------------------------------------------
    ' Form Overrides
    ' --------------------------------------------------------------------------------------------------------
    Protected Overrides Sub OnHandleCreated(ByVal e As EventArgs)
        MyBase.OnHandleCreated(e)
        Initialize()
        isInitialized = True

        ' Start a ~60 FPS render timer
        renderTimer          = New System.Windows.Forms.Timer()
        renderTimer.Interval = 16
        AddHandler renderTimer.Tick, Sub(s, args)
                                         If isInitialized Then DrawFrame()
                                     End Sub
        renderTimer.Start()
    End Sub

    Protected Overrides Sub OnPaint(ByVal e As PaintEventArgs)
        ' Vulkan handles all rendering – suppress default paint
    End Sub

    Protected Overrides Sub OnPaintBackground(ByVal e As PaintEventArgs)
        ' Vulkan handles background – suppress to prevent flicker
    End Sub

    Protected Overrides Sub OnResize(ByVal e As EventArgs)
        MyBase.OnResize(e)
        If isInitialized AndAlso Me.WindowState <> FormWindowState.Minimized Then
            renderTimer?.Stop()
            RecreateSwapchain()
            renderTimer?.Start()
        End If
    End Sub

    Protected Overrides Sub OnFormClosing(ByVal e As FormClosingEventArgs)
        MyBase.OnFormClosing(e)
        renderTimer?.Stop()
        isInitialized = False
        Cleanup()
    End Sub

    ' --------------------------------------------------------------------------------------------------------
    ' Initialization Pipeline
    ' --------------------------------------------------------------------------------------------------------
    Private Sub Initialize()
        Console.WriteLine("Initializing Vulkan Harmonograph...")
        CreateInstance()
        CreateSurface()
        PickPhysicalDevice()
        CreateDevice()
        CreateSwapchain()
        CreateRenderPass()
        CreateDescriptorSetLayout()
        CreateBuffers()
        CreateDescriptorPool()
        CreateDescriptorSet()
        CompileShaders()
        CreateComputePipeline()
        CreateGraphicsPipeline()
        CreateFramebuffers()
        CreateCommandPool()
        CreateCommandBuffers()
        CreateSyncObjects()
        InitUBO()
        Console.WriteLine("Vulkan Harmonograph initialized.")
    End Sub

    ' --------------------------------------------------------------------------------------------------------
    ' Create Vulkan Instance (Vulkan 1.4, no validation layers for release mode)
    ' --------------------------------------------------------------------------------------------------------
    Private Sub CreateInstance()
        Dim appNamePtr    As IntPtr = Marshal.StringToHGlobalAnsi("Harmonograph")
        Dim engineNamePtr As IntPtr = Marshal.StringToHGlobalAnsi("NoEngine")

        Dim appInfo As New VkApplicationInfo With {
            .sType              = VkStructureType.VK_STRUCTURE_TYPE_APPLICATION_INFO,
            .pApplicationName   = appNamePtr,
            .applicationVersion = 1UI,
            .pEngineName        = engineNamePtr,
            .engineVersion      = 1UI,
            .apiVersion         = (1UI << 22) Or (4UI << 12) Or 0UI  ' Vulkan 1.4
        }

        Dim extensions As String() = {"VK_KHR_surface", "VK_KHR_win32_surface"}
        Dim extPtrs    As IntPtr() = Array.ConvertAll(extensions, Function(s) Marshal.StringToHGlobalAnsi(s))
        Dim extHandle  As GCHandle = GCHandle.Alloc(extPtrs, GCHandleType.Pinned)
        Dim appHandle  As GCHandle = GCHandle.Alloc(appInfo,  GCHandleType.Pinned)

        Try
            Dim ci As New VkInstanceCreateInfo With {
                .sType                   = VkStructureType.VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
                .pApplicationInfo        = appHandle.AddrOfPinnedObject(),
                .enabledExtensionCount   = CUInt(extensions.Length),
                .ppEnabledExtensionNames = extHandle.AddrOfPinnedObject()
            }
            Dim r As VkResult = vkCreateInstance(ci, IntPtr.Zero, instance)
            If r <> VkResult.VK_SUCCESS Then Throw New Exception($"vkCreateInstance failed: {r}")
        Finally
            appHandle.Free()
            extHandle.Free()
            For Each p In extPtrs : Marshal.FreeHGlobal(p) : Next
            Marshal.FreeHGlobal(appNamePtr)
            Marshal.FreeHGlobal(engineNamePtr)
        End Try
    End Sub

    ' --------------------------------------------------------------------------------------------------------
    ' Create Win32 Surface
    ' --------------------------------------------------------------------------------------------------------
    Private Sub CreateSurface()
        Dim ci As New VkWin32SurfaceCreateInfoKHR With {
            .sType     = VkStructureType.VK_STRUCTURE_TYPE_WIN32_SURFACE_CREATE_INFO_KHR,
            .hinstance = GetModuleHandle(Nothing),
            .hwnd      = Me.Handle
        }
        Dim r As VkResult = vkCreateWin32SurfaceKHR(instance, ci, IntPtr.Zero, surface)
        If r <> VkResult.VK_SUCCESS Then Throw New Exception($"vkCreateWin32SurfaceKHR failed: {r}")
    End Sub

    ' --------------------------------------------------------------------------------------------------------
    ' Pick a Physical Device that supports graphics + compute + present on one queue family
    ' --------------------------------------------------------------------------------------------------------
    Private Sub PickPhysicalDevice()
        Dim count As UInteger = 0
        vkEnumeratePhysicalDevices(instance, count, IntPtr.Zero)
        Dim pdBuf(count - 1) As IntPtr
        Dim pdHandle As GCHandle = GCHandle.Alloc(pdBuf, GCHandleType.Pinned)
        vkEnumeratePhysicalDevices(instance, count, pdHandle.AddrOfPinnedObject())
        pdHandle.Free()

        Dim qfpSize As Integer = Marshal.SizeOf(GetType(VkQueueFamilyProperties))

        For Each pd As IntPtr In pdBuf
            Dim qCount As UInteger = 0
            vkGetPhysicalDeviceQueueFamilyProperties(pd, qCount, IntPtr.Zero)

            Dim qBuf As IntPtr = Marshal.AllocHGlobal(CInt(qCount) * qfpSize)
            Try
                vkGetPhysicalDeviceQueueFamilyProperties(pd, qCount, qBuf)
                For i As UInteger = 0 To qCount - 1
                    Dim prop As VkQueueFamilyProperties = Marshal.PtrToStructure(Of VkQueueFamilyProperties)(qBuf + CInt(i) * qfpSize)
                    Dim hasGraphics As Boolean = (prop.queueFlags And VkQueueFlags.VK_QUEUE_GRAPHICS_BIT) <> 0
                    Dim hasCompute  As Boolean = (prop.queueFlags And VkQueueFlags.VK_QUEUE_COMPUTE_BIT) <> 0
                    Dim presentSupported As VkBool32
                    vkGetPhysicalDeviceSurfaceSupportKHR(pd, i, surface, presentSupported)

                    If hasGraphics AndAlso hasCompute AndAlso presentSupported = VkBool32.True Then
                        physicalDevice = pd
                        queueFamily    = i
                        Return
                    End If
                Next
            Finally
                Marshal.FreeHGlobal(qBuf)
            End Try
        Next
        Throw New Exception("No suitable physical device found")
    End Sub

    ' --------------------------------------------------------------------------------------------------------
    ' Create Logical Device
    ' --------------------------------------------------------------------------------------------------------
    Private Sub CreateDevice()
        Dim priority     As Single  = 1.0F
        Dim priHandle    As GCHandle = GCHandle.Alloc(priority, GCHandleType.Pinned)

        Dim queueCI As New VkDeviceQueueCreateInfo With {
            .sType            = VkStructureType.VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
            .queueFamilyIndex = queueFamily,
            .queueCount       = 1UI,
            .pQueuePriorities = priHandle.AddrOfPinnedObject()
        }
        Dim queueHandle As GCHandle = GCHandle.Alloc(queueCI, GCHandleType.Pinned)

        Dim extName    As IntPtr   = Marshal.StringToHGlobalAnsi("VK_KHR_swapchain")
        Dim extPtrArr  As IntPtr() = {extName}
        Dim extHandle  As GCHandle = GCHandle.Alloc(extPtrArr, GCHandleType.Pinned)

        Try
            Dim ci As New VkDeviceCreateInfo With {
                .sType                   = VkStructureType.VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO,
                .queueCreateInfoCount    = 1UI,
                .pQueueCreateInfos       = queueHandle.AddrOfPinnedObject(),
                .enabledExtensionCount   = 1UI,
                .ppEnabledExtensionNames = extHandle.AddrOfPinnedObject()
            }
            Dim r As VkResult = vkCreateDevice(physicalDevice, ci, IntPtr.Zero, device)
            If r <> VkResult.VK_SUCCESS Then Throw New Exception($"vkCreateDevice failed: {r}")
            vkGetDeviceQueue(device, queueFamily, 0UI, queue)
        Finally
            priHandle.Free()
            queueHandle.Free()
            extHandle.Free()
            Marshal.FreeHGlobal(extName)
        End Try
    End Sub

    ' --------------------------------------------------------------------------------------------------------
    ' Create Swapchain
    ' --------------------------------------------------------------------------------------------------------
    Private Sub CreateSwapchain()
        Dim caps As VkSurfaceCapabilitiesKHR
        vkGetPhysicalDeviceSurfaceCapabilitiesKHR(physicalDevice, surface, caps)

        Dim fmtCount As UInteger = 0
        vkGetPhysicalDeviceSurfaceFormatsKHR(physicalDevice, surface, fmtCount, IntPtr.Zero)
        Dim fmtSize   As Integer = Marshal.SizeOf(GetType(VkSurfaceFormatKHR))
        Dim fmtBuf    As IntPtr  = Marshal.AllocHGlobal(CInt(fmtCount) * fmtSize)
        vkGetPhysicalDeviceSurfaceFormatsKHR(physicalDevice, surface, fmtCount, fmtBuf)
        Dim fmt0 As VkSurfaceFormatKHR = Marshal.PtrToStructure(Of VkSurfaceFormatKHR)(fmtBuf)
        Marshal.FreeHGlobal(fmtBuf)

        swapchainFormat = fmt0.format
        swapchainExtent = caps.currentExtent
        If swapchainExtent.width = &HFFFFFFFFUI Then
            swapchainExtent.width  = CUInt(ClientSize.Width)
            swapchainExtent.height = CUInt(ClientSize.Height)
        End If

        Dim imgCount As UInteger = caps.minImageCount + 1UI
        If caps.maxImageCount > 0UI AndAlso imgCount > caps.maxImageCount Then imgCount = caps.maxImageCount

        Dim ci As New VkSwapchainCreateInfoKHR With {
            .sType            = VkStructureType.VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR,
            .surface          = surface,
            .minImageCount    = imgCount,
            .imageFormat      = swapchainFormat,
            .imageColorSpace  = VkColorSpaceKHR.VK_COLOR_SPACE_SRGB_NONLINEAR_KHR,
            .imageExtent      = swapchainExtent,
            .imageArrayLayers = 1UI,
            .imageUsage       = VkImageUsageFlags.VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT,
            .imageSharingMode = VkSharingMode.VK_SHARING_MODE_EXCLUSIVE,
            .preTransform     = caps.currentTransform,
            .compositeAlpha   = VkCompositeAlphaFlagsKHR.VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR,
            .presentMode      = VkPresentModeKHR.VK_PRESENT_MODE_FIFO_KHR,
            .clipped          = VkBool32.True
        }
        vkCreateSwapchainKHR(device, ci, IntPtr.Zero, swapchain)

        ' Retrieve swapchain images
        Dim scCount As UInteger = 0
        vkGetSwapchainImagesKHR(device, swapchain, scCount, IntPtr.Zero)
        swapchainImages = New IntPtr(scCount - 1) {}
        Dim imgHandle As GCHandle = GCHandle.Alloc(swapchainImages, GCHandleType.Pinned)
        vkGetSwapchainImagesKHR(device, swapchain, scCount, imgHandle.AddrOfPinnedObject())
        imgHandle.Free()

        ' Create image views
        swapchainImageViews = New IntPtr(scCount - 1) {}
        For i As Integer = 0 To CInt(scCount) - 1
            Dim vci As New VkImageViewCreateInfo With {
                .sType    = VkStructureType.VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO,
                .image    = swapchainImages(i),
                .viewType = VkImageViewType.VK_IMAGE_VIEW_TYPE_2D,
                .format   = swapchainFormat,
                .subresourceRange = New VkImageSubresourceRange With {
                    .aspectMask = VkImageAspectFlags.VK_IMAGE_ASPECT_COLOR_BIT,
                    .levelCount = 1UI,
                    .layerCount = 1UI
                }
            }
            vkCreateImageView(device, vci, IntPtr.Zero, swapchainImageViews(i))
        Next
    End Sub

    ' --------------------------------------------------------------------------------------------------------
    ' Create Render Pass (single color attachment, no depth)
    ' --------------------------------------------------------------------------------------------------------
    Private Sub CreateRenderPass()
        Dim attachment As New VkAttachmentDescription With {
            .format        = swapchainFormat,
            .samples       = VkSampleCountFlags.VK_SAMPLE_COUNT_1_BIT,
            .loadOp        = VkAttachmentLoadOp.VK_ATTACHMENT_LOAD_OP_CLEAR,
            .storeOp       = VkAttachmentStoreOp.VK_ATTACHMENT_STORE_OP_STORE,
            .initialLayout = VkImageLayout.VK_IMAGE_LAYOUT_UNDEFINED,
            .finalLayout   = VkImageLayout.VK_IMAGE_LAYOUT_PRESENT_SRC_KHR
        }
        Dim attachHandle As GCHandle = GCHandle.Alloc(attachment, GCHandleType.Pinned)

        Dim colorRef As New VkAttachmentReference With {
            .attachment = 0UI,
            .layout     = VkImageLayout.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL
        }
        Dim refHandle As GCHandle = GCHandle.Alloc(colorRef, GCHandleType.Pinned)

        Dim subpass As New VkSubpassDescription With {
            .pipelineBindPoint    = VkPipelineBindPoint.VK_PIPELINE_BIND_POINT_GRAPHICS,
            .colorAttachmentCount = 1UI,
            .pColorAttachments    = refHandle.AddrOfPinnedObject()
        }
        Dim subHandle As GCHandle = GCHandle.Alloc(subpass, GCHandleType.Pinned)

        Dim rpci As New VkRenderPassCreateInfo With {
            .sType           = VkStructureType.VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO,
            .attachmentCount = 1UI,
            .pAttachments    = attachHandle.AddrOfPinnedObject(),
            .subpassCount    = 1UI,
            .pSubpasses      = subHandle.AddrOfPinnedObject()
        }
        vkCreateRenderPass(device, rpci, IntPtr.Zero, renderPass)

        attachHandle.Free()
        refHandle.Free()
        subHandle.Free()
    End Sub

    ' --------------------------------------------------------------------------------------------------------
    ' Descriptor Set Layout
    '   binding 0 = pos  (SSBO, compute + vertex)
    '   binding 1 = col  (SSBO, compute + vertex)
    '   binding 2 = UBO  (params, compute only)
    ' --------------------------------------------------------------------------------------------------------
    Private Sub CreateDescriptorSetLayout()
        Dim bindings As VkDescriptorSetLayoutBinding() = {
            New VkDescriptorSetLayoutBinding With {
                .binding         = 0UI,
                .descriptorType  = VkDescriptorType.VK_DESCRIPTOR_TYPE_STORAGE_BUFFER,
                .descriptorCount = 1UI,
                .stageFlags      = VkShaderStageFlags.VK_SHADER_STAGE_COMPUTE_BIT Or VkShaderStageFlags.VK_SHADER_STAGE_VERTEX_BIT
            },
            New VkDescriptorSetLayoutBinding With {
                .binding         = 1UI,
                .descriptorType  = VkDescriptorType.VK_DESCRIPTOR_TYPE_STORAGE_BUFFER,
                .descriptorCount = 1UI,
                .stageFlags      = VkShaderStageFlags.VK_SHADER_STAGE_COMPUTE_BIT Or VkShaderStageFlags.VK_SHADER_STAGE_VERTEX_BIT
            },
            New VkDescriptorSetLayoutBinding With {
                .binding         = 2UI,
                .descriptorType  = VkDescriptorType.VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER,
                .descriptorCount = 1UI,
                .stageFlags      = VkShaderStageFlags.VK_SHADER_STAGE_COMPUTE_BIT
            }
        }
        Dim bindHandle As GCHandle = GCHandle.Alloc(bindings, GCHandleType.Pinned)

        Dim ci As New VkDescriptorSetLayoutCreateInfo With {
            .sType        = VkStructureType.VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
            .bindingCount = CUInt(bindings.Length),
            .pBindings    = bindHandle.AddrOfPinnedObject()
        }
        vkCreateDescriptorSetLayout(device, ci, IntPtr.Zero, descriptorSetLayout)
        bindHandle.Free()
    End Sub

    ' --------------------------------------------------------------------------------------------------------
    ' Create GPU Buffers (pos, col as device-local SSBO; ubo as host-visible UBO)
    ' --------------------------------------------------------------------------------------------------------
    Private Sub CreateBuffers()
        Dim posSize As ULong = CULng(VERTEX_COUNT) * 16UL
        Dim colSize As ULong = CULng(VERTEX_COUNT) * 16UL
        Dim uboSize As ULong = CULng(Marshal.SizeOf(GetType(ParamsUBO)))

        Dim posResult As (buf As IntPtr, mem As IntPtr) = CreateBuffer(posSize, VkBufferUsageFlags.VK_BUFFER_USAGE_STORAGE_BUFFER_BIT, VkMemoryPropertyFlags.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT)
        posBuffer = posResult.buf : posMemory = posResult.mem

        Dim colResult As (buf As IntPtr, mem As IntPtr) = CreateBuffer(colSize, VkBufferUsageFlags.VK_BUFFER_USAGE_STORAGE_BUFFER_BIT, VkMemoryPropertyFlags.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT)
        colBuffer = colResult.buf : colMemory = colResult.mem

        Dim uboResult As (buf As IntPtr, mem As IntPtr) = CreateBuffer(uboSize, VkBufferUsageFlags.VK_BUFFER_USAGE_UNIFORM_BUFFER_BIT, VkMemoryPropertyFlags.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT Or VkMemoryPropertyFlags.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT)
        uboBuffer = uboResult.buf : uboMemory = uboResult.mem
    End Sub

    Private Function CreateBuffer(ByVal size As ULong, ByVal usage As VkBufferUsageFlags, ByVal memProps As VkMemoryPropertyFlags) As (IntPtr, IntPtr)
        Dim bci As New VkBufferCreateInfo With {
            .sType       = VkStructureType.VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO,
            .size        = size,
            .usage       = usage,
            .sharingMode = VkSharingMode.VK_SHARING_MODE_EXCLUSIVE
        }
        Dim buf As IntPtr
        vkCreateBuffer(device, bci, IntPtr.Zero, buf)

        Dim req As VkMemoryRequirements
        vkGetBufferMemoryRequirements(device, buf, req)

        Dim mai As New VkMemoryAllocateInfo With {
            .sType           = VkStructureType.VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
            .allocationSize  = req.size,
            .memoryTypeIndex = FindMemoryType(req.memoryTypeBits, memProps)
        }
        Dim mem As IntPtr
        vkAllocateMemory(device, mai, IntPtr.Zero, mem)
        vkBindBufferMemory(device, buf, mem, 0UL)
        Return (buf, mem)
    End Function

    Private Function FindMemoryType(ByVal typeFilter As UInteger, ByVal properties As VkMemoryPropertyFlags) As UInteger
        ' Pre-allocate managed arrays inside the struct before passing ByRef
        Dim memProps As New VkPhysicalDeviceMemoryProperties With {
            .memoryTypes = New VkMemoryType(31) {},
            .memoryHeaps = New VkMemoryHeap(15) {}
        }
        vkGetPhysicalDeviceMemoryProperties(physicalDevice, memProps)

        For i As UInteger = 0UI To memProps.memoryTypeCount - 1UI
            If (typeFilter And (1UI << CInt(i))) <> 0UI AndAlso (memProps.memoryTypes(CInt(i)).propertyFlags And properties) = properties Then
                Return i
            End If
        Next
        Throw New Exception("No suitable memory type found")
    End Function

    ' --------------------------------------------------------------------------------------------------------
    ' Create Descriptor Pool
    ' --------------------------------------------------------------------------------------------------------
    Private Sub CreateDescriptorPool()
        Dim poolSizes As VkDescriptorPoolSize() = {
            New VkDescriptorPoolSize With {.type = VkDescriptorType.VK_DESCRIPTOR_TYPE_STORAGE_BUFFER, .descriptorCount = 2UI},
            New VkDescriptorPoolSize With {.type = VkDescriptorType.VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER, .descriptorCount = 1UI}
        }
        Dim pHandle As GCHandle = GCHandle.Alloc(poolSizes, GCHandleType.Pinned)

        Dim ci As New VkDescriptorPoolCreateInfo With {
            .sType         = VkStructureType.VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO,
            .maxSets       = 1UI,
            .poolSizeCount = CUInt(poolSizes.Length),
            .pPoolSizes    = pHandle.AddrOfPinnedObject()
        }
        vkCreateDescriptorPool(device, ci, IntPtr.Zero, descriptorPool)
        pHandle.Free()
    End Sub

    ' --------------------------------------------------------------------------------------------------------
    ' Allocate and Update Descriptor Set
    ' --------------------------------------------------------------------------------------------------------
    Private Sub CreateDescriptorSet()
        Dim layoutHandle As GCHandle = GCHandle.Alloc(descriptorSetLayout, GCHandleType.Pinned)
        Dim ai As New VkDescriptorSetAllocateInfo With {
            .sType              = VkStructureType.VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO,
            .descriptorPool     = descriptorPool,
            .descriptorSetCount = 1UI,
            .pSetLayouts        = layoutHandle.AddrOfPinnedObject()
        }
        vkAllocateDescriptorSets(device, ai, descriptorSet)
        layoutHandle.Free()

        Dim posInfo As New VkDescriptorBufferInfo With {.buffer = posBuffer, .offset = 0UL, .range = CULng(VERTEX_COUNT) * 16UL}
        Dim colInfo As New VkDescriptorBufferInfo With {.buffer = colBuffer, .offset = 0UL, .range = CULng(VERTEX_COUNT) * 16UL}
        Dim uboInfo As New VkDescriptorBufferInfo With {.buffer = uboBuffer, .offset = 0UL, .range = CULng(Marshal.SizeOf(GetType(ParamsUBO)))}

        Dim piH As GCHandle = GCHandle.Alloc(posInfo, GCHandleType.Pinned)
        Dim ciH As GCHandle = GCHandle.Alloc(colInfo, GCHandleType.Pinned)
        Dim uiH As GCHandle = GCHandle.Alloc(uboInfo, GCHandleType.Pinned)

        Dim writes As VkWriteDescriptorSet() = {
            New VkWriteDescriptorSet With {.sType = VkStructureType.VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET, .dstSet = descriptorSet, .dstBinding = 0UI, .descriptorCount = 1UI, .descriptorType = VkDescriptorType.VK_DESCRIPTOR_TYPE_STORAGE_BUFFER, .pBufferInfo = piH.AddrOfPinnedObject()},
            New VkWriteDescriptorSet With {.sType = VkStructureType.VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET, .dstSet = descriptorSet, .dstBinding = 1UI, .descriptorCount = 1UI, .descriptorType = VkDescriptorType.VK_DESCRIPTOR_TYPE_STORAGE_BUFFER, .pBufferInfo = ciH.AddrOfPinnedObject()},
            New VkWriteDescriptorSet With {.sType = VkStructureType.VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET, .dstSet = descriptorSet, .dstBinding = 2UI, .descriptorCount = 1UI, .descriptorType = VkDescriptorType.VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER, .pBufferInfo = uiH.AddrOfPinnedObject()}
        }
        Dim wHandle As GCHandle = GCHandle.Alloc(writes, GCHandleType.Pinned)
        vkUpdateDescriptorSets(device, CUInt(writes.Length), wHandle.AddrOfPinnedObject(), 0UI, IntPtr.Zero)

        wHandle.Free() : piH.Free() : ciH.Free() : uiH.Free()
    End Sub

    ' --------------------------------------------------------------------------------------------------------
    ' Compile Shaders from project files (hello.comp / hello.vert / hello.frag)
    ' --------------------------------------------------------------------------------------------------------
    Private Sub CompileShaders()
        ' Look for shader files next to the executable; fall back to the current directory
        Dim baseDirs As String() = {
            AppDomain.CurrentDomain.BaseDirectory,
            System.IO.Directory.GetCurrentDirectory()
        }

        Dim compSrc As String = LoadShaderSource(baseDirs, "hello.comp")
        Dim vertSrc As String = LoadShaderSource(baseDirs, "hello.vert")
        Dim fragSrc As String = LoadShaderSource(baseDirs, "hello.frag")

        compShaderModule = CreateShaderModule(ShaderCompiler.Compile(compSrc, ShaderCompiler.ShaderKind.Compute,  "hello.comp"))
        vertShaderModule = CreateShaderModule(ShaderCompiler.Compile(vertSrc, ShaderCompiler.ShaderKind.Vertex,   "hello.vert"))
        fragShaderModule = CreateShaderModule(ShaderCompiler.Compile(fragSrc, ShaderCompiler.ShaderKind.Fragment, "hello.frag"))
    End Sub

    ''' <summary>
    ''' Search a list of directories for a shader file and return its contents.
    ''' Throws if the file cannot be found in any of the provided directories.
    ''' </summary>
    Private Shared Function LoadShaderSource(ByVal baseDirs As String(), ByVal fileName As String) As String
        For Each dir As String In baseDirs
            Dim fullPath As String = System.IO.Path.Combine(dir, fileName)
            If System.IO.File.Exists(fullPath) Then
                Return System.IO.File.ReadAllText(fullPath, Encoding.UTF8)
            End If
        Next
        Throw New System.IO.FileNotFoundException($"Shader file not found: {fileName}. " &
                                                  "Place hello.comp, hello.vert, and hello.frag " &
                                                  "in the same directory as the executable.")
    End Function

    Private Function CreateShaderModule(ByVal code As Byte()) As IntPtr
        Dim codeHandle As GCHandle = GCHandle.Alloc(code, GCHandleType.Pinned)
        Dim ci As New VkShaderModuleCreateInfo With {
            .sType    = VkStructureType.VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO,
            .codeSize = CType(code.Length, UIntPtr),
            .pCode    = codeHandle.AddrOfPinnedObject()
        }
        Dim sm As IntPtr
        vkCreateShaderModule(device, ci, IntPtr.Zero, sm)
        codeHandle.Free()
        Return sm
    End Function

    ' --------------------------------------------------------------------------------------------------------
    ' Create Compute Pipeline
    ' --------------------------------------------------------------------------------------------------------
    Private Sub CreateComputePipeline()
        Dim layoutHandle As GCHandle = GCHandle.Alloc(descriptorSetLayout, GCHandleType.Pinned)
        Dim lci As New VkPipelineLayoutCreateInfo With {
            .sType        = VkStructureType.VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO,
            .setLayoutCount = 1UI,
            .pSetLayouts  = layoutHandle.AddrOfPinnedObject()
        }
        vkCreatePipelineLayout(device, lci, IntPtr.Zero, computePipelineLayout)
        layoutHandle.Free()

        Dim mainPtr As IntPtr = Marshal.StringToHGlobalAnsi("main")
        Dim pci As New VkComputePipelineCreateInfo With {
            .sType = VkStructureType.VK_STRUCTURE_TYPE_COMPUTE_PIPELINE_CREATE_INFO,
            .stage = New VkPipelineShaderStageCreateInfo With {
                .sType  = VkStructureType.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
                .stage  = VkShaderStageFlags.VK_SHADER_STAGE_COMPUTE_BIT,
                .module = compShaderModule,
                .pName  = mainPtr
            },
            .layout             = computePipelineLayout,
            .basePipelineIndex  = -1
        }
        vkCreateComputePipelines(device, IntPtr.Zero, 1UI, pci, IntPtr.Zero, computePipeline)
        Marshal.FreeHGlobal(mainPtr)
    End Sub

    ' --------------------------------------------------------------------------------------------------------
    ' Create Graphics Pipeline (LINE_STRIP, no vertex buffers – positions come from SSBO)
    ' --------------------------------------------------------------------------------------------------------
    Private Sub CreateGraphicsPipeline()
        Dim layoutHandle As GCHandle = GCHandle.Alloc(descriptorSetLayout, GCHandleType.Pinned)
        Dim lci As New VkPipelineLayoutCreateInfo With {
            .sType        = VkStructureType.VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO,
            .setLayoutCount = 1UI,
            .pSetLayouts  = layoutHandle.AddrOfPinnedObject()
        }
        vkCreatePipelineLayout(device, lci, IntPtr.Zero, graphicsPipelineLayout)
        layoutHandle.Free()

        Dim mainPtr As IntPtr = Marshal.StringToHGlobalAnsi("main")
        Dim stages As VkPipelineShaderStageCreateInfo() = {
            New VkPipelineShaderStageCreateInfo With {.sType = VkStructureType.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO, .stage = VkShaderStageFlags.VK_SHADER_STAGE_VERTEX_BIT,   .module = vertShaderModule, .pName = mainPtr},
            New VkPipelineShaderStageCreateInfo With {.sType = VkStructureType.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO, .stage = VkShaderStageFlags.VK_SHADER_STAGE_FRAGMENT_BIT, .module = fragShaderModule, .pName = mainPtr}
        }
        Dim stagesHandle As GCHandle = GCHandle.Alloc(stages, GCHandleType.Pinned)

        Dim vertexInput  As New VkPipelineVertexInputStateCreateInfo  With {.sType = VkStructureType.VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO}
        Dim inputAssembly As New VkPipelineInputAssemblyStateCreateInfo With {.sType = VkStructureType.VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO, .topology = VkPrimitiveTopology.VK_PRIMITIVE_TOPOLOGY_LINE_STRIP}

        Dim viewport As New VkViewport With {.x = 0, .y = 0, .width = swapchainExtent.width, .height = swapchainExtent.height, .minDepth = 0, .maxDepth = 1}
        Dim scissor  As New VkRect2D  With {.extent = swapchainExtent}
        Dim vpHandle  As GCHandle = GCHandle.Alloc(viewport, GCHandleType.Pinned)
        Dim scHandle  As GCHandle = GCHandle.Alloc(scissor,  GCHandleType.Pinned)

        Dim viewportState As New VkPipelineViewportStateCreateInfo With {
            .sType         = VkStructureType.VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO,
            .viewportCount = 1UI, .pViewports = vpHandle.AddrOfPinnedObject(),
            .scissorCount  = 1UI, .pScissors  = scHandle.AddrOfPinnedObject()
        }
        Dim rasterizer As New VkPipelineRasterizationStateCreateInfo With {
            .sType     = VkStructureType.VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO,
            .polygonMode = VkPolygonMode.VK_POLYGON_MODE_FILL,
            .cullMode  = VkCullModeFlags.VK_CULL_MODE_NONE,
            .frontFace = VkFrontFace.VK_FRONT_FACE_COUNTER_CLOCKWISE,
            .lineWidth = 1.0F
        }
        Dim multisampling As New VkPipelineMultisampleStateCreateInfo With {
            .sType                = VkStructureType.VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO,
            .rasterizationSamples = VkSampleCountFlags.VK_SAMPLE_COUNT_1_BIT
        }
        Dim colorBlendAtt As New VkPipelineColorBlendAttachmentState With {
            .colorWriteMask = VkColorComponentFlags.VK_COLOR_COMPONENT_R_BIT Or
                              VkColorComponentFlags.VK_COLOR_COMPONENT_G_BIT Or
                              VkColorComponentFlags.VK_COLOR_COMPONENT_B_BIT Or
                              VkColorComponentFlags.VK_COLOR_COMPONENT_A_BIT
        }
        Dim cbaHandle As GCHandle = GCHandle.Alloc(colorBlendAtt, GCHandleType.Pinned)
        Dim colorBlend As New VkPipelineColorBlendStateCreateInfo With {
            .sType           = VkStructureType.VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO,
            .attachmentCount = 1UI,
            .pAttachments    = cbaHandle.AddrOfPinnedObject()
        }

        ' Pin sub-states so we can pass their addresses to VkGraphicsPipelineCreateInfo
        Dim viH  As GCHandle = GCHandle.Alloc(vertexInput,   GCHandleType.Pinned)
        Dim iaH  As GCHandle = GCHandle.Alloc(inputAssembly, GCHandleType.Pinned)
        Dim vsH  As GCHandle = GCHandle.Alloc(viewportState, GCHandleType.Pinned)
        Dim rsH  As GCHandle = GCHandle.Alloc(rasterizer,    GCHandleType.Pinned)
        Dim msH  As GCHandle = GCHandle.Alloc(multisampling, GCHandleType.Pinned)
        Dim cbH  As GCHandle = GCHandle.Alloc(colorBlend,    GCHandleType.Pinned)

        Dim pipelineCI As New VkGraphicsPipelineCreateInfo With {
            .sType               = VkStructureType.VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO,
            .stageCount          = 2UI,
            .pStages             = stagesHandle.AddrOfPinnedObject(),
            .pVertexInputState   = viH.AddrOfPinnedObject(),
            .pInputAssemblyState = iaH.AddrOfPinnedObject(),
            .pViewportState      = vsH.AddrOfPinnedObject(),
            .pRasterizationState = rsH.AddrOfPinnedObject(),
            .pMultisampleState   = msH.AddrOfPinnedObject(),
            .pColorBlendState    = cbH.AddrOfPinnedObject(),
            .layout              = graphicsPipelineLayout,
            .renderPass          = renderPass,
            .basePipelineIndex   = -1
        }
        Dim pciHandle As GCHandle = GCHandle.Alloc(pipelineCI, GCHandleType.Pinned)
        vkCreateGraphicsPipelines(device, IntPtr.Zero, 1UI, pciHandle.AddrOfPinnedObject(), IntPtr.Zero, graphicsPipeline)

        pciHandle.Free() : stagesHandle.Free()
        vpHandle.Free() : scHandle.Free()
        cbaHandle.Free()
        viH.Free() : iaH.Free() : vsH.Free() : rsH.Free() : msH.Free() : cbH.Free()
        Marshal.FreeHGlobal(mainPtr)
    End Sub

    ' --------------------------------------------------------------------------------------------------------
    ' Create Framebuffers (one per swapchain image)
    ' --------------------------------------------------------------------------------------------------------
    Private Sub CreateFramebuffers()
        framebuffers = New IntPtr(swapchainImageViews.Length - 1) {}
        For i As Integer = 0 To swapchainImageViews.Length - 1
            Dim ivHandle As GCHandle = GCHandle.Alloc(swapchainImageViews(i), GCHandleType.Pinned)
            Dim fbci As New VkFramebufferCreateInfo With {
                .sType           = VkStructureType.VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO,
                .renderPass      = renderPass,
                .attachmentCount = 1UI,
                .pAttachments    = ivHandle.AddrOfPinnedObject(),
                .width           = swapchainExtent.width,
                .height          = swapchainExtent.height,
                .layers          = 1UI
            }
            vkCreateFramebuffer(device, fbci, IntPtr.Zero, framebuffers(i))
            ivHandle.Free()
        Next
    End Sub

    ' --------------------------------------------------------------------------------------------------------
    ' Create Command Pool and Command Buffers (one per frame-in-flight)
    ' --------------------------------------------------------------------------------------------------------
    Private Sub CreateCommandPool()
        Dim cpci As New VkCommandPoolCreateInfo With {
            .sType            = VkStructureType.VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO,
            .flags            = VkCommandPoolCreateFlags.VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT,
            .queueFamilyIndex = queueFamily
        }
        vkCreateCommandPool(device, cpci, IntPtr.Zero, commandPool)
    End Sub

    Private Sub CreateCommandBuffers()
        commandBuffers = New IntPtr(MAX_FRAMES_IN_FLIGHT - 1) {}
        Dim cbai As New VkCommandBufferAllocateInfo With {
            .sType              = VkStructureType.VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
            .commandPool        = commandPool,
            .level              = VkCommandBufferLevel.VK_COMMAND_BUFFER_LEVEL_PRIMARY,
            .commandBufferCount = CUInt(MAX_FRAMES_IN_FLIGHT)
        }
        Dim cbHandle As GCHandle = GCHandle.Alloc(commandBuffers, GCHandleType.Pinned)
        vkAllocateCommandBuffers(device, cbai, cbHandle.AddrOfPinnedObject())
        cbHandle.Free()
    End Sub

    ' --------------------------------------------------------------------------------------------------------
    ' Create Synchronization Objects (semaphores and fences)
    ' --------------------------------------------------------------------------------------------------------
    Private Sub CreateSyncObjects()
        imageAvailableSemaphores = New IntPtr(MAX_FRAMES_IN_FLIGHT - 1) {}
        renderFinishedSemaphores = New IntPtr(MAX_FRAMES_IN_FLIGHT - 1) {}
        inFlightFences           = New IntPtr(MAX_FRAMES_IN_FLIGHT - 1) {}

        Dim semCI   As New VkSemaphoreCreateInfo With {.sType = VkStructureType.VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO}
        Dim fenceCI As New VkFenceCreateInfo     With {.sType = VkStructureType.VK_STRUCTURE_TYPE_FENCE_CREATE_INFO, .flags = VkFenceCreateFlags.VK_FENCE_CREATE_SIGNALED_BIT}

        For i As Integer = 0 To MAX_FRAMES_IN_FLIGHT - 1
            vkCreateSemaphore(device, semCI, IntPtr.Zero, imageAvailableSemaphores(i))
            vkCreateSemaphore(device, semCI, IntPtr.Zero, renderFinishedSemaphores(i))
            vkCreateFence(device, fenceCI, IntPtr.Zero, inFlightFences(i))
        Next
    End Sub

    ' --------------------------------------------------------------------------------------------------------
    ' Initialize the UBO with harmonograph parameters
    ' --------------------------------------------------------------------------------------------------------
    Private Sub InitUBO()
        uboParams = New ParamsUBO With {
            .max_num = VERTEX_COUNT,
            .dt      = 0.001F,
            .scale   = 0.02F,
            .A1 = 50.0F, .f1 = 2.0F, .p1 = 1.0F / 16.0F, .d1 = 0.02F,
            .A2 = 50.0F, .f2 = 2.0F, .p2 = 3.0F / 2.0F,  .d2 = 0.0315F,
            .A3 = 50.0F, .f3 = 2.0F, .p3 = 13.0F / 15.0F, .d3 = 0.02F,
            .A4 = 50.0F, .f4 = 2.0F, .p4 = 1.0F,          .d4 = 0.02F
        }
    End Sub

    ' --------------------------------------------------------------------------------------------------------
    ' Update UBO each frame (animates frequencies and phase)
    ' --------------------------------------------------------------------------------------------------------
    Private Sub UpdateUBO()
        animTime      += 0.016F
        uboParams.f1   = 2.0F + 0.5F * CSng(Math.Sin(animTime * 0.7))
        uboParams.f2   = 2.0F + 0.5F * CSng(Math.Sin(animTime * 0.9))
        uboParams.f3   = 2.0F + 0.5F * CSng(Math.Sin(animTime * 1.1))
        uboParams.f4   = 2.0F + 0.5F * CSng(Math.Sin(animTime * 1.3))
        uboParams.p1  += 0.002F

        ' Map → write → unmap (host-coherent memory, no explicit flush needed)
        Dim dataPtr As IntPtr
        vkMapMemory(device, uboMemory, 0UL, CULng(Marshal.SizeOf(GetType(ParamsUBO))), 0UI, dataPtr)
        Marshal.StructureToPtr(uboParams, dataPtr, False)
        vkUnmapMemory(device, uboMemory)
    End Sub

    ' --------------------------------------------------------------------------------------------------------
    ' Draw Frame – compute dispatch → barrier → render pass
    ' --------------------------------------------------------------------------------------------------------
    Private Sub DrawFrame()
        Dim cur As Integer = frameIndex Mod MAX_FRAMES_IN_FLIGHT

        vkWaitForFences(device, 1UI, inFlightFences(cur), VkBool32.True, ULong.MaxValue)
        vkResetFences(device, 1UI, inFlightFences(cur))

        Dim imageIndex As UInteger = 0UI
        Dim r As VkResult = vkAcquireNextImageKHR(device, swapchain, ULong.MaxValue, imageAvailableSemaphores(cur), IntPtr.Zero, imageIndex)
        If r = VkResult.VK_ERROR_OUT_OF_DATE_KHR Then RecreateSwapchain() : Return

        UpdateUBO()

        Dim cmd As IntPtr = commandBuffers(cur)
        vkResetCommandBuffer(cmd, 0UI)

        Dim beginInfo As New VkCommandBufferBeginInfo With {.sType = VkStructureType.VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO}
        vkBeginCommandBuffer(cmd, beginInfo)

        ' --- Compute pass ---
        vkCmdBindPipeline(cmd, VkPipelineBindPoint.VK_PIPELINE_BIND_POINT_COMPUTE, computePipeline)
        vkCmdBindDescriptorSets(cmd, VkPipelineBindPoint.VK_PIPELINE_BIND_POINT_COMPUTE, computePipelineLayout, 0UI, 1UI, descriptorSet, 0UI, IntPtr.Zero)
        vkCmdDispatch(cmd, (VERTEX_COUNT + 255UI) \ 256UI, 1UI, 1UI)

        ' --- Barrier: ensure compute writes are visible to the vertex shader ---
        Dim barriers As VkBufferMemoryBarrier() = {
            New VkBufferMemoryBarrier With {
                .sType               = CUInt(VkStructureType.VK_STRUCTURE_TYPE_BUFFER_MEMORY_BARRIER),
                .srcAccessMask       = CUInt(VkAccessFlags.VK_ACCESS_SHADER_WRITE_BIT),
                .dstAccessMask       = CUInt(VkAccessFlags.VK_ACCESS_SHADER_READ_BIT),
                .srcQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED,
                .dstQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED,
                .buffer              = posBuffer,
                .size                = CULng(VERTEX_COUNT) * 16UL
            },
            New VkBufferMemoryBarrier With {
                .sType               = CUInt(VkStructureType.VK_STRUCTURE_TYPE_BUFFER_MEMORY_BARRIER),
                .srcAccessMask       = CUInt(VkAccessFlags.VK_ACCESS_SHADER_WRITE_BIT),
                .dstAccessMask       = CUInt(VkAccessFlags.VK_ACCESS_SHADER_READ_BIT),
                .srcQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED,
                .dstQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED,
                .buffer              = colBuffer,
                .size                = CULng(VERTEX_COUNT) * 16UL
            }
        }
        Dim barrierHandle As GCHandle = GCHandle.Alloc(barriers, GCHandleType.Pinned)
        vkCmdPipelineBarrier(cmd,
                             VkPipelineStageFlags.VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT,
                             VkPipelineStageFlags.VK_PIPELINE_STAGE_VERTEX_SHADER_BIT,
                             0UI, 0UI, IntPtr.Zero,
                             CUInt(barriers.Length), barrierHandle.AddrOfPinnedObject(),
                             0UI, IntPtr.Zero)
        barrierHandle.Free()

        ' --- Render pass ---
        Dim clearValues As VkClearValue() = {New VkClearValue With {.color = New VkClearColorValue With {.r = 0.0F, .g = 0.0F, .b = 0.0F, .a = 1.0F}}}
        Dim clearHandle As GCHandle = GCHandle.Alloc(clearValues, GCHandleType.Pinned)

        Dim rpBeginInfo As New VkRenderPassBeginInfo With {
            .sType           = VkStructureType.VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO,
            .renderPass      = renderPass,
            .framebuffer     = framebuffers(imageIndex),
            .renderArea      = New VkRect2D With {.extent = swapchainExtent},
            .clearValueCount = 1UI,
            .pClearValues    = clearHandle.AddrOfPinnedObject()
        }
        vkCmdBeginRenderPass(cmd, rpBeginInfo, VkSubpassContents.VK_SUBPASS_CONTENTS_INLINE)
        clearHandle.Free()

        vkCmdBindPipeline(cmd, VkPipelineBindPoint.VK_PIPELINE_BIND_POINT_GRAPHICS, graphicsPipeline)
        vkCmdBindDescriptorSets(cmd, VkPipelineBindPoint.VK_PIPELINE_BIND_POINT_GRAPHICS, graphicsPipelineLayout, 0UI, 1UI, descriptorSet, 0UI, IntPtr.Zero)
        vkCmdDraw(cmd, VERTEX_COUNT, 1UI, 0UI, 0UI)

        vkCmdEndRenderPass(cmd)
        vkEndCommandBuffer(cmd)

        ' --- Submit ---
        Dim waitStages    As UInteger()  = {CUInt(VkPipelineStageFlags.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT)}
        Dim waitStageH    As GCHandle    = GCHandle.Alloc(waitStages, GCHandleType.Pinned)
        Dim cmdBufs       As IntPtr()    = {cmd}
        Dim cmdBufH       As GCHandle    = GCHandle.Alloc(cmdBufs, GCHandleType.Pinned)

        Dim submitInfo As New VkSubmitInfo With {
            .sType                = VkStructureType.VK_STRUCTURE_TYPE_SUBMIT_INFO,
            .waitSemaphoreCount   = 1UI,
            .pWaitSemaphores      = Marshal.UnsafeAddrOfPinnedArrayElement(imageAvailableSemaphores, cur),
            .pWaitDstStageMask    = waitStageH.AddrOfPinnedObject(),
            .commandBufferCount   = 1UI,
            .pCommandBuffers      = cmdBufH.AddrOfPinnedObject(),
            .signalSemaphoreCount = 1UI,
            .pSignalSemaphores    = Marshal.UnsafeAddrOfPinnedArrayElement(renderFinishedSemaphores, cur)
        }
        vkQueueSubmit(queue, 1UI, submitInfo, inFlightFences(cur))
        waitStageH.Free() : cmdBufH.Free()

        ' --- Present ---
        Dim swapchains   As IntPtr()  = {swapchain}
        Dim imgIndices   As UInteger() = {imageIndex}
        Dim scH          As GCHandle  = GCHandle.Alloc(swapchains, GCHandleType.Pinned)
        Dim idxH         As GCHandle  = GCHandle.Alloc(imgIndices, GCHandleType.Pinned)

        Dim presentInfo As New VkPresentInfoKHR With {
            .sType              = VkStructureType.VK_STRUCTURE_TYPE_PRESENT_INFO_KHR,
            .waitSemaphoreCount = 1UI,
            .pWaitSemaphores    = Marshal.UnsafeAddrOfPinnedArrayElement(renderFinishedSemaphores, cur),
            .swapchainCount     = 1UI,
            .pSwapchains        = scH.AddrOfPinnedObject(),
            .pImageIndices      = idxH.AddrOfPinnedObject()
        }
        r = vkQueuePresentKHR(queue, presentInfo)
        scH.Free() : idxH.Free()

        If r = VkResult.VK_ERROR_OUT_OF_DATE_KHR OrElse r = VkResult.VK_SUBOPTIMAL_KHR Then
            RecreateSwapchain()
        End If

        frameIndex += 1
    End Sub

    ' --------------------------------------------------------------------------------------------------------
    ' Recreate the swapchain on resize / out-of-date
    ' --------------------------------------------------------------------------------------------------------
    Private Sub RecreateSwapchain()
        vkDeviceWaitIdle(device)

        For Each fb As IntPtr In framebuffers
            vkDestroyFramebuffer(device, fb, IntPtr.Zero)
        Next
        vkDestroyPipeline(device, graphicsPipeline, IntPtr.Zero)
        vkDestroyPipelineLayout(device, graphicsPipelineLayout, IntPtr.Zero)
        For Each iv As IntPtr In swapchainImageViews
            vkDestroyImageView(device, iv, IntPtr.Zero)
        Next
        vkDestroySwapchainKHR(device, swapchain, IntPtr.Zero)

        CreateSwapchain()
        CreateGraphicsPipeline()
        CreateFramebuffers()
    End Sub

    ' --------------------------------------------------------------------------------------------------------
    ' Release all Vulkan resources
    ' --------------------------------------------------------------------------------------------------------
    Private Sub Cleanup()
        vkDeviceWaitIdle(device)

        vkDestroyBuffer(device, posBuffer, IntPtr.Zero)
        vkFreeMemory(device, posMemory, IntPtr.Zero)
        vkDestroyBuffer(device, colBuffer, IntPtr.Zero)
        vkFreeMemory(device, colMemory, IntPtr.Zero)
        vkDestroyBuffer(device, uboBuffer, IntPtr.Zero)
        vkFreeMemory(device, uboMemory, IntPtr.Zero)

        vkDestroyDescriptorPool(device, descriptorPool, IntPtr.Zero)
        vkDestroyDescriptorSetLayout(device, descriptorSetLayout, IntPtr.Zero)

        For i As Integer = 0 To MAX_FRAMES_IN_FLIGHT - 1
            vkDestroySemaphore(device, imageAvailableSemaphores(i), IntPtr.Zero)
            vkDestroySemaphore(device, renderFinishedSemaphores(i), IntPtr.Zero)
            vkDestroyFence(device, inFlightFences(i), IntPtr.Zero)
        Next

        vkDestroyCommandPool(device, commandPool, IntPtr.Zero)

        vkDestroyPipeline(device, computePipeline, IntPtr.Zero)
        vkDestroyPipelineLayout(device, computePipelineLayout, IntPtr.Zero)
        vkDestroyPipeline(device, graphicsPipeline, IntPtr.Zero)
        vkDestroyPipelineLayout(device, graphicsPipelineLayout, IntPtr.Zero)

        vkDestroyShaderModule(device, compShaderModule, IntPtr.Zero)
        vkDestroyShaderModule(device, vertShaderModule, IntPtr.Zero)
        vkDestroyShaderModule(device, fragShaderModule, IntPtr.Zero)

        For Each fb As IntPtr In framebuffers
            vkDestroyFramebuffer(device, fb, IntPtr.Zero)
        Next
        vkDestroyRenderPass(device, renderPass, IntPtr.Zero)
        For Each iv As IntPtr In swapchainImageViews
            vkDestroyImageView(device, iv, IntPtr.Zero)
        Next
        vkDestroySwapchainKHR(device, swapchain, IntPtr.Zero)

        vkDestroyDevice(device, IntPtr.Zero)
        vkDestroySurfaceKHR(instance, surface, IntPtr.Zero)
        vkDestroyInstance(instance, IntPtr.Zero)
    End Sub

    ' --------------------------------------------------------------------------------------------------------
    ' Entry Point
    ' --------------------------------------------------------------------------------------------------------
    <STAThread>
    Shared Sub Main()
        Application.Run(New HarmonographForm())
    End Sub
End Class
