Attribute VB_Name = "hello"
Option Explicit

' ============================================================================
'  Excel VBA (64-bit) + Vulkan 1.4 + shaderc: Harmonograph Compute Demo
'   - Compute Shader for harmonograph calculation
'   - Storage Buffers for positions and colors
'   - Uniform Buffer for parameters
'   - Descriptor Sets for resource binding
'   - Pipeline Barrier for compute-to-graphics sync
'   - Logs to C:\TEMP\vk_harmonograph_log.txt
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
    Private Declare PtrSafe Sub RtlZeroMemory Lib "kernel32" (ByVal dest As LongPtr, ByVal cb As LongPtr)
    Private Declare PtrSafe Function CoTaskMemAlloc Lib "ole32" (ByVal cb As LongPtr) As LongPtr
    Private Declare PtrSafe Sub CoTaskMemFree Lib "ole32" (ByVal pv As LongPtr)
    Private Declare PtrSafe Function CallWindowProcW Lib "user32" (ByVal lpPrevWndFunc As LongPtr, ByVal hwnd As LongPtr, ByVal msg As LongPtr, ByVal wParam As LongPtr, ByVal lParam As LongPtr) As LongPtr
    Private Declare PtrSafe Function QueryPerformanceCounter Lib "kernel32" (ByRef lpPerformanceCount As LongLong) As Long
    Private Declare PtrSafe Function QueryPerformanceFrequency Lib "kernel32" (ByRef lpFrequency As LongLong) As Long
#End If

' Window / Message loop
Private Const WS_OVERLAPPEDWINDOW As Long = &HCF0000
Private Const WS_VISIBLE As Long = &H10000000
Private Const CW_USEDEFAULT As Long = &H80000000
Private Const WM_DESTROY As Long = &H2
Private Const WM_CLOSE As Long = &H10
Private Const WM_KEYDOWN As Long = &H100
Private Const VK_ESCAPE As Long = &H1B
Private Const PM_REMOVE As Long = &H1

Private Type POINTAPI: x As Long: y As Long: End Type
Private Type MSG_T: hwnd As LongPtr: message As Long: wParam As LongPtr: lParam As LongPtr: time As Long: pt As POINTAPI: End Type
Private Type WNDCLASSEXW: cbSize As Long: style As Long: lpfnWndProc As LongPtr: cbClsExtra As Long: cbWndExtra As Long: hInstance As LongPtr: hIcon As LongPtr: hCursor As LongPtr: hbrBackground As LongPtr: lpszMenuName As LongPtr: lpszClassName As LongPtr: hIconSm As LongPtr: End Type
Private Type RECT: Left As Long: Top As Long: Right As Long: Bottom As Long: End Type

Private Declare PtrSafe Function RegisterClassExW Lib "user32" (ByRef wc As WNDCLASSEXW) As Integer
Private Declare PtrSafe Function CreateWindowExW Lib "user32" (ByVal dwExStyle As Long, ByVal lpClassName As LongPtr, ByVal lpWindowName As LongPtr, ByVal dwStyle As Long, ByVal x As Long, ByVal y As Long, ByVal nWidth As Long, ByVal nHeight As Long, ByVal hWndParent As LongPtr, ByVal hMenu As LongPtr, ByVal hInstance As LongPtr, ByVal lpParam As LongPtr) As LongPtr
Private Declare PtrSafe Function DefWindowProcW Lib "user32" (ByVal hwnd As LongPtr, ByVal uMsg As Long, ByVal wParam As LongPtr, ByVal lParam As LongPtr) As LongPtr
Private Declare PtrSafe Function DestroyWindow Lib "user32" (ByVal hwnd As LongPtr) As Long
Private Declare PtrSafe Sub PostQuitMessage Lib "user32" (ByVal nExitCode As Long)
Private Declare PtrSafe Function PeekMessageW Lib "user32" (ByRef lpMsg As MSG_T, ByVal hwnd As LongPtr, ByVal wMsgFilterMin As Long, ByVal wMsgFilterMax As Long, ByVal wRemoveMsg As Long) As Long
Private Declare PtrSafe Function TranslateMessage Lib "user32" (ByRef lpMsg As MSG_T) As Long
Private Declare PtrSafe Function DispatchMessageW Lib "user32" (ByRef lpMsg As MSG_T) As LongPtr
Private Declare PtrSafe Function ShowWindow Lib "user32" (ByVal hwnd As LongPtr, ByVal nCmdShow As Long) As Long
Private Declare PtrSafe Function UpdateWindow Lib "user32" (ByVal hwnd As LongPtr) As Long
Private Declare PtrSafe Function GetClientRect Lib "user32" (ByVal hwnd As LongPtr, ByRef rc As RECT) As Long
Private Declare PtrSafe Function UnregisterClassW Lib "user32" (ByVal lpClassName As LongPtr, ByVal hInstance As LongPtr) As Long

Private Const MEM_COMMIT As Long = &H1000
Private Const MEM_RESERVE As Long = &H2000
Private Const MEM_RELEASE As Long = &H8000
Private Const PAGE_EXECUTE_READWRITE As Long = &H40

Private Const LOG_PATH As String = "C:\TEMP\vk_harmonograph_log.txt"
Private g_logEnabled As Boolean
Private g_allocAnsiPtrs() As LongPtr
Private g_allocAnsiCount As Long

Private Type THUNK_REC: fnPtr As LongPtr: argc As Long: stubPtr As LongPtr: End Type
Private g_thunks() As THUNK_REC
Private g_thunkCount As Long

' Vulkan constants
Private Const VK_SUCCESS As Long = 0
Private Const VK_SUBOPTIMAL_KHR As Long = 1000001003
Private Const VK_ERROR_OUT_OF_DATE_KHR As Long = -1000001004
Private Const VK_TRUE As Long = 1
Private Const VK_FALSE As Long = 0
Private Const VK_API_VERSION_1_4 As Long = &H4010000

' Structure types
Private Const VK_STRUCTURE_TYPE_APPLICATION_INFO As Long = 0
Private Const VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO As Long = 1
Private Const VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO As Long = 2
Private Const VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO As Long = 3
Private Const VK_STRUCTURE_TYPE_SUBMIT_INFO As Long = 4
Private Const VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO As Long = 5
Private Const VK_STRUCTURE_TYPE_FENCE_CREATE_INFO As Long = 8
Private Const VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO As Long = 9
Private Const VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO As Long = 12
Private Const VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO As Long = 15
Private Const VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO As Long = 16
Private Const VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO As Long = 18
Private Const VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO As Long = 19
Private Const VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO As Long = 20
Private Const VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO As Long = 22
Private Const VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO As Long = 23
Private Const VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO As Long = 24
Private Const VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO As Long = 26
Private Const VK_STRUCTURE_TYPE_PIPELINE_DYNAMIC_STATE_CREATE_INFO As Long = 27
Private Const VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO As Long = 28
Private Const VK_STRUCTURE_TYPE_COMPUTE_PIPELINE_CREATE_INFO As Long = 29
Private Const VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO As Long = 30
Private Const VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO As Long = 32
Private Const VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO As Long = 33
Private Const VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO As Long = 34
Private Const VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET As Long = 35
Private Const VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO As Long = 37
Private Const VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO As Long = 38
Private Const VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO As Long = 39
Private Const VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO As Long = 40
Private Const VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO As Long = 42
Private Const VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO As Long = 43
Private Const VK_STRUCTURE_TYPE_BUFFER_MEMORY_BARRIER As Long = 44
Private Const VK_STRUCTURE_TYPE_WIN32_SURFACE_CREATE_INFO_KHR As Long = 1000009000
Private Const VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR As Long = 1000001000
Private Const VK_STRUCTURE_TYPE_PRESENT_INFO_KHR As Long = 1000001001

' Other constants
Private Const VK_QUEUE_GRAPHICS_BIT As Long = &H1
Private Const VK_QUEUE_COMPUTE_BIT As Long = &H2
Private Const VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT As Long = &H10
Private Const VK_SHARING_MODE_EXCLUSIVE As Long = 0
Private Const VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR As Long = &H1
Private Const VK_PRESENT_MODE_FIFO_KHR As Long = 2
Private Const VK_FORMAT_B8G8R8A8_UNORM As Long = 44
Private Const VK_COLOR_SPACE_SRGB_NONLINEAR_KHR As Long = 0
Private Const VK_IMAGE_ASPECT_COLOR_BIT As Long = &H1
Private Const VK_IMAGE_VIEW_TYPE_2D As Long = 1
Private Const VK_PIPELINE_BIND_POINT_GRAPHICS As Long = 0
Private Const VK_PIPELINE_BIND_POINT_COMPUTE As Long = 1
Private Const VK_PRIMITIVE_TOPOLOGY_LINE_STRIP As Long = 2
Private Const VK_POLYGON_MODE_FILL As Long = 0
Private Const VK_CULL_MODE_NONE As Long = 0
Private Const VK_FRONT_FACE_COUNTER_CLOCKWISE As Long = 1
Private Const VK_SAMPLE_COUNT_1_BIT As Long = 1
Private Const VK_ATTACHMENT_LOAD_OP_CLEAR As Long = 1
Private Const VK_ATTACHMENT_STORE_OP_STORE As Long = 0
Private Const VK_ATTACHMENT_LOAD_OP_DONT_CARE As Long = 2
Private Const VK_ATTACHMENT_STORE_OP_DONT_CARE As Long = 1
Private Const VK_IMAGE_LAYOUT_UNDEFINED As Long = 0
Private Const VK_IMAGE_LAYOUT_PRESENT_SRC_KHR As Long = 1000001002
Private Const VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL As Long = 2
Private Const VK_SUBPASS_CONTENTS_INLINE As Long = 0
Private Const VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT As Long = &H2
Private Const VK_FENCE_CREATE_SIGNALED_BIT As Long = &H1
Private Const VK_PIPELINE_STAGE_VERTEX_SHADER_BIT As Long = &H8
Private Const VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT As Long = &H400
Private Const VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT As Long = &H800
Private Const VK_ACCESS_SHADER_READ_BIT As Long = &H20
Private Const VK_ACCESS_SHADER_WRITE_BIT As Long = &H40
Private Const VK_SHADER_STAGE_VERTEX_BIT As Long = &H1
Private Const VK_SHADER_STAGE_FRAGMENT_BIT As Long = &H10
Private Const VK_SHADER_STAGE_COMPUTE_BIT As Long = &H20
Private Const VK_DYNAMIC_STATE_VIEWPORT As Long = 0
Private Const VK_DYNAMIC_STATE_SCISSOR As Long = 1
Private Const VK_BUFFER_USAGE_STORAGE_BUFFER_BIT As Long = &H20
Private Const VK_BUFFER_USAGE_UNIFORM_BUFFER_BIT As Long = &H10
Private Const VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT As Long = &H1
Private Const VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT As Long = &H2
Private Const VK_MEMORY_PROPERTY_HOST_COHERENT_BIT As Long = &H4
Private Const VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER As Long = 6
Private Const VK_DESCRIPTOR_TYPE_STORAGE_BUFFER As Long = 7
Private Const VK_QUEUE_FAMILY_IGNORED As Long = &HFFFFFFFF
Private Const SHADERC_SHADER_KIND_VERTEX As Long = 0
Private Const SHADERC_SHADER_KIND_FRAGMENT As Long = 1
Private Const SHADERC_SHADER_KIND_COMPUTE As Long = 2
Private Const SHADERC_COMPILATION_STATUS_SUCCESS As Long = 0
Private Const VERTEX_COUNT As Long = 500000

' Vulkan structs
Private Type VkExtent2D: width As Long: height As Long: End Type
Private Type VkOffset2D: x As Long: y As Long: End Type
Private Type VkRect2D: offset As VkOffset2D: extent As VkExtent2D: End Type

Private Type VkApplicationInfo
    sType As Long: pad0 As Long: pNext As LongPtr: pApplicationName As LongPtr
    applicationVersion As Long: pad1 As Long: pEngineName As LongPtr: engineVersion As Long: apiVersion As Long
End Type

Private Type VkInstanceCreateInfo
    sType As Long: pad0 As Long: pNext As LongPtr: flags As Long: pad1 As Long: pApplicationInfo As LongPtr
    enabledLayerCount As Long: pad2 As Long: ppEnabledLayerNames As LongPtr
    enabledExtensionCount As Long: pad3 As Long: ppEnabledExtensionNames As LongPtr
End Type

Private Type VkWin32SurfaceCreateInfoKHR
    sType As Long: pad0 As Long: pNext As LongPtr: flags As Long: pad1 As Long: hInstance As LongPtr: hwnd As LongPtr
End Type

Private Type VkDeviceQueueCreateInfo
    sType As Long: pad0 As Long: pNext As LongPtr: flags As Long: queueFamilyIndex As Long
    queueCount As Long: pad1 As Long: pQueuePriorities As LongPtr
End Type

Private Type VkDeviceCreateInfo
    sType As Long: pad0 As Long: pNext As LongPtr: flags As Long: queueCreateInfoCount As Long
    pQueueCreateInfos As LongPtr: enabledLayerCount As Long: pad1 As Long
    ppEnabledLayerNames As LongPtr: enabledExtensionCount As Long: pad2 As Long
    ppEnabledExtensionNames As LongPtr: pEnabledFeatures As LongPtr
End Type

Private Type VkSurfaceFormatKHR: format As Long: colorSpace As Long: End Type

Private Type VkSurfaceCapabilitiesKHR
    minImageCount As Long: maxImageCount As Long: currentExtent As VkExtent2D
    minImageExtent As VkExtent2D: maxImageExtent As VkExtent2D
    maxImageArrayLayers As Long: supportedTransforms As Long: currentTransform As Long
    supportedCompositeAlpha As Long: supportedUsageFlags As Long
End Type

Private Type VkSwapchainCreateInfoKHR
    sType As Long: pad0 As Long: pNext As LongPtr: flags As Long: surface As LongPtr
    minImageCount As Long: imageFormat As Long: imageColorSpace As Long
    imageExtent As VkExtent2D: imageArrayLayers As Long: imageUsage As Long
    imageSharingMode As Long: queueFamilyIndexCount As Long: pQueueFamilyIndices As LongPtr
    preTransform As Long: compositeAlpha As Long: presentMode As Long: clipped As Long: oldSwapchain As LongPtr
End Type

Private Type VkImageViewCreateInfo
    sType As Long: pad0 As Long: pNext As LongPtr: flags As Long: image As LongPtr
    viewType As Long: format As Long: r As Long: g As Long: b As Long: a As Long
    aspectMask As Long: baseMipLevel As Long: levelCount As Long: baseArrayLayer As Long: layerCount As Long
End Type

Private Type VkAttachmentDescription
    flags As Long: format As Long: samples As Long: loadOp As Long: storeOp As Long
    stencilLoadOp As Long: stencilStoreOp As Long: initialLayout As Long: finalLayout As Long
End Type

Private Type VkAttachmentReference: attachment As Long: layout As Long: End Type

Private Type VkSubpassDescription
    flags As Long: pipelineBindPoint As Long: inputAttachmentCount As Long: pInputAttachments As LongPtr
    colorAttachmentCount As Long: pad0 As Long: pColorAttachments As LongPtr: pResolveAttachments As LongPtr
    pDepthStencilAttachment As LongPtr: preserveAttachmentCount As Long: pad1 As Long: pPreserveAttachments As LongPtr
End Type

Private Type VkRenderPassCreateInfo
    sType As Long: pad0 As Long: pNext As LongPtr: flags As Long: attachmentCount As Long
    pAttachments As LongPtr: subpassCount As Long: pad1 As Long: pSubpasses As LongPtr
    dependencyCount As Long: pad2 As Long: pDependencies As LongPtr
End Type

Private Type VkFramebufferCreateInfo
    sType As Long: pad0 As Long: pNext As LongPtr: flags As Long: renderPass As LongPtr
    attachmentCount As Long: pad1 As Long: pAttachments As LongPtr: width As Long: height As Long: layers As Long
End Type

Private Type VkCommandPoolCreateInfo
    sType As Long: pad0 As Long: pNext As LongPtr: flags As Long: queueFamilyIndex As Long
End Type

Private Type VkCommandBufferAllocateInfo
    sType As Long: pad0 As Long: pNext As LongPtr: commandPool As LongPtr: level As Long: commandBufferCount As Long
End Type

Private Type VkCommandBufferBeginInfo
    sType As Long: pad0 As Long: pNext As LongPtr: flags As Long: pad1 As Long: pInheritanceInfo As LongPtr
End Type

Private Type VkClearColorValue: float32_0 As Single: float32_1 As Single: float32_2 As Single: float32_3 As Single: End Type
Private Type VkClearValue: color As VkClearColorValue: End Type

Private Type VkRenderPassBeginInfo
    sType As Long: pad0 As Long: pNext As LongPtr: renderPass As LongPtr: framebuffer As LongPtr
    renderArea As VkRect2D: clearValueCount As Long: pad1 As Long: pClearValues As LongPtr
End Type

Private Type VkSemaphoreCreateInfo: sType As Long: pad0 As Long: pNext As LongPtr: flags As Long: End Type
Private Type VkFenceCreateInfo: sType As Long: pad0 As Long: pNext As LongPtr: flags As Long: End Type

Private Type VkShaderModuleCreateInfo
    sType As Long: pad0 As Long: pNext As LongPtr: flags As Long: pad1 As Long: codeSize As LongPtr: pCode As LongPtr
End Type

Private Type VkPipelineShaderStageCreateInfo
    sType As Long: pad0 As Long: pNext As LongPtr: flags As Long: stage As Long
    module As LongPtr: pName As LongPtr: pSpecializationInfo As LongPtr
End Type

Private Type VkPipelineVertexInputStateCreateInfo
    sType As Long: pad0 As Long: pNext As LongPtr: flags As Long: vertexBindingDescriptionCount As Long
    pVertexBindingDescriptions As LongPtr: vertexAttributeDescriptionCount As Long: pad1 As Long: pVertexAttributeDescriptions As LongPtr
End Type

Private Type VkPipelineInputAssemblyStateCreateInfo
    sType As Long: pad0 As Long: pNext As LongPtr: flags As Long: topology As Long: primitiveRestartEnable As Long
End Type

Private Type VkViewport: x As Single: y As Single: width As Single: height As Single: minDepth As Single: maxDepth As Single: End Type

Private Type VkPipelineViewportStateCreateInfo
    sType As Long: pad0 As Long: pNext As LongPtr: flags As Long: viewportCount As Long
    pViewports As LongPtr: scissorCount As Long: pad2 As Long: pScissors As LongPtr
End Type

Private Type VkPipelineRasterizationStateCreateInfo
    sType As Long: pad0 As Long: pNext As LongPtr: flags As Long: depthClampEnable As Long
    rasterizerDiscardEnable As Long: polygonMode As Long: cullMode As Long: frontFace As Long
    depthBiasEnable As Long: depthBiasConstantFactor As Single: depthBiasClamp As Single
    depthBiasSlopeFactor As Single: lineWidth As Single
End Type

Private Type VkPipelineMultisampleStateCreateInfo
    sType As Long: pad0 As Long: pNext As LongPtr: flags As Long: rasterizationSamples As Long
    sampleShadingEnable As Long: minSampleShading As Single: pSampleMask As LongPtr
    alphaToCoverageEnable As Long: alphaToOneEnable As Long
End Type

Private Type VkPipelineColorBlendAttachmentState
    blendEnable As Long: srcColorBlendFactor As Long: dstColorBlendFactor As Long: colorBlendOp As Long
    srcAlphaBlendFactor As Long: dstAlphaBlendFactor As Long: alphaBlendOp As Long: colorWriteMask As Long
End Type

Private Type VkPipelineColorBlendStateCreateInfo
    sType As Long: pad0 As Long: pNext As LongPtr: flags As Long: logicOpEnable As Long: logicOp As Long
    attachmentCount As Long: pAttachments As LongPtr
    blendConstants0 As Single: blendConstants1 As Single: blendConstants2 As Single: blendConstants3 As Single
End Type

Private Type VkPipelineDynamicStateCreateInfo
    sType As Long: pad0 As Long: pNext As LongPtr: flags As Long: dynamicStateCount As Long: pDynamicStates As LongPtr
End Type

Private Type VkPipelineLayoutCreateInfo
    sType As Long: pad0 As Long: pNext As LongPtr: flags As Long: setLayoutCount As Long
    pSetLayouts As LongPtr: pushConstantRangeCount As Long: pad1 As Long: pPushConstantRanges As LongPtr
End Type

Private Type VkGraphicsPipelineCreateInfo
    sType As Long: pad0 As Long: pNext As LongPtr: flags As Long: stageCount As Long: pStages As LongPtr
    pVertexInputState As LongPtr: pInputAssemblyState As LongPtr: pTessellationState As LongPtr
    pViewportState As LongPtr: pRasterizationState As LongPtr: pMultisampleState As LongPtr
    pDepthStencilState As LongPtr: pColorBlendState As LongPtr: pDynamicState As LongPtr
    layout As LongPtr: renderPass As LongPtr: subpass As Long: pad1 As Long
    basePipelineHandle As LongPtr: basePipelineIndex As Long: pad2 As Long
End Type

Private Type VkComputePipelineCreateInfo
    sType As Long: pad0 As Long: pNext As LongPtr: flags As Long: pad1 As Long
    stage As VkPipelineShaderStageCreateInfo: layout As LongPtr
    basePipelineHandle As LongPtr: basePipelineIndex As Long: pad2 As Long
End Type

Private Type VkSubmitInfo
    sType As Long: pad0 As Long: pNext As LongPtr: waitSemaphoreCount As Long: pad1 As Long
    pWaitSemaphores As LongPtr: pWaitDstStageMask As LongPtr: commandBufferCount As Long: pad2 As Long
    pCommandBuffers As LongPtr: signalSemaphoreCount As Long: pad3 As Long: pSignalSemaphores As LongPtr
End Type

Private Type VkPresentInfoKHR
    sType As Long: pad0 As Long: pNext As LongPtr: waitSemaphoreCount As Long: pad1 As Long
    pWaitSemaphores As LongPtr: swapchainCount As Long: pad2 As Long
    pSwapchains As LongPtr: pImageIndices As LongPtr: pResults As LongPtr
End Type

Private Type VkBufferCreateInfo
    sType As Long: pad0 As Long: pNext As LongPtr: flags As Long: pad1 As Long
    size As LongLong: usage As Long: sharingMode As Long: queueFamilyIndexCount As Long: pad2 As Long: pQueueFamilyIndices As LongPtr
End Type

Private Type VkMemoryRequirements: size As LongLong: alignment As LongLong: memoryTypeBits As Long: pad0 As Long: End Type

Private Type VkMemoryAllocateInfo
    sType As Long: pad0 As Long: pNext As LongPtr: allocationSize As LongLong: memoryTypeIndex As Long: pad1 As Long
End Type

Private Type VkMemoryType: propertyFlags As Long: heapIndex As Long: End Type
Private Type VkMemoryHeap: size As LongLong: flags As Long: pad0 As Long: End Type

Private Type VkPhysicalDeviceMemoryProperties
    memoryTypeCount As Long
    memoryTypes(0 To 31) As VkMemoryType
    memoryHeapCount As Long
    memoryHeaps(0 To 15) As VkMemoryHeap
End Type

Private Type VkDescriptorSetLayoutBinding
    binding As Long: descriptorType As Long: descriptorCount As Long: stageFlags As Long: pImmutableSamplers As LongPtr
End Type

Private Type VkDescriptorSetLayoutCreateInfo
    sType As Long: pad0 As Long: pNext As LongPtr: flags As Long: bindingCount As Long: pBindings As LongPtr
End Type

Private Type VkDescriptorPoolSize: descriptorType As Long: descriptorCount As Long: End Type

Private Type VkDescriptorPoolCreateInfo
    sType As Long: pad0 As Long: pNext As LongPtr: flags As Long: maxSets As Long
    poolSizeCount As Long: pad1 As Long: pPoolSizes As LongPtr
End Type

Private Type VkDescriptorSetAllocateInfo
    sType As Long: pad0 As Long: pNext As LongPtr: descriptorPool As LongPtr
    descriptorSetCount As Long: pad1 As Long: pSetLayouts As LongPtr
End Type

Private Type VkDescriptorBufferInfo: buffer As LongPtr: offset As LongLong: range As LongLong: End Type

Private Type VkWriteDescriptorSet
    sType As Long: pad0 As Long: pNext As LongPtr: dstSet As LongPtr: dstBinding As Long: dstArrayElement As Long
    descriptorCount As Long: descriptorType As Long: pImageInfo As LongPtr: pBufferInfo As LongPtr: pTexelBufferView As LongPtr
End Type

Private Type VkBufferMemoryBarrier
    sType As Long: pad0 As Long: pNext As LongPtr: srcAccessMask As Long: dstAccessMask As Long
    srcQueueFamilyIndex As Long: dstQueueFamilyIndex As Long: buffer As LongPtr: offset As LongLong: size As LongLong
End Type

Private Type ParamsUBO
    max_num As Long: dt As Single: scale_ As Single: pad0 As Single
    A1 As Single: f1 As Single: p1 As Single: d1 As Single
    A2 As Single: f2 As Single: p2 As Single: d2 As Single
    A3 As Single: f3 As Single: p3 As Single: d3 As Single
    A4 As Single: f4 As Single: p4 As Single: d4 As Single
End Type

' Global state
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
Private p_vkGetPhysicalDeviceMemoryProperties As LongPtr
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
Private p_vkCreateComputePipelines As LongPtr
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
Private p_vkCmdDispatch As LongPtr
Private p_vkCmdSetViewport As LongPtr
Private p_vkCmdSetScissor As LongPtr
Private p_vkCmdPipelineBarrier As LongPtr
Private p_vkCmdBindDescriptorSets As LongPtr
Private p_vkCreateSemaphore As LongPtr
Private p_vkDestroySemaphore As LongPtr
Private p_vkCreateFence As LongPtr
Private p_vkDestroyFence As LongPtr
Private p_vkWaitForFences As LongPtr
Private p_vkResetFences As LongPtr
Private p_vkQueueSubmit As LongPtr
Private p_vkDeviceWaitIdle As LongPtr
Private p_vkCreateBuffer As LongPtr
Private p_vkDestroyBuffer As LongPtr
Private p_vkGetBufferMemoryRequirements As LongPtr
Private p_vkAllocateMemory As LongPtr
Private p_vkFreeMemory As LongPtr
Private p_vkBindBufferMemory As LongPtr
Private p_vkMapMemory As LongPtr
Private p_vkUnmapMemory As LongPtr
Private p_vkCreateDescriptorSetLayout As LongPtr
Private p_vkDestroyDescriptorSetLayout As LongPtr
Private p_vkCreateDescriptorPool As LongPtr
Private p_vkDestroyDescriptorPool As LongPtr
Private p_vkAllocateDescriptorSets As LongPtr
Private p_vkUpdateDescriptorSets As LongPtr

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
Private qFamilyGraphics As Long
Private vkSwapchain As LongPtr
Private swapImageFormat As Long
Private swapExtent As VkExtent2D
Private swapImageCount As Long
Private swapImages() As LongPtr
Private swapImageViews() As LongPtr
Private swapFramebuffers() As LongPtr
Private vkRenderPass As LongPtr
Private vkGraphicsPipelineLayout As LongPtr
Private vkGraphicsPipeline As LongPtr
Private vkComputePipelineLayout As LongPtr
Private vkComputePipeline As LongPtr
Private vkCommandPool As LongPtr
Private vkCmdBuffers() As LongPtr
Private semImageAvailable As LongPtr
Private semRenderFinished As LongPtr
Private fenceInFlight As LongPtr
Private shaderVertModule As LongPtr
Private shaderFragModule As LongPtr
Private shaderCompModule As LongPtr
Private posBuffer As LongPtr
Private posMemory As LongPtr
Private colBuffer As LongPtr
Private colMemory As LongPtr
Private uboBuffer As LongPtr
Private uboMemory As LongPtr
Private vkDescriptorSetLayout As LongPtr
Private vkDescriptorPool As LongPtr
Private vkDescriptorSet As LongPtr
Private memoryProperties As VkPhysicalDeviceMemoryProperties
Private uboParams As ParamsUBO
Private g_startTime As LongLong
Private g_perfFreq As LongLong

' Utility functions
Private Sub LogInit()
    On Error Resume Next
    If Dir$("C:\TEMP", vbDirectory) = "" Then MkDir "C:\TEMP"
    g_logEnabled = True
    LogLine "============================================================"
    LogLine "START " & format$(Now, "yyyy-mm-dd hh:nn:ss")
End Sub

Private Sub LogLine(ByVal s As String)
    If Not g_logEnabled Then Exit Sub
    Dim f As Integer: f = FreeFile
    On Error Resume Next
    Open LOG_PATH For Append As #f
    Print #f, format$(Now, "hh:nn:ss") & " | " & s
    Close #f
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
    Dim b() As Byte: b = StrConv(s, vbFromUnicode)
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
    Dim b() As Byte: ReDim b(0 To i - 1) As Byte
    RtlMoveMemory VarPtr(b(0)), p, i
    PtrToAnsiString = StrConv(b, vbUnicode)
End Function

Private Function GetEnvW(ByVal name As String) As String
    Dim buf As String: buf = String$(2048, vbNullChar)
    Dim n As Long: n = GetEnvironmentVariableW(StrPtr(name), StrPtr(buf), Len(buf))
    If n <= 0 Then GetEnvW = "" Else GetEnvW = Left$(buf, n)
End Function

Private Function FindShadercDll() As String
    Dim vulkanSdk As String: vulkanSdk = GetEnvW("VULKAN_SDK")
    If vulkanSdk <> "" Then
        Dim p As String: p = vulkanSdk & "\Bin\shaderc_shared.dll"
        If Dir$(p) <> "" Then FindShadercDll = p: Exit Function
    End If
    Dim base As String: base = "C:\VulkanSDK\"
    Dim v As String, best As String: v = Dir$(base & "*", vbDirectory)
    Do While v <> ""
        If v <> "." And v <> ".." Then
            On Error Resume Next
            If (GetAttr(base & v) And vbDirectory) <> 0 Then
                Dim cand As String: cand = base & v & "\Bin\shaderc_shared.dll"
                If Dir$(cand) <> "" Then best = cand
            End If
            On Error GoTo 0
        End If
        v = Dir$
    Loop
    FindShadercDll = best
End Function

' Thunk functions
Private Function GetThunk(ByVal fnPtr As LongPtr, ByVal argc As Long) As LongPtr
    Dim i As Long
    For i = 1 To g_thunkCount
        If g_thunks(i).fnPtr = fnPtr And g_thunks(i).argc = argc Then
            GetThunk = g_thunks(i).stubPtr: Exit Function
        End If
    Next
    Dim stub As LongPtr: stub = BuildThunk(fnPtr, argc)
    g_thunkCount = g_thunkCount + 1
    ReDim Preserve g_thunks(1 To g_thunkCount)
    g_thunks(g_thunkCount).fnPtr = fnPtr
    g_thunks(g_thunkCount).argc = argc
    g_thunks(g_thunkCount).stubPtr = stub
    GetThunk = stub
End Function

Private Function BuildThunk(ByVal fnPtr As LongPtr, ByVal argc As Long) As LongPtr
    If argc < 0 Or argc > 12 Then Err.Raise 5
    Dim stackArgs As Long: If argc > 4 Then stackArgs = argc - 4
    Dim pad8 As Long: If (stackArgs And 1) <> 0 Then pad8 = 1
    Dim allocBytes As Long: allocBytes = &H28 + (stackArgs * 8) + (pad8 * 8)
    Dim codeSize As Long: codeSize = 256
    Dim mem As LongPtr: mem = VirtualAlloc(0, codeSize, MEM_RESERVE Or MEM_COMMIT, PAGE_EXECUTE_READWRITE)
    If mem = 0 Then Err.Raise 5
    Dim b() As Byte: ReDim b(0 To codeSize - 1) As Byte
    Dim pIdx As Long: pIdx = 0
    b(pIdx) = &H4C: b(pIdx + 1) = &H8B: b(pIdx + 2) = &HD9: pIdx = pIdx + 3
    b(pIdx) = &H48: b(pIdx + 1) = &H83: b(pIdx + 2) = &HEC: b(pIdx + 3) = CByte(allocBytes): pIdx = pIdx + 4
    b(pIdx) = &H48: b(pIdx + 1) = &HB8: pIdx = pIdx + 2
    Dim tmpLL As LongLong: tmpLL = CLngLng(fnPtr)
    RtlMoveMemory mem + pIdx, VarPtr(tmpLL), 8
    pIdx = pIdx + 8
    If argc >= 1 Then b(pIdx) = &H49: b(pIdx + 1) = &H8B: b(pIdx + 2) = &HB: pIdx = pIdx + 3
    If argc >= 2 Then b(pIdx) = &H49: b(pIdx + 1) = &H8B: b(pIdx + 2) = &H53: b(pIdx + 3) = &H8: pIdx = pIdx + 4
    If argc >= 3 Then b(pIdx) = &H4D: b(pIdx + 1) = &H8B: b(pIdx + 2) = &H43: b(pIdx + 3) = &H10: pIdx = pIdx + 4
    If argc >= 4 Then b(pIdx) = &H4D: b(pIdx + 1) = &H8B: b(pIdx + 2) = &H4B: b(pIdx + 3) = &H18: pIdx = pIdx + 4
    Dim i As Long
    For i = 4 To argc - 1
        Dim offArg As Byte: offArg = CByte(i * 8)
        Dim offStk As Byte: offStk = CByte(&H20 + (i - 4) * 8)
        b(pIdx) = &H4D: b(pIdx + 1) = &H8B: b(pIdx + 2) = &H53: b(pIdx + 3) = offArg: pIdx = pIdx + 4
        b(pIdx) = &H4C: b(pIdx + 1) = &H89: b(pIdx + 2) = &H54: b(pIdx + 3) = &H24: b(pIdx + 4) = offStk: pIdx = pIdx + 5
    Next
    b(pIdx) = &HFF: b(pIdx + 1) = &HD0: pIdx = pIdx + 2
    b(pIdx) = &H48: b(pIdx + 1) = &H83: b(pIdx + 2) = &HC4: b(pIdx + 3) = CByte(allocBytes): pIdx = pIdx + 4
    b(pIdx) = &HC3: pIdx = pIdx + 1
    RtlMoveMemory mem, VarPtr(b(0)), pIdx
    Dim immPos As Long: immPos = 3 + 4 + 2
    RtlMoveMemory mem + immPos, VarPtr(tmpLL), 8
    BuildThunk = mem
End Function

Private Function InvokeRaw(ByVal fnPtr As LongPtr, ByVal argc As Long, ByRef argv() As LongLong) As LongLong
    Dim stub As LongPtr: stub = GetThunk(fnPtr, argc)
    Dim argMem As LongPtr
    If argc > 0 Then
        argMem = CoTaskMemAlloc(argc * 8)
        If argMem = 0 Then Err.Raise 5
        RtlMoveMemory argMem, VarPtr(argv(0)), argc * 8
    End If
    Dim ret As LongPtr: ret = CallWindowProcW(stub, argMem, 0, 0, 0)
    If argMem <> 0 Then CoTaskMemFree argMem
    InvokeRaw = CLngLng(ret)
End Function

Private Function InvokeI32(ByVal fnPtr As LongPtr, ByVal argc As Long, ByRef argv() As LongLong) As Long
    InvokeI32 = CLng(InvokeRaw(fnPtr, argc, argv) And &HFFFFFFFF)
End Function

Private Function InvokePtr0(ByVal fnPtr As LongPtr) As LongPtr
    Dim dummy(0 To 0) As LongLong
    InvokePtr0 = CLngPtr(InvokeRaw(fnPtr, 0, dummy))
End Function

Private Sub VkCheck(ByVal res As Long, ByVal what As String)
    If res <> VK_SUCCESS And res <> VK_SUBOPTIMAL_KHR Then
        LogLine "VK_FAIL " & what & " VkResult=" & CStr(res)
        Err.Raise 5, , what & " failed VkResult=" & res
    Else
        LogLine "VK_OK " & what
    End If
End Sub

Private Function WndProc(ByVal hwnd As LongPtr, ByVal uMsg As Long, ByVal wParam As LongPtr, ByVal lParam As LongPtr) As LongPtr
    Select Case uMsg
        Case WM_KEYDOWN: If wParam = VK_ESCAPE Then g_quit = True
        Case WM_CLOSE: g_quit = True: WndProc = 0: Exit Function
        Case WM_DESTROY: g_quit = True
    End Select
    WndProc = DefWindowProcW(hwnd, uMsg, wParam, lParam)
End Function

Private Sub CreateAppWindow(ByVal w As Long, ByVal h As Long)
    g_hInst = GetModuleHandleW(0)
    Dim clsName As String: clsName = "VBA_VK_HARMONOGRAPH"
    Dim wc As WNDCLASSEXW
    wc.cbSize = LenB(wc)
    wc.lpfnWndProc = VBA.CLngPtr(AddressOf WndProc)
    wc.hInstance = g_hInst
    wc.lpszClassName = StrPtr(clsName)
    If RegisterClassExW(wc) = 0 Then Err.Raise 5
    Dim title As String: title = "Harmonograph - Vulkan 1.4 Compute / VBA x64"
    g_hwnd = CreateWindowExW(0, StrPtr(clsName), StrPtr(title), WS_OVERLAPPEDWINDOW Or WS_VISIBLE, CW_USEDEFAULT, CW_USEDEFAULT, w, h, 0, 0, g_hInst, 0)
    If g_hwnd = 0 Then Err.Raise 5
    ShowWindow g_hwnd, 1
    UpdateWindow g_hwnd
End Sub

Private Sub LoadVulkanLoader()
    LogLine "LoadVulkanLoader..."
    g_hVulkan = LoadLibraryW(StrPtr("vulkan-1.dll"))
    If g_hVulkan = 0 Then Err.Raise 5
    p_vkGetInstanceProcAddr = GetProcAddress(g_hVulkan, "vkGetInstanceProcAddr")
    p_vkGetDeviceProcAddr = GetProcAddress(g_hVulkan, "vkGetDeviceProcAddr")
    p_vkCreateInstance = GetProcAddress(g_hVulkan, "vkCreateInstance")
    If p_vkCreateInstance = 0 Then Err.Raise 5
End Sub

Private Function VkGetInstanceProc(ByVal inst As LongPtr, ByVal name As String) As LongPtr
    Dim argv(0 To 1) As LongLong
    argv(0) = CLngLng(inst): argv(1) = CLngLng(AllocAnsiZ(name))
    VkGetInstanceProc = CLngPtr(InvokeRaw(p_vkGetInstanceProcAddr, 2, argv))
End Function

Private Function VkGetDeviceProc(ByVal dev As LongPtr, ByVal name As String) As LongPtr
    Dim argv(0 To 1) As LongLong
    argv(0) = CLngLng(dev): argv(1) = CLngLng(AllocAnsiZ(name))
    VkGetDeviceProc = CLngPtr(InvokeRaw(p_vkGetDeviceProcAddr, 2, argv))
End Function

Private Sub LoadVulkanInstanceFuncs()
    p_vkDestroyInstance = VkGetInstanceProc(vkInstance, "vkDestroyInstance")
    p_vkEnumeratePhysicalDevices = VkGetInstanceProc(vkInstance, "vkEnumeratePhysicalDevices")
    p_vkGetPhysicalDeviceQueueFamilyProperties = VkGetInstanceProc(vkInstance, "vkGetPhysicalDeviceQueueFamilyProperties")
    p_vkGetPhysicalDeviceMemoryProperties = VkGetInstanceProc(vkInstance, "vkGetPhysicalDeviceMemoryProperties")
    p_vkCreateDevice = VkGetInstanceProc(vkInstance, "vkCreateDevice")
    p_vkCreateWin32SurfaceKHR = VkGetInstanceProc(vkInstance, "vkCreateWin32SurfaceKHR")
    p_vkDestroySurfaceKHR = VkGetInstanceProc(vkInstance, "vkDestroySurfaceKHR")
    p_vkGetPhysicalDeviceSurfaceSupportKHR = VkGetInstanceProc(vkInstance, "vkGetPhysicalDeviceSurfaceSupportKHR")
    p_vkGetPhysicalDeviceSurfaceFormatsKHR = VkGetInstanceProc(vkInstance, "vkGetPhysicalDeviceSurfaceFormatsKHR")
    p_vkGetPhysicalDeviceSurfaceCapabilitiesKHR = VkGetInstanceProc(vkInstance, "vkGetPhysicalDeviceSurfaceCapabilitiesKHR")
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
    p_vkCreateComputePipelines = VkGetDeviceProc(vkDevice, "vkCreateComputePipelines")
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
    p_vkCmdDispatch = VkGetDeviceProc(vkDevice, "vkCmdDispatch")
    p_vkCmdSetViewport = VkGetDeviceProc(vkDevice, "vkCmdSetViewport")
    p_vkCmdSetScissor = VkGetDeviceProc(vkDevice, "vkCmdSetScissor")
    p_vkCmdPipelineBarrier = VkGetDeviceProc(vkDevice, "vkCmdPipelineBarrier")
    p_vkCmdBindDescriptorSets = VkGetDeviceProc(vkDevice, "vkCmdBindDescriptorSets")
    p_vkCreateSemaphore = VkGetDeviceProc(vkDevice, "vkCreateSemaphore")
    p_vkDestroySemaphore = VkGetDeviceProc(vkDevice, "vkDestroySemaphore")
    p_vkCreateFence = VkGetDeviceProc(vkDevice, "vkCreateFence")
    p_vkDestroyFence = VkGetDeviceProc(vkDevice, "vkDestroyFence")
    p_vkWaitForFences = VkGetDeviceProc(vkDevice, "vkWaitForFences")
    p_vkResetFences = VkGetDeviceProc(vkDevice, "vkResetFences")
    p_vkQueueSubmit = VkGetDeviceProc(vkDevice, "vkQueueSubmit")
    p_vkDeviceWaitIdle = VkGetDeviceProc(vkDevice, "vkDeviceWaitIdle")
    p_vkCreateBuffer = VkGetDeviceProc(vkDevice, "vkCreateBuffer")
    p_vkDestroyBuffer = VkGetDeviceProc(vkDevice, "vkDestroyBuffer")
    p_vkGetBufferMemoryRequirements = VkGetDeviceProc(vkDevice, "vkGetBufferMemoryRequirements")
    p_vkAllocateMemory = VkGetDeviceProc(vkDevice, "vkAllocateMemory")
    p_vkFreeMemory = VkGetDeviceProc(vkDevice, "vkFreeMemory")
    p_vkBindBufferMemory = VkGetDeviceProc(vkDevice, "vkBindBufferMemory")
    p_vkMapMemory = VkGetDeviceProc(vkDevice, "vkMapMemory")
    p_vkUnmapMemory = VkGetDeviceProc(vkDevice, "vkUnmapMemory")
    p_vkCreateDescriptorSetLayout = VkGetDeviceProc(vkDevice, "vkCreateDescriptorSetLayout")
    p_vkDestroyDescriptorSetLayout = VkGetDeviceProc(vkDevice, "vkDestroyDescriptorSetLayout")
    p_vkCreateDescriptorPool = VkGetDeviceProc(vkDevice, "vkCreateDescriptorPool")
    p_vkDestroyDescriptorPool = VkGetDeviceProc(vkDevice, "vkDestroyDescriptorPool")
    p_vkAllocateDescriptorSets = VkGetDeviceProc(vkDevice, "vkAllocateDescriptorSets")
    p_vkUpdateDescriptorSets = VkGetDeviceProc(vkDevice, "vkUpdateDescriptorSets")
End Sub

Private Sub LoadShaderc()
    LogLine "LoadShaderc..."
    Dim path As String: path = FindShadercDll()
    If path = "" Then Err.Raise 5, , "shaderc_shared.dll not found"
    Dim binDir As String: binDir = Left$(path, InStrRev(path, "\") - 1)
    Call SetDllDirectoryW(StrPtr(binDir))
    g_hShaderc = LoadLibraryW(StrPtr(path))
    If g_hShaderc = 0 Then Err.Raise 5
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
    LogLine "shaderc loaded: " & path
End Sub

Private Function ShadercCompileSpv(ByVal glsl As String, ByVal kind As Long, ByVal fileName As String) As Byte()
    LogLine "Compiling: " & fileName
    Dim spv() As Byte, compiler As LongPtr, options As LongPtr, result As LongPtr
    Dim srcBytes() As Byte, argv(0 To 6) As LongLong, argv1(0 To 0) As LongLong
    On Error GoTo EH
    compiler = InvokePtr0(p_shaderc_compiler_initialize)
    If compiler = 0 Then Err.Raise 5
    options = InvokePtr0(p_shaderc_compile_options_initialize)
    srcBytes = StrConv(glsl, vbFromUnicode)
    argv(0) = CLngLng(compiler)
    argv(1) = CLngLng(VarPtr(srcBytes(0)))
    argv(2) = CLngLng(UBound(srcBytes) - LBound(srcBytes) + 1)
    argv(3) = CLngLng(kind)
    argv(4) = CLngLng(AllocAnsiZ(fileName))
    argv(5) = CLngLng(AllocAnsiZ("main"))
    argv(6) = CLngLng(options)
    result = CLngPtr(InvokeRaw(p_shaderc_compile_into_spv, 7, argv))
    If result = 0 Then Err.Raise 5
    argv1(0) = CLngLng(result)
    Dim status As Long: status = InvokeI32(p_shaderc_result_get_compilation_status, 1, argv1)
    If status <> SHADERC_COMPILATION_STATUS_SUCCESS Then
        Dim pErr As LongPtr: pErr = CLngPtr(InvokeRaw(p_shaderc_result_get_error_message, 1, argv1))
        LogLine "shaderc FAILED: " & PtrToAnsiString(pErr)
        Err.Raise 5
    End If
    Dim outLen As Long: outLen = CLng(InvokeRaw(p_shaderc_result_get_length, 1, argv1))
    If outLen <= 0 Then GoTo CLEANUP
    Dim pOut As LongPtr: pOut = CLngPtr(InvokeRaw(p_shaderc_result_get_bytes, 1, argv1))
    ReDim spv(0 To outLen - 1) As Byte
    RtlMoveMemory VarPtr(spv(0)), pOut, CLngPtr(outLen)
    LogLine "Compiled " & outLen & " bytes"
    ShadercCompileSpv = spv
CLEANUP:
    On Error Resume Next
    If result <> 0 Then argv1(0) = CLngLng(result): Call InvokeRaw(p_shaderc_result_release, 1, argv1)
    If options <> 0 Then argv1(0) = CLngLng(options): Call InvokeRaw(p_shaderc_compile_options_release, 1, argv1)
    If compiler <> 0 Then argv1(0) = CLngLng(compiler): Call InvokeRaw(p_shaderc_compiler_release, 1, argv1)
    Exit Function
EH: LogLine "shaderc error: " & Err.Description: Resume CLEANUP
End Function

Private Sub VkCreateInstance_()
    LogLine "VkCreateInstance_..."
    Dim appInfo As VkApplicationInfo
    appInfo.sType = VK_STRUCTURE_TYPE_APPLICATION_INFO
    appInfo.pApplicationName = AllocAnsiZ("Harmonograph VBA")
    appInfo.applicationVersion = &H10000
    appInfo.pEngineName = AllocAnsiZ("No Engine")
    appInfo.engineVersion = &H10000
    appInfo.apiVersion = VK_API_VERSION_1_4
    Dim extPtrs(0 To 1) As LongPtr
    extPtrs(0) = AllocAnsiZ("VK_KHR_surface")
    extPtrs(1) = AllocAnsiZ("VK_KHR_win32_surface")
    Dim ci As VkInstanceCreateInfo
    ci.sType = VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO
    ci.pApplicationInfo = VarPtr(appInfo)
    ci.enabledExtensionCount = 2
    ci.ppEnabledExtensionNames = VarPtr(extPtrs(0))
    Dim pInst As LongPtr, argv(0 To 2) As LongLong
    argv(0) = CLngLng(VarPtr(ci)): argv(1) = 0: argv(2) = CLngLng(VarPtr(pInst))
    VkCheck InvokeI32(p_vkCreateInstance, 3, argv), "vkCreateInstance"
    vkInstance = pInst
    LoadVulkanInstanceFuncs
End Sub

Private Sub VkCreateSurface_()
    LogLine "VkCreateSurface_..."
    Dim sci As VkWin32SurfaceCreateInfoKHR
    sci.sType = VK_STRUCTURE_TYPE_WIN32_SURFACE_CREATE_INFO_KHR
    sci.hInstance = g_hInst: sci.hwnd = g_hwnd
    Dim pSurf As LongPtr, argv(0 To 3) As LongLong
    argv(0) = CLngLng(vkInstance): argv(1) = CLngLng(VarPtr(sci)): argv(2) = 0: argv(3) = CLngLng(VarPtr(pSurf))
    VkCheck InvokeI32(p_vkCreateWin32SurfaceKHR, 4, argv), "vkCreateWin32SurfaceKHR"
    vkSurface = pSurf
End Sub

Private Sub PickPhysicalDeviceAndQueues_()
    LogLine "PickPhysicalDeviceAndQueues_..."
    Dim count As Long, argvC(0 To 2) As LongLong
    argvC(0) = CLngLng(vkInstance): argvC(1) = CLngLng(VarPtr(count)): argvC(2) = 0
    VkCheck InvokeI32(p_vkEnumeratePhysicalDevices, 3, argvC), "vkEnumeratePhysicalDevices"
    If count <= 0 Then Err.Raise 5
    Dim devs() As LongPtr: ReDim devs(0 To count - 1) As LongLong
    argvC(2) = CLngLng(VarPtr(devs(0)))
    VkCheck InvokeI32(p_vkEnumeratePhysicalDevices, 3, argvC), "vkEnumeratePhysicalDevices"
    vkPhysicalDevice = devs(0)
    Dim qCount As Long, argvQ(0 To 2) As LongLong
    argvQ(0) = CLngLng(vkPhysicalDevice): argvQ(1) = CLngLng(VarPtr(qCount)): argvQ(2) = 0
    Call InvokeRaw(p_vkGetPhysicalDeviceQueueFamilyProperties, 3, argvQ)
    If qCount <= 0 Then Err.Raise 5
    Dim buf() As Byte: ReDim buf(0 To qCount * 24 - 1) As Byte
    argvQ(2) = CLngLng(VarPtr(buf(0)))
    Call InvokeRaw(p_vkGetPhysicalDeviceQueueFamilyProperties, 3, argvQ)
    qFamilyGraphics = -1
    Dim i As Long
    For i = 0 To qCount - 1
        Dim flags As Long: RtlMoveMemory VarPtr(flags), VarPtr(buf(i * 24)), 4
        If (flags And VK_QUEUE_GRAPHICS_BIT) <> 0 And (flags And VK_QUEUE_COMPUTE_BIT) <> 0 Then
            Dim supported As Long, argvS(0 To 3) As LongLong
            argvS(0) = CLngLng(vkPhysicalDevice): argvS(1) = CLngLng(i): argvS(2) = CLngLng(vkSurface): argvS(3) = CLngLng(VarPtr(supported))
            VkCheck InvokeI32(p_vkGetPhysicalDeviceSurfaceSupportKHR, 4, argvS), "vkGetPhysicalDeviceSurfaceSupportKHR"
            If supported <> 0 Then qFamilyGraphics = i: Exit For
        End If
    Next
    If qFamilyGraphics < 0 Then Err.Raise 5
    Dim argvM(0 To 1) As LongLong
    argvM(0) = CLngLng(vkPhysicalDevice): argvM(1) = CLngLng(VarPtr(memoryProperties))
    Call InvokeRaw(p_vkGetPhysicalDeviceMemoryProperties, 2, argvM)
    LogLine "queueFamily=" & CStr(qFamilyGraphics)
End Sub

Private Sub VkCreateDevice_()
    LogLine "VkCreateDevice_..."
    Dim priority As Single: priority = 1!
    Dim qci As VkDeviceQueueCreateInfo
    qci.sType = VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO
    qci.queueFamilyIndex = qFamilyGraphics: qci.queueCount = 1: qci.pQueuePriorities = VarPtr(priority)
    Dim extPtrs(0 To 0) As LongPtr: extPtrs(0) = AllocAnsiZ("VK_KHR_swapchain")
    Dim dci As VkDeviceCreateInfo
    dci.sType = VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO
    dci.queueCreateInfoCount = 1: dci.pQueueCreateInfos = VarPtr(qci)
    dci.enabledExtensionCount = 1: dci.ppEnabledExtensionNames = VarPtr(extPtrs(0))
    Dim pDev As LongPtr, argv(0 To 3) As LongLong
    argv(0) = CLngLng(vkPhysicalDevice): argv(1) = CLngLng(VarPtr(dci)): argv(2) = 0: argv(3) = CLngLng(VarPtr(pDev))
    VkCheck InvokeI32(p_vkCreateDevice, 4, argv), "vkCreateDevice"
    vkDevice = pDev
    LoadVulkanDeviceFuncs
    Dim argvQ(0 To 3) As LongLong
    argvQ(0) = CLngLng(vkDevice): argvQ(1) = CLngLng(qFamilyGraphics): argvQ(2) = 0: argvQ(3) = CLngLng(VarPtr(vkQueueGraphics))
    Call InvokeRaw(p_vkGetDeviceQueue, 4, argvQ)
End Sub

Private Sub VkCreateSwapchainAndViews_()
    LogLine "VkCreateSwapchainAndViews_..."
    Dim fmtCount As Long, argvF(0 To 3) As LongLong
    argvF(0) = CLngLng(vkPhysicalDevice): argvF(1) = CLngLng(vkSurface): argvF(2) = CLngLng(VarPtr(fmtCount)): argvF(3) = 0
    Call InvokeRaw(p_vkGetPhysicalDeviceSurfaceFormatsKHR, 4, argvF)
    If fmtCount <= 0 Then Err.Raise 5
    Dim fmts() As VkSurfaceFormatKHR: ReDim fmts(0 To fmtCount - 1) As VkSurfaceFormatKHR
    argvF(3) = CLngLng(VarPtr(fmts(0)))
    Call InvokeRaw(p_vkGetPhysicalDeviceSurfaceFormatsKHR, 4, argvF)
    swapImageFormat = fmts(0).format
    Dim caps As VkSurfaceCapabilitiesKHR, argvCaps(0 To 2) As LongLong
    argvCaps(0) = CLngLng(vkPhysicalDevice): argvCaps(1) = CLngLng(vkSurface): argvCaps(2) = CLngLng(VarPtr(caps))
    VkCheck InvokeI32(p_vkGetPhysicalDeviceSurfaceCapabilitiesKHR, 3, argvCaps), "vkGetPhysicalDeviceSurfaceCapabilitiesKHR"
    Dim rc As RECT: GetClientRect g_hwnd, rc
    swapExtent.width = rc.Right - rc.Left: swapExtent.height = rc.Bottom - rc.Top
    Dim desired As Long: desired = caps.minImageCount + 1
    If caps.maxImageCount > 0 And desired > caps.maxImageCount Then desired = caps.maxImageCount
    Dim sci As VkSwapchainCreateInfoKHR
    sci.sType = VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR
    sci.surface = vkSurface: sci.minImageCount = desired: sci.imageFormat = fmts(0).format
    sci.imageColorSpace = fmts(0).colorSpace: sci.imageExtent = swapExtent
    sci.imageArrayLayers = 1: sci.imageUsage = VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT
    sci.imageSharingMode = VK_SHARING_MODE_EXCLUSIVE: sci.preTransform = caps.currentTransform
    sci.compositeAlpha = VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR: sci.presentMode = VK_PRESENT_MODE_FIFO_KHR: sci.clipped = VK_TRUE
    Dim argv(0 To 3) As LongLong
    argv(0) = CLngLng(vkDevice): argv(1) = CLngLng(VarPtr(sci)): argv(2) = 0: argv(3) = CLngLng(VarPtr(vkSwapchain))
    VkCheck InvokeI32(p_vkCreateSwapchainKHR, 4, argv), "vkCreateSwapchainKHR"
    Dim argvI(0 To 3) As LongLong
    argvI(0) = CLngLng(vkDevice): argvI(1) = CLngLng(vkSwapchain): argvI(2) = CLngLng(VarPtr(swapImageCount)): argvI(3) = 0
    VkCheck InvokeI32(p_vkGetSwapchainImagesKHR, 4, argvI), "vkGetSwapchainImagesKHR"
    ReDim swapImages(0 To swapImageCount - 1) As LongLong
    argvI(3) = CLngLng(VarPtr(swapImages(0)))
    VkCheck InvokeI32(p_vkGetSwapchainImagesKHR, 4, argvI), "vkGetSwapchainImagesKHR"
    ReDim swapImageViews(0 To swapImageCount - 1) As LongLong
    Dim i As Long
    For i = 0 To swapImageCount - 1
        Dim iv As VkImageViewCreateInfo
        iv.sType = VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO: iv.image = swapImages(i)
        iv.viewType = VK_IMAGE_VIEW_TYPE_2D: iv.format = swapImageFormat
        iv.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT: iv.levelCount = 1: iv.layerCount = 1
        Dim argvV(0 To 3) As LongLong
        argvV(0) = CLngLng(vkDevice): argvV(1) = CLngLng(VarPtr(iv)): argvV(2) = 0: argvV(3) = CLngLng(VarPtr(swapImageViews(i)))
        VkCheck InvokeI32(p_vkCreateImageView, 4, argvV), "vkCreateImageView"
    Next
End Sub

Private Sub VkCreateRenderPass_()
    LogLine "VkCreateRenderPass_..."
    Dim colorAttach As VkAttachmentDescription
    colorAttach.format = swapImageFormat: colorAttach.samples = VK_SAMPLE_COUNT_1_BIT
    colorAttach.loadOp = VK_ATTACHMENT_LOAD_OP_CLEAR: colorAttach.storeOp = VK_ATTACHMENT_STORE_OP_STORE
    colorAttach.stencilLoadOp = VK_ATTACHMENT_LOAD_OP_DONT_CARE: colorAttach.stencilStoreOp = VK_ATTACHMENT_STORE_OP_DONT_CARE
    colorAttach.initialLayout = VK_IMAGE_LAYOUT_UNDEFINED: colorAttach.finalLayout = VK_IMAGE_LAYOUT_PRESENT_SRC_KHR
    Dim colorRef As VkAttachmentReference: colorRef.attachment = 0: colorRef.layout = VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL
    Dim subpass As VkSubpassDescription
    subpass.pipelineBindPoint = VK_PIPELINE_BIND_POINT_GRAPHICS: subpass.colorAttachmentCount = 1: subpass.pColorAttachments = VarPtr(colorRef)
    Dim rpci As VkRenderPassCreateInfo
    rpci.sType = VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO: rpci.attachmentCount = 1: rpci.pAttachments = VarPtr(colorAttach)
    rpci.subpassCount = 1: rpci.pSubpasses = VarPtr(subpass)
    Dim argv(0 To 3) As LongLong
    argv(0) = CLngLng(vkDevice): argv(1) = CLngLng(VarPtr(rpci)): argv(2) = 0: argv(3) = CLngLng(VarPtr(vkRenderPass))
    VkCheck InvokeI32(p_vkCreateRenderPass, 4, argv), "vkCreateRenderPass"
End Sub

Private Sub VkCreateFramebuffers_()
    LogLine "VkCreateFramebuffers_..."
    ReDim swapFramebuffers(0 To swapImageCount - 1) As LongLong
    Dim i As Long
    For i = 0 To swapImageCount - 1
        Dim fbci As VkFramebufferCreateInfo
        fbci.sType = VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO: fbci.renderPass = vkRenderPass
        fbci.attachmentCount = 1: fbci.pAttachments = VarPtr(swapImageViews(i))
        fbci.width = swapExtent.width: fbci.height = swapExtent.height: fbci.layers = 1
        Dim argv(0 To 3) As LongLong
        argv(0) = CLngLng(vkDevice): argv(1) = CLngLng(VarPtr(fbci)): argv(2) = 0: argv(3) = CLngLng(VarPtr(swapFramebuffers(i)))
        VkCheck InvokeI32(p_vkCreateFramebuffer, 4, argv), "vkCreateFramebuffer"
    Next
End Sub

Private Function FindMemoryType(ByVal typeFilter As Long, ByVal properties As Long) As Long
    Dim i As Long
    For i = 0 To memoryProperties.memoryTypeCount - 1
        If (typeFilter And (2 ^ i)) <> 0 Then
            If (memoryProperties.memoryTypes(i).propertyFlags And properties) = properties Then
                FindMemoryType = i: Exit Function
            End If
        End If
    Next
    Err.Raise 5, , "No suitable memory type"
End Function

Private Sub CreateBuffer(ByVal size As LongLong, ByVal usage As Long, ByVal memProps As Long, ByRef outBuffer As LongPtr, ByRef outMemory As LongPtr)
    Dim bufInfo As VkBufferCreateInfo
    bufInfo.sType = VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO: bufInfo.size = size
    bufInfo.usage = usage: bufInfo.sharingMode = VK_SHARING_MODE_EXCLUSIVE
    Dim argv(0 To 3) As LongLong
    argv(0) = CLngLng(vkDevice): argv(1) = CLngLng(VarPtr(bufInfo)): argv(2) = 0: argv(3) = CLngLng(VarPtr(outBuffer))
    VkCheck InvokeI32(p_vkCreateBuffer, 4, argv), "vkCreateBuffer"
    Dim memReq As VkMemoryRequirements, argvM(0 To 2) As LongLong
    argvM(0) = CLngLng(vkDevice): argvM(1) = CLngLng(outBuffer): argvM(2) = CLngLng(VarPtr(memReq))
    Call InvokeRaw(p_vkGetBufferMemoryRequirements, 3, argvM)
    Dim allocInfo As VkMemoryAllocateInfo
    allocInfo.sType = VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO: allocInfo.allocationSize = memReq.size
    allocInfo.memoryTypeIndex = FindMemoryType(memReq.memoryTypeBits, memProps)
    Dim argvA(0 To 3) As LongLong
    argvA(0) = CLngLng(vkDevice): argvA(1) = CLngLng(VarPtr(allocInfo)): argvA(2) = 0: argvA(3) = CLngLng(VarPtr(outMemory))
    VkCheck InvokeI32(p_vkAllocateMemory, 4, argvA), "vkAllocateMemory"
    Dim argvB(0 To 3) As LongLong
    argvB(0) = CLngLng(vkDevice): argvB(1) = CLngLng(outBuffer): argvB(2) = CLngLng(outMemory): argvB(3) = 0
    VkCheck InvokeI32(p_vkBindBufferMemory, 4, argvB), "vkBindBufferMemory"
End Sub

Private Sub VkCreateBuffers_()
    LogLine "VkCreateBuffers_..."
    CreateBuffer CLngLng(VERTEX_COUNT) * 16, VK_BUFFER_USAGE_STORAGE_BUFFER_BIT, VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT, posBuffer, posMemory
    CreateBuffer CLngLng(VERTEX_COUNT) * 16, VK_BUFFER_USAGE_STORAGE_BUFFER_BIT, VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT, colBuffer, colMemory
    CreateBuffer LenB(uboParams), VK_BUFFER_USAGE_UNIFORM_BUFFER_BIT, VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT Or VK_MEMORY_PROPERTY_HOST_COHERENT_BIT, uboBuffer, uboMemory
End Sub

Private Sub VkCreateDescriptorSetLayout_()
    LogLine "VkCreateDescriptorSetLayout_..."
    Dim bindings(0 To 2) As VkDescriptorSetLayoutBinding
    bindings(0).binding = 0: bindings(0).descriptorType = VK_DESCRIPTOR_TYPE_STORAGE_BUFFER
    bindings(0).descriptorCount = 1: bindings(0).stageFlags = VK_SHADER_STAGE_COMPUTE_BIT Or VK_SHADER_STAGE_VERTEX_BIT
    bindings(1).binding = 1: bindings(1).descriptorType = VK_DESCRIPTOR_TYPE_STORAGE_BUFFER
    bindings(1).descriptorCount = 1: bindings(1).stageFlags = VK_SHADER_STAGE_COMPUTE_BIT Or VK_SHADER_STAGE_VERTEX_BIT
    bindings(2).binding = 2: bindings(2).descriptorType = VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER
    bindings(2).descriptorCount = 1: bindings(2).stageFlags = VK_SHADER_STAGE_COMPUTE_BIT
    Dim layoutInfo As VkDescriptorSetLayoutCreateInfo
    layoutInfo.sType = VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO: layoutInfo.bindingCount = 3: layoutInfo.pBindings = VarPtr(bindings(0))
    Dim argv(0 To 3) As LongLong
    argv(0) = CLngLng(vkDevice): argv(1) = CLngLng(VarPtr(layoutInfo)): argv(2) = 0: argv(3) = CLngLng(VarPtr(vkDescriptorSetLayout))
    VkCheck InvokeI32(p_vkCreateDescriptorSetLayout, 4, argv), "vkCreateDescriptorSetLayout"
End Sub

Private Sub VkCreateDescriptorPool_()
    LogLine "VkCreateDescriptorPool_..."
    Dim poolSizes(0 To 1) As VkDescriptorPoolSize
    poolSizes(0).descriptorType = VK_DESCRIPTOR_TYPE_STORAGE_BUFFER: poolSizes(0).descriptorCount = 2
    poolSizes(1).descriptorType = VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER: poolSizes(1).descriptorCount = 1
    Dim poolInfo As VkDescriptorPoolCreateInfo
    poolInfo.sType = VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO: poolInfo.maxSets = 1
    poolInfo.poolSizeCount = 2: poolInfo.pPoolSizes = VarPtr(poolSizes(0))
    Dim argv(0 To 3) As LongLong
    argv(0) = CLngLng(vkDevice): argv(1) = CLngLng(VarPtr(poolInfo)): argv(2) = 0: argv(3) = CLngLng(VarPtr(vkDescriptorPool))
    VkCheck InvokeI32(p_vkCreateDescriptorPool, 4, argv), "vkCreateDescriptorPool"
End Sub

Private Sub VkAllocateDescriptorSets_()
    LogLine "VkAllocateDescriptorSets_..."
    Dim allocInfo As VkDescriptorSetAllocateInfo
    allocInfo.sType = VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO: allocInfo.descriptorPool = vkDescriptorPool
    allocInfo.descriptorSetCount = 1: allocInfo.pSetLayouts = VarPtr(vkDescriptorSetLayout)
    Dim argv(0 To 2) As LongLong
    argv(0) = CLngLng(vkDevice): argv(1) = CLngLng(VarPtr(allocInfo)): argv(2) = CLngLng(VarPtr(vkDescriptorSet))
    VkCheck InvokeI32(p_vkAllocateDescriptorSets, 3, argv), "vkAllocateDescriptorSets"
End Sub

Private Sub VkUpdateDescriptorSets_()
    LogLine "VkUpdateDescriptorSets_..."
    Dim posInfo As VkDescriptorBufferInfo: posInfo.buffer = posBuffer: posInfo.range = CLngLng(VERTEX_COUNT) * 16
    Dim colInfo As VkDescriptorBufferInfo: colInfo.buffer = colBuffer: colInfo.range = CLngLng(VERTEX_COUNT) * 16
    Dim uboInfo As VkDescriptorBufferInfo: uboInfo.buffer = uboBuffer: uboInfo.range = LenB(uboParams)
    Dim writes(0 To 2) As VkWriteDescriptorSet
    writes(0).sType = VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET: writes(0).dstSet = vkDescriptorSet: writes(0).dstBinding = 0
    writes(0).descriptorCount = 1: writes(0).descriptorType = VK_DESCRIPTOR_TYPE_STORAGE_BUFFER: writes(0).pBufferInfo = VarPtr(posInfo)
    writes(1).sType = VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET: writes(1).dstSet = vkDescriptorSet: writes(1).dstBinding = 1
    writes(1).descriptorCount = 1: writes(1).descriptorType = VK_DESCRIPTOR_TYPE_STORAGE_BUFFER: writes(1).pBufferInfo = VarPtr(colInfo)
    writes(2).sType = VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET: writes(2).dstSet = vkDescriptorSet: writes(2).dstBinding = 2
    writes(2).descriptorCount = 1: writes(2).descriptorType = VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER: writes(2).pBufferInfo = VarPtr(uboInfo)
    Dim argv(0 To 4) As LongLong
    argv(0) = CLngLng(vkDevice): argv(1) = 3: argv(2) = CLngLng(VarPtr(writes(0))): argv(3) = 0: argv(4) = 0
    Call InvokeRaw(p_vkUpdateDescriptorSets, 5, argv)
End Sub

Private Sub VkCreateShadersAndPipelines_()
    LogLine "VkCreateShadersAndPipelines_..."
    ' Compute shader
    Dim glslComp As String
    glslComp = "#version 450" & vbLf
    glslComp = glslComp & "layout(local_size_x = 256) in;" & vbLf
    glslComp = glslComp & "layout(std430, binding = 0) buffer Positions { vec4 pos[]; };" & vbLf
    glslComp = glslComp & "layout(std430, binding = 1) buffer Colors { vec4 col[]; };" & vbLf
    glslComp = glslComp & "layout(std140, binding = 2) uniform Params {" & vbLf
    glslComp = glslComp & "    uint max_num; float dt; float scale; float pad0;" & vbLf
    glslComp = glslComp & "    float A1; float f1; float p1; float d1;" & vbLf
    glslComp = glslComp & "    float A2; float f2; float p2; float d2;" & vbLf
    glslComp = glslComp & "    float A3; float f3; float p3; float d3;" & vbLf
    glslComp = glslComp & "    float A4; float f4; float p4; float d4;" & vbLf
    glslComp = glslComp & "} u;" & vbLf
    glslComp = glslComp & "vec3 hsv2rgb(float h, float s, float v) {" & vbLf
    glslComp = glslComp & "    float c = v * s; float hp = h / 60.0; float x = c * (1.0 - abs(mod(hp, 2.0) - 1.0));" & vbLf
    glslComp = glslComp & "    vec3 rgb; if (hp < 1.0) rgb = vec3(c, x, 0.0); else if (hp < 2.0) rgb = vec3(x, c, 0.0);" & vbLf
    glslComp = glslComp & "    else if (hp < 3.0) rgb = vec3(0.0, c, x); else if (hp < 4.0) rgb = vec3(0.0, x, c);" & vbLf
    glslComp = glslComp & "    else if (hp < 5.0) rgb = vec3(x, 0.0, c); else rgb = vec3(c, 0.0, x);" & vbLf
    glslComp = glslComp & "    return rgb + vec3(v - c); }" & vbLf
    glslComp = glslComp & "void main() {" & vbLf
    glslComp = glslComp & "    uint idx = gl_GlobalInvocationID.x; if (idx >= u.max_num) return;" & vbLf
    glslComp = glslComp & "    float t = float(idx) * u.dt; float PI = 3.141592653589793;" & vbLf
    glslComp = glslComp & "    float x = u.A1 * sin(u.f1 * t + PI * u.p1) * exp(-u.d1 * t) + u.A2 * sin(u.f2 * t + PI * u.p2) * exp(-u.d2 * t);" & vbLf
    glslComp = glslComp & "    float y = u.A3 * sin(u.f3 * t + PI * u.p3) * exp(-u.d3 * t) + u.A4 * sin(u.f4 * t + PI * u.p4) * exp(-u.d4 * t);" & vbLf
    glslComp = glslComp & "    pos[idx] = vec4(x * u.scale, y * u.scale, 0.0, 1.0);" & vbLf
    glslComp = glslComp & "    col[idx] = vec4(hsv2rgb(mod((t / 20.0) * 360.0, 360.0), 1.0, 1.0), 1.0); }" & vbLf
    ' Vertex shader
    Dim glslVert As String
    glslVert = "#version 450" & vbLf
    glslVert = glslVert & "layout(std430, binding = 0) buffer Positions { vec4 pos[]; };" & vbLf
    glslVert = glslVert & "layout(std430, binding = 1) buffer Colors { vec4 col[]; };" & vbLf
    glslVert = glslVert & "layout(location = 0) out vec4 vColor;" & vbLf
    glslVert = glslVert & "void main() { uint idx = uint(gl_VertexIndex); gl_Position = pos[idx]; vColor = col[idx]; }" & vbLf
    ' Fragment shader
    Dim glslFrag As String
    glslFrag = "#version 450" & vbLf
    glslFrag = glslFrag & "layout(location = 0) in vec4 vColor;" & vbLf
    glslFrag = glslFrag & "layout(location = 0) out vec4 outColor;" & vbLf
    glslFrag = glslFrag & "void main() { outColor = vColor; }" & vbLf
    ' Compile shaders
    Dim spvComp() As Byte: spvComp = ShadercCompileSpv(glslComp, SHADERC_SHADER_KIND_COMPUTE, "hello.comp")
    Dim spvVert() As Byte: spvVert = ShadercCompileSpv(glslVert, SHADERC_SHADER_KIND_VERTEX, "hello.vert")
    Dim spvFrag() As Byte: spvFrag = ShadercCompileSpv(glslFrag, SHADERC_SHADER_KIND_FRAGMENT, "hello.frag")
    ' Create shader modules
    Dim smci As VkShaderModuleCreateInfo, argv(0 To 3) As LongLong, res As Long
    smci.sType = VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO
    smci.codeSize = UBound(spvComp) + 1: smci.pCode = VarPtr(spvComp(0))
    argv(0) = CLngLng(vkDevice): argv(1) = CLngLng(VarPtr(smci)): argv(2) = 0: argv(3) = CLngLng(VarPtr(shaderCompModule))
    VkCheck InvokeI32(p_vkCreateShaderModule, 4, argv), "vkCreateShaderModule(comp)"
    smci.codeSize = UBound(spvVert) + 1: smci.pCode = VarPtr(spvVert(0))
    argv(3) = CLngLng(VarPtr(shaderVertModule))
    VkCheck InvokeI32(p_vkCreateShaderModule, 4, argv), "vkCreateShaderModule(vert)"
    smci.codeSize = UBound(spvFrag) + 1: smci.pCode = VarPtr(spvFrag(0))
    argv(3) = CLngLng(VarPtr(shaderFragModule))
    VkCheck InvokeI32(p_vkCreateShaderModule, 4, argv), "vkCreateShaderModule(frag)"
    Dim pMain As LongPtr: pMain = AllocAnsiZ("main")
    ' Create compute pipeline
    LogLine "Creating compute pipeline..."
    Dim compLayoutInfo As VkPipelineLayoutCreateInfo
    compLayoutInfo.sType = VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO: compLayoutInfo.setLayoutCount = 1: compLayoutInfo.pSetLayouts = VarPtr(vkDescriptorSetLayout)
    argv(1) = CLngLng(VarPtr(compLayoutInfo)): argv(3) = CLngLng(VarPtr(vkComputePipelineLayout))
    VkCheck InvokeI32(p_vkCreatePipelineLayout, 4, argv), "vkCreatePipelineLayout(compute)"
    Dim compPipelineInfo As VkComputePipelineCreateInfo
    compPipelineInfo.sType = VK_STRUCTURE_TYPE_COMPUTE_PIPELINE_CREATE_INFO
    compPipelineInfo.stage.sType = VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO
    compPipelineInfo.stage.stage = VK_SHADER_STAGE_COMPUTE_BIT: compPipelineInfo.stage.module = shaderCompModule: compPipelineInfo.stage.pName = pMain
    compPipelineInfo.layout = vkComputePipelineLayout: compPipelineInfo.basePipelineIndex = -1
    Dim argvP(0 To 5) As LongLong
    argvP(0) = CLngLng(vkDevice): argvP(1) = 0: argvP(2) = 1: argvP(3) = CLngLng(VarPtr(compPipelineInfo)): argvP(4) = 0: argvP(5) = CLngLng(VarPtr(vkComputePipeline))
    VkCheck InvokeI32(p_vkCreateComputePipelines, 6, argvP), "vkCreateComputePipelines"
    ' Create graphics pipeline
    LogLine "Creating graphics pipeline..."
    Dim gfxLayoutInfo As VkPipelineLayoutCreateInfo
    gfxLayoutInfo.sType = VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO: gfxLayoutInfo.setLayoutCount = 1: gfxLayoutInfo.pSetLayouts = VarPtr(vkDescriptorSetLayout)
    argv(1) = CLngLng(VarPtr(gfxLayoutInfo)): argv(3) = CLngLng(VarPtr(vkGraphicsPipelineLayout))
    VkCheck InvokeI32(p_vkCreatePipelineLayout, 4, argv), "vkCreatePipelineLayout(graphics)"
    Dim stages(0 To 1) As VkPipelineShaderStageCreateInfo
    stages(0).sType = VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO: stages(0).stage = VK_SHADER_STAGE_VERTEX_BIT: stages(0).module = shaderVertModule: stages(0).pName = pMain
    stages(1).sType = VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO: stages(1).stage = VK_SHADER_STAGE_FRAGMENT_BIT: stages(1).module = shaderFragModule: stages(1).pName = pMain
    Dim vi As VkPipelineVertexInputStateCreateInfo: vi.sType = VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO
    Dim ia As VkPipelineInputAssemblyStateCreateInfo: ia.sType = VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO: ia.topology = VK_PRIMITIVE_TOPOLOGY_LINE_STRIP
    Dim dynStates(0 To 1) As Long: dynStates(0) = VK_DYNAMIC_STATE_VIEWPORT: dynStates(1) = VK_DYNAMIC_STATE_SCISSOR
    Dim dynState As VkPipelineDynamicStateCreateInfo: dynState.sType = VK_STRUCTURE_TYPE_PIPELINE_DYNAMIC_STATE_CREATE_INFO: dynState.dynamicStateCount = 2: dynState.pDynamicStates = VarPtr(dynStates(0))
    Dim vp As VkPipelineViewportStateCreateInfo: vp.sType = VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO: vp.viewportCount = 1: vp.scissorCount = 1
    Dim rs As VkPipelineRasterizationStateCreateInfo: rs.sType = VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO: rs.polygonMode = VK_POLYGON_MODE_FILL: rs.cullMode = VK_CULL_MODE_NONE: rs.frontFace = VK_FRONT_FACE_COUNTER_CLOCKWISE: rs.lineWidth = 1!
    Dim ms As VkPipelineMultisampleStateCreateInfo: ms.sType = VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO: ms.rasterizationSamples = VK_SAMPLE_COUNT_1_BIT
    Dim cba As VkPipelineColorBlendAttachmentState: cba.colorWriteMask = &HF
    Dim cb As VkPipelineColorBlendStateCreateInfo: cb.sType = VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO: cb.attachmentCount = 1: cb.pAttachments = VarPtr(cba)
    Dim gpci As VkGraphicsPipelineCreateInfo
    gpci.sType = VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO: gpci.stageCount = 2: gpci.pStages = VarPtr(stages(0))
    gpci.pVertexInputState = VarPtr(vi): gpci.pInputAssemblyState = VarPtr(ia): gpci.pViewportState = VarPtr(vp)
    gpci.pRasterizationState = VarPtr(rs): gpci.pMultisampleState = VarPtr(ms): gpci.pColorBlendState = VarPtr(cb)
    gpci.pDynamicState = VarPtr(dynState): gpci.layout = vkGraphicsPipelineLayout: gpci.renderPass = vkRenderPass: gpci.basePipelineIndex = -1
    argvP(3) = CLngLng(VarPtr(gpci)): argvP(5) = CLngLng(VarPtr(vkGraphicsPipeline))
    VkCheck InvokeI32(p_vkCreateGraphicsPipelines, 6, argvP), "vkCreateGraphicsPipelines"
End Sub

Private Sub VkCreateCommandPoolAndBuffers_()
    LogLine "VkCreateCommandPoolAndBuffers_..."
    Dim cpci As VkCommandPoolCreateInfo
    cpci.sType = VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO: cpci.flags = VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT: cpci.queueFamilyIndex = qFamilyGraphics
    Dim argv(0 To 3) As LongLong
    argv(0) = CLngLng(vkDevice): argv(1) = CLngLng(VarPtr(cpci)): argv(2) = 0: argv(3) = CLngLng(VarPtr(vkCommandPool))
    VkCheck InvokeI32(p_vkCreateCommandPool, 4, argv), "vkCreateCommandPool"
    ReDim vkCmdBuffers(0 To swapImageCount - 1) As LongLong
    Dim ai As VkCommandBufferAllocateInfo
    ai.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO: ai.commandPool = vkCommandPool: ai.commandBufferCount = 1
    Dim i As Long
    For i = 0 To swapImageCount - 1
        Dim one As LongPtr, argvA(0 To 2) As LongLong
        argvA(0) = CLngLng(vkDevice): argvA(1) = CLngLng(VarPtr(ai)): argvA(2) = CLngLng(VarPtr(one))
        VkCheck InvokeI32(p_vkAllocateCommandBuffers, 3, argvA), "vkAllocateCommandBuffers"
        vkCmdBuffers(i) = one
    Next
End Sub

Private Sub VkCreateSyncObjects_()
    LogLine "VkCreateSyncObjects_..."
    Dim sci As VkSemaphoreCreateInfo: sci.sType = VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO
    Dim argv(0 To 3) As LongLong
    argv(0) = CLngLng(vkDevice): argv(1) = CLngLng(VarPtr(sci)): argv(2) = 0
    argv(3) = CLngLng(VarPtr(semImageAvailable)): VkCheck InvokeI32(p_vkCreateSemaphore, 4, argv), "vkCreateSemaphore"
    argv(3) = CLngLng(VarPtr(semRenderFinished)): VkCheck InvokeI32(p_vkCreateSemaphore, 4, argv), "vkCreateSemaphore"
    Dim fci As VkFenceCreateInfo: fci.sType = VK_STRUCTURE_TYPE_FENCE_CREATE_INFO: fci.flags = VK_FENCE_CREATE_SIGNALED_BIT
    argv(1) = CLngLng(VarPtr(fci)): argv(3) = CLngLng(VarPtr(fenceInFlight))
    VkCheck InvokeI32(p_vkCreateFence, 4, argv), "vkCreateFence"
End Sub

Private Sub InitUBO()
    uboParams.max_num = VERTEX_COUNT: uboParams.dt = 0.0001!: uboParams.scale_ = 0.5!
    uboParams.A1 = 1!: uboParams.f1 = 2.01!: uboParams.p1 = 0!: uboParams.d1 = 0.002!
    uboParams.A2 = 1!: uboParams.f2 = 3!: uboParams.p2 = 0!: uboParams.d2 = 0.0065!
    uboParams.A3 = 1!: uboParams.f3 = 3.01!: uboParams.p3 = 1.5!: uboParams.d3 = 0.003!
    uboParams.A4 = 1!: uboParams.f4 = 2!: uboParams.p4 = 0!: uboParams.d4 = 0.0085!
End Sub

Private Sub UpdateUBO()
    uboParams.p1 = uboParams.p1 + 0.002!
    Dim pData As LongPtr, argv(0 To 5) As LongLong
    argv(0) = CLngLng(vkDevice): argv(1) = CLngLng(uboMemory): argv(2) = 0: argv(3) = CLngLng(LenB(uboParams)): argv(4) = 0: argv(5) = CLngLng(VarPtr(pData))
    If InvokeI32(p_vkMapMemory, 6, argv) = VK_SUCCESS Then
        RtlMoveMemory pData, VarPtr(uboParams), LenB(uboParams)
        Dim argv1(0 To 1) As LongLong: argv1(0) = CLngLng(vkDevice): argv1(1) = CLngLng(uboMemory)
        Call InvokeRaw(p_vkUnmapMemory, 2, argv1)
    End If
End Sub

Private Sub RecordCommandBuffer(ByVal imageIndex As Long)
    Dim cmd As LongPtr: cmd = vkCmdBuffers(imageIndex)
    Dim argv2(0 To 1) As LongLong: argv2(0) = CLngLng(cmd): argv2(1) = 0
    Call InvokeRaw(p_vkResetCommandBuffer, 2, argv2)
    Dim bi As VkCommandBufferBeginInfo: bi.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO
    Dim argvB(0 To 1) As LongLong: argvB(0) = CLngLng(cmd): argvB(1) = CLngLng(VarPtr(bi))
    Call InvokeRaw(p_vkBeginCommandBuffer, 2, argvB)
    ' Compute
    Dim argvBP(0 To 2) As LongLong: argvBP(0) = CLngLng(cmd): argvBP(1) = CLngLng(VK_PIPELINE_BIND_POINT_COMPUTE): argvBP(2) = CLngLng(vkComputePipeline)
    Call InvokeRaw(p_vkCmdBindPipeline, 3, argvBP)
    Dim argvDS(0 To 7) As LongLong: argvDS(0) = CLngLng(cmd): argvDS(1) = CLngLng(VK_PIPELINE_BIND_POINT_COMPUTE): argvDS(2) = CLngLng(vkComputePipelineLayout): argvDS(3) = 0: argvDS(4) = 1: argvDS(5) = CLngLng(VarPtr(vkDescriptorSet)): argvDS(6) = 0: argvDS(7) = 0
    Call InvokeRaw(p_vkCmdBindDescriptorSets, 8, argvDS)
    Dim groupCount As Long: groupCount = (VERTEX_COUNT + 255) \ 256
    Dim argvD(0 To 3) As LongLong: argvD(0) = CLngLng(cmd): argvD(1) = CLngLng(groupCount): argvD(2) = 1: argvD(3) = 1
    Call InvokeRaw(p_vkCmdDispatch, 4, argvD)
    ' Barrier
    Dim barriers(0 To 1) As VkBufferMemoryBarrier
    barriers(0).sType = VK_STRUCTURE_TYPE_BUFFER_MEMORY_BARRIER: barriers(0).srcAccessMask = VK_ACCESS_SHADER_WRITE_BIT: barriers(0).dstAccessMask = VK_ACCESS_SHADER_READ_BIT
    barriers(0).srcQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED: barriers(0).dstQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED: barriers(0).buffer = posBuffer: barriers(0).size = CLngLng(VERTEX_COUNT) * 16
    barriers(1).sType = VK_STRUCTURE_TYPE_BUFFER_MEMORY_BARRIER: barriers(1).srcAccessMask = VK_ACCESS_SHADER_WRITE_BIT: barriers(1).dstAccessMask = VK_ACCESS_SHADER_READ_BIT
    barriers(1).srcQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED: barriers(1).dstQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED: barriers(1).buffer = colBuffer: barriers(1).size = CLngLng(VERTEX_COUNT) * 16
    Dim argvBar(0 To 9) As LongLong: argvBar(0) = CLngLng(cmd): argvBar(1) = CLngLng(VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT): argvBar(2) = CLngLng(VK_PIPELINE_STAGE_VERTEX_SHADER_BIT): argvBar(3) = 0: argvBar(4) = 0: argvBar(5) = 0: argvBar(6) = 2: argvBar(7) = CLngLng(VarPtr(barriers(0))): argvBar(8) = 0: argvBar(9) = 0
    Call InvokeRaw(p_vkCmdPipelineBarrier, 10, argvBar)
    ' Begin render pass
    Dim clear As VkClearValue: clear.color.float32_3 = 1!
    Dim rpbi As VkRenderPassBeginInfo: rpbi.sType = VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO: rpbi.renderPass = vkRenderPass
    rpbi.framebuffer = swapFramebuffers(imageIndex): rpbi.renderArea.extent = swapExtent: rpbi.clearValueCount = 1: rpbi.pClearValues = VarPtr(clear)
    Dim argvR(0 To 2) As LongLong: argvR(0) = CLngLng(cmd): argvR(1) = CLngLng(VarPtr(rpbi)): argvR(2) = CLngLng(VK_SUBPASS_CONTENTS_INLINE)
    Call InvokeRaw(p_vkCmdBeginRenderPass, 3, argvR)
    ' Graphics
    argvBP(1) = CLngLng(VK_PIPELINE_BIND_POINT_GRAPHICS): argvBP(2) = CLngLng(vkGraphicsPipeline)
    Call InvokeRaw(p_vkCmdBindPipeline, 3, argvBP)
    argvDS(1) = CLngLng(VK_PIPELINE_BIND_POINT_GRAPHICS): argvDS(2) = CLngLng(vkGraphicsPipelineLayout)
    Call InvokeRaw(p_vkCmdBindDescriptorSets, 8, argvDS)
    ' Viewport
    Dim viewport As VkViewport: viewport.width = CSng(swapExtent.width): viewport.height = CSng(swapExtent.height): viewport.maxDepth = 1!
    Dim argvVP(0 To 3) As LongLong: argvVP(0) = CLngLng(cmd): argvVP(1) = 0: argvVP(2) = 1: argvVP(3) = CLngLng(VarPtr(viewport))
    Call InvokeRaw(p_vkCmdSetViewport, 4, argvVP)
    ' Scissor
    Dim scissor As VkRect2D: scissor.extent = swapExtent
    Dim argvSC(0 To 3) As LongLong: argvSC(0) = CLngLng(cmd): argvSC(1) = 0: argvSC(2) = 1: argvSC(3) = CLngLng(VarPtr(scissor))
    Call InvokeRaw(p_vkCmdSetScissor, 4, argvSC)
    ' Draw
    Dim argvDraw(0 To 4) As LongLong: argvDraw(0) = CLngLng(cmd): argvDraw(1) = CLngLng(VERTEX_COUNT): argvDraw(2) = 1: argvDraw(3) = 0: argvDraw(4) = 0
    Call InvokeRaw(p_vkCmdDraw, 5, argvDraw)
    ' End
    Dim argvE(0 To 0) As LongLong: argvE(0) = CLngLng(cmd)
    Call InvokeRaw(p_vkCmdEndRenderPass, 1, argvE)
    Call InvokeRaw(p_vkEndCommandBuffer, 1, argvE)
End Sub

Private Sub DrawFrame()
    Dim argvW(0 To 4) As LongLong: argvW(0) = CLngLng(vkDevice): argvW(1) = 1: argvW(2) = CLngLng(VarPtr(fenceInFlight)): argvW(3) = CLngLng(VK_TRUE): argvW(4) = CLngLng("9223372036854775807")
    Call InvokeRaw(p_vkWaitForFences, 5, argvW)
    Dim argvRF(0 To 2) As LongLong: argvRF(0) = CLngLng(vkDevice): argvRF(1) = 1: argvRF(2) = CLngLng(VarPtr(fenceInFlight))
    Call InvokeRaw(p_vkResetFences, 3, argvRF)
    Dim imageIndex As Long, argvA(0 To 5) As LongLong
    argvA(0) = CLngLng(vkDevice): argvA(1) = CLngLng(vkSwapchain): argvA(2) = CLngLng("9223372036854775807"): argvA(3) = CLngLng(semImageAvailable): argvA(4) = 0: argvA(5) = CLngLng(VarPtr(imageIndex))
    Dim res As Long: res = InvokeI32(p_vkAcquireNextImageKHR, 6, argvA)
    If res = VK_ERROR_OUT_OF_DATE_KHR Then g_quit = True: Exit Sub
    UpdateUBO
    RecordCommandBuffer imageIndex
    Dim waitStage As Long: waitStage = VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT
    Dim submit As VkSubmitInfo: submit.sType = VK_STRUCTURE_TYPE_SUBMIT_INFO: submit.waitSemaphoreCount = 1: submit.pWaitSemaphores = VarPtr(semImageAvailable)
    submit.pWaitDstStageMask = VarPtr(waitStage): submit.commandBufferCount = 1: submit.pCommandBuffers = VarPtr(vkCmdBuffers(imageIndex)): submit.signalSemaphoreCount = 1: submit.pSignalSemaphores = VarPtr(semRenderFinished)
    Dim argvS(0 To 3) As LongLong: argvS(0) = CLngLng(vkQueueGraphics): argvS(1) = 1: argvS(2) = CLngLng(VarPtr(submit)): argvS(3) = CLngLng(fenceInFlight)
    Call InvokeRaw(p_vkQueueSubmit, 4, argvS)
    Dim present As VkPresentInfoKHR: present.sType = VK_STRUCTURE_TYPE_PRESENT_INFO_KHR: present.waitSemaphoreCount = 1: present.pWaitSemaphores = VarPtr(semRenderFinished)
    present.swapchainCount = 1: present.pSwapchains = VarPtr(vkSwapchain): present.pImageIndices = VarPtr(imageIndex)
    Dim argvP(0 To 1) As LongLong: argvP(0) = CLngLng(vkQueueGraphics): argvP(1) = CLngLng(VarPtr(present))
    res = InvokeI32(p_vkQueuePresentKHR, 2, argvP)
    If res = VK_ERROR_OUT_OF_DATE_KHR Or res = VK_SUBOPTIMAL_KHR Then g_quit = True
End Sub

Private Sub VulkanInitAll()
    LoadVulkanLoader
    LoadShaderc
    VkCreateInstance_
    VkCreateSurface_
    PickPhysicalDeviceAndQueues_
    VkCreateDevice_
    VkCreateSwapchainAndViews_
    VkCreateRenderPass_
    VkCreateFramebuffers_
    VkCreateBuffers_
    VkCreateDescriptorSetLayout_
    VkCreateDescriptorPool_
    VkAllocateDescriptorSets_
    VkUpdateDescriptorSets_
    VkCreateShadersAndPipelines_
    VkCreateCommandPoolAndBuffers_
    VkCreateSyncObjects_
    InitUBO
    LogLine "VulkanInitAll DONE"
End Sub

Private Sub VulkanCleanupAll()
    On Error Resume Next
    LogLine "Cleanup begin"

    ' ----------------------------
    ' Device wait idle
    ' ----------------------------
    If vkDevice <> 0 And p_vkDeviceWaitIdle <> 0 Then
        Dim argvWait(0 To 0) As LongLong
        argvWait(0) = CLngLng(vkDevice)
        Call InvokeRaw(p_vkDeviceWaitIdle, 1, argvWait)
    End If

    Dim i As Long

    ' ----------------------------
    ' Destroy fence / semaphores / command pool
    ' ----------------------------
    If vkDevice <> 0 Then
        If fenceInFlight <> 0 And p_vkDestroyFence <> 0 Then
            Dim argvD3(0 To 2) As LongLong
            argvD3(0) = CLngLng(vkDevice)
            argvD3(1) = CLngLng(fenceInFlight)
            argvD3(2) = 0
            Call InvokeRaw(p_vkDestroyFence, 3, argvD3)
            fenceInFlight = 0
        End If

        If semRenderFinished <> 0 And p_vkDestroySemaphore <> 0 Then
            Dim argvD3s1(0 To 2) As LongLong
            argvD3s1(0) = CLngLng(vkDevice)
            argvD3s1(1) = CLngLng(semRenderFinished)
            argvD3s1(2) = 0
            Call InvokeRaw(p_vkDestroySemaphore, 3, argvD3s1)
            semRenderFinished = 0
        End If

        If semImageAvailable <> 0 And p_vkDestroySemaphore <> 0 Then
            Dim argvD3s2(0 To 2) As LongLong
            argvD3s2(0) = CLngLng(vkDevice)
            argvD3s2(1) = CLngLng(semImageAvailable)
            argvD3s2(2) = 0
            Call InvokeRaw(p_vkDestroySemaphore, 3, argvD3s2)
            semImageAvailable = 0
        End If

        If vkCommandPool <> 0 And p_vkDestroyCommandPool <> 0 Then
            Dim argvD3cp(0 To 2) As LongLong
            argvD3cp(0) = CLngLng(vkDevice)
            argvD3cp(1) = CLngLng(vkCommandPool)
            argvD3cp(2) = 0
            Call InvokeRaw(p_vkDestroyCommandPool, 3, argvD3cp)
            vkCommandPool = 0
        End If
    End If

    ' ----------------------------
    ' Framebuffers
    ' ----------------------------
    If vkDevice <> 0 And p_vkDestroyFramebuffer <> 0 Then
        If (Not Not swapFramebuffers) <> 0 Then
            For i = 0 To UBound(swapFramebuffers)
                If swapFramebuffers(i) <> 0 Then
                    Dim argvFB(0 To 2) As LongLong
                    argvFB(0) = CLngLng(vkDevice)
                    argvFB(1) = CLngLng(swapFramebuffers(i))
                    argvFB(2) = 0
                    Call InvokeRaw(p_vkDestroyFramebuffer, 3, argvFB)
                    swapFramebuffers(i) = 0
                End If
            Next i
        End If
    End If

    ' ----------------------------
    ' Pipelines / layouts
    ' ----------------------------
    If vkDevice <> 0 Then
        If vkGraphicsPipeline <> 0 And p_vkDestroyPipeline <> 0 Then
            Dim argvP1(0 To 2) As LongLong
            argvP1(0) = CLngLng(vkDevice)
            argvP1(1) = CLngLng(vkGraphicsPipeline)
            argvP1(2) = 0
            Call InvokeRaw(p_vkDestroyPipeline, 3, argvP1)
            vkGraphicsPipeline = 0
        End If

        If vkComputePipeline <> 0 And p_vkDestroyPipeline <> 0 Then
            Dim argvP2(0 To 2) As LongLong
            argvP2(0) = CLngLng(vkDevice)
            argvP2(1) = CLngLng(vkComputePipeline)
            argvP2(2) = 0
            Call InvokeRaw(p_vkDestroyPipeline, 3, argvP2)
            vkComputePipeline = 0
        End If

        If vkGraphicsPipelineLayout <> 0 And p_vkDestroyPipelineLayout <> 0 Then
            Dim argvPL1(0 To 2) As LongLong
            argvPL1(0) = CLngLng(vkDevice)
            argvPL1(1) = CLngLng(vkGraphicsPipelineLayout)
            argvPL1(2) = 0
            Call InvokeRaw(p_vkDestroyPipelineLayout, 3, argvPL1)
            vkGraphicsPipelineLayout = 0
        End If

        If vkComputePipelineLayout <> 0 And p_vkDestroyPipelineLayout <> 0 Then
            Dim argvPL2(0 To 2) As LongLong
            argvPL2(0) = CLngLng(vkDevice)
            argvPL2(1) = CLngLng(vkComputePipelineLayout)
            argvPL2(2) = 0
            Call InvokeRaw(p_vkDestroyPipelineLayout, 3, argvPL2)
            vkComputePipelineLayout = 0
        End If
    End If

    ' ----------------------------
    ' Shader modules
    ' ----------------------------
    If vkDevice <> 0 And p_vkDestroyShaderModule <> 0 Then
        If shaderVertModule <> 0 Then
            Dim argvSM1(0 To 2) As LongLong
            argvSM1(0) = CLngLng(vkDevice)
            argvSM1(1) = CLngLng(shaderVertModule)
            argvSM1(2) = 0
            Call InvokeRaw(p_vkDestroyShaderModule, 3, argvSM1)
            shaderVertModule = 0
        End If

        If shaderFragModule <> 0 Then
            Dim argvSM2(0 To 2) As LongLong
            argvSM2(0) = CLngLng(vkDevice)
            argvSM2(1) = CLngLng(shaderFragModule)
            argvSM2(2) = 0
            Call InvokeRaw(p_vkDestroyShaderModule, 3, argvSM2)
            shaderFragModule = 0
        End If

        If shaderCompModule <> 0 Then
            Dim argvSM3(0 To 2) As LongLong
            argvSM3(0) = CLngLng(vkDevice)
            argvSM3(1) = CLngLng(shaderCompModule)
            argvSM3(2) = 0
            Call InvokeRaw(p_vkDestroyShaderModule, 3, argvSM3)
            shaderCompModule = 0
        End If
    End If

    ' ----------------------------
    ' Descriptor pool / set layout
    ' ----------------------------
    If vkDevice <> 0 Then
        If vkDescriptorPool <> 0 And p_vkDestroyDescriptorPool <> 0 Then
            Dim argvDP(0 To 2) As LongLong
            argvDP(0) = CLngLng(vkDevice)
            argvDP(1) = CLngLng(vkDescriptorPool)
            argvDP(2) = 0
            Call InvokeRaw(p_vkDestroyDescriptorPool, 3, argvDP)
            vkDescriptorPool = 0
        End If

        If vkDescriptorSetLayout <> 0 And p_vkDestroyDescriptorSetLayout <> 0 Then
            Dim argvDSL(0 To 2) As LongLong
            argvDSL(0) = CLngLng(vkDevice)
            argvDSL(1) = CLngLng(vkDescriptorSetLayout)
            argvDSL(2) = 0
            Call InvokeRaw(p_vkDestroyDescriptorSetLayout, 3, argvDSL)
            vkDescriptorSetLayout = 0
        End If
    End If

    ' ----------------------------
    ' Buffers / memory
    ' ----------------------------
    If vkDevice <> 0 Then
        If posBuffer <> 0 And p_vkDestroyBuffer <> 0 Then
            Dim argvB1(0 To 2) As LongLong
            argvB1(0) = CLngLng(vkDevice)
            argvB1(1) = CLngLng(posBuffer)
            argvB1(2) = 0
            Call InvokeRaw(p_vkDestroyBuffer, 3, argvB1)
            posBuffer = 0
        End If
        If posMemory <> 0 And p_vkFreeMemory <> 0 Then
            Dim argvM1(0 To 2) As LongLong
            argvM1(0) = CLngLng(vkDevice)
            argvM1(1) = CLngLng(posMemory)
            argvM1(2) = 0
            Call InvokeRaw(p_vkFreeMemory, 3, argvM1)
            posMemory = 0
        End If

        If colBuffer <> 0 And p_vkDestroyBuffer <> 0 Then
            Dim argvB2(0 To 2) As LongLong
            argvB2(0) = CLngLng(vkDevice)
            argvB2(1) = CLngLng(colBuffer)
            argvB2(2) = 0
            Call InvokeRaw(p_vkDestroyBuffer, 3, argvB2)
            colBuffer = 0
        End If
        If colMemory <> 0 And p_vkFreeMemory <> 0 Then
            Dim argvM2(0 To 2) As LongLong
            argvM2(0) = CLngLng(vkDevice)
            argvM2(1) = CLngLng(colMemory)
            argvM2(2) = 0
            Call InvokeRaw(p_vkFreeMemory, 3, argvM2)
            colMemory = 0
        End If

        If uboBuffer <> 0 And p_vkDestroyBuffer <> 0 Then
            Dim argvB3(0 To 2) As LongLong
            argvB3(0) = CLngLng(vkDevice)
            argvB3(1) = CLngLng(uboBuffer)
            argvB3(2) = 0
            Call InvokeRaw(p_vkDestroyBuffer, 3, argvB3)
            uboBuffer = 0
        End If
        If uboMemory <> 0 And p_vkFreeMemory <> 0 Then
            Dim argvM3(0 To 2) As LongLong
            argvM3(0) = CLngLng(vkDevice)
            argvM3(1) = CLngLng(uboMemory)
            argvM3(2) = 0
            Call InvokeRaw(p_vkFreeMemory, 3, argvM3)
            uboMemory = 0
        End If
    End If

    ' ----------------------------
    ' Render pass
    ' ----------------------------
    If vkDevice <> 0 And vkRenderPass <> 0 And p_vkDestroyRenderPass <> 0 Then
        Dim argvRP(0 To 2) As LongLong
        argvRP(0) = CLngLng(vkDevice)
        argvRP(1) = CLngLng(vkRenderPass)
        argvRP(2) = 0
        Call InvokeRaw(p_vkDestroyRenderPass, 3, argvRP)
        vkRenderPass = 0
    End If

    ' ----------------------------
    ' Image views
    ' ----------------------------
    If vkDevice <> 0 And p_vkDestroyImageView <> 0 Then
        If (Not Not swapImageViews) <> 0 Then
            For i = 0 To UBound(swapImageViews)
                If swapImageViews(i) <> 0 Then
                    Dim argvIV(0 To 2) As LongLong
                    argvIV(0) = CLngLng(vkDevice)
                    argvIV(1) = CLngLng(swapImageViews(i))
                    argvIV(2) = 0
                    Call InvokeRaw(p_vkDestroyImageView, 3, argvIV)
                    swapImageViews(i) = 0
                End If
            Next i
        End If
    End If

    ' ----------------------------
    ' Swapchain
    ' ----------------------------
    If vkDevice <> 0 And vkSwapchain <> 0 And p_vkDestroySwapchainKHR <> 0 Then
        Dim argvSC(0 To 2) As LongLong
        argvSC(0) = CLngLng(vkDevice)
        argvSC(1) = CLngLng(vkSwapchain)
        argvSC(2) = 0
        Call InvokeRaw(p_vkDestroySwapchainKHR, 3, argvSC)
        vkSwapchain = 0
    End If

    ' ----------------------------
    ' Device
    ' ----------------------------
    If vkDevice <> 0 And p_vkDestroyDevice <> 0 Then
        Dim argvDev(0 To 1) As LongLong
        argvDev(0) = CLngLng(vkDevice)
        argvDev(1) = 0
        Call InvokeRaw(p_vkDestroyDevice, 2, argvDev)
        vkDevice = 0
    End If

    ' ----------------------------
    ' Surface
    ' ----------------------------
    If vkSurface <> 0 And vkInstance <> 0 And p_vkDestroySurfaceKHR <> 0 Then
        Dim argvSurf(0 To 2) As LongLong
        argvSurf(0) = CLngLng(vkInstance)
        argvSurf(1) = CLngLng(vkSurface)
        argvSurf(2) = 0
        Call InvokeRaw(p_vkDestroySurfaceKHR, 3, argvSurf)
        vkSurface = 0
    End If

    ' ----------------------------
    ' Instance
    ' ----------------------------
    If vkInstance <> 0 And p_vkDestroyInstance <> 0 Then
        Dim argvInst(0 To 1) As LongLong
        argvInst(0) = CLngLng(vkInstance)
        argvInst(1) = 0
        Call InvokeRaw(p_vkDestroyInstance, 2, argvInst)
        vkInstance = 0
    End If

    FreeAllAnsi
    LogLine "Cleanup end"
End Sub


Private Sub FreeThunks()
    Dim i As Long
    On Error Resume Next
    If g_thunkCount > 0 Then
        For i = 1 To g_thunkCount
            If g_thunks(i).stubPtr <> 0 Then VirtualFree g_thunks(i).stubPtr, 0, &H8000
        Next
        Erase g_thunks: g_thunkCount = 0
    End If
End Sub

Public Sub Main()
    On Error GoTo EH
    LogInit
    QueryPerformanceFrequency g_perfFreq
    QueryPerformanceCounter g_startTime
    g_quit = False
    LogLine "CreateAppWindow..."
    CreateAppWindow 960, 720
    LogLine "VulkanInitAll..."
    VulkanInitAll
    LogLine "Enter main loop..."
    Dim m As MSG_T
    Do While Not g_quit
        If PeekMessageW(m, 0, 0, 0, PM_REMOVE) <> 0 Then
            TranslateMessage m: DispatchMessageW m
        Else
            DrawFrame
            DoEvents
        End If
    Loop
    LogLine "Cleanup..."
    VulkanCleanupAll
    If g_hwnd <> 0 Then DestroyWindow g_hwnd: g_hwnd = 0
    FreeThunks
    UnregisterClassW StrPtr("VBA_VK_HARMONOGRAPH"), g_hInst
    LogLine "END OK"
    Exit Sub
EH:
    LogLine "EXCEPTION: " & Err.Description
    On Error Resume Next
    VulkanCleanupAll
    MsgBox "ERROR: " & Err.Description & vbCrLf & "Log: " & LOG_PATH, vbExclamation
End Sub
