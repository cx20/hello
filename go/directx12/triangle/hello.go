package main

import (
    "fmt"
    "runtime"
    "syscall"
    "unsafe"
)

// Constants
const (
    CW_USEDEFAULT       = 0x80000000
    WS_OVERLAPPEDWINDOW = 0x00CF0000
    WS_VISIBLE          = 0x10000000
    PM_REMOVE           = 0x0001
    WM_QUIT             = 0x0012
    WM_DESTROY          = 0x0002
    WM_PAINT            = 0x000F

    DXGI_FORMAT_R8G8B8A8_UNORM     = 28
    DXGI_FORMAT_R32G32B32_FLOAT    = 6
    DXGI_FORMAT_R32G32B32A32_FLOAT = 2

    D3D_FEATURE_LEVEL_11_0 = 0xb000
    
    D3D12_COMMAND_LIST_TYPE_DIRECT = 0
    D3D12_COMMAND_QUEUE_FLAG_NONE  = 0

    D3D12_RESOURCE_STATE_COMMON        = 0
    D3D12_RESOURCE_STATE_RENDER_TARGET = 4
    D3D12_RESOURCE_STATE_PRESENT       = 0
    D3D12_RESOURCE_STATE_GENERIC_READ  = 0x1 | 0x800

    D3D12_DESCRIPTOR_HEAP_TYPE_RTV  = 2
    D3D12_DESCRIPTOR_HEAP_FLAG_NONE = 0

    D3D12_ROOT_SIGNATURE_FLAG_ALLOW_INPUT_ASSEMBLER_INPUT_LAYOUT = 0x1

    D3D12_FILL_MODE_SOLID = 3
    D3D12_CULL_MODE_BACK  = 3

    D3D12_PRIMITIVE_TOPOLOGY_TYPE_TRIANGLE = 3 
    D3D_PRIMITIVE_TOPOLOGY_TRIANGLELIST    = 4

    D3D12_DEFAULT_DEPTH_BIAS       = 0
    D3D12_DEFAULT_DEPTH_BIAS_CLAMP = 0.0

    D3D12_HEAP_TYPE_UPLOAD          = 2
    D3D12_RESOURCE_DIMENSION_BUFFER = 1

    D3DCOMPILE_ENABLE_STRICTNESS = 0x800

    INFINITE = 0xFFFFFFFF
)

const (
    FrameCount = 2
    Width      = 800
    Height     = 600
)

// DLL & Procs
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
    procOutputDebugStringW  = kernel32.NewProc("OutputDebugStringW")

    procD3D12CreateDevice           = d3d12.NewProc("D3D12CreateDevice")
    procD3D12GetDebugInterface      = d3d12.NewProc("D3D12GetDebugInterface")
    procD3D12SerializeRootSignature = d3d12.NewProc("D3D12SerializeRootSignature")
    procCreateDXGIFactory2          = dxgi.NewProc("CreateDXGIFactory2")
    procD3DCompile                  = d3dcompiler.NewProc("D3DCompile")
)

// GUIDs
var (
    IID_ID3D12Debug            = GUID{0x344488b7, 0x6846, 0x474b, [8]byte{0xb9, 0x89, 0xf0, 0x27, 0x44, 0x82, 0x45, 0xe0}}

    IID_IDXGIFactory4          = GUID{0x1bc6ea02, 0xef36, 0x464f, [8]byte{0xbf, 0x0c, 0x21, 0xca, 0x39, 0xe5, 0x16, 0x8a}}
    IID_IDXGISwapChain3        = GUID{0x94d99bdb, 0xf1f8, 0x4ab0, [8]byte{0xb2, 0x36, 0x7d, 0xa0, 0x17, 0x0e, 0xda, 0xb1}}

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

type GUID struct {
    Data1 uint32
    Data2 uint16
    Data3 uint16
    Data4 [8]byte
}

type D3D12_CPU_DESCRIPTOR_HANDLE struct {
    ptr uintptr
}

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
    Size, Style                         uint32
    WndProc                             uintptr
    ClsExtra, WndExtra                  int32
    Instance, Icon, Cursor, Background  syscall.Handle
    MenuName, ClassName                 *uint16
    IconSm                              syscall.Handle
}
type DXGI_RATIONAL struct {
    Numerator, Denominator uint32
}
type DXGI_SAMPLE_DESC struct {
    Count, Quality uint32
}
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
    _pad1             uint32 // Padding for x64
    pParameters       uintptr
    NumStaticSamplers uint32
    _pad2             uint32 // Padding for x64
    pStaticSamplers   uintptr
    Flags             uint32
    _pad3             uint32 // Alignment
}

type D3D12_GRAPHICS_PIPELINE_STATE_DESC struct {
    pRootSignature        uintptr
    VS, PS, DS, HS, GS    struct{ pShaderBytecode uintptr; BytecodeLength uintptr }
    StreamOutput          struct {
        pSODecl          uintptr
        NumEntries       uint32
        pBufferStrides   uintptr 
        NumStrides       uint32
        RasterizedStream uint32
    }
    BlendState            D3D12_BLEND_DESC
    SampleMask            uint32
    RasterizerState       D3D12_RASTERIZER_DESC
    DepthStencilState     D3D12_DEPTH_STENCIL_DESC
    InputLayout           struct {
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
    CachedPSO             struct{ pCachedBlob uintptr; CachedBlobSizeInBytes uintptr }
    Flags                 int32
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
type D3D12_VIEWPORT struct {
    TopLeftX, TopLeftY, Width, Height, MinDepth, MaxDepth float32
}
type D3D12_RECT struct {
    Left, Top, Right, Bottom int32
}
type VERTEX struct {
    Pos   [3]float32
    Color [4]float32
}
type D3D12_HEAP_PROPERTIES struct {
    Type                 int32
    CPUPageProperty      int32
    MemoryPoolPreference int32
    CreationNodeMask     uint32
    VisibleNodeMask      uint32
}
type D3D12_RESOURCE_DESC struct {
    Dimension          int32
    Alignment          uint64
    Width              uint64
    Height             uint32
    DepthOrArraySize   uint16
    MipLevels          uint16
    Format             uint32
    SampleDesc         DXGI_SAMPLE_DESC
    Layout             int32
    Flags              int32
}
type D3D12_RESOURCE_BARRIER struct {
    Type        int32
    Flags       int32
    pResource   uintptr
    Subresource uint32
    StateBefore int32
    StateAfter  int32
}

var (
    g_hwnd              syscall.Handle
    g_device            uintptr
    g_commandQueue      uintptr
    g_swapChain         uintptr
    g_descriptorHeap    uintptr
    g_rtvDescriptorSize uint32
    g_renderTargets     [FrameCount]uintptr
    g_commandAllocator  uintptr
    g_rootSignature     uintptr
    g_pso               uintptr
    g_commandList       uintptr
    g_fence             uintptr
    g_fenceValue        uint64
    g_fenceEvent        syscall.Handle
    g_frameIndex        uint32
    g_vertexBuffer      uintptr
    g_vbView            struct {
        BufferLocation uint64
        SizeInBytes    uint32
        StrideInBytes  uint32
    }
)

var shaderSource = `
struct PSInput {
    float4 position : SV_POSITION;
    float4 color : COLOR;
};
PSInput VSMain(float4 position : POSITION, float4 color : COLOR) {
    PSInput result;
    result.position = position;
    result.color = color;
    return result;
}
float4 PSMain(PSInput input) : SV_TARGET {
    return input.color;
}
`

func logDebug(format string, args ...interface{}) {
    msg := fmt.Sprintf(format, args...)
    fmt.Println(msg)
    p, _ := syscall.UTF16PtrFromString(msg + "\n")
    procOutputDebugStringW.Call(uintptr(unsafe.Pointer(p)))
}

func checkResult(hr uintptr, msg string) bool {
    if int32(hr) < 0 {
        logDebug("ERROR: %s failed. HRESULT: 0x%08X", msg, uint32(hr))
        return false
    }
    return true
}

func main() {
    runtime.LockOSThread()
    logDebug("Starting DX12 Go Application (Final Fix)...")

    var debugController uintptr
    hr, _, _ := procD3D12GetDebugInterface.Call(uintptr(unsafe.Pointer(&IID_ID3D12Debug)), uintptr(unsafe.Pointer(&debugController)))
    if int32(hr) >= 0 && debugController != 0 {
        logDebug("Enabling Debug Layer...")
        comCall(debugController, 3) 
        comRelease(debugController)
    }

    instance := getModuleHandle()
    if !initWindow(instance) {
        logDebug("Failed to init window")
        return
    }

    if !initDirectX() {
        logDebug("Failed to init DirectX 12. Exiting.")
        return
    }
    logDebug("DirectX 12 Initialized Successfully.")

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
    logDebug("Exiting Application.")
}

func initWindow(instance syscall.Handle) bool {
    className := syscall.StringToUTF16Ptr("GoDX12Class")

    wcex := WNDCLASSEXW{
        Size:       uint32(unsafe.Sizeof(WNDCLASSEXW{})),
        Style:      0x20, // CS_OWNDC
        WndProc:    syscall.NewCallback(wndProc),
        Instance:   instance,
        Cursor:     loadCursor(0, 32512),
        Background: 0,
        ClassName:  className,
    }

    if ret, _, _ := procRegisterClassExW.Call(uintptr(unsafe.Pointer(&wcex))); ret == 0 {
        return false
    }

    g_hwnd = createWindow(className, "Hello DirectX 12 (Go)", instance, Width, Height)
    if g_hwnd == 0 {
        return false
    }

    procShowWindow.Call(uintptr(g_hwnd), 1)
    return true
}

func wndProc(hwnd syscall.Handle, msg uint32, wParam, lParam uintptr) uintptr {
    switch msg {
    case WM_DESTROY:
        procPostQuitMessage.Call(0)
        return 0
    case WM_PAINT:
        ret, _, _ := procDefWindowProcW.Call(uintptr(hwnd), uintptr(msg), wParam, lParam)
        return ret
    }
    ret, _, _ := procDefWindowProcW.Call(uintptr(hwnd), uintptr(msg), wParam, lParam)
    return ret
}

func initDirectX() bool {
    var factory4 uintptr
    logDebug("Creating DXGI Factory2...")
    hr, _, _ := procCreateDXGIFactory2.Call(1, uintptr(unsafe.Pointer(&IID_IDXGIFactory4)), uintptr(unsafe.Pointer(&factory4)))
    if !checkResult(hr, "CreateDXGIFactory2") { return false }
    defer comRelease(factory4)

    logDebug("Creating D3D12 Device...")
    hr, _, _ = procD3D12CreateDevice.Call(0, D3D_FEATURE_LEVEL_11_0, uintptr(unsafe.Pointer(&IID_ID3D12Device)), uintptr(unsafe.Pointer(&g_device)))
    if !checkResult(hr, "D3D12CreateDevice") { return false }

    logDebug("Creating Command Queue...")
    qDesc := D3D12_COMMAND_QUEUE_DESC{Type: D3D12_COMMAND_LIST_TYPE_DIRECT, Flags: D3D12_COMMAND_QUEUE_FLAG_NONE}
    hr = comCall(g_device, 8, uintptr(unsafe.Pointer(&qDesc)), uintptr(unsafe.Pointer(&IID_ID3D12CommandQueue)), uintptr(unsafe.Pointer(&g_commandQueue)))
    if !checkResult(hr, "CreateCommandQueue") { return false }

    logDebug("Creating Swap Chain (ForHwnd)...")
    scDesc := DXGI_SWAP_CHAIN_DESC1{
        Width:       Width,
        Height:      Height,
        Format:      DXGI_FORMAT_R8G8B8A8_UNORM,
        Stereo:      0,
        SampleDesc:  DXGI_SAMPLE_DESC{Count: 1, Quality: 0},
        BufferUsage: 0x20, // DXGI_USAGE_RENDER_TARGET_OUTPUT
        BufferCount: FrameCount,
        Scaling:     0, // DXGI_SCALING_STRETCH
        SwapEffect:  4, // DXGI_SWAP_EFFECT_FLIP_DISCARD
        AlphaMode:   0, // DXGI_ALPHA_MODE_UNSPECIFIED
        Flags:       0,
    }

    var tempSwapChain uintptr
    hr = comCall(factory4, 15, g_commandQueue, uintptr(g_hwnd), uintptr(unsafe.Pointer(&scDesc)), 0, 0, uintptr(unsafe.Pointer(&tempSwapChain)))
    if !checkResult(hr, "CreateSwapChainForHwnd") { return false }
    logDebug("  SwapChain Created: 0x%X", tempSwapChain)

    hr = comCall(tempSwapChain, 0, uintptr(unsafe.Pointer(&IID_IDXGISwapChain3)), uintptr(unsafe.Pointer(&g_swapChain)))
    comRelease(tempSwapChain)
    if !checkResult(hr, "QueryInterface(IDXGISwapChain3)") { return false }

    g_frameIndex = uint32(comCall(g_swapChain, 36))

    logDebug("Creating Descriptor Heap...")
    rtvHeapDesc := D3D12_DESCRIPTOR_HEAP_DESC{Type: D3D12_DESCRIPTOR_HEAP_TYPE_RTV, NumDescriptors: FrameCount, Flags: D3D12_DESCRIPTOR_HEAP_FLAG_NONE}
    hr = comCall(g_device, 14, uintptr(unsafe.Pointer(&rtvHeapDesc)), uintptr(unsafe.Pointer(&IID_ID3D12DescriptorHeap)), uintptr(unsafe.Pointer(&g_descriptorHeap)))
    if !checkResult(hr, "CreateDescriptorHeap") { return false }

    g_rtvDescriptorSize = uint32(comCall(g_device, 15, D3D12_DESCRIPTOR_HEAP_TYPE_RTV))

    logDebug("Creating RTVs...")
    
    var rtvHandleStruct D3D12_CPU_DESCRIPTOR_HANDLE
    comCall(g_descriptorHeap, 9, uintptr(unsafe.Pointer(&rtvHandleStruct)))
    rtvHandleVal := rtvHandleStruct.ptr

    for i := 0; i < FrameCount; i++ {
        hr = comCall(g_swapChain, 9, uintptr(i), uintptr(unsafe.Pointer(&IID_ID3D12Resource)), uintptr(unsafe.Pointer(&g_renderTargets[i])))
        if !checkResult(hr, fmt.Sprintf("GetBuffer(%d)", i)) { return false }
        comCall(g_device, 20, g_renderTargets[i], 0, rtvHandleVal)
        rtvHandleVal += uintptr(g_rtvDescriptorSize)
    }

    logDebug("Creating Command Allocator...")
    hr = comCall(g_device, 9, D3D12_COMMAND_LIST_TYPE_DIRECT, uintptr(unsafe.Pointer(&IID_ID3D12CommandAllocator)), uintptr(unsafe.Pointer(&g_commandAllocator)))
    if !checkResult(hr, "CreateCommandAllocator") { return false }

    logDebug("Creating Root Signature...")
    rsDesc := D3D12_ROOT_SIGNATURE_DESC{
        Flags: D3D12_ROOT_SIGNATURE_FLAG_ALLOW_INPUT_ASSEMBLER_INPUT_LAYOUT,
    }
    var signature, errorBlob uintptr
    hr, _, _ = procD3D12SerializeRootSignature.Call(uintptr(unsafe.Pointer(&rsDesc)), 1, uintptr(unsafe.Pointer(&signature)), uintptr(unsafe.Pointer(&errorBlob)))
    if !checkResult(hr, "D3D12SerializeRootSignature") {
        if errorBlob != 0 {
            printBlobError(errorBlob)
            comRelease(errorBlob)
        }
        return false
    }
    
    ptr := comCall(signature, 3)
    size := comCall(signature, 4)
    hr = comCall(g_device, 16, 0, ptr, size, uintptr(unsafe.Pointer(&IID_ID3D12RootSignature)), uintptr(unsafe.Pointer(&g_rootSignature)))
    comRelease(signature)
    if errorBlob != 0 { comRelease(errorBlob) }
    if !checkResult(hr, "CreateRootSignature") { return false }

    logDebug("Compiling Shaders...")
    vsBlob, errBlobVS := compileShader("VSMain", "vs_5_0")
    if vsBlob == 0 {
        logDebug("Vertex Shader Compile Failed")
        if errBlobVS != 0 {
            printBlobError(errBlobVS)
            comRelease(errBlobVS)
        }
        return false
    }
    psBlob, errBlobPS := compileShader("PSMain", "ps_5_0")
    if psBlob == 0 {
        logDebug("Pixel Shader Compile Failed")
        if errBlobPS != 0 {
            printBlobError(errBlobPS)
            comRelease(errBlobPS)
        }
        comRelease(vsBlob)
        return false
    }

    logDebug("Creating PSO...")
    inputElementDescs := []D3D12_INPUT_ELEMENT_DESC{
        {
            SemanticName:   syscall.StringBytePtr("POSITION"),
            Format:         DXGI_FORMAT_R32G32B32_FLOAT,
            InputSlotClass: 0,
        },
        {
            SemanticName:      syscall.StringBytePtr("COLOR"),
            Format:            DXGI_FORMAT_R32G32B32A32_FLOAT,
            AlignedByteOffset: 12,
            InputSlotClass:    0,
        },
    }

    psoDesc := D3D12_GRAPHICS_PIPELINE_STATE_DESC{}
    psoDesc.pRootSignature = g_rootSignature
    psoDesc.VS.pShaderBytecode = comCall(vsBlob, 3)
    psoDesc.VS.BytecodeLength = comCall(vsBlob, 4)
    psoDesc.PS.pShaderBytecode = comCall(psBlob, 3)
    psoDesc.PS.BytecodeLength = comCall(psBlob, 4)
    
    psoDesc.BlendState.RenderTarget[0].BlendEnable = 0
    psoDesc.BlendState.RenderTarget[0].LogicOpEnable = 0
    psoDesc.BlendState.RenderTarget[0].SrcBlend = 2
    psoDesc.BlendState.RenderTarget[0].DestBlend = 1
    psoDesc.BlendState.RenderTarget[0].BlendOp = 1
    psoDesc.BlendState.RenderTarget[0].SrcBlendAlpha = 2
    psoDesc.BlendState.RenderTarget[0].DestBlendAlpha = 1
    psoDesc.BlendState.RenderTarget[0].BlendOpAlpha = 1
    psoDesc.BlendState.RenderTarget[0].LogicOp = 4
    psoDesc.BlendState.RenderTarget[0].RenderTargetWriteMask = 0x0F
    
    psoDesc.SampleMask = 0xFFFFFFFF
    
    psoDesc.RasterizerState.FillMode = D3D12_FILL_MODE_SOLID
    psoDesc.RasterizerState.CullMode = D3D12_CULL_MODE_BACK
    psoDesc.RasterizerState.DepthClipEnable = 1
    
    psoDesc.InputLayout.pInputElementDescs = uintptr(unsafe.Pointer(&inputElementDescs[0]))
    psoDesc.InputLayout.NumElements = 2
    
    // ★修正済み: 正しいトポロジタイプ
    psoDesc.PrimitiveTopologyType = D3D12_PRIMITIVE_TOPOLOGY_TYPE_TRIANGLE
    
    psoDesc.NumRenderTargets = 1
    psoDesc.RTVFormats[0] = DXGI_FORMAT_R8G8B8A8_UNORM
    psoDesc.SampleDesc.Count = 1
    psoDesc.SampleDesc.Quality = 0

    hr = comCall(g_device, 10, uintptr(unsafe.Pointer(&psoDesc)), uintptr(unsafe.Pointer(&IID_ID3D12PipelineState)), uintptr(unsafe.Pointer(&g_pso)))
    comRelease(vsBlob)
    comRelease(psBlob)
    if !checkResult(hr, "CreateGraphicsPipelineState") { return false }

    logDebug("Creating Command List...")
    hr = comCall(g_device, 12, 0, D3D12_COMMAND_LIST_TYPE_DIRECT, g_commandAllocator, g_pso, uintptr(unsafe.Pointer(&IID_ID3D12CommandList)), uintptr(unsafe.Pointer(&g_commandList)))
    if !checkResult(hr, "CreateCommandList") { return false }
    comCall(g_commandList, 9)

    logDebug("Creating Vertex Buffer...")
    aspectRatio := float32(Width) / float32(Height)
    vertices := []VERTEX{
        {Pos: [3]float32{0.0, 0.5 * aspectRatio, 0.0}, Color: [4]float32{1.0, 0.0, 0.0, 1.0}},
        {Pos: [3]float32{0.5, -0.5 * aspectRatio, 0.0}, Color: [4]float32{0.0, 1.0, 0.0, 1.0}},
        {Pos: [3]float32{-0.5, -0.5 * aspectRatio, 0.0}, Color: [4]float32{0.0, 0.0, 1.0, 1.0}},
    }
    vertexBufferSize := uint32(unsafe.Sizeof(vertices[0]) * 3)

    heapProps := D3D12_HEAP_PROPERTIES{Type: D3D12_HEAP_TYPE_UPLOAD, CreationNodeMask: 1, VisibleNodeMask: 1}
    resDesc := D3D12_RESOURCE_DESC{
        Dimension: D3D12_RESOURCE_DIMENSION_BUFFER, Width: uint64(vertexBufferSize), Height: 1, DepthOrArraySize: 1, MipLevels: 1,
        Format: 0, SampleDesc: DXGI_SAMPLE_DESC{Count: 1}, Layout: 1, Flags: 0,
    }

    hr = comCall(g_device, 27, uintptr(unsafe.Pointer(&heapProps)), 0, uintptr(unsafe.Pointer(&resDesc)), D3D12_RESOURCE_STATE_GENERIC_READ, 0, uintptr(unsafe.Pointer(&IID_ID3D12Resource)), uintptr(unsafe.Pointer(&g_vertexBuffer)))
    if !checkResult(hr, "CreateCommittedResource (VertexBuffer)") { return false }

    var pVertexDataStart uintptr
    comCall(g_vertexBuffer, 8, 0, 0, uintptr(unsafe.Pointer(&pVertexDataStart)))
    src := unsafe.Pointer(&vertices[0])
    for i := uint32(0); i < vertexBufferSize; i++ {
        *(*byte)(unsafe.Pointer(pVertexDataStart + uintptr(i))) = *(*byte)(unsafe.Pointer(uintptr(src) + uintptr(i)))
    }
    comCall(g_vertexBuffer, 9, 0, 0)

    gpuAddr, _, _ := syscall.SyscallN(*(*uintptr)(unsafe.Pointer(*(*uintptr)(unsafe.Pointer(g_vertexBuffer)) + 11*8)), g_vertexBuffer)
    g_vbView.BufferLocation = uint64(gpuAddr)
    g_vbView.SizeInBytes = vertexBufferSize
    g_vbView.StrideInBytes = uint32(unsafe.Sizeof(vertices[0]))

    logDebug("Creating Fence...")
    hr = comCall(g_device, 36, 0, 0, uintptr(unsafe.Pointer(&IID_ID3D12Fence)), uintptr(unsafe.Pointer(&g_fence)))
    if !checkResult(hr, "CreateFence") { return false }
    g_fenceValue = 1

    r, _, _ := procCreateEventExW.Call(0, 0, 0, 0x1F0003)
    g_fenceEvent = syscall.Handle(r)

    return true
}

func render() {
    comCall(g_commandAllocator, 8) 
    comCall(g_commandList, 10, g_commandAllocator, g_pso) 

    comCall(g_commandList, 30, g_rootSignature) 

    vp := D3D12_VIEWPORT{Width: float32(Width), Height: float32(Height), MaxDepth: 1.0}
    comCall(g_commandList, 21, 1, uintptr(unsafe.Pointer(&vp))) 

    scissor := D3D12_RECT{0, 0, Width, Height}
    comCall(g_commandList, 22, 1, uintptr(unsafe.Pointer(&scissor))) 

    barrier := D3D12_RESOURCE_BARRIER{
        Type:        0, 
        pResource:   g_renderTargets[g_frameIndex],
        StateBefore: D3D12_RESOURCE_STATE_PRESENT,
        StateAfter:  D3D12_RESOURCE_STATE_RENDER_TARGET,
    }
    comCall(g_commandList, 26, 1, uintptr(unsafe.Pointer(&barrier))) 

    var rtvHandleStruct D3D12_CPU_DESCRIPTOR_HANDLE
    comCall(g_descriptorHeap, 9, uintptr(unsafe.Pointer(&rtvHandleStruct)))
    rtvHandleVal := rtvHandleStruct.ptr
    rtvHandleVal += uintptr(g_frameIndex * g_rtvDescriptorSize)

    clearColor := [4]float32{0.0, 0.2, 0.4, 1.0}
    comCall(g_commandList, 48, rtvHandleVal, uintptr(unsafe.Pointer(&clearColor[0])), 0, 0) 

    comCall(g_commandList, 46, 1, uintptr(unsafe.Pointer(&rtvHandleVal)), 0, 0) 

    comCall(g_commandList, 20, D3D_PRIMITIVE_TOPOLOGY_TRIANGLELIST) 

    comCall(g_commandList, 44, 0, 1, uintptr(unsafe.Pointer(&g_vbView))) 

    comCall(g_commandList, 12, 3, 1, 0, 0) 

    barrier.StateBefore = D3D12_RESOURCE_STATE_RENDER_TARGET
    barrier.StateAfter = D3D12_RESOURCE_STATE_PRESENT
    comCall(g_commandList, 26, 1, uintptr(unsafe.Pointer(&barrier))) 

    comCall(g_commandList, 9) 

    cmds := [1]uintptr{g_commandList}
    comCall(g_commandQueue, 10, 1, uintptr(unsafe.Pointer(&cmds[0]))) 

    comCall(g_swapChain, 8, 1, 0) 

    waitForPreviousFrame()
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

func compileShader(entry, target string) (uintptr, uintptr) {
    src := []byte(shaderSource)
    pEntry, _ := syscall.BytePtrFromString(entry)
    pTarget, _ := syscall.BytePtrFromString(target)
    var blob, errBlob uintptr
    procD3DCompile.Call(uintptr(unsafe.Pointer(&src[0])), uintptr(len(src)), 0, 0, 0, uintptr(unsafe.Pointer(pEntry)), uintptr(unsafe.Pointer(pTarget)), D3DCOMPILE_ENABLE_STRICTNESS, 0, uintptr(unsafe.Pointer(&blob)), uintptr(unsafe.Pointer(&errBlob)))
    return blob, errBlob
}

func printBlobError(blob uintptr) {
    if blob == 0 { return }
    ptr := comCall(blob, 3) 
    size := comCall(blob, 4) 
    buf := make([]byte, size)
    for i := uintptr(0); i < size; i++ {
        buf[i] = *(*byte)(unsafe.Pointer(ptr + i))
    }
    logDebug("Shader Compile Error: %s", string(buf))
}

func comCall(obj uintptr, index int, args ...uintptr) uintptr {
    if obj == 0 { return 0 }
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

func getModuleHandle() syscall.Handle {
    h, _, _ := procGetModuleHandleW.Call(0)
    return syscall.Handle(h)
}

func createWindow(className *uint16, title string, instance syscall.Handle, width, height int32) syscall.Handle {
    t, _ := syscall.UTF16PtrFromString(title)
    r, _, _ := procCreateWindowExW.Call(
        0,
        uintptr(unsafe.Pointer(className)),
        uintptr(unsafe.Pointer(t)),
        WS_OVERLAPPEDWINDOW | WS_VISIBLE,
        CW_USEDEFAULT,
        CW_USEDEFAULT,
        uintptr(width), uintptr(height),
        0, 0, uintptr(instance), 0,
    )
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
