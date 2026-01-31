program hello;

{$mode delphi}

uses
  Windows, ActiveX, SysUtils;

// ===========================================
// DirectX 10 Types and Constants
// ===========================================
type
  DXGI_FORMAT = Cardinal;
  D3D10_DRIVER_TYPE = Cardinal;
  D3D10_USAGE = Cardinal;
  D3D10_BIND_FLAG = Cardinal;
  D3D10_CPU_ACCESS_FLAG = Cardinal;
  D3D10_PRIMITIVE_TOPOLOGY = Cardinal;

const
  // DXGI_FORMAT
  DXGI_FORMAT_R32G32B32_FLOAT    = 6;
  DXGI_FORMAT_R32G32B32A32_FLOAT = 2;
  DXGI_FORMAT_R8G8B8A8_UNORM     = 28;

  // D3D10_DRIVER_TYPE
  D3D10_DRIVER_TYPE_HARDWARE  = 1;
  D3D10_DRIVER_TYPE_WARP      = 2;
  D3D10_DRIVER_TYPE_REFERENCE = 3;

  // D3D10_USAGE
  D3D10_USAGE_DEFAULT = 0;

  // D3D10_BIND_FLAG
  D3D10_BIND_VERTEX_BUFFER = $1;

  // D3D10_PRIMITIVE_TOPOLOGY
  D3D10_PRIMITIVE_TOPOLOGY_TRIANGLELIST = 4;

  // DXGI_USAGE
  DXGI_USAGE_RENDER_TARGET_OUTPUT = $20;

  // D3D10_INPUT_PER_VERTEX_DATA
  D3D10_INPUT_PER_VERTEX_DATA = 0;

  // D3D10_SDK_VERSION (different from D3D11)
  D3D10_SDK_VERSION = 29;

  // D3DCOMPILE flags
  D3DCOMPILE_ENABLE_STRICTNESS = $800;

  // GUIDs - D3D10 specific
  IID_ID3D10Texture2D: TGUID = '{9B7E4C04-342C-4106-A19F-4F2704F689F0}';

type
  // Structures
  DXGI_RATIONAL = record
    Numerator: UINT;
    Denominator: UINT;
  end;

  DXGI_MODE_DESC = record
    Width: UINT;
    Height: UINT;
    RefreshRate: DXGI_RATIONAL;
    Format: DXGI_FORMAT;
    ScanlineOrdering: UINT;
    Scaling: UINT;
  end;

  DXGI_SAMPLE_DESC = record
    Count: UINT;
    Quality: UINT;
  end;

  DXGI_SWAP_CHAIN_DESC = record
    BufferDesc: DXGI_MODE_DESC;
    SampleDesc: DXGI_SAMPLE_DESC;
    BufferUsage: UINT;
    BufferCount: UINT;
    OutputWindow: HWND;
    Windowed: BOOL;
    SwapEffect: UINT;
    Flags: UINT;
  end;

  // D3D10_VIEWPORT uses UINT for Width/Height (different from D3D11 which uses Single)
  D3D10_VIEWPORT = record
    TopLeftX: Integer;
    TopLeftY: Integer;
    Width: UINT;
    Height: UINT;
    MinDepth: Single;
    MaxDepth: Single;
  end;

  D3D10_INPUT_ELEMENT_DESC = record
    SemanticName: PAnsiChar;
    SemanticIndex: UINT;
    Format: DXGI_FORMAT;
    InputSlot: UINT;
    AlignedByteOffset: UINT;
    InputSlotClass: UINT;
    InstanceDataStepRate: UINT;
  end;
  PD3D10_INPUT_ELEMENT_DESC = ^D3D10_INPUT_ELEMENT_DESC;

  // D3D10_BUFFER_DESC has no StructureByteStride (different from D3D11)
  D3D10_BUFFER_DESC = record
    ByteWidth: UINT;
    Usage: D3D10_USAGE;
    BindFlags: UINT;
    CPUAccessFlags: UINT;
    MiscFlags: UINT;
  end;

  D3D10_SUBRESOURCE_DATA = record
    pSysMem: Pointer;
    SysMemPitch: UINT;
    SysMemSlicePitch: UINT;
  end;

  VERTEX = record
    x, y, z: Single;
    r, g, b, a: Single;
  end;

  // ===========================================
  // COM Interfaces using VTable approach
  // ===========================================
  
  // ID3DBlob VTable
  ID3DBlobVtbl = record
    // IUnknown
    QueryInterface: function(Self: Pointer; const riid: TGUID; out ppvObject): HRESULT; stdcall;
    AddRef: function(Self: Pointer): ULONG; stdcall;
    Release: function(Self: Pointer): ULONG; stdcall;
    // ID3DBlob
    GetBufferPointer: function(Self: Pointer): Pointer; stdcall;
    GetBufferSize: function(Self: Pointer): SIZE_T; stdcall;
  end;
  PID3DBlobVtbl = ^ID3DBlobVtbl;
  
  ID3DBlob = record
    lpVtbl: PID3DBlobVtbl;
  end;
  PID3DBlob = ^ID3DBlob;
  PPID3DBlob = ^PID3DBlob;

  // ID3D10Device VTable
  // In D3D10, there's no DeviceContext - device handles rendering directly
  ID3D10DeviceVtbl = record
    // IUnknown (0-2)
    QueryInterface: function(Self: Pointer; const riid: TGUID; out ppvObject): HRESULT; stdcall;
    AddRef: function(Self: Pointer): ULONG; stdcall;
    Release: function(Self: Pointer): ULONG; stdcall;
    // ID3D10Device (3+)
    VSSetConstantBuffers: procedure(Self: Pointer; StartSlot, NumBuffers: UINT; ppConstantBuffers: Pointer); stdcall;  // 3
    PSSetShaderResources: procedure(Self: Pointer; StartSlot, NumViews: UINT; ppShaderResourceViews: Pointer); stdcall; // 4
    PSSetShader: procedure(Self: Pointer; pPixelShader: Pointer); stdcall;  // 5 - No ClassInstances in D3D10
    PSSetSamplers: procedure(Self: Pointer; StartSlot, NumSamplers: UINT; ppSamplers: Pointer); stdcall;  // 6
    VSSetShader: procedure(Self: Pointer; pVertexShader: Pointer); stdcall;  // 7 - No ClassInstances in D3D10
    DrawIndexed: procedure(Self: Pointer; IndexCount, StartIndexLocation: UINT; BaseVertexLocation: Integer); stdcall;  // 8
    Draw: procedure(Self: Pointer; VertexCount, StartVertexLocation: UINT); stdcall;  // 9
    PSSetConstantBuffers: procedure(Self: Pointer; StartSlot, NumBuffers: UINT; ppConstantBuffers: Pointer); stdcall;  // 10
    IASetInputLayout: procedure(Self: Pointer; pInputLayout: Pointer); stdcall;  // 11
    IASetVertexBuffers: procedure(Self: Pointer; StartSlot, NumBuffers: UINT; ppVertexBuffers: Pointer; pStrides, pOffsets: PUINT); stdcall;  // 12
    IASetIndexBuffer: procedure(Self: Pointer; pIndexBuffer: Pointer; Format: DXGI_FORMAT; Offset: UINT); stdcall;  // 13
    DrawIndexedInstanced: procedure(Self: Pointer; IndexCountPerInstance, InstanceCount, StartIndexLocation: UINT; BaseVertexLocation: Integer; StartInstanceLocation: UINT); stdcall;  // 14
    DrawInstanced: procedure(Self: Pointer; VertexCountPerInstance, InstanceCount, StartVertexLocation, StartInstanceLocation: UINT); stdcall;  // 15
    GSSetConstantBuffers: procedure(Self: Pointer; StartSlot, NumBuffers: UINT; ppConstantBuffers: Pointer); stdcall;  // 16
    GSSetShader: procedure(Self: Pointer; pShader: Pointer); stdcall;  // 17
    IASetPrimitiveTopology: procedure(Self: Pointer; Topology: D3D10_PRIMITIVE_TOPOLOGY); stdcall;  // 18
    VSSetShaderResources: procedure(Self: Pointer; StartSlot, NumViews: UINT; ppShaderResourceViews: Pointer); stdcall;  // 19
    VSSetSamplers: procedure(Self: Pointer; StartSlot, NumSamplers: UINT; ppSamplers: Pointer); stdcall;  // 20
    SetPredication: procedure(Self: Pointer; pPredicate: Pointer; PredicateValue: BOOL); stdcall;  // 21
    GSSetShaderResources: procedure(Self: Pointer; StartSlot, NumViews: UINT; ppShaderResourceViews: Pointer); stdcall;  // 22
    GSSetSamplers: procedure(Self: Pointer; StartSlot, NumSamplers: UINT; ppSamplers: Pointer); stdcall;  // 23
    OMSetRenderTargets: procedure(Self: Pointer; NumViews: UINT; ppRenderTargetViews: Pointer; pDepthStencilView: Pointer); stdcall;  // 24
    OMSetBlendState: procedure(Self: Pointer; pBlendState: Pointer; BlendFactor: PSingle; SampleMask: UINT); stdcall;  // 25
    OMSetDepthStencilState: procedure(Self: Pointer; pDepthStencilState: Pointer; StencilRef: UINT); stdcall;  // 26
    SOSetTargets: procedure(Self: Pointer; NumBuffers: UINT; ppSOTargets: Pointer; pOffsets: PUINT); stdcall;  // 27
    DrawAuto: procedure(Self: Pointer); stdcall;  // 28
    RSSetState: procedure(Self: Pointer; pRasterizerState: Pointer); stdcall;  // 29
    RSSetViewports: procedure(Self: Pointer; NumViewports: UINT; pViewports: Pointer); stdcall;  // 30
    RSSetScissorRects: procedure(Self: Pointer; NumRects: UINT; pRects: Pointer); stdcall;  // 31
    CopySubresourceRegion: procedure(Self: Pointer; pDstResource: Pointer; DstSubresource, DstX, DstY, DstZ: UINT; pSrcResource: Pointer; SrcSubresource: UINT; pSrcBox: Pointer); stdcall;  // 32
    CopyResource: procedure(Self: Pointer; pDstResource, pSrcResource: Pointer); stdcall;  // 33
    UpdateSubresource: procedure(Self: Pointer; pDstResource: Pointer; DstSubresource: UINT; pDstBox: Pointer; pSrcData: Pointer; SrcRowPitch, SrcDepthPitch: UINT); stdcall;  // 34
    ClearRenderTargetView: procedure(Self: Pointer; pRenderTargetView: Pointer; ColorRGBA: PSingle); stdcall;  // 35
    ClearDepthStencilView: procedure(Self: Pointer; pDepthStencilView: Pointer; ClearFlags: UINT; Depth: Single; Stencil: Byte); stdcall;  // 36
    GenerateMips: procedure(Self: Pointer; pShaderResourceView: Pointer); stdcall;  // 37
    ResolveSubresource: procedure(Self: Pointer; pDstResource: Pointer; DstSubresource: UINT; pSrcResource: Pointer; SrcSubresource: UINT; Format: DXGI_FORMAT); stdcall;  // 38
    VSGetConstantBuffers: procedure(Self: Pointer; StartSlot, NumBuffers: UINT; ppConstantBuffers: Pointer); stdcall;  // 39
    PSGetShaderResources: procedure(Self: Pointer; StartSlot, NumViews: UINT; ppShaderResourceViews: Pointer); stdcall;  // 40
    PSGetShader: procedure(Self: Pointer; out ppPixelShader: Pointer); stdcall;  // 41
    PSGetSamplers: procedure(Self: Pointer; StartSlot, NumSamplers: UINT; ppSamplers: Pointer); stdcall;  // 42
    VSGetShader: procedure(Self: Pointer; out ppVertexShader: Pointer); stdcall;  // 43
    PSGetConstantBuffers: procedure(Self: Pointer; StartSlot, NumBuffers: UINT; ppConstantBuffers: Pointer); stdcall;  // 44
    IAGetInputLayout: procedure(Self: Pointer; out ppInputLayout: Pointer); stdcall;  // 45
    IAGetVertexBuffers: procedure(Self: Pointer; StartSlot, NumBuffers: UINT; ppVertexBuffers: Pointer; pStrides, pOffsets: PUINT); stdcall;  // 46
    IAGetIndexBuffer: procedure(Self: Pointer; out pIndexBuffer: Pointer; out Format: DXGI_FORMAT; out Offset: UINT); stdcall;  // 47
    GSGetConstantBuffers: procedure(Self: Pointer; StartSlot, NumBuffers: UINT; ppConstantBuffers: Pointer); stdcall;  // 48
    GSGetShader: procedure(Self: Pointer; out ppGeometryShader: Pointer); stdcall;  // 49
    IAGetPrimitiveTopology: procedure(Self: Pointer; out pTopology: D3D10_PRIMITIVE_TOPOLOGY); stdcall;  // 50
    VSGetShaderResources: procedure(Self: Pointer; StartSlot, NumViews: UINT; ppShaderResourceViews: Pointer); stdcall;  // 51
    VSGetSamplers: procedure(Self: Pointer; StartSlot, NumSamplers: UINT; ppSamplers: Pointer); stdcall;  // 52
    GetPredication: procedure(Self: Pointer; out ppPredicate: Pointer; out pPredicateValue: BOOL); stdcall;  // 53
    GSGetShaderResources: procedure(Self: Pointer; StartSlot, NumViews: UINT; ppShaderResourceViews: Pointer); stdcall;  // 54
    GSGetSamplers: procedure(Self: Pointer; StartSlot, NumSamplers: UINT; ppSamplers: Pointer); stdcall;  // 55
    OMGetRenderTargets: procedure(Self: Pointer; NumViews: UINT; ppRenderTargetViews: Pointer; out ppDepthStencilView: Pointer); stdcall;  // 56
    OMGetBlendState: procedure(Self: Pointer; out ppBlendState: Pointer; BlendFactor: PSingle; out pSampleMask: UINT); stdcall;  // 57
    OMGetDepthStencilState: procedure(Self: Pointer; out ppDepthStencilState: Pointer; out pStencilRef: UINT); stdcall;  // 58
    SOGetTargets: procedure(Self: Pointer; NumBuffers: UINT; ppSOTargets: Pointer; pOffsets: PUINT); stdcall;  // 59
    RSGetState: procedure(Self: Pointer; out ppRasterizerState: Pointer); stdcall;  // 60
    RSGetViewports: procedure(Self: Pointer; var pNumViewports: UINT; pViewports: Pointer); stdcall;  // 61
    RSGetScissorRects: procedure(Self: Pointer; var pNumRects: UINT; pRects: Pointer); stdcall;  // 62
    GetDeviceRemovedReason: function(Self: Pointer): HRESULT; stdcall;  // 63
    SetExceptionMode: function(Self: Pointer; RaiseFlags: UINT): HRESULT; stdcall;  // 64
    GetExceptionMode: function(Self: Pointer): UINT; stdcall;  // 65
    GetPrivateData: function(Self: Pointer; const guid: TGUID; var pDataSize: UINT; pData: Pointer): HRESULT; stdcall;  // 66
    SetPrivateData: function(Self: Pointer; const guid: TGUID; DataSize: UINT; pData: Pointer): HRESULT; stdcall;  // 67
    SetPrivateDataInterface: function(Self: Pointer; const guid: TGUID; pData: Pointer): HRESULT; stdcall;  // 68
    ClearState: procedure(Self: Pointer); stdcall;  // 69
    Flush: procedure(Self: Pointer); stdcall;  // 70
    CreateBuffer: function(Self: Pointer; const pDesc: D3D10_BUFFER_DESC; pInitialData: Pointer; out ppBuffer: Pointer): HRESULT; stdcall;  // 71
    CreateTexture1D: function(Self: Pointer; pDesc, pInitialData: Pointer; out ppTexture1D: Pointer): HRESULT; stdcall;  // 72
    CreateTexture2D: function(Self: Pointer; pDesc, pInitialData: Pointer; out ppTexture2D: Pointer): HRESULT; stdcall;  // 73
    CreateTexture3D: function(Self: Pointer; pDesc, pInitialData: Pointer; out ppTexture3D: Pointer): HRESULT; stdcall;  // 74
    CreateShaderResourceView: function(Self: Pointer; pResource: Pointer; pDesc: Pointer; out ppSRView: Pointer): HRESULT; stdcall;  // 75
    CreateRenderTargetView: function(Self: Pointer; pResource: Pointer; pDesc: Pointer; out ppRTView: Pointer): HRESULT; stdcall;  // 76
    CreateDepthStencilView: function(Self: Pointer; pResource: Pointer; pDesc: Pointer; out ppDepthStencilView: Pointer): HRESULT; stdcall;  // 77
    CreateInputLayout: function(Self: Pointer; pInputElementDescs: PD3D10_INPUT_ELEMENT_DESC; NumElements: UINT; pShaderBytecodeWithInputSignature: Pointer; BytecodeLength: SIZE_T; out ppInputLayout: Pointer): HRESULT; stdcall;  // 78
    // D3D10 CreateVertexShader has no ClassLinkage parameter (only 3 params)
    CreateVertexShader: function(Self: Pointer; pShaderBytecode: Pointer; BytecodeLength: SIZE_T; out ppVertexShader: Pointer): HRESULT; stdcall;  // 79
    CreateGeometryShader: function(Self: Pointer; pShaderBytecode: Pointer; BytecodeLength: SIZE_T; out ppGeometryShader: Pointer): HRESULT; stdcall;  // 80
    CreateGeometryShaderWithStreamOutput: pointer;  // 81
    // D3D10 CreatePixelShader has no ClassLinkage parameter (only 3 params)
    CreatePixelShader: function(Self: Pointer; pShaderBytecode: Pointer; BytecodeLength: SIZE_T; out ppPixelShader: Pointer): HRESULT; stdcall;  // 82
  end;
  PID3D10DeviceVtbl = ^ID3D10DeviceVtbl;
  
  ID3D10Device = record
    lpVtbl: PID3D10DeviceVtbl;
  end;
  PID3D10Device = ^ID3D10Device;
  PPID3D10Device = ^PID3D10Device;

  // IDXGISwapChain VTable (same as D3D11)
  IDXGISwapChainVtbl = record
    // IUnknown
    QueryInterface: function(Self: Pointer; const riid: TGUID; out ppvObject): HRESULT; stdcall;
    AddRef: function(Self: Pointer): ULONG; stdcall;
    Release: function(Self: Pointer): ULONG; stdcall;
    // IDXGIObject
    SetPrivateData: function(Self: Pointer; const Name: TGUID; DataSize: UINT; pData: Pointer): HRESULT; stdcall;
    SetPrivateDataInterface: function(Self: Pointer; const Name: TGUID; pUnknown: Pointer): HRESULT; stdcall;
    GetPrivateData: function(Self: Pointer; const Name: TGUID; var pDataSize: UINT; pData: Pointer): HRESULT; stdcall;
    GetParent: function(Self: Pointer; const riid: TGUID; out ppParent): HRESULT; stdcall;
    // IDXGIDeviceSubObject
    GetDevice: function(Self: Pointer; const riid: TGUID; out ppDevice): HRESULT; stdcall;
    // IDXGISwapChain
    Present: function(Self: Pointer; SyncInterval: UINT; Flags: UINT): HRESULT; stdcall;
    GetBuffer: function(Self: Pointer; Buffer: UINT; const riid: TGUID; out ppSurface): HRESULT; stdcall;
    SetFullscreenState: function(Self: Pointer; Fullscreen: BOOL; pTarget: Pointer): HRESULT; stdcall;
    GetFullscreenState: function(Self: Pointer; out pFullscreen: BOOL; out ppTarget: Pointer): HRESULT; stdcall;
    GetDesc: function(Self: Pointer; out pDesc: DXGI_SWAP_CHAIN_DESC): HRESULT; stdcall;
    ResizeBuffers: function(Self: Pointer; BufferCount, Width, Height: UINT; NewFormat: DXGI_FORMAT; SwapChainFlags: UINT): HRESULT; stdcall;
    ResizeTarget: function(Self: Pointer; const pNewTargetParameters: DXGI_MODE_DESC): HRESULT; stdcall;
    GetContainingOutput: function(Self: Pointer; out ppOutput: Pointer): HRESULT; stdcall;
    GetFrameStatistics: function(Self: Pointer; out pStats: Pointer): HRESULT; stdcall;
    GetLastPresentCount: function(Self: Pointer; out pLastPresentCount: UINT): HRESULT; stdcall;
  end;
  PIDXGISwapChainVtbl = ^IDXGISwapChainVtbl;
  
  IDXGISwapChain = record
    lpVtbl: PIDXGISwapChainVtbl;
  end;
  PIDXGISwapChain = ^IDXGISwapChain;
  PPIDXGISwapChain = ^PIDXGISwapChain;

  // ID3D10RenderTargetView VTable
  ID3D10RenderTargetViewVtbl = record
    // IUnknown
    QueryInterface: function(Self: Pointer; const riid: TGUID; out ppvObject): HRESULT; stdcall;
    AddRef: function(Self: Pointer): ULONG; stdcall;
    Release: function(Self: Pointer): ULONG; stdcall;
    // ID3D10DeviceChild
    GetDevice: procedure(Self: Pointer; out ppDevice: Pointer); stdcall;
    GetPrivateData: function(Self: Pointer; const guid: TGUID; var pDataSize: UINT; pData: Pointer): HRESULT; stdcall;
    SetPrivateData: function(Self: Pointer; const guid: TGUID; DataSize: UINT; pData: Pointer): HRESULT; stdcall;
    SetPrivateDataInterface: function(Self: Pointer; const guid: TGUID; pData: Pointer): HRESULT; stdcall;
    // ID3D10View
    GetResource: procedure(Self: Pointer; out ppResource: Pointer); stdcall;
    // ID3D10RenderTargetView
    GetDesc: procedure(Self: Pointer; out pDesc: Pointer); stdcall;
  end;
  PID3D10RenderTargetViewVtbl = ^ID3D10RenderTargetViewVtbl;
  
  ID3D10RenderTargetView = record
    lpVtbl: PID3D10RenderTargetViewVtbl;
  end;
  PID3D10RenderTargetView = ^ID3D10RenderTargetView;

  // ID3D10Texture2D VTable
  ID3D10Texture2DVtbl = record
    // IUnknown
    QueryInterface: function(Self: Pointer; const riid: TGUID; out ppvObject): HRESULT; stdcall;
    AddRef: function(Self: Pointer): ULONG; stdcall;
    Release: function(Self: Pointer): ULONG; stdcall;
    // ID3D10DeviceChild
    GetDevice: procedure(Self: Pointer; out ppDevice: Pointer); stdcall;
    GetPrivateData: function(Self: Pointer; const guid: TGUID; var pDataSize: UINT; pData: Pointer): HRESULT; stdcall;
    SetPrivateData: function(Self: Pointer; const guid: TGUID; DataSize: UINT; pData: Pointer): HRESULT; stdcall;
    SetPrivateDataInterface: function(Self: Pointer; const guid: TGUID; pData: Pointer): HRESULT; stdcall;
    // ID3D10Resource
    GetType: procedure(Self: Pointer; out rType: UINT); stdcall;
    SetEvictionPriority: procedure(Self: Pointer; EvictionPriority: UINT); stdcall;
    GetEvictionPriority: function(Self: Pointer): UINT; stdcall;
    // ID3D10Texture2D
    Map: function(Self: Pointer; Subresource: UINT; MapType: UINT; MapFlags: UINT; out pMappedTex2D: Pointer): HRESULT; stdcall;
    Unmap: procedure(Self: Pointer; Subresource: UINT); stdcall;
    GetDesc: procedure(Self: Pointer; out pDesc: Pointer); stdcall;
  end;
  PID3D10Texture2DVtbl = ^ID3D10Texture2DVtbl;
  
  ID3D10Texture2D = record
    lpVtbl: PID3D10Texture2DVtbl;
  end;
  PID3D10Texture2D = ^ID3D10Texture2D;

// ===========================================
// External function declarations
// ===========================================
// D3D10 uses D3D10CreateDeviceAndSwapChain - no separate DeviceContext output
function D3D10CreateDeviceAndSwapChain(
  pAdapter: Pointer;
  DriverType: D3D10_DRIVER_TYPE;
  Software: HMODULE;
  Flags: UINT;
  SDKVersion: UINT;
  pSwapChainDesc: Pointer;
  out ppSwapChain: PIDXGISwapChain;
  out ppDevice: PID3D10Device
): HRESULT; stdcall; external 'd3d10.dll';

function D3DCompileFromFile(
  pFileName: PWideChar;
  pDefines: Pointer;
  pInclude: Pointer;
  pEntrypoint: PAnsiChar;
  pTarget: PAnsiChar;
  Flags1: UINT;
  Flags2: UINT;
  out ppCode: PID3DBlob;
  ppErrorMsgs: Pointer
): HRESULT; stdcall; external 'd3dcompiler_47.dll';

// ===========================================
// Global variables
// ===========================================
var
  g_hWnd: HWND = 0;
  g_pd3dDevice: PID3D10Device = nil;        // No DeviceContext in D3D10
  g_pSwapChain: PIDXGISwapChain = nil;
  g_pRenderTargetView: PID3D10RenderTargetView = nil;
  g_pVertexShader: Pointer = nil;
  g_pPixelShader: Pointer = nil;
  g_pVertexLayout: Pointer = nil;
  g_pVertexBuffer: Pointer = nil;

// ===========================================
// Debug helper
// ===========================================
procedure DebugMsg(const Msg: string);
begin
  MessageBoxA(0, PAnsiChar(AnsiString(Msg)), 'Debug', MB_OK);
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
  rc: TRect;
begin
  ZeroMemory(@wcex, SizeOf(wcex));
  wcex.cbSize := SizeOf(WNDCLASSEX);
  wcex.style := CS_HREDRAW or CS_VREDRAW;
  wcex.lpfnWndProc := @WndProc;
  wcex.hInstance := hInstance;
  wcex.hCursor := LoadCursor(0, IDC_ARROW);
  wcex.hbrBackground := COLOR_WINDOW + 1;
  wcex.lpszClassName := 'WindowClass';

  if RegisterClassEx(wcex) = 0 then
  begin
    Result := E_FAIL;
    Exit;
  end;

  rc.Left := 0;
  rc.Top := 0;
  rc.Right := 640;
  rc.Bottom := 480;
  AdjustWindowRect(@rc, WS_OVERLAPPEDWINDOW, False);

  g_hWnd := CreateWindow('WindowClass', 'Hello, World!',
    WS_OVERLAPPEDWINDOW,
    CW_USEDEFAULT, CW_USEDEFAULT,
    rc.Right - rc.Left, rc.Bottom - rc.Top,
    0, 0, hInstance, nil);

  if g_hWnd = 0 then
  begin
    Result := E_FAIL;
    Exit;
  end;

  ShowWindow(g_hWnd, nCmdShow);
  Result := S_OK;
end;

// ===========================================
// Initialize Device
// ===========================================
function InitDevice: HRESULT;
var
  rc: TRect;
  width, height: UINT;
  sd: DXGI_SWAP_CHAIN_DESC;
  pBackBuffer: PID3D10Texture2D;
  vp: D3D10_VIEWPORT;
  pVSBlob, pPSBlob: PID3DBlob;
  layout: array[0..1] of D3D10_INPUT_ELEMENT_DESC;
  vertices: array[0..2] of VERTEX;
  bd: D3D10_BUFFER_DESC;
  InitData: D3D10_SUBRESOURCE_DATA;
  stride, offset: UINT;
begin
  GetClientRect(g_hWnd, rc);
  width := rc.Right - rc.Left;
  height := rc.Bottom - rc.Top;

  ZeroMemory(@sd, SizeOf(sd));
  sd.BufferCount := 1;
  sd.BufferDesc.Width := width;
  sd.BufferDesc.Height := height;
  sd.BufferDesc.Format := DXGI_FORMAT_R8G8B8A8_UNORM;
  sd.BufferDesc.RefreshRate.Numerator := 60;
  sd.BufferDesc.RefreshRate.Denominator := 1;
  sd.BufferUsage := DXGI_USAGE_RENDER_TARGET_OUTPUT;
  sd.OutputWindow := g_hWnd;
  sd.SampleDesc.Count := 1;
  sd.SampleDesc.Quality := 0;
  sd.Windowed := True;

  // D3D10CreateDeviceAndSwapChain - no DeviceContext output
  Result := D3D10CreateDeviceAndSwapChain(
    nil, D3D10_DRIVER_TYPE_HARDWARE, 0, 0,
    D3D10_SDK_VERSION,
    @sd, g_pSwapChain, g_pd3dDevice);

  if Failed(Result) then
  begin
    DebugMsg('D3D10CreateDeviceAndSwapChain failed: ' + IntToHex(Result, 8));
    Exit;
  end;

  // Get back buffer
  pBackBuffer := nil;
  Result := g_pSwapChain^.lpVtbl^.GetBuffer(g_pSwapChain, 0, IID_ID3D10Texture2D, pBackBuffer);
  if Failed(Result) then
  begin
    DebugMsg('GetBuffer failed: ' + IntToHex(Result, 8));
    Exit;
  end;

  // Create render target view
  Result := g_pd3dDevice^.lpVtbl^.CreateRenderTargetView(g_pd3dDevice, pBackBuffer, nil, g_pRenderTargetView);
  pBackBuffer^.lpVtbl^.Release(pBackBuffer);
  if Failed(Result) then
  begin
    DebugMsg('CreateRenderTargetView failed: ' + IntToHex(Result, 8));
    Exit;
  end;

  // Set render target - in D3D10, device handles this directly
  g_pd3dDevice^.lpVtbl^.OMSetRenderTargets(g_pd3dDevice, 1, @g_pRenderTargetView, nil);

  // Setup viewport - D3D10 uses UINT for Width/Height
  vp.TopLeftX := 0;
  vp.TopLeftY := 0;
  vp.Width := width;
  vp.Height := height;
  vp.MinDepth := 0.0;
  vp.MaxDepth := 1.0;
  g_pd3dDevice^.lpVtbl^.RSSetViewports(g_pd3dDevice, 1, @vp);

  // Compile vertex shader
  pVSBlob := nil;
  Result := D3DCompileFromFile('hello.fx', nil, nil, 'VS', 'vs_4_0',
    D3DCOMPILE_ENABLE_STRICTNESS, 0, pVSBlob, nil);
  if Failed(Result) then
  begin
    DebugMsg('D3DCompileFromFile (VS) failed: ' + IntToHex(Result, 8));
    Exit;
  end;

  // Create vertex shader - D3D10 has no ClassLinkage parameter
  Result := g_pd3dDevice^.lpVtbl^.CreateVertexShader(g_pd3dDevice,
    pVSBlob^.lpVtbl^.GetBufferPointer(pVSBlob),
    pVSBlob^.lpVtbl^.GetBufferSize(pVSBlob),
    g_pVertexShader);
  if Failed(Result) then
  begin
    pVSBlob^.lpVtbl^.Release(pVSBlob);
    DebugMsg('CreateVertexShader failed: ' + IntToHex(Result, 8));
    Exit;
  end;

  // Define input layout
  layout[0].SemanticName := 'POSITION';
  layout[0].SemanticIndex := 0;
  layout[0].Format := DXGI_FORMAT_R32G32B32_FLOAT;
  layout[0].InputSlot := 0;
  layout[0].AlignedByteOffset := 0;
  layout[0].InputSlotClass := D3D10_INPUT_PER_VERTEX_DATA;
  layout[0].InstanceDataStepRate := 0;

  layout[1].SemanticName := 'COLOR';
  layout[1].SemanticIndex := 0;
  layout[1].Format := DXGI_FORMAT_R32G32B32A32_FLOAT;
  layout[1].InputSlot := 0;
  layout[1].AlignedByteOffset := 12;
  layout[1].InputSlotClass := D3D10_INPUT_PER_VERTEX_DATA;
  layout[1].InstanceDataStepRate := 0;

  // Create input layout
  Result := g_pd3dDevice^.lpVtbl^.CreateInputLayout(g_pd3dDevice, @layout[0], 2,
    pVSBlob^.lpVtbl^.GetBufferPointer(pVSBlob),
    pVSBlob^.lpVtbl^.GetBufferSize(pVSBlob),
    g_pVertexLayout);
  pVSBlob^.lpVtbl^.Release(pVSBlob);
  if Failed(Result) then
  begin
    DebugMsg('CreateInputLayout failed: ' + IntToHex(Result, 8));
    Exit;
  end;

  // Set input layout - in D3D10, device handles this directly
  g_pd3dDevice^.lpVtbl^.IASetInputLayout(g_pd3dDevice, g_pVertexLayout);

  // Compile pixel shader
  pPSBlob := nil;
  Result := D3DCompileFromFile('hello.fx', nil, nil, 'PS', 'ps_4_0',
    D3DCOMPILE_ENABLE_STRICTNESS, 0, pPSBlob, nil);
  if Failed(Result) then
  begin
    DebugMsg('D3DCompileFromFile (PS) failed: ' + IntToHex(Result, 8));
    Exit;
  end;

  // Create pixel shader - D3D10 has no ClassLinkage parameter
  Result := g_pd3dDevice^.lpVtbl^.CreatePixelShader(g_pd3dDevice,
    pPSBlob^.lpVtbl^.GetBufferPointer(pPSBlob),
    pPSBlob^.lpVtbl^.GetBufferSize(pPSBlob),
    g_pPixelShader);
  pPSBlob^.lpVtbl^.Release(pPSBlob);
  if Failed(Result) then
  begin
    DebugMsg('CreatePixelShader failed: ' + IntToHex(Result, 8));
    Exit;
  end;

  // Create vertex buffer
  vertices[0].x :=  0.0; vertices[0].y :=  0.5; vertices[0].z := 0.5;
  vertices[0].r :=  1.0; vertices[0].g :=  0.0; vertices[0].b := 0.0; vertices[0].a := 1.0;
  vertices[1].x :=  0.5; vertices[1].y := -0.5; vertices[1].z := 0.5;
  vertices[1].r :=  0.0; vertices[1].g :=  1.0; vertices[1].b := 0.0; vertices[1].a := 1.0;
  vertices[2].x := -0.5; vertices[2].y := -0.5; vertices[2].z := 0.5;
  vertices[2].r :=  0.0; vertices[2].g :=  0.0; vertices[2].b := 1.0; vertices[2].a := 1.0;

  // D3D10_BUFFER_DESC has no StructureByteStride
  ZeroMemory(@bd, SizeOf(bd));
  bd.Usage := D3D10_USAGE_DEFAULT;
  bd.ByteWidth := SizeOf(VERTEX) * 3;
  bd.BindFlags := D3D10_BIND_VERTEX_BUFFER;
  bd.CPUAccessFlags := 0;

  ZeroMemory(@InitData, SizeOf(InitData));
  InitData.pSysMem := @vertices[0];

  Result := g_pd3dDevice^.lpVtbl^.CreateBuffer(g_pd3dDevice, bd, @InitData, g_pVertexBuffer);
  if Failed(Result) then
  begin
    DebugMsg('CreateBuffer failed: ' + IntToHex(Result, 8));
    Exit;
  end;

  // Set vertex buffer - in D3D10, device handles this directly
  stride := SizeOf(VERTEX);
  offset := 0;
  g_pd3dDevice^.lpVtbl^.IASetVertexBuffers(g_pd3dDevice, 0, 1, @g_pVertexBuffer, @stride, @offset);

  // Set primitive topology - in D3D10, device handles this directly
  g_pd3dDevice^.lpVtbl^.IASetPrimitiveTopology(g_pd3dDevice, D3D10_PRIMITIVE_TOPOLOGY_TRIANGLELIST);

  Result := S_OK;
end;

// ===========================================
// Cleanup Device
// ===========================================
procedure CleanupDevice;
begin
  // In D3D10, ClearState is on the device directly
  if g_pd3dDevice <> nil then
    g_pd3dDevice^.lpVtbl^.ClearState(g_pd3dDevice);

  if g_pVertexBuffer <> nil then
    PID3D10RenderTargetView(g_pVertexBuffer)^.lpVtbl^.Release(g_pVertexBuffer);
  if g_pVertexLayout <> nil then
    PID3D10RenderTargetView(g_pVertexLayout)^.lpVtbl^.Release(g_pVertexLayout);
  if g_pVertexShader <> nil then
    PID3D10RenderTargetView(g_pVertexShader)^.lpVtbl^.Release(g_pVertexShader);
  if g_pPixelShader <> nil then
    PID3D10RenderTargetView(g_pPixelShader)^.lpVtbl^.Release(g_pPixelShader);
  if g_pRenderTargetView <> nil then
    g_pRenderTargetView^.lpVtbl^.Release(g_pRenderTargetView);
  if g_pSwapChain <> nil then
    g_pSwapChain^.lpVtbl^.Release(g_pSwapChain);
  if g_pd3dDevice <> nil then
    g_pd3dDevice^.lpVtbl^.Release(g_pd3dDevice);
end;

// ===========================================
// Render
// ===========================================
procedure Render;
var
  ClearColor: array[0..3] of Single;
begin
  ClearColor[0] := 1.0;
  ClearColor[1] := 1.0;
  ClearColor[2] := 1.0;
  ClearColor[3] := 1.0;

  // In D3D10, all rendering commands go through the device directly
  g_pd3dDevice^.lpVtbl^.ClearRenderTargetView(g_pd3dDevice, g_pRenderTargetView, @ClearColor[0]);
  g_pd3dDevice^.lpVtbl^.OMSetRenderTargets(g_pd3dDevice, 1, @g_pRenderTargetView, nil);
  
  // D3D10 shader set functions have no ClassInstances parameter
  g_pd3dDevice^.lpVtbl^.VSSetShader(g_pd3dDevice, g_pVertexShader);
  g_pd3dDevice^.lpVtbl^.PSSetShader(g_pd3dDevice, g_pPixelShader);
  
  g_pd3dDevice^.lpVtbl^.Draw(g_pd3dDevice, 3, 0);

  g_pSwapChain^.lpVtbl^.Present(g_pSwapChain, 0, 0);
end;

// ===========================================
// Main
// ===========================================
var
  msg: TMsg;
begin
  if Failed(InitWindow(hInstance, CmdShow)) then
  begin
    DebugMsg('InitWindow failed');
    Halt(0);
  end;

  if Failed(InitDevice) then
  begin
    CleanupDevice;
    Halt(0);
  end;

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

  CleanupDevice;
end.
