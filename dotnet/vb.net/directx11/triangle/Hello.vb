Imports System
Imports System.Text
Imports System.Runtime.InteropServices
Imports System.Collections.Generic

Public Class Hello

#Region "Win32 API Definitions"
    <StructLayout(LayoutKind.Sequential)>
    Public Structure POINT
        Public X As Integer
        Public Y As Integer
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Public Structure MSG
        Public hwnd As IntPtr
        Public message As UInteger
        Public wParam As IntPtr
        Public lParam As IntPtr
        Public time As UInteger
        Public pt As POINT
    End Structure

    Public Delegate Function WndProcDelegate(hWnd As IntPtr, uMsg As UInteger, wParam As IntPtr, lParam As IntPtr) As IntPtr

    <StructLayout(LayoutKind.Sequential, CharSet:=CharSet.Auto)>
    Public Structure WNDCLASSEX
        Public cbSize As UInteger
        Public style As UInteger
        Public lpfnWndProc As WndProcDelegate
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

    <StructLayout(LayoutKind.Sequential)>
    Public Structure RECT
        Public Left As Integer
        Public Top As Integer
        Public Right As Integer
        Public Bottom As Integer
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Public Structure PAINTSTRUCT
        Public hdc As IntPtr
        Public fErase As Integer
        Public rcPaint As RECT
        Public fRestore As Integer
        Public fIncUpdate As Integer
        <MarshalAs(UnmanagedType.ByValArray, SizeConst:=32)>
        Public rgbReserved As Byte()
    End Structure

    Private Const WS_OVERLAPPEDWINDOW As UInteger = &HCF0000UI
    Private Const WS_VISIBLE As UInteger = &H10000000UI
    Private Const WM_DESTROY As UInteger = 2UI
    Private Const WM_PAINT As UInteger = 15UI
    Private Const WM_QUIT As UInteger = 18UI
    Private Const PM_REMOVE As UInteger = 1UI
    Private Const CS_OWNDC As UInteger = 32UI
    Private Const IDC_ARROW As Integer = 32512

    <DllImport("user32.dll", CharSet:=CharSet.Auto)>
    Private Shared Function ShowWindow(hWnd As IntPtr, nCmdShow As Integer) As Boolean
    End Function

    <DllImport("user32.dll", CharSet:=CharSet.Auto, SetLastError:=True)>
    Private Shared Function LoadCursor(hInstance As IntPtr, lpCursorName As Integer) As IntPtr
    End Function

    <DllImport("user32.dll", EntryPoint:="RegisterClassEx", CharSet:=CharSet.Auto, SetLastError:=True)>
    Private Shared Function RegisterClassEx(<[In]()> ByRef lpwcx As WNDCLASSEX) As UShort
    End Function

    <DllImport("user32.dll", CharSet:=CharSet.Auto)>
    Private Shared Function CreateWindowEx(dwExStyle As UInteger, lpClassName As String, lpWindowName As String, dwStyle As UInteger, x As Integer, y As Integer, nWidth As Integer, nHeight As Integer, hWndParent As IntPtr, hMenu As IntPtr, hInstance As IntPtr, lpParam As IntPtr) As IntPtr
    End Function

    <DllImport("user32.dll", CharSet:=CharSet.Auto)>
    Private Shared Function PeekMessage(ByRef lpMsg As MSG, hWnd As IntPtr, wMsgFilterMin As UInteger, wMsgFilterMax As UInteger, wRemoveMsg As UInteger) As Boolean
    End Function

    <DllImport("user32.dll", CharSet:=CharSet.Auto)>
    Private Shared Function TranslateMessage(<[In]()> ByRef lpMsg As MSG) As Boolean
    End Function

    <DllImport("user32.dll", CharSet:=CharSet.Auto)>
    Private Shared Function DispatchMessage(<[In]()> ByRef lpMsg As MSG) As IntPtr
    End Function

    <DllImport("user32.dll", CharSet:=CharSet.Auto)>
    Private Shared Sub PostQuitMessage(nExitCode As Integer)
    End Sub

    <DllImport("user32.dll", CharSet:=CharSet.Auto)>
    Private Shared Function DefWindowProc(hWnd As IntPtr, uMsg As UInteger, wParam As IntPtr, lParam As IntPtr) As IntPtr
    End Function

    <DllImport("user32.dll", CharSet:=CharSet.Auto)>
    Private Shared Function BeginPaint(hWnd As IntPtr, ByRef lpPaint As PAINTSTRUCT) As IntPtr
    End Function

    <DllImport("user32.dll", CharSet:=CharSet.Auto)>
    Private Shared Function EndPaint(hWnd As IntPtr, ByRef lpPaint As PAINTSTRUCT) As IntPtr
    End Function

    <DllImport("gdi32.dll", CharSet:=CharSet.Auto)>
    Private Shared Function TextOut(hdc As IntPtr, x As Integer, y As Integer, lpString As String, nCount As Integer) As IntPtr
    End Function

#End Region

#Region "DirectX Constants & Structs"
    Private Const DXGI_FORMAT_R32G32B32A32_FLOAT As UInteger = 2UI
    Private Const DXGI_FORMAT_R32G32B32_FLOAT As UInteger = 6UI
    Private Const DXGI_FORMAT_R8G8B8A8_UNORM As UInteger = 28UI

    Private Const DXGI_USAGE_RENDER_TARGET_OUTPUT As UInteger = 32UI
    Private Const DXGI_SCALING_STRETCH As UInteger = 0UI
    Private Const DXGI_SWAP_EFFECT_FLIP_SEQUENTIAL As UInteger = 3UI

    Private Const D3D_DRIVER_TYPE_HARDWARE As Integer = 1
    Private Const D3D11_SDK_VERSION As UInteger = 7
    Private Const D3D11_CREATE_DEVICE_DEBUG As UInteger = 2
    Private Const D3D11_BIND_VERTEX_BUFFER As UInteger = 1
    Private Const D3D11_USAGE_DEFAULT As UInteger = 0
    Private Const D3D_PRIMITIVE_TOPOLOGY_TRIANGLELIST As UInteger = 4

    Private Const D3DCOMPILE_DEBUG As UInteger = 1
    Private Const D3DCOMPILE_SKIP_OPTIMIZATION As UInteger = 4
    Private Const D3DCOMPILE_ENABLE_STRICTNESS As UInteger = 2048

    <StructLayout(LayoutKind.Sequential)>
    Private Structure DXGI_RATIONAL
        Public Numerator As UInteger
        Public Denominator As UInteger
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Private Structure DXGI_MODE_DESC
        Public Width As UInteger
        Public Height As UInteger
        Public RefreshRate As DXGI_RATIONAL
        Public Format As UInteger
        Public ScanlineOrdering As UInteger
        Public Scaling As UInteger
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Private Structure DXGI_SAMPLE_DESC
        Public Count As UInteger
        Public Quality As UInteger
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Private Structure DXGI_SWAP_CHAIN_DESC
        Public BufferDesc As DXGI_MODE_DESC
        Public SampleDesc As DXGI_SAMPLE_DESC
        Public BufferUsage As UInteger
        Public BufferCount As UInteger
        Public OutputWindow As IntPtr
        Public Windowed As Boolean
        Public SwapEffect As UInteger
        Public Flags As UInteger
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Private Structure DXGI_SWAP_CHAIN_DESC1
        Public Width As UInteger
        Public Height As UInteger
        Public Format As UInteger
        Public Stereo As Boolean
        Public SampleDesc As DXGI_SAMPLE_DESC
        Public BufferUsage As UInteger
        Public BufferCount As UInteger
        Public Scaling As UInteger
        Public SwapEffect As UInteger
        Public AlphaMode As UInteger
        Public Flags As UInteger
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Private Structure Vertex
        Public X As Single, Y As Single, Z As Single
        Public R As Single, G As Single, B As Single, A As Single
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Private Structure D3D11_BUFFER_DESC
        Public ByteWidth As UInteger
        Public Usage As UInteger
        Public BindFlags As UInteger
        Public CPUAccessFlags As UInteger
        Public MiscFlags As UInteger
        Public StructureByteStride As UInteger
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Private Structure D3D11_SUBRESOURCE_DATA
        Public pSysMem As IntPtr
        Public SysMemPitch As UInteger
        Public SysMemSlicePitch As UInteger
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Private Structure D3D11_INPUT_ELEMENT_DESC
        <MarshalAs(UnmanagedType.LPStr)>
        Public SemanticName As String
        Public SemanticIndex As UInteger
        Public Format As UInteger
        Public InputSlot As UInteger
        Public AlignedByteOffset As UInteger
        Public InputSlotClass As UInteger
        Public InstanceDataStepRate As UInteger
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Private Structure D3D11_VIEWPORT
        Public TopLeftX As Single
        Public TopLeftY As Single
        Public Width As Single
        Public Height As Single
        Public MinDepth As Single
        Public MaxDepth As Single
    End Structure

#End Region

#Region "DirectX Delegates (VTable Maps)"

    ' IUnknown
    <UnmanagedFunctionPointer(CallingConvention.StdCall)>
    Private Delegate Function QueryInterfaceDelegate(thisPtr As IntPtr, ByRef riid As Guid, ByRef ppvObject As IntPtr) As Integer

    ' ID3D11Device
    <UnmanagedFunctionPointer(CallingConvention.StdCall)>
    Private Delegate Function CreateBufferDelegate(device As IntPtr, ByRef pDesc As D3D11_BUFFER_DESC, ByRef pInitialData As D3D11_SUBRESOURCE_DATA, ByRef ppBuffer As IntPtr) As Integer

    <UnmanagedFunctionPointer(CallingConvention.StdCall)>
    Private Delegate Function CreateRenderTargetViewDelegate(device As IntPtr, pResource As IntPtr, pDesc As IntPtr, ByRef ppRTView As IntPtr) As Integer

    <UnmanagedFunctionPointer(CallingConvention.StdCall)>
    Private Delegate Function CreateInputLayoutDelegate(device As IntPtr, <[In]()> pInputElementDescs As D3D11_INPUT_ELEMENT_DESC(), NumElements As UInteger, pShaderBytecodeWithInputSignature As IntPtr, BytecodeLength As IntPtr, ByRef ppInputLayout As IntPtr) As Integer

    <UnmanagedFunctionPointer(CallingConvention.StdCall)>
    Private Delegate Function CreateVertexShaderDelegate(device As IntPtr, pShaderBytecode As IntPtr, BytecodeLength As IntPtr, pClassLinkage As IntPtr, ByRef ppVertexShader As IntPtr) As Integer

    <UnmanagedFunctionPointer(CallingConvention.StdCall)>
    Private Delegate Function CreatePixelShaderDelegate(device As IntPtr, pShaderBytecode As IntPtr, BytecodeLength As IntPtr, pClassLinkage As IntPtr, ByRef ppPixelShader As IntPtr) As Integer

    ' ID3D11DeviceContext
    <UnmanagedFunctionPointer(CallingConvention.StdCall)>
    Private Delegate Sub PSSetShaderDelegate(context As IntPtr, pPixelShader As IntPtr, ppClassInstances As IntPtr(), NumClassInstances As UInteger)

    <UnmanagedFunctionPointer(CallingConvention.StdCall)>
    Private Delegate Sub VSSetShaderDelegate(context As IntPtr, pVertexShader As IntPtr, ppClassInstances As IntPtr(), NumClassInstances As UInteger)

    <UnmanagedFunctionPointer(CallingConvention.StdCall)>
    Private Delegate Sub DrawDelegate(context As IntPtr, VertexCount As UInteger, StartVertexLocation As UInteger)

    <UnmanagedFunctionPointer(CallingConvention.StdCall)>
    Private Delegate Sub IASetInputLayoutDelegate(context As IntPtr, inputLayout As IntPtr)

    <UnmanagedFunctionPointer(CallingConvention.StdCall)>
    Private Delegate Sub IASetVertexBuffersDelegate(context As IntPtr, StartSlot As UInteger, NumBuffers As UInteger, <[In]()> ppVertexBuffers As IntPtr(), <[In]()> pStrides As UInteger(), <[In]()> pOffsets As UInteger())

    <UnmanagedFunctionPointer(CallingConvention.StdCall)>
    Private Delegate Sub IASetPrimitiveTopologyDelegate(context As IntPtr, Topology As UInteger)

    <UnmanagedFunctionPointer(CallingConvention.StdCall)>
    Private Delegate Sub OMSetRenderTargetsDelegate(context As IntPtr, NumViews As UInteger, <[In]()> ppRenderTargetViews As IntPtr(), pDepthStencilView As IntPtr)

    <UnmanagedFunctionPointer(CallingConvention.StdCall)>
    Private Delegate Sub RSSetViewportsDelegate(context As IntPtr, numViewports As UInteger, ByRef viewport As D3D11_VIEWPORT)

    <UnmanagedFunctionPointer(CallingConvention.StdCall)>
    Private Delegate Sub ClearRenderTargetViewDelegate(context As IntPtr, pRenderTargetView As IntPtr, <MarshalAs(UnmanagedType.LPArray, SizeConst:=4)> ColorRGBA As Single())

    ' IDXGIFactory
    <UnmanagedFunctionPointer(CallingConvention.StdCall)>
    Private Delegate Function CreateSwapChainForHwndDelegate(factory As IntPtr, pDevice As IntPtr, hWnd As IntPtr, ByRef pDesc As DXGI_SWAP_CHAIN_DESC1, pFullscreenDesc As IntPtr, pRestrictToOutput As IntPtr, ByRef ppSwapChain As IntPtr) As Integer

    ' IDXGISwapChain
    <UnmanagedFunctionPointer(CallingConvention.StdCall)>
    Private Delegate Function PresentDelegate(pSwapChain As IntPtr, SyncInterval As UInteger, Flags As UInteger) As Integer

    <UnmanagedFunctionPointer(CallingConvention.StdCall)>
    Private Delegate Function GetBufferDelegate(swapChain As IntPtr, Buffer As UInteger, ByRef riid As Guid, ByRef ppSurface As IntPtr) As Integer

    ' ID3DBlob
    <UnmanagedFunctionPointer(CallingConvention.StdCall)>
    Private Delegate Function GetBufferPointerDelegate(pBlob As IntPtr) As IntPtr

    <UnmanagedFunctionPointer(CallingConvention.StdCall)>
    Private Delegate Function GetBufferSizeDelegate(pBlob As IntPtr) As IntPtr

#End Region

#Region "DLL Imports (D3D11/D3DCompiler)"

    <DllImport("d3d11.dll", CallingConvention:=CallingConvention.StdCall)>
    Private Shared Function D3D11CreateDevice(pAdapter As IntPtr, DriverType As Integer, Software As IntPtr, Flags As UInteger, <[In](), MarshalAs(UnmanagedType.LPArray)> pFeatureLevels As UInteger(), FeatureLevels As UInteger, SDKVersion As UInteger, ByRef ppDevice As IntPtr, ByRef pFeatureLevel As IntPtr, ByRef ppImmediateContext As IntPtr) As Integer
    End Function

    <DllImport("dxgi.dll", CallingConvention:=CallingConvention.StdCall)>
    Private Shared Function CreateDXGIFactory1(ByRef riid As Guid, ByRef ppFactory As IntPtr) As Integer
    End Function

    <DllImport("d3dcompiler_47.dll", CallingConvention:=CallingConvention.Winapi)>
    Private Shared Function D3DCompileFromFile(<MarshalAs(UnmanagedType.LPWStr)> pFileName As String, pDefines As IntPtr, pInclude As IntPtr, <MarshalAs(UnmanagedType.LPStr)> pEntrypoint As String, <MarshalAs(UnmanagedType.LPStr)> pTarget As String, Flags1 As UInteger, Flags2 As UInteger, ByRef ppCode As IntPtr, ByRef ppErrorMsgs As IntPtr) As Integer
    End Function

#End Region

    Private Shared swapChainDesc1 As DXGI_SWAP_CHAIN_DESC1
    
    ' Important: Keep WndProc delegate as a field to prevent GC collection
    Private Shared wndProcDelegateInstance As WndProcDelegate

    ' Main Entry Point
    <STAThread()>
    Public Shared Function Main(args As String()) As Integer
        Console.WriteLine("----------------------------------------")
        Console.WriteLine("[Main] - Start")

        Dim hwnd As IntPtr = CreateMyWindow()
        If hwnd = IntPtr.Zero Then Return 0

        ShowWindow(hwnd, 1)

        Dim featureLevels As UInteger() = {&HB000UI, &HA100UI, &HA000UI, &H9300UI}
        Dim device As IntPtr = IntPtr.Zero
        Dim context As IntPtr = IntPtr.Zero
        Dim featureLevel As IntPtr = IntPtr.Zero

        Dim hr As Integer = D3D11CreateDevice(IntPtr.Zero, D3D_DRIVER_TYPE_HARDWARE, IntPtr.Zero, D3D11_CREATE_DEVICE_DEBUG, featureLevels, CUInt(featureLevels.Length), D3D11_SDK_VERSION, device, featureLevel, context)

        If hr < 0 Then
            Console.WriteLine("Failed to create D3D11 Device: " & hr.ToString("X"))
            Return 0
        End If

        ' Create IDXGIFactory1
        Dim factory1 As IntPtr = IntPtr.Zero
        Dim IID_IDXGIFactory1 As New Guid("770aae78-f26f-4dba-a829-253c83d1b387")
        hr = CreateDXGIFactory1(IID_IDXGIFactory1, factory1)
        If hr < 0 Then Return 0

        ' Obtain IDXGIFactory2 (QueryInterface)
        Dim factory2 As IntPtr = IntPtr.Zero
        Dim IID_IDXGIFactory2 As New Guid("50c83a1c-e072-4c48-87b0-3630fa36a6d0")
        
        Dim vTableFactory As IntPtr = Marshal.ReadIntPtr(factory1)
        Dim qiPtr As IntPtr = Marshal.ReadIntPtr(vTableFactory, 0) ' IUnknown::QueryInterface #0
        Dim qiFunc = Marshal.GetDelegateForFunctionPointer(Of QueryInterfaceDelegate)(qiPtr)
        hr = qiFunc(factory1, IID_IDXGIFactory2, factory2)
        Marshal.Release(factory1)

        If hr < 0 Then
            Console.WriteLine("Failed to query IDXGIFactory2")
            Return 0
        End If

        ' Create SwapChain
        swapChainDesc1 = New DXGI_SWAP_CHAIN_DESC1() With {
            .Width = 800,
            .Height = 600,
            .Format = DXGI_FORMAT_R8G8B8A8_UNORM,
            .Stereo = False,
            .SampleDesc = New DXGI_SAMPLE_DESC() With {.Count = 1, .Quality = 0},
            .BufferUsage = DXGI_USAGE_RENDER_TARGET_OUTPUT,
            .BufferCount = 2,
            .Scaling = DXGI_SCALING_STRETCH,
            .SwapEffect = DXGI_SWAP_EFFECT_FLIP_SEQUENTIAL,
            .AlphaMode = 0,
            .Flags = 0
        }

        Dim swapChain As IntPtr = IntPtr.Zero
        
        ' IDXGIFactory2::CreateSwapChainForHwnd #15
        Dim vTableFact2 As IntPtr = Marshal.ReadIntPtr(factory2)
        Dim createSCPtr As IntPtr = Marshal.ReadIntPtr(vTableFact2, 15 * IntPtr.Size)
        Dim createSCFunc = Marshal.GetDelegateForFunctionPointer(Of CreateSwapChainForHwndDelegate)(createSCPtr)
        
        hr = createSCFunc(factory2, device, hwnd, swapChainDesc1, IntPtr.Zero, IntPtr.Zero, swapChain)
        Marshal.Release(factory2)

        If hr < 0 Then
            Console.WriteLine("Failed to create SwapChain: " & hr.ToString("X"))
            Return 0
        End If

        ' Get BackBuffer
        Dim backBuffer As IntPtr = IntPtr.Zero
        Dim IID_ID3D11Texture2D As New Guid("6f15aaf2-d208-4e89-9ab4-489535d34f9c")
        
        ' IDXGISwapChain::GetBuffer #9
        Dim vTableSC As IntPtr = Marshal.ReadIntPtr(swapChain)
        Dim getBufferPtr As IntPtr = Marshal.ReadIntPtr(vTableSC, 9 * IntPtr.Size)
        Dim getBufferFunc = Marshal.GetDelegateForFunctionPointer(Of GetBufferDelegate)(getBufferPtr)
        
        hr = getBufferFunc(swapChain, 0, IID_ID3D11Texture2D, backBuffer)
        If hr < 0 Then Return 0

        ' Create RenderTargetView
        Dim renderTargetView As IntPtr = IntPtr.Zero
        
        ' ID3D11Device::CreateRenderTargetView #9
        Dim vTableDev As IntPtr = Marshal.ReadIntPtr(device)
        Dim createRTVPtr As IntPtr = Marshal.ReadIntPtr(vTableDev, 9 * IntPtr.Size)
        Dim createRTVFunc = Marshal.GetDelegateForFunctionPointer(Of CreateRenderTargetViewDelegate)(createRTVPtr)
        
        hr = createRTVFunc(device, backBuffer, IntPtr.Zero, renderTargetView)
        Marshal.Release(backBuffer)
        If hr < 0 Then Return 0

        ' Vertex Data
        Dim vertices As Vertex() = {
            New Vertex() With {.X = 0.0F, .Y = 0.5F, .Z = 0.0F, .R = 1.0F, .G = 0.0F, .B = 0.0F, .A = 1.0F},
            New Vertex() With {.X = 0.5F, .Y = -0.5F, .Z = 0.0F, .R = 0.0F, .G = 1.0F, .B = 0.0F, .A = 1.0F},
            New Vertex() With {.X = -0.5F, .Y = -0.5F, .Z = 0.0F, .R = 0.0F, .G = 0.0F, .B = 1.0F, .A = 1.0F}
        }

        Dim vertexBuffer As IntPtr = IntPtr.Zero
        Dim bufferDesc As New D3D11_BUFFER_DESC() With {
            .ByteWidth = CUInt(Marshal.SizeOf(GetType(Vertex)) * vertices.Length),
            .Usage = D3D11_USAGE_DEFAULT,
            .BindFlags = D3D11_BIND_VERTEX_BUFFER,
            .CPUAccessFlags = 0,
            .MiscFlags = 0,
            .StructureByteStride = 0
        }

        Dim gch As GCHandle = GCHandle.Alloc(vertices, GCHandleType.Pinned)
        Try
            Dim initData As New D3D11_SUBRESOURCE_DATA() With {
                .pSysMem = gch.AddrOfPinnedObject(),
                .SysMemPitch = 0,
                .SysMemSlicePitch = 0
            }

            ' ID3D11Device::CreateBuffer #3
            Dim createBufPtr As IntPtr = Marshal.ReadIntPtr(vTableDev, 3 * IntPtr.Size)
            Dim createBufFunc = Marshal.GetDelegateForFunctionPointer(Of CreateBufferDelegate)(createBufPtr)
            hr = createBufFunc(device, bufferDesc, initData, vertexBuffer)
        Finally
            gch.Free()
        End Try

        If hr < 0 Then Return 0

        ' Compile Shaders
        Dim vsBlob As IntPtr = CompileShaderFromFile("hello.fx", "VS", "vs_4_0")
        Dim psBlob As IntPtr = CompileShaderFromFile("hello.fx", "PS", "ps_4_0")

        If vsBlob = IntPtr.Zero OrElse psBlob = IntPtr.Zero Then Return 0

        ' Create Vertex Shader
        Dim vertexShader As IntPtr = IntPtr.Zero
        Dim vsCodePtr As IntPtr = GetBufferPointer(vsBlob)
        Dim vsSize As IntPtr = GetBufferSize(vsBlob)

        ' ID3D11Device::CreateVertexShader #12
        Dim createVSPtr As IntPtr = Marshal.ReadIntPtr(vTableDev, 12 * IntPtr.Size)
        Dim createVSFunc = Marshal.GetDelegateForFunctionPointer(Of CreateVertexShaderDelegate)(createVSPtr)
        createVSFunc(device, vsCodePtr, vsSize, IntPtr.Zero, vertexShader)

        ' Create Input Layout
        Dim inputLayout As IntPtr = IntPtr.Zero
        Dim inputElements As D3D11_INPUT_ELEMENT_DESC() = {
            New D3D11_INPUT_ELEMENT_DESC() With {.SemanticName = "POSITION", .SemanticIndex = 0, .Format = DXGI_FORMAT_R32G32B32_FLOAT, .InputSlot = 0, .AlignedByteOffset = 0, .InputSlotClass = 0, .InstanceDataStepRate = 0},
            New D3D11_INPUT_ELEMENT_DESC() With {.SemanticName = "COLOR", .SemanticIndex = 0, .Format = DXGI_FORMAT_R32G32B32A32_FLOAT, .InputSlot = 0, .AlignedByteOffset = 12, .InputSlotClass = 0, .InstanceDataStepRate = 0}
        }

        ' ID3D11Device::CreateInputLayout #11
        Dim createILPtr As IntPtr = Marshal.ReadIntPtr(vTableDev, 11 * IntPtr.Size)
        Dim createILFunc = Marshal.GetDelegateForFunctionPointer(Of CreateInputLayoutDelegate)(createILPtr)
        createILFunc(device, inputElements, CUInt(inputElements.Length), vsCodePtr, vsSize, inputLayout)

        ' Create Pixel Shader
        Dim pixelShader As IntPtr = IntPtr.Zero
        Dim psCodePtr As IntPtr = GetBufferPointer(psBlob)
        Dim psSize As IntPtr = GetBufferSize(psBlob)

        ' ID3D11Device::CreatePixelShader #15
        Dim createPSPtr As IntPtr = Marshal.ReadIntPtr(vTableDev, 15 * IntPtr.Size)
        Dim createPSFunc = Marshal.GetDelegateForFunctionPointer(Of CreatePixelShaderDelegate)(createPSPtr)
        createPSFunc(device, psCodePtr, psSize, IntPtr.Zero, pixelShader)

        Marshal.Release(vsBlob)
        Marshal.Release(psBlob)

        ' Setup Viewport
        Dim viewport As New D3D11_VIEWPORT() With {
            .Width = 800,
            .Height = 600,
            .MinDepth = 0.0F,
            .MaxDepth = 1.0F,
            .TopLeftX = 0,
            .TopLeftY = 0
        }

        ' Prepare Context Methods
        Dim vTableCtx As IntPtr = Marshal.ReadIntPtr(context)
        
        ' ID3D11DeviceContext::OMSetRenderTargets #33
        Dim omSetTargetsPtr As IntPtr = Marshal.ReadIntPtr(vTableCtx, 33 * IntPtr.Size)
        Dim omSetTargetsFunc = Marshal.GetDelegateForFunctionPointer(Of OMSetRenderTargetsDelegate)(omSetTargetsPtr)
        
        ' ID3D11DeviceContext::RSSetViewports #44
        Dim rsSetViewPtr As IntPtr = Marshal.ReadIntPtr(vTableCtx, 44 * IntPtr.Size)
        Dim rsSetViewFunc = Marshal.GetDelegateForFunctionPointer(Of RSSetViewportsDelegate)(rsSetViewPtr)
        
        ' ID3D11DeviceContext::IASetInputLayout #17
        Dim iaSetILPtr As IntPtr = Marshal.ReadIntPtr(vTableCtx, 17 * IntPtr.Size)
        Dim iaSetILFunc = Marshal.GetDelegateForFunctionPointer(Of IASetInputLayoutDelegate)(iaSetILPtr)
        
        ' ID3D11DeviceContext::IASetVertexBuffers #18
        Dim iaSetBufPtr As IntPtr = Marshal.ReadIntPtr(vTableCtx, 18 * IntPtr.Size)
        Dim iaSetBufFunc = Marshal.GetDelegateForFunctionPointer(Of IASetVertexBuffersDelegate)(iaSetBufPtr)

        ' ID3D11DeviceContext::IASetPrimitiveTopology #24
        Dim iaSetTopoPtr As IntPtr = Marshal.ReadIntPtr(vTableCtx, 24 * IntPtr.Size)
        Dim iaSetTopoFunc = Marshal.GetDelegateForFunctionPointer(Of IASetPrimitiveTopologyDelegate)(iaSetTopoPtr)

        ' ID3D11DeviceContext::VSSetShader #11
        Dim vsSetShaderPtr As IntPtr = Marshal.ReadIntPtr(vTableCtx, 11 * IntPtr.Size)
        Dim vsSetShaderFunc = Marshal.GetDelegateForFunctionPointer(Of VSSetShaderDelegate)(vsSetShaderPtr)

        ' ID3D11DeviceContext::PSSetShader #9
        Dim psSetShaderPtr As IntPtr = Marshal.ReadIntPtr(vTableCtx, 9 * IntPtr.Size)
        Dim psSetShaderFunc = Marshal.GetDelegateForFunctionPointer(Of PSSetShaderDelegate)(psSetShaderPtr)

        ' ID3D11DeviceContext::ClearRenderTargetView #50
        Dim clearRTVPtr As IntPtr = Marshal.ReadIntPtr(vTableCtx, 50 * IntPtr.Size)
        Dim clearRTVFunc = Marshal.GetDelegateForFunctionPointer(Of ClearRenderTargetViewDelegate)(clearRTVPtr)

        ' ID3D11DeviceContext::Draw #13
        Dim drawPtr As IntPtr = Marshal.ReadIntPtr(vTableCtx, 13 * IntPtr.Size)
        Dim drawFunc = Marshal.GetDelegateForFunctionPointer(Of DrawDelegate)(drawPtr)

        ' IDXGISwapChain::Present #8
        Dim presentPtr As IntPtr = Marshal.ReadIntPtr(vTableSC, 8 * IntPtr.Size)
        Dim presentFunc = Marshal.GetDelegateForFunctionPointer(Of PresentDelegate)(presentPtr)

        ' Set Static Pipeline State (things that don't change per frame)
        rsSetViewFunc(context, 1, viewport)
        iaSetILFunc(context, inputLayout)
        
        Dim buffers As IntPtr() = {vertexBuffer}
        Dim strides As UInteger() = {CUInt(Marshal.SizeOf(GetType(Vertex)))}
        Dim offsets As UInteger() = {0}
        iaSetBufFunc(context, 0, 1, buffers, strides, offsets)
        
        iaSetTopoFunc(context, D3D_PRIMITIVE_TOPOLOGY_TRIANGLELIST)
        vsSetShaderFunc(context, vertexShader, Nothing, 0)
        psSetShaderFunc(context, pixelShader, Nothing, 0)

        ' Main Loop
        Dim msg As New MSG()
        While msg.message <> WM_QUIT
            If PeekMessage(msg, IntPtr.Zero, 0, 0, PM_REMOVE) Then
                TranslateMessage(msg)
                DispatchMessage(msg)
            Else
                ' Rendering
                ' Fix: In FLIP model, RT is unbound after Present, so it must be set every frame.
                omSetTargetsFunc(context, 1, New IntPtr() {renderTargetView}, IntPtr.Zero)

                ' Clear
                Dim clearColor As Single() = {1.0F, 1.0F, 1.0F, 1.0F}
                clearRTVFunc(context, renderTargetView, clearColor)

                ' Draw
                drawFunc(context, 3, 0)

                ' Present
                presentFunc(swapChain, 1, 0)
            End If
        End While

        ' Cleanup (Basic)
        Marshal.Release(renderTargetView)
        Marshal.Release(vertexBuffer)
        Marshal.Release(inputLayout)
        Marshal.Release(vertexShader)
        Marshal.Release(pixelShader)
        Marshal.Release(swapChain)
        Marshal.Release(context)
        Marshal.Release(device)

        Return 0
    End Function

    Private Shared Function CreateMyWindow() As IntPtr
        Dim hInstance As IntPtr = Marshal.GetHINSTANCE(GetType(Hello).Module)
        
        ' Hold delegate in field to prevent GC collection
        wndProcDelegateInstance = AddressOf WndProc

        Dim wndClass As New WNDCLASSEX() With {
            .cbSize = CUInt(Marshal.SizeOf(GetType(WNDCLASSEX))),
            .style = CS_OWNDC,
            .lpfnWndProc = wndProcDelegateInstance,
            .cbClsExtra = 0,
            .cbWndExtra = 0,
            .hInstance = hInstance,
            .hIcon = IntPtr.Zero,
            .hCursor = LoadCursor(IntPtr.Zero, IDC_ARROW),
            .hbrBackground = IntPtr.Zero,
            .lpszMenuName = Nothing,
            .lpszClassName = "MyDX11VBClass",
            .hIconSm = IntPtr.Zero
        }

        RegisterClassEx(wndClass)

        Return CreateWindowEx(0, "MyDX11VBClass", "Hello, DirectX11(VB.NET) World!", WS_OVERLAPPEDWINDOW, 100, 100, 800, 600, IntPtr.Zero, IntPtr.Zero, hInstance, IntPtr.Zero)
    End Function

    Private Shared Function WndProc(hWnd As IntPtr, uMsg As UInteger, wParam As IntPtr, lParam As IntPtr) As IntPtr
        Select Case uMsg
            Case WM_PAINT
                Dim ps As New PAINTSTRUCT()
                Dim hdc As IntPtr = BeginPaint(hWnd, ps)
                Dim msg As String = "Hello, DirectX11(VB.NET) World!"
                TextOut(hdc, 0, 0, msg, msg.Length)
                EndPaint(hWnd, ps)
                Return IntPtr.Zero
            Case WM_DESTROY
                PostQuitMessage(0)
                Return IntPtr.Zero
        End Select
        Return DefWindowProc(hWnd, uMsg, wParam, lParam)
    End Function

    Private Shared Function CompileShaderFromFile(fileName As String, entryPoint As String, profile As String) As IntPtr
        Dim shaderBlob As IntPtr = IntPtr.Zero
        Dim errorBlob As IntPtr = IntPtr.Zero
        Dim flags As UInteger = D3DCOMPILE_ENABLE_STRICTNESS Or D3DCOMPILE_DEBUG Or D3DCOMPILE_SKIP_OPTIMIZATION

        D3DCompileFromFile(fileName, IntPtr.Zero, IntPtr.Zero, entryPoint, profile, flags, 0, shaderBlob, errorBlob)

        If errorBlob <> IntPtr.Zero Then
            Dim msgPtr As IntPtr = GetBufferPointer(errorBlob)
            Dim msgStr As String = Marshal.PtrToStringAnsi(msgPtr)
            Console.WriteLine("Shader Error: " & msgStr)
            Marshal.Release(errorBlob)
        End If

        Return shaderBlob
    End Function

    ' Blob Helpers
    Private Shared Function GetBufferPointer(blob As IntPtr) As IntPtr
        Dim vTable As IntPtr = Marshal.ReadIntPtr(blob)
        Dim funcPtr As IntPtr = Marshal.ReadIntPtr(vTable, 3 * IntPtr.Size) ' ID3DBlob::GetBufferPointer #3
        Dim func = Marshal.GetDelegateForFunctionPointer(Of GetBufferPointerDelegate)(funcPtr)
        Return func(blob)
    End Function

    Private Shared Function GetBufferSize(blob As IntPtr) As IntPtr
        Dim vTable As IntPtr = Marshal.ReadIntPtr(blob)
        Dim funcPtr As IntPtr = Marshal.ReadIntPtr(vTable, 4 * IntPtr.Size) ' ID3DBlob::GetBufferSize #4
        Dim func = Marshal.GetDelegateForFunctionPointer(Of GetBufferSizeDelegate)(funcPtr)
        Return func(blob)
    End Function

End Class
