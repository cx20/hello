// Vulkan 1.4 Ray Marching Example in Go
// Win32 API + Manual Vulkan Bindings
// Build: go build -ldflags="-H windowsgui" hello_raymarching.go
// Note: Vulkan SDK must be installed
//
// Shader compilation (requires glslc from Vulkan SDK):
//   glslc.exe hello.vert -o hello_vert.spv
//   glslc.exe hello.frag -o hello_frag.spv
//
// Features:
// - Runtime SPIR-V shader loading from .spv files
// - Full-screen triangle technique
// - Push constants for time and resolution
// - Animated SDF shapes (sphere + torus)
// - Soft shadows, ambient occlusion, and fog

package main

import (
    "encoding/binary"
    "fmt"
    "math"
    "os"
    "runtime"
    "syscall"
    "time"
    "unsafe"
)

// =============================================================================
// Constants
// =============================================================================

const (
    WIDTH                = 800
    HEIGHT               = 600
    MAX_FRAMES_IN_FLIGHT = 2
    NUM_HARMONOGRAPH_POINTS = 500000
)

// Win32 constants
const (
    CW_USEDEFAULT     uint32 = 0x80000000
    WS_OVERLAPPEDWINDOW      = 0x00CF0000
    WM_DESTROY               = 0x0002
    WM_CLOSE                 = 0x0010
    WM_QUIT                  = 0x0012
    PM_REMOVE                = 0x0001
    CS_OWNDC                 = 0x0020
    IDC_ARROW                = 32512
    IDI_APPLICATION          = 32512
    BLACK_BRUSH              = 4
)

// Vulkan constants
const (
    VK_SUCCESS               = 0
    VK_ERROR_OUT_OF_DATE_KHR = -1000001004

    VK_STRUCTURE_TYPE_APPLICATION_INFO                          = 0
    VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO                      = 1
    VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO                  = 2
    VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO                        = 3
    VK_STRUCTURE_TYPE_SUBMIT_INFO                               = 4
    VK_STRUCTURE_TYPE_FENCE_CREATE_INFO                         = 8
    VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO                     = 9
    VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO                    = 15
    VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO                 = 16
    VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO         = 18
    VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO   = 19
    VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO = 20
    VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO       = 22
    VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO  = 23
    VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO    = 24
    VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO    = 26
    VK_STRUCTURE_TYPE_PIPELINE_DYNAMIC_STATE_CREATE_INFO        = 27
    VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO             = 28
    VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO               = 30
    VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO                   = 37
    VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO                   = 38
    VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO                  = 39
    VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO              = 40
    VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO                 = 42
    VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO                    = 43
    VK_STRUCTURE_TYPE_BUFFER_MEMORY_BARRIER                     = 44
    VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO                        = 12
    VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO                      = 5
    VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO         = 33
    VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO               = 34
    VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO              = 35
    VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET                      = 36
    VK_STRUCTURE_TYPE_COMPUTE_PIPELINE_CREATE_INFO              = 29
    VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR                 = 1000001000
    VK_STRUCTURE_TYPE_PRESENT_INFO_KHR                          = 1000001001
    VK_STRUCTURE_TYPE_WIN32_SURFACE_CREATE_INFO_KHR             = 1000009000

    VK_FORMAT_B8G8R8A8_SRGB           = 50
    VK_COLOR_SPACE_SRGB_NONLINEAR_KHR = 0

    VK_PRESENT_MODE_MAILBOX_KHR = 1
    VK_PRESENT_MODE_FIFO_KHR    = 2

    VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT = 0x00000010

    VK_SHARING_MODE_EXCLUSIVE  = 0
    VK_SHARING_MODE_CONCURRENT = 1

    VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR = 0x00000001

    VK_IMAGE_VIEW_TYPE_2D         = 1
    VK_COMPONENT_SWIZZLE_IDENTITY = 0
    VK_IMAGE_ASPECT_COLOR_BIT     = 0x00000001

    VK_ATTACHMENT_LOAD_OP_CLEAR      = 1
    VK_ATTACHMENT_STORE_OP_STORE     = 0
    VK_ATTACHMENT_STORE_OP_DONT_CARE = 1

    VK_IMAGE_LAYOUT_UNDEFINED                = 0
    VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL = 2
    VK_IMAGE_LAYOUT_PRESENT_SRC_KHR          = 1000001002

    VK_PIPELINE_BIND_POINT_GRAPHICS = 0
    VK_PIPELINE_BIND_POINT_COMPUTE  = 1

    VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT = 0x00000400
    VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT          = 0x00000800
    VK_PIPELINE_STAGE_VERTEX_INPUT_BIT            = 0x00000004
    VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT          = 0x00000100
    VK_ACCESS_SHADER_READ_BIT                     = 0x00000020
    VK_ACCESS_SHADER_WRITE_BIT                    = 0x00000040

    VK_SHADER_STAGE_VERTEX_BIT   = 0x00000001
    VK_SHADER_STAGE_FRAGMENT_BIT = 0x00000010
    VK_SHADER_STAGE_COMPUTE_BIT  = 0x00000020

    VK_PRIMITIVE_TOPOLOGY_POINT_LIST   = 0
    VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST = 3
    VK_POLYGON_MODE_FILL                = 0
    VK_CULL_MODE_NONE                   = 0
    VK_FRONT_FACE_CLOCKWISE             = 1

    VK_COLOR_COMPONENT_R_BIT = 0x00000001
    VK_COLOR_COMPONENT_G_BIT = 0x00000002
    VK_COLOR_COMPONENT_B_BIT = 0x00000004
    VK_COLOR_COMPONENT_A_BIT = 0x00000008

    VK_DYNAMIC_STATE_VIEWPORT = 0
    VK_DYNAMIC_STATE_SCISSOR  = 1

    VK_SUBPASS_CONTENTS_INLINE      = 0
    VK_COMMAND_BUFFER_LEVEL_PRIMARY = 0
    VK_FENCE_CREATE_SIGNALED_BIT    = 0x00000001
    VK_QUEUE_GRAPHICS_BIT           = 0x00000001

    VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT = 0x00000002
    VK_SUBPASS_EXTERNAL                             = 0xFFFFFFFF
    
    // Buffer usage flags
    VK_BUFFER_USAGE_STORAGE_BUFFER_BIT = 0x00000020
    VK_BUFFER_USAGE_UNIFORM_BUFFER_BIT = 0x00000010
    VK_BUFFER_USAGE_TRANSFER_DST_BIT   = 0x00000001
    
    // Memory property flags
    VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT  = 0x00000001
    VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT  = 0x00000002
    VK_MEMORY_PROPERTY_HOST_COHERENT_BIT = 0x00000004
    
    // Descriptor types
    VK_DESCRIPTOR_TYPE_STORAGE_BUFFER = 7
    VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER = 6
)

// =============================================================================
// Vulkan Type Definitions
// =============================================================================

type VkInstance uintptr
type VkPhysicalDevice uintptr
type VkDevice uintptr
type VkQueue uintptr
type VkSurfaceKHR uintptr
type VkSwapchainKHR uintptr
type VkImage uintptr
type VkImageView uintptr
type VkRenderPass uintptr
type VkPipelineLayout uintptr
type VkPipeline uintptr
type VkFramebuffer uintptr
type VkCommandPool uintptr
type VkCommandBuffer uintptr
type VkSemaphore uintptr
type VkFence uintptr
type VkShaderModule uintptr
type VkDescriptorSetLayout uintptr
type VkDescriptorPool uintptr
type VkDescriptorSet uintptr

// =============================================================================
// Vulkan Structure Definitions
// =============================================================================

type VkExtent2D struct {
    Width  uint32
    Height uint32
}

type VkOffset2D struct {
    X int32
    Y int32
}

type VkRect2D struct {
    Offset VkOffset2D
    Extent VkExtent2D
}

type VkViewport struct {
    X, Y, Width, Height, MinDepth, MaxDepth float32
}

type VkClearColorValue struct {
    Float32 [4]float32
}

type VkClearValue struct {
    Color VkClearColorValue
}

type VkApplicationInfo struct {
    SType              uint32
    PNext              uintptr
    PApplicationName   *byte
    ApplicationVersion uint32
    PEngineName        *byte
    EngineVersion      uint32
    ApiVersion         uint32
}

type VkInstanceCreateInfo struct {
    SType                   uint32
    PNext                   uintptr
    Flags                   uint32
    PApplicationInfo        *VkApplicationInfo
    EnabledLayerCount       uint32
    PpEnabledLayerNames     **byte
    EnabledExtensionCount   uint32
    PpEnabledExtensionNames **byte
}

type VkQueueFamilyProperties struct {
    QueueFlags                  uint32
    QueueCount                  uint32
    TimestampValidBits          uint32
    MinImageTransferGranularity [3]uint32
}

type VkDeviceQueueCreateInfo struct {
    SType            uint32
    PNext            uintptr
    Flags            uint32
    QueueFamilyIndex uint32
    QueueCount       uint32
    PQueuePriorities *float32
}

type VkDeviceCreateInfo struct {
    SType                   uint32
    PNext                   uintptr
    Flags                   uint32
    QueueCreateInfoCount    uint32
    PQueueCreateInfos       *VkDeviceQueueCreateInfo
    EnabledLayerCount       uint32
    PpEnabledLayerNames     **byte
    EnabledExtensionCount   uint32
    PpEnabledExtensionNames **byte
    PEnabledFeatures        uintptr
}

type VkSurfaceCapabilitiesKHR struct {
    MinImageCount           uint32
    MaxImageCount           uint32
    CurrentExtent           VkExtent2D
    MinImageExtent          VkExtent2D
    MaxImageExtent          VkExtent2D
    MaxImageArrayLayers     uint32
    SupportedTransforms     uint32
    CurrentTransform        uint32
    SupportedCompositeAlpha uint32
    SupportedUsageFlags     uint32
}

type VkSurfaceFormatKHR struct {
    Format     uint32
    ColorSpace uint32
}

type VkSwapchainCreateInfoKHR struct {
    SType                 uint32
    PNext                 uintptr
    Flags                 uint32
    Surface               VkSurfaceKHR
    MinImageCount         uint32
    ImageFormat           uint32
    ImageColorSpace       uint32
    ImageExtent           VkExtent2D
    ImageArrayLayers      uint32
    ImageUsage            uint32
    ImageSharingMode      uint32
    QueueFamilyIndexCount uint32
    PQueueFamilyIndices   *uint32
    PreTransform          uint32
    CompositeAlpha        uint32
    PresentMode           uint32
    Clipped               uint32
    OldSwapchain          VkSwapchainKHR
}

type VkComponentMapping struct {
    R, G, B, A uint32
}

type VkImageSubresourceRange struct {
    AspectMask     uint32
    BaseMipLevel   uint32
    LevelCount     uint32
    BaseArrayLayer uint32
    LayerCount     uint32
}

type VkImageViewCreateInfo struct {
    SType            uint32
    PNext            uintptr
    Flags            uint32
    Image            VkImage
    ViewType         uint32
    Format           uint32
    Components       VkComponentMapping
    SubresourceRange VkImageSubresourceRange
}

type VkAttachmentDescription struct {
    Flags          uint32
    Format         uint32
    Samples        uint32
    LoadOp         uint32
    StoreOp        uint32
    StencilLoadOp  uint32
    StencilStoreOp uint32
    InitialLayout  uint32
    FinalLayout    uint32
}

type VkAttachmentReference struct {
    Attachment uint32
    Layout     uint32
}

type VkSubpassDescription struct {
    Flags                   uint32
    PipelineBindPoint       uint32
    InputAttachmentCount    uint32
    PInputAttachments       *VkAttachmentReference
    ColorAttachmentCount    uint32
    PColorAttachments       *VkAttachmentReference
    PResolveAttachments     *VkAttachmentReference
    PDepthStencilAttachment *VkAttachmentReference
    PreserveAttachmentCount uint32
    PPreserveAttachments    *uint32
}

type VkSubpassDependency struct {
    SrcSubpass      uint32
    DstSubpass      uint32
    SrcStageMask    uint32
    DstStageMask    uint32
    SrcAccessMask   uint32
    DstAccessMask   uint32
    DependencyFlags uint32
}

type VkRenderPassCreateInfo struct {
    SType           uint32
    PNext           uintptr
    Flags           uint32
    AttachmentCount uint32
    PAttachments    *VkAttachmentDescription
    SubpassCount    uint32
    PSubpasses      *VkSubpassDescription
    DependencyCount uint32
    PDependencies   *VkSubpassDependency
}

type VkShaderModuleCreateInfo struct {
    SType    uint32
    PNext    uintptr
    Flags    uint32
    CodeSize uintptr
    PCode    *uint32
}

type VkPipelineShaderStageCreateInfo struct {
    SType               uint32
    PNext               uintptr
    Flags               uint32
    Stage               uint32
    Module              VkShaderModule
    PName               *byte
    PSpecializationInfo uintptr
}

type VkPipelineVertexInputStateCreateInfo struct {
    SType                           uint32
    PNext                           uintptr
    Flags                           uint32
    VertexBindingDescriptionCount   uint32
    PVertexBindingDescriptions      uintptr
    VertexAttributeDescriptionCount uint32
    PVertexAttributeDescriptions    uintptr
}

type VkPipelineInputAssemblyStateCreateInfo struct {
    SType                  uint32
    PNext                  uintptr
    Flags                  uint32
    Topology               uint32
    PrimitiveRestartEnable uint32
}

type VkPipelineViewportStateCreateInfo struct {
    SType         uint32
    PNext         uintptr
    Flags         uint32
    ViewportCount uint32
    PViewports    *VkViewport
    ScissorCount  uint32
    PScissors     *VkRect2D
}

type VkPipelineRasterizationStateCreateInfo struct {
    SType                   uint32
    PNext                   uintptr
    Flags                   uint32
    DepthClampEnable        uint32
    RasterizerDiscardEnable uint32
    PolygonMode             uint32
    CullMode                uint32
    FrontFace               uint32
    DepthBiasEnable         uint32
    DepthBiasConstantFactor float32
    DepthBiasClamp          float32
    DepthBiasSlopeFactor    float32
    LineWidth               float32
}

type VkPipelineMultisampleStateCreateInfo struct {
    SType                 uint32
    PNext                 uintptr
    Flags                 uint32
    RasterizationSamples  uint32
    SampleShadingEnable   uint32
    MinSampleShading      float32
    PSampleMask           *uint32
    AlphaToCoverageEnable uint32
    AlphaToOneEnable      uint32
}

type VkPipelineColorBlendAttachmentState struct {
    BlendEnable         uint32
    SrcColorBlendFactor uint32
    DstColorBlendFactor uint32
    ColorBlendOp        uint32
    SrcAlphaBlendFactor uint32
    DstAlphaBlendFactor uint32
    AlphaBlendOp        uint32
    ColorWriteMask      uint32
}

type VkPipelineColorBlendStateCreateInfo struct {
    SType           uint32
    PNext           uintptr
    Flags           uint32
    LogicOpEnable   uint32
    LogicOp         uint32
    AttachmentCount uint32
    PAttachments    *VkPipelineColorBlendAttachmentState
    BlendConstants  [4]float32
}

type VkPipelineDynamicStateCreateInfo struct {
    SType             uint32
    PNext             uintptr
    Flags             uint32
    DynamicStateCount uint32
    PDynamicStates    *uint32
}

type VkPushConstantRange struct {
    StageFlags uint32
    Offset     uint32
    Size       uint32
}

type VkPipelineLayoutCreateInfo struct {
    SType                  uint32
    PNext                  uintptr
    Flags                  uint32
    SetLayoutCount         uint32
    PSetLayouts            uintptr
    PushConstantRangeCount uint32
    PPushConstantRanges    *VkPushConstantRange
}

type VkGraphicsPipelineCreateInfo struct {
    SType               uint32
    PNext               uintptr
    Flags               uint32
    StageCount          uint32
    PStages             *VkPipelineShaderStageCreateInfo
    PVertexInputState   *VkPipelineVertexInputStateCreateInfo
    PInputAssemblyState *VkPipelineInputAssemblyStateCreateInfo
    PTessellationState  uintptr
    PViewportState      *VkPipelineViewportStateCreateInfo
    PRasterizationState *VkPipelineRasterizationStateCreateInfo
    PMultisampleState   *VkPipelineMultisampleStateCreateInfo
    PDepthStencilState  uintptr
    PColorBlendState    *VkPipelineColorBlendStateCreateInfo
    PDynamicState       *VkPipelineDynamicStateCreateInfo
    Layout              VkPipelineLayout
    RenderPass          VkRenderPass
    Subpass             uint32
    BasePipelineHandle  VkPipeline
    BasePipelineIndex   int32
}

type VkFramebufferCreateInfo struct {
    SType           uint32
    PNext           uintptr
    Flags           uint32
    RenderPass      VkRenderPass
    AttachmentCount uint32
    PAttachments    *VkImageView
    Width           uint32
    Height          uint32
    Layers          uint32
}

type VkCommandPoolCreateInfo struct {
    SType            uint32
    PNext            uintptr
    Flags            uint32
    QueueFamilyIndex uint32
}

type VkCommandBufferAllocateInfo struct {
    SType              uint32
    PNext              uintptr
    CommandPool        VkCommandPool
    Level              uint32
    CommandBufferCount uint32
}

type VkCommandBufferBeginInfo struct {
    SType            uint32
    PNext            uintptr
    Flags            uint32
    PInheritanceInfo uintptr
}

type VkRenderPassBeginInfo struct {
    SType           uint32
    PNext           uintptr
    RenderPass      VkRenderPass
    Framebuffer     VkFramebuffer
    RenderArea      VkRect2D
    ClearValueCount uint32
    PClearValues    *VkClearValue
}

type VkSemaphoreCreateInfo struct {
    SType uint32
    PNext uintptr
    Flags uint32
}

type VkFenceCreateInfo struct {
    SType uint32
    PNext uintptr
    Flags uint32
}

type VkSubmitInfo struct {
    SType                uint32
    PNext                uintptr
    WaitSemaphoreCount   uint32
    PWaitSemaphores      *VkSemaphore
    PWaitDstStageMask    *uint32
    CommandBufferCount   uint32
    PCommandBuffers      *VkCommandBuffer
    SignalSemaphoreCount uint32
    PSignalSemaphores    *VkSemaphore
}

type VkPresentInfoKHR struct {
    SType              uint32
    PNext              uintptr
    WaitSemaphoreCount uint32
    PWaitSemaphores    *VkSemaphore
    SwapchainCount     uint32
    PSwapchains        *VkSwapchainKHR
    PImageIndices      *uint32
    PResults           *int32
}

type VkWin32SurfaceCreateInfoKHR struct {
    SType     uint32
    PNext     uintptr
    Flags     uint32
    Hinstance syscall.Handle
    Hwnd      syscall.Handle
}

// Buffer creation structures
type VkBuffer uintptr
type VkDeviceMemory uintptr

type VkBufferCreateInfo struct {
    SType                 uint32
    PNext                 uintptr
    Flags                 uint32
    Size                  uintptr
    Usage                 uint32
    SharingMode           uint32
    QueueFamilyIndexCount uint32
    PQueueFamilyIndices   *uint32
}

type VkMemoryRequirements struct {
    Size           uintptr
    Alignment      uintptr
    MemoryTypeBits uint32
}

type VkBufferMemoryBarrier struct {
    SType               uint32
    PNext               uintptr
    SrcAccessMask       uint32
    DstAccessMask       uint32
    SrcQueueFamilyIndex uint32
    DstQueueFamilyIndex uint32
    Buffer              uintptr
    Offset              uintptr
    Size                uintptr
}

type VkPhysicalDeviceMemoryProperties struct {
    MemoryTypeCount uint32
    MemoryTypes     [32]struct {
        PropertyFlags uint32
        HeapIndex     uint32
    }
}

type VkAllocateMemoryInfo struct {
    SType           uint32
    PNext           uintptr
    AllocationSize  uintptr
    MemoryTypeIndex uint32
}

type VkDescriptorSetLayoutBinding struct {
    Binding            uint32
    DescriptorType     uint32
    DescriptorCount    uint32
    StageFlags         uint32
    PImmutableSamplers uintptr
}

type VkDescriptorSetLayoutCreateInfo struct {
    SType        uint32
    PNext        uintptr
    Flags        uint32
    BindingCount uint32
    PBindings    *VkDescriptorSetLayoutBinding
}

type VkDescriptorPoolSize struct {
    DescriptorType uint32
    DescriptorCount uint32
}

type VkDescriptorPoolCreateInfo struct {
    SType         uint32
    PNext         uintptr
    Flags         uint32
    MaxSets       uint32
    PoolSizeCount uint32
    PPoolSizes    *VkDescriptorPoolSize
}

type VkDescriptorSetAllocateInfo struct {
    SType              uint32
    PNext              uintptr
    DescriptorPool     VkDescriptorPool
    DescriptorSetCount uint32
    PSetLayouts        uintptr
}

type VkDescriptorBufferInfo struct {
    Buffer uintptr
    Offset uintptr
    Range  uintptr
}

type VkWriteDescriptorSet struct {
    SType            uint32
    PNext            uintptr
    DstSet           uintptr
    DstBinding       uint32
    DstArrayElement  uint32
    DescriptorCount  uint32
    DescriptorType   uint32
    PImageInfo       uintptr
    PBufferInfo      *VkDescriptorBufferInfo
    PTexelBufferView uintptr
}

type VkComputePipelineCreateInfo struct {
    SType              uint32
    PNext              uintptr
    Flags              uint32
    Stage              VkPipelineShaderStageCreateInfo
    Layout             VkPipelineLayout
    BasePipelineHandle VkPipeline
    BasePipelineIndex  int32
}

// Push constants structure (matches shader layout)
type PushConstants struct {
    ITime       float32
    Padding     float32
    IResolution [2]float32
}

// Compute shader parameters
type ComputeParams struct {
    MaxNum uint32
    DT     float32
    Scale  float32
    Pad0   float32
    A1, F1, P1, D1 float32
    A2, F2, P2, D2 float32
    A3, F3, P3, D3 float32
    A4, F4, P4, D4 float32
}

// =============================================================================
// Win32 Structures
// =============================================================================

type POINT struct {
    X, Y int32
}

type MSG struct {
    Hwnd    syscall.Handle
    Message uint32
    _       uint32
    WParam  uintptr
    LParam  uintptr
    Time    uint32
    Pt      POINT
}

type WNDCLASSEXW struct {
    Size       uint32
    Style      uint32
    WndProc    uintptr
    ClsExtra   int32
    WndExtra   int32
    Instance   syscall.Handle
    Icon       syscall.Handle
    Cursor     syscall.Handle
    Background syscall.Handle
    MenuName   *uint16
    ClassName  *uint16
    IconSm     syscall.Handle
}

// =============================================================================
// Application State
// =============================================================================

type App struct {
    hwnd      syscall.Handle
    hInstance syscall.Handle

    instance       VkInstance
    surface        VkSurfaceKHR
    physicalDevice VkPhysicalDevice
    device         VkDevice
    graphicsQueue  VkQueue
    presentQueue   VkQueue
    graphicsFamily uint32
    presentFamily  uint32

    swapChain             VkSwapchainKHR
    swapChainImages       []VkImage
    swapChainImageFormat  uint32
    swapChainExtent       VkExtent2D
    swapChainImageViews   []VkImageView
    swapChainFramebuffers []VkFramebuffer

    renderPass       VkRenderPass
    pipelineLayout   VkPipelineLayout
    graphicsPipeline VkPipeline

    // Compute shader related
    computePipeline       VkPipeline
    computePipelineLayout VkPipelineLayout
    
    // Storage buffers for harmonograph computation
    positionBuffer    VkBuffer
    positionBufferMem VkDeviceMemory
    colorBuffer       VkBuffer
    colorBufferMem    VkDeviceMemory
    paramBuffer       VkBuffer
    paramBufferMemory VkDeviceMemory
    
    // Descriptor resources
    descriptorSetLayout VkDescriptorSetLayout
    descriptorPool      VkDescriptorPool
    descriptorSet       VkDescriptorSet

    commandPool    VkCommandPool
    commandBuffers []VkCommandBuffer
    
    // Compute command buffer
    computeCommandBuffer VkCommandBuffer

    imageAvailableSemaphores [MAX_FRAMES_IN_FLIGHT]VkSemaphore
    renderFinishedSemaphores [MAX_FRAMES_IN_FLIGHT]VkSemaphore
    inFlightFences           [MAX_FRAMES_IN_FLIGHT]VkFence
    
    // Compute synchronization
    computeFence VkFence
    
    currentFrame int

    startTime time.Time
    animationTime float32
}

var app App

// =============================================================================
// Vulkan Function Pointers
// =============================================================================

var (
    vulkanDLL                syscall.Handle
    ptrVkGetInstanceProcAddr uintptr

    ptrVkCreateInstance                          uintptr
    ptrVkDestroyInstance                         uintptr
    ptrVkEnumeratePhysicalDevices                uintptr
    ptrVkGetPhysicalDeviceQueueFamilyProperties  uintptr
    ptrVkCreateDevice                            uintptr
    ptrVkDestroyDevice                           uintptr
    ptrVkGetDeviceQueue                          uintptr
    ptrVkDeviceWaitIdle                          uintptr
    ptrVkDestroySurfaceKHR                       uintptr
    ptrVkGetPhysicalDeviceSurfaceSupportKHR      uintptr
    ptrVkGetPhysicalDeviceSurfaceCapabilitiesKHR uintptr
    ptrVkGetPhysicalDeviceSurfaceFormatsKHR      uintptr
    ptrVkGetPhysicalDeviceSurfacePresentModesKHR uintptr
    ptrVkCreateWin32SurfaceKHR                   uintptr

    ptrVkCreateSwapchainKHR      uintptr
    ptrVkDestroySwapchainKHR     uintptr
    ptrVkGetSwapchainImagesKHR   uintptr
    ptrVkAcquireNextImageKHR     uintptr
    ptrVkQueuePresentKHR         uintptr
    ptrVkCreateImageView         uintptr
    ptrVkDestroyImageView        uintptr
    ptrVkCreateRenderPass        uintptr
    ptrVkDestroyRenderPass       uintptr
    ptrVkCreateShaderModule      uintptr
    ptrVkDestroyShaderModule     uintptr
    ptrVkCreatePipelineLayout    uintptr
    ptrVkDestroyPipelineLayout   uintptr
    ptrVkCreateGraphicsPipelines uintptr
    ptrVkCreateComputePipelines  uintptr
    ptrVkDestroyPipeline         uintptr
    ptrVkCreateFramebuffer       uintptr
    ptrVkDestroyFramebuffer      uintptr
    ptrVkCreateCommandPool       uintptr
    ptrVkDestroyCommandPool      uintptr
    ptrVkAllocateCommandBuffers  uintptr
    ptrVkBeginCommandBuffer      uintptr
    ptrVkEndCommandBuffer        uintptr
    ptrVkResetCommandBuffer      uintptr
    ptrVkCmdBeginRenderPass      uintptr
    ptrVkCmdEndRenderPass        uintptr
    ptrVkCmdBindPipeline         uintptr
    ptrVkCmdSetViewport          uintptr
    ptrVkCmdSetScissor           uintptr
    ptrVkCmdDraw                 uintptr
    ptrVkCmdDispatch             uintptr
    ptrVkCmdPushConstants        uintptr
    ptrVkCmdBindDescriptorSets   uintptr
    ptrVkCmdPipelineBarrier      uintptr
    ptrVkCreateSemaphore         uintptr
    ptrVkDestroySemaphore        uintptr
    ptrVkCreateFence             uintptr
    ptrVkDestroyFence            uintptr
    ptrVkWaitForFences           uintptr
    ptrVkResetFences             uintptr
    ptrVkQueueSubmit             uintptr
    
    // Buffer and Memory
    ptrVkCreateBuffer                  uintptr
    ptrVkDestroyBuffer                 uintptr
    ptrVkGetBufferMemoryRequirements   uintptr
    ptrVkAllocateMemory                uintptr
    ptrVkFreeMemory                    uintptr
    ptrVkBindBufferMemory              uintptr
    ptrVkMapMemory                     uintptr
    ptrVkUnmapMemory                   uintptr
    ptrVkGetPhysicalDeviceMemoryProperties uintptr
    
    // Descriptors
    ptrVkCreateDescriptorSetLayout     uintptr
    ptrVkDestroyDescriptorSetLayout    uintptr
    ptrVkCreateDescriptorPool          uintptr
    ptrVkDestroyDescriptorPool         uintptr
    ptrVkAllocateDescriptorSets        uintptr
    ptrVkUpdateDescriptorSets          uintptr
)

// =============================================================================
// SPIR-V Shader Loading
// =============================================================================

// loadSPIRVFile loads a SPIR-V shader file and returns it as []uint32
func loadSPIRVFile(filename string) ([]uint32, error) {
    data, err := os.ReadFile(filename)
    if err != nil {
        return nil, fmt.Errorf("failed to read shader file %s: %w", filename, err)
    }

    // SPIR-V must be 4-byte aligned
    if len(data)%4 != 0 {
        return nil, fmt.Errorf("shader file %s has invalid size (must be multiple of 4)", filename)
    }

    // Convert bytes to uint32 slice
    code := make([]uint32, len(data)/4)
    for i := range code {
        code[i] = binary.LittleEndian.Uint32(data[i*4:])
    }

    return code, nil
}

// =============================================================================
// Utility Functions
// =============================================================================

func cstr(s string) *byte {
    b, _ := syscall.BytePtrFromString(s)
    return b
}

func check(result int32, msg string) {
    if result != VK_SUCCESS {
        errMsg := fmt.Sprintf("VK_ERROR: %s (code: %d)", msg, result)
        debugLog(errMsg)
        panic(errMsg)
    }
}

// =============================================================================
// Vulkan Loader
// =============================================================================

func loadVulkan() bool {
    debugLog("loadVulkan: Starting")
    var err error
    vulkanDLL, err = syscall.LoadLibrary("vulkan-1.dll")
    if err != nil {
        debugLog("loadVulkan: Failed to load vulkan-1.dll")
        fmt.Println("Failed to load vulkan-1.dll")
        return false
    }

    ptrVkGetInstanceProcAddr, _ = syscall.GetProcAddress(vulkanDLL, "vkGetInstanceProcAddr")
    if ptrVkGetInstanceProcAddr == 0 {
        debugLog("loadVulkan: Failed to get vkGetInstanceProcAddr")
        return false
    }

    ptrVkCreateInstance = vkGetInstanceProcAddr(0, "vkCreateInstance")
    debugLog("loadVulkan: Success")
    return true
}

func vkGetInstanceProcAddr(instance VkInstance, name string) uintptr {
    ret, _, _ := syscall.SyscallN(ptrVkGetInstanceProcAddr, uintptr(instance), uintptr(unsafe.Pointer(cstr(name))))
    return ret
}

func loadInstanceFunctions(instance VkInstance) {
    ptrVkDestroyInstance = vkGetInstanceProcAddr(instance, "vkDestroyInstance")
    ptrVkEnumeratePhysicalDevices = vkGetInstanceProcAddr(instance, "vkEnumeratePhysicalDevices")
    ptrVkGetPhysicalDeviceQueueFamilyProperties = vkGetInstanceProcAddr(instance, "vkGetPhysicalDeviceQueueFamilyProperties")
    ptrVkCreateDevice = vkGetInstanceProcAddr(instance, "vkCreateDevice")
    ptrVkDestroySurfaceKHR = vkGetInstanceProcAddr(instance, "vkDestroySurfaceKHR")
    ptrVkGetPhysicalDeviceSurfaceSupportKHR = vkGetInstanceProcAddr(instance, "vkGetPhysicalDeviceSurfaceSupportKHR")
    ptrVkGetPhysicalDeviceSurfaceCapabilitiesKHR = vkGetInstanceProcAddr(instance, "vkGetPhysicalDeviceSurfaceCapabilitiesKHR")
    ptrVkGetPhysicalDeviceSurfaceFormatsKHR = vkGetInstanceProcAddr(instance, "vkGetPhysicalDeviceSurfaceFormatsKHR")
    ptrVkGetPhysicalDeviceSurfacePresentModesKHR = vkGetInstanceProcAddr(instance, "vkGetPhysicalDeviceSurfacePresentModesKHR")
    ptrVkCreateWin32SurfaceKHR = vkGetInstanceProcAddr(instance, "vkCreateWin32SurfaceKHR")
}

func loadDeviceFunctions(device VkDevice) {
    ptrVkDestroyDevice = vkGetInstanceProcAddr(app.instance, "vkDestroyDevice")
    ptrVkGetDeviceQueue = vkGetInstanceProcAddr(app.instance, "vkGetDeviceQueue")
    ptrVkDeviceWaitIdle = vkGetInstanceProcAddr(app.instance, "vkDeviceWaitIdle")
    ptrVkCreateSwapchainKHR = vkGetInstanceProcAddr(app.instance, "vkCreateSwapchainKHR")
    ptrVkDestroySwapchainKHR = vkGetInstanceProcAddr(app.instance, "vkDestroySwapchainKHR")
    ptrVkGetSwapchainImagesKHR = vkGetInstanceProcAddr(app.instance, "vkGetSwapchainImagesKHR")
    ptrVkAcquireNextImageKHR = vkGetInstanceProcAddr(app.instance, "vkAcquireNextImageKHR")
    ptrVkQueuePresentKHR = vkGetInstanceProcAddr(app.instance, "vkQueuePresentKHR")
    ptrVkCreateImageView = vkGetInstanceProcAddr(app.instance, "vkCreateImageView")
    ptrVkDestroyImageView = vkGetInstanceProcAddr(app.instance, "vkDestroyImageView")
    ptrVkCreateRenderPass = vkGetInstanceProcAddr(app.instance, "vkCreateRenderPass")
    ptrVkDestroyRenderPass = vkGetInstanceProcAddr(app.instance, "vkDestroyRenderPass")
    ptrVkCreateShaderModule = vkGetInstanceProcAddr(app.instance, "vkCreateShaderModule")
    ptrVkDestroyShaderModule = vkGetInstanceProcAddr(app.instance, "vkDestroyShaderModule")
    ptrVkCreatePipelineLayout = vkGetInstanceProcAddr(app.instance, "vkCreatePipelineLayout")
    ptrVkDestroyPipelineLayout = vkGetInstanceProcAddr(app.instance, "vkDestroyPipelineLayout")
    ptrVkCreateGraphicsPipelines = vkGetInstanceProcAddr(app.instance, "vkCreateGraphicsPipelines")
    ptrVkCreateComputePipelines = vkGetInstanceProcAddr(app.instance, "vkCreateComputePipelines")
    ptrVkDestroyPipeline = vkGetInstanceProcAddr(app.instance, "vkDestroyPipeline")
    ptrVkCreateFramebuffer = vkGetInstanceProcAddr(app.instance, "vkCreateFramebuffer")
    ptrVkDestroyFramebuffer = vkGetInstanceProcAddr(app.instance, "vkDestroyFramebuffer")
    ptrVkCreateCommandPool = vkGetInstanceProcAddr(app.instance, "vkCreateCommandPool")
    ptrVkDestroyCommandPool = vkGetInstanceProcAddr(app.instance, "vkDestroyCommandPool")
    ptrVkAllocateCommandBuffers = vkGetInstanceProcAddr(app.instance, "vkAllocateCommandBuffers")
    ptrVkBeginCommandBuffer = vkGetInstanceProcAddr(app.instance, "vkBeginCommandBuffer")
    ptrVkEndCommandBuffer = vkGetInstanceProcAddr(app.instance, "vkEndCommandBuffer")
    ptrVkResetCommandBuffer = vkGetInstanceProcAddr(app.instance, "vkResetCommandBuffer")
    ptrVkCmdBeginRenderPass = vkGetInstanceProcAddr(app.instance, "vkCmdBeginRenderPass")
    ptrVkCmdEndRenderPass = vkGetInstanceProcAddr(app.instance, "vkCmdEndRenderPass")
    ptrVkCmdBindPipeline = vkGetInstanceProcAddr(app.instance, "vkCmdBindPipeline")
    ptrVkCmdSetViewport = vkGetInstanceProcAddr(app.instance, "vkCmdSetViewport")
    ptrVkCmdSetScissor = vkGetInstanceProcAddr(app.instance, "vkCmdSetScissor")
    ptrVkCmdDraw = vkGetInstanceProcAddr(app.instance, "vkCmdDraw")
    ptrVkCmdDispatch = vkGetInstanceProcAddr(app.instance, "vkCmdDispatch")
    ptrVkCmdPushConstants = vkGetInstanceProcAddr(app.instance, "vkCmdPushConstants")
    ptrVkCmdBindDescriptorSets = vkGetInstanceProcAddr(app.instance, "vkCmdBindDescriptorSets")
    ptrVkCmdPipelineBarrier = vkGetInstanceProcAddr(app.instance, "vkCmdPipelineBarrier")
    ptrVkCmdPipelineBarrier = vkGetInstanceProcAddr(app.instance, "vkCmdPipelineBarrier")
    ptrVkCreateSemaphore = vkGetInstanceProcAddr(app.instance, "vkCreateSemaphore")
    ptrVkDestroySemaphore = vkGetInstanceProcAddr(app.instance, "vkDestroySemaphore")
    ptrVkCreateFence = vkGetInstanceProcAddr(app.instance, "vkCreateFence")
    ptrVkDestroyFence = vkGetInstanceProcAddr(app.instance, "vkDestroyFence")
    ptrVkWaitForFences = vkGetInstanceProcAddr(app.instance, "vkWaitForFences")
    ptrVkResetFences = vkGetInstanceProcAddr(app.instance, "vkResetFences")
    ptrVkQueueSubmit = vkGetInstanceProcAddr(app.instance, "vkQueueSubmit")
    
    // Buffer and Memory
    ptrVkCreateBuffer = vkGetInstanceProcAddr(app.instance, "vkCreateBuffer")
    ptrVkDestroyBuffer = vkGetInstanceProcAddr(app.instance, "vkDestroyBuffer")
    ptrVkGetBufferMemoryRequirements = vkGetInstanceProcAddr(app.instance, "vkGetBufferMemoryRequirements")
    ptrVkAllocateMemory = vkGetInstanceProcAddr(app.instance, "vkAllocateMemory")
    ptrVkFreeMemory = vkGetInstanceProcAddr(app.instance, "vkFreeMemory")
    ptrVkBindBufferMemory = vkGetInstanceProcAddr(app.instance, "vkBindBufferMemory")
    ptrVkMapMemory = vkGetInstanceProcAddr(app.instance, "vkMapMemory")
    ptrVkUnmapMemory = vkGetInstanceProcAddr(app.instance, "vkUnmapMemory")
    ptrVkGetPhysicalDeviceMemoryProperties = vkGetInstanceProcAddr(app.instance, "vkGetPhysicalDeviceMemoryProperties")
    
    // Descriptors
    ptrVkCreateDescriptorSetLayout = vkGetInstanceProcAddr(app.instance, "vkCreateDescriptorSetLayout")
    ptrVkDestroyDescriptorSetLayout = vkGetInstanceProcAddr(app.instance, "vkDestroyDescriptorSetLayout")
    ptrVkCreateDescriptorPool = vkGetInstanceProcAddr(app.instance, "vkCreateDescriptorPool")
    ptrVkDestroyDescriptorPool = vkGetInstanceProcAddr(app.instance, "vkDestroyDescriptorPool")
    ptrVkAllocateDescriptorSets = vkGetInstanceProcAddr(app.instance, "vkAllocateDescriptorSets")
    ptrVkUpdateDescriptorSets = vkGetInstanceProcAddr(app.instance, "vkUpdateDescriptorSets")
}

// =============================================================================
// Vulkan Initialization
// =============================================================================

func createInstance() {
    debugLog("createInstance: Starting")
    appInfo := VkApplicationInfo{
        SType:              VK_STRUCTURE_TYPE_APPLICATION_INFO,
        PApplicationName:   cstr("Harmonograph"),
        ApplicationVersion: 1,
        PEngineName:        cstr("No Engine"),
        EngineVersion:      1,
        ApiVersion:         (1 << 22) | (4 << 12), // Vulkan 1.4
    }

    extensions := []*byte{
        cstr("VK_KHR_surface"),
        cstr("VK_KHR_win32_surface"),
    }

    createInfo := VkInstanceCreateInfo{
        SType:                   VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
        PApplicationInfo:        &appInfo,
        EnabledExtensionCount:   uint32(len(extensions)),
        PpEnabledExtensionNames: &extensions[0],
    }

    ret, _, _ := syscall.SyscallN(ptrVkCreateInstance,
        uintptr(unsafe.Pointer(&createInfo)), 0,
        uintptr(unsafe.Pointer(&app.instance)))
    check(int32(ret), "Failed to create Vulkan instance")
    debugLog("createInstance: Success")

    loadInstanceFunctions(app.instance)
}

func createSurface() {
    debugLog("createSurface: Starting")
    createInfo := VkWin32SurfaceCreateInfoKHR{
        SType:     VK_STRUCTURE_TYPE_WIN32_SURFACE_CREATE_INFO_KHR,
        Hinstance: app.hInstance,
        Hwnd:      app.hwnd,
    }

    ret, _, _ := syscall.SyscallN(ptrVkCreateWin32SurfaceKHR,
        uintptr(app.instance),
        uintptr(unsafe.Pointer(&createInfo)), 0,
        uintptr(unsafe.Pointer(&app.surface)))
    check(int32(ret), "Failed to create window surface")
    debugLog("createSurface: Success")
}

func pickPhysicalDevice() {
    debugLog("pickPhysicalDevice: Starting")
    var deviceCount uint32
    syscall.SyscallN(ptrVkEnumeratePhysicalDevices, uintptr(app.instance),
        uintptr(unsafe.Pointer(&deviceCount)), 0)

    if deviceCount == 0 {
        debugLog("pickPhysicalDevice: No devices found")
        panic("No Vulkan devices found")
    }

    debugLog(fmt.Sprintf("pickPhysicalDevice: Found %d devices", deviceCount))

    devices := make([]VkPhysicalDevice, deviceCount)
    syscall.SyscallN(ptrVkEnumeratePhysicalDevices, uintptr(app.instance),
        uintptr(unsafe.Pointer(&deviceCount)),
        uintptr(unsafe.Pointer(&devices[0])))

    app.physicalDevice = devices[0]

    var queueFamilyCount uint32
    syscall.SyscallN(ptrVkGetPhysicalDeviceQueueFamilyProperties,
        uintptr(app.physicalDevice),
        uintptr(unsafe.Pointer(&queueFamilyCount)), 0)

    queueFamilies := make([]VkQueueFamilyProperties, queueFamilyCount)
    syscall.SyscallN(ptrVkGetPhysicalDeviceQueueFamilyProperties,
        uintptr(app.physicalDevice),
        uintptr(unsafe.Pointer(&queueFamilyCount)),
        uintptr(unsafe.Pointer(&queueFamilies[0])))

    for i := uint32(0); i < queueFamilyCount; i++ {
        if queueFamilies[i].QueueFlags&VK_QUEUE_GRAPHICS_BIT != 0 {
            app.graphicsFamily = i
        }

        var presentSupport uint32
        syscall.SyscallN(ptrVkGetPhysicalDeviceSurfaceSupportKHR,
            uintptr(app.physicalDevice), uintptr(i), uintptr(app.surface),
            uintptr(unsafe.Pointer(&presentSupport)))

        if presentSupport != 0 {
            app.presentFamily = i
        }
    }
    debugLog(fmt.Sprintf("pickPhysicalDevice: Graphics family=%d, Present family=%d", app.graphicsFamily, app.presentFamily))
}

func createLogicalDevice() {
    debugLog("createLogicalDevice: Starting")
    queuePriority := float32(1.0)
    queueCreateInfos := []VkDeviceQueueCreateInfo{{
        SType:            VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
        QueueFamilyIndex: app.graphicsFamily,
        QueueCount:       1,
        PQueuePriorities: &queuePriority,
    }}

    if app.graphicsFamily != app.presentFamily {
        queueCreateInfos = append(queueCreateInfos, VkDeviceQueueCreateInfo{
            SType:            VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
            QueueFamilyIndex: app.presentFamily,
            QueueCount:       1,
            PQueuePriorities: &queuePriority,
        })
    }

    deviceExtensions := []*byte{cstr("VK_KHR_swapchain")}
    createInfo := VkDeviceCreateInfo{
        SType:                   VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO,
        QueueCreateInfoCount:    uint32(len(queueCreateInfos)),
        PQueueCreateInfos:       &queueCreateInfos[0],
        EnabledExtensionCount:   1,
        PpEnabledExtensionNames: &deviceExtensions[0],
    }

    ret, _, _ := syscall.SyscallN(ptrVkCreateDevice,
        uintptr(app.physicalDevice),
        uintptr(unsafe.Pointer(&createInfo)), 0,
        uintptr(unsafe.Pointer(&app.device)))
    check(int32(ret), "Failed to create logical device")

    loadDeviceFunctions(app.device)

    syscall.SyscallN(ptrVkGetDeviceQueue, uintptr(app.device),
        uintptr(app.graphicsFamily), 0, uintptr(unsafe.Pointer(&app.graphicsQueue)))
    syscall.SyscallN(ptrVkGetDeviceQueue, uintptr(app.device),
        uintptr(app.presentFamily), 0, uintptr(unsafe.Pointer(&app.presentQueue)))
    
    debugLog("createLogicalDevice: Success")
}

func createSwapChain() {
    var caps VkSurfaceCapabilitiesKHR
    syscall.SyscallN(ptrVkGetPhysicalDeviceSurfaceCapabilitiesKHR,
        uintptr(app.physicalDevice), uintptr(app.surface),
        uintptr(unsafe.Pointer(&caps)))

    var formatCount uint32
    syscall.SyscallN(ptrVkGetPhysicalDeviceSurfaceFormatsKHR,
        uintptr(app.physicalDevice), uintptr(app.surface),
        uintptr(unsafe.Pointer(&formatCount)), 0)

    formats := make([]VkSurfaceFormatKHR, formatCount)
    syscall.SyscallN(ptrVkGetPhysicalDeviceSurfaceFormatsKHR,
        uintptr(app.physicalDevice), uintptr(app.surface),
        uintptr(unsafe.Pointer(&formatCount)),
        uintptr(unsafe.Pointer(&formats[0])))

    var modeCount uint32
    syscall.SyscallN(ptrVkGetPhysicalDeviceSurfacePresentModesKHR,
        uintptr(app.physicalDevice), uintptr(app.surface),
        uintptr(unsafe.Pointer(&modeCount)), 0)

    modes := make([]uint32, modeCount)
    syscall.SyscallN(ptrVkGetPhysicalDeviceSurfacePresentModesKHR,
        uintptr(app.physicalDevice), uintptr(app.surface),
        uintptr(unsafe.Pointer(&modeCount)),
        uintptr(unsafe.Pointer(&modes[0])))

    surfaceFormat := formats[0]
    for _, f := range formats {
        if f.Format == VK_FORMAT_B8G8R8A8_SRGB && f.ColorSpace == VK_COLOR_SPACE_SRGB_NONLINEAR_KHR {
            surfaceFormat = f
            break
        }
    }

    presentMode := uint32(VK_PRESENT_MODE_FIFO_KHR)
    for _, m := range modes {
        if m == VK_PRESENT_MODE_MAILBOX_KHR {
            presentMode = VK_PRESENT_MODE_MAILBOX_KHR
            break
        }
    }

    extent := caps.CurrentExtent
    if extent.Width == 0xFFFFFFFF {
        extent = VkExtent2D{WIDTH, HEIGHT}
    }

    imageCount := caps.MinImageCount + 1
    if caps.MaxImageCount > 0 && imageCount > caps.MaxImageCount {
        imageCount = caps.MaxImageCount
    }

    createInfo := VkSwapchainCreateInfoKHR{
        SType:            VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR,
        Surface:          app.surface,
        MinImageCount:    imageCount,
        ImageFormat:      surfaceFormat.Format,
        ImageColorSpace:  surfaceFormat.ColorSpace,
        ImageExtent:      extent,
        ImageArrayLayers: 1,
        ImageUsage:       VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT,
        PreTransform:     caps.CurrentTransform,
        CompositeAlpha:   VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR,
        PresentMode:      presentMode,
        Clipped:          1,
    }

    queueFamilyIndices := []uint32{app.graphicsFamily, app.presentFamily}
    if app.graphicsFamily != app.presentFamily {
        createInfo.ImageSharingMode = VK_SHARING_MODE_CONCURRENT
        createInfo.QueueFamilyIndexCount = 2
        createInfo.PQueueFamilyIndices = &queueFamilyIndices[0]
    } else {
        createInfo.ImageSharingMode = VK_SHARING_MODE_EXCLUSIVE
    }

    ret, _, _ := syscall.SyscallN(ptrVkCreateSwapchainKHR,
        uintptr(app.device), uintptr(unsafe.Pointer(&createInfo)), 0,
        uintptr(unsafe.Pointer(&app.swapChain)))
    check(int32(ret), "Failed to create swap chain")

    app.swapChainImageFormat = surfaceFormat.Format
    app.swapChainExtent = extent

    syscall.SyscallN(ptrVkGetSwapchainImagesKHR, uintptr(app.device),
        uintptr(app.swapChain), uintptr(unsafe.Pointer(&imageCount)), 0)

    app.swapChainImages = make([]VkImage, imageCount)
    syscall.SyscallN(ptrVkGetSwapchainImagesKHR, uintptr(app.device),
        uintptr(app.swapChain), uintptr(unsafe.Pointer(&imageCount)),
        uintptr(unsafe.Pointer(&app.swapChainImages[0])))
}

func createImageViews() {
    app.swapChainImageViews = make([]VkImageView, len(app.swapChainImages))

    for i, image := range app.swapChainImages {
        createInfo := VkImageViewCreateInfo{
            SType:    VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO,
            Image:    image,
            ViewType: VK_IMAGE_VIEW_TYPE_2D,
            Format:   app.swapChainImageFormat,
            Components: VkComponentMapping{
                VK_COMPONENT_SWIZZLE_IDENTITY,
                VK_COMPONENT_SWIZZLE_IDENTITY,
                VK_COMPONENT_SWIZZLE_IDENTITY,
                VK_COMPONENT_SWIZZLE_IDENTITY,
            },
            SubresourceRange: VkImageSubresourceRange{
                AspectMask: VK_IMAGE_ASPECT_COLOR_BIT,
                LevelCount: 1, LayerCount: 1,
            },
        }

        ret, _, _ := syscall.SyscallN(ptrVkCreateImageView, uintptr(app.device),
            uintptr(unsafe.Pointer(&createInfo)), 0,
            uintptr(unsafe.Pointer(&app.swapChainImageViews[i])))
        check(int32(ret), "Failed to create image view")
    }
}

func createRenderPass() {
    colorAttachment := VkAttachmentDescription{
        Format:         app.swapChainImageFormat,
        Samples:        1,
        LoadOp:         VK_ATTACHMENT_LOAD_OP_CLEAR,
        StoreOp:        VK_ATTACHMENT_STORE_OP_STORE,
        StencilLoadOp:  VK_ATTACHMENT_STORE_OP_DONT_CARE,
        StencilStoreOp: VK_ATTACHMENT_STORE_OP_DONT_CARE,
        InitialLayout:  VK_IMAGE_LAYOUT_UNDEFINED,
        FinalLayout:    VK_IMAGE_LAYOUT_PRESENT_SRC_KHR,
    }

    colorAttachmentRef := VkAttachmentReference{
        Layout: VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
    }

    subpass := VkSubpassDescription{
        PipelineBindPoint:    VK_PIPELINE_BIND_POINT_GRAPHICS,
        ColorAttachmentCount: 1,
        PColorAttachments:    &colorAttachmentRef,
    }

    dependency := VkSubpassDependency{
        SrcSubpass:    VK_SUBPASS_EXTERNAL,
        SrcStageMask:  VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT,
        DstStageMask:  VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT,
        DstAccessMask: VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT,
    }

    renderPassInfo := VkRenderPassCreateInfo{
        SType:           VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO,
        AttachmentCount: 1, PAttachments: &colorAttachment,
        SubpassCount: 1, PSubpasses: &subpass,
        DependencyCount: 1, PDependencies: &dependency,
    }

    ret, _, _ := syscall.SyscallN(ptrVkCreateRenderPass, uintptr(app.device),
        uintptr(unsafe.Pointer(&renderPassInfo)), 0,
        uintptr(unsafe.Pointer(&app.renderPass)))
    check(int32(ret), "Failed to create render pass")
}

func createShaderModule(code []uint32) VkShaderModule {
    createInfo := VkShaderModuleCreateInfo{
        SType:    VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO,
        CodeSize: uintptr(len(code) * 4),
        PCode:    &code[0],
    }

    var shaderModule VkShaderModule
    ret, _, _ := syscall.SyscallN(ptrVkCreateShaderModule, uintptr(app.device),
        uintptr(unsafe.Pointer(&createInfo)), 0,
        uintptr(unsafe.Pointer(&shaderModule)))
    check(int32(ret), "Failed to create shader module")
    return shaderModule
}

// =============================================================================
// Buffer and Memory Management
// =============================================================================

func findMemoryType(typeFilter uint32, properties uint32) uint32 {
    debugLog(fmt.Sprintf("findMemoryType: Called with typeFilter=%x, properties=%x", typeFilter, properties))
    debugLog(fmt.Sprintf("findMemoryType: typeFilter bits - bit0=%x, bit1=%x, bit2=%x, bit3=%x, bit4=%x", 
        typeFilter&1, typeFilter&2, typeFilter&4, typeFilter&8, typeFilter&16))
    
    var memProps VkPhysicalDeviceMemoryProperties
    ret, _, _ := syscall.SyscallN(ptrVkGetPhysicalDeviceMemoryProperties, uintptr(app.physicalDevice),
        uintptr(unsafe.Pointer(&memProps)))
    
    debugLog(fmt.Sprintf("findMemoryType: vkGetPhysicalDeviceMemoryProperties ret=%d, count=%d", ret, memProps.MemoryTypeCount))
    
    for i := uint32(0); i < memProps.MemoryTypeCount; i++ {
        flags := memProps.MemoryTypes[i].PropertyFlags
        heapIdx := memProps.MemoryTypes[i].HeapIndex
        
        mask := uint32(1 << i)
        typeFilterMatch := (typeFilter & mask) != 0
        propMatch := (flags & properties) == properties
        
        debugLog(fmt.Sprintf("findMemoryType: Type[%d] flags=%x mask=%x typeFilter=%x typeFilter&mask=%x heapIdx=%d | Match=%v", 
            i, flags, mask, typeFilter, typeFilter&mask, heapIdx, typeFilterMatch))
        
        if typeFilterMatch && propMatch {
            debugLog(fmt.Sprintf("findMemoryType: Found suitable type %d", i))
            return i
        }
    }
    debugLog("findMemoryType: No suitable memory type found!")
    return 0
}

func createBuffer(size uintptr, usage uint32, properties uint32) (VkBuffer, VkDeviceMemory) {
    debugLog(fmt.Sprintf("createBuffer: Starting, size=%d, usage=%x, properties=%x", size, usage, properties))
    createInfo := VkBufferCreateInfo{
        SType:       VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO,
        Size:        size,
        Usage:       usage,
        SharingMode: VK_SHARING_MODE_EXCLUSIVE,
    }
    
    var buffer VkBuffer
    ret, _, _ := syscall.SyscallN(ptrVkCreateBuffer, uintptr(app.device),
        uintptr(unsafe.Pointer(&createInfo)), 0, uintptr(unsafe.Pointer(&buffer)))
    check(int32(ret), "Failed to create buffer")
    debugLog(fmt.Sprintf("createBuffer: Buffer created, buffer=%v", buffer))
    
    var memReqs VkMemoryRequirements
    ret, _, _ = syscall.SyscallN(ptrVkGetBufferMemoryRequirements, uintptr(app.device),
        uintptr(buffer), uintptr(unsafe.Pointer(&memReqs)))
    debugLog(fmt.Sprintf("createBuffer: vkGetBufferMemoryRequirements ret=%d, size=%d, alignment=%d, typeBits=%x", ret, memReqs.Size, memReqs.Alignment, memReqs.MemoryTypeBits))
    
    memTypeIdx := findMemoryType(memReqs.MemoryTypeBits, properties)
    debugLog(fmt.Sprintf("createBuffer: Selected memory type index=%d", memTypeIdx))
    
    allocInfo := VkAllocateMemoryInfo{
        SType:           VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
        AllocationSize:  memReqs.Size,
        MemoryTypeIndex: memTypeIdx,
    }
    
    var memory VkDeviceMemory
    ret, _, _ = syscall.SyscallN(ptrVkAllocateMemory, uintptr(app.device),
        uintptr(unsafe.Pointer(&allocInfo)), 0, uintptr(unsafe.Pointer(&memory)))
    check(int32(ret), "Failed to allocate buffer memory")
    debugLog("createBuffer: Memory allocated")
    
    ret, _, _ = syscall.SyscallN(ptrVkBindBufferMemory, uintptr(app.device),
        uintptr(buffer), uintptr(memory), 0)
    debugLog(fmt.Sprintf("createBuffer: vkBindBufferMemory ret=%d", ret))
    debugLog("createBuffer: Success")
    
    return buffer, memory
}

func createStorageBuffers() {
    debugPrint("createStorageBuffers: Starting")
    // Position buffer
    debugPrint("createStorageBuffers: Creating position buffer")
    app.positionBuffer, app.positionBufferMem = createBuffer(uintptr(NUM_HARMONOGRAPH_POINTS*16),
        VK_BUFFER_USAGE_STORAGE_BUFFER_BIT,
        VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT|VK_MEMORY_PROPERTY_HOST_COHERENT_BIT)
    debugPrint("createStorageBuffers: Position buffer created")
    
    // Color buffer
    debugPrint("createStorageBuffers: Creating color buffer")
    app.colorBuffer, app.colorBufferMem = createBuffer(uintptr(NUM_HARMONOGRAPH_POINTS*16),
        VK_BUFFER_USAGE_STORAGE_BUFFER_BIT,
        VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT|VK_MEMORY_PROPERTY_HOST_COHERENT_BIT)
    debugPrint("createStorageBuffers: Color buffer created")
    
    // Params buffer
    debugPrint("createStorageBuffers: Creating params buffer")
    app.paramBuffer, app.paramBufferMemory = createBuffer(uintptr(unsafe.Sizeof(ComputeParams{})),
        VK_BUFFER_USAGE_UNIFORM_BUFFER_BIT|VK_BUFFER_USAGE_STORAGE_BUFFER_BIT,
        VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT|VK_MEMORY_PROPERTY_HOST_COHERENT_BIT)
    debugPrint("createStorageBuffers: Params buffer created")
    debugPrint("createStorageBuffers: Success")
}

func initializeParamBuffer() {
    debugPrint("initializeParamBuffer: Starting")
    
    // Initialize parameters for harmonograph computation
    params := ComputeParams{
        MaxNum: NUM_HARMONOGRAPH_POINTS,
        DT:     0.01,
        Scale:  0.3,
        Pad0:   0,
        // Oscillator 1: slow large circle
        A1: 1.0, F1: 1.0, P1: 0.0, D1: 0.0,
        // Oscillator 2: faster small circle
        A2: 0.6, F2: 3.0, P2: 0.5, D2: 0.001,
        // Oscillator 3: vertical motion
        A3: 1.0, F3: 2.0, P3: 0.0, D3: 0.001,
        // Oscillator 4: additional modulation
        A4: 0.5, F4: 5.0, P4: 0.25, D4: 0.002,
    }
    
    // Map memory and copy parameters
    var mappedPtr uintptr
    ret, _, _ := syscall.SyscallN(ptrVkMapMemory, uintptr(app.device),
        uintptr(app.paramBufferMemory), 0, uintptr(unsafe.Sizeof(params)), 0,
        uintptr(unsafe.Pointer(&mappedPtr)))
    check(int32(ret), "Failed to map param buffer memory")
    
    // Copy the struct to mapped memory
    paramsBytes := (*[unsafe.Sizeof(ComputeParams{})]byte)(unsafe.Pointer(&params))[:]
    targetBytes := (*[unsafe.Sizeof(ComputeParams{})]byte)(unsafe.Pointer(mappedPtr))[:]
    copy(targetBytes, paramsBytes)
    
    syscall.SyscallN(ptrVkUnmapMemory, uintptr(app.device), uintptr(app.paramBufferMemory))
    
    debugPrint("initializeParamBuffer: Success")
}

func createGraphicsPipeline() {
    debugPrint("createGraphicsPipeline: Starting")
    // Load shaders from SPIR-V files at runtime
    vertShaderCode, err := loadSPIRVFile("hello_vert.spv")
    if err != nil {
        panic(err)
    }
    fragShaderCode, err := loadSPIRVFile("hello_frag.spv")
    if err != nil {
        panic(err)
    }

    fmt.Printf("Loaded vertex shader: %d bytes\n", len(vertShaderCode)*4)
    fmt.Printf("Loaded fragment shader: %d bytes\n", len(fragShaderCode)*4)
    debugPrint("createGraphicsPipeline: Shaders loaded")

    vertShaderModule := createShaderModule(vertShaderCode)
    fragShaderModule := createShaderModule(fragShaderCode)

    mainName := cstr("main")
    shaderStages := []VkPipelineShaderStageCreateInfo{
        {
            SType:  VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
            Stage:  VK_SHADER_STAGE_VERTEX_BIT,
            Module: vertShaderModule,
            PName:  mainName,
        },
        {
            SType:  VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
            Stage:  VK_SHADER_STAGE_FRAGMENT_BIT,
            Module: fragShaderModule,
            PName:  mainName,
        },
    }

    vertexInputInfo := VkPipelineVertexInputStateCreateInfo{
        SType: VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO,
    }

    inputAssembly := VkPipelineInputAssemblyStateCreateInfo{
        SType:    VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO,
        Topology: VK_PRIMITIVE_TOPOLOGY_POINT_LIST,
    }

    viewportState := VkPipelineViewportStateCreateInfo{
        SType:         VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO,
        ViewportCount: 1,
        ScissorCount:  1,
    }

    rasterizer := VkPipelineRasterizationStateCreateInfo{
        SType:       VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO,
        PolygonMode: VK_POLYGON_MODE_FILL,
        LineWidth:   1.0,
        CullMode:    VK_CULL_MODE_NONE,
        FrontFace:   VK_FRONT_FACE_CLOCKWISE,
    }

    multisampling := VkPipelineMultisampleStateCreateInfo{
        SType:                VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO,
        RasterizationSamples: 1,
    }

    colorBlendAttachment := VkPipelineColorBlendAttachmentState{
        ColorWriteMask: VK_COLOR_COMPONENT_R_BIT | VK_COLOR_COMPONENT_G_BIT |
            VK_COLOR_COMPONENT_B_BIT | VK_COLOR_COMPONENT_A_BIT,
    }

    colorBlending := VkPipelineColorBlendStateCreateInfo{
        SType:           VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO,
        AttachmentCount: 1,
        PAttachments:    &colorBlendAttachment,
    }

    dynamicStates := []uint32{VK_DYNAMIC_STATE_VIEWPORT, VK_DYNAMIC_STATE_SCISSOR}
    dynamicState := VkPipelineDynamicStateCreateInfo{
        SType:             VK_STRUCTURE_TYPE_PIPELINE_DYNAMIC_STATE_CREATE_INFO,
        DynamicStateCount: 2,
        PDynamicStates:    &dynamicStates[0],
    }

    // Push constant range for time and resolution
    pushConstantRange := VkPushConstantRange{
        StageFlags: VK_SHADER_STAGE_FRAGMENT_BIT,
        Offset:     0,
        Size:       uint32(unsafe.Sizeof(PushConstants{})),
    }

    setLayouts := []VkDescriptorSetLayout{app.descriptorSetLayout}
    pipelineLayoutInfo := VkPipelineLayoutCreateInfo{
        SType:                  VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO,
        SetLayoutCount:         1,
        PSetLayouts:            uintptr(unsafe.Pointer(&setLayouts[0])),
        PushConstantRangeCount: 1,
        PPushConstantRanges:    &pushConstantRange,
    }

    ret, _, _ := syscall.SyscallN(ptrVkCreatePipelineLayout, uintptr(app.device),
        uintptr(unsafe.Pointer(&pipelineLayoutInfo)), 0,
        uintptr(unsafe.Pointer(&app.pipelineLayout)))
    check(int32(ret), "Failed to create pipeline layout")

    pipelineInfo := VkGraphicsPipelineCreateInfo{
        SType:               VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO,
        StageCount:          2,
        PStages:             &shaderStages[0],
        PVertexInputState:   &vertexInputInfo,
        PInputAssemblyState: &inputAssembly,
        PViewportState:      &viewportState,
        PRasterizationState: &rasterizer,
        PMultisampleState:   &multisampling,
        PColorBlendState:    &colorBlending,
        PDynamicState:       &dynamicState,
        Layout:              app.pipelineLayout,
        RenderPass:          app.renderPass,
        BasePipelineIndex:   -1,
    }

    ret, _, _ = syscall.SyscallN(ptrVkCreateGraphicsPipelines, uintptr(app.device), 0, 1,
        uintptr(unsafe.Pointer(&pipelineInfo)), 0,
        uintptr(unsafe.Pointer(&app.graphicsPipeline)))
    check(int32(ret), "Failed to create graphics pipeline")

    syscall.SyscallN(ptrVkDestroyShaderModule, uintptr(app.device), uintptr(fragShaderModule), 0)
    syscall.SyscallN(ptrVkDestroyShaderModule, uintptr(app.device), uintptr(vertShaderModule), 0)
    debugPrint("createGraphicsPipeline: Success")
}

func createDescriptorSetLayout() {
    debugPrint("createDescriptorSetLayout: Starting")
    bindings := []VkDescriptorSetLayoutBinding{
        {
            Binding:         0,
            DescriptorType:  VK_DESCRIPTOR_TYPE_STORAGE_BUFFER,
            DescriptorCount: 1,
            StageFlags:      VK_SHADER_STAGE_COMPUTE_BIT | VK_SHADER_STAGE_VERTEX_BIT,
        },
        {
            Binding:         1,
            DescriptorType:  VK_DESCRIPTOR_TYPE_STORAGE_BUFFER,
            DescriptorCount: 1,
            StageFlags:      VK_SHADER_STAGE_COMPUTE_BIT | VK_SHADER_STAGE_FRAGMENT_BIT,
        },
        {
            Binding:         2,
            DescriptorType:  VK_DESCRIPTOR_TYPE_STORAGE_BUFFER,
            DescriptorCount: 1,
            StageFlags:      VK_SHADER_STAGE_COMPUTE_BIT,
        },
    }
    
    createInfo := VkDescriptorSetLayoutCreateInfo{
        SType:        VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
        BindingCount: uint32(len(bindings)),
        PBindings:    &bindings[0],
    }
    
    ret, _, _ := syscall.SyscallN(ptrVkCreateDescriptorSetLayout, uintptr(app.device),
        uintptr(unsafe.Pointer(&createInfo)), 0,
        uintptr(unsafe.Pointer(&app.descriptorSetLayout)))
    check(int32(ret), "Failed to create descriptor set layout")
    debugPrint("createDescriptorSetLayout: Success")
}

func createDescriptorPool() {
    debugPrint("createDescriptorPool: Starting")
    poolSizes := []VkDescriptorPoolSize{
        {
            DescriptorType:  VK_DESCRIPTOR_TYPE_STORAGE_BUFFER,
            DescriptorCount: 3,
        },
    }
    
    createInfo := VkDescriptorPoolCreateInfo{
        SType:         VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO,
        MaxSets:       1,
        PoolSizeCount: uint32(len(poolSizes)),
        PPoolSizes:    &poolSizes[0],
    }
    
    ret, _, _ := syscall.SyscallN(ptrVkCreateDescriptorPool, uintptr(app.device),
        uintptr(unsafe.Pointer(&createInfo)), 0,
        uintptr(unsafe.Pointer(&app.descriptorPool)))
    check(int32(ret), "Failed to create descriptor pool")
    debugPrint("createDescriptorPool: Success")
}

func allocateDescriptorSets() {
    debugPrint("allocateDescriptorSets: Starting")
    allocInfo := VkDescriptorSetAllocateInfo{
        SType:              VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO,
        DescriptorPool:     app.descriptorPool,
        DescriptorSetCount: 1,
        PSetLayouts:        uintptr(unsafe.Pointer(&app.descriptorSetLayout)),
    }
    
    ret, _, _ := syscall.SyscallN(ptrVkAllocateDescriptorSets, uintptr(app.device),
        uintptr(unsafe.Pointer(&allocInfo)), uintptr(unsafe.Pointer(&app.descriptorSet)))
    check(int32(ret), "Failed to allocate descriptor sets")
    debugPrint("allocateDescriptorSets: Success")
}

func updateDescriptorSets() {
    debugPrint("updateDescriptorSets: Starting")
    bufferInfos := []VkDescriptorBufferInfo{
        {Buffer: uintptr(app.positionBuffer), Offset: 0, Range: uintptr(NUM_HARMONOGRAPH_POINTS * 16)},
        {Buffer: uintptr(app.colorBuffer), Offset: 0, Range: uintptr(NUM_HARMONOGRAPH_POINTS * 16)},
        {Buffer: uintptr(app.paramBuffer), Offset: 0, Range: uintptr(unsafe.Sizeof(ComputeParams{}))},
    }
    
    writes := []VkWriteDescriptorSet{
        {
            SType:            VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET,
            DstSet:           uintptr(app.descriptorSet),
            DstBinding:       0,
            DescriptorCount:  1,
            DescriptorType:   VK_DESCRIPTOR_TYPE_STORAGE_BUFFER,
            PBufferInfo:      &bufferInfos[0],
        },
        {
            SType:            VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET,
            DstSet:           uintptr(app.descriptorSet),
            DstBinding:       1,
            DescriptorCount:  1,
            DescriptorType:   VK_DESCRIPTOR_TYPE_STORAGE_BUFFER,
            PBufferInfo:      &bufferInfos[1],
        },
        {
            SType:            VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET,
            DstSet:           uintptr(app.descriptorSet),
            DstBinding:       2,
            DescriptorCount:  1,
            DescriptorType:   VK_DESCRIPTOR_TYPE_STORAGE_BUFFER,
            PBufferInfo:      &bufferInfos[2],
        },
    }
    
    syscall.SyscallN(ptrVkUpdateDescriptorSets, uintptr(app.device), uintptr(len(writes)),
        uintptr(unsafe.Pointer(&writes[0])), 0, 0)
    debugPrint("updateDescriptorSets: Success")
}

func createComputePipeline() {
    debugPrint("createComputePipeline: Starting")
    // Load compute shader
    computeShaderCode, err := loadSPIRVFile("hello_comp.spv")
    if err != nil {
        panic(err)
    }
    
    fmt.Printf("Loaded compute shader: %d bytes\n", len(computeShaderCode)*4)
    debugPrint("createComputePipeline: Shader loaded")
    
    computeShaderModule := createShaderModule(computeShaderCode)
    
    mainName := cstr("main")
    shaderStage := VkPipelineShaderStageCreateInfo{
        SType:  VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
        Stage:  VK_SHADER_STAGE_COMPUTE_BIT,
        Module: computeShaderModule,
        PName:  mainName,
    }
    
    pipelineLayoutInfo := VkPipelineLayoutCreateInfo{
        SType:          VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO,
        SetLayoutCount: 1,
        PSetLayouts:    uintptr(unsafe.Pointer(&app.descriptorSetLayout)),
    }
    
    ret, _, _ := syscall.SyscallN(ptrVkCreatePipelineLayout, uintptr(app.device),
        uintptr(unsafe.Pointer(&pipelineLayoutInfo)), 0,
        uintptr(unsafe.Pointer(&app.computePipelineLayout)))
    check(int32(ret), "Failed to create compute pipeline layout")
    debugPrint("createComputePipeline: Pipeline layout created")
    
    pipelineInfo := VkComputePipelineCreateInfo{
        SType:  VK_STRUCTURE_TYPE_COMPUTE_PIPELINE_CREATE_INFO,
        Stage:  shaderStage,
        Layout: app.computePipelineLayout,
    }
    
    ret, _, _ = syscall.SyscallN(ptrVkCreateComputePipelines, uintptr(app.device), 0, 1,
        uintptr(unsafe.Pointer(&pipelineInfo)), 0,
        uintptr(unsafe.Pointer(&app.computePipeline)))
    check(int32(ret), "Failed to create compute pipeline")
    
    syscall.SyscallN(ptrVkDestroyShaderModule, uintptr(app.device), uintptr(computeShaderModule), 0)
    debugPrint("createComputePipeline: Success")
}

func createComputeCommandBuffer() {
    debugPrint("createComputeCommandBuffer: Starting")
    allocInfo := VkCommandBufferAllocateInfo{
        SType:              VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
        CommandPool:        app.commandPool,
        Level:              VK_COMMAND_BUFFER_LEVEL_PRIMARY,
        CommandBufferCount: 1,
    }
    ret, _, _ := syscall.SyscallN(ptrVkAllocateCommandBuffers, uintptr(app.device),
        uintptr(unsafe.Pointer(&allocInfo)), uintptr(unsafe.Pointer(&app.computeCommandBuffer)))
    check(int32(ret), "Failed to allocate compute command buffer")
    debugPrint("createComputeCommandBuffer: Success")
}

func recordComputeCommandBuffer() {
    debugPrint("recordComputeCommandBuffer: Starting")
    beginInfo := VkCommandBufferBeginInfo{SType: VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO}
    ret, _, _ := syscall.SyscallN(ptrVkBeginCommandBuffer, uintptr(app.computeCommandBuffer),
        uintptr(unsafe.Pointer(&beginInfo)))
    check(int32(ret), "Failed to begin compute command buffer")
    
    syscall.SyscallN(ptrVkCmdBindPipeline, uintptr(app.computeCommandBuffer),
        VK_PIPELINE_BIND_POINT_COMPUTE, uintptr(app.computePipeline))
    
    syscall.SyscallN(ptrVkCmdBindDescriptorSets, uintptr(app.computeCommandBuffer),
        VK_PIPELINE_BIND_POINT_COMPUTE, uintptr(app.computePipelineLayout), 0, 1,
        uintptr(unsafe.Pointer(&app.descriptorSet)), 0, uintptr(0))
    
    // Dispatch compute shader threads
    // NUM_HARMONOGRAPH_POINTS threads with local_size_x = 256
    threadsPerGroup := uint32(256)
    numGroups := (NUM_HARMONOGRAPH_POINTS + threadsPerGroup - 1) / threadsPerGroup
    syscall.SyscallN(ptrVkCmdDispatch, uintptr(app.computeCommandBuffer), uintptr(numGroups), 1, 1)
    
    // Insert memory barrier to ensure compute writes are visible to graphics reads
    posBarrier := VkBufferMemoryBarrier{
        SType:               VK_STRUCTURE_TYPE_BUFFER_MEMORY_BARRIER,
        SrcAccessMask:       VK_ACCESS_SHADER_WRITE_BIT,
        DstAccessMask:       VK_ACCESS_SHADER_READ_BIT,
        SrcQueueFamilyIndex: 0xFFFFFFFF,
        DstQueueFamilyIndex: 0xFFFFFFFF,
        Buffer:              uintptr(app.positionBuffer),
        Offset:              0,
        Size:                uintptr(NUM_HARMONOGRAPH_POINTS * 16),
    }
    
    colBarrier := VkBufferMemoryBarrier{
        SType:               VK_STRUCTURE_TYPE_BUFFER_MEMORY_BARRIER,
        SrcAccessMask:       VK_ACCESS_SHADER_WRITE_BIT,
        DstAccessMask:       VK_ACCESS_SHADER_READ_BIT,
        SrcQueueFamilyIndex: 0xFFFFFFFF,
        DstQueueFamilyIndex: 0xFFFFFFFF,
        Buffer:              uintptr(app.colorBuffer),
        Offset:              0,
        Size:                uintptr(NUM_HARMONOGRAPH_POINTS * 16),
    }
    
    barriers := [2]VkBufferMemoryBarrier{posBarrier, colBarrier}
    syscall.SyscallN(ptrVkCmdPipelineBarrier, uintptr(app.computeCommandBuffer),
        VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT, VK_PIPELINE_STAGE_VERTEX_INPUT_BIT,
        0, 0, uintptr(0), 2, uintptr(unsafe.Pointer(&barriers[0])), 0, uintptr(0))
    
    ret, _, _ = syscall.SyscallN(ptrVkEndCommandBuffer, uintptr(app.computeCommandBuffer))
    check(int32(ret), "Failed to end compute command buffer")
    debugPrint("recordComputeCommandBuffer: Success")
}

func createFramebuffers() {
    debugPrint("createFramebuffers: Starting")
    app.swapChainFramebuffers = make([]VkFramebuffer, len(app.swapChainImageViews))
    for i, iv := range app.swapChainImageViews {
        createInfo := VkFramebufferCreateInfo{
            SType:           VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO,
            RenderPass:      app.renderPass,
            AttachmentCount: 1,
            PAttachments:    &iv,
            Width:           app.swapChainExtent.Width,
            Height:          app.swapChainExtent.Height,
            Layers:          1,
        }
        ret, _, _ := syscall.SyscallN(ptrVkCreateFramebuffer, uintptr(app.device),
            uintptr(unsafe.Pointer(&createInfo)), 0,
            uintptr(unsafe.Pointer(&app.swapChainFramebuffers[i])))
        check(int32(ret), "Failed to create framebuffer")
    }
    debugPrint("createFramebuffers: Success")
}

func createCommandPool() {
    debugPrint("createCommandPool: Starting")
    poolInfo := VkCommandPoolCreateInfo{
        SType:            VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO,
        Flags:            VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT,
        QueueFamilyIndex: app.graphicsFamily,
    }
    ret, _, _ := syscall.SyscallN(ptrVkCreateCommandPool, uintptr(app.device),
        uintptr(unsafe.Pointer(&poolInfo)), 0, uintptr(unsafe.Pointer(&app.commandPool)))
    check(int32(ret), "Failed to create command pool")
    debugPrint("createCommandPool: Success")
}

func createCommandBuffers() {
    debugPrint("createCommandBuffers: Starting")
    app.commandBuffers = make([]VkCommandBuffer, MAX_FRAMES_IN_FLIGHT)
    allocInfo := VkCommandBufferAllocateInfo{
        SType:              VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
        CommandPool:        app.commandPool,
        Level:              VK_COMMAND_BUFFER_LEVEL_PRIMARY,
        CommandBufferCount: MAX_FRAMES_IN_FLIGHT,
    }
    ret, _, _ := syscall.SyscallN(ptrVkAllocateCommandBuffers, uintptr(app.device),
        uintptr(unsafe.Pointer(&allocInfo)), uintptr(unsafe.Pointer(&app.commandBuffers[0])))
    check(int32(ret), "Failed to allocate command buffers")
    debugPrint("createCommandBuffers: Success")
}

func createSyncObjects() {
    debugPrint("createSyncObjects: Starting")
    semaphoreInfo := VkSemaphoreCreateInfo{SType: VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO}
    fenceInfo := VkFenceCreateInfo{SType: VK_STRUCTURE_TYPE_FENCE_CREATE_INFO, Flags: VK_FENCE_CREATE_SIGNALED_BIT}

    for i := 0; i < MAX_FRAMES_IN_FLIGHT; i++ {
        ret, _, _ := syscall.SyscallN(ptrVkCreateSemaphore, uintptr(app.device),
            uintptr(unsafe.Pointer(&semaphoreInfo)), 0, uintptr(unsafe.Pointer(&app.imageAvailableSemaphores[i])))
        check(int32(ret), "Failed to create semaphore")
        ret, _, _ = syscall.SyscallN(ptrVkCreateSemaphore, uintptr(app.device),
            uintptr(unsafe.Pointer(&semaphoreInfo)), 0, uintptr(unsafe.Pointer(&app.renderFinishedSemaphores[i])))
        check(int32(ret), "Failed to create semaphore")
        ret, _, _ = syscall.SyscallN(ptrVkCreateFence, uintptr(app.device),
            uintptr(unsafe.Pointer(&fenceInfo)), 0, uintptr(unsafe.Pointer(&app.inFlightFences[i])))
        check(int32(ret), "Failed to create fence")
    }
    debugPrint("createSyncObjects: Success")
}

func recordCommandBuffer(commandBuffer VkCommandBuffer, imageIndex uint32) {
    debugLog(fmt.Sprintf("recordCommandBuffer: Starting for imageIndex=%d", imageIndex))
    
    beginInfo := VkCommandBufferBeginInfo{SType: VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO}
    ret, _, _ := syscall.SyscallN(ptrVkBeginCommandBuffer, uintptr(commandBuffer), uintptr(unsafe.Pointer(&beginInfo)))
    check(int32(ret), "Failed to begin command buffer")
    
    debugLog("recordCommandBuffer: Command buffer begun")

    clearColor := VkClearValue{Color: VkClearColorValue{Float32: [4]float32{0, 0, 0, 1}}}
    renderPassInfo := VkRenderPassBeginInfo{
        SType:           VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO,
        RenderPass:      app.renderPass,
        Framebuffer:     app.swapChainFramebuffers[imageIndex],
        RenderArea:      VkRect2D{Extent: app.swapChainExtent},
        ClearValueCount: 1,
        PClearValues:    &clearColor,
    }

    syscall.SyscallN(ptrVkCmdBeginRenderPass, uintptr(commandBuffer), uintptr(unsafe.Pointer(&renderPassInfo)), VK_SUBPASS_CONTENTS_INLINE)
    syscall.SyscallN(ptrVkCmdBindPipeline, uintptr(commandBuffer), VK_PIPELINE_BIND_POINT_GRAPHICS, uintptr(app.graphicsPipeline))
    
    debugLog("recordCommandBuffer: Render pass begun, pipeline bound")

    viewport := VkViewport{
        Width:    float32(app.swapChainExtent.Width),
        Height:   float32(app.swapChainExtent.Height),
        MaxDepth: 1.0,
    }
    syscall.SyscallN(ptrVkCmdSetViewport, uintptr(commandBuffer), 0, 1, uintptr(unsafe.Pointer(&viewport)))

    scissor := VkRect2D{Extent: app.swapChainExtent}
    syscall.SyscallN(ptrVkCmdSetScissor, uintptr(commandBuffer), 0, 1, uintptr(unsafe.Pointer(&scissor)))

    debugLog("recordCommandBuffer: Viewport and scissor set")

    // Bind descriptor sets for graphics pipeline (to access storage buffers)
    syscall.SyscallN(ptrVkCmdBindDescriptorSets, uintptr(commandBuffer),
        VK_PIPELINE_BIND_POINT_GRAPHICS, uintptr(app.pipelineLayout), 0, 1,
        uintptr(unsafe.Pointer(&app.descriptorSet)), 0, uintptr(0))

    debugLog(fmt.Sprintf("recordCommandBuffer: Descriptor sets bound, drawing %d points", NUM_HARMONOGRAPH_POINTS))

    // Draw harmonograph points
    syscall.SyscallN(ptrVkCmdDraw, uintptr(commandBuffer), NUM_HARMONOGRAPH_POINTS, 1, 0, 0)

    syscall.SyscallN(ptrVkCmdEndRenderPass, uintptr(commandBuffer))
    ret, _, _ = syscall.SyscallN(ptrVkEndCommandBuffer, uintptr(commandBuffer))
    check(int32(ret), "Failed to end command buffer")
    
    debugLog("recordCommandBuffer: Command buffer recorded successfully")
}

func drawFrame() {
    debugLog("drawFrame: Starting")
    
    // Update animation parameters
    app.animationTime += 0.016
    params := ComputeParams{
        MaxNum: NUM_HARMONOGRAPH_POINTS,
        DT:     0.001,
        Scale:  0.02,
        Pad0:   0.0,
        A1:     50.0, F1: 2.0 + 0.5*float32(math.Sin(float64(app.animationTime)*0.7)), P1: 1.0/16.0, D1: 0.02,
        A2:     50.0, F2: 2.0 + 0.5*float32(math.Sin(float64(app.animationTime)*0.9)), P2: 3.0/2.0, D2: 0.0315,
        A3:     50.0, F3: 2.0 + 0.5*float32(math.Sin(float64(app.animationTime)*1.1)), P3: 13.0/15.0, D3: 0.02,
        A4:     50.0, F4: 2.0 + 0.5*float32(math.Sin(float64(app.animationTime)*1.3)), P4: 1.0, D4: 0.02,
    }
    
    // Update UBO with animation parameters
    var mappedPtr uintptr
    ret, _, _ := syscall.SyscallN(ptrVkMapMemory, uintptr(app.device), uintptr(app.paramBufferMemory),
        0, uintptr(unsafe.Sizeof(ComputeParams{})), 0, uintptr(unsafe.Pointer(&mappedPtr)))
    check(int32(ret), "Failed to map param buffer memory")
    
    paramsBytes := (*[unsafe.Sizeof(ComputeParams{})]byte)(unsafe.Pointer(&params))[:]
    targetBytes := (*[unsafe.Sizeof(ComputeParams{})]byte)(unsafe.Pointer(mappedPtr))[:]
    copy(targetBytes, paramsBytes)
    
    syscall.SyscallN(ptrVkUnmapMemory, uintptr(app.device), uintptr(app.paramBufferMemory))
    
    // First run compute shader to update harmonograph data
    syscall.SyscallN(ptrVkWaitForFences, uintptr(app.device), 1,
        uintptr(unsafe.Pointer(&app.computeFence)), 1, 0xFFFFFFFFFFFFFFFF)
    
    debugLog("drawFrame: Compute fence signaled, resetting")
    
    syscall.SyscallN(ptrVkResetFences, uintptr(app.device), 1, uintptr(unsafe.Pointer(&app.computeFence)))
    syscall.SyscallN(ptrVkResetCommandBuffer, uintptr(app.computeCommandBuffer), 0)
    recordComputeCommandBuffer()
    
    submitInfo := VkSubmitInfo{
        SType:              VK_STRUCTURE_TYPE_SUBMIT_INFO,
        CommandBufferCount: 1,
        PCommandBuffers:    &app.computeCommandBuffer,
    }
    ret, _, _ = syscall.SyscallN(ptrVkQueueSubmit, uintptr(app.graphicsQueue), 1,
        uintptr(unsafe.Pointer(&submitInfo)), uintptr(app.computeFence))
    check(int32(ret), "Failed to submit compute command buffer")
    
    debugLog("drawFrame: Compute command submitted, waiting for completion")
    
    // Wait for compute to finish
    syscall.SyscallN(ptrVkWaitForFences, uintptr(app.device), 1,
        uintptr(unsafe.Pointer(&app.computeFence)), 1, 0xFFFFFFFFFFFFFFFF)
    
    debugLog("drawFrame: Compute completed, acquiring next image")
    
    // Then render graphics
    syscall.SyscallN(ptrVkWaitForFences, uintptr(app.device), 1,
        uintptr(unsafe.Pointer(&app.inFlightFences[app.currentFrame])), 1, 0xFFFFFFFFFFFFFFFF)

    var imageIndex uint32
    result, _, _ := syscall.SyscallN(ptrVkAcquireNextImageKHR, uintptr(app.device), uintptr(app.swapChain),
        0xFFFFFFFFFFFFFFFF, uintptr(app.imageAvailableSemaphores[app.currentFrame]), 0, uintptr(unsafe.Pointer(&imageIndex)))
    if int32(result) == VK_ERROR_OUT_OF_DATE_KHR {
        debugLog("drawFrame: Swapchain out of date, returning")
        return
    }
    
    debugLog(fmt.Sprintf("drawFrame: Image acquired: index=%d, currentFrame=%d", imageIndex, app.currentFrame))

    syscall.SyscallN(ptrVkResetFences, uintptr(app.device), 1, uintptr(unsafe.Pointer(&app.inFlightFences[app.currentFrame])))
    syscall.SyscallN(ptrVkResetCommandBuffer, uintptr(app.commandBuffers[app.currentFrame]), 0)
    recordCommandBuffer(app.commandBuffers[app.currentFrame], imageIndex)

    waitStages := []uint32{VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT}
    submitInfo = VkSubmitInfo{
        SType:                VK_STRUCTURE_TYPE_SUBMIT_INFO,
        WaitSemaphoreCount:   1,
        PWaitSemaphores:      &app.imageAvailableSemaphores[app.currentFrame],
        PWaitDstStageMask:    &waitStages[0],
        CommandBufferCount:   1,
        PCommandBuffers:      &app.commandBuffers[app.currentFrame],
        SignalSemaphoreCount: 1,
        PSignalSemaphores:    &app.renderFinishedSemaphores[app.currentFrame],
    }
    ret, _, _ = syscall.SyscallN(ptrVkQueueSubmit, uintptr(app.graphicsQueue), 1,
        uintptr(unsafe.Pointer(&submitInfo)), uintptr(app.inFlightFences[app.currentFrame]))
    check(int32(ret), "Failed to submit draw command buffer")
    
    debugLog("drawFrame: Graphics command submitted")

    presentInfo := VkPresentInfoKHR{
        SType:              VK_STRUCTURE_TYPE_PRESENT_INFO_KHR,
        WaitSemaphoreCount: 1,
        PWaitSemaphores:    &app.renderFinishedSemaphores[app.currentFrame],
        SwapchainCount:     1,
        PSwapchains:        &app.swapChain,
        PImageIndices:      &imageIndex,
    }
    syscall.SyscallN(ptrVkQueuePresentKHR, uintptr(app.presentQueue), uintptr(unsafe.Pointer(&presentInfo)))
    app.currentFrame = (app.currentFrame + 1) % MAX_FRAMES_IN_FLIGHT
    
    debugLog("drawFrame: Frame presented")
}

func cleanup() {
    syscall.SyscallN(ptrVkDeviceWaitIdle, uintptr(app.device))
    
    // Cleanup compute resources
    syscall.SyscallN(ptrVkDestroyBuffer, uintptr(app.device), uintptr(app.positionBuffer), 0)
    syscall.SyscallN(ptrVkFreeMemory, uintptr(app.device), uintptr(app.positionBufferMem), 0)
    
    syscall.SyscallN(ptrVkDestroyBuffer, uintptr(app.device), uintptr(app.colorBuffer), 0)
    syscall.SyscallN(ptrVkFreeMemory, uintptr(app.device), uintptr(app.colorBufferMem), 0)
    
    syscall.SyscallN(ptrVkDestroyBuffer, uintptr(app.device), uintptr(app.paramBuffer), 0)
    syscall.SyscallN(ptrVkFreeMemory, uintptr(app.device), uintptr(app.paramBufferMemory), 0)
    syscall.SyscallN(ptrVkDestroyDescriptorPool, uintptr(app.device), uintptr(app.descriptorPool), 0)
    syscall.SyscallN(ptrVkDestroyDescriptorSetLayout, uintptr(app.device), uintptr(app.descriptorSetLayout), 0)
    syscall.SyscallN(ptrVkDestroyPipeline, uintptr(app.device), uintptr(app.computePipeline), 0)
    syscall.SyscallN(ptrVkDestroyPipelineLayout, uintptr(app.device), uintptr(app.computePipelineLayout), 0)
    
    // Cleanup graphics resources
    for i := 0; i < MAX_FRAMES_IN_FLIGHT; i++ {
        syscall.SyscallN(ptrVkDestroySemaphore, uintptr(app.device), uintptr(app.renderFinishedSemaphores[i]), 0)
        syscall.SyscallN(ptrVkDestroySemaphore, uintptr(app.device), uintptr(app.imageAvailableSemaphores[i]), 0)
        syscall.SyscallN(ptrVkDestroyFence, uintptr(app.device), uintptr(app.inFlightFences[i]), 0)
    }
    syscall.SyscallN(ptrVkDestroyFence, uintptr(app.device), uintptr(app.computeFence), 0)
    
    syscall.SyscallN(ptrVkDestroyCommandPool, uintptr(app.device), uintptr(app.commandPool), 0)
    for _, fb := range app.swapChainFramebuffers {
        syscall.SyscallN(ptrVkDestroyFramebuffer, uintptr(app.device), uintptr(fb), 0)
    }
    syscall.SyscallN(ptrVkDestroyPipeline, uintptr(app.device), uintptr(app.graphicsPipeline), 0)
    syscall.SyscallN(ptrVkDestroyPipelineLayout, uintptr(app.device), uintptr(app.pipelineLayout), 0)
    syscall.SyscallN(ptrVkDestroyRenderPass, uintptr(app.device), uintptr(app.renderPass), 0)
    for _, iv := range app.swapChainImageViews {
        syscall.SyscallN(ptrVkDestroyImageView, uintptr(app.device), uintptr(iv), 0)
    }
    syscall.SyscallN(ptrVkDestroySwapchainKHR, uintptr(app.device), uintptr(app.swapChain), 0)
    syscall.SyscallN(ptrVkDestroyDevice, uintptr(app.device), 0)
    syscall.SyscallN(ptrVkDestroySurfaceKHR, uintptr(app.instance), uintptr(app.surface), 0)
    syscall.SyscallN(ptrVkDestroyInstance, uintptr(app.instance), 0)
    syscall.FreeLibrary(vulkanDLL)
}

func initVulkan() {
    debugLog("initVulkan: Starting")
    createInstance()
    debugLog("initVulkan: Created instance")
    createSurface()
    debugLog("initVulkan: Created surface")
    pickPhysicalDevice()
    debugLog("initVulkan: Picked physical device")
    createLogicalDevice()
    debugLog("initVulkan: Created logical device")
    createSwapChain()
    debugLog("initVulkan: Created swapchain")
    createImageViews()
    debugLog("initVulkan: Created image views")
    createRenderPass()
    debugLog("initVulkan: Created render pass")
    
    // Create storage buffers for compute shader
    createStorageBuffers()
    debugLog("initVulkan: Created storage buffers")
    
    // Initialize parameter buffer with harmonograph computation parameters
    initializeParamBuffer()
    debugLog("initVulkan: Initialized parameter buffer")
    
    // Create descriptor set layout and pool
    createDescriptorSetLayout()
    debugLog("initVulkan: Created descriptor set layout")
    createDescriptorPool()
    debugLog("initVulkan: Created descriptor pool")
    allocateDescriptorSets()
    debugLog("initVulkan: Allocated descriptor sets")
    updateDescriptorSets()
    debugLog("initVulkan: Updated descriptor sets")
    
    // Create pipelines (compute and graphics)
    createComputePipeline()
    debugLog("initVulkan: Created compute pipeline")
    createGraphicsPipeline()
    debugLog("initVulkan: Created graphics pipeline")
    
    createFramebuffers()
    debugLog("initVulkan: Created framebuffers")
    createCommandPool()
    debugLog("initVulkan: Created command pool")
    createCommandBuffers()
    debugLog("initVulkan: Created command buffers")
    createComputeCommandBuffer()
    debugLog("initVulkan: Created compute command buffer")
    createSyncObjects()
    debugLog("initVulkan: Created sync objects")
    
    // Create compute fence
    fenceInfo := VkFenceCreateInfo{SType: VK_STRUCTURE_TYPE_FENCE_CREATE_INFO, Flags: VK_FENCE_CREATE_SIGNALED_BIT}
    ret, _, _ := syscall.SyscallN(ptrVkCreateFence, uintptr(app.device),
        uintptr(unsafe.Pointer(&fenceInfo)), 0, uintptr(unsafe.Pointer(&app.computeFence)))
    check(int32(ret), "Failed to create compute fence")
    debugLog("initVulkan: Created compute fence")
    
    // Record compute command buffer once
    recordComputeCommandBuffer()
    debugLog("initVulkan: Recorded compute command buffer")
    
    debugLog("initVulkan: Completed successfully")
}

// =============================================================================
// Windows
// =============================================================================

// Debug output helper function
func debugLog(msg string) {
    wideStr := syscall.StringToUTF16Ptr(msg + "\n")
    procOutputDebugStringW.Call(uintptr(unsafe.Pointer(wideStr)))
    fmt.Println("[DEBUG] " + msg)
}

var (
    user32              = syscall.NewLazyDLL("user32.dll")
    procCreateWindowExW = user32.NewProc("CreateWindowExW")
    procDefWindowProcW  = user32.NewProc("DefWindowProcW")
    procDestroyWindow   = user32.NewProc("DestroyWindow")
    procDispatchMessage = user32.NewProc("DispatchMessageW")
    procPeekMessageW    = user32.NewProc("PeekMessageW")
    procLoadCursorW     = user32.NewProc("LoadCursorW")
    procLoadIconW       = user32.NewProc("LoadIconW")
    procPostQuitMessage = user32.NewProc("PostQuitMessage")
    procRegisterClassEx = user32.NewProc("RegisterClassExW")
    procShowWindow      = user32.NewProc("ShowWindow")
    procTranslateMsg    = user32.NewProc("TranslateMessage")

    gdi32              = syscall.NewLazyDLL("gdi32.dll")
    procGetStockObject = gdi32.NewProc("GetStockObject")

    kernel32             = syscall.NewLazyDLL("kernel32.dll")
    procGetModuleHandleW = kernel32.NewProc("GetModuleHandleW")
    procOutputDebugStringW = kernel32.NewProc("OutputDebugStringW")
)

func debugPrint(msg string) {
    fmt.Println(msg)
    utf16Msg, _ := syscall.UTF16PtrFromString(msg + "\n")
    procOutputDebugStringW.Call(uintptr(unsafe.Pointer(utf16Msg)))
}

func wndProc(hwnd syscall.Handle, msg uint32, wparam, lparam uintptr) uintptr {
    switch msg {
    case WM_CLOSE, WM_DESTROY:
        procPostQuitMessage.Call(0)
        return 0
    }
    ret, _, _ := procDefWindowProcW.Call(uintptr(hwnd), uintptr(msg), wparam, lparam)
    return ret
}

func main() {
    runtime.LockOSThread()
    
    debugLog("main: Starting application")

    if !loadVulkan() {
        debugLog("main: Failed to load Vulkan")
        fmt.Println("Failed to load Vulkan")
        return
    }
    
    debugLog("main: Vulkan loaded successfully")

    ret, _, _ := procGetModuleHandleW.Call(0)
    app.hInstance = syscall.Handle(ret)
    
    debugLog("main: Creating window")

    className := "VulkanHarmonograph"
    wcx := WNDCLASSEXW{
        Style:     CS_OWNDC,
        WndProc:   syscall.NewCallback(wndProc),
        Instance:  app.hInstance,
        ClassName: syscall.StringToUTF16Ptr(className),
    }
    wcx.Size = uint32(unsafe.Sizeof(wcx))

    cursor, _, _ := procLoadCursorW.Call(0, IDC_ARROW)
    wcx.Cursor = syscall.Handle(cursor)
    brush, _, _ := procGetStockObject.Call(BLACK_BRUSH)
    wcx.Background = syscall.Handle(brush)
    icon, _, _ := procLoadIconW.Call(0, IDI_APPLICATION)
    wcx.Icon = syscall.Handle(icon)
    wcx.IconSm = syscall.Handle(icon)

    procRegisterClassEx.Call(uintptr(unsafe.Pointer(&wcx)))

    ret, _, _ = procCreateWindowExW.Call(
        0,
        uintptr(unsafe.Pointer(syscall.StringToUTF16Ptr(className))),
        uintptr(unsafe.Pointer(syscall.StringToUTF16Ptr("Harmonograph - Vulkan 1.4 Compute Shader (Go)"))),
        WS_OVERLAPPEDWINDOW,
        uintptr(CW_USEDEFAULT),
        uintptr(CW_USEDEFAULT),
        WIDTH,
        HEIGHT,
        0, 0,
        uintptr(app.hInstance),
        0,
    )
    app.hwnd = syscall.Handle(ret)
    
    debugLog("main: Window created")

    procShowWindow.Call(uintptr(app.hwnd), 5)
    
    debugLog("main: Initializing Vulkan")

    initVulkan()
    app.startTime = time.Now()

    debugLog("main: Vulkan initialization complete")

    fmt.Println("===========================================")
    fmt.Println("Vulkan Harmonograph (Compute Shader) initialized!")
    fmt.Println("Shaders loaded from: hello_vert.spv, hello_frag.spv, hello_comp.spv")
    fmt.Println("===========================================")
    
    debugLog("main: Entering main loop")

    // Main loop
    for {
        var msg MSG
        ret, _, _ := procPeekMessageW.Call(uintptr(unsafe.Pointer(&msg)), 0, 0, 0, PM_REMOVE)
        if ret != 0 {
            if msg.Message == WM_QUIT {
                debugLog("main: Received WM_QUIT")
                break
            }
            procTranslateMsg.Call(uintptr(unsafe.Pointer(&msg)))
            procDispatchMessage.Call(uintptr(unsafe.Pointer(&msg)))
        } else {
            drawFrame()
        }
    }
    
    debugLog("main: Cleaning up")

    cleanup()
    procDestroyWindow.Call(uintptr(app.hwnd))
    
    debugLog("main: Application terminated")
}