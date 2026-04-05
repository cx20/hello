program hello;

{$mode delphi}
// Ensure Vulkan structs use C-compatible packing/alignment.
{$PACKRECORDS C}
{$H+}

uses
  SysUtils, Classes, Math;

(*
  Vulkan 1.4 Triangle (macOS, Free Pascal, GLFW + MoltenVK)

  - GLFW window and surface (Metal/MoltenVK backend)
  - All Vulkan and GLFW bindings via external declarations
  - VK_KHR_portability_enumeration + VK_KHR_portability_subset for MoltenVK
  - SPIR-V loaded from hello_vert.spv / hello_frag.spv

  Build:  sh build.sh
  Run:    sh run.sh
*)

// ============================================================
// Vulkan base types
// ============================================================
type
  VkFlags      = UInt32;
  VkBool32     = UInt32;
  VkDeviceSize = UInt64;
  VkResult     = Int32;

  // Dispatchable handles (pointers on 64-bit)
  VkInstance       = Pointer;
  VkPhysicalDevice = Pointer;
  VkDevice         = Pointer;
  VkQueue          = Pointer;
  VkCommandPool    = Pointer;
  VkCommandBuffer  = Pointer;

  PVkInstance       = ^VkInstance;
  PVkPhysicalDevice = ^VkPhysicalDevice;
  PVkDevice         = ^VkDevice;
  PVkQueue          = ^VkQueue;
  PVkCommandPool    = ^VkCommandPool;
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
  VkSemaphore      = UInt64;
  VkFence          = UInt64;

  PVkSurfaceKHR    = ^VkSurfaceKHR;
  PVkSwapchainKHR  = ^VkSwapchainKHR;
  PVkImage         = ^VkImage;
  PVkImageView     = ^VkImageView;
  PVkShaderModule  = ^VkShaderModule;
  PVkRenderPass    = ^VkRenderPass;
  PVkPipelineLayout = ^VkPipelineLayout;
  PVkPipeline      = ^VkPipeline;
  PVkFramebuffer   = ^VkFramebuffer;
  PVkSemaphore     = ^VkSemaphore;
  PVkFence         = ^VkFence;
  PVkBool32        = ^VkBool32;

  PVkChar = PAnsiChar;

  // --------------------------------------------------------
  // Vulkan structs
  // --------------------------------------------------------
  TVkExtent2D = record
    width:  UInt32;
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

  TVkApplicationInfo = record
    sType:              UInt32;
    pNext:              Pointer;
    pApplicationName:   PVkChar;
    applicationVersion: UInt32;
    pEngineName:        PVkChar;
    engineVersion:      UInt32;
    apiVersion:         UInt32;
  end;
  PVkApplicationInfo = ^TVkApplicationInfo;

  TVkInstanceCreateInfo = record
    sType:                   UInt32;
    pNext:                   Pointer;
    flags:                   UInt32;
    pApplicationInfo:        PVkApplicationInfo;
    enabledLayerCount:       UInt32;
    ppEnabledLayerNames:     PPAnsiChar;
    enabledExtensionCount:   UInt32;
    ppEnabledExtensionNames: PPAnsiChar;
  end;
  PVkInstanceCreateInfo = ^TVkInstanceCreateInfo;

  TVkExtensionProperties = record
    extensionName: array[0..255] of AnsiChar;
    specVersion:   UInt32;
  end;
  PVkExtensionProperties = ^TVkExtensionProperties;

  TVkSurfaceCapabilitiesKHR = record
    minImageCount:           UInt32;
    maxImageCount:           UInt32;
    currentExtent:           TVkExtent2D;
    minImageExtent:          TVkExtent2D;
    maxImageExtent:          TVkExtent2D;
    maxImageArrayLayers:     UInt32;
    supportedTransforms:     UInt32;
    currentTransform:        UInt32;
    supportedCompositeAlpha: UInt32;
    supportedUsageFlags:     UInt32;
  end;
  PVkSurfaceCapabilitiesKHR = ^TVkSurfaceCapabilitiesKHR;

  TVkSurfaceFormatKHR = record
    format:     UInt32;
    colorSpace: UInt32;
  end;
  PVkSurfaceFormatKHR = ^TVkSurfaceFormatKHR;

  TVkDeviceQueueCreateInfo = record
    sType:            UInt32;
    pNext:            Pointer;
    flags:            UInt32;
    queueFamilyIndex: UInt32;
    queueCount:       UInt32;
    pQueuePriorities: PSingle;
  end;
  PVkDeviceQueueCreateInfo = ^TVkDeviceQueueCreateInfo;

  TVkDeviceCreateInfo = record
    sType:                   UInt32;
    pNext:                   Pointer;
    flags:                   UInt32;
    queueCreateInfoCount:    UInt32;
    pQueueCreateInfos:       PVkDeviceQueueCreateInfo;
    enabledLayerCount:       UInt32;
    ppEnabledLayerNames:     PPAnsiChar;
    enabledExtensionCount:   UInt32;
    ppEnabledExtensionNames: PPAnsiChar;
    pEnabledFeatures:        Pointer;
  end;
  PVkDeviceCreateInfo = ^TVkDeviceCreateInfo;

  TVkExtent3D = record
    width:  UInt32;
    height: UInt32;
    depth:  UInt32;
  end;

  TVkQueueFamilyProperties = record
    queueFlags:                  UInt32;
    queueCount:                  UInt32;
    timestampValidBits:          UInt32;
    minImageTransferGranularity: TVkExtent3D;
  end;
  PVkQueueFamilyProperties = ^TVkQueueFamilyProperties;

  TVkSwapchainCreateInfoKHR = record
    sType:                 UInt32;
    pNext:                 Pointer;
    flags:                 UInt32;
    surface:               VkSurfaceKHR;
    minImageCount:         UInt32;
    imageFormat:           UInt32;
    imageColorSpace:       UInt32;
    imageExtent:           TVkExtent2D;
    imageArrayLayers:      UInt32;
    imageUsage:            UInt32;
    imageSharingMode:      UInt32;
    queueFamilyIndexCount: UInt32;
    pQueueFamilyIndices:   PUInt32;
    preTransform:          UInt32;
    compositeAlpha:        UInt32;
    presentMode:           UInt32;
    clipped:               VkBool32;
    oldSwapchain:          VkSwapchainKHR;
  end;
  PVkSwapchainCreateInfoKHR = ^TVkSwapchainCreateInfoKHR;

  TVkComponentMapping = record
    r, g, b, a: UInt32;
  end;

  TVkImageSubresourceRange = record
    aspectMask:     UInt32;
    baseMipLevel:   UInt32;
    levelCount:     UInt32;
    baseArrayLayer: UInt32;
    layerCount:     UInt32;
  end;

  TVkImageViewCreateInfo = record
    sType:            UInt32;
    pNext:            Pointer;
    flags:            UInt32;
    image:            VkImage;
    viewType:         UInt32;
    format:           UInt32;
    components:       TVkComponentMapping;
    subresourceRange: TVkImageSubresourceRange;
  end;
  PVkImageViewCreateInfo = ^TVkImageViewCreateInfo;

  TVkAttachmentDescription = record
    flags:         UInt32;
    format:        UInt32;
    samples:       UInt32;
    loadOp:        UInt32;
    storeOp:       UInt32;
    stencilLoadOp: UInt32;
    stencilStoreOp: UInt32;
    initialLayout: UInt32;
    finalLayout:   UInt32;
  end;

  TVkAttachmentReference = record
    attachment: UInt32;
    layout:     UInt32;
  end;
  PVkAttachmentReference = ^TVkAttachmentReference;

  TVkSubpassDescription = record
    flags:                   UInt32;
    pipelineBindPoint:       UInt32;
    inputAttachmentCount:    UInt32;
    pInputAttachments:       Pointer;
    colorAttachmentCount:    UInt32;
    pColorAttachments:       PVkAttachmentReference;
    pResolveAttachments:     Pointer;
    pDepthStencilAttachment: Pointer;
    preserveAttachmentCount: UInt32;
    pPreserveAttachments:    Pointer;
  end;

  TVkRenderPassCreateInfo = record
    sType:           UInt32;
    pNext:           Pointer;
    flags:           UInt32;
    attachmentCount: UInt32;
    pAttachments:    ^TVkAttachmentDescription;
    subpassCount:    UInt32;
    pSubpasses:      ^TVkSubpassDescription;
    dependencyCount: UInt32;
    pDependencies:   Pointer;
  end;
  PVkRenderPassCreateInfo = ^TVkRenderPassCreateInfo;

  TVkShaderModuleCreateInfo = record
    sType:    UInt32;
    pNext:    Pointer;
    flags:    UInt32;
    codeSize: NativeUInt;
    pCode:    PUInt32;
  end;
  PVkShaderModuleCreateInfo = ^TVkShaderModuleCreateInfo;

  TVkPipelineShaderStageCreateInfo = record
    sType:               UInt32;
    pNext:               Pointer;
    flags:               UInt32;
    stage:               UInt32;
    module_:             VkShaderModule;
    pName:               PVkChar;
    pSpecializationInfo: Pointer;
  end;
  PVkPipelineShaderStageCreateInfo = ^TVkPipelineShaderStageCreateInfo;

  TVkPipelineVertexInputStateCreateInfo = record
    sType:                           UInt32;
    pNext:                           Pointer;
    flags:                           UInt32;
    vertexBindingDescriptionCount:   UInt32;
    pVertexBindingDescriptions:      Pointer;
    vertexAttributeDescriptionCount: UInt32;
    pVertexAttributeDescriptions:    Pointer;
  end;

  TVkPipelineInputAssemblyStateCreateInfo = record
    sType:                  UInt32;
    pNext:                  Pointer;
    flags:                  UInt32;
    topology:               UInt32;
    primitiveRestartEnable: VkBool32;
  end;

  TVkViewport = record
    x, y, width, height, minDepth, maxDepth: Single;
  end;
  PVkViewport = ^TVkViewport;

  TVkPipelineViewportStateCreateInfo = record
    sType:         UInt32;
    pNext:         Pointer;
    flags:         UInt32;
    viewportCount: UInt32;
    pViewports:    PVkViewport;
    scissorCount:  UInt32;
    pScissors:     ^TVkRect2D;
  end;

  TVkPipelineRasterizationStateCreateInfo = record
    sType:                   UInt32;
    pNext:                   Pointer;
    flags:                   UInt32;
    depthClampEnable:        VkBool32;
    rasterizerDiscardEnable: VkBool32;
    polygonMode:             UInt32;
    cullMode:                UInt32;
    frontFace:               UInt32;
    depthBiasEnable:         VkBool32;
    depthBiasConstantFactor: Single;
    depthBiasClamp:          Single;
    depthBiasSlopeFactor:    Single;
    lineWidth:               Single;
  end;

  TVkPipelineMultisampleStateCreateInfo = record
    sType:                 UInt32;
    pNext:                 Pointer;
    flags:                 UInt32;
    rasterizationSamples:  UInt32;
    sampleShadingEnable:   VkBool32;
    minSampleShading:      Single;
    pSampleMask:           Pointer;
    alphaToCoverageEnable: VkBool32;
    alphaToOneEnable:      VkBool32;
  end;

  TVkPipelineColorBlendAttachmentState = record
    blendEnable:         VkBool32;
    srcColorBlendFactor: UInt32;
    dstColorBlendFactor: UInt32;
    colorBlendOp:        UInt32;
    srcAlphaBlendFactor: UInt32;
    dstAlphaBlendFactor: UInt32;
    alphaBlendOp:        UInt32;
    colorWriteMask:      UInt32;
  end;
  PVkPipelineColorBlendAttachmentState = ^TVkPipelineColorBlendAttachmentState;

  TVkPipelineColorBlendStateCreateInfo = record
    sType:           UInt32;
    pNext:           Pointer;
    flags:           UInt32;
    logicOpEnable:   VkBool32;
    logicOp:         UInt32;
    attachmentCount: UInt32;
    pAttachments:    PVkPipelineColorBlendAttachmentState;
    blendConstants:  array[0..3] of Single;
  end;

  TVkPipelineDynamicStateCreateInfo = record
    sType:             UInt32;
    pNext:             Pointer;
    flags:             UInt32;
    dynamicStateCount: UInt32;
    pDynamicStates:    PUInt32;
  end;

  TVkPipelineLayoutCreateInfo = record
    sType:                  UInt32;
    pNext:                  Pointer;
    flags:                  UInt32;
    setLayoutCount:         UInt32;
    pSetLayouts:            Pointer;
    pushConstantRangeCount: UInt32;
    pPushConstantRanges:    Pointer;
  end;
  PVkPipelineLayoutCreateInfo = ^TVkPipelineLayoutCreateInfo;

  TVkGraphicsPipelineCreateInfo = record
    sType:               UInt32;
    pNext:               Pointer;
    flags:               UInt32;
    stageCount:          UInt32;
    pStages:             PVkPipelineShaderStageCreateInfo;
    pVertexInputState:   ^TVkPipelineVertexInputStateCreateInfo;
    pInputAssemblyState: ^TVkPipelineInputAssemblyStateCreateInfo;
    pTessellationState:  Pointer;
    pViewportState:      ^TVkPipelineViewportStateCreateInfo;
    pRasterizationState: ^TVkPipelineRasterizationStateCreateInfo;
    pMultisampleState:   ^TVkPipelineMultisampleStateCreateInfo;
    pDepthStencilState:  Pointer;
    pColorBlendState:    ^TVkPipelineColorBlendStateCreateInfo;
    pDynamicState:       ^TVkPipelineDynamicStateCreateInfo;
    layout:              VkPipelineLayout;
    renderPass:          VkRenderPass;
    subpass:             UInt32;
    basePipelineHandle:  VkPipeline;
    basePipelineIndex:   Int32;
  end;
  PVkGraphicsPipelineCreateInfo = ^TVkGraphicsPipelineCreateInfo;

  TVkFramebufferCreateInfo = record
    sType:           UInt32;
    pNext:           Pointer;
    flags:           UInt32;
    renderPass:      VkRenderPass;
    attachmentCount: UInt32;
    pAttachments:    PVkImageView;
    width:           UInt32;
    height:          UInt32;
    layers:          UInt32;
  end;
  PVkFramebufferCreateInfo = ^TVkFramebufferCreateInfo;

  TVkCommandPoolCreateInfo = record
    sType:            UInt32;
    pNext:            Pointer;
    flags:            UInt32;
    queueFamilyIndex: UInt32;
  end;
  PVkCommandPoolCreateInfo = ^TVkCommandPoolCreateInfo;

  TVkCommandBufferAllocateInfo = record
    sType:              UInt32;
    pNext:              Pointer;
    commandPool:        VkCommandPool;
    level_:             UInt32;
    commandBufferCount: UInt32;
  end;
  PVkCommandBufferAllocateInfo = ^TVkCommandBufferAllocateInfo;

  TVkCommandBufferBeginInfo = record
    sType:            UInt32;
    pNext:            Pointer;
    flags:            UInt32;
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
    sType:           UInt32;
    pNext:           Pointer;
    renderPass:      VkRenderPass;
    framebuffer:     VkFramebuffer;
    renderArea:      TVkRect2D;
    clearValueCount: UInt32;
    pClearValues:    PVkClearValue;
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
    sType:                UInt32;
    pNext:                Pointer;
    waitSemaphoreCount:   UInt32;
    pWaitSemaphores:      PVkSemaphore;
    pWaitDstStageMask:    PUInt32;
    commandBufferCount:   UInt32;
    pCommandBuffers:      ^VkCommandBuffer;
    signalSemaphoreCount: UInt32;
    pSignalSemaphores:    PVkSemaphore;
  end;
  PVkSubmitInfo = ^TVkSubmitInfo;

  TVkPresentInfoKHR = record
    sType:              UInt32;
    pNext:              Pointer;
    waitSemaphoreCount: UInt32;
    pWaitSemaphores:    PVkSemaphore;
    swapchainCount:     UInt32;
    pSwapchains:        PVkSwapchainKHR;
    pImageIndices:      PUInt32;
    pResults:           Pointer;
  end;
  PVkPresentInfoKHR = ^TVkPresentInfoKHR;

  // GLFW callback type
  TGLFWFramebufferSizeFun = procedure(window: Pointer; width, height: Integer); cdecl;

  // App state
  TSwapchainBundle = record
    swapchain:      VkSwapchainKHR;
    format:         UInt32;
    extent:         TVkExtent2D;
    imageCount:     UInt32;
    images:         array of VkImage;
    views:          array of VkImageView;
    renderPass:     VkRenderPass;
    pipelineLayout: VkPipelineLayout;
    pipeline:       VkPipeline;
    framebuffers:   array of VkFramebuffer;
    commandPool:    VkCommandPool;
    commandBuffers: array of VkCommandBuffer;
  end;

  TSyncObjects = record
    imageAvailable: array[0..1] of VkSemaphore;
    renderFinished: array[0..1] of VkSemaphore;
    inFlight:       array[0..1] of VkFence;
  end;

  // For indexing into PPAnsiChar as an array
  TPCharArray = array[0..255] of PAnsiChar;
  PPCharArray = ^TPCharArray;

// ============================================================
// Constants
// ============================================================
const
  VK_SUCCESS               = 0;
  VK_SUBOPTIMAL_KHR        = 1000001003;
  VK_ERROR_OUT_OF_DATE_KHR = -1000001004;

  VK_API_VERSION_1_4 = (1 shl 22) or (4 shl 12) or 0;

  // MoltenVK portability
  VK_INSTANCE_CREATE_ENUMERATE_PORTABILITY_BIT_KHR = $00000001;

  // Structure types
  VK_STRUCTURE_TYPE_APPLICATION_INFO                          = 0;
  VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO                      = 1;
  VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO                  = 2;
  VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO                        = 3;
  VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR                 = 1000001000;
  VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO                    = 15;
  VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO                 = 16;
  VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO         = 18;
  VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO   = 19;
  VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO = 20;
  VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO       = 22;
  VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO  = 23;
  VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO    = 24;
  VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO    = 26;
  VK_STRUCTURE_TYPE_PIPELINE_DYNAMIC_STATE_CREATE_INFO        = 27;
  VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO               = 30;
  VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO             = 28;
  VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO                   = 38;
  VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO                   = 37;
  VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO                  = 39;
  VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO              = 40;
  VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO                 = 42;
  VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO                    = 43;
  VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO                     = 9;
  VK_STRUCTURE_TYPE_FENCE_CREATE_INFO                         = 8;
  VK_STRUCTURE_TYPE_SUBMIT_INFO                               = 4;
  VK_STRUCTURE_TYPE_PRESENT_INFO_KHR                          = 1000001002;

  // Queue flags
  VK_QUEUE_GRAPHICS_BIT = $00000001;

  // Command pool flags
  VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT = $00000002;

  // Pipeline
  VK_PIPELINE_BIND_POINT_GRAPHICS        = 0;
  VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST    = 3;
  VK_POLYGON_MODE_FILL                   = 0;
  VK_CULL_MODE_NONE                      = 0;
  VK_FRONT_FACE_COUNTER_CLOCKWISE        = 1;
  VK_SAMPLE_COUNT_1_BIT                  = 1;
  VK_COLOR_COMPONENT_R_BIT               = $1;
  VK_COLOR_COMPONENT_G_BIT               = $2;
  VK_COLOR_COMPONENT_B_BIT               = $4;
  VK_COLOR_COMPONENT_A_BIT               = $8;
  VK_DYNAMIC_STATE_VIEWPORT              = 0;
  VK_DYNAMIC_STATE_SCISSOR               = 1;

  // Image / layout
  VK_IMAGE_ASPECT_COLOR_BIT              = $1;
  VK_IMAGE_VIEW_TYPE_2D                  = 1;
  VK_IMAGE_LAYOUT_UNDEFINED              = 0;
  VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL = 2;
  VK_IMAGE_LAYOUT_PRESENT_SRC_KHR        = 1000001002;

  // Attachment ops
  VK_ATTACHMENT_LOAD_OP_CLEAR            = 1;
  VK_ATTACHMENT_LOAD_OP_DONT_CARE        = 2;
  VK_ATTACHMENT_STORE_OP_STORE           = 0;
  VK_ATTACHMENT_STORE_OP_DONT_CARE       = 1;

  // Sharing mode
  VK_SHARING_MODE_EXCLUSIVE              = 0;
  VK_SHARING_MODE_CONCURRENT             = 1;

  // Present mode
  VK_PRESENT_MODE_FIFO_KHR               = 2;

  // Composite alpha / transform
  VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR      = $00000001;
  VK_SURFACE_TRANSFORM_IDENTITY_BIT_KHR  = $00000001;

  // Pipeline stage
  VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT = $00000400;

  // Fence
  VK_FENCE_CREATE_SIGNALED_BIT           = $00000001;

  // Command buffer
  VK_COMMAND_BUFFER_LEVEL_PRIMARY        = 0;

  // Shader stages
  VK_SHADER_STAGE_VERTEX_BIT             = $00000001;
  VK_SHADER_STAGE_FRAGMENT_BIT           = $00000010;

  // Image usage
  VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT    = $00000010;

  // Common formats
  VK_FORMAT_B8G8R8A8_UNORM               = 44;
  VK_FORMAT_B8G8R8A8_SRGB                = 50;

  // GLFW hints
  GLFW_CLIENT_API                        = $00022001;
  GLFW_NO_API                            = 0;

  // Library names
  libvulkan = 'vulkan';
  libglfw   = 'glfw';

  // Static extension name strings (stable PAnsiChar pointers)
  cExtSwapchain  : PAnsiChar = 'VK_KHR_swapchain';
  cExtPortEnum   : PAnsiChar = 'VK_KHR_portability_enumeration';
  cExtPortSubset : PAnsiChar = 'VK_KHR_portability_subset';

// ============================================================
// GLFW external declarations
// ============================================================
function  glfwInit: Integer; cdecl; external libglfw;
procedure glfwTerminate; cdecl; external libglfw;
procedure glfwWindowHint(hint, value: Integer); cdecl; external libglfw;
function  glfwCreateWindow(width, height: Integer; title: PAnsiChar; monitor, share: Pointer): Pointer; cdecl; external libglfw;
procedure glfwDestroyWindow(window: Pointer); cdecl; external libglfw;
function  glfwWindowShouldClose(window: Pointer): Integer; cdecl; external libglfw;
procedure glfwPollEvents; cdecl; external libglfw;
procedure glfwWaitEvents; cdecl; external libglfw;
procedure glfwGetFramebufferSize(window: Pointer; width, height: PInteger); cdecl; external libglfw;
function  glfwGetRequiredInstanceExtensions(count: PCardinal): PPAnsiChar; cdecl; external libglfw;
function  glfwCreateWindowSurface(instance: VkInstance; window: Pointer; allocator: Pointer; surface: PVkSurfaceKHR): VkResult; cdecl; external libglfw;
procedure glfwSetFramebufferSizeCallback(window: Pointer; cbfun: TGLFWFramebufferSizeFun); cdecl; external libglfw;

// ============================================================
// Vulkan external declarations
// ============================================================

// Core instance functions
function  vkCreateInstance(pCreateInfo: PVkInstanceCreateInfo; pAllocator: Pointer; pInstance: PVkInstance): VkResult; cdecl; external libvulkan;
procedure vkDestroyInstance(instance: VkInstance; pAllocator: Pointer); cdecl; external libvulkan;
function  vkEnumeratePhysicalDevices(instance: VkInstance; pPhysicalDeviceCount: PUInt32; pPhysicalDevices: PVkPhysicalDevice): VkResult; cdecl; external libvulkan;
function  vkEnumerateInstanceExtensionProperties(pLayerName: PAnsiChar; pPropertyCount: PUInt32; pProperties: PVkExtensionProperties): VkResult; cdecl; external libvulkan;
function  vkEnumerateDeviceExtensionProperties(physicalDevice: VkPhysicalDevice; pLayerName: PAnsiChar; pPropertyCount: PUInt32; pProperties: PVkExtensionProperties): VkResult; cdecl; external libvulkan;

// Physical device
procedure vkGetPhysicalDeviceQueueFamilyProperties(physicalDevice: VkPhysicalDevice; pQueueFamilyPropertyCount: PUInt32; pQueueFamilyProperties: PVkQueueFamilyProperties); cdecl; external libvulkan;
function  vkGetPhysicalDeviceSurfaceSupportKHR(physicalDevice: VkPhysicalDevice; queueFamilyIndex: UInt32; surface: VkSurfaceKHR; pSupported: PVkBool32): VkResult; cdecl; external libvulkan;
function  vkGetPhysicalDeviceSurfaceCapabilitiesKHR(physicalDevice: VkPhysicalDevice; surface: VkSurfaceKHR; pSurfaceCapabilities: PVkSurfaceCapabilitiesKHR): VkResult; cdecl; external libvulkan;
function  vkGetPhysicalDeviceSurfaceFormatsKHR(physicalDevice: VkPhysicalDevice; surface: VkSurfaceKHR; pSurfaceFormatCount: PUInt32; pSurfaceFormats: PVkSurfaceFormatKHR): VkResult; cdecl; external libvulkan;
function  vkGetPhysicalDeviceSurfacePresentModesKHR(physicalDevice: VkPhysicalDevice; surface: VkSurfaceKHR; pPresentModeCount: PUInt32; pPresentModes: PUInt32): VkResult; cdecl; external libvulkan;

// Logical device
function  vkCreateDevice(physicalDevice: VkPhysicalDevice; pCreateInfo: PVkDeviceCreateInfo; pAllocator: Pointer; pDevice: PVkDevice): VkResult; cdecl; external libvulkan;
procedure vkDestroyDevice(device: VkDevice; pAllocator: Pointer); cdecl; external libvulkan;
procedure vkGetDeviceQueue(device: VkDevice; queueFamilyIndex, queueIndex: UInt32; pQueue: PVkQueue); cdecl; external libvulkan;
function  vkDeviceWaitIdle(device: VkDevice): VkResult; cdecl; external libvulkan;

// Surface
procedure vkDestroySurfaceKHR(instance: VkInstance; surface: VkSurfaceKHR; pAllocator: Pointer); cdecl; external libvulkan;

// Swapchain
function  vkCreateSwapchainKHR(device: VkDevice; pCreateInfo: PVkSwapchainCreateInfoKHR; pAllocator: Pointer; pSwapchain: PVkSwapchainKHR): VkResult; cdecl; external libvulkan;
procedure vkDestroySwapchainKHR(device: VkDevice; swapchain: VkSwapchainKHR; pAllocator: Pointer); cdecl; external libvulkan;
function  vkGetSwapchainImagesKHR(device: VkDevice; swapchain: VkSwapchainKHR; pSwapchainImageCount: PUInt32; pSwapchainImages: PVkImage): VkResult; cdecl; external libvulkan;
function  vkAcquireNextImageKHR(device: VkDevice; swapchain: VkSwapchainKHR; timeout: UInt64; semaphore: VkSemaphore; fence: VkFence; pImageIndex: PUInt32): VkResult; cdecl; external libvulkan;

// Image views
function  vkCreateImageView(device: VkDevice; pCreateInfo: PVkImageViewCreateInfo; pAllocator: Pointer; pView: PVkImageView): VkResult; cdecl; external libvulkan;
procedure vkDestroyImageView(device: VkDevice; imageView: VkImageView; pAllocator: Pointer); cdecl; external libvulkan;

// Render pass
function  vkCreateRenderPass(device: VkDevice; pCreateInfo: PVkRenderPassCreateInfo; pAllocator: Pointer; pRenderPass: PVkRenderPass): VkResult; cdecl; external libvulkan;
procedure vkDestroyRenderPass(device: VkDevice; renderPass: VkRenderPass; pAllocator: Pointer); cdecl; external libvulkan;

// Shader modules
function  vkCreateShaderModule(device: VkDevice; pCreateInfo: PVkShaderModuleCreateInfo; pAllocator: Pointer; pShaderModule: PVkShaderModule): VkResult; cdecl; external libvulkan;
procedure vkDestroyShaderModule(device: VkDevice; shaderModule: VkShaderModule; pAllocator: Pointer); cdecl; external libvulkan;

// Pipeline
function  vkCreatePipelineLayout(device: VkDevice; pCreateInfo: PVkPipelineLayoutCreateInfo; pAllocator: Pointer; pPipelineLayout: PVkPipelineLayout): VkResult; cdecl; external libvulkan;
procedure vkDestroyPipelineLayout(device: VkDevice; pipelineLayout: VkPipelineLayout; pAllocator: Pointer); cdecl; external libvulkan;
function  vkCreateGraphicsPipelines(device: VkDevice; pipelineCache: UInt64; createInfoCount: UInt32; pCreateInfos: PVkGraphicsPipelineCreateInfo; pAllocator: Pointer; pPipelines: PVkPipeline): VkResult; cdecl; external libvulkan;
procedure vkDestroyPipeline(device: VkDevice; pipeline: VkPipeline; pAllocator: Pointer); cdecl; external libvulkan;

// Framebuffers
function  vkCreateFramebuffer(device: VkDevice; pCreateInfo: PVkFramebufferCreateInfo; pAllocator: Pointer; pFramebuffer: PVkFramebuffer): VkResult; cdecl; external libvulkan;
procedure vkDestroyFramebuffer(device: VkDevice; framebuffer: VkFramebuffer; pAllocator: Pointer); cdecl; external libvulkan;

// Command pool + buffers
function  vkCreateCommandPool(device: VkDevice; pCreateInfo: PVkCommandPoolCreateInfo; pAllocator: Pointer; pCommandPool: PVkCommandPool): VkResult; cdecl; external libvulkan;
procedure vkDestroyCommandPool(device: VkDevice; commandPool: VkCommandPool; pAllocator: Pointer); cdecl; external libvulkan;
function  vkAllocateCommandBuffers(device: VkDevice; pAllocateInfo: PVkCommandBufferAllocateInfo; pCommandBuffers: PVkCommandBuffer): VkResult; cdecl; external libvulkan;
function  vkBeginCommandBuffer(commandBuffer: VkCommandBuffer; pBeginInfo: PVkCommandBufferBeginInfo): VkResult; cdecl; external libvulkan;
function  vkEndCommandBuffer(commandBuffer: VkCommandBuffer): VkResult; cdecl; external libvulkan;

// Draw commands
procedure vkCmdBeginRenderPass(commandBuffer: VkCommandBuffer; pRenderPassBegin: PVkRenderPassBeginInfo; contents: UInt32); cdecl; external libvulkan;
procedure vkCmdEndRenderPass(commandBuffer: VkCommandBuffer); cdecl; external libvulkan;
procedure vkCmdBindPipeline(commandBuffer: VkCommandBuffer; pipelineBindPoint: UInt32; pipeline: VkPipeline); cdecl; external libvulkan;
procedure vkCmdDraw(commandBuffer: VkCommandBuffer; vertexCount, instanceCount, firstVertex, firstInstance: UInt32); cdecl; external libvulkan;
procedure vkCmdSetViewport(commandBuffer: VkCommandBuffer; firstViewport, viewportCount: UInt32; pViewports: PVkViewport); cdecl; external libvulkan;
procedure vkCmdSetScissor(commandBuffer: VkCommandBuffer; firstScissor, scissorCount: UInt32; pScissors: PVkRect2D); cdecl; external libvulkan;

// Sync objects
function  vkCreateSemaphore(device: VkDevice; pCreateInfo: PVkSemaphoreCreateInfo; pAllocator: Pointer; pSemaphore: PVkSemaphore): VkResult; cdecl; external libvulkan;
procedure vkDestroySemaphore(device: VkDevice; semaphore: VkSemaphore; pAllocator: Pointer); cdecl; external libvulkan;
function  vkCreateFence(device: VkDevice; pCreateInfo: PVkFenceCreateInfo; pAllocator: Pointer; pFence: PVkFence): VkResult; cdecl; external libvulkan;
procedure vkDestroyFence(device: VkDevice; fence: VkFence; pAllocator: Pointer); cdecl; external libvulkan;
function  vkWaitForFences(device: VkDevice; fenceCount: UInt32; pFences: PVkFence; waitAll: VkBool32; timeout: UInt64): VkResult; cdecl; external libvulkan;
function  vkResetFences(device: VkDevice; fenceCount: UInt32; pFences: PVkFence): VkResult; cdecl; external libvulkan;

// Queue submission and present
function  vkQueueSubmit(queue: VkQueue; submitCount: UInt32; pSubmits: PVkSubmitInfo; fence: VkFence): VkResult; cdecl; external libvulkan;
function  vkQueuePresentKHR(queue: VkQueue; pPresentInfo: PVkPresentInfoKHR): VkResult; cdecl; external libvulkan;

// ============================================================
// Global state
// ============================================================
var
  gWindow:          Pointer   = nil;
  gInstance:        VkInstance = nil;
  gSurface:         VkSurfaceKHR = 0;
  gPhysicalDevice:  VkPhysicalDevice = nil;
  gDevice:          VkDevice = nil;
  gGraphicsQueue:   VkQueue = nil;
  gPresentQueue:    VkQueue = nil;
  gGraphicsQFamily: UInt32 = $FFFFFFFF;
  gPresentQFamily:  UInt32 = $FFFFFFFF;

  gBundle:          TSwapchainBundle;
  gSync:            TSyncObjects;
  gFrame:           UInt32 = 0;
  gResized:         Boolean = False;

// ============================================================
// Helpers
// ============================================================
procedure VkCheck(res: VkResult; const what: string);
begin
  if res <> VK_SUCCESS then
    raise Exception.CreateFmt('%s failed: VkResult=%d', [what, res]);
end;

procedure FramebufferResizeCallback(window: Pointer; width, height: Integer); cdecl;
begin
  gResized := True;
end;

function IsInstanceExtensionAvailable(const name: AnsiString): Boolean;
var
  count: UInt32;
  props: array of TVkExtensionProperties;
  i: Integer;
begin
  Result := False;
  count := 0;
  vkEnumerateInstanceExtensionProperties(nil, @count, nil);
  if count = 0 then Exit;
  SetLength(props, count);
  vkEnumerateInstanceExtensionProperties(nil, @count, @props[0]);
  for i := 0 to Integer(count) - 1 do
    if AnsiString(PAnsiChar(@props[i].extensionName)) = name then
    begin
      Result := True;
      Exit;
    end;
end;

function IsDeviceExtensionAvailable(pd: VkPhysicalDevice; const name: AnsiString): Boolean;
var
  count: UInt32;
  props: array of TVkExtensionProperties;
  i: Integer;
begin
  Result := False;
  count := 0;
  vkEnumerateDeviceExtensionProperties(pd, nil, @count, nil);
  if count = 0 then Exit;
  SetLength(props, count);
  vkEnumerateDeviceExtensionProperties(pd, nil, @count, @props[0]);
  for i := 0 to Integer(count) - 1 do
    if AnsiString(PAnsiChar(@props[i].extensionName)) = name then
    begin
      Result := True;
      Exit;
    end;
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

function CreateShaderModuleFromFile(device: VkDevice; const fileName: string): VkShaderModule;
var
  data: TBytes;
  ci:   TVkShaderModuleCreateInfo;
begin
  if not ReadFileBytes(fileName, data) then
    raise Exception.CreateFmt('Shader file not found: %s', [fileName]);
  if (Length(data) = 0) or ((Length(data) mod 4) <> 0) then
    raise Exception.CreateFmt('SPIR-V size invalid: %s (%d bytes)', [fileName, Length(data)]);

  FillChar(ci, SizeOf(ci), 0);
  ci.sType    := VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO;
  ci.codeSize := Length(data);
  ci.pCode    := PUInt32(@data[0]);

  Result := 0;
  VkCheck(vkCreateShaderModule(device, @ci, nil, @Result), 'vkCreateShaderModule');
end;

function ChooseSurfaceFormat(const fmts: array of TVkSurfaceFormatKHR): TVkSurfaceFormatKHR;
var
  i: Integer;
begin
  Result := fmts[0];
  // Prefer BGRA8 SRGB, fall back to BGRA8 UNORM, otherwise first available
  for i := 0 to High(fmts) do
    if fmts[i].format = VK_FORMAT_B8G8R8A8_SRGB then
      Exit(fmts[i]);
  for i := 0 to High(fmts) do
    if fmts[i].format = VK_FORMAT_B8G8R8A8_UNORM then
      Exit(fmts[i]);
end;

function ChooseExtent(const caps: TVkSurfaceCapabilitiesKHR): TVkExtent2D;
var
  w, h: Integer;
begin
  if caps.currentExtent.width <> $FFFFFFFF then
    Exit(caps.currentExtent);

  glfwGetFramebufferSize(gWindow, @w, @h);

  Result.width  := UInt32(w);
  Result.height := UInt32(h);

  if Result.width  < caps.minImageExtent.width  then Result.width  := caps.minImageExtent.width;
  if Result.height < caps.minImageExtent.height then Result.height := caps.minImageExtent.height;
  if Result.width  > caps.maxImageExtent.width  then Result.width  := caps.maxImageExtent.width;
  if Result.height > caps.maxImageExtent.height then Result.height := caps.maxImageExtent.height;
end;

// ============================================================
// Window
// ============================================================
procedure CreateWindow;
begin
  if glfwInit = 0 then
    raise Exception.Create('glfwInit failed');
  glfwWindowHint(GLFW_CLIENT_API, GLFW_NO_API);
  gWindow := glfwCreateWindow(800, 600, 'Hello, World!', nil, nil);
  if gWindow = nil then
    raise Exception.Create('glfwCreateWindow failed');
  glfwSetFramebufferSizeCallback(gWindow, @FramebufferResizeCallback);
end;

// ============================================================
// Instance + Surface
// ============================================================
procedure CreateInstance;
var
  app:           TVkApplicationInfo;
  ici:           TVkInstanceCreateInfo;
  glfwExtCount:  Cardinal;
  glfwExtsPtr:   PPCharArray;
  hasPortEnum:   Boolean;
  exts:          array of PAnsiChar;
  extCount:      Integer;
  i:             Integer;
begin
  FillChar(app, SizeOf(app), 0);
  app.sType              := VK_STRUCTURE_TYPE_APPLICATION_INFO;
  app.pApplicationName   := 'Hello, World!';
  app.applicationVersion := 1;
  app.pEngineName        := 'NoEngine';
  app.engineVersion      := 1;
  app.apiVersion         := VK_API_VERSION_1_4;

  glfwExtCount := 0;
  glfwExtsPtr  := PPCharArray(glfwGetRequiredInstanceExtensions(@glfwExtCount));
  if (glfwExtCount = 0) or (glfwExtsPtr = nil) then
    raise Exception.Create('GLFW: no Vulkan instance extensions returned');

  hasPortEnum := IsInstanceExtensionAvailable('VK_KHR_portability_enumeration');

  extCount := Integer(glfwExtCount);
  if hasPortEnum then Inc(extCount);
  SetLength(exts, extCount);

  for i := 0 to Integer(glfwExtCount) - 1 do
    exts[i] := glfwExtsPtr^[i];
  if hasPortEnum then
    exts[Integer(glfwExtCount)] := cExtPortEnum;

  FillChar(ici, SizeOf(ici), 0);
  ici.sType                   := VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO;
  ici.pApplicationInfo        := @app;
  ici.enabledExtensionCount   := UInt32(extCount);
  ici.ppEnabledExtensionNames := PPAnsiChar(@exts[0]);
  if hasPortEnum then
    ici.flags := VK_INSTANCE_CREATE_ENUMERATE_PORTABILITY_BIT_KHR;

  gInstance := nil;
  VkCheck(vkCreateInstance(@ici, nil, @gInstance), 'vkCreateInstance');
end;

procedure CreateSurface;
begin
  gSurface := 0;
  VkCheck(glfwCreateWindowSurface(gInstance, gWindow, nil, @gSurface), 'glfwCreateWindowSurface');
end;

// ============================================================
// Physical device + queues
// ============================================================
procedure PickPhysicalDeviceAndQueues;
var
  count:     UInt32;
  devs:      array of VkPhysicalDevice;
  i, qi:     Integer;
  qCount:    UInt32;
  props:     array of TVkQueueFamilyProperties;
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
    gPresentQFamily  := $FFFFFFFF;

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
      VkCheck(vkGetPhysicalDeviceSurfaceSupportKHR(devs[i], UInt32(qi), gSurface, @supported),
              'vkGetPhysicalDeviceSurfaceSupportKHR');
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

// ============================================================
// Logical device
// ============================================================
procedure CreateDeviceAndQueues;
var
  priority:   Single;
  unique:     array of UInt32;
  qInfos:     array of TVkDeviceQueueCreateInfo;
  dci:        TVkDeviceCreateInfo;
  exts:       array of PAnsiChar;
  extCount:   Integer;
  i:          Integer;
begin
  priority := 1.0;

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
    qInfos[i].sType            := VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO;
    qInfos[i].queueFamilyIndex := unique[i];
    qInfos[i].queueCount       := 1;
    qInfos[i].pQueuePriorities := @priority;
  end;

  // Required: VK_KHR_swapchain; optional: VK_KHR_portability_subset (MoltenVK)
  extCount := 1;
  if IsDeviceExtensionAvailable(gPhysicalDevice, 'VK_KHR_portability_subset') then
    Inc(extCount);
  SetLength(exts, extCount);
  exts[0] := cExtSwapchain;
  if extCount > 1 then
    exts[1] := cExtPortSubset;

  FillChar(dci, SizeOf(dci), 0);
  dci.sType                   := VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO;
  dci.queueCreateInfoCount    := UInt32(Length(unique));
  dci.pQueueCreateInfos       := @qInfos[0];
  dci.enabledExtensionCount   := UInt32(extCount);
  dci.ppEnabledExtensionNames := PPAnsiChar(@exts[0]);

  gDevice := nil;
  VkCheck(vkCreateDevice(gPhysicalDevice, @dci, nil, @gDevice), 'vkCreateDevice');

  vkGetDeviceQueue(gDevice, gGraphicsQFamily, 0, @gGraphicsQueue);
  vkGetDeviceQueue(gDevice, gPresentQFamily,  0, @gPresentQueue);
end;

// ============================================================
// Swapchain bundle (swapchain + views + render pass + pipeline
//                  + framebuffers + command pool/buffers)
// ============================================================
procedure RecordCommandBuffers(var b: TSwapchainBundle);
var
  i:         Integer;
  beginInfo: TVkCommandBufferBeginInfo;
  clear:     TVkClearValue;
  rpbi:      TVkRenderPassBeginInfo;
  vp:        TVkViewport;
  sc:        TVkRect2D;
begin
  FillChar(clear, SizeOf(clear), 0);
  clear.color.float32[0] := 0.05;
  clear.color.float32[1] := 0.05;
  clear.color.float32[2] := 0.10;
  clear.color.float32[3] := 1.0;

  for i := 0 to Integer(b.imageCount) - 1 do
  begin
    FillChar(beginInfo, SizeOf(beginInfo), 0);
    beginInfo.sType := VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO;
    VkCheck(vkBeginCommandBuffer(b.commandBuffers[i], @beginInfo), 'vkBeginCommandBuffer');

    vp.x        := 0; vp.y        := 0;
    vp.width    := b.extent.width;
    vp.height   := b.extent.height;
    vp.minDepth := 0; vp.maxDepth := 1;

    sc.offset.x := 0; sc.offset.y := 0;
    sc.extent   := b.extent;

    FillChar(rpbi, SizeOf(rpbi), 0);
    rpbi.sType               := VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO;
    rpbi.renderPass          := b.renderPass;
    rpbi.framebuffer         := b.framebuffers[i];
    rpbi.renderArea.offset.x := 0;
    rpbi.renderArea.offset.y := 0;
    rpbi.renderArea.extent   := b.extent;
    rpbi.clearValueCount     := 1;
    rpbi.pClearValues        := @clear;

    vkCmdBeginRenderPass(b.commandBuffers[i], @rpbi, 0);
    vkCmdBindPipeline(b.commandBuffers[i], VK_PIPELINE_BIND_POINT_GRAPHICS, b.pipeline);
    vkCmdSetViewport(b.commandBuffers[i], 0, 1, @vp);
    vkCmdSetScissor(b.commandBuffers[i],  0, 1, @sc);
    vkCmdDraw(b.commandBuffers[i], 3, 1, 0, 0);
    vkCmdEndRenderPass(b.commandBuffers[i]);

    VkCheck(vkEndCommandBuffer(b.commandBuffers[i]), 'vkEndCommandBuffer');
  end;
end;

procedure CreateSwapchainBundle(out b: TSwapchainBundle);
var
  caps:        TVkSurfaceCapabilitiesKHR;
  fmtCount:    UInt32;
  pmCount:     UInt32;
  imgCount:    UInt32;
  fmts:        array of TVkSurfaceFormatKHR;
  pms:         array of UInt32;
  sfmt:        TVkSurfaceFormatKHR;
  extent:      TVkExtent2D;
  desiredCount: UInt32;
  sharingMode: UInt32;
  qCount:      UInt32;
  pQ:          PUInt32;
  qIndices:    array[0..1] of UInt32;
  sci:         TVkSwapchainCreateInfoKHR;
  ivci:        TVkImageViewCreateInfo;
  colorAttach: TVkAttachmentDescription;
  colorRef:    TVkAttachmentReference;
  subpass:     TVkSubpassDescription;
  rpci:        TVkRenderPassCreateInfo;
  vertMod:     VkShaderModule;
  fragMod:     VkShaderModule;
  plci:        TVkPipelineLayoutCreateInfo;
  stages:      array[0..1] of TVkPipelineShaderStageCreateInfo;
  vin:         TVkPipelineVertexInputStateCreateInfo;
  ia:          TVkPipelineInputAssemblyStateCreateInfo;
  dummyVp:     TVkViewport;
  dummySc:     TVkRect2D;
  vpState:     TVkPipelineViewportStateCreateInfo;
  rs:          TVkPipelineRasterizationStateCreateInfo;
  ms:          TVkPipelineMultisampleStateCreateInfo;
  cbAttach:    TVkPipelineColorBlendAttachmentState;
  cb:          TVkPipelineColorBlendStateCreateInfo;
  dynStates:   array[0..1] of UInt32;
  dyn:         TVkPipelineDynamicStateCreateInfo;
  gpci:        TVkGraphicsPipelineCreateInfo;
  fbci:        TVkFramebufferCreateInfo;
  cpci:        TVkCommandPoolCreateInfo;
  cbi:         TVkCommandBufferAllocateInfo;
  attachView:  VkImageView;
  i:           Integer;
begin
  FillChar(b, SizeOf(b), 0);

  // Surface capabilities + formats + present modes
  VkCheck(vkGetPhysicalDeviceSurfaceCapabilitiesKHR(gPhysicalDevice, gSurface, @caps),
          'vkGetPhysicalDeviceSurfaceCapabilitiesKHR');

  fmtCount := 0;
  VkCheck(vkGetPhysicalDeviceSurfaceFormatsKHR(gPhysicalDevice, gSurface, @fmtCount, nil),
          'vkGetPhysicalDeviceSurfaceFormatsKHR(count)');
  SetLength(fmts, fmtCount);
  if fmtCount > 0 then
    VkCheck(vkGetPhysicalDeviceSurfaceFormatsKHR(gPhysicalDevice, gSurface, @fmtCount, @fmts[0]),
            'vkGetPhysicalDeviceSurfaceFormatsKHR(list)');

  pmCount := 0;
  VkCheck(vkGetPhysicalDeviceSurfacePresentModesKHR(gPhysicalDevice, gSurface, @pmCount, nil),
          'vkGetPhysicalDeviceSurfacePresentModesKHR(count)');
  SetLength(pms, pmCount);
  if pmCount > 0 then
    VkCheck(vkGetPhysicalDeviceSurfacePresentModesKHR(gPhysicalDevice, gSurface, @pmCount, @pms[0]),
            'vkGetPhysicalDeviceSurfacePresentModesKHR(list)');

  sfmt   := ChooseSurfaceFormat(fmts);
  extent := ChooseExtent(caps);

  desiredCount := caps.minImageCount + 1;
  if (caps.maxImageCount <> 0) and (desiredCount > caps.maxImageCount) then
    desiredCount := caps.maxImageCount;

  qIndices[0] := gGraphicsQFamily;
  qIndices[1] := gPresentQFamily;
  if gGraphicsQFamily <> gPresentQFamily then
  begin
    sharingMode := VK_SHARING_MODE_CONCURRENT;
    qCount      := 2;
    pQ          := @qIndices[0];
  end
  else
  begin
    sharingMode := VK_SHARING_MODE_EXCLUSIVE;
    qCount      := 0;
    pQ          := nil;
  end;

  // Swapchain
  FillChar(sci, SizeOf(sci), 0);
  sci.sType                 := VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR;
  sci.surface               := gSurface;
  sci.minImageCount         := desiredCount;
  sci.imageFormat           := sfmt.format;
  sci.imageColorSpace       := sfmt.colorSpace;
  sci.imageExtent           := extent;
  sci.imageArrayLayers      := 1;
  sci.imageUsage            := VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT;
  sci.imageSharingMode      := sharingMode;
  sci.queueFamilyIndexCount := qCount;
  sci.pQueueFamilyIndices   := pQ;
  if (caps.supportedTransforms and caps.currentTransform) <> 0 then
    sci.preTransform := caps.currentTransform
  else
    sci.preTransform := VK_SURFACE_TRANSFORM_IDENTITY_BIT_KHR;
  sci.compositeAlpha        := VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR;
  sci.presentMode           := VK_PRESENT_MODE_FIFO_KHR;
  sci.clipped               := 1;
  sci.oldSwapchain          := 0;

  b.swapchain := 0;
  VkCheck(vkCreateSwapchainKHR(gDevice, @sci, nil, @b.swapchain), 'vkCreateSwapchainKHR');
  b.format := sfmt.format;
  b.extent := extent;

  imgCount := 0;
  VkCheck(vkGetSwapchainImagesKHR(gDevice, b.swapchain, @imgCount, nil), 'vkGetSwapchainImagesKHR(count)');
  b.imageCount := imgCount;
  SetLength(b.images, imgCount);
  VkCheck(vkGetSwapchainImagesKHR(gDevice, b.swapchain, @imgCount, @b.images[0]), 'vkGetSwapchainImagesKHR(list)');

  // Image views
  SetLength(b.views, imgCount);
  for i := 0 to Integer(imgCount) - 1 do
  begin
    FillChar(ivci, SizeOf(ivci), 0);
    ivci.sType                           := VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO;
    ivci.image                           := b.images[i];
    ivci.viewType                        := VK_IMAGE_VIEW_TYPE_2D;
    ivci.format                          := b.format;
    ivci.subresourceRange.aspectMask     := VK_IMAGE_ASPECT_COLOR_BIT;
    ivci.subresourceRange.levelCount     := 1;
    ivci.subresourceRange.layerCount     := 1;
    b.views[i] := 0;
    VkCheck(vkCreateImageView(gDevice, @ivci, nil, @b.views[i]), 'vkCreateImageView');
  end;

  // Render pass
  FillChar(colorAttach, SizeOf(colorAttach), 0);
  colorAttach.format        := b.format;
  colorAttach.samples       := VK_SAMPLE_COUNT_1_BIT;
  colorAttach.loadOp        := VK_ATTACHMENT_LOAD_OP_CLEAR;
  colorAttach.storeOp       := VK_ATTACHMENT_STORE_OP_STORE;
  colorAttach.stencilLoadOp := VK_ATTACHMENT_LOAD_OP_DONT_CARE;
  colorAttach.stencilStoreOp := VK_ATTACHMENT_STORE_OP_DONT_CARE;
  colorAttach.initialLayout := VK_IMAGE_LAYOUT_UNDEFINED;
  colorAttach.finalLayout   := VK_IMAGE_LAYOUT_PRESENT_SRC_KHR;

  colorRef.attachment := 0;
  colorRef.layout     := VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL;

  FillChar(subpass, SizeOf(subpass), 0);
  subpass.pipelineBindPoint    := VK_PIPELINE_BIND_POINT_GRAPHICS;
  subpass.colorAttachmentCount := 1;
  subpass.pColorAttachments    := @colorRef;

  FillChar(rpci, SizeOf(rpci), 0);
  rpci.sType           := VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO;
  rpci.attachmentCount := 1;
  rpci.pAttachments    := @colorAttach;
  rpci.subpassCount    := 1;
  rpci.pSubpasses      := @subpass;

  b.renderPass := 0;
  VkCheck(vkCreateRenderPass(gDevice, @rpci, nil, @b.renderPass), 'vkCreateRenderPass');

  // Shaders (pre-compiled SPIR-V)
  vertMod := CreateShaderModuleFromFile(gDevice, 'hello_vert.spv');
  fragMod := CreateShaderModuleFromFile(gDevice, 'hello_frag.spv');

  // Pipeline layout (no descriptors)
  FillChar(plci, SizeOf(plci), 0);
  plci.sType := VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO;
  b.pipelineLayout := 0;
  VkCheck(vkCreatePipelineLayout(gDevice, @plci, nil, @b.pipelineLayout), 'vkCreatePipelineLayout');

  // Shader stages
  FillChar(stages, SizeOf(stages), 0);
  stages[0].sType   := VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO;
  stages[0].stage   := VK_SHADER_STAGE_VERTEX_BIT;
  stages[0].module_ := vertMod;
  stages[0].pName   := 'main';
  stages[1].sType   := VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO;
  stages[1].stage   := VK_SHADER_STAGE_FRAGMENT_BIT;
  stages[1].module_ := fragMod;
  stages[1].pName   := 'main';

  FillChar(vin, SizeOf(vin), 0);
  vin.sType := VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO;

  FillChar(ia, SizeOf(ia), 0);
  ia.sType    := VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO;
  ia.topology := VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST;

  // Dummy viewport/scissor (dynamic state overrides at draw time)
  dummyVp.x        := 0; dummyVp.y        := 0;
  dummyVp.width    := extent.width;
  dummyVp.height   := extent.height;
  dummyVp.minDepth := 0; dummyVp.maxDepth := 1;
  dummySc.offset.x := 0; dummySc.offset.y := 0;
  dummySc.extent   := extent;

  FillChar(vpState, SizeOf(vpState), 0);
  vpState.sType         := VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO;
  vpState.viewportCount := 1;
  vpState.pViewports    := @dummyVp;
  vpState.scissorCount  := 1;
  vpState.pScissors     := @dummySc;

  FillChar(rs, SizeOf(rs), 0);
  rs.sType     := VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO;
  rs.polygonMode := VK_POLYGON_MODE_FILL;
  rs.cullMode  := VK_CULL_MODE_NONE;
  rs.frontFace := VK_FRONT_FACE_COUNTER_CLOCKWISE;
  rs.lineWidth := 1.0;

  FillChar(ms, SizeOf(ms), 0);
  ms.sType                := VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO;
  ms.rasterizationSamples := VK_SAMPLE_COUNT_1_BIT;

  FillChar(cbAttach, SizeOf(cbAttach), 0);
  cbAttach.colorWriteMask := VK_COLOR_COMPONENT_R_BIT or VK_COLOR_COMPONENT_G_BIT
                          or VK_COLOR_COMPONENT_B_BIT or VK_COLOR_COMPONENT_A_BIT;

  FillChar(cb, SizeOf(cb), 0);
  cb.sType           := VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO;
  cb.attachmentCount := 1;
  cb.pAttachments    := @cbAttach;

  dynStates[0] := VK_DYNAMIC_STATE_VIEWPORT;
  dynStates[1] := VK_DYNAMIC_STATE_SCISSOR;
  FillChar(dyn, SizeOf(dyn), 0);
  dyn.sType             := VK_STRUCTURE_TYPE_PIPELINE_DYNAMIC_STATE_CREATE_INFO;
  dyn.dynamicStateCount := 2;
  dyn.pDynamicStates    := @dynStates[0];

  FillChar(gpci, SizeOf(gpci), 0);
  gpci.sType               := VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO;
  gpci.stageCount          := 2;
  gpci.pStages             := @stages[0];
  gpci.pVertexInputState   := @vin;
  gpci.pInputAssemblyState := @ia;
  gpci.pViewportState      := @vpState;
  gpci.pRasterizationState := @rs;
  gpci.pMultisampleState   := @ms;
  gpci.pColorBlendState    := @cb;
  gpci.pDynamicState       := @dyn;
  gpci.layout              := b.pipelineLayout;
  gpci.renderPass          := b.renderPass;
  gpci.subpass             := 0;
  gpci.basePipelineHandle  := 0;
  gpci.basePipelineIndex   := -1;

  b.pipeline := 0;
  VkCheck(vkCreateGraphicsPipelines(gDevice, 0, 1, @gpci, nil, @b.pipeline), 'vkCreateGraphicsPipelines');

  vkDestroyShaderModule(gDevice, vertMod, nil);
  vkDestroyShaderModule(gDevice, fragMod, nil);

  // Framebuffers
  SetLength(b.framebuffers, imgCount);
  for i := 0 to Integer(imgCount) - 1 do
  begin
    attachView := b.views[i];
    FillChar(fbci, SizeOf(fbci), 0);
    fbci.sType           := VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO;
    fbci.renderPass      := b.renderPass;
    fbci.attachmentCount := 1;
    fbci.pAttachments    := @attachView;
    fbci.width           := extent.width;
    fbci.height          := extent.height;
    fbci.layers          := 1;
    b.framebuffers[i] := 0;
    VkCheck(vkCreateFramebuffer(gDevice, @fbci, nil, @b.framebuffers[i]), 'vkCreateFramebuffer');
  end;

  // Command pool + buffers
  FillChar(cpci, SizeOf(cpci), 0);
  cpci.sType            := VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO;
  cpci.flags            := VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT;
  cpci.queueFamilyIndex := gGraphicsQFamily;
  b.commandPool := nil;
  VkCheck(vkCreateCommandPool(gDevice, @cpci, nil, @b.commandPool), 'vkCreateCommandPool');

  SetLength(b.commandBuffers, imgCount);
  FillChar(cbi, SizeOf(cbi), 0);
  cbi.sType               := VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO;
  cbi.commandPool         := b.commandPool;
  cbi.level_              := VK_COMMAND_BUFFER_LEVEL_PRIMARY;
  cbi.commandBufferCount  := imgCount;
  VkCheck(vkAllocateCommandBuffers(gDevice, @cbi, @b.commandBuffers[0]), 'vkAllocateCommandBuffers');

  RecordCommandBuffers(b);
end;

procedure DestroySwapchainBundle(var b: TSwapchainBundle);
var
  i: Integer;
begin
  if gDevice = nil then Exit;

  if b.commandPool <> nil then
  begin
    vkDestroyCommandPool(gDevice, b.commandPool, nil);
    b.commandPool := nil;
  end;

  for i := 0 to High(b.framebuffers) do
    if b.framebuffers[i] <> 0 then
      vkDestroyFramebuffer(gDevice, b.framebuffers[i], nil);
  SetLength(b.framebuffers, 0);

  if b.pipeline <> 0       then vkDestroyPipeline(gDevice, b.pipeline, nil);
  if b.pipelineLayout <> 0 then vkDestroyPipelineLayout(gDevice, b.pipelineLayout, nil);
  if b.renderPass <> 0     then vkDestroyRenderPass(gDevice, b.renderPass, nil);

  for i := 0 to High(b.views) do
    if b.views[i] <> 0 then
      vkDestroyImageView(gDevice, b.views[i], nil);
  SetLength(b.views, 0);
  SetLength(b.images, 0);

  if b.swapchain <> 0 then
    vkDestroySwapchainKHR(gDevice, b.swapchain, nil);

  FillChar(b, SizeOf(b), 0);
end;

procedure RecreateSwapchain;
var
  w, h: Integer;
  newBundle: TSwapchainBundle;
begin
  // Wait while minimized
  w := 0; h := 0;
  glfwGetFramebufferSize(gWindow, @w, @h);
  while (w = 0) or (h = 0) do
  begin
    glfwGetFramebufferSize(gWindow, @w, @h);
    glfwWaitEvents;
  end;

  VkCheck(vkDeviceWaitIdle(gDevice), 'vkDeviceWaitIdle');
  DestroySwapchainBundle(gBundle);
  CreateSwapchainBundle(newBundle);
  gBundle := newBundle;
end;

// ============================================================
// Sync objects
// ============================================================
procedure CreateSyncObjects(out s: TSyncObjects);
var
  sci: TVkSemaphoreCreateInfo;
  fci: TVkFenceCreateInfo;
  i:   Integer;
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
    s.inFlight[i]       := 0;
    VkCheck(vkCreateSemaphore(gDevice, @sci, nil, @s.imageAvailable[i]), 'vkCreateSemaphore');
    VkCheck(vkCreateSemaphore(gDevice, @sci, nil, @s.renderFinished[i]), 'vkCreateSemaphore');
    VkCheck(vkCreateFence(gDevice, @fci, nil, @s.inFlight[i]), 'vkCreateFence');
  end;
end;

procedure DestroySyncObjects(var s: TSyncObjects);
var
  i: Integer;
begin
  if gDevice = nil then Exit;
  for i := 0 to 1 do
  begin
    if s.imageAvailable[i] <> 0 then vkDestroySemaphore(gDevice, s.imageAvailable[i], nil);
    if s.renderFinished[i] <> 0 then vkDestroySemaphore(gDevice, s.renderFinished[i], nil);
    if s.inFlight[i]       <> 0 then vkDestroyFence(gDevice, s.inFlight[i], nil);
  end;
  FillChar(s, SizeOf(s), 0);
end;

// ============================================================
// Draw frame
// ============================================================
procedure DrawFrame;
var
  cur:         UInt32;
  fenceArr:    array[0..0] of VkFence;
  imageIndex:  UInt32;
  res:         VkResult;
  waitSems:    array[0..0] of VkSemaphore;
  signalSems:  array[0..0] of VkSemaphore;
  waitStages:  array[0..0] of UInt32;
  cmdArr:      array[0..0] of VkCommandBuffer;
  submit:      TVkSubmitInfo;
  present:     TVkPresentInfoKHR;
  swapArr:     array[0..0] of VkSwapchainKHR;
  idxArr:      array[0..0] of UInt32;
begin
  cur := gFrame and 1;

  fenceArr[0] := gSync.inFlight[cur];
  VkCheck(vkWaitForFences(gDevice, 1, @fenceArr[0], 1, High(UInt64)), 'vkWaitForFences');

  imageIndex := 0;
  res := vkAcquireNextImageKHR(gDevice, gBundle.swapchain, High(UInt64),
                               gSync.imageAvailable[cur], 0, @imageIndex);
  if res = VK_ERROR_OUT_OF_DATE_KHR then
  begin
    RecreateSwapchain;
    Exit;
  end
  else if (res <> VK_SUCCESS) and (res <> VK_SUBOPTIMAL_KHR) then
    VkCheck(res, 'vkAcquireNextImageKHR');

  VkCheck(vkResetFences(gDevice, 1, @fenceArr[0]), 'vkResetFences');

  waitSems[0]   := gSync.imageAvailable[cur];
  signalSems[0] := gSync.renderFinished[cur];
  waitStages[0] := VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT;
  cmdArr[0]     := gBundle.commandBuffers[imageIndex];

  FillChar(submit, SizeOf(submit), 0);
  submit.sType                := VK_STRUCTURE_TYPE_SUBMIT_INFO;
  submit.waitSemaphoreCount   := 1;
  submit.pWaitSemaphores      := @waitSems[0];
  submit.pWaitDstStageMask    := @waitStages[0];
  submit.commandBufferCount   := 1;
  submit.pCommandBuffers      := @cmdArr[0];
  submit.signalSemaphoreCount := 1;
  submit.pSignalSemaphores    := @signalSems[0];

  VkCheck(vkQueueSubmit(gGraphicsQueue, 1, @submit, gSync.inFlight[cur]), 'vkQueueSubmit');

  swapArr[0] := gBundle.swapchain;
  idxArr[0]  := imageIndex;

  FillChar(present, SizeOf(present), 0);
  present.sType              := VK_STRUCTURE_TYPE_PRESENT_INFO_KHR;
  present.waitSemaphoreCount := 1;
  present.pWaitSemaphores    := @signalSems[0];
  present.swapchainCount     := 1;
  present.pSwapchains        := @swapArr[0];
  present.pImageIndices      := @idxArr[0];

  res := vkQueuePresentKHR(gPresentQueue, @present);
  if (res = VK_ERROR_OUT_OF_DATE_KHR) or (res = VK_SUBOPTIMAL_KHR) or gResized then
  begin
    gResized := False;
    RecreateSwapchain;
  end
  else if res <> VK_SUCCESS then
    VkCheck(res, 'vkQueuePresentKHR');

  Inc(gFrame);
end;

// ============================================================
// Init / shutdown
// ============================================================
procedure VulkanInit;
begin
  CreateWindow;
  CreateInstance;
  CreateSurface;
  PickPhysicalDeviceAndQueues;
  CreateDeviceAndQueues;
  CreateSwapchainBundle(gBundle);
  CreateSyncObjects(gSync);
  gResized := False;
end;

procedure VulkanShutdown;
begin
  if gDevice <> nil then
  begin
    VkCheck(vkDeviceWaitIdle(gDevice), 'vkDeviceWaitIdle');
    DestroySyncObjects(gSync);
    DestroySwapchainBundle(gBundle);
    vkDestroyDevice(gDevice, nil);
    gDevice := nil;
  end;

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

  if gWindow <> nil then
  begin
    glfwDestroyWindow(gWindow);
    gWindow := nil;
  end;

  glfwTerminate;
end;

procedure MainLoop;
begin
  while glfwWindowShouldClose(gWindow) = 0 do
  begin
    glfwPollEvents;

    if gResized then
    begin
      gResized := False;
      RecreateSwapchain;
      Continue;
    end;

    DrawFrame;
  end;
  VkCheck(vkDeviceWaitIdle(gDevice), 'vkDeviceWaitIdle(end)');
end;

// ============================================================
// Entry point
// ============================================================
begin
  // Mask all FP exceptions: GLFW and MoltenVK may perform operations
  // (NaN, denormals) that FPC leaves unmasked by default on macOS.
  SetExceptionMask([exInvalidOp, exDenormalized, exZeroDivide,
                    exOverflow, exUnderflow, exPrecision]);
  try
    VulkanInit;
    MainLoop;
  finally
    VulkanShutdown;
  end;
end.
