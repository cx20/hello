program hello;

{$mode delphi}
// Ensure Vulkan structs use C-compatible packing/alignment.
// IMPORTANT: Do NOT use "record" for Vulkan structs; drivers may assume natural alignment.
{$PACKRECORDS C}
{$apptype gui}
{$H+}

uses
  Windows, Messages, SysUtils, Classes, Math;

(*
  Vulkan 1.4 Harmonograph (Compute + Graphics) (Windows, Free Pascal, no external Pascal libs)

  - Win32 window (Windows unit)
  - Vulkan loaded dynamically from vulkan-1.dll
  - Compute shader generates harmonograph points into storage buffers
  - Graphics pipeline renders points using gl_VertexIndex
  - SPIR-V shaders loaded from hello_vert.spv / hello_frag.spv / hello_comp.spv

  Build:
    glslc.exe hello.vert -o hello_vert.spv
    glslc.exe hello.frag -o hello_frag.spv
    glslc.exe hello.comp -o hello_comp.spv
    build.bat
*)

type
  // ------------------------------------------------------------
  // Vulkan base types
  // ------------------------------------------------------------
  VkFlags      = UInt32;
  VkBool32     = UInt32;
  VkDeviceSize = UInt64;
  VkResult     = Int32;

  // Dispatchable handles (pointers)
  VkInstance       = Pointer;
  VkPhysicalDevice = Pointer;
	PVkPhysicalDevice = ^VkPhysicalDevice;
  VkDevice         = Pointer;
  VkQueue          = Pointer;
  VkCommandPool    = Pointer;
  VkCommandBuffer  = Pointer;
  PVkCommandBuffer  = ^VkCommandBuffer;

  // Non-dispatchable handles (uint64)
  VkSurfaceKHR     = UInt64;
  VkSwapchainKHR   = UInt64;
  VkImage          = UInt64;
  VkImageView      = UInt64;
  VkShaderModule   = UInt64;
  VkRenderPass     = UInt64;
  VkPipelineLayout = UInt64;
  VkPipeline       = UInt64;
  VkFramebuffer    = UInt64;
  VkBuffer         = UInt64;
  VkDeviceMemory   = UInt64;
  VkDescriptorSetLayout = UInt64;
  VkDescriptorPool = UInt64;
  VkDescriptorSet  = UInt64;
  VkSemaphore      = UInt64;
  VkFence          = UInt64;

  PVkSurfaceKHR   = ^VkSurfaceKHR;
  PVkSwapchainKHR = ^VkSwapchainKHR;
  PVkImage        = ^VkImage;
  PVkImageView    = ^VkImageView;
  PVkSemaphore    = ^VkSemaphore;
  PVkFence        = ^VkFence;
  PVkDescriptorSet = ^VkDescriptorSet;

const
  VK_SUCCESS = 0;
  VK_SUBOPTIMAL_KHR = 1000001003;

  // shaderc (C API)
  SHADERC_DLL = 'shaderc_shared.dll';
  shaderc_compilation_status_success = 0;
  shaderc_glsl_vertex_shader = 0;
  shaderc_glsl_fragment_shader = 1;
  VK_ERROR_OUT_OF_DATE_KHR = -1000001004;

  // API version helpers (VK_MAKE_API_VERSION variant)
  VK_API_VERSION_1_4 = (1 shl 22) or (4 shl 12) or 0;

  // Structure types
  VK_STRUCTURE_TYPE_APPLICATION_INFO                         = 0;
  VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO                     = 1;
  VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO                 = 2;
  VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO                       = 3;
  VK_STRUCTURE_TYPE_WIN32_SURFACE_CREATE_INFO_KHR            = 1000009000;
  VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR                = 1000001000;
  VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO                   = 15;
  VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO                = 16;
  VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO        = 18;
  VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO  = 19;
  VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO= 20;
  VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO      = 22;
  VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO = 23;
  VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO   = 24;
  VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO   = 26;
  VK_STRUCTURE_TYPE_PIPELINE_DYNAMIC_STATE_CREATE_INFO       = 27;
  VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO              = 30;
  VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO            = 28;
  VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO                  = 38;
  VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO                  = 37;
  VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO                 = 39;
  VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO             = 40;
  VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO                = 42;
  VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO                   = 43;
  VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO                    = 9;
  VK_STRUCTURE_TYPE_FENCE_CREATE_INFO                        = 8;
  VK_STRUCTURE_TYPE_SUBMIT_INFO                              = 4;
  VK_STRUCTURE_TYPE_PRESENT_INFO_KHR                         = 1000001002;
  VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO                       = 12;
  VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO                     = 5;
  VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO        = 33;
  VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO              = 34;
  VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO             = 35;
  VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET                     = 36;
  VK_STRUCTURE_TYPE_COMPUTE_PIPELINE_CREATE_INFO             = 29;
  VK_STRUCTURE_TYPE_BUFFER_MEMORY_BARRIER                    = 44;

  // Extensions
  VK_KHR_SURFACE_EXTENSION_NAME       = 'VK_KHR_surface';
  VK_KHR_WIN32_SURFACE_EXTENSION_NAME = 'VK_KHR_win32_surface';
  VK_KHR_SWAPCHAIN_EXTENSION_NAME     = 'VK_KHR_swapchain';

  // Queue flags
  VK_QUEUE_GRAPHICS_BIT = $00000001;

  // Command pool flags
  VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT = $00000002;

  // Pipeline
  VK_PIPELINE_BIND_POINT_GRAPHICS = 0;
  VK_PIPELINE_BIND_POINT_COMPUTE  = 1;
  VK_PRIMITIVE_TOPOLOGY_POINT_LIST = 0;
  VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST = 3;
  VK_POLYGON_MODE_FILL = 0;
  VK_CULL_MODE_NONE = 0;
  VK_FRONT_FACE_COUNTER_CLOCKWISE = 1;
  VK_SAMPLE_COUNT_1_BIT = 1;

  VK_COLOR_COMPONENT_R_BIT = $1;
  VK_COLOR_COMPONENT_G_BIT = $2;
  VK_COLOR_COMPONENT_B_BIT = $4;
  VK_COLOR_COMPONENT_A_BIT = $8;

  VK_DYNAMIC_STATE_VIEWPORT = 0;
  VK_DYNAMIC_STATE_SCISSOR  = 1;

  // Image / layout
  VK_IMAGE_ASPECT_COLOR_BIT = $1;
  VK_IMAGE_VIEW_TYPE_2D = 1;

  VK_IMAGE_LAYOUT_UNDEFINED = 0;
  VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL = 2;
  VK_IMAGE_LAYOUT_PRESENT_SRC_KHR = 1000001002;

  // Attachment
  VK_ATTACHMENT_LOAD_OP_CLEAR  = 1;
  VK_ATTACHMENT_STORE_OP_STORE = 0;

  // Sharing mode
  VK_SHARING_MODE_EXCLUSIVE  = 0;
  VK_SHARING_MODE_CONCURRENT = 1;

  // Present mode
  VK_PRESENT_MODE_FIFO_KHR = 2;

  // Composite alpha / transform
  VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR = $00000001;
  VK_SURFACE_TRANSFORM_IDENTITY_BIT_KHR = $00000001;

  // Pipeline stage
  VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT = $00000400;
  VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT = $00000800;
  VK_PIPELINE_STAGE_VERTEX_SHADER_BIT  = $00000008;

  VK_ACCESS_SHADER_READ_BIT  = $00000020;
  VK_ACCESS_SHADER_WRITE_BIT = $00000040;

  // Fence
  VK_FENCE_CREATE_SIGNALED_BIT = $00000001;

  // Command buffer
  VK_COMMAND_BUFFER_LEVEL_PRIMARY = 0;

  // Shader stage
  VK_SHADER_STAGE_VERTEX_BIT   = $00000001;
  VK_SHADER_STAGE_FRAGMENT_BIT = $00000010;
  VK_SHADER_STAGE_COMPUTE_BIT  = $00000020;

  // Image usage
  VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT = $00000010;

  // Buffer usage
  VK_BUFFER_USAGE_STORAGE_BUFFER_BIT = $00000020;
  VK_BUFFER_USAGE_UNIFORM_BUFFER_BIT = $00000010;

  // Memory properties
  VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT  = $00000002;
  VK_MEMORY_PROPERTY_HOST_COHERENT_BIT = $00000004;

  // Descriptor types
  VK_DESCRIPTOR_TYPE_STORAGE_BUFFER = 7;
  VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER = 6;

  VK_QUEUE_FAMILY_IGNORED = $FFFFFFFF;

  // Common format
  VK_FORMAT_B8G8R8A8_UNORM = 44;

  NUM_HARMONOGRAPH_POINTS = 500000;

type
  // ------------------------------------------------------------
  // Vulkan structs (minimal)
  // ------------------------------------------------------------
  PVkChar = PAnsiChar;

  TVkExtent2D = record
    width: UInt32;
    height: UInt32;
  end;

  TVkOffset2D = record
    x: Int32;
    y: Int32;
  end;

  TVkRect2D = record
    offset: TVkOffset2D;
    extent: TVkExtent2D;
  end;
  PVkRect2D = ^TVkRect2D;

  TVkBufferCreateInfo = record
    sType: UInt32;
    pNext: Pointer;
    flags: UInt32;
    size: VkDeviceSize;
    usage: UInt32;
    sharingMode: UInt32;
    queueFamilyIndexCount: UInt32;
    pQueueFamilyIndices: PUInt32;
  end;
  PVkBufferCreateInfo = ^TVkBufferCreateInfo;

  TVkMemoryRequirements = record
    size: VkDeviceSize;
    alignment: VkDeviceSize;
    memoryTypeBits: UInt32;
  end;
  PVkMemoryRequirements = ^TVkMemoryRequirements;

  TVkMemoryAllocateInfo = record
    sType: UInt32;
    pNext: Pointer;
    allocationSize: VkDeviceSize;
    memoryTypeIndex: UInt32;
  end;
  PVkMemoryAllocateInfo = ^TVkMemoryAllocateInfo;

  TVkMemoryHeap = record
    size: VkDeviceSize;
    flags: UInt32;
  end;

  TVkPhysicalDeviceMemoryProperties = record
    memoryTypeCount: UInt32;
    memoryTypes: array[0..31] of record
      propertyFlags: UInt32;
      heapIndex: UInt32;
    end;
    memoryHeapCount: UInt32;
    memoryHeaps: array[0..15] of TVkMemoryHeap;
  end;

  TVkDescriptorSetLayoutBinding = record
    binding: UInt32;
    descriptorType: UInt32;
    descriptorCount: UInt32;
    stageFlags: UInt32;
    pImmutableSamplers: Pointer;
  end;
  PVkDescriptorSetLayoutBinding = ^TVkDescriptorSetLayoutBinding;

  TVkDescriptorSetLayoutCreateInfo = record
    sType: UInt32;
    pNext: Pointer;
    flags: UInt32;
    bindingCount: UInt32;
    pBindings: PVkDescriptorSetLayoutBinding;
  end;
  PVkDescriptorSetLayoutCreateInfo = ^TVkDescriptorSetLayoutCreateInfo;

  TVkDescriptorPoolSize = record
    type_: UInt32;
    descriptorCount: UInt32;
  end;

  TVkDescriptorPoolCreateInfo = record
    sType: UInt32;
    pNext: Pointer;
    flags: UInt32;
    maxSets: UInt32;
    poolSizeCount: UInt32;
    pPoolSizes: ^TVkDescriptorPoolSize;
  end;
  PVkDescriptorPoolCreateInfo = ^TVkDescriptorPoolCreateInfo;

  TVkDescriptorSetAllocateInfo = record
    sType: UInt32;
    pNext: Pointer;
    descriptorPool: VkDescriptorPool;
    descriptorSetCount: UInt32;
    pSetLayouts: ^VkDescriptorSetLayout;
  end;
  PVkDescriptorSetAllocateInfo = ^TVkDescriptorSetAllocateInfo;

  TVkDescriptorBufferInfo = record
    buffer: VkBuffer;
    offset: VkDeviceSize;
    range: VkDeviceSize;
  end;
  PVkDescriptorBufferInfo = ^TVkDescriptorBufferInfo;

  TVkWriteDescriptorSet = record
    sType: UInt32;
    pNext: Pointer;
    dstSet: VkDescriptorSet;
    dstBinding: UInt32;
    dstArrayElement: UInt32;
    descriptorCount: UInt32;
    descriptorType: UInt32;
    pImageInfo: Pointer;
    pBufferInfo: PVkDescriptorBufferInfo;
    pTexelBufferView: Pointer;
  end;
  PVkWriteDescriptorSet = ^TVkWriteDescriptorSet;

  TVkBufferMemoryBarrier = record
    sType: UInt32;
    pNext: Pointer;
    srcAccessMask: UInt32;
    dstAccessMask: UInt32;
    srcQueueFamilyIndex: UInt32;
    dstQueueFamilyIndex: UInt32;
    buffer: VkBuffer;
    offset: VkDeviceSize;
    size: VkDeviceSize;
  end;
  PVkBufferMemoryBarrier = ^TVkBufferMemoryBarrier;

  TVkApplicationInfo = record
    sType: UInt32;
    pNext: Pointer;
    pApplicationName: PVkChar;
    applicationVersion: UInt32;
    pEngineName: PVkChar;
    engineVersion: UInt32;
    apiVersion: UInt32;
  end;
  PVkApplicationInfo = ^TVkApplicationInfo;

  TVkInstanceCreateInfo = record
    sType: UInt32;
    pNext: Pointer;
    flags: UInt32;
    pApplicationInfo: PVkApplicationInfo;
    enabledLayerCount: UInt32;
    ppEnabledLayerNames: PPAnsiChar;
    enabledExtensionCount: UInt32;
    ppEnabledExtensionNames: PPAnsiChar;
  end;
  PVkInstanceCreateInfo = ^TVkInstanceCreateInfo;

  TVkWin32SurfaceCreateInfoKHR = record
    sType: UInt32;
    pNext: Pointer;
    flags: UInt32;
    hinstance: HINST;
    hwnd: HWND;
  end;
  PVkWin32SurfaceCreateInfoKHR = ^TVkWin32SurfaceCreateInfoKHR;

  TVkSurfaceCapabilitiesKHR = record
    minImageCount: UInt32;
    maxImageCount: UInt32;
    currentExtent: TVkExtent2D;
    minImageExtent: TVkExtent2D;
    maxImageExtent: TVkExtent2D;
    maxImageArrayLayers: UInt32;
    supportedTransforms: UInt32;
    currentTransform: UInt32;
    supportedCompositeAlpha: UInt32;
    supportedUsageFlags: UInt32;
  end;
  PVkSurfaceCapabilitiesKHR = ^TVkSurfaceCapabilitiesKHR;

  TVkSurfaceFormatKHR = record
    format: UInt32;
    colorSpace: UInt32;
  end;
  PVkSurfaceFormatKHR = ^TVkSurfaceFormatKHR;

  TVkDeviceQueueCreateInfo = record
    sType: UInt32;
    pNext: Pointer;
    flags: UInt32;
    queueFamilyIndex: UInt32;
    queueCount: UInt32;
    pQueuePriorities: PSingle;
  end;
  PVkDeviceQueueCreateInfo = ^TVkDeviceQueueCreateInfo;

  TVkDeviceCreateInfo = record
    sType: UInt32;
    pNext: Pointer;
    flags: UInt32;
    queueCreateInfoCount: UInt32;
    pQueueCreateInfos: PVkDeviceQueueCreateInfo;
    enabledLayerCount: UInt32;
    ppEnabledLayerNames: PPAnsiChar;
    enabledExtensionCount: UInt32;
    ppEnabledExtensionNames: PPAnsiChar;
    pEnabledFeatures: Pointer;
  end;
  PVkDeviceCreateInfo = ^TVkDeviceCreateInfo;

  TVkExtent3D = record
    width: UInt32;
    height: UInt32;
    depth: UInt32;
  end;

  TVkQueueFamilyProperties = record
    queueFlags: UInt32;
    queueCount: UInt32;
    timestampValidBits: UInt32;
    minImageTransferGranularity: TVkExtent3D;
  end;
  PVkQueueFamilyProperties = ^TVkQueueFamilyProperties;

  TVkSwapchainCreateInfoKHR = record
    sType: UInt32;
    pNext: Pointer;
    flags: UInt32;
    surface: VkSurfaceKHR;
    minImageCount: UInt32;
    imageFormat: UInt32;
    imageColorSpace: UInt32;
    imageExtent: TVkExtent2D;
    imageArrayLayers: UInt32;
    imageUsage: UInt32;
    imageSharingMode: UInt32;
    queueFamilyIndexCount: UInt32;
    pQueueFamilyIndices: PUInt32;
    preTransform: UInt32;
    compositeAlpha: UInt32;
    presentMode: UInt32;
    clipped: VkBool32;
    oldSwapchain: VkSwapchainKHR;
  end;
  PVkSwapchainCreateInfoKHR = ^TVkSwapchainCreateInfoKHR;

  TVkComponentMapping = record
    r, g, b, a: UInt32;
  end;

  TVkImageSubresourceRange = record
    aspectMask: UInt32;
    baseMipLevel: UInt32;
    levelCount: UInt32;
    baseArrayLayer: UInt32;
    layerCount: UInt32;
  end;

  TVkImageViewCreateInfo = record
    sType: UInt32;
    pNext: Pointer;
    flags: UInt32;
    image: VkImage;
    viewType: UInt32;
    format: UInt32;
    components: TVkComponentMapping;
    subresourceRange: TVkImageSubresourceRange;
  end;
  PVkImageViewCreateInfo = ^TVkImageViewCreateInfo;

  TVkAttachmentDescription = record
    flags: UInt32;
    format: UInt32;
    samples: UInt32;
    loadOp: UInt32;
    storeOp: UInt32;
    stencilLoadOp: UInt32;
    stencilStoreOp: UInt32;
    initialLayout: UInt32;
    finalLayout: UInt32;
  end;

  TVkAttachmentReference = record
    attachment: UInt32;
    layout: UInt32;
  end;
  PVkAttachmentReference = ^TVkAttachmentReference;

  TVkSubpassDescription = record
    flags: UInt32;
    pipelineBindPoint: UInt32;
    inputAttachmentCount: UInt32;
    pInputAttachments: Pointer;
    colorAttachmentCount: UInt32;
    pColorAttachments: PVkAttachmentReference;
    pResolveAttachments: Pointer;
    pDepthStencilAttachment: Pointer;
    preserveAttachmentCount: UInt32;
    pPreserveAttachments: Pointer;
  end;

  TVkRenderPassCreateInfo = record
    sType: UInt32;
    pNext: Pointer;
    flags: UInt32;
    attachmentCount: UInt32;
    pAttachments: ^TVkAttachmentDescription;
    subpassCount: UInt32;
    pSubpasses: ^TVkSubpassDescription;
    dependencyCount: UInt32;
    pDependencies: Pointer;
  end;
  PVkRenderPassCreateInfo = ^TVkRenderPassCreateInfo;

  TVkShaderModuleCreateInfo = record
    sType: UInt32;
    pNext: Pointer;
    flags: UInt32;
    codeSize: NativeUInt;
    pCode: PUInt32;
  end;
  PVkShaderModuleCreateInfo = ^TVkShaderModuleCreateInfo;

  TVkPipelineShaderStageCreateInfo = record
    sType: UInt32;
    pNext: Pointer;
    flags: UInt32;
    stage: UInt32;
    module_: VkShaderModule;
    pName: PVkChar;
    pSpecializationInfo: Pointer;
  end;
  PVkPipelineShaderStageCreateInfo = ^TVkPipelineShaderStageCreateInfo;

  TVkComputePipelineCreateInfo = record
    sType: UInt32;
    pNext: Pointer;
    flags: UInt32;
    stage: TVkPipelineShaderStageCreateInfo;
    layout: VkPipelineLayout;
    basePipelineHandle: VkPipeline;
    basePipelineIndex: Int32;
  end;
  PVkComputePipelineCreateInfo = ^TVkComputePipelineCreateInfo;

  TVkPipelineVertexInputStateCreateInfo = record
    sType: UInt32;
    pNext: Pointer;
    flags: UInt32;
    vertexBindingDescriptionCount: UInt32;
    pVertexBindingDescriptions: Pointer;
    vertexAttributeDescriptionCount: UInt32;
    pVertexAttributeDescriptions: Pointer;
  end;

  TVkPipelineInputAssemblyStateCreateInfo = record
    sType: UInt32;
    pNext: Pointer;
    flags: UInt32;
    topology: UInt32;
    primitiveRestartEnable: VkBool32;
  end;

  TVkViewport = record
    x, y, width, height, minDepth, maxDepth: Single;
  end;
  PVkViewport = ^TVkViewport;

  TVkPipelineViewportStateCreateInfo = record
    sType: UInt32;
    pNext: Pointer;
    flags: UInt32;
    viewportCount: UInt32;
    pViewports: PVkViewport;
    scissorCount: UInt32;
    pScissors: ^TVkRect2D;
  end;

  TVkPipelineRasterizationStateCreateInfo = record
    sType: UInt32;
    pNext: Pointer;
    flags: UInt32;
    depthClampEnable: VkBool32;
    rasterizerDiscardEnable: VkBool32;
    polygonMode: UInt32;
    cullMode: UInt32;
    frontFace: UInt32;
    depthBiasEnable: VkBool32;
    depthBiasConstantFactor: Single;
    depthBiasClamp: Single;
    depthBiasSlopeFactor: Single;
    lineWidth: Single;
  end;

  TVkPipelineMultisampleStateCreateInfo = record
    sType: UInt32;
    pNext: Pointer;
    flags: UInt32;
    rasterizationSamples: UInt32;
    sampleShadingEnable: VkBool32;
    minSampleShading: Single;
    pSampleMask: Pointer;
    alphaToCoverageEnable: VkBool32;
    alphaToOneEnable: VkBool32;
  end;

  TVkPipelineColorBlendAttachmentState = record
    blendEnable: VkBool32;
    srcColorBlendFactor: UInt32;
    dstColorBlendFactor: UInt32;
    colorBlendOp: UInt32;
    srcAlphaBlendFactor: UInt32;
    dstAlphaBlendFactor: UInt32;
    alphaBlendOp: UInt32;
    colorWriteMask: UInt32;
  end;
  PVkPipelineColorBlendAttachmentState = ^TVkPipelineColorBlendAttachmentState;

  TVkPipelineColorBlendStateCreateInfo = record
    sType: UInt32;
    pNext: Pointer;
    flags: UInt32;
    logicOpEnable: VkBool32;
    logicOp: UInt32;
    attachmentCount: UInt32;
    pAttachments: PVkPipelineColorBlendAttachmentState;
    blendConstants: array[0..3] of Single;
  end;

  TVkPipelineDynamicStateCreateInfo = record
    sType: UInt32;
    pNext: Pointer;
    flags: UInt32;
    dynamicStateCount: UInt32;
    pDynamicStates: PUInt32;
  end;

  TVkPipelineLayoutCreateInfo = record
    sType: UInt32;
    pNext: Pointer;
    flags: UInt32;
    setLayoutCount: UInt32;
    pSetLayouts: Pointer;
    pushConstantRangeCount: UInt32;
    pPushConstantRanges: Pointer;
  end;
  PVkPipelineLayoutCreateInfo = ^TVkPipelineLayoutCreateInfo;

  TVkPushConstantRange = record
    stageFlags: UInt32;
    offset: UInt32;
    size: UInt32;
  end;
  PVkPushConstantRange = ^TVkPushConstantRange;

  TPushConstants = record
    iTime: Single;
    padding: Single;
    iResolution: array[0..1] of Single;
  end;

  TComputeParams = record
    max_num: UInt32;
    dt: Single;
    scale: Single;
    pad0: Single;
    A1, f1, p1, d1: Single;
    A2, f2, p2, d2: Single;
    A3, f3, p3, d3: Single;
    A4, f4, p4, d4: Single;
  end;

  TVkGraphicsPipelineCreateInfo = record
    sType: UInt32;
    pNext: Pointer;
    flags: UInt32;
    stageCount: UInt32;
    pStages: PVkPipelineShaderStageCreateInfo;
    pVertexInputState: ^TVkPipelineVertexInputStateCreateInfo;
    pInputAssemblyState: ^TVkPipelineInputAssemblyStateCreateInfo;
    pTessellationState: Pointer;
    pViewportState: ^TVkPipelineViewportStateCreateInfo;
    pRasterizationState: ^TVkPipelineRasterizationStateCreateInfo;
    pMultisampleState: ^TVkPipelineMultisampleStateCreateInfo;
    pDepthStencilState: Pointer;
    pColorBlendState: ^TVkPipelineColorBlendStateCreateInfo;
    pDynamicState: ^TVkPipelineDynamicStateCreateInfo;
    layout: VkPipelineLayout;
    renderPass: VkRenderPass;
    subpass: UInt32;
    basePipelineHandle: VkPipeline;
    basePipelineIndex: Int32;
  end;
  PVkGraphicsPipelineCreateInfo = ^TVkGraphicsPipelineCreateInfo;


  TVkFramebufferCreateInfo = record
    sType: UInt32;
    pNext: Pointer;
    flags: UInt32;
    renderPass: VkRenderPass;
    attachmentCount: UInt32;
    pAttachments: PVkImageView;
    width: UInt32;
    height: UInt32;
    layers: UInt32;
  end;
  PVkFramebufferCreateInfo = ^TVkFramebufferCreateInfo;


  TVkCommandPoolCreateInfo = record
    sType: UInt32;
    pNext: Pointer;
    flags: UInt32;
    queueFamilyIndex: UInt32;
  end;
  PVkCommandPoolCreateInfo = ^TVkCommandPoolCreateInfo;


  TVkCommandBufferAllocateInfo = record
    sType: UInt32;
    pNext: Pointer;
    commandPool: VkCommandPool;
    level_: UInt32;
    commandBufferCount: UInt32;
  end;
  PVkCommandBufferAllocateInfo = ^TVkCommandBufferAllocateInfo;


  TVkCommandBufferBeginInfo = record
    sType: UInt32;
    pNext: Pointer;
    flags: UInt32;
    pInheritanceInfo: Pointer;
  end;
  PVkCommandBufferBeginInfo = ^TVkCommandBufferBeginInfo;


  TVkClearColorValue = record
    float32: array[0..3] of Single;
  end;

  TVkClearValue = record
    color: TVkClearColorValue;
  end;
  PVkClearValue = ^TVkClearValue;

  TVkRenderPassBeginInfo = record
    sType: UInt32;
    pNext: Pointer;
    renderPass: VkRenderPass;
    framebuffer: VkFramebuffer;
    renderArea: TVkRect2D;
    clearValueCount: UInt32;
    pClearValues: PVkClearValue;
  end;
  PVkRenderPassBeginInfo = ^TVkRenderPassBeginInfo;


  TVkSemaphoreCreateInfo = record
    sType: UInt32;
    pNext: Pointer;
    flags: UInt32;
  end;
  PVkSemaphoreCreateInfo = ^TVkSemaphoreCreateInfo;


  TVkFenceCreateInfo = record
    sType: UInt32;
    pNext: Pointer;
    flags: UInt32;
  end;
  PVkFenceCreateInfo = ^TVkFenceCreateInfo;


  TVkSubmitInfo = record
    sType: UInt32;
    pNext: Pointer;
    waitSemaphoreCount: UInt32;
    pWaitSemaphores: PVkSemaphore;
    pWaitDstStageMask: PUInt32;
    commandBufferCount: UInt32;
    pCommandBuffers: ^VkCommandBuffer;
    signalSemaphoreCount: UInt32;
    pSignalSemaphores: PVkSemaphore;
  end;
  PVkSubmitInfo = ^TVkSubmitInfo;


  TVkPresentInfoKHR = record
    sType: UInt32;
    pNext: Pointer;
    waitSemaphoreCount: UInt32;
    pWaitSemaphores: PVkSemaphore;
    swapchainCount: UInt32;
    pSwapchains: PVkSwapchainKHR;
    pImageIndices: PUInt32;
    pResults: Pointer;
  end;
  PVkPresentInfoKHR = ^TVkPresentInfoKHR;


  // ------------------------------------------------------------
  // Vulkan function pointer types (cdecl)
  // ------------------------------------------------------------
  PFN_vkVoidFunction = Pointer;

  PFN_vkGetInstanceProcAddr = function(instance: VkInstance; pName: PVkChar): PFN_vkVoidFunction; stdcall;
  PFN_vkGetDeviceProcAddr   = function(device: VkDevice; pName: PVkChar): PFN_vkVoidFunction; stdcall;

  PFN_vkCreateInstance = function(const pCreateInfo: PVkInstanceCreateInfo; pAllocator: Pointer; out instance: VkInstance): VkResult; stdcall;
  PFN_vkDestroyInstance = procedure(instance: VkInstance; pAllocator: Pointer); stdcall;

	PFN_vkEnumeratePhysicalDevices = function(instance: VkInstance; pPhysicalDeviceCount: PUInt32; pPhysicalDevices: PVkPhysicalDevice): VkResult; stdcall;
  PFN_vkGetPhysicalDeviceQueueFamilyProperties = procedure(physicalDevice: VkPhysicalDevice; pQueueFamilyPropertyCount: PUInt32; pQueueFamilyProperties: PVkQueueFamilyProperties); stdcall;

  PFN_vkCreateDevice = function(physicalDevice: VkPhysicalDevice; const pCreateInfo: PVkDeviceCreateInfo; pAllocator: Pointer; out device: VkDevice): VkResult; stdcall;
  PFN_vkDestroyDevice = procedure(device: VkDevice; pAllocator: Pointer); stdcall;
  PFN_vkGetDeviceQueue = procedure(device: VkDevice; queueFamilyIndex: UInt32; queueIndex: UInt32; out queue: VkQueue); stdcall;

  // Instance extension: surface
  PFN_vkCreateWin32SurfaceKHR = function(instance: VkInstance; const pCreateInfo: PVkWin32SurfaceCreateInfoKHR; pAllocator: Pointer; out surface: VkSurfaceKHR): VkResult; stdcall;
  PFN_vkDestroySurfaceKHR = procedure(instance: VkInstance; surface: VkSurfaceKHR; pAllocator: Pointer); stdcall;
  PFN_vkGetPhysicalDeviceSurfaceSupportKHR = function(physicalDevice: VkPhysicalDevice; queueFamilyIndex: UInt32; surface: VkSurfaceKHR; out supported: VkBool32): VkResult; stdcall;
  PFN_vkGetPhysicalDeviceSurfaceCapabilitiesKHR = function(physicalDevice: VkPhysicalDevice; surface: VkSurfaceKHR; out surfaceCapabilities: TVkSurfaceCapabilitiesKHR): VkResult; stdcall;
  PFN_vkGetPhysicalDeviceSurfaceFormatsKHR = function(physicalDevice: VkPhysicalDevice; surface: VkSurfaceKHR; pSurfaceFormatCount: PUInt32; pSurfaceFormats: PVkSurfaceFormatKHR): VkResult; stdcall;
  PFN_vkGetPhysicalDeviceSurfacePresentModesKHR = function(physicalDevice: VkPhysicalDevice; surface: VkSurfaceKHR; pPresentModeCount: PUInt32; pPresentModes: PUInt32): VkResult; stdcall;

  // Device extension: swapchain
  PFN_vkCreateSwapchainKHR = function(device: VkDevice; const pCreateInfo: PVkSwapchainCreateInfoKHR; pAllocator: Pointer; out swapchain: VkSwapchainKHR): VkResult; stdcall;
  PFN_vkDestroySwapchainKHR = procedure(device: VkDevice; swapchain: VkSwapchainKHR; pAllocator: Pointer); stdcall;
  PFN_vkGetSwapchainImagesKHR = function(device: VkDevice; swapchain: VkSwapchainKHR; pSwapchainImageCount: PUInt32; pSwapchainImages: PVkImage): VkResult; stdcall;

  PFN_vkCreateImageView = function(device: VkDevice; const pCreateInfo: PVkImageViewCreateInfo; pAllocator: Pointer; out view: VkImageView): VkResult; stdcall;
  PFN_vkDestroyImageView = procedure(device: VkDevice; imageView: VkImageView; pAllocator: Pointer); stdcall;

  PFN_vkCreateRenderPass = function(device: VkDevice; const pCreateInfo: PVkRenderPassCreateInfo; pAllocator: Pointer; out renderPass: VkRenderPass): VkResult; stdcall;
  PFN_vkDestroyRenderPass = procedure(device: VkDevice; renderPass: VkRenderPass; pAllocator: Pointer); stdcall;

  PFN_vkCreateShaderModule = function(device: VkDevice; const pCreateInfo: PVkShaderModuleCreateInfo; pAllocator: Pointer; out shaderModule: VkShaderModule): VkResult; stdcall;
  PFN_vkDestroyShaderModule = procedure(device: VkDevice; shaderModule: VkShaderModule; pAllocator: Pointer); stdcall;

  PFN_vkCreateBuffer = function(device: VkDevice; const pCreateInfo: PVkBufferCreateInfo; pAllocator: Pointer; out buffer: VkBuffer): VkResult; stdcall;
  PFN_vkDestroyBuffer = procedure(device: VkDevice; buffer: VkBuffer; pAllocator: Pointer); stdcall;
  PFN_vkGetBufferMemoryRequirements = procedure(device: VkDevice; buffer: VkBuffer; out memReq: TVkMemoryRequirements); stdcall;
  PFN_vkAllocateMemory = function(device: VkDevice; const pAllocateInfo: PVkMemoryAllocateInfo; pAllocator: Pointer; out memory: VkDeviceMemory): VkResult; stdcall;
  PFN_vkFreeMemory = procedure(device: VkDevice; memory: VkDeviceMemory; pAllocator: Pointer); stdcall;
  PFN_vkBindBufferMemory = function(device: VkDevice; buffer: VkBuffer; memory: VkDeviceMemory; memoryOffset: VkDeviceSize): VkResult; stdcall;
  PFN_vkMapMemory = function(device: VkDevice; memory: VkDeviceMemory; offset: VkDeviceSize; size: VkDeviceSize; flags: UInt32; out data: Pointer): VkResult; stdcall;
  PFN_vkUnmapMemory = procedure(device: VkDevice; memory: VkDeviceMemory); stdcall;
  PFN_vkGetPhysicalDeviceMemoryProperties = procedure(physicalDevice: VkPhysicalDevice; out memoryProperties: TVkPhysicalDeviceMemoryProperties); stdcall;

  PFN_vkCreateDescriptorSetLayout = function(device: VkDevice; const pCreateInfo: PVkDescriptorSetLayoutCreateInfo; pAllocator: Pointer; out setLayout: VkDescriptorSetLayout): VkResult; stdcall;
  PFN_vkDestroyDescriptorSetLayout = procedure(device: VkDevice; descriptorSetLayout: VkDescriptorSetLayout; pAllocator: Pointer); stdcall;
  PFN_vkCreateDescriptorPool = function(device: VkDevice; const pCreateInfo: PVkDescriptorPoolCreateInfo; pAllocator: Pointer; out descriptorPool: VkDescriptorPool): VkResult; stdcall;
  PFN_vkDestroyDescriptorPool = procedure(device: VkDevice; descriptorPool: VkDescriptorPool; pAllocator: Pointer); stdcall;
  PFN_vkAllocateDescriptorSets = function(device: VkDevice; const pAllocateInfo: PVkDescriptorSetAllocateInfo; pDescriptorSets: PVkDescriptorSet): VkResult; stdcall;
  PFN_vkUpdateDescriptorSets = procedure(device: VkDevice; descriptorWriteCount: UInt32; const pDescriptorWrites: PVkWriteDescriptorSet; descriptorCopyCount: UInt32; pDescriptorCopies: Pointer); stdcall;

  PFN_vkCreatePipelineLayout = function(device: VkDevice; pCreateInfo: PVkPipelineLayoutCreateInfo; pAllocator: Pointer; out pipelineLayout: VkPipelineLayout): VkResult; stdcall;
  PFN_vkDestroyPipelineLayout = procedure(device: VkDevice; pipelineLayout: VkPipelineLayout; pAllocator: Pointer); stdcall;

  PFN_vkCreateGraphicsPipelines = function(device: VkDevice; pipelineCache: UInt64; createInfoCount: UInt32; pCreateInfos: PVkGraphicsPipelineCreateInfo; pAllocator: Pointer; out pipelines: VkPipeline): VkResult; stdcall;
  PFN_vkCreateComputePipelines = function(device: VkDevice; pipelineCache: UInt64; createInfoCount: UInt32; pCreateInfos: PVkComputePipelineCreateInfo; pAllocator: Pointer; out pipelines: VkPipeline): VkResult; stdcall;
  PFN_vkDestroyPipeline = procedure(device: VkDevice; pipeline: VkPipeline; pAllocator: Pointer); stdcall;

  PFN_vkCreateFramebuffer = function(device: VkDevice; pCreateInfo: PVkFramebufferCreateInfo; pAllocator: Pointer; out framebuffer: VkFramebuffer): VkResult; stdcall;
  PFN_vkDestroyFramebuffer = procedure(device: VkDevice; framebuffer: VkFramebuffer; pAllocator: Pointer); stdcall;

  PFN_vkCreateCommandPool = function(device: VkDevice; pCreateInfo: PVkCommandPoolCreateInfo; pAllocator: Pointer; out commandPool: VkCommandPool): VkResult; stdcall;
  PFN_vkDestroyCommandPool = procedure(device: VkDevice; commandPool: VkCommandPool; pAllocator: Pointer); stdcall;

  PFN_vkAllocateCommandBuffers = function(device: VkDevice; pAllocateInfo: PVkCommandBufferAllocateInfo; pCommandBuffers: PVkCommandBuffer): VkResult; stdcall;

  PFN_vkBeginCommandBuffer = function(commandBuffer: VkCommandBuffer; pBeginInfo: PVkCommandBufferBeginInfo): VkResult; stdcall;
  PFN_vkEndCommandBuffer = function(commandBuffer: VkCommandBuffer): VkResult; stdcall;

  PFN_vkCmdBeginRenderPass = procedure(commandBuffer: VkCommandBuffer; pRenderPassBegin: PVkRenderPassBeginInfo; contents: UInt32); stdcall;
  PFN_vkCmdEndRenderPass = procedure(commandBuffer: VkCommandBuffer); stdcall;
  PFN_vkCmdBindPipeline = procedure(commandBuffer: VkCommandBuffer; pipelineBindPoint: UInt32; pipeline: VkPipeline); stdcall;
  PFN_vkCmdBindDescriptorSets = procedure(commandBuffer: VkCommandBuffer; pipelineBindPoint: UInt32; layout: VkPipelineLayout; firstSet: UInt32; descriptorSetCount: UInt32; pDescriptorSets: PVkDescriptorSet; dynamicOffsetCount: UInt32; pDynamicOffsets: PUInt32); stdcall;
  PFN_vkCmdDraw = procedure(commandBuffer: VkCommandBuffer; vertexCount, instanceCount, firstVertex, firstInstance: UInt32); stdcall;
  PFN_vkCmdDispatch = procedure(commandBuffer: VkCommandBuffer; groupCountX, groupCountY, groupCountZ: UInt32); stdcall;
  PFN_vkCmdPipelineBarrier = procedure(commandBuffer: VkCommandBuffer; srcStageMask, dstStageMask, dependencyFlags: UInt32; memoryBarrierCount: UInt32; pMemoryBarriers: Pointer; bufferMemoryBarrierCount: UInt32; pBufferMemoryBarriers: PVkBufferMemoryBarrier; imageMemoryBarrierCount: UInt32; pImageMemoryBarriers: Pointer); stdcall;
  PFN_vkCmdSetViewport = procedure(commandBuffer: VkCommandBuffer; firstViewport: UInt32; viewportCount: UInt32; const pViewports: PVkViewport); stdcall;
  PFN_vkCmdSetScissor = procedure(commandBuffer: VkCommandBuffer; firstScissor: UInt32; scissorCount: UInt32; pScissors: PVkRect2D); stdcall;
  PFN_vkCmdPushConstants = procedure(commandBuffer: VkCommandBuffer; layout: VkPipelineLayout; stageFlags: UInt32; offset: UInt32; size: UInt32; pValues: Pointer); stdcall;
  PFN_vkResetCommandBuffer = function(commandBuffer: VkCommandBuffer; flags: UInt32): VkResult; stdcall;

  PFN_vkCreateSemaphore = function(device: VkDevice; pCreateInfo: PVkSemaphoreCreateInfo; pAllocator: Pointer; out semaphore: VkSemaphore): VkResult; stdcall;
  PFN_vkDestroySemaphore = procedure(device: VkDevice; semaphore: VkSemaphore; pAllocator: Pointer); stdcall;
  PFN_vkCreateFence = function(device: VkDevice; pCreateInfo: PVkFenceCreateInfo; pAllocator: Pointer; out fence: VkFence): VkResult; stdcall;
  PFN_vkDestroyFence = procedure(device: VkDevice; fence: VkFence; pAllocator: Pointer); stdcall;

  PFN_vkWaitForFences = function(device: VkDevice; fenceCount: UInt32; const pFences: PVkFence; waitAll: VkBool32; timeout: UInt64): VkResult; stdcall;
  PFN_vkResetFences = function(device: VkDevice; fenceCount: UInt32; const pFences: PVkFence): VkResult; stdcall;

  PFN_vkAcquireNextImageKHR = function(device: VkDevice; swapchain: VkSwapchainKHR; timeout: UInt64; semaphore: VkSemaphore; fence: VkFence; out imageIndex: UInt32): VkResult; stdcall;

  PFN_vkQueueSubmit = function(queue: VkQueue; submitCount: UInt32; pSubmits: PVkSubmitInfo; fence: VkFence): VkResult; stdcall;
  PFN_vkQueuePresentKHR = function(queue: VkQueue; pPresentInfo: PVkPresentInfoKHR): VkResult; stdcall;

  PFN_vkDeviceWaitIdle = function(device: VkDevice): VkResult; stdcall;

	// ------------------------------------------------------------
	// shaderc (runtime GLSL -> SPIR-V)
	// ------------------------------------------------------------
	TSizeT = NativeUInt;
	shaderc_compiler_t = Pointer;
	shaderc_compile_options_t = Pointer;
	shaderc_compilation_result_t = Pointer;

	PFN_shaderc_compiler_initialize = function: shaderc_compiler_t; cdecl;
	PFN_shaderc_compiler_release = procedure(compiler: shaderc_compiler_t); cdecl;
	PFN_shaderc_compile_options_initialize = function: shaderc_compile_options_t; cdecl;
	PFN_shaderc_compile_options_release = procedure(options: shaderc_compile_options_t); cdecl;
	PFN_shaderc_compile_into_spv = function(
	  compiler: shaderc_compiler_t;
	  source_text: PAnsiChar;
	  source_text_size: TSizeT;
	  shader_kind: Integer;
	  input_file_name: PAnsiChar;
	  entry_point_name: PAnsiChar;
	  options: shaderc_compile_options_t
	): shaderc_compilation_result_t; cdecl;
	PFN_shaderc_result_get_compilation_status = function(result_: shaderc_compilation_result_t): Integer; cdecl;
	PFN_shaderc_result_get_error_message = function(result_: shaderc_compilation_result_t): PAnsiChar; cdecl;
	PFN_shaderc_result_get_length = function(result_: shaderc_compilation_result_t): TSizeT; cdecl;
	PFN_shaderc_result_get_bytes = function(result_: shaderc_compilation_result_t): PAnsiChar; cdecl;
	PFN_shaderc_result_release = procedure(result_: shaderc_compilation_result_t); cdecl;

var
  gDbgIndent: Integer = 0;

  // Vulkan library + base loaders
  gVulkan: HMODULE = 0;
  vkGetInstanceProcAddr: PFN_vkGetInstanceProcAddr = nil;
  vkGetDeviceProcAddr: PFN_vkGetDeviceProcAddr = nil;

  // Global exported (from vulkan-1.dll)
  vkCreateInstance: PFN_vkCreateInstance = nil;
  vkDestroyInstance: PFN_vkDestroyInstance = nil;
  vkEnumeratePhysicalDevices: PFN_vkEnumeratePhysicalDevices = nil;
  vkGetPhysicalDeviceQueueFamilyProperties: PFN_vkGetPhysicalDeviceQueueFamilyProperties = nil;
  vkCreateDevice: PFN_vkCreateDevice = nil;
  vkDestroyDevice: PFN_vkDestroyDevice = nil;

  // Instance funcs
  vkCreateWin32SurfaceKHR: PFN_vkCreateWin32SurfaceKHR = nil;
  vkDestroySurfaceKHR: PFN_vkDestroySurfaceKHR = nil;
  vkGetPhysicalDeviceSurfaceSupportKHR: PFN_vkGetPhysicalDeviceSurfaceSupportKHR = nil;
  vkGetPhysicalDeviceSurfaceCapabilitiesKHR: PFN_vkGetPhysicalDeviceSurfaceCapabilitiesKHR = nil;
  vkGetPhysicalDeviceSurfaceFormatsKHR: PFN_vkGetPhysicalDeviceSurfaceFormatsKHR = nil;
  vkGetPhysicalDeviceSurfacePresentModesKHR: PFN_vkGetPhysicalDeviceSurfacePresentModesKHR = nil;

  // Device funcs
  vkGetDeviceQueue: PFN_vkGetDeviceQueue = nil;
  vkCreateSwapchainKHR: PFN_vkCreateSwapchainKHR = nil;
  vkDestroySwapchainKHR: PFN_vkDestroySwapchainKHR = nil;
  vkGetSwapchainImagesKHR: PFN_vkGetSwapchainImagesKHR = nil;

  // Raw pointers for debug (avoid procvar-as-expression pitfalls on FPC i386)
  gfp_vkCreateSwapchainKHR: Pointer = nil;

  vkCreateImageView: PFN_vkCreateImageView = nil;
  vkDestroyImageView: PFN_vkDestroyImageView = nil;

  vkCreateRenderPass: PFN_vkCreateRenderPass = nil;
  vkDestroyRenderPass: PFN_vkDestroyRenderPass = nil;

  vkCreateShaderModule: PFN_vkCreateShaderModule = nil;
  vkDestroyShaderModule: PFN_vkDestroyShaderModule = nil;

  vkCreateBuffer: PFN_vkCreateBuffer = nil;
  vkDestroyBuffer: PFN_vkDestroyBuffer = nil;
  vkGetBufferMemoryRequirements: PFN_vkGetBufferMemoryRequirements = nil;
  vkAllocateMemory: PFN_vkAllocateMemory = nil;
  vkFreeMemory: PFN_vkFreeMemory = nil;
  vkBindBufferMemory: PFN_vkBindBufferMemory = nil;
  vkMapMemory: PFN_vkMapMemory = nil;
  vkUnmapMemory: PFN_vkUnmapMemory = nil;
  vkGetPhysicalDeviceMemoryProperties: PFN_vkGetPhysicalDeviceMemoryProperties = nil;

  vkCreateDescriptorSetLayout: PFN_vkCreateDescriptorSetLayout = nil;
  vkDestroyDescriptorSetLayout: PFN_vkDestroyDescriptorSetLayout = nil;
  vkCreateDescriptorPool: PFN_vkCreateDescriptorPool = nil;
  vkDestroyDescriptorPool: PFN_vkDestroyDescriptorPool = nil;
  vkAllocateDescriptorSets: PFN_vkAllocateDescriptorSets = nil;
  vkUpdateDescriptorSets: PFN_vkUpdateDescriptorSets = nil;

  vkCreatePipelineLayout: PFN_vkCreatePipelineLayout = nil;
  vkDestroyPipelineLayout: PFN_vkDestroyPipelineLayout = nil;

  vkCreateGraphicsPipelines: PFN_vkCreateGraphicsPipelines = nil;
  vkCreateComputePipelines: PFN_vkCreateComputePipelines = nil;
  vkDestroyPipeline: PFN_vkDestroyPipeline = nil;

  vkCreateFramebuffer: PFN_vkCreateFramebuffer = nil;
  vkDestroyFramebuffer: PFN_vkDestroyFramebuffer = nil;

  vkCreateCommandPool: PFN_vkCreateCommandPool = nil;
  vkDestroyCommandPool: PFN_vkDestroyCommandPool = nil;

  vkAllocateCommandBuffers: PFN_vkAllocateCommandBuffers = nil;
  vkBeginCommandBuffer: PFN_vkBeginCommandBuffer = nil;
  vkEndCommandBuffer: PFN_vkEndCommandBuffer = nil;

  vkCmdBeginRenderPass: PFN_vkCmdBeginRenderPass = nil;
  vkCmdEndRenderPass: PFN_vkCmdEndRenderPass = nil;
  vkCmdBindPipeline: PFN_vkCmdBindPipeline = nil;
  vkCmdBindDescriptorSets: PFN_vkCmdBindDescriptorSets = nil;
  vkCmdDraw: PFN_vkCmdDraw = nil;
  vkCmdDispatch: PFN_vkCmdDispatch = nil;
  vkCmdPipelineBarrier: PFN_vkCmdPipelineBarrier = nil;
  vkCmdSetViewport: PFN_vkCmdSetViewport = nil;
  vkCmdSetScissor: PFN_vkCmdSetScissor = nil;
  vkCmdPushConstants: PFN_vkCmdPushConstants = nil;
  vkResetCommandBuffer: PFN_vkResetCommandBuffer = nil;

  vkCreateSemaphore: PFN_vkCreateSemaphore = nil;
  vkDestroySemaphore: PFN_vkDestroySemaphore = nil;
  vkCreateFence: PFN_vkCreateFence = nil;
  vkDestroyFence: PFN_vkDestroyFence = nil;

  vkWaitForFences: PFN_vkWaitForFences = nil;
  vkResetFences: PFN_vkResetFences = nil;

  vkAcquireNextImageKHR: PFN_vkAcquireNextImageKHR = nil;
  vkQueueSubmit: PFN_vkQueueSubmit = nil;
  vkQueuePresentKHR: PFN_vkQueuePresentKHR = nil;

  vkDeviceWaitIdle: PFN_vkDeviceWaitIdle = nil;

	// shaderc (loaded from shaderc_shared.dll)
	gShaderc: HMODULE = 0;
	shaderc_compiler_initialize: PFN_shaderc_compiler_initialize = nil;
	shaderc_compiler_release: PFN_shaderc_compiler_release = nil;
	shaderc_compile_options_initialize: PFN_shaderc_compile_options_initialize = nil;
	shaderc_compile_options_release: PFN_shaderc_compile_options_release = nil;
	shaderc_compile_into_spv: PFN_shaderc_compile_into_spv = nil;
	shaderc_result_get_compilation_status: PFN_shaderc_result_get_compilation_status = nil;
	shaderc_result_get_error_message: PFN_shaderc_result_get_error_message = nil;
	shaderc_result_get_length: PFN_shaderc_result_get_length = nil;
	shaderc_result_get_bytes: PFN_shaderc_result_get_bytes = nil;
	shaderc_result_release: PFN_shaderc_result_release = nil;

	gShadercCompiler: shaderc_compiler_t = nil;
	gShadercOptions: shaderc_compile_options_t = nil;

type
  TSwapchainBundle = record
    swapchain: VkSwapchainKHR;
    format: UInt32;
    extent: TVkExtent2D;
    imageCount: UInt32;
    images: array of VkImage;
    views: array of VkImageView;
    renderPass: VkRenderPass;
    pipelineLayout: VkPipelineLayout;
    pipeline: VkPipeline;
    framebuffers: array of VkFramebuffer;
    commandPool: VkCommandPool;
    commandBuffers: array of VkCommandBuffer;
  end;

  TSyncObjects = record
    imageAvailable: array[0..1] of VkSemaphore;
    renderFinished: array[0..1] of VkSemaphore;
    inFlight: array[0..1] of VkFence;
  end;

var
  // Win32 window
  gHwnd: HWND = 0;
  gHinst: HINST = 0;
  gShouldQuit: Boolean = False;
  gResized: Boolean = False;

  // Vulkan state
  gInstance: VkInstance = nil;
  gSurface: VkSurfaceKHR = 0;
  gPhysicalDevice: VkPhysicalDevice = nil;
  gDevice: VkDevice = nil;
  gGraphicsQueue: VkQueue = nil;
  gPresentQueue: VkQueue = nil;
  gGraphicsQFamily: UInt32 = $FFFFFFFF;
  gPresentQFamily: UInt32 = $FFFFFFFF;

  gBundle: TSwapchainBundle;
  gSync: TSyncObjects;
  gFrame: UInt32 = 0;
  gStartTick: UInt64 = 0;
  gPhase: Single = 0.0;

  gDescriptorSetLayout: VkDescriptorSetLayout = 0;
  gDescriptorPool: VkDescriptorPool = 0;
  gDescriptorSet: VkDescriptorSet = 0;
  gPipelineLayout: VkPipelineLayout = 0;
  gComputePipeline: VkPipeline = 0;

  gPositionBuffer: VkBuffer = 0;
  gPositionMemory: VkDeviceMemory = 0;
  gColorBuffer: VkBuffer = 0;
  gColorMemory: VkDeviceMemory = 0;
  gParamBuffer: VkBuffer = 0;
  gParamMemory: VkDeviceMemory = 0;

procedure Dbg(const s: AnsiString); forward;
procedure Dbgf(const fmt: AnsiString; const args: array of const); forward;

procedure VkCheck(res: VkResult; const what: string);
begin
  if res <> VK_SUCCESS then
  begin
    Dbgf('VkCheck failed: %s res=%d', [what, res]);
    raise Exception.CreateFmt('%s failed: VkResult=%d', [what, res]);
  end;
end;


// ------------------------------------------------------------
// Debug logging (DebugView / OutputDebugString)
// ------------------------------------------------------------
function IndentStr: AnsiString;
begin
  Result := AnsiString(StringOfChar(' ', gDbgIndent * 2));
end;

procedure Dbg(const s: AnsiString);
var
  msg: AnsiString;
begin
  msg := s + #13#10;
  OutputDebugStringA(PAnsiChar(msg));
end;

procedure Dbgf(const fmt: AnsiString; const args: array of const);
begin
  Dbg(IndentStr + AnsiString(Format(string(fmt), args)));
end;

procedure DbgEnter(const fn: AnsiString);
begin
  Dbg(IndentStr + '>> ' + fn);
  Inc(gDbgIndent);
end;

procedure DbgLeave(const fn: AnsiString);
begin
  if gDbgIndent > 0 then Dec(gDbgIndent);
  Dbg(IndentStr + '<< ' + fn);
end;

function PtrHex(p: Pointer): AnsiString;
begin
  Result := AnsiString('0x' + IntToHex(PtrUInt(p), SizeOf(Pointer) * 2));
end;

function U64Hex(u: QWord): AnsiString;
begin
  Result := AnsiString('0x' + IntToHex(u, 16));
end;

function GetProcOrFail(lib: HMODULE; const name: AnsiString): Pointer;
begin
  Result := GetProcAddress(lib, PAnsiChar(name));
  Dbgf('GetProcAddress(%s) = %s', [name, string(PtrHex(Result))]);
  if Result = nil then
    raise Exception.CreateFmt('GetProcAddress failed: %s', [string(name)]);
end;


function LoadVulkanProc(instance: VkInstance; const name: AnsiString): Pointer;
begin
  Result := vkGetInstanceProcAddr(instance, PAnsiChar(name));
  Dbgf('vkGetInstanceProcAddr(%s) = %s', [name, string(PtrHex(Result))]);
  if Result = nil then
    raise Exception.CreateFmt('vkGetInstanceProcAddr failed: %s', [string(name)]);
end;


function LoadDeviceProc(device: VkDevice; const name: AnsiString): Pointer;
begin
  Result := vkGetDeviceProcAddr(device, PAnsiChar(name));
  if Result = nil then
    raise Exception.CreateFmt('vkGetDeviceProcAddr failed: %s', [string(name)]);
end;

procedure LoadVulkanLibrary;
begin
  if gVulkan <> 0 then Exit;

  gVulkan := LoadLibrary('vulkan-1.dll');
  if gVulkan = 0 then
    raise Exception.Create('LoadLibrary(vulkan-1.dll) failed (Vulkan runtime not installed?)');

  vkGetInstanceProcAddr := PFN_vkGetInstanceProcAddr(GetProcOrFail(gVulkan, 'vkGetInstanceProcAddr'));
  vkGetDeviceProcAddr   := PFN_vkGetDeviceProcAddr(GetProcOrFail(gVulkan, 'vkGetDeviceProcAddr'));

  vkCreateInstance := PFN_vkCreateInstance(GetProcOrFail(gVulkan, 'vkCreateInstance'));
  vkDestroyInstance := PFN_vkDestroyInstance(GetProcOrFail(gVulkan, 'vkDestroyInstance'));
  vkEnumeratePhysicalDevices := PFN_vkEnumeratePhysicalDevices(GetProcOrFail(gVulkan, 'vkEnumeratePhysicalDevices'));
  vkGetPhysicalDeviceQueueFamilyProperties := PFN_vkGetPhysicalDeviceQueueFamilyProperties(GetProcOrFail(gVulkan, 'vkGetPhysicalDeviceQueueFamilyProperties'));
  vkGetPhysicalDeviceMemoryProperties := PFN_vkGetPhysicalDeviceMemoryProperties(GetProcOrFail(gVulkan, 'vkGetPhysicalDeviceMemoryProperties'));
  vkCreateDevice := PFN_vkCreateDevice(GetProcOrFail(gVulkan, 'vkCreateDevice'));
  vkDestroyDevice := PFN_vkDestroyDevice(GetProcOrFail(gVulkan, 'vkDestroyDevice'));
end;

procedure LoadShadercLibrary;
begin
  if gShaderc <> 0 then Exit;

  gShaderc := LoadLibrary(PChar(SHADERC_DLL));
  if gShaderc = 0 then
    raise Exception.CreateFmt('LoadLibrary(%s) failed. Please ensure shaderc_shared.dll is present (matching x86/x64).', [SHADERC_DLL]);

  shaderc_compiler_initialize := PFN_shaderc_compiler_initialize(GetProcOrFail(gShaderc, 'shaderc_compiler_initialize'));
  shaderc_compiler_release := PFN_shaderc_compiler_release(GetProcOrFail(gShaderc, 'shaderc_compiler_release'));
  shaderc_compile_options_initialize := PFN_shaderc_compile_options_initialize(GetProcOrFail(gShaderc, 'shaderc_compile_options_initialize'));
  shaderc_compile_options_release := PFN_shaderc_compile_options_release(GetProcOrFail(gShaderc, 'shaderc_compile_options_release'));
  shaderc_compile_into_spv := PFN_shaderc_compile_into_spv(GetProcOrFail(gShaderc, 'shaderc_compile_into_spv'));
  shaderc_result_get_compilation_status := PFN_shaderc_result_get_compilation_status(GetProcOrFail(gShaderc, 'shaderc_result_get_compilation_status'));
  shaderc_result_get_error_message := PFN_shaderc_result_get_error_message(GetProcOrFail(gShaderc, 'shaderc_result_get_error_message'));
  shaderc_result_get_length := PFN_shaderc_result_get_length(GetProcOrFail(gShaderc, 'shaderc_result_get_length'));
  shaderc_result_get_bytes := PFN_shaderc_result_get_bytes(GetProcOrFail(gShaderc, 'shaderc_result_get_bytes'));
  shaderc_result_release := PFN_shaderc_result_release(GetProcOrFail(gShaderc, 'shaderc_result_release'));

  gShadercCompiler := shaderc_compiler_initialize();
  if gShadercCompiler = nil then
    raise Exception.Create('shaderc_compiler_initialize failed');

  gShadercOptions := shaderc_compile_options_initialize();
  if gShadercOptions = nil then
    raise Exception.Create('shaderc_compile_options_initialize failed');
end;

procedure UnloadShadercLibrary;
begin
  if gShadercOptions <> nil then
  begin
    shaderc_compile_options_release(gShadercOptions);
    gShadercOptions := nil;
  end;
  if gShadercCompiler <> nil then
  begin
    shaderc_compiler_release(gShadercCompiler);
    gShadercCompiler := nil;
  end;
  if gShaderc <> 0 then
  begin
    FreeLibrary(gShaderc);
    gShaderc := 0;
  end;
end;

procedure LoadInstanceFunctions(instance: VkInstance);
begin
  DbgEnter('LoadInstanceFunctions');

  vkCreateWin32SurfaceKHR := PFN_vkCreateWin32SurfaceKHR(LoadVulkanProc(instance, 'vkCreateWin32SurfaceKHR'));
  vkDestroySurfaceKHR := PFN_vkDestroySurfaceKHR(LoadVulkanProc(instance, 'vkDestroySurfaceKHR'));
  vkGetPhysicalDeviceSurfaceSupportKHR := PFN_vkGetPhysicalDeviceSurfaceSupportKHR(LoadVulkanProc(instance, 'vkGetPhysicalDeviceSurfaceSupportKHR'));
  vkGetPhysicalDeviceSurfaceCapabilitiesKHR := PFN_vkGetPhysicalDeviceSurfaceCapabilitiesKHR(LoadVulkanProc(instance, 'vkGetPhysicalDeviceSurfaceCapabilitiesKHR'));
  vkGetPhysicalDeviceSurfaceFormatsKHR := PFN_vkGetPhysicalDeviceSurfaceFormatsKHR(LoadVulkanProc(instance, 'vkGetPhysicalDeviceSurfaceFormatsKHR'));
  vkGetPhysicalDeviceSurfacePresentModesKHR := PFN_vkGetPhysicalDeviceSurfacePresentModesKHR(LoadVulkanProc(instance, 'vkGetPhysicalDeviceSurfacePresentModesKHR'));

  DbgLeave('LoadInstanceFunctions');
end;

procedure LoadDeviceFunctions(device: VkDevice);
begin
  vkDestroyDevice := PFN_vkDestroyDevice(LoadDeviceProc(device, 'vkDestroyDevice'));
  vkGetDeviceQueue := PFN_vkGetDeviceQueue(LoadDeviceProc(device, 'vkGetDeviceQueue'));

  // Keep raw pointer for debug logging (casting procvars inside array-of-const can confuse FPC i386)
  gfp_vkCreateSwapchainKHR := LoadDeviceProc(device, 'vkCreateSwapchainKHR');
  vkCreateSwapchainKHR := PFN_vkCreateSwapchainKHR(gfp_vkCreateSwapchainKHR);
  vkDestroySwapchainKHR := PFN_vkDestroySwapchainKHR(LoadDeviceProc(device, 'vkDestroySwapchainKHR'));
  vkGetSwapchainImagesKHR := PFN_vkGetSwapchainImagesKHR(LoadDeviceProc(device, 'vkGetSwapchainImagesKHR'));

  vkCreateImageView := PFN_vkCreateImageView(LoadDeviceProc(device, 'vkCreateImageView'));
  vkDestroyImageView := PFN_vkDestroyImageView(LoadDeviceProc(device, 'vkDestroyImageView'));

  vkCreateRenderPass := PFN_vkCreateRenderPass(LoadDeviceProc(device, 'vkCreateRenderPass'));
  vkDestroyRenderPass := PFN_vkDestroyRenderPass(LoadDeviceProc(device, 'vkDestroyRenderPass'));

  vkCreateShaderModule := PFN_vkCreateShaderModule(LoadDeviceProc(device, 'vkCreateShaderModule'));
  vkDestroyShaderModule := PFN_vkDestroyShaderModule(LoadDeviceProc(device, 'vkDestroyShaderModule'));

  vkCreateBuffer := PFN_vkCreateBuffer(LoadDeviceProc(device, 'vkCreateBuffer'));
  vkDestroyBuffer := PFN_vkDestroyBuffer(LoadDeviceProc(device, 'vkDestroyBuffer'));
  vkGetBufferMemoryRequirements := PFN_vkGetBufferMemoryRequirements(LoadDeviceProc(device, 'vkGetBufferMemoryRequirements'));
  vkAllocateMemory := PFN_vkAllocateMemory(LoadDeviceProc(device, 'vkAllocateMemory'));
  vkFreeMemory := PFN_vkFreeMemory(LoadDeviceProc(device, 'vkFreeMemory'));
  vkBindBufferMemory := PFN_vkBindBufferMemory(LoadDeviceProc(device, 'vkBindBufferMemory'));
  vkMapMemory := PFN_vkMapMemory(LoadDeviceProc(device, 'vkMapMemory'));
  vkUnmapMemory := PFN_vkUnmapMemory(LoadDeviceProc(device, 'vkUnmapMemory'));

  vkCreateDescriptorSetLayout := PFN_vkCreateDescriptorSetLayout(LoadDeviceProc(device, 'vkCreateDescriptorSetLayout'));
  vkDestroyDescriptorSetLayout := PFN_vkDestroyDescriptorSetLayout(LoadDeviceProc(device, 'vkDestroyDescriptorSetLayout'));
  vkCreateDescriptorPool := PFN_vkCreateDescriptorPool(LoadDeviceProc(device, 'vkCreateDescriptorPool'));
  vkDestroyDescriptorPool := PFN_vkDestroyDescriptorPool(LoadDeviceProc(device, 'vkDestroyDescriptorPool'));
  vkAllocateDescriptorSets := PFN_vkAllocateDescriptorSets(LoadDeviceProc(device, 'vkAllocateDescriptorSets'));
  vkUpdateDescriptorSets := PFN_vkUpdateDescriptorSets(LoadDeviceProc(device, 'vkUpdateDescriptorSets'));

  vkCreatePipelineLayout := PFN_vkCreatePipelineLayout(LoadDeviceProc(device, 'vkCreatePipelineLayout'));
  vkDestroyPipelineLayout := PFN_vkDestroyPipelineLayout(LoadDeviceProc(device, 'vkDestroyPipelineLayout'));

  vkCreateGraphicsPipelines := PFN_vkCreateGraphicsPipelines(LoadDeviceProc(device, 'vkCreateGraphicsPipelines'));
  vkCreateComputePipelines := PFN_vkCreateComputePipelines(LoadDeviceProc(device, 'vkCreateComputePipelines'));
  vkDestroyPipeline := PFN_vkDestroyPipeline(LoadDeviceProc(device, 'vkDestroyPipeline'));

  vkCreateFramebuffer := PFN_vkCreateFramebuffer(LoadDeviceProc(device, 'vkCreateFramebuffer'));
  vkDestroyFramebuffer := PFN_vkDestroyFramebuffer(LoadDeviceProc(device, 'vkDestroyFramebuffer'));

  vkCreateCommandPool := PFN_vkCreateCommandPool(LoadDeviceProc(device, 'vkCreateCommandPool'));
  vkDestroyCommandPool := PFN_vkDestroyCommandPool(LoadDeviceProc(device, 'vkDestroyCommandPool'));

  vkAllocateCommandBuffers := PFN_vkAllocateCommandBuffers(LoadDeviceProc(device, 'vkAllocateCommandBuffers'));
  vkBeginCommandBuffer := PFN_vkBeginCommandBuffer(LoadDeviceProc(device, 'vkBeginCommandBuffer'));
  vkEndCommandBuffer := PFN_vkEndCommandBuffer(LoadDeviceProc(device, 'vkEndCommandBuffer'));

  vkCmdBeginRenderPass := PFN_vkCmdBeginRenderPass(LoadDeviceProc(device, 'vkCmdBeginRenderPass'));
  vkCmdEndRenderPass := PFN_vkCmdEndRenderPass(LoadDeviceProc(device, 'vkCmdEndRenderPass'));
  vkCmdBindPipeline := PFN_vkCmdBindPipeline(LoadDeviceProc(device, 'vkCmdBindPipeline'));
  vkCmdBindDescriptorSets := PFN_vkCmdBindDescriptorSets(LoadDeviceProc(device, 'vkCmdBindDescriptorSets'));
  vkCmdDraw := PFN_vkCmdDraw(LoadDeviceProc(device, 'vkCmdDraw'));
  vkCmdDispatch := PFN_vkCmdDispatch(LoadDeviceProc(device, 'vkCmdDispatch'));
  vkCmdPipelineBarrier := PFN_vkCmdPipelineBarrier(LoadDeviceProc(device, 'vkCmdPipelineBarrier'));
  vkCmdSetViewport := PFN_vkCmdSetViewport(LoadDeviceProc(device, 'vkCmdSetViewport'));
  vkCmdSetScissor := PFN_vkCmdSetScissor(LoadDeviceProc(device, 'vkCmdSetScissor'));
  vkCmdPushConstants := PFN_vkCmdPushConstants(LoadDeviceProc(device, 'vkCmdPushConstants'));
  vkResetCommandBuffer := PFN_vkResetCommandBuffer(LoadDeviceProc(device, 'vkResetCommandBuffer'));

  vkCreateSemaphore := PFN_vkCreateSemaphore(LoadDeviceProc(device, 'vkCreateSemaphore'));
  vkDestroySemaphore := PFN_vkDestroySemaphore(LoadDeviceProc(device, 'vkDestroySemaphore'));
  vkCreateFence := PFN_vkCreateFence(LoadDeviceProc(device, 'vkCreateFence'));
  vkDestroyFence := PFN_vkDestroyFence(LoadDeviceProc(device, 'vkDestroyFence'));

  vkWaitForFences := PFN_vkWaitForFences(LoadDeviceProc(device, 'vkWaitForFences'));
  vkResetFences := PFN_vkResetFences(LoadDeviceProc(device, 'vkResetFences'));

  vkAcquireNextImageKHR := PFN_vkAcquireNextImageKHR(LoadDeviceProc(device, 'vkAcquireNextImageKHR'));
  vkQueueSubmit := PFN_vkQueueSubmit(LoadDeviceProc(device, 'vkQueueSubmit'));
  vkQueuePresentKHR := PFN_vkQueuePresentKHR(LoadDeviceProc(device, 'vkQueuePresentKHR'));

  vkDeviceWaitIdle := PFN_vkDeviceWaitIdle(LoadDeviceProc(device, 'vkDeviceWaitIdle'));
end;

function ReadFileBytes(const fileName: string; out bytes: TBytes): Boolean;
var
  fs: TFileStream;
begin
  Result := False;
  if not FileExists(fileName) then Exit;
  fs := TFileStream.Create(fileName, fmOpenRead or fmShareDenyWrite);
  try
    SetLength(bytes, fs.Size);
    if fs.Size > 0 then
      fs.ReadBuffer(bytes[0], fs.Size);
    Result := True;
  finally
    fs.Free;
  end;
end;

type
  TUInt32DynArray = array of UInt32;

function ReadFileTextAnsi(const fileName: string): AnsiString;
var
  data: TBytes;
begin
  Result := '';
  if not ReadFileBytes(fileName, data) then
    raise Exception.CreateFmt('File not found: %s', [fileName]);
  SetLength(Result, Length(data));
  if Length(data) > 0 then
    Move(data[0], Result[1], Length(data));
end;

function CompileGLSLFileToWords(const fileName: string; shaderKind: Integer): TUInt32DynArray;
var
  src: AnsiString;
  res: shaderc_compilation_result_t;
  status: Integer;
  errMsg: PAnsiChar;
  byteLen: TSizeT;
  bytes: PAnsiChar;
  wordCount: Integer;
begin
  // FPC may warn about managed return values not initialized; make it explicit.
  Result := nil;
  SetLength(Result, 0);
  LoadShadercLibrary;

  src := ReadFileTextAnsi(fileName);
  if Length(src) = 0 then
    raise Exception.CreateFmt('Shader source is empty: %s', [fileName]);

  res := shaderc_compile_into_spv(
    gShadercCompiler,
    PAnsiChar(src),
    TSizeT(Length(src)),
    shaderKind,
    PAnsiChar(AnsiString(fileName)),
    'main',
    gShadercOptions
  );
  if res = nil then
    raise Exception.CreateFmt('shaderc_compile_into_spv returned nil: %s', [fileName]);

  try
    status := shaderc_result_get_compilation_status(res);
    if status <> shaderc_compilation_status_success then
    begin
      errMsg := shaderc_result_get_error_message(res);
      if errMsg <> nil then
        raise Exception.CreateFmt('Shader compile failed (%s): %s', [fileName, string(AnsiString(errMsg))])
      else
        raise Exception.CreateFmt('Shader compile failed (%s): status=%d', [fileName, status]);
    end;

    byteLen := shaderc_result_get_length(res);
    if (byteLen = 0) or ((byteLen mod 4) <> 0) then
      raise Exception.CreateFmt('Invalid SPIR-V length from shaderc (%s): %d bytes', [fileName, Integer(byteLen)]);

    bytes := shaderc_result_get_bytes(res);
    if bytes = nil then
      raise Exception.CreateFmt('shaderc_result_get_bytes returned nil (%s)', [fileName]);

    wordCount := Integer(byteLen div 4);
    SetLength(Result, wordCount);
    Move(bytes^, Result[0], wordCount * 4);
  finally
    shaderc_result_release(res);
  end;
end;

function CreateShaderModuleFromWords(device: VkDevice; const words: TUInt32DynArray): VkShaderModule;
var
  ci: TVkShaderModuleCreateInfo;
begin
  if Length(words) = 0 then
    raise Exception.Create('CreateShaderModuleFromWords: empty code');

  FillChar(ci, SizeOf(ci), 0);
  ci.sType := VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO;
  ci.codeSize := Length(words) * 4;
  ci.pCode := @words[0];

  Result := 0;
  VkCheck(vkCreateShaderModule(device, @ci, nil, Result), 'vkCreateShaderModule');
end;

function CreateShaderModuleFromFile(device: VkDevice; const fileName: string): VkShaderModule;
var
  data: TBytes;
  ci: TVkShaderModuleCreateInfo;
begin
  Dbgf('CreateShaderModuleFromFile: %s', [fileName]);
  if not ReadFileBytes(fileName, data) then
    raise Exception.CreateFmt('Shader file not found: %s', [fileName]);
  if (Length(data) mod 4) <> 0 then
    raise Exception.CreateFmt('SPIR-V size must be multiple of 4: %s', [fileName]);

  Dbgf('Shader size=%d bytes', [Length(data)]);

  FillChar(ci, SizeOf(ci), 0);
  ci.sType := VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO;
  ci.codeSize := Length(data);
  ci.pCode := PUInt32(@data[0]);

  Result := 0;
  VkCheck(vkCreateShaderModule(device, @ci, nil, Result), 'vkCreateShaderModule');
end;

function FindMemoryType(typeBits: UInt32; properties: UInt32): UInt32;
var
  memProps: TVkPhysicalDeviceMemoryProperties;
  i: UInt32;
begin
  vkGetPhysicalDeviceMemoryProperties(gPhysicalDevice, memProps);
  Dbgf('FindMemoryType: typeBits=%x properties=%x count=%d', [typeBits, properties, memProps.memoryTypeCount]);
  for i := 0 to memProps.memoryTypeCount - 1 do
  begin
    if ((typeBits and (UInt32(1) shl i)) <> 0) and ((memProps.memoryTypes[i].propertyFlags and properties) = properties) then
    begin
      Dbgf('FindMemoryType: match index=%d flags=%x', [i, memProps.memoryTypes[i].propertyFlags]);
      Exit(i);
    end;
  end;
  raise Exception.Create('No suitable memory type found');
end;

procedure CreateBuffer(size: VkDeviceSize; usage: UInt32; properties: UInt32; out buffer: VkBuffer; out memory: VkDeviceMemory);
var
  ci: TVkBufferCreateInfo;
  memReq: TVkMemoryRequirements;
  ai: TVkMemoryAllocateInfo;
  memTypeIndex: UInt32;
  res: VkResult;
begin
  Dbg('CreateBuffer: size=' + IntToStr(Integer(size)) + ' usage=' + IntToHex(usage, 1) + ' properties=' + IntToHex(properties, 1));
  FillChar(ci, SizeOf(ci), 0);
  ci.sType := VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO;
  ci.size := size;
  ci.usage := usage;
  ci.sharingMode := VK_SHARING_MODE_EXCLUSIVE;

  buffer := 0;
  res := vkCreateBuffer(gDevice, @ci, nil, buffer);
  Dbgf('vkCreateBuffer res=%d buffer=%s', [res, string(U64Hex(buffer))]);
  VkCheck(res, 'vkCreateBuffer');

  vkGetBufferMemoryRequirements(gDevice, buffer, memReq);
  Dbg('MemReq: size=' + IntToStr(Integer(memReq.size)) + ' align=' + IntToStr(Integer(memReq.alignment)) + ' typeBits=' + IntToHex(memReq.memoryTypeBits, 1));
  memTypeIndex := FindMemoryType(memReq.memoryTypeBits, properties);
  Dbg(AnsiString('CreateBuffer: memTypeIndex=' + IntToStr(memTypeIndex)));
  Dbg('CreateBuffer: after FindMemoryType');

  FillChar(ai, SizeOf(ai), 0);
  ai.sType := VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO;
  ai.allocationSize := memReq.size;
  ai.memoryTypeIndex := memTypeIndex;
  Dbg('CreateBuffer: before vkAllocateMemory');
  Dbg('vkAllocateMemory size=' + IntToStr(Integer(ai.allocationSize)) + ' memTypeIndex=' + IntToStr(Integer(ai.memoryTypeIndex)));

  memory := 0;
  res := vkAllocateMemory(gDevice, @ai, nil, memory);
  Dbgf('vkAllocateMemory res=%d memory=%s', [res, string(U64Hex(memory))]);
  VkCheck(res, 'vkAllocateMemory');

  res := vkBindBufferMemory(gDevice, buffer, memory, 0);
  Dbgf('vkBindBufferMemory res=%d', [res]);
  VkCheck(res, 'vkBindBufferMemory');
  Dbg('CreateBuffer: success');
end;

procedure UpdateParamsBuffer(const params: TComputeParams);
var
  data: Pointer;
begin
  data := nil;
  VkCheck(vkMapMemory(gDevice, gParamMemory, 0, SizeOf(params), 0, data), 'vkMapMemory');
  if data <> nil then
    Move(params, data^, SizeOf(params));
  vkUnmapMemory(gDevice, gParamMemory);
end;

procedure CreateComputeResources;
var
  bindings: array[0..2] of TVkDescriptorSetLayoutBinding;
  dslci: TVkDescriptorSetLayoutCreateInfo;
  plci: TVkPipelineLayoutCreateInfo;
  poolSizes: array[0..1] of TVkDescriptorPoolSize;
  dpci: TVkDescriptorPoolCreateInfo;
  dsai: TVkDescriptorSetAllocateInfo;
  dbi: array[0..2] of TVkDescriptorBufferInfo;
  writes: array[0..2] of TVkWriteDescriptorSet;
  compMod: VkShaderModule;
  stage: TVkPipelineShaderStageCreateInfo;
  cpci: TVkComputePipelineCreateInfo;
  params: TComputeParams;
begin
  DbgEnter('CreateComputeResources');
  Dbgf('NUM_HARMONOGRAPH_POINTS=%d', [NUM_HARMONOGRAPH_POINTS]);
  Dbgf('SPV vert=%s frag=%s comp=%s', ['hello_vert.spv', 'hello_frag.spv', 'hello_comp.spv']);
  // Descriptor set layout
  bindings[0].binding := 0;
  bindings[0].descriptorType := VK_DESCRIPTOR_TYPE_STORAGE_BUFFER;
  bindings[0].descriptorCount := 1;
  bindings[0].stageFlags := VK_SHADER_STAGE_COMPUTE_BIT or VK_SHADER_STAGE_VERTEX_BIT;
  bindings[0].pImmutableSamplers := nil;

  bindings[1] := bindings[0];
  bindings[1].binding := 1;

  bindings[2].binding := 2;
  bindings[2].descriptorType := VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER;
  bindings[2].descriptorCount := 1;
  bindings[2].stageFlags := VK_SHADER_STAGE_COMPUTE_BIT;
  bindings[2].pImmutableSamplers := nil;

  FillChar(dslci, SizeOf(dslci), 0);
  dslci.sType := VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO;
  dslci.bindingCount := 3;
  dslci.pBindings := @bindings[0];

  gDescriptorSetLayout := 0;
  VkCheck(vkCreateDescriptorSetLayout(gDevice, @dslci, nil, gDescriptorSetLayout), 'vkCreateDescriptorSetLayout');
  Dbgf('DescriptorSetLayout=%s', [string(U64Hex(gDescriptorSetLayout))]);

  // Pipeline layout
  FillChar(plci, SizeOf(plci), 0);
  plci.sType := VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO;
  plci.setLayoutCount := 1;
  plci.pSetLayouts := @gDescriptorSetLayout;

  gPipelineLayout := 0;
  VkCheck(vkCreatePipelineLayout(gDevice, @plci, nil, gPipelineLayout), 'vkCreatePipelineLayout');
  Dbgf('PipelineLayout=%s', [string(U64Hex(gPipelineLayout))]);

  // Buffers
  CreateBuffer(VkDeviceSize(NUM_HARMONOGRAPH_POINTS) * 16, VK_BUFFER_USAGE_STORAGE_BUFFER_BIT,
    VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT or VK_MEMORY_PROPERTY_HOST_COHERENT_BIT, gPositionBuffer, gPositionMemory);
  CreateBuffer(VkDeviceSize(NUM_HARMONOGRAPH_POINTS) * 16, VK_BUFFER_USAGE_STORAGE_BUFFER_BIT,
    VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT or VK_MEMORY_PROPERTY_HOST_COHERENT_BIT, gColorBuffer, gColorMemory);
  CreateBuffer(SizeOf(TComputeParams), VK_BUFFER_USAGE_UNIFORM_BUFFER_BIT,
    VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT or VK_MEMORY_PROPERTY_HOST_COHERENT_BIT, gParamBuffer, gParamMemory);

  // Descriptor pool
  poolSizes[0].type_ := VK_DESCRIPTOR_TYPE_STORAGE_BUFFER;
  poolSizes[0].descriptorCount := 2;
  poolSizes[1].type_ := VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER;
  poolSizes[1].descriptorCount := 1;

  FillChar(dpci, SizeOf(dpci), 0);
  dpci.sType := VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO;
  dpci.maxSets := 1;
  dpci.poolSizeCount := 2;
  dpci.pPoolSizes := @poolSizes[0];

  gDescriptorPool := 0;
  VkCheck(vkCreateDescriptorPool(gDevice, @dpci, nil, gDescriptorPool), 'vkCreateDescriptorPool');
  Dbgf('DescriptorPool=%s', [string(U64Hex(gDescriptorPool))]);

  // Descriptor set
  FillChar(dsai, SizeOf(dsai), 0);
  dsai.sType := VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO;
  dsai.descriptorPool := gDescriptorPool;
  dsai.descriptorSetCount := 1;
  dsai.pSetLayouts := @gDescriptorSetLayout;

  gDescriptorSet := 0;
  VkCheck(vkAllocateDescriptorSets(gDevice, @dsai, @gDescriptorSet), 'vkAllocateDescriptorSets');
  Dbgf('DescriptorSet=%s', [string(U64Hex(gDescriptorSet))]);

  dbi[0].buffer := gPositionBuffer;
  dbi[0].offset := 0;
  dbi[0].range := VkDeviceSize(NUM_HARMONOGRAPH_POINTS) * 16;
  dbi[1].buffer := gColorBuffer;
  dbi[1].offset := 0;
  dbi[1].range := VkDeviceSize(NUM_HARMONOGRAPH_POINTS) * 16;
  dbi[2].buffer := gParamBuffer;
  dbi[2].offset := 0;
  dbi[2].range := SizeOf(TComputeParams);

  FillChar(writes, SizeOf(writes), 0);
  writes[0].sType := VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET;
  writes[0].dstSet := gDescriptorSet;
  writes[0].dstBinding := 0;
  writes[0].descriptorCount := 1;
  writes[0].descriptorType := VK_DESCRIPTOR_TYPE_STORAGE_BUFFER;
  writes[0].pBufferInfo := @dbi[0];

  writes[1] := writes[0];
  writes[1].dstBinding := 1;
  writes[1].pBufferInfo := @dbi[1];

  writes[2] := writes[0];
  writes[2].dstBinding := 2;
  writes[2].descriptorType := VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER;
  writes[2].pBufferInfo := @dbi[2];

  vkUpdateDescriptorSets(gDevice, 3, @writes[0], 0, nil);
  Dbg('DescriptorSets updated');

  // Compute pipeline
  compMod := CreateShaderModuleFromFile(gDevice, 'hello_comp.spv');

  FillChar(stage, SizeOf(stage), 0);
  stage.sType := VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO;
  stage.stage := VK_SHADER_STAGE_COMPUTE_BIT;
  stage.module_ := compMod;
  stage.pName := 'main';

  FillChar(cpci, SizeOf(cpci), 0);
  cpci.sType := VK_STRUCTURE_TYPE_COMPUTE_PIPELINE_CREATE_INFO;
  cpci.stage := stage;
  cpci.layout := gPipelineLayout;
  cpci.basePipelineHandle := 0;
  cpci.basePipelineIndex := -1;

  gComputePipeline := 0;
  VkCheck(vkCreateComputePipelines(gDevice, 0, 1, @cpci, nil, gComputePipeline), 'vkCreateComputePipelines');
  Dbgf('ComputePipeline=%s', [string(U64Hex(gComputePipeline))]);

  vkDestroyShaderModule(gDevice, compMod, nil);

  // Initial params
  FillChar(params, SizeOf(params), 0);
  params.max_num := NUM_HARMONOGRAPH_POINTS;
  params.dt := 0.001;
  params.scale := 0.02;
  params.A1 := 50.0; params.f1 := 2.0; params.p1 := 1.0 / 16.0; params.d1 := 0.02;
  params.A2 := 50.0; params.f2 := 2.0; params.p2 := 3.0 / 2.0; params.d2 := 0.0315;
  params.A3 := 50.0; params.f3 := 2.0; params.p3 := 13.0 / 15.0; params.d3 := 0.02;
  params.A4 := 50.0; params.f4 := 2.0; params.p4 := 1.0; params.d4 := 0.02;
  UpdateParamsBuffer(params);
  Dbg('Compute params initialized');
  DbgLeave('CreateComputeResources');
end;

function ChooseSurfaceFormat(const fmts: array of TVkSurfaceFormatKHR): TVkSurfaceFormatKHR;
var
  i: Integer;
begin
  Result := fmts[0];
  for i := 0 to High(fmts) do
    if fmts[i].format = VK_FORMAT_B8G8R8A8_UNORM then
      Exit(fmts[i]);
end;

function ChooseExtent(hwnd: HWND; const caps: TVkSurfaceCapabilitiesKHR): TVkExtent2D;
var
  rc: TRect;
  w, h: Integer;
begin
  if (caps.currentExtent.width <> $FFFFFFFF) and (caps.currentExtent.height <> $FFFFFFFF) then
    Exit(caps.currentExtent);

  GetClientRect(hwnd, rc);
  w := rc.Right - rc.Left;
  h := rc.Bottom - rc.Top;

  if w < Integer(caps.minImageExtent.width) then w := Integer(caps.minImageExtent.width);
  if h < Integer(caps.minImageExtent.height) then h := Integer(caps.minImageExtent.height);
  if w > Integer(caps.maxImageExtent.width) then w := Integer(caps.maxImageExtent.width);
  if h > Integer(caps.maxImageExtent.height) then h := Integer(caps.maxImageExtent.height);

  Result.width := UInt32(w);
  Result.height := UInt32(h);
end;

procedure DestroySwapchainBundle(device: VkDevice; var b: TSwapchainBundle);
var
  i: Integer;
begin
  if device = nil then Exit;

  if b.commandPool <> nil then
  begin
    vkDestroyCommandPool(device, b.commandPool, nil);
    b.commandPool := nil;
  end;

  for i := 0 to High(b.framebuffers) do
    if b.framebuffers[i] <> 0 then
      vkDestroyFramebuffer(device, b.framebuffers[i], nil);
  SetLength(b.framebuffers, 0);

  if b.pipeline <> 0 then vkDestroyPipeline(device, b.pipeline, nil);
  if b.renderPass <> 0 then vkDestroyRenderPass(device, b.renderPass, nil);

  for i := 0 to High(b.views) do
    if b.views[i] <> 0 then
      vkDestroyImageView(device, b.views[i], nil);
  SetLength(b.views, 0);
  SetLength(b.images, 0);

  if b.swapchain <> 0 then
    vkDestroySwapchainKHR(device, b.swapchain, nil);

  b.swapchain := 0;
  b.format := 0;
  b.extent.width := 0;
  b.extent.height := 0;
  b.imageCount := 0;
  b.renderPass := 0;
  b.pipelineLayout := 0;
  b.pipeline := 0;
  b.commandPool := nil;
end;

procedure RecordCommandBuffer(device: VkDevice; var b: TSwapchainBundle; imageIndex: UInt32; timeSec: Single);
var
  beginInfo: TVkCommandBufferBeginInfo;
  clear: TVkClearValue;
  rpbi: TVkRenderPassBeginInfo;
  vp: TVkViewport;
  sc: TVkRect2D;
  barriers: array[0..1] of TVkBufferMemoryBarrier;
  groups: UInt32;
begin
  DbgEnter('RecordCommandBuffer');
  Dbgf('imageIndex=%u timeSec=%.3f', [imageIndex, timeSec]);
  FillChar(clear, SizeOf(clear), 0);
  clear.color.float32[0] := 0.0;
  clear.color.float32[1] := 0.0;
  clear.color.float32[2] := 0.0;
  clear.color.float32[3] := 1.0;

  FillChar(beginInfo, SizeOf(beginInfo), 0);
  beginInfo.sType := VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO;
  VkCheck(vkBeginCommandBuffer(b.commandBuffers[imageIndex], @beginInfo), 'vkBeginCommandBuffer');

  vkCmdBindPipeline(b.commandBuffers[imageIndex], VK_PIPELINE_BIND_POINT_COMPUTE, gComputePipeline);
  vkCmdBindDescriptorSets(b.commandBuffers[imageIndex], VK_PIPELINE_BIND_POINT_COMPUTE, gPipelineLayout, 0, 1, @gDescriptorSet, 0, nil);
  groups := (NUM_HARMONOGRAPH_POINTS + 255) div 256;
  Dbgf('Dispatch groups=%u', [groups]);
  vkCmdDispatch(b.commandBuffers[imageIndex], groups, 1, 1);

  FillChar(barriers, SizeOf(barriers), 0);
  barriers[0].sType := VK_STRUCTURE_TYPE_BUFFER_MEMORY_BARRIER;
  barriers[0].srcAccessMask := VK_ACCESS_SHADER_WRITE_BIT;
  barriers[0].dstAccessMask := VK_ACCESS_SHADER_READ_BIT;
  barriers[0].srcQueueFamilyIndex := VK_QUEUE_FAMILY_IGNORED;
  barriers[0].dstQueueFamilyIndex := VK_QUEUE_FAMILY_IGNORED;
  barriers[0].buffer := gPositionBuffer;
  barriers[0].offset := 0;
  barriers[0].size := VkDeviceSize(NUM_HARMONOGRAPH_POINTS) * 16;

  barriers[1] := barriers[0];
  barriers[1].buffer := gColorBuffer;

  vkCmdPipelineBarrier(b.commandBuffers[imageIndex],
    VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT, VK_PIPELINE_STAGE_VERTEX_SHADER_BIT,
    0, 0, nil, 2, @barriers[0], 0, nil);

  vp.x := 0; vp.y := 0;
  vp.width := b.extent.width;
  vp.height := b.extent.height;
  vp.minDepth := 0;
  vp.maxDepth := 1;

  sc.offset.x := 0;
  sc.offset.y := 0;
  sc.extent := b.extent;

  FillChar(rpbi, SizeOf(rpbi), 0);
  rpbi.sType := VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO;
  rpbi.renderPass := b.renderPass;
  rpbi.framebuffer := b.framebuffers[imageIndex];
  rpbi.renderArea.offset.x := 0;
  rpbi.renderArea.offset.y := 0;
  rpbi.renderArea.extent := b.extent;
  rpbi.clearValueCount := 1;
  rpbi.pClearValues := @clear;

  vkCmdBeginRenderPass(b.commandBuffers[imageIndex], @rpbi, 0);
  vkCmdBindPipeline(b.commandBuffers[imageIndex], VK_PIPELINE_BIND_POINT_GRAPHICS, b.pipeline);
  vkCmdBindDescriptorSets(b.commandBuffers[imageIndex], VK_PIPELINE_BIND_POINT_GRAPHICS, gPipelineLayout, 0, 1, @gDescriptorSet, 0, nil);
  vkCmdSetViewport(b.commandBuffers[imageIndex], 0, 1, @vp);
  vkCmdSetScissor(b.commandBuffers[imageIndex], 0, 1, @sc);
  vkCmdDraw(b.commandBuffers[imageIndex], NUM_HARMONOGRAPH_POINTS, 1, 0, 0);
  vkCmdEndRenderPass(b.commandBuffers[imageIndex]);

  VkCheck(vkEndCommandBuffer(b.commandBuffers[imageIndex]), 'vkEndCommandBuffer');
  DbgLeave('RecordCommandBuffer');
end;

procedure CreateSwapchainBundle(instance: VkInstance; device: VkDevice; pd: VkPhysicalDevice; surface: VkSurfaceKHR;
  hwnd: HWND; graphicsQ, presentQ: UInt32; const vertSpv, fragSpv: string; out b: TSwapchainBundle);
var
  caps: TVkSurfaceCapabilitiesKHR;
  fmtCount, pmCount, imgCount: UInt32;
  fmts: array of TVkSurfaceFormatKHR;
  pms: array of UInt32;
  sfmt: TVkSurfaceFormatKHR;
  extent: TVkExtent2D;
  desiredCount: UInt32;
  qIndices: array[0..1] of UInt32;
  sharingMode: UInt32;
  qCount: UInt32;
  pQ: PUInt32;
  sci: TVkSwapchainCreateInfoKHR;
  i: Integer;
  ivci: TVkImageViewCreateInfo;
  colorAttach: TVkAttachmentDescription;
  colorRef: TVkAttachmentReference;
  subpass: TVkSubpassDescription;
  rpci: TVkRenderPassCreateInfo;
  vertMod, fragMod: VkShaderModule;
  stages: array[0..1] of TVkPipelineShaderStageCreateInfo;
  vin: TVkPipelineVertexInputStateCreateInfo;
  ia: TVkPipelineInputAssemblyStateCreateInfo;
  vpState: TVkPipelineViewportStateCreateInfo;
  rs: TVkPipelineRasterizationStateCreateInfo;
  ms: TVkPipelineMultisampleStateCreateInfo;
  cbAttach: TVkPipelineColorBlendAttachmentState;
  cb: TVkPipelineColorBlendStateCreateInfo;
  dynStates: array[0..1] of UInt32;
  dyn: TVkPipelineDynamicStateCreateInfo;
  gpci: TVkGraphicsPipelineCreateInfo;
  fbci: TVkFramebufferCreateInfo;
  cpci: TVkCommandPoolCreateInfo;
  cbi: TVkCommandBufferAllocateInfo;
  dummyVp: TVkViewport;
  dummySc: TVkRect2D;
  attachments: array[0..0] of VkImageView;
begin
  FillChar(b, SizeOf(b), 0);

  VkCheck(vkGetPhysicalDeviceSurfaceCapabilitiesKHR(pd, surface, caps), 'vkGetPhysicalDeviceSurfaceCapabilitiesKHR');

  fmtCount := 0;
  VkCheck(vkGetPhysicalDeviceSurfaceFormatsKHR(pd, surface, @fmtCount, nil), 'vkGetPhysicalDeviceSurfaceFormatsKHR(count)');
  SetLength(fmts, fmtCount);
  if fmtCount > 0 then
    VkCheck(vkGetPhysicalDeviceSurfaceFormatsKHR(pd, surface, @fmtCount, @fmts[0]), 'vkGetPhysicalDeviceSurfaceFormatsKHR(list)');

  pmCount := 0;
  VkCheck(vkGetPhysicalDeviceSurfacePresentModesKHR(pd, surface, @pmCount, nil), 'vkGetPhysicalDeviceSurfacePresentModesKHR(count)');
  SetLength(pms, pmCount);
  if pmCount > 0 then
    VkCheck(vkGetPhysicalDeviceSurfacePresentModesKHR(pd, surface, @pmCount, @pms[0]), 'vkGetPhysicalDeviceSurfacePresentModesKHR(list)');

  sfmt := ChooseSurfaceFormat(fmts);
  extent := ChooseExtent(hwnd, caps);

  desiredCount := caps.minImageCount + 1;
  if (caps.maxImageCount <> 0) and (desiredCount > caps.maxImageCount) then
    desiredCount := caps.maxImageCount;

  qIndices[0] := graphicsQ;
  qIndices[1] := presentQ;

  if graphicsQ <> presentQ then
  begin
    sharingMode := VK_SHARING_MODE_CONCURRENT;
    qCount := 2;
    pQ := @qIndices[0];
  end
  else
  begin
    sharingMode := VK_SHARING_MODE_EXCLUSIVE;
    qCount := 0;
    pQ := nil;
  end;

  FillChar(sci, SizeOf(sci), 0);
  sci.sType := VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR;
  sci.surface := surface;
  sci.minImageCount := desiredCount;
  sci.imageFormat := sfmt.format;
  sci.imageColorSpace := sfmt.colorSpace;
  sci.imageExtent := extent;
  sci.imageArrayLayers := 1;
  sci.imageUsage := VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT;
  sci.imageSharingMode := sharingMode;
  sci.queueFamilyIndexCount := qCount;
  sci.pQueueFamilyIndices := pQ;

  if (caps.supportedTransforms and caps.currentTransform) <> 0 then
    sci.preTransform := caps.currentTransform
  else
    sci.preTransform := VK_SURFACE_TRANSFORM_IDENTITY_BIT_KHR;

  sci.compositeAlpha := VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR;
  sci.presentMode := VK_PRESENT_MODE_FIFO_KHR;
  sci.clipped := 1;
  sci.oldSwapchain := 0;

  b.swapchain := 0;
  Dbgf('vkCreateSwapchainKHR fp=%s device=%s surface=%s fmt=%d colorspace=%d extent=%dx%d minImages=%u sharingMode=%u qCount=%u',
       [string(PtrHex(gfp_vkCreateSwapchainKHR)), string(U64Hex(QWord(device))), string(U64Hex(QWord(surface))),
        Ord(sfmt.format), Ord(sfmt.colorSpace), extent.width, extent.height, desiredCount, Ord(sharingMode), qCount]);
  VkCheck(vkCreateSwapchainKHR(device, @sci, nil, b.swapchain), 'vkCreateSwapchainKHR');
  b.format := sfmt.format;
  b.extent := extent;

  imgCount := 0;
  VkCheck(vkGetSwapchainImagesKHR(device, b.swapchain, @imgCount, nil), 'vkGetSwapchainImagesKHR(count)');
  b.imageCount := imgCount;
  SetLength(b.images, imgCount);
  VkCheck(vkGetSwapchainImagesKHR(device, b.swapchain, @imgCount, @b.images[0]), 'vkGetSwapchainImagesKHR(list)');

  SetLength(b.views, imgCount);
  for i := 0 to Integer(imgCount) - 1 do
  begin
    FillChar(ivci, SizeOf(ivci), 0);
    ivci.sType := VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO;
    ivci.image := b.images[i];
    ivci.viewType := VK_IMAGE_VIEW_TYPE_2D;
    ivci.format := b.format;
    ivci.components.r := 0;
    ivci.components.g := 0;
    ivci.components.b := 0;
    ivci.components.a := 0;
    ivci.subresourceRange.aspectMask := VK_IMAGE_ASPECT_COLOR_BIT;
    ivci.subresourceRange.baseMipLevel := 0;
    ivci.subresourceRange.levelCount := 1;
    ivci.subresourceRange.baseArrayLayer := 0;
    ivci.subresourceRange.layerCount := 1;

    b.views[i] := 0;
    VkCheck(vkCreateImageView(device, @ivci, nil, b.views[i]), 'vkCreateImageView');
  end;

  // Render pass (single color attachment)
  FillChar(colorAttach, SizeOf(colorAttach), 0);
  colorAttach.format := b.format;
  colorAttach.samples := VK_SAMPLE_COUNT_1_BIT;
  colorAttach.loadOp := VK_ATTACHMENT_LOAD_OP_CLEAR;
  colorAttach.storeOp := VK_ATTACHMENT_STORE_OP_STORE;
  colorAttach.initialLayout := VK_IMAGE_LAYOUT_UNDEFINED;
  colorAttach.finalLayout := VK_IMAGE_LAYOUT_PRESENT_SRC_KHR;

  colorRef.attachment := 0;
  colorRef.layout := VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL;

  FillChar(subpass, SizeOf(subpass), 0);
  subpass.pipelineBindPoint := VK_PIPELINE_BIND_POINT_GRAPHICS;
  subpass.colorAttachmentCount := 1;
  subpass.pColorAttachments := @colorRef;

  FillChar(rpci, SizeOf(rpci), 0);
  rpci.sType := VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO;
  rpci.attachmentCount := 1;
  rpci.pAttachments := @colorAttach;
  rpci.subpassCount := 1;
  rpci.pSubpasses := @subpass;

  b.renderPass := 0;
  VkCheck(vkCreateRenderPass(device, @rpci, nil, b.renderPass), 'vkCreateRenderPass');

  // Shaders (precompiled SPIR-V)
  vertMod := CreateShaderModuleFromFile(device, vertSpv);
  fragMod := CreateShaderModuleFromFile(device, fragSpv);

  // Pipeline layout (shared with compute resources)
  b.pipelineLayout := 0;

  // Shader stages
  FillChar(stages, SizeOf(stages), 0);
  stages[0].sType := VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO;
  stages[0].stage := VK_SHADER_STAGE_VERTEX_BIT;
  stages[0].module_ := vertMod;
  stages[0].pName := 'main';

  stages[1].sType := VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO;
  stages[1].stage := VK_SHADER_STAGE_FRAGMENT_BIT;
  stages[1].module_ := fragMod;
  stages[1].pName := 'main';

  FillChar(vin, SizeOf(vin), 0);
  vin.sType := VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO;

  FillChar(ia, SizeOf(ia), 0);
  ia.sType := VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO;
  ia.topology := VK_PRIMITIVE_TOPOLOGY_POINT_LIST;
  ia.primitiveRestartEnable := 0;

  // Viewport/scissor are dynamic, but some drivers want non-null pointers here.
  dummyVp.x := 0; dummyVp.y := 0;
  dummyVp.width := extent.width;
  dummyVp.height := extent.height;
  dummyVp.minDepth := 0;
  dummyVp.maxDepth := 1;

  dummySc.offset.x := 0;
  dummySc.offset.y := 0;
  dummySc.extent := extent;

  FillChar(vpState, SizeOf(vpState), 0);
  vpState.sType := VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO;
  vpState.viewportCount := 1;
  vpState.pViewports := @dummyVp;
  vpState.scissorCount := 1;
  vpState.pScissors := @dummySc;

  FillChar(rs, SizeOf(rs), 0);
  rs.sType := VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO;
  rs.polygonMode := VK_POLYGON_MODE_FILL;
  rs.cullMode := VK_CULL_MODE_NONE; // avoid winding issues
  rs.frontFace := VK_FRONT_FACE_COUNTER_CLOCKWISE;
  rs.lineWidth := 1.0;

  FillChar(ms, SizeOf(ms), 0);
  ms.sType := VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO;
  ms.rasterizationSamples := VK_SAMPLE_COUNT_1_BIT;

  FillChar(cbAttach, SizeOf(cbAttach), 0);
  cbAttach.colorWriteMask := VK_COLOR_COMPONENT_R_BIT or VK_COLOR_COMPONENT_G_BIT or VK_COLOR_COMPONENT_B_BIT or VK_COLOR_COMPONENT_A_BIT;

  FillChar(cb, SizeOf(cb), 0);
  cb.sType := VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO;
  cb.attachmentCount := 1;
  cb.pAttachments := @cbAttach;

  dynStates[0] := VK_DYNAMIC_STATE_VIEWPORT;
  dynStates[1] := VK_DYNAMIC_STATE_SCISSOR;

  FillChar(dyn, SizeOf(dyn), 0);
  dyn.sType := VK_STRUCTURE_TYPE_PIPELINE_DYNAMIC_STATE_CREATE_INFO;
  dyn.dynamicStateCount := 2;
  dyn.pDynamicStates := @dynStates[0];

  FillChar(gpci, SizeOf(gpci), 0);
  gpci.sType := VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO;
  gpci.stageCount := 2;
  gpci.pStages := @stages[0];
  gpci.pVertexInputState := @vin;
  gpci.pInputAssemblyState := @ia;
  gpci.pViewportState := @vpState;
  gpci.pRasterizationState := @rs;
  gpci.pMultisampleState := @ms;
  gpci.pColorBlendState := @cb;
  gpci.pDynamicState := @dyn;
  gpci.layout := gPipelineLayout;
  gpci.renderPass := b.renderPass;
  gpci.subpass := 0;
  gpci.basePipelineHandle := 0;
  gpci.basePipelineIndex := -1;

  b.pipeline := 0;
  VkCheck(vkCreateGraphicsPipelines(device, 0, 1, @gpci, nil, b.pipeline), 'vkCreateGraphicsPipelines');

  vkDestroyShaderModule(device, vertMod, nil);
  vkDestroyShaderModule(device, fragMod, nil);

  // Framebuffers
  SetLength(b.framebuffers, imgCount);
  for i := 0 to Integer(imgCount) - 1 do
  begin
    attachments[0] := b.views[i];

    FillChar(fbci, SizeOf(fbci), 0);
    fbci.sType := VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO;
    fbci.renderPass := b.renderPass;
    fbci.attachmentCount := 1;
    fbci.pAttachments := @attachments[0];
    fbci.width := extent.width;
    fbci.height := extent.height;
    fbci.layers := 1;

    b.framebuffers[i] := 0;
    VkCheck(vkCreateFramebuffer(device, @fbci, nil, b.framebuffers[i]), 'vkCreateFramebuffer');
  end;

  // Command pool + buffers
  FillChar(cpci, SizeOf(cpci), 0);
  cpci.sType := VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO;
  cpci.flags := VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT;
  cpci.queueFamilyIndex := graphicsQ;

  b.commandPool := nil;
  VkCheck(vkCreateCommandPool(device, @cpci, nil, b.commandPool), 'vkCreateCommandPool');

  SetLength(b.commandBuffers, imgCount);
  FillChar(cbi, SizeOf(cbi), 0);
  cbi.sType := VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO;
  cbi.commandPool := b.commandPool;
  cbi.level_ := VK_COMMAND_BUFFER_LEVEL_PRIMARY;
  cbi.commandBufferCount := imgCount;

  VkCheck(vkAllocateCommandBuffers(device, @cbi, @b.commandBuffers[0]), 'vkAllocateCommandBuffers');
end;

procedure RecreateSwapchain;
var
  newBundle: TSwapchainBundle;
begin
  VkCheck(vkDeviceWaitIdle(gDevice), 'vkDeviceWaitIdle');
  DestroySwapchainBundle(gDevice, gBundle);

  CreateSwapchainBundle(gInstance, gDevice, gPhysicalDevice, gSurface, gHwnd, gGraphicsQFamily, gPresentQFamily,
	  'hello_vert.spv', 'hello_frag.spv', newBundle);

  gBundle := newBundle;
end;

procedure CreateSyncObjects(device: VkDevice; out s: TSyncObjects);
var
  sci: TVkSemaphoreCreateInfo;
  fci: TVkFenceCreateInfo;
  i: Integer;
begin
  FillChar(s, SizeOf(s), 0);
  FillChar(sci, SizeOf(sci), 0);
  sci.sType := VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO;

  FillChar(fci, SizeOf(fci), 0);
  fci.sType := VK_STRUCTURE_TYPE_FENCE_CREATE_INFO;
  fci.flags := VK_FENCE_CREATE_SIGNALED_BIT;

  for i := 0 to 1 do
  begin
    s.imageAvailable[i] := 0;
    s.renderFinished[i] := 0;
    s.inFlight[i] := 0;

    VkCheck(vkCreateSemaphore(device, @sci, nil, s.imageAvailable[i]), 'vkCreateSemaphore');
    VkCheck(vkCreateSemaphore(device, @sci, nil, s.renderFinished[i]), 'vkCreateSemaphore');
    VkCheck(vkCreateFence(device, @fci, nil, s.inFlight[i]), 'vkCreateFence');
  end;
end;

procedure DestroySyncObjects(device: VkDevice; var s: TSyncObjects);
var
  i: Integer;
begin
  if device = nil then Exit;
  for i := 0 to 1 do
  begin
    if s.imageAvailable[i] <> 0 then vkDestroySemaphore(device, s.imageAvailable[i], nil);
    if s.renderFinished[i] <> 0 then vkDestroySemaphore(device, s.renderFinished[i], nil);
    if s.inFlight[i] <> 0 then vkDestroyFence(device, s.inFlight[i], nil);
    s.imageAvailable[i] := 0;
    s.renderFinished[i] := 0;
    s.inFlight[i] := 0;
  end;
end;

procedure DrawFrame;
var
  cur: UInt32;
  fenceArr: array[0..0] of VkFence;
  imageIndex: UInt32;
  res: VkResult;
  timeSec: Single;
  params: TComputeParams;

  waitSems: array[0..0] of VkSemaphore;
  signalSems: array[0..0] of VkSemaphore;
  waitStages: array[0..0] of UInt32;
  cmd: VkCommandBuffer;
  cmdArr: array[0..0] of VkCommandBuffer;

  submit: TVkSubmitInfo;
  present: TVkPresentInfoKHR;
  swapArr: array[0..0] of VkSwapchainKHR;
  idxArr: array[0..0] of UInt32;
begin
  DbgEnter('DrawFrame');
  cur := gFrame and 1;
  Dbgf('frame=%u cur=%u', [gFrame, cur]);

  fenceArr[0] := gSync.inFlight[cur];
  VkCheck(vkWaitForFences(gDevice, 1, @fenceArr[0], 1, High(UInt64)), 'vkWaitForFences');
  VkCheck(vkResetFences(gDevice, 1, @fenceArr[0]), 'vkResetFences');

  imageIndex := 0;
  res := vkAcquireNextImageKHR(gDevice, gBundle.swapchain, High(UInt64), gSync.imageAvailable[cur], 0, imageIndex);
  Dbgf('vkAcquireNextImageKHR res=%d imageIndex=%u', [res, imageIndex]);
  if res = VK_ERROR_OUT_OF_DATE_KHR then
  begin
    RecreateSwapchain;
    DbgLeave('DrawFrame');
    Exit;
  end
  else if (res <> VK_SUCCESS) and (res <> VK_SUBOPTIMAL_KHR) then
    VkCheck(res, 'vkAcquireNextImageKHR');

  waitSems[0] := gSync.imageAvailable[cur];
  signalSems[0] := gSync.renderFinished[cur];
  waitStages[0] := VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT;

  cmd := gBundle.commandBuffers[imageIndex];
  timeSec := (GetTickCount64 - gStartTick) / 1000.0;
  gPhase := gPhase + 0.002;

  FillChar(params, SizeOf(params), 0);
  params.max_num := NUM_HARMONOGRAPH_POINTS;
  params.dt := 0.001;
  params.scale := 0.02;
  params.A1 := 50.0; params.f1 := 2.0 + 0.5 * Sin(timeSec * 0.7); params.p1 := (1.0 / 16.0) + gPhase; params.d1 := 0.02;
  params.A2 := 50.0; params.f2 := 2.0 + 0.5 * Sin(timeSec * 0.9); params.p2 := 3.0 / 2.0; params.d2 := 0.0315;
  params.A3 := 50.0; params.f3 := 2.0 + 0.5 * Sin(timeSec * 1.1); params.p3 := 13.0 / 15.0; params.d3 := 0.02;
  params.A4 := 50.0; params.f4 := 2.0 + 0.5 * Sin(timeSec * 1.3); params.p4 := 1.0; params.d4 := 0.02;
  UpdateParamsBuffer(params);

  VkCheck(vkResetCommandBuffer(cmd, 0), 'vkResetCommandBuffer');
  RecordCommandBuffer(gDevice, gBundle, imageIndex, timeSec);
  cmdArr[0] := cmd;

  FillChar(submit, SizeOf(submit), 0);
  submit.sType := VK_STRUCTURE_TYPE_SUBMIT_INFO;
  submit.waitSemaphoreCount := 1;
  submit.pWaitSemaphores := @waitSems[0];
  submit.pWaitDstStageMask := @waitStages[0];
  submit.commandBufferCount := 1;
  submit.pCommandBuffers := @cmdArr[0];
  submit.signalSemaphoreCount := 1;
  submit.pSignalSemaphores := @signalSems[0];

  VkCheck(vkQueueSubmit(gGraphicsQueue, 1, @submit, gSync.inFlight[cur]), 'vkQueueSubmit');

  swapArr[0] := gBundle.swapchain;
  idxArr[0] := imageIndex;

  FillChar(present, SizeOf(present), 0);
  present.sType := VK_STRUCTURE_TYPE_PRESENT_INFO_KHR;
  present.waitSemaphoreCount := 1;
  present.pWaitSemaphores := @signalSems[0];
  present.swapchainCount := 1;
  present.pSwapchains := @swapArr[0];
  present.pImageIndices := @idxArr[0];

  res := vkQueuePresentKHR(gPresentQueue, @present);
  Dbgf('vkQueuePresentKHR res=%d', [res]);
  if (res = VK_ERROR_OUT_OF_DATE_KHR) or (res = VK_SUBOPTIMAL_KHR) then
    RecreateSwapchain
  else
    VkCheck(res, 'vkQueuePresentKHR');

  Inc(gFrame);
  DbgLeave('DrawFrame');
end;

function WndProc(hWnd: HWND; Msg: UINT; wParam: WPARAM; lParam: LPARAM): LRESULT; stdcall;
begin
  case Msg of
    WM_CLOSE:
      begin
        gShouldQuit := True;
        PostQuitMessage(0);
        Result := 0;
        Exit;
      end;
    WM_DESTROY:
      begin
        gShouldQuit := True;
        PostQuitMessage(0);
        Result := 0;
        Exit;
      end;
    WM_SIZE:
      begin
        if (wParam <> SIZE_MINIMIZED) then
          gResized := True;
      end;
  end;
  Result := DefWindowProc(hWnd, Msg, wParam, lParam);
end;

procedure CreateMainWindow;
const
  CLASS_NAME = 'VkHarmonographWindowPascal';
var
  wc: WNDCLASSEX;
begin
  gHinst := GetModuleHandle(nil);

  FillChar(wc, SizeOf(wc), 0);
  wc.cbSize := SizeOf(wc);
  wc.style := CS_OWNDC;
  wc.lpfnWndProc := @WndProc;
  wc.hInstance := gHinst;
  wc.hCursor := LoadCursor(0, IDC_ARROW);
  wc.lpszClassName := CLASS_NAME;

  if RegisterClassEx(wc) = 0 then
    raise Exception.Create('RegisterClassEx failed');

  gHwnd := CreateWindowEx(
    0,
    CLASS_NAME,
    'Vulkan 1.4 Harmonograph (Pascal)',
    WS_OVERLAPPEDWINDOW,
    Integer(CW_USEDEFAULT), Integer(CW_USEDEFAULT),
    800, 600,
    0, 0,
    gHinst,
    nil
  );
  if gHwnd = 0 then
    raise Exception.Create('CreateWindowEx failed');

  ShowWindow(gHwnd, SW_SHOW);
  UpdateWindow(gHwnd);
end;

procedure CreateInstanceAndSurface;
var
  app: TVkApplicationInfo;
  ici: TVkInstanceCreateInfo;
  exts: array[0..1] of PAnsiChar;
  sci: TVkWin32SurfaceCreateInfoKHR;
begin
  DbgEnter('CreateInstanceAndSurface');

  FillChar(app, SizeOf(app), 0);
  app.sType := VK_STRUCTURE_TYPE_APPLICATION_INFO;
  app.pApplicationName := 'VkHarmonographPascal';
  app.applicationVersion := 1;
  app.pEngineName := 'NoEngine';
  app.engineVersion := 1;
  app.apiVersion := VK_API_VERSION_1_4;

  exts[0] := PAnsiChar(AnsiString(VK_KHR_SURFACE_EXTENSION_NAME));
  exts[1] := PAnsiChar(AnsiString(VK_KHR_WIN32_SURFACE_EXTENSION_NAME));
  Dbgf('Enable instance ext[0]=%s', [string(exts[0])]);
  Dbgf('Enable instance ext[1]=%s', [string(exts[1])]);


  FillChar(ici, SizeOf(ici), 0);
  ici.sType := VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO;
  ici.pApplicationInfo := @app;
  ici.enabledExtensionCount := 2;
  ici.ppEnabledExtensionNames := @exts[0];

  gInstance := nil;
  VkCheck(vkCreateInstance(@ici, nil, gInstance), 'vkCreateInstance');
  LoadInstanceFunctions(gInstance);

  // Surface
  FillChar(sci, SizeOf(sci), 0);
  sci.sType := VK_STRUCTURE_TYPE_WIN32_SURFACE_CREATE_INFO_KHR;
  sci.hinstance := gHinst;
  sci.hwnd := gHwnd;

  gSurface := 0;
  VkCheck(vkCreateWin32SurfaceKHR(gInstance, @sci, nil, gSurface), 'vkCreateWin32SurfaceKHR');

  DbgLeave('CreateInstanceAndSurface');
end;


procedure PickPhysicalDeviceAndQueues;
var
  count: UInt32;
  devs: array of VkPhysicalDevice;
  i, qi: Integer;
  qCount: UInt32;
  props: array of TVkQueueFamilyProperties;
  supported: VkBool32;
begin
  count := 0;
  VkCheck(vkEnumeratePhysicalDevices(gInstance, @count, nil), 'vkEnumeratePhysicalDevices(count)');
  if count = 0 then
    raise Exception.Create('No Vulkan physical devices found');

  SetLength(devs, count);
  VkCheck(vkEnumeratePhysicalDevices(gInstance, @count, @devs[0]), 'vkEnumeratePhysicalDevices(list)');

  for i := 0 to Integer(count) - 1 do
  begin
    gGraphicsQFamily := $FFFFFFFF;
    gPresentQFamily := $FFFFFFFF;

    qCount := 0;
    vkGetPhysicalDeviceQueueFamilyProperties(devs[i], @qCount, nil);
    SetLength(props, qCount);
    if qCount > 0 then
      vkGetPhysicalDeviceQueueFamilyProperties(devs[i], @qCount, @props[0]);

    for qi := 0 to Integer(qCount) - 1 do
    begin
      if (props[qi].queueFlags and VK_QUEUE_GRAPHICS_BIT) <> 0 then
        gGraphicsQFamily := UInt32(qi);

      supported := 0;
      VkCheck(vkGetPhysicalDeviceSurfaceSupportKHR(devs[i], UInt32(qi), gSurface, supported), 'vkGetPhysicalDeviceSurfaceSupportKHR');
      if supported <> 0 then
        gPresentQFamily := UInt32(qi);

      if (gGraphicsQFamily <> $FFFFFFFF) and (gPresentQFamily <> $FFFFFFFF) then
      begin
        gPhysicalDevice := devs[i];
        Exit;
      end;
    end;
  end;

  raise Exception.Create('No suitable physical device / queue family found');
end;

procedure CreateDeviceAndQueues;
var
  priorities: Single;
  unique: array of UInt32;
  qInfos: array of TVkDeviceQueueCreateInfo;
  dci: TVkDeviceCreateInfo;
  exts: array[0..0] of PAnsiChar;
  i: Integer;
begin
  priorities := 1.0;

  if gGraphicsQFamily = gPresentQFamily then
  begin
    SetLength(unique, 1);
    unique[0] := gGraphicsQFamily;
  end
  else
  begin
    SetLength(unique, 2);
    unique[0] := gGraphicsQFamily;
    unique[1] := gPresentQFamily;
  end;

  SetLength(qInfos, Length(unique));
  FillChar(qInfos[0], SizeOf(TVkDeviceQueueCreateInfo) * Length(unique), 0);

  for i := 0 to High(unique) do
  begin
    qInfos[i].sType := VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO;
    qInfos[i].queueFamilyIndex := unique[i];
    qInfos[i].queueCount := 1;
    qInfos[i].pQueuePriorities := @priorities;
  end;

  exts[0] := PAnsiChar(AnsiString(VK_KHR_SWAPCHAIN_EXTENSION_NAME));

  FillChar(dci, SizeOf(dci), 0);
  dci.sType := VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO;
  dci.queueCreateInfoCount := UInt32(Length(unique));
  dci.pQueueCreateInfos := @qInfos[0];
  dci.enabledExtensionCount := 1;
  dci.ppEnabledExtensionNames := @exts[0];

  gDevice := nil;
  VkCheck(vkCreateDevice(gPhysicalDevice, @dci, nil, gDevice), 'vkCreateDevice');
  LoadDeviceFunctions(gDevice);

  vkGetDeviceQueue(gDevice, gGraphicsQFamily, 0, gGraphicsQueue);
  vkGetDeviceQueue(gDevice, gPresentQFamily, 0, gPresentQueue);
end;

procedure VulkanInit;
begin
  DbgEnter('VulkanInit');

  LoadVulkanLibrary;
  Dbg('LoadVulkanLibrary: OK');
  CreateMainWindow;
  Dbg('CreateMainWindow: OK');
  CreateInstanceAndSurface;
  Dbg('CreateInstanceAndSurface: OK');
  PickPhysicalDeviceAndQueues;
  Dbg('PickPhysicalDeviceAndQueues: OK');
  CreateDeviceAndQueues;
  Dbg('CreateDeviceAndQueues: OK');

  CreateComputeResources;
  Dbg('CreateComputeResources: OK');

  CreateSwapchainBundle(gInstance, gDevice, gPhysicalDevice, gSurface, gHwnd, gGraphicsQFamily, gPresentQFamily,
	  'hello_vert.spv', 'hello_frag.spv', gBundle);
  Dbg('CreateSwapchainBundle: OK');

  CreateSyncObjects(gDevice, gSync);
  Dbg('CreateSyncObjects: OK');

  gStartTick := GetTickCount64;

  // WM_SIZE may arrive during startup; ignore the first one.
  gResized := False;

  DbgLeave('VulkanInit');
end;

procedure VulkanShutdown;
begin
  DbgEnter('VulkanShutdown');

  if gDevice <> nil then
  begin
    VkCheck(vkDeviceWaitIdle(gDevice), 'vkDeviceWaitIdle');
    DestroySyncObjects(gDevice, gSync);
    DestroySwapchainBundle(gDevice, gBundle);

    if gComputePipeline <> 0 then vkDestroyPipeline(gDevice, gComputePipeline, nil);
    if gPipelineLayout <> 0 then vkDestroyPipelineLayout(gDevice, gPipelineLayout, nil);
    if gDescriptorPool <> 0 then vkDestroyDescriptorPool(gDevice, gDescriptorPool, nil);
    if gDescriptorSetLayout <> 0 then vkDestroyDescriptorSetLayout(gDevice, gDescriptorSetLayout, nil);

    if gPositionBuffer <> 0 then vkDestroyBuffer(gDevice, gPositionBuffer, nil);
    if gPositionMemory <> 0 then vkFreeMemory(gDevice, gPositionMemory, nil);
    if gColorBuffer <> 0 then vkDestroyBuffer(gDevice, gColorBuffer, nil);
    if gColorMemory <> 0 then vkFreeMemory(gDevice, gColorMemory, nil);
    if gParamBuffer <> 0 then vkDestroyBuffer(gDevice, gParamBuffer, nil);
    if gParamMemory <> 0 then vkFreeMemory(gDevice, gParamMemory, nil);

    vkDestroyDevice(gDevice, nil);
    gDevice := nil;
  end;

  Dbg('Destroyed device and compute resources');

  if (gInstance <> nil) and (gSurface <> 0) then
  begin
    vkDestroySurfaceKHR(gInstance, gSurface, nil);
    gSurface := 0;
  end;

  if gInstance <> nil then
  begin
    vkDestroyInstance(gInstance, nil);
    gInstance := nil;
  end;

  if gVulkan <> 0 then
  begin
    FreeLibrary(gVulkan);
    gVulkan := 0;
  end;

  // shaderc is independent of Vulkan objects; unload last
  UnloadShadercLibrary;
  Dbg('UnloadShadercLibrary: OK');

  DbgLeave('VulkanShutdown');
end;

procedure MainLoop;
var
  // Use TMsg from the Windows unit (MSG can be fragile across modes/units in FPC)
  msg: TMsg;
begin
  while not gShouldQuit do
  begin
    while PeekMessage(msg, 0, 0, 0, PM_REMOVE) do
    begin
      if msg.message = WM_QUIT then
      begin
        gShouldQuit := True;
        Break;
      end;
      TranslateMessage(msg);
      DispatchMessage(msg);
    end;

    if gShouldQuit then Break;

    if gResized then
    begin
      gResized := False;
      RecreateSwapchain;
      Continue;
    end;

    DrawFrame;
    Sleep(1); // reduce CPU usage
  end;
end;

begin
  try
    try
      VulkanInit;
      MainLoop;
    except
      on E: Exception do
      begin
        Dbgf('Exception: %s', [E.Message]);
        raise;
      end;
    end;
  finally
    VulkanShutdown;
  end;
end.