Option Strict Off
Option Explicit On

Imports System
Imports System.IO
Imports System.Runtime.InteropServices
Imports System.Text
Imports System.Threading

' OpenGL 4.6 + DirectX 11 + Vulkan 1.4 triangles composited via Windows.UI.Composition.
' Compile: vbc /target:winexe Hello.vb
Public Module Hello
    Private Const PW As Integer = 320
    Private Const PH As Integer = 480

    Private Const WS_OVR As UInteger = &HCF0000UI
    Private Const WS_VIS As UInteger = &H10000000UI
    Private Const CS_OWN As UInteger = &H20UI

    Private Const WM_DEST As UInteger = 2UI
    Private Const WM_CLOSE As UInteger = &H10UI
    Private Const WM_QUIT As UInteger = &H12UI
    Private Const WM_KEY As UInteger = &H100UI
    Private Const PM_REM As UInteger = 1UI
    Private Const VK_ESC As Integer = &H1B

    Private Const DXGI_B8 As UInteger = 87UI
    Private Const DXGI_R32G32B32 As UInteger = 6UI
    Private Const DXGI_R32G32B32A32 As UInteger = 2UI
    Private Const DXGI_USAGE_RTO As UInteger = &H20UI
    Private Const DXGI_SCALING_STRETCH As UInteger = 0UI
    Private Const DXGI_FLIP_DISCARD As UInteger = 4UI
    Private Const DXGI_ALPHA_IGNORE As UInteger = 0UI

    Private Const D3D_SDK As UInteger = 7UI
    Private Const D3D_FL11 As UInteger = &HB000UI
    Private Const D3D_BGRA As UInteger = &H20UI
    Private Const D3D_STAGING As UInteger = 3UI
    Private Const D3D_BIND_VB As UInteger = 1UI
    Private Const D3D_MAP_W As UInteger = 2UI
    Private Const D3D_CPU_W As UInteger = &H10000UI
    Private Const D3D_TOPO_TRI As UInteger = 4UI

    Private Const GL_TRI As UInteger = 4UI
    Private Const GL_FLT As UInteger = &H1406UI
    Private Const GL_COLBIT As UInteger = &H4000UI
    Private Const GL_ABuf As UInteger = &H8892UI
    Private Const GL_STATIC As UInteger = &H88E4UI
    Private Const GL_VS As UInteger = &H8B31UI
    Private Const GL_FS As UInteger = &H8B30UI
    Private Const GL_FB As UInteger = &H8D40UI
    Private Const GL_RB As UInteger = &H8D41UI
    Private Const GL_CA0 As UInteger = &H8CE0UI
    Private Const WGL_RW As UInteger = 1UI

    <StructLayout(LayoutKind.Sequential)>
    Private Structure POINT
        Public X As Integer
        Public Y As Integer
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Private Structure RECT
        Public Left As Integer
        Public Top As Integer
        Public Right As Integer
        Public Bottom As Integer
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Private Structure Float2
        Public X As Single
        Public Y As Single
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Private Structure Float3
        Public X As Single
        Public Y As Single
        Public Z As Single
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Private Structure MSG
        Public hwnd As IntPtr
        Public message As UInteger
        Public wParam As IntPtr
        Public lParam As IntPtr
        Public time As UInteger
        Public pt As POINT
    End Structure

    Private Delegate Function WndProcDelegate(hWnd As IntPtr, uMsg As UInteger, wParam As IntPtr, lParam As IntPtr) As IntPtr

    <StructLayout(LayoutKind.Sequential, CharSet:=CharSet.Unicode)>
    Private Structure WNDCLASSEX
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
    Private Structure PIXELFORMATDESCRIPTOR
        Public nSize As UShort
        Public nVersion As UShort
        Public dwFlags As UInteger
        Public iPixelType As Byte
        Public cColorBits As Byte
        Public cRedBits As Byte
        Public cRedShift As Byte
        Public cGreenBits As Byte
        Public cGreenShift As Byte
        Public cBlueBits As Byte
        Public cBlueShift As Byte
        Public cAlphaBits As Byte
        Public cAlphaShift As Byte
        Public cAccumBits As Byte
        Public cAccumRedBits As Byte
        Public cAccumGreenBits As Byte
        Public cAccumBlueBits As Byte
        Public cAccumAlphaBits As Byte
        Public cDepthBits As Byte
        Public cStencilBits As Byte
        Public cAuxBuffers As Byte
        Public iLayerType As Byte
        Public bReserved As Byte
        Public dwLayerMask As UInteger
        Public dwVisibleMask As UInteger
        Public dwDamageMask As UInteger
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Private Structure DXGI_SAMPLE_DESC
        Public Count As UInteger
        Public Quality As UInteger
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Private Structure DXGI_SWAP_CHAIN_DESC1
        Public Width As UInteger
        Public Height As UInteger
        Public Format As UInteger
        <MarshalAs(UnmanagedType.Bool)>
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
    Private Structure DispatcherQueueOptions
        Public dwSize As Integer
        Public threadType As Integer
        Public apartmentType As Integer
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Private Structure D3D11_TEXTURE2D_DESC
        Public Width As UInteger
        Public Height As UInteger
        Public MipLevels As UInteger
        Public ArraySize As UInteger
        Public Format As UInteger
        Public SampleDesc As DXGI_SAMPLE_DESC
        Public Usage As UInteger
        Public BindFlags As UInteger
        Public CPUAccessFlags As UInteger
        Public MiscFlags As UInteger
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Private Structure D3D11_MAPPED_SUBRESOURCE
        Public pData As IntPtr
        Public RowPitch As UInteger
        Public DepthPitch As UInteger
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

    <StructLayout(LayoutKind.Sequential)>
    Private Structure DxVertex
        Public X As Single
        Public Y As Single
        Public Z As Single
        Public R As Single
        Public G As Single
        Public B As Single
        Public A As Single
    End Structure

    <UnmanagedFunctionPointer(CallingConvention.StdCall)>
    Private Delegate Function QIDelegate(self As IntPtr, ByRef riid As Guid, ByRef ppv As IntPtr) As Integer

    <UnmanagedFunctionPointer(CallingConvention.StdCall)>
    Private Delegate Function CreateRTVDelegate(d As IntPtr, r As IntPtr, desc As IntPtr, ByRef rtv As IntPtr) As Integer

    <UnmanagedFunctionPointer(CallingConvention.StdCall)>
    Private Delegate Function CreateBufferDelegate(d As IntPtr, ByRef desc As D3D11_BUFFER_DESC, ByRef data As D3D11_SUBRESOURCE_DATA, ByRef buf As IntPtr) As Integer

    <UnmanagedFunctionPointer(CallingConvention.StdCall)>
    Private Delegate Function CreateTex2DDelegate(d As IntPtr, ByRef desc As D3D11_TEXTURE2D_DESC, init As IntPtr, ByRef tex As IntPtr) As Integer

    <UnmanagedFunctionPointer(CallingConvention.StdCall)>
    Private Delegate Function CreateVSDelegate(d As IntPtr, bc As IntPtr, sz As IntPtr, lnk As IntPtr, ByRef vs As IntPtr) As Integer

    <UnmanagedFunctionPointer(CallingConvention.StdCall)>
    Private Delegate Function CreatePSDelegate(d As IntPtr, bc As IntPtr, sz As IntPtr, lnk As IntPtr, ByRef ps As IntPtr) As Integer

    <UnmanagedFunctionPointer(CallingConvention.StdCall)>
    Private Delegate Function CreateILDelegate(d As IntPtr, <[In]> e As D3D11_INPUT_ELEMENT_DESC(), n As UInteger, bc As IntPtr, sz As IntPtr, ByRef il As IntPtr) As Integer

    <UnmanagedFunctionPointer(CallingConvention.StdCall)>
    Private Delegate Sub PSSetDelegate(c As IntPtr, ps As IntPtr, ci As IntPtr(), n As UInteger)

    <UnmanagedFunctionPointer(CallingConvention.StdCall)>
    Private Delegate Sub VSSetDelegate(c As IntPtr, vs As IntPtr, ci As IntPtr(), n As UInteger)

    <UnmanagedFunctionPointer(CallingConvention.StdCall)>
    Private Delegate Sub DrawDelegate(c As IntPtr, cnt As UInteger, start As UInteger)

    <UnmanagedFunctionPointer(CallingConvention.StdCall)>
    Private Delegate Function MapDelegate(c As IntPtr, r As IntPtr, subr As UInteger, mapType As UInteger, flags As UInteger, ByRef m As D3D11_MAPPED_SUBRESOURCE) As Integer

    <UnmanagedFunctionPointer(CallingConvention.StdCall)>
    Private Delegate Sub UnmapDelegate(c As IntPtr, r As IntPtr, subr As UInteger)

    <UnmanagedFunctionPointer(CallingConvention.StdCall)>
    Private Delegate Sub IASetILDelegate(c As IntPtr, il As IntPtr)

    <UnmanagedFunctionPointer(CallingConvention.StdCall)>
    Private Delegate Sub IASetVBDelegate(c As IntPtr, slot As UInteger, n As UInteger, vbs As IntPtr(), strides As UInteger(), offs As UInteger())

    <UnmanagedFunctionPointer(CallingConvention.StdCall)>
    Private Delegate Sub IASetTopoDelegate(c As IntPtr, topo As UInteger)

    <UnmanagedFunctionPointer(CallingConvention.StdCall)>
    Private Delegate Sub OMSetRTDelegate(c As IntPtr, n As UInteger, rtvs As IntPtr(), dsv As IntPtr)

    <UnmanagedFunctionPointer(CallingConvention.StdCall)>
    Private Delegate Sub RSSetVPDelegate(c As IntPtr, n As UInteger, ByRef vp As D3D11_VIEWPORT)

    <UnmanagedFunctionPointer(CallingConvention.StdCall)>
    Private Delegate Sub CopyResDelegate(c As IntPtr, dst As IntPtr, src As IntPtr)

    <UnmanagedFunctionPointer(CallingConvention.StdCall)>
    Private Delegate Sub ClearRTVDelegate(c As IntPtr, rtv As IntPtr, <MarshalAs(UnmanagedType.LPArray, SizeConst:=4)> col As Single())

    <UnmanagedFunctionPointer(CallingConvention.StdCall)>
    Private Delegate Function PresentDelegate(sc As IntPtr, sync As UInteger, flags As UInteger) As Integer

    <UnmanagedFunctionPointer(CallingConvention.StdCall)>
    Private Delegate Function GetBufDelegate(sc As IntPtr, buf As UInteger, ByRef iid As Guid, ByRef srf As IntPtr) As Integer

    <UnmanagedFunctionPointer(CallingConvention.StdCall)>
    Private Delegate Function CreateSCCompDelegate(fac As IntPtr, dev As IntPtr, ByRef desc As DXGI_SWAP_CHAIN_DESC1, restrictToOutput As IntPtr, ByRef sc As IntPtr) As Integer

    <UnmanagedFunctionPointer(CallingConvention.StdCall)>
    Private Delegate Function BlobPtrDelegate(b As IntPtr) As IntPtr

    <UnmanagedFunctionPointer(CallingConvention.StdCall)>
    Private Delegate Function BlobSzDelegate(b As IntPtr) As IntPtr

    <UnmanagedFunctionPointer(CallingConvention.StdCall)>
    Private Delegate Function CreateDesktopWindowTargetDelegate(interop As IntPtr, hwnd As IntPtr, isTopmost As Integer, ByRef target As IntPtr) As Integer

    <UnmanagedFunctionPointer(CallingConvention.StdCall)>
    Private Delegate Function CreateCompSurfaceForSCDelegate(interop As IntPtr, swapChain As IntPtr, ByRef surface As IntPtr) As Integer

    <UnmanagedFunctionPointer(CallingConvention.StdCall)>
    Private Delegate Function CreateContainerVisualDelegate(compositor As IntPtr, ByRef visual As IntPtr) As Integer

    <UnmanagedFunctionPointer(CallingConvention.StdCall)>
    Private Delegate Function CreateSpriteVisualDelegate(compositor As IntPtr, ByRef visual As IntPtr) As Integer

    <UnmanagedFunctionPointer(CallingConvention.StdCall)>
    Private Delegate Function CreateSurfaceBrushWithSurfaceDelegate(compositor As IntPtr, surface As IntPtr, ByRef brush As IntPtr) As Integer

    <UnmanagedFunctionPointer(CallingConvention.StdCall)>
    Private Delegate Function PutRootDelegate(target As IntPtr, visual As IntPtr) As Integer

    <UnmanagedFunctionPointer(CallingConvention.StdCall)>
    Private Delegate Function GetChildrenDelegate(container As IntPtr, ByRef children As IntPtr) As Integer

    <UnmanagedFunctionPointer(CallingConvention.StdCall)>
    Private Delegate Function InsertAtTopDelegate(collection As IntPtr, visual As IntPtr) As Integer

    <UnmanagedFunctionPointer(CallingConvention.StdCall)>
    Private Delegate Function PutBrushDelegate(sprite As IntPtr, brush As IntPtr) As Integer

    <UnmanagedFunctionPointer(CallingConvention.StdCall)>
    Private Delegate Function PutSizeDelegate(visual As IntPtr, size As Float2) As Integer

    <UnmanagedFunctionPointer(CallingConvention.StdCall)>
    Private Delegate Function PutOffsetDelegate(visual As IntPtr, offset As Float3) As Integer

    Private Delegate Sub glGenBuffersD(n As Integer, b As UInteger())
    Private Delegate Sub glBindBufferD(t As UInteger, b As UInteger)
    Private Delegate Sub glBufferDataD(t As UInteger, sz As Integer, d As Single(), u As UInteger)
    Private Delegate Function glCreateShaderD(t As UInteger) As UInteger
    Private Delegate Sub glShaderSourceD(s As UInteger, c As Integer, src As String(), len As Integer())
    Private Delegate Sub glCompileShaderD(s As UInteger)
    Private Delegate Function glCreateProgramD() As UInteger
    Private Delegate Sub glAttachShaderD(p As UInteger, s As UInteger)
    Private Delegate Sub glLinkProgramD(p As UInteger)
    Private Delegate Sub glUseProgramD(p As UInteger)
    Private Delegate Function glGetAttribLocationD(p As UInteger, n As String) As UInteger
    Private Delegate Sub glEnableVAD(i As UInteger)
    Private Delegate Sub glVertexAttribPointerD(i As UInteger, sz As Integer, t As UInteger, norm As Boolean, stride As Integer, ptr As IntPtr)
    Private Delegate Sub glGenFBD(n As Integer, f As UInteger())
    Private Delegate Sub glBindFBD(t As UInteger, f As UInteger)
    Private Delegate Sub glFBRBD(t As UInteger, a As UInteger, rt As UInteger, rb As UInteger)
    Private Delegate Sub glGenRBD(n As Integer, r As UInteger())
    Private Delegate Sub glGenVAOD(n As Integer, v As UInteger())
    Private Delegate Sub glBindVAOD(v As UInteger)
    Private Delegate Function wglCreateCtxARBD(hdc As IntPtr, sh As IntPtr, a As Integer()) As IntPtr
    Private Delegate Function wglDXOpenD(dx As IntPtr) As IntPtr
    Private Delegate Function wglDXRegD(h As IntPtr, dx As IntPtr, gl As UInteger, t As UInteger, a As UInteger) As IntPtr
    Private Delegate Function wglDXLockD(h As IntPtr, c As Integer, o As IntPtr()) As Integer
    Private Delegate Function wglDXUnlockD(h As IntPtr, c As Integer, o As IntPtr()) As Integer

    <StructLayout(LayoutKind.Sequential)>
    Private Structure VkAppInfo
        Public sType As UInteger
        Public pNext As IntPtr
        Public pAppName As IntPtr
        Public appVer As UInteger
        Public pEngName As IntPtr
        Public engVer As UInteger
        Public apiVer As UInteger
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Private Structure VkInstCI
        Public sType As UInteger
        Public pNext As IntPtr
        Public flags As UInteger
        Public pAppInfo As IntPtr
        Public lCnt As UInteger
        Public ppL As IntPtr
        Public eCnt As UInteger
        Public ppE As IntPtr
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Private Structure VkDevQCI
        Public sType As UInteger
        Public pNext As IntPtr
        Public flags As UInteger
        Public qfi As UInteger
        Public qCnt As UInteger
        Public pPrio As IntPtr
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Private Structure VkDevCI
        Public sType As UInteger
        Public pNext As IntPtr
        Public flags As UInteger
        Public qciCnt As UInteger
        Public pQCI As IntPtr
        Public lCnt As UInteger
        Public ppL As IntPtr
        Public eCnt As UInteger
        Public ppE As IntPtr
        Public pFeat As IntPtr
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Private Structure VkQFP
        Public qFlags As UInteger
        Public qCnt As UInteger
        Public tsVB As UInteger
        Public gW As UInteger
        Public gH As UInteger
        Public gD As UInteger
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Private Structure VkMemReq
        Public size As ULong
        Public align As ULong
        Public memBits As UInteger
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Private Structure VkMemAI
        Public sType As UInteger
        Public pNext As IntPtr
        Public size As ULong
        Public memIdx As UInteger
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Private Structure VkMemType
        Public propFlags As UInteger
        Public heapIdx As UInteger
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Private Structure VkPhysMemProps
        Public typeCnt As UInteger
        <MarshalAs(UnmanagedType.ByValArray, SizeConst:=256)>
        Public types As Byte()
        Public heapCnt As UInteger
        <MarshalAs(UnmanagedType.ByValArray, SizeConst:=256)>
        Public heaps As Byte()
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Private Structure VkImgCI
        Public sType As UInteger
        Public pNext As IntPtr
        Public flags As UInteger
        Public imgType As UInteger
        Public fmt As UInteger
        Public eW As UInteger
        Public eH As UInteger
        Public eD As UInteger
        Public mip As UInteger
        Public arr As UInteger
        Public samples As UInteger
        Public tiling As UInteger
        Public usage As UInteger
        Public sharing As UInteger
        Public qfCnt As UInteger
        Public pQF As IntPtr
        Public initLayout As UInteger
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Private Structure VkImgViewCI
        Public sType As UInteger
        Public pNext As IntPtr
        Public flags As UInteger
        Public img As ULong
        Public viewType As UInteger
        Public fmt As UInteger
        Public cR As UInteger
        Public cG As UInteger
        Public cB As UInteger
        Public cA As UInteger
        Public aspect As UInteger
        Public baseMip As UInteger
        Public lvlCnt As UInteger
        Public baseLayer As UInteger
        Public layerCnt As UInteger
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Private Structure VkBufCI
        Public sType As UInteger
        Public pNext As IntPtr
        Public flags As UInteger
        Public size As ULong
        Public usage As UInteger
        Public sharing As UInteger
        Public qfCnt As UInteger
        Public pQF As IntPtr
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Private Structure VkAttDesc
        Public flags As UInteger
        Public fmt As UInteger
        Public samples As UInteger
        Public loadOp As UInteger
        Public storeOp As UInteger
        Public stLoadOp As UInteger
        Public stStoreOp As UInteger
        Public initLayout As UInteger
        Public finalLayout As UInteger
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Private Structure VkAttRef
        Public att As UInteger
        Public layout As UInteger
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Private Structure VkSubDesc
        Public flags As UInteger
        Public bp As UInteger
        Public iaCnt As UInteger
        Public pIA As IntPtr
        Public caCnt As UInteger
        Public pCA As IntPtr
        Public pRA As IntPtr
        Public pDA As IntPtr
        Public paCnt As UInteger
        Public pPA As IntPtr
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Private Structure VkRPCI
        Public sType As UInteger
        Public pNext As IntPtr
        Public flags As UInteger
        Public attCnt As UInteger
        Public pAtts As IntPtr
        Public subCnt As UInteger
        Public pSubs As IntPtr
        Public depCnt As UInteger
        Public pDeps As IntPtr
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Private Structure VkFBCI
        Public sType As UInteger
        Public pNext As IntPtr
        Public flags As UInteger
        Public rp As ULong
        Public attCnt As UInteger
        Public pAtts As IntPtr
        Public w As UInteger
        Public h As UInteger
        Public layers As UInteger
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Private Structure VkSMCI
        Public sType As UInteger
        Public pNext As IntPtr
        Public flags As UInteger
        Public codeSz As UIntPtr
        Public pCode As IntPtr
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Private Structure VkPSSCI
        Public sType As UInteger
        Public pNext As IntPtr
        Public flags As UInteger
        Public stage As UInteger
        Public [module] As ULong
        Public pName As IntPtr
        Public pSpec As IntPtr
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Private Structure VkPVICI
        Public sType As UInteger
        Public pNext As IntPtr
        Public flags As UInteger
        Public vbdCnt As UInteger
        Public pVBD As IntPtr
        Public vadCnt As UInteger
        Public pVAD As IntPtr
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Private Structure VkPIACI
        Public sType As UInteger
        Public pNext As IntPtr
        Public flags As UInteger
        Public topo As UInteger
        Public primRestart As UInteger
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Private Structure VkViewport
        Public x As Single
        Public y As Single
        Public w As Single
        Public h As Single
        Public minD As Single
        Public maxD As Single
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Private Structure VkOff2D
        Public x As Integer
        Public y As Integer
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Private Structure VkExt2D
        Public w As UInteger
        Public h As UInteger
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Private Structure VkRect2D
        Public off As VkOff2D
        Public ext As VkExt2D
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Private Structure VkPVPCI
        Public sType As UInteger
        Public pNext As IntPtr
        Public flags As UInteger
        Public vpCnt As UInteger
        Public pVP As IntPtr
        Public scCnt As UInteger
        Public pSC As IntPtr
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Private Structure VkPRCI
        Public sType As UInteger
        Public pNext As IntPtr
        Public flags As UInteger
        Public depthClamp As UInteger
        Public rastDiscard As UInteger
        Public polyMode As UInteger
        Public cullMode As UInteger
        Public frontFace As UInteger
        Public depthBias As UInteger
        Public dbConst As Single
        Public dbClamp As Single
        Public dbSlope As Single
        Public lineW As Single
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Private Structure VkPMSCI
        Public sType As UInteger
        Public pNext As IntPtr
        Public flags As UInteger
        Public rSamples As UInteger
        Public sShading As UInteger
        Public minSS As Single
        Public pSM As IntPtr
        Public a2c As UInteger
        Public a2o As UInteger
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Private Structure VkPCBAS
        Public blendEn As UInteger
        Public sCBF As UInteger
        Public dCBF As UInteger
        Public cbOp As UInteger
        Public sABF As UInteger
        Public dABF As UInteger
        Public abOp As UInteger
        Public wMask As UInteger
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Private Structure VkPCBCI
        Public sType As UInteger
        Public pNext As IntPtr
        Public flags As UInteger
        Public logicOpEn As UInteger
        Public logicOp As UInteger
        Public attCnt As UInteger
        Public pAtts As IntPtr
        Public bc0 As Single
        Public bc1 As Single
        Public bc2 As Single
        Public bc3 As Single
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Private Structure VkPLCI
        Public sType As UInteger
        Public pNext As IntPtr
        Public flags As UInteger
        Public slCnt As UInteger
        Public pSL As IntPtr
        Public pcCnt As UInteger
        Public pPC As IntPtr
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Private Structure VkGPCI
        Public sType As UInteger
        Public pNext As IntPtr
        Public flags As UInteger
        Public stageCnt As UInteger
        Public pStages As IntPtr
        Public pVIS As IntPtr
        Public pIAS As IntPtr
        Public pTess As IntPtr
        Public pVPS As IntPtr
        Public pRast As IntPtr
        Public pMS As IntPtr
        Public pDS As IntPtr
        Public pCBS As IntPtr
        Public pDyn As IntPtr
        Public layout As ULong
        Public rp As ULong
        Public subpass As UInteger
        Public basePipe As ULong
        Public basePipeIdx As Integer
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Private Structure VkCPCI
        Public sType As UInteger
        Public pNext As IntPtr
        Public flags As UInteger
        Public qfi As UInteger
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Private Structure VkCBAI
        Public sType As UInteger
        Public pNext As IntPtr
        Public pool As IntPtr
        Public level As UInteger
        Public cnt As UInteger
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Private Structure VkCBBI
        Public sType As UInteger
        Public pNext As IntPtr
        Public flags As UInteger
        Public pInh As IntPtr
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Private Structure VkClearCol
        Public r As Single
        Public g As Single
        Public b As Single
        Public a As Single
    End Structure

    <StructLayout(LayoutKind.Explicit)>
    Private Structure VkClearVal
        <FieldOffset(0)>
        Public color As VkClearCol
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Private Structure VkRPBI
        Public sType As UInteger
        Public pNext As IntPtr
        Public rp As ULong
        Public fb As ULong
        Public area As VkRect2D
        Public cvCnt As UInteger
        Public pCV As IntPtr
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Private Structure VkFenceCI
        Public sType As UInteger
        Public pNext As IntPtr
        Public flags As UInteger
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Private Structure VkSubmitInfo
        Public sType As UInteger
        Public pNext As IntPtr
        Public wsCnt As UInteger
        Public pWS As IntPtr
        Public pWSM As IntPtr
        Public cbCnt As UInteger
        Public pCB As IntPtr
        Public ssCnt As UInteger
        Public pSS As IntPtr
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Private Structure VkBufImgCopy
        Public bufOff As ULong
        Public bRL As UInteger
        Public bIH As UInteger
        Public aspect As UInteger
        Public mip As UInteger
        Public baseL As UInteger
        Public lCnt As UInteger
        Public oX As Integer
        Public oY As Integer
        Public oZ As Integer
        Public eW As UInteger
        Public eH As UInteger
        Public eD As UInteger
    End Structure

    Private NotInheritable Class SC
        Private Const L As String = "shaderc_shared.dll"

        <DllImport(L, CallingConvention:=CallingConvention.Cdecl)>
        Private Shared Function shaderc_compiler_initialize() As IntPtr
        End Function

        <DllImport(L, CallingConvention:=CallingConvention.Cdecl)>
        Private Shared Sub shaderc_compiler_release(c As IntPtr)
        End Sub

        <DllImport(L, CallingConvention:=CallingConvention.Cdecl)>
        Private Shared Function shaderc_compile_options_initialize() As IntPtr
        End Function

        <DllImport(L, CallingConvention:=CallingConvention.Cdecl)>
        Private Shared Sub shaderc_compile_options_release(o As IntPtr)
        End Sub

        <DllImport(L, CallingConvention:=CallingConvention.Cdecl)>
        Private Shared Sub shaderc_compile_options_set_optimization_level(o As IntPtr, l As Integer)
        End Sub

        <DllImport(L, CallingConvention:=CallingConvention.Cdecl)>
        Private Shared Function shaderc_compile_into_spv(c As IntPtr, <MarshalAs(UnmanagedType.LPStr)> s As String, sz As UIntPtr, k As Integer, <MarshalAs(UnmanagedType.LPStr)> fn As String, <MarshalAs(UnmanagedType.LPStr)> ep As String, o As IntPtr) As IntPtr
        End Function

        <DllImport(L, CallingConvention:=CallingConvention.Cdecl)>
        Private Shared Function shaderc_result_get_compilation_status(r As IntPtr) As Integer
        End Function

        <DllImport(L, CallingConvention:=CallingConvention.Cdecl)>
        Private Shared Function shaderc_result_get_length(r As IntPtr) As UIntPtr
        End Function

        <DllImport(L, CallingConvention:=CallingConvention.Cdecl)>
        Private Shared Function shaderc_result_get_bytes(r As IntPtr) As IntPtr
        End Function

        <DllImport(L, CallingConvention:=CallingConvention.Cdecl)>
        Private Shared Function shaderc_result_get_error_message(r As IntPtr) As IntPtr
        End Function

        <DllImport(L, CallingConvention:=CallingConvention.Cdecl)>
        Private Shared Sub shaderc_result_release(r As IntPtr)
        End Sub

        Public Shared Function Compile(src As String, kind As Integer, fname As String) As Byte()
            Dim c As IntPtr = shaderc_compiler_initialize()
            Dim o As IntPtr = shaderc_compile_options_initialize()
            shaderc_compile_options_set_optimization_level(o, 2)
            Try
                Dim r As IntPtr = shaderc_compile_into_spv(c, src, CType(src.Length, UIntPtr), kind, fname, "main", o)
                If shaderc_result_get_compilation_status(r) <> 0 Then
                    Dim e As String = Marshal.PtrToStringAnsi(shaderc_result_get_error_message(r))
                    shaderc_result_release(r)
                    Throw New Exception("Shader: " & e)
                End If
                Dim len As Integer = CInt(shaderc_result_get_length(r).ToUInt64())
                Dim d(len - 1) As Byte
                Marshal.Copy(shaderc_result_get_bytes(r), d, 0, len)
                shaderc_result_release(r)
                Return d
            Finally
                shaderc_compile_options_release(o)
                shaderc_compiler_release(c)
            End Try
        End Function
    End Class

    <DllImport("user32.dll", EntryPoint:="RegisterClassExW", CharSet:=CharSet.Unicode, ExactSpelling:=True, SetLastError:=True)>
    Private Function RegisterClassEx(ByRef w As WNDCLASSEX) As UShort
    End Function

    <DllImport("user32.dll", EntryPoint:="CreateWindowExW", CharSet:=CharSet.Unicode, ExactSpelling:=True, SetLastError:=True)>
    Private Function CreateWindowEx(exStyle As UInteger, cls As String, ttl As String, st As UInteger, x As Integer, y As Integer, w As Integer, h As Integer, p As IntPtr, m As IntPtr, hi As IntPtr, lp As IntPtr) As IntPtr
    End Function

    <DllImport("user32.dll", EntryPoint:="SetWindowTextW", CharSet:=CharSet.Unicode, ExactSpelling:=True, SetLastError:=True)>
    Private Function SetWindowText(hWnd As IntPtr, lpString As String) As Boolean
    End Function

    <DllImport("user32.dll", EntryPoint:="GetWindowTextLengthW", ExactSpelling:=True, SetLastError:=True)>
    Private Function GetWindowTextLength(hWnd As IntPtr) As Integer
    End Function

    <DllImport("user32.dll", EntryPoint:="GetWindowTextW", CharSet:=CharSet.Unicode, ExactSpelling:=True, SetLastError:=True)>
    Private Function GetWindowText(hWnd As IntPtr, lpString As StringBuilder, nMaxCount As Integer) As Integer
    End Function

    <DllImport("user32.dll", EntryPoint:="PeekMessageW", ExactSpelling:=True)>
    Private Function PeekMessage(ByRef m As MSG, h As IntPtr, mn As UInteger, mx As UInteger, rm As UInteger) As Boolean
    End Function

    <DllImport("user32.dll")>
    Private Function TranslateMessage(ByRef m As MSG) As Boolean
    End Function

    <DllImport("user32.dll", EntryPoint:="DispatchMessageW", ExactSpelling:=True)>
    Private Function DispatchMessage(ByRef m As MSG) As IntPtr
    End Function

    <DllImport("user32.dll")>
    Private Sub PostQuitMessage(c As Integer)
    End Sub

    <DllImport("user32.dll", EntryPoint:="DefWindowProcW", ExactSpelling:=True)>
    Private Function DefWindowProc(h As IntPtr, m As UInteger, w As IntPtr, l As IntPtr) As IntPtr
    End Function

    <DllImport("user32.dll")>
    Private Function LoadCursor(h As IntPtr, c As Integer) As IntPtr
    End Function

    <DllImport("user32.dll")>
    Private Function GetDC(h As IntPtr) As IntPtr
    End Function

    <DllImport("user32.dll")>
    Private Function AdjustWindowRect(ByRef r As RECT, s As UInteger, m As Boolean) As Boolean
    End Function

    <DllImport("kernel32.dll", CharSet:=CharSet.Auto)>
    Private Function GetModuleHandle(n As String) As IntPtr
    End Function

    <DllImport("kernel32.dll", CharSet:=CharSet.Unicode)>
    Private Sub OutputDebugString(lpOutputString As String)
    End Sub

    <DllImport("kernel32.dll", EntryPoint:="RtlMoveMemory")>
    Private Sub CopyMemory(dest As IntPtr, src As IntPtr, length As IntPtr)
    End Sub

    <DllImport("gdi32.dll")>
    Private Function ChoosePixelFormat(h As IntPtr, ByRef p As PIXELFORMATDESCRIPTOR) As Integer
    End Function

    <DllImport("gdi32.dll")>
    Private Function SetPixelFormat(h As IntPtr, f As Integer, ByRef p As PIXELFORMATDESCRIPTOR) As Boolean
    End Function

    <DllImport("opengl32.dll")>
    Private Function wglCreateContext(h As IntPtr) As IntPtr
    End Function

    <DllImport("opengl32.dll")>
    Private Function wglMakeCurrent(h As IntPtr, g As IntPtr) As Integer
    End Function

    <DllImport("opengl32.dll")>
    Private Function wglDeleteContext(g As IntPtr) As Integer
    End Function

    <DllImport("opengl32.dll")>
    Private Function wglGetProcAddress(n As String) As IntPtr
    End Function

    <DllImport("opengl32.dll")>
    Private Sub glClearColor(r As Single, g As Single, b As Single, a As Single)
    End Sub

    <DllImport("opengl32.dll")>
    Private Sub glClear(m As UInteger)
    End Sub

    <DllImport("opengl32.dll")>
    Private Sub glViewport(x As Integer, y As Integer, w As Integer, h As Integer)
    End Sub

    <DllImport("opengl32.dll")>
    Private Sub glDrawArrays(m As UInteger, f As Integer, c As Integer)
    End Sub

    <DllImport("opengl32.dll")>
    Private Sub glFlush()
    End Sub

    <DllImport("d3d11.dll")>
    Private Function D3D11CreateDevice(a As IntPtr, dt As Integer, sw As IntPtr, fl As UInteger, lv As UInteger(), n As UInteger, sdk As UInteger, ByRef dev As IntPtr, ByRef flOut As UInteger, ByRef ctx As IntPtr) As Integer
    End Function

    <DllImport("dxgi.dll")>
    Private Function CreateDXGIFactory1(ByRef iid As Guid, ByRef fac As IntPtr) As Integer
    End Function

    <DllImport("d3dcompiler_47.dll")>
    Private Function D3DCompile(<MarshalAs(UnmanagedType.LPStr)> src As String, sz As IntPtr, <MarshalAs(UnmanagedType.LPStr)> nm As String, def As IntPtr, inc As IntPtr, <MarshalAs(UnmanagedType.LPStr)> ep As String, <MarshalAs(UnmanagedType.LPStr)> tgt As String, f1 As UInteger, f2 As UInteger, ByRef code As IntPtr, ByRef err As IntPtr) As Integer
    End Function

    <DllImport("CoreMessaging.dll")>
    Private Function CreateDispatcherQueueController(ByRef options As DispatcherQueueOptions, ByRef controller As IntPtr) As Integer
    End Function

    <DllImport("combase.dll", PreserveSig:=True)>
    Private Function RoInitialize(initType As Integer) As Integer
    End Function

    <DllImport("combase.dll", PreserveSig:=True)>
    Private Function RoActivateInstance(activatableClassId As IntPtr, ByRef instance As IntPtr) As Integer
    End Function

    <DllImport("combase.dll", PreserveSig:=True)>
    Private Function WindowsCreateString(<MarshalAs(UnmanagedType.LPWStr)> sourceString As String, length As UInteger, ByRef hstring As IntPtr) As Integer
    End Function

    <DllImport("combase.dll", PreserveSig:=True)>
    Private Function WindowsDeleteString(hstring As IntPtr) As Integer
    End Function

    <DllImport("vulkan-1.dll")>
    Private Function vkCreateInstance(ByRef ci As VkInstCI, a As IntPtr, ByRef i As IntPtr) As Integer
    End Function

    <DllImport("vulkan-1.dll")>
    Private Function vkEnumeratePhysicalDevices(i As IntPtr, ByRef c As UInteger, d As IntPtr()) As Integer
    End Function

    <DllImport("vulkan-1.dll")>
    Private Sub vkGetPhysicalDeviceQueueFamilyProperties(p As IntPtr, ByRef c As UInteger, <Out> q As VkQFP())
    End Sub

    <DllImport("vulkan-1.dll")>
    Private Function vkCreateDevice(p As IntPtr, ByRef ci As VkDevCI, a As IntPtr, ByRef d As IntPtr) As Integer
    End Function

    <DllImport("vulkan-1.dll")>
    Private Sub vkGetDeviceQueue(d As IntPtr, qf As UInteger, qi As UInteger, ByRef q As IntPtr)
    End Sub

    <DllImport("vulkan-1.dll")>
    Private Sub vkGetPhysicalDeviceMemoryProperties(p As IntPtr, ByRef m As VkPhysMemProps)
    End Sub

    <DllImport("vulkan-1.dll")>
    Private Function vkCreateImage(d As IntPtr, ByRef ci As VkImgCI, a As IntPtr, ByRef img As ULong) As Integer
    End Function

    <DllImport("vulkan-1.dll")>
    Private Sub vkGetImageMemoryRequirements(d As IntPtr, img As ULong, ByRef r As VkMemReq)
    End Sub

    <DllImport("vulkan-1.dll")>
    Private Function vkAllocateMemory(d As IntPtr, ByRef ai As VkMemAI, a As IntPtr, ByRef m As ULong) As Integer
    End Function

    <DllImport("vulkan-1.dll")>
    Private Function vkBindImageMemory(d As IntPtr, img As ULong, m As ULong, o As ULong) As Integer
    End Function

    <DllImport("vulkan-1.dll")>
    Private Function vkCreateImageView(d As IntPtr, ByRef ci As VkImgViewCI, a As IntPtr, ByRef v As ULong) As Integer
    End Function

    <DllImport("vulkan-1.dll")>
    Private Function vkCreateBuffer(d As IntPtr, ByRef ci As VkBufCI, a As IntPtr, ByRef b As ULong) As Integer
    End Function

    <DllImport("vulkan-1.dll")>
    Private Sub vkGetBufferMemoryRequirements(d As IntPtr, b As ULong, ByRef r As VkMemReq)
    End Sub

    <DllImport("vulkan-1.dll")>
    Private Function vkBindBufferMemory(d As IntPtr, b As ULong, m As ULong, o As ULong) As Integer
    End Function

    <DllImport("vulkan-1.dll")>
    Private Function vkCreateRenderPass(d As IntPtr, ByRef ci As VkRPCI, a As IntPtr, ByRef rp As ULong) As Integer
    End Function

    <DllImport("vulkan-1.dll")>
    Private Function vkCreateFramebuffer(d As IntPtr, ByRef ci As VkFBCI, a As IntPtr, ByRef fb As ULong) As Integer
    End Function

    <DllImport("vulkan-1.dll")>
    Private Function vkCreateShaderModule(d As IntPtr, ByRef ci As VkSMCI, a As IntPtr, ByRef sm As ULong) As Integer
    End Function

    <DllImport("vulkan-1.dll")>
    Private Sub vkDestroyShaderModule(d As IntPtr, sm As ULong, a As IntPtr)
    End Sub

    <DllImport("vulkan-1.dll")>
    Private Function vkCreatePipelineLayout(d As IntPtr, ByRef ci As VkPLCI, a As IntPtr, ByRef pl As ULong) As Integer
    End Function

    <DllImport("vulkan-1.dll")>
    Private Function vkCreateGraphicsPipelines(d As IntPtr, cache As ULong, n As UInteger, ByRef ci As VkGPCI, a As IntPtr, ByRef p As ULong) As Integer
    End Function

    <DllImport("vulkan-1.dll")>
    Private Function vkCreateCommandPool(d As IntPtr, ByRef ci As VkCPCI, a As IntPtr, ByRef p As IntPtr) As Integer
    End Function

    <DllImport("vulkan-1.dll")>
    Private Function vkAllocateCommandBuffers(d As IntPtr, ByRef ai As VkCBAI, ByRef cb As IntPtr) As Integer
    End Function

    <DllImport("vulkan-1.dll")>
    Private Function vkCreateFence(d As IntPtr, ByRef ci As VkFenceCI, a As IntPtr, ByRef f As ULong) As Integer
    End Function

    <DllImport("vulkan-1.dll")>
    Private Function vkWaitForFences(d As IntPtr, n As UInteger, f As ULong(), all As UInteger, t As ULong) As Integer
    End Function

    <DllImport("vulkan-1.dll")>
    Private Function vkResetFences(d As IntPtr, n As UInteger, f As ULong()) As Integer
    End Function

    <DllImport("vulkan-1.dll")>
    Private Function vkResetCommandBuffer(cb As IntPtr, f As UInteger) As Integer
    End Function

    <DllImport("vulkan-1.dll")>
    Private Function vkBeginCommandBuffer(cb As IntPtr, ByRef bi As VkCBBI) As Integer
    End Function

    <DllImport("vulkan-1.dll")>
    Private Function vkEndCommandBuffer(cb As IntPtr) As Integer
    End Function

    <DllImport("vulkan-1.dll")>
    Private Sub vkCmdBeginRenderPass(cb As IntPtr, ByRef rp As VkRPBI, c As UInteger)
    End Sub

    <DllImport("vulkan-1.dll")>
    Private Sub vkCmdEndRenderPass(cb As IntPtr)
    End Sub

    <DllImport("vulkan-1.dll")>
    Private Sub vkCmdBindPipeline(cb As IntPtr, bp As UInteger, p As ULong)
    End Sub

    <DllImport("vulkan-1.dll")>
    Private Sub vkCmdDraw(cb As IntPtr, vc As UInteger, ic As UInteger, fv As UInteger, fi As UInteger)
    End Sub

    <DllImport("vulkan-1.dll")>
    Private Sub vkCmdCopyImageToBuffer(cb As IntPtr, img As ULong, layout As UInteger, buf As ULong, n As UInteger, r As IntPtr)
    End Sub

    <DllImport("vulkan-1.dll")>
    Private Function vkQueueSubmit(q As IntPtr, n As UInteger, ByRef si As VkSubmitInfo, f As ULong) As Integer
    End Function

    <DllImport("vulkan-1.dll")>
    Private Function vkMapMemory(d As IntPtr, m As ULong, o As ULong, sz As ULong, f As UInteger, ByRef p As IntPtr) As Integer
    End Function

    <DllImport("vulkan-1.dll")>
    Private Sub vkUnmapMemory(d As IntPtr, m As ULong)
    End Sub

    <DllImport("vulkan-1.dll")>
    Private Function vkDeviceWaitIdle(d As IntPtr) As Integer
    End Function

    Private ReadOnly IID_F2 As New Guid("50c83a1c-e072-4c48-87b0-3630fa36a6d0")
    Private ReadOnly IID_DXGIDev As New Guid("54ec77fa-1377-44e6-8c32-88fd5f44c84c")
    Private ReadOnly IID_Tex2D As New Guid("6f15aaf2-d208-4e89-9ab4-489535d34f9c")
    Private ReadOnly IID_ICompositorDesktopInterop As New Guid("29E691FA-4567-4DCA-B319-D0F207EB6807")
    Private ReadOnly IID_ICompositorInterop As New Guid("25297D5C-3AD4-4C9C-B5CF-E36A38512330")
    Private ReadOnly IID_ICompositor As New Guid("B403CA50-7F8C-4E83-985F-CC45060036D8")
    Private ReadOnly IID_ICompositionTarget As New Guid("A1BEA8BA-D726-4663-8129-6B5E7927FFA6")
    Private ReadOnly IID_IContainerVisual As New Guid("02F6BC74-ED20-4773-AFE6-D49B4A93DB32")
    Private ReadOnly IID_IVisualCollection As New Guid("8B745505-FD3E-4A98-84A8-E949468C6BCB")
    Private ReadOnly IID_ISpriteVisual As New Guid("08E05581-1AD1-4F97-9757-402D76E4233B")
    Private ReadOnly IID_IVisual As New Guid("117E202D-A859-4C89-873B-C2AA566788E3")
    Private ReadOnly IID_ICompositionBrush As New Guid("AB0D7608-30C0-40E9-B568-B60A6BD1FB46")

    ' Writes timestamped messages to DebugView.
    Private Sub Dbg(msg As String)
        Try
            OutputDebugString("[VB.WinRT.Comp.Multi] " & DateTime.Now.ToString("HH:mm:ss.fff") & " " & msg)
        Catch
            ' Ignore logging failures to keep runtime flow stable.
        End Try
    End Sub

    Private Sub CheckHR(hr As Integer, op As String)
        If hr < 0 Then
            Throw New Exception(op & " failed with hr=0x" & hr.ToString("X8"))
        End If
    End Sub

    Private Function VT(p As IntPtr, i As Integer) As IntPtr
        Return Marshal.ReadIntPtr(Marshal.ReadIntPtr(p), i * IntPtr.Size)
    End Function

    Private Function QI(o As IntPtr, g As Guid, ByRef r As IntPtr) As Integer
        Dim f = CType(Marshal.GetDelegateForFunctionPointer(VT(o, 0), GetType(QIDelegate)), QIDelegate)
        Return f(o, g, r)
    End Function

    Private Sub Rel(o As IntPtr)
        If o <> IntPtr.Zero Then
            Marshal.Release(o)
        End If
    End Sub

    Private Function GetGL(Of T As Class)(n As String) As T
        Dim p As IntPtr = wglGetProcAddress(n)
        If p = IntPtr.Zero Then
            Throw New Exception("GL: " & n)
        End If
        Dim d As [Delegate] = Marshal.GetDelegateForFunctionPointer(p, GetType(T))
        Return CType(CType(d, Object), T)
    End Function

    Private _quit As Boolean
    Private _wpr As WndProcDelegate
    Private _hw As IntPtr
    Private _d3d As IntPtr
    Private _ctx As IntPtr
    Private _fac As IntPtr
    Private _dq As IntPtr
    Private _compUnk As IntPtr
    Private _comp As IntPtr
    Private _deskTarget As IntPtr
    Private _compTarget As IntPtr
    Private _rootContainer As IntPtr
    Private _rootVisual As IntPtr
    Private _children As IntPtr
    Private _spriteRaw(2) As IntPtr
    Private _spriteVisual(2) As IntPtr
    Private _brush(2) As IntPtr

    Private Function WP(h As IntPtr, m As UInteger, w As IntPtr, l As IntPtr) As IntPtr
        If m = WM_CLOSE OrElse m = WM_DEST Then
            Dbg("Window close message received: 0x" & m.ToString("X"))
            _quit = True
            PostQuitMessage(0)
            Return IntPtr.Zero
        End If
        If m = WM_KEY AndAlso w.ToInt32() = VK_ESC Then
            Dbg("ESC pressed, quitting")
            _quit = True
            PostQuitMessage(0)
            Return IntPtr.Zero
        End If
        Return DefWindowProc(h, m, w, l)
    End Function

    Private Sub MakeWin()
        Dbg("MakeWin: begin")
        Const WINDOW_TITLE As String = "OpenGL + D3D11 + Vulkan via Windows.UI.Composition (VB.NET)"
        Dim hi As IntPtr = GetModuleHandle(Nothing)
        _wpr = AddressOf WP

        Dim wc As New WNDCLASSEX With {
            .cbSize = CUInt(Marshal.SizeOf(GetType(WNDCLASSEX))),
            .style = CS_OWN,
            .lpfnWndProc = _wpr,
            .hInstance = hi,
            .hCursor = LoadCursor(IntPtr.Zero, 32512),
            .lpszClassName = "DCMulti"
        }
        Dim atom As UShort = RegisterClassEx(wc)
        If atom = 0US Then
            Dbg("RegisterClassEx returned 0")
        End If

        Dim rc As New RECT With {.Right = PW * 3, .Bottom = PH}
        AdjustWindowRect(rc, WS_OVR, False)

        _hw = CreateWindowEx(
            0UI,
            "DCMulti",
            WINDOW_TITLE,
            WS_OVR Or WS_VIS,
            100,
            100,
            rc.Right - rc.Left,
            rc.Bottom - rc.Top,
            IntPtr.Zero,
            IntPtr.Zero,
            hi,
            IntPtr.Zero)

        If _hw = IntPtr.Zero Then
            Throw New Exception("CreateWindowEx failed")
        End If

        Dim okTitle As Boolean = SetWindowText(_hw, WINDOW_TITLE)
        Dbg("SetWindowTextW: ok=" & okTitle.ToString())

        Dim titleLen As Integer = GetWindowTextLength(_hw)
        Dim sb As New StringBuilder(Math.Max(titleLen + 1, 260))
        GetWindowText(_hw, sb, sb.Capacity)
        Dbg("Window title now: [" & sb.ToString() & "]")

        Dbg("MakeWin: hwnd=0x" & _hw.ToInt64().ToString("X"))
    End Sub

    Private Sub MakeD3D()
        Dbg("MakeD3D: begin")
        Dim lv() As UInteger = {D3D_FL11}
        Dim fl As UInteger
        Dim hr As Integer = D3D11CreateDevice(IntPtr.Zero, 1, IntPtr.Zero, D3D_BGRA, lv, 1UI, D3D_SDK, _d3d, fl, _ctx)
        CheckHR(hr, "D3D11CreateDevice")
        Dbg("MakeD3D: device=0x" & _d3d.ToInt64().ToString("X") & ", context=0x" & _ctx.ToInt64().ToString("X"))
    End Sub

    Private Sub MakeFac()
        Dbg("MakeFac: begin")
        Dim g As New Guid("770aae78-f26f-4dba-a829-253c83d1b387")
        Dim f1 As IntPtr = IntPtr.Zero
        CheckHR(CreateDXGIFactory1(g, f1), "CreateDXGIFactory1")
        CheckHR(QI(f1, IID_F2, _fac), "QI IDXGIFactory2")
        Rel(f1)
        Dbg("MakeFac: factory2=0x" & _fac.ToInt64().ToString("X"))
    End Sub

    Private Sub AddCompositionPanel(sc As IntPtr, offsetX As Single, index As Integer)
        Dim compInterop As IntPtr = IntPtr.Zero
        Dim surface As IntPtr = IntPtr.Zero
        Dim surfBrush As IntPtr = IntPtr.Zero

        CheckHR(QI(_compUnk, IID_ICompositorInterop, compInterop), "QI(ICompositorInterop)")
        CheckHR(CType(Marshal.GetDelegateForFunctionPointer(VT(compInterop, 4), GetType(CreateCompSurfaceForSCDelegate)), CreateCompSurfaceForSCDelegate)(compInterop, sc, surface), "CreateCompositionSurfaceForSwapChain")
        Rel(compInterop)

        CheckHR(CType(Marshal.GetDelegateForFunctionPointer(VT(_comp, 24), GetType(CreateSurfaceBrushWithSurfaceDelegate)), CreateSurfaceBrushWithSurfaceDelegate)(_comp, surface, surfBrush), "CreateSurfaceBrush")
        Rel(surface)
        CheckHR(QI(surfBrush, IID_ICompositionBrush, _brush(index)), "QI(ICompositionBrush)")
        Rel(surfBrush)

        CheckHR(CType(Marshal.GetDelegateForFunctionPointer(VT(_comp, 22), GetType(CreateSpriteVisualDelegate)), CreateSpriteVisualDelegate)(_comp, _spriteRaw(index)), "CreateSpriteVisual")
        CheckHR(CType(Marshal.GetDelegateForFunctionPointer(VT(_spriteRaw(index), 7), GetType(PutBrushDelegate)), PutBrushDelegate)(_spriteRaw(index), _brush(index)), "put_Brush")
        CheckHR(QI(_spriteRaw(index), IID_IVisual, _spriteVisual(index)), "QI(IVisual sprite)")
        CheckHR(CType(Marshal.GetDelegateForFunctionPointer(VT(_spriteVisual(index), 36), GetType(PutSizeDelegate)), PutSizeDelegate)(_spriteVisual(index), New Float2 With {.X = PW, .Y = PH}), "put_Size")
        CheckHR(CType(Marshal.GetDelegateForFunctionPointer(VT(_spriteVisual(index), 21), GetType(PutOffsetDelegate)), PutOffsetDelegate)(_spriteVisual(index), New Float3 With {.X = offsetX, .Y = 0.0F, .Z = 0.0F}), "put_Offset")
        CheckHR(CType(Marshal.GetDelegateForFunctionPointer(VT(_children, 9), GetType(InsertAtTopDelegate)), InsertAtTopDelegate)(_children, _spriteVisual(index)), "InsertAtTop")
    End Sub

    Private Sub InitComposition()
        Dbg("InitComposition: begin")

        Dim hr As Integer = RoInitialize(0)
        If hr < 0 AndAlso hr <> 1 Then
            CheckHR(hr, "RoInitialize")
        End If

        Dim dqOpt As New DispatcherQueueOptions With {
            .dwSize = Marshal.SizeOf(GetType(DispatcherQueueOptions)),
            .threadType = 2,
            .apartmentType = 0
        }
        CheckHR(CreateDispatcherQueueController(dqOpt, _dq), "CreateDispatcherQueueController")

        Dim className As String = "Windows.UI.Composition.Compositor"
        Dim hstr As IntPtr = IntPtr.Zero
        CheckHR(WindowsCreateString(className, CUInt(className.Length), hstr), "WindowsCreateString")
        Try
            CheckHR(RoActivateInstance(hstr, _compUnk), "RoActivateInstance")
        Finally
            WindowsDeleteString(hstr)
        End Try

        CheckHR(QI(_compUnk, IID_ICompositor, _comp), "QI(ICompositor)")

        Dim deskInterop As IntPtr = IntPtr.Zero
        CheckHR(QI(_compUnk, IID_ICompositorDesktopInterop, deskInterop), "QI(ICompositorDesktopInterop)")
        Try
            CheckHR(CType(Marshal.GetDelegateForFunctionPointer(VT(deskInterop, 3), GetType(CreateDesktopWindowTargetDelegate)), CreateDesktopWindowTargetDelegate)(deskInterop, _hw, 0, _deskTarget), "CreateDesktopWindowTarget")
        Finally
            Rel(deskInterop)
        End Try

        CheckHR(QI(_deskTarget, IID_ICompositionTarget, _compTarget), "QI(ICompositionTarget)")
        CheckHR(CType(Marshal.GetDelegateForFunctionPointer(VT(_comp, 9), GetType(CreateContainerVisualDelegate)), CreateContainerVisualDelegate)(_comp, _rootContainer), "CreateContainerVisual")
        CheckHR(QI(_rootContainer, IID_IVisual, _rootVisual), "QI(IVisual root)")
        CheckHR(CType(Marshal.GetDelegateForFunctionPointer(VT(_compTarget, 7), GetType(PutRootDelegate)), PutRootDelegate)(_compTarget, _rootVisual), "put_Root")
        CheckHR(CType(Marshal.GetDelegateForFunctionPointer(VT(_rootContainer, 6), GetType(GetChildrenDelegate)), GetChildrenDelegate)(_rootContainer, _children), "get_Children")

        AddCompositionPanel(_glSC, 0.0F, 0)
        AddCompositionPanel(_dxSC, CSng(PW), 1)
        AddCompositionPanel(_vSC, CSng(PW * 2), 2)
        Dbg("InitComposition: ok")
    End Sub

    Private Function MakeSC(w As Integer, h As Integer) As IntPtr
        Dim d As New DXGI_SWAP_CHAIN_DESC1 With {
            .Width = CUInt(w),
            .Height = CUInt(h),
            .Format = DXGI_B8,
            .SampleDesc = New DXGI_SAMPLE_DESC With {.Count = 1UI},
            .BufferUsage = DXGI_USAGE_RTO,
            .BufferCount = 2UI,
            .Scaling = DXGI_SCALING_STRETCH,
            .SwapEffect = DXGI_FLIP_DISCARD,
            .AlphaMode = DXGI_ALPHA_IGNORE,
            .Flags = 0UI
        }
        Dim sc As IntPtr = IntPtr.Zero
        Dim hr As Integer = CType(Marshal.GetDelegateForFunctionPointer(VT(_fac, 24), GetType(CreateSCCompDelegate)), CreateSCCompDelegate)(_fac, _d3d, d, IntPtr.Zero, sc)
        CheckHR(hr, "CreateSwapChainForComposition")
        Return sc
    End Function

    Private Function SCBuf(sc As IntPtr) As IntPtr
        Dim t As IntPtr = IntPtr.Zero
        Dim g As Guid = IID_Tex2D
        Dim hr As Integer = CType(Marshal.GetDelegateForFunctionPointer(VT(sc, 9), GetType(GetBufDelegate)), GetBufDelegate)(sc, 0UI, g, t)
        CheckHR(hr, "IDXGISwapChain.GetBuffer")
        Return t
    End Function

    Private Sub SCPres(sc As IntPtr)
        CType(Marshal.GetDelegateForFunctionPointer(VT(sc, 8), GetType(PresentDelegate)), PresentDelegate)(sc, 1UI, 0UI)
    End Sub

    Private Function MakeRTV(t As IntPtr) As IntPtr
        Dim r As IntPtr = IntPtr.Zero
        CType(Marshal.GetDelegateForFunctionPointer(VT(_d3d, 9), GetType(CreateRTVDelegate)), CreateRTVDelegate)(_d3d, t, IntPtr.Zero, r)
        Return r
    End Function

    Private Function MakeStagTex(w As Integer, h As Integer) As IntPtr
        Dim d As New D3D11_TEXTURE2D_DESC With {
            .Width = CUInt(w),
            .Height = CUInt(h),
            .MipLevels = 1UI,
            .ArraySize = 1UI,
            .Format = DXGI_B8,
            .SampleDesc = New DXGI_SAMPLE_DESC With {.Count = 1UI},
            .Usage = D3D_STAGING,
            .CPUAccessFlags = D3D_CPU_W
        }
        Dim t As IntPtr = IntPtr.Zero
        CType(Marshal.GetDelegateForFunctionPointer(VT(_d3d, 5), GetType(CreateTex2DDelegate)), CreateTex2DDelegate)(_d3d, d, IntPtr.Zero, t)
        Return t
    End Function

    Private Sub ClearRTV(r As IntPtr, cr As Single, cg As Single, cb As Single, ca As Single)
        CType(Marshal.GetDelegateForFunctionPointer(VT(_ctx, 50), GetType(ClearRTVDelegate)), ClearRTVDelegate)(_ctx, r, New Single() {cr, cg, cb, ca})
    End Sub

    Private Sub CopyRes(d As IntPtr, s As IntPtr)
        CType(Marshal.GetDelegateForFunctionPointer(VT(_ctx, 47), GetType(CopyResDelegate)), CopyResDelegate)(_ctx, d, s)
    End Sub

    Private Function MapW(r As IntPtr) As D3D11_MAPPED_SUBRESOURCE
        Dim m As D3D11_MAPPED_SUBRESOURCE
        CType(Marshal.GetDelegateForFunctionPointer(VT(_ctx, 14), GetType(MapDelegate)), MapDelegate)(_ctx, r, 0UI, D3D_MAP_W, 0UI, m)
        Return m
    End Function

    Private Sub Unmap(r As IntPtr)
        CType(Marshal.GetDelegateForFunctionPointer(VT(_ctx, 15), GetType(UnmapDelegate)), UnmapDelegate)(_ctx, r, 0UI)
    End Sub

    Private _dxSC As IntPtr
    Private _dxBB As IntPtr
    Private _dxRTV As IntPtr
    Private _dxVB As IntPtr
    Private _dxVS As IntPtr
    Private _dxPS As IntPtr
    Private _dxIL As IntPtr

    Private ReadOnly HLSL As String =
        "struct VSI{float3 p:POSITION;float4 c:COLOR;};" & vbLf &
        "struct PSI{float4 p:SV_POSITION;float4 c:COLOR;};" & vbLf &
        "PSI VS(VSI i){PSI o;o.p=float4(i.p,1);o.c=i.c;return o;}" & vbLf &
        "float4 PS(PSI i):SV_Target{return i.c;}" & vbLf

    Private Sub InitDX()
        Dbg("InitDX: begin")
        _dxSC = MakeSC(PW, PH)
        _dxBB = SCBuf(_dxSC)
        _dxRTV = MakeRTV(_dxBB)

        Dim vb As IntPtr = IntPtr.Zero
        Dim pb As IntPtr = IntPtr.Zero
        Dim err As IntPtr = IntPtr.Zero
        D3DCompile(HLSL, CType(HLSL.Length, IntPtr), "dx", IntPtr.Zero, IntPtr.Zero, "VS", "vs_4_0", 0UI, 0UI, vb, err)
        D3DCompile(HLSL, CType(HLSL.Length, IntPtr), "dx", IntPtr.Zero, IntPtr.Zero, "PS", "ps_4_0", 0UI, 0UI, pb, err)

        Dim vP As IntPtr = CType(Marshal.GetDelegateForFunctionPointer(VT(vb, 3), GetType(BlobPtrDelegate)), BlobPtrDelegate)(vb)
        Dim vSize As IntPtr = CType(Marshal.GetDelegateForFunctionPointer(VT(vb, 4), GetType(BlobSzDelegate)), BlobSzDelegate)(vb)
        Dim pP As IntPtr = CType(Marshal.GetDelegateForFunctionPointer(VT(pb, 3), GetType(BlobPtrDelegate)), BlobPtrDelegate)(pb)
        Dim pSize As IntPtr = CType(Marshal.GetDelegateForFunctionPointer(VT(pb, 4), GetType(BlobSzDelegate)), BlobSzDelegate)(pb)

        CType(Marshal.GetDelegateForFunctionPointer(VT(_d3d, 12), GetType(CreateVSDelegate)), CreateVSDelegate)(_d3d, vP, vSize, IntPtr.Zero, _dxVS)
        CType(Marshal.GetDelegateForFunctionPointer(VT(_d3d, 15), GetType(CreatePSDelegate)), CreatePSDelegate)(_d3d, pP, pSize, IntPtr.Zero, _dxPS)

        Dim el() As D3D11_INPUT_ELEMENT_DESC = {
            New D3D11_INPUT_ELEMENT_DESC With {.SemanticName = "POSITION", .Format = DXGI_R32G32B32, .AlignedByteOffset = 0UI},
            New D3D11_INPUT_ELEMENT_DESC With {.SemanticName = "COLOR", .Format = DXGI_R32G32B32A32, .AlignedByteOffset = 12UI}
        }
        CType(Marshal.GetDelegateForFunctionPointer(VT(_d3d, 11), GetType(CreateILDelegate)), CreateILDelegate)(_d3d, el, 2UI, vP, vSize, _dxIL)
        Rel(vb)
        Rel(pb)

        Dim vs() As DxVertex = {
            New DxVertex With {.X = 0.0F, .Y = 0.5F, .Z = 0.0F, .R = 1.0F, .G = 0.0F, .B = 0.0F, .A = 1.0F},
            New DxVertex With {.X = 0.5F, .Y = -0.5F, .Z = 0.0F, .R = 0.0F, .G = 1.0F, .B = 0.0F, .A = 1.0F},
            New DxVertex With {.X = -0.5F, .Y = -0.5F, .Z = 0.0F, .R = 0.0F, .G = 0.0F, .B = 1.0F, .A = 1.0F}
        }

        Dim hV As GCHandle = GCHandle.Alloc(vs, GCHandleType.Pinned)
        Dim bd As New D3D11_BUFFER_DESC With {
            .ByteWidth = CUInt(Marshal.SizeOf(GetType(DxVertex)) * 3),
            .BindFlags = D3D_BIND_VB
        }
        Dim sd As New D3D11_SUBRESOURCE_DATA With {.pSysMem = hV.AddrOfPinnedObject()}
        CType(Marshal.GetDelegateForFunctionPointer(VT(_d3d, 3), GetType(CreateBufferDelegate)), CreateBufferDelegate)(_d3d, bd, sd, _dxVB)
        hV.Free()

        Console.WriteLine("[D3D11] OK")
        Dbg("InitDX: done")
    End Sub

    Private Sub RenderDX()
        ClearRTV(_dxRTV, 0.05F, 0.15F, 0.05F, 1.0F)

        CType(Marshal.GetDelegateForFunctionPointer(VT(_ctx, 33), GetType(OMSetRTDelegate)), OMSetRTDelegate)(_ctx, 1UI, New IntPtr() {_dxRTV}, IntPtr.Zero)

        Dim vp As New D3D11_VIEWPORT With {.Width = PW, .Height = PH, .MaxDepth = 1.0F}
        CType(Marshal.GetDelegateForFunctionPointer(VT(_ctx, 44), GetType(RSSetVPDelegate)), RSSetVPDelegate)(_ctx, 1UI, vp)

        CType(Marshal.GetDelegateForFunctionPointer(VT(_ctx, 17), GetType(IASetILDelegate)), IASetILDelegate)(_ctx, _dxIL)
        CType(Marshal.GetDelegateForFunctionPointer(VT(_ctx, 18), GetType(IASetVBDelegate)), IASetVBDelegate)(_ctx, 0UI, 1UI, New IntPtr() {_dxVB}, New UInteger() {CUInt(Marshal.SizeOf(GetType(DxVertex)))}, New UInteger() {0UI})
        CType(Marshal.GetDelegateForFunctionPointer(VT(_ctx, 24), GetType(IASetTopoDelegate)), IASetTopoDelegate)(_ctx, D3D_TOPO_TRI)

        CType(Marshal.GetDelegateForFunctionPointer(VT(_ctx, 11), GetType(VSSetDelegate)), VSSetDelegate)(_ctx, _dxVS, Nothing, 0UI)
        CType(Marshal.GetDelegateForFunctionPointer(VT(_ctx, 9), GetType(PSSetDelegate)), PSSetDelegate)(_ctx, _dxPS, Nothing, 0UI)
        CType(Marshal.GetDelegateForFunctionPointer(VT(_ctx, 13), GetType(DrawDelegate)), DrawDelegate)(_ctx, 3UI, 0UI)

        SCPres(_dxSC)
    End Sub

    Private _glSC As IntPtr
    Private _glBB As IntPtr
    Private _glHDC As IntPtr
    Private _glHRC As IntPtr
    Private _glID As IntPtr
    Private _glIO As IntPtr

    Private _glFBO As UInteger
    Private _glRBO As UInteger
    Private _glProg As UInteger
    Private _glPA As UInteger
    Private _glCA As UInteger
    Private _glVBO(1) As UInteger

    Private gGB As glGenBuffersD
    Private gBB As glBindBufferD
    Private gBD As glBufferDataD
    Private gCS As glCreateShaderD
    Private gSS As glShaderSourceD
    Private gCoS As glCompileShaderD
    Private gCP As glCreateProgramD
    Private gAS As glAttachShaderD
    Private gLP As glLinkProgramD
    Private gUP As glUseProgramD
    Private gGA As glGetAttribLocationD
    Private gEV As glEnableVAD
    Private gVAP As glVertexAttribPointerD
    Private gGF As glGenFBD
    Private gBF As glBindFBD
    Private gFR As glFBRBD
    Private gGR As glGenRBD
    Private gGV As glGenVAOD
    Private gBV As glBindVAOD
    Private gDL As wglDXLockD
    Private gDU As wglDXUnlockD

    Private Sub InitGL()
        Dbg("InitGL: begin")
        _glHDC = GetDC(_hw)

        Dim pfd As New PIXELFORMATDESCRIPTOR With {
            .nSize = CUShort(Marshal.SizeOf(GetType(PIXELFORMATDESCRIPTOR))),
            .nVersion = 1US,
            .dwFlags = &H25UI,
            .cColorBits = 32
        }
        Dim fmt As Integer = ChoosePixelFormat(_glHDC, pfd)
        SetPixelFormat(_glHDC, fmt, pfd)

        Dim tmp As IntPtr = wglCreateContext(_glHDC)
        wglMakeCurrent(_glHDC, tmp)

        _glHRC = GetGL(Of wglCreateCtxARBD)("wglCreateContextAttribsARB")(_glHDC, IntPtr.Zero, Nothing)
        wglMakeCurrent(_glHDC, _glHRC)
        wglDeleteContext(tmp)

        gGB = GetGL(Of glGenBuffersD)("glGenBuffers")
        gBB = GetGL(Of glBindBufferD)("glBindBuffer")
        gBD = GetGL(Of glBufferDataD)("glBufferData")
        gCS = GetGL(Of glCreateShaderD)("glCreateShader")
        gSS = GetGL(Of glShaderSourceD)("glShaderSource")
        gCoS = GetGL(Of glCompileShaderD)("glCompileShader")
        gCP = GetGL(Of glCreateProgramD)("glCreateProgram")
        gAS = GetGL(Of glAttachShaderD)("glAttachShader")
        gLP = GetGL(Of glLinkProgramD)("glLinkProgram")
        gUP = GetGL(Of glUseProgramD)("glUseProgram")
        gGA = GetGL(Of glGetAttribLocationD)("glGetAttribLocation")
        gEV = GetGL(Of glEnableVAD)("glEnableVertexAttribArray")
        gVAP = GetGL(Of glVertexAttribPointerD)("glVertexAttribPointer")
        gGF = GetGL(Of glGenFBD)("glGenFramebuffers")
        gBF = GetGL(Of glBindFBD)("glBindFramebuffer")
        gFR = GetGL(Of glFBRBD)("glFramebufferRenderbuffer")
        gGR = GetGL(Of glGenRBD)("glGenRenderbuffers")
        gGV = GetGL(Of glGenVAOD)("glGenVertexArrays")
        gBV = GetGL(Of glBindVAOD)("glBindVertexArray")

        Dim dxO = GetGL(Of wglDXOpenD)("wglDXOpenDeviceNV")
        Dim dxR = GetGL(Of wglDXRegD)("wglDXRegisterObjectNV")
        gDL = GetGL(Of wglDXLockD)("wglDXLockObjectsNV")
        gDU = GetGL(Of wglDXUnlockD)("wglDXUnlockObjectsNV")

        _glSC = MakeSC(PW, PH)
        _glBB = SCBuf(_glSC)

        _glID = dxO(_d3d)
        If _glID = IntPtr.Zero Then
            Throw New Exception("wglDXOpenDeviceNV")
        End If

        Dim rb(0) As UInteger
        gGR(1, rb)
        _glRBO = rb(0)

        _glIO = dxR(_glID, _glBB, _glRBO, GL_RB, WGL_RW)
        If _glIO = IntPtr.Zero Then
            Throw New Exception("wglDXRegisterObjectNV")
        End If

        Dim fb(0) As UInteger
        gGF(1, fb)
        _glFBO = fb(0)
        gBF(GL_FB, _glFBO)
        gFR(GL_FB, GL_CA0, GL_RB, _glRBO)
        gBF(GL_FB, 0UI)

        Dim va(0) As UInteger
        gGV(1, va)
        gBV(va(0))
        gGB(2, _glVBO)

        Dim vt() As Single = {0.0F, 0.5F, 0.0F, 0.5F, -0.5F, 0.0F, -0.5F, -0.5F, 0.0F}
        Dim cl() As Single = {1.0F, 0.0F, 0.0F, 0.0F, 1.0F, 0.0F, 0.0F, 0.0F, 1.0F}

        gBB(GL_ABuf, _glVBO(0))
        gBD(GL_ABuf, vt.Length * 4, vt, GL_STATIC)
        gBB(GL_ABuf, _glVBO(1))
        gBD(GL_ABuf, cl.Length * 4, cl, GL_STATIC)

        Dim vs As String =
            "#version 460 core" & vbLf &
            "layout(location=0) in vec3 pos;layout(location=1) in vec3 col;" & vbLf &
            "out vec4 vC;" & vbLf &
            "void main(){vC=vec4(col,1);gl_Position=vec4(pos.x,-pos.y,pos.z,1);}" & vbLf

        Dim fs As String =
            "#version 460 core" & vbLf &
            "in vec4 vC;out vec4 oC;" & vbLf &
            "void main(){oC=vC;}" & vbLf

        Dim v As UInteger = gCS(GL_VS)
        gSS(v, 1, New String() {vs}, Nothing)
        gCoS(v)

        Dim f As UInteger = gCS(GL_FS)
        gSS(f, 1, New String() {fs}, Nothing)
        gCoS(f)

        _glProg = gCP()
        gAS(_glProg, v)
        gAS(_glProg, f)
        gLP(_glProg)
        gUP(_glProg)

        _glPA = gGA(_glProg, "pos")
        _glCA = gGA(_glProg, "col")
        gEV(_glPA)
        gEV(_glCA)

        Console.WriteLine("[GL] OK")
        Dbg("InitGL: done")
    End Sub

    Private Sub RenderGL()
        wglMakeCurrent(_glHDC, _glHRC)

        Dim o() As IntPtr = {_glIO}
        gDL(_glID, 1, o)

        gBF(GL_FB, _glFBO)
        glViewport(0, 0, PW, PH)
        glClearColor(0.05F, 0.05F, 0.15F, 1.0F)
        glClear(GL_COLBIT)

        gUP(_glProg)
        gBB(GL_ABuf, _glVBO(0))
        gVAP(_glPA, 3, GL_FLT, False, 0, IntPtr.Zero)
        gBB(GL_ABuf, _glVBO(1))
        gVAP(_glCA, 3, GL_FLT, False, 0, IntPtr.Zero)

        glDrawArrays(GL_TRI, 0, 3)
        gBF(GL_FB, 0UI)
        glFlush()

        gDU(_glID, 1, o)
        SCPres(_glSC)
    End Sub

    Private _vSC As IntPtr
    Private _vBB As IntPtr
    Private _vST As IntPtr
    Private _vI As IntPtr
    Private _vPD As IntPtr
    Private _vD As IntPtr
    Private _vQ As IntPtr
    Private _vCP As IntPtr
    Private _vCB As IntPtr

    Private _vOI As ULong
    Private _vOV As ULong
    Private _vOM As ULong
    Private _vSB As ULong
    Private _vSM2 As ULong
    Private _vRP As ULong
    Private _vFB2 As ULong
    Private _vPL As ULong
    Private _vPP As ULong
    Private _vFN As ULong

    Private _vQF As Integer

    Private Function FindMT(ByRef p As VkPhysMemProps, bits As UInteger, req As UInteger) As UInteger
        For i As UInteger = 0UI To p.typeCnt - 1UI
            If (bits And (1UI << CInt(i))) <> 0UI Then
                Dim mtOff As Integer = CInt(i) * Marshal.SizeOf(GetType(VkMemType))
                Dim flags As UInteger = BitConverter.ToUInt32(p.types, mtOff)
                If (flags And req) = req Then
                    Return i
                End If
            End If
        Next
        Throw New Exception("No VK mem type")
    End Function

    Private Sub InitVK()
        Dbg("InitVK: begin")
        Dim an As IntPtr = Marshal.StringToHGlobalAnsi("vk")
        Dim ai As New VkAppInfo With {.sType = 0UI, .pAppName = an, .apiVer = (1UI << 22)}
        Dim hAI As GCHandle = GCHandle.Alloc(ai, GCHandleType.Pinned)

        Dim ici As New VkInstCI With {.sType = 1UI, .pAppInfo = hAI.AddrOfPinnedObject()}
        vkCreateInstance(ici, IntPtr.Zero, _vI)
        hAI.Free()
        Marshal.FreeHGlobal(an)

        Dim cnt As UInteger = 0UI
        vkEnumeratePhysicalDevices(_vI, cnt, Nothing)

        Dim ds(CInt(cnt) - 1) As IntPtr
        vkEnumeratePhysicalDevices(_vI, cnt, ds)
        _vPD = ds(0)
        _vQF = -1

        Dim qc As UInteger = 0UI
        vkGetPhysicalDeviceQueueFamilyProperties(_vPD, qc, Nothing)
        Dim qp(CInt(qc) - 1) As VkQFP
        vkGetPhysicalDeviceQueueFamilyProperties(_vPD, qc, qp)

        For i As Integer = 0 To CInt(qc) - 1
            If (qp(i).qFlags And 1UI) <> 0UI Then
                _vQF = i
                Exit For
            End If
        Next

        Dim hP As GCHandle = GCHandle.Alloc(New Single() {1.0F}, GCHandleType.Pinned)
        Dim qci As New VkDevQCI With {
            .sType = 2UI,
            .qfi = CUInt(_vQF),
            .qCnt = 1UI,
            .pPrio = hP.AddrOfPinnedObject()
        }
        Dim hQ As GCHandle = GCHandle.Alloc(qci, GCHandleType.Pinned)

        Dim dci As New VkDevCI With {.sType = 3UI, .qciCnt = 1UI, .pQCI = hQ.AddrOfPinnedObject()}
        vkCreateDevice(_vPD, dci, IntPtr.Zero, _vD)
        hQ.Free()
        hP.Free()

        vkGetDeviceQueue(_vD, CUInt(_vQF), 0UI, _vQ)

        Dim mp As New VkPhysMemProps With {.types = New Byte(255) {}, .heaps = New Byte(255) {}}
        vkGetPhysicalDeviceMemoryProperties(_vPD, mp)

        Dim ic As New VkImgCI With {
            .sType = 14UI,
            .imgType = 1UI,
            .fmt = 44UI,
            .eW = CUInt(PW),
            .eH = CUInt(PH),
            .eD = 1UI,
            .mip = 1UI,
            .arr = 1UI,
            .samples = 1UI,
            .usage = &H11UI
        }
        vkCreateImage(_vD, ic, IntPtr.Zero, _vOI)

        Dim ir As VkMemReq
        vkGetImageMemoryRequirements(_vD, _vOI, ir)
        Dim ia2 As New VkMemAI With {.sType = 5UI, .size = ir.size, .memIdx = FindMT(mp, ir.memBits, 1UI)}
        vkAllocateMemory(_vD, ia2, IntPtr.Zero, _vOM)
        vkBindImageMemory(_vD, _vOI, _vOM, 0UL)

        Dim ivc As New VkImgViewCI With {
            .sType = 15UI,
            .img = _vOI,
            .viewType = 1UI,
            .fmt = 44UI,
            .aspect = 1UI,
            .lvlCnt = 1UI,
            .layerCnt = 1UI
        }
        vkCreateImageView(_vD, ivc, IntPtr.Zero, _vOV)

        Dim bsz As ULong = CULng(PW * PH * 4)
        Dim bc As New VkBufCI With {.sType = 12UI, .size = bsz, .usage = 2UI}
        vkCreateBuffer(_vD, bc, IntPtr.Zero, _vSB)

        Dim br As VkMemReq
        vkGetBufferMemoryRequirements(_vD, _vSB, br)
        Dim ba As New VkMemAI With {.sType = 5UI, .size = br.size, .memIdx = FindMT(mp, br.memBits, 6UI)}
        vkAllocateMemory(_vD, ba, IntPtr.Zero, _vSM2)
        vkBindBufferMemory(_vD, _vSB, _vSM2, 0UL)

        Dim att As New VkAttDesc With {.fmt = 44UI, .samples = 1UI, .loadOp = 1UI, .storeOp = 0UI, .stLoadOp = 2UI, .stStoreOp = 1UI, .finalLayout = 6UI}
        Dim ar As New VkAttRef With {.att = 0UI, .layout = 2UI}

        Dim hA As GCHandle = GCHandle.Alloc(att, GCHandleType.Pinned)
        Dim hR As GCHandle = GCHandle.Alloc(ar, GCHandleType.Pinned)
        Dim sd As New VkSubDesc With {.caCnt = 1UI, .pCA = hR.AddrOfPinnedObject()}
        Dim hS As GCHandle = GCHandle.Alloc(sd, GCHandleType.Pinned)

        Dim rpc As New VkRPCI With {.sType = 38UI, .attCnt = 1UI, .pAtts = hA.AddrOfPinnedObject(), .subCnt = 1UI, .pSubs = hS.AddrOfPinnedObject()}
        vkCreateRenderPass(_vD, rpc, IntPtr.Zero, _vRP)
        hA.Free()
        hR.Free()
        hS.Free()

        Dim attachments() As ULong = {_vOV}
        Dim hV As GCHandle = GCHandle.Alloc(attachments, GCHandleType.Pinned)
        Dim fbc As New VkFBCI With {.sType = 37UI, .rp = _vRP, .attCnt = 1UI, .pAtts = hV.AddrOfPinnedObject(), .w = CUInt(PW), .h = CUInt(PH), .layers = 1UI}
        vkCreateFramebuffer(_vD, fbc, IntPtr.Zero, _vFB2)
        hV.Free()

        Dim vSpv() As Byte = SC.Compile(File.ReadAllText("hello.vert"), 0, "hello.vert")
        Dim fSpv() As Byte = SC.Compile(File.ReadAllText("hello.frag"), 1, "hello.frag")

        Dim vsm As ULong
        Dim fsm As ULong

        Dim hvSpv As GCHandle = GCHandle.Alloc(vSpv, GCHandleType.Pinned)
        Dim vsmci As New VkSMCI With {.sType = 16UI, .codeSz = CType(vSpv.Length, UIntPtr), .pCode = hvSpv.AddrOfPinnedObject()}
        vkCreateShaderModule(_vD, vsmci, IntPtr.Zero, vsm)
        hvSpv.Free()

        Dim hfSpv As GCHandle = GCHandle.Alloc(fSpv, GCHandleType.Pinned)
        Dim fsmci As New VkSMCI With {.sType = 16UI, .codeSz = CType(fSpv.Length, UIntPtr), .pCode = hfSpv.AddrOfPinnedObject()}
        vkCreateShaderModule(_vD, fsmci, IntPtr.Zero, fsm)
        hfSpv.Free()

        Dim ms As IntPtr = Marshal.StringToHGlobalAnsi("main")
        Dim stg() As VkPSSCI = {
            New VkPSSCI With {.sType = 18UI, .stage = 1UI, .module = vsm, .pName = ms},
            New VkPSSCI With {.sType = 18UI, .stage = &H10UI, .module = fsm, .pName = ms}
        }

        Dim hStg As GCHandle = GCHandle.Alloc(stg, GCHandleType.Pinned)
        Dim vi As New VkPVICI With {.sType = 19UI}
        Dim ias As New VkPIACI With {.sType = 20UI, .topo = 3UI}
        Dim vp As New VkViewport With {.w = PW, .h = PH, .maxD = 1.0F}
        Dim sc2 As New VkRect2D With {.ext = New VkExt2D With {.w = CUInt(PW), .h = CUInt(PH)}}

        Dim hVP As GCHandle = GCHandle.Alloc(vp, GCHandleType.Pinned)
        Dim hSC As GCHandle = GCHandle.Alloc(sc2, GCHandleType.Pinned)
        Dim vps As New VkPVPCI With {.sType = 22UI, .vpCnt = 1UI, .pVP = hVP.AddrOfPinnedObject(), .scCnt = 1UI, .pSC = hSC.AddrOfPinnedObject()}
        Dim rs As New VkPRCI With {.sType = 23UI, .lineW = 1.0F}
        Dim mss As New VkPMSCI With {.sType = 24UI, .rSamples = 1UI}
        Dim cba As New VkPCBAS With {.wMask = &HFUI}

        Dim hCBA As GCHandle = GCHandle.Alloc(cba, GCHandleType.Pinned)
        Dim cbs As New VkPCBCI With {
            .sType = 26UI,
            .attCnt = 1UI,
            .pAtts = hCBA.AddrOfPinnedObject(),
            .bc0 = 0.0F,
            .bc1 = 0.0F,
            .bc2 = 0.0F,
            .bc3 = 0.0F
        }

        Dim hVI As GCHandle = GCHandle.Alloc(vi, GCHandleType.Pinned)
        Dim hIA As GCHandle = GCHandle.Alloc(ias, GCHandleType.Pinned)
        Dim hVPS As GCHandle = GCHandle.Alloc(vps, GCHandleType.Pinned)
        Dim hRS As GCHandle = GCHandle.Alloc(rs, GCHandleType.Pinned)
        Dim hMS As GCHandle = GCHandle.Alloc(mss, GCHandleType.Pinned)
        Dim hCB As GCHandle = GCHandle.Alloc(cbs, GCHandleType.Pinned)

        Dim plc As New VkPLCI With {.sType = 30UI}
        vkCreatePipelineLayout(_vD, plc, IntPtr.Zero, _vPL)

        Dim gpc As New VkGPCI With {
            .sType = 28UI,
            .stageCnt = 2UI,
            .pStages = hStg.AddrOfPinnedObject(),
            .pVIS = hVI.AddrOfPinnedObject(),
            .pIAS = hIA.AddrOfPinnedObject(),
            .pVPS = hVPS.AddrOfPinnedObject(),
            .pRast = hRS.AddrOfPinnedObject(),
            .pMS = hMS.AddrOfPinnedObject(),
            .pCBS = hCB.AddrOfPinnedObject(),
            .layout = _vPL,
            .rp = _vRP
        }
        vkCreateGraphicsPipelines(_vD, 0UL, 1UI, gpc, IntPtr.Zero, _vPP)

        hStg.Free()
        hVI.Free()
        hIA.Free()
        hVPS.Free()
        hRS.Free()
        hMS.Free()
        hCB.Free()
        hCBA.Free()
        hVP.Free()
        hSC.Free()

        Marshal.FreeHGlobal(ms)
        vkDestroyShaderModule(_vD, vsm, IntPtr.Zero)
        vkDestroyShaderModule(_vD, fsm, IntPtr.Zero)

        Dim cpc As New VkCPCI With {.sType = 39UI, .flags = 2UI, .qfi = CUInt(_vQF)}
        vkCreateCommandPool(_vD, cpc, IntPtr.Zero, _vCP)

        Dim cbi As New VkCBAI With {.sType = 40UI, .pool = _vCP, .cnt = 1UI}
        vkAllocateCommandBuffers(_vD, cbi, _vCB)

        Dim fc As New VkFenceCI With {.sType = 8UI, .flags = 1UI}
        vkCreateFence(_vD, fc, IntPtr.Zero, _vFN)

        _vSC = MakeSC(PW, PH)
        _vBB = SCBuf(_vSC)
        _vST = MakeStagTex(PW, PH)

        Console.WriteLine("[VK] OK")
        Dbg("InitVK: done")
    End Sub

    Private Sub RenderVK()
        Dim fn() As ULong = {_vFN}
        vkWaitForFences(_vD, 1UI, fn, 1UI, ULong.MaxValue)
        vkResetFences(_vD, 1UI, fn)
        vkResetCommandBuffer(_vCB, 0UI)

        Dim bi As New VkCBBI With {.sType = 42UI}
        vkBeginCommandBuffer(_vCB, bi)

        Dim cv As New VkClearVal With {.color = New VkClearCol With {.r = 0.15F, .g = 0.05F, .b = 0.05F, .a = 1.0F}}
        Dim hCV As GCHandle = GCHandle.Alloc(cv, GCHandleType.Pinned)

        Dim rpbi As New VkRPBI With {
            .sType = 43UI,
            .rp = _vRP,
            .fb = _vFB2,
            .area = New VkRect2D With {.ext = New VkExt2D With {.w = CUInt(PW), .h = CUInt(PH)}},
            .cvCnt = 1UI,
            .pCV = hCV.AddrOfPinnedObject()
        }

        vkCmdBeginRenderPass(_vCB, rpbi, 0UI)
        vkCmdBindPipeline(_vCB, 0UI, _vPP)
        vkCmdDraw(_vCB, 3UI, 1UI, 0UI, 0UI)
        vkCmdEndRenderPass(_vCB)
        hCV.Free()

        Dim rg As New VkBufImgCopy With {
            .bRL = CUInt(PW),
            .bIH = CUInt(PH),
            .aspect = 1UI,
            .lCnt = 1UI,
            .eW = CUInt(PW),
            .eH = CUInt(PH),
            .eD = 1UI
        }
        Dim hRG As GCHandle = GCHandle.Alloc(rg, GCHandleType.Pinned)
        vkCmdCopyImageToBuffer(_vCB, _vOI, 6UI, _vSB, 1UI, hRG.AddrOfPinnedObject())
        hRG.Free()

        vkEndCommandBuffer(_vCB)

        Dim cbs() As IntPtr = {_vCB}
        Dim hC As GCHandle = GCHandle.Alloc(cbs, GCHandleType.Pinned)
        Dim si As New VkSubmitInfo With {.sType = 4UI, .cbCnt = 1UI, .pCB = hC.AddrOfPinnedObject()}
        vkQueueSubmit(_vQ, 1UI, si, _vFN)
        hC.Free()

        vkWaitForFences(_vD, 1UI, fn, 1UI, ULong.MaxValue)

        Dim vd As IntPtr = IntPtr.Zero
        vkMapMemory(_vD, _vSM2, 0UL, CULng(PW * PH * 4), 0UI, vd)

        Dim m As D3D11_MAPPED_SUBRESOURCE = MapW(_vST)
        Dim pitch As Integer = PW * 4
        For y As Integer = 0 To PH - 1
            Dim src As IntPtr = IntPtr.Add(vd, y * pitch)
            Dim dst As IntPtr = IntPtr.Add(m.pData, y * CInt(m.RowPitch))
            CopyMemory(dst, src, CType(pitch, IntPtr))
        Next

        Unmap(_vST)
        vkUnmapMemory(_vD, _vSM2)

        CopyRes(_vBB, _vST)
        SCPres(_vSC)
    End Sub

    <STAThread>
    Public Sub Main()
        Try
            Dbg("=== START ===")
            Console.WriteLine("=== GL + D3D11 + VK via Windows.UI.Composition (VB.NET) ===")

            Dbg("Phase: MakeWin")
            MakeWin()
            Dbg("Phase: MakeD3D")
            MakeD3D()
            Dbg("Phase: MakeFac")
            MakeFac()

            Dbg("Phase: InitGL")
            Console.WriteLine("--- GL ---")
            InitGL()

            Dbg("Phase: InitDX")
            Console.WriteLine("--- D3D11 ---")
            InitDX()

            Dbg("Phase: InitVK")
            Console.WriteLine("--- VK ---")
            InitVK()

            Dbg("Phase: InitComposition")
            InitComposition()
            Console.WriteLine("Main loop...")
            Dbg("Entering main loop")

            Dim first As Boolean = True
            Dim msg As MSG

            While Not _quit
                While PeekMessage(msg, IntPtr.Zero, 0UI, 0UI, PM_REM)
                    If msg.message = WM_QUIT Then
                        Dbg("WM_QUIT received")
                        _quit = True
                        Exit While
                    End If
                    TranslateMessage(msg)
                    DispatchMessage(msg)
                End While

                If _quit Then
                    Exit While
                End If

                RenderGL()
                RenderDX()
                RenderVK()

                If first Then
                    Console.WriteLine("First frame OK")
                    Dbg("First frame rendered")
                    first = False
                End If
                Thread.Sleep(1)
            End While

            If _vD <> IntPtr.Zero Then
                vkDeviceWaitIdle(_vD)
            End If
            Console.WriteLine("=== END ===")
            Dbg("=== END ===")
        Catch ex As Exception
            Dbg("EXCEPTION: " & ex.ToString())
            Throw
        End Try
    End Sub
End Module
