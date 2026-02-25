/* hello.d
 * Win32 + DirectComposition: composite OpenGL / D3D11 / Vulkan triangles.
 *
 * D language port of the C implementation.
 * Uses raw COM vtable calls for DirectComposition and WinRT interfaces,
 * WGL_NV_DX_interop for OpenGL->DXGI interop, and Vulkan offscreen
 * rendering with CPU readback into a D3D11 staging texture.
 *
 * Build (LDC example, adjust paths as needed):
 *   ldc2 hello.d ^
 *     -L/SUBSYSTEM:WINDOWS ^
 *     -Luser32.lib -Lgdi32.lib -Lopengl32.lib ^
 *     -Ld3d11.lib -Ldxgi.lib -Ld3dcompiler.lib -Ldcomp.lib ^
 *     -LCoreMessaging.lib -Lwindowsapp.lib -Lruntimeobject.lib ^
 *     -Lvulkan-1.lib -Lole32.lib
 */
module hello;

import core.sys.windows.windef;
import core.sys.windows.winuser;
import core.sys.windows.wingdi;
import core.sys.windows.winbase;
import core.sys.windows.basetsd;
import core.stdc.string : memcpy, memset, strlen;
import core.stdc.stdlib : malloc, free;
import core.stdc.stdio : fopen, fclose, fread, fseek, ftell, snprintf, FILE, SEEK_END, SEEK_SET;

/* ============================================================
 * Basic type aliases
 * ============================================================ */
alias FLOAT  = float;
alias UINT64 = ulong;
alias INT32  = int;
alias CHAR   = char;
alias WCHAR  = wchar;
alias BOOL   = int;
alias BYTE   = ubyte;
alias DWORD  = uint;
alias LONG   = int;
alias ULONG  = uint;
alias UINT   = uint;
alias USHORT = ushort;
alias SIZE_T = size_t;
alias LPVOID = void*;
alias PVOID  = void*;
alias PWSTR  = wchar*;
alias LPCWSTR = const(wchar)*;
alias LPCSTR  = const(char)*;
alias LPSTR   = char*;

enum int TRUE  = 1;
enum int FALSE = 0;

enum : uint {
    S_OK            = 0,
    E_FAIL          = 0x80004005,
    E_INVALIDARG    = 0x80070057,
    E_OUTOFMEMORY   = 0x8007000E,
    RPC_E_CHANGED_MODE = 0x80010106,
}

enum uint ERROR_CLASS_ALREADY_EXISTS = 1410;

bool FAILED(uint hr) { return (cast(int)hr) < 0; }
bool SUCCEEDED(uint hr) { return (cast(int)hr) >= 0; }
uint HRESULT_FROM_WIN32(uint x) { return x <= 0 ? x : ((x & 0x0000FFFF) | 0x80070000); }

enum uint COINIT_APARTMENTTHREADED = 0x2;

enum uint WS_EX_NOREDIRECTIONBITMAP = 0x00200000;

/* ============================================================
 * GUID / IID
 * ============================================================ */
struct GUID {
    uint   Data1;
    ushort Data2;
    ushort Data3;
    ubyte[8] Data4;
}
alias IID = GUID;
alias REFIID = const(GUID)*;

bool guidEq(ref const GUID a, ref const GUID b) {
    return a.Data1 == b.Data1 && a.Data2 == b.Data2 &&
           a.Data3 == b.Data3 && a.Data4 == b.Data4;
}

/* ============================================================
 * Minimal COM: IUnknown
 * ============================================================ */
struct IUnknownVtbl {
    extern(Windows) uint function(void*, const(GUID)*, void**) QueryInterface;
    extern(Windows) uint function(void*) AddRef;
    extern(Windows) uint function(void*) Release;
}

struct IUnknown {
    IUnknownVtbl* lpVtbl;
}

uint QI(void* pObj, const(GUID)* riid, void** ppOut) {
    return (cast(IUnknown*)pObj).lpVtbl.QueryInterface(pObj, riid, ppOut);
}

uint Rel(void* pObj) {
    if (pObj) return (cast(IUnknown*)pObj).lpVtbl.Release(pObj);
    return 0;
}

/* ============================================================
 * HSTRING (opaque handle for WinRT)
 * ============================================================ */
alias HSTRING = void*;

/* ============================================================
 * Vtable slot helpers (equivalent to C VTBL/SLOT macros)
 * ============================================================ */
void** VTBL(void* obj) {
    return (cast(void***)obj)[0];
}

void* SLOT(void* obj, size_t i) {
    return VTBL(obj)[i];
}

/* ============================================================
 * Vertex definition
 * ============================================================ */
struct VERTEX {
    float x, y, z;
    float r, g, b, a;
}

/* ============================================================
 * Numerics types (for WinRT Composition)
 * ============================================================ */
struct Vector2 { float X; float Y; }
struct Vector3 { float X; float Y; float Z; }

/* ============================================================
 * FILEDATA for SPIR-V loading
 * ============================================================ */
struct FILEDATA {
    ubyte* data;
    size_t size;
}

/* ============================================================
 * DXGI / D3D11 structures and enums (minimal set)
 * ============================================================ */
enum DXGI_FORMAT : uint {
    DXGI_FORMAT_UNKNOWN            = 0,
    DXGI_FORMAT_R32G32B32A32_FLOAT = 2,
    DXGI_FORMAT_R32G32B32_FLOAT    = 6,
    DXGI_FORMAT_B8G8R8A8_UNORM     = 87,
}

enum DXGI_SWAP_EFFECT : uint {
    DXGI_SWAP_EFFECT_FLIP_SEQUENTIAL = 3,
}

enum DXGI_SCALING : uint {
    DXGI_SCALING_STRETCH = 0,
}

enum DXGI_ALPHA_MODE : uint {
    DXGI_ALPHA_MODE_PREMULTIPLIED = 1,
}

struct DXGI_SAMPLE_DESC { uint Count; uint Quality; }

struct DXGI_SWAP_CHAIN_DESC1 {
    uint Width;
    uint Height;
    DXGI_FORMAT Format;
    int Stereo;
    DXGI_SAMPLE_DESC SampleDesc;
    uint BufferUsage;
    uint BufferCount;
    DXGI_SCALING Scaling;
    DXGI_SWAP_EFFECT SwapEffect;
    DXGI_ALPHA_MODE AlphaMode;
    uint Flags;
}

enum uint DXGI_USAGE_RENDER_TARGET_OUTPUT = 0x00000020;

/* IDXGISwapChain1 vtable (IUnknown=3 + IDXGIObject=1 + IDXGIDeviceSubObject=1 + IDXGISwapChain=10 + IDXGISwapChain1) */
struct IDXGISwapChain1Vtbl {
    /* IUnknown (0-2) */
    extern(Windows) uint function(void*, const(GUID)*, void**) QueryInterface;
    extern(Windows) uint function(void*) AddRef;
    extern(Windows) uint function(void*) Release;
    /* IDXGIObject (3-6) */
    void* SetPrivateData;
    void* SetPrivateDataInterface;
    void* GetPrivateData;
    void* GetParent;
    /* IDXGIDeviceSubObject (7) */
    void* GetDevice;
    /* IDXGISwapChain (8-17) */
    extern(Windows) uint function(void*, uint, uint) Present;  /* 8 */
    extern(Windows) uint function(void*, uint, const(GUID)*, void**) GetBuffer;  /* 9 */
    void* SetFullscreenState;   /* 10 */
    void* GetFullscreenState;   /* 11 */
    void* GetDesc;              /* 12 */
    void* ResizeBuffers;        /* 13 */
    void* ResizeTarget;         /* 14 */
    void* GetContainingOutput;  /* 15 */
    void* GetFrameStatistics;   /* 16 */
    void* GetLastPresentCount;  /* 17 */
}

struct IDXGISwapChain1 { IDXGISwapChain1Vtbl* lpVtbl; }

/* IDXGIFactory2 vtable (we only need CreateSwapChainForComposition at slot 24) */
struct IDXGIFactory2Vtbl {
    /* IUnknown (0-2) */
    extern(Windows) uint function(void*, const(GUID)*, void**) QueryInterface;
    extern(Windows) uint function(void*) AddRef;
    extern(Windows) uint function(void*) Release;
    /* IDXGIObject (3-6) */
    void*[4] dxgiObj;
    /* IDXGIFactory (7-13) */
    void*[7] dxgiFactory;
    /* IDXGIFactory1 (14-15) */
    void*[2] dxgiFactory1;
    /* IDXGIFactory2 (16-24) */
    void* IsWindowedStereoEnabled;   /* 16 */
    void* CreateSwapChainForHwnd;    /* 17 */
    extern(Windows) uint function(void*, void*, const(DXGI_SWAP_CHAIN_DESC1)*, void*, IDXGISwapChain1**) CreateSwapChainForComposition; /* 18? */
    /* NOTE: actual slot varies. We compute via GetParent. Let's use a function pointer from the slot. */
}

struct IDXGIFactory2 { IDXGIFactory2Vtbl* lpVtbl; }

/* IDXGIDevice vtable */
struct IDXGIDeviceVtbl {
    extern(Windows) uint function(void*, const(GUID)*, void**) QueryInterface;
    extern(Windows) uint function(void*) AddRef;
    extern(Windows) uint function(void*) Release;
    void*[4] dxgiObj;
    extern(Windows) uint function(void*, void**) GetAdapter; /* slot 7 */
}

struct IDXGIDevice { IDXGIDeviceVtbl* lpVtbl; }

/* IDXGIAdapter vtable */
struct IDXGIAdapterVtbl {
    extern(Windows) uint function(void*, const(GUID)*, void**) QueryInterface;
    extern(Windows) uint function(void*) AddRef;
    extern(Windows) uint function(void*) Release;
    void*[4] dxgiObj_with_GetParent;
}

struct IDXGIAdapter { IDXGIAdapterVtbl* lpVtbl; }

/* D3D11 enums */
enum D3D_DRIVER_TYPE : uint { D3D_DRIVER_TYPE_HARDWARE = 1 }
enum D3D_FEATURE_LEVEL : uint { D3D_FEATURE_LEVEL_11_0 = 0xb000 }
enum D3D11_USAGE : uint { D3D11_USAGE_DEFAULT = 0, D3D11_USAGE_STAGING = 3 }
enum D3D11_BIND_FLAG : uint { D3D11_BIND_VERTEX_BUFFER = 0x1, D3D11_BIND_RENDER_TARGET = 0x20 }
enum D3D11_CPU_ACCESS_FLAG : uint { D3D11_CPU_ACCESS_WRITE = 0x10000 }
enum D3D11_MAP : uint { D3D11_MAP_WRITE = 2 }

enum uint D3D11_CREATE_DEVICE_BGRA_SUPPORT = 0x20;
enum uint D3D11_SDK_VERSION = 7;

enum uint D3D11_PRIMITIVE_TOPOLOGY_TRIANGLELIST = 4;

struct D3D11_VIEWPORT {
    float TopLeftX;
    float TopLeftY;
    float Width;
    float Height;
    float MinDepth;
    float MaxDepth;
}

struct D3D11_TEXTURE2D_DESC {
    uint Width;
    uint Height;
    uint MipLevels;
    uint ArraySize;
    DXGI_FORMAT Format;
    DXGI_SAMPLE_DESC SampleDesc;
    D3D11_USAGE Usage;
    uint BindFlags;
    uint CPUAccessFlags;
    uint MiscFlags;
}

struct D3D11_SUBRESOURCE_DATA {
    const(void)* pSysMem;
    uint SysMemPitch;
    uint SysMemSlicePitch;
}

struct D3D11_BUFFER_DESC {
    uint ByteWidth;
    D3D11_USAGE Usage;
    uint BindFlags;
    uint CPUAccessFlags;
    uint MiscFlags;
    uint StructureByteStride;
}

struct D3D11_MAPPED_SUBRESOURCE {
    void* pData;
    uint RowPitch;
    uint DepthPitch;
}

struct D3D11_INPUT_ELEMENT_DESC {
    const(char)* SemanticName;
    uint SemanticIndex;
    DXGI_FORMAT Format;
    uint InputSlot;
    uint AlignedByteOffset;
    uint InputSlotClass;
    uint InstanceDataStepRate;
}

enum uint D3D11_INPUT_PER_VERTEX_DATA = 0;

enum uint D3DCOMPILE_ENABLE_STRICTNESS = (1 << 11);

/* D3D11Device opaque - we call through vtable slots */
alias ID3D11Device = void;
alias ID3D11DeviceContext = void;
alias ID3D11Texture2D = void;
alias ID3D11RenderTargetView = void;
alias ID3D11VertexShader = void;
alias ID3D11PixelShader = void;
alias ID3D11InputLayout = void;
alias ID3D11Buffer = void;
alias ID3DBlob = void;

/* ============================================================
 * IID constants
 * ============================================================ */
static immutable GUID IID_IDXGIDevice = GUID(0x54ec77fa, 0x1377, 0x44e6, [0x8c, 0x32, 0x88, 0xfd, 0x5f, 0x44, 0xc8, 0x4c]);
static immutable GUID IID_IDXGIFactory2 = GUID(0x50c83a1c, 0xe072, 0x4c48, [0x87, 0xb0, 0x36, 0x30, 0xfa, 0x36, 0xa6, 0xd0]);
static immutable GUID IID_ID3D11Texture2D = GUID(0x6f15aaf2, 0xd208, 0x4e89, [0x9a, 0xb4, 0x48, 0x95, 0x35, 0xd3, 0x4f, 0x9c]);
static immutable GUID IID_IDCompositionDevice_C = GUID(0xC37EA93A, 0xE7AA, 0x450D, [0xB1, 0x6F, 0x97, 0x46, 0xCB, 0x04, 0x07, 0xF3]);

/* ============================================================
 * OpenGL / WGL constants
 * ============================================================ */
alias GLuint    = uint;
alias GLint     = int;
alias GLsizei   = int;
alias GLenum    = uint;
alias GLfloat   = float;
alias GLchar    = char;
alias GLboolean = ubyte;
alias GLbitfield = uint;
alias GLsizeiptr = ptrdiff_t;

enum : uint {
    GL_COLOR_BUFFER_BIT       = 0x00004000,
    GL_TRIANGLES              = 0x0004,
    GL_FLOAT                  = 0x1406,
    GL_RENDERBUFFER           = 0x8D41,
    GL_FRAMEBUFFER            = 0x8D40,
    GL_COLOR_ATTACHMENT0      = 0x8CE0,
    GL_FRAMEBUFFER_COMPLETE   = 0x8CD5,
    GL_ARRAY_BUFFER           = 0x8892,
    GL_STATIC_DRAW            = 0x88E4,
    GL_VERTEX_SHADER          = 0x8B31,
    GL_FRAGMENT_SHADER        = 0x8B30,
    GL_COMPILE_STATUS         = 0x8B81,
    GL_LINK_STATUS            = 0x8B82,
}

enum : int {
    WGL_CONTEXT_MAJOR_VERSION_ARB    = 0x2091,
    WGL_CONTEXT_MINOR_VERSION_ARB    = 0x2092,
    WGL_CONTEXT_FLAGS_ARB            = 0x2094,
    WGL_CONTEXT_PROFILE_MASK_ARB     = 0x9126,
    WGL_CONTEXT_CORE_PROFILE_BIT_ARB = 0x00000001,
    WGL_ACCESS_READ_WRITE_NV         = 0x0001,
}

enum : uint {
    PFD_DRAW_TO_WINDOW = 0x00000004,
    PFD_SUPPORT_OPENGL = 0x00000020,
    PFD_DOUBLEBUFFER   = 0x00000001,
    PFD_TYPE_RGBA      = 0,
    PFD_MAIN_PLANE     = 0,
}

struct PIXELFORMATDESCRIPTOR {
    ushort nSize;
    ushort nVersion;
    uint   dwFlags;
    ubyte  iPixelType;
    ubyte  cColorBits;
    ubyte  cRedBits, cRedShift;
    ubyte  cGreenBits, cGreenShift;
    ubyte  cBlueBits, cBlueShift;
    ubyte  cAlphaBits, cAlphaShift;
    ubyte  cAccumBits;
    ubyte  cAccumRedBits, cAccumGreenBits, cAccumBlueBits, cAccumAlphaBits;
    ubyte  cDepthBits;
    ubyte  cStencilBits;
    ubyte  cAuxBuffers;
    ubyte  iLayerType;
    ubyte  bReserved;
    uint   dwLayerMask;
    uint   dwVisibleMask;
    uint   dwDamageMask;
}

/* ============================================================
 * Vulkan types and enums (minimal set for offscreen triangle)
 * ============================================================ */
alias VkInstance       = void*;
alias VkPhysicalDevice = void*;
alias VkDevice         = void*;
alias VkQueue          = void*;
alias VkImage          = ulong;
alias VkDeviceMemory   = ulong;
alias VkImageView      = ulong;
alias VkBuffer         = ulong;
alias VkRenderPass     = ulong;
alias VkFramebuffer_   = ulong;  /* renamed to avoid clash */
alias VkPipelineLayout = ulong;
alias VkPipeline       = ulong;
alias VkCommandPool    = ulong;
alias VkCommandBuffer  = void*;
alias VkFence          = ulong;
alias VkShaderModule   = ulong;
alias VkDeviceSize     = ulong;
alias VkFlags          = uint;
alias VkBool32         = uint;
alias VkResult         = int;

enum VkResult VK_SUCCESS = 0;

enum : uint {
    VK_STRUCTURE_TYPE_APPLICATION_INFO                  = 0,
    VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO              = 1,
    VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO          = 2,
    VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO                = 3,
    VK_STRUCTURE_TYPE_SUBMIT_INFO                       = 4,
    VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO              = 5,
    VK_STRUCTURE_TYPE_FENCE_CREATE_INFO                 = 8,
    VK_STRUCTURE_TYPE_IMAGE_CREATE_INFO                 = 14,
    VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO            = 15,
    VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO         = 16,
    VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO = 18,
    VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO = 19,
    VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO = 20,
    VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO = 22,
    VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO = 23,
    VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO = 24,
    VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO = 26,
    VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO       = 30,
    VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO           = 38,
    VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO          = 39,
    VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO      = 40,
    VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO         = 42,
    VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO            = 43,
    VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO                = 12,
    VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO           = 37,
    VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO     = 28,
}

enum uint VK_API_VERSION_1_0 = (1 << 22) | (0 << 12);

uint VK_MAKE_API_VERSION(uint variant, uint major, uint minor, uint patch) {
    return (variant << 29) | (major << 22) | (minor << 12) | patch;
}

enum : uint {
    VK_IMAGE_TYPE_2D                     = 1,
    VK_FORMAT_B8G8R8A8_UNORM            = 44,
    VK_SAMPLE_COUNT_1_BIT               = 1,
    VK_IMAGE_TILING_OPTIMAL             = 0,
    VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT = 0x10,
    VK_IMAGE_USAGE_TRANSFER_SRC_BIT     = 0x01,
    VK_IMAGE_LAYOUT_UNDEFINED           = 0,
    VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL = 2,
    VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL = 6,
    VK_IMAGE_VIEW_TYPE_2D               = 1,
    VK_IMAGE_ASPECT_COLOR_BIT           = 1,
    VK_BUFFER_USAGE_TRANSFER_DST_BIT    = 0x02,
    VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT = 0x01,
    VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT = 0x02,
    VK_MEMORY_PROPERTY_HOST_COHERENT_BIT = 0x04,
    VK_ATTACHMENT_LOAD_OP_CLEAR         = 1,
    VK_ATTACHMENT_STORE_OP_STORE        = 0,
    VK_ATTACHMENT_LOAD_OP_DONT_CARE     = 2,
    VK_ATTACHMENT_STORE_OP_DONT_CARE    = 1,
    VK_PIPELINE_BIND_POINT_GRAPHICS     = 0,
    VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST = 3,
    VK_POLYGON_MODE_FILL                = 0,
    VK_CULL_MODE_BACK_BIT               = 2,
    VK_FRONT_FACE_CLOCKWISE             = 1,
    VK_SHADER_STAGE_VERTEX_BIT          = 1,
    VK_SHADER_STAGE_FRAGMENT_BIT        = 0x10,
    VK_COMMAND_BUFFER_LEVEL_PRIMARY     = 0,
    VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT = 0x02,
    VK_FENCE_CREATE_SIGNALED_BIT        = 0x01,
    VK_SUBPASS_CONTENTS_INLINE          = 0,
    VK_QUEUE_GRAPHICS_BIT               = 1,
}

struct VkApplicationInfo {
    uint sType;
    const(void)* pNext;
    const(char)* pApplicationName;
    uint applicationVersion;
    const(char)* pEngineName;
    uint engineVersion;
    uint apiVersion;
}

struct VkInstanceCreateInfo {
    uint sType;
    const(void)* pNext;
    uint flags;
    const(VkApplicationInfo)* pApplicationInfo;
    uint enabledLayerCount;
    const(char*)* ppEnabledLayerNames;
    uint enabledExtensionCount;
    const(char*)* ppEnabledExtensionNames;
}

struct VkDeviceQueueCreateInfo {
    uint sType;
    const(void)* pNext;
    uint flags;
    uint queueFamilyIndex;
    uint queueCount;
    const(float)* pQueuePriorities;
}

struct VkDeviceCreateInfo {
    uint sType;
    const(void)* pNext;
    uint flags;
    uint queueCreateInfoCount;
    const(VkDeviceQueueCreateInfo)* pQueueCreateInfos;
    uint enabledLayerCount;
    const(char*)* ppEnabledLayerNames;
    uint enabledExtensionCount;
    const(char*)* ppEnabledExtensionNames;
    const(void)* pEnabledFeatures;
}

struct VkQueueFamilyProperties {
    uint queueFlags;
    uint queueCount;
    uint timestampValidBits;
    uint[3] minImageTransferGranularity;
}

struct VkPhysicalDeviceMemoryProperties {
    uint memoryTypeCount;
    VkMemoryType[32] memoryTypes;
    uint memoryHeapCount;
    VkMemoryHeap[16] memoryHeaps;
}

struct VkMemoryType { uint propertyFlags; uint heapIndex; }
struct VkMemoryHeap { ulong size; uint flags; }

struct VkImageCreateInfo {
    uint sType; const(void)* pNext; uint flags;
    uint imageType;
    uint format;
    VkExtent3D extent;
    uint mipLevels; uint arrayLayers;
    uint samples; uint tiling; uint usage;
    uint sharingMode;
    uint queueFamilyIndexCount;
    const(uint)* pQueueFamilyIndices;
    uint initialLayout;
}

struct VkExtent3D { uint width; uint height; uint depth; }

struct VkMemoryRequirements { ulong size; ulong alignment; uint memoryTypeBits; }

struct VkMemoryAllocateInfo {
    uint sType; const(void)* pNext;
    ulong allocationSize;
    uint memoryTypeIndex;
}

struct VkImageViewCreateInfo {
    uint sType; const(void)* pNext; uint flags;
    VkImage image;
    uint viewType; uint format;
    VkComponentMapping components;
    VkImageSubresourceRange subresourceRange;
}

struct VkComponentMapping { uint r; uint g; uint b; uint a; }
struct VkImageSubresourceRange { uint aspectMask; uint baseMipLevel; uint levelCount; uint baseArrayLayer; uint layerCount; }

struct VkBufferCreateInfo {
    uint sType; const(void)* pNext; uint flags;
    ulong size; uint usage; uint sharingMode;
    uint queueFamilyIndexCount; const(uint)* pQueueFamilyIndices;
}

struct VkAttachmentDescription {
    uint flags; uint format; uint samples;
    uint loadOp; uint storeOp;
    uint stencilLoadOp; uint stencilStoreOp;
    uint initialLayout; uint finalLayout;
}

struct VkAttachmentReference { uint attachment; uint layout; }

struct VkSubpassDescription {
    uint flags; uint pipelineBindPoint;
    uint inputAttachmentCount; const(VkAttachmentReference)* pInputAttachments;
    uint colorAttachmentCount; const(VkAttachmentReference)* pColorAttachments;
    const(VkAttachmentReference)* pResolveAttachments;
    const(VkAttachmentReference)* pDepthStencilAttachment;
    uint preserveAttachmentCount; const(uint)* pPreserveAttachments;
}

struct VkRenderPassCreateInfo {
    uint sType; const(void)* pNext; uint flags;
    uint attachmentCount; const(VkAttachmentDescription)* pAttachments;
    uint subpassCount; const(VkSubpassDescription)* pSubpasses;
    uint dependencyCount; const(void)* pDependencies;
}

struct VkFramebufferCreateInfo {
    uint sType; const(void)* pNext; uint flags;
    VkRenderPass renderPass;
    uint attachmentCount; const(VkImageView)* pAttachments;
    uint width; uint height; uint layers;
}

struct VkShaderModuleCreateInfo {
    uint sType; const(void)* pNext; uint flags;
    size_t codeSize; const(uint)* pCode;
}

struct VkPipelineShaderStageCreateInfo {
    uint sType; const(void)* pNext; uint flags;
    uint stage;
    VkShaderModule _module;
    const(char)* pName;
    const(void)* pSpecializationInfo;
}

struct VkPipelineVertexInputStateCreateInfo {
    uint sType; const(void)* pNext; uint flags;
    uint vertexBindingDescriptionCount; const(void)* pVertexBindingDescriptions;
    uint vertexAttributeDescriptionCount; const(void)* pVertexAttributeDescriptions;
}

struct VkPipelineInputAssemblyStateCreateInfo {
    uint sType; const(void)* pNext; uint flags;
    uint topology; uint primitiveRestartEnable;
}

struct VkViewport { float x; float y; float width; float height; float minDepth; float maxDepth; }
struct VkOffset2D { int x; int y; }
struct VkExtent2D { uint width; uint height; }
struct VkRect2D { VkOffset2D offset; VkExtent2D extent; }

struct VkPipelineViewportStateCreateInfo {
    uint sType; const(void)* pNext; uint flags;
    uint viewportCount; const(VkViewport)* pViewports;
    uint scissorCount; const(VkRect2D)* pScissors;
}

struct VkPipelineRasterizationStateCreateInfo {
    uint sType; const(void)* pNext; uint flags;
    uint depthClampEnable; uint rasterizerDiscardEnable;
    uint polygonMode;
    uint cullMode; uint frontFace;
    uint depthBiasEnable; float depthBiasConstantFactor; float depthBiasClamp; float depthBiasSlopeFactor;
    float lineWidth;
}

struct VkPipelineMultisampleStateCreateInfo {
    uint sType; const(void)* pNext; uint flags;
    uint rasterizationSamples;
    uint sampleShadingEnable; float minSampleShading;
    const(void)* pSampleMask;
    uint alphaToCoverageEnable; uint alphaToOneEnable;
}

struct VkPipelineColorBlendAttachmentState {
    uint blendEnable;
    uint srcColorBlendFactor; uint dstColorBlendFactor; uint colorBlendOp;
    uint srcAlphaBlendFactor; uint dstAlphaBlendFactor; uint alphaBlendOp;
    uint colorWriteMask;
}

struct VkPipelineColorBlendStateCreateInfo {
    uint sType; const(void)* pNext; uint flags;
    uint logicOpEnable; uint logicOp;
    uint attachmentCount; const(VkPipelineColorBlendAttachmentState)* pAttachments;
    float[4] blendConstants;
}

struct VkPipelineLayoutCreateInfo {
    uint sType; const(void)* pNext; uint flags;
    uint setLayoutCount; const(void)* pSetLayouts;
    uint pushConstantRangeCount; const(void)* pPushConstantRanges;
}

struct VkGraphicsPipelineCreateInfo {
    uint sType; const(void)* pNext; uint flags;
    uint stageCount; const(VkPipelineShaderStageCreateInfo)* pStages;
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

struct VkCommandPoolCreateInfo {
    uint sType; const(void)* pNext; uint flags;
    uint queueFamilyIndex;
}

struct VkCommandBufferAllocateInfo {
    uint sType; const(void)* pNext;
    VkCommandPool commandPool;
    uint level; uint commandBufferCount;
}

struct VkCommandBufferBeginInfo {
    uint sType; const(void)* pNext; uint flags;
    const(void)* pInheritanceInfo;
}

struct VkClearColorValue { float[4] float32; }
struct VkClearValue { VkClearColorValue color; }

struct VkRenderPassBeginInfo {
    uint sType; const(void)* pNext;
    VkRenderPass renderPass;
    VkFramebuffer_ framebuffer;
    VkRect2D renderArea;
    uint clearValueCount; const(VkClearValue)* pClearValues;
}

struct VkImageSubresourceLayers { uint aspectMask; uint mipLevel; uint baseArrayLayer; uint layerCount; }
struct VkOffset3D { int x; int y; int z; }

struct VkBufferImageCopy {
    ulong bufferOffset;
    uint bufferRowLength; uint bufferImageHeight;
    VkImageSubresourceLayers imageSubresource;
    VkOffset3D imageOffset;
    VkExtent3D imageExtent;
}

struct VkSubmitInfo {
    uint sType; const(void)* pNext;
    uint waitSemaphoreCount; const(void)* pWaitSemaphores; const(void)* pWaitDstStageMask;
    uint commandBufferCount; const(VkCommandBuffer)* pCommandBuffers;
    uint signalSemaphoreCount; const(void)* pSignalSemaphores;
}

struct VkFenceCreateInfo {
    uint sType; const(void)* pNext; uint flags;
}

/* ============================================================
 * External Win32 / D3D / OpenGL / Vulkan function declarations
 * ============================================================ */
extern(Windows):

/* kernel32 */
void  OutputDebugStringW(const(wchar)*) nothrow @nogc;
void  OutputDebugStringA(const(char)*) nothrow @nogc;
HANDLE GetModuleHandleA(const(char)*);
void* GetProcAddress(HANDLE, const(char)*);

/* ole32 */
uint CoInitializeEx(void*, uint);
void CoUninitialize();

/* d3d11 */
uint D3D11CreateDevice(
    void* pAdapter, uint DriverType, void* Software, uint Flags,
    const(uint)* pFeatureLevels, uint FeatureLevels,
    uint SDKVersion,
    void** ppDevice, uint* pFeatureLevel, void** ppImmediateContext);

/* d3dcompiler */
uint D3DCompile(
    const(void)* pSrcData, size_t SrcDataSize,
    const(char)* pSourceName, const(void)* pDefines, void* pInclude,
    const(char)* pEntrypoint, const(char)* pTarget,
    uint Flags1, uint Flags2,
    void** ppCode, void** ppErrorMsgs);

/* dcomp */
uint DCompositionCreateDevice(void* dxgiDevice, const(GUID)* iid, void** dcompDevice);

/* opengl32 */
int   ChoosePixelFormat(HDC, const(PIXELFORMATDESCRIPTOR)*);
int   SetPixelFormat(HDC, int, const(PIXELFORMATDESCRIPTOR)*);
HANDLE wglCreateContext(HDC);
int   wglDeleteContext(HANDLE);
int   wglMakeCurrent(HDC, HANDLE);
void* wglGetProcAddress(const(char)*);
void  glViewport(int, int, int, int);
void  glClearColor(float, float, float, float);
void  glClear(uint);
void  glDrawArrays(uint, int, int);
void  glFlush();

/* vulkan */
VkResult vkCreateInstance(const(VkInstanceCreateInfo)*, const(void)*, VkInstance*);
void vkDestroyInstance(VkInstance, const(void)*);
VkResult vkEnumeratePhysicalDevices(VkInstance, uint*, VkPhysicalDevice*);
void vkGetPhysicalDeviceQueueFamilyProperties(VkPhysicalDevice, uint*, VkQueueFamilyProperties*);
void vkGetPhysicalDeviceMemoryProperties(VkPhysicalDevice, VkPhysicalDeviceMemoryProperties*);
VkResult vkCreateDevice(VkPhysicalDevice, const(VkDeviceCreateInfo)*, const(void)*, VkDevice*);
void vkDestroyDevice(VkDevice, const(void)*);
void vkGetDeviceQueue(VkDevice, uint, uint, VkQueue*);
VkResult vkCreateImage(VkDevice, const(VkImageCreateInfo)*, const(void)*, VkImage*);
void vkDestroyImage(VkDevice, VkImage, const(void)*);
void vkGetImageMemoryRequirements(VkDevice, VkImage, VkMemoryRequirements*);
VkResult vkAllocateMemory(VkDevice, const(VkMemoryAllocateInfo)*, const(void)*, VkDeviceMemory*);
void vkFreeMemory(VkDevice, VkDeviceMemory, const(void)*);
VkResult vkBindImageMemory(VkDevice, VkImage, VkDeviceMemory, ulong);
VkResult vkCreateImageView(VkDevice, const(VkImageViewCreateInfo)*, const(void)*, VkImageView*);
void vkDestroyImageView(VkDevice, VkImageView, const(void)*);
VkResult vkCreateBuffer(VkDevice, const(VkBufferCreateInfo)*, const(void)*, VkBuffer*);
void vkDestroyBuffer(VkDevice, VkBuffer, const(void)*);
void vkGetBufferMemoryRequirements(VkDevice, VkBuffer, VkMemoryRequirements*);
VkResult vkBindBufferMemory(VkDevice, VkBuffer, VkDeviceMemory, ulong);
VkResult vkCreateRenderPass(VkDevice, const(VkRenderPassCreateInfo)*, const(void)*, VkRenderPass*);
void vkDestroyRenderPass(VkDevice, VkRenderPass, const(void)*);
VkResult vkCreateFramebuffer(VkDevice, const(VkFramebufferCreateInfo)*, const(void)*, VkFramebuffer_*);
void vkDestroyFramebuffer(VkDevice, VkFramebuffer_, const(void)*);
VkResult vkCreateShaderModule(VkDevice, const(VkShaderModuleCreateInfo)*, const(void)*, VkShaderModule*);
void vkDestroyShaderModule(VkDevice, VkShaderModule, const(void)*);
VkResult vkCreatePipelineLayout(VkDevice, const(VkPipelineLayoutCreateInfo)*, const(void)*, VkPipelineLayout*);
void vkDestroyPipelineLayout(VkDevice, VkPipelineLayout, const(void)*);
VkResult vkCreateGraphicsPipelines(VkDevice, ulong, uint, const(VkGraphicsPipelineCreateInfo)*, const(void)*, VkPipeline*);
void vkDestroyPipeline(VkDevice, VkPipeline, const(void)*);
VkResult vkCreateCommandPool(VkDevice, const(VkCommandPoolCreateInfo)*, const(void)*, VkCommandPool*);
void vkDestroyCommandPool(VkDevice, VkCommandPool, const(void)*);
VkResult vkAllocateCommandBuffers(VkDevice, const(VkCommandBufferAllocateInfo)*, VkCommandBuffer*);
VkResult vkBeginCommandBuffer(VkCommandBuffer, const(VkCommandBufferBeginInfo)*);
VkResult vkEndCommandBuffer(VkCommandBuffer);
void vkCmdBeginRenderPass(VkCommandBuffer, const(VkRenderPassBeginInfo)*, uint);
void vkCmdEndRenderPass(VkCommandBuffer);
void vkCmdBindPipeline(VkCommandBuffer, uint, VkPipeline);
void vkCmdDraw(VkCommandBuffer, uint, uint, uint, uint);
void vkCmdCopyImageToBuffer(VkCommandBuffer, VkImage, uint, VkBuffer, uint, const(VkBufferImageCopy)*);
VkResult vkCreateFence(VkDevice, const(VkFenceCreateInfo)*, const(void)*, VkFence*);
void vkDestroyFence(VkDevice, VkFence, const(void)*);
VkResult vkWaitForFences(VkDevice, uint, const(VkFence)*, uint, ulong);
VkResult vkResetFences(VkDevice, uint, const(VkFence)*);
VkResult vkResetCommandBuffer(VkCommandBuffer, uint);
VkResult vkQueueSubmit(VkQueue, uint, const(VkSubmitInfo)*, VkFence);
VkResult vkMapMemory(VkDevice, VkDeviceMemory, ulong, ulong, uint, void**);
void vkUnmapMemory(VkDevice, VkDeviceMemory);
VkResult vkDeviceWaitIdle(VkDevice);

/* ============================================================
 * Re-enter D calling convention
 * ============================================================ */
extern(D):

/* ============================================================
 * OpenGL function pointer types (loaded at runtime)
 * ============================================================ */
alias fn_glGenBuffers            = extern(Windows) void function(GLsizei, GLuint*);
alias fn_glBindBuffer            = extern(Windows) void function(GLenum, GLuint);
alias fn_glBufferData            = extern(Windows) void function(GLenum, GLsizeiptr, const(void)*, GLenum);
alias fn_glCreateShader          = extern(Windows) GLuint function(GLenum);
alias fn_glShaderSource          = extern(Windows) void function(GLuint, GLsizei, const(GLchar*)*, const(GLint)*);
alias fn_glCompileShader         = extern(Windows) void function(GLuint);
alias fn_glGetShaderiv           = extern(Windows) void function(GLuint, GLenum, GLint*);
alias fn_glGetShaderInfoLog      = extern(Windows) void function(GLuint, GLsizei, GLsizei*, GLchar*);
alias fn_glCreateProgram         = extern(Windows) GLuint function();
alias fn_glAttachShader          = extern(Windows) void function(GLuint, GLuint);
alias fn_glLinkProgram           = extern(Windows) void function(GLuint);
alias fn_glGetProgramiv          = extern(Windows) void function(GLuint, GLenum, GLint*);
alias fn_glGetProgramInfoLog     = extern(Windows) void function(GLuint, GLsizei, GLsizei*, GLchar*);
alias fn_glUseProgram            = extern(Windows) void function(GLuint);
alias fn_glGetAttribLocation     = extern(Windows) GLint function(GLuint, const(GLchar)*);
alias fn_glEnableVertexAttribArray = extern(Windows) void function(GLuint);
alias fn_glVertexAttribPointer   = extern(Windows) void function(GLuint, GLint, GLenum, GLboolean, GLsizei, const(void)*);
alias fn_glGenVertexArrays       = extern(Windows) void function(GLsizei, GLuint*);
alias fn_glBindVertexArray       = extern(Windows) void function(GLuint);
alias fn_glGenFramebuffers       = extern(Windows) void function(GLsizei, GLuint*);
alias fn_glBindFramebuffer       = extern(Windows) void function(GLenum, GLuint);
alias fn_glFramebufferRenderbuffer = extern(Windows) void function(GLenum, GLenum, GLenum, GLuint);
alias fn_glCheckFramebufferStatus = extern(Windows) GLenum function(GLenum);
alias fn_glGenRenderbuffers      = extern(Windows) void function(GLsizei, GLuint*);
alias fn_glBindRenderbuffer      = extern(Windows) void function(GLenum, GLuint);
alias fn_glDeleteBuffers         = extern(Windows) void function(GLsizei, const(GLuint)*);
alias fn_glDeleteVertexArrays    = extern(Windows) void function(GLsizei, const(GLuint)*);
alias fn_glDeleteFramebuffers    = extern(Windows) void function(GLsizei, const(GLuint)*);
alias fn_glDeleteRenderbuffers   = extern(Windows) void function(GLsizei, const(GLuint)*);
alias fn_glDeleteProgram         = extern(Windows) void function(GLuint);

alias fn_wglCreateContextAttribsARB = extern(Windows) HANDLE function(HDC, HANDLE, const(int)*);
alias fn_wglDXOpenDeviceNV       = extern(Windows) HANDLE function(void*);
alias fn_wglDXCloseDeviceNV      = extern(Windows) int function(HANDLE);
alias fn_wglDXRegisterObjectNV   = extern(Windows) HANDLE function(HANDLE, void*, GLuint, GLenum, GLenum);
alias fn_wglDXUnregisterObjectNV = extern(Windows) int function(HANDLE, HANDLE);
alias fn_wglDXLockObjectsNV      = extern(Windows) int function(HANDLE, GLint, HANDLE*);
alias fn_wglDXUnlockObjectsNV    = extern(Windows) int function(HANDLE, GLint, HANDLE*);

/* ============================================================
 * GL function pointer globals
 * ============================================================ */
__gshared fn_glGenBuffers            p_glGenBuffers;
__gshared fn_glBindBuffer            p_glBindBuffer;
__gshared fn_glBufferData            p_glBufferData;
__gshared fn_glCreateShader          p_glCreateShader;
__gshared fn_glShaderSource          p_glShaderSource;
__gshared fn_glCompileShader         p_glCompileShader;
__gshared fn_glGetShaderiv           p_glGetShaderiv;
__gshared fn_glGetShaderInfoLog      p_glGetShaderInfoLog;
__gshared fn_glCreateProgram         p_glCreateProgram;
__gshared fn_glAttachShader          p_glAttachShader;
__gshared fn_glLinkProgram           p_glLinkProgram;
__gshared fn_glGetProgramiv          p_glGetProgramiv;
__gshared fn_glGetProgramInfoLog     p_glGetProgramInfoLog;
__gshared fn_glUseProgram            p_glUseProgram;
__gshared fn_glGetAttribLocation     p_glGetAttribLocation;
__gshared fn_glEnableVertexAttribArray p_glEnableVertexAttribArray;
__gshared fn_glVertexAttribPointer   p_glVertexAttribPointer;
__gshared fn_glGenVertexArrays       p_glGenVertexArrays;
__gshared fn_glBindVertexArray       p_glBindVertexArray;
__gshared fn_glGenFramebuffers       p_glGenFramebuffers;
__gshared fn_glBindFramebuffer       p_glBindFramebuffer;
__gshared fn_glFramebufferRenderbuffer p_glFramebufferRenderbuffer;
__gshared fn_glCheckFramebufferStatus p_glCheckFramebufferStatus;
__gshared fn_glGenRenderbuffers      p_glGenRenderbuffers;
__gshared fn_glBindRenderbuffer      p_glBindRenderbuffer;
__gshared fn_glDeleteBuffers         p_glDeleteBuffers;
__gshared fn_glDeleteVertexArrays    p_glDeleteVertexArrays;
__gshared fn_glDeleteFramebuffers    p_glDeleteFramebuffers;
__gshared fn_glDeleteRenderbuffers   p_glDeleteRenderbuffers;
__gshared fn_glDeleteProgram         p_glDeleteProgram;

__gshared fn_wglCreateContextAttribsARB p_wglCreateContextAttribsARB;
__gshared fn_wglDXOpenDeviceNV       p_wglDXOpenDeviceNV;
__gshared fn_wglDXCloseDeviceNV      p_wglDXCloseDeviceNV;
__gshared fn_wglDXRegisterObjectNV   p_wglDXRegisterObjectNV;
__gshared fn_wglDXUnregisterObjectNV p_wglDXUnregisterObjectNV;
__gshared fn_wglDXLockObjectsNV      p_wglDXLockObjectsNV;
__gshared fn_wglDXUnlockObjectsNV    p_wglDXUnlockObjectsNV;

/* ============================================================
 * OpenGL shader sources
 * ============================================================ */
__gshared immutable char[] kVS_GLSL =
    "#version 460 core\n" ~
    "layout(location=0) in vec3 position;\n" ~
    "layout(location=1) in vec3 color;\n" ~
    "out vec4 vColor;\n" ~
    "void main(){ vColor=vec4(color,1.0); gl_Position=vec4(position.x,-position.y,position.z,1.0); }\n\0";

__gshared immutable char[] kPS_GLSL =
    "#version 460 core\n" ~
    "in vec4 vColor;\n" ~
    "out vec4 outColor;\n" ~
    "void main(){ outColor=vColor; }\n\0";

/* D3D11 HLSL shader sources */
__gshared immutable char[] kVS_HLSL =
    "struct VSInput { float3 pos:POSITION; float4 col:COLOR; };\n" ~
    "struct VSOutput{ float4 pos:SV_POSITION; float4 col:COLOR; };\n" ~
    "VSOutput main(VSInput i){ VSOutput o; o.pos=float4(i.pos,1); o.col=i.col; return o; }\n\0";

__gshared immutable char[] kPS_HLSL =
    "struct PSInput { float4 pos:SV_POSITION; float4 col:COLOR; };\n" ~
    "float4 main(PSInput i):SV_TARGET{ return i.col; }\n\0";

/* ============================================================
 * Global state
 * ============================================================ */
__gshared HWND  g_hwnd = null;
__gshared uint  g_width = 320;
__gshared uint  g_height = 480;
__gshared uint  g_windowWidth = 960;
__gshared int   g_comInitialized = FALSE;

/* DispatcherQueue controller */
__gshared void* g_dqController = null;

/* D3D11 objects (opaque pointers, called through vtable slots) */
__gshared void* g_d3dDevice   = null;
__gshared void* g_d3dCtx      = null;
__gshared void* g_swapChain   = null;  /* IDXGISwapChain1 - GL panel */
__gshared void* g_backBuffer  = null;  /* ID3D11Texture2D */
__gshared void* g_rtv         = null;  /* ID3D11RenderTargetView */
__gshared void* g_dxSwapChain = null;  /* IDXGISwapChain1 - D3D panel */
__gshared void* g_dxRtv       = null;
__gshared void* g_vkSwapChain = null;  /* IDXGISwapChain1 - Vulkan panel */
__gshared void* g_vkBackBuffer = null;
__gshared void* g_vkStagingTex = null;
__gshared void* g_vs           = null;
__gshared void* g_ps           = null;
__gshared void* g_inputLayout  = null;
__gshared void* g_vb           = null;

/* WGL / OpenGL objects */
__gshared HDC    g_hdc   = null;
__gshared HANDLE g_hglrc = null;
__gshared HANDLE g_glInteropDevice = null;
__gshared HANDLE g_glInteropObject = null;
__gshared GLuint[2] g_glVbo = [0, 0];
__gshared GLuint g_glVao = 0;
__gshared GLuint g_glProgram = 0;
__gshared GLuint g_glRbo = 0;
__gshared GLuint g_glFbo = 0;
__gshared GLint  g_glPosAttrib = -1;
__gshared GLint  g_glColAttrib = -1;

/* DirectComposition objects */
__gshared void* g_compositor         = null;
__gshared void* g_compositionTarget  = null;
__gshared void* g_rootVisual         = null;
__gshared void* g_visual             = null;  /* GL panel visual */
__gshared void* g_dxVisual           = null;  /* D3D panel visual */
__gshared void* g_vkVisual           = null;  /* Vulkan panel visual */

/* Unused composition surface pointers (kept for cleanup symmetry) */
__gshared void* g_compositionSurface   = null;
__gshared void* g_surfaceBrush         = null;
__gshared void* g_compositionBrush     = null;
__gshared void* g_spriteVisual         = null;
__gshared void* g_dxCompositionSurface = null;
__gshared void* g_dxSurfaceBrush      = null;
__gshared void* g_dxCompositionBrush   = null;
__gshared void* g_dxSpriteVisual      = null;
__gshared void* g_vkCompositionSurface = null;
__gshared void* g_vkSurfaceBrush      = null;
__gshared void* g_vkCompositionBrush   = null;
__gshared void* g_vkSpriteVisual      = null;
__gshared void* g_visualCollection     = null;
__gshared void* g_desktopTarget        = null;
__gshared void* g_desktopInterop       = null;
__gshared void* g_compInterop          = null;

/* Vulkan offscreen state */
__gshared VkInstance       g_vkInstance       = null;
__gshared VkPhysicalDevice g_vkPhysDev        = null;
__gshared VkDevice         g_vkDevice         = null;
__gshared uint             g_vkQueueFamily    = uint.max;
__gshared VkQueue          g_vkQueue          = null;
__gshared VkImage          g_vkOffImage       = 0;
__gshared VkDeviceMemory   g_vkOffMemory      = 0;
__gshared VkImageView      g_vkOffView        = 0;
__gshared VkBuffer         g_vkReadbackBuf    = 0;
__gshared VkDeviceMemory   g_vkReadbackMem    = 0;
__gshared VkRenderPass     g_vkRenderPass     = 0;
__gshared VkFramebuffer_   g_vkFramebuffer    = 0;
__gshared VkPipelineLayout g_vkPipelineLayout = 0;
__gshared VkPipeline       g_vkPipeline       = 0;
__gshared VkCommandPool    g_vkCmdPool        = 0;
__gshared VkCommandBuffer  g_vkCmdBuf         = null;
__gshared VkFence          g_vkFence          = 0;

/* ============================================================
 * Debug logging
 * ============================================================ */
void dbg(string msg) nothrow @nogc {
    /* Convert compile-time string to wchar* for OutputDebugStringW is complex,
       so use OutputDebugStringA with a char buffer */
    OutputDebugStringA(msg.ptr);
}

void dbgHr(const(char)* where, uint hr) nothrow {
    char[256] buf = void;
    int n = snprintf(buf.ptr, buf.length, "[ERR ] %s hr=0x%08X\n", where, hr);
    if (n > 0) OutputDebugStringA(buf.ptr);
}

void dbgVk(const(char)* where, int vr) nothrow {
    char[256] buf = void;
    int n = snprintf(buf.ptr, buf.length, "[ERR ] %s VkResult=%d (0x%08X)\n", where, vr, cast(uint)vr);
    if (n > 0) OutputDebugStringA(buf.ptr);
}

/* ============================================================
 * DirectComposition vtable wrappers
 *
 * IDCompositionDevice: IUnknown(3) + Commit(3), ..., CreateTargetForHwnd(6), CreateVisual(7)
 * IDCompositionTarget: IUnknown(3) + SetRoot(3)
 * IDCompositionVisual: IUnknown(3) + SetOffsetX(4), ..., SetOffsetY(6), ..., SetContent(15), AddVisual(16)
 * ============================================================ */
alias PFN_DCCommit            = extern(Windows) uint function(void*);
alias PFN_DCCreateTargetForHwnd = extern(Windows) uint function(void*, HWND, int, void**);
alias PFN_DCCreateVisual      = extern(Windows) uint function(void*, void**);
alias PFN_DCTargetSetRoot     = extern(Windows) uint function(void*, void*);
alias PFN_DCVisualSetOffsetX  = extern(Windows) uint function(void*, float);
alias PFN_DCVisualSetOffsetY  = extern(Windows) uint function(void*, float);
alias PFN_DCVisualSetContent  = extern(Windows) uint function(void*, void*);
alias PFN_DCVisualAddVisual   = extern(Windows) uint function(void*, void*, int, void*);

uint DCompDevice_Commit(void* dev)
{ return (cast(PFN_DCCommit)SLOT(dev, 3))(dev); }

uint DCompDevice_CreateTargetForHwnd(void* dev, HWND hwnd, int topmost, void** ppTarget)
{ return (cast(PFN_DCCreateTargetForHwnd)SLOT(dev, 6))(dev, hwnd, topmost, ppTarget); }

uint DCompDevice_CreateVisual(void* dev, void** ppVisual)
{ return (cast(PFN_DCCreateVisual)SLOT(dev, 7))(dev, ppVisual); }

uint DCompTarget_SetRoot(void* target, void* root)
{ return (cast(PFN_DCTargetSetRoot)SLOT(target, 3))(target, root); }

uint DCompVisual_SetOffsetX(void* vis, float x)
{ return (cast(PFN_DCVisualSetOffsetX)SLOT(vis, 4))(vis, x); }

uint DCompVisual_SetOffsetY(void* vis, float y)
{ return (cast(PFN_DCVisualSetOffsetY)SLOT(vis, 6))(vis, y); }

uint DCompVisual_SetContent(void* vis, void* content)
{ return (cast(PFN_DCVisualSetContent)SLOT(vis, 15))(vis, content); }

uint DCompVisual_AddVisual(void* parent, void* child, int insertAbove, void* refVisual)
{ return (cast(PFN_DCVisualAddVisual)SLOT(parent, 16))(parent, child, insertAbove, refVisual); }

/* ============================================================
 * D3D11 Device vtable helpers
 *
 * ID3D11Device vtable layout (IUnknown=3):
 *   3: CreateBuffer
 *   4: CreateTexture1D
 *   5: CreateTexture2D
 *   ...
 *   9: CreateRenderTargetView
 *   ...
 *  12: CreateVertexShader
 *  15: CreatePixelShader (slot 15)
 *  ...
 *  17: CreateInputLayout
 * ============================================================ */
alias PFN_D3DCreateBuffer = extern(Windows) uint function(void*, const(D3D11_BUFFER_DESC)*, const(D3D11_SUBRESOURCE_DATA)*, void**);
alias PFN_D3DCreateTexture2D = extern(Windows) uint function(void*, const(D3D11_TEXTURE2D_DESC)*, const(void)*, void**);
alias PFN_D3DCreateRTV = extern(Windows) uint function(void*, void*, const(void)*, void**);
alias PFN_D3DCreateVS = extern(Windows) uint function(void*, const(void)*, size_t, void*, void**);
alias PFN_D3DCreatePS = extern(Windows) uint function(void*, const(void)*, size_t, void*, void**);
alias PFN_D3DCreateInputLayout = extern(Windows) uint function(void*, const(D3D11_INPUT_ELEMENT_DESC)*, uint, const(void)*, size_t, void**);
alias PFN_D3DDeviceQI = extern(Windows) uint function(void*, const(GUID)*, void**);

uint D3DDev_QI(void* dev, const(GUID)* iid, void** ppOut)
{ return (cast(PFN_D3DDeviceQI)SLOT(dev, 0))(dev, iid, ppOut); }

uint D3DDev_CreateBuffer(void* dev, const(D3D11_BUFFER_DESC)* desc, const(D3D11_SUBRESOURCE_DATA)* init, void** ppBuf)
{ return (cast(PFN_D3DCreateBuffer)SLOT(dev, 3))(dev, desc, init, ppBuf); }

uint D3DDev_CreateTexture2D(void* dev, const(D3D11_TEXTURE2D_DESC)* desc, const(void)* init, void** ppTex)
{ return (cast(PFN_D3DCreateTexture2D)SLOT(dev, 5))(dev, desc, init, ppTex); }

uint D3DDev_CreateRenderTargetView(void* dev, void* res, const(void)* desc, void** ppRtv)
{ return (cast(PFN_D3DCreateRTV)SLOT(dev, 9))(dev, res, desc, ppRtv); }

uint D3DDev_CreateVertexShader(void* dev, const(void)* code, size_t len, void* classLink, void** ppVS)
{ return (cast(PFN_D3DCreateVS)SLOT(dev, 12))(dev, code, len, classLink, ppVS); }

/* ID3D11Device::CreatePixelShader is at slot 15 */
uint D3DDev_CreatePixelShader(void* dev, const(void)* code, size_t len, void* classLink, void** ppPS)
{ return (cast(PFN_D3DCreatePS)SLOT(dev, 15))(dev, code, len, classLink, ppPS); }

/* ID3D11Device::CreateInputLayout is at slot 11.
   ID3D11Device::CreatePixelShader is at slot 15. */
/* Actual ordering summary:
   QI/AddRef/Release (0-2),
   CreateBuffer(3), CreateTexture1D(4), CreateTexture2D(5), CreateTexture3D(6),
   CreateShaderResourceView(7), CreateUnorderedAccessView(8), CreateRenderTargetView(9),
   CreateDepthStencilView(10), CreateInputLayout(11), CreateVertexShader(12),
   CreateGeometryShader(13), CreateGeometryShaderWithStreamOutput(14), CreatePixelShader(15). */
/* ID3D11Device: QI(0), AddRef(1), Release(2),
   CreateBuffer(3), CreateTexture1D(4), CreateTexture2D(5), CreateTexture3D(6),
   CreateShaderResourceView(7), CreateUnorderedAccessView(8), CreateRenderTargetView(9),
   CreateDepthStencilView(10), CreateInputLayout(11), CreateVertexShader(12),
   CreateGeometryShader(13), CreateGeometryShaderWithStreamOutput(14), CreatePixelShader(15) */

uint D3DDev_CreateInputLayout2(void* dev, const(D3D11_INPUT_ELEMENT_DESC)* descs, uint num,
                               const(void)* code, size_t len, void** ppIL)
{ return (cast(PFN_D3DCreateInputLayout)SLOT(dev, 11))(dev, descs, num, code, len, ppIL); }

/* Pixel shader is slot 15 */
uint D3DDev_CreatePixelShader2(void* dev, const(void)* code, size_t len, void* classLink, void** ppPS)
{ return (cast(PFN_D3DCreatePS)SLOT(dev, 15))(dev, code, len, classLink, ppPS); }

/* ============================================================
 * D3D11 DeviceContext vtable helpers
 *
 * ID3D11DeviceContext: IUnknown(3) + ID3D11DeviceChild(3) + ID3D11DeviceContext methods
 * The vtable is very large. Key methods:
 *   VSSetShader(11), PSSetShader(9), ...
 * Exact slots (from d3d11.h vtable ordering):
 *   ID3D11DeviceContext : ID3D11DeviceChild(7)
 *   7: VSSetConstantBuffers
 *   8: PSSetShaderResources
 *   9: PSSetShader
 *  10: PSSetSamplers
 *  11: VSSetShader
 *  12: DrawIndexed
 *  13: Draw
 *  14: Map
 *  15: Unmap
 *  16: PSSetConstantBuffers
 *  17: IASetInputLayout
 *  18: IASetVertexBuffers
 *  19: IASetIndexBuffer
 *  20: DrawIndexedInstanced
 *  21: DrawInstanced
 *  ...
 *  24: IASetPrimitiveTopology
 *  ...
 *  44: RSSetViewports
 *  ...
 *  33: OMSetRenderTargets
 *  ...
 *  50: ClearRenderTargetView
 *  ...
 *  47: CopyResource
 * ============================================================ */

/* Let me use the actual ID3D11DeviceContext vtable slot numbers from the Windows SDK:
   ID3D11DeviceContext inherits ID3D11DeviceChild which inherits IUnknown.
   IUnknown: QI(0), AddRef(1), Release(2)
   ID3D11DeviceChild: GetDevice(3), GetPrivateData(4), SetPrivateData(5), SetPrivateDataInterface(6)
   ID3D11DeviceContext starts at slot 7:
     7:  VSSetConstantBuffers
     8:  PSSetShaderResources
     9:  PSSetShader
    10:  PSSetSamplers
    11:  VSSetShader
    12:  DrawIndexed
    13:  Draw
    14:  Map
    15:  Unmap
    16:  PSSetConstantBuffers
    17:  IASetInputLayout
    18:  IASetVertexBuffers
    19:  IASetIndexBuffer
    20:  DrawIndexedInstanced
    21:  DrawInstanced
    22:  GSSetConstantBuffers
    23:  GSSetShader
    24:  IASetPrimitiveTopology
    25:  VSSetShaderResources
    26:  VSSetSamplers
    27-32: ...
    33:  OMSetRenderTargets
    ...
    44:  RSSetViewports
    ...
    47:  CopyResource
    ...
    50:  ClearRenderTargetView
*/

alias PFN_Ctx_Draw = extern(Windows) void function(void*, uint, uint);
alias PFN_Ctx_Map  = extern(Windows) uint function(void*, void*, uint, uint, uint, D3D11_MAPPED_SUBRESOURCE*);
alias PFN_Ctx_Unmap = extern(Windows) void function(void*, void*, uint);
alias PFN_Ctx_IASetInputLayout = extern(Windows) void function(void*, void*);
alias PFN_Ctx_IASetVertexBuffers = extern(Windows) void function(void*, uint, uint, void**, const(uint)*, const(uint)*);
alias PFN_Ctx_IASetPrimitiveTopology = extern(Windows) void function(void*, uint);
alias PFN_Ctx_VSSetShader = extern(Windows) void function(void*, void*, void*, uint);
alias PFN_Ctx_PSSetShader = extern(Windows) void function(void*, void*, void*, uint);
alias PFN_Ctx_OMSetRenderTargets = extern(Windows) void function(void*, uint, void**, void*);
alias PFN_Ctx_RSSetViewports = extern(Windows) void function(void*, uint, const(D3D11_VIEWPORT)*);
alias PFN_Ctx_CopyResource = extern(Windows) void function(void*, void*, void*);
alias PFN_Ctx_ClearRTV = extern(Windows) void function(void*, void*, const(float)*);

void Ctx_VSSetShader(void* ctx, void* shader)
{ (cast(PFN_Ctx_VSSetShader)SLOT(ctx, 11))(ctx, shader, null, 0); }

void Ctx_PSSetShader(void* ctx, void* shader)
{ (cast(PFN_Ctx_PSSetShader)SLOT(ctx, 9))(ctx, shader, null, 0); }

void Ctx_Draw(void* ctx, uint vertexCount, uint startVertex)
{ (cast(PFN_Ctx_Draw)SLOT(ctx, 13))(ctx, vertexCount, startVertex); }

uint Ctx_Map(void* ctx, void* res, uint sub, uint mapType, uint flags, D3D11_MAPPED_SUBRESOURCE* mapped)
{ return (cast(PFN_Ctx_Map)SLOT(ctx, 14))(ctx, res, sub, mapType, flags, mapped); }

void Ctx_Unmap(void* ctx, void* res, uint sub)
{ (cast(PFN_Ctx_Unmap)SLOT(ctx, 15))(ctx, res, sub); }

void Ctx_IASetInputLayout(void* ctx, void* layout)
{ (cast(PFN_Ctx_IASetInputLayout)SLOT(ctx, 17))(ctx, layout); }

void Ctx_IASetVertexBuffers(void* ctx, uint slot, uint numBuf, void** ppBuf, const(uint)* strides, const(uint)* offsets)
{ (cast(PFN_Ctx_IASetVertexBuffers)SLOT(ctx, 18))(ctx, slot, numBuf, ppBuf, strides, offsets); }

void Ctx_IASetPrimitiveTopology(void* ctx, uint topo)
{ (cast(PFN_Ctx_IASetPrimitiveTopology)SLOT(ctx, 24))(ctx, topo); }

void Ctx_OMSetRenderTargets(void* ctx, uint numViews, void** ppRtvs, void* dsv)
{ (cast(PFN_Ctx_OMSetRenderTargets)SLOT(ctx, 33))(ctx, numViews, ppRtvs, dsv); }

void Ctx_RSSetViewports(void* ctx, uint num, const(D3D11_VIEWPORT)* vps)
{ (cast(PFN_Ctx_RSSetViewports)SLOT(ctx, 44))(ctx, num, vps); }

void Ctx_CopyResource(void* ctx, void* dst, void* src)
{ (cast(PFN_Ctx_CopyResource)SLOT(ctx, 47))(ctx, dst, src); }

void Ctx_ClearRenderTargetView(void* ctx, void* rtv, const(float)* color)
{ (cast(PFN_Ctx_ClearRTV)SLOT(ctx, 50))(ctx, rtv, color); }

/* ============================================================
 * IDXGISwapChain1 vtable helpers
 * IUnknown(3) + IDXGIObject(4) + IDXGIDeviceSubObject(1) + IDXGISwapChain methods
 *   Present = slot 8, GetBuffer = slot 9
 * ============================================================ */
alias PFN_SC_Present   = extern(Windows) uint function(void*, uint, uint);
alias PFN_SC_GetBuffer = extern(Windows) uint function(void*, uint, const(GUID)*, void**);

uint SC_Present(void* sc, uint syncInterval, uint flags)
{ return (cast(PFN_SC_Present)SLOT(sc, 8))(sc, syncInterval, flags); }

uint SC_GetBuffer(void* sc, uint buf, const(GUID)* iid, void** ppSurface)
{ return (cast(PFN_SC_GetBuffer)SLOT(sc, 9))(sc, buf, iid, ppSurface); }

/* ============================================================
 * IDXGIDevice::GetAdapter - slot 7 (QI=0,AddRef=1,Release=2,SetPrivateData=3,SetPrivateDataInterface=4,GetPrivateData=5,GetParent=6,GetAdapter=7)
 * Actually IDXGIDevice: IUnknown(3) + IDXGIObject(4) + GetAdapter(7), CreateSurface(8), ...
 * ============================================================ */

/* IDXGIAdapter::GetParent - slot 6 (IUnknown(3) + IDXGIObject: SetPrivateData(3), SetPrivateDataInterface(4), GetPrivateData(5), GetParent(6)) */

/* IDXGIFactory2::CreateSwapChainForComposition
   IDXGIFactory2 inherits IDXGIFactory1 inherits IDXGIFactory inherits IDXGIObject inherits IUnknown
   IUnknown(3) + IDXGIObject(4) + IDXGIFactory: EnumAdapters(7), MakeWindowAssociation(8), GetWindowAssociation(9), CreateSwapChain(10), CreateSoftwareAdapter(11)
   IDXGIFactory1: EnumAdapters1(12), IsCurrent(13)
   IDXGIFactory2: IsWindowedStereoEnabled(14), CreateSwapChainForHwnd(15), CreateSwapChainForCoreWindow(16), GetSharedResourceAdapterLuid(17), RegisterStereoStatusWindow(18), RegisterStereoStatusEvent(19), UnregisterStereoStatus(20), RegisterOcclusionStatusWindow(21), RegisterOcclusionStatusEvent(22), UnregisterOcclusionStatus(23), CreateSwapChainForComposition(24)
*/
alias PFN_DXGIFactory2_CreateSCForComp = extern(Windows) uint function(void*, void*, const(DXGI_SWAP_CHAIN_DESC1)*, void*, void**);

uint DXGIFactory2_CreateSwapChainForComposition(void* factory, void* device, const(DXGI_SWAP_CHAIN_DESC1)* desc, void** ppSC)
{ return (cast(PFN_DXGIFactory2_CreateSCForComp)SLOT(factory, 24))(factory, device, desc, null, ppSC); }

alias PFN_DXGIDevice_GetAdapter = extern(Windows) uint function(void*, void**);
alias PFN_DXGIAdapter_GetParent = extern(Windows) uint function(void*, const(GUID)*, void**);

/* ============================================================
 * ID3DBlob vtable helpers
 * IUnknown(3) + GetBufferPointer(3), GetBufferSize(4)
 * ============================================================ */
alias PFN_BlobGetPtr  = extern(Windows) void* function(void*);
alias PFN_BlobGetSize = extern(Windows) size_t function(void*);

void* Blob_GetBufferPointer(void* blob)
{ return (cast(PFN_BlobGetPtr)SLOT(blob, 3))(blob); }

size_t Blob_GetBufferSize(void* blob)
{ return (cast(PFN_BlobGetSize)SLOT(blob, 4))(blob); }

/* ============================================================
 * OpenGL proc loading
 * ============================================================ */
void* GetGLProc(const(char)* name) {
    void* p = wglGetProcAddress(name);
    if (!p || p == cast(void*)1 || p == cast(void*)2 || p == cast(void*)3 || p == cast(void*)-1) {
        auto h = GetModuleHandleA("opengl32.dll");
        if (h) p = GetProcAddress(h, name);
    }
    return p;
}

bool LoadGLProc(T)(ref T dst, const(char)* name) {
    dst = cast(T)GetGLProc(name);
    return dst !is null;
}

/* ============================================================
 * WGL context creation
 * ============================================================ */
HANDLE EnableOpenGL(HDC hdc) {
    PIXELFORMATDESCRIPTOR pfd;
    memset(&pfd, 0, pfd.sizeof);
    pfd.nSize = cast(ushort)pfd.sizeof;
    pfd.nVersion = 1;
    pfd.dwFlags = PFD_DRAW_TO_WINDOW | PFD_SUPPORT_OPENGL | PFD_DOUBLEBUFFER;
    pfd.iPixelType = PFD_TYPE_RGBA;
    pfd.cColorBits = 32;
    pfd.cDepthBits = 24;
    pfd.iLayerType = PFD_MAIN_PLANE;

    int pf = ChoosePixelFormat(hdc, &pfd);
    if (pf == 0) return null;
    if (!SetPixelFormat(hdc, pf, &pfd)) {
        /* Ignore ERROR_INVALID_PIXEL_FORMAT if already set */
    }

    auto oldRc = wglCreateContext(hdc);
    if (!oldRc) return null;
    if (!wglMakeCurrent(hdc, oldRc)) {
        wglDeleteContext(oldRc);
        return null;
    }

    p_wglCreateContextAttribsARB = cast(fn_wglCreateContextAttribsARB)GetGLProc("wglCreateContextAttribsARB");
    if (!p_wglCreateContextAttribsARB)
        return oldRc;

    int[9] attrs = [
        WGL_CONTEXT_MAJOR_VERSION_ARB, 4,
        WGL_CONTEXT_MINOR_VERSION_ARB, 6,
        WGL_CONTEXT_FLAGS_ARB, 0,
        WGL_CONTEXT_PROFILE_MASK_ARB, WGL_CONTEXT_CORE_PROFILE_BIT_ARB,
        0
    ];

    auto rc = p_wglCreateContextAttribsARB(hdc, null, attrs.ptr);
    if (!rc) return oldRc;

    wglMakeCurrent(hdc, rc);
    wglDeleteContext(oldRc);
    return rc;
}

void DisableOpenGL() {
    if (g_hglrc) {
        wglMakeCurrent(null, null);
        wglDeleteContext(g_hglrc);
        g_hglrc = null;
    }
    if (g_hdc && g_hwnd) {
        ReleaseDC(g_hwnd, g_hdc);
        g_hdc = null;
    }
}

/* ============================================================
 * GL shader compilation helpers
 * ============================================================ */
uint CheckGLShader(GLuint shader) {
    GLint ok = 0;
    p_glGetShaderiv(shader, GL_COMPILE_STATUS, &ok);
    if (ok) return S_OK;
    if (p_glGetShaderInfoLog) {
        GLchar[1024] logbuf;
        GLsizei loglen = 0;
        p_glGetShaderInfoLog(shader, 1023, &loglen, logbuf.ptr);
        if (loglen > 0) OutputDebugStringA(logbuf.ptr);
    }
    return E_FAIL;
}

uint CheckGLProgram(GLuint prog) {
    GLint ok = 0;
    p_glGetProgramiv(prog, GL_LINK_STATUS, &ok);
    if (ok) return S_OK;
    if (p_glGetProgramInfoLog) {
        GLchar[1024] logbuf;
        GLsizei loglen = 0;
        p_glGetProgramInfoLog(prog, 1023, &loglen, logbuf.ptr);
        if (loglen > 0) OutputDebugStringA(logbuf.ptr);
    }
    return E_FAIL;
}

/* ============================================================
 * D3D11 HLSL compilation helper
 * ============================================================ */
uint CompileShader(const(char)* src, const(char)* entry, const(char)* target, void** ppBlob) {
    void* pErr = null;
    uint hr = D3DCompile(src, strlen(src), null, null, null, entry, target,
                          D3DCOMPILE_ENABLE_STRICTNESS, 0, ppBlob, &pErr);
    if (FAILED(hr)) {
        if (pErr) {
            OutputDebugStringA(cast(const(char)*)Blob_GetBufferPointer(pErr));
            Rel(pErr);
        }
        return hr;
    }
    if (pErr) Rel(pErr);
    return S_OK;
}

/* ============================================================
 * File reading for SPIR-V
 * ============================================================ */
FILEDATA ReadBinaryFile(const(char)* path) {
    FILEDATA out_;
    out_.data = null;
    out_.size = 0;
    FILE* fp = fopen(path, "rb");
    if (!fp) return out_;
    if (fseek(fp, 0, SEEK_END) != 0) { fclose(fp); return out_; }
    long sz = ftell(fp);
    if (sz <= 0) { fclose(fp); return out_; }
    if (fseek(fp, 0, SEEK_SET) != 0) { fclose(fp); return out_; }
    out_.data = cast(ubyte*)malloc(cast(size_t)sz);
    if (!out_.data) { fclose(fp); return out_; }
    if (fread(out_.data, 1, cast(size_t)sz, fp) != cast(size_t)sz) {
        free(out_.data);
        out_.data = null;
        out_.size = 0;
    } else {
        out_.size = cast(size_t)sz;
    }
    fclose(fp);
    return out_;
}

void FreeFileData(FILEDATA* f) {
    if (f && f.data) { free(f.data); f.data = null; f.size = 0; }
}

/* ============================================================
 * Vulkan memory type helper
 * ============================================================ */
uint VkFindMemoryType(uint typeBits, uint props) {
    VkPhysicalDeviceMemoryProperties mp;
    vkGetPhysicalDeviceMemoryProperties(g_vkPhysDev, &mp);
    for (uint i = 0; i < mp.memoryTypeCount; ++i) {
        if ((typeBits & (1u << i)) && (mp.memoryTypes[i].propertyFlags & props) == props)
            return i;
    }
    return uint.max;
}

/* ============================================================
 * Create DXGI swap chain for composition on the shared D3D11 device
 * ============================================================ */
uint CreateSwapChainForCompositionOnSharedDevice(void** ppSwapChain) {
    void* dxgiDevice = null;
    void* adapter = null;
    void* factory = null;
    uint hr;

    if (!ppSwapChain) return E_INVALIDARG;
    *ppSwapChain = null;

    hr = D3DDev_QI(g_d3dDevice, &IID_IDXGIDevice, &dxgiDevice);
    if (FAILED(hr)) return hr;

    hr = (cast(PFN_DXGIDevice_GetAdapter)SLOT(dxgiDevice, 7))(dxgiDevice, &adapter);
    Rel(dxgiDevice);
    if (FAILED(hr)) return hr;

    hr = (cast(PFN_DXGIAdapter_GetParent)SLOT(adapter, 6))(adapter, &IID_IDXGIFactory2, &factory);
    Rel(adapter);
    if (FAILED(hr)) return hr;

    DXGI_SWAP_CHAIN_DESC1 desc;
    memset(&desc, 0, desc.sizeof);
    desc.Width = g_width;
    desc.Height = g_height;
    desc.Format = DXGI_FORMAT.DXGI_FORMAT_B8G8R8A8_UNORM;
    desc.SampleDesc.Count = 1;
    desc.BufferUsage = DXGI_USAGE_RENDER_TARGET_OUTPUT;
    desc.BufferCount = 2;
    desc.Scaling = DXGI_SCALING.DXGI_SCALING_STRETCH;
    desc.SwapEffect = DXGI_SWAP_EFFECT.DXGI_SWAP_EFFECT_FLIP_SEQUENTIAL;
    desc.AlphaMode = DXGI_ALPHA_MODE.DXGI_ALPHA_MODE_PREMULTIPLIED;

    hr = DXGIFactory2_CreateSwapChainForComposition(factory, g_d3dDevice, &desc, ppSwapChain);
    Rel(factory);
    return hr;
}

/* ============================================================
 * Create render target view from swapchain
 * ============================================================ */
uint CreateRenderTargetForSwapChain(void* sc, void** ppRtv) {
    void* bb = null;
    uint hr;
    if (!sc || !ppRtv) return E_INVALIDARG;
    if (*ppRtv) { Rel(*ppRtv); *ppRtv = null; }
    hr = SC_GetBuffer(sc, 0, &IID_ID3D11Texture2D, &bb);
    if (FAILED(hr)) return hr;
    hr = D3DDev_CreateRenderTargetView(g_d3dDevice, bb, null, ppRtv);
    Rel(bb);
    return hr;
}

/* ============================================================
 * Create main render target (for GL panel swapchain)
 * ============================================================ */
uint CreateRenderTarget() {
    void* pBackBuffer = null;
    uint hr;

    if (g_rtv)        { Rel(g_rtv);        g_rtv = null; }
    if (g_backBuffer) { Rel(g_backBuffer); g_backBuffer = null; }

    hr = SC_GetBuffer(g_swapChain, 0, &IID_ID3D11Texture2D, &pBackBuffer);
    if (FAILED(hr)) return hr;

    hr = D3DDev_CreateRenderTargetView(g_d3dDevice, pBackBuffer, null, &g_rtv);
    if (FAILED(hr)) { Rel(pBackBuffer); return hr; }

    /* Keep back buffer alive for WGL_NV_DX_interop */
    g_backBuffer = pBackBuffer;
    return S_OK;
}

/* ============================================================
 * Add a DComp visual for a swap chain at a given X offset
 * ============================================================ */
uint AddSpriteForSwapChain(void* sc, float offsetX,
    void** ppSurface, void** ppSurfaceBrush, void** ppCompBrush,
    void** ppSpriteVisual, void** ppVisual)
{
    uint hr;
    void* dcompVisual = null;

    if (!sc || !ppSurface || !ppSurfaceBrush || !ppCompBrush || !ppSpriteVisual || !ppVisual)
        return E_INVALIDARG;

    *ppSurface = null; *ppSurfaceBrush = null; *ppCompBrush = null;
    *ppSpriteVisual = null; *ppVisual = null;

    if (!g_compositor || !g_rootVisual) return E_FAIL;

    hr = DCompDevice_CreateVisual(g_compositor, &dcompVisual);
    if (FAILED(hr)) return hr;

    hr = DCompVisual_SetOffsetX(dcompVisual, offsetX);
    if (FAILED(hr)) { Rel(dcompVisual); return hr; }
    hr = DCompVisual_SetOffsetY(dcompVisual, 0.0f);
    if (FAILED(hr)) { Rel(dcompVisual); return hr; }
    hr = DCompVisual_SetContent(dcompVisual, sc);
    if (FAILED(hr)) { Rel(dcompVisual); return hr; }
    hr = DCompVisual_AddVisual(g_rootVisual, dcompVisual, TRUE, null);
    if (FAILED(hr)) { Rel(dcompVisual); return hr; }

    *ppVisual = dcompVisual;
    return S_OK;
}

/* ============================================================
 * Initialize D3D11 + SwapChain for Composition
 * ============================================================ */
uint InitD3D11AndSwapChainForComposition() {
    uint hr;
    uint deviceFlags = D3D11_CREATE_DEVICE_BGRA_SUPPORT;
    uint[1] fls = [D3D_FEATURE_LEVEL.D3D_FEATURE_LEVEL_11_0];
    uint flOut = 0;

    VERTEX[3] verts = [
        VERTEX( 0.0f,  0.5f, 0.5f,  1.0f, 0.0f, 0.0f, 1.0f),
        VERTEX( 0.5f, -0.5f, 0.5f,  0.0f, 1.0f, 0.0f, 1.0f),
        VERTEX(-0.5f, -0.5f, 0.5f,  0.0f, 0.0f, 1.0f, 1.0f),
    ];

    /* Create D3D11 device */
    hr = D3D11CreateDevice(null, D3D_DRIVER_TYPE.D3D_DRIVER_TYPE_HARDWARE, null,
        deviceFlags, fls.ptr, 1, D3D11_SDK_VERSION,
        &g_d3dDevice, &flOut, &g_d3dCtx);
    if (FAILED(hr)) return hr;

    dbg("[STEP] D3D11 device created\n\0");

    /* Get DXGI factory */
    void* dxgiDevice = null;
    hr = D3DDev_QI(g_d3dDevice, &IID_IDXGIDevice, &dxgiDevice);
    if (FAILED(hr)) { dbgHr("InitD3D11: QI(IDXGIDevice)", hr); return hr; }
    dbg("[STEP] InitD3D11: IDXGIDevice acquired\n\0");

    void* adapter = null;
    hr = (cast(PFN_DXGIDevice_GetAdapter)SLOT(dxgiDevice, 7))(dxgiDevice, &adapter);
    Rel(dxgiDevice);
    if (FAILED(hr)) { dbgHr("InitD3D11: IDXGIDevice::GetAdapter", hr); return hr; }
    dbg("[STEP] InitD3D11: DXGI adapter acquired\n\0");

    void* factory = null;
    hr = (cast(PFN_DXGIAdapter_GetParent)SLOT(adapter, 6))(adapter, &IID_IDXGIFactory2, &factory);
    Rel(adapter);
    if (FAILED(hr)) { dbgHr("InitD3D11: IDXGIAdapter::GetParent(IDXGIFactory2)", hr); return hr; }
    dbg("[STEP] InitD3D11: DXGI factory acquired\n\0");

    /* Create swap chain for composition */
    DXGI_SWAP_CHAIN_DESC1 desc;
    memset(&desc, 0, desc.sizeof);
    desc.Width = g_width;
    desc.Height = g_height;
    desc.Format = DXGI_FORMAT.DXGI_FORMAT_B8G8R8A8_UNORM;
    desc.SampleDesc.Count = 1;
    desc.BufferUsage = DXGI_USAGE_RENDER_TARGET_OUTPUT;
    desc.BufferCount = 2;
    desc.Scaling = DXGI_SCALING.DXGI_SCALING_STRETCH;
    desc.SwapEffect = DXGI_SWAP_EFFECT.DXGI_SWAP_EFFECT_FLIP_SEQUENTIAL;
    desc.AlphaMode = DXGI_ALPHA_MODE.DXGI_ALPHA_MODE_PREMULTIPLIED;

    hr = DXGIFactory2_CreateSwapChainForComposition(factory, g_d3dDevice, &desc, &g_swapChain);
    Rel(factory);
    if (FAILED(hr)) { dbgHr("InitD3D11: CreateSwapChainForComposition", hr); return hr; }
    dbg("[STEP] InitD3D11: swap chain created\n\0");

    /* Render target */
    hr = CreateRenderTarget();
    if (FAILED(hr)) { dbgHr("InitD3D11: CreateRenderTarget", hr); return hr; }
    dbg("[STEP] InitD3D11: render target created\n\0");

    /* Compile and create vertex shader */
    void* vsBlob = null;
    hr = CompileShader(kVS_HLSL.ptr, "main", "vs_4_0", &vsBlob);
    if (FAILED(hr)) { dbgHr("InitD3D11: CompileShader(VS)", hr); return hr; }
    dbg("[STEP] InitD3D11: vertex shader compiled\n\0");

    hr = D3DDev_CreateVertexShader(g_d3dDevice,
        Blob_GetBufferPointer(vsBlob), Blob_GetBufferSize(vsBlob), null, &g_vs);
    if (FAILED(hr)) { dbgHr("InitD3D11: CreateVertexShader", hr); Rel(vsBlob); return hr; }
    dbg("[STEP] InitD3D11: vertex shader created\n\0");

    /* Compile and create pixel shader */
    void* psBlob = null;
    hr = CompileShader(kPS_HLSL.ptr, "main", "ps_4_0", &psBlob);
    if (FAILED(hr)) { dbgHr("InitD3D11: CompileShader(PS)", hr); Rel(vsBlob); return hr; }
    dbg("[STEP] InitD3D11: pixel shader compiled\n\0");

    hr = D3DDev_CreatePixelShader2(g_d3dDevice,
        Blob_GetBufferPointer(psBlob), Blob_GetBufferSize(psBlob), null, &g_ps);
    Rel(psBlob);
    if (FAILED(hr)) { dbgHr("InitD3D11: CreatePixelShader", hr); Rel(vsBlob); return hr; }
    dbg("[STEP] InitD3D11: pixel shader created\n\0");

    /* Input layout */
    D3D11_INPUT_ELEMENT_DESC[2] layoutDesc;

    layoutDesc[0].SemanticName = "POSITION";
    layoutDesc[0].SemanticIndex = 0;
    layoutDesc[0].Format = DXGI_FORMAT.DXGI_FORMAT_R32G32B32_FLOAT;
    layoutDesc[0].InputSlot = 0;
    layoutDesc[0].AlignedByteOffset = 0;
    layoutDesc[0].InputSlotClass = D3D11_INPUT_PER_VERTEX_DATA;
    layoutDesc[0].InstanceDataStepRate = 0;

    layoutDesc[1].SemanticName = "COLOR";
    layoutDesc[1].SemanticIndex = 0;
    layoutDesc[1].Format = DXGI_FORMAT.DXGI_FORMAT_R32G32B32A32_FLOAT;
    layoutDesc[1].InputSlot = 0;
    layoutDesc[1].AlignedByteOffset = 12;
    layoutDesc[1].InputSlotClass = D3D11_INPUT_PER_VERTEX_DATA;
    layoutDesc[1].InstanceDataStepRate = 0;

    hr = D3DDev_CreateInputLayout2(g_d3dDevice, layoutDesc.ptr, 2,
        Blob_GetBufferPointer(vsBlob), Blob_GetBufferSize(vsBlob), &g_inputLayout);
    Rel(vsBlob);
    if (FAILED(hr)) { dbgHr("InitD3D11: CreateInputLayout", hr); return hr; }
    dbg("[STEP] InitD3D11: input layout created\n\0");

    /* Vertex buffer */
    D3D11_BUFFER_DESC bd;
    memset(&bd, 0, bd.sizeof);
    bd.Usage = D3D11_USAGE.D3D11_USAGE_DEFAULT;
    bd.ByteWidth = cast(uint)(verts.sizeof);
    bd.BindFlags = D3D11_BIND_FLAG.D3D11_BIND_VERTEX_BUFFER;

    D3D11_SUBRESOURCE_DATA initData;
    memset(&initData, 0, initData.sizeof);
    initData.pSysMem = verts.ptr;

    hr = D3DDev_CreateBuffer(g_d3dDevice, &bd, &initData, &g_vb);
    if (FAILED(hr)) { dbgHr("InitD3D11: CreateBuffer(VB)", hr); return hr; }

    dbg("[STEP] D3D11 init ok\n\0");
    return S_OK;
}

/* ============================================================
 * Initialize DirectComposition for HWND
 * ============================================================ */
uint InitCompositionForHwnd() {
    uint hr;

    hr = CoInitializeEx(null, COINIT_APARTMENTTHREADED);
    if (SUCCEEDED(hr)) {
        g_comInitialized = TRUE;
    } else if (hr != RPC_E_CHANGED_MODE) {
        return hr;
    }

    void* dxgiDevice = null;
    hr = D3DDev_QI(g_d3dDevice, &IID_IDXGIDevice, &dxgiDevice);
    if (FAILED(hr)) return hr;

    hr = DCompositionCreateDevice(dxgiDevice, &IID_IDCompositionDevice_C, &g_compositor);
    Rel(dxgiDevice);
    if (FAILED(hr)) return hr;

    dbg("[STEP] IDCompositionDevice created\n\0");

    hr = DCompDevice_CreateTargetForHwnd(g_compositor, g_hwnd, TRUE, &g_compositionTarget);
    if (FAILED(hr)) return hr;

    hr = DCompDevice_CreateVisual(g_compositor, &g_rootVisual);
    if (FAILED(hr)) return hr;

    hr = DCompTarget_SetRoot(g_compositionTarget, g_rootVisual);
    if (FAILED(hr)) return hr;

    /* Create visual for GL panel (left, offset 0) */
    void* glVisual = null;
    hr = DCompDevice_CreateVisual(g_compositor, &glVisual);
    if (FAILED(hr)) return hr;
    DCompVisual_SetOffsetX(glVisual, 0.0f);
    DCompVisual_SetOffsetY(glVisual, 0.0f);
    hr = DCompVisual_SetContent(glVisual, g_swapChain);
    if (FAILED(hr)) { Rel(glVisual); return hr; }
    hr = DCompVisual_AddVisual(g_rootVisual, glVisual, TRUE, null);
    if (FAILED(hr)) { Rel(glVisual); return hr; }

    g_visual = glVisual;
    dbg("[STEP] DirectComposition visual tree initialized\n\0");
    return S_OK;
}

/* ============================================================
 * Initialize OpenGL for composition (WGL_NV_DX_interop)
 * ============================================================ */
uint InitOpenGLForComposition() {
    uint hr = S_OK;

    if (!g_hwnd || !g_d3dDevice || !g_swapChain || !g_backBuffer) return E_FAIL;

    g_hdc = GetDC(g_hwnd);
    if (!g_hdc) return E_FAIL;

    g_hglrc = EnableOpenGL(g_hdc);
    if (!g_hglrc) return E_FAIL;
    if (!wglMakeCurrent(g_hdc, g_hglrc)) return E_FAIL;

    /* Load all GL extension functions */
    if (!LoadGLProc(p_glGenBuffers, "glGenBuffers")) return E_FAIL;
    if (!LoadGLProc(p_glBindBuffer, "glBindBuffer")) return E_FAIL;
    if (!LoadGLProc(p_glBufferData, "glBufferData")) return E_FAIL;
    if (!LoadGLProc(p_glCreateShader, "glCreateShader")) return E_FAIL;
    if (!LoadGLProc(p_glShaderSource, "glShaderSource")) return E_FAIL;
    if (!LoadGLProc(p_glCompileShader, "glCompileShader")) return E_FAIL;
    if (!LoadGLProc(p_glGetShaderiv, "glGetShaderiv")) return E_FAIL;
    if (!LoadGLProc(p_glGetShaderInfoLog, "glGetShaderInfoLog")) return E_FAIL;
    if (!LoadGLProc(p_glCreateProgram, "glCreateProgram")) return E_FAIL;
    if (!LoadGLProc(p_glAttachShader, "glAttachShader")) return E_FAIL;
    if (!LoadGLProc(p_glLinkProgram, "glLinkProgram")) return E_FAIL;
    if (!LoadGLProc(p_glGetProgramiv, "glGetProgramiv")) return E_FAIL;
    if (!LoadGLProc(p_glGetProgramInfoLog, "glGetProgramInfoLog")) return E_FAIL;
    if (!LoadGLProc(p_glUseProgram, "glUseProgram")) return E_FAIL;
    if (!LoadGLProc(p_glGetAttribLocation, "glGetAttribLocation")) return E_FAIL;
    if (!LoadGLProc(p_glEnableVertexAttribArray, "glEnableVertexAttribArray")) return E_FAIL;
    if (!LoadGLProc(p_glVertexAttribPointer, "glVertexAttribPointer")) return E_FAIL;
    if (!LoadGLProc(p_glGenVertexArrays, "glGenVertexArrays")) return E_FAIL;
    if (!LoadGLProc(p_glBindVertexArray, "glBindVertexArray")) return E_FAIL;
    if (!LoadGLProc(p_glGenFramebuffers, "glGenFramebuffers")) return E_FAIL;
    if (!LoadGLProc(p_glBindFramebuffer, "glBindFramebuffer")) return E_FAIL;
    if (!LoadGLProc(p_glFramebufferRenderbuffer, "glFramebufferRenderbuffer")) return E_FAIL;
    if (!LoadGLProc(p_glCheckFramebufferStatus, "glCheckFramebufferStatus")) return E_FAIL;
    if (!LoadGLProc(p_glGenRenderbuffers, "glGenRenderbuffers")) return E_FAIL;
    if (!LoadGLProc(p_glBindRenderbuffer, "glBindRenderbuffer")) return E_FAIL;

    p_glDeleteBuffers = cast(fn_glDeleteBuffers)GetGLProc("glDeleteBuffers");
    p_glDeleteVertexArrays = cast(fn_glDeleteVertexArrays)GetGLProc("glDeleteVertexArrays");
    p_glDeleteFramebuffers = cast(fn_glDeleteFramebuffers)GetGLProc("glDeleteFramebuffers");
    p_glDeleteRenderbuffers = cast(fn_glDeleteRenderbuffers)GetGLProc("glDeleteRenderbuffers");
    p_glDeleteProgram = cast(fn_glDeleteProgram)GetGLProc("glDeleteProgram");

    if (!LoadGLProc(p_wglDXOpenDeviceNV, "wglDXOpenDeviceNV")) return E_FAIL;
    if (!LoadGLProc(p_wglDXCloseDeviceNV, "wglDXCloseDeviceNV")) return E_FAIL;
    if (!LoadGLProc(p_wglDXRegisterObjectNV, "wglDXRegisterObjectNV")) return E_FAIL;
    if (!LoadGLProc(p_wglDXUnregisterObjectNV, "wglDXUnregisterObjectNV")) return E_FAIL;
    if (!LoadGLProc(p_wglDXLockObjectsNV, "wglDXLockObjectsNV")) return E_FAIL;
    if (!LoadGLProc(p_wglDXUnlockObjectsNV, "wglDXUnlockObjectsNV")) return E_FAIL;

    /* Open NV interop device */
    g_glInteropDevice = p_wglDXOpenDeviceNV(g_d3dDevice);
    if (!g_glInteropDevice) return E_FAIL;

    /* Create renderbuffer and register with DX interop */
    p_glGenRenderbuffers(1, &g_glRbo);
    p_glBindRenderbuffer(GL_RENDERBUFFER, g_glRbo);

    g_glInteropObject = p_wglDXRegisterObjectNV(
        g_glInteropDevice, g_backBuffer, g_glRbo, GL_RENDERBUFFER, WGL_ACCESS_READ_WRITE_NV);
    if (!g_glInteropObject) return E_FAIL;

    /* Create FBO */
    p_glGenFramebuffers(1, &g_glFbo);
    p_glBindFramebuffer(GL_FRAMEBUFFER, g_glFbo);
    p_glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, g_glRbo);
    GLenum fboStatus = p_glCheckFramebufferStatus(GL_FRAMEBUFFER);
    p_glBindFramebuffer(GL_FRAMEBUFFER, 0);
    if (fboStatus != GL_FRAMEBUFFER_COMPLETE) return E_FAIL;

    /* Create VAO and VBOs */
    p_glGenVertexArrays(1, &g_glVao);
    p_glBindVertexArray(g_glVao);

    GLfloat[9] glVerts = [
        -0.5f, -0.5f, 0.0f,
         0.5f, -0.5f, 0.0f,
         0.0f,  0.5f, 0.0f
    ];
    GLfloat[9] glCols = [
        0.0f, 0.0f, 1.0f,
        0.0f, 1.0f, 0.0f,
        1.0f, 0.0f, 0.0f
    ];

    p_glGenBuffers(2, g_glVbo.ptr);
    p_glBindBuffer(GL_ARRAY_BUFFER, g_glVbo[0]);
    p_glBufferData(GL_ARRAY_BUFFER, cast(GLsizeiptr)glVerts.sizeof, glVerts.ptr, GL_STATIC_DRAW);
    p_glBindBuffer(GL_ARRAY_BUFFER, g_glVbo[1]);
    p_glBufferData(GL_ARRAY_BUFFER, cast(GLsizeiptr)glCols.sizeof, glCols.ptr, GL_STATIC_DRAW);

    /* Compile shaders */
    const(GLchar)* vsSrc = kVS_GLSL.ptr;
    GLuint vs = p_glCreateShader(GL_VERTEX_SHADER);
    p_glShaderSource(vs, 1, &vsSrc, null);
    p_glCompileShader(vs);
    hr = CheckGLShader(vs);
    if (FAILED(hr)) return hr;

    const(GLchar)* psSrc = kPS_GLSL.ptr;
    GLuint ps = p_glCreateShader(GL_FRAGMENT_SHADER);
    p_glShaderSource(ps, 1, &psSrc, null);
    p_glCompileShader(ps);
    hr = CheckGLShader(ps);
    if (FAILED(hr)) return hr;

    g_glProgram = p_glCreateProgram();
    p_glAttachShader(g_glProgram, vs);
    p_glAttachShader(g_glProgram, ps);
    p_glLinkProgram(g_glProgram);
    hr = CheckGLProgram(g_glProgram);
    if (FAILED(hr)) return hr;

    p_glUseProgram(g_glProgram);
    g_glPosAttrib = p_glGetAttribLocation(g_glProgram, "position");
    g_glColAttrib = p_glGetAttribLocation(g_glProgram, "color");
    if (g_glPosAttrib < 0 || g_glColAttrib < 0) return E_FAIL;
    p_glEnableVertexAttribArray(cast(GLuint)g_glPosAttrib);
    p_glEnableVertexAttribArray(cast(GLuint)g_glColAttrib);

    dbg("[STEP] OpenGL init ok\n\0");
    return S_OK;
}

/* ============================================================
 * Initialize D3D11 second panel
 * ============================================================ */
uint InitD3D11SecondPanel() {
    uint hr;

    hr = CreateSwapChainForCompositionOnSharedDevice(&g_dxSwapChain);
    if (FAILED(hr)) return hr;

    hr = CreateRenderTargetForSwapChain(g_dxSwapChain, &g_dxRtv);
    if (FAILED(hr)) return hr;

    hr = AddSpriteForSwapChain(g_dxSwapChain, cast(float)g_width,
        &g_dxCompositionSurface, &g_dxSurfaceBrush, &g_dxCompositionBrush,
        &g_dxSpriteVisual, &g_dxVisual);
    if (FAILED(hr)) return hr;

    dbg("[STEP] D3D11 second panel ok\n\0");
    return S_OK;
}

/* ============================================================
 * Initialize Vulkan third panel
 * ============================================================ */
uint CreateVkPanelD3DResources() {
    uint hr;
    if (g_vkBackBuffer) { Rel(g_vkBackBuffer); g_vkBackBuffer = null; }
    if (g_vkStagingTex) { Rel(g_vkStagingTex); g_vkStagingTex = null; }

    hr = SC_GetBuffer(g_vkSwapChain, 0, &IID_ID3D11Texture2D, &g_vkBackBuffer);
    if (FAILED(hr)) return hr;

    D3D11_TEXTURE2D_DESC td;
    memset(&td, 0, td.sizeof);
    td.Width = g_width;
    td.Height = g_height;
    td.MipLevels = 1;
    td.ArraySize = 1;
    td.Format = DXGI_FORMAT.DXGI_FORMAT_B8G8R8A8_UNORM;
    td.SampleDesc.Count = 1;
    td.Usage = D3D11_USAGE.D3D11_USAGE_STAGING;
    td.CPUAccessFlags = D3D11_CPU_ACCESS_FLAG.D3D11_CPU_ACCESS_WRITE;
    hr = D3DDev_CreateTexture2D(g_d3dDevice, &td, null, &g_vkStagingTex);
    return hr;
}

uint InitVulkanThirdPanel() {
    uint hr;
    VkResult vr;

    hr = CreateSwapChainForCompositionOnSharedDevice(&g_vkSwapChain);
    if (FAILED(hr)) { dbgHr("InitVulkan: CreateSwapChainForCompositionOnSharedDevice", hr); return hr; }
    dbg("[STEP] InitVulkan: swap chain created\n\0");

    hr = AddSpriteForSwapChain(g_vkSwapChain, cast(float)(g_width * 2),
        &g_vkCompositionSurface, &g_vkSurfaceBrush, &g_vkCompositionBrush,
        &g_vkSpriteVisual, &g_vkVisual);
    if (FAILED(hr)) { dbgHr("InitVulkan: AddSpriteForSwapChain", hr); return hr; }
    dbg("[STEP] InitVulkan: DComp visual connected\n\0");

    hr = CreateVkPanelD3DResources();
    if (FAILED(hr)) { dbgHr("InitVulkan: CreateVkPanelD3DResources", hr); return hr; }
    dbg("[STEP] InitVulkan: D3D resources created\n\0");

    /* Create Vulkan instance */
    VkApplicationInfo ai;
    memset(&ai, 0, ai.sizeof);
    ai.sType = VK_STRUCTURE_TYPE_APPLICATION_INFO;
    ai.pApplicationName = "triangle_multi_vk_panel";
    ai.apiVersion = VK_MAKE_API_VERSION(0, 1, 4, 0);

    VkInstanceCreateInfo ici;
    memset(&ici, 0, ici.sizeof);
    ici.sType = VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO;
    ici.pApplicationInfo = &ai;
    vr = vkCreateInstance(&ici, null, &g_vkInstance);
    if (vr != VK_SUCCESS) { dbgVk("InitVulkan: vkCreateInstance", vr); return E_FAIL; }
    dbg("[STEP] InitVulkan: instance created\n\0");

    /* Enumerate physical devices */
    uint devCount = 0;
    vr = vkEnumeratePhysicalDevices(g_vkInstance, &devCount, null);
    if (vr != VK_SUCCESS) { dbgVk("InitVulkan: vkEnumeratePhysicalDevices(count)", vr); return E_FAIL; }
    if (devCount == 0) { dbg("[ERR ] InitVulkan: no physical devices\n\0"); return E_FAIL; }
    auto devs = cast(VkPhysicalDevice*)malloc(VkPhysicalDevice.sizeof * devCount);
    if (!devs) return E_OUTOFMEMORY;
    vr = vkEnumeratePhysicalDevices(g_vkInstance, &devCount, devs);
    if (vr != VK_SUCCESS) { free(devs); dbgVk("InitVulkan: vkEnumeratePhysicalDevices(list)", vr); return E_FAIL; }
    dbg("[STEP] InitVulkan: physical devices enumerated\n\0");

    for (uint i = 0; i < devCount && g_vkPhysDev is null; ++i) {
        uint qc = 0;
        vkGetPhysicalDeviceQueueFamilyProperties(devs[i], &qc, null);
        if (!qc) continue;
        auto qprops = cast(VkQueueFamilyProperties*)malloc(VkQueueFamilyProperties.sizeof * qc);
        if (!qprops) continue;
        vkGetPhysicalDeviceQueueFamilyProperties(devs[i], &qc, qprops);
        for (uint q = 0; q < qc; ++q) {
            if (qprops[q].queueFlags & VK_QUEUE_GRAPHICS_BIT) {
                g_vkPhysDev = devs[i];
                g_vkQueueFamily = q;
                break;
            }
        }
        free(qprops);
    }
    free(devs);
    if (g_vkPhysDev is null) { dbg("[ERR ] InitVulkan: no graphics queue family found\n\0"); return E_FAIL; }
    dbg("[STEP] InitVulkan: graphics queue family selected\n\0");

    /* Create logical device */
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
    vr = vkCreateDevice(g_vkPhysDev, &dci, null, &g_vkDevice);
    if (vr != VK_SUCCESS) { dbgVk("InitVulkan: vkCreateDevice", vr); return E_FAIL; }
    vkGetDeviceQueue(g_vkDevice, g_vkQueueFamily, 0, &g_vkQueue);
    dbg("[STEP] InitVulkan: device/queue created\n\0");

    /* Offscreen image */
    VkImageCreateInfo imgci;
    memset(&imgci, 0, imgci.sizeof);
    imgci.sType = VK_STRUCTURE_TYPE_IMAGE_CREATE_INFO;
    imgci.imageType = VK_IMAGE_TYPE_2D;
    imgci.format = VK_FORMAT_B8G8R8A8_UNORM;
    imgci.extent = VkExtent3D(g_width, g_height, 1);
    imgci.mipLevels = 1; imgci.arrayLayers = 1;
    imgci.samples = VK_SAMPLE_COUNT_1_BIT;
    imgci.tiling = VK_IMAGE_TILING_OPTIMAL;
    imgci.usage = VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT | VK_IMAGE_USAGE_TRANSFER_SRC_BIT;
    imgci.initialLayout = VK_IMAGE_LAYOUT_UNDEFINED;
    vr = vkCreateImage(g_vkDevice, &imgci, null, &g_vkOffImage);
    if (vr != VK_SUCCESS) { dbgVk("InitVulkan: vkCreateImage", vr); return E_FAIL; }

    VkMemoryRequirements mr;
    vkGetImageMemoryRequirements(g_vkDevice, g_vkOffImage, &mr);
    VkMemoryAllocateInfo mai;
    memset(&mai, 0, mai.sizeof);
    mai.sType = VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO;
    mai.allocationSize = mr.size;
    mai.memoryTypeIndex = VkFindMemoryType(mr.memoryTypeBits, VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT);
    if (mai.memoryTypeIndex == uint.max) { dbg("[ERR ] InitVulkan: no DEVICE_LOCAL memory type\n\0"); return E_FAIL; }
    vr = vkAllocateMemory(g_vkDevice, &mai, null, &g_vkOffMemory);
    if (vr != VK_SUCCESS) { dbgVk("InitVulkan: vkAllocateMemory(offscreen)", vr); return E_FAIL; }
    vkBindImageMemory(g_vkDevice, g_vkOffImage, g_vkOffMemory, 0);

    /* Image view */
    VkImageViewCreateInfo ivci;
    memset(&ivci, 0, ivci.sizeof);
    ivci.sType = VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO;
    ivci.image = g_vkOffImage;
    ivci.viewType = VK_IMAGE_VIEW_TYPE_2D;
    ivci.format = VK_FORMAT_B8G8R8A8_UNORM;
    ivci.subresourceRange.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT;
    ivci.subresourceRange.levelCount = 1;
    ivci.subresourceRange.layerCount = 1;
    vr = vkCreateImageView(g_vkDevice, &ivci, null, &g_vkOffView);
    if (vr != VK_SUCCESS) { dbgVk("InitVulkan: vkCreateImageView", vr); return E_FAIL; }

    /* Readback buffer */
    VkBufferCreateInfo bci;
    memset(&bci, 0, bci.sizeof);
    bci.sType = VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO;
    bci.size = cast(VkDeviceSize)g_width * g_height * 4;
    bci.usage = VK_BUFFER_USAGE_TRANSFER_DST_BIT;
    vr = vkCreateBuffer(g_vkDevice, &bci, null, &g_vkReadbackBuf);
    if (vr != VK_SUCCESS) { dbgVk("InitVulkan: vkCreateBuffer(readback)", vr); return E_FAIL; }
    vkGetBufferMemoryRequirements(g_vkDevice, g_vkReadbackBuf, &mr);
    memset(&mai, 0, mai.sizeof);
    mai.sType = VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO;
    mai.allocationSize = mr.size;
    mai.memoryTypeIndex = VkFindMemoryType(mr.memoryTypeBits,
        VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | VK_MEMORY_PROPERTY_HOST_COHERENT_BIT);
    if (mai.memoryTypeIndex == uint.max) { dbg("[ERR ] InitVulkan: no HOST_VISIBLE|HOST_COHERENT memory type\n\0"); return E_FAIL; }
    vr = vkAllocateMemory(g_vkDevice, &mai, null, &g_vkReadbackMem);
    if (vr != VK_SUCCESS) { dbgVk("InitVulkan: vkAllocateMemory(readback)", vr); return E_FAIL; }
    vkBindBufferMemory(g_vkDevice, g_vkReadbackBuf, g_vkReadbackMem, 0);
    dbg("[STEP] InitVulkan: offscreen/readback resources created\n\0");

    /* Render pass */
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
    vr = vkCreateRenderPass(g_vkDevice, &rpci, null, &g_vkRenderPass);
    if (vr != VK_SUCCESS) { dbgVk("InitVulkan: vkCreateRenderPass", vr); return E_FAIL; }

    /* Framebuffer */
    VkFramebufferCreateInfo fbci;
    memset(&fbci, 0, fbci.sizeof);
    fbci.sType = VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO;
    fbci.renderPass = g_vkRenderPass;
    fbci.attachmentCount = 1;
    fbci.pAttachments = &g_vkOffView;
    fbci.width = g_width; fbci.height = g_height; fbci.layers = 1;
    vr = vkCreateFramebuffer(g_vkDevice, &fbci, null, &g_vkFramebuffer);
    if (vr != VK_SUCCESS) { dbgVk("InitVulkan: vkCreateFramebuffer", vr); return E_FAIL; }
    dbg("[STEP] InitVulkan: render pass/framebuffer created\n\0");

    /* Load SPIR-V shaders */
    FILEDATA vsSpv = ReadBinaryFile("hello_vert.spv");
    FILEDATA fsSpv = ReadBinaryFile("hello_frag.spv");
    if (!vsSpv.data || !fsSpv.data) {
        dbg("[ERR ] InitVulkan: failed to read SPIR-V files (hello_vert.spv / hello_frag.spv)\n\0");
        return E_FAIL;
    }
    dbg("[STEP] InitVulkan: SPIR-V files loaded\n\0");

    VkShaderModuleCreateInfo smci;
    memset(&smci, 0, smci.sizeof);
    smci.sType = VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO;
    smci.codeSize = vsSpv.size;
    smci.pCode = cast(const(uint)*)vsSpv.data;
    VkShaderModule vsMod = 0;
    vr = vkCreateShaderModule(g_vkDevice, &smci, null, &vsMod);
    if (vr != VK_SUCCESS) { dbgVk("InitVulkan: vkCreateShaderModule(VS)", vr); return E_FAIL; }

    smci.codeSize = fsSpv.size;
    smci.pCode = cast(const(uint)*)fsSpv.data;
    VkShaderModule fsMod = 0;
    vr = vkCreateShaderModule(g_vkDevice, &smci, null, &fsMod);
    if (vr != VK_SUCCESS) { dbgVk("InitVulkan: vkCreateShaderModule(FS)", vr); return E_FAIL; }
    dbg("[STEP] InitVulkan: shader modules created\n\0");

    /* Pipeline stages */
    VkPipelineShaderStageCreateInfo[2] stages;
    memset(stages.ptr, 0, stages.sizeof);
    stages[0].sType = VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO;
    stages[0].stage = VK_SHADER_STAGE_VERTEX_BIT;
    stages[0]._module = vsMod;
    stages[0].pName = "main";
    stages[1].sType = VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO;
    stages[1].stage = VK_SHADER_STAGE_FRAGMENT_BIT;
    stages[1]._module = fsMod;
    stages[1].pName = "main";

    VkPipelineVertexInputStateCreateInfo vi;
    memset(&vi, 0, vi.sizeof); vi.sType = VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO;

    VkPipelineInputAssemblyStateCreateInfo ia;
    memset(&ia, 0, ia.sizeof); ia.sType = VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO;
    ia.topology = VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST;

    VkViewport vp;
    memset(&vp, 0, vp.sizeof);
    vp.width = cast(float)g_width; vp.height = cast(float)g_height; vp.maxDepth = 1.0f;

    VkRect2D sc;
    memset(&sc, 0, sc.sizeof);
    sc.extent = VkExtent2D(g_width, g_height);

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
    vr = vkCreatePipelineLayout(g_vkDevice, &plci, null, &g_vkPipelineLayout);
    if (vr != VK_SUCCESS) { dbgVk("InitVulkan: vkCreatePipelineLayout", vr); return E_FAIL; }

    VkGraphicsPipelineCreateInfo gpci;
    memset(&gpci, 0, gpci.sizeof);
    gpci.sType = VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO;
    gpci.stageCount = 2; gpci.pStages = stages.ptr;
    gpci.pVertexInputState = &vi; gpci.pInputAssemblyState = &ia;
    gpci.pViewportState = &vps; gpci.pRasterizationState = &rs;
    gpci.pMultisampleState = &ms; gpci.pColorBlendState = &cbs;
    gpci.layout = g_vkPipelineLayout; gpci.renderPass = g_vkRenderPass;
    vr = vkCreateGraphicsPipelines(g_vkDevice, 0, 1, &gpci, null, &g_vkPipeline);
    if (vr != VK_SUCCESS) { dbgVk("InitVulkan: vkCreateGraphicsPipelines", vr); return E_FAIL; }
    dbg("[STEP] InitVulkan: graphics pipeline created\n\0");

    /* Command pool, buffer, fence */
    VkCommandPoolCreateInfo cpci;
    memset(&cpci, 0, cpci.sizeof);
    cpci.sType = VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO;
    cpci.flags = VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT;
    cpci.queueFamilyIndex = g_vkQueueFamily;
    vr = vkCreateCommandPool(g_vkDevice, &cpci, null, &g_vkCmdPool);
    if (vr != VK_SUCCESS) { dbgVk("InitVulkan: vkCreateCommandPool", vr); return E_FAIL; }

    VkCommandBufferAllocateInfo cbai;
    memset(&cbai, 0, cbai.sizeof);
    cbai.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO;
    cbai.commandPool = g_vkCmdPool;
    cbai.level = VK_COMMAND_BUFFER_LEVEL_PRIMARY;
    cbai.commandBufferCount = 1;
    vr = vkAllocateCommandBuffers(g_vkDevice, &cbai, &g_vkCmdBuf);
    if (vr != VK_SUCCESS) { dbgVk("InitVulkan: vkAllocateCommandBuffers", vr); return E_FAIL; }

    VkFenceCreateInfo fci;
    memset(&fci, 0, fci.sizeof);
    fci.sType = VK_STRUCTURE_TYPE_FENCE_CREATE_INFO;
    fci.flags = VK_FENCE_CREATE_SIGNALED_BIT;
    vr = vkCreateFence(g_vkDevice, &fci, null, &g_vkFence);
    if (vr != VK_SUCCESS) { dbgVk("InitVulkan: vkCreateFence", vr); return E_FAIL; }

    if (vsMod) vkDestroyShaderModule(g_vkDevice, vsMod, null);
    if (fsMod) vkDestroyShaderModule(g_vkDevice, fsMod, null);
    FreeFileData(&vsSpv);
    FreeFileData(&fsSpv);

    dbg("[STEP] Vulkan third panel ok\n\0");
    return S_OK;
}

/* ============================================================
 * Rendering
 * ============================================================ */
void RenderD3D11Panel() {
    if (!g_dxSwapChain || !g_dxRtv) return;

    D3D11_VIEWPORT vp;
    memset(&vp, 0, vp.sizeof);
    vp.Width = cast(float)g_width;
    vp.Height = cast(float)g_height;
    vp.MaxDepth = 1.0f;
    Ctx_RSSetViewports(g_d3dCtx, 1, &vp);

    void*[1] rtvs = [g_dxRtv];
    Ctx_OMSetRenderTargets(g_d3dCtx, 1, rtvs.ptr, null);
    float[4] clear = [0.05f, 0.15f, 0.05f, 1.0f];
    Ctx_ClearRenderTargetView(g_d3dCtx, g_dxRtv, clear.ptr);

    uint stride = VERTEX.sizeof;
    uint offset = 0;
    void*[1] vbs = [g_vb];
    Ctx_IASetInputLayout(g_d3dCtx, g_inputLayout);
    Ctx_IASetVertexBuffers(g_d3dCtx, 0, 1, vbs.ptr, &stride, &offset);
    Ctx_IASetPrimitiveTopology(g_d3dCtx, D3D11_PRIMITIVE_TOPOLOGY_TRIANGLELIST);
    Ctx_VSSetShader(g_d3dCtx, g_vs);
    Ctx_PSSetShader(g_d3dCtx, g_ps);
    Ctx_Draw(g_d3dCtx, 3, 0);
    SC_Present(g_dxSwapChain, 1, 0);
}

void RenderVulkanPanel() {
    if (!g_vkDevice || !g_vkCmdBuf || !g_vkFence || !g_vkStagingTex || !g_vkBackBuffer) return;

    vkWaitForFences(g_vkDevice, 1, &g_vkFence, TRUE, ulong.max);
    vkResetFences(g_vkDevice, 1, &g_vkFence);
    vkResetCommandBuffer(g_vkCmdBuf, 0);

    VkCommandBufferBeginInfo bi;
    memset(&bi, 0, bi.sizeof);
    bi.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO;
    if (vkBeginCommandBuffer(g_vkCmdBuf, &bi) != VK_SUCCESS) return;

    VkClearValue cv;
    cv.color.float32 = [0.15f, 0.05f, 0.05f, 1.0f];

    VkRenderPassBeginInfo rpbi;
    memset(&rpbi, 0, rpbi.sizeof);
    rpbi.sType = VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO;
    rpbi.renderPass = g_vkRenderPass;
    rpbi.framebuffer = g_vkFramebuffer;
    rpbi.renderArea.extent = VkExtent2D(g_width, g_height);
    rpbi.clearValueCount = 1;
    rpbi.pClearValues = &cv;

    vkCmdBeginRenderPass(g_vkCmdBuf, &rpbi, VK_SUBPASS_CONTENTS_INLINE);
    vkCmdBindPipeline(g_vkCmdBuf, VK_PIPELINE_BIND_POINT_GRAPHICS, g_vkPipeline);
    vkCmdDraw(g_vkCmdBuf, 3, 1, 0, 0);
    vkCmdEndRenderPass(g_vkCmdBuf);

    /* Copy image to readback buffer */
    VkBufferImageCopy region;
    memset(&region, 0, region.sizeof);
    region.bufferRowLength = g_width;
    region.bufferImageHeight = g_height;
    region.imageSubresource.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT;
    region.imageSubresource.layerCount = 1;
    region.imageExtent = VkExtent3D(g_width, g_height, 1);
    vkCmdCopyImageToBuffer(g_vkCmdBuf, g_vkOffImage, VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL,
                           g_vkReadbackBuf, 1, &region);

    if (vkEndCommandBuffer(g_vkCmdBuf) != VK_SUCCESS) return;

    VkSubmitInfo si;
    memset(&si, 0, si.sizeof);
    si.sType = VK_STRUCTURE_TYPE_SUBMIT_INFO;
    si.commandBufferCount = 1;
    si.pCommandBuffers = &g_vkCmdBuf;
    if (vkQueueSubmit(g_vkQueue, 1, &si, g_vkFence) != VK_SUCCESS) return;
    vkWaitForFences(g_vkDevice, 1, &g_vkFence, TRUE, ulong.max);

    /* Readback Vulkan pixels -> D3D11 staging texture -> back buffer */
    void* vkData = null;
    if (vkMapMemory(g_vkDevice, g_vkReadbackMem, 0, cast(VkDeviceSize)g_width * g_height * 4, 0, &vkData) != VK_SUCCESS)
        return;

    D3D11_MAPPED_SUBRESOURCE mapped;
    if (SUCCEEDED(Ctx_Map(g_d3dCtx, g_vkStagingTex, 0, D3D11_MAP.D3D11_MAP_WRITE, 0, &mapped))) {
        const(ubyte)* src = cast(const(ubyte)*)vkData;
        ubyte* dst = cast(ubyte*)mapped.pData;
        uint pitch = g_width * 4;
        for (uint y = 0; y < g_height; ++y)
            memcpy(dst + cast(size_t)y * mapped.RowPitch, src + cast(size_t)y * pitch, pitch);
        Ctx_Unmap(g_d3dCtx, g_vkStagingTex, 0);
        Ctx_CopyResource(g_d3dCtx, g_vkBackBuffer, g_vkStagingTex);
    }
    vkUnmapMemory(g_vkDevice, g_vkReadbackMem);
    SC_Present(g_vkSwapChain, 1, 0);
}

void Render() {
    if (!g_hdc || !g_hglrc || !g_glInteropDevice || !g_glInteropObject || !g_glFbo)
        return;
    if (!wglMakeCurrent(g_hdc, g_hglrc)) return;

    /* Lock D3D back buffer for GL rendering */
    HANDLE[1] objs = [g_glInteropObject];
    if (!p_wglDXLockObjectsNV(g_glInteropDevice, 1, objs.ptr)) return;

    p_glBindFramebuffer(GL_FRAMEBUFFER, g_glFbo);
    glViewport(0, 0, cast(GLsizei)g_width, cast(GLsizei)g_height);
    glClearColor(0.05f, 0.05f, 0.15f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT);

    p_glUseProgram(g_glProgram);
    p_glBindBuffer(GL_ARRAY_BUFFER, g_glVbo[0]);
    p_glVertexAttribPointer(cast(GLuint)g_glPosAttrib, 3, GL_FLOAT, 0, 0, null);
    p_glBindBuffer(GL_ARRAY_BUFFER, g_glVbo[1]);
    p_glVertexAttribPointer(cast(GLuint)g_glColAttrib, 3, GL_FLOAT, 0, 0, null);
    glDrawArrays(GL_TRIANGLES, 0, 3);
    glFlush();
    p_glBindFramebuffer(GL_FRAMEBUFFER, 0);

    p_wglDXUnlockObjectsNV(g_glInteropDevice, 1, objs.ptr);

    /* Present GL panel */
    SC_Present(g_swapChain, 1, 0);

    /* Render other panels */
    RenderD3D11Panel();
    RenderVulkanPanel();
}

/* ============================================================
 * Cleanup
 * ============================================================ */
void CleanupVulkanPanel() {
    if (g_vkDevice) vkDeviceWaitIdle(g_vkDevice);
    if (g_vkFence)          { vkDestroyFence(g_vkDevice, g_vkFence, null);          g_vkFence = 0; }
    if (g_vkCmdPool)        { vkDestroyCommandPool(g_vkDevice, g_vkCmdPool, null);  g_vkCmdPool = 0; }
    if (g_vkPipeline)       { vkDestroyPipeline(g_vkDevice, g_vkPipeline, null);    g_vkPipeline = 0; }
    if (g_vkPipelineLayout) { vkDestroyPipelineLayout(g_vkDevice, g_vkPipelineLayout, null); g_vkPipelineLayout = 0; }
    if (g_vkFramebuffer)    { vkDestroyFramebuffer(g_vkDevice, g_vkFramebuffer, null); g_vkFramebuffer = 0; }
    if (g_vkRenderPass)     { vkDestroyRenderPass(g_vkDevice, g_vkRenderPass, null); g_vkRenderPass = 0; }
    if (g_vkOffView)        { vkDestroyImageView(g_vkDevice, g_vkOffView, null);    g_vkOffView = 0; }
    if (g_vkOffImage)       { vkDestroyImage(g_vkDevice, g_vkOffImage, null);       g_vkOffImage = 0; }
    if (g_vkOffMemory)      { vkFreeMemory(g_vkDevice, g_vkOffMemory, null);        g_vkOffMemory = 0; }
    if (g_vkReadbackBuf)    { vkDestroyBuffer(g_vkDevice, g_vkReadbackBuf, null);   g_vkReadbackBuf = 0; }
    if (g_vkReadbackMem)    { vkFreeMemory(g_vkDevice, g_vkReadbackMem, null);      g_vkReadbackMem = 0; }
    if (g_vkDevice)         { vkDestroyDevice(g_vkDevice, null);                    g_vkDevice = null; }
    if (g_vkInstance)       { vkDestroyInstance(g_vkInstance, null);                 g_vkInstance = null; }
    if (g_vkStagingTex)     { Rel(g_vkStagingTex); g_vkStagingTex = null; }
    if (g_vkBackBuffer)     { Rel(g_vkBackBuffer); g_vkBackBuffer = null; }
}

void Cleanup() {
    dbg("[STEP] Cleanup begin\n\0");

    /* Release composition visuals */
    Rel(g_visualCollection);     g_visualCollection = null;
    Rel(g_vkVisual);             g_vkVisual = null;
    Rel(g_vkCompositionBrush);   g_vkCompositionBrush = null;
    Rel(g_vkSpriteVisual);       g_vkSpriteVisual = null;
    Rel(g_vkSurfaceBrush);       g_vkSurfaceBrush = null;
    Rel(g_vkCompositionSurface); g_vkCompositionSurface = null;
    Rel(g_dxVisual);             g_dxVisual = null;
    Rel(g_dxCompositionBrush);   g_dxCompositionBrush = null;
    Rel(g_dxSpriteVisual);       g_dxSpriteVisual = null;
    Rel(g_dxSurfaceBrush);       g_dxSurfaceBrush = null;
    Rel(g_dxCompositionSurface); g_dxCompositionSurface = null;
    Rel(g_visual);               g_visual = null;
    Rel(g_compositionBrush);     g_compositionBrush = null;
    Rel(g_spriteVisual);         g_spriteVisual = null;
    Rel(g_surfaceBrush);         g_surfaceBrush = null;
    Rel(g_compositionSurface);   g_compositionSurface = null;
    Rel(g_rootVisual);           g_rootVisual = null;
    Rel(g_compositionTarget);    g_compositionTarget = null;
    Rel(g_desktopTarget);        g_desktopTarget = null;
    Rel(g_compInterop);          g_compInterop = null;
    Rel(g_desktopInterop);       g_desktopInterop = null;
    Rel(g_compositor);           g_compositor = null;

    /* Vulkan cleanup */
    CleanupVulkanPanel();

    /* OpenGL / WGL / NV interop cleanup */
    if (g_glInteropObject && g_glInteropDevice && p_wglDXUnregisterObjectNV) {
        p_wglDXUnregisterObjectNV(g_glInteropDevice, g_glInteropObject);
        g_glInteropObject = null;
    }
    if (g_glInteropDevice && p_wglDXCloseDeviceNV) {
        p_wglDXCloseDeviceNV(g_glInteropDevice);
        g_glInteropDevice = null;
    }
    if (g_hdc && g_hglrc) wglMakeCurrent(g_hdc, g_hglrc);
    if (g_glProgram && p_glDeleteProgram) { p_glDeleteProgram(g_glProgram); g_glProgram = 0; }
    if (g_glVbo[0] && p_glDeleteBuffers) { p_glDeleteBuffers(2, g_glVbo.ptr); g_glVbo[0] = 0; g_glVbo[1] = 0; }
    if (g_glVao && p_glDeleteVertexArrays) { p_glDeleteVertexArrays(1, &g_glVao); g_glVao = 0; }
    if (g_glFbo && p_glDeleteFramebuffers) { p_glDeleteFramebuffers(1, &g_glFbo); g_glFbo = 0; }
    if (g_glRbo && p_glDeleteRenderbuffers) { p_glDeleteRenderbuffers(1, &g_glRbo); g_glRbo = 0; }
    DisableOpenGL();

    /* D3D11 cleanup */
    if (g_vb)          Rel(g_vb);           g_vb = null;
    if (g_inputLayout) Rel(g_inputLayout);  g_inputLayout = null;
    if (g_ps)          Rel(g_ps);           g_ps = null;
    if (g_vs)          Rel(g_vs);           g_vs = null;
    if (g_rtv)         Rel(g_rtv);          g_rtv = null;
    if (g_dxRtv)       Rel(g_dxRtv);        g_dxRtv = null;
    if (g_backBuffer)  Rel(g_backBuffer);   g_backBuffer = null;
    if (g_swapChain)   Rel(g_swapChain);    g_swapChain = null;
    if (g_dxSwapChain) Rel(g_dxSwapChain);  g_dxSwapChain = null;
    if (g_vkSwapChain) Rel(g_vkSwapChain);  g_vkSwapChain = null;
    if (g_d3dCtx)      Rel(g_d3dCtx);       g_d3dCtx = null;
    if (g_d3dDevice)   Rel(g_d3dDevice);    g_d3dDevice = null;

    if (g_dqController) { Rel(g_dqController); g_dqController = null; }

    if (g_comInitialized) {
        CoUninitialize();
        g_comInitialized = FALSE;
    }

    dbg("[STEP] Cleanup ok\n\0");
}

/* ============================================================
 * Window procedure
 * ============================================================ */
extern(Windows)
LRESULT WndProc(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam) nothrow {
    switch (msg) {
        case WM_DESTROY:
            PostQuitMessage(0);
            return 0;
        case WM_PAINT:
            PAINTSTRUCT ps;
            BeginPaint(hWnd, &ps);
            EndPaint(hWnd, &ps);
            return 0;
        default:
            return DefWindowProc(hWnd, msg, wParam, lParam);
    }
}

/* ============================================================
 * Create application window
 * ============================================================ */
uint CreateAppWindow(HINSTANCE hInst) {
    WNDCLASSEX wc;
    memset(&wc, 0, wc.sizeof);
    wc.cbSize        = cast(uint)wc.sizeof;
    wc.hInstance     = hInst;
    wc.lpszClassName = "Win32CompTriangleD"w.ptr;
    wc.lpfnWndProc   = &WndProc;
    wc.hCursor       = LoadCursor(null, IDC_ARROW);
    wc.hbrBackground = null;

    if (!RegisterClassEx(&wc)) {
        /* Ignore if already registered */
    }

    DWORD style = WS_OVERLAPPEDWINDOW;
    RECT rc;
    rc.left = 0; rc.top = 0; rc.right = cast(LONG)g_windowWidth; rc.bottom = cast(LONG)g_height;
    AdjustWindowRect(&rc, style, FALSE);

    g_hwnd = CreateWindowEx(
        WS_EX_NOREDIRECTIONBITMAP,
        "Win32CompTriangleD"w.ptr,
        "OpenGL + D3D11 + Vulkan via DirectComposition (D)"w.ptr,
        style,
        CW_USEDEFAULT, CW_USEDEFAULT,
        rc.right - rc.left, rc.bottom - rc.top,
        null, null, hInst, null
    );

    if (!g_hwnd) return E_FAIL;

    ShowWindow(g_hwnd, SW_SHOW);
    UpdateWindow(g_hwnd);
    return S_OK;
}

/* ============================================================
 * Entry point
 * ============================================================ */
extern(Windows)
int WinMain(HINSTANCE hInst, HINSTANCE hPrev, LPSTR pCmdLine, int nCmdShow) {
    MSG msg;
    uint hr;

    dbg("[STEP] wWinMain start\n\0");

    hr = CreateAppWindow(hInst);
    if (FAILED(hr)) { dbgHr("WinMain: CreateAppWindow", hr); Cleanup(); return cast(int)hr; }

    dbg("[STEP] InitD3D11...\n\0");
    hr = InitD3D11AndSwapChainForComposition();
    if (FAILED(hr)) { dbgHr("WinMain: InitD3D11AndSwapChainForComposition", hr); Cleanup(); return cast(int)hr; }

    dbg("[STEP] InitComposition...\n\0");
    hr = InitCompositionForHwnd();
    if (FAILED(hr)) { dbgHr("WinMain: InitCompositionForHwnd", hr); Cleanup(); return cast(int)hr; }

    dbg("[STEP] InitOpenGL...\n\0");
    hr = InitOpenGLForComposition();
    if (FAILED(hr)) { dbgHr("WinMain: InitOpenGLForComposition", hr); Cleanup(); return cast(int)hr; }

    dbg("[STEP] InitD3D11Panel...\n\0");
    hr = InitD3D11SecondPanel();
    if (FAILED(hr)) { dbgHr("WinMain: InitD3D11SecondPanel", hr); Cleanup(); return cast(int)hr; }

    dbg("[STEP] InitVulkanPanel...\n\0");
    hr = InitVulkanThirdPanel();
    if (FAILED(hr)) { dbgHr("WinMain: InitVulkanThirdPanel", hr); Cleanup(); return cast(int)hr; }

    if (g_compositor) {
        hr = DCompDevice_Commit(g_compositor);
        if (FAILED(hr)) { dbgHr("WinMain: DCompDevice_Commit", hr); Cleanup(); return cast(int)hr; }
    }

    dbg("[STEP] === ENTERING MESSAGE LOOP ===\n\0");
    memset(&msg, 0, msg.sizeof);
    while (msg.message != WM_QUIT) {
        if (PeekMessage(&msg, null, 0, 0, PM_REMOVE)) {
            TranslateMessage(&msg);
            DispatchMessage(&msg);
        } else {
            Render();
        }
    }

    dbg("[STEP] loop end\n\0");
    Cleanup();
    return 0;
}
