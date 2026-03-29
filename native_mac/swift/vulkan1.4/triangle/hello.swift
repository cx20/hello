import Foundation
import Darwin
import GLFW
import Vulkan

private let width = 800
private let height = 600
private let maxFramesInFlight = 2
private let deviceExtensions = ["VK_KHR_swapchain"]

private func vkMakeVersion(_ major: UInt32, _ minor: UInt32, _ patch: UInt32) -> UInt32 {
    (major << 22) | (minor << 12) | patch
}

private func vkMakeAPIVersion(_ variant: UInt32, _ major: UInt32, _ minor: UInt32, _ patch: UInt32) -> UInt32 {
    (variant << 29) | (major << 22) | (minor << 12) | patch
}

private struct QueueFamilyIndices {
    var graphicsFamily: UInt32?
    var presentFamily: UInt32?

    var isComplete: Bool {
        graphicsFamily != nil && presentFamily != nil
    }
}

private struct SwapChainSupportDetails {
    var capabilities = VkSurfaceCapabilitiesKHR()
    var formats: [VkSurfaceFormatKHR] = []
    var presentModes: [VkPresentModeKHR] = []
}

private enum SampleError: Error {
    case message(String)
}

private func fail(_ message: String) throws -> Never {
    throw SampleError.message(message)
}

private func cString<T>(from tuple: T) -> String {
    var mutableTuple = tuple
    let capacity = MemoryLayout<T>.size
    return withUnsafePointer(to: &mutableTuple) {
        $0.withMemoryRebound(to: CChar.self, capacity: capacity) {
            String(cString: $0)
        }
    }
}

private func withDuplicatedCStringArray<R>(_ strings: [String], _ body: (UnsafeMutablePointer<UnsafePointer<CChar>?>?, UInt32) throws -> R) rethrows -> R {
    let storage = strings.map { strdup($0) }
    defer {
        for item in storage {
            free(item)
        }
    }
    var pointers = storage.map { item in
        item.map { UnsafePointer<CChar>($0) }
    }
    return try pointers.withUnsafeMutableBufferPointer {
        try body($0.baseAddress, UInt32($0.count))
    }
}

private func withUnsafeBytes<R>(of data: Data, _ body: (UnsafeRawPointer?, Int) throws -> R) rethrows -> R {
    try data.withUnsafeBytes { buffer in
        try body(buffer.baseAddress, buffer.count)
    }
}

private func containsPathEntry(_ list: String?, _ entry: String) -> Bool {
    guard let list else {
        return false
    }
    return list.split(separator: ":").contains { $0 == Substring(entry) }
}

private func ensureLaunchEnvAndRelaunchIfNeeded() {
    let environment = ProcessInfo.processInfo.environment
    if environment["HELLO_VK_ENV_READY"] == "1" {
        return
    }

    let current = environment["DYLD_FALLBACK_LIBRARY_PATH"]
    let hasUsrLocal = containsPathEntry(current, "/usr/local/lib")
    let hasHomebrew = containsPathEntry(current, "/opt/homebrew/lib")
    if hasUsrLocal || hasHomebrew {
        setenv("HELLO_VK_ENV_READY", "1", 1)
        return
    }

    let defaults = "/usr/local/lib:/opt/homebrew/lib:/usr/lib"
    if let current, !current.isEmpty {
        setenv("DYLD_FALLBACK_LIBRARY_PATH", "\(current):\(defaults)", 1)
    } else {
        setenv("DYLD_FALLBACK_LIBRARY_PATH", defaults, 1)
    }
    setenv("HELLO_VK_ENV_READY", "1", 1)

    var argv = CommandLine.arguments.map { strdup($0) }
    defer {
        for arg in argv {
            free(arg)
        }
    }
    argv.append(nil)
    argv.withUnsafeMutableBufferPointer { buffer in
        _ = execv(buffer[0], buffer.baseAddress)
    }
    perror("execv")
    exit(EXIT_FAILURE)
}

private func ensureDyldFallbackLibraryPath() {
    let current = ProcessInfo.processInfo.environment["DYLD_FALLBACK_LIBRARY_PATH"]
    let hasUsrLocal = containsPathEntry(current, "/usr/local/lib")
    let hasHomebrew = containsPathEntry(current, "/opt/homebrew/lib")
    if hasUsrLocal && hasHomebrew {
        return
    }

    let defaults = "/usr/local/lib:/opt/homebrew/lib:/usr/lib"
    if let current, !current.isEmpty {
        setenv("DYLD_FALLBACK_LIBRARY_PATH", "\(current):\(defaults)", 1)
    } else {
        setenv("DYLD_FALLBACK_LIBRARY_PATH", defaults, 1)
    }
}

private func vkCheck(_ result: VkResult, _ message: String) throws {
    if result != VK_SUCCESS {
        throw SampleError.message(message)
    }
}

final class HelloTriangleApplication {
    private var window: OpaquePointer?
    private var instance: VkInstance?
    private var surface: VkSurfaceKHR?
    private var physicalDevice: VkPhysicalDevice?
    private var device: VkDevice?
    private var graphicsQueue: VkQueue?
    private var presentQueue: VkQueue?
    private var swapChain: VkSwapchainKHR?
    private var swapChainImages: [VkImage?] = []
    private var swapChainImageFormat = VK_FORMAT_UNDEFINED
    private var swapChainExtent = VkExtent2D()
    private var swapChainImageViews: [VkImageView?] = []
    private var swapChainFramebuffers: [VkFramebuffer?] = []
    private var renderPass: VkRenderPass?
    private var pipelineLayout: VkPipelineLayout?
    private var graphicsPipeline: VkPipeline?
    private var commandPool: VkCommandPool?
    private var commandBuffers: [VkCommandBuffer?] = []
    private var imageAvailableSemaphores: [VkSemaphore?] = Array(repeating: nil, count: maxFramesInFlight)
    private var renderFinishedSemaphores: [VkSemaphore?] = Array(repeating: nil, count: maxFramesInFlight)
    private var inFlightFences: [VkFence?] = Array(repeating: nil, count: maxFramesInFlight)
    private var imagesInFlight: [VkFence?] = []
    private var currentFrame = 0
    private var framebufferResized = false

    func run() throws {
        ensureLaunchEnvAndRelaunchIfNeeded()
        try initWindow()
        try initVulkan()
        mainLoop()
        cleanup()
    }

    private func initWindow() throws {
        ensureDyldFallbackLibraryPath()
        if glfwInit() == 0 {
            try fail("failed to initialize GLFW")
        }
        glfwWindowHint(GLFW_CLIENT_API, GLFW_NO_API)
        guard let createdWindow = glfwCreateWindow(Int32(width), Int32(height), "Hello Vulkan (Swift, MoltenVK)", nil, nil) else {
            try fail("failed to create GLFW window")
        }
        window = createdWindow
        glfwSetWindowUserPointer(createdWindow, Unmanaged.passUnretained(self).toOpaque())
        let callback: GLFWframebuffersizefun = { window, _, _ in
            guard let window, let pointer = glfwGetWindowUserPointer(window) else {
                return
            }
            let app = Unmanaged<HelloTriangleApplication>.fromOpaque(pointer).takeUnretainedValue()
            app.framebufferResized = true
        }
        glfwSetFramebufferSizeCallback(createdWindow, callback)
    }

    private func isInstanceExtensionAvailable(_ name: String) -> Bool {
        var count: UInt32 = 0
        vkEnumerateInstanceExtensionProperties(nil, &count, nil)
        var properties = Array(repeating: VkExtensionProperties(), count: Int(count))
        properties.withUnsafeMutableBufferPointer {
            _ = vkEnumerateInstanceExtensionProperties(nil, &count, $0.baseAddress)
        }
        return properties.contains { cString(from: $0.extensionName) == name }
    }

    private func requiredInstanceExtensions() throws -> [String] {
        var count: UInt32 = 0
        guard let glfwExtensions = glfwGetRequiredInstanceExtensions(&count), count > 0 else {
            try fail("GLFW Vulkan surface extensions are unavailable. Please install/build GLFW with Vulkan support.")
        }

        var names: [String] = []
        for index in 0..<Int(count) {
            if let pointer = glfwExtensions[index] {
                names.append(String(cString: pointer))
            }
        }
        if isInstanceExtensionAvailable("VK_KHR_portability_enumeration") {
            names.append("VK_KHR_portability_enumeration")
        }
        return names
    }

    private func createInstance() throws {
        var appInfo = VkApplicationInfo()
        appInfo.sType = VK_STRUCTURE_TYPE_APPLICATION_INFO
        appInfo.pApplicationName = UnsafePointer(strdup("Hello Triangle"))
        appInfo.applicationVersion = vkMakeVersion(1, 0, 0)
        appInfo.pEngineName = UnsafePointer(strdup("No Engine"))
        appInfo.engineVersion = vkMakeVersion(1, 0, 0)
        appInfo.apiVersion = vkMakeAPIVersion(0, 1, 0, 0)
        defer {
            free(UnsafeMutableRawPointer(mutating: appInfo.pApplicationName))
            free(UnsafeMutableRawPointer(mutating: appInfo.pEngineName))
        }

        var createInfo = VkInstanceCreateInfo()
        createInfo.sType = VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO
        createInfo.pApplicationInfo = withUnsafePointer(to: &appInfo) { $0 }

        let extensions = try requiredInstanceExtensions()
        try withDuplicatedCStringArray(extensions) { pointers, count in
            createInfo.enabledExtensionCount = count
            createInfo.ppEnabledExtensionNames = UnsafePointer(pointers)
            if extensions.contains("VK_KHR_portability_enumeration") {
                createInfo.flags = VkInstanceCreateFlags(VK_INSTANCE_CREATE_ENUMERATE_PORTABILITY_BIT_KHR.rawValue)
            }
            createInfo.enabledLayerCount = 0
            createInfo.ppEnabledLayerNames = nil
            try vkCheck(vkCreateInstance(&createInfo, nil, &instance), "failed to create instance")
        }
    }

    private func createSurface() throws {
        guard let instance, let window else {
            try fail("instance/window not initialized")
        }
        try vkCheck(glfwCreateWindowSurface(instance, window, nil, &surface), "failed to create window surface")
    }

    private func findQueueFamilies(_ device: VkPhysicalDevice?) -> QueueFamilyIndices {
        var indices = QueueFamilyIndices()
        var queueFamilyCount: UInt32 = 0
        vkGetPhysicalDeviceQueueFamilyProperties(device, &queueFamilyCount, nil)
        var queueFamilies = Array(repeating: VkQueueFamilyProperties(), count: Int(queueFamilyCount))
        queueFamilies.withUnsafeMutableBufferPointer {
            vkGetPhysicalDeviceQueueFamilyProperties(device, &queueFamilyCount, $0.baseAddress)
        }
        for index in 0..<queueFamilies.count {
            if (queueFamilies[index].queueFlags & VkQueueFlags(VK_QUEUE_GRAPHICS_BIT.rawValue)) != 0 {
                indices.graphicsFamily = UInt32(index)
            }
            var presentSupport: VkBool32 = VkBool32(VK_FALSE)
            vkGetPhysicalDeviceSurfaceSupportKHR(device, UInt32(index), surface, &presentSupport)
            if presentSupport == VkBool32(VK_TRUE) {
                indices.presentFamily = UInt32(index)
            }
            if indices.isComplete {
                break
            }
        }
        return indices
    }

    private func checkDeviceExtensionSupport(_ device: VkPhysicalDevice?) -> Bool {
        var count: UInt32 = 0
        vkEnumerateDeviceExtensionProperties(device, nil, &count, nil)
        var properties = Array(repeating: VkExtensionProperties(), count: Int(count))
        properties.withUnsafeMutableBufferPointer {
            _ = vkEnumerateDeviceExtensionProperties(device, nil, &count, $0.baseAddress)
        }
        let names = Set(properties.map { cString(from: $0.extensionName) })
        return deviceExtensions.allSatisfy { names.contains($0) }
    }

    private func isDeviceExtensionAvailable(_ device: VkPhysicalDevice?, _ name: String) -> Bool {
        var count: UInt32 = 0
        vkEnumerateDeviceExtensionProperties(device, nil, &count, nil)
        var properties = Array(repeating: VkExtensionProperties(), count: Int(count))
        properties.withUnsafeMutableBufferPointer {
            _ = vkEnumerateDeviceExtensionProperties(device, nil, &count, $0.baseAddress)
        }
        return properties.contains { cString(from: $0.extensionName) == name }
    }

    private func querySwapChainSupport(_ device: VkPhysicalDevice?) -> SwapChainSupportDetails {
        var details = SwapChainSupportDetails()
        vkGetPhysicalDeviceSurfaceCapabilitiesKHR(device, surface, &details.capabilities)

        var formatCount: UInt32 = 0
        vkGetPhysicalDeviceSurfaceFormatsKHR(device, surface, &formatCount, nil)
        if formatCount > 0 {
            details.formats = Array(repeating: VkSurfaceFormatKHR(), count: Int(formatCount))
            _ = details.formats.withUnsafeMutableBufferPointer {
                vkGetPhysicalDeviceSurfaceFormatsKHR(device, surface, &formatCount, $0.baseAddress)
            }
        }

        var presentModeCount: UInt32 = 0
        vkGetPhysicalDeviceSurfacePresentModesKHR(device, surface, &presentModeCount, nil)
        if presentModeCount > 0 {
            details.presentModes = Array(repeating: VK_PRESENT_MODE_FIFO_KHR, count: Int(presentModeCount))
            _ = details.presentModes.withUnsafeMutableBufferPointer {
                vkGetPhysicalDeviceSurfacePresentModesKHR(device, surface, &presentModeCount, $0.baseAddress)
            }
        }
        return details
    }

    private func isDeviceSuitable(_ device: VkPhysicalDevice?) -> Bool {
        let indices = findQueueFamilies(device)
        let extensionsSupported = checkDeviceExtensionSupport(device)
        let swapChainAdequate: Bool
        if extensionsSupported {
            let support = querySwapChainSupport(device)
            swapChainAdequate = !support.formats.isEmpty && !support.presentModes.isEmpty
        } else {
            swapChainAdequate = false
        }
        return indices.isComplete && extensionsSupported && swapChainAdequate
    }

    private func pickPhysicalDevice() throws {
        var deviceCount: UInt32 = 0
        vkEnumeratePhysicalDevices(instance, &deviceCount, nil)
        if deviceCount == 0 {
            try fail("failed to find GPUs with Vulkan support")
        }
        var devices = Array<VkPhysicalDevice?>(repeating: nil, count: Int(deviceCount))
        try devices.withUnsafeMutableBufferPointer {
            try vkCheck(vkEnumeratePhysicalDevices(instance, &deviceCount, $0.baseAddress), "failed to enumerate physical devices")
        }
        for candidate in devices where isDeviceSuitable(candidate) {
            physicalDevice = candidate
            break
        }
        if physicalDevice == nil {
            try fail("failed to find a suitable GPU")
        }
    }

    private func createLogicalDevice() throws {
        let indices = findQueueFamilies(physicalDevice)
        guard let graphicsFamily = indices.graphicsFamily, let presentFamily = indices.presentFamily else {
            try fail("missing queue families")
        }

        let uniqueFamilies = Array(Set([graphicsFamily, presentFamily]))
        var queuePriority: Float = 1.0
        var queueInfos: [VkDeviceQueueCreateInfo] = uniqueFamilies.map { family in
            var info = VkDeviceQueueCreateInfo()
            info.sType = VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO
            info.queueFamilyIndex = family
            info.queueCount = 1
            info.pQueuePriorities = withUnsafePointer(to: &queuePriority) { $0 }
            return info
        }

        var deviceFeatures = VkPhysicalDeviceFeatures()
        var extensions = deviceExtensions
        if isDeviceExtensionAvailable(physicalDevice, "VK_KHR_portability_subset") {
            extensions.append("VK_KHR_portability_subset")
        }

        var createInfo = VkDeviceCreateInfo()
        createInfo.sType = VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO
        try withDuplicatedCStringArray(extensions) { extensionPointers, extensionCount in
            try queueInfos.withUnsafeMutableBufferPointer { queueBuffer in
                createInfo.queueCreateInfoCount = UInt32(queueBuffer.count)
                createInfo.pQueueCreateInfos = UnsafePointer(queueBuffer.baseAddress)
                createInfo.pEnabledFeatures = withUnsafePointer(to: &deviceFeatures) { $0 }
                createInfo.enabledExtensionCount = extensionCount
                createInfo.ppEnabledExtensionNames = UnsafePointer(extensionPointers)
                createInfo.enabledLayerCount = 0
                try vkCheck(vkCreateDevice(physicalDevice, &createInfo, nil, &device), "failed to create logical device")
            }
        }

        vkGetDeviceQueue(device, graphicsFamily, 0, &graphicsQueue)
        vkGetDeviceQueue(device, presentFamily, 0, &presentQueue)
    }

    private func chooseSwapSurfaceFormat(_ formats: [VkSurfaceFormatKHR]) -> VkSurfaceFormatKHR {
        for format in formats where format.format == VK_FORMAT_B8G8R8A8_SRGB && format.colorSpace == VK_COLOR_SPACE_SRGB_NONLINEAR_KHR {
            return format
        }
        return formats[0]
    }

    private func chooseSwapPresentMode(_ presentModes: [VkPresentModeKHR]) -> VkPresentModeKHR {
        for mode in presentModes where mode == VK_PRESENT_MODE_MAILBOX_KHR {
            return mode
        }
        return VK_PRESENT_MODE_FIFO_KHR
    }

    private func chooseSwapExtent(_ capabilities: VkSurfaceCapabilitiesKHR) -> VkExtent2D {
        if capabilities.currentExtent.width != UInt32.max {
            return capabilities.currentExtent
        }
        var framebufferWidth: Int32 = 0
        var framebufferHeight: Int32 = 0
        glfwGetFramebufferSize(window, &framebufferWidth, &framebufferHeight)
        var actualExtent = VkExtent2D(width: UInt32(framebufferWidth), height: UInt32(framebufferHeight))
        actualExtent.width = min(capabilities.maxImageExtent.width, max(capabilities.minImageExtent.width, actualExtent.width))
        actualExtent.height = min(capabilities.maxImageExtent.height, max(capabilities.minImageExtent.height, actualExtent.height))
        return actualExtent
    }

    private func createSwapChain() throws {
        let support = querySwapChainSupport(physicalDevice)
        let surfaceFormat = chooseSwapSurfaceFormat(support.formats)
        let presentMode = chooseSwapPresentMode(support.presentModes)
        let extent = chooseSwapExtent(support.capabilities)

        var imageCount = support.capabilities.minImageCount + 1
        if support.capabilities.maxImageCount > 0 && imageCount > support.capabilities.maxImageCount {
            imageCount = support.capabilities.maxImageCount
        }

        let indices = findQueueFamilies(physicalDevice)
        var queueFamilyIndices = [indices.graphicsFamily!, indices.presentFamily!]

        var createInfo = VkSwapchainCreateInfoKHR()
        createInfo.sType = VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR
        createInfo.surface = surface
        createInfo.minImageCount = imageCount
        createInfo.imageFormat = surfaceFormat.format
        createInfo.imageColorSpace = surfaceFormat.colorSpace
        createInfo.imageExtent = extent
        createInfo.imageArrayLayers = 1
        createInfo.imageUsage = VkImageUsageFlags(VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT.rawValue)
        if indices.graphicsFamily != indices.presentFamily {
            createInfo.imageSharingMode = VK_SHARING_MODE_CONCURRENT
            createInfo.queueFamilyIndexCount = UInt32(queueFamilyIndices.count)
        } else {
            createInfo.imageSharingMode = VK_SHARING_MODE_EXCLUSIVE
            createInfo.queueFamilyIndexCount = 0
            createInfo.pQueueFamilyIndices = nil
        }
        createInfo.preTransform = support.capabilities.currentTransform
        createInfo.compositeAlpha = VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR
        createInfo.presentMode = presentMode
        createInfo.clipped = VkBool32(VK_TRUE)
        createInfo.oldSwapchain = nil

        if indices.graphicsFamily != indices.presentFamily {
            try queueFamilyIndices.withUnsafeMutableBufferPointer { queueBuffer in
                createInfo.pQueueFamilyIndices = UnsafePointer(queueBuffer.baseAddress)
                try vkCheck(vkCreateSwapchainKHR(device, &createInfo, nil, &swapChain), "failed to create swap chain")
            }
        } else {
            try vkCheck(vkCreateSwapchainKHR(device, &createInfo, nil, &swapChain), "failed to create swap chain")
        }

        try vkCheck(vkGetSwapchainImagesKHR(device, swapChain, &imageCount, nil), "failed to query swap chain images")
        swapChainImages = Array(repeating: nil, count: Int(imageCount))
        try swapChainImages.withUnsafeMutableBufferPointer {
            try vkCheck(vkGetSwapchainImagesKHR(device, swapChain, &imageCount, $0.baseAddress), "failed to fetch swap chain images")
        }

        swapChainImageFormat = surfaceFormat.format
        swapChainExtent = extent
    }

    private func createImageViews() throws {
        swapChainImageViews = Array(repeating: nil, count: swapChainImages.count)
        for index in 0..<swapChainImages.count {
            var createInfo = VkImageViewCreateInfo()
            createInfo.sType = VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO
            createInfo.image = swapChainImages[index]
            createInfo.viewType = VK_IMAGE_VIEW_TYPE_2D
            createInfo.format = swapChainImageFormat
            createInfo.components.r = VK_COMPONENT_SWIZZLE_IDENTITY
            createInfo.components.g = VK_COMPONENT_SWIZZLE_IDENTITY
            createInfo.components.b = VK_COMPONENT_SWIZZLE_IDENTITY
            createInfo.components.a = VK_COMPONENT_SWIZZLE_IDENTITY
            createInfo.subresourceRange.aspectMask = VkImageAspectFlags(VK_IMAGE_ASPECT_COLOR_BIT.rawValue)
            createInfo.subresourceRange.baseMipLevel = 0
            createInfo.subresourceRange.levelCount = 1
            createInfo.subresourceRange.baseArrayLayer = 0
            createInfo.subresourceRange.layerCount = 1
            try vkCheck(vkCreateImageView(device, &createInfo, nil, &swapChainImageViews[index]), "failed to create image view")
        }
    }

    private func createRenderPass() throws {
        var colorAttachment = VkAttachmentDescription()
        colorAttachment.format = swapChainImageFormat
        colorAttachment.samples = VK_SAMPLE_COUNT_1_BIT
        colorAttachment.loadOp = VK_ATTACHMENT_LOAD_OP_CLEAR
        colorAttachment.storeOp = VK_ATTACHMENT_STORE_OP_STORE
        colorAttachment.stencilLoadOp = VK_ATTACHMENT_LOAD_OP_DONT_CARE
        colorAttachment.stencilStoreOp = VK_ATTACHMENT_STORE_OP_DONT_CARE
        colorAttachment.initialLayout = VK_IMAGE_LAYOUT_UNDEFINED
        colorAttachment.finalLayout = VK_IMAGE_LAYOUT_PRESENT_SRC_KHR

        var colorAttachmentRef = VkAttachmentReference()
        colorAttachmentRef.attachment = 0
        colorAttachmentRef.layout = VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL

        var subpass = VkSubpassDescription()
        subpass.pipelineBindPoint = VK_PIPELINE_BIND_POINT_GRAPHICS
        subpass.colorAttachmentCount = 1
        subpass.pColorAttachments = withUnsafePointer(to: &colorAttachmentRef) { $0 }

        var dependency = VkSubpassDependency()
        dependency.srcSubpass = VK_SUBPASS_EXTERNAL
        dependency.dstSubpass = 0
        dependency.srcStageMask = VkPipelineStageFlags(VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT.rawValue)
        dependency.dstStageMask = VkPipelineStageFlags(VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT.rawValue)
        dependency.dstAccessMask = VkAccessFlags(VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT.rawValue)

        var renderPassInfo = VkRenderPassCreateInfo()
        renderPassInfo.sType = VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO
        renderPassInfo.attachmentCount = 1
        renderPassInfo.pAttachments = withUnsafePointer(to: &colorAttachment) { $0 }
        renderPassInfo.subpassCount = 1
        renderPassInfo.pSubpasses = withUnsafePointer(to: &subpass) { $0 }
        renderPassInfo.dependencyCount = 1
        renderPassInfo.pDependencies = withUnsafePointer(to: &dependency) { $0 }

        try vkCheck(vkCreateRenderPass(device, &renderPassInfo, nil, &renderPass), "failed to create render pass")
    }

    private func createShaderModule(from code: Data) throws -> VkShaderModule? {
        var createInfo = VkShaderModuleCreateInfo()
        createInfo.sType = VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO
        createInfo.codeSize = code.count
        var module: VkShaderModule?
        try withUnsafeBytes(of: code) { pointer, _ in
            createInfo.pCode = pointer?.assumingMemoryBound(to: UInt32.self)
            try vkCheck(vkCreateShaderModule(device, &createInfo, nil, &module), "failed to create shader module")
        }
        return module
    }

    private func createGraphicsPipeline() throws {
        let vertShaderCode = try Data(contentsOf: URL(fileURLWithPath: "hello_vert.spv"))
        let fragShaderCode = try Data(contentsOf: URL(fileURLWithPath: "hello_frag.spv"))
        guard let vertShaderModule = try createShaderModule(from: vertShaderCode),
              let fragShaderModule = try createShaderModule(from: fragShaderCode) else {
            try fail("failed to create shader modules")
        }
        defer {
            vkDestroyShaderModule(device, fragShaderModule, nil)
            vkDestroyShaderModule(device, vertShaderModule, nil)
        }

        let mainName = strdup("main")
        defer { free(mainName) }

        var vertShaderStageInfo = VkPipelineShaderStageCreateInfo()
        vertShaderStageInfo.sType = VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO
        vertShaderStageInfo.stage = VK_SHADER_STAGE_VERTEX_BIT
        vertShaderStageInfo.module = vertShaderModule
        vertShaderStageInfo.pName = UnsafePointer(mainName)

        var fragShaderStageInfo = VkPipelineShaderStageCreateInfo()
        fragShaderStageInfo.sType = VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO
        fragShaderStageInfo.stage = VK_SHADER_STAGE_FRAGMENT_BIT
        fragShaderStageInfo.module = fragShaderModule
        fragShaderStageInfo.pName = UnsafePointer(mainName)

        var shaderStages = [vertShaderStageInfo, fragShaderStageInfo]

        var vertexInputInfo = VkPipelineVertexInputStateCreateInfo()
        vertexInputInfo.sType = VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO

        var inputAssembly = VkPipelineInputAssemblyStateCreateInfo()
        inputAssembly.sType = VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO
        inputAssembly.topology = VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST
        inputAssembly.primitiveRestartEnable = VkBool32(VK_FALSE)

        var viewport = VkViewport()
        viewport.x = 0.0
        viewport.y = 0.0
        viewport.width = Float(swapChainExtent.width)
        viewport.height = Float(swapChainExtent.height)
        viewport.minDepth = 0.0
        viewport.maxDepth = 1.0

        var scissor = VkRect2D(offset: VkOffset2D(x: 0, y: 0), extent: swapChainExtent)

        var viewportState = VkPipelineViewportStateCreateInfo()
        viewportState.sType = VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO
        viewportState.viewportCount = 1
        viewportState.pViewports = withUnsafePointer(to: &viewport) { $0 }
        viewportState.scissorCount = 1
        viewportState.pScissors = withUnsafePointer(to: &scissor) { $0 }

        var rasterizer = VkPipelineRasterizationStateCreateInfo()
        rasterizer.sType = VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO
        rasterizer.depthClampEnable = VkBool32(VK_FALSE)
        rasterizer.rasterizerDiscardEnable = VkBool32(VK_FALSE)
        rasterizer.polygonMode = VK_POLYGON_MODE_FILL
        rasterizer.lineWidth = 1.0
        rasterizer.cullMode = VkCullModeFlags(VK_CULL_MODE_BACK_BIT.rawValue)
        rasterizer.frontFace = VK_FRONT_FACE_CLOCKWISE
        rasterizer.depthBiasEnable = VkBool32(VK_FALSE)

        var multisampling = VkPipelineMultisampleStateCreateInfo()
        multisampling.sType = VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO
        multisampling.sampleShadingEnable = VkBool32(VK_FALSE)
        multisampling.rasterizationSamples = VK_SAMPLE_COUNT_1_BIT

        var colorBlendAttachment = VkPipelineColorBlendAttachmentState()
        colorBlendAttachment.colorWriteMask = VkColorComponentFlags(
            VK_COLOR_COMPONENT_R_BIT.rawValue |
            VK_COLOR_COMPONENT_G_BIT.rawValue |
            VK_COLOR_COMPONENT_B_BIT.rawValue |
            VK_COLOR_COMPONENT_A_BIT.rawValue
        )
        colorBlendAttachment.blendEnable = VkBool32(VK_FALSE)

        var colorBlending = VkPipelineColorBlendStateCreateInfo()
        colorBlending.sType = VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO
        colorBlending.logicOpEnable = VkBool32(VK_FALSE)
        colorBlending.attachmentCount = 1
        colorBlending.pAttachments = withUnsafePointer(to: &colorBlendAttachment) { $0 }

        var pipelineLayoutInfo = VkPipelineLayoutCreateInfo()
        pipelineLayoutInfo.sType = VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO
        try vkCheck(vkCreatePipelineLayout(device, &pipelineLayoutInfo, nil, &pipelineLayout), "failed to create pipeline layout")

        var pipelineInfo = VkGraphicsPipelineCreateInfo()
        pipelineInfo.sType = VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO
        try shaderStages.withUnsafeMutableBufferPointer { shaderBuffer in
            pipelineInfo.stageCount = UInt32(shaderBuffer.count)
            pipelineInfo.pStages = UnsafePointer(shaderBuffer.baseAddress)
            pipelineInfo.pVertexInputState = withUnsafePointer(to: &vertexInputInfo) { $0 }
            pipelineInfo.pInputAssemblyState = withUnsafePointer(to: &inputAssembly) { $0 }
            pipelineInfo.pViewportState = withUnsafePointer(to: &viewportState) { $0 }
            pipelineInfo.pRasterizationState = withUnsafePointer(to: &rasterizer) { $0 }
            pipelineInfo.pMultisampleState = withUnsafePointer(to: &multisampling) { $0 }
            pipelineInfo.pColorBlendState = withUnsafePointer(to: &colorBlending) { $0 }
            pipelineInfo.layout = pipelineLayout
            pipelineInfo.renderPass = renderPass
            pipelineInfo.subpass = 0
            try vkCheck(vkCreateGraphicsPipelines(device, nil, 1, &pipelineInfo, nil, &graphicsPipeline), "failed to create graphics pipeline")
        }
    }

    private func createFramebuffers() throws {
        swapChainFramebuffers = Array(repeating: nil, count: swapChainImageViews.count)
        for index in 0..<swapChainImageViews.count {
            var attachments = [swapChainImageViews[index]]
            var framebufferInfo = VkFramebufferCreateInfo()
            framebufferInfo.sType = VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO
            framebufferInfo.renderPass = renderPass
            framebufferInfo.attachmentCount = 1
            framebufferInfo.width = swapChainExtent.width
            framebufferInfo.height = swapChainExtent.height
            framebufferInfo.layers = 1
            try attachments.withUnsafeMutableBufferPointer { attachmentBuffer in
                framebufferInfo.pAttachments = UnsafePointer(attachmentBuffer.baseAddress)
                try vkCheck(vkCreateFramebuffer(device, &framebufferInfo, nil, &swapChainFramebuffers[index]), "failed to create framebuffer")
            }
        }
    }

    private func createCommandPool() throws {
        let indices = findQueueFamilies(physicalDevice)
        var poolInfo = VkCommandPoolCreateInfo()
        poolInfo.sType = VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO
        poolInfo.queueFamilyIndex = indices.graphicsFamily!
        try vkCheck(vkCreateCommandPool(device, &poolInfo, nil, &commandPool), "failed to create command pool")
    }

    private func createCommandBuffers() throws {
        commandBuffers = Array(repeating: nil, count: swapChainFramebuffers.count)
        var allocInfo = VkCommandBufferAllocateInfo()
        allocInfo.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO
        allocInfo.commandPool = commandPool
        allocInfo.level = VK_COMMAND_BUFFER_LEVEL_PRIMARY
        allocInfo.commandBufferCount = UInt32(commandBuffers.count)
        try commandBuffers.withUnsafeMutableBufferPointer {
            try vkCheck(vkAllocateCommandBuffers(device, &allocInfo, $0.baseAddress), "failed to allocate command buffers")
        }

        for index in 0..<commandBuffers.count {
            var beginInfo = VkCommandBufferBeginInfo()
            beginInfo.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO
            try vkCheck(vkBeginCommandBuffer(commandBuffers[index], &beginInfo), "failed to begin command buffer")

            var renderPassInfo = VkRenderPassBeginInfo()
            renderPassInfo.sType = VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO
            renderPassInfo.renderPass = renderPass
            renderPassInfo.framebuffer = swapChainFramebuffers[index]
            renderPassInfo.renderArea.offset = VkOffset2D(x: 0, y: 0)
            renderPassInfo.renderArea.extent = swapChainExtent
            var clearValue = VkClearValue()
            clearValue.color.float32.0 = 0.0
            clearValue.color.float32.1 = 0.0
            clearValue.color.float32.2 = 0.0
            clearValue.color.float32.3 = 1.0
            renderPassInfo.clearValueCount = 1
            renderPassInfo.pClearValues = withUnsafePointer(to: &clearValue) { $0 }

            vkCmdBeginRenderPass(commandBuffers[index], &renderPassInfo, VK_SUBPASS_CONTENTS_INLINE)
            vkCmdBindPipeline(commandBuffers[index], VK_PIPELINE_BIND_POINT_GRAPHICS, graphicsPipeline)
            vkCmdDraw(commandBuffers[index], 3, 1, 0, 0)
            vkCmdEndRenderPass(commandBuffers[index])
            try vkCheck(vkEndCommandBuffer(commandBuffers[index]), "failed to record command buffer")
        }
    }

    private func createSyncObjects() throws {
        imagesInFlight = Array(repeating: nil, count: swapChainImages.count)
        var semaphoreInfo = VkSemaphoreCreateInfo()
        semaphoreInfo.sType = VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO
        var fenceInfo = VkFenceCreateInfo()
        fenceInfo.sType = VK_STRUCTURE_TYPE_FENCE_CREATE_INFO
        fenceInfo.flags = VkFenceCreateFlags(VK_FENCE_CREATE_SIGNALED_BIT.rawValue)
        for index in 0..<maxFramesInFlight {
            try vkCheck(vkCreateSemaphore(device, &semaphoreInfo, nil, &imageAvailableSemaphores[index]), "failed to create imageAvailable semaphore")
            try vkCheck(vkCreateSemaphore(device, &semaphoreInfo, nil, &renderFinishedSemaphores[index]), "failed to create renderFinished semaphore")
            try vkCheck(vkCreateFence(device, &fenceInfo, nil, &inFlightFences[index]), "failed to create fence")
        }
    }

    private func cleanupSwapChain() {
        for framebuffer in swapChainFramebuffers {
            vkDestroyFramebuffer(device, framebuffer, nil)
        }
        swapChainFramebuffers.removeAll()
        for imageView in swapChainImageViews {
            vkDestroyImageView(device, imageView, nil)
        }
        swapChainImageViews.removeAll()
        swapChainImages.removeAll()
        if let graphicsPipeline {
            vkDestroyPipeline(device, graphicsPipeline, nil)
            self.graphicsPipeline = nil
        }
        if let pipelineLayout {
            vkDestroyPipelineLayout(device, pipelineLayout, nil)
            self.pipelineLayout = nil
        }
        if let renderPass {
            vkDestroyRenderPass(device, renderPass, nil)
            self.renderPass = nil
        }
        if let swapChain {
            vkDestroySwapchainKHR(device, swapChain, nil)
            self.swapChain = nil
        }
    }

    private func recreateSwapChain() throws {
        var framebufferWidth: Int32 = 0
        var framebufferHeight: Int32 = 0
        glfwGetFramebufferSize(window, &framebufferWidth, &framebufferHeight)
        while framebufferWidth == 0 || framebufferHeight == 0 {
            glfwGetFramebufferSize(window, &framebufferWidth, &framebufferHeight)
            glfwWaitEvents()
        }
        vkDeviceWaitIdle(device)
        cleanupSwapChain()
        try createSwapChain()
        try createImageViews()
        try createRenderPass()
        try createGraphicsPipeline()
        try createFramebuffers()
        try createCommandBuffers()
        imagesInFlight = Array(repeating: nil, count: swapChainImages.count)
    }

    private func drawFrame() throws {
        try vkCheck(vkWaitForFences(device, 1, &inFlightFences[currentFrame], VkBool32(VK_TRUE), UInt64.max), "failed waiting for fence")

        var imageIndex: UInt32 = 0
        let acquireResult = vkAcquireNextImageKHR(device, swapChain, UInt64.max, imageAvailableSemaphores[currentFrame], nil, &imageIndex)
        if acquireResult == VK_ERROR_OUT_OF_DATE_KHR {
            try recreateSwapChain()
            return
        }
        if acquireResult != VK_SUCCESS && acquireResult != VK_SUBOPTIMAL_KHR {
            try fail("failed to acquire swap chain image")
        }

        if imagesInFlight[Int(imageIndex)] != nil {
            try vkCheck(vkWaitForFences(device, 1, &imagesInFlight[Int(imageIndex)], VkBool32(VK_TRUE), UInt64.max), "failed waiting for image fence")
        }
        imagesInFlight[Int(imageIndex)] = inFlightFences[currentFrame]

        var waitSemaphores = [imageAvailableSemaphores[currentFrame]]
        var waitStages = [VkPipelineStageFlags(VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT.rawValue)]
        var commandBuffer = commandBuffers[Int(imageIndex)]
        var signalSemaphores = [renderFinishedSemaphores[currentFrame]]
        var submitInfo = VkSubmitInfo()
        submitInfo.sType = VK_STRUCTURE_TYPE_SUBMIT_INFO
        submitInfo.waitSemaphoreCount = 1
        submitInfo.commandBufferCount = 1
        submitInfo.signalSemaphoreCount = 1
        try waitSemaphores.withUnsafeMutableBufferPointer { waitBuffer in
            try waitStages.withUnsafeMutableBufferPointer { stageBuffer in
                try withUnsafeMutablePointer(to: &commandBuffer) { commandBufferPointer in
                    try signalSemaphores.withUnsafeMutableBufferPointer { signalBuffer in
                        submitInfo.pWaitSemaphores = UnsafePointer(waitBuffer.baseAddress)
                        submitInfo.pWaitDstStageMask = UnsafePointer(stageBuffer.baseAddress)
                        submitInfo.pCommandBuffers = UnsafePointer(commandBufferPointer)
                        submitInfo.pSignalSemaphores = UnsafePointer(signalBuffer.baseAddress)
                        try vkCheck(vkResetFences(device, 1, &inFlightFences[currentFrame]), "failed to reset fence")
                        try vkCheck(vkQueueSubmit(graphicsQueue, 1, &submitInfo, inFlightFences[currentFrame]), "failed to submit draw command buffer")
                    }
                }
            }
        }

        var swapChains = [swapChain]
        var presentInfo = VkPresentInfoKHR()
        presentInfo.sType = VK_STRUCTURE_TYPE_PRESENT_INFO_KHR
        presentInfo.waitSemaphoreCount = 1
        presentInfo.swapchainCount = 1
        let presentResult = withUnsafeMutablePointer(to: &imageIndex) { imageIndexPointer in
            signalSemaphores.withUnsafeMutableBufferPointer { signalBuffer in
                swapChains.withUnsafeMutableBufferPointer { swapChainBuffer in
                    presentInfo.pImageIndices = UnsafePointer(imageIndexPointer)
                    presentInfo.pWaitSemaphores = UnsafePointer(signalBuffer.baseAddress)
                    presentInfo.pSwapchains = UnsafePointer(swapChainBuffer.baseAddress)
                    return vkQueuePresentKHR(presentQueue, &presentInfo)
                }
            }
        }

        if presentResult == VK_ERROR_OUT_OF_DATE_KHR || presentResult == VK_SUBOPTIMAL_KHR || framebufferResized {
            framebufferResized = false
            try recreateSwapChain()
        } else if presentResult != VK_SUCCESS {
            try fail("failed to present swap chain image")
        }

        currentFrame = (currentFrame + 1) % maxFramesInFlight
    }

    private func initVulkan() throws {
        try createInstance()
        try createSurface()
        try pickPhysicalDevice()
        try createLogicalDevice()
        try createSwapChain()
        try createImageViews()
        try createRenderPass()
        try createGraphicsPipeline()
        try createFramebuffers()
        try createCommandPool()
        try createCommandBuffers()
        try createSyncObjects()
    }

    private func mainLoop() {
        while glfwWindowShouldClose(window) == 0 {
            glfwPollEvents()
            do {
                try drawFrame()
            } catch {
                fputs("\(error)\n", stderr)
                break
            }
        }
        vkDeviceWaitIdle(device)
    }

    private func cleanup() {
        if let device {
            vkDeviceWaitIdle(device)
        }
        for index in 0..<maxFramesInFlight {
            vkDestroySemaphore(device, renderFinishedSemaphores[index], nil)
            vkDestroySemaphore(device, imageAvailableSemaphores[index], nil)
            vkDestroyFence(device, inFlightFences[index], nil)
        }
        cleanupSwapChain()
        if let commandPool {
            vkDestroyCommandPool(device, commandPool, nil)
            self.commandPool = nil
        }
        if let device {
            vkDestroyDevice(device, nil)
            self.device = nil
        }
        if let surface {
            vkDestroySurfaceKHR(instance, surface, nil)
            self.surface = nil
        }
        if let instance {
            vkDestroyInstance(instance, nil)
            self.instance = nil
        }
        if let window {
            glfwDestroyWindow(window)
            self.window = nil
        }
        glfwTerminate()
    }
}

do {
    let app = HelloTriangleApplication()
    try app.run()
} catch let error as SampleError {
    switch error {
    case .message(let message):
        fputs("\(message)\n", stderr)
    }
    exit(EXIT_FAILURE)
} catch {
    fputs("\(error)\n", stderr)
    exit(EXIT_FAILURE)
}