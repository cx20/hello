# Vulkan 1.4 Compute Shader Harmonograph (PowerShell)
# Runtime shader compilation using shaderc_shared.dll

$VulkanCode = @'
using System;
using System.Text;
using System.Drawing;
using System.Windows.Forms;
using System.Runtime.InteropServices;

public static class ShaderCompiler
{
    [DllImport("shaderc_shared.dll", CallingConvention = CallingConvention.Cdecl)]
    public static extern IntPtr shaderc_compiler_initialize();
    [DllImport("shaderc_shared.dll", CallingConvention = CallingConvention.Cdecl)]
    public static extern void shaderc_compiler_release(IntPtr compiler);
    [DllImport("shaderc_shared.dll", CallingConvention = CallingConvention.Cdecl)]
    public static extern IntPtr shaderc_compile_options_initialize();
    [DllImport("shaderc_shared.dll", CallingConvention = CallingConvention.Cdecl)]
    public static extern void shaderc_compile_options_set_target_env(IntPtr options, int target, uint version);
    [DllImport("shaderc_shared.dll", CallingConvention = CallingConvention.Cdecl)]
    public static extern void shaderc_compile_options_release(IntPtr options);
    [DllImport("shaderc_shared.dll", CallingConvention = CallingConvention.Cdecl)]
    public static extern IntPtr shaderc_compile_into_spv(IntPtr compiler, byte[] source, UIntPtr sourceSize, int kind, byte[] inputFileName, byte[] entryPoint, IntPtr options);
    [DllImport("shaderc_shared.dll", CallingConvention = CallingConvention.Cdecl)]
    public static extern void shaderc_result_release(IntPtr result);
    [DllImport("shaderc_shared.dll", CallingConvention = CallingConvention.Cdecl)]
    public static extern UIntPtr shaderc_result_get_length(IntPtr result);
    [DllImport("shaderc_shared.dll", CallingConvention = CallingConvention.Cdecl)]
    public static extern IntPtr shaderc_result_get_bytes(IntPtr result);
    [DllImport("shaderc_shared.dll", CallingConvention = CallingConvention.Cdecl)]
    public static extern int shaderc_result_get_compilation_status(IntPtr result);
    [DllImport("shaderc_shared.dll", CallingConvention = CallingConvention.Cdecl)]
    public static extern IntPtr shaderc_result_get_error_message(IntPtr result);

    public static byte[] Compile(string source, int kind, string fileName)
    {
        IntPtr compiler = shaderc_compiler_initialize();
        IntPtr options = shaderc_compile_options_initialize();
        shaderc_compile_options_set_target_env(options, 0, (1u << 22) | (4u << 12));
        byte[] srcBytes = Encoding.UTF8.GetBytes(source);
        byte[] fileBytes = Encoding.UTF8.GetBytes(fileName + "\0");
        byte[] entryBytes = Encoding.UTF8.GetBytes("main\0");
        IntPtr result = shaderc_compile_into_spv(compiler, srcBytes, (UIntPtr)srcBytes.Length, kind, fileBytes, entryBytes, options);
        int status = shaderc_result_get_compilation_status(result);
        if (status != 0)
        {
            string err = Marshal.PtrToStringAnsi(shaderc_result_get_error_message(result));
            shaderc_result_release(result);
            shaderc_compile_options_release(options);
            shaderc_compiler_release(compiler);
            throw new Exception("Shader compile error: " + err);
        }
        int len = (int)(ulong)shaderc_result_get_length(result);
        byte[] spv = new byte[len];
        Marshal.Copy(shaderc_result_get_bytes(result), spv, 0, len);
        shaderc_result_release(result);
        shaderc_compile_options_release(options);
        shaderc_compiler_release(compiler);
        return spv;
    }
}

public class VulkanHarmonograph : Form
{
    const uint VK_TRUE = 1;
    const uint VK_API_VERSION_1_4 = (1 << 22) | (4 << 12);
    const uint VK_QUEUE_GRAPHICS_BIT = 1;
    const uint VK_QUEUE_COMPUTE_BIT = 2;
    const uint VK_QUEUE_FAMILY_IGNORED = 0xFFFFFFFF;
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
    const uint VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO = 12;
    const uint VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO = 15;
    const uint VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO = 16;
    const uint VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO = 18;
    const uint VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO = 19;
    const uint VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO = 20;
    const uint VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO = 22;
    const uint VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO = 23;
    const uint VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO = 24;
    const uint VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO = 26;
    const uint VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO = 28;
    const uint VK_STRUCTURE_TYPE_COMPUTE_PIPELINE_CREATE_INFO = 29;
    const uint VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO = 30;
    const uint VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO = 32;
    const uint VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO = 33;
    const uint VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO = 34;
    const uint VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET = 35;
    const uint VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO = 37;
    const uint VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO = 38;
    const uint VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO = 39;
    const uint VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO = 40;
    const uint VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO = 42;
    const uint VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO = 43;
    const uint VK_STRUCTURE_TYPE_BUFFER_MEMORY_BARRIER = 44;
    const uint VK_STRUCTURE_TYPE_PRESENT_INFO_KHR = 1000001001;
    const uint VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR = 1000001000;
    const uint VK_STRUCTURE_TYPE_WIN32_SURFACE_CREATE_INFO_KHR = 1000009000;
    const uint VK_IMAGE_LAYOUT_UNDEFINED = 0;
    const uint VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL = 2;
    const uint VK_IMAGE_LAYOUT_PRESENT_SRC_KHR = 1000001002;
    const uint VK_ATTACHMENT_LOAD_OP_CLEAR = 1;
    const uint VK_ATTACHMENT_STORE_OP_STORE = 0;
    const uint VK_PIPELINE_BIND_POINT_GRAPHICS = 0;
    const uint VK_PIPELINE_BIND_POINT_COMPUTE = 1;
    const uint VK_PIPELINE_STAGE_VERTEX_SHADER_BIT = 0x00000008;
    const uint VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT = 0x00000400;
    const uint VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT = 0x00000800;
    const uint VK_ACCESS_SHADER_READ_BIT = 0x00000020;
    const uint VK_ACCESS_SHADER_WRITE_BIT = 0x00000040;
    const uint VK_SUBPASS_EXTERNAL = 0xFFFFFFFF;
    const uint VK_SHADER_STAGE_VERTEX_BIT = 1;
    const uint VK_SHADER_STAGE_FRAGMENT_BIT = 0x10;
    const uint VK_SHADER_STAGE_COMPUTE_BIT = 0x20;
    const uint VK_PRIMITIVE_TOPOLOGY_LINE_STRIP = 2;
    const uint VK_SAMPLE_COUNT_1_BIT = 1;
    const uint VK_FORMAT_B8G8R8A8_UNORM = 44;
    const uint VK_COLOR_SPACE_SRGB_NONLINEAR_KHR = 0;
    const uint VK_PRESENT_MODE_FIFO_KHR = 2;
    const uint VK_SHARING_MODE_EXCLUSIVE = 0;
    const uint VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT = 0x10;
    const uint VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR = 1;
    const uint VK_IMAGE_VIEW_TYPE_2D = 1;
    const uint VK_IMAGE_ASPECT_COLOR_BIT = 1;
    const uint VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT = 2;
    const uint VK_COMMAND_BUFFER_LEVEL_PRIMARY = 0;
    const uint VK_SUBPASS_CONTENTS_INLINE = 0;
    const uint VK_FENCE_CREATE_SIGNALED_BIT = 1;
    const uint VK_BUFFER_USAGE_STORAGE_BUFFER_BIT = 0x20;
    const uint VK_BUFFER_USAGE_UNIFORM_BUFFER_BIT = 0x10;
    const uint VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT = 1;
    const uint VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT = 2;
    const uint VK_MEMORY_PROPERTY_HOST_COHERENT_BIT = 4;
    const uint VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER = 6;
    const uint VK_DESCRIPTOR_TYPE_STORAGE_BUFFER = 7;
    const ulong VK_WHOLE_SIZE = 0xFFFFFFFFFFFFFFFF;
    const int MAX_FRAMES_IN_FLIGHT = 2;
    const uint VERTEX_COUNT = 500000;

    static string COMP_SRC = @"#version 450
layout(local_size_x = 256, local_size_y = 1, local_size_z = 1) in;
layout(std430, binding = 0) buffer Positions { vec4 pos[]; };
layout(std430, binding = 1) buffer Colors    { vec4 col[]; };
layout(std140, binding = 2) uniform Params {
    uint  max_num; float dt; float scale; float pad0;
    float A1; float f1; float p1; float d1;
    float A2; float f2; float p2; float d2;
    float A3; float f3; float p3; float d3;
    float A4; float f4; float p4; float d4;
} u;
vec3 hsv2rgb(float h, float s, float v) {
    float c = v * s; float hp = h / 60.0;
    float x = c * (1.0 - abs(mod(hp, 2.0) - 1.0)); vec3 rgb;
    if (hp < 1.0) rgb = vec3(c, x, 0.0);
    else if (hp < 2.0) rgb = vec3(x, c, 0.0);
    else if (hp < 3.0) rgb = vec3(0.0, c, x);
    else if (hp < 4.0) rgb = vec3(0.0, x, c);
    else if (hp < 5.0) rgb = vec3(x, 0.0, c);
    else rgb = vec3(c, 0.0, x);
    return rgb + vec3(v - c);
}
void main() {
    uint idx = gl_GlobalInvocationID.x;
    if (idx >= u.max_num) return;
    float t = float(idx) * u.dt; float PI = 3.141592653589793;
    float x = u.A1 * sin(u.f1 * t + PI * u.p1) * exp(-u.d1 * t) + u.A2 * sin(u.f2 * t + PI * u.p2) * exp(-u.d2 * t);
    float y = u.A3 * sin(u.f3 * t + PI * u.p3) * exp(-u.d3 * t) + u.A4 * sin(u.f4 * t + PI * u.p4) * exp(-u.d4 * t);
    pos[idx] = vec4(x * u.scale, y * u.scale, 0.0, 1.0);
    float hue = mod((t / 20.0) * 360.0, 360.0);
    col[idx] = vec4(hsv2rgb(hue, 1.0, 1.0), 1.0);
}";

    static string VERT_SRC = @"#version 450
layout(std430, binding = 0) buffer Positions { vec4 pos[]; };
layout(std430, binding = 1) buffer Colors    { vec4 col[]; };
layout(location = 0) out vec4 vColor;
void main() { uint idx = uint(gl_VertexIndex); gl_Position = pos[idx]; vColor = col[idx]; }";

    static string FRAG_SRC = @"#version 450
layout(location = 0) in vec4 vColor;
layout(location = 0) out vec4 outColor;
void main() { outColor = vColor; }";

    [StructLayout(LayoutKind.Sequential)] struct VkApplicationInfo { public uint sType; public IntPtr pNext; public IntPtr pApplicationName; public uint applicationVersion; public IntPtr pEngineName; public uint engineVersion; public uint apiVersion; }
    [StructLayout(LayoutKind.Sequential)] struct VkInstanceCreateInfo { public uint sType; public IntPtr pNext; public uint flags; public IntPtr pApplicationInfo; public uint enabledLayerCount; public IntPtr ppEnabledLayerNames; public uint enabledExtensionCount; public IntPtr ppEnabledExtensionNames; }
    [StructLayout(LayoutKind.Sequential)] struct VkWin32SurfaceCreateInfoKHR { public uint sType; public IntPtr pNext; public uint flags; public IntPtr hinstance; public IntPtr hwnd; }
    [StructLayout(LayoutKind.Sequential)] struct VkDeviceQueueCreateInfo { public uint sType; public IntPtr pNext; public uint flags; public uint queueFamilyIndex; public uint queueCount; public IntPtr pQueuePriorities; }
    [StructLayout(LayoutKind.Sequential)] struct VkDeviceCreateInfo { public uint sType; public IntPtr pNext; public uint flags; public uint queueCreateInfoCount; public IntPtr pQueueCreateInfos; public uint enabledLayerCount; public IntPtr ppEnabledLayerNames; public uint enabledExtensionCount; public IntPtr ppEnabledExtensionNames; public IntPtr pEnabledFeatures; }
    [StructLayout(LayoutKind.Sequential)] struct VkQueueFamilyProperties { public uint queueFlags; public uint queueCount; public uint timestampValidBits; public uint w; public uint h; public uint d; }
    [StructLayout(LayoutKind.Sequential)] struct VkSurfaceCapabilitiesKHR { public uint minImageCount; public uint maxImageCount; public uint currentExtentWidth; public uint currentExtentHeight; public uint minImageExtentWidth; public uint minImageExtentHeight; public uint maxImageExtentWidth; public uint maxImageExtentHeight; public uint maxImageArrayLayers; public uint supportedTransforms; public uint currentTransform; public uint supportedCompositeAlpha; public uint supportedUsageFlags; }
    [StructLayout(LayoutKind.Sequential)] struct VkSurfaceFormatKHR { public uint format; public uint colorSpace; }
    [StructLayout(LayoutKind.Sequential)] struct VkSwapchainCreateInfoKHR { public uint sType; public IntPtr pNext; public uint flags; public IntPtr surface; public uint minImageCount; public uint imageFormat; public uint imageColorSpace; public uint imageExtentWidth; public uint imageExtentHeight; public uint imageArrayLayers; public uint imageUsage; public uint imageSharingMode; public uint queueFamilyIndexCount; public IntPtr pQueueFamilyIndices; public uint preTransform; public uint compositeAlpha; public uint presentMode; public uint clipped; public IntPtr oldSwapchain; }
    [StructLayout(LayoutKind.Sequential)] struct VkComponentMapping { public uint r, g, b, a; }
    [StructLayout(LayoutKind.Sequential)] struct VkImageSubresourceRange { public uint aspectMask; public uint baseMipLevel; public uint levelCount; public uint baseArrayLayer; public uint layerCount; }
    [StructLayout(LayoutKind.Sequential)] struct VkImageViewCreateInfo { public uint sType; public IntPtr pNext; public uint flags; public IntPtr image; public uint viewType; public uint format; public VkComponentMapping components; public VkImageSubresourceRange subresourceRange; }
    [StructLayout(LayoutKind.Sequential)] struct VkAttachmentDescription { public uint flags; public uint format; public uint samples; public uint loadOp; public uint storeOp; public uint stencilLoadOp; public uint stencilStoreOp; public uint initialLayout; public uint finalLayout; }
    [StructLayout(LayoutKind.Sequential)] struct VkAttachmentReference { public uint attachment; public uint layout; }
    [StructLayout(LayoutKind.Sequential)] struct VkSubpassDescription { public uint flags; public uint pipelineBindPoint; public uint inputAttachmentCount; public IntPtr pInputAttachments; public uint colorAttachmentCount; public IntPtr pColorAttachments; public IntPtr pResolveAttachments; public IntPtr pDepthStencilAttachment; public uint preserveAttachmentCount; public IntPtr pPreserveAttachments; }
    [StructLayout(LayoutKind.Sequential)] struct VkSubpassDependency { public uint srcSubpass; public uint dstSubpass; public uint srcStageMask; public uint dstStageMask; public uint srcAccessMask; public uint dstAccessMask; public uint dependencyFlags; }
    [StructLayout(LayoutKind.Sequential)] struct VkRenderPassCreateInfo { public uint sType; public IntPtr pNext; public uint flags; public uint attachmentCount; public IntPtr pAttachments; public uint subpassCount; public IntPtr pSubpasses; public uint dependencyCount; public IntPtr pDependencies; }
    [StructLayout(LayoutKind.Sequential)] struct VkShaderModuleCreateInfo { public uint sType; public IntPtr pNext; public uint flags; public UIntPtr codeSize; public IntPtr pCode; }
    [StructLayout(LayoutKind.Sequential)] struct VkPipelineShaderStageCreateInfo { public uint sType; public IntPtr pNext; public uint flags; public uint stage; public IntPtr module; public IntPtr pName; public IntPtr pSpecializationInfo; }
    [StructLayout(LayoutKind.Sequential)] struct VkPipelineVertexInputStateCreateInfo { public uint sType; public IntPtr pNext; public uint flags; public uint vertexBindingDescriptionCount; public IntPtr pVertexBindingDescriptions; public uint vertexAttributeDescriptionCount; public IntPtr pVertexAttributeDescriptions; }
    [StructLayout(LayoutKind.Sequential)] struct VkPipelineInputAssemblyStateCreateInfo { public uint sType; public IntPtr pNext; public uint flags; public uint topology; public uint primitiveRestartEnable; }
    [StructLayout(LayoutKind.Sequential)] struct VkViewport { public float x, y, width, height, minDepth, maxDepth; }
    [StructLayout(LayoutKind.Sequential)] struct VkOffset2D { public int x, y; }
    [StructLayout(LayoutKind.Sequential)] struct VkExtent2D { public uint width, height; }
    [StructLayout(LayoutKind.Sequential)] struct VkRect2D { public VkOffset2D offset; public VkExtent2D extent; }
    [StructLayout(LayoutKind.Sequential)] struct VkPipelineViewportStateCreateInfo { public uint sType; public IntPtr pNext; public uint flags; public uint viewportCount; public IntPtr pViewports; public uint scissorCount; public IntPtr pScissors; }
    [StructLayout(LayoutKind.Sequential)] struct VkPipelineRasterizationStateCreateInfo { public uint sType; public IntPtr pNext; public uint flags; public uint depthClampEnable; public uint rasterizerDiscardEnable; public uint polygonMode; public uint cullMode; public uint frontFace; public uint depthBiasEnable; public float depthBiasConstantFactor; public float depthBiasClamp; public float depthBiasSlopeFactor; public float lineWidth; }
    [StructLayout(LayoutKind.Sequential)] struct VkPipelineMultisampleStateCreateInfo { public uint sType; public IntPtr pNext; public uint flags; public uint rasterizationSamples; public uint sampleShadingEnable; public float minSampleShading; public IntPtr pSampleMask; public uint alphaToCoverageEnable; public uint alphaToOneEnable; }
    [StructLayout(LayoutKind.Sequential)] struct VkPipelineColorBlendAttachmentState { public uint blendEnable; public uint srcColorBlendFactor; public uint dstColorBlendFactor; public uint colorBlendOp; public uint srcAlphaBlendFactor; public uint dstAlphaBlendFactor; public uint alphaBlendOp; public uint colorWriteMask; }
    [StructLayout(LayoutKind.Sequential)] struct VkPipelineColorBlendStateCreateInfo { public uint sType; public IntPtr pNext; public uint flags; public uint logicOpEnable; public uint logicOp; public uint attachmentCount; public IntPtr pAttachments; public float b0, b1, b2, b3; }
    [StructLayout(LayoutKind.Sequential)] struct VkPipelineLayoutCreateInfo { public uint sType; public IntPtr pNext; public uint flags; public uint setLayoutCount; public IntPtr pSetLayouts; public uint pushConstantRangeCount; public IntPtr pPushConstantRanges; }
    [StructLayout(LayoutKind.Sequential)] struct VkGraphicsPipelineCreateInfo { public uint sType; public IntPtr pNext; public uint flags; public uint stageCount; public IntPtr pStages; public IntPtr pVertexInputState; public IntPtr pInputAssemblyState; public IntPtr pTessellationState; public IntPtr pViewportState; public IntPtr pRasterizationState; public IntPtr pMultisampleState; public IntPtr pDepthStencilState; public IntPtr pColorBlendState; public IntPtr pDynamicState; public IntPtr layout; public IntPtr renderPass; public uint subpass; public IntPtr basePipelineHandle; public int basePipelineIndex; }
    [StructLayout(LayoutKind.Sequential)] struct VkComputePipelineCreateInfo { public uint sType; public IntPtr pNext; public uint flags; public VkPipelineShaderStageCreateInfo stage; public IntPtr layout; public IntPtr basePipelineHandle; public int basePipelineIndex; }
    [StructLayout(LayoutKind.Sequential)] struct VkFramebufferCreateInfo { public uint sType; public IntPtr pNext; public uint flags; public IntPtr renderPass; public uint attachmentCount; public IntPtr pAttachments; public uint width; public uint height; public uint layers; }
    [StructLayout(LayoutKind.Sequential)] struct VkCommandPoolCreateInfo { public uint sType; public IntPtr pNext; public uint flags; public uint queueFamilyIndex; }
    [StructLayout(LayoutKind.Sequential)] struct VkCommandBufferAllocateInfo { public uint sType; public IntPtr pNext; public IntPtr commandPool; public uint level; public uint commandBufferCount; }
    [StructLayout(LayoutKind.Sequential)] struct VkCommandBufferBeginInfo { public uint sType; public IntPtr pNext; public uint flags; public IntPtr pInheritanceInfo; }
    [StructLayout(LayoutKind.Sequential)] struct VkClearColorValue { public float r, g, b, a; }
    [StructLayout(LayoutKind.Sequential)] struct VkClearValue { public VkClearColorValue color; }
    [StructLayout(LayoutKind.Sequential)] struct VkRenderPassBeginInfo { public uint sType; public IntPtr pNext; public IntPtr renderPass; public IntPtr framebuffer; public VkRect2D renderArea; public uint clearValueCount; public IntPtr pClearValues; }
    [StructLayout(LayoutKind.Sequential)] struct VkSemaphoreCreateInfo { public uint sType; public IntPtr pNext; public uint flags; }
    [StructLayout(LayoutKind.Sequential)] struct VkFenceCreateInfo { public uint sType; public IntPtr pNext; public uint flags; }
    [StructLayout(LayoutKind.Sequential)] struct VkSubmitInfo { public uint sType; public IntPtr pNext; public uint waitSemaphoreCount; public IntPtr pWaitSemaphores; public IntPtr pWaitDstStageMask; public uint commandBufferCount; public IntPtr pCommandBuffers; public uint signalSemaphoreCount; public IntPtr pSignalSemaphores; }
    [StructLayout(LayoutKind.Sequential)] struct VkPresentInfoKHR { public uint sType; public IntPtr pNext; public uint waitSemaphoreCount; public IntPtr pWaitSemaphores; public uint swapchainCount; public IntPtr pSwapchains; public IntPtr pImageIndices; public IntPtr pResults; }
    [StructLayout(LayoutKind.Sequential)] struct VkBufferCreateInfo { public uint sType; public IntPtr pNext; public uint flags; public ulong size; public uint usage; public uint sharingMode; public uint queueFamilyIndexCount; public IntPtr pQueueFamilyIndices; }
    [StructLayout(LayoutKind.Sequential)] struct VkMemoryRequirements { public ulong size; public ulong alignment; public uint memoryTypeBits; }
    [StructLayout(LayoutKind.Sequential)] struct VkMemoryAllocateInfo { public uint sType; public IntPtr pNext; public ulong allocationSize; public uint memoryTypeIndex; }
    [StructLayout(LayoutKind.Sequential)] struct VkPhysicalDeviceMemoryProperties { public uint memoryTypeCount; [MarshalAs(UnmanagedType.ByValArray, SizeConst = 32)] public VkMemoryType[] memoryTypes; public uint memoryHeapCount; [MarshalAs(UnmanagedType.ByValArray, SizeConst = 16)] public VkMemoryHeap[] memoryHeaps; }
    [StructLayout(LayoutKind.Sequential)] struct VkMemoryType { public uint propertyFlags; public uint heapIndex; }
    [StructLayout(LayoutKind.Sequential)] struct VkMemoryHeap { public ulong size; public uint flags; }
    [StructLayout(LayoutKind.Sequential)] struct VkDescriptorSetLayoutBinding { public uint binding; public uint descriptorType; public uint descriptorCount; public uint stageFlags; public IntPtr pImmutableSamplers; }
    [StructLayout(LayoutKind.Sequential)] struct VkDescriptorSetLayoutCreateInfo { public uint sType; public IntPtr pNext; public uint flags; public uint bindingCount; public IntPtr pBindings; }
    [StructLayout(LayoutKind.Sequential)] struct VkDescriptorPoolSize { public uint type; public uint descriptorCount; }
    [StructLayout(LayoutKind.Sequential)] struct VkDescriptorPoolCreateInfo { public uint sType; public IntPtr pNext; public uint flags; public uint maxSets; public uint poolSizeCount; public IntPtr pPoolSizes; }
    [StructLayout(LayoutKind.Sequential)] struct VkDescriptorSetAllocateInfo { public uint sType; public IntPtr pNext; public IntPtr descriptorPool; public uint descriptorSetCount; public IntPtr pSetLayouts; }
    [StructLayout(LayoutKind.Sequential)] struct VkDescriptorBufferInfo { public IntPtr buffer; public ulong offset; public ulong range; }
    [StructLayout(LayoutKind.Sequential)] struct VkWriteDescriptorSet { public uint sType; public IntPtr pNext; public IntPtr dstSet; public uint dstBinding; public uint dstArrayElement; public uint descriptorCount; public uint descriptorType; public IntPtr pImageInfo; public IntPtr pBufferInfo; public IntPtr pTexelBufferView; }
    [StructLayout(LayoutKind.Sequential)] struct VkBufferMemoryBarrier { public uint sType; public IntPtr pNext; public uint srcAccessMask; public uint dstAccessMask; public uint srcQueueFamilyIndex; public uint dstQueueFamilyIndex; public IntPtr buffer; public ulong offset; public ulong size; }
    [StructLayout(LayoutKind.Sequential, Pack = 4)] struct ParamsUBO { public uint max_num; public float dt; public float scale; public float pad0; public float A1, f1, p1, d1; public float A2, f2, p2, d2; public float A3, f3, p3, d3; public float A4, f4, p4, d4; }

    [DllImport("kernel32.dll")] static extern IntPtr GetModuleHandle(string lpModuleName);
    [DllImport("vulkan-1.dll")] static extern int vkCreateInstance(ref VkInstanceCreateInfo pCreateInfo, IntPtr pAllocator, out IntPtr pInstance);
    [DllImport("vulkan-1.dll")] static extern void vkDestroyInstance(IntPtr instance, IntPtr pAllocator);
    [DllImport("vulkan-1.dll")] static extern int vkEnumeratePhysicalDevices(IntPtr instance, ref uint pPhysicalDeviceCount, IntPtr[] pPhysicalDevices);
    [DllImport("vulkan-1.dll")] static extern void vkGetPhysicalDeviceQueueFamilyProperties(IntPtr physicalDevice, ref uint pCount, [Out] VkQueueFamilyProperties[] pProps);
    [DllImport("vulkan-1.dll")] static extern void vkGetPhysicalDeviceMemoryProperties(IntPtr physicalDevice, out VkPhysicalDeviceMemoryProperties pMemoryProperties);
    [DllImport("vulkan-1.dll")] static extern int vkCreateWin32SurfaceKHR(IntPtr instance, ref VkWin32SurfaceCreateInfoKHR pCreateInfo, IntPtr pAllocator, out IntPtr pSurface);
    [DllImport("vulkan-1.dll")] static extern void vkDestroySurfaceKHR(IntPtr instance, IntPtr surface, IntPtr pAllocator);
    [DllImport("vulkan-1.dll")] static extern int vkGetPhysicalDeviceSurfaceSupportKHR(IntPtr physicalDevice, uint queueFamilyIndex, IntPtr surface, out uint pSupported);
    [DllImport("vulkan-1.dll")] static extern int vkGetPhysicalDeviceSurfaceCapabilitiesKHR(IntPtr physicalDevice, IntPtr surface, out VkSurfaceCapabilitiesKHR pSurfaceCapabilities);
    [DllImport("vulkan-1.dll")] static extern int vkGetPhysicalDeviceSurfaceFormatsKHR(IntPtr physicalDevice, IntPtr surface, ref uint pCount, [Out] VkSurfaceFormatKHR[] pFormats);
    [DllImport("vulkan-1.dll")] static extern int vkCreateDevice(IntPtr physicalDevice, ref VkDeviceCreateInfo pCreateInfo, IntPtr pAllocator, out IntPtr pDevice);
    [DllImport("vulkan-1.dll")] static extern void vkDestroyDevice(IntPtr device, IntPtr pAllocator);
    [DllImport("vulkan-1.dll")] static extern void vkGetDeviceQueue(IntPtr device, uint queueFamilyIndex, uint queueIndex, out IntPtr pQueue);
    [DllImport("vulkan-1.dll")] static extern int vkDeviceWaitIdle(IntPtr device);
    [DllImport("vulkan-1.dll")] static extern int vkCreateSwapchainKHR(IntPtr device, ref VkSwapchainCreateInfoKHR pCreateInfo, IntPtr pAllocator, out IntPtr pSwapchain);
    [DllImport("vulkan-1.dll")] static extern void vkDestroySwapchainKHR(IntPtr device, IntPtr swapchain, IntPtr pAllocator);
    [DllImport("vulkan-1.dll")] static extern int vkGetSwapchainImagesKHR(IntPtr device, IntPtr swapchain, ref uint pCount, IntPtr[] pImages);
    [DllImport("vulkan-1.dll")] static extern int vkCreateImageView(IntPtr device, ref VkImageViewCreateInfo pCreateInfo, IntPtr pAllocator, out IntPtr pView);
    [DllImport("vulkan-1.dll")] static extern void vkDestroyImageView(IntPtr device, IntPtr imageView, IntPtr pAllocator);
    [DllImport("vulkan-1.dll")] static extern int vkCreateRenderPass(IntPtr device, ref VkRenderPassCreateInfo pCreateInfo, IntPtr pAllocator, out IntPtr pRenderPass);
    [DllImport("vulkan-1.dll")] static extern void vkDestroyRenderPass(IntPtr device, IntPtr renderPass, IntPtr pAllocator);
    [DllImport("vulkan-1.dll")] static extern int vkCreateShaderModule(IntPtr device, ref VkShaderModuleCreateInfo pCreateInfo, IntPtr pAllocator, out IntPtr pShaderModule);
    [DllImport("vulkan-1.dll")] static extern void vkDestroyShaderModule(IntPtr device, IntPtr shaderModule, IntPtr pAllocator);
    [DllImport("vulkan-1.dll")] static extern int vkCreateDescriptorSetLayout(IntPtr device, ref VkDescriptorSetLayoutCreateInfo pCreateInfo, IntPtr pAllocator, out IntPtr pSetLayout);
    [DllImport("vulkan-1.dll")] static extern void vkDestroyDescriptorSetLayout(IntPtr device, IntPtr descriptorSetLayout, IntPtr pAllocator);
    [DllImport("vulkan-1.dll")] static extern int vkCreatePipelineLayout(IntPtr device, ref VkPipelineLayoutCreateInfo pCreateInfo, IntPtr pAllocator, out IntPtr pPipelineLayout);
    [DllImport("vulkan-1.dll")] static extern void vkDestroyPipelineLayout(IntPtr device, IntPtr pipelineLayout, IntPtr pAllocator);
    [DllImport("vulkan-1.dll")] static extern int vkCreateGraphicsPipelines(IntPtr device, IntPtr pipelineCache, uint createInfoCount, ref VkGraphicsPipelineCreateInfo pCreateInfos, IntPtr pAllocator, out IntPtr pPipelines);
    [DllImport("vulkan-1.dll")] static extern int vkCreateComputePipelines(IntPtr device, IntPtr pipelineCache, uint createInfoCount, ref VkComputePipelineCreateInfo pCreateInfos, IntPtr pAllocator, out IntPtr pPipelines);
    [DllImport("vulkan-1.dll")] static extern void vkDestroyPipeline(IntPtr device, IntPtr pipeline, IntPtr pAllocator);
    [DllImport("vulkan-1.dll")] static extern int vkCreateFramebuffer(IntPtr device, ref VkFramebufferCreateInfo pCreateInfo, IntPtr pAllocator, out IntPtr pFramebuffer);
    [DllImport("vulkan-1.dll")] static extern void vkDestroyFramebuffer(IntPtr device, IntPtr framebuffer, IntPtr pAllocator);
    [DllImport("vulkan-1.dll")] static extern int vkCreateCommandPool(IntPtr device, ref VkCommandPoolCreateInfo pCreateInfo, IntPtr pAllocator, out IntPtr pCommandPool);
    [DllImport("vulkan-1.dll")] static extern void vkDestroyCommandPool(IntPtr device, IntPtr commandPool, IntPtr pAllocator);
    [DllImport("vulkan-1.dll")] static extern int vkAllocateCommandBuffers(IntPtr device, ref VkCommandBufferAllocateInfo pAllocateInfo, IntPtr[] pCommandBuffers);
    [DllImport("vulkan-1.dll")] static extern int vkBeginCommandBuffer(IntPtr commandBuffer, ref VkCommandBufferBeginInfo pBeginInfo);
    [DllImport("vulkan-1.dll")] static extern int vkEndCommandBuffer(IntPtr commandBuffer);
    [DllImport("vulkan-1.dll")] static extern int vkResetCommandBuffer(IntPtr commandBuffer, uint flags);
    [DllImport("vulkan-1.dll")] static extern void vkCmdBeginRenderPass(IntPtr commandBuffer, ref VkRenderPassBeginInfo pRenderPassBegin, uint contents);
    [DllImport("vulkan-1.dll")] static extern void vkCmdEndRenderPass(IntPtr commandBuffer);
    [DllImport("vulkan-1.dll")] static extern void vkCmdBindPipeline(IntPtr commandBuffer, uint pipelineBindPoint, IntPtr pipeline);
    [DllImport("vulkan-1.dll")] static extern void vkCmdBindDescriptorSets(IntPtr commandBuffer, uint pipelineBindPoint, IntPtr layout, uint firstSet, uint descriptorSetCount, IntPtr[] pDescriptorSets, uint dynamicOffsetCount, IntPtr pDynamicOffsets);
    [DllImport("vulkan-1.dll")] static extern void vkCmdDraw(IntPtr commandBuffer, uint vertexCount, uint instanceCount, uint firstVertex, uint firstInstance);
    [DllImport("vulkan-1.dll")] static extern void vkCmdDispatch(IntPtr commandBuffer, uint groupCountX, uint groupCountY, uint groupCountZ);
    [DllImport("vulkan-1.dll")] static extern void vkCmdPipelineBarrier(IntPtr commandBuffer, uint srcStageMask, uint dstStageMask, uint dependencyFlags, uint memoryBarrierCount, IntPtr pMemoryBarriers, uint bufferMemoryBarrierCount, IntPtr pBufferMemoryBarriers, uint imageMemoryBarrierCount, IntPtr pImageMemoryBarriers);
    [DllImport("vulkan-1.dll")] static extern int vkCreateSemaphore(IntPtr device, ref VkSemaphoreCreateInfo pCreateInfo, IntPtr pAllocator, out IntPtr pSemaphore);
    [DllImport("vulkan-1.dll")] static extern void vkDestroySemaphore(IntPtr device, IntPtr semaphore, IntPtr pAllocator);
    [DllImport("vulkan-1.dll")] static extern int vkCreateFence(IntPtr device, ref VkFenceCreateInfo pCreateInfo, IntPtr pAllocator, out IntPtr pFence);
    [DllImport("vulkan-1.dll")] static extern void vkDestroyFence(IntPtr device, IntPtr fence, IntPtr pAllocator);
    [DllImport("vulkan-1.dll")] static extern int vkWaitForFences(IntPtr device, uint fenceCount, IntPtr[] pFences, uint waitAll, ulong timeout);
    [DllImport("vulkan-1.dll")] static extern int vkResetFences(IntPtr device, uint fenceCount, IntPtr[] pFences);
    [DllImport("vulkan-1.dll")] static extern int vkAcquireNextImageKHR(IntPtr device, IntPtr swapchain, ulong timeout, IntPtr semaphore, IntPtr fence, out uint pImageIndex);
    [DllImport("vulkan-1.dll")] static extern int vkQueueSubmit(IntPtr queue, uint submitCount, ref VkSubmitInfo pSubmits, IntPtr fence);
    [DllImport("vulkan-1.dll")] static extern int vkQueuePresentKHR(IntPtr queue, ref VkPresentInfoKHR pPresentInfo);
    [DllImport("vulkan-1.dll")] static extern int vkCreateBuffer(IntPtr device, ref VkBufferCreateInfo pCreateInfo, IntPtr pAllocator, out IntPtr pBuffer);
    [DllImport("vulkan-1.dll")] static extern void vkDestroyBuffer(IntPtr device, IntPtr buffer, IntPtr pAllocator);
    [DllImport("vulkan-1.dll")] static extern void vkGetBufferMemoryRequirements(IntPtr device, IntPtr buffer, out VkMemoryRequirements pMemoryRequirements);
    [DllImport("vulkan-1.dll")] static extern int vkAllocateMemory(IntPtr device, ref VkMemoryAllocateInfo pAllocateInfo, IntPtr pAllocator, out IntPtr pMemory);
    [DllImport("vulkan-1.dll")] static extern void vkFreeMemory(IntPtr device, IntPtr memory, IntPtr pAllocator);
    [DllImport("vulkan-1.dll")] static extern int vkBindBufferMemory(IntPtr device, IntPtr buffer, IntPtr memory, ulong memoryOffset);
    [DllImport("vulkan-1.dll")] static extern int vkMapMemory(IntPtr device, IntPtr memory, ulong offset, ulong size, uint flags, out IntPtr ppData);
    [DllImport("vulkan-1.dll")] static extern void vkUnmapMemory(IntPtr device, IntPtr memory);
    [DllImport("vulkan-1.dll")] static extern int vkCreateDescriptorPool(IntPtr device, ref VkDescriptorPoolCreateInfo pCreateInfo, IntPtr pAllocator, out IntPtr pDescriptorPool);
    [DllImport("vulkan-1.dll")] static extern void vkDestroyDescriptorPool(IntPtr device, IntPtr descriptorPool, IntPtr pAllocator);
    [DllImport("vulkan-1.dll")] static extern int vkAllocateDescriptorSets(IntPtr device, ref VkDescriptorSetAllocateInfo pAllocateInfo, IntPtr[] pDescriptorSets);
    [DllImport("vulkan-1.dll")] static extern void vkUpdateDescriptorSets(IntPtr device, uint descriptorWriteCount, IntPtr pDescriptorWrites, uint descriptorCopyCount, IntPtr pDescriptorCopies);

    IntPtr instance, physicalDevice, device, surface, swapchain, renderPass, queue, commandPool;
    IntPtr computePipeline, computePipelineLayout, graphicsPipeline, graphicsPipelineLayout;
    IntPtr descriptorSetLayout, descriptorPool, descriptorSet;
    IntPtr posBuffer, posMemory, colBuffer, colMemory, uboBuffer, uboMemory;
    IntPtr compShaderModule, vertShaderModule, fragShaderModule;
    IntPtr[] swapchainImages, swapchainImageViews, framebuffers, commandBuffers;
    IntPtr[] imageAvailableSemaphores, renderFinishedSemaphores, inFlightFences;
    uint queueFamilyIndex, swapchainExtentWidth, swapchainExtentHeight, swapchainFormat;
    int currentFrame = 0;
    bool framebufferResized = false;
    ParamsUBO uboParams;
    float animTime = 0.0f;
    System.Windows.Forms.Timer renderTimer;

    public VulkanHarmonograph()
    {
        this.Text = "Vulkan 1.4 Compute Harmonograph (PowerShell)";
        this.ClientSize = new Size(960, 720);
        this.SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.UserPaint, true);
        this.DoubleBuffered = false;
        InitVulkan();
        renderTimer = new System.Windows.Forms.Timer();
        renderTimer.Interval = 16;
        renderTimer.Tick += new EventHandler(OnRenderTick);
        renderTimer.Start();
    }

    void OnRenderTick(object sender, EventArgs e) { DrawFrame(); }
    protected override void OnPaint(PaintEventArgs e) { }
    protected override void OnPaintBackground(PaintEventArgs e) { }
    protected override void OnResize(EventArgs e) { base.OnResize(e); if (device != IntPtr.Zero && ClientSize.Width > 0 && ClientSize.Height > 0) framebufferResized = true; }
    protected override void OnFormClosing(FormClosingEventArgs e) { base.OnFormClosing(e); if (renderTimer != null) { renderTimer.Stop(); } Cleanup(); }

    void InitVulkan() { CreateInstance(); CreateSurface(); PickPhysicalDevice(); CreateDevice(); CreateSwapchain(); CreateImageViews(); CreateRenderPass(); CreateDescriptorSetLayout(); CreateBuffers(); CreateDescriptorPool(); CreateDescriptorSet(); CreateComputePipeline(); CreateGraphicsPipeline(); CreateFramebuffers(); CreateCommandPool(); CreateCommandBuffers(); CreateSyncObjects(); InitUBO(); }

    void CreateInstance() { IntPtr appName = Marshal.StringToHGlobalAnsi("VulkanHarmonograph"); IntPtr engineName = Marshal.StringToHGlobalAnsi("NoEngine"); VkApplicationInfo appInfo = new VkApplicationInfo(); appInfo.sType = VK_STRUCTURE_TYPE_APPLICATION_INFO; appInfo.pApplicationName = appName; appInfo.applicationVersion = 1; appInfo.pEngineName = engineName; appInfo.engineVersion = 1; appInfo.apiVersion = VK_API_VERSION_1_4; IntPtr ext1 = Marshal.StringToHGlobalAnsi("VK_KHR_surface"); IntPtr ext2 = Marshal.StringToHGlobalAnsi("VK_KHR_win32_surface"); IntPtr[] extensions = new IntPtr[] { ext1, ext2 }; GCHandle appInfoHandle = GCHandle.Alloc(appInfo, GCHandleType.Pinned); GCHandle extHandle = GCHandle.Alloc(extensions, GCHandleType.Pinned); VkInstanceCreateInfo createInfo = new VkInstanceCreateInfo(); createInfo.sType = VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO; createInfo.pApplicationInfo = appInfoHandle.AddrOfPinnedObject(); createInfo.enabledExtensionCount = 2; createInfo.ppEnabledExtensionNames = extHandle.AddrOfPinnedObject(); vkCreateInstance(ref createInfo, IntPtr.Zero, out instance); appInfoHandle.Free(); extHandle.Free(); Marshal.FreeHGlobal(appName); Marshal.FreeHGlobal(engineName); Marshal.FreeHGlobal(ext1); Marshal.FreeHGlobal(ext2); }

    void CreateSurface() { VkWin32SurfaceCreateInfoKHR createInfo = new VkWin32SurfaceCreateInfoKHR(); createInfo.sType = VK_STRUCTURE_TYPE_WIN32_SURFACE_CREATE_INFO_KHR; createInfo.hinstance = GetModuleHandle(null); createInfo.hwnd = this.Handle; vkCreateWin32SurfaceKHR(instance, ref createInfo, IntPtr.Zero, out surface); }

    void PickPhysicalDevice() { uint deviceCount = 0; vkEnumeratePhysicalDevices(instance, ref deviceCount, null); IntPtr[] devices = new IntPtr[deviceCount]; vkEnumeratePhysicalDevices(instance, ref deviceCount, devices); physicalDevice = devices[0]; uint queueFamilyCount = 0; vkGetPhysicalDeviceQueueFamilyProperties(physicalDevice, ref queueFamilyCount, null); VkQueueFamilyProperties[] queueFamilies = new VkQueueFamilyProperties[queueFamilyCount]; vkGetPhysicalDeviceQueueFamilyProperties(physicalDevice, ref queueFamilyCount, queueFamilies); for (uint i = 0; i < queueFamilyCount; i++) { if ((queueFamilies[i].queueFlags & (VK_QUEUE_GRAPHICS_BIT | VK_QUEUE_COMPUTE_BIT)) != 0) { uint supported; vkGetPhysicalDeviceSurfaceSupportKHR(physicalDevice, i, surface, out supported); if (supported == VK_TRUE) { queueFamilyIndex = i; break; } } } }

    void CreateDevice() { float[] priorities = new float[] { 1.0f }; GCHandle prioritiesHandle = GCHandle.Alloc(priorities, GCHandleType.Pinned); VkDeviceQueueCreateInfo queueCreateInfo = new VkDeviceQueueCreateInfo(); queueCreateInfo.sType = VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO; queueCreateInfo.queueFamilyIndex = queueFamilyIndex; queueCreateInfo.queueCount = 1; queueCreateInfo.pQueuePriorities = prioritiesHandle.AddrOfPinnedObject(); GCHandle queueCreateInfoHandle = GCHandle.Alloc(queueCreateInfo, GCHandleType.Pinned); IntPtr extName = Marshal.StringToHGlobalAnsi("VK_KHR_swapchain"); IntPtr[] exts = new IntPtr[] { extName }; GCHandle extHandle = GCHandle.Alloc(exts, GCHandleType.Pinned); VkDeviceCreateInfo deviceCreateInfo = new VkDeviceCreateInfo(); deviceCreateInfo.sType = VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO; deviceCreateInfo.queueCreateInfoCount = 1; deviceCreateInfo.pQueueCreateInfos = queueCreateInfoHandle.AddrOfPinnedObject(); deviceCreateInfo.enabledExtensionCount = 1; deviceCreateInfo.ppEnabledExtensionNames = extHandle.AddrOfPinnedObject(); vkCreateDevice(physicalDevice, ref deviceCreateInfo, IntPtr.Zero, out device); vkGetDeviceQueue(device, queueFamilyIndex, 0, out queue); prioritiesHandle.Free(); queueCreateInfoHandle.Free(); extHandle.Free(); Marshal.FreeHGlobal(extName); }

    void CreateSwapchain() { VkSurfaceCapabilitiesKHR caps; vkGetPhysicalDeviceSurfaceCapabilitiesKHR(physicalDevice, surface, out caps); swapchainFormat = VK_FORMAT_B8G8R8A8_UNORM; swapchainExtentWidth = caps.currentExtentWidth; swapchainExtentHeight = caps.currentExtentHeight; uint imageCount = caps.minImageCount + 1; if (caps.maxImageCount > 0 && imageCount > caps.maxImageCount) imageCount = caps.maxImageCount; VkSwapchainCreateInfoKHR createInfo = new VkSwapchainCreateInfoKHR(); createInfo.sType = VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR; createInfo.surface = surface; createInfo.minImageCount = imageCount; createInfo.imageFormat = swapchainFormat; createInfo.imageColorSpace = VK_COLOR_SPACE_SRGB_NONLINEAR_KHR; createInfo.imageExtentWidth = swapchainExtentWidth; createInfo.imageExtentHeight = swapchainExtentHeight; createInfo.imageArrayLayers = 1; createInfo.imageUsage = VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT; createInfo.imageSharingMode = VK_SHARING_MODE_EXCLUSIVE; createInfo.preTransform = caps.currentTransform; createInfo.compositeAlpha = VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR; createInfo.presentMode = VK_PRESENT_MODE_FIFO_KHR; createInfo.clipped = VK_TRUE; vkCreateSwapchainKHR(device, ref createInfo, IntPtr.Zero, out swapchain); uint count = 0; vkGetSwapchainImagesKHR(device, swapchain, ref count, null); swapchainImages = new IntPtr[count]; vkGetSwapchainImagesKHR(device, swapchain, ref count, swapchainImages); }

    void CreateImageViews() { swapchainImageViews = new IntPtr[swapchainImages.Length]; for (int i = 0; i < swapchainImages.Length; i++) { VkImageViewCreateInfo createInfo = new VkImageViewCreateInfo(); createInfo.sType = VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO; createInfo.image = swapchainImages[i]; createInfo.viewType = VK_IMAGE_VIEW_TYPE_2D; createInfo.format = swapchainFormat; createInfo.subresourceRange.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT; createInfo.subresourceRange.levelCount = 1; createInfo.subresourceRange.layerCount = 1; vkCreateImageView(device, ref createInfo, IntPtr.Zero, out swapchainImageViews[i]); } }

    void CreateRenderPass() { VkAttachmentDescription colorAttachment = new VkAttachmentDescription(); colorAttachment.format = swapchainFormat; colorAttachment.samples = VK_SAMPLE_COUNT_1_BIT; colorAttachment.loadOp = VK_ATTACHMENT_LOAD_OP_CLEAR; colorAttachment.storeOp = VK_ATTACHMENT_STORE_OP_STORE; colorAttachment.stencilLoadOp = 2; colorAttachment.stencilStoreOp = 2; colorAttachment.initialLayout = VK_IMAGE_LAYOUT_UNDEFINED; colorAttachment.finalLayout = VK_IMAGE_LAYOUT_PRESENT_SRC_KHR; VkAttachmentReference colorAttachmentRef = new VkAttachmentReference(); colorAttachmentRef.attachment = 0; colorAttachmentRef.layout = VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL; GCHandle colorAttachmentHandle = GCHandle.Alloc(colorAttachment, GCHandleType.Pinned); GCHandle colorRefHandle = GCHandle.Alloc(colorAttachmentRef, GCHandleType.Pinned); VkSubpassDescription subpass = new VkSubpassDescription(); subpass.pipelineBindPoint = VK_PIPELINE_BIND_POINT_GRAPHICS; subpass.colorAttachmentCount = 1; subpass.pColorAttachments = colorRefHandle.AddrOfPinnedObject(); GCHandle subpassHandle = GCHandle.Alloc(subpass, GCHandleType.Pinned); VkSubpassDependency dependency = new VkSubpassDependency(); dependency.srcSubpass = VK_SUBPASS_EXTERNAL; dependency.dstSubpass = 0; dependency.srcStageMask = VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT; dependency.dstStageMask = VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT; dependency.dstAccessMask = 0x100; GCHandle dependencyHandle = GCHandle.Alloc(dependency, GCHandleType.Pinned); VkRenderPassCreateInfo renderPassInfo = new VkRenderPassCreateInfo(); renderPassInfo.sType = VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO; renderPassInfo.attachmentCount = 1; renderPassInfo.pAttachments = colorAttachmentHandle.AddrOfPinnedObject(); renderPassInfo.subpassCount = 1; renderPassInfo.pSubpasses = subpassHandle.AddrOfPinnedObject(); renderPassInfo.dependencyCount = 1; renderPassInfo.pDependencies = dependencyHandle.AddrOfPinnedObject(); vkCreateRenderPass(device, ref renderPassInfo, IntPtr.Zero, out renderPass); colorAttachmentHandle.Free(); colorRefHandle.Free(); subpassHandle.Free(); dependencyHandle.Free(); }

    void CreateDescriptorSetLayout() { VkDescriptorSetLayoutBinding[] bindings = new VkDescriptorSetLayoutBinding[] { new VkDescriptorSetLayoutBinding { binding = 0, descriptorType = VK_DESCRIPTOR_TYPE_STORAGE_BUFFER, descriptorCount = 1, stageFlags = VK_SHADER_STAGE_COMPUTE_BIT | VK_SHADER_STAGE_VERTEX_BIT }, new VkDescriptorSetLayoutBinding { binding = 1, descriptorType = VK_DESCRIPTOR_TYPE_STORAGE_BUFFER, descriptorCount = 1, stageFlags = VK_SHADER_STAGE_COMPUTE_BIT | VK_SHADER_STAGE_VERTEX_BIT }, new VkDescriptorSetLayoutBinding { binding = 2, descriptorType = VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER, descriptorCount = 1, stageFlags = VK_SHADER_STAGE_COMPUTE_BIT } }; GCHandle bindingsHandle = GCHandle.Alloc(bindings, GCHandleType.Pinned); VkDescriptorSetLayoutCreateInfo createInfo = new VkDescriptorSetLayoutCreateInfo(); createInfo.sType = VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO; createInfo.bindingCount = 3; createInfo.pBindings = bindingsHandle.AddrOfPinnedObject(); vkCreateDescriptorSetLayout(device, ref createInfo, IntPtr.Zero, out descriptorSetLayout); bindingsHandle.Free(); }

    uint FindMemoryType(uint typeFilter, uint properties) { VkPhysicalDeviceMemoryProperties memProps; vkGetPhysicalDeviceMemoryProperties(physicalDevice, out memProps); for (uint i = 0; i < memProps.memoryTypeCount; i++) { if ((typeFilter & (1u << (int)i)) != 0 && (memProps.memoryTypes[i].propertyFlags & properties) == properties) return i; } throw new Exception("Failed to find suitable memory type"); }

    void CreateBuffer(ulong size, uint usage, uint memoryProperties, out IntPtr buffer, out IntPtr memory) { VkBufferCreateInfo bufferInfo = new VkBufferCreateInfo(); bufferInfo.sType = VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO; bufferInfo.size = size; bufferInfo.usage = usage; bufferInfo.sharingMode = VK_SHARING_MODE_EXCLUSIVE; vkCreateBuffer(device, ref bufferInfo, IntPtr.Zero, out buffer); VkMemoryRequirements memReqs; vkGetBufferMemoryRequirements(device, buffer, out memReqs); VkMemoryAllocateInfo allocInfo = new VkMemoryAllocateInfo(); allocInfo.sType = VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO; allocInfo.allocationSize = memReqs.size; allocInfo.memoryTypeIndex = FindMemoryType(memReqs.memoryTypeBits, memoryProperties); vkAllocateMemory(device, ref allocInfo, IntPtr.Zero, out memory); vkBindBufferMemory(device, buffer, memory, 0); }

    void CreateBuffers() { ulong bufferSize = VERTEX_COUNT * 16; CreateBuffer(bufferSize, VK_BUFFER_USAGE_STORAGE_BUFFER_BIT, VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT, out posBuffer, out posMemory); CreateBuffer(bufferSize, VK_BUFFER_USAGE_STORAGE_BUFFER_BIT, VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT, out colBuffer, out colMemory); CreateBuffer((ulong)Marshal.SizeOf(typeof(ParamsUBO)), VK_BUFFER_USAGE_UNIFORM_BUFFER_BIT, VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | VK_MEMORY_PROPERTY_HOST_COHERENT_BIT, out uboBuffer, out uboMemory); }

    void CreateDescriptorPool() { VkDescriptorPoolSize[] poolSizes = new VkDescriptorPoolSize[] { new VkDescriptorPoolSize { type = VK_DESCRIPTOR_TYPE_STORAGE_BUFFER, descriptorCount = 2 }, new VkDescriptorPoolSize { type = VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER, descriptorCount = 1 } }; GCHandle poolSizesHandle = GCHandle.Alloc(poolSizes, GCHandleType.Pinned); VkDescriptorPoolCreateInfo poolInfo = new VkDescriptorPoolCreateInfo(); poolInfo.sType = VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO; poolInfo.maxSets = 1; poolInfo.poolSizeCount = 2; poolInfo.pPoolSizes = poolSizesHandle.AddrOfPinnedObject(); vkCreateDescriptorPool(device, ref poolInfo, IntPtr.Zero, out descriptorPool); poolSizesHandle.Free(); }

    void CreateDescriptorSet() { IntPtr[] layouts = new IntPtr[] { descriptorSetLayout }; GCHandle layoutsHandle = GCHandle.Alloc(layouts, GCHandleType.Pinned); VkDescriptorSetAllocateInfo allocInfo = new VkDescriptorSetAllocateInfo(); allocInfo.sType = VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO; allocInfo.descriptorPool = descriptorPool; allocInfo.descriptorSetCount = 1; allocInfo.pSetLayouts = layoutsHandle.AddrOfPinnedObject(); IntPtr[] sets = new IntPtr[1]; vkAllocateDescriptorSets(device, ref allocInfo, sets); descriptorSet = sets[0]; layoutsHandle.Free(); VkDescriptorBufferInfo posInfo = new VkDescriptorBufferInfo { buffer = posBuffer, offset = 0, range = VERTEX_COUNT * 16 }; VkDescriptorBufferInfo colInfo = new VkDescriptorBufferInfo { buffer = colBuffer, offset = 0, range = VERTEX_COUNT * 16 }; VkDescriptorBufferInfo uboInfo = new VkDescriptorBufferInfo { buffer = uboBuffer, offset = 0, range = (ulong)Marshal.SizeOf(typeof(ParamsUBO)) }; GCHandle posInfoHandle = GCHandle.Alloc(posInfo, GCHandleType.Pinned); GCHandle colInfoHandle = GCHandle.Alloc(colInfo, GCHandleType.Pinned); GCHandle uboInfoHandle = GCHandle.Alloc(uboInfo, GCHandleType.Pinned); VkWriteDescriptorSet[] writes = new VkWriteDescriptorSet[] { new VkWriteDescriptorSet { sType = VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET, dstSet = descriptorSet, dstBinding = 0, descriptorCount = 1, descriptorType = VK_DESCRIPTOR_TYPE_STORAGE_BUFFER, pBufferInfo = posInfoHandle.AddrOfPinnedObject() }, new VkWriteDescriptorSet { sType = VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET, dstSet = descriptorSet, dstBinding = 1, descriptorCount = 1, descriptorType = VK_DESCRIPTOR_TYPE_STORAGE_BUFFER, pBufferInfo = colInfoHandle.AddrOfPinnedObject() }, new VkWriteDescriptorSet { sType = VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET, dstSet = descriptorSet, dstBinding = 2, descriptorCount = 1, descriptorType = VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER, pBufferInfo = uboInfoHandle.AddrOfPinnedObject() } }; int writeSize = Marshal.SizeOf(typeof(VkWriteDescriptorSet)); IntPtr writesPtr = Marshal.AllocHGlobal(writeSize * 3); for (int i = 0; i < 3; i++) Marshal.StructureToPtr(writes[i], new IntPtr(writesPtr.ToInt64() + i * writeSize), false); vkUpdateDescriptorSets(device, 3, writesPtr, 0, IntPtr.Zero); Marshal.FreeHGlobal(writesPtr); posInfoHandle.Free(); colInfoHandle.Free(); uboInfoHandle.Free(); }

    IntPtr CreateShaderModule(byte[] code) { GCHandle codeHandle = GCHandle.Alloc(code, GCHandleType.Pinned); VkShaderModuleCreateInfo createInfo = new VkShaderModuleCreateInfo(); createInfo.sType = VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO; createInfo.codeSize = (UIntPtr)code.Length; createInfo.pCode = codeHandle.AddrOfPinnedObject(); IntPtr shaderModule; vkCreateShaderModule(device, ref createInfo, IntPtr.Zero, out shaderModule); codeHandle.Free(); return shaderModule; }

    void CreateComputePipeline() { byte[] compSpv = ShaderCompiler.Compile(COMP_SRC, 2, "harmonograph.comp"); compShaderModule = CreateShaderModule(compSpv); IntPtr mainName = Marshal.StringToHGlobalAnsi("main"); IntPtr[] layouts = new IntPtr[] { descriptorSetLayout }; GCHandle layoutsHandle = GCHandle.Alloc(layouts, GCHandleType.Pinned); VkPipelineLayoutCreateInfo layoutInfo = new VkPipelineLayoutCreateInfo(); layoutInfo.sType = VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO; layoutInfo.setLayoutCount = 1; layoutInfo.pSetLayouts = layoutsHandle.AddrOfPinnedObject(); vkCreatePipelineLayout(device, ref layoutInfo, IntPtr.Zero, out computePipelineLayout); layoutsHandle.Free(); VkPipelineShaderStageCreateInfo stageInfo = new VkPipelineShaderStageCreateInfo(); stageInfo.sType = VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO; stageInfo.stage = VK_SHADER_STAGE_COMPUTE_BIT; stageInfo.module = compShaderModule; stageInfo.pName = mainName; VkComputePipelineCreateInfo pipelineInfo = new VkComputePipelineCreateInfo(); pipelineInfo.sType = VK_STRUCTURE_TYPE_COMPUTE_PIPELINE_CREATE_INFO; pipelineInfo.stage = stageInfo; pipelineInfo.layout = computePipelineLayout; vkCreateComputePipelines(device, IntPtr.Zero, 1, ref pipelineInfo, IntPtr.Zero, out computePipeline); Marshal.FreeHGlobal(mainName); }

    void CreateGraphicsPipeline() { byte[] vertSpv = ShaderCompiler.Compile(VERT_SRC, 0, "harmonograph.vert"); byte[] fragSpv = ShaderCompiler.Compile(FRAG_SRC, 1, "harmonograph.frag"); vertShaderModule = CreateShaderModule(vertSpv); fragShaderModule = CreateShaderModule(fragSpv); IntPtr mainName = Marshal.StringToHGlobalAnsi("main"); VkPipelineShaderStageCreateInfo[] stages = new VkPipelineShaderStageCreateInfo[] { new VkPipelineShaderStageCreateInfo { sType = VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO, stage = VK_SHADER_STAGE_VERTEX_BIT, module = vertShaderModule, pName = mainName }, new VkPipelineShaderStageCreateInfo { sType = VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO, stage = VK_SHADER_STAGE_FRAGMENT_BIT, module = fragShaderModule, pName = mainName } }; GCHandle stagesHandle = GCHandle.Alloc(stages, GCHandleType.Pinned); VkPipelineVertexInputStateCreateInfo vertexInput = new VkPipelineVertexInputStateCreateInfo { sType = VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO }; VkPipelineInputAssemblyStateCreateInfo inputAssembly = new VkPipelineInputAssemblyStateCreateInfo { sType = VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO, topology = VK_PRIMITIVE_TOPOLOGY_LINE_STRIP }; VkViewport viewport = new VkViewport { x = 0, y = 0, width = swapchainExtentWidth, height = swapchainExtentHeight, minDepth = 0, maxDepth = 1 }; VkRect2D scissor = new VkRect2D(); scissor.extent.width = swapchainExtentWidth; scissor.extent.height = swapchainExtentHeight; GCHandle viewportHandle = GCHandle.Alloc(viewport, GCHandleType.Pinned); GCHandle scissorHandle = GCHandle.Alloc(scissor, GCHandleType.Pinned); VkPipelineViewportStateCreateInfo viewportState = new VkPipelineViewportStateCreateInfo(); viewportState.sType = VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO; viewportState.viewportCount = 1; viewportState.pViewports = viewportHandle.AddrOfPinnedObject(); viewportState.scissorCount = 1; viewportState.pScissors = scissorHandle.AddrOfPinnedObject(); VkPipelineRasterizationStateCreateInfo rasterizer = new VkPipelineRasterizationStateCreateInfo(); rasterizer.sType = VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO; rasterizer.lineWidth = 1.0f; VkPipelineMultisampleStateCreateInfo multisampling = new VkPipelineMultisampleStateCreateInfo(); multisampling.sType = VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO; multisampling.rasterizationSamples = VK_SAMPLE_COUNT_1_BIT; VkPipelineColorBlendAttachmentState colorBlendAttachment = new VkPipelineColorBlendAttachmentState(); colorBlendAttachment.colorWriteMask = 0xF; GCHandle colorBlendAttachmentHandle = GCHandle.Alloc(colorBlendAttachment, GCHandleType.Pinned); VkPipelineColorBlendStateCreateInfo colorBlending = new VkPipelineColorBlendStateCreateInfo(); colorBlending.sType = VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO; colorBlending.attachmentCount = 1; colorBlending.pAttachments = colorBlendAttachmentHandle.AddrOfPinnedObject(); IntPtr[] layouts = new IntPtr[] { descriptorSetLayout }; GCHandle layoutsHandle = GCHandle.Alloc(layouts, GCHandleType.Pinned); VkPipelineLayoutCreateInfo layoutInfo = new VkPipelineLayoutCreateInfo(); layoutInfo.sType = VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO; layoutInfo.setLayoutCount = 1; layoutInfo.pSetLayouts = layoutsHandle.AddrOfPinnedObject(); vkCreatePipelineLayout(device, ref layoutInfo, IntPtr.Zero, out graphicsPipelineLayout); layoutsHandle.Free(); GCHandle vertexInputHandle = GCHandle.Alloc(vertexInput, GCHandleType.Pinned); GCHandle inputAssemblyHandle = GCHandle.Alloc(inputAssembly, GCHandleType.Pinned); GCHandle viewportStateHandle = GCHandle.Alloc(viewportState, GCHandleType.Pinned); GCHandle rasterizerHandle = GCHandle.Alloc(rasterizer, GCHandleType.Pinned); GCHandle multisamplingHandle = GCHandle.Alloc(multisampling, GCHandleType.Pinned); GCHandle colorBlendingHandle = GCHandle.Alloc(colorBlending, GCHandleType.Pinned); VkGraphicsPipelineCreateInfo pipelineInfo = new VkGraphicsPipelineCreateInfo(); pipelineInfo.sType = VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO; pipelineInfo.stageCount = 2; pipelineInfo.pStages = stagesHandle.AddrOfPinnedObject(); pipelineInfo.pVertexInputState = vertexInputHandle.AddrOfPinnedObject(); pipelineInfo.pInputAssemblyState = inputAssemblyHandle.AddrOfPinnedObject(); pipelineInfo.pViewportState = viewportStateHandle.AddrOfPinnedObject(); pipelineInfo.pRasterizationState = rasterizerHandle.AddrOfPinnedObject(); pipelineInfo.pMultisampleState = multisamplingHandle.AddrOfPinnedObject(); pipelineInfo.pColorBlendState = colorBlendingHandle.AddrOfPinnedObject(); pipelineInfo.layout = graphicsPipelineLayout; pipelineInfo.renderPass = renderPass; vkCreateGraphicsPipelines(device, IntPtr.Zero, 1, ref pipelineInfo, IntPtr.Zero, out graphicsPipeline); stagesHandle.Free(); viewportHandle.Free(); scissorHandle.Free(); colorBlendAttachmentHandle.Free(); vertexInputHandle.Free(); inputAssemblyHandle.Free(); viewportStateHandle.Free(); rasterizerHandle.Free(); multisamplingHandle.Free(); colorBlendingHandle.Free(); Marshal.FreeHGlobal(mainName); }

    void CreateFramebuffers() { framebuffers = new IntPtr[swapchainImageViews.Length]; for (int i = 0; i < swapchainImageViews.Length; i++) { IntPtr[] attachments = new IntPtr[] { swapchainImageViews[i] }; GCHandle attachmentsHandle = GCHandle.Alloc(attachments, GCHandleType.Pinned); VkFramebufferCreateInfo framebufferInfo = new VkFramebufferCreateInfo(); framebufferInfo.sType = VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO; framebufferInfo.renderPass = renderPass; framebufferInfo.attachmentCount = 1; framebufferInfo.pAttachments = attachmentsHandle.AddrOfPinnedObject(); framebufferInfo.width = swapchainExtentWidth; framebufferInfo.height = swapchainExtentHeight; framebufferInfo.layers = 1; vkCreateFramebuffer(device, ref framebufferInfo, IntPtr.Zero, out framebuffers[i]); attachmentsHandle.Free(); } }

    void CreateCommandPool() { VkCommandPoolCreateInfo poolInfo = new VkCommandPoolCreateInfo(); poolInfo.sType = VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO; poolInfo.flags = VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT; poolInfo.queueFamilyIndex = queueFamilyIndex; vkCreateCommandPool(device, ref poolInfo, IntPtr.Zero, out commandPool); }

    void CreateCommandBuffers() { commandBuffers = new IntPtr[MAX_FRAMES_IN_FLIGHT]; VkCommandBufferAllocateInfo allocInfo = new VkCommandBufferAllocateInfo(); allocInfo.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO; allocInfo.commandPool = commandPool; allocInfo.level = VK_COMMAND_BUFFER_LEVEL_PRIMARY; allocInfo.commandBufferCount = MAX_FRAMES_IN_FLIGHT; vkAllocateCommandBuffers(device, ref allocInfo, commandBuffers); }

    void CreateSyncObjects() { imageAvailableSemaphores = new IntPtr[MAX_FRAMES_IN_FLIGHT]; renderFinishedSemaphores = new IntPtr[MAX_FRAMES_IN_FLIGHT]; inFlightFences = new IntPtr[MAX_FRAMES_IN_FLIGHT]; VkSemaphoreCreateInfo semInfo = new VkSemaphoreCreateInfo { sType = VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO }; VkFenceCreateInfo fenceInfo = new VkFenceCreateInfo { sType = VK_STRUCTURE_TYPE_FENCE_CREATE_INFO, flags = VK_FENCE_CREATE_SIGNALED_BIT }; for (int i = 0; i < MAX_FRAMES_IN_FLIGHT; i++) { vkCreateSemaphore(device, ref semInfo, IntPtr.Zero, out imageAvailableSemaphores[i]); vkCreateSemaphore(device, ref semInfo, IntPtr.Zero, out renderFinishedSemaphores[i]); vkCreateFence(device, ref fenceInfo, IntPtr.Zero, out inFlightFences[i]); } }

    void InitUBO() { uboParams = new ParamsUBO(); uboParams.max_num = VERTEX_COUNT; uboParams.dt = 0.001f; uboParams.scale = 0.02f; uboParams.A1 = 50; uboParams.f1 = 2.0f; uboParams.p1 = 1.0f / 16; uboParams.d1 = 0.02f; uboParams.A2 = 50; uboParams.f2 = 2.0f; uboParams.p2 = 3.0f / 2; uboParams.d2 = 0.0215f; uboParams.A3 = 50; uboParams.f3 = 2.0f; uboParams.p3 = 13.0f / 15; uboParams.d3 = 0.025f; uboParams.A4 = 50; uboParams.f4 = 2.0f; uboParams.p4 = 1.0f; uboParams.d4 = 0.0315f; }

    void UpdateUBO() { animTime += 0.016f; uboParams.f1 = 2.0f + 0.5f * (float)Math.Sin(animTime * 0.7); uboParams.f2 = 2.0f + 0.5f * (float)Math.Sin(animTime * 0.9); uboParams.f3 = 2.0f + 0.5f * (float)Math.Sin(animTime * 1.1); uboParams.f4 = 2.0f + 0.5f * (float)Math.Sin(animTime * 1.3); uboParams.p1 += 0.002f; IntPtr data; vkMapMemory(device, uboMemory, 0, (ulong)Marshal.SizeOf(typeof(ParamsUBO)), 0, out data); Marshal.StructureToPtr(uboParams, data, false); vkUnmapMemory(device, uboMemory); }

    void DrawFrame() { if (device == IntPtr.Zero) return; IntPtr[] fences = new IntPtr[] { inFlightFences[currentFrame] }; vkWaitForFences(device, 1, fences, VK_TRUE, VK_WHOLE_SIZE); uint imageIndex; int result = vkAcquireNextImageKHR(device, swapchain, VK_WHOLE_SIZE, imageAvailableSemaphores[currentFrame], IntPtr.Zero, out imageIndex); if (result == VK_ERROR_OUT_OF_DATE_KHR) { RecreateSwapchain(); return; } vkResetFences(device, 1, fences); UpdateUBO(); IntPtr cmd = commandBuffers[currentFrame]; vkResetCommandBuffer(cmd, 0); VkCommandBufferBeginInfo beginInfo = new VkCommandBufferBeginInfo { sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO }; vkBeginCommandBuffer(cmd, ref beginInfo); vkCmdBindPipeline(cmd, VK_PIPELINE_BIND_POINT_COMPUTE, computePipeline); IntPtr[] descSets = new IntPtr[] { descriptorSet }; vkCmdBindDescriptorSets(cmd, VK_PIPELINE_BIND_POINT_COMPUTE, computePipelineLayout, 0, 1, descSets, 0, IntPtr.Zero); vkCmdDispatch(cmd, (VERTEX_COUNT + 255) / 256, 1, 1); VkBufferMemoryBarrier barrier1 = new VkBufferMemoryBarrier { sType = VK_STRUCTURE_TYPE_BUFFER_MEMORY_BARRIER, srcAccessMask = VK_ACCESS_SHADER_WRITE_BIT, dstAccessMask = VK_ACCESS_SHADER_READ_BIT, srcQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED, dstQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED, buffer = posBuffer, size = VERTEX_COUNT * 16 }; VkBufferMemoryBarrier barrier2 = new VkBufferMemoryBarrier { sType = VK_STRUCTURE_TYPE_BUFFER_MEMORY_BARRIER, srcAccessMask = VK_ACCESS_SHADER_WRITE_BIT, dstAccessMask = VK_ACCESS_SHADER_READ_BIT, srcQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED, dstQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED, buffer = colBuffer, size = VERTEX_COUNT * 16 }; int barrierSize = Marshal.SizeOf(typeof(VkBufferMemoryBarrier)); IntPtr barrierPtr = Marshal.AllocHGlobal(barrierSize * 2); Marshal.StructureToPtr(barrier1, barrierPtr, false); Marshal.StructureToPtr(barrier2, new IntPtr(barrierPtr.ToInt64() + barrierSize), false); vkCmdPipelineBarrier(cmd, VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT, VK_PIPELINE_STAGE_VERTEX_SHADER_BIT, 0, 0, IntPtr.Zero, 2, barrierPtr, 0, IntPtr.Zero); Marshal.FreeHGlobal(barrierPtr); VkClearValue clearColor = new VkClearValue { color = new VkClearColorValue { r = 0, g = 0, b = 0, a = 1 } }; GCHandle clearColorHandle = GCHandle.Alloc(clearColor, GCHandleType.Pinned); VkRenderPassBeginInfo renderPassBeginInfo = new VkRenderPassBeginInfo(); renderPassBeginInfo.sType = VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO; renderPassBeginInfo.renderPass = renderPass; renderPassBeginInfo.framebuffer = framebuffers[imageIndex]; renderPassBeginInfo.renderArea.extent.width = swapchainExtentWidth; renderPassBeginInfo.renderArea.extent.height = swapchainExtentHeight; renderPassBeginInfo.clearValueCount = 1; renderPassBeginInfo.pClearValues = clearColorHandle.AddrOfPinnedObject(); vkCmdBeginRenderPass(cmd, ref renderPassBeginInfo, VK_SUBPASS_CONTENTS_INLINE); clearColorHandle.Free(); vkCmdBindPipeline(cmd, VK_PIPELINE_BIND_POINT_GRAPHICS, graphicsPipeline); vkCmdBindDescriptorSets(cmd, VK_PIPELINE_BIND_POINT_GRAPHICS, graphicsPipelineLayout, 0, 1, descSets, 0, IntPtr.Zero); vkCmdDraw(cmd, VERTEX_COUNT, 1, 0, 0); vkCmdEndRenderPass(cmd); vkEndCommandBuffer(cmd); IntPtr[] waitSemaphores = new IntPtr[] { imageAvailableSemaphores[currentFrame] }; IntPtr[] signalSemaphores = new IntPtr[] { renderFinishedSemaphores[currentFrame] }; uint[] waitStages = new uint[] { VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT }; IntPtr[] cmdBuffers = new IntPtr[] { cmd }; GCHandle waitSemaphoresHandle = GCHandle.Alloc(waitSemaphores, GCHandleType.Pinned); GCHandle signalSemaphoresHandle = GCHandle.Alloc(signalSemaphores, GCHandleType.Pinned); GCHandle waitStagesHandle = GCHandle.Alloc(waitStages, GCHandleType.Pinned); GCHandle cmdBuffersHandle = GCHandle.Alloc(cmdBuffers, GCHandleType.Pinned); VkSubmitInfo submitInfo = new VkSubmitInfo(); submitInfo.sType = VK_STRUCTURE_TYPE_SUBMIT_INFO; submitInfo.waitSemaphoreCount = 1; submitInfo.pWaitSemaphores = waitSemaphoresHandle.AddrOfPinnedObject(); submitInfo.pWaitDstStageMask = waitStagesHandle.AddrOfPinnedObject(); submitInfo.commandBufferCount = 1; submitInfo.pCommandBuffers = cmdBuffersHandle.AddrOfPinnedObject(); submitInfo.signalSemaphoreCount = 1; submitInfo.pSignalSemaphores = signalSemaphoresHandle.AddrOfPinnedObject(); vkQueueSubmit(queue, 1, ref submitInfo, inFlightFences[currentFrame]); waitSemaphoresHandle.Free(); waitStagesHandle.Free(); cmdBuffersHandle.Free(); IntPtr[] swapchains = new IntPtr[] { swapchain }; uint[] imageIndices = new uint[] { imageIndex }; GCHandle swapchainsHandle = GCHandle.Alloc(swapchains, GCHandleType.Pinned); GCHandle imageIndicesHandle = GCHandle.Alloc(imageIndices, GCHandleType.Pinned); VkPresentInfoKHR presentInfo = new VkPresentInfoKHR(); presentInfo.sType = VK_STRUCTURE_TYPE_PRESENT_INFO_KHR; presentInfo.waitSemaphoreCount = 1; presentInfo.pWaitSemaphores = signalSemaphoresHandle.AddrOfPinnedObject(); presentInfo.swapchainCount = 1; presentInfo.pSwapchains = swapchainsHandle.AddrOfPinnedObject(); presentInfo.pImageIndices = imageIndicesHandle.AddrOfPinnedObject(); result = vkQueuePresentKHR(queue, ref presentInfo); signalSemaphoresHandle.Free(); swapchainsHandle.Free(); imageIndicesHandle.Free(); if (result == VK_ERROR_OUT_OF_DATE_KHR || result == VK_SUBOPTIMAL_KHR || framebufferResized) { framebufferResized = false; RecreateSwapchain(); } currentFrame = (currentFrame + 1) % MAX_FRAMES_IN_FLIGHT; }

    void CleanupSwapchain() { for (int i = 0; i < framebuffers.Length; i++) vkDestroyFramebuffer(device, framebuffers[i], IntPtr.Zero); vkDestroyPipeline(device, graphicsPipeline, IntPtr.Zero); vkDestroyPipelineLayout(device, graphicsPipelineLayout, IntPtr.Zero); for (int i = 0; i < swapchainImageViews.Length; i++) vkDestroyImageView(device, swapchainImageViews[i], IntPtr.Zero); vkDestroySwapchainKHR(device, swapchain, IntPtr.Zero); }

    void RecreateSwapchain() { if (ClientSize.Width == 0 || ClientSize.Height == 0) return; vkDeviceWaitIdle(device); CleanupSwapchain(); CreateSwapchain(); CreateImageViews(); CreateGraphicsPipeline(); CreateFramebuffers(); }

    void Cleanup() { if (device == IntPtr.Zero) return; vkDeviceWaitIdle(device); vkDestroyBuffer(device, posBuffer, IntPtr.Zero); vkFreeMemory(device, posMemory, IntPtr.Zero); vkDestroyBuffer(device, colBuffer, IntPtr.Zero); vkFreeMemory(device, colMemory, IntPtr.Zero); vkDestroyBuffer(device, uboBuffer, IntPtr.Zero); vkFreeMemory(device, uboMemory, IntPtr.Zero); vkDestroyDescriptorPool(device, descriptorPool, IntPtr.Zero); vkDestroyDescriptorSetLayout(device, descriptorSetLayout, IntPtr.Zero); for (int i = 0; i < MAX_FRAMES_IN_FLIGHT; i++) { vkDestroySemaphore(device, imageAvailableSemaphores[i], IntPtr.Zero); vkDestroySemaphore(device, renderFinishedSemaphores[i], IntPtr.Zero); vkDestroyFence(device, inFlightFences[i], IntPtr.Zero); } vkDestroyCommandPool(device, commandPool, IntPtr.Zero); vkDestroyPipeline(device, computePipeline, IntPtr.Zero); vkDestroyPipelineLayout(device, computePipelineLayout, IntPtr.Zero); vkDestroyShaderModule(device, compShaderModule, IntPtr.Zero); vkDestroyShaderModule(device, vertShaderModule, IntPtr.Zero); vkDestroyShaderModule(device, fragShaderModule, IntPtr.Zero); for (int i = 0; i < framebuffers.Length; i++) vkDestroyFramebuffer(device, framebuffers[i], IntPtr.Zero); vkDestroyPipeline(device, graphicsPipeline, IntPtr.Zero); vkDestroyPipelineLayout(device, graphicsPipelineLayout, IntPtr.Zero); vkDestroyRenderPass(device, renderPass, IntPtr.Zero); for (int i = 0; i < swapchainImageViews.Length; i++) vkDestroyImageView(device, swapchainImageViews[i], IntPtr.Zero); vkDestroySwapchainKHR(device, swapchain, IntPtr.Zero); vkDestroyDevice(device, IntPtr.Zero); vkDestroySurfaceKHR(instance, surface, IntPtr.Zero); vkDestroyInstance(instance, IntPtr.Zero); }
}
'@

Write-Host "Vulkan 1.4 Compute Harmonograph (PowerShell)"
Write-Host "============================================="
Write-Host "Runtime shader compilation using shaderc_shared.dll"
Write-Host ""

try {
    Add-Type -TypeDefinition $VulkanCode -ReferencedAssemblies @('System.Windows.Forms', 'System.Drawing', 'System.Drawing.Primitives') -Language CSharp
    [System.Windows.Forms.Application]::EnableVisualStyles()
    [System.Windows.Forms.Application]::SetCompatibleTextRenderingDefault($false)
    $form = New-Object VulkanHarmonograph
    [System.Windows.Forms.Application]::Run($form)
}
catch {
    Write-Host "Error: $_"
    Write-Host ""
    Write-Host "Requirements:"
    Write-Host "  1. Windows + Vulkan 1.4 GPU/drivers"
    Write-Host "  2. shaderc_shared.dll in current directory or PATH"
    Write-Host "  3. vulkan-1.dll in PATH"
}
