
program hello;

{$mode delphi}
{$apptype gui}
{$H+}
{$PACKRECORDS C}

uses
  Windows, Messages, ActiveX, SysUtils, Classes;

type
  UINT = Cardinal;
  SIZE_T = NativeUInt;
  DXGI_FORMAT = Cardinal;
  D3D_DRIVER_TYPE = Cardinal;
  D3D_FEATURE_LEVEL = Cardinal;
  D3D11_PRIMITIVE_TOPOLOGY = Cardinal;

  DXGI_SAMPLE_DESC = record
    Count: UINT;
    Quality: UINT;
  end;

  DXGI_SWAP_CHAIN_DESC1 = record
    Width: UINT;
    Height: UINT;
    Format: DXGI_FORMAT;
    Stereo: BOOL;
    SampleDesc: DXGI_SAMPLE_DESC;
    BufferUsage: UINT;
    BufferCount: UINT;
    Scaling: UINT;
    SwapEffect: UINT;
    AlphaMode: UINT;
    Flags: UINT;
  end;
  PDXGI_SWAP_CHAIN_DESC1 = ^DXGI_SWAP_CHAIN_DESC1;

  D3D11_VIEWPORT = record
    TopLeftX: Single;
    TopLeftY: Single;
    Width: Single;
    Height: Single;
    MinDepth: Single;
    MaxDepth: Single;
  end;

  D3D11_INPUT_ELEMENT_DESC = record
    SemanticName: PAnsiChar;
    SemanticIndex: UINT;
    Format: DXGI_FORMAT;
    InputSlot: UINT;
    AlignedByteOffset: UINT;
    InputSlotClass: UINT;
    InstanceDataStepRate: UINT;
  end;
  PD3D11_INPUT_ELEMENT_DESC = ^D3D11_INPUT_ELEMENT_DESC;

  D3D11_BUFFER_DESC = record
    ByteWidth: UINT;
    Usage: UINT;
    BindFlags: UINT;
    CPUAccessFlags: UINT;
    MiscFlags: UINT;
    StructureByteStride: UINT;
  end;

  D3D11_SUBRESOURCE_DATA = record
    pSysMem: Pointer;
    SysMemPitch: UINT;
    SysMemSlicePitch: UINT;
  end;

  D3D11_TEXTURE2D_DESC = record
    Width: UINT;
    Height: UINT;
    MipLevels: UINT;
    ArraySize: UINT;
    Format: DXGI_FORMAT;
    SampleDesc: DXGI_SAMPLE_DESC;
    Usage: UINT;
    BindFlags: UINT;
    CPUAccessFlags: UINT;
    MiscFlags: UINT;
  end;

  D3D11_MAPPED_SUBRESOURCE = record
    pData: Pointer;
    RowPitch: UINT;
    DepthPitch: UINT;
  end;

  TVertex = packed record
    x, y, z: Single;
    r, g, b, a: Single;
  end;

  TQueryInterface = function(Self: Pointer; const iid: TGUID; out obj): HRESULT; stdcall;
  TRelease = function(Self: Pointer): ULONG; stdcall;
  TGetAdapter = function(Self: Pointer; out ppAdapter: Pointer): HRESULT; stdcall;
  TGetParent = function(Self: Pointer; const iid: TGUID; out ppParent: Pointer): HRESULT; stdcall;
  TCreateSwapChainForComposition = function(Self: Pointer; pDevice: Pointer; pDesc: PDXGI_SWAP_CHAIN_DESC1; pRestrictToOutput: Pointer; out ppSwapChain: Pointer): HRESULT; stdcall;
  TSwapChainGetBuffer = function(Self: Pointer; Buffer: UINT; const iid: TGUID; out ppSurface): HRESULT; stdcall;
  TSwapChainPresent = function(Self: Pointer; SyncInterval: UINT; Flags: UINT): HRESULT; stdcall;

  TD3DCreateRTV = function(Self: Pointer; pResource: Pointer; pDesc: Pointer; out ppRTV: Pointer): HRESULT; stdcall;
  TD3DCreateBuffer = function(Self: Pointer; const pDesc: D3D11_BUFFER_DESC; pData: Pointer; out ppBuffer: Pointer): HRESULT; stdcall;
  TD3DCreateInputLayout = function(Self: Pointer; pInputElementDescs: PD3D11_INPUT_ELEMENT_DESC; NumElements: UINT; pShaderBytecodeWithInputSignature: Pointer; BytecodeLength: SIZE_T; out ppInputLayout: Pointer): HRESULT; stdcall;
  TD3DCreateVS = function(Self: Pointer; pShaderBytecode: Pointer; BytecodeLength: SIZE_T; pClassLinkage: Pointer; out ppVertexShader: Pointer): HRESULT; stdcall;
  TD3DCreatePS = function(Self: Pointer; pShaderBytecode: Pointer; BytecodeLength: SIZE_T; pClassLinkage: Pointer; out ppPixelShader: Pointer): HRESULT; stdcall;
  TD3DCreateTexture2D = function(Self: Pointer; pDesc: Pointer; pInitialData: Pointer; out ppTexture2D: Pointer): HRESULT; stdcall;

  TCtxOMSetRenderTargets = procedure(Self: Pointer; NumViews: UINT; ppRenderTargetViews: PPointer; pDSV: Pointer); stdcall;
  TCtxRSSetViewports = procedure(Self: Pointer; NumViewports: UINT; pViewports: Pointer); stdcall;
  TCtxClearRTV = procedure(Self: Pointer; pRTV: Pointer; ColorRGBA: PSingle); stdcall;
  TCtxIASetInputLayout = procedure(Self: Pointer; pInputLayout: Pointer); stdcall;
  TCtxIASetVertexBuffers = procedure(Self: Pointer; StartSlot, NumBuffers: UINT; ppVertexBuffers: PPointer; pStrides, pOffsets: PCardinal); stdcall;
  TCtxIASetPrimitiveTopology = procedure(Self: Pointer; Topology: D3D11_PRIMITIVE_TOPOLOGY); stdcall;
  TCtxVSSetShader = procedure(Self: Pointer; pVS: Pointer; ppClassInstances: Pointer; NumClassInstances: UINT); stdcall;
  TCtxPSSetShader = procedure(Self: Pointer; pPS: Pointer; ppClassInstances: Pointer; NumClassInstances: UINT); stdcall;
  TCtxDraw = procedure(Self: Pointer; VertexCount, StartVertexLocation: UINT); stdcall;
  TCtxMap = function(Self: Pointer; pResource: Pointer; Subresource, MapType, MapFlags: UINT; out pMapped: D3D11_MAPPED_SUBRESOURCE): HRESULT; stdcall;
  TCtxUnmap = procedure(Self: Pointer; pResource: Pointer; Subresource: UINT); stdcall;
  TCtxCopyResource = procedure(Self: Pointer; pDstResource, pSrcResource: Pointer); stdcall;

  TBlobGetBufferPointer = function(Self: Pointer): Pointer; stdcall;
  TBlobGetBufferSize = function(Self: Pointer): SIZE_T; stdcall;

  TDCompCreateTargetForHwnd = function(Self: Pointer; hwnd: HWND; topmost: BOOL; out ppTarget: Pointer): HRESULT; stdcall;
  TDCompCreateVisual = function(Self: Pointer; out ppVisual: Pointer): HRESULT; stdcall;
  TDCompCommit = function(Self: Pointer): HRESULT; stdcall;
  TDCompTargetSetRoot = function(Self: Pointer; pVisual: Pointer): HRESULT; stdcall;
  TDCompVisualSetOffsetX = function(Self: Pointer; x: Single): HRESULT; stdcall;
  TDCompVisualSetOffsetY = function(Self: Pointer; y: Single): HRESULT; stdcall;
  TDCompVisualSetContent = function(Self: Pointer; pContent: Pointer): HRESULT; stdcall;
  TDCompVisualAddVisual = function(Self: Pointer; pVisual: Pointer; insertAbove: BOOL; pReferenceVisual: Pointer): HRESULT; stdcall;

  PFNWGLCREATECONTEXTATTRIBSARBPROC = function(hdc: HDC; hShareContext: HGLRC; const attribList: PInteger): HGLRC; stdcall;
  PFNWGLDXOPENDEVICENVPROC = function(dxDevice: Pointer): THandle; stdcall;
  PFNWGLDXCLOSEDEVICENVPROC = function(hDevice: THandle): BOOL; stdcall;
  PFNWGLDXREGISTEROBJECTNVPROC = function(hDevice: THandle; dxObject: Pointer; name: Cardinal; objType: Cardinal; access: Cardinal): THandle; stdcall;
  PFNWGLDXUNREGISTEROBJECTNVPROC = function(hDevice: THandle; hObject: THandle): BOOL; stdcall;
  PFNWGLDXLOCKOBJECTSNVPROC = function(hDevice: THandle; count: Integer; hObjects: PHandle): BOOL; stdcall;
  PFNWGLDXUNLOCKOBJECTSNVPROC = function(hDevice: THandle; count: Integer; hObjects: PHandle): BOOL; stdcall;

  TglGenBuffers = procedure(n: Integer; buffers: PCardinal); stdcall;
  TglBindBuffer = procedure(target: Cardinal; buffer: Cardinal); stdcall;
  TglBufferData = procedure(target: Cardinal; size: NativeInt; const data: Pointer; usage: Cardinal); stdcall;
  TglCreateShader = function(shaderType: Cardinal): Cardinal; stdcall;
  TglShaderSource = procedure(shaderObj: Cardinal; count: Integer; const str: PPAnsiChar; lengths: PInteger); stdcall;
  TglCompileShader = procedure(shaderObj: Cardinal); stdcall;
  TglCreateProgram = function: Cardinal; stdcall;
  TglAttachShader = procedure(programObj, shaderObj: Cardinal); stdcall;
  TglLinkProgram = procedure(programObj: Cardinal); stdcall;
  TglUseProgram = procedure(programObj: Cardinal); stdcall;
  TglGetAttribLocation = function(programObj: Cardinal; name: PAnsiChar): Integer; stdcall;
  TglEnableVertexAttribArray = procedure(index: Cardinal); stdcall;
  TglVertexAttribPointer = procedure(index: Cardinal; size: Integer; aType: Cardinal; normalized: Byte; stride: Integer; const ptr: Pointer); stdcall;
  TglGenVertexArrays = procedure(n: Integer; arrays: PCardinal); stdcall;
  TglBindVertexArray = procedure(array_: Cardinal); stdcall;
  TglGenFramebuffers = procedure(n: Integer; framebuffers: PCardinal); stdcall;
  TglBindFramebuffer = procedure(target: Cardinal; framebuffer: Cardinal); stdcall;
  TglFramebufferRenderbuffer = procedure(target, attachment, renderbuffertarget, renderbuffer: Cardinal); stdcall;
  TglGenRenderbuffers = procedure(n: Integer; renderbuffers: PCardinal); stdcall;
  TglBindRenderbuffer = procedure(target, renderbuffer: Cardinal); stdcall;

  VkInstance = Pointer;
  VkPhysicalDevice = Pointer;
  VkDevice = Pointer;
  VkQueue = Pointer;
  VkCommandPool = Pointer;
  VkCommandBuffer = Pointer;

  VkImage = UInt64;
  VkImageView = UInt64;
  VkBuffer = UInt64;
  VkDeviceMemory = UInt64;
  VkRenderPass = UInt64;
  VkFramebuffer = UInt64;
  VkShaderModule = UInt64;
  VkPipelineLayout = UInt64;
  VkPipeline = UInt64;
  VkFence = UInt64;

  TVkExtent3D = record
    width, height, depth: UInt32;
  end;

  TVkApplicationInfo = record
    sType: UInt32;
    pNext: Pointer;
    pApplicationName: PAnsiChar;
    applicationVersion: UInt32;
    pEngineName: PAnsiChar;
    engineVersion: UInt32;
    apiVersion: UInt32;
  end;

  TVkInstanceCreateInfo = record
    sType: UInt32;
    pNext: Pointer;
    flags: UInt32;
    pApplicationInfo: ^TVkApplicationInfo;
    enabledLayerCount: UInt32;
    ppEnabledLayerNames: PPAnsiChar;
    enabledExtensionCount: UInt32;
    ppEnabledExtensionNames: PPAnsiChar;
  end;

  TVkDeviceQueueCreateInfo = record
    sType: UInt32;
    pNext: Pointer;
    flags: UInt32;
    queueFamilyIndex: UInt32;
    queueCount: UInt32;
    pQueuePriorities: PSingle;
  end;

  TVkDeviceCreateInfo = record
    sType: UInt32;
    pNext: Pointer;
    flags: UInt32;
    queueCreateInfoCount: UInt32;
    pQueueCreateInfos: ^TVkDeviceQueueCreateInfo;
    enabledLayerCount: UInt32;
    ppEnabledLayerNames: PPAnsiChar;
    enabledExtensionCount: UInt32;
    ppEnabledExtensionNames: PPAnsiChar;
    pEnabledFeatures: Pointer;
  end;

  TVkQueueFamilyProperties = record
    queueFlags: UInt32;
    queueCount: UInt32;
    timestampValidBits: UInt32;
    minImageTransferGranularity: TVkExtent3D;
  end;

  TVkMemoryRequirements = record
    size: UInt64;
    alignment: UInt64;
    memoryTypeBits: UInt32;
  end;

  TVkMemoryAllocateInfo = record
    sType: UInt32;
    pNext: Pointer;
    allocationSize: UInt64;
    memoryTypeIndex: UInt32;
  end;

  TVkMemoryType = record
    propertyFlags: UInt32;
    heapIndex: UInt32;
  end;

  TVkMemoryHeap = record
    size: UInt64;
    flags: UInt32;
  end;

  TVkPhysicalDeviceMemoryProperties = record
    memoryTypeCount: UInt32;
    memoryTypes: array[0..31] of TVkMemoryType;
    memoryHeapCount: UInt32;
    memoryHeaps: array[0..15] of TVkMemoryHeap;
  end;

  TVkImageCreateInfo = record
    sType: UInt32;
    pNext: Pointer;
    flags: UInt32;
    imageType: UInt32;
    format: UInt32;
    extent: TVkExtent3D;
    mipLevels: UInt32;
    arrayLayers: UInt32;
    samples: UInt32;
    tiling: UInt32;
    usage: UInt32;
    sharingMode: UInt32;
    queueFamilyIndexCount: UInt32;
    pQueueFamilyIndices: PUInt32;
    initialLayout: UInt32;
  end;

  TVkImageViewCreateInfo = record
    sType: UInt32;
    pNext: Pointer;
    flags: UInt32;
    image: VkImage;
    viewType: UInt32;
    format: UInt32;
    componentsR, componentsG, componentsB, componentsA: UInt32;
    aspectMask: UInt32;
    baseMipLevel: UInt32;
    levelCount: UInt32;
    baseArrayLayer: UInt32;
    layerCount: UInt32;
  end;

  TVkBufferCreateInfo = record
    sType: UInt32;
    pNext: Pointer;
    flags: UInt32;
    size: UInt64;
    usage: UInt32;
    sharingMode: UInt32;
    queueFamilyIndexCount: UInt32;
    pQueueFamilyIndices: PUInt32;
  end;

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

  TVkSubpassDescription = record
    flags: UInt32;
    pipelineBindPoint: UInt32;
    inputAttachmentCount: UInt32;
    pInputAttachments: Pointer;
    colorAttachmentCount: UInt32;
    pColorAttachments: ^TVkAttachmentReference;
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

  TVkFramebufferCreateInfo = record
    sType: UInt32;
    pNext: Pointer;
    flags: UInt32;
    renderPass: VkRenderPass;
    attachmentCount: UInt32;
    pAttachments: ^VkImageView;
    width, height, layers: UInt32;
  end;

  TVkShaderModuleCreateInfo = record
    sType: UInt32;
    pNext: Pointer;
    flags: UInt32;
    codeSize: NativeUInt;
    pCode: Pointer;
  end;

  TVkPipelineShaderStageCreateInfo = record
    sType: UInt32;
    pNext: Pointer;
    flags: UInt32;
    stage: UInt32;
    module_: VkShaderModule;
    pName: PAnsiChar;
    pSpecializationInfo: Pointer;
  end;

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
    primitiveRestartEnable: UInt32;
  end;

  TVkViewport = record
    x, y, width, height, minDepth, maxDepth: Single;
  end;

  TVkOffset2D = record
    x, y: Int32;
  end;

  TVkExtent2D = record
    width, height: UInt32;
  end;

  TVkRect2D = record
    offset: TVkOffset2D;
    extent: TVkExtent2D;
  end;

  TVkPipelineViewportStateCreateInfo = record
    sType: UInt32;
    pNext: Pointer;
    flags: UInt32;
    viewportCount: UInt32;
    pViewports: ^TVkViewport;
    scissorCount: UInt32;
    pScissors: ^TVkRect2D;
  end;

  TVkPipelineRasterizationStateCreateInfo = record
    sType: UInt32;
    pNext: Pointer;
    flags: UInt32;
    depthClampEnable: UInt32;
    rasterizerDiscardEnable: UInt32;
    polygonMode: UInt32;
    cullMode: UInt32;
    frontFace: UInt32;
    depthBiasEnable: UInt32;
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
    sampleShadingEnable: UInt32;
    minSampleShading: Single;
    pSampleMask: Pointer;
    alphaToCoverageEnable: UInt32;
    alphaToOneEnable: UInt32;
  end;

  TVkPipelineColorBlendAttachmentState = record
    blendEnable: UInt32;
    srcColorBlendFactor: UInt32;
    dstColorBlendFactor: UInt32;
    colorBlendOp: UInt32;
    srcAlphaBlendFactor: UInt32;
    dstAlphaBlendFactor: UInt32;
    alphaBlendOp: UInt32;
    colorWriteMask: UInt32;
  end;

  TVkPipelineColorBlendStateCreateInfo = record
    sType: UInt32;
    pNext: Pointer;
    flags: UInt32;
    logicOpEnable: UInt32;
    logicOp: UInt32;
    attachmentCount: UInt32;
    pAttachments: ^TVkPipelineColorBlendAttachmentState;
    blendConstants: array[0..3] of Single;
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

  TVkGraphicsPipelineCreateInfo = record
    sType: UInt32;
    pNext: Pointer;
    flags: UInt32;
    stageCount: UInt32;
    pStages: ^TVkPipelineShaderStageCreateInfo;
    pVertexInputState: ^TVkPipelineVertexInputStateCreateInfo;
    pInputAssemblyState: ^TVkPipelineInputAssemblyStateCreateInfo;
    pTessellationState: Pointer;
    pViewportState: ^TVkPipelineViewportStateCreateInfo;
    pRasterizationState: ^TVkPipelineRasterizationStateCreateInfo;
    pMultisampleState: ^TVkPipelineMultisampleStateCreateInfo;
    pDepthStencilState: Pointer;
    pColorBlendState: ^TVkPipelineColorBlendStateCreateInfo;
    pDynamicState: Pointer;
    layout: VkPipelineLayout;
    renderPass: VkRenderPass;
    subpass: UInt32;
    basePipelineHandle: UInt64;
    basePipelineIndex: Int32;
  end;

  TVkCommandPoolCreateInfo = record
    sType: UInt32;
    pNext: Pointer;
    flags: UInt32;
    queueFamilyIndex: UInt32;
  end;

  TVkCommandBufferAllocateInfo = record
    sType: UInt32;
    pNext: Pointer;
    commandPool: VkCommandPool;
    level: UInt32;
    commandBufferCount: UInt32;
  end;

  TVkFenceCreateInfo = record
    sType: UInt32;
    pNext: Pointer;
    flags: UInt32;
  end;

  TVkCommandBufferBeginInfo = record
    sType: UInt32;
    pNext: Pointer;
    flags: UInt32;
    pInheritanceInfo: Pointer;
  end;

  TVkClearValue = record
    color: array[0..3] of Single;
  end;

  TVkRenderPassBeginInfo = record
    sType: UInt32;
    pNext: Pointer;
    renderPass: VkRenderPass;
    framebuffer: VkFramebuffer;
    renderArea: TVkRect2D;
    clearValueCount: UInt32;
    pClearValues: ^TVkClearValue;
  end;

  TVkSubmitInfo = record
    sType: UInt32;
    pNext: Pointer;
    waitSemaphoreCount: UInt32;
    pWaitSemaphores: Pointer;
    pWaitDstStageMask: Pointer;
    commandBufferCount: UInt32;
    pCommandBuffers: ^VkCommandBuffer;
    signalSemaphoreCount: UInt32;
    pSignalSemaphores: Pointer;
  end;

  TVkBufferImageCopy = record
    bufferOffset: UInt64;
    bufferRowLength: UInt32;
    bufferImageHeight: UInt32;
    imageSubresourceAspectMask: UInt32;
    imageSubresourceMipLevel: UInt32;
    imageSubresourceBaseArrayLayer: UInt32;
    imageSubresourceLayerCount: UInt32;
    imageOffsetX: Int32;
    imageOffsetY: Int32;
    imageOffsetZ: Int32;
    imageExtentWidth: UInt32;
    imageExtentHeight: UInt32;
    imageExtentDepth: UInt32;
  end;
  PVkBufferImageCopy = ^TVkBufferImageCopy;

const
  WINDOW_CLASS_NAME = 'PascalCompTriangleMulti';
  WINDOW_TITLE = 'OpenGL + DirectX 11 + Vulkan via DirectComposition (Pascal)';
  PANEL_WIDTH = 320;
  PANEL_HEIGHT = 480;
  WINDOW_WIDTH = PANEL_WIDTH * 3;

  WS_EX_NOREDIRECTIONBITMAP = $00200000;

  DXGI_FORMAT_B8G8R8A8_UNORM = 87;
  DXGI_FORMAT_R32G32B32_FLOAT = 6;
  DXGI_FORMAT_R32G32B32A32_FLOAT = 2;
  DXGI_USAGE_RENDER_TARGET_OUTPUT = $00000020;
  DXGI_SCALING_STRETCH = 0;
  DXGI_SWAP_EFFECT_FLIP_SEQUENTIAL = 3;
  DXGI_ALPHA_MODE_PREMULTIPLIED = 1;

  D3D_DRIVER_TYPE_HARDWARE = 1;
  D3D11_CREATE_DEVICE_BGRA_SUPPORT = $20;
  D3D11_SDK_VERSION = 7;
  D3D_FEATURE_LEVEL_11_0 = $b000;
  D3D11_BIND_VERTEX_BUFFER = $1;
  D3D11_USAGE_DEFAULT = 0;
  D3D11_USAGE_STAGING = 3;
  D3D11_CPU_ACCESS_WRITE = $00010000;
  D3D11_MAP_WRITE = 2;
  D3D11_INPUT_PER_VERTEX_DATA = 0;
  D3D11_PRIMITIVE_TOPOLOGY_TRIANGLELIST = 4;
  D3DCOMPILE_ENABLE_STRICTNESS = $800;

  PFD_TYPE_RGBA = 0;
  PFD_MAIN_PLANE = 0;
  PFD_DRAW_TO_WINDOW = $00000004;
  PFD_SUPPORT_OPENGL = $00000020;
  PFD_DOUBLEBUFFER = $00000001;

  WGL_CONTEXT_MAJOR_VERSION_ARB = $2091;
  WGL_CONTEXT_MINOR_VERSION_ARB = $2092;
  WGL_CONTEXT_PROFILE_MASK_ARB = $9126;
  WGL_CONTEXT_CORE_PROFILE_BIT_ARB = $00000001;
  WGL_ACCESS_READ_WRITE_NV = $0001;

  GL_FALSE = 0;
  GL_FLOAT = $1406;
  GL_COLOR_BUFFER_BIT = $00004000;
  GL_TRIANGLES = $0004;
  GL_ARRAY_BUFFER = $8892;
  GL_STATIC_DRAW = $88E4;
  GL_FRAGMENT_SHADER = $8B30;
  GL_VERTEX_SHADER = $8B31;
  GL_FRAMEBUFFER = $8D40;
  GL_RENDERBUFFER = $8D41;
  GL_COLOR_ATTACHMENT0 = $8CE0;

  VK_SUCCESS = 0;
  VK_STRUCTURE_TYPE_APPLICATION_INFO = 0;
  VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO = 1;
  VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO = 2;
  VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO = 3;
  VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO = 5;
  VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO = 16;
  VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO = 18;
  VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO = 19;
  VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO = 20;
  VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO = 22;
  VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO = 23;
  VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO = 24;
  VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO = 26;
  VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO = 28;
  VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO = 30;
  VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO = 37;
  VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO = 38;
  VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO = 39;
  VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO = 40;
  VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO = 42;
  VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO = 43;
  VK_STRUCTURE_TYPE_FENCE_CREATE_INFO = 8;
  VK_STRUCTURE_TYPE_SUBMIT_INFO = 4;
  VK_STRUCTURE_TYPE_IMAGE_CREATE_INFO = 14;
  VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO = 15;
  VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO = 12;

  VK_QUEUE_GRAPHICS_BIT = $00000001;
  VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT = $00000001;
  VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT = $00000002;
  VK_MEMORY_PROPERTY_HOST_COHERENT_BIT = $00000004;
  VK_IMAGE_TYPE_2D = 1;
  VK_FORMAT_B8G8R8A8_UNORM = 44;
  VK_SAMPLE_COUNT_1_BIT = 1;
  VK_IMAGE_TILING_OPTIMAL = 0;
  VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT = $00000010;
  VK_IMAGE_USAGE_TRANSFER_SRC_BIT = $00000001;
  VK_BUFFER_USAGE_TRANSFER_DST_BIT = $00000002;
  VK_SHARING_MODE_EXCLUSIVE = 0;
  VK_IMAGE_LAYOUT_UNDEFINED = 0;
  VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL = 2;
  VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL = 6;
  VK_IMAGE_VIEW_TYPE_2D = 1;
  VK_IMAGE_ASPECT_COLOR_BIT = $00000001;
  VK_PIPELINE_BIND_POINT_GRAPHICS = 0;
  VK_ATTACHMENT_LOAD_OP_CLEAR = 1;
  VK_ATTACHMENT_STORE_OP_STORE = 0;
  VK_ATTACHMENT_LOAD_OP_DONT_CARE = 2;
  VK_ATTACHMENT_STORE_OP_DONT_CARE = 1;
  VK_SHADER_STAGE_VERTEX_BIT = $00000001;
  VK_SHADER_STAGE_FRAGMENT_BIT = $00000010;
  VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST = 3;
  VK_POLYGON_MODE_FILL = 0;
  VK_CULL_MODE_NONE = 0;
  VK_FRONT_FACE_COUNTER_CLOCKWISE = 1;
  VK_COLOR_COMPONENT_R_BIT = $00000001;
  VK_COLOR_COMPONENT_G_BIT = $00000002;
  VK_COLOR_COMPONENT_B_BIT = $00000004;
  VK_COLOR_COMPONENT_A_BIT = $00000008;
  VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT = $00000002;
  VK_COMMAND_BUFFER_LEVEL_PRIMARY = 0;
  VK_FENCE_CREATE_SIGNALED_BIT = $00000001;

var
  gHwnd: HWND = 0;
  gD3DDevice: Pointer = nil;
  gD3DCtx: Pointer = nil;
  gDXGIDevice: Pointer = nil;
  gFactory2: Pointer = nil;
  gSwapGL: Pointer = nil;
  gSwapDX: Pointer = nil;
  gSwapVK: Pointer = nil;
  gBackBufferGL: Pointer = nil;
  gBackBufferDX: Pointer = nil;
  gBackBufferVK: Pointer = nil;
  gStagingVK: Pointer = nil;
  gRTVGL: Pointer = nil;
  gRTVDX: Pointer = nil;
  gVS: Pointer = nil;
  gPS: Pointer = nil;
  gInputLayout: Pointer = nil;
  gVB: Pointer = nil;
  gDCompDevice: Pointer = nil;
  gDCompTarget: Pointer = nil;
  gRootVisual: Pointer = nil;
  gVisualGL: Pointer = nil;
  gVisualDX: Pointer = nil;
  gVisualVK: Pointer = nil;

  gHdc: HDC = 0;
  gHglrc: HGLRC = 0;
  gOpenGL32: HMODULE = 0;
  wglCreateContextAttribsARB: PFNWGLCREATECONTEXTATTRIBSARBPROC = nil;
  wglDXOpenDeviceNV: PFNWGLDXOPENDEVICENVPROC = nil;
  wglDXCloseDeviceNV: PFNWGLDXCLOSEDEVICENVPROC = nil;
  wglDXRegisterObjectNV: PFNWGLDXREGISTEROBJECTNVPROC = nil;
  wglDXUnregisterObjectNV: PFNWGLDXUNREGISTEROBJECTNVPROC = nil;
  wglDXLockObjectsNV: PFNWGLDXLOCKOBJECTSNVPROC = nil;
  wglDXUnlockObjectsNV: PFNWGLDXUNLOCKOBJECTSNVPROC = nil;

  glClear: procedure(mask: Cardinal); stdcall;
  glClearColor: procedure(red, green, blue, alpha: Single); stdcall;
  glDrawArrays: procedure(mode: Cardinal; first, count: Integer); stdcall;
  glViewport: procedure(x, y, width, height: Integer); stdcall;
  glGenBuffers: TglGenBuffers;
  glBindBuffer: TglBindBuffer;
  glBufferData: TglBufferData;
  glCreateShader: TglCreateShader;
  glShaderSource: TglShaderSource;
  glCompileShader: TglCompileShader;
  glCreateProgram: TglCreateProgram;
  glAttachShader: TglAttachShader;
  glLinkProgram: TglLinkProgram;
  glUseProgram: TglUseProgram;
  glGetAttribLocation: TglGetAttribLocation;
  glEnableVertexAttribArray: TglEnableVertexAttribArray;
  glVertexAttribPointer: TglVertexAttribPointer;
  glGenVertexArrays: TglGenVertexArrays;
  glBindVertexArray: TglBindVertexArray;
  glGenFramebuffers: TglGenFramebuffers;
  glBindFramebuffer: TglBindFramebuffer;
  glFramebufferRenderbuffer: TglFramebufferRenderbuffer;
  glGenRenderbuffers: TglGenRenderbuffers;
  glBindRenderbuffer: TglBindRenderbuffer;

  gGLInteropDevice: THandle = 0;
  gGLInteropObject: THandle = 0;
  gGLVBO: array[0..1] of Cardinal = (0, 0);
  gGLVAO: Cardinal = 0;
  gGLProgram: Cardinal = 0;
  gGLRBO: Cardinal = 0;
  gGLFBO: Cardinal = 0;
  gRunning: Boolean = True;
  gRenderGLLogged: Boolean = False;
  gRenderDXLogged: Boolean = False;
  gRenderVKLogged: Boolean = False;

  gVkInstance: VkInstance = nil;
  gVkPhysDev: VkPhysicalDevice = nil;
  gVkDevice: VkDevice = nil;
  gVkQueue: VkQueue = nil;
  gVkCmdPool: VkCommandPool = nil;
  gVkCmdBuf: VkCommandBuffer = nil;
  gVkQFamily: UInt32 = $FFFFFFFF;
  gVkOffImage: VkImage = 0;
  gVkOffView: VkImageView = 0;
  gVkOffMem: VkDeviceMemory = 0;
  gVkReadbackBuf: VkBuffer = 0;
  gVkReadbackMem: VkDeviceMemory = 0;
  gVkRenderPass: VkRenderPass = 0;
  gVkFramebuffer: VkFramebuffer = 0;
  gVkPipelineLayout: VkPipelineLayout = 0;
  gVkPipeline: VkPipeline = 0;
  gVkFence: VkFence = 0;

const
  IID_IDXGIDevice: TGUID = '{54EC77FA-1377-44E6-8C32-88FD5F44C84C}';
  IID_IDXGIFactory2: TGUID = '{50C83A1C-E072-4C48-87B0-3630FA36A6D0}';
  IID_ID3D11Texture2D: TGUID = '{6F15AAF2-D208-4E89-9AB4-489535D34F9C}';
  IID_IDCompositionDevice: TGUID = '{C37EA93A-E7AA-450D-B16F-9746CB0407F3}';

function D3D11CreateDevice(pAdapter: Pointer; DriverType: D3D_DRIVER_TYPE; Software: HMODULE; Flags: UINT; pFeatureLevels: Pointer; FeatureLevels: UINT; SDKVersion: UINT; out ppDevice: Pointer; pFeatureLevel: Pointer; out ppImmediateContext: Pointer): HRESULT; stdcall; external 'd3d11.dll';
function D3DCompile(pSrcData: Pointer; SrcDataSize: SIZE_T; pSourceName: PAnsiChar; pDefines, pInclude: Pointer; pEntrypoint, pTarget: PAnsiChar; Flags1, Flags2: UINT; out ppCode: Pointer; out ppErrorMsgs: Pointer): HRESULT; stdcall; external 'd3dcompiler_47.dll';
function DCompositionCreateDevice(dxgiDevice: Pointer; const iid: TGUID; out dcompositionDevice): HRESULT; stdcall; external 'dcomp.dll';
function vkCreateInstance(const pCreateInfo: TVkInstanceCreateInfo; pAllocator: Pointer; out pInstance: VkInstance): Int32; stdcall; external 'vulkan-1.dll';
function vkEnumeratePhysicalDevices(instance: VkInstance; var pPhysicalDeviceCount: UInt32; pPhysicalDevices: Pointer): Int32; stdcall; external 'vulkan-1.dll';
procedure vkGetPhysicalDeviceQueueFamilyProperties(physicalDevice: VkPhysicalDevice; var pQueueFamilyPropertyCount: UInt32; pQueueFamilyProperties: Pointer); stdcall; external 'vulkan-1.dll';
function vkCreateDevice(physicalDevice: VkPhysicalDevice; const pCreateInfo: TVkDeviceCreateInfo; pAllocator: Pointer; out pDevice: VkDevice): Int32; stdcall; external 'vulkan-1.dll';
procedure vkGetDeviceQueue(device: VkDevice; queueFamilyIndex, queueIndex: UInt32; out pQueue: VkQueue); stdcall; external 'vulkan-1.dll';
procedure vkGetPhysicalDeviceMemoryProperties(physicalDevice: VkPhysicalDevice; out pMemoryProperties: TVkPhysicalDeviceMemoryProperties); stdcall; external 'vulkan-1.dll';
function vkCreateImage(device: VkDevice; const pCreateInfo: TVkImageCreateInfo; pAllocator: Pointer; out pImage: VkImage): Int32; stdcall; external 'vulkan-1.dll';
procedure vkGetImageMemoryRequirements(device: VkDevice; image: VkImage; out pMemoryRequirements: TVkMemoryRequirements); stdcall; external 'vulkan-1.dll';
function vkAllocateMemory(device: VkDevice; const pAllocateInfo: TVkMemoryAllocateInfo; pAllocator: Pointer; out pMemory: VkDeviceMemory): Int32; stdcall; external 'vulkan-1.dll';
function vkBindImageMemory(device: VkDevice; image: VkImage; memory: VkDeviceMemory; memoryOffset: UInt64): Int32; stdcall; external 'vulkan-1.dll';
function vkCreateImageView(device: VkDevice; const pCreateInfo: TVkImageViewCreateInfo; pAllocator: Pointer; out pView: VkImageView): Int32; stdcall; external 'vulkan-1.dll';
function vkCreateBuffer(device: VkDevice; const pCreateInfo: TVkBufferCreateInfo; pAllocator: Pointer; out pBuffer: VkBuffer): Int32; stdcall; external 'vulkan-1.dll';
procedure vkGetBufferMemoryRequirements(device: VkDevice; buffer: VkBuffer; out pMemoryRequirements: TVkMemoryRequirements); stdcall; external 'vulkan-1.dll';
function vkBindBufferMemory(device: VkDevice; buffer: VkBuffer; memory: VkDeviceMemory; memoryOffset: UInt64): Int32; stdcall; external 'vulkan-1.dll';
function vkCreateRenderPass(device: VkDevice; const pCreateInfo: TVkRenderPassCreateInfo; pAllocator: Pointer; out pRenderPass: VkRenderPass): Int32; stdcall; external 'vulkan-1.dll';
function vkCreateFramebuffer(device: VkDevice; const pCreateInfo: TVkFramebufferCreateInfo; pAllocator: Pointer; out pFramebuffer: VkFramebuffer): Int32; stdcall; external 'vulkan-1.dll';
function vkCreateShaderModule(device: VkDevice; const pCreateInfo: TVkShaderModuleCreateInfo; pAllocator: Pointer; out pShaderModule: VkShaderModule): Int32; stdcall; external 'vulkan-1.dll';
procedure vkDestroyShaderModule(device: VkDevice; shaderModule: VkShaderModule; pAllocator: Pointer); stdcall; external 'vulkan-1.dll';
function vkCreatePipelineLayout(device: VkDevice; const pCreateInfo: TVkPipelineLayoutCreateInfo; pAllocator: Pointer; out pPipelineLayout: VkPipelineLayout): Int32; stdcall; external 'vulkan-1.dll';
function vkCreateGraphicsPipelines(device: VkDevice; pipelineCache: UInt64; createInfoCount: UInt32; const pCreateInfos: TVkGraphicsPipelineCreateInfo; pAllocator: Pointer; out pPipelines: VkPipeline): Int32; stdcall; external 'vulkan-1.dll';
function vkCreateCommandPool(device: VkDevice; const pCreateInfo: TVkCommandPoolCreateInfo; pAllocator: Pointer; out pCommandPool: VkCommandPool): Int32; stdcall; external 'vulkan-1.dll';
function vkAllocateCommandBuffers(device: VkDevice; const pAllocateInfo: TVkCommandBufferAllocateInfo; out pCommandBuffer: VkCommandBuffer): Int32; stdcall; external 'vulkan-1.dll';
function vkCreateFence(device: VkDevice; const pCreateInfo: TVkFenceCreateInfo; pAllocator: Pointer; out pFence: VkFence): Int32; stdcall; external 'vulkan-1.dll';
function vkWaitForFences(device: VkDevice; fenceCount: UInt32; pFences: PUInt64; waitAll: UInt32; timeout: UInt64): Int32; stdcall; external 'vulkan-1.dll';
function vkResetFences(device: VkDevice; fenceCount: UInt32; pFences: PUInt64): Int32; stdcall; external 'vulkan-1.dll';
function vkResetCommandBuffer(commandBuffer: VkCommandBuffer; flags: UInt32): Int32; stdcall; external 'vulkan-1.dll';
function vkBeginCommandBuffer(commandBuffer: VkCommandBuffer; const pBeginInfo: TVkCommandBufferBeginInfo): Int32; stdcall; external 'vulkan-1.dll';
function vkEndCommandBuffer(commandBuffer: VkCommandBuffer): Int32; stdcall; external 'vulkan-1.dll';
procedure vkCmdBeginRenderPass(commandBuffer: VkCommandBuffer; const pRenderPassBegin: TVkRenderPassBeginInfo; contents: UInt32); stdcall; external 'vulkan-1.dll';
procedure vkCmdEndRenderPass(commandBuffer: VkCommandBuffer); stdcall; external 'vulkan-1.dll';
procedure vkCmdBindPipeline(commandBuffer: VkCommandBuffer; pipelineBindPoint: UInt32; pipeline: VkPipeline); stdcall; external 'vulkan-1.dll';
procedure vkCmdDraw(commandBuffer: VkCommandBuffer; vertexCount, instanceCount, firstVertex, firstInstance: UInt32); stdcall; external 'vulkan-1.dll';
procedure vkCmdCopyImageToBuffer(commandBuffer: VkCommandBuffer; srcImage: VkImage; srcImageLayout: UInt32; dstBuffer: VkBuffer; regionCount: UInt32; pRegions: PVkBufferImageCopy); stdcall; external 'vulkan-1.dll';
function vkQueueSubmit(queue: VkQueue; submitCount: UInt32; const pSubmits: TVkSubmitInfo; fence: VkFence): Int32; stdcall; external 'vulkan-1.dll';
function vkMapMemory(device: VkDevice; memory: VkDeviceMemory; offset, size: UInt64; flags: UInt32; out ppData: Pointer): Int32; stdcall; external 'vulkan-1.dll';
procedure vkUnmapMemory(device: VkDevice; memory: VkDeviceMemory); stdcall; external 'vulkan-1.dll';
function vkDeviceWaitIdle(device: VkDevice): Int32; stdcall; external 'vulkan-1.dll';

type
  Tshaderc_compiler_initialize = function: Pointer; cdecl;
  Tshaderc_compiler_release = procedure(compiler: Pointer); cdecl;
  Tshaderc_compile_options_initialize = function: Pointer; cdecl;
  Tshaderc_compile_options_release = procedure(options: Pointer); cdecl;
  Tshaderc_compile_options_set_optimization_level = procedure(options: Pointer; level: Integer); cdecl;
  Tshaderc_compile_into_spv = function(compiler: Pointer; source_text: PAnsiChar; source_text_size: NativeUInt; shader_kind: Integer; input_file_name: PAnsiChar; entry_point_name: PAnsiChar; options: Pointer): Pointer; cdecl;
  Tshaderc_result_get_compilation_status = function(result_: Pointer): Integer; cdecl;
  Tshaderc_result_get_length = function(result_: Pointer): NativeUInt; cdecl;
  Tshaderc_result_get_bytes = function(result_: Pointer): Pointer; cdecl;
  Tshaderc_result_get_error_message = function(result_: Pointer): PAnsiChar; cdecl;
  Tshaderc_result_release = procedure(result_: Pointer); cdecl;

var
  gShadercLib: HMODULE = 0;
  p_shaderc_compiler_initialize: Tshaderc_compiler_initialize = nil;
  p_shaderc_compiler_release: Tshaderc_compiler_release = nil;
  p_shaderc_compile_options_initialize: Tshaderc_compile_options_initialize = nil;
  p_shaderc_compile_options_release: Tshaderc_compile_options_release = nil;
  p_shaderc_compile_options_set_optimization_level: Tshaderc_compile_options_set_optimization_level = nil;
  p_shaderc_compile_into_spv: Tshaderc_compile_into_spv = nil;
  p_shaderc_result_get_compilation_status: Tshaderc_result_get_compilation_status = nil;
  p_shaderc_result_get_length: Tshaderc_result_get_length = nil;
  p_shaderc_result_get_bytes: Tshaderc_result_get_bytes = nil;
  p_shaderc_result_get_error_message: Tshaderc_result_get_error_message = nil;
  p_shaderc_result_release: Tshaderc_result_release = nil;

function SUCCEEDED(hr: HRESULT): Boolean; inline;
begin
  Result := hr >= 0;
end;

function HResultFromWin32(err: DWORD): HRESULT; inline;
begin
  if err <= 0 then
    Result := HRESULT(err)
  else
    Result := HRESULT((err and $0000FFFF) or (7 shl 16) or $80000000);
end;

procedure Log(const s: UnicodeString);
begin
  OutputDebugStringW(PWideChar('[Pascal Comp] ' + s + #13#10));
end;

procedure LogStep(const fn, msg: UnicodeString);
begin
  Log(fn + ' | ' + msg);
end;

procedure LogFail(const fn: UnicodeString; hr: HRESULT);
begin
  LogStep(fn, 'fail hr=0x' + IntToHex(Cardinal(hr), 8));
end;

function Slot(obj: Pointer; index: NativeUInt): Pointer; inline;
begin
  Result := PPointer(NativeUInt(PPointer(obj)^) + index * SizeOf(Pointer))^;
end;

procedure SafeRelease(var p: Pointer);
var
  releaseFn: TRelease;
begin
  if p <> nil then
  begin
    releaseFn := TRelease(Slot(p, 2));
    releaseFn(p);
    p := nil;
  end;
end;

function QI(obj: Pointer; const iid: TGUID; out outObj: Pointer): HRESULT;
var
  qiFn: TQueryInterface;
begin
  outObj := nil;
  qiFn := TQueryInterface(Slot(obj, 0));
  Result := qiFn(obj, iid, outObj);
end;

function WndProc(hWnd: HWND; msg: UINT; wParam: WPARAM; lParam: LPARAM): LRESULT; stdcall;
begin
  case msg of
    WM_DESTROY:
      begin
        gRunning := False;
        PostQuitMessage(0);
        Exit(0);
      end;
  end;
  Result := DefWindowProcW(hWnd, msg, wParam, lParam);
end;

function CreateAppWindow(hInst: HINST): HRESULT;
var
  wc: WNDCLASSEXW;
  rc: TRect;
  style: DWORD;
begin
  LogStep('CreateAppWindow', 'begin');
  FillChar(wc, SizeOf(wc), 0);
  wc.cbSize := SizeOf(wc);
  wc.hInstance := hInst;
  wc.lpszClassName := PWideChar(WideString(WINDOW_CLASS_NAME));
  wc.lpfnWndProc := @WndProc;
  wc.hCursor := LoadCursor(0, IDC_ARROW);
  wc.hbrBackground := 0;
  RegisterClassExW(wc);

  style := WS_OVERLAPPEDWINDOW;
  rc.Left := 0; rc.Top := 0; rc.Right := WINDOW_WIDTH; rc.Bottom := PANEL_HEIGHT;
  AdjustWindowRect(rc, style, False);

  gHwnd := CreateWindowExW(
    WS_EX_NOREDIRECTIONBITMAP,
    wc.lpszClassName,
    PWideChar(WideString(WINDOW_TITLE)),
    style,
    CW_USEDEFAULT, CW_USEDEFAULT,
    rc.Right - rc.Left, rc.Bottom - rc.Top,
    0, 0, hInst, nil
  );
  if gHwnd = 0 then
  begin
    Result := HResultFromWin32(GetLastError);
    LogFail('CreateAppWindow', Result);
    Exit;
  end;

  ShowWindow(gHwnd, SW_SHOW);
  UpdateWindow(gHwnd);
  Result := S_OK;
  LogStep('CreateAppWindow', 'ok');
end;

function CreateSwapChain(width, height: UINT; out swap: Pointer; out backBuffer: Pointer; out rtv: Pointer): HRESULT;
var
  desc: DXGI_SWAP_CHAIN_DESC1;
  hr: HRESULT;
  createSwapFn: TCreateSwapChainForComposition;
  getBufFn: TSwapChainGetBuffer;
  createRTVFn: TD3DCreateRTV;
begin
  LogStep('CreateSwapChain', 'begin');
  swap := nil;
  backBuffer := nil;
  rtv := nil;

  if gFactory2 = nil then
  begin
    LogStep('CreateSwapChain', 'gFactory2 is nil');
    Exit(E_POINTER);
  end;
  if gD3DDevice = nil then
  begin
    LogStep('CreateSwapChain', 'gD3DDevice is nil');
    Exit(E_POINTER);
  end;

  FillChar(desc, SizeOf(desc), 0);
  desc.Width := width;
  desc.Height := height;
  desc.Format := DXGI_FORMAT_B8G8R8A8_UNORM;
  desc.SampleDesc.Count := 1;
  desc.BufferUsage := DXGI_USAGE_RENDER_TARGET_OUTPUT;
  desc.BufferCount := 2;
  desc.Scaling := DXGI_SCALING_STRETCH;
  desc.SwapEffect := DXGI_SWAP_EFFECT_FLIP_SEQUENTIAL;
  desc.AlphaMode := DXGI_ALPHA_MODE_PREMULTIPLIED;

  createSwapFn := TCreateSwapChainForComposition(Slot(gFactory2, 24));
  hr := createSwapFn(gFactory2, gD3DDevice, @desc, nil, swap);
  if not SUCCEEDED(hr) then begin LogFail('CreateSwapChain/CreateSwapChainForComposition', hr); Exit(hr); end;

  getBufFn := TSwapChainGetBuffer(Slot(swap, 9));
  hr := getBufFn(swap, 0, IID_ID3D11Texture2D, backBuffer);
  if not SUCCEEDED(hr) then begin LogFail('CreateSwapChain/GetBuffer', hr); Exit(hr); end;

  createRTVFn := TD3DCreateRTV(Slot(gD3DDevice, 9));
  Result := createRTVFn(gD3DDevice, backBuffer, nil, rtv);
  if not SUCCEEDED(Result) then
    LogFail('CreateSwapChain/CreateRenderTargetView', Result)
  else
    LogStep('CreateSwapChain', 'ok');
end;

function CreateStagingTexture(width, height: UINT; out tex: Pointer): HRESULT;
var
  desc: D3D11_TEXTURE2D_DESC;
  createTexFn: TD3DCreateTexture2D;
begin
  tex := nil;
  FillChar(desc, SizeOf(desc), 0);
  desc.Width := width;
  desc.Height := height;
  desc.MipLevels := 1;
  desc.ArraySize := 1;
  desc.Format := DXGI_FORMAT_B8G8R8A8_UNORM;
  desc.SampleDesc.Count := 1;
  desc.Usage := D3D11_USAGE_STAGING;
  desc.CPUAccessFlags := D3D11_CPU_ACCESS_WRITE;
  createTexFn := TD3DCreateTexture2D(Slot(gD3DDevice, 5));
  Result := createTexFn(gD3DDevice, @desc, nil, tex);
end;

function VkOk(r: Int32): Boolean; inline;
begin
  Result := r = VK_SUCCESS;
end;

function FindVkMemoryType(const props: TVkPhysicalDeviceMemoryProperties; typeBits, reqFlags: UInt32): UInt32;
var
  i: UInt32;
begin
  for i := 0 to props.memoryTypeCount - 1 do
  begin
    if ((typeBits and (UInt32(1) shl i)) <> 0) and ((props.memoryTypes[i].propertyFlags and reqFlags) = reqFlags) then
      Exit(i);
  end;
  Result := $FFFFFFFF;
end;

function EnsureShadercLoaded: Boolean;
var
  sdk, p: UnicodeString;
begin
  if gShadercLib <> 0 then
    Exit(True);

  gShadercLib := LoadLibrary('shaderc_shared.dll');
  if gShadercLib = 0 then
  begin
    sdk := GetEnvironmentVariable('VULKAN_SDK');
    if sdk <> '' then
    begin
      p := IncludeTrailingPathDelimiter(sdk) + 'Bin32\shaderc_shared.dll';
      gShadercLib := LoadLibrary(PChar(AnsiString(p)));
      if gShadercLib = 0 then
      begin
        p := IncludeTrailingPathDelimiter(sdk) + 'Bin\shaderc_shared.dll';
        gShadercLib := LoadLibrary(PChar(AnsiString(p)));
      end;
    end;
  end;
  if gShadercLib = 0 then
  begin
    LogStep('EnsureShadercLoaded', 'LoadLibrary(shaderc_shared.dll) failed (checked current dir and VULKAN_SDK\\Bin32/Bin)');
    Exit(False);
  end;

  p_shaderc_compiler_initialize := Tshaderc_compiler_initialize(GetProcAddress(gShadercLib, 'shaderc_compiler_initialize'));
  p_shaderc_compiler_release := Tshaderc_compiler_release(GetProcAddress(gShadercLib, 'shaderc_compiler_release'));
  p_shaderc_compile_options_initialize := Tshaderc_compile_options_initialize(GetProcAddress(gShadercLib, 'shaderc_compile_options_initialize'));
  p_shaderc_compile_options_release := Tshaderc_compile_options_release(GetProcAddress(gShadercLib, 'shaderc_compile_options_release'));
  p_shaderc_compile_options_set_optimization_level := Tshaderc_compile_options_set_optimization_level(GetProcAddress(gShadercLib, 'shaderc_compile_options_set_optimization_level'));
  p_shaderc_compile_into_spv := Tshaderc_compile_into_spv(GetProcAddress(gShadercLib, 'shaderc_compile_into_spv'));
  p_shaderc_result_get_compilation_status := Tshaderc_result_get_compilation_status(GetProcAddress(gShadercLib, 'shaderc_result_get_compilation_status'));
  p_shaderc_result_get_length := Tshaderc_result_get_length(GetProcAddress(gShadercLib, 'shaderc_result_get_length'));
  p_shaderc_result_get_bytes := Tshaderc_result_get_bytes(GetProcAddress(gShadercLib, 'shaderc_result_get_bytes'));
  p_shaderc_result_get_error_message := Tshaderc_result_get_error_message(GetProcAddress(gShadercLib, 'shaderc_result_get_error_message'));
  p_shaderc_result_release := Tshaderc_result_release(GetProcAddress(gShadercLib, 'shaderc_result_release'));

  Result :=
    Assigned(p_shaderc_compiler_initialize) and
    Assigned(p_shaderc_compiler_release) and
    Assigned(p_shaderc_compile_options_initialize) and
    Assigned(p_shaderc_compile_options_release) and
    Assigned(p_shaderc_compile_options_set_optimization_level) and
    Assigned(p_shaderc_compile_into_spv) and
    Assigned(p_shaderc_result_get_compilation_status) and
    Assigned(p_shaderc_result_get_length) and
    Assigned(p_shaderc_result_get_bytes) and
    Assigned(p_shaderc_result_get_error_message) and
    Assigned(p_shaderc_result_release);

  if not Result then
    LogStep('EnsureShadercLoaded', 'GetProcAddress failed for shaderc APIs');
end;

function CompileSpirvFromFile(const fileName: AnsiString; shaderKind: Integer; out bytes: TBytes): Boolean;
var
  sl: TStringList;
  src: AnsiString;
  comp, opts, res: Pointer;
  n: NativeUInt;
  p: Pointer;
begin
  Result := False;
  SetLength(bytes, 0);
  if not EnsureShadercLoaded then
    Exit;
  if not FileExists(string(fileName)) then
  begin
    LogStep('CompileSpirvFromFile', string(fileName) + ' not found');
    Exit;
  end;
  sl := TStringList.Create;
  try
    sl.LoadFromFile(string(fileName));
    src := AnsiString(sl.Text);
  finally
    sl.Free;
  end;

  comp := p_shaderc_compiler_initialize;
  opts := p_shaderc_compile_options_initialize;
  if (comp = nil) or (opts = nil) then
  begin
    LogStep('CompileSpirvFromFile', 'shaderc initialize failed');
    if opts <> nil then p_shaderc_compile_options_release(opts);
    if comp <> nil then p_shaderc_compiler_release(comp);
    Exit;
  end;
  p_shaderc_compile_options_set_optimization_level(opts, 2);
  res := p_shaderc_compile_into_spv(comp, PAnsiChar(src), Length(src), shaderKind, PAnsiChar(fileName), 'main', opts);
  if res = nil then
  begin
    LogStep('CompileSpirvFromFile', 'shaderc returned nil result');
    p_shaderc_compile_options_release(opts);
    p_shaderc_compiler_release(comp);
    Exit;
  end;
  if p_shaderc_result_get_compilation_status(res) <> 0 then
  begin
    LogStep('CompileSpirvFromFile', 'shader compile failed: ' + string(p_shaderc_result_get_error_message(res)));
    p_shaderc_result_release(res);
    p_shaderc_compile_options_release(opts);
    p_shaderc_compiler_release(comp);
    Exit;
  end;
  n := p_shaderc_result_get_length(res);
  SetLength(bytes, n);
  p := p_shaderc_result_get_bytes(res);
  if (n > 0) and (p <> nil) then
    Move(p^, bytes[0], n);
  p_shaderc_result_release(res);
  p_shaderc_compile_options_release(opts);
  p_shaderc_compiler_release(comp);
  Result := True;
end;

function InitD3DAndSwapChains: HRESULT;
var
  hr: HRESULT;
  fl: D3D_FEATURE_LEVEL;
  feat: D3D_FEATURE_LEVEL;
  dxgiAdapter: Pointer;
  dummyRtv: Pointer;
  getAdapterFn: TGetAdapter;
  getParentFn: TGetParent;
begin
  LogStep('InitD3DAndSwapChains', 'begin');
  fl := D3D_FEATURE_LEVEL_11_0;
  hr := D3D11CreateDevice(nil, D3D_DRIVER_TYPE_HARDWARE, 0, D3D11_CREATE_DEVICE_BGRA_SUPPORT, @fl, 1, D3D11_SDK_VERSION, gD3DDevice, @feat, gD3DCtx);
  if not SUCCEEDED(hr) then begin Log('D3D11CreateDevice hr=0x' + IntToHex(Cardinal(hr), 8)); LogFail('InitD3DAndSwapChains', hr); Exit(hr); end;

  hr := QI(gD3DDevice, IID_IDXGIDevice, gDXGIDevice);
  if not SUCCEEDED(hr) then begin Log('QI(IDXGIDevice) hr=0x' + IntToHex(Cardinal(hr), 8)); LogFail('InitD3DAndSwapChains', hr); Exit(hr); end;

  getAdapterFn := TGetAdapter(Slot(gDXGIDevice, 7));
  hr := getAdapterFn(gDXGIDevice, dxgiAdapter);
  if not SUCCEEDED(hr) then begin Log('IDXGIDevice::GetAdapter hr=0x' + IntToHex(Cardinal(hr), 8)); LogFail('InitD3DAndSwapChains', hr); Exit(hr); end;

  getParentFn := TGetParent(Slot(dxgiAdapter, 6));
  hr := getParentFn(dxgiAdapter, IID_IDXGIFactory2, gFactory2);
  SafeRelease(dxgiAdapter);
  if not SUCCEEDED(hr) then begin Log('IDXGIAdapter::GetParent(IDXGIFactory2) hr=0x' + IntToHex(Cardinal(hr), 8)); LogFail('InitD3DAndSwapChains', hr); Exit(hr); end;

  hr := CreateSwapChain(PANEL_WIDTH, PANEL_HEIGHT, gSwapGL, gBackBufferGL, gRTVGL);
  if not SUCCEEDED(hr) then begin Log('CreateSwapChain(GL) hr=0x' + IntToHex(Cardinal(hr), 8)); LogFail('InitD3DAndSwapChains', hr); Exit(hr); end;

  Result := CreateSwapChain(PANEL_WIDTH, PANEL_HEIGHT, gSwapDX, gBackBufferDX, gRTVDX);
  if not SUCCEEDED(Result) then
  begin
    Log('CreateSwapChain(DX) hr=0x' + IntToHex(Cardinal(Result), 8));
    LogFail('InitD3DAndSwapChains', Result);
    Exit;
  end
  else
  begin
    Result := CreateSwapChain(PANEL_WIDTH, PANEL_HEIGHT, gSwapVK, gBackBufferVK, dummyRtv);
    if not SUCCEEDED(Result) then
    begin
      Log('CreateSwapChain(VK) hr=0x' + IntToHex(Cardinal(Result), 8));
      LogFail('InitD3DAndSwapChains', Result);
      Exit;
    end;
    Result := CreateStagingTexture(PANEL_WIDTH, PANEL_HEIGHT, gStagingVK);
    if not SUCCEEDED(Result) then
    begin
      Log('CreateStagingTexture(VK) hr=0x' + IntToHex(Cardinal(Result), 8));
      LogFail('InitD3DAndSwapChains', Result);
      Exit;
    end;
    LogStep('InitD3DAndSwapChains', 'ok');
  end;
end;

function InitDCompTree: HRESULT;
var
  hr: HRESULT;
  createTargetFn: TDCompCreateTargetForHwnd;
  createVisualFn: TDCompCreateVisual;
  setRootFn: TDCompTargetSetRoot;
  setContentFn: TDCompVisualSetContent;
  setOffsetXFn: TDCompVisualSetOffsetX;
  setOffsetYFn: TDCompVisualSetOffsetY;
  addVisualFn: TDCompVisualAddVisual;
  commitFn: TDCompCommit;
begin
  LogStep('InitDCompTree', 'begin');
  hr := DCompositionCreateDevice(gDXGIDevice, IID_IDCompositionDevice, gDCompDevice);
  if not SUCCEEDED(hr) then begin LogFail('InitDCompTree/DCompositionCreateDevice', hr); Exit(hr); end;

  createTargetFn := TDCompCreateTargetForHwnd(Slot(gDCompDevice, 6));
  hr := createTargetFn(gDCompDevice, gHwnd, True, gDCompTarget);
  if not SUCCEEDED(hr) then begin LogFail('InitDCompTree/CreateTargetForHwnd', hr); Exit(hr); end;

  createVisualFn := TDCompCreateVisual(Slot(gDCompDevice, 7));
  hr := createVisualFn(gDCompDevice, gRootVisual); if not SUCCEEDED(hr) then begin LogFail('InitDCompTree/CreateVisual(root)', hr); Exit(hr); end;
  hr := createVisualFn(gDCompDevice, gVisualGL);   if not SUCCEEDED(hr) then begin LogFail('InitDCompTree/CreateVisual(gl)', hr); Exit(hr); end;
  hr := createVisualFn(gDCompDevice, gVisualDX);   if not SUCCEEDED(hr) then begin LogFail('InitDCompTree/CreateVisual(dx)', hr); Exit(hr); end;
  hr := createVisualFn(gDCompDevice, gVisualVK);   if not SUCCEEDED(hr) then begin LogFail('InitDCompTree/CreateVisual(vk)', hr); Exit(hr); end;

  setContentFn := TDCompVisualSetContent(Slot(gVisualGL, 15));
  hr := setContentFn(gVisualGL, gSwapGL); if not SUCCEEDED(hr) then begin LogFail('InitDCompTree/SetContent(gl)', hr); Exit(hr); end;
  setOffsetXFn := TDCompVisualSetOffsetX(Slot(gVisualGL, 4));
  setOffsetYFn := TDCompVisualSetOffsetY(Slot(gVisualGL, 6));
  setOffsetXFn(gVisualGL, 0.0); setOffsetYFn(gVisualGL, 0.0);

  setContentFn := TDCompVisualSetContent(Slot(gVisualDX, 15));
  hr := setContentFn(gVisualDX, gSwapDX); if not SUCCEEDED(hr) then begin LogFail('InitDCompTree/SetContent(dx)', hr); Exit(hr); end;
  setOffsetXFn := TDCompVisualSetOffsetX(Slot(gVisualDX, 4));
  setOffsetYFn := TDCompVisualSetOffsetY(Slot(gVisualDX, 6));
  setOffsetXFn(gVisualDX, PANEL_WIDTH); setOffsetYFn(gVisualDX, 0.0);

  setContentFn := TDCompVisualSetContent(Slot(gVisualVK, 15));
  hr := setContentFn(gVisualVK, gSwapVK); if not SUCCEEDED(hr) then begin LogFail('InitDCompTree/SetContent(vk)', hr); Exit(hr); end;
  setOffsetXFn := TDCompVisualSetOffsetX(Slot(gVisualVK, 4));
  setOffsetYFn := TDCompVisualSetOffsetY(Slot(gVisualVK, 6));
  setOffsetXFn(gVisualVK, PANEL_WIDTH * 2); setOffsetYFn(gVisualVK, 0.0);

  addVisualFn := TDCompVisualAddVisual(Slot(gRootVisual, 16));
  hr := addVisualFn(gRootVisual, gVisualGL, True, nil); if not SUCCEEDED(hr) then begin LogFail('InitDCompTree/AddVisual(gl)', hr); Exit(hr); end;
  hr := addVisualFn(gRootVisual, gVisualDX, True, nil); if not SUCCEEDED(hr) then begin LogFail('InitDCompTree/AddVisual(dx)', hr); Exit(hr); end;
  hr := addVisualFn(gRootVisual, gVisualVK, True, nil); if not SUCCEEDED(hr) then begin LogFail('InitDCompTree/AddVisual(vk)', hr); Exit(hr); end;

  setRootFn := TDCompTargetSetRoot(Slot(gDCompTarget, 3));
  hr := setRootFn(gDCompTarget, gRootVisual); if not SUCCEEDED(hr) then begin LogFail('InitDCompTree/SetRoot', hr); Exit(hr); end;

  commitFn := TDCompCommit(Slot(gDCompDevice, 3));
  Result := commitFn(gDCompDevice);
  if SUCCEEDED(Result) then
    LogStep('InitDCompTree', 'ok')
  else
    LogFail('InitDCompTree/Commit', Result);
end;

function LoadGLProc(const name: PAnsiChar): Pointer;
begin
  Result := wglGetProcAddress(name);
  if (Result = nil) or (NativeUInt(Result) <= 3) then
    Result := GetProcAddress(gOpenGL32, name);
end;

function CompileDXShader(const src, entryName, profileName: AnsiString; out blob: Pointer): HRESULT;
var
  errBlob: Pointer;
begin
  blob := nil;
  errBlob := nil;
  Result := D3DCompile(PAnsiChar(src), Length(src), nil, nil, nil, PAnsiChar(entryName), PAnsiChar(profileName), D3DCOMPILE_ENABLE_STRICTNESS, 0, blob, errBlob);
  if not SUCCEEDED(Result) and (errBlob <> nil) then
  begin
    Log('D3DCompile failed.');
    SafeRelease(errBlob);
  end;
end;
function InitDXPipeline: HRESULT;
var
  hr: HRESULT;
  vsBlob, psBlob: Pointer;
  vsSrc, psSrc: AnsiString;
  inputDesc: array[0..1] of D3D11_INPUT_ELEMENT_DESC;
  vbDesc: D3D11_BUFFER_DESC;
  initData: D3D11_SUBRESOURCE_DATA;
  vertices: array[0..2] of TVertex;
  createVSFn: TD3DCreateVS;
  createPSFn: TD3DCreatePS;
  createLayoutFn: TD3DCreateInputLayout;
  createBufFn: TD3DCreateBuffer;
  blobPtrFn: TBlobGetBufferPointer;
  blobSizeFn: TBlobGetBufferSize;
  pCode: Pointer;
  cbSize: SIZE_T;
begin
  LogStep('InitDXPipeline', 'begin');
  vsSrc := 'struct VSInput { float3 pos:POSITION; float4 col:COLOR; };' +
           'struct VSOutput{ float4 pos:SV_POSITION; float4 col:COLOR; };' +
           'VSOutput main(VSInput i){ VSOutput o; o.pos=float4(i.pos,1); o.col=i.col; return o; }';
  psSrc := 'struct PSInput { float4 pos:SV_POSITION; float4 col:COLOR; };' +
           'float4 main(PSInput i):SV_TARGET{ return i.col; }';

  hr := CompileDXShader(vsSrc, 'main', 'vs_4_0', vsBlob); if not SUCCEEDED(hr) then begin LogFail('InitDXPipeline/CompileVS', hr); Exit(hr); end;
  hr := CompileDXShader(psSrc, 'main', 'ps_4_0', psBlob); if not SUCCEEDED(hr) then begin SafeRelease(vsBlob); LogFail('InitDXPipeline/CompilePS', hr); Exit(hr); end;

  blobPtrFn := TBlobGetBufferPointer(Slot(vsBlob, 3));
  blobSizeFn := TBlobGetBufferSize(Slot(vsBlob, 4));
  pCode := blobPtrFn(vsBlob); cbSize := blobSizeFn(vsBlob);
  createVSFn := TD3DCreateVS(Slot(gD3DDevice, 12));
  hr := createVSFn(gD3DDevice, pCode, cbSize, nil, gVS); if not SUCCEEDED(hr) then begin SafeRelease(vsBlob); SafeRelease(psBlob); LogFail('InitDXPipeline/CreateVS', hr); Exit(hr); end;

  blobPtrFn := TBlobGetBufferPointer(Slot(psBlob, 3));
  blobSizeFn := TBlobGetBufferSize(Slot(psBlob, 4));
  pCode := blobPtrFn(psBlob); cbSize := blobSizeFn(psBlob);
  createPSFn := TD3DCreatePS(Slot(gD3DDevice, 15));
  hr := createPSFn(gD3DDevice, pCode, cbSize, nil, gPS); if not SUCCEEDED(hr) then begin SafeRelease(vsBlob); SafeRelease(psBlob); LogFail('InitDXPipeline/CreatePS', hr); Exit(hr); end;

  inputDesc[0].SemanticName := 'POSITION';
  inputDesc[0].SemanticIndex := 0;
  inputDesc[0].Format := DXGI_FORMAT_R32G32B32_FLOAT;
  inputDesc[0].InputSlot := 0;
  inputDesc[0].AlignedByteOffset := 0;
  inputDesc[0].InputSlotClass := D3D11_INPUT_PER_VERTEX_DATA;
  inputDesc[0].InstanceDataStepRate := 0;
  inputDesc[1].SemanticName := 'COLOR';
  inputDesc[1].SemanticIndex := 0;
  inputDesc[1].Format := DXGI_FORMAT_R32G32B32A32_FLOAT;
  inputDesc[1].InputSlot := 0;
  inputDesc[1].AlignedByteOffset := 12;
  inputDesc[1].InputSlotClass := D3D11_INPUT_PER_VERTEX_DATA;
  inputDesc[1].InstanceDataStepRate := 0;

  blobPtrFn := TBlobGetBufferPointer(Slot(vsBlob, 3));
  blobSizeFn := TBlobGetBufferSize(Slot(vsBlob, 4));
  pCode := blobPtrFn(vsBlob); cbSize := blobSizeFn(vsBlob);
  createLayoutFn := TD3DCreateInputLayout(Slot(gD3DDevice, 11));
  hr := createLayoutFn(gD3DDevice, @inputDesc[0], 2, pCode, cbSize, gInputLayout); if not SUCCEEDED(hr) then begin SafeRelease(vsBlob); SafeRelease(psBlob); LogFail('InitDXPipeline/CreateInputLayout', hr); Exit(hr); end;

  vertices[0].x := 0.0;  vertices[0].y := 0.5;  vertices[0].z := 0.0; vertices[0].r := 1.0; vertices[0].g := 0.0; vertices[0].b := 0.0; vertices[0].a := 1.0;
  vertices[1].x := 0.5;  vertices[1].y := -0.5; vertices[1].z := 0.0; vertices[1].r := 0.0; vertices[1].g := 1.0; vertices[1].b := 0.0; vertices[1].a := 1.0;
  vertices[2].x := -0.5; vertices[2].y := -0.5; vertices[2].z := 0.0; vertices[2].r := 0.0; vertices[2].g := 0.0; vertices[2].b := 1.0; vertices[2].a := 1.0;

  FillChar(vbDesc, SizeOf(vbDesc), 0);
  vbDesc.ByteWidth := SizeOf(vertices);
  vbDesc.Usage := D3D11_USAGE_DEFAULT;
  vbDesc.BindFlags := D3D11_BIND_VERTEX_BUFFER;
  FillChar(initData, SizeOf(initData), 0);
  initData.pSysMem := @vertices[0];

  createBufFn := TD3DCreateBuffer(Slot(gD3DDevice, 3));
  hr := createBufFn(gD3DDevice, vbDesc, @initData, gVB);

  SafeRelease(vsBlob);
  SafeRelease(psBlob);
  Result := hr;
  if not SUCCEEDED(Result) then
    LogFail('InitDXPipeline/CreateBuffer', Result)
  else
    LogStep('InitDXPipeline', 'ok');
end;

function InitOpenGLAndInterop: HRESULT;
var
  pfd: PIXELFORMATDESCRIPTOR;
  iFormat: Integer;
  oldRC: HGLRC;
  attrs: array[0..6] of Integer;
  vertices: array[0..8] of Single;
  colors: array[0..8] of Single;
  vsrc, fsrc: PAnsiChar;
  vs, fs: Cardinal;
  posAttrib, colAttrib: Integer;
begin
  LogStep('InitOpenGLAndInterop', 'begin');
  gOpenGL32 := LoadLibrary('opengl32.dll');
  if gOpenGL32 = 0 then begin Result := HResultFromWin32(GetLastError); LogFail('InitOpenGLAndInterop/LoadLibrary(opengl32)', Result); Exit; end;

  gHdc := GetDC(gHwnd);
  FillChar(pfd, SizeOf(pfd), 0);
  pfd.nSize := SizeOf(pfd);
  pfd.nVersion := 1;
  pfd.dwFlags := PFD_DRAW_TO_WINDOW or PFD_SUPPORT_OPENGL or PFD_DOUBLEBUFFER;
  pfd.iPixelType := PFD_TYPE_RGBA;
  pfd.cColorBits := 24;
  pfd.cDepthBits := 16;
  pfd.iLayerType := PFD_MAIN_PLANE;
  iFormat := ChoosePixelFormat(gHdc, @pfd);
  SetPixelFormat(gHdc, iFormat, @pfd);

  oldRC := wglCreateContext(gHdc);
  wglMakeCurrent(gHdc, oldRC);
  wglCreateContextAttribsARB := PFNWGLCREATECONTEXTATTRIBSARBPROC(LoadGLProc('wglCreateContextAttribsARB'));
  if Assigned(wglCreateContextAttribsARB) then
  begin
    attrs[0] := WGL_CONTEXT_MAJOR_VERSION_ARB; attrs[1] := 4;
    attrs[2] := WGL_CONTEXT_MINOR_VERSION_ARB; attrs[3] := 6;
    attrs[4] := WGL_CONTEXT_PROFILE_MASK_ARB;  attrs[5] := WGL_CONTEXT_CORE_PROFILE_BIT_ARB;
    attrs[6] := 0;
    gHglrc := wglCreateContextAttribsARB(gHdc, 0, @attrs[0]);
  end
  else
    gHglrc := oldRC;

  if (gHglrc <> 0) and (gHglrc <> oldRC) then
  begin
    wglMakeCurrent(0, 0);
    wglDeleteContext(oldRC);
    wglMakeCurrent(gHdc, gHglrc);
  end;

  glClear := GetProcAddress(gOpenGL32, 'glClear');
  glClearColor := GetProcAddress(gOpenGL32, 'glClearColor');
  glDrawArrays := GetProcAddress(gOpenGL32, 'glDrawArrays');
  glViewport := GetProcAddress(gOpenGL32, 'glViewport');
  glGenBuffers := TglGenBuffers(LoadGLProc('glGenBuffers'));
  glBindBuffer := TglBindBuffer(LoadGLProc('glBindBuffer'));
  glBufferData := TglBufferData(LoadGLProc('glBufferData'));
  glCreateShader := TglCreateShader(LoadGLProc('glCreateShader'));
  glShaderSource := TglShaderSource(LoadGLProc('glShaderSource'));
  glCompileShader := TglCompileShader(LoadGLProc('glCompileShader'));
  glCreateProgram := TglCreateProgram(LoadGLProc('glCreateProgram'));
  glAttachShader := TglAttachShader(LoadGLProc('glAttachShader'));
  glLinkProgram := TglLinkProgram(LoadGLProc('glLinkProgram'));
  glUseProgram := TglUseProgram(LoadGLProc('glUseProgram'));
  glGetAttribLocation := TglGetAttribLocation(LoadGLProc('glGetAttribLocation'));
  glEnableVertexAttribArray := TglEnableVertexAttribArray(LoadGLProc('glEnableVertexAttribArray'));
  glVertexAttribPointer := TglVertexAttribPointer(LoadGLProc('glVertexAttribPointer'));
  glGenVertexArrays := TglGenVertexArrays(LoadGLProc('glGenVertexArrays'));
  glBindVertexArray := TglBindVertexArray(LoadGLProc('glBindVertexArray'));
  glGenFramebuffers := TglGenFramebuffers(LoadGLProc('glGenFramebuffers'));
  glBindFramebuffer := TglBindFramebuffer(LoadGLProc('glBindFramebuffer'));
  glFramebufferRenderbuffer := TglFramebufferRenderbuffer(LoadGLProc('glFramebufferRenderbuffer'));
  glGenRenderbuffers := TglGenRenderbuffers(LoadGLProc('glGenRenderbuffers'));
  glBindRenderbuffer := TglBindRenderbuffer(LoadGLProc('glBindRenderbuffer'));

  if (not Assigned(glClear)) or (not Assigned(glClearColor)) or (not Assigned(glDrawArrays)) or
     (not Assigned(glViewport)) or (not Assigned(glCreateShader)) or (not Assigned(glShaderSource)) or
     (not Assigned(glCompileShader)) or (not Assigned(glCreateProgram)) or (not Assigned(glAttachShader)) or
     (not Assigned(glLinkProgram)) or (not Assigned(glUseProgram)) or
     (not Assigned(glGetAttribLocation)) or (not Assigned(glEnableVertexAttribArray)) or
     (not Assigned(glVertexAttribPointer)) or (not Assigned(glGenBuffers)) or
     (not Assigned(glBindBuffer)) or (not Assigned(glBufferData)) or
     (not Assigned(glGenVertexArrays)) or (not Assigned(glBindVertexArray)) or
     (not Assigned(glGenFramebuffers)) or (not Assigned(glBindFramebuffer)) or
     (not Assigned(glFramebufferRenderbuffer)) or (not Assigned(glGenRenderbuffers)) or
     (not Assigned(glBindRenderbuffer)) then
  begin
    LogStep('InitOpenGLAndInterop', 'missing required GL procedures');
    Exit(E_FAIL);
  end;

  wglDXOpenDeviceNV := PFNWGLDXOPENDEVICENVPROC(LoadGLProc('wglDXOpenDeviceNV'));
  wglDXCloseDeviceNV := PFNWGLDXCLOSEDEVICENVPROC(LoadGLProc('wglDXCloseDeviceNV'));
  wglDXRegisterObjectNV := PFNWGLDXREGISTEROBJECTNVPROC(LoadGLProc('wglDXRegisterObjectNV'));
  wglDXUnregisterObjectNV := PFNWGLDXUNREGISTEROBJECTNVPROC(LoadGLProc('wglDXUnregisterObjectNV'));
  wglDXLockObjectsNV := PFNWGLDXLOCKOBJECTSNVPROC(LoadGLProc('wglDXLockObjectsNV'));
  wglDXUnlockObjectsNV := PFNWGLDXUNLOCKOBJECTSNVPROC(LoadGLProc('wglDXUnlockObjectsNV'));
  if not Assigned(wglDXOpenDeviceNV) then begin LogStep('InitOpenGLAndInterop', 'missing wglDXOpenDeviceNV'); Exit(E_FAIL); end;

  gGLInteropDevice := wglDXOpenDeviceNV(gD3DDevice);
  if gGLInteropDevice = 0 then begin LogStep('InitOpenGLAndInterop', 'wglDXOpenDeviceNV failed'); Exit(E_FAIL); end;

  glGenRenderbuffers(1, @gGLRBO);
  glBindRenderbuffer(GL_RENDERBUFFER, gGLRBO);
  gGLInteropObject := wglDXRegisterObjectNV(gGLInteropDevice, gBackBufferGL, gGLRBO, GL_RENDERBUFFER, WGL_ACCESS_READ_WRITE_NV);
  if gGLInteropObject = 0 then begin LogStep('InitOpenGLAndInterop', 'wglDXRegisterObjectNV failed'); Exit(E_FAIL); end;

  glGenFramebuffers(1, @gGLFBO);
  glBindFramebuffer(GL_FRAMEBUFFER, gGLFBO);
  glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, gGLRBO);

  glGenVertexArrays(1, @gGLVAO);
  glBindVertexArray(gGLVAO);
  glGenBuffers(2, @gGLVBO[0]);

  vertices[0] := 0.0; vertices[1] := 0.5; vertices[2] := 0.0;
  vertices[3] := 0.5; vertices[4] := -0.5; vertices[5] := 0.0;
  vertices[6] := -0.5; vertices[7] := -0.5; vertices[8] := 0.0;
  colors[0] := 1.0; colors[1] := 0.0; colors[2] := 0.0;
  colors[3] := 0.0; colors[4] := 1.0; colors[5] := 0.0;
  colors[6] := 0.0; colors[7] := 0.0; colors[8] := 1.0;

  glBindBuffer(GL_ARRAY_BUFFER, gGLVBO[0]);
  glBufferData(GL_ARRAY_BUFFER, SizeOf(vertices), @vertices[0], GL_STATIC_DRAW);
  glBindBuffer(GL_ARRAY_BUFFER, gGLVBO[1]);
  glBufferData(GL_ARRAY_BUFFER, SizeOf(colors), @colors[0], GL_STATIC_DRAW);

  vsrc := '#version 460 core'#10 + 'layout(location=0) in vec3 position;'#10 + 'layout(location=1) in vec3 color;'#10 + 'out vec4 vColor;'#10 + 'void main(){ vColor=vec4(color,1.0); gl_Position=vec4(position.x,-position.y,position.z,1.0); }'#10;
  fsrc := '#version 460 core'#10 + 'in vec4 vColor;'#10 + 'out vec4 outColor;'#10 + 'void main(){ outColor=vColor; }'#10;
  vs := glCreateShader(GL_VERTEX_SHADER); glShaderSource(vs, 1, @vsrc, nil); glCompileShader(vs);
  fs := glCreateShader(GL_FRAGMENT_SHADER); glShaderSource(fs, 1, @fsrc, nil); glCompileShader(fs);
  gGLProgram := glCreateProgram(); glAttachShader(gGLProgram, vs); glAttachShader(gGLProgram, fs); glLinkProgram(gGLProgram); glUseProgram(gGLProgram);
  posAttrib := glGetAttribLocation(gGLProgram, 'position');
  colAttrib := glGetAttribLocation(gGLProgram, 'color');
  glEnableVertexAttribArray(posAttrib); glBindBuffer(GL_ARRAY_BUFFER, gGLVBO[0]); glVertexAttribPointer(posAttrib, 3, GL_FLOAT, GL_FALSE, 0, nil);
  glEnableVertexAttribArray(colAttrib); glBindBuffer(GL_ARRAY_BUFFER, gGLVBO[1]); glVertexAttribPointer(colAttrib, 3, GL_FLOAT, GL_FALSE, 0, nil);

  LogStep('InitOpenGLAndInterop', 'ok');
  Result := S_OK;
end;

function InitVulkanPanel: HRESULT;
var
  r: Int32;
  appName: PAnsiChar;
  appInfo: TVkApplicationInfo;
  instInfo: TVkInstanceCreateInfo;
  devCount: UInt32;
  devs: array of VkPhysicalDevice;
  qCount: UInt32;
  qProps: array of TVkQueueFamilyProperties;
  i: UInt32;
  qprio: Single;
  qci: TVkDeviceQueueCreateInfo;
  dci: TVkDeviceCreateInfo;
  memProps: TVkPhysicalDeviceMemoryProperties;
  imgCI: TVkImageCreateInfo;
  imgReq: TVkMemoryRequirements;
  memAI: TVkMemoryAllocateInfo;
  viewCI: TVkImageViewCreateInfo;
  bufCI: TVkBufferCreateInfo;
  bufReq: TVkMemoryRequirements;
  att: TVkAttachmentDescription;
  attRef: TVkAttachmentReference;
  sub: TVkSubpassDescription;
  rpCI: TVkRenderPassCreateInfo;
  fbCI: TVkFramebufferCreateInfo;
  attachView: VkImageView;
  vsSpv, fsSpv: TBytes;
  smCI: TVkShaderModuleCreateInfo;
  vsMod, fsMod: VkShaderModule;
  stages: array[0..1] of TVkPipelineShaderStageCreateInfo;
  entryName: PAnsiChar;
  vi: TVkPipelineVertexInputStateCreateInfo;
  ia: TVkPipelineInputAssemblyStateCreateInfo;
  vp: TVkViewport;
  sc: TVkRect2D;
  vpState: TVkPipelineViewportStateCreateInfo;
  rs: TVkPipelineRasterizationStateCreateInfo;
  ms: TVkPipelineMultisampleStateCreateInfo;
  cba: TVkPipelineColorBlendAttachmentState;
  cb: TVkPipelineColorBlendStateCreateInfo;
  plCI: TVkPipelineLayoutCreateInfo;
  gpCI: TVkGraphicsPipelineCreateInfo;
  cpCI: TVkCommandPoolCreateInfo;
  cbAI: TVkCommandBufferAllocateInfo;
  fCI: TVkFenceCreateInfo;
begin
  LogStep('InitVulkanPanel', 'begin');
  Result := E_FAIL;
  if (gBackBufferVK = nil) or (gStagingVK = nil) then
  begin
    LogStep('InitVulkanPanel', 'missing D3D resources');
    Exit;
  end;

  FillChar(appInfo, SizeOf(appInfo), 0);
  appInfo.sType := VK_STRUCTURE_TYPE_APPLICATION_INFO;
  appName := 'vk';
  appInfo.pApplicationName := appName;
  appInfo.apiVersion := (1 shl 22);

  FillChar(instInfo, SizeOf(instInfo), 0);
  instInfo.sType := VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO;
  instInfo.pApplicationInfo := @appInfo;
  r := vkCreateInstance(instInfo, nil, gVkInstance);
  if not VkOk(r) then begin LogStep('InitVulkanPanel', 'vkCreateInstance failed'); Exit; end;

  devCount := 0;
  r := vkEnumeratePhysicalDevices(gVkInstance, devCount, nil);
  if (not VkOk(r)) or (devCount = 0) then begin LogStep('InitVulkanPanel', 'no physical device'); Exit; end;
  SetLength(devs, devCount);
  r := vkEnumeratePhysicalDevices(gVkInstance, devCount, @devs[0]);
  if not VkOk(r) then begin LogStep('InitVulkanPanel', 'vkEnumeratePhysicalDevices failed'); Exit; end;
  gVkPhysDev := devs[0];

  qCount := 0;
  vkGetPhysicalDeviceQueueFamilyProperties(gVkPhysDev, qCount, nil);
  SetLength(qProps, qCount);
  if qCount > 0 then
    vkGetPhysicalDeviceQueueFamilyProperties(gVkPhysDev, qCount, @qProps[0]);
  gVkQFamily := $FFFFFFFF;
  for i := 0 to qCount - 1 do
  begin
    if (qProps[i].queueFlags and VK_QUEUE_GRAPHICS_BIT) <> 0 then
    begin
      gVkQFamily := i;
      Break;
    end;
  end;
  if gVkQFamily = $FFFFFFFF then begin LogStep('InitVulkanPanel', 'graphics queue not found'); Exit; end;

  qprio := 1.0;
  FillChar(qci, SizeOf(qci), 0);
  qci.sType := VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO;
  qci.queueFamilyIndex := gVkQFamily;
  qci.queueCount := 1;
  qci.pQueuePriorities := @qprio;

  FillChar(dci, SizeOf(dci), 0);
  dci.sType := VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO;
  dci.queueCreateInfoCount := 1;
  dci.pQueueCreateInfos := @qci;
  r := vkCreateDevice(gVkPhysDev, dci, nil, gVkDevice);
  if not VkOk(r) then begin LogStep('InitVulkanPanel', 'vkCreateDevice failed'); Exit; end;
  vkGetDeviceQueue(gVkDevice, gVkQFamily, 0, gVkQueue);

  vkGetPhysicalDeviceMemoryProperties(gVkPhysDev, memProps);

  FillChar(imgCI, SizeOf(imgCI), 0);
  imgCI.sType := VK_STRUCTURE_TYPE_IMAGE_CREATE_INFO;
  imgCI.imageType := VK_IMAGE_TYPE_2D;
  imgCI.format := VK_FORMAT_B8G8R8A8_UNORM;
  imgCI.extent.width := PANEL_WIDTH;
  imgCI.extent.height := PANEL_HEIGHT;
  imgCI.extent.depth := 1;
  imgCI.mipLevels := 1;
  imgCI.arrayLayers := 1;
  imgCI.samples := VK_SAMPLE_COUNT_1_BIT;
  imgCI.tiling := VK_IMAGE_TILING_OPTIMAL;
  imgCI.usage := VK_IMAGE_USAGE_TRANSFER_SRC_BIT or VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT;
  imgCI.sharingMode := VK_SHARING_MODE_EXCLUSIVE;
  imgCI.initialLayout := VK_IMAGE_LAYOUT_UNDEFINED;
  r := vkCreateImage(gVkDevice, imgCI, nil, gVkOffImage);
  if not VkOk(r) then begin LogStep('InitVulkanPanel', 'vkCreateImage failed'); Exit; end;

  vkGetImageMemoryRequirements(gVkDevice, gVkOffImage, imgReq);
  FillChar(memAI, SizeOf(memAI), 0);
  memAI.sType := VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO;
  memAI.allocationSize := imgReq.size;
  memAI.memoryTypeIndex := FindVkMemoryType(memProps, imgReq.memoryTypeBits, VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT);
  if memAI.memoryTypeIndex = $FFFFFFFF then begin LogStep('InitVulkanPanel', 'image memory type not found'); Exit; end;
  r := vkAllocateMemory(gVkDevice, memAI, nil, gVkOffMem);
  if not VkOk(r) then begin LogStep('InitVulkanPanel', 'vkAllocateMemory(image) failed'); Exit; end;
  r := vkBindImageMemory(gVkDevice, gVkOffImage, gVkOffMem, 0);
  if not VkOk(r) then begin LogStep('InitVulkanPanel', 'vkBindImageMemory failed'); Exit; end;

  FillChar(viewCI, SizeOf(viewCI), 0);
  viewCI.sType := VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO;
  viewCI.image := gVkOffImage;
  viewCI.viewType := VK_IMAGE_VIEW_TYPE_2D;
  viewCI.format := VK_FORMAT_B8G8R8A8_UNORM;
  viewCI.aspectMask := VK_IMAGE_ASPECT_COLOR_BIT;
  viewCI.levelCount := 1;
  viewCI.layerCount := 1;
  r := vkCreateImageView(gVkDevice, viewCI, nil, gVkOffView);
  if not VkOk(r) then begin LogStep('InitVulkanPanel', 'vkCreateImageView failed'); Exit; end;

  FillChar(bufCI, SizeOf(bufCI), 0);
  bufCI.sType := VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO;
  bufCI.size := UInt64(PANEL_WIDTH * PANEL_HEIGHT * 4);
  bufCI.usage := VK_BUFFER_USAGE_TRANSFER_DST_BIT;
  bufCI.sharingMode := VK_SHARING_MODE_EXCLUSIVE;
  r := vkCreateBuffer(gVkDevice, bufCI, nil, gVkReadbackBuf);
  if not VkOk(r) then begin LogStep('InitVulkanPanel', 'vkCreateBuffer failed'); Exit; end;
  vkGetBufferMemoryRequirements(gVkDevice, gVkReadbackBuf, bufReq);
  FillChar(memAI, SizeOf(memAI), 0);
  memAI.sType := VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO;
  memAI.allocationSize := bufReq.size;
  memAI.memoryTypeIndex := FindVkMemoryType(memProps, bufReq.memoryTypeBits, VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT or VK_MEMORY_PROPERTY_HOST_COHERENT_BIT);
  if memAI.memoryTypeIndex = $FFFFFFFF then begin LogStep('InitVulkanPanel', 'buffer memory type not found'); Exit; end;
  r := vkAllocateMemory(gVkDevice, memAI, nil, gVkReadbackMem);
  if not VkOk(r) then begin LogStep('InitVulkanPanel', 'vkAllocateMemory(buffer) failed'); Exit; end;
  r := vkBindBufferMemory(gVkDevice, gVkReadbackBuf, gVkReadbackMem, 0);
  if not VkOk(r) then begin LogStep('InitVulkanPanel', 'vkBindBufferMemory failed'); Exit; end;

  FillChar(att, SizeOf(att), 0);
  att.format := VK_FORMAT_B8G8R8A8_UNORM;
  att.samples := VK_SAMPLE_COUNT_1_BIT;
  att.loadOp := VK_ATTACHMENT_LOAD_OP_CLEAR;
  att.storeOp := VK_ATTACHMENT_STORE_OP_STORE;
  att.stencilLoadOp := VK_ATTACHMENT_LOAD_OP_DONT_CARE;
  att.stencilStoreOp := VK_ATTACHMENT_STORE_OP_DONT_CARE;
  att.finalLayout := VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL;
  attRef.attachment := 0;
  attRef.layout := VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL;
  FillChar(sub, SizeOf(sub), 0);
  sub.pipelineBindPoint := VK_PIPELINE_BIND_POINT_GRAPHICS;
  sub.colorAttachmentCount := 1;
  sub.pColorAttachments := @attRef;
  FillChar(rpCI, SizeOf(rpCI), 0);
  rpCI.sType := VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO;
  rpCI.attachmentCount := 1;
  rpCI.pAttachments := @att;
  rpCI.subpassCount := 1;
  rpCI.pSubpasses := @sub;
  r := vkCreateRenderPass(gVkDevice, rpCI, nil, gVkRenderPass);
  if not VkOk(r) then begin LogStep('InitVulkanPanel', 'vkCreateRenderPass failed'); Exit; end;

  attachView := gVkOffView;
  FillChar(fbCI, SizeOf(fbCI), 0);
  fbCI.sType := VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO;
  fbCI.renderPass := gVkRenderPass;
  fbCI.attachmentCount := 1;
  fbCI.pAttachments := @attachView;
  fbCI.width := PANEL_WIDTH;
  fbCI.height := PANEL_HEIGHT;
  fbCI.layers := 1;
  r := vkCreateFramebuffer(gVkDevice, fbCI, nil, gVkFramebuffer);
  if not VkOk(r) then begin LogStep('InitVulkanPanel', 'vkCreateFramebuffer failed'); Exit; end;

  if not CompileSpirvFromFile('hello.vert', 0, vsSpv) then Exit;
  if not CompileSpirvFromFile('hello.frag', 1, fsSpv) then Exit;

  FillChar(smCI, SizeOf(smCI), 0);
  smCI.sType := VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO;
  smCI.codeSize := Length(vsSpv);
  smCI.pCode := @vsSpv[0];
  r := vkCreateShaderModule(gVkDevice, smCI, nil, vsMod);
  if not VkOk(r) then begin LogStep('InitVulkanPanel', 'vkCreateShaderModule(vs) failed'); Exit; end;
  smCI.codeSize := Length(fsSpv);
  smCI.pCode := @fsSpv[0];
  r := vkCreateShaderModule(gVkDevice, smCI, nil, fsMod);
  if not VkOk(r) then begin LogStep('InitVulkanPanel', 'vkCreateShaderModule(fs) failed'); Exit; end;

  entryName := 'main';
  FillChar(stages, SizeOf(stages), 0);
  stages[0].sType := VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO;
  stages[0].stage := VK_SHADER_STAGE_VERTEX_BIT;
  stages[0].module_ := vsMod;
  stages[0].pName := entryName;
  stages[1].sType := VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO;
  stages[1].stage := VK_SHADER_STAGE_FRAGMENT_BIT;
  stages[1].module_ := fsMod;
  stages[1].pName := entryName;

  FillChar(vi, SizeOf(vi), 0);
  vi.sType := VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO;
  FillChar(ia, SizeOf(ia), 0);
  ia.sType := VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO;
  ia.topology := VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST;
  FillChar(vp, SizeOf(vp), 0);
  vp.width := PANEL_WIDTH;
  vp.height := PANEL_HEIGHT;
  vp.maxDepth := 1.0;
  FillChar(sc, SizeOf(sc), 0);
  sc.extent.width := PANEL_WIDTH;
  sc.extent.height := PANEL_HEIGHT;
  FillChar(vpState, SizeOf(vpState), 0);
  vpState.sType := VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO;
  vpState.viewportCount := 1;
  vpState.pViewports := @vp;
  vpState.scissorCount := 1;
  vpState.pScissors := @sc;
  FillChar(rs, SizeOf(rs), 0);
  rs.sType := VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO;
  rs.polygonMode := VK_POLYGON_MODE_FILL;
  rs.cullMode := VK_CULL_MODE_NONE;
  rs.frontFace := VK_FRONT_FACE_COUNTER_CLOCKWISE;
  rs.lineWidth := 1.0;
  FillChar(ms, SizeOf(ms), 0);
  ms.sType := VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO;
  ms.rasterizationSamples := VK_SAMPLE_COUNT_1_BIT;
  FillChar(cba, SizeOf(cba), 0);
  cba.colorWriteMask := VK_COLOR_COMPONENT_R_BIT or VK_COLOR_COMPONENT_G_BIT or VK_COLOR_COMPONENT_B_BIT or VK_COLOR_COMPONENT_A_BIT;
  FillChar(cb, SizeOf(cb), 0);
  cb.sType := VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO;
  cb.attachmentCount := 1;
  cb.pAttachments := @cba;
  FillChar(plCI, SizeOf(plCI), 0);
  plCI.sType := VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO;
  r := vkCreatePipelineLayout(gVkDevice, plCI, nil, gVkPipelineLayout);
  if not VkOk(r) then begin LogStep('InitVulkanPanel', 'vkCreatePipelineLayout failed'); Exit; end;

  FillChar(gpCI, SizeOf(gpCI), 0);
  gpCI.sType := VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO;
  gpCI.stageCount := 2;
  gpCI.pStages := @stages[0];
  gpCI.pVertexInputState := @vi;
  gpCI.pInputAssemblyState := @ia;
  gpCI.pViewportState := @vpState;
  gpCI.pRasterizationState := @rs;
  gpCI.pMultisampleState := @ms;
  gpCI.pColorBlendState := @cb;
  gpCI.layout := gVkPipelineLayout;
  gpCI.renderPass := gVkRenderPass;
  r := vkCreateGraphicsPipelines(gVkDevice, 0, 1, gpCI, nil, gVkPipeline);
  vkDestroyShaderModule(gVkDevice, vsMod, nil);
  vkDestroyShaderModule(gVkDevice, fsMod, nil);
  if not VkOk(r) then begin LogStep('InitVulkanPanel', 'vkCreateGraphicsPipelines failed'); Exit; end;

  FillChar(cpCI, SizeOf(cpCI), 0);
  cpCI.sType := VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO;
  cpCI.flags := VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT;
  cpCI.queueFamilyIndex := gVkQFamily;
  r := vkCreateCommandPool(gVkDevice, cpCI, nil, gVkCmdPool);
  if not VkOk(r) then begin LogStep('InitVulkanPanel', 'vkCreateCommandPool failed'); Exit; end;

  FillChar(cbAI, SizeOf(cbAI), 0);
  cbAI.sType := VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO;
  cbAI.commandPool := gVkCmdPool;
  cbAI.level := VK_COMMAND_BUFFER_LEVEL_PRIMARY;
  cbAI.commandBufferCount := 1;
  r := vkAllocateCommandBuffers(gVkDevice, cbAI, gVkCmdBuf);
  if not VkOk(r) then begin LogStep('InitVulkanPanel', 'vkAllocateCommandBuffers failed'); Exit; end;

  FillChar(fCI, SizeOf(fCI), 0);
  fCI.sType := VK_STRUCTURE_TYPE_FENCE_CREATE_INFO;
  fCI.flags := VK_FENCE_CREATE_SIGNALED_BIT;
  r := vkCreateFence(gVkDevice, fCI, nil, gVkFence);
  if not VkOk(r) then begin LogStep('InitVulkanPanel', 'vkCreateFence failed'); Exit; end;

  Result := S_OK;
  LogStep('InitVulkanPanel', 'ok');
end;

procedure RenderVulkan;
var
  fn: UInt64;
  bi: TVkCommandBufferBeginInfo;
  cv: TVkClearValue;
  rpbi: TVkRenderPassBeginInfo;
  rg: TVkBufferImageCopy;
  si: TVkSubmitInfo;
  srcData: Pointer;
  mapped: D3D11_MAPPED_SUBRESOURCE;
  ctxMap: TCtxMap;
  ctxUnmap: TCtxUnmap;
  ctxCopy: TCtxCopyResource;
  presentFn: TSwapChainPresent;
  y, pitch: Integer;
begin
  if not gRenderVKLogged then
  begin
    LogStep('RenderVulkan', 'begin');
    gRenderVKLogged := True;
  end;
  fn := gVkFence;
  vkWaitForFences(gVkDevice, 1, @fn, 1, High(UInt64));
  vkResetFences(gVkDevice, 1, @fn);
  vkResetCommandBuffer(gVkCmdBuf, 0);

  FillChar(bi, SizeOf(bi), 0);
  bi.sType := VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO;
  vkBeginCommandBuffer(gVkCmdBuf, bi);

  cv.color[0] := 0.15; cv.color[1] := 0.05; cv.color[2] := 0.05; cv.color[3] := 1.0;
  FillChar(rpbi, SizeOf(rpbi), 0);
  rpbi.sType := VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO;
  rpbi.renderPass := gVkRenderPass;
  rpbi.framebuffer := gVkFramebuffer;
  rpbi.renderArea.extent.width := PANEL_WIDTH;
  rpbi.renderArea.extent.height := PANEL_HEIGHT;
  rpbi.clearValueCount := 1;
  rpbi.pClearValues := @cv;
  vkCmdBeginRenderPass(gVkCmdBuf, rpbi, 0);
  vkCmdBindPipeline(gVkCmdBuf, VK_PIPELINE_BIND_POINT_GRAPHICS, gVkPipeline);
  vkCmdDraw(gVkCmdBuf, 3, 1, 0, 0);
  vkCmdEndRenderPass(gVkCmdBuf);

  FillChar(rg, SizeOf(rg), 0);
  rg.bufferRowLength := PANEL_WIDTH;
  rg.bufferImageHeight := PANEL_HEIGHT;
  rg.imageSubresourceAspectMask := VK_IMAGE_ASPECT_COLOR_BIT;
  rg.imageSubresourceLayerCount := 1;
  rg.imageExtentWidth := PANEL_WIDTH;
  rg.imageExtentHeight := PANEL_HEIGHT;
  rg.imageExtentDepth := 1;
  vkCmdCopyImageToBuffer(gVkCmdBuf, gVkOffImage, VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL, gVkReadbackBuf, 1, @rg);
  vkEndCommandBuffer(gVkCmdBuf);

  FillChar(si, SizeOf(si), 0);
  si.sType := VK_STRUCTURE_TYPE_SUBMIT_INFO;
  si.commandBufferCount := 1;
  si.pCommandBuffers := @gVkCmdBuf;
  vkQueueSubmit(gVkQueue, 1, si, gVkFence);
  vkWaitForFences(gVkDevice, 1, @fn, 1, High(UInt64));

  vkMapMemory(gVkDevice, gVkReadbackMem, 0, UInt64(PANEL_WIDTH * PANEL_HEIGHT * 4), 0, srcData);
  ctxMap := TCtxMap(Slot(gD3DCtx, 14));
  ctxUnmap := TCtxUnmap(Slot(gD3DCtx, 15));
  ctxCopy := TCtxCopyResource(Slot(gD3DCtx, 47));
  if SUCCEEDED(ctxMap(gD3DCtx, gStagingVK, 0, D3D11_MAP_WRITE, 0, mapped)) then
  begin
    pitch := PANEL_WIDTH * 4;
    for y := 0 to PANEL_HEIGHT - 1 do
      Move(PByte(NativeUInt(srcData) + NativeUInt(y * pitch))^, PByte(NativeUInt(mapped.pData) + NativeUInt(y * mapped.RowPitch))^, pitch);
    ctxUnmap(gD3DCtx, gStagingVK, 0);
    vkUnmapMemory(gVkDevice, gVkReadbackMem);
    ctxCopy(gD3DCtx, gBackBufferVK, gStagingVK);
    presentFn := TSwapChainPresent(Slot(gSwapVK, 8));
    presentFn(gSwapVK, 1, 0);
  end
  else
    LogStep('RenderVulkan', 'D3D map failed');
end;
procedure RenderGL;
var
  presentFn: TSwapChainPresent;
  lockObj: THandle;
begin
  if not gRenderGLLogged then
  begin
    LogStep('RenderGL', 'begin');
    gRenderGLLogged := True;
  end;
  lockObj := gGLInteropObject;
  if Assigned(wglDXLockObjectsNV) then wglDXLockObjectsNV(gGLInteropDevice, 1, @lockObj);
  glBindFramebuffer(GL_FRAMEBUFFER, gGLFBO);
  glViewport(0, 0, PANEL_WIDTH, PANEL_HEIGHT);
  glClearColor(0.1, 0.1, 0.1, 1.0);
  glClear(GL_COLOR_BUFFER_BIT);
  glUseProgram(gGLProgram);
  glBindVertexArray(gGLVAO);
  glDrawArrays(GL_TRIANGLES, 0, 3);
  if Assigned(wglDXUnlockObjectsNV) then wglDXUnlockObjectsNV(gGLInteropDevice, 1, @lockObj);
  presentFn := TSwapChainPresent(Slot(gSwapGL, 8));
  if not SUCCEEDED(presentFn(gSwapGL, 1, 0)) then
    LogStep('RenderGL', 'present failed');
end;

procedure RenderDX;
var
  clear: array[0..3] of Single;
  vp: D3D11_VIEWPORT;
  stride, offset: UINT;
  ctxOMSetRT: TCtxOMSetRenderTargets;
  ctxRSSetVP: TCtxRSSetViewports;
  ctxClearRT: TCtxClearRTV;
  ctxIASetLayout: TCtxIASetInputLayout;
  ctxIASetVB: TCtxIASetVertexBuffers;
  ctxIASetTopo: TCtxIASetPrimitiveTopology;
  ctxVSSet: TCtxVSSetShader;
  ctxPSSet: TCtxPSSetShader;
  ctxDraw: TCtxDraw;
  presentFn: TSwapChainPresent;
  rtvPtr: Pointer;
  vbPtr: Pointer;
begin
  if not gRenderDXLogged then
  begin
    LogStep('RenderDX', 'begin');
    gRenderDXLogged := True;
  end;
  clear[0] := 0.1; clear[1] := 0.1; clear[2] := 0.1; clear[3] := 1.0;
  FillChar(vp, SizeOf(vp), 0);
  vp.Width := PANEL_WIDTH; vp.Height := PANEL_HEIGHT; vp.MinDepth := 0.0; vp.MaxDepth := 1.0;
  stride := SizeOf(TVertex); offset := 0;

  ctxOMSetRT := TCtxOMSetRenderTargets(Slot(gD3DCtx, 33));
  ctxRSSetVP := TCtxRSSetViewports(Slot(gD3DCtx, 44));
  ctxClearRT := TCtxClearRTV(Slot(gD3DCtx, 50));
  ctxIASetLayout := TCtxIASetInputLayout(Slot(gD3DCtx, 17));
  ctxIASetVB := TCtxIASetVertexBuffers(Slot(gD3DCtx, 18));
  ctxIASetTopo := TCtxIASetPrimitiveTopology(Slot(gD3DCtx, 24));
  ctxVSSet := TCtxVSSetShader(Slot(gD3DCtx, 11));
  ctxPSSet := TCtxPSSetShader(Slot(gD3DCtx, 9));
  ctxDraw := TCtxDraw(Slot(gD3DCtx, 13));

  rtvPtr := gRTVDX;
  ctxOMSetRT(gD3DCtx, 1, @rtvPtr, nil);
  ctxRSSetVP(gD3DCtx, 1, @vp);
  ctxClearRT(gD3DCtx, gRTVDX, @clear[0]);
  ctxIASetLayout(gD3DCtx, gInputLayout);
  vbPtr := gVB;
  ctxIASetVB(gD3DCtx, 0, 1, @vbPtr, @stride, @offset);
  ctxIASetTopo(gD3DCtx, D3D11_PRIMITIVE_TOPOLOGY_TRIANGLELIST);
  ctxVSSet(gD3DCtx, gVS, nil, 0);
  ctxPSSet(gD3DCtx, gPS, nil, 0);
  ctxDraw(gD3DCtx, 3, 0);

  presentFn := TSwapChainPresent(Slot(gSwapDX, 8));
  if not SUCCEEDED(presentFn(gSwapDX, 1, 0)) then
    LogStep('RenderDX', 'present failed');
end;

procedure Cleanup;
begin
  if gVkDevice <> nil then
    vkDeviceWaitIdle(gVkDevice);

  if gShadercLib <> 0 then
  begin
    FreeLibrary(gShadercLib);
    gShadercLib := 0;
  end;

  if (gGLInteropObject <> 0) and Assigned(wglDXUnregisterObjectNV) then wglDXUnregisterObjectNV(gGLInteropDevice, gGLInteropObject);
  if (gGLInteropDevice <> 0) and Assigned(wglDXCloseDeviceNV) then wglDXCloseDeviceNV(gGLInteropDevice);
  gGLInteropObject := 0; gGLInteropDevice := 0;

  if gHglrc <> 0 then begin wglMakeCurrent(0, 0); wglDeleteContext(gHglrc); gHglrc := 0; end;
  if gHdc <> 0 then begin ReleaseDC(gHwnd, gHdc); gHdc := 0; end;
  if gOpenGL32 <> 0 then begin FreeLibrary(gOpenGL32); gOpenGL32 := 0; end;

  SafeRelease(gVisualVK); SafeRelease(gVisualDX); SafeRelease(gVisualGL); SafeRelease(gRootVisual); SafeRelease(gDCompTarget); SafeRelease(gDCompDevice);
  SafeRelease(gVB); SafeRelease(gInputLayout); SafeRelease(gPS); SafeRelease(gVS);
  SafeRelease(gRTVDX); SafeRelease(gRTVGL); SafeRelease(gBackBufferVK); SafeRelease(gBackBufferDX); SafeRelease(gBackBufferGL); SafeRelease(gStagingVK); SafeRelease(gSwapVK); SafeRelease(gSwapDX); SafeRelease(gSwapGL);
  SafeRelease(gFactory2); SafeRelease(gDXGIDevice); SafeRelease(gD3DCtx); SafeRelease(gD3DDevice);
  CoUninitialize;
end;

function Run: Integer;
var
  hr: HRESULT;
  msg: TMsg;
begin
  Result := 1;
  LogStep('Run', 'begin');
  hr := CoInitializeEx(nil, COINIT_APARTMENTTHREADED);
  if not SUCCEEDED(hr) then begin Log('CoInitializeEx failed.'); Exit; end;
  LogStep('Run', 'CoInitializeEx ok');
  hr := CreateAppWindow(HInstance);
  if not SUCCEEDED(hr) then begin Log('CreateAppWindow failed.'); Exit; end;
  LogStep('Run', 'CreateAppWindow ok');
  hr := InitD3DAndSwapChains;
  if not SUCCEEDED(hr) then begin Log('InitD3DAndSwapChains failed hr=0x' + IntToHex(Cardinal(hr), 8)); Exit; end;
  LogStep('Run', 'InitD3DAndSwapChains ok');
  hr := InitDXPipeline;
  if not SUCCEEDED(hr) then begin Log('InitDXPipeline failed.'); Exit; end;
  LogStep('Run', 'InitDXPipeline ok');
  hr := InitOpenGLAndInterop;
  if not SUCCEEDED(hr) then begin Log('InitOpenGLAndInterop failed.'); Exit; end;
  LogStep('Run', 'InitOpenGLAndInterop ok');
  hr := InitVulkanPanel;
  if not SUCCEEDED(hr) then begin Log('InitVulkanPanel failed.'); Exit; end;
  LogStep('Run', 'InitVulkanPanel ok');
  hr := InitDCompTree;
  if not SUCCEEDED(hr) then begin Log('InitDCompTree failed.'); Exit; end;
  LogStep('Run', 'InitDCompTree ok');

  while gRunning do
  begin
    while PeekMessage(msg, 0, 0, 0, PM_REMOVE) do
    begin
      if msg.message = WM_QUIT then begin gRunning := False; Break; end;
      TranslateMessage(msg);
      DispatchMessage(msg);
    end;
    if not gRunning then Break;
    RenderGL;
    RenderDX;
    RenderVulkan;
    Sleep(1);
  end;
  Result := 0;
end;

begin
  try
    try
      Halt(Run);
    except
      on E: Exception do
      begin
        Log('Unhandled exception: ' + E.ClassName + ' | ' + E.Message);
        if ExceptAddr <> nil then
          Log('Exception address: 0x' + IntToHex(NativeUInt(ExceptAddr), SizeOf(Pointer) * 2));
        Halt(1);
      end;
    end;
  finally
    Cleanup;
  end;
end.
