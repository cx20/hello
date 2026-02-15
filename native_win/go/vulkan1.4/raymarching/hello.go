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

    VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT = 0x00000400
    VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT          = 0x00000100

    VK_SHADER_STAGE_VERTEX_BIT   = 0x00000001
    VK_SHADER_STAGE_FRAGMENT_BIT = 0x00000010

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

// Push constants structure (matches shader layout)
type PushConstants struct {
    ITime       float32
    Padding     float32
    IResolution [2]float32
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

    commandPool    VkCommandPool
    commandBuffers []VkCommandBuffer

    imageAvailableSemaphores [MAX_FRAMES_IN_FLIGHT]VkSemaphore
    renderFinishedSemaphores [MAX_FRAMES_IN_FLIGHT]VkSemaphore
    inFlightFences           [MAX_FRAMES_IN_FLIGHT]VkFence
    currentFrame             int

    startTime time.Time
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
    ptrVkCmdPushConstants        uintptr
    ptrVkCreateSemaphore         uintptr
    ptrVkDestroySemaphore        uintptr
    ptrVkCreateFence             uintptr
    ptrVkDestroyFence            uintptr
    ptrVkWaitForFences           uintptr
    ptrVkResetFences             uintptr
    ptrVkQueueSubmit             uintptr
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
        return false
    }

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
    ptrVkCmdPushConstants = vkGetInstanceProcAddr(app.instance, "vkCmdPushConstants")
    ptrVkCreateSemaphore = vkGetInstanceProcAddr(app.instance, "vkCreateSemaphore")
    ptrVkDestroySemaphore = vkGetInstanceProcAddr(app.instance, "vkDestroySemaphore")
    ptrVkCreateFence = vkGetInstanceProcAddr(app.instance, "vkCreateFence")
    ptrVkDestroyFence = vkGetInstanceProcAddr(app.instance, "vkDestroyFence")
    ptrVkWaitForFences = vkGetInstanceProcAddr(app.instance, "vkWaitForFences")
    ptrVkResetFences = vkGetInstanceProcAddr(app.instance, "vkResetFences")
    ptrVkQueueSubmit = vkGetInstanceProcAddr(app.instance, "vkQueueSubmit")
}

// =============================================================================
// Vulkan Initialization
// =============================================================================

func createInstance() {
    appInfo := VkApplicationInfo{
        SType:              VK_STRUCTURE_TYPE_APPLICATION_INFO,
        PApplicationName:   cstr("Ray Marching"),
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
        uintptr(unsafe.Pointer(&createInfo)), 0,
        uintptr(unsafe.Pointer(&app.surface)))
    check(int32(ret), "Failed to create window surface")
}

func pickPhysicalDevice() {
    var deviceCount uint32
    syscall.SyscallN(ptrVkEnumeratePhysicalDevices, uintptr(app.instance),
        uintptr(unsafe.Pointer(&deviceCount)), 0)

    if deviceCount == 0 {
        panic("No Vulkan devices found")
    }

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
}

func createLogicalDevice() {
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

func createGraphicsPipeline() {
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

    pipelineLayoutInfo := VkPipelineLayoutCreateInfo{
        SType:                  VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO,
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
}

func createFramebuffers() {
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
}

func createCommandPool() {
    poolInfo := VkCommandPoolCreateInfo{
        SType:            VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO,
        Flags:            VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT,
        QueueFamilyIndex: app.graphicsFamily,
    }
    ret, _, _ := syscall.SyscallN(ptrVkCreateCommandPool, uintptr(app.device),
        uintptr(unsafe.Pointer(&poolInfo)), 0, uintptr(unsafe.Pointer(&app.commandPool)))
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
    ret, _, _ := syscall.SyscallN(ptrVkAllocateCommandBuffers, uintptr(app.device),
        uintptr(unsafe.Pointer(&allocInfo)), uintptr(unsafe.Pointer(&app.commandBuffers[0])))
    check(int32(ret), "Failed to allocate command buffers")
}

func createSyncObjects() {
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
}

func recordCommandBuffer(commandBuffer VkCommandBuffer, imageIndex uint32) {
    beginInfo := VkCommandBufferBeginInfo{SType: VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO}
    ret, _, _ := syscall.SyscallN(ptrVkBeginCommandBuffer, uintptr(commandBuffer), uintptr(unsafe.Pointer(&beginInfo)))
    check(int32(ret), "Failed to begin command buffer")

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

    viewport := VkViewport{
        Width:    float32(app.swapChainExtent.Width),
        Height:   float32(app.swapChainExtent.Height),
        MaxDepth: 1.0,
    }
    syscall.SyscallN(ptrVkCmdSetViewport, uintptr(commandBuffer), 0, 1, uintptr(unsafe.Pointer(&viewport)))

    scissor := VkRect2D{Extent: app.swapChainExtent}
    syscall.SyscallN(ptrVkCmdSetScissor, uintptr(commandBuffer), 0, 1, uintptr(unsafe.Pointer(&scissor)))

    // Push constants with time and resolution
    pushConstants := PushConstants{
        ITime:       float32(time.Since(app.startTime).Seconds()),
        IResolution: [2]float32{float32(app.swapChainExtent.Width), float32(app.swapChainExtent.Height)},
    }
    syscall.SyscallN(ptrVkCmdPushConstants, uintptr(commandBuffer), uintptr(app.pipelineLayout),
        VK_SHADER_STAGE_FRAGMENT_BIT, 0, uintptr(unsafe.Sizeof(pushConstants)), uintptr(unsafe.Pointer(&pushConstants)))

    // Draw fullscreen triangle (3 vertices)
    syscall.SyscallN(ptrVkCmdDraw, uintptr(commandBuffer), 3, 1, 0, 0)

    syscall.SyscallN(ptrVkCmdEndRenderPass, uintptr(commandBuffer))
    ret, _, _ = syscall.SyscallN(ptrVkEndCommandBuffer, uintptr(commandBuffer))
    check(int32(ret), "Failed to end command buffer")
}

func drawFrame() {
    syscall.SyscallN(ptrVkWaitForFences, uintptr(app.device), 1,
        uintptr(unsafe.Pointer(&app.inFlightFences[app.currentFrame])), 1, 0xFFFFFFFFFFFFFFFF)

    var imageIndex uint32
    result, _, _ := syscall.SyscallN(ptrVkAcquireNextImageKHR, uintptr(app.device), uintptr(app.swapChain),
        0xFFFFFFFFFFFFFFFF, uintptr(app.imageAvailableSemaphores[app.currentFrame]), 0, uintptr(unsafe.Pointer(&imageIndex)))
    if int32(result) == VK_ERROR_OUT_OF_DATE_KHR {
        return
    }

    syscall.SyscallN(ptrVkResetFences, uintptr(app.device), 1, uintptr(unsafe.Pointer(&app.inFlightFences[app.currentFrame])))
    syscall.SyscallN(ptrVkResetCommandBuffer, uintptr(app.commandBuffers[app.currentFrame]), 0)
    recordCommandBuffer(app.commandBuffers[app.currentFrame], imageIndex)

    waitStages := []uint32{VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT}
    submitInfo := VkSubmitInfo{
        SType:                VK_STRUCTURE_TYPE_SUBMIT_INFO,
        WaitSemaphoreCount:   1,
        PWaitSemaphores:      &app.imageAvailableSemaphores[app.currentFrame],
        PWaitDstStageMask:    &waitStages[0],
        CommandBufferCount:   1,
        PCommandBuffers:      &app.commandBuffers[app.currentFrame],
        SignalSemaphoreCount: 1,
        PSignalSemaphores:    &app.renderFinishedSemaphores[app.currentFrame],
    }
    ret, _, _ := syscall.SyscallN(ptrVkQueueSubmit, uintptr(app.graphicsQueue), 1,
        uintptr(unsafe.Pointer(&submitInfo)), uintptr(app.inFlightFences[app.currentFrame]))
    check(int32(ret), "Failed to submit draw command buffer")

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
// Windows
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

    gdi32              = syscall.NewLazyDLL("gdi32.dll")
    procGetStockObject = gdi32.NewProc("GetStockObject")

    kernel32             = syscall.NewLazyDLL("kernel32.dll")
    procGetModuleHandleW = kernel32.NewProc("GetModuleHandleW")
)

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

    if !loadVulkan() {
        fmt.Println("Failed to load Vulkan")
        return
    }

    ret, _, _ := procGetModuleHandleW.Call(0)
    app.hInstance = syscall.Handle(ret)

    className := "VulkanRayMarching"
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
        uintptr(unsafe.Pointer(syscall.StringToUTF16Ptr("Ray Marching - Vulkan 1.4 (Go)"))),
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

    procShowWindow.Call(uintptr(app.hwnd), 5)

    initVulkan()
    app.startTime = time.Now()

    fmt.Println("===========================================")
    fmt.Println("Vulkan Ray Marching initialized!")
    fmt.Println("Shaders loaded from: hello_vert.spv, hello_frag.spv")
    fmt.Println("===========================================")

    // Main loop
    for {
        var msg MSG
        ret, _, _ := procPeekMessageW.Call(uintptr(unsafe.Pointer(&msg)), 0, 0, 0, PM_REMOVE)
        if ret != 0 {
            if msg.Message == WM_QUIT {
                break
            }
            procTranslateMsg.Call(uintptr(unsafe.Pointer(&msg)))
            procDispatchMessage.Call(uintptr(unsafe.Pointer(&msg)))
        } else {
            drawFrame()
        }
    }

    cleanup()
    procDestroyWindow.Call(uintptr(app.hwnd))
}