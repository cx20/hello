package main

import (
    "fmt"
    "math"
    "math/rand"
    "runtime"
    "syscall"
    "unsafe"
)

// =============================================================================
// Constants
// =============================================================================
const (
    CW_USEDEFAULT       = 0x80000000
    WS_OVERLAPPEDWINDOW = 0x00CF0000
    WS_VISIBLE          = 0x10000000
    PM_REMOVE           = 0x0001
    WM_QUIT             = 0x0012
    WM_DESTROY          = 0x0002

    DXGI_FORMAT_R8G8B8A8_UNORM     = 28
    DXGI_FORMAT_R32G32B32A32_FLOAT = 2

    D3D_FEATURE_LEVEL_11_0 = 0xb000

    D3D12_COMMAND_LIST_TYPE_DIRECT = 0
    D3D12_COMMAND_QUEUE_FLAG_NONE  = 0

    D3D12_RESOURCE_STATE_PRESENT             = 0
    D3D12_RESOURCE_STATE_COMMON              = 0
    D3D12_RESOURCE_STATE_RENDER_TARGET       = 4
    D3D12_RESOURCE_STATE_UNORDERED_ACCESS    = 0x8
    D3D12_RESOURCE_STATE_VERTEX_AND_CONSTANT = 0x1

    D3D12_DESCRIPTOR_HEAP_TYPE_RTV     = 2
    D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV = 0
    D3D12_DESCRIPTOR_HEAP_FLAG_NONE    = 0
    D3D12_DESCRIPTOR_HEAP_FLAG_VISIBLE = 1

    D3D12_ROOT_SIGNATURE_FLAG_ALLOW_INPUT_ASSEMBLER_INPUT_LAYOUT = 0x1

    D3D12_FILL_MODE_SOLID = 3
    D3D12_CULL_MODE_NONE  = 1

    D3D12_PRIMITIVE_TOPOLOGY_TYPE_LINE = 2
    D3D_PRIMITIVE_TOPOLOGY_LINESTRIP   = 3

    D3D12_HEAP_TYPE_DEFAULT         = 1
    D3D12_RESOURCE_DIMENSION_BUFFER = 1

    D3D12_ROOT_PARAMETER_TYPE_32BIT_CONSTANTS  = 1
    D3D12_ROOT_PARAMETER_TYPE_DESCRIPTOR_TABLE = 0
    D3D12_SHADER_VISIBILITY_ALL                = 0

    D3D12_RESOURCE_FLAG_ALLOW_UNORDERED_ACCESS = 0x4

    D3DCOMPILE_DEBUG             = 0x1
    D3DCOMPILE_SKIP_OPTIMIZATION = 0x4
    D3DCOMPILE_ENABLE_STRICTNESS = 0x800

    INFINITE = 0xFFFFFFFF
    DXGI_CREATE_FACTORY_DEBUG = 0x1
)

const (
    FrameCount  = 2
    Width       = 1024
    Height      = 768
    VertexCount = 500000
    PI2         = 6.283185307179586
)

// =============================================================================
// DLL & Procedure declarations
// =============================================================================
var (
    user32      = syscall.NewLazyDLL("user32.dll")
    kernel32    = syscall.NewLazyDLL("kernel32.dll")
    d3d12       = syscall.NewLazyDLL("d3d12.dll")
    dxgi        = syscall.NewLazyDLL("dxgi.dll")
    d3dcompiler = syscall.NewLazyDLL("d3dcompiler_47.dll")

    procRegisterClassExW    = user32.NewProc("RegisterClassExW")
    procCreateWindowExW     = user32.NewProc("CreateWindowExW")
    procDefWindowProcW      = user32.NewProc("DefWindowProcW")
    procPeekMessageW        = user32.NewProc("PeekMessageW")
    procTranslateMessage    = user32.NewProc("TranslateMessage")
    procDispatchMessageW    = user32.NewProc("DispatchMessageW")
    procPostQuitMessage     = user32.NewProc("PostQuitMessage")
    procShowWindow          = user32.NewProc("ShowWindow")
    procLoadCursorW         = user32.NewProc("LoadCursorW")

    procGetModuleHandleW    = kernel32.NewProc("GetModuleHandleW")
    procCreateEventExW      = kernel32.NewProc("CreateEventExW")
    procWaitForSingleObject = kernel32.NewProc("WaitForSingleObject")
    procCloseHandle         = kernel32.NewProc("CloseHandle")
    procOutputDebugStringA  = kernel32.NewProc("OutputDebugStringA")
    procGetTickCount        = kernel32.NewProc("GetTickCount")

    procD3D12CreateDevice           = d3d12.NewProc("D3D12CreateDevice")
    procD3D12GetDebugInterface      = d3d12.NewProc("D3D12GetDebugInterface")
    procD3D12SerializeRootSignature = d3d12.NewProc("D3D12SerializeRootSignature")
    procCreateDXGIFactory2          = dxgi.NewProc("CreateDXGIFactory2")
    procD3DCompile                  = d3dcompiler.NewProc("D3DCompile")
)

// =============================================================================
// GUIDs for DirectX 12 interfaces
// =============================================================================
var (
    IID_ID3D12Debug = GUID{0x344488b7, 0x6846, 0x474b, [8]byte{0xb9, 0x89, 0xf0, 0x27, 0x44, 0x82, 0x45, 0xe0}}

    IID_IDXGIFactory4   = GUID{0x1bc6ea02, 0xef36, 0x464f, [8]byte{0xbf, 0x0c, 0x21, 0xca, 0x39, 0xe5, 0x16, 0x8a}}
    IID_IDXGISwapChain3 = GUID{0x94d99bdb, 0xf1f8, 0x4ab0, [8]byte{0xb2, 0x36, 0x7d, 0xa0, 0x17, 0x0e, 0xda, 0xb1}}

    IID_ID3D12Device           = GUID{0x189819f1, 0x1db6, 0x4b57, [8]byte{0xbe, 0x54, 0x18, 0x21, 0x33, 0x9b, 0x85, 0xf7}}
    IID_ID3D12CommandQueue     = GUID{0x0ec870a6, 0x5d7e, 0x4c22, [8]byte{0x8c, 0xfc, 0x5b, 0xaa, 0xe0, 0x76, 0x16, 0xed}}
    IID_ID3D12Resource         = GUID{0x696442be, 0xa72e, 0x4059, [8]byte{0xbc, 0x79, 0x5b, 0x5c, 0x98, 0x04, 0x0f, 0xad}}
    IID_ID3D12CommandAllocator = GUID{0x6102dee4, 0xaf59, 0x4b09, [8]byte{0xb9, 0x99, 0xb4, 0x4d, 0x73, 0xf0, 0x9b, 0x24}}
    IID_ID3D12RootSignature    = GUID{0xc54a6b66, 0x72df, 0x4ee8, [8]byte{0x8b, 0xe5, 0xa9, 0x46, 0xa1, 0x42, 0x92, 0x14}}
    IID_ID3D12PipelineState    = GUID{0x765a30f3, 0xf624, 0x4c6f, [8]byte{0xa8, 0x28, 0xac, 0xe9, 0x48, 0x62, 0x24, 0x45}}
    IID_ID3D12DescriptorHeap   = GUID{0x8efb471d, 0x616c, 0x4f49, [8]byte{0x90, 0xf7, 0x12, 0x7b, 0xb7, 0x63, 0xfa, 0x51}}
    IID_ID3D12CommandList      = GUID{0x5b160d0f, 0xac1b, 0x4185, [8]byte{0x8b, 0xa8, 0xb3, 0xae, 0x42, 0xa5, 0xa4, 0x55}}
    IID_ID3D12Fence            = GUID{0x0a753dcf, 0xc4d8, 0x4b91, [8]byte{0xad, 0xf6, 0xbe, 0x5a, 0x60, 0xd9, 0x5a, 0x76}}
)

// =============================================================================
// Type definitions
// =============================================================================
type GUID struct {
    Data1 uint32
    Data2 uint16
    Data3 uint16
    Data4 [8]byte
}

type D3D12_CPU_DESCRIPTOR_HANDLE struct{ ptr uintptr }
type D3D12_GPU_DESCRIPTOR_HANDLE struct{ ptr uint64 }

type MSG_WIN struct {
    Hwnd    syscall.Handle
    Message uint32
    Padding uint32
    WParam  uintptr
    LParam  uintptr
    Time    uint32
    Pt      struct{ X, Y int32 }
}

type WNDCLASSEXW struct {
    Size, Style                        uint32
    WndProc                            uintptr
    ClsExtra, WndExtra                 int32
    Instance, Icon, Cursor, Background syscall.Handle
    MenuName, ClassName                *uint16
    IconSm                             syscall.Handle
}

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

type D3D12_COMMAND_QUEUE_DESC struct {
    Type     int32
    Priority int32
    Flags    int32
    NodeMask uint32
}

type D3D12_DESCRIPTOR_HEAP_DESC struct {
    Type           int32
    NumDescriptors uint32
    Flags          int32
    NodeMask       uint32
}

type D3D12_INPUT_ELEMENT_DESC struct {
    SemanticName         *byte
    SemanticIndex        uint32
    Format               uint32
    InputSlot            uint32
    AlignedByteOffset    uint32
    InputSlotClass       int32
    InstanceDataStepRate uint32
}

type D3D12_ROOT_SIGNATURE_DESC struct {
    NumParameters     uint32
    _pad1             uint32
    pParameters       uintptr
    NumStaticSamplers uint32
    _pad2             uint32
    pStaticSamplers   uintptr
    Flags             uint32
    _pad3             uint32
}

type D3D12_ROOT_CONSTANTS struct {
    ShaderRegister uint32
    RegisterSpace  uint32
    Num32BitValues uint32
}

type D3D12_DESCRIPTOR_RANGE struct {
    RangeType                         int32
    NumDescriptors                    uint32
    BaseShaderRegister                uint32
    RegisterSpace                     uint32
    OffsetInDescriptorsFromTableStart uint32
}

type D3D12_ROOT_DESCRIPTOR_TABLE struct {
    NumDescriptorRanges uint32
    _pad                uint32
    pDescriptorRanges   uintptr
}

type D3D12_ROOT_PARAMETER struct {
    ParameterType    int32
    _pad             uint32
    DescriptorTable  D3D12_ROOT_DESCRIPTOR_TABLE
    ShaderVisibility int32
    _pad3            uint32
}

type D3D12_ROOT_PARAMETER_CONSTANTS struct {
    ParameterType    int32
    _pad             uint32
    Constants        D3D12_ROOT_CONSTANTS
    _pad2            uint32
    ShaderVisibility int32
    _pad3            uint32
}

type D3D12_BLEND_DESC struct {
    AlphaToCoverageEnable  int32
    IndependentBlendEnable int32
    RenderTarget           [8]struct {
        BlendEnable, LogicOpEnable                  int32
        SrcBlend, DestBlend, BlendOp                int32
        SrcBlendAlpha, DestBlendAlpha, BlendOpAlpha int32
        LogicOp                                     int32
        RenderTargetWriteMask                       uint8
        _pad                                        [3]byte
    }
}

type D3D12_RASTERIZER_DESC struct {
    FillMode              int32
    CullMode              int32
    FrontCounterClockwise int32
    DepthBias             int32
    DepthBiasClamp        float32
    SlopeScaledDepthBias  float32
    DepthClipEnable       int32
    MultisampleEnable     int32
    AntialiasedLineEnable int32
    ForcedSampleCount     uint32
    ConservativeRaster    int32
}

type D3D12_DEPTH_STENCIL_DESC struct {
    DepthEnable      int32
    DepthWriteMask   int32
    DepthFunc        int32
    StencilEnable    int32
    StencilReadMask  uint8
    StencilWriteMask uint8
    FrontFace        struct{ StencilFailOp, StencilDepthFailOp, StencilPassOp, StencilFunc int32 }
    BackFace         struct{ StencilFailOp, StencilDepthFailOp, StencilPassOp, StencilFunc int32 }
}

type D3D12_GRAPHICS_PIPELINE_STATE_DESC struct {
    pRootSignature uintptr
    VS, PS, DS, HS, GS struct {
        pShaderBytecode uintptr
        BytecodeLength  uintptr
    }
    StreamOutput struct {
        pSODecl          uintptr
        NumEntries       uint32
        pBufferStrides   uintptr
        NumStrides       uint32
        RasterizedStream uint32
    }
    BlendState        D3D12_BLEND_DESC
    SampleMask        uint32
    RasterizerState   D3D12_RASTERIZER_DESC
    DepthStencilState D3D12_DEPTH_STENCIL_DESC
    InputLayout       struct {
        pInputElementDescs uintptr
        NumElements        uint32
    }
    IBStripCutValue       int32
    PrimitiveTopologyType int32
    NumRenderTargets      uint32
    RTVFormats            [8]uint32
    DSVFormat             uint32
    SampleDesc            DXGI_SAMPLE_DESC
    NodeMask              uint32
    CachedPSO             struct {
        pCachedBlob           uintptr
        CachedBlobSizeInBytes uintptr
    }
    Flags int32
}

type D3D12_COMPUTE_PIPELINE_STATE_DESC struct {
    pRootSignature uintptr
    CS             struct {
        pShaderBytecode uintptr
        BytecodeLength  uintptr
    }
    NodeMask  uint32
    CachedPSO struct {
        pCachedBlob           uintptr
        CachedBlobSizeInBytes uintptr
    }
    Flags int32
}

type D3D12_VIEWPORT struct {
    TopLeftX, TopLeftY, Width, Height, MinDepth, MaxDepth float32
}

type D3D12_RECT struct{ Left, Top, Right, Bottom int32 }

type D3D12_HEAP_PROPERTIES struct {
    Type                 int32
    CPUPageProperty      int32
    MemoryPoolPreference int32
    CreationNodeMask     uint32
    VisibleNodeMask      uint32
}

type D3D12_RESOURCE_DESC struct {
    Dimension        int32
    Alignment        uint64
    Width            uint64
    Height           uint32
    DepthOrArraySize uint16
    MipLevels        uint16
    Format           uint32
    SampleDesc       DXGI_SAMPLE_DESC
    Layout           int32
    Flags            int32
}

type D3D12_RESOURCE_BARRIER struct {
    Type        int32
    Flags       int32
    pResource   uintptr
    Subresource uint32
    StateBefore int32
    StateAfter  int32
}

type D3D12_UNORDERED_ACCESS_VIEW_DESC struct {
    Format        uint32
    ViewDimension int32
    Buffer        struct {
        FirstElement         uint64
        NumElements          uint32
        StructureByteStride  uint32
        CounterOffsetInBytes uint64
        Flags                uint32
    }
}

type D3D12_VERTEX_BUFFER_VIEW struct {
    BufferLocation uint64
    SizeInBytes    uint32
    StrideInBytes  uint32
}

// =============================================================================
// Global variables
// =============================================================================
var (
    g_hwnd                  syscall.Handle
    g_device                uintptr
    g_commandQueue          uintptr
    g_swapChain             uintptr
    g_rtvHeap               uintptr
    g_uavHeap               uintptr
    g_rtvDescriptorSize     uint32
    g_renderTargets         [FrameCount]uintptr
    g_commandAllocator      uintptr
    g_computeAllocator      uintptr
    g_graphicsRootSignature uintptr
    g_computeRootSignature  uintptr
    g_graphicsPSO           uintptr
    g_computePSO            uintptr
    g_commandList           uintptr
    g_computeCommandList    uintptr
    g_fence                 uintptr
    g_fenceValue            uint64
    g_fenceEvent            syscall.Handle
    g_frameIndex            uint32
    g_vertexBuffer          uintptr
    g_vbView                D3D12_VERTEX_BUFFER_VIEW
    g_startTick             uint32
    g_frameCount            uint64
    g_firstFrameLogged       bool
    g_vertexBufferNeedsUAVTransition bool

    g_A1 float32 = 50.0
    g_f1 float32 = 2.0
    g_p1 float32 = 1.0 / 16.0
    g_d1 float32 = 0.02
    g_A2 float32 = 50.0
    g_f2 float32 = 2.0
    g_p2 float32 = 3.0 / 2.0
    g_d2 float32 = 0.0315
    g_A3 float32 = 50.0
    g_f3 float32 = 2.0
    g_p3 float32 = 13.0 / 15.0
    g_d3 float32 = 0.02
    g_A4 float32 = 50.0
    g_f4 float32 = 2.0
    g_p4 float32 = 1.0
    g_d4 float32 = 0.02
)

// =============================================================================
// Compute Shader for Harmonograph calculation
// =============================================================================
var computeShaderSource = `
struct Vertex {
    float4 position;
    float4 color;
};

RWStructuredBuffer<Vertex> outputVertices : register(u0);

cbuffer HarmonographParams : register(b0) {
    float A1, f1, p1, d1;
    float A2, f2, p2, d2;
    float A3, f3, p3, d3;
    float A4, f4, p4, d4;
    uint max_num;
    float3 padding;
    float2 resolution;
    float2 padding2;
};

float3 hsv2rgb(float h, float s, float v) {
    float c = v * s;
    float hp = h / 60.0;
    float x = c * (1.0 - abs(fmod(hp, 2.0) - 1.0));
    float3 rgb;

    if (hp < 1.0)
        rgb = float3(c, x, 0.0);
    else if (hp < 2.0)
        rgb = float3(x, c, 0.0);
    else if (hp < 3.0)
        rgb = float3(0.0, c, x);
    else if (hp < 4.0)
        rgb = float3(0.0, x, c);
    else if (hp < 5.0)
        rgb = float3(x, 0.0, c);
    else
        rgb = float3(c, 0.0, x);

    float m = v - c;
    return rgb + float3(m, m, m);
}

[numthreads(64, 1, 1)]
void CSMain(uint3 dispatchThreadID : SV_DispatchThreadID) {
    uint idx = dispatchThreadID.x;
    if (idx >= max_num) return;

    float t = (float)idx * 0.001;
    float PI = 3.14159265;

    float x = A1 * sin(f1 * t + PI * p1) * exp(-d1 * t) +
              A2 * sin(f2 * t + PI * p2) * exp(-d2 * t);
    float y = A3 * sin(f3 * t + PI * p3) * exp(-d3 * t) +
              A4 * sin(f4 * t + PI * p4) * exp(-d4 * t);
    float z = A1 * cos(f1 * t + PI * p1) * exp(-d1 * t) +
              A2 * cos(f2 * t + PI * p2) * exp(-d2 * t);

    outputVertices[idx].position = float4(x, y, z, 1.0);

    float hue = fmod((t / 20.0) * 360.0, 360.0);
    float3 rgb = hsv2rgb(hue, 1.0, 1.0);
    outputVertices[idx].color = float4(rgb, 1.0);
}
`

// =============================================================================
// Graphics Shader for rendering
// =============================================================================
var graphicsShaderSource = `
cbuffer TransformBuffer : register(b0) {
    row_major float4x4 mvpMatrix;
};

struct VSInput {
    float4 position : POSITION;
    float4 color : COLOR;
};

struct PSInput {
    float4 position : SV_POSITION;
    float4 color : COLOR;
};

PSInput VSMain(VSInput input) {
    PSInput output;
    output.position = mul(input.position, mvpMatrix);
    output.color = input.color;
    return output;
}

float4 PSMain(PSInput input) : SV_TARGET {
    return input.color;
}
`

// =============================================================================
// Debug output function
// =============================================================================
func debugLog(format string, args ...interface{}) {
    msg := fmt.Sprintf(format, args...)
    fmt.Println(msg)
    msgBytes := append([]byte(msg), '\n', 0)
    procOutputDebugStringA.Call(uintptr(unsafe.Pointer(&msgBytes[0])))
}

func checkResult(hr uintptr, operation string) bool {
    if int32(hr) < 0 {
        debugLog("[ERROR] %s FAILED: 0x%08X", operation, uint32(hr))
        return false
    }
    debugLog("[OK] %s", operation)
    return true
}

// =============================================================================
// Main entry point
// =============================================================================
func main() {
    runtime.LockOSThread()
    tick, _, _ := procGetTickCount.Call()
    rand.Seed(int64(tick))
    debugLog("=== Harmonograph DX12 Compute Demo ===")
    debugLog("Window: %dx%d, Vertices: %d", Width, Height, VertexCount)

    // Enable debug layer
    var debugController uintptr
    hr, _, _ := procD3D12GetDebugInterface.Call(
        uintptr(unsafe.Pointer(&IID_ID3D12Debug)),
        uintptr(unsafe.Pointer(&debugController)))
    if int32(hr) >= 0 && debugController != 0 {
        comCall(debugController, 3)
        comRelease(debugController)
        debugLog("[OK] D3D12 debug layer enabled")
    } else {
        debugLog("[WARN] D3D12 debug layer not available (hr=0x%08X)", uint32(hr))
    }

    instance := getModuleHandle()
    debugLog("[INIT] initWindow: start")
    if !initWindow(instance) {
        debugLog("[INIT] initWindow: failed")
        return
    }
    debugLog("[INIT] initWindow: done")
    debugLog("[INIT] initDirectX: start")
    if !initDirectX() {
        debugLog("[INIT] initDirectX: failed")
        return
    }
    debugLog("[INIT] initDirectX: done")

    tick, _, _ = procGetTickCount.Call()
    g_startTick = uint32(tick)

    msg := MSG_WIN{}
    for msg.Message != WM_QUIT {
        if peekMessage(&msg, 0, 0, 0, PM_REMOVE) {
            translateMessage(&msg)
            dispatchMessage(&msg)
        } else {
            render()
        }
    }

    waitForPreviousFrame()
    procCloseHandle.Call(uintptr(g_fenceEvent))
}

// =============================================================================
// Window initialization
// =============================================================================
func initWindow(instance syscall.Handle) bool {
    debugLog("[WINDOW] RegisterClassExW")
    className := syscall.StringToUTF16Ptr("HarmonographDX12Class")
    wcex := WNDCLASSEXW{
        Size: uint32(unsafe.Sizeof(WNDCLASSEXW{})), Style: 0x20,
        WndProc: syscall.NewCallback(wndProc), Instance: instance,
        Cursor: loadCursor(0, 32512), ClassName: className,
    }
    ret, _, _ := procRegisterClassExW.Call(uintptr(unsafe.Pointer(&wcex)))
    if ret == 0 {
        debugLog("[WINDOW] RegisterClassExW failed")
        return false
    }
    debugLog("[WINDOW] CreateWindowExW")
    g_hwnd = createWindow(className, "Harmonograph - DX12 Compute (Go)", instance, Width, Height)
    if g_hwnd == 0 {
        debugLog("[WINDOW] CreateWindowExW failed")
        return false
    }
    procShowWindow.Call(uintptr(g_hwnd), 1)
    debugLog("[WINDOW] ShowWindow")
    return true
}

func wndProc(hwnd syscall.Handle, msg uint32, wParam, lParam uintptr) uintptr {
    if msg == WM_DESTROY {
        debugLog("[WINDOW] WM_DESTROY received")
        procPostQuitMessage.Call(0)
        return 0
    }
    ret, _, _ := procDefWindowProcW.Call(uintptr(hwnd), uintptr(msg), wParam, lParam)
    return ret
}

// =============================================================================
// DirectX 12 initialization
// =============================================================================
func initDirectX() bool {
    debugLog("[DX12] CreateDXGIFactory2")
    // Create DXGI Factory
    var factory4 uintptr
    hr, _, _ := procCreateDXGIFactory2.Call(DXGI_CREATE_FACTORY_DEBUG, uintptr(unsafe.Pointer(&IID_IDXGIFactory4)), uintptr(unsafe.Pointer(&factory4)))
    if !checkResult(hr, "CreateDXGIFactory2") {
        return false
    }
    defer comRelease(factory4)

    // Create Device
    debugLog("[DX12] D3D12CreateDevice")
    hr, _, _ = procD3D12CreateDevice.Call(0, D3D_FEATURE_LEVEL_11_0,
        uintptr(unsafe.Pointer(&IID_ID3D12Device)), uintptr(unsafe.Pointer(&g_device)))
    if !checkResult(hr, "D3D12CreateDevice") {
        return false
    }

    // Create Command Queue
    debugLog("[DX12] CreateCommandQueue")
    qDesc := D3D12_COMMAND_QUEUE_DESC{Type: D3D12_COMMAND_LIST_TYPE_DIRECT}
    hr = comCall(g_device, 8, uintptr(unsafe.Pointer(&qDesc)),
        uintptr(unsafe.Pointer(&IID_ID3D12CommandQueue)), uintptr(unsafe.Pointer(&g_commandQueue)))
    if !checkResult(hr, "CreateCommandQueue") {
        return false
    }

    // Create Swap Chain
    debugLog("[DX12] CreateSwapChainForHwnd")
    scDesc := DXGI_SWAP_CHAIN_DESC1{
        Width: Width, Height: Height, Format: DXGI_FORMAT_R8G8B8A8_UNORM,
        SampleDesc: DXGI_SAMPLE_DESC{Count: 1}, BufferUsage: 0x20, BufferCount: FrameCount, SwapEffect: 4,
    }
    var tempSwapChain uintptr
    hr = comCall(factory4, 15, g_commandQueue, uintptr(g_hwnd), uintptr(unsafe.Pointer(&scDesc)), 0, 0, uintptr(unsafe.Pointer(&tempSwapChain)))
    if !checkResult(hr, "CreateSwapChainForHwnd") {
        return false
    }
    hr = comCall(tempSwapChain, 0, uintptr(unsafe.Pointer(&IID_IDXGISwapChain3)), uintptr(unsafe.Pointer(&g_swapChain)))
    comRelease(tempSwapChain)
    if !checkResult(hr, "QueryInterface(SwapChain3)") {
        return false
    }
    g_frameIndex = uint32(comCall(g_swapChain, 36))

    // Create RTV Descriptor Heap
    debugLog("[DX12] CreateDescriptorHeap(RTV)")
    rtvHeapDesc := D3D12_DESCRIPTOR_HEAP_DESC{Type: D3D12_DESCRIPTOR_HEAP_TYPE_RTV, NumDescriptors: FrameCount}
    hr = comCall(g_device, 14, uintptr(unsafe.Pointer(&rtvHeapDesc)),
        uintptr(unsafe.Pointer(&IID_ID3D12DescriptorHeap)), uintptr(unsafe.Pointer(&g_rtvHeap)))
    if !checkResult(hr, "CreateDescriptorHeap(RTV)") {
        return false
    }
    g_rtvDescriptorSize = uint32(comCall(g_device, 15, D3D12_DESCRIPTOR_HEAP_TYPE_RTV))

    // Create UAV Descriptor Heap (shader visible)
    debugLog("[DX12] CreateDescriptorHeap(UAV)")
    uavHeapDesc := D3D12_DESCRIPTOR_HEAP_DESC{Type: D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV, NumDescriptors: 1, Flags: D3D12_DESCRIPTOR_HEAP_FLAG_VISIBLE}
    hr = comCall(g_device, 14, uintptr(unsafe.Pointer(&uavHeapDesc)),
        uintptr(unsafe.Pointer(&IID_ID3D12DescriptorHeap)), uintptr(unsafe.Pointer(&g_uavHeap)))
    if !checkResult(hr, "CreateDescriptorHeap(UAV)") {
        return false
    }

    // Create Render Target Views
    debugLog("[DX12] CreateRenderTargetViews")
    var rtvHandleStruct D3D12_CPU_DESCRIPTOR_HANDLE
    comCall(g_rtvHeap, 9, uintptr(unsafe.Pointer(&rtvHandleStruct)))
    rtvHandleVal := rtvHandleStruct.ptr
    for i := 0; i < FrameCount; i++ {
        hr = comCall(g_swapChain, 9, uintptr(i), uintptr(unsafe.Pointer(&IID_ID3D12Resource)), uintptr(unsafe.Pointer(&g_renderTargets[i])))
        if !checkResult(hr, fmt.Sprintf("GetBuffer(%d)", i)) {
            return false
        }
        comCall(g_device, 20, g_renderTargets[i], 0, rtvHandleVal)
        rtvHandleVal += uintptr(g_rtvDescriptorSize)
    }

    // Create Command Allocators
    debugLog("[DX12] CreateCommandAllocator(Direct)")
    hr = comCall(g_device, 9, D3D12_COMMAND_LIST_TYPE_DIRECT,
        uintptr(unsafe.Pointer(&IID_ID3D12CommandAllocator)), uintptr(unsafe.Pointer(&g_commandAllocator)))
    if !checkResult(hr, "CreateCommandAllocator(Direct)") {
        return false
    }
    debugLog("[DX12] CreateCommandAllocator(Compute)")
    hr = comCall(g_device, 9, D3D12_COMMAND_LIST_TYPE_DIRECT,
        uintptr(unsafe.Pointer(&IID_ID3D12CommandAllocator)), uintptr(unsafe.Pointer(&g_computeAllocator)))
    if !checkResult(hr, "CreateCommandAllocator(Compute)") {
        return false
    }

    // Create Vertex Buffer (UAV for compute shader output)
    debugLog("[DX12] CreateCommittedResource(VB)")
    vertexBufferSize := uint64(VertexCount * 32) // 32 bytes per vertex (float4 pos + float4 color)
    heapProps := D3D12_HEAP_PROPERTIES{Type: D3D12_HEAP_TYPE_DEFAULT, CreationNodeMask: 1, VisibleNodeMask: 1}
    resDesc := D3D12_RESOURCE_DESC{
        Dimension: D3D12_RESOURCE_DIMENSION_BUFFER, Width: vertexBufferSize, Height: 1,
        DepthOrArraySize: 1, MipLevels: 1, SampleDesc: DXGI_SAMPLE_DESC{Count: 1},
        Layout: 1, Flags: D3D12_RESOURCE_FLAG_ALLOW_UNORDERED_ACCESS,
    }
    hr = comCall(g_device, 27, uintptr(unsafe.Pointer(&heapProps)), 0, uintptr(unsafe.Pointer(&resDesc)),
        D3D12_RESOURCE_STATE_UNORDERED_ACCESS, 0,
        uintptr(unsafe.Pointer(&IID_ID3D12Resource)), uintptr(unsafe.Pointer(&g_vertexBuffer)))
    if !checkResult(hr, "CreateCommittedResource(VB)") {
        return false
    }
    g_vertexBufferNeedsUAVTransition = true

    // Create UAV for vertex buffer
    debugLog("[DX12] CreateUnorderedAccessView")
    var uavHandleStruct D3D12_CPU_DESCRIPTOR_HANDLE
    comCall(g_uavHeap, 9, uintptr(unsafe.Pointer(&uavHandleStruct)))
    uavDesc := D3D12_UNORDERED_ACCESS_VIEW_DESC{ViewDimension: 1}
    uavDesc.Buffer.NumElements = VertexCount
    uavDesc.Buffer.StructureByteStride = 32
    comCall(g_device, 19, g_vertexBuffer, 0, uintptr(unsafe.Pointer(&uavDesc)), uavHandleStruct.ptr)

    // Setup vertex buffer view
    gpuAddr, _, _ := syscall.SyscallN(
        *(*uintptr)(unsafe.Pointer(*(*uintptr)(unsafe.Pointer(g_vertexBuffer)) + 11*8)), g_vertexBuffer)
    g_vbView.BufferLocation = uint64(gpuAddr)
    g_vbView.SizeInBytes = uint32(vertexBufferSize)
    g_vbView.StrideInBytes = 32

    // Create Root Signatures
    debugLog("[DX12] CreateComputeRootSignature")
    if !createComputeRootSignature() {
        return false
    }
    debugLog("[DX12] CreateGraphicsRootSignature")
    if !createGraphicsRootSignature() {
        return false
    }

    // Compile and create Compute PSO
    debugLog("[DX12] Compile compute shader")
    csBlob, errBlob := compileShader(computeShaderSource, "CSMain", "cs_5_0")
    if csBlob == 0 {
        if errBlob != 0 {
            printBlobError(errBlob)
            comRelease(errBlob)
        }
        return false
    }

    debugLog("[DX12] CreateComputePipelineState")
    csPsoDesc := D3D12_COMPUTE_PIPELINE_STATE_DESC{pRootSignature: g_computeRootSignature}
    csPsoDesc.CS.pShaderBytecode = comCall(csBlob, 3)
    csPsoDesc.CS.BytecodeLength = comCall(csBlob, 4)
    hr = comCall(g_device, 11, uintptr(unsafe.Pointer(&csPsoDesc)),
        uintptr(unsafe.Pointer(&IID_ID3D12PipelineState)), uintptr(unsafe.Pointer(&g_computePSO)))
    comRelease(csBlob)
    if !checkResult(hr, "CreateComputePipelineState") {
        return false
    }

    // Compile and create Graphics PSO
    debugLog("[DX12] Compile graphics shaders")
    vsBlob, errBlobVS := compileShader(graphicsShaderSource, "VSMain", "vs_5_0")
    if vsBlob == 0 {
        if errBlobVS != 0 {
            printBlobError(errBlobVS)
            comRelease(errBlobVS)
        }
        return false
    }
    psBlob, errBlobPS := compileShader(graphicsShaderSource, "PSMain", "ps_5_0")
    if psBlob == 0 {
        if errBlobPS != 0 {
            printBlobError(errBlobPS)
            comRelease(errBlobPS)
        }
        comRelease(vsBlob)
        return false
    }

    inputElementDescs := []D3D12_INPUT_ELEMENT_DESC{
        {SemanticName: syscall.StringBytePtr("POSITION"), Format: DXGI_FORMAT_R32G32B32A32_FLOAT, AlignedByteOffset: 0},
        {SemanticName: syscall.StringBytePtr("COLOR"), Format: DXGI_FORMAT_R32G32B32A32_FLOAT, AlignedByteOffset: 16},
    }

    gfxPsoDesc := D3D12_GRAPHICS_PIPELINE_STATE_DESC{pRootSignature: g_graphicsRootSignature}
    gfxPsoDesc.VS.pShaderBytecode = comCall(vsBlob, 3)
    gfxPsoDesc.VS.BytecodeLength = comCall(vsBlob, 4)
    gfxPsoDesc.PS.pShaderBytecode = comCall(psBlob, 3)
    gfxPsoDesc.PS.BytecodeLength = comCall(psBlob, 4)
    gfxPsoDesc.BlendState.RenderTarget[0].SrcBlend = 2
    gfxPsoDesc.BlendState.RenderTarget[0].DestBlend = 1
    gfxPsoDesc.BlendState.RenderTarget[0].BlendOp = 1
    gfxPsoDesc.BlendState.RenderTarget[0].SrcBlendAlpha = 2
    gfxPsoDesc.BlendState.RenderTarget[0].DestBlendAlpha = 1
    gfxPsoDesc.BlendState.RenderTarget[0].BlendOpAlpha = 1
    gfxPsoDesc.BlendState.RenderTarget[0].LogicOp = 4
    gfxPsoDesc.BlendState.RenderTarget[0].RenderTargetWriteMask = 0x0F
    gfxPsoDesc.SampleMask = 0xFFFFFFFF
    gfxPsoDesc.RasterizerState.FillMode = D3D12_FILL_MODE_SOLID
    gfxPsoDesc.RasterizerState.CullMode = D3D12_CULL_MODE_NONE
    gfxPsoDesc.RasterizerState.DepthClipEnable = 1
    gfxPsoDesc.RasterizerState.AntialiasedLineEnable = 1
    gfxPsoDesc.InputLayout.pInputElementDescs = uintptr(unsafe.Pointer(&inputElementDescs[0]))
    gfxPsoDesc.InputLayout.NumElements = 2
    gfxPsoDesc.PrimitiveTopologyType = D3D12_PRIMITIVE_TOPOLOGY_TYPE_LINE
    gfxPsoDesc.NumRenderTargets = 1
    gfxPsoDesc.RTVFormats[0] = DXGI_FORMAT_R8G8B8A8_UNORM
    gfxPsoDesc.SampleDesc.Count = 1

    debugLog("[DX12] CreateGraphicsPipelineState")
    hr = comCall(g_device, 10, uintptr(unsafe.Pointer(&gfxPsoDesc)),
        uintptr(unsafe.Pointer(&IID_ID3D12PipelineState)), uintptr(unsafe.Pointer(&g_graphicsPSO)))
    comRelease(vsBlob)
    comRelease(psBlob)
    if !checkResult(hr, "CreateGraphicsPipelineState") {
        return false
    }

    // Create Command Lists
    debugLog("[DX12] CreateCommandList(Graphics)")
    hr = comCall(g_device, 12, 0, D3D12_COMMAND_LIST_TYPE_DIRECT, g_commandAllocator, g_graphicsPSO,
        uintptr(unsafe.Pointer(&IID_ID3D12CommandList)), uintptr(unsafe.Pointer(&g_commandList)))
    if !checkResult(hr, "CreateCommandList(Graphics)") {
        return false
    }
    comCall(g_commandList, 9) // Close

    debugLog("[DX12] CreateCommandList(Compute)")
    hr = comCall(g_device, 12, 0, D3D12_COMMAND_LIST_TYPE_DIRECT, g_computeAllocator, g_computePSO,
        uintptr(unsafe.Pointer(&IID_ID3D12CommandList)), uintptr(unsafe.Pointer(&g_computeCommandList)))
    if !checkResult(hr, "CreateCommandList(Compute)") {
        return false
    }
    comCall(g_computeCommandList, 9) // Close

    // Create Fence
    debugLog("[DX12] CreateFence")
    hr = comCall(g_device, 36, 0, 0, uintptr(unsafe.Pointer(&IID_ID3D12Fence)), uintptr(unsafe.Pointer(&g_fence)))
    if !checkResult(hr, "CreateFence") {
        return false
    }
    g_fenceValue = 1
    r, _, _ := procCreateEventExW.Call(0, 0, 0, 0x1F0003)
    g_fenceEvent = syscall.Handle(r)

    debugLog("DirectX 12 initialization complete")
    return true
}

func createComputeRootSignature() bool {
    // Parameter 0: Descriptor table for UAV
    uavRange := D3D12_DESCRIPTOR_RANGE{RangeType: 1, NumDescriptors: 1}
    rootParams := [2]D3D12_ROOT_PARAMETER{}

    rootParams[0].ParameterType = D3D12_ROOT_PARAMETER_TYPE_DESCRIPTOR_TABLE
    rootParams[0].DescriptorTable.NumDescriptorRanges = 1
    rootParams[0].DescriptorTable.pDescriptorRanges = uintptr(unsafe.Pointer(&uavRange))
    rootParams[0].ShaderVisibility = D3D12_SHADER_VISIBILITY_ALL

    // Parameter 1: Root constants (b0)
    param1 := (*D3D12_ROOT_PARAMETER_CONSTANTS)(unsafe.Pointer(&rootParams[1]))
    param1.ParameterType = D3D12_ROOT_PARAMETER_TYPE_32BIT_CONSTANTS
    param1.Constants.Num32BitValues = 24
    param1.Constants.ShaderRegister = 0
    param1.Constants.RegisterSpace = 0
    param1.ShaderVisibility = D3D12_SHADER_VISIBILITY_ALL

    rsDesc := D3D12_ROOT_SIGNATURE_DESC{NumParameters: 2, pParameters: uintptr(unsafe.Pointer(&rootParams[0]))}

    var signature, errorBlob uintptr
    hr, _, _ := procD3D12SerializeRootSignature.Call(uintptr(unsafe.Pointer(&rsDesc)), 1,
        uintptr(unsafe.Pointer(&signature)), uintptr(unsafe.Pointer(&errorBlob)))
    if !checkResult(hr, "SerializeRootSignature(Compute)") {
        if errorBlob != 0 {
            printBlobError(errorBlob)
            comRelease(errorBlob)
        }
        return false
    }

    ptr := comCall(signature, 3)
    size := comCall(signature, 4)
    hr = comCall(g_device, 16, 0, ptr, size,
        uintptr(unsafe.Pointer(&IID_ID3D12RootSignature)), uintptr(unsafe.Pointer(&g_computeRootSignature)))
    comRelease(signature)
    if errorBlob != 0 {
        comRelease(errorBlob)
    }
    return checkResult(hr, "CreateRootSignature(Compute)")
}

func createGraphicsRootSignature() bool {
    // Root parameter: MVP matrix (16 floats)
    rootParam := D3D12_ROOT_PARAMETER_CONSTANTS{
        ParameterType:    D3D12_ROOT_PARAMETER_TYPE_32BIT_CONSTANTS,
        ShaderVisibility: D3D12_SHADER_VISIBILITY_ALL,
    }
    rootParam.Constants.Num32BitValues = 16

    rsDesc := D3D12_ROOT_SIGNATURE_DESC{
        NumParameters: 1, pParameters: uintptr(unsafe.Pointer(&rootParam)),
        Flags: D3D12_ROOT_SIGNATURE_FLAG_ALLOW_INPUT_ASSEMBLER_INPUT_LAYOUT,
    }

    var signature, errorBlob uintptr
    hr, _, _ := procD3D12SerializeRootSignature.Call(uintptr(unsafe.Pointer(&rsDesc)), 1,
        uintptr(unsafe.Pointer(&signature)), uintptr(unsafe.Pointer(&errorBlob)))
    if !checkResult(hr, "SerializeRootSignature(Graphics)") {
        if errorBlob != 0 {
            printBlobError(errorBlob)
            comRelease(errorBlob)
        }
        return false
    }

    ptr := comCall(signature, 3)
    size := comCall(signature, 4)
    hr = comCall(g_device, 16, 0, ptr, size,
        uintptr(unsafe.Pointer(&IID_ID3D12RootSignature)), uintptr(unsafe.Pointer(&g_graphicsRootSignature)))
    comRelease(signature)
    if errorBlob != 0 {
        comRelease(errorBlob)
    }
    return checkResult(hr, "CreateRootSignature(Graphics)")
}

// =============================================================================
// Matrix operations
// =============================================================================
func createPerspectiveMatrix(fovYDegrees, aspect, nearZ, farZ float32) [16]float32 {
    rad := fovYDegrees * (float32(math.Pi) / 180.0) * 0.5
    v := float32(1.0 / math.Tan(float64(rad)))
    u := v / aspect
    w := nearZ - farZ
    var m [16]float32
    m[0] = u
    m[5] = v
    m[10] = (nearZ + farZ) / w
    m[11] = -1.0
    m[14] = (nearZ * farZ * 2.0) / w
    return m
}

func createLookAtMatrix(eyeX, eyeY, eyeZ, atX, atY, atZ, upX, upY, upZ float32) [16]float32 {
    wx, wy, wz := eyeX-atX, eyeY-atY, eyeZ-atZ
    wl := float32(math.Sqrt(float64(wx*wx + wy*wy + wz*wz)))
    wx, wy, wz = wx/wl, wy/wl, wz/wl

    ux := upY*wz - upZ*wy
    uy := upZ*wx - upX*wz
    uz := upX*wy - upY*wx
    ul := float32(math.Sqrt(float64(ux*ux + uy*uy + uz*uz)))
    ux, uy, uz = ux/ul, uy/ul, uz/ul

    vx := wy*uz - wz*uy
    vy := wz*ux - wx*uz
    vz := wx*uy - wy*ux

    var m [16]float32
    m[0], m[1], m[2] = ux, vx, wx
    m[4], m[5], m[6] = uy, vy, wy
    m[8], m[9], m[10] = uz, vz, wz
    m[12] = -(ux*eyeX + uy*eyeY + uz*eyeZ)
    m[13] = -(vx*eyeX + vy*eyeY + vz*eyeZ)
    m[14] = -(wx*eyeX + wy*eyeY + wz*eyeZ)
    m[15] = 1.0
    return m
}

func multiplyMatrix(a, b [16]float32) [16]float32 {
    var r [16]float32
    for i := 0; i < 4; i++ {
        for j := 0; j < 4; j++ {
            for k := 0; k < 4; k++ {
                r[i*4+j] += a[i*4+k] * b[k*4+j]
            }
        }
    }
    return r
}

// =============================================================================
// Render function
// =============================================================================
func render() {
    g_frameCount++
    if !g_firstFrameLogged {
        debugLog("[RENDER] first frame start")
    }

    // ===== COMPUTE PASS =====
    comCall(g_computeAllocator, 8) // Reset
    comCall(g_computeCommandList, 10, g_computeAllocator, g_computePSO)
    comCall(g_computeCommandList, 29, g_computeRootSignature) // SetComputeRootSignature

    // Set descriptor heap
    heaps := [1]uintptr{g_uavHeap}
    comCall(g_computeCommandList, 28, 1, uintptr(unsafe.Pointer(&heaps[0])))

    // Set root descriptor table (UAV)
    var gpuHandle D3D12_GPU_DESCRIPTOR_HANDLE
    comCall(g_uavHeap, 10, uintptr(unsafe.Pointer(&gpuHandle)))
    comCall(g_computeCommandList, 31, 0, uintptr(gpuHandle.ptr)) // SetComputeRootDescriptorTable

    g_f1 = float32(math.Mod(float64(g_f1+rand.Float32()/40.0), 10.0))
    g_f2 = float32(math.Mod(float64(g_f2+rand.Float32()/40.0), 10.0))
    g_f3 = float32(math.Mod(float64(g_f3+rand.Float32()/40.0), 10.0))
    g_f4 = float32(math.Mod(float64(g_f4+rand.Float32()/40.0), 10.0))
    g_p1 += float32(PI2 * 0.5 / 360.0)

    constants := [24]uint32{
        math.Float32bits(g_A1), math.Float32bits(g_f1), math.Float32bits(g_p1), math.Float32bits(g_d1),
        math.Float32bits(g_A2), math.Float32bits(g_f2), math.Float32bits(g_p2), math.Float32bits(g_d2),
        math.Float32bits(g_A3), math.Float32bits(g_f3), math.Float32bits(g_p3), math.Float32bits(g_d3),
        math.Float32bits(g_A4), math.Float32bits(g_f4), math.Float32bits(g_p4), math.Float32bits(g_d4),
        uint32(VertexCount), 0, 0, 0,
        math.Float32bits(float32(Width)), math.Float32bits(float32(Height)), 0, 0,
    }
    comCall(g_computeCommandList, 35, 1, 24, uintptr(unsafe.Pointer(&constants[0])), 0)

    if g_vertexBufferNeedsUAVTransition {
        barrier := D3D12_RESOURCE_BARRIER{
            Type: 0, pResource: g_vertexBuffer,
            StateBefore: D3D12_RESOURCE_STATE_COMMON,
            StateAfter:  D3D12_RESOURCE_STATE_UNORDERED_ACCESS,
        }
        comCall(g_computeCommandList, 26, 1, uintptr(unsafe.Pointer(&barrier)))
        g_vertexBufferNeedsUAVTransition = false
    }

    // Dispatch compute shader
    threadGroups := (VertexCount + 63) / 64
    comCall(g_computeCommandList, 14, uintptr(threadGroups), 1, 1)

    // Barrier: UAV -> Vertex buffer
    barrier := D3D12_RESOURCE_BARRIER{
        Type: 0, pResource: g_vertexBuffer,
        StateBefore: D3D12_RESOURCE_STATE_UNORDERED_ACCESS,
        StateAfter:  D3D12_RESOURCE_STATE_VERTEX_AND_CONSTANT,
    }
    comCall(g_computeCommandList, 26, 1, uintptr(unsafe.Pointer(&barrier)))
    comCall(g_computeCommandList, 9) // Close

    // Execute compute
    cmds := [1]uintptr{g_computeCommandList}
    comCall(g_commandQueue, 10, 1, uintptr(unsafe.Pointer(&cmds[0])))

    // Wait for compute
    comCall(g_commandQueue, 14, g_fence, uintptr(g_fenceValue))
    g_fenceValue++
    completed, _, _ := syscall.SyscallN(*(*uintptr)(unsafe.Pointer(*(*uintptr)(unsafe.Pointer(g_fence)) + 8*8)), g_fence)
    if completed < uintptr(g_fenceValue-1) {
        comCall(g_fence, 9, uintptr(g_fenceValue-1), uintptr(g_fenceEvent))
        procWaitForSingleObject.Call(uintptr(g_fenceEvent), uintptr(INFINITE))
    }

    // ===== GRAPHICS PASS =====
    comCall(g_commandAllocator, 8) // Reset
    comCall(g_commandList, 10, g_commandAllocator, g_graphicsPSO)
    comCall(g_commandList, 30, g_graphicsRootSignature) // SetGraphicsRootSignature

    view := createLookAtMatrix(0, 5.0, 10.0, 0, 0, 0, 0, 1, 0)
    proj := createPerspectiveMatrix(45.0, float32(Width)/float32(Height), 0.1, 200.0)
    mvp := multiplyMatrix(view, proj)
    comCall(g_commandList, 36, 0, 16, uintptr(unsafe.Pointer(&mvp[0])), 0)

    // Set viewport and scissor
    vp := D3D12_VIEWPORT{Width: float32(Width), Height: float32(Height), MaxDepth: 1.0}
    scissor := D3D12_RECT{Right: Width, Bottom: Height}
    comCall(g_commandList, 21, 1, uintptr(unsafe.Pointer(&vp)))
    comCall(g_commandList, 22, 1, uintptr(unsafe.Pointer(&scissor)))

    // Transition render target
    barrier = D3D12_RESOURCE_BARRIER{
        Type: 0, pResource: g_renderTargets[g_frameIndex],
        StateBefore: D3D12_RESOURCE_STATE_PRESENT,
        StateAfter:  D3D12_RESOURCE_STATE_RENDER_TARGET,
    }
    comCall(g_commandList, 26, 1, uintptr(unsafe.Pointer(&barrier)))

    // Get RTV handle and clear
    var rtvHandleStruct D3D12_CPU_DESCRIPTOR_HANDLE
    comCall(g_rtvHeap, 9, uintptr(unsafe.Pointer(&rtvHandleStruct)))
    rtvHandleVal := rtvHandleStruct.ptr + uintptr(g_frameIndex*g_rtvDescriptorSize)

    clearColor := [4]float32{0.02, 0.02, 0.05, 1.0}
    comCall(g_commandList, 48, rtvHandleVal, uintptr(unsafe.Pointer(&clearColor[0])), 0, 0)
    comCall(g_commandList, 46, 1, uintptr(unsafe.Pointer(&rtvHandleVal)), 0, 0)

    // Set primitive topology and vertex buffer
    comCall(g_commandList, 20, D3D_PRIMITIVE_TOPOLOGY_LINESTRIP)
    comCall(g_commandList, 44, 0, 1, uintptr(unsafe.Pointer(&g_vbView)))

    // Draw
    comCall(g_commandList, 12, VertexCount, 1, 0, 0)

    // Transition vertex buffer back to UAV
    barrier = D3D12_RESOURCE_BARRIER{
        Type: 0, pResource: g_vertexBuffer,
        StateBefore: D3D12_RESOURCE_STATE_VERTEX_AND_CONSTANT,
        StateAfter:  D3D12_RESOURCE_STATE_UNORDERED_ACCESS,
    }
    comCall(g_commandList, 26, 1, uintptr(unsafe.Pointer(&barrier)))

    // Transition render target to present
    barrier = D3D12_RESOURCE_BARRIER{
        Type: 0, pResource: g_renderTargets[g_frameIndex],
        StateBefore: D3D12_RESOURCE_STATE_RENDER_TARGET,
        StateAfter:  D3D12_RESOURCE_STATE_PRESENT,
    }
    comCall(g_commandList, 26, 1, uintptr(unsafe.Pointer(&barrier)))
    comCall(g_commandList, 9) // Close

    // Execute graphics
    cmds[0] = g_commandList
    comCall(g_commandQueue, 10, 1, uintptr(unsafe.Pointer(&cmds[0])))

    // Present
    comCall(g_swapChain, 8, 1, 0)

    waitForPreviousFrame()
    if !g_firstFrameLogged {
        debugLog("[RENDER] first frame end")
        g_firstFrameLogged = true
    }
}

func waitForPreviousFrame() {
    val := g_fenceValue
    comCall(g_commandQueue, 14, g_fence, uintptr(val))
    g_fenceValue++
    completed, _, _ := syscall.SyscallN(*(*uintptr)(unsafe.Pointer(*(*uintptr)(unsafe.Pointer(g_fence)) + 8*8)), g_fence)
    if completed < uintptr(val) {
        comCall(g_fence, 9, uintptr(val), uintptr(g_fenceEvent))
        procWaitForSingleObject.Call(uintptr(g_fenceEvent), uintptr(INFINITE))
    }
    g_frameIndex = uint32(comCall(g_swapChain, 36))
}

// =============================================================================
// Shader compilation
// =============================================================================
func compileShader(source, entry, target string) (uintptr, uintptr) {
    src := []byte(source)
    pEntry, _ := syscall.BytePtrFromString(entry)
    pTarget, _ := syscall.BytePtrFromString(target)
    var blob, errBlob uintptr
    flags := uintptr(D3DCOMPILE_DEBUG | D3DCOMPILE_SKIP_OPTIMIZATION | D3DCOMPILE_ENABLE_STRICTNESS)
    hr, _, _ := procD3DCompile.Call(
        uintptr(unsafe.Pointer(&src[0])), uintptr(len(src)), 0, 0, 0,
        uintptr(unsafe.Pointer(pEntry)), uintptr(unsafe.Pointer(pTarget)),
        flags, 0, uintptr(unsafe.Pointer(&blob)), uintptr(unsafe.Pointer(&errBlob)))
    if int32(hr) < 0 {
        debugLog("[SHADER] Compilation failed for %s (hr=0x%X)", entry, hr)
        return 0, errBlob
    }
    return blob, errBlob
}

func printBlobError(blob uintptr) {
    if blob == 0 {
        return
    }
    ptr := comCall(blob, 3)
    size := comCall(blob, 4)
    buf := make([]byte, size)
    for i := uintptr(0); i < size; i++ {
        buf[i] = *(*byte)(unsafe.Pointer(ptr + i))
    }
    debugLog("[SHADER ERROR] %s", string(buf))
}

// =============================================================================
// COM helper functions
// =============================================================================
func comCall(obj uintptr, index int, args ...uintptr) uintptr {
    if obj == 0 {
        return 0
    }
    vtable := *(*uintptr)(unsafe.Pointer(obj))
    method := *(*uintptr)(unsafe.Pointer(vtable + uintptr(index)*8))
    callArgs := make([]uintptr, len(args)+1)
    callArgs[0] = obj
    copy(callArgs[1:], args)
    ret, _, _ := syscall.SyscallN(method, callArgs...)
    return ret
}

func comRelease(obj uintptr) {
    if obj != 0 {
        comCall(obj, 2)
    }
}

// =============================================================================
// Win32 helper functions
// =============================================================================
func getModuleHandle() syscall.Handle {
    h, _, _ := procGetModuleHandleW.Call(0)
    return syscall.Handle(h)
}

func createWindow(className *uint16, title string, instance syscall.Handle, width, height int32) syscall.Handle {
    t, _ := syscall.UTF16PtrFromString(title)
    r, _, _ := procCreateWindowExW.Call(0, uintptr(unsafe.Pointer(className)), uintptr(unsafe.Pointer(t)),
        WS_OVERLAPPEDWINDOW|WS_VISIBLE, CW_USEDEFAULT, CW_USEDEFAULT, uintptr(width), uintptr(height), 0, 0, uintptr(instance), 0)
    return syscall.Handle(r)
}

func loadCursor(instance syscall.Handle, cursorID uint32) syscall.Handle {
    r, _, _ := procLoadCursorW.Call(uintptr(instance), uintptr(cursorID))
    return syscall.Handle(r)
}

func peekMessage(msg *MSG_WIN, hwnd syscall.Handle, min, max, remove uint32) bool {
    r, _, _ := procPeekMessageW.Call(uintptr(unsafe.Pointer(msg)), uintptr(hwnd), uintptr(min), uintptr(max), uintptr(remove))
    return r != 0
}

func translateMessage(msg *MSG_WIN) {
    procTranslateMessage.Call(uintptr(unsafe.Pointer(msg)))
}

func dispatchMessage(msg *MSG_WIN) {
    procDispatchMessageW.Call(uintptr(unsafe.Pointer(msg)))
}