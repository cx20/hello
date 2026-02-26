package main

/*
 * hello_dcomp.go
 *
 * Win32 window + OpenGL 4.6 + D3D11 + Vulkan triangles composited via
 * DirectComposition on a classic desktop app.
 *
 * Pure Go (no cgo) using raw COM vtable calls and syscall.SyscallN.
 *
 * Architecture:
 *   - Three DXGI swap chains created with CreateSwapChainForComposition
 *   - Left panel:  OpenGL 4.6 via WGL_NV_DX_interop into D3D11 back buffer
 *   - Center panel: D3D11 direct rendering
 *   - Right panel:  Vulkan offscreen -> readback -> D3D11 staging copy
 *   - DirectComposition root visual with 3 child visuals
 *
 * Build:
 *   go build -ldflags "-H windowsgui" hello_dcomp.go
 *
 * Requirements:
 *   - NVIDIA GPU (for WGL_NV_DX_interop)
 *   - Vulkan SDK installed (vulkan-1.dll)
 *   - hello_vert.spv and hello_frag.spv in working directory
 *
 * SPIR-V compilation:
 *   glslangValidator -V hello.vert -o hello_vert.spv
 *   glslangValidator -V hello.frag -o hello_frag.spv
 */

import (
	"math"
	"os"
	"syscall"
	"unsafe"
)

// ============================================================
// Constants
// ============================================================

const (
	panelW     = 320
	panelH     = 480
	windowW    = panelW * 3
	vertexSize = 7 * 4 // 3 floats pos + 4 floats color = 28 bytes
)

// Win32
const (
	WS_OVERLAPPEDWINDOW      = 0x00CF0000
	WS_VISIBLE                = 0x10000000
	WS_EX_NOREDIRECTIONBITMAP = 0x00200000
	CW_USEDEFAULT             = 0x80000000
	SW_SHOW                   = 5
	IDC_ARROW                 = 32512
	WM_DESTROY                = 0x0002
	WM_PAINT                  = 0x000F
	PM_REMOVE                 = 0x0001
)

// DXGI / D3D11
const (
	D3D_DRIVER_TYPE_HARDWARE          = 1
	D3D11_SDK_VERSION                 = 7
	D3D11_CREATE_DEVICE_BGRA_SUPPORT  = 0x20
	D3D_FEATURE_LEVEL_11_0            = 0xb000
	DXGI_FORMAT_B8G8R8A8_UNORM        = 87
	DXGI_FORMAT_R32G32B32_FLOAT       = 6
	DXGI_FORMAT_R32G32B32A32_FLOAT    = 2
	DXGI_USAGE_RENDER_TARGET_OUTPUT   = 0x20
	DXGI_SCALING_STRETCH              = 0
	DXGI_SWAP_EFFECT_FLIP_SEQUENTIAL  = 3
	DXGI_ALPHA_MODE_PREMULTIPLIED     = 1
	D3D11_BIND_VERTEX_BUFFER          = 0x1
	D3D11_USAGE_DEFAULT               = 0
	D3D11_USAGE_STAGING               = 3
	D3D11_CPU_ACCESS_WRITE            = 0x10000
	D3D11_INPUT_PER_VERTEX_DATA       = 0
	D3D11_PRIMITIVE_TOPOLOGY_TRIANGLELIST = 4
	D3D11_MAP_WRITE                   = 2
	D3DCOMPILE_ENABLE_STRICTNESS      = 0x800
)

// OpenGL
const (
	GL_TRIANGLES                    = 0x0004
	GL_FLOAT                        = 0x1406
	GL_FALSE                        = 0
	GL_COLOR_BUFFER_BIT             = 0x4000
	GL_ARRAY_BUFFER                 = 0x8892
	GL_STATIC_DRAW                  = 0x88E4
	GL_FRAGMENT_SHADER              = 0x8B30
	GL_VERTEX_SHADER                = 0x8B31
	GL_FRAMEBUFFER                  = 0x8D40
	GL_RENDERBUFFER                 = 0x8D41
	GL_COLOR_ATTACHMENT0            = 0x8CE0
	GL_FRAMEBUFFER_COMPLETE         = 0x8CD5
	GL_COMPILE_STATUS               = 0x8B81
	GL_LINK_STATUS                  = 0x8B82
	WGL_CONTEXT_MAJOR_VERSION_ARB   = 0x2091
	WGL_CONTEXT_MINOR_VERSION_ARB   = 0x2092
	WGL_CONTEXT_FLAGS_ARB           = 0x2094
	WGL_CONTEXT_PROFILE_MASK_ARB    = 0x9126
	WGL_CONTEXT_CORE_PROFILE_BIT_ARB = 0x00000001
	WGL_ACCESS_READ_WRITE_NV        = 0x0001
	PFD_DRAW_TO_WINDOW              = 0x4
	PFD_SUPPORT_OPENGL              = 0x20
	PFD_DOUBLEBUFFER                = 0x1
	PFD_TYPE_RGBA                   = 0
	PFD_MAIN_PLANE                  = 0
)

// Vulkan
const (
	VK_SUCCESS                          = 0
	VK_STRUCTURE_TYPE_APPLICATION_INFO   = 0
	VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO = 1
	VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO = 2
	VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO = 3
	VK_STRUCTURE_TYPE_SUBMIT_INFO       = 4
	VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO = 5
	VK_STRUCTURE_TYPE_FENCE_CREATE_INFO = 8
	VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO = 39
	VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO = 40
	VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO = 42
	VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO = 43
	VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO = 38
	VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO = 37
	VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO = 16
	VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO = 18
	VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO = 19
	VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO = 20
	VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO = 22
	VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO = 23
	VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO = 24
	VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO = 26
	VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO = 30
	VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO = 28
	VK_STRUCTURE_TYPE_IMAGE_CREATE_INFO = 14
	VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO = 15
	VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO = 12
	VK_IMAGE_TYPE_2D                    = 1
	VK_FORMAT_B8G8R8A8_UNORM           = 44
	VK_SAMPLE_COUNT_1_BIT              = 1
	VK_IMAGE_TILING_OPTIMAL            = 0
	VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT = 0x10
	VK_IMAGE_USAGE_TRANSFER_SRC_BIT    = 0x1
	VK_IMAGE_LAYOUT_UNDEFINED          = 0
	VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL = 2
	VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL = 6
	VK_IMAGE_VIEW_TYPE_2D              = 1
	VK_IMAGE_ASPECT_COLOR_BIT          = 0x1
	VK_BUFFER_USAGE_TRANSFER_DST_BIT   = 0x2
	VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT = 0x1
	VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT = 0x2
	VK_MEMORY_PROPERTY_HOST_COHERENT_BIT = 0x4
	VK_ATTACHMENT_LOAD_OP_CLEAR         = 1
	VK_ATTACHMENT_STORE_OP_STORE        = 0
	VK_ATTACHMENT_LOAD_OP_DONT_CARE     = 2
	VK_ATTACHMENT_STORE_OP_DONT_CARE    = 1
	VK_PIPELINE_BIND_POINT_GRAPHICS     = 0
	VK_SUBPASS_CONTENTS_INLINE          = 0
	VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST = 3
	VK_POLYGON_MODE_FILL                = 0
	VK_CULL_MODE_BACK_BIT               = 2
	VK_FRONT_FACE_CLOCKWISE             = 1
	VK_SHADER_STAGE_VERTEX_BIT          = 0x1
	VK_SHADER_STAGE_FRAGMENT_BIT        = 0x10
	VK_COMMAND_BUFFER_LEVEL_PRIMARY     = 0
	VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT = 0x2
	VK_FENCE_CREATE_SIGNALED_BIT        = 0x1
	VK_QUEUE_GRAPHICS_BIT               = 0x1
	VK_TRUE                             = 1
)

// ============================================================
// GUIDs
// ============================================================

type GUID struct {
	Data1 uint32
	Data2 uint16
	Data3 uint16
	Data4 [8]byte
}

var (
	IID_IDXGIDevice  = GUID{0x54ec77fa, 0x1377, 0x44e6, [8]byte{0x8c, 0x32, 0x88, 0xfd, 0x5f, 0x44, 0xc8, 0x4c}}
	IID_IDXGIFactory2 = GUID{0x50c83a1c, 0xe072, 0x4c48, [8]byte{0x87, 0xb0, 0x36, 0x30, 0xfa, 0x36, 0xa6, 0xd0}}
	IID_ID3D11Texture2D = GUID{0x6f15aaf2, 0xd208, 0x4e89, [8]byte{0x9a, 0xb4, 0x48, 0x95, 0x35, 0xd3, 0x4f, 0x9c}}
	IID_IDCompositionDevice = GUID{0xC37EA93A, 0xE7AA, 0x450D, [8]byte{0xB1, 0x6F, 0x97, 0x46, 0xCB, 0x04, 0x07, 0xF3}}
)

// ============================================================
// Structures
// ============================================================

type POINT struct{ X, Y int32 }
type MSG struct {
	Hwnd    uintptr
	Message uint32
	WParam  uintptr
	LParam  uintptr
	Time    uint32
	Pt      POINT
}
type RECT struct{ Left, Top, Right, Bottom int32 }
type PAINTSTRUCT struct {
	Hdc        uintptr
	FErase     int32
	RcPaint    RECT
	FRestore   int32
	FIncUpdate int32
	Reserved   [32]byte
}
type WNDCLASSEXW struct {
	Size       uint32
	Style      uint32
	WndProc    uintptr
	ClsExtra   int32
	WndExtra   int32
	Instance   uintptr
	Icon       uintptr
	Cursor     uintptr
	Background uintptr
	MenuName   *uint16
	ClassName  *uint16
	IconSm     uintptr
}
type PIXELFORMATDESCRIPTOR struct {
	Size, Version                          uint16
	Flags                                  uint32
	PixelType, ColorBits, RedBits, RedShift,
	GreenBits, GreenShift, BlueBits, BlueShift,
	AlphaBits, AlphaShift, AccumBits,
	AccumRedBits, AccumGreenBits, AccumBlueBits,
	AccumAlphaBits, DepthBits, StencilBits,
	AuxBuffers, LayerType, Reserved byte
	LayerMask, VisibleMask, DamageMask uint32
}

// DXGI / D3D11 structures
type DXGI_SAMPLE_DESC struct{ Count, Quality uint32 }
type DXGI_SWAP_CHAIN_DESC1 struct {
	Width, Height uint32
	Format        uint32
	Stereo        int32
	SampleDesc    DXGI_SAMPLE_DESC
	BufferUsage   uint32
	BufferCount   uint32
	Scaling       uint32
	SwapEffect    uint32
	AlphaMode     uint32
	Flags         uint32
}
type D3D11_VIEWPORT struct {
	TopLeftX, TopLeftY, Width, Height, MinDepth, MaxDepth float32
}
type D3D11_INPUT_ELEMENT_DESC struct {
	SemanticName         *byte
	SemanticIndex        uint32
	Format               uint32
	InputSlot            uint32
	AlignedByteOffset    uint32
	InputSlotClass       uint32
	InstanceDataStepRate uint32
}
type D3D11_BUFFER_DESC struct {
	ByteWidth, Usage, BindFlags, CPUAccessFlags, MiscFlags, StructureByteStride uint32
}
type D3D11_SUBRESOURCE_DATA struct {
	SysMem          uintptr
	SysMemPitch     uint32
	SysMemSlicePitch uint32
}
type D3D11_TEXTURE2D_DESC struct {
	Width, Height, MipLevels, ArraySize uint32
	Format                              uint32
	SampleDesc                          DXGI_SAMPLE_DESC
	Usage                               uint32
	BindFlags                           uint32
	CPUAccessFlags                      uint32
	MiscFlags                           uint32
}
type D3D11_MAPPED_SUBRESOURCE struct {
	PData      uintptr
	RowPitch   uint32
	DepthPitch uint32
}

// Vertex: 3 float pos + 4 float color
type Vertex struct {
	X, Y, Z    float32
	R, G, B, A float32
}

// ============================================================
// Vulkan structures (minimal subset)
// ============================================================

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
	PPEnabledLayerNames     uintptr
	EnabledExtensionCount   uint32
	PPEnabledExtensionNames uintptr
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
	PPEnabledLayerNames     uintptr
	EnabledExtensionCount   uint32
	PPEnabledExtensionNames uintptr
	PEnabledFeatures        uintptr
}
type VkImageCreateInfo struct {
	SType                 uint32
	PNext                 uintptr
	Flags                 uint32
	ImageType             uint32
	Format                uint32
	ExtentWidth           uint32
	ExtentHeight          uint32
	ExtentDepth           uint32
	MipLevels             uint32
	ArrayLayers           uint32
	Samples               uint32
	Tiling                uint32
	Usage                 uint32
	SharingMode           uint32
	QueueFamilyIndexCount uint32
	PQueueFamilyIndices   uintptr
	InitialLayout         uint32
}
type VkMemoryRequirements struct {
	Size           uint64
	Alignment      uint64
	MemoryTypeBits uint32
	_pad           [4]byte
}
type VkMemoryAllocateInfo struct {
	SType           uint32
	PNext           uintptr
	AllocationSize  uint64
	MemoryTypeIndex uint32
	_pad            [4]byte
}
type VkImageViewCreateInfo struct {
	SType            uint32
	PNext            uintptr
	Flags            uint32
	Image            uintptr
	ViewType         uint32
	Format           uint32
	ComponentR       uint32
	ComponentG       uint32
	ComponentB       uint32
	ComponentA       uint32
	AspectMask       uint32
	BaseMipLevel     uint32
	LevelCount       uint32
	BaseArrayLayer   uint32
	LayerCount       uint32
}
type VkBufferCreateInfo struct {
	SType                 uint32
	PNext                 uintptr
	Flags                 uint32
	Size                  uint64
	Usage                 uint32
	SharingMode           uint32
	QueueFamilyIndexCount uint32
	PQueueFamilyIndices   uintptr
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
	PInputAttachments       uintptr
	ColorAttachmentCount    uint32
	PColorAttachments       *VkAttachmentReference
	PResolveAttachments     uintptr
	PDepthStencilAttachment uintptr
	PreserveAttachmentCount uint32
	PPreserveAttachments    uintptr
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
	PDependencies   uintptr
}
type VkFramebufferCreateInfo struct {
	SType           uint32
	PNext           uintptr
	Flags           uint32
	RenderPass      uintptr
	AttachmentCount uint32
	PAttachments    *uintptr
	Width           uint32
	Height          uint32
	Layers          uint32
}
type VkShaderModuleCreateInfo struct {
	SType    uint32
	PNext    uintptr
	Flags    uint32
	CodeSize uintptr
	PCode    uintptr
}
type VkPipelineShaderStageCreateInfo struct {
	SType  uint32
	PNext  uintptr
	Flags  uint32
	Stage  uint32
	Module uintptr
	PName  *byte
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
type VkViewport struct {
	X, Y, Width, Height, MinDepth, MaxDepth float32
}
type VkRect2D struct {
	OffsetX, OffsetY int32
	ExtentW, ExtentH uint32
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
	PSampleMask           uintptr
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
	PDynamicState       uintptr
	Layout              uintptr
	RenderPass          uintptr
	Subpass             uint32
	BasePipelineHandle  uintptr
	BasePipelineIndex   int32
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
	CommandPool        uintptr
	Level              uint32
	CommandBufferCount uint32
}
type VkCommandBufferBeginInfo struct {
	SType            uint32
	PNext            uintptr
	Flags            uint32
	PInheritanceInfo uintptr
}
type VkClearColorValue struct {
	Float32 [4]float32
}
type VkClearValue struct {
	Color VkClearColorValue
}
type VkRenderPassBeginInfo struct {
	SType           uint32
	PNext           uintptr
	RenderPass      uintptr
	Framebuffer     uintptr
	RenderAreaX     int32
	RenderAreaY     int32
	RenderAreaW     uint32
	RenderAreaH     uint32
	ClearValueCount uint32
	PClearValues    *VkClearValue
}
type VkBufferImageCopy struct {
	BufferOffset      uint64
	BufferRowLength   uint32
	BufferImageHeight uint32
	AspectMask        uint32
	MipLevel          uint32
	BaseArrayLayer    uint32
	LayerCount        uint32
	OffsetX           int32
	OffsetY           int32
	OffsetZ           int32
	ExtentW           uint32
	ExtentH           uint32
	ExtentD           uint32
}
type VkSubmitInfo struct {
	SType                uint32
	PNext                uintptr
	WaitSemaphoreCount   uint32
	PWaitSemaphores      uintptr
	PWaitDstStageMask    uintptr
	CommandBufferCount   uint32
	PCommandBuffers      *uintptr
	SignalSemaphoreCount uint32
	PSignalSemaphores    uintptr
}
type VkFenceCreateInfo struct {
	SType uint32
	PNext uintptr
	Flags uint32
}
type VkQueueFamilyProperties struct {
	QueueFlags                  uint32
	QueueCount                  uint32
	TimestampValidBits          uint32
	MinImageTransferGranularityW uint32
	MinImageTransferGranularityH uint32
	MinImageTransferGranularityD uint32
}
type VkPhysicalDeviceMemoryProperties struct {
	MemoryTypeCount uint32
	MemoryTypes     [32]struct {
		PropertyFlags uint32
		HeapIndex     uint32
	}
	MemoryHeapCount uint32
	MemoryHeaps     [16]struct {
		Size  uint64
		Flags uint32
		_pad  [4]byte
	}
}

// ============================================================
// DLL/proc declarations
// ============================================================

var (
	user32              = syscall.NewLazyDLL("user32.dll")
	pRegisterClassExW   = user32.NewProc("RegisterClassExW")
	pCreateWindowExW    = user32.NewProc("CreateWindowExW")
	pDefWindowProcW     = user32.NewProc("DefWindowProcW")
	pPeekMessageW       = user32.NewProc("PeekMessageW")
	pTranslateMessage   = user32.NewProc("TranslateMessage")
	pDispatchMessageW   = user32.NewProc("DispatchMessageW")
	pPostQuitMessage    = user32.NewProc("PostQuitMessage")
	pLoadCursorW        = user32.NewProc("LoadCursorW")
	pShowWindow         = user32.NewProc("ShowWindow")
	pUpdateWindow       = user32.NewProc("UpdateWindow")
	pAdjustWindowRect   = user32.NewProc("AdjustWindowRect")
	pBeginPaint         = user32.NewProc("BeginPaint")
	pEndPaint           = user32.NewProc("EndPaint")
	pGetDC              = user32.NewProc("GetDC")
	pReleaseDC          = user32.NewProc("ReleaseDC")

	kernel32            = syscall.NewLazyDLL("kernel32.dll")
	pGetModuleHandleW   = kernel32.NewProc("GetModuleHandleW")
	pOutputDebugStringW = kernel32.NewProc("OutputDebugStringW")

	gdi32                = syscall.NewLazyDLL("gdi32.dll")
	pChoosePixelFormat   = gdi32.NewProc("ChoosePixelFormat")
	pSetPixelFormat      = gdi32.NewProc("SetPixelFormat")

	opengl32             = syscall.NewLazyDLL("opengl32.dll")
	pWglCreateContext    = opengl32.NewProc("wglCreateContext")
	pWglDeleteContext    = opengl32.NewProc("wglDeleteContext")
	pWglMakeCurrent      = opengl32.NewProc("wglMakeCurrent")
	pWglGetProcAddress   = opengl32.NewProc("wglGetProcAddress")
	pGlViewport          = opengl32.NewProc("glViewport")
	pGlClearColor        = opengl32.NewProc("glClearColor")
	pGlClear             = opengl32.NewProc("glClear")
	pGlDrawArrays        = opengl32.NewProc("glDrawArrays")
	pGlFlush             = opengl32.NewProc("glFlush")

	d3d11               = syscall.NewLazyDLL("d3d11.dll")
	pD3D11CreateDevice   = d3d11.NewProc("D3D11CreateDevice")

	d3dcompiler          = syscall.NewLazyDLL("d3dcompiler_47.dll")
	pD3DCompile          = d3dcompiler.NewProc("D3DCompile")

	dcomp                         = syscall.NewLazyDLL("dcomp.dll")
	pDCompositionCreateDevice     = dcomp.NewProc("DCompositionCreateDevice")

	ole32                = syscall.NewLazyDLL("ole32.dll")
	pCoInitializeEx      = ole32.NewProc("CoInitializeEx")

	vulkan               = syscall.NewLazyDLL("vulkan-1.dll")
	pvkCreateInstance    = vulkan.NewProc("vkCreateInstance")
	pvkEnumeratePhysicalDevices = vulkan.NewProc("vkEnumeratePhysicalDevices")
	pvkGetPhysicalDeviceQueueFamilyProperties = vulkan.NewProc("vkGetPhysicalDeviceQueueFamilyProperties")
	pvkGetPhysicalDeviceMemoryProperties = vulkan.NewProc("vkGetPhysicalDeviceMemoryProperties")
	pvkCreateDevice      = vulkan.NewProc("vkCreateDevice")
	pvkGetDeviceQueue    = vulkan.NewProc("vkGetDeviceQueue")
	pvkCreateImage       = vulkan.NewProc("vkCreateImage")
	pvkGetImageMemoryRequirements = vulkan.NewProc("vkGetImageMemoryRequirements")
	pvkAllocateMemory    = vulkan.NewProc("vkAllocateMemory")
	pvkBindImageMemory   = vulkan.NewProc("vkBindImageMemory")
	pvkCreateImageView   = vulkan.NewProc("vkCreateImageView")
	pvkCreateBuffer      = vulkan.NewProc("vkCreateBuffer")
	pvkGetBufferMemoryRequirements = vulkan.NewProc("vkGetBufferMemoryRequirements")
	pvkBindBufferMemory  = vulkan.NewProc("vkBindBufferMemory")
	pvkCreateRenderPass  = vulkan.NewProc("vkCreateRenderPass")
	pvkCreateFramebuffer = vulkan.NewProc("vkCreateFramebuffer")
	pvkCreateShaderModule = vulkan.NewProc("vkCreateShaderModule")
	pvkCreatePipelineLayout = vulkan.NewProc("vkCreatePipelineLayout")
	pvkCreateGraphicsPipelines = vulkan.NewProc("vkCreateGraphicsPipelines")
	pvkDestroyShaderModule = vulkan.NewProc("vkDestroyShaderModule")
	pvkCreateCommandPool = vulkan.NewProc("vkCreateCommandPool")
	pvkAllocateCommandBuffers = vulkan.NewProc("vkAllocateCommandBuffers")
	pvkCreateFence       = vulkan.NewProc("vkCreateFence")
	pvkWaitForFences     = vulkan.NewProc("vkWaitForFences")
	pvkResetFences       = vulkan.NewProc("vkResetFences")
	pvkResetCommandBuffer = vulkan.NewProc("vkResetCommandBuffer")
	pvkBeginCommandBuffer = vulkan.NewProc("vkBeginCommandBuffer")
	pvkCmdBeginRenderPass = vulkan.NewProc("vkCmdBeginRenderPass")
	pvkCmdBindPipeline   = vulkan.NewProc("vkCmdBindPipeline")
	pvkCmdDraw           = vulkan.NewProc("vkCmdDraw")
	pvkCmdEndRenderPass  = vulkan.NewProc("vkCmdEndRenderPass")
	pvkCmdCopyImageToBuffer = vulkan.NewProc("vkCmdCopyImageToBuffer")
	pvkEndCommandBuffer  = vulkan.NewProc("vkEndCommandBuffer")
	pvkQueueSubmit       = vulkan.NewProc("vkQueueSubmit")
	pvkMapMemory         = vulkan.NewProc("vkMapMemory")
	pvkUnmapMemory       = vulkan.NewProc("vkUnmapMemory")
	pvkDeviceWaitIdle    = vulkan.NewProc("vkDeviceWaitIdle")
	pvkDestroyFence      = vulkan.NewProc("vkDestroyFence")
	pvkDestroyCommandPool = vulkan.NewProc("vkDestroyCommandPool")
	pvkDestroyPipeline   = vulkan.NewProc("vkDestroyPipeline")
	pvkDestroyPipelineLayout = vulkan.NewProc("vkDestroyPipelineLayout")
	pvkDestroyFramebuffer = vulkan.NewProc("vkDestroyFramebuffer")
	pvkDestroyRenderPass = vulkan.NewProc("vkDestroyRenderPass")
	pvkDestroyImageView  = vulkan.NewProc("vkDestroyImageView")
	pvkDestroyImage      = vulkan.NewProc("vkDestroyImage")
	pvkFreeMemory        = vulkan.NewProc("vkFreeMemory")
	pvkDestroyBuffer     = vulkan.NewProc("vkDestroyBuffer")
	pvkDestroyDevice     = vulkan.NewProc("vkDestroyDevice")
	pvkDestroyInstance   = vulkan.NewProc("vkDestroyInstance")
)

// OpenGL extension function pointers (loaded at runtime via wglGetProcAddress)
var (
	glGenBuffers              uintptr
	glBindBuffer              uintptr
	glBufferData              uintptr
	glCreateShader            uintptr
	glShaderSource            uintptr
	glCompileShader           uintptr
	glGetShaderiv             uintptr
	glCreateProgram           uintptr
	glAttachShader            uintptr
	glLinkProgram             uintptr
	glGetProgramiv            uintptr
	glUseProgram              uintptr
	glGetAttribLocation       uintptr
	glEnableVertexAttribArray uintptr
	glVertexAttribPointer     uintptr
	glGenVertexArrays         uintptr
	glBindVertexArray         uintptr
	glGenFramebuffers         uintptr
	glBindFramebuffer         uintptr
	glFramebufferRenderbuffer uintptr
	glCheckFramebufferStatus  uintptr
	glGenRenderbuffers        uintptr
	glBindRenderbuffer        uintptr
	glDeleteBuffers           uintptr
	glDeleteVertexArrays      uintptr
	glDeleteFramebuffers      uintptr
	glDeleteRenderbuffers     uintptr
	glDeleteProgram           uintptr
	wglCreateContextAttribsARB uintptr
	wglDXOpenDeviceNV         uintptr
	wglDXCloseDeviceNV        uintptr
	wglDXRegisterObjectNV     uintptr
	wglDXUnregisterObjectNV   uintptr
	wglDXLockObjectsNV        uintptr
	wglDXUnlockObjectsNV      uintptr
)

// ============================================================
// COM vtable helper
// ============================================================

// comCall invokes COM method at vtable[index] with the given args.
// The object pointer is automatically prepended as the first (this) arg.
func comCall(obj uintptr, index int, args ...uintptr) uintptr {
	vtbl := *(*uintptr)(unsafe.Pointer(obj))
	method := *(*uintptr)(unsafe.Pointer(vtbl + uintptr(index)*unsafe.Sizeof(uintptr(0))))
	all := make([]uintptr, 0, 1+len(args))
	all = append(all, obj)
	all = append(all, args...)
	ret, _, _ := syscall.SyscallN(method, all...)
	return ret
}

// comRelease calls IUnknown::Release (vtable slot 2)
func comRelease(obj uintptr) {
	if obj != 0 {
		comCall(obj, 2)
	}
}

// comQI calls IUnknown::QueryInterface (vtable slot 0)
func comQI(obj uintptr, iid *GUID, out *uintptr) uintptr {
	return comCall(obj, 0, uintptr(unsafe.Pointer(iid)), uintptr(unsafe.Pointer(out)))
}

// f32bits converts float32 to uintptr for passing via syscall
func f32bits(f float32) uintptr {
	return uintptr(math.Float32bits(f))
}

// ============================================================
// HLSL shader sources (embedded)
// ============================================================

var hlslVS = []byte("struct VSInput { float3 pos:POSITION; float4 col:COLOR; };\n" +
	"struct VSOutput{ float4 pos:SV_POSITION; float4 col:COLOR; };\n" +
	"VSOutput main(VSInput i){ VSOutput o; o.pos=float4(i.pos,1); o.col=i.col; return o; }\n\x00")

var hlslPS = []byte("struct PSInput { float4 pos:SV_POSITION; float4 col:COLOR; };\n" +
	"float4 main(PSInput i):SV_TARGET{ return i.col; }\n\x00")

// GLSL shader sources (for OpenGL panel via WGL_NV_DX_interop)
var glslVS = "#version 460 core\n" +
	"layout(location=0) in vec3 position;\n" +
	"layout(location=1) in vec3 color;\n" +
	"out vec4 vColor;\n" +
	"void main(){ vColor=vec4(color,1.0); gl_Position=vec4(position.x,-position.y,position.z,1.0); }\n\x00"

var glslPS = "#version 460 core\n" +
	"in vec4 vColor;\n" +
	"out vec4 outColor;\n" +
	"void main(){ outColor=vColor; }\n\x00"

// ============================================================
// Global state
// ============================================================

var (
	gHwnd uintptr
	gHdc  uintptr
	gHglrc uintptr

	// D3D11
	gD3dDevice  uintptr // ID3D11Device*
	gD3dCtx     uintptr // ID3D11DeviceContext*
	gSwapChain  uintptr // IDXGISwapChain1* (OpenGL panel)
	gBackBuffer uintptr // ID3D11Texture2D* (shared with GL)
	gRtv        uintptr // ID3D11RenderTargetView*
	gVs         uintptr // ID3D11VertexShader*
	gPs         uintptr // ID3D11PixelShader*
	gInputLayout uintptr // ID3D11InputLayout*
	gVb         uintptr // ID3D11Buffer*

	// D3D11 panel (center)
	gDxSwapChain uintptr
	gDxRtv       uintptr

	// Vulkan panel (right)
	gVkSwapChain  uintptr
	gVkBackBuffer uintptr // ID3D11Texture2D*
	gVkStagingTex uintptr // ID3D11Texture2D*

	// DirectComposition
	gCompositor        uintptr // IDCompositionDevice*
	gCompTarget        uintptr // IDCompositionTarget*
	gRootVisual        uintptr // IDCompositionVisual*
	gGlVisual          uintptr
	gDxVisual          uintptr
	gVkDcompVisual     uintptr

	// OpenGL objects
	gGlInteropDevice uintptr
	gGlInteropObject uintptr
	gGlVbo           [2]uint32
	gGlVao           uint32
	gGlProgram       uint32
	gGlRbo           uint32
	gGlFbo           uint32
	gGlPosAttrib     int32
	gGlColAttrib     int32

	// Vulkan objects
	gVkInstance       uintptr
	gVkPhysDev        uintptr
	gVkDevice         uintptr
	gVkQueueFamily    uint32 = 0xFFFFFFFF
	gVkQueue          uintptr
	gVkOffImage       uintptr
	gVkOffMemory      uintptr
	gVkOffView        uintptr
	gVkReadbackBuf    uintptr
	gVkReadbackMem    uintptr
	gVkRenderPass     uintptr
	gVkFramebuffer    uintptr
	gVkPipelineLayout uintptr
	gVkPipeline       uintptr
	gVkCmdPool        uintptr
	gVkCmdBuf         uintptr
	gVkFence          uintptr
)

// ============================================================
// Debug logging (OutputDebugStringW)
// ============================================================

func dbg(msg string) {
	p, _ := syscall.UTF16PtrFromString("[Go DComp] " + msg + "\n")
	pOutputDebugStringW.Call(uintptr(unsafe.Pointer(p)))
}

// ============================================================
// String helpers
// ============================================================

func mustUTF16Ptr(s string) *uint16 {
	p, _ := syscall.UTF16PtrFromString(s)
	return p
}

func cstr(s string) *byte {
	b := append([]byte(s), 0)
	return &b[0]
}

// ============================================================
// Win32 window
// ============================================================

func wndProc(hwnd uintptr, msg uint32, wparam, lparam uintptr) uintptr {
	switch msg {
	case WM_DESTROY:
		pPostQuitMessage.Call(0)
		return 0
	case WM_PAINT:
		var ps PAINTSTRUCT
		pBeginPaint.Call(hwnd, uintptr(unsafe.Pointer(&ps)))
		pEndPaint.Call(hwnd, uintptr(unsafe.Pointer(&ps)))
		return 0
	}
	ret, _, _ := pDefWindowProcW.Call(hwnd, uintptr(msg), wparam, lparam)
	return ret
}

func createAppWindow(hInst uintptr) error {
	className := mustUTF16Ptr("GoDCompTriangle")
	cursor, _, _ := pLoadCursorW.Call(0, uintptr(IDC_ARROW))

	wcx := WNDCLASSEXW{
		WndProc:    syscall.NewCallback(wndProc),
		Instance:   hInst,
		Cursor:     cursor,
		Background: 0, // No GDI background - composition handles rendering
		ClassName:  className,
	}
	wcx.Size = uint32(unsafe.Sizeof(wcx))
	pRegisterClassExW.Call(uintptr(unsafe.Pointer(&wcx)))

	style := uint32(WS_OVERLAPPEDWINDOW)
	rc := RECT{0, 0, windowW, panelH}
	pAdjustWindowRect.Call(uintptr(unsafe.Pointer(&rc)), uintptr(style), 0)

	title := mustUTF16Ptr("OpenGL + D3D11 + Vulkan via DirectComposition (Go)")
	gHwnd, _, _ = pCreateWindowExW.Call(
		WS_EX_NOREDIRECTIONBITMAP,
		uintptr(unsafe.Pointer(className)),
		uintptr(unsafe.Pointer(title)),
		uintptr(style),
		CW_USEDEFAULT, CW_USEDEFAULT,
		uintptr(rc.Right-rc.Left), uintptr(rc.Bottom-rc.Top),
		0, 0, hInst, 0,
	)
	if gHwnd == 0 {
		return syscall.GetLastError()
	}

	pShowWindow.Call(gHwnd, SW_SHOW)
	pUpdateWindow.Call(gHwnd)
	return nil
}

// ============================================================
// D3D11 initialization + swapchain + shaders
// ============================================================

// D3D11 Device vtable indices
const (
	d3dDevCreateBuffer          = 3
	d3dDevCreateRenderTargetView = 9
	d3dDevCreateInputLayout     = 11
	d3dDevCreateVertexShader    = 12
	d3dDevCreatePixelShader     = 15
	d3dDevCreateTexture2D       = 5
)

// D3D11 DeviceContext vtable indices (ID3D11DeviceChild adds 4 methods after IUnknown)
const (
	d3dCtxPSSetShader            = 9
	d3dCtxVSSetShader            = 11
	d3dCtxDraw                   = 13
	d3dCtxMap                    = 14
	d3dCtxUnmap                  = 15
	d3dCtxIASetInputLayout       = 17
	d3dCtxIASetVertexBuffers     = 18
	d3dCtxIASetPrimitiveTopology = 24
	d3dCtxOMSetRenderTargets     = 33
	d3dCtxRSSetViewports         = 44
	d3dCtxCopyResource           = 47
	d3dCtxClearRenderTargetView  = 50
)

// IDXGISwapChain vtable indices
const (
	dxgiSwapPresent   = 8
	dxgiSwapGetBuffer = 9
)

// IDXGIDevice vtable indices
const (
	dxgiDevGetAdapter = 7
)

// IDXGIObject::GetParent
const (
	dxgiObjGetParent = 6
)

// IDXGIFactory2::CreateSwapChainForComposition
const (
	dxgiFactory2CreateSwapChainForComposition = 24
)

// ID3DBlob vtable indices
const (
	blobGetBufferPointer = 3
	blobGetBufferSize    = 4
)

// IDCompositionDevice vtable indices
const (
	dcompDevCommit            = 3
	dcompDevCreateTargetForHwnd = 6
	dcompDevCreateVisual      = 7
)

// IDCompositionTarget vtable indices
const (
	dcompTargetSetRoot = 3
)

// IDCompositionVisual vtable indices
const (
	dcompVisualSetOffsetXFloat = 4
	dcompVisualSetOffsetYFloat = 6
	dcompVisualSetContent      = 15
	dcompVisualAddVisual       = 16
)

func createSwapChainForComposition(device uintptr) (uintptr, error) {
	var dxgiDevice uintptr
	hr := comQI(device, &IID_IDXGIDevice, &dxgiDevice)
	if hr != 0 {
		return 0, syscall.Errno(hr)
	}
	defer comRelease(dxgiDevice)

	var adapter uintptr
	hr = comCall(dxgiDevice, dxgiDevGetAdapter, uintptr(unsafe.Pointer(&adapter)))
	if hr != 0 {
		return 0, syscall.Errno(hr)
	}
	defer comRelease(adapter)

	var factory uintptr
	hr = comCall(adapter, dxgiObjGetParent, uintptr(unsafe.Pointer(&IID_IDXGIFactory2)), uintptr(unsafe.Pointer(&factory)))
	if hr != 0 {
		return 0, syscall.Errno(hr)
	}
	defer comRelease(factory)

	desc := DXGI_SWAP_CHAIN_DESC1{
		Width:       panelW,
		Height:      panelH,
		Format:      DXGI_FORMAT_B8G8R8A8_UNORM,
		SampleDesc:  DXGI_SAMPLE_DESC{Count: 1},
		BufferUsage: DXGI_USAGE_RENDER_TARGET_OUTPUT,
		BufferCount: 2,
		Scaling:     DXGI_SCALING_STRETCH,
		SwapEffect:  DXGI_SWAP_EFFECT_FLIP_SEQUENTIAL,
		AlphaMode:   DXGI_ALPHA_MODE_PREMULTIPLIED,
	}

	var swapChain uintptr
	hr = comCall(factory, dxgiFactory2CreateSwapChainForComposition,
		device,
		uintptr(unsafe.Pointer(&desc)),
		0, // pRestrictToOutput
		uintptr(unsafe.Pointer(&swapChain)),
	)
	if hr != 0 {
		return 0, syscall.Errno(hr)
	}
	return swapChain, nil
}

func createRenderTargetForSwapChain(swapChain uintptr) (uintptr, uintptr, error) {
	var backBuf uintptr
	hr := comCall(swapChain, dxgiSwapGetBuffer,
		0,
		uintptr(unsafe.Pointer(&IID_ID3D11Texture2D)),
		uintptr(unsafe.Pointer(&backBuf)),
	)
	if hr != 0 {
		return 0, 0, syscall.Errno(hr)
	}

	var rtv uintptr
	hr = comCall(gD3dDevice, d3dDevCreateRenderTargetView,
		backBuf, 0, uintptr(unsafe.Pointer(&rtv)))
	if hr != 0 {
		comRelease(backBuf)
		return 0, 0, syscall.Errno(hr)
	}
	return backBuf, rtv, nil
}

func compileShader(src []byte, entry, target string) (uintptr, error) {
	var blob, errBlob uintptr
	entryB := cstr(entry)
	targetB := cstr(target)
	hr, _, _ := pD3DCompile.Call(
		uintptr(unsafe.Pointer(&src[0])),
		uintptr(len(src)-1), // exclude null terminator in length
		0, 0, 0,
		uintptr(unsafe.Pointer(entryB)),
		uintptr(unsafe.Pointer(targetB)),
		D3DCOMPILE_ENABLE_STRICTNESS,
		0,
		uintptr(unsafe.Pointer(&blob)),
		uintptr(unsafe.Pointer(&errBlob)),
	)
	if errBlob != 0 {
		comRelease(errBlob)
	}
	if hr != 0 {
		return 0, syscall.Errno(hr)
	}
	return blob, nil
}

func initD3D11() error {
	dbg("InitD3D11 begin")

	featureLevel := [1]uint32{D3D_FEATURE_LEVEL_11_0}
	var flOut uint32
	hr, _, _ := pD3D11CreateDevice.Call(
		0, D3D_DRIVER_TYPE_HARDWARE, 0,
		D3D11_CREATE_DEVICE_BGRA_SUPPORT,
		uintptr(unsafe.Pointer(&featureLevel[0])), 1,
		D3D11_SDK_VERSION,
		uintptr(unsafe.Pointer(&gD3dDevice)),
		uintptr(unsafe.Pointer(&flOut)),
		uintptr(unsafe.Pointer(&gD3dCtx)),
	)
	if hr != 0 {
		return syscall.Errno(hr)
	}
	dbg("D3D11 device created")

	// Create swap chain for GL panel
	var err error
	gSwapChain, err = createSwapChainForComposition(gD3dDevice)
	if err != nil {
		return err
	}
	dbg("SwapChain (GL panel) created")

	// Get back buffer (keep alive for WGL_NV_DX_interop registration)
	gBackBuffer, gRtv, err = createRenderTargetForSwapChain(gSwapChain)
	if err != nil {
		return err
	}
	// Do NOT release gBackBuffer here; GL interop needs it

	// Compile vertex shader
	vsBlob, err := compileShader(hlslVS, "main", "vs_4_0")
	if err != nil {
		return err
	}
	defer comRelease(vsBlob)

	vsBufPtr := comCall(vsBlob, blobGetBufferPointer)
	vsBufSize := comCall(vsBlob, blobGetBufferSize)

	hr2 := comCall(gD3dDevice, d3dDevCreateVertexShader,
		vsBufPtr, vsBufSize, 0,
		uintptr(unsafe.Pointer(&gVs)))
	if hr2 != 0 {
		return syscall.Errno(hr2)
	}

	// Compile pixel shader
	psBlob, err := compileShader(hlslPS, "main", "ps_4_0")
	if err != nil {
		return err
	}
	defer comRelease(psBlob)

	psBufPtr := comCall(psBlob, blobGetBufferPointer)
	psBufSize := comCall(psBlob, blobGetBufferSize)

	hr2 = comCall(gD3dDevice, d3dDevCreatePixelShader,
		psBufPtr, psBufSize, 0,
		uintptr(unsafe.Pointer(&gPs)))
	if hr2 != 0 {
		return syscall.Errno(hr2)
	}

	// Input layout
	posName := cstr("POSITION")
	colName := cstr("COLOR")
	layout := [2]D3D11_INPUT_ELEMENT_DESC{
		{SemanticName: posName, Format: DXGI_FORMAT_R32G32B32_FLOAT, AlignedByteOffset: 0},
		{SemanticName: colName, Format: DXGI_FORMAT_R32G32B32A32_FLOAT, AlignedByteOffset: 12},
	}

	hr2 = comCall(gD3dDevice, d3dDevCreateInputLayout,
		uintptr(unsafe.Pointer(&layout[0])), 2,
		vsBufPtr, vsBufSize,
		uintptr(unsafe.Pointer(&gInputLayout)))
	if hr2 != 0 {
		return syscall.Errno(hr2)
	}

	// Vertex buffer (shared by D3D11 panels)
	verts := [3]Vertex{
		{0.0, 0.5, 0.5, 1.0, 0.0, 0.0, 1.0},
		{0.5, -0.5, 0.5, 0.0, 1.0, 0.0, 1.0},
		{-0.5, -0.5, 0.5, 0.0, 0.0, 1.0, 1.0},
	}

	bd := D3D11_BUFFER_DESC{
		ByteWidth: uint32(unsafe.Sizeof(verts)),
		Usage:     D3D11_USAGE_DEFAULT,
		BindFlags: D3D11_BIND_VERTEX_BUFFER,
	}
	initData := D3D11_SUBRESOURCE_DATA{SysMem: uintptr(unsafe.Pointer(&verts[0]))}

	hr2 = comCall(gD3dDevice, d3dDevCreateBuffer,
		uintptr(unsafe.Pointer(&bd)),
		uintptr(unsafe.Pointer(&initData)),
		uintptr(unsafe.Pointer(&gVb)))
	if hr2 != 0 {
		return syscall.Errno(hr2)
	}

	dbg("InitD3D11 ok")
	return nil
}

// ============================================================
// OpenGL initialization (WGL_NV_DX_interop)
// ============================================================

func getGLProc(name string) uintptr {
	b := cstr(name)
	ret, _, _ := pWglGetProcAddress.Call(uintptr(unsafe.Pointer(b)))
	return ret
}

func loadGLExtensions() error {
	glGenBuffers = getGLProc("glGenBuffers")
	glBindBuffer = getGLProc("glBindBuffer")
	glBufferData = getGLProc("glBufferData")
	glCreateShader = getGLProc("glCreateShader")
	glShaderSource = getGLProc("glShaderSource")
	glCompileShader = getGLProc("glCompileShader")
	glGetShaderiv = getGLProc("glGetShaderiv")
	glCreateProgram = getGLProc("glCreateProgram")
	glAttachShader = getGLProc("glAttachShader")
	glLinkProgram = getGLProc("glLinkProgram")
	glGetProgramiv = getGLProc("glGetProgramiv")
	glUseProgram = getGLProc("glUseProgram")
	glGetAttribLocation = getGLProc("glGetAttribLocation")
	glEnableVertexAttribArray = getGLProc("glEnableVertexAttribArray")
	glVertexAttribPointer = getGLProc("glVertexAttribPointer")
	glGenVertexArrays = getGLProc("glGenVertexArrays")
	glBindVertexArray = getGLProc("glBindVertexArray")
	glGenFramebuffers = getGLProc("glGenFramebuffers")
	glBindFramebuffer = getGLProc("glBindFramebuffer")
	glFramebufferRenderbuffer = getGLProc("glFramebufferRenderbuffer")
	glCheckFramebufferStatus = getGLProc("glCheckFramebufferStatus")
	glGenRenderbuffers = getGLProc("glGenRenderbuffers")
	glBindRenderbuffer = getGLProc("glBindRenderbuffer")
	glDeleteBuffers = getGLProc("glDeleteBuffers")
	glDeleteVertexArrays = getGLProc("glDeleteVertexArrays")
	glDeleteFramebuffers = getGLProc("glDeleteFramebuffers")
	glDeleteRenderbuffers = getGLProc("glDeleteRenderbuffers")
	glDeleteProgram = getGLProc("glDeleteProgram")

	wglCreateContextAttribsARB = getGLProc("wglCreateContextAttribsARB")
	wglDXOpenDeviceNV = getGLProc("wglDXOpenDeviceNV")
	wglDXCloseDeviceNV = getGLProc("wglDXCloseDeviceNV")
	wglDXRegisterObjectNV = getGLProc("wglDXRegisterObjectNV")
	wglDXUnregisterObjectNV = getGLProc("wglDXUnregisterObjectNV")
	wglDXLockObjectsNV = getGLProc("wglDXLockObjectsNV")
	wglDXUnlockObjectsNV = getGLProc("wglDXUnlockObjectsNV")

	if wglDXOpenDeviceNV == 0 {
		return syscall.EINVAL
	}
	return nil
}

func initOpenGL() error {
	dbg("InitOpenGL begin")

	gHdc, _, _ = pGetDC.Call(gHwnd)
	if gHdc == 0 {
		return syscall.EINVAL
	}

	// Set pixel format
	pfd := PIXELFORMATDESCRIPTOR{
		Flags:      PFD_DRAW_TO_WINDOW | PFD_SUPPORT_OPENGL | PFD_DOUBLEBUFFER,
		PixelType:  PFD_TYPE_RGBA,
		ColorBits:  32,
		DepthBits:  24,
		LayerType:  PFD_MAIN_PLANE,
	}
	pfd.Size = uint16(unsafe.Sizeof(pfd))
	pfd.Version = 1

	pf, _, _ := pChoosePixelFormat.Call(gHdc, uintptr(unsafe.Pointer(&pfd)))
	pSetPixelFormat.Call(gHdc, pf, uintptr(unsafe.Pointer(&pfd)))

	// Create legacy context first to load extensions
	legacyRC, _, _ := pWglCreateContext.Call(gHdc)
	if legacyRC == 0 {
		return syscall.EINVAL
	}
	pWglMakeCurrent.Call(gHdc, legacyRC)

	// Load wglCreateContextAttribsARB
	wglCreateContextAttribsARB = getGLProc("wglCreateContextAttribsARB")

	if wglCreateContextAttribsARB != 0 {
		// Create OpenGL 4.6 core context
		attrs := [...]int32{
			WGL_CONTEXT_MAJOR_VERSION_ARB, 4,
			WGL_CONTEXT_MINOR_VERSION_ARB, 6,
			WGL_CONTEXT_FLAGS_ARB, 0,
			WGL_CONTEXT_PROFILE_MASK_ARB, WGL_CONTEXT_CORE_PROFILE_BIT_ARB,
			0,
		}
		rc, _, _ := syscall.SyscallN(wglCreateContextAttribsARB,
			gHdc, 0, uintptr(unsafe.Pointer(&attrs[0])))
		if rc != 0 {
			pWglMakeCurrent.Call(gHdc, rc)
			pWglDeleteContext.Call(legacyRC)
			gHglrc = rc
		} else {
			gHglrc = legacyRC
		}
	} else {
		gHglrc = legacyRC
	}

	// Load GL extensions
	if err := loadGLExtensions(); err != nil {
		return err
	}

	// Open NV interop device
	gGlInteropDevice, _, _ = syscall.SyscallN(wglDXOpenDeviceNV, gD3dDevice)
	if gGlInteropDevice == 0 {
		dbg("wglDXOpenDeviceNV failed")
		return syscall.EINVAL
	}

	// Create renderbuffer and register with NV interop
	syscall.SyscallN(glGenRenderbuffers, 1, uintptr(unsafe.Pointer(&gGlRbo)))
	syscall.SyscallN(glBindRenderbuffer, GL_RENDERBUFFER, uintptr(gGlRbo))

	gGlInteropObject, _, _ = syscall.SyscallN(wglDXRegisterObjectNV,
		gGlInteropDevice, gBackBuffer,
		uintptr(gGlRbo), GL_RENDERBUFFER, WGL_ACCESS_READ_WRITE_NV)
	if gGlInteropObject == 0 {
		dbg("wglDXRegisterObjectNV failed")
		return syscall.EINVAL
	}

	// Create FBO and attach renderbuffer
	syscall.SyscallN(glGenFramebuffers, 1, uintptr(unsafe.Pointer(&gGlFbo)))
	syscall.SyscallN(glBindFramebuffer, GL_FRAMEBUFFER, uintptr(gGlFbo))
	syscall.SyscallN(glFramebufferRenderbuffer,
		GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, uintptr(gGlRbo))
	status, _, _ := syscall.SyscallN(glCheckFramebufferStatus, GL_FRAMEBUFFER)
	syscall.SyscallN(glBindFramebuffer, GL_FRAMEBUFFER, 0)
	if uint32(status) != GL_FRAMEBUFFER_COMPLETE {
		dbg("FBO incomplete")
		return syscall.EINVAL
	}

	// Create VAO, VBOs
	syscall.SyscallN(glGenVertexArrays, 1, uintptr(unsafe.Pointer(&gGlVao)))
	syscall.SyscallN(glBindVertexArray, uintptr(gGlVao))

	syscall.SyscallN(glGenBuffers, 2, uintptr(unsafe.Pointer(&gGlVbo[0])))

	// Position data
	positions := [9]float32{
		-0.5, -0.5, 0.0,
		0.5, -0.5, 0.0,
		0.0, 0.5, 0.0,
	}
	syscall.SyscallN(glBindBuffer, GL_ARRAY_BUFFER, uintptr(gGlVbo[0]))
	syscall.SyscallN(glBufferData, GL_ARRAY_BUFFER,
		uintptr(unsafe.Sizeof(positions)),
		uintptr(unsafe.Pointer(&positions[0])),
		GL_STATIC_DRAW)

	// Color data
	colors := [9]float32{
		0.0, 0.0, 1.0,
		0.0, 1.0, 0.0,
		1.0, 0.0, 0.0,
	}
	syscall.SyscallN(glBindBuffer, GL_ARRAY_BUFFER, uintptr(gGlVbo[1]))
	syscall.SyscallN(glBufferData, GL_ARRAY_BUFFER,
		uintptr(unsafe.Sizeof(colors)),
		uintptr(unsafe.Pointer(&colors[0])),
		GL_STATIC_DRAW)

	// Compile GL shaders
	vs := compileGLShader(GL_VERTEX_SHADER, glslVS)
	fs := compileGLShader(GL_FRAGMENT_SHADER, glslPS)
	if vs == 0 || fs == 0 {
		dbg("GL shader compile failed")
		return syscall.EINVAL
	}

	prog, _, _ := syscall.SyscallN(glCreateProgram)
	syscall.SyscallN(glAttachShader, prog, vs)
	syscall.SyscallN(glAttachShader, prog, fs)
	syscall.SyscallN(glLinkProgram, prog)

	var linkOk int32
	syscall.SyscallN(glGetProgramiv, prog, GL_LINK_STATUS, uintptr(unsafe.Pointer(&linkOk)))
	if linkOk == 0 {
		dbg("GL program link failed")
		return syscall.EINVAL
	}
	gGlProgram = uint32(prog)

	syscall.SyscallN(glUseProgram, prog)

	posAttrName := cstr("position")
	colAttrName := cstr("color")
	pa, _, _ := syscall.SyscallN(glGetAttribLocation, prog, uintptr(unsafe.Pointer(posAttrName)))
	ca, _, _ := syscall.SyscallN(glGetAttribLocation, prog, uintptr(unsafe.Pointer(colAttrName)))
	gGlPosAttrib = int32(pa)
	gGlColAttrib = int32(ca)

	syscall.SyscallN(glEnableVertexAttribArray, uintptr(gGlPosAttrib))
	syscall.SyscallN(glEnableVertexAttribArray, uintptr(gGlColAttrib))

	dbg("InitOpenGL ok")
	return nil
}

func compileGLShader(shaderType uint32, src string) uintptr {
	shader, _, _ := syscall.SyscallN(glCreateShader, uintptr(shaderType))
	srcPtr := cstr(src)
	syscall.SyscallN(glShaderSource, shader, 1,
		uintptr(unsafe.Pointer(&srcPtr)), 0)
	syscall.SyscallN(glCompileShader, shader)

	var ok int32
	syscall.SyscallN(glGetShaderiv, shader, GL_COMPILE_STATUS, uintptr(unsafe.Pointer(&ok)))
	if ok == 0 {
		return 0
	}
	return shader
}

// ============================================================
// D3D11 second panel (center)
// ============================================================

func initD3D11SecondPanel() error {
	dbg("InitD3D11SecondPanel begin")

	var err error
	gDxSwapChain, err = createSwapChainForComposition(gD3dDevice)
	if err != nil {
		return err
	}

	_, gDxRtv, err = createRenderTargetForSwapChain(gDxSwapChain)
	if err != nil {
		return err
	}

	dbg("InitD3D11SecondPanel ok")
	return nil
}

// ============================================================
// Vulkan panel (right) - offscreen render -> D3D11 staging copy
// ============================================================

func vkFindMemoryType(typeBits uint32, props uint32) uint32 {
	var mp VkPhysicalDeviceMemoryProperties
	pvkGetPhysicalDeviceMemoryProperties.Call(gVkPhysDev, uintptr(unsafe.Pointer(&mp)))
	for i := uint32(0); i < mp.MemoryTypeCount; i++ {
		if (typeBits&(1<<i)) != 0 && (mp.MemoryTypes[i].PropertyFlags&props) == props {
			return i
		}
	}
	return 0xFFFFFFFF
}

func initVulkanPanel() error {
	dbg("InitVulkanPanel begin")

	// Create swap chain for Vulkan panel
	var err error
	gVkSwapChain, err = createSwapChainForComposition(gD3dDevice)
	if err != nil {
		return err
	}

	// Get back buffer + create staging texture
	var backBuf uintptr
	hr := comCall(gVkSwapChain, dxgiSwapGetBuffer,
		0, uintptr(unsafe.Pointer(&IID_ID3D11Texture2D)),
		uintptr(unsafe.Pointer(&backBuf)))
	if hr != 0 {
		return syscall.Errno(hr)
	}
	gVkBackBuffer = backBuf

	td := D3D11_TEXTURE2D_DESC{
		Width: panelW, Height: panelH,
		MipLevels: 1, ArraySize: 1,
		Format:     DXGI_FORMAT_B8G8R8A8_UNORM,
		SampleDesc: DXGI_SAMPLE_DESC{Count: 1},
		Usage:      D3D11_USAGE_STAGING,
		CPUAccessFlags: D3D11_CPU_ACCESS_WRITE,
	}
	hr = comCall(gD3dDevice, d3dDevCreateTexture2D,
		uintptr(unsafe.Pointer(&td)), 0,
		uintptr(unsafe.Pointer(&gVkStagingTex)))
	if hr != 0 {
		return syscall.Errno(hr)
	}

	// Create Vulkan instance
	appName := cstr("triangle_multi_vk_panel")
	ai := VkApplicationInfo{
		SType:            VK_STRUCTURE_TYPE_APPLICATION_INFO,
		PApplicationName: appName,
		ApiVersion:       (1 << 22) | (4 << 12), // VK_API_VERSION_1_4
	}
	ici := VkInstanceCreateInfo{
		SType:            VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
		PApplicationInfo: &ai,
	}
	vr, _, _ := pvkCreateInstance.Call(
		uintptr(unsafe.Pointer(&ici)), 0,
		uintptr(unsafe.Pointer(&gVkInstance)))
	if int32(vr) != VK_SUCCESS {
		return syscall.EINVAL
	}

	// Enumerate physical devices
	var devCount uint32
	pvkEnumeratePhysicalDevices.Call(gVkInstance, uintptr(unsafe.Pointer(&devCount)), 0)
	if devCount == 0 {
		return syscall.EINVAL
	}
	devs := make([]uintptr, devCount)
	pvkEnumeratePhysicalDevices.Call(gVkInstance, uintptr(unsafe.Pointer(&devCount)),
		uintptr(unsafe.Pointer(&devs[0])))

	// Find a queue family with graphics support
	for _, dev := range devs {
		var qc uint32
		pvkGetPhysicalDeviceQueueFamilyProperties.Call(dev, uintptr(unsafe.Pointer(&qc)), 0)
		if qc == 0 {
			continue
		}
		qprops := make([]VkQueueFamilyProperties, qc)
		pvkGetPhysicalDeviceQueueFamilyProperties.Call(dev, uintptr(unsafe.Pointer(&qc)),
			uintptr(unsafe.Pointer(&qprops[0])))
		for i := uint32(0); i < qc; i++ {
			if qprops[i].QueueFlags&VK_QUEUE_GRAPHICS_BIT != 0 {
				gVkPhysDev = dev
				gVkQueueFamily = i
				break
			}
		}
		if gVkPhysDev != 0 {
			break
		}
	}
	if gVkPhysDev == 0 {
		return syscall.EINVAL
	}

	// Create logical device
	prio := float32(1.0)
	qci := VkDeviceQueueCreateInfo{
		SType:            VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
		QueueFamilyIndex: gVkQueueFamily,
		QueueCount:       1,
		PQueuePriorities: &prio,
	}
	dci := VkDeviceCreateInfo{
		SType:                VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO,
		QueueCreateInfoCount: 1,
		PQueueCreateInfos:    &qci,
	}
	vr, _, _ = pvkCreateDevice.Call(gVkPhysDev, uintptr(unsafe.Pointer(&dci)), 0,
		uintptr(unsafe.Pointer(&gVkDevice)))
	if int32(vr) != VK_SUCCESS {
		return syscall.EINVAL
	}
	pvkGetDeviceQueue.Call(gVkDevice, uintptr(gVkQueueFamily), 0,
		uintptr(unsafe.Pointer(&gVkQueue)))

	// Create offscreen image
	imgci := VkImageCreateInfo{
		SType:       VK_STRUCTURE_TYPE_IMAGE_CREATE_INFO,
		ImageType:   VK_IMAGE_TYPE_2D,
		Format:      VK_FORMAT_B8G8R8A8_UNORM,
		ExtentWidth: panelW, ExtentHeight: panelH, ExtentDepth: 1,
		MipLevels: 1, ArrayLayers: 1,
		Samples:       VK_SAMPLE_COUNT_1_BIT,
		Tiling:        VK_IMAGE_TILING_OPTIMAL,
		Usage:         VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT | VK_IMAGE_USAGE_TRANSFER_SRC_BIT,
		InitialLayout: VK_IMAGE_LAYOUT_UNDEFINED,
	}
	vr, _, _ = pvkCreateImage.Call(gVkDevice, uintptr(unsafe.Pointer(&imgci)), 0,
		uintptr(unsafe.Pointer(&gVkOffImage)))
	if int32(vr) != VK_SUCCESS {
		return syscall.EINVAL
	}

	var mr VkMemoryRequirements
	pvkGetImageMemoryRequirements.Call(gVkDevice, gVkOffImage, uintptr(unsafe.Pointer(&mr)))
	mai := VkMemoryAllocateInfo{
		SType:           VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
		AllocationSize:  mr.Size,
		MemoryTypeIndex: vkFindMemoryType(mr.MemoryTypeBits, VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT),
	}
	vr, _, _ = pvkAllocateMemory.Call(gVkDevice, uintptr(unsafe.Pointer(&mai)), 0,
		uintptr(unsafe.Pointer(&gVkOffMemory)))
	if int32(vr) != VK_SUCCESS {
		return syscall.EINVAL
	}
	pvkBindImageMemory.Call(gVkDevice, gVkOffImage, gVkOffMemory, 0)

	// Image view
	ivci := VkImageViewCreateInfo{
		SType:    VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO,
		Image:    gVkOffImage,
		ViewType: VK_IMAGE_VIEW_TYPE_2D,
		Format:   VK_FORMAT_B8G8R8A8_UNORM,
		AspectMask: VK_IMAGE_ASPECT_COLOR_BIT,
		LevelCount: 1, LayerCount: 1,
	}
	vr, _, _ = pvkCreateImageView.Call(gVkDevice, uintptr(unsafe.Pointer(&ivci)), 0,
		uintptr(unsafe.Pointer(&gVkOffView)))
	if int32(vr) != VK_SUCCESS {
		return syscall.EINVAL
	}

	// Readback buffer
	bci := VkBufferCreateInfo{
		SType: VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO,
		Size:  uint64(panelW) * uint64(panelH) * 4,
		Usage: VK_BUFFER_USAGE_TRANSFER_DST_BIT,
	}
	vr, _, _ = pvkCreateBuffer.Call(gVkDevice, uintptr(unsafe.Pointer(&bci)), 0,
		uintptr(unsafe.Pointer(&gVkReadbackBuf)))
	if int32(vr) != VK_SUCCESS {
		return syscall.EINVAL
	}
	pvkGetBufferMemoryRequirements.Call(gVkDevice, gVkReadbackBuf, uintptr(unsafe.Pointer(&mr)))
	mai2 := VkMemoryAllocateInfo{
		SType:           VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
		AllocationSize:  mr.Size,
		MemoryTypeIndex: vkFindMemoryType(mr.MemoryTypeBits, VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT|VK_MEMORY_PROPERTY_HOST_COHERENT_BIT),
	}
	vr, _, _ = pvkAllocateMemory.Call(gVkDevice, uintptr(unsafe.Pointer(&mai2)), 0,
		uintptr(unsafe.Pointer(&gVkReadbackMem)))
	if int32(vr) != VK_SUCCESS {
		return syscall.EINVAL
	}
	pvkBindBufferMemory.Call(gVkDevice, gVkReadbackBuf, gVkReadbackMem, 0)

	// Render pass
	att := VkAttachmentDescription{
		Format:         VK_FORMAT_B8G8R8A8_UNORM,
		Samples:        VK_SAMPLE_COUNT_1_BIT,
		LoadOp:         VK_ATTACHMENT_LOAD_OP_CLEAR,
		StoreOp:        VK_ATTACHMENT_STORE_OP_STORE,
		StencilLoadOp:  VK_ATTACHMENT_LOAD_OP_DONT_CARE,
		StencilStoreOp: VK_ATTACHMENT_STORE_OP_DONT_CARE,
		InitialLayout:  VK_IMAGE_LAYOUT_UNDEFINED,
		FinalLayout:    VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL,
	}
	aref := VkAttachmentReference{Attachment: 0, Layout: VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL}
	sub := VkSubpassDescription{
		PipelineBindPoint:    VK_PIPELINE_BIND_POINT_GRAPHICS,
		ColorAttachmentCount: 1,
		PColorAttachments:    &aref,
	}
	rpci := VkRenderPassCreateInfo{
		SType:           VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO,
		AttachmentCount: 1, PAttachments: &att,
		SubpassCount: 1, PSubpasses: &sub,
	}
	vr, _, _ = pvkCreateRenderPass.Call(gVkDevice, uintptr(unsafe.Pointer(&rpci)), 0,
		uintptr(unsafe.Pointer(&gVkRenderPass)))
	if int32(vr) != VK_SUCCESS {
		return syscall.EINVAL
	}

	// Framebuffer
	attachments := [1]uintptr{gVkOffView}
	fbci := VkFramebufferCreateInfo{
		SType:           VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO,
		RenderPass:      gVkRenderPass,
		AttachmentCount: 1,
		PAttachments:    &attachments[0],
		Width:           panelW, Height: panelH, Layers: 1,
	}
	vr, _, _ = pvkCreateFramebuffer.Call(gVkDevice, uintptr(unsafe.Pointer(&fbci)), 0,
		uintptr(unsafe.Pointer(&gVkFramebuffer)))
	if int32(vr) != VK_SUCCESS {
		return syscall.EINVAL
	}

	// Load SPIR-V shaders from files
	vsSpv, err2 := os.ReadFile("hello_vert.spv")
	if err2 != nil {
		dbg("Failed to read hello_vert.spv")
		return err2
	}
	fsSpv, err2 := os.ReadFile("hello_frag.spv")
	if err2 != nil {
		dbg("Failed to read hello_frag.spv")
		return err2
	}

	// Create shader modules
	var vsMod, fsMod uintptr
	smci := VkShaderModuleCreateInfo{
		SType:    VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO,
		CodeSize: uintptr(len(vsSpv)),
		PCode:    uintptr(unsafe.Pointer(&vsSpv[0])),
	}
	vr, _, _ = pvkCreateShaderModule.Call(gVkDevice, uintptr(unsafe.Pointer(&smci)), 0,
		uintptr(unsafe.Pointer(&vsMod)))
	if int32(vr) != VK_SUCCESS {
		return syscall.EINVAL
	}
	smci.CodeSize = uintptr(len(fsSpv))
	smci.PCode = uintptr(unsafe.Pointer(&fsSpv[0]))
	vr, _, _ = pvkCreateShaderModule.Call(gVkDevice, uintptr(unsafe.Pointer(&smci)), 0,
		uintptr(unsafe.Pointer(&fsMod)))
	if int32(vr) != VK_SUCCESS {
		return syscall.EINVAL
	}

	// Pipeline
	mainName := cstr("main")
	stages := [2]VkPipelineShaderStageCreateInfo{
		{SType: VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
			Stage: VK_SHADER_STAGE_VERTEX_BIT, Module: vsMod, PName: mainName},
		{SType: VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
			Stage: VK_SHADER_STAGE_FRAGMENT_BIT, Module: fsMod, PName: mainName},
	}
	vi := VkPipelineVertexInputStateCreateInfo{SType: VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO}
	ia := VkPipelineInputAssemblyStateCreateInfo{
		SType: VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO,
		Topology: VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST,
	}
	vp := VkViewport{Width: panelW, Height: panelH, MaxDepth: 1.0}
	sc := VkRect2D{ExtentW: panelW, ExtentH: panelH}
	vps := VkPipelineViewportStateCreateInfo{
		SType: VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO,
		ViewportCount: 1, PViewports: &vp,
		ScissorCount: 1, PScissors: &sc,
	}
	rs := VkPipelineRasterizationStateCreateInfo{
		SType:       VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO,
		PolygonMode: VK_POLYGON_MODE_FILL,
		CullMode:    VK_CULL_MODE_BACK_BIT,
		FrontFace:   VK_FRONT_FACE_CLOCKWISE,
		LineWidth:   1.0,
	}
	ms := VkPipelineMultisampleStateCreateInfo{
		SType:                VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO,
		RasterizationSamples: VK_SAMPLE_COUNT_1_BIT,
	}
	cba := VkPipelineColorBlendAttachmentState{ColorWriteMask: 0xF}
	cbs := VkPipelineColorBlendStateCreateInfo{
		SType:           VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO,
		AttachmentCount: 1, PAttachments: &cba,
	}
	plci := VkPipelineLayoutCreateInfo{SType: VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO}
	vr, _, _ = pvkCreatePipelineLayout.Call(gVkDevice, uintptr(unsafe.Pointer(&plci)), 0,
		uintptr(unsafe.Pointer(&gVkPipelineLayout)))
	if int32(vr) != VK_SUCCESS {
		return syscall.EINVAL
	}

	gpci := VkGraphicsPipelineCreateInfo{
		SType:               VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO,
		StageCount:          2,
		PStages:             &stages[0],
		PVertexInputState:   &vi,
		PInputAssemblyState: &ia,
		PViewportState:      &vps,
		PRasterizationState: &rs,
		PMultisampleState:   &ms,
		PColorBlendState:    &cbs,
		Layout:              gVkPipelineLayout,
		RenderPass:          gVkRenderPass,
		BasePipelineIndex:   -1,
	}
	vr, _, _ = pvkCreateGraphicsPipelines.Call(gVkDevice, 0, 1,
		uintptr(unsafe.Pointer(&gpci)), 0,
		uintptr(unsafe.Pointer(&gVkPipeline)))
	if int32(vr) != VK_SUCCESS {
		return syscall.EINVAL
	}

	// Command pool + buffer + fence
	cpci := VkCommandPoolCreateInfo{
		SType:            VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO,
		Flags:            VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT,
		QueueFamilyIndex: gVkQueueFamily,
	}
	vr, _, _ = pvkCreateCommandPool.Call(gVkDevice, uintptr(unsafe.Pointer(&cpci)), 0,
		uintptr(unsafe.Pointer(&gVkCmdPool)))
	if int32(vr) != VK_SUCCESS {
		return syscall.EINVAL
	}

	cbai := VkCommandBufferAllocateInfo{
		SType:              VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
		CommandPool:        gVkCmdPool,
		Level:              VK_COMMAND_BUFFER_LEVEL_PRIMARY,
		CommandBufferCount: 1,
	}
	vr, _, _ = pvkAllocateCommandBuffers.Call(gVkDevice, uintptr(unsafe.Pointer(&cbai)),
		uintptr(unsafe.Pointer(&gVkCmdBuf)))
	if int32(vr) != VK_SUCCESS {
		return syscall.EINVAL
	}

	fci := VkFenceCreateInfo{
		SType: VK_STRUCTURE_TYPE_FENCE_CREATE_INFO,
		Flags: VK_FENCE_CREATE_SIGNALED_BIT,
	}
	vr, _, _ = pvkCreateFence.Call(gVkDevice, uintptr(unsafe.Pointer(&fci)), 0,
		uintptr(unsafe.Pointer(&gVkFence)))
	if int32(vr) != VK_SUCCESS {
		return syscall.EINVAL
	}

	// Cleanup shader modules (no longer needed after pipeline creation)
	pvkDestroyShaderModule.Call(gVkDevice, vsMod, 0)
	pvkDestroyShaderModule.Call(gVkDevice, fsMod, 0)

	dbg("InitVulkanPanel ok")
	return nil
}

// ============================================================
// DirectComposition setup
// ============================================================

func initComposition() error {
	dbg("InitComposition begin")

	// CoInitializeEx (STA)
	pCoInitializeEx.Call(0, 2) // COINIT_APARTMENTTHREADED = 2

	// Get IDXGIDevice from D3D11 device
	var dxgiDevice uintptr
	hr := comQI(gD3dDevice, &IID_IDXGIDevice, &dxgiDevice)
	if hr != 0 {
		return syscall.Errno(hr)
	}
	defer comRelease(dxgiDevice)

	// Create IDCompositionDevice
	r, _, _ := pDCompositionCreateDevice.Call(
		dxgiDevice,
		uintptr(unsafe.Pointer(&IID_IDCompositionDevice)),
		uintptr(unsafe.Pointer(&gCompositor)),
	)
	if r != 0 {
		return syscall.Errno(r)
	}
	dbg("IDCompositionDevice created")

	// Create target for HWND
	hr = comCall(gCompositor, dcompDevCreateTargetForHwnd,
		gHwnd, 1, // topmost = TRUE
		uintptr(unsafe.Pointer(&gCompTarget)))
	if hr != 0 {
		return syscall.Errno(hr)
	}

	// Create root visual
	hr = comCall(gCompositor, dcompDevCreateVisual,
		uintptr(unsafe.Pointer(&gRootVisual)))
	if hr != 0 {
		return syscall.Errno(hr)
	}

	// Set root
	hr = comCall(gCompTarget, dcompTargetSetRoot, gRootVisual)
	if hr != 0 {
		return syscall.Errno(hr)
	}

	// Add OpenGL panel visual (left, offset 0)
	gGlVisual = addSwapChainVisual(gSwapChain, 0.0)

	// Add D3D11 panel visual (center, offset panelW)
	gDxVisual = addSwapChainVisual(gDxSwapChain, float32(panelW))

	// Add Vulkan panel visual (right, offset panelW*2)
	gVkDcompVisual = addSwapChainVisual(gVkSwapChain, float32(panelW*2))

	// Commit
	hr = comCall(gCompositor, dcompDevCommit)
	if hr != 0 {
		return syscall.Errno(hr)
	}

	dbg("InitComposition ok")
	return nil
}

func addSwapChainVisual(swapChain uintptr, offsetX float32) uintptr {
	var visual uintptr
	comCall(gCompositor, dcompDevCreateVisual, uintptr(unsafe.Pointer(&visual)))
	comCall(visual, dcompVisualSetOffsetXFloat, f32bits(offsetX))
	comCall(visual, dcompVisualSetOffsetYFloat, f32bits(float32(0.0)))
	comCall(visual, dcompVisualSetContent, swapChain)
	comCall(gRootVisual, dcompVisualAddVisual, visual, 1, 0) // insertAbove=TRUE
	return visual
}

// ============================================================
// Render functions
// ============================================================

func renderOpenGLPanel() {
	if gGlInteropDevice == 0 || gGlInteropObject == 0 {
		return
	}

	pWglMakeCurrent.Call(gHdc, gHglrc)

	// Lock D3D11 back buffer for GL access
	objs := [1]uintptr{gGlInteropObject}
	r, _, _ := syscall.SyscallN(wglDXLockObjectsNV, gGlInteropDevice, 1,
		uintptr(unsafe.Pointer(&objs[0])))
	if r == 0 {
		return
	}

	// Render into FBO
	syscall.SyscallN(glBindFramebuffer, GL_FRAMEBUFFER, uintptr(gGlFbo))
	pGlViewport.Call(0, 0, panelW, panelH)

	// Clear with dark blue background
	pGlClearColor.Call(f32bits(0.05), f32bits(0.05), f32bits(0.15), f32bits(1.0))
	pGlClear.Call(GL_COLOR_BUFFER_BIT)

	// Draw triangle
	syscall.SyscallN(glUseProgram, uintptr(gGlProgram))
	syscall.SyscallN(glBindBuffer, GL_ARRAY_BUFFER, uintptr(gGlVbo[0]))
	syscall.SyscallN(glVertexAttribPointer,
		uintptr(gGlPosAttrib), 3, GL_FLOAT, GL_FALSE, 0, 0)
	syscall.SyscallN(glBindBuffer, GL_ARRAY_BUFFER, uintptr(gGlVbo[1]))
	syscall.SyscallN(glVertexAttribPointer,
		uintptr(gGlColAttrib), 3, GL_FLOAT, GL_FALSE, 0, 0)
	pGlDrawArrays.Call(GL_TRIANGLES, 0, 3)
	pGlFlush.Call()

	syscall.SyscallN(glBindFramebuffer, GL_FRAMEBUFFER, 0)

	// Unlock and present
	syscall.SyscallN(wglDXUnlockObjectsNV, gGlInteropDevice, 1,
		uintptr(unsafe.Pointer(&objs[0])))

	comCall(gSwapChain, dxgiSwapPresent, 1, 0)
}

func renderD3D11Panel() {
	if gDxSwapChain == 0 || gDxRtv == 0 {
		return
	}

	// Set viewport
	vp := D3D11_VIEWPORT{Width: panelW, Height: panelH, MaxDepth: 1.0}
	comCall(gD3dCtx, d3dCtxRSSetViewports, 1, uintptr(unsafe.Pointer(&vp)))

	// Set render target and clear with dark green background
	rtvs := [1]uintptr{gDxRtv}
	comCall(gD3dCtx, d3dCtxOMSetRenderTargets, 1, uintptr(unsafe.Pointer(&rtvs[0])), 0)
	clearColor := [4]float32{0.05, 0.15, 0.05, 1.0}
	comCall(gD3dCtx, d3dCtxClearRenderTargetView, gDxRtv, uintptr(unsafe.Pointer(&clearColor[0])))

	// Set pipeline state and draw
	stride := uint32(vertexSize)
	offset := uint32(0)
	vbs := [1]uintptr{gVb}
	comCall(gD3dCtx, d3dCtxIASetInputLayout, gInputLayout)
	comCall(gD3dCtx, d3dCtxIASetVertexBuffers, 0, 1,
		uintptr(unsafe.Pointer(&vbs[0])),
		uintptr(unsafe.Pointer(&stride)),
		uintptr(unsafe.Pointer(&offset)))
	comCall(gD3dCtx, d3dCtxIASetPrimitiveTopology, D3D11_PRIMITIVE_TOPOLOGY_TRIANGLELIST)
	comCall(gD3dCtx, d3dCtxVSSetShader, gVs, 0, 0)
	comCall(gD3dCtx, d3dCtxPSSetShader, gPs, 0, 0)
	comCall(gD3dCtx, d3dCtxDraw, 3, 0)

	comCall(gDxSwapChain, dxgiSwapPresent, 1, 0)
}

func renderVulkanPanel() {
	if gVkDevice == 0 || gVkCmdBuf == 0 || gVkStagingTex == 0 || gVkBackBuffer == 0 {
		return
	}

	maxU64 := ^uintptr(0)
	fences := [1]uintptr{gVkFence}
	pvkWaitForFences.Call(gVkDevice, 1, uintptr(unsafe.Pointer(&fences[0])), VK_TRUE, maxU64)
	pvkResetFences.Call(gVkDevice, 1, uintptr(unsafe.Pointer(&fences[0])))
	pvkResetCommandBuffer.Call(gVkCmdBuf, 0)

	// Begin command buffer
	bi := VkCommandBufferBeginInfo{SType: VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO}
	pvkBeginCommandBuffer.Call(gVkCmdBuf, uintptr(unsafe.Pointer(&bi)))

	// Begin render pass with dark red clear color
	cv := VkClearValue{Color: VkClearColorValue{Float32: [4]float32{0.15, 0.05, 0.05, 1.0}}}
	rpbi := VkRenderPassBeginInfo{
		SType:           VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO,
		RenderPass:      gVkRenderPass,
		Framebuffer:     gVkFramebuffer,
		RenderAreaW:     panelW,
		RenderAreaH:     panelH,
		ClearValueCount: 1,
		PClearValues:    &cv,
	}
	pvkCmdBeginRenderPass.Call(gVkCmdBuf, uintptr(unsafe.Pointer(&rpbi)), VK_SUBPASS_CONTENTS_INLINE)
	pvkCmdBindPipeline.Call(gVkCmdBuf, VK_PIPELINE_BIND_POINT_GRAPHICS, gVkPipeline)
	pvkCmdDraw.Call(gVkCmdBuf, 3, 1, 0, 0)
	pvkCmdEndRenderPass.Call(gVkCmdBuf)

	// Copy image to readback buffer
	region := VkBufferImageCopy{
		BufferRowLength:   panelW,
		BufferImageHeight: panelH,
		AspectMask:        VK_IMAGE_ASPECT_COLOR_BIT,
		LayerCount:        1,
		ExtentW:           panelW,
		ExtentH:           panelH,
		ExtentD:           1,
	}
	pvkCmdCopyImageToBuffer.Call(gVkCmdBuf, gVkOffImage,
		VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL,
		gVkReadbackBuf, 1, uintptr(unsafe.Pointer(&region)))

	pvkEndCommandBuffer.Call(gVkCmdBuf)

	// Submit and wait
	cmdBufs := [1]uintptr{gVkCmdBuf}
	si := VkSubmitInfo{
		SType:              VK_STRUCTURE_TYPE_SUBMIT_INFO,
		CommandBufferCount: 1,
		PCommandBuffers:    &cmdBufs[0],
	}
	pvkQueueSubmit.Call(gVkQueue, 1, uintptr(unsafe.Pointer(&si)), gVkFence)
	pvkWaitForFences.Call(gVkDevice, 1, uintptr(unsafe.Pointer(&fences[0])), VK_TRUE, maxU64)

	// Map Vulkan readback buffer and copy to D3D11 staging texture
	var vkData uintptr
	pvkMapMemory.Call(gVkDevice, gVkReadbackMem, 0,
		uintptr(uint64(panelW)*uint64(panelH)*4), 0,
		uintptr(unsafe.Pointer(&vkData)))

	var mapped D3D11_MAPPED_SUBRESOURCE
	hr := comCall(gD3dCtx, d3dCtxMap, gVkStagingTex, 0, D3D11_MAP_WRITE, 0,
		uintptr(unsafe.Pointer(&mapped)))
	if hr == 0 {
		pitch := uint32(panelW * 4)
		for y := uint32(0); y < panelH; y++ {
			src := (*[panelW * 4]byte)(unsafe.Pointer(vkData + uintptr(y)*uintptr(pitch)))
			dst := (*[panelW * 4]byte)(unsafe.Pointer(mapped.PData + uintptr(y)*uintptr(mapped.RowPitch)))
			*dst = *src
		}
		comCall(gD3dCtx, d3dCtxUnmap, gVkStagingTex, 0)
		comCall(gD3dCtx, d3dCtxCopyResource, gVkBackBuffer, gVkStagingTex)
	}
	pvkUnmapMemory.Call(gVkDevice, gVkReadbackMem)

	comCall(gVkSwapChain, dxgiSwapPresent, 1, 0)
}

func render() {
	renderOpenGLPanel()
	renderD3D11Panel()
	renderVulkanPanel()
}

// ============================================================
// Cleanup
// ============================================================

func cleanup() {
	dbg("Cleanup begin")

	// DirectComposition visuals
	comRelease(gVkDcompVisual)
	comRelease(gDxVisual)
	comRelease(gGlVisual)
	comRelease(gRootVisual)
	comRelease(gCompTarget)
	comRelease(gCompositor)

	// Vulkan cleanup
	if gVkDevice != 0 {
		pvkDeviceWaitIdle.Call(gVkDevice)
	}
	if gVkFence != 0 {
		pvkDestroyFence.Call(gVkDevice, gVkFence, 0)
	}
	if gVkCmdPool != 0 {
		pvkDestroyCommandPool.Call(gVkDevice, gVkCmdPool, 0)
	}
	if gVkPipeline != 0 {
		pvkDestroyPipeline.Call(gVkDevice, gVkPipeline, 0)
	}
	if gVkPipelineLayout != 0 {
		pvkDestroyPipelineLayout.Call(gVkDevice, gVkPipelineLayout, 0)
	}
	if gVkFramebuffer != 0 {
		pvkDestroyFramebuffer.Call(gVkDevice, gVkFramebuffer, 0)
	}
	if gVkRenderPass != 0 {
		pvkDestroyRenderPass.Call(gVkDevice, gVkRenderPass, 0)
	}
	if gVkOffView != 0 {
		pvkDestroyImageView.Call(gVkDevice, gVkOffView, 0)
	}
	if gVkOffImage != 0 {
		pvkDestroyImage.Call(gVkDevice, gVkOffImage, 0)
	}
	if gVkOffMemory != 0 {
		pvkFreeMemory.Call(gVkDevice, gVkOffMemory, 0)
	}
	if gVkReadbackBuf != 0 {
		pvkDestroyBuffer.Call(gVkDevice, gVkReadbackBuf, 0)
	}
	if gVkReadbackMem != 0 {
		pvkFreeMemory.Call(gVkDevice, gVkReadbackMem, 0)
	}
	if gVkDevice != 0 {
		pvkDestroyDevice.Call(gVkDevice, 0)
	}
	if gVkInstance != 0 {
		pvkDestroyInstance.Call(gVkInstance, 0)
	}
	comRelease(gVkStagingTex)
	comRelease(gVkBackBuffer)

	// OpenGL interop cleanup (before D3D device release)
	if gGlInteropObject != 0 && gGlInteropDevice != 0 {
		syscall.SyscallN(wglDXUnregisterObjectNV, gGlInteropDevice, gGlInteropObject)
	}
	if gGlInteropDevice != 0 {
		syscall.SyscallN(wglDXCloseDeviceNV, gGlInteropDevice)
	}

	// OpenGL objects
	if gHdc != 0 && gHglrc != 0 {
		pWglMakeCurrent.Call(gHdc, gHglrc)
	}
	if gGlProgram != 0 && glDeleteProgram != 0 {
		syscall.SyscallN(glDeleteProgram, uintptr(gGlProgram))
	}
	if gGlVbo[0] != 0 && glDeleteBuffers != 0 {
		syscall.SyscallN(glDeleteBuffers, 2, uintptr(unsafe.Pointer(&gGlVbo[0])))
	}
	if gGlVao != 0 && glDeleteVertexArrays != 0 {
		syscall.SyscallN(glDeleteVertexArrays, 1, uintptr(unsafe.Pointer(&gGlVao)))
	}
	if gGlFbo != 0 && glDeleteFramebuffers != 0 {
		syscall.SyscallN(glDeleteFramebuffers, 1, uintptr(unsafe.Pointer(&gGlFbo)))
	}
	if gGlRbo != 0 && glDeleteRenderbuffers != 0 {
		syscall.SyscallN(glDeleteRenderbuffers, 1, uintptr(unsafe.Pointer(&gGlRbo)))
	}

	if gHglrc != 0 {
		pWglMakeCurrent.Call(0, 0)
		pWglDeleteContext.Call(gHglrc)
	}
	if gHdc != 0 && gHwnd != 0 {
		pReleaseDC.Call(gHwnd, gHdc)
	}

	// D3D11 objects
	comRelease(gVb)
	comRelease(gInputLayout)
	comRelease(gPs)
	comRelease(gVs)
	comRelease(gDxRtv)
	comRelease(gRtv)
	comRelease(gBackBuffer)
	comRelease(gDxSwapChain)
	comRelease(gVkSwapChain)
	comRelease(gSwapChain)
	comRelease(gD3dCtx)
	comRelease(gD3dDevice)

	dbg("Cleanup ok")
}

// ============================================================
// Entry point
// ============================================================

func main() {
	dbg("=== wWinMain start ===")

	hInst, _, _ := pGetModuleHandleW.Call(0)

	if err := createAppWindow(hInst); err != nil {
		dbg("CreateAppWindow failed")
		return
	}

	if err := initD3D11(); err != nil {
		dbg("InitD3D11 failed")
		cleanup()
		return
	}

	if err := initOpenGL(); err != nil {
		dbg("InitOpenGL failed")
		cleanup()
		return
	}

	if err := initD3D11SecondPanel(); err != nil {
		dbg("InitD3D11SecondPanel failed")
		cleanup()
		return
	}

	if err := initVulkanPanel(); err != nil {
		dbg("InitVulkanPanel failed")
		cleanup()
		return
	}

	if err := initComposition(); err != nil {
		dbg("InitComposition failed")
		cleanup()
		return
	}

	dbg("=== ENTERING MESSAGE LOOP ===")
	var msg MSG
	for {
		ret, _, _ := pPeekMessageW.Call(
			uintptr(unsafe.Pointer(&msg)), 0, 0, 0, PM_REMOVE)
		if ret != 0 {
			if msg.Message == 0x0012 { // WM_QUIT
				break
			}
			pTranslateMessage.Call(uintptr(unsafe.Pointer(&msg)))
			pDispatchMessageW.Call(uintptr(unsafe.Pointer(&msg)))
		} else {
			render()
		}
	}

	dbg("loop end")
	cleanup()
}