// Vulkan 1.4 Triangle Example in Go
// Win32 API + Manual Vulkan Bindings
// Build: go build -ldflags="-H windowsgui" hello_vulkan.go
// Note: Vulkan SDK must be installed

package main

import (
    "fmt"
    "runtime"
    "syscall"
    "unsafe"
)

// =============================================================================
// Constants
// =============================================================================

const (
    WIDTH              = 800
    HEIGHT             = 600
    MAX_FRAMES_IN_FLIGHT = 2
    ENABLE_VALIDATION  = true
)

// Win32 constants
const (
    CW_USEDEFAULT uint32      = 0x80000000
    WS_OVERLAPPEDWINDOW       = 0x00CF0000
    WM_DESTROY                = 0x0002
    WM_CLOSE                  = 0x0010
    WM_QUIT                   = 0x0012
    PM_REMOVE                 = 0x0001
    CS_OWNDC                  = 0x0020
    IDC_ARROW                 = 32512
    IDI_APPLICATION           = 32512
    BLACK_BRUSH               = 4
)

// Vulkan constants
const (
    VK_SUCCESS                        = 0
    VK_NOT_READY                      = 1
    VK_TIMEOUT                        = 2
    VK_SUBOPTIMAL_KHR                 = 1000001003
    VK_ERROR_OUT_OF_DATE_KHR          = -1000001004

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
    VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR                 = 1000001000
    VK_STRUCTURE_TYPE_PRESENT_INFO_KHR                          = 1000001001
    VK_STRUCTURE_TYPE_WIN32_SURFACE_CREATE_INFO_KHR             = 1000009000
    VK_STRUCTURE_TYPE_DEBUG_UTILS_MESSENGER_CREATE_INFO_EXT     = 1000128004

    VK_FORMAT_B8G8R8A8_SRGB         = 50
    VK_FORMAT_B8G8R8A8_UNORM        = 44
    VK_COLOR_SPACE_SRGB_NONLINEAR_KHR = 0

    VK_PRESENT_MODE_IMMEDIATE_KHR    = 0
    VK_PRESENT_MODE_MAILBOX_KHR      = 1
    VK_PRESENT_MODE_FIFO_KHR         = 2

    VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT = 0x00000010

    VK_SHARING_MODE_EXCLUSIVE  = 0
    VK_SHARING_MODE_CONCURRENT = 1

    VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR = 0x00000001

    VK_IMAGE_VIEW_TYPE_2D = 1

    VK_COMPONENT_SWIZZLE_IDENTITY = 0

    VK_IMAGE_ASPECT_COLOR_BIT = 0x00000001

    VK_ATTACHMENT_LOAD_OP_CLEAR     = 1
    VK_ATTACHMENT_STORE_OP_STORE    = 0
    VK_ATTACHMENT_STORE_OP_DONT_CARE = 1

    VK_IMAGE_LAYOUT_UNDEFINED                = 0
    VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL = 2
    VK_IMAGE_LAYOUT_PRESENT_SRC_KHR          = 1000001002

    VK_PIPELINE_BIND_POINT_GRAPHICS = 0

    VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT = 0x00000400

    VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT = 0x00000100

    VK_SHADER_STAGE_VERTEX_BIT   = 0x00000001
    VK_SHADER_STAGE_FRAGMENT_BIT = 0x00000010

    VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST = 3

    VK_POLYGON_MODE_FILL = 0

    VK_CULL_MODE_BACK_BIT = 0x00000002

    VK_FRONT_FACE_CLOCKWISE = 1

    VK_COLOR_COMPONENT_R_BIT = 0x00000001
    VK_COLOR_COMPONENT_G_BIT = 0x00000002
    VK_COLOR_COMPONENT_B_BIT = 0x00000004
    VK_COLOR_COMPONENT_A_BIT = 0x00000008

    VK_DYNAMIC_STATE_VIEWPORT = 0
    VK_DYNAMIC_STATE_SCISSOR  = 1

    VK_SUBPASS_CONTENTS_INLINE = 0

    VK_COMMAND_BUFFER_LEVEL_PRIMARY = 0

    VK_FENCE_CREATE_SIGNALED_BIT = 0x00000001

    VK_QUEUE_GRAPHICS_BIT = 0x00000001

    VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT = 0x00000002

    VK_SUBPASS_EXTERNAL = 0xFFFFFFFF

    VK_DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT = 0x00000100
    VK_DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT   = 0x00001000

    VK_DEBUG_UTILS_MESSAGE_TYPE_GENERAL_BIT_EXT     = 0x00000001
    VK_DEBUG_UTILS_MESSAGE_TYPE_VALIDATION_BIT_EXT  = 0x00000002
    VK_DEBUG_UTILS_MESSAGE_TYPE_PERFORMANCE_BIT_EXT = 0x00000004
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
type VkDebugUtilsMessengerEXT uintptr

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
    X        float32
    Y        float32
    Width    float32
    Height   float32
    MinDepth float32
    MaxDepth float32
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
    R uint32
    G uint32
    B uint32
    A uint32
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

type VkPipelineLayoutCreateInfo struct {
    SType                  uint32
    PNext                  uintptr
    Flags                  uint32
    SetLayoutCount         uint32
    PSetLayouts            uintptr
    PushConstantRangeCount uint32
    PPushConstantRanges    uintptr
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

type VkDebugUtilsMessengerCreateInfoEXT struct {
    SType           uint32
    PNext           uintptr
    Flags           uint32
    MessageSeverity uint32
    MessageType     uint32
    PfnUserCallback uintptr
    PUserData       uintptr
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
    debugMessenger VkDebugUtilsMessengerEXT
    surface        VkSurfaceKHR
    physicalDevice VkPhysicalDevice
    device         VkDevice
    graphicsQueue  VkQueue
    presentQueue   VkQueue
    graphicsFamily uint32
    presentFamily  uint32

    swapChain            VkSwapchainKHR
    swapChainImages      []VkImage
    swapChainImageFormat uint32
    swapChainExtent      VkExtent2D
    swapChainImageViews  []VkImageView
    swapChainFramebuffers []VkFramebuffer

    renderPass       VkRenderPass
    pipelineLayout   VkPipelineLayout
    graphicsPipeline VkPipeline

    commandPool    VkCommandPool
    commandBuffers []VkCommandBuffer

    imageAvailableSemaphores [MAX_FRAMES_IN_FLIGHT]VkSemaphore
    renderFinishedSemaphores [MAX_FRAMES_IN_FLIGHT]VkSemaphore
    inFlightFences           [MAX_FRAMES_IN_FLIGHT]VkFence
    currentFrame             int
}

var app App

// =============================================================================
// Vulkan Function Pointers
// =============================================================================

var (
    vulkanDLL syscall.Handle

    ptrVkGetInstanceProcAddr uintptr

    ptrVkCreateInstance                       uintptr
    ptrVkDestroyInstance                      uintptr
    ptrVkEnumeratePhysicalDevices             uintptr
    ptrVkGetPhysicalDeviceProperties          uintptr
    ptrVkGetPhysicalDeviceQueueFamilyProperties uintptr
    ptrVkCreateDevice                         uintptr
    ptrVkDestroyDevice                        uintptr
    ptrVkGetDeviceQueue                       uintptr
    ptrVkDeviceWaitIdle                       uintptr

    ptrVkDestroySurfaceKHR                      uintptr
    ptrVkGetPhysicalDeviceSurfaceSupportKHR    uintptr
    ptrVkGetPhysicalDeviceSurfaceCapabilitiesKHR uintptr
    ptrVkGetPhysicalDeviceSurfaceFormatsKHR    uintptr
    ptrVkGetPhysicalDeviceSurfacePresentModesKHR uintptr
    ptrVkCreateWin32SurfaceKHR                 uintptr

    ptrVkCreateSwapchainKHR    uintptr
    ptrVkDestroySwapchainKHR   uintptr
    ptrVkGetSwapchainImagesKHR uintptr
    ptrVkAcquireNextImageKHR   uintptr
    ptrVkQueuePresentKHR       uintptr

    ptrVkCreateImageView  uintptr
    ptrVkDestroyImageView uintptr
    ptrVkCreateRenderPass uintptr
    ptrVkDestroyRenderPass uintptr

    ptrVkCreateShaderModule    uintptr
    ptrVkDestroyShaderModule   uintptr
    ptrVkCreatePipelineLayout  uintptr
    ptrVkDestroyPipelineLayout uintptr
    ptrVkCreateGraphicsPipelines uintptr
    ptrVkDestroyPipeline       uintptr

    ptrVkCreateFramebuffer  uintptr
    ptrVkDestroyFramebuffer uintptr

    ptrVkCreateCommandPool     uintptr
    ptrVkDestroyCommandPool    uintptr
    ptrVkAllocateCommandBuffers uintptr
    ptrVkBeginCommandBuffer    uintptr
    ptrVkEndCommandBuffer      uintptr
    ptrVkResetCommandBuffer    uintptr
    ptrVkCmdBeginRenderPass    uintptr
    ptrVkCmdEndRenderPass      uintptr
    ptrVkCmdBindPipeline       uintptr
    ptrVkCmdSetViewport        uintptr
    ptrVkCmdSetScissor         uintptr
    ptrVkCmdDraw               uintptr

    ptrVkCreateSemaphore  uintptr
    ptrVkDestroySemaphore uintptr
    ptrVkCreateFence      uintptr
    ptrVkDestroyFence     uintptr
    ptrVkWaitForFences    uintptr
    ptrVkResetFences      uintptr
    ptrVkQueueSubmit      uintptr

    ptrVkCreateDebugUtilsMessengerEXT  uintptr
    ptrVkDestroyDebugUtilsMessengerEXT uintptr
)

// =============================================================================
// SPIR-V Shaders (Pre-compiled Bytecode)
// =============================================================================

// Vertex shader (compiled from hello.vert)
var vertShaderCode = []uint32{
    0x07230203, 0x00010000, 0x0008000b, 0x00000036, 0x00000000, 0x00020011,
    0x00000001, 0x0006000b, 0x00000001, 0x4c534c47, 0x6474732e, 0x3035342e,
    0x00000000, 0x0003000e, 0x00000000, 0x00000001, 0x0008000f, 0x00000000,
    0x00000004, 0x6e69616d, 0x00000000, 0x00000022, 0x00000026, 0x00000031,
    0x00030003, 0x00000002, 0x000001c2, 0x00040005, 0x00000004, 0x6e69616d,
    0x00000000, 0x00050005, 0x0000000c, 0x69736f70, 0x6e6f6974, 0x00000073,
    0x00040005, 0x00000017, 0x6f6c6f63, 0x00007372, 0x00060005, 0x00000020,
    0x505f6c67, 0x65567265, 0x78657472, 0x00000000, 0x00060006, 0x00000020,
    0x00000000, 0x505f6c67, 0x7469736f, 0x006e6f69, 0x00070006, 0x00000020,
    0x00000001, 0x505f6c67, 0x746e696f, 0x657a6953, 0x00000000, 0x00070006,
    0x00000020, 0x00000002, 0x435f6c67, 0x4470696c, 0x61747369, 0x0065636e,
    0x00070006, 0x00000020, 0x00000003, 0x435f6c67, 0x446c6c75, 0x61747369,
    0x0065636e, 0x00030005, 0x00000022, 0x00000000, 0x00060005, 0x00000026,
    0x565f6c67, 0x65747265, 0x646e4978, 0x00007865, 0x00050005, 0x00000031,
    0x67617266, 0x6f6c6f43, 0x00000072, 0x00050048, 0x00000020, 0x00000000,
    0x0000000b, 0x00000000, 0x00050048, 0x00000020, 0x00000001, 0x0000000b,
    0x00000001, 0x00050048, 0x00000020, 0x00000002, 0x0000000b, 0x00000003,
    0x00050048, 0x00000020, 0x00000003, 0x0000000b, 0x00000004, 0x00030047,
    0x00000020, 0x00000002, 0x00040047, 0x00000026, 0x0000000b, 0x0000002a,
    0x00040047, 0x00000031, 0x0000001e, 0x00000000, 0x00020013, 0x00000002,
    0x00030021, 0x00000003, 0x00000002, 0x00030016, 0x00000006, 0x00000020,
    0x00040017, 0x00000007, 0x00000006, 0x00000002, 0x00040015, 0x00000008,
    0x00000020, 0x00000000, 0x0004002b, 0x00000008, 0x00000009, 0x00000003,
    0x0004001c, 0x0000000a, 0x00000007, 0x00000009, 0x00040020, 0x0000000b,
    0x00000006, 0x0000000a, 0x0004003b, 0x0000000b, 0x0000000c, 0x00000006,
    0x0004002b, 0x00000006, 0x0000000d, 0x00000000, 0x0004002b, 0x00000006,
    0x0000000e, 0xbf000000, 0x0005002c, 0x00000007, 0x0000000f, 0x0000000d,
    0x0000000e, 0x0004002b, 0x00000006, 0x00000010, 0x3f000000, 0x0005002c,
    0x00000007, 0x00000011, 0x00000010, 0x00000010, 0x0005002c, 0x00000007,
    0x00000012, 0x0000000e, 0x00000010, 0x0006002c, 0x0000000a, 0x00000013,
    0x0000000f, 0x00000011, 0x00000012, 0x00040017, 0x00000014, 0x00000006,
    0x00000003, 0x0004001c, 0x00000015, 0x00000014, 0x00000009, 0x00040020,
    0x00000016, 0x00000006, 0x00000015, 0x0004003b, 0x00000016, 0x00000017,
    0x00000006, 0x0004002b, 0x00000006, 0x00000018, 0x3f800000, 0x0006002c,
    0x00000014, 0x00000019, 0x00000018, 0x0000000d, 0x0000000d, 0x0006002c,
    0x00000014, 0x0000001a, 0x0000000d, 0x00000018, 0x0000000d, 0x0006002c,
    0x00000014, 0x0000001b, 0x0000000d, 0x0000000d, 0x00000018, 0x0006002c,
    0x00000015, 0x0000001c, 0x00000019, 0x0000001a, 0x0000001b, 0x00040017,
    0x0000001d, 0x00000006, 0x00000004, 0x0004002b, 0x00000008, 0x0000001e,
    0x00000001, 0x0004001c, 0x0000001f, 0x00000006, 0x0000001e, 0x0006001e,
    0x00000020, 0x0000001d, 0x00000006, 0x0000001f, 0x0000001f, 0x00040020,
    0x00000021, 0x00000003, 0x00000020, 0x0004003b, 0x00000021, 0x00000022,
    0x00000003, 0x00040015, 0x00000023, 0x00000020, 0x00000001, 0x0004002b,
    0x00000023, 0x00000024, 0x00000000, 0x00040020, 0x00000025, 0x00000001,
    0x00000023, 0x0004003b, 0x00000025, 0x00000026, 0x00000001, 0x00040020,
    0x00000028, 0x00000006, 0x00000007, 0x00040020, 0x0000002d, 0x00000003,
    0x0000001d, 0x00040020, 0x00000030, 0x00000003, 0x00000014, 0x0004003b,
    0x00000030, 0x00000031, 0x00000003, 0x00040020, 0x00000033, 0x00000006,
    0x00000014, 0x00050036, 0x00000002, 0x00000004, 0x00000000, 0x00000003,
    0x000200f8, 0x00000005, 0x0003003e, 0x0000000c, 0x00000013, 0x0003003e,
    0x00000017, 0x0000001c, 0x0004003d, 0x00000023, 0x00000027, 0x00000026,
    0x00050041, 0x00000028, 0x00000029, 0x0000000c, 0x00000027, 0x0004003d,
    0x00000007, 0x0000002a, 0x00000029, 0x00050051, 0x00000006, 0x0000002b,
    0x0000002a, 0x00000000, 0x00050051, 0x00000006, 0x0000002c, 0x0000002a,
    0x00000001, 0x00070050, 0x0000001d, 0x0000002e, 0x0000002b, 0x0000002c,
    0x0000000d, 0x00000018, 0x00050041, 0x0000002d, 0x0000002f, 0x00000022,
    0x00000024, 0x0003003e, 0x0000002f, 0x0000002e, 0x0004003d, 0x00000023,
    0x00000032, 0x00000026, 0x00050041, 0x00000033, 0x00000034, 0x00000017,
    0x00000032, 0x0004003d, 0x00000014, 0x00000035, 0x00000034, 0x0003003e,
    0x00000031, 0x00000035, 0x000100fd, 0x00010038,
}

// Fragment shader (compiled from hello.frag)
var fragShaderCode = []uint32{
    0x07230203, 0x00010000, 0x0008000b, 0x00000013, 0x00000000, 0x00020011,
    0x00000001, 0x0006000b, 0x00000001, 0x4c534c47, 0x6474732e, 0x3035342e,
    0x00000000, 0x0003000e, 0x00000000, 0x00000001, 0x0007000f, 0x00000004,
    0x00000004, 0x6e69616d, 0x00000000, 0x00000009, 0x0000000c, 0x00030010,
    0x00000004, 0x00000007, 0x00030003, 0x00000002, 0x000001c2, 0x00040005,
    0x00000004, 0x6e69616d, 0x00000000, 0x00050005, 0x00000009, 0x4374756f,
    0x726f6c6f, 0x00000000, 0x00050005, 0x0000000c, 0x67617266, 0x6f6c6f43,
    0x00000072, 0x00040047, 0x00000009, 0x0000001e, 0x00000000, 0x00040047,
    0x0000000c, 0x0000001e, 0x00000000, 0x00020013, 0x00000002, 0x00030021,
    0x00000003, 0x00000002, 0x00030016, 0x00000006, 0x00000020, 0x00040017,
    0x00000007, 0x00000006, 0x00000004, 0x00040020, 0x00000008, 0x00000003,
    0x00000007, 0x0004003b, 0x00000008, 0x00000009, 0x00000003, 0x00040017,
    0x0000000a, 0x00000006, 0x00000003, 0x00040020, 0x0000000b, 0x00000001,
    0x0000000a, 0x0004003b, 0x0000000b, 0x0000000c, 0x00000001, 0x0004002b,
    0x00000006, 0x0000000e, 0x3f800000, 0x00050036, 0x00000002, 0x00000004,
    0x00000000, 0x00000003, 0x000200f8, 0x00000005, 0x0004003d, 0x0000000a,
    0x0000000d, 0x0000000c, 0x00050051, 0x00000006, 0x0000000f, 0x0000000d,
    0x00000000, 0x00050051, 0x00000006, 0x00000010, 0x0000000d, 0x00000001,
    0x00050051, 0x00000006, 0x00000011, 0x0000000d, 0x00000002, 0x00070050,
    0x00000007, 0x00000012, 0x0000000f, 0x00000010, 0x00000011, 0x0000000e,
    0x0003003e, 0x00000009, 0x00000012, 0x000100fd, 0x00010038,
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
        panic(fmt.Sprintf("%s: %d", msg, result))
    }
}

// =============================================================================
// Vulkan Loader
// =============================================================================

func loadVulkan() bool {
    var err error
    vulkanDLL, err = syscall.LoadLibrary("vulkan-1.dll")
    if err != nil {
        fmt.Println("Failed to load vulkan-1.dll")
        return false
    }

    ptrVkGetInstanceProcAddr, _ = syscall.GetProcAddress(vulkanDLL, "vkGetInstanceProcAddr")
    if ptrVkGetInstanceProcAddr == 0 {
        fmt.Println("Failed to get vkGetInstanceProcAddr")
        return false
    }

    // Load global functions
    ptrVkCreateInstance = vkGetInstanceProcAddr(0, "vkCreateInstance")

    return true
}

func vkGetInstanceProcAddr(instance VkInstance, name string) uintptr {
    ret, _, _ := syscall.SyscallN(ptrVkGetInstanceProcAddr, uintptr(instance), uintptr(unsafe.Pointer(cstr(name))))
    return ret
}

func loadInstanceFunctions(instance VkInstance) {
    ptrVkDestroyInstance = vkGetInstanceProcAddr(instance, "vkDestroyInstance")
    ptrVkEnumeratePhysicalDevices = vkGetInstanceProcAddr(instance, "vkEnumeratePhysicalDevices")
    ptrVkGetPhysicalDeviceProperties = vkGetInstanceProcAddr(instance, "vkGetPhysicalDeviceProperties")
    ptrVkGetPhysicalDeviceQueueFamilyProperties = vkGetInstanceProcAddr(instance, "vkGetPhysicalDeviceQueueFamilyProperties")
    ptrVkCreateDevice = vkGetInstanceProcAddr(instance, "vkCreateDevice")

    // Surface functions
    ptrVkDestroySurfaceKHR = vkGetInstanceProcAddr(instance, "vkDestroySurfaceKHR")
    ptrVkGetPhysicalDeviceSurfaceSupportKHR = vkGetInstanceProcAddr(instance, "vkGetPhysicalDeviceSurfaceSupportKHR")
    ptrVkGetPhysicalDeviceSurfaceCapabilitiesKHR = vkGetInstanceProcAddr(instance, "vkGetPhysicalDeviceSurfaceCapabilitiesKHR")
    ptrVkGetPhysicalDeviceSurfaceFormatsKHR = vkGetInstanceProcAddr(instance, "vkGetPhysicalDeviceSurfaceFormatsKHR")
    ptrVkGetPhysicalDeviceSurfacePresentModesKHR = vkGetInstanceProcAddr(instance, "vkGetPhysicalDeviceSurfacePresentModesKHR")
    ptrVkCreateWin32SurfaceKHR = vkGetInstanceProcAddr(instance, "vkCreateWin32SurfaceKHR")

    // Debug functions
    ptrVkCreateDebugUtilsMessengerEXT = vkGetInstanceProcAddr(instance, "vkCreateDebugUtilsMessengerEXT")
    ptrVkDestroyDebugUtilsMessengerEXT = vkGetInstanceProcAddr(instance, "vkDestroyDebugUtilsMessengerEXT")
}

func vkGetDeviceProcAddr(device VkDevice, name string) uintptr {
    ptr := vkGetInstanceProcAddr(app.instance, "vkGetDeviceProcAddr")
    ret, _, _ := syscall.SyscallN(ptr, uintptr(device), uintptr(unsafe.Pointer(cstr(name))))
    return ret
}

func loadDeviceFunctions(device VkDevice) {
    ptrVkDestroyDevice = vkGetDeviceProcAddr(device, "vkDestroyDevice")
    ptrVkGetDeviceQueue = vkGetDeviceProcAddr(device, "vkGetDeviceQueue")
    ptrVkDeviceWaitIdle = vkGetDeviceProcAddr(device, "vkDeviceWaitIdle")

    // Swapchain functions
    ptrVkCreateSwapchainKHR = vkGetDeviceProcAddr(device, "vkCreateSwapchainKHR")
    ptrVkDestroySwapchainKHR = vkGetDeviceProcAddr(device, "vkDestroySwapchainKHR")
    ptrVkGetSwapchainImagesKHR = vkGetDeviceProcAddr(device, "vkGetSwapchainImagesKHR")
    ptrVkAcquireNextImageKHR = vkGetDeviceProcAddr(device, "vkAcquireNextImageKHR")
    ptrVkQueuePresentKHR = vkGetDeviceProcAddr(device, "vkQueuePresentKHR")

    // Image view & render pass functions
    ptrVkCreateImageView = vkGetDeviceProcAddr(device, "vkCreateImageView")
    ptrVkDestroyImageView = vkGetDeviceProcAddr(device, "vkDestroyImageView")
    ptrVkCreateRenderPass = vkGetDeviceProcAddr(device, "vkCreateRenderPass")
    ptrVkDestroyRenderPass = vkGetDeviceProcAddr(device, "vkDestroyRenderPass")

    // Pipeline functions
    ptrVkCreateShaderModule = vkGetDeviceProcAddr(device, "vkCreateShaderModule")
    ptrVkDestroyShaderModule = vkGetDeviceProcAddr(device, "vkDestroyShaderModule")
    ptrVkCreatePipelineLayout = vkGetDeviceProcAddr(device, "vkCreatePipelineLayout")
    ptrVkDestroyPipelineLayout = vkGetDeviceProcAddr(device, "vkDestroyPipelineLayout")
    ptrVkCreateGraphicsPipelines = vkGetDeviceProcAddr(device, "vkCreateGraphicsPipelines")
    ptrVkDestroyPipeline = vkGetDeviceProcAddr(device, "vkDestroyPipeline")

    // Framebuffer functions
    ptrVkCreateFramebuffer = vkGetDeviceProcAddr(device, "vkCreateFramebuffer")
    ptrVkDestroyFramebuffer = vkGetDeviceProcAddr(device, "vkDestroyFramebuffer")

    // Command buffer functions
    ptrVkCreateCommandPool = vkGetDeviceProcAddr(device, "vkCreateCommandPool")
    ptrVkDestroyCommandPool = vkGetDeviceProcAddr(device, "vkDestroyCommandPool")
    ptrVkAllocateCommandBuffers = vkGetDeviceProcAddr(device, "vkAllocateCommandBuffers")
    ptrVkBeginCommandBuffer = vkGetDeviceProcAddr(device, "vkBeginCommandBuffer")
    ptrVkEndCommandBuffer = vkGetDeviceProcAddr(device, "vkEndCommandBuffer")
    ptrVkResetCommandBuffer = vkGetDeviceProcAddr(device, "vkResetCommandBuffer")
    ptrVkCmdBeginRenderPass = vkGetDeviceProcAddr(device, "vkCmdBeginRenderPass")
    ptrVkCmdEndRenderPass = vkGetDeviceProcAddr(device, "vkCmdEndRenderPass")
    ptrVkCmdBindPipeline = vkGetDeviceProcAddr(device, "vkCmdBindPipeline")
    ptrVkCmdSetViewport = vkGetDeviceProcAddr(device, "vkCmdSetViewport")
    ptrVkCmdSetScissor = vkGetDeviceProcAddr(device, "vkCmdSetScissor")
    ptrVkCmdDraw = vkGetDeviceProcAddr(device, "vkCmdDraw")

    // Synchronization objects
    ptrVkCreateSemaphore = vkGetDeviceProcAddr(device, "vkCreateSemaphore")
    ptrVkDestroySemaphore = vkGetDeviceProcAddr(device, "vkDestroySemaphore")
    ptrVkCreateFence = vkGetDeviceProcAddr(device, "vkCreateFence")
    ptrVkDestroyFence = vkGetDeviceProcAddr(device, "vkDestroyFence")
    ptrVkWaitForFences = vkGetDeviceProcAddr(device, "vkWaitForFences")
    ptrVkResetFences = vkGetDeviceProcAddr(device, "vkResetFences")
    ptrVkQueueSubmit = vkGetDeviceProcAddr(device, "vkQueueSubmit")
}

// =============================================================================
// Vulkan Initialization Functions
// =============================================================================

func createInstance() {
    appName := cstr("Hello Vulkan (Go)")
    engineName := cstr("No Engine")

    appInfo := VkApplicationInfo{
        SType:              VK_STRUCTURE_TYPE_APPLICATION_INFO,
        PApplicationName:   appName,
        ApplicationVersion: 1,
        PEngineName:        engineName,
        EngineVersion:      1,
        ApiVersion:         (1 << 22) | (4 << 12), // VK_API_VERSION_1_4
    }

    extensions := []*byte{
        cstr("VK_KHR_surface"),
        cstr("VK_KHR_win32_surface"),
    }
    if ENABLE_VALIDATION {
        extensions = append(extensions, cstr("VK_EXT_debug_utils"))
    }

    layers := []*byte{cstr("VK_LAYER_KHRONOS_validation")}

    createInfo := VkInstanceCreateInfo{
        SType:                   VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
        PApplicationInfo:        &appInfo,
        EnabledExtensionCount:   uint32(len(extensions)),
        PpEnabledExtensionNames: &extensions[0],
    }

    if ENABLE_VALIDATION {
        createInfo.EnabledLayerCount = uint32(len(layers))
        createInfo.PpEnabledLayerNames = &layers[0]
    }

    ret, _, _ := syscall.SyscallN(ptrVkCreateInstance,
        uintptr(unsafe.Pointer(&createInfo)),
        0,
        uintptr(unsafe.Pointer(&app.instance)))
    check(int32(ret), "Failed to create instance")

    loadInstanceFunctions(app.instance)
}

func createSurface() {
    createInfo := VkWin32SurfaceCreateInfoKHR{
        SType:     VK_STRUCTURE_TYPE_WIN32_SURFACE_CREATE_INFO_KHR,
        Hinstance: app.hInstance,
        Hwnd:      app.hwnd,
    }

    ret, _, _ := syscall.SyscallN(ptrVkCreateWin32SurfaceKHR,
        uintptr(app.instance),
        uintptr(unsafe.Pointer(&createInfo)),
        0,
        uintptr(unsafe.Pointer(&app.surface)))
    check(int32(ret), "Failed to create surface")
}

func pickPhysicalDevice() {
    var deviceCount uint32
    syscall.SyscallN(ptrVkEnumeratePhysicalDevices,
        uintptr(app.instance),
        uintptr(unsafe.Pointer(&deviceCount)),
        0)

    if deviceCount == 0 {
        panic("No Vulkan devices found")
    }

    devices := make([]VkPhysicalDevice, deviceCount)
    syscall.SyscallN(ptrVkEnumeratePhysicalDevices,
        uintptr(app.instance),
        uintptr(unsafe.Pointer(&deviceCount)),
        uintptr(unsafe.Pointer(&devices[0])))

    // Use first device
    app.physicalDevice = devices[0]

    // Find queue families
    var queueFamilyCount uint32
    syscall.SyscallN(ptrVkGetPhysicalDeviceQueueFamilyProperties,
        uintptr(app.physicalDevice),
        uintptr(unsafe.Pointer(&queueFamilyCount)),
        0)

    queueFamilies := make([]VkQueueFamilyProperties, queueFamilyCount)
    syscall.SyscallN(ptrVkGetPhysicalDeviceQueueFamilyProperties,
        uintptr(app.physicalDevice),
        uintptr(unsafe.Pointer(&queueFamilyCount)),
        uintptr(unsafe.Pointer(&queueFamilies[0])))

    foundGraphics := false
    foundPresent := false

    for i := uint32(0); i < queueFamilyCount; i++ {
        if (queueFamilies[i].QueueFlags&VK_QUEUE_GRAPHICS_BIT) != 0 && !foundGraphics {
            app.graphicsFamily = i
            foundGraphics = true
        }

        var presentSupport uint32
        syscall.SyscallN(ptrVkGetPhysicalDeviceSurfaceSupportKHR,
            uintptr(app.physicalDevice),
            uintptr(i),
            uintptr(app.surface),
            uintptr(unsafe.Pointer(&presentSupport)))

        if presentSupport != 0 && !foundPresent {
            app.presentFamily = i
            foundPresent = true
        }

        if foundGraphics && foundPresent {
            break
        }
    }

    if !foundGraphics || !foundPresent {
        panic("Failed to find suitable queue families")
    }
}

func createLogicalDevice() {
    queuePriority := float32(1.0)

    queueCreateInfos := make([]VkDeviceQueueCreateInfo, 0, 2)

    queueCreateInfos = append(queueCreateInfos, VkDeviceQueueCreateInfo{
        SType:            VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
        QueueFamilyIndex: app.graphicsFamily,
        QueueCount:       1,
        PQueuePriorities: &queuePriority,
    })

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
        uintptr(unsafe.Pointer(&createInfo)),
        0,
        uintptr(unsafe.Pointer(&app.device)))
    check(int32(ret), "Failed to create logical device")

    loadDeviceFunctions(app.device)

    syscall.SyscallN(ptrVkGetDeviceQueue,
        uintptr(app.device),
        uintptr(app.graphicsFamily),
        0,
        uintptr(unsafe.Pointer(&app.graphicsQueue)))

    syscall.SyscallN(ptrVkGetDeviceQueue,
        uintptr(app.device),
        uintptr(app.presentFamily),
        0,
        uintptr(unsafe.Pointer(&app.presentQueue)))
}

func createSwapChain() {
    var caps VkSurfaceCapabilitiesKHR
    syscall.SyscallN(ptrVkGetPhysicalDeviceSurfaceCapabilitiesKHR,
        uintptr(app.physicalDevice),
        uintptr(app.surface),
        uintptr(unsafe.Pointer(&caps)))

    var formatCount uint32
    syscall.SyscallN(ptrVkGetPhysicalDeviceSurfaceFormatsKHR,
        uintptr(app.physicalDevice),
        uintptr(app.surface),
        uintptr(unsafe.Pointer(&formatCount)),
        0)

    formats := make([]VkSurfaceFormatKHR, formatCount)
    syscall.SyscallN(ptrVkGetPhysicalDeviceSurfaceFormatsKHR,
        uintptr(app.physicalDevice),
        uintptr(app.surface),
        uintptr(unsafe.Pointer(&formatCount)),
        uintptr(unsafe.Pointer(&formats[0])))

    var modeCount uint32
    syscall.SyscallN(ptrVkGetPhysicalDeviceSurfacePresentModesKHR,
        uintptr(app.physicalDevice),
        uintptr(app.surface),
        uintptr(unsafe.Pointer(&modeCount)),
        0)

    modes := make([]uint32, modeCount)
    syscall.SyscallN(ptrVkGetPhysicalDeviceSurfacePresentModesKHR,
        uintptr(app.physicalDevice),
        uintptr(app.surface),
        uintptr(unsafe.Pointer(&modeCount)),
        uintptr(unsafe.Pointer(&modes[0])))

    // Choose format
    surfaceFormat := formats[0]
    for _, f := range formats {
        if f.Format == VK_FORMAT_B8G8R8A8_SRGB && f.ColorSpace == VK_COLOR_SPACE_SRGB_NONLINEAR_KHR {
            surfaceFormat = f
            break
        }
    }

    // Choose present mode
    presentMode := uint32(VK_PRESENT_MODE_FIFO_KHR)
    for _, m := range modes {
        if m == VK_PRESENT_MODE_MAILBOX_KHR {
            presentMode = VK_PRESENT_MODE_MAILBOX_KHR
            break
        }
    }

    // Choose extent
    extent := caps.CurrentExtent
    if extent.Width == 0xFFFFFFFF {
        extent.Width = WIDTH
        extent.Height = HEIGHT
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
        uintptr(app.device),
        uintptr(unsafe.Pointer(&createInfo)),
        0,
        uintptr(unsafe.Pointer(&app.swapChain)))
    check(int32(ret), "Failed to create swap chain")

    app.swapChainImageFormat = surfaceFormat.Format
    app.swapChainExtent = extent

    // Get images
    syscall.SyscallN(ptrVkGetSwapchainImagesKHR,
        uintptr(app.device),
        uintptr(app.swapChain),
        uintptr(unsafe.Pointer(&imageCount)),
        0)

    app.swapChainImages = make([]VkImage, imageCount)
    syscall.SyscallN(ptrVkGetSwapchainImagesKHR,
        uintptr(app.device),
        uintptr(app.swapChain),
        uintptr(unsafe.Pointer(&imageCount)),
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
                R: VK_COMPONENT_SWIZZLE_IDENTITY,
                G: VK_COMPONENT_SWIZZLE_IDENTITY,
                B: VK_COMPONENT_SWIZZLE_IDENTITY,
                A: VK_COMPONENT_SWIZZLE_IDENTITY,
            },
            SubresourceRange: VkImageSubresourceRange{
                AspectMask:     VK_IMAGE_ASPECT_COLOR_BIT,
                BaseMipLevel:   0,
                LevelCount:     1,
                BaseArrayLayer: 0,
                LayerCount:     1,
            },
        }

        ret, _, _ := syscall.SyscallN(ptrVkCreateImageView,
            uintptr(app.device),
            uintptr(unsafe.Pointer(&createInfo)),
            0,
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
        Attachment: 0,
        Layout:     VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
    }

    subpass := VkSubpassDescription{
        PipelineBindPoint:    VK_PIPELINE_BIND_POINT_GRAPHICS,
        ColorAttachmentCount: 1,
        PColorAttachments:    &colorAttachmentRef,
    }

    dependency := VkSubpassDependency{
        SrcSubpass:    VK_SUBPASS_EXTERNAL,
        DstSubpass:    0,
        SrcStageMask:  VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT,
        SrcAccessMask: 0,
        DstStageMask:  VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT,
        DstAccessMask: VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT,
    }

    renderPassInfo := VkRenderPassCreateInfo{
        SType:           VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO,
        AttachmentCount: 1,
        PAttachments:    &colorAttachment,
        SubpassCount:    1,
        PSubpasses:      &subpass,
        DependencyCount: 1,
        PDependencies:   &dependency,
    }

    ret, _, _ := syscall.SyscallN(ptrVkCreateRenderPass,
        uintptr(app.device),
        uintptr(unsafe.Pointer(&renderPassInfo)),
        0,
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
    ret, _, _ := syscall.SyscallN(ptrVkCreateShaderModule,
        uintptr(app.device),
        uintptr(unsafe.Pointer(&createInfo)),
        0,
        uintptr(unsafe.Pointer(&shaderModule)))
    check(int32(ret), "Failed to create shader module")

    return shaderModule
}

func createGraphicsPipeline() {
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
        Topology: VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST,
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
        CullMode:    VK_CULL_MODE_BACK_BIT,
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

    pipelineLayoutInfo := VkPipelineLayoutCreateInfo{
        SType: VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO,
    }

    ret, _, _ := syscall.SyscallN(ptrVkCreatePipelineLayout,
        uintptr(app.device),
        uintptr(unsafe.Pointer(&pipelineLayoutInfo)),
        0,
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
        Subpass:             0,
        BasePipelineIndex:   -1,
    }

    ret, _, _ = syscall.SyscallN(ptrVkCreateGraphicsPipelines,
        uintptr(app.device),
        0,
        1,
        uintptr(unsafe.Pointer(&pipelineInfo)),
        0,
        uintptr(unsafe.Pointer(&app.graphicsPipeline)))
    check(int32(ret), "Failed to create graphics pipeline")

    syscall.SyscallN(ptrVkDestroyShaderModule, uintptr(app.device), uintptr(fragShaderModule), 0)
    syscall.SyscallN(ptrVkDestroyShaderModule, uintptr(app.device), uintptr(vertShaderModule), 0)
}

func createFramebuffers() {
    app.swapChainFramebuffers = make([]VkFramebuffer, len(app.swapChainImageViews))

    for i, imageView := range app.swapChainImageViews {
        attachments := []VkImageView{imageView}

        framebufferInfo := VkFramebufferCreateInfo{
            SType:           VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO,
            RenderPass:      app.renderPass,
            AttachmentCount: 1,
            PAttachments:    &attachments[0],
            Width:           app.swapChainExtent.Width,
            Height:          app.swapChainExtent.Height,
            Layers:          1,
        }

        ret, _, _ := syscall.SyscallN(ptrVkCreateFramebuffer,
            uintptr(app.device),
            uintptr(unsafe.Pointer(&framebufferInfo)),
            0,
            uintptr(unsafe.Pointer(&app.swapChainFramebuffers[i])))
        check(int32(ret), "Failed to create framebuffer")
    }
}

func createCommandPool() {
    poolInfo := VkCommandPoolCreateInfo{
        SType:            VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO,
        Flags:            VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT,
        QueueFamilyIndex: app.graphicsFamily,
    }

    ret, _, _ := syscall.SyscallN(ptrVkCreateCommandPool,
        uintptr(app.device),
        uintptr(unsafe.Pointer(&poolInfo)),
        0,
        uintptr(unsafe.Pointer(&app.commandPool)))
    check(int32(ret), "Failed to create command pool")
}

func createCommandBuffers() {
    app.commandBuffers = make([]VkCommandBuffer, MAX_FRAMES_IN_FLIGHT)

    allocInfo := VkCommandBufferAllocateInfo{
        SType:              VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
        CommandPool:        app.commandPool,
        Level:              VK_COMMAND_BUFFER_LEVEL_PRIMARY,
        CommandBufferCount: MAX_FRAMES_IN_FLIGHT,
    }

    ret, _, _ := syscall.SyscallN(ptrVkAllocateCommandBuffers,
        uintptr(app.device),
        uintptr(unsafe.Pointer(&allocInfo)),
        uintptr(unsafe.Pointer(&app.commandBuffers[0])))
    check(int32(ret), "Failed to allocate command buffers")
}

func createSyncObjects() {
    semaphoreInfo := VkSemaphoreCreateInfo{
        SType: VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO,
    }

    fenceInfo := VkFenceCreateInfo{
        SType: VK_STRUCTURE_TYPE_FENCE_CREATE_INFO,
        Flags: VK_FENCE_CREATE_SIGNALED_BIT,
    }

    for i := 0; i < MAX_FRAMES_IN_FLIGHT; i++ {
        ret1, _, _ := syscall.SyscallN(ptrVkCreateSemaphore,
            uintptr(app.device),
            uintptr(unsafe.Pointer(&semaphoreInfo)),
            0,
            uintptr(unsafe.Pointer(&app.imageAvailableSemaphores[i])))

        ret2, _, _ := syscall.SyscallN(ptrVkCreateSemaphore,
            uintptr(app.device),
            uintptr(unsafe.Pointer(&semaphoreInfo)),
            0,
            uintptr(unsafe.Pointer(&app.renderFinishedSemaphores[i])))

        ret3, _, _ := syscall.SyscallN(ptrVkCreateFence,
            uintptr(app.device),
            uintptr(unsafe.Pointer(&fenceInfo)),
            0,
            uintptr(unsafe.Pointer(&app.inFlightFences[i])))

        if int32(ret1) != VK_SUCCESS || int32(ret2) != VK_SUCCESS || int32(ret3) != VK_SUCCESS {
            panic("Failed to create sync objects")
        }
    }
}

func recordCommandBuffer(commandBuffer VkCommandBuffer, imageIndex uint32) {
    beginInfo := VkCommandBufferBeginInfo{
        SType: VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
    }

    ret, _, _ := syscall.SyscallN(ptrVkBeginCommandBuffer,
        uintptr(commandBuffer),
        uintptr(unsafe.Pointer(&beginInfo)))
    check(int32(ret), "Failed to begin command buffer")

    clearColor := VkClearValue{
        Color: VkClearColorValue{
            Float32: [4]float32{0.0, 0.0, 0.0, 1.0},
        },
    }

    renderPassInfo := VkRenderPassBeginInfo{
        SType:       VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO,
        RenderPass:  app.renderPass,
        Framebuffer: app.swapChainFramebuffers[imageIndex],
        RenderArea: VkRect2D{
            Offset: VkOffset2D{X: 0, Y: 0},
            Extent: app.swapChainExtent,
        },
        ClearValueCount: 1,
        PClearValues:    &clearColor,
    }

    syscall.SyscallN(ptrVkCmdBeginRenderPass,
        uintptr(commandBuffer),
        uintptr(unsafe.Pointer(&renderPassInfo)),
        uintptr(VK_SUBPASS_CONTENTS_INLINE))

    syscall.SyscallN(ptrVkCmdBindPipeline,
        uintptr(commandBuffer),
        uintptr(VK_PIPELINE_BIND_POINT_GRAPHICS),
        uintptr(app.graphicsPipeline))

    viewport := VkViewport{
        X:        0.0,
        Y:        0.0,
        Width:    float32(app.swapChainExtent.Width),
        Height:   float32(app.swapChainExtent.Height),
        MinDepth: 0.0,
        MaxDepth: 1.0,
    }
    syscall.SyscallN(ptrVkCmdSetViewport, uintptr(commandBuffer), 0, 1, uintptr(unsafe.Pointer(&viewport)))

    scissor := VkRect2D{
        Offset: VkOffset2D{X: 0, Y: 0},
        Extent: app.swapChainExtent,
    }
    syscall.SyscallN(ptrVkCmdSetScissor, uintptr(commandBuffer), 0, 1, uintptr(unsafe.Pointer(&scissor)))

    syscall.SyscallN(ptrVkCmdDraw, uintptr(commandBuffer), 3, 1, 0, 0)

    syscall.SyscallN(ptrVkCmdEndRenderPass, uintptr(commandBuffer))

    ret, _, _ = syscall.SyscallN(ptrVkEndCommandBuffer, uintptr(commandBuffer))
    check(int32(ret), "Failed to record command buffer")
}

func drawFrame() {
    syscall.SyscallN(ptrVkWaitForFences,
        uintptr(app.device),
        1,
        uintptr(unsafe.Pointer(&app.inFlightFences[app.currentFrame])),
        1,
        0xFFFFFFFFFFFFFFFF)

    var imageIndex uint32
    result, _, _ := syscall.SyscallN(ptrVkAcquireNextImageKHR,
        uintptr(app.device),
        uintptr(app.swapChain),
        0xFFFFFFFFFFFFFFFF,
        uintptr(app.imageAvailableSemaphores[app.currentFrame]),
        0,
        uintptr(unsafe.Pointer(&imageIndex)))

    if int32(result) == VK_ERROR_OUT_OF_DATE_KHR {
        return
    }

    syscall.SyscallN(ptrVkResetFences,
        uintptr(app.device),
        1,
        uintptr(unsafe.Pointer(&app.inFlightFences[app.currentFrame])))

    syscall.SyscallN(ptrVkResetCommandBuffer,
        uintptr(app.commandBuffers[app.currentFrame]),
        0)

    recordCommandBuffer(app.commandBuffers[app.currentFrame], imageIndex)

    waitSemaphores := []VkSemaphore{app.imageAvailableSemaphores[app.currentFrame]}
    waitStages := []uint32{VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT}
    signalSemaphores := []VkSemaphore{app.renderFinishedSemaphores[app.currentFrame]}

    submitInfo := VkSubmitInfo{
        SType:                VK_STRUCTURE_TYPE_SUBMIT_INFO,
        WaitSemaphoreCount:   1,
        PWaitSemaphores:      &waitSemaphores[0],
        PWaitDstStageMask:    &waitStages[0],
        CommandBufferCount:   1,
        PCommandBuffers:      &app.commandBuffers[app.currentFrame],
        SignalSemaphoreCount: 1,
        PSignalSemaphores:    &signalSemaphores[0],
    }

    ret, _, _ := syscall.SyscallN(ptrVkQueueSubmit,
        uintptr(app.graphicsQueue),
        1,
        uintptr(unsafe.Pointer(&submitInfo)),
        uintptr(app.inFlightFences[app.currentFrame]))
    check(int32(ret), "Failed to submit draw command buffer")

    swapChains := []VkSwapchainKHR{app.swapChain}

    presentInfo := VkPresentInfoKHR{
        SType:              VK_STRUCTURE_TYPE_PRESENT_INFO_KHR,
        WaitSemaphoreCount: 1,
        PWaitSemaphores:    &signalSemaphores[0],
        SwapchainCount:     1,
        PSwapchains:        &swapChains[0],
        PImageIndices:      &imageIndex,
    }

    syscall.SyscallN(ptrVkQueuePresentKHR,
        uintptr(app.presentQueue),
        uintptr(unsafe.Pointer(&presentInfo)))

    app.currentFrame = (app.currentFrame + 1) % MAX_FRAMES_IN_FLIGHT
}

func cleanup() {
    syscall.SyscallN(ptrVkDeviceWaitIdle, uintptr(app.device))

    for i := 0; i < MAX_FRAMES_IN_FLIGHT; i++ {
        syscall.SyscallN(ptrVkDestroySemaphore, uintptr(app.device), uintptr(app.renderFinishedSemaphores[i]), 0)
        syscall.SyscallN(ptrVkDestroySemaphore, uintptr(app.device), uintptr(app.imageAvailableSemaphores[i]), 0)
        syscall.SyscallN(ptrVkDestroyFence, uintptr(app.device), uintptr(app.inFlightFences[i]), 0)
    }

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
    createInstance()
    createSurface()
    pickPhysicalDevice()
    createLogicalDevice()
    createSwapChain()
    createImageViews()
    createRenderPass()
    createGraphicsPipeline()
    createFramebuffers()
    createCommandPool()
    createCommandBuffers()
    createSyncObjects()
}

// =============================================================================
// Windows Window Handling
// =============================================================================

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
)

var (
    gdi32            = syscall.NewLazyDLL("gdi32.dll")
    procGetStockObject = gdi32.NewProc("GetStockObject")
)

var (
    kernel32             = syscall.NewLazyDLL("kernel32.dll")
    procGetModuleHandleW = kernel32.NewProc("GetModuleHandleW")
    procSleep            = kernel32.NewProc("Sleep")
)

func wndProc(hwnd syscall.Handle, msg uint32, wparam, lparam uintptr) uintptr {
    switch msg {
    case WM_CLOSE, WM_DESTROY:
        procPostQuitMessage.Call(0)
        return 0
    default:
        ret, _, _ := procDefWindowProcW.Call(uintptr(hwnd), uintptr(msg), wparam, lparam)
        return ret
    }
}

func main() {
    runtime.LockOSThread()

    // Load Vulkan
    if !loadVulkan() {
        return
    }

    // Get module handle
    ret, _, _ := procGetModuleHandleW.Call(0)
    app.hInstance = syscall.Handle(ret)

    // Register window class
    className := "VulkanTriangle"
    wcx := WNDCLASSEXW{
        Style:      CS_OWNDC,
        WndProc:    syscall.NewCallback(wndProc),
        Instance:   app.hInstance,
        Cursor:     loadCursor(0, IDC_ARROW),
        Background: getStockObject(BLACK_BRUSH),
        ClassName:  syscall.StringToUTF16Ptr(className),
    }
    wcx.Size = uint32(unsafe.Sizeof(wcx))
    wcx.Icon = loadIcon(0, IDI_APPLICATION)
    wcx.IconSm = wcx.Icon

    procRegisterClassEx.Call(uintptr(unsafe.Pointer(&wcx)))

    // Create window
    ret, _, _ = procCreateWindowExW.Call(
        0,
        uintptr(unsafe.Pointer(syscall.StringToUTF16Ptr(className))),
        uintptr(unsafe.Pointer(syscall.StringToUTF16Ptr("Hello Vulkan (Go)"))),
        uintptr(WS_OVERLAPPEDWINDOW),
        uintptr(CW_USEDEFAULT),
        uintptr(CW_USEDEFAULT),
        uintptr(WIDTH),
        uintptr(HEIGHT),
        0, 0,
        uintptr(app.hInstance),
        0,
    )
    app.hwnd = syscall.Handle(ret)

    procShowWindow.Call(uintptr(app.hwnd), 5)

    // Initialize Vulkan
    initVulkan()
    fmt.Println("Vulkan initialized successfully!")

    // Main loop
    quit := false
    for !quit {
        var msg MSG
        ret, _, _ := procPeekMessageW.Call(
            uintptr(unsafe.Pointer(&msg)),
            0, 0, 0,
            uintptr(PM_REMOVE),
        )
        if ret != 0 {
            if msg.Message == WM_QUIT {
                quit = true
            } else {
                procTranslateMsg.Call(uintptr(unsafe.Pointer(&msg)))
                procDispatchMessage.Call(uintptr(unsafe.Pointer(&msg)))
            }
        } else {
            drawFrame()
        }
    }

    // Cleanup
    cleanup()
    procDestroyWindow.Call(uintptr(app.hwnd))
}

func loadCursor(hInstance syscall.Handle, cursorName uint32) syscall.Handle {
    ret, _, _ := procLoadCursorW.Call(uintptr(hInstance), uintptr(cursorName))
    return syscall.Handle(ret)
}

func loadIcon(hInstance syscall.Handle, iconName uint32) syscall.Handle {
    ret, _, _ := procLoadIconW.Call(uintptr(hInstance), uintptr(iconName))
    return syscall.Handle(ret)
}

func getStockObject(fnObject int32) syscall.Handle {
    ret, _, _ := procGetStockObject.Call(uintptr(fnObject))
    return syscall.Handle(ret)
}
