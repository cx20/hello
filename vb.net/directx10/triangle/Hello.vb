Imports System
Imports System.Text
Imports System.Runtime.InteropServices

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

#Region "DirectX10 Constants & Structs"
    Private Const DXGI_FORMAT_R32G32B32A32_FLOAT As UInteger = 2UI
    Private Const DXGI_FORMAT_R32G32B32_FLOAT As UInteger = 6UI
    Private Const DXGI_FORMAT_R8G8B8A8_UNORM As UInteger = 28UI

    Private Const DXGI_USAGE_RENDER_TARGET_OUTPUT As UInteger = 32UI
    Private Const DXGI_SWAP_EFFECT_DISCARD As UInteger = 0UI

    Private Const D3D10_DRIVER_TYPE_HARDWARE As Integer = 1
    Private Const D3D10_SDK_VERSION As UInteger = 29UI
    Private Const D3D10_BIND_VERTEX_BUFFER As UInteger = 1UI
    Private Const D3D10_USAGE_DEFAULT As UInteger = 0UI
    Private Const D3D10_PRIMITIVE_TOPOLOGY_TRIANGLELIST As UInteger = 4UI

    Private Const D3DCOMPILE_DEBUG As UInteger = 1UI
    Private Const D3DCOMPILE_SKIP_OPTIMIZATION As UInteger = 4UI
    Private Const D3DCOMPILE_ENABLE_STRICTNESS As UInteger = 2048UI

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
    Private Structure Vertex
        Public X As Single, Y As Single, Z As Single
        Public R As Single, G As Single, B As Single, A As Single
    End Structure

    ' D3D10_BUFFER_DESC - Note: No StructureByteStride in D3D10
    <StructLayout(LayoutKind.Sequential, Pack:=4)>
    Private Structure D3D10_BUFFER_DESC
        Public ByteWidth As UInteger
        Public Usage As UInteger
        Public BindFlags As UInteger
        Public CPUAccessFlags As UInteger
        Public MiscFlags As UInteger
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Private Structure D3D10_SUBRESOURCE_DATA
        Public pSysMem As IntPtr
        Public SysMemPitch As UInteger
        Public SysMemSlicePitch As UInteger
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Private Structure D3D10_INPUT_ELEMENT_DESC
        <MarshalAs(UnmanagedType.LPStr)>
        Public SemanticName As String
        Public SemanticIndex As UInteger
        Public Format As UInteger
        Public InputSlot As UInteger
        Public AlignedByteOffset As UInteger
        Public InputSlotClass As UInteger
        Public InstanceDataStepRate As UInteger
    End Structure

    ' D3D10_VIEWPORT - Note: Width/Height are UInteger (not Single like D3D11)
    <StructLayout(LayoutKind.Sequential)>
    Private Structure D3D10_VIEWPORT
        Public TopLeftX As Integer
        Public TopLeftY As Integer
        Public Width As UInteger
        Public Height As UInteger
        Public MinDepth As Single
        Public MaxDepth As Single
    End Structure

#End Region

#Region "DirectX10 Delegates (VTable Maps)"

    ' =====================================
    ' ID3D10Device VTable Delegates
    ' =====================================

    ' #5 PSSetShader (no ClassInstances in D3D10)
    <UnmanagedFunctionPointer(CallingConvention.StdCall)>
    Private Delegate Sub PSSetShaderDelegate(device As IntPtr, pPixelShader As IntPtr)

    ' #7 VSSetShader (no ClassInstances in D3D10)
    <UnmanagedFunctionPointer(CallingConvention.StdCall)>
    Private Delegate Sub VSSetShaderDelegate(device As IntPtr, pVertexShader As IntPtr)

    ' #9 Draw
    <UnmanagedFunctionPointer(CallingConvention.StdCall)>
    Private Delegate Sub DrawDelegate(device As IntPtr, VertexCount As UInteger, StartVertexLocation As UInteger)

    ' #11 IASetInputLayout
    <UnmanagedFunctionPointer(CallingConvention.StdCall)>
    Private Delegate Sub IASetInputLayoutDelegate(device As IntPtr, pInputLayout As IntPtr)

    ' #12 IASetVertexBuffers
    <UnmanagedFunctionPointer(CallingConvention.StdCall)>
    Private Delegate Sub IASetVertexBuffersDelegate(device As IntPtr, StartSlot As UInteger, NumBuffers As UInteger, <[In]()> ppVertexBuffers As IntPtr(), <[In]()> pStrides As UInteger(), <[In]()> pOffsets As UInteger())

    ' #18 IASetPrimitiveTopology
    <UnmanagedFunctionPointer(CallingConvention.StdCall)>
    Private Delegate Sub IASetPrimitiveTopologyDelegate(device As IntPtr, Topology As UInteger)

    ' #24 OMSetRenderTargets
    <UnmanagedFunctionPointer(CallingConvention.StdCall)>
    Private Delegate Sub OMSetRenderTargetsDelegate(device As IntPtr, NumViews As UInteger, <[In]()> ppRenderTargetViews As IntPtr(), pDepthStencilView As IntPtr)

    ' #30 RSSetViewports
    <UnmanagedFunctionPointer(CallingConvention.StdCall)>
    Private Delegate Sub RSSetViewportsDelegate(device As IntPtr, NumViewports As UInteger, ByRef pViewports As D3D10_VIEWPORT)

    ' #35 ClearRenderTargetView
    <UnmanagedFunctionPointer(CallingConvention.StdCall)>
    Private Delegate Sub ClearRenderTargetViewDelegate(device As IntPtr, pRenderTargetView As IntPtr, <MarshalAs(UnmanagedType.LPArray, SizeConst:=4)> ColorRGBA As Single())

    ' #69 ClearState
    <UnmanagedFunctionPointer(CallingConvention.StdCall)>
    Private Delegate Sub ClearStateDelegate(device As IntPtr)

    ' #71 CreateBuffer
    <UnmanagedFunctionPointer(CallingConvention.StdCall)>
    Private Delegate Function CreateBufferDelegate(device As IntPtr, ByRef pDesc As D3D10_BUFFER_DESC, ByRef pInitialData As D3D10_SUBRESOURCE_DATA, ByRef ppBuffer As IntPtr) As Integer

    ' #76 CreateRenderTargetView
    <UnmanagedFunctionPointer(CallingConvention.StdCall)>
    Private Delegate Function CreateRenderTargetViewDelegate(device As IntPtr, pResource As IntPtr, pDesc As IntPtr, ByRef ppRTView As IntPtr) As Integer

    ' #78 CreateInputLayout
    <UnmanagedFunctionPointer(CallingConvention.StdCall)>
    Private Delegate Function CreateInputLayoutDelegate(device As IntPtr, <[In]()> pInputElementDescs As D3D10_INPUT_ELEMENT_DESC(), NumElements As UInteger, pShaderBytecodeWithInputSignature As IntPtr, BytecodeLength As IntPtr, ByRef ppInputLayout As IntPtr) As Integer

    ' #79 CreateVertexShader (no ClassLinkage in D3D10)
    <UnmanagedFunctionPointer(CallingConvention.StdCall)>
    Private Delegate Function CreateVertexShaderDelegate(device As IntPtr, pShaderBytecode As IntPtr, BytecodeLength As IntPtr, ByRef ppVertexShader As IntPtr) As Integer

    ' #82 CreatePixelShader (no ClassLinkage in D3D10)
    <UnmanagedFunctionPointer(CallingConvention.StdCall)>
    Private Delegate Function CreatePixelShaderDelegate(device As IntPtr, pShaderBytecode As IntPtr, BytecodeLength As IntPtr, ByRef ppPixelShader As IntPtr) As Integer

    ' =====================================
    ' IDXGISwapChain VTable Delegates
    ' =====================================

    ' #8 Present
    <UnmanagedFunctionPointer(CallingConvention.StdCall)>
    Private Delegate Function PresentDelegate(pSwapChain As IntPtr, SyncInterval As UInteger, Flags As UInteger) As Integer

    ' #9 GetBuffer
    <UnmanagedFunctionPointer(CallingConvention.StdCall)>
    Private Delegate Function GetBufferDelegate(swapChain As IntPtr, Buffer As UInteger, ByRef riid As Guid, ByRef ppSurface As IntPtr) As Integer

    ' =====================================
    ' ID3DBlob VTable Delegates
    ' =====================================

    ' #3 GetBufferPointer
    <UnmanagedFunctionPointer(CallingConvention.StdCall)>
    Private Delegate Function GetBufferPointerDelegate(pBlob As IntPtr) As IntPtr

    ' #4 GetBufferSize
    <UnmanagedFunctionPointer(CallingConvention.StdCall)>
    Private Delegate Function GetBufferSizeDelegate(pBlob As IntPtr) As IntPtr

#End Region

#Region "DLL Imports (D3D10/D3DCompiler)"

    <DllImport("d3d10.dll", CallingConvention:=CallingConvention.StdCall, SetLastError:=True)>
    Private Shared Function D3D10CreateDeviceAndSwapChain(
        pAdapter As IntPtr,
        DriverType As Integer,
        Software As IntPtr,
        Flags As UInteger,
        SDKVersion As UInteger,
        ByRef pSwapChainDesc As DXGI_SWAP_CHAIN_DESC,
        ByRef ppSwapChain As IntPtr,
        ByRef ppDevice As IntPtr
    ) As Integer
    End Function

    <DllImport("d3dcompiler_47.dll", CallingConvention:=CallingConvention.Winapi)>
    Private Shared Function D3DCompileFromFile(
        <MarshalAs(UnmanagedType.LPWStr)> pFileName As String,
        pDefines As IntPtr,
        pInclude As IntPtr,
        <MarshalAs(UnmanagedType.LPStr)> pEntrypoint As String,
        <MarshalAs(UnmanagedType.LPStr)> pTarget As String,
        Flags1 As UInteger,
        Flags2 As UInteger,
        ByRef ppCode As IntPtr,
        ByRef ppErrorMsgs As IntPtr
    ) As Integer
    End Function

#End Region

    ' Important: Keep WndProc delegate as a field to prevent GC collection
    Private Shared wndProcDelegateInstance As WndProcDelegate

    ' Main Entry Point
    <STAThread()>
    Public Shared Function Main(args As String()) As Integer
        Console.WriteLine("----------------------------------------")
        Console.WriteLine("[Main] - Start DirectX10 VB.NET Sample")

        Dim hwnd As IntPtr = CreateMyWindow()
        If hwnd = IntPtr.Zero Then
            Console.WriteLine("Failed to create window")
            Return -1
        End If

        ShowWindow(hwnd, 1)

        ' Create swap chain description
        Dim swapChainDesc As New DXGI_SWAP_CHAIN_DESC() With {
            .BufferDesc = New DXGI_MODE_DESC() With {
                .Width = 800,
                .Height = 600,
                .RefreshRate = New DXGI_RATIONAL() With {.Numerator = 60, .Denominator = 1},
                .Format = DXGI_FORMAT_R8G8B8A8_UNORM,
                .ScanlineOrdering = 0,
                .Scaling = 0
            },
            .SampleDesc = New DXGI_SAMPLE_DESC() With {.Count = 1, .Quality = 0},
            .BufferUsage = DXGI_USAGE_RENDER_TARGET_OUTPUT,
            .BufferCount = 1,
            .OutputWindow = hwnd,
            .Windowed = True,
            .SwapEffect = DXGI_SWAP_EFFECT_DISCARD,
            .Flags = 0
        }

        ' Create device and swap chain
        Dim device As IntPtr = IntPtr.Zero
        Dim swapChain As IntPtr = IntPtr.Zero

        Dim hr As Integer = D3D10CreateDeviceAndSwapChain(
            IntPtr.Zero,
            D3D10_DRIVER_TYPE_HARDWARE,
            IntPtr.Zero,
            0,  ' Flags
            D3D10_SDK_VERSION,
            swapChainDesc,
            swapChain,
            device
        )

        If hr < 0 Then
            Console.WriteLine("Failed to create D3D10 Device and SwapChain: " & hr.ToString("X"))
            Return -1
        End If
        Console.WriteLine($"Device: {device:X}, SwapChain: {swapChain:X}")

        ' Get VTables
        Dim vTableDev As IntPtr = Marshal.ReadIntPtr(device)
        Dim vTableSC As IntPtr = Marshal.ReadIntPtr(swapChain)

        ' Get BackBuffer
        Dim backBuffer As IntPtr = IntPtr.Zero
        Dim IID_ID3D10Texture2D As New Guid("9B7E4C04-342C-4106-A19F-4F2704F689F0")

        ' IDXGISwapChain::GetBuffer #9
        Dim getBufferPtr As IntPtr = Marshal.ReadIntPtr(vTableSC, 9 * IntPtr.Size)
        Dim getBufferFunc = Marshal.GetDelegateForFunctionPointer(Of GetBufferDelegate)(getBufferPtr)
        hr = getBufferFunc(swapChain, 0, IID_ID3D10Texture2D, backBuffer)
        If hr < 0 Then
            Console.WriteLine("Failed to get back buffer: " & hr.ToString("X"))
            Return -1
        End If
        Console.WriteLine($"BackBuffer: {backBuffer:X}")

        ' Create RenderTargetView
        Dim renderTargetView As IntPtr = IntPtr.Zero

        ' ID3D10Device::CreateRenderTargetView #76
        Dim createRTVPtr As IntPtr = Marshal.ReadIntPtr(vTableDev, 76 * IntPtr.Size)
        Dim createRTVFunc = Marshal.GetDelegateForFunctionPointer(Of CreateRenderTargetViewDelegate)(createRTVPtr)
        hr = createRTVFunc(device, backBuffer, IntPtr.Zero, renderTargetView)
        Marshal.Release(backBuffer)
        If hr < 0 Then
            Console.WriteLine("Failed to create render target view: " & hr.ToString("X"))
            Return -1
        End If
        Console.WriteLine($"RenderTargetView: {renderTargetView:X}")

        ' Set render targets
        ' ID3D10Device::OMSetRenderTargets #24
        Dim omSetTargetsPtr As IntPtr = Marshal.ReadIntPtr(vTableDev, 24 * IntPtr.Size)
        Dim omSetTargetsFunc = Marshal.GetDelegateForFunctionPointer(Of OMSetRenderTargetsDelegate)(omSetTargetsPtr)
        omSetTargetsFunc(device, 1, New IntPtr() {renderTargetView}, IntPtr.Zero)

        ' Set viewport
        Dim viewport As New D3D10_VIEWPORT() With {
            .TopLeftX = 0,
            .TopLeftY = 0,
            .Width = 800,
            .Height = 600,
            .MinDepth = 0.0F,
            .MaxDepth = 1.0F
        }

        ' ID3D10Device::RSSetViewports #30
        Dim rsSetViewPtr As IntPtr = Marshal.ReadIntPtr(vTableDev, 30 * IntPtr.Size)
        Dim rsSetViewFunc = Marshal.GetDelegateForFunctionPointer(Of RSSetViewportsDelegate)(rsSetViewPtr)
        rsSetViewFunc(device, 1, viewport)

        ' Compile Shaders
        Dim vsBlob As IntPtr = CompileShaderFromFile("hello.fx", "VS", "vs_4_0")
        Dim psBlob As IntPtr = CompileShaderFromFile("hello.fx", "PS", "ps_4_0")

        If vsBlob = IntPtr.Zero OrElse psBlob = IntPtr.Zero Then
            Console.WriteLine("Failed to compile shaders")
            Return -1
        End If

        ' Create Vertex Shader
        Dim vertexShader As IntPtr = IntPtr.Zero
        Dim vsCodePtr As IntPtr = GetBufferPointer(vsBlob)
        Dim vsSize As IntPtr = GetBufferSize(vsBlob)

        ' ID3D10Device::CreateVertexShader #79
        Dim createVSPtr As IntPtr = Marshal.ReadIntPtr(vTableDev, 79 * IntPtr.Size)
        Dim createVSFunc = Marshal.GetDelegateForFunctionPointer(Of CreateVertexShaderDelegate)(createVSPtr)
        hr = createVSFunc(device, vsCodePtr, vsSize, vertexShader)
        If hr < 0 Then
            Console.WriteLine("Failed to create vertex shader: " & hr.ToString("X"))
            Return -1
        End If
        Console.WriteLine($"VertexShader: {vertexShader:X}")

        ' Create Input Layout
        Dim inputLayout As IntPtr = IntPtr.Zero
        Dim inputElements As D3D10_INPUT_ELEMENT_DESC() = {
            New D3D10_INPUT_ELEMENT_DESC() With {
                .SemanticName = "POSITION",
                .SemanticIndex = 0,
                .Format = DXGI_FORMAT_R32G32B32_FLOAT,
                .InputSlot = 0,
                .AlignedByteOffset = 0,
                .InputSlotClass = 0,
                .InstanceDataStepRate = 0
            },
            New D3D10_INPUT_ELEMENT_DESC() With {
                .SemanticName = "COLOR",
                .SemanticIndex = 0,
                .Format = DXGI_FORMAT_R32G32B32A32_FLOAT,
                .InputSlot = 0,
                .AlignedByteOffset = 12,
                .InputSlotClass = 0,
                .InstanceDataStepRate = 0
            }
        }

        ' ID3D10Device::CreateInputLayout #78
        Dim createILPtr As IntPtr = Marshal.ReadIntPtr(vTableDev, 78 * IntPtr.Size)
        Dim createILFunc = Marshal.GetDelegateForFunctionPointer(Of CreateInputLayoutDelegate)(createILPtr)
        hr = createILFunc(device, inputElements, CUInt(inputElements.Length), vsCodePtr, vsSize, inputLayout)
        If hr < 0 Then
            Console.WriteLine("Failed to create input layout: " & hr.ToString("X"))
            Return -1
        End If
        Console.WriteLine($"InputLayout: {inputLayout:X}")

        Marshal.Release(vsBlob)

        ' Create Pixel Shader
        Dim pixelShader As IntPtr = IntPtr.Zero
        Dim psCodePtr As IntPtr = GetBufferPointer(psBlob)
        Dim psSize As IntPtr = GetBufferSize(psBlob)

        ' ID3D10Device::CreatePixelShader #82
        Dim createPSPtr As IntPtr = Marshal.ReadIntPtr(vTableDev, 82 * IntPtr.Size)
        Dim createPSFunc = Marshal.GetDelegateForFunctionPointer(Of CreatePixelShaderDelegate)(createPSPtr)
        hr = createPSFunc(device, psCodePtr, psSize, pixelShader)
        If hr < 0 Then
            Console.WriteLine("Failed to create pixel shader: " & hr.ToString("X"))
            Return -1
        End If
        Console.WriteLine($"PixelShader: {pixelShader:X}")

        Marshal.Release(psBlob)

        ' Vertex Data
        Dim vertices As Vertex() = {
            New Vertex() With {.X = 0.0F, .Y = 0.5F, .Z = 0.5F, .R = 1.0F, .G = 0.0F, .B = 0.0F, .A = 1.0F},
            New Vertex() With {.X = 0.5F, .Y = -0.5F, .Z = 0.5F, .R = 0.0F, .G = 1.0F, .B = 0.0F, .A = 1.0F},
            New Vertex() With {.X = -0.5F, .Y = -0.5F, .Z = 0.5F, .R = 0.0F, .G = 0.0F, .B = 1.0F, .A = 1.0F}
        }

        Dim vertexBuffer As IntPtr = IntPtr.Zero
        Dim bufferDesc As New D3D10_BUFFER_DESC() With {
            .ByteWidth = CUInt(Marshal.SizeOf(GetType(Vertex)) * vertices.Length),
            .Usage = D3D10_USAGE_DEFAULT,
            .BindFlags = D3D10_BIND_VERTEX_BUFFER,
            .CPUAccessFlags = 0,
            .MiscFlags = 0
        }

        Dim gch As GCHandle = GCHandle.Alloc(vertices, GCHandleType.Pinned)
        Try
            Dim initData As New D3D10_SUBRESOURCE_DATA() With {
                .pSysMem = gch.AddrOfPinnedObject(),
                .SysMemPitch = 0,
                .SysMemSlicePitch = 0
            }

            ' ID3D10Device::CreateBuffer #71
            Dim createBufPtr As IntPtr = Marshal.ReadIntPtr(vTableDev, 71 * IntPtr.Size)
            Dim createBufFunc = Marshal.GetDelegateForFunctionPointer(Of CreateBufferDelegate)(createBufPtr)
            hr = createBufFunc(device, bufferDesc, initData, vertexBuffer)
        Finally
            gch.Free()
        End Try

        If hr < 0 Then
            Console.WriteLine("Failed to create vertex buffer: " & hr.ToString("X"))
            Return -1
        End If
        Console.WriteLine($"VertexBuffer: {vertexBuffer:X}")

        ' Prepare Device Methods (all rendering goes through device in D3D10)
        ' ID3D10Device::IASetInputLayout #11
        Dim iaSetILPtr As IntPtr = Marshal.ReadIntPtr(vTableDev, 11 * IntPtr.Size)
        Dim iaSetILFunc = Marshal.GetDelegateForFunctionPointer(Of IASetInputLayoutDelegate)(iaSetILPtr)

        ' ID3D10Device::IASetVertexBuffers #12
        Dim iaSetBufPtr As IntPtr = Marshal.ReadIntPtr(vTableDev, 12 * IntPtr.Size)
        Dim iaSetBufFunc = Marshal.GetDelegateForFunctionPointer(Of IASetVertexBuffersDelegate)(iaSetBufPtr)

        ' ID3D10Device::IASetPrimitiveTopology #18
        Dim iaSetTopoPtr As IntPtr = Marshal.ReadIntPtr(vTableDev, 18 * IntPtr.Size)
        Dim iaSetTopoFunc = Marshal.GetDelegateForFunctionPointer(Of IASetPrimitiveTopologyDelegate)(iaSetTopoPtr)

        ' ID3D10Device::VSSetShader #7
        Dim vsSetShaderPtr As IntPtr = Marshal.ReadIntPtr(vTableDev, 7 * IntPtr.Size)
        Dim vsSetShaderFunc = Marshal.GetDelegateForFunctionPointer(Of VSSetShaderDelegate)(vsSetShaderPtr)

        ' ID3D10Device::PSSetShader #5
        Dim psSetShaderPtr As IntPtr = Marshal.ReadIntPtr(vTableDev, 5 * IntPtr.Size)
        Dim psSetShaderFunc = Marshal.GetDelegateForFunctionPointer(Of PSSetShaderDelegate)(psSetShaderPtr)

        ' ID3D10Device::ClearRenderTargetView #35
        Dim clearRTVPtr As IntPtr = Marshal.ReadIntPtr(vTableDev, 35 * IntPtr.Size)
        Dim clearRTVFunc = Marshal.GetDelegateForFunctionPointer(Of ClearRenderTargetViewDelegate)(clearRTVPtr)

        ' ID3D10Device::Draw #9
        Dim drawPtr As IntPtr = Marshal.ReadIntPtr(vTableDev, 9 * IntPtr.Size)
        Dim drawFunc = Marshal.GetDelegateForFunctionPointer(Of DrawDelegate)(drawPtr)

        ' IDXGISwapChain::Present #8
        Dim presentPtr As IntPtr = Marshal.ReadIntPtr(vTableSC, 8 * IntPtr.Size)
        Dim presentFunc = Marshal.GetDelegateForFunctionPointer(Of PresentDelegate)(presentPtr)

        ' ID3D10Device::ClearState #69
        Dim clearStatePtr As IntPtr = Marshal.ReadIntPtr(vTableDev, 69 * IntPtr.Size)
        Dim clearStateFunc = Marshal.GetDelegateForFunctionPointer(Of ClearStateDelegate)(clearStatePtr)

        ' Set Static Pipeline State
        iaSetILFunc(device, inputLayout)

        Dim buffers As IntPtr() = {vertexBuffer}
        Dim strides As UInteger() = {CUInt(Marshal.SizeOf(GetType(Vertex)))}
        Dim offsets As UInteger() = {0}
        iaSetBufFunc(device, 0, 1, buffers, strides, offsets)

        iaSetTopoFunc(device, D3D10_PRIMITIVE_TOPOLOGY_TRIANGLELIST)
        vsSetShaderFunc(device, vertexShader)
        psSetShaderFunc(device, pixelShader)

        Console.WriteLine("Starting render loop...")

        ' Main Loop
        Dim msg As New MSG()
        While msg.message <> WM_QUIT
            If PeekMessage(msg, IntPtr.Zero, 0, 0, PM_REMOVE) Then
                TranslateMessage(msg)
                DispatchMessage(msg)
            Else
                ' Rendering
                ' Clear
                Dim clearColor As Single() = {1.0F, 1.0F, 1.0F, 1.0F}
                clearRTVFunc(device, renderTargetView, clearColor)

                ' Draw
                drawFunc(device, 3, 0)

                ' Present
                presentFunc(swapChain, 0, 0)
            End If
        End While

        ' Cleanup
        Console.WriteLine("Cleaning up...")
        clearStateFunc(device)

        If vertexBuffer <> IntPtr.Zero Then Marshal.Release(vertexBuffer)
        If inputLayout <> IntPtr.Zero Then Marshal.Release(inputLayout)
        If vertexShader <> IntPtr.Zero Then Marshal.Release(vertexShader)
        If pixelShader <> IntPtr.Zero Then Marshal.Release(pixelShader)
        If renderTargetView <> IntPtr.Zero Then Marshal.Release(renderTargetView)
        If swapChain <> IntPtr.Zero Then Marshal.Release(swapChain)
        If device <> IntPtr.Zero Then Marshal.Release(device)

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
            .lpszClassName = "MyDX10VBClass",
            .hIconSm = IntPtr.Zero
        }

        RegisterClassEx(wndClass)

        Return CreateWindowEx(0, "MyDX10VBClass", "Hello, World!", WS_OVERLAPPEDWINDOW, 100, 100, 800, 600, IntPtr.Zero, IntPtr.Zero, hInstance, IntPtr.Zero)
    End Function

    Private Shared Function WndProc(hWnd As IntPtr, uMsg As UInteger, wParam As IntPtr, lParam As IntPtr) As IntPtr
        Select Case uMsg
            Case WM_PAINT
                Dim ps As New PAINTSTRUCT()
                Dim hdc As IntPtr = BeginPaint(hWnd, ps)
                Dim msg As String = "Hello, DirectX10(VB.NET) World!"
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
        Console.WriteLine($"Compiling shader: {fileName}, Entry: {entryPoint}, Profile: {profile}")

        Dim shaderBlob As IntPtr = IntPtr.Zero
        Dim errorBlob As IntPtr = IntPtr.Zero
        Dim flags As UInteger = D3DCOMPILE_ENABLE_STRICTNESS

        Dim hr As Integer = D3DCompileFromFile(fileName, IntPtr.Zero, IntPtr.Zero, entryPoint, profile, flags, 0, shaderBlob, errorBlob)

        If hr < 0 Then
            If errorBlob <> IntPtr.Zero Then
                Dim msgPtr As IntPtr = GetBufferPointer(errorBlob)
                Dim msgStr As String = Marshal.PtrToStringAnsi(msgPtr)
                Console.WriteLine("Shader Error: " & msgStr)
                Marshal.Release(errorBlob)
            End If
            Return IntPtr.Zero
        End If

        If errorBlob <> IntPtr.Zero Then
            Marshal.Release(errorBlob)
        End If

        Console.WriteLine($"Shader compiled successfully: {shaderBlob:X}")
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
