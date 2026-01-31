// F# DirectX 11 Triangle Sample - No external libraries
// Based on the C# sample, using P/Invoke and COM interop

open System
open System.Runtime.InteropServices
open System.Text

// ============================================================================
// Win32 Constants
// ============================================================================
module Win32Constants =
    let WS_OVERLAPPEDWINDOW = 0x00CF0000u
    let WS_VISIBLE          = 0x10000000u
    let CS_OWNDC            = 0x0020u

    let WM_PAINT            = 0x000Fu
    let WM_DESTROY          = 0x0002u
    let WM_QUIT             = 0x0012u
    let PM_REMOVE           = 0x0001u

    let IDC_ARROW           = 32512

// ============================================================================
// DXGI Constants
// ============================================================================
module DXGIConstants =
    let DXGI_FORMAT_R32G32B32_FLOAT     = 6u
    let DXGI_FORMAT_R32G32B32A32_FLOAT  = 2u
    let DXGI_FORMAT_R8G8B8A8_UNORM      = 28u

    let DXGI_USAGE_RENDER_TARGET_OUTPUT = 0x20u
    let DXGI_SCALING_STRETCH            = 0u
    let DXGI_SWAP_EFFECT_FLIP_SEQUENTIAL = 3u

// ============================================================================
// D3D11 Constants
// ============================================================================
module D3D11Constants =
    let D3D_DRIVER_TYPE_HARDWARE    = 1
    let D3D_FEATURE_LEVEL_11_0      = 0xb000u
    let D3D_FEATURE_LEVEL_10_1      = 0xa100u
    let D3D_FEATURE_LEVEL_10_0      = 0xa000u

    let D3D11_SDK_VERSION           = 7u
    let D3D11_CREATE_DEVICE_DEBUG   = 0x2u
    let D3D11_BIND_VERTEX_BUFFER    = 0x1u
    let D3D11_USAGE_DEFAULT         = 0u

    let D3D11_PRIMITIVE_TOPOLOGY_TRIANGLELIST = 4u

    let D3DCOMPILE_ENABLE_STRICTNESS = 1u <<< 11

// ============================================================================
// Win32 Structures
// ============================================================================
[<Struct; StructLayout(LayoutKind.Sequential)>]
type POINT =
    val mutable X: int
    val mutable Y: int

[<Struct; StructLayout(LayoutKind.Sequential)>]
type MSG =
    val mutable hwnd: IntPtr
    val mutable message: uint32
    val mutable wParam: IntPtr
    val mutable lParam: IntPtr
    val mutable time: uint32
    val mutable pt: POINT

[<Struct; StructLayout(LayoutKind.Sequential)>]
type RECT =
    val mutable Left: int
    val mutable Top: int
    val mutable Right: int
    val mutable Bottom: int

[<Struct; StructLayout(LayoutKind.Sequential)>]
type PAINTSTRUCT =
    val mutable hdc: IntPtr
    val mutable fErase: int
    val mutable rcPaint: RECT
    val mutable fRestore: int
    val mutable fIncUpdate: int
    [<MarshalAs(UnmanagedType.ByValArray, SizeConst = 32)>]
    val mutable rgbReserved: byte[]

type WndProcDelegate = delegate of IntPtr * uint32 * IntPtr * IntPtr -> IntPtr

[<Struct; StructLayout(LayoutKind.Sequential, CharSet = CharSet.Auto)>]
type WNDCLASSEX =
    val mutable cbSize: uint32
    val mutable style: uint32
    val mutable lpfnWndProc: WndProcDelegate
    val mutable cbClsExtra: int
    val mutable cbWndExtra: int
    val mutable hInstance: IntPtr
    val mutable hIcon: IntPtr
    val mutable hCursor: IntPtr
    val mutable hbrBackground: IntPtr
    val mutable lpszMenuName: string
    val mutable lpszClassName: string
    val mutable hIconSm: IntPtr

// ============================================================================
// DXGI Structures
// ============================================================================
[<Struct; StructLayout(LayoutKind.Sequential)>]
type DXGI_SAMPLE_DESC =
    val mutable Count: uint32
    val mutable Quality: uint32

[<Struct; StructLayout(LayoutKind.Sequential)>]
type DXGI_SWAP_CHAIN_DESC1 =
    val mutable Width: uint32
    val mutable Height: uint32
    val mutable Format: uint32
    val mutable Stereo: bool
    val mutable SampleDesc: DXGI_SAMPLE_DESC
    val mutable BufferUsage: uint32
    val mutable BufferCount: uint32
    val mutable Scaling: uint32
    val mutable SwapEffect: uint32
    val mutable AlphaMode: uint32
    val mutable Flags: uint32

// ============================================================================
// D3D11 Structures
// ============================================================================
[<Struct; StructLayout(LayoutKind.Sequential, Pack = 4)>]
type D3D11_BUFFER_DESC =
    val mutable ByteWidth: uint32
    val mutable Usage: uint32
    val mutable BindFlags: uint32
    val mutable CPUAccessFlags: uint32
    val mutable MiscFlags: uint32
    val mutable StructureByteStride: uint32

[<Struct; StructLayout(LayoutKind.Sequential)>]
type D3D11_SUBRESOURCE_DATA =
    val mutable pSysMem: IntPtr
    val mutable SysMemPitch: uint32
    val mutable SysMemSlicePitch: uint32

[<Struct; StructLayout(LayoutKind.Sequential)>]
type D3D11_INPUT_ELEMENT_DESC =
    [<MarshalAs(UnmanagedType.LPStr)>]
    val mutable SemanticName: string
    val mutable SemanticIndex: uint32
    val mutable Format: uint32
    val mutable InputSlot: uint32
    val mutable AlignedByteOffset: uint32
    val mutable InputSlotClass: uint32
    val mutable InstanceDataStepRate: uint32

[<Struct; StructLayout(LayoutKind.Sequential)>]
type D3D11_VIEWPORT =
    val mutable TopLeftX: float32
    val mutable TopLeftY: float32
    val mutable Width: float32
    val mutable Height: float32
    val mutable MinDepth: float32
    val mutable MaxDepth: float32

// Vertex structure
[<Struct; StructLayout(LayoutKind.Sequential)>]
type Vertex =
    val mutable X: float32
    val mutable Y: float32
    val mutable Z: float32
    val mutable R: float32
    val mutable G: float32
    val mutable B: float32
    val mutable A: float32

// ============================================================================
// P/Invoke Declarations
// ============================================================================
module NativeMethods =
    [<DllImport("user32.dll", CharSet = CharSet.Auto)>]
    extern bool ShowWindow(IntPtr hWnd, int nCmdShow)

    [<DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)>]
    extern IntPtr LoadCursor(IntPtr hInstance, int lpCursorName)

    [<DllImport("user32.dll", EntryPoint = "RegisterClassEx", CharSet = CharSet.Auto, SetLastError = true)>]
    extern uint16 RegisterClassEx([<In>] WNDCLASSEX& lpwcx)

    [<DllImport("user32.dll", CharSet = CharSet.Auto)>]
    extern IntPtr CreateWindowEx(
        uint32 dwExStyle,
        string lpClassName,
        string lpWindowName,
        uint32 dwStyle,
        int x, int y, int nWidth, int nHeight,
        IntPtr hWndParent,
        IntPtr hMenu,
        IntPtr hInstance,
        IntPtr lpParam)

    [<DllImport("user32.dll", CharSet = CharSet.Auto)>]
    extern bool PeekMessage([<Out>] MSG& lpMsg, IntPtr hWnd, uint32 wMsgFilterMin, uint32 wMsgFilterMax, uint32 wRemoveMsg)

    [<DllImport("user32.dll", CharSet = CharSet.Auto)>]
    extern bool TranslateMessage([<In>] MSG& lpMsg)

    [<DllImport("user32.dll", CharSet = CharSet.Auto)>]
    extern IntPtr DispatchMessage([<In>] MSG& lpMsg)

    [<DllImport("user32.dll", CharSet = CharSet.Auto)>]
    extern unit PostQuitMessage(int nExitCode)

    [<DllImport("user32.dll", CharSet = CharSet.Auto)>]
    extern IntPtr DefWindowProc(IntPtr hWnd, uint32 uMsg, IntPtr wParam, IntPtr lParam)

    [<DllImport("user32.dll", CharSet = CharSet.Auto)>]
    extern IntPtr BeginPaint(IntPtr hWnd, [<Out>] PAINTSTRUCT& lpPaint)

    [<DllImport("user32.dll", CharSet = CharSet.Auto)>]
    extern IntPtr EndPaint(IntPtr hWnd, PAINTSTRUCT& lpPaint)

    [<DllImport("gdi32.dll", CharSet = CharSet.Auto)>]
    extern IntPtr TextOut(IntPtr hdc, int x, int y, string lpString, int nCount)

    // D3D11
    [<DllImport("d3d11.dll")>]
    extern int D3D11CreateDevice(
        IntPtr pAdapter,
        int DriverType,
        IntPtr Software,
        uint32 Flags,
        [<In; MarshalAs(UnmanagedType.LPArray)>] uint32[] pFeatureLevels,
        uint32 FeatureLevels,
        uint32 SDKVersion,
        [<Out>] IntPtr& ppDevice,
        [<Out>] IntPtr& pFeatureLevel,
        [<Out>] IntPtr& ppImmediateContext)

    // DXGI
    [<DllImport("dxgi.dll")>]
    extern int CreateDXGIFactory1(Guid& riid, [<Out>] IntPtr& ppFactory)

    // D3DCompiler
    [<DllImport("d3dcompiler_47.dll", CallingConvention = CallingConvention.Winapi)>]
    extern int D3DCompileFromFile(
        [<MarshalAs(UnmanagedType.LPWStr)>] string pFileName,
        IntPtr pDefines,
        IntPtr pInclude,
        [<MarshalAs(UnmanagedType.LPStr)>] string pEntrypoint,
        [<MarshalAs(UnmanagedType.LPStr)>] string pTarget,
        uint32 Flags1,
        uint32 Flags2,
        [<Out>] IntPtr& ppCode,
        [<Out>] IntPtr& ppErrorMsgs)

// ============================================================================
// COM Delegate Types
// ============================================================================
module DelegateTypes =
    // IUnknown
    type QueryInterfaceDelegate = delegate of IntPtr * byref<Guid> * byref<IntPtr> -> int

    // ID3DBlob
    type GetBufferPointerDelegate = delegate of IntPtr -> IntPtr
    type GetBufferSizeDelegate = delegate of IntPtr -> int

    // IDXGIFactory2
    type CreateSwapChainForHwndDelegate = delegate of IntPtr * IntPtr * IntPtr * byref<DXGI_SWAP_CHAIN_DESC1> * IntPtr * IntPtr * byref<IntPtr> -> int

    // IDXGISwapChain
    type GetBufferDelegate = delegate of IntPtr * uint32 * byref<Guid> * byref<IntPtr> -> int
    type PresentDelegate = delegate of IntPtr * uint32 * uint32 -> int

    // ID3D11Device
    type CreateBufferDelegate = delegate of IntPtr * byref<D3D11_BUFFER_DESC> * byref<D3D11_SUBRESOURCE_DATA> * byref<IntPtr> -> int
    type CreateRenderTargetViewDelegate = delegate of IntPtr * IntPtr * IntPtr * byref<IntPtr> -> int
    type CreateInputLayoutDelegate = delegate of IntPtr * D3D11_INPUT_ELEMENT_DESC[] * uint32 * IntPtr * IntPtr * byref<IntPtr> -> int
    type CreateVertexShaderDelegate = delegate of IntPtr * IntPtr * IntPtr * IntPtr * byref<IntPtr> -> int
    type CreatePixelShaderDelegate = delegate of IntPtr * IntPtr * IntPtr * IntPtr * byref<IntPtr> -> int

    // ID3D11DeviceContext
    type OMSetRenderTargetsDelegate = delegate of IntPtr * uint32 * IntPtr[] * IntPtr -> unit
    type RSSetViewportsDelegate = delegate of IntPtr * uint32 * byref<D3D11_VIEWPORT> -> unit
    type ClearRenderTargetViewDelegate = delegate of IntPtr * IntPtr * float32[] -> unit
    type IASetVertexBuffersDelegate = delegate of IntPtr * uint32 * uint32 * IntPtr[] * uint32[] * uint32[] -> unit
    type IASetInputLayoutDelegate = delegate of IntPtr * IntPtr -> unit
    type IASetPrimitiveTopologyDelegate = delegate of IntPtr * uint32 -> unit
    type VSSetShaderDelegate = delegate of IntPtr * IntPtr * IntPtr[] * uint32 -> unit
    type PSSetShaderDelegate = delegate of IntPtr * IntPtr * IntPtr[] * uint32 -> unit
    type DrawDelegate = delegate of IntPtr * uint32 * uint32 -> unit

// ============================================================================
// GUIDs
// ============================================================================
module Guids =
    let IID_IDXGIFactory1       = Guid("770aae78-f26f-4dba-a829-253c83d1b387")
    let IID_IDXGIFactory2       = Guid("50c83a1c-e072-4c48-87b0-3630fa36a6d0")
    let IID_ID3D11Texture2D     = Guid("6f15aaf2-d208-4e89-9ab4-489535d34f9c")

// ============================================================================
// Helper Functions
// ============================================================================
module Helpers =
    let inline getVTableMethod<'TDelegate when 'TDelegate :> Delegate> (comPtr: IntPtr) (index: int) : 'TDelegate =
        let vTable = Marshal.ReadIntPtr(comPtr)
        let methodPtr = Marshal.ReadIntPtr(vTable, index * IntPtr.Size)
        Marshal.GetDelegateForFunctionPointer<'TDelegate>(methodPtr)

    let getBufferPointer (blob: IntPtr) : IntPtr =
        if blob = IntPtr.Zero then IntPtr.Zero
        else
            let getPtr = getVTableMethod<DelegateTypes.GetBufferPointerDelegate> blob 3
            getPtr.Invoke(blob)

    let getBlobSize (blob: IntPtr) : int =
        if blob = IntPtr.Zero then 0
        else
            let getSize = getVTableMethod<DelegateTypes.GetBufferSizeDelegate> blob 4
            getSize.Invoke(blob)

    let structArrayToByteArray<'T when 'T : struct> (structures: 'T[]) : byte[] =
        let size = Marshal.SizeOf<'T>()
        let arr = Array.zeroCreate<byte> (size * structures.Length)
        let handle = GCHandle.Alloc(structures, GCHandleType.Pinned)
        try
            let ptr = handle.AddrOfPinnedObject()
            Marshal.Copy(ptr, arr, 0, arr.Length)
        finally
            handle.Free()
        arr

// ============================================================================
// Main Application
// ============================================================================
type HelloDX11() =
    let mutable device = IntPtr.Zero
    let mutable context = IntPtr.Zero
    let mutable swapChain = IntPtr.Zero
    let mutable renderTargetView = IntPtr.Zero
    let mutable vertexBuffer = IntPtr.Zero
    let mutable vertexShader = IntPtr.Zero
    let mutable pixelShader = IntPtr.Zero
    let mutable inputLayout = IntPtr.Zero
    let mutable backBuffer = IntPtr.Zero

    let mutable viewport = D3D11_VIEWPORT()
    let vertexCount = 3u

    member private this.CompileShaderFromFile(fileName: string, entryPoint: string, profile: string) : IntPtr =
        printfn "[CompileShaderFromFile] File: %s, Entry: %s, Profile: %s" fileName entryPoint profile
        let mutable shaderBlob = IntPtr.Zero
        let mutable errorBlob = IntPtr.Zero

        let result = NativeMethods.D3DCompileFromFile(
            fileName,
            IntPtr.Zero,
            IntPtr.Zero,
            entryPoint,
            profile,
            D3D11Constants.D3DCOMPILE_ENABLE_STRICTNESS,
            0u,
            &shaderBlob,
            &errorBlob
        )

        if result < 0 then
            if errorBlob <> IntPtr.Zero then
                let errorMessage = Marshal.PtrToStringAnsi(Helpers.getBufferPointer errorBlob)
                printfn "Shader compilation error: %s" errorMessage
                Marshal.Release(errorBlob) |> ignore
            IntPtr.Zero
        else
            printfn "Shader compiled successfully. Blob: %X, Size: %d" (int64 shaderBlob) (Helpers.getBlobSize shaderBlob)
            shaderBlob

    member private this.CreateVertexBuffer(vertices: Vertex[]) : IntPtr =
        printfn "[CreateVertexBuffer] - Start"

        let mutable bufferDesc = D3D11_BUFFER_DESC()
        bufferDesc.ByteWidth <- uint32 (Marshal.SizeOf<Vertex>() * vertices.Length)
        bufferDesc.Usage <- D3D11Constants.D3D11_USAGE_DEFAULT
        bufferDesc.BindFlags <- D3D11Constants.D3D11_BIND_VERTEX_BUFFER
        bufferDesc.CPUAccessFlags <- 0u
        bufferDesc.MiscFlags <- 0u
        bufferDesc.StructureByteStride <- uint32 (Marshal.SizeOf<Vertex>())

        let handle = GCHandle.Alloc(vertices, GCHandleType.Pinned)
        try
            let mutable initData = D3D11_SUBRESOURCE_DATA()
            initData.pSysMem <- handle.AddrOfPinnedObject()
            initData.SysMemPitch <- 0u
            initData.SysMemSlicePitch <- 0u

            let createBuffer = Helpers.getVTableMethod<DelegateTypes.CreateBufferDelegate> device 3
            let mutable buffer = IntPtr.Zero
            let result = createBuffer.Invoke(device, &bufferDesc, &initData, &buffer)

            if result < 0 then
                printfn "Failed to create vertex buffer: %X" result
                IntPtr.Zero
            else
                printfn "Vertex buffer created: %X" (int64 buffer)
                buffer
        finally
            handle.Free()

    member private this.CreateInputLayout(vsBlob: IntPtr) : IntPtr =
        printfn "[CreateInputLayout] - Start"

        let mutable positionElement = D3D11_INPUT_ELEMENT_DESC()
        positionElement.SemanticName <- "POSITION"
        positionElement.SemanticIndex <- 0u
        positionElement.Format <- DXGIConstants.DXGI_FORMAT_R32G32B32_FLOAT
        positionElement.InputSlot <- 0u
        positionElement.AlignedByteOffset <- 0u
        positionElement.InputSlotClass <- 0u
        positionElement.InstanceDataStepRate <- 0u

        let mutable colorElement = D3D11_INPUT_ELEMENT_DESC()
        colorElement.SemanticName <- "COLOR"
        colorElement.SemanticIndex <- 0u
        colorElement.Format <- DXGIConstants.DXGI_FORMAT_R32G32B32A32_FLOAT
        colorElement.InputSlot <- 0u
        colorElement.AlignedByteOffset <- 12u
        colorElement.InputSlotClass <- 0u
        colorElement.InstanceDataStepRate <- 0u

        let inputElements = [| positionElement; colorElement |]

        let shaderBytecode = Helpers.getBufferPointer vsBlob
        let bytecodeLength = Helpers.getBlobSize vsBlob

        let createInputLayout = Helpers.getVTableMethod<DelegateTypes.CreateInputLayoutDelegate> device 11
        let mutable layout = IntPtr.Zero
        let result = createInputLayout.Invoke(device, inputElements, uint32 inputElements.Length, shaderBytecode, IntPtr bytecodeLength, &layout)

        if result < 0 then
            printfn "Failed to create input layout: %X" result
            IntPtr.Zero
        else
            printfn "Input layout created: %X" (int64 layout)
            layout

    member this.Initialize(hwnd: IntPtr) =
        printfn "[Initialize] - Start"

        // Create D3D11 Device
        let featureLevels = [| D3D11Constants.D3D_FEATURE_LEVEL_11_0; D3D11Constants.D3D_FEATURE_LEVEL_10_1; D3D11Constants.D3D_FEATURE_LEVEL_10_0 |]
        let mutable featureLevel = IntPtr.Zero

        let deviceResult = NativeMethods.D3D11CreateDevice(
            IntPtr.Zero,
            D3D11Constants.D3D_DRIVER_TYPE_HARDWARE,
            IntPtr.Zero,
            D3D11Constants.D3D11_CREATE_DEVICE_DEBUG,
            featureLevels,
            uint32 featureLevels.Length,
            D3D11Constants.D3D11_SDK_VERSION,
            &device,
            &featureLevel,
            &context
        )

        if deviceResult < 0 then
            failwithf "Failed to create D3D11 device: %X" deviceResult
        printfn "Device created: %X" (int64 device)
        printfn "Context created: %X" (int64 context)

        // Create DXGI Factory
        let mutable factory = IntPtr.Zero
        let mutable factoryGuid = Guids.IID_IDXGIFactory1
        let factoryResult = NativeMethods.CreateDXGIFactory1(&factoryGuid, &factory)

        if factoryResult < 0 then
            failwithf "Failed to create DXGI Factory: %X" factoryResult
        printfn "Factory created: %X" (int64 factory)

        // Query for IDXGIFactory2
        let queryInterface = Helpers.getVTableMethod<DelegateTypes.QueryInterfaceDelegate> factory 0
        let mutable factory2Guid = Guids.IID_IDXGIFactory2
        let mutable factory2 = IntPtr.Zero
        let qiResult = queryInterface.Invoke(factory, &factory2Guid, &factory2)

        Marshal.Release(factory) |> ignore

        if qiResult < 0 then
            failwithf "Failed to get IDXGIFactory2: %X" qiResult

        factory <- factory2
        printfn "IDXGIFactory2 obtained: %X" (int64 factory)

        // Create Swap Chain
        let mutable sampleDesc = DXGI_SAMPLE_DESC()
        sampleDesc.Count <- 1u
        sampleDesc.Quality <- 0u

        let mutable swapChainDesc = DXGI_SWAP_CHAIN_DESC1()
        swapChainDesc.Width <- 800u
        swapChainDesc.Height <- 600u
        swapChainDesc.Format <- DXGIConstants.DXGI_FORMAT_R8G8B8A8_UNORM
        swapChainDesc.Stereo <- false
        swapChainDesc.SampleDesc <- sampleDesc
        swapChainDesc.BufferUsage <- DXGIConstants.DXGI_USAGE_RENDER_TARGET_OUTPUT
        swapChainDesc.BufferCount <- 2u
        swapChainDesc.Scaling <- DXGIConstants.DXGI_SCALING_STRETCH
        swapChainDesc.SwapEffect <- DXGIConstants.DXGI_SWAP_EFFECT_FLIP_SEQUENTIAL
        swapChainDesc.AlphaMode <- 0u
        swapChainDesc.Flags <- 0u

        let createSwapChainForHwnd = Helpers.getVTableMethod<DelegateTypes.CreateSwapChainForHwndDelegate> factory 15
        let swapChainResult = createSwapChainForHwnd.Invoke(factory, device, hwnd, &swapChainDesc, IntPtr.Zero, IntPtr.Zero, &swapChain)

        Marshal.Release(factory) |> ignore

        if swapChainResult < 0 then
            failwithf "Failed to create swap chain: %X" swapChainResult
        printfn "Swap chain created: %X" (int64 swapChain)

        // Get back buffer
        let getBuffer = Helpers.getVTableMethod<DelegateTypes.GetBufferDelegate> swapChain 9
        let mutable textureGuid = Guids.IID_ID3D11Texture2D
        let bufferResult = getBuffer.Invoke(swapChain, 0u, &textureGuid, &backBuffer)

        if bufferResult < 0 then
            failwithf "Failed to get back buffer: %X" bufferResult
        printfn "Back buffer obtained: %X" (int64 backBuffer)

        // Create Render Target View
        let createRTV = Helpers.getVTableMethod<DelegateTypes.CreateRenderTargetViewDelegate> device 9
        let rtvResult = createRTV.Invoke(device, backBuffer, IntPtr.Zero, &renderTargetView)

        if rtvResult < 0 then
            failwithf "Failed to create render target view: %X" rtvResult
        printfn "Render target view created: %X" (int64 renderTargetView)

        // Create Vertex Buffer
        let mutable v0 = Vertex()
        v0.X <- 0.0f; v0.Y <- 0.5f; v0.Z <- 0.0f
        v0.R <- 1.0f; v0.G <- 0.0f; v0.B <- 0.0f; v0.A <- 1.0f

        let mutable v1 = Vertex()
        v1.X <- 0.5f; v1.Y <- -0.5f; v1.Z <- 0.0f
        v1.R <- 0.0f; v1.G <- 1.0f; v1.B <- 0.0f; v1.A <- 1.0f

        let mutable v2 = Vertex()
        v2.X <- -0.5f; v2.Y <- -0.5f; v2.Z <- 0.0f
        v2.R <- 0.0f; v2.G <- 0.0f; v2.B <- 1.0f; v2.A <- 1.0f

        let vertices = [| v0; v1; v2 |]
        vertexBuffer <- this.CreateVertexBuffer(vertices)

        if vertexBuffer = IntPtr.Zero then
            failwith "Failed to create vertex buffer"

        // Compile and Create Shaders
        let vsBlob = this.CompileShaderFromFile("hello.fx", "VS", "vs_4_0")
        if vsBlob = IntPtr.Zero then
            failwith "Failed to compile vertex shader"

        let shaderBytecode = Helpers.getBufferPointer vsBlob
        let bytecodeLength = Helpers.getBlobSize vsBlob

        let createVS = Helpers.getVTableMethod<DelegateTypes.CreateVertexShaderDelegate> device 12
        let mutable vs = IntPtr.Zero
        let vsResult = createVS.Invoke(device, shaderBytecode, IntPtr bytecodeLength, IntPtr.Zero, &vs)

        if vsResult < 0 then
            failwithf "Failed to create vertex shader: %X" vsResult
        vertexShader <- vs
        printfn "Vertex shader created: %X" (int64 vertexShader)

        // Create Input Layout
        inputLayout <- this.CreateInputLayout(vsBlob)
        Marshal.Release(vsBlob) |> ignore

        if inputLayout = IntPtr.Zero then
            failwith "Failed to create input layout"

        // Compile and Create Pixel Shader
        let psBlob = this.CompileShaderFromFile("hello.fx", "PS", "ps_4_0")
        if psBlob = IntPtr.Zero then
            failwith "Failed to compile pixel shader"

        let psBytecode = Helpers.getBufferPointer psBlob
        let psBytecodeLength = Helpers.getBlobSize psBlob

        let createPS = Helpers.getVTableMethod<DelegateTypes.CreatePixelShaderDelegate> device 15
        let mutable ps = IntPtr.Zero
        let psResult = createPS.Invoke(device, psBytecode, IntPtr psBytecodeLength, IntPtr.Zero, &ps)
        Marshal.Release(psBlob) |> ignore

        if psResult < 0 then
            failwithf "Failed to create pixel shader: %X" psResult
        pixelShader <- ps
        printfn "Pixel shader created: %X" (int64 pixelShader)

        // Setup Viewport
        viewport <- D3D11_VIEWPORT()
        viewport.TopLeftX <- 0.0f
        viewport.TopLeftY <- 0.0f
        viewport.Width <- 800.0f
        viewport.Height <- 600.0f
        viewport.MinDepth <- 0.0f
        viewport.MaxDepth <- 1.0f

        // Set initial state
        let omSetRenderTargets = Helpers.getVTableMethod<DelegateTypes.OMSetRenderTargetsDelegate> context 33
        omSetRenderTargets.Invoke(context, 1u, [| renderTargetView |], IntPtr.Zero)

        let rsSetViewports = Helpers.getVTableMethod<DelegateTypes.RSSetViewportsDelegate> context 44
        rsSetViewports.Invoke(context, 1u, &viewport)

        let iaSetInputLayout = Helpers.getVTableMethod<DelegateTypes.IASetInputLayoutDelegate> context 17
        iaSetInputLayout.Invoke(context, inputLayout)

        let iaSetPrimitiveTopology = Helpers.getVTableMethod<DelegateTypes.IASetPrimitiveTopologyDelegate> context 24
        iaSetPrimitiveTopology.Invoke(context, D3D11Constants.D3D11_PRIMITIVE_TOPOLOGY_TRIANGLELIST)

        let stride = uint32 (Marshal.SizeOf<Vertex>())
        let offset = 0u
        let iaSetVertexBuffers = Helpers.getVTableMethod<DelegateTypes.IASetVertexBuffersDelegate> context 18
        iaSetVertexBuffers.Invoke(context, 0u, 1u, [| vertexBuffer |], [| stride |], [| offset |])

        printfn "[Initialize] - Complete"

    member this.Render() =
        // Set render targets
        let omSetRenderTargets = Helpers.getVTableMethod<DelegateTypes.OMSetRenderTargetsDelegate> context 33
        omSetRenderTargets.Invoke(context, 1u, [| renderTargetView |], IntPtr.Zero)

        // Clear render target
        let clearColor = [| 0.0f; 0.2f; 0.4f; 1.0f |]
        let clearRTV = Helpers.getVTableMethod<DelegateTypes.ClearRenderTargetViewDelegate> context 50
        clearRTV.Invoke(context, renderTargetView, clearColor)

        // Set shaders
        let vsSetShader = Helpers.getVTableMethod<DelegateTypes.VSSetShaderDelegate> context 11
        vsSetShader.Invoke(context, vertexShader, null, 0u)

        let psSetShader = Helpers.getVTableMethod<DelegateTypes.PSSetShaderDelegate> context 9
        psSetShader.Invoke(context, pixelShader, null, 0u)

        // Draw
        let draw = Helpers.getVTableMethod<DelegateTypes.DrawDelegate> context 13
        draw.Invoke(context, vertexCount, 0u)

        // Present
        let present = Helpers.getVTableMethod<DelegateTypes.PresentDelegate> swapChain 8
        present.Invoke(swapChain, 1u, 0u) |> ignore

    member this.Cleanup() =
        printfn "[Cleanup] - Start"

        if inputLayout <> IntPtr.Zero then Marshal.Release(inputLayout) |> ignore
        if pixelShader <> IntPtr.Zero then Marshal.Release(pixelShader) |> ignore
        if vertexShader <> IntPtr.Zero then Marshal.Release(vertexShader) |> ignore
        if vertexBuffer <> IntPtr.Zero then Marshal.Release(vertexBuffer) |> ignore
        if renderTargetView <> IntPtr.Zero then Marshal.Release(renderTargetView) |> ignore
        if backBuffer <> IntPtr.Zero then Marshal.Release(backBuffer) |> ignore
        if swapChain <> IntPtr.Zero then Marshal.Release(swapChain) |> ignore
        if context <> IntPtr.Zero then Marshal.Release(context) |> ignore
        if device <> IntPtr.Zero then Marshal.Release(device) |> ignore

// ============================================================================
// Entry Point
// ============================================================================
module Program =
    let mutable wndProcDelegate: WndProcDelegate = null

    let WndProc (hWnd: IntPtr) (uMsg: uint32) (wParam: IntPtr) (lParam: IntPtr) : IntPtr =
        match uMsg with
        | msg when msg = Win32Constants.WM_PAINT ->
            let mutable ps = PAINTSTRUCT()
            let hdc = NativeMethods.BeginPaint(hWnd, &ps)
            let text = "Hello, DirectX 11 (F#) World!"
            NativeMethods.TextOut(hdc, 0, 0, text, text.Length) |> ignore
            NativeMethods.EndPaint(hWnd, &ps) |> ignore
            IntPtr.Zero
        | msg when msg = Win32Constants.WM_DESTROY ->
            NativeMethods.PostQuitMessage(0)
            IntPtr.Zero
        | _ ->
            NativeMethods.DefWindowProc(hWnd, uMsg, wParam, lParam)

    [<EntryPoint; STAThread>]
    let main argv =
        printfn "=========================================="
        printfn "[Main] - F# DirectX 11 Triangle Demo"
        printfn "=========================================="

        let app = HelloDX11()

        let CLASS_NAME = "MyDX11WindowClass"
        let WINDOW_NAME = "Hello, World!"

        let hInstance = Marshal.GetHINSTANCE(typeof<HelloDX11>.Module)
        printfn "hInstance: %X" (int64 hInstance)

        wndProcDelegate <- WndProcDelegate(WndProc)

        let mutable wndClassEx = WNDCLASSEX()
        wndClassEx.cbSize <- uint32 (Marshal.SizeOf(typeof<WNDCLASSEX>))
        wndClassEx.style <- Win32Constants.CS_OWNDC
        wndClassEx.lpfnWndProc <- wndProcDelegate
        wndClassEx.cbClsExtra <- 0
        wndClassEx.cbWndExtra <- 0
        wndClassEx.hInstance <- hInstance
        wndClassEx.hIcon <- IntPtr.Zero
        wndClassEx.hCursor <- NativeMethods.LoadCursor(IntPtr.Zero, Win32Constants.IDC_ARROW)
        wndClassEx.hbrBackground <- IntPtr.Zero
        wndClassEx.lpszMenuName <- null
        wndClassEx.lpszClassName <- CLASS_NAME
        wndClassEx.hIconSm <- IntPtr.Zero

        let atom = NativeMethods.RegisterClassEx(&wndClassEx)
        if atom = 0us then
            let error = Marshal.GetLastWin32Error()
            printfn "Failed to register window class. Error: %d" error
            1
        else
            printfn "Window class registered. Atom: %d" atom

            let hwnd = NativeMethods.CreateWindowEx(
                0u,
                CLASS_NAME,
                WINDOW_NAME,
                Win32Constants.WS_OVERLAPPEDWINDOW ||| Win32Constants.WS_VISIBLE,
                100, 100,
                800, 600,
                IntPtr.Zero,
                IntPtr.Zero,
                hInstance,
                IntPtr.Zero
            )

            if hwnd = IntPtr.Zero then
                printfn "Failed to create window"
                1
            else
                printfn "Window created: %X" (int64 hwnd)

                try
                    app.Initialize(hwnd)
                    NativeMethods.ShowWindow(hwnd, 1) |> ignore

                    let mutable msg = MSG()
                    let mutable running = true

                    while running do
                        if NativeMethods.PeekMessage(&msg, IntPtr.Zero, 0u, 0u, Win32Constants.PM_REMOVE) then
                            if msg.message = Win32Constants.WM_QUIT then
                                running <- false
                            else
                                NativeMethods.TranslateMessage(&msg) |> ignore
                                NativeMethods.DispatchMessage(&msg) |> ignore
                        else
                            app.Render()

                    int msg.wParam
                finally
                    app.Cleanup()
