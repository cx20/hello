Imports System
Imports System.Collections.Generic
Imports System.Runtime.InteropServices
Imports System.Text

Public Module CD3DX12_BLEND_DESC
    Public Function [Default]() As Hello.D3D12_BLEND_DESC
        Dim d3D12_RENDER_TARGET_BLEND_DESC As Hello.D3D12_RENDER_TARGET_BLEND_DESC = New Hello.D3D12_RENDER_TARGET_BLEND_DESC() With { .BlendEnable = False, .LogicOpEnable = False, .SrcBlend = Hello.D3D12_BLEND.D3D12_BLEND_ONE, .DestBlend = Hello.D3D12_BLEND.D3D12_BLEND_ZERO, .BlendOp = Hello.D3D12_BLEND_OP.D3D12_BLEND_OP_ADD, .SrcBlendAlpha = Hello.D3D12_BLEND.D3D12_BLEND_ONE, .DestBlendAlpha = Hello.D3D12_BLEND.D3D12_BLEND_ZERO, .BlendOpAlpha = Hello.D3D12_BLEND_OP.D3D12_BLEND_OP_ADD, .LogicOp = Hello.D3D12_LOGIC_OP.D3D12_LOGIC_OP_NOOP, .RenderTargetWriteMask = 15 }
        Return New Hello.D3D12_BLEND_DESC() With { .AlphaToCoverageEnable = False, .IndependentBlendEnable = False, .RenderTarget = New Hello.D3D12_RENDER_TARGET_BLEND_DESC() { d3D12_RENDER_TARGET_BLEND_DESC, d3D12_RENDER_TARGET_BLEND_DESC, d3D12_RENDER_TARGET_BLEND_DESC, d3D12_RENDER_TARGET_BLEND_DESC, d3D12_RENDER_TARGET_BLEND_DESC, d3D12_RENDER_TARGET_BLEND_DESC, d3D12_RENDER_TARGET_BLEND_DESC, d3D12_RENDER_TARGET_BLEND_DESC } }
    End Function
End Module

Public Module CD3DX12_RASTERIZER_DESC
    Public Function [Default]() As Hello.D3D12_RASTERIZER_DESC
        Return New Hello.D3D12_RASTERIZER_DESC() With { .FillMode = Hello.D3D12_FILL_MODE.D3D12_FILL_MODE_SOLID, .CullMode = Hello.D3D12_CULL_MODE.D3D12_CULL_MODE_BACK, .FrontCounterClockwise = False, .DepthBias = 0, .DepthBiasClamp = 0F, .SlopeScaledDepthBias = 0F, .DepthClipEnable = True, .MultisampleEnable = False, .AntialiasedLineEnable = False, .ForcedSampleCount = 0UI, .ConservativeRaster = Hello.D3D12_CONSERVATIVE_RASTERIZATION_MODE.D3D12_CONSERVATIVE_RASTERIZATION_MODE_OFF }
    End Function
End Module

Public Module CD3DX12_DEPTH_STENCIL_DESC
    Public Function [Default]() As Hello.D3D12_DEPTH_STENCIL_DESC
        Return New Hello.D3D12_DEPTH_STENCIL_DESC() With { .DepthEnable = False, .DepthWriteMask = Hello.D3D12_DEPTH_WRITE_MASK.D3D12_DEPTH_WRITE_MASK_ALL, .DepthFunc = Hello.D3D12_COMPARISON_FUNC.D3D12_COMPARISON_FUNC_LESS, .StencilEnable = False, .StencilReadMask = 255, .StencilWriteMask = 255, .FrontFace = New Hello.D3D12_DEPTH_STENCILOP_DESC() With { .StencilFailOp = Hello.D3D12_STENCIL_OP.D3D12_STENCIL_OP_KEEP, .StencilDepthFailOp = Hello.D3D12_STENCIL_OP.D3D12_STENCIL_OP_KEEP, .StencilPassOp = Hello.D3D12_STENCIL_OP.D3D12_STENCIL_OP_KEEP, .StencilFunc = Hello.D3D12_COMPARISON_FUNC.D3D12_COMPARISON_FUNC_ALWAYS }, .BackFace = New Hello.D3D12_DEPTH_STENCILOP_DESC() With { .StencilFailOp = Hello.D3D12_STENCIL_OP.D3D12_STENCIL_OP_KEEP, .StencilDepthFailOp = Hello.D3D12_STENCIL_OP.D3D12_STENCIL_OP_KEEP, .StencilPassOp = Hello.D3D12_STENCIL_OP.D3D12_STENCIL_OP_KEEP, .StencilFunc = Hello.D3D12_COMPARISON_FUNC.D3D12_COMPARISON_FUNC_ALWAYS } }
    End Function
End Module

Public Module CD3DX12_RESOURCE_BARRIER
    Public Function Transition(pResource As IntPtr, stateBefore As Hello.D3D12_RESOURCE_STATES, stateAfter As Hello.D3D12_RESOURCE_STATES, Optional subresource As UInteger=4294967295UI) As Hello.D3D12_RESOURCE_BARRIER
        Return New Hello.D3D12_RESOURCE_BARRIER() With { .Type = Hello.D3D12_RESOURCE_BARRIER_TYPE.D3D12_RESOURCE_BARRIER_TYPE_TRANSITION, .Flags = Hello.D3D12_RESOURCE_BARRIER_FLAGS.D3D12_RESOURCE_BARRIER_FLAG_NONE, .Transition = New Hello.D3D12_RESOURCE_TRANSITION_BARRIER() With { .pResource = pResource, .Subresource = subresource, .StateBefore = stateBefore, .StateAfter = stateAfter } }
    End Function
End Module

Public Class Hello
    Public Structure POINT
        Public X As Integer

        Public Y As Integer
    End Structure

    Public Structure MSG
        Public hwnd As IntPtr

        Public message As UInteger

        Public wParam As IntPtr

        Public lParam As IntPtr

        Public time As UInteger

        Public pt As Hello.POINT
    End Structure

    Private Delegate Function WndProcDelegate(hWnd As IntPtr, uMsg As UInteger, wParam As IntPtr, lParam As IntPtr) As IntPtr

    <StructLayout(LayoutKind.Sequential, CharSet := CharSet.Auto)>
    Private Structure WNDCLASSEX
        Public cbSize As UInteger

        Public style As UInteger

        Public lpfnWndProc As Hello.WndProcDelegate

        Public cbClsExtra As Integer

        Public cbWndExtra As Integer

        Public hInstance As IntPtr

        Public hIcon As IntPtr

        Public hCursor As IntPtr

        Public hbrBackground As IntPtr

        Public lpszMenuName As String

        Public lpszClassName As String

        Public hIconSm As IntPtr
    End Structure

    Private Structure RECT
        Public Left As Integer

        Public Top As Integer

        Public Right As Integer

        Public Bottom As Integer
    End Structure

    Private Structure PAINTSTRUCT
        Public hdc As IntPtr

        Public fErase As Integer

        Public rcPaint As Hello.RECT

        Public fRestore As Integer

        Public fIncUpdate As Integer

        <MarshalAs(UnmanagedType.ByValArray, SizeConst := 32)>
        Public rgbReserved As Byte()
    End Structure

    Private Structure Vertex
        Public X As Single

        Public Y As Single

        Public Z As Single

        Public R As Single

        Public G As Single

        Public B As Single

        Public A As Single
    End Structure

    <Guid("344488b7-6846-474b-b989-f027448245e0"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)>
    <ComImport()>
    Private Interface ID3D12Debug
        Sub EnableDebugLayer()
    End Interface

    Private Structure D3D12_COMMAND_QUEUE_DESC
        Public Type As Hello.D3D12_COMMAND_LIST_TYPE

        Public Priority As Integer

        Public Flags As Hello.D3D12_COMMAND_QUEUE_FLAGS

        Public NodeMask As UInteger
    End Structure

    Private Enum D3D12_COMMAND_LIST_TYPE
        D3D12_COMMAND_LIST_TYPE_DIRECT
        D3D12_COMMAND_LIST_TYPE_BUNDLE
        D3D12_COMMAND_LIST_TYPE_COMPUTE
        D3D12_COMMAND_LIST_TYPE_COPY
    End Enum

    <Flags()>
    Private Enum D3D12_COMMAND_QUEUE_FLAGS
        D3D12_COMMAND_QUEUE_FLAG_NONE = 0
        D3D12_COMMAND_QUEUE_FLAG_DISABLE_GPU_TIMEOUT = 1
    End Enum

    Private Structure D3D12_DESCRIPTOR_HEAP_DESC
        Public Type As Hello.D3D12_DESCRIPTOR_HEAP_TYPE

        Public NumDescriptors As UInteger

        Public Flags As Hello.D3D12_DESCRIPTOR_HEAP_FLAGS

        Public NodeMask As UInteger
    End Structure

    Private Enum D3D12_DESCRIPTOR_HEAP_TYPE
        D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV
        D3D12_DESCRIPTOR_HEAP_TYPE_SAMPLER
        D3D12_DESCRIPTOR_HEAP_TYPE_RTV
        D3D12_DESCRIPTOR_HEAP_TYPE_DSV
    End Enum

    <Flags()>
    Private Enum D3D12_DESCRIPTOR_HEAP_FLAGS
        D3D12_DESCRIPTOR_HEAP_FLAG_NONE = 0
        D3D12_DESCRIPTOR_HEAP_FLAG_SHADER_VISIBLE = 1
    End Enum

    Public Structure D3D12_CPU_DESCRIPTOR_HANDLE
        Public ptr As IntPtr
    End Structure

    Public Structure D3D12_GPU_DESCRIPTOR_HANDLE
        Public ptr As ULong
    End Structure

    Public Enum D3D12_RESOURCE_STATES
        D3D12_RESOURCE_STATE_COMMON
        D3D12_RESOURCE_STATE_VERTEX_AND_CONSTANT_BUFFER
        D3D12_RESOURCE_STATE_INDEX_BUFFER
        D3D12_RESOURCE_STATE_RENDER_TARGET = 4
        D3D12_RESOURCE_STATE_UNORDERED_ACCESS = 8
        D3D12_RESOURCE_STATE_DEPTH_WRITE = 16
        D3D12_RESOURCE_STATE_DEPTH_READ = 32
        D3D12_RESOURCE_STATE_NON_PIXEL_SHADER_RESOURCE = 64
        D3D12_RESOURCE_STATE_PIXEL_SHADER_RESOURCE = 128
        D3D12_RESOURCE_STATE_STREAM_OUT = 256
        D3D12_RESOURCE_STATE_INDIRECT_ARGUMENT = 512
        D3D12_RESOURCE_STATE_COPY_DEST = 1024
        D3D12_RESOURCE_STATE_COPY_SOURCE = 2048
        D3D12_RESOURCE_STATE_RESOLVE_DEST = 4096
        D3D12_RESOURCE_STATE_RESOLVE_SOURCE = 8192
        D3D12_RESOURCE_STATE_GENERIC_READ = 2755
        D3D12_RESOURCE_STATE_PRESENT = 0
        D3D12_RESOURCE_STATE_PREDICATION = 512
    End Enum

    Private Structure D3D12_RESOURCE_DESC
        Public Dimension As Hello.D3D12_RESOURCE_DIMENSION

        Public Alignment As ULong

        Public Width As ULong

        Public Height As UInteger

        Public DepthOrArraySize As UShort

        Public MipLevels As UShort

        Public Format As UInteger

        Public SampleDesc As Hello.DXGI_SAMPLE_DESC

        Public Layout As Hello.D3D12_TEXTURE_LAYOUT

        Public Flags As Hello.D3D12_RESOURCE_FLAGS
    End Structure

    Private Enum D3D12_RESOURCE_DIMENSION
        D3D12_RESOURCE_DIMENSION_UNKNOWN
        D3D12_RESOURCE_DIMENSION_BUFFER
        D3D12_RESOURCE_DIMENSION_TEXTURE1D
        D3D12_RESOURCE_DIMENSION_TEXTURE2D
        D3D12_RESOURCE_DIMENSION_TEXTURE3D
    End Enum

    Public Structure DXGI_SAMPLE_DESC
        Public Count As UInteger

        Public Quality As UInteger
    End Structure

    Private Enum D3D12_TEXTURE_LAYOUT
        D3D12_TEXTURE_LAYOUT_UNKNOWN
        D3D12_TEXTURE_LAYOUT_ROW_MAJOR
        D3D12_TEXTURE_LAYOUT_64KB_UNDEFINED_SWIZZLE
        D3D12_TEXTURE_LAYOUT_64KB_STANDARD_SWIZZLE
    End Enum

    <Flags()>
    Private Enum D3D12_RESOURCE_FLAGS
        D3D12_RESOURCE_FLAG_NONE = 0
        D3D12_RESOURCE_FLAG_ALLOW_RENDER_TARGET = 1
        D3D12_RESOURCE_FLAG_ALLOW_DEPTH_STENCIL = 2
        D3D12_RESOURCE_FLAG_ALLOW_UNORDERED_ACCESS = 4
        D3D12_RESOURCE_FLAG_DENY_SHADER_RESOURCE = 8
        D3D12_RESOURCE_FLAG_ALLOW_CROSS_ADAPTER = 16
        D3D12_RESOURCE_FLAG_ALLOW_SIMULTANEOUS_ACCESS = 32
    End Enum

    Public Structure D3D12_HEAP_PROPERTIES
        Public Type As Hello.D3D12_HEAP_TYPE

        Public CPUPageProperty As Hello.D3D12_CPU_PAGE_PROPERTY

        Public MemoryPoolPreference As Hello.D3D12_MEMORY_POOL

        Public CreationNodeMask As UInteger

        Public VisibleNodeMask As UInteger
    End Structure

    Public Enum D3D12_HEAP_TYPE
        D3D12_HEAP_TYPE_DEFAULT = 1
        D3D12_HEAP_TYPE_UPLOAD
        D3D12_HEAP_TYPE_READBACK
        D3D12_HEAP_TYPE_CUSTOM
    End Enum

    Public Enum D3D12_CPU_PAGE_PROPERTY
        D3D12_CPU_PAGE_PROPERTY_UNKNOWN
        D3D12_CPU_PAGE_PROPERTY_NOT_AVAILABLE
        D3D12_CPU_PAGE_PROPERTY_WRITE_COMBINE
        D3D12_CPU_PAGE_PROPERTY_WRITE_BACK
    End Enum

    Public Enum D3D12_MEMORY_POOL
        D3D12_MEMORY_POOL_UNKNOWN
        D3D12_MEMORY_POOL_L0
        D3D12_MEMORY_POOL_L1
    End Enum

    <Flags()>
    Public Enum D3D12_HEAP_FLAGS
        D3D12_HEAP_FLAG_NONE = 0
        D3D12_HEAP_FLAG_SHARED = 1
        D3D12_HEAP_FLAG_DENY_BUFFERS = 4
        D3D12_HEAP_FLAG_ALLOW_DISPLAY = 8
        D3D12_HEAP_FLAG_SHARED_CROSS_ADAPTER = 32
        D3D12_HEAP_FLAG_DENY_RT_DS_TEXTURES = 64
        D3D12_HEAP_FLAG_DENY_NON_RT_DS_TEXTURES = 128
        D3D12_HEAP_FLAG_ALLOW_ALL_BUFFERS_AND_TEXTURES = 0
        D3D12_HEAP_FLAG_ALLOW_ONLY_BUFFERS = 192
        D3D12_HEAP_FLAG_ALLOW_ONLY_NON_RT_DS_TEXTURES = 68
    End Enum

    Private Structure D3D12_GRAPHICS_PIPELINE_STATE_DESC
        Public pRootSignature As IntPtr

        Public VS As Hello.D3D12_SHADER_BYTECODE

        Public PS As Hello.D3D12_SHADER_BYTECODE

        Public DS As Hello.D3D12_SHADER_BYTECODE

        Public HS As Hello.D3D12_SHADER_BYTECODE

        Public GS As Hello.D3D12_SHADER_BYTECODE

        Public StreamOutput As Hello.D3D12_STREAM_OUTPUT_DESC

        Public BlendState As Hello.D3D12_BLEND_DESC

        Public SampleMask As UInteger

        Public RasterizerState As Hello.D3D12_RASTERIZER_DESC

        Public DepthStencilState As Hello.D3D12_DEPTH_STENCIL_DESC

        Public InputLayout As Hello.D3D12_INPUT_LAYOUT_DESC

        Public IBStripCutValue As Hello.D3D12_INDEX_BUFFER_STRIP_CUT_VALUE

        Public PrimitiveTopologyType As Hello.D3D12_PRIMITIVE_TOPOLOGY_TYPE

        Public NumRenderTargets As UInteger

        <MarshalAs(UnmanagedType.ByValArray, SizeConst := 8)>
        Public RTVFormats As UInteger()

        Public DSVFormat As UInteger

        Public SampleDesc As Hello.DXGI_SAMPLE_DESC

        Public NodeMask As UInteger

        Public CachedPSO As Hello.D3D12_CACHED_PIPELINE_STATE

        Public Flags As Hello.D3D12_PIPELINE_STATE_FLAGS
    End Structure

    Private Structure D3D12_SHADER_BYTECODE
        Public pShaderBytecode As IntPtr

        Public BytecodeLength As IntPtr
    End Structure

    Private Structure D3D12_INPUT_LAYOUT_DESC
        Public pInputElementDescs As IntPtr

        Public NumElements As UInteger
    End Structure

    Private Structure D3D12_INPUT_ELEMENT_DESC
        Public SemanticName As IntPtr

        Public SemanticIndex As UInteger

        Public Format As UInteger

        Public InputSlot As UInteger

        Public AlignedByteOffset As UInteger

        Public InputSlotClass As Hello.D3D12_INPUT_CLASSIFICATION

        Public InstanceDataStepRate As UInteger
    End Structure

    Private Enum D3D12_INPUT_CLASSIFICATION
        D3D12_INPUT_CLASSIFICATION_PER_VERTEX_DATA
        D3D12_INPUT_CLASSIFICATION_PER_INSTANCE_DATA
    End Enum

    Public Structure D3D12_ROOT_SIGNATURE_DESC
        Public NumParameters As UInteger

        Public pParameters As IntPtr

        Public NumStaticSamplers As UInteger

        Public pStaticSamplers As IntPtr

        Public Flags As Hello.D3D12_ROOT_SIGNATURE_FLAGS
    End Structure

    <Flags()>
    Public Enum D3D12_ROOT_SIGNATURE_FLAGS
        D3D12_ROOT_SIGNATURE_FLAG_NONE = 0
        D3D12_ROOT_SIGNATURE_FLAG_ALLOW_INPUT_ASSEMBLER_INPUT_LAYOUT = 1
        D3D12_ROOT_SIGNATURE_FLAG_DENY_VERTEX_SHADER_ROOT_ACCESS = 2
        D3D12_ROOT_SIGNATURE_FLAG_DENY_HULL_SHADER_ROOT_ACCESS = 4
        D3D12_ROOT_SIGNATURE_FLAG_DENY_DOMAIN_SHADER_ROOT_ACCESS = 8
        D3D12_ROOT_SIGNATURE_FLAG_DENY_GEOMETRY_SHADER_ROOT_ACCESS = 16
        D3D12_ROOT_SIGNATURE_FLAG_DENY_PIXEL_SHADER_ROOT_ACCESS = 32
        D3D12_ROOT_SIGNATURE_FLAG_ALLOW_STREAM_OUTPUT = 64
    End Enum

    Public Structure D3D12_VERTEX_BUFFER_VIEW
        Public BufferLocation As ULong

        Public SizeInBytes As UInteger

        Public StrideInBytes As UInteger
    End Structure

    Public Structure D3D12_CONSTANT_BUFFER_VIEW_DESC
        Public BufferLocation As ULong

        Public SizeInBytes As UInteger

        Public SizeInBytesDividedBy256 As UInteger
    End Structure

    Public Structure D3D12_SAMPLER_DESC
        Public Filter As Hello.D3D12_FILTER

        Public AddressU As Hello.D3D12_TEXTURE_ADDRESS_MODE

        Public AddressV As Hello.D3D12_TEXTURE_ADDRESS_MODE

        Public AddressW As Hello.D3D12_TEXTURE_ADDRESS_MODE

        Public MipLODBias As Single

        Public MaxAnisotropy As UInteger

        Public ComparisonFunc As Hello.D3D12_COMPARISON_FUNC

        <MarshalAs(UnmanagedType.ByValArray, SizeConst := 4)>
        Public BorderColor As Single()

        Public MinLOD As Single

        Public MaxLOD As Single
    End Structure

    Public Enum D3D12_FILTER
        D3D12_FILTER_MIN_MAG_MIP_POINT
        D3D12_FILTER_MIN_MAG_POINT_MIP_LINEAR
        D3D12_FILTER_MIN_POINT_MAG_LINEAR_MIP_POINT = 4
        D3D12_FILTER_MIN_POINT_MAG_MIP_LINEAR
        D3D12_FILTER_MIN_LINEAR_MAG_MIP_POINT = 16
        D3D12_FILTER_MIN_LINEAR_MAG_POINT_MIP_LINEAR
        D3D12_FILTER_MIN_MAG_LINEAR_MIP_POINT = 20
        D3D12_FILTER_MIN_MAG_MIP_LINEAR
        D3D12_FILTER_ANISOTROPIC = 85
    End Enum

    Public Enum D3D12_TEXTURE_ADDRESS_MODE
        D3D12_TEXTURE_ADDRESS_MODE_WRAP = 1
        D3D12_TEXTURE_ADDRESS_MODE_MIRROR
        D3D12_TEXTURE_ADDRESS_MODE_CLAMP
        D3D12_TEXTURE_ADDRESS_MODE_BORDER
        D3D12_TEXTURE_ADDRESS_MODE_MIRROR_ONCE
    End Enum

    Public Enum D3D12_COMPARISON_FUNC
        D3D12_COMPARISON_FUNC_NEVER = 1
        D3D12_COMPARISON_FUNC_LESS
        D3D12_COMPARISON_FUNC_EQUAL
        D3D12_COMPARISON_FUNC_LESS_EQUAL
        D3D12_COMPARISON_FUNC_GREATER
        D3D12_COMPARISON_FUNC_NOT_EQUAL
        D3D12_COMPARISON_FUNC_GREATER_EQUAL
        D3D12_COMPARISON_FUNC_ALWAYS
    End Enum

    Public Structure D3D12_RESOURCE_ALLOCATION_INFO
        Public SizeInBytes As ULong

        Public Alignment As ULong
    End Structure

    Public Structure D3D12_HEAP_DESC
        Public SizeInBytes As ULong

        Public Properties As Hello.D3D12_HEAP_PROPERTIES

        Public Alignment As ULong

        Public Flags As Hello.D3D12_HEAP_FLAGS
    End Structure

    <Flags()>
    Public Enum D3D12_FENCE_FLAGS
        D3D12_FENCE_FLAG_NONE = 0
        D3D12_FENCE_FLAG_SHARED = 1
        D3D12_FENCE_FLAG_SHARED_CROSS_ADAPTER = 2
    End Enum

    Public Structure D3D12_PLACED_SUBRESOURCE_FOOTPRINT
        Public Offset As ULong

        Public Footprint As Hello.D3D12_SUBRESOURCE_FOOTPRINT
    End Structure

    Public Structure D3D12_SUBRESOURCE_FOOTPRINT
        Public Format As UInteger

        Public Width As UInteger

        Public Height As UInteger

        Public Depth As UInteger

        Public RowPitch As UInteger
    End Structure

    Public Structure D3D12_STREAM_OUTPUT_DESC
        Public pSODeclaration As IntPtr

        Public NumEntries As UInteger

        Public pBufferStrides As IntPtr

        Public NumStrides As UInteger

        Public RasterizedStream As UInteger
    End Structure

    Public Structure D3D12_BLEND_DESC
        Public AlphaToCoverageEnable As Boolean

        Public IndependentBlendEnable As Boolean

        <MarshalAs(UnmanagedType.ByValArray, SizeConst := 8)>
        Public RenderTarget As Hello.D3D12_RENDER_TARGET_BLEND_DESC()
    End Structure

    Public Structure D3D12_RENDER_TARGET_BLEND_DESC
        Public BlendEnable As Boolean

        Public LogicOpEnable As Boolean

        Public SrcBlend As Hello.D3D12_BLEND

        Public DestBlend As Hello.D3D12_BLEND

        Public BlendOp As Hello.D3D12_BLEND_OP

        Public SrcBlendAlpha As Hello.D3D12_BLEND

        Public DestBlendAlpha As Hello.D3D12_BLEND

        Public BlendOpAlpha As Hello.D3D12_BLEND_OP

        Public LogicOp As Hello.D3D12_LOGIC_OP

        Public RenderTargetWriteMask As Byte
    End Structure

    Public Structure D3D12_RASTERIZER_DESC
        Public FillMode As Hello.D3D12_FILL_MODE

        Public CullMode As Hello.D3D12_CULL_MODE

        Public FrontCounterClockwise As Boolean

        Public DepthBias As Integer

        Public DepthBiasClamp As Single

        Public SlopeScaledDepthBias As Single

        Public DepthClipEnable As Boolean

        Public MultisampleEnable As Boolean

        Public AntialiasedLineEnable As Boolean

        Public ForcedSampleCount As UInteger

        Public ConservativeRaster As Hello.D3D12_CONSERVATIVE_RASTERIZATION_MODE
    End Structure

    Public Structure D3D12_DEPTH_STENCIL_DESC
        Public DepthEnable As Boolean

        Public DepthWriteMask As Hello.D3D12_DEPTH_WRITE_MASK

        Public DepthFunc As Hello.D3D12_COMPARISON_FUNC

        Public StencilEnable As Boolean

        Public StencilReadMask As Byte

        Public StencilWriteMask As Byte

        Public FrontFace As Hello.D3D12_DEPTH_STENCILOP_DESC

        Public BackFace As Hello.D3D12_DEPTH_STENCILOP_DESC
    End Structure

    Public Enum D3D12_INDEX_BUFFER_STRIP_CUT_VALUE
        D3D12_INDEX_BUFFER_STRIP_CUT_VALUE_DISABLED
        D3D12_INDEX_BUFFER_STRIP_CUT_VALUE_0xFFFF
        D3D12_INDEX_BUFFER_STRIP_CUT_VALUE_0xFFFFFFFF
    End Enum

    Public Enum D3D12_PRIMITIVE_TOPOLOGY_TYPE
        D3D12_PRIMITIVE_TOPOLOGY_TYPE_UNDEFINED
        D3D12_PRIMITIVE_TOPOLOGY_TYPE_POINT
        D3D12_PRIMITIVE_TOPOLOGY_TYPE_LINE
        D3D12_PRIMITIVE_TOPOLOGY_TYPE_TRIANGLE
        D3D12_PRIMITIVE_TOPOLOGY_TYPE_PATCH
    End Enum

    Public Structure D3D12_CACHED_PIPELINE_STATE
        Public pCachedBlob As IntPtr

        Public CachedBlobSizeInBytes As IntPtr
    End Structure

    <Flags()>
    Public Enum D3D12_PIPELINE_STATE_FLAGS
        D3D12_PIPELINE_STATE_FLAG_NONE = 0
        D3D12_PIPELINE_STATE_FLAG_TOOL_DEBUG = 1
    End Enum

    Public Enum D3D12_BLEND
        D3D12_BLEND_ZERO = 1
        D3D12_BLEND_ONE
        D3D12_BLEND_SRC_COLOR
        D3D12_BLEND_INV_SRC_COLOR
        D3D12_BLEND_SRC_ALPHA
        D3D12_BLEND_INV_SRC_ALPHA
        D3D12_BLEND_DEST_ALPHA
        D3D12_BLEND_INV_DEST_ALPHA
        D3D12_BLEND_DEST_COLOR
        D3D12_BLEND_INV_DEST_COLOR
        D3D12_BLEND_SRC_ALPHA_SAT
        D3D12_BLEND_BLEND_FACTOR = 14
        D3D12_BLEND_INV_BLEND_FACTOR
        D3D12_BLEND_SRC1_COLOR
        D3D12_BLEND_INV_SRC1_COLOR
        D3D12_BLEND_SRC1_ALPHA
        D3D12_BLEND_INV_SRC1_ALPHA
    End Enum

    Public Enum D3D12_BLEND_OP
        D3D12_BLEND_OP_ADD = 1
        D3D12_BLEND_OP_SUBTRACT
        D3D12_BLEND_OP_REV_SUBTRACT
        D3D12_BLEND_OP_MIN
        D3D12_BLEND_OP_MAX
    End Enum

    Public Enum D3D12_LOGIC_OP
        D3D12_LOGIC_OP_CLEAR
        D3D12_LOGIC_OP_SET
        D3D12_LOGIC_OP_COPY
        D3D12_LOGIC_OP_COPY_INVERTED
        D3D12_LOGIC_OP_NOOP
        D3D12_LOGIC_OP_INVERT
        D3D12_LOGIC_OP_AND
        D3D12_LOGIC_OP_NAND
        D3D12_LOGIC_OP_OR
        D3D12_LOGIC_OP_NOR
        D3D12_LOGIC_OP_XOR
        D3D12_LOGIC_OP_EQUIV
        D3D12_LOGIC_OP_AND_REVERSE
        D3D12_LOGIC_OP_AND_INVERTED
        D3D12_LOGIC_OP_OR_REVERSE
        D3D12_LOGIC_OP_OR_INVERTED
    End Enum

    Public Enum D3D12_FILL_MODE
        D3D12_FILL_MODE_WIREFRAME = 2
        D3D12_FILL_MODE_SOLID
    End Enum

    Public Enum D3D12_CULL_MODE
        D3D12_CULL_MODE_NONE = 1
        D3D12_CULL_MODE_FRONT
        D3D12_CULL_MODE_BACK
    End Enum

    Public Enum D3D12_CONSERVATIVE_RASTERIZATION_MODE
        D3D12_CONSERVATIVE_RASTERIZATION_MODE_OFF
        D3D12_CONSERVATIVE_RASTERIZATION_MODE_ON
    End Enum

    Public Enum D3D12_DEPTH_WRITE_MASK
        D3D12_DEPTH_WRITE_MASK_ZERO
        D3D12_DEPTH_WRITE_MASK_ALL
    End Enum

    Public Structure D3D12_DEPTH_STENCILOP_DESC
        Public StencilFailOp As Hello.D3D12_STENCIL_OP

        Public StencilDepthFailOp As Hello.D3D12_STENCIL_OP

        Public StencilPassOp As Hello.D3D12_STENCIL_OP

        Public StencilFunc As Hello.D3D12_COMPARISON_FUNC
    End Structure

    Public Enum D3D12_STENCIL_OP
        D3D12_STENCIL_OP_KEEP = 1
        D3D12_STENCIL_OP_ZERO
        D3D12_STENCIL_OP_REPLACE
        D3D12_STENCIL_OP_INCR_SAT
        D3D12_STENCIL_OP_DECR_SAT
        D3D12_STENCIL_OP_INVERT
        D3D12_STENCIL_OP_INCR
        D3D12_STENCIL_OP_DECR
    End Enum

    Public Structure DXGI_RATIONAL
        Public Numerator As UInteger

        Public Denominator As UInteger
    End Structure

    Public Structure DXGI_MODE_DESC
        Public Width As UInteger

        Public Height As UInteger

        Public RefreshRate As Hello.DXGI_RATIONAL

        Public Format As UInteger

        Public ScanlineOrdering As UInteger

        Public Scaling As UInteger
    End Structure

    Public Structure DXGI_SWAP_CHAIN_DESC
        Public BufferDesc As Hello.DXGI_MODE_DESC

        Public SampleDesc As Hello.DXGI_SAMPLE_DESC

        Public BufferUsage As UInteger

        Public BufferCount As UInteger

        Public OutputWindow As IntPtr

        Public Windowed As Boolean

        Public SwapEffect As UInteger

        Public Flags As UInteger
    End Structure

    Public Structure DXGI_SWAP_CHAIN_DESC1
        Public Width As UInteger

        Public Height As UInteger

        Public Format As UInteger

        Public Stereo As Boolean

        Public SampleDesc As Hello.DXGI_SAMPLE_DESC

        Public BufferUsage As UInteger

        Public BufferCount As UInteger

        Public Scaling As Hello.DXGI_SCALING

        Public SwapEffect As UInteger

        Public AlphaMode As Hello.DXGI_ALPHA_MODE

        Public Flags As UInteger
    End Structure

    Public Enum DXGI_SCALING
        DXGI_SCALING_STRETCH
        DXGI_SCALING_NONE
        DXGI_SCALING_ASPECT_RATIO_STRETCH
    End Enum

    Public Enum DXGI_ALPHA_MODE
        DXGI_ALPHA_MODE_UNSPECIFIED
        DXGI_ALPHA_MODE_PREMULTIPLIED
        DXGI_ALPHA_MODE_STRAIGHT
        DXGI_ALPHA_MODE_IGNORE
    End Enum

    Public Structure D3D12_TEXTURE_COPY_LOCATION
        Public pResource As IntPtr

        Public Type As Hello.D3D12_TEXTURE_COPY_TYPE

        Public PlacedFootprint As Hello.D3D12_PLACED_SUBRESOURCE_FOOTPRINT
    End Structure

    Public Enum D3D12_TEXTURE_COPY_TYPE
        D3D12_TEXTURE_COPY_TYPE_SUBRESOURCE_INDEX
        D3D12_TEXTURE_COPY_TYPE_PLACED_FOOTPRINT
    End Enum

    Public Structure D3D12_INDEX_BUFFER_VIEW
        Public BufferLocation As ULong

        Public SizeInBytes As UInteger

        Public Format As UInteger
    End Structure

    Public Structure D3D12_STREAM_OUTPUT_BUFFER_VIEW
        Public BufferLocation As ULong

        Public SizeInBytes As ULong

        Public BufferFilledSizeLocation As ULong
    End Structure

    Public Enum D3D12_CLEAR_FLAGS
        D3D12_CLEAR_FLAG_DEPTH = 1
        D3D12_CLEAR_FLAG_STENCIL
    End Enum

    Public Structure D3D12_DISCARD_REGION
        Public NumRects As UInteger

        Public pRects As IntPtr

        Public FirstSubresource As UInteger

        Public NumSubresources As UInteger
    End Structure

    Public Enum D3D12_QUERY_TYPE
        D3D12_QUERY_TYPE_OCCLUSION
        D3D12_QUERY_TYPE_BINARY_OCCLUSION
        D3D12_QUERY_TYPE_TIMESTAMP
        D3D12_QUERY_TYPE_PIPELINE_STATISTICS
        D3D12_QUERY_TYPE_SO_STATISTICS_STREAM0
        D3D12_QUERY_TYPE_SO_STATISTICS_STREAM1
        D3D12_QUERY_TYPE_SO_STATISTICS_STREAM2
        D3D12_QUERY_TYPE_SO_STATISTICS_STREAM3
        D3D12_QUERY_TYPE_VIDEO_DECODE_STATISTICS
        D3D12_QUERY_TYPE_PIPELINE_STATISTICS1 = 10
    End Enum

    Public Enum D3D12_PREDICATION_OP
        D3D12_PREDICATION_OP_EQUAL_ZERO
        D3D12_PREDICATION_OP_NOT_EQUAL_ZERO
    End Enum

    Public Structure D3D12_TILED_RESOURCE_COORDINATE
        Public X As UInteger

        Public Y As UInteger

        Public Z As UInteger

        Public Subresource As UInteger
    End Structure

    Public Structure D3D12_TILE_REGION_SIZE
        Public NumTiles As UInteger

        Public UseBox As Boolean

        Public Width As UInteger

        Public Height As UShort

        Public Depth As UShort
    End Structure

    <Flags()>
    Public Enum D3D12_TILE_COPY_FLAGS
        D3D12_TILE_COPY_FLAG_NONE = 0
        D3D12_TILE_COPY_FLAG_NO_HAZARD = 1
        D3D12_TILE_COPY_FLAG_LINEAR_BUFFER_TO_SWIZZLED_TILED_RESOURCE = 2
        D3D12_TILE_COPY_FLAG_SWIZZLED_TILED_RESOURCE_TO_LINEAR_BUFFER = 4
    End Enum

    Public Enum D3D_PRIMITIVE_TOPOLOGY
        D3D_PRIMITIVE_TOPOLOGY_UNDEFINED
        D3D_PRIMITIVE_TOPOLOGY_POINTLIST
        D3D_PRIMITIVE_TOPOLOGY_LINELIST
        D3D_PRIMITIVE_TOPOLOGY_LINESTRIP
        D3D_PRIMITIVE_TOPOLOGY_TRIANGLELIST
        D3D_PRIMITIVE_TOPOLOGY_TRIANGLESTRIP
    End Enum

    Public Structure D3D12_VIEWPORT
        Public TopLeftX As Single

        Public TopLeftY As Single

        Public Width As Single

        Public Height As Single

        Public MinDepth As Single

        Public MaxDepth As Single
    End Structure

    Public Structure D3D12_RECT
        Public left As Integer

        Public top As Integer

        Public right As Integer

        Public bottom As Integer
    End Structure

    Public Structure D3D12_RESOURCE_BARRIER
        Public Type As Hello.D3D12_RESOURCE_BARRIER_TYPE

        Public Flags As Hello.D3D12_RESOURCE_BARRIER_FLAGS

        Public Transition As Hello.D3D12_RESOURCE_TRANSITION_BARRIER
    End Structure

    Public Enum D3D12_RESOURCE_BARRIER_TYPE
        D3D12_RESOURCE_BARRIER_TYPE_TRANSITION
        D3D12_RESOURCE_BARRIER_TYPE_ALIASING
        D3D12_RESOURCE_BARRIER_TYPE_UAV
    End Enum

    <Flags()>
    Public Enum D3D12_RESOURCE_BARRIER_FLAGS
        D3D12_RESOURCE_BARRIER_FLAG_NONE = 0
        D3D12_RESOURCE_BARRIER_FLAG_BEGIN_ONLY = 1
        D3D12_RESOURCE_BARRIER_FLAG_END_ONLY = 2
    End Enum

    Public Structure D3D12_RESOURCE_TRANSITION_BARRIER
        Public pResource As IntPtr

        Public Subresource As UInteger

        Public StateBefore As Hello.D3D12_RESOURCE_STATES

        Public StateAfter As Hello.D3D12_RESOURCE_STATES
    End Structure

    Public Structure D3D12_RANGE
        Public Begin As ULong

        Public [End] As ULong
    End Structure

    Public Structure D3D12_CPU_DESCRIPTOR_HANDLE_ARRAY
        Public ptr As IntPtr
    End Structure

    Public Structure DXGI_PRESENT_PARAMETERS
        Public DirtyRectsCount As UInteger

        Public pDirtyRects As IntPtr

        Public pScrollRect As IntPtr

        Public pScrollOffset As IntPtr
    End Structure

    Private Structure PSInput
        <MarshalAs(UnmanagedType.Struct)>
        Public position As Hello.float4

        <MarshalAs(UnmanagedType.Struct)>
        Public color As Hello.float4
    End Structure

    Public Structure float4
        Public x As Single

        Public y As Single

        Public z As Single

        Public w As Single
    End Structure

    <UnmanagedFunctionPointer(CallingConvention.StdCall)>
    Private Delegate Function CreateSwapChainDelegate(factory As IntPtr, pDevice As IntPtr, <[In]()> ByRef pDesc As Hello.DXGI_SWAP_CHAIN_DESC, <Out()> ByRef ppSwapChain As IntPtr) As Integer

    <UnmanagedFunctionPointer(CallingConvention.StdCall)>
    Private Delegate Function CreateSwapChainForHwndDelegate(factory As IntPtr, pDevice As IntPtr, hWnd As IntPtr, <[In]()> ByRef pDesc As Hello.DXGI_SWAP_CHAIN_DESC1, pFullscreenDesc As IntPtr, pRestrictToOutput As IntPtr, <Out()> ByRef ppSwapChain As IntPtr) As Integer

    <UnmanagedFunctionPointer(CallingConvention.StdCall)>
    Private Delegate Function PresentDelegate(swapChain As IntPtr, SyncInterval As UInteger, Flags As UInteger) As Integer

    <UnmanagedFunctionPointer(CallingConvention.StdCall)>
    Private Delegate Function GetBufferDelegate(<[In]()> swapChain As IntPtr, <[In]()> Buffer As UInteger, <[In]()> ByRef riid As Guid, <Out()> ByRef ppSurface As IntPtr) As Integer

    <UnmanagedFunctionPointer(CallingConvention.StdCall)>
    Private Delegate Function GetCurrentBackBufferIndexDelegate(swapChain As IntPtr) As UInteger

    <UnmanagedFunctionPointer(CallingConvention.StdCall)>
    Private Delegate Function CreateCommandQueueDelegate(device As IntPtr, <[In]()> ByRef pDesc As Hello.D3D12_COMMAND_QUEUE_DESC, ByRef riid As Guid, <Out()> ByRef ppCommandQueue As IntPtr) As Integer

    <UnmanagedFunctionPointer(CallingConvention.StdCall)>
    Private Delegate Function CreateCommandAllocatorDelegate(device As IntPtr, type As Hello.D3D12_COMMAND_LIST_TYPE, ByRef riid As Guid, <Out()> ByRef ppCommandAllocator As IntPtr) As Integer

    <UnmanagedFunctionPointer(CallingConvention.StdCall)>
    Private Delegate Function CreateGraphicsPipelineStateDelegate(device As IntPtr, <[In]()> ByRef pDesc As Hello.D3D12_GRAPHICS_PIPELINE_STATE_DESC, ByRef riid As Guid, <Out()> ByRef ppPipelineState As IntPtr) As Integer

    <UnmanagedFunctionPointer(CallingConvention.StdCall)>
    Private Delegate Function CreateCommandListDelegate(device As IntPtr, nodeMask As UInteger, type As Hello.D3D12_COMMAND_LIST_TYPE, pCommandAllocator As IntPtr, pInitialState As IntPtr, ByRef riid As Guid, <Out()> ByRef ppCommandList As IntPtr) As Integer

    <UnmanagedFunctionPointer(CallingConvention.StdCall)>
    Private Delegate Function CreateDescriptorHeapDelegate(device As IntPtr, <[In]()> ByRef pDesc As Hello.D3D12_DESCRIPTOR_HEAP_DESC, ByRef riid As Guid, <Out()> ByRef ppHeap As IntPtr) As Integer

    <UnmanagedFunctionPointer(CallingConvention.StdCall)>
    Private Delegate Function GetDescriptorHandleIncrementSizeDelegate(device As IntPtr, descriptorHeapType As Hello.D3D12_DESCRIPTOR_HEAP_TYPE) As UInteger

    <UnmanagedFunctionPointer(CallingConvention.StdCall)>
    Private Delegate Function CreateRootSignatureDelegate(device As IntPtr, nodeMask As UInteger, pBlobWithRootSignature As IntPtr, blobLengthInBytes As IntPtr, ByRef riid As Guid, <Out()> ByRef ppvRootSignature As IntPtr) As Integer

    <UnmanagedFunctionPointer(CallingConvention.StdCall)>
    Private Delegate Sub CreateRenderTargetViewDelegate(device As IntPtr, pResource As IntPtr, pDesc As IntPtr, DestDescriptor As Hello.D3D12_CPU_DESCRIPTOR_HANDLE)

    <UnmanagedFunctionPointer(CallingConvention.StdCall)>
    Private Delegate Function GetDeviceRemovedReasonDelegate(device As IntPtr) As Integer

    <UnmanagedFunctionPointer(CallingConvention.StdCall)>
    Private Delegate Function CreateCommittedResourceDelegate(device As IntPtr, <[In]()> ByRef pHeapProperties As Hello.D3D12_HEAP_PROPERTIES, HeapFlags As Hello.D3D12_HEAP_FLAGS, <[In]()> ByRef pDesc As Hello.D3D12_RESOURCE_DESC, InitialResourceState As Hello.D3D12_RESOURCE_STATES, pOptimizedClearValue As IntPtr, ByRef riid As Guid, <Out()> ByRef ppvResource As IntPtr) As Integer

    <UnmanagedFunctionPointer(CallingConvention.StdCall)>
    Private Delegate Function CreateFenceDelegate(device As IntPtr, InitialValue As ULong, Flags As Hello.D3D12_FENCE_FLAGS, ByRef riid As Guid, <Out()> ByRef ppFence As IntPtr) As Integer

    <UnmanagedFunctionPointer(CallingConvention.StdCall)>
    Private Delegate Function CloseDelegate(commandList As IntPtr) As Integer

    <UnmanagedFunctionPointer(CallingConvention.StdCall)>
    Private Delegate Function ResetCommandListDelegate(commandList As IntPtr, pAllocator As IntPtr, pInitialState As IntPtr) As Integer

    <UnmanagedFunctionPointer(CallingConvention.StdCall)>
    Private Delegate Sub IASetPrimitiveTopologyDelegate(commandList As IntPtr, PrimitiveTopology As Hello.D3D_PRIMITIVE_TOPOLOGY)

    <UnmanagedFunctionPointer(CallingConvention.StdCall)>
    Private Delegate Sub RSSetViewportsDelegate(commandList As IntPtr, NumViewports As UInteger, <MarshalAs(UnmanagedType.LPArray)> <[In]()> pViewports As Hello.D3D12_VIEWPORT())

    <UnmanagedFunctionPointer(CallingConvention.StdCall)>
    Private Delegate Sub RSSetScissorRectsDelegate(commandList As IntPtr, NumRects As UInteger, <MarshalAs(UnmanagedType.LPArray)> <[In]()> pRects As Hello.D3D12_RECT())

    <UnmanagedFunctionPointer(CallingConvention.StdCall)>
    Private Delegate Sub ResourceBarrierDelegate(commandList As IntPtr, NumBarriers As UInteger, <[In]()> pBarriers As Hello.D3D12_RESOURCE_BARRIER())

    <UnmanagedFunctionPointer(CallingConvention.StdCall)>
    Private Delegate Sub SetGraphicsRootSignatureDelegate(commandList As IntPtr, pRootSignature As IntPtr)

    <UnmanagedFunctionPointer(CallingConvention.StdCall)>
    Private Delegate Sub OMSetRenderTargetsDelegate(commandList As IntPtr, NumRenderTargetDescriptors As UInteger, <[In]()> pRenderTargetDescriptors As Hello.D3D12_CPU_DESCRIPTOR_HANDLE_ARRAY(), RTsSingleHandleToDescriptorRange As Boolean, pDepthStencilDescriptor As IntPtr)

    <UnmanagedFunctionPointer(CallingConvention.StdCall)>
    Private Delegate Sub ClearRenderTargetViewDelegate(commandList As IntPtr, RenderTargetView As Hello.D3D12_CPU_DESCRIPTOR_HANDLE, <[In]()> ColorRGBA As Single(), NumRects As UInteger, pRects As IntPtr)

    <UnmanagedFunctionPointer(CallingConvention.StdCall)>
    Private Delegate Sub IASetVertexBuffersDelegate(commandList As IntPtr, StartSlot As UInteger, NumViews As UInteger, <[In]()> pViews As Hello.D3D12_VERTEX_BUFFER_VIEW())

    <UnmanagedFunctionPointer(CallingConvention.StdCall)>
    Private Delegate Sub DrawInstancedDelegate(commandList As IntPtr, VertexCountPerInstance As UInteger, InstanceCount As UInteger, StartVertexLocation As UInteger, StartInstanceLocation As UInteger)

    <UnmanagedFunctionPointer(CallingConvention.StdCall)>
    Private Delegate Sub ExecuteCommandListsDelegate(commandQueue As IntPtr, NumCommandLists As UInteger, <[In]()> ppCommandLists As IntPtr())

    <UnmanagedFunctionPointer(CallingConvention.StdCall)>
    Private Delegate Function SignalDelegate(commandQueue As IntPtr, fence As IntPtr, Value As ULong) As Integer

    <UnmanagedFunctionPointer(CallingConvention.StdCall)>
    Private Delegate Function ResetCommandAllocatorDelegate(commandAllocator As IntPtr) As Integer

    <UnmanagedFunctionPointer(CallingConvention.StdCall)>
    Private Delegate Function GetCompletedValueDelegate(fence As IntPtr) As ULong

    <UnmanagedFunctionPointer(CallingConvention.StdCall)>
    Private Delegate Function SetEventOnCompletionDelegate(fence As IntPtr, Value As ULong, hEvent As IntPtr) As Integer

    <UnmanagedFunctionPointer(CallingConvention.StdCall)>
    Private Delegate Function GetBufferPointerDelegate(blob As IntPtr) As IntPtr

    <UnmanagedFunctionPointer(CallingConvention.StdCall)>
    Private Delegate Function GetBufferSizeDelegate(blob As IntPtr) As Integer

    <UnmanagedFunctionPointer(CallingConvention.StdCall)>
    Private Delegate Function MapDelegate(resource As IntPtr, Subresource As UInteger, ByRef pReadRange As Hello.D3D12_RANGE, <Out()> ByRef ppData As IntPtr) As Integer

    <UnmanagedFunctionPointer(CallingConvention.StdCall)>
    Private Delegate Function UnmapDelegate(resource As IntPtr, Subresource As UInteger, ByRef pWrittenRange As Hello.D3D12_RANGE) As Integer

    <UnmanagedFunctionPointer(CallingConvention.StdCall)>
    Private Delegate Function GetGPUVirtualAddressDelegate(resource As IntPtr) As ULong

    <UnmanagedFunctionPointer(CallingConvention.StdCall)>
    Private Delegate Sub GetCPUDescriptorHandleForHeapStartDelegate(descriptorHeap As IntPtr, <Out()> ByRef handle As Hello.D3D12_CPU_DESCRIPTOR_HANDLE)

    Private Const WS_OVERLAPPEDWINDOW As UInteger = 13565952UI

    Private Const WS_VISIBLE As UInteger = 268435456UI

    Private Const WM_CREATE As UInteger = 1UI

    Private Const WM_DESTROY As UInteger = 2UI

    Private Const WM_PAINT As UInteger = 15UI

    Private Const WM_CLOSE As UInteger = 16UI

    Private Const WM_COMMAND As UInteger = 273UI

    Private Const WM_QUIT As UInteger = 18UI

    Private Const PM_REMOVE As UInteger = 1UI

    Private Const CS_OWNDC As UInteger = 32UI

    Private Const IDC_ARROW As Integer = 32512

    Private Const INFINITE As UInteger = 4294967295UI

    Private Const D3D_FEATURE_LEVEL_11_0 As UInteger = 45056UI

    Private Const D3D_FEATURE_LEVEL_10_1 As UInteger = 41216UI

    Private Const D3D_FEATURE_LEVEL_10_0 As UInteger = 40960UI

    Private Const D3D_FEATURE_LEVEL_9_3 As UInteger = 37632UI

    Private Const D3D_FEATURE_LEVEL_9_2 As UInteger = 37376UI

    Private Const D3D_FEATURE_LEVEL_9_1 As UInteger = 37120UI

    Private Const D3D_ROOT_SIGNATURE_VERSION_1 As UInteger = 1UI

    Private Const D3D_ROOT_SIGNATURE_VERSION_1_0 As UInteger = 1UI

    Private Const D3D_ROOT_SIGNATURE_VERSION_1_1 As UInteger = 2UI

    Private Const D3D_ROOT_SIGNATURE_VERSION_1_2 As UInteger = 3UI

    Private Shared swapChainDesc1 As Hello.DXGI_SWAP_CHAIN_DESC1

    Private Const DXGI_FORMAT_UNKNOWN As UInteger = 0UI

    Private Const DXGI_FORMAT_R32G32B32A32_TYPELESS As UInteger = 1UI

    Private Const DXGI_FORMAT_R32G32B32A32_FLOAT As UInteger = 2UI

    Private Const DXGI_FORMAT_R32G32B32A32_UINT As UInteger = 3UI

    Private Const DXGI_FORMAT_R32G32B32A32_SINT As UInteger = 4UI

    Private Const DXGI_FORMAT_R32G32B32_TYPELESS As UInteger = 5UI

    Private Const DXGI_FORMAT_R32G32B32_FLOAT As UInteger = 6UI

    Private Const DXGI_FORMAT_R32G32B32_UINT As UInteger = 7UI

    Private Const DXGI_FORMAT_R32G32B32_SINT As UInteger = 8UI

    Private Const DXGI_FORMAT_R16G16B16A16_TYPELESS As UInteger = 9UI

    Private Const DXGI_FORMAT_R16G16B16A16_FLOAT As UInteger = 10UI

    Private Const DXGI_FORMAT_R32G32_FLOAT As UInteger = 16UI

    Private Const DXGI_FORMAT_R8G8B8A8_UNORM As UInteger = 28UI

    Private Const DXGI_FORMAT_R8G8B8A8_UINT As UInteger = 30UI

    Private Const DXGI_FORMAT_R8G8B8A8_SNORM As UInteger = 29UI

    Private Const DXGI_FORMAT_R8G8B8A8_SINT As UInteger = 31UI

    Private Const DXGI_FORMAT_R32_FLOAT As UInteger = 41UI

    Private Const DXGI_USAGE_RENDER_TARGET_OUTPUT As UInteger = 32UI

    Private Const DXGI_SCALING_STRETCH As UInteger = 0UI

    Private Const DXGI_MODE_SCANLINE_ORDER_UNSPECIFIED As Integer = 0

    Private Const DXGI_MODE_SCALING_UNSPECIFIED As UInteger = 0UI

    Private Const DXGI_MODE_SCALING_CENTERED As UInteger = 1UI

    Private Const DXGI_MODE_SCALING_STRETCH As UInteger = 2UI

    Private Const DXGI_SCANLINE_ORDERING_UNSPECIFIED As UInteger = 0UI

    Private Const DXGI_SWAP_EFFECT_DISCARD As UInteger = 0UI

    Private Const DXGI_SWAP_EFFECT_SEQUENTIAL As UInteger = 1UI

    Private Const DXGI_SWAP_EFFECT_FLIP_SEQUENTIAL As UInteger = 3UI

    Private Const DXGI_SWAP_EFFECT_FLIP_DISCARD As UInteger = 4UI

    Private Const DXGI_SWAP_CHAIN_FLAG_NONPREROTATED As UInteger = 1UI

    Private Const DXGI_SWAP_CHAIN_FLAG_ALLOW_MODE_SWITCH As UInteger = 2UI

    Private Const DXGI_SWAP_CHAIN_FLAG_GDI_COMPATIBLE As UInteger = 4UI

    Private Const DXGI_SWAP_CHAIN_FLAG_RESTRICTED_CONTENT As UInteger = 8UI

    Private Const DXGI_SWAP_CHAIN_FLAG_RESTRICT_SHARED_RESOURCE_DRIVER As UInteger = 16UI

    Private Const DXGI_SWAP_CHAIN_FLAG_DISPLAY_ONLY As UInteger = 32UI

    Private Const DXGI_SWAP_CHAIN_FLAG_FRAME_LATENCY_WAITABLE_OBJECT As UInteger = 64UI

    Private Const DXGI_SWAP_CHAIN_FLAG_ALLOW_TEARING As UInteger = 512UI

    Private Const DXGI_PRESENT_NONE As UInteger = 0UI

    Private Const DXGI_PRESENT_TEST As UInteger = 1UI

    Private Const DXGI_PRESENT_DO_NOT_SEQUENCE As UInteger = 2UI

    Private Const DXGI_PRESENT_RESTART As UInteger = 4UI

    Private Const DXGI_PRESENT_DO_NOT_WAIT As UInteger = 8UI

    Private Const DXGI_PRESENT_STEREO_PREFER_RIGHT As UInteger = 16UI

    Private Const DXGI_PRESENT_STEREO_TEMPORARY_MONO As UInteger = 32UI

    Private Const DXGI_PRESENT_RESTRICT_TO_OUTPUT As UInteger = 64UI

    Private Const DXGI_PRESENT_USE_DURATION As UInteger = 256UI

    Private Shared IID_ID3D12Debug As Guid = New Guid("344488b7-6846-474b-b989-f027448245e0")

    Private Shared IID_ID3D12Device As Guid = New Guid("189819f1-1db6-4b57-be54-1821339b85f7")

    Private Shared IID_ID3D12Resource As Guid = New Guid("696442be-a72e-4059-bc79-5b5c98040fad")

    Private Shared IID_ID3D12PipelineState As Guid = New Guid("765a30f3-f624-4c6f-a828-ace948622445")

    Private Shared IID_ID3D12GraphicsCommandList As Guid = New Guid("5b160d0f-ac1b-4185-8ba8-b3ae42a5a455")

    Private Shared IID_ID3D12Fence As Guid = New Guid("0a753dcf-c4d8-4b91-adf6-be5a60d95a76")

    Private Shared IID_ID3D12CommandQueue As Guid = New Guid("0ec870a6-5d7e-4c22-8cfc-5baae07616ed")

    Private Shared IID_ID3D12DescriptorHeap As Guid = New Guid("8efb471d-616c-4f49-90f7-127bb763fa51")

    Private Shared IID_ID3D12CommandAllocator As Guid = New Guid("6102dee4-af59-4b09-b999-b44d73f09b24")

    Private Shared IID_ID3D12RootSignature As Guid = New Guid("c54a6b66-72df-4ee8-8be5-a946a1429214")

    Private Shared IID_ID3DBlob As Guid = New Guid("8ba5fb08-5195-40e2-ac58-0d989c3a0102")

    Private Shared IID_IDXGIFactory As Guid = New Guid("7b7166ec-21c7-44ae-b21a-c9ae321ae369")

    Private Shared IID_IDXGIFactory1 As Guid = New Guid("770aae78-f26f-4dba-a829-253c83d1b387")

    Private Shared IID_IDXGIFactory2 As Guid = New Guid("50c83a1c-e072-4c48-87b0-3630fa36a6d0")

    Private Shared IID_IDXGIFactory3 As Guid = New Guid("25483823-cd46-4c7d-86ca-47aa95b837bd")

    Private Shared IID_IDXGIFactory4 As Guid = New Guid("1bc6ea02-ef36-464f-bf0c-21ca39e5168a")

    Private Shared IID_IDXGISwapChain1 As Guid = New Guid("790a45f7-0d42-4876-983a-0a55cfe6f4aa")

    Private Shared IID_IDXGISwapChain2 As Guid = New Guid("a8be2ac4-199f-4946-b331-79599fb98de7")

    Private Shared IID_IDXGISwapChain3 As Guid = New Guid("94d99bdb-f1f8-4ab0-b236-7da0170edab1")

    Private Const FrameCount As Integer = 2

    Private device As IntPtr

    Private commandQueue As IntPtr

    Private swapChain As IntPtr

    Private renderTargets As IntPtr() = New IntPtr(2 - 1) {}

    Private commandAllocator As IntPtr

    Private commandList As IntPtr

    Private pipelineState As IntPtr

    Private rootSignature As IntPtr

    Private rtvHeap As IntPtr

    Private rtvDescriptorSize As UInteger

    Private vertexBuffer As IntPtr

    Private vertexBufferView As Hello.D3D12_VERTEX_BUFFER_VIEW

    Private fence As IntPtr

    Private fenceEvent As IntPtr

    Private fenceValue As ULong

    Private frameIndex As Integer = 0

    Public Const D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES As UInteger = 4294967295UI

    Private Declare Auto Function ShowWindow Lib "user32.dll" (hWnd As IntPtr, nCmdShow As Integer) As Boolean

    Private Declare Auto Function LoadCursor Lib "user32.dll" (hInstance As IntPtr, lpCursorName As Integer) As IntPtr

    Private Declare Auto Function RegisterClassEx Lib "user32.dll" (<[In]()> ByRef lpwcx As Hello.WNDCLASSEX) As UShort

    Private Declare Auto Function CreateWindowEx Lib "user32.dll" (dwExStyle As UInteger, lpClassName As String, lpWindowName As String, dwStyle As UInteger, x As Integer, y As Integer, nWidth As Integer, nHeight As Integer, hWndParent As IntPtr, hMenu As IntPtr, hInstance As IntPtr, lpParam As IntPtr) As IntPtr

    Private Declare Auto Function PeekMessage Lib "user32.dll" (<Out()> ByRef lpMsg As Hello.MSG, hWnd As IntPtr, wMsgFilterMin As UInteger, wMsgFilterMax As UInteger, wRemoveMsg As UInteger) As Boolean

    Private Declare Auto Function GetMessage Lib "user32.dll" (<Out()> ByRef lpMsg As Hello.MSG, hWnd As IntPtr, wMsgFilterMin As UInteger, wMsgFilterMax As UInteger) As Boolean

    Private Declare Auto Function TranslateMessage Lib "user32.dll" (<[In]()> ByRef lpMsg As Hello.MSG) As Boolean

    Private Declare Auto Function DispatchMessage Lib "user32.dll" (<[In]()> ByRef lpMsg As Hello.MSG) As IntPtr

    Private Declare Auto Sub PostQuitMessage Lib "user32.dll" (nExitCode As Integer)

    Private Declare Auto Function DefWindowProc Lib "user32.dll" (hWnd As IntPtr, uMsg As UInteger, wParam As IntPtr, lParam As IntPtr) As IntPtr

    Private Declare Auto Function BeginPaint Lib "user32.dll" (hWnd As IntPtr, <Out()> ByRef lpPaint As Hello.PAINTSTRUCT) As IntPtr

    Private Declare Auto Function EndPaint Lib "user32.dll" (hWnd As IntPtr, ByRef lpPaint As Hello.PAINTSTRUCT) As IntPtr

    Private Declare Auto Function TextOut Lib "gdi32.dll" (hdc As IntPtr, x As Integer, y As Integer, lpString As String, nCount As Integer) As IntPtr

    Private Declare Auto Function GetWindowText Lib "user32.dll" (hWnd As IntPtr, lpString As StringBuilder, nMaxCount As Integer) As Integer

    Private Declare Auto Function GetClassName Lib "user32.dll" (hWnd As IntPtr, lpClassName As StringBuilder, nMaxCount As Integer) As Integer

    Private Declare Function D3D12GetDebugInterface Lib "d3d12.dll" (<[In]()> ByRef riid As Guid, <Out()> ByRef ppvDebug As IntPtr) As Integer

    Public Declare Function D3D12CreateDevice Lib "d3d12.dll" (pAdapter As IntPtr, MinimumFeatureLevel As UInteger, ByRef riid As Guid, <Out()> ByRef ppDevice As IntPtr) As Integer

    Private Declare Function DXGIGetDebugInterface Lib "dxgidebug.dll" (ByRef riid As Guid, <Out()> ByRef ppDebug As IntPtr) As Integer

    Private Declare Function CreateDXGIFactory1 Lib "dxgi.dll" (ByRef riid As Guid, <Out()> ByRef ppFactory As IntPtr) As Integer

    Private Declare Function CreateDXGIFactory2 Lib "dxgi.dll" (Flags As UInteger, ByRef riid As Guid, <Out()> ByRef ppFactory As IntPtr) As Integer

    Public Declare Function D3D12SerializeRootSignature Lib "d3d12.dll" (ByRef pRootSignature As Hello.D3D12_ROOT_SIGNATURE_DESC, Version As UInteger, <Out()> ByRef ppBlob As IntPtr, <Out()> ByRef ppErrorBlob As IntPtr) As Integer

    Public Declare Function CreateEvent Lib "kernel32.dll" (lpEventAttributes As IntPtr, bManualReset As Boolean, bInitialState As Boolean, lpName As String) As IntPtr

    Public Declare Function WaitForSingleObject Lib "kernel32.dll" (hHandle As IntPtr, dwMilliseconds As UInteger) As UInteger

    Public Declare Function CloseHandle Lib "kernel32.dll" (hObject As IntPtr) As<MarshalAs(UnmanagedType.Bool)>
    Boolean

    Private Declare Function D3DCompileFromFile Lib "d3dcompiler_47.dll" (<MarshalAs(UnmanagedType.LPWStr)> pFileName As String, pDefines As IntPtr, pInclude As IntPtr, <MarshalAs(UnmanagedType.LPStr)> pEntrypoint As String, <MarshalAs(UnmanagedType.LPStr)> pTarget As String, Flags1 As UInteger, Flags2 As UInteger, <Out()> ByRef ppCode As IntPtr, <Out()> ByRef ppErrorMsgs As IntPtr) As Integer

    Private Function StructArrayToByteArray(Of T As Structure)(structures As T()) As Byte()
        Dim num As Integer = Marshal.SizeOf(Of T)()
        Dim array As Byte() = New Byte(num * structures.Length - 1) {}
        Dim gCHandle As GCHandle = GCHandle.Alloc(structures, GCHandleType.Pinned)
        Try
            Dim source As IntPtr = gCHandle.AddrOfPinnedObject()
            Marshal.Copy(source, array, 0, array.Length)
        Finally
            gCHandle.Free()
        End Try
        Return array
    End Function

    Private Shared Function CreateSwapChain(factory As IntPtr, pDevice As IntPtr, ByRef pDesc As Hello.DXGI_SWAP_CHAIN_DESC, <Out()> ByRef ppSwapChain As IntPtr) As Integer
        Dim result As Integer
        Try
            Console.WriteLine("----------------------------------------")
            Console.WriteLine("[CreateSwapChain] - Start")
            Dim ptr As IntPtr = Marshal.ReadIntPtr(factory)
            Dim intPtr As IntPtr = Marshal.ReadIntPtr(ptr, 10 * IntPtr.Size)
            Console.WriteLine(String.Format("CreateSwapChain method address: {0:X}", intPtr))
            Dim delegateForFunctionPointer As Hello.CreateSwapChainDelegate = Marshal.GetDelegateForFunctionPointer(Of Hello.CreateSwapChainDelegate)(intPtr)
            Dim num As Integer = delegateForFunctionPointer(factory, pDevice, pDesc, ppSwapChain)
            Console.WriteLine(String.Format("CreateSwapChain result: {0:X}", num))
            Console.WriteLine(String.Format("Created SwapChain pointer: {0:X}", ppSwapChain))
            result = num
        Catch ex As Exception
            Console.WriteLine("Error in CreateSwapChain: " + ex.Message)
            Console.WriteLine("Stack trace: " + ex.StackTrace)
            ppSwapChain = System.IntPtr.Zero
            result = -1
        End Try
        Return result
    End Function

    Private Shared Function CreateSwapChainForHwnd(factory As IntPtr, pDevice As IntPtr, hWnd As IntPtr, ByRef pDesc As Hello.DXGI_SWAP_CHAIN_DESC1, pFullscreenDesc As IntPtr, pRestrictToOutput As IntPtr, <Out()> ByRef ppSwapChain As IntPtr) As Integer
        Console.WriteLine("----------------------------------------")
        Console.WriteLine("[CreateSwapChainForHwnd] - Start")
        Console.WriteLine("Creating swap chain...")
        Console.WriteLine(String.Format("Factory: {0:X}", factory))
        Console.WriteLine(String.Format("Device: {0:X}", pDevice))
        Console.WriteLine(String.Format("HWND: {0:X}", hWnd))
        Dim result As Integer
        Try
            Dim ptr As IntPtr = Marshal.ReadIntPtr(factory)
            Dim intPtr As IntPtr = Marshal.ReadIntPtr(ptr, 15 * IntPtr.Size)
            Console.WriteLine(String.Format("CreateSwapChainForHwnd method address: {0:X}", intPtr))
            Dim delegateForFunctionPointer As Hello.CreateSwapChainForHwndDelegate = Marshal.GetDelegateForFunctionPointer(Of Hello.CreateSwapChainForHwndDelegate)(intPtr)
            Dim num As Integer = delegateForFunctionPointer(factory, pDevice, hWnd, pDesc, pFullscreenDesc, pRestrictToOutput, ppSwapChain)
            Console.WriteLine(String.Format("CreateSwapChainForHwnd result: {0:X}", num))
            Dim flag As Boolean = num < 0
            If flag Then
                Console.WriteLine(String.Format("Failed with HRESULT: {0:X}", num))
            Else
                Console.WriteLine(String.Format("Created swap chain: {0:X}", ppSwapChain))
            End If
            result = num
        Catch ex As Exception
            Console.WriteLine("Error creating swap chain: " + ex.Message)
            Console.WriteLine("Stack trace: " + ex.StackTrace)
            ppSwapChain = System.IntPtr.Zero
            result = -1
        End Try
        Return result
    End Function

    Private Shared Function GetBuffer(swapChain As IntPtr, buffer As UInteger, ByRef riid As Guid, <Out()> ByRef ppSurface As IntPtr) As Integer
        Dim result As Integer
        Try
            Console.WriteLine("----------------------------------------")
            Console.WriteLine("[GetBuffer] - Start")
            Console.WriteLine(String.Format("Getting buffer from swap chain: {0:X}", swapChain))
            Dim ptr As IntPtr = Marshal.ReadIntPtr(swapChain)
            Dim intPtr As IntPtr = Marshal.ReadIntPtr(ptr, 9 * IntPtr.Size)
            Console.WriteLine(String.Format("GetBuffer method address: {0:X}", intPtr))
            Dim flag As Boolean = intPtr = System.IntPtr.Zero
            If flag Then
                Console.WriteLine("GetBuffer method pointer is null!")
                ppSurface = System.IntPtr.Zero
                result = -1
            Else
                Dim delegateForFunctionPointer As Hello.GetBufferDelegate = Marshal.GetDelegateForFunctionPointer(Of Hello.GetBufferDelegate)(intPtr)
                Console.WriteLine("Calling GetBuffer with parameters:")
                Console.WriteLine(String.Format("  swapChain: {0:X}", swapChain))
                Console.WriteLine(String.Format("  buffer: {0}", buffer))
                Console.WriteLine(String.Format("  riid: {0}", riid))
                Console.WriteLine("SwapChain creation parameters:")
                Console.WriteLine(String.Format("  BufferCount: {0}", Hello.swapChainDesc1.BufferCount))
                Console.WriteLine(String.Format("  Format: {0:X}", Hello.swapChainDesc1.Format))
                Console.WriteLine(String.Format("  BufferUsage: {0:X}", Hello.swapChainDesc1.BufferUsage))
                Console.WriteLine(String.Format("  SwapEffect: {0:X}", Hello.swapChainDesc1.SwapEffect))
                Dim num As Integer = delegateForFunctionPointer(swapChain, buffer, riid, ppSurface)
                Console.WriteLine(String.Format("GetBuffer result: {0:X}", num))
                Dim flag2 As Boolean = num >= 0
                If flag2 Then
                    Console.WriteLine(String.Format("Buffer obtained: {0:X}", ppSurface))
                Else
                    Console.WriteLine(String.Format("GetBuffer failed with HRESULT: {0:X}", num))
                End If
                result = num
            End If
        Catch ex As Exception
            Console.WriteLine("Error in GetBuffer: " + ex.Message)
            Console.WriteLine("Stack trace: " + ex.StackTrace)
            ppSurface = System.IntPtr.Zero
            result = -1
        End Try
        Return result
    End Function

    Private Shared Function CompileShaderFromFile(fileName As String, entryPoint As String, profile As String) As IntPtr
        Console.WriteLine("----------------------------------------")
        Console.WriteLine("[CompileShaderFromFile] - Start")
        Console.WriteLine("File: " + fileName)
        Console.WriteLine("Entry Point: " + entryPoint)
        Console.WriteLine("Profile: " + profile)
        Dim zero As IntPtr = System.IntPtr.Zero
        Dim zero2 As IntPtr = System.IntPtr.Zero
        Dim result As IntPtr
        Try
            Dim num As UInteger = 2048UI
            Console.WriteLine(String.Format("Compile Flags: {0:X}", num))
            Dim num2 As Integer = Hello.D3DCompileFromFile(fileName, System.IntPtr.Zero, System.IntPtr.Zero, entryPoint, profile, num, 0UI, zero, zero2)
            Console.WriteLine(String.Format("D3DCompileFromFile result: {0:X}", num2))
            Console.WriteLine(String.Format("Shader Blob: {0:X}", zero))
            Console.WriteLine(String.Format("Error Blob: {0:X}", zero2))
            Dim flag As Boolean = num2 < 0
            If flag Then
                Dim flag2 As Boolean = zero2 <> System.IntPtr.Zero
                If flag2 Then
                    Dim str As String = Marshal.PtrToStringAnsi(Hello.GetBufferPointer(zero2))
                    Console.WriteLine("Shader compilation error: " + str)
                Else
                    Console.WriteLine(String.Format("Shader compilation failed with HRESULT: {0:X}", num2))
                End If
                result = System.IntPtr.Zero
            Else
                Dim flag3 As Boolean = zero <> System.IntPtr.Zero
                If flag3 Then
                    Dim bufferPointer As IntPtr = Hello.GetBufferPointer(zero)
                    Dim blobSize As Integer = Hello.GetBlobSize(zero)
                    Console.WriteLine("Compiled shader details:")
                    Console.WriteLine(String.Format("  Code pointer: {0:X}", bufferPointer))
                    Console.WriteLine(String.Format("  Size: {0} bytes", blobSize))
                    Dim flag4 As Boolean = bufferPointer <> System.IntPtr.Zero AndAlso blobSize > 0
                    If flag4 Then
                        Console.WriteLine("  First 16 bytes of shader code:")
                        Dim array As Byte() = New Byte(Math.Min(16, blobSize) - 1) {}
                        Marshal.Copy(bufferPointer, array, 0, array.Length)
                        Console.Write("  ")
                        Dim array2 As Byte() = array
                        For i As Integer = 0 To array2.Length - 1
                            Dim b As Byte = array2(i)
                            Console.Write(String.Format("{0:X2} ", b))
                        Next
                        Console.WriteLine()
                    End If
                End If
                result = zero
            End If
        Catch ex As Exception
            Console.WriteLine("Exception in CompileShaderFromFile: " + ex.Message)
            Console.WriteLine("Stack trace: " + ex.StackTrace)
            result = System.IntPtr.Zero
        Finally
            Dim flag5 As Boolean = zero2 <> System.IntPtr.Zero
            If flag5 Then
                Marshal.Release(zero2)
            End If
        End Try
        Return result
    End Function

    Private Shared Function GetBlobSize(blob As IntPtr) As Integer
        Dim flag As Boolean = blob = System.IntPtr.Zero
        Dim result As Integer
        If flag Then
            Console.WriteLine("Error: Blob pointer is null")
            result = 0
        Else
            Try
                Dim ptr As IntPtr = Marshal.ReadIntPtr(blob)
                Dim ptr2 As IntPtr = Marshal.ReadIntPtr(ptr, 4 * System.IntPtr.Size)
                Dim delegateForFunctionPointer As Hello.GetBufferSizeDelegate = Marshal.GetDelegateForFunctionPointer(Of Hello.GetBufferSizeDelegate)(ptr2)
                result = delegateForFunctionPointer(blob)
            Catch ex As Exception
                Console.WriteLine("Error in GetBlobSize: " + ex.Message)
                result = 0
            End Try
        End If
        Return result
    End Function

    Private Shared Function GetBufferPointer(blob As IntPtr) As IntPtr
        Dim flag As Boolean = blob = System.IntPtr.Zero
        Dim result As IntPtr
        If flag Then
            Console.WriteLine("Error: Blob pointer is null")
            result = System.IntPtr.Zero
        Else
            Try
                Dim ptr As IntPtr = Marshal.ReadIntPtr(blob)
                Dim ptr2 As IntPtr = Marshal.ReadIntPtr(ptr, 3 * System.IntPtr.Size)
                Dim delegateForFunctionPointer As Hello.GetBufferPointerDelegate = Marshal.GetDelegateForFunctionPointer(Of Hello.GetBufferPointerDelegate)(ptr2)
                result = delegateForFunctionPointer(blob)
            Catch ex As Exception
                Console.WriteLine("Error in GetBufferPointer: " + ex.Message)
                result = System.IntPtr.Zero
            End Try
        End If
        Return result
    End Function

    Private Shared Function GetCPUDescriptorHandleForHeapStart(descriptorHeap As IntPtr) As IntPtr
        Dim ptr As IntPtr = Marshal.ReadIntPtr(descriptorHeap)
        Dim ptr2 As IntPtr = Marshal.ReadIntPtr(ptr, 9 * System.IntPtr.Size)
        Dim delegateForFunctionPointer As Hello.GetCPUDescriptorHandleForHeapStartDelegate = Marshal.GetDelegateForFunctionPointer(Of Hello.GetCPUDescriptorHandleForHeapStartDelegate)(ptr2)
        Dim d3D12_CPU_DESCRIPTOR_HANDLE As Hello.D3D12_CPU_DESCRIPTOR_HANDLE
        delegateForFunctionPointer(descriptorHeap, d3D12_CPU_DESCRIPTOR_HANDLE)
        Return d3D12_CPU_DESCRIPTOR_HANDLE.ptr
    End Function

    Private Shared Function GetBufferSize(blob As IntPtr) As Integer
        Dim flag As Boolean = blob = System.IntPtr.Zero
        Dim result As Integer
        If flag Then
            Console.WriteLine("Error: Blob pointer is null.")
            result = 0
        Else
            Try
                Dim ptr As IntPtr = Marshal.ReadIntPtr(blob)
                Dim ptr2 As IntPtr = Marshal.ReadIntPtr(ptr, 4 * System.IntPtr.Size)
                Dim delegateForFunctionPointer As Hello.GetBufferSizeDelegate = Marshal.GetDelegateForFunctionPointer(Of Hello.GetBufferSizeDelegate)(ptr2)
                result = delegateForFunctionPointer(blob)
            Catch ex As Exception
                Console.WriteLine("Error in GetBufferSize: " + ex.Message)
                result = 0
            End Try
        End If
        Return result
    End Function

    Private Function GetDeviceRemovedReason(device As IntPtr) As Integer
        Dim ptr As IntPtr = Marshal.ReadIntPtr(device)
        Dim ptr2 As IntPtr = Marshal.ReadIntPtr(ptr, 37 * System.IntPtr.Size)
        Dim delegateForFunctionPointer As Hello.GetDeviceRemovedReasonDelegate = Marshal.GetDelegateForFunctionPointer(Of Hello.GetDeviceRemovedReasonDelegate)(ptr2)
        Return delegateForFunctionPointer(device)
    End Function

    Private Sub LoadAssets()
        Console.WriteLine("----------------------------------------")
        Console.WriteLine("[LoadAssets] - Start")
        Dim d3D12_ROOT_SIGNATURE_DESC As Hello.D3D12_ROOT_SIGNATURE_DESC = New Hello.D3D12_ROOT_SIGNATURE_DESC() With { .NumParameters = 0UI, .pParameters = System.IntPtr.Zero, .NumStaticSamplers = 0UI, .pStaticSamplers = System.IntPtr.Zero, .Flags = Hello.D3D12_ROOT_SIGNATURE_FLAGS.D3D12_ROOT_SIGNATURE_FLAG_ALLOW_INPUT_ASSEMBLER_INPUT_LAYOUT }
        Console.WriteLine("Root signature desc:")
        Console.WriteLine(String.Format("  NumParameters: {0}", d3D12_ROOT_SIGNATURE_DESC.NumParameters))
        Console.WriteLine(String.Format("  pParameters: {0:X}", d3D12_ROOT_SIGNATURE_DESC.pParameters))
        Console.WriteLine(String.Format("  NumStaticSamplers: {0}", d3D12_ROOT_SIGNATURE_DESC.NumStaticSamplers))
        Console.WriteLine(String.Format("  pStaticSamplers: {0:X}", d3D12_ROOT_SIGNATURE_DESC.pStaticSamplers))
        Console.WriteLine(String.Format("  Flags: {0}", d3D12_ROOT_SIGNATURE_DESC.Flags))
        Dim zero As IntPtr = System.IntPtr.Zero
        Dim zero2 As IntPtr = System.IntPtr.Zero
        Dim num As Integer = Hello.D3D12SerializeRootSignature(d3D12_ROOT_SIGNATURE_DESC, 1UI, zero, zero2)
        Console.WriteLine(String.Format("D3D12SerializeRootSignature result: {0:X}", num))
        Dim flag As Boolean = num < 0
        If flag Then
            Dim flag2 As Boolean = zero2 <> System.IntPtr.Zero
            If flag2 Then
                Dim str As String = Marshal.PtrToStringAnsi(Hello.GetBufferPointer(zero2))
                Console.WriteLine("Root signature serialization error: " + str)
                Marshal.Release(zero2)
            End If
        Else
            Dim flag3 As Boolean = zero = System.IntPtr.Zero
            If flag3 Then
                Console.WriteLine("Error: Signature blob is null")
            Else
                Dim bufferPointer As IntPtr = Hello.GetBufferPointer(zero)
                Dim blobSize As Integer = Hello.GetBlobSize(zero)
                Console.WriteLine("Serialized root signature info:")
                Console.WriteLine(String.Format("  Blob pointer: {0:X}", zero))
                Console.WriteLine(String.Format("  Data pointer: {0:X}", bufferPointer))
                Console.WriteLine(String.Format("  Size: {0}", blobSize))
                Dim flag4 As Boolean = bufferPointer = System.IntPtr.Zero OrElse blobSize = 0
                If flag4 Then
                    Console.WriteLine("Error: Invalid serialized root signature data")
                    Dim flag5 As Boolean = zero <> System.IntPtr.Zero
                    If flag5 Then
                        Marshal.Release(zero)
                    End If
                Else
                    Try
                        Dim ptr As IntPtr = Marshal.ReadIntPtr(Me.device)
                        Dim ptr2 As IntPtr = Marshal.ReadIntPtr(ptr, 16 * System.IntPtr.Size)
                        Dim delegateForFunctionPointer As Hello.CreateRootSignatureDelegate = Marshal.GetDelegateForFunctionPointer(Of Hello.CreateRootSignatureDelegate)(ptr2)
                        Dim iID_ID3D12RootSignature As Guid = Hello.IID_ID3D12RootSignature
                        Dim num2 As Integer = delegateForFunctionPointer(Me.device, 0UI, Hello.GetBufferPointer(zero), CType(Hello.GetBlobSize(zero), IntPtr), iID_ID3D12RootSignature, Me.rootSignature)
                        Console.WriteLine(String.Format("CreateRootSignature result: {0:X}", num2))
                        Dim flag6 As Boolean = num2 < 0
                        If flag6 Then
                            Console.WriteLine(String.Format("Failed to create root signature. HRESULT: {0:X}", num2))
                        Else
                            Console.WriteLine(String.Format("Successfully created root signature: {0:X}", Me.rootSignature))
                        End If
                    Finally
                        Dim flag7 As Boolean = zero <> System.IntPtr.Zero
                        If flag7 Then
                            Marshal.Release(zero)
                        End If
                    End Try
                    Dim blob As IntPtr = Hello.CompileShaderFromFile("hello.hlsl", "VSMain", "vs_5_0")
                    Dim blob2 As IntPtr = Hello.CompileShaderFromFile("hello.hlsl", "PSMain", "ps_5_0")
                    Dim gCHandle As GCHandle = Nothing
                    Dim list As List(Of GCHandle) = New List(Of GCHandle)()
                    Dim array As Hello.D3D12_INPUT_ELEMENT_DESC() = New Hello.D3D12_INPUT_ELEMENT_DESC() { New Hello.D3D12_INPUT_ELEMENT_DESC() With { .SemanticName = Marshal.StringToHGlobalAnsi("POSITION"), .SemanticIndex = 0UI, .Format = 6UI, .InputSlot = 0UI, .AlignedByteOffset = 0UI, .InputSlotClass = Hello.D3D12_INPUT_CLASSIFICATION.D3D12_INPUT_CLASSIFICATION_PER_VERTEX_DATA, .InstanceDataStepRate = 0UI }, New Hello.D3D12_INPUT_ELEMENT_DESC() With { .SemanticName = Marshal.StringToHGlobalAnsi("COLOR"), .SemanticIndex = 0UI, .Format = 2UI, .InputSlot = 0UI, .AlignedByteOffset = 12UI, .InputSlotClass = Hello.D3D12_INPUT_CLASSIFICATION.D3D12_INPUT_CLASSIFICATION_PER_VERTEX_DATA, .InstanceDataStepRate = 0UI } }
                    Dim intPtr As IntPtr = GCHandle.Alloc(array, GCHandleType.Pinned).AddrOfPinnedObject()
                    Console.WriteLine(String.Format("Pinned input layout pointer: {0:X}", intPtr))
                    Dim d3D12_GRAPHICS_PIPELINE_STATE_DESC As Hello.D3D12_GRAPHICS_PIPELINE_STATE_DESC = Nothing
                    d3D12_GRAPHICS_PIPELINE_STATE_DESC.pRootSignature = Me.rootSignature
                    d3D12_GRAPHICS_PIPELINE_STATE_DESC.VS = New Hello.D3D12_SHADER_BYTECODE() With { .pShaderBytecode = Hello.GetBufferPointer(blob), .BytecodeLength = CType(Hello.GetBlobSize(blob), IntPtr) }
                    d3D12_GRAPHICS_PIPELINE_STATE_DESC.PS = New Hello.D3D12_SHADER_BYTECODE() With { .pShaderBytecode = Hello.GetBufferPointer(blob2), .BytecodeLength = CType(Hello.GetBlobSize(blob2), IntPtr) }
                    d3D12_GRAPHICS_PIPELINE_STATE_DESC.BlendState = CD3DX12_BLEND_DESC.[Default]()
                    d3D12_GRAPHICS_PIPELINE_STATE_DESC.SampleMask = 4294967295UI
                    d3D12_GRAPHICS_PIPELINE_STATE_DESC.RasterizerState = CD3DX12_RASTERIZER_DESC.[Default]()
                    d3D12_GRAPHICS_PIPELINE_STATE_DESC.DepthStencilState = CD3DX12_DEPTH_STENCIL_DESC.[Default]()
                    d3D12_GRAPHICS_PIPELINE_STATE_DESC.InputLayout = New Hello.D3D12_INPUT_LAYOUT_DESC() With { .pInputElementDescs = intPtr, .NumElements = CUInt(array.Length) }
                    d3D12_GRAPHICS_PIPELINE_STATE_DESC.PrimitiveTopologyType = Hello.D3D12_PRIMITIVE_TOPOLOGY_TYPE.D3D12_PRIMITIVE_TOPOLOGY_TYPE_TRIANGLE
                    d3D12_GRAPHICS_PIPELINE_STATE_DESC.NumRenderTargets = 1UI
                    Dim expr_4E9 As UInteger() = New UInteger(8 - 1) {}
                    expr_4E9(0) = 28UI
                    d3D12_GRAPHICS_PIPELINE_STATE_DESC.RTVFormats = expr_4E9
                    d3D12_GRAPHICS_PIPELINE_STATE_DESC.DSVFormat = 0UI
                    d3D12_GRAPHICS_PIPELINE_STATE_DESC.SampleDesc = New Hello.DXGI_SAMPLE_DESC() With { .Count = 1UI, .Quality = 0UI }
                    d3D12_GRAPHICS_PIPELINE_STATE_DESC.NodeMask = 0UI
                    Dim d3D12_GRAPHICS_PIPELINE_STATE_DESC2 As Hello.D3D12_GRAPHICS_PIPELINE_STATE_DESC = d3D12_GRAPHICS_PIPELINE_STATE_DESC
                    Console.WriteLine("----------------------------------------")
                    Console.WriteLine("[CreateGraphicsPipelineState] - Start")
                    Console.WriteLine("Pipeline State Description Details:")
                    Console.WriteLine(String.Format("  RootSignature: {0:X}", d3D12_GRAPHICS_PIPELINE_STATE_DESC2.pRootSignature))
                    Console.WriteLine("  VS ByteCode:")
                    Console.WriteLine(String.Format("    Code Pointer: {0:X}", d3D12_GRAPHICS_PIPELINE_STATE_DESC2.VS.pShaderBytecode))
                    Console.WriteLine(String.Format("    Code Length: {0}", d3D12_GRAPHICS_PIPELINE_STATE_DESC2.VS.BytecodeLength))
                    Console.WriteLine("  PS ByteCode:")
                    Console.WriteLine(String.Format("    Code Pointer: {0:X}", d3D12_GRAPHICS_PIPELINE_STATE_DESC2.PS.pShaderBytecode))
                    Console.WriteLine(String.Format("    Code Length: {0}", d3D12_GRAPHICS_PIPELINE_STATE_DESC2.PS.BytecodeLength))
                    Console.WriteLine("  BlendState:")
                    Console.WriteLine(String.Format("    AlphaToCoverageEnable: {0}", d3D12_GRAPHICS_PIPELINE_STATE_DESC2.BlendState.AlphaToCoverageEnable))
                    Console.WriteLine(String.Format("    IndependentBlendEnable: {0}", d3D12_GRAPHICS_PIPELINE_STATE_DESC2.BlendState.IndependentBlendEnable))
                    Console.WriteLine(String.Format("  SampleMask: {0:X}", d3D12_GRAPHICS_PIPELINE_STATE_DESC2.SampleMask))
                    Console.WriteLine("  InputLayout:")
                    Console.WriteLine(String.Format("    Desc Pointer: {0:X}", d3D12_GRAPHICS_PIPELINE_STATE_DESC2.InputLayout.pInputElementDescs))
                    Console.WriteLine(String.Format("    NumElements: {0}", d3D12_GRAPHICS_PIPELINE_STATE_DESC2.InputLayout.NumElements))
                    Console.WriteLine(String.Format("  PrimitiveTopologyType: {0}", d3D12_GRAPHICS_PIPELINE_STATE_DESC2.PrimitiveTopologyType))
                    Console.WriteLine(String.Format("  NumRenderTargets: {0}", d3D12_GRAPHICS_PIPELINE_STATE_DESC2.NumRenderTargets))
                    Dim flag8 As Boolean = d3D12_GRAPHICS_PIPELINE_STATE_DESC2.RTVFormats IsNot Nothing
                    If flag8 Then
                        For i As Integer = 0 To Math.Min(8, d3D12_GRAPHICS_PIPELINE_STATE_DESC2.RTVFormats.Length) - 1
                            Console.WriteLine(String.Format("  RTVFormat[{0}]: {1:X}", i, d3D12_GRAPHICS_PIPELINE_STATE_DESC2.RTVFormats(i)))
                        Next
                    Else
                        Console.WriteLine("  RTVFormats array is null")
                    End If
                    Console.WriteLine(String.Format("  DSVFormat: {0:X}", d3D12_GRAPHICS_PIPELINE_STATE_DESC2.DSVFormat))
                    Console.WriteLine("  SampleDesc:")
                    Console.WriteLine(String.Format("    Count: {0}", d3D12_GRAPHICS_PIPELINE_STATE_DESC2.SampleDesc.Count))
                    Console.WriteLine(String.Format("    Quality: {0}", d3D12_GRAPHICS_PIPELINE_STATE_DESC2.SampleDesc.Quality))
                    Try
                        Dim ptr3 As IntPtr = Marshal.ReadIntPtr(Me.device)
                        Dim ptr4 As IntPtr = Marshal.ReadIntPtr(ptr3, 10 * IntPtr.Size)
                        Dim delegateForFunctionPointer2 As Hello.CreateGraphicsPipelineStateDelegate = Marshal.GetDelegateForFunctionPointer(Of Hello.CreateGraphicsPipelineStateDelegate)(ptr4)
                        Dim iID_ID3D12PipelineState As Guid = Hello.IID_ID3D12PipelineState
                        Dim num3 As Integer = delegateForFunctionPointer2(Me.device, d3D12_GRAPHICS_PIPELINE_STATE_DESC2, iID_ID3D12PipelineState, Me.pipelineState)
                        Console.WriteLine(String.Format("CreateGraphicsPipelineState result: {0:X}", num3))
                        Dim flag9 As Boolean = num3 < 0
                        If flag9 Then
                            Console.WriteLine(String.Format("Failed to create graphics pipeline state. HRESULT: {0:X}", num3))
                        Else
                            Console.WriteLine(String.Format("Successfully created pipeline state: {0:X}", Me.pipelineState))
                        End If
                    Catch ex As Exception
                        Console.WriteLine("Error creating pipeline state: " + ex.Message)
                        Console.WriteLine("Stack trace: " + ex.StackTrace)
                        Me.pipelineState = System.IntPtr.Zero
                    End Try
                    Console.WriteLine("[CreateCommandList using vtable] - Start")
                    Try
                        Dim ptr5 As IntPtr = Marshal.ReadIntPtr(Me.device)
                        Dim ptr6 As IntPtr = Marshal.ReadIntPtr(ptr5, 12 * IntPtr.Size)
                        Dim delegateForFunctionPointer3 As Hello.CreateCommandListDelegate = Marshal.GetDelegateForFunctionPointer(Of Hello.CreateCommandListDelegate)(ptr6)
                        Dim iID_ID3D12GraphicsCommandList As Guid = Hello.IID_ID3D12GraphicsCommandList
                        Dim num4 As Integer = delegateForFunctionPointer3(Me.device, 0UI, Hello.D3D12_COMMAND_LIST_TYPE.D3D12_COMMAND_LIST_TYPE_DIRECT, Me.commandAllocator, Me.pipelineState, iID_ID3D12GraphicsCommandList, Me.commandList)
                        Console.WriteLine(String.Format("CreateCommandList result: {0:X}", num4))
                        Dim flag10 As Boolean = num4 < 0
                        If flag10 Then
                            Console.WriteLine(String.Format("Failed to create command list. HRESULT: {0:X}", num4))
                        Else
                            Console.WriteLine(String.Format("Successfully created command list: {0:X}", Me.commandList))
                            Try
                                ptr5 = Marshal.ReadIntPtr(Me.commandList)
                                Dim ptr7 As IntPtr = Marshal.ReadIntPtr(ptr5, 9 * IntPtr.Size)
                                Dim delegateForFunctionPointer4 As Hello.CloseDelegate = Marshal.GetDelegateForFunctionPointer(Of Hello.CloseDelegate)(ptr7)
                                Dim num5 As Integer = delegateForFunctionPointer4(Me.commandList)
                                Console.WriteLine(String.Format("Close result: {0:X}", num5))
                            Catch ex2 As Exception
                                Console.WriteLine("Error in Close: " + ex2.Message)
                                Console.WriteLine("Stack trace: " + ex2.StackTrace)
                            End Try
                        End If
                    Catch ex3 As Exception
                        Console.WriteLine("Error creating command list: " + ex3.Message)
                        Console.WriteLine("Stack trace: " + ex3.StackTrace)
                        Me.commandList = System.IntPtr.Zero
                    End Try
                    Dim num6 As Single = 1.33333337F
                    Dim array2 As Hello.Vertex() = New Hello.Vertex() { New Hello.Vertex() With { .X = 0F, .Y = 0.5F * num6, .Z = 0F, .R = 1F, .G = 0F, .B = 0F, .A = 1F }, New Hello.Vertex() With { .X = 0.5F, .Y = -0.5F * num6, .Z = 0F, .R = 0F, .G = 1F, .B = 0F, .A = 1F }, New Hello.Vertex() With { .X = -0.5F, .Y = -0.5F * num6, .Z = 0F, .R = 0F, .G = 0F, .B = 1F, .A = 1F } }
                    Dim num7 As UInteger = CUInt((Marshal.SizeOf(Of Hello.Vertex)() * array2.Length))
                    Dim d3D12_HEAP_PROPERTIES As Hello.D3D12_HEAP_PROPERTIES = New Hello.D3D12_HEAP_PROPERTIES() With { .Type = Hello.D3D12_HEAP_TYPE.D3D12_HEAP_TYPE_UPLOAD, .CPUPageProperty = Hello.D3D12_CPU_PAGE_PROPERTY.D3D12_CPU_PAGE_PROPERTY_UNKNOWN, .MemoryPoolPreference = Hello.D3D12_MEMORY_POOL.D3D12_MEMORY_POOL_UNKNOWN }
                    Dim d3D12_RESOURCE_DESC As Hello.D3D12_RESOURCE_DESC = New Hello.D3D12_RESOURCE_DESC() With { .Dimension = Hello.D3D12_RESOURCE_DIMENSION.D3D12_RESOURCE_DIMENSION_BUFFER, .Width = CULng(num7), .Height = 1UI, .DepthOrArraySize = 1, .MipLevels = 1, .Format = 0UI, .SampleDesc = New Hello.DXGI_SAMPLE_DESC() With { .Count = 1UI, .Quality = 0UI }, .Layout = Hello.D3D12_TEXTURE_LAYOUT.D3D12_TEXTURE_LAYOUT_ROW_MAJOR, .Flags = Hello.D3D12_RESOURCE_FLAGS.D3D12_RESOURCE_FLAG_NONE }
                    Console.WriteLine("[CreateCommittedResource using vtable] - Start")
                    Dim iID_ID3D12Resource As Guid = Hello.IID_ID3D12Resource
                    Try
                        Dim ptr8 As IntPtr = Marshal.ReadIntPtr(Me.device)
                        Dim ptr9 As IntPtr = Marshal.ReadIntPtr(ptr8, 27 * IntPtr.Size)
                        Dim delegateForFunctionPointer5 As Hello.CreateCommittedResourceDelegate = Marshal.GetDelegateForFunctionPointer(Of Hello.CreateCommittedResourceDelegate)(ptr9)
                        Dim num8 As Integer = delegateForFunctionPointer5(Me.device, d3D12_HEAP_PROPERTIES, Hello.D3D12_HEAP_FLAGS.D3D12_HEAP_FLAG_NONE, d3D12_RESOURCE_DESC, Hello.D3D12_RESOURCE_STATES.D3D12_RESOURCE_STATE_GENERIC_READ, System.IntPtr.Zero, iID_ID3D12Resource, Me.vertexBuffer)
                        Console.WriteLine(String.Format("CreateCommittedResource result: {0:X}", num8))
                        Dim flag11 As Boolean = num8 < 0
                        If flag11 Then
                            Console.WriteLine(String.Format("Failed to create committed resource. HRESULT: {0:X}", num8))
                        Else
                            Console.WriteLine(String.Format("Successfully created vertex buffer: {0:X}", Me.vertexBuffer))
                        End If
                    Catch ex4 As Exception
                        Console.WriteLine("Error creating committed resource: " + ex4.Message)
                        Console.WriteLine("Stack trace: " + ex4.StackTrace)
                        Me.vertexBuffer = System.IntPtr.Zero
                    End Try
                    Try
                        Dim d3D12_RANGE As Hello.D3D12_RANGE = New Hello.D3D12_RANGE() With { .Begin = 0UL, .[End] = 0UL }
                        Dim ptr10 As IntPtr = Marshal.ReadIntPtr(Me.vertexBuffer)
                        Dim ptr11 As IntPtr = Marshal.ReadIntPtr(ptr10, 8 * IntPtr.Size)
                        Dim delegateForFunctionPointer6 As Hello.MapDelegate = Marshal.GetDelegateForFunctionPointer(Of Hello.MapDelegate)(ptr11)
                        Dim destination As IntPtr
                        Dim num9 As Integer = delegateForFunctionPointer6(Me.vertexBuffer, 0UI, d3D12_RANGE, destination)
                        Dim source As Byte() = Me.StructArrayToByteArray(Of Hello.Vertex)(array2)
                        Marshal.Copy(source, 0, destination, CInt(num7))
                        Dim d3D12_RANGE2 As Hello.D3D12_RANGE = New Hello.D3D12_RANGE() With { .Begin = 0UL, .[End] = 0UL }
                        Dim ptr12 As IntPtr = Marshal.ReadIntPtr(ptr10, 9 * IntPtr.Size)
                        Dim delegateForFunctionPointer7 As Hello.UnmapDelegate = Marshal.GetDelegateForFunctionPointer(Of Hello.UnmapDelegate)(ptr12)
                        delegateForFunctionPointer7(Me.vertexBuffer, 0UI, d3D12_RANGE2)
                    Catch ex5 As Exception
                        Console.WriteLine("Error Map/Unmap: " + ex5.Message)
                        Console.WriteLine("Stack trace: " + ex5.StackTrace)
                    End Try
                    Try
                        Dim ptr13 As IntPtr = Marshal.ReadIntPtr(Me.vertexBuffer)
                        Dim ptr14 As IntPtr = Marshal.ReadIntPtr(ptr13, 11 * IntPtr.Size)
                        Dim delegateForFunctionPointer8 As Hello.GetGPUVirtualAddressDelegate = Marshal.GetDelegateForFunctionPointer(Of Hello.GetGPUVirtualAddressDelegate)(ptr14)
                        Me.vertexBufferView = New Hello.D3D12_VERTEX_BUFFER_VIEW() With { .BufferLocation = delegateForFunctionPointer8(Me.vertexBuffer), .StrideInBytes = CUInt(Marshal.SizeOf(Of Hello.Vertex)()), .SizeInBytes = num7 }
                    Catch ex6 As Exception
                        Console.WriteLine("Error GetGPUVirtualAddress: " + ex6.Message)
                        Console.WriteLine("Stack trace: " + ex6.StackTrace)
                        Me.fence = System.IntPtr.Zero
                    End Try
                    Console.WriteLine("VertexBufferView settings:")
                    Console.WriteLine(String.Format("  BufferLocation: {0:X}", Me.vertexBufferView.BufferLocation))
                    Console.WriteLine(String.Format("  SizeInBytes: {0}", Me.vertexBufferView.SizeInBytes))
                    Console.WriteLine(String.Format("  StrideInBytes: {0}", Me.vertexBufferView.StrideInBytes))
                    Console.WriteLine("[CreateFence using vtable] - Start")
                    Try
                        Dim ptr15 As IntPtr = Marshal.ReadIntPtr(Me.device)
                        Dim ptr16 As IntPtr = Marshal.ReadIntPtr(ptr15, 36 * IntPtr.Size)
                        Dim delegateForFunctionPointer9 As Hello.CreateFenceDelegate = Marshal.GetDelegateForFunctionPointer(Of Hello.CreateFenceDelegate)(ptr16)
                        Dim iID_ID3D12Fence As Guid = Hello.IID_ID3D12Fence
                        Dim num10 As Integer = delegateForFunctionPointer9(Me.device, 0UL, Hello.D3D12_FENCE_FLAGS.D3D12_FENCE_FLAG_NONE, iID_ID3D12Fence, Me.fence)
                        Console.WriteLine(String.Format("CreateFence result: {0:X}", num10))
                        Dim flag12 As Boolean = num10 < 0
                        If flag12 Then
                            Console.WriteLine(String.Format("Failed to create fence. HRESULT: {0:X}", num10))
                        Else
                            Console.WriteLine(String.Format("Successfully created fence: {0:X}", Me.fence))
                            Me.fenceValue = 1UL
                            Me.fenceEvent = Hello.CreateEvent(IntPtr.Zero, False, False, Nothing)
                            Dim flag13 As Boolean = Me.fenceEvent = System.IntPtr.Zero
                            If flag13 Then
                                Console.WriteLine(String.Format("Failed to create fence event. Last error: {0}", Marshal.GetLastWin32Error()))
                            End If
                        End If
                    Catch ex7 As Exception
                        Console.WriteLine("Error creating fence: " + ex7.Message)
                        Console.WriteLine("Stack trace: " + ex7.StackTrace)
                        Me.fence = System.IntPtr.Zero
                    End Try
                End If
            End If
        End If
    End Sub

    Private Sub PopulateCommandList()
        Console.WriteLine("----------------------------------------")
        Console.WriteLine("[WaitForPreviousFrame] - Start")
        Try
            Dim ptr As IntPtr = Marshal.ReadIntPtr(Me.commandAllocator)
            Dim ptr2 As IntPtr = Marshal.ReadIntPtr(ptr, 8 * System.IntPtr.Size)
            Dim delegateForFunctionPointer As Hello.ResetCommandAllocatorDelegate = Marshal.GetDelegateForFunctionPointer(Of Hello.ResetCommandAllocatorDelegate)(ptr2)
            Dim num As Integer = delegateForFunctionPointer(Me.commandAllocator)
            Dim flag As Boolean = num < 0
            If flag Then
                Console.WriteLine(String.Format("Failed to reset command allocator. HRESULT: {0:X}", num))
            Else
                Dim ptr3 As IntPtr = Marshal.ReadIntPtr(Me.commandList)
                Dim ptr4 As IntPtr = Marshal.ReadIntPtr(ptr3, 10 * IntPtr.Size)
                Dim delegateForFunctionPointer2 As Hello.ResetCommandListDelegate = Marshal.GetDelegateForFunctionPointer(Of Hello.ResetCommandListDelegate)(ptr4)
                Dim num2 As Integer = delegateForFunctionPointer2(Me.commandList, Me.commandAllocator, Me.pipelineState)
                Dim flag2 As Boolean = num2 < 0
                If flag2 Then
                    Console.WriteLine(String.Format("Failed to reset command list. HRESULT: {0:X}", num2))
                Else
                    Dim ptr5 As IntPtr = Marshal.ReadIntPtr(ptr3, 30 * IntPtr.Size)
                    Dim delegateForFunctionPointer3 As Hello.SetGraphicsRootSignatureDelegate = Marshal.GetDelegateForFunctionPointer(Of Hello.SetGraphicsRootSignatureDelegate)(ptr5)
                    delegateForFunctionPointer3(Me.commandList, Me.rootSignature)
                    Dim pViewports As Hello.D3D12_VIEWPORT() = New Hello.D3D12_VIEWPORT() { New Hello.D3D12_VIEWPORT() With { .TopLeftX = 0F, .TopLeftY = 0F, .Width = 800F, .Height = 600F, .MinDepth = 0F, .MaxDepth = 1F } }
                    Dim ptr6 As IntPtr = Marshal.ReadIntPtr(ptr3, 21 * IntPtr.Size)
                    Dim delegateForFunctionPointer4 As Hello.RSSetViewportsDelegate = Marshal.GetDelegateForFunctionPointer(Of Hello.RSSetViewportsDelegate)(ptr6)
                    delegateForFunctionPointer4(Me.commandList, 1UI, pViewports)
                    Dim pRects As Hello.D3D12_RECT() = New Hello.D3D12_RECT() { New Hello.D3D12_RECT() With { .left = 0, .top = 0, .right = 800, .bottom = 600 } }
                    Dim ptr7 As IntPtr = Marshal.ReadIntPtr(ptr3, 22 * IntPtr.Size)
                    Dim delegateForFunctionPointer5 As Hello.RSSetScissorRectsDelegate = Marshal.GetDelegateForFunctionPointer(Of Hello.RSSetScissorRectsDelegate)(ptr7)
                    delegateForFunctionPointer5(Me.commandList, 1UI, pRects)
                    Dim d3D12_RESOURCE_BARRIER As Hello.D3D12_RESOURCE_BARRIER = CD3DX12_RESOURCE_BARRIER.Transition(Me.renderTargets(Me.frameIndex), Hello.D3D12_RESOURCE_STATES.D3D12_RESOURCE_STATE_COMMON, Hello.D3D12_RESOURCE_STATES.D3D12_RESOURCE_STATE_RENDER_TARGET, 4294967295UI)
                    Dim ptr8 As IntPtr = Marshal.ReadIntPtr(ptr3, 26 * IntPtr.Size)
                    Dim delegateForFunctionPointer6 As Hello.ResourceBarrierDelegate = Marshal.GetDelegateForFunctionPointer(Of Hello.ResourceBarrierDelegate)(ptr8)
                    delegateForFunctionPointer6(Me.commandList, 1UI, New Hello.D3D12_RESOURCE_BARRIER() { d3D12_RESOURCE_BARRIER })
                    Dim d3D12_CPU_DESCRIPTOR_HANDLE As Hello.D3D12_CPU_DESCRIPTOR_HANDLE = New Hello.D3D12_CPU_DESCRIPTOR_HANDLE() With { .ptr = Hello.GetCPUDescriptorHandleForHeapStart(Me.rtvHeap) + Me.frameIndex * CInt(Me.rtvDescriptorSize) }
                    Dim array As Hello.D3D12_CPU_DESCRIPTOR_HANDLE_ARRAY() = New Hello.D3D12_CPU_DESCRIPTOR_HANDLE_ARRAY() { New Hello.D3D12_CPU_DESCRIPTOR_HANDLE_ARRAY() With { .ptr = d3D12_CPU_DESCRIPTOR_HANDLE.ptr } }
                    Dim gCHandle As GCHandle = GCHandle.Alloc(array, GCHandleType.Pinned)
                    Try
                        Dim ptr9 As IntPtr = Marshal.ReadIntPtr(ptr3, 46 * IntPtr.Size)
                        Dim delegateForFunctionPointer7 As Hello.OMSetRenderTargetsDelegate = Marshal.GetDelegateForFunctionPointer(Of Hello.OMSetRenderTargetsDelegate)(ptr9)
                        delegateForFunctionPointer7(Me.commandList, 1UI, array, False, System.IntPtr.Zero)
                    Finally
                        Dim isAllocated As Boolean = gCHandle.IsAllocated
                        If isAllocated Then
                            gCHandle.Free()
                        End If
                    End Try
                    Dim colorRGBA As Single() = New Single() { 0F, 0.2F, 0.4F, 1F }
                    Dim ptr10 As IntPtr = Marshal.ReadIntPtr(ptr3, 48 * IntPtr.Size)
                    Dim delegateForFunctionPointer8 As Hello.ClearRenderTargetViewDelegate = Marshal.GetDelegateForFunctionPointer(Of Hello.ClearRenderTargetViewDelegate)(ptr10)
                    delegateForFunctionPointer8(Me.commandList, d3D12_CPU_DESCRIPTOR_HANDLE, colorRGBA, 0UI, System.IntPtr.Zero)
                    Dim ptr11 As IntPtr = Marshal.ReadIntPtr(ptr3, 20 * IntPtr.Size)
                    Dim delegateForFunctionPointer9 As Hello.IASetPrimitiveTopologyDelegate = Marshal.GetDelegateForFunctionPointer(Of Hello.IASetPrimitiveTopologyDelegate)(ptr11)
                    delegateForFunctionPointer9(Me.commandList, Hello.D3D_PRIMITIVE_TOPOLOGY.D3D_PRIMITIVE_TOPOLOGY_TRIANGLELIST)
                    Dim ptr12 As IntPtr = Marshal.ReadIntPtr(ptr3, 44 * IntPtr.Size)
                    Dim delegateForFunctionPointer10 As Hello.IASetVertexBuffersDelegate = Marshal.GetDelegateForFunctionPointer(Of Hello.IASetVertexBuffersDelegate)(ptr12)
                    delegateForFunctionPointer10(Me.commandList, 0UI, 1UI, New Hello.D3D12_VERTEX_BUFFER_VIEW() { Me.vertexBufferView })
                    Dim ptr13 As IntPtr = Marshal.ReadIntPtr(ptr3, 12 * IntPtr.Size)
                    Dim delegateForFunctionPointer11 As Hello.DrawInstancedDelegate = Marshal.GetDelegateForFunctionPointer(Of Hello.DrawInstancedDelegate)(ptr13)
                    delegateForFunctionPointer11(Me.commandList, 3UI, 1UI, 0UI, 0UI)
                    d3D12_RESOURCE_BARRIER = CD3DX12_RESOURCE_BARRIER.Transition(Me.renderTargets(Me.frameIndex), Hello.D3D12_RESOURCE_STATES.D3D12_RESOURCE_STATE_RENDER_TARGET, Hello.D3D12_RESOURCE_STATES.D3D12_RESOURCE_STATE_COMMON, 4294967295UI)
                    delegateForFunctionPointer6(Me.commandList, 1UI, New Hello.D3D12_RESOURCE_BARRIER() { d3D12_RESOURCE_BARRIER })
                    Dim ptr14 As IntPtr = Marshal.ReadIntPtr(ptr3, 9 * IntPtr.Size)
                    Dim delegateForFunctionPointer12 As Hello.CloseDelegate = Marshal.GetDelegateForFunctionPointer(Of Hello.CloseDelegate)(ptr14)
                    num2 = delegateForFunctionPointer12(Me.commandList)
                End If
            End If
        Catch ex As Exception
            Console.WriteLine("Error in PopulateCommandList: " + ex.Message)
            Console.WriteLine("Stack trace: " + ex.StackTrace)
        End Try
    End Sub

Private Sub WaitForPreviousFrame()
        'Console.WriteLine("----------------------------------------")
        'Console.WriteLine("[WaitForPreviousFrame] - Start")
        
        If Me.fence = IntPtr.Zero Then
            Console.WriteLine("Error: Fence is null. Skipping WaitForPreviousFrame.")
            Return
        End If

        Try
            Dim ptrQueue As IntPtr = Marshal.ReadIntPtr(Me.commandQueue)
            Dim ptrSignal As IntPtr = Marshal.ReadIntPtr(ptrQueue, 14 * System.IntPtr.Size)
            Dim signal As Hello.SignalDelegate = Marshal.GetDelegateForFunctionPointer(Of Hello.SignalDelegate)(ptrSignal)

            Dim num As Integer = signal(Me.commandQueue, Me.fence, Me.fenceValue)
            Dim flag As Boolean = num < 0
            If flag Then
                Console.WriteLine(String.Format("Signal failed with HRESULT: {0:X}", num))
                Return
            End If

            Dim ptrFence As IntPtr = Marshal.ReadIntPtr(Me.fence)
            Dim ptrGetCompleted As IntPtr = Marshal.ReadIntPtr(ptrFence, 8 * IntPtr.Size)
            Dim getCompletedValue As Hello.GetCompletedValueDelegate = Marshal.GetDelegateForFunctionPointer(Of Hello.GetCompletedValueDelegate)(ptrGetCompleted)

            If getCompletedValue(Me.fence) < Me.fenceValue Then
                Dim ptrSetEvent As IntPtr = Marshal.ReadIntPtr(ptrFence, 9 * IntPtr.Size)
                Dim setEventOnCompletion As Hello.SetEventOnCompletionDelegate = Marshal.GetDelegateForFunctionPointer(Of Hello.SetEventOnCompletionDelegate)(ptrSetEvent)

                num = setEventOnCompletion(Me.fence, Me.fenceValue, Me.fenceEvent)
                Dim flag3 As Boolean = num < 0
                If flag3 Then
                    Console.WriteLine(String.Format("SetEventOnCompletion failed with HRESULT: {0:X}", num))
                    Return
                End If
                
                Hello.WaitForSingleObject(Me.fenceEvent, 4294967295UI) ' INFINITE Wait
            End If

            Me.fenceValue += 1UL

        Catch ex As Exception
            Console.WriteLine("Error in WaitForPreviousFrame: " + ex.Message)
            Console.WriteLine("Stack trace: " + ex.StackTrace)
        End Try
    End Sub

    Public Sub Render()
        'Console.WriteLine("----------------------------------------")
        'Console.WriteLine("[Render] - Start")
        Try
            Dim ptrChainVTable As IntPtr = Marshal.ReadIntPtr(Me.swapChain)
            Dim getBackBufferIndexPtr As IntPtr = Marshal.ReadIntPtr(ptrChainVTable, 36 * IntPtr.Size)
            Dim getBackBufferIndex As GetCurrentBackBufferIndexDelegate = Marshal.GetDelegateForFunctionPointer(Of GetCurrentBackBufferIndexDelegate)(getBackBufferIndexPtr)

            Me.frameIndex = CInt(getBackBufferIndex(Me.swapChain))

            Me.PopulateCommandList()

            Dim ppCommandLists As IntPtr() = New IntPtr() {Me.commandList}
            Dim ptrQueue As IntPtr = Marshal.ReadIntPtr(Me.commandQueue)
            Dim ptrExec As IntPtr = Marshal.ReadIntPtr(ptrQueue, 10 * System.IntPtr.Size)
            Dim executeCommandLists As Hello.ExecuteCommandListsDelegate = Marshal.GetDelegateForFunctionPointer(Of Hello.ExecuteCommandListsDelegate)(ptrExec)
            
            executeCommandLists(Me.commandQueue, 1UI, ppCommandLists)

            Dim ptrChain As IntPtr = Marshal.ReadIntPtr(Me.swapChain)
            Dim ptrPresent As IntPtr = Marshal.ReadIntPtr(ptrChain, 8 * IntPtr.Size)
            Dim present As Hello.PresentDelegate = Marshal.GetDelegateForFunctionPointer(Of Hello.PresentDelegate)(ptrPresent)

            Dim num As Integer = present(Me.swapChain, 1UI, 0UI)

            Dim flag As Boolean = num < 0
            If flag Then
                Console.WriteLine(String.Format("Present failed with HRESULT: {0:X}", num))
                Return
            Else
                Me.WaitForPreviousFrame()
            End If

        Catch ex As Exception
            Console.WriteLine("Error in Render: " + ex.Message)
            Console.WriteLine("Stack trace: " + ex.StackTrace)
        End Try
    End Sub

    Private Sub CleanupDevice()
        Console.WriteLine("----------------------------------------")
        Console.WriteLine("[CleanupDevice] - Start")
        Hello.CloseHandle(Me.fenceEvent)
        Dim flag As Boolean = Me.fence <> System.IntPtr.Zero
        If flag Then
            Marshal.Release(Me.fence)
        End If
        Dim flag2 As Boolean = Me.vertexBuffer <> System.IntPtr.Zero
        If flag2 Then
            Marshal.Release(Me.vertexBuffer)
        End If
        Dim flag3 As Boolean = Me.pipelineState <> System.IntPtr.Zero
        If flag3 Then
            Marshal.Release(Me.pipelineState)
        End If
        Dim flag4 As Boolean = Me.rootSignature <> System.IntPtr.Zero
        If flag4 Then
            Marshal.Release(Me.rootSignature)
        End If
        Dim flag5 As Boolean = Me.commandList <> System.IntPtr.Zero
        If flag5 Then
            Marshal.Release(Me.commandList)
        End If
        Dim flag6 As Boolean = Me.commandAllocator <> System.IntPtr.Zero
        If flag6 Then
            Marshal.Release(Me.commandAllocator)
        End If
        Dim flag7 As Boolean = Me.rtvHeap <> System.IntPtr.Zero
        If flag7 Then
            Marshal.Release(Me.rtvHeap)
        End If
        Dim array As IntPtr() = Me.renderTargets
        For i As Integer = 0 To array.Length - 1
            Dim intPtr As IntPtr = array(i)
            Dim flag8 As Boolean = intPtr <> System.IntPtr.Zero
            If flag8 Then
                Marshal.Release(intPtr)
            End If
        Next
        Dim flag9 As Boolean = Me.swapChain <> System.IntPtr.Zero
        If flag9 Then
            Marshal.Release(Me.swapChain)
        End If
        Dim flag10 As Boolean = Me.commandQueue <> System.IntPtr.Zero
        If flag10 Then
            Marshal.Release(Me.commandQueue)
        End If
        Dim flag11 As Boolean = Me.device <> System.IntPtr.Zero
        If flag11 Then
            Marshal.Release(Me.device)
        End If
    End Sub

    Private Sub LoadPipeline(hwnd As IntPtr)
        Console.WriteLine("----------------------------------------")
        Console.WriteLine("[LoadPipeline] - Start")
        Try
            Dim iID_ID3D12Debug As Guid = Hello.IID_ID3D12Debug
            Dim intPtr As IntPtr
            Dim num As Integer = Hello.D3D12GetDebugInterface(iID_ID3D12Debug, intPtr)
            Dim flag As Boolean = num >= 0 AndAlso intPtr <> System.IntPtr.Zero
            If flag Then
                Console.WriteLine("Enabling debug layer...")
                Dim iD3D12Debug As Hello.ID3D12Debug = TryCast(Marshal.GetObjectForIUnknown(intPtr), Hello.ID3D12Debug)
                iD3D12Debug.EnableDebugLayer()
                Marshal.ReleaseComObject(iD3D12Debug)
            Else
                Console.WriteLine(String.Format("Failed to get debug interface: {0:X}", num))
            End If
            Dim zero As IntPtr = System.IntPtr.Zero
            Dim iID_IDXGIFactory As Guid = Hello.IID_IDXGIFactory4
            Dim num2 As Integer = Hello.CreateDXGIFactory2(0UI, iID_IDXGIFactory, zero)
            Dim flag2 As Boolean = num2 < 0
            If flag2 Then
                Throw New Exception(String.Format("Failed to create DXGI Factory2: {0:X}", num2))
            End If
            Dim iID_ID3D12Device As Guid = Hello.IID_ID3D12Device
            num2 = Hello.D3D12CreateDevice(IntPtr.Zero, 45056UI, iID_ID3D12Device, Me.device)
            Dim flag3 As Boolean = num2 < 0
            If flag3 Then
                Throw New Exception(String.Format("Failed to create D3D12 Device: {0:X}", num2))
            End If
            Dim d3D12_COMMAND_QUEUE_DESC As Hello.D3D12_COMMAND_QUEUE_DESC = New Hello.D3D12_COMMAND_QUEUE_DESC() With { .Type = Hello.D3D12_COMMAND_LIST_TYPE.D3D12_COMMAND_LIST_TYPE_DIRECT, .Priority = 0, .Flags = Hello.D3D12_COMMAND_QUEUE_FLAGS.D3D12_COMMAND_QUEUE_FLAG_NONE, .NodeMask = 0UI }
            Dim ptr As IntPtr = Marshal.ReadIntPtr(Me.device)
            Dim ptr2 As IntPtr = Marshal.ReadIntPtr(ptr, 8 * System.IntPtr.Size)
            Dim delegateForFunctionPointer As Hello.CreateCommandQueueDelegate = Marshal.GetDelegateForFunctionPointer(Of Hello.CreateCommandQueueDelegate)(ptr2)
            Dim iID_ID3D12CommandQueue As Guid = Hello.IID_ID3D12CommandQueue
            num2 = delegateForFunctionPointer(Me.device, d3D12_COMMAND_QUEUE_DESC, iID_ID3D12CommandQueue, Me.commandQueue)
            Dim flag4 As Boolean = num2 < 0
            If flag4 Then
                Throw New Exception(String.Format("Failed to create Command Queue: {0:X}", num2))
            End If
            Hello.swapChainDesc1 = New Hello.DXGI_SWAP_CHAIN_DESC1() With { .Width = 800UI, .Height = 600UI, .Format = 28UI, .Stereo = False, .SampleDesc = New Hello.DXGI_SAMPLE_DESC() With { .Count = 1UI, .Quality = 0UI }, .BufferUsage = 32UI, .BufferCount = 2UI, .Scaling = Hello.DXGI_SCALING.DXGI_SCALING_STRETCH, .SwapEffect = 4UI, .AlphaMode = Hello.DXGI_ALPHA_MODE.DXGI_ALPHA_MODE_UNSPECIFIED, .Flags = 66UI }
            num2 = Hello.CreateSwapChainForHwnd(zero, Me.commandQueue, hwnd, Hello.swapChainDesc1, System.IntPtr.Zero, System.IntPtr.Zero, Me.swapChain)
            Dim flag5 As Boolean = num2 < 0
            If flag5 Then
                Throw New Exception(String.Format("Failed to create Swap Chain: {0:X}", num2))
            End If
            Dim d3D12_DESCRIPTOR_HEAP_DESC As Hello.D3D12_DESCRIPTOR_HEAP_DESC = New Hello.D3D12_DESCRIPTOR_HEAP_DESC() With { .Type = Hello.D3D12_DESCRIPTOR_HEAP_TYPE.D3D12_DESCRIPTOR_HEAP_TYPE_RTV, .NumDescriptors = 2UI, .Flags = Hello.D3D12_DESCRIPTOR_HEAP_FLAGS.D3D12_DESCRIPTOR_HEAP_FLAG_NONE, .NodeMask = 0UI }
            Dim iID_ID3D12DescriptorHeap As Guid = Hello.IID_ID3D12DescriptorHeap
            ptr = Marshal.ReadIntPtr(Me.device)
            Dim ptr3 As IntPtr = Marshal.ReadIntPtr(ptr, 14 * IntPtr.Size)
            Dim delegateForFunctionPointer2 As Hello.CreateDescriptorHeapDelegate = Marshal.GetDelegateForFunctionPointer(Of Hello.CreateDescriptorHeapDelegate)(ptr3)
            num2 = delegateForFunctionPointer2(Me.device, d3D12_DESCRIPTOR_HEAP_DESC, iID_ID3D12DescriptorHeap, Me.rtvHeap)
            Dim flag6 As Boolean = num2 < 0
            If flag6 Then
                Throw New Exception(String.Format("Failed to create Descriptor Heap: {0:X}", num2))
            End If
            Dim ptr4 As IntPtr = Marshal.ReadIntPtr(ptr, 15 * IntPtr.Size)
            Dim delegateForFunctionPointer3 As Hello.GetDescriptorHandleIncrementSizeDelegate = Marshal.GetDelegateForFunctionPointer(Of Hello.GetDescriptorHandleIncrementSizeDelegate)(ptr4)
            Me.rtvDescriptorSize = delegateForFunctionPointer3(Me.device, Hello.D3D12_DESCRIPTOR_HEAP_TYPE.D3D12_DESCRIPTOR_HEAP_TYPE_RTV)
            Dim destDescriptor As Hello.D3D12_CPU_DESCRIPTOR_HANDLE = New Hello.D3D12_CPU_DESCRIPTOR_HANDLE() With { .ptr = Hello.GetCPUDescriptorHandleForHeapStart(Me.rtvHeap) }
            For i As Integer = 0 To 2 - 1
                Dim ptr5 As IntPtr = Marshal.ReadIntPtr(Me.swapChain)
                Dim ptr6 As IntPtr = Marshal.ReadIntPtr(ptr5, 9 * IntPtr.Size)
                Dim delegateForFunctionPointer4 As Hello.GetBufferDelegate = Marshal.GetDelegateForFunctionPointer(Of Hello.GetBufferDelegate)(ptr6)
                Dim iID_ID3D12Resource As Guid = Hello.IID_ID3D12Resource
                Dim intPtr2 As IntPtr
                num2 = delegateForFunctionPointer4(Me.swapChain, CUInt(i), iID_ID3D12Resource, intPtr2)
                Dim flag7 As Boolean = num2 < 0
                If flag7 Then
                    Throw New Exception(String.Format("Failed to get Buffer: {0:X}", num2))
                End If
                Me.renderTargets(i) = intPtr2
                ptr = Marshal.ReadIntPtr(Me.device)
                Dim ptr7 As IntPtr = Marshal.ReadIntPtr(ptr, 20 * IntPtr.Size)
                Dim delegateForFunctionPointer5 As Hello.CreateRenderTargetViewDelegate = Marshal.GetDelegateForFunctionPointer(Of Hello.CreateRenderTargetViewDelegate)(ptr7)
                delegateForFunctionPointer5(Me.device, intPtr2, System.IntPtr.Zero, destDescriptor)
                Dim d3D12_RESOURCE_BARRIER As D3D12_RESOURCE_BARRIER = CD3DX12_RESOURCE_BARRIER.Transition(Me.renderTargets(i), Hello.D3D12_RESOURCE_STATES.D3D12_RESOURCE_STATE_COMMON, Hello.D3D12_RESOURCE_STATES.D3D12_RESOURCE_STATE_COMMON, 4294967295UI)
                destDescriptor.ptr += CInt(Me.rtvDescriptorSize)
            Next
            ptr = Marshal.ReadIntPtr(Me.device)
            Dim ptr8 As IntPtr = Marshal.ReadIntPtr(ptr, 9 * IntPtr.Size)
            Dim delegateForFunctionPointer6 As Hello.CreateCommandAllocatorDelegate = Marshal.GetDelegateForFunctionPointer(Of Hello.CreateCommandAllocatorDelegate)(ptr8)
            Dim iID_ID3D12CommandAllocator As Guid = Hello.IID_ID3D12CommandAllocator
            num2 = delegateForFunctionPointer6(Me.device, Hello.D3D12_COMMAND_LIST_TYPE.D3D12_COMMAND_LIST_TYPE_DIRECT, iID_ID3D12CommandAllocator, Me.commandAllocator)
            Dim flag8 As Boolean = num2 < 0
            If flag8 Then
                Throw New Exception(String.Format("Failed to create Command Allocator: {0:X}", num2))
            End If
            Marshal.Release(zero)
        Catch ex As Exception
            Console.WriteLine("Error in LoadPipeline: " + ex.Message)
            Console.WriteLine("Stack trace: " + ex.StackTrace)
            Throw
        End Try
    End Sub

    Private Shared Function WndProc(hWnd As IntPtr, uMsg As UInteger, wParam As IntPtr, lParam As IntPtr) As IntPtr
        Dim pAINTSTRUCT As Hello.PAINTSTRUCT = Nothing
        Dim text As String = "Hello, DirectX11(C#) World!"
        Dim result As IntPtr
        If uMsg <> 2UI Then
            If uMsg <> 15UI Then
                result = Hello.DefWindowProc(hWnd, uMsg, wParam, lParam)
                Return result
            End If
            Dim hdc As IntPtr = Hello.BeginPaint(hWnd, pAINTSTRUCT)
            Hello.TextOut(hdc, 0, 0, text, text.Length)
            Hello.EndPaint(hWnd, pAINTSTRUCT)
        Else
            Hello.PostQuitMessage(0)
        End If
        result = System.IntPtr.Zero
        Return result
    End Function

    <STAThread()>
    Public Shared Function Main(args As String()) As Integer
        Console.WriteLine("----------------------------------------")
        Console.WriteLine("[Main] - Start")
        Dim hello As Hello = New Hello()
        Dim hINSTANCE As IntPtr = Marshal.GetHINSTANCE(GetType(Hello).[Module])
        Console.WriteLine(String.Format("hInstance: {0}", hINSTANCE))
        Dim wNDCLASSEX As Hello.WNDCLASSEX = New Hello.WNDCLASSEX() With { .cbSize = CUInt(Marshal.SizeOf(GetType(Hello.WNDCLASSEX))), .style = 32UI, .lpfnWndProc = AddressOf Hello.WndProc, .cbClsExtra = 0, .cbWndExtra = 0, .hInstance = hINSTANCE, .hIcon = System.IntPtr.Zero, .hCursor = Hello.LoadCursor(IntPtr.Zero, 32512), .hbrBackground = System.IntPtr.Zero, .lpszMenuName = Nothing, .lpszClassName = "MyDXWindowClass", .hIconSm = System.IntPtr.Zero }
        Console.WriteLine(String.Format("WNDCLASSEX Size: {0}", wNDCLASSEX.cbSize))
        Console.WriteLine(String.Format("WndProc Pointer: {0}", wNDCLASSEX.lpfnWndProc))
        Dim num As UShort = Hello.RegisterClassEx(wNDCLASSEX)
        Dim lastWin32Error As Integer = Marshal.GetLastWin32Error()
        Console.WriteLine(String.Format("RegisterClassEx result: {0}", num))
        Console.WriteLine(String.Format("Last error: {0}", lastWin32Error))
        Dim flag As Boolean = num = 0
        Dim result As Integer
        If flag Then
            Console.WriteLine(String.Format("Failed to register window class. Error: {0}", lastWin32Error))
            result = 0
        Else
            Dim intPtr As IntPtr = Hello.CreateWindowEx(0UI, "MyDXWindowClass", "Helo, World!", 282001408UI, 100, 100, 800, 600, System.IntPtr.Zero, System.IntPtr.Zero, hINSTANCE, System.IntPtr.Zero)
            Try
                hello.LoadPipeline(intPtr)
                hello.LoadAssets()
                Hello.ShowWindow(intPtr, 1)
                Dim mSG As Hello.MSG = Nothing
                While mSG.message <> 18UI
                    Dim flag2 As Boolean = Hello.PeekMessage(mSG, System.IntPtr.Zero, 0UI, 0UI, 1UI)
                    If flag2 Then
                        Hello.TranslateMessage(mSG)
                        Hello.DispatchMessage(mSG)
                    Else
                        hello.Render()
                    End If
                End While
                result = CInt(mSG.wParam)
            Finally
                hello.CleanupDevice()
            End Try
        End If
        Return result
    End Function
End Class
