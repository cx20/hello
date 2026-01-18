Attribute VB_Name = "hello"
Option Explicit

' ============================================================================
'  [FIXED] Excel VBA (64-bit) + Raw Vulkan 1.4 + shaderc runtime compile
'   - Fixed padding in VkPipelineViewportStateCreateInfo & VkPipelineColorBlendStateCreateInfo
'   - No external VBA libraries
'   - Uses x64 thunk to call arbitrary function pointers
'   - Logs to C:\TEMP\vk_vba_log.txt
' ============================================================================

' -----------------------------
' Win32 / memory / proc
' -----------------------------
#If VBA7 Then
    Private Declare PtrSafe Function LoadLibraryW Lib "kernel32" (ByVal lpLibFileName As LongPtr) As LongPtr
    Private Declare PtrSafe Function FreeLibrary Lib "kernel32" (ByVal hLibModule As LongPtr) As Long
    Private Declare PtrSafe Function GetProcAddress Lib "kernel32" (ByVal hModule As LongPtr, ByVal lpProcName As String) As LongPtr
    Private Declare PtrSafe Function GetModuleHandleW Lib "kernel32" (ByVal lpModuleName As LongPtr) As LongPtr
    Private Declare PtrSafe Function GetEnvironmentVariableW Lib "kernel32" (ByVal lpName As LongPtr, ByVal lpBuffer As LongPtr, ByVal nSize As Long) As Long
    Private Declare PtrSafe Function SetDllDirectoryW Lib "kernel32" (ByVal lpPathName As LongPtr) As Long

    Private Declare PtrSafe Function VirtualAlloc Lib "kernel32" (ByVal lpAddress As LongPtr, ByVal dwSize As LongPtr, ByVal flAllocationType As Long, ByVal flProtect As Long) As LongPtr
    Private Declare PtrSafe Function VirtualFree Lib "kernel32" (ByVal lpAddress As LongPtr, ByVal dwSize As LongPtr, ByVal dwFreeType As Long) As Long
    Private Declare PtrSafe Sub RtlMoveMemory Lib "kernel32" (ByVal dst As LongPtr, ByVal src As LongPtr, ByVal cb As LongPtr)

    Private Declare PtrSafe Function CoTaskMemAlloc Lib "ole32" (ByVal cb As LongPtr) As LongPtr
    Private Declare PtrSafe Sub CoTaskMemFree Lib "ole32" (ByVal pv As LongPtr)

    Private Declare PtrSafe Function CallWindowProcW Lib "user32" (ByVal lpPrevWndFunc As LongPtr, ByVal hwnd As LongPtr, ByVal msg As LongPtr, ByVal wParam As LongPtr, ByVal lParam As LongPtr) As LongPtr
#Else
    ' 32-bit not supported
#End If

' -----------------------------
' Window / Message loop
' -----------------------------
Private Const WS_OVERLAPPEDWINDOW As Long = &HCF0000
Private Const WS_VISIBLE As Long = &H10000000
Private Const CW_USEDEFAULT As Long = &H80000000
Private Const WM_DESTROY As Long = &H2
Private Const WM_CLOSE As Long = &H10
Private Const WM_KEYDOWN As Long = &H100
Private Const VK_ESCAPE As Long = &H1B
Private Const PM_REMOVE As Long = &H1

Private Type POINTAPI
    x As Long
    y As Long
End Type

Private Type MSG_T
    hwnd As LongPtr
    message As Long
    wParam As LongPtr
    lParam As LongPtr
    time As Long
    pt As POINTAPI
End Type

Private Type WNDCLASSEXW
    cbSize As Long
    style As Long
    lpfnWndProc As LongPtr
    cbClsExtra As Long
    cbWndExtra As Long
    hInstance As LongPtr
    hIcon As LongPtr
    hCursor As LongPtr
    hbrBackground As LongPtr
    lpszMenuName As LongPtr
    lpszClassName As LongPtr
    hIconSm As LongPtr
End Type

Private Type RECT
    Left As Long
    Top As Long
    Right As Long
    Bottom As Long
End Type

Private Declare PtrSafe Function RegisterClassExW Lib "user32" (ByRef wc As WNDCLASSEXW) As Integer
Private Declare PtrSafe Function CreateWindowExW Lib "user32" ( _
    ByVal dwExStyle As Long, ByVal lpClassName As LongPtr, ByVal lpWindowName As LongPtr, _
    ByVal dwStyle As Long, ByVal x As Long, ByVal y As Long, ByVal nWidth As Long, ByVal nHeight As Long, _
    ByVal hWndParent As LongPtr, ByVal hMenu As LongPtr, ByVal hInstance As LongPtr, ByVal lpParam As LongPtr) As LongPtr
Private Declare PtrSafe Function DefWindowProcW Lib "user32" (ByVal hwnd As LongPtr, ByVal uMsg As Long, ByVal wParam As LongPtr, ByVal lParam As LongPtr) As LongPtr
Private Declare PtrSafe Function DestroyWindow Lib "user32" (ByVal hwnd As LongPtr) As Long
Private Declare PtrSafe Sub PostQuitMessage Lib "user32" (ByVal nExitCode As Long)
Private Declare PtrSafe Function PeekMessageW Lib "user32" (ByRef lpMsg As MSG_T, ByVal hwnd As LongPtr, ByVal wMsgFilterMin As Long, ByVal wMsgFilterMax As Long, ByVal wRemoveMsg As Long) As Long
Private Declare PtrSafe Function TranslateMessage Lib "user32" (ByRef lpMsg As MSG_T) As Long
Private Declare PtrSafe Function DispatchMessageW Lib "user32" (ByRef lpMsg As MSG_T) As LongPtr
Private Declare PtrSafe Function ShowWindow Lib "user32" (ByVal hwnd As LongPtr, ByVal nCmdShow As Long) As Long
Private Declare PtrSafe Function UpdateWindow Lib "user32" (ByVal hwnd As LongPtr) As Long
Private Declare PtrSafe Function GetClientRect Lib "user32" (ByVal hwnd As LongPtr, ByRef rc As RECT) As Long

' -----------------------------
' VirtualAlloc constants
' -----------------------------
Private Const MEM_COMMIT As Long = &H1000
Private Const MEM_RESERVE As Long = &H2000
Private Const MEM_RELEASE As Long = &H8000
Private Const PAGE_EXECUTE_READWRITE As Long = &H40

' ============================================================
' Logging
' ============================================================
Private Const LOG_PATH As String = "C:\TEMP\vk_vba_log.txt"
Private g_logEnabled As Boolean

' ============================================================
' Utility: ANSI string allocation (CoTaskMemAlloc)
' ============================================================
Private g_allocAnsiPtrs() As LongPtr
Private g_allocAnsiCount As Long

' ============================================================
' x64 thunk caller
'   - Build a tiny executable stub per (fnPtr, argc)
'   - Stub signature matches WNDPROC so we can call via CallWindowProcW.
'   - We pass argBase pointer in RCX (hwnd parameter).
'   - Stub loads args from [argBase + i*8] into (rcx, rdx, r8, r9) and stack,
'     loads target fn into RAX, calls it, returns RAX.
'
'  Supported: argc 0..12 (enough for this sample)
' ============================================================
Private Type THUNK_REC
    fnPtr As LongPtr
    argc As Long
    stubPtr As LongPtr
End Type

Private g_thunks() As THUNK_REC
Private g_thunkCount As Long

' ============================================================
' Vulkan constants (minimal)
' ============================================================
Private Const VK_SUCCESS As Long = 0
Private Const VK_TRUE As Long = 1
Private Const VK_FALSE As Long = 0

Private Const VK_API_VERSION_1_4 As Long = &H4010000 ' 1.4.0

Private Const VK_STRUCTURE_TYPE_APPLICATION_INFO As Long = 0
Private Const VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO As Long = 1
Private Const VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO As Long = 2
Private Const VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO As Long = 3
Private Const VK_STRUCTURE_TYPE_WIN32_SURFACE_CREATE_INFO_KHR As Long = 1000009000
Private Const VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR As Long = 1000001000
Private Const VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO As Long = 15
Private Const VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO As Long = 38
Private Const VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO As Long = 37
Private Const VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO As Long = 39
Private Const VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO As Long = 40
Private Const VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO As Long = 42
Private Const VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO As Long = 43
Private Const VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO As Long = 9
Private Const VK_STRUCTURE_TYPE_FENCE_CREATE_INFO As Long = 8
Private Const VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO As Long = 18
Private Const VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO As Long = 19
Private Const VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO As Long = 20
Private Const VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO As Long = 22
Private Const VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO As Long = 23
Private Const VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO As Long = 24
Private Const VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO As Long = 27
Private Const VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO As Long = 30
Private Const VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO As Long = 28
Private Const VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO As Long = 16
Private Const VK_STRUCTURE_TYPE_SUBMIT_INFO As Long = 4
Private Const VK_STRUCTURE_TYPE_PRESENT_INFO_KHR As Long = 1000001001
Private Const VK_STRUCTURE_TYPE_SURFACE_CAPABILITIES_KHR As Long = 1000000000 ' not a real sType; placeholder (capabilities has no sType)

Private Const VK_QUEUE_GRAPHICS_BIT As Long = &H1
Private Const VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT As Long = &H10
Private Const VK_SHARING_MODE_EXCLUSIVE As Long = 0
Private Const VK_SHARING_MODE_CONCURRENT As Long = 1
Private Const VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR As Long = &H1
Private Const VK_PRESENT_MODE_FIFO_KHR As Long = 2

Private Const VK_FORMAT_B8G8R8A8_UNORM As Long = 44
Private Const VK_COLOR_SPACE_SRGB_NONLINEAR_KHR As Long = 0

Private Const VK_IMAGE_ASPECT_COLOR_BIT As Long = &H1
Private Const VK_IMAGE_VIEW_TYPE_2D As Long = 1

Private Const VK_PIPELINE_BIND_POINT_GRAPHICS As Long = 0
Private Const VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST As Long = 3

Private Const VK_POLYGON_MODE_FILL As Long = 0
Private Const VK_CULL_MODE_NONE As Long = 0
Private Const VK_CULL_MODE_BACK_BIT As Long = &H2
Private Const VK_FRONT_FACE_CLOCKWISE As Long = 0
Private Const VK_FRONT_FACE_COUNTER_CLOCKWISE As Long = 1
Private Const VK_SAMPLE_COUNT_1_BIT As Long = 1

Private Const VK_ATTACHMENT_LOAD_OP_CLEAR As Long = 1
Private Const VK_ATTACHMENT_STORE_OP_STORE As Long = 0
Private Const VK_IMAGE_LAYOUT_UNDEFINED As Long = 0
Private Const VK_IMAGE_LAYOUT_PRESENT_SRC_KHR As Long = 1000001002
Private Const VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL As Long = 2

Private Const VK_SUBPASS_CONTENTS_INLINE As Long = 0
Private Const VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT As Long = &H2
Private Const VK_FENCE_CREATE_SIGNALED_BIT As Long = &H1

Private Const VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT As Long = &H400
Private Const VK_SUBPASS_EXTERNAL As Long = -1
Private Const VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT As Long = &H80

' Vulkan extensions
Private Const VK_KHR_SURFACE As String = "VK_KHR_surface"
Private Const VK_KHR_WIN32_SURFACE As String = "VK_KHR_win32_surface"
Private Const VK_KHR_SWAPCHAIN As String = "VK_KHR_swapchain"

' ============================================================
' shaderc constants (minimum)
' ============================================================
Private Const SHADERC_SHADER_KIND_VERTEX As Long = 0
Private Const SHADERC_SHADER_KIND_FRAGMENT As Long = 1
Private Const SHADERC_COMPILATION_STATUS_SUCCESS As Long = 0

' ============================================================
' Vulkan structs (minimal; padding for 64-bit)
' ============================================================
Private Type VkExtent2D
    width As Long
    height As Long
End Type

Private Type VkOffset2D
    x As Long
    y As Long
End Type

Private Type VkRect2D
    offset As VkOffset2D
    extent As VkExtent2D
End Type

Private Type VkApplicationInfo
    sType As Long
    pad0 As Long
    pNext As LongPtr
    pApplicationName As LongPtr
    applicationVersion As Long
    pad1 As Long
    pEngineName As LongPtr
    engineVersion As Long
    apiVersion As Long
End Type

Private Type VkInstanceCreateInfo
    sType As Long
    pad0 As Long
    pNext As LongPtr
    flags As Long
    pad1 As Long
    pApplicationInfo As LongPtr
    enabledLayerCount As Long
    pad2 As Long
    ppEnabledLayerNames As LongPtr
    enabledExtensionCount As Long
    pad3 As Long
    ppEnabledExtensionNames As LongPtr
End Type

Private Type VkWin32SurfaceCreateInfoKHR
    sType As Long
    pad0 As Long
    pNext As LongPtr
    flags As Long
    pad1 As Long
    hInstance As LongPtr
    hwnd As LongPtr
End Type

Private Type VkDeviceQueueCreateInfo
    sType As Long
    pad0 As Long
    pNext As LongPtr
    flags As Long
    queueFamilyIndex As Long
    queueCount As Long
    pad1 As Long
    pQueuePriorities As LongPtr
End Type

Private Type VkDeviceCreateInfo
    sType As Long
    pad0 As Long
    pNext As LongPtr
    flags As Long
    queueCreateInfoCount As Long
    pQueueCreateInfos As LongPtr
    enabledLayerCount As Long
    pad1 As Long
    ppEnabledLayerNames As LongPtr
    enabledExtensionCount As Long
    pad2 As Long
    ppEnabledExtensionNames As LongPtr
    pEnabledFeatures As LongPtr
End Type

Private Type VkSurfaceFormatKHR
    format As Long
    colorSpace As Long
End Type

Private Type VkSurfaceCapabilitiesKHR
    minImageCount As Long
    maxImageCount As Long
    currentExtent As VkExtent2D
    minImageExtent As VkExtent2D
    maxImageExtent As VkExtent2D
    maxImageArrayLayers As Long
    supportedTransforms As Long
    currentTransform As Long
    supportedCompositeAlpha As Long
    supportedUsageFlags As Long
End Type

Private Type VkSwapchainCreateInfoKHR
    sType As Long
    pad0 As Long
    pNext As LongPtr
    flags As Long
    surface As LongPtr
    minImageCount As Long
    imageFormat As Long
    imageColorSpace As Long
    imageExtent As VkExtent2D
    imageArrayLayers As Long
    imageUsage As Long
    imageSharingMode As Long
    queueFamilyIndexCount As Long
    pQueueFamilyIndices As LongPtr
    preTransform As Long
    compositeAlpha As Long
    presentMode As Long
    clipped As Long
    oldSwapchain As LongPtr
End Type

Private Type VkImageViewCreateInfo
    sType As Long
    pad0 As Long
    pNext As LongPtr
    flags As Long
    image As LongPtr
    viewType As Long
    format As Long
    r As Long: g As Long: b As Long: a As Long
    aspectMask As Long
    baseMipLevel As Long
    levelCount As Long
    baseArrayLayer As Long
    layerCount As Long
End Type

Private Type VkAttachmentDescription
    flags As Long
    format As Long
    samples As Long
    loadOp As Long
    storeOp As Long
    stencilLoadOp As Long
    stencilStoreOp As Long
    initialLayout As Long
    finalLayout As Long
End Type

Private Type VkAttachmentReference
    attachment As Long
    layout As Long
End Type

Private Type VkSubpassDescription
    flags As Long
    pipelineBindPoint As Long
    inputAttachmentCount As Long
    pInputAttachments As LongPtr
    colorAttachmentCount As Long
    pad0 As Long
    pColorAttachments As LongPtr
    pResolveAttachments As LongPtr
    pDepthStencilAttachment As LongPtr
    preserveAttachmentCount As Long
    pad1 As Long
    pPreserveAttachments As LongPtr
End Type

Private Type VkSubpassDependency
    srcSubpass As Long
    dstSubpass As Long
    srcStageMask As Long
    dstStageMask As Long
    srcAccessMask As Long
    dstAccessMask As Long
    dependencyFlags As Long
End Type

Private Type VkRenderPassCreateInfo
    sType As Long
    pad0 As Long
    pNext As LongPtr
    flags As Long
    attachmentCount As Long
    pAttachments As LongPtr
    subpassCount As Long
    pad1 As Long
    pSubpasses As LongPtr
    dependencyCount As Long
    pad2 As Long
    pDependencies As LongPtr
End Type

Private Type VkFramebufferCreateInfo
    sType As Long
    pad0 As Long
    pNext As LongPtr
    flags As Long
    renderPass As LongPtr
    attachmentCount As Long
    pad1 As Long
    pAttachments As LongPtr
    width As Long
    height As Long
    layers As Long
End Type

Private Type VkCommandPoolCreateInfo
    sType As Long
    pad0 As Long
    pNext As LongPtr
    flags As Long
    queueFamilyIndex As Long
End Type

Private Type VkCommandBufferAllocateInfo
    sType As Long
    pad0 As Long
    pNext As LongPtr
    commandPool As LongPtr
    level As Long
    commandBufferCount As Long
End Type

Private Type VkCommandBufferBeginInfo
    sType As Long
    pad0 As Long
    pNext As LongPtr
    flags As Long
    pad1 As Long
    pInheritanceInfo As LongPtr
End Type

Private Type VkClearColorValue
    float32_0 As Single
    float32_1 As Single
    float32_2 As Single
    float32_3 As Single
End Type

Private Type VkClearValue
    color As VkClearColorValue
End Type

Private Type VkRenderPassBeginInfo
    sType As Long
    pad0 As Long
    pNext As LongPtr
    renderPass As LongPtr
    framebuffer As LongPtr
    renderArea As VkRect2D
    clearValueCount As Long
    pad1 As Long
    pClearValues As LongPtr
End Type

Private Type VkSemaphoreCreateInfo
    sType As Long
    pad0 As Long
    pNext As LongPtr
    flags As Long
End Type

Private Type VkFenceCreateInfo
    sType As Long
    pad0 As Long
    pNext As LongPtr
    flags As Long
End Type

Private Type VkShaderModuleCreateInfo
    sType As Long
    pad0 As Long
    pNext As LongPtr
    flags As Long
    pad1 As Long
    codeSize As LongPtr
    pCode As LongPtr
End Type

Private Type VkPipelineShaderStageCreateInfo
    sType As Long
    pad0 As Long
    pNext As LongPtr
    flags As Long
    stage As Long
    module As LongPtr
    pName As LongPtr
    pSpecializationInfo As LongPtr
End Type

Private Type VkPipelineVertexInputStateCreateInfo
    sType As Long
    pad0 As Long
    pNext As LongPtr
    flags As Long
    vertexBindingDescriptionCount As Long
    pVertexBindingDescriptions As LongPtr
    vertexAttributeDescriptionCount As Long
    pad1 As Long
    pVertexAttributeDescriptions As LongPtr
End Type

Private Type VkPipelineInputAssemblyStateCreateInfo
    sType As Long
    pad0 As Long
    pNext As LongPtr
    flags As Long
    topology As Long
    primitiveRestartEnable As Long
End Type

Private Type VkViewport
    x As Single
    y As Single
    width As Single
    height As Single
    minDepth As Single
    maxDepth As Single
End Type

' --- FIX: Removed incorrect padding (pad1) ---
Private Type VkPipelineViewportStateCreateInfo
    sType As Long
    pad0 As Long
    pNext As LongPtr
    flags As Long
    viewportCount As Long
    ' pad1 As Long  <-- REMOVED. viewportCount(20)+4=24 (aligned 8)
    pViewports As LongPtr
    scissorCount As Long
    pad2 As Long    ' Needs padding: scissorCount(32)+4=36 -> 40
    pScissors As LongPtr
End Type

Private Type VkPipelineRasterizationStateCreateInfo
    sType As Long
    pad0 As Long
    pNext As LongPtr
    flags As Long
    depthClampEnable As Long
    rasterizerDiscardEnable As Long
    polygonMode As Long
    cullMode As Long
    frontFace As Long
    depthBiasEnable As Long
    depthBiasConstantFactor As Single
    depthBiasClamp As Single
    depthBiasSlopeFactor As Single
    lineWidth As Single
End Type

Private Type VkPipelineMultisampleStateCreateInfo
    sType As Long
    pad0 As Long
    pNext As LongPtr
    flags As Long
    rasterizationSamples As Long
    sampleShadingEnable As Long
    minSampleShading As Single
    pSampleMask As LongPtr
    alphaToCoverageEnable As Long
    alphaToOneEnable As Long
End Type

Private Type VkPipelineColorBlendAttachmentState
    blendEnable As Long
    srcColorBlendFactor As Long
    dstColorBlendFactor As Long
    colorBlendOp As Long
    srcAlphaBlendFactor As Long
    dstAlphaBlendFactor As Long
    alphaBlendOp As Long
    colorWriteMask As Long
End Type

' --- FIX: Removed incorrect padding (pad1) ---
Private Type VkPipelineColorBlendStateCreateInfo
    sType As Long
    pad0 As Long
    pNext As LongPtr
    flags As Long
    logicOpEnable As Long
    logicOp As Long
    attachmentCount As Long
    ' pad1 As Long <-- REMOVED. attachmentCount(28)+4=32 (aligned 8)
    pAttachments As LongPtr
    blendConstants0 As Single
    blendConstants1 As Single
    blendConstants2 As Single
    blendConstants3 As Single
End Type

Private Type VkPipelineLayoutCreateInfo
    sType As Long
    pad0 As Long
    pNext As LongPtr
    flags As Long
    setLayoutCount As Long
    pSetLayouts As LongPtr
    pushConstantRangeCount As Long
    pad1 As Long
    pPushConstantRanges As LongPtr
End Type

Private Type VkGraphicsPipelineCreateInfo
    sType As Long
    pad0 As Long
    pNext As LongPtr
    flags As Long
    stageCount As Long
    pStages As LongPtr
    pVertexInputState As LongPtr
    pInputAssemblyState As LongPtr
    pTessellationState As LongPtr
    pViewportState As LongPtr
    pRasterizationState As LongPtr
    pMultisampleState As LongPtr
    pDepthStencilState As LongPtr
    pColorBlendState As LongPtr
    pDynamicState As LongPtr
    layout As LongPtr
    renderPass As LongPtr
    subpass As Long
    pad1 As Long
    basePipelineHandle As LongPtr
    basePipelineIndex As Long
    pad2 As Long
End Type

Private Type VkSubmitInfo
    sType As Long
    pad0 As Long
    pNext As LongPtr
    waitSemaphoreCount As Long
    pad1 As Long
    pWaitSemaphores As LongPtr
    pWaitDstStageMask As LongPtr
    commandBufferCount As Long
    pad2 As Long
    pCommandBuffers As LongPtr
    signalSemaphoreCount As Long
    pad3 As Long
    pSignalSemaphores As LongPtr
End Type

Private Type VkPresentInfoKHR
    sType As Long
    pad0 As Long
    pNext As LongPtr
    waitSemaphoreCount As Long
    pad1 As Long
    pWaitSemaphores As LongPtr
    swapchainCount As Long
    pad2 As Long
    pSwapchains As LongPtr
    pImageIndices As LongPtr
    pResults As LongPtr
End Type

' ============================================================
' Global state
' ============================================================
Private g_hwnd As LongPtr
Private g_hInst As LongPtr
Private g_quit As Boolean

Private g_hVulkan As LongPtr
Private g_hShaderc As LongPtr

' Vulkan loader exports
Private p_vkGetInstanceProcAddr As LongPtr
Private p_vkGetDeviceProcAddr As LongPtr
Private p_vkCreateInstance As LongPtr

' Instance funcs
Private p_vkDestroyInstance As LongPtr
Private p_vkEnumeratePhysicalDevices As LongPtr
Private p_vkGetPhysicalDeviceQueueFamilyProperties As LongPtr
Private p_vkGetPhysicalDeviceSurfaceSupportKHR As LongPtr
Private p_vkGetPhysicalDeviceSurfaceFormatsKHR As LongPtr
Private p_vkGetPhysicalDeviceSurfaceCapabilitiesKHR As LongPtr
Private p_vkCreateWin32SurfaceKHR As LongPtr
Private p_vkDestroySurfaceKHR As LongPtr
Private p_vkCreateDevice As LongPtr

' Device funcs
Private p_vkDestroyDevice As LongPtr
Private p_vkGetDeviceQueue As LongPtr
Private p_vkCreateSwapchainKHR As LongPtr
Private p_vkDestroySwapchainKHR As LongPtr
Private p_vkGetSwapchainImagesKHR As LongPtr
Private p_vkAcquireNextImageKHR As LongPtr
Private p_vkQueuePresentKHR As LongPtr
Private p_vkCreateImageView As LongPtr
Private p_vkDestroyImageView As LongPtr
Private p_vkCreateRenderPass As LongPtr
Private p_vkDestroyRenderPass As LongPtr
Private p_vkCreateFramebuffer As LongPtr
Private p_vkDestroyFramebuffer As LongPtr
Private p_vkCreateShaderModule As LongPtr
Private p_vkDestroyShaderModule As LongPtr
Private p_vkCreatePipelineLayout As LongPtr
Private p_vkDestroyPipelineLayout As LongPtr
Private p_vkCreateGraphicsPipelines As LongPtr
Private p_vkDestroyPipeline As LongPtr
Private p_vkCreateCommandPool As LongPtr
Private p_vkDestroyCommandPool As LongPtr
Private p_vkAllocateCommandBuffers As LongPtr
Private p_vkBeginCommandBuffer As LongPtr
Private p_vkEndCommandBuffer As LongPtr
Private p_vkResetCommandBuffer As LongPtr
Private p_vkCmdBeginRenderPass As LongPtr
Private p_vkCmdEndRenderPass As LongPtr
Private p_vkCmdBindPipeline As LongPtr
Private p_vkCmdDraw As LongPtr
Private p_vkCreateSemaphore As LongPtr
Private p_vkDestroySemaphore As LongPtr
Private p_vkCreateFence As LongPtr
Private p_vkDestroyFence As LongPtr
Private p_vkWaitForFences As LongPtr
Private p_vkResetFences As LongPtr
Private p_vkQueueSubmit As LongPtr
Private p_vkDeviceWaitIdle As LongPtr

' shaderc
Private p_shaderc_compiler_initialize As LongPtr
Private p_shaderc_compiler_release As LongPtr
Private p_shaderc_compile_options_initialize As LongPtr
Private p_shaderc_compile_options_release As LongPtr
Private p_shaderc_compile_into_spv As LongPtr
Private p_shaderc_result_get_compilation_status As LongPtr
Private p_shaderc_result_get_error_message As LongPtr
Private p_shaderc_result_get_length As LongPtr
Private p_shaderc_result_get_bytes As LongPtr
Private p_shaderc_result_release As LongPtr

' Vulkan objects
Private vkInstance As LongPtr
Private vkSurface As LongPtr
Private vkPhysicalDevice As LongPtr
Private vkDevice As LongPtr
Private vkQueueGraphics As LongPtr
Private vkQueuePresent As LongPtr
Private qFamilyGraphics As Long
Private qFamilyPresent As Long

Private vkSwapchain As LongPtr
Private swapImageFormat As Long
Private swapExtent As VkExtent2D
Private swapImageCount As Long
Private swapImages() As LongPtr
Private swapImageViews() As LongPtr
Private swapFramebuffers() As LongPtr

Private vkRenderPass As LongPtr
Private vkPipelineLayout As LongPtr
Private vkPipeline As LongPtr
Private vkCommandPool As LongPtr
Private vkCmdBuffers() As LongPtr

Private semImageAvailable As LongPtr
Private semRenderFinished As LongPtr
Private fenceInFlight As LongPtr

Private shaderVertModule As LongPtr
Private shaderFragModule As LongPtr

' ============================================================
' Entry point
' ============================================================

Private Sub LogInit()
    On Error Resume Next
    If Dir$("C:\TEMP", vbDirectory) = "" Then MkDir "C:\TEMP"
    On Error GoTo 0

    g_logEnabled = True
    LogLine "============================================================"
    LogLine "START " & format$(Now, "yyyy-mm-dd hh:nn:ss.000")
    LogLine "Excel=" & Application.name & " " & Application.Version
End Sub

Private Sub LogLine(ByVal s As String)
    If Not g_logEnabled Then Exit Sub
    Dim f As Integer: f = FreeFile
    On Error Resume Next
    Open LOG_PATH For Append As #f
    Print #f, format$(Now, "hh:nn:ss.000") & " | " & s
    Close #f
    On Error GoTo 0
End Sub

Private Function HexPtr(ByVal p As LongPtr) As String
    HexPtr = "&H" & Right$("0000000000000000" & Hex$(CLngLng(p)), 16)
End Function

Private Sub LogKV(ByVal k As String, ByVal v As String)
    LogLine k & "=" & v
End Sub

Private Sub TrackAllocAnsi(ByVal p As LongPtr)
    If p = 0 Then Exit Sub
    g_allocAnsiCount = g_allocAnsiCount + 1
    ReDim Preserve g_allocAnsiPtrs(1 To g_allocAnsiCount)
    g_allocAnsiPtrs(g_allocAnsiCount) = p
End Sub

Private Sub FreeAllAnsi()
    Dim i As Long
    For i = 1 To g_allocAnsiCount
        If g_allocAnsiPtrs(i) <> 0 Then CoTaskMemFree g_allocAnsiPtrs(i)
    Next
    g_allocAnsiCount = 0
End Sub

Private Function AllocAnsiZ(ByVal s As String) As LongPtr
    Dim b() As Byte
    b = StrConv(s, vbFromUnicode) ' ANSI
    Dim n As LongPtr: n = (UBound(b) - LBound(b) + 1)
    Dim p As LongPtr: p = CoTaskMemAlloc(n + 1)
    If p = 0 Then Err.Raise 5
    RtlMoveMemory p, VarPtr(b(LBound(b))), n
    Dim z As Byte: z = 0
    RtlMoveMemory p + n, VarPtr(z), 1
    TrackAllocAnsi p
    AllocAnsiZ = p
End Function

Private Function PtrToAnsiString(ByVal p As LongPtr) As String
    If p = 0 Then PtrToAnsiString = "": Exit Function
    Dim i As LongPtr: i = 0
    Do
        Dim ch As Byte
        RtlMoveMemory VarPtr(ch), p + i, 1
        If ch = 0 Then Exit Do
        i = i + 1
    Loop
    If i = 0 Then PtrToAnsiString = "": Exit Function
    Dim b() As Byte
    ReDim b(0 To i - 1) As Byte
    RtlMoveMemory VarPtr(b(0)), p, i
    PtrToAnsiString = StrConv(b, vbUnicode)
End Function

Private Function GetEnvW(ByVal name As String) As String
    Dim buf As String
    buf = String$(2048, vbNullChar)

    Dim n As Long
    n = GetEnvironmentVariableW(StrPtr(name), StrPtr(buf), Len(buf))
    If n <= 0 Then
        GetEnvW = ""
    Else
        GetEnvW = Left$(buf, n)
    End If
End Function
Private Function FindShadercDll() As String
    Dim vulkanSdk As String
    vulkanSdk = GetEnvW("VULKAN_SDK")
    If vulkanSdk <> "" Then
        Dim p As String
        p = vulkanSdk & "\Bin\shaderc_shared.dll"
        If Dir$(p) <> "" Then
            FindShadercDll = p
            Exit Function
        End If
    End If

    Dim base As String: base = "C:\VulkanSDK\"
    Dim v As String, best As String
    v = Dir$(base & "*", vbDirectory)
    Do While v <> ""
        If v <> "." And v <> ".." Then
            On Error Resume Next
            If (GetAttr(base & v) And vbDirectory) <> 0 Then
            On Error GoTo 0
                Dim cand As String
                cand = base & v & "\Bin\shaderc_shared.dll"
                If Dir$(cand) <> "" Then best = cand
            End If
        End If
        v = Dir$
    Loop
    FindShadercDll = best
End Function

Private Function GetThunk(ByVal fnPtr As LongPtr, ByVal argc As Long) As LongPtr
    Dim i As Long
    For i = 1 To g_thunkCount
        If g_thunks(i).fnPtr = fnPtr And g_thunks(i).argc = argc Then
            GetThunk = g_thunks(i).stubPtr
            Exit Function
        End If
    Next

    Dim stub As LongPtr
    stub = BuildThunk(fnPtr, argc)

    g_thunkCount = g_thunkCount + 1
    ReDim Preserve g_thunks(1 To g_thunkCount)
    g_thunks(g_thunkCount).fnPtr = fnPtr
    g_thunks(g_thunkCount).argc = argc
    g_thunks(g_thunkCount).stubPtr = stub

    GetThunk = stub
End Function

Private Function BuildThunk(ByVal fnPtr As LongPtr, ByVal argc As Long) As LongPtr
    If argc < 0 Or argc > 12 Then Err.Raise 5, , "BuildThunk: argc out of range"

    Dim stackArgs As Long: stackArgs = 0
    If argc > 4 Then stackArgs = argc - 4

    Dim pad8 As Long: pad8 = 0
    If (stackArgs And 1) <> 0 Then pad8 = 1 ' add 8 bytes padding to keep 16B alignment
    Dim allocBytes As Long: allocBytes = &H28 + (stackArgs * 8) + (pad8 * 8) ' 0x28 = shadow(0x20)+retalign(0x8)

    ' Code buffer: worst-case ~200 bytes
    Dim codeSize As Long: codeSize = 256
    Dim mem As LongPtr
    mem = VirtualAlloc(0, codeSize, MEM_RESERVE Or MEM_COMMIT, PAGE_EXECUTE_READWRITE)
    If mem = 0 Then Err.Raise 5, , "VirtualAlloc for thunk failed"

    Dim b() As Byte
    ReDim b(0 To codeSize - 1) As Byte
    Dim p As Long: p = 0

    ' Helpers to emit bytes
    ' NOTE: VBA doesn't allow nested subs, so we inline small writers with repeated code.

    ' 4C 8B D9              mov r11, rcx   ; save argBase
    b(p) = &H4C: b(p + 1) = &H8B: b(p + 2) = &HD9: p = p + 3

    ' 48 83 EC xx           sub rsp, imm8
    b(p) = &H48: b(p + 1) = &H83: b(p + 2) = &HEC: b(p + 3) = CByte(allocBytes): p = p + 4

    ' 48 B8 imm64           mov rax, fnPtr
    b(p) = &H48: b(p + 1) = &HB8: p = p + 2
    Dim tmpLL As LongLong: tmpLL = CLngLng(fnPtr)
    RtlMoveMemory mem + p, VarPtr(tmpLL), 8
    p = p + 8

    ' Load first 4 args from [r11 + off]
    If argc >= 1 Then
        ' 49 8B 0B            mov rcx, [r11+0]
        b(p) = &H49: b(p + 1) = &H8B: b(p + 2) = &HB: p = p + 3
    End If
    If argc >= 2 Then
        ' 49 8B 53 08         mov rdx, [r11+8]
        b(p) = &H49: b(p + 1) = &H8B: b(p + 2) = &H53: b(p + 3) = &H8: p = p + 4
    End If
    If argc >= 3 Then
        ' 4D 8B 43 10         mov r8, [r11+16]
        b(p) = &H4D: b(p + 1) = &H8B: b(p + 2) = &H43: b(p + 3) = &H10: p = p + 4
    End If
    If argc >= 4 Then
        ' 4D 8B 4B 18         mov r9, [r11+24]
        b(p) = &H4D: b(p + 1) = &H8B: b(p + 2) = &H4B: b(p + 3) = &H18: p = p + 4
    End If

    ' Stack args i>=4: place at [rsp+0x20 + (i-4)*8]
    Dim i As Long
    For i = 4 To argc - 1
        Dim offArg As Byte: offArg = CByte(i * 8)
        Dim offStk As Byte: offStk = CByte(&H20 + (i - 4) * 8)

        ' 4D 8B 53 xx         mov r10, [r11+offArg]
        b(p) = &H4D: b(p + 1) = &H8B: b(p + 2) = &H53: b(p + 3) = offArg: p = p + 4
        ' 4C 89 54 24 xx      mov [rsp+offStk], r10
        b(p) = &H4C: b(p + 1) = &H89: b(p + 2) = &H54: b(p + 3) = &H24: b(p + 4) = offStk: p = p + 5
    Next

    ' FF D0                 call rax
    b(p) = &HFF: b(p + 1) = &HD0: p = p + 2

    ' 48 83 C4 xx           add rsp, imm8
    b(p) = &H48: b(p + 1) = &H83: b(p + 2) = &HC4: b(p + 3) = CByte(allocBytes): p = p + 4

    ' C3                    ret
    b(p) = &HC3: p = p + 1

    ' Copy the bytes buffer (except the imm64 already written) into mem
    ' We already wrote imm64 into mem at (mem+p_after_mov_rax_prefix), but we still copy full b then rewrite imm64.
    RtlMoveMemory mem, VarPtr(b(0)), p

    ' Rewrite imm64 again at correct position: after 3 + 4 + 2 bytes = 9
    Dim immPos As Long: immPos = 3 + 4 + 2
    RtlMoveMemory mem + immPos, VarPtr(tmpLL), 8

    BuildThunk = mem
End Function

Private Function InvokeRaw(ByVal fnPtr As LongPtr, ByVal argc As Long, ByRef argv() As LongLong) As LongLong
    Dim stub As LongPtr: stub = GetThunk(fnPtr, argc)

    Dim argMem As LongPtr
    If argc > 0 Then
        argMem = CoTaskMemAlloc(argc * 8)
        If argMem = 0 Then Err.Raise 5, , "CoTaskMemAlloc args failed"
        RtlMoveMemory argMem, VarPtr(argv(0)), argc * 8
    Else
        argMem = 0
    End If

    Dim ret As LongPtr
    ret = CallWindowProcW(stub, argMem, 0, 0, 0)

    If argMem <> 0 Then CoTaskMemFree argMem
    InvokeRaw = CLngLng(ret)
End Function

Private Function InvokePtr(ByVal fnPtr As LongPtr, ByVal argc As Long, ByRef argv() As LongLong) As LongPtr
    InvokePtr = CLngPtr(InvokeRaw(fnPtr, argc, argv))
End Function

Private Function InvokeI32(ByVal fnPtr As LongPtr, ByVal argc As Long, ByRef argv() As LongLong) As Long
    Dim r As LongLong: r = InvokeRaw(fnPtr, argc, argv)
    InvokeI32 = CLng(r And &HFFFFFFFF)
End Function

Private Function InvokeU32(ByVal fnPtr As LongPtr, ByVal argc As Long, ByRef argv() As LongLong) As Long
    Dim r As LongLong: r = InvokeRaw(fnPtr, argc, argv)
    InvokeU32 = CLng(r And &HFFFFFFFF)
End Function

Private Function InvokeRaw0(ByVal fnPtr As LongPtr) As LongLong
    Dim dummy(0 To 0) As LongLong
    InvokeRaw0 = InvokeRaw(fnPtr, 0, dummy)
End Function

Private Function InvokePtr0(ByVal fnPtr As LongPtr) As LongPtr
    InvokePtr0 = CLngPtr(InvokeRaw0(fnPtr))
End Function

'Private Function CLngPtr(ByVal v As Variant) As LongPtr
'    CLngPtr = v
'End Function

Private Sub VkCheck(ByVal res As Long, ByVal what As String)
    If res <> VK_SUCCESS Then
        LogLine "VK_FAIL " & what & " VkResult=" & CStr(res)
        Err.Raise 5, , what & " failed VkResult=" & res
    Else
        LogLine "VK_OK   " & what
    End If
End Sub

Private Function WndProc(ByVal hwnd As LongPtr, ByVal uMsg As Long, ByVal wParam As LongPtr, ByVal lParam As LongPtr) As LongPtr
    Select Case uMsg
        Case WM_KEYDOWN
            If wParam = VK_ESCAPE Then
                g_quit = True
                DestroyWindow hwnd
                WndProc = 0
                Exit Function
            End If
        Case WM_CLOSE
            g_quit = True
            DestroyWindow hwnd
            WndProc = 0
            Exit Function
        Case WM_DESTROY
            g_quit = True
            PostQuitMessage 0
            WndProc = 0
            Exit Function
    End Select
    WndProc = DefWindowProcW(hwnd, uMsg, wParam, lParam)
End Function

Private Sub CreateAppWindow(ByVal w As Long, ByVal h As Long)
    g_hInst = GetModuleHandleW(0)

    Dim clsName As String: clsName = "VBA_VK_WINDOW"
    Dim wc As WNDCLASSEXW
    wc.cbSize = LenB(wc)
    wc.lpfnWndProc = VBA.Int(AddressOf WndProc)
    wc.hInstance = g_hInst
    wc.lpszClassName = StrPtr(clsName)

    If RegisterClassExW(wc) = 0 Then Err.Raise 5, , "RegisterClassExW failed"

    Dim title As String: title = "Hello Vulkan (VBA x64 thunk)"
    g_hwnd = CreateWindowExW(0, StrPtr(clsName), StrPtr(title), WS_OVERLAPPEDWINDOW Or WS_VISIBLE, _
                            CW_USEDEFAULT, CW_USEDEFAULT, w, h, 0, 0, g_hInst, 0)
    If g_hwnd = 0 Then Err.Raise 5, , "CreateWindowExW failed"

    ShowWindow g_hwnd, 1
    UpdateWindow g_hwnd
End Sub

Private Sub LoadVulkanLoader()
    g_hVulkan = LoadLibraryW(StrPtr("vulkan-1.dll"))
    If g_hVulkan = 0 Then Err.Raise 5, , "LoadLibrary vulkan-1.dll failed"

    p_vkGetInstanceProcAddr = GetProcAddress(g_hVulkan, "vkGetInstanceProcAddr")
    p_vkGetDeviceProcAddr = GetProcAddress(g_hVulkan, "vkGetDeviceProcAddr")
    p_vkCreateInstance = GetProcAddress(g_hVulkan, "vkCreateInstance")

    If p_vkCreateInstance = 0 Or p_vkGetInstanceProcAddr = 0 Or p_vkGetDeviceProcAddr = 0 Then
        Err.Raise 5, , "GetProcAddress(vulkan loader) failed"
    End If
End Sub

Private Function VkGetInstanceProc(ByVal inst As LongPtr, ByVal name As String) As LongPtr
    Dim argv(0 To 1) As LongLong
    argv(0) = CLngLng(inst)
    argv(1) = CLngLng(AllocAnsiZ(name))
    VkGetInstanceProc = CLngPtr(InvokeRaw(p_vkGetInstanceProcAddr, 2, argv))
End Function

Private Function VkGetDeviceProc(ByVal dev As LongPtr, ByVal name As String) As LongPtr
    Dim argv(0 To 1) As LongLong
    argv(0) = CLngLng(dev)
    argv(1) = CLngLng(AllocAnsiZ(name))
    VkGetDeviceProc = CLngPtr(InvokeRaw(p_vkGetDeviceProcAddr, 2, argv))
End Function

Private Sub LoadVulkanInstanceFuncs()
    p_vkDestroyInstance = VkGetInstanceProc(vkInstance, "vkDestroyInstance")
    p_vkEnumeratePhysicalDevices = VkGetInstanceProc(vkInstance, "vkEnumeratePhysicalDevices")
    p_vkGetPhysicalDeviceQueueFamilyProperties = VkGetInstanceProc(vkInstance, "vkGetPhysicalDeviceQueueFamilyProperties")
    p_vkCreateDevice = VkGetInstanceProc(vkInstance, "vkCreateDevice")

    p_vkCreateWin32SurfaceKHR = VkGetInstanceProc(vkInstance, "vkCreateWin32SurfaceKHR")
    p_vkDestroySurfaceKHR = VkGetInstanceProc(vkInstance, "vkDestroySurfaceKHR")
    p_vkGetPhysicalDeviceSurfaceSupportKHR = VkGetInstanceProc(vkInstance, "vkGetPhysicalDeviceSurfaceSupportKHR")
    p_vkGetPhysicalDeviceSurfaceFormatsKHR = VkGetInstanceProc(vkInstance, "vkGetPhysicalDeviceSurfaceFormatsKHR")
    p_vkGetPhysicalDeviceSurfaceCapabilitiesKHR = VkGetInstanceProc(vkInstance, "vkGetPhysicalDeviceSurfaceCapabilitiesKHR")

    If p_vkCreateWin32SurfaceKHR = 0 Then Err.Raise 5, , "vkCreateWin32SurfaceKHR not found"
    If p_vkGetPhysicalDeviceSurfaceCapabilitiesKHR = 0 Then Err.Raise 5, , "vkGetPhysicalDeviceSurfaceCapabilitiesKHR not found"
End Sub

Private Sub LoadVulkanDeviceFuncs()
    p_vkDestroyDevice = VkGetDeviceProc(vkDevice, "vkDestroyDevice")
    p_vkGetDeviceQueue = VkGetDeviceProc(vkDevice, "vkGetDeviceQueue")

    p_vkCreateSwapchainKHR = VkGetDeviceProc(vkDevice, "vkCreateSwapchainKHR")
    p_vkDestroySwapchainKHR = VkGetDeviceProc(vkDevice, "vkDestroySwapchainKHR")
    p_vkGetSwapchainImagesKHR = VkGetDeviceProc(vkDevice, "vkGetSwapchainImagesKHR")
    p_vkAcquireNextImageKHR = VkGetDeviceProc(vkDevice, "vkAcquireNextImageKHR")
    p_vkQueuePresentKHR = VkGetDeviceProc(vkDevice, "vkQueuePresentKHR")

    p_vkCreateImageView = VkGetDeviceProc(vkDevice, "vkCreateImageView")
    p_vkDestroyImageView = VkGetDeviceProc(vkDevice, "vkDestroyImageView")
    p_vkCreateRenderPass = VkGetDeviceProc(vkDevice, "vkCreateRenderPass")
    p_vkDestroyRenderPass = VkGetDeviceProc(vkDevice, "vkDestroyRenderPass")
    p_vkCreateFramebuffer = VkGetDeviceProc(vkDevice, "vkCreateFramebuffer")
    p_vkDestroyFramebuffer = VkGetDeviceProc(vkDevice, "vkDestroyFramebuffer")

    p_vkCreateShaderModule = VkGetDeviceProc(vkDevice, "vkCreateShaderModule")
    p_vkDestroyShaderModule = VkGetDeviceProc(vkDevice, "vkDestroyShaderModule")
    p_vkCreatePipelineLayout = VkGetDeviceProc(vkDevice, "vkCreatePipelineLayout")
    p_vkDestroyPipelineLayout = VkGetDeviceProc(vkDevice, "vkDestroyPipelineLayout")
    p_vkCreateGraphicsPipelines = VkGetDeviceProc(vkDevice, "vkCreateGraphicsPipelines")
    p_vkDestroyPipeline = VkGetDeviceProc(vkDevice, "vkDestroyPipeline")

    p_vkCreateCommandPool = VkGetDeviceProc(vkDevice, "vkCreateCommandPool")
    p_vkDestroyCommandPool = VkGetDeviceProc(vkDevice, "vkDestroyCommandPool")
    p_vkAllocateCommandBuffers = VkGetDeviceProc(vkDevice, "vkAllocateCommandBuffers")
    p_vkBeginCommandBuffer = VkGetDeviceProc(vkDevice, "vkBeginCommandBuffer")
    p_vkEndCommandBuffer = VkGetDeviceProc(vkDevice, "vkEndCommandBuffer")
    p_vkResetCommandBuffer = VkGetDeviceProc(vkDevice, "vkResetCommandBuffer")
    p_vkCmdBeginRenderPass = VkGetDeviceProc(vkDevice, "vkCmdBeginRenderPass")
    p_vkCmdEndRenderPass = VkGetDeviceProc(vkDevice, "vkCmdEndRenderPass")
    p_vkCmdBindPipeline = VkGetDeviceProc(vkDevice, "vkCmdBindPipeline")
    p_vkCmdDraw = VkGetDeviceProc(vkDevice, "vkCmdDraw")

    p_vkCreateSemaphore = VkGetDeviceProc(vkDevice, "vkCreateSemaphore")
    p_vkDestroySemaphore = VkGetDeviceProc(vkDevice, "vkDestroySemaphore")
    p_vkCreateFence = VkGetDeviceProc(vkDevice, "vkCreateFence")
    p_vkDestroyFence = VkGetDeviceProc(vkDevice, "vkDestroyFence")
    p_vkWaitForFences = VkGetDeviceProc(vkDevice, "vkWaitForFences")
    p_vkResetFences = VkGetDeviceProc(vkDevice, "vkResetFences")
    p_vkQueueSubmit = VkGetDeviceProc(vkDevice, "vkQueueSubmit")
    p_vkDeviceWaitIdle = VkGetDeviceProc(vkDevice, "vkDeviceWaitIdle")

    If p_vkCreateSwapchainKHR = 0 Then Err.Raise 5, , "vkCreateSwapchainKHR not found"
End Sub

Private Sub LoadShaderc()
    LogLine "LoadShaderc: begin"
    LogLine "LoadShaderc: try FindShadercDll"

    Dim path As String
    path = FindShadercDll()
    LogLine "LoadShaderc: FindShadercDll path=" & path

    If path = "" Then Err.Raise 5, , "shaderc_shared.dll not found. Install Vulkan SDK or set VULKAN_SDK."

    Dim binDir As String
    binDir = Left$(path, InStrRev(path, "\") - 1)
    Call SetDllDirectoryW(StrPtr(binDir))

    g_hShaderc = LoadLibraryW(StrPtr(path))
    If g_hShaderc = 0 Then Err.Raise 5, , "LoadLibrary shaderc_shared.dll failed: " & path

    p_shaderc_compiler_initialize = GetProcAddress(g_hShaderc, "shaderc_compiler_initialize")
    p_shaderc_compiler_release = GetProcAddress(g_hShaderc, "shaderc_compiler_release")
    p_shaderc_compile_options_initialize = GetProcAddress(g_hShaderc, "shaderc_compile_options_initialize")
    p_shaderc_compile_options_release = GetProcAddress(g_hShaderc, "shaderc_compile_options_release")
    p_shaderc_compile_into_spv = GetProcAddress(g_hShaderc, "shaderc_compile_into_spv")
    p_shaderc_result_get_compilation_status = GetProcAddress(g_hShaderc, "shaderc_result_get_compilation_status")
    p_shaderc_result_get_error_message = GetProcAddress(g_hShaderc, "shaderc_result_get_error_message")
    p_shaderc_result_get_length = GetProcAddress(g_hShaderc, "shaderc_result_get_length")
    p_shaderc_result_get_bytes = GetProcAddress(g_hShaderc, "shaderc_result_get_bytes")
    p_shaderc_result_release = GetProcAddress(g_hShaderc, "shaderc_result_release")

    If p_shaderc_compiler_initialize = 0 Or p_shaderc_compile_into_spv = 0 Then
        Err.Raise 5, , "GetProcAddress(shaderc) failed"
    End If

    LogKV "shaderc_path", path
End Sub

Private Function ShadercCompileSpv(ByVal glsl As String, ByVal kind As Long, ByVal fileName As String) As Byte()
    LogLine "shaderc compile begin file=" & fileName & " kind=" & CStr(kind)

    ' 返却用（空の場合は未初期化のまま返す）
    Dim spv() As Byte

    ' shaderc objects
    Dim compiler As LongPtr
    Dim options As LongPtr
    Dim result As LongPtr

    ' source
    Dim srcBytes() As Byte
    Dim pSrc As LongPtr
    Dim srcLen As LongLong

    ' strings
    Dim pFile As LongPtr
    Dim pEntry As LongPtr

    ' args
    Dim argv(0 To 6) As LongLong
    Dim argv1(0 To 0) As LongLong

    On Error GoTo EH

    compiler = InvokePtr0(p_shaderc_compiler_initialize)
    If compiler = 0 Then Err.Raise 5, , "shaderc_compiler_initialize failed"

    options = InvokePtr0(p_shaderc_compile_options_initialize)
    ' options が 0 でも shaderc は動く場合があるが、一応チェックしたいならここで Err.Raise

    srcBytes = StrConv(glsl, vbFromUnicode) ' ANSI bytes
    If (Not Not srcBytes) = 0 Then
        ' 空文字のケース
        LogLine "shaderc source empty"
        ShadercCompileSpv = spv
        GoTo CLEANUP
    End If

    pSrc = VarPtr(srcBytes(0))
    srcLen = CLngLng(UBound(srcBytes) - LBound(srcBytes) + 1)

    pFile = AllocAnsiZ(fileName)
    pEntry = AllocAnsiZ("main")

    argv(0) = CLngLng(compiler)
    argv(1) = CLngLng(pSrc)
    argv(2) = srcLen
    argv(3) = CLngLng(kind)
    argv(4) = CLngLng(pFile)
    argv(5) = CLngLng(pEntry)
    argv(6) = CLngLng(options)

    result = CLngPtr(InvokeRaw(p_shaderc_compile_into_spv, 7, argv))
    If result = 0 Then Err.Raise 5, , "shaderc_compile_into_spv returned NULL"

    argv1(0) = CLngLng(result)

    Dim status As Long
    status = InvokeI32(p_shaderc_result_get_compilation_status, 1, argv1)
    If status <> SHADERC_COMPILATION_STATUS_SUCCESS Then
        Dim pErr As LongPtr
        pErr = CLngPtr(InvokeRaw(p_shaderc_result_get_error_message, 1, argv1))

        Dim msg As String
        msg = PtrToAnsiString(pErr)

        LogLine "shaderc FAILED file=" & fileName & " kind=" & CStr(kind)
        LogLine "shaderc ERROR: " & msg

        Err.Raise 5, , "shaderc compile failed: " & msg
    End If

    ' ここから出力取り出し
    Dim outLenLL As LongLong
    outLenLL = CLngLng(InvokeRaw(p_shaderc_result_get_length, 1, argv1))

    If outLenLL <= 0 Then
        LogLine "shaderc compile ok but length=0"
        ShadercCompileSpv = spv
        GoTo CLEANUP
    End If

    ' VBA 配列は Long 範囲の要素数しか扱えない前提で安全化
    If outLenLL > 2147483647# Then
        Err.Raise 5, , "SPIR-V too large for VBA array: " & CStr(outLenLL)
    End If

    Dim outLen As Long
    outLen = CLng(outLenLL)

    Dim pOut As LongPtr
    pOut = CLngPtr(InvokeRaw(p_shaderc_result_get_bytes, 1, argv1))
    If pOut = 0 Then Err.Raise 5, , "shaderc_result_get_bytes returned NULL"

    ReDim spv(0 To outLen - 1) As Byte
    RtlMoveMemory VarPtr(spv(0)), pOut, CLngPtr(outLen)

    LogLine "shaderc compile ok bytes=" & CStr(outLen)
    ShadercCompileSpv = spv

CLEANUP:
    On Error Resume Next
    If result <> 0 Then
        argv1(0) = CLngLng(result)
        Call InvokeRaw(p_shaderc_result_release, 1, argv1)
        result = 0
    End If
    If options <> 0 Then
        argv1(0) = CLngLng(options)
        Call InvokeRaw(p_shaderc_compile_options_release, 1, argv1)
        options = 0
    End If
    If compiler <> 0 Then
        argv1(0) = CLngLng(compiler)
        Call InvokeRaw(p_shaderc_compiler_release, 1, argv1)
        compiler = 0
    End If
    Exit Function

EH:
    ' 失敗時も確実に解放
    LogLine "shaderc exception: " & Err.Description
    Resume CLEANUP
End Function

Private Sub VkCreateInstance_()
    Dim appInfo As VkApplicationInfo
    appInfo.sType = VK_STRUCTURE_TYPE_APPLICATION_INFO
    appInfo.pApplicationName = AllocAnsiZ("Hello Triangle")
    appInfo.applicationVersion = &H10000
    appInfo.pEngineName = AllocAnsiZ("No Engine")
    appInfo.engineVersion = &H10000
    appInfo.apiVersion = VK_API_VERSION_1_4

    Dim extPtrs(0 To 1) As LongPtr
    extPtrs(0) = AllocAnsiZ(VK_KHR_SURFACE)
    extPtrs(1) = AllocAnsiZ(VK_KHR_WIN32_SURFACE)

    Dim ci As VkInstanceCreateInfo
    ci.sType = VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO
    ci.pApplicationInfo = VarPtr(appInfo)
    ci.enabledExtensionCount = 2
    ci.ppEnabledExtensionNames = VarPtr(extPtrs(0))

    Dim pInst As LongPtr
    Dim argv(0 To 2) As LongLong
    argv(0) = CLngLng(VarPtr(ci))
    argv(1) = 0
    argv(2) = CLngLng(VarPtr(pInst))

    LogLine "call vkCreateInstance"
    Dim res As Long: res = InvokeI32(p_vkCreateInstance, 3, argv)
    VkCheck res, "vkCreateInstance"
    vkInstance = pInst

    LoadVulkanInstanceFuncs
End Sub

Private Sub VkCreateSurface_()
    Dim sci As VkWin32SurfaceCreateInfoKHR
    sci.sType = VK_STRUCTURE_TYPE_WIN32_SURFACE_CREATE_INFO_KHR
    sci.hInstance = g_hInst
    sci.hwnd = g_hwnd

    Dim pSurf As LongPtr
    Dim argv(0 To 3) As LongLong
    argv(0) = CLngLng(vkInstance)
    argv(1) = CLngLng(VarPtr(sci))
    argv(2) = 0
    argv(3) = CLngLng(VarPtr(pSurf))

    LogLine "call vkCreateWin32SurfaceKHR"
    Dim res As Long: res = InvokeI32(p_vkCreateWin32SurfaceKHR, 4, argv)
    VkCheck res, "vkCreateWin32SurfaceKHR"
    vkSurface = pSurf
End Sub

Private Sub PickPhysicalDeviceAndQueues_()
    Dim count As Long
    Dim argvC(0 To 2) As LongLong
    argvC(0) = CLngLng(vkInstance)
    argvC(1) = CLngLng(VarPtr(count))
    argvC(2) = 0

    LogLine "call vkEnumeratePhysicalDevices(count)"
    Dim res As Long: res = InvokeI32(p_vkEnumeratePhysicalDevices, 3, argvC)
    VkCheck res, "vkEnumeratePhysicalDevices(count)"
    If count <= 0 Then Err.Raise 5, , "No Vulkan physical devices"

    Dim devs() As LongPtr
    ReDim devs(0 To count - 1) As LongLong

    argvC(2) = CLngLng(VarPtr(devs(0)))
    LogLine "call vkEnumeratePhysicalDevices(list)"
    res = InvokeI32(p_vkEnumeratePhysicalDevices, 3, argvC)
    VkCheck res, "vkEnumeratePhysicalDevices(list)"
    vkPhysicalDevice = devs(0)

    ' queue families count (first call with pProps=NULL)
    Dim qCount As Long
    Dim argvQ(0 To 2) As LongLong
    argvQ(0) = CLngLng(vkPhysicalDevice)
    argvQ(1) = CLngLng(VarPtr(qCount))
    argvQ(2) = 0
    LogLine "call vkGetPhysicalDeviceQueueFamilyProperties(count)"
    Call InvokeRaw(p_vkGetPhysicalDeviceQueueFamilyProperties, 3, argvQ)
    If qCount <= 0 Then Err.Raise 5, , "No queue families"

    ' Allocate raw buffer for VkQueueFamilyProperties[qCount]
    ' Real struct size differs by driver; we only need first uint32 queueFlags.
    ' Use stride=64 to be safe.
    Dim stride As Long: stride = 64
    Dim buf() As Byte
    ReDim buf(0 To qCount * stride - 1) As Byte
    argvQ(2) = CLngLng(VarPtr(buf(0)))
    LogLine "call vkGetPhysicalDeviceQueueFamilyProperties(list)"
    Call InvokeRaw(p_vkGetPhysicalDeviceQueueFamilyProperties, 3, argvQ)

    Dim i As Long
    qFamilyGraphics = -1
    qFamilyPresent = -1

    For i = 0 To qCount - 1
        Dim flags As Long
        RtlMoveMemory VarPtr(flags), VarPtr(buf(i * stride)), 4
        If (flags And VK_QUEUE_GRAPHICS_BIT) <> 0 Then
            qFamilyGraphics = i
            Exit For
        End If
    Next
    If qFamilyGraphics < 0 Then Err.Raise 5, , "No graphics queue"

    For i = 0 To qCount - 1
        Dim supported As Long
        Dim argvS(0 To 3) As LongLong
        argvS(0) = CLngLng(vkPhysicalDevice)
        argvS(1) = CLngLng(i)
        argvS(2) = CLngLng(vkSurface)
        argvS(3) = CLngLng(VarPtr(supported))
        res = InvokeI32(p_vkGetPhysicalDeviceSurfaceSupportKHR, 4, argvS)
        VkCheck res, "vkGetPhysicalDeviceSurfaceSupportKHR"
        If supported <> 0 Then
            qFamilyPresent = i
            Exit For
        End If
    Next
    If qFamilyPresent < 0 Then Err.Raise 5, , "No present queue"
End Sub

Private Sub VkCreateDevice_()
    Dim priority As Single: priority = 1!

    Dim qci As VkDeviceQueueCreateInfo
    qci.sType = VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO
    qci.queueFamilyIndex = qFamilyGraphics
    qci.queueCount = 1
    qci.pQueuePriorities = VarPtr(priority)

    Dim extPtrs(0 To 0) As LongPtr
    extPtrs(0) = AllocAnsiZ(VK_KHR_SWAPCHAIN)

    Dim dci As VkDeviceCreateInfo
    dci.sType = VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO
    dci.queueCreateInfoCount = 1
    dci.pQueueCreateInfos = VarPtr(qci)
    dci.enabledExtensionCount = 1
    dci.ppEnabledExtensionNames = VarPtr(extPtrs(0))

    Dim pDev As LongPtr
    Dim argv(0 To 3) As LongLong
    argv(0) = CLngLng(vkPhysicalDevice)
    argv(1) = CLngLng(VarPtr(dci))
    argv(2) = 0
    argv(3) = CLngLng(VarPtr(pDev))

    LogLine "call vkCreateDevice"
    Dim res As Long: res = InvokeI32(p_vkCreateDevice, 4, argv)
    VkCheck res, "vkCreateDevice"
    vkDevice = pDev

    LoadVulkanDeviceFuncs

    Dim argvQ(0 To 3) As LongLong
    argvQ(0) = CLngLng(vkDevice)
    argvQ(1) = CLngLng(qFamilyGraphics)
    argvQ(2) = 0
    argvQ(3) = CLngLng(VarPtr(vkQueueGraphics))
    LogLine "call vkGetDeviceQueue(graphics)"
    Call InvokeRaw(p_vkGetDeviceQueue, 4, argvQ)

    argvQ(1) = CLngLng(qFamilyPresent)
    argvQ(3) = CLngLng(VarPtr(vkQueuePresent))
    LogLine "call vkGetDeviceQueue(present)"
    Call InvokeRaw(p_vkGetDeviceQueue, 4, argvQ)
End Sub

Private Sub VkCreateSwapchainAndViews_()
    ' Query surface formats
    Dim fmtCount As Long
    Dim argvF(0 To 3) As LongLong
    argvF(0) = CLngLng(vkPhysicalDevice)
    argvF(1) = CLngLng(vkSurface)
    argvF(2) = CLngLng(VarPtr(fmtCount))
    argvF(3) = 0
    LogLine "call vkGetPhysicalDeviceSurfaceFormatsKHR(count)"
    Call InvokeRaw(p_vkGetPhysicalDeviceSurfaceFormatsKHR, 4, argvF)
    If fmtCount <= 0 Then Err.Raise 5, , "No surface formats"

    Dim fmts() As VkSurfaceFormatKHR
    ReDim fmts(0 To fmtCount - 1) As VkSurfaceFormatKHR
    argvF(3) = CLngLng(VarPtr(fmts(0)))
    LogLine "call vkGetPhysicalDeviceSurfaceFormatsKHR(list)"
    Call InvokeRaw(p_vkGetPhysicalDeviceSurfaceFormatsKHR, 4, argvF)

    Dim chosenFmt As VkSurfaceFormatKHR
    chosenFmt = fmts(0)
    Dim i As Long
    For i = 0 To fmtCount - 1
        If fmts(i).format = VK_FORMAT_B8G8R8A8_UNORM And fmts(i).colorSpace = VK_COLOR_SPACE_SRGB_NONLINEAR_KHR Then
            chosenFmt = fmts(i)
            Exit For
        End If
    Next
    swapImageFormat = chosenFmt.format

    ' Capabilities (for preTransform and image count)
    Dim caps As VkSurfaceCapabilitiesKHR
    Dim argvCaps(0 To 2) As LongLong
    argvCaps(0) = CLngLng(vkPhysicalDevice)
    argvCaps(1) = CLngLng(vkSurface)
    argvCaps(2) = CLngLng(VarPtr(caps))
    LogLine "call vkGetPhysicalDeviceSurfaceCapabilitiesKHR"
    Dim res As Long: res = InvokeI32(p_vkGetPhysicalDeviceSurfaceCapabilitiesKHR, 3, argvCaps)
    VkCheck res, "vkGetPhysicalDeviceSurfaceCapabilitiesKHR"

    ' Window size
    Dim rc As RECT
    GetClientRect g_hwnd, rc
    swapExtent.width = rc.Right - rc.Left
    swapExtent.height = rc.Bottom - rc.Top

    ' Choose image count
    Dim desired As Long: desired = caps.minImageCount + 1
    If caps.maxImageCount > 0 And desired > caps.maxImageCount Then desired = caps.maxImageCount

    Dim sci As VkSwapchainCreateInfoKHR
    sci.sType = VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR
    sci.surface = vkSurface
    sci.minImageCount = desired
    sci.imageFormat = chosenFmt.format
    sci.imageColorSpace = chosenFmt.colorSpace
    sci.imageExtent = swapExtent
    sci.imageArrayLayers = 1
    sci.imageUsage = VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT

    Dim qIdx(0 To 1) As Long
    If qFamilyGraphics <> qFamilyPresent Then
        qIdx(0) = qFamilyGraphics
        qIdx(1) = qFamilyPresent
        sci.imageSharingMode = VK_SHARING_MODE_CONCURRENT
        sci.queueFamilyIndexCount = 2
        sci.pQueueFamilyIndices = VarPtr(qIdx(0))
    Else
        sci.imageSharingMode = VK_SHARING_MODE_EXCLUSIVE
        sci.queueFamilyIndexCount = 0
        sci.pQueueFamilyIndices = 0
    End If

    sci.preTransform = caps.currentTransform
    sci.compositeAlpha = VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR
    sci.presentMode = VK_PRESENT_MODE_FIFO_KHR
    sci.clipped = VK_TRUE
    sci.oldSwapchain = 0

    Dim argv(0 To 3) As LongLong
    argv(0) = CLngLng(vkDevice)
    argv(1) = CLngLng(VarPtr(sci))
    argv(2) = 0
    argv(3) = CLngLng(VarPtr(vkSwapchain))

    LogLine "call vkCreateSwapchainKHR"
    res = InvokeI32(p_vkCreateSwapchainKHR, 4, argv)
    VkCheck res, "vkCreateSwapchainKHR"

    ' Images
    Dim argvI(0 To 3) As LongLong
    argvI(0) = CLngLng(vkDevice)
    argvI(1) = CLngLng(vkSwapchain)
    argvI(2) = CLngLng(VarPtr(swapImageCount))
    argvI(3) = 0

    LogLine "call vkGetSwapchainImagesKHR(count)"
    res = InvokeI32(p_vkGetSwapchainImagesKHR, 4, argvI)
    VkCheck res, "vkGetSwapchainImagesKHR(count)"

    ReDim swapImages(0 To swapImageCount - 1) As LongLong
    argvI(3) = CLngLng(VarPtr(swapImages(0)))
    LogLine "call vkGetSwapchainImagesKHR(list)"
    res = InvokeI32(p_vkGetSwapchainImagesKHR, 4, argvI)
    VkCheck res, "vkGetSwapchainImagesKHR(list)"

    ' Views
    ReDim swapImageViews(0 To swapImageCount - 1) As LongLong
    For i = 0 To swapImageCount - 1
        Dim iv As VkImageViewCreateInfo
        iv.sType = VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO
        iv.image = swapImages(i)
        iv.viewType = VK_IMAGE_VIEW_TYPE_2D
        iv.format = swapImageFormat
        iv.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT
        iv.baseMipLevel = 0
        iv.levelCount = 1
        iv.baseArrayLayer = 0
        iv.layerCount = 1

        Dim argvV(0 To 3) As LongLong
        argvV(0) = CLngLng(vkDevice)
        argvV(1) = CLngLng(VarPtr(iv))
        argvV(2) = 0
        argvV(3) = CLngLng(VarPtr(swapImageViews(i)))

        LogLine "call vkCreateImageView i=" & CStr(i)
        res = InvokeI32(p_vkCreateImageView, 4, argvV)
        VkCheck res, "vkCreateImageView"
    Next
End Sub

Private Sub VkCreateRenderPass_()
    Dim colorAttach As VkAttachmentDescription
    colorAttach.format = swapImageFormat
    colorAttach.samples = VK_SAMPLE_COUNT_1_BIT
    colorAttach.loadOp = VK_ATTACHMENT_LOAD_OP_CLEAR
    colorAttach.storeOp = VK_ATTACHMENT_STORE_OP_STORE
    colorAttach.stencilLoadOp = 0
    colorAttach.stencilStoreOp = 0
    colorAttach.initialLayout = VK_IMAGE_LAYOUT_UNDEFINED
    colorAttach.finalLayout = VK_IMAGE_LAYOUT_PRESENT_SRC_KHR

    Dim colorRef As VkAttachmentReference
    colorRef.attachment = 0
    colorRef.layout = VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL

    Dim subpass As VkSubpassDescription
    subpass.pipelineBindPoint = VK_PIPELINE_BIND_POINT_GRAPHICS
    subpass.colorAttachmentCount = 1
    subpass.pColorAttachments = VarPtr(colorRef)

    Dim dep As VkSubpassDependency
    dep.srcSubpass = VK_SUBPASS_EXTERNAL
    dep.dstSubpass = 0
    dep.srcStageMask = VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT
    dep.dstStageMask = VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT
    dep.srcAccessMask = 0
    dep.dstAccessMask = VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT

    Dim rpci As VkRenderPassCreateInfo
    rpci.sType = VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO
    rpci.attachmentCount = 1
    rpci.pAttachments = VarPtr(colorAttach)
    rpci.subpassCount = 1
    rpci.pSubpasses = VarPtr(subpass)
    rpci.dependencyCount = 1
    rpci.pDependencies = VarPtr(dep)

    Dim argv(0 To 3) As LongLong
    argv(0) = CLngLng(vkDevice)
    argv(1) = CLngLng(VarPtr(rpci))
    argv(2) = 0
    argv(3) = CLngLng(VarPtr(vkRenderPass))

    LogLine "call vkCreateRenderPass"
    Dim res As Long: res = InvokeI32(p_vkCreateRenderPass, 4, argv)
    VkCheck res, "vkCreateRenderPass"
End Sub

Private Sub VkCreateFramebuffers_()
    Dim i As Long
    ReDim swapFramebuffers(0 To swapImageCount - 1) As LongLong

    For i = 0 To swapImageCount - 1
        Dim fbci As VkFramebufferCreateInfo
        fbci.sType = VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO
        fbci.renderPass = vkRenderPass
        fbci.attachmentCount = 1
        fbci.pAttachments = VarPtr(swapImageViews(i))
        fbci.width = swapExtent.width
        fbci.height = swapExtent.height
        fbci.layers = 1

        Dim argv(0 To 3) As LongLong
        argv(0) = CLngLng(vkDevice)
        argv(1) = CLngLng(VarPtr(fbci))
        argv(2) = 0
        argv(3) = CLngLng(VarPtr(swapFramebuffers(i)))

        LogLine "call vkCreateFramebuffer i=" & CStr(i)
        Dim res As Long: res = InvokeI32(p_vkCreateFramebuffer, 4, argv)
        VkCheck res, "vkCreateFramebuffer"
    Next
End Sub

Private Sub VkCreateShadersAndPipeline_()
    ' GLSL inlined
    Dim glslVert As String
    glslVert = _
        "#version 450" & vbLf & _
        "#extension GL_ARB_separate_shader_objects : enable" & vbLf & _
        "layout(location = 0) out vec3 fragColor;" & vbLf & _
        "vec2 positions[3] = vec2[](" & vbLf & _
        "    vec2(0.0, -0.5)," & vbLf & _
        "    vec2(0.5, 0.5)," & vbLf & _
        "    vec2(-0.5, 0.5)" & vbLf & _
        ");" & vbLf & _
        "vec3 colors[3] = vec3[](" & vbLf & _
        "    vec3(1.0, 0.0, 0.0)," & vbLf & _
        "    vec3(0.0, 1.0, 0.0)," & vbLf & _
        "    vec3(0.0, 0.0, 1.0)" & vbLf & _
        ");" & vbLf & _
        "void main() {" & vbLf & _
        "    gl_Position = vec4(positions[gl_VertexIndex], 0.0, 1.0);" & vbLf & _
        "    fragColor = colors[gl_VertexIndex];" & vbLf & _
        "}"

    Dim glslFrag As String
    glslFrag = _
        "#version 450" & vbLf & _
        "#extension GL_ARB_separate_shader_objects : enable" & vbLf & _
        "layout(location = 0) in vec3 fragColor;" & vbLf & _
        "layout(location = 0) out vec4 outColor;" & vbLf & _
        "void main() {" & vbLf & _
        "    outColor = vec4(fragColor, 1.0);" & vbLf & _
        "}"

    Dim spvVert() As Byte
    Dim spvFrag() As Byte
    spvVert = ShadercCompileSpv(glslVert, SHADERC_SHADER_KIND_VERTEX, "hello.vert")
    spvFrag = ShadercCompileSpv(glslFrag, SHADERC_SHADER_KIND_FRAGMENT, "hello.frag")

    Dim smci As VkShaderModuleCreateInfo
    smci.sType = VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO

    Dim argv(0 To 3) As LongLong

    smci.codeSize = UBound(spvVert) + 1
    smci.pCode = VarPtr(spvVert(0))
    argv(0) = CLngLng(vkDevice)
    argv(1) = CLngLng(VarPtr(smci))
    argv(2) = 0
    argv(3) = CLngLng(VarPtr(shaderVertModule))
    LogLine "call vkCreateShaderModule(vert)"
    Dim res As Long: res = InvokeI32(p_vkCreateShaderModule, 4, argv)
    VkCheck res, "vkCreateShaderModule(vert)"

    smci.codeSize = UBound(spvFrag) + 1
    smci.pCode = VarPtr(spvFrag(0))
    argv(3) = CLngLng(VarPtr(shaderFragModule))
    LogLine "call vkCreateShaderModule(frag)"
    res = InvokeI32(p_vkCreateShaderModule, 4, argv)
    VkCheck res, "vkCreateShaderModule(frag)"

    Dim pMain As LongPtr: pMain = AllocAnsiZ("main")

    Dim stages(0 To 1) As VkPipelineShaderStageCreateInfo
    stages(0).sType = VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO
    stages(0).stage = &H1 ' VK_SHADER_STAGE_VERTEX_BIT
    stages(0).module = shaderVertModule
    stages(0).pName = pMain

    stages(1).sType = VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO
    stages(1).stage = &H10 ' VK_SHADER_STAGE_FRAGMENT_BIT
    stages(1).module = shaderFragModule
    stages(1).pName = pMain

    Dim vi As VkPipelineVertexInputStateCreateInfo
    vi.sType = VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO

    Dim ia As VkPipelineInputAssemblyStateCreateInfo
    ia.sType = VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO
    ia.topology = VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST
    ia.primitiveRestartEnable = VK_FALSE

    Dim viewport As VkViewport
    viewport.x = 0!: viewport.y = 0!
    viewport.width = CSng(swapExtent.width)
    viewport.height = CSng(swapExtent.height)
    viewport.minDepth = 0!: viewport.maxDepth = 1!

    Dim scissor As VkRect2D
    scissor.offset.x = 0: scissor.offset.y = 0
    scissor.extent = swapExtent

    Dim vp As VkPipelineViewportStateCreateInfo
    vp.sType = VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO
    vp.viewportCount = 1
    vp.pViewports = VarPtr(viewport)
    vp.scissorCount = 1
    vp.pScissors = VarPtr(scissor)

    Dim rs As VkPipelineRasterizationStateCreateInfo
    rs.sType = VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO
    rs.depthClampEnable = VK_FALSE
    rs.rasterizerDiscardEnable = VK_FALSE
    rs.polygonMode = VK_POLYGON_MODE_FILL
    rs.cullMode = VK_CULL_MODE_NONE
    rs.frontFace = VK_FRONT_FACE_COUNTER_CLOCKWISE
    rs.depthBiasEnable = VK_FALSE
    rs.lineWidth = 1!

    Dim ms As VkPipelineMultisampleStateCreateInfo
    ms.sType = VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO
    ms.rasterizationSamples = VK_SAMPLE_COUNT_1_BIT
    ms.sampleShadingEnable = VK_FALSE

    Dim cba As VkPipelineColorBlendAttachmentState
    cba.blendEnable = VK_FALSE
    cba.colorWriteMask = &HF ' RGBA

    Dim cb As VkPipelineColorBlendStateCreateInfo
    cb.sType = VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO
    cb.logicOpEnable = VK_FALSE
    cb.attachmentCount = 1
    cb.pAttachments = VarPtr(cba)

    Dim plci As VkPipelineLayoutCreateInfo
    plci.sType = VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO

    argv(0) = CLngLng(vkDevice)
    argv(1) = CLngLng(VarPtr(plci))
    argv(2) = 0
    argv(3) = CLngLng(VarPtr(vkPipelineLayout))
    LogLine "call vkCreatePipelineLayout"
    res = InvokeI32(p_vkCreatePipelineLayout, 4, argv)
    VkCheck res, "vkCreatePipelineLayout"

    Dim gpci As VkGraphicsPipelineCreateInfo
    gpci.sType = VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO
    gpci.stageCount = 2
    gpci.pStages = VarPtr(stages(0))
    gpci.pVertexInputState = VarPtr(vi)
    gpci.pInputAssemblyState = VarPtr(ia)
    gpci.pViewportState = VarPtr(vp)
    gpci.pRasterizationState = VarPtr(rs)
    gpci.pMultisampleState = VarPtr(ms)
    gpci.pDepthStencilState = VarPtr(ms)
    gpci.pColorBlendState = VarPtr(cb)
    gpci.layout = vkPipelineLayout
    gpci.renderPass = vkRenderPass
    gpci.subpass = 0

    Dim argvP(0 To 5) As LongLong
    argvP(0) = CLngLng(vkDevice)
    argvP(1) = 0 ' pipelineCache
    argvP(2) = 1
    argvP(3) = CLngLng(VarPtr(gpci))
    argvP(4) = 0
    argvP(5) = CLngLng(VarPtr(vkPipeline))

    LogLine "call vkCreateGraphicsPipelines"
    res = InvokeI32(p_vkCreateGraphicsPipelines, 6, argvP)
    VkCheck res, "vkCreateGraphicsPipelines"
End Sub

Private Sub VkCreateCommandPoolAndBuffers_()
    Dim cpci As VkCommandPoolCreateInfo
    cpci.sType = VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO
    cpci.flags = VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT
    cpci.queueFamilyIndex = qFamilyGraphics

    Dim argv(0 To 3) As LongLong
    argv(0) = CLngLng(vkDevice)
    argv(1) = CLngLng(VarPtr(cpci))
    argv(2) = 0
    argv(3) = CLngLng(VarPtr(vkCommandPool))

    LogLine "call vkCreateCommandPool"
    Dim res As Long: res = InvokeI32(p_vkCreateCommandPool, 4, argv)
    VkCheck res, "vkCreateCommandPool"

    ReDim vkCmdBuffers(0 To swapImageCount - 1) As LongLong

    Dim ai As VkCommandBufferAllocateInfo
    ai.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO
    ai.commandPool = vkCommandPool
    ai.level = 0 ' PRIMARY
    ai.commandBufferCount = 1

    Dim i As Long
    For i = 0 To swapImageCount - 1
        Dim one As LongPtr
        Dim argvA(0 To 2) As LongLong
        argvA(0) = CLngLng(vkDevice)
        argvA(1) = CLngLng(VarPtr(ai))
        argvA(2) = CLngLng(VarPtr(one))
        LogLine "call vkAllocateCommandBuffers i=" & CStr(i)
        res = InvokeI32(p_vkAllocateCommandBuffers, 3, argvA)
        VkCheck res, "vkAllocateCommandBuffers"
        vkCmdBuffers(i) = one
    Next
End Sub

Private Sub VkCreateSyncObjects_()
    Dim sci As VkSemaphoreCreateInfo
    sci.sType = VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO

    Dim argv(0 To 3) As LongLong
    argv(0) = CLngLng(vkDevice)
    argv(1) = CLngLng(VarPtr(sci))
    argv(2) = 0

    LogLine "call vkCreateSemaphore(imageAvailable)"
    argv(3) = CLngLng(VarPtr(semImageAvailable))
    Dim res As Long: res = InvokeI32(p_vkCreateSemaphore, 4, argv)
    VkCheck res, "vkCreateSemaphore(imageAvailable)"

    LogLine "call vkCreateSemaphore(renderFinished)"
    argv(3) = CLngLng(VarPtr(semRenderFinished))
    res = InvokeI32(p_vkCreateSemaphore, 4, argv)
    VkCheck res, "vkCreateSemaphore(renderFinished)"

    Dim fci As VkFenceCreateInfo
    fci.sType = VK_STRUCTURE_TYPE_FENCE_CREATE_INFO
    fci.flags = VK_FENCE_CREATE_SIGNALED_BIT

    LogLine "call vkCreateFence"
    argv(1) = CLngLng(VarPtr(fci))
    argv(3) = CLngLng(VarPtr(fenceInFlight))
    res = InvokeI32(p_vkCreateFence, 4, argv)
    VkCheck res, "vkCreateFence"
End Sub

Private Sub RecordCommandBuffer(ByVal imageIndex As Long)
    Dim cmd As LongPtr
    cmd = vkCmdBuffers(imageIndex)

    Dim argv2(0 To 1) As LongLong
    argv2(0) = CLngLng(cmd)
    argv2(1) = 0

    LogLine "call vkResetCommandBuffer"
    Dim res As Long: res = InvokeI32(p_vkResetCommandBuffer, 2, argv2)
    VkCheck res, "vkResetCommandBuffer"

    Dim bi As VkCommandBufferBeginInfo
    bi.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO

    Dim argvB(0 To 1) As LongLong
    argvB(0) = CLngLng(cmd)
    argvB(1) = CLngLng(VarPtr(bi))
    LogLine "call vkBeginCommandBuffer"
    res = InvokeI32(p_vkBeginCommandBuffer, 2, argvB)
    VkCheck res, "vkBeginCommandBuffer"

    Dim clear As VkClearValue
    clear.color.float32_0 = 0!
    clear.color.float32_1 = 0!
    clear.color.float32_2 = 0!
    clear.color.float32_3 = 1!

    Dim rpbi As VkRenderPassBeginInfo
    rpbi.sType = VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO
    rpbi.renderPass = vkRenderPass
    rpbi.framebuffer = swapFramebuffers(imageIndex)
    rpbi.renderArea.offset.x = 0
    rpbi.renderArea.offset.y = 0
    rpbi.renderArea.extent = swapExtent
    rpbi.clearValueCount = 1
    rpbi.pClearValues = VarPtr(clear)

    Dim argvR(0 To 2) As LongLong
    argvR(0) = CLngLng(cmd)
    argvR(1) = CLngLng(VarPtr(rpbi))
    argvR(2) = CLngLng(VK_SUBPASS_CONTENTS_INLINE)

    LogLine "call vkCmdBeginRenderPass"
    Call InvokeRaw(p_vkCmdBeginRenderPass, 3, argvR)

    Dim argvBP(0 To 2) As LongLong
    argvBP(0) = CLngLng(cmd)
    argvBP(1) = CLngLng(VK_PIPELINE_BIND_POINT_GRAPHICS)
    argvBP(2) = CLngLng(vkPipeline)

    LogLine "call vkCmdBindPipeline"
    Call InvokeRaw(p_vkCmdBindPipeline, 3, argvBP)

    Dim argvD(0 To 4) As LongLong
    argvD(0) = CLngLng(cmd)
    argvD(1) = 3
    argvD(2) = 1
    argvD(3) = 0
    argvD(4) = 0
    LogLine "call vkCmdDraw"
    Call InvokeRaw(p_vkCmdDraw, 5, argvD)

    Dim argvE(0 To 0) As LongLong
    argvE(0) = CLngLng(cmd)
    LogLine "call vkCmdEndRenderPass"
    Call InvokeRaw(p_vkCmdEndRenderPass, 1, argvE)

    LogLine "call vkEndCommandBuffer"
    res = InvokeI32(p_vkEndCommandBuffer, 1, argvE)
    VkCheck res, "vkEndCommandBuffer"
End Sub

Private Sub DrawFrame()
    LogLine "DrawFrame begin"

    ' vkWaitForFences(device, 1, &fence, VK_TRUE, UINT64_MAX)
    Dim argvW(0 To 4) As LongLong
    argvW(0) = CLngLng(vkDevice)
    argvW(1) = 1
    argvW(2) = CLngLng(VarPtr(fenceInFlight))
    argvW(3) = CLngLng(VK_TRUE)
    argvW(4) = CLngLng("9223372036854775807") ' large timeout &H7FFFFFFFFFFFFFFF#
    LogLine "call vkWaitForFences"
    Dim res As Long: res = InvokeI32(p_vkWaitForFences, 5, argvW)
    VkCheck res, "vkWaitForFences"

    Dim argvRF(0 To 2) As LongLong
    argvRF(0) = CLngLng(vkDevice)
    argvRF(1) = 1
    argvRF(2) = CLngLng(VarPtr(fenceInFlight))
    LogLine "call vkResetFences"
    res = InvokeI32(p_vkResetFences, 3, argvRF)
    VkCheck res, "vkResetFences"

    Dim imageIndex As Long
    Dim argvA(0 To 5) As LongLong
    argvA(0) = CLngLng(vkDevice)
    argvA(1) = CLngLng(vkSwapchain)
    argvA(2) = CLngLng("9223372036854775807") ' &H7FFFFFFFFFFFFFFF#
    argvA(3) = CLngLng(semImageAvailable)
    argvA(4) = 0
    argvA(5) = CLngLng(VarPtr(imageIndex))

    LogLine "call vkAcquireNextImageKHR"
    res = InvokeI32(p_vkAcquireNextImageKHR, 6, argvA)
    VkCheck res, "vkAcquireNextImageKHR"
    LogKV "imageIndex", CStr(imageIndex)

    RecordCommandBuffer imageIndex

    Dim waitStage As Long: waitStage = VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT

    Dim submit As VkSubmitInfo
    submit.sType = VK_STRUCTURE_TYPE_SUBMIT_INFO
    submit.waitSemaphoreCount = 1
    submit.pWaitSemaphores = VarPtr(semImageAvailable)
    submit.pWaitDstStageMask = VarPtr(waitStage)
    submit.commandBufferCount = 1
    submit.pCommandBuffers = VarPtr(vkCmdBuffers(imageIndex))
    submit.signalSemaphoreCount = 1
    submit.pSignalSemaphores = VarPtr(semRenderFinished)

    Dim argvS(0 To 3) As LongLong
    argvS(0) = CLngLng(vkQueueGraphics)
    argvS(1) = 1
    argvS(2) = CLngLng(VarPtr(submit))
    argvS(3) = CLngLng(fenceInFlight)

    LogLine "call vkQueueSubmit"
    res = InvokeI32(p_vkQueueSubmit, 4, argvS)
    VkCheck res, "vkQueueSubmit"

    Dim present As VkPresentInfoKHR
    present.sType = VK_STRUCTURE_TYPE_PRESENT_INFO_KHR
    present.waitSemaphoreCount = 1
    present.pWaitSemaphores = VarPtr(semRenderFinished)
    present.swapchainCount = 1
    present.pSwapchains = VarPtr(vkSwapchain)
    present.pImageIndices = VarPtr(imageIndex)

    Dim argvP(0 To 1) As LongLong
    argvP(0) = CLngLng(vkQueuePresent)
    argvP(1) = CLngLng(VarPtr(present))

    LogLine "call vkQueuePresentKHR"
    res = InvokeI32(p_vkQueuePresentKHR, 2, argvP)
    VkCheck res, "vkQueuePresentKHR"

    LogLine "DrawFrame end"
End Sub

Private Sub VulkanInitAll()
    LogLine "LoadVulkanLoader"
    LoadVulkanLoader
    LogKV "p_vkGetInstanceProcAddr", HexPtr(p_vkGetInstanceProcAddr)
    LogKV "p_vkCreateInstance", HexPtr(p_vkCreateInstance)

    LogLine "LoadShaderc"
    LoadShaderc

    LogLine "VkCreateInstance"
    VkCreateInstance_
    LogKV "vkInstance", HexPtr(vkInstance)

    LogLine "VkCreateSurface"
    VkCreateSurface_
    LogKV "vkSurface", HexPtr(vkSurface)

    LogLine "PickPhysicalDeviceAndQueues"
    PickPhysicalDeviceAndQueues_
    LogKV "vkPhysicalDevice", HexPtr(vkPhysicalDevice)
    LogKV "qFamilyGraphics", CStr(qFamilyGraphics)
    LogKV "qFamilyPresent", CStr(qFamilyPresent)

    LogLine "VkCreateDevice"
    VkCreateDevice_
    LogKV "vkDevice", HexPtr(vkDevice)
    LogKV "vkQueueGraphics", HexPtr(vkQueueGraphics)
    LogKV "vkQueuePresent", HexPtr(vkQueuePresent)

    LogLine "VkCreateSwapchainAndViews"
    VkCreateSwapchainAndViews_
    LogKV "vkSwapchain", HexPtr(vkSwapchain)
    LogKV "swapImageCount", CStr(swapImageCount)
    LogKV "swapImageFormat", CStr(swapImageFormat)
    LogKV "swapExtent", CStr(swapExtent.width) & "x" & CStr(swapExtent.height)

    LogLine "VkCreateRenderPass"
    VkCreateRenderPass_
    LogKV "vkRenderPass", HexPtr(vkRenderPass)

    LogLine "VkCreateFramebuffers"
    VkCreateFramebuffers_

    LogLine "VkCreateShadersAndPipeline"
    VkCreateShadersAndPipeline_
    LogKV "shaderVertModule", HexPtr(shaderVertModule)
    LogKV "shaderFragModule", HexPtr(shaderFragModule)
    LogKV "vkPipelineLayout", HexPtr(vkPipelineLayout)
    LogKV "vkPipeline", HexPtr(vkPipeline)

    LogLine "VkCreateCommandPoolAndBuffers"
    VkCreateCommandPoolAndBuffers_
    LogKV "vkCommandPool", HexPtr(vkCommandPool)

    LogLine "VkCreateSyncObjects"
    VkCreateSyncObjects_
    LogKV "semImageAvailable", HexPtr(semImageAvailable)
    LogKV "semRenderFinished", HexPtr(semRenderFinished)
    LogKV "fenceInFlight", HexPtr(fenceInFlight)

    LogLine "VulkanInitAll DONE"
End Sub

Private Sub VulkanCleanupAll()
    On Error Resume Next
    LogLine "Cleanup begin"

    If vkDevice <> 0 Then
        If p_vkDeviceWaitIdle <> 0 Then
            LogLine "call vkDeviceWaitIdle"
            Dim argv1(0 To 0) As LongLong
            argv1(0) = CLngLng(vkDevice)
            Call InvokeRaw(p_vkDeviceWaitIdle, 1, argv1)
        End If

        Dim i As Long

        If fenceInFlight <> 0 Then
            LogLine "destroy fence"
            Dim argvD(0 To 2) As LongLong
            argvD(0) = CLngLng(vkDevice)
            argvD(1) = CLngLng(fenceInFlight)
            argvD(2) = 0
            Call InvokeRaw(p_vkDestroyFence, 3, argvD)
        End If
        If semRenderFinished <> 0 Then
            LogLine "destroy semaphore renderFinished"
            Dim argvD2(0 To 2) As LongLong
            argvD2(0) = CLngLng(vkDevice)
            argvD2(1) = CLngLng(semRenderFinished)
            argvD2(2) = 0
            Call InvokeRaw(p_vkDestroySemaphore, 3, argvD2)
        End If
        If semImageAvailable <> 0 Then
            LogLine "destroy semaphore imageAvailable"
            Dim argvD3(0 To 2) As LongLong
            argvD3(0) = CLngLng(vkDevice)
            argvD3(1) = CLngLng(semImageAvailable)
            argvD3(2) = 0
            Call InvokeRaw(p_vkDestroySemaphore, 3, argvD3)
        End If

        If vkCommandPool <> 0 Then
            LogLine "destroy command pool"
            Dim argvCP(0 To 2) As LongLong
            argvCP(0) = CLngLng(vkDevice)
            argvCP(1) = CLngLng(vkCommandPool)
            argvCP(2) = 0
            Call InvokeRaw(p_vkDestroyCommandPool, 3, argvCP)
        End If

        If (Not Not swapFramebuffers) <> 0 Then
            For i = 0 To swapImageCount - 1
                If swapFramebuffers(i) <> 0 Then
                    LogLine "destroy framebuffer i=" & CStr(i)
                    Dim argvFB(0 To 2) As LongLong
                    argvFB(0) = CLngLng(vkDevice)
                    argvFB(1) = CLngLng(swapFramebuffers(i))
                    argvFB(2) = 0
                    Call InvokeRaw(p_vkDestroyFramebuffer, 3, argvFB)
                End If
            Next
        End If

        If vkPipeline <> 0 Then
            LogLine "destroy pipeline"
            Dim argvPL(0 To 2) As LongLong
            argvPL(0) = CLngLng(vkDevice)
            argvPL(1) = CLngLng(vkPipeline)
            argvPL(2) = 0
            Call InvokeRaw(p_vkDestroyPipeline, 3, argvPL)
        End If
        If vkPipelineLayout <> 0 Then
            LogLine "destroy pipeline layout"
            Dim argvPLL(0 To 2) As LongLong
            argvPLL(0) = CLngLng(vkDevice)
            argvPLL(1) = CLngLng(vkPipelineLayout)
            argvPLL(2) = 0
            Call InvokeRaw(p_vkDestroyPipelineLayout, 3, argvPLL)
        End If

        If shaderVertModule <> 0 Then
            LogLine "destroy shader module vert"
            Dim argvSM(0 To 2) As LongLong
            argvSM(0) = CLngLng(vkDevice)
            argvSM(1) = CLngLng(shaderVertModule)
            argvSM(2) = 0
            Call InvokeRaw(p_vkDestroyShaderModule, 3, argvSM)
        End If
        If shaderFragModule <> 0 Then
            LogLine "destroy shader module frag"
            Dim argvSM2(0 To 2) As LongLong
            argvSM2(0) = CLngLng(vkDevice)
            argvSM2(1) = CLngLng(shaderFragModule)
            argvSM2(2) = 0
            Call InvokeRaw(p_vkDestroyShaderModule, 3, argvSM2)
        End If

        If vkRenderPass <> 0 Then
            LogLine "destroy render pass"
            Dim argvRP(0 To 2) As LongLong
            argvRP(0) = CLngLng(vkDevice)
            argvRP(1) = CLngLng(vkRenderPass)
            argvRP(2) = 0
            Call InvokeRaw(p_vkDestroyRenderPass, 3, argvRP)
        End If

        If (Not Not swapImageViews) <> 0 Then
            For i = 0 To swapImageCount - 1
                If swapImageViews(i) <> 0 Then
                    LogLine "destroy image view i=" & CStr(i)
                    Dim argvIV(0 To 2) As LongLong
                    argvIV(0) = CLngLng(vkDevice)
                    argvIV(1) = CLngLng(swapImageViews(i))
                    argvIV(2) = 0
                    Call InvokeRaw(p_vkDestroyImageView, 3, argvIV)
                End If
            Next
        End If

        If vkSwapchain <> 0 Then
            LogLine "destroy swapchain"
            Dim argvSC(0 To 2) As LongLong
            argvSC(0) = CLngLng(vkDevice)
            argvSC(1) = CLngLng(vkSwapchain)
            argvSC(2) = 0
            Call InvokeRaw(p_vkDestroySwapchainKHR, 3, argvSC)
        End If

        If p_vkDestroyDevice <> 0 Then
            LogLine "destroy device"
            Dim argvDD(0 To 1) As LongLong
            argvDD(0) = CLngLng(vkDevice)
            argvDD(1) = 0
            Call InvokeRaw(p_vkDestroyDevice, 2, argvDD)
        End If
    End If

    If vkSurface <> 0 And p_vkDestroySurfaceKHR <> 0 Then
        LogLine "destroy surface"
        Dim argvS(0 To 2) As LongLong
        argvS(0) = CLngLng(vkInstance)
        argvS(1) = CLngLng(vkSurface)
        argvS(2) = 0
        Call InvokeRaw(p_vkDestroySurfaceKHR, 3, argvS)
    End If

    If vkInstance <> 0 And p_vkDestroyInstance <> 0 Then
        LogLine "destroy instance"
        Dim argvI(0 To 1) As LongLong
        argvI(0) = CLngLng(vkInstance)
        argvI(1) = 0
        Call InvokeRaw(p_vkDestroyInstance, 2, argvI)
    End If

    If g_hShaderc <> 0 Then
        LogLine "FreeLibrary shaderc"
        FreeLibrary g_hShaderc
        g_hShaderc = 0
    End If
    If g_hVulkan <> 0 Then
        LogLine "FreeLibrary vulkan"
        FreeLibrary g_hVulkan
        g_hVulkan = 0
    End If

    FreeAllAnsi
    LogLine "Cleanup end"
End Sub

Public Sub Main()
    On Error GoTo EH

    LogInit

    g_quit = False
    LogLine "CreateAppWindow..."
    CreateAppWindow 800, 600
    LogKV "hwnd", HexPtr(g_hwnd)
    LogKV "hInst", HexPtr(g_hInst)

    LogLine "VulkanInitAll..."
    VulkanInitAll

    LogLine "Enter main loop..."
    Dim m As MSG_T
    Do While Not g_quit
        If PeekMessageW(m, 0, 0, 0, PM_REMOVE) <> 0 Then
            TranslateMessage m
            DispatchMessageW m
        Else
            DrawFrame
            DoEvents
        End If
    Loop

    LogLine "Cleanup..."
    VulkanCleanupAll
    LogLine "END OK"
    Exit Sub

EH:
    LogLine "EXCEPTION: " & Err.Description
    LogLine "Cleanup after exception..."
    On Error Resume Next
    VulkanCleanupAll
    LogLine "END ERROR"
    MsgBox "ERROR: " & Err.Description & vbCrLf & "Log: " & LOG_PATH, vbExclamation
End Sub

