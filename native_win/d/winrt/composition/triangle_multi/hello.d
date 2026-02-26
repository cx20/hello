// hello.d
// Win32 window + OpenGL 4.6 / D3D11 / Vulkan triangles composited via
// Windows.UI.Composition DesktopWindowTarget on classic desktop apps.
//
// D language port of the C implementation. Uses raw COM vtable calls
// for WinRT interfaces and dynamic loading for all graphics DLLs.
//
// Build (LDC):
//   ldc2 -mtriple=x86_64-pc-windows-msvc hello.d -L/SUBSYSTEM:WINDOWS ^
//        -L/ENTRY:wmainCRTStartup
//
// Build (DMD, 64-bit):
//   dmd hello.d -L/SUBSYSTEM:WINDOWS -L/ENTRY:wmainCRTStartup
//
// Required DLLs at runtime:
//   d3d11.dll, dxgi.dll, d3dcompiler_47.dll, opengl32.dll, gdi32.dll,
//   vulkan-1.dll, combase.dll, CoreMessaging.dll, user32.dll, ole32.dll
//
// Required alongside executable:
//   hello_vert.spv, hello_frag.spv (compiled from hello.vert / hello.frag)

import core.sys.windows.winbase;
import core.sys.windows.windef;
import core.sys.windows.winuser;
import core.sys.windows.com;
import core.sys.windows.wingdi;
import core.stdc.stdio   : snprintf, fopen, fread, fseek, ftell, fclose, FILE, SEEK_END, SEEK_SET;
import core.stdc.string  : memcpy, memset, strlen;
import core.stdc.stdlib  : malloc, free;

pragma(lib, "user32");
pragma(lib, "gdi32");
pragma(lib, "ole32");

// ============================================================
// Basic type aliases
// ============================================================
alias UINT32 = uint;
alias INT32  = int;
alias UINT64 = ulong;
alias FLOAT  = float;

alias HSTRING   = void*;
alias HMODULE_  = void*;
alias VkFlags   = uint;
alias VkBool32  = uint;
alias VkDeviceSize = ulong;

alias VkInstance       = void*;
alias VkPhysicalDevice = void*;
alias VkDevice         = void*;
alias VkQueue          = void*;
alias VkImage          = void*;
alias VkDeviceMemory   = void*;
alias VkImageView      = void*;
alias VkBuffer         = void*;
alias VkRenderPass     = void*;
alias VkFramebuffer_   = void*;
alias VkPipelineLayout = void*;
alias VkPipeline       = void*;
alias VkCommandPool    = void*;
alias VkCommandBuffer  = void*;
alias VkFence          = void*;
alias VkShaderModule   = void*;

alias VkResult = int;
enum VK_SUCCESS = 0;
enum VK_NULL_HANDLE = null;

enum VK_STRUCTURE_TYPE_APPLICATION_INFO                 = 0;
enum VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO              = 1;
enum VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO          = 2;
enum VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO                = 3;
enum VK_STRUCTURE_TYPE_SUBMIT_INFO                       = 4;
enum VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO              = 5;
enum VK_STRUCTURE_TYPE_FENCE_CREATE_INFO                 = 8;
enum VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO                = 12;
enum VK_STRUCTURE_TYPE_IMAGE_CREATE_INFO                 = 14;
enum VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO            = 15;
enum VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO         = 16;
enum VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO = 18;
enum VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO   = 19;
enum VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO = 20;
enum VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO       = 22;
enum VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO  = 23;
enum VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO    = 24;
enum VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO    = 26;
enum VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO               = 30;
enum VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO                   = 38;
enum VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO                  = 39;
enum VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO              = 40;
enum VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO                 = 42;
enum VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO                    = 43;
enum VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO                   = 37;
enum VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO             = 28;

enum VK_API_VERSION_1_4 = (1 << 22) | (4 << 12); // 1.4.0
enum VK_IMAGE_TYPE_2D = 1;
enum VK_FORMAT_B8G8R8A8_UNORM = 44;
enum VK_SAMPLE_COUNT_1_BIT = 1;
enum VK_IMAGE_TILING_OPTIMAL = 0;
enum VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT = 0x10;
enum VK_IMAGE_USAGE_TRANSFER_SRC_BIT    = 0x01;
enum VK_IMAGE_LAYOUT_UNDEFINED                  = 0;
enum VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL    = 2;
enum VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL        = 6;
enum VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT         = 0x01;
enum VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT         = 0x02;
enum VK_MEMORY_PROPERTY_HOST_COHERENT_BIT        = 0x04;
enum VK_IMAGE_VIEW_TYPE_2D = 1;
enum VK_IMAGE_ASPECT_COLOR_BIT = 0x01;
enum VK_BUFFER_USAGE_TRANSFER_DST_BIT = 0x02;
enum VK_ATTACHMENT_LOAD_OP_CLEAR      = 1;
enum VK_ATTACHMENT_STORE_OP_STORE     = 0;
enum VK_ATTACHMENT_LOAD_OP_DONT_CARE  = 2;
enum VK_ATTACHMENT_STORE_OP_DONT_CARE = 1;
enum VK_PIPELINE_BIND_POINT_GRAPHICS  = 0;
enum VK_SHADER_STAGE_VERTEX_BIT       = 0x01;
enum VK_SHADER_STAGE_FRAGMENT_BIT     = 0x10;
enum VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST = 3;
enum VK_POLYGON_MODE_FILL  = 0;
enum VK_CULL_MODE_BACK_BIT = 2;
enum VK_FRONT_FACE_CLOCKWISE = 1;
enum VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT = 0x02;
enum VK_COMMAND_BUFFER_LEVEL_PRIMARY = 0;
enum VK_FENCE_CREATE_SIGNALED_BIT = 0x01;
enum VK_SUBPASS_CONTENTS_INLINE = 0;
enum VK_QUEUE_GRAPHICS_BIT = 0x01;
enum UINT32_MAX = 0xFFFFFFFF;
enum UINT64_MAX_VAL = 0xFFFFFFFFFFFFFFFF;

enum WS_EX_NOREDIRECTIONBITMAP = 0x00200000;

// ============================================================
// HSTRING header for WinRT string references
// ============================================================
struct HSTRING_HEADER
{
    union
    {
        void* Reserved1;
        byte[24] reserved;
    }
}

// ============================================================
// Vertex definition
// ============================================================
struct VERTEX
{
    FLOAT x, y, z;
    FLOAT r, g, b, a;
}

struct Vector2 { float X, Y; }
struct Vector3 { float X, Y, Z; }

// ============================================================
// DXGI / D3D11 enums and structs (minimal set needed)
// ============================================================
enum DXGI_FORMAT_B8G8R8A8_UNORM          = 87;
enum DXGI_FORMAT_R32G32B32_FLOAT         = 6;
enum DXGI_FORMAT_R32G32B32A32_FLOAT      = 2;
enum DXGI_USAGE_RENDER_TARGET_OUTPUT     = 0x00000020;
enum DXGI_SCALING_STRETCH                = 0;
enum DXGI_SWAP_EFFECT_FLIP_SEQUENTIAL    = 3;
enum DXGI_ALPHA_MODE_PREMULTIPLIED       = 1;
enum D3D_DRIVER_TYPE_HARDWARE            = 1;
enum D3D_FEATURE_LEVEL_11_0             = 0xb000;
enum D3D11_SDK_VERSION                   = 7;
enum D3D11_CREATE_DEVICE_BGRA_SUPPORT   = 0x20;
enum D3D11_USAGE_DEFAULT                 = 0;
enum D3D11_USAGE_STAGING                 = 3;
enum D3D11_BIND_VERTEX_BUFFER           = 0x01;
enum D3D11_CPU_ACCESS_WRITE              = 0x10000;
enum D3D11_INPUT_PER_VERTEX_DATA        = 0;
enum D3D11_PRIMITIVE_TOPOLOGY_TRIANGLELIST = 4;
enum D3D11_MAP_WRITE                     = 2;
enum D3DCOMPILE_ENABLE_STRICTNESS       = (1 << 11);
enum PM_REMOVE_                          = 1;
enum ERROR_CLASS_ALREADY_EXISTS          = 1410;

struct DXGI_SAMPLE_DESC { uint Count; uint Quality; }
struct DXGI_SWAP_CHAIN_DESC1
{
    uint Width, Height;
    uint Format;
    int  Stereo;
    DXGI_SAMPLE_DESC SampleDesc;
    uint BufferUsage;
    uint BufferCount;
    uint Scaling;
    uint SwapEffect;
    uint AlphaMode;
    uint Flags;
}

struct D3D11_INPUT_ELEMENT_DESC
{
    const(char)* SemanticName;
    uint SemanticIndex;
    uint Format;
    uint InputSlot;
    uint AlignedByteOffset;
    uint InputSlotClass;
    uint InstanceDataStepRate;
}

struct D3D11_BUFFER_DESC
{
    uint ByteWidth;
    uint Usage;
    uint BindFlags;
    uint CPUAccessFlags;
    uint MiscFlags;
    uint StructureByteStride;
}

struct D3D11_SUBRESOURCE_DATA
{
    const(void)* pSysMem;
    uint SysMemPitch;
    uint SysMemSlicePitch;
}

struct D3D11_VIEWPORT
{
    float TopLeftX, TopLeftY;
    float Width, Height;
    float MinDepth, MaxDepth;
}

struct D3D11_TEXTURE2D_DESC
{
    uint Width, Height;
    uint MipLevels, ArraySize;
    uint Format;
    DXGI_SAMPLE_DESC SampleDesc;
    uint Usage;
    uint BindFlags;
    uint CPUAccessFlags;
    uint MiscFlags;
}

struct D3D11_MAPPED_SUBRESOURCE
{
    void* pData;
    uint  RowPitch;
    uint  DepthPitch;
}

// ============================================================
// OpenGL constants
// ============================================================
alias GLuint     = uint;
alias GLint      = int;
alias GLsizei    = int;
alias GLenum     = uint;
alias GLboolean  = ubyte;
alias GLfloat    = float;
alias GLchar     = char;
alias GLbitfield = uint;
alias GLsizeiptr = ptrdiff_t;

enum GL_ARRAY_BUFFER       = 0x8892;
enum GL_STATIC_DRAW        = 0x88E4;
enum GL_FRAGMENT_SHADER    = 0x8B30;
enum GL_VERTEX_SHADER      = 0x8B31;
enum GL_FRAMEBUFFER        = 0x8D40;
enum GL_RENDERBUFFER       = 0x8D41;
enum GL_COLOR_ATTACHMENT0  = 0x8CE0;
enum GL_FRAMEBUFFER_COMPLETE = 0x8CD5;
enum GL_COMPILE_STATUS     = 0x8B81;
enum GL_LINK_STATUS        = 0x8B82;
enum GL_COLOR_BUFFER_BIT   = 0x00004000;
enum GL_FLOAT              = 0x1406;
enum GL_FALSE              = 0;
enum GL_TRIANGLES          = 0x0004;
enum WGL_CONTEXT_MAJOR_VERSION_ARB    = 0x2091;
enum WGL_CONTEXT_MINOR_VERSION_ARB    = 0x2092;
enum WGL_CONTEXT_FLAGS_ARB            = 0x2094;
enum WGL_CONTEXT_PROFILE_MASK_ARB     = 0x9126;
enum WGL_CONTEXT_CORE_PROFILE_BIT_ARB = 0x00000001;
enum WGL_ACCESS_READ_WRITE_NV         = 0x0001;

// ============================================================
// DispatcherQueue options (from C DispatcherQueue.h)
// ============================================================
struct DispatcherQueueOptions
{
    uint dwSize;
    int  threadType;
    int  apartmentType;
}
enum DQTYPE_THREAD_CURRENT = 2;
enum DQTAT_COM_STA         = 2;

// ============================================================
// Vulkan structures (minimal definitions)
// ============================================================
struct VkApplicationInfo
{
    int sType;
    const(void)* pNext;
    const(char)* pApplicationName;
    uint applicationVersion;
    const(char)* pEngineName;
    uint engineVersion;
    uint apiVersion;
}

struct VkInstanceCreateInfo
{
    int sType;
    const(void)* pNext;
    VkFlags flags;
    const(VkApplicationInfo)* pApplicationInfo;
    uint enabledLayerCount;
    const(char*)* ppEnabledLayerNames;
    uint enabledExtensionCount;
    const(char*)* ppEnabledExtensionNames;
}

struct VkDeviceQueueCreateInfo
{
    int sType;
    const(void)* pNext;
    VkFlags flags;
    uint queueFamilyIndex;
    uint queueCount;
    const(float)* pQueuePriorities;
}

struct VkDeviceCreateInfo
{
    int sType;
    const(void)* pNext;
    VkFlags flags;
    uint queueCreateInfoCount;
    const(VkDeviceQueueCreateInfo)* pQueueCreateInfos;
    uint enabledLayerCount;
    const(char*)* ppEnabledLayerNames;
    uint enabledExtensionCount;
    const(char*)* ppEnabledExtensionNames;
    const(void)* pEnabledFeatures;
}

struct VkExtent3D { uint width, height, depth; }
struct VkExtent2D { uint width, height; }
struct VkOffset2D { int x, y; }

struct VkImageCreateInfo
{
    int sType;
    const(void)* pNext;
    VkFlags flags;
    int imageType;
    int format;
    VkExtent3D extent;
    uint mipLevels, arrayLayers;
    int samples;
    int tiling;
    VkFlags usage;
    int sharingMode;
    uint queueFamilyIndexCount;
    const(uint)* pQueueFamilyIndices;
    int initialLayout;
}

struct VkMemoryRequirements
{
    VkDeviceSize size;
    VkDeviceSize alignment;
    uint memoryTypeBits;
}

struct VkMemoryAllocateInfo
{
    int sType;
    const(void)* pNext;
    VkDeviceSize allocationSize;
    uint memoryTypeIndex;
}

struct VkImageSubresourceRange
{
    VkFlags aspectMask;
    uint baseMipLevel, levelCount;
    uint baseArrayLayer, layerCount;
}

struct VkComponentMapping { int r, g, b, a; }

struct VkImageViewCreateInfo
{
    int sType;
    const(void)* pNext;
    VkFlags flags;
    VkImage image;
    int viewType;
    int format;
    VkComponentMapping components;
    VkImageSubresourceRange subresourceRange;
}

struct VkBufferCreateInfo
{
    int sType;
    const(void)* pNext;
    VkFlags flags;
    VkDeviceSize size;
    VkFlags usage;
    int sharingMode;
    uint queueFamilyIndexCount;
    const(uint)* pQueueFamilyIndices;
}

struct VkAttachmentDescription
{
    VkFlags flags;
    int format;
    int samples;
    int loadOp, storeOp;
    int stencilLoadOp, stencilStoreOp;
    int initialLayout, finalLayout;
}

struct VkAttachmentReference
{
    uint attachment;
    int layout;
}

struct VkSubpassDescription
{
    VkFlags flags;
    int pipelineBindPoint;
    uint inputAttachmentCount;
    const(VkAttachmentReference)* pInputAttachments;
    uint colorAttachmentCount;
    const(VkAttachmentReference)* pColorAttachments;
    const(VkAttachmentReference)* pResolveAttachments;
    const(VkAttachmentReference)* pDepthStencilAttachment;
    uint preserveAttachmentCount;
    const(uint)* pPreserveAttachments;
}

struct VkRenderPassCreateInfo
{
    int sType;
    const(void)* pNext;
    VkFlags flags;
    uint attachmentCount;
    const(VkAttachmentDescription)* pAttachments;
    uint subpassCount;
    const(VkSubpassDescription)* pSubpasses;
    uint dependencyCount;
    const(void)* pDependencies;
}

struct VkFramebufferCreateInfo
{
    int sType;
    const(void)* pNext;
    VkFlags flags;
    VkRenderPass renderPass;
    uint attachmentCount;
    const(VkImageView)* pAttachments;
    uint width, height, layers;
}

struct VkShaderModuleCreateInfo
{
    int sType;
    const(void)* pNext;
    VkFlags flags;
    size_t codeSize;
    const(uint)* pCode;
}

struct VkPipelineShaderStageCreateInfo
{
    int sType;
    const(void)* pNext;
    VkFlags flags;
    int stage;
    VkShaderModule module_;
    const(char)* pName;
    const(void)* pSpecializationInfo;
}

struct VkVertexInputBindingDescription { uint binding; uint stride; int inputRate; }
struct VkVertexInputAttributeDescription { uint location; uint binding; int format; uint offset; }

struct VkPipelineVertexInputStateCreateInfo
{
    int sType;
    const(void)* pNext;
    VkFlags flags;
    uint vertexBindingDescriptionCount;
    const(VkVertexInputBindingDescription)* pVertexBindingDescriptions;
    uint vertexAttributeDescriptionCount;
    const(VkVertexInputAttributeDescription)* pVertexAttributeDescriptions;
}

struct VkPipelineInputAssemblyStateCreateInfo
{
    int sType;
    const(void)* pNext;
    VkFlags flags;
    int topology;
    VkBool32 primitiveRestartEnable;
}

struct VkViewport { float x, y, width, height, minDepth, maxDepth; }
struct VkRect2D   { VkOffset2D offset; VkExtent2D extent; }

struct VkPipelineViewportStateCreateInfo
{
    int sType;
    const(void)* pNext;
    VkFlags flags;
    uint viewportCount;
    const(VkViewport)* pViewports;
    uint scissorCount;
    const(VkRect2D)* pScissors;
}

struct VkPipelineRasterizationStateCreateInfo
{
    int sType;
    const(void)* pNext;
    VkFlags flags;
    VkBool32 depthClampEnable;
    VkBool32 rasterizerDiscardEnable;
    int polygonMode;
    VkFlags cullMode;
    int frontFace;
    VkBool32 depthBiasEnable;
    float depthBiasConstantFactor, depthBiasClamp, depthBiasSlopeFactor;
    float lineWidth;
}

struct VkPipelineMultisampleStateCreateInfo
{
    int sType;
    const(void)* pNext;
    VkFlags flags;
    int rasterizationSamples;
    VkBool32 sampleShadingEnable;
    float minSampleShading;
    const(void)* pSampleMask;
    VkBool32 alphaToCoverageEnable;
    VkBool32 alphaToOneEnable;
}

struct VkPipelineColorBlendAttachmentState
{
    VkBool32 blendEnable;
    int srcColorBlendFactor, dstColorBlendFactor, colorBlendOp;
    int srcAlphaBlendFactor, dstAlphaBlendFactor, alphaBlendOp;
    VkFlags colorWriteMask;
}

struct VkPipelineColorBlendStateCreateInfo
{
    int sType;
    const(void)* pNext;
    VkFlags flags;
    VkBool32 logicOpEnable;
    int logicOp;
    uint attachmentCount;
    const(VkPipelineColorBlendAttachmentState)* pAttachments;
    float[4] blendConstants;
}

struct VkPipelineLayoutCreateInfo
{
    int sType;
    const(void)* pNext;
    VkFlags flags;
    uint setLayoutCount;
    const(void)* pSetLayouts;
    uint pushConstantRangeCount;
    const(void)* pPushConstantRanges;
}

struct VkGraphicsPipelineCreateInfo
{
    int sType;
    const(void)* pNext;
    VkFlags flags;
    uint stageCount;
    const(VkPipelineShaderStageCreateInfo)* pStages;
    const(VkPipelineVertexInputStateCreateInfo)* pVertexInputState;
    const(VkPipelineInputAssemblyStateCreateInfo)* pInputAssemblyState;
    const(void)* pTessellationState;
    const(VkPipelineViewportStateCreateInfo)* pViewportState;
    const(VkPipelineRasterizationStateCreateInfo)* pRasterizationState;
    const(VkPipelineMultisampleStateCreateInfo)* pMultisampleState;
    const(void)* pDepthStencilState;
    const(VkPipelineColorBlendStateCreateInfo)* pColorBlendState;
    const(void)* pDynamicState;
    VkPipelineLayout layout;
    VkRenderPass renderPass;
    uint subpass;
    VkPipeline basePipelineHandle;
    int basePipelineIndex;
}

struct VkCommandPoolCreateInfo
{
    int sType;
    const(void)* pNext;
    VkFlags flags;
    uint queueFamilyIndex;
}

struct VkCommandBufferAllocateInfo
{
    int sType;
    const(void)* pNext;
    VkCommandPool commandPool;
    int level;
    uint commandBufferCount;
}

struct VkFenceCreateInfo
{
    int sType;
    const(void)* pNext;
    VkFlags flags;
}

struct VkCommandBufferBeginInfo
{
    int sType;
    const(void)* pNext;
    VkFlags flags;
    const(void)* pInheritanceInfo;
}

struct VkClearColorValue { float[4] float32; }
struct VkClearValue      { VkClearColorValue color; }

struct VkRenderPassBeginInfo
{
    int sType;
    const(void)* pNext;
    VkRenderPass renderPass;
    VkFramebuffer_ framebuffer;
    VkRect2D renderArea;
    uint clearValueCount;
    const(VkClearValue)* pClearValues;
}

struct VkImageSubresourceLayers
{
    VkFlags aspectMask;
    uint mipLevel;
    uint baseArrayLayer, layerCount;
}

struct VkBufferImageCopy
{
    VkDeviceSize bufferOffset;
    uint bufferRowLength, bufferImageHeight;
    VkImageSubresourceLayers imageSubresource;
    VkOffset2D imageOffsetXY; int imageOffsetZ;
    VkExtent3D imageExtent;
}

struct VkSubmitInfo
{
    int sType;
    const(void)* pNext;
    uint waitSemaphoreCount;
    const(void)* pWaitSemaphores;
    const(void)* pWaitDstStageMask;
    uint commandBufferCount;
    const(VkCommandBuffer)* pCommandBuffers;
    uint signalSemaphoreCount;
    const(void)* pSignalSemaphores;
}

struct VkQueueFamilyProperties
{
    VkFlags queueFlags;
    uint queueCount;
    uint timestampValidBits;
    VkExtent3D minImageTransferGranularity;
}

struct VkMemoryType
{
    VkFlags propertyFlags;
    uint    heapIndex;
}
struct VkMemoryHeap
{
    VkDeviceSize size;
    VkFlags flags;
}
struct VkPhysicalDeviceMemoryProperties
{
    uint memoryTypeCount;
    VkMemoryType[32] memoryTypes;
    uint memoryHeapCount;
    VkMemoryHeap[16] memoryHeaps;
}

// ============================================================
// WinRT / Composition GUIDs
// ============================================================
immutable GUID IID_ICompositor =
    GUID(0xB403CA50, 0x7F8C, 0x4E83, [0x98, 0x5F, 0xA4, 0x14, 0xD2, 0x6F, 0x1D, 0xAD]);
immutable GUID IID_ICompositorDesktopInterop =
    GUID(0x29E691FA, 0x4567, 0x4DCA, [0xB3, 0x19, 0xD0, 0xF2, 0x07, 0xEB, 0x68, 0x07]);
immutable GUID IID_ICompositorInterop =
    GUID(0x25297D5C, 0x3AD4, 0x4C9C, [0xB5, 0xCF, 0xE3, 0x6A, 0x38, 0x51, 0x23, 0x30]);
immutable GUID IID_ICompositionTarget =
    GUID(0xA1BEA8BA, 0xD726, 0x4663, [0x81, 0x29, 0x6B, 0x5E, 0x79, 0x27, 0xFF, 0xA6]);
immutable GUID IID_IContainerVisual =
    GUID(0x02F6BC74, 0xED20, 0x4773, [0xAF, 0xE6, 0xD4, 0x9B, 0x4A, 0x93, 0xDB, 0x32]);
immutable GUID IID_IVisual =
    GUID(0x117E202D, 0xA859, 0x4C89, [0x87, 0x3B, 0xC2, 0xAA, 0x56, 0x67, 0x88, 0xE3]);
immutable GUID IID_ISpriteVisual =
    GUID(0x08E05581, 0x1AD1, 0x4F97, [0x97, 0x57, 0x40, 0x2D, 0x76, 0xE4, 0x23, 0x3B]);
immutable GUID IID_ICompositionBrush =
    GUID(0xAB0D7608, 0x30C0, 0x40E9, [0xB5, 0x68, 0xB6, 0x0A, 0x6B, 0xD1, 0xFB, 0x46]);
immutable GUID IID_ICompositionSurface =
    GUID(0x1527540D, 0x42C7, 0x47A6, [0xA4, 0x08, 0x66, 0x8F, 0x79, 0xA9, 0x0D, 0xFB]);

immutable GUID IID_IDXGIDevice =
    GUID(0x54ec77fa, 0x1377, 0x44e6, [0x8c, 0x32, 0x88, 0xfd, 0x5f, 0x44, 0xc8, 0x4c]);
immutable GUID IID_IDXGIFactory2 =
    GUID(0x50c83a1c, 0xe072, 0x4c48, [0x87, 0xb0, 0x36, 0x30, 0xfa, 0x36, 0xa6, 0xd0]);
immutable GUID IID_ID3D11Texture2D =
    GUID(0x6f15aaf2, 0xd208, 0x4e89, [0x9a, 0xb4, 0x48, 0x95, 0x35, 0xd3, 0x4f, 0x9c]);

enum RO_INIT_SINGLETHREADED = 0;

// ============================================================
// Debug logging via OutputDebugStringA
// ============================================================
void dbgLog(const(char)* msg) nothrow @nogc
{
    OutputDebugStringA(msg);
}

void dbgStep(const(char)* fn, const(char)* msg) nothrow @nogc
{
    char[512] buf;
    snprintf(buf.ptr, buf.length, "[STEP] %s : %s\n", fn, msg);
    OutputDebugStringA(buf.ptr);
}

void dbgHR(const(char)* fn, const(char)* api, HRESULT hr) nothrow @nogc
{
    char[512] buf;
    snprintf(buf.ptr, buf.length, "[ERR ] %s : %s failed hr=0x%08X\n", fn, api, cast(uint)hr);
    OutputDebugStringA(buf.ptr);
}

void dbgInt(const(char)* fn, const(char)* label, int val) nothrow @nogc
{
    char[512] buf;
    snprintf(buf.ptr, buf.length, "[DBG ] %s : %s = %d\n", fn, label, val);
    OutputDebugStringA(buf.ptr);
}

// ============================================================
// COM vtable helpers
// ============================================================
void** getVtbl(void* obj) nothrow @nogc
{
    return *cast(void***)obj;
}

uint comRelease(void* obj) nothrow @nogc
{
    if (obj is null) return 0;
    alias Fn = extern(Windows) uint function(void*) nothrow @nogc;
    return (cast(Fn)(getVtbl(obj)[2]))(obj);
}

HRESULT comQI(void* obj, const(GUID)* iid, void** result) nothrow @nogc
{
    alias Fn = extern(Windows) HRESULT function(void*, const(GUID)*, void**) nothrow @nogc;
    return (cast(Fn)(getVtbl(obj)[0]))(obj, iid, result);
}

// ============================================================
// WinRT Compositor vtable wrappers (slot indices from IDL)
// ============================================================

// ICompositor::CreateContainerVisual (slot 9)
HRESULT Compositor_CreateContainerVisual(void* comp, void** ppResult) nothrow @nogc
{
    alias Fn = extern(Windows) HRESULT function(void*, void**) nothrow @nogc;
    return (cast(Fn)(getVtbl(comp)[9]))(comp, ppResult);
}

// ICompositor::CreateSpriteVisual (slot 22)
HRESULT Compositor_CreateSpriteVisual(void* comp, void** ppResult) nothrow @nogc
{
    alias Fn = extern(Windows) HRESULT function(void*, void**) nothrow @nogc;
    return (cast(Fn)(getVtbl(comp)[22]))(comp, ppResult);
}

// ICompositor::CreateSurfaceBrush(surface) (slot 24)
HRESULT Compositor_CreateSurfaceBrush(void* comp, void* surface, void** ppResult) nothrow @nogc
{
    alias Fn = extern(Windows) HRESULT function(void*, void*, void**) nothrow @nogc;
    return (cast(Fn)(getVtbl(comp)[24]))(comp, surface, ppResult);
}

// ICompositorDesktopInterop::CreateDesktopWindowTarget (COM slot 3)
HRESULT CompositorDesktopInterop_CreateDesktopWindowTarget(
    void* interop, HWND hwnd, int isTopmost, void** ppResult) nothrow @nogc
{
    alias Fn = extern(Windows) HRESULT function(void*, HWND, int, void**) nothrow @nogc;
    return (cast(Fn)(getVtbl(interop)[3]))(interop, hwnd, isTopmost, ppResult);
}

// ICompositorInterop::CreateCompositionSurfaceForSwapChain (COM slot 4)
HRESULT CompositorInterop_CreateSurfaceForSwapChain(
    void* interop, void* pSwapChain, void** ppResult) nothrow @nogc
{
    alias Fn = extern(Windows) HRESULT function(void*, void*, void**) nothrow @nogc;
    return (cast(Fn)(getVtbl(interop)[4]))(interop, pSwapChain, ppResult);
}

// ICompositionTarget::put_Root (slot 7)
HRESULT CompositionTarget_put_Root(void* target, void* visual) nothrow @nogc
{
    alias Fn = extern(Windows) HRESULT function(void*, void*) nothrow @nogc;
    return (cast(Fn)(getVtbl(target)[7]))(target, visual);
}

// IContainerVisual::get_Children (slot 6)
HRESULT ContainerVisual_get_Children(void* container, void** ppResult) nothrow @nogc
{
    alias Fn = extern(Windows) HRESULT function(void*, void**) nothrow @nogc;
    return (cast(Fn)(getVtbl(container)[6]))(container, ppResult);
}

// IVisualCollection::InsertAtTop (slot 9)
HRESULT VisualCollection_InsertAtTop(void* collection, void* visual) nothrow @nogc
{
    alias Fn = extern(Windows) HRESULT function(void*, void*) nothrow @nogc;
    return (cast(Fn)(getVtbl(collection)[9]))(collection, visual);
}

// IVisual::put_Size (slot 36), Vector2 by value
HRESULT Visual_put_Size(void* visual, float w, float h) nothrow @nogc
{
    alias Fn = extern(Windows) HRESULT function(void*, Vector2) nothrow @nogc;
    Vector2 v = { w, h };
    return (cast(Fn)(getVtbl(visual)[36]))(visual, v);
}

// IVisual::put_Offset (slot 21), Vector3 by value
HRESULT Visual_put_Offset(void* visual, float x, float y, float z) nothrow @nogc
{
    alias Fn = extern(Windows) HRESULT function(void*, Vector3) nothrow @nogc;
    Vector3 v = { x, y, z };
    return (cast(Fn)(getVtbl(visual)[21]))(visual, v);
}

// ISpriteVisual::put_Brush (slot 7)
HRESULT SpriteVisual_put_Brush(void* sprite, void* brush) nothrow @nogc
{
    alias Fn = extern(Windows) HRESULT function(void*, void*) nothrow @nogc;
    return (cast(Fn)(getVtbl(sprite)[7]))(sprite, brush);
}

// ============================================================
// Dynamic function pointer types
// ============================================================
extern(Windows) nothrow @nogc
{
    // combase.dll
    alias pWindowsCreateStringReference = HRESULT function(
        const(wchar)*, uint, HSTRING_HEADER*, HSTRING*);
    alias pRoInitialize      = HRESULT function(uint);
    alias pRoUninitialize    = void function();
    alias pRoActivateInstance = HRESULT function(HSTRING, void**);

    // CoreMessaging.dll
    alias pCreateDispatcherQueueController = HRESULT function(
        DispatcherQueueOptions, void**);

    // d3d11.dll
    alias pD3D11CreateDevice = HRESULT function(
        void* pAdapter, uint driverType, void* software, uint flags,
        const(uint)* featureLevels, uint numLevels, uint sdkVersion,
        void** ppDevice, uint* pFeatureLevel, void** ppContext);

    // d3dcompiler_47.dll
    alias pD3DCompile = HRESULT function(
        const(void)* pSrcData, size_t srcDataSize,
        const(char)* pSourceName,
        const(void)* pDefines, const(void)* pInclude,
        const(char)* pEntrypoint, const(char)* pTarget,
        uint flags1, uint flags2,
        void** ppCode, void** ppErrorMsgs);

    // opengl32.dll / wgl
    alias pWglCreateContext     = HGLRC function(HDC);
    alias pWglDeleteContext     = int function(HGLRC);
    alias pWglMakeCurrent       = int function(HDC, HGLRC);
    alias pWglGetProcAddress_   = void* function(const(char)*);
    alias pChoosePixelFormat_   = int function(HDC, const(PIXELFORMATDESCRIPTOR)*);
    alias pSetPixelFormat_      = int function(HDC, int, const(PIXELFORMATDESCRIPTOR)*);

    // GL extension procs
    alias pGlGenBuffers        = void function(GLsizei, GLuint*);
    alias pGlBindBuffer        = void function(GLenum, GLuint);
    alias pGlBufferData        = void function(GLenum, GLsizeiptr, const(void)*, GLenum);
    alias pGlCreateShader      = GLuint function(GLenum);
    alias pGlShaderSource      = void function(GLuint, GLsizei, const(GLchar*)*, const(GLint)*);
    alias pGlCompileShader     = void function(GLuint);
    alias pGlGetShaderiv       = void function(GLuint, GLenum, GLint*);
    alias pGlGetShaderInfoLog  = void function(GLuint, GLsizei, GLsizei*, GLchar*);
    alias pGlCreateProgram     = GLuint function();
    alias pGlAttachShader      = void function(GLuint, GLuint);
    alias pGlLinkProgram       = void function(GLuint);
    alias pGlGetProgramiv      = void function(GLuint, GLenum, GLint*);
    alias pGlGetProgramInfoLog = void function(GLuint, GLsizei, GLsizei*, GLchar*);
    alias pGlUseProgram        = void function(GLuint);
    alias pGlGetAttribLocation = GLint function(GLuint, const(GLchar)*);
    alias pGlEnableVertexAttribArray = void function(GLuint);
    alias pGlVertexAttribPointer = void function(GLuint, GLint, GLenum, GLboolean, GLsizei, const(void)*);
    alias pGlGenVertexArrays   = void function(GLsizei, GLuint*);
    alias pGlBindVertexArray   = void function(GLuint);
    alias pGlGenFramebuffers   = void function(GLsizei, GLuint*);
    alias pGlBindFramebuffer   = void function(GLenum, GLuint);
    alias pGlFramebufferRenderbuffer = void function(GLenum, GLenum, GLenum, GLuint);
    alias pGlCheckFramebufferStatus  = GLenum function(GLenum);
    alias pGlGenRenderbuffers  = void function(GLsizei, GLuint*);
    alias pGlBindRenderbuffer  = void function(GLenum, GLuint);
    alias pGlDeleteBuffers     = void function(GLsizei, const(GLuint)*);
    alias pGlDeleteVertexArrays = void function(GLsizei, const(GLuint)*);
    alias pGlDeleteFramebuffers = void function(GLsizei, const(GLuint)*);
    alias pGlDeleteRenderbuffers = void function(GLsizei, const(GLuint)*);
    alias pGlDeleteProgram     = void function(GLuint);
    alias pGlViewport          = void function(GLint, GLint, GLsizei, GLsizei);
    alias pGlClearColor        = void function(GLfloat, GLfloat, GLfloat, GLfloat);
    alias pGlClear             = void function(GLbitfield);
    alias pGlDrawArrays        = void function(GLenum, GLint, GLsizei);
    alias pGlFlush             = void function();

    alias pWglCreateContextAttribsARB = HGLRC function(HDC, HGLRC, const(int)*);
    alias pWglDXOpenDeviceNV       = void* function(void*);
    alias pWglDXCloseDeviceNV      = int function(void*);
    alias pWglDXRegisterObjectNV   = void* function(void*, void*, GLuint, GLenum, GLenum);
    alias pWglDXUnregisterObjectNV = int function(void*, void*);
    alias pWglDXLockObjectsNV      = int function(void*, GLint, void**);
    alias pWglDXUnlockObjectsNV    = int function(void*, GLint, void**);

    // Vulkan function pointers
    alias pvkCreateInstance       = VkResult function(const(VkInstanceCreateInfo)*, const(void)*, VkInstance*);
    alias pvkEnumeratePhysicalDevices = VkResult function(VkInstance, uint*, VkPhysicalDevice*);
    alias pvkGetPhysicalDeviceQueueFamilyProperties = void function(VkPhysicalDevice, uint*, VkQueueFamilyProperties*);
    alias pvkCreateDevice         = VkResult function(VkPhysicalDevice, const(VkDeviceCreateInfo)*, const(void)*, VkDevice*);
    alias pvkGetDeviceQueue       = void function(VkDevice, uint, uint, VkQueue*);
    alias pvkCreateImage          = VkResult function(VkDevice, const(VkImageCreateInfo)*, const(void)*, VkImage*);
    alias pvkGetImageMemoryRequirements = void function(VkDevice, VkImage, VkMemoryRequirements*);
    alias pvkAllocateMemory       = VkResult function(VkDevice, const(VkMemoryAllocateInfo)*, const(void)*, VkDeviceMemory*);
    alias pvkBindImageMemory      = VkResult function(VkDevice, VkImage, VkDeviceMemory, VkDeviceSize);
    alias pvkCreateImageView      = VkResult function(VkDevice, const(VkImageViewCreateInfo)*, const(void)*, VkImageView*);
    alias pvkCreateBuffer         = VkResult function(VkDevice, const(VkBufferCreateInfo)*, const(void)*, VkBuffer*);
    alias pvkGetBufferMemoryRequirements = void function(VkDevice, VkBuffer, VkMemoryRequirements*);
    alias pvkBindBufferMemory     = VkResult function(VkDevice, VkBuffer, VkDeviceMemory, VkDeviceSize);
    alias pvkCreateRenderPass     = VkResult function(VkDevice, const(VkRenderPassCreateInfo)*, const(void)*, VkRenderPass*);
    alias pvkCreateFramebuffer    = VkResult function(VkDevice, const(VkFramebufferCreateInfo)*, const(void)*, VkFramebuffer_*);
    alias pvkCreateShaderModule   = VkResult function(VkDevice, const(VkShaderModuleCreateInfo)*, const(void)*, VkShaderModule*);
    alias pvkCreatePipelineLayout = VkResult function(VkDevice, const(VkPipelineLayoutCreateInfo)*, const(void)*, VkPipelineLayout*);
    alias pvkCreateGraphicsPipelines = VkResult function(VkDevice, void*, uint, const(VkGraphicsPipelineCreateInfo)*, const(void)*, VkPipeline*);
    alias pvkCreateCommandPool    = VkResult function(VkDevice, const(VkCommandPoolCreateInfo)*, const(void)*, VkCommandPool*);
    alias pvkAllocateCommandBuffers = VkResult function(VkDevice, const(VkCommandBufferAllocateInfo)*, VkCommandBuffer*);
    alias pvkCreateFence          = VkResult function(VkDevice, const(VkFenceCreateInfo)*, const(void)*, VkFence*);
    alias pvkWaitForFences        = VkResult function(VkDevice, uint, const(VkFence)*, VkBool32, ulong);
    alias pvkResetFences          = VkResult function(VkDevice, uint, const(VkFence)*);
    alias pvkResetCommandBuffer   = VkResult function(VkCommandBuffer, VkFlags);
    alias pvkBeginCommandBuffer   = VkResult function(VkCommandBuffer, const(VkCommandBufferBeginInfo)*);
    alias pvkEndCommandBuffer     = VkResult function(VkCommandBuffer);
    alias pvkCmdBeginRenderPass   = void function(VkCommandBuffer, const(VkRenderPassBeginInfo)*, int);
    alias pvkCmdEndRenderPass     = void function(VkCommandBuffer);
    alias pvkCmdBindPipeline      = void function(VkCommandBuffer, int, VkPipeline);
    alias pvkCmdDraw              = void function(VkCommandBuffer, uint, uint, uint, uint);
    alias pvkCmdCopyImageToBuffer = void function(VkCommandBuffer, VkImage, int, VkBuffer, uint, const(VkBufferImageCopy)*);
    alias pvkQueueSubmit          = VkResult function(VkQueue, uint, const(VkSubmitInfo)*, VkFence);
    alias pvkMapMemory            = VkResult function(VkDevice, VkDeviceMemory, VkDeviceSize, VkDeviceSize, VkFlags, void**);
    alias pvkUnmapMemory          = void function(VkDevice, VkDeviceMemory);
    alias pvkDeviceWaitIdle       = VkResult function(VkDevice);
    alias pvkDestroyFence         = void function(VkDevice, VkFence, const(void)*);
    alias pvkDestroyCommandPool   = void function(VkDevice, VkCommandPool, const(void)*);
    alias pvkDestroyPipeline      = void function(VkDevice, VkPipeline, const(void)*);
    alias pvkDestroyPipelineLayout = void function(VkDevice, VkPipelineLayout, const(void)*);
    alias pvkDestroyFramebuffer   = void function(VkDevice, VkFramebuffer_, const(void)*);
    alias pvkDestroyRenderPass    = void function(VkDevice, VkRenderPass, const(void)*);
    alias pvkDestroyImageView     = void function(VkDevice, VkImageView, const(void)*);
    alias pvkDestroyImage         = void function(VkDevice, VkImage, const(void)*);
    alias pvkFreeMemory           = void function(VkDevice, VkDeviceMemory, const(void)*);
    alias pvkDestroyBuffer        = void function(VkDevice, VkBuffer, const(void)*);
    alias pvkDestroyDevice        = void function(VkDevice, const(void)*);
    alias pvkDestroyInstance      = void function(VkInstance, const(void)*);
    alias pvkDestroyShaderModule  = void function(VkDevice, VkShaderModule, const(void)*);
    alias pvkGetPhysicalDeviceMemoryProperties = void function(VkPhysicalDevice, VkPhysicalDeviceMemoryProperties*);
}

// ============================================================
// Global function pointers (loaded dynamically)
// ============================================================
__gshared pWindowsCreateStringReference WindowsCreateStringReference;
__gshared pRoInitialize      RoInitialize;
__gshared pRoUninitialize    RoUninitialize;
__gshared pRoActivateInstance RoActivateInstance;
__gshared pCreateDispatcherQueueController fnCreateDispatcherQueueController;
__gshared pD3D11CreateDevice  fnD3D11CreateDevice;
__gshared pD3DCompile         fnD3DCompile;

// OpenGL base
__gshared pWglCreateContext     fn_wglCreateContext;
__gshared pWglDeleteContext     fn_wglDeleteContext;
__gshared pWglMakeCurrent       fn_wglMakeCurrent;
__gshared pWglGetProcAddress_   fn_wglGetProcAddress;
__gshared pGlViewport     fn_glViewport;
__gshared pGlClearColor   fn_glClearColor;
__gshared pGlClear        fn_glClear;
__gshared pGlDrawArrays   fn_glDrawArrays;
__gshared pGlFlush        fn_glFlush;

// GL extension functions
__gshared pGlGenBuffers        fn_glGenBuffers;
__gshared pGlBindBuffer        fn_glBindBuffer;
__gshared pGlBufferData        fn_glBufferData;
__gshared pGlCreateShader      fn_glCreateShader;
__gshared pGlShaderSource      fn_glShaderSource;
__gshared pGlCompileShader     fn_glCompileShader;
__gshared pGlGetShaderiv       fn_glGetShaderiv;
__gshared pGlGetShaderInfoLog  fn_glGetShaderInfoLog;
__gshared pGlCreateProgram     fn_glCreateProgram;
__gshared pGlAttachShader      fn_glAttachShader;
__gshared pGlLinkProgram       fn_glLinkProgram;
__gshared pGlGetProgramiv      fn_glGetProgramiv;
__gshared pGlGetProgramInfoLog fn_glGetProgramInfoLog;
__gshared pGlUseProgram        fn_glUseProgram;
__gshared pGlGetAttribLocation fn_glGetAttribLocation;
__gshared pGlEnableVertexAttribArray fn_glEnableVertexAttribArray;
__gshared pGlVertexAttribPointer fn_glVertexAttribPointer;
__gshared pGlGenVertexArrays   fn_glGenVertexArrays;
__gshared pGlBindVertexArray   fn_glBindVertexArray;
__gshared pGlGenFramebuffers   fn_glGenFramebuffers;
__gshared pGlBindFramebuffer   fn_glBindFramebuffer;
__gshared pGlFramebufferRenderbuffer fn_glFramebufferRenderbuffer;
__gshared pGlCheckFramebufferStatus  fn_glCheckFramebufferStatus;
__gshared pGlGenRenderbuffers  fn_glGenRenderbuffers;
__gshared pGlBindRenderbuffer  fn_glBindRenderbuffer;
__gshared pGlDeleteBuffers     fn_glDeleteBuffers;
__gshared pGlDeleteVertexArrays fn_glDeleteVertexArrays;
__gshared pGlDeleteFramebuffers fn_glDeleteFramebuffers;
__gshared pGlDeleteRenderbuffers fn_glDeleteRenderbuffers;
__gshared pGlDeleteProgram     fn_glDeleteProgram;

__gshared pWglCreateContextAttribsARB fn_wglCreateContextAttribsARB;
__gshared pWglDXOpenDeviceNV       fn_wglDXOpenDeviceNV;
__gshared pWglDXCloseDeviceNV      fn_wglDXCloseDeviceNV;
__gshared pWglDXRegisterObjectNV   fn_wglDXRegisterObjectNV;
__gshared pWglDXUnregisterObjectNV fn_wglDXUnregisterObjectNV;
__gshared pWglDXLockObjectsNV      fn_wglDXLockObjectsNV;
__gshared pWglDXUnlockObjectsNV    fn_wglDXUnlockObjectsNV;

// Vulkan function pointers
__gshared pvkCreateInstance       fn_vkCreateInstance;
__gshared pvkEnumeratePhysicalDevices fn_vkEnumeratePhysicalDevices;
__gshared pvkGetPhysicalDeviceQueueFamilyProperties fn_vkGetPhysicalDeviceQueueFamilyProperties;
__gshared pvkCreateDevice         fn_vkCreateDevice;
__gshared pvkGetDeviceQueue       fn_vkGetDeviceQueue;
__gshared pvkCreateImage          fn_vkCreateImage;
__gshared pvkGetImageMemoryRequirements fn_vkGetImageMemoryRequirements;
__gshared pvkAllocateMemory       fn_vkAllocateMemory;
__gshared pvkBindImageMemory      fn_vkBindImageMemory;
__gshared pvkCreateImageView      fn_vkCreateImageView;
__gshared pvkCreateBuffer         fn_vkCreateBuffer;
__gshared pvkGetBufferMemoryRequirements fn_vkGetBufferMemoryRequirements;
__gshared pvkBindBufferMemory     fn_vkBindBufferMemory;
__gshared pvkCreateRenderPass     fn_vkCreateRenderPass;
__gshared pvkCreateFramebuffer    fn_vkCreateFramebuffer;
__gshared pvkCreateShaderModule   fn_vkCreateShaderModule;
__gshared pvkCreatePipelineLayout fn_vkCreatePipelineLayout;
__gshared pvkCreateGraphicsPipelines fn_vkCreateGraphicsPipelines;
__gshared pvkCreateCommandPool    fn_vkCreateCommandPool;
__gshared pvkAllocateCommandBuffers fn_vkAllocateCommandBuffers;
__gshared pvkCreateFence          fn_vkCreateFence;
__gshared pvkWaitForFences        fn_vkWaitForFences;
__gshared pvkResetFences          fn_vkResetFences;
__gshared pvkResetCommandBuffer   fn_vkResetCommandBuffer;
__gshared pvkBeginCommandBuffer   fn_vkBeginCommandBuffer;
__gshared pvkEndCommandBuffer     fn_vkEndCommandBuffer;
__gshared pvkCmdBeginRenderPass   fn_vkCmdBeginRenderPass;
__gshared pvkCmdEndRenderPass     fn_vkCmdEndRenderPass;
__gshared pvkCmdBindPipeline      fn_vkCmdBindPipeline;
__gshared pvkCmdDraw              fn_vkCmdDraw;
__gshared pvkCmdCopyImageToBuffer fn_vkCmdCopyImageToBuffer;
__gshared pvkQueueSubmit          fn_vkQueueSubmit;
__gshared pvkMapMemory            fn_vkMapMemory;
__gshared pvkUnmapMemory          fn_vkUnmapMemory;
__gshared pvkDeviceWaitIdle       fn_vkDeviceWaitIdle;
__gshared pvkDestroyFence         fn_vkDestroyFence;
__gshared pvkDestroyCommandPool   fn_vkDestroyCommandPool;
__gshared pvkDestroyPipeline      fn_vkDestroyPipeline;
__gshared pvkDestroyPipelineLayout fn_vkDestroyPipelineLayout;
__gshared pvkDestroyFramebuffer   fn_vkDestroyFramebuffer;
__gshared pvkDestroyRenderPass    fn_vkDestroyRenderPass;
__gshared pvkDestroyImageView     fn_vkDestroyImageView;
__gshared pvkDestroyImage         fn_vkDestroyImage;
__gshared pvkFreeMemory           fn_vkFreeMemory;
__gshared pvkDestroyBuffer        fn_vkDestroyBuffer;
__gshared pvkDestroyDevice        fn_vkDestroyDevice;
__gshared pvkDestroyInstance      fn_vkDestroyInstance;
__gshared pvkDestroyShaderModule  fn_vkDestroyShaderModule;
__gshared pvkGetPhysicalDeviceMemoryProperties fn_vkGetPhysicalDeviceMemoryProperties;

// ============================================================
// Global state
// ============================================================
__gshared HWND g_hwnd;
__gshared uint g_width  = 320;
__gshared uint g_height = 480;
__gshared uint g_windowWidth = 960;
__gshared bool g_comInitialized = false;

// DispatcherQueue controller (must stay alive)
__gshared void* g_dqController;

// D3D11 objects (stored as opaque COM pointers)
__gshared void* g_d3dDevice;
__gshared void* g_d3dCtx;
__gshared void* g_swapChain;
__gshared void* g_backBuffer;      // ID3D11Texture2D for GL interop
__gshared void* g_rtv;
__gshared void* g_dxSwapChain;     // D3D11 second panel
__gshared void* g_dxRtv;
__gshared void* g_vkSwapChain;     // Vulkan third panel
__gshared void* g_vkBackBuffer;
__gshared void* g_vkStagingTex;
__gshared void* g_d3dVS;
__gshared void* g_d3dPS;
__gshared void* g_inputLayout;
__gshared void* g_d3dVB;

// OpenGL objects
__gshared HDC   g_hdc;
__gshared HGLRC g_hglrc;
__gshared void* g_glInteropDevice;
__gshared void* g_glInteropObject;
__gshared GLuint[2] g_glVbo;
__gshared GLuint g_glVao;
__gshared GLuint g_glProgram;
__gshared GLuint g_glRbo;
__gshared GLuint g_glFbo;
__gshared GLint  g_glPosAttrib = -1;
__gshared GLint  g_glColAttrib = -1;

// Composition objects (WinRT, opaque pointers)
__gshared void* g_compositor;
__gshared void* g_desktopTarget;
__gshared void* g_rootVisual;
__gshared void* g_spriteVisual;
__gshared void* g_compositionSurface;
__gshared void* g_surfaceBrush;
__gshared void* g_visualCollection;
__gshared void* g_compositionTarget;
__gshared void* g_visual;
__gshared void* g_compositionBrush;

// Second panel (D3D11)
__gshared void* g_dxSpriteVisual;
__gshared void* g_dxCompositionSurface;
__gshared void* g_dxSurfaceBrush;
__gshared void* g_dxCompositionBrush;
__gshared void* g_dxVisual;

// Third panel (Vulkan)
__gshared void* g_vkSpriteVisual;
__gshared void* g_vkCompositionSurface;
__gshared void* g_vkSurfaceBrush;
__gshared void* g_vkCompositionBrush;
__gshared void* g_vkVisualObj;

// Vulkan state
__gshared VkInstance       g_vkInst;
__gshared VkPhysicalDevice g_vkPhysDev;
__gshared VkDevice         g_vkDev;
__gshared uint             g_vkQueueFamily = UINT32_MAX;
__gshared VkQueue          g_vkQueue;
__gshared VkImage          g_vkOffImage;
__gshared VkDeviceMemory   g_vkOffMemory;
__gshared VkImageView      g_vkOffView;
__gshared VkBuffer         g_vkReadbackBuf;
__gshared VkDeviceMemory   g_vkReadbackMem;
__gshared VkRenderPass     g_vkRenderPass;
__gshared VkFramebuffer_   g_vkFramebuffer;
__gshared VkPipelineLayout g_vkPipeLayout;
__gshared VkPipeline       g_vkPipeline;
__gshared VkCommandPool    g_vkCmdPool;
__gshared VkCommandBuffer  g_vkCmdBuf;
__gshared VkFence          g_vkFence;

// Compositor interop interfaces
__gshared void* g_desktopInterop;
__gshared void* g_compInterop;

// ============================================================
// OpenGL shader sources (GLSL 460)
// ============================================================
__gshared immutable(char)* kVS_GLSL =
    "#version 460 core\n"
    ~ "layout(location=0) in vec3 position;\n"
    ~ "layout(location=1) in vec3 color;\n"
    ~ "out vec4 vColor;\n"
    ~ "void main(){ vColor=vec4(color,1.0); gl_Position=vec4(position.x,-position.y,position.z,1.0); }\n\0";

__gshared immutable(char)* kPS_GLSL =
    "#version 460 core\n"
    ~ "in vec4 vColor;\n"
    ~ "out vec4 outColor;\n"
    ~ "void main(){ outColor=vColor; }\n\0";

// D3D11 HLSL shader sources
__gshared immutable(char)* kVS_HLSL =
    "struct VSInput { float3 pos:POSITION; float4 col:COLOR; };\n"
    ~ "struct VSOutput{ float4 pos:SV_POSITION; float4 col:COLOR; };\n"
    ~ "VSOutput main(VSInput i){ VSOutput o; o.pos=float4(i.pos,1); o.col=i.col; return o; }\n\0";

__gshared immutable(char)* kPS_HLSL =
    "struct PSInput { float4 pos:SV_POSITION; float4 col:COLOR; };\n"
    ~ "float4 main(PSInput i):SV_TARGET{ return i.col; }\n\0";

// ============================================================
// DLL loading helpers
// ============================================================
bool loadCombaseFunctions()
{
    HMODULE hLib = LoadLibraryA("combase.dll");
    if (hLib is null) return false;
    WindowsCreateStringReference = cast(pWindowsCreateStringReference)
        GetProcAddress(hLib, "WindowsCreateStringReference");
    RoInitialize = cast(pRoInitialize)GetProcAddress(hLib, "RoInitialize");
    RoUninitialize = cast(pRoUninitialize)GetProcAddress(hLib, "RoUninitialize");
    RoActivateInstance = cast(pRoActivateInstance)GetProcAddress(hLib, "RoActivateInstance");
    return (WindowsCreateStringReference !is null)
        && (RoInitialize !is null) && (RoUninitialize !is null)
        && (RoActivateInstance !is null);
}

bool loadD3D11Functions()
{
    HMODULE hLib = LoadLibraryA("d3d11.dll");
    if (hLib is null) return false;
    fnD3D11CreateDevice = cast(pD3D11CreateDevice)GetProcAddress(hLib, "D3D11CreateDevice");
    return fnD3D11CreateDevice !is null;
}

bool loadD3DCompiler()
{
    HMODULE hLib = LoadLibraryA("d3dcompiler_47.dll");
    if (hLib is null) return false;
    fnD3DCompile = cast(pD3DCompile)GetProcAddress(hLib, "D3DCompile");
    return fnD3DCompile !is null;
}

bool loadCoreMessaging()
{
    HMODULE hLib = LoadLibraryA("CoreMessaging.dll");
    if (hLib is null) return false;
    fnCreateDispatcherQueueController = cast(pCreateDispatcherQueueController)
        GetProcAddress(hLib, "CreateDispatcherQueueController");
    return fnCreateDispatcherQueueController !is null;
}

bool loadOpenGL32()
{
    HMODULE hLib = LoadLibraryA("opengl32.dll");
    if (hLib is null) return false;
    fn_wglCreateContext   = cast(pWglCreateContext)GetProcAddress(hLib, "wglCreateContext");
    fn_wglDeleteContext   = cast(pWglDeleteContext)GetProcAddress(hLib, "wglDeleteContext");
    fn_wglMakeCurrent     = cast(pWglMakeCurrent)GetProcAddress(hLib, "wglMakeCurrent");
    fn_wglGetProcAddress  = cast(pWglGetProcAddress_)GetProcAddress(hLib, "wglGetProcAddress");
    fn_glViewport   = cast(pGlViewport)GetProcAddress(hLib, "glViewport");
    fn_glClearColor = cast(pGlClearColor)GetProcAddress(hLib, "glClearColor");
    fn_glClear      = cast(pGlClear)GetProcAddress(hLib, "glClear");
    fn_glDrawArrays = cast(pGlDrawArrays)GetProcAddress(hLib, "glDrawArrays");
    fn_glFlush      = cast(pGlFlush)GetProcAddress(hLib, "glFlush");
    return (fn_wglCreateContext !is null) && (fn_wglMakeCurrent !is null)
        && (fn_wglGetProcAddress !is null);
}

void* getGLProc(const(char)* name)
{
    void* p = fn_wglGetProcAddress(name);
    if (p is null || p == cast(void*)0x1 || p == cast(void*)0x2
        || p == cast(void*)0x3 || p == cast(void*)(-1))
    {
        HMODULE h = GetModuleHandleA("opengl32.dll");
        if (h !is null) p = cast(void*)GetProcAddress(h, name);
    }
    return p;
}

bool loadVulkan()
{
    HMODULE hLib = LoadLibraryA("vulkan-1.dll");
    if (hLib is null) return false;
    fn_vkCreateInstance   = cast(pvkCreateInstance)GetProcAddress(hLib, "vkCreateInstance");
    fn_vkEnumeratePhysicalDevices = cast(pvkEnumeratePhysicalDevices)GetProcAddress(hLib, "vkEnumeratePhysicalDevices");
    fn_vkGetPhysicalDeviceQueueFamilyProperties = cast(pvkGetPhysicalDeviceQueueFamilyProperties)GetProcAddress(hLib, "vkGetPhysicalDeviceQueueFamilyProperties");
    fn_vkCreateDevice     = cast(pvkCreateDevice)GetProcAddress(hLib, "vkCreateDevice");
    fn_vkGetDeviceQueue   = cast(pvkGetDeviceQueue)GetProcAddress(hLib, "vkGetDeviceQueue");
    fn_vkCreateImage      = cast(pvkCreateImage)GetProcAddress(hLib, "vkCreateImage");
    fn_vkGetImageMemoryRequirements = cast(pvkGetImageMemoryRequirements)GetProcAddress(hLib, "vkGetImageMemoryRequirements");
    fn_vkAllocateMemory   = cast(pvkAllocateMemory)GetProcAddress(hLib, "vkAllocateMemory");
    fn_vkBindImageMemory  = cast(pvkBindImageMemory)GetProcAddress(hLib, "vkBindImageMemory");
    fn_vkCreateImageView  = cast(pvkCreateImageView)GetProcAddress(hLib, "vkCreateImageView");
    fn_vkCreateBuffer     = cast(pvkCreateBuffer)GetProcAddress(hLib, "vkCreateBuffer");
    fn_vkGetBufferMemoryRequirements = cast(pvkGetBufferMemoryRequirements)GetProcAddress(hLib, "vkGetBufferMemoryRequirements");
    fn_vkBindBufferMemory = cast(pvkBindBufferMemory)GetProcAddress(hLib, "vkBindBufferMemory");
    fn_vkCreateRenderPass = cast(pvkCreateRenderPass)GetProcAddress(hLib, "vkCreateRenderPass");
    fn_vkCreateFramebuffer = cast(pvkCreateFramebuffer)GetProcAddress(hLib, "vkCreateFramebuffer");
    fn_vkCreateShaderModule = cast(pvkCreateShaderModule)GetProcAddress(hLib, "vkCreateShaderModule");
    fn_vkCreatePipelineLayout = cast(pvkCreatePipelineLayout)GetProcAddress(hLib, "vkCreatePipelineLayout");
    fn_vkCreateGraphicsPipelines = cast(pvkCreateGraphicsPipelines)GetProcAddress(hLib, "vkCreateGraphicsPipelines");
    fn_vkCreateCommandPool = cast(pvkCreateCommandPool)GetProcAddress(hLib, "vkCreateCommandPool");
    fn_vkAllocateCommandBuffers = cast(pvkAllocateCommandBuffers)GetProcAddress(hLib, "vkAllocateCommandBuffers");
    fn_vkCreateFence      = cast(pvkCreateFence)GetProcAddress(hLib, "vkCreateFence");
    fn_vkWaitForFences    = cast(pvkWaitForFences)GetProcAddress(hLib, "vkWaitForFences");
    fn_vkResetFences      = cast(pvkResetFences)GetProcAddress(hLib, "vkResetFences");
    fn_vkResetCommandBuffer = cast(pvkResetCommandBuffer)GetProcAddress(hLib, "vkResetCommandBuffer");
    fn_vkBeginCommandBuffer = cast(pvkBeginCommandBuffer)GetProcAddress(hLib, "vkBeginCommandBuffer");
    fn_vkEndCommandBuffer = cast(pvkEndCommandBuffer)GetProcAddress(hLib, "vkEndCommandBuffer");
    fn_vkCmdBeginRenderPass = cast(pvkCmdBeginRenderPass)GetProcAddress(hLib, "vkCmdBeginRenderPass");
    fn_vkCmdEndRenderPass = cast(pvkCmdEndRenderPass)GetProcAddress(hLib, "vkCmdEndRenderPass");
    fn_vkCmdBindPipeline  = cast(pvkCmdBindPipeline)GetProcAddress(hLib, "vkCmdBindPipeline");
    fn_vkCmdDraw          = cast(pvkCmdDraw)GetProcAddress(hLib, "vkCmdDraw");
    fn_vkCmdCopyImageToBuffer = cast(pvkCmdCopyImageToBuffer)GetProcAddress(hLib, "vkCmdCopyImageToBuffer");
    fn_vkQueueSubmit      = cast(pvkQueueSubmit)GetProcAddress(hLib, "vkQueueSubmit");
    fn_vkMapMemory        = cast(pvkMapMemory)GetProcAddress(hLib, "vkMapMemory");
    fn_vkUnmapMemory      = cast(pvkUnmapMemory)GetProcAddress(hLib, "vkUnmapMemory");
    fn_vkDeviceWaitIdle   = cast(pvkDeviceWaitIdle)GetProcAddress(hLib, "vkDeviceWaitIdle");
    fn_vkDestroyFence     = cast(pvkDestroyFence)GetProcAddress(hLib, "vkDestroyFence");
    fn_vkDestroyCommandPool = cast(pvkDestroyCommandPool)GetProcAddress(hLib, "vkDestroyCommandPool");
    fn_vkDestroyPipeline  = cast(pvkDestroyPipeline)GetProcAddress(hLib, "vkDestroyPipeline");
    fn_vkDestroyPipelineLayout = cast(pvkDestroyPipelineLayout)GetProcAddress(hLib, "vkDestroyPipelineLayout");
    fn_vkDestroyFramebuffer = cast(pvkDestroyFramebuffer)GetProcAddress(hLib, "vkDestroyFramebuffer");
    fn_vkDestroyRenderPass = cast(pvkDestroyRenderPass)GetProcAddress(hLib, "vkDestroyRenderPass");
    fn_vkDestroyImageView = cast(pvkDestroyImageView)GetProcAddress(hLib, "vkDestroyImageView");
    fn_vkDestroyImage     = cast(pvkDestroyImage)GetProcAddress(hLib, "vkDestroyImage");
    fn_vkFreeMemory       = cast(pvkFreeMemory)GetProcAddress(hLib, "vkFreeMemory");
    fn_vkDestroyBuffer    = cast(pvkDestroyBuffer)GetProcAddress(hLib, "vkDestroyBuffer");
    fn_vkDestroyDevice    = cast(pvkDestroyDevice)GetProcAddress(hLib, "vkDestroyDevice");
    fn_vkDestroyInstance  = cast(pvkDestroyInstance)GetProcAddress(hLib, "vkDestroyInstance");
    fn_vkDestroyShaderModule = cast(pvkDestroyShaderModule)GetProcAddress(hLib, "vkDestroyShaderModule");
    fn_vkGetPhysicalDeviceMemoryProperties = cast(pvkGetPhysicalDeviceMemoryProperties)GetProcAddress(hLib, "vkGetPhysicalDeviceMemoryProperties");
    return fn_vkCreateInstance !is null;
}

// ============================================================
// D3D11 COM vtable call helpers (via opaque void*)
// ============================================================

// Helper: call method at vtable slot on an opaque COM pointer
// Specific typed wrappers follow below.

// IDXGISwapChain1::Present (IUnknown[0..2], IDXGIObject[3..5], IDXGIDeviceSubObject[6],
//   IDXGISwapChain: slot 8=Present)
HRESULT SwapChain_Present(void* sc, uint syncInterval, uint flags) nothrow @nogc
{
    alias Fn = extern(Windows) HRESULT function(void*, uint, uint) nothrow @nogc;
    return (cast(Fn)(getVtbl(sc)[8]))(sc, syncInterval, flags);
}

// IDXGISwapChain::GetBuffer (slot 9)
HRESULT SwapChain_GetBuffer(void* sc, uint buffer, const(GUID)* iid, void** ppSurface) nothrow @nogc
{
    alias Fn = extern(Windows) HRESULT function(void*, uint, const(GUID)*, void**) nothrow @nogc;
    return (cast(Fn)(getVtbl(sc)[9]))(sc, buffer, iid, ppSurface);
}

// ID3D11Device::CreateRenderTargetView (slot 9)
HRESULT Device_CreateRenderTargetView(void* dev, void* resource, void* desc, void** ppRTV) nothrow @nogc
{
    alias Fn = extern(Windows) HRESULT function(void*, void*, void*, void**) nothrow @nogc;
    return (cast(Fn)(getVtbl(dev)[9]))(dev, resource, desc, ppRTV);
}

// ID3D11Device::CreateVertexShader (slot 12)
HRESULT Device_CreateVertexShader(void* dev, const(void)* bytecode, size_t len, void* classLinkage, void** ppVS) nothrow @nogc
{
    alias Fn = extern(Windows) HRESULT function(void*, const(void)*, size_t, void*, void**) nothrow @nogc;
    return (cast(Fn)(getVtbl(dev)[12]))(dev, bytecode, len, classLinkage, ppVS);
}

// ID3D11Device::CreatePixelShader (slot 15)
HRESULT Device_CreatePixelShader(void* dev, const(void)* bytecode, size_t len, void* classLinkage, void** ppPS) nothrow @nogc
{
    alias Fn = extern(Windows) HRESULT function(void*, const(void)*, size_t, void*, void**) nothrow @nogc;
    return (cast(Fn)(getVtbl(dev)[15]))(dev, bytecode, len, classLinkage, ppPS);
}

// ID3D11Device::CreateInputLayout (slot 11)
HRESULT Device_CreateInputLayout(void* dev, const(D3D11_INPUT_ELEMENT_DESC)* descs, uint num,
    const(void)* bytecode, size_t len, void** ppLayout) nothrow @nogc
{
    alias Fn = extern(Windows) HRESULT function(void*, const(D3D11_INPUT_ELEMENT_DESC)*, uint,
        const(void)*, size_t, void**) nothrow @nogc;
    return (cast(Fn)(getVtbl(dev)[11]))(dev, descs, num, bytecode, len, ppLayout);
}

// ID3D11Device::CreateBuffer (slot 3)
HRESULT Device_CreateBuffer(void* dev, const(D3D11_BUFFER_DESC)* desc,
    const(D3D11_SUBRESOURCE_DATA)* initData, void** ppBuf) nothrow @nogc
{
    alias Fn = extern(Windows) HRESULT function(void*, const(D3D11_BUFFER_DESC)*,
        const(D3D11_SUBRESOURCE_DATA)*, void**) nothrow @nogc;
    return (cast(Fn)(getVtbl(dev)[3]))(dev, desc, initData, ppBuf);
}

// ID3D11Device::CreateTexture2D (slot 5)
HRESULT Device_CreateTexture2D(void* dev, const(D3D11_TEXTURE2D_DESC)* desc,
    const(void)* initData, void** ppTex) nothrow @nogc
{
    alias Fn = extern(Windows) HRESULT function(void*, const(D3D11_TEXTURE2D_DESC)*, const(void)*, void**) nothrow @nogc;
    return (cast(Fn)(getVtbl(dev)[5]))(dev, desc, initData, ppTex);
}

// ID3D11Device::QueryInterface (slot 0)
// (reuse comQI)

// ID3D11DeviceContext method slots (based on ID3D11DeviceChild -> ID3D11DeviceContext):
// The context vtable starts: IUnknown(3) + ID3D11DeviceChild(3) = offset 6 for context methods
// But the actual slot indices from the full vtable are:
//   VSSetShader           = slot 11
//   PSSetShader           = slot 9
//   Draw                  = slot 13
//   Map                   = slot 14
//   Unmap                 = slot 15
//   IASetInputLayout      = slot 17
//   IASetVertexBuffers    = slot 18
//   IASetPrimitiveTopology = slot 24
//   RSSetViewports        = slot 44
//   OMSetRenderTargets    = slot 33
//   ClearRenderTargetView = slot 50
//   CopyResource          = slot 47

void Ctx_RSSetViewports(void* ctx, uint num, const(D3D11_VIEWPORT)* vps) nothrow @nogc
{
    alias Fn = extern(Windows) void function(void*, uint, const(D3D11_VIEWPORT)*) nothrow @nogc;
    (cast(Fn)(getVtbl(ctx)[44]))(ctx, num, vps);
}

void Ctx_OMSetRenderTargets(void* ctx, uint num, const(void*)* ppRTV, void* dsv) nothrow @nogc
{
    alias Fn = extern(Windows) void function(void*, uint, const(void*)*, void*) nothrow @nogc;
    (cast(Fn)(getVtbl(ctx)[33]))(ctx, num, ppRTV, dsv);
}

void Ctx_ClearRenderTargetView(void* ctx, void* rtv, const(float)* color) nothrow @nogc
{
    alias Fn = extern(Windows) void function(void*, void*, const(float)*) nothrow @nogc;
    (cast(Fn)(getVtbl(ctx)[50]))(ctx, rtv, color);
}

void Ctx_IASetInputLayout(void* ctx, void* layout) nothrow @nogc
{
    alias Fn = extern(Windows) void function(void*, void*) nothrow @nogc;
    (cast(Fn)(getVtbl(ctx)[17]))(ctx, layout);
}

void Ctx_IASetVertexBuffers(void* ctx, uint startSlot, uint num,
    const(void*)* ppVB, const(uint)* strides, const(uint)* offsets) nothrow @nogc
{
    alias Fn = extern(Windows) void function(void*, uint, uint, const(void*)*,
        const(uint)*, const(uint)*) nothrow @nogc;
    (cast(Fn)(getVtbl(ctx)[18]))(ctx, startSlot, num, ppVB, strides, offsets);
}

void Ctx_IASetPrimitiveTopology(void* ctx, uint topology) nothrow @nogc
{
    alias Fn = extern(Windows) void function(void*, uint) nothrow @nogc;
    (cast(Fn)(getVtbl(ctx)[24]))(ctx, topology);
}

void Ctx_VSSetShader(void* ctx, void* vs, void* classInstances, uint numCI) nothrow @nogc
{
    alias Fn = extern(Windows) void function(void*, void*, void*, uint) nothrow @nogc;
    (cast(Fn)(getVtbl(ctx)[11]))(ctx, vs, classInstances, numCI);
}

void Ctx_PSSetShader(void* ctx, void* ps, void* classInstances, uint numCI) nothrow @nogc
{
    alias Fn = extern(Windows) void function(void*, void*, void*, uint) nothrow @nogc;
    (cast(Fn)(getVtbl(ctx)[9]))(ctx, ps, classInstances, numCI);
}

void Ctx_Draw(void* ctx, uint vertexCount, uint startVertex) nothrow @nogc
{
    alias Fn = extern(Windows) void function(void*, uint, uint) nothrow @nogc;
    (cast(Fn)(getVtbl(ctx)[13]))(ctx, vertexCount, startVertex);
}

HRESULT Ctx_Map(void* ctx, void* resource, uint subresource, uint mapType,
    uint mapFlags, D3D11_MAPPED_SUBRESOURCE* mapped) nothrow @nogc
{
    alias Fn = extern(Windows) HRESULT function(void*, void*, uint, uint, uint,
        D3D11_MAPPED_SUBRESOURCE*) nothrow @nogc;
    return (cast(Fn)(getVtbl(ctx)[14]))(ctx, resource, subresource, mapType, mapFlags, mapped);
}

void Ctx_Unmap(void* ctx, void* resource, uint subresource) nothrow @nogc
{
    alias Fn = extern(Windows) void function(void*, void*, uint) nothrow @nogc;
    (cast(Fn)(getVtbl(ctx)[15]))(ctx, resource, subresource);
}

void Ctx_CopyResource(void* ctx, void* dst, void* src) nothrow @nogc
{
    alias Fn = extern(Windows) void function(void*, void*, void*) nothrow @nogc;
    (cast(Fn)(getVtbl(ctx)[47]))(ctx, dst, src);
}

// ID3DBlob::GetBufferPointer (slot 3), GetBufferSize (slot 4)
void* Blob_GetBufferPointer(void* blob) nothrow @nogc
{
    alias Fn = extern(Windows) void* function(void*) nothrow @nogc;
    return (cast(Fn)(getVtbl(blob)[3]))(blob);
}
size_t Blob_GetBufferSize(void* blob) nothrow @nogc
{
    alias Fn = extern(Windows) size_t function(void*) nothrow @nogc;
    return (cast(Fn)(getVtbl(blob)[4]))(blob);
}

// IDXGIDevice::GetAdapter (slot 7, IDXGIObject has slots 3-6)
HRESULT DXGIDevice_GetAdapter(void* dev, void** ppAdapter) nothrow @nogc
{
    alias Fn = extern(Windows) HRESULT function(void*, void**) nothrow @nogc;
    return (cast(Fn)(getVtbl(dev)[7]))(dev, ppAdapter);
}

// IDXGIObject::GetParent (slot 6)
HRESULT DXGIObject_GetParent(void* obj, const(GUID)* iid, void** ppParent) nothrow @nogc
{
    alias Fn = extern(Windows) HRESULT function(void*, const(GUID)*, void**) nothrow @nogc;
    return (cast(Fn)(getVtbl(obj)[6]))(obj, iid, ppParent);
}

// IDXGIFactory2::CreateSwapChainForComposition (slot 24)
HRESULT Factory2_CreateSwapChainForComposition(void* factory, void* device,
    const(DXGI_SWAP_CHAIN_DESC1)* desc, void* restrictOutput, void** ppSwapChain) nothrow @nogc
{
    alias Fn = extern(Windows) HRESULT function(void*, void*, const(DXGI_SWAP_CHAIN_DESC1)*,
        void*, void**) nothrow @nogc;
    return (cast(Fn)(getVtbl(factory)[24]))(factory, device, desc, restrictOutput, ppSwapChain);
}

// ============================================================
// HSTRING helper
// ============================================================
HRESULT createHStringRef(const(wchar)* str, uint len, ref HSTRING_HEADER hdr, ref HSTRING hs)
{
    return WindowsCreateStringReference(str, len, &hdr, &hs);
}

// ============================================================
// Window Procedure
// ============================================================
extern(Windows) LRESULT WndProc(HWND hWnd, uint msg, WPARAM wParam, LPARAM lParam) nothrow @system
{
    switch (msg)
    {
    case WM_DESTROY:
        PostQuitMessage(0);
        return 0;
    case WM_PAINT:
        PAINTSTRUCT ps;
        BeginPaint(hWnd, &ps);
        EndPaint(hWnd, &ps);
        return 0;
    default:
        return DefWindowProcW(hWnd, msg, wParam, lParam);
    }
}

// ============================================================
// Create application window
// ============================================================
HRESULT CreateAppWindow(HINSTANCE hInst)
{
    enum FN = "CreateAppWindow";
    dbgStep(FN, "begin");

    WNDCLASSEXW wc;
    memset(&wc, 0, wc.sizeof);
    wc.cbSize        = WNDCLASSEXW.sizeof;
    wc.hInstance     = hInst;
    wc.lpszClassName = "Win32CompTriangleD\0"w.ptr;
    wc.lpfnWndProc   = &WndProc;
    wc.hCursor       = LoadCursorW(null, cast(const(wchar)*)IDC_ARROW);
    wc.hbrBackground = null;

    if (!RegisterClassExW(&wc))
    {
        if (GetLastError() != ERROR_CLASS_ALREADY_EXISTS) return E_FAIL;
    }

    DWORD style = WS_OVERLAPPEDWINDOW;
    RECT rc;
    rc.left = 0; rc.top = 0;
    rc.right = cast(int)g_windowWidth; rc.bottom = cast(int)g_height;
    AdjustWindowRect(&rc, style, FALSE);

    g_hwnd = CreateWindowExW(
        WS_EX_NOREDIRECTIONBITMAP,
        "Win32CompTriangleD\0"w.ptr,
        "OpenGL + D3D11 + Vulkan via Windows.UI.Composition (D)\0"w.ptr,
        style,
        CW_USEDEFAULT, CW_USEDEFAULT,
        rc.right - rc.left, rc.bottom - rc.top,
        null, null, hInst, null
    );
    if (g_hwnd is null) return E_FAIL;

    ShowWindow(g_hwnd, SW_SHOW);
    UpdateWindow(g_hwnd);
    dbgStep(FN, "ok");
    return S_OK;
}

// ============================================================
// Initialize DispatcherQueue (required for Composition)
// ============================================================
HRESULT InitDispatcherQueue()
{
    enum FN = "InitDispatcherQueue";
    if (g_dqController !is null) return S_OK;
    dbgStep(FN, "begin");

    DispatcherQueueOptions opt;
    memset(&opt, 0, opt.sizeof);
    opt.dwSize = DispatcherQueueOptions.sizeof;
    opt.threadType = DQTYPE_THREAD_CURRENT;
    opt.apartmentType = DQTAT_COM_STA;

    HRESULT hr = fnCreateDispatcherQueueController(opt, &g_dqController);
    if (FAILED(hr)) { dbgHR(FN, "CreateDispatcherQueueController", hr); return hr; }
    dbgStep(FN, "ok");
    return S_OK;
}

// ============================================================
// Compile HLSL shader
// ============================================================
HRESULT CompileShader(const(char)* src, const(char)* entry, const(char)* target, void** ppBlob)
{
    void* pErr = null;
    HRESULT hr = fnD3DCompile(src, strlen(src), null, null, null, entry, target,
        D3DCOMPILE_ENABLE_STRICTNESS, 0, ppBlob, &pErr);
    if (FAILED(hr))
    {
        if (pErr !is null)
        {
            OutputDebugStringA(cast(const(char)*)Blob_GetBufferPointer(pErr));
            comRelease(pErr);
        }
        return hr;
    }
    if (pErr !is null) comRelease(pErr);
    return S_OK;
}

// ============================================================
// Create swap chain for composition on the shared D3D11 device
// ============================================================
HRESULT CreateSwapChainForComp(void** ppSwapChain)
{
    void* dxgiDev, adapter, factory;
    HRESULT hr;

    hr = comQI(g_d3dDevice, &IID_IDXGIDevice, &dxgiDev);
    if (FAILED(hr)) return hr;
    hr = DXGIDevice_GetAdapter(dxgiDev, &adapter);
    comRelease(dxgiDev);
    if (FAILED(hr)) return hr;
    hr = DXGIObject_GetParent(adapter, &IID_IDXGIFactory2, &factory);
    comRelease(adapter);
    if (FAILED(hr)) return hr;

    DXGI_SWAP_CHAIN_DESC1 desc;
    memset(&desc, 0, desc.sizeof);
    desc.Width  = g_width;
    desc.Height = g_height;
    desc.Format = DXGI_FORMAT_B8G8R8A8_UNORM;
    desc.SampleDesc.Count = 1;
    desc.BufferUsage = DXGI_USAGE_RENDER_TARGET_OUTPUT;
    desc.BufferCount = 2;
    desc.Scaling     = DXGI_SCALING_STRETCH;
    desc.SwapEffect  = DXGI_SWAP_EFFECT_FLIP_SEQUENTIAL;
    desc.AlphaMode   = DXGI_ALPHA_MODE_PREMULTIPLIED;

    hr = Factory2_CreateSwapChainForComposition(factory, g_d3dDevice, &desc, null, ppSwapChain);
    comRelease(factory);
    return hr;
}

// ============================================================
// Create RTV from swap chain back buffer
// ============================================================
HRESULT CreateRTV(void* sc, void** ppRTV)
{
    void* bb;
    HRESULT hr = SwapChain_GetBuffer(sc, 0, &IID_ID3D11Texture2D, &bb);
    if (FAILED(hr)) return hr;
    hr = Device_CreateRenderTargetView(g_d3dDevice, bb, null, ppRTV);
    comRelease(bb);
    return hr;
}

// ============================================================
// Add SpriteVisual for a swap chain at the given X offset
// ============================================================
HRESULT AddSpriteForSwapChain(void* sc, float offsetX,
    void** ppSurface, void** ppSurfBrush, void** ppCompBrush,
    void** ppSprite, void** ppVisual)
{
    HRESULT hr;
    void* spriteAsVisual;

    hr = CompositorInterop_CreateSurfaceForSwapChain(g_compInterop, sc, ppSurface);
    if (FAILED(hr)) return hr;
    hr = Compositor_CreateSurfaceBrush(g_compositor, *ppSurface, ppSurfBrush);
    if (FAILED(hr)) return hr;
    hr = comQI(*ppSurfBrush, &IID_ICompositionBrush, ppCompBrush);
    if (FAILED(hr)) return hr;
    hr = Compositor_CreateSpriteVisual(g_compositor, ppSprite);
    if (FAILED(hr)) return hr;
    hr = SpriteVisual_put_Brush(*ppSprite, *ppCompBrush);
    if (FAILED(hr)) return hr;
    hr = comQI(*ppSprite, &IID_IVisual, ppVisual);
    if (FAILED(hr)) return hr;
    hr = Visual_put_Size(*ppVisual, cast(float)g_width, cast(float)g_height);
    if (FAILED(hr)) return hr;
    hr = Visual_put_Offset(*ppVisual, offsetX, 0.0f, 0.0f);
    if (FAILED(hr)) return hr;

    hr = comQI(*ppSprite, &IID_IVisual, &spriteAsVisual);
    if (FAILED(hr)) return hr;
    hr = VisualCollection_InsertAtTop(g_visualCollection, spriteAsVisual);
    comRelease(spriteAsVisual);
    return hr;
}

// ============================================================
// Initialize D3D11 + first swap chain + shaders + vertex buffer
// ============================================================
HRESULT InitD3D11()
{
    enum FN = "InitD3D11";
    HRESULT hr;
    dbgStep(FN, "begin");

    uint[1] fls = [ D3D_FEATURE_LEVEL_11_0 ];
    uint flOut;
    hr = fnD3D11CreateDevice(null, D3D_DRIVER_TYPE_HARDWARE, null,
        D3D11_CREATE_DEVICE_BGRA_SUPPORT,
        fls.ptr, 1, D3D11_SDK_VERSION,
        &g_d3dDevice, &flOut, &g_d3dCtx);
    if (FAILED(hr)) { dbgHR(FN, "D3D11CreateDevice", hr); return hr; }
    dbgStep(FN, "D3D11 device created");

    // Create first swap chain for composition
    hr = CreateSwapChainForComp(&g_swapChain);
    if (FAILED(hr)) { dbgHR(FN, "CreateSwapChainForComposition", hr); return hr; }

    // Get back buffer for GL interop
    hr = SwapChain_GetBuffer(g_swapChain, 0, &IID_ID3D11Texture2D, &g_backBuffer);
    if (FAILED(hr)) return hr;

    // Create RTV
    hr = Device_CreateRenderTargetView(g_d3dDevice, g_backBuffer, null, &g_rtv);
    if (FAILED(hr)) return hr;

    // Compile HLSL shaders
    void* vsBlob, psBlob;
    hr = CompileShader(kVS_HLSL, "main", "vs_4_0", &vsBlob);
    if (FAILED(hr)) return hr;

    hr = Device_CreateVertexShader(g_d3dDevice,
        Blob_GetBufferPointer(vsBlob), Blob_GetBufferSize(vsBlob), null, &g_d3dVS);
    if (FAILED(hr)) { comRelease(vsBlob); return hr; }

    hr = CompileShader(kPS_HLSL, "main", "ps_4_0", &psBlob);
    if (FAILED(hr)) { comRelease(vsBlob); return hr; }

    hr = Device_CreatePixelShader(g_d3dDevice,
        Blob_GetBufferPointer(psBlob), Blob_GetBufferSize(psBlob), null, &g_d3dPS);
    comRelease(psBlob);
    if (FAILED(hr)) { comRelease(vsBlob); return hr; }

    // Input layout
    D3D11_INPUT_ELEMENT_DESC[2] layout;
    layout[0].SemanticName  = "POSITION";
    layout[0].Format        = DXGI_FORMAT_R32G32B32_FLOAT;
    layout[0].AlignedByteOffset = 0;
    layout[1].SemanticName  = "COLOR";
    layout[1].Format        = DXGI_FORMAT_R32G32B32A32_FLOAT;
    layout[1].AlignedByteOffset = 12;

    hr = Device_CreateInputLayout(g_d3dDevice, layout.ptr, 2,
        Blob_GetBufferPointer(vsBlob), Blob_GetBufferSize(vsBlob), &g_inputLayout);
    comRelease(vsBlob);
    if (FAILED(hr)) return hr;

    // Vertex buffer
    VERTEX[3] verts = [
        VERTEX(  0.0f,  0.5f, 0.5f,  1.0f, 0.0f, 0.0f, 1.0f ),
        VERTEX(  0.5f, -0.5f, 0.5f,  0.0f, 1.0f, 0.0f, 1.0f ),
        VERTEX( -0.5f, -0.5f, 0.5f,  0.0f, 0.0f, 1.0f, 1.0f ),
    ];
    D3D11_BUFFER_DESC bd;
    memset(&bd, 0, bd.sizeof);
    bd.Usage     = D3D11_USAGE_DEFAULT;
    bd.ByteWidth = cast(uint)verts.sizeof;
    bd.BindFlags = D3D11_BIND_VERTEX_BUFFER;

    D3D11_SUBRESOURCE_DATA initData;
    memset(&initData, 0, initData.sizeof);
    initData.pSysMem = verts.ptr;

    hr = Device_CreateBuffer(g_d3dDevice, &bd, &initData, &g_d3dVB);
    if (FAILED(hr)) return hr;

    dbgStep(FN, "ok");
    return S_OK;
}

// ============================================================
// OpenGL 4.6 via WGL_NV_DX_interop
// ============================================================
HGLRC EnableOpenGL(HDC hdc)
{
    PIXELFORMATDESCRIPTOR pfd;
    memset(&pfd, 0, pfd.sizeof);
    pfd.nSize    = PIXELFORMATDESCRIPTOR.sizeof;
    pfd.nVersion = 1;
    pfd.dwFlags  = PFD_DRAW_TO_WINDOW | PFD_SUPPORT_OPENGL | PFD_DOUBLEBUFFER;
    pfd.iPixelType = PFD_TYPE_RGBA;
    pfd.cColorBits = 32;
    pfd.cDepthBits = 24;
    pfd.iLayerType = PFD_MAIN_PLANE;

    int pf = ChoosePixelFormat(hdc, &pfd);
    if (pf == 0) return null;
    if (!SetPixelFormat(hdc, pf, &pfd))
    {
        if (GetLastError() != 2000/*ERROR_INVALID_PIXEL_FORMAT*/) return null;
    }

    HGLRC oldRc = fn_wglCreateContext(hdc);
    if (oldRc is null) return null;
    if (!fn_wglMakeCurrent(hdc, oldRc))
    {
        fn_wglDeleteContext(oldRc);
        return null;
    }

    fn_wglCreateContextAttribsARB = cast(pWglCreateContextAttribsARB)
        getGLProc("wglCreateContextAttribsARB");
    if (fn_wglCreateContextAttribsARB is null) return oldRc;

    int[9] attrs = [
        WGL_CONTEXT_MAJOR_VERSION_ARB, 4,
        WGL_CONTEXT_MINOR_VERSION_ARB, 6,
        WGL_CONTEXT_FLAGS_ARB, 0,
        WGL_CONTEXT_PROFILE_MASK_ARB, WGL_CONTEXT_CORE_PROFILE_BIT_ARB,
        0
    ];
    HGLRC rc = fn_wglCreateContextAttribsARB(hdc, null, attrs.ptr);
    if (rc is null) return oldRc;

    fn_wglMakeCurrent(hdc, rc);
    fn_wglDeleteContext(oldRc);
    return rc;
}

HRESULT InitOpenGL()
{
    enum FN = "InitOpenGL";
    HRESULT hr;
    dbgStep(FN, "begin");

    if (g_hwnd is null || g_d3dDevice is null || g_swapChain is null || g_backBuffer is null)
        return E_FAIL;

    g_hdc = GetDC(g_hwnd);
    if (g_hdc is null) return E_FAIL;

    g_hglrc = EnableOpenGL(g_hdc);
    if (g_hglrc is null) return E_FAIL;
    if (!fn_wglMakeCurrent(g_hdc, g_hglrc)) return E_FAIL;

    // Load GL extension functions
    fn_glGenBuffers   = cast(pGlGenBuffers)getGLProc("glGenBuffers");
    fn_glBindBuffer   = cast(pGlBindBuffer)getGLProc("glBindBuffer");
    fn_glBufferData   = cast(pGlBufferData)getGLProc("glBufferData");
    fn_glCreateShader = cast(pGlCreateShader)getGLProc("glCreateShader");
    fn_glShaderSource = cast(pGlShaderSource)getGLProc("glShaderSource");
    fn_glCompileShader = cast(pGlCompileShader)getGLProc("glCompileShader");
    fn_glGetShaderiv   = cast(pGlGetShaderiv)getGLProc("glGetShaderiv");
    fn_glGetShaderInfoLog = cast(pGlGetShaderInfoLog)getGLProc("glGetShaderInfoLog");
    fn_glCreateProgram = cast(pGlCreateProgram)getGLProc("glCreateProgram");
    fn_glAttachShader  = cast(pGlAttachShader)getGLProc("glAttachShader");
    fn_glLinkProgram   = cast(pGlLinkProgram)getGLProc("glLinkProgram");
    fn_glGetProgramiv  = cast(pGlGetProgramiv)getGLProc("glGetProgramiv");
    fn_glGetProgramInfoLog = cast(pGlGetProgramInfoLog)getGLProc("glGetProgramInfoLog");
    fn_glUseProgram    = cast(pGlUseProgram)getGLProc("glUseProgram");
    fn_glGetAttribLocation = cast(pGlGetAttribLocation)getGLProc("glGetAttribLocation");
    fn_glEnableVertexAttribArray = cast(pGlEnableVertexAttribArray)getGLProc("glEnableVertexAttribArray");
    fn_glVertexAttribPointer = cast(pGlVertexAttribPointer)getGLProc("glVertexAttribPointer");
    fn_glGenVertexArrays = cast(pGlGenVertexArrays)getGLProc("glGenVertexArrays");
    fn_glBindVertexArray = cast(pGlBindVertexArray)getGLProc("glBindVertexArray");
    fn_glGenFramebuffers = cast(pGlGenFramebuffers)getGLProc("glGenFramebuffers");
    fn_glBindFramebuffer = cast(pGlBindFramebuffer)getGLProc("glBindFramebuffer");
    fn_glFramebufferRenderbuffer = cast(pGlFramebufferRenderbuffer)getGLProc("glFramebufferRenderbuffer");
    fn_glCheckFramebufferStatus  = cast(pGlCheckFramebufferStatus)getGLProc("glCheckFramebufferStatus");
    fn_glGenRenderbuffers = cast(pGlGenRenderbuffers)getGLProc("glGenRenderbuffers");
    fn_glBindRenderbuffer = cast(pGlBindRenderbuffer)getGLProc("glBindRenderbuffer");
    fn_glDeleteBuffers    = cast(pGlDeleteBuffers)getGLProc("glDeleteBuffers");
    fn_glDeleteVertexArrays = cast(pGlDeleteVertexArrays)getGLProc("glDeleteVertexArrays");
    fn_glDeleteFramebuffers = cast(pGlDeleteFramebuffers)getGLProc("glDeleteFramebuffers");
    fn_glDeleteRenderbuffers = cast(pGlDeleteRenderbuffers)getGLProc("glDeleteRenderbuffers");
    fn_glDeleteProgram = cast(pGlDeleteProgram)getGLProc("glDeleteProgram");

    // WGL_NV_DX_interop
    fn_wglDXOpenDeviceNV   = cast(pWglDXOpenDeviceNV)getGLProc("wglDXOpenDeviceNV");
    fn_wglDXCloseDeviceNV  = cast(pWglDXCloseDeviceNV)getGLProc("wglDXCloseDeviceNV");
    fn_wglDXRegisterObjectNV = cast(pWglDXRegisterObjectNV)getGLProc("wglDXRegisterObjectNV");
    fn_wglDXUnregisterObjectNV = cast(pWglDXUnregisterObjectNV)getGLProc("wglDXUnregisterObjectNV");
    fn_wglDXLockObjectsNV  = cast(pWglDXLockObjectsNV)getGLProc("wglDXLockObjectsNV");
    fn_wglDXUnlockObjectsNV = cast(pWglDXUnlockObjectsNV)getGLProc("wglDXUnlockObjectsNV");

    if (fn_glGenBuffers is null || fn_wglDXOpenDeviceNV is null)
    {
        dbgStep(FN, "missing GL functions");
        return E_FAIL;
    }

    // Open D3D device for NV interop
    g_glInteropDevice = fn_wglDXOpenDeviceNV(g_d3dDevice);
    if (g_glInteropDevice is null) { dbgStep(FN, "wglDXOpenDeviceNV failed"); return E_FAIL; }

    // Register D3D11 back buffer as GL renderbuffer
    fn_glGenRenderbuffers(1, &g_glRbo);
    fn_glBindRenderbuffer(GL_RENDERBUFFER, g_glRbo);
    g_glInteropObject = fn_wglDXRegisterObjectNV(
        g_glInteropDevice, g_backBuffer, g_glRbo, GL_RENDERBUFFER, WGL_ACCESS_READ_WRITE_NV);
    if (g_glInteropObject is null) { dbgStep(FN, "wglDXRegisterObjectNV failed"); return E_FAIL; }

    // FBO
    fn_glGenFramebuffers(1, &g_glFbo);
    fn_glBindFramebuffer(GL_FRAMEBUFFER, g_glFbo);
    fn_glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, g_glRbo);
    GLenum fboStatus = fn_glCheckFramebufferStatus(GL_FRAMEBUFFER);
    fn_glBindFramebuffer(GL_FRAMEBUFFER, 0);
    if (fboStatus != GL_FRAMEBUFFER_COMPLETE) return E_FAIL;

    // VAO and VBOs
    fn_glGenVertexArrays(1, &g_glVao);
    fn_glBindVertexArray(g_glVao);

    GLfloat[9] verts = [
        -0.5f, -0.5f, 0.0f,
         0.5f, -0.5f, 0.0f,
         0.0f,  0.5f, 0.0f
    ];
    GLfloat[9] cols = [
        0.0f, 0.0f, 1.0f,
        0.0f, 1.0f, 0.0f,
        1.0f, 0.0f, 0.0f
    ];

    fn_glGenBuffers(2, g_glVbo.ptr);
    fn_glBindBuffer(GL_ARRAY_BUFFER, g_glVbo[0]);
    fn_glBufferData(GL_ARRAY_BUFFER, cast(GLsizeiptr)verts.sizeof, verts.ptr, GL_STATIC_DRAW);
    fn_glBindBuffer(GL_ARRAY_BUFFER, g_glVbo[1]);
    fn_glBufferData(GL_ARRAY_BUFFER, cast(GLsizeiptr)cols.sizeof, cols.ptr, GL_STATIC_DRAW);

    // Compile GLSL shaders
    GLuint vs = fn_glCreateShader(GL_VERTEX_SHADER);
    fn_glShaderSource(vs, 1, &kVS_GLSL, null);
    fn_glCompileShader(vs);
    { GLint ok; fn_glGetShaderiv(vs, GL_COMPILE_STATUS, &ok); if (!ok) return E_FAIL; }

    GLuint ps = fn_glCreateShader(GL_FRAGMENT_SHADER);
    fn_glShaderSource(ps, 1, &kPS_GLSL, null);
    fn_glCompileShader(ps);
    { GLint ok; fn_glGetShaderiv(ps, GL_COMPILE_STATUS, &ok); if (!ok) return E_FAIL; }

    g_glProgram = fn_glCreateProgram();
    fn_glAttachShader(g_glProgram, vs);
    fn_glAttachShader(g_glProgram, ps);
    fn_glLinkProgram(g_glProgram);
    { GLint ok; fn_glGetProgramiv(g_glProgram, GL_LINK_STATUS, &ok); if (!ok) return E_FAIL; }

    fn_glUseProgram(g_glProgram);
    g_glPosAttrib = fn_glGetAttribLocation(g_glProgram, "position");
    g_glColAttrib = fn_glGetAttribLocation(g_glProgram, "color");
    if (g_glPosAttrib < 0 || g_glColAttrib < 0) return E_FAIL;
    fn_glEnableVertexAttribArray(cast(GLuint)g_glPosAttrib);
    fn_glEnableVertexAttribArray(cast(GLuint)g_glColAttrib);

    dbgStep(FN, "ok");
    return S_OK;
}

// ============================================================
// D3D11 second panel
// ============================================================
HRESULT InitD3D11SecondPanel()
{
    enum FN = "InitD3D11SecondPanel";
    HRESULT hr;
    dbgStep(FN, "begin");

    hr = CreateSwapChainForComp(&g_dxSwapChain);
    if (FAILED(hr)) return hr;
    hr = CreateRTV(g_dxSwapChain, &g_dxRtv);
    if (FAILED(hr)) return hr;
    hr = AddSpriteForSwapChain(g_dxSwapChain, cast(float)g_width,
        &g_dxCompositionSurface, &g_dxSurfaceBrush, &g_dxCompositionBrush,
        &g_dxSpriteVisual, &g_dxVisual);
    if (FAILED(hr)) return hr;
    dbgStep(FN, "ok");
    return S_OK;
}

// ============================================================
// Read binary file (for SPIR-V shaders)
// ============================================================
struct FileData { ubyte* data; size_t size; }

FileData readBinaryFile(const(char)* path)
{
    FileData out_;
    out_.data = null; out_.size = 0;
    FILE* fp = fopen(path, "rb");
    if (fp is null) return out_;
    fseek(fp, 0, SEEK_END);
    long sz = ftell(fp);
    if (sz <= 0) { fclose(fp); return out_; }
    fseek(fp, 0, SEEK_SET);
    out_.data = cast(ubyte*)malloc(cast(size_t)sz);
    if (out_.data is null) { fclose(fp); return out_; }
    if (fread(out_.data, 1, cast(size_t)sz, fp) != cast(size_t)sz)
    {
        free(out_.data);
        out_.data = null;
    }
    else out_.size = cast(size_t)sz;
    fclose(fp);
    return out_;
}

// ============================================================
// Find Vulkan memory type
// ============================================================
uint vkFindMemoryType(uint typeBits, uint props)
{
    VkPhysicalDeviceMemoryProperties mp;
    fn_vkGetPhysicalDeviceMemoryProperties(g_vkPhysDev, &mp);
    for (uint i = 0; i < mp.memoryTypeCount; ++i)
    {
        if ((typeBits & (1u << i)) && (mp.memoryTypes[i].propertyFlags & props) == props)
            return i;
    }
    return UINT32_MAX;
}

// ============================================================
// Vulkan third panel (offscreen -> readback -> D3D11 copy)
// ============================================================
HRESULT InitVulkanThirdPanel()
{
    enum FN = "InitVulkanThirdPanel";
    HRESULT hr;
    VkResult vr;
    dbgStep(FN, "begin");

    // Create D3D11 swap chain for the Vulkan panel
    hr = CreateSwapChainForComp(&g_vkSwapChain);
    if (FAILED(hr)) return hr;

    // We need g_visualCollection to exist before calling AddSpriteForSwapChain
    hr = AddSpriteForSwapChain(g_vkSwapChain, cast(float)(g_width * 2),
        &g_vkCompositionSurface, &g_vkSurfaceBrush, &g_vkCompositionBrush,
        &g_vkSpriteVisual, &g_vkVisualObj);
    if (FAILED(hr)) return hr;

    // Get VK panel D3D resources (staging texture + back buffer)
    hr = SwapChain_GetBuffer(g_vkSwapChain, 0, &IID_ID3D11Texture2D, &g_vkBackBuffer);
    if (FAILED(hr)) return hr;

    D3D11_TEXTURE2D_DESC td;
    memset(&td, 0, td.sizeof);
    td.Width  = g_width;
    td.Height = g_height;
    td.MipLevels = 1;
    td.ArraySize = 1;
    td.Format = DXGI_FORMAT_B8G8R8A8_UNORM;
    td.SampleDesc.Count = 1;
    td.Usage = D3D11_USAGE_STAGING;
    td.CPUAccessFlags = D3D11_CPU_ACCESS_WRITE;
    hr = Device_CreateTexture2D(g_d3dDevice, &td, null, &g_vkStagingTex);
    if (FAILED(hr)) return hr;

    // Initialize Vulkan instance
    VkApplicationInfo ai;
    memset(&ai, 0, ai.sizeof);
    ai.sType = VK_STRUCTURE_TYPE_APPLICATION_INFO;
    ai.pApplicationName = "triangle_multi_vk_panel";
    ai.apiVersion = VK_API_VERSION_1_4;

    VkInstanceCreateInfo ici;
    memset(&ici, 0, ici.sizeof);
    ici.sType = VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO;
    ici.pApplicationInfo = &ai;
    vr = fn_vkCreateInstance(&ici, null, &g_vkInst);
    if (vr != VK_SUCCESS) return E_FAIL;

    // Enumerate physical devices and find a graphics queue
    uint devCount = 0;
    fn_vkEnumeratePhysicalDevices(g_vkInst, &devCount, null);
    if (devCount == 0) return E_FAIL;
    VkPhysicalDevice* devs = cast(VkPhysicalDevice*)malloc(devCount * (void*).sizeof);
    if (devs is null) return E_FAIL;
    fn_vkEnumeratePhysicalDevices(g_vkInst, &devCount, devs);

    for (uint i = 0; i < devCount && g_vkPhysDev is null; ++i)
    {
        uint qc = 0;
        fn_vkGetPhysicalDeviceQueueFamilyProperties(devs[i], &qc, null);
        if (qc == 0) continue;
        auto qprops = cast(VkQueueFamilyProperties*)malloc(qc * VkQueueFamilyProperties.sizeof);
        if (qprops is null) continue;
        fn_vkGetPhysicalDeviceQueueFamilyProperties(devs[i], &qc, qprops);
        for (uint q = 0; q < qc; ++q)
        {
            if (qprops[q].queueFlags & VK_QUEUE_GRAPHICS_BIT)
            {
                g_vkPhysDev = devs[i];
                g_vkQueueFamily = q;
                break;
            }
        }
        free(qprops);
    }
    free(devs);
    if (g_vkPhysDev is null) return E_FAIL;

    // Create logical device
    float prio = 1.0f;
    VkDeviceQueueCreateInfo qci;
    memset(&qci, 0, qci.sizeof);
    qci.sType = VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO;
    qci.queueFamilyIndex = g_vkQueueFamily;
    qci.queueCount = 1;
    qci.pQueuePriorities = &prio;

    VkDeviceCreateInfo dci;
    memset(&dci, 0, dci.sizeof);
    dci.sType = VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO;
    dci.queueCreateInfoCount = 1;
    dci.pQueueCreateInfos = &qci;
    vr = fn_vkCreateDevice(g_vkPhysDev, &dci, null, &g_vkDev);
    if (vr != VK_SUCCESS) return E_FAIL;
    fn_vkGetDeviceQueue(g_vkDev, g_vkQueueFamily, 0, &g_vkQueue);

    // Offscreen image
    VkImageCreateInfo imgci;
    memset(&imgci, 0, imgci.sizeof);
    imgci.sType = VK_STRUCTURE_TYPE_IMAGE_CREATE_INFO;
    imgci.imageType = VK_IMAGE_TYPE_2D;
    imgci.format = VK_FORMAT_B8G8R8A8_UNORM;
    imgci.extent.width = g_width; imgci.extent.height = g_height; imgci.extent.depth = 1;
    imgci.mipLevels = 1; imgci.arrayLayers = 1;
    imgci.samples = VK_SAMPLE_COUNT_1_BIT;
    imgci.tiling = VK_IMAGE_TILING_OPTIMAL;
    imgci.usage = VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT | VK_IMAGE_USAGE_TRANSFER_SRC_BIT;
    imgci.initialLayout = VK_IMAGE_LAYOUT_UNDEFINED;
    vr = fn_vkCreateImage(g_vkDev, &imgci, null, &g_vkOffImage);
    if (vr != VK_SUCCESS) return E_FAIL;

    VkMemoryRequirements mr;
    fn_vkGetImageMemoryRequirements(g_vkDev, g_vkOffImage, &mr);
    VkMemoryAllocateInfo mai;
    memset(&mai, 0, mai.sizeof);
    mai.sType = VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO;
    mai.allocationSize = mr.size;
    mai.memoryTypeIndex = vkFindMemoryType(mr.memoryTypeBits, VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT);
    if (mai.memoryTypeIndex == UINT32_MAX) return E_FAIL;
    vr = fn_vkAllocateMemory(g_vkDev, &mai, null, &g_vkOffMemory);
    if (vr != VK_SUCCESS) return E_FAIL;
    fn_vkBindImageMemory(g_vkDev, g_vkOffImage, g_vkOffMemory, 0);

    // Image view
    VkImageViewCreateInfo ivci;
    memset(&ivci, 0, ivci.sizeof);
    ivci.sType = VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO;
    ivci.image = g_vkOffImage;
    ivci.viewType = VK_IMAGE_VIEW_TYPE_2D;
    ivci.format = VK_FORMAT_B8G8R8A8_UNORM;
    ivci.subresourceRange.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT;
    ivci.subresourceRange.levelCount = 1;
    ivci.subresourceRange.layerCount = 1;
    vr = fn_vkCreateImageView(g_vkDev, &ivci, null, &g_vkOffView);
    if (vr != VK_SUCCESS) return E_FAIL;

    // Readback buffer
    VkBufferCreateInfo bci;
    memset(&bci, 0, bci.sizeof);
    bci.sType = VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO;
    bci.size = cast(VkDeviceSize)g_width * g_height * 4;
    bci.usage = VK_BUFFER_USAGE_TRANSFER_DST_BIT;
    vr = fn_vkCreateBuffer(g_vkDev, &bci, null, &g_vkReadbackBuf);
    if (vr != VK_SUCCESS) return E_FAIL;
    fn_vkGetBufferMemoryRequirements(g_vkDev, g_vkReadbackBuf, &mr);
    memset(&mai, 0, mai.sizeof);
    mai.sType = VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO;
    mai.allocationSize = mr.size;
    mai.memoryTypeIndex = vkFindMemoryType(mr.memoryTypeBits,
        VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | VK_MEMORY_PROPERTY_HOST_COHERENT_BIT);
    if (mai.memoryTypeIndex == UINT32_MAX) return E_FAIL;
    vr = fn_vkAllocateMemory(g_vkDev, &mai, null, &g_vkReadbackMem);
    if (vr != VK_SUCCESS) return E_FAIL;
    fn_vkBindBufferMemory(g_vkDev, g_vkReadbackBuf, g_vkReadbackMem, 0);

    // Render pass
    VkAttachmentDescription att;
    memset(&att, 0, att.sizeof);
    att.format = VK_FORMAT_B8G8R8A8_UNORM;
    att.samples = VK_SAMPLE_COUNT_1_BIT;
    att.loadOp = VK_ATTACHMENT_LOAD_OP_CLEAR;
    att.storeOp = VK_ATTACHMENT_STORE_OP_STORE;
    att.stencilLoadOp = VK_ATTACHMENT_LOAD_OP_DONT_CARE;
    att.stencilStoreOp = VK_ATTACHMENT_STORE_OP_DONT_CARE;
    att.initialLayout = VK_IMAGE_LAYOUT_UNDEFINED;
    att.finalLayout = VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL;

    VkAttachmentReference aref;
    aref.attachment = 0;
    aref.layout = VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL;

    VkSubpassDescription sub;
    memset(&sub, 0, sub.sizeof);
    sub.pipelineBindPoint = VK_PIPELINE_BIND_POINT_GRAPHICS;
    sub.colorAttachmentCount = 1;
    sub.pColorAttachments = &aref;

    VkRenderPassCreateInfo rpci;
    memset(&rpci, 0, rpci.sizeof);
    rpci.sType = VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO;
    rpci.attachmentCount = 1; rpci.pAttachments = &att;
    rpci.subpassCount = 1; rpci.pSubpasses = &sub;
    vr = fn_vkCreateRenderPass(g_vkDev, &rpci, null, &g_vkRenderPass);
    if (vr != VK_SUCCESS) return E_FAIL;

    // Framebuffer
    VkFramebufferCreateInfo fbci;
    memset(&fbci, 0, fbci.sizeof);
    fbci.sType = VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO;
    fbci.renderPass = g_vkRenderPass;
    fbci.attachmentCount = 1;
    fbci.pAttachments = &g_vkOffView;
    fbci.width = g_width; fbci.height = g_height; fbci.layers = 1;
    vr = fn_vkCreateFramebuffer(g_vkDev, &fbci, null, &g_vkFramebuffer);
    if (vr != VK_SUCCESS) return E_FAIL;

    // Load SPIR-V shaders
    FileData vsSpv = readBinaryFile("hello_vert.spv");
    FileData fsSpv = readBinaryFile("hello_frag.spv");
    if (vsSpv.data is null || fsSpv.data is null) return E_FAIL;

    VkShaderModuleCreateInfo smci;
    VkShaderModule vsMod, fsMod;
    memset(&smci, 0, smci.sizeof);
    smci.sType = VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO;
    smci.codeSize = vsSpv.size;
    smci.pCode = cast(const(uint)*)vsSpv.data;
    vr = fn_vkCreateShaderModule(g_vkDev, &smci, null, &vsMod);
    if (vr != VK_SUCCESS) return E_FAIL;
    smci.codeSize = fsSpv.size;
    smci.pCode = cast(const(uint)*)fsSpv.data;
    vr = fn_vkCreateShaderModule(g_vkDev, &smci, null, &fsMod);
    if (vr != VK_SUCCESS) return E_FAIL;

    // Pipeline stages
    VkPipelineShaderStageCreateInfo[2] stages;
    memset(stages.ptr, 0, stages.sizeof);
    stages[0].sType = VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO;
    stages[0].stage = VK_SHADER_STAGE_VERTEX_BIT;
    stages[0].module_ = vsMod;
    stages[0].pName = "main";
    stages[1].sType = VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO;
    stages[1].stage = VK_SHADER_STAGE_FRAGMENT_BIT;
    stages[1].module_ = fsMod;
    stages[1].pName = "main";

    VkPipelineVertexInputStateCreateInfo vi;
    memset(&vi, 0, vi.sizeof);
    vi.sType = VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO;

    VkPipelineInputAssemblyStateCreateInfo ia;
    memset(&ia, 0, ia.sizeof);
    ia.sType = VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO;
    ia.topology = VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST;

    VkViewport vp;
    memset(&vp, 0, vp.sizeof);
    vp.width = cast(float)g_width; vp.height = cast(float)g_height; vp.maxDepth = 1.0f;

    VkRect2D sc;
    memset(&sc, 0, sc.sizeof);
    sc.extent.width = g_width; sc.extent.height = g_height;

    VkPipelineViewportStateCreateInfo vps;
    memset(&vps, 0, vps.sizeof);
    vps.sType = VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO;
    vps.viewportCount = 1; vps.pViewports = &vp;
    vps.scissorCount = 1; vps.pScissors = &sc;

    VkPipelineRasterizationStateCreateInfo rs;
    memset(&rs, 0, rs.sizeof);
    rs.sType = VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO;
    rs.polygonMode = VK_POLYGON_MODE_FILL;
    rs.lineWidth = 1.0f;
    rs.cullMode = VK_CULL_MODE_BACK_BIT;
    rs.frontFace = VK_FRONT_FACE_CLOCKWISE;

    VkPipelineMultisampleStateCreateInfo ms;
    memset(&ms, 0, ms.sizeof);
    ms.sType = VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO;
    ms.rasterizationSamples = VK_SAMPLE_COUNT_1_BIT;

    VkPipelineColorBlendAttachmentState cba;
    memset(&cba, 0, cba.sizeof);
    cba.colorWriteMask = 0xF;

    VkPipelineColorBlendStateCreateInfo cbs;
    memset(&cbs, 0, cbs.sizeof);
    cbs.sType = VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO;
    cbs.attachmentCount = 1; cbs.pAttachments = &cba;

    VkPipelineLayoutCreateInfo plci;
    memset(&plci, 0, plci.sizeof);
    plci.sType = VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO;
    vr = fn_vkCreatePipelineLayout(g_vkDev, &plci, null, &g_vkPipeLayout);
    if (vr != VK_SUCCESS) return E_FAIL;

    VkGraphicsPipelineCreateInfo gpci;
    memset(&gpci, 0, gpci.sizeof);
    gpci.sType = VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO;
    gpci.stageCount = 2; gpci.pStages = stages.ptr;
    gpci.pVertexInputState = &vi; gpci.pInputAssemblyState = &ia;
    gpci.pViewportState = &vps; gpci.pRasterizationState = &rs;
    gpci.pMultisampleState = &ms; gpci.pColorBlendState = &cbs;
    gpci.layout = g_vkPipeLayout; gpci.renderPass = g_vkRenderPass;
    vr = fn_vkCreateGraphicsPipelines(g_vkDev, null, 1, &gpci, null, &g_vkPipeline);
    if (vr != VK_SUCCESS) return E_FAIL;

    // Command pool, command buffer, fence
    VkCommandPoolCreateInfo cpci;
    memset(&cpci, 0, cpci.sizeof);
    cpci.sType = VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO;
    cpci.flags = VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT;
    cpci.queueFamilyIndex = g_vkQueueFamily;
    vr = fn_vkCreateCommandPool(g_vkDev, &cpci, null, &g_vkCmdPool);
    if (vr != VK_SUCCESS) return E_FAIL;

    VkCommandBufferAllocateInfo cbai;
    memset(&cbai, 0, cbai.sizeof);
    cbai.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO;
    cbai.commandPool = g_vkCmdPool;
    cbai.level = VK_COMMAND_BUFFER_LEVEL_PRIMARY;
    cbai.commandBufferCount = 1;
    vr = fn_vkAllocateCommandBuffers(g_vkDev, &cbai, &g_vkCmdBuf);
    if (vr != VK_SUCCESS) return E_FAIL;

    VkFenceCreateInfo fci;
    memset(&fci, 0, fci.sizeof);
    fci.sType = VK_STRUCTURE_TYPE_FENCE_CREATE_INFO;
    fci.flags = VK_FENCE_CREATE_SIGNALED_BIT;
    vr = fn_vkCreateFence(g_vkDev, &fci, null, &g_vkFence);
    if (vr != VK_SUCCESS) return E_FAIL;

    // Cleanup shader modules and SPIR-V data
    fn_vkDestroyShaderModule(g_vkDev, vsMod, null);
    fn_vkDestroyShaderModule(g_vkDev, fsMod, null);
    free(vsSpv.data);
    free(fsSpv.data);

    dbgStep(FN, "ok");
    return S_OK;
}

// ============================================================
// Initialize Windows.UI.Composition for the HWND
// ============================================================
HRESULT InitComposition()
{
    enum FN = "InitComposition";
    HRESULT hr;
    dbgStep(FN, "begin");

    // COM STA
    hr = CoInitializeEx(null, COINIT_APARTMENTTHREADED);
    if (SUCCEEDED(hr)) g_comInitialized = true;
    else if (hr != 0x80010106) // RPC_E_CHANGED_MODE
    { dbgHR(FN, "CoInitializeEx", hr); return hr; }

    // DispatcherQueue
    hr = InitDispatcherQueue();
    if (FAILED(hr)) return hr;

    // WinRT initialization
    hr = RoInitialize(RO_INIT_SINGLETHREADED);
    if (FAILED(hr) && hr != 1 && hr != 0x80010106) return hr; // S_FALSE or RPC_E_CHANGED_MODE

    // Activate Compositor
    static immutable wchar[] compositorClass = "Windows.UI.Composition.Compositor\0"w;
    HSTRING_HEADER hdr;
    HSTRING hsClass;
    hr = createHStringRef(compositorClass.ptr, cast(uint)(compositorClass.length - 1), hdr, hsClass);
    if (FAILED(hr)) return hr;

    void* inspectable;
    hr = RoActivateInstance(hsClass, &inspectable);
    if (FAILED(hr)) { dbgHR(FN, "RoActivateInstance(Compositor)", hr); return hr; }
    g_compositor = inspectable;
    dbgStep(FN, "Compositor created");

    // Desktop interop
    hr = comQI(g_compositor, &IID_ICompositorDesktopInterop, &g_desktopInterop);
    if (FAILED(hr)) return hr;

    hr = CompositorDesktopInterop_CreateDesktopWindowTarget(
        g_desktopInterop, g_hwnd, 0, &g_desktopTarget);
    if (FAILED(hr)) { dbgHR(FN, "CreateDesktopWindowTarget", hr); return hr; }
    dbgStep(FN, "DesktopWindowTarget created");

    // Composition target
    hr = comQI(g_desktopTarget, &IID_ICompositionTarget, &g_compositionTarget);
    if (FAILED(hr)) return hr;

    // Root container visual
    hr = Compositor_CreateContainerVisual(g_compositor, &g_rootVisual);
    if (FAILED(hr)) return hr;

    // Set root
    {
        void* rootAsVisual;
        hr = comQI(g_rootVisual, &IID_IVisual, &rootAsVisual);
        if (FAILED(hr)) return hr;
        hr = CompositionTarget_put_Root(g_compositionTarget, rootAsVisual);
        comRelease(rootAsVisual);
        if (FAILED(hr)) return hr;
    }
    dbgStep(FN, "Root visual set");

    // Compositor interop (for swap chain -> surface)
    hr = comQI(g_compositor, &IID_ICompositorInterop, &g_compInterop);
    if (FAILED(hr)) return hr;

    // Create composition surface from GL panel swap chain
    hr = CompositorInterop_CreateSurfaceForSwapChain(
        g_compInterop, g_swapChain, &g_compositionSurface);
    if (FAILED(hr)) return hr;

    hr = Compositor_CreateSurfaceBrush(g_compositor, g_compositionSurface, &g_surfaceBrush);
    if (FAILED(hr)) return hr;

    hr = Compositor_CreateSpriteVisual(g_compositor, &g_spriteVisual);
    if (FAILED(hr)) return hr;

    hr = comQI(g_surfaceBrush, &IID_ICompositionBrush, &g_compositionBrush);
    if (FAILED(hr)) return hr;
    hr = SpriteVisual_put_Brush(g_spriteVisual, g_compositionBrush);
    if (FAILED(hr)) return hr;

    hr = comQI(g_spriteVisual, &IID_IVisual, &g_visual);
    if (FAILED(hr)) return hr;
    hr = Visual_put_Size(g_visual, cast(float)g_width, cast(float)g_height);

    // Get children collection and insert sprite
    hr = ContainerVisual_get_Children(g_rootVisual, &g_visualCollection);
    if (FAILED(hr)) return hr;

    void* spriteAsVisual;
    hr = comQI(g_spriteVisual, &IID_IVisual, &spriteAsVisual);
    if (FAILED(hr)) return hr;
    hr = VisualCollection_InsertAtTop(g_visualCollection, spriteAsVisual);
    comRelease(spriteAsVisual);
    if (FAILED(hr)) return hr;

    dbgStep(FN, "Composition init complete");
    return S_OK;
}

// ============================================================
// Rendering
// ============================================================
void RenderD3D11Panel()
{
    if (g_dxSwapChain is null || g_dxRtv is null) return;

    D3D11_VIEWPORT vp;
    memset(&vp, 0, vp.sizeof);
    vp.Width = cast(float)g_width;
    vp.Height = cast(float)g_height;
    vp.MaxDepth = 1.0f;
    Ctx_RSSetViewports(g_d3dCtx, 1, &vp);

    void*[1] rtvs = [ g_dxRtv ];
    Ctx_OMSetRenderTargets(g_d3dCtx, 1, rtvs.ptr, null);
    float[4] clearColor = [ 0.05f, 0.15f, 0.05f, 1.0f ];
    Ctx_ClearRenderTargetView(g_d3dCtx, g_dxRtv, clearColor.ptr);

    uint stride = VERTEX.sizeof;
    uint offset = 0;
    void*[1] vbs = [ g_d3dVB ];
    Ctx_IASetInputLayout(g_d3dCtx, g_inputLayout);
    Ctx_IASetVertexBuffers(g_d3dCtx, 0, 1, vbs.ptr, &stride, &offset);
    Ctx_IASetPrimitiveTopology(g_d3dCtx, D3D11_PRIMITIVE_TOPOLOGY_TRIANGLELIST);
    Ctx_VSSetShader(g_d3dCtx, g_d3dVS, null, 0);
    Ctx_PSSetShader(g_d3dCtx, g_d3dPS, null, 0);
    Ctx_Draw(g_d3dCtx, 3, 0);
    SwapChain_Present(g_dxSwapChain, 1, 0);
}

void RenderVulkanPanel()
{
    if (g_vkDev is null || g_vkCmdBuf is null || g_vkFence is null
        || g_vkStagingTex is null || g_vkBackBuffer is null) return;

    fn_vkWaitForFences(g_vkDev, 1, &g_vkFence, 1, UINT64_MAX_VAL);
    fn_vkResetFences(g_vkDev, 1, &g_vkFence);
    fn_vkResetCommandBuffer(g_vkCmdBuf, 0);

    VkCommandBufferBeginInfo bi;
    memset(&bi, 0, bi.sizeof);
    bi.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO;
    if (fn_vkBeginCommandBuffer(g_vkCmdBuf, &bi) != VK_SUCCESS) return;

    VkClearValue cv;
    cv.color.float32 = [ 0.15f, 0.05f, 0.05f, 1.0f ];

    VkRenderPassBeginInfo rpbi;
    memset(&rpbi, 0, rpbi.sizeof);
    rpbi.sType = VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO;
    rpbi.renderPass = g_vkRenderPass;
    rpbi.framebuffer = g_vkFramebuffer;
    rpbi.renderArea.extent.width = g_width;
    rpbi.renderArea.extent.height = g_height;
    rpbi.clearValueCount = 1;
    rpbi.pClearValues = &cv;
    fn_vkCmdBeginRenderPass(g_vkCmdBuf, &rpbi, VK_SUBPASS_CONTENTS_INLINE);
    fn_vkCmdBindPipeline(g_vkCmdBuf, VK_PIPELINE_BIND_POINT_GRAPHICS, g_vkPipeline);
    fn_vkCmdDraw(g_vkCmdBuf, 3, 1, 0, 0);
    fn_vkCmdEndRenderPass(g_vkCmdBuf);

    // Copy offscreen image to readback buffer
    VkBufferImageCopy region;
    memset(&region, 0, region.sizeof);
    region.bufferRowLength = g_width;
    region.bufferImageHeight = g_height;
    region.imageSubresource.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT;
    region.imageSubresource.layerCount = 1;
    region.imageExtent.width = g_width;
    region.imageExtent.height = g_height;
    region.imageExtent.depth = 1;
    fn_vkCmdCopyImageToBuffer(g_vkCmdBuf, g_vkOffImage,
        VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL, g_vkReadbackBuf, 1, &region);

    if (fn_vkEndCommandBuffer(g_vkCmdBuf) != VK_SUCCESS) return;

    VkSubmitInfo si;
    memset(&si, 0, si.sizeof);
    si.sType = VK_STRUCTURE_TYPE_SUBMIT_INFO;
    si.commandBufferCount = 1;
    si.pCommandBuffers = &g_vkCmdBuf;
    fn_vkQueueSubmit(g_vkQueue, 1, &si, g_vkFence);
    fn_vkWaitForFences(g_vkDev, 1, &g_vkFence, 1, UINT64_MAX_VAL);

    // Map readback -> copy to D3D11 staging -> copy to swap chain back buffer
    void* vkData;
    if (fn_vkMapMemory(g_vkDev, g_vkReadbackMem, 0,
            cast(VkDeviceSize)g_width * g_height * 4, 0, &vkData) == VK_SUCCESS)
    {
        D3D11_MAPPED_SUBRESOURCE mapped;
        if (SUCCEEDED(Ctx_Map(g_d3dCtx, g_vkStagingTex, 0, D3D11_MAP_WRITE, 0, &mapped)))
        {
            const(ubyte)* src = cast(const(ubyte)*)vkData;
            ubyte* dst = cast(ubyte*)mapped.pData;
            uint pitch = g_width * 4;
            for (uint y = 0; y < g_height; ++y)
                memcpy(dst + cast(size_t)y * mapped.RowPitch,
                       src + cast(size_t)y * pitch, pitch);
            Ctx_Unmap(g_d3dCtx, g_vkStagingTex, 0);
            Ctx_CopyResource(g_d3dCtx, g_vkBackBuffer, g_vkStagingTex);
        }
        fn_vkUnmapMemory(g_vkDev, g_vkReadbackMem);
    }
    SwapChain_Present(g_vkSwapChain, 1, 0);
}

void RenderGLPanel()
{
    if (g_hdc is null || g_hglrc is null || g_glInteropDevice is null
        || g_glInteropObject is null || g_glFbo == 0) return;
    if (!fn_wglMakeCurrent(g_hdc, g_hglrc)) return;

    void*[1] objs = [ g_glInteropObject ];
    if (!fn_wglDXLockObjectsNV(g_glInteropDevice, 1, objs.ptr)) return;

    fn_glBindFramebuffer(GL_FRAMEBUFFER, g_glFbo);
    fn_glViewport(0, 0, cast(GLsizei)g_width, cast(GLsizei)g_height);
    fn_glClearColor(0.05f, 0.05f, 0.15f, 1.0f);
    fn_glClear(GL_COLOR_BUFFER_BIT);

    fn_glUseProgram(g_glProgram);
    fn_glBindBuffer(GL_ARRAY_BUFFER, g_glVbo[0]);
    fn_glVertexAttribPointer(cast(GLuint)g_glPosAttrib, 3, GL_FLOAT, GL_FALSE, 0, null);
    fn_glBindBuffer(GL_ARRAY_BUFFER, g_glVbo[1]);
    fn_glVertexAttribPointer(cast(GLuint)g_glColAttrib, 3, GL_FLOAT, GL_FALSE, 0, null);
    fn_glDrawArrays(GL_TRIANGLES, 0, 3);
    fn_glFlush();
    fn_glBindFramebuffer(GL_FRAMEBUFFER, 0);

    fn_wglDXUnlockObjectsNV(g_glInteropDevice, 1, objs.ptr);

    SwapChain_Present(g_swapChain, 1, 0);
}

void Render()
{
    RenderGLPanel();
    RenderD3D11Panel();
    RenderVulkanPanel();
}

// ============================================================
// Cleanup
// ============================================================
void CleanupVulkan()
{
    if (g_vkDev !is null) fn_vkDeviceWaitIdle(g_vkDev);
    if (g_vkFence !is null) { fn_vkDestroyFence(g_vkDev, g_vkFence, null); g_vkFence = null; }
    if (g_vkCmdPool !is null) { fn_vkDestroyCommandPool(g_vkDev, g_vkCmdPool, null); g_vkCmdPool = null; }
    if (g_vkPipeline !is null) { fn_vkDestroyPipeline(g_vkDev, g_vkPipeline, null); g_vkPipeline = null; }
    if (g_vkPipeLayout !is null) { fn_vkDestroyPipelineLayout(g_vkDev, g_vkPipeLayout, null); g_vkPipeLayout = null; }
    if (g_vkFramebuffer !is null) { fn_vkDestroyFramebuffer(g_vkDev, g_vkFramebuffer, null); g_vkFramebuffer = null; }
    if (g_vkRenderPass !is null) { fn_vkDestroyRenderPass(g_vkDev, g_vkRenderPass, null); g_vkRenderPass = null; }
    if (g_vkOffView !is null) { fn_vkDestroyImageView(g_vkDev, g_vkOffView, null); g_vkOffView = null; }
    if (g_vkOffImage !is null) { fn_vkDestroyImage(g_vkDev, g_vkOffImage, null); g_vkOffImage = null; }
    if (g_vkOffMemory !is null) { fn_vkFreeMemory(g_vkDev, g_vkOffMemory, null); g_vkOffMemory = null; }
    if (g_vkReadbackBuf !is null) { fn_vkDestroyBuffer(g_vkDev, g_vkReadbackBuf, null); g_vkReadbackBuf = null; }
    if (g_vkReadbackMem !is null) { fn_vkFreeMemory(g_vkDev, g_vkReadbackMem, null); g_vkReadbackMem = null; }
    if (g_vkDev !is null) { fn_vkDestroyDevice(g_vkDev, null); g_vkDev = null; }
    if (g_vkInst !is null) { fn_vkDestroyInstance(g_vkInst, null); g_vkInst = null; }
    if (g_vkStagingTex !is null) { comRelease(g_vkStagingTex); g_vkStagingTex = null; }
    if (g_vkBackBuffer !is null) { comRelease(g_vkBackBuffer); g_vkBackBuffer = null; }
}

void Cleanup()
{
    dbgStep("Cleanup", "begin");

    // Composition objects (reverse creation order)
    comRelease(g_visualCollection);  g_visualCollection = null;
    comRelease(g_vkVisualObj);       g_vkVisualObj = null;
    comRelease(g_vkCompositionBrush); g_vkCompositionBrush = null;
    comRelease(g_vkSpriteVisual);    g_vkSpriteVisual = null;
    comRelease(g_vkSurfaceBrush);    g_vkSurfaceBrush = null;
    comRelease(g_vkCompositionSurface); g_vkCompositionSurface = null;
    comRelease(g_dxVisual);          g_dxVisual = null;
    comRelease(g_dxCompositionBrush); g_dxCompositionBrush = null;
    comRelease(g_dxSpriteVisual);    g_dxSpriteVisual = null;
    comRelease(g_dxSurfaceBrush);    g_dxSurfaceBrush = null;
    comRelease(g_dxCompositionSurface); g_dxCompositionSurface = null;
    comRelease(g_visual);            g_visual = null;
    comRelease(g_compositionBrush);  g_compositionBrush = null;
    comRelease(g_spriteVisual);      g_spriteVisual = null;
    comRelease(g_surfaceBrush);      g_surfaceBrush = null;
    comRelease(g_compositionSurface); g_compositionSurface = null;
    comRelease(g_rootVisual);        g_rootVisual = null;
    comRelease(g_compositionTarget); g_compositionTarget = null;
    comRelease(g_desktopTarget);     g_desktopTarget = null;
    comRelease(g_compInterop);       g_compInterop = null;
    comRelease(g_desktopInterop);    g_desktopInterop = null;
    comRelease(g_compositor);        g_compositor = null;

    // Vulkan
    CleanupVulkan();

    // OpenGL / WGL NV interop
    if (g_glInteropObject !is null && g_glInteropDevice !is null && fn_wglDXUnregisterObjectNV !is null)
    {
        fn_wglDXUnregisterObjectNV(g_glInteropDevice, g_glInteropObject);
        g_glInteropObject = null;
    }
    if (g_glInteropDevice !is null && fn_wglDXCloseDeviceNV !is null)
    {
        fn_wglDXCloseDeviceNV(g_glInteropDevice);
        g_glInteropDevice = null;
    }
    if (g_hdc !is null && g_hglrc !is null) fn_wglMakeCurrent(g_hdc, g_hglrc);
    if (g_glProgram != 0 && fn_glDeleteProgram !is null) { fn_glDeleteProgram(g_glProgram); g_glProgram = 0; }
    if (g_glVbo[0] != 0 && fn_glDeleteBuffers !is null) { fn_glDeleteBuffers(2, g_glVbo.ptr); g_glVbo[0] = 0; g_glVbo[1] = 0; }
    if (g_glVao != 0 && fn_glDeleteVertexArrays !is null) { fn_glDeleteVertexArrays(1, &g_glVao); g_glVao = 0; }
    if (g_glFbo != 0 && fn_glDeleteFramebuffers !is null) { fn_glDeleteFramebuffers(1, &g_glFbo); g_glFbo = 0; }
    if (g_glRbo != 0 && fn_glDeleteRenderbuffers !is null) { fn_glDeleteRenderbuffers(1, &g_glRbo); g_glRbo = 0; }
    if (g_hglrc !is null)
    {
        fn_wglMakeCurrent(null, null);
        fn_wglDeleteContext(g_hglrc);
        g_hglrc = null;
    }
    if (g_hdc !is null && g_hwnd !is null)
    {
        ReleaseDC(g_hwnd, g_hdc);
        g_hdc = null;
    }

    // D3D11 objects
    comRelease(g_d3dVB);       g_d3dVB = null;
    comRelease(g_inputLayout); g_inputLayout = null;
    comRelease(g_d3dPS);       g_d3dPS = null;
    comRelease(g_d3dVS);       g_d3dVS = null;
    comRelease(g_rtv);         g_rtv = null;
    comRelease(g_dxRtv);       g_dxRtv = null;
    comRelease(g_backBuffer);  g_backBuffer = null;
    comRelease(g_swapChain);   g_swapChain = null;
    comRelease(g_dxSwapChain); g_dxSwapChain = null;
    comRelease(g_vkSwapChain); g_vkSwapChain = null;
    comRelease(g_d3dCtx);      g_d3dCtx = null;
    comRelease(g_d3dDevice);   g_d3dDevice = null;

    // DispatcherQueue
    comRelease(g_dqController); g_dqController = null;

    RoUninitialize();
    if (g_comInitialized) { CoUninitialize(); g_comInitialized = false; }

    dbgStep("Cleanup", "ok");
}

// ============================================================
// Entry point
// ============================================================
extern(Windows)
int WinMain(HINSTANCE hInst, HINSTANCE hPrev, LPSTR lpCmdLine, int nShowCmd)
{
    HRESULT hr;
    dbgStep("WinMain", "start");

    // Load all required DLLs
    if (!loadCombaseFunctions())   { dbgStep("WinMain", "FATAL: combase.dll"); return 1; }
    if (!loadD3D11Functions())     { dbgStep("WinMain", "FATAL: d3d11.dll"); return 1; }
    if (!loadD3DCompiler())        { dbgStep("WinMain", "FATAL: d3dcompiler_47.dll"); return 1; }
    if (!loadCoreMessaging())      { dbgStep("WinMain", "FATAL: CoreMessaging.dll"); return 1; }
    if (!loadOpenGL32())           { dbgStep("WinMain", "FATAL: opengl32.dll"); return 1; }
    if (!loadVulkan())             { dbgStep("WinMain", "FATAL: vulkan-1.dll"); return 1; }
    dbgStep("WinMain", "all DLLs loaded");

    hr = CreateAppWindow(hInst);
    if (FAILED(hr)) { Cleanup(); return cast(int)hr; }

    hr = InitD3D11();
    if (FAILED(hr)) { dbgStep("WinMain", "FATAL: InitD3D11"); Cleanup(); return cast(int)hr; }

    hr = InitComposition();
    if (FAILED(hr)) { dbgStep("WinMain", "FATAL: InitComposition"); Cleanup(); return cast(int)hr; }

    hr = InitOpenGL();
    if (FAILED(hr)) { dbgStep("WinMain", "FATAL: InitOpenGL"); Cleanup(); return cast(int)hr; }

    hr = InitD3D11SecondPanel();
    if (FAILED(hr)) { dbgStep("WinMain", "FATAL: InitD3D11SecondPanel"); Cleanup(); return cast(int)hr; }

    hr = InitVulkanThirdPanel();
    if (FAILED(hr)) { dbgStep("WinMain", "FATAL: InitVulkanThirdPanel"); Cleanup(); return cast(int)hr; }

    dbgStep("WinMain", "=== ENTERING MESSAGE LOOP ===");
    MSG msg;
    memset(&msg, 0, msg.sizeof);
    while (msg.message != WM_QUIT)
    {
        if (PeekMessageW(&msg, null, 0, 0, PM_REMOVE_))
        {
            TranslateMessage(&msg);
            DispatchMessageW(&msg);
        }
        else
        {
            Render();
        }
    }

    dbgStep("WinMain", "loop end");
    Cleanup();
    return 0;
}