program hello;

{$mode delphi}

uses
  Windows, ActiveX, SysUtils;

// ===========================================
// DirectX 9 Types and Constants
// ===========================================
const
  // D3D constants
  D3D_SDK_VERSION                     = 32;
  D3DADAPTER_DEFAULT                  = 0;
  D3DDEVTYPE_HAL                      = 1;
  D3DCREATE_SOFTWARE_VERTEXPROCESSING = $00000020;
  D3DCLEAR_TARGET                     = $00000001;
  D3DPT_TRIANGLELIST                  = 4;
  D3DPOOL_DEFAULT                     = 0;
  D3DSWAPEFFECT_DISCARD               = 1;
  D3DMULTISAMPLE_NONE                 = 0;
  D3DFMT_UNKNOWN                      = 0;

  // FVF flags
  D3DFVF_XYZRHW  = $004;
  D3DFVF_DIFFUSE = $040;

var
  D3DFVF_VERTEX: DWORD;

type
  // D3DFORMAT type
  D3DFORMAT = DWORD;
  D3DMULTISAMPLE_TYPE = DWORD;
  D3DSWAPEFFECT = DWORD;
  D3DDEVTYPE = DWORD;
  D3DPOOL = DWORD;
  D3DPRIMITIVETYPE = DWORD;

  // D3DPRESENT_PARAMETERS structure
  D3DPRESENT_PARAMETERS = record
    BackBufferWidth: UINT;
    BackBufferHeight: UINT;
    BackBufferFormat: D3DFORMAT;
    BackBufferCount: UINT;
    MultiSampleType: D3DMULTISAMPLE_TYPE;
    MultiSampleQuality: DWORD;
    SwapEffect: D3DSWAPEFFECT;
    hDeviceWindow: HWND;
    Windowed: BOOL;
    EnableAutoDepthStencil: BOOL;
    AutoDepthStencilFormat: D3DFORMAT;
    Flags: DWORD;
    FullScreen_RefreshRateInHz: UINT;
    PresentationInterval: UINT;
  end;
  PD3DPRESENT_PARAMETERS = ^D3DPRESENT_PARAMETERS;

  // Vertex structure (transformed with diffuse color)
  VERTEX = record
    x, y, z, rhw: Single;
    color: DWORD;
  end;
  PVERTEX = ^VERTEX;

  // ===========================================
  // COM Interfaces using VTable approach
  // ===========================================

  // Forward declarations
  PIDirect3D9 = ^IDirect3D9Rec;
  PIDirect3DDevice9 = ^IDirect3DDevice9Rec;
  PIDirect3DVertexBuffer9 = ^IDirect3DVertexBuffer9Rec;

  // IDirect3D9 VTable
  IDirect3D9Vtbl = record
    // IUnknown
    QueryInterface: function(Self: Pointer; const riid: TGUID; out ppvObject): HRESULT; stdcall;
    AddRef: function(Self: Pointer): ULONG; stdcall;
    Release: function(Self: Pointer): ULONG; stdcall;
    // IDirect3D9
    RegisterSoftwareDevice: function(Self: Pointer; pInitializeFunction: Pointer): HRESULT; stdcall;
    GetAdapterCount: function(Self: Pointer): UINT; stdcall;
    GetAdapterIdentifier: function(Self: Pointer; Adapter, Flags: UINT; pIdentifier: Pointer): HRESULT; stdcall;
    GetAdapterModeCount: function(Self: Pointer; Adapter: UINT; Format: D3DFORMAT): UINT; stdcall;
    EnumAdapterModes: function(Self: Pointer; Adapter: UINT; Format: D3DFORMAT; Mode: UINT; pMode: Pointer): HRESULT; stdcall;
    GetAdapterDisplayMode: function(Self: Pointer; Adapter: UINT; pMode: Pointer): HRESULT; stdcall;
    CheckDeviceType: function(Self: Pointer; Adapter: UINT; DevType: D3DDEVTYPE; AdapterFormat, BackBufferFormat: D3DFORMAT; bWindowed: BOOL): HRESULT; stdcall;
    CheckDeviceFormat: function(Self: Pointer; Adapter: UINT; DeviceType: D3DDEVTYPE; AdapterFormat: D3DFORMAT; Usage: DWORD; RType: DWORD; CheckFormat: D3DFORMAT): HRESULT; stdcall;
    CheckDeviceMultiSampleType: function(Self: Pointer; Adapter: UINT; DeviceType: D3DDEVTYPE; SurfaceFormat: D3DFORMAT; Windowed: BOOL; MultiSampleType: D3DMULTISAMPLE_TYPE; pQualityLevels: PDWORD): HRESULT; stdcall;
    CheckDepthStencilMatch: function(Self: Pointer; Adapter: UINT; DeviceType: D3DDEVTYPE; AdapterFormat, RenderTargetFormat, DepthStencilFormat: D3DFORMAT): HRESULT; stdcall;
    CheckDeviceFormatConversion: function(Self: Pointer; Adapter: UINT; DeviceType: D3DDEVTYPE; SourceFormat, TargetFormat: D3DFORMAT): HRESULT; stdcall;
    GetDeviceCaps: function(Self: Pointer; Adapter: UINT; DeviceType: D3DDEVTYPE; pCaps: Pointer): HRESULT; stdcall;
    GetAdapterMonitor: function(Self: Pointer; Adapter: UINT): HMONITOR; stdcall;
    CreateDevice: function(Self: Pointer; Adapter: UINT; DeviceType: D3DDEVTYPE; hFocusWindow: HWND; BehaviorFlags: DWORD; pPresentationParameters: PD3DPRESENT_PARAMETERS; out ppReturnedDeviceInterface: PIDirect3DDevice9): HRESULT; stdcall;
  end;
  PIDirect3D9Vtbl = ^IDirect3D9Vtbl;

  IDirect3D9Rec = record
    lpVtbl: PIDirect3D9Vtbl;
  end;

  // IDirect3DDevice9 VTable
  IDirect3DDevice9Vtbl = record
    // IUnknown
    QueryInterface: function(Self: Pointer; const riid: TGUID; out ppvObject): HRESULT; stdcall;
    AddRef: function(Self: Pointer): ULONG; stdcall;
    Release: function(Self: Pointer): ULONG; stdcall;
    // IDirect3DDevice9
    TestCooperativeLevel: function(Self: Pointer): HRESULT; stdcall;
    GetAvailableTextureMem: function(Self: Pointer): UINT; stdcall;
    EvictManagedResources: function(Self: Pointer): HRESULT; stdcall;
    GetDirect3D: function(Self: Pointer; out ppD3D9: PIDirect3D9): HRESULT; stdcall;
    GetDeviceCaps: function(Self: Pointer; pCaps: Pointer): HRESULT; stdcall;
    GetDisplayMode: function(Self: Pointer; iSwapChain: UINT; pMode: Pointer): HRESULT; stdcall;
    GetCreationParameters: function(Self: Pointer; pParameters: Pointer): HRESULT; stdcall;
    SetCursorProperties: function(Self: Pointer; XHotSpot, YHotSpot: UINT; pCursorBitmap: Pointer): HRESULT; stdcall;
    SetCursorPosition: procedure(Self: Pointer; X, Y: Integer; Flags: DWORD); stdcall;
    ShowCursor: function(Self: Pointer; bShow: BOOL): BOOL; stdcall;
    CreateAdditionalSwapChain: function(Self: Pointer; pPresentationParameters: PD3DPRESENT_PARAMETERS; out pSwapChain: Pointer): HRESULT; stdcall;
    GetSwapChain: function(Self: Pointer; iSwapChain: UINT; out pSwapChain: Pointer): HRESULT; stdcall;
    GetNumberOfSwapChains: function(Self: Pointer): UINT; stdcall;
    Reset: function(Self: Pointer; pPresentationParameters: PD3DPRESENT_PARAMETERS): HRESULT; stdcall;
    Present: function(Self: Pointer; pSourceRect, pDestRect: Pointer; hDestWindowOverride: HWND; pDirtyRegion: Pointer): HRESULT; stdcall;
    GetBackBuffer: function(Self: Pointer; iSwapChain, iBackBuffer: UINT; Type_: DWORD; out ppBackBuffer: Pointer): HRESULT; stdcall;
    GetRasterStatus: function(Self: Pointer; iSwapChain: UINT; pRasterStatus: Pointer): HRESULT; stdcall;
    SetDialogBoxMode: function(Self: Pointer; bEnableDialogs: BOOL): HRESULT; stdcall;
    SetGammaRamp: procedure(Self: Pointer; iSwapChain, Flags: UINT; pRamp: Pointer); stdcall;
    GetGammaRamp: procedure(Self: Pointer; iSwapChain: UINT; pRamp: Pointer); stdcall;
    CreateTexture: function(Self: Pointer; Width, Height, Levels: UINT; Usage: DWORD; Format: D3DFORMAT; Pool: D3DPOOL; out ppTexture: Pointer; pSharedHandle: Pointer): HRESULT; stdcall;
    CreateVolumeTexture: function(Self: Pointer; Width, Height, Depth, Levels: UINT; Usage: DWORD; Format: D3DFORMAT; Pool: D3DPOOL; out ppVolumeTexture: Pointer; pSharedHandle: Pointer): HRESULT; stdcall;
    CreateCubeTexture: function(Self: Pointer; EdgeLength, Levels: UINT; Usage: DWORD; Format: D3DFORMAT; Pool: D3DPOOL; out ppCubeTexture: Pointer; pSharedHandle: Pointer): HRESULT; stdcall;
    CreateVertexBuffer: function(Self: Pointer; Length: UINT; Usage, FVF: DWORD; Pool: D3DPOOL; out ppVertexBuffer: PIDirect3DVertexBuffer9; pSharedHandle: Pointer): HRESULT; stdcall;
    CreateIndexBuffer: function(Self: Pointer; Length: UINT; Usage: DWORD; Format: D3DFORMAT; Pool: D3DPOOL; out ppIndexBuffer: Pointer; pSharedHandle: Pointer): HRESULT; stdcall;
    CreateRenderTarget: function(Self: Pointer; Width, Height: UINT; Format: D3DFORMAT; MultiSample: D3DMULTISAMPLE_TYPE; MultisampleQuality: DWORD; Lockable: BOOL; out ppSurface: Pointer; pSharedHandle: Pointer): HRESULT; stdcall;
    CreateDepthStencilSurface: function(Self: Pointer; Width, Height: UINT; Format: D3DFORMAT; MultiSample: D3DMULTISAMPLE_TYPE; MultisampleQuality: DWORD; Discard: BOOL; out ppSurface: Pointer; pSharedHandle: Pointer): HRESULT; stdcall;
    UpdateSurface: function(Self: Pointer; pSourceSurface: Pointer; pSourceRect: Pointer; pDestinationSurface: Pointer; pDestPoint: Pointer): HRESULT; stdcall;
    UpdateTexture: function(Self: Pointer; pSourceTexture, pDestinationTexture: Pointer): HRESULT; stdcall;
    GetRenderTargetData: function(Self: Pointer; pRenderTarget, pDestSurface: Pointer): HRESULT; stdcall;
    GetFrontBufferData: function(Self: Pointer; iSwapChain: UINT; pDestSurface: Pointer): HRESULT; stdcall;
    StretchRect: function(Self: Pointer; pSourceSurface: Pointer; pSourceRect: Pointer; pDestSurface: Pointer; pDestRect: Pointer; Filter: DWORD): HRESULT; stdcall;
    ColorFill: function(Self: Pointer; pSurface: Pointer; pRect: Pointer; color: DWORD): HRESULT; stdcall;
    CreateOffscreenPlainSurface: function(Self: Pointer; Width, Height: UINT; Format: D3DFORMAT; Pool: D3DPOOL; out ppSurface: Pointer; pSharedHandle: Pointer): HRESULT; stdcall;
    SetRenderTarget: function(Self: Pointer; RenderTargetIndex: DWORD; pRenderTarget: Pointer): HRESULT; stdcall;
    GetRenderTarget: function(Self: Pointer; RenderTargetIndex: DWORD; out ppRenderTarget: Pointer): HRESULT; stdcall;
    SetDepthStencilSurface: function(Self: Pointer; pNewZStencil: Pointer): HRESULT; stdcall;
    GetDepthStencilSurface: function(Self: Pointer; out ppZStencilSurface: Pointer): HRESULT; stdcall;
    BeginScene: function(Self: Pointer): HRESULT; stdcall;
    EndScene: function(Self: Pointer): HRESULT; stdcall;
    Clear: function(Self: Pointer; Count: DWORD; pRects: Pointer; Flags, Color: DWORD; Z: Single; Stencil: DWORD): HRESULT; stdcall;
    SetTransform: function(Self: Pointer; State: DWORD; pMatrix: Pointer): HRESULT; stdcall;
    GetTransform: function(Self: Pointer; State: DWORD; pMatrix: Pointer): HRESULT; stdcall;
    MultiplyTransform: function(Self: Pointer; State: DWORD; pMatrix: Pointer): HRESULT; stdcall;
    SetViewport: function(Self: Pointer; pViewport: Pointer): HRESULT; stdcall;
    GetViewport: function(Self: Pointer; pViewport: Pointer): HRESULT; stdcall;
    SetMaterial: function(Self: Pointer; pMaterial: Pointer): HRESULT; stdcall;
    GetMaterial: function(Self: Pointer; pMaterial: Pointer): HRESULT; stdcall;
    SetLight: function(Self: Pointer; Index: DWORD; pLight: Pointer): HRESULT; stdcall;
    GetLight: function(Self: Pointer; Index: DWORD; pLight: Pointer): HRESULT; stdcall;
    LightEnable: function(Self: Pointer; Index: DWORD; Enable: BOOL): HRESULT; stdcall;
    GetLightEnable: function(Self: Pointer; Index: DWORD; out pEnable: BOOL): HRESULT; stdcall;
    SetClipPlane: function(Self: Pointer; Index: DWORD; pPlane: Pointer): HRESULT; stdcall;
    GetClipPlane: function(Self: Pointer; Index: DWORD; pPlane: Pointer): HRESULT; stdcall;
    SetRenderState: function(Self: Pointer; State, Value: DWORD): HRESULT; stdcall;
    GetRenderState: function(Self: Pointer; State: DWORD; out pValue: DWORD): HRESULT; stdcall;
    CreateStateBlock: function(Self: Pointer; Type_: DWORD; out ppSB: Pointer): HRESULT; stdcall;
    BeginStateBlock: function(Self: Pointer): HRESULT; stdcall;
    EndStateBlock: function(Self: Pointer; out ppSB: Pointer): HRESULT; stdcall;
    SetClipStatus: function(Self: Pointer; pClipStatus: Pointer): HRESULT; stdcall;
    GetClipStatus: function(Self: Pointer; pClipStatus: Pointer): HRESULT; stdcall;
    GetTexture: function(Self: Pointer; Stage: DWORD; out ppTexture: Pointer): HRESULT; stdcall;
    SetTexture: function(Self: Pointer; Stage: DWORD; pTexture: Pointer): HRESULT; stdcall;
    GetTextureStageState: function(Self: Pointer; Stage, Type_: DWORD; out pValue: DWORD): HRESULT; stdcall;
    SetTextureStageState: function(Self: Pointer; Stage, Type_, Value: DWORD): HRESULT; stdcall;
    GetSamplerState: function(Self: Pointer; Sampler, Type_: DWORD; out pValue: DWORD): HRESULT; stdcall;
    SetSamplerState: function(Self: Pointer; Sampler, Type_, Value: DWORD): HRESULT; stdcall;
    ValidateDevice: function(Self: Pointer; out pNumPasses: DWORD): HRESULT; stdcall;
    SetPaletteEntries: function(Self: Pointer; PaletteNumber: UINT; pEntries: Pointer): HRESULT; stdcall;
    GetPaletteEntries: function(Self: Pointer; PaletteNumber: UINT; pEntries: Pointer): HRESULT; stdcall;
    SetCurrentTexturePalette: function(Self: Pointer; PaletteNumber: UINT): HRESULT; stdcall;
    GetCurrentTexturePalette: function(Self: Pointer; out PaletteNumber: UINT): HRESULT; stdcall;
    SetScissorRect: function(Self: Pointer; pRect: Pointer): HRESULT; stdcall;
    GetScissorRect: function(Self: Pointer; pRect: Pointer): HRESULT; stdcall;
    SetSoftwareVertexProcessing: function(Self: Pointer; bSoftware: BOOL): HRESULT; stdcall;
    GetSoftwareVertexProcessing: function(Self: Pointer): BOOL; stdcall;
    SetNPatchMode: function(Self: Pointer; nSegments: Single): HRESULT; stdcall;
    GetNPatchMode: function(Self: Pointer): Single; stdcall;
    DrawPrimitive: function(Self: Pointer; PrimitiveType: D3DPRIMITIVETYPE; StartVertex, PrimitiveCount: UINT): HRESULT; stdcall;
    DrawIndexedPrimitive: function(Self: Pointer; PrimitiveType: D3DPRIMITIVETYPE; BaseVertexIndex: Integer; MinVertexIndex, NumVertices, startIndex, primCount: UINT): HRESULT; stdcall;
    DrawPrimitiveUP: function(Self: Pointer; PrimitiveType: D3DPRIMITIVETYPE; PrimitiveCount: UINT; pVertexStreamZeroData: Pointer; VertexStreamZeroStride: UINT): HRESULT; stdcall;
    DrawIndexedPrimitiveUP: function(Self: Pointer; PrimitiveType: D3DPRIMITIVETYPE; MinVertexIndex, NumVertices, PrimitiveCount: UINT; pIndexData: Pointer; IndexDataFormat: D3DFORMAT; pVertexStreamZeroData: Pointer; VertexStreamZeroStride: UINT): HRESULT; stdcall;
    ProcessVertices: function(Self: Pointer; SrcStartIndex, DestIndex, VertexCount: UINT; pDestBuffer: Pointer; pVertexDecl: Pointer; Flags: DWORD): HRESULT; stdcall;
    CreateVertexDeclaration: function(Self: Pointer; pVertexElements: Pointer; out ppDecl: Pointer): HRESULT; stdcall;
    SetVertexDeclaration: function(Self: Pointer; pDecl: Pointer): HRESULT; stdcall;
    GetVertexDeclaration: function(Self: Pointer; out ppDecl: Pointer): HRESULT; stdcall;
    SetFVF: function(Self: Pointer; FVF: DWORD): HRESULT; stdcall;
    GetFVF: function(Self: Pointer; out pFVF: DWORD): HRESULT; stdcall;
    CreateVertexShader: function(Self: Pointer; pFunction: Pointer; out ppShader: Pointer): HRESULT; stdcall;
    SetVertexShader: function(Self: Pointer; pShader: Pointer): HRESULT; stdcall;
    GetVertexShader: function(Self: Pointer; out ppShader: Pointer): HRESULT; stdcall;
    SetVertexShaderConstantF: function(Self: Pointer; StartRegister: UINT; pConstantData: Pointer; Vector4fCount: UINT): HRESULT; stdcall;
    GetVertexShaderConstantF: function(Self: Pointer; StartRegister: UINT; pConstantData: Pointer; Vector4fCount: UINT): HRESULT; stdcall;
    SetVertexShaderConstantI: function(Self: Pointer; StartRegister: UINT; pConstantData: Pointer; Vector4iCount: UINT): HRESULT; stdcall;
    GetVertexShaderConstantI: function(Self: Pointer; StartRegister: UINT; pConstantData: Pointer; Vector4iCount: UINT): HRESULT; stdcall;
    SetVertexShaderConstantB: function(Self: Pointer; StartRegister: UINT; pConstantData: Pointer; BoolCount: UINT): HRESULT; stdcall;
    GetVertexShaderConstantB: function(Self: Pointer; StartRegister: UINT; pConstantData: Pointer; BoolCount: UINT): HRESULT; stdcall;
    SetStreamSource: function(Self: Pointer; StreamNumber: UINT; pStreamData: PIDirect3DVertexBuffer9; OffsetInBytes, Stride: UINT): HRESULT; stdcall;
    GetStreamSource: function(Self: Pointer; StreamNumber: UINT; out ppStreamData: PIDirect3DVertexBuffer9; out pOffsetInBytes, pStride: UINT): HRESULT; stdcall;
    SetStreamSourceFreq: function(Self: Pointer; StreamNumber, Setting: UINT): HRESULT; stdcall;
    GetStreamSourceFreq: function(Self: Pointer; StreamNumber: UINT; out pSetting: UINT): HRESULT; stdcall;
    SetIndices: function(Self: Pointer; pIndexData: Pointer): HRESULT; stdcall;
    GetIndices: function(Self: Pointer; out ppIndexData: Pointer): HRESULT; stdcall;
    CreatePixelShader: function(Self: Pointer; pFunction: Pointer; out ppShader: Pointer): HRESULT; stdcall;
    SetPixelShader: function(Self: Pointer; pShader: Pointer): HRESULT; stdcall;
    GetPixelShader: function(Self: Pointer; out ppShader: Pointer): HRESULT; stdcall;
    SetPixelShaderConstantF: function(Self: Pointer; StartRegister: UINT; pConstantData: Pointer; Vector4fCount: UINT): HRESULT; stdcall;
    GetPixelShaderConstantF: function(Self: Pointer; StartRegister: UINT; pConstantData: Pointer; Vector4fCount: UINT): HRESULT; stdcall;
    SetPixelShaderConstantI: function(Self: Pointer; StartRegister: UINT; pConstantData: Pointer; Vector4iCount: UINT): HRESULT; stdcall;
    GetPixelShaderConstantI: function(Self: Pointer; StartRegister: UINT; pConstantData: Pointer; Vector4iCount: UINT): HRESULT; stdcall;
    SetPixelShaderConstantB: function(Self: Pointer; StartRegister: UINT; pConstantData: Pointer; BoolCount: UINT): HRESULT; stdcall;
    GetPixelShaderConstantB: function(Self: Pointer; StartRegister: UINT; pConstantData: Pointer; BoolCount: UINT): HRESULT; stdcall;
    DrawRectPatch: function(Self: Pointer; Handle: UINT; pNumSegs, pRectPatchInfo: Pointer): HRESULT; stdcall;
    DrawTriPatch: function(Self: Pointer; Handle: UINT; pNumSegs, pTriPatchInfo: Pointer): HRESULT; stdcall;
    DeletePatch: function(Self: Pointer; Handle: UINT): HRESULT; stdcall;
    CreateQuery: function(Self: Pointer; Type_: DWORD; out ppQuery: Pointer): HRESULT; stdcall;
  end;
  PIDirect3DDevice9Vtbl = ^IDirect3DDevice9Vtbl;

  IDirect3DDevice9Rec = record
    lpVtbl: PIDirect3DDevice9Vtbl;
  end;

  // IDirect3DVertexBuffer9 VTable
  IDirect3DVertexBuffer9Vtbl = record
    // IUnknown
    QueryInterface: function(Self: Pointer; const riid: TGUID; out ppvObject): HRESULT; stdcall;
    AddRef: function(Self: Pointer): ULONG; stdcall;
    Release: function(Self: Pointer): ULONG; stdcall;
    // IDirect3DResource9
    GetDevice: function(Self: Pointer; out ppDevice: PIDirect3DDevice9): HRESULT; stdcall;
    SetPrivateData: function(Self: Pointer; const refguid: TGUID; pData: Pointer; SizeOfData, Flags: DWORD): HRESULT; stdcall;
    GetPrivateData: function(Self: Pointer; const refguid: TGUID; pData: Pointer; out pSizeOfData: DWORD): HRESULT; stdcall;
    FreePrivateData: function(Self: Pointer; const refguid: TGUID): HRESULT; stdcall;
    SetPriority: function(Self: Pointer; PriorityNew: DWORD): DWORD; stdcall;
    GetPriority: function(Self: Pointer): DWORD; stdcall;
    PreLoad: procedure(Self: Pointer); stdcall;
    GetType: function(Self: Pointer): DWORD; stdcall;
    // IDirect3DVertexBuffer9
    Lock: function(Self: Pointer; OffsetToLock, SizeToLock: UINT; out ppbData: Pointer; Flags: DWORD): HRESULT; stdcall;
    Unlock: function(Self: Pointer): HRESULT; stdcall;
    GetDesc: function(Self: Pointer; out pDesc: Pointer): HRESULT; stdcall;
  end;
  PIDirect3DVertexBuffer9Vtbl = ^IDirect3DVertexBuffer9Vtbl;

  IDirect3DVertexBuffer9Rec = record
    lpVtbl: PIDirect3DVertexBuffer9Vtbl;
  end;

// ===========================================
// External function declaration
// ===========================================
function Direct3DCreate9(SDKVersion: UINT): PIDirect3D9; stdcall; external 'd3d9.dll';

// ===========================================
// Global variables
// ===========================================
var
  g_hWnd: HWND = 0;
  g_pD3D: PIDirect3D9 = nil;
  g_pd3dDevice: PIDirect3DDevice9 = nil;
  g_pVB: PIDirect3DVertexBuffer9 = nil;

// ===========================================
// D3DCOLOR_XRGB macro replacement
// ===========================================
function D3DCOLOR_XRGB(r, g, b: Byte): DWORD;
begin
  Result := $FF000000 or (DWORD(r) shl 16) or (DWORD(g) shl 8) or DWORD(b);
end;

// ===========================================
// Window Procedure
// ===========================================
function WndProc(hWnd: HWND; message: UINT; wParam: WPARAM; lParam: LPARAM): LRESULT; stdcall;
begin
  case message of
    WM_DESTROY:
      begin
        PostQuitMessage(0);
        Result := 0;
      end;
  else
    Result := DefWindowProc(hWnd, message, wParam, lParam);
  end;
end;

// ===========================================
// Initialize Window
// ===========================================
function InitWindow(hInstance: HINST; nCmdShow: Integer): HRESULT;
var
  wcex: WNDCLASSEX;
begin
  ZeroMemory(@wcex, SizeOf(wcex));
  wcex.cbSize := SizeOf(WNDCLASSEX);
  wcex.style := CS_HREDRAW or CS_VREDRAW;
  wcex.lpfnWndProc := @WndProc;
  wcex.hInstance := hInstance;
  wcex.hCursor := LoadCursor(0, IDC_ARROW);
  wcex.hbrBackground := COLOR_WINDOW + 1;
  wcex.lpszClassName := 'D3D9WindowClass';

  if RegisterClassEx(wcex) = 0 then
  begin
    Result := E_FAIL;
    Exit;
  end;

  g_hWnd := CreateWindow('D3D9WindowClass', 'Hello, World!',
    WS_OVERLAPPEDWINDOW,
    CW_USEDEFAULT, CW_USEDEFAULT, 640, 480,
    0, 0, hInstance, nil);

  if g_hWnd = 0 then
  begin
    Result := E_FAIL;
    Exit;
  end;

  ShowWindow(g_hWnd, nCmdShow);
  UpdateWindow(g_hWnd);
  Result := S_OK;
end;

// ===========================================
// Initialize Direct3D
// ===========================================
function InitD3D: HRESULT;
var
  d3dpp: D3DPRESENT_PARAMETERS;
begin
  // Create Direct3D9 object
  g_pD3D := Direct3DCreate9(D3D_SDK_VERSION);
  if g_pD3D = nil then
  begin
    Result := E_FAIL;
    Exit;
  end;

  // Set up present parameters
  ZeroMemory(@d3dpp, SizeOf(d3dpp));
  d3dpp.Windowed := True;
  d3dpp.SwapEffect := D3DSWAPEFFECT_DISCARD;
  d3dpp.BackBufferFormat := D3DFMT_UNKNOWN;
  d3dpp.hDeviceWindow := g_hWnd;

  // Create device
  Result := g_pD3D^.lpVtbl^.CreateDevice(
    g_pD3D,
    D3DADAPTER_DEFAULT,
    D3DDEVTYPE_HAL,
    g_hWnd,
    D3DCREATE_SOFTWARE_VERTEXPROCESSING,
    @d3dpp,
    g_pd3dDevice
  );

  if Failed(Result) then
    Exit;

  Result := S_OK;
end;

// ===========================================
// Initialize Vertex Buffer
// ===========================================
function InitVB: HRESULT;
var
  vertices: array[0..2] of VERTEX;
  pVertices: PVERTEX;
begin
  // Define triangle vertices
  vertices[0].x := 320.0; vertices[0].y := 100.0; vertices[0].z := 0.0; vertices[0].rhw := 1.0;
  vertices[0].color := D3DCOLOR_XRGB(255, 0, 0);  // Red

  vertices[1].x := 520.0; vertices[1].y := 380.0; vertices[1].z := 0.0; vertices[1].rhw := 1.0;
  vertices[1].color := D3DCOLOR_XRGB(0, 255, 0);  // Green

  vertices[2].x := 120.0; vertices[2].y := 380.0; vertices[2].z := 0.0; vertices[2].rhw := 1.0;
  vertices[2].color := D3DCOLOR_XRGB(0, 0, 255);  // Blue

  // Create vertex buffer
  Result := g_pd3dDevice^.lpVtbl^.CreateVertexBuffer(
    g_pd3dDevice,
    3 * SizeOf(VERTEX),
    0,
    D3DFVF_VERTEX,
    D3DPOOL_DEFAULT,
    g_pVB,
    nil
  );

  if Failed(Result) then
    Exit;

  // Lock and fill vertex buffer
  Result := g_pVB^.lpVtbl^.Lock(g_pVB, 0, SizeOf(vertices), Pointer(pVertices), 0);
  if Failed(Result) then
    Exit;

  Move(vertices, pVertices^, SizeOf(vertices));

  g_pVB^.lpVtbl^.Unlock(g_pVB);

  Result := S_OK;
end;

// ===========================================
// Cleanup
// ===========================================
procedure Cleanup;
begin
  if g_pVB <> nil then
  begin
    g_pVB^.lpVtbl^.Release(g_pVB);
    g_pVB := nil;
  end;

  if g_pd3dDevice <> nil then
  begin
    g_pd3dDevice^.lpVtbl^.Release(g_pd3dDevice);
    g_pd3dDevice := nil;
  end;

  if g_pD3D <> nil then
  begin
    g_pD3D^.lpVtbl^.Release(g_pD3D);
    g_pD3D := nil;
  end;
end;

// ===========================================
// Render
// ===========================================
procedure Render;
begin
  if g_pd3dDevice = nil then
    Exit;

  // Clear the backbuffer to white
  g_pd3dDevice^.lpVtbl^.Clear(g_pd3dDevice, 0, nil, D3DCLEAR_TARGET,
    D3DCOLOR_XRGB(255, 255, 255), 1.0, 0);

  // Begin scene
  if Succeeded(g_pd3dDevice^.lpVtbl^.BeginScene(g_pd3dDevice)) then
  begin
    // Set stream source
    g_pd3dDevice^.lpVtbl^.SetStreamSource(g_pd3dDevice, 0, g_pVB, 0, SizeOf(VERTEX));

    // Set FVF
    g_pd3dDevice^.lpVtbl^.SetFVF(g_pd3dDevice, D3DFVF_VERTEX);

    // Draw triangle
    g_pd3dDevice^.lpVtbl^.DrawPrimitive(g_pd3dDevice, D3DPT_TRIANGLELIST, 0, 1);

    // End scene
    g_pd3dDevice^.lpVtbl^.EndScene(g_pd3dDevice);
  end;

  // Present
  g_pd3dDevice^.lpVtbl^.Present(g_pd3dDevice, nil, nil, 0, nil);
end;

// ===========================================
// Main
// ===========================================
var
  msg: TMsg;
begin
  // Initialize FVF
  D3DFVF_VERTEX := D3DFVF_XYZRHW or D3DFVF_DIFFUSE;

  if Failed(InitWindow(hInstance, CmdShow)) then
    Halt(0);

  if Failed(InitD3D) then
  begin
    Cleanup;
    Halt(0);
  end;

  if Failed(InitVB) then
  begin
    Cleanup;
    Halt(0);
  end;

  // Message loop
  ZeroMemory(@msg, SizeOf(msg));
  while msg.message <> WM_QUIT do
  begin
    if PeekMessage(msg, 0, 0, 0, PM_REMOVE) then
    begin
      TranslateMessage(msg);
      DispatchMessage(msg);
    end
    else
    begin
      Render;
    end;
  end;

  Cleanup;
end.
