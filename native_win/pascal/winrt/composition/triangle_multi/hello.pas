program hello;

(*
 * hello.pas
 *
 * Win32 window + OpenGL 4.6 + D3D11 + Vulkan triangles composited via
 * Windows.UI.Composition (WinRT Composition API) on a classic desktop app.
 *
 * Pure Free Pascal using raw COM/WinRT vtable calls via function pointer
 * casts and direct DLL imports — no external binding units required beyond
 * the standard Windows unit.
 *
 * Architecture:
 *   - Three DXGI swap chains (CreateSwapChainForComposition)
 *   - Left panel  (  0px): OpenGL 4.6 via WGL_NV_DX_interop -> D3D11 back buffer
 *   - Center panel (320px): Direct D3D11 rendering with HLSL shaders
 *   - Right panel  (640px): Vulkan offscreen -> readback -> D3D11 staging copy
 *   - Windows.UI.Composition visual tree:
 *       Compositor -> DesktopWindowTarget -> ContainerVisual (root)
 *         -> 3 SpriteVisuals with SurfaceBrushes wrapping swap chains
 *
 * Build (Free Pascal x86_64):
 *   fpc -Twin64 -O2 hello.pas
 *
 * Requirements:
 *   - NVIDIA GPU (for WGL_NV_DX_interop)
 *   - Vulkan SDK installed (vulkan-1.dll)
 *   - hello_vert.spv and hello_frag.spv in working directory
 *
 * SPIR-V compilation:
 *   glslc hello.vert -o hello_vert.spv
 *   glslc hello.frag -o hello_frag.spv
 *)

{$mode delphi}
{$apptype gui}
{$packrecords C}

uses
  Windows, SysUtils, ActiveX;

(* ============================================================
 * Constants
 * ============================================================ *)
const
  PANEL_W     = 320;
  PANEL_H     = 480;
  WINDOW_W    = PANEL_W * 3;
  VERTEX_SIZE = 7 * 4; { 3 pos + 4 color floats = 28 bytes }

  { Win32 }
  WS_EX_NOREDIRECTIONBITMAP = $00200000;

  { DXGI / D3D11 }
  D3D_DRIVER_TYPE_HARDWARE         = 1;
  D3D11_SDK_VERSION                = 7;
  D3D11_CREATE_DEVICE_BGRA_SUPPORT = $20;
  D3D_FEATURE_LEVEL_11_0           = $b000;
  DXGI_FORMAT_B8G8R8A8_UNORM       = 87;
  DXGI_FORMAT_R32G32B32_FLOAT      = 6;
  DXGI_FORMAT_R32G32B32A32_FLOAT   = 2;
  DXGI_USAGE_RENDER_TARGET_OUTPUT  = $20;
  DXGI_SCALING_STRETCH             = 0;
  DXGI_SWAP_EFFECT_FLIP_SEQUENTIAL = 3;
  DXGI_ALPHA_MODE_PREMULTIPLIED    = 1;
  D3D11_BIND_VERTEX_BUFFER         = $1;
  D3D11_USAGE_DEFAULT              = 0;
  D3D11_USAGE_STAGING              = 3;
  D3D11_CPU_ACCESS_WRITE           = $10000;
  D3D11_PRIMITIVE_TOPOLOGY_TRIANGLELIST = 4;
  D3D11_MAP_WRITE                  = 2;
  D3DCOMPILE_ENABLE_STRICTNESS     = $800;

  { OpenGL }
  GL_TRIANGLES            = $0004;
  GL_FLOAT                = $1406;
  GL_FALSE                = 0;
  GL_COLOR_BUFFER_BIT     = $4000;
  GL_ARRAY_BUFFER         = $8892;
  GL_STATIC_DRAW          = $88E4;
  GL_FRAGMENT_SHADER      = $8B30;
  GL_VERTEX_SHADER        = $8B31;
  GL_FRAMEBUFFER          = $8D40;
  GL_RENDERBUFFER         = $8D41;
  GL_COLOR_ATTACHMENT0    = $8CE0;
  GL_FRAMEBUFFER_COMPLETE = $8CD5;
  GL_COMPILE_STATUS       = $8B81;
  GL_LINK_STATUS          = $8B82;
  WGL_CONTEXT_MAJOR_VERSION_ARB    = $2091;
  WGL_CONTEXT_MINOR_VERSION_ARB    = $2092;
  WGL_CONTEXT_FLAGS_ARB            = $2094;
  WGL_CONTEXT_PROFILE_MASK_ARB     = $9126;
  WGL_CONTEXT_CORE_PROFILE_BIT_ARB = $01;
  WGL_ACCESS_READ_WRITE_NV         = $01;
  PFD_DRAW_TO_WINDOW = $4;
  PFD_SUPPORT_OPENGL = $20;
  PFD_DOUBLEBUFFER   = $1;

  { Vulkan structure types }
  VK_STRUCTURE_TYPE_APPLICATION_INFO                  = 0;
  VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO              = 1;
  VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO          = 2;
  VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO                = 3;
  VK_STRUCTURE_TYPE_SUBMIT_INFO                       = 4;
  VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO              = 5;
  VK_STRUCTURE_TYPE_FENCE_CREATE_INFO                 = 8;
  VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO                = 12;
  VK_STRUCTURE_TYPE_IMAGE_CREATE_INFO                 = 14;
  VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO            = 15;
  VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO         = 16;
  VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO = 18;
  VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO  = 19;
  VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO = 20;
  VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO       = 22;
  VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO  = 23;
  VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO    = 24;
  VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO    = 26;
  VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO    = 28;
  VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO      = 30;
  VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO          = 37;
  VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO          = 38;
  VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO          = 39;
  VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO      = 40;
  VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO         = 42;
  VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO            = 43;

  { Vulkan miscellaneous }
  VK_SUCCESS = 0;
  VK_IMAGE_TYPE_2D           = 1;
  VK_FORMAT_B8G8R8A8_UNORM   = 44;
  VK_SAMPLE_COUNT_1_BIT      = 1;
  VK_IMAGE_TILING_OPTIMAL    = 0;
  VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT = $10;
  VK_IMAGE_USAGE_TRANSFER_SRC_BIT    = $1;
  VK_IMAGE_LAYOUT_UNDEFINED              = 0;
  VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL = 2;
  VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL    = 6;
  VK_IMAGE_VIEW_TYPE_2D      = 1;
  VK_IMAGE_ASPECT_COLOR_BIT  = $1;
  VK_BUFFER_USAGE_TRANSFER_DST_BIT = $2;
  VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT  = $1;
  VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT  = $2;
  VK_MEMORY_PROPERTY_HOST_COHERENT_BIT = $4;
  VK_ATTACHMENT_LOAD_OP_CLEAR     = 1;
  VK_ATTACHMENT_STORE_OP_STORE    = 0;
  VK_ATTACHMENT_LOAD_OP_DONT_CARE = 2;
  VK_ATTACHMENT_STORE_OP_DONT_CARE = 1;
  VK_PIPELINE_BIND_POINT_GRAPHICS = 0;
  VK_SUBPASS_CONTENTS_INLINE = 0;
  VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST = 3;
  VK_POLYGON_MODE_FILL       = 0;
  VK_CULL_MODE_BACK_BIT      = 2;
  VK_FRONT_FACE_CLOCKWISE    = 1;
  VK_SHADER_STAGE_VERTEX_BIT   = $1;
  VK_SHADER_STAGE_FRAGMENT_BIT = $10;
  VK_COMMAND_BUFFER_LEVEL_PRIMARY = 0;
  VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT = $2;
  VK_FENCE_CREATE_SIGNALED_BIT = $1;
  VK_QUEUE_GRAPHICS_BIT = $1;
  VK_TRUE = 1;

  { DispatcherQueue }
  DQTYPE_THREAD_CURRENT = 2;
  DQTAT_COM_STA         = 2;

(* ============================================================
 * Types — DXGI / D3D11
 * ============================================================ *)
type
  THRESULT = LongInt;
  TVertex = packed record
    X, Y, Z: Single;
    R, G, B, A: Single;
  end;
  TVector2 = packed record X, Y: Single; end;
  TVector3 = packed record X, Y, Z: Single; end;
  TDXGI_SAMPLE_DESC = record Count, Quality: UINT; end;
  TDXGI_SWAP_CHAIN_DESC1 = record
    Width, Height, Format: UINT;
    Stereo: LongBool;
    SampleDesc: TDXGI_SAMPLE_DESC;
    BufferUsage, BufferCount, Scaling, SwapEffect, AlphaMode, Flags: UINT;
  end;
  TD3D11_VIEWPORT = record
    TopLeftX, TopLeftY, Width, Height, MinDepth, MaxDepth: Single;
  end;
  TD3D11_INPUT_ELEMENT_DESC = record
    SemanticName: PAnsiChar;
    SemanticIndex, Format, InputSlot: UINT;
    AlignedByteOffset, InputSlotClass, InstanceDataStepRate: UINT;
  end;
  TD3D11_BUFFER_DESC = record
    ByteWidth, Usage, BindFlags, CPUAccessFlags: UINT;
    MiscFlags, StructureByteStride: UINT;
  end;
  TD3D11_SUBRESOURCE_DATA = record
    pSysMem: Pointer;
    SysMemPitch, SysMemSlicePitch: UINT;
  end;
  TD3D11_TEXTURE2D_DESC = record
    Width, Height, MipLevels, ArraySize, Format: UINT;
    SampleDesc: TDXGI_SAMPLE_DESC;
    Usage, BindFlags, CPUAccessFlags, MiscFlags: UINT;
  end;
  TD3D11_MAPPED_SUBRESOURCE = record
    pData: Pointer;
    RowPitch, DepthPitch: UINT;
  end;
  TDispatcherQueueOptions = record
    dwSize, threadType, apartmentType: UINT;
  end;

  { HSTRING }
  THSTRING = NativeUInt;
  THSTRING_HEADER = record
    {$ifdef CPU64}
    Reserved: array[0..23] of Byte;
    {$else}
    Reserved: array[0..19] of Byte;
    {$endif}
  end;

(* ============================================================
 * Vulkan structures (C-compatible layout via {$packrecords C})
 * ============================================================ *)
type
  TVkApplicationInfo = record
    sType: UInt32; pNext: Pointer;
    pApplicationName: PAnsiChar; applicationVersion: UInt32;
    pEngineName: PAnsiChar; engineVersion, apiVersion: UInt32;
  end;
  TVkInstanceCreateInfo = record
    sType: UInt32; pNext: Pointer; flags: UInt32;
    pApplicationInfo: Pointer;
    enabledLayerCount: UInt32; ppEnabledLayerNames: Pointer;
    enabledExtensionCount: UInt32; ppEnabledExtensionNames: Pointer;
  end;
  TVkDeviceQueueCreateInfo = record
    sType: UInt32; pNext: Pointer; flags: UInt32;
    queueFamilyIndex, queueCount: UInt32;
    pQueuePriorities: PSingle;
  end;
  TVkDeviceCreateInfo = record
    sType: UInt32; pNext: Pointer; flags: UInt32;
    queueCreateInfoCount: UInt32; pQueueCreateInfos: Pointer;
    enabledLayerCount: UInt32; ppEnabledLayerNames: Pointer;
    enabledExtensionCount: UInt32; ppEnabledExtensionNames: Pointer;
    pEnabledFeatures: Pointer;
  end;
  TVkImageCreateInfo = record
    sType: UInt32; pNext: Pointer; flags, imageType, format: UInt32;
    extentW, extentH, extentD: UInt32;
    mipLevels, arrayLayers, samples, tiling, usage: UInt32;
    sharingMode, qfiCount: UInt32; pQFIndices: Pointer;
    initialLayout: UInt32;
  end;
  TVkMemoryRequirements = record
    size, alignment: UInt64;
    memoryTypeBits: UInt32;
    _pad: array[0..3] of Byte;
  end;
  TVkMemoryAllocateInfo = record
    sType: UInt32; pNext: Pointer;
    allocationSize: UInt64; memoryTypeIndex: UInt32;
    _pad: array[0..3] of Byte;
  end;
  TVkImageViewCreateInfo = record
    sType: UInt32; pNext: Pointer; flags: UInt32;
    image: Pointer; viewType, format: UInt32;
    compR, compG, compB, compA: UInt32;
    aspectMask, baseMipLevel, levelCount, baseArrayLayer, layerCount: UInt32;
  end;
  TVkBufferCreateInfo = record
    sType: UInt32; pNext: Pointer; flags: UInt32;
    size: UInt64; usage, sharingMode, qfiCount: UInt32;
    pQFIndices: Pointer;
  end;
  TVkAttachmentDescription = record
    flags, format, samples: UInt32;
    loadOp, storeOp, stencilLoadOp, stencilStoreOp: UInt32;
    initialLayout, finalLayout: UInt32;
  end;
  TVkAttachmentReference = record attachment, layout: UInt32; end;
  TVkSubpassDescription = record
    flags, pipelineBindPoint: UInt32;
    inputAttachmentCount: UInt32; pInputAttachments: Pointer;
    colorAttachmentCount: UInt32; pColorAttachments: Pointer;
    pResolveAttachments, pDepthStencilAttachment: Pointer;
    preserveAttachmentCount: UInt32; pPreserveAttachments: Pointer;
  end;
  TVkRenderPassCreateInfo = record
    sType: UInt32; pNext: Pointer; flags: UInt32;
    attachmentCount: UInt32; pAttachments: Pointer;
    subpassCount: UInt32; pSubpasses: Pointer;
    dependencyCount: UInt32; pDependencies: Pointer;
  end;
  TVkFramebufferCreateInfo = record
    sType: UInt32; pNext: Pointer; flags: UInt32;
    renderPass: Pointer; attachmentCount: UInt32; pAttachments: Pointer;
    width, height, layers: UInt32;
  end;
  TVkShaderModuleCreateInfo = record
    sType: UInt32; pNext: Pointer; flags: UInt32;
    codeSize: NativeUInt; pCode: Pointer;
  end;
  TVkPipelineShaderStageCreateInfo = record
    sType: UInt32; pNext: Pointer; flags, stage: UInt32;
    module: Pointer; pName: PAnsiChar; pSpecInfo: Pointer;
  end;
  TVkPipelineVertexInputStateCreateInfo = record
    sType: UInt32; pNext: Pointer; flags: UInt32;
    vbdCount: UInt32; pVBDescs: Pointer;
    vadCount: UInt32; pVADescs: Pointer;
  end;
  TVkPipelineInputAssemblyStateCreateInfo = record
    sType: UInt32; pNext: Pointer; flags, topology, primRestart: UInt32;
  end;
  TVkViewport = record X, Y, Width, Height, MinDepth, MaxDepth: Single; end;
  TVkRect2D = record OffsetX, OffsetY: Int32; ExtentW, ExtentH: UInt32; end;
  TVkPipelineViewportStateCreateInfo = record
    sType: UInt32; pNext: Pointer; flags: UInt32;
    vpCount: UInt32; pViewports: Pointer;
    scissorCount: UInt32; pScissors: Pointer;
  end;
  TVkPipelineRasterizationStateCreateInfo = record
    sType: UInt32; pNext: Pointer; flags: UInt32;
    depthClamp, rasterizerDiscard, polygonMode, cullMode, frontFace: UInt32;
    depthBiasEnable: UInt32;
    depthBiasConst, depthBiasClamp, depthBiasSlope, lineWidth: Single;
  end;
  TVkPipelineMultisampleStateCreateInfo = record
    sType: UInt32; pNext: Pointer; flags, rasterSamples, sampleShadingEn: UInt32;
    minSampleShading: Single; pSampleMask: Pointer;
    alphaToCoverage, alphaToOne: UInt32;
  end;
  TVkPipelineColorBlendAttachmentState = record
    blendEnable: UInt32;
    srcColorBF, dstColorBF, colorBlendOp: UInt32;
    srcAlphaBF, dstAlphaBF, alphaBlendOp: UInt32;
    colorWriteMask: UInt32;
  end;
  TVkPipelineColorBlendStateCreateInfo = record
    sType: UInt32; pNext: Pointer; flags, logicOpEnable, logicOp: UInt32;
    attachmentCount: UInt32; pAttachments: Pointer;
    blendConstants: array[0..3] of Single;
  end;
  TVkPipelineLayoutCreateInfo = record
    sType: UInt32; pNext: Pointer; flags: UInt32;
    setLayoutCount: UInt32; pSetLayouts: Pointer;
    pushConstRangeCount: UInt32; pPushConstRanges: Pointer;
  end;
  TVkGraphicsPipelineCreateInfo = record
    sType: UInt32; pNext: Pointer; flags: UInt32;
    stageCount: UInt32; pStages: Pointer;
    pVertexInputState, pInputAssemblyState, pTessellationState: Pointer;
    pViewportState, pRasterizationState, pMultisampleState: Pointer;
    pDepthStencilState, pColorBlendState, pDynamicState: Pointer;
    layout, renderPass: Pointer; subpass: UInt32;
    basePipelineHandle: Pointer; basePipelineIndex: Int32;
  end;
  TVkCommandPoolCreateInfo = record
    sType: UInt32; pNext: Pointer; flags: UInt32;
    queueFamilyIndex: UInt32;
  end;
  TVkCommandBufferAllocateInfo = record
    sType: UInt32; pNext: Pointer;
    commandPool: Pointer; level, count: UInt32;
  end;
  TVkCommandBufferBeginInfo = record
    sType: UInt32; pNext: Pointer; flags: UInt32;
    pInheritanceInfo: Pointer;
  end;
  TVkClearValue = record R, G, B, A: Single; end;
  TVkRenderPassBeginInfo = record
    sType: UInt32; pNext: Pointer;
    renderPass, framebuffer: Pointer;
    renderAreaX, renderAreaY: Int32;
    renderAreaW, renderAreaH: UInt32;
    clearValueCount: UInt32; pClearValues: Pointer;
  end;
  TVkBufferImageCopy = record
    bufOffset: UInt64;
    bufRowLength, bufImgH: UInt32;
    aspectMask, mipLevel, baseLayer, layerCount: UInt32;
    offX, offY, offZ: Int32;
    extW, extH, extD: UInt32;
  end;
  TVkSubmitInfo = record
    sType: UInt32; pNext: Pointer;
    waitSemCount: UInt32; pWaitSems, pWaitDstStageMask: Pointer;
    cmdBufCount: UInt32; pCmdBufs: Pointer;
    signalSemCount: UInt32; pSignalSems: Pointer;
  end;
  TVkFenceCreateInfo = record
    sType: UInt32; pNext: Pointer; flags: UInt32;
  end;
  TVkQueueFamilyProperties = record
    queueFlags, queueCount, timestampValidBits: UInt32;
    minITGW, minITGH, minITGD: UInt32;
  end;
  TVkPhysicalDeviceMemoryProperties = record
    memTypeCount: UInt32;
    memTypes: array[0..31] of record propFlags, heapIndex: UInt32; end;
    memHeapCount: UInt32;
    memHeaps: array[0..15] of record size: UInt64; flags: UInt32; _pad: array[0..3] of Byte; end;
  end;

(* ============================================================
 * GUIDs
 * ============================================================ *)
const
  IID_IDXGIDevice:     TGUID = '{54EC77FA-1377-44E6-8C32-88FD5F44C84C}';
  IID_IDXGIFactory2:   TGUID = '{50C83A1C-E072-4C48-87B0-3630FA36A6D0}';
  IID_ID3D11Texture2D: TGUID = '{6F15AAF2-D208-4E89-9AB4-489535D34F9C}';

  { Windows.UI.Composition interfaces }
  IID_ICompositor:               TGUID = '{B403CA50-7F8C-4E83-985F-A414D26F1DAD}';
  IID_ICompositorDesktopInterop: TGUID = '{29E691FA-4567-4DCA-B319-D0F207EB6807}';
  IID_ICompositorInterop:        TGUID = '{25297D5C-3AD4-4C9C-B5CF-E36A38512330}';
  IID_ICompositionTarget:        TGUID = '{A1BEA8BA-D726-4663-8129-6B5E7927FFA6}';
  IID_IContainerVisual:          TGUID = '{02F6BC74-ED20-4773-AFE6-D49B4A93DB32}';
  IID_IVisual:                   TGUID = '{117E202D-A859-4C89-873B-C2AA566788E3}';
  IID_ISpriteVisual:             TGUID = '{08E05581-1AD1-4F97-9757-402D76E4233B}';
  IID_ICompositionBrush:         TGUID = '{AB0D7608-30C0-40E9-B568-B60A6BD1FB46}';

(* ============================================================
 * External DLL function imports
 * ============================================================ *)
function D3D11CreateDevice(
  pAdapter: Pointer; DriverType, Software: UINT; Flags: UINT;
  pFeatureLevels: Pointer; FeatureLevels: UINT; SDKVersion: UINT;
  out ppDevice: Pointer; pFeatureLevel: Pointer;
  out ppImmediateContext: Pointer): THRESULT; stdcall; external 'd3d11.dll';

function D3DCompile(
  pSrcData: Pointer; SrcDataSize: NativeUInt;
  pSourceName, pDefines, pInclude: Pointer;
  pEntrypoint, pTarget: PAnsiChar;
  Flags1, Flags2: UINT;
  out ppCode: Pointer; ppErrorMsgs: Pointer): THRESULT; stdcall; external 'd3dcompiler_47.dll';

function RoInitialize(initType: UINT): THRESULT; stdcall; external 'combase.dll';
procedure RoUninitialize; stdcall; external 'combase.dll';
function RoActivateInstance(
  activatableClassId: THSTRING; out instance: Pointer): THRESULT; stdcall; external 'combase.dll';
function WindowsCreateStringReference(
  sourceString: PWideChar; length: UINT;
  out hstringHeader: THSTRING_HEADER;
  out str: THSTRING): THRESULT; stdcall; external 'combase.dll';

function CreateDispatcherQueueController(
  const options: TDispatcherQueueOptions;
  out controller: Pointer): THRESULT; stdcall; external 'CoreMessaging.dll';

{ OpenGL basic functions }
function wglCreateContext(dc: HDC): HGLRC; stdcall; external 'opengl32.dll';
function wglDeleteContext(rc: HGLRC): BOOL; stdcall; external 'opengl32.dll';
function wglMakeCurrent(dc: HDC; rc: HGLRC): BOOL; stdcall; external 'opengl32.dll';
function wglGetProcAddress(name: PAnsiChar): Pointer; stdcall; external 'opengl32.dll';
procedure glViewport(x, y: Integer; w, h: Integer); stdcall; external 'opengl32.dll';
procedure glClearColor(r, g, b, a: Single); stdcall; external 'opengl32.dll';
procedure glClear(mask: UINT); stdcall; external 'opengl32.dll';
procedure glDrawArrays(mode: UINT; first: Integer; count: Integer); stdcall; external 'opengl32.dll';
procedure glFlush; stdcall; external 'opengl32.dll';

{ Vulkan functions }
function vkCreateInstance(pCI: Pointer; pA: Pointer; out inst: Pointer): Int32; stdcall; external 'vulkan-1.dll';
function vkEnumeratePhysicalDevices(inst: Pointer; pC: Pointer; pD: Pointer): Int32; stdcall; external 'vulkan-1.dll';
procedure vkGetPhysicalDeviceQueueFamilyProperties(pd: Pointer; pC: Pointer; pP: Pointer); stdcall; external 'vulkan-1.dll';
procedure vkGetPhysicalDeviceMemoryProperties(pd: Pointer; pM: Pointer); stdcall; external 'vulkan-1.dll';
function vkCreateDevice(pd: Pointer; pCI: Pointer; pA: Pointer; out dev: Pointer): Int32; stdcall; external 'vulkan-1.dll';
procedure vkGetDeviceQueue(dev: Pointer; qfi, qi: UInt32; out q: Pointer); stdcall; external 'vulkan-1.dll';
function vkCreateImage(dev, pCI, pA: Pointer; out img: Pointer): Int32; stdcall; external 'vulkan-1.dll';
procedure vkGetImageMemoryRequirements(dev, img: Pointer; pR: Pointer); stdcall; external 'vulkan-1.dll';
function vkAllocateMemory(dev, pAI, pA: Pointer; out mem: Pointer): Int32; stdcall; external 'vulkan-1.dll';
function vkBindImageMemory(dev, img, mem: Pointer; offset: UInt64): Int32; stdcall; external 'vulkan-1.dll';
function vkCreateImageView(dev, pCI, pA: Pointer; out iv: Pointer): Int32; stdcall; external 'vulkan-1.dll';
function vkCreateBuffer(dev, pCI, pA: Pointer; out buf: Pointer): Int32; stdcall; external 'vulkan-1.dll';
procedure vkGetBufferMemoryRequirements(dev, buf: Pointer; pR: Pointer); stdcall; external 'vulkan-1.dll';
function vkBindBufferMemory(dev, buf, mem: Pointer; offset: UInt64): Int32; stdcall; external 'vulkan-1.dll';
function vkCreateRenderPass(dev, pCI, pA: Pointer; out rp: Pointer): Int32; stdcall; external 'vulkan-1.dll';
function vkCreateFramebuffer(dev, pCI, pA: Pointer; out fb: Pointer): Int32; stdcall; external 'vulkan-1.dll';
function vkCreateShaderModule(dev, pCI, pA: Pointer; out sm: Pointer): Int32; stdcall; external 'vulkan-1.dll';
function vkCreatePipelineLayout(dev, pCI, pA: Pointer; out pl: Pointer): Int32; stdcall; external 'vulkan-1.dll';
function vkCreateGraphicsPipelines(dev, cache: Pointer; count: UInt32; pCI, pA: Pointer; out pip: Pointer): Int32; stdcall; external 'vulkan-1.dll';
procedure vkDestroyShaderModule(dev, sm, pA: Pointer); stdcall; external 'vulkan-1.dll';
function vkCreateCommandPool(dev, pCI, pA: Pointer; out cp: Pointer): Int32; stdcall; external 'vulkan-1.dll';
function vkAllocateCommandBuffers(dev, pAI: Pointer; out cb: Pointer): Int32; stdcall; external 'vulkan-1.dll';
function vkCreateFence(dev, pCI, pA: Pointer; out f: Pointer): Int32; stdcall; external 'vulkan-1.dll';
function vkWaitForFences(dev: Pointer; cnt: UInt32; pF: Pointer; waitAll: UInt32; timeout: UInt64): Int32; stdcall; external 'vulkan-1.dll';
function vkResetFences(dev: Pointer; cnt: UInt32; pF: Pointer): Int32; stdcall; external 'vulkan-1.dll';
function vkResetCommandBuffer(cb: Pointer; flags: UInt32): Int32; stdcall; external 'vulkan-1.dll';
function vkBeginCommandBuffer(cb, pBI: Pointer): Int32; stdcall; external 'vulkan-1.dll';
procedure vkCmdBeginRenderPass(cb, pBI: Pointer; contents: UInt32); stdcall; external 'vulkan-1.dll';
procedure vkCmdBindPipeline(cb: Pointer; bp: UInt32; pip: Pointer); stdcall; external 'vulkan-1.dll';
procedure vkCmdDraw(cb: Pointer; vc, ic, fv, fi: UInt32); stdcall; external 'vulkan-1.dll';
procedure vkCmdEndRenderPass(cb: Pointer); stdcall; external 'vulkan-1.dll';
procedure vkCmdCopyImageToBuffer(cb, img: Pointer; layout: UInt32; buf: Pointer; rc: UInt32; pR: Pointer); stdcall; external 'vulkan-1.dll';
function vkEndCommandBuffer(cb: Pointer): Int32; stdcall; external 'vulkan-1.dll';
function vkQueueSubmit(q: Pointer; cnt: UInt32; pSI: Pointer; fence: Pointer): Int32; stdcall; external 'vulkan-1.dll';
function vkMapMemory(dev, mem: Pointer; offset, size: UInt64; flags: UInt32; out ppData: Pointer): Int32; stdcall; external 'vulkan-1.dll';
procedure vkUnmapMemory(dev, mem: Pointer); stdcall; external 'vulkan-1.dll';
procedure vkDeviceWaitIdle(dev: Pointer); stdcall; external 'vulkan-1.dll';
procedure vkDestroyFence(dev, f, pA: Pointer); stdcall; external 'vulkan-1.dll';
procedure vkDestroyCommandPool(dev, cp, pA: Pointer); stdcall; external 'vulkan-1.dll';
procedure vkDestroyPipeline(dev, p, pA: Pointer); stdcall; external 'vulkan-1.dll';
procedure vkDestroyPipelineLayout(dev, pl, pA: Pointer); stdcall; external 'vulkan-1.dll';
procedure vkDestroyFramebuffer(dev, fb, pA: Pointer); stdcall; external 'vulkan-1.dll';
procedure vkDestroyRenderPass(dev, rp, pA: Pointer); stdcall; external 'vulkan-1.dll';
procedure vkDestroyImageView(dev, iv, pA: Pointer); stdcall; external 'vulkan-1.dll';
procedure vkDestroyImage(dev, img, pA: Pointer); stdcall; external 'vulkan-1.dll';
procedure vkFreeMemory(dev, mem, pA: Pointer); stdcall; external 'vulkan-1.dll';
procedure vkDestroyBuffer(dev, buf, pA: Pointer); stdcall; external 'vulkan-1.dll';
procedure vkDestroyDevice(dev, pA: Pointer); stdcall; external 'vulkan-1.dll';
procedure vkDestroyInstance(inst, pA: Pointer); stdcall; external 'vulkan-1.dll';

(* ============================================================
 * COM vtable helpers
 *
 * All COM/WinRT objects are stored as raw Pointer.
 * Slot(obj, N) returns the function pointer at vtable index N.
 * ============================================================ *)
function Slot(obj: Pointer; index: Integer): Pointer; inline;
begin
  Result := PPointer(PByte(PPointer(obj)^) + index * SizeOf(Pointer))^;
end;

type
  TFnQI       = function(This: Pointer; const riid: TGUID; out ppv: Pointer): THRESULT; stdcall;
  TFnRelease  = function(This: Pointer): ULONG; stdcall;

function ComQI(obj: Pointer; const iid: TGUID; out res: Pointer): THRESULT;
begin
  Result := TFnQI(Slot(obj, 0))(obj, iid, res);
end;

procedure ComRelease(var obj: Pointer);
begin
  if obj <> nil then begin TFnRelease(Slot(obj, 2))(obj); obj := nil; end;
end;

(* ============================================================
 * COM vtable function pointer types
 *
 * Naming: T<Interface>_<Method> with vtable slot in comment.
 * ============================================================ *)
type
  { ID3D11Device }
  TD3DDev_CreateBuffer           = function(This, pDesc, pInit: Pointer; out ppBuf: Pointer): THRESULT; stdcall;     { 3 }
  TD3DDev_CreateTexture2D        = function(This, pDesc, pInit: Pointer; out ppTex: Pointer): THRESULT; stdcall;     { 5 }
  TD3DDev_CreateRTV              = function(This, pRes, pDesc: Pointer; out ppRTV: Pointer): THRESULT; stdcall;      { 9 }
  TD3DDev_CreateInputLayout      = function(This, pDescs: Pointer; Num: UINT; pBC: Pointer; BCLen: NativeUInt; out ppIL: Pointer): THRESULT; stdcall; { 11 }
  TD3DDev_CreateVertexShader     = function(This, pBC: Pointer; BCLen: NativeUInt; pCL: Pointer; out ppVS: Pointer): THRESULT; stdcall; { 12 }
  TD3DDev_CreatePixelShader      = function(This, pBC: Pointer; BCLen: NativeUInt; pCL: Pointer; out ppPS: Pointer): THRESULT; stdcall; { 15 }
  { ID3D11DeviceContext }
  TCtx_PSSetShader     = procedure(This, pPS, pCI: Pointer; n: UINT); stdcall;         { 9 }
  TCtx_VSSetShader     = procedure(This, pVS, pCI: Pointer; n: UINT); stdcall;         { 11 }
  TCtx_Draw            = procedure(This: Pointer; vc, sv: UINT); stdcall;              { 13 }
  TCtx_Map             = function(This, pRes: Pointer; sub, mapType, flags: UINT; out mapped: TD3D11_MAPPED_SUBRESOURCE): THRESULT; stdcall; { 14 }
  TCtx_Unmap           = procedure(This, pRes: Pointer; sub: UINT); stdcall;           { 15 }
  TCtx_IASetInputLayout = procedure(This, pIL: Pointer); stdcall;                       { 17 }
  TCtx_IASetVB         = procedure(This: Pointer; slot, num: UINT; ppVB, pStrides, pOffsets: Pointer); stdcall; { 18 }
  TCtx_IASetTopo       = procedure(This: Pointer; topo: UINT); stdcall;                { 24 }
  TCtx_OMSetRTV        = procedure(This: Pointer; num: UINT; ppRTV: Pointer; pDSV: Pointer); stdcall; { 33 }
  TCtx_RSSetVP         = procedure(This: Pointer; num: UINT; pVP: Pointer); stdcall;   { 44 }
  TCtx_CopyResource    = procedure(This, pDst, pSrc: Pointer); stdcall;                { 47 }
  TCtx_ClearRTV        = procedure(This, pRTV: Pointer; col: Pointer); stdcall;        { 50 }
  { IDXGISwapChain }
  TSwap_Present   = function(This: Pointer; sync, flags: UINT): THRESULT; stdcall;     { 8 }
  TSwap_GetBuffer = function(This: Pointer; buf: UINT; const riid: TGUID; out ppSurf: Pointer): THRESULT; stdcall; { 9 }
  { IDXGIDevice }
  TDxgiDev_GetAdapter = function(This: Pointer; out ppA: Pointer): THRESULT; stdcall;  { 7 }
  { IDXGIObject (adapter) }
  TDxgiObj_GetParent = function(This: Pointer; const riid: TGUID; out ppP: Pointer): THRESULT; stdcall; { 6 }
  { IDXGIFactory2 }
  TFactory2_CreateSCForComp = function(This, pDev, pDesc, pRO: Pointer; out ppSC: Pointer): THRESULT; stdcall; { 24 }
  { ID3DBlob }
  TBlob_GetPointer = function(This: Pointer): Pointer; stdcall;   { 3 }
  TBlob_GetSize    = function(This: Pointer): NativeUInt; stdcall; { 4 }
  { ICompositor (WinRT, slot 6+) }
  TComp_CreateContainerVisual = function(This: Pointer; out ppR: Pointer): THRESULT; stdcall; { 9 }
  TComp_CreateSpriteVisual    = function(This: Pointer; out ppR: Pointer): THRESULT; stdcall; { 22 }
  TComp_CreateSurfaceBrush    = function(This, pSurf: Pointer; out ppR: Pointer): THRESULT; stdcall; { 24 }
  { ICompositorDesktopInterop (COM, slot 3+) }
  TDesktopInterop_CreateTarget = function(This: Pointer; hwnd: HWND; topmost: BOOL; out ppT: Pointer): THRESULT; stdcall; { 3 }
  { ICompositorInterop (COM, slot 3+) }
  TCompInterop_CreateSurfaceForSC = function(This, pSC: Pointer; out ppS: Pointer): THRESULT; stdcall; { 4 }
  { ICompositionTarget (WinRT, slot 6+) }
  TCompTarget_PutRoot = function(This, pV: Pointer): THRESULT; stdcall;               { 7 }
  { IContainerVisual (WinRT, slot 6+) }
  TContainerVisual_GetChildren = function(This: Pointer; out ppC: Pointer): THRESULT; stdcall; { 6 }
  { IVisualCollection (WinRT, slot 6+) }
  TVisualColl_InsertAtTop = function(This, pV: Pointer): THRESULT; stdcall;            { 9 }
  { IVisual (WinRT, slot 6+) }
  { put_Offset: Vector3 (12 bytes) -> passed by pointer on x64 }
  TVisual_PutOffset = function(This: Pointer; pOffset: Pointer): THRESULT; stdcall;    { 21 }
  { put_Size: Vector2 (8 bytes) -> packed into register on x64 }
  TVisual_PutSize   = function(This: Pointer; size: UInt64): THRESULT; stdcall;        { 36 }
  { ISpriteVisual (WinRT, slot 6+) }
  TSpriteVisual_PutBrush = function(This, pBrush: Pointer): THRESULT; stdcall;         { 7 }

(* ============================================================
 * Helper: pack two Singles into UInt64 for register passing
 * ============================================================ *)
function PackVector2(x, y: Single): UInt64;
var ix, iy: UInt32;
begin
  Move(x, ix, 4);
  Move(y, iy, 4);
  Result := UInt64(ix) or (UInt64(iy) shl 32);
end;

(* ============================================================
 * HSTRING helper
 * ============================================================ *)
function CreateHStringRef(const s: WideString; out header: THSTRING_HEADER): THSTRING;
begin
  Result := 0;
  if Length(s) > 0 then
    WindowsCreateStringReference(PWideChar(s), Length(s), header, Result);
end;

(* ============================================================
 * Debug output
 * ============================================================ *)
procedure Dbg(const msg: string);
var ws: WideString;
begin
  ws := WideString('[Pascal Comp] ' + msg + #13#10);
  OutputDebugStringW(PWideChar(ws));
end;

(* ============================================================
 * Shader sources
 * ============================================================ *)
const
  HLSL_VS: AnsiString =
    'struct I{float3 p:POSITION;float4 c:COLOR;};'+
    'struct O{float4 p:SV_POSITION;float4 c:COLOR;};'+
    'O main(I i){O o;o.p=float4(i.p,1);o.c=i.c;return o;}'#0;
  HLSL_PS: AnsiString =
    'struct I{float4 p:SV_POSITION;float4 c:COLOR;};'+
    'float4 main(I i):SV_TARGET{return i.c;}'#0;
  GLSL_VS: AnsiString =
    '#version 460 core'#10+
    'layout(location=0) in vec3 position;'#10+
    'layout(location=1) in vec3 color;'#10+
    'out vec4 vColor;'#10+
    'void main(){vColor=vec4(color,1);gl_Position=vec4(position.x,-position.y,position.z,1);}'#0;
  GLSL_FS: AnsiString =
    '#version 460 core'#10+
    'in vec4 vColor;out vec4 outColor;'#10+
    'void main(){outColor=vColor;}'#0;

(* ============================================================
 * OpenGL extension function pointers
 * ============================================================ *)
var
  p_glGenBuffers, p_glBindBuffer, p_glBufferData: Pointer;
  p_glCreateShader, p_glShaderSource, p_glCompileShader, p_glGetShaderiv: Pointer;
  p_glCreateProgram, p_glAttachShader, p_glLinkProgram, p_glGetProgramiv: Pointer;
  p_glUseProgram, p_glGetAttribLocation: Pointer;
  p_glEnableVertexAttribArray, p_glVertexAttribPointer: Pointer;
  p_glGenVertexArrays, p_glBindVertexArray: Pointer;
  p_glGenFramebuffers, p_glBindFramebuffer: Pointer;
  p_glFramebufferRenderbuffer, p_glCheckFramebufferStatus: Pointer;
  p_glGenRenderbuffers, p_glBindRenderbuffer: Pointer;
  p_glDeleteBuffers, p_glDeleteVertexArrays: Pointer;
  p_glDeleteFramebuffers, p_glDeleteRenderbuffers, p_glDeleteProgram: Pointer;
  p_wglCreateContextAttribsARB: Pointer;
  p_wglDXOpenDeviceNV, p_wglDXCloseDeviceNV: Pointer;
  p_wglDXRegisterObjectNV, p_wglDXUnregisterObjectNV: Pointer;
  p_wglDXLockObjectsNV, p_wglDXUnlockObjectsNV: Pointer;

{ Typed wrappers for frequently called GL extension functions }
type
  TGLProc1u = procedure(n: Integer; p: Pointer); stdcall;
  TGLProc_BindBuf = procedure(t, b: UINT); stdcall;
  TGLProc_BufData = procedure(t: UINT; sz: NativeUInt; d: Pointer; usage: UINT); stdcall;
  TGLProc_CreateShader = function(t: UINT): UINT; stdcall;
  TGLProc_ShaderSource = procedure(sh, cnt: UINT; pp: Pointer; pl: Pointer); stdcall;
  TGLProc_CompileShader = procedure(sh: UINT); stdcall;
  TGLProc_GetShaderiv = procedure(sh, pname: UINT; p: Pointer); stdcall;
  TGLProc_CreateProgram = function: UINT; stdcall;
  TGLProc_AttachShader = procedure(prog, sh: UINT); stdcall;
  TGLProc_LinkProgram = procedure(prog: UINT); stdcall;
  TGLProc_UseProgram = procedure(prog: UINT); stdcall;
  TGLProc_GetAttribLoc = function(prog: UINT; name: PAnsiChar): Int32; stdcall;
  TGLProc_EnableVAA = procedure(idx: UINT); stdcall;
  TGLProc_VertexAttribPtr = procedure(idx, sz, typ, norm, stride: UINT; p: Pointer); stdcall;
  TGLProc_BindVAO = procedure(vao: UINT); stdcall;
  TGLProc_BindFBO = procedure(t, fbo: UINT); stdcall;
  TGLProc_FBORenderbuffer = procedure(t, att, rbt, rbo: UINT); stdcall;
  TGLProc_CheckFBOStatus = function(t: UINT): UINT; stdcall;
  TGLProc_BindRBO = procedure(t, rbo: UINT); stdcall;
  TGLProc_DelProg = procedure(prog: UINT); stdcall;
  TGLProc_wglCreateCtx = function(dc: HDC; share: HGLRC; attribs: Pointer): HGLRC; stdcall;
  TGLProc_DXOpenDevice = function(dev: Pointer): Pointer; stdcall;
  TGLProc_DXCloseDevice = function(dev: Pointer): BOOL; stdcall;
  TGLProc_DXRegisterObj = function(dev, d3dObj: Pointer; glName, glType, access: UINT): Pointer; stdcall;
  TGLProc_DXUnregisterObj = function(dev, obj: Pointer): BOOL; stdcall;
  TGLProc_DXLockObjs = function(dev: Pointer; cnt: Integer; objs: Pointer): BOOL; stdcall;
  TGLProc_DXUnlockObjs = function(dev: Pointer; cnt: Integer; objs: Pointer): BOOL; stdcall;

(* ============================================================
 * Global state
 * ============================================================ *)
var
  g_hwnd: HWND;
  g_hdc: HDC;
  g_hglrc: HGLRC;

  { D3D11 objects (raw COM pointers) }
  g_d3dDevice, g_d3dCtx: Pointer;
  g_swapChain, g_backBuffer, g_rtv: Pointer;       { GL panel }
  g_vs, g_ps, g_inputLayout, g_vb: Pointer;
  g_dxSwapChain, g_dxRtv: Pointer;                 { D3D11 panel }
  g_vkSwapChain, g_vkBackBuffer, g_vkStagingTex: Pointer; { Vulkan panel D3D resources }

  { Composition }
  g_dqController: Pointer;
  g_compositor, g_desktopInterop, g_compInterop: Pointer;
  g_desktopTarget, g_compositionTarget: Pointer;
  g_rootContainer, g_rootVisual: Pointer;
  g_visualCollection: Pointer;
  { Per-panel composition objects (surface, surfaceBrush, compBrush, sprite, visual) }
  g_glSurf, g_glBrush, g_glCBrush, g_glSprite, g_glVis: Pointer;
  g_dxSurf, g_dxBrush, g_dxCBrush, g_dxSprite, g_dxVis: Pointer;
  g_vkSurf, g_vkBrush, g_vkCBrush, g_vkSprite, g_vkVis: Pointer;

  { OpenGL }
  g_glInteropDevice, g_glInteropObject: Pointer;
  g_glVbo: array[0..1] of UINT;
  g_glVao, g_glProgram: UINT;
  g_glRbo, g_glFbo: UINT;
  g_glPosAttrib, g_glColAttrib: Int32;

  { Vulkan }
  g_vkInstance, g_vkPhysDev, g_vkDevice, g_vkQueue: Pointer;
  g_vkQueueFamily: UInt32 = $FFFFFFFF;
  g_vkOffImage, g_vkOffMemory, g_vkOffView: Pointer;
  g_vkReadbackBuf, g_vkReadbackMem: Pointer;
  g_vkRenderPass, g_vkFramebuffer: Pointer;
  g_vkPipelineLayout, g_vkPipeline: Pointer;
  g_vkCmdPool, g_vkCmdBuf, g_vkFence: Pointer;

(* ============================================================
 * WndProc
 * ============================================================ *)
function WndProc(hWnd: HWND; msg: UINT; wParam: WPARAM; lParam: LPARAM): LRESULT; stdcall;
var ps: TPaintStruct;
begin
  case msg of
    WM_DESTROY: begin PostQuitMessage(0); Result := 0; end;
    WM_PAINT:   begin BeginPaint(hWnd, ps); EndPaint(hWnd, ps); Result := 0; end;
  else
    Result := DefWindowProcW(hWnd, msg, wParam, lParam);
  end;
end;

(* ============================================================
 * Create application window
 * ============================================================ *)
function CreateAppWindow(hInst: HINST): Boolean;
var
  wc: TWndClassExW;
  rc: TRect;
  style: DWORD;
begin
  FillChar(wc, SizeOf(wc), 0);
  wc.cbSize := SizeOf(wc);
  wc.hInstance := hInst;
  wc.lpszClassName := 'PascalCompTriangle';
  wc.lpfnWndProc := @WndProc;
  wc.hCursor := LoadCursor(0, IDC_ARROW);
  RegisterClassExW(wc);

  style := WS_OVERLAPPEDWINDOW;
  rc.Left := 0; rc.Top := 0; rc.Right := WINDOW_W; rc.Bottom := PANEL_H;
  AdjustWindowRect(rc, style, False);

  g_hwnd := CreateWindowExW(
    WS_EX_NOREDIRECTIONBITMAP,
    'PascalCompTriangle',
    'OpenGL + D3D11 + Vulkan via Windows.UI.Composition (Pascal)',
    style, Integer(CW_USEDEFAULT), Integer(CW_USEDEFAULT),
    rc.Right - rc.Left, rc.Bottom - rc.Top,
    0, 0, hInst, nil);
  Result := g_hwnd <> 0;
  if Result then begin ShowWindow(g_hwnd, SW_SHOW); UpdateWindow(g_hwnd); end;
end;

(* ============================================================
 * DXGI swap chain creation (shared helper)
 * ============================================================ *)
function CreateSwapChainForComposition(dev: Pointer; out sc: Pointer): THRESULT;
var
  dxgiDev, adapter, factory: Pointer;
  desc: TDXGI_SWAP_CHAIN_DESC1;
begin
  sc := nil;
  Result := ComQI(dev, IID_IDXGIDevice, dxgiDev); if Result < 0 then Exit;
  Result := TDxgiDev_GetAdapter(Slot(dxgiDev, 7))(dxgiDev, adapter);
  ComRelease(dxgiDev); if Result < 0 then Exit;
  Result := TDxgiObj_GetParent(Slot(adapter, 6))(adapter, IID_IDXGIFactory2, factory);
  ComRelease(adapter); if Result < 0 then Exit;

  FillChar(desc, SizeOf(desc), 0);
  desc.Width := PANEL_W; desc.Height := PANEL_H;
  desc.Format := DXGI_FORMAT_B8G8R8A8_UNORM;
  desc.SampleDesc.Count := 1;
  desc.BufferUsage := DXGI_USAGE_RENDER_TARGET_OUTPUT;
  desc.BufferCount := 2;
  desc.Scaling := DXGI_SCALING_STRETCH;
  desc.SwapEffect := DXGI_SWAP_EFFECT_FLIP_SEQUENTIAL;
  desc.AlphaMode := DXGI_ALPHA_MODE_PREMULTIPLIED;
  Result := TFactory2_CreateSCForComp(Slot(factory, 24))(factory, dev, @desc, nil, sc);
  ComRelease(factory);
end;

function CreateRTV(sc: Pointer; out bb, rtv: Pointer): THRESULT;
begin
  bb := nil; rtv := nil;
  Result := TSwap_GetBuffer(Slot(sc, 9))(sc, 0, IID_ID3D11Texture2D, bb);
  if Result < 0 then Exit;
  Result := TD3DDev_CreateRTV(Slot(g_d3dDevice, 9))(g_d3dDevice, bb, nil, rtv);
  if Result < 0 then begin ComRelease(bb); Exit; end;
end;

function CompileShader(src: PAnsiChar; len: NativeUInt; entry, target: PAnsiChar; out blob: Pointer): THRESULT;
var errBlob: Pointer;
begin
  errBlob := nil;
  Result := D3DCompile(src, len, nil, nil, nil, entry, target,
    D3DCOMPILE_ENABLE_STRICTNESS, 0, blob, @errBlob);
  if errBlob <> nil then ComRelease(errBlob);
end;

(* ============================================================
 * D3D11 initialization
 * ============================================================ *)
function InitD3D11: Boolean;
var
  fl: UInt32;
  flOut: UInt32;
  vsBlob, psBlob: Pointer;
  vsBuf: Pointer; vsSz: NativeUInt;
  layout: array[0..1] of TD3D11_INPUT_ELEMENT_DESC;
  verts: array[0..2] of TVertex;
  bd: TD3D11_BUFFER_DESC;
  sd: TD3D11_SUBRESOURCE_DATA;
begin
  Dbg('InitD3D11 begin');
  Result := False;
  fl := D3D_FEATURE_LEVEL_11_0;
  if D3D11CreateDevice(nil, D3D_DRIVER_TYPE_HARDWARE, 0,
       D3D11_CREATE_DEVICE_BGRA_SUPPORT,
       @fl, 1, D3D11_SDK_VERSION,
       g_d3dDevice, @flOut, g_d3dCtx) < 0 then Exit;

  if CreateSwapChainForComposition(g_d3dDevice, g_swapChain) < 0 then Exit;
  if CreateRTV(g_swapChain, g_backBuffer, g_rtv) < 0 then Exit;

  { Compile HLSL shaders }
  if CompileShader(PAnsiChar(HLSL_VS), Length(HLSL_VS)-1, 'main', 'vs_4_0', vsBlob) < 0 then Exit;
  vsBuf := TBlob_GetPointer(Slot(vsBlob, 3))(vsBlob);
  vsSz := TBlob_GetSize(Slot(vsBlob, 4))(vsBlob);
  if TD3DDev_CreateVertexShader(Slot(g_d3dDevice, 12))(g_d3dDevice, vsBuf, vsSz, nil, g_vs) < 0 then begin ComRelease(vsBlob); Exit; end;

  if CompileShader(PAnsiChar(HLSL_PS), Length(HLSL_PS)-1, 'main', 'ps_4_0', psBlob) < 0 then begin ComRelease(vsBlob); Exit; end;
  if TD3DDev_CreatePixelShader(Slot(g_d3dDevice, 15))(
       g_d3dDevice, TBlob_GetPointer(Slot(psBlob, 3))(psBlob),
       TBlob_GetSize(Slot(psBlob, 4))(psBlob), nil, g_ps) < 0 then begin ComRelease(psBlob); ComRelease(vsBlob); Exit; end;
  ComRelease(psBlob);

  { Input layout }
  FillChar(layout, SizeOf(layout), 0);
  layout[0].SemanticName := 'POSITION'; layout[0].Format := DXGI_FORMAT_R32G32B32_FLOAT;
  layout[1].SemanticName := 'COLOR'; layout[1].Format := DXGI_FORMAT_R32G32B32A32_FLOAT; layout[1].AlignedByteOffset := 12;
  if TD3DDev_CreateInputLayout(Slot(g_d3dDevice, 11))(g_d3dDevice, @layout[0], 2, vsBuf, vsSz, g_inputLayout) < 0 then begin ComRelease(vsBlob); Exit; end;
  ComRelease(vsBlob);

  { Vertex buffer }
  verts[0].X:= 0; verts[0].Y:= 0.5; verts[0].Z:=0.5; verts[0].R:=1; verts[0].G:=0; verts[0].B:=0; verts[0].A:=1;
  verts[1].X:= 0.5; verts[1].Y:=-0.5; verts[1].Z:=0.5; verts[1].R:=0; verts[1].G:=1; verts[1].B:=0; verts[1].A:=1;
  verts[2].X:=-0.5; verts[2].Y:=-0.5; verts[2].Z:=0.5; verts[2].R:=0; verts[2].G:=0; verts[2].B:=1; verts[2].A:=1;
  FillChar(bd, SizeOf(bd), 0);
  bd.ByteWidth := SizeOf(verts); bd.BindFlags := D3D11_BIND_VERTEX_BUFFER;
  FillChar(sd, SizeOf(sd), 0); sd.pSysMem := @verts[0];
  if TD3DDev_CreateBuffer(Slot(g_d3dDevice, 3))(g_d3dDevice, @bd, @sd, g_vb) < 0 then Exit;

  Dbg('InitD3D11 ok');
  Result := True;
end;

(* ============================================================
 * OpenGL initialization (WGL_NV_DX_interop)
 * ============================================================ *)
function GetGLProc(const name: AnsiString): Pointer;
begin
  Result := wglGetProcAddress(PAnsiChar(name));
end;

function LoadGLExtensions: Boolean;
begin
  p_glGenBuffers := GetGLProc('glGenBuffers');
  p_glBindBuffer := GetGLProc('glBindBuffer');
  p_glBufferData := GetGLProc('glBufferData');
  p_glCreateShader := GetGLProc('glCreateShader');
  p_glShaderSource := GetGLProc('glShaderSource');
  p_glCompileShader := GetGLProc('glCompileShader');
  p_glGetShaderiv := GetGLProc('glGetShaderiv');
  p_glCreateProgram := GetGLProc('glCreateProgram');
  p_glAttachShader := GetGLProc('glAttachShader');
  p_glLinkProgram := GetGLProc('glLinkProgram');
  p_glGetProgramiv := GetGLProc('glGetProgramiv');
  p_glUseProgram := GetGLProc('glUseProgram');
  p_glGetAttribLocation := GetGLProc('glGetAttribLocation');
  p_glEnableVertexAttribArray := GetGLProc('glEnableVertexAttribArray');
  p_glVertexAttribPointer := GetGLProc('glVertexAttribPointer');
  p_glGenVertexArrays := GetGLProc('glGenVertexArrays');
  p_glBindVertexArray := GetGLProc('glBindVertexArray');
  p_glGenFramebuffers := GetGLProc('glGenFramebuffers');
  p_glBindFramebuffer := GetGLProc('glBindFramebuffer');
  p_glFramebufferRenderbuffer := GetGLProc('glFramebufferRenderbuffer');
  p_glCheckFramebufferStatus := GetGLProc('glCheckFramebufferStatus');
  p_glGenRenderbuffers := GetGLProc('glGenRenderbuffers');
  p_glBindRenderbuffer := GetGLProc('glBindRenderbuffer');
  p_glDeleteBuffers := GetGLProc('glDeleteBuffers');
  p_glDeleteVertexArrays := GetGLProc('glDeleteVertexArrays');
  p_glDeleteFramebuffers := GetGLProc('glDeleteFramebuffers');
  p_glDeleteRenderbuffers := GetGLProc('glDeleteRenderbuffers');
  p_glDeleteProgram := GetGLProc('glDeleteProgram');
  p_wglCreateContextAttribsARB := GetGLProc('wglCreateContextAttribsARB');
  p_wglDXOpenDeviceNV := GetGLProc('wglDXOpenDeviceNV');
  p_wglDXCloseDeviceNV := GetGLProc('wglDXCloseDeviceNV');
  p_wglDXRegisterObjectNV := GetGLProc('wglDXRegisterObjectNV');
  p_wglDXUnregisterObjectNV := GetGLProc('wglDXUnregisterObjectNV');
  p_wglDXLockObjectsNV := GetGLProc('wglDXLockObjectsNV');
  p_wglDXUnlockObjectsNV := GetGLProc('wglDXUnlockObjectsNV');
  Result := p_wglDXOpenDeviceNV <> nil;
end;

function CompileGLShader(shaderType: UINT; const src: AnsiString): UINT;
var ok: Int32; p: PAnsiChar;
begin
  Result := TGLProc_CreateShader(p_glCreateShader)(shaderType);
  p := PAnsiChar(src);
  TGLProc_ShaderSource(p_glShaderSource)(Result, 1, @p, nil);
  TGLProc_CompileShader(p_glCompileShader)(Result);
  ok := 0;
  TGLProc_GetShaderiv(p_glGetShaderiv)(Result, GL_COMPILE_STATUS, @ok);
  if ok = 0 then Result := 0;
end;

function InitOpenGL: Boolean;
var
  pfd: TPixelFormatDescriptor;
  pf: Integer;
  legacyRC, rc: HGLRC;
  attrs: array[0..8] of Int32;
  pos: array[0..8] of Single;
  col: array[0..8] of Single;
  vs, fs: UINT;
  prog: UINT;
  lk: Int32;
  st: UINT;
begin
  Dbg('InitOpenGL begin');
  Result := False;
  g_hdc := GetDC(g_hwnd);

  FillChar(pfd, SizeOf(pfd), 0);
  pfd.nSize := SizeOf(pfd); pfd.nVersion := 1;
  pfd.dwFlags := PFD_DRAW_TO_WINDOW or PFD_SUPPORT_OPENGL or PFD_DOUBLEBUFFER;
  pfd.iPixelType := 0; { PFD_TYPE_RGBA }
  pfd.cColorBits := 32; pfd.cDepthBits := 24;
  pf := ChoosePixelFormat(g_hdc, @pfd);
  SetPixelFormat(g_hdc, pf, @pfd);

  legacyRC := wglCreateContext(g_hdc);
  wglMakeCurrent(g_hdc, legacyRC);

  p_wglCreateContextAttribsARB := GetGLProc('wglCreateContextAttribsARB');
  if p_wglCreateContextAttribsARB <> nil then begin
    attrs[0] := WGL_CONTEXT_MAJOR_VERSION_ARB; attrs[1] := 4;
    attrs[2] := WGL_CONTEXT_MINOR_VERSION_ARB; attrs[3] := 6;
    attrs[4] := WGL_CONTEXT_FLAGS_ARB;         attrs[5] := 0;
    attrs[6] := WGL_CONTEXT_PROFILE_MASK_ARB;  attrs[7] := WGL_CONTEXT_CORE_PROFILE_BIT_ARB;
    attrs[8] := 0;
    rc := TGLProc_wglCreateCtx(p_wglCreateContextAttribsARB)(g_hdc, 0, @attrs[0]);
    if rc <> 0 then begin wglMakeCurrent(g_hdc, rc); wglDeleteContext(legacyRC); g_hglrc := rc; end
    else g_hglrc := legacyRC;
  end else
    g_hglrc := legacyRC;

  if not LoadGLExtensions then Exit;

  { NV_DX_interop setup }
  g_glInteropDevice := TGLProc_DXOpenDevice(p_wglDXOpenDeviceNV)(g_d3dDevice);
  if g_glInteropDevice = nil then Exit;

  TGLProc1u(p_glGenRenderbuffers)(1, @g_glRbo);
  TGLProc_BindRBO(p_glBindRenderbuffer)(GL_RENDERBUFFER, g_glRbo);
  g_glInteropObject := TGLProc_DXRegisterObj(p_wglDXRegisterObjectNV)(
    g_glInteropDevice, g_backBuffer, g_glRbo, GL_RENDERBUFFER, WGL_ACCESS_READ_WRITE_NV);
  if g_glInteropObject = nil then Exit;

  { Framebuffer }
  TGLProc1u(p_glGenFramebuffers)(1, @g_glFbo);
  TGLProc_BindFBO(p_glBindFramebuffer)(GL_FRAMEBUFFER, g_glFbo);
  TGLProc_FBORenderbuffer(p_glFramebufferRenderbuffer)(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, g_glRbo);
  st := TGLProc_CheckFBOStatus(p_glCheckFramebufferStatus)(GL_FRAMEBUFFER);
  TGLProc_BindFBO(p_glBindFramebuffer)(GL_FRAMEBUFFER, 0);
  if st <> GL_FRAMEBUFFER_COMPLETE then Exit;

  { VAO/VBOs }
  TGLProc1u(p_glGenVertexArrays)(1, @g_glVao);
  TGLProc_BindVAO(p_glBindVertexArray)(g_glVao);
  TGLProc1u(p_glGenBuffers)(2, @g_glVbo[0]);

  pos[0]:=-0.5; pos[1]:=-0.5; pos[2]:=0; pos[3]:=0.5; pos[4]:=-0.5; pos[5]:=0; pos[6]:=0; pos[7]:=0.5; pos[8]:=0;
  TGLProc_BindBuf(p_glBindBuffer)(GL_ARRAY_BUFFER, g_glVbo[0]);
  TGLProc_BufData(p_glBufferData)(GL_ARRAY_BUFFER, SizeOf(pos), @pos[0], GL_STATIC_DRAW);
  col[0]:=0; col[1]:=0; col[2]:=1; col[3]:=0; col[4]:=1; col[5]:=0; col[6]:=1; col[7]:=0; col[8]:=0;
  TGLProc_BindBuf(p_glBindBuffer)(GL_ARRAY_BUFFER, g_glVbo[1]);
  TGLProc_BufData(p_glBufferData)(GL_ARRAY_BUFFER, SizeOf(col), @col[0], GL_STATIC_DRAW);

  { GLSL shaders }
  vs := CompileGLShader(GL_VERTEX_SHADER, GLSL_VS);
  fs := CompileGLShader(GL_FRAGMENT_SHADER, GLSL_FS);
  if (vs = 0) or (fs = 0) then Exit;
  prog := TGLProc_CreateProgram(p_glCreateProgram)();
  TGLProc_AttachShader(p_glAttachShader)(prog, vs);
  TGLProc_AttachShader(p_glAttachShader)(prog, fs);
  TGLProc_LinkProgram(p_glLinkProgram)(prog);
  lk := 0;
  TGLProc_GetShaderiv(p_glGetProgramiv)(prog, GL_LINK_STATUS, @lk);
  if lk = 0 then Exit;
  g_glProgram := prog;
  TGLProc_UseProgram(p_glUseProgram)(prog);
  g_glPosAttrib := TGLProc_GetAttribLoc(p_glGetAttribLocation)(prog, 'position');
  g_glColAttrib := TGLProc_GetAttribLoc(p_glGetAttribLocation)(prog, 'color');
  TGLProc_EnableVAA(p_glEnableVertexAttribArray)(UINT(g_glPosAttrib));
  TGLProc_EnableVAA(p_glEnableVertexAttribArray)(UINT(g_glColAttrib));

  Dbg('InitOpenGL ok');
  Result := True;
end;

(* ============================================================
 * D3D11 second panel (center)
 * ============================================================ *)
function InitD3D11SecondPanel: Boolean;
var dummy: Pointer;
begin
  Result := False;
  if CreateSwapChainForComposition(g_d3dDevice, g_dxSwapChain) < 0 then Exit;
  if CreateRTV(g_dxSwapChain, dummy, g_dxRtv) < 0 then Exit;
  ComRelease(dummy); { back buffer not needed separately }
  Result := True;
end;

(* ============================================================
 * Vulkan panel (right) — offscreen -> readback -> D3D11 staging
 * ============================================================ *)
function VkFindMemType(bits, props: UInt32): UInt32;
var mp: TVkPhysicalDeviceMemoryProperties; i: UInt32;
begin
  FillChar(mp, SizeOf(mp), 0);
  vkGetPhysicalDeviceMemoryProperties(g_vkPhysDev, @mp);
  for i := 0 to mp.memTypeCount - 1 do
    if (bits and (1 shl i) <> 0) and (mp.memTypes[i].propFlags and props = props) then
      Exit(i);
  Result := $FFFFFFFF;
end;

function InitVulkanPanel: Boolean;
var
  ai: TVkApplicationInfo; ici: TVkInstanceCreateInfo;
  devCount, qc, i, q: UInt32;
  devs: array of Pointer;
  qp: array of TVkQueueFamilyProperties;
  prio: Single;
  qci: TVkDeviceQueueCreateInfo; dci: TVkDeviceCreateInfo;
  imgci: TVkImageCreateInfo; mr: TVkMemoryRequirements;
  mai: TVkMemoryAllocateInfo;
  ivci: TVkImageViewCreateInfo;
  bci: TVkBufferCreateInfo;
  att: TVkAttachmentDescription; aref: TVkAttachmentReference;
  sub: TVkSubpassDescription; rpci: TVkRenderPassCreateInfo;
  fbci: TVkFramebufferCreateInfo;
  vsSpv, fsSpv: array of Byte;
  smci: TVkShaderModuleCreateInfo;
  vsMod, fsMod: Pointer;
  stages: array[0..1] of TVkPipelineShaderStageCreateInfo;
  vi: TVkPipelineVertexInputStateCreateInfo;
  ia: TVkPipelineInputAssemblyStateCreateInfo;
  vp: TVkViewport; sc: TVkRect2D;
  vps: TVkPipelineViewportStateCreateInfo;
  rs: TVkPipelineRasterizationStateCreateInfo;
  ms: TVkPipelineMultisampleStateCreateInfo;
  cba: TVkPipelineColorBlendAttachmentState;
  cbs: TVkPipelineColorBlendStateCreateInfo;
  plci: TVkPipelineLayoutCreateInfo;
  gpci: TVkGraphicsPipelineCreateInfo;
  cpci: TVkCommandPoolCreateInfo;
  cbai: TVkCommandBufferAllocateInfo;
  fci: TVkFenceCreateInfo;
  td: TD3D11_TEXTURE2D_DESC;
  bb: Pointer;
  f: file of Byte;
  sz: Integer;
  atts: array[0..0] of Pointer;
begin
  Dbg('InitVulkanPanel begin');
  Result := False;

  { Third swap chain + staging texture }
  if CreateSwapChainForComposition(g_d3dDevice, g_vkSwapChain) < 0 then Exit;
  if TSwap_GetBuffer(Slot(g_vkSwapChain, 9))(g_vkSwapChain, 0, IID_ID3D11Texture2D, bb) < 0 then Exit;
  g_vkBackBuffer := bb;
  FillChar(td, SizeOf(td), 0);
  td.Width := PANEL_W; td.Height := PANEL_H; td.MipLevels := 1; td.ArraySize := 1;
  td.Format := DXGI_FORMAT_B8G8R8A8_UNORM; td.SampleDesc.Count := 1;
  td.Usage := D3D11_USAGE_STAGING; td.CPUAccessFlags := D3D11_CPU_ACCESS_WRITE;
  if TD3DDev_CreateTexture2D(Slot(g_d3dDevice, 5))(g_d3dDevice, @td, nil, g_vkStagingTex) < 0 then Exit;

  { Vulkan instance }
  FillChar(ai, SizeOf(ai), 0);
  ai.sType := VK_STRUCTURE_TYPE_APPLICATION_INFO;
  ai.pApplicationName := 'triangle_vk_panel';
  ai.apiVersion := (1 shl 22) or (4 shl 12);
  FillChar(ici, SizeOf(ici), 0);
  ici.sType := VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO;
  ici.pApplicationInfo := @ai;
  if vkCreateInstance(@ici, nil, g_vkInstance) <> VK_SUCCESS then Exit;

  { Physical device + graphics queue family }
  devCount := 0;
  vkEnumeratePhysicalDevices(g_vkInstance, @devCount, nil);
  if devCount = 0 then Exit;
  SetLength(devs, devCount);
  vkEnumeratePhysicalDevices(g_vkInstance, @devCount, @devs[0]);
  for i := 0 to devCount - 1 do begin
    qc := 0;
    vkGetPhysicalDeviceQueueFamilyProperties(devs[i], @qc, nil);
    if qc = 0 then Continue;
    SetLength(qp, qc);
    vkGetPhysicalDeviceQueueFamilyProperties(devs[i], @qc, @qp[0]);
    for q := 0 to qc - 1 do
      if qp[q].queueFlags and VK_QUEUE_GRAPHICS_BIT <> 0 then begin
        g_vkPhysDev := devs[i]; g_vkQueueFamily := q; Break;
      end;
    if g_vkPhysDev <> nil then Break;
  end;
  if g_vkPhysDev = nil then Exit;

  { Logical device }
  prio := 1.0;
  FillChar(qci, SizeOf(qci), 0);
  qci.sType := VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO;
  qci.queueFamilyIndex := g_vkQueueFamily; qci.queueCount := 1; qci.pQueuePriorities := @prio;
  FillChar(dci, SizeOf(dci), 0);
  dci.sType := VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO;
  dci.queueCreateInfoCount := 1; dci.pQueueCreateInfos := @qci;
  if vkCreateDevice(g_vkPhysDev, @dci, nil, g_vkDevice) <> VK_SUCCESS then Exit;
  vkGetDeviceQueue(g_vkDevice, g_vkQueueFamily, 0, g_vkQueue);

  { Offscreen image }
  FillChar(imgci, SizeOf(imgci), 0);
  imgci.sType := VK_STRUCTURE_TYPE_IMAGE_CREATE_INFO;
  imgci.imageType := VK_IMAGE_TYPE_2D; imgci.format := VK_FORMAT_B8G8R8A8_UNORM;
  imgci.extentW := PANEL_W; imgci.extentH := PANEL_H; imgci.extentD := 1;
  imgci.mipLevels := 1; imgci.arrayLayers := 1; imgci.samples := VK_SAMPLE_COUNT_1_BIT;
  imgci.tiling := VK_IMAGE_TILING_OPTIMAL;
  imgci.usage := VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT or VK_IMAGE_USAGE_TRANSFER_SRC_BIT;
  if vkCreateImage(g_vkDevice, @imgci, nil, g_vkOffImage) <> VK_SUCCESS then Exit;
  FillChar(mr, SizeOf(mr), 0);
  vkGetImageMemoryRequirements(g_vkDevice, g_vkOffImage, @mr);
  FillChar(mai, SizeOf(mai), 0);
  mai.sType := VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO;
  mai.allocationSize := mr.size;
  mai.memoryTypeIndex := VkFindMemType(mr.memoryTypeBits, VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT);
  if vkAllocateMemory(g_vkDevice, @mai, nil, g_vkOffMemory) <> VK_SUCCESS then Exit;
  vkBindImageMemory(g_vkDevice, g_vkOffImage, g_vkOffMemory, 0);

  { Image view }
  FillChar(ivci, SizeOf(ivci), 0);
  ivci.sType := VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO;
  ivci.image := g_vkOffImage; ivci.viewType := VK_IMAGE_VIEW_TYPE_2D; ivci.format := VK_FORMAT_B8G8R8A8_UNORM;
  ivci.aspectMask := VK_IMAGE_ASPECT_COLOR_BIT; ivci.levelCount := 1; ivci.layerCount := 1;
  if vkCreateImageView(g_vkDevice, @ivci, nil, g_vkOffView) <> VK_SUCCESS then Exit;

  { Readback buffer }
  FillChar(bci, SizeOf(bci), 0);
  bci.sType := VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO;
  bci.size := UInt64(PANEL_W) * PANEL_H * 4; bci.usage := VK_BUFFER_USAGE_TRANSFER_DST_BIT;
  if vkCreateBuffer(g_vkDevice, @bci, nil, g_vkReadbackBuf) <> VK_SUCCESS then Exit;
  vkGetBufferMemoryRequirements(g_vkDevice, g_vkReadbackBuf, @mr);
  FillChar(mai, SizeOf(mai), 0);
  mai.sType := VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO;
  mai.allocationSize := mr.size;
  mai.memoryTypeIndex := VkFindMemType(mr.memoryTypeBits, VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT or VK_MEMORY_PROPERTY_HOST_COHERENT_BIT);
  if vkAllocateMemory(g_vkDevice, @mai, nil, g_vkReadbackMem) <> VK_SUCCESS then Exit;
  vkBindBufferMemory(g_vkDevice, g_vkReadbackBuf, g_vkReadbackMem, 0);

  { Render pass }
  FillChar(att, SizeOf(att), 0);
  att.format := VK_FORMAT_B8G8R8A8_UNORM; att.samples := VK_SAMPLE_COUNT_1_BIT;
  att.loadOp := VK_ATTACHMENT_LOAD_OP_CLEAR; att.storeOp := VK_ATTACHMENT_STORE_OP_STORE;
  att.stencilLoadOp := VK_ATTACHMENT_LOAD_OP_DONT_CARE; att.stencilStoreOp := VK_ATTACHMENT_STORE_OP_DONT_CARE;
  att.finalLayout := VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL;
  aref.attachment := 0; aref.layout := VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL;
  FillChar(sub, SizeOf(sub), 0);
  sub.colorAttachmentCount := 1; sub.pColorAttachments := @aref;
  FillChar(rpci, SizeOf(rpci), 0);
  rpci.sType := VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO;
  rpci.attachmentCount := 1; rpci.pAttachments := @att;
  rpci.subpassCount := 1; rpci.pSubpasses := @sub;
  if vkCreateRenderPass(g_vkDevice, @rpci, nil, g_vkRenderPass) <> VK_SUCCESS then Exit;

  { Framebuffer }
  atts[0] := g_vkOffView;
  FillChar(fbci, SizeOf(fbci), 0);
  fbci.sType := VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO;
  fbci.renderPass := g_vkRenderPass; fbci.attachmentCount := 1; fbci.pAttachments := @atts[0];
  fbci.width := PANEL_W; fbci.height := PANEL_H; fbci.layers := 1;
  if vkCreateFramebuffer(g_vkDevice, @fbci, nil, g_vkFramebuffer) <> VK_SUCCESS then Exit;

  { Load SPIR-V shaders }
  AssignFile(f, 'hello_vert.spv'); {$I-} Reset(f); {$I+}
  if IOResult <> 0 then Exit;
  sz := FileSize(f); SetLength(vsSpv, sz); BlockRead(f, vsSpv[0], sz); CloseFile(f);
  AssignFile(f, 'hello_frag.spv'); {$I-} Reset(f); {$I+}
  if IOResult <> 0 then Exit;
  sz := FileSize(f); SetLength(fsSpv, sz); BlockRead(f, fsSpv[0], sz); CloseFile(f);

  FillChar(smci, SizeOf(smci), 0); smci.sType := VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO;
  smci.codeSize := Length(vsSpv); smci.pCode := @vsSpv[0];
  vsMod := nil; vkCreateShaderModule(g_vkDevice, @smci, nil, vsMod);
  smci.codeSize := Length(fsSpv); smci.pCode := @fsSpv[0];
  fsMod := nil; vkCreateShaderModule(g_vkDevice, @smci, nil, fsMod);

  FillChar(stages, SizeOf(stages), 0);
  stages[0].sType := VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO;
  stages[0].stage := VK_SHADER_STAGE_VERTEX_BIT; stages[0].module := vsMod; stages[0].pName := 'main';
  stages[1].sType := VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO;
  stages[1].stage := VK_SHADER_STAGE_FRAGMENT_BIT; stages[1].module := fsMod; stages[1].pName := 'main';

  FillChar(vi, SizeOf(vi), 0); vi.sType := VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO;
  FillChar(ia, SizeOf(ia), 0); ia.sType := VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO; ia.topology := VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST;
  FillChar(vp, SizeOf(vp), 0); vp.Width := PANEL_W; vp.Height := PANEL_H; vp.MaxDepth := 1;
  FillChar(sc, SizeOf(sc), 0); sc.ExtentW := PANEL_W; sc.ExtentH := PANEL_H;
  FillChar(vps, SizeOf(vps), 0); vps.sType := VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO;
  vps.vpCount := 1; vps.pViewports := @vp; vps.scissorCount := 1; vps.pScissors := @sc;
  FillChar(rs, SizeOf(rs), 0); rs.sType := VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO;
  rs.polygonMode := VK_POLYGON_MODE_FILL; rs.cullMode := VK_CULL_MODE_BACK_BIT;
  rs.frontFace := VK_FRONT_FACE_CLOCKWISE; rs.lineWidth := 1;
  FillChar(ms, SizeOf(ms), 0); ms.sType := VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO; ms.rasterSamples := VK_SAMPLE_COUNT_1_BIT;
  FillChar(cba, SizeOf(cba), 0); cba.colorWriteMask := $F;
  FillChar(cbs, SizeOf(cbs), 0); cbs.sType := VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO;
  cbs.attachmentCount := 1; cbs.pAttachments := @cba;
  FillChar(plci, SizeOf(plci), 0); plci.sType := VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO;
  vkCreatePipelineLayout(g_vkDevice, @plci, nil, g_vkPipelineLayout);

  FillChar(gpci, SizeOf(gpci), 0);
  gpci.sType := VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO;
  gpci.stageCount := 2; gpci.pStages := @stages[0];
  gpci.pVertexInputState := @vi; gpci.pInputAssemblyState := @ia;
  gpci.pViewportState := @vps; gpci.pRasterizationState := @rs;
  gpci.pMultisampleState := @ms; gpci.pColorBlendState := @cbs;
  gpci.layout := g_vkPipelineLayout; gpci.renderPass := g_vkRenderPass;
  gpci.basePipelineIndex := -1;
  vkCreateGraphicsPipelines(g_vkDevice, nil, 1, @gpci, nil, g_vkPipeline);

  { Command pool + buffer + fence }
  FillChar(cpci, SizeOf(cpci), 0);
  cpci.sType := VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO;
  cpci.flags := VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT;
  cpci.queueFamilyIndex := g_vkQueueFamily;
  vkCreateCommandPool(g_vkDevice, @cpci, nil, g_vkCmdPool);
  FillChar(cbai, SizeOf(cbai), 0);
  cbai.sType := VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO;
  cbai.commandPool := g_vkCmdPool; cbai.count := 1;
  vkAllocateCommandBuffers(g_vkDevice, @cbai, g_vkCmdBuf);
  FillChar(fci, SizeOf(fci), 0);
  fci.sType := VK_STRUCTURE_TYPE_FENCE_CREATE_INFO; fci.flags := VK_FENCE_CREATE_SIGNALED_BIT;
  vkCreateFence(g_vkDevice, @fci, nil, g_vkFence);

  if vsMod <> nil then vkDestroyShaderModule(g_vkDevice, vsMod, nil);
  if fsMod <> nil then vkDestroyShaderModule(g_vkDevice, fsMod, nil);
  Dbg('InitVulkanPanel ok');
  Result := True;
end;

(* ============================================================
 * Windows.UI.Composition setup
 * ============================================================ *)
function AddSpriteForSwapChain(
  swapChain: Pointer; offsetX: Single;
  var pSurf, pBrush, pCBrush, pSprite, pVisual: Pointer): Boolean;
var
  offset: TVector3;
  spriteVis: Pointer;
begin
  Result := False;
  { Create composition surface from swap chain }
  if TCompInterop_CreateSurfaceForSC(Slot(g_compInterop, 4))(g_compInterop, swapChain, pSurf) < 0 then Exit;
  { Create surface brush }
  if TComp_CreateSurfaceBrush(Slot(g_compositor, 24))(g_compositor, pSurf, pBrush) < 0 then Exit;
  { QI brush -> ICompositionBrush }
  if ComQI(pBrush, IID_ICompositionBrush, pCBrush) < 0 then Exit;
  { Create sprite visual }
  if TComp_CreateSpriteVisual(Slot(g_compositor, 22))(g_compositor, pSprite) < 0 then Exit;
  { Set brush on sprite }
  TSpriteVisual_PutBrush(Slot(pSprite, 7))(pSprite, pCBrush);
  { QI sprite -> IVisual }
  if ComQI(pSprite, IID_IVisual, pVisual) < 0 then Exit;
  { Set size (Vector2 packed into register) }
  TVisual_PutSize(Slot(pVisual, 36))(pVisual, PackVector2(PANEL_W, PANEL_H));
  { Set offset (Vector3 passed by pointer) }
  offset.X := offsetX; offset.Y := 0; offset.Z := 0;
  TVisual_PutOffset(Slot(pVisual, 21))(pVisual, @offset);
  { Insert into root visual collection }
  spriteVis := nil;
  if ComQI(pSprite, IID_IVisual, spriteVis) < 0 then Exit;
  TVisualColl_InsertAtTop(Slot(g_visualCollection, 9))(g_visualCollection, spriteVis);
  ComRelease(spriteVis);
  Result := True;
end;

function InitComposition: Boolean;
var
  opts: TDispatcherQueueOptions;
  hsComp: THSTRING;
  hdrComp: THSTRING_HEADER;
  inspectable: Pointer;
begin
  Dbg('InitComposition begin');
  Result := False;

  { Initialize WinRT + DispatcherQueue }
  CoInitializeEx(nil, COINIT_APARTMENTTHREADED);
  FillChar(opts, SizeOf(opts), 0);
  opts.dwSize := SizeOf(opts);
  opts.threadType := DQTYPE_THREAD_CURRENT;
  opts.apartmentType := DQTAT_COM_STA;
  if CreateDispatcherQueueController(opts, g_dqController) < 0 then Exit;
  RoInitialize(0); { RO_INIT_SINGLETHREADED }
  Dbg('DispatcherQueue + RoInit ok');

  { Activate Compositor }
  hsComp := CreateHStringRef('Windows.UI.Composition.Compositor', hdrComp);
  inspectable := nil;
  if RoActivateInstance(hsComp, inspectable) < 0 then Exit;
  g_compositor := inspectable; { default interface is ICompositor }
  Dbg('Compositor activated');

  { QI for interop interfaces }
  if ComQI(g_compositor, IID_ICompositorDesktopInterop, g_desktopInterop) < 0 then Exit;
  if ComQI(g_compositor, IID_ICompositorInterop, g_compInterop) < 0 then Exit;

  { Create DesktopWindowTarget }
  if TDesktopInterop_CreateTarget(Slot(g_desktopInterop, 3))(
       g_desktopInterop, g_hwnd, False, g_desktopTarget) < 0 then Exit;
  Dbg('DesktopWindowTarget created');

  { QI for ICompositionTarget }
  if ComQI(g_desktopTarget, IID_ICompositionTarget, g_compositionTarget) < 0 then Exit;

  { Create root ContainerVisual }
  if TComp_CreateContainerVisual(Slot(g_compositor, 9))(g_compositor, g_rootContainer) < 0 then Exit;

  { QI root -> IVisual to set on target }
  if ComQI(g_rootContainer, IID_IVisual, g_rootVisual) < 0 then Exit;
  TCompTarget_PutRoot(Slot(g_compositionTarget, 7))(g_compositionTarget, g_rootVisual);

  { Get children collection }
  if TContainerVisual_GetChildren(Slot(g_rootContainer, 6))(g_rootContainer, g_visualCollection) < 0 then Exit;

  { Add sprite visuals for each panel }
  if not AddSpriteForSwapChain(g_swapChain,   0,        g_glSurf, g_glBrush, g_glCBrush, g_glSprite, g_glVis) then Exit;
  if not AddSpriteForSwapChain(g_dxSwapChain,  PANEL_W,  g_dxSurf, g_dxBrush, g_dxCBrush, g_dxSprite, g_dxVis) then Exit;
  if not AddSpriteForSwapChain(g_vkSwapChain,  PANEL_W*2, g_vkSurf, g_vkBrush, g_vkCBrush, g_vkSprite, g_vkVis) then Exit;

  Dbg('InitComposition ok');
  Result := True;
end;

(* ============================================================
 * Render functions
 * ============================================================ *)
procedure RenderOpenGLPanel;
var objs: array[0..0] of Pointer;
begin
  if (g_glInteropDevice = nil) or (g_glInteropObject = nil) then Exit;
  wglMakeCurrent(g_hdc, g_hglrc);
  objs[0] := g_glInteropObject;
  if not TGLProc_DXLockObjs(p_wglDXLockObjectsNV)(g_glInteropDevice, 1, @objs[0]) then Exit;

  TGLProc_BindFBO(p_glBindFramebuffer)(GL_FRAMEBUFFER, g_glFbo);
  glViewport(0, 0, PANEL_W, PANEL_H);
  glClearColor(0.05, 0.05, 0.15, 1.0);
  glClear(GL_COLOR_BUFFER_BIT);
  TGLProc_UseProgram(p_glUseProgram)(g_glProgram);
  TGLProc_BindBuf(p_glBindBuffer)(GL_ARRAY_BUFFER, g_glVbo[0]);
  TGLProc_VertexAttribPtr(p_glVertexAttribPointer)(UINT(g_glPosAttrib), 3, GL_FLOAT, GL_FALSE, 0, nil);
  TGLProc_BindBuf(p_glBindBuffer)(GL_ARRAY_BUFFER, g_glVbo[1]);
  TGLProc_VertexAttribPtr(p_glVertexAttribPointer)(UINT(g_glColAttrib), 3, GL_FLOAT, GL_FALSE, 0, nil);
  glDrawArrays(GL_TRIANGLES, 0, 3);
  glFlush;
  TGLProc_BindFBO(p_glBindFramebuffer)(GL_FRAMEBUFFER, 0);

  TGLProc_DXUnlockObjs(p_wglDXUnlockObjectsNV)(g_glInteropDevice, 1, @objs[0]);
  TSwap_Present(Slot(g_swapChain, 8))(g_swapChain, 1, 0);
end;

procedure RenderD3D11Panel;
var
  vpd: TD3D11_VIEWPORT;
  cc: array[0..3] of Single;
  stride, offs: UINT;
  vbs: array[0..0] of Pointer;
  rtvs: array[0..0] of Pointer;
begin
  if (g_dxSwapChain = nil) or (g_dxRtv = nil) then Exit;
  FillChar(vpd, SizeOf(vpd), 0);
  vpd.Width := PANEL_W; vpd.Height := PANEL_H; vpd.MaxDepth := 1;
  TCtx_RSSetVP(Slot(g_d3dCtx, 44))(g_d3dCtx, 1, @vpd);
  rtvs[0] := g_dxRtv;
  TCtx_OMSetRTV(Slot(g_d3dCtx, 33))(g_d3dCtx, 1, @rtvs[0], nil);
  cc[0] := 0.05; cc[1] := 0.15; cc[2] := 0.05; cc[3] := 1;
  TCtx_ClearRTV(Slot(g_d3dCtx, 50))(g_d3dCtx, g_dxRtv, @cc[0]);
  stride := VERTEX_SIZE; offs := 0; vbs[0] := g_vb;
  TCtx_IASetInputLayout(Slot(g_d3dCtx, 17))(g_d3dCtx, g_inputLayout);
  TCtx_IASetVB(Slot(g_d3dCtx, 18))(g_d3dCtx, 0, 1, @vbs[0], @stride, @offs);
  TCtx_IASetTopo(Slot(g_d3dCtx, 24))(g_d3dCtx, D3D11_PRIMITIVE_TOPOLOGY_TRIANGLELIST);
  TCtx_VSSetShader(Slot(g_d3dCtx, 11))(g_d3dCtx, g_vs, nil, 0);
  TCtx_PSSetShader(Slot(g_d3dCtx, 9))(g_d3dCtx, g_ps, nil, 0);
  TCtx_Draw(Slot(g_d3dCtx, 13))(g_d3dCtx, 3, 0);
  TSwap_Present(Slot(g_dxSwapChain, 8))(g_dxSwapChain, 1, 0);
end;

procedure RenderVulkanPanel;
var
  fences: array[0..0] of Pointer;
  bi: TVkCommandBufferBeginInfo;
  cv: TVkClearValue;
  rpbi: TVkRenderPassBeginInfo;
  region: TVkBufferImageCopy;
  cmdBufs: array[0..0] of Pointer;
  si: TVkSubmitInfo;
  vkData: Pointer;
  mapped: TD3D11_MAPPED_SUBRESOURCE;
  pitch, y: UINT;
begin
  if (g_vkDevice = nil) or (g_vkCmdBuf = nil) or (g_vkStagingTex = nil) then Exit;

  fences[0] := g_vkFence;
  vkWaitForFences(g_vkDevice, 1, @fences[0], VK_TRUE, UInt64($FFFFFFFFFFFFFFFF));
  vkResetFences(g_vkDevice, 1, @fences[0]);
  vkResetCommandBuffer(g_vkCmdBuf, 0);

  FillChar(bi, SizeOf(bi), 0); bi.sType := VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO;
  vkBeginCommandBuffer(g_vkCmdBuf, @bi);

  FillChar(cv, SizeOf(cv), 0); cv.R := 0.15; cv.G := 0.05; cv.B := 0.05; cv.A := 1;
  FillChar(rpbi, SizeOf(rpbi), 0);
  rpbi.sType := VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO;
  rpbi.renderPass := g_vkRenderPass; rpbi.framebuffer := g_vkFramebuffer;
  rpbi.renderAreaW := PANEL_W; rpbi.renderAreaH := PANEL_H;
  rpbi.clearValueCount := 1; rpbi.pClearValues := @cv;
  vkCmdBeginRenderPass(g_vkCmdBuf, @rpbi, VK_SUBPASS_CONTENTS_INLINE);
  vkCmdBindPipeline(g_vkCmdBuf, VK_PIPELINE_BIND_POINT_GRAPHICS, g_vkPipeline);
  vkCmdDraw(g_vkCmdBuf, 3, 1, 0, 0);
  vkCmdEndRenderPass(g_vkCmdBuf);

  FillChar(region, SizeOf(region), 0);
  region.bufRowLength := PANEL_W; region.bufImgH := PANEL_H;
  region.aspectMask := VK_IMAGE_ASPECT_COLOR_BIT; region.layerCount := 1;
  region.extW := PANEL_W; region.extH := PANEL_H; region.extD := 1;
  vkCmdCopyImageToBuffer(g_vkCmdBuf, g_vkOffImage, VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL, g_vkReadbackBuf, 1, @region);
  vkEndCommandBuffer(g_vkCmdBuf);

  cmdBufs[0] := g_vkCmdBuf;
  FillChar(si, SizeOf(si), 0);
  si.sType := VK_STRUCTURE_TYPE_SUBMIT_INFO; si.cmdBufCount := 1; si.pCmdBufs := @cmdBufs[0];
  vkQueueSubmit(g_vkQueue, 1, @si, g_vkFence);
  vkWaitForFences(g_vkDevice, 1, @fences[0], VK_TRUE, UInt64($FFFFFFFFFFFFFFFF));

  vkData := nil;
  vkMapMemory(g_vkDevice, g_vkReadbackMem, 0, UInt64(PANEL_W)*PANEL_H*4, 0, vkData);
  FillChar(mapped, SizeOf(mapped), 0);
  if TCtx_Map(Slot(g_d3dCtx, 14))(g_d3dCtx, g_vkStagingTex, 0, D3D11_MAP_WRITE, 0, mapped) >= 0 then begin
    pitch := PANEL_W * 4;
    for y := 0 to PANEL_H - 1 do
      Move(Pointer(PByte(vkData) + y * pitch)^,
           Pointer(PByte(mapped.pData) + y * mapped.RowPitch)^,
           pitch);
    TCtx_Unmap(Slot(g_d3dCtx, 15))(g_d3dCtx, g_vkStagingTex, 0);
    TCtx_CopyResource(Slot(g_d3dCtx, 47))(g_d3dCtx, g_vkBackBuffer, g_vkStagingTex);
  end;
  vkUnmapMemory(g_vkDevice, g_vkReadbackMem);
  TSwap_Present(Slot(g_vkSwapChain, 8))(g_vkSwapChain, 1, 0);
end;

procedure Render;
begin
  RenderOpenGLPanel;
  RenderD3D11Panel;
  RenderVulkanPanel;
end;

(* ============================================================
 * Cleanup
 * ============================================================ *)
procedure Cleanup;
begin
  Dbg('Cleanup begin');

  { Composition objects }
  ComRelease(g_visualCollection);
  ComRelease(g_vkVis); ComRelease(g_vkSprite); ComRelease(g_vkCBrush); ComRelease(g_vkBrush); ComRelease(g_vkSurf);
  ComRelease(g_dxVis); ComRelease(g_dxSprite); ComRelease(g_dxCBrush); ComRelease(g_dxBrush); ComRelease(g_dxSurf);
  ComRelease(g_glVis); ComRelease(g_glSprite); ComRelease(g_glCBrush); ComRelease(g_glBrush); ComRelease(g_glSurf);
  ComRelease(g_rootVisual); ComRelease(g_rootContainer);
  ComRelease(g_compositionTarget); ComRelease(g_desktopTarget);
  ComRelease(g_compInterop); ComRelease(g_desktopInterop); ComRelease(g_compositor);

  { Vulkan }
  if g_vkDevice <> nil then vkDeviceWaitIdle(g_vkDevice);
  if g_vkFence <> nil then vkDestroyFence(g_vkDevice, g_vkFence, nil);
  if g_vkCmdPool <> nil then vkDestroyCommandPool(g_vkDevice, g_vkCmdPool, nil);
  if g_vkPipeline <> nil then vkDestroyPipeline(g_vkDevice, g_vkPipeline, nil);
  if g_vkPipelineLayout <> nil then vkDestroyPipelineLayout(g_vkDevice, g_vkPipelineLayout, nil);
  if g_vkFramebuffer <> nil then vkDestroyFramebuffer(g_vkDevice, g_vkFramebuffer, nil);
  if g_vkRenderPass <> nil then vkDestroyRenderPass(g_vkDevice, g_vkRenderPass, nil);
  if g_vkOffView <> nil then vkDestroyImageView(g_vkDevice, g_vkOffView, nil);
  if g_vkOffImage <> nil then vkDestroyImage(g_vkDevice, g_vkOffImage, nil);
  if g_vkOffMemory <> nil then vkFreeMemory(g_vkDevice, g_vkOffMemory, nil);
  if g_vkReadbackBuf <> nil then vkDestroyBuffer(g_vkDevice, g_vkReadbackBuf, nil);
  if g_vkReadbackMem <> nil then vkFreeMemory(g_vkDevice, g_vkReadbackMem, nil);
  if g_vkDevice <> nil then vkDestroyDevice(g_vkDevice, nil);
  if g_vkInstance <> nil then vkDestroyInstance(g_vkInstance, nil);
  ComRelease(g_vkStagingTex); ComRelease(g_vkBackBuffer);

  { OpenGL interop }
  if (g_glInteropObject <> nil) and (g_glInteropDevice <> nil) then
    TGLProc_DXUnregisterObj(p_wglDXUnregisterObjectNV)(g_glInteropDevice, g_glInteropObject);
  if g_glInteropDevice <> nil then
    TGLProc_DXCloseDevice(p_wglDXCloseDeviceNV)(g_glInteropDevice);
  if (g_hdc <> 0) and (g_hglrc <> 0) then wglMakeCurrent(g_hdc, g_hglrc);
  if (g_glProgram <> 0) and (p_glDeleteProgram <> nil) then TGLProc_DelProg(p_glDeleteProgram)(g_glProgram);
  if (g_glVbo[0] <> 0) and (p_glDeleteBuffers <> nil) then TGLProc1u(p_glDeleteBuffers)(2, @g_glVbo[0]);
  if (g_glVao <> 0) and (p_glDeleteVertexArrays <> nil) then TGLProc1u(p_glDeleteVertexArrays)(1, @g_glVao);
  if (g_glFbo <> 0) and (p_glDeleteFramebuffers <> nil) then TGLProc1u(p_glDeleteFramebuffers)(1, @g_glFbo);
  if (g_glRbo <> 0) and (p_glDeleteRenderbuffers <> nil) then TGLProc1u(p_glDeleteRenderbuffers)(1, @g_glRbo);
  if g_hglrc <> 0 then begin wglMakeCurrent(0, 0); wglDeleteContext(g_hglrc); end;
  if g_hdc <> 0 then ReleaseDC(g_hwnd, g_hdc);

  { D3D11 }
  ComRelease(g_vb); ComRelease(g_inputLayout); ComRelease(g_ps); ComRelease(g_vs);
  ComRelease(g_dxRtv); ComRelease(g_rtv); ComRelease(g_backBuffer);
  ComRelease(g_dxSwapChain); ComRelease(g_vkSwapChain); ComRelease(g_swapChain);
  ComRelease(g_d3dCtx); ComRelease(g_d3dDevice);

  ComRelease(g_dqController);
  RoUninitialize;
  CoUninitialize;

  Dbg('Cleanup ok');
end;

(* ============================================================
 * Entry point
 * ============================================================ *)
var
  msg: TMsg;
begin
  Dbg('=== main start ===');
  if not CreateAppWindow(HInstance) then begin Dbg('CreateAppWindow failed'); Halt(1); end;
  if not InitD3D11 then begin Dbg('InitD3D11 failed'); Cleanup; Halt(1); end;
  if not InitOpenGL then begin Dbg('InitOpenGL failed'); Cleanup; Halt(1); end;
  if not InitD3D11SecondPanel then begin Dbg('InitD3D11SecondPanel failed'); Cleanup; Halt(1); end;
  if not InitVulkanPanel then begin Dbg('InitVulkanPanel failed'); Cleanup; Halt(1); end;
  if not InitComposition then begin Dbg('InitComposition failed'); Cleanup; Halt(1); end;

  Dbg('=== ENTERING MESSAGE LOOP ===');
  FillChar(msg, SizeOf(msg), 0);
  while msg.message <> WM_QUIT do begin
    if PeekMessageW(msg, 0, 0, 0, PM_REMOVE) then begin
      TranslateMessage(msg);
      DispatchMessageW(msg);
    end else
      Render;
  end;

  Dbg('loop end');
  Cleanup;
end.
	
