program hello;

{$mode delphi}

uses
  Windows, ActiveX, SysUtils;

// ===========================================
// DirectX 11 Types and Constants
// ===========================================
type
  DXGI_FORMAT = Cardinal;
  D3D_DRIVER_TYPE = Cardinal;
  D3D_FEATURE_LEVEL = Cardinal;
  D3D11_USAGE = Cardinal;
  D3D11_BIND_FLAG = Cardinal;
  D3D11_CPU_ACCESS_FLAG = Cardinal;
  D3D11_PRIMITIVE_TOPOLOGY = Cardinal;

const
  // DXGI_FORMAT
  DXGI_FORMAT_R32G32B32_FLOAT    = 6;
  DXGI_FORMAT_R32G32B32A32_FLOAT = 2;
  DXGI_FORMAT_R8G8B8A8_UNORM     = 28;

  // D3D_DRIVER_TYPE
  D3D_DRIVER_TYPE_HARDWARE  = 1;

  // D3D_FEATURE_LEVEL
  D3D_FEATURE_LEVEL_11_0 = $b000;

  // D3D11_USAGE
  D3D11_USAGE_DEFAULT = 0;

  // D3D11_BIND_FLAG
  D3D11_BIND_VERTEX_BUFFER = $1;

  // D3D11_PRIMITIVE_TOPOLOGY
  D3D11_PRIMITIVE_TOPOLOGY_TRIANGLELIST = 4;

  // DXGI_USAGE
  DXGI_USAGE_RENDER_TARGET_OUTPUT = $20;

  // D3D11_INPUT_PER_VERTEX_DATA
  D3D11_INPUT_PER_VERTEX_DATA = 0;

  // D3D11_SDK_VERSION
  D3D11_SDK_VERSION = 7;

  // D3DCOMPILE flags
  D3DCOMPILE_ENABLE_STRICTNESS = $800;

  // GUIDs
  IID_ID3D11Texture2D: TGUID = '{6f15aaf2-d208-4e89-9ab4-489535d34f9c}';

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

  D3D11_VIEWPORT = record
    TopLeftX: Single;
    TopLeftY: Single;
    Width: Single;
    Height: Single;
    MinDepth: Single;
    MaxDepth: Single;
  end;

  D3D11_INPUT_ELEMENT_DESC = record
    SemanticName: PAnsiChar;
    SemanticIndex: UINT;
    Format: DXGI_FORMAT;
    InputSlot: UINT;
    AlignedByteOffset: UINT;
    InputSlotClass: UINT;
    InstanceDataStepRate: UINT;
  end;
  PD3D11_INPUT_ELEMENT_DESC = ^D3D11_INPUT_ELEMENT_DESC;

  D3D11_BUFFER_DESC = record
    ByteWidth: UINT;
    Usage: D3D11_USAGE;
    BindFlags: UINT;
    CPUAccessFlags: UINT;
    MiscFlags: UINT;
    StructureByteStride: UINT;
  end;

  D3D11_SUBRESOURCE_DATA = record
    pSysMem: Pointer;
    SysMemPitch: UINT;
    SysMemSlicePitch: UINT;
  end;

  VERTEX = record
    x, y, z: Single;
    r, g, b, a: Single;
  end;

  // ===========================================
  // COM Interfaces using VTable approach (like C)
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

  // ID3D11Device VTable (partial - only methods we need)
  ID3D11DeviceVtbl = record
    // IUnknown
    QueryInterface: function(Self: Pointer; const riid: TGUID; out ppvObject): HRESULT; stdcall;
    AddRef: function(Self: Pointer): ULONG; stdcall;
    Release: function(Self: Pointer): ULONG; stdcall;
    // ID3D11Device
    CreateBuffer: function(Self: Pointer; const pDesc: D3D11_BUFFER_DESC; pInitialData: Pointer; out ppBuffer: Pointer): HRESULT; stdcall;
    CreateTexture1D: function(Self: Pointer; pDesc, pInitialData: Pointer; out ppTexture1D: Pointer): HRESULT; stdcall;
    CreateTexture2D: function(Self: Pointer; pDesc, pInitialData: Pointer; out ppTexture2D: Pointer): HRESULT; stdcall;
    CreateTexture3D: function(Self: Pointer; pDesc, pInitialData: Pointer; out ppTexture3D: Pointer): HRESULT; stdcall;
    CreateShaderResourceView: function(Self: Pointer; pResource: Pointer; pDesc: Pointer; out ppSRView: Pointer): HRESULT; stdcall;
    CreateUnorderedAccessView: function(Self: Pointer; pResource: Pointer; pDesc: Pointer; out ppUAView: Pointer): HRESULT; stdcall;
    CreateRenderTargetView: function(Self: Pointer; pResource: Pointer; pDesc: Pointer; out ppRTView: Pointer): HRESULT; stdcall;
    CreateDepthStencilView: function(Self: Pointer; pResource: Pointer; pDesc: Pointer; out ppDepthStencilView: Pointer): HRESULT; stdcall;
    CreateInputLayout: function(Self: Pointer; pInputElementDescs: PD3D11_INPUT_ELEMENT_DESC; NumElements: UINT; pShaderBytecodeWithInputSignature: Pointer; BytecodeLength: SIZE_T; out ppInputLayout: Pointer): HRESULT; stdcall;
    CreateVertexShader: function(Self: Pointer; pShaderBytecode: Pointer; BytecodeLength: SIZE_T; pClassLinkage: Pointer; out ppVertexShader: Pointer): HRESULT; stdcall;
    CreateGeometryShader: function(Self: Pointer; pShaderBytecode: Pointer; BytecodeLength: SIZE_T; pClassLinkage: Pointer; out ppGeometryShader: Pointer): HRESULT; stdcall;
    CreateGeometryShaderWithStreamOutput: pointer;
    CreatePixelShader: function(Self: Pointer; pShaderBytecode: Pointer; BytecodeLength: SIZE_T; pClassLinkage: Pointer; out ppPixelShader: Pointer): HRESULT; stdcall;
  end;
  PID3D11DeviceVtbl = ^ID3D11DeviceVtbl;
  
  ID3D11Device = record
    lpVtbl: PID3D11DeviceVtbl;
  end;
  PID3D11Device = ^ID3D11Device;
  PPID3D11Device = ^PID3D11Device;

  // ID3D11DeviceContext VTable
  ID3D11DeviceContextVtbl = record
    // IUnknown
    QueryInterface: function(Self: Pointer; const riid: TGUID; out ppvObject): HRESULT; stdcall;
    AddRef: function(Self: Pointer): ULONG; stdcall;
    Release: function(Self: Pointer): ULONG; stdcall;
    // ID3D11DeviceChild
    GetDevice: procedure(Self: Pointer; out ppDevice: Pointer); stdcall;
    GetPrivateData: function(Self: Pointer; const guid: TGUID; var pDataSize: UINT; pData: Pointer): HRESULT; stdcall;
    SetPrivateData: function(Self: Pointer; const guid: TGUID; DataSize: UINT; pData: Pointer): HRESULT; stdcall;
    SetPrivateDataInterface: function(Self: Pointer; const guid: TGUID; pData: Pointer): HRESULT; stdcall;
    // ID3D11DeviceContext
    VSSetConstantBuffers: procedure(Self: Pointer; StartSlot, NumBuffers: UINT; ppConstantBuffers: Pointer); stdcall;
    PSSetShaderResources: procedure(Self: Pointer; StartSlot, NumViews: UINT; ppShaderResourceViews: Pointer); stdcall;
    PSSetShader: procedure(Self: Pointer; pPixelShader: Pointer; ppClassInstances: Pointer; NumClassInstances: UINT); stdcall;
    PSSetSamplers: procedure(Self: Pointer; StartSlot, NumSamplers: UINT; ppSamplers: Pointer); stdcall;
    VSSetShader: procedure(Self: Pointer; pVertexShader: Pointer; ppClassInstances: Pointer; NumClassInstances: UINT); stdcall;
    DrawIndexed: procedure(Self: Pointer; IndexCount, StartIndexLocation: UINT; BaseVertexLocation: Integer); stdcall;
    Draw: procedure(Self: Pointer; VertexCount, StartVertexLocation: UINT); stdcall;
    Map: function(Self: Pointer; pResource: Pointer; Subresource, MapType, MapFlags: UINT; out pMappedResource: Pointer): HRESULT; stdcall;
    Unmap: procedure(Self: Pointer; pResource: Pointer; Subresource: UINT); stdcall;
    PSSetConstantBuffers: procedure(Self: Pointer; StartSlot, NumBuffers: UINT; ppConstantBuffers: Pointer); stdcall;
    IASetInputLayout: procedure(Self: Pointer; pInputLayout: Pointer); stdcall;
    IASetVertexBuffers: procedure(Self: Pointer; StartSlot, NumBuffers: UINT; ppVertexBuffers: Pointer; pStrides, pOffsets: PUINT); stdcall;
    IASetIndexBuffer: procedure(Self: Pointer; pIndexBuffer: Pointer; Format: DXGI_FORMAT; Offset: UINT); stdcall;
    DrawIndexedInstanced: procedure(Self: Pointer; IndexCountPerInstance, InstanceCount, StartIndexLocation: UINT; BaseVertexLocation: Integer; StartInstanceLocation: UINT); stdcall;
    DrawInstanced: procedure(Self: Pointer; VertexCountPerInstance, InstanceCount, StartVertexLocation, StartInstanceLocation: UINT); stdcall;
    GSSetConstantBuffers: procedure(Self: Pointer; StartSlot, NumBuffers: UINT; ppConstantBuffers: Pointer); stdcall;
    GSSetShader: procedure(Self: Pointer; pShader: Pointer; ppClassInstances: Pointer; NumClassInstances: UINT); stdcall;
    IASetPrimitiveTopology: procedure(Self: Pointer; Topology: D3D11_PRIMITIVE_TOPOLOGY); stdcall;
    VSSetShaderResources: procedure(Self: Pointer; StartSlot, NumViews: UINT; ppShaderResourceViews: Pointer); stdcall;
    VSSetSamplers: procedure(Self: Pointer; StartSlot, NumSamplers: UINT; ppSamplers: Pointer); stdcall;
    Begin_: procedure(Self: Pointer; pAsync: Pointer); stdcall;
    End_: procedure(Self: Pointer; pAsync: Pointer); stdcall;
    GetData: function(Self: Pointer; pAsync: Pointer; pData: Pointer; DataSize, GetDataFlags: UINT): HRESULT; stdcall;
    SetPredication: procedure(Self: Pointer; pPredicate: Pointer; PredicateValue: BOOL); stdcall;
    GSSetShaderResources: procedure(Self: Pointer; StartSlot, NumViews: UINT; ppShaderResourceViews: Pointer); stdcall;
    GSSetSamplers: procedure(Self: Pointer; StartSlot, NumSamplers: UINT; ppSamplers: Pointer); stdcall;
    OMSetRenderTargets: procedure(Self: Pointer; NumViews: UINT; ppRenderTargetViews: Pointer; pDepthStencilView: Pointer); stdcall;
    OMSetRenderTargetsAndUnorderedAccessViews: procedure(Self: Pointer; NumRTVs: UINT; ppRenderTargetViews: Pointer; pDepthStencilView: Pointer; UAVStartSlot, NumUAVs: UINT; ppUnorderedAccessViews: Pointer; pUAVInitialCounts: PUINT); stdcall;
    OMSetBlendState: procedure(Self: Pointer; pBlendState: Pointer; BlendFactor: PSingle; SampleMask: UINT); stdcall;
    OMSetDepthStencilState: procedure(Self: Pointer; pDepthStencilState: Pointer; StencilRef: UINT); stdcall;
    SOSetTargets: procedure(Self: Pointer; NumBuffers: UINT; ppSOTargets: Pointer; pOffsets: PUINT); stdcall;
    DrawAuto: procedure(Self: Pointer); stdcall;
    DrawIndexedInstancedIndirect: procedure(Self: Pointer; pBufferForArgs: Pointer; AlignedByteOffsetForArgs: UINT); stdcall;
    DrawInstancedIndirect: procedure(Self: Pointer; pBufferForArgs: Pointer; AlignedByteOffsetForArgs: UINT); stdcall;
    Dispatch: procedure(Self: Pointer; ThreadGroupCountX, ThreadGroupCountY, ThreadGroupCountZ: UINT); stdcall;
    DispatchIndirect: procedure(Self: Pointer; pBufferForArgs: Pointer; AlignedByteOffsetForArgs: UINT); stdcall;
    RSSetState: procedure(Self: Pointer; pRasterizerState: Pointer); stdcall;
    RSSetViewports: procedure(Self: Pointer; NumViewports: UINT; pViewports: Pointer); stdcall;
    RSSetScissorRects: procedure(Self: Pointer; NumRects: UINT; pRects: Pointer); stdcall;
    CopySubresourceRegion: procedure(Self: Pointer; pDstResource: Pointer; DstSubresource, DstX, DstY, DstZ: UINT; pSrcResource: Pointer; SrcSubresource: UINT; pSrcBox: Pointer); stdcall;
    CopyResource: procedure(Self: Pointer; pDstResource, pSrcResource: Pointer); stdcall;
    UpdateSubresource: procedure(Self: Pointer; pDstResource: Pointer; DstSubresource: UINT; pDstBox: Pointer; pSrcData: Pointer; SrcRowPitch, SrcDepthPitch: UINT); stdcall;
    CopyStructureCount: procedure(Self: Pointer; pDstBuffer: Pointer; DstAlignedByteOffset: UINT; pSrcView: Pointer); stdcall;
    ClearRenderTargetView: procedure(Self: Pointer; pRenderTargetView: Pointer; ColorRGBA: PSingle); stdcall;
    ClearUnorderedAccessViewUint: procedure(Self: Pointer; pUnorderedAccessView: Pointer; Values: PUINT); stdcall;
    ClearUnorderedAccessViewFloat: procedure(Self: Pointer; pUnorderedAccessView: Pointer; Values: PSingle); stdcall;
    ClearDepthStencilView: procedure(Self: Pointer; pDepthStencilView: Pointer; ClearFlags: UINT; Depth: Single; Stencil: Byte); stdcall;
    GenerateMips: procedure(Self: Pointer; pShaderResourceView: Pointer); stdcall;
    SetResourceMinLOD: procedure(Self: Pointer; pResource: Pointer; MinLOD: Single); stdcall;
    GetResourceMinLOD: function(Self: Pointer; pResource: Pointer): Single; stdcall;
    ResolveSubresource: procedure(Self: Pointer; pDstResource: Pointer; DstSubresource: UINT; pSrcResource: Pointer; SrcSubresource: UINT; Format: DXGI_FORMAT); stdcall;
    ExecuteCommandList: procedure(Self: Pointer; pCommandList: Pointer; RestoreContextState: BOOL); stdcall;
    HSSetShaderResources: procedure(Self: Pointer; StartSlot, NumViews: UINT; ppShaderResourceViews: Pointer); stdcall;
    HSSetShader: procedure(Self: Pointer; pHullShader: Pointer; ppClassInstances: Pointer; NumClassInstances: UINT); stdcall;
    HSSetSamplers: procedure(Self: Pointer; StartSlot, NumSamplers: UINT; ppSamplers: Pointer); stdcall;
    HSSetConstantBuffers: procedure(Self: Pointer; StartSlot, NumBuffers: UINT; ppConstantBuffers: Pointer); stdcall;
    DSSetShaderResources: procedure(Self: Pointer; StartSlot, NumViews: UINT; ppShaderResourceViews: Pointer); stdcall;
    DSSetShader: procedure(Self: Pointer; pDomainShader: Pointer; ppClassInstances: Pointer; NumClassInstances: UINT); stdcall;
    DSSetSamplers: procedure(Self: Pointer; StartSlot, NumSamplers: UINT; ppSamplers: Pointer); stdcall;
    DSSetConstantBuffers: procedure(Self: Pointer; StartSlot, NumBuffers: UINT; ppConstantBuffers: Pointer); stdcall;
    CSSetShaderResources: procedure(Self: Pointer; StartSlot, NumViews: UINT; ppShaderResourceViews: Pointer); stdcall;
    CSSetUnorderedAccessViews: procedure(Self: Pointer; StartSlot, NumUAVs: UINT; ppUnorderedAccessViews: Pointer; pUAVInitialCounts: PUINT); stdcall;
    CSSetShader: procedure(Self: Pointer; pComputeShader: Pointer; ppClassInstances: Pointer; NumClassInstances: UINT); stdcall;
    CSSetSamplers: procedure(Self: Pointer; StartSlot, NumSamplers: UINT; ppSamplers: Pointer); stdcall;
    CSSetConstantBuffers: procedure(Self: Pointer; StartSlot, NumBuffers: UINT; ppConstantBuffers: Pointer); stdcall;
    VSGetConstantBuffers: procedure(Self: Pointer; StartSlot, NumBuffers: UINT; ppConstantBuffers: Pointer); stdcall;
    PSGetShaderResources: procedure(Self: Pointer; StartSlot, NumViews: UINT; ppShaderResourceViews: Pointer); stdcall;
    PSGetShader: procedure(Self: Pointer; out ppPixelShader: Pointer; ppClassInstances: Pointer; var pNumClassInstances: UINT); stdcall;
    PSGetSamplers: procedure(Self: Pointer; StartSlot, NumSamplers: UINT; ppSamplers: Pointer); stdcall;
    VSGetShader: procedure(Self: Pointer; out ppVertexShader: Pointer; ppClassInstances: Pointer; var pNumClassInstances: UINT); stdcall;
    PSGetConstantBuffers: procedure(Self: Pointer; StartSlot, NumBuffers: UINT; ppConstantBuffers: Pointer); stdcall;
    IAGetInputLayout: procedure(Self: Pointer; out ppInputLayout: Pointer); stdcall;
    IAGetVertexBuffers: procedure(Self: Pointer; StartSlot, NumBuffers: UINT; ppVertexBuffers: Pointer; pStrides, pOffsets: PUINT); stdcall;
    IAGetIndexBuffer: procedure(Self: Pointer; out pIndexBuffer: Pointer; out Format: DXGI_FORMAT; out Offset: UINT); stdcall;
    GSGetConstantBuffers: procedure(Self: Pointer; StartSlot, NumBuffers: UINT; ppConstantBuffers: Pointer); stdcall;
    GSGetShader: procedure(Self: Pointer; out ppGeometryShader: Pointer; ppClassInstances: Pointer; var pNumClassInstances: UINT); stdcall;
    IAGetPrimitiveTopology: procedure(Self: Pointer; out pTopology: D3D11_PRIMITIVE_TOPOLOGY); stdcall;
    VSGetShaderResources: procedure(Self: Pointer; StartSlot, NumViews: UINT; ppShaderResourceViews: Pointer); stdcall;
    VSGetSamplers: procedure(Self: Pointer; StartSlot, NumSamplers: UINT; ppSamplers: Pointer); stdcall;
    GetPredication: procedure(Self: Pointer; out ppPredicate: Pointer; out pPredicateValue: BOOL); stdcall;
    GSGetShaderResources: procedure(Self: Pointer; StartSlot, NumViews: UINT; ppShaderResourceViews: Pointer); stdcall;
    GSGetSamplers: procedure(Self: Pointer; StartSlot, NumSamplers: UINT; ppSamplers: Pointer); stdcall;
    OMGetRenderTargets: procedure(Self: Pointer; NumViews: UINT; ppRenderTargetViews: Pointer; out ppDepthStencilView: Pointer); stdcall;
    OMGetRenderTargetsAndUnorderedAccessViews: procedure(Self: Pointer; NumRTVs: UINT; ppRenderTargetViews: Pointer; out ppDepthStencilView: Pointer; UAVStartSlot, NumUAVs: UINT; ppUnorderedAccessViews: Pointer); stdcall;
    OMGetBlendState: procedure(Self: Pointer; out ppBlendState: Pointer; BlendFactor: PSingle; out pSampleMask: UINT); stdcall;
    OMGetDepthStencilState: procedure(Self: Pointer; out ppDepthStencilState: Pointer; out pStencilRef: UINT); stdcall;
    SOGetTargets: procedure(Self: Pointer; NumBuffers: UINT; ppSOTargets: Pointer); stdcall;
    RSGetState: procedure(Self: Pointer; out ppRasterizerState: Pointer); stdcall;
    RSGetViewports: procedure(Self: Pointer; var pNumViewports: UINT; pViewports: Pointer); stdcall;
    RSGetScissorRects: procedure(Self: Pointer; var pNumRects: UINT; pRects: Pointer); stdcall;
    HSGetShaderResources: procedure(Self: Pointer; StartSlot, NumViews: UINT; ppShaderResourceViews: Pointer); stdcall;
    HSGetShader: procedure(Self: Pointer; out ppHullShader: Pointer; ppClassInstances: Pointer; var pNumClassInstances: UINT); stdcall;
    HSGetSamplers: procedure(Self: Pointer; StartSlot, NumSamplers: UINT; ppSamplers: Pointer); stdcall;
    HSGetConstantBuffers: procedure(Self: Pointer; StartSlot, NumBuffers: UINT; ppConstantBuffers: Pointer); stdcall;
    DSGetShaderResources: procedure(Self: Pointer; StartSlot, NumViews: UINT; ppShaderResourceViews: Pointer); stdcall;
    DSGetShader: procedure(Self: Pointer; out ppDomainShader: Pointer; ppClassInstances: Pointer; var pNumClassInstances: UINT); stdcall;
    DSGetSamplers: procedure(Self: Pointer; StartSlot, NumSamplers: UINT; ppSamplers: Pointer); stdcall;
    DSGetConstantBuffers: procedure(Self: Pointer; StartSlot, NumBuffers: UINT; ppConstantBuffers: Pointer); stdcall;
    CSGetShaderResources: procedure(Self: Pointer; StartSlot, NumViews: UINT; ppShaderResourceViews: Pointer); stdcall;
    CSGetUnorderedAccessViews: procedure(Self: Pointer; StartSlot, NumUAVs: UINT; ppUnorderedAccessViews: Pointer); stdcall;
    CSGetShader: procedure(Self: Pointer; out ppComputeShader: Pointer; ppClassInstances: Pointer; var pNumClassInstances: UINT); stdcall;
    CSGetSamplers: procedure(Self: Pointer; StartSlot, NumSamplers: UINT; ppSamplers: Pointer); stdcall;
    CSGetConstantBuffers: procedure(Self: Pointer; StartSlot, NumBuffers: UINT; ppConstantBuffers: Pointer); stdcall;
    ClearState: procedure(Self: Pointer); stdcall;
    Flush: procedure(Self: Pointer); stdcall;
    GetType: function(Self: Pointer): UINT; stdcall;
    GetContextFlags: function(Self: Pointer): UINT; stdcall;
    FinishCommandList: function(Self: Pointer; RestoreDeferredContextState: BOOL; out ppCommandList: Pointer): HRESULT; stdcall;
  end;
  PID3D11DeviceContextVtbl = ^ID3D11DeviceContextVtbl;
  
  ID3D11DeviceContext = record
    lpVtbl: PID3D11DeviceContextVtbl;
  end;
  PID3D11DeviceContext = ^ID3D11DeviceContext;
  PPID3D11DeviceContext = ^PID3D11DeviceContext;

  // IDXGISwapChain VTable
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

  // ID3D11RenderTargetView VTable
  ID3D11RenderTargetViewVtbl = record
    // IUnknown
    QueryInterface: function(Self: Pointer; const riid: TGUID; out ppvObject): HRESULT; stdcall;
    AddRef: function(Self: Pointer): ULONG; stdcall;
    Release: function(Self: Pointer): ULONG; stdcall;
    // ID3D11DeviceChild
    GetDevice: procedure(Self: Pointer; out ppDevice: Pointer); stdcall;
    GetPrivateData: function(Self: Pointer; const guid: TGUID; var pDataSize: UINT; pData: Pointer): HRESULT; stdcall;
    SetPrivateData: function(Self: Pointer; const guid: TGUID; DataSize: UINT; pData: Pointer): HRESULT; stdcall;
    SetPrivateDataInterface: function(Self: Pointer; const guid: TGUID; pData: Pointer): HRESULT; stdcall;
    // ID3D11View
    GetResource: procedure(Self: Pointer; out ppResource: Pointer); stdcall;
    // ID3D11RenderTargetView
    GetDesc: procedure(Self: Pointer; out pDesc: Pointer); stdcall;
  end;
  PID3D11RenderTargetViewVtbl = ^ID3D11RenderTargetViewVtbl;
  
  ID3D11RenderTargetView = record
    lpVtbl: PID3D11RenderTargetViewVtbl;
  end;
  PID3D11RenderTargetView = ^ID3D11RenderTargetView;

  // ID3D11Texture2D VTable
  ID3D11Texture2DVtbl = record
    // IUnknown
    QueryInterface: function(Self: Pointer; const riid: TGUID; out ppvObject): HRESULT; stdcall;
    AddRef: function(Self: Pointer): ULONG; stdcall;
    Release: function(Self: Pointer): ULONG; stdcall;
    // ID3D11DeviceChild
    GetDevice: procedure(Self: Pointer; out ppDevice: Pointer); stdcall;
    GetPrivateData: function(Self: Pointer; const guid: TGUID; var pDataSize: UINT; pData: Pointer): HRESULT; stdcall;
    SetPrivateData: function(Self: Pointer; const guid: TGUID; DataSize: UINT; pData: Pointer): HRESULT; stdcall;
    SetPrivateDataInterface: function(Self: Pointer; const guid: TGUID; pData: Pointer): HRESULT; stdcall;
    // ID3D11Resource
    GetType: procedure(Self: Pointer; out rType: UINT); stdcall;
    SetEvictionPriority: procedure(Self: Pointer; EvictionPriority: UINT); stdcall;
    GetEvictionPriority: function(Self: Pointer): UINT; stdcall;
    // ID3D11Texture2D
    GetDesc: procedure(Self: Pointer; out pDesc: Pointer); stdcall;
  end;
  PID3D11Texture2DVtbl = ^ID3D11Texture2DVtbl;
  
  ID3D11Texture2D = record
    lpVtbl: PID3D11Texture2DVtbl;
  end;
  PID3D11Texture2D = ^ID3D11Texture2D;

// ===========================================
// External function declarations
// ===========================================
function D3D11CreateDeviceAndSwapChain(
  pAdapter: Pointer;
  DriverType: D3D_DRIVER_TYPE;
  Software: HMODULE;
  Flags: UINT;
  pFeatureLevels: Pointer;
  FeatureLevels: UINT;
  SDKVersion: UINT;
  pSwapChainDesc: Pointer;
  out ppSwapChain: PIDXGISwapChain;
  out ppDevice: PID3D11Device;
  pFeatureLevel: Pointer;
  out ppImmediateContext: PID3D11DeviceContext
): HRESULT; stdcall; external 'd3d11.dll';

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
  g_pd3dDevice: PID3D11Device = nil;
  g_pImmediateContext: PID3D11DeviceContext = nil;
  g_pSwapChain: PIDXGISwapChain = nil;
  g_pRenderTargetView: PID3D11RenderTargetView = nil;
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
  featureLevel: D3D_FEATURE_LEVEL;
  pBackBuffer: PID3D11Texture2D;
  vp: D3D11_VIEWPORT;
  pVSBlob, pPSBlob: PID3DBlob;
  layout: array[0..1] of D3D11_INPUT_ELEMENT_DESC;
  vertices: array[0..2] of VERTEX;
  bd: D3D11_BUFFER_DESC;
  InitData: D3D11_SUBRESOURCE_DATA;
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

  featureLevel := D3D_FEATURE_LEVEL_11_0;

  Result := D3D11CreateDeviceAndSwapChain(
    nil, D3D_DRIVER_TYPE_HARDWARE, 0, 0,
    @featureLevel, 1, D3D11_SDK_VERSION,
    @sd, g_pSwapChain, g_pd3dDevice, nil, g_pImmediateContext);

  if Failed(Result) then
  begin
    DebugMsg('D3D11CreateDeviceAndSwapChain failed: ' + IntToHex(Result, 8));
    Exit;
  end;

  // Get back buffer
  pBackBuffer := nil;
  Result := g_pSwapChain^.lpVtbl^.GetBuffer(g_pSwapChain, 0, IID_ID3D11Texture2D, pBackBuffer);
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

  // Set render target
  g_pImmediateContext^.lpVtbl^.OMSetRenderTargets(g_pImmediateContext, 1, @g_pRenderTargetView, nil);

  // Setup viewport
  vp.TopLeftX := 0;
  vp.TopLeftY := 0;
  vp.Width := width;
  vp.Height := height;
  vp.MinDepth := 0.0;
  vp.MaxDepth := 1.0;
  g_pImmediateContext^.lpVtbl^.RSSetViewports(g_pImmediateContext, 1, @vp);

  // Compile vertex shader
  pVSBlob := nil;
  Result := D3DCompileFromFile('hello.fx', nil, nil, 'VS', 'vs_4_0',
    D3DCOMPILE_ENABLE_STRICTNESS, 0, pVSBlob, nil);
  if Failed(Result) then
  begin
    DebugMsg('D3DCompileFromFile (VS) failed: ' + IntToHex(Result, 8));
    Exit;
  end;

  // Create vertex shader
  Result := g_pd3dDevice^.lpVtbl^.CreateVertexShader(g_pd3dDevice,
    pVSBlob^.lpVtbl^.GetBufferPointer(pVSBlob),
    pVSBlob^.lpVtbl^.GetBufferSize(pVSBlob),
    nil, g_pVertexShader);
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
  layout[0].InputSlotClass := D3D11_INPUT_PER_VERTEX_DATA;
  layout[0].InstanceDataStepRate := 0;

  layout[1].SemanticName := 'COLOR';
  layout[1].SemanticIndex := 0;
  layout[1].Format := DXGI_FORMAT_R32G32B32A32_FLOAT;
  layout[1].InputSlot := 0;
  layout[1].AlignedByteOffset := 12;
  layout[1].InputSlotClass := D3D11_INPUT_PER_VERTEX_DATA;
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

  g_pImmediateContext^.lpVtbl^.IASetInputLayout(g_pImmediateContext, g_pVertexLayout);

  // Compile pixel shader
  pPSBlob := nil;
  Result := D3DCompileFromFile('hello.fx', nil, nil, 'PS', 'ps_4_0',
    D3DCOMPILE_ENABLE_STRICTNESS, 0, pPSBlob, nil);
  if Failed(Result) then
  begin
    DebugMsg('D3DCompileFromFile (PS) failed: ' + IntToHex(Result, 8));
    Exit;
  end;

  // Create pixel shader
  Result := g_pd3dDevice^.lpVtbl^.CreatePixelShader(g_pd3dDevice,
    pPSBlob^.lpVtbl^.GetBufferPointer(pPSBlob),
    pPSBlob^.lpVtbl^.GetBufferSize(pPSBlob),
    nil, g_pPixelShader);
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

  ZeroMemory(@bd, SizeOf(bd));
  bd.Usage := D3D11_USAGE_DEFAULT;
  bd.ByteWidth := SizeOf(VERTEX) * 3;
  bd.BindFlags := D3D11_BIND_VERTEX_BUFFER;
  bd.CPUAccessFlags := 0;

  ZeroMemory(@InitData, SizeOf(InitData));
  InitData.pSysMem := @vertices[0];

  Result := g_pd3dDevice^.lpVtbl^.CreateBuffer(g_pd3dDevice, bd, @InitData, g_pVertexBuffer);
  if Failed(Result) then
  begin
    DebugMsg('CreateBuffer failed: ' + IntToHex(Result, 8));
    Exit;
  end;

  // Set vertex buffer
  stride := SizeOf(VERTEX);
  offset := 0;
  g_pImmediateContext^.lpVtbl^.IASetVertexBuffers(g_pImmediateContext, 0, 1, @g_pVertexBuffer, @stride, @offset);

  // Set primitive topology
  g_pImmediateContext^.lpVtbl^.IASetPrimitiveTopology(g_pImmediateContext, D3D11_PRIMITIVE_TOPOLOGY_TRIANGLELIST);

  Result := S_OK;
end;

// ===========================================
// Cleanup Device
// ===========================================
procedure CleanupDevice;
begin
  if g_pImmediateContext <> nil then
    g_pImmediateContext^.lpVtbl^.ClearState(g_pImmediateContext);

  if g_pVertexBuffer <> nil then
    PID3D11RenderTargetView(g_pVertexBuffer)^.lpVtbl^.Release(g_pVertexBuffer);
  if g_pVertexLayout <> nil then
    PID3D11RenderTargetView(g_pVertexLayout)^.lpVtbl^.Release(g_pVertexLayout);
  if g_pVertexShader <> nil then
    PID3D11RenderTargetView(g_pVertexShader)^.lpVtbl^.Release(g_pVertexShader);
  if g_pPixelShader <> nil then
    PID3D11RenderTargetView(g_pPixelShader)^.lpVtbl^.Release(g_pPixelShader);
  if g_pRenderTargetView <> nil then
    g_pRenderTargetView^.lpVtbl^.Release(g_pRenderTargetView);
  if g_pSwapChain <> nil then
    g_pSwapChain^.lpVtbl^.Release(g_pSwapChain);
  if g_pImmediateContext <> nil then
    g_pImmediateContext^.lpVtbl^.Release(g_pImmediateContext);
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

  g_pImmediateContext^.lpVtbl^.ClearRenderTargetView(g_pImmediateContext, g_pRenderTargetView, @ClearColor[0]);
  g_pImmediateContext^.lpVtbl^.OMSetRenderTargets(g_pImmediateContext, 1, @g_pRenderTargetView, nil);
  g_pImmediateContext^.lpVtbl^.VSSetShader(g_pImmediateContext, g_pVertexShader, nil, 0);
  g_pImmediateContext^.lpVtbl^.PSSetShader(g_pImmediateContext, g_pPixelShader, nil, 0);
  g_pImmediateContext^.lpVtbl^.Draw(g_pImmediateContext, 3, 0);

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