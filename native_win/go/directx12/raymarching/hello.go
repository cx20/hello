package main

import (
    "fmt"
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
    WM_PAINT            = 0x000F

    DXGI_FORMAT_R8G8B8A8_UNORM = 28
    DXGI_FORMAT_R32G32_FLOAT   = 16

    D3D_FEATURE_LEVEL_11_0 = 0xb000

    D3D12_COMMAND_LIST_TYPE_DIRECT = 0
    D3D12_COMMAND_QUEUE_FLAG_NONE  = 0

    D3D12_RESOURCE_STATE_PRESENT       = 0
    D3D12_RESOURCE_STATE_RENDER_TARGET = 4
    D3D12_RESOURCE_STATE_GENERIC_READ  = 0x1 | 0x800

    D3D12_DESCRIPTOR_HEAP_TYPE_RTV  = 2
    D3D12_DESCRIPTOR_HEAP_FLAG_NONE = 0

    D3D12_ROOT_SIGNATURE_FLAG_ALLOW_INPUT_ASSEMBLER_INPUT_LAYOUT = 0x1

    D3D12_FILL_MODE_SOLID = 3
    D3D12_CULL_MODE_NONE  = 1

    D3D12_PRIMITIVE_TOPOLOGY_TYPE_TRIANGLE = 3
    D3D_PRIMITIVE_TOPOLOGY_TRIANGLELIST    = 4

    D3D12_HEAP_TYPE_UPLOAD          = 2
    D3D12_RESOURCE_DIMENSION_BUFFER = 1

    D3D12_ROOT_PARAMETER_TYPE_32BIT_CONSTANTS = 1
    D3D12_SHADER_VISIBILITY_ALL               = 0

    D3DCOMPILE_DEBUG              = 0x1
    D3DCOMPILE_SKIP_OPTIMIZATION  = 0x4
    D3DCOMPILE_ENABLE_STRICTNESS  = 0x800

    INFINITE = 0xFFFFFFFF
)

const (
    FrameCount = 2
    Width      = 800
    Height     = 600
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
    IID_ID3D12InfoQueue        = GUID{0x0742a90b, 0xc387, 0x483f, [8]byte{0xb9, 0x46, 0x30, 0xa7, 0xe4, 0xe6, 0x14, 0x58}}
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
    Size, Style                        uint32
    WndProc                            uintptr
    ClsExtra, WndExtra                 int32
    Instance, Icon, Cursor, Background syscall.Handle
    MenuName, ClassName                *uint16
    IconSm                             syscall.Handle
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

type D3D12_ROOT_PARAMETER struct {
    ParameterType    int32
    _pad             uint32
    Constants        D3D12_ROOT_CONSTANTS
    _pad2            uint32
    ShaderVisibility int32
    _pad3            uint32
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

// =============================================================================
// Global variables
// =============================================================================
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
    g_startTick  uint32
    g_frameCount uint64
)

// =============================================================================
// Raymarching shader source (based on reference HLSL)
// =============================================================================
var shaderSource = `
// Raymarching shader for DirectX 12

cbuffer ConstantBuffer : register(b0)
{
    float iTime;
    float2 iResolution;
    float padding;
};

struct PSInput
{
    float4 position : SV_POSITION;
    float2 uv : TEXCOORD0;
};

PSInput VSMain(float2 position : POSITION)
{
    PSInput result;
    result.position = float4(position, 0.0, 1.0);
    result.uv = position * 0.5 + 0.5;
    return result;
}

// Raymarching constants
static const int MAX_STEPS = 100;
static const float MAX_DIST = 100.0;
static const float SURF_DIST = 0.001;

// Signed Distance Functions
float sdSphere(float3 p, float r)
{
    return length(p) - r;
}

float sdBox(float3 p, float3 b)
{
    float3 q = abs(p) - b;
    return length(max(q, 0.0)) + min(max(q.x, max(q.y, q.z)), 0.0);
}

float sdTorus(float3 p, float2 t)
{
    float2 q = float2(length(p.xz) - t.x, p.y);
    return length(q) - t.y;
}

// Smooth minimum for blending shapes
float smin(float a, float b, float k)
{
    float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
    return lerp(b, a, h) - k * h * (1.0 - h);
}

// Scene distance function
float GetDist(float3 p)
{
    // Animated sphere
    float sphere = sdSphere(p - float3(sin(iTime) * 1.5, 0.5 + sin(iTime * 2.0) * 0.3, 0.0), 0.5);
    
    // Rotating torus
    float angle = iTime * 0.5;
    float3 torusPos = p - float3(0.0, 0.5, 0.0);
    float cosA = cos(angle);
    float sinA = sin(angle);
    float2 rotatedXZ = float2(cosA * torusPos.x - sinA * torusPos.z, sinA * torusPos.x + cosA * torusPos.z);
    torusPos.x = rotatedXZ.x;
    torusPos.z = rotatedXZ.y;
    
    float angle2 = angle * 0.7;
    float cosA2 = cos(angle2);
    float sinA2 = sin(angle2);
    float2 rotatedXY = float2(cosA2 * torusPos.x - sinA2 * torusPos.y, sinA2 * torusPos.x + cosA2 * torusPos.y);
    torusPos.x = rotatedXY.x;
    torusPos.y = rotatedXY.y;
    
    float torus = sdTorus(torusPos, float2(0.8, 0.2));
    
    // Ground plane
    float plane = p.y + 0.5;
    
    // Combine with smooth blending
    float d = smin(sphere, torus, 0.3);
    d = min(d, plane);
    
    return d;
}

// Calculate normal using gradient
float3 GetNormal(float3 p)
{
    float d = GetDist(p);
    float2 e = float2(0.001, 0.0);
    float3 n = d - float3(
        GetDist(p - e.xyy),
        GetDist(p - e.yxy),
        GetDist(p - e.yyx)
    );
    return normalize(n);
}

// Raymarching
float RayMarch(float3 ro, float3 rd)
{
    float dO = 0.0;
    for (int i = 0; i < MAX_STEPS; i++)
    {
        float3 p = ro + rd * dO;
        float dS = GetDist(p);
        dO += dS;
        if (dO > MAX_DIST || dS < SURF_DIST) break;
    }
    return dO;
}

// Soft shadows
float GetShadow(float3 ro, float3 rd, float mint, float maxt, float k)
{
    float res = 1.0;
    float t = mint;
    for (int i = 0; i < 64 && t < maxt; i++)
    {
        float h = GetDist(ro + rd * t);
        if (h < 0.001)
            return 0.0;
        res = min(res, k * h / t);
        t += h;
    }
    return res;
}

// Ambient occlusion
float GetAO(float3 p, float3 n)
{
    float occ = 0.0;
    float sca = 1.0;
    for (int i = 0; i < 5; i++)
    {
        float h = 0.01 + 0.12 * float(i) / 4.0;
        float d = GetDist(p + h * n);
        occ += (h - d) * sca;
        sca *= 0.95;
    }
    return clamp(1.0 - 3.0 * occ, 0.0, 1.0);
}

float4 PSMain(PSInput input) : SV_TARGET
{
    float2 uv = input.uv - 0.5;
    uv.x *= iResolution.x / iResolution.y;
    
    // Camera setup
    float3 ro = float3(0.0, 1.5, -4.0);
    float3 rd = normalize(float3(uv.x, uv.y, 1.0));
    
    // Light position
    float3 lightPos = float3(3.0, 5.0, -2.0);
    
    // Raymarching
    float d = RayMarch(ro, rd);
    
    float3 col = float3(0.0, 0.0, 0.0);
    
    if (d < MAX_DIST)
    {
        float3 p = ro + rd * d;
        float3 n = GetNormal(p);
        float3 l = normalize(lightPos - p);
        float3 v = normalize(ro - p);
        float3 r = reflect(-l, n);
        
        // Material color based on position
        float3 matCol = float3(0.4, 0.6, 0.9);
        if (p.y < -0.49)
        {
            // Checkerboard floor
            float checker = fmod(floor(p.x) + floor(p.z), 2.0);
            matCol = lerp(float3(0.2, 0.2, 0.2), float3(0.8, 0.8, 0.8), checker);
        }
        
        // Lighting
        float diff = max(dot(n, l), 0.0);
        float spec = pow(max(dot(r, v), 0.0), 32.0);
        float ao = GetAO(p, n);
        float shadow = GetShadow(p + n * 0.01, l, 0.01, length(lightPos - p), 16.0);
        
        // Ambient
        float3 ambient = float3(0.1, 0.12, 0.15);
        
        col = matCol * (ambient * ao + diff * shadow) + float3(1.0, 1.0, 1.0) * spec * shadow * 0.5;
        
        // Fog
        col = lerp(col, float3(0.05, 0.05, 0.1), 1.0 - exp(-0.02 * d * d));
    }
    else
    {
        // Background gradient
        col = lerp(float3(0.1, 0.1, 0.15), float3(0.02, 0.02, 0.05), input.uv.y);
    }
    
    // Gamma correction
    col = pow(col, float3(0.4545, 0.4545, 0.4545));
    
    return float4(col, 1.0);
}
`

// =============================================================================
// Debug output function - outputs to both console and DebugView
// =============================================================================
func debugLog(format string, args ...interface{}) {
    msg := fmt.Sprintf(format, args...)
    fmt.Println(msg)
    
    // Output to DebugView using OutputDebugStringA
    msgBytes := append([]byte(msg), '\n', 0)
    procOutputDebugStringA.Call(uintptr(unsafe.Pointer(&msgBytes[0])))
}

func checkResult(hr uintptr, operation string) bool {
    if int32(hr) < 0 {
        debugLog("[ERROR] %s FAILED with HRESULT: 0x%08X", operation, uint32(hr))
        return false
    }
    debugLog("[OK] %s succeeded (HRESULT: 0x%08X)", operation, uint32(hr))
    return true
}

// =============================================================================
// Main entry point
// =============================================================================
func main() {
    runtime.LockOSThread()
    debugLog("==============================================")
    debugLog("[INIT] Starting Raymarching DX12 Debug Demo")
    debugLog("[INIT] Window Size: %dx%d", Width, Height)
    debugLog("==============================================")

    // Enable DirectX debug layer
    debugLog("[DEBUG] Attempting to enable D3D12 Debug Layer...")
    var debugController uintptr
    hr, _, _ := procD3D12GetDebugInterface.Call(
        uintptr(unsafe.Pointer(&IID_ID3D12Debug)),
        uintptr(unsafe.Pointer(&debugController)))
    
    if int32(hr) >= 0 && debugController != 0 {
        debugLog("[DEBUG] D3D12 Debug interface obtained: 0x%X", debugController)
        debugLog("[DEBUG] Calling EnableDebugLayer()...")
        comCall(debugController, 3) // EnableDebugLayer
        debugLog("[DEBUG] Debug Layer ENABLED")
        comRelease(debugController)
    } else {
        debugLog("[DEBUG] Failed to get debug interface (HRESULT: 0x%08X)", uint32(hr))
        debugLog("[DEBUG] Continuing without debug layer...")
    }

    instance := getModuleHandle()
    debugLog("[INIT] Module handle: 0x%X", instance)

    if !initWindow(instance) {
        debugLog("[FATAL] Window initialization failed")
        return
    }

    if !initDirectX() {
        debugLog("[FATAL] DirectX 12 initialization failed")
        return
    }
    
    debugLog("==============================================")
    debugLog("[INIT] Initialization complete, entering main loop")
    debugLog("==============================================")

    // Store start time for animation
    tick, _, _ := procGetTickCount.Call()
    g_startTick = uint32(tick)

    // Main message loop
    msg := MSG_WIN{}
    for msg.Message != WM_QUIT {
        if peekMessage(&msg, 0, 0, 0, PM_REMOVE) {
            translateMessage(&msg)
            dispatchMessage(&msg)
        } else {
            render()
        }
    }

    // Cleanup
    debugLog("[CLEANUP] Waiting for GPU...")
    waitForPreviousFrame()
    procCloseHandle.Call(uintptr(g_fenceEvent))
    debugLog("[CLEANUP] Application exit")
}

// =============================================================================
// Window initialization
// =============================================================================
func initWindow(instance syscall.Handle) bool {
    debugLog("[WINDOW] Creating window class...")
    className := syscall.StringToUTF16Ptr("RaymarchingDX12DebugClass")

    wcex := WNDCLASSEXW{
        Size:       uint32(unsafe.Sizeof(WNDCLASSEXW{})),
        Style:      0x20, // CS_OWNDC
        WndProc:    syscall.NewCallback(wndProc),
        Instance:   instance,
        Cursor:     loadCursor(0, 32512),
        Background: 0,
        ClassName:  className,
    }

    ret, _, _ := procRegisterClassExW.Call(uintptr(unsafe.Pointer(&wcex)))
    if ret == 0 {
        debugLog("[WINDOW] RegisterClassExW FAILED")
        return false
    }
    debugLog("[WINDOW] Window class registered")

    g_hwnd = createWindow(className, "Raymarching - DirectX 12 DEBUG (Go)", instance, Width, Height)
    if g_hwnd == 0 {
        debugLog("[WINDOW] CreateWindowExW FAILED")
        return false
    }
    debugLog("[WINDOW] Window created: HWND=0x%X", g_hwnd)

    procShowWindow.Call(uintptr(g_hwnd), 1)
    debugLog("[WINDOW] Window shown")
    return true
}

func wndProc(hwnd syscall.Handle, msg uint32, wParam, lParam uintptr) uintptr {
    switch msg {
    case WM_DESTROY:
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
    debugLog("[DX12] ============ Starting DirectX 12 Init ============")
    
    // Create DXGI Factory with debug flag
    var factory4 uintptr
    debugLog("[DX12] Creating DXGI Factory (with debug flag)...")
    hr, _, _ := procCreateDXGIFactory2.Call(
        1, // DXGI_CREATE_FACTORY_DEBUG
        uintptr(unsafe.Pointer(&IID_IDXGIFactory4)),
        uintptr(unsafe.Pointer(&factory4)))
    if !checkResult(hr, "CreateDXGIFactory2") {
        return false
    }
    debugLog("[DX12] Factory4: 0x%X", factory4)
    defer comRelease(factory4)

    // Create D3D12 Device
    debugLog("[DX12] Creating D3D12 Device (Feature Level 11_0)...")
    hr, _, _ = procD3D12CreateDevice.Call(
        0, // Default adapter
        D3D_FEATURE_LEVEL_11_0,
        uintptr(unsafe.Pointer(&IID_ID3D12Device)),
        uintptr(unsafe.Pointer(&g_device)))
    if !checkResult(hr, "D3D12CreateDevice") {
        return false
    }
    debugLog("[DX12] Device: 0x%X", g_device)

    // Create Command Queue
    debugLog("[DX12] Creating Command Queue...")
    qDesc := D3D12_COMMAND_QUEUE_DESC{
        Type:  D3D12_COMMAND_LIST_TYPE_DIRECT,
        Flags: D3D12_COMMAND_QUEUE_FLAG_NONE,
    }
    hr = comCall(g_device, 8,
        uintptr(unsafe.Pointer(&qDesc)),
        uintptr(unsafe.Pointer(&IID_ID3D12CommandQueue)),
        uintptr(unsafe.Pointer(&g_commandQueue)))
    if !checkResult(hr, "CreateCommandQueue") {
        return false
    }
    debugLog("[DX12] CommandQueue: 0x%X", g_commandQueue)

    // Create Swap Chain
    debugLog("[DX12] Creating Swap Chain...")
    scDesc := DXGI_SWAP_CHAIN_DESC1{
        Width:       Width,
        Height:      Height,
        Format:      DXGI_FORMAT_R8G8B8A8_UNORM,
        Stereo:      0,
        SampleDesc:  DXGI_SAMPLE_DESC{Count: 1, Quality: 0},
        BufferUsage: 0x20, // DXGI_USAGE_RENDER_TARGET_OUTPUT
        BufferCount: FrameCount,
        Scaling:     0,
        SwapEffect:  4, // DXGI_SWAP_EFFECT_FLIP_DISCARD
        AlphaMode:   0,
        Flags:       0,
    }
    debugLog("[DX12] SwapChain Desc: %dx%d, Format=%d, BufferCount=%d", 
        scDesc.Width, scDesc.Height, scDesc.Format, scDesc.BufferCount)

    var tempSwapChain uintptr
    hr = comCall(factory4, 15, g_commandQueue, uintptr(g_hwnd),
        uintptr(unsafe.Pointer(&scDesc)), 0, 0,
        uintptr(unsafe.Pointer(&tempSwapChain)))
    if !checkResult(hr, "CreateSwapChainForHwnd") {
        return false
    }
    debugLog("[DX12] TempSwapChain: 0x%X", tempSwapChain)

    hr = comCall(tempSwapChain, 0,
        uintptr(unsafe.Pointer(&IID_IDXGISwapChain3)),
        uintptr(unsafe.Pointer(&g_swapChain)))
    comRelease(tempSwapChain)
    if !checkResult(hr, "QueryInterface(IDXGISwapChain3)") {
        return false
    }
    debugLog("[DX12] SwapChain3: 0x%X", g_swapChain)

    g_frameIndex = uint32(comCall(g_swapChain, 36)) // GetCurrentBackBufferIndex
    debugLog("[DX12] Initial frame index: %d", g_frameIndex)

    // Create Descriptor Heap for RTVs
    debugLog("[DX12] Creating RTV Descriptor Heap...")
    rtvHeapDesc := D3D12_DESCRIPTOR_HEAP_DESC{
        Type:           D3D12_DESCRIPTOR_HEAP_TYPE_RTV,
        NumDescriptors: FrameCount,
        Flags:          D3D12_DESCRIPTOR_HEAP_FLAG_NONE,
    }
    hr = comCall(g_device, 14,
        uintptr(unsafe.Pointer(&rtvHeapDesc)),
        uintptr(unsafe.Pointer(&IID_ID3D12DescriptorHeap)),
        uintptr(unsafe.Pointer(&g_descriptorHeap)))
    if !checkResult(hr, "CreateDescriptorHeap (RTV)") {
        return false
    }
    debugLog("[DX12] DescriptorHeap: 0x%X", g_descriptorHeap)

    g_rtvDescriptorSize = uint32(comCall(g_device, 15, D3D12_DESCRIPTOR_HEAP_TYPE_RTV))
    debugLog("[DX12] RTV Descriptor Size: %d bytes", g_rtvDescriptorSize)

    // Create Render Target Views
    debugLog("[DX12] Creating RTVs...")
    var rtvHandleStruct D3D12_CPU_DESCRIPTOR_HANDLE
    comCall(g_descriptorHeap, 9, uintptr(unsafe.Pointer(&rtvHandleStruct)))
    rtvHandleVal := rtvHandleStruct.ptr
    debugLog("[DX12] RTV Handle Start: 0x%X", rtvHandleVal)

    for i := 0; i < FrameCount; i++ {
        hr = comCall(g_swapChain, 9, uintptr(i),
            uintptr(unsafe.Pointer(&IID_ID3D12Resource)),
            uintptr(unsafe.Pointer(&g_renderTargets[i])))
        if !checkResult(hr, fmt.Sprintf("GetBuffer(%d)", i)) {
            return false
        }
        debugLog("[DX12] RenderTarget[%d]: 0x%X", i, g_renderTargets[i])
        comCall(g_device, 20, g_renderTargets[i], 0, rtvHandleVal)
        rtvHandleVal += uintptr(g_rtvDescriptorSize)
    }

    // Create Command Allocator
    debugLog("[DX12] Creating Command Allocator...")
    hr = comCall(g_device, 9, D3D12_COMMAND_LIST_TYPE_DIRECT,
        uintptr(unsafe.Pointer(&IID_ID3D12CommandAllocator)),
        uintptr(unsafe.Pointer(&g_commandAllocator)))
    if !checkResult(hr, "CreateCommandAllocator") {
        return false
    }
    debugLog("[DX12] CommandAllocator: 0x%X", g_commandAllocator)

    // Create Root Signature
    debugLog("[DX12] Creating Root Signature...")
    rootParam := D3D12_ROOT_PARAMETER{
        ParameterType:    D3D12_ROOT_PARAMETER_TYPE_32BIT_CONSTANTS,
        ShaderVisibility: D3D12_SHADER_VISIBILITY_ALL,
    }
    rootParam.Constants.ShaderRegister = 0
    rootParam.Constants.RegisterSpace = 0
    rootParam.Constants.Num32BitValues = 4 // iTime, iResolution.x, iResolution.y, padding
    debugLog("[DX12] Root Parameter: Type=%d, Num32BitValues=%d", 
        rootParam.ParameterType, rootParam.Constants.Num32BitValues)

    rsDesc := D3D12_ROOT_SIGNATURE_DESC{
        NumParameters: 1,
        pParameters:   uintptr(unsafe.Pointer(&rootParam)),
        Flags:         D3D12_ROOT_SIGNATURE_FLAG_ALLOW_INPUT_ASSEMBLER_INPUT_LAYOUT,
    }

    var signature, errorBlob uintptr
    hr, _, _ = procD3D12SerializeRootSignature.Call(
        uintptr(unsafe.Pointer(&rsDesc)), 1,
        uintptr(unsafe.Pointer(&signature)),
        uintptr(unsafe.Pointer(&errorBlob)))
    if !checkResult(hr, "D3D12SerializeRootSignature") {
        if errorBlob != 0 {
            printBlobError(errorBlob)
            comRelease(errorBlob)
        }
        return false
    }
    debugLog("[DX12] Signature Blob: 0x%X", signature)

    ptr := comCall(signature, 3)
    size := comCall(signature, 4)
    debugLog("[DX12] Signature: ptr=0x%X, size=%d", ptr, size)
    
    hr = comCall(g_device, 16, 0, ptr, size,
        uintptr(unsafe.Pointer(&IID_ID3D12RootSignature)),
        uintptr(unsafe.Pointer(&g_rootSignature)))
    comRelease(signature)
    if errorBlob != 0 {
        comRelease(errorBlob)
    }
    if !checkResult(hr, "CreateRootSignature") {
        return false
    }
    debugLog("[DX12] RootSignature: 0x%X", g_rootSignature)

    // Compile Shaders with debug flags
    debugLog("[DX12] Compiling Vertex Shader...")
    vsBlob, errBlobVS := compileShader("VSMain", "vs_5_0")
    if vsBlob == 0 {
        debugLog("[ERROR] Vertex Shader compilation FAILED")
        if errBlobVS != 0 {
            printBlobError(errBlobVS)
            comRelease(errBlobVS)
        }
        return false
    }
    debugLog("[DX12] VS Blob: 0x%X, Size: %d", vsBlob, comCall(vsBlob, 4))

    debugLog("[DX12] Compiling Pixel Shader...")
    psBlob, errBlobPS := compileShader("PSMain", "ps_5_0")
    if psBlob == 0 {
        debugLog("[ERROR] Pixel Shader compilation FAILED")
        if errBlobPS != 0 {
            printBlobError(errBlobPS)
            comRelease(errBlobPS)
        }
        comRelease(vsBlob)
        return false
    }
    debugLog("[DX12] PS Blob: 0x%X, Size: %d", psBlob, comCall(psBlob, 4))

    // Create Pipeline State Object
    debugLog("[DX12] Creating Graphics Pipeline State...")
    inputElementDescs := []D3D12_INPUT_ELEMENT_DESC{
        {
            SemanticName:   syscall.StringBytePtr("POSITION"),
            Format:         DXGI_FORMAT_R32G32_FLOAT,
            InputSlotClass: 0,
        },
    }
    debugLog("[DX12] Input Layout: 1 element (POSITION, R32G32_FLOAT)")

    psoDesc := D3D12_GRAPHICS_PIPELINE_STATE_DESC{}
    psoDesc.pRootSignature = g_rootSignature
    psoDesc.VS.pShaderBytecode = comCall(vsBlob, 3)
    psoDesc.VS.BytecodeLength = comCall(vsBlob, 4)
    psoDesc.PS.pShaderBytecode = comCall(psBlob, 3)
    psoDesc.PS.BytecodeLength = comCall(psBlob, 4)

    debugLog("[DX12] PSO: VS ptr=0x%X len=%d", psoDesc.VS.pShaderBytecode, psoDesc.VS.BytecodeLength)
    debugLog("[DX12] PSO: PS ptr=0x%X len=%d", psoDesc.PS.pShaderBytecode, psoDesc.PS.BytecodeLength)

    // Blend state
    psoDesc.BlendState.RenderTarget[0].BlendEnable = 0
    psoDesc.BlendState.RenderTarget[0].LogicOpEnable = 0
    psoDesc.BlendState.RenderTarget[0].SrcBlend = 2  // D3D12_BLEND_ONE
    psoDesc.BlendState.RenderTarget[0].DestBlend = 1 // D3D12_BLEND_ZERO
    psoDesc.BlendState.RenderTarget[0].BlendOp = 1   // D3D12_BLEND_OP_ADD
    psoDesc.BlendState.RenderTarget[0].SrcBlendAlpha = 2
    psoDesc.BlendState.RenderTarget[0].DestBlendAlpha = 1
    psoDesc.BlendState.RenderTarget[0].BlendOpAlpha = 1
    psoDesc.BlendState.RenderTarget[0].LogicOp = 4 // D3D12_LOGIC_OP_NOOP
    psoDesc.BlendState.RenderTarget[0].RenderTargetWriteMask = 0x0F

    psoDesc.SampleMask = 0xFFFFFFFF

    // Rasterizer state
    psoDesc.RasterizerState.FillMode = D3D12_FILL_MODE_SOLID
    psoDesc.RasterizerState.CullMode = D3D12_CULL_MODE_NONE
    psoDesc.RasterizerState.DepthClipEnable = 1
    debugLog("[DX12] PSO: FillMode=SOLID, CullMode=NONE")

    // Input layout
    psoDesc.InputLayout.pInputElementDescs = uintptr(unsafe.Pointer(&inputElementDescs[0]))
    psoDesc.InputLayout.NumElements = 1

    psoDesc.PrimitiveTopologyType = D3D12_PRIMITIVE_TOPOLOGY_TYPE_TRIANGLE
    psoDesc.NumRenderTargets = 1
    psoDesc.RTVFormats[0] = DXGI_FORMAT_R8G8B8A8_UNORM
    psoDesc.SampleDesc.Count = 1
    psoDesc.SampleDesc.Quality = 0
    debugLog("[DX12] PSO: TopologyType=TRIANGLE, RTVFormat=R8G8B8A8_UNORM")

    hr = comCall(g_device, 10,
        uintptr(unsafe.Pointer(&psoDesc)),
        uintptr(unsafe.Pointer(&IID_ID3D12PipelineState)),
        uintptr(unsafe.Pointer(&g_pso)))
    comRelease(vsBlob)
    comRelease(psBlob)
    if !checkResult(hr, "CreateGraphicsPipelineState") {
        return false
    }
    debugLog("[DX12] PSO: 0x%X", g_pso)

    // Create Command List
    debugLog("[DX12] Creating Command List...")
    hr = comCall(g_device, 12, 0, D3D12_COMMAND_LIST_TYPE_DIRECT,
        g_commandAllocator, g_pso,
        uintptr(unsafe.Pointer(&IID_ID3D12CommandList)),
        uintptr(unsafe.Pointer(&g_commandList)))
    if !checkResult(hr, "CreateCommandList") {
        return false
    }
    debugLog("[DX12] CommandList: 0x%X", g_commandList)
    
    hr = comCall(g_commandList, 9) // Close
    debugLog("[DX12] CommandList closed (initial)")

    // Create Vertex Buffer for fullscreen quad
    debugLog("[DX12] Creating Vertex Buffer (fullscreen quad)...")
    vertices := []float32{
        -1.0, -1.0, // Bottom-left
        -1.0, 1.0,  // Top-left
        1.0, -1.0,  // Bottom-right
        1.0, -1.0,  // Bottom-right
        -1.0, 1.0,  // Top-left
        1.0, 1.0,   // Top-right
    }
    vertexBufferSize := uint32(len(vertices) * 4)
    debugLog("[DX12] Vertex data: 6 vertices, %d bytes total", vertexBufferSize)
    debugLog("[DX12] Vertices: [%.1f,%.1f], [%.1f,%.1f], [%.1f,%.1f], [%.1f,%.1f], [%.1f,%.1f], [%.1f,%.1f]",
        vertices[0], vertices[1], vertices[2], vertices[3], vertices[4], vertices[5],
        vertices[6], vertices[7], vertices[8], vertices[9], vertices[10], vertices[11])

    heapProps := D3D12_HEAP_PROPERTIES{
        Type:             D3D12_HEAP_TYPE_UPLOAD,
        CreationNodeMask: 1,
        VisibleNodeMask:  1,
    }
    resDesc := D3D12_RESOURCE_DESC{
        Dimension:        D3D12_RESOURCE_DIMENSION_BUFFER,
        Width:            uint64(vertexBufferSize),
        Height:           1,
        DepthOrArraySize: 1,
        MipLevels:        1,
        Format:           0,
        SampleDesc:       DXGI_SAMPLE_DESC{Count: 1},
        Layout:           1, // D3D12_TEXTURE_LAYOUT_ROW_MAJOR
        Flags:            0,
    }

    hr = comCall(g_device, 27,
        uintptr(unsafe.Pointer(&heapProps)), 0,
        uintptr(unsafe.Pointer(&resDesc)),
        D3D12_RESOURCE_STATE_GENERIC_READ, 0,
        uintptr(unsafe.Pointer(&IID_ID3D12Resource)),
        uintptr(unsafe.Pointer(&g_vertexBuffer)))
    if !checkResult(hr, "CreateCommittedResource (VertexBuffer)") {
        return false
    }
    debugLog("[DX12] VertexBuffer: 0x%X", g_vertexBuffer)

    // Map and copy vertex data
    var pVertexDataStart uintptr
    hr = comCall(g_vertexBuffer, 8, 0, 0, uintptr(unsafe.Pointer(&pVertexDataStart)))
    debugLog("[DX12] Mapped vertex buffer at: 0x%X (hr=0x%X)", pVertexDataStart, hr)
    
    src := unsafe.Pointer(&vertices[0])
    for i := uint32(0); i < vertexBufferSize; i++ {
        *(*byte)(unsafe.Pointer(pVertexDataStart + uintptr(i))) = *(*byte)(unsafe.Pointer(uintptr(src) + uintptr(i)))
    }
    comCall(g_vertexBuffer, 9, 0, 0) // Unmap
    debugLog("[DX12] Vertex data copied and unmapped")

    // Setup vertex buffer view
    gpuAddr, _, _ := syscall.SyscallN(
        *(*uintptr)(unsafe.Pointer(*(*uintptr)(unsafe.Pointer(g_vertexBuffer)) + 11*8)),
        g_vertexBuffer)
    g_vbView.BufferLocation = uint64(gpuAddr)
    g_vbView.SizeInBytes = vertexBufferSize
    g_vbView.StrideInBytes = 8 // 2 floats per vertex
    debugLog("[DX12] VBView: GPU=0x%X, Size=%d, Stride=%d", 
        g_vbView.BufferLocation, g_vbView.SizeInBytes, g_vbView.StrideInBytes)

    // Create Fence
    debugLog("[DX12] Creating Fence...")
    hr = comCall(g_device, 36, 0, 0,
        uintptr(unsafe.Pointer(&IID_ID3D12Fence)),
        uintptr(unsafe.Pointer(&g_fence)))
    if !checkResult(hr, "CreateFence") {
        return false
    }
    debugLog("[DX12] Fence: 0x%X", g_fence)
    g_fenceValue = 1

    r, _, _ := procCreateEventExW.Call(0, 0, 0, 0x1F0003)
    g_fenceEvent = syscall.Handle(r)
    debugLog("[DX12] FenceEvent: 0x%X", g_fenceEvent)

    debugLog("[DX12] ============ DirectX 12 Init Complete ============")
    return true
}

// =============================================================================
// Render function - called every frame
// =============================================================================
func render() {
    g_frameCount++
    
    // Log every 60 frames
    logThisFrame := (g_frameCount % 60) == 1

    if logThisFrame {
        debugLog("[RENDER] ===== Frame %d =====", g_frameCount)
    }

    // Reset command allocator and command list
    hr := comCall(g_commandAllocator, 8) // Reset
    if logThisFrame {
        debugLog("[RENDER] CommandAllocator.Reset() hr=0x%X", hr)
    }
    
    hr = comCall(g_commandList, 10, g_commandAllocator, g_pso) // Reset
    if logThisFrame {
        debugLog("[RENDER] CommandList.Reset() hr=0x%X", hr)
    }

    // Set root signature (vtable index 30 = SetGraphicsRootSignature)
    comCall(g_commandList, 30, g_rootSignature) // SetGraphicsRootSignature
    if logThisFrame {
        debugLog("[RENDER] SetGraphicsRootSignature: 0x%X", g_rootSignature)
    }

    // Calculate elapsed time for animation
    tick, _, _ := procGetTickCount.Call()
    elapsed := float32(uint32(tick)-g_startTick) / 1000.0

    // Set root constants (time and resolution)
    // vtable index 36 = SetGraphicsRoot32BitConstants
    constants := [4]float32{elapsed, float32(Width), float32(Height), 0.0}
    comCall(g_commandList, 36, 0, 4, uintptr(unsafe.Pointer(&constants[0])), 0) // SetGraphicsRoot32BitConstants
    
    if logThisFrame {
        debugLog("[RENDER] Constants: time=%.3f, res=[%.0f, %.0f]", constants[0], constants[1], constants[2])
    }

    // Set viewport
    vp := D3D12_VIEWPORT{
        TopLeftX: 0,
        TopLeftY: 0,
        Width:    float32(Width),
        Height:   float32(Height),
        MinDepth: 0.0,
        MaxDepth: 1.0,
    }
    comCall(g_commandList, 21, 1, uintptr(unsafe.Pointer(&vp))) // RSSetViewports
    if logThisFrame {
        debugLog("[RENDER] Viewport: %.0fx%.0f", vp.Width, vp.Height)
    }

    // Set scissor rect
    scissor := D3D12_RECT{0, 0, Width, Height}
    comCall(g_commandList, 22, 1, uintptr(unsafe.Pointer(&scissor))) // RSSetScissorRects
    if logThisFrame {
        debugLog("[RENDER] Scissor: %dx%d", scissor.Right, scissor.Bottom)
    }

    // Transition render target to render target state
    barrier := D3D12_RESOURCE_BARRIER{
        Type:        0, // D3D12_RESOURCE_BARRIER_TYPE_TRANSITION
        pResource:   g_renderTargets[g_frameIndex],
        StateBefore: D3D12_RESOURCE_STATE_PRESENT,
        StateAfter:  D3D12_RESOURCE_STATE_RENDER_TARGET,
    }
    comCall(g_commandList, 26, 1, uintptr(unsafe.Pointer(&barrier))) // ResourceBarrier
    if logThisFrame {
        debugLog("[RENDER] Barrier: PRESENT -> RENDER_TARGET (RT[%d])", g_frameIndex)
    }

    // Get RTV handle
    var rtvHandleStruct D3D12_CPU_DESCRIPTOR_HANDLE
    comCall(g_descriptorHeap, 9, uintptr(unsafe.Pointer(&rtvHandleStruct)))
    rtvHandleVal := rtvHandleStruct.ptr
    rtvHandleVal += uintptr(g_frameIndex * g_rtvDescriptorSize)
    if logThisFrame {
        debugLog("[RENDER] RTV Handle: 0x%X", rtvHandleVal)
    }

    // Clear render target
    clearColor := [4]float32{0.0, 0.0, 0.0, 1.0}
    comCall(g_commandList, 48, rtvHandleVal, uintptr(unsafe.Pointer(&clearColor[0])), 0, 0)
    if logThisFrame {
        debugLog("[RENDER] ClearRenderTargetView: [%.1f, %.1f, %.1f, %.1f]", 
            clearColor[0], clearColor[1], clearColor[2], clearColor[3])
    }

    // Set render target
    comCall(g_commandList, 46, 1, uintptr(unsafe.Pointer(&rtvHandleVal)), 0, 0)
    if logThisFrame {
        debugLog("[RENDER] OMSetRenderTargets: 1 RT")
    }

    // Set primitive topology
    comCall(g_commandList, 20, D3D_PRIMITIVE_TOPOLOGY_TRIANGLELIST) // IASetPrimitiveTopology
    if logThisFrame {
        debugLog("[RENDER] IASetPrimitiveTopology: TRIANGLELIST")
    }

    // Set vertex buffer
    comCall(g_commandList, 44, 0, 1, uintptr(unsafe.Pointer(&g_vbView))) // IASetVertexBuffers
    if logThisFrame {
        debugLog("[RENDER] IASetVertexBuffers: slot=0, count=1")
    }

    // Draw fullscreen quad (6 vertices = 2 triangles)
    comCall(g_commandList, 12, 6, 1, 0, 0) // DrawInstanced
    if logThisFrame {
        debugLog("[RENDER] DrawInstanced: 6 vertices, 1 instance")
    }

    // Transition render target to present state
    barrier.StateBefore = D3D12_RESOURCE_STATE_RENDER_TARGET
    barrier.StateAfter = D3D12_RESOURCE_STATE_PRESENT
    comCall(g_commandList, 26, 1, uintptr(unsafe.Pointer(&barrier)))
    if logThisFrame {
        debugLog("[RENDER] Barrier: RENDER_TARGET -> PRESENT")
    }

    // Close command list
    hr = comCall(g_commandList, 9) // Close
    if logThisFrame {
        debugLog("[RENDER] CommandList.Close() hr=0x%X", hr)
    }

    // Execute command list
    cmds := [1]uintptr{g_commandList}
    comCall(g_commandQueue, 10, 1, uintptr(unsafe.Pointer(&cmds[0]))) // ExecuteCommandLists
    if logThisFrame {
        debugLog("[RENDER] ExecuteCommandLists: 1 list")
    }

    // Present
    hr = comCall(g_swapChain, 8, 1, 0) // Present
    if logThisFrame {
        debugLog("[RENDER] Present() hr=0x%X", hr)
    }

    waitForPreviousFrame()
    
    if logThisFrame {
        debugLog("[RENDER] Frame %d complete, next frameIndex=%d", g_frameCount, g_frameIndex)
    }
}

// =============================================================================
// Synchronization
// =============================================================================
func waitForPreviousFrame() {
    val := g_fenceValue
    comCall(g_commandQueue, 14, g_fence, uintptr(val)) // Signal
    g_fenceValue++

    completed, _, _ := syscall.SyscallN(
        *(*uintptr)(unsafe.Pointer(*(*uintptr)(unsafe.Pointer(g_fence)) + 8*8)),
        g_fence) // GetCompletedValue

    if completed < uintptr(val) {
        comCall(g_fence, 9, uintptr(val), uintptr(g_fenceEvent)) // SetEventOnCompletion
        procWaitForSingleObject.Call(uintptr(g_fenceEvent), uintptr(INFINITE))
    }

    g_frameIndex = uint32(comCall(g_swapChain, 36)) // GetCurrentBackBufferIndex
}

// =============================================================================
// Shader compilation
// =============================================================================
func compileShader(entry, target string) (uintptr, uintptr) {
    src := []byte(shaderSource)
    pEntry, _ := syscall.BytePtrFromString(entry)
    pTarget, _ := syscall.BytePtrFromString(target)
    var blob, errBlob uintptr
    
    // Use debug flags for shader compilation
    flags := uintptr(D3DCOMPILE_DEBUG | D3DCOMPILE_SKIP_OPTIMIZATION | D3DCOMPILE_ENABLE_STRICTNESS)
    
    debugLog("[SHADER] Compiling '%s' target='%s' flags=0x%X", entry, target, flags)
    debugLog("[SHADER] Source length: %d bytes", len(src))
    
    hr, _, _ := procD3DCompile.Call(
        uintptr(unsafe.Pointer(&src[0])),
        uintptr(len(src)),
        0, 0, 0,
        uintptr(unsafe.Pointer(pEntry)),
        uintptr(unsafe.Pointer(pTarget)),
        flags, 0,
        uintptr(unsafe.Pointer(&blob)),
        uintptr(unsafe.Pointer(&errBlob)))
    
    debugLog("[SHADER] D3DCompile returned hr=0x%X, blob=0x%X, errBlob=0x%X", hr, blob, errBlob)
    
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
    r, _, _ := procCreateWindowExW.Call(
        0,
        uintptr(unsafe.Pointer(className)),
        uintptr(unsafe.Pointer(t)),
        WS_OVERLAPPEDWINDOW|WS_VISIBLE,
        CW_USEDEFAULT, CW_USEDEFAULT,
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
    r, _, _ := procPeekMessageW.Call(
        uintptr(unsafe.Pointer(msg)),
        uintptr(hwnd),
        uintptr(min), uintptr(max), uintptr(remove))
    return r != 0
}

func translateMessage(msg *MSG_WIN) {
    procTranslateMessage.Call(uintptr(unsafe.Pointer(msg)))
}

func dispatchMessage(msg *MSG_WIN) {
    procDispatchMessageW.Call(uintptr(unsafe.Pointer(msg)))
}
