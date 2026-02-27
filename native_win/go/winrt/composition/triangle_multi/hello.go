package main

/*
 * hello_comp.go
 *
 * Win32 window + OpenGL 4.6 + D3D11 + Vulkan triangles composited via
 * Windows.UI.Composition (WinRT Composition API) on a classic desktop app.
 *
 * Pure Go (no cgo) using raw COM/WinRT vtable calls and syscall.SyscallN.
 *
 * Architecture:
 *   - Three DXGI swap chains created with CreateSwapChainForComposition
 *   - Left panel:  OpenGL 4.6 via WGL_NV_DX_interop into D3D11 back buffer
 *   - Center panel: D3D11 direct rendering
 *   - Right panel:  Vulkan offscreen -> readback -> D3D11 staging copy
 *   - Windows.UI.Composition visual tree:
 *       Compositor -> DesktopWindowTarget -> ContainerVisual (root)
 *         -> 3 SpriteVisuals with SurfaceBrushes wrapping swap chains
 *
 * Key difference from DirectComposition (IDCompositionDevice) approach:
 *   - Uses WinRT Compositor activated via RoActivateInstance
 *   - QI for ICompositorDesktopInterop (HWND target)
 *   - QI for ICompositorInterop (swap chain -> composition surface)
 *   - Requires DispatcherQueue on the thread
 *
 * Build:
 *   go build -ldflags "-H windowsgui" hello_comp.go
 *
 * Requirements:
 *   - NVIDIA GPU (for WGL_NV_DX_interop)
 *   - Vulkan SDK installed (vulkan-1.dll)
 *   - hello_vert.spv and hello_frag.spv in working directory
 *
 * SPIR-V compilation:
 *   glslc hello.vert -o hello_vert.spv
 *   glslc hello.frag -o hello_frag.spv
 */

import (
	"fmt"
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
	WS_OVERLAPPEDWINDOW       = 0x00CF0000
	WS_EX_NOREDIRECTIONBITMAP = 0x00200000
	CW_USEDEFAULT             = 0x80000000
	SW_SHOW                   = 5
	IDC_ARROW                 = 32512
	WM_DESTROY                = 0x0002
	WM_PAINT                  = 0x000F
	PM_REMOVE                 = 0x0001
	WM_QUIT                   = 0x0012
)

// DXGI / D3D11
const (
	D3D_DRIVER_TYPE_HARDWARE         = 1
	D3D11_SDK_VERSION                = 7
	D3D11_CREATE_DEVICE_BGRA_SUPPORT = 0x20
	D3D_FEATURE_LEVEL_11_0           = 0xb000
	DXGI_FORMAT_B8G8R8A8_UNORM       = 87
	DXGI_FORMAT_R32G32B32_FLOAT      = 6
	DXGI_FORMAT_R32G32B32A32_FLOAT   = 2
	DXGI_USAGE_RENDER_TARGET_OUTPUT  = 0x20
	DXGI_SCALING_STRETCH             = 0
	DXGI_SWAP_EFFECT_FLIP_SEQUENTIAL = 3
	DXGI_ALPHA_MODE_PREMULTIPLIED    = 1
	D3D11_BIND_VERTEX_BUFFER         = 0x1
	D3D11_USAGE_DEFAULT              = 0
	D3D11_USAGE_STAGING              = 3
	D3D11_CPU_ACCESS_WRITE           = 0x10000
	D3D11_PRIMITIVE_TOPOLOGY_TRIANGLELIST = 4
	D3D11_MAP_WRITE                  = 2
	D3DCOMPILE_ENABLE_STRICTNESS     = 0x800
)

// OpenGL
const (
	GL_TRIANGLES            = 0x0004
	GL_FLOAT                = 0x1406
	GL_FALSE                = 0
	GL_COLOR_BUFFER_BIT     = 0x4000
	GL_ARRAY_BUFFER         = 0x8892
	GL_STATIC_DRAW          = 0x88E4
	GL_FRAGMENT_SHADER      = 0x8B30
	GL_VERTEX_SHADER        = 0x8B31
	GL_FRAMEBUFFER          = 0x8D40
	GL_RENDERBUFFER         = 0x8D41
	GL_COLOR_ATTACHMENT0    = 0x8CE0
	GL_FRAMEBUFFER_COMPLETE = 0x8CD5
	GL_COMPILE_STATUS       = 0x8B81
	GL_INFO_LOG_LENGTH      = 0x8B84
	GL_LINK_STATUS          = 0x8B82
	GL_VERSION              = 0x1F02
	GL_SHADING_LANGUAGE_VERSION = 0x8B8C
	WGL_CONTEXT_MAJOR_VERSION_ARB    = 0x2091
	WGL_CONTEXT_MINOR_VERSION_ARB    = 0x2092
	WGL_CONTEXT_FLAGS_ARB            = 0x2094
	WGL_CONTEXT_PROFILE_MASK_ARB     = 0x9126
	WGL_CONTEXT_CORE_PROFILE_BIT_ARB = 0x00000001
	WGL_ACCESS_READ_WRITE_NV         = 0x0001
	PFD_DRAW_TO_WINDOW = 0x4
	PFD_SUPPORT_OPENGL = 0x20
	PFD_DOUBLEBUFFER   = 0x1
	PFD_TYPE_RGBA      = 0
	PFD_MAIN_PLANE     = 0
)

// Vulkan
const (
	VK_SUCCESS                                         = 0
	VK_STRUCTURE_TYPE_APPLICATION_INFO                  = 0
	VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO              = 1
	VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO          = 2
	VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO                = 3
	VK_STRUCTURE_TYPE_SUBMIT_INFO                       = 4
	VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO              = 5
	VK_STRUCTURE_TYPE_FENCE_CREATE_INFO                 = 8
	VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO                = 12
	VK_STRUCTURE_TYPE_IMAGE_CREATE_INFO                 = 14
	VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO            = 15
	VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO         = 16
	VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO = 18
	VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO  = 19
	VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO = 20
	VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO       = 22
	VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO  = 23
	VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO    = 24
	VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO    = 26
	VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO    = 28
	VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO      = 30
	VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO          = 37
	VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO          = 38
	VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO          = 39
	VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO      = 40
	VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO         = 42
	VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO            = 43
	VK_IMAGE_TYPE_2D                                   = 1
	VK_FORMAT_B8G8R8A8_UNORM                           = 44
	VK_SAMPLE_COUNT_1_BIT                              = 1
	VK_IMAGE_TILING_OPTIMAL                            = 0
	VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT                = 0x10
	VK_IMAGE_USAGE_TRANSFER_SRC_BIT                    = 0x1
	VK_IMAGE_LAYOUT_UNDEFINED                          = 0
	VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL           = 2
	VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL               = 6
	VK_IMAGE_VIEW_TYPE_2D                              = 1
	VK_IMAGE_ASPECT_COLOR_BIT                          = 0x1
	VK_BUFFER_USAGE_TRANSFER_DST_BIT                   = 0x2
	VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT                = 0x1
	VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT                = 0x2
	VK_MEMORY_PROPERTY_HOST_COHERENT_BIT               = 0x4
	VK_ATTACHMENT_LOAD_OP_CLEAR                        = 1
	VK_ATTACHMENT_STORE_OP_STORE                       = 0
	VK_ATTACHMENT_LOAD_OP_DONT_CARE                    = 2
	VK_ATTACHMENT_STORE_OP_DONT_CARE                   = 1
	VK_PIPELINE_BIND_POINT_GRAPHICS                    = 0
	VK_SUBPASS_CONTENTS_INLINE                         = 0
	VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST                = 3
	VK_POLYGON_MODE_FILL                               = 0
	VK_CULL_MODE_BACK_BIT                              = 2
	VK_FRONT_FACE_CLOCKWISE                            = 1
	VK_SHADER_STAGE_VERTEX_BIT                         = 0x1
	VK_SHADER_STAGE_FRAGMENT_BIT                       = 0x10
	VK_COMMAND_BUFFER_LEVEL_PRIMARY                    = 0
	VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT    = 0x2
	VK_FENCE_CREATE_SIGNALED_BIT                       = 0x1
	VK_QUEUE_GRAPHICS_BIT                              = 0x1
	VK_TRUE                                            = 1
)

// WinRT
const (
	RO_INIT_SINGLETHREADED = 0
)

// DispatcherQueue
const (
	DQTYPE_THREAD_CURRENT = 2
	DQTAT_COM_NONE        = 0
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
	IID_IDXGIDevice     = GUID{0x54ec77fa, 0x1377, 0x44e6, [8]byte{0x8c, 0x32, 0x88, 0xfd, 0x5f, 0x44, 0xc8, 0x4c}}
	IID_IDXGIFactory2   = GUID{0x50c83a1c, 0xe072, 0x4c48, [8]byte{0x87, 0xb0, 0x36, 0x30, 0xfa, 0x36, 0xa6, 0xd0}}
	IID_ID3D11Texture2D = GUID{0x6f15aaf2, 0xd208, 0x4e89, [8]byte{0x9a, 0xb4, 0x48, 0x95, 0x35, 0xd3, 0x4f, 0x9c}}

	// Windows.UI.Composition interfaces
	IID_ICompositor                = GUID{0xB403CA50, 0x7F8C, 0x4E83, [8]byte{0x98, 0x5F, 0xA4, 0x14, 0xD2, 0x6F, 0x1D, 0xAD}}
	IID_ICompositorDesktopInterop  = GUID{0x29E691FA, 0x4567, 0x4DCA, [8]byte{0xB3, 0x19, 0xD0, 0xF2, 0x07, 0xEB, 0x68, 0x07}}
	IID_ICompositorInterop         = GUID{0x25297D5C, 0x3AD4, 0x4C9C, [8]byte{0xB5, 0xCF, 0xE3, 0x6A, 0x38, 0x51, 0x23, 0x30}}
	IID_ICompositionTarget         = GUID{0xA1BEA8BA, 0xD726, 0x4663, [8]byte{0x81, 0x29, 0x6B, 0x5E, 0x79, 0x27, 0xFF, 0xA6}}
	IID_IContainerVisual           = GUID{0x02F6BC74, 0xED20, 0x4773, [8]byte{0xAF, 0xE6, 0xD4, 0x9B, 0x4A, 0x93, 0xDB, 0x32}}
	IID_IVisual                    = GUID{0x117E202D, 0xA859, 0x4C89, [8]byte{0x87, 0x3B, 0xC2, 0xAA, 0x56, 0x67, 0x88, 0xE3}}
	IID_ISpriteVisual              = GUID{0x08E05581, 0x1AD1, 0x4F97, [8]byte{0x97, 0x57, 0x40, 0x2D, 0x76, 0xE4, 0x23, 0x3B}}
	IID_ICompositionBrush          = GUID{0xAB0D7608, 0x30C0, 0x40E9, [8]byte{0xB5, 0x68, 0xB6, 0x0A, 0x6B, 0xD1, 0xFB, 0x46}}
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
	Size, Version                                        uint16
	Flags                                                uint32
	PixelType, ColorBits, RedBits, RedShift              byte
	GreenBits, GreenShift, BlueBits, BlueShift           byte
	AlphaBits, AlphaShift, AccumBits                     byte
	AccumRedBits, AccumGreenBits, AccumBlueBits          byte
	AccumAlphaBits, DepthBits, StencilBits               byte
	AuxBuffers, LayerType, Reserved                      byte
	LayerMask, VisibleMask, DamageMask                   uint32
}
type DXGI_SAMPLE_DESC struct{ Count, Quality uint32 }
type DXGI_SWAP_CHAIN_DESC1 struct {
	Width, Height, Format uint32
	Stereo                int32
	SampleDesc            DXGI_SAMPLE_DESC
	BufferUsage           uint32
	BufferCount           uint32
	Scaling, SwapEffect   uint32
	AlphaMode, Flags      uint32
}
type D3D11_VIEWPORT struct {
	TopLeftX, TopLeftY, Width, Height, MinDepth, MaxDepth float32
}
type D3D11_INPUT_ELEMENT_DESC struct {
	SemanticName                           *byte
	SemanticIndex, Format, InputSlot       uint32
	AlignedByteOffset, InputSlotClass      uint32
	InstanceDataStepRate                   uint32
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
	Width, Height, MipLevels, ArraySize, Format uint32
	SampleDesc                                  DXGI_SAMPLE_DESC
	Usage, BindFlags, CPUAccessFlags, MiscFlags uint32
}
type D3D11_MAPPED_SUBRESOURCE struct {
	PData      uintptr
	RowPitch   uint32
	DepthPitch uint32
}

// WinRT Numerics (used by IVisual put_Size / put_Offset)
type Vector2 struct{ X, Y float32 }
type Vector3 struct{ X, Y, Z float32 }

// Vertex: 3 float pos + 4 float color
type Vertex struct{ X, Y, Z, R, G, B, A float32 }

// HSTRING_HEADER: opaque, 24 bytes on x64
type HSTRING_HEADER struct{ _ [24]byte }

// DispatcherQueueOptions: 12 bytes
type DispatcherQueueOptions struct {
	Size          uint32
	ThreadType    uint32
	ApartmentType uint32
}

// ============================================================
// Vulkan structures (minimal subset  Esame as DirectComposition version)
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
	SType                   uint32
	PNext                   uintptr
	Flags                   uint32
	QueueFamilyIndex         uint32
	QueueCount               uint32
	PQueuePriorities         *float32
}
type VkDeviceCreateInfo struct {
	SType                   uint32
	PNext                   uintptr
	Flags                   uint32
	QueueCreateInfoCount    uint32
	PQueueCreateInfos       uintptr
	EnabledLayerCount       uint32
	PPEnabledLayerNames     uintptr
	EnabledExtensionCount   uint32
	PPEnabledExtensionNames uintptr
	PEnabledFeatures        uintptr
}
type VkImageCreateInfo struct {
	SType         uint32
	PNext         uintptr
	Flags         uint32
	ImageType     uint32
	Format        uint32
	ExtentW       uint32
	ExtentH       uint32
	ExtentD       uint32
	MipLevels     uint32
	ArrayLayers   uint32
	Samples       uint32
	Tiling        uint32
	Usage         uint32
	SharingMode   uint32
	QFICount      uint32
	PQFIndices    uintptr
	InitialLayout uint32
}
type VkMemoryRequirements struct {
	Size, Alignment uint64
	MemoryTypeBits  uint32
	_pad            [4]byte
}
type VkMemoryAllocateInfo struct {
	SType           uint32
	PNext           uintptr
	AllocationSize  uint64
	MemoryTypeIndex uint32
	_pad            [4]byte
}
type VkImageViewCreateInfo struct {
	SType                    uint32
	PNext                    uintptr
	Flags                    uint32
	Image                    uintptr
	ViewType                 uint32
	Format                   uint32
	CompR, CompG, CompB, CompA uint32
	AspectMask               uint32
	BaseMipLevel             uint32
	LevelCount               uint32
	BaseArrayLayer           uint32
	LayerCount               uint32
}
type VkBufferCreateInfo struct {
	SType         uint32
	PNext         uintptr
	Flags         uint32
	Size          uint64
	Usage         uint32
	SharingMode   uint32
	QFICount      uint32
	PQFIndices    uintptr
}
type VkAttachmentDescription struct {
	Flags, Format, Samples                                     uint32
	LoadOp, StoreOp, StencilLoadOp, StencilStoreOp             uint32
	InitialLayout, FinalLayout                                 uint32
}
type VkAttachmentReference struct{ Attachment, Layout uint32 }
type VkSubpassDescription struct {
	Flags, PipelineBindPoint                 uint32
	InputAttachmentCount                     uint32
	PInputAttachments                        uintptr
	ColorAttachmentCount                     uint32
	PColorAttachments                        *VkAttachmentReference
	PResolveAttachments, PDepthStencilAttachment uintptr
	PreserveAttachmentCount                  uint32
	PPreserveAttachments                     uintptr
}
type VkRenderPassCreateInfo struct {
	SType               uint32
	PNext               uintptr
	Flags               uint32
	AttachmentCount     uint32
	PAttachments        *VkAttachmentDescription
	SubpassCount        uint32
	PSubpasses          *VkSubpassDescription
	DependencyCount     uint32
	PDependencies       uintptr
}
type VkFramebufferCreateInfo struct {
	SType               uint32
	PNext               uintptr
	Flags               uint32
	RenderPass          uintptr
	AttachmentCount     uint32
	PAttachments        *uintptr
	Width, Height       uint32
	Layers              uint32
}
type VkShaderModuleCreateInfo struct {
	SType    uint32
	PNext    uintptr
	Flags    uint32
	CodeSize uintptr
	PCode    uintptr
}
type VkPipelineShaderStageCreateInfo struct {
	SType               uint32
	PNext               uintptr
	Flags               uint32
	Stage               uint32
	Module              uintptr
	PName               *byte
	PSpecInfo           uintptr
}
type VkPipelineVertexInputStateCreateInfo struct {
	SType               uint32
	PNext               uintptr
	Flags               uint32
	VBDCount            uint32
	PVBDescs            uintptr
	VADCount            uint32
	PVADescs            uintptr
}
type VkPipelineInputAssemblyStateCreateInfo struct {
	SType               uint32
	PNext               uintptr
	Flags               uint32
	Topology            uint32
	PrimRestart         uint32
}
type VkViewport struct{ X, Y, Width, Height, MinDepth, MaxDepth float32 }
type VkRect2D struct {
	OffsetX, OffsetY int32
	ExtentW, ExtentH uint32
}
type VkPipelineViewportStateCreateInfo struct {
	SType               uint32
	PNext               uintptr
	Flags               uint32
	VPCount             uint32
	PViewports          *VkViewport
	ScissorCount        uint32
	PScissors           *VkRect2D
}
type VkPipelineRasterizationStateCreateInfo struct {
	SType                               uint32
	PNext                               uintptr
	Flags                               uint32
	DepthClamp, RasterizerDiscard       uint32
	PolygonMode, CullMode, FrontFace    uint32
	DepthBiasEnable                     uint32
	DepthBiasConst, DepthBiasClamp, DepthBiasSlope float32
	LineWidth                           float32
}
type VkPipelineMultisampleStateCreateInfo struct {
	SType               uint32
	PNext               uintptr
	Flags               uint32
	RasterSamples       uint32
	SampleShadingEn     uint32
	MinSampleShading    float32
	PSampleMask         uintptr
	AlphaToCoverage     uint32
	AlphaToOne          uint32
}
type VkPipelineColorBlendAttachmentState struct {
	BlendEnable                            uint32
	SrcColorBF, DstColorBF, ColorBlendOp   uint32
	SrcAlphaBF, DstAlphaBF, AlphaBlendOp   uint32
	ColorWriteMask                         uint32
}
type VkPipelineColorBlendStateCreateInfo struct {
	SType               uint32
	PNext               uintptr
	Flags               uint32
	LogicOpEnable       uint32
	LogicOp             uint32
	AttachmentCount     uint32
	PAttachments        *VkPipelineColorBlendAttachmentState
	BlendConstants      [4]float32
}
type VkPipelineLayoutCreateInfo struct {
	SType               uint32
	PNext               uintptr
	Flags               uint32
	SetLayoutCount      uint32
	PSetLayouts         uintptr
	PushConstRangeCount uint32
	PPushConstRanges    uintptr
}
type VkGraphicsPipelineCreateInfo struct {
	SType                 uint32
	PNext                 uintptr
	Flags                 uint32
	StageCount            uint32
	PStages               uintptr
	PVertexInputState     uintptr
	PInputAssemblyState   uintptr
	PTessellationState    uintptr
	PViewportState        uintptr
	PRasterizationState   uintptr
	PMultisampleState     uintptr
	PDepthStencilState    uintptr
	PColorBlendState      uintptr
	PDynamicState         uintptr
	Layout                uintptr
	RenderPass            uintptr
	Subpass               uint32
	BasePipelineHandle    uintptr
	BasePipelineIndex     int32
}
type VkCommandPoolCreateInfo struct {
	SType               uint32
	PNext               uintptr
	Flags               uint32
	QueueFamilyIndex    uint32
}
type VkCommandBufferAllocateInfo struct {
	SType        uint32
	PNext        uintptr
	CommandPool  uintptr
	Level        uint32
	Count        uint32
}
type VkCommandBufferBeginInfo struct {
	SType               uint32
	PNext               uintptr
	Flags               uint32
	PInheritanceInfo    uintptr
}
type VkClearValue struct{ R, G, B, A float32 }
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
	BufOffset                uint64
	BufRowLength, BufImgH    uint32
	AspectMask               uint32
	MipLevel, BaseLayer, LayerCount uint32
	OffX, OffY, OffZ         int32
	ExtW, ExtH, ExtD         uint32
}
type VkSubmitInfo struct {
	SType               uint32
	PNext               uintptr
	WaitSemCount        uint32
	PWaitSems           uintptr
	PWaitDstStageMask   uintptr
	CmdBufCount         uint32
	PCmdBufs            *uintptr
	SignalSemCount      uint32
	PSignalSems         uintptr
}
type VkFenceCreateInfo struct {
	SType uint32
	PNext uintptr
	Flags uint32
}
type VkQueueFamilyProperties struct {
	QueueFlags, QueueCount, TimestampValidBits uint32
	MinITGW, MinITGH, MinITGD                  uint32
}
type VkPhysicalDeviceMemoryProperties struct {
	MemTypeCount uint32
	MemTypes     [32]struct{ PropFlags, HeapIndex uint32 }
	MemHeapCount uint32
	MemHeaps     [16]struct {
		Size  uint64
		Flags uint32
		_pad  [4]byte
	}
}

// ============================================================
// DLL / proc declarations
// ============================================================

var (
	user32            = syscall.NewLazyDLL("user32.dll")
	pRegisterClassExW = user32.NewProc("RegisterClassExW")
	pCreateWindowExW  = user32.NewProc("CreateWindowExW")
	pDefWindowProcW   = user32.NewProc("DefWindowProcW")
	pPeekMessageW     = user32.NewProc("PeekMessageW")
	pTranslateMessage = user32.NewProc("TranslateMessage")
	pDispatchMessageW = user32.NewProc("DispatchMessageW")
	pPostQuitMessage  = user32.NewProc("PostQuitMessage")
	pLoadCursorW      = user32.NewProc("LoadCursorW")
	pShowWindow       = user32.NewProc("ShowWindow")
	pUpdateWindow     = user32.NewProc("UpdateWindow")
	pAdjustWindowRect = user32.NewProc("AdjustWindowRect")
	pBeginPaint       = user32.NewProc("BeginPaint")
	pEndPaint         = user32.NewProc("EndPaint")
	pGetDC            = user32.NewProc("GetDC")
	pReleaseDC        = user32.NewProc("ReleaseDC")

	kernel32            = syscall.NewLazyDLL("kernel32.dll")
	pGetModuleHandleW   = kernel32.NewProc("GetModuleHandleW")
	pGetCurrentProcessId = kernel32.NewProc("GetCurrentProcessId")
	pOutputDebugStringW = kernel32.NewProc("OutputDebugStringW")

	gdi32              = syscall.NewLazyDLL("gdi32.dll")
	pChoosePixelFormat = gdi32.NewProc("ChoosePixelFormat")
	pSetPixelFormat    = gdi32.NewProc("SetPixelFormat")

	opengl32           = syscall.NewLazyDLL("opengl32.dll")
	pWglCreateContext  = opengl32.NewProc("wglCreateContext")
	pWglDeleteContext  = opengl32.NewProc("wglDeleteContext")
	pWglMakeCurrent    = opengl32.NewProc("wglMakeCurrent")
	pWglGetProcAddress = opengl32.NewProc("wglGetProcAddress")
	pGlGetString       = opengl32.NewProc("glGetString")
	pGlViewport        = opengl32.NewProc("glViewport")
	pGlClearColor      = opengl32.NewProc("glClearColor")
	pGlClear           = opengl32.NewProc("glClear")
	pGlDrawArrays      = opengl32.NewProc("glDrawArrays")
	pGlFlush           = opengl32.NewProc("glFlush")

	d3d11              = syscall.NewLazyDLL("d3d11.dll")
	pD3D11CreateDevice = d3d11.NewProc("D3D11CreateDevice")

	d3dcompiler = syscall.NewLazyDLL("d3dcompiler_47.dll")
	pD3DCompile = d3dcompiler.NewProc("D3DCompile")

	// WinRT runtime (replaces dcomp.dll)
	combase                            = syscall.NewLazyDLL("combase.dll")
	pRoInitialize                      = combase.NewProc("RoInitialize")
	pRoUninitialize                    = combase.NewProc("RoUninitialize")
	pRoActivateInstance                = combase.NewProc("RoActivateInstance")
	pWindowsCreateStringReference      = combase.NewProc("WindowsCreateStringReference")

	coreMessaging                          = syscall.NewLazyDLL("CoreMessaging.dll")
	pCreateDispatcherQueueController       = coreMessaging.NewProc("CreateDispatcherQueueController")

	vulkan                         = syscall.NewLazyDLL("vulkan-1.dll")
	pvkCreateInstance              = vulkan.NewProc("vkCreateInstance")
	pvkEnumeratePhysicalDevices    = vulkan.NewProc("vkEnumeratePhysicalDevices")
	pvkGetPhysicalDeviceQueueFamilyProperties = vulkan.NewProc("vkGetPhysicalDeviceQueueFamilyProperties")
	pvkGetPhysicalDeviceMemoryProperties      = vulkan.NewProc("vkGetPhysicalDeviceMemoryProperties")
	pvkCreateDevice                = vulkan.NewProc("vkCreateDevice")
	pvkGetDeviceQueue              = vulkan.NewProc("vkGetDeviceQueue")
	pvkCreateImage                 = vulkan.NewProc("vkCreateImage")
	pvkGetImageMemoryRequirements  = vulkan.NewProc("vkGetImageMemoryRequirements")
	pvkAllocateMemory              = vulkan.NewProc("vkAllocateMemory")
	pvkBindImageMemory             = vulkan.NewProc("vkBindImageMemory")
	pvkCreateImageView             = vulkan.NewProc("vkCreateImageView")
	pvkCreateBuffer                = vulkan.NewProc("vkCreateBuffer")
	pvkGetBufferMemoryRequirements = vulkan.NewProc("vkGetBufferMemoryRequirements")
	pvkBindBufferMemory            = vulkan.NewProc("vkBindBufferMemory")
	pvkCreateRenderPass            = vulkan.NewProc("vkCreateRenderPass")
	pvkCreateFramebuffer           = vulkan.NewProc("vkCreateFramebuffer")
	pvkCreateShaderModule          = vulkan.NewProc("vkCreateShaderModule")
	pvkCreatePipelineLayout        = vulkan.NewProc("vkCreatePipelineLayout")
	pvkCreateGraphicsPipelines     = vulkan.NewProc("vkCreateGraphicsPipelines")
	pvkDestroyShaderModule         = vulkan.NewProc("vkDestroyShaderModule")
	pvkCreateCommandPool           = vulkan.NewProc("vkCreateCommandPool")
	pvkAllocateCommandBuffers      = vulkan.NewProc("vkAllocateCommandBuffers")
	pvkCreateFence                 = vulkan.NewProc("vkCreateFence")
	pvkWaitForFences               = vulkan.NewProc("vkWaitForFences")
	pvkResetFences                 = vulkan.NewProc("vkResetFences")
	pvkResetCommandBuffer          = vulkan.NewProc("vkResetCommandBuffer")
	pvkBeginCommandBuffer          = vulkan.NewProc("vkBeginCommandBuffer")
	pvkCmdBeginRenderPass          = vulkan.NewProc("vkCmdBeginRenderPass")
	pvkCmdBindPipeline             = vulkan.NewProc("vkCmdBindPipeline")
	pvkCmdDraw                     = vulkan.NewProc("vkCmdDraw")
	pvkCmdEndRenderPass            = vulkan.NewProc("vkCmdEndRenderPass")
	pvkCmdCopyImageToBuffer        = vulkan.NewProc("vkCmdCopyImageToBuffer")
	pvkEndCommandBuffer            = vulkan.NewProc("vkEndCommandBuffer")
	pvkQueueSubmit                 = vulkan.NewProc("vkQueueSubmit")
	pvkMapMemory                   = vulkan.NewProc("vkMapMemory")
	pvkUnmapMemory                 = vulkan.NewProc("vkUnmapMemory")
	pvkDeviceWaitIdle              = vulkan.NewProc("vkDeviceWaitIdle")
	pvkDestroyFence                = vulkan.NewProc("vkDestroyFence")
	pvkDestroyCommandPool          = vulkan.NewProc("vkDestroyCommandPool")
	pvkDestroyPipeline             = vulkan.NewProc("vkDestroyPipeline")
	pvkDestroyPipelineLayout       = vulkan.NewProc("vkDestroyPipelineLayout")
	pvkDestroyFramebuffer          = vulkan.NewProc("vkDestroyFramebuffer")
	pvkDestroyRenderPass           = vulkan.NewProc("vkDestroyRenderPass")
	pvkDestroyImageView            = vulkan.NewProc("vkDestroyImageView")
	pvkDestroyImage                = vulkan.NewProc("vkDestroyImage")
	pvkFreeMemory                  = vulkan.NewProc("vkFreeMemory")
	pvkDestroyBuffer               = vulkan.NewProc("vkDestroyBuffer")
	pvkDestroyDevice               = vulkan.NewProc("vkDestroyDevice")
	pvkDestroyInstance             = vulkan.NewProc("vkDestroyInstance")
)

// OpenGL extension function pointers (loaded at runtime)
var (
	glGenBuffers, glBindBuffer, glBufferData               uintptr
	glCreateShader, glShaderSource, glCompileShader         uintptr
	glGetShaderiv, glGetShaderInfoLog                       uintptr
	glCreateProgram, glAttachShader                         uintptr
	glLinkProgram, glGetProgramiv, glGetProgramInfoLog      uintptr
	glUseProgram                                             uintptr
	glGetAttribLocation, glEnableVertexAttribArray          uintptr
	glVertexAttribPointer                                   uintptr
	glGenVertexArrays, glBindVertexArray                    uintptr
	glGenFramebuffers, glBindFramebuffer                    uintptr
	glFramebufferRenderbuffer, glCheckFramebufferStatus     uintptr
	glGenRenderbuffers, glBindRenderbuffer                  uintptr
	glDeleteBuffers, glDeleteVertexArrays                   uintptr
	glDeleteFramebuffers, glDeleteRenderbuffers             uintptr
	glDeleteProgram                                         uintptr
	wglCreateContextAttribsARB                              uintptr
	wglDXOpenDeviceNV, wglDXCloseDeviceNV                   uintptr
	wglDXRegisterObjectNV, wglDXUnregisterObjectNV          uintptr
	wglDXLockObjectsNV, wglDXUnlockObjectsNV               uintptr
)

// ============================================================
// COM vtable helpers
// ============================================================

func comCall(obj uintptr, index int, args ...uintptr) uintptr {
	vtbl := *(*uintptr)(unsafe.Pointer(obj))
	method := *(*uintptr)(unsafe.Pointer(vtbl + uintptr(index)*unsafe.Sizeof(uintptr(0))))
	all := make([]uintptr, 0, 1+len(args))
	all = append(all, obj)
	all = append(all, args...)
	ret, _, _ := syscall.SyscallN(method, all...)
	return ret
}

func comRelease(obj uintptr) {
	if obj != 0 {
		comCall(obj, 2)
	}
}

func comQI(obj uintptr, iid *GUID, out *uintptr) uintptr {
	return comCall(obj, 0, uintptr(unsafe.Pointer(iid)), uintptr(unsafe.Pointer(out)))
}

func f32bits(f float32) uintptr { return uintptr(math.Float32bits(f)) }

// packVector2 packs a Vector2 (8 bytes) into a single register value
// for x64 ABI where structs <= 8 bytes are passed by value in a register.
func packVector2(x, y float32) uintptr {
	return uintptr(uint64(math.Float32bits(x)) | uint64(math.Float32bits(y))<<32)
}

// ============================================================
// HSTRING helper
// ============================================================

func createStringRef(s string) (uintptr, *HSTRING_HEADER, []uint16) {
	utf16 := syscall.StringToUTF16(s)
	length := uint32(len(utf16) - 1) // exclude null terminator
	var header HSTRING_HEADER
	var hstring uintptr
	pWindowsCreateStringReference.Call(
		uintptr(unsafe.Pointer(&utf16[0])),
		uintptr(length),
		uintptr(unsafe.Pointer(&header)),
		uintptr(unsafe.Pointer(&hstring)),
	)
	return hstring, &header, utf16
}

// ============================================================
// String helpers
// ============================================================

func mustUTF16Ptr(s string) *uint16 { p, _ := syscall.UTF16PtrFromString(s); return p }
func cstr(s string) *byte           { b := append([]byte(s), 0); return &b[0] }

func cstrToString(p uintptr) string {
	if p == 0 {
		return ""
	}
	n := 0
	for *(*byte)(unsafe.Pointer(p + uintptr(n))) != 0 {
		n++
	}
	return string(unsafe.Slice((*byte)(unsafe.Pointer(p)), n))
}

// ============================================================
// Shader sources
// ============================================================

var hlslVS = []byte("struct VSInput { float3 pos:POSITION; float4 col:COLOR; };\nstruct VSOutput{ float4 pos:SV_POSITION; float4 col:COLOR; };\nVSOutput main(VSInput i){ VSOutput o; o.pos=float4(i.pos,1); o.col=i.col; return o; }\n\x00")
var hlslPS = []byte("struct PSInput { float4 pos:SV_POSITION; float4 col:COLOR; };\nfloat4 main(PSInput i):SV_TARGET{ return i.col; }\n\x00")
var glslVS = "#version 460 core\nlayout(location=0) in vec3 position;\nlayout(location=1) in vec3 color;\nout vec4 vColor;\nvoid main(){ vColor=vec4(color,1.0); gl_Position=vec4(position.x,-position.y,position.z,1.0); }\n\x00"
var glslPS = "#version 460 core\nin vec4 vColor;\nout vec4 outColor;\nvoid main(){ outColor=vColor; }\n\x00"

// ============================================================
// Debug logging
// ============================================================

func dbg(msg string) {
	line := "[Go Comp] " + msg + "\r\n"
	// Send to DebugView via OutputDebugString.
	pw, _ := syscall.UTF16PtrFromString(line)
	pOutputDebugStringW.Call(uintptr(unsafe.Pointer(pw)))
}

func dbgf(format string, args ...interface{}) {
	dbg(fmt.Sprintf(format, args...))
}

func dbgState(fn, state string) {
	dbg(fn + " | " + state)
}

func init() {
	pid, _, _ := pGetCurrentProcessId.Call()
	dbgf("bootstrap | process start pid=%d", uint32(pid))
}

// ============================================================
// COM vtable slot indices
// ============================================================

// D3D11 Device
const (
	d3dDevCreateBuffer           = 3
	d3dDevCreateTexture2D        = 5
	d3dDevCreateRenderTargetView = 9
	d3dDevCreateInputLayout      = 11
	d3dDevCreateVertexShader     = 12
	d3dDevCreatePixelShader      = 15
)

// D3D11 DeviceContext
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

// IDXGISwapChain
const (
	dxgiSwapPresent   = 8
	dxgiSwapGetBuffer = 9
)

// IDXGIDevice / IDXGIObject / IDXGIFactory2
const (
	dxgiDevGetAdapter                       = 7
	dxgiObjGetParent                        = 6
	dxgiFactory2CreateSwapChainForComposition = 24
)

// ID3DBlob
const (
	blobGetBufferPointer = 3
	blobGetBufferSize    = 4
)

// ============================================================
// Windows.UI.Composition vtable slot indices
//
// WinRT interfaces: IInspectable base (6 slots: 0-5), methods at 6+
// COM interop interfaces: IUnknown base (3 slots: 0-2), methods at 3+
// ============================================================

// ICompositor (WinRT, slot 6+)
// From Windows.UI.Composition.idl method ordering
const (
	compositorCreateContainerVisual = 9  // CreateContainerVisual(IContainerVisual**)
	compositorCreateSpriteVisual    = 22 // CreateSpriteVisual(ISpriteVisual**)
	compositorCreateSurfaceBrush    = 24 // CreateSurfaceBrush(ICompositionSurface*, ICompositionSurfaceBrush**)
)

// ICompositorDesktopInterop (COM, slot 3+)
const (
	desktopInteropCreateTarget = 3 // CreateDesktopWindowTarget(HWND, BOOL, IDesktopWindowTarget**)
)

// ICompositorInterop (COM, slot 3+)
const (
	compInteropCreateSurfaceForSwapChain = 4 // CreateCompositionSurfaceForSwapChain(IUnknown*, ICompositionSurface**)
)

// ICompositionTarget (WinRT, slot 6+)
const (
	compTargetPutRoot = 7 // put_Root(IVisual*)
)

// IContainerVisual (WinRT, slot 6+)
const (
	containerVisualGetChildren = 6 // get_Children(IVisualCollection**)
)

// IVisualCollection (WinRT, slot 6+)
const (
	visualCollectionInsertAtTop = 9 // InsertAtTop(IVisual*)
)

// IVisual (WinRT, slot 6+)
// Corrected slot numbering (C code had off-by-one for put_Size):
//   slot 21: put_Offset(Vector3)   EVector3 is 12 bytes, passed by pointer on x64
//   slot 37: put_Size(Vector2)     EVector2 is 8 bytes, packed in register on x64
const (
	visualPutOffset = 21
	visualPutSize   = 36
)

// ISpriteVisual (WinRT, slot 6+)
const (
	spriteVisualPutBrush = 7 // put_Brush(ICompositionBrush*)
)

// ============================================================
// Global state
// ============================================================

var (
	gHwnd, gHdc, gHglrc uintptr

	// D3D11
	gD3dDevice, gD3dCtx                        uintptr
	gSwapChain, gBackBuffer, gRtv              uintptr // OpenGL panel
	gVs, gPs, gInputLayout, gVb               uintptr
	gDxSwapChain, gDxRtv                       uintptr // D3D11 panel
	gVkSwapChain, gVkBackBuffer, gVkStagingTex uintptr // Vulkan panel D3D11 resources

	// Windows.UI.Composition objects
	gDqController    uintptr // IDispatcherQueueController (keep alive)
	gCompositor      uintptr // ICompositor
	gDesktopInterop  uintptr // ICompositorDesktopInterop
	gCompInterop     uintptr // ICompositorInterop
	gDesktopTarget   uintptr // IDesktopWindowTarget (IInspectable)
	gCompTarget      uintptr // ICompositionTarget
	gRootContainer   uintptr // IContainerVisual
	gRootVisual      uintptr // IVisual (QI from root container)
	gVisualCollection uintptr // IVisualCollection

	// Per-panel composition objects
	gGlSurface, gGlBrush, gGlCompBrush, gGlSprite, gGlVisual       uintptr
	gDxSurface, gDxBrush, gDxCompBrush, gDxSprite, gDxVisual        uintptr
	gVkSurface, gVkCompBrush2, gVkCompBrush, gVkSprite, gVkCompVisual uintptr

	// OpenGL objects
	gGlInteropDevice, gGlInteropObject uintptr
	gGlVbo                             [2]uint32
	gGlVao, gGlProgram                 uint32
	gGlRbo, gGlFbo                     uint32
	gGlPosAttrib, gGlColAttrib         int32

	// Vulkan objects
	gVkInstance, gVkPhysDev, gVkDevice                 uintptr
	gVkQueueFamily                                     uint32 = 0xFFFFFFFF
	gVkQueue                                           uintptr
	gVkOffImage, gVkOffMemory, gVkOffView              uintptr
	gVkReadbackBuf, gVkReadbackMem                     uintptr
	gVkRenderPass, gVkFramebuffer                      uintptr
	gVkPipelineLayout, gVkPipeline                     uintptr
	gVkCmdPool, gVkCmdBuf, gVkFence                    uintptr
)

// ============================================================
// Win32 window
// ============================================================

func wndProc(hwnd uintptr, msg uint32, wparam, lparam uintptr) uintptr {
	switch msg {
	case WM_DESTROY:
		dbgState("wndProc", "WM_DESTROY -> PostQuitMessage")
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
	dbgState("createAppWindow", "begin")
	className := mustUTF16Ptr("GoWinRTCompTriangle")
	cursor, _, _ := pLoadCursorW.Call(0, IDC_ARROW)
	wcx := WNDCLASSEXW{
		WndProc: syscall.NewCallback(wndProc), Instance: hInst,
		Cursor: cursor, ClassName: className,
	}
	wcx.Size = uint32(unsafe.Sizeof(wcx))
	pRegisterClassExW.Call(uintptr(unsafe.Pointer(&wcx)))
	dbgState("createAppWindow", "class registered")

	rc := RECT{0, 0, windowW, panelH}
	pAdjustWindowRect.Call(uintptr(unsafe.Pointer(&rc)), WS_OVERLAPPEDWINDOW, 0)

	title := mustUTF16Ptr("OpenGL + D3D11 + Vulkan via Windows.UI.Composition (Go)")
	gHwnd, _, _ = pCreateWindowExW.Call(
		WS_EX_NOREDIRECTIONBITMAP,
		uintptr(unsafe.Pointer(className)), uintptr(unsafe.Pointer(title)),
		WS_OVERLAPPEDWINDOW,
		CW_USEDEFAULT, CW_USEDEFAULT,
		uintptr(rc.Right-rc.Left), uintptr(rc.Bottom-rc.Top),
		0, 0, hInst, 0)
	if gHwnd == 0 {
		lastErr := syscall.GetLastError()
		dbgf("createAppWindow | CreateWindowExW failed: %v", lastErr)
		return lastErr
	}
	pShowWindow.Call(gHwnd, SW_SHOW)
	pUpdateWindow.Call(gHwnd)
	dbgState("createAppWindow", "ok")
	return nil
}

// ============================================================
// DXGI swap chain creation (shared by all 3 panels)
// ============================================================

func createSwapChainForComposition(device uintptr) (uintptr, error) {
	dbgState("createSwapChainForComposition", "begin")
	var dxgiDev uintptr
	if hr := comQI(device, &IID_IDXGIDevice, &dxgiDev); hr != 0 {
		dbgf("createSwapChainForComposition | QI(IDXGIDevice) failed: hr=0x%08X", uint32(hr))
		return 0, syscall.Errno(hr)
	}
	defer comRelease(dxgiDev)
	var adapter uintptr
	if hr := comCall(dxgiDev, dxgiDevGetAdapter, uintptr(unsafe.Pointer(&adapter))); hr != 0 {
		dbgf("createSwapChainForComposition | GetAdapter failed: hr=0x%08X", uint32(hr))
		return 0, syscall.Errno(hr)
	}
	defer comRelease(adapter)
	var factory uintptr
	if hr := comCall(adapter, dxgiObjGetParent, uintptr(unsafe.Pointer(&IID_IDXGIFactory2)), uintptr(unsafe.Pointer(&factory))); hr != 0 {
		dbgf("createSwapChainForComposition | GetParent(IDXGIFactory2) failed: hr=0x%08X", uint32(hr))
		return 0, syscall.Errno(hr)
	}
	defer comRelease(factory)

	desc := DXGI_SWAP_CHAIN_DESC1{
		Width: panelW, Height: panelH, Format: DXGI_FORMAT_B8G8R8A8_UNORM,
		SampleDesc: DXGI_SAMPLE_DESC{Count: 1},
		BufferUsage: DXGI_USAGE_RENDER_TARGET_OUTPUT, BufferCount: 2,
		Scaling: DXGI_SCALING_STRETCH, SwapEffect: DXGI_SWAP_EFFECT_FLIP_SEQUENTIAL,
		AlphaMode: DXGI_ALPHA_MODE_PREMULTIPLIED,
	}
	var sc uintptr
	if hr := comCall(factory, dxgiFactory2CreateSwapChainForComposition,
		device, uintptr(unsafe.Pointer(&desc)), 0, uintptr(unsafe.Pointer(&sc))); hr != 0 {
		dbgf("createSwapChainForComposition | CreateSwapChainForComposition failed: hr=0x%08X", uint32(hr))
		return 0, syscall.Errno(hr)
	}
	dbgState("createSwapChainForComposition", "ok")
	return sc, nil
}

func createRTV(sc uintptr) (uintptr, uintptr, error) {
	dbgState("createRTV", "begin")
	var bb uintptr
	if hr := comCall(sc, dxgiSwapGetBuffer, 0,
		uintptr(unsafe.Pointer(&IID_ID3D11Texture2D)), uintptr(unsafe.Pointer(&bb))); hr != 0 {
		dbgf("createRTV | GetBuffer failed: hr=0x%08X", uint32(hr))
		return 0, 0, syscall.Errno(hr)
	}
	var rtv uintptr
	if hr := comCall(gD3dDevice, d3dDevCreateRenderTargetView, bb, 0, uintptr(unsafe.Pointer(&rtv))); hr != 0 {
		dbgf("createRTV | CreateRenderTargetView failed: hr=0x%08X", uint32(hr))
		comRelease(bb)
		return 0, 0, syscall.Errno(hr)
	}
	dbgState("createRTV", "ok")
	return bb, rtv, nil
}

func compileShader(src []byte, entry, target string) (uintptr, error) {
	var blob, errBlob uintptr
	hr, _, _ := pD3DCompile.Call(uintptr(unsafe.Pointer(&src[0])), uintptr(len(src)-1),
		0, 0, 0, uintptr(unsafe.Pointer(cstr(entry))), uintptr(unsafe.Pointer(cstr(target))),
		D3DCOMPILE_ENABLE_STRICTNESS, 0,
		uintptr(unsafe.Pointer(&blob)), uintptr(unsafe.Pointer(&errBlob)))
	if errBlob != 0 {
		comRelease(errBlob)
	}
	if hr != 0 {
		return 0, syscall.Errno(hr)
	}
	return blob, nil
}

// ============================================================
// D3D11 initialization
// ============================================================

func initD3D11() error {
	dbgState("initD3D11", "begin")
	fl := [1]uint32{D3D_FEATURE_LEVEL_11_0}
	var flOut uint32
	hr, _, _ := pD3D11CreateDevice.Call(0, D3D_DRIVER_TYPE_HARDWARE, 0,
		D3D11_CREATE_DEVICE_BGRA_SUPPORT,
		uintptr(unsafe.Pointer(&fl[0])), 1, D3D11_SDK_VERSION,
		uintptr(unsafe.Pointer(&gD3dDevice)), uintptr(unsafe.Pointer(&flOut)),
		uintptr(unsafe.Pointer(&gD3dCtx)))
	if hr != 0 {
		dbgf("initD3D11 | D3D11CreateDevice failed: hr=0x%08X", uint32(hr))
		return syscall.Errno(hr)
	}

	var err error
	if gSwapChain, err = createSwapChainForComposition(gD3dDevice); err != nil {
		dbgf("initD3D11 | createSwapChainForComposition failed: %v", err)
		return err
	}
	if gBackBuffer, gRtv, err = createRTV(gSwapChain); err != nil {
		dbgf("initD3D11 | createRTV failed: %v", err)
		return err
	}

	// Compile shaders
	vsBlob, err := compileShader(hlslVS, "main", "vs_4_0")
	if err != nil {
		dbgf("initD3D11 | compile VS failed: %v", err)
		return err
	}
	defer comRelease(vsBlob)
	vsBuf := comCall(vsBlob, blobGetBufferPointer)
	vsSz := comCall(vsBlob, blobGetBufferSize)
	if hr := comCall(gD3dDevice, d3dDevCreateVertexShader, vsBuf, vsSz, 0, uintptr(unsafe.Pointer(&gVs))); hr != 0 {
		dbgf("initD3D11 | CreateVertexShader failed: hr=0x%08X", uint32(hr))
		return syscall.Errno(hr)
	}

	psBlob, err := compileShader(hlslPS, "main", "ps_4_0")
	if err != nil {
		dbgf("initD3D11 | compile PS failed: %v", err)
		return err
	}
	defer comRelease(psBlob)
	if hr := comCall(gD3dDevice, d3dDevCreatePixelShader,
		comCall(psBlob, blobGetBufferPointer), comCall(psBlob, blobGetBufferSize),
		0, uintptr(unsafe.Pointer(&gPs))); hr != 0 {
		dbgf("initD3D11 | CreatePixelShader failed: hr=0x%08X", uint32(hr))
		return syscall.Errno(hr)
	}

	// Input layout
	layout := [2]D3D11_INPUT_ELEMENT_DESC{
		{SemanticName: cstr("POSITION"), Format: DXGI_FORMAT_R32G32B32_FLOAT},
		{SemanticName: cstr("COLOR"), Format: DXGI_FORMAT_R32G32B32A32_FLOAT, AlignedByteOffset: 12},
	}
	if hr := comCall(gD3dDevice, d3dDevCreateInputLayout,
		uintptr(unsafe.Pointer(&layout[0])), 2, vsBuf, vsSz,
		uintptr(unsafe.Pointer(&gInputLayout))); hr != 0 {
		dbgf("initD3D11 | CreateInputLayout failed: hr=0x%08X", uint32(hr))
		return syscall.Errno(hr)
	}

	// Vertex buffer
	verts := [3]Vertex{
		{0, 0.5, 0.5, 1, 0, 0, 1}, {0.5, -0.5, 0.5, 0, 1, 0, 1}, {-0.5, -0.5, 0.5, 0, 0, 1, 1},
	}
	bd := D3D11_BUFFER_DESC{ByteWidth: uint32(unsafe.Sizeof(verts)), BindFlags: D3D11_BIND_VERTEX_BUFFER}
	sd := D3D11_SUBRESOURCE_DATA{SysMem: uintptr(unsafe.Pointer(&verts[0]))}
	if hr := comCall(gD3dDevice, d3dDevCreateBuffer,
		uintptr(unsafe.Pointer(&bd)), uintptr(unsafe.Pointer(&sd)),
		uintptr(unsafe.Pointer(&gVb))); hr != 0 {
		dbgf("initD3D11 | CreateBuffer failed: hr=0x%08X", uint32(hr))
		return syscall.Errno(hr)
	}
	dbgState("initD3D11", "ok")
	return nil
}

// ============================================================
// OpenGL initialization (WGL_NV_DX_interop)
// ============================================================

func getGLProc(name string) uintptr {
	ret, _, _ := pWglGetProcAddress.Call(uintptr(unsafe.Pointer(cstr(name))))
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
	glGetShaderInfoLog = getGLProc("glGetShaderInfoLog")
	glCreateProgram = getGLProc("glCreateProgram")
	glAttachShader = getGLProc("glAttachShader")
	glLinkProgram = getGLProc("glLinkProgram")
	glGetProgramiv = getGLProc("glGetProgramiv")
	glGetProgramInfoLog = getGLProc("glGetProgramInfoLog")
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

func compileGLShader(shaderType uint32, src string, label string) uintptr {
	sh, _, _ := syscall.SyscallN(glCreateShader, uintptr(shaderType))
	p := cstr(src)
	syscall.SyscallN(glShaderSource, sh, 1, uintptr(unsafe.Pointer(&p)), 0)
	syscall.SyscallN(glCompileShader, sh)
	var ok int32
	syscall.SyscallN(glGetShaderiv, sh, GL_COMPILE_STATUS, uintptr(unsafe.Pointer(&ok)))
	if ok == 0 {
		var logLen int32
		syscall.SyscallN(glGetShaderiv, sh, GL_INFO_LOG_LENGTH, uintptr(unsafe.Pointer(&logLen)))
		if logLen > 1 && glGetShaderInfoLog != 0 {
			buf := make([]byte, logLen)
			var written int32
			syscall.SyscallN(glGetShaderInfoLog, sh, uintptr(logLen), uintptr(unsafe.Pointer(&written)), uintptr(unsafe.Pointer(&buf[0])))
			msg := string(buf)
			dbgf("compileGLShader | %s failed: %s", label, msg)
		} else {
			dbgf("compileGLShader | %s failed: no info log", label)
		}
		return 0
	}
	return sh
}

func initOpenGL() error {
	dbgState("initOpenGL", "begin")
	gHdc, _, _ = pGetDC.Call(gHwnd)
	pfd := PIXELFORMATDESCRIPTOR{
		Flags: PFD_DRAW_TO_WINDOW | PFD_SUPPORT_OPENGL | PFD_DOUBLEBUFFER,
		PixelType: PFD_TYPE_RGBA, ColorBits: 32, DepthBits: 24, LayerType: PFD_MAIN_PLANE,
	}
	pfd.Size = uint16(unsafe.Sizeof(pfd))
	pfd.Version = 1
	pf, _, _ := pChoosePixelFormat.Call(gHdc, uintptr(unsafe.Pointer(&pfd)))
	pSetPixelFormat.Call(gHdc, pf, uintptr(unsafe.Pointer(&pfd)))

	legacyRC, _, _ := pWglCreateContext.Call(gHdc)
	pWglMakeCurrent.Call(gHdc, legacyRC)
	wglCreateContextAttribsARB = getGLProc("wglCreateContextAttribsARB")
	if wglCreateContextAttribsARB != 0 {
		attrs := [...]int32{WGL_CONTEXT_MAJOR_VERSION_ARB, 4, WGL_CONTEXT_MINOR_VERSION_ARB, 6,
			WGL_CONTEXT_FLAGS_ARB, 0, WGL_CONTEXT_PROFILE_MASK_ARB, WGL_CONTEXT_CORE_PROFILE_BIT_ARB, 0}
		rc, _, _ := syscall.SyscallN(wglCreateContextAttribsARB, gHdc, 0, uintptr(unsafe.Pointer(&attrs[0])))
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
	if err := loadGLExtensions(); err != nil {
		dbgf("initOpenGL | loadGLExtensions failed: %v", err)
		return err
	}
	if ver, _, _ := pGlGetString.Call(GL_VERSION); ver != 0 {
		dbgf("initOpenGL | GL_VERSION=%s", cstrToString(ver))
	}
	if sl, _, _ := pGlGetString.Call(GL_SHADING_LANGUAGE_VERSION); sl != 0 {
		dbgf("initOpenGL | GLSL_VERSION=%s", cstrToString(sl))
	}

	gGlInteropDevice, _, _ = syscall.SyscallN(wglDXOpenDeviceNV, gD3dDevice)
	if gGlInteropDevice == 0 {
		dbgState("initOpenGL", "wglDXOpenDeviceNV failed")
		return syscall.EINVAL
	}
	syscall.SyscallN(glGenRenderbuffers, 1, uintptr(unsafe.Pointer(&gGlRbo)))
	syscall.SyscallN(glBindRenderbuffer, GL_RENDERBUFFER, uintptr(gGlRbo))
	gGlInteropObject, _, _ = syscall.SyscallN(wglDXRegisterObjectNV,
		gGlInteropDevice, gBackBuffer, uintptr(gGlRbo), GL_RENDERBUFFER, WGL_ACCESS_READ_WRITE_NV)
	if gGlInteropObject == 0 {
		dbgState("initOpenGL", "wglDXRegisterObjectNV failed")
		return syscall.EINVAL
	}

	syscall.SyscallN(glGenFramebuffers, 1, uintptr(unsafe.Pointer(&gGlFbo)))
	syscall.SyscallN(glBindFramebuffer, GL_FRAMEBUFFER, uintptr(gGlFbo))
	syscall.SyscallN(glFramebufferRenderbuffer, GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, uintptr(gGlRbo))
	st, _, _ := syscall.SyscallN(glCheckFramebufferStatus, GL_FRAMEBUFFER)
	syscall.SyscallN(glBindFramebuffer, GL_FRAMEBUFFER, 0)
	if uint32(st) != GL_FRAMEBUFFER_COMPLETE {
		dbgf("initOpenGL | glCheckFramebufferStatus failed: status=0x%08X", uint32(st))
		return syscall.EINVAL
	}

	syscall.SyscallN(glGenVertexArrays, 1, uintptr(unsafe.Pointer(&gGlVao)))
	syscall.SyscallN(glBindVertexArray, uintptr(gGlVao))
	syscall.SyscallN(glGenBuffers, 2, uintptr(unsafe.Pointer(&gGlVbo[0])))

	pos := [9]float32{-0.5, -0.5, 0, 0.5, -0.5, 0, 0, 0.5, 0}
	syscall.SyscallN(glBindBuffer, GL_ARRAY_BUFFER, uintptr(gGlVbo[0]))
	syscall.SyscallN(glBufferData, GL_ARRAY_BUFFER, unsafe.Sizeof(pos), uintptr(unsafe.Pointer(&pos[0])), GL_STATIC_DRAW)
	col := [9]float32{0, 0, 1, 0, 1, 0, 1, 0, 0}
	syscall.SyscallN(glBindBuffer, GL_ARRAY_BUFFER, uintptr(gGlVbo[1]))
	syscall.SyscallN(glBufferData, GL_ARRAY_BUFFER, unsafe.Sizeof(col), uintptr(unsafe.Pointer(&col[0])), GL_STATIC_DRAW)

	vs := compileGLShader(GL_VERTEX_SHADER, glslVS, "vertex")
	fs := compileGLShader(GL_FRAGMENT_SHADER, glslPS, "fragment")
	if vs == 0 || fs == 0 {
		dbgState("initOpenGL", "shader compile failed")
		return syscall.EINVAL
	}
	prog, _, _ := syscall.SyscallN(glCreateProgram)
	syscall.SyscallN(glAttachShader, prog, vs)
	syscall.SyscallN(glAttachShader, prog, fs)
	syscall.SyscallN(glLinkProgram, prog)
	var lk int32
	syscall.SyscallN(glGetProgramiv, prog, GL_LINK_STATUS, uintptr(unsafe.Pointer(&lk)))
	if lk == 0 {
		dbgState("initOpenGL", "program link failed")
		return syscall.EINVAL
	}
	gGlProgram = uint32(prog)
	syscall.SyscallN(glUseProgram, prog)
	pa, _, _ := syscall.SyscallN(glGetAttribLocation, prog, uintptr(unsafe.Pointer(cstr("position"))))
	ca, _, _ := syscall.SyscallN(glGetAttribLocation, prog, uintptr(unsafe.Pointer(cstr("color"))))
	gGlPosAttrib = int32(pa)
	gGlColAttrib = int32(ca)
	syscall.SyscallN(glEnableVertexAttribArray, uintptr(gGlPosAttrib))
	syscall.SyscallN(glEnableVertexAttribArray, uintptr(gGlColAttrib))
	dbgState("initOpenGL", "ok")
	return nil
}

// ============================================================
// D3D11 second panel (center)
// ============================================================

func initD3D11SecondPanel() error {
	dbgState("initD3D11SecondPanel", "begin")
	var err error
	if gDxSwapChain, err = createSwapChainForComposition(gD3dDevice); err != nil {
		dbgf("initD3D11SecondPanel | createSwapChainForComposition failed: %v", err)
		return err
	}
	_, gDxRtv, err = createRTV(gDxSwapChain)
	if err != nil {
		dbgf("initD3D11SecondPanel | createRTV failed: %v", err)
		return err
	}
	dbgState("initD3D11SecondPanel", "ok")
	return err
}

// ============================================================
// Vulkan panel (right)  Eoffscreen render -> D3D11 staging copy
// ============================================================

func vkFindMemType(bits, props uint32) uint32 {
	var mp VkPhysicalDeviceMemoryProperties
	pvkGetPhysicalDeviceMemoryProperties.Call(gVkPhysDev, uintptr(unsafe.Pointer(&mp)))
	for i := uint32(0); i < mp.MemTypeCount; i++ {
		if bits&(1<<i) != 0 && mp.MemTypes[i].PropFlags&props == props {
			return i
		}
	}
	return 0xFFFFFFFF
}

func initVulkanPanel() error {
	dbgState("initVulkanPanel", "begin")
	var err error
	if gVkSwapChain, err = createSwapChainForComposition(gD3dDevice); err != nil {
		dbgf("initVulkanPanel | createSwapChainForComposition failed: %v", err)
		return err
	}
	dbgState("initVulkanPanel", "swap chain created")
	var bb uintptr
	dbgState("initVulkanPanel", "GetBuffer begin")
	if hr := comCall(gVkSwapChain, dxgiSwapGetBuffer, 0,
		uintptr(unsafe.Pointer(&IID_ID3D11Texture2D)), uintptr(unsafe.Pointer(&bb))); hr != 0 {
		dbgf("initVulkanPanel | GetBuffer failed: hr=0x%08X", uint32(hr))
		return syscall.Errno(hr)
	}
	dbgState("initVulkanPanel", "GetBuffer ok")
	gVkBackBuffer = bb
	td := D3D11_TEXTURE2D_DESC{
		Width: panelW, Height: panelH, MipLevels: 1, ArraySize: 1,
		Format: DXGI_FORMAT_B8G8R8A8_UNORM, SampleDesc: DXGI_SAMPLE_DESC{Count: 1},
		Usage: D3D11_USAGE_STAGING, CPUAccessFlags: D3D11_CPU_ACCESS_WRITE,
	}
	dbgState("initVulkanPanel", "CreateTexture2D(staging) begin")
	if hr := comCall(gD3dDevice, d3dDevCreateTexture2D,
		uintptr(unsafe.Pointer(&td)), 0, uintptr(unsafe.Pointer(&gVkStagingTex))); hr != 0 {
		dbgf("initVulkanPanel | CreateTexture2D(staging) failed: hr=0x%08X", uint32(hr))
		return syscall.Errno(hr)
	}
	dbgState("initVulkanPanel", "CreateTexture2D(staging) ok")

	// Create Vulkan instance
	appName := cstr("triangle_vk_panel")
	ai := VkApplicationInfo{SType: VK_STRUCTURE_TYPE_APPLICATION_INFO, PApplicationName: appName,
		ApiVersion: (1 << 22) | (4 << 12)}
	ici := VkInstanceCreateInfo{SType: VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO, PApplicationInfo: &ai}
	dbgState("initVulkanPanel", "vkCreateInstance begin")
	vr, _, _ := pvkCreateInstance.Call(uintptr(unsafe.Pointer(&ici)), 0, uintptr(unsafe.Pointer(&gVkInstance)))
	if int32(vr) != VK_SUCCESS {
		dbgf("initVulkanPanel | vkCreateInstance failed: vr=%d", int32(vr))
		return syscall.EINVAL
	}
	dbgState("initVulkanPanel", "vkCreateInstance ok")

	// Enumerate and pick physical device
	var devCount uint32
	dbgState("initVulkanPanel", "vkEnumeratePhysicalDevices(count) begin")
	pvkEnumeratePhysicalDevices.Call(gVkInstance, uintptr(unsafe.Pointer(&devCount)), 0)
	if devCount == 0 {
		dbgState("initVulkanPanel", "no physical device")
		return syscall.EINVAL
	}
	dbgf("initVulkanPanel | physical devices=%d", devCount)
	devs := make([]uintptr, devCount)
	dbgState("initVulkanPanel", "vkEnumeratePhysicalDevices(list) begin")
	pvkEnumeratePhysicalDevices.Call(gVkInstance, uintptr(unsafe.Pointer(&devCount)), uintptr(unsafe.Pointer(&devs[0])))
	for _, d := range devs {
		var qc uint32
		pvkGetPhysicalDeviceQueueFamilyProperties.Call(d, uintptr(unsafe.Pointer(&qc)), 0)
		qp := make([]VkQueueFamilyProperties, qc)
		pvkGetPhysicalDeviceQueueFamilyProperties.Call(d, uintptr(unsafe.Pointer(&qc)), uintptr(unsafe.Pointer(&qp[0])))
		for i := uint32(0); i < qc; i++ {
			if qp[i].QueueFlags&VK_QUEUE_GRAPHICS_BIT != 0 {
				gVkPhysDev = d
				gVkQueueFamily = i
				break
			}
		}
		if gVkPhysDev != 0 {
			break
		}
	}
	if gVkPhysDev == 0 {
		dbgState("initVulkanPanel", "no graphics queue family")
		return syscall.EINVAL
	}
	dbgf("initVulkanPanel | selected queue family=%d", gVkQueueFamily)

	// Create logical device
	prio := float32(1.0)
	qci := VkDeviceQueueCreateInfo{SType: VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
		QueueFamilyIndex: gVkQueueFamily, QueueCount: 1, PQueuePriorities: &prio}
	dci := VkDeviceCreateInfo{SType: VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO,
		QueueCreateInfoCount: 1, PQueueCreateInfos: uintptr(unsafe.Pointer(&qci))}
	dbgState("initVulkanPanel", "vkCreateDevice begin")
	vr, _, _ = pvkCreateDevice.Call(gVkPhysDev, uintptr(unsafe.Pointer(&dci)), 0, uintptr(unsafe.Pointer(&gVkDevice)))
	if int32(vr) != VK_SUCCESS {
		dbgf("initVulkanPanel | vkCreateDevice failed: vr=%d", int32(vr))
		return syscall.EINVAL
	}
	dbgState("initVulkanPanel", "vkCreateDevice ok")
	pvkGetDeviceQueue.Call(gVkDevice, uintptr(gVkQueueFamily), 0, uintptr(unsafe.Pointer(&gVkQueue)))
	dbgState("initVulkanPanel", "vkGetDeviceQueue ok")

	// Create offscreen image
	imgci := VkImageCreateInfo{SType: VK_STRUCTURE_TYPE_IMAGE_CREATE_INFO,
		ImageType: VK_IMAGE_TYPE_2D, Format: VK_FORMAT_B8G8R8A8_UNORM,
		ExtentW: panelW, ExtentH: panelH, ExtentD: 1, MipLevels: 1, ArrayLayers: 1,
		Samples: VK_SAMPLE_COUNT_1_BIT, Tiling: VK_IMAGE_TILING_OPTIMAL,
		Usage: VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT | VK_IMAGE_USAGE_TRANSFER_SRC_BIT}
	dbgState("initVulkanPanel", "vkCreateImage begin")
	vr, _, _ = pvkCreateImage.Call(gVkDevice, uintptr(unsafe.Pointer(&imgci)), 0, uintptr(unsafe.Pointer(&gVkOffImage)))
	if int32(vr) != VK_SUCCESS {
		dbgf("initVulkanPanel | vkCreateImage failed: vr=%d", int32(vr))
		return syscall.EINVAL
	}
	var mr VkMemoryRequirements
	pvkGetImageMemoryRequirements.Call(gVkDevice, gVkOffImage, uintptr(unsafe.Pointer(&mr)))
	mai := VkMemoryAllocateInfo{SType: VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
		AllocationSize: mr.Size, MemoryTypeIndex: vkFindMemType(mr.MemoryTypeBits, VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT)}
	dbgState("initVulkanPanel", "vkAllocateMemory(offscreen) begin")
	vr, _, _ = pvkAllocateMemory.Call(gVkDevice, uintptr(unsafe.Pointer(&mai)), 0, uintptr(unsafe.Pointer(&gVkOffMemory)))
	if int32(vr) != VK_SUCCESS {
		dbgf("initVulkanPanel | vkAllocateMemory(offscreen) failed: vr=%d", int32(vr))
		return syscall.EINVAL
	}
	pvkBindImageMemory.Call(gVkDevice, gVkOffImage, gVkOffMemory, 0)
	dbgState("initVulkanPanel", "vkBindImageMemory ok")

	// Image view
	ivci := VkImageViewCreateInfo{SType: VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO,
		Image: gVkOffImage, ViewType: VK_IMAGE_VIEW_TYPE_2D, Format: VK_FORMAT_B8G8R8A8_UNORM,
		AspectMask: VK_IMAGE_ASPECT_COLOR_BIT, LevelCount: 1, LayerCount: 1}
	dbgState("initVulkanPanel", "vkCreateImageView begin")
	vr, _, _ = pvkCreateImageView.Call(gVkDevice, uintptr(unsafe.Pointer(&ivci)), 0, uintptr(unsafe.Pointer(&gVkOffView)))
	if int32(vr) != VK_SUCCESS {
		dbgf("initVulkanPanel | vkCreateImageView failed: vr=%d", int32(vr))
		return syscall.EINVAL
	}

	// Readback buffer
	bci := VkBufferCreateInfo{SType: VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO,
		Size: uint64(panelW) * uint64(panelH) * 4, Usage: VK_BUFFER_USAGE_TRANSFER_DST_BIT}
	dbgState("initVulkanPanel", "vkCreateBuffer(readback) begin")
	vr, _, _ = pvkCreateBuffer.Call(gVkDevice, uintptr(unsafe.Pointer(&bci)), 0, uintptr(unsafe.Pointer(&gVkReadbackBuf)))
	if int32(vr) != VK_SUCCESS {
		dbgf("initVulkanPanel | vkCreateBuffer(readback) failed: vr=%d", int32(vr))
		return syscall.EINVAL
	}
	pvkGetBufferMemoryRequirements.Call(gVkDevice, gVkReadbackBuf, uintptr(unsafe.Pointer(&mr)))
	mai2 := VkMemoryAllocateInfo{SType: VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
		AllocationSize: mr.Size, MemoryTypeIndex: vkFindMemType(mr.MemoryTypeBits, VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT|VK_MEMORY_PROPERTY_HOST_COHERENT_BIT)}
	dbgState("initVulkanPanel", "vkAllocateMemory(readback) begin")
	vr, _, _ = pvkAllocateMemory.Call(gVkDevice, uintptr(unsafe.Pointer(&mai2)), 0, uintptr(unsafe.Pointer(&gVkReadbackMem)))
	if int32(vr) != VK_SUCCESS {
		dbgf("initVulkanPanel | vkAllocateMemory(readback) failed: vr=%d", int32(vr))
		return syscall.EINVAL
	}
	pvkBindBufferMemory.Call(gVkDevice, gVkReadbackBuf, gVkReadbackMem, 0)
	dbgState("initVulkanPanel", "vkBindBufferMemory ok")

	// Render pass
	att := VkAttachmentDescription{Format: VK_FORMAT_B8G8R8A8_UNORM, Samples: VK_SAMPLE_COUNT_1_BIT,
		LoadOp: VK_ATTACHMENT_LOAD_OP_CLEAR, StoreOp: VK_ATTACHMENT_STORE_OP_STORE,
		StencilLoadOp: VK_ATTACHMENT_LOAD_OP_DONT_CARE, StencilStoreOp: VK_ATTACHMENT_STORE_OP_DONT_CARE,
		FinalLayout: VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL}
	aref := VkAttachmentReference{Layout: VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL}
	sub := VkSubpassDescription{ColorAttachmentCount: 1, PColorAttachments: &aref}
	rpci := VkRenderPassCreateInfo{SType: VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO,
		AttachmentCount: 1, PAttachments: &att, SubpassCount: 1, PSubpasses: &sub}
	dbgState("initVulkanPanel", "vkCreateRenderPass begin")
	vr, _, _ = pvkCreateRenderPass.Call(gVkDevice, uintptr(unsafe.Pointer(&rpci)), 0, uintptr(unsafe.Pointer(&gVkRenderPass)))
	if int32(vr) != VK_SUCCESS {
		dbgf("initVulkanPanel | vkCreateRenderPass failed: vr=%d", int32(vr))
		return syscall.EINVAL
	}

	// Framebuffer
	atts := [1]uintptr{gVkOffView}
	fbci := VkFramebufferCreateInfo{SType: VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO,
		RenderPass: gVkRenderPass, AttachmentCount: 1, PAttachments: &atts[0],
		Width: panelW, Height: panelH, Layers: 1}
	dbgState("initVulkanPanel", "vkCreateFramebuffer begin")
	vr, _, _ = pvkCreateFramebuffer.Call(gVkDevice, uintptr(unsafe.Pointer(&fbci)), 0, uintptr(unsafe.Pointer(&gVkFramebuffer)))
	if int32(vr) != VK_SUCCESS {
		dbgf("initVulkanPanel | vkCreateFramebuffer failed: vr=%d", int32(vr))
		return syscall.EINVAL
	}

	// Load SPIR-V and create pipeline
	vsSpv, e := os.ReadFile("hello_vert.spv")
	if e != nil {
		dbgf("initVulkanPanel | ReadFile(hello_vert.spv) failed: %v", e)
		return e
	}
	fsSpv, e := os.ReadFile("hello_frag.spv")
	if e != nil {
		dbgf("initVulkanPanel | ReadFile(hello_frag.spv) failed: %v", e)
		return e
	}
	var vsMod, fsMod uintptr
	smci := VkShaderModuleCreateInfo{SType: VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO,
		CodeSize: uintptr(len(vsSpv)), PCode: uintptr(unsafe.Pointer(&vsSpv[0]))}
	pvkCreateShaderModule.Call(gVkDevice, uintptr(unsafe.Pointer(&smci)), 0, uintptr(unsafe.Pointer(&vsMod)))
	smci.CodeSize = uintptr(len(fsSpv))
	smci.PCode = uintptr(unsafe.Pointer(&fsSpv[0]))
	pvkCreateShaderModule.Call(gVkDevice, uintptr(unsafe.Pointer(&smci)), 0, uintptr(unsafe.Pointer(&fsMod)))

	mainN := cstr("main")
	stages := [2]VkPipelineShaderStageCreateInfo{
		{SType: VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO, Stage: VK_SHADER_STAGE_VERTEX_BIT, Module: vsMod, PName: mainN},
		{SType: VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO, Stage: VK_SHADER_STAGE_FRAGMENT_BIT, Module: fsMod, PName: mainN},
	}
	vi := VkPipelineVertexInputStateCreateInfo{SType: VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO}
	ia := VkPipelineInputAssemblyStateCreateInfo{SType: VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO, Topology: VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST}
	vp := VkViewport{Width: panelW, Height: panelH, MaxDepth: 1}
	sc := VkRect2D{ExtentW: panelW, ExtentH: panelH}
	vps := VkPipelineViewportStateCreateInfo{SType: VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO,
		VPCount: 1, PViewports: &vp, ScissorCount: 1, PScissors: &sc}
	rs := VkPipelineRasterizationStateCreateInfo{SType: VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO,
		PolygonMode: VK_POLYGON_MODE_FILL, CullMode: VK_CULL_MODE_BACK_BIT, FrontFace: VK_FRONT_FACE_CLOCKWISE, LineWidth: 1}
	ms := VkPipelineMultisampleStateCreateInfo{SType: VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO, RasterSamples: VK_SAMPLE_COUNT_1_BIT}
	cba := VkPipelineColorBlendAttachmentState{ColorWriteMask: 0xF}
	cbs := VkPipelineColorBlendStateCreateInfo{SType: VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO, AttachmentCount: 1, PAttachments: &cba}
	plci := VkPipelineLayoutCreateInfo{SType: VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO}
	pvkCreatePipelineLayout.Call(gVkDevice, uintptr(unsafe.Pointer(&plci)), 0, uintptr(unsafe.Pointer(&gVkPipelineLayout)))

	gpci := VkGraphicsPipelineCreateInfo{SType: VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO,
		StageCount: 2, PStages: uintptr(unsafe.Pointer(&stages[0])),
		PVertexInputState: uintptr(unsafe.Pointer(&vi)), PInputAssemblyState: uintptr(unsafe.Pointer(&ia)),
		PViewportState: uintptr(unsafe.Pointer(&vps)), PRasterizationState: uintptr(unsafe.Pointer(&rs)),
		PMultisampleState: uintptr(unsafe.Pointer(&ms)), PColorBlendState: uintptr(unsafe.Pointer(&cbs)),
		Layout: gVkPipelineLayout, RenderPass: gVkRenderPass, BasePipelineIndex: -1}
	pvkCreateGraphicsPipelines.Call(gVkDevice, 0, 1, uintptr(unsafe.Pointer(&gpci)), 0, uintptr(unsafe.Pointer(&gVkPipeline)))

	// Command pool + buffer + fence
	cpci := VkCommandPoolCreateInfo{SType: VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO,
		Flags: VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT, QueueFamilyIndex: gVkQueueFamily}
	pvkCreateCommandPool.Call(gVkDevice, uintptr(unsafe.Pointer(&cpci)), 0, uintptr(unsafe.Pointer(&gVkCmdPool)))
	cbai := VkCommandBufferAllocateInfo{SType: VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
		CommandPool: gVkCmdPool, Count: 1}
	pvkAllocateCommandBuffers.Call(gVkDevice, uintptr(unsafe.Pointer(&cbai)), uintptr(unsafe.Pointer(&gVkCmdBuf)))
	fci := VkFenceCreateInfo{SType: VK_STRUCTURE_TYPE_FENCE_CREATE_INFO, Flags: VK_FENCE_CREATE_SIGNALED_BIT}
	pvkCreateFence.Call(gVkDevice, uintptr(unsafe.Pointer(&fci)), 0, uintptr(unsafe.Pointer(&gVkFence)))

	pvkDestroyShaderModule.Call(gVkDevice, vsMod, 0)
	pvkDestroyShaderModule.Call(gVkDevice, fsMod, 0)
	dbgState("initVulkanPanel", "ok")
	return nil
}

// ============================================================
// Windows.UI.Composition setup
// ============================================================

func initComposition() error {
	dbgState("initComposition", "begin")

	// Initialize WinRT (STA for windowed app with message pump)
	pRoInitialize.Call(RO_INIT_SINGLETHREADED)

	// Create DispatcherQueue on current thread (required by Compositor)
	// DispatcherQueueOptions is 12 bytes  Epassed by pointer on x64 ABI
	opts := DispatcherQueueOptions{
		Size:          12,
		ThreadType:    DQTYPE_THREAD_CURRENT,
		ApartmentType: DQTAT_COM_NONE, // COM already initialized by RoInitialize
	}
	hr, _, _ := pCreateDispatcherQueueController.Call(
		uintptr(unsafe.Pointer(&opts)),
		uintptr(unsafe.Pointer(&gDqController)),
	)
	if hr != 0 {
		dbgf("initComposition | CreateDispatcherQueueController failed: hr=0x%08X", uint32(hr))
		return syscall.Errno(hr)
	}
	dbgState("initComposition", "DispatcherQueue created")

	// Activate Windows.UI.Composition.Compositor via RoActivateInstance
	hsCompositor, _, _ := createStringRef("Windows.UI.Composition.Compositor")
	var inspectable uintptr
	hr, _, _ = pRoActivateInstance.Call(hsCompositor, uintptr(unsafe.Pointer(&inspectable)))
	if hr != 0 {
		dbgf("initComposition | RoActivateInstance(Compositor) failed: hr=0x%08X", uint32(hr))
		return syscall.Errno(hr)
	}
	dbgState("initComposition", "Compositor activated")

	// RoActivateInstance returns the default interface for Compositor.
	// Keep this pointer as the compositor instance and release it in cleanup().
	gCompositor = inspectable

	// QI for ICompositorDesktopInterop (COM interop for HWND target)
	if hr := comQI(inspectable, &IID_ICompositorDesktopInterop, &gDesktopInterop); hr != 0 {
		dbgf("initComposition | QI(ICompositorDesktopInterop) failed: hr=0x%08X", uint32(hr))
		return syscall.Errno(hr)
	}

	// QI for ICompositorInterop (COM interop for swap chain ↁEsurface)
	if hr := comQI(inspectable, &IID_ICompositorInterop, &gCompInterop); hr != 0 {
		dbgf("initComposition | QI(ICompositorInterop) failed: hr=0x%08X", uint32(hr))
		return syscall.Errno(hr)
	}

	// Create desktop window target for our HWND
	if hr := comCall(gDesktopInterop, desktopInteropCreateTarget,
		gHwnd, 1, // isTopmost = TRUE
		uintptr(unsafe.Pointer(&gDesktopTarget))); hr != 0 {
		dbgf("initComposition | CreateDesktopWindowTarget failed: hr=0x%08X", uint32(hr))
		return syscall.Errno(hr)
	}
	dbgState("initComposition", "DesktopWindowTarget created")

	// QI desktop target for ICompositionTarget (to set root visual)
	if hr := comQI(gDesktopTarget, &IID_ICompositionTarget, &gCompTarget); hr != 0 {
		dbgf("initComposition | QI(ICompositionTarget) failed: hr=0x%08X", uint32(hr))
		return syscall.Errno(hr)
	}

	// Create ContainerVisual as root
	if hr := comCall(gCompositor, compositorCreateContainerVisual,
		uintptr(unsafe.Pointer(&gRootContainer))); hr != 0 {
		dbgf("initComposition | CreateContainerVisual failed: hr=0x%08X", uint32(hr))
		return syscall.Errno(hr)
	}

	// QI root container for IVisual (needed for put_Root)
	if hr := comQI(gRootContainer, &IID_IVisual, &gRootVisual); hr != 0 {
		dbgf("initComposition | QI(IVisual root) failed: hr=0x%08X", uint32(hr))
		return syscall.Errno(hr)
	}

	// Set root visual on composition target
	if hr := comCall(gCompTarget, compTargetPutRoot, gRootVisual); hr != 0 {
		dbgf("initComposition | put_Root failed: hr=0x%08X", uint32(hr))
		return syscall.Errno(hr)
	}

	// Get children collection from root container
	if hr := comCall(gRootContainer, containerVisualGetChildren,
		uintptr(unsafe.Pointer(&gVisualCollection))); hr != 0 {
		dbgf("initComposition | GetChildren failed: hr=0x%08X", uint32(hr))
		return syscall.Errno(hr)
	}

	// Add sprite visuals for each swap chain panel
	if err := addSpriteForSwapChain(gSwapChain, 0,
		&gGlSurface, &gGlBrush, &gGlCompBrush, &gGlSprite, &gGlVisual); err != nil {
		dbgf("initComposition | addSpriteForSwapChain(GL) failed: %v", err)
		return err
	}
	if err := addSpriteForSwapChain(gDxSwapChain, panelW,
		&gDxSurface, &gDxBrush, &gDxCompBrush, &gDxSprite, &gDxVisual); err != nil {
		dbgf("initComposition | addSpriteForSwapChain(D3D11) failed: %v", err)
		return err
	}
	if err := addSpriteForSwapChain(gVkSwapChain, panelW*2,
		&gVkSurface, &gVkCompBrush2, &gVkCompBrush, &gVkSprite, &gVkCompVisual); err != nil {
		dbgf("initComposition | addSpriteForSwapChain(Vulkan) failed: %v", err)
		return err
	}

	dbgState("initComposition", "ok")
	return nil
}

// addSpriteForSwapChain creates a SpriteVisual backed by a swap chain surface
// and adds it to the root container at the given X offset.
func addSpriteForSwapChain(
	swapChain uintptr, offsetX float32,
	pSurface, pBrush, pCompBrush, pSprite, pVisual *uintptr,
) error {
	dbgf("addSpriteForSwapChain | begin offsetX=%.1f", offsetX)
	// Create composition surface from swap chain
	// ICompositorInterop::CreateCompositionSurfaceForSwapChain (COM slot 4)
	if hr := comCall(gCompInterop, compInteropCreateSurfaceForSwapChain,
		swapChain, uintptr(unsafe.Pointer(pSurface))); hr != 0 {
		dbgf("addSpriteForSwapChain | CreateSurfaceForSwapChain failed: hr=0x%08X", uint32(hr))
		return syscall.Errno(hr)
	}
	dbgf("addSpriteForSwapChain | surface created offsetX=%.1f", offsetX)

	// Create surface brush from the composition surface
	// ICompositor::CreateSurfaceBrush(ICompositionSurface) (WinRT slot 24)
	if hr := comCall(gCompositor, compositorCreateSurfaceBrush,
		*pSurface, uintptr(unsafe.Pointer(pBrush))); hr != 0 {
		dbgf("addSpriteForSwapChain | CreateSurfaceBrush failed: hr=0x%08X", uint32(hr))
		return syscall.Errno(hr)
	}
	dbgf("addSpriteForSwapChain | surface brush created offsetX=%.1f", offsetX)

	// QI brush for ICompositionBrush (needed by ISpriteVisual::put_Brush)
	if hr := comQI(*pBrush, &IID_ICompositionBrush, pCompBrush); hr != 0 {
		dbgf("addSpriteForSwapChain | QI(ICompositionBrush) failed: hr=0x%08X", uint32(hr))
		return syscall.Errno(hr)
	}
	dbgf("addSpriteForSwapChain | ICompositionBrush acquired offsetX=%.1f", offsetX)

	// Create sprite visual
	// ICompositor::CreateSpriteVisual (WinRT slot 22)
	if hr := comCall(gCompositor, compositorCreateSpriteVisual,
		uintptr(unsafe.Pointer(pSprite))); hr != 0 {
		dbgf("addSpriteForSwapChain | CreateSpriteVisual failed: hr=0x%08X", uint32(hr))
		return syscall.Errno(hr)
	}
	dbgf("addSpriteForSwapChain | sprite visual created offsetX=%.1f", offsetX)

	// Set brush on sprite visual
	// ISpriteVisual::put_Brush (WinRT slot 7)
	if hr := comCall(*pSprite, spriteVisualPutBrush, *pCompBrush); hr != 0 {
		dbgf("addSpriteForSwapChain | put_Brush failed: hr=0x%08X", uint32(hr))
		return syscall.Errno(hr)
	}

	// QI sprite for IVisual (to set size/offset and add to collection)
	if hr := comQI(*pSprite, &IID_IVisual, pVisual); hr != 0 {
		dbgf("addSpriteForSwapChain | QI(IVisual) failed: hr=0x%08X", uint32(hr))
		return syscall.Errno(hr)
	}
	dbgf("addSpriteForSwapChain | IVisual acquired offsetX=%.1f", offsetX)

	// Set size: IVisual::put_Size (WinRT slot 37)
	// Vector2 is 8 bytes ↁEpassed by value in a register on x64
	if hr := comCall(*pVisual, visualPutSize, packVector2(panelW, panelH)); hr != 0 {
		dbgf("addSpriteForSwapChain | put_Size failed: hr=0x%08X", uint32(hr))
		return syscall.Errno(hr)
	}

	// Set offset: IVisual::put_Offset (WinRT slot 21)
	// Vector3 is 12 bytes ↁEpassed by pointer on x64
	offset := Vector3{X: offsetX}
	if hr := comCall(*pVisual, visualPutOffset, uintptr(unsafe.Pointer(&offset))); hr != 0 {
		dbgf("addSpriteForSwapChain | put_Offset failed: hr=0x%08X", uint32(hr))
		return syscall.Errno(hr)
	}

	// Insert into root container's children collection
	// IVisualCollection::InsertAtTop (WinRT slot 9)
	if hr := comCall(gVisualCollection, visualCollectionInsertAtTop, *pVisual); hr != 0 {
		dbgf("addSpriteForSwapChain | InsertAtTop failed: hr=0x%08X", uint32(hr))
		return syscall.Errno(hr)
	}

	dbgf("addSpriteForSwapChain | ok offsetX=%.1f", offsetX)
	return nil
}

// ============================================================
// Render functions
// ============================================================

func renderOpenGLPanel() {
	if gGlInteropDevice == 0 || gGlInteropObject == 0 {
		return
	}
	pWglMakeCurrent.Call(gHdc, gHglrc)
	objs := [1]uintptr{gGlInteropObject}
	if r, _, _ := syscall.SyscallN(wglDXLockObjectsNV, gGlInteropDevice, 1, uintptr(unsafe.Pointer(&objs[0]))); r == 0 {
		return
	}
	syscall.SyscallN(glBindFramebuffer, GL_FRAMEBUFFER, uintptr(gGlFbo))
	pGlViewport.Call(0, 0, panelW, panelH)
	pGlClearColor.Call(f32bits(0.05), f32bits(0.05), f32bits(0.15), f32bits(1.0))
	pGlClear.Call(GL_COLOR_BUFFER_BIT)
	syscall.SyscallN(glUseProgram, uintptr(gGlProgram))
	syscall.SyscallN(glBindBuffer, GL_ARRAY_BUFFER, uintptr(gGlVbo[0]))
	syscall.SyscallN(glVertexAttribPointer, uintptr(gGlPosAttrib), 3, GL_FLOAT, GL_FALSE, 0, 0)
	syscall.SyscallN(glBindBuffer, GL_ARRAY_BUFFER, uintptr(gGlVbo[1]))
	syscall.SyscallN(glVertexAttribPointer, uintptr(gGlColAttrib), 3, GL_FLOAT, GL_FALSE, 0, 0)
	pGlDrawArrays.Call(GL_TRIANGLES, 0, 3)
	pGlFlush.Call()
	syscall.SyscallN(glBindFramebuffer, GL_FRAMEBUFFER, 0)
	syscall.SyscallN(wglDXUnlockObjectsNV, gGlInteropDevice, 1, uintptr(unsafe.Pointer(&objs[0])))
	comCall(gSwapChain, dxgiSwapPresent, 1, 0)
}

func renderD3D11Panel() {
	if gDxSwapChain == 0 || gDxRtv == 0 {
		return
	}
	vp := D3D11_VIEWPORT{Width: panelW, Height: panelH, MaxDepth: 1}
	comCall(gD3dCtx, d3dCtxRSSetViewports, 1, uintptr(unsafe.Pointer(&vp)))
	rtvs := [1]uintptr{gDxRtv}
	comCall(gD3dCtx, d3dCtxOMSetRenderTargets, 1, uintptr(unsafe.Pointer(&rtvs[0])), 0)
	cc := [4]float32{0.05, 0.15, 0.05, 1}
	comCall(gD3dCtx, d3dCtxClearRenderTargetView, gDxRtv, uintptr(unsafe.Pointer(&cc[0])))
	stride := uint32(vertexSize)
	offset := uint32(0)
	vbs := [1]uintptr{gVb}
	comCall(gD3dCtx, d3dCtxIASetInputLayout, gInputLayout)
	comCall(gD3dCtx, d3dCtxIASetVertexBuffers, 0, 1, uintptr(unsafe.Pointer(&vbs[0])), uintptr(unsafe.Pointer(&stride)), uintptr(unsafe.Pointer(&offset)))
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

	bi := VkCommandBufferBeginInfo{SType: VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO}
	pvkBeginCommandBuffer.Call(gVkCmdBuf, uintptr(unsafe.Pointer(&bi)))
	cv := VkClearValue{R: 0.15, G: 0.05, B: 0.05, A: 1}
	rpbi := VkRenderPassBeginInfo{SType: VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO,
		RenderPass: gVkRenderPass, Framebuffer: gVkFramebuffer,
		RenderAreaW: panelW, RenderAreaH: panelH, ClearValueCount: 1, PClearValues: &cv}
	pvkCmdBeginRenderPass.Call(gVkCmdBuf, uintptr(unsafe.Pointer(&rpbi)), VK_SUBPASS_CONTENTS_INLINE)
	pvkCmdBindPipeline.Call(gVkCmdBuf, VK_PIPELINE_BIND_POINT_GRAPHICS, gVkPipeline)
	pvkCmdDraw.Call(gVkCmdBuf, 3, 1, 0, 0)
	pvkCmdEndRenderPass.Call(gVkCmdBuf)

	region := VkBufferImageCopy{BufRowLength: panelW, BufImgH: panelH,
		AspectMask: VK_IMAGE_ASPECT_COLOR_BIT, LayerCount: 1, ExtW: panelW, ExtH: panelH, ExtD: 1}
	pvkCmdCopyImageToBuffer.Call(gVkCmdBuf, gVkOffImage, VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL, gVkReadbackBuf, 1, uintptr(unsafe.Pointer(&region)))
	pvkEndCommandBuffer.Call(gVkCmdBuf)

	cmdBufs := [1]uintptr{gVkCmdBuf}
	si := VkSubmitInfo{SType: VK_STRUCTURE_TYPE_SUBMIT_INFO, CmdBufCount: 1, PCmdBufs: &cmdBufs[0]}
	pvkQueueSubmit.Call(gVkQueue, 1, uintptr(unsafe.Pointer(&si)), gVkFence)
	pvkWaitForFences.Call(gVkDevice, 1, uintptr(unsafe.Pointer(&fences[0])), VK_TRUE, maxU64)

	var vkData uintptr
	pvkMapMemory.Call(gVkDevice, gVkReadbackMem, 0, uintptr(uint64(panelW)*uint64(panelH)*4), 0, uintptr(unsafe.Pointer(&vkData)))
	var mapped D3D11_MAPPED_SUBRESOURCE
	if hr := comCall(gD3dCtx, d3dCtxMap, gVkStagingTex, 0, D3D11_MAP_WRITE, 0, uintptr(unsafe.Pointer(&mapped))); hr == 0 {
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
	dbgState("cleanup", "begin")

	// Release composition objects (reverse order)
	comRelease(gVisualCollection)
	comRelease(gVkCompVisual)
	comRelease(gVkSprite)
	comRelease(gVkCompBrush)
	comRelease(gVkCompBrush2)
	comRelease(gVkSurface)
	comRelease(gDxVisual)
	comRelease(gDxSprite)
	comRelease(gDxCompBrush)
	comRelease(gDxBrush)
	comRelease(gDxSurface)
	comRelease(gGlVisual)
	comRelease(gGlSprite)
	comRelease(gGlCompBrush)
	comRelease(gGlBrush)
	comRelease(gGlSurface)
	comRelease(gRootVisual)
	comRelease(gRootContainer)
	comRelease(gCompTarget)
	comRelease(gDesktopTarget)
	comRelease(gCompInterop)
	comRelease(gDesktopInterop)
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

	// OpenGL interop cleanup
	if gGlInteropObject != 0 && gGlInteropDevice != 0 {
		syscall.SyscallN(wglDXUnregisterObjectNV, gGlInteropDevice, gGlInteropObject)
	}
	if gGlInteropDevice != 0 {
		syscall.SyscallN(wglDXCloseDeviceNV, gGlInteropDevice)
	}
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
	if gHdc != 0 {
		pReleaseDC.Call(gHwnd, gHdc)
	}

	// D3D11 cleanup
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

	// DispatcherQueue controller
	comRelease(gDqController)

	// WinRT uninit
	pRoUninitialize.Call()

	dbgState("cleanup", "ok")
}

// ============================================================
// Entry point
// ============================================================

func main() {
	dbgState("main", "start")
	hInst, _, _ := pGetModuleHandleW.Call(0)

	if err := createAppWindow(hInst); err != nil {
		dbgf("main | createAppWindow failed: %v", err)
		return
	}
	if err := initD3D11(); err != nil {
		dbgf("main | initD3D11 failed: %v", err)
		cleanup()
		return
	}
	if err := initOpenGL(); err != nil {
		dbgf("main | initOpenGL failed: %v", err)
		cleanup()
		return
	}
	if err := initD3D11SecondPanel(); err != nil {
		dbgf("main | initD3D11SecondPanel failed: %v", err)
		cleanup()
		return
	}
	if err := initVulkanPanel(); err != nil {
		dbgf("main | initVulkanPanel failed: %v", err)
		cleanup()
		return
	}
	if err := initComposition(); err != nil {
		dbgf("main | initComposition failed: %v", err)
		cleanup()
		return
	}

	dbgState("main", "enter message loop")
	var msg MSG
	for {
		ret, _, _ := pPeekMessageW.Call(uintptr(unsafe.Pointer(&msg)), 0, 0, 0, PM_REMOVE)
		if ret != 0 {
			if msg.Message == WM_QUIT {
				break
			}
			pTranslateMessage.Call(uintptr(unsafe.Pointer(&msg)))
			pDispatchMessageW.Call(uintptr(unsafe.Pointer(&msg)))
		} else {
			render()
		}
	}

	dbgState("main", "message loop ended")
	cleanup()
}
