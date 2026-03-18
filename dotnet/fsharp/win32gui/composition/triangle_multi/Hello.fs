// Hello.fs
// OpenGL 4.6 + DirectX 11 + Vulkan 1.4 triangles composited via DirectComposition
// Compile: fsc /target:winexe Hello.fs

open System
open System.IO
open System.Runtime.InteropServices
open System.Threading

[<Struct; StructLayout(LayoutKind.Sequential)>]
type POINT =
    val mutable X: int
    val mutable Y: int

[<Struct; StructLayout(LayoutKind.Sequential)>]
type RECT =
    val mutable Left: int
    val mutable Top: int
    val mutable Right: int
    val mutable Bottom: int

[<Struct; StructLayout(LayoutKind.Sequential)>]
type MSG =
    val mutable hwnd: nativeint
    val mutable message: uint32
    val mutable wParam: nativeint
    val mutable lParam: nativeint
    val mutable time: uint32
    val mutable pt: POINT

type WndProcDelegate = delegate of nativeint * uint32 * nativeint * nativeint -> nativeint

[<Struct; StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)>]
type WNDCLASSEX =
    val mutable cbSize: uint32
    val mutable style: uint32
    val mutable lpfnWndProc: WndProcDelegate
    val mutable cbClsExtra: int
    val mutable cbWndExtra: int
    val mutable hInstance: nativeint
    val mutable hIcon: nativeint
    val mutable hCursor: nativeint
    val mutable hbrBackground: nativeint
    val mutable lpszMenuName: string
    val mutable lpszClassName: string
    val mutable hIconSm: nativeint

[<Struct; StructLayout(LayoutKind.Sequential)>]
type PIXELFORMATDESCRIPTOR =
    val mutable nSize: uint16
    val mutable nVersion: uint16
    val mutable dwFlags: uint32
    val mutable iPixelType: byte
    val mutable cColorBits: byte
    val mutable cRedBits: byte
    val mutable cRedShift: byte
    val mutable cGreenBits: byte
    val mutable cGreenShift: byte
    val mutable cBlueBits: byte
    val mutable cBlueShift: byte
    val mutable cAlphaBits: byte
    val mutable cAlphaShift: byte
    val mutable cAccumBits: byte
    val mutable cAccumRedBits: byte
    val mutable cAccumGreenBits: byte
    val mutable cAccumBlueBits: byte
    val mutable cAccumAlphaBits: byte
    val mutable cDepthBits: byte
    val mutable cStencilBits: byte
    val mutable cAuxBuffers: byte
    val mutable iLayerType: byte
    val mutable bReserved: byte
    val mutable dwLayerMask: uint32
    val mutable dwVisibleMask: uint32
    val mutable dwDamageMask: uint32

[<Struct; StructLayout(LayoutKind.Sequential)>]
type DXGI_SAMPLE_DESC =
    val mutable Count: uint32
    val mutable Quality: uint32

[<Struct; StructLayout(LayoutKind.Sequential)>]
type DXGI_SWAP_CHAIN_DESC1 =
    val mutable Width: uint32
    val mutable Height: uint32
    val mutable Format: uint32
    [<MarshalAs(UnmanagedType.Bool)>]
    val mutable Stereo: bool
    val mutable SampleDesc: DXGI_SAMPLE_DESC
    val mutable BufferUsage: uint32
    val mutable BufferCount: uint32
    val mutable Scaling: uint32
    val mutable SwapEffect: uint32
    val mutable AlphaMode: uint32
    val mutable Flags: uint32

[<Struct; StructLayout(LayoutKind.Sequential)>]
type D3D11_TEXTURE2D_DESC =
    val mutable Width: uint32
    val mutable Height: uint32
    val mutable MipLevels: uint32
    val mutable ArraySize: uint32
    val mutable Format: uint32
    val mutable SampleDesc: DXGI_SAMPLE_DESC
    val mutable Usage: uint32
    val mutable BindFlags: uint32
    val mutable CPUAccessFlags: uint32
    val mutable MiscFlags: uint32

[<Struct; StructLayout(LayoutKind.Sequential)>]
type D3D11_MAPPED_SUBRESOURCE =
    val mutable pData: nativeint
    val mutable RowPitch: uint32
    val mutable DepthPitch: uint32

[<Struct; StructLayout(LayoutKind.Sequential)>]
type D3D11_BUFFER_DESC =
    val mutable ByteWidth: uint32
    val mutable Usage: uint32
    val mutable BindFlags: uint32
    val mutable CPUAccessFlags: uint32
    val mutable MiscFlags: uint32
    val mutable StructureByteStride: uint32

[<Struct; StructLayout(LayoutKind.Sequential)>]
type D3D11_SUBRESOURCE_DATA =
    val mutable pSysMem: nativeint
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

[<Struct; StructLayout(LayoutKind.Sequential)>]
type DxVertex =
    val mutable X: float32
    val mutable Y: float32
    val mutable Z: float32
    val mutable R: float32
    val mutable G: float32
    val mutable B: float32
    val mutable A: float32

[<UnmanagedFunctionPointer(CallingConvention.StdCall)>]
type QIDelegate = delegate of nativeint * Guid byref * nativeint byref -> int

[<UnmanagedFunctionPointer(CallingConvention.StdCall)>]
type CreateRTVDelegate = delegate of nativeint * nativeint * nativeint * nativeint byref -> int

[<UnmanagedFunctionPointer(CallingConvention.StdCall)>]
type CreateBufferDelegate = delegate of nativeint * D3D11_BUFFER_DESC byref * D3D11_SUBRESOURCE_DATA byref * nativeint byref -> int

[<UnmanagedFunctionPointer(CallingConvention.StdCall)>]
type CreateTex2DDelegate = delegate of nativeint * D3D11_TEXTURE2D_DESC byref * nativeint * nativeint byref -> int

[<UnmanagedFunctionPointer(CallingConvention.StdCall)>]
type CreateVSDelegate = delegate of nativeint * nativeint * nativeint * nativeint * nativeint byref -> int

[<UnmanagedFunctionPointer(CallingConvention.StdCall)>]
type CreatePSDelegate = delegate of nativeint * nativeint * nativeint * nativeint * nativeint byref -> int

[<UnmanagedFunctionPointer(CallingConvention.StdCall)>]
type CreateILDelegate = delegate of nativeint * D3D11_INPUT_ELEMENT_DESC[] * uint32 * nativeint * nativeint * nativeint byref -> int

[<UnmanagedFunctionPointer(CallingConvention.StdCall)>]
type PSSetDelegate = delegate of nativeint * nativeint * nativeint[] * uint32 -> unit

[<UnmanagedFunctionPointer(CallingConvention.StdCall)>]
type VSSetDelegate = delegate of nativeint * nativeint * nativeint[] * uint32 -> unit

[<UnmanagedFunctionPointer(CallingConvention.StdCall)>]
type DrawDelegate = delegate of nativeint * uint32 * uint32 -> unit

[<UnmanagedFunctionPointer(CallingConvention.StdCall)>]
type MapDelegate = delegate of nativeint * nativeint * uint32 * uint32 * uint32 * D3D11_MAPPED_SUBRESOURCE byref -> int

[<UnmanagedFunctionPointer(CallingConvention.StdCall)>]
type UnmapDelegate = delegate of nativeint * nativeint * uint32 -> unit

[<UnmanagedFunctionPointer(CallingConvention.StdCall)>]
type IASetILDelegate = delegate of nativeint * nativeint -> unit

[<UnmanagedFunctionPointer(CallingConvention.StdCall)>]
type IASetVBDelegate = delegate of nativeint * uint32 * uint32 * nativeint[] * uint32[] * uint32[] -> unit

[<UnmanagedFunctionPointer(CallingConvention.StdCall)>]
type IASetTopoDelegate = delegate of nativeint * uint32 -> unit

[<UnmanagedFunctionPointer(CallingConvention.StdCall)>]
type OMSetRTDelegate = delegate of nativeint * uint32 * nativeint[] * nativeint -> unit

[<UnmanagedFunctionPointer(CallingConvention.StdCall)>]
type RSSetVPDelegate = delegate of nativeint * uint32 * D3D11_VIEWPORT byref -> unit

[<UnmanagedFunctionPointer(CallingConvention.StdCall)>]
type CopyResDelegate = delegate of nativeint * nativeint * nativeint -> unit

[<UnmanagedFunctionPointer(CallingConvention.StdCall)>]
type ClearRTVDelegate = delegate of nativeint * nativeint * float32[] -> unit

[<UnmanagedFunctionPointer(CallingConvention.StdCall)>]
type PresentDelegate = delegate of nativeint * uint32 * uint32 -> int

[<UnmanagedFunctionPointer(CallingConvention.StdCall)>]
type GetBufDelegate = delegate of nativeint * uint32 * Guid byref * nativeint byref -> int

[<UnmanagedFunctionPointer(CallingConvention.StdCall)>]
type CreateSCCompDelegate = delegate of nativeint * nativeint * DXGI_SWAP_CHAIN_DESC1 byref * nativeint * nativeint byref -> int

[<UnmanagedFunctionPointer(CallingConvention.StdCall)>]
type BlobPtrDelegate = delegate of nativeint -> nativeint

[<UnmanagedFunctionPointer(CallingConvention.StdCall)>]
type BlobSzDelegate = delegate of nativeint -> nativeint

[<UnmanagedFunctionPointer(CallingConvention.StdCall)>]
type DCCommitDelegate = delegate of nativeint -> int

[<UnmanagedFunctionPointer(CallingConvention.StdCall)>]
type DCCreateTargetDelegate = delegate of nativeint * nativeint * int * nativeint byref -> int

[<UnmanagedFunctionPointer(CallingConvention.StdCall)>]
type DCCreateVisDelegate = delegate of nativeint * nativeint byref -> int

[<UnmanagedFunctionPointer(CallingConvention.StdCall)>]
type DCSetRootDelegate = delegate of nativeint * nativeint -> int

[<UnmanagedFunctionPointer(CallingConvention.StdCall)>]
type DCSetOffXDelegate = delegate of nativeint * float32 -> int

[<UnmanagedFunctionPointer(CallingConvention.StdCall)>]
type DCSetOffYDelegate = delegate of nativeint * float32 -> int

[<UnmanagedFunctionPointer(CallingConvention.StdCall)>]
type DCSetContentDelegate = delegate of nativeint * nativeint -> int

[<UnmanagedFunctionPointer(CallingConvention.StdCall)>]
type DCAddVisDelegate = delegate of nativeint * nativeint * int * nativeint -> int

type glGenBuffersD = delegate of int * uint32[] -> unit
type glBindBufferD = delegate of uint32 * uint32 -> unit
type glBufferDataD = delegate of uint32 * int * float32[] * uint32 -> unit
type glCreateShaderD = delegate of uint32 -> uint32
type glShaderSourceD = delegate of uint32 * int * string[] * int[] -> unit
type glCompileShaderD = delegate of uint32 -> unit
type glCreateProgramD = delegate of unit -> uint32
type glAttachShaderD = delegate of uint32 * uint32 -> unit
type glLinkProgramD = delegate of uint32 -> unit
type glUseProgramD = delegate of uint32 -> unit
type glGetAttribLocationD = delegate of uint32 * string -> uint32
type glEnableVAD = delegate of uint32 -> unit
type glVertexAttribPointerD = delegate of uint32 * int * uint32 * bool * int * nativeint -> unit
type glGenFBD = delegate of int * uint32[] -> unit
type glBindFBD = delegate of uint32 * uint32 -> unit
type glFBRBD = delegate of uint32 * uint32 * uint32 * uint32 -> unit
type glGenRBD = delegate of int * uint32[] -> unit
type glGenVAOD = delegate of int * uint32[] -> unit
type glBindVAOD = delegate of uint32 -> unit
type wglCreateCtxARBD = delegate of nativeint * nativeint * int[] -> nativeint
type wglDXOpenD = delegate of nativeint -> nativeint
type wglDXRegD = delegate of nativeint * nativeint * uint32 * uint32 * uint32 -> nativeint
type wglDXLockD = delegate of nativeint * int * nativeint[] -> int
type wglDXUnlockD = delegate of nativeint * int * nativeint[] -> int

[<Struct; StructLayout(LayoutKind.Sequential)>]
type VkAppInfo =
    val mutable sType: uint32
    val mutable pNext: nativeint
    val mutable pAppName: nativeint
    val mutable appVer: uint32
    val mutable pEngName: nativeint
    val mutable engVer: uint32
    val mutable apiVer: uint32

[<Struct; StructLayout(LayoutKind.Sequential)>]
type VkInstCI =
    val mutable sType: uint32
    val mutable pNext: nativeint
    val mutable flags: uint32
    val mutable pAppInfo: nativeint
    val mutable lCnt: uint32
    val mutable ppL: nativeint
    val mutable eCnt: uint32
    val mutable ppE: nativeint

[<Struct; StructLayout(LayoutKind.Sequential)>]
type VkDevQCI =
    val mutable sType: uint32
    val mutable pNext: nativeint
    val mutable flags: uint32
    val mutable qfi: uint32
    val mutable qCnt: uint32
    val mutable pPrio: nativeint

[<Struct; StructLayout(LayoutKind.Sequential)>]
type VkDevCI =
    val mutable sType: uint32
    val mutable pNext: nativeint
    val mutable flags: uint32
    val mutable qciCnt: uint32
    val mutable pQCI: nativeint
    val mutable lCnt: uint32
    val mutable ppL: nativeint
    val mutable eCnt: uint32
    val mutable ppE: nativeint
    val mutable pFeat: nativeint

[<Struct; StructLayout(LayoutKind.Sequential)>]
type VkQFP =
    val mutable qFlags: uint32
    val mutable qCnt: uint32
    val mutable tsVB: uint32
    val mutable gW: uint32
    val mutable gH: uint32
    val mutable gD: uint32

[<Struct; StructLayout(LayoutKind.Sequential)>]
type VkMemReq =
    val mutable size: uint64
    val mutable align: uint64
    val mutable memBits: uint32

[<Struct; StructLayout(LayoutKind.Sequential)>]
type VkMemAI =
    val mutable sType: uint32
    val mutable pNext: nativeint
    val mutable size: uint64
    val mutable memIdx: uint32

[<Struct; StructLayout(LayoutKind.Sequential)>]
type VkMemType =
    val mutable propFlags: uint32
    val mutable heapIdx: uint32

[<Struct; StructLayout(LayoutKind.Sequential)>]
type VkPhysMemProps =
    val mutable typeCnt: uint32
    [<MarshalAs(UnmanagedType.ByValArray, SizeConst = 256)>]
    val mutable types: byte[]
    val mutable heapCnt: uint32
    [<MarshalAs(UnmanagedType.ByValArray, SizeConst = 256)>]
    val mutable heaps: byte[]

[<Struct; StructLayout(LayoutKind.Sequential)>]
type VkImgCI =
    val mutable sType: uint32
    val mutable pNext: nativeint
    val mutable flags: uint32
    val mutable imgType: uint32
    val mutable fmt: uint32
    val mutable eW: uint32
    val mutable eH: uint32
    val mutable eD: uint32
    val mutable mip: uint32
    val mutable arr: uint32
    val mutable samples: uint32
    val mutable tiling: uint32
    val mutable usage: uint32
    val mutable sharing: uint32
    val mutable qfCnt: uint32
    val mutable pQF: nativeint
    val mutable initLayout: uint32

[<Struct; StructLayout(LayoutKind.Sequential)>]
type VkImgViewCI =
    val mutable sType: uint32
    val mutable pNext: nativeint
    val mutable flags: uint32
    val mutable img: uint64
    val mutable viewType: uint32
    val mutable fmt: uint32
    val mutable cR: uint32
    val mutable cG: uint32
    val mutable cB: uint32
    val mutable cA: uint32
    val mutable aspect: uint32
    val mutable baseMip: uint32
    val mutable lvlCnt: uint32
    val mutable baseLayer: uint32
    val mutable layerCnt: uint32

[<Struct; StructLayout(LayoutKind.Sequential)>]
type VkBufCI =
    val mutable sType: uint32
    val mutable pNext: nativeint
    val mutable flags: uint32
    val mutable size: uint64
    val mutable usage: uint32
    val mutable sharing: uint32
    val mutable qfCnt: uint32
    val mutable pQF: nativeint

[<Struct; StructLayout(LayoutKind.Sequential)>]
type VkAttDesc =
    val mutable flags: uint32
    val mutable fmt: uint32
    val mutable samples: uint32
    val mutable loadOp: uint32
    val mutable storeOp: uint32
    val mutable stLoadOp: uint32
    val mutable stStoreOp: uint32
    val mutable initLayout: uint32
    val mutable finalLayout: uint32

[<Struct; StructLayout(LayoutKind.Sequential)>]
type VkAttRef =
    val mutable att: uint32
    val mutable layout: uint32

[<Struct; StructLayout(LayoutKind.Sequential)>]
type VkSubDesc =
    val mutable flags: uint32
    val mutable bp: uint32
    val mutable iaCnt: uint32
    val mutable pIA: nativeint
    val mutable caCnt: uint32
    val mutable pCA: nativeint
    val mutable pRA: nativeint
    val mutable pDA: nativeint
    val mutable paCnt: uint32
    val mutable pPA: nativeint

[<Struct; StructLayout(LayoutKind.Sequential)>]
type VkRPCI =
    val mutable sType: uint32
    val mutable pNext: nativeint
    val mutable flags: uint32
    val mutable attCnt: uint32
    val mutable pAtts: nativeint
    val mutable subCnt: uint32
    val mutable pSubs: nativeint
    val mutable depCnt: uint32
    val mutable pDeps: nativeint

[<Struct; StructLayout(LayoutKind.Sequential)>]
type VkFBCI =
    val mutable sType: uint32
    val mutable pNext: nativeint
    val mutable flags: uint32
    val mutable rp: uint64
    val mutable attCnt: uint32
    val mutable pAtts: nativeint
    val mutable w: uint32
    val mutable h: uint32
    val mutable layers: uint32

[<Struct; StructLayout(LayoutKind.Sequential)>]
type VkSMCI =
    val mutable sType: uint32
    val mutable pNext: nativeint
    val mutable flags: uint32
    val mutable codeSz: unativeint
    val mutable pCode: nativeint

[<Struct; StructLayout(LayoutKind.Sequential)>]
type VkPSSCI =
    val mutable sType: uint32
    val mutable pNext: nativeint
    val mutable flags: uint32
    val mutable stage: uint32
    val mutable ``module``: uint64
    val mutable pName: nativeint
    val mutable pSpec: nativeint

[<Struct; StructLayout(LayoutKind.Sequential)>]
type VkPVICI =
    val mutable sType: uint32
    val mutable pNext: nativeint
    val mutable flags: uint32
    val mutable vbdCnt: uint32
    val mutable pVBD: nativeint
    val mutable vadCnt: uint32
    val mutable pVAD: nativeint

[<Struct; StructLayout(LayoutKind.Sequential)>]
type VkPIACI =
    val mutable sType: uint32
    val mutable pNext: nativeint
    val mutable flags: uint32
    val mutable topo: uint32
    val mutable primRestart: uint32

[<Struct; StructLayout(LayoutKind.Sequential)>]
type VkViewport =
    val mutable x: float32
    val mutable y: float32
    val mutable w: float32
    val mutable h: float32
    val mutable minD: float32
    val mutable maxD: float32

[<Struct; StructLayout(LayoutKind.Sequential)>]
type VkOff2D =
    val mutable x: int
    val mutable y: int

[<Struct; StructLayout(LayoutKind.Sequential)>]
type VkExt2D =
    val mutable w: uint32
    val mutable h: uint32

[<Struct; StructLayout(LayoutKind.Sequential)>]
type VkRect2D =
    val mutable off: VkOff2D
    val mutable ext: VkExt2D

[<Struct; StructLayout(LayoutKind.Sequential)>]
type VkPVPCI =
    val mutable sType: uint32
    val mutable pNext: nativeint
    val mutable flags: uint32
    val mutable vpCnt: uint32
    val mutable pVP: nativeint
    val mutable scCnt: uint32
    val mutable pSC: nativeint

[<Struct; StructLayout(LayoutKind.Sequential)>]
type VkPRCI =
    val mutable sType: uint32
    val mutable pNext: nativeint
    val mutable flags: uint32
    val mutable depthClamp: uint32
    val mutable rastDiscard: uint32
    val mutable polyMode: uint32
    val mutable cullMode: uint32
    val mutable frontFace: uint32
    val mutable depthBias: uint32
    val mutable dbConst: float32
    val mutable dbClamp: float32
    val mutable dbSlope: float32
    val mutable lineW: float32

[<Struct; StructLayout(LayoutKind.Sequential)>]
type VkPMSCI =
    val mutable sType: uint32
    val mutable pNext: nativeint
    val mutable flags: uint32
    val mutable rSamples: uint32
    val mutable sShading: uint32
    val mutable minSS: float32
    val mutable pSM: nativeint
    val mutable a2c: uint32
    val mutable a2o: uint32

[<Struct; StructLayout(LayoutKind.Sequential)>]
type VkPCBAS =
    val mutable blendEn: uint32
    val mutable sCBF: uint32
    val mutable dCBF: uint32
    val mutable cbOp: uint32
    val mutable sABF: uint32
    val mutable dABF: uint32
    val mutable abOp: uint32
    val mutable wMask: uint32

[<Struct; StructLayout(LayoutKind.Sequential)>]
type VkPCBCI =
    val mutable sType: uint32
    val mutable pNext: nativeint
    val mutable flags: uint32
    val mutable logicOpEn: uint32
    val mutable logicOp: uint32
    val mutable attCnt: uint32
    val mutable pAtts: nativeint
    val mutable bc0: float32
    val mutable bc1: float32
    val mutable bc2: float32
    val mutable bc3: float32

[<Struct; StructLayout(LayoutKind.Sequential)>]
type VkPLCI =
    val mutable sType: uint32
    val mutable pNext: nativeint
    val mutable flags: uint32
    val mutable slCnt: uint32
    val mutable pSL: nativeint
    val mutable pcCnt: uint32
    val mutable pPC: nativeint

[<Struct; StructLayout(LayoutKind.Sequential)>]
type VkGPCI =
    val mutable sType: uint32
    val mutable pNext: nativeint
    val mutable flags: uint32
    val mutable stageCnt: uint32
    val mutable pStages: nativeint
    val mutable pVIS: nativeint
    val mutable pIAS: nativeint
    val mutable pTess: nativeint
    val mutable pVPS: nativeint
    val mutable pRast: nativeint
    val mutable pMS: nativeint
    val mutable pDS: nativeint
    val mutable pCBS: nativeint
    val mutable pDyn: nativeint
    val mutable layout: uint64
    val mutable rp: uint64
    val mutable subpass: uint32
    val mutable basePipe: uint64
    val mutable basePipeIdx: int

[<Struct; StructLayout(LayoutKind.Sequential)>]
type VkCPCI =
    val mutable sType: uint32
    val mutable pNext: nativeint
    val mutable flags: uint32
    val mutable qfi: uint32

[<Struct; StructLayout(LayoutKind.Sequential)>]
type VkCBAI =
    val mutable sType: uint32
    val mutable pNext: nativeint
    val mutable pool: nativeint
    val mutable level: uint32
    val mutable cnt: uint32

[<Struct; StructLayout(LayoutKind.Sequential)>]
type VkCBBI =
    val mutable sType: uint32
    val mutable pNext: nativeint
    val mutable flags: uint32
    val mutable pInh: nativeint

[<Struct; StructLayout(LayoutKind.Sequential)>]
type VkClearCol =
    val mutable r: float32
    val mutable g: float32
    val mutable b: float32
    val mutable a: float32

[<Struct; StructLayout(LayoutKind.Explicit)>]
type VkClearVal =
    [<FieldOffset(0)>]
    val mutable color: VkClearCol

[<Struct; StructLayout(LayoutKind.Sequential)>]
type VkRPBI =
    val mutable sType: uint32
    val mutable pNext: nativeint
    val mutable rp: uint64
    val mutable fb: uint64
    val mutable area: VkRect2D
    val mutable cvCnt: uint32
    val mutable pCV: nativeint

[<Struct; StructLayout(LayoutKind.Sequential)>]
type VkFenceCI =
    val mutable sType: uint32
    val mutable pNext: nativeint
    val mutable flags: uint32

[<Struct; StructLayout(LayoutKind.Sequential)>]
type VkSubmitInfo =
    val mutable sType: uint32
    val mutable pNext: nativeint
    val mutable wsCnt: uint32
    val mutable pWS: nativeint
    val mutable pWSM: nativeint
    val mutable cbCnt: uint32
    val mutable pCB: nativeint
    val mutable ssCnt: uint32
    val mutable pSS: nativeint

[<Struct; StructLayout(LayoutKind.Sequential)>]
type VkBufImgCopy =
    val mutable bufOff: uint64
    val mutable bRL: uint32
    val mutable bIH: uint32
    val mutable aspect: uint32
    val mutable mip: uint32
    val mutable baseL: uint32
    val mutable lCnt: uint32
    val mutable oX: int
    val mutable oY: int
    val mutable oZ: int
    val mutable eW: uint32
    val mutable eH: uint32
    val mutable eD: uint32

module SC =
    [<DllImport("shaderc_shared.dll", CallingConvention = CallingConvention.Cdecl)>]
    extern nativeint shaderc_compiler_initialize()

    [<DllImport("shaderc_shared.dll", CallingConvention = CallingConvention.Cdecl)>]
    extern void shaderc_compiler_release(nativeint c)

    [<DllImport("shaderc_shared.dll", CallingConvention = CallingConvention.Cdecl)>]
    extern nativeint shaderc_compile_options_initialize()

    [<DllImport("shaderc_shared.dll", CallingConvention = CallingConvention.Cdecl)>]
    extern void shaderc_compile_options_release(nativeint o)

    [<DllImport("shaderc_shared.dll", CallingConvention = CallingConvention.Cdecl)>]
    extern void shaderc_compile_options_set_optimization_level(nativeint o, int l)

    [<DllImport("shaderc_shared.dll", CallingConvention = CallingConvention.Cdecl)>]
    extern nativeint shaderc_compile_into_spv(nativeint c, [<MarshalAs(UnmanagedType.LPStr)>] string s, unativeint sz, int k, [<MarshalAs(UnmanagedType.LPStr)>] string fn, [<MarshalAs(UnmanagedType.LPStr)>] string ep, nativeint o)

    [<DllImport("shaderc_shared.dll", CallingConvention = CallingConvention.Cdecl)>]
    extern int shaderc_result_get_compilation_status(nativeint r)

    [<DllImport("shaderc_shared.dll", CallingConvention = CallingConvention.Cdecl)>]
    extern unativeint shaderc_result_get_length(nativeint r)

    [<DllImport("shaderc_shared.dll", CallingConvention = CallingConvention.Cdecl)>]
    extern nativeint shaderc_result_get_bytes(nativeint r)

    [<DllImport("shaderc_shared.dll", CallingConvention = CallingConvention.Cdecl)>]
    extern nativeint shaderc_result_get_error_message(nativeint r)

    [<DllImport("shaderc_shared.dll", CallingConvention = CallingConvention.Cdecl)>]
    extern void shaderc_result_release(nativeint r)

    let Compile (src: string) (kind: int) (fname: string) : byte[] =
        let c = shaderc_compiler_initialize()
        let o = shaderc_compile_options_initialize()
        shaderc_compile_options_set_optimization_level(o, 2)
        try
            let r = shaderc_compile_into_spv(c, src, unativeint src.Length, kind, fname, "main", o)
            try
                if shaderc_result_get_compilation_status(r) <> 0 then
                    let e = Marshal.PtrToStringAnsi(shaderc_result_get_error_message(r))
                    failwith ("Shader: " + e)
                let len = int (shaderc_result_get_length(r))
                let d = Array.zeroCreate<byte> len
                Marshal.Copy(shaderc_result_get_bytes(r), d, 0, len)
                d
            finally
                shaderc_result_release(r)
        finally
            shaderc_compile_options_release(o)
            shaderc_compiler_release(c)

module NativeMethods =
    [<DllImport("user32.dll", EntryPoint = "RegisterClassExW", CharSet = CharSet.Unicode, ExactSpelling = true)>]
    extern uint16 RegisterClassEx([<In>] WNDCLASSEX& w)

    [<DllImport("user32.dll", EntryPoint = "CreateWindowExW", CharSet = CharSet.Unicode, ExactSpelling = true)>]
    extern nativeint CreateWindowEx(uint32 exStyle, string cls, string ttl, uint32 st, int x, int y, int w, int h, nativeint p, nativeint m, nativeint hi, nativeint lp)

    [<DllImport("user32.dll", EntryPoint = "PeekMessageW", ExactSpelling = true)>]
    extern bool PeekMessage([<Out>] MSG& m, nativeint h, uint32 mn, uint32 mx, uint32 rm)

    [<DllImport("user32.dll")>]
    extern bool TranslateMessage([<In>] MSG& m)

    [<DllImport("user32.dll", EntryPoint = "DispatchMessageW", ExactSpelling = true)>]
    extern nativeint DispatchMessage([<In>] MSG& m)

    [<DllImport("user32.dll")>]
    extern void PostQuitMessage(int c)

    [<DllImport("user32.dll", EntryPoint = "DefWindowProcW", ExactSpelling = true)>]
    extern nativeint DefWindowProc(nativeint h, uint32 m, nativeint w, nativeint l)

    [<DllImport("user32.dll")>]
    extern nativeint LoadCursor(nativeint h, int c)

    [<DllImport("user32.dll")>]
    extern nativeint GetDC(nativeint h)

    [<DllImport("user32.dll")>]
    extern bool AdjustWindowRect([<In; Out>] RECT& r, uint32 s, bool m)

    [<DllImport("kernel32.dll", CharSet = CharSet.Auto)>]
    extern nativeint GetModuleHandle(string n)

    [<DllImport("kernel32.dll", EntryPoint = "OutputDebugStringW", CharSet = CharSet.Unicode, ExactSpelling = true)>]
    extern void OutputDebugString(string s)

    [<DllImport("kernel32.dll", EntryPoint = "RtlMoveMemory")>]
    extern void CopyMemory(nativeint dest, nativeint src, nativeint length)

    [<DllImport("gdi32.dll")>]
    extern int ChoosePixelFormat(nativeint h, [<In>] PIXELFORMATDESCRIPTOR& p)

    [<DllImport("gdi32.dll")>]
    extern bool SetPixelFormat(nativeint h, int f, [<In>] PIXELFORMATDESCRIPTOR& p)

    [<DllImport("opengl32.dll")>]
    extern nativeint wglCreateContext(nativeint h)

    [<DllImport("opengl32.dll")>]
    extern int wglMakeCurrent(nativeint h, nativeint g)

    [<DllImport("opengl32.dll")>]
    extern int wglDeleteContext(nativeint g)

    [<DllImport("opengl32.dll")>]
    extern nativeint wglGetProcAddress(string n)

    [<DllImport("opengl32.dll")>]
    extern void glClearColor(float32 r, float32 g, float32 b, float32 a)

    [<DllImport("opengl32.dll")>]
    extern void glClear(uint32 m)

    [<DllImport("opengl32.dll")>]
    extern void glViewport(int x, int y, int w, int h)

    [<DllImport("opengl32.dll")>]
    extern void glDrawArrays(uint32 m, int f, int c)

    [<DllImport("opengl32.dll")>]
    extern void glFlush()

    [<DllImport("d3d11.dll")>]
    extern int D3D11CreateDevice(nativeint a, int dt, nativeint sw, uint32 fl, [<In>] uint32[] lv, uint32 n, uint32 sdk, [<Out>] nativeint& dev, [<Out>] uint32& flOut, [<Out>] nativeint& ctx)

    [<DllImport("dxgi.dll")>]
    extern int CreateDXGIFactory1([<In>] Guid& iid, [<Out>] nativeint& fac)

    [<DllImport("d3dcompiler_47.dll")>]
    extern int D3DCompile([<MarshalAs(UnmanagedType.LPStr)>] string src, nativeint sz, [<MarshalAs(UnmanagedType.LPStr)>] string nm, nativeint def, nativeint inc, [<MarshalAs(UnmanagedType.LPStr)>] string ep, [<MarshalAs(UnmanagedType.LPStr)>] string tgt, uint32 f1, uint32 f2, [<Out>] nativeint& code, [<Out>] nativeint& err)

    [<DllImport("dcomp.dll")>]
    extern int DCompositionCreateDevice(nativeint dxgi, [<In>] Guid& iid, [<Out>] nativeint& dcomp)

    [<DllImport("vulkan-1.dll")>]
    extern int vkCreateInstance([<In; Out>] VkInstCI& ci, nativeint a, [<Out>] nativeint& i)

    [<DllImport("vulkan-1.dll")>]
    extern int vkEnumeratePhysicalDevices(nativeint i, [<In; Out>] uint32& c, [<In; Out>] nativeint[] d)

    [<DllImport("vulkan-1.dll")>]
    extern void vkGetPhysicalDeviceQueueFamilyProperties(nativeint p, [<In; Out>] uint32& c, [<Out>] VkQFP[] q)

    [<DllImport("vulkan-1.dll")>]
    extern int vkCreateDevice(nativeint p, [<In; Out>] VkDevCI& ci, nativeint a, [<Out>] nativeint& d)

    [<DllImport("vulkan-1.dll")>]
    extern void vkGetDeviceQueue(nativeint d, uint32 qf, uint32 qi, [<Out>] nativeint& q)

    [<DllImport("vulkan-1.dll")>]
    extern void vkGetPhysicalDeviceMemoryProperties(nativeint p, [<Out>] VkPhysMemProps& m)

    [<DllImport("vulkan-1.dll")>]
    extern int vkCreateImage(nativeint d, [<In; Out>] VkImgCI& ci, nativeint a, [<Out>] uint64& img)

    [<DllImport("vulkan-1.dll")>]
    extern void vkGetImageMemoryRequirements(nativeint d, uint64 img, [<Out>] VkMemReq& r)

    [<DllImport("vulkan-1.dll")>]
    extern int vkAllocateMemory(nativeint d, [<In; Out>] VkMemAI& ai, nativeint a, [<Out>] uint64& m)

    [<DllImport("vulkan-1.dll")>]
    extern int vkBindImageMemory(nativeint d, uint64 img, uint64 m, uint64 o)

    [<DllImport("vulkan-1.dll")>]
    extern int vkCreateImageView(nativeint d, [<In; Out>] VkImgViewCI& ci, nativeint a, [<Out>] uint64& v)

    [<DllImport("vulkan-1.dll")>]
    extern int vkCreateBuffer(nativeint d, [<In; Out>] VkBufCI& ci, nativeint a, [<Out>] uint64& b)

    [<DllImport("vulkan-1.dll")>]
    extern void vkGetBufferMemoryRequirements(nativeint d, uint64 b, [<Out>] VkMemReq& r)

    [<DllImport("vulkan-1.dll")>]
    extern int vkBindBufferMemory(nativeint d, uint64 b, uint64 m, uint64 o)

    [<DllImport("vulkan-1.dll")>]
    extern int vkCreateRenderPass(nativeint d, [<In; Out>] VkRPCI& ci, nativeint a, [<Out>] uint64& rp)

    [<DllImport("vulkan-1.dll")>]
    extern int vkCreateFramebuffer(nativeint d, [<In; Out>] VkFBCI& ci, nativeint a, [<Out>] uint64& fb)

    [<DllImport("vulkan-1.dll")>]
    extern int vkCreateShaderModule(nativeint d, [<In; Out>] VkSMCI& ci, nativeint a, [<Out>] uint64& sm)

    [<DllImport("vulkan-1.dll")>]
    extern void vkDestroyShaderModule(nativeint d, uint64 sm, nativeint a)

    [<DllImport("vulkan-1.dll")>]
    extern int vkCreatePipelineLayout(nativeint d, [<In; Out>] VkPLCI& ci, nativeint a, [<Out>] uint64& pl)

    [<DllImport("vulkan-1.dll")>]
    extern int vkCreateGraphicsPipelines(nativeint d, uint64 cache, uint32 n, [<In; Out>] VkGPCI& ci, nativeint a, [<Out>] uint64& p)

    [<DllImport("vulkan-1.dll")>]
    extern int vkCreateCommandPool(nativeint d, [<In; Out>] VkCPCI& ci, nativeint a, [<Out>] nativeint& p)

    [<DllImport("vulkan-1.dll")>]
    extern int vkAllocateCommandBuffers(nativeint d, [<In; Out>] VkCBAI& ai, [<Out>] nativeint& cb)

    [<DllImport("vulkan-1.dll")>]
    extern int vkCreateFence(nativeint d, [<In; Out>] VkFenceCI& ci, nativeint a, [<Out>] uint64& f)

    [<DllImport("vulkan-1.dll")>]
    extern int vkWaitForFences(nativeint d, uint32 n, [<In>] uint64[] f, uint32 all, uint64 t)

    [<DllImport("vulkan-1.dll")>]
    extern int vkResetFences(nativeint d, uint32 n, [<In>] uint64[] f)

    [<DllImport("vulkan-1.dll")>]
    extern int vkResetCommandBuffer(nativeint cb, uint32 f)

    [<DllImport("vulkan-1.dll")>]
    extern int vkBeginCommandBuffer(nativeint cb, [<In; Out>] VkCBBI& bi)

    [<DllImport("vulkan-1.dll")>]
    extern int vkEndCommandBuffer(nativeint cb)

    [<DllImport("vulkan-1.dll")>]
    extern void vkCmdBeginRenderPass(nativeint cb, [<In; Out>] VkRPBI& rp, uint32 c)

    [<DllImport("vulkan-1.dll")>]
    extern void vkCmdEndRenderPass(nativeint cb)

    [<DllImport("vulkan-1.dll")>]
    extern void vkCmdBindPipeline(nativeint cb, uint32 bp, uint64 p)

    [<DllImport("vulkan-1.dll")>]
    extern void vkCmdDraw(nativeint cb, uint32 vc, uint32 ic, uint32 fv, uint32 fi)

    [<DllImport("vulkan-1.dll")>]
    extern void vkCmdCopyImageToBuffer(nativeint cb, uint64 img, uint32 layout, uint64 buf, uint32 n, nativeint r)

    [<DllImport("vulkan-1.dll")>]
    extern int vkQueueSubmit(nativeint q, uint32 n, [<In; Out>] VkSubmitInfo& si, uint64 f)

    [<DllImport("vulkan-1.dll")>]
    extern int vkMapMemory(nativeint d, uint64 m, uint64 o, uint64 sz, uint32 f, [<Out>] nativeint& p)

    [<DllImport("vulkan-1.dll")>]
    extern void vkUnmapMemory(nativeint d, uint64 m)

    [<DllImport("vulkan-1.dll")>]
    extern int vkDeviceWaitIdle(nativeint d)

module App =
    let PW = 320
    let PH = 480
    let WS_OVR = 0xCF0000u
    let WS_VIS = 0x10000000u
    let CS_OWN = 0x20u
    let WM_DEST = 2u
    let WM_CLOSE = 0x10u
    let WM_QUIT = 0x12u
    let WM_KEY = 0x100u
    let PM_REM = 1u
    let VK_ESC = 0x1B
    let DXGI_B8 = 87u
    let DXGI_R32G32B32 = 6u
    let DXGI_R32G32B32A32 = 2u
    let DXGI_USAGE_RTO = 0x20u
    let DXGI_FLIP_SEQ = 3u
    let DXGI_ALPHA_PRE = 1u
    let D3D_SDK = 7u
    let D3D_FL11 = 0xB000u
    let D3D_BGRA = 0x20u
    let D3D_STAGING = 3u
    let D3D_BIND_VB = 1u
    let D3D_MAP_W = 2u
    let D3D_CPU_W = 0x10000u
    let D3D_TOPO_TRI = 4u
    let GL_TRI = 4u
    let GL_FLT = 0x1406u
    let GL_COLBIT = 0x4000u
    let GL_ABUF = 0x8892u
    let GL_STATIC = 0x88E4u
    let GL_VS = 0x8B31u
    let GL_FS = 0x8B30u
    let GL_FB = 0x8D40u
    let GL_RB = 0x8D41u
    let GL_CA0 = 0x8CE0u
    let WGL_RW = 1u

    let IID_F2 = Guid("50c83a1c-e072-4c48-87b0-3630fa36a6d0")
    let IID_DXGIDev = Guid("54ec77fa-1377-44e6-8c32-88fd5f44c84c")
    let IID_Tex2D = Guid("6f15aaf2-d208-4e89-9ab4-489535d34f9c")
    let IID_DCDev = Guid("C37EA93A-E7AA-450D-B16F-9746CB0407F3")

    let mutable quit = false
    let mutable wpr: WndProcDelegate = null
    let mutable hw = nativeint 0
    let mutable d3d = nativeint 0
    let mutable ctx = nativeint 0
    let mutable fac = nativeint 0
    let mutable dc = nativeint 0
    let mutable dct = nativeint 0
    let mutable dcr = nativeint 0

    let mutable dxSC = nativeint 0
    let mutable dxBB = nativeint 0
    let mutable dxRTV = nativeint 0
    let mutable dxVB = nativeint 0
    let mutable dxVS = nativeint 0
    let mutable dxPS = nativeint 0
    let mutable dxIL = nativeint 0

    let mutable glSC = nativeint 0
    let mutable glBB = nativeint 0
    let mutable glHDC = nativeint 0
    let mutable glHRC = nativeint 0
    let mutable glID = nativeint 0
    let mutable glIO = nativeint 0
    let mutable glFBO = 0u
    let mutable glRBO = 0u
    let mutable glProg = 0u
    let mutable glPA = 0u
    let mutable glCA = 0u
    let glVBO = [| 0u; 0u |]

    let mutable gGB: glGenBuffersD = null
    let mutable gBB: glBindBufferD = null
    let mutable gBD: glBufferDataD = null
    let mutable gCS: glCreateShaderD = null
    let mutable gSS: glShaderSourceD = null
    let mutable gCoS: glCompileShaderD = null
    let mutable gCP: glCreateProgramD = null
    let mutable gAS: glAttachShaderD = null
    let mutable gLP: glLinkProgramD = null
    let mutable gUP: glUseProgramD = null
    let mutable gGA: glGetAttribLocationD = null
    let mutable gEV: glEnableVAD = null
    let mutable gVAP: glVertexAttribPointerD = null
    let mutable gGF: glGenFBD = null
    let mutable gBF: glBindFBD = null
    let mutable gFR: glFBRBD = null
    let mutable gGR: glGenRBD = null
    let mutable gGV: glGenVAOD = null
    let mutable gBV: glBindVAOD = null
    let mutable gDL: wglDXLockD = null
    let mutable gDU: wglDXUnlockD = null

    let mutable vSC = nativeint 0
    let mutable vBB = nativeint 0
    let mutable vST = nativeint 0
    let mutable vI = nativeint 0
    let mutable vPD = nativeint 0
    let mutable vD = nativeint 0
    let mutable vQ = nativeint 0
    let mutable vCP = nativeint 0
    let mutable vCB = nativeint 0
    let mutable vOI = 0UL
    let mutable vOV = 0UL
    let mutable vOM = 0UL
    let mutable vSB = 0UL
    let mutable vSM2 = 0UL
    let mutable vRP = 0UL
    let mutable vFB2 = 0UL
    let mutable vPL = 0UL
    let mutable vPP = 0UL
    let mutable vFN = 0UL
    let mutable vQF = -1
    let mutable frameNo = 0

    let dbg (msg: string) =
        let line = "[F#][composition/triangle_multi] " + msg
        printfn "%s" line
        NativeMethods.OutputDebugString(line)

    let hhex (hr: int) =
        sprintf "0x%08X" (uint32 hr)

    let checkHR (label: string) (hr: int) =
        if hr < 0 then
            dbg (sprintf "%s failed: %s" label (hhex hr))
            failwithf "%s failed: %s" label (hhex hr)

    let checkVK (label: string) (r: int) =
        if r <> 0 then
            dbg (sprintf "%s failed: %d (0x%08X)" label r (uint32 r))
            failwithf "%s failed: %d" label r

    let vt (p: nativeint) (i: int) : nativeint =
        Marshal.ReadIntPtr(Marshal.ReadIntPtr(p), i * IntPtr.Size)

    let qi (o: nativeint) (g: Guid) : nativeint =
        let mutable gg = g
        let mutable r = nativeint 0
        let f = Marshal.GetDelegateForFunctionPointer<QIDelegate>(vt o 0)
        let hr = f.Invoke(o, &gg, &r)
        if hr < 0 then failwithf "QI failed: 0x%08X" hr
        r

    let rel (o: nativeint) =
        if o <> nativeint 0 then Marshal.Release(o) |> ignore

    let getGL<'T when 'T :> Delegate> (n: string) : 'T =
        let p = NativeMethods.wglGetProcAddress(n)
        if p = nativeint 0 then failwith ("GL: " + n)
        Marshal.GetDelegateForFunctionPointer<'T>(p)

    let hlsl =
        "struct VSI{float3 p:POSITION;float4 c:COLOR;};\n" +
        "struct PSI{float4 p:SV_POSITION;float4 c:COLOR;};\n" +
        "PSI VS(VSI i){PSI o;o.p=float4(i.p,1);o.c=i.c;return o;}\n" +
        "float4 PS(PSI i):SV_Target{return i.c;}\n"

    let wp (h: nativeint) (m: uint32) (w: nativeint) (l: nativeint) : nativeint =
        if m = WM_CLOSE || m = WM_DEST then
            dbg (sprintf "WM_CLOSE/WM_DEST message=0x%X" m)
            quit <- true
            NativeMethods.PostQuitMessage(0)
            nativeint 0
        elif m = WM_KEY && (int w) = VK_ESC then
            dbg "VK_ESCAPE pressed"
            quit <- true
            NativeMethods.PostQuitMessage(0)
            nativeint 0
        else
            NativeMethods.DefWindowProc(h, m, w, l)

    let makeWin () =
        dbg "makeWin: begin"
        let hi = NativeMethods.GetModuleHandle(null)
        wpr <- new WndProcDelegate(fun h m w l -> wp h m w l)

        let mutable wc = Unchecked.defaultof<WNDCLASSEX>
        wc.cbSize <- uint32 (Marshal.SizeOf(typeof<WNDCLASSEX>))
        wc.style <- CS_OWN
        wc.lpfnWndProc <- wpr
        wc.hInstance <- hi
        wc.hCursor <- NativeMethods.LoadCursor(nativeint 0, 32512)
        wc.lpszClassName <- "DCMulti"
        let cls = NativeMethods.RegisterClassEx(&wc)
        dbg (sprintf "RegisterClassEx -> 0x%X" cls)

        let mutable rc = Unchecked.defaultof<RECT>
        rc.Right <- PW * 3
        rc.Bottom <- PH
        NativeMethods.AdjustWindowRect(&rc, WS_OVR, false) |> ignore

        hw <- NativeMethods.CreateWindowEx(0u, "DCMulti", "Hello, DirectComposition(F#) World!", WS_OVR ||| WS_VIS, 100, 100, rc.Right - rc.Left, rc.Bottom - rc.Top, nativeint 0, nativeint 0, hi, nativeint 0)
        if hw = nativeint 0 then failwith "CreateWindowEx failed"
        dbg (sprintf "CreateWindowEx hwnd=0x%X" hw)

    let makeD3D () =
        dbg "makeD3D: begin"
        let mutable fl = 0u
        let lv = [| D3D_FL11 |]
        let hr = NativeMethods.D3D11CreateDevice(nativeint 0, 1, nativeint 0, D3D_BGRA, lv, 1u, D3D_SDK, &d3d, &fl, &ctx)
        checkHR "D3D11CreateDevice" hr
        dbg (sprintf "makeD3D: featureLevel=0x%X d3d=0x%X ctx=0x%X" fl d3d ctx)

    let makeFac () =
        dbg "makeFac: begin"
        let mutable g = Guid("770aae78-f26f-4dba-a829-253c83d1b387")
        let mutable f1 = nativeint 0
        let hr = NativeMethods.CreateDXGIFactory1(&g, &f1)
        checkHR "CreateDXGIFactory1" hr
        fac <- qi f1 IID_F2
        rel f1
        dbg (sprintf "makeFac: fac=0x%X" fac)

    let makeDC () =
        dbg "makeDC: begin"
        let dxgi = qi d3d IID_DXGIDev
        let mutable dg = IID_DCDev
        let hr = NativeMethods.DCompositionCreateDevice(dxgi, &dg, &dc)
        rel dxgi
        checkHR "DCompositionCreateDevice" hr

        let ct = Marshal.GetDelegateForFunctionPointer<DCCreateTargetDelegate>(vt dc 6)
        let cv = Marshal.GetDelegateForFunctionPointer<DCCreateVisDelegate>(vt dc 7)
        let hrCT = ct.Invoke(dc, hw, 1, &dct)
        checkHR "IDCompositionDevice::CreateTargetForHwnd" hrCT
        let hrCV = cv.Invoke(dc, &dcr)
        checkHR "IDCompositionDevice::CreateVisual(root)" hrCV

        let sr = Marshal.GetDelegateForFunctionPointer<DCSetRootDelegate>(vt dct 3)
        let hrSR = sr.Invoke(dct, dcr)
        checkHR "IDCompositionTarget::SetRoot" hrSR
        dbg (sprintf "makeDC: dc=0x%X dct=0x%X dcr=0x%X" dc dct dcr)

    let dcVis () : nativeint =
        let cv = Marshal.GetDelegateForFunctionPointer<DCCreateVisDelegate>(vt dc 7)
        let mutable v = nativeint 0
        cv.Invoke(dc, &v) |> ignore
        v

    let dcSetup (v: nativeint) (sc: nativeint) (x: float32) =
        let scn = Marshal.GetDelegateForFunctionPointer<DCSetContentDelegate>(vt v 15)
        let ox = Marshal.GetDelegateForFunctionPointer<DCSetOffXDelegate>(vt v 4)
        let oy = Marshal.GetDelegateForFunctionPointer<DCSetOffYDelegate>(vt v 6)
        let av = Marshal.GetDelegateForFunctionPointer<DCAddVisDelegate>(vt dcr 16)
        checkHR "IDCompositionVisual::SetContent" (scn.Invoke(v, sc))
        checkHR "IDCompositionVisual::SetOffsetX" (ox.Invoke(v, x))
        checkHR "IDCompositionVisual::SetOffsetY" (oy.Invoke(v, 0.0f))
        checkHR "IDCompositionVisual::AddVisual" (av.Invoke(dcr, v, 1, nativeint 0))
        dbg (sprintf "dcSetup: vis=0x%X sc=0x%X x=%.1f" v sc x)

    let dcCommit () =
        let c = Marshal.GetDelegateForFunctionPointer<DCCommitDelegate>(vt dc 3)
        checkHR "IDCompositionDevice::Commit" (c.Invoke(dc))
        dbg "dcCommit: success"

    let makeSC (w: int) (h: int) : nativeint =
        let mutable d = Unchecked.defaultof<DXGI_SWAP_CHAIN_DESC1>
        d.Width <- uint32 w
        d.Height <- uint32 h
        d.Format <- DXGI_B8
        d.SampleDesc <- DXGI_SAMPLE_DESC(Count = 1u)
        d.BufferUsage <- DXGI_USAGE_RTO
        d.BufferCount <- 2u
        d.SwapEffect <- DXGI_FLIP_SEQ
        d.AlphaMode <- DXGI_ALPHA_PRE

        let f = Marshal.GetDelegateForFunctionPointer<CreateSCCompDelegate>(vt fac 24)
        let mutable sc = nativeint 0
        let hr = f.Invoke(fac, d3d, &d, nativeint 0, &sc)
        checkHR "CreateSwapChainForComposition" hr
        dbg (sprintf "makeSC: %dx%d sc=0x%X" w h sc)
        sc

    let scBuf (sc: nativeint) : nativeint =
        let gb = Marshal.GetDelegateForFunctionPointer<GetBufDelegate>(vt sc 9)
        let mutable g = IID_Tex2D
        let mutable t = nativeint 0
        let hr = gb.Invoke(sc, 0u, &g, &t)
        checkHR "IDXGISwapChain::GetBuffer" hr
        dbg (sprintf "scBuf: sc=0x%X tex=0x%X" sc t)
        t

    let scPres (sc: nativeint) =
        let p = Marshal.GetDelegateForFunctionPointer<PresentDelegate>(vt sc 8)
        let hr = p.Invoke(sc, 1u, 0u)
        checkHR "IDXGISwapChain::Present" hr

    let makeRTV (t: nativeint) : nativeint =
        let f = Marshal.GetDelegateForFunctionPointer<CreateRTVDelegate>(vt d3d 9)
        let mutable r = nativeint 0
        let hr = f.Invoke(d3d, t, nativeint 0, &r)
        checkHR "ID3D11Device::CreateRenderTargetView" hr
        dbg (sprintf "makeRTV: bb=0x%X rtv=0x%X" t r)
        r

    let makeStagTex (w: int) (h: int) : nativeint =
        let mutable d = Unchecked.defaultof<D3D11_TEXTURE2D_DESC>
        d.Width <- uint32 w
        d.Height <- uint32 h
        d.MipLevels <- 1u
        d.ArraySize <- 1u
        d.Format <- DXGI_B8
        d.SampleDesc <- DXGI_SAMPLE_DESC(Count = 1u)
        d.Usage <- D3D_STAGING
        d.CPUAccessFlags <- D3D_CPU_W
        let f = Marshal.GetDelegateForFunctionPointer<CreateTex2DDelegate>(vt d3d 5)
        let mutable t = nativeint 0
        let hr = f.Invoke(d3d, &d, nativeint 0, &t)
        checkHR "ID3D11Device::CreateTexture2D(staging)" hr
        dbg (sprintf "makeStagTex: %dx%d tex=0x%X" w h t)
        t

    let clearRTV (r: nativeint) (cr: float32) (cg: float32) (cb: float32) (ca: float32) =
        let f = Marshal.GetDelegateForFunctionPointer<ClearRTVDelegate>(vt ctx 50)
        f.Invoke(ctx, r, [| cr; cg; cb; ca |])

    let copyRes (d: nativeint) (s: nativeint) =
        let f = Marshal.GetDelegateForFunctionPointer<CopyResDelegate>(vt ctx 47)
        f.Invoke(ctx, d, s)

    let mapW (r: nativeint) : D3D11_MAPPED_SUBRESOURCE =
        let f = Marshal.GetDelegateForFunctionPointer<MapDelegate>(vt ctx 14)
        let mutable m = Unchecked.defaultof<D3D11_MAPPED_SUBRESOURCE>
        f.Invoke(ctx, r, 0u, D3D_MAP_W, 0u, &m) |> ignore
        m

    let unmap (r: nativeint) =
        let f = Marshal.GetDelegateForFunctionPointer<UnmapDelegate>(vt ctx 15)
        f.Invoke(ctx, r, 0u)

    let initDX () =
        dbg "initDX: begin"
        dxSC <- makeSC PW PH
        dxBB <- scBuf dxSC
        dxRTV <- makeRTV dxBB

        let mutable vb = nativeint 0
        let mutable pb = nativeint 0
        let mutable err = nativeint 0
        let hrVS = NativeMethods.D3DCompile(hlsl, nativeint hlsl.Length, "dx", nativeint 0, nativeint 0, "VS", "vs_4_0", 0u, 0u, &vb, &err)
        checkHR "D3DCompile(VS)" hrVS
        let hrPS = NativeMethods.D3DCompile(hlsl, nativeint hlsl.Length, "dx", nativeint 0, nativeint 0, "PS", "ps_4_0", 0u, 0u, &pb, &err)
        checkHR "D3DCompile(PS)" hrPS

        let bp = Marshal.GetDelegateForFunctionPointer<BlobPtrDelegate>(vt vb 3)
        let bs = Marshal.GetDelegateForFunctionPointer<BlobSzDelegate>(vt vb 4)
        let vP = bp.Invoke(vb)
        let vS = bs.Invoke(vb)
        let pP = (Marshal.GetDelegateForFunctionPointer<BlobPtrDelegate>(vt pb 3)).Invoke(pb)
        let pS = (Marshal.GetDelegateForFunctionPointer<BlobSzDelegate>(vt pb 4)).Invoke(pb)

        let hrCVS = (Marshal.GetDelegateForFunctionPointer<CreateVSDelegate>(vt d3d 12)).Invoke(d3d, vP, vS, nativeint 0, &dxVS)
        checkHR "CreateVertexShader" hrCVS
        let hrCPS = (Marshal.GetDelegateForFunctionPointer<CreatePSDelegate>(vt d3d 15)).Invoke(d3d, pP, pS, nativeint 0, &dxPS)
        checkHR "CreatePixelShader" hrCPS

        let el =
            [| D3D11_INPUT_ELEMENT_DESC(SemanticName = "POSITION", Format = DXGI_R32G32B32, AlignedByteOffset = 0u)
               D3D11_INPUT_ELEMENT_DESC(SemanticName = "COLOR", Format = DXGI_R32G32B32A32, AlignedByteOffset = 12u) |]

        let hrIL = (Marshal.GetDelegateForFunctionPointer<CreateILDelegate>(vt d3d 11)).Invoke(d3d, el, 2u, vP, vS, &dxIL)
        checkHR "CreateInputLayout" hrIL
        rel vb
        rel pb

        let vs =
            [| DxVertex(X = 0.0f, Y = 0.5f, Z = 0.0f, R = 1.0f, G = 0.0f, B = 0.0f, A = 1.0f)
               DxVertex(X = 0.5f, Y = -0.5f, Z = 0.0f, R = 0.0f, G = 1.0f, B = 0.0f, A = 1.0f)
               DxVertex(X = -0.5f, Y = -0.5f, Z = 0.0f, R = 0.0f, G = 0.0f, B = 1.0f, A = 1.0f) |]

        let hV = GCHandle.Alloc(vs, GCHandleType.Pinned)
        let mutable bd = Unchecked.defaultof<D3D11_BUFFER_DESC>
        bd.ByteWidth <- uint32 (Marshal.SizeOf(typeof<DxVertex>) * 3)
        bd.BindFlags <- D3D_BIND_VB
        let mutable sd = Unchecked.defaultof<D3D11_SUBRESOURCE_DATA>
        sd.pSysMem <- hV.AddrOfPinnedObject()
        let hrVB = (Marshal.GetDelegateForFunctionPointer<CreateBufferDelegate>(vt d3d 3)).Invoke(d3d, &bd, &sd, &dxVB)
        checkHR "CreateBuffer(VertexBuffer)" hrVB
        hV.Free()

        dcSetup (dcVis()) dxSC (float32 PW)
        dbg (sprintf "initDX: done sc=0x%X bb=0x%X rtv=0x%X vb=0x%X" dxSC dxBB dxRTV dxVB)
        printfn "[D3D11] OK"

    let renderDX () =
        clearRTV dxRTV 0.05f 0.15f 0.05f 1.0f
        (Marshal.GetDelegateForFunctionPointer<OMSetRTDelegate>(vt ctx 33)).Invoke(ctx, 1u, [| dxRTV |], nativeint 0)

        let mutable vp = D3D11_VIEWPORT(Width = float32 PW, Height = float32 PH, MaxDepth = 1.0f)
        (Marshal.GetDelegateForFunctionPointer<RSSetVPDelegate>(vt ctx 44)).Invoke(ctx, 1u, &vp)

        (Marshal.GetDelegateForFunctionPointer<IASetILDelegate>(vt ctx 17)).Invoke(ctx, dxIL)
        (Marshal.GetDelegateForFunctionPointer<IASetVBDelegate>(vt ctx 18)).Invoke(ctx, 0u, 1u, [| dxVB |], [| uint32 (Marshal.SizeOf(typeof<DxVertex>)) |], [| 0u |])
        (Marshal.GetDelegateForFunctionPointer<IASetTopoDelegate>(vt ctx 24)).Invoke(ctx, D3D_TOPO_TRI)
        (Marshal.GetDelegateForFunctionPointer<VSSetDelegate>(vt ctx 11)).Invoke(ctx, dxVS, null, 0u)
        (Marshal.GetDelegateForFunctionPointer<PSSetDelegate>(vt ctx 9)).Invoke(ctx, dxPS, null, 0u)
        (Marshal.GetDelegateForFunctionPointer<DrawDelegate>(vt ctx 13)).Invoke(ctx, 3u, 0u)
        scPres dxSC

    let initGL () =
        dbg "initGL: begin"
        glHDC <- NativeMethods.GetDC(hw)
        let mutable pfd = Unchecked.defaultof<PIXELFORMATDESCRIPTOR>
        pfd.nSize <- uint16 (Marshal.SizeOf(typeof<PIXELFORMATDESCRIPTOR>))
        pfd.nVersion <- 1us
        pfd.dwFlags <- 0x25u
        pfd.cColorBits <- 32uy
        let fmt = NativeMethods.ChoosePixelFormat(glHDC, &pfd)
        NativeMethods.SetPixelFormat(glHDC, fmt, &pfd) |> ignore
        dbg (sprintf "initGL: hdc=0x%X pixelFormat=%d" glHDC fmt)

        let tmp = NativeMethods.wglCreateContext(glHDC)
        NativeMethods.wglMakeCurrent(glHDC, tmp) |> ignore
        glHRC <- (getGL<wglCreateCtxARBD> "wglCreateContextAttribsARB").Invoke(glHDC, nativeint 0, null)
        NativeMethods.wglMakeCurrent(glHDC, glHRC) |> ignore
        NativeMethods.wglDeleteContext(tmp) |> ignore
        dbg (sprintf "initGL: tmpCtx=0x%X glCtx=0x%X" tmp glHRC)

        gGB <- getGL<glGenBuffersD> "glGenBuffers"
        gBB <- getGL<glBindBufferD> "glBindBuffer"
        gBD <- getGL<glBufferDataD> "glBufferData"
        gCS <- getGL<glCreateShaderD> "glCreateShader"
        gSS <- getGL<glShaderSourceD> "glShaderSource"
        gCoS <- getGL<glCompileShaderD> "glCompileShader"
        gCP <- getGL<glCreateProgramD> "glCreateProgram"
        gAS <- getGL<glAttachShaderD> "glAttachShader"
        gLP <- getGL<glLinkProgramD> "glLinkProgram"
        gUP <- getGL<glUseProgramD> "glUseProgram"
        gGA <- getGL<glGetAttribLocationD> "glGetAttribLocation"
        gEV <- getGL<glEnableVAD> "glEnableVertexAttribArray"
        gVAP <- getGL<glVertexAttribPointerD> "glVertexAttribPointer"
        gGF <- getGL<glGenFBD> "glGenFramebuffers"
        gBF <- getGL<glBindFBD> "glBindFramebuffer"
        gFR <- getGL<glFBRBD> "glFramebufferRenderbuffer"
        gGR <- getGL<glGenRBD> "glGenRenderbuffers"
        gGV <- getGL<glGenVAOD> "glGenVertexArrays"
        gBV <- getGL<glBindVAOD> "glBindVertexArray"

        let dxO = getGL<wglDXOpenD> "wglDXOpenDeviceNV"
        let dxR = getGL<wglDXRegD> "wglDXRegisterObjectNV"
        gDL <- getGL<wglDXLockD> "wglDXLockObjectsNV"
        gDU <- getGL<wglDXUnlockD> "wglDXUnlockObjectsNV"

        glSC <- makeSC PW PH
        glBB <- scBuf glSC
        glID <- dxO.Invoke(d3d)
        if glID = nativeint 0 then failwith "wglDXOpenDeviceNV"
        dbg (sprintf "initGL: glSC=0x%X glBB=0x%X glID=0x%X" glSC glBB glID)

        let rb = [| 0u |]
        gGR.Invoke(1, rb)
        glRBO <- rb.[0]

        glIO <- dxR.Invoke(glID, glBB, glRBO, GL_RB, WGL_RW)
        if glIO = nativeint 0 then failwith "wglDXRegisterObjectNV"
        dbg (sprintf "initGL: glRBO=%u glIO=0x%X" glRBO glIO)

        let fb = [| 0u |]
        gGF.Invoke(1, fb)
        glFBO <- fb.[0]
        gBF.Invoke(GL_FB, glFBO)
        gFR.Invoke(GL_FB, GL_CA0, GL_RB, glRBO)
        gBF.Invoke(GL_FB, 0u)

        let va = [| 0u |]
        gGV.Invoke(1, va)
        gBV.Invoke(va.[0])
        gGB.Invoke(2, glVBO)

        let vt = [| 0.0f; 0.5f; 0.0f; 0.5f; -0.5f; 0.0f; -0.5f; -0.5f; 0.0f |]
        let cl = [| 1.0f; 0.0f; 0.0f; 0.0f; 1.0f; 0.0f; 0.0f; 0.0f; 1.0f |]
        gBB.Invoke(GL_ABUF, glVBO.[0])
        gBD.Invoke(GL_ABUF, vt.Length * 4, vt, GL_STATIC)
        gBB.Invoke(GL_ABUF, glVBO.[1])
        gBD.Invoke(GL_ABUF, cl.Length * 4, cl, GL_STATIC)

        let vs = "#version 460 core\nlayout(location=0) in vec3 pos;layout(location=1) in vec3 col;\nout vec4 vC;\nvoid main(){vC=vec4(col,1);gl_Position=vec4(pos.x,-pos.y,pos.z,1);}\n"
        let fs = "#version 460 core\nin vec4 vC;out vec4 oC;\nvoid main(){oC=vC;}\n"
        let v = gCS.Invoke(GL_VS)
        gSS.Invoke(v, 1, [| vs |], null)
        gCoS.Invoke(v)
        let f = gCS.Invoke(GL_FS)
        gSS.Invoke(f, 1, [| fs |], null)
        gCoS.Invoke(f)

        glProg <- gCP.Invoke()
        gAS.Invoke(glProg, v)
        gAS.Invoke(glProg, f)
        gLP.Invoke(glProg)
        gUP.Invoke(glProg)

        glPA <- gGA.Invoke(glProg, "pos")
        glCA <- gGA.Invoke(glProg, "col")
        gEV.Invoke(glPA)
        gEV.Invoke(glCA)

        dcSetup (dcVis()) glSC 0.0f
        dbg (sprintf "initGL: done fbo=%u prog=%u pos=%u col=%u" glFBO glProg glPA glCA)
        printfn "[GL] OK"

    let renderGL () =
        NativeMethods.wglMakeCurrent(glHDC, glHRC) |> ignore
        let o = [| glIO |]
        gDL.Invoke(glID, 1, o) |> ignore

        gBF.Invoke(GL_FB, glFBO)
        NativeMethods.glViewport(0, 0, PW, PH)
        NativeMethods.glClearColor(0.05f, 0.05f, 0.15f, 1.0f)
        NativeMethods.glClear(GL_COLBIT)

        gUP.Invoke(glProg)
        gBB.Invoke(GL_ABUF, glVBO.[0])
        gVAP.Invoke(glPA, 3, GL_FLT, false, 0, nativeint 0)
        gBB.Invoke(GL_ABUF, glVBO.[1])
        gVAP.Invoke(glCA, 3, GL_FLT, false, 0, nativeint 0)

        NativeMethods.glDrawArrays(GL_TRI, 0, 3)
        gBF.Invoke(GL_FB, 0u)
        NativeMethods.glFlush()
        gDU.Invoke(glID, 1, o) |> ignore
        scPres glSC

    let findMT (p: VkPhysMemProps) (bits: uint32) (req: uint32) : uint32 =
        let mutable i = 0u
        let msz = Marshal.SizeOf(typeof<VkMemType>)
        let mutable ret = UInt32.MaxValue
        while i < p.typeCnt && ret = UInt32.MaxValue do
            if (bits &&& (1u <<< int i)) <> 0u then
                let off = int i * msz
                let flags = BitConverter.ToUInt32(p.types, off)
                if (flags &&& req) = req then ret <- i
            i <- i + 1u
        if ret = UInt32.MaxValue then failwith "No VK mem type"
        ret

    let initVK () =
        dbg "initVK: begin"
        let an = Marshal.StringToHGlobalAnsi("vk")
        let ai = VkAppInfo(sType = 0u, pAppName = an, apiVer = (1u <<< 22))
        let hAI = GCHandle.Alloc(ai, GCHandleType.Pinned)
        let mutable ici = VkInstCI(sType = 1u, pAppInfo = hAI.AddrOfPinnedObject())
        checkVK "vkCreateInstance" (NativeMethods.vkCreateInstance(&ici, nativeint 0, &vI))
        hAI.Free()
        Marshal.FreeHGlobal(an)
        dbg (sprintf "initVK: instance=0x%X" vI)

        let mutable cnt = 0u
        checkVK "vkEnumeratePhysicalDevices(count)" (NativeMethods.vkEnumeratePhysicalDevices(vI, &cnt, null))
        let ds = Array.zeroCreate<nativeint> (int cnt)
        checkVK "vkEnumeratePhysicalDevices(list)" (NativeMethods.vkEnumeratePhysicalDevices(vI, &cnt, ds))
        vPD <- ds.[0]
        vQF <- -1
        dbg (sprintf "initVK: physicalDeviceCount=%d pd=0x%X" cnt vPD)

        let mutable qc = 0u
        NativeMethods.vkGetPhysicalDeviceQueueFamilyProperties(vPD, &qc, null)
        let qp = Array.zeroCreate<VkQFP> (int qc)
        NativeMethods.vkGetPhysicalDeviceQueueFamilyProperties(vPD, &qc, qp)
        for i in 0 .. (int qc - 1) do
            if (qp.[i].qFlags &&& 1u) <> 0u && vQF = -1 then vQF <- i

        let hP = GCHandle.Alloc([| 1.0f |], GCHandleType.Pinned)
        let qci = VkDevQCI(sType = 2u, qfi = uint32 vQF, qCnt = 1u, pPrio = hP.AddrOfPinnedObject())
        let hQ = GCHandle.Alloc(qci, GCHandleType.Pinned)
        let mutable dci = VkDevCI(sType = 3u, qciCnt = 1u, pQCI = hQ.AddrOfPinnedObject())
        checkVK "vkCreateDevice" (NativeMethods.vkCreateDevice(vPD, &dci, nativeint 0, &vD))
        hQ.Free()
        hP.Free()
        dbg (sprintf "initVK: queueFamily=%d device=0x%X" vQF vD)

        NativeMethods.vkGetDeviceQueue(vD, uint32 vQF, 0u, &vQ)
        let mutable mp = VkPhysMemProps(types = Array.zeroCreate<byte> 256, heaps = Array.zeroCreate<byte> 256)
        NativeMethods.vkGetPhysicalDeviceMemoryProperties(vPD, &mp)

        let mutable ic = VkImgCI(sType = 14u, imgType = 1u, fmt = 44u, eW = uint32 PW, eH = uint32 PH, eD = 1u, mip = 1u, arr = 1u, samples = 1u, usage = 0x11u)
        checkVK "vkCreateImage(output)" (NativeMethods.vkCreateImage(vD, &ic, nativeint 0, &vOI))

        let mutable ir = Unchecked.defaultof<VkMemReq>
        NativeMethods.vkGetImageMemoryRequirements(vD, vOI, &ir)
        let mutable ia2 = VkMemAI(sType = 5u, size = ir.size, memIdx = findMT mp ir.memBits 1u)
        checkVK "vkAllocateMemory(output)" (NativeMethods.vkAllocateMemory(vD, &ia2, nativeint 0, &vOM))
        checkVK "vkBindImageMemory(output)" (NativeMethods.vkBindImageMemory(vD, vOI, vOM, 0UL))

        let mutable ivc = VkImgViewCI(sType = 15u, img = vOI, viewType = 1u, fmt = 44u, aspect = 1u, lvlCnt = 1u, layerCnt = 1u)
        checkVK "vkCreateImageView(output)" (NativeMethods.vkCreateImageView(vD, &ivc, nativeint 0, &vOV))

        let bsz = uint64 (PW * PH * 4)
        let mutable bc = VkBufCI(sType = 12u, size = bsz, usage = 2u)
        checkVK "vkCreateBuffer(stagingReadback)" (NativeMethods.vkCreateBuffer(vD, &bc, nativeint 0, &vSB))

        let mutable br = Unchecked.defaultof<VkMemReq>
        NativeMethods.vkGetBufferMemoryRequirements(vD, vSB, &br)
        let mutable ba = VkMemAI(sType = 5u, size = br.size, memIdx = findMT mp br.memBits 6u)
        checkVK "vkAllocateMemory(stagingReadback)" (NativeMethods.vkAllocateMemory(vD, &ba, nativeint 0, &vSM2))
        checkVK "vkBindBufferMemory(stagingReadback)" (NativeMethods.vkBindBufferMemory(vD, vSB, vSM2, 0UL))

        let att = VkAttDesc(fmt = 44u, samples = 1u, loadOp = 1u, storeOp = 0u, stLoadOp = 2u, stStoreOp = 1u, finalLayout = 6u)
        let ar = VkAttRef(att = 0u, layout = 2u)

        let hA = GCHandle.Alloc(att, GCHandleType.Pinned)
        let hR = GCHandle.Alloc(ar, GCHandleType.Pinned)
        let sd = VkSubDesc(caCnt = 1u, pCA = hR.AddrOfPinnedObject())
        let hS = GCHandle.Alloc(sd, GCHandleType.Pinned)
        let mutable rpc = VkRPCI(sType = 38u, attCnt = 1u, pAtts = hA.AddrOfPinnedObject(), subCnt = 1u, pSubs = hS.AddrOfPinnedObject())
        checkVK "vkCreateRenderPass" (NativeMethods.vkCreateRenderPass(vD, &rpc, nativeint 0, &vRP))
        hA.Free(); hR.Free(); hS.Free()

        let hV = GCHandle.Alloc([| vOV |], GCHandleType.Pinned)
        let mutable fbc = VkFBCI(sType = 37u, rp = vRP, attCnt = 1u, pAtts = hV.AddrOfPinnedObject(), w = uint32 PW, h = uint32 PH, layers = 1u)
        checkVK "vkCreateFramebuffer" (NativeMethods.vkCreateFramebuffer(vD, &fbc, nativeint 0, &vFB2))
        hV.Free()

        let vSpv = SC.Compile (File.ReadAllText("hello.vert")) 0 "hello.vert"
        let fSpv = SC.Compile (File.ReadAllText("hello.frag")) 1 "hello.frag"

        let mutable vsm = 0UL
        let mutable fsm = 0UL

        let hv = GCHandle.Alloc(vSpv, GCHandleType.Pinned)
        let mutable vsmci = VkSMCI(sType = 16u, codeSz = unativeint vSpv.Length, pCode = hv.AddrOfPinnedObject())
        checkVK "vkCreateShaderModule(vertex)" (NativeMethods.vkCreateShaderModule(vD, &vsmci, nativeint 0, &vsm))
        hv.Free()

        let hf = GCHandle.Alloc(fSpv, GCHandleType.Pinned)
        let mutable fsmci = VkSMCI(sType = 16u, codeSz = unativeint fSpv.Length, pCode = hf.AddrOfPinnedObject())
        checkVK "vkCreateShaderModule(fragment)" (NativeMethods.vkCreateShaderModule(vD, &fsmci, nativeint 0, &fsm))
        hf.Free()

        let ms = Marshal.StringToHGlobalAnsi("main")
        let stg =
            [| VkPSSCI(sType = 18u, stage = 1u, ``module`` = vsm, pName = ms)
               VkPSSCI(sType = 18u, stage = 0x10u, ``module`` = fsm, pName = ms) |]

        let hStg = GCHandle.Alloc(stg, GCHandleType.Pinned)
        let vi = VkPVICI(sType = 19u)
        let ias = VkPIACI(sType = 20u, topo = 3u)
        let vp = VkViewport(w = float32 PW, h = float32 PH, maxD = 1.0f)
        let sc2 = VkRect2D(ext = VkExt2D(w = uint32 PW, h = uint32 PH))

        let hVP = GCHandle.Alloc(vp, GCHandleType.Pinned)
        let hSC = GCHandle.Alloc(sc2, GCHandleType.Pinned)
        let vps = VkPVPCI(sType = 22u, vpCnt = 1u, pVP = hVP.AddrOfPinnedObject(), scCnt = 1u, pSC = hSC.AddrOfPinnedObject())
        let rs = VkPRCI(sType = 23u, lineW = 1.0f)
        let mss = VkPMSCI(sType = 24u, rSamples = 1u)
        let cba = VkPCBAS(wMask = 0xFu)

        let hCBA = GCHandle.Alloc(cba, GCHandleType.Pinned)
        let cbs = VkPCBCI(sType = 26u, attCnt = 1u, pAtts = hCBA.AddrOfPinnedObject())

        let hVI = GCHandle.Alloc(vi, GCHandleType.Pinned)
        let hIA = GCHandle.Alloc(ias, GCHandleType.Pinned)
        let hVPS = GCHandle.Alloc(vps, GCHandleType.Pinned)
        let hRS = GCHandle.Alloc(rs, GCHandleType.Pinned)
        let hMS = GCHandle.Alloc(mss, GCHandleType.Pinned)
        let hCB = GCHandle.Alloc(cbs, GCHandleType.Pinned)

        let mutable plc = VkPLCI(sType = 30u)
        checkVK "vkCreatePipelineLayout" (NativeMethods.vkCreatePipelineLayout(vD, &plc, nativeint 0, &vPL))

        let mutable gpc = VkGPCI(sType = 28u, stageCnt = 2u, pStages = hStg.AddrOfPinnedObject(), pVIS = hVI.AddrOfPinnedObject(), pIAS = hIA.AddrOfPinnedObject(), pVPS = hVPS.AddrOfPinnedObject(), pRast = hRS.AddrOfPinnedObject(), pMS = hMS.AddrOfPinnedObject(), pCBS = hCB.AddrOfPinnedObject(), layout = vPL, rp = vRP)
        checkVK "vkCreateGraphicsPipelines" (NativeMethods.vkCreateGraphicsPipelines(vD, 0UL, 1u, &gpc, nativeint 0, &vPP))

        hStg.Free(); hVI.Free(); hIA.Free(); hVPS.Free(); hRS.Free(); hMS.Free(); hCB.Free(); hCBA.Free(); hVP.Free(); hSC.Free()
        Marshal.FreeHGlobal(ms)
        NativeMethods.vkDestroyShaderModule(vD, vsm, nativeint 0)
        NativeMethods.vkDestroyShaderModule(vD, fsm, nativeint 0)

        let mutable cpc = VkCPCI(sType = 39u, flags = 2u, qfi = uint32 vQF)
        checkVK "vkCreateCommandPool" (NativeMethods.vkCreateCommandPool(vD, &cpc, nativeint 0, &vCP))

        let mutable cbi = VkCBAI(sType = 40u, pool = vCP, cnt = 1u)
        checkVK "vkAllocateCommandBuffers" (NativeMethods.vkAllocateCommandBuffers(vD, &cbi, &vCB))

        let mutable fc = VkFenceCI(sType = 8u, flags = 1u)
        checkVK "vkCreateFence" (NativeMethods.vkCreateFence(vD, &fc, nativeint 0, &vFN))

        vSC <- makeSC PW PH
        vBB <- scBuf vSC
        vST <- makeStagTex PW PH

        dcSetup (dcVis()) vSC (float32 (PW * 2))
        dbg (sprintf "initVK: done vSC=0x%X vBB=0x%X vST=0x%X rp=0x%X fb=0x%X pipe=0x%X" vSC vBB vST vRP vFB2 vPP)
        printfn "[VK] OK"

    let renderVK () =
        let fn = [| vFN |]
        checkVK "vkWaitForFences(begin)" (NativeMethods.vkWaitForFences(vD, 1u, fn, 1u, UInt64.MaxValue))
        checkVK "vkResetFences" (NativeMethods.vkResetFences(vD, 1u, fn))
        checkVK "vkResetCommandBuffer" (NativeMethods.vkResetCommandBuffer(vCB, 0u))

        let mutable bi = VkCBBI(sType = 42u)
        checkVK "vkBeginCommandBuffer" (NativeMethods.vkBeginCommandBuffer(vCB, &bi))

        let cv = VkClearVal(color = VkClearCol(r = 0.15f, g = 0.05f, b = 0.05f, a = 1.0f))
        let hCV = GCHandle.Alloc(cv, GCHandleType.Pinned)

        let mutable rpbi = VkRPBI(sType = 43u, rp = vRP, fb = vFB2, area = VkRect2D(ext = VkExt2D(w = uint32 PW, h = uint32 PH)), cvCnt = 1u, pCV = hCV.AddrOfPinnedObject())
        NativeMethods.vkCmdBeginRenderPass(vCB, &rpbi, 0u)
        NativeMethods.vkCmdBindPipeline(vCB, 0u, vPP)
        NativeMethods.vkCmdDraw(vCB, 3u, 1u, 0u, 0u)
        NativeMethods.vkCmdEndRenderPass(vCB)
        hCV.Free()

        let rg = VkBufImgCopy(bRL = uint32 PW, bIH = uint32 PH, aspect = 1u, lCnt = 1u, eW = uint32 PW, eH = uint32 PH, eD = 1u)
        let hRG = GCHandle.Alloc(rg, GCHandleType.Pinned)
        NativeMethods.vkCmdCopyImageToBuffer(vCB, vOI, 6u, vSB, 1u, hRG.AddrOfPinnedObject())
        hRG.Free()

        checkVK "vkEndCommandBuffer" (NativeMethods.vkEndCommandBuffer(vCB))

        let cbs = [| vCB |]
        let hC = GCHandle.Alloc(cbs, GCHandleType.Pinned)
        let mutable si = VkSubmitInfo(sType = 4u, cbCnt = 1u, pCB = hC.AddrOfPinnedObject())
        checkVK "vkQueueSubmit" (NativeMethods.vkQueueSubmit(vQ, 1u, &si, vFN))
        hC.Free()

        checkVK "vkWaitForFences(end)" (NativeMethods.vkWaitForFences(vD, 1u, fn, 1u, UInt64.MaxValue))

        let mutable vd = nativeint 0
        checkVK "vkMapMemory" (NativeMethods.vkMapMemory(vD, vSM2, 0UL, uint64 (PW * PH * 4), 0u, &vd))

        let m = mapW vST
        let p = PW * 4
        for y in 0 .. (PH - 1) do
            let src = vd + nativeint (y * p)
            let dst = m.pData + nativeint (y * int m.RowPitch)
            NativeMethods.CopyMemory(dst, src, nativeint p)

        unmap vST
        NativeMethods.vkUnmapMemory(vD, vSM2)
        copyRes vBB vST
        scPres vSC

    [<EntryPoint; STAThread>]
    let main _ =
        let mutable exitCode = 0
        try
            dbg "=== START ==="
            printfn "=== GL + D3D11 + VK via DirectComposition (F#) ==="
            makeWin()
            makeD3D()
            makeFac()
            makeDC()
            printfn "--- GL ---"
            initGL()
            printfn "--- D3D11 ---"
            initDX()
            printfn "--- VK ---"
            initVK()
            dcCommit()
            dbg "dcCommit: done"
            printfn "Main loop..."

            let mutable first = true
            let mutable msg = Unchecked.defaultof<MSG>

            while not quit do
                while NativeMethods.PeekMessage(&msg, nativeint 0, 0u, 0u, PM_REM) do
                    if msg.message = WM_QUIT then
                        dbg "WM_QUIT received"
                        quit <- true
                    else
                        NativeMethods.TranslateMessage(&msg) |> ignore
                        NativeMethods.DispatchMessage(&msg) |> ignore

                if not quit then
                    renderGL()
                    renderDX()
                    renderVK()
                    frameNo <- frameNo + 1
                    if first then
                        dbg "First frame rendered"
                        printfn "First frame OK"
                        first <- false
                    elif frameNo % 300 = 0 then
                        dbg (sprintf "frame=%d" frameNo)
                    Thread.Sleep(1)
        with ex ->
            dbg ("Unhandled exception: " + ex.ToString())
            exitCode <- 1

        if vD <> nativeint 0 then
            checkVK "vkDeviceWaitIdle" (NativeMethods.vkDeviceWaitIdle(vD))

        dbg (sprintf "=== END (exit=%d) ===" exitCode)
        printfn "=== END ==="
        exitCode
