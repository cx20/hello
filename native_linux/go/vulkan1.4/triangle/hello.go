// Vulkan 1.4 Triangle Example in Go
// Linux + GLFW + vulkan-go bindings
// Build: go build -o hello .

package main

import (
	"encoding/binary"
	"fmt"
	"math"
	"os"
	"runtime"
	"syscall"
	"unsafe"

	"github.com/go-gl/glfw/v3.3/glfw"
	vk "github.com/vulkan-go/vulkan"
)

func init() {
	// vulkan-go stores Go-managed strings inside C structs (nested Go pointer
	// pattern). Disable CGo pointer checking by re-exec'ing with cgocheck=0.
	if os.Getenv("_HELLO_REEXEC") == "" {
		env := append(os.Environ(), "GODEBUG=cgocheck=0", "_HELLO_REEXEC=1")
		_ = syscall.Exec("/proc/self/exe", os.Args, env)
	}
	runtime.LockOSThread()
}

// =============================================================================
// Constants
// =============================================================================

const (
	windowWidth      = 800
	windowHeight     = 600
	windowTitle      = "Hello, World!"
	maxFramesInFlight = 2
)

// =============================================================================
// Embedded SPIR-V shaders
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
	0x00000020, 0x00000002, 0x435f6c67, 0x4470696c, 0x61747361, 0x0065636e,
	0x00070006, 0x00000020, 0x00000003, 0x435f6c67, 0x446c6c75, 0x61747361,
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
	0x0000001c, 0x0000001c, 0x00000019, 0x0000001a, 0x0000001b, 0x00040017,
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
// Helper: null-terminate a string for vulkan-go
// =============================================================================

func safeStr(s string) string {
	if len(s) == 0 || s[len(s)-1] != 0 {
		return s + "\x00"
	}
	return s
}

func safeStrSlice(ss []string) []string {
	out := make([]string, len(ss))
	for i, s := range ss {
		out[i] = safeStr(s)
	}
	return out
}

// clearColor creates a VkClearValue for a color attachment.
func clearColor(r, g, b, a float32) vk.ClearValue {
	var cv vk.ClearValue
	binary.LittleEndian.PutUint32(cv[0:], math.Float32bits(r))
	binary.LittleEndian.PutUint32(cv[4:], math.Float32bits(g))
	binary.LittleEndian.PutUint32(cv[8:], math.Float32bits(b))
	binary.LittleEndian.PutUint32(cv[12:], math.Float32bits(a))
	return cv
}

// =============================================================================
// Application struct
// =============================================================================

type App struct {
	window         *glfw.Window
	instance       vk.Instance
	surface        vk.Surface
	physDevice     vk.PhysicalDevice
	device         vk.Device
	graphicsQueue  vk.Queue
	presentQueue   vk.Queue
	graphicsFamily uint32
	presentFamily  uint32

	swapchain      vk.Swapchain
	swapImages     []vk.Image
	swapFormat     vk.Format
	swapExtent     vk.Extent2D
	swapImageViews []vk.ImageView

	renderPass     vk.RenderPass
	pipelineLayout vk.PipelineLayout
	pipeline       vk.Pipeline
	framebuffers   []vk.Framebuffer

	commandPool    vk.CommandPool
	commandBuffers []vk.CommandBuffer

	imageAvailable [maxFramesInFlight]vk.Semaphore
	renderFinished [maxFramesInFlight]vk.Semaphore
	inFlight       [maxFramesInFlight]vk.Fence

	currentFrame int
}

func main() {
	app := &App{}
	app.run()
}

func (a *App) run() {
	a.initWindow()
	a.initVulkan()
	a.mainLoop()
	a.cleanup()
}

// =============================================================================
// Window
// =============================================================================

func (a *App) initWindow() {
	if err := glfw.Init(); err != nil {
		panic(fmt.Sprintf("glfw.Init: %v", err))
	}
	if !glfw.VulkanSupported() {
		panic("Vulkan is not supported by GLFW")
	}
	glfw.WindowHint(glfw.ClientAPI, glfw.NoAPI)
	glfw.WindowHint(glfw.Resizable, glfw.False)

	var err error
	a.window, err = glfw.CreateWindow(windowWidth, windowHeight, windowTitle, nil, nil)
	if err != nil {
		panic(fmt.Sprintf("glfw.CreateWindow: %v", err))
	}
}

// =============================================================================
// Vulkan init
// =============================================================================

func (a *App) initVulkan() {
	vk.SetGetInstanceProcAddr(glfw.GetVulkanGetInstanceProcAddress())
	if err := vk.Init(); err != nil {
		panic(fmt.Sprintf("vk.Init: %v", err))
	}
	a.createInstance()
	vk.InitInstance(a.instance)
	a.createSurface()
	a.pickPhysicalDevice()
	a.createLogicalDevice()
	a.createSwapchain()
	a.createImageViews()
	a.createRenderPass()
	a.createGraphicsPipeline()
	a.createFramebuffers()
	a.createCommandPool()
	a.createCommandBuffers()
	a.createSyncObjects()
}

// =============================================================================
// Instance
// =============================================================================

func (a *App) createInstance() {
	exts := safeStrSlice(a.window.GetRequiredInstanceExtensions())

	appInfo := &vk.ApplicationInfo{
		SType:              vk.StructureTypeApplicationInfo,
		PApplicationName:   safeStr("Hello, World!"),
		ApplicationVersion: vk.MakeVersion(1, 0, 0),
		PEngineName:        safeStr("No Engine"),
		EngineVersion:      vk.MakeVersion(1, 0, 0),
		ApiVersion:         vk.MakeVersion(1, 4, 0),
	}
	var pinner runtime.Pinner
	pinner.Pin(appInfo)
	defer pinner.Unpin()

	ret := vk.CreateInstance(&vk.InstanceCreateInfo{
		SType:                   vk.StructureTypeInstanceCreateInfo,
		PApplicationInfo:        appInfo,
		EnabledExtensionCount:   uint32(len(exts)),
		PpEnabledExtensionNames: exts,
	}, nil, &a.instance)
	orPanic(ret, "vkCreateInstance")
}

// =============================================================================
// Surface
// =============================================================================

func (a *App) createSurface() {
	// CreateWindowSurface returns a uintptr that is a pointer to VkSurfaceKHR
	// (not the handle value itself). Dereference it to get the actual handle.
	surfacePtr, err := a.window.CreateWindowSurface(a.instance, nil)
	if err != nil {
		panic(fmt.Sprintf("CreateWindowSurface: %v", err))
	}
	a.surface = *(*vk.Surface)(unsafe.Pointer(surfacePtr))
}

// =============================================================================
// Physical device
// =============================================================================

func (a *App) pickPhysicalDevice() {
	var count uint32
	vk.EnumeratePhysicalDevices(a.instance, &count, nil)
	if count == 0 {
		panic("no Vulkan-capable GPU found")
	}
	devices := make([]vk.PhysicalDevice, count)
	vk.EnumeratePhysicalDevices(a.instance, &count, devices)

	for _, dev := range devices {
		gf, pf, ok := a.findQueueFamilies(dev)
		if ok {
			a.physDevice = dev
			a.graphicsFamily = gf
			a.presentFamily = pf
			return
		}
	}
	panic("no suitable GPU found")
}

func (a *App) findQueueFamilies(dev vk.PhysicalDevice) (gfx, present uint32, ok bool) {
	var count uint32
	vk.GetPhysicalDeviceQueueFamilyProperties(dev, &count, nil)
	props := make([]vk.QueueFamilyProperties, count)
	vk.GetPhysicalDeviceQueueFamilyProperties(dev, &count, props)

	gfxFound, presentFound := false, false

	for i, p := range props {
		p.Deref()
		if p.QueueFlags&vk.QueueFlags(vk.QueueGraphicsBit) != 0 {
			gfx = uint32(i)
			gfxFound = true
		}
		var supported vk.Bool32
		vk.GetPhysicalDeviceSurfaceSupport(dev, uint32(i), a.surface, &supported)
		if supported == vk.True {
			present = uint32(i)
			presentFound = true
		}
		if gfxFound && presentFound {
			return gfx, present, true
		}
	}
	return 0, 0, false
}

// =============================================================================
// Logical device
// =============================================================================

func (a *App) createLogicalDevice() {
	priority := float32(1.0)

	queueInfos := []vk.DeviceQueueCreateInfo{
		{
			SType:            vk.StructureTypeDeviceQueueCreateInfo,
			QueueFamilyIndex: a.graphicsFamily,
			QueueCount:       1,
			PQueuePriorities: []float32{priority},
		},
	}
	if a.graphicsFamily != a.presentFamily {
		queueInfos = append(queueInfos, vk.DeviceQueueCreateInfo{
			SType:            vk.StructureTypeDeviceQueueCreateInfo,
			QueueFamilyIndex: a.presentFamily,
			QueueCount:       1,
			PQueuePriorities: []float32{priority},
		})
	}

	deviceExts := safeStrSlice([]string{"VK_KHR_swapchain"})

	ret := vk.CreateDevice(a.physDevice, &vk.DeviceCreateInfo{
		SType:                   vk.StructureTypeDeviceCreateInfo,
		QueueCreateInfoCount:    uint32(len(queueInfos)),
		PQueueCreateInfos:       queueInfos,
		EnabledExtensionCount:   uint32(len(deviceExts)),
		PpEnabledExtensionNames: deviceExts,
	}, nil, &a.device)
	orPanic(ret, "vkCreateDevice")

	vk.GetDeviceQueue(a.device, a.graphicsFamily, 0, &a.graphicsQueue)
	vk.GetDeviceQueue(a.device, a.presentFamily, 0, &a.presentQueue)
}

// =============================================================================
// Swapchain
// =============================================================================

func (a *App) createSwapchain() {
	caps := vk.SurfaceCapabilities{}
	vk.GetPhysicalDeviceSurfaceCapabilities(a.physDevice, a.surface, &caps)
	caps.Deref()

	// Choose format
	var formatCount uint32
	vk.GetPhysicalDeviceSurfaceFormats(a.physDevice, a.surface, &formatCount, nil)
	formats := make([]vk.SurfaceFormat, formatCount)
	vk.GetPhysicalDeviceSurfaceFormats(a.physDevice, a.surface, &formatCount, formats)
	chosenFormat := formats[0]
	chosenFormat.Deref()
	for _, f := range formats {
		f.Deref()
		if f.Format == vk.FormatB8g8r8a8Srgb && f.ColorSpace == vk.ColorSpaceSrgbNonlinear {
			chosenFormat = f
			break
		}
	}

	// Choose present mode
	var pmCount uint32
	vk.GetPhysicalDeviceSurfacePresentModes(a.physDevice, a.surface, &pmCount, nil)
	presentModes := make([]vk.PresentMode, pmCount)
	vk.GetPhysicalDeviceSurfacePresentModes(a.physDevice, a.surface, &pmCount, presentModes)
	chosenPM := vk.PresentModeFifo
	for _, pm := range presentModes {
		if pm == vk.PresentModeMailbox {
			chosenPM = pm
			break
		}
	}

	// Choose extent
	extent := caps.CurrentExtent
	extent.Deref()
	if extent.Width == 0xFFFFFFFF {
		extent.Width = windowWidth
		extent.Height = windowHeight
	}

	imageCount := caps.MinImageCount + 1
	if caps.MaxImageCount > 0 && imageCount > caps.MaxImageCount {
		imageCount = caps.MaxImageCount
	}

	sharingMode := vk.SharingModeExclusive
	var queueFamilyIndices []uint32
	if a.graphicsFamily != a.presentFamily {
		sharingMode = vk.SharingModeConcurrent
		queueFamilyIndices = []uint32{a.graphicsFamily, a.presentFamily}
	}

	ret := vk.CreateSwapchain(a.device, &vk.SwapchainCreateInfo{
		SType:                 vk.StructureTypeSwapchainCreateInfo,
		Surface:               a.surface,
		MinImageCount:         imageCount,
		ImageFormat:           chosenFormat.Format,
		ImageColorSpace:       chosenFormat.ColorSpace,
		ImageExtent:           extent,
		ImageArrayLayers:      1,
		ImageUsage:            vk.ImageUsageFlags(vk.ImageUsageColorAttachmentBit),
		ImageSharingMode:      sharingMode,
		QueueFamilyIndexCount: uint32(len(queueFamilyIndices)),
		PQueueFamilyIndices:   queueFamilyIndices,
		PreTransform:          caps.CurrentTransform,
		CompositeAlpha:        vk.CompositeAlphaOpaqueBit,
		PresentMode:           chosenPM,
		Clipped:               vk.True,
	}, nil, &a.swapchain)
	orPanic(ret, "vkCreateSwapchainKHR")

	a.swapFormat = chosenFormat.Format
	a.swapExtent = extent

	var imgCount uint32
	vk.GetSwapchainImages(a.device, a.swapchain, &imgCount, nil)
	a.swapImages = make([]vk.Image, imgCount)
	vk.GetSwapchainImages(a.device, a.swapchain, &imgCount, a.swapImages)
}

// =============================================================================
// Image views
// =============================================================================

func (a *App) createImageViews() {
	a.swapImageViews = make([]vk.ImageView, len(a.swapImages))
	for i, img := range a.swapImages {
		var view vk.ImageView
		ret := vk.CreateImageView(a.device, &vk.ImageViewCreateInfo{
			SType:    vk.StructureTypeImageViewCreateInfo,
			Image:    img,
			ViewType: vk.ImageViewType2d,
			Format:   a.swapFormat,
			Components: vk.ComponentMapping{
				R: vk.ComponentSwizzleIdentity,
				G: vk.ComponentSwizzleIdentity,
				B: vk.ComponentSwizzleIdentity,
				A: vk.ComponentSwizzleIdentity,
			},
			SubresourceRange: vk.ImageSubresourceRange{
				AspectMask:     vk.ImageAspectFlags(vk.ImageAspectColorBit),
				BaseMipLevel:   0,
				LevelCount:     1,
				BaseArrayLayer: 0,
				LayerCount:     1,
			},
		}, nil, &view)
		orPanic(ret, "vkCreateImageView")
		a.swapImageViews[i] = view
	}
}

// =============================================================================
// Render pass
// =============================================================================

func (a *App) createRenderPass() {
	ret := vk.CreateRenderPass(a.device, &vk.RenderPassCreateInfo{
		SType:           vk.StructureTypeRenderPassCreateInfo,
		AttachmentCount: 1,
		PAttachments: []vk.AttachmentDescription{
			{
				Format:         a.swapFormat,
				Samples:        vk.SampleCount1Bit,
				LoadOp:         vk.AttachmentLoadOpClear,
				StoreOp:        vk.AttachmentStoreOpStore,
				StencilLoadOp:  vk.AttachmentLoadOpDontCare,
				StencilStoreOp: vk.AttachmentStoreOpDontCare,
				InitialLayout:  vk.ImageLayoutUndefined,
				FinalLayout:    vk.ImageLayoutPresentSrc,
			},
		},
		SubpassCount: 1,
		PSubpasses: []vk.SubpassDescription{
			{
				PipelineBindPoint:    vk.PipelineBindPointGraphics,
				ColorAttachmentCount: 1,
				PColorAttachments: []vk.AttachmentReference{
					{
						Attachment: 0,
						Layout:     vk.ImageLayoutColorAttachmentOptimal,
					},
				},
			},
		},
		DependencyCount: 1,
		PDependencies: []vk.SubpassDependency{
			{
				SrcSubpass:    vk.SubpassExternal,
				DstSubpass:    0,
				SrcStageMask:  vk.PipelineStageFlags(vk.PipelineStageColorAttachmentOutputBit),
				SrcAccessMask: 0,
				DstStageMask:  vk.PipelineStageFlags(vk.PipelineStageColorAttachmentOutputBit),
				DstAccessMask: vk.AccessFlags(vk.AccessColorAttachmentWriteBit),
			},
		},
	}, nil, &a.renderPass)
	orPanic(ret, "vkCreateRenderPass")
}

// =============================================================================
// Graphics pipeline
// =============================================================================

func (a *App) createGraphicsPipeline() {
	vertModule := a.createShaderModule(vertShaderCode)
	fragModule := a.createShaderModule(fragShaderCode)
	defer vk.DestroyShaderModule(a.device, vertModule, nil)
	defer vk.DestroyShaderModule(a.device, fragModule, nil)

	shaderStages := []vk.PipelineShaderStageCreateInfo{
		{
			SType:  vk.StructureTypePipelineShaderStageCreateInfo,
			Stage:  vk.ShaderStageVertexBit,
			Module: vertModule,
			PName:  safeStr("main"),
		},
		{
			SType:  vk.StructureTypePipelineShaderStageCreateInfo,
			Stage:  vk.ShaderStageFragmentBit,
			Module: fragModule,
			PName:  safeStr("main"),
		},
	}

	pipelineLayoutRet := vk.CreatePipelineLayout(a.device, &vk.PipelineLayoutCreateInfo{
		SType: vk.StructureTypePipelineLayoutCreateInfo,
	}, nil, &a.pipelineLayout)
	orPanic(pipelineLayoutRet, "vkCreatePipelineLayout")

	viewport := vk.Viewport{
		X:        0,
		Y:        0,
		Width:    float32(a.swapExtent.Width),
		Height:   float32(a.swapExtent.Height),
		MinDepth: 0,
		MaxDepth: 1,
	}
	scissor := vk.Rect2D{
		Offset: vk.Offset2D{X: 0, Y: 0},
		Extent: a.swapExtent,
	}

	vertexInputState := &vk.PipelineVertexInputStateCreateInfo{
		SType: vk.StructureTypePipelineVertexInputStateCreateInfo,
	}
	inputAssemblyState := &vk.PipelineInputAssemblyStateCreateInfo{
		SType:    vk.StructureTypePipelineInputAssemblyStateCreateInfo,
		Topology: vk.PrimitiveTopologyTriangleList,
	}
	viewportState := &vk.PipelineViewportStateCreateInfo{
		SType:         vk.StructureTypePipelineViewportStateCreateInfo,
		ViewportCount: 1,
		PViewports:    []vk.Viewport{viewport},
		ScissorCount:  1,
		PScissors:     []vk.Rect2D{scissor},
	}
	rasterizationState := &vk.PipelineRasterizationStateCreateInfo{
		SType:       vk.StructureTypePipelineRasterizationStateCreateInfo,
		PolygonMode: vk.PolygonModeFill,
		CullMode:    vk.CullModeFlags(vk.CullModeNone),
		FrontFace:   vk.FrontFaceClockwise,
		LineWidth:   1.0,
	}
	multisampleState := &vk.PipelineMultisampleStateCreateInfo{
		SType:                vk.StructureTypePipelineMultisampleStateCreateInfo,
		RasterizationSamples: vk.SampleCount1Bit,
		MinSampleShading:     1.0,
	}
	colorBlendAttachment := vk.PipelineColorBlendAttachmentState{
		ColorWriteMask: vk.ColorComponentFlags(
			vk.ColorComponentRBit | vk.ColorComponentGBit |
				vk.ColorComponentBBit | vk.ColorComponentABit),
	}
	colorBlendState := &vk.PipelineColorBlendStateCreateInfo{
		SType:           vk.StructureTypePipelineColorBlendStateCreateInfo,
		AttachmentCount: 1,
		PAttachments:    []vk.PipelineColorBlendAttachmentState{colorBlendAttachment},
	}

	var pinner runtime.Pinner
	pinner.Pin(vertexInputState)
	pinner.Pin(inputAssemblyState)
	pinner.Pin(viewportState)
	pinner.Pin(rasterizationState)
	pinner.Pin(multisampleState)
	pinner.Pin(colorBlendState)
	defer pinner.Unpin()

	pipelines := make([]vk.Pipeline, 1)
	var noCache vk.PipelineCache
	ret := vk.CreateGraphicsPipelines(a.device, noCache, 1, []vk.GraphicsPipelineCreateInfo{
		{
			SType:               vk.StructureTypeGraphicsPipelineCreateInfo,
			StageCount:          uint32(len(shaderStages)),
			PStages:             shaderStages,
			PVertexInputState:   vertexInputState,
			PInputAssemblyState: inputAssemblyState,
			PViewportState:      viewportState,
			PRasterizationState: rasterizationState,
			PMultisampleState:   multisampleState,
			PColorBlendState:    colorBlendState,
			Layout:              a.pipelineLayout,
			RenderPass:          a.renderPass,
			Subpass:             0,
		},
	}, nil, pipelines)
	orPanic(ret, "vkCreateGraphicsPipelines")
	a.pipeline = pipelines[0]
}

func (a *App) createShaderModule(code []uint32) vk.ShaderModule {
	var shaderModule vk.ShaderModule
	ret := vk.CreateShaderModule(a.device, &vk.ShaderModuleCreateInfo{
		SType:    vk.StructureTypeShaderModuleCreateInfo,
		CodeSize: uint(len(code) * 4),
		PCode:    code,
	}, nil, &shaderModule)
	orPanic(ret, "vkCreateShaderModule")
	return shaderModule
}

// =============================================================================
// Framebuffers
// =============================================================================

func (a *App) createFramebuffers() {
	a.framebuffers = make([]vk.Framebuffer, len(a.swapImageViews))
	for i, view := range a.swapImageViews {
		var fb vk.Framebuffer
		ret := vk.CreateFramebuffer(a.device, &vk.FramebufferCreateInfo{
			SType:           vk.StructureTypeFramebufferCreateInfo,
			RenderPass:      a.renderPass,
			AttachmentCount: 1,
			PAttachments:    []vk.ImageView{view},
			Width:           a.swapExtent.Width,
			Height:          a.swapExtent.Height,
			Layers:          1,
		}, nil, &fb)
		orPanic(ret, "vkCreateFramebuffer")
		a.framebuffers[i] = fb
	}
}

// =============================================================================
// Command pool + buffers
// =============================================================================

func (a *App) createCommandPool() {
	ret := vk.CreateCommandPool(a.device, &vk.CommandPoolCreateInfo{
		SType:            vk.StructureTypeCommandPoolCreateInfo,
		Flags:            vk.CommandPoolCreateFlags(vk.CommandPoolCreateResetCommandBufferBit),
		QueueFamilyIndex: a.graphicsFamily,
	}, nil, &a.commandPool)
	orPanic(ret, "vkCreateCommandPool")
}

func (a *App) createCommandBuffers() {
	a.commandBuffers = make([]vk.CommandBuffer, maxFramesInFlight)
	ret := vk.AllocateCommandBuffers(a.device, &vk.CommandBufferAllocateInfo{
		SType:              vk.StructureTypeCommandBufferAllocateInfo,
		CommandPool:        a.commandPool,
		Level:              vk.CommandBufferLevelPrimary,
		CommandBufferCount: maxFramesInFlight,
	}, a.commandBuffers)
	orPanic(ret, "vkAllocateCommandBuffers")
}

// =============================================================================
// Sync objects
// =============================================================================

func (a *App) createSyncObjects() {
	semInfo := &vk.SemaphoreCreateInfo{SType: vk.StructureTypeSemaphoreCreateInfo}
	fenceInfo := &vk.FenceCreateInfo{
		SType: vk.StructureTypeFenceCreateInfo,
		Flags: vk.FenceCreateFlags(vk.FenceCreateSignaledBit),
	}
	for i := 0; i < maxFramesInFlight; i++ {
		orPanic(vk.CreateSemaphore(a.device, semInfo, nil, &a.imageAvailable[i]), "imageAvailableSemaphore")
		orPanic(vk.CreateSemaphore(a.device, semInfo, nil, &a.renderFinished[i]), "renderFinishedSemaphore")
		orPanic(vk.CreateFence(a.device, fenceInfo, nil, &a.inFlight[i]), "inFlightFence")
	}
}

// =============================================================================
// Main loop
// =============================================================================

func (a *App) mainLoop() {
	for !a.window.ShouldClose() {
		glfw.PollEvents()
		a.drawFrame()
	}
	vk.DeviceWaitIdle(a.device)
}

func (a *App) drawFrame() {
	cf := a.currentFrame
	vk.WaitForFences(a.device, 1, []vk.Fence{a.inFlight[cf]}, vk.True, ^uint64(0))
	vk.ResetFences(a.device, 1, []vk.Fence{a.inFlight[cf]})

	var imageIndex uint32
	var noFence vk.Fence
	ret := vk.AcquireNextImage(a.device, a.swapchain, ^uint64(0),
		a.imageAvailable[cf], noFence, &imageIndex)
	if ret == vk.ErrorOutOfDate {
		return
	}

	vk.ResetCommandBuffer(a.commandBuffers[cf], 0)
	a.recordCommandBuffer(a.commandBuffers[cf], imageIndex)

	waitStage := []vk.PipelineStageFlags{vk.PipelineStageFlags(vk.PipelineStageColorAttachmentOutputBit)}
	submitInfo := vk.SubmitInfo{
		SType:                vk.StructureTypeSubmitInfo,
		WaitSemaphoreCount:   1,
		PWaitSemaphores:      []vk.Semaphore{a.imageAvailable[cf]},
		PWaitDstStageMask:    waitStage,
		CommandBufferCount:   1,
		PCommandBuffers:      []vk.CommandBuffer{a.commandBuffers[cf]},
		SignalSemaphoreCount: 1,
		PSignalSemaphores:    []vk.Semaphore{a.renderFinished[cf]},
	}
	orPanic(vk.QueueSubmit(a.graphicsQueue, 1, []vk.SubmitInfo{submitInfo}, a.inFlight[cf]), "vkQueueSubmit")

	vk.QueuePresent(a.presentQueue, &vk.PresentInfo{
		SType:              vk.StructureTypePresentInfo,
		WaitSemaphoreCount: 1,
		PWaitSemaphores:    []vk.Semaphore{a.renderFinished[cf]},
		SwapchainCount:     1,
		PSwapchains:        []vk.Swapchain{a.swapchain},
		PImageIndices:      []uint32{imageIndex},
	})

	a.currentFrame = (a.currentFrame + 1) % maxFramesInFlight
}

func (a *App) recordCommandBuffer(cb vk.CommandBuffer, imageIndex uint32) {
	orPanic(vk.BeginCommandBuffer(cb, &vk.CommandBufferBeginInfo{
		SType: vk.StructureTypeCommandBufferBeginInfo,
	}), "vkBeginCommandBuffer")

	clearVal := clearColor(0.0, 0.0, 0.0, 1.0)
	vk.CmdBeginRenderPass(cb, &vk.RenderPassBeginInfo{
		SType:       vk.StructureTypeRenderPassBeginInfo,
		RenderPass:  a.renderPass,
		Framebuffer: a.framebuffers[imageIndex],
		RenderArea: vk.Rect2D{
			Offset: vk.Offset2D{X: 0, Y: 0},
			Extent: a.swapExtent,
		},
		ClearValueCount: 1,
		PClearValues:    []vk.ClearValue{clearVal},
	}, vk.SubpassContentsInline)

	vk.CmdBindPipeline(cb, vk.PipelineBindPointGraphics, a.pipeline)

	vk.CmdDraw(cb, 3, 1, 0, 0)
	vk.CmdEndRenderPass(cb)
	orPanic(vk.EndCommandBuffer(cb), "vkEndCommandBuffer")
}

// =============================================================================
// Cleanup
// =============================================================================

func (a *App) cleanup() {
	for i := 0; i < maxFramesInFlight; i++ {
		vk.DestroySemaphore(a.device, a.imageAvailable[i], nil)
		vk.DestroySemaphore(a.device, a.renderFinished[i], nil)
		vk.DestroyFence(a.device, a.inFlight[i], nil)
	}
	vk.DestroyCommandPool(a.device, a.commandPool, nil)
	for _, fb := range a.framebuffers {
		vk.DestroyFramebuffer(a.device, fb, nil)
	}
	vk.DestroyPipeline(a.device, a.pipeline, nil)
	vk.DestroyPipelineLayout(a.device, a.pipelineLayout, nil)
	vk.DestroyRenderPass(a.device, a.renderPass, nil)
	for _, v := range a.swapImageViews {
		vk.DestroyImageView(a.device, v, nil)
	}
	vk.DestroySwapchain(a.device, a.swapchain, nil)
	vk.DestroyDevice(a.device, nil)
	vk.DestroySurface(a.instance, a.surface, nil)
	vk.DestroyInstance(a.instance, nil)
	a.window.Destroy()
	glfw.Terminate()
}

// =============================================================================
// Helpers
// =============================================================================

func orPanic(ret vk.Result, msg string) {
	if ret != vk.Success {
		panic(fmt.Sprintf("%s: %v", msg, ret))
	}
}
